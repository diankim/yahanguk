alter table public.world_pfight_members add column if not exists weak text;
alter table public.world_raid_log add column if not exists who text;
alter table public.world_raid_log add column if not exists n integer;

create or replace function public.world_raid_say_n(p_raid uuid, p_kind text, p_text text, p_who text, p_n integer)
 returns void
 language sql
 security definer
 set search_path to ''
as $function$
  insert into public.world_raid_log(raid_id, kind, text, who, n) values (p_raid, p_kind, p_text, p_who, p_n)
$function$;
alter function public.world_raid_say_n(uuid, text, text, text, integer) owner to fn_owner_field;
revoke all on function public.world_raid_say_n(uuid, text, text, text, integer) from public, anon, authenticated;
grant execute on function public.world_raid_say_n(uuid, text, text, text, integer) to service_role;

create or replace function public.world_notify_group(p_kind text)
 returns text
 language sql
 immutable
 set search_path to 'pg_catalog'
as $function$
  select case
    when p_kind in ('title', 'cosmetic') then 'title'
    when p_kind in ('reward', 'skill_rerank') then 'reward'
    when p_kind in ('bag_full', 'bag_overflow') then 'bag'
    when p_kind in ('rescue_request') then 'rescue'
    when p_kind in ('friend_down') then 'friend_rescue'
    when p_kind in ('trade_offer', 'trade_result', 'ucomm_done') then 'trade'
    when p_kind in ('friend_request', 'friend_accepted') then 'friend'
    when p_kind in ('ride_request', 'party_invite', 'party_expedition', 'party_exp_offer', 'party_leave', 'party_aid', 'pfight_invite', 'pfight_join') then 'party'
    when p_kind in ('circle_invite') then 'circle'
    when p_kind in ('letter') then 'letter'
    when p_kind in ('spar_request', 'spar_result', 'tourney_alert', 'tourney_result', 'tourney_partner') then 'spar'
    when p_kind like 'bond%' or p_kind = 'wedding_invite' then 'bond'
    when p_kind in ('faction', 'faction_open', 'faction_week') then 'faction'
    when p_kind in ('raid_invite', 'raid_vote', 'raid', 'raid_result', 'gw', 'gw_invite') then 'raid'
    when p_kind in ('housing_visit', 'housing_guest', 'housing_item', 'housing_merge', 'pet_play', 'pet_new') then 'housing'
    else null end
$function$;

