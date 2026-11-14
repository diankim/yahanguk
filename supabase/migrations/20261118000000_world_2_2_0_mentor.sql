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
create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;
create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

create or replace function public.world_xp_lead_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object('lead', 3, 'active_days', 2, 'active_min', 60, 'steps', '[]'::jsonb,
    'trail', jsonb_build_object('gap', 5, 'steps', '[[5,120],[10,150],[15,175],[20,200]]'::jsonb))
$function$;

select pg_temp.yh_fix('world_xp_damp_pct(uuid,integer)', array[
$q$  select * into d from public.world_xp_damp$q$,
$q$  if avg_lv is not null and r ? 'trail' and avg_lv - p_level >= (r #>> '{trail,gap}')::numeric then
    p := (select (s ->> 1)::numeric from jsonb_array_elements(r #> '{trail,steps}') s where (s ->> 0)::numeric <= avg_lv - p_level order by (s ->> 0)::numeric desc limit 1);
    if p is not null then pct := greatest(pct, p); end if;
  end if;
  select * into d from public.world_xp_damp$q$]);
select pg_temp.yh_fix('world_xp_damp_apply()', array[$q$if pct >= 100 then return new; end if;$q$, $q$if pct = 100 then return new; end if;$q$]);

create or replace function public.world_mentor_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select $j${
    "gap": 10, "near_min": 10, "cap_pct": 225, "day_cap": 60, "pair_cap": 30, "xp_day": 50,
    "kinds": {
      "pfight": {"pct": 25, "merit": 2, "name": "함께 토벌"},
      "win": {"pct": 15, "merit": 1, "name": "곁에서 토벌"},
      "exp": {"pct": 25, "merit": [[30, 1], [60, 2], [120, 4], [240, 6], [480, 10]], "name": "파티 원정"},
      "quest": {"pct": 25, "merit": 2, "name": "퀘스트"}
    },
    "skip": ["봉연의 그림자", "10장 결전", "귀허의 주인", "먹그림자", "비장고"],
    "post": {"hours": 2, "note": 30, "wants": {"win": "토벌", "exp": "원정", "quest": "퀘스트"}},
    "guide": {"low": 5, "high": 35},
    "shop": [
      {"key": "hf_mentor_lantern", "kind": "item", "name": "선배의 등롱", "price": 40, "desc": "별채 가구 · 조명"},
      {"key": "fr_mentor", "kind": "frame", "name": "등롱 길 테", "price": 60, "desc": "프로필 테두리"},
      {"key": "pt_mentor", "kind": "pattern", "name": "갈림길 무늬", "price": 80, "desc": "프로필 바탕 무늬"},
      {"key": "sl_seon", "kind": "seal", "name": "낙관 「先」", "price": 120, "desc": "프로필 낙관"},
      {"key": "ns:1033", "kind": "name_style", "name": "등롱빛", "price": 160, "desc": "채팅 이름 색"},
      {"key": "lantern_donkey", "kind": "mount", "name": "등롱 나귀", "price": 250, "desc": "탈것 · 속도 ×2.0 · 둘이 탐 · 운임 1"}
    ],
    "titles": [
      {"key": "mt_merit20", "by": "total", "n": 20},
      {"key": "mt_merit150", "by": "total", "n": 150},
      {"key": "mt_merit600", "by": "total", "n": 600},
      {"key": "mt_kids3", "by": "mentees", "n": 3},
      {"key": "mt_kids6", "by": "mentees", "n": 6},
      {"key": "mt_follow10", "by": "follows", "n": 10},
      {"key": "mt_grad", "by": "grad", "n": 20}
    ]
  }$j$::jsonb
$function$;

create table if not exists public.world_mentor_merit (
  owner_id uuid primary key,
  merit int not null default 0 check (merit >= 0),
  total int not null default 0,
  updated_at timestamptz not null default now()
);
create table if not exists public.world_mentor_pairs (
  mentor_id uuid not null,
  mentee_id uuid not null,
  n int not null default 0,
  first_at timestamptz not null default now(),
  last_at timestamptz not null default now(),
  primary key (mentor_id, mentee_id)
);
create index if not exists idx_world_mentor_pairs_mentee on public.world_mentor_pairs(mentee_id);
create table if not exists public.world_mentor_log (
  day date not null,
  mentor_id uuid not null,
  mentee_id uuid not null,
  kind text not null,
  n int not null default 0,
  merit int not null default 0,
  xp int not null default 0,
  primary key (day, mentor_id, mentee_id, kind)
);
create index if not exists idx_world_mentor_log_mentee on public.world_mentor_log(day, mentee_id);
create table if not exists public.world_mentor_posts (
  owner_id uuid primary key,
  kind text not null check (kind in ('seek', 'offer')),
  note text not null default '',
  wants text[] not null default '{}',
  region text,
  created_at timestamptz not null default now(),
  until timestamptz not null,
  chat_day date
);
do $g$
declare t text;
begin
  foreach t in array array['world_mentor_merit', 'world_mentor_pairs', 'world_mentor_log', 'world_mentor_posts'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to fn_owner_field', t);
  end loop;
end $g$;

create or replace function public.world_mentor_today()
 returns date language sql stable
as $function$ select (now() at time zone 'Asia/Seoul')::date $function$;

create or replace function public.world_mentor_pair(p_uid uuid, p_kind text, p_ctx jsonb default '{}'::jsonb)
 returns uuid
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_mentor_rules(); me record; m uuid;
begin
  if p_uid is null or exists (select 1 from public.world_staff s where s.owner_id = p_uid) then return null; end if;
  if not exists (select 1 from public.world_party_members where owner_id = p_uid) then return null; end if;
  select level, location into me from public.world_characters where owner_id = p_uid;
  if me.level is null then return null; end if;
  select c2.owner_id into m
    from public.world_party_members a
    join public.world_party_members b on b.party_id = a.party_id and b.owner_id <> a.owner_id
    join public.world_characters c2 on c2.owner_id = b.owner_id
   where a.owner_id = p_uid
     and c2.level - me.level >= (r ->> 'gap')::int
     and c2.downed_at is null and not coalesce(c2.is_dead, false)
     and not exists (select 1 from public.world_staff s where s.owner_id = c2.owner_id)
     and case p_kind
       when 'exp' then exists (select 1 from public.world_expeditions px
          where px.owner_id = c2.owner_id and px.expedition_id <> (p_ctx ->> 'exp')::uuid
            and public.world_pexp_together((p_ctx ->> 'exp')::uuid, px.expedition_id))
       when 'pfight' then exists (select 1 from public.world_pfight_members x
          join public.world_pfight_members y on y.fight_id = x.fight_id and y.owner_id = c2.owner_id
          join public.world_pfights f on f.fight_id = x.fight_id
          where x.owner_id = p_uid and f.status = 'fight' and coalesce(y.out_reason, '') not in ('fled', 'gone'))
       when 'win' then c2.location = me.location and c2.travel_destination is null
          and exists (select 1 from public.world_events e where e.actor_id = c2.owner_id
            and e.created_at > now() - make_interval(mins => (r ->> 'near_min')::int))
       else c2.location = me.location and c2.travel_destination is null end
   order by c2.level desc, c2.owner_id
   limit 1;
  return m;
end $function$;

create or replace function public.world_mentor_rule_count(p_owner uuid, p_rule jsonb)
 returns numeric
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select case p_rule ->> 'mentor'
    when 'total' then coalesce((select total from public.world_mentor_merit where owner_id = p_owner), 0)
    when 'mentees' then (select count(*) from public.world_mentor_pairs where mentor_id = p_owner)
    when 'follows' then coalesce((select sum(n) from public.world_mentor_pairs where mentee_id = p_owner), 0)
    when 'grad' then case when exists (select 1 from public.world_mentor_pairs where mentee_id = p_owner)
      then coalesce((select total from public.world_mentor_merit where owner_id = p_owner), 0) else 0 end
    else 0 end::numeric
$function$;

create or replace function public.world_mentor_bonus(p_uid uuid, p_kind text, p_xp int, p_ctx jsonb default '{}'::jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_mentor_rules(); kr jsonb := public.world_mentor_rules() -> 'kinds' -> p_kind;
  m uuid; lv int; t numeric; tot numeric; b int := 0; d date := public.world_mentor_today(); lim int; used int;
  mk int; mused int; pused int; before_total int; after_total int; new_pair boolean; fl int; x jsonb;
begin
  if p_uid is null or kr is null or coalesce(p_xp, 0) <= 0 then return '{}'::jsonb; end if;
  m := public.world_mentor_pair(p_uid, p_kind, p_ctx);
  if m is null then return '{}'::jsonb; end if;
  select level into lv from public.world_characters where owner_id = p_uid;
  if lv is null or lv >= public.world_level_cap() then return '{}'::jsonb; end if;
  t := public.world_xp_damp_pct(p_uid, lv);
  tot := least((r ->> 'cap_pct')::numeric, t + (kr ->> 'pct')::numeric);
  if t > 0 and tot > t then b := round(p_xp * (tot / t - 1)); end if;
  lim := floor(public.world_xp_need(lv) * (r ->> 'xp_day')::numeric / 100);
  select coalesce(sum(l.xp), 0) into used from public.world_mentor_log l where l.day = d and l.mentee_id = p_uid;
  b := greatest(0, least(b, lim - used));
  if jsonb_typeof(kr -> 'merit') = 'array' then
    mk := coalesce((select (s ->> 1)::int from jsonb_array_elements(kr -> 'merit') s
      where (s ->> 0)::int <= coalesce((p_ctx ->> 'minutes')::int, 0) order by (s ->> 0)::int desc limit 1), 0);
  else mk := (kr ->> 'merit')::int; end if;
  perform pg_advisory_xact_lock(hashtextextended('mentor:' || m::text, 0));
  select coalesce(sum(l.merit), 0), coalesce(sum(l.merit) filter (where l.mentee_id = p_uid), 0) into mused, pused
    from public.world_mentor_log l where l.day = d and l.mentor_id = m;
  mk := greatest(0, least(mk, (r ->> 'day_cap')::int - mused, (r ->> 'pair_cap')::int - pused));
  insert into public.world_mentor_log(day, mentor_id, mentee_id, kind, n, merit, xp) values (d, m, p_uid, p_kind, 1, mk, b)
  on conflict (day, mentor_id, mentee_id, kind) do update set n = world_mentor_log.n + 1, merit = world_mentor_log.merit + excluded.merit, xp = world_mentor_log.xp + excluded.xp;
  new_pair := not exists (select 1 from public.world_mentor_pairs where mentor_id = m and mentee_id = p_uid);
  insert into public.world_mentor_pairs(mentor_id, mentee_id, n) values (m, p_uid, 1)
  on conflict (mentor_id, mentee_id) do update set n = world_mentor_pairs.n + 1, last_at = now();
  select coalesce(sum(n), 0) into fl from public.world_mentor_pairs where mentee_id = p_uid;
  select coalesce(total, 0) into before_total from public.world_mentor_merit where owner_id = m;
  before_total := coalesce(before_total, 0);
  after_total := before_total + mk;
  if mk > 0 then
    insert into public.world_mentor_merit(owner_id, merit, total) values (m, mk, mk)
    on conflict (owner_id) do update set merit = world_mentor_merit.merit + excluded.merit, total = world_mentor_merit.total + excluded.total, updated_at = now();
  end if;
  for x in select value from jsonb_array_elements(r -> 'titles') loop
    if (x ->> 'by' in ('total', 'grad') and before_total < (x ->> 'n')::int and after_total >= (x ->> 'n')::int)
       or (x ->> 'by' = 'mentees' and new_pair) then
      perform public.world_title_award_check(m, 'mentor'); exit;
    end if;
  end loop;
  if fl = (select (q.v ->> 'n')::int from jsonb_array_elements(r -> 'titles') q(v) where q.v ->> 'by' = 'follows' limit 1) then
    perform public.world_title_award_check(p_uid, 'mentor');
  end if;
  return jsonb_build_object('xp', b, 'mentor', m, 'merit', mk, 'kind', p_kind,
    'name', (select character_name from public.world_characters where owner_id = m));
end $function$;

select pg_temp.yh_fix('world_title_rule_ok', array[
$q$ELSIF p_rule ? 'home' THEN RETURN public.world_home_rule_count(p_owner, p_rule) >= n;$q$,
$q$ELSIF p_rule ? 'mentor' THEN RETURN public.world_mentor_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'home' THEN RETURN public.world_home_rule_count(p_owner, p_rule) >= n;$q$]);
select pg_temp.yh_fix('world_title_rule_progress', array[
$q$elsif p_rule ? 'home' then v := public.world_home_rule_count(p_owner, p_rule);$q$,
$q$elsif p_rule ? 'mentor' then v := public.world_mentor_rule_count(p_owner, p_rule); elsif p_rule ? 'home' then v := public.world_home_rule_count(p_owner, p_rule);$q$]);
select pg_temp.yh_fix('world_title_award_check', array[
$q$    IF r ? 'codex' AND$q$,
$q$    IF r ? 'mentor' AND p_event_type IS NOT NULL AND p_event_type <> 'mentor' THEN CONTINUE; END IF;
    IF r ? 'codex' AND$q$]);

select pg_temp.yh_fix('world_battle_action(text,text)', array[
$q$loot jsonb := '{}'::jsonb; xp int := 0;$q$,
$q$loot jsonb := '{}'::jsonb; mt jsonb := '{}'::jsonb; xp int := 0;$q$,
$q$    gil_gain := round((2 + a.mlevel) * rk_mul);$q$,
$q$    mt := public.world_mentor_bonus(uid, CASE WHEN nullif(current_setting('yh.pf_n', true), '') IS NULL THEN 'win' ELSE 'pfight' END, xp + 12);
    xp := xp + coalesce((mt ->> 'xp')::int, 0);
    gil_gain := round((2 + a.mlevel) * rk_mul);$q$,
$q$'xp', xp + 12, 'gil', gil_gain, 'loot', loot);$q$,
$q$'xp', xp + 12, 'gil', gil_gain, 'loot', loot, 'mentor_xp', coalesce((mt ->> 'xp')::int, 0), 'mentor', mt ->> 'name');$q$]);

select pg_temp.yh_fix('world_expedition_complete(boolean)', array[
$q$full_gear text;$q$, $q$full_gear text; mt jsonb := '{}'::jsonb;$q$,
$q$  gained := public.world_grant_xp(uid, xp);$q$,
$q$  if xp > 0 then
    mt := public.world_mentor_bonus(uid, 'exp', xp, jsonb_build_object('exp', e.expedition_id, 'minutes', e.minutes));
    xp := xp + coalesce((mt ->> 'xp')::int, 0);
  end if;
  gained := public.world_grant_xp(uid, xp);$q$]);

select pg_temp.yh_fix('world_quest_report(text)', array[
$q$gx jsonb;$q$, $q$gx jsonb; mt jsonb := '{}'::jsonb;$q$,
$q$  if rw_xp > 0 then gx := public.world_grant_xp_got(uid, rw_xp);$q$,
$q$  if rw_xp > 0 and jsonb_array_length(coalesce(s.need -> 'tasks', '[]'::jsonb)) > 0 then
    mt := public.world_mentor_bonus(uid, 'quest', rw_xp, jsonb_build_object('quest', p_quest));
    rw_xp := rw_xp + coalesce((mt ->> 'xp')::int, 0);
  end if;
  if coalesce((mt ->> 'xp')::int, 0) > 0 then msg := msg || '선배 덤(' || (mt ->> 'name') || ') · '; end if;
  if rw_xp > 0 then gx := public.world_grant_xp_got(uid, rw_xp);$q$]);

create or replace function public.world_mentor_post(p_kind text, p_note text default '', p_wants text[] default '{}')
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_mentor_rules(); c record; w text[]; nt text; d date := public.world_mentor_today(); prev date; said boolean := false;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if exists (select 1 from public.world_staff s where s.owner_id = uid) then raise exception '운영진은 선배 찾기에 글을 올릴 수 없습니다.'; end if;
  if p_kind not in ('seek', 'offer') then raise exception '글 갈래가 잘못되었습니다.'; end if;
  select character_name, level, location, job_key into c from public.world_characters where owner_id = uid;
  if c.level is null then raise exception '캐릭터가 없습니다.'; end if;
  if p_kind = 'offer' and c.level < 1 + (r ->> 'gap')::int then raise exception '선배 글은 Lv.%부터 올릴 수 있습니다.', 1 + (r ->> 'gap')::int; end if;
  if p_kind = 'seek' and c.level > public.world_level_cap() - (r ->> 'gap')::int then raise exception '이 레벨에서는 새내기 글을 올릴 수 없습니다.'; end if;
  nt := left(regexp_replace(btrim(coalesce(p_note, '')), '\s+', ' ', 'g'), (r #>> '{post,note}')::int);
  select array_agg(distinct x) into w from unnest(coalesce(p_wants, '{}')) x where x in (select jsonb_object_keys(r #> '{post,wants}'));
  select chat_day into prev from public.world_mentor_posts where owner_id = uid;
  insert into public.world_mentor_posts(owner_id, kind, note, wants, region, created_at, until, chat_day)
  values (uid, p_kind, nt, coalesce(w, '{}'), c.location, now(), now() + make_interval(hours => (r #>> '{post,hours}')::int), d)
  on conflict (owner_id) do update set kind = excluded.kind, note = excluded.note, wants = excluded.wants, region = excluded.region,
    created_at = now(), until = excluded.until, chat_day = d;
  if prev is distinct from d then
    insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
    values ('global', uid, '선배 소식', 'Lv' || c.level || ' ' || public.world_josa(c.character_name, '이', '가') || ' '
      || case p_kind when 'seek' then '함께할 선배를 찾습니다' else '새내기와 함께 갑니다' end
      || ' · ' || coalesce(c.location, '')
      || coalesce(' · ' || nullif(array_to_string(array(select r #>> array['post', 'wants', x] from unnest(coalesce(w, '{}')) x), '·'), ''), '')
      || case when nt <> '' then ' — ' || nt else '' end || ' (동료 › 선배와 새내기)');
    said := true;
  end if;
  return jsonb_build_object('ok', true, 'chat', said, 'until', now() + make_interval(hours => (r #>> '{post,hours}')::int));
end $function$;

create or replace function public.world_mentor_unpost()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  update public.world_mentor_posts set until = now() where owner_id = uid and until > now();
  return jsonb_build_object('ok', true);
end $function$;

create or replace function public.world_mentor_owned(p_uid uuid, p_kind text, p_key text)
 returns boolean
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select case p_kind
    when 'frame' then exists (select 1 from public.world_character_cosmetics where owner_id = p_uid and cosmetic_key = p_key)
    when 'pattern' then exists (select 1 from public.world_character_cosmetics where owner_id = p_uid and cosmetic_key = p_key)
    when 'seal' then exists (select 1 from public.world_character_cosmetics where owner_id = p_uid and cosmetic_key = p_key)
    when 'name_style' then exists (select 1 from public.world_faction_unlocks where owner_id = p_uid and unlock_key = p_key)
    when 'mount' then exists (select 1 from public.world_owned_mounts where owner_id = p_uid and mount_id = p_key)
    else false end
$function$;

create or replace function public.world_mentor_board()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_mentor_rules(); lv int; d date := public.world_mentor_today(); staff boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select level into lv from public.world_characters where owner_id = uid;
  staff := exists (select 1 from public.world_staff s where s.owner_id = uid);
  return jsonb_build_object(
    'me', jsonb_build_object(
      'level', lv, 'staff', staff,
      'merit', coalesce((select merit from public.world_mentor_merit where owner_id = uid), 0),
      'total', coalesce((select total from public.world_mentor_merit where owner_id = uid), 0),
      'mentees', (select count(*) from public.world_mentor_pairs where mentor_id = uid),
      'follows', coalesce((select sum(n) from public.world_mentor_pairs where mentee_id = uid), 0),
      'today_merit', coalesce((select sum(merit) from public.world_mentor_log where day = d and mentor_id = uid), 0),
      'today_xp', coalesce((select sum(xp) from public.world_mentor_log where day = d and mentee_id = uid), 0),
      'xp_day_cap', case when lv >= public.world_level_cap() then 0 else floor(public.world_xp_need(lv) * (r ->> 'xp_day')::numeric / 100) end,
      'post', (select jsonb_build_object('kind', p.kind, 'note', p.note, 'wants', to_jsonb(p.wants), 'until', p.until)
        from public.world_mentor_posts p where p.owner_id = uid and p.until > now())),
    'posts', coalesce((select jsonb_agg(jsonb_build_object('owner_id', p.owner_id, 'name', c.character_name, 'level', c.level, 'job_key', c.job_key,
        'location', c.location, 'kind', p.kind, 'note', p.note, 'wants', to_jsonb(p.wants), 'until', p.until, 'profile', c.profile,
        'last_active', (select max(e.created_at) from public.world_events e where e.actor_id = p.owner_id))
        order by p.created_at desc)
      from public.world_mentor_posts p join public.world_characters c on c.owner_id = p.owner_id
      where p.until > now() and p.owner_id <> uid and not coalesce(c.is_dead, false)
        and not exists (select 1 from public.world_blocks b where (b.owner_id = uid and b.blocked_id = p.owner_id) or (b.owner_id = p.owner_id and b.blocked_id = uid))
        and abs(c.level - coalesce(lv, 0)) >= (r ->> 'gap')::int
        and ((p.kind = 'seek' and c.level < lv) or (p.kind = 'offer' and c.level > lv))), '[]'::jsonb),
    'people', coalesce((select jsonb_agg(x order by x ->> 'last_at' desc) from (
      select jsonb_build_object('owner_id', c.owner_id, 'name', c.character_name, 'level', c.level, 'role', 'mentee', 'n', p.n, 'last_at', p.last_at) x
        from public.world_mentor_pairs p join public.world_characters c on c.owner_id = p.mentee_id where p.mentor_id = uid
      union all
      select jsonb_build_object('owner_id', c.owner_id, 'name', c.character_name, 'level', c.level, 'role', 'mentor', 'n', p.n, 'last_at', p.last_at)
        from public.world_mentor_pairs p join public.world_characters c on c.owner_id = p.mentor_id where p.mentee_id = uid
      order by 1 limit 20) s), '[]'::jsonb),
    'owned', coalesce((select jsonb_agg(s ->> 'key') from jsonb_array_elements(r -> 'shop') s
      where public.world_mentor_owned(uid, s ->> 'kind', s ->> 'key')), '[]'::jsonb));
end $function$;

create or replace function public.world_mentor_shop_buy(p_key text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_mentor_rules(); s jsonb; c public.world_characters%rowtype; cost int; left_m int;
begin
  perform public.world_travel_guard('챙김 쓰기');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select x into s from jsonb_array_elements(r -> 'shop') x where x ->> 'key' = p_key;
  if s is null then raise exception '챙김으로 바꿀 수 없는 것입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 바꿀 수 없습니다.'; end if;
  if s ->> 'kind' <> 'item' and public.world_mentor_owned(uid, s ->> 'kind', p_key) then raise exception '이미 가지고 있습니다.'; end if;
  cost := (s ->> 'price')::int;
  if s ->> 'kind' = 'item' and public.world_bag_room(coalesce(c.inventory, '{}'::jsonb), p_key, public.world_bag_limit(uid)) < 1 then raise exception '가방 자리가 모자랍니다.'; end if;
  update public.world_mentor_merit set merit = merit - cost, updated_at = now() where owner_id = uid and merit >= cost returning merit into left_m;
  if not found then raise exception '챙김이 모자랍니다(% 필요, 지금 %).', cost, coalesce((select merit from public.world_mentor_merit where owner_id = uid), 0); end if;
  if s ->> 'kind' = 'item' then
    update public.world_characters set inventory = public.world_inv_add(coalesce(inventory, '{}'::jsonb), p_key, 1), updated_at = now() where owner_id = uid;
  elsif s ->> 'kind' in ('frame', 'pattern', 'seal') then
    insert into public.world_character_cosmetics(owner_id, cosmetic_key) values (uid, p_key) on conflict do nothing;
  elsif s ->> 'kind' = 'name_style' then
    insert into public.world_faction_unlocks(owner_id, unlock_key) values (uid, p_key) on conflict do nothing;
  elsif s ->> 'kind' = 'mount' then
    insert into public.world_owned_mounts(owner_id, mount_id) values (uid, p_key) on conflict do nothing;
  end if;
  return jsonb_build_object('content', public.world_josa(s ->> 'name', '을', '를') || ' 받았습니다(챙김 ' || cost || ').'
    || case s ->> 'kind' when 'item' then ' 가방에 넣었습니다.' when 'name_style' then ' 설정 › 프로필 › 채팅 이름 색에서 고릅니다.'
      when 'mount' then ' 지도 › 이동의 내 탈것에서 탑니다.' else ' 설정 › 프로필 꾸미기에서 답니다.' end,
    'merit', left_m, 'kind', s ->> 'kind');
end $function$;

create or replace function public.world_mentor_guide()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare g jsonb := public.world_mentor_rules() -> 'guide';
begin
  if exists (select 1 from public.world_staff s where s.owner_id = new.owner_id) then return new; end if;
  if old.level < (g ->> 'low')::int and new.level >= (g ->> 'low')::int then perform public.world_guide_note(new.owner_id, 'mentor_low'); end if;
  if old.level < (g ->> 'high')::int and new.level >= (g ->> 'high')::int then perform public.world_guide_note(new.owner_id, 'mentor_high'); end if;
  return new;
end $function$;
drop trigger if exists trg_world_mentor_guide on public.world_characters;
create trigger trg_world_mentor_guide after update of level on public.world_characters
  for each row when (new.level > old.level) execute function public.world_mentor_guide();

select pg_temp.yh_fix('world_guide_note(uuid,text,integer)', array[
$q$p_tip not in ('ch1', 'erosion')$q$, $q$p_tip not in ('ch1', 'erosion', 'mentor_low', 'mentor_high')$q$,
$q$  if p_tip = 'ch1' then$q$,
$q$  if p_tip = 'mentor_low' then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_uid, 'guide', '선배와 함께 가 보세요',
      '레벨이 ' || (public.world_mentor_rules() ->> 'gap') || ' 이상 높은 선배와 같은 파티로 토벌·파티 원정·퀘스트를 하면 경험치를 더 받습니다. 동료 화면 「선배와 새내기」의 「선배 찾기」에 글을 올려 함께할 선배를 찾아보세요.',
      jsonb_build_object('tip', 'mentor_low'));
    return;
  elsif p_tip = 'mentor_high' then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_uid, 'guide', '새내기를 챙겨 주세요',
      '레벨이 ' || (public.world_mentor_rules() ->> 'gap') || ' 이상 낮은 새내기와 같은 파티로 다니면 새내기는 경험치를 더 받고, 나는 「챙김」을 쌓아 꾸미기·탈것·칭호로 바꿀 수 있습니다. 동료 화면 「선배와 새내기」를 열어 보세요.',
      jsonb_build_object('tip', 'mentor_high'));
    return;
  end if;
  if p_tip = 'ch1' then$q$]);

create or replace function public.world_sys_chat_names()
 returns text[]
 language sql
 immutable
as $function$ select array['구조 알림', '세력 소식', '봉연 소식', '비무 소식', '연리 소식', '운영 공지', '선배 소식'] $function$;

select pg_temp.yh_fix('world_character_purge(uuid)', array[
$q$  delete from public.world_bijang_maps where owner_id = p_uid;$q$,
$q$  delete from public.world_bijang_maps where owner_id = p_uid;
  delete from public.world_mentor_merit where owner_id = p_uid;
  delete from public.world_mentor_pairs where mentor_id = p_uid or mentee_id = p_uid;
  delete from public.world_mentor_log where mentor_id = p_uid or mentee_id = p_uid;
  delete from public.world_mentor_posts where owner_id = p_uid;$q$]);

select pg_temp.yh_fix('world_housekeeping', array[
$q$begin$q$, $q$begin
  delete from public.world_mentor_log where day < public.world_mentor_today() - 60;
  delete from public.world_mentor_posts where until < now() - interval '2 days';$q$]);

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
('mt_merit20', '첫 챙김', 'users', '새내기를 처음 챙긴 선배.', '챙김을 모두 20 쌓는다', '{}', true, false, '{"mentor": "total", "n": 20}', 1601, '선배와 새내기', 1),
('mt_merit150', '등불 든 선배', 'users', '어두운 길에 등불을 들어 준 선배.', '챙김을 모두 150 쌓는다', '{}', true, false, '{"mentor": "total", "n": 150}', 1602, '선배와 새내기', 2),
('mt_merit600', '모두의 선배', 'users', '야행국 새내기라면 한 번쯤 그 등을 따라 걸었다.', '챙김을 모두 600 쌓는다', '{}', true, false, '{"mentor": "total", "n": 600}', 1603, '선배와 새내기', 3),
('mt_kids3', '세 갈래 길', 'users', '서로 다른 새내기 셋과 길을 걸었다.', '서로 다른 새내기 3명을 챙긴다', '{}', true, false, '{"mentor": "mentees", "n": 3}', 1604, '선배와 새내기', 2),
('mt_kids6', '여섯 갈래 길', 'users', '갈래마다 누군가 그 이름을 기억한다.', '서로 다른 새내기 6명을 챙긴다', '{}', true, true, '{"mentor": "mentees", "n": 6}', 1605, '선배와 새내기', 3),
('mt_follow10', '챙김 받은 새내기', 'users', '선배의 등을 보며 길을 익혔다.', '선배와 함께 10번 덤을 받는다', '{}', true, false, '{"mentor": "follows", "n": 10}', 1606, '선배와 새내기', 1),
('mt_grad', '청출어람', 'users', '챙김을 받던 새내기가 이제 누군가를 챙긴다.', '새내기로 덤을 받은 뒤 선배로 챙김 20을 쌓는다', '{}', true, true, '{"mentor": "grad", "n": 20}', 1607, '선배와 새내기', 4)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text,
  bonus = excluded.bonus, hidden = excluded.hidden, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade, active = true;

insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
('fr_mentor', 'frame', 'rare', '등롱 길 테', '챙김 60으로 바꾼다', '선배와 새내기', '{"shop": "mentor"}', false, true, 1601),
('pt_mentor', 'pattern', 'rare', '갈림길 무늬', '챙김 80으로 바꾼다', '선배와 새내기', '{"shop": "mentor"}', false, true, 1602),
('sl_seon', 'seal', 'legend', '낙관 「先」', '챙김 120으로 바꾼다', '선배와 새내기', '{"shop": "mentor"}', false, true, 1603)
on conflict (cosmetic_key) do update set tier = excluded.tier, cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text,
  category = excluded.category, rule = excluded.rule, hidden = excluded.hidden, active = true, sort = excluded.sort;

insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, unlock_faction, unlock_region, unlock_item, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method) values
('lantern_donkey', '등롱 나귀', 2.0, 1, 0, null, null, null, 0, '길잡이 등롱을 목에 건 순한 나귀. 새내기 하나를 뒤에 태우고도 걸음이 흔들리지 않는다.', '선배', 2, 1, false, 'event')
on conflict (mount_id) do update set mount_name = excluded.mount_name, speed_multiplier = excluded.speed_multiplier, description = excluded.description,
  tier = excluded.tier, passenger_capacity = excluded.passenger_capacity, fare_tokens = excluded.fare_tokens, acquire_method = excluded.acquire_method;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values
('hf_mentor_lantern', '선배의 등롱', 'furniture', 4, '별채 가구 · 조명. 새내기를 챙긴 선배가 받는 장대 등롱입니다. 갈림길마다 걸어 두던 것처럼, 불빛이 아래로 따뜻하게 번집니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 돌아갑니다.', false, false, 800, 1,
 '{"d": 1, "w": 1, "hk": "mentor_lantern", "cat": "조명", "top": 0, "kind": "floor", "grade": 4}')
on conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, tradeable = excluded.tradeable, equipment_traits = excluded.equipment_traits;

select pg_temp.yh_share('public.world_mentor_rules()');
select pg_temp.yh_share('public.world_mentor_today()');
select pg_temp.yh_share('public.world_mentor_pair(uuid, text, jsonb)');
select pg_temp.yh_share('public.world_mentor_rule_count(uuid, jsonb)');
select pg_temp.yh_share('public.world_mentor_bonus(uuid, text, int, jsonb)');
select pg_temp.yh_share('public.world_mentor_owned(uuid, text, text)');
select pg_temp.yh_share('public.world_mentor_guide()');
select pg_temp.yh_own('public.world_mentor_pair(uuid, text, jsonb)', 'fn_owner_field');
select pg_temp.yh_own('public.world_mentor_rule_count(uuid, jsonb)', 'fn_owner_field');
select pg_temp.yh_own('public.world_mentor_bonus(uuid, text, int, jsonb)', 'fn_owner_field');
select pg_temp.yh_own('public.world_mentor_owned(uuid, text, text)', 'fn_owner_field');
select pg_temp.yh_share('public.world_mentor_post(text, text, text[])');
select pg_temp.yh_share('public.world_mentor_unpost()');
select pg_temp.yh_share('public.world_mentor_board()');
select pg_temp.yh_share('public.world_mentor_shop_buy(text)');
select pg_temp.yh_own('public.world_mentor_post(text, text, text[])', 'fn_owner_field');
select pg_temp.yh_own('public.world_mentor_unpost()', 'fn_owner_field');
select pg_temp.yh_own('public.world_mentor_board()', 'fn_owner_field');
select pg_temp.yh_own('public.world_mentor_shop_buy(text)', 'fn_owner_field');
grant execute on function public.world_mentor_post(text, text, text[]) to authenticated;
grant execute on function public.world_mentor_unpost() to authenticated;
grant execute on function public.world_mentor_board() to authenticated;
grant execute on function public.world_mentor_shop_buy(text) to authenticated;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118000000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
