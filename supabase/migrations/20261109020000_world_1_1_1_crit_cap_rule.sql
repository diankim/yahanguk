CREATE OR REPLACE FUNCTION public.world_agile_rules()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select jsonb_build_object(
    'agi_k', 2, 'tank_k', 0.5,
    'quiet_k', 0.8, 'quiet_cap', 50,
    'sneak_base', 25, 'sneak_k', 0.65, 'sneak_cap', 75, 'sneak_min', 10, 'scout_sneak', 10,
    'flee_base', 50, 'flee_k', 0.5, 'flee_cap', 95, 'flee_min', 10, 'scout_flee', 15,
    'hazard_base', 30, 'hazard_k', 0.75, 'hazard_cap', 90, 'hazard_w_k', 0.05,
    'eva_base', 3, 'eva_k', 0.175, 'eva_cap', 40, 'scout_eva', 6, 'crit_cap', 60)
$function$;

CREATE OR REPLACE FUNCTION public.world_combat_stats(p_owner uuid, p_delta jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE c public.world_characters%rowtype; s_str int; s_agi int; s_vit int; s_per int; s_wil int; s_spi int;
  w_id text; w_name text; w_tr jsonb; w_dur int; w_max int; a_id text; a_name text; a_tr jsonb; a_dur int; a_max int;
  style text := 'melee'; wpow numeric := 2; wbonus numeric := 0; adef numeric := 0; adr numeric := 0; w_state text := 'none'; a_state text := 'none';
  base numeric; mind numeric := 1; pct numeric; style_pct numeric; attack numeric; defense numeric; red numeric; inc numeric; eva numeric; crit numeric; flee numeric;
  skill_cat text; skill_pct numeric := 0; skill_crit numeric := 0; skills jsonb := '[]'::jsonb;
  g_def numeric; g_eva numeric; g_crit numeric; g_flee numeric; g_pres numeric; pres numeric;
BEGIN
  SELECT * INTO c FROM public.world_characters WHERE owner_id = p_owner;
  IF NOT FOUND THEN RETURN NULL; END IF;
  s_str := c.strength + coalesce((p_delta ->> 'strength')::int, 0); s_agi := c.agility + coalesce((p_delta ->> 'agility')::int, 0); s_agi := greatest(1, round(s_agi * (1 + public.world_status_self(p_owner, 'agility_pct') / 100.0))::int);
  s_vit := c.vitality + coalesce((p_delta ->> 'vitality')::int, 0); s_per := c.perception + coalesce((p_delta ->> 'perception')::int, 0);
  s_wil := c.willpower + coalesce((p_delta ->> 'willpower')::int, 0); s_spi := c.spirit_affinity + coalesce((p_delta ->> 'spirit_affinity')::int, 0);

  SELECT e.item_id, i.item_name, i.equipment_traits, d.durability INTO w_id, w_name, w_tr, w_dur
    FROM public.world_character_equipment e JOIN public.world_item_catalog i ON i.item_id = e.item_id
    LEFT JOIN public.world_item_durability d ON d.owner_id = e.owner_id AND d.item_id = e.item_id WHERE e.owner_id = p_owner AND e.slot = 'weapon';
  IF w_id IS NOT NULL THEN
    w_max := public.world_item_max_durability(w_id); w_dur := coalesce(w_dur, w_max);
    style := coalesce(w_tr ->> 'weapon_type', 'melee');
    IF w_dur <= 0 THEN w_state := 'broken'; wpow := 2;
    ELSE
      wpow := coalesce((w_tr ->> 'power')::numeric, 2); wbonus := coalesce((w_tr ->> 'combat_damage_pct')::numeric, 0); w_state := 'ok';
      IF w_dur * 4 < w_max THEN wpow := wpow * 0.8; w_state := 'worn'; END IF;
      wpow := wpow * (1 + 0.05 * public.world_enhance_level(p_owner, w_id));
    END IF;
  END IF;
  SELECT e.item_id, i.item_name, i.equipment_traits, d.durability INTO a_id, a_name, a_tr, a_dur
    FROM public.world_character_equipment e JOIN public.world_item_catalog i ON i.item_id = e.item_id
    LEFT JOIN public.world_item_durability d ON d.owner_id = e.owner_id AND d.item_id = e.item_id WHERE e.owner_id = p_owner AND e.slot = 'armor';
  IF a_id IS NOT NULL THEN
    a_max := public.world_item_max_durability(a_id); a_dur := coalesce(a_dur, a_max);
    IF a_dur <= 0 THEN a_state := 'broken';
    ELSE
      adef := coalesce((a_tr ->> 'defense')::numeric, 0); adr := coalesce((a_tr ->> 'damage_reduction_pct')::numeric, 0); a_state := 'ok';
      IF a_dur * 4 < a_max THEN adef := adef * 0.8; a_state := 'worn'; END IF;
    END IF;
  END IF;
  -- 그 밖의 장비가 더하는 전투 특성(관모·신·노리개·호신부·탈, 무기·방어구의 덧붙은 특성)
  g_def := public.world_gear_total(p_owner, 'defense') + public.world_title_bonus_of(p_owner, 'defense'); g_eva := public.world_gear_total(p_owner, 'evasion_pct') + public.world_title_bonus_of(p_owner, 'evasion_pct');
  g_crit := public.world_gear_total(p_owner, 'crit_pct') + public.world_title_bonus_of(p_owner, 'crit_pct'); g_flee := public.world_gear_total(p_owner, 'flee_pct') + public.world_title_bonus_of(p_owner, 'flee_pct');
  g_pres := public.world_gear_total(p_owner, 'presence') + public.world_title_bonus_of(p_owner, 'presence');

  -- 익힌 전투 기술: 직업 계열(7.7.7p)과 분석·조합 기술의 상시 효과
  skill_cat := coalesce(public.world_job_line(c.job_key), CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'sealing' ELSE 'melee' END);
  SELECT coalesce(sum(CASE WHEN sk.category = skill_cat THEN coalesce((sk.passive_effect ->> 'damage_pct')::numeric, 0) ELSE 0 END), 0),
         coalesce(sum(coalesce((sk.passive_effect ->> 'crit_pct')::numeric, 0)), 0),
         coalesce(jsonb_agg(sk.skill_name), '[]'::jsonb)
    INTO skill_pct, skill_crit, skills
    FROM public.world_skill_catalog sk
    WHERE sk.category IN (skill_cat, 'analysis', 'combo') AND public.world_skill_line_ok(sk.category, sk.requires, c.job_key) AND public.world_skill_has(c.skill_progress, coalesce((select pk.picks from public.world_skill_picks pk where pk.owner_id = p_owner), '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires);

  base := CASE style
    WHEN 'ranged' THEN 6 + s_agi * 0.6 + s_per * 0.45 + wpow * 1.5 + c.level * 0.8
    WHEN 'magic' THEN 6 + s_spi * 0.75 + s_wil * 0.4 + wpow * 1.5 + c.level * 0.8
    ELSE 8 + s_str * 1.0 + wpow * 1.6 + c.level * 0.8 END;
  IF c.mental < 20 THEN mind := mind * 0.7; ELSIF c.mental < 40 THEN mind := mind * 0.85; END IF;
  IF c.erosion >= 30 AND public.world_on_island(p_owner) THEN NULL; -- 귀허도 요기 순응: 섬에서는 침식으로 공격력이 줄지 않음(7.4.3)
  ELSIF c.erosion >= 80 THEN mind := mind * 0.7; ELSIF c.erosion >= 55 THEN mind := mind * 0.8; ELSIF c.erosion >= 30 THEN mind := mind * 0.9; END IF;
  style_pct := public.world_status_effect_total(style || '_pct') + public.world_title_bonus_of(p_owner, style || '_pct');
  pct := public.world_status_effect_total('combat_damage_pct') + public.world_title_bonus_of(p_owner, 'combat_damage_pct') + wbonus + style_pct + skill_pct; -- 요화·요괴화의 피해와 침식 불이익은 상한 밖(상한에 묻혀 효과가 사라지지 않게)
  pct := least(35, pct - public.world_status_self(p_owner, 'combat_damage_pct') - public.world_erosion_effect('combat_damage_pct'))
         + (SELECT coalesce(sum((cat.effects ->> 'combat_damage_pct')::numeric * coalesce(cs.potency, 1)), 0) FROM public.world_character_statuses cs JOIN public.world_status_catalog cat USING (status_key)
             WHERE cs.owner_id = p_owner AND cs.expires_at > now() AND cs.status_key IN ('yohwa', 'yohwa_frenzy'))
         + least(0, public.world_erosion_effect('combat_damage_pct'))
         + public.world_status_self(p_owner, 'combat_damage_pct')
         - (SELECT coalesce(sum((cat.effects ->> 'combat_damage_pct')::numeric * coalesce(cs.potency, 1)), 0) FROM public.world_character_statuses cs JOIN public.world_status_catalog cat USING (status_key)
             WHERE cs.owner_id = p_owner AND cs.expires_at > now() AND cs.status_key IN ('yohwa', 'yohwa_frenzy'));
  attack := base * (1 + (least(coalesce(c.combat_rank, 1), 50) - 1) * 0.006) * mind * (1 + pct / 100.0)
    * CASE WHEN c.job_key = 'artificer' THEN 0.85 WHEN c.job_key = 'analyst' AND style = 'melee' THEN 1.18 ELSE 1 END;
  defense := greatest(0, s_vit * 0.8 + adef + g_def + c.level * 0.5 + CASE WHEN c.job_key = 'sealmaster' THEN 30 ELSE 0 END);
  red := 1 - (100.0 / (100 + defense * 3)) * (1 - adr / 100.0);
  inc := greatest(-60, public.world_status_effect_total('incoming_damage_pct') + public.world_title_bonus_of(p_owner, 'incoming_damage_pct'));
  eva := greatest(0, least((public.world_agile_rules() ->> 'eva_cap')::numeric, (public.world_agile_rules() ->> 'eva_base')::numeric
    + public.world_agile_of(s_str, s_agi, s_vit, s_per, s_wil, s_spi) * (public.world_agile_rules() ->> 'eva_k')::numeric
    + CASE WHEN c.job_key = 'scout' THEN (public.world_agile_rules() ->> 'scout_eva')::numeric ELSE 0 END + g_eva));
  crit := greatest(0, least((public.world_agile_rules() ->> 'crit_cap')::numeric, 5 + s_per * 0.4 + CASE WHEN style = 'ranged' THEN 8 ELSE 0 END + CASE WHEN c.job_key = 'analyst' AND style = 'melee' THEN 5 WHEN c.job_key = 'scout' AND style = 'ranged' THEN 4 ELSE 0 END + skill_crit + g_crit));
  flee := greatest((public.world_agile_rules() ->> 'flee_min')::numeric, least((public.world_agile_rules() ->> 'flee_cap')::numeric, (public.world_agile_rules() ->> 'flee_base')::numeric
    + public.world_agile_of(s_str, s_agi, s_vit, s_per, s_wil, s_spi) * (public.world_agile_rules() ->> 'flee_k')::numeric
    + CASE WHEN c.job_key = 'scout' THEN (public.world_agile_rules() ->> 'scout_flee')::numeric ELSE 0 END + g_flee));
  -- 이목: 요괴가 먼저 노리는 정도. 몸집(체력)과 갑옷이 무거울수록 높고, 날랠수록 낮다
  pres := greatest(5, least(300, (1 + coalesce((SELECT sum((sk.passive_effect ->> 'presence_pct')::numeric) FROM public.world_skill_catalog sk
      WHERE sk.category = skill_cat AND sk.passive_effect ? 'presence_pct' AND public.world_skill_line_ok(sk.category, sk.requires, c.job_key)
        AND public.world_skill_has(c.skill_progress, '{}'::jsonb, sk.category, sk.unlock_rank, sk.slot, sk.requires)), 0) / 100.0) * (30 + CASE WHEN c.job_key = 'artificer' THEN 80 WHEN c.job_key = 'sealmaster' THEN 60 WHEN c.job_key = 'exorcist' THEN -15 ELSE 0 END + s_vit * 0.8 - s_agi * 0.4 + adef * 0.6 + g_pres
    + CASE WHEN style = 'melee' THEN (SELECT coalesce(sum(CASE x WHEN 'melee_c13b' THEN 40 WHEN 'melee_c24b' THEN 60 WHEN 'melee_x30' THEN 30 WHEN 'melee_c43b' THEN 150 ELSE 0 END), 0) FROM unnest(public.world_skill_procs(p_owner)) x) ELSE 0 END)));
  RETURN jsonb_build_object(
    'style', style, 'attack', round(attack), 'attack_raw', attack, 'damage_pct', round(pct, 1), 'style_pct', round(style_pct, 1), 'skill_pct', skill_pct, 'skills', skills,
    'defense', round(defense, 1), 'reduction_pct', round(red * 100, 1), 'incoming_pct', round(inc, 1),
    'evasion_pct', round(eva, 1), 'crit_pct', round(crit, 1), 'crit_mult', 150, 'damage_cap', 35, 'flee_pct', round(flee),
    'presence', round(pres), 'gear_presence', round(g_pres, 1),
    'spell_cost', CASE WHEN style = 'magic' THEN 3 ELSE 0 END, 'mind_mul', round(mind, 2),
    'weapon', CASE WHEN w_id IS NULL THEN NULL ELSE jsonb_build_object('item_id', w_id, 'name', w_name, 'enhance', public.world_enhance_level(p_owner, w_id), 'type', style, 'power', round(wpow, 1),
      'durability', w_dur, 'max', w_max, 'state', w_state) END,
    'armor', CASE WHEN a_id IS NULL THEN NULL ELSE jsonb_build_object('item_id', a_id, 'name', a_name, 'defense', round(adef, 1), 'reduction', adr,
      'durability', a_dur, 'max', a_max, 'state', a_state) END,
    'stats', jsonb_build_object('strength', s_str, 'agility', s_agi, 'vitality', s_vit, 'perception', s_per, 'willpower', s_wil, 'spirit_affinity', s_spi));
END $function$;

update public.world_app_meta set value = '20261109020000' where key = 'db_version';
