-- 7.5.2 — 효과 적용 점검(2026-10-31) 반영
--  ② 귀허의 주인·합동 토벌: 참가자마다 자기 효과로 능력치(world_raid_stats가 JWT를 그 사람으로 바꿔 계산)
--  ③ 원정 정산: 장비뿐 아니라 칭호·상태·날씨·소속·직업·침식·섬·레벨 차·봉연 잠김 효과를 읽는다
--  ④ 감소 상한: 받는 피해 −60%·침식 −75%·정신 손실 −75%·이동 시간 −50%
--  ⑤ 효과가 안 붙던 기본 기술 11개
--  ⑥ 장비 제작 특화(crafting_specialization)를 7.5.0 제작 계열 이름으로
--  ⑦ 낚싯대 물고기 크기 · ⑧ 채집 희귀품에 도구·상태·칭호 · ⑨ 행동마다 잃는 정신에 정신 손실 감소
--  칭호 효과 숫자 판정(소수) 고침
set local check_function_bodies = off;

create or replace function pg_temp.yh_patch(p_fn regprocedure, p_old text, p_new text) returns void
language plpgsql as $f$
declare d text; n int;
begin
  d := replace(pg_get_functiondef(p_fn), E'\r\n', E'\n');
  if position(p_old in d) = 0 and position(p_new in d) > 0 then return; end if;  -- 이미 고침
  n := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if n <> 1 then raise exception '7.5.2 anchor % in % (found %)', left(p_old, 60), p_fn, n; end if;
  execute replace(d, p_old, p_new);
end $f$;

-- ── ② 남의 능력치를 그 사람 기준으로 ───────────────────────────────────────────
create or replace function public.world_raid_stats(p_owner uuid)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare s jsonb; oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true);
  sw boolean := public.fn_owner_auth_uid() is distinct from p_owner;
begin
  -- 상태·직업·소속·침식 효과는 「부른 사람」(JWT) 기준이라, 남의 능력치를 잴 때는 그 사람으로 바꿔 계산한다(7.5.2)
  if sw then
    perform set_config('request.jwt.claim.sub', p_owner::text, true);
    perform set_config('request.jwt.claims', json_build_object('sub', p_owner, 'role', 'authenticated')::text, true);
  end if;
  s := public.world_combat_stats(p_owner);
  if sw then
    perform set_config('request.jwt.claims', coalesce(oc, ''), true);
    perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  end if;
  return jsonb_build_object('attack', coalesce((s ->> 'attack')::numeric, 10), 'red', coalesce((s ->> 'reduction_pct')::numeric, 0),
    'inc', coalesce((s ->> 'incoming_pct')::numeric, 0), 'eva', coalesce((s ->> 'evasion_pct')::numeric, 0), 'crit', coalesce((s ->> 'crit_pct')::numeric, 5),
    'pres', coalesce((s ->> 'presence')::numeric, 30), 'style', coalesce(s ->> 'style', 'melee'));
end $function$;

-- ── ④ 감소 상한 ────────────────────────────────────────────────────────────────
select pg_temp.yh_patch('public.world_status_effect_total(text)', $o$#variable_conflict use_column
begin
  return (select * from ($o$, $n$#variable_conflict use_column
declare yh_v numeric;
begin
  yh_v := (select * from ($n$);
select pg_temp.yh_patch('public.world_status_effect_total(text)', $o$) yhq limit 1);
end$o$, $n$) yhq limit 1);
  -- 감소 상한(7.5.2): 모든 효과를 합쳐도 받는 피해 −60%·침식 −75%·정신 손실 −75%·이동 시간 −50%까지
  return case p_effect_key when 'incoming_damage_pct' then greatest(-60, yh_v) when 'erosion_pct' then greatest(-75, yh_v)
    when 'mental_loss_pct' then greatest(-75, yh_v) when 'travel_time_pct' then greatest(-50, yh_v) else yh_v end;
end$n$);
select pg_temp.yh_patch('public.world_combat_stats(uuid,jsonb)',
  $o$inc := public.world_status_effect_total('incoming_damage_pct') + public.world_title_bonus_of(p_owner, 'incoming_damage_pct');$o$,
  $n$inc := greatest(-60, public.world_status_effect_total('incoming_damage_pct') + public.world_title_bonus_of(p_owner, 'incoming_damage_pct'));$n$);
