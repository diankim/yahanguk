GRANT SELECT ON public.world_expedition_grounds TO fn_owner_field;

-- 상태판·경로 이동·원정·물품·사진·캐릭터 정리·시신·구조대·야영·전문화 (postgres로 만든 뒤 fn_owner_field 소유로 넘긴다)

-- ── 상태판: 탐색력·전투·원정·상태이상(치료법 포함)·보급·사망 시한 ─────────────
CREATE OR REPLACE FUNCTION public.world_hud_snapshot()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; st int; mx int;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  PERFORM public.world_death_sweep();
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid;
  IF NOT FOUND THEN RETURN NULL; END IF;
  DELETE FROM public.world_character_statuses WHERE owner_id = uid AND expires_at <= now();
  st := public.world_stamina_now(c.stamina, c.stamina_at, c.level); mx := public.world_stamina_max(c.level);
  RETURN jsonb_build_object(
    'stamina', jsonb_build_object('now', st, 'max', mx,
      'next_at', CASE WHEN st >= mx THEN NULL ELSE c.stamina_at + make_interval(secs => (floor(greatest(0, extract(epoch FROM now() - c.stamina_at)) / 360)::int + 1) * 360) END),
    'battle', public.world_field_battle_view(uid),
    'expedition', (SELECT jsonb_build_object('expedition_id', e.expedition_id, 'place_name', coalesce(n.node_name, g.ground_name), 'region_name', r.region_name,
        'minutes', e.minutes, 'stance', e.stance, 'supplies', e.supplies, 'started_at', e.started_at, 'ends_at', e.ends_at)
      FROM public.world_expeditions e LEFT JOIN public.world_exploration_nodes n ON n.node_id = e.node_id
      LEFT JOIN public.world_expedition_grounds g ON g.ground_id = e.ground_id LEFT JOIN public.world_map_regions r ON r.region_id = e.region_id
      WHERE e.owner_id = uid AND e.status = 'active' LIMIT 1),
    'statuses', (SELECT coalesce(jsonb_agg(jsonb_build_object('key', s.status_key, 'name', k.status_name, 'polarity', k.polarity, 'description', k.description,
        'effects', k.effects, 'potency', s.potency, 'stacks', s.stacks, 'expires_at', s.expires_at, 'cure', k.cure, 'cure_items', k.cure_items)
        ORDER BY (k.polarity = 'positive'), s.expires_at), '[]'::jsonb)
      FROM public.world_character_statuses s JOIN public.world_status_catalog k USING (status_key) WHERE s.owner_id = uid),
    'supply', jsonb_build_object('claimed_today', EXISTS (SELECT 1 FROM public.world_faction_supply_claims x WHERE x.owner_id = uid AND x.supply_date = current_date),
      'next_at', (current_date + 1)::timestamptz),
    'death_at', CASE WHEN c.downed_at IS NOT NULL AND NOT c.is_dead THEN c.downed_at + interval '4 hours' END);
END $f$;

-- ── 경로 이동: 이어진 길을 따라 여러 지역을 한 번에 간다. 도착 알림은 마지막 한 번만 ─────────
CREATE OR REPLACE FUNCTION public.world_travel_route(p_region_id text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; here public.world_map_regions%rowtype; dest public.world_map_regions%rowtype;
  ids text[]; xs float8[]; ys float8[]; el float8[]; tc float8[]; terr text[]; lv int[]; lk jsonb[]; d float8[]; prv int[]; done boolean[];
  nn int; i int; u int; v int; best float8; si int; ti int; w float8; speed float8 := 1; path int[] := '{}'; secs float8 := 0; hop float8;
  vis int; arrives timestamptz; fee int; names text[] := '{}'; nb text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태에서는 움직일 수 없습니다.'; END IF;
  IF c.travel_arrives_at IS NOT NULL AND c.travel_arrives_at > now() THEN RAISE EXCEPTION '이미 이동 중입니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = uid AND NOT a.defeated AND NOT coalesce(a.fled, false)) THEN
    RAISE EXCEPTION '전투 중에는 이동할 수 없습니다. 도주하거나 전투를 마치세요.'; END IF;
  here := public.world_field_region(c.location);
  SELECT * INTO dest FROM public.world_map_regions WHERE region_id = p_region_id AND active;
  IF dest.region_id IS NULL THEN RAISE EXCEPTION '지도에 없는 지역입니다.'; END IF;
  IF here.region_id IS NULL THEN RAISE EXCEPTION '지금 있는 곳의 좌표를 알 수 없습니다.'; END IF;
  IF here.region_id = dest.region_id THEN RAISE EXCEPTION '이미 그 지역에 있습니다.'; END IF;
  IF c.level < dest.min_level THEN RAISE EXCEPTION '%', format('레벨 %s부터 들어갈 수 있는 지역입니다.', dest.min_level); END IF;

  SELECT array_agg(region_id ORDER BY region_id), array_agg(world_x::float8 ORDER BY region_id), array_agg(world_y::float8 ORDER BY region_id),
         array_agg(coalesce(elevation, 0)::float8 ORDER BY region_id), array_agg(coalesce(terrain_cost, 1)::float8 ORDER BY region_id),
         array_agg(territory_id ORDER BY region_id), array_agg(min_level ORDER BY region_id), array_agg(to_jsonb(coalesce(travel_from, '{}')) ORDER BY region_id)
    INTO ids, xs, ys, el, tc, terr, lv, lk FROM public.world_map_regions WHERE active;
  nn := cardinality(ids);
  si := array_position(ids, here.region_id); ti := array_position(ids, dest.region_id);
  d := array_fill(1e18::float8, ARRAY[nn]); prv := array_fill(0, ARRAY[nn]); done := array_fill(false, ARRAY[nn]);
  d[si] := 0;
  SELECT coalesce(m.speed_multiplier, 1) INTO speed FROM public.world_mount_catalog m WHERE m.mount_id = c.mount_id;
  speed := coalesce(speed, 1);
  LOOP
    u := NULL; best := 1e18;
    FOR i IN 1..nn LOOP IF NOT done[i] AND d[i] < best THEN best := d[i]; u := i; END IF; END LOOP;
    EXIT WHEN u IS NULL OR u = ti;
    done[u] := true;
    FOR nb IN SELECT jsonb_array_elements_text(lk[u]) LOOP
      v := array_position(ids, nb);
      CONTINUE WHEN v IS NULL OR done[v] OR (lv[v] > c.level);
      w := (sqrt((xs[u] - xs[v]) ^ 2 + (ys[u] - ys[v]) ^ 2) * 1.4 + abs(el[u] - el[v]) * 6 + 12) * greatest(tc[u], tc[v])
           * CASE WHEN terr[u] IS DISTINCT FROM terr[v] THEN 1.2 ELSE 1 END;
      IF d[u] + w < d[v] THEN d[v] := d[u] + w; prv[v] := u; END IF;
    END LOOP;
  END LOOP;
  IF d[ti] >= 1e17 THEN RAISE EXCEPTION '그곳으로 이어진 길이 없습니다. 레벨이 모자란 지역이 길을 막고 있습니다.'; END IF;
  v := ti;
  WHILE v <> si LOOP path := v || path; v := prv[v]; END LOOP;
  path := si || path;
  FOR i IN 2..cardinality(path) LOOP
    hop := (sqrt((xs[path[i - 1]] - xs[path[i]]) ^ 2 + (ys[path[i - 1]] - ys[path[i]]) ^ 2) * 1.4 + abs(el[path[i - 1]] - el[path[i]]) * 6 + 12)
           * greatest(tc[path[i - 1]], tc[path[i]]) * CASE WHEN terr[path[i - 1]] IS DISTINCT FROM terr[path[i]] THEN 1.2 ELSE 1 END / speed;
    SELECT coalesce(visits, 0) INTO vis FROM public.world_region_intel WHERE owner_id = uid AND region_id = ids[path[i]];
    hop := hop * (1 - least(0.3, coalesce(vis, 0) * 0.06));
    secs := secs + greatest(12, hop);
    names := names || (SELECT region_name FROM public.world_map_regions WHERE region_id = ids[path[i]]);
  END LOOP;
  IF cardinality(path) > 2 THEN secs := secs * 0.9; END IF;
  secs := secs * (1 + public.world_status_effect_total('travel_time_pct') / 100.0 + least(0, public.world_title_bonus('travel_time_pct')) / 100.0);
  secs := greatest(12, least(10800, secs));
  fee := 5 * (cardinality(path) - 1);
  IF c.gil < fee THEN RAISE EXCEPTION '%', format('여행 준비금 %s전이 필요합니다.', fee); END IF;
  arrives := now() + make_interval(secs => round(secs));
  UPDATE public.world_characters SET gil = gil - fee, travel_destination = dest.region_name, travel_arrives_at = arrives,
    current_exploration_node_id = NULL, updated_at = now() WHERE owner_id = uid;
  INSERT INTO public.world_travel_history(owner_id, from_region, to_region, arrives_at) VALUES (uid, c.location, dest.region_name, arrives);
  INSERT INTO public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  VALUES (uid, 'travel_fee', -fee, true, jsonb_build_object('to', dest.region_id, 'hops', cardinality(path) - 1, 'seconds', round(secs)));
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'travel', '출발: ' || dest.region_name || CASE WHEN cardinality(path) > 2 THEN ' (' || (cardinality(path) - 1) || '구간)' ELSE '' END,
    jsonb_build_object('region_id', dest.region_id, 'region_name', dest.region_name, 'arrives_at', arrives, 'travel_seconds', round(secs), 'route', to_jsonb(names), 'mount', c.mount_id));
  RETURN jsonb_build_object('ok', true, 'content', dest.region_name || '(으)로 출발했습니다. ' || CASE WHEN cardinality(path) > 2 THEN array_to_string(names, ' › ') || ' · ' ELSE '' END
      || '약 ' || CASE WHEN secs >= 3600 THEN floor(secs / 3600) || '시간 ' ELSE '' END || ceil(mod(secs::numeric, 3600) / 60) || '분 뒤 도착합니다.',
    'route', to_jsonb(names), 'arrives_at', arrives, 'seconds', round(secs), 'fee', fee);
