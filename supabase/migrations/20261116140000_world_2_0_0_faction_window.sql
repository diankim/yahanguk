lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function public.world_faction_spread_rules()
 returns jsonb language sql immutable
as $function$
  select jsonb_build_object('steps', jsonb_build_array(jsonb_build_array(0, 100), jsonb_build_array(1, 75), jsonb_build_array(2, 55),
                                                       jsonb_build_array(3, 40), jsonb_build_array(4, 25)),
    'boost_max', 1.3, 'home_pct', 150, 'person_cap', 60, 'region_cap', 40,
    'day_region_cap', 60, 'day_cap', 90, 'window_h', 72, 'active_min', 60,
    'floor', 60, 'flip_ratio', 1.25, 'hold_h', 24, 'idle_h', 24)
$function$;

create table if not exists public.world_influence_ledger (
  hr timestamptz not null,
  owner_id uuid not null,
  faction_id text not null,
  region_id text not null,
  raw numeric not null,
  val numeric not null,
  primary key (owner_id, region_id, hr));
create index if not exists idx_world_influence_ledger_rf on public.world_influence_ledger (region_id, faction_id, hr);
create index if not exists idx_world_influence_ledger_hr on public.world_influence_ledger (hr);
alter table public.world_influence_ledger enable row level security;
revoke all on table public.world_influence_ledger from public, anon, authenticated;

create table if not exists public.world_region_contest (
  region_id text primary key,
  faction_id text not null,
  since timestamptz not null);
alter table public.world_region_contest enable row level security;
revoke all on table public.world_region_contest from public, anon, authenticated;
grant select on table public.world_region_contest to fn_owner_field;

create or replace function public.world_faction_boost(p text)
 returns numeric language sql stable set search_path to 'pg_catalog', 'public'
as $function$
  with t as (select f.faction_id, (select count(*) from public.world_map_regions mr
                                     where mr.active and not mr.is_safe_zone and mr.home_faction_id is not null and mr.control_faction_id = f.faction_id) n
               from public.world_major_factions f where f.active),
  m as (select max(n) hi, min(n) lo from t)
  select coalesce((select round(case when m.hi = m.lo then 1
                                     else 1 + ((public.world_faction_spread_rules() ->> 'boost_max')::numeric - 1) * (m.hi - t.n) / (m.hi - m.lo) end, 2)
                     from t, m where t.faction_id = p), 1)
$function$;

create or replace function public.world_faction_spread_mult(p_faction text, p_region text)
 returns numeric language sql stable set search_path to ''
as $function$
  select case when (select home_faction_id from public.world_map_regions where region_id = p_region) = p_faction
              then (public.world_faction_spread_rules() ->> 'home_pct')::numeric / 100
    else (select coalesce((select (s ->> 1)::numeric / 100 from jsonb_array_elements(public.world_faction_spread_rules() -> 'steps') s
                            where (s ->> 0)::int <= x.n order by (s ->> 0)::int desc limit 1), 1)
            from (select count(*) n from public.world_map_regions mr
                   where mr.active and not mr.is_safe_zone and mr.home_faction_id is not null and mr.home_faction_id <> p_faction
                     and mr.region_id <> p_region
                     and (mr.control_faction_id = p_faction
                          or exists (select 1 from public.world_region_contest wc where wc.region_id = mr.region_id and wc.faction_id = p_faction))) x) end
$function$;

create or replace function public.world_influence_accrue(p_from timestamptz, p_to timestamptz)
 returns integer language plpgsql set search_path to 'pg_catalog', 'public'