select pg_temp.yh_patch('public.world_travel_route(text)',
  $o$secs := secs * (1 + public.world_status_effect_total('travel_time_pct') / 100.0 + least(0, public.world_title_bonus('travel_time_pct')) / 100.0);$o$,
  $n$secs := secs * greatest(0.5, 1 + public.world_status_effect_total('travel_time_pct') / 100.0 + least(0, public.world_title_bonus('travel_time_pct')) / 100.0);$n$);

-- 칭호 효과 숫자 판정: '\\.'이 소수점을 못 잡아 1.5 같은 값이 0이 되던 것
select pg_temp.yh_patch('public.world_title_bonus(text)', $o$(\\.[0-9]+)$o$, $n$(\.[0-9]+)$n$);

-- ── ③ 원정 정산 ────────────────────────────────────────────────────────────────
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$  base_t timestamptz; won boolean;$o$,
  $n$  base_t timestamptz; won boolean;
  oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true); g_gq float8; g_heal float8; v_pct float8;$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$  select * into c from public.world_characters where owner_id = e.owner_id for update;
$o$,
  $n$  select * into c from public.world_characters where owner_id = e.owner_id for update;
  -- 효과는 원정 주인 기준으로 잰다(7.5.2: 예약 작업·파티원이 불러도 같은 값)
  perform set_config('request.jwt.claim.sub', e.owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', e.owner_id, 'role', 'authenticated')::text, true);
$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$  if c.job_key = 'exorcist' then power := power * 1.12; end if;
$o$, '');
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$  power := power * (1 + (public.world_gear_total(e.owner_id, 'combat_damage_pct') + public.world_gear_total(e.owner_id, 'crit_pct') * 0.5) / 100.0);
  defense := defense + public.world_gear_total(e.owner_id, 'defense') * 2;
  g_inc := public.world_gear_total(e.owner_id, 'incoming_damage_pct') - public.world_gear_total(e.owner_id, 'evasion_pct') * 0.5;
  g_ml := public.world_gear_total(e.owner_id, 'mental_loss_pct'); g_er := public.world_gear_total(e.owner_id, 'erosion_pct');
  g_rare := public.world_gear_total(e.owner_id, 'rare_loot_pct');$o$,
  $n$  -- 장비·칭호·상태·날씨·소속·직업·침식·섬·레벨 차·봉연 잠김(7.5.2, 전에는 장비만)
  defense := defense + (public.world_status_effect_total('defense') + public.world_title_bonus('defense')) * 2;
  g_inc := greatest(-60, public.world_status_effect_total('incoming_damage_pct') + public.world_title_bonus('incoming_damage_pct')
    - (public.world_status_effect_total('evasion_pct') + public.world_title_bonus('evasion_pct')) * 0.5);
  g_ml := public.world_status_effect_total('mental_loss_pct'); g_er := public.world_status_effect_total('erosion_pct');
  g_rare := public.world_status_effect_total('rare_loot_pct') + public.world_title_bonus('rare_loot_pct');
  g_gq := public.world_status_effect_total('gather_qty_pct') + public.world_title_bonus('gather_qty_pct');
  g_heal := greatest(-50, public.world_status_effect_total('healing_pct'));$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$  ammo_k := public.world_ammo_of(e.owner_id);