END $f$;

-- ── 원정: 찾아낸 세부 지역으로 보낸다. 보급품은 가방에서 자동으로 챙긴다 ─────────
CREATE OR REPLACE FUNCTION public.world_expedition_overview()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  r := public.world_field_region(c.location);
  RETURN jsonb_build_object(
    'region_id', r.region_id, 'region_name', r.region_name, 'safe', r.is_safe_zone,
    'survey', CASE WHEN r.region_id IS NOT NULL THEN public.world_field_survey(uid, r.region_id) END,
    'active', (SELECT jsonb_build_object('expedition_id', e.expedition_id, 'place_name', coalesce(n.node_name, g.ground_name), 'region_name', rr.region_name,
        'minutes', e.minutes, 'stance', e.stance, 'supplies', e.supplies, 'started_at', e.started_at, 'ends_at', e.ends_at)
      FROM public.world_expeditions e LEFT JOIN public.world_exploration_nodes n ON n.node_id = e.node_id
      LEFT JOIN public.world_expedition_grounds g ON g.ground_id = e.ground_id LEFT JOIN public.world_map_regions rr ON rr.region_id = e.region_id
      WHERE e.owner_id = uid AND e.status = 'active' LIMIT 1),
    'options', CASE WHEN r.is_safe_zone THEN '[]'::jsonb ELSE (SELECT coalesce(jsonb_agg(jsonb_build_object('node_id', n.node_id, 'name', n.node_name,
        'depth', n.hierarchy_level - 1, 'min_level', n.min_level, 'danger', r.danger_level + n.hierarchy_level - 2, 'locked', c.level < n.min_level)
        ORDER BY n.hierarchy_level, n.node_name), '[]'::jsonb)
      FROM public.world_exploration_nodes n JOIN public.world_exploration_discoveries d ON d.node_id = n.node_id AND d.owner_id = uid
      WHERE n.region_id = r.region_id AND n.hierarchy_level >= 2) END,
    'supplies', (SELECT coalesce(jsonb_object_agg(k, least(20, (c.inventory ->> k)::int)), '{}'::jsonb)
      FROM unnest(ARRAY['tonic', 'herbal_extract', 'herb', 'ward_talisman', 'seal_paper', 'revival_charm', 'travel_ration']) k
      WHERE coalesce((c.inventory ->> k)::int, 0) > 0),
    'recent', (SELECT coalesce(jsonb_agg(x ORDER BY (x ->> 'finished_at') DESC), '[]'::jsonb) FROM (
      SELECT jsonb_build_object('place_name', coalesce(n.node_name, g.ground_name), 'minutes', e.minutes, 'stance', e.stance, 'result', e.result,
        'started_at', e.started_at, 'finished_at', e.finished_at) x
      FROM public.world_expeditions e LEFT JOIN public.world_exploration_nodes n ON n.node_id = e.node_id LEFT JOIN public.world_expedition_grounds g ON g.ground_id = e.ground_id
      WHERE e.owner_id = uid AND e.status = 'done' ORDER BY e.finished_at DESC LIMIT 10) q));
END $f$;

CREATE OR REPLACE FUNCTION public.world_expedition_start(p_node_id uuid, p_minutes integer, p_stance text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; n public.world_exploration_nodes%rowtype;
  inv jsonb; sup jsonb := '{}'::jsonb; k text; q int; ends timestamptz;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_minutes IS NULL OR p_minutes NOT IN (30, 60, 120, 240, 480) THEN RAISE EXCEPTION '원정 기간을 고르세요.'; END IF;
  IF p_stance IS NULL OR p_stance NOT IN ('cautious', 'balanced', 'bold') THEN RAISE EXCEPTION '원정 태세를 고르세요.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.health <= 0 OR c.downed_at IS NOT NULL THEN RAISE EXCEPTION '전투불능 상태에서는 원정을 떠날 수 없습니다.'; END IF;
  IF c.travel_arrives_at IS NOT NULL AND c.travel_arrives_at > now() THEN RAISE EXCEPTION '이동 중에는 원정을 떠날 수 없습니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_expeditions WHERE owner_id = uid AND status = 'active') THEN RAISE EXCEPTION '이미 원정 중입니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = uid AND NOT a.defeated AND NOT coalesce(a.fled, false)) THEN RAISE EXCEPTION '전투 중에는 원정을 떠날 수 없습니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_idle_activities i WHERE i.owner_id = uid AND i.status = 'active') THEN RAISE EXCEPTION '자율 활동을 마친 뒤 원정을 떠나세요.'; END IF;
  r := public.world_field_region(c.location);
  IF r.region_id IS NULL OR r.is_safe_zone THEN RAISE EXCEPTION '안전지대에서는 원정을 떠날 수 없습니다.'; END IF;
  SELECT * INTO n FROM public.world_exploration_nodes WHERE node_id = p_node_id AND region_id = r.region_id AND hierarchy_level >= 2;
  IF NOT FOUND THEN RAISE EXCEPTION '지금 있는 지역의 장소를 고르세요.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.world_exploration_discoveries d WHERE d.owner_id = uid AND d.node_id = n.node_id) THEN RAISE EXCEPTION '아직 찾지 못한 곳입니다.'; END IF;
  IF c.level < n.min_level THEN RAISE EXCEPTION '%', format('레벨 %s부터 갈 수 있는 곳입니다.', n.min_level); END IF;
  inv := coalesce(c.inventory, '{}'::jsonb);
  FOREACH k IN ARRAY ARRAY['tonic', 'herbal_extract', 'herb', 'ward_talisman', 'seal_paper', 'revival_charm', 'travel_ration'] LOOP
    q := least(20, coalesce((inv ->> k)::int, 0));
    IF q > 0 THEN sup := sup || jsonb_build_object(k, q); inv := public.world_inv_add(inv, k, -q); END IF;
  END LOOP;
  ends := now() + make_interval(mins => p_minutes);
  UPDATE public.world_characters SET inventory = inv, current_exploration_node_id = n.node_id, updated_at = now() WHERE owner_id = uid;
  INSERT INTO public.world_expeditions(owner_id, node_id, region_id, minutes, stance, supplies, ends_at)
  VALUES (uid, n.node_id, r.region_id, p_minutes, p_stance, sup, ends);
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'expedition_start', n.node_name || '(으)로 원정을 떠났습니다.',
    jsonb_build_object('node_id', n.node_id, 'region_id', r.region_id, 'minutes', p_minutes, 'stance', p_stance, 'supplies', sup));
  RETURN jsonb_build_object('ok', true, 'ends_at', ends, 'content', n.node_name || '(으)로 원정을 떠났습니다. 보급품을 챙겨 ' || p_minutes || '분 뒤에 돌아옵니다.');
