-- 주 이야기·상시 의뢰·옛 방식 차단 (postgres로 만든 뒤 fn_owner_field 소유로 넘긴다)

-- ── 이야기 현황 ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.world_story_board()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; cur text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  cur := public.world_story_current(uid);
  RETURN jsonb_build_object(
    'all_done', cur IS NULL,
    'chapters', (SELECT coalesce(jsonb_agg(jsonb_build_object('chapter_id', ch.chapter_id, 'seq', ch.seq, 'title', ch.title, 'summary', ch.summary,
        'intro', ch.intro, 'outro', ch.outro, 'min_level', ch.min_level, 'rewards', ch.rewards,
        'status', CASE WHEN cur IS NULL OR ch.seq < (SELECT seq FROM public.world_story_chapters WHERE chapter_id = cur) THEN 'done'
                       WHEN ch.chapter_id = cur AND c.level >= ch.min_level THEN 'active' ELSE 'locked' END,
        'locked_reason', CASE WHEN ch.chapter_id = cur AND c.level < ch.min_level THEN 'level' ELSE 'prev' END,
        'clues', (SELECT coalesce(jsonb_agg(jsonb_build_object('clue_id', k.clue_id, 'name', k.name, 'tag', k.tag, 'region_id', k.region_id,
              'region_name', (SELECT region_name FROM public.world_map_regions WHERE region_id = k.region_id), 'description', k.description,
              'found', EXISTS (SELECT 1 FROM public.world_case_progress p WHERE p.owner_id = uid AND p.case_id = ch.chapter_id
                               AND p.clues @> jsonb_build_array(jsonb_build_object('id', k.clue_id))))
            ORDER BY k.sort), '[]'::jsonb) FROM public.world_story_clues k WHERE k.chapter_id = ch.chapter_id),
        'combos', (SELECT coalesce(jsonb_agg(jsonb_build_object('combo_id', x.combo_id, 'name', x.name, 'needs', x.needs, 'description', x.description,
              'conclusion', x.conclusion,
              'done', EXISTS (SELECT 1 FROM public.world_case_progress p WHERE p.owner_id = uid AND p.case_id = ch.chapter_id AND p.combined ? x.combo_id))
            ORDER BY x.sort), '[]'::jsonb) FROM public.world_story_combos x WHERE x.chapter_id = ch.chapter_id))
      ORDER BY ch.seq), '[]'::jsonb) FROM public.world_story_chapters ch),
    'regional', jsonb_build_object(
      'clues', (SELECT count(*) FROM public.world_case_progress p, jsonb_array_elements(coalesce(p.clues, '[]'::jsonb)) cl
                WHERE p.owner_id = uid AND p.case_id = 'regional_discoveries' AND coalesce(cl ->> 'site_id', '') <> ''),
      'regions', (SELECT count(DISTINCT cl ->> 'region_id') FROM public.world_case_progress p, jsonb_array_elements(coalesce(p.clues, '[]'::jsonb)) cl
                  WHERE p.owner_id = uid AND p.case_id = 'regional_discoveries' AND coalesce(cl ->> 'site_id', '') <> ''),
      'submitted', EXISTS (SELECT 1 FROM public.world_regional_case_claims WHERE owner_id = uid AND claim_key = 'regional_route_complete')));
END $f$;

