-- 7.7.3 — 파티 현장 토벌을 「10초 라운드(모두 고른 뒤 한꺼번에)」에서 「속도순 차례」로 바꾼다(사용자 요청 2026-11-01).
-- · 라운드마다 남은 참가자를 속도(민첩 + 감각×0.5, world_combat_stats.stats) 높은 순으로 줄 세운다(turn_order).
-- · 자기 차례(turn_id)에 고른 행동(공격·직업 기술·방어·물품·달아나기)이 바로 풀린다 — 세는 시계 없음.
--   차례가 30초 넘게 비면(자리를 비운 사람) 다음에 누가 화면을 읽을 때 방어로 넘긴다(싸움이 멈추지 않게, 화면에는 초를 세지 않음).
-- · 요괴는 라운드 처음에 노릴 사람(target_id, 이목^1.3)을 정하고 그 사람 차례 바로 뒤에 반격한다(그 사람이 방어를 고르면 막는다).
--   노린 사람이 차례 전에 빠지면 그 뒤 차례인 사람을 친다(mon_done).
-- · 기운 모으기 끊기는 그 라운드에 모두가 준 피해(round_dmg)로 본다(전과 같음).
-- 보상·전리품·경험치 +10%/명·탐색력·합류 규칙은 그대로.
lock table public.world_pfights in share row exclusive mode;

alter table public.world_pfights
  add column if not exists turn_id uuid,
  add column if not exists turn_order jsonb not null default '[]'::jsonb,
  add column if not exists round_dmg int not null default 0,
  add column if not exists mon_done boolean not null default false;

-- 함수는 기존 주인(fn_owner_field)으로 만든다(postgres는 그 역할로 SET할 수 있다)
set role fn_owner_field;

-- 라운드 열기: 노릴 사람·속도 순서·첫 차례
create or replace function public.world_pfight_round(p_fight uuid, p_round int)
returns void language plpgsql security definer set search_path to '' as $function$
declare f public.world_pfights%rowtype; tgt uuid; ord jsonb; names text; tname text;
begin
  select * into f from public.world_pfights where fight_id = p_fight for update;
  if not found or f.status <> 'fight' then return; end if;
  select pm.owner_id, pm.name into tgt, tname from public.world_pfight_members pm
   where pm.fight_id = p_fight and pm.out_reason is null
   order by -ln(greatest(random(), 1e-9)) / power(greatest(1, coalesce((public.world_combat_stats(pm.owner_id) ->> 'presence')::numeric, 30)), 1.3) limit 1;
  select jsonb_agg(jsonb_build_object('id', s.owner_id, 'spd', s.spd) order by s.spd desc, s.joined_at),
         string_agg(s.name, ' → ' order by s.spd desc, s.joined_at)
    into ord, names
    from (select pm.owner_id, pm.name, pm.joined_at,
                 round(coalesce((cs -> 'stats' ->> 'agility')::numeric, 0) + coalesce((cs -> 'stats' ->> 'perception')::numeric, 0) * 0.5) spd
            from public.world_pfight_members pm, lateral (select public.world_combat_stats(pm.owner_id) cs) x
           where pm.fight_id = p_fight and pm.out_reason is null) s;
  update public.world_pfights set round = p_round, target_id = tgt, turn_order = coalesce(ord, '[]'::jsonb), turn_id = (ord -> 0 ->> 'id')::uuid,
    round_ends = now() + interval '30 seconds', round_dmg = 0, mon_done = false, updated_at = now(),
    log = log || jsonb_build_array('— ' || p_round || '라운드 · 차례 ' || coalesce(names, '') || ' · ' || f.monster_name || '이(가) ' || coalesce(tname, '') || '을(를) 노린다(그 차례 뒤에 반격) —')
   where fight_id = p_fight;
  update public.world_pfight_members set action = null, item = null where fight_id = p_fight and out_reason is null;
end $function$;

create or replace function public.world_pfight_start(p_fight uuid, p_force boolean default false)
returns void language plpgsql security definer set search_path to '' as $function$
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
  update public.world_pfights set status = 'fight', updated_at = now() where fight_id = p_fight;
  -- 요괴 체력·기세를 모두에게 맞춘다
  update public.world_active_encounters a set current_hp = f.hp, max_hp = f.max_hp, intent = f.intent, fx = f.fx
    from public.world_pfight_members pm where pm.fight_id = p_fight and pm.out_reason is null and a.owner_id = pm.owner_id;
  perform public.world_pfight_round(p_fight, 1);
end $function$;