END $f$;

CREATE OR REPLACE FUNCTION public.world_expedition_complete(p_recall boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE
  uid uuid := public.fn_owner_auth_uid();
  e public.world_expeditions%rowtype; c public.world_characters%rowtype; n public.world_exploration_nodes%rowtype;
  r public.world_map_regions%rowtype; m public.world_region_monsters%rowtype;
  total_rounds int; rounds int; i int; roll float8; win_p float8; depth int; danger int;
  sup jsonb; loot jsonb := '{}'::jsonb; log jsonb := '[]'::jsonb;
  hp int; mn int; er int; prog_before int; prog_after int;
  wins int := 0; losses int := 0; gathers int := 0; finds int := 0; hazards int := 0; discovered int := 0;
  xp int := 0; cxp int := 0; gxp int := 0; ixp int := 0; gil_gain int := 0;
  wt int := 0; at int := 0; tt int := 0; power float8; defense float8; threat float8; dmg int; heal int;
  p_fight float8; dmg_mul float8; loot_mul float8; disc_mul float8; heal_at int;
  item text; qty int; pool text[]; rare_pool text[]; ended text := 'complete';
  spirit_mech boolean; rations_need int; rations_short int := 0; gained int := 0;
  inv jsonb; used int; cap int; lost jsonb := '{}'::jsonb; k text; q int; space int;
  ms_list text[]; new_ms text[] := '{}'; fully int; mount_gift text; found_node uuid; found_spot uuid; nm text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO e FROM public.world_expeditions WHERE owner_id = uid AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '진행 중인 원정이 없습니다.'; END IF;
  IF now() < e.ends_at AND NOT coalesce(p_recall, false) THEN RAISE EXCEPTION '아직 원정이 끝나지 않았습니다. 일찍 돌아오려면 귀환을 고르세요.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  SELECT * INTO r FROM public.world_map_regions WHERE region_id = e.region_id;
  SELECT * INTO n FROM public.world_exploration_nodes WHERE node_id = e.node_id;
  IF n.node_id IS NULL THEN SELECT * INTO n FROM public.world_exploration_nodes WHERE region_id = e.region_id AND hierarchy_level = 2 LIMIT 1; END IF;
  depth := greatest(1, least(3, n.hierarchy_level - 1));
  danger := r.danger_level + n.hierarchy_level - 2;
  nm := n.node_name;

  total_rounds := CASE e.minutes WHEN 30 THEN 3 WHEN 60 THEN 6 WHEN 120 THEN 10 WHEN 240 THEN 16 ELSE 24 END;
  rounds := CASE WHEN now() >= e.ends_at THEN total_rounds ELSE floor(total_rounds * extract(epoch FROM now() - e.started_at) / (e.minutes * 60.0))::int END;
  rounds := greatest(0, least(total_rounds, rounds));
  IF rounds < total_rounds THEN ended := 'recalled'; END IF;

  SELECT coalesce(max(CASE WHEN eq.slot = 'weapon' THEN i.tier END), 0), coalesce(max(CASE WHEN eq.slot = 'armor' THEN i.tier END), 0),
         coalesce(max(CASE WHEN eq.slot = 'tool' THEN i.tier END), 0)
  INTO wt, at, tt FROM public.world_character_equipment eq JOIN public.world_item_catalog i ON i.item_id = eq.item_id WHERE eq.owner_id = uid;

  power := 12 + c.level * 5 + c.strength * 2.5 + c.agility * 1.5 + c.perception + wt * 14 + coalesce(c.combat_rank, 1) * 3;
  IF c.job_key = 'exorcist' THEN power := power * 1.12; END IF;
  defense := c.level * 2 + c.vitality * 3 + at * 12;
  IF c.major_faction_id = 'north_league' THEN defense := defense * 1.2; END IF;
  p_fight := CASE e.stance WHEN 'cautious' THEN 0.22 WHEN 'bold' THEN 0.5 ELSE 0.35 END + danger * 0.012;
  dmg_mul := CASE e.stance WHEN 'cautious' THEN 0.7 WHEN 'bold' THEN 1.3 ELSE 1.0 END;
  loot_mul := CASE e.stance WHEN 'cautious' THEN 0.8 WHEN 'bold' THEN 1.3 ELSE 1.0 END * (1 + (depth - 1) * 0.15);
  IF c.major_faction_id = 'red_moon_cult' AND e.stance = 'bold' THEN loot_mul := loot_mul * 1.15; END IF;
  disc_mul := CASE e.stance WHEN 'cautious' THEN 0.85 WHEN 'bold' THEN 1.2 ELSE 1.0 END;
  IF c.job_key = 'scout' THEN disc_mul := disc_mul * 1.2; END IF;
  IF c.major_faction_id = 'mandate_court' THEN disc_mul := disc_mul * 1.2; END IF;
  heal_at := CASE e.stance WHEN 'cautious' THEN 60 WHEN 'bold' THEN 30 ELSE 45 END;

  pool := ARRAY(SELECT DISTINCT x FROM public.world_gathering_spots s JOIN public.world_exploration_nodes y ON y.node_id = s.node_id, unnest(s.loot_items) x
                WHERE y.region_id = r.region_id AND y.hierarchy_level <= n.hierarchy_level + 1);
  rare_pool := ARRAY(SELECT x FROM public.world_region_profiles p, unnest(p.signature_items) x JOIN public.world_item_catalog ic ON ic.item_id = x
                     WHERE p.region_id = r.region_id AND x NOT IN ('courier_token', 'spirit_compass'));
  prog_before := (public.world_field_survey(uid, r.region_id) ->> 'pct')::int;

  sup := e.supplies; hp := c.health; mn := c.mental; er := c.erosion;
  rations_need := floor(e.minutes * rounds / total_rounds / 60.0)::int;
  FOR i IN 1..rations_need LOOP
    IF coalesce((sup ->> 'travel_ration')::int, 0) > 0 THEN sup := jsonb_set(sup, '{travel_ration}', to_jsonb((sup ->> 'travel_ration')::int - 1));
    ELSE rations_short := rations_short + 1; END IF;
  END LOOP;
  IF rations_short > 0 THEN
    mn := mn - rations_short * 6; loot_mul := loot_mul * 0.9;
    log := log || jsonb_build_array('노정 건량이 모자라 허기진 채로 걸었습니다. 정신 -' || rations_short * 6);
  END IF;

  FOR i IN 1..rounds LOOP
    roll := random();
    IF roll < p_fight THEN
      SELECT * INTO m FROM public.world_region_monsters WHERE region_id = r.region_id AND (role <> 'guardian' OR depth >= 3)
        ORDER BY -ln(greatest(random(), 1e-9)) / CASE role WHEN 'common' THEN 6 WHEN 'guardian' THEN 0.6 ELSE 4 END LIMIT 1;
      IF m.monster_id IS NULL THEN CONTINUE; END IF;
      threat := ((70 + (n.min_level + 1) * 14) / 8.0 + (8 + (n.min_level + 1) * 1.1) * 2) * CASE WHEN m.role = 'guardian' THEN 2.4 ELSE 1 END * (1 + (depth - 1) * 0.25);
      spirit_mech := coalesce(m.mechanic_key, '') IN ('spectral', 'warded', 'seal_breaker');
      win_p := power / (power + threat);
      IF spirit_mech THEN
        win_p := win_p + c.spirit_affinity * 0.004;
        IF coalesce((sup ->> 'seal_paper')::int, 0) > 0 THEN
          sup := jsonb_set(sup, '{seal_paper}', to_jsonb((sup ->> 'seal_paper')::int - 1));
          win_p := win_p + CASE WHEN c.job_key IN ('sealmaster', 'exorcist') THEN 0.25 ELSE 0.15 END;
        END IF;
      END IF;
      win_p := greatest(0.08, least(0.95, win_p));
      IF random() < win_p THEN
        wins := wins + 1; xp := xp + 10 + danger * 2; cxp := cxp + 16; gil_gain := gil_gain + 2 + danger;
        dmg := round((8 + n.min_level * 1.1) * 0.9 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + defense));
        IF m.drops IS NOT NULL AND random() < 0.7 * loot_mul THEN
          SELECT d.k INTO item FROM jsonb_each(m.drops) d(k, v) WHERE EXISTS (SELECT 1 FROM public.world_item_catalog ic WHERE ic.item_id = d.k) ORDER BY random() LIMIT 1;
          IF item IS NOT NULL THEN loot := public.world_inv_add(loot, item, 1); END IF;
        END IF;
        IF wins <= 3 THEN log := log || jsonb_build_array(m.monster_name || '을(를) 물리쳤습니다.'); END IF;
      ELSE
        losses := losses + 1;
        dmg := round((8 + n.min_level * 1.1) * 2.4 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + defense));
        log := log || jsonb_build_array(m.monster_name || '에게 밀려 물러났습니다. 체력 -' || dmg);
      END IF;
      hp := hp - dmg;
      IF spirit_mech THEN mn := mn - 3; ELSE mn := mn - 1; END IF;
    ELSIF roll < p_fight + 0.35 THEN
      IF cardinality(pool) > 0 THEN
        item := pool[1 + floor(random() * cardinality(pool))::int];
        qty := 1 + floor(random() * (1 + least(tt, 3)))::int + coalesce(c.gathering_rank, 1) / 10;
        IF tt = 0 THEN qty := CASE WHEN random() < 0.5 THEN 1 ELSE 0 END; END IF;
        qty := round(qty * loot_mul * (1 + CASE WHEN c.major_faction_id = 'southern_remnant' THEN 0.15 ELSE 0 END
                + CASE WHEN c.job_key IN ('artificer', 'scout') THEN 0.15 ELSE 0 END + c.perception * 0.005));
        IF qty > 0 THEN gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty); END IF;
      END IF;
    ELSIF roll < p_fight + 0.35 + 0.22 + c.perception * 0.002 THEN
      finds := finds + 1; xp := xp + 6; ixp := ixp + 10;
      -- 새 장소나 채집터를 찾는다(찾은 곳에서 이어지는 곳만)
      IF random() < 0.55 * disc_mul THEN
        found_node := NULL; found_spot := NULL;
        SELECT z.node_id INTO found_node FROM public.world_exploration_nodes z
          WHERE z.region_id = r.region_id AND z.hierarchy_level >= 2 AND z.min_level <= c.level + 2
            AND NOT EXISTS (SELECT 1 FROM public.world_exploration_discoveries d WHERE d.owner_id = uid AND d.node_id = z.node_id)
            AND (z.hierarchy_level = 2 OR EXISTS (SELECT 1 FROM public.world_exploration_discoveries d WHERE d.owner_id = uid AND d.node_id = z.parent_node_id))
          ORDER BY (z.parent_node_id = n.node_id) DESC, random() LIMIT 1;
        IF found_node IS NOT NULL AND random() < 0.5 THEN
          INSERT INTO public.world_exploration_discoveries(owner_id, node_id) VALUES (uid, found_node) ON CONFLICT DO NOTHING;
          discovered := discovered + 1;
          IF discovered <= 3 THEN log := log || jsonb_build_array('새로운 곳을 찾았습니다: ' || (SELECT node_name FROM public.world_exploration_nodes WHERE node_id = found_node)); END IF;
        ELSE
          SELECT s.spot_id INTO found_spot FROM public.world_gathering_spots s JOIN public.world_exploration_discoveries d ON d.node_id = s.node_id AND d.owner_id = uid
            JOIN public.world_exploration_nodes y ON y.node_id = s.node_id
            WHERE y.region_id = r.region_id AND s.active AND NOT EXISTS (SELECT 1 FROM public.world_gathering_discoveries g WHERE g.owner_id = uid AND g.spot_id = s.spot_id)
            ORDER BY (s.node_id = n.node_id) DESC, random() LIMIT 1;
          IF found_spot IS NOT NULL THEN
            INSERT INTO public.world_gathering_discoveries(owner_id, spot_id) VALUES (uid, found_spot) ON CONFLICT DO NOTHING;
            discovered := discovered + 1;
            IF discovered <= 3 THEN log := log || jsonb_build_array('채집터를 찾았습니다: ' || (SELECT spot_name FROM public.world_gathering_spots WHERE spot_id = found_spot)); END IF;
          END IF;
        END IF;
      END IF;
      IF cardinality(rare_pool) > 0 AND random() < 0.04 + depth * 0.03 + (CASE WHEN c.job_key = 'analyst' THEN 0.05 ELSE 0 END) THEN
        item := rare_pool[1 + floor(random() * cardinality(rare_pool))::int];
        loot := public.world_inv_add(loot, item, 1);
        log := log || jsonb_build_array('숨겨진 곳에서 ' || (SELECT item_name FROM public.world_item_catalog WHERE item_id = item) || '을(를) 찾았습니다.');
      END IF;
    ELSE
      IF random() < 0.6 THEN
        hazards := hazards + 1;
        er := er + round((danger + depth) / 2.0 * (CASE WHEN c.job_key = 'sealmaster' THEN 0.5 ELSE 1 END) * greatest(0.3, 1 - c.willpower / 100.0));
        mn := mn - (2 + floor(random() * 4))::int;
      END IF;
    END IF;
    IF er >= 50 AND coalesce((sup ->> 'ward_talisman')::int, 0) > 0 THEN
      sup := jsonb_set(sup, '{ward_talisman}', to_jsonb((sup ->> 'ward_talisman')::int - 1)); er := er - 15; mn := mn + 5;
    END IF;
    WHILE hp < heal_at LOOP
      item := CASE WHEN coalesce((sup ->> 'tonic')::int, 0) > 0 THEN 'tonic' WHEN coalesce((sup ->> 'herbal_extract')::int, 0) > 0 THEN 'herbal_extract'
                   WHEN coalesce((sup ->> 'herb')::int, 0) > 0 THEN 'herb' END;
      EXIT WHEN item IS NULL;
      heal := CASE item WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 ELSE 12 END;
      IF c.job_key = 'medic' THEN heal := round(heal * 1.5); END IF;
      sup := jsonb_set(sup, ARRAY[item], to_jsonb((sup ->> item)::int - 1)); hp := least(100, hp + heal);
    END LOOP;
    IF hp <= 0 THEN
      IF coalesce((sup ->> 'revival_charm')::int, 0) > 0 THEN
        sup := jsonb_set(sup, '{revival_charm}', to_jsonb((sup ->> 'revival_charm')::int - 1)); hp := 30;
        log := log || jsonb_build_array('쓰러지기 직전 회생 부적이 타올라 몸을 일으켰습니다.');
      ELSE
        hp := 0; ended := 'downed';
        log := log || jsonb_build_array('쓰러졌습니다. 챙긴 전리품 절반을 잃었습니다. 구조가 필요합니다.');
        SELECT coalesce(jsonb_object_agg(lk, (lv::int / 2)) FILTER (WHERE lv::int / 2 > 0), '{}'::jsonb) INTO loot FROM jsonb_each_text(loot) l(lk, lv);
        EXIT;
      END IF;
    END IF;
    IF mn <= 0 THEN
      mn := 5; ended := CASE WHEN ended = 'complete' THEN 'exhausted' ELSE ended END;
      log := log || jsonb_build_array('정신이 바닥나 서둘러 돌아왔습니다.');
      EXIT;
    END IF;
  END LOOP;

  er := greatest(0, least(100, er)); mn := greatest(0, least(100, mn)); hp := greatest(0, least(100, hp));
  inv := coalesce(c.inventory, '{}'::jsonb);
  FOR k, q IN SELECT key, value::text::int FROM jsonb_each(sup) WHERE value::text::int > 0 LOOP inv := public.world_inv_add(inv, k, q); END LOOP;
  cap := c.bag_capacity + CASE WHEN c.major_faction_id = 'river_alliance' THEN 20 ELSE 0 END;
  SELECT coalesce(sum(greatest(0, CASE WHEN jsonb_typeof(v) = 'number' THEN v::text::numeric ELSE 0 END)), 0)::int INTO used FROM jsonb_each(inv) t(kk, v);
  FOR k, q IN SELECT key, value::text::int FROM jsonb_each(loot) WHERE value::text::int > 0 ORDER BY key LOOP
    space := greatest(0, cap - used);
    IF space < q THEN lost := lost || jsonb_build_object(k, q - space); END IF;
    IF least(space, q) > 0 THEN inv := public.world_inv_add(inv, k, least(space, q)); used := used + least(space, q); END IF;
  END LOOP;
  IF lost <> '{}'::jsonb THEN log := log || jsonb_build_array('가방이 가득 차 일부 전리품을 두고 왔습니다.'); END IF;

  UPDATE public.world_characters SET
    health = CASE WHEN ended = 'downed' THEN 0 ELSE hp END, mental = mn, erosion = er,
    erosion_stage = CASE WHEN er >= 80 THEN 4 WHEN er >= 55 THEN 3 WHEN er >= 30 THEN 2 WHEN er >= 10 THEN 1 ELSE 0 END,
    combat_xp = combat_xp + cxp, combat_rank = public.world_skill_rank(combat_xp + cxp, 'combat'),
    gathering_xp = gathering_xp + gxp, gathering_rank = public.world_skill_rank(gathering_xp + gxp, 'gathering'),
    investigation_xp = investigation_xp + ixp, investigation_rank = public.world_skill_rank(investigation_xp + ixp, 'investigation'),
    gil = gil + gil_gain, inventory = inv, updated_at = now()
  WHERE owner_id = uid;
  gained := public.world_grant_xp(uid, xp);

  prog_after := (public.world_field_survey(uid, r.region_id) ->> 'pct')::int;
  INSERT INTO public.world_region_progress(owner_id, region_id) VALUES (uid, r.region_id) ON CONFLICT DO NOTHING;
  SELECT coalesce(p.milestones, '{}') INTO ms_list FROM public.world_region_progress p WHERE p.owner_id = uid AND p.region_id = r.region_id FOR UPDATE;
  IF prog_after >= 100 AND NOT ('complete' = ANY (ms_list)) THEN
    new_ms := array_append(new_ms, 'complete');
    UPDATE public.world_characters SET bag_capacity = least(400, bag_capacity + 5) WHERE owner_id = uid;
    log := log || jsonb_build_array(r.region_name || ' 완전 답사 — 가방 용량 +5');
  END IF;
  UPDATE public.world_region_progress SET progress = prog_after, expeditions = expeditions + 1, milestones = world_region_progress.milestones || new_ms, updated_at = now()
  WHERE owner_id = uid AND region_id = r.region_id;
  IF 'complete' = ANY (new_ms) THEN
    SELECT count(*) INTO fully FROM public.world_region_progress WHERE owner_id = uid AND 'complete' = ANY (milestones);
    IF fully >= 5 THEN
      INSERT INTO public.world_owned_mounts(owner_id, mount_id) VALUES (uid, 'mist_deer') ON CONFLICT DO NOTHING;
      IF FOUND THEN mount_gift := 'mist_deer'; log := log || jsonb_build_array('다섯 지역을 완전히 답사하자 안개 사슴이 따라왔습니다.'); END IF;
    END IF;
  END IF;

  UPDATE public.world_expeditions SET status = 'done', finished_at = now(), result = jsonb_build_object(
    'ended', ended, 'rounds', rounds, 'total_rounds', total_rounds, 'wins', wins, 'losses', losses, 'gathers', gathers, 'finds', finds, 'hazards', hazards,
    'discovered', discovered, 'loot', loot, 'lost', lost, 'supplies_left', sup,
    'supplies_used', (SELECT coalesce(jsonb_object_agg(s.key, s.value::text::int - coalesce((sup ->> s.key)::int, 0)) FILTER (WHERE s.value::text::int - coalesce((sup ->> s.key)::int, 0) > 0), '{}'::jsonb) FROM jsonb_each(e.supplies) s),
    'experience', xp, 'combat_xp', cxp, 'gathering_xp', gxp, 'investigation_xp', ixp, 'gil', gil_gain, 'levels', gained,
    'health', CASE WHEN ended = 'downed' THEN 0 ELSE hp END, 'mental', mn, 'erosion', er,
    'progress_before', prog_before, 'progress_after', prog_after, 'mount', mount_gift, 'log', log)
  WHERE expedition_id = e.expedition_id;

  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'expedition_end', nm || ' 원정 종료',
    jsonb_build_object('node_id', n.node_id, 'ended', ended, 'wins', wins, 'gathers', gathers, 'progress', prog_after));

  RETURN (SELECT jsonb_build_object('ok', true, 'place_name', nm, 'content', nm || ' 원정을 마쳤습니다.', 'result', x.result)
          FROM public.world_expeditions x WHERE x.expedition_id = e.expedition_id);
