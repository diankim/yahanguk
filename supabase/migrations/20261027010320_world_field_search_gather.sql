-- 탐색·채집과 실행 권한 정리 (fn_owner_field 소유)
SET ROLE fn_owner_field;

-- ── 탐색 ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.world_field_search()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE
  uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; n public.world_exploration_nodes%rowtype;
  theme text; depth int; left_st int; roll float8; w_path float8 := 0; w_spot float8 := 0; w_enc float8; w_cache float8 := 12; w_clue float8 := 0;
  w_reg float8 := 0; w_haz float8; w_omen float8 := 8; w_quiet float8 := 6; tot float8; outcome text; txt text; payload jsonb := '{}'::jsonb;
  child public.world_exploration_nodes%rowtype; spot public.world_gathering_spots%rowtype; inv jsonb; it text; qty int; gil_gain int := 0;
  xp int := 0; battle jsonb; chap text; clue public.world_story_clues%rowtype; hurt int; stkey text; site text; omen int;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태에서는 탐색할 수 없습니다.'; END IF;
  IF c.travel_arrives_at IS NOT NULL AND c.travel_arrives_at > now() THEN RAISE EXCEPTION '이동 중에는 탐색할 수 없습니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = uid AND NOT a.defeated AND NOT coalesce(a.fled, false)) THEN
    RAISE EXCEPTION '전투를 먼저 끝내세요.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = uid AND e.status = 'active') THEN RAISE EXCEPTION '원정 중에는 탐색할 수 없습니다.'; END IF;
  r := public.world_field_region(c.location);
  IF r.region_id IS NULL THEN RAISE EXCEPTION '지금 있는 곳을 알 수 없습니다.'; END IF;
  IF r.is_safe_zone THEN RAISE EXCEPTION '안전지대에서는 탐색하지 않습니다. 바깥 지역으로 나가세요.'; END IF;
  IF c.level < r.min_level THEN RAISE EXCEPTION '이 지역을 탐색하기에는 레벨이 낮습니다.'; END IF;
  SELECT * INTO n FROM public.world_exploration_nodes WHERE node_id = c.current_exploration_node_id AND region_id = r.region_id;
  IF n.node_id IS NULL THEN SELECT * INTO n FROM public.world_exploration_nodes WHERE region_id = r.region_id AND hierarchy_level = 1 LIMIT 1; END IF;
  depth := n.hierarchy_level - 1;
  SELECT t.theme INTO theme FROM public.world_region_theme t WHERE t.region_id = r.region_id;
  left_st := public.world_stamina_change(uid, -1);
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid;
  inv := coalesce(c.inventory, '{}'::jsonb);

  -- 가능한 결과의 비중
  SELECT * INTO child FROM public.world_exploration_nodes z WHERE z.parent_node_id = n.node_id
    AND NOT EXISTS (SELECT 1 FROM public.world_exploration_discoveries d WHERE d.owner_id = uid AND d.node_id = z.node_id) ORDER BY z.min_level, random() LIMIT 1;
  IF child.node_id IS NOT NULL THEN w_path := 22 + CASE WHEN c.job_key = 'scout' THEN 8 ELSE 0 END + CASE WHEN depth = 0 THEN 20 ELSE 0 END; END IF;
  SELECT * INTO spot FROM public.world_gathering_spots s WHERE s.node_id = n.node_id AND s.active
    AND NOT EXISTS (SELECT 1 FROM public.world_gathering_discoveries d WHERE d.owner_id = uid AND d.spot_id = s.spot_id) ORDER BY random() LIMIT 1;
  IF spot.spot_id IS NOT NULL THEN w_spot := 18 + CASE WHEN c.job_key IN ('artificer', 'scout') THEN 4 ELSE 0 END; END IF;
  w_enc := CASE WHEN depth = 0 THEN 18 ELSE 30 + depth * 3 END;
  w_haz := greatest(3, 8 + depth * 2 - c.agility / 10.0);
  chap := public.world_story_current(uid);
  SELECT k.* INTO clue FROM public.world_story_clues k JOIN public.world_story_chapters ch ON ch.chapter_id = k.chapter_id
    WHERE k.chapter_id = chap AND k.region_id = r.region_id AND c.level >= ch.min_level
      AND NOT EXISTS (SELECT 1 FROM public.world_case_progress p WHERE p.owner_id = uid AND p.case_id = k.chapter_id
                      AND p.clues @> jsonb_build_array(jsonb_build_object('id', k.clue_id)))
    ORDER BY k.sort LIMIT 1;
  IF clue.clue_id IS NOT NULL THEN
    w_clue := 16 + c.perception * 0.4 + least(coalesce(c.investigation_rank, 1), 20) * 0.6 + public.world_status_effect_total('clue_bonus_pct') * 0.5
              + CASE WHEN c.job_key = 'analyst' THEN 8 ELSE 0 END + depth * 3;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.world_case_progress p, jsonb_array_elements(coalesce(p.clues, '[]'::jsonb)) cl
                 WHERE p.owner_id = uid AND p.case_id = 'regional_discoveries' AND cl ->> 'region_id' = r.region_id) THEN
    w_reg := CASE WHEN depth >= 1 THEN 5 ELSE 0 END;
  END IF;
  tot := w_path + w_spot + w_enc + w_cache + w_clue + w_reg + w_haz + w_omen + w_quiet;
  roll := random() * tot;
  outcome := CASE
    WHEN roll < w_path THEN 'path'
    WHEN roll < w_path + w_spot THEN 'spot'
    WHEN roll < w_path + w_spot + w_clue THEN 'clue'
    WHEN roll < w_path + w_spot + w_clue + w_enc THEN 'encounter'
    WHEN roll < w_path + w_spot + w_clue + w_enc + w_cache THEN 'cache'
    WHEN roll < w_path + w_spot + w_clue + w_enc + w_cache + w_reg THEN 'regional'
    WHEN roll < w_path + w_spot + w_clue + w_enc + w_cache + w_reg + w_haz THEN 'hazard'
    WHEN roll < w_path + w_spot + w_clue + w_enc + w_cache + w_reg + w_haz + w_omen THEN 'omen'
    ELSE 'quiet' END;

  IF outcome = 'path' THEN
    INSERT INTO public.world_exploration_discoveries(owner_id, node_id) VALUES (uid, child.node_id) ON CONFLICT DO NOTHING;
    txt := (ARRAY['덤불을 헤치자 ', '무너진 담 너머로 ', '희미한 발자국을 따라가자 ', '바람이 새어 드는 틈을 지나 ', '등불을 비추자 '])[1 + floor(random() * 5)::int]
           || child.node_name || '(으)로 이어지는 길이 드러났다.';
    xp := 8; payload := jsonb_build_object('node_id', child.node_id, 'node_name', child.node_name);
  ELSIF outcome = 'spot' THEN
    INSERT INTO public.world_gathering_discoveries(owner_id, spot_id) VALUES (uid, spot.spot_id) ON CONFLICT DO NOTHING;
    txt := '쓸 만한 채집터를 찾았다: ' || spot.spot_name || '.';
    xp := 6; payload := jsonb_build_object('spot_id', spot.spot_id, 'spot_name', spot.spot_name, 'category', spot.category);
  ELSIF outcome = 'clue' THEN
    INSERT INTO public.world_case_progress(owner_id, case_id, clues, combined) VALUES (uid, clue.chapter_id, '[]'::jsonb, '[]'::jsonb) ON CONFLICT (owner_id, case_id) DO NOTHING;
    UPDATE public.world_case_progress SET clues = coalesce(clues, '[]'::jsonb) || jsonb_build_array(jsonb_build_object('id', clue.clue_id, 'title', clue.name, 'region', clue.region_id, 'found_at', now())),
      updated_at = now() WHERE owner_id = uid AND case_id = clue.chapter_id;
    txt := '사건의 단서를 찾았다 — 「' || clue.name || '」. ' || clue.description;
    xp := 20; payload := jsonb_build_object('chapter_id', clue.chapter_id, 'clue_id', clue.clue_id, 'clue_name', clue.name);
    UPDATE public.world_characters SET investigation_xp = investigation_xp + 15, investigation_rank = public.world_skill_rank(investigation_xp + 15, 'investigation') WHERE owner_id = uid;
  ELSIF outcome = 'regional' THEN
    SELECT s.site_id INTO site FROM public.world_region_sites s WHERE s.region_id = r.region_id ORDER BY s.site_id LIMIT 1;
    INSERT INTO public.world_case_progress(owner_id, case_id, clues) VALUES (uid, 'regional_discoveries', '[]'::jsonb) ON CONFLICT (owner_id, case_id) DO NOTHING;
    UPDATE public.world_case_progress SET clues = coalesce(clues, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'id', 'regional_' || coalesce(site, r.region_id), 'title', r.region_name || ' 답사 기록', 'region_id', r.region_id, 'site_id', coalesce(site, r.region_id), 'found_at', now(), 'source', 'search')),
      updated_at = now() WHERE owner_id = uid AND case_id = 'regional_discoveries';
    txt := '이 지역만의 흔적을 기록했다. 지역 답사 보고서에 쓸 수 있다.';
    xp := 10; payload := jsonb_build_object('region_id', r.region_id);
  ELSIF outcome = 'encounter' THEN
    battle := public.world_battle_open(uid, r.region_id, n.node_id, depth, c.level);
    IF battle IS NULL THEN outcome := 'quiet'; txt := '수상한 기척이 있었지만 이내 사라졌다.';
    ELSE
      txt := CASE WHEN (battle ->> 'rank') = 'guardian' THEN '땅이 울린다. 이 지역의 우두머리 ' || (battle ->> 'name') || '이(가) 앞을 막아섰다!'
                  WHEN (battle ->> 'rank') = 'elite' THEN '살기가 짙다. 정예 ' || (battle ->> 'name') || '이(가) 나타났다!'
                  ELSE (battle ->> 'name') || '이(가) 나타났다!' END;
      payload := battle;
    END IF;
  ELSIF outcome = 'cache' THEN
    it := (ARRAY['herb', 'travel_ration', 'tonic', 'seal_paper', 'wood', 'ore'])[1 + floor(random() * 6)::int];
    IF random() < 0.35 + depth * 0.08 THEN
      SELECT x INTO it FROM public.world_region_profiles p, unnest(p.signature_items) x JOIN public.world_item_catalog ic ON ic.item_id = x
        WHERE p.region_id = r.region_id AND (ic.tier <= 2 OR depth >= 3) AND x NOT IN ('courier_token', 'spirit_compass') ORDER BY random() LIMIT 1;
      it := coalesce(it, 'herb');
    END IF;
    qty := 1 + CASE WHEN random() < 0.3 + depth * 0.05 THEN 1 ELSE 0 END;
    gil_gain := floor(random() * (4 + r.danger_level * 2))::int;
    inv := public.world_inv_add(inv, it, qty);
    txt := (ARRAY['누군가 숨겨 둔 꾸러미에서 ', '쓰러진 짐수레 밑에서 ', '바위 틈 보따리에서 ', '버려진 야영지에서 '])[1 + floor(random() * 4)::int]
           || (SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || ' ×' || qty || CASE WHEN gil_gain > 0 THEN '와(과) ' || gil_gain || '전' ELSE '' END || '을(를) 챙겼다.';
    xp := 5; payload := jsonb_build_object('item_id', it, 'qty', qty, 'gil', gil_gain);
  ELSIF outcome = 'hazard' THEN
    IF random() < 0.3 + c.agility * 0.01 + c.perception * 0.005 THEN
      txt := (ARRAY['발밑의 덫을 알아채고 비켜섰다.', '무너지는 돌무더기를 아슬아슬하게 피했다.', '독기 어린 안개를 눈치채고 숨을 참고 지나갔다.'])[1 + floor(random() * 3)::int];
      xp := 6; payload := jsonb_build_object('avoided', true);
    ELSE
      hurt := 4 + floor(random() * (6 + depth * 2))::int;
      stkey := CASE theme WHEN 'city' THEN (ARRAY['sprain', 'stomach_upset'])[1 + floor(random() * 2)::int]
        WHEN 'wild' THEN (ARRAY['poisoned', 'bleeding'])[1 + floor(random() * 2)::int]
        WHEN 'shrine' THEN (ARRAY['erosion_whisper', 'shaken'])[1 + floor(random() * 2)::int]
        WHEN 'water' THEN (ARRAY['cold', 'poisoned'])[1 + floor(random() * 2)::int]
        WHEN 'mountain' THEN (ARRAY['cold', 'sprain'])[1 + floor(random() * 2)::int]
        WHEN 'desert' THEN (ARRAY['burned', 'exhausted'])[1 + floor(random() * 2)::int]
        WHEN 'deep' THEN (ARRAY['erosion_whisper', 'poisoned'])[1 + floor(random() * 2)::int]
        ELSE (ARRAY['disoriented', 'shaken'])[1 + floor(random() * 2)::int] END;
      PERFORM public.world_field_status(uid, stkey, 'explore');
      UPDATE public.world_characters SET health = greatest(1, health - hurt), updated_at = now() WHERE owner_id = uid;
      txt := (ARRAY['숨겨진 덫에 걸렸다.', '발을 헛디뎌 굴렀다.', '썩은 기운을 들이마셨다.', '날카로운 것에 베였다.'])[1 + floor(random() * 4)::int]
             || ' 체력 -' || hurt || ', ' || (SELECT status_name FROM public.world_status_catalog WHERE status_key = stkey) || '.';
      payload := jsonb_build_object('avoided', false, 'damage', hurt, 'status', stkey);
    END IF;
  ELSIF outcome = 'omen' THEN
    omen := 1 + floor(random() * 4)::int;
    IF omen = 1 THEN UPDATE public.world_characters SET mental = least(100, mental + 6) WHERE owner_id = uid; txt := '고요한 풍경에 마음이 가라앉았다. 정신 +6';
    ELSIF omen = 2 THEN UPDATE public.world_characters SET spiritual_power = least(100, spiritual_power + 6) WHERE owner_id = uid; txt := '영맥이 흐르는 자리를 지났다. 영력 +6';
    ELSIF omen = 3 THEN PERFORM public.world_field_status(uid, (ARRAY['keen_senses', 'fieldcraft', 'lucky_find', 'clear_mind'])[1 + floor(random() * 4)::int], 'explore');
      txt := '오래된 표식이 길을 일러 준다. 이로운 기운이 깃들었다.';
    ELSE txt := '벽에 새겨진 옛 글귀를 읽었다. ' || coalesce((SELECT signature_clue FROM public.world_region_profiles WHERE region_id = r.region_id), '이 땅의 옛 이야기다.'); xp := 10;
    END IF;
    payload := jsonb_build_object('omen', omen);
  ELSE
    txt := (ARRAY['바람 소리만 들린다. 아무것도 없었다.', '한참을 살폈지만 눈에 띄는 것이 없다.', '멀리서 무언가 울었지만 다가오지 않았다.'])[1 + floor(random() * 3)::int];
    xp := 3;
  END IF;

  UPDATE public.world_characters SET inventory = inv, gil = gil + gil_gain, experience = experience + xp, updated_at = now() WHERE owner_id = uid;
  INSERT INTO public.world_region_intel(owner_id, region_id, visits, surveyed_sites, last_visited_at, updated_at)
  VALUES (uid, r.region_id, 1, 0, now(), now())
  ON CONFLICT (owner_id, region_id) DO UPDATE SET
    visits = world_region_intel.visits + CASE WHEN world_region_intel.last_visited_at < now() - interval '1 hour' THEN 1 ELSE 0 END,
    surveyed_sites = world_region_intel.surveyed_sites + CASE WHEN outcome IN ('path', 'spot') THEN 1 ELSE 0 END,
    last_visited_at = now(), updated_at = now();

  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'explore', txt, payload || jsonb_build_object('kind', 'field_search', 'outcome', outcome, 'region_id', r.region_id,
    'node_id', n.node_id, 'danger', r.danger_level, 'location', c.location));

  RETURN jsonb_build_object('ok', true, 'outcome', outcome, 'content', txt, 'payload', payload, 'stamina', left_st,
    'battle', CASE WHEN outcome = 'encounter' THEN public.world_field_battle_view(uid) END);
