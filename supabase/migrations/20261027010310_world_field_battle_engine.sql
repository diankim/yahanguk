-- 현장 상황 조회·세부 지역 이동·전투 엔진 (fn_owner_field 소유)
SET ROLE fn_owner_field;

-- ── 현장 상황 ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.world_field_battle_view(p_owner uuid)
 RETURNS jsonb LANGUAGE sql STABLE SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT CASE WHEN a.owner_id IS NULL OR a.defeated OR coalesce(a.fled, false) OR a.mlevel IS NULL THEN NULL ELSE jsonb_build_object(
    'monster_id', m.monster_id, 'name', m.monster_name, 'type', m.monster_type, 'mechanic', m.mechanic_key, 'role', m.role,
    'description', m.description, 'rank', a.rank, 'level', a.mlevel, 'hp', a.current_hp, 'max_hp', a.max_hp, 'atk', a.atk,
    'intent', a.intent, 'turn', a.turn_count, 'fx', a.fx, 'pfx', a.pfx, 'log', a.log,
    'next_action_at', a.last_action_at + interval '2 seconds') END
  FROM (SELECT p_owner AS o) q
  LEFT JOIN public.world_active_encounters a ON a.owner_id = q.o
  LEFT JOIN public.world_region_monsters m ON m.monster_id = a.monster_id
$f$;