END $f$;

-- ── 답사 현황(지역별) ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.world_survey_overview()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid();
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  RETURN (WITH nf AS (SELECT n.region_id, count(*) total, count(d.node_id) found FROM public.world_exploration_nodes n
                      LEFT JOIN public.world_exploration_discoveries d ON d.node_id = n.node_id AND d.owner_id = uid WHERE n.hierarchy_level >= 2 GROUP BY 1),
               sf AS (SELECT n.region_id, count(*) total, count(d.spot_id) found FROM public.world_gathering_spots s JOIN public.world_exploration_nodes n ON n.node_id = s.node_id
                      LEFT JOIN public.world_gathering_discoveries d ON d.spot_id = s.spot_id AND d.owner_id = uid WHERE s.active GROUP BY 1)
    SELECT jsonb_build_object('regions', coalesce(jsonb_agg(jsonb_build_object('region_id', r.region_id, 'region_name', r.region_name, 'territory_name', r.territory_name,
        'safe_zone', r.is_safe_zone, 'danger', r.danger_level, 'min_level', r.min_level,
        'nodes_found', nf.found, 'nodes_total', nf.total, 'spots_found', sf.found, 'spots_total', sf.total,
        'progress', CASE WHEN nf.total + sf.total = 0 THEN 0 ELSE floor(100.0 * (nf.found + sf.found) / (nf.total + sf.total))::int END)
        ORDER BY r.territory_id, r.min_level, r.region_name), '[]'::jsonb))
    FROM public.world_map_regions r LEFT JOIN nf ON nf.region_id = r.region_id LEFT JOIN sf ON sf.region_id = r.region_id WHERE r.active);