CREATE OR REPLACE FUNCTION public.world_battle_action(p_action text, p_item text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; a public.world_active_encounters%rowtype;
  m public.world_region_monsters%rowtype; r public.world_map_regions%rowtype; st jsonb;
  act text := lower(coalesce(p_action, '')); style text := 'melee'; adr numeric := 0; eva numeric; flee_p numeric; crit_p numeric; defv numeric; inc numeric;
  turn int; v_weak text; v_fx jsonb; v_pfx jsonb; lines jsonb := '[]'::jsonb; dmg int := 0; mdmg int := 0; heal int := 0; crit boolean := false;
  base numeric; mul numeric := 1; cc numeric; mdef numeric; hit numeric; v_intent text; next_intent text; skip_monster boolean := coalesce(current_setting('yh.pf_skip', true), '') = '1';
  guarding boolean := false; fled boolean := false; ended text; hp int; mn int; sp int; er int; inv jsonb; it text; k text; v int;
  loot jsonb := '{}'::jsonb; xp int := 0; gil_gain int := 0; rk_mul numeric; drop_p numeric; reflect int := 0; shield int;
  skill_name text; qty int; job_cd int; v_result jsonb; statuses text[] := '{}'; sig text; attacked boolean := false; wear jsonb; rare numeric; g public.world_monster_gimmicks%rowtype; gburst boolean := false; keen boolean := false; mheal int := 0; thorn int := 0;
  sk text[]; first_atk boolean; force_crit boolean := false; crit_x numeric := 1.5; extra int; ex_total int := 0; resist numeric; nfix int; gname text;
  raw_m int; absorb int; m_pre int; fxi jsonb; fxq numeric; brk numeric := 0.15; eva_now numeric; n_hit int := 0; ammo_k text;
  sneak_ok boolean := false; pf_skip boolean := coalesce(current_setting('yh.pf_skip', true), '') = '1'; pf_on boolean := coalesce(current_setting('yh.pf_resolve', true), '') = '1';
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  PERFORM set_config('yh.bag_drop', 'on', true);
  IF act NOT IN ('attack', 'skill', 'guard', 'item', 'flee', 'sneak') THEN RAISE EXCEPTION '알 수 없는 행동입니다.'; END IF;
  -- 7.7.7m: 1초 간격을 잠그기 전에
  IF NOT pf_on THEN PERFORM public.world_rate_check('battle', uid); END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태입니다.'; END IF;
  SELECT * INTO a FROM public.world_active_encounters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND OR a.defeated OR coalesce(a.fled, false) OR a.mlevel IS NULL THEN RAISE EXCEPTION '진행 중인 전투가 없습니다.'; END IF;
  IF NOT pf_on AND EXISTS (SELECT 1 FROM public.world_pfight_members pm JOIN public.world_pfights pf ON pf.fight_id = pm.fight_id
        WHERE pm.owner_id = uid AND pm.out_reason IS NULL AND pf.status IN ('gather', 'fight')) THEN
    RAISE EXCEPTION '파티 토벌 중입니다. 파티 토벌 화면에서 이번 라운드 행동을 고르세요.'; END IF;
  IF NOT pf_on AND a.last_action_at IS NOT NULL AND a.last_action_at > now() - interval '1 second' THEN
    RAISE EXCEPTION '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.'; END IF;
  SELECT * INTO m FROM public.world_region_monsters WHERE monster_id = a.monster_id;
  r := public.world_field_region(c.location);
  IF r.region_id IS DISTINCT FROM a.region_id THEN RAISE EXCEPTION '전투가 벌어진 지역에 있어야 합니다.'; END IF;

  st := public.world_combat_stats(uid);
  style := st ->> 'style';
  eva := (st ->> 'evasion_pct')::numeric; flee_p := (st ->> 'flee_pct')::numeric; crit_p := (st ->> 'crit_pct')::numeric;
  defv := (st ->> 'defense')::numeric; inc := (st ->> 'incoming_pct')::numeric;
  IF st -> 'armor' IS NOT NULL AND st -> 'armor' <> 'null'::jsonb AND st -> 'armor' ->> 'state' <> 'broken' THEN adr := coalesce((st -> 'armor' ->> 'reduction')::numeric, 0); END IF;
  sk := public.world_skill_procs(uid);

  turn := a.turn_count + 1; v_fx := coalesce(a.fx, '{}'::jsonb); v_pfx := coalesce(a.pfx, '{}'::jsonb);
  hp := c.health; mn := c.mental; sp := c.spiritual_power; er := c.erosion; inv := coalesce(c.inventory, '{}'::jsonb);
  v_intent := coalesce(a.intent, 'strike');
  IF v_intent LIKE 'g%:%' AND act IN ('attack', 'guard', 'skill', 'item') THEN v_pfx := v_pfx || jsonb_build_object('u_an', coalesce((v_pfx ->> 'u_an')::int, 0) + 1); END IF;
  job_cd := coalesce((v_pfx ->> 'skill_ready')::int, 0);
  first_atk := NOT coalesce((v_pfx ->> 'opened')::boolean, false);
  IF 'analysis_c43b' = ANY (sk) THEN brk := 0.08; END IF;

  -- 턴 시작: 지혈(출혈·중독 30%), 붕대술(남은 턴 동안 체력 +4)
  IF 'first_aid_x13' = ANY (sk) AND random() < 0.3 THEN
    UPDATE public.world_character_statuses SET expires_at = now() WHERE status_id = (SELECT status_id FROM public.world_character_statuses
      WHERE owner_id = uid AND expires_at > now() AND status_key IN ('bleeding', 'poisoned') ORDER BY expires_at LIMIT 1);
    IF FOUND THEN lines := lines || jsonb_build_array('「지혈」 출혈·독 하나를 다스렸다.'); END IF;
  END IF;
  IF coalesce((v_pfx ->> 'regen')::int, 0) > 0 THEN
    hp := least(100, hp + 4); v_pfx := v_pfx || jsonb_build_object('regen', (v_pfx ->> 'regen')::int - 1);
    lines := lines || jsonb_build_array('「붕대술」 체력 +4');
  END IF;

  IF act = 'skill' THEN
    IF turn < job_cd THEN RAISE EXCEPTION '%', format('기술은 %s턴 뒤에 다시 쓸 수 있습니다.', job_cd - turn); END IF;
    IF c.job_key = 'medic' AND (v_pfx ->> 'med_used') IS NOT NULL THEN RAISE EXCEPTION '응급 처방은 한 전투에 한 번만 쓸 수 있습니다.'; END IF;
    IF sp < (CASE WHEN c.job_key = 'medic' THEN 25 ELSE 12 END) THEN RAISE EXCEPTION '%', CASE WHEN style = 'melee' THEN '기력' ELSE '영력' END || '이 모자랍니다. (필요 ' || CASE WHEN c.job_key = 'medic' THEN 25 ELSE 12 END || ')'; END IF;
    sp := sp - CASE WHEN c.job_key = 'medic' THEN 25 ELSE 12 END; v_pfx := v_pfx || jsonb_build_object('skill_ready', turn + 3);
  END IF;

  IF act = 'sneak' THEN
    IF pf_on OR a.turn_count > 0 OR v_pfx ? 'sneak_tried' THEN RAISE EXCEPTION '기척 숨기기는 요괴와 마주친 직후에만 할 수 있습니다.'; END IF;
    v_pfx := v_pfx || jsonb_build_object('sneak_tried', true);
    IF random() * 100 < public.world_sneak_pct(uid, a.mlevel, a.rank) THEN
      fled := true; sneak_ok := true;
      lines := lines || jsonb_build_array('「기척 숨기기」 숨을 죽이고 물러나 ' || m.monster_name || '의 눈을 피했다.');
    ELSE
      lines := lines || jsonb_build_array('기척을 숨기려다 들켰다! ' || m.monster_name || '이(가) 먼저 덤벼든다.');
    END IF;
  ELSIF act = 'flee' THEN
    IF coalesce((v_pfx ->> 'bound')::int, 0) > 0 THEN
      lines := lines || jsonb_build_array('붙잡혀 있어 달아날 수 없다.');
    ELSIF random() * 100 < least(90, flee_p - greatest(0, a.mlevel - c.level) * 3 - (CASE WHEN a.rank = 'guardian' THEN 20 ELSE 0 END)) THEN
      fled := true; lines := lines || jsonb_build_array('몸을 돌려 달아났다.');
    ELSE
      lines := lines || jsonb_build_array('달아나려 했지만 길이 막혔다.');
    END IF;
  ELSIF act = 'guard' THEN
    guarding := true; sp := least(100, sp + 4); v_pfx := v_pfx || jsonb_build_object('u_gd', coalesce((v_pfx ->> 'u_gd')::int, 0) + 1, 'gd_last', true);
    lines := lines || jsonb_build_array('자세를 낮추고 막을 준비를 했다.');
  ELSIF act = 'item' THEN
    it := coalesce(p_item, '');
    IF public.world_item_base(it) NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman', 'spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew', 'rejuv_pill', 'grand_pill') THEN RAISE EXCEPTION '전투 중에 쓸 수 없는 물품입니다.'; END IF;
    IF coalesce((inv ->> it)::int, 0) < 1 THEN RAISE EXCEPTION '가방에 그 물품이 없습니다.'; END IF;
    inv := public.world_inv_add(inv, it, -1); v_pfx := v_pfx || jsonb_build_object('u_fa', coalesce((v_pfx ->> 'u_fa')::int, 0) + 1);
    IF public.world_item_base(it) IN ('spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew') THEN
      heal := ceil((CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END) * CASE public.world_item_base(it) WHEN 'spirit_tea' THEN 10 WHEN 'clear_spirit_pill' THEN 20 WHEN 'spirit_qi_pill' THEN 35 WHEN 'moonlight_essence' THEN 55 ELSE 80 END)::int;
      IF c.job_key = 'medic' THEN heal := round(heal * 1.15); END IF; IF 'medicine_c13b' = ANY (sk) THEN heal := round(heal * 1.2); END IF;
      heal := round(heal * (1 + public.world_status_effect_total('healing_pct') / 100.0));
      sp := least(100, sp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 ' || CASE WHEN style = 'melee' THEN '기력 ' ELSE '영력 ' END || heal || ' 회복');
    ELSIF public.world_item_base(it) = 'ward_talisman' THEN

      UPDATE public.world_character_statuses SET expires_at = now() WHERE owner_id = uid AND expires_at > now() AND status_key IN ('erosion_whisper', 'shaken', 'poisoned');
      IF (v_fx ->> 'barrier') IS NOT NULL THEN v_fx := v_fx - 'barrier'; END IF;
      lines := lines || jsonb_build_array('정화 부적을 태워 사기를 걷어냈다.');
    ELSE
      heal := ceil((CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END) * CASE public.world_item_base(it) WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 WHEN 'rejuv_pill' THEN 60 WHEN 'grand_pill' THEN 100
        ELSE CASE WHEN 'combo_first_aid_herbalism' = ANY (sk) THEN 22 ELSE 12 END END)::int;
      IF c.job_key = 'medic' THEN heal := round(heal * 1.15); END IF; IF 'medicine_c13b' = ANY (sk) THEN heal := round(heal * 1.2); END IF;
      heal := round(heal * (1 + public.world_status_effect_total('healing_pct') / 100.0));
      IF coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) >= 3 THEN heal := heal + 10; END IF;
      hp := least(100, hp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 체력 ' || heal || ' 회복');
      IF 'first_aid_c24a' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('regen', 2); END IF;
      IF 'first_aid_c24b' = ANY (sk) THEN mn := least(100, mn + 6); lines := lines || jsonb_build_array('「안정 호흡」 정신 +6'); END IF;
      IF 'first_aid_c43b' = ANY (sk) THEN
        UPDATE public.world_character_statuses SET expires_at = now() WHERE status_id = (SELECT cs.status_id FROM public.world_character_statuses cs JOIN public.world_status_catalog sc USING (status_key)
        WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' AND cs.status_key NOT IN ('yohwa', 'yohwa_seal') ORDER BY cs.expires_at LIMIT 1);
        IF FOUND THEN lines := lines || jsonb_build_array('「해독술」 나쁜 상태 하나를 풀었다.'); END IF;
      END IF;
    END IF;
    -- 물품 효과의 정신·침식·치료(use_fx 한 원본, 체력·영력은 위에서 기술 보정과 함께)
    fxi := public.world_item_fx(public.world_item_base(it)); fxq := CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END;
    IF coalesce((fxi ->> 'mn')::numeric, 0) > 0 THEN mn := least(100, mn + ceil((fxi ->> 'mn')::numeric * fxq)::int); lines := lines || jsonb_build_array('정신 +' || ceil((fxi ->> 'mn')::numeric * fxq)::int); END IF;
    IF coalesce((fxi ->> 'er')::numeric, 0) > 0 THEN er := greatest(0, er - ceil((fxi ->> 'er')::numeric * fxq)::int); lines := lines || jsonb_build_array('침식 −' || ceil((fxi ->> 'er')::numeric * fxq)::int); END IF;
    IF jsonb_array_length(coalesce(fxi -> 'cures', '[]'::jsonb)) > 0 THEN
      UPDATE public.world_character_statuses SET expires_at = now() WHERE owner_id = uid AND expires_at > now()
        AND status_key IN (SELECT jsonb_array_elements_text(fxi -> 'cures')) AND status_key NOT IN ('yohwa', 'yohwa_seal');
    END IF;
    IF 'first_aid_x30' = ANY (sk) AND NOT coalesce((v_pfx ->> 'swift')::boolean, false) THEN
      skip_monster := true; v_pfx := v_pfx || jsonb_build_object('swift', true);
      lines := lines || jsonb_build_array('「약침」 빈틈없이 처치해 적이 덤벼들지 못했다.');
    END IF;
  ELSIF act = 'skill' AND c.job_key = 'medic' THEN
    heal := least(40, 15 + c.vitality / 2 + c.willpower / 2); IF 'medicine_m50' = ANY (sk) THEN heal := round(heal * 1.5); END IF; IF 'combo_medicine_alchemy' = ANY (sk) THEN heal := heal + 10; END IF;
    heal := round(heal * (1 + public.world_status_effect_total('healing_pct') / 100.0)); hp := least(100, hp + heal); v_pfx := v_pfx || jsonb_build_object('u_fa', coalesce((v_pfx ->> 'u_fa')::int, 0) + 1, 'med_used', true);
    UPDATE public.world_character_statuses SET expires_at = now() WHERE status_id = (SELECT cs.status_id FROM public.world_character_statuses cs JOIN public.world_status_catalog sc USING (status_key)
      WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' AND cs.status_key NOT IN ('yohwa', 'yohwa_seal') ORDER BY cs.expires_at LIMIT 1);
    lines := lines || jsonb_build_array('응급 처방: 체력 ' || heal || ' 회복' || CASE WHEN FOUND THEN ', 나쁜 상태 하나를 걷어냈다.' ELSE '.' END);
  ELSIF act = 'skill' AND c.job_key = 'analyst' THEN
    v_pfx := v_pfx || jsonb_build_object('focus', CASE WHEN 'analysis_m50' = ANY (sk) THEN 5 ELSE 3 END, 'focus_fresh', true, 'u_an', coalesce((v_pfx ->> 'u_an')::int, 0) + 1);
    lines := lines || jsonb_build_array('약점 간파: ' || m.monster_name || '의 빈틈을 읽었다. 다음 ' || CASE WHEN 'analysis_m50' = ANY (sk) THEN '다섯' ELSE '세' END || ' 번의 공격이 강해진다.');
  ELSE
    attacked := true;
    IF act = 'skill' AND c.job_key = 'exorcist' THEN style := 'magic'; skill_name := '퇴마진';
    ELSIF act = 'skill' AND c.job_key = 'scout' THEN style := 'ranged'; skill_name := '급소 사격';
    ELSIF act = 'skill' AND c.job_key = 'sealmaster' THEN skill_name := '봉인술';
    ELSIF act = 'skill' AND c.job_key = 'artificer' THEN style := 'melee'; skill_name := '파갑참';
    END IF;
    base := (st ->> 'attack_raw')::numeric;
    -- 원거리 무기는 화살·쇠뇌살·취관 침을 한 발에 하나 쓴다(없으면 피해 절반)
    IF style = 'ranged' THEN
      ammo_k := public.world_ammo_of(uid);
      IF ammo_k IS NOT NULL THEN
        IF coalesce((inv ->> ammo_k)::int, 0) > 0 THEN inv := public.world_inv_add(inv, ammo_k, -1);
        ELSE base := base * 0.5; v_weak := 'ammo'; lines := lines || jsonb_build_array('쏠 것이 떨어져 활대로 내리쳤다. (피해 절반)'); END IF;
      END IF;
    END IF;
    IF style = 'magic' AND act = 'attack' THEN
      IF sp >= 3 THEN sp := sp - 3; ELSE base := base * 0.5; v_weak := 'mp'; lines := lines || jsonb_build_array('영력이 바닥나 술법이 약해졌다.'); END IF;
    END IF;
    -- 근접 무기는 영력 대신 기력(같은 수치, 화면에서 노란 게이지)을 공격마다 2 쓴다(없으면 피해 절반)
    IF style = 'melee' AND act = 'attack' THEN
      IF sp >= 2 THEN sp := sp - 2; ELSE base := base * 0.5; v_weak := 'sp'; lines := lines || jsonb_build_array('기력이 바닥나 칼끝에 힘이 실리지 않았다. (피해 절반)'); END IF;
    END IF;
    keen := coalesce((v_pfx ->> 'focus')::int, 0) > 0 OR coalesce((v_fx ->> 'marked')::int, 0) > 0 OR (first_atk AND 'ranged_x13' = ANY (sk));
    mul := 0.85 + random() * 0.3;
    mul := mul * public.world_kind_mult(m.kind, style, c.job_key);
    -- 약점 간파 뒤 첫 공격(급소 간파): 반드시 치명타, 치명타 피해 ×2
    IF coalesce((v_pfx ->> 'focus_fresh')::boolean, false) THEN
      IF 'analysis_c24a' = ANY (sk) THEN force_crit := true; crit_x := 2.0; END IF;
      v_pfx := v_pfx - 'focus_fresh';
    END IF;
    IF coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN mul := mul * 1.4 * (CASE WHEN coalesce((c.skill_progress -> 'analysis' ->> 'rank')::int, 0) >= 3 THEN 1.08 ELSE 1 END); v_pfx := v_pfx || jsonb_build_object('focus', (v_pfx ->> 'focus')::int - 1); END IF;
    IF coalesce((v_fx ->> 'marked')::int, 0) > 0 THEN mul := mul * 1.25; v_fx := v_fx || jsonb_build_object('marked', (v_fx ->> 'marked')::int - 1); END IF;
    IF coalesce((v_fx ->> 'airborne')::boolean, false) THEN
      mul := mul * CASE style WHEN 'melee' THEN 0.4 WHEN 'ranged' THEN 1.2 ELSE 0.9 END;
    END IF;
    -- 고유 효과: 피해 배율
    IF style = 'melee' AND 'melee_c24a' = ANY (sk) AND a.current_hp < a.max_hp * 0.3 THEN mul := mul * 1.4; lines := lines || jsonb_build_array('「일격」 마무리를 노렸다.'); END IF;
    IF style = 'ranged' AND 'ranged_c24a' = ANY (sk) AND a.current_hp > a.max_hp * 0.7 THEN mul := mul * 1.3; END IF;
    IF style = 'ranged' AND 'ranged_x30' = ANY (sk) AND m.kind IN ('bird', 'sky') THEN mul := mul * 1.25; END IF;
    IF style = 'ranged' AND first_atk AND 'combo_ranged_tracking' = ANY (sk) THEN mul := mul * 1.5; lines := lines || jsonb_build_array('「사냥꾼의 눈」 먼저 겨눴다.'); END IF;
    IF 'analysis_x30' = ANY (sk) AND EXISTS (SELECT 1 FROM public.world_monster_codex x WHERE x.owner_id = uid AND x.monster_id = m.monster_id AND x.defeated > 0) THEN mul := mul * 1.15; END IF;
    IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN mul := mul * 1.2; END IF;
    IF coalesce((v_pfx ->> 'brace')::boolean, false) THEN mul := mul * 1.20; v_pfx := v_pfx - 'brace'; lines := lines || jsonb_build_array('「버팀 기세」 받아 낸 힘을 실었다.'); END IF;
    IF coalesce((v_pfx ->> 'gd_last')::boolean, false) AND coalesce((c.skill_progress -> 'guarding' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.08; END IF;
    v_pfx := v_pfx - 'gd_last';
    IF style = 'melee' AND c.job_key = 'artificer' AND m.mechanic_key = 'armored' AND coalesce((c.skill_progress -> 'melee' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.08; END IF;
    IF style = 'magic' AND c.job_key = 'sealmaster' AND m.mechanic_key = 'warded' AND coalesce((c.skill_progress -> 'sealing' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;
    IF style = 'melee' AND c.job_key = 'analyst' AND m.kind IN ('mirror', 'shadow') AND coalesce((c.skill_progress -> 'dagger' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.08; END IF;
    IF style = 'magic' AND c.job_key = 'exorcist' AND m.kind IN ('ghost', 'breaker') AND coalesce((c.skill_progress -> 'exorcism' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;
    IF style = 'magic' AND c.job_key = 'medic' AND m.kind IN ('venom', 'water') AND coalesce((c.skill_progress -> 'medicine' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;
    IF style = 'magic' AND 'exorcism_c13b' = ANY (sk) THEN mul := mul * CASE WHEN m.kind IN ('ghost', 'shadow', 'breaker') THEN 1.26 ELSE 1.08 END; END IF;
    IF style = 'melee' AND 'dagger_c13b' = ANY (sk) THEN
      mul := mul * (1 + 0.04 * least(5, coalesce((v_pfx ->> 'dissect')::int, 0)));
      v_pfx := v_pfx || jsonb_build_object('dissect', least(5, coalesce((v_pfx ->> 'dissect')::int, 0) + 1));
    END IF;
    IF coalesce((v_fx ->> 'dazed')::int, 0) > 0 THEN
      IF 'sealing_x30' = ANY (sk) THEN mul := mul * 1.3; lines := lines || jsonb_build_array('「겹술식」 무방비한 틈을 찔렀다.'); END IF;
      v_fx := v_fx - 'dazed';
    END IF;
    IF skill_name = '퇴마진' THEN mul := mul * CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 1.7 ELSE 1.4 END; v_fx := v_fx - 'barrier';
    ELSIF skill_name = '급소 사격' THEN mul := mul * 1.4; v_fx := v_fx || jsonb_build_object('marked', 3);
    ELSIF skill_name = '파갑참' THEN mul := mul * 1.7;
    ELSIF skill_name = '봉인술' THEN mul := mul * 1.1;
    END IF;
    -- 치명타: 발도(첫 근접 공격), 유수검(막기·회피 뒤)
    IF first_atk AND style = 'melee' AND 'melee_x13' = ANY (sk) THEN force_crit := true; END IF;
    IF coalesce((v_pfx ->> 'flow')::boolean, false) THEN force_crit := true; v_pfx := v_pfx - 'flow'; END IF;
    IF style = 'magic' AND 'exorcism_m50' = ANY (sk) THEN crit_x := greatest(crit_x, 2.0); END IF;
    cc := least(0.65, crit_p / 100.0 + (CASE WHEN coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN 0.1 ELSE 0 END));
    crit := skill_name = '퇴마진' OR force_crit OR random() < cc;
    IF crit THEN mul := mul * crit_x; END IF;
    mdef := a.def;
    IF coalesce((v_fx ->> 'harden')::int, 0) > 0 AND style IN ('melee', 'ranged') AND skill_name IS DISTINCT FROM '파갑참'
       AND NOT ((style = 'ranged' AND 'ranged_c43a' = ANY (sk)) OR (crit AND style = 'melee' AND 'dagger_c43b' = ANY (sk))) THEN mdef := mdef * 3; END IF;
    v_fx := v_fx - 'harden';
    IF skill_name = '파갑참' OR ((style = 'ranged' AND 'ranged_c43a' = ANY (sk)) OR (crit AND style = 'melee' AND 'dagger_c43b' = ANY (sk))) THEN mdef := 0; END IF;
    dmg := greatest(1, round(base * mul - mdef * 0.8));
    IF coalesce((v_pfx ->> 'surge')::int, 0) > 0 THEN dmg := dmg + (v_pfx ->> 'surge')::int; lines := lines || jsonb_build_array('「역류」 막아 낸 힘을 실었다. +' || (v_pfx ->> 'surge')); v_pfx := v_pfx - 'surge'; END IF;
    IF coalesce((v_fx ->> 'evade')::int, 0) > 0 AND NOT keen AND random() < 0.5 THEN dmg := 0; lines := lines || jsonb_build_array('허상을 쳤다. 공격이 빗나갔다.'); END IF;
    shield := coalesce((v_fx ->> 'barrier')::int, 0);
    IF shield > 0 AND skill_name IS DISTINCT FROM '파갑참' AND NOT ((style = 'ranged' AND 'ranged_c43a' = ANY (sk)) OR (crit AND style = 'melee' AND 'dagger_c43b' = ANY (sk))) THEN
      IF style = 'magic' THEN shield := shield - dmg * 2; ELSE shield := shield - dmg; END IF;
      IF shield > 0 THEN v_fx := v_fx || jsonb_build_object('barrier', shield); lines := lines || jsonb_build_array('결계가 공격을 삼켰다.'); dmg := 0;
      ELSE v_fx := v_fx - 'barrier'; dmg := greatest(1, -shield / (CASE WHEN style = 'magic' THEN 2 ELSE 1 END)); lines := lines || jsonb_build_array('결계가 깨졌다.'); END IF;
    END IF;
    IF coalesce((v_fx ->> 'mirror')::int, 0) > 0 AND style = 'magic' AND dmg > 0 THEN
      reflect := least(15, round(dmg * 0.3)); v_fx := v_fx - 'mirror';
    END IF;
    a.current_hp := greatest(0, a.current_hp - dmg);
    lines := lines || jsonb_build_array(coalesce(skill_name, CASE style WHEN 'ranged' THEN '사격' WHEN 'magic' THEN '술법' ELSE '베기' END) || ': ' || dmg || ' 피해'
      || CASE WHEN crit THEN ' (치명타)' ELSE '' END);
    -- 고유 효과: 추가 타격(연타·검신·속사·연환시)
    IF dmg > 0 AND a.current_hp > 0 THEN
      IF style = 'melee' AND 'melee_m50' = ANY (sk) AND random() < 0.2 THEN
        extra := greatest(1, round(dmg * 0.5)); a.current_hp := greatest(0, a.current_hp - extra * 2); ex_total := extra * 2;
        lines := lines || jsonb_build_array('「검신」 세 번 연속 베었다: +' || extra || ' · +' || extra);
      ELSIF style = 'ranged' AND 'ranged_c24b' = ANY (sk) AND random() < 0.2 AND (ammo_k IS NULL OR coalesce((inv ->> ammo_k)::int, 0) > 0) THEN
        IF ammo_k IS NOT NULL THEN inv := public.world_inv_add(inv, ammo_k, -1); END IF;
        extra := greatest(1, round(dmg * 0.6)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := extra;
        lines := lines || jsonb_build_array('「속사」 연사: ' || extra || ' 피해');
        IF 'ranged_c43b' = ANY (sk) AND random() < 0.5 AND a.current_hp > 0 AND (ammo_k IS NULL OR coalesce((inv ->> ammo_k)::int, 0) > 0) THEN
        IF ammo_k IS NOT NULL THEN inv := public.world_inv_add(inv, ammo_k, -1); END IF;
        a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra;
        lines := lines || jsonb_build_array('「연환시」 세 번째 화살: ' || extra || ' 피해');
        END IF;
      END IF;
    END IF;
    -- 고유 효과: 치명타가 남기는 것(파천·필살 계산·천궁)
    IF crit AND dmg > 0 THEN
      IF (style = 'melee' AND 'melee_c43a' = ANY (sk)) OR 'analysis_c43a' = ANY (sk) THEN
        v_fx := v_fx || jsonb_build_object('broken', 3); lines := lines || jsonb_build_array(m.monster_name || '의 방어가 무너졌다(다음 두 번 받는 피해 +20%).');
      END IF;
      IF style = 'ranged' AND 'ranged_m50' = ANY (sk) THEN
        v_fx := v_fx || jsonb_build_object('pierce', 3); lines := lines || jsonb_build_array('「천궁」 화살이 꿰뚫고 박혔다.');
      END IF;
    END IF;
    -- 고유 효과: 술법(폭렬부·천뢰부·정심주·청정결)
    IF style = 'magic' AND dmg > 0 AND a.current_hp > 0 THEN
      IF 'sealing_c13a' = ANY (sk) AND random() < 0.25 THEN extra := greatest(1, round(dmg * 0.4)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「연쇄부」 부적이 튀어 ' || extra || ' 피해'); END IF;
      IF 'sealing_c30a' = ANY (sk) AND random() < 0.25 AND a.current_hp > 0 THEN extra := greatest(1, round(dmg * 0.7)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「연환부」 한 번 더 시전: ' || extra || ' 피해'); END IF;
      IF 'sealing_c24a' = ANY (sk) AND random() < 0.2 AND a.current_hp > 0 THEN extra := greatest(1, round(dmg * 0.25)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「폭렬부」 술식이 터졌다: ' || extra || ' 피해'); END IF;
      IF 'sealing_c43a' = ANY (sk) AND random() < 0.15 AND a.current_hp > 0 THEN extra := greatest(1, round(a.max_hp * 0.08)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「천뢰부」 벼락: ' || extra || ' 피해'); END IF;
    END IF;
    IF style = 'magic' AND 'sealing_c24b' = ANY (sk) THEN
      v_pfx := v_pfx || jsonb_build_object('pshield', least(16, coalesce((v_pfx ->> 'pshield')::int, 0) + 4));
      IF coalesce((v_pfx ->> 'calm')::int, 0) < 5 THEN mn := least(100, mn + 2); v_pfx := v_pfx || jsonb_build_object('calm', coalesce((v_pfx ->> 'calm')::int, 0) + 1); END IF;
    END IF;
    -- 청정결계: 술법을 쓰면 3턴 동안 받는 피해 −20%
    IF style = 'magic' AND 'sealing_c43b' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('ward', 3); END IF;
    IF style = 'magic' AND 'sealing_c43b' = ANY (sk) AND random() < 0.3 AND er > 0 THEN er := er - 1; END IF;
    -- 강기 두르기: 근접 공격마다 보호막 +3(최대 15)
    IF style = 'melee' AND 'melee_x30' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('pshield', least(15, coalesce((v_pfx ->> 'pshield')::int, 0) + 3)); END IF;
    IF style = 'melee' AND dmg > 0 AND a.current_hp > 0 THEN
      IF 'dagger_c24b' = ANY (sk) AND random() < 0.2 THEN
        v_fx := v_fx || jsonb_build_object('pierce', greatest(2, coalesce((v_fx ->> 'pierce')::int, 0))); lines := lines || jsonb_build_array('「독 바른 날」 날의 독이 스며들었다.');
      END IF;
      IF 'dagger_c30b' = ANY (sk) AND random() < 0.3 THEN
        v_fx := v_fx || jsonb_build_object('weak', greatest(2, coalesce((v_fx ->> 'weak')::int, 0))); lines := lines || jsonb_build_array('「그림자 덫」 ' || m.monster_name || '의 다음 공격이 무뎌진다.');
      END IF;
    END IF;
    IF style = 'magic' AND dmg > 0 THEN
      IF 'exorcism_c24b' = ANY (sk) AND (v_fx ? 'barrier' OR v_fx ? 'evade') AND random() < 0.4 THEN
        v_fx := (v_fx - 'barrier' - 'evade') || jsonb_build_object('weak', greatest(2, coalesce((v_fx ->> 'weak')::int, 0))); lines := lines || jsonb_build_array('「퇴마 진언」 요괴의 결계와 허상을 걷어 냈다. 다음 공격이 약해진다.');
      END IF;
      IF 'exorcism_c30b' = ANY (sk) AND er > 0 AND random() < 0.5 THEN er := er - 1; END IF;
      IF 'exorcism_c30b' = ANY (sk) AND a.current_hp > 0 AND random() < 0.25 THEN
        v_fx := v_fx || jsonb_build_object('pierce', greatest(2, coalesce((v_fx ->> 'pierce')::int, 0))); lines := lines || jsonb_build_array('「정화의 불」 요기를 사르는 불이 붙었다.');
      END IF;
      IF 'medicine_c24b' = ANY (sk) AND coalesce((v_pfx ->> 'mend')::int, 0) < 6 AND hp < 100 THEN
        hp := least(100, hp + 3); v_pfx := v_pfx || jsonb_build_object('mend', coalesce((v_pfx ->> 'mend')::int, 0) + 1); lines := lines || jsonb_build_array('「보신 처방」 체력 +3');
      END IF;
      IF 'medicine_c30b' = ANY (sk) AND random() < 0.35 THEN
        UPDATE public.world_character_statuses SET expires_at = now() WHERE status_id = (SELECT cs.status_id FROM public.world_character_statuses cs JOIN public.world_status_catalog sc USING (status_key)
        WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' AND cs.status_key NOT IN ('yohwa', 'yohwa_seal') ORDER BY cs.expires_at LIMIT 1);
        IF FOUND THEN lines := lines || jsonb_build_array('「해독 처방」 나쁜 상태 하나를 풀었다.'); END IF;
      END IF;
    END IF;
    v_pfx := v_pfx || jsonb_build_object('opened', true);
    IF reflect > 0 AND hp > 1 THEN reflect := least(reflect, hp - 1); hp := hp - reflect; lines := lines || jsonb_build_array('거울막이 술법을 되돌려 ' || reflect || ' 피해를 입었다.'); END IF;
    IF coalesce((v_fx ->> 'thorns')::int, 0) > 0 AND style = 'melee' AND dmg > 0 THEN thorn := least(15, greatest(1, round(dmg * 0.3))); hp := greatest(least(hp, 1), hp - thorn); lines := lines || jsonb_build_array('가시에 찔려 ' || thorn || ' 피해를 입었다.'); END IF;
    IF skill_name = '봉인술' THEN
      resist := CASE WHEN 'sealing_x13' = ANY (sk) THEN 0.35 ELSE 0.5 END;
      IF 'sealing_m50' = ANY (sk) THEN resist := resist / 2; END IF;
      IF a.rank = 'guardian' AND random() < resist THEN lines := lines || jsonb_build_array('우두머리가 봉인을 떨쳐냈다.');
      ELSE v_fx := v_fx || jsonb_build_object('stunned', CASE WHEN 'combo_sealing_wardcraft' = ANY (sk) THEN 2 ELSE 1 END);
        IF 'sealing_x13' = ANY (sk) THEN v_fx := v_fx || jsonb_build_object('broken', 3); lines := lines || jsonb_build_array('「부적 접기」 묶인 틈에 방어가 풀렸다.'); END IF;
        IF 'sealing_x30' = ANY (sk) THEN v_fx := v_fx || jsonb_build_object('weak', 4); lines := lines || jsonb_build_array('「겹술식」 기운이 꺾여 2턴 동안 공격이 약해진다.'); END IF;
        lines := lines || jsonb_build_array(m.monster_name || '의 움직임을 봉했다' || CASE WHEN 'combo_sealing_wardcraft' = ANY (sk) THEN '(겹봉인: 2턴)' ELSE '' END || '.'); END IF;
    END IF;
    IF NOT ('combo_melee_smithing' = ANY (sk) AND random() < 0.5) THEN
      wear := public.world_durability_wear(uid, 'weapon', 1);
      IF coalesce((wear ->> 'broke')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 부서졌다! 수리할 때까지 맨손만 못한 위력으로 싸운다.');
      ELSIF coalesce((wear ->> 'worn')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '의 날이 무뎌졌다. 수리가 필요하다.'); END IF;
    END IF;
  END IF;

  -- 꿰뚫림(천궁): 매턴 적 최대 체력 4%
  IF coalesce((v_fx ->> 'pierce')::int, 0) > 0 AND a.current_hp > 0 THEN
    extra := greatest(1, round(a.max_hp * 0.04)); a.current_hp := greatest(0, a.current_hp - extra);
    v_fx := v_fx || jsonb_build_object('pierce', (v_fx ->> 'pierce')::int - 1);
    IF (v_fx ->> 'pierce')::int <= 0 THEN v_fx := v_fx - 'pierce'; END IF;
    lines := lines || jsonb_build_array('박힌 화살이 파고든다: ' || extra || ' 피해');
  END IF;
  IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN
    v_fx := v_fx || jsonb_build_object('broken', (v_fx ->> 'broken')::int - 1);
    IF (v_fx ->> 'broken')::int <= 0 THEN v_fx := v_fx - 'broken'; END IF;
  END IF;
  IF coalesce((v_fx ->> 'weak')::int, 0) > 0 THEN
    v_fx := v_fx || jsonb_build_object('weak', (v_fx ->> 'weak')::int - 1);
    IF (v_fx ->> 'weak')::int <= 0 THEN v_fx := v_fx - 'weak'; END IF;
  END IF;
  IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 AND NOT (style = 'magic' AND attacked AND 'sealing_c43b' = ANY (sk)) THEN
    v_pfx := v_pfx || jsonb_build_object('ward', (v_pfx ->> 'ward')::int - 1);
    IF (v_pfx ->> 'ward')::int <= 0 THEN v_pfx := v_pfx - 'ward'; END IF;
  END IF;

  v_pfx := v_pfx - 'bound'; v_fx := v_fx - 'evade' - 'thorns' - 'mirror';
  IF a.current_hp <= 0 THEN
    ended := 'victory';
  ELSIF fled THEN
    ended := 'fled';
  ELSE
    IF NOT pf_skip AND coalesce((v_fx ->> 'stunned')::int, 0) > 0 THEN
      skip_monster := true;
      IF (v_fx ->> 'stunned')::int > 1 THEN v_fx := v_fx || jsonb_build_object('stunned', (v_fx ->> 'stunned')::int - 1);
      ELSE v_fx := v_fx - 'stunned'; END IF;
      v_fx := v_fx || jsonb_build_object('dazed', 1);
      lines := lines || jsonb_build_array(m.monster_name || '이(가) 봉인에 묶여 움직이지 못했다.');
      next_intent := public.world_battle_intent_k(m.kind, a.mlevel, m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank);
    END IF;
    -- 흐름 읽기: 기믹을 예고한 턴에 공격하면 30% 확률로 끊는다
    IF NOT skip_monster AND attacked AND 'analysis_c24b' = ANY (sk) AND v_intent LIKE 'g:%' AND random() < 0.3 THEN
      SELECT name INTO gname FROM public.world_monster_gimmicks WHERE gimmick_key = split_part(v_intent, ':', 2);
      lines := lines || jsonb_build_array('「흐름 읽기」 ' || coalesce('「' || gname || '」', '그 수법') || '을(를) 미리 끊었다.');
      v_intent := 'strike';
    END IF;
    IF NOT skip_monster THEN
      hit := a.atk * (0.9 + random() * 0.2);
      IF coalesce((v_fx ->> 'weak')::int, 0) > 0 THEN hit := hit * 0.8; END IF;
      IF coalesce((v_fx ->> 'swarm')::int, 0) > 0 AND v_intent IN ('strike', 'heavy') THEN hit := hit * 1.3; v_fx := v_fx - 'swarm'; END IF;
      hit := hit * CASE v_intent WHEN 'strike' THEN 1 WHEN 'heavy' THEN 1.9 WHEN 'dive' THEN 1.7 WHEN 'pounce' THEN 2.0 WHEN 'unleash' THEN 2.6
        WHEN 'harden' THEN 0.5 WHEN 'wail' THEN 0.6 WHEN 'venom' THEN 0.6 WHEN 'mirror' THEN 0.4 WHEN 'tide' THEN 0.8 WHEN 'barrier' THEN 0.3
        WHEN 'breach' THEN 0.7 ELSE 0 END;
      IF v_intent LIKE 'g%:%' THEN
        SELECT * INTO g FROM public.world_monster_gimmicks WHERE gimmick_key = split_part(v_intent, ':', 2);
        gburst := v_intent LIKE 'g!:%';
        IF g.gimmick_key IS NULL THEN hit := a.atk * (0.9 + random() * 0.2);
        ELSIF g.gtype = 'charge' AND NOT gburst THEN
        hit := 0;
        IF dmg + ex_total + coalesce(nullif(current_setting('yh.pf_dmg', true), '')::int, 0) >= a.max_hp * brk THEN lines := lines || jsonb_build_array(m.monster_name || '의 기세가 흐트러져 「' || g.name || '」이(가) 끊겼다.');
        ELSE next_intent := 'g!:' || g.gimmick_key; lines := lines || jsonb_build_array(m.monster_name || ': ' || g.tell); END IF;
        ELSE
        hit := a.atk * (0.9 + random() * 0.2) * g.power;
        IF g.gtype = 'heal' THEN
        mheal := round(a.max_hp * g.power2 * CASE WHEN act = 'skill' THEN 0.5 ELSE 1 END); a.current_hp := least(a.max_hp, a.current_hp + mheal);
        lines := lines || jsonb_build_array(m.monster_name || '의 「' || g.name || '」: 체력 ' || mheal || ' 회복' || CASE WHEN act = 'skill' THEN ' (기술로 절반을 끊음)' ELSE '' END);
        ELSIF g.gtype = 'summon' THEN
        a.current_hp := least(a.max_hp, a.current_hp + round(a.max_hp * g.power2)); v_fx := v_fx || jsonb_build_object('swarm', 1);
        lines := lines || jsonb_build_array(m.monster_name || '의 「' || g.name || '」: 무리가 몰려든다.');
        ELSIF g.gtype = 'shield' THEN
        v_fx := v_fx || jsonb_build_object('barrier', coalesce((v_fx ->> 'barrier')::int, 0) + round(a.max_hp * g.power2));
        lines := lines || jsonb_build_array(m.monster_name || '의 「' || g.name || '」: 결계가 둘러졌다.');
        ELSIF g.gtype = 'evade' THEN v_fx := v_fx || jsonb_build_object('evade', 1);
        ELSIF g.gtype = 'thorns' THEN v_fx := v_fx || jsonb_build_object('thorns', 1);
        ELSIF g.gtype = 'mirror' THEN v_fx := v_fx || jsonb_build_object('mirror', 1);
        END IF;
        END IF;
      END IF;
      v_fx := v_fx - 'airborne';
      IF v_intent = 'soar' THEN v_fx := v_fx || jsonb_build_object('airborne', true); next_intent := 'dive'; lines := lines || jsonb_build_array(m.monster_name || '이(가) 하늘로 솟구쳤다.');
      ELSIF v_intent = 'lurk' THEN next_intent := 'pounce'; lines := lines || jsonb_build_array(m.monster_name || '이(가) 그림자 속으로 숨었다.');
      ELSIF v_intent = 'charge' THEN next_intent := 'unleash'; lines := lines || jsonb_build_array(m.monster_name || '이(가) 기를 모은다.');
      ELSIF v_intent = 'harden' THEN v_fx := v_fx || jsonb_build_object('harden', 1); lines := lines || jsonb_build_array(m.monster_name || '이(가) 껍질을 굳혔다.');
      ELSIF v_intent = 'swarm' THEN
        a.current_hp := least(a.max_hp, a.current_hp + round(a.max_hp * 0.1)); v_fx := v_fx || jsonb_build_object('swarm', 1);
        lines := lines || jsonb_build_array(m.monster_name || '이(가) 무리를 불러 모았다.');
      ELSIF v_intent = 'mirror' THEN v_fx := v_fx || jsonb_build_object('mirror', 1); lines := lines || jsonb_build_array(m.monster_name || '이(가) 거울막을 둘렀다.');
      ELSIF v_intent = 'barrier' THEN v_fx := v_fx || jsonb_build_object('barrier', round(a.max_hp * 0.12)); lines := lines || jsonb_build_array(m.monster_name || '이(가) 결계를 펼쳤다.');
      ELSIF v_intent = 'rest' THEN a.current_hp := least(a.max_hp, a.current_hp + round(a.max_hp * 0.06)); lines := lines || jsonb_build_array(m.monster_name || '이(가) 숨을 골랐다.');
      END IF;
      IF hit > 0 THEN
        mdmg := round(hit * 100.0 / (100 + defv * 3));
        raw_m := mdmg;
        IF guarding THEN mdmg := round(mdmg * (CASE WHEN v_intent IN ('heavy', 'dive', 'pounce', 'unleash') OR gburst OR g.gtype IS NOT DISTINCT FROM 'big' THEN 0.25 ELSE 0.35 END)); END IF;
        IF guarding AND 'guarding_x13' = ANY (sk) THEN mdmg := round(mdmg * 0.8); END IF;
        IF guarding AND 'melee_g43' = ANY (sk) THEN mdmg := round(mdmg * 0.7); v_pfx := v_pfx || jsonb_build_object('pshield', least(20, coalesce((v_pfx ->> 'pshield')::int, 0) + 4)); END IF;
        IF guarding AND 'melee_g50' = ANY (sk) AND mdmg > 0 AND random() < 0.3 THEN mdmg := 0; lines := lines || jsonb_build_array('「금강 수호」 공격을 완전히 받아 냈다.'); END IF;
        IF guarding AND coalesce((c.skill_progress -> 'guarding' ->> 'rank')::int, 0) >= 3 THEN mdmg := round(mdmg * 0.9); END IF;
        IF g.gimmick_key IS NOT NULL AND 'analysis_x13' = ANY (sk) THEN mdmg := round(mdmg * 0.8); END IF;
        IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 THEN mdmg := round(mdmg * CASE WHEN 'exorcism_c43b' = ANY (sk) THEN 0.74 ELSE 0.8 END); END IF;
        IF 'melee_c13b' = ANY (sk) AND mdmg > 0 AND NOT coalesce((v_pfx ->> 'cowed')::boolean, false) THEN mdmg := round(mdmg * 0.7); v_pfx := v_pfx || jsonb_build_object('cowed', true, 'cowed_now', true); END IF;
        IF coalesce((v_pfx ->> 'roar')::int, 0) > 0 THEN mdmg := round(mdmg * 0.85); END IF;
        mdmg := round(mdmg * (1 + inc / 100.0) * (1 - adr / 100.0) * greatest(0.7, least(1.3, 1 - 0.03 * (c.level - a.mlevel))));
        IF c.health < 30 THEN mdmg := ceil(mdmg * 1.15); END IF;
        IF hp < 30 AND 'melee_g30' = ANY (sk) THEN mdmg := round(mdmg * 0.75); END IF;
        eva_now := eva + CASE WHEN 'analysis_m50' = ANY (sk) AND coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN 15 ELSE 0 END;
        IF guarding AND 'guarding_c24a' = ANY (sk) AND coalesce((v_pfx ->> 'wall_cd')::int, 0) <= turn THEN
        mdmg := 0; v_pfx := v_pfx || jsonb_build_object('wall_cd', turn + 3); lines := lines || jsonb_build_array('「철벽」 공격을 완전히 막아 냈다.');
        ELSIF NOT guarding AND random() * 100 < eva_now * (CASE WHEN v_intent IN ('heavy', 'pounce', 'unleash') OR gburst THEN 0.6 ELSE 1 END) THEN
        mdmg := 0; lines := lines || jsonb_build_array('몸을 틀어 공격을 피했다.');
        IF 'melee_c30a' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('flow', true); END IF;
        END IF;
        mdmg := greatest(0, mdmg);
        -- 호령은 실제로 맞은 첫 공격에만(피하거나 철벽으로 막으면 다음 공격으로 넘어감)
        IF coalesce((v_pfx ->> 'cowed_now')::boolean, false) THEN
        IF mdmg > 0 THEN lines := lines || jsonb_build_array('「호령」 기세에 눌린 첫 공격이 무뎌졌다.'); ELSE v_pfx := v_pfx - 'cowed'; END IF;
        v_pfx := v_pfx - 'cowed_now';
        END IF;
        IF guarding AND 'melee_c30a' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('flow', true); END IF;
        IF guarding AND 'guarding_c43b' = ANY (sk) AND raw_m > mdmg THEN v_pfx := v_pfx || jsonb_build_object('surge', least(40, raw_m - mdmg)); END IF;
        m_pre := mdmg;
        -- 강기 보호막이 먼저 받는다
        IF mdmg > 0 AND coalesce((v_pfx ->> 'pshield')::int, 0) > 0 THEN
        absorb := least(mdmg, (v_pfx ->> 'pshield')::int); mdmg := mdmg - absorb;
        v_pfx := v_pfx || jsonb_build_object('pshield', (v_pfx ->> 'pshield')::int - absorb);
        lines := lines || jsonb_build_array('「강기」가 ' || absorb || ' 피해를 막았다.');
        END IF;
        hp := greatest(0, hp - mdmg);
        IF m_pre > 0 THEN
        lines := lines || jsonb_build_array(m.monster_name || CASE v_intent WHEN 'heavy' THEN '의 강타' WHEN 'dive' THEN '의 급강하' WHEN 'pounce' THEN '의 기습'
        WHEN 'unleash' THEN '의 폭발' WHEN 'venom' THEN '의 독 분사' WHEN 'wail' THEN '의 곡성' WHEN 'tide' THEN '의 물살' WHEN 'breach' THEN '의 봉인 깨기' ELSE CASE WHEN g.gimmick_key IS NOT NULL THEN '의 「' || g.name || '」' ELSE '의 공격' END END
        || ': ' || mdmg || ' 피해' || CASE WHEN guarding THEN ' (막음)' ELSE '' END);
        wear := public.world_durability_wear(uid, 'hat', 1); IF coalesce((wear ->> 'broke')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 부서졌다!'); END IF; wear := public.world_durability_wear(uid, 'armor', 1);
        IF coalesce((wear ->> 'broke')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 찢어졌다! 수리할 때까지 막아 주지 못한다.');
        ELSIF coalesce((wear ->> 'worn')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 해어졌다. 수리가 필요하다.'); END IF;
        IF guarding AND (v_intent IN ('heavy', 'dive', 'pounce', 'unleash') OR gburst OR g.gtype IS NOT DISTINCT FROM 'big') AND style = 'melee' THEN
        dmg := round(m_pre * 1.2 + c.strength * 0.5); a.current_hp := greatest(0, a.current_hp - dmg);
        lines := lines || jsonb_build_array('받아치기: ' || dmg || ' 피해');
        END IF;
        IF guarding AND 'guarding_c24b' = ANY (sk) THEN
        extra := greatest(1, round(m_pre * 0.5)); a.current_hp := greatest(0, a.current_hp - extra); lines := lines || jsonb_build_array('「반격 태세」 ' || extra || ' 피해를 되돌렸다.');
        END IF;
        IF guarding AND 'melee_g13' = ANY (sk) AND a.current_hp > 0 THEN
        extra := greatest(1, round(raw_m * 0.4 + c.strength * 0.5)); a.current_hp := greatest(0, a.current_hp - extra); lines := lines || jsonb_build_array('「반격 자세」 ' || extra || ' 피해를 되받아쳤다.');
        END IF;
        IF guarding AND 'melee_g24' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('brace', true); END IF;
        IF guarding AND 'combo_guarding_mining' = ANY (sk) THEN
        extra := greatest(1, round(m_pre * 0.3)); hp := least(100, hp + extra); lines := lines || jsonb_build_array('「바위 몸」 체력 +' || extra);
        END IF;
        IF v_intent = 'wail' THEN mn := greatest(0, mn - greatest(0, round(6 * (1 + public.world_status_effect_total('mental_loss_pct') / 100.0))::int)); IF random() < 0.35 THEN statuses := array_append(statuses, 'shaken'); END IF; END IF;
        IF v_intent = 'venom' AND random() < 0.45 THEN statuses := array_append(statuses, 'poisoned'); END IF;
        IF v_intent = 'tide' AND random() < 0.3 THEN statuses := array_append(statuses, 'cold'); END IF;
        IF v_intent = 'breach' THEN PERFORM public.world_yohwa_overflow(uid, er + greatest(1, round(4 * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int) - 100); er := least(100, er + greatest(1, round(4 * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int)); END IF;
        IF v_intent IN ('heavy', 'pounce') AND NOT guarding AND random() < 0.2 THEN statuses := array_append(statuses, 'bleeding'); END IF;
        IF g.gimmick_key IS NOT NULL THEN
        IF g.status IS NOT NULL AND random() < g.chance * (CASE WHEN guarding THEN 0.5 ELSE 1 END) THEN statuses := array_append(statuses, g.status); END IF;
        IF g.mental > 0 THEN mn := greatest(0, mn - greatest(0, round(g.mental * (CASE WHEN guarding THEN 0.5 ELSE 1 END) * (1 + public.world_status_effect_total('mental_loss_pct') / 100.0))::int)); END IF;
        IF g.erosion > 0 THEN PERFORM public.world_yohwa_overflow(uid, er + greatest(1, round(g.erosion * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int) - 100); er := least(100, er + greatest(1, round(g.erosion * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int)); END IF;
        IF g.gtype = 'drain' THEN mheal := round(mdmg * g.power2); a.current_hp := least(a.max_hp, a.current_hp + mheal); lines := lines || jsonb_build_array(m.monster_name || '이(가) 기운을 빨아 체력 ' || mheal || ' 회복'); END IF;
        IF g.gtype = 'grapple' THEN
        IF 'guarding_x30' = ANY (sk) THEN lines := lines || jsonb_build_array('「부동」 붙잡히지 않았다.');
        ELSE v_pfx := v_pfx || jsonb_build_object('bound', 1); lines := lines || jsonb_build_array('붙잡혔다. 다음 턴에는 달아날 수 없다.'); END IF;
        END IF;
        END IF;
        END IF;
      END IF;
      -- 만장성벽: 방어한 턴에는 상태이상이 붙지 않는다
      IF guarding AND 'guarding_m50' = ANY (sk) AND cardinality(statuses) > 0 THEN statuses := '{}'; lines := lines || jsonb_build_array('「만장성벽」 나쁜 기운을 모두 튕겨 냈다.'); END IF;
    END IF;
    IF a.current_hp <= 0 THEN ended := 'victory'; END IF;
    -- 기사회생: 체력이 25 아래로 떨어지면 한 번 +30
    IF ended IS NULL AND hp > 0 AND hp < 25 AND 'first_aid_m50' = ANY (sk) AND NOT coalesce((v_pfx ->> 'rallied')::boolean, false) THEN
      hp := least(100, hp + 30); v_pfx := v_pfx || jsonb_build_object('rallied', true); lines := lines || jsonb_build_array('「기사회생」 숨을 몰아쉬며 다시 섰다. 체력 +30');
    END IF;
    -- 회춘(의술 43 택일): 한 번 체력 20으로 버틴다
    IF ended IS NULL AND hp <= 0 AND 'medicine_c43b' = ANY (sk) AND NOT coalesce((v_pfx ->> 'reborn')::boolean, false) THEN
      hp := 20; v_pfx := v_pfx || jsonb_build_object('reborn', true); lines := lines || jsonb_build_array('「회춘」 끊어지던 숨을 되살려 다시 섰다. 체력 20');
    END IF;
    -- 금강불괴: 한 번 체력 1로 버틴다
    IF ended IS NULL AND hp <= 0 AND 'guarding_c43a' = ANY (sk) AND NOT coalesce((v_pfx ->> 'endured')::boolean, false) THEN
      hp := 1; v_pfx := v_pfx || jsonb_build_object('endured', true); lines := lines || jsonb_build_array('「금강불괴」 쓰러질 일격을 버텨 냈다. 체력 1');
    END IF;
    IF ended IS NULL AND hp <= 0 THEN
      IF coalesce((inv ->> 'revival_charm')::int, 0) > 0 AND NOT coalesce((v_pfx ->> 'revived')::boolean, false) THEN
        inv := public.world_inv_add(inv, 'revival_charm', -1); hp := 30; v_pfx := v_pfx || jsonb_build_object('revived', true);
        lines := lines || jsonb_build_array('쓰러지는 순간 회생 부적이 타올라 다시 일어섰다.');
      ELSE
        ended := 'defeat';
      END IF;
    END IF;
    IF ended IS NULL THEN
      next_intent := coalesce(next_intent, public.world_battle_intent_k(m.kind, a.mlevel, m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank));
    END IF;
    -- 도발: 방어한 턴에 적이 다음에 쓰려던 기믹을 버리고 나에게 달려든다
    IF ended IS NULL AND guarding AND 'melee_c43b' = ANY (sk) THEN
      v_pfx := v_pfx || jsonb_build_object('roar', 2); lines := lines || jsonb_build_array('「사자후」 포효가 울려 ' || m.monster_name || '의 시선이 내게 묶였다.');
    END IF;
    IF ended IS NULL AND coalesce((v_pfx ->> 'roar')::int, 0) > 0 AND next_intent LIKE 'g%:%' THEN next_intent := 'strike'; END IF;
    IF ended IS NULL AND NOT guarding AND coalesce((v_pfx ->> 'roar')::int, 0) > 0 THEN
      v_pfx := v_pfx || jsonb_build_object('roar', (v_pfx ->> 'roar')::int - 1); IF (v_pfx ->> 'roar')::int <= 0 THEN v_pfx := v_pfx - 'roar'; END IF;
    END IF;
    IF ended IS NULL AND guarding AND 'melee_c24b' = ANY (sk) AND next_intent LIKE 'g%:%' THEN
      next_intent := 'strike'; lines := lines || jsonb_build_array('「도발」 ' || m.monster_name || '이(가) 준비하던 수를 버리고 달려든다.');
    END IF;
  END IF;

  FOREACH k IN ARRAY statuses LOOP PERFORM public.world_field_status(uid, k, 'combat'); END LOOP;

  IF ended = 'victory' THEN
    rk_mul := CASE a.rank WHEN 'elite' THEN 1.8 WHEN 'guardian' THEN 3 ELSE 1 END;
    rare := public.world_status_effect_total('rare_loot_pct') + public.world_title_bonus('rare_loot_pct');
    xp := round((6 + a.mlevel * 3) * rk_mul * public.world_xp_gap_mul(a.mlevel - c.level)
      * (1 + 0.1 * least(3, greatest(0, coalesce(nullif(current_setting('yh.pf_n', true), '')::int, 1) - 1))));
    gil_gain := round((2 + a.mlevel) * rk_mul);
    drop_p := least(1, (CASE a.rank WHEN 'elite' THEN 0.8 WHEN 'guardian' THEN 1 ELSE 0.6 END) * (1 + (rare + CASE WHEN coalesce((c.skill_progress -> 'analysis' ->> 'rank')::int, 0) >= 8 THEN 5 ELSE 0 END) / 100.0));
    FOR k, v IN SELECT d.key, CASE WHEN jsonb_typeof(d.value) = 'number' THEN d.value::text::int ELSE 1 END FROM jsonb_each(coalesce(m.drops, '{}'::jsonb)) d LOOP
      IF EXISTS (SELECT 1 FROM public.world_item_catalog ic WHERE ic.item_id = k) AND random() < drop_p THEN
        qty := greatest(1, 1 + floor(random() * greatest(1, v))::int) * (CASE WHEN a.rank = 'guardian' THEN 2 ELSE 1 END);
        loot := public.world_inv_add(loot, k, qty);
      END IF;
    END LOOP;
    IF random() < 0.25 + rare / 100.0 THEN
      SELECT x INTO sig FROM public.world_region_profiles p, unnest(p.signature_items) x JOIN public.world_item_catalog ic ON ic.item_id = x
        WHERE p.region_id = a.region_id AND ic.tier <= 2 AND x NOT IN ('courier_token', 'spirit_compass') ORDER BY random() LIMIT 1;
      IF sig IS NOT NULL THEN loot := public.world_inv_add(loot, sig, 1); END IF;
    END IF;
    IF a.rank <> 'normal' AND random() < (CASE a.rank WHEN 'guardian' THEN 1 ELSE 0.3 END) THEN loot := public.world_inv_add(loot, 'monster_core', 1); END IF; sig := public.world_gear_roll(m.mechanic_key, a.mlevel, a.rank, rare); IF sig IS NOT NULL THEN loot := public.world_inv_add(loot, sig, 1); lines := lines || jsonb_build_array('장비를 얻었다: ' || (SELECT item_name FROM public.world_item_catalog WHERE item_id = sig)); END IF;
    IF loot = '{}'::jsonb THEN loot := public.world_inv_add(loot, CASE WHEN random() < 0.5 THEN 'spirit_dust' ELSE 'beast_bone' END, 1); END IF;
    FOR k, v IN SELECT key, value::text::int FROM jsonb_each(loot) LOOP inv := public.world_inv_add(inv, k, v); END LOOP;
    lines := lines || jsonb_build_array(m.monster_name || '을(를) 쓰러뜨렸다.');
    v_result := jsonb_build_object('outcome', 'victory', 'monster', m.monster_name, 'rank', a.rank, 'level', a.mlevel, 'xp', xp + 24, 'gil', gil_gain, 'loot', loot);
  ELSIF ended = 'defeat' THEN
    hp := 0;
    lines := lines || jsonb_build_array('정신이 아득해진다… 쓰러졌다.');
    v_result := jsonb_build_object('outcome', 'defeat', 'monster', m.monster_name);
  ELSIF ended = 'fled' THEN
    v_result := jsonb_build_object('outcome', 'fled', 'monster', m.monster_name);
  END IF;

  IF EXISTS (SELECT 1 FROM unnest(sk) x WHERE x ~ '^(dagger|exorcism|medicine|combo_dagger)_') THEN lines := public.world_skill_alias_lines(uid, lines); END IF;
  UPDATE public.world_characters SET health = hp, mental = mn, spiritual_power = sp, erosion = er,
    erosion_stage = CASE WHEN er >= 80 THEN 4 WHEN er >= 55 THEN 3 WHEN er >= 30 THEN 2 WHEN er >= 10 THEN 1 ELSE 0 END,
    inventory = inv, gil = gil + gil_gain, experience = experience + greatest(0, xp), updated_at = now()
  WHERE owner_id = uid;

  UPDATE public.world_active_encounters SET current_hp = a.current_hp, turn_count = turn, fx = v_fx, pfx = v_pfx,
    intent = CASE WHEN ended IS NULL THEN next_intent ELSE v_intent END,
    defeated = coalesce(ended = 'victory', false), fled = coalesce(ended IN ('fled', 'defeat'), false), result = v_result,
    log = (SELECT coalesce(jsonb_agg(x ORDER BY o), '[]'::jsonb) FROM (SELECT x, o FROM jsonb_array_elements(a.log || lines) WITH ORDINALITY t(x, o) ORDER BY o DESC LIMIT 14) s),
    last_action_at = now(), updated_at = now()
  WHERE owner_id = uid;

  IF ended = 'victory' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'combat', m.monster_name || ' 토벌' || CASE a.rank WHEN 'elite' THEN '(정예)' WHEN 'guardian' THEN '(우두머리)' ELSE '' END,
      jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id, 'monster_name', m.monster_name, 'defeated', true,
        'mechanic', m.mechanic_key, 'action', CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'seal' ELSE 'attack' END, 'line', public.world_job_line(c.job_key),
        'rank', a.rank, 'level', a.mlevel, 'loot', loot, 'turns', turn,
        'acts', jsonb_build_object('analysis', coalesce((v_pfx ->> 'u_an')::int, 0), 'guarding', coalesce((v_pfx ->> 'u_gd')::int, 0), 'first_aid', coalesce((v_pfx ->> 'u_fa')::int, 0))));
  ELSIF ended = 'defeat' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'battle_lost', m.monster_name || '에게 쓰러졌습니다.', jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id));
  ELSIF ended = 'fled' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'battle_fled', m.monster_name || CASE WHEN sneak_ok THEN '을(를) 기척을 숨겨 피했습니다.' ELSE '에게서 달아났습니다.' END, jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id, 'sneak', sneak_ok));
  END IF;

  RETURN jsonb_build_object('ok', true, 'lines', lines, 'ended', ended, 'result', v_result, 'damage', dmg + ex_total, 'taken', mdmg, 'heal', heal,
    'crit', crit, 'weak', v_weak, 'health', hp, 'battle', public.world_field_battle_view(uid), 'next_action_at', now() + interval '1 second',
    'me', (select jsonb_build_object('health', x.health, 'mental', x.mental, 'spiritual_power', x.spiritual_power, 'erosion', x.erosion,
      'inventory', x.inventory, 'downed_at', x.downed_at, 'updated_at', x.updated_at) from public.world_characters x where x.owner_id = uid));
END $function$;

CREATE OR REPLACE FUNCTION public.world_guard_action_context()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  c public.world_characters%rowtype; r public.world_map_regions%rowtype; m public.world_mount_catalog%rowtype;
  k text := coalesce(new.event_type, ''); p jsonb := coalesce(new.payload, '{}'::jsonb);
  away boolean; passenger uuid; idling boolean; cd_s text;
BEGIN
  IF new.actor_id IS NULL THEN RETURN new; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = new.actor_id;
  IF NOT FOUND THEN RETURN new; END IF;
  r := public.world_region_at(c.location);
  away := EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = new.actor_id AND e.status = 'active');
        idling := EXISTS (SELECT 1 FROM public.world_idle_activities i WHERE i.owner_id = new.actor_id AND i.status = 'active');
  IF k = 'travel' AND p ? 'passenger_id' THEN
    passenger := nullif(p ->> 'passenger_id', '')::uuid;
    IF EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = passenger AND e.status = 'active') THEN
      RAISE EXCEPTION '동승자가 원정 중이라 함께 출발할 수 없습니다.';
    END IF;
  END IF;
  IF k = 'travel' AND p ? 'passenger_id'
        AND EXISTS (SELECT 1 FROM public.world_idle_activities i WHERE i.owner_id = nullif(p ->> 'passenger_id', '')::uuid AND i.status = 'active') THEN
        RAISE EXCEPTION '동승자가 자율 활동 중이라 함께 출발할 수 없습니다.';
        END IF;
        IF idling AND NOT (
        k IN ('progression', 'mission', 'supply', 'case_combine', 'case_resolved', 'story', 'loot', 'use_item', 'equip', 'unequip')
        OR (k = 'trade' AND NOT (p ? 'unit_price') AND NOT (p ? 'gil'))
        OR (k = 'travel' AND p ? 'travel_history_id')) THEN
        RAISE EXCEPTION '자율 활동 중에는 할 수 없습니다. 활동이 끝나 보상을 받은 뒤 다시 시도하세요.';
        END IF;
        IF away AND NOT (
       k IN ('progression', 'mission', 'supply', 'case_combine', 'case_resolved', 'loot', 'downed')
    OR k LIKE 'expedition%'
    OR (k = 'trade' AND NOT (p ? 'unit_price') AND NOT (p ? 'gil'))
    OR (k = 'travel' AND p ? 'travel_history_id')) THEN
    RAISE EXCEPTION '원정 중에는 할 수 없습니다. 원정을 마치거나 귀환한 뒤 다시 시도하세요.';
  END IF;
  IF (k IN ('explore', 'gather', 'fish', 'combat', 'encounter', 'expedition_start') OR (k = 'travel' AND NOT (p ? 'travel_history_id')))
     AND EXISTS (SELECT 1 FROM public.world_overflow_items o WHERE o.owner_id = new.actor_id) THEN
    RAISE EXCEPTION '원정 짐 보따리를 먼저 정리하세요. 챙기거나 버린 뒤 다시 할 수 있습니다.';
  END IF;
  IF k <> 'progression' AND EXISTS (SELECT 1 FROM public.world_character_statuses ys WHERE ys.owner_id = new.actor_id AND ys.status_key = 'yohwa_seal' AND ys.expires_at > now()) THEN
        RAISE EXCEPTION '봉인 해독 중에는 채팅 말고는 할 수 없습니다. 해독이 끝나면 다시 움직일 수 있습니다.';
        END IF;
        IF k = 'travel' AND NOT (p ? 'travel_history_id') THEN
    PERFORM 1 FROM public.world_travel_history h WHERE h.owner_id = new.actor_id AND h.cancelled_at > now() - interval '3 minutes';
    IF FOUND THEN
      cd_s := ceil(extract(epoch FROM (SELECT max(h.cancelled_at) FROM public.world_travel_history h WHERE h.owner_id = new.actor_id) + interval '3 minutes' - now()))::text;
      RAISE EXCEPTION USING MESSAGE = format('이동을 취소한 뒤 3분 동안은 다시 출발할 수 없습니다(%s초 남음).', cd_s), HINT = 'cd:' || cd_s;
    END IF;
  END IF;
  -- 이동 중에는 제작·분해·강화·수리·상점·거래소를 할 수 없다(7.3.6)
  IF (k IN ('craft', 'dismantle', 'enhance', 'repair', 'shop_buy', 'shop_sell') OR (k = 'trade' AND (p ? 'unit_price' OR p ? 'gil')))
     AND EXISTS (SELECT 1 FROM public.world_characters wc WHERE wc.owner_id = new.actor_id AND wc.travel_arrives_at IS NOT NULL) THEN
    RAISE EXCEPTION '이동 중에는 할 수 없습니다. 도착한 뒤 다시 시도하세요.';
  END IF;
  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN ('encounter', 'combat') THEN
    RAISE EXCEPTION '안전지대에서는 요괴 수색과 전투를 할 수 없습니다.';
  END IF;
  IF k IN ('shop_buy', 'shop_sell') AND (r.region_id IS NULL OR NOT r.is_safe_zone OR r.shop_id IS NULL) THEN
    RAISE EXCEPTION '상점은 안전지대에만 있습니다.';
  END IF;
  IF k = 'trade' AND p ? 'unit_price' AND r.region_id = 'banyo_village' THEN
    RAISE EXCEPTION '반요촌에는 거래소가 없습니다.';
  END IF;
  IF k = 'trade' AND (p ? 'unit_price' OR (p ? 'gil' AND NOT (p ? 'trade_id'))) AND (r.region_id IS NULL OR NOT r.is_safe_zone) THEN
    RAISE EXCEPTION '거래소는 안전지대에서만 이용할 수 있습니다.';
  END IF;
  IF k = 'mount' AND p ? 'price' THEN
    SELECT * INTO m FROM public.world_mount_catalog WHERE mount_id = p ->> 'mount_id';
    IF m.acquire_method = 'event' THEN RAISE EXCEPTION '이 탈것은 특별한 사건으로만 얻을 수 있습니다.'; END IF;
    IF r.region_id IS NULL OR NOT r.has_stable THEN RAISE EXCEPTION '탈것은 안전지대의 마구간에서만 구할 수 있습니다.'; END IF;
  END IF;
  RETURN new;
END
$function$;

CREATE OR REPLACE FUNCTION public.world_pfight_resolve(p_fight uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      perform set_config('yh.pf_hb', coalesce((select health from public.world_characters where owner_id = mm.owner_id), 0)::text, true);
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
        update public.world_pfight_members pm set weak = r ->> 'weak', dmg = pm.dmg + greatest(0, before - f.hp),
        taken = pm.taken + greatest(0, coalesce(nullif(current_setting('yh.pf_hb', true), '')::int, c.health) - c.health),
        heal = pm.heal + greatest(0, c.health - coalesce(nullif(current_setting('yh.pf_hb', true), '')::int, c.health))
        from public.world_characters c where c.owner_id = mm.owner_id and pm.fight_id = p_fight and pm.owner_id = mm.owner_id;
        if r ->> 'ended' = 'victory' then won := true;
        update public.world_pfight_members set out_reason = 'won' where fight_id = p_fight and owner_id = mm.owner_id;
        elsif r ->> 'ended' = 'defeat' then update public.world_pfight_members set out_reason = 'down' where fight_id = p_fight and owner_id = mm.owner_id;
        elsif r ->> 'ended' = 'fled' then update public.world_pfight_members set out_reason = 'fled' where fight_id = p_fight and owner_id = mm.owner_id;
        end if;
        end if;
      end if;
      update public.world_pfight_members set action = null, item = null where fight_id = p_fight and owner_id = mm.owner_id;
    end if;
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
  update public.world_pfights set log = (select coalesce(jsonb_agg(x order by o), '[]'::jsonb) from (select x, o from jsonb_array_elements(log) with ordinality t(x, o) order by o desc limit 60) s)
   where fight_id = p_fight and jsonb_array_length(log) > 60;
end $function$;

CREATE OR REPLACE FUNCTION public.world_pfight_snapshot(p_fight uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
        'health', c.health, 'mental', c.mental, 'sp', c.spiritual_power, 'job', c.job_key, 'dmg', pm.dmg, 'taken', pm.taken, 'heal', pm.heal, 'weak', pm.weak, 'share', coalesce((public.world_pfight_shares(p_fight) ->> pm.owner_id::text)::numeric, 0)) order by pm.joined_at), '[]'::jsonb)
      from public.world_pfight_members pm join public.world_characters c on c.owner_id = pm.owner_id where pm.fight_id = p_fight));
end $function$;

CREATE OR REPLACE FUNCTION public.world_raid_snapshot_core(p_raid uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rd public.world_raids%rowtype; rid uuid := p_raid; me public.world_raid_members%rowtype;
  here text; mem jsonb; logs jsonb; tot numeric; ck numeric; can_join boolean := false; why text; coop jsonb := '[]'::jsonb; reveal_region boolean; reveal_c boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if exists (select 1 from public.world_raids where status in ('announced', 'signup', 'fight')
        and ((status = 'announced' and spawn_at <= now()) or (status = 'signup' and signup_until <= now()) or (status = 'fight' and ends_at <= now()))) then
    perform public.world_raid_tick();
  end if;
  if rid is null then
    select x.raid_id into rid from public.world_raid_members m join public.world_raids x on x.raid_id = m.raid_id
     where m.owner_id = uid and x.status in ('signup', 'fight') order by x.created_at desc limit 1;
  end if;
  if rid is null then
    select raid_id into rid from public.world_raids where kind = 'world' and status in ('signup', 'fight') order by created_at desc limit 1;
  end if;
  if rid is null then
    select raid_id into rid from public.world_raids where kind = 'world' order by coalesce(ended_at, spawn_at) desc nulls last limit 1;
  end if;
  select * into rd from public.world_raids where raid_id = rid;
  if not found then return jsonb_build_object('raid', null); end if;
  select * into me from public.world_raid_members where raid_id = rid and owner_id = uid;
  select region_id into here from public.world_map_regions where region_name = c.location;
  reveal_region := rd.status <> 'announced' or '12h' = any (rd.notices);
  reveal_c := rd.status <> 'announced' or '24h' = any (rd.notices);
  if rd.status = 'announced' and not reveal_c then return jsonb_build_object('raid', null); end if;
  ck := public.world_raid_k(rid);
  select coalesce(sum(public.world_raid_score(rd.kind, level, credits, stats, contrib, ck)), 0) into tot from public.world_raid_members where raid_id = rid;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.owner_id, 'name', x.name, 'level', x.level, 'job', x.job_key, 'hp', ch.health, 'sp', ch.spiritual_power,
      'out', case when x.left_at is null and x.out_until > now() then ceil(extract(epoch from x.out_until - now())) end, 'resting', x.left_at is null and x.out_until is not null and x.out_until <= now(), 'left', x.left_at is not null, 'dmg', x.dmg, 'heal', x.heal, 'taken', x.taken, 'coop', x.coop, 'acts', x.acts,
      'share', case when tot > 0 then round(public.world_raid_score(rd.kind, x.level, x.credits, x.stats, x.contrib, ck) / tot * 100, 1) else 0 end, 'credits', coalesce(x.credits, '{}'::jsonb), 'me', x.owner_id = uid, 'away', rd.status = 'fight' and not public.world_raid_here(x.owner_id, rd.region_id),
      'buffs', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(x.fx) k), 'reward', case when x.owner_id = uid then x.reward end)
      order by x.contrib desc, x.joined_at), '[]'::jsonb)
    into mem from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id where x.raid_id = rid;
  select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'at', l.at, 'kind', l.kind, 'text', l.text, 'who', l.who, 'n', l.n) order by l.id), '[]'::jsonb) into logs
    from (select * from public.world_raid_log where raid_id = rid order by id desc limit 40) l;
  if me.owner_id is null and (rd.status = 'signup' or (rd.kind = 'world' and rd.status = 'fight')) then
    if rd.status = 'signup' and rd.signup_until <= now() then why := '신청 시간이 지났습니다.';
    elsif rd.status = 'fight' and rd.ends_at <= now() then why := '토벌이 끝났습니다.';
    elsif c.health <= 0 or c.downed_at is not null then why := '전투불능 상태에서는 합류할 수 없습니다.';
    elsif here is distinct from rd.region_id then why := (select region_name from public.world_map_regions where region_id = rd.region_id) || case when rd.status = 'fight' then '에 가면 토벌에 합류할 수 있습니다.' else '에 있어야 신청할 수 있습니다.' end;
    elsif rd.kind = 'final' and not exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id where a.owner_id = uid and b.owner_id = rd.leader_id) then why := '시작한 조사원의 파티원만 합류할 수 있습니다.';
    else can_join := true; end if;
  end if;
  if me.owner_id is not null then
    select coalesce(jsonb_agg(jsonb_build_object('id', s.skill_id, 'name', s.skill_name, 'desc', s.description, 'target', s.target, 'cost', s.cost, 'rank', s.unlock_rank,
        'unlocked', coalesce(c.combat_rank, 1) >= s.unlock_rank, 'type', s.effect ->> 'type',
        'cd', case when me.cd ? s.skill_id and (me.cd ->> s.skill_id)::timestamptz > now() then ceil(extract(epoch from (me.cd ->> s.skill_id)::timestamptz - now())) else 0 end) order by s.sort), '[]'::jsonb)
      into coop from public.world_coop_skills s where s.job_key = c.job_key;
  end if;
  return jsonb_build_object('raid', jsonb_build_object('id', rd.raid_id, 'kind', rd.kind, 'boss', rd.boss_name, 'status', rd.status,
      'region_id', case when reveal_region then rd.region_id end, 'region', case when reveal_region then (select region_name from public.world_map_regions where region_id = rd.region_id) end,
      'candidates', case when reveal_c and not reveal_region then (select jsonb_agg(x.region_name) from unnest(rd.candidates) cc join public.world_map_regions x on x.region_id = cc) end,
      'spawn_at', case when reveal_region then rd.spawn_at end, 'signup_until', rd.signup_until, 'ends_at', rd.ends_at, 'ended_at', rd.ended_at,
      'hp', rd.hp, 'max_hp', rd.max_hp, 'phase', rd.phase, 'intent', rd.intent, 'leader', rd.leader_id = uid,
      'charge', case when rd.fx ? 'charge' then (rd.fx -> 'charge') || jsonb_build_object('secs', case when (rd.fx -> 'charge' ->> 'until') is not null then greatest(0, round((rd.fx -> 'charge' ->> 'until')::numeric - extract(epoch from now())::numeric, 1)) end, 'dur', 8) end, 'boss_fx', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(rd.fx) k where k <> 'charge')),
    'members', mem, 'log', logs,
    'me', jsonb_build_object('joined', me.owner_id is not null, 'can_join', can_join, 'why', why, 'here', here = rd.region_id, 'away', me.owner_id is not null and rd.status = 'fight' and not public.world_raid_here(uid, rd.region_id),
      'hp', c.health, 'sp', c.spiritual_power, 'out', case when me.left_at is null and me.out_until > now() then ceil(extract(epoch from me.out_until - now())) end, 'resting', me.left_at is null and me.out_until is not null and me.out_until <= now(), 'left', me.left_at is not null,
      'items_left', case when rd.kind = 'final' and me.owner_id is not null then greatest(0, 5 - me.items_used) end,
      'solo', case when rd.kind = 'final' and me.owner_id is not null and (select count(*) from public.world_raid_members x where x.raid_id = rd.raid_id) = 1 then public.world_solo_aid(me.job_key) end,
      'fx', me.fx, 'coop', coop, 'job', c.job_key, 'combat_rank', coalesce(c.combat_rank, 1)),
    'locks', (select coalesce(jsonb_agg(jsonb_build_object('region_id', l.region_id, 'region', x.region_name, 'until', l.until)), '[]'::jsonb)
        from public.world_raid_locks l join public.world_map_regions x on x.region_id = l.region_id where l.until > now()));
end $function$;

CREATE OR REPLACE FUNCTION public.world_raid_action(p_raid uuid, p_action text, p_skill text DEFAULT NULL::text, p_target uuid DEFAULT NULL::uuid, p_item text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rd public.world_raids%rowtype; mb public.world_raid_members%rowtype;
  tm public.world_raid_members%rowtype; sk public.world_coop_skills%rowtype; st jsonb; f jsonb; rfx jsonb; act text := lower(coalesce(p_action, ''));
  here text; sp int; inv jsonb; ammo text; mul numeric := 1; dmg int := 0; crit boolean := false; credit numeric := 0; h0 int; h1 int; amt int;
  n_act int; pick uuid; lv int; raw numeric; ph_mul numeric; k text; v jsonb; tgt uuid; nm text; newp int; tot numeric; acc numeric; rnd numeric; m record;
  bm text; bp numeric := 0; be text; bep numeric := 0; bc text; bcp numeric := 0; bcn text; ex numeric;
  bt int; tick boolean := true; bnow numeric; cbr jsonb; cbc jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if act not in ('attack', 'guard', 'item', 'coop') then raise exception '알 수 없는 행동입니다.'; end if;
  -- 7.7.7m: 내 1초 간격을 토벌 행(모두가 함께 씀)을 잠그기 전에 — 연타가 다른 참가자의 행동을 줄 세우지 않게
  perform public.world_rate_check('raid', uid, p_raid);
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if not found then raise exception '알 수 없는 토벌입니다.'; end if;
  if rd.status <> 'fight' then raise exception '지금은 싸울 수 없습니다.'; end if;
  if rd.ends_at <= now() then perform public.world_raid_settle(p_raid, false); return public.world_raid_snapshot(p_raid); end if;
  select * into mb from public.world_raid_members where raid_id = p_raid and owner_id = uid for update;
  if not found then raise exception '참가 신청한 조사원만 싸울 수 있습니다. 진행은 관전으로 볼 수 있습니다.'; end if;
  if mb.last_action_at is not null and mb.last_action_at > now() - interval '1 second' then raise exception '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.'; end if;
  if mb.left_at is not null then raise exception '토벌에서 나왔습니다. 「다시 참가」하면 이어서 싸울 수 있습니다.'; end if;
  if mb.out_until is not null and mb.out_until > now() then
    raise exception '물러나 숨을 고르는 중입니다(%초 뒤 돌아옴).', ceil(extract(epoch from mb.out_until - now())); end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태입니다.'; end if;
  select region_id into here from public.world_map_regions where region_name = c.location;
  if here is distinct from rd.region_id then raise exception '토벌이 벌어진 곳에 있어야 합니다.'; end if;
  if exists (select 1 from public.world_expeditions where owner_id = uid and status = 'active') then raise exception '원정 중에는 싸울 수 없습니다.'; end if;
  -- 토벌 보강 6.1.1
  if c.travel_destination is not null then raise exception '이동 중에는 싸울 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities where owner_id = uid and status = 'active') then raise exception '자율 활동 중에는 싸울 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false) and a.mlevel is not null) then
    raise exception '진행 중인 요괴 전투를 먼저 끝내세요.'; end if;

  st := public.world_raid_stats(uid);
  f := mb.fx; rfx := rd.fx; sp := c.spiritual_power; inv := coalesce(c.inventory, '{}'::jsonb);
  if mb.out_until is not null then mb.out_until := null;
    -- 결전: 쉬다가 돌아오면 체력 30(귀허와 같게 — 회복품이 셋뿐이라 체력 1로 돌아오면 곧바로 다시 쓰러진다)
    if rd.kind = 'final' and c.health < 30 then c.health := 30; update public.world_characters set health = 30, updated_at = now() where owner_id = uid; end if;
  end if;

  if act = 'attack' then
    -- 무기 소모: 근접 기력 2·술법 영력 3·원거리 한 발, 없으면 피해 절반
    if st ->> 'style' = 'magic' then if sp >= 2 then sp := sp - 2; else mul := mul * 0.5; end if;
    elsif st ->> 'style' = 'ranged' then
      ammo := public.world_ammo_of(uid);
      if ammo is not null and coalesce((inv ->> ammo)::int, 0) >= 1 then inv := public.world_inv_add(inv, ammo, -1); if (inv ->> ammo)::int <= 0 then inv := inv - ammo; end if;
      else mul := mul * 0.5; end if;
    else if sp >= 2 then sp := sp - 2; else mul := mul * 0.5; end if; end if;
    cbr := public.world_cb_attack(st, f, rfx, 0.85, 0.3);
    f := cbr -> 'fx'; rfx := cbr -> 'bfx'; crit := (cbr ->> 'crit')::boolean;
    if rd.kind = 'final' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then
      mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_dmg')::numeric, (public.world_solo_aid(c.job_key) ->> 'solo_dmg')::numeric, 0) / 100.0);
    elsif rd.kind = 'final' then mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_all')::numeric, 0) / 100.0); end if;
    dmg := greatest(1, round((cbr ->> 'd')::numeric * mul))::int;
    rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - dmg); mb.dmg := mb.dmg + dmg; credit := 0;
    -- 늘려 준 몫은 건 사람에게(공용 world_cb_boost_credits), 남은 몫이 내 기여
    for cbc in select * from jsonb_array_elements(public.world_cb_boost_credits(dmg, crit, cbr -> 'src', uid, (st ->> 'crit')::numeric)) loop
      if cbc ->> 2 = 'dmg' then credit := (cbc ->> 1)::numeric; else perform public.world_raid_credit(p_raid, (cbc ->> 0)::uuid, (cbc ->> 1)::numeric, 'boost'); end if;
    end loop;
    if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,got}', to_jsonb((rfx -> 'charge' ->> 'got')::int + dmg)); end if;
    perform public.world_raid_say_n(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.', mb.name, dmg);
  elsif act = 'guard' then
    f := f || jsonb_build_object('guard', 1); mb.guarded := mb.guarded + 1;
    perform public.world_raid_say(p_raid, 'guard', mb.name || ' — 방어 태세를 갖췄습니다.');
  elsif act = 'item' then
    -- 물품은 평소 쓰는 길(world_use_item)을 그대로 거친다
    update public.world_characters set spiritual_power = sp where owner_id = uid;
    h0 := c.health;
    perform set_config('yh.raid_item', '1', true);
    perform public.world_use_item(p_item);
    perform set_config('yh.raid_item', '', true);
    select * into c from public.world_characters where owner_id = uid;
    sp := c.spiritual_power; inv := coalesce(c.inventory, '{}'::jsonb); h1 := c.health;
    if rd.kind = 'final' and h1 > h0 then
      if mb.items_used >= 5 then raise exception '결전에서는 체력 회복품을 한 싸움에 다섯 개까지만 쓸 수 있습니다.'; end if;
      mb.items_used := mb.items_used + 1;
    end if;
    mb.heal := mb.heal + greatest(0, h1 - h0); credit := greatest(0, h1 - h0);
    perform public.world_raid_say(p_raid, 'item', mb.name || ' — ' || coalesce((select item_name from public.world_item_catalog where item_id = p_item), '물품') || '을(를) 썼습니다' || case when h1 > h0 then '(체력 +' || (h1 - h0) || ')' else '' end || '.');
  else
    select * into sk from public.world_coop_skills where skill_id = p_skill;
    if not found or sk.job_key <> c.job_key then raise exception '쓸 수 없는 협동 기술입니다.'; end if;
    if coalesce(c.combat_rank, 1) < sk.unlock_rank then raise exception '전투 숙련 %단계에 열리는 기술입니다.', sk.unlock_rank; end if;
    if mb.cd ? sk.skill_id and (mb.cd ->> sk.skill_id)::timestamptz > now() then
      raise exception '%은(는) %초 뒤에 다시 쓸 수 있습니다.', sk.skill_name, ceil(extract(epoch from (mb.cd ->> sk.skill_id)::timestamptz - now())); end if;
    if sp < sk.cost then raise exception '영력이 모자랍니다(필요 %).', sk.cost; end if;
    tgt := case when sk.target = 'self' then uid else coalesce(p_target, uid) end;
    if sk.target = 'ally' then
      select * into tm from public.world_raid_members where raid_id = p_raid and owner_id = tgt for update;
      if not found then raise exception '이 토벌에 참가한 동료에게만 쓸 수 있습니다.'; end if;
      if sk.effect ->> 'type' = 'revive' then
        if tm.out_until is null then raise exception '물러난 동료에게만 쓸 수 있습니다.'; end if;
        if tm.left_at is not null then raise exception '토벌에서 나간 동료입니다.'; end if;
      elsif tm.out_until is not null and tm.out_until > now() then raise exception '물러난 동료에게는 쓸 수 없습니다.'; end if;
    end if;
    sp := sp - sk.cost;
    mb.cd := mb.cd || jsonb_build_object(sk.skill_id, now() + make_interval(secs => sk.cooldown_s));
    mb.coop := mb.coop + 1; credit := 0;
    k := sk.effect ->> 'type'; v := sk.effect;
    -- 자신에게 거는 효과는 아래에서 mb.fx(f)에 바로 쓴다
    if sk.target in ('ally', 'self') and tgt = uid then
      if k in ('ward', 'might', 'evade', 'gward', 'crit_next') then f := f || public.world_cb_buff(k, v, uid);
      elsif k = 'shield' then f := f || jsonb_build_object('shield', coalesce((f ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid);
      elsif k = 'cleanse_heal' then f := f - 'bound';
      elsif k = 'cover' then raise exception '자기 자신은 대신 막을 수 없습니다.';
      end if;
    elsif sk.target = 'ally' then
      update public.world_raid_members set fx = case
        when k in ('ward', 'might', 'evade', 'gward', 'crit_next') then fx || public.world_cb_buff(k, v, uid)
        when k = 'shield' then fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid)
        when k = 'cleanse_heal' then fx - 'bound'
        when k = 'cover' then fx || jsonb_build_object('cover', jsonb_build_object('by', uid, 'until', now() + make_interval(secs => (v ->> 'secs')::int)))
        else fx end,
        out_until = case when k = 'revive' then least(out_until, now()) else out_until end
       where raid_id = p_raid and owner_id = tgt;
    end if;
    if k in ('heal', 'cleanse_heal', 'revive', 'sp', 'gward') then
      amt := case k when 'revive' then (v ->> 'hp')::int when 'sp' then 0 when 'gward' then 0
        else round((v ->> 'amt')::int * (1 + coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) / 100.0)) end;
      -- 결전: 회복 기술은 절반(회복품을 다섯으로 묶어 회복 기술이 승패를 혼자 정하던 것 — 회복 직업 없는 조가 해볼 만하게)
      if rd.kind = 'final' and k in ('heal', 'cleanse_heal') then amt := ceil(amt * 0.5); end if;
      if k = 'revive' then
        select health into h1 from public.world_characters where owner_id = tgt;
        update public.world_characters set health = greatest(health, amt), updated_at = now() where owner_id = tgt;
        amt := greatest(0, amt - coalesce(h1, 0));
      elsif k = 'sp' then
        if tgt <> uid then perform public.world_raid_credit(p_raid, uid, (select greatest(0, least((v ->> 'amt')::int, 100 - x.spiritual_power)) from public.world_characters x where x.owner_id = tgt) * coalesce((st ->> 'attack')::numeric, 0) * 0.05, 'boost'); end if;
        update public.world_characters set spiritual_power = least(100, spiritual_power + (v ->> 'amt')::int), updated_at = now() where owner_id = tgt and owner_id <> uid;
        if tgt = uid then sp := least(100, sp + (v ->> 'amt')::int); end if;
      elsif k = 'gward' then
        update public.world_characters set mental = least(100, mental + coalesce((v ->> 'mind')::int, 0)), updated_at = now() where owner_id = tgt;
      else
        if tgt = uid then
        select health into h0 from public.world_characters where owner_id = uid;
        end if;
        select health into h1 from public.world_characters where owner_id = tgt;
        update public.world_characters set health = least(100, health + amt), updated_at = now() where owner_id = tgt and health > 0;
        amt := case when coalesce(h1, 0) > 0 then greatest(0, least(100, h1 + amt) - h1) else 0 end;
      end if;
      if amt > 0 then mb.heal := mb.heal + amt; perform public.world_raid_credit(p_raid, uid, amt, case when tgt = uid then 'heal_self' else 'heal' end); end if;
    end if;
    if k = 'heal_all' then
      amt := round((v ->> 'amt')::int * (1 + coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) / 100.0));
      if rd.kind = 'final' then amt := ceil(amt * 0.5); end if; -- heal_all final half
      select sum(greatest(0, least(100, ch.health + amt) - ch.health)) into acc from public.world_characters ch join public.world_raid_members x on x.owner_id = ch.owner_id
       where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and ch.health > 0;
      update public.world_characters ch set health = least(100, ch.health + amt), updated_at = now()
        from public.world_raid_members x where x.raid_id = p_raid and x.owner_id = ch.owner_id and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and ch.health > 0;
      get diagnostics n_act = row_count;
      mb.heal := mb.heal + coalesce(acc, 0)::int; perform public.world_raid_credit(p_raid, uid, coalesce(acc, 0), 'heal');
    elsif k in ('ward_all', 'might_all', 'crit_all', 'rally', 'resonance') then
      update public.world_raid_members x set fx = x.fx || public.world_cb_buff(k, v, uid)
       where x.raid_id = p_raid and x.owner_id <> uid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id);
      f := f || public.world_cb_buff(k, v, uid);
    elsif k = 'taunt' then
      f := f || public.world_cb_buff('taunt', v, uid);
    elsif k = 'expose' then
      rfx := rfx || jsonb_build_object('expose', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n', 'by', uid), 'stagger', coalesce((rfx ->> 'stagger')::int, 0) + coalesce((v ->> 'stagger')::int, 0), 'stagger_by', uid);
    elsif k = 'delay' then
      rfx := rfx || jsonb_build_object('stagger', coalesce((rfx ->> 'stagger')::int, 0) + (v ->> 'n')::int, 'stagger_by', uid);
      if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int + 3));
        if (rfx -> 'charge' ->> 'until') is not null then rfx := jsonb_set(rfx, '{charge,until}', to_jsonb((rfx -> 'charge' ->> 'until')::numeric + 6)); end if; end if;
    elsif k = 'smoke' then
      rfx := rfx || jsonb_build_object('smoke', jsonb_build_object('miss', v -> 'miss', 'n', v -> 'n', 'by', uid));
    elsif k = 'break' then
      rfx := rfx || jsonb_build_object('break', v -> 'pct', 'break_by', uid);
    end if;
    select name into nm from public.world_raid_members where raid_id = p_raid and owner_id = tgt;
    perform public.world_raid_say(p_raid, 'coop', mb.name || ' — [' || sk.skill_name || '] ' ||
      case when sk.target = 'ally' and tgt <> uid then nm || '에게 · ' else '' end || sk.exp_text || '.');
  end if;

  -- 내 행동을 먼저 적고(체력·영력·가방), 보스의 반격은 그 뒤에 실제 캐릭터에 쓴다
  update public.world_characters set spiritual_power = sp, inventory = inv, updated_at = now() where owner_id = uid;
  mb.acts := mb.acts + 1; mb.last_action_at := now();
  mb.contrib := mb.contrib + credit * case when rd.kind = 'world' then least(1, mb.level / 30.0) else 1 end;
  update public.world_raid_members set fx = f, cd = mb.cd, dmg = mb.dmg, heal = mb.heal, coop = mb.coop, guarded = mb.guarded, acts = mb.acts,
    contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = case when rd.kind = 'final' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then st || (public.world_solo_aid(c.job_key) - 'solo_guard' - 'final_guard') || jsonb_build_object('solo_guard', coalesce(public.world_solo_aid(c.job_key) -> 'final_guard', '0'::jsonb)) else st end, items_used = mb.items_used where raid_id = p_raid and owner_id = uid;
  perform public.world_raid_credit(p_raid, uid, credit, case act when 'attack' then 'dmg' when 'item' then 'heal_self' end);
  if act = 'coop' then perform public.world_raid_credit(p_raid, uid, 1, 'skill'); end if;

  rd.turn := rd.turn + 1;
  if rd.hp <= 0 then
    update public.world_raids set hp = 0, turn = rd.turn, fx = rfx, updated_at = now() where raid_id = p_raid;
    perform public.world_raid_say(p_raid, 'win', mb.name || '의 일격에 ' || rd.boss_name || '이(가) 무너졌습니다.');
    perform public.world_raid_settle(p_raid, true);
    return public.world_raid_snapshot(p_raid);
  end if;
  newp := case when rd.hp * 100 <= rd.max_hp * 40 then 3 when rd.hp * 100 <= rd.max_hp * 70 then 2 else 1 end;
  if newp > rd.phase then
    rd.phase := newp;
    perform public.world_raid_say(p_raid, 'phase', case newp when 2 then rd.boss_name || '의 사슬이 풀리며 움직임이 사나워집니다(2단계).'
        else rd.boss_name || '이(가) 봉연의 기운을 끌어모으기 시작합니다(3단계).' end);
  end if;
  ph_mul := case rd.phase when 1 then 1 when 2 then 1.15 else 1.3 end * case when rd.kind = 'final' then 1.1 else 1 end;
  select count(*) into n_act from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id
   where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' and ch.health > 1;

  -- 7.7.6: 서버 보스는 큰 수법을 2초 박자로 센다(결전은 차례 그대로)
  if rd.kind = 'world' then
    bnow := extract(epoch from now()); tick := false;
    if not (rfx ? 'beat_at') then rfx := rfx || jsonb_build_object('beat', 0, 'beat_at', bnow);
    elsif bnow >= (rfx ->> 'beat_at')::numeric + 2 then
      rfx := rfx || jsonb_build_object('beat', (rfx ->> 'beat')::int + 1, 'beat_at', bnow); tick := true;
    end if;
    bt := (rfx ->> 'beat')::int;
  else bt := rd.turn; end if;

  if coalesce((rfx ->> 'stagger')::int, 0) > 0 then
    rfx := case when (rfx ->> 'stagger')::int <= 1 then rfx - 'stagger' else jsonb_set(rfx, '{stagger}', to_jsonb((rfx ->> 'stagger')::int - 1)) end;
    if rfx ? 'stagger_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'stagger_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 0.7 * (least(0.4, 0.8 / greatest(1, n_act)) + 0.8 * greatest(1, n_act) / 7.0), 'guard'); end if;
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 휘청여 반격하지 못합니다.');
  elsif rfx ? 'charge' then
    rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int - case when tick then 1 else 0 end));
    if (rfx -> 'charge' ->> 'got')::int >= (rfx -> 'charge' ->> 'need')::int then
      rfx := rfx - 'charge';
      perform public.world_raid_say(p_raid, 'boss', '몰아친 공격에 ' || rd.boss_name || '의 기운 모으기가 끊겼습니다.');
    elsif (case when (rfx -> 'charge' ->> 'until') is not null then extract(epoch from now()) >= (rfx -> 'charge' ->> 'until')::numeric else (rfx -> 'charge' ->> 'left')::int <= 0 end) then
      rfx := rfx - 'charge';
      perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 모은 봉연의 기운을 터뜨립니다!');
      for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' loop
        raw := public.world_raid_boss_base(p_raid, rd.kind, m.level) * ph_mul * 2.2 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
        perform public.world_raid_hit(p_raid, m.owner_id, raw, 'burst');
      end loop;
      if rfx ? 'break_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'break_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 2.2 * (rfx ->> 'break')::numeric / 100.0 * 0.7 * greatest(1, n_act), 'guard'); end if;
      rfx := rfx - 'break' - 'break_by';
    end if;
  elsif tick and rd.phase = 3 and bt % 11 = 0 then
    rfx := rfx || jsonb_build_object('charge', jsonb_build_object('left', case when rd.kind = 'world' then 4 else 5 + greatest(1, n_act) end, 'until', case when rd.kind = 'world' then round(extract(epoch from now())::numeric + 8, 2) end, 'need', public.world_raid_charge_need(p_raid, rd.kind, rd.max_hp), 'got', 0));
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 기운을 모읍니다. ' || public.world_raid_charge_need(p_raid, rd.kind, rd.max_hp) || ' 넘게 몰아쳐 끊거나, 방어하세요!');
  elsif tick and bt % 7 = 0 then
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 크게 휘둘러 모두를 덮칩니다.');
    for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' loop
      raw := public.world_raid_boss_base(p_raid, rd.kind, m.level) * ph_mul * 0.8 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
      perform public.world_raid_hit(p_raid, m.owner_id, raw, 'slam');
    end loop;
    if rfx ? 'break_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'break_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 0.8 * (rfx ->> 'break')::numeric / 100.0 * 0.7 * greatest(1, n_act), 'guard'); end if;
    rfx := rfx - 'break' - 'break_by';
  elsif tick and rd.phase >= 2 and bt % 5 = 0 then
    select x.owner_id, x.name into pick, nm from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) order by random() limit 1;
    if pick is not null then
      update public.world_raid_members set fx = fx || '{"bound":1}'::jsonb where raid_id = p_raid and owner_id = pick;
      perform public.world_raid_say(p_raid, 'boss', '봉연의 사슬이 ' || nm || '을(를) 휘감습니다(다음 공격 절반).');
    end if;
  elsif random() < least(0.4, 0.8 / greatest(1, n_act)) then
    -- 표적: 이목^1.3에 비례(호법 신장은 이목을 더한다)
    select x.owner_id, x.level into pick, lv from public.world_raid_members x
     where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds'
     order by public.world_cb_pick_key((x.stats ->> 'pres')::numeric + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)) limit 1;
    if pick is not null then
      if rfx ? 'smoke' and random() * 100 < (rfx -> 'smoke' ->> 'miss')::numeric then
        perform public.world_raid_credit(p_raid, nullif(rfx -> 'smoke' ->> 'by', '')::uuid, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul * 0.7, 'guard');
        perform public.world_raid_say(p_raid, 'miss', '연막 속에서 ' || rd.boss_name || '의 공격이 빗나갔습니다.');
      else
        perform public.world_raid_hit(p_raid, pick, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul, 'single');
      end if;
      if rfx ? 'smoke' then rfx := case when (rfx -> 'smoke' ->> 'n')::int <= 1 then rfx - 'smoke' else jsonb_set(rfx, '{smoke,n}', to_jsonb((rfx -> 'smoke' ->> 'n')::int - 1)) end; end if;
    end if;
  end if;

  -- 결전에서 모두 물러나면 보스가 기운을 되찾는다
  if rd.kind = 'final' and not exists (select 1 from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id)) then
    rd.hp := least(rd.max_hp, rd.hp + round(rd.max_hp * 0.015));
    perform public.world_raid_say(p_raid, 'boss', '모두 물러난 사이 ' || rd.boss_name || '이(가) 기운을 되찾습니다(체력 +1.5%).');
  end if;
  rd.intent := case when rfx ? 'charge' then '기운을 모으는 중 — ' || case when rd.kind = 'world' then greatest(0, ceil(coalesce((rfx -> 'charge' ->> 'until')::numeric, extract(epoch from now()) + (rfx -> 'charge' ->> 'left')::int * 2) - extract(epoch from now())))::int || '초' else '남은 ' || (rfx -> 'charge' ->> 'left') || '번' end || ' 안에 ' || greatest(0, (rfx -> 'charge' ->> 'need')::int - (rfx -> 'charge' ->> 'got')::int) || ' 더 몰아치면 끊긴다'
        when (bt + 1) % 7 = 0 then '크게 휘두를 낌새가 보인다 — 방어하라'
        when rd.phase >= 2 and (bt + 1) % 5 = 0 then '사슬이 꿈틀거린다'
        else null end;
  update public.world_raids set hp = rd.hp, turn = rd.turn, phase = rd.phase, fx = rfx, intent = rd.intent, updated_at = now() where raid_id = p_raid;
  return public.world_raid_snapshot(p_raid);