create or replace function public.world_pfight_act(p_fight uuid, p_action text, p_item text default null)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_pfights%rowtype; a public.world_active_encounters%rowtype; c public.world_characters%rowtype; act text := lower(coalesce(p_action, ''));
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if act not in ('attack', 'skill', 'guard', 'item', 'flee') then raise exception '알 수 없는 행동입니다.'; end if;
  select * into f from public.world_pfights where fight_id = p_fight for update;
  if not found or f.status <> 'fight' then raise exception '지금은 행동을 고를 수 없습니다.'; end if;
  if not exists (select 1 from public.world_pfight_members where fight_id = p_fight and owner_id = uid and out_reason is null) then raise exception '이 싸움의 참가자가 아닙니다.'; end if;
  if f.turn_id is distinct from uid then raise exception '아직 차례가 아닙니다. 앞 사람이 행동하면 차례가 옵니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  select * into a from public.world_active_encounters where owner_id = uid;
  if act = 'item' and coalesce((c.inventory ->> coalesce(p_item, ''))::int, 0) < 1 then raise exception '가방에 그 물품이 없습니다.'; end if;
  if act = 'skill' and coalesce((a.pfx ->> 'skill_ready')::int, 0) > coalesce(a.turn_count, 0) + 1 then
    raise exception '%', format('기술은 %s차례 뒤에 다시 쓸 수 있습니다.', (a.pfx ->> 'skill_ready')::int - a.turn_count - 1); end if;
  if act = 'skill' and c.job_key = 'medic' and (a.pfx ->> 'med_used') is not null then raise exception '응급 처방은 한 전투에 한 번만 쓸 수 있습니다.'; end if;
  update public.world_pfight_members set action = act, item = case when act = 'item' then p_item end where fight_id = p_fight and owner_id = uid;
  perform public.world_pfight_resolve(p_fight);
  return public.world_pfight_snapshot(p_fight);
end $function$;

-- 차례 풀기: 지금 차례인 사람이 골랐거나 30초가 지났으면 그 한 사람을 풀고 다음 차례로. 자리를 비운 차례가 이어지면 여러 번 돈다.
create or replace function public.world_pfight_resolve(p_fight uuid)
returns void language plpgsql security definer set search_path to '' as $function$
declare f public.world_pfights%rowtype; mm public.world_pfight_members%rowtype; r jsonb; e public.world_active_encounters%rowtype; ln text; lines jsonb;
  oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true);
  won boolean := false; before int; act text; alive int; hits boolean; auto boolean; idx int; nxt uuid; guard_i int := 0;