END $f$;

-- ── 물품 사용: 회복·치료·탐색력. 쓰러졌을 때는 회생 부적만 ─────────────────
CREATE OR REPLACE FUNCTION public.world_use_item(p_item_id text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; inv jsonb; hp int := 0; mn int := 0; er int := 0; stam int := 0;
  cures text[] := '{}'; cleared int := 0; nm text; mul float8 := 1; msg text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) THEN RAISE EXCEPTION '숨을 거둔 조사원은 물품을 쓸 수 없습니다.'; END IF;
  inv := coalesce(c.inventory, '{}'::jsonb);
  IF coalesce((inv ->> p_item_id)::int, 0) < 1 THEN RAISE EXCEPTION '가방에 그 물품이 없습니다.'; END IF;
  SELECT item_name INTO nm FROM public.world_item_catalog WHERE item_id = p_item_id;
  IF c.downed_at IS NOT NULL OR c.health <= 0 THEN
    IF p_item_id <> 'revival_charm' THEN RAISE EXCEPTION '쓰러진 상태에서는 회생 부적만 쓸 수 있습니다. 구조를 기다리거나 구조대를 부르세요.'; END IF;
    inv := public.world_inv_add(inv, p_item_id, -1);
    UPDATE public.world_characters SET inventory = inv, health = 50, mental = least(100, mental + 20), spiritual_power = least(100, spiritual_power + 15),
      downed_at = NULL, updated_at = now() WHERE owner_id = uid;
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'use_item', c.character_name || '이(가) 회생 부적으로 일어났습니다.', jsonb_build_object('v2', true, 'item_id', p_item_id, 'revive', true));
    RETURN jsonb_build_object('ok', true, 'content', '회생 부적이 타올라 다시 일어섰습니다. 체력 50');
  END IF;
  IF p_item_id = 'revival_charm' THEN RAISE EXCEPTION '회생 부적은 쓰러졌을 때 씁니다.'; END IF;
  IF p_item_id NOT IN ('tonic', 'herbal_extract', 'herb', 'medicine_base', 'ward_talisman', 'travel_ration') THEN RAISE EXCEPTION '쓸 수 없는 물품입니다.'; END IF;
  mul := (CASE WHEN c.job_key = 'medic' THEN 1.4 ELSE 1 END) * (1 + public.world_status_effect_total('healing_pct') / 100.0);
  CASE p_item_id
    WHEN 'tonic' THEN hp := 35; cures := ARRAY['shaken'];
    WHEN 'herbal_extract' THEN hp := 22; cures := ARRAY['bleeding', 'burned', 'sprain'];
    WHEN 'herb' THEN hp := 12; cures := ARRAY['poisoned', 'stomach_upset'];
    WHEN 'medicine_base' THEN mn := 12; cures := ARRAY['fatigue', 'cold', 'exhausted', 'overtrained'];
    WHEN 'ward_talisman' THEN mn := 8; er := 12; cures := ARRAY['erosion_whisper', 'shaken', 'poisoned'];
    WHEN 'travel_ration' THEN stam := 5;
  END CASE;
  hp := round(hp * mul); mn := round(mn * mul);
  SELECT count(*) INTO cleared FROM public.world_character_statuses WHERE owner_id = uid AND status_key = ANY (cures) AND expires_at > now();
  IF stam = 0 AND cleared = 0 AND (hp = 0 OR c.health >= 100) AND (mn = 0 OR c.mental >= 100) AND (er = 0 OR c.erosion <= 0) THEN
    RAISE EXCEPTION '지금은 쓸 필요가 없습니다.'; END IF;
  IF stam > 0 AND public.world_stamina_now(c.stamina, c.stamina_at, c.level) >= public.world_stamina_max(c.level) THEN RAISE EXCEPTION '탐색력이 이미 가득 찼습니다.'; END IF;
  DELETE FROM public.world_character_statuses WHERE owner_id = uid AND status_key = ANY (cures);
  inv := public.world_inv_add(inv, p_item_id, -1);
  UPDATE public.world_characters SET inventory = inv, health = least(100, health + hp), mental = least(100, mental + mn),
    erosion = greatest(0, erosion - er), erosion_stage = CASE WHEN greatest(0, erosion - er) >= 80 THEN 4 WHEN greatest(0, erosion - er) >= 55 THEN 3
      WHEN greatest(0, erosion - er) >= 30 THEN 2 WHEN greatest(0, erosion - er) >= 10 THEN 1 ELSE 0 END, updated_at = now() WHERE owner_id = uid;
  IF stam > 0 THEN PERFORM public.world_stamina_change(uid, stam); END IF;
  msg := nm || '을(를) 썼습니다.' || CASE WHEN hp > 0 THEN ' 체력 +' || hp ELSE '' END || CASE WHEN mn > 0 THEN ' 정신 +' || mn ELSE '' END
    || CASE WHEN er > 0 THEN ' 침식 -' || er ELSE '' END || CASE WHEN stam > 0 THEN ' 탐색력 +' || stam ELSE '' END || CASE WHEN cleared > 0 THEN ' · 상태 ' || cleared || '개 치료' ELSE '' END;
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'use_item', msg, jsonb_build_object('v2', true, 'item_id', p_item_id, 'cleared_statuses', cleared));
  RETURN jsonb_build_object('ok', true, 'content', msg);