as $function$
declare rr jsonb := public.world_faction_spread_rules(); dy date := (p_to at time zone 'Asia/Seoul')::date; n int;
begin
  with ev as (
    select e.actor_id, coalesce(e.payload ->> 'region_id', nd.region_id) region_id, public.world_influence_pts(e.event_type, e.payload) pts
    from public.world_events e left join public.world_exploration_nodes nd on e.event_type = 'gather' and nd.node_id::text = e.payload ->> 'node_id'
    where e.created_at > p_from and e.created_at <= p_to and e.event_type in ('combat', 'explore', 'gather')
    union all
    select x.owner_id, x.region_id, least(24, least(x.minutes, extract(epoch from x.finished_at - x.started_at) / 60) / 20.0) from public.world_expeditions x
    where x.finished_at > p_from and x.finished_at <= p_to and x.status = 'done'),
  per as (select c.major_faction_id f, ev.region_id, ev.actor_id, least((rr ->> 'region_cap')::numeric, sum(ev.pts)) pts
          from ev join public.world_characters c on c.owner_id = ev.actor_id
          join public.world_map_regions mr on mr.region_id = ev.region_id
          where c.major_faction_id is not null and mr.active and not mr.is_safe_zone and mr.home_faction_id is not null
          group by 1, 2, 3 having sum(ev.pts) > 0),
  per2 as (select f, region_id, actor_id, pts * least(1, (rr ->> 'person_cap')::numeric / sum(pts) over (partition by actor_id)) pts from per),
  used as (select l.owner_id, l.region_id, sum(l.raw) r from public.world_influence_ledger l
            where l.hr > p_to - interval '2 days' and (l.hr at time zone 'Asia/Seoul')::date = dy group by 1, 2),
  d1 as (select p.f, p.region_id, p.actor_id, greatest(0, least(p.pts, (rr ->> 'day_region_cap')::numeric - coalesce(u.r, 0))) pts
           from per2 p left join used u on u.owner_id = p.actor_id and u.region_id = p.region_id),
  ut as (select owner_id, sum(r) r from used group by 1),
  d2 as (select d1.f, d1.region_id, d1.actor_id,
                d1.pts * least(1, greatest(0, (rr ->> 'day_cap')::numeric - coalesce(ut.r, 0)) / sum(d1.pts) over (partition by d1.actor_id)) pts
           from d1 left join ut on ut.owner_id = d1.actor_id where d1.pts > 0)
  insert into public.world_influence_ledger(hr, owner_id, faction_id, region_id, raw, val)
  select p_to, d2.actor_id, d2.f, d2.region_id, round(d2.pts, 2),
         round(d2.pts * public.world_faction_boost(d2.f) * public.world_faction_spread_mult(d2.f, d2.region_id), 2)
    from d2 where d2.pts > 0
  on conflict (owner_id, region_id, hr) do update set raw = public.world_influence_ledger.raw + excluded.raw, val = public.world_influence_ledger.val + excluded.val;
  get diagnostics n = row_count;
  return n;
end $function$;
revoke all on function public.world_influence_accrue(timestamptz, timestamptz) from public, anon, authenticated;

create or replace function public.world_influence_score(p_at timestamptz)
 returns void language plpgsql set search_path to 'pg_catalog', 'public'