$o$,
  $n$  -- 주는 피해(근접·원거리·술법 포함, 합 35%까지)와 치명타 절반(직업 피해 %는 그 역할 무기를 들었을 때만)
  v_pct := least(35, public.world_status_effect_total('combat_damage_pct') + public.world_title_bonus('combat_damage_pct')
    + public.world_status_effect_total(wtype || '_pct') + public.world_title_bonus(wtype || '_pct'));
  power := power * (1 + (v_pct + (public.world_status_effect_total('crit_pct') + public.world_title_bonus('crit_pct')) * 0.5) / 100.0);
  ammo_k := public.world_ammo_of(e.owner_id);
$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$+ case when c.job_key in ('analyst', 'scout') then 0.15 else 0 end + c.perception * 0.005));$o$,
  $n$+ case when c.job_key = 'scout' then 0.15 else 0 end + c.perception * 0.005) * greatest(0.5, 1 + g_gq / 100.0));$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$random() < 0.04 + depth * 0.03 + (case when c.job_key = 'analyst' then 0.05 else 0 end)$o$,
  $n$random() < 0.04 + depth * 0.03 + (case when c.job_key = 'analyst' then 0.05 else 0 end) + greatest(0, g_rare) / 400.0$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$      if c.job_key = 'medic' then heal := round(heal * 1.15); end if;
$o$,
  $n$      if c.job_key = 'medic' then heal := round(heal * 1.15); end if;
      heal := greatest(1, round(heal * (1 + g_heal / 100.0)));
$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$  return last_i;
end$o$,
  $n$  perform set_config('request.jwt.claims', coalesce(oc, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  return last_i;
end$n$);

-- ── ⑨ 행동마다 잃는 정신에 정신 손실 감소 ─────────────────────────────────────
select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$           greatest(0, coalesce(sum(case when (cat.effects ->> 'mental_per_action') ~ '^-?[0-9]+$' then (cat.effects ->> 'mental_per_action')::int * cs.potency else 0 end), 0))$o$,
  $n$           coalesce(sum(case when (cat.effects ->> 'mental_per_action') ~ '^-?[0-9]+$' then (cat.effects ->> 'mental_per_action')::int * cs.potency else 0 end), 0)$n$);
select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$    mn_tick := mn_tick + case when c.erosion >= 55 then 1 else 0 end;
$o$,
  $n$    mn_tick := mn_tick + case when c.erosion >= 55 then 1 else 0 end;
    -- 정신 손실 감소(소속·직업·칭호·관모·등잔빛 등, 7.5.2)를 곱한다. 「맑은 정신」(−1)은 침식 위험의 +1을 상쇄
    if mn_tick > 0 then mn_tick := greatest(0, floor(mn_tick * greatest(0.25, 1 + public.world_status_effect_total('mental_loss_pct') / 100.0) + random())::int);
    else mn_tick := 0; end if;
$n$);
-- ⑤ 잔향 추적(탐사 3) 탐사 기술 경험 +10% · 영역 판독(탐사 8) 위험도 5 이상에서 +4
select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$  if not found or coalesce(c.is_dead, false) then return new; end if;
$o$,
  $n$  if not found or coalesce(c.is_dead, false) then return new; end if;
  if sk = 'tracking' and sk_xp > 0 then
    if coalesce((c.skill_progress -> 'tracking' ->> 'rank')::int, 0) >= 3 then sk_xp := ceil(sk_xp * 1.1)::int; end if;
    if coalesce((c.skill_progress -> 'tracking' ->> 'rank')::int, 0) >= 8 and coalesce((p ->> 'danger')::int, 0) >= 5 then sk_xp := sk_xp + 4; end if;
  end if;
$n$);

-- ── ⑤ 기본 기술(토벌) ──────────────────────────────────────────────────────────
-- 패턴 독해(분석 3): 집중 뒤 공격 +8%
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$IF coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN mul := mul * 1.4;$o$,
  $n$IF coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN mul := mul * 1.4 * (CASE WHEN coalesce((c.skill_progress -> 'analysis' ->> 'rank')::int, 0) >= 3 THEN 1.08 ELSE 1 END);$n$);