END $f$;

-- ── 본부 구조대: 쓰러졌을 때 돈을 내고 가장 가까운 안전지대로 옮겨진다 ─────────
CREATE OR REPLACE FUNCTION public.world_call_rescue()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; s public.world_map_regions%rowtype; fee bigint;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND OR coalesce(c.is_dead, false) THEN RAISE EXCEPTION '구조대를 부를 수 없습니다.'; END IF;
  IF c.downed_at IS NULL AND c.health > 0 THEN RAISE EXCEPTION '쓰러진 상태가 아닙니다.'; END IF;
  r := public.world_field_region(c.location);
  SELECT * INTO s FROM public.world_map_regions x WHERE x.is_safe_zone AND x.active AND x.min_level <= c.level
    ORDER BY (x.world_x - coalesce(r.world_x, 480)) ^ 2 + (x.world_y - coalesce(r.world_y, 360)) ^ 2 LIMIT 1;
  fee := least(c.gil, greatest(50, c.gil * 3 / 10));
  DELETE FROM public.world_active_encounters WHERE owner_id = uid;
  UPDATE public.world_characters SET gil = gil - fee, health = 30, mental = greatest(mental, 20), downed_at = NULL,
    location = s.region_name, current_exploration_node_id = NULL, travel_destination = NULL, travel_arrives_at = NULL, updated_at = now()
  WHERE owner_id = uid;
  INSERT INTO public.world_economy_ledger(owner_id, action, currency_delta, sink, details) VALUES (uid, 'rescue_team', -fee, true, jsonb_build_object('to', s.region_id));
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'rescue', '본부 구조대가 ' || c.character_name || '을(를) ' || s.region_name || '(으)로 옮겼습니다.', jsonb_build_object('self', true, 'fee', fee, 'to', s.region_id));
  RETURN jsonb_build_object('ok', true, 'content', '구조대가 ' || s.region_name || '(으)로 옮겨 주었습니다. ' || fee || '전을 냈습니다. 체력 30', 'location', s.region_name);
END $f$;

