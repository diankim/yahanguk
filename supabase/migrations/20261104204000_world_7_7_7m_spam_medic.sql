-- 7.7.7m — 연타 부담 줄이기 + 의무관 [야전 처치](사용자 결정 2026-11-01).
--  ① 간격 검사를 잠금·실제 처리보다 앞으로: 채집(12초 — 지금은 world_events 기록 트리거에서야 걸려 채집을 다 처리한 뒤 되돌렸다),
--     봉연·결전 행동(1초 — 모두가 함께 쓰는 토벌 행을 잠근 뒤에 보던 것을 잠그기 전에), 현장 토벌(1초)·낚시(20초)는 캐릭터 행 잠금 앞으로.
--     게임 규칙(간격·문구)은 그대로이고, 너무 이른 요청이 서버에서 일을 덜 한다.
--  ② 의무관 [야전 처치]: 보급품이 떨어졌을 때 원정 한 번에 한 번 체력 +30 → 회복 기준 아래로 내려갈 때마다 보급품보다 먼저, 원정 한 번에 세 번까지 체력 +25(회복 보정 적용).
create or replace function pg_temp.yh_sub(d text, o text, n text, tag text) returns text language plpgsql as $f$
begin
  if (length(d) - length(replace(d, o, ''))) / greatest(1, length(o)) <> 1 then raise exception '7.7.7m anchor %', tag; end if;
  return replace(d, o, n);
end $f$;

-- 행동 간격 검사 공용(7.7.7m): 잠그기 전에 부르는 가벼운 검사. 정확한 검사·동시 요청 막이는 각 함수 본문·기록 트리거에 그대로 있다.
create or replace function public.world_rate_check(p_kind text, p_uid uuid, p_ref uuid default null)
returns void language plpgsql stable set search_path to 'pg_catalog', 'public' as $f$
begin
  if p_uid is null then return; end if;
  if p_kind = 'gather' and exists (select 1 from public.world_events where actor_id = p_uid and event_type = 'gather' and created_at > now() - interval '12 seconds') then
    raise exception '채집은 12초마다 가능합니다. 잠시 후 다시 시도하세요.';
  elsif p_kind = 'fish' and exists (select 1 from public.world_events where actor_id = p_uid and event_type = 'fish' and created_at > now() - interval '15 seconds') then
    raise exception '찌를 다시 던지려면 조금 더 기다리세요.';
  elsif p_kind = 'battle' and exists (select 1 from public.world_active_encounters where owner_id = p_uid and last_action_at > now() - interval '1 second') then
    raise exception '전투 행동 간격이 너무 짧습니다. 잠시 후 다시 시도하세요.';
  elsif p_kind = 'raid' and exists (select 1 from public.world_raid_members where raid_id = p_ref and owner_id = p_uid and last_action_at > now() - interval '1 second') then
    raise exception '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.';
  end if;
end $f$;
revoke all on function public.world_rate_check(text, uuid, uuid) from public, anon, authenticated;
grant execute on function public.world_rate_check(text, uuid, uuid) to fn_owner_field;