END $f$;

-- ── 채집 ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.world_field_gather(p_spot_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_gathering_spots%rowtype;
  d public.world_gathering_discoveries%rowtype; it text; qty int; tool_bonus int := 0; inv jsonb; left_st int; prof_match boolean; nm text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태에서는 채집할 수 없습니다.'; END IF;
  IF c.travel_arrives_at IS NOT NULL AND c.travel_arrives_at > now() THEN RAISE EXCEPTION '이동 중에는 채집할 수 없습니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = uid AND NOT a.defeated AND NOT coalesce(a.fled, false)) THEN
    RAISE EXCEPTION '전투 중에는 채집할 수 없습니다.'; END IF;
  SELECT * INTO s FROM public.world_gathering_spots WHERE spot_id = p_spot_id AND active AND node_id = c.current_exploration_node_id;
  IF NOT FOUND THEN RAISE EXCEPTION '지금 있는 곳의 채집터가 아닙니다.'; END IF;
  SELECT * INTO d FROM public.world_gathering_discoveries WHERE owner_id = uid AND spot_id = s.spot_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '먼저 탐색으로 채집터를 찾으세요.'; END IF;
  IF d.last_gathered_at IS NOT NULL AND d.last_gathered_at > now() - interval '5 minutes' THEN
    RAISE EXCEPTION '%', format('이 채집터는 %s초 뒤에 다시 쓸 수 있습니다.', ceil(extract(epoch FROM d.last_gathered_at + interval '5 minutes' - now()))::int); END IF;
  IF c.level < s.min_level THEN RAISE EXCEPTION '%', format('레벨 %s부터 채집할 수 있습니다.', s.min_level); END IF;
  left_st := public.world_stamina_change(uid, -1);
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid;
  SELECT coalesce((i.equipment_traits ->> 'gathering_bonus_pct')::int, 0) INTO tool_bonus FROM public.world_character_equipment e
    JOIN public.world_item_catalog i ON i.item_id = e.item_id WHERE e.owner_id = uid AND e.slot = 'tool';
  it := s.loot_items[1 + floor(random() * cardinality(s.loot_items))::int];
  qty := s.yield_min + floor(random() * (s.yield_max - s.yield_min + 1))::int + coalesce(c.gathering_rank, 1) / 8;
  prof_match := (c.gathering_profession = 'mining' AND s.category = 'ore') OR (c.gathering_profession = 'botany' AND s.category = 'herbs')
    OR (c.gathering_profession = 'spirit_harvest' AND s.category = 'spirit') OR (c.gathering_profession = 'fishing' AND s.category = 'water')
    OR (c.gathering_profession = 'fieldwork' AND s.category IN ('wood', 'supplies', 'relics'));
  IF prof_match THEN qty := qty + 1; END IF;
  qty := greatest(1, round(qty * (1 + (coalesce(tool_bonus, 0) + public.world_status_effect_total('gather_qty_pct') + public.world_title_bonus('gather_qty_pct')) / 100.0)));
  inv := public.world_inv_add(c.inventory, it, qty);
  UPDATE public.world_characters SET inventory = inv, updated_at = now() WHERE owner_id = uid;
  UPDATE public.world_gathering_discoveries SET last_gathered_at = now(), gather_count = gather_count + 1 WHERE owner_id = uid AND spot_id = s.spot_id;
  SELECT item_name INTO nm FROM public.world_item_catalog WHERE item_id = it;
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'gather', s.spot_name || '에서 ' || nm || ' ×' || qty || ' 채집',
    jsonb_build_object('spot_id', s.spot_id, 'category', s.category, 'item_id', it, 'qty', qty, 'node_id', s.node_id,
      'node', CASE s.category WHEN 'ore' THEN 'ore' WHEN 'herbs' THEN 'herb' WHEN 'spirit' THEN 'shrine' ELSE 'field' END, 'profession_match', prof_match));
  RETURN jsonb_build_object('ok', true, 'content', s.spot_name || '에서 ' || nm || ' ×' || qty || '을(를) 얻었습니다.' || CASE WHEN prof_match THEN ' (전문 분야 +1)' ELSE '' END,
    'item_id', it, 'qty', qty, 'stamina', left_st, 'ready_at', now() + interval '5 minutes');
END $f$;

REVOKE ALL ON FUNCTION public.world_field_region(text), public.world_stamina_max(integer), public.world_stamina_now(integer, timestamptz, integer),
  public.world_stamina_change(uuid, integer), public.world_field_survey(uuid, text), public.world_field_status(uuid, text, text),
  public.world_inv_add(jsonb, text, integer), public.world_story_current(uuid), public.world_field_battle_view(uuid),
  public.world_battle_intent(text, numeric, text), public.world_battle_open(uuid, text, uuid, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.world_field_snapshot(), public.world_field_move(uuid), public.world_battle_action(text, text),
  public.world_field_search(), public.world_field_gather(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_field_snapshot(), public.world_field_move(uuid), public.world_battle_action(text, text),
  public.world_field_search(), public.world_field_gather(uuid) TO authenticated;
RESET ROLE;