-- ── 쉬기: 안전지대 숙소 또는 바깥 야영. 탐색력도 채운다. 야영 중에는 습격받을 수 있다 ─────────
CREATE OR REPLACE FUNCTION public.world_field_rest(p_style text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; n public.world_exploration_nodes%rowtype;
  cost int; is_full boolean := p_style = 'full'; hp int; mn int; sp int; er int; st int; mx int; cleared int := 0; ambush jsonb;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_style NOT IN ('short', 'full') THEN RAISE EXCEPTION '쉬는 방식을 고르세요.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '쓰러진 상태에서는 스스로 쉴 수 없습니다.'; END IF;
  IF c.travel_arrives_at IS NOT NULL AND c.travel_arrives_at > now() THEN RAISE EXCEPTION '이동 중에는 쉴 수 없습니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = uid AND NOT a.defeated AND NOT coalesce(a.fled, false)) THEN RAISE EXCEPTION '전투 중입니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = uid AND e.status = 'active') THEN RAISE EXCEPTION '원정 중입니다.'; END IF;
  r := public.world_field_region(c.location);
  IF r.region_id IS NULL THEN RAISE EXCEPTION '쉴 곳을 찾을 수 없습니다.'; END IF;
  cost := CASE WHEN r.rest_spot_type = 'hq' THEN 0 ELSE coalesce(r.rest_fee, 0) * CASE WHEN is_full THEN 2 ELSE 1 END END;
  IF c.gil < cost THEN RAISE EXCEPTION '%', format('전이 부족합니다. 필요: %s전', cost); END IF;
  hp := CASE WHEN is_full THEN 65 ELSE 25 END + coalesce(r.rest_quality, 1) * 5;
  mn := CASE WHEN is_full THEN 50 ELSE 20 END; sp := CASE WHEN is_full THEN 35 ELSE 12 END; er := CASE WHEN is_full THEN 18 ELSE 6 END;
  IF NOT r.is_safe_zone THEN hp := hp / 2; mn := mn / 2; sp := sp / 2; er := er / 2; END IF;
  IF is_full THEN
    DELETE FROM public.world_character_statuses WHERE owner_id = uid AND status_key IN ('fatigue', 'exhausted', 'cold', 'stomach_upset', 'overtrained', 'shaken', 'disoriented', 'bleeding', 'sprain', 'burned');
  ELSE
    DELETE FROM public.world_character_statuses WHERE owner_id = uid AND status_key IN ('fatigue', 'shaken', 'disoriented', 'overtrained');
  END IF;
  GET DIAGNOSTICS cleared = ROW_COUNT;
  UPDATE public.world_characters SET health = least(100, health + hp), mental = least(100, mental + mn), spiritual_power = least(100, spiritual_power + sp),
    erosion = greatest(0, erosion - er), gil = gil - cost, updated_at = now() WHERE owner_id = uid;
  mx := public.world_stamina_max(c.level); st := public.world_stamina_now(c.stamina, c.stamina_at, c.level);
  PERFORM public.world_stamina_change(uid, least(mx - st, CASE WHEN is_full AND r.is_safe_zone THEN mx WHEN is_full THEN 6 ELSE 3 END));
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'rest', c.character_name || CASE WHEN r.is_safe_zone THEN '이(가) ' || coalesce(r.rest_spot_name, '숙소') || '에서 쉬었습니다.' ELSE '이(가) 야영했습니다.' END,
    jsonb_build_object('region_id', r.region_id, 'style', p_style, 'fee', cost, 'cleared_statuses', cleared));
  -- 바깥 야영은 위험도만큼 습격받을 수 있다
  IF NOT r.is_safe_zone AND random() < least(0.45, 0.05 + r.danger_level * 0.03) THEN
    SELECT * INTO n FROM public.world_exploration_nodes WHERE node_id = c.current_exploration_node_id AND region_id = r.region_id;
    IF n.node_id IS NULL THEN SELECT * INTO n FROM public.world_exploration_nodes WHERE region_id = r.region_id AND hierarchy_level = 1 LIMIT 1; END IF;
    ambush := public.world_battle_open(uid, r.region_id, n.node_id, n.hierarchy_level - 1, c.level);
    IF ambush IS NOT NULL THEN
      RETURN jsonb_build_object('ok', true, 'ambushed', true, 'content', '쉬던 중 ' || (ambush ->> 'name') || '이(가) 습격했습니다!');
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'content', CASE WHEN is_full THEN '푹 쉬었습니다.' ELSE '잠시 숨을 골랐습니다.' END
    || ' 체력·정신·영력이 회복되고 탐색력이 찼습니다.' || CASE WHEN cleared > 0 THEN ' 나쁜 상태 ' || cleared || '개가 풀렸습니다.' ELSE '' END);
END $f$;

-- ── 생활 전문화: 한 번 정하면 3일 동안 바꿀 수 없다 ─────────────────────
CREATE OR REPLACE FUNCTION public.world_set_life_profession_v2(p_gathering text, p_crafting text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_gathering NOT IN ('fieldwork', 'mining', 'botany', 'spirit_harvest', 'fishing') THEN RAISE EXCEPTION '없는 채집 분야입니다.'; END IF;
  IF p_crafting NOT IN ('general', 'smithing', 'carpentry', 'alchemy', 'sealing', 'weaving', 'leatherwork', 'artifice') THEN RAISE EXCEPTION '없는 제작 분야입니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF c.gathering_profession = p_gathering AND c.crafting_profession = p_crafting THEN RAISE EXCEPTION '이미 그 분야입니다.'; END IF;
  IF c.life_changed_at IS NOT NULL AND c.life_changed_at > now() - interval '72 hours' THEN
    RAISE EXCEPTION '%', format('전문화는 %s 이후에 다시 바꿀 수 있습니다.', to_char((c.life_changed_at + interval '72 hours') AT TIME ZONE 'Asia/Seoul', 'MM월 DD일 HH24:MI'));
  END IF;
  UPDATE public.world_characters SET gathering_profession = p_gathering, crafting_profession = p_crafting, life_changed_at = now(), updated_at = now() WHERE owner_id = uid;
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'mission', '생활 전문 분야 변경', jsonb_build_object('v2', true, 'gathering_profession', p_gathering, 'crafting_profession', p_crafting));
  RETURN jsonb_build_object('ok', true, 'content', '전문화를 정했습니다. 3일 뒤에 다시 바꿀 수 있습니다.');
END $f$;