as $function$
declare rr jsonb := public.world_faction_spread_rules(); w interval := make_interval(hours => (rr ->> 'window_h')::int);
begin
  with act as (
    select c.major_faction_id f, count(*) n
      from (select e.actor_id from public.world_events e where e.created_at > p_at - w and e.created_at <= p_at
             group by e.actor_id having count(distinct floor(extract(epoch from e.created_at) / 600)) >= (rr ->> 'active_min')::int / 10) a
      join public.world_characters c on c.owner_id = a.actor_id where c.major_faction_id is not null group by 1),
  sc as (select l.region_id, l.faction_id, sum(l.val) v, max(l.hr) filter (where l.val > 0) last_hr
           from public.world_influence_ledger l where l.hr > p_at - w and l.hr <= p_at group by 1, 2),
  tp as (select distinct on (l.region_id, l.faction_id) l.region_id, l.faction_id, l.owner_id
           from public.world_influence_ledger l where l.hr > p_at - w and l.hr <= p_at order by l.region_id, l.faction_id, l.hr desc, l.val desc)
  insert into public.world_region_influence(region_id, faction_id, points, last_actor, updated_at)
  select sc.region_id, sc.faction_id, round(sc.v / sqrt(greatest(1, coalesce(act.n, 1)))::numeric, 2), tp.owner_id, coalesce(sc.last_hr, p_at - w)
    from sc left join act on act.f = sc.faction_id left join tp on tp.region_id = sc.region_id and tp.faction_id = sc.faction_id
  on conflict (region_id, faction_id) do update set points = excluded.points, last_actor = excluded.last_actor,
    updated_at = greatest(public.world_region_influence.updated_at, excluded.updated_at);
  update public.world_region_influence i set points = 0
   where i.points <> 0 and not exists (select 1 from public.world_influence_ledger l where l.region_id = i.region_id and l.faction_id = i.faction_id and l.hr > p_at - w and l.hr <= p_at);
end $function$;
revoke all on function public.world_influence_score(timestamptz) from public, anon, authenticated;

create or replace function public.world_influence_tick()
 returns jsonb language plpgsql set search_path to 'pg_catalog', 'public'
as $function$
declare t0 timestamptz; t1 timestamptz := now(); r record; s record; ct record; flips int := 0; holder_score numeric; need numeric; old_stance text; new_stance text; who uuid;
  rr jsonb := public.world_faction_spread_rules(); fl numeric := (rr ->> 'floor')::numeric; ratio numeric := (rr ->> 'flip_ratio')::numeric;
  hold interval := make_interval(hours => (rr ->> 'hold_h')::int); idle interval := make_interval(hours => (rr ->> 'idle_h')::int);