CREATE OR REPLACE FUNCTION public.world_field_snapshot()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype;
  n public.world_exploration_nodes%rowtype; st int; mx int; theme text; weapon jsonb; chap text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  r := public.world_field_region(c.location);
  SELECT * INTO n FROM public.world_exploration_nodes WHERE node_id = c.current_exploration_node_id AND region_id = r.region_id;
  IF n.node_id IS NULL THEN
    SELECT * INTO n FROM public.world_exploration_nodes WHERE region_id = r.region_id AND hierarchy_level = 1 LIMIT 1;
  END IF;
  st := public.world_stamina_now(c.stamina, c.stamina_at, c.level); mx := public.world_stamina_max(c.level);
  SELECT t.theme INTO theme FROM public.world_region_theme t WHERE t.region_id = r.region_id;
  SELECT jsonb_build_object('item_id', i.item_id, 'name', i.item_name, 'type', coalesce(i.equipment_traits ->> 'weapon_type', 'melee'),
      'power', coalesce((i.equipment_traits ->> 'power')::int, 0))
    INTO weapon FROM public.world_character_equipment e JOIN public.world_item_catalog i ON i.item_id = e.item_id
    WHERE e.owner_id = uid AND e.slot = 'weapon';
  chap := public.world_story_current(uid);
  RETURN jsonb_build_object(
    'region', jsonb_build_object('region_id', r.region_id, 'region_name', r.region_name, 'territory_name', r.territory_name,
      'faction_id', r.control_faction_id, 'faction_name', r.faction_control, 'danger', r.danger_level, 'min_level', r.min_level,
      'safe', r.is_safe_zone, 'shop_name', r.shop_name, 'has_stable', r.has_stable, 'theme', theme, 'description', r.description,
      'rest_spot_name', r.rest_spot_name, 'rest_spot_type', r.rest_spot_type, 'rest_fee', r.rest_fee),
    'stamina', jsonb_build_object('now', st, 'max', mx, 'per_seconds', 360,
      'next_at', CASE WHEN st >= mx THEN NULL ELSE c.stamina_at + make_interval(secs => (floor(greatest(0, extract(epoch FROM now() - c.stamina_at)) / 360)::int + 1) * 360) END),
    'weapon', coalesce(weapon, jsonb_build_object('item_id', NULL, 'name', '맨손', 'type', 'melee', 'power', 2)),
    'node', jsonb_build_object('node_id', n.node_id, 'name', n.node_name, 'level', n.hierarchy_level, 'depth', n.hierarchy_level - 1,
      'description', n.description, 'min_level', n.min_level, 'parent_id', n.parent_node_id),
    'path', (WITH RECURSIVE up AS (SELECT x.node_id, x.node_name, x.parent_node_id, x.hierarchy_level FROM public.world_exploration_nodes x WHERE x.node_id = n.node_id
               UNION ALL SELECT y.node_id, y.node_name, y.parent_node_id, y.hierarchy_level FROM public.world_exploration_nodes y JOIN up ON y.node_id = up.parent_node_id)
             SELECT coalesce(jsonb_agg(jsonb_build_object('node_id', node_id, 'name', node_name, 'level', hierarchy_level) ORDER BY hierarchy_level), '[]'::jsonb) FROM up),
    'nodes', (SELECT coalesce(jsonb_agg(jsonb_build_object('node_id', x.node_id, 'name', x.node_name, 'level', x.hierarchy_level,
        'parent_id', x.parent_node_id, 'min_level', x.min_level, 'here', x.node_id = n.node_id,
        'paths_total', (SELECT count(*) FROM public.world_exploration_nodes z WHERE z.parent_node_id = x.node_id),
        'paths_found', (SELECT count(*) FROM public.world_exploration_nodes z JOIN public.world_exploration_discoveries d ON d.node_id = z.node_id AND d.owner_id = uid WHERE z.parent_node_id = x.node_id),
        'spots_total', (SELECT count(*) FROM public.world_gathering_spots s WHERE s.node_id = x.node_id AND s.active),
        'spots_found', (SELECT count(*) FROM public.world_gathering_spots s JOIN public.world_gathering_discoveries d ON d.spot_id = s.spot_id AND d.owner_id = uid WHERE s.node_id = x.node_id))
        ORDER BY x.hierarchy_level, x.sort_order, x.node_name), '[]'::jsonb)
      FROM public.world_exploration_nodes x
      WHERE x.region_id = r.region_id AND (x.hierarchy_level = 1 OR EXISTS (SELECT 1 FROM public.world_exploration_discoveries d WHERE d.owner_id = uid AND d.node_id = x.node_id))),
    'spots', (SELECT coalesce(jsonb_agg(jsonb_build_object('spot_id', s.spot_id, 'name', s.spot_name, 'category', s.category, 'min_level', s.min_level,
        'items', (SELECT jsonb_agg(DISTINCT x) FROM unnest(s.loot_items) x), 'gather_count', d.gather_count,
        'ready_at', CASE WHEN d.last_gathered_at IS NOT NULL AND d.last_gathered_at > now() - interval '5 minutes' THEN d.last_gathered_at + interval '5 minutes' END)
        ORDER BY s.spot_name), '[]'::jsonb)
      FROM public.world_gathering_spots s JOIN public.world_gathering_discoveries d ON d.spot_id = s.spot_id AND d.owner_id = uid
      WHERE s.node_id = n.node_id AND s.active),
    'hidden_spots', (SELECT count(*) FROM public.world_gathering_spots s WHERE s.node_id = n.node_id AND s.active
      AND NOT EXISTS (SELECT 1 FROM public.world_gathering_discoveries d WHERE d.owner_id = uid AND d.spot_id = s.spot_id)),
    'hidden_paths', (SELECT count(*) FROM public.world_exploration_nodes z WHERE z.parent_node_id = n.node_id
      AND NOT EXISTS (SELECT 1 FROM public.world_exploration_discoveries d WHERE d.owner_id = uid AND d.node_id = z.node_id)),
    'survey', public.world_field_survey(uid, r.region_id),
    'battle', public.world_field_battle_view(uid),
    'story_here', (SELECT coalesce(jsonb_agg(jsonb_build_object('clue_id', k.clue_id, 'chapter', ch.title)), '[]'::jsonb)
      FROM public.world_story_clues k JOIN public.world_story_chapters ch ON ch.chapter_id = k.chapter_id
      WHERE k.chapter_id = chap AND k.region_id = r.region_id AND c.level >= ch.min_level
        AND NOT EXISTS (SELECT 1 FROM public.world_case_progress p WHERE p.owner_id = uid AND p.case_id = k.chapter_id
                        AND p.clues @> jsonb_build_array(jsonb_build_object('id', k.clue_id)))),
    'monsters', (SELECT coalesce(jsonb_agg(jsonb_build_object('name', m.monster_name, 'type', m.monster_type, 'mechanic', m.mechanic_key, 'role', m.role,
        'min_level', m.min_level, 'max_level', m.max_level) ORDER BY m.role DESC, m.min_level), '[]'::jsonb)
      FROM public.world_region_monsters m WHERE m.region_id = r.region_id),
    'recent', (SELECT coalesce(jsonb_agg(jsonb_build_object('content', e.content, 'kind', coalesce(e.payload ->> 'outcome', e.event_type), 'at', e.created_at) ORDER BY e.created_at DESC), '[]'::jsonb)
      FROM (SELECT * FROM public.world_events e WHERE e.actor_id = uid AND e.event_type IN ('explore', 'gather', 'combat', 'battle_lost', 'battle_fled')
              AND e.created_at > now() - interval '1 day' ORDER BY e.created_at DESC LIMIT 12) e)
  );
END $f$;