begin
  loop
    guard_i := guard_i + 1; exit when guard_i > 12;
    select * into f from public.world_pfights where fight_id = p_fight for update;
    if not found or f.status <> 'fight' then return; end if;
    if f.turn_id is null then perform public.world_pfight_round(p_fight, greatest(1, f.round)); continue; end if;
    select * into mm from public.world_pfight_members where fight_id = p_fight and owner_id = f.turn_id;
    lines := '[]'::jsonb; r := null; won := false;
    if mm.owner_id is not null and mm.out_reason is null then
      if mm.action is null and now() < f.round_ends then exit; end if;
      auto := mm.action is null; act := coalesce(mm.action, 'guard'); before := f.hp;
      select count(*) into alive from public.world_pfight_members where fight_id = p_fight and out_reason is null;
      hits := not f.mon_done and (mm.owner_id = f.target_id
        or not exists (select 1 from public.world_pfight_members where fight_id = p_fight and owner_id = f.target_id and out_reason is null));
      perform set_config('yh.pf_resolve', '1', true);
      perform set_config('yh.pf_n', alive::text, true);
      perform set_config('yh.pf_dmg', f.round_dmg::text, true);
      perform set_config('yh.pf_skip', case when hits then '0' else '1' end, true);
      perform set_config('request.jwt.claim.sub', mm.owner_id::text, true);
      perform set_config('request.jwt.claims', json_build_object('sub', mm.owner_id, 'role', 'authenticated')::text, true);
      update public.world_active_encounters set current_hp = f.hp, max_hp = f.max_hp, intent = f.intent, fx = f.fx, last_action_at = null
       where owner_id = mm.owner_id and not defeated and not coalesce(fled, false);
      if not found then
        update public.world_pfight_members set out_reason = 'gone' where fight_id = p_fight and owner_id = mm.owner_id;
      else
        if auto then lines := lines || jsonb_build_array(mm.name || ' · 차례를 비워 방어했다.'); end if;
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
          if hits then f.mon_done := true; if r ->> 'ended' is null then f.intent := e.intent; end if; end if;
          if before > f.hp then f.round_dmg := f.round_dmg + (before - f.hp); end if;
          if r ->> 'ended' = 'victory' then won := true;
            update public.world_pfight_members set out_reason = 'won' where fight_id = p_fight and owner_id = mm.owner_id;
          elsif r ->> 'ended' = 'defeat' then update public.world_pfight_members set out_reason = 'down' where fight_id = p_fight and owner_id = mm.owner_id;
          elsif r ->> 'ended' = 'fled' then update public.world_pfight_members set out_reason = 'fled' where fight_id = p_fight and owner_id = mm.owner_id;
          end if;
        end if;
      end if;
      update public.world_pfight_members set action = null, item = null where fight_id = p_fight and owner_id = mm.owner_id;
    end if;
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
      update public.world_pfights set status = 'won', hp = 0, fx = f.fx, turn_id = null, updated_at = now(), log = (log || lines || jsonb_build_array('— ' || monster_name || '을(를) 함께 쓰러뜨렸다 —')),
        result = jsonb_build_object('outcome', 'victory', 'rounds', f.round) where fight_id = p_fight;
      exit;
    elsif alive = 0 then
      update public.world_pfights set status = case when exists (select 1 from public.world_pfight_members where fight_id = p_fight and out_reason = 'down') then 'lost' else 'fled' end,
        hp = f.hp, fx = f.fx, turn_id = null, updated_at = now(), log = log || lines || jsonb_build_array('— 싸움이 끝났다 —'), result = jsonb_build_object('outcome', 'defeat', 'rounds', f.round)
       where fight_id = p_fight;
      exit;
    end if;
    -- 다음 차례: 순서에서 지금 사람 뒤의 남은 참가자, 없으면 다음 라운드
    select o.i into idx from jsonb_array_elements(f.turn_order) with ordinality o(v, i) where (o.v ->> 'id')::uuid = f.turn_id;
    select (o.v ->> 'id')::uuid into nxt from jsonb_array_elements(f.turn_order) with ordinality o(v, i)
      join public.world_pfight_members pm on pm.fight_id = p_fight and pm.owner_id = (o.v ->> 'id')::uuid and pm.out_reason is null
     where o.i > coalesce(idx, 0) order by o.i limit 1;
    update public.world_pfights set hp = f.hp, fx = f.fx, intent = f.intent, round_dmg = f.round_dmg, mon_done = f.mon_done, updated_at = now(),
      turn_id = nxt, round_ends = now() + interval '30 seconds', log = log || lines where fight_id = p_fight;
    update public.world_active_encounters a set current_hp = f.hp, max_hp = f.max_hp, intent = f.intent, fx = f.fx
      from public.world_pfight_members pm where pm.fight_id = p_fight and pm.out_reason is null and a.owner_id = pm.owner_id;
    if nxt is null then perform public.world_pfight_round(p_fight, f.round + 1); end if;
  end loop;
  -- 기록은 마지막 60줄만
  update public.world_pfights set log = (select coalesce(jsonb_agg(x order by o), '[]'::jsonb) from (select x, o from jsonb_array_elements(log) with ordinality t(x, o) order by o desc limit 60) s)
   where fight_id = p_fight and jsonb_array_length(log) > 60;
end $function$;

create or replace function public.world_pfight_snapshot(p_fight uuid)
returns jsonb language plpgsql security definer set search_path to '' as $function$
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
    'hp', f.hp, 'max_hp', f.max_hp, 'intent', f.intent, 'target_id', f.target_id, 'now', now(), 'gather_ends', f.gather_ends,
    'turn_id', f.turn_id, 'my_turn', f.status = 'fight' and f.turn_id = uid, 'mon_done', f.mon_done,
    'order', (select coalesce(jsonb_agg((o.v ->> 'id')::uuid order by o.i), '[]'::jsonb) from jsonb_array_elements(f.turn_order) with ordinality o(v, i)),
    'log', f.log, 'result', f.result, 'region_id', f.region_id,
    'can_join', me.owner_id is null and f.status in ('gather', 'fight') and now() <= f.gather_ends and public.world_pfight_ready(uid, f.region_id),
    'me', case when me.owner_id is null then null else jsonb_build_object('action', me.action, 'item', me.item, 'out', me.out_reason) end,
    'battle', case when me.owner_id is not null and me.out_reason is null then public.world_field_battle_view(uid) end,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', pm.owner_id, 'name', pm.name, 'out', pm.out_reason,
        'spd', (select (o.v ->> 'spd')::int from jsonb_array_elements(f.turn_order) o(v) where (o.v ->> 'id')::uuid = pm.owner_id),
        'health', c.health, 'mental', c.mental, 'sp', c.spiritual_power, 'job', c.job_key) order by pm.joined_at), '[]'::jsonb)
      from public.world_pfight_members pm join public.world_characters c on c.owner_id = pm.owner_id where pm.fight_id = p_fight));
end $function$;

-- 새 도우미는 조사원이 부를 수 없게(주인 역할이 revoke해야 먹힌다)
revoke all on function public.world_pfight_round(uuid, int) from public, anon, authenticated;
reset role;

update public.world_app_meta set value = '20261104201100' where key = 'db_version';