-- 흐름 반전(막기 8): 막은 다음 공격 +8% · 파쇄 타격(근접 8) 장갑 +8% · 결계 압축(봉인술 8) 결계 +12%
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$    IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN mul := mul * 1.2; END IF;
$o$,
  $n$    IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN mul := mul * 1.2; END IF;
    IF coalesce((v_pfx ->> 'gd_last')::boolean, false) AND coalesce((c.skill_progress -> 'guarding' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.08; END IF;
    v_pfx := v_pfx - 'gd_last';
    IF style = 'melee' AND m.mechanic_key = 'armored' AND coalesce((c.skill_progress -> 'melee' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.08; END IF;
    IF style = 'magic' AND m.mechanic_key = 'warded' AND coalesce((c.skill_progress -> 'sealing' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;
$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$    guarding := true; sp := least(100, sp + 4); v_pfx := v_pfx || jsonb_build_object('u_gd', coalesce((v_pfx ->> 'u_gd')::int, 0) + 1);$o$,
  $n$    guarding := true; sp := least(100, sp + 4); v_pfx := v_pfx || jsonb_build_object('u_gd', coalesce((v_pfx ->> 'u_gd')::int, 0) + 1, 'gd_last', true);$n$);
-- 철벽 자세(막기 3): 막는 중 받는 피해 10% 더 줄임
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$        IF guarding AND 'guarding_x13' = ANY (sk) THEN mdmg := round(mdmg * 0.8); END IF;
$o$,
  $n$        IF guarding AND 'guarding_x13' = ANY (sk) THEN mdmg := round(mdmg * 0.8); END IF;
        IF guarding AND coalesce((c.skill_progress -> 'guarding' ->> 'rank')::int, 0) >= 3 THEN mdmg := round(mdmg * 0.9); END IF;
$n$);
-- 응급 지혈(응급 처치 3): 토벌 중 회복품 체력 +10
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$      hp := least(100, hp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 체력 '$o$,
  $n$      IF coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) >= 3 THEN heal := heal + 10; END IF;
      hp := least(100, hp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 체력 '$n$);
-- 요괴 도감(분석 8): 전리품 확률 +5%
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$ELSE 0.6 END) * (1 + rare / 100.0));$o$,
  $n$ELSE 0.6 END) * (1 + (rare + CASE WHEN coalesce((c.skill_progress -> 'analysis' ->> 'rank')::int, 0) >= 8 THEN 5 ELSE 0 END) / 100.0));$n$);
-- 현장 소생술(응급 처치 8): 구조하면 상대 체력 +10
select pg_temp.yh_patch('public.world_rescue_character(uuid)',
  $o$ when public.world_bond_partner(uid)=p_target then 50 else 30 end,$o$,
  $n$ when public.world_bond_partner(uid)=p_target then 50 else 30 end + case when coalesce((rescuer.skill_progress -> 'first_aid' ->> 'rank')::int, 0) >= 8 then 10 else 0 end,$n$);
-- 부적 정련(봉인술 3): 봉인 공예 제작 품질 +5 · ⑥ 장비 제작 특화는 그 제작법 계열(또는 필요 기술)과 맞으면 +10
select pg_temp.yh_patch('public.world_craft_item(text)',
  $o$    + case when r.required_skill is not null and exists (select 1 from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id where e.owner_id = uid and i.crafting_specialization = r.required_skill) then 10 else 0 end$o$,
  $n$    + case when exists (select 1 from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id where e.owner_id = uid and i.crafting_specialization in (r.required_skill, line)) then 10 else 0 end
    + case when line = 'wardcraft' and coalesce((c.skill_progress -> 'sealing' ->> 'rank')::int, 0) >= 3 then 5 else 0 end$n$);