-- 같은 지역 안에서는 찾아낸 곳으로 곧바로 옮겨 간다.
CREATE OR REPLACE FUNCTION public.world_field_move(p_node_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; n public.world_exploration_nodes%rowtype;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태에서는 움직일 수 없습니다.'; END IF;
  IF c.travel_arrives_at IS NOT NULL AND c.travel_arrives_at > now() THEN RAISE EXCEPTION '이동 중입니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = uid AND NOT a.defeated AND NOT coalesce(a.fled, false)) THEN
    RAISE EXCEPTION '전투 중에는 자리를 옮길 수 없습니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = uid AND e.status = 'active') THEN RAISE EXCEPTION '원정 중에는 움직일 수 없습니다.'; END IF;
  r := public.world_field_region(c.location);
  SELECT * INTO n FROM public.world_exploration_nodes WHERE node_id = p_node_id AND region_id = r.region_id;
  IF NOT FOUND THEN RAISE EXCEPTION '지금 있는 지역의 장소가 아닙니다.'; END IF;
  IF n.hierarchy_level > 1 AND NOT EXISTS (SELECT 1 FROM public.world_exploration_discoveries d WHERE d.owner_id = uid AND d.node_id = n.node_id) THEN
    RAISE EXCEPTION '아직 찾지 못한 곳입니다. 탐색으로 길을 찾으세요.'; END IF;
  IF c.level < n.min_level THEN RAISE EXCEPTION '%', format('레벨 %s부터 들어갈 수 있는 곳입니다.', n.min_level); END IF;
  UPDATE public.world_characters SET current_exploration_node_id = n.node_id, updated_at = now() WHERE owner_id = uid;
  RETURN jsonb_build_object('ok', true, 'content', n.node_name || '(으)로 옮겼습니다.', 'node_id', n.node_id);
END $f$;

-- ── 전투 ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.world_battle_intent(p_mech text, p_hp_ratio numeric, p_rank text)
 RETURNS text LANGUAGE plpgsql VOLATILE SET search_path TO 'pg_catalog'
AS $f$
DECLARE x float8 := random(); sp text; special float8 := CASE WHEN p_rank <> 'normal' AND p_hp_ratio < 0.5 THEN 0.38 ELSE 0.25 END;
BEGIN
  sp := CASE p_mech WHEN 'aerial' THEN 'soar' WHEN 'armored' THEN 'harden' WHEN 'spectral' THEN 'wail' WHEN 'toxic' THEN 'venom'
    WHEN 'swarm' THEN 'swarm' WHEN 'reflect' THEN 'mirror' WHEN 'tide' THEN 'tide' WHEN 'ambush' THEN 'lurk' WHEN 'warded' THEN 'barrier'
    WHEN 'boss' THEN 'charge' WHEN 'seal_breaker' THEN 'breach' ELSE 'heavy' END;
  IF x < special THEN RETURN sp; END IF;
  IF x < special + 0.2 THEN RETURN 'heavy'; END IF;
  IF x < special + 0.28 AND p_hp_ratio < 0.6 THEN RETURN 'rest'; END IF;
  RETURN 'strike';
END $f$;

-- 탐색 중 조우: 지역·깊이에 맞는 요괴를 고르고 전투를 연다.
CREATE OR REPLACE FUNCTION public.world_battle_open(p_owner uuid, p_region text, p_node uuid, p_depth integer, p_level integer)
 RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE m public.world_region_monsters%rowtype; rk text := 'normal'; lv int; hpm float8 := 1; atm float8 := 1; hp int; v_atk int; df int;
  node_min int; v_intent text;
BEGIN
  SELECT min_level INTO node_min FROM public.world_exploration_nodes WHERE node_id = p_node;
  IF p_depth >= 3 AND random() < CASE WHEN p_depth >= 4 THEN 0.16 ELSE 0.09 END THEN
    SELECT * INTO m FROM public.world_region_monsters WHERE region_id = p_region AND role = 'guardian' ORDER BY random() LIMIT 1;
  END IF;
  IF m.monster_id IS NULL THEN
    SELECT * INTO m FROM public.world_region_monsters WHERE region_id = p_region AND role IN ('common', 'main')
    ORDER BY -ln(greatest(random(), 1e-9)) / CASE role WHEN 'common' THEN 6 ELSE 4 END LIMIT 1;
  ELSE rk := 'guardian'; END IF;
  IF m.monster_id IS NULL THEN RETURN NULL; END IF;
  IF rk = 'normal' AND p_depth >= 2 AND random() < 0.05 + p_depth * 0.03 THEN rk := 'elite'; END IF;
  lv := coalesce(node_min, 1) + floor(random() * 3)::int;
  lv := least(lv, p_level + CASE rk WHEN 'normal' THEN 3 ELSE 6 END);
  lv := greatest(1, lv);
  IF rk = 'elite' THEN hpm := 1.6; atm := 1.25; ELSIF rk = 'guardian' THEN hpm := 2.6; atm := 1.4; END IF;
  hp := round((70 + lv * 14) * hpm); v_atk := round((8 + lv * 1.1) * atm);
  df := round(lv * 0.6 * CASE WHEN m.mechanic_key = 'armored' THEN 2 ELSE 1 END);
  v_intent := CASE WHEN m.mechanic_key = 'ambush' THEN 'lurk' ELSE public.world_battle_intent(m.mechanic_key, 1, rk) END;
  INSERT INTO public.world_active_encounters(owner_id, region_id, monster_id, current_hp, max_hp, defeated, fled, started_at, updated_at,
    turn_count, analysis_turns, guard_until_turn, node_id, mlevel, atk, def, rank, intent, fx, pfx, log, last_action_at, result)
  VALUES (p_owner, p_region, m.monster_id, hp, hp, false, false, now(), now(), 0, 0, 0, p_node, lv, v_atk, df, rk, v_intent, '{}', '{}',
    jsonb_build_array(m.monster_name || CASE rk WHEN 'elite' THEN '(정예)' WHEN 'guardian' THEN '(우두머리)' ELSE '' END || '이(가) 나타났다.'),
    now() - interval '2 seconds', NULL)
  ON CONFLICT (owner_id) DO UPDATE SET region_id = excluded.region_id, monster_id = excluded.monster_id, current_hp = excluded.current_hp,
    max_hp = excluded.max_hp, defeated = false, fled = false, started_at = now(), updated_at = now(), turn_count = 0, analysis_turns = 0,
    guard_until_turn = 0, node_id = excluded.node_id, mlevel = excluded.mlevel, atk = excluded.atk, def = excluded.def, rank = excluded.rank,
    intent = excluded.intent, fx = '{}', pfx = '{}', log = excluded.log, last_action_at = excluded.last_action_at, result = NULL;
  RETURN jsonb_build_object('monster_id', m.monster_id, 'name', m.monster_name, 'rank', rk, 'level', lv);
END $f$;

CREATE OR REPLACE FUNCTION public.world_battle_action(p_action text, p_item text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE
  uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; a public.world_active_encounters%rowtype;
  m public.world_region_monsters%rowtype; r public.world_map_regions%rowtype;
  act text := lower(coalesce(p_action, '')); style text := 'melee'; wpow int := 2; wbonus int := 0; armor_def int := 0; dr_pct int := 0;
  turn int; v_fx jsonb; v_pfx jsonb; lines jsonb := '[]'::jsonb; dmg int := 0; mdmg int := 0; heal int := 0; crit boolean := false;
  base float8; mul float8 := 1; cc float8; mdef float8; defv float8; hit float8; v_intent text; next_intent text; skip_monster boolean := false;
  guarding boolean := false; fled boolean := false; ended text; hp int; mn int; sp int; er int; inv jsonb; it text; q int; k text; v int;
  loot jsonb := '{}'::jsonb; xp int := 0; gil_gain int := 0; rk_mul float8; drop_p float8; reflect int := 0; shield int;
  skill_name text; qty int; job_cd int; wtype text; v_result jsonb; statuses text[] := '{}'; sig text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF act NOT IN ('attack', 'skill', 'guard', 'item', 'flee') THEN RAISE EXCEPTION '알 수 없는 행동입니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태입니다.'; END IF;
  SELECT * INTO a FROM public.world_active_encounters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND OR a.defeated OR coalesce(a.fled, false) OR a.mlevel IS NULL THEN RAISE EXCEPTION '진행 중인 전투가 없습니다.'; END IF;
  IF a.last_action_at IS NOT NULL AND a.last_action_at > now() - interval '2 seconds' THEN
    RAISE EXCEPTION '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.'; END IF;
  SELECT * INTO m FROM public.world_region_monsters WHERE monster_id = a.monster_id;
  r := public.world_field_region(c.location);
  IF r.region_id IS DISTINCT FROM a.region_id THEN RAISE EXCEPTION '전투가 벌어진 지역에 있어야 합니다.'; END IF;

  -- 장비
  SELECT coalesce(i.equipment_traits ->> 'weapon_type', 'melee'), coalesce((i.equipment_traits ->> 'power')::int, 0), coalesce((i.equipment_traits ->> 'combat_damage_pct')::int, 0)
    INTO wtype, wpow, wbonus FROM public.world_character_equipment e JOIN public.world_item_catalog i ON i.item_id = e.item_id WHERE e.owner_id = uid AND e.slot = 'weapon';
  style := coalesce(wtype, 'melee'); wpow := coalesce(wpow, 2); wbonus := coalesce(wbonus, 0);
  SELECT coalesce((i.equipment_traits ->> 'defense')::int, 0), coalesce((i.equipment_traits ->> 'damage_reduction_pct')::int, 0)
    INTO armor_def, dr_pct FROM public.world_character_equipment e JOIN public.world_item_catalog i ON i.item_id = e.item_id WHERE e.owner_id = uid AND e.slot = 'armor';
  armor_def := coalesce(armor_def, 0); dr_pct := coalesce(dr_pct, 0);

  turn := a.turn_count + 1; v_fx := coalesce(a.fx, '{}'::jsonb); v_pfx := coalesce(a.pfx, '{}'::jsonb);
  hp := c.health; mn := c.mental; sp := c.spiritual_power; er := c.erosion; inv := coalesce(c.inventory, '{}'::jsonb);
  v_intent := coalesce(a.intent, 'strike');
  job_cd := coalesce((v_pfx ->> 'skill_ready')::int, 0);

  IF act = 'skill' THEN
    IF turn < job_cd THEN RAISE EXCEPTION '%', format('기술은 %s턴 뒤에 다시 쓸 수 있습니다.', job_cd - turn); END IF;
    IF sp < 12 THEN RAISE EXCEPTION '영력이 모자랍니다. (필요 12)'; END IF;
    sp := sp - 12; v_pfx := v_pfx || jsonb_build_object('skill_ready', turn + 3);
  END IF;

  -- ① 조사원의 행동
  IF act = 'flee' THEN
    IF random() < least(0.9, 0.5 + c.agility * 0.01 - greatest(0, a.mlevel - c.level) * 0.03 + CASE WHEN c.job_key = 'scout' THEN 0.15 ELSE 0 END
                         - CASE WHEN a.rank = 'guardian' THEN 0.2 ELSE 0 END) THEN
      fled := true; lines := lines || jsonb_build_array('몸을 돌려 달아났다.');
    ELSE
      lines := lines || jsonb_build_array('달아나려 했지만 길이 막혔다.');
    END IF;
  ELSIF act = 'guard' THEN
    guarding := true; sp := least(100, sp + 4);
    lines := lines || jsonb_build_array('자세를 낮추고 막을 준비를 했다.');
  ELSIF act = 'item' THEN
    it := coalesce(p_item, '');
    IF it NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman') THEN RAISE EXCEPTION '전투 중에 쓸 수 없는 물품입니다.'; END IF;
    IF coalesce((inv ->> it)::int, 0) < 1 THEN RAISE EXCEPTION '가방에 그 물품이 없습니다.'; END IF;
    inv := public.world_inv_add(inv, it, -1);
    IF it = 'ward_talisman' THEN
      mn := least(100, mn + 8);
      DELETE FROM public.world_character_statuses WHERE owner_id = uid AND status_key IN ('erosion_whisper', 'shaken', 'poisoned');
      IF (v_fx ->> 'barrier') IS NOT NULL THEN v_fx := v_fx - 'barrier'; END IF;
      lines := lines || jsonb_build_array('정화 부적을 태워 사기를 걷어냈다. 정신 +8');
    ELSE
      heal := CASE it WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 ELSE 12 END;
      IF c.job_key = 'medic' THEN heal := round(heal * 1.4); END IF;
      heal := round(heal * (1 + public.world_status_effect_total('healing_pct') / 100.0));
      hp := least(100, hp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 체력 ' || heal || ' 회복');
    END IF;
  ELSIF act = 'skill' AND c.job_key = 'medic' THEN
    heal := least(60, 25 + c.vitality + c.willpower / 2); hp := least(100, hp + heal);
    DELETE FROM public.world_character_statuses WHERE status_id = (SELECT cs.status_id FROM public.world_character_statuses cs JOIN public.world_status_catalog sc USING (status_key)
      WHERE cs.owner_id = uid AND sc.polarity = 'negative' ORDER BY cs.expires_at LIMIT 1);
    lines := lines || jsonb_build_array('응급 처방: 체력 ' || heal || ' 회복, 나쁜 상태 하나를 걷어냈다.');
  ELSIF act = 'skill' AND c.job_key = 'analyst' THEN
    v_pfx := v_pfx || jsonb_build_object('focus', 3);
    lines := lines || jsonb_build_array('약점 간파: ' || m.monster_name || '의 빈틈을 읽었다. 다음 세 번의 공격이 강해진다.');
  ELSE
    -- 공격(기본 공격 또는 공격 기술)
    IF act = 'skill' AND c.job_key = 'exorcist' THEN style := 'magic'; skill_name := '퇴마진';
    ELSIF act = 'skill' AND c.job_key = 'scout' THEN style := 'ranged'; skill_name := '급소 사격';
    ELSIF act = 'skill' AND c.job_key = 'sealmaster' THEN skill_name := '봉인술';
    ELSIF act = 'skill' AND c.job_key = 'artificer' THEN skill_name := '폭렬 부적';
    END IF;
    base := CASE style
      WHEN 'ranged' THEN 6 + c.agility * 0.9 + c.perception * 0.7 + wpow * 1.5 + c.level * 0.8
      WHEN 'magic' THEN 6 + c.spirit_affinity * 1.1 + c.willpower * 0.6 + wpow * 1.5 + c.level * 0.8
      ELSE 8 + c.strength * 1.5 + wpow * 1.6 + c.level * 0.8 END;
    IF style = 'magic' AND act = 'attack' THEN
      IF sp >= 3 THEN sp := sp - 3; ELSE base := base * 0.5; lines := lines || jsonb_build_array('영력이 바닥나 술법이 약해졌다.'); END IF;
    END IF;
    mul := (0.85 + random() * 0.3) * (1 + coalesce(c.combat_rank, 1) * 0.015);
    mul := mul * CASE coalesce(m.mechanic_key, '')
      WHEN 'aerial' THEN CASE style WHEN 'melee' THEN 0.6 WHEN 'ranged' THEN 1.35 ELSE 1 END
      WHEN 'armored' THEN CASE style WHEN 'melee' THEN 0.85 WHEN 'ranged' THEN 0.7 ELSE 1.25 END
      WHEN 'spectral' THEN CASE style WHEN 'melee' THEN 0.6 WHEN 'ranged' THEN 0.8 ELSE 1.4 END
      WHEN 'warded' THEN CASE style WHEN 'melee' THEN 1.1 WHEN 'ranged' THEN 1 ELSE 0.8 END
      WHEN 'reflect' THEN CASE style WHEN 'melee' THEN 1 WHEN 'ranged' THEN 1.15 ELSE 0.7 END
      WHEN 'swarm' THEN CASE style WHEN 'melee' THEN 1.25 WHEN 'ranged' THEN 0.9 ELSE 1.1 END
      WHEN 'toxic' THEN CASE style WHEN 'melee' THEN 0.9 WHEN 'ranged' THEN 1.15 ELSE 1 END
      WHEN 'tide' THEN CASE style WHEN 'melee' THEN 1 WHEN 'ranged' THEN 0.9 ELSE 1.15 END
      WHEN 'seal_breaker' THEN CASE style WHEN 'melee' THEN 1.1 WHEN 'ranged' THEN 1 ELSE 0.85 END
      ELSE 1 END;
    IF c.mental < 20 THEN mul := mul * 0.7; ELSIF c.mental < 40 THEN mul := mul * 0.85; END IF;
    IF c.erosion >= 80 THEN mul := mul * 0.7; ELSIF c.erosion >= 55 THEN mul := mul * 0.8; ELSIF c.erosion >= 30 THEN mul := mul * 0.9; END IF;
    mul := mul * (1 + (public.world_status_effect_total('combat_damage_pct') + public.world_title_bonus('combat_damage_pct') + wbonus) / 100.0);
    IF coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN mul := mul * 1.4; v_pfx := v_pfx || jsonb_build_object('focus', (v_pfx ->> 'focus')::int - 1); END IF;
    IF coalesce((v_fx ->> 'marked')::int, 0) > 0 THEN mul := mul * 1.25; v_fx := v_fx || jsonb_build_object('marked', (v_fx ->> 'marked')::int - 1); END IF;
    IF coalesce((v_fx ->> 'airborne')::boolean, false) THEN
      mul := mul * CASE style WHEN 'melee' THEN 0.4 WHEN 'ranged' THEN 1.2 ELSE 0.9 END;
    END IF;
    IF skill_name = '퇴마진' THEN mul := mul * 2.0; v_fx := v_fx - 'barrier';
    ELSIF skill_name = '급소 사격' THEN mul := mul * 1.8; v_fx := v_fx || jsonb_build_object('marked', 2);
    ELSIF skill_name = '폭렬 부적' THEN mul := mul * 1.7;
    ELSIF skill_name = '봉인술' THEN mul := mul * 1.1;
    END IF;
    cc := least(0.45, 0.05 + c.perception * 0.004 + CASE WHEN style = 'ranged' THEN 0.08 ELSE 0 END + CASE WHEN c.job_key = 'analyst' THEN 0.08 ELSE 0 END
          + CASE WHEN coalesce((v_pfx ->> 'focus')::int, -1) >= 0 AND (v_pfx ? 'focus') THEN 0.1 ELSE 0 END);
    crit := skill_name = '급소 사격' OR random() < cc;
    IF crit AND skill_name IS DISTINCT FROM '급소 사격' THEN mul := mul * 1.6; END IF;
    mdef := a.def;
    IF coalesce((v_fx ->> 'harden')::int, 0) > 0 AND style IN ('melee', 'ranged') AND skill_name IS DISTINCT FROM '폭렬 부적' THEN mdef := mdef * 3; END IF;
    v_fx := v_fx - 'harden';
    IF skill_name = '폭렬 부적' THEN mdef := 0; END IF;
    dmg := greatest(1, round(base * mul - mdef * 0.8));
    shield := coalesce((v_fx ->> 'barrier')::int, 0);
    IF shield > 0 AND skill_name IS DISTINCT FROM '폭렬 부적' THEN
      IF style = 'magic' THEN shield := shield - dmg * 2; ELSE shield := shield - dmg; END IF;
      IF shield > 0 THEN v_fx := v_fx || jsonb_build_object('barrier', shield); lines := lines || jsonb_build_array('결계가 공격을 삼켰다.'); dmg := 0;
      ELSE v_fx := v_fx - 'barrier'; dmg := greatest(1, -shield / CASE WHEN style = 'magic' THEN 2 ELSE 1 END); lines := lines || jsonb_build_array('결계가 깨졌다.'); END IF;
    END IF;
    IF coalesce((v_fx ->> 'mirror')::int, 0) > 0 AND style = 'magic' AND dmg > 0 THEN
      reflect := round(dmg * 0.5); v_fx := v_fx - 'mirror';
    END IF;
    a.current_hp := greatest(0, a.current_hp - dmg);
    lines := lines || jsonb_build_array(coalesce(skill_name, CASE style WHEN 'ranged' THEN '사격' WHEN 'magic' THEN '술법' ELSE '베기' END) || ': ' || dmg || ' 피해'
      || CASE WHEN crit THEN ' (치명타)' ELSE '' END);
    IF reflect > 0 THEN hp := greatest(0, hp - reflect); lines := lines || jsonb_build_array('거울막이 술법을 되돌려 ' || reflect || ' 피해를 입었다.'); END IF;
    IF skill_name = '봉인술' THEN
      IF a.rank = 'guardian' AND random() < 0.5 THEN lines := lines || jsonb_build_array('우두머리가 봉인을 떨쳐냈다.');
      ELSE v_fx := v_fx || jsonb_build_object('stunned', 1); lines := lines || jsonb_build_array(m.monster_name || '의 움직임을 봉했다.'); END IF;
    END IF;
  END IF;

  -- ② 결판
  IF a.current_hp <= 0 THEN
    ended := 'victory';
  ELSIF fled THEN
    ended := 'fled';
  ELSE
    -- ③ 요괴의 행동(예고한 대로)
    IF coalesce((v_fx ->> 'stunned')::int, 0) > 0 THEN
      skip_monster := true; v_fx := v_fx - 'stunned';
      lines := lines || jsonb_build_array(m.monster_name || '이(가) 봉인에 묶여 움직이지 못했다.');
      next_intent := public.world_battle_intent(m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank);
    END IF;
    IF NOT skip_monster THEN
      hit := a.atk * (0.9 + random() * 0.2);
      IF coalesce((v_fx ->> 'swarm')::int, 0) > 0 AND v_intent IN ('strike', 'heavy') THEN hit := hit * 1.3; v_fx := v_fx - 'swarm'; END IF;
      hit := hit * CASE v_intent WHEN 'strike' THEN 1 WHEN 'heavy' THEN 1.9 WHEN 'dive' THEN 1.7 WHEN 'pounce' THEN 2.0 WHEN 'unleash' THEN 2.6
        WHEN 'harden' THEN 0.5 WHEN 'wail' THEN 0.6 WHEN 'venom' THEN 0.6 WHEN 'mirror' THEN 0.4 WHEN 'tide' THEN 0.8 WHEN 'barrier' THEN 0.3
        WHEN 'breach' THEN 0.7 ELSE 0 END;
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
        defv := c.vitality * 0.8 + armor_def + c.level * 0.5;
        mdmg := round(hit * 100.0 / (100 + defv * 3));
        IF guarding THEN mdmg := round(mdmg * CASE WHEN v_intent IN ('heavy', 'dive', 'pounce', 'unleash') THEN 0.25 ELSE 0.35 END); END IF;
        mdmg := round(mdmg * (1 + public.world_status_effect_total('incoming_damage_pct') / 100.0) * (1 - dr_pct / 100.0));
        IF c.health < 30 THEN mdmg := ceil(mdmg * 1.15); END IF;
        IF c.job_key = 'scout' AND NOT guarding AND random() < least(0.3, 0.06 + c.agility * 0.008) THEN
          mdmg := 0; lines := lines || jsonb_build_array('몸을 틀어 공격을 피했다.');
        END IF;
        mdmg := greatest(0, mdmg);
        hp := greatest(0, hp - mdmg);
        IF mdmg > 0 THEN
          lines := lines || jsonb_build_array(m.monster_name || CASE v_intent WHEN 'heavy' THEN '의 강타' WHEN 'dive' THEN '의 급강하' WHEN 'pounce' THEN '의 기습'
            WHEN 'unleash' THEN '의 폭발' WHEN 'venom' THEN '의 독 분사' WHEN 'wail' THEN '의 곡성' WHEN 'tide' THEN '의 물살' WHEN 'breach' THEN '의 봉인 깨기' ELSE '의 공격' END
            || ': ' || mdmg || ' 피해' || CASE WHEN guarding THEN ' (막음)' ELSE '' END);
          IF guarding AND v_intent IN ('heavy', 'dive', 'pounce', 'unleash') AND style = 'melee' THEN
            dmg := round(mdmg * 1.2 + c.strength * 0.5); a.current_hp := greatest(0, a.current_hp - dmg);
            lines := lines || jsonb_build_array('받아치기: ' || dmg || ' 피해');
          END IF;
        END IF;
        IF v_intent = 'wail' THEN mn := greatest(0, mn - 6); IF random() < 0.35 THEN statuses := array_append(statuses, 'shaken'); END IF; END IF;
        IF v_intent = 'venom' AND random() < 0.45 THEN statuses := array_append(statuses, 'poisoned'); END IF;
        IF v_intent = 'tide' AND random() < 0.3 THEN statuses := array_append(statuses, 'cold'); END IF;
        IF v_intent = 'breach' THEN er := least(100, er + 4); END IF;
        IF v_intent IN ('heavy', 'pounce') AND NOT guarding AND random() < 0.2 THEN statuses := array_append(statuses, 'bleeding'); END IF;
      END IF;
    END IF;
    IF a.current_hp <= 0 THEN ended := 'victory'; END IF;
    IF ended IS NULL AND hp <= 0 THEN
      IF coalesce((inv ->> 'revival_charm')::int, 0) > 0 AND NOT coalesce((v_pfx ->> 'revived')::boolean, false) THEN
        inv := public.world_inv_add(inv, 'revival_charm', -1); hp := 30; v_pfx := v_pfx || jsonb_build_object('revived', true);
        lines := lines || jsonb_build_array('쓰러지는 순간 회생 부적이 타올라 다시 일어섰다.');
      ELSE
        ended := 'defeat';
      END IF;
    END IF;
    IF ended IS NULL THEN
      next_intent := coalesce(next_intent, public.world_battle_intent(m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank));
    END IF;
  END IF;

  FOREACH k IN ARRAY statuses LOOP PERFORM public.world_field_status(uid, k, 'combat'); END LOOP;

  -- ④ 정리
  IF ended = 'victory' THEN
    rk_mul := CASE a.rank WHEN 'elite' THEN 1.8 WHEN 'guardian' THEN 3 ELSE 1 END;
    xp := round((12 + a.mlevel * 6) * rk_mul * CASE WHEN a.mlevel < c.level - 5 THEN 0.3 ELSE 1 END);
    gil_gain := round((2 + a.mlevel) * rk_mul);
    drop_p := CASE a.rank WHEN 'elite' THEN 0.8 WHEN 'guardian' THEN 1 ELSE 0.6 END;
    FOR k, v IN SELECT d.key, CASE WHEN jsonb_typeof(d.value) = 'number' THEN d.value::text::int ELSE 1 END FROM jsonb_each(coalesce(m.drops, '{}'::jsonb)) d LOOP
      IF EXISTS (SELECT 1 FROM public.world_item_catalog ic WHERE ic.item_id = k) AND random() < drop_p THEN
        qty := greatest(1, 1 + floor(random() * greatest(1, v))::int) * CASE WHEN a.rank = 'guardian' THEN 2 ELSE 1 END;
        loot := public.world_inv_add(loot, k, qty);
      END IF;
    END LOOP;
    IF random() < 0.25 THEN
      SELECT x INTO sig FROM public.world_region_profiles p, unnest(p.signature_items) x JOIN public.world_item_catalog ic ON ic.item_id = x
        WHERE p.region_id = a.region_id AND ic.tier <= 2 AND x NOT IN ('courier_token', 'spirit_compass') ORDER BY random() LIMIT 1;
      IF sig IS NOT NULL THEN loot := public.world_inv_add(loot, sig, 1); END IF;
    END IF;
    IF a.rank <> 'normal' AND random() < CASE a.rank WHEN 'guardian' THEN 1 ELSE 0.3 END THEN loot := public.world_inv_add(loot, 'monster_core', 1); END IF;
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

  UPDATE public.world_characters SET health = hp, mental = mn, spiritual_power = sp, erosion = er,
    erosion_stage = CASE WHEN er >= 80 THEN 4 WHEN er >= 55 THEN 3 WHEN er >= 30 THEN 2 WHEN er >= 10 THEN 1 ELSE 0 END,
    inventory = inv, gil = gil + gil_gain, experience = experience + greatest(0, xp), updated_at = now()
  WHERE owner_id = uid;

  UPDATE public.world_active_encounters SET current_hp = a.current_hp, turn_count = turn, fx = v_fx, pfx = v_pfx,
    intent = CASE WHEN ended IS NULL THEN next_intent ELSE v_intent END,
    defeated = ended = 'victory', fled = ended IN ('fled', 'defeat'), result = v_result,
    log = (SELECT coalesce(jsonb_agg(x ORDER BY o), '[]'::jsonb) FROM (SELECT x, o FROM jsonb_array_elements(a.log || lines) WITH ORDINALITY t(x, o) ORDER BY o DESC LIMIT 14) s),
    last_action_at = now(), updated_at = now()
  WHERE owner_id = uid;

  IF ended = 'victory' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'combat', m.monster_name || ' 토벌' || CASE a.rank WHEN 'elite' THEN '(정예)' WHEN 'guardian' THEN '(우두머리)' ELSE '' END,
      jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id, 'monster_name', m.monster_name, 'defeated', true,
        'mechanic', m.mechanic_key, 'action', CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'seal' ELSE 'attack' END,
        'rank', a.rank, 'level', a.mlevel, 'loot', loot, 'turns', turn));
  ELSIF ended = 'defeat' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'battle_lost', m.monster_name || '에게 쓰러졌습니다.', jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id));
  ELSIF ended = 'fled' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'battle_fled', m.monster_name || '에게서 달아났습니다.', jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id));
  END IF;

  RETURN jsonb_build_object('ok', true, 'lines', lines, 'ended', ended, 'result', v_result, 'damage', dmg, 'taken', mdmg, 'heal', heal,
    'crit', crit, 'health', hp, 'battle', public.world_field_battle_view(uid), 'next_action_at', now() + interval '2 seconds');
END $f$;

RESET ROLE;