begin
  select value::timestamptz into t0 from public.world_app_meta where key = 'influence_at';
  t0 := greatest(coalesce(t0, t1 - interval '1 hour'), t1 - interval '3 hours');
  perform public.world_influence_accrue(t0, t1);
  delete from public.world_influence_ledger where hr < t1 - make_interval(hours => (rr ->> 'window_h')::int) - interval '2 days';
  perform public.world_influence_score(t1);

  for r in select mr.region_id, mr.region_name, mr.home_faction_id, mr.control_faction_id from public.world_map_regions mr
           where mr.active and not mr.is_safe_zone and mr.home_faction_id is not null loop
    if r.control_faction_id is distinct from r.home_faction_id
       and coalesce((select updated_at from public.world_region_influence where region_id = r.region_id and faction_id = r.control_faction_id), '-infinity'::timestamptz) < t1 - idle then
      update public.world_map_regions set control_faction_id = r.home_faction_id, faction_control = public.world_mf_name(r.home_faction_id), control_changed_at = t1, contested = false where region_id = r.region_id;
      delete from public.world_region_contest where region_id = r.region_id;
      flips := flips + 1;
      insert into public.world_faction_log(kind, region_id, faction_id, other_id, content)
      values ('control', r.region_id, r.home_faction_id, r.control_faction_id, public.world_josa(r.region_name, '이', '가') || ' 하루 넘게 돌보는 이가 없어 본래 주인 ' || public.world_mf_name(r.home_faction_id) || '에게 돌아갔습니다.');
      insert into public.world_notifications(user_id, kind, title, content, payload)
      select c.owner_id, 'faction', '세력 판도 변화', public.world_josa(r.region_name, '이', '가') || ' 본래 주인 ' || public.world_mf_name(r.home_faction_id) || '에게 돌아갔습니다.', jsonb_build_object('region_id', r.region_id, 'faction_id', r.home_faction_id)
        from public.world_characters c where c.major_faction_id in (r.home_faction_id, r.control_faction_id) and not coalesce(c.is_dead, false);
      continue;
    end if;
    holder_score := coalesce((select points from public.world_region_influence where region_id = r.region_id and faction_id = r.control_faction_id), 0);
    if r.control_faction_id = r.home_faction_id then holder_score := greatest(fl, holder_score); end if;
    select f.faction_id, f.faction_name, coalesce(i.points, 0) sc, i.last_actor into s
      from public.world_major_factions f left join public.world_region_influence i on i.region_id = r.region_id and i.faction_id = f.faction_id
      where f.active and f.faction_id is distinct from r.control_faction_id order by 3 desc limit 1;
    need := holder_score * ratio;
    if s.faction_id is not null and s.sc > 0 and s.sc >= need then
      select * into ct from public.world_region_contest where region_id = r.region_id;
      if ct.region_id is null or ct.faction_id <> s.faction_id then
        insert into public.world_region_contest(region_id, faction_id, since) values (r.region_id, s.faction_id, t1)
        on conflict (region_id) do update set faction_id = excluded.faction_id, since = excluded.since;
        update public.world_map_regions set contested = true where region_id = r.region_id and contested is distinct from true;
        insert into public.world_faction_log(kind, region_id, faction_id, other_id, content)
        values ('contest', r.region_id, s.faction_id, r.control_faction_id, public.world_josa(s.faction_name, '이', '가') || ' ' || r.region_name || '에서 ' || public.world_mf_name(r.control_faction_id) || '보다 앞섰습니다. ' || (rr ->> 'hold_h') || '시간 이대로면 넘어갑니다.');
        insert into public.world_notifications(user_id, kind, title, content, payload)
        select c.owner_id, 'faction', '세력 분쟁', public.world_josa(s.faction_name, '이', '가') || ' ' || r.region_name || '에서 앞섰습니다. ' || (rr ->> 'hold_h') || '시간 동안 이대로면 그 세력에게 넘어갑니다.', jsonb_build_object('region_id', r.region_id, 'faction_id', s.faction_id)
          from public.world_characters c where c.major_faction_id = r.control_faction_id and not coalesce(c.is_dead, false);
      elsif t1 - ct.since >= hold - interval '30 minutes' then
        update public.world_map_regions set control_faction_id = s.faction_id, faction_control = s.faction_name, control_changed_at = t1, contested = false where region_id = r.region_id;
        delete from public.world_region_contest where region_id = r.region_id;
        flips := flips + 1;
        insert into public.world_faction_log(kind, region_id, faction_id, other_id, content)
        values ('control', r.region_id, s.faction_id, r.control_faction_id, public.world_josa(s.faction_name, '이', '가') || ' ' || public.world_josa(r.region_name, '을', '를') || ' ' || public.world_mf_name(r.control_faction_id) || '에게서 차지했습니다.');
        insert into public.world_notifications(user_id, kind, title, content, payload)
        select c.owner_id, 'faction', '세력 판도 변화', public.world_josa(s.faction_name, '이', '가') || ' ' || public.world_josa(r.region_name, '을', '를') || ' 차지했습니다.', jsonb_build_object('region_id', r.region_id, 'faction_id', s.faction_id)
          from public.world_characters c where c.major_faction_id in (s.faction_id, r.control_faction_id) and not coalesce(c.is_dead, false);
        who := coalesce(s.last_actor, (select owner_id from public.world_characters where major_faction_id = s.faction_id limit 1));
        if who is not null then
          insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
          values ('global', who, '세력 소식', public.world_josa(s.faction_name, '이', '가') || ' ' || public.world_josa(r.region_name, '을', '를') || ' 차지했습니다. 지배 세력이 바뀐 지역은 채집·희귀품·위험이 달라집니다.');
        end if;
      end if;
    else
      delete from public.world_region_contest where region_id = r.region_id;
      update public.world_map_regions set contested = false where region_id = r.region_id and contested;
    end if;
  end loop;

  for r in select fr.faction_a, fr.faction_b, fr.score from public.world_faction_relations fr loop
    old_stance := public.world_faction_stance(r.score);
    update public.world_faction_relations fr set score = greatest(-100, least(100, round(fr.score + (fr.base - fr.score) * 0.01
      + least(1, 0.5 * (select count(distinct pm.party_id) from public.world_party_members pm
            join public.world_characters ca on ca.owner_id = pm.owner_id and ca.major_faction_id = r.faction_a
            join public.world_party_members pm2 on pm2.party_id = pm.party_id join public.world_characters cb on cb.owner_id = pm2.owner_id and cb.major_faction_id = r.faction_b
            where exists (select 1 from public.world_events e where e.actor_id = ca.owner_id and e.created_at > t0)
              and exists (select 1 from public.world_events e where e.actor_id = cb.owner_id and e.created_at > t0)))
      - least(1.5, 0.5 * (select count(*) from
            (select l.region_id from public.world_influence_ledger l where l.hr = t1 and l.faction_id = r.faction_a group by 1 having sum(l.val) >= 3) ia
            join (select l.region_id from public.world_influence_ledger l where l.hr = t1 and l.faction_id = r.faction_b group by 1 having sum(l.val) >= 3) ib
              on ib.region_id = ia.region_id)), 2))), updated_at = t1
      where fr.faction_a = r.faction_a and fr.faction_b = r.faction_b returning score into holder_score;
    new_stance := public.world_faction_stance(holder_score);
    if new_stance <> old_stance then
      insert into public.world_faction_log(kind, faction_id, other_id, content)
      values ('relation', r.faction_a, r.faction_b, public.world_josa(public.world_mf_name(r.faction_a), '과', '와') || ' ' || public.world_mf_name(r.faction_b) || '의 관계가 ' || old_stance || '에서 ' || public.world_josa(new_stance, '으로', '로') || ' 바뀌었습니다.');
    end if;
  end loop;

  insert into public.world_app_meta(key, value, changed_at) values ('influence_at', t1::text, now())
  on conflict (key) do update set value = excluded.value, changed_at = now();
  return jsonb_build_object('from', t0, 'to', t1, 'flips', flips);