update public.world_skill_catalog set description = d.t from (values
  ('analysis_read', '집중(분석)한 뒤의 공격 피해 +8%.'),
  ('analysis_hunter', '토벌에서 전리품이 나올 확률 +5%.'),
  ('firstaid_quick', '토벌 중 회복품으로 회복하는 체력 +10.'),
  ('firstaid_field', '다른 조사원을 구조하면 상대가 체력 10을 더 얻고 일어난다.'),
  ('guard_brace', '막는 중 받는 피해를 10% 더 줄인다.'),
  ('guard_counter', '막은 바로 다음 공격의 피해 +8%.'),
  ('tracking_scent', '탐사 기술 경험 +10%.'),
  ('tracking_hunter', '위험도 5 이상인 곳에서 탐사하면 탐사 기술 경험 +4.'),
  ('melee_break', '근접 피해 +10%, 장갑 요괴에게 +8% 더.'),
  ('sealing_domain', '봉인 피해 +15%, 결계 요괴에게 +12% 더.'),
  ('sealing_script', '봉인 피해 +8%, 봉인 공예 제작 품질 +5.')) d(id, t)
 where skill_id = d.id;

-- ── ⑥ 장비 제작 특화를 제작 계열 이름으로(우수품 행은 트리거가 따라 고침) ────────
update public.world_item_catalog set crafting_specialization = case crafting_specialization
    when 'sealing' then 'wardcraft' when 'warding' then 'wardcraft' when 'herbalism' then 'alchemy' when 'spirit_gathering' then 'artifice'
    when 'mining' then 'smithing' when 'melee' then 'smithing' when 'fishing' then 'cooking' when 'analysis' then 'artifice' end
 where crafting_specialization in ('sealing', 'warding', 'herbalism', 'spirit_gathering', 'mining', 'melee', 'fishing', 'analysis');

-- ── ⑦ 낚싯대 물고기 크기 ───────────────────────────────────────────────────────
select pg_temp.yh_patch('public.world_fish()',
  $o$public.world_line_base(c.skill_progress, 'fishing', 'fish_size_pct')) / 100.0)), 1);$o$,
  $n$public.world_line_base(c.skill_progress, 'fishing', 'fish_size_pct')
       + coalesce((select (i.equipment_traits ->> 'fish_size_pct')::numeric from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0)) / 100.0)), 1);$n$);

-- ── ⑧ 채집 희귀품: 도구 희귀품 + 상태·칭호 희귀품 보정 ─────────────────────────
select pg_temp.yh_patch('public.world_field_gather(uuid)',
  $o$  r_pct := least(8, public.world_line_base(c.skill_progress, line, 'rare_loot_pct')) + public.world_title_bonus('gr_' || line);$o$,
  $n$  r_pct := least(8, public.world_line_base(c.skill_progress, line, 'rare_loot_pct')) + public.world_title_bonus('gr_' || line);
  -- 상태·직업·소속·칭호 희귀품은 비율로, 든 채집 도구의 희귀품은 그대로 더한다(7.5.2)
  r_pct := r_pct * greatest(0.5, 1 + (public.world_status_effect_total('rare_loot_pct') + public.world_title_bonus('rare_loot_pct')) / 100.0)
    + coalesce((select (i.equipment_traits ->> 'rare_loot_pct')::numeric from public.world_item_catalog i where i.item_id = tool_id), 0);$n$);

-- ── 이동 중 물품 사용 막기(사용자 요청: 퀵슬롯·가방 모두, 쓰러졌을 때 회생 부적은 그대로) ─────
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$  IF coalesce(c.is_dead, false) THEN RAISE EXCEPTION '숨을 거둔 조사원은 물품을 쓸 수 없습니다.'; END IF;
$o$,
  $n$  IF coalesce(c.is_dead, false) THEN RAISE EXCEPTION '숨을 거둔 조사원은 물품을 쓸 수 없습니다.'; END IF;
  IF c.travel_destination IS NOT NULL AND public.world_item_base(p_item_id) <> 'revival_charm' THEN RAISE EXCEPTION '이동 중에는 물품을 쓸 수 없습니다. 도착한 뒤 쓰세요.'; END IF;