do $p$
declare d text;
begin
  -- 채집: 마지막 채집 시각(색인 idx_world_events_actor_type_time)을 잠그기 전에 본다. 기록 트리거의 검사는 동시 요청 막이로 그대로 둔다.
  d := replace(pg_get_functiondef('public.world_field_gather(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('7.7.7m' in d) = 0 then
    d := pg_temp.yh_sub(d, '  if uid is null then raise exception ''로그인이 필요합니다.''; end if;
  select * into c from public.world_characters where owner_id = uid for update;',
      '  if uid is null then raise exception ''로그인이 필요합니다.''; end if;
  -- 7.7.7m: 12초 간격을 잠그기 전에(연타가 채집을 다 처리한 뒤 되돌리지 않게)
  perform public.world_rate_check(''gather'', uid);
  select * into c from public.world_characters where owner_id = uid for update;', 'gather');
    execute d;
  end if;

  -- 낚시: 간격(기본 20초, 「재빠른 챔질」 15초)을 잠그기 전에 짧은 쪽(15초)으로 한 번 더 — 정확한 간격 검사는 본문에 그대로
  d := replace(pg_get_functiondef('public.world_fish()'::regprocedure), E'\r\n', E'\n');
  if position('7.7.7m' in d) = 0 then
    d := pg_temp.yh_sub(d, '  select * into c from public.world_characters where owner_id = uid for update;',
      '  -- 7.7.7m: 가장 짧은 간격(15초) 안의 연타는 잠그기 전에 돌려보낸다
  perform public.world_rate_check(''fish'', uid);
  select * into c from public.world_characters where owner_id = uid for update;', 'fish');
    execute d;
  end if;

  -- 현장 토벌: 1초 간격을 캐릭터·전투 행 잠금 앞에서(파티 토벌이 대신 푸는 차례는 그대로 건너뜀)
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  if position('7.7.7m' in d) = 0 then
    d := pg_temp.yh_sub(d, '  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;',
      '  -- 7.7.7m: 1초 간격을 잠그기 전에
  IF NOT pf_on THEN PERFORM public.world_rate_check(''battle'', uid); END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;', 'battle');
    execute d;
  end if;

  -- 봉연·결전: 내 1초 간격을 함께 쓰는 토벌 행을 잠그기 전에
  d := replace(pg_get_functiondef('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure), E'\r\n', E'\n');
  if position('7.7.7m' in d) = 0 then
    d := pg_temp.yh_sub(d, '  select * into rd from public.world_raids where raid_id = p_raid for update;',
      '  -- 7.7.7m: 내 1초 간격을 토벌 행(모두가 함께 씀)을 잠그기 전에 — 연타가 다른 참가자의 행동을 줄 세우지 않게
  perform public.world_rate_check(''raid'', uid, p_raid);
  select * into rd from public.world_raids where raid_id = p_raid for update;', 'raid');
    execute d;
  end if;

  -- 의무관 [야전 처치]: 회복 기준 아래면 보급품보다 먼저, 원정 한 번에 세 번까지 +25
  d := replace(pg_get_functiondef('public.world_expedition_settle(uuid,integer)'::regprocedure), E'\r\n', E'\n');
  if position('7.7.7m' in d) = 0 then
    d := pg_temp.yh_sub(d, '    while hp < heal_at loop
      item := case',
      '    while hp < heal_at loop
      -- 7.7.7m 의무관 [야전 처치]: 보급품보다 먼저, 원정 한 번에 세 번까지(jobn은 의무관에게 이 기술만 센다)
      if c.job_key = ''medic'' and jobn < 3 and hp > 0 then
        heal := greatest(1, round(25 * (1 + g_heal / 100.0))); hp := least(100, hp + heal); jobn := jobn + 1; job_once := true;
        lg := lg || jsonb_build_array(''[야전 처치] 주변 약초로 상처를 동여맸습니다. 체력 +'' || heal);
        seq := seq + 1; jr := jr || jsonb_build_object(''at'', base_t + make_interval(secs => seq * 2), ''kind'', ''heal'', ''who'', me, ''owner'', e.owner_id, ''text'', ''[야전 처치] 주변 약초로 상처를 동여맸습니다. 체력 +'' || heal || '' ('' || jobn || ''/3)'');
        continue;
      end if;
      item := case', 'settle loop');
    d := pg_temp.yh_sub(d, '        if c.job_key = ''medic'' and not job_once then
          hp := least(100, hp + 30); job_once := true; jobn := jobn + 1;',
      '        if false then',
      'settle old');
    execute d;
  end if;
  -- ④ 원정 중 쓰러짐: 정산이 체력 0을 적으면 「쓰러짐」 기록(world_notify_downed)이 원정 중 막이에 걸려 정산 전체가 되돌려졌다 → downed를 원정 중에도 허용
  d := replace(pg_get_functiondef('public.world_guard_action_context()'::regprocedure), E'\r\n', E'\n');
  if position('''loot'', ''downed'')' in d) = 0 then
    d := pg_temp.yh_sub(d, E'IF away AND NOT (\n       k IN (''progression'', ''mission'', ''supply'', ''case_combine'', ''case_resolved'', ''loot'')',
      E'IF away AND NOT (\n       k IN (''progression'', ''mission'', ''supply'', ''case_combine'', ''case_resolved'', ''loot'', ''downed'')', 'guard downed');
    execute d;
  end if;
end $p$;


update public.world_patch_notes set body = body || $N$
## 7.7.7m
- 의무관 원정 기술 [야전 처치]: 체력이 회복 기준 아래로 내려갈 때마다 보급품보다 먼저 체력 +25(원정 한 번에 세 번까지). 전에는 보급품이 떨어졌을 때 한 번 +30이었습니다.
- 채집·낚시·현장 토벌·봉연 토벌·결전에서 간격이 지나기 전에 보낸 요청을 서버가 더 빨리 돌려보냅니다(규칙은 그대로).
- 원정 중에 쓰러지면 원정 정산이 멈추던 문제를 고쳤습니다(쓰러지면 바로 결과가 나오고 구조가 필요합니다).
- 외전 「달 없는 장」을 받을 수 없던 문제를 고쳤습니다(저잣거리 탐색 4번은 받은 뒤 둘째 장면의 할 일로 옮겼습니다).
$N$ where note_id = '7.7.0' and position('## 7.7.7m' in body) = 0;

update public.world_app_meta set value = '20261104204000' where key = 'db_version';

-- ③ 외전 「달 없는 장」(gq_4): 첫 장면(받는 장면)에 탐색 4번이 걸려 있어 받을 수가 없었다(받기 전 기록은 세지 않음, 2026-11-01 제보).
--    탐색 4번을 둘째 장면 할 일로 옮기고, 첫 장면 경험치도 둘째 장면으로 합친다(합은 그대로).
update public.world_quest_steps set need = need - 'tasks', goal = '달 없는 저잣거리에서 야행국 장부를 찾는다', reward = reward - 'xp'
 where quest_id = 'gq_4' and step = 1 and need ? 'tasks';
update public.world_quest_steps
   set need = jsonb_set(need, '{tasks}', '[{"t": "search", "r": ["moonless_market"], "n": 4}]'::jsonb || (need -> 'tasks')),
       goal = '저잣거리를 4번 탐색하고, 기억 저울 장수를 쓰러뜨려 망각 수정을 3개 거둔다',
       reward = jsonb_set(reward, '{xp}', to_jsonb(coalesce((reward ->> 'xp')::int, 0) * 2))
 where quest_id = 'gq_4' and step = 2 and not (need -> 'tasks') @> '[{"t": "search"}]'::jsonb;