end $function$;

create or replace function public.world_influence_mine(p_uid uuid, p_region text, p_faction text)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
declare t0 timestamptz; rr jsonb := public.world_faction_spread_rules(); cap numeric := (rr ->> 'region_cap')::numeric; pcap numeric := (rr ->> 'person_cap')::numeric;
  here numeric; total numeric; dh numeric; dt numeric; dy date := (now() at time zone 'Asia/Seoul')::date;
begin
  if p_uid is null or p_faction is null or not exists (select 1 from public.world_map_regions mr where mr.region_id = p_region and mr.active and not mr.is_safe_zone and mr.home_faction_id is not null) then
    return null;
  end if;
  select value::timestamptz into t0 from public.world_app_meta where key = 'influence_at';
  t0 := greatest(coalesce(t0, now() - interval '1 hour'), now() - interval '3 hours');
  with ev as (
    select coalesce(e.payload ->> 'region_id', n.region_id) region_id, public.world_influence_pts(e.event_type, e.payload) pts
    from public.world_events e left join public.world_exploration_nodes n on e.event_type = 'gather' and n.node_id::text = e.payload ->> 'node_id'
    where e.actor_id = p_uid and e.event_type in ('combat', 'explore', 'gather') and e.created_at > t0
    union all
    select x.region_id, least(24, least(x.minutes, extract(epoch from x.finished_at - x.started_at) / 60) / 20.0) from public.world_expeditions x
    where x.owner_id = p_uid and x.status = 'done' and x.finished_at > t0),
  per as (select ev.region_id, sum(ev.pts) pts from ev join public.world_map_regions mr on mr.region_id = ev.region_id
          where mr.active and not mr.is_safe_zone and mr.home_faction_id is not null group by 1)
  select coalesce(max(least(cap, pts)) filter (where region_id = p_region), 0), coalesce(sum(least(cap, pts)), 0) into here, total from per;
  select coalesce(sum(l.raw) filter (where l.region_id = p_region), 0), coalesce(sum(l.raw), 0) into dh, dt
    from public.world_influence_ledger l where l.owner_id = p_uid and l.hr > now() - interval '2 days' and (l.hr at time zone 'Asia/Seoul')::date = dy;
  return jsonb_build_object('n', round(here, 1), 'cap', cap, 'all', round(total, 1), 'all_cap', pcap,
    'day', round(least((rr ->> 'day_region_cap')::numeric, dh + here), 1), 'day_cap', (rr ->> 'day_region_cap')::numeric,
    'day_all', round(least((rr ->> 'day_cap')::numeric, dt + least(pcap, total)), 1), 'day_all_cap', (rr ->> 'day_cap')::numeric,
    'next_at', date_trunc('hour', now() - interval '7 minutes') + interval '1 hour 7 minutes');