$n$);

-- 끝: 바뀐 함수 본문 검사
set local check_function_bodies = on;
do $v$
declare f regprocedure;
begin
  foreach f in array array['public.world_raid_stats(uuid)', 'public.world_status_effect_total(text)', 'public.world_combat_stats(uuid,jsonb)',
    'public.world_travel_route(text)', 'public.world_title_bonus(text)', 'public.world_expedition_settle(uuid,integer)', 'public.world_event_char_apply()',
    'public.world_battle_action(text,text)', 'public.world_rescue_character(uuid)', 'public.world_craft_item(text)', 'public.world_fish()',
    'public.world_field_gather(uuid)', 'public.world_use_item(text)']::regprocedure[] loop
    perform plpgsql_validator(f::oid);
  end loop;
end $v$;

-- 패치노트: 7.5.0 본문 맨 아래에 덧붙임
update public.world_patch_notes set body = body || $N$

## 7.5.2
- **원정**에 장비 말고 다른 효과도 붙습니다: 칭호·음식과 상태·날씨·소속·직업·침식 단계·섬·레벨 차·봉연 잠김. 원정에서 얻는 철벽·맹호·청명 비약도 이제 원정에서 듣습니다. 직업 피해 %는 그 역할 무기를 들었을 때 붙고(퇴마관만 따로 받던 +12%는 이것으로 바뀜), 회복품도 회복량 효과를 받습니다.
- **귀허의 주인** 결전에서 참가자마다 자기 효과로 능력치를 잽니다. 전에는 결전을 연 사람의 상태·직업 효과가 모두에게 붙었습니다.
- **감소 상한**: 모든 효과를 합쳐도 받는 피해 −60%, 침식·정신 손실 −75%, 이동 시간 −50%까지입니다(전에는 상한이 없어 피해 0이 될 수 있었습니다).
- **행동마다 잃는 정신**에도 정신 손실 감소가 붙습니다. 「맑은 정신」은 침식 위험 단계의 −1을 상쇄합니다.
- 효과가 안 붙던 **기본 기술 11개**에 효과를 붙였습니다: 패턴 독해·요괴 도감·응급 지혈·현장 소생술·철벽 자세·흐름 반전·잔향 추적·영역 판독·파쇄 타격(장갑 +8%)·결계 압축(결계 +12%)·부적 정련(봉인 공예 품질 +5). 설명도 실제 수치로 고쳤습니다.
- 장비의 **제작 특화(+10 품질)**를 7.5.0 제작 계열 이름으로 맞췄습니다: 각인 공구·호신 도포 봉인 공예, 채집도·영맥 낫 연금, 영등·영맥 나침반 법구 공예, 곡괭이·월식도 단조, 낚싯대 요리.
- 낚싯대의 **물고기 크기** 효과가 붙습니다. 채집 도구의 **희귀품**이 채집에 붙고, 상태·직업·소속·칭호 희귀품도 채집 희귀품을 늘립니다.
- **이동 중에는 물품을 쓸 수 없습니다**(가방·퀵슬롯 모두, 쓰러졌을 때 회생 부적은 그대로).
- 우수품 음식·약에 **사용** 단추가 없던 것을 고쳤습니다(조의신 님 제보). 퀵슬롯은 묻지 않고 바로 씁니다(강산하 님 제보).
- 칭호 효과에 「기타 효과」로 보이던 것(기술 칭호의 계열별 제작 품질·재료 아낄 확률·하나 더 만들 확률·채집량·희귀품, 음식 기운 지속)에 이름을 붙였습니다.
$N$
 where note_id = '7.5.0' and position('## 7.5.2' in body) = 0;

update public.world_app_meta set value = '20261104020000' where key = 'db_version';