-- ── 가설 세우기: 짝이 맞는 단서가 모두 있으면 결론을 확정한다. 장의 가설을 모두 세우면 장이 끝난다 ─────
CREATE OR REPLACE FUNCTION public.world_story_combine(p_combo_id text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; x public.world_story_combos%rowtype; ch public.world_story_chapters%rowtype;
  p public.world_case_progress%rowtype; need text; inv jsonb; k text; q int; done_all boolean; marker text; rw jsonb; msg text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '쓰러진 상태에서는 추리할 수 없습니다.'; END IF;
  SELECT * INTO x FROM public.world_story_combos WHERE combo_id = p_combo_id;
  IF NOT FOUND THEN RAISE EXCEPTION '알 수 없는 가설입니다.'; END IF;
  SELECT * INTO ch FROM public.world_story_chapters WHERE chapter_id = x.chapter_id;
  IF public.world_story_current(uid) IS DISTINCT FROM ch.chapter_id THEN RAISE EXCEPTION '지금 진행 중인 장의 가설이 아닙니다.'; END IF;
  SELECT * INTO p FROM public.world_case_progress WHERE owner_id = uid AND case_id = ch.chapter_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '먼저 단서를 찾으세요.'; END IF;
  IF p.combined ? x.combo_id THEN RAISE EXCEPTION '이미 확정한 가설입니다.'; END IF;
  FOREACH need IN ARRAY x.needs LOOP
    IF NOT p.clues @> jsonb_build_array(jsonb_build_object('id', need)) THEN RAISE EXCEPTION '필요한 단서가 모자랍니다.'; END IF;
  END LOOP;
  UPDATE public.world_case_progress SET combined = coalesce(combined, '[]'::jsonb) || jsonb_build_array(x.combo_id), updated_at = now()
  WHERE owner_id = uid AND case_id = ch.chapter_id RETURNING * INTO p;
  UPDATE public.world_characters SET investigation_xp = investigation_xp + 25, investigation_rank = public.world_skill_rank(investigation_xp + 25, 'investigation') WHERE owner_id = uid;
  PERFORM public.world_grant_xp(uid, 20 + ch.min_level * 4);
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'case_combine', '가설 확정: ' || x.name, jsonb_build_object('v2', true, 'case_id', ch.chapter_id, 'combination', x.combo_id));
  msg := '가설 확정: ' || x.name || '. ' || x.conclusion;
  done_all := NOT EXISTS (SELECT 1 FROM public.world_story_combos y WHERE y.chapter_id = ch.chapter_id AND NOT (p.combined ? y.combo_id));
  IF done_all THEN
    marker := CASE WHEN ch.chapter_id = 'red_seal' THEN 'redseal_case_completed' ELSE ch.chapter_id || '_completed' END;
    UPDATE public.world_case_progress SET combined = combined || jsonb_build_array(marker), updated_at = now() WHERE owner_id = uid AND case_id = ch.chapter_id;
    rw := ch.rewards;
    SELECT inventory INTO inv FROM public.world_characters WHERE owner_id = uid;
    FOR k, q IN SELECT key, value::text::int FROM jsonb_each(coalesce(rw -> 'items', '{}'::jsonb)) LOOP inv := public.world_inv_add(inv, k, q); END LOOP;
    UPDATE public.world_characters SET inventory = inv, gil = gil + coalesce((rw ->> 'gil')::int, 0),
      bag_capacity = least(400, bag_capacity + coalesce((rw ->> 'bag')::int, 0)), updated_at = now() WHERE owner_id = uid;
    PERFORM public.world_grant_xp(uid, coalesce((rw ->> 'xp')::int, 0));
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'story', ch.seq || '장 「' || ch.title || '」 해결', jsonb_build_object('v2', true, 'chapter_id', ch.chapter_id));
    INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
    VALUES (uid, 'reward', ch.seq || '장 해결 · ' || ch.title, ch.outro || ' 보상: ' || coalesce(rw ->> 'text', ''), jsonb_build_object('chapter_id', ch.chapter_id));
    msg := msg || ' — ' || ch.seq || '장을 마쳤습니다! ' || coalesce(rw ->> 'text', '');
  END IF;
  RETURN jsonb_build_object('ok', true, 'content', msg, 'chapter_done', done_all);
END $f$;

