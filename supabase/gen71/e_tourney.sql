
-- ─────────────────────────────────────────────────────────────
-- E. 야행 비무회(夜行比武會): 주간 신청(월 00:00 ~ 금 23:59 KST) · 토 21:00 1:1 · 일 21:00 팀전(같은 파티 2명)
--   개최지는 주마다 바뀌는 안전지대 하나. 1시간·30분 전 알림, 10분 전 개최지에 없으면 불참(상대 부전승), 최소 4명(팀)
--   단판 승자 진출 토너먼트(모자라면 부전승 자리), 같은 회차 경기는 함께 펼쳐지고 합마다 2초씩 화면이 다시 보여 준다(개최지에서 관람)
--   작전: 태세(공격·균형·수비)·회복품 둘(가방에서 쓰지 않음, 작전 표식)·직업 기술 쓰는 때(처음·몰릴 때·마무리)
--   레벨 보정: 기세는 경기 평균 레벨로 같게, 레벨 차 1마다 2%(최대 20%), 능력치·장비 차이는 절반만
--   목숨·체력·물품·전·경험치는 그대로, world_events를 남기지 않는다(칭호·꾸미기는 비무회 기록으로 판정)
--   예약 작업 yh-tourney(1분마다 world_tourney_tick, 할 일이 없으면 바로 끝남)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.world_tourneys (
  t_id uuid primary key default gen_random_uuid(),
  week date not null,
  mode text not null check (mode in ('solo', 'team')),
  venue_region text not null,
  signup_ends timestamptz not null,
  starts_at timestamptz not null,
  status text not null default 'signup' check (status in ('signup', 'locked', 'running', 'done', 'cancelled')),
  round int not null default 0,
  rounds int not null default 0,
  round_at timestamptz,
  alerts int not null default 0,
  result jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (week, mode)
);
create table if not exists public.world_tourney_entries (
  entry_id uuid primary key default gen_random_uuid(),
  t_id uuid not null references public.world_tourneys(t_id) on delete cascade,
  members uuid[] not null,
  names text[] not null,
  seed int,
  status text not null default 'in' check (status in ('in', 'absent', 'out', 'champion')),
  place int,
  flawless boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.world_tourney_entrants (
  t_id uuid not null references public.world_tourneys(t_id) on delete cascade,
  owner_id uuid not null,
  entry_id uuid not null references public.world_tourney_entries(entry_id) on delete cascade,
  tactic jsonb not null default '{"stance": "balanced", "items": [], "skill": "mid"}'::jsonb,
  primary key (t_id, owner_id)
);
create table if not exists public.world_tourney_matches (
  match_id uuid primary key default gen_random_uuid(),
  t_id uuid not null references public.world_tourneys(t_id) on delete cascade,
  round int not null,
  slot int not null,
  a uuid,
  b uuid,
  winner uuid,
  log jsonb not null default '[]'::jsonb,
  exchanges int not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  unique (t_id, round, slot)
);
create index if not exists world_tourney_entries_t on public.world_tourney_entries(t_id);
create index if not exists world_tourney_entrants_owner on public.world_tourney_entrants(owner_id);
alter table public.world_tourneys enable row level security;
alter table public.world_tourney_entries enable row level security;
alter table public.world_tourney_entrants enable row level security;
alter table public.world_tourney_matches enable row level security;
revoke all on public.world_tourneys, public.world_tourney_entries, public.world_tourney_entrants, public.world_tourney_matches from anon, authenticated;
grant select, insert, update, delete on public.world_tourneys, public.world_tourney_entries, public.world_tourney_entrants, public.world_tourney_matches to fn_owner_field;

-- 이번 주 두 대회(없으면 만든다). 개최지는 주마다 안전지대를 돌아가며(반요촌 제외)
create or replace function public.world_tourney_ensure() returns void
language plpgsql security definer set search_path = '' as $$
declare mon date := date_trunc('week', now() at time zone 'Asia/Seoul')::date; v text;
begin
  select region_id into v from (select region_id, row_number() over (order by region_id) - 1 k, count(*) over () n
      from public.world_map_regions where is_safe_zone and active and region_id <> 'banyo_village') x
   where k = (extract(week from mon)::int % n);
  insert into public.world_tourneys(week, mode, venue_region, signup_ends, starts_at)
  values (mon, 'solo', v, ((mon + 5)::timestamp) at time zone 'Asia/Seoul', ((mon + 5)::timestamp + interval '21 hours') at time zone 'Asia/Seoul'),
         (mon, 'team', v, ((mon + 5)::timestamp) at time zone 'Asia/Seoul', ((mon + 6)::timestamp + interval '21 hours') at time zone 'Asia/Seoul')
  on conflict (week, mode) do nothing;
end $$;

-- 신청: 안전지대의 「비무 방」에서. 팀전은 같은 파티의 동료 한 명을 함께 적는다
create or replace function public.world_tourney_signup(p_mode text, p_partner uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; p public.world_characters%rowtype; t public.world_tourneys%rowtype; eid uuid; pid uuid;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_mode not in ('solo', 'team') then raise exception '알 수 없는 대회입니다.'; end if;
  perform public.world_tourney_ensure();
  select * into t from public.world_tourneys where week = date_trunc('week', now() at time zone 'Asia/Seoul')::date and mode = p_mode for update;
  if t.status <> 'signup' or now() >= t.signup_ends then raise exception '이번 주 신청은 끝났습니다(월요일 0시부터 금요일 23시 59분까지).'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not coalesce((public.world_field_region(c.location)).is_safe_zone, false) then raise exception '안전지대의 비무 방에서 신청할 수 있습니다.'; end if;
  if exists (select 1 from public.world_tourney_entrants where t_id = t.t_id and owner_id = uid) then raise exception '이미 신청했습니다.'; end if;
  if p_mode = 'team' then
    if p_partner is null or p_partner = uid then raise exception '함께 나갈 파티원을 고르세요.'; end if;
    select m.party_id into pid from public.world_party_members m where m.owner_id = uid;
    if pid is null or not exists (select 1 from public.world_party_members m where m.party_id = pid and m.owner_id = p_partner) then raise exception '같은 파티의 동료와만 팀으로 나갈 수 있습니다.'; end if;
    if exists (select 1 from public.world_tourney_entrants where t_id = t.t_id and owner_id = p_partner) then raise exception '그 동료는 이미 다른 팀으로 신청했습니다.'; end if;
    select * into p from public.world_characters where owner_id = p_partner;
    insert into public.world_tourney_entries(t_id, members, names) values (t.t_id, array[uid, p_partner], array[c.character_name, p.character_name]) returning entry_id into eid;
    insert into public.world_tourney_entrants(t_id, owner_id, entry_id) values (t.t_id, uid, eid), (t.t_id, p_partner, eid);
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_partner, 'tourney_partner', '비무회 팀 신청', c.character_name || '이(가) 당신과 함께 이번 주 팀전에 신청했습니다. 일요일 21시, ' || (select region_name from public.world_map_regions where region_id = t.venue_region) || '에서 열립니다.', jsonb_build_object('t_id', t.t_id));
  else
    insert into public.world_tourney_entries(t_id, members, names) values (t.t_id, array[uid], array[c.character_name]) returning entry_id into eid;
    insert into public.world_tourney_entrants(t_id, owner_id, entry_id) values (t.t_id, uid, eid);
  end if;
  return jsonb_build_object('ok', true, 'content', case when p_mode = 'solo' then '이번 주 1:1 비무회(토요일 21시)에 신청했습니다.' else '이번 주 팀전(일요일 21시)에 신청했습니다.' end);
end $$;

create or replace function public.world_tourney_cancel(p_mode text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); t public.world_tourneys%rowtype; eid uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into t from public.world_tourneys where week = date_trunc('week', now() at time zone 'Asia/Seoul')::date and mode = p_mode for update;
  if not found or t.status <> 'signup' or now() >= t.signup_ends then raise exception '신청 기간이 지나 물릴 수 없습니다.'; end if;
  select entry_id into eid from public.world_tourney_entrants where t_id = t.t_id and owner_id = uid;
  if eid is null then raise exception '신청한 것이 없습니다.'; end if;
  delete from public.world_tourney_entries where entry_id = eid;
  return jsonb_build_object('ok', true, 'content', '신청을 물렸습니다.');
end $$;

-- 작전: 대회가 시작하기 전까지 바꿀 수 있다
create or replace function public.world_tourney_tactic(p_mode text, p_stance text, p_items text[], p_skill text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); t public.world_tourneys%rowtype; ok_items text[] := array['tonic', 'herbal_extract', 'herb', 'rejuv_pill', 'grand_pill', 'banyo_salve'];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_stance not in ('attack', 'balanced', 'defense') or p_skill not in ('open', 'mid', 'finish') then raise exception '작전이 올바르지 않습니다.'; end if;
  if coalesce(cardinality(p_items), 0) > 2 or exists (select 1 from unnest(coalesce(p_items, '{}')) x where x <> all (ok_items)) then raise exception '회복품은 두 가지까지 고를 수 있습니다.'; end if;
  select * into t from public.world_tourneys where week = date_trunc('week', now() at time zone 'Asia/Seoul')::date and mode = p_mode;
  if not found or t.status not in ('signup', 'locked') or now() >= t.starts_at then raise exception '대회가 시작되어 작전을 바꿀 수 없습니다.'; end if;
  update public.world_tourney_entrants set tactic = jsonb_build_object('stance', p_stance, 'items', to_jsonb(coalesce(p_items, '{}')), 'skill', p_skill)
   where t_id = t.t_id and owner_id = uid;
  if not found then raise exception '신청한 대회가 아닙니다.'; end if;
  return jsonb_build_object('ok', true, 'content', '작전을 정했습니다.');
end $$;

-- 겨루기 한 판(1:1 또는 2:2): 서버가 끝까지 굴리고 합마다의 기록을 남긴다
create or replace function public.world_tourney_duel(p_t uuid, p_a uuid, p_b uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  ids uuid[] := '{}'; side int[] := '{}'; nm text[] := '{}'; lv numeric[] := '{}'; atk numeric[] := '{}'; crit numeric[] := '{}'; cm numeric[] := '{}'; eva numeric[] := '{}'; red numeric[] := '{}';
  pres numeric[] := '{}'; agi numeric[] := '{}'; hp numeric[] := '{}'; mx numeric[] := '{}'; stance text[] := '{}'; skw text[] := '{}'; job text[] := '{}';
  items jsonb[] := '{}'; used boolean[] := '{}'; stun int[] := '{}'; focus int[] := '{}'; fell boolean[] := '{}';
  e public.world_tourney_entries%rowtype; uid uuid; st jsonb; ch public.world_characters%rowtype; tac jsonb; s int; n int; i int; j int; k int; x int; maxx int;
  oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true);
  lg jsonb := '[]'::jsonb; avg_lv numeric; m_atk numeric; m_crit numeric; m_eva numeric; m_red numeric; base_hp numeric; ord int[]; tgt int; w numeric; best numeric; dmg numeric; mul numeric;
  is_crit boolean; heal numeric; win int; it text; opp_lv numeric; alive int[]; sum_r numeric[]; lastx int := 0;
begin
  for s in 1..2 loop
    select * into e from public.world_tourney_entries where entry_id = case when s = 1 then p_a else p_b end;
    foreach uid in array e.members loop
      select * into ch from public.world_characters where owner_id = uid;
      select tactic into tac from public.world_tourney_entrants where t_id = p_t and owner_id = uid;
      perform set_config('request.jwt.claim.sub', uid::text, true);
      perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
      st := public.world_combat_stats(uid);
      ids := ids || uid; side := side || s; nm := nm || ch.character_name; lv := lv || coalesce(ch.level, 1)::numeric; job := job || ch.job_key;
      atk := atk || greatest(1, coalesce((st ->> 'attack')::numeric, 10)); crit := crit || least(60, coalesce((st ->> 'crit_pct')::numeric, 5));
      cm := cm || coalesce((st ->> 'crit_mult')::numeric, 150) / 100; eva := eva || least(40, coalesce((st ->> 'evasion_pct')::numeric, 0));
      red := red || least(60, coalesce((st ->> 'reduction_pct')::numeric, 0)); pres := pres || greatest(1, coalesce((st ->> 'presence')::numeric, 30));
      agi := agi || coalesce(ch.agility, 5)::numeric + random(); stance := stance || coalesce(tac ->> 'stance', 'balanced'); skw := skw || coalesce(tac ->> 'skill', 'mid');
      items := items || coalesce(tac -> 'items', '[]'::jsonb); used := used || false; stun := stun || 0; focus := focus || 0; fell := fell || false;
    end loop;
  end loop;
  perform set_config('request.jwt.claims', coalesce(oc, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  n := cardinality(ids);
  -- 보정: 기세는 평균 레벨로 같게, 능력치·장비 차이는 평균과의 차이의 절반만
  select avg(v) into avg_lv from unnest(lv) v; select avg(v) into m_atk from unnest(atk) v; select avg(v) into m_crit from unnest(crit) v;
  select avg(v) into m_eva from unnest(eva) v; select avg(v) into m_red from unnest(red) v;
  base_hp := round(100 + 8 * avg_lv);
  for i in 1..n loop
    atk[i] := m_atk + (atk[i] - m_atk) * 0.5; crit[i] := m_crit + (crit[i] - m_crit) * 0.5; eva[i] := m_eva + (eva[i] - m_eva) * 0.5; red[i] := m_red + (red[i] - m_red) * 0.5;
    hp := hp || base_hp; mx := mx || base_hp;
  end loop;
  select array_agg(o order by agi[o] desc) into ord from generate_series(1, n) o;
  maxx := case when n > 2 then 16 else 12 end;
  lg := lg || jsonb_build_array(jsonb_build_object('x', 0, 'k', 'start', 't',
    (select string_agg(nm[o], '·') from generate_series(1, n) o where side[o] = 1) || ' 대 ' || (select string_agg(nm[o], '·') from generate_series(1, n) o where side[o] = 2) || ' — 비무대에 올랐다. 기세 ' || base_hp || '씩.'));
  <<duel>>
  for x in 1..maxx loop
    lastx := x;
    foreach i in array ord loop
      continue when hp[i] <= 0;
      if not exists (select 1 from generate_series(1, n) o where side[o] <> side[i] and hp[o] > 0) then exit duel; end if;
      if stun[i] > 0 then stun[i] := stun[i] - 1; lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'stun', 'w', side[i], 't', nm[i] || '이(가) 봉인에 묶여 움직이지 못했다.')); continue; end if;
      -- 회복품: 기세가 40% 아래로 떨어지면 하나 쓴다
      if hp[i] < mx[i] * 0.4 and jsonb_array_length(items[i]) > 0 then
        it := items[i] ->> 0; items[i] := items[i] - 0;
        heal := round(mx[i] * case it when 'grand_pill' then 0.45 when 'rejuv_pill' then 0.32 when 'banyo_salve' then 0.36 when 'tonic' then 0.22 when 'herbal_extract' then 0.15 else 0.1 end);
        hp[i] := least(mx[i], hp[i] + heal);
        lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'heal', 'w', side[i], 't', nm[i] || '이(가) ' || coalesce((select item_name from public.world_item_catalog where item_id = it), '회복품') || '을(를) 써 기세 ' || heal || '을(를) 되찾았다.'));
        continue;
      end if;
      -- 표적: 이목^1.3에 비례
      tgt := null; best := -1;
      for o in 1..n loop
        if side[o] <> side[i] and hp[o] > 0 then
          w := -ln(greatest(random(), 1e-9)) / power(pres[o], 1.3);
          if tgt is null or w < best then tgt := o; best := w; end if;
        end if;
      end loop;
      -- 직업 기술(한 판에 한 번): 처음 · 몰릴 때(내 기세 60% 아래) · 마무리(상대 35% 아래)
      mul := 1; is_crit := false;
      if not used[i] and ((skw[i] = 'open') or (skw[i] = 'mid' and hp[i] < mx[i] * 0.6) or (skw[i] = 'finish' and hp[tgt] < mx[tgt] * 0.35)) then
        used[i] := true;
        if job[i] = 'medic' then
          heal := round(mx[i] * 0.25); hp[i] := least(mx[i], hp[i] + heal);
          lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'skill', 'w', side[i], 't', nm[i] || '의 「응급 처방」: 기세 ' || heal || ' 회복'));
          continue;
        elsif job[i] = 'analyst' then focus[i] := 3; lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'skill', 'w', side[i], 't', nm[i] || '의 「약점 간파」: 상대의 빈틈을 읽었다.'));
        elsif job[i] = 'artificer' then mul := 1.7; lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'skill', 'w', side[i], 't', nm[i] || '의 「파갑참」!'));
        elsif job[i] = 'scout' then is_crit := true; lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'skill', 'w', side[i], 't', nm[i] || '의 「급소 사격」!'));
        elsif job[i] = 'exorcist' then mul := 2.0; lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'skill', 'w', side[i], 't', nm[i] || '의 「퇴마진」!'));
        elsif job[i] = 'sealmaster' then mul := 1.1; stun[tgt] := 1; lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'skill', 'w', side[i], 't', nm[i] || '의 「봉인술」: ' || nm[tgt] || '을(를) 묶었다.'));
        end if;
      end if;
      if random() * 100 < eva[tgt] + case when stance[tgt] = 'defense' then 5 else 0 end and not is_crit then
        lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'miss', 'w', side[i], 't', nm[tgt] || '이(가) ' || nm[i] || '의 공격을 흘려 피했다.'));
        continue;
      end if;
      select avg(lv[o]) into opp_lv from generate_series(1, n) o where side[o] <> side[i];
      dmg := atk[i] * (0.85 + random() * 0.3) * mul
             * case stance[i] when 'attack' then 1.15 when 'defense' then 0.85 else 1 end
             * case stance[tgt] when 'attack' then 1.1 when 'defense' then 0.8 else 1 end
             * (1 + greatest(-0.2, least(0.2, 0.02 * (lv[i] - opp_lv))))
             * (1 - case when job[i] = 'artificer' and mul = 1.7 then 0 else red[tgt] end / 100.0);
      if focus[i] > 0 then dmg := dmg * 1.4; focus[i] := focus[i] - 1; end if;
      if is_crit or random() * 100 < crit[i] then dmg := dmg * cm[i]; is_crit := true; end if;
      dmg := greatest(1, round(dmg));
      hp[tgt] := greatest(0, hp[tgt] - dmg);
      lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', case when is_crit then 'crit' else 'hit' end, 'w', side[i], 'd', dmg,
        't', nm[i] || case when is_crit then '의 일격이 빈틈을 꿰뚫었다! ' else '이(가) ' || nm[tgt] || '에게 ' end || dmg || ' 피해'));
      -- 합공(팀전): 곁의 동료가 10% 확률로 이어 친다
      if hp[tgt] > 0 and n > 2 and random() < 0.1 then
        for o in 1..n loop
          if o <> i and side[o] = side[i] and hp[o] > 0 then
            heal := greatest(1, round(atk[o] * 0.4 * (1 - red[tgt] / 100.0))); hp[tgt] := greatest(0, hp[tgt] - heal);
            lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'coop', 'w', side[i], 'd', heal, 't', nm[o] || '이(가) 틈을 놓치지 않고 이어 쳤다! ' || heal || ' 피해'));
            exit;
          end if;
        end loop;
      end if;
      if hp[tgt] <= 0 then fell[tgt] := true; lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'down', 'w', side[i], 't', nm[tgt] || '이(가) 무릎을 꿇었다.')); end if;
    end loop;
  end loop;
  select array_agg(cnt order by sd) into alive from (select g.sd, count(*) filter (where side[o] = g.sd and hp[o] > 0) cnt from generate_series(1, 2) g(sd), generate_series(1, n) o group by g.sd) z;
  select array_agg(rr order by sd) into sum_r from (select g.sd, coalesce(sum(hp[o] / mx[o]) filter (where side[o] = g.sd), 0) rr from generate_series(1, 2) g(sd), generate_series(1, n) o group by g.sd) z;
  win := case when alive[1] > 0 and alive[2] = 0 then 1 when alive[2] > 0 and alive[1] = 0 then 2 when sum_r[1] >= sum_r[2] then 1 else 2 end;
  lg := lg || jsonb_build_array(jsonb_build_object('x', lastx + 1, 'k', 'end', 'w', win, 't',
    (select string_agg(nm[o], '·') from generate_series(1, n) o where side[o] = win) || case when alive[3 - win] = 0 then '이(가) 상대를 모두 꺾었다.' else '이(가) 판정으로 이겼다.' end));
  return jsonb_build_object('winner', win, 'log', lg, 'exchanges', lastx + 1,
    'flawless', (select bool_and(not fell[o]) and sum(hp[o] / mx[o]) / count(*) >= 0.5 from generate_series(1, n) o where side[o] = win));