-- ── 프로필 사진: 128px 정사각 이미지(데이터 주소)만 받는다 ─────────────────
CREATE OR REPLACE FUNCTION public.world_set_avatar(p_image text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid();
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_image IS NOT NULL THEN
    IF length(p_image) > 40000 THEN RAISE EXCEPTION '사진이 너무 큽니다.'; END IF;
    IF p_image !~ '^data:image/(webp|jpeg|png);base64,[A-Za-z0-9+/]+={0,2}$' THEN RAISE EXCEPTION '사진 형식이 올바르지 않습니다.'; END IF;
  END IF;
  UPDATE public.world_characters SET profile = CASE WHEN p_image IS NULL THEN coalesce(profile, '{}'::jsonb) - 'avatar'
    ELSE coalesce(profile, '{}'::jsonb) || jsonb_build_object('avatar', p_image) END, updated_at = now() WHERE owner_id = uid;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  RETURN jsonb_build_object('ok', true, 'content', CASE WHEN p_image IS NULL THEN '사진을 지웠습니다.' ELSE '프로필 사진을 바꿨습니다.' END);
END $f$;

-- ── 시신: 명복 빌기(정신 회복, 한 번) · 유품 수습 ─────────────────────────
CREATE OR REPLACE FUNCTION public.world_corpse_respect(p_corpse_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; k public.world_corpses%rowtype;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  SELECT * INTO k FROM public.world_corpses WHERE corpse_id = p_corpse_id FOR UPDATE;
  IF k.corpse_id IS NULL OR k.location <> c.location THEN RAISE EXCEPTION '같은 곳에 있는 시신이 아닙니다.'; END IF;
  IF k.owner_id = uid OR uid = ANY (k.respects) THEN RAISE EXCEPTION '이미 명복을 빌었습니다.'; END IF;
  UPDATE public.world_corpses SET respects = array_append(respects, uid) WHERE corpse_id = k.corpse_id;
  UPDATE public.world_characters SET mental = least(100, mental + 5), updated_at = now() WHERE owner_id = uid;
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'respect', c.character_name || '이(가) ' || k.character_name || '의 명복을 빌었습니다.', jsonb_build_object('corpse_id', k.corpse_id));
  RETURN jsonb_build_object('ok', true, 'content', k.character_name || '의 명복을 빌었습니다. 마음이 조금 가라앉습니다. 정신 +5');
END $f$;

CREATE OR REPLACE FUNCTION public.world_corpse_loot(p_corpse_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; k public.world_corpses%rowtype; inv jsonb; it text; q int; got text[] := '{}';
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '지금은 유품을 수습할 수 없습니다.'; END IF;
  SELECT * INTO k FROM public.world_corpses WHERE corpse_id = p_corpse_id FOR UPDATE;
  IF k.corpse_id IS NULL OR k.location <> c.location THEN RAISE EXCEPTION '같은 곳에 있는 시신이 아닙니다.'; END IF;
  IF k.items = '{}'::jsonb AND k.gil = 0 THEN RAISE EXCEPTION '남은 유품이 없습니다.'; END IF;
  inv := coalesce(c.inventory, '{}'::jsonb);
  FOR it, q IN SELECT key, value::text::int FROM jsonb_each(k.items) WHERE value::text::int > 0 LOOP
    inv := public.world_inv_add(inv, it, q); got := got || ((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || ' ×' || q);
  END LOOP;
  UPDATE public.world_characters SET inventory = inv, gil = gil + k.gil, updated_at = now() WHERE owner_id = uid;
  UPDATE public.world_corpses SET items = '{}'::jsonb, gil = 0, looted_by = uid, looted_at = now() WHERE corpse_id = k.corpse_id;
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'loot', c.character_name || '이(가) ' || k.character_name || '의 유품을 수습했습니다.', jsonb_build_object('corpse_id', k.corpse_id, 'gil', k.gil));
  RETURN jsonb_build_object('ok', true, 'content', k.character_name || '의 유품을 수습했습니다: ' || coalesce(nullif(array_to_string(got, ', '), ''), '물건 없음')
    || CASE WHEN k.gil > 0 THEN ' · ' || k.gil || '전' ELSE '' END || '. 가방이 가득 차면 넘친 것은 두고 옵니다.');
END $f$;

-- ── 캐릭터 정리: 본인이 이름을 적어 확인하면 캐릭터와 진행 기록을 지운다 ─────────
-- 쓰러졌거나 숨진 상태였다면 그 자리에 시신을 남긴다. 계정과 공용 기록(채팅·사건 로그·경제 원장)은 남긴다.
CREATE OR REPLACE FUNCTION public.world_character_delete(p_confirm text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; items jsonb; pid uuid;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '정리할 캐릭터가 없습니다.'; END IF;
  IF btrim(coalesce(p_confirm, '')) <> c.character_name THEN RAISE EXCEPTION '캐릭터 이름이 일치하지 않습니다.'; END IF;
  IF (c.downed_at IS NOT NULL OR c.health <= 0 OR c.is_dead)
     AND NOT EXISTS (SELECT 1 FROM public.world_corpses k WHERE k.owner_id = uid AND k.died_at > now() - interval '1 day') THEN
    r := public.world_field_region(c.location);
    SELECT coalesce(jsonb_object_agg(k, v), '{}'::jsonb) INTO items FROM jsonb_each(coalesce(c.inventory, '{}'::jsonb)) e(k, v)
      JOIN public.world_item_catalog i ON i.item_id = e.k WHERE jsonb_typeof(v) = 'number' AND v::text::int > 0 AND coalesce(i.tradeable, true);
    INSERT INTO public.world_corpses(owner_id, character_name, location, region_id, death_reason, items, gil)
    VALUES (uid, c.character_name, c.location, r.region_id, CASE WHEN c.is_dead THEN coalesce(c.death_reason, '숨을 거두었다') ELSE '쓰러진 자리에서 눈을 감았다' END, items, greatest(0, c.gil / 2));
  END IF;
  SELECT party_id INTO pid FROM public.world_parties WHERE leader_id = uid;
  IF pid IS NOT NULL THEN DELETE FROM public.world_parties WHERE party_id = pid; END IF;
  DELETE FROM public.world_party_members WHERE owner_id = uid;
  DELETE FROM public.world_party_invites WHERE inviter_id = uid OR invitee_id = uid;
  DELETE FROM public.world_ride_requests WHERE driver_id = uid OR passenger_id = uid;
  DELETE FROM public.world_travel_party_requests WHERE leader_id = uid OR passenger_id = uid;
  DELETE FROM public.world_trade_offers WHERE seller_id = uid AND status = 'open';
  DELETE FROM public.world_trade_requests WHERE proposer_id = uid OR partner_id = uid;
  DELETE FROM public.world_active_encounters WHERE owner_id = uid;
  DELETE FROM public.world_case_progress WHERE owner_id = uid;
  DELETE FROM public.world_character_equipment WHERE owner_id = uid;
  DELETE FROM public.world_character_statuses WHERE owner_id = uid;
  DELETE FROM public.world_character_titles WHERE owner_id = uid;
  DELETE FROM public.world_expedition_state WHERE owner_id = uid;
  DELETE FROM public.world_expeditions WHERE owner_id = uid;
  DELETE FROM public.world_exploration_discoveries WHERE owner_id = uid;
  DELETE FROM public.world_gathering_discoveries WHERE owner_id = uid;
  DELETE FROM public.world_idle_activities WHERE owner_id = uid;
  DELETE FROM public.world_owned_mounts WHERE owner_id = uid;
  DELETE FROM public.world_region_event_progress WHERE owner_id = uid;
  DELETE FROM public.world_region_intel WHERE owner_id = uid;
  DELETE FROM public.world_region_progress WHERE owner_id = uid;
  DELETE FROM public.world_region_site_discoveries WHERE owner_id = uid;
  DELETE FROM public.world_regional_case_claims WHERE owner_id = uid;
  DELETE FROM public.world_story_progress WHERE owner_id = uid;
  DELETE FROM public.world_faction_mission_progress WHERE owner_id = uid;
  DELETE FROM public.world_commissions WHERE owner_id = uid;
  DELETE FROM public.world_characters WHERE owner_id = uid;
  INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
  VALUES (uid, 'system', '캐릭터를 정리했습니다', c.character_name || '의 기록을 정리했습니다. 새 조사원을 만들 수 있습니다.', '{}'::jsonb);
  RETURN jsonb_build_object('ok', true, 'content', c.character_name || '을(를) 정리했습니다.');
END $f$;

-- 실행 권한과 소유권: 함수 전용 역할로 넘긴다
REVOKE ALL ON FUNCTION public.world_hud_snapshot() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_hud_snapshot() TO authenticated;
ALTER FUNCTION public.world_hud_snapshot() OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_travel_route(p_region_id text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_travel_route(p_region_id text) TO authenticated;
ALTER FUNCTION public.world_travel_route(p_region_id text) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_expedition_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_expedition_overview() TO authenticated;
ALTER FUNCTION public.world_expedition_overview() OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_expedition_start(p_node_id uuid, p_minutes integer, p_stance text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_expedition_start(p_node_id uuid, p_minutes integer, p_stance text) TO authenticated;
ALTER FUNCTION public.world_expedition_start(p_node_id uuid, p_minutes integer, p_stance text) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_expedition_complete(p_recall boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_expedition_complete(p_recall boolean) TO authenticated;
ALTER FUNCTION public.world_expedition_complete(p_recall boolean) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_survey_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_survey_overview() TO authenticated;
ALTER FUNCTION public.world_survey_overview() OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_use_item(p_item_id text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_use_item(p_item_id text) TO authenticated;
ALTER FUNCTION public.world_use_item(p_item_id text) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_call_rescue() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_call_rescue() TO authenticated;
ALTER FUNCTION public.world_call_rescue() OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_field_rest(p_style text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_field_rest(p_style text) TO authenticated;
ALTER FUNCTION public.world_field_rest(p_style text) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_set_life_profession_v2(p_gathering text, p_crafting text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_set_life_profession_v2(p_gathering text, p_crafting text) TO authenticated;
ALTER FUNCTION public.world_set_life_profession_v2(p_gathering text, p_crafting text) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_set_avatar(p_image text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_set_avatar(p_image text) TO authenticated;
ALTER FUNCTION public.world_set_avatar(p_image text) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_corpse_respect(p_corpse_id uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_corpse_respect(p_corpse_id uuid) TO authenticated;
ALTER FUNCTION public.world_corpse_respect(p_corpse_id uuid) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_corpse_loot(p_corpse_id uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_corpse_loot(p_corpse_id uuid) TO authenticated;
ALTER FUNCTION public.world_corpse_loot(p_corpse_id uuid) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_character_delete(p_confirm text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_character_delete(p_confirm text) TO authenticated;
ALTER FUNCTION public.world_character_delete(p_confirm text) OWNER TO fn_owner_field;