-- ── 상시 의뢰: 하루에 세 가지(한국 시각 자정에 바뀐다) ───────────────────────
CREATE OR REPLACE FUNCTION public.world_commission_board()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; today date := (now() AT TIME ZONE 'Asia/Seoul')::date;
  reg public.world_map_regions%rowtype; it text; q int; price int;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.world_commissions WHERE owner_id = uid AND day = today) THEN
    DELETE FROM public.world_commissions WHERE owner_id = uid AND day < today - 3;
    SELECT * INTO reg FROM public.world_map_regions WHERE active AND NOT is_safe_zone AND min_level <= c.level AND min_level >= c.level - 10
      ORDER BY md5(uid::text || today::text || region_id) LIMIT 1;
    IF reg.region_id IS NULL THEN SELECT * INTO reg FROM public.world_map_regions WHERE region_id = 'field_outskirts'; END IF;
    INSERT INTO public.world_commissions(owner_id, day, slot, kind, title, description, target_region, need, reward_gil, reward_xp)
    VALUES (uid, today, 1, 'hunt', reg.region_name || ' 요괴 토벌', reg.region_name || '에서 요괴를 쓰러뜨리세요.', reg.region_id, 3, 40 + c.level * 6, 30 + c.level * 5);
    INSERT INTO public.world_commissions(owner_id, day, slot, kind, title, description, target_region, need, reward_gil, reward_xp)
    SELECT uid, today, 2, k, t, d, NULL, n, 30 + c.level * 4, 25 + c.level * 4
    FROM (VALUES ('gather', '채집 의뢰', '아무 지역의 채집터에서 다섯 번 채집하세요.', 5), ('search', '정찰 의뢰', '바깥 지역을 여덟 번 탐색하세요.', 8)) v(k, t, d, n)
    ORDER BY md5(uid::text || today::text || k) LIMIT 1;
    it := (ARRAY['herb', 'wood', 'ore', 'seal_paper', 'river_reed', 'spirit_dust', 'resin', 'beast_bone'])[1 + abs(hashtext(uid::text || today::text)) % 8];
    q := 4 + abs(hashtext(today::text || uid::text)) % 5;
    SELECT coalesce(reference_price, 20) INTO price FROM public.world_item_catalog WHERE item_id = it;
    INSERT INTO public.world_commissions(owner_id, day, slot, kind, title, description, target_item, need, reward_gil, reward_xp)
    VALUES (uid, today, 3, 'deliver', (SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || ' 납품',
      '게시판 담당자에게 ' || (SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || ' ' || q || '개를 건네세요. 안전지대에서 납품합니다.',
      it, q, round(price * q * 1.4)::int, 20 + c.level * 3);
  END IF;
  RETURN jsonb_build_object('day', today, 'resets_at', ((today + 1)::timestamp AT TIME ZONE 'Asia/Seoul'),
    'items', (SELECT coalesce(jsonb_agg(jsonb_build_object('slot', m.slot, 'kind', m.kind, 'title', m.title, 'description', m.description,
        'need', m.need, 'progress', CASE WHEN m.kind = 'deliver' THEN least(m.need, coalesce((c.inventory ->> m.target_item)::int, 0)) ELSE m.progress END,
        'reward_gil', m.reward_gil, 'reward_xp', m.reward_xp, 'reward_item', m.reward_item, 'claimed', m.claimed_at IS NOT NULL) ORDER BY m.slot), '[]'::jsonb)
      FROM public.world_commissions m WHERE m.owner_id = uid AND m.day = today));
END $f$;

CREATE OR REPLACE FUNCTION public.world_commission_claim(p_slot integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; m public.world_commissions%rowtype; today date := (now() AT TIME ZONE 'Asia/Seoul')::date;
  r public.world_map_regions%rowtype; inv jsonb;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  SELECT * INTO m FROM public.world_commissions WHERE owner_id = uid AND day = today AND slot = p_slot FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '오늘의 의뢰가 아닙니다.'; END IF;
  IF m.claimed_at IS NOT NULL THEN RAISE EXCEPTION '이미 보상을 받았습니다.'; END IF;
  inv := coalesce(c.inventory, '{}'::jsonb);
  IF m.kind = 'deliver' THEN
    r := public.world_field_region(c.location);
    IF r.region_id IS NULL OR NOT r.is_safe_zone THEN RAISE EXCEPTION '납품은 안전지대에서 합니다.'; END IF;
    IF coalesce((inv ->> m.target_item)::int, 0) < m.need THEN RAISE EXCEPTION '납품할 물품이 모자랍니다.'; END IF;
    inv := public.world_inv_add(inv, m.target_item, -m.need);
  ELSIF m.progress < m.need THEN RAISE EXCEPTION '아직 의뢰를 마치지 못했습니다.';
  END IF;
  UPDATE public.world_commissions SET claimed_at = now(), progress = need WHERE owner_id = uid AND day = today AND slot = p_slot;
  UPDATE public.world_characters SET inventory = inv, gil = gil + m.reward_gil, updated_at = now() WHERE owner_id = uid;
  PERFORM public.world_grant_xp(uid, m.reward_xp);
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'commission', '의뢰 완료: ' || m.title, jsonb_build_object('slot', p_slot, 'gil', m.reward_gil, 'xp', m.reward_xp));
  RETURN jsonb_build_object('ok', true, 'content', '의뢰 완료: ' || m.title || ' · ' || m.reward_gil || '전, 경험치 ' || m.reward_xp);
END $f$;

-- 의뢰 진행: 토벌·채집·탐색 기록이 쌓일 때마다 오늘의 의뢰에 반영한다
CREATE OR REPLACE FUNCTION public.world_track_commissions()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE today date := (now() AT TIME ZONE 'Asia/Seoul')::date; p jsonb := coalesce(new.payload, '{}'::jsonb);
BEGIN
  IF new.actor_id IS NULL THEN RETURN new; END IF;
  IF new.event_type = 'combat' AND coalesce((p ->> 'defeated')::boolean, false) THEN
    UPDATE public.world_commissions SET progress = least(need, progress + 1)
    WHERE owner_id = new.actor_id AND day = today AND kind = 'hunt' AND claimed_at IS NULL AND (target_region IS NULL OR target_region = p ->> 'region_id');
  ELSIF new.event_type = 'gather' THEN
    UPDATE public.world_commissions SET progress = least(need, progress + 1) WHERE owner_id = new.actor_id AND day = today AND kind = 'gather' AND claimed_at IS NULL;
  ELSIF new.event_type = 'explore' AND p ->> 'kind' = 'field_search' THEN
    UPDATE public.world_commissions SET progress = least(need, progress + 1) WHERE owner_id = new.actor_id AND day = today AND kind = 'search' AND claimed_at IS NULL;
  END IF;
  RETURN new;
END $f$;

-- 옛 방식 행동 차단: 탐색력·전투 규칙을 거치지 않는 이전 RPC는 기록 단계에서 막는다
CREATE OR REPLACE FUNCTION public.world_guard_legacy_actions()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE k text := coalesce(new.event_type, ''); p jsonb := coalesce(new.payload, '{}'::jsonb); legacy boolean := false;
BEGIN
  IF new.actor_id IS NULL THEN RETURN new; END IF;
  legacy := k IN ('encounter', 'exploration_move', 'self_recovery')
    OR (k = 'combat' AND NOT p ? 'turns')
    OR (k = 'gather' AND NOT p ? 'profession_match')
    OR (k = 'explore' AND coalesce(p ->> 'kind', '') <> 'field_search')
    OR (k = 'use_item' AND NOT p ? 'v2')
    OR (k = 'mission' AND p ? 'gathering_profession' AND NOT p ? 'v2')
    OR (k LIKE 'expedition%' AND p ? 'ground_id')
    OR (k IN ('case_combine', 'investigation') AND coalesce(p ->> 'case_id', '') = 'red_seal' AND NOT p ? 'v2')
    OR (k = 'story' AND NOT p ? 'v2');
  IF legacy THEN RAISE EXCEPTION '이전 방식의 행동입니다. 화면을 새로고침한 뒤 다시 시도하세요.'; END IF;
  RETURN new;
END $f$;

-- 실행 권한과 소유권: 함수 전용 역할로 넘긴다
REVOKE ALL ON FUNCTION public.world_story_board() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_story_board() TO authenticated;
ALTER FUNCTION public.world_story_board() OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_story_combine(p_combo_id text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_story_combine(p_combo_id text) TO authenticated;
ALTER FUNCTION public.world_story_combine(p_combo_id text) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_commission_board() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_commission_board() TO authenticated;
ALTER FUNCTION public.world_commission_board() OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_commission_claim(p_slot integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_commission_claim(p_slot integer) TO authenticated;
ALTER FUNCTION public.world_commission_claim(p_slot integer) OWNER TO fn_owner_field;