end $$;

-- 한 회차를 펼친다(부전승 포함). 다음 회차는 가장 긴 경기가 끝나고 20초 뒤
create or replace function public.world_tourney_play_round(p_t uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare t public.world_tourneys%rowtype; m record; r jsonb; latest timestamptz := now(); loser uuid; w uuid;
begin
  select * into t from public.world_tourneys where t_id = p_t for update;
  for m in select * from public.world_tourney_matches where t_id = p_t and round = t.round order by slot loop
    if m.b is null or m.a is null then
      w := coalesce(m.a, m.b);
      update public.world_tourney_matches set winner = w, starts_at = now(), ends_at = now(), exchanges = 0,
        log = jsonb_build_array(jsonb_build_object('x', 0, 'k', 'bye', 't', (select array_to_string(names, '·') from public.world_tourney_entries where entry_id = w) || ' — 부전승'))
       where match_id = m.match_id;
      continue;
    end if;
    r := public.world_tourney_duel(p_t, m.a, m.b);
    w := case when (r ->> 'winner')::int = 1 then m.a else m.b end; loser := case when w = m.a then m.b else m.a end;
    update public.world_tourney_matches set winner = w, log = r -> 'log', exchanges = (r ->> 'exchanges')::int, starts_at = now(),
      ends_at = now() + make_interval(secs => 2 * (r ->> 'exchanges')::int) where match_id = m.match_id;
    latest := greatest(latest, now() + make_interval(secs => 2 * (r ->> 'exchanges')::int));
    update public.world_tourney_entries set status = 'out', place = power(2, t.rounds - t.round)::int + 1 where entry_id = loser;
    if not coalesce((r ->> 'flawless')::boolean, false) then update public.world_tourney_entries set flawless = false where entry_id = w; end if;
  end loop;
  update public.world_tourneys set round_at = latest + interval '20 seconds', updated_at = now() where t_id = p_t;
end $$;

-- 대회를 마친다: 순위·칭호·꾸미기·탈것·이름 색·알림·전체 채팅
create or replace function public.world_tourney_finish(p_t uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare t public.world_tourneys%rowtype; ch uuid; u uuid; champ_names text; venue text; nchamp int; who uuid; runner text;
begin
  select * into t from public.world_tourneys where t_id = p_t for update;
  select winner into ch from public.world_tourney_matches where t_id = p_t and round = t.rounds;
  update public.world_tourney_entries set status = 'champion', place = 1 where entry_id = ch;
  select array_to_string(names, '·') into champ_names from public.world_tourney_entries where entry_id = ch;
  select array_to_string(e.names, '·') into runner from public.world_tourney_entries e where e.t_id = p_t and e.place = 2;
  select region_name into venue from public.world_map_regions where region_id = t.venue_region;
  update public.world_tourneys set status = 'done', updated_at = now(), result = jsonb_build_object('champion', ch, 'champion_names', champ_names, 'runner_up', runner) where t_id = p_t;
  for u in select unnest(members) from public.world_tourney_entries where entry_id = ch loop
    insert into public.world_faction_unlocks(owner_id, unlock_key) values (u, case when t.mode = 'solo' then 'ns:1029' else 'ns:1030' end) on conflict do nothing;
    select count(*) into nchamp from public.world_tourney_entries e join public.world_tourneys x on x.t_id = e.t_id where x.status = 'done' and e.place = 1 and u = any (e.members);
    if nchamp >= 3 then insert into public.world_owned_mounts(owner_id, mount_id) values (u, 'tn_white_horse') on conflict do nothing; end if;
  end loop;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select en.owner_id, 'tourney_result', '비무회 결과', case when e.place = 1 then '이번 ' || case when t.mode = 'solo' then '1:1' else '팀전' end || ' 비무회에서 우승했습니다! 이번 주 동안 조사원 카드에 「비무 장원」 표식이 붙습니다.'
         else '이번 비무회 순위: ' || e.place || '위 무렵. 우승은 ' || champ_names || '.' end, jsonb_build_object('t_id', p_t)
    from public.world_tourney_entrants en join public.world_tourney_entries e on e.entry_id = en.entry_id where en.t_id = p_t and e.status <> 'absent';
  for u in select en.owner_id from public.world_tourney_entrants en join public.world_tourney_entries e on e.entry_id = en.entry_id where en.t_id = p_t and e.status <> 'absent' loop
    perform public.world_title_award_check(u, 'tourney');
    perform public.world_cosmetic_award_check(u, 'tourney');
  end loop;
  select owner_id into who from public.world_staff order by owner_id limit 1;
  if who is not null then
    insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
    values ('global', who, '비무 소식', venue || '에서 열린 ' || case when t.mode = 'solo' then '1:1' else '팀전' end || ' 비무회의 장원은 ' || champ_names || '입니다.' || coalesce(' 준우승 ' || runner || '.', ''));
  end if;
end $$;

-- 1분마다: 알림 → 10분 전 출석·대진 → 시작 → 회차 진행 → 마침
create or replace function public.world_tourney_tick() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t public.world_tourneys%rowtype; venue text; n int; p int; i int; arr uuid[]; who uuid; done int := 0; w uuid[];
begin
  perform public.world_tourney_ensure();
  for t in select * from public.world_tourneys where status in ('signup', 'locked', 'running') and starts_at < now() + interval '61 minutes' order by starts_at for update loop
    select region_name into venue from public.world_map_regions where region_id = t.venue_region;
    if t.status = 'signup' then
      if t.alerts < 1 and now() >= t.starts_at - interval '60 minutes' then
        insert into public.world_notifications(user_id, kind, title, content, payload)
        select owner_id, 'tourney_alert', '비무회 한 시간 전', '한 시간 뒤 ' || venue || '에서 비무회가 열립니다. 미리 도착해 작전을 정하세요(정하지 않으면 균형).', jsonb_build_object('t_id', t.t_id)
          from public.world_tourney_entrants where t_id = t.t_id;
        update public.world_tourneys set alerts = 1 where t_id = t.t_id;
      end if;
      if t.alerts < 2 and now() >= t.starts_at - interval '30 minutes' then
        insert into public.world_notifications(user_id, kind, title, content, payload)
        select owner_id, 'tourney_alert', '비무회 30분 전', '30분 뒤 ' || venue || '에서 비무회가 열립니다. 10분 전까지 개최지에 있어야 합니다.', jsonb_build_object('t_id', t.t_id)
          from public.world_tourney_entrants where t_id = t.t_id;
        update public.world_tourneys set alerts = 2 where t_id = t.t_id;
      end if;
      if now() >= t.starts_at - interval '10 minutes' then
        -- 출석: 모든 구성원이 개최지에 있고 쓰러지지 않았어야 한다
        update public.world_tourney_entries e set status = 'absent'
         where e.t_id = t.t_id and exists (select 1 from unnest(e.members) u join public.world_characters c on c.owner_id = u
                                            where c.location is distinct from venue or c.downed_at is not null or coalesce(c.is_dead, false));
        insert into public.world_notifications(user_id, kind, title, content, payload)
        select en.owner_id, 'tourney_alert', '비무회 불참', '시작 10분 전에 ' || venue || '에 없어(또는 쓰러져 있어) 이번 비무회에 나서지 못했습니다.', jsonb_build_object('t_id', t.t_id)
          from public.world_tourney_entrants en join public.world_tourney_entries e on e.entry_id = en.entry_id where en.t_id = t.t_id and e.status = 'absent';
        select count(*) into n from public.world_tourney_entries where t_id = t.t_id and status = 'in';
        if n < 4 then
          update public.world_tourneys set status = 'cancelled', updated_at = now() where t_id = t.t_id;
          insert into public.world_notifications(user_id, kind, title, content, payload)
          select owner_id, 'tourney_alert', '비무회 취소', '나선 ' || case when t.mode = 'solo' then '사람' else '팀' end || '이 넷이 되지 않아 이번 비무회는 열리지 않습니다.', jsonb_build_object('t_id', t.t_id)
            from public.world_tourney_entrants where t_id = t.t_id;
          continue;
        end if;
        p := 1; while p < n loop p := p * 2; end loop;
        select array_agg(entry_id order by random()) into arr from public.world_tourney_entries where t_id = t.t_id and status = 'in';
        update public.world_tourney_entries e set seed = array_position(arr, e.entry_id) where e.t_id = t.t_id and e.status = 'in';
        for i in 1..(p / 2) loop
          insert into public.world_tourney_matches(t_id, round, slot, a, b) values (t.t_id, 1, i, arr[i], arr[p + 1 - i]);
        end loop;
        update public.world_tourneys set status = 'locked', rounds = round(ln(p) / ln(2))::int, round = 1, updated_at = now() where t_id = t.t_id;
        insert into public.world_notifications(user_id, kind, title, content, payload)
        select en.owner_id, 'tourney_alert', '비무회 대진 확정', '대진이 정해졌습니다. 21시에 ' || venue || '에서 첫 경기가 펼쳐집니다.', jsonb_build_object('t_id', t.t_id)
          from public.world_tourney_entrants en join public.world_tourney_entries e on e.entry_id = en.entry_id where en.t_id = t.t_id and e.status = 'in';
      end if;
    elsif t.status = 'locked' and now() >= t.starts_at then
      update public.world_tourneys set status = 'running', updated_at = now() where t_id = t.t_id;
      perform public.world_tourney_play_round(t.t_id);
      done := done + 1;
    elsif t.status = 'running' and now() >= t.round_at then
      if t.round >= t.rounds then perform public.world_tourney_finish(t.t_id);
      else
        select array_agg(winner order by slot) into w from public.world_tourney_matches where t_id = t.t_id and round = t.round;
        for i in 1..(cardinality(w) / 2) loop
          insert into public.world_tourney_matches(t_id, round, slot, a, b) values (t.t_id, t.round + 1, i, w[2 * i - 1], w[2 * i]);
        end loop;
        update public.world_tourneys set round = round + 1 where t_id = t.t_id;
        perform public.world_tourney_play_round(t.t_id);
      end if;
      done := done + 1;
    end if;
  end loop;
  return jsonb_build_object('worked', done);
end $$;

-- 비무 방(게시판): 이번 주 두 대회 · 내 신청·작전 · 지난 결과(일주일)
create or replace function public.world_tourney_board() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_tourney_ensure();
  select * into c from public.world_characters where owner_id = uid;
  return jsonb_build_object('now', now(), 'here_safe', coalesce((public.world_field_region(c.location)).is_safe_zone, false),
    'current', (select coalesce(jsonb_agg(jsonb_build_object('t_id', t.t_id, 'mode', t.mode, 'status', t.status, 'venue', t.venue_region,
        'venue_name', (select region_name from public.world_map_regions where region_id = t.venue_region), 'signup_ends', t.signup_ends, 'starts_at', t.starts_at, 'round', t.round, 'rounds', t.rounds,
        'count', (select count(*) from public.world_tourney_entries e where e.t_id = t.t_id and e.status <> 'absent'),
        'entries', (select coalesce(jsonb_agg(array_to_string(e.names, '·') order by e.created_at), '[]'::jsonb) from public.world_tourney_entries e where e.t_id = t.t_id),
        'mine', (select jsonb_build_object('entry_id', en.entry_id, 'tactic', en.tactic, 'names', e.names, 'status', e.status) from public.world_tourney_entrants en
                   join public.world_tourney_entries e on e.entry_id = en.entry_id where en.t_id = t.t_id and en.owner_id = uid)) order by t.starts_at), '[]'::jsonb)
      from public.world_tourneys t where t.week = date_trunc('week', now() at time zone 'Asia/Seoul')::date),
    'past', (select coalesce(jsonb_agg(jsonb_build_object('t_id', t.t_id, 'mode', t.mode, 'status', t.status, 'starts_at', t.starts_at, 'result', t.result,
        'venue_name', (select region_name from public.world_map_regions where region_id = t.venue_region)) order by t.starts_at desc), '[]'::jsonb)
      from public.world_tourneys t where t.status in ('done', 'cancelled') and t.starts_at > now() - interval '8 days'),
    'party', (select coalesce(jsonb_agg(jsonb_build_object('id', m2.owner_id, 'name', ch.character_name)), '[]'::jsonb)
      from public.world_party_members m join public.world_party_members m2 on m2.party_id = m.party_id and m2.owner_id <> uid
      join public.world_characters ch on ch.owner_id = m2.owner_id where m.owner_id = uid));
end $$;

-- 대진표와 경기 기록. 진행 중인 회차의 기록은 개최지에 있는 사람과 참가자에게만 보인다(끝난 대회는 모두)
create or replace function public.world_tourney_view(p_t uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); t public.world_tourneys%rowtype; c public.world_characters%rowtype; can_watch boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into t from public.world_tourneys where t_id = p_t;
  if not found then raise exception '없는 대회입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  can_watch := t.status in ('done', 'cancelled') or c.location = (select region_name from public.world_map_regions where region_id = t.venue_region)
               or exists (select 1 from public.world_tourney_entrants where t_id = p_t and owner_id = uid);
  return jsonb_build_object('now', now(), 't_id', t.t_id, 'mode', t.mode, 'status', t.status, 'round', t.round, 'rounds', t.rounds, 'starts_at', t.starts_at, 'round_at', t.round_at,
    'venue_name', (select region_name from public.world_map_regions where region_id = t.venue_region), 'result', t.result, 'can_watch', can_watch,
    'entries', (select coalesce(jsonb_object_agg(e.entry_id, jsonb_build_object('names', e.names, 'status', e.status, 'place', e.place, 'seed', e.seed, 'mine', uid = any (e.members))), '{}'::jsonb)
                  from public.world_tourney_entries e where e.t_id = p_t),
    'matches', (select coalesce(jsonb_agg(jsonb_build_object('id', m.match_id, 'round', m.round, 'slot', m.slot, 'a', m.a, 'b', m.b,
        'winner', case when m.ends_at <= now() or t.status = 'done' then m.winner end, 'starts_at', m.starts_at, 'ends_at', m.ends_at, 'exchanges', m.exchanges,
        'log', case when can_watch then m.log end) order by m.round, m.slot), '[]'::jsonb) from public.world_tourney_matches m where m.t_id = p_t));
end $$;

do $$ declare fn text; begin
  foreach fn in array array['world_tourney_ensure()', 'world_tourney_signup(text,uuid)', 'world_tourney_cancel(text)', 'world_tourney_tactic(text,text,text[],text)',
    'world_tourney_duel(uuid,uuid,uuid)', 'world_tourney_play_round(uuid)', 'world_tourney_finish(uuid)', 'world_tourney_tick()', 'world_tourney_board()', 'world_tourney_view(uuid)'] loop
    execute format('alter function public.%s owner to fn_owner_field', fn);
  end loop;
  set role fn_owner_field;
  revoke all on function public.world_tourney_ensure(), public.world_tourney_duel(uuid, uuid, uuid), public.world_tourney_play_round(uuid), public.world_tourney_finish(uuid),
    public.world_tourney_tick() from public, anon, authenticated;
  revoke all on function public.world_tourney_signup(text, uuid), public.world_tourney_cancel(text), public.world_tourney_tactic(text, text, text[], text),
    public.world_tourney_board(), public.world_tourney_view(uuid) from public, anon;
  grant execute on function public.world_tourney_signup(text, uuid), public.world_tourney_cancel(text), public.world_tourney_tactic(text, text, text[], text),
    public.world_tourney_board(), public.world_tourney_view(uuid) to authenticated;
  reset role;
end $$;
grant select, insert on public.world_faction_unlocks, public.world_owned_mounts to fn_owner_field;
grant select on public.world_staff, public.world_party_members to fn_owner_field;
grant insert on public.world_chat_messages to fn_owner_field;
select cron.schedule('yh-tourney', '* * * * *', 'select public.world_tourney_tick()');

-- 칭호·꾸미기 규칙 'tourney'(비무회 기록으로 센다)
create or replace function public.world_tourney_rule_count(p_owner uuid, p_rule jsonb) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(case p_rule ->> 'tourney'
    when 'join' then (select count(*) from public.world_tourney_entries e join public.world_tourneys t on t.t_id = e.t_id where t.status = 'done' and e.status <> 'absent' and p_owner = any (e.members))
    when 'win' then (select count(*) from public.world_tourney_matches m join public.world_tourney_entries e on e.entry_id = m.winner join public.world_tourneys t on t.t_id = m.t_id
                      where t.status = 'done' and m.a is not null and m.b is not null and p_owner = any (e.members))
    when 'top4' then (select count(*) from public.world_tourney_entries e join public.world_tourneys t on t.t_id = e.t_id where t.status = 'done' and e.place <= 3 and p_owner = any (e.members))
    when 'final' then (select count(*) from public.world_tourney_entries e join public.world_tourneys t on t.t_id = e.t_id where t.status = 'done' and e.place <= 2 and p_owner = any (e.members))
    when 'champ' then (select count(*) from public.world_tourney_entries e join public.world_tourneys t on t.t_id = e.t_id where t.status = 'done' and e.place = 1 and p_owner = any (e.members))
    when 'solo_champ' then (select count(*) from public.world_tourney_entries e join public.world_tourneys t on t.t_id = e.t_id where t.status = 'done' and t.mode = 'solo' and e.place = 1 and p_owner = any (e.members))
    when 'team_champ' then (select count(*) from public.world_tourney_entries e join public.world_tourneys t on t.t_id = e.t_id where t.status = 'done' and t.mode = 'team' and e.place = 1 and p_owner = any (e.members))
    when 'flawless' then (select count(*) from public.world_tourney_entries e join public.world_tourneys t on t.t_id = e.t_id where t.status = 'done' and e.place = 1 and e.flawless and p_owner = any (e.members))
  end, 0)
$$;
revoke all on function public.world_tourney_rule_count(uuid, jsonb) from public, anon, authenticated;
do $$ declare o text; begin
  foreach o in array array[(select pg_get_userbyid(proowner) from pg_proc where oid = 'public.world_title_rule_ok(uuid,jsonb)'::regprocedure),
                           (select pg_get_userbyid(proowner) from pg_proc where oid = 'public.world_title_rule_progress(uuid,jsonb)'::regprocedure)] loop
    execute format('grant execute on function public.world_tourney_rule_count(uuid, jsonb) to %I', o);
    execute format('grant select on public.world_tourney_entries, public.world_tourneys, public.world_tourney_matches to %I', o);
  end loop;
end $$;
select pg_temp.yh_patch('public.world_title_rule_ok(uuid,jsonb)', 'ELSIF p_rule ? ''raid'' THEN RETURN public.world_raid_rule_count(p_owner, p_rule) >= n;',
  'ELSIF p_rule ? ''tourney'' THEN RETURN public.world_tourney_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? ''raid'' THEN RETURN public.world_raid_rule_count(p_owner, p_rule) >= n;');
select pg_temp.yh_patch('public.world_title_rule_progress(uuid,jsonb)', 'elsif p_rule ? ''raid'' then', 'elsif p_rule ? ''tourney'' then v := public.world_tourney_rule_count(p_owner, p_rule);
  elsif p_rule ? ''raid'' then');
select pg_temp.yh_patch('public.world_title_award_check(uuid,text)', 'IF r ? ''raid'' AND p_event_type IS NOT NULL AND p_event_type <> ''raid'' THEN CONTINUE; END IF;',
  'IF r ? ''raid'' AND p_event_type IS NOT NULL AND p_event_type <> ''raid'' THEN CONTINUE; END IF; IF r ? ''tourney'' AND p_event_type IS NOT NULL AND p_event_type <> ''tourney'' THEN CONTINUE; END IF;');

-- 보상: 칭호(능력치 효과 없음) · 꾸미기 · 탈것
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
 ('tn_first', '비무대에 오른 이', 'flag', '야행 비무회의 비무대에 처음 올랐다.', '비무회에 한 번 나선다', '{}', true, false, '{"tourney": "join", "n": 1}', 1200, '비무회', 1),
 ('tn_win1', '첫 승의 함성', 'flag', '비무회에서 처음으로 이겼다.', '비무회 경기에서 1번 이긴다', '{}', true, false, '{"tourney": "win", "n": 1}', 1201, '비무회', 1),
 ('tn_win5', '비무대의 단골', 'flag', '비무회에서 다섯 번 이겼다.', '비무회 경기에서 5번 이긴다', '{}', true, false, '{"tourney": "win", "n": 5}', 1202, '비무회', 2),
 ('tn_win20', '스무 판의 칼끝', 'flag', '비무회에서 스무 번 이겼다.', '비무회 경기에서 20번 이긴다', '{}', true, false, '{"tourney": "win", "n": 20}', 1203, '비무회', 3),
 ('tn_top4', '사강의 이름', 'flag', '비무회 네 자리 안에 이름을 올렸다.', '비무회에서 4강에 든다', '{}', true, false, '{"tourney": "top4", "n": 1}', 1204, '비무회', 3),
 ('tn_final', '마지막 비무대', 'flag', '비무회 결승에 올랐다.', '비무회 결승에 오른다', '{}', true, false, '{"tourney": "final", "n": 1}', 1205, '비무회', 3),
 ('tn_champ', '비무 장원', 'flag', '야행 비무회에서 우승했다.', '비무회에서 우승한다', '{}', true, false, '{"tourney": "champ", "n": 1}', 1206, '비무회', 4),
 ('tn_champ3', '세 번의 장원', 'flag', '비무회에서 세 번 우승했다.', '비무회에서 3번 우승한다', '{}', true, false, '{"tourney": "champ", "n": 3}', 1207, '비무회', 5),
 ('tn_champ10', '천하제일 비무객', 'flag', '비무회에서 열 번 우승했다.', '비무회에서 10번 우승한다', '{}', true, false, '{"tourney": "champ", "n": 10}', 1208, '비무회', 5),
 ('tn_team', '쌍검의 장원', 'flag', '비무회 팀전에서 우승했다.', '비무회 팀전에서 우승한다', '{}', true, false, '{"tourney": "team_champ", "n": 1}', 1209, '비무회', 4),
 ('tn_flawless', '흠 없는 장원', 'flag', '한 번도 무릎 꿇지 않고, 기세를 절반 넘게 지킨 채 우승했다.', '비무회의 모든 경기에서 아무도 쓰러지지 않고 기세 절반 넘게 남긴 채 우승한다', '{}', true, true, '{"tourney": "flawless", "n": 1}', 1210, '비무회', 5)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule,
  category = excluded.category, grade = excluded.grade, hidden = excluded.hidden;
insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
 ('pt_tn_join', 'pattern', 'rare', '비무 깃발 무늬', '비무회에 한 번 나선다', '비무회', '{"tourney": "join", "n": 1}', false, true, 1200),
 ('fr_tn_solo', 'frame', 'legend', '장원 금테', '1:1 비무회에서 우승한다', '비무회', '{"tourney": "solo_champ", "n": 1}', false, true, 1201),
 ('fr_tn_team', 'frame', 'legend', '쌍룡 테', '비무회 팀전에서 우승한다', '비무회', '{"tourney": "team_champ", "n": 1}', false, true, 1202),
 ('sl_tn_solo', 'seal', 'legend', '낙관 「武」', '1:1 비무회에서 우승한다', '비무회', '{"tourney": "solo_champ", "n": 1}', false, true, 1203),
 ('sl_tn_team', 'seal', 'legend', '낙관 「雙」', '비무회 팀전에서 우승한다', '비무회', '{"tourney": "team_champ", "n": 1}', false, true, 1204)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, category = excluded.category;
insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method)
values ('tn_white_horse', '비무 장원 백마', 2.2, 1, 0, 0, '비무회에서 세 번 우승한 조사원에게 내리는 흰 말. 갈기에 장원의 붉은 술을 달았다. 운임은 구간당 노정패 1.', '영물', 2, 1, false, 'event')
on conflict (mount_id) do update set description = excluded.description, speed_multiplier = excluded.speed_multiplier;
select pg_temp.yh_patch('public.world_notify_group(text)', 'when p_kind in (''spar_request'', ''spar_result'') then ''spar''', 'when p_kind in (''spar_request'', ''spar_result'', ''tourney_alert'', ''tourney_result'', ''tourney_partner'') then ''spar''');