end $function$;

select pg_temp.yh_fix('world_faction_board', array[
$q$'contested', r.contested,$q$,
$q$'contested', r.contested, 'by', (select wc.faction_id from public.world_region_contest wc where wc.region_id = r.region_id),
        'since', (select wc.since from public.world_region_contest wc where wc.region_id = r.region_id),$q$]);

select pg_temp.yh_fix('world_faction_weekly', array[
$q$ || '. 모든 지역의 영향력이 절반으로 줄었습니다.');$q$,
$q$ || '.');$q$,
$q$  update public.world_region_influence set points = round(points * 0.5, 2) where points > 0;
$q$,
''
]);

select pg_temp.yh_fix('world_character_purge', array[
$q$  delete from public.world_hidden_trails where owner_id = p_uid;$q$,
$q$  delete from public.world_hidden_trails where owner_id = p_uid;
  delete from public.world_influence_ledger where owner_id = p_uid;$q$]);

do $$
declare h timestamptz; t1 timestamptz := coalesce((select value::timestamptz from public.world_app_meta where key = 'influence_at'), now());
begin
  if not exists (select 1 from public.world_influence_ledger) then
    for h in select generate_series(t1 - interval '72 hours', t1, interval '1 hour') loop
      perform public.world_influence_accrue(h - interval '1 hour', h);
    end loop;
  end if;
  perform public.world_influence_score(now());
end $$;

update public.world_patch_notes set body = body || E'\n\n### 세력 판도\n- 지역 점수는 최근 3일 동안 그 지역에 쌓은 영향력 합으로 셉니다. 오래 쌓아 둔 점수가 남아 있지 않고, 주간 정산에서 영향력을 절반으로 줄이지도 않습니다.\n- 점수는 그 세력에서 최근 3일 동안 1시간 넘게 움직인 조사원 수의 제곱근으로 나눕니다. 사람이 많다고 그만큼 앞서지 않습니다.\n- 한 사람이 하루(한국 시각)에 쌓는 영향력은 지역마다 60, 모든 지역 합 90까지입니다. 한 시간 정산 몫(지역 40·합 60)은 그대로입니다.\n- 본래 주인은 점수가 낮아도 60으로 셉니다. 다른 세력 점수가 지배 세력의 1.25배를 넘으면 「분쟁 중」이 되고, 24시간 이어지면 지배 세력이 바뀝니다. 분쟁이 시작되면 지배 세력 조사원에게 알림이 갑니다.\n- 남의 땅을 차지한 세력이 24시간 새로 쌓지 않으면 본래 주인에게 돌아갑니다.\n- 약세 보정은 차지한 지역 수로 바뀝니다. 가장 적게 차지한 세력은 새로 쌓는 영향력 ×1.3, 가장 많이 차지한 세력은 ×1입니다.'
where note_id = '2.0.0' and position('### 세력 판도' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116140000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
