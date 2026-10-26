-- 탐색·전투 공용 도우미: 지역 찾기·탐색력·답사율·상태이상·경험치·사망 처리
-- ── 공용 도우미 ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.world_field_region(p_location text)
 RETURNS public.world_map_regions LANGUAGE sql STABLE SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT r.* FROM public.world_map_regions r
  WHERE r.region_name = p_location OR r.region_id = p_location
     OR (r.region_id = 'hq_yard' AND p_location IN ('본부 로비', '야행국 본부 · 정청', '야행국 본부 · 로비'))
  ORDER BY (r.region_name = p_location) DESC LIMIT 1
$f$;



-- 탐색력은 6분마다 1씩 찬다.


CREATE OR REPLACE FUNCTION public.world_stamina_change(p_owner uuid, p_delta integer)
 RETURNS integer LANGUAGE plpgsql SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE c public.world_characters%rowtype; cur int; mx int; ticks int; nxt int; base_at timestamptz;
BEGIN
  SELECT * INTO c FROM public.world_characters WHERE owner_id = p_owner FOR UPDATE;
  mx := public.world_stamina_max(c.level);
  ticks := floor(greatest(0, extract(epoch FROM now() - c.stamina_at)) / 360)::int;
  cur := least(mx, greatest(0, c.stamina) + ticks);
  IF cur + p_delta < 0 THEN
    RAISE EXCEPTION '%', format('탐색력이 부족합니다. %s분 뒤에 1 회복됩니다.',
      greatest(1, ceil((360 - mod(greatest(0, extract(epoch FROM now() - c.stamina_at))::numeric, 360)) / 60)::int));
  END IF;
  nxt := least(mx, cur + p_delta);
  -- 가득 차 있었다면 지금부터, 아니면 차오르던 진행분을 살린다.
  base_at := CASE WHEN cur >= mx THEN now() ELSE c.stamina_at + make_interval(secs => ticks * 360) END;
  UPDATE public.world_characters SET stamina = nxt, stamina_at = base_at, updated_at = now() WHERE owner_id = p_owner;
  RETURN nxt;
END $f$;

CREATE OR REPLACE FUNCTION public.world_field_survey(p_owner uuid, p_region text)
 RETURNS jsonb LANGUAGE sql STABLE SET search_path TO 'pg_catalog', 'public'
AS $f$
  WITH n AS (SELECT count(*) total, count(d.node_id) found FROM public.world_exploration_nodes x
             LEFT JOIN public.world_exploration_discoveries d ON d.node_id = x.node_id AND d.owner_id = p_owner
             WHERE x.region_id = p_region AND x.hierarchy_level >= 2),
       s AS (SELECT count(*) total, count(d.spot_id) found FROM public.world_gathering_spots x
             JOIN public.world_exploration_nodes y ON y.node_id = x.node_id
             LEFT JOIN public.world_gathering_discoveries d ON d.spot_id = x.spot_id AND d.owner_id = p_owner
             WHERE y.region_id = p_region AND x.active)
  SELECT jsonb_build_object('nodes_found', n.found, 'nodes_total', n.total, 'spots_found', s.found, 'spots_total', s.total,
    'pct', CASE WHEN n.total + s.total = 0 THEN 0 ELSE floor(100.0 * (n.found + s.found) / (n.total + s.total))::int END)
  FROM n, s
$f$;

-- 상태이상 부여(동시에 최대 10개). 같은 효과는 시간을 늘린다.
CREATE OR REPLACE FUNCTION public.world_field_status(p_owner uuid, p_key text, p_source text)
 RETURNS boolean LANGUAGE plpgsql SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE st public.world_status_catalog%rowtype; ex public.world_character_statuses%rowtype; cnt int;
BEGIN
  SELECT * INTO st FROM public.world_status_catalog WHERE status_key = p_key AND active;
  IF NOT FOUND THEN RETURN false; END IF;
  DELETE FROM public.world_character_statuses WHERE owner_id = p_owner AND expires_at <= now();
  SELECT * INTO ex FROM public.world_character_statuses WHERE owner_id = p_owner AND status_key = p_key ORDER BY expires_at DESC LIMIT 1 FOR UPDATE;
  IF FOUND THEN
    UPDATE public.world_character_statuses SET stacks = least(st.max_stacks, stacks + 1), potency = least(3, potency + 1),
      expires_at = greatest(expires_at, now()) + make_interval(mins => least(st.duration_minutes, 15)) WHERE status_id = ex.status_id;
    RETURN true;
  END IF;
  SELECT count(*) INTO cnt FROM public.world_character_statuses WHERE owner_id = p_owner;
  IF cnt >= 10 THEN RETURN false; END IF;
  INSERT INTO public.world_character_statuses(owner_id, status_key, source_activity, expires_at, metadata)
  VALUES (p_owner, p_key, p_source, now() + make_interval(mins => st.duration_minutes), '{}'::jsonb);
  RETURN true;
END $f$;

-- 가방에 물품 더하기(가방 용량은 기존 트리거가 다듬고 알린다)
CREATE OR REPLACE FUNCTION public.world_inv_add(p_inv jsonb, p_item text, p_qty integer)
 RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO 'pg_catalog'
AS $f$ SELECT jsonb_set(coalesce(p_inv, '{}'::jsonb), ARRAY[p_item], to_jsonb(coalesce((p_inv ->> p_item)::int, 0) + p_qty), true) $f$;

