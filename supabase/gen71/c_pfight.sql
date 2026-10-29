
-- ─────────────────────────────────────────────────────────────
-- C. 파티 현장 토벌(라운드 10초)
--   현장 토벌 중인 조사원이 「동료 부르기」 → 같은 곳 파티원에게 합류 알림(60초) → 합류하면 탐색력 1, 요괴 체력 +70%(기준 체력)씩
--   라운드마다 참가자마다 행동 하나(공격·기술·방어·물품·달아나기, 안 고르면 방어)를 10초 안에 고르고, 모두 고르거나 마감이 지나면
--   누군가 화면을 읽을 때(world_pfight_snapshot·act) 서버가 한 번에 푼다(예약 작업 없음).
--   풀기: 혼자 토벌 함수(world_battle_action)를 참가자마다 그 사람으로 부른다 — 요괴는 이목^1.3으로 고른 한 명(표적)의 차례에만 반격하고,
--   나머지는 yh.pf_skip으로 반격을 건너뛴다. 기술·기믹·탄환·내구도·상태이상·보상·기록은 혼자 토벌과 똑같다.
--   이기면 참가자마다 혼자 토벌과 같은 보상(전리품은 각자 굴림)에 경험치 +10%/명(3명까지).
-- ─────────────────────────────────────────────────────────────
create table if not exists public.world_pfights (
  fight_id uuid primary key default gen_random_uuid(),
  party_id uuid not null,
  region_id text not null,
  leader_id uuid not null,
  monster_id text not null,
  monster_name text,
  rank text,
  mlevel int,
  base_hp int not null,
  max_hp int not null,
  hp int not null,
  intent text,
  fx jsonb not null default '{}'::jsonb,
  status text not null default 'gather' check (status in ('gather', 'fight', 'won', 'lost', 'fled', 'cancelled')),
  round int not null default 0,
  round_ends timestamptz,
  gather_ends timestamptz not null,
  target_id uuid,
  log jsonb not null default '[]'::jsonb,
  result jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists world_pfights_live on public.world_pfights(party_id) where status in ('gather', 'fight');
create table if not exists public.world_pfight_members (
  fight_id uuid not null references public.world_pfights(fight_id) on delete cascade,
  owner_id uuid not null,
  name text,
  joined_at timestamptz not null default now(),
  action text,
  item text,
  out_reason text,
  primary key (fight_id, owner_id)
);
create unique index if not exists world_pfight_members_live on public.world_pfight_members(owner_id) where out_reason is null;
alter table public.world_pfights enable row level security;
alter table public.world_pfight_members enable row level security;
revoke all on public.world_pfights, public.world_pfight_members from anon, authenticated;
grant select, insert, update, delete on public.world_pfights, public.world_pfight_members to fn_owner_field;

-- 혼자 토벌 함수: 파티 토벌 중에는 직접 못 부르고, 풀 때(yh.pf_resolve)는 1초 간격을 건너뛰며, 표적이 아닌 참가자(yh.pf_skip)는 요괴가 반격하지 않는다
select pg_temp.yh_patch('public.world_battle_action(text,text)', 'raw_m int; absorb int; brk numeric := 0.15; eva_now numeric; n_hit int := 0; ammo_k text;',
  'raw_m int; absorb int; brk numeric := 0.15; eva_now numeric; n_hit int := 0; ammo_k text;
  pf_skip boolean := coalesce(current_setting(''yh.pf_skip'', true), '''') = ''1''; pf_on boolean := coalesce(current_setting(''yh.pf_resolve'', true), '''') = ''1'';');
select pg_temp.yh_patch('public.world_battle_action(text,text)', 'skip_monster boolean := false;', 'skip_monster boolean := coalesce(current_setting(''yh.pf_skip'', true), '''') = ''1'';');
select pg_temp.yh_patch('public.world_battle_action(text,text)', '  IF a.last_action_at IS NOT NULL AND a.last_action_at > now() - interval ''1 second'' THEN',
  '  IF NOT pf_on AND EXISTS (SELECT 1 FROM public.world_pfight_members pm JOIN public.world_pfights pf ON pf.fight_id = pm.fight_id
             WHERE pm.owner_id = uid AND pm.out_reason IS NULL AND pf.status IN (''gather'', ''fight'')) THEN
    RAISE EXCEPTION ''파티 토벌 중입니다. 파티 토벌 화면에서 이번 라운드 행동을 고르세요.''; END IF;
  IF NOT pf_on AND a.last_action_at IS NOT NULL AND a.last_action_at > now() - interval ''1 second'' THEN');
select pg_temp.yh_patch('public.world_battle_action(text,text)', '    IF coalesce((v_fx ->> ''stunned'')::int, 0) > 0 THEN
      skip_monster := true;',
  '    IF NOT pf_skip AND coalesce((v_fx ->> ''stunned'')::int, 0) > 0 THEN
      skip_monster := true;');
select pg_temp.yh_patch('public.world_battle_action(text,text)', 'IF dmg + ex_total >= a.max_hp * brk THEN',
  'IF dmg + ex_total + coalesce(nullif(current_setting(''yh.pf_dmg'', true), '''')::int, 0) >= a.max_hp * brk THEN');
select pg_temp.yh_patch('public.world_battle_action(text,text)', 'xp := round((6 + a.mlevel * 3) * rk_mul * public.world_xp_gap_mul(a.mlevel - c.level));',
  'xp := round((6 + a.mlevel * 3) * rk_mul * public.world_xp_gap_mul(a.mlevel - c.level)
      * (1 + 0.1 * least(3, greatest(0, coalesce(nullif(current_setting(''yh.pf_n'', true), '''')::int, 1) - 1))));');

-- 지금 내가 든 파티 토벌(없으면 null)
create or replace function public.world_pfight_mine() returns uuid
language sql stable security definer set search_path = '' as $$
  select pm.fight_id from public.world_pfight_members pm join public.world_pfights pf on pf.fight_id = pm.fight_id
   where pm.owner_id = public.fn_owner_auth_uid() and pm.out_reason is null and pf.status in ('gather', 'fight') limit 1
$$;

-- 합류할 수 있는 동료: 같은 파티·같은 곳·쓰러지지 않음·다른 전투·원정·이동·자율 중이 아님
create or replace function public.world_pfight_ready(p_uid uuid, p_region text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.world_characters c where c.owner_id = p_uid
      and not coalesce(c.is_dead, false) and c.downed_at is null and c.health > 0 and c.travel_destination is null
      and (public.world_field_region(c.location)).region_id = p_region)
    and not exists (select 1 from public.world_active_encounters a where a.owner_id = p_uid and not a.defeated and not coalesce(a.fled, false))
    and not exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active')
    and not exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = 'active')
    and not exists (select 1 from public.world_pfight_members pm join public.world_pfights pf on pf.fight_id = pm.fight_id
                     where pm.owner_id = p_uid and pm.out_reason is null and pf.status in ('gather', 'fight'))
$$;

-- 동료 부르기: 지금 싸우는 요괴로 파티 토벌을 연다(60초 동안 합류를 받음)
create or replace function public.world_pfight_call() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; a public.world_active_encounters%rowtype; pid uuid; fid uuid; nm text; n int := 0; u uuid;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select * into a from public.world_active_encounters where owner_id = uid for update;
  if not found or a.defeated or coalesce(a.fled, false) or a.mlevel is null then raise exception '싸우고 있는 요괴가 없습니다.'; end if;
  if public.world_pfight_mine() is not null then raise exception '이미 파티 토벌 중입니다.'; end if;
  select party_id into pid from public.world_party_members where owner_id = uid;
  if pid is null then raise exception '파티에 들어 있어야 동료를 부를 수 있습니다.'; end if;
  select monster_name into nm from public.world_region_monsters where monster_id = a.monster_id;
  for u in select m.owner_id from public.world_party_members m where m.party_id = pid and m.owner_id <> uid loop
    if public.world_pfight_ready(u, a.region_id) then n := n + 1; end if;
  end loop;
  if n = 0 then raise exception '같은 곳에서 합류할 수 있는 파티원이 없습니다(전투·원정·이동·자율 중이거나 쓰러진 동료는 부를 수 없습니다).'; end if;
  insert into public.world_pfights(party_id, region_id, leader_id, monster_id, monster_name, rank, mlevel, base_hp, max_hp, hp, intent, fx, gather_ends, log)
  values (pid, a.region_id, uid, a.monster_id, nm, a.rank, a.mlevel, a.max_hp, a.max_hp, a.current_hp, a.intent, coalesce(a.fx, '{}'::jsonb), now() + interval '60 seconds',
          jsonb_build_array(c.character_name || '이(가) 동료를 불렀다. ' || nm || '와(과)의 싸움에 합류할 동료를 60초 동안 기다린다.'))
  returning fight_id into fid;
  insert into public.world_pfight_members(fight_id, owner_id, name) values (fid, uid, c.character_name);
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select m.owner_id, 'pfight_invite', '동료가 부릅니다', c.character_name || '이(가) ' || nm || '와(과) 싸우며 도움을 청합니다. 60초 안에 합류하세요(탐색력 1).',
         jsonb_build_object('fight_id', fid, 'region_id', a.region_id)
    from public.world_party_members m where m.party_id = pid and m.owner_id <> uid and public.world_pfight_ready(m.owner_id, a.region_id);
  return jsonb_build_object('ok', true, 'fight_id', fid, 'invited', n, 'content', '동료 ' || n || '명에게 합류를 청했습니다.');
end $$;

-- 합류: 탐색력 1, 내 전투(같은 요괴)를 만들고 요괴 체력을 기준 체력의 70%만큼 늘린다(4명까지)
create or replace function public.world_pfight_join(p_fight uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; f public.world_pfights%rowtype; la public.world_active_encounters%rowtype; add_hp int;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into f from public.world_pfights where fight_id = p_fight for update;
  if not found or f.status not in ('gather', 'fight') or now() > f.gather_ends then raise exception '이미 끝났거나 합류 시간이 지난 싸움입니다.'; end if;
  if not exists (select 1 from public.world_party_members m where m.party_id = f.party_id and m.owner_id = uid) then raise exception '같은 파티원만 합류할 수 있습니다.'; end if;
  if exists (select 1 from public.world_pfight_members where fight_id = p_fight and owner_id = uid) then raise exception '이미 합류했습니다.'; end if;
  if (select count(*) from public.world_pfight_members where fight_id = p_fight and out_reason is null) >= 4 then raise exception '이미 네 명이 싸우고 있습니다.'; end if;
  if not public.world_pfight_ready(uid, f.region_id) then raise exception '지금은 합류할 수 없습니다(같은 곳에 있어야 하고, 전투·원정·이동·자율 중이거나 쓰러져 있으면 안 됩니다).'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  perform public.world_stamina_change(uid, -1);
  select * into la from public.world_active_encounters where owner_id = f.leader_id;
  add_hp := round(f.base_hp * 0.7);
  update public.world_pfights set max_hp = max_hp + add_hp, hp = hp + add_hp, updated_at = now(),
    log = log || jsonb_build_array(c.character_name || '이(가) 싸움에 뛰어들었다. ' || monster_name || '이(가) 더 사납게 울부짖는다.')
   where fight_id = p_fight returning * into f;
  insert into public.world_active_encounters(owner_id, region_id, monster_id, current_hp, max_hp, defeated, fled, started_at, updated_at,
    turn_count, analysis_turns, guard_until_turn, node_id, mlevel, atk, def, rank, intent, fx, pfx, log, last_action_at, result)
  values (uid, f.region_id, f.monster_id, f.hp, f.max_hp, false, false, now(), now(), 0, 0, 0, la.node_id, f.mlevel, la.atk, la.def, f.rank, f.intent, f.fx, '{}',
    jsonb_build_array(f.monster_name || '와(과)의 싸움에 합류했다.'), null, null)
  on conflict (owner_id) do update set region_id = excluded.region_id, monster_id = excluded.monster_id, current_hp = excluded.current_hp, max_hp = excluded.max_hp,
    defeated = false, fled = false, started_at = now(), updated_at = now(), turn_count = 0, analysis_turns = 0, guard_until_turn = 0, node_id = excluded.node_id,
    mlevel = excluded.mlevel, atk = excluded.atk, def = excluded.def, rank = excluded.rank, intent = excluded.intent, fx = excluded.fx, pfx = '{}',
    log = excluded.log, last_action_at = null, result = null;
  insert into public.world_pfight_members(fight_id, owner_id, name) values (p_fight, uid, c.character_name);
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (f.leader_id, 'pfight_join', '동료 합류', c.character_name || '이(가) 싸움에 합류했습니다.', jsonb_build_object('fight_id', p_fight));
  return jsonb_build_object('ok', true, 'fight_id', p_fight, 'content', f.monster_name || '와(과)의 싸움에 합류했습니다.');
end $$;

-- 싸움을 연 사람이 기다리지 않고 바로 시작(합류한 동료가 없으면 다시 혼자 싸운다)
create or replace function public.world_pfight_start(p_fight uuid, p_force boolean default false) returns void
language plpgsql security definer set search_path = '' as $$
declare f public.world_pfights%rowtype; n int;
begin
  select * into f from public.world_pfights where fight_id = p_fight for update;
  if not found or f.status <> 'gather' then return; end if;
  if not p_force and now() < f.gather_ends then return; end if;
  select count(*) into n from public.world_pfight_members where fight_id = p_fight and out_reason is null;
  if n < 2 then
    update public.world_pfights set status = 'cancelled', updated_at = now(), log = log || jsonb_build_array('합류한 동료가 없어 다시 혼자 싸운다.') where fight_id = p_fight;
    update public.world_pfight_members set out_reason = 'done' where fight_id = p_fight and out_reason is null;
    return;
  end if;
  update public.world_pfights set status = 'fight', round = 1, round_ends = now() + interval '10 seconds', updated_at = now(),
    log = log || jsonb_build_array('— 1라운드 · 10초 안에 행동을 고르세요(고르지 않으면 방어) —') where fight_id = p_fight;
  -- 요괴 체력·기세를 모두에게 맞춘다
  update public.world_active_encounters a set current_hp = f.hp, max_hp = f.max_hp, intent = f.intent, fx = f.fx
    from public.world_pfight_members pm where pm.fight_id = p_fight and pm.out_reason is null and a.owner_id = pm.owner_id;
end $$;
create or replace function public.world_pfight_begin(p_fight uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_pfights%rowtype;
begin
  select * into f from public.world_pfights where fight_id = p_fight;
  if not found or f.leader_id is distinct from uid then raise exception '싸움을 연 사람만 시작할 수 있습니다.'; end if;
  perform public.world_pfight_start(p_fight, true);
  return public.world_pfight_snapshot(p_fight);
end $$;

-- 라운드 풀기(마감이 지났거나 모두 골랐을 때만)
create or replace function public.world_pfight_resolve(p_fight uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare f public.world_pfights%rowtype; mm record; tgt uuid; n int; r jsonb; e public.world_active_encounters%rowtype; ln text; lines jsonb := '[]'::jsonb;
  oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true);
  won boolean := false; dealt int := 0; before int; act text; alive int;
begin
  select * into f from public.world_pfights where fight_id = p_fight for update;
  if not found or f.status <> 'fight' then return; end if;
  if now() < f.round_ends and exists (select 1 from public.world_pfight_members where fight_id = p_fight and out_reason is null and action is null) then return; end if;
  select count(*) into n from public.world_pfight_members where fight_id = p_fight and out_reason is null;
  -- 표적: 이목^1.3에 비례(쓰러지지 않은 참가자)
  select pm.owner_id into tgt from public.world_pfight_members pm
   where pm.fight_id = p_fight and pm.out_reason is null
   order by -ln(greatest(random(), 1e-9)) / power(greatest(1, coalesce((public.world_combat_stats(pm.owner_id) ->> 'presence')::numeric, 30)), 1.3) limit 1;
  perform set_config('yh.pf_resolve', '1', true);
  perform set_config('yh.pf_n', n::text, true);
  perform set_config('yh.pf_dmg', '0', true);
  lines := jsonb_build_array('— ' || f.round || '라운드 · ' || f.monster_name || '이(가) ' || (select name from public.world_pfight_members where fight_id = p_fight and owner_id = tgt) || '을(를) 노린다 —');
  for mm in select pm.* from public.world_pfight_members pm where pm.fight_id = p_fight and pm.out_reason is null
             order by (pm.owner_id = tgt), pm.joined_at loop
    exit when f.hp <= 0;
    perform set_config('request.jwt.claim.sub', mm.owner_id::text, true);
    perform set_config('request.jwt.claims', json_build_object('sub', mm.owner_id, 'role', 'authenticated')::text, true);
    perform set_config('yh.pf_skip', case when mm.owner_id = tgt then '0' else '1' end, true);
    perform set_config('yh.pf_dmg', dealt::text, true);
    update public.world_active_encounters set current_hp = f.hp, max_hp = f.max_hp, intent = f.intent, fx = f.fx, last_action_at = null
     where owner_id = mm.owner_id and not defeated and not coalesce(fled, false);
    if not found then update public.world_pfight_members set out_reason = 'gone' where fight_id = p_fight and owner_id = mm.owner_id; continue; end if;
    act := coalesce(mm.action, 'guard'); before := f.hp; r := null;
    begin
      r := public.world_battle_action(act, mm.item);
    exception when others then
      lines := lines || jsonb_build_array(mm.name || ' · ' || sqlerrm || ' — 대신 방어했다.');
      begin r := public.world_battle_action('guard', null);
      exception when others then r := null; lines := lines || jsonb_build_array(mm.name || ' · 움직이지 못했다(' || sqlerrm || ').'); end;
    end;
    select * into e from public.world_active_encounters where owner_id = mm.owner_id;
    if r is not null then
      for ln in select jsonb_array_elements_text(coalesce(r -> 'lines', '[]'::jsonb)) loop lines := lines || jsonb_build_array(mm.name || ' · ' || ln); end loop;
      f.hp := e.current_hp; f.fx := coalesce(e.fx, '{}'::jsonb);
      if mm.owner_id = tgt and r ->> 'ended' is null then f.intent := e.intent; end if;
      if before > f.hp then dealt := dealt + (before - f.hp); end if;
      if r ->> 'ended' = 'victory' then won := true;
        update public.world_pfight_members set out_reason = 'won' where fight_id = p_fight and owner_id = mm.owner_id;
      elsif r ->> 'ended' = 'defeat' then update public.world_pfight_members set out_reason = 'down' where fight_id = p_fight and owner_id = mm.owner_id;
      elsif r ->> 'ended' = 'fled' then update public.world_pfight_members set out_reason = 'fled' where fight_id = p_fight and owner_id = mm.owner_id;
      end if;
    end if;
  end loop;
  -- 이겼으면 남은 참가자도 그 자리에서 이긴 것으로(각자 보상·기록)
  if won or f.hp <= 0 then
    won := true;
    for mm in select pm.* from public.world_pfight_members pm where pm.fight_id = p_fight and pm.out_reason is null loop
      perform set_config('request.jwt.claim.sub', mm.owner_id::text, true);
      perform set_config('request.jwt.claims', json_build_object('sub', mm.owner_id, 'role', 'authenticated')::text, true);
      perform set_config('yh.pf_skip', '1', true);
      update public.world_active_encounters set current_hp = 0, last_action_at = null where owner_id = mm.owner_id and not defeated and not coalesce(fled, false);
      begin
        r := public.world_battle_action('guard', null);
        for ln in select jsonb_array_elements_text(coalesce(r -> 'lines', '[]'::jsonb)) loop
          if ln not like '자세를 낮추고%' then lines := lines || jsonb_build_array(mm.name || ' · ' || ln); end if; end loop;
      exception when others then lines := lines || jsonb_build_array(mm.name || ' · 보상을 받지 못했다(' || sqlerrm || ').'); end;
      update public.world_pfight_members set out_reason = 'won' where fight_id = p_fight and owner_id = mm.owner_id;
    end loop;
  end if;
  perform set_config('request.jwt.claims', coalesce(oc, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  perform set_config('yh.pf_resolve', '', true); perform set_config('yh.pf_skip', '', true); perform set_config('yh.pf_n', '', true); perform set_config('yh.pf_dmg', '', true);
  select count(*) into alive from public.world_pfight_members where fight_id = p_fight and out_reason is null;
  if won then
    update public.world_pfights set status = 'won', hp = 0, fx = f.fx, target_id = tgt, updated_at = now(), log = (log || lines || jsonb_build_array('— ' || monster_name || '을(를) 함께 쓰러뜨렸다 —')),
      result = jsonb_build_object('outcome', 'victory', 'rounds', f.round) where fight_id = p_fight;
  elsif alive = 0 then
    update public.world_pfights set status = case when exists (select 1 from public.world_pfight_members where fight_id = p_fight and out_reason = 'down') then 'lost' else 'fled' end,
      hp = f.hp, fx = f.fx, target_id = tgt, updated_at = now(), log = log || lines || jsonb_build_array('— 싸움이 끝났다 —'), result = jsonb_build_object('outcome', 'defeat', 'rounds', f.round)
     where fight_id = p_fight;
  else
    update public.world_pfights set hp = f.hp, fx = f.fx, intent = f.intent, target_id = tgt, round = round + 1, round_ends = now() + interval '10 seconds', updated_at = now(),
      log = log || lines || jsonb_build_array('— ' || (f.round + 1) || '라운드 —') where fight_id = p_fight;
    update public.world_pfight_members set action = null, item = null where fight_id = p_fight and out_reason is null;
    update public.world_active_encounters a set current_hp = f.hp, max_hp = f.max_hp, intent = f.intent, fx = f.fx
      from public.world_pfight_members pm where pm.fight_id = p_fight and pm.out_reason is null and a.owner_id = pm.owner_id;
  end if;
  -- 기록은 마지막 60줄만
  update public.world_pfights set log = (select coalesce(jsonb_agg(x order by o), '[]'::jsonb) from (select x, o from jsonb_array_elements(log) with ordinality t(x, o) order by o desc limit 60) s)
   where fight_id = p_fight and jsonb_array_length(log) > 60;
end $$;

-- 화면이 읽는 값(마감이 지났으면 먼저 푼다)
create or replace function public.world_pfight_snapshot(p_fight uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_pfights%rowtype; me public.world_pfight_members%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into f from public.world_pfights where fight_id = p_fight;
  if not found then raise exception '없는 싸움입니다.'; end if;
  if not exists (select 1 from public.world_party_members m where m.party_id = f.party_id and m.owner_id = uid)
     and not exists (select 1 from public.world_pfight_members where fight_id = p_fight and owner_id = uid) then raise exception '파티원만 볼 수 있습니다.'; end if;
  if f.status = 'gather' and now() >= f.gather_ends then perform public.world_pfight_start(p_fight); end if;
  perform public.world_pfight_resolve(p_fight);
  select * into f from public.world_pfights where fight_id = p_fight;
  select * into me from public.world_pfight_members where fight_id = p_fight and owner_id = uid;
  return jsonb_build_object('fight_id', f.fight_id, 'status', f.status, 'round', f.round, 'leader_id', f.leader_id, 'monster', f.monster_name, 'rank', f.rank, 'level', f.mlevel,
    'hp', f.hp, 'max_hp', f.max_hp, 'intent', f.intent, 'target_id', f.target_id, 'now', now(), 'round_ends', f.round_ends, 'gather_ends', f.gather_ends,
    'log', f.log, 'result', f.result, 'region_id', f.region_id,
    'can_join', me.owner_id is null and f.status in ('gather', 'fight') and now() <= f.gather_ends and public.world_pfight_ready(uid, f.region_id),
    'me', case when me.owner_id is null then null else jsonb_build_object('action', me.action, 'item', me.item, 'out', me.out_reason) end,
    'battle', case when me.owner_id is not null and me.out_reason is null then public.world_field_battle_view(uid) end,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', pm.owner_id, 'name', pm.name, 'chosen', pm.action is not null, 'out', pm.out_reason,
        'health', c.health, 'mental', c.mental, 'sp', c.spiritual_power, 'job', c.job_key) order by pm.joined_at), '[]'::jsonb)
      from public.world_pfight_members pm join public.world_characters c on c.owner_id = pm.owner_id where pm.fight_id = p_fight));
end $$;

-- 이번 라운드 행동 고르기(모두 고르면 바로 푼다)
create or replace function public.world_pfight_act(p_fight uuid, p_action text, p_item text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_pfights%rowtype; a public.world_active_encounters%rowtype; c public.world_characters%rowtype; act text := lower(coalesce(p_action, ''));
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if act not in ('attack', 'skill', 'guard', 'item', 'flee') then raise exception '알 수 없는 행동입니다.'; end if;
  select * into f from public.world_pfights where fight_id = p_fight;
  if not found or f.status <> 'fight' then raise exception '지금은 행동을 고를 수 없습니다.'; end if;
  if not exists (select 1 from public.world_pfight_members where fight_id = p_fight and owner_id = uid and out_reason is null) then raise exception '이 싸움의 참가자가 아닙니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  select * into a from public.world_active_encounters where owner_id = uid;
  if act = 'item' and coalesce((c.inventory ->> coalesce(p_item, ''))::int, 0) < 1 then raise exception '가방에 그 물품이 없습니다.'; end if;
  if act = 'skill' and coalesce((a.pfx ->> 'skill_ready')::int, 0) > coalesce(a.turn_count, 0) + 1 then
    raise exception '%', format('기술은 %s라운드 뒤에 다시 쓸 수 있습니다.', (a.pfx ->> 'skill_ready')::int - a.turn_count - 1); end if;
  if act = 'skill' and c.job_key = 'medic' and (a.pfx ->> 'med_used') is not null then raise exception '응급 처방은 한 전투에 한 번만 쓸 수 있습니다.'; end if;
  update public.world_pfight_members set action = act, item = case when act = 'item' then p_item end where fight_id = p_fight and owner_id = uid;
  perform public.world_pfight_resolve(p_fight);
  return public.world_pfight_snapshot(p_fight);
end $$;

do $$ declare fn text; begin
  foreach fn in array array['world_pfight_mine()', 'world_pfight_ready(uuid,text)', 'world_pfight_call()', 'world_pfight_join(uuid)', 'world_pfight_start(uuid,boolean)',
    'world_pfight_begin(uuid)', 'world_pfight_resolve(uuid)', 'world_pfight_snapshot(uuid)', 'world_pfight_act(uuid,text,text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', fn);
  end loop;
  set role fn_owner_field;
  revoke all on function public.world_pfight_ready(uuid, text), public.world_pfight_start(uuid, boolean), public.world_pfight_resolve(uuid) from public, anon, authenticated;
  revoke all on function public.world_pfight_mine(), public.world_pfight_call(), public.world_pfight_join(uuid), public.world_pfight_begin(uuid),
    public.world_pfight_snapshot(uuid), public.world_pfight_act(uuid, text, text) from public, anon;
  grant execute on function public.world_pfight_mine(), public.world_pfight_call(), public.world_pfight_join(uuid), public.world_pfight_begin(uuid),
    public.world_pfight_snapshot(uuid), public.world_pfight_act(uuid, text, text) to authenticated;
  reset role;
end $$;

-- 알림 갈래: 파티
select pg_temp.yh_patch('public.world_notify_group(text)', '''party_leave'', ''party_aid'')', '''party_leave'', ''party_aid'', ''pfight_invite'', ''pfight_join'')');