end $function$;

CREATE OR REPLACE FUNCTION public.world_raid_hit(p_raid uuid, p_target uuid, p_raw numeric, p_kind text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare m public.world_raid_members%rowtype; pm public.world_raid_members%rowtype; f jsonb; r jsonb; c jsonb; d int; hp int; who uuid := p_target; nm text; absorb int;
  rk text := (select x.kind from public.world_raids x where x.raid_id = p_raid); st jsonb; self_guard numeric;
begin
  select * into m from public.world_raid_members where raid_id = p_raid and owner_id = p_target for update;
  if not found then return 0; end if;
  f := m.fx;
  -- 퇴마관의 대신 막기: 그 동료를 노린 공격을 지킨 사람이 절반만 받는다
  if f ? 'cover' and (f -> 'cover' ->> 'until')::timestamptz > now() then
    select * into pm from public.world_raid_members where raid_id = p_raid and owner_id = (f -> 'cover' ->> 'by')::uuid for update;
    if found and pm.out_until is null then
      perform public.world_raid_say(p_raid, 'coop', pm.name || ' — ' || m.name || '을(를) 노린 공격을 대신 막았습니다.');
      perform public.world_raid_credit(p_raid, pm.owner_id, p_raw * 0.5 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0), 'guard');
      m := pm; who := pm.owner_id; p_raw := p_raw * 0.5;
    end if;
  end if;
  nm := m.name;
  st := m.stats;
  r := public.world_cb_mitigate(p_raw, st, m.fx, who, p_kind in ('slam', 'burst'), p_kind = 'burst', null, p_kind = 'single');
  for c in select * from jsonb_array_elements(r -> 'credits') loop
    perform public.world_raid_credit(p_raid, (c ->> 0)::uuid, (c ->> 1)::numeric, c ->> 2);
  end loop;
  f := r -> 'fx'; d := (r ->> 'd')::int; absorb := (r ->> 'absorb')::int;
  if (r ->> 'evaded')::boolean then
    update public.world_raid_members set fx = f where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say(p_raid, 'miss', nm || ' — 공격을 피했습니다.');
    return 0;
  end if;
  perform public.world_raid_credit(p_raid, who, d, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);
  -- 한 사람을 노린 공격: 자기 방어로 줄인 몫의 절반은 막아 준 피해(7.7.7r)
  if p_kind = 'single' then
    self_guard := p_raw * (1 - (1 - least(80, coalesce((st ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((st ->> 'inc')::numeric, 0) / 100.0)) * 0.5;
    if self_guard > 0 then perform public.world_raid_credit(p_raid, who, self_guard, 'guard'); end if;
  end if;
  update public.world_characters set health = greatest(1, health - d), updated_at = now() where owner_id = who returning health into hp;
  if hp <= 1 and d > 0 then
    update public.world_raid_members set taken = taken + d, fx = f - 'bound', out_until = now() + case when (select x.kind from public.world_raids x where x.raid_id = p_raid) = 'final' then interval '30 seconds' else interval '60 seconds' end, falls = falls + 1 where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say_n(p_raid, 'fall', nm || ' — ' || d || '의 피해를 입고 물러났습니다(' || case when (select x.kind from public.world_raids x where x.raid_id = p_raid) = 'final' then '30초' else '1분' end || ' 쉰 뒤 행동하면 돌아옴).', nm, d);
  else
    update public.world_raid_members set taken = taken + d, fx = f where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say_n(p_raid, 'hit', nm || ' — ' || d || '의 피해' || '.', nm, d);
  end if;
  return d;
end $function$;

CREATE OR REPLACE FUNCTION public.world_character_purge(p_uid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if p_uid is null then return; end if;
  delete from public.world_quest_progress where owner_id = p_uid;
  delete from public.world_quest_abandons where owner_id = p_uid;
  delete from public.world_faction_progress where owner_id = p_uid;
  delete from public.world_faction_unlocks where owner_id = p_uid;
  delete from public.world_tutorial_state where owner_id = p_uid;
  delete from public.world_storage where owner_id = p_uid;
  delete from public.world_title_presets where owner_id = p_uid;
  delete from public.world_quickslots where owner_id = p_uid;
  delete from public.world_skill_picks where owner_id = p_uid;
  delete from public.world_item_locks where owner_id = p_uid;
  delete from public.world_item_durability where owner_id = p_uid;
  delete from public.world_item_acquired where owner_id = p_uid;
  delete from public.world_gear_enhance where owner_id = p_uid;
  delete from public.world_overflow_items where owner_id = p_uid;
  delete from public.world_monster_codex where owner_id = p_uid;
  delete from public.world_fish_log where owner_id = p_uid;
  delete from public.world_region_visits where owner_id = p_uid;
  delete from public.world_hidden_trails where owner_id = p_uid;
  delete from public.world_character_cosmetics where owner_id = p_uid;
  delete from public.world_craft_favorites where owner_id = p_uid;
  delete from public.world_pet_profile where owner_id = p_uid;
  delete from public.world_pet_streak where owner_id = p_uid;
  delete from public.world_pet_gifts where owner_id = p_uid;
  delete from public.world_pet_guest where owner_id = p_uid;
  delete from public.world_pets where owner_id = p_uid;
  delete from public.world_xp_damp where owner_id = p_uid;
  delete from public.world_yohwa_log where owner_id = p_uid;
  delete from public.world_user_commissions where owner_id = p_uid and status = 'open';
  if not exists (select 1 from public.world_housing_shared s where p_uid in (s.home_id, s.mate_id)) then
    delete from public.world_housing_store where owner_id = p_uid;
    delete from public.world_housing_rewards where owner_id = p_uid;
    delete from public.world_housing_guestbook where owner_id = p_uid;
    delete from public.world_housing_visits where owner_id = p_uid;
    delete from public.world_housing where owner_id = p_uid;
  end if;
end $function$;

update public.world_app_meta set value = '20261106070000' where key = 'db_version';