-- ── 이야기: 현재 장과 이 지역에서 찾을 단서 ─────────────────────────
CREATE OR REPLACE FUNCTION public.world_story_current(p_owner uuid)
 RETURNS text LANGUAGE sql STABLE SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT ch.chapter_id FROM public.world_story_chapters ch
  WHERE NOT EXISTS (SELECT 1 FROM public.world_case_progress p WHERE p.owner_id = p_owner AND p.case_id = ch.chapter_id
                    AND (p.combined ? (ch.chapter_id || '_completed') OR (ch.chapter_id = 'red_seal' AND p.combined ? 'redseal_case_completed')))
  ORDER BY ch.seq LIMIT 1
$f$;


-- 경험치를 더하고 레벨을 올린다(진행 트리거와 같은 규칙: 레벨×100, 레벨마다 능력치 3·체력 10·정신 5·영력 5).
CREATE OR REPLACE FUNCTION public.world_grant_xp(p_owner uuid, p_xp integer)
 RETURNS integer LANGUAGE plpgsql SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE lv int; xp int; gained int := 0;
BEGIN
  SELECT level, experience + greatest(0, coalesce(p_xp, 0)) INTO lv, xp FROM public.world_characters WHERE owner_id = p_owner FOR UPDATE;
  IF lv IS NULL THEN RETURN 0; END IF;
  WHILE lv < 100 AND xp >= lv * 100 LOOP xp := xp - lv * 100; lv := lv + 1; gained := gained + 1; END LOOP;
  IF lv >= 100 THEN xp := 0; END IF;
  UPDATE public.world_characters SET level = lv, experience = xp, stat_points = least(297, stat_points + gained * 3),
    health = CASE WHEN downed_at IS NULL THEN least(100, health + gained * 10) ELSE health END,
    mental = least(100, mental + gained * 5), spiritual_power = least(100, spiritual_power + gained * 5), updated_at = now()
  WHERE owner_id = p_owner;
  RETURN gained;
END $f$;

-- 전투불능으로 4시간이 지나도록 일어나지 못한 조사원은 숨을 거두고, 그 자리에 시신과 유품이 남는다.
-- 거래할 수 없는 물품은 유품으로 남기지 않는다.
CREATE OR REPLACE FUNCTION public.world_death_sweep()
 RETURNS integer LANGUAGE plpgsql SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE c record; n int := 0; r public.world_map_regions%rowtype; items jsonb;
BEGIN
  FOR c IN SELECT * FROM public.world_characters WHERE downed_at IS NOT NULL AND NOT coalesce(is_dead, false)
             AND downed_at < now() - interval '4 hours' FOR UPDATE SKIP LOCKED LOOP
    r := public.world_field_region(c.location);
    SELECT coalesce(jsonb_object_agg(k, v), '{}'::jsonb) INTO items
    FROM jsonb_each(coalesce(c.inventory, '{}'::jsonb)) e(k, v)
    JOIN public.world_item_catalog i ON i.item_id = e.k
    WHERE jsonb_typeof(v) = 'number' AND v::text::int > 0 AND coalesce(i.tradeable, true);
    INSERT INTO public.world_corpses(owner_id, character_name, location, region_id, died_at, death_reason, items, gil)
    VALUES (c.owner_id, c.character_name, c.location, r.region_id, now(), '구조받지 못한 채 숨을 거두었다', items, greatest(0, c.gil / 2));
    UPDATE public.world_characters SET is_dead = true, died_at = now(), death_reason = '구조받지 못한 채 숨을 거두었다',
      health = 0, updated_at = now() WHERE owner_id = c.owner_id;
    DELETE FROM public.world_active_encounters WHERE owner_id = c.owner_id;
    INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
    VALUES (c.owner_id, 'death', '숨을 거두었습니다', c.character_name || '은(는) 구조를 받지 못하고 ' || c.location || '에서 숨을 거두었습니다.', jsonb_build_object('location', c.location));
    n := n + 1;
  END LOOP;
  RETURN n;
END $f$;

-- 실행 권한과 소유권: 함수 전용 역할로 넘긴다
REVOKE ALL ON FUNCTION public.world_field_region(p_location text) FROM PUBLIC;
ALTER FUNCTION public.world_field_region(p_location text) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_stamina_change(p_owner uuid, p_delta integer) FROM PUBLIC;
ALTER FUNCTION public.world_stamina_change(p_owner uuid, p_delta integer) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_field_survey(p_owner uuid, p_region text) FROM PUBLIC;
ALTER FUNCTION public.world_field_survey(p_owner uuid, p_region text) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_field_status(p_owner uuid, p_key text, p_source text) FROM PUBLIC;
ALTER FUNCTION public.world_field_status(p_owner uuid, p_key text, p_source text) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_inv_add(p_inv jsonb, p_item text, p_qty integer) FROM PUBLIC;
ALTER FUNCTION public.world_inv_add(p_inv jsonb, p_item text, p_qty integer) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_story_current(p_owner uuid) FROM PUBLIC;
ALTER FUNCTION public.world_story_current(p_owner uuid) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_grant_xp(p_owner uuid, p_xp integer) FROM PUBLIC;
ALTER FUNCTION public.world_grant_xp(p_owner uuid, p_xp integer) OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_death_sweep() FROM PUBLIC;
ALTER FUNCTION public.world_death_sweep() OWNER TO fn_owner_field;
