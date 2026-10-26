-- 야행국 2차 라이브 테스트 반영 (서버 로직): 앞선 frontier 스키마 마이그레이션의 테이블·열을 사용한다.
-- ── B. 전용 최소 권한 역할 ─────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fn_owner_expedition') THEN
    CREATE ROLE fn_owner_expedition NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fn_owner_social') THEN
    CREATE ROLE fn_owner_social NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
END $$;
GRANT USAGE ON SCHEMA public TO fn_owner_expedition, fn_owner_social;
GRANT EXECUTE ON FUNCTION public.fn_owner_auth_uid() TO fn_owner_expedition, fn_owner_social;
GRANT EXECUTE ON FUNCTION public.world_skill_rank(integer, text) TO fn_owner_expedition;
GRANT SELECT ON public.world_map_regions, public.world_region_monsters, public.world_region_sites, public.world_item_catalog,
  public.world_character_equipment, public.world_expedition_grounds, public.world_mount_catalog, public.world_idle_activities,
  public.world_active_encounters, public.world_major_factions TO fn_owner_expedition;
GRANT SELECT, INSERT, UPDATE ON public.world_region_progress, public.world_expeditions, public.world_case_progress TO fn_owner_expedition;
GRANT SELECT, INSERT ON public.world_owned_mounts TO fn_owner_expedition;
GRANT INSERT ON public.world_events, public.world_notifications TO fn_owner_expedition;
GRANT USAGE ON SEQUENCE public.world_events_id_seq, public.world_notifications_id_seq TO fn_owner_expedition;
GRANT SELECT ON public.world_characters TO fn_owner_expedition;
GRANT UPDATE (health, mental, erosion, erosion_stage, experience, level, stat_points, spiritual_power, combat_xp, combat_rank,
  gathering_xp, gathering_rank, investigation_xp, investigation_rank, gil, inventory, bag_capacity, profile, updated_at)
  ON public.world_characters TO fn_owner_expedition;
-- 같은 지역 조사원·파티 조회용: 공개해도 되는 열만
GRANT SELECT (owner_id, character_name, location, health, level, job_key, faction_key, major_faction_id, downed_at, is_dead, profile, updated_at)
  ON public.world_characters TO fn_owner_social;
GRANT SELECT ON public.world_parties, public.world_party_members, public.world_party_invites, public.world_party_loot_pool,
  public.world_active_encounters, public.world_expeditions, public.world_title_catalog, public.world_character_titles TO fn_owner_social;

GRANT fn_owner_expedition TO postgres WITH SET TRUE;
GRANT fn_owner_social TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_expedition, fn_owner_social;

SET ROLE fn_owner_expedition;

-- 위치 문자열 → 지역 (옛 본부 지명 포함)
CREATE OR REPLACE FUNCTION public.world_region_at(p_location text)
 RETURNS public.world_map_regions
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT r.* FROM public.world_map_regions r
  WHERE r.region_name = p_location OR r.region_id = p_location
     OR (r.region_id = 'hq_yard' AND p_location IN ('본부 로비', '야행국 본부 · 정청', '야행국 본부 · 로비'))
  ORDER BY (r.region_name = p_location) DESC LIMIT 1
$f$;

CREATE OR REPLACE FUNCTION public.world_bag_limit(p_owner uuid)
 RETURNS integer
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT c.bag_capacity + CASE WHEN c.major_faction_id = 'river_alliance' THEN 20 ELSE 0 END
  FROM public.world_characters c WHERE c.owner_id = p_owner
$f$;

CREATE OR REPLACE FUNCTION public.world_bag_count(p_inv jsonb)
 RETURNS integer
 LANGUAGE sql IMMUTABLE SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT coalesce(sum(greatest(0, CASE WHEN jsonb_typeof(v) = 'number' THEN v::text::numeric ELSE 0 END)), 0)::int
  FROM jsonb_each(coalesce(p_inv, '{}'::jsonb)) AS t(k, v)
$f$;

-- 가방 용량: 교환(재화나 물품을 내주고 받는 경우)으로 초과하면 거절, 단순 획득으로 초과하면 넘치는 만큼 버리고 알린다.
CREATE OR REPLACE FUNCTION public.world_enforce_bag_capacity()
 RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE
  cap int := new.bag_capacity + CASE WHEN new.major_faction_id = 'river_alliance' THEN 20 ELSE 0 END;
  old_total int := public.world_bag_count(old.inventory);
  new_total int := public.world_bag_count(new.inventory);
  allowed int; over int; k text; inc int; cut int; dropped jsonb := '{}'::jsonb; exchange boolean;
BEGIN
  IF new_total <= cap OR new_total <= old_total THEN RETURN new; END IF;
  allowed := greatest(cap, old_total);
  IF new_total <= allowed THEN RETURN new; END IF;
  exchange := new.gil < old.gil OR EXISTS (
    SELECT 1 FROM jsonb_each(coalesce(old.inventory, '{}'::jsonb)) o(k, v)
    WHERE jsonb_typeof(o.v) = 'number' AND coalesce((new.inventory ->> o.k)::numeric, 0) < o.v::text::numeric);
  IF exchange THEN
    RAISE EXCEPTION '가방이 가득 찼습니다 (%/%칸). 물품을 정리한 뒤 다시 시도하세요.', new_total, cap USING errcode = 'P0001';
  END IF;
  over := new_total - allowed;
  FOR k, inc IN
    SELECT n.k, (n.v::text::numeric - coalesce((old.inventory ->> n.k)::numeric, 0))::int
    FROM jsonb_each(new.inventory) n(k, v)
    WHERE jsonb_typeof(n.v) = 'number' AND n.v::text::numeric > coalesce((old.inventory ->> n.k)::numeric, 0)
    ORDER BY n.k DESC
  LOOP
    EXIT WHEN over <= 0;
    cut := least(inc, over);
    new.inventory := jsonb_set(new.inventory, ARRAY[k], to_jsonb((new.inventory ->> k)::int - cut));
    dropped := jsonb_set(dropped, ARRAY[k], to_jsonb(cut));
    over := over - cut;
  END LOOP;
  INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
  VALUES (new.owner_id, 'bag_full', '가방이 가득 찼습니다',
    (SELECT string_agg(coalesce(i.item_name, d.k) || ' ×' || d.v, ', ') FROM jsonb_each_text(dropped) d(k, v) LEFT JOIN public.world_item_catalog i ON i.item_id = d.k)
      || '을(를) 챙기지 못했습니다. 가방을 정리하거나 용량을 늘리세요.',
    jsonb_build_object('dropped', dropped, 'capacity', cap));
  RETURN new;
END
$f$;

-- 행동 가능 여부(안전지대·원정 중) 검사: 거의 모든 행동이 world_events를 남기므로 기록 직전에 한곳에서 막는다.
CREATE OR REPLACE FUNCTION public.world_guard_action_context()
 RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE
  c public.world_characters%rowtype; r public.world_map_regions%rowtype; m public.world_mount_catalog%rowtype;
  k text := coalesce(new.event_type, ''); p jsonb := coalesce(new.payload, '{}'::jsonb);
  away boolean; passenger uuid;
BEGIN
  IF new.actor_id IS NULL THEN RETURN new; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = new.actor_id;
  IF NOT FOUND THEN RETURN new; END IF;
  r := public.world_region_at(c.location);

  -- 원정 중에는 현장 행동 불가 (스탯 분배·임무 보상·사건 추론·거래 취소·도착 처리는 허용)
  away := EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = new.actor_id AND e.status = 'active');
  IF k = 'travel' AND p ? 'passenger_id' THEN
    passenger := nullif(p ->> 'passenger_id', '')::uuid;
    IF EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = passenger AND e.status = 'active') THEN
      RAISE EXCEPTION '동승자가 원정 중이라 함께 출발할 수 없습니다.';
    END IF;
  END IF;
  IF away AND NOT (
       k IN ('progression', 'mission', 'supply', 'case_combine', 'case_resolved', 'loot')
    OR k LIKE 'expedition%'
    OR (k = 'trade' AND NOT (p ? 'unit_price') AND NOT (p ? 'gil'))
    OR (k = 'travel' AND p ? 'travel_history_id')) THEN
    RAISE EXCEPTION '원정 중에는 할 수 없습니다. 원정을 마치거나 귀환한 뒤 다시 시도하세요.';
  END IF;

  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN ('encounter', 'combat') THEN
    RAISE EXCEPTION '안전지대에서는 요괴 수색과 전투를 할 수 없습니다.';
  END IF;
  IF k IN ('shop_buy', 'shop_sell') AND (r.region_id IS NULL OR NOT r.is_safe_zone OR r.shop_id IS NULL) THEN
    RAISE EXCEPTION '상점은 안전지대에만 있습니다.';
  END IF;
  IF k = 'trade' AND (p ? 'unit_price' OR p ? 'gil') AND (r.region_id IS NULL OR NOT r.is_safe_zone) THEN
    RAISE EXCEPTION '거래소는 안전지대에서만 이용할 수 있습니다.';
  END IF;
  IF k = 'mount' AND p ? 'price' THEN
    SELECT * INTO m FROM public.world_mount_catalog WHERE mount_id = p ->> 'mount_id';
    IF m.acquire_method = 'event' THEN RAISE EXCEPTION '이 탈것은 특별한 사건으로만 얻을 수 있습니다.'; END IF;
    IF r.region_id IS NULL OR NOT r.has_stable THEN RAISE EXCEPTION '탈것은 안전지대의 마구간에서만 구할 수 있습니다.'; END IF;
  END IF;
  RETURN new;
END
$f$;

CREATE OR REPLACE FUNCTION public.world_guard_idle_during_expedition()
 RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
BEGIN
  IF new.status = 'active' AND EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = new.owner_id AND e.status = 'active') THEN
    RAISE EXCEPTION '원정 중에는 자율 활동을 시작할 수 없습니다.';
  END IF;
  RETURN new;
END
$f$;

-- 사건 해결 보상: 가방 확장과 특별 탈것
CREATE OR REPLACE FUNCTION public.world_reward_case_resolution()
 RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
BEGIN
  IF TG_TABLE_NAME = 'world_regional_case_claims' THEN
    UPDATE public.world_characters SET bag_capacity = least(400, bag_capacity + 20), updated_at = now() WHERE owner_id = new.owner_id;
    INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
    VALUES (new.owner_id, 'reward', '가방이 넓어졌습니다', '지역 답사 보고서를 제출한 공로로 가방 용량이 20칸 늘었습니다.', '{}'::jsonb);
  ELSIF new.case_id = 'red_seal' AND coalesce(new.combined, '[]'::jsonb) @> '["redseal_case_completed"]'::jsonb
        AND NOT coalesce(old.combined, '[]'::jsonb) @> '["redseal_case_completed"]'::jsonb THEN
    UPDATE public.world_characters SET bag_capacity = least(400, bag_capacity + 20), updated_at = now() WHERE owner_id = new.owner_id;
    INSERT INTO public.world_owned_mounts(owner_id, mount_id) VALUES (new.owner_id, 'seal_haetae') ON CONFLICT DO NOTHING;
    INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
    VALUES (new.owner_id, 'reward', '붉은 인장 사건 해결', '가방 용량이 20칸 늘고, 홍인 해태가 당신을 따르기로 했습니다. 지도 › 이동·탈것에서 탈 수 있습니다.', '{}'::jsonb);
  END IF;
  RETURN new;
END
$f$;

-- 프로필: 문장·색·한 줄 소개. 이름·직업·소속은 바꿀 수 없다.
CREATE OR REPLACE FUNCTION public.world_set_profile(p_emblem text, p_color text, p_bio text)
 RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); bio text := btrim(coalesce(p_bio, '')); prof jsonb;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_emblem IS NULL OR p_emblem NOT IN ('moon','lantern','seal','bell','lotus','blade','crane','flame','wave','mountain','star','eye') THEN
    RAISE EXCEPTION '문장을 선택하세요.';
  END IF;
  IF p_color IS NULL OR p_color NOT IN ('vermilion','gold','jade','indigo','violet','ash','crimson','teal','amber','ivory') THEN
    RAISE EXCEPTION '색을 선택하세요.';
  END IF;
  IF char_length(bio) > 60 THEN RAISE EXCEPTION '소개는 60자 이내로 적어 주세요.'; END IF;
  prof := jsonb_build_object('emblem', p_emblem, 'color', p_color, 'bio', bio);
  UPDATE public.world_characters SET profile = prof, updated_at = now() WHERE owner_id = uid;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  RETURN jsonb_build_object('ok', true, 'profile', prof, 'content', '프로필을 저장했습니다.');
END
$f$;

-- 현재 위치의 상점(안전지대만)
CREATE OR REPLACE FUNCTION public.world_current_shop(p_owner uuid)
 RETURNS TABLE(shop_id text, shop_name text, region_id text, region_name text)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT r.shop_id, r.shop_name, r.region_id, r.region_name
  FROM public.world_characters c, LATERAL (SELECT (public.world_region_at(c.location)).*) r
  WHERE c.owner_id = p_owner AND r.is_safe_zone AND r.shop_id IS NOT NULL
$f$;

-- ── 원정 ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.world_expedition_board()
 RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype;
  prog int := 0; e public.world_expeditions%rowtype; g public.world_expedition_grounds%rowtype;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터가 없습니다.'; END IF;
  r := public.world_region_at(c.location);
  SELECT coalesce(max(p.progress), 0) INTO prog FROM public.world_region_progress p WHERE p.owner_id = uid AND p.region_id = r.region_id;
  SELECT * INTO e FROM public.world_expeditions x WHERE x.owner_id = uid AND x.status = 'active';
  IF FOUND THEN SELECT * INTO g FROM public.world_expedition_grounds WHERE ground_id = e.ground_id; END IF;
  RETURN jsonb_build_object(
    'region_id', r.region_id, 'region_name', r.region_name, 'safe_zone', coalesce(r.is_safe_zone, false), 'progress', prog,
    'bag', jsonb_build_object('used', public.world_bag_count(c.inventory), 'capacity', public.world_bag_limit(uid)),
    'grounds', (SELECT coalesce(jsonb_agg(jsonb_build_object('ground_id', x.ground_id, 'ground_name', x.ground_name, 'depth', x.depth,
        'description', x.description, 'min_level', x.min_level, 'unlock_progress', x.unlock_progress, 'danger', x.danger,
        'unlocked', prog >= x.unlock_progress AND c.level >= x.min_level) ORDER BY x.depth), '[]'::jsonb)
      FROM public.world_expedition_grounds x WHERE x.region_id = r.region_id),
    'monsters', (SELECT coalesce(jsonb_agg(jsonb_build_object('name', m.monster_name, 'min_level', m.min_level, 'max_level', m.max_level,
        'type', m.monster_type, 'mechanic', m.mechanic_key)), '[]'::jsonb) FROM public.world_region_monsters m WHERE m.region_id = r.region_id),
    'active', CASE WHEN e.expedition_id IS NULL THEN NULL ELSE jsonb_build_object('expedition_id', e.expedition_id, 'ground_id', e.ground_id,
        'ground_name', g.ground_name, 'region_id', e.region_id, 'minutes', e.minutes, 'stance', e.stance, 'supplies', e.supplies,
        'started_at', e.started_at, 'ends_at', e.ends_at, 'ready', now() >= e.ends_at) END,
    'recent', (SELECT coalesce(jsonb_agg(jsonb_build_object('expedition_id', y.expedition_id, 'ground_name', gg.ground_name,
        'finished_at', y.finished_at, 'minutes', y.minutes, 'stance', y.stance, 'result', y.result) ORDER BY y.finished_at DESC), '[]'::jsonb)
      FROM (SELECT * FROM public.world_expeditions z WHERE z.owner_id = uid AND z.status = 'done' ORDER BY z.finished_at DESC LIMIT 5) y
      JOIN public.world_expedition_grounds gg ON gg.ground_id = y.ground_id));
END
$f$;

CREATE OR REPLACE FUNCTION public.world_expedition_launch(p_ground_id text, p_minutes integer, p_stance text, p_supplies jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; g public.world_expedition_grounds%rowtype;
  r public.world_map_regions%rowtype; prog int := 0; inv jsonb; k text; n int; sup jsonb := '{}'::jsonb; ends timestamptz;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_minutes IS NULL OR p_minutes NOT IN (30, 60, 120, 240, 480) THEN RAISE EXCEPTION '원정 시간을 선택하세요.'; END IF;
  IF p_stance IS NULL OR p_stance NOT IN ('cautious', 'balanced', 'bold') THEN RAISE EXCEPTION '원정 태세를 선택하세요.'; END IF;
  IF p_supplies IS NULL OR jsonb_typeof(p_supplies) <> 'object' THEN p_supplies := '{}'::jsonb; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.health <= 0 OR c.downed_at IS NOT NULL THEN RAISE EXCEPTION '전투불능 상태에서는 원정을 떠날 수 없습니다.'; END IF;
  IF c.travel_arrives_at IS NOT NULL AND c.travel_arrives_at > now() THEN RAISE EXCEPTION '이동 중에는 원정을 떠날 수 없습니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_expeditions WHERE owner_id = uid AND status = 'active') THEN RAISE EXCEPTION '이미 원정 중입니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = uid AND NOT a.defeated AND NOT coalesce(a.fled, false)) THEN
    RAISE EXCEPTION '전투 중에는 원정을 떠날 수 없습니다.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.world_idle_activities i WHERE i.owner_id = uid AND i.status = 'active') THEN
    RAISE EXCEPTION '자율 활동을 마친 뒤 원정을 떠나세요.';
  END IF;
  SELECT * INTO g FROM public.world_expedition_grounds WHERE ground_id = p_ground_id;
  IF NOT FOUND THEN RAISE EXCEPTION '알 수 없는 원정지입니다.'; END IF;
  r := public.world_region_at(c.location);
  IF r.region_id IS DISTINCT FROM g.region_id THEN RAISE EXCEPTION '원정지가 있는 지역에 머물러야 출발할 수 있습니다.'; END IF;
  IF r.is_safe_zone THEN RAISE EXCEPTION '안전지대에서는 원정을 떠날 수 없습니다.'; END IF;
  IF c.level < g.min_level THEN RAISE EXCEPTION '레벨 %부터 갈 수 있는 원정지입니다.', g.min_level; END IF;
  SELECT coalesce(max(progress), 0) INTO prog FROM public.world_region_progress WHERE owner_id = uid AND region_id = g.region_id;
  IF prog < g.unlock_progress THEN RAISE EXCEPTION '%', format('지역 답사도 %s%% 이상에서 열리는 원정지입니다. (현재 %s%%)', g.unlock_progress, prog); END IF;
  inv := coalesce(c.inventory, '{}'::jsonb);
  FOR k, n IN SELECT key, CASE WHEN jsonb_typeof(value) = 'number' THEN value::text::int ELSE -1 END FROM jsonb_each(p_supplies) LOOP
    IF k NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman', 'seal_paper', 'revival_charm', 'travel_ration') THEN
      RAISE EXCEPTION '원정에 가져갈 수 없는 물품입니다.';
    END IF;
    IF n < 0 OR n > 20 THEN RAISE EXCEPTION '보급품은 품목마다 0~20개까지 챙길 수 있습니다.'; END IF;
    IF coalesce((inv ->> k)::int, 0) < n THEN
      RAISE EXCEPTION '보급품이 부족합니다: % (필요 %, 보유 %)', (SELECT item_name FROM public.world_item_catalog WHERE item_id = k), n, coalesce((inv ->> k)::int, 0);
    END IF;
    IF n > 0 THEN sup := sup || jsonb_build_object(k, n); inv := jsonb_set(inv, ARRAY[k], to_jsonb((inv ->> k)::int - n)); END IF;
  END LOOP;
  ends := now() + make_interval(mins => p_minutes);
  UPDATE public.world_characters SET inventory = inv, updated_at = now() WHERE owner_id = uid;
  INSERT INTO public.world_expeditions(owner_id, ground_id, region_id, minutes, stance, supplies, ends_at)
  VALUES (uid, g.ground_id, g.region_id, p_minutes, p_stance, sup, ends);
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'expedition_start', g.ground_name || '(으)로 원정을 떠났습니다.',
    jsonb_build_object('ground_id', g.ground_id, 'minutes', p_minutes, 'stance', p_stance, 'supplies', sup));
  RETURN jsonb_build_object('ok', true, 'ends_at', ends, 'content', g.ground_name || '(으)로 원정을 떠났습니다. ' || p_minutes || '분 뒤 결과를 확인하세요.');
END
$f$;

-- 원정 결과 계산과 지급. p_recall=true면 지금까지 지난 시간만큼만 계산해 일찍 돌아온다.
CREATE OR REPLACE FUNCTION public.world_expedition_finish(p_recall boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE
  uid uuid := public.fn_owner_auth_uid();
  e public.world_expeditions%rowtype; c public.world_characters%rowtype; g public.world_expedition_grounds%rowtype;
  r public.world_map_regions%rowtype; m public.world_region_monsters%rowtype;
  total_rounds int; rounds int; i int; roll float8; win_p float8;
  sup jsonb; loot jsonb := '{}'::jsonb; log jsonb := '[]'::jsonb;
  hp int; mn int; er int; prog_gain int := 0; prog_before int := 0; prog_after int;
  wins int := 0; losses int := 0; gathers int := 0; finds int := 0; hazards int := 0;
  xp int := 0; cxp int := 0; gxp int := 0; ixp int := 0; gil_gain int := 0;
  wt int := 0; at int := 0; tt int := 0; power float8; defense float8; threat float8; dmg int; heal int;
  p_fight float8; dmg_mul float8; loot_mul float8; prog_mul float8; heal_at int;
  item text; qty int; pool text[]; rare_pool text[]; ended text := 'complete';
  spirit_mech boolean; rations_need int; rations_short int := 0; next_level int; next_xp int; gained int := 0;
  inv jsonb; used int; cap int; lost jsonb := '{}'::jsonb; k text; n int; space int;
  milestones text[]; new_ms text[] := '{}'; fully int; clue_added boolean := false; site text; mount_gift text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO e FROM public.world_expeditions WHERE owner_id = uid AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '진행 중인 원정이 없습니다.'; END IF;
  IF now() < e.ends_at AND NOT coalesce(p_recall, false) THEN
    RAISE EXCEPTION '아직 원정이 끝나지 않았습니다. 일찍 돌아오려면 귀환을 선택하세요.';
  END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  SELECT * INTO g FROM public.world_expedition_grounds WHERE ground_id = e.ground_id;
  SELECT * INTO r FROM public.world_map_regions WHERE region_id = e.region_id;

  total_rounds := CASE e.minutes WHEN 30 THEN 3 WHEN 60 THEN 6 WHEN 120 THEN 10 WHEN 240 THEN 16 ELSE 24 END;
  rounds := CASE WHEN now() >= e.ends_at THEN total_rounds
    ELSE floor(total_rounds * extract(epoch FROM now() - e.started_at) / (e.minutes * 60.0))::int END;
  rounds := greatest(0, least(total_rounds, rounds));
  IF rounds < total_rounds THEN ended := 'recalled'; END IF;

  SELECT coalesce(max(CASE WHEN eq.slot = 'weapon' THEN i.tier END), 0), coalesce(max(CASE WHEN eq.slot = 'armor' THEN i.tier END), 0),
         coalesce(max(CASE WHEN eq.slot = 'tool' THEN i.tier END), 0)
  INTO wt, at, tt FROM public.world_character_equipment eq JOIN public.world_item_catalog i ON i.item_id = eq.item_id WHERE eq.owner_id = uid;

  -- 능력치·장비·직업·대세력이 원정 결과를 정한다
  power := 12 + c.level * 5 + c.strength * 2.5 + c.agility * 1.5 + c.perception + wt * 14 + coalesce(c.combat_rank, 1) * 3;
  IF c.job_key = 'exorcist' THEN power := power * 1.12; END IF;
  defense := c.level * 2 + c.vitality * 3 + at * 12;
  IF c.major_faction_id = 'north_league' THEN defense := defense * 1.2; END IF;
  p_fight := CASE e.stance WHEN 'cautious' THEN 0.22 WHEN 'bold' THEN 0.5 ELSE 0.35 END + g.danger * 0.012;
  dmg_mul := CASE e.stance WHEN 'cautious' THEN 0.7 WHEN 'bold' THEN 1.3 ELSE 1.0 END;
  loot_mul := CASE e.stance WHEN 'cautious' THEN 0.8 WHEN 'bold' THEN 1.3 ELSE 1.0 END;
  IF c.major_faction_id = 'red_moon_cult' AND e.stance = 'bold' THEN loot_mul := loot_mul * 1.15; END IF;
  prog_mul := CASE e.stance WHEN 'cautious' THEN 0.85 WHEN 'bold' THEN 1.2 ELSE 1.0 END * (1 + (g.depth - 1) * 0.3);
  IF c.job_key = 'scout' THEN prog_mul := prog_mul * 1.2; END IF;
  IF c.major_faction_id = 'mandate_court' THEN prog_mul := prog_mul * 1.2; END IF;
  heal_at := CASE e.stance WHEN 'cautious' THEN 60 WHEN 'bold' THEN 30 ELSE 45 END;

  pool := coalesce(r.gather_nodes, '{}') || coalesce((SELECT array_agg(DISTINCT x) FROM public.world_region_sites s, jsonb_array_elements_text(coalesce(s.loot_table, '[]'::jsonb)) x WHERE s.region_id = r.region_id), '{}');
  rare_pool := coalesce((SELECT array_agg(DISTINCT x) FROM public.world_region_sites s, jsonb_array_elements_text(coalesce(s.rare_bonus -> 'items', '[]'::jsonb)) x WHERE s.region_id = r.region_id), '{}');
  pool := ARRAY(SELECT x FROM unnest(pool) x WHERE EXISTS (SELECT 1 FROM public.world_item_catalog ic WHERE ic.item_id = x));
  rare_pool := ARRAY(SELECT x FROM unnest(rare_pool) x WHERE EXISTS (SELECT 1 FROM public.world_item_catalog ic WHERE ic.item_id = x));

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
      SELECT * INTO m FROM public.world_region_monsters WHERE region_id = r.region_id ORDER BY -ln(greatest(random(), 1e-9)) / greatest(coalesce(spawn_weight, 1), 1) LIMIT 1;
      IF m.monster_id IS NULL THEN CONTINUE; END IF;
      threat := (m.hp / 8.0 + m.attack_power * 2) * (1 + (g.depth - 1) * 0.25);
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
        wins := wins + 1; xp := xp + 10 + g.danger * 2; cxp := cxp + 16; gil_gain := gil_gain + 2 + g.danger;
        dmg := round(m.attack_power * 0.3 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + defense));
        IF m.drops IS NOT NULL AND random() < 0.7 * loot_mul THEN
          SELECT d.k INTO item FROM jsonb_each(m.drops) d(k, v) WHERE EXISTS (SELECT 1 FROM public.world_item_catalog ic WHERE ic.item_id = d.k) ORDER BY random() LIMIT 1;
          IF item IS NOT NULL THEN loot := jsonb_set(loot, ARRAY[item], to_jsonb(coalesce((loot ->> item)::int, 0) + 1)); END IF;
        END IF;
        IF wins <= 3 THEN log := log || jsonb_build_array(m.monster_name || '을(를) 물리쳤습니다.'); END IF;
      ELSE
        losses := losses + 1;
        dmg := round(m.attack_power * 0.8 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + defense));
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
        IF qty > 0 THEN
          gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8;
          loot := jsonb_set(loot, ARRAY[item], to_jsonb(coalesce((loot ->> item)::int, 0) + qty));
        END IF;
      END IF;
    ELSIF roll < p_fight + 0.35 + 0.22 + c.perception * 0.002 THEN
      finds := finds + 1; xp := xp + 6; ixp := ixp + 10;
      prog_gain := prog_gain + round((4 + c.perception / 4.0 + coalesce(c.investigation_rank, 1)) * prog_mul);
      IF cardinality(rare_pool) > 0 AND random() < 0.04 + g.depth * 0.03 + (CASE WHEN c.job_key = 'analyst' THEN 0.05 ELSE 0 END) THEN
        item := rare_pool[1 + floor(random() * cardinality(rare_pool))::int];
        loot := jsonb_set(loot, ARRAY[item], to_jsonb(coalesce((loot ->> item)::int, 0) + 1));
        log := log || jsonb_build_array('숨겨진 곳에서 ' || (SELECT item_name FROM public.world_item_catalog WHERE item_id = item) || '을(를) 찾았습니다.');
      END IF;
      IF NOT clue_added AND random() < 0.2 THEN
        SELECT s.site_id INTO site FROM public.world_region_sites s WHERE s.region_id = r.region_id ORDER BY s.site_id LIMIT 1;
        IF site IS NOT NULL THEN
          INSERT INTO public.world_case_progress(owner_id, case_id, clues) VALUES (uid, 'regional_discoveries', '[]'::jsonb) ON CONFLICT (owner_id, case_id) DO NOTHING;
          UPDATE public.world_case_progress SET clues = coalesce(clues, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
              'id', 'regional_' || site, 'title', r.region_name || ' 원정 기록', 'region_id', r.region_id, 'site_id', site, 'found_at', now(), 'source', 'expedition')),
            updated_at = now()
          WHERE owner_id = uid AND case_id = 'regional_discoveries'
            AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(clues, '[]'::jsonb)) cl WHERE cl ->> 'region_id' = r.region_id);
          IF FOUND THEN clue_added := true; log := log || jsonb_build_array('지역 답사 보고서에 쓸 단서를 기록했습니다.'); END IF;
        END IF;
      END IF;
    ELSE
      IF random() < 0.6 THEN
        hazards := hazards + 1;
        er := er + round((g.danger + g.depth) / 2.0 * CASE WHEN c.job_key = 'sealmaster' THEN 0.5 ELSE 1 END * greatest(0.3, 1 - c.willpower / 100.0));
        mn := mn - (2 + floor(random() * 4))::int;
      END IF;
    END IF;
    prog_gain := prog_gain + 1;

    -- 보급품 자동 사용
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

  -- 지급: 남은 보급품 먼저 돌려주고, 전리품은 가방 용량까지만
  inv := coalesce(c.inventory, '{}'::jsonb);
  FOR k, n IN SELECT key, value::text::int FROM jsonb_each(sup) WHERE value::text::int > 0 LOOP
    inv := jsonb_set(inv, ARRAY[k], to_jsonb(coalesce((inv ->> k)::int, 0) + n));
  END LOOP;
  cap := public.world_bag_limit(uid); used := public.world_bag_count(inv);
  FOR k, n IN SELECT key, value::text::int FROM jsonb_each(loot) WHERE value::text::int > 0 ORDER BY key LOOP
    space := greatest(0, cap - used);
    IF space < n THEN lost := lost || jsonb_build_object(k, n - space); END IF;
    IF least(space, n) > 0 THEN inv := jsonb_set(inv, ARRAY[k], to_jsonb(coalesce((inv ->> k)::int, 0) + least(space, n))); used := used + least(space, n); END IF;
  END LOOP;
  IF lost <> '{}'::jsonb THEN log := log || jsonb_build_array('가방이 가득 차 일부 전리품을 두고 왔습니다.'); END IF;

  -- 경험치와 레벨 (기존 규칙: 다음 레벨까지 level×100, 레벨당 능력치 3점)
  next_level := c.level; next_xp := c.experience + xp;
  WHILE next_level < 100 AND next_xp >= next_level * 100 LOOP next_xp := next_xp - next_level * 100; next_level := next_level + 1; gained := gained + 1; END LOOP;
  IF next_level >= 100 THEN next_xp := 0; END IF;

  UPDATE public.world_characters SET
    health = CASE WHEN ended = 'downed' THEN 0 ELSE least(100, hp + gained * 10) END,
    mental = least(100, mn + gained * 5), erosion = er,
    erosion_stage = CASE WHEN er >= 80 THEN 4 WHEN er >= 55 THEN 3 WHEN er >= 30 THEN 2 WHEN er >= 10 THEN 1 ELSE 0 END,
    experience = next_xp, level = least(100, next_level), stat_points = least(297, stat_points + gained * 3),
    combat_xp = combat_xp + cxp, combat_rank = public.world_skill_rank(combat_xp + cxp, 'combat'),
    gathering_xp = gathering_xp + gxp, gathering_rank = public.world_skill_rank(gathering_xp + gxp, 'gathering'),
    investigation_xp = investigation_xp + ixp, investigation_rank = public.world_skill_rank(investigation_xp + ixp, 'investigation'),
    gil = gil + gil_gain, inventory = inv, updated_at = now()
  WHERE owner_id = uid;

  -- 지역 답사도와 이정표
  INSERT INTO public.world_region_progress(owner_id, region_id) VALUES (uid, r.region_id) ON CONFLICT DO NOTHING;
  SELECT progress, milestones INTO prog_before, milestones FROM public.world_region_progress WHERE owner_id = uid AND region_id = r.region_id FOR UPDATE;
  prog_after := least(100, prog_before + CASE WHEN ended = 'downed' THEN prog_gain / 2 ELSE prog_gain END);
  IF prog_after >= 30 AND NOT ('depth2' = ANY (milestones)) THEN new_ms := new_ms || 'depth2'; log := log || jsonb_build_array('답사도 30% — 심부 원정지가 열렸습니다.'); END IF;
  IF prog_after >= 70 AND NOT ('depth3' = ANY (milestones)) THEN new_ms := new_ms || 'depth3'; log := log || jsonb_build_array('답사도 70% — 핵심 원정지가 열렸습니다.'); END IF;
  IF prog_after >= 100 AND NOT ('complete' = ANY (milestones)) THEN
    new_ms := new_ms || 'complete';
    UPDATE public.world_characters SET bag_capacity = least(400, bag_capacity + 5) WHERE owner_id = uid;
    log := log || jsonb_build_array(r.region_name || ' 완전 답사 — 가방 용량 +5');
  END IF;
  UPDATE public.world_region_progress SET progress = prog_after, expeditions = expeditions + 1, milestones = milestones || new_ms, updated_at = now()
  WHERE owner_id = uid AND region_id = r.region_id;
  IF 'complete' = ANY (new_ms) THEN
    SELECT count(*) INTO fully FROM public.world_region_progress WHERE owner_id = uid AND progress >= 100;
    IF fully >= 5 THEN
      INSERT INTO public.world_owned_mounts(owner_id, mount_id) VALUES (uid, 'mist_deer') ON CONFLICT DO NOTHING;
      IF FOUND THEN mount_gift := 'mist_deer'; log := log || jsonb_build_array('다섯 지역을 완전히 답사하자 안개 사슴이 따라왔습니다.'); END IF;
    END IF;
  END IF;

  UPDATE public.world_expeditions SET status = 'done', finished_at = now(), result = jsonb_build_object(
    'ended', ended, 'rounds', rounds, 'total_rounds', total_rounds, 'wins', wins, 'losses', losses, 'gathers', gathers, 'finds', finds, 'hazards', hazards,
    'loot', loot, 'lost', lost, 'supplies_left', sup, 'supplies_used', (SELECT coalesce(jsonb_object_agg(s.key, s.value::text::int - coalesce((sup ->> s.key)::int, 0)) FILTER (WHERE s.value::text::int - coalesce((sup ->> s.key)::int, 0) > 0), '{}'::jsonb) FROM jsonb_each(e.supplies) s),
    'experience', xp, 'combat_xp', cxp, 'gathering_xp', gxp, 'investigation_xp', ixp, 'gil', gil_gain, 'levels', gained,
    'health', CASE WHEN ended = 'downed' THEN 0 ELSE hp END, 'mental', mn, 'erosion', er,
    'progress_before', prog_before, 'progress_after', prog_after, 'mount', mount_gift, 'log', log)
  WHERE expedition_id = e.expedition_id;

  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'expedition_end', g.ground_name || ' 원정 종료',
    jsonb_build_object('ground_id', g.ground_id, 'ended', ended, 'wins', wins, 'gathers', gathers, 'progress', prog_after));

  RETURN (SELECT jsonb_build_object('ok', true, 'ground_name', g.ground_name, 'content', g.ground_name || ' 원정을 마쳤습니다.') || jsonb_build_object('result', result)
          FROM public.world_expeditions WHERE expedition_id = e.expedition_id);
END
$f$;

CREATE OR REPLACE FUNCTION public.world_exploration_overview()
 RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid();
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  RETURN jsonb_build_object(
    'regions', (SELECT coalesce(jsonb_agg(jsonb_build_object('region_id', r.region_id, 'region_name', r.region_name, 'territory_name', r.territory_name,
        'safe_zone', r.is_safe_zone, 'progress', coalesce(p.progress, 0), 'expeditions', coalesce(p.expeditions, 0), 'min_level', r.min_level,
        'danger', r.danger_level) ORDER BY r.territory_id, r.min_level), '[]'::jsonb)
      FROM public.world_map_regions r LEFT JOIN public.world_region_progress p ON p.owner_id = uid AND p.region_id = r.region_id),
    'history', (SELECT coalesce(jsonb_agg(jsonb_build_object('ground_name', g.ground_name, 'region_id', x.region_id, 'finished_at', x.finished_at,
        'minutes', x.minutes, 'stance', x.stance, 'result', x.result) ORDER BY x.finished_at DESC), '[]'::jsonb)
      FROM (SELECT * FROM public.world_expeditions y WHERE y.owner_id = uid AND y.status = 'done' ORDER BY y.finished_at DESC LIMIT 20) x
      JOIN public.world_expedition_grounds g ON g.ground_id = x.ground_id));
END
$f$;

REVOKE ALL ON FUNCTION public.world_region_at(text), public.world_bag_limit(uuid), public.world_bag_count(jsonb),
  public.world_current_shop(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.world_set_profile(text, text, text), public.world_expedition_board(), public.world_expedition_launch(text, integer, text, jsonb),
  public.world_expedition_finish(boolean), public.world_exploration_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_set_profile(text, text, text), public.world_expedition_board(), public.world_expedition_launch(text, integer, text, jsonb),
  public.world_expedition_finish(boolean), public.world_exploration_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.world_current_shop(uuid) TO fn_owner_18876, fn_owner_18877;
GRANT EXECUTE ON FUNCTION public.world_bag_count(jsonb) TO fn_owner_social;
RESET ROLE;

-- ── C. 조회: 같은 지역 조사원·파티 (공개 열만) ────────────────────
SET ROLE fn_owner_social;
CREATE OR REPLACE FUNCTION public.world_region_roster()
 RETURNS jsonb
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); loc text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT location INTO loc FROM public.world_characters WHERE owner_id = uid;
  RETURN (SELECT coalesce(jsonb_agg(jsonb_build_object('owner_id', c.owner_id, 'character_name', c.character_name, 'level', c.level,
      'job_key', c.job_key, 'faction_key', c.faction_key, 'major_faction_id', c.major_faction_id, 'health', c.health,
      'downed', c.downed_at IS NOT NULL OR c.health <= 0, 'is_dead', coalesce(c.is_dead, false), 'profile', c.profile,
      'away', EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = c.owner_id AND e.status = 'active'),
      'in_combat', EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = c.owner_id AND NOT a.defeated AND NOT coalesce(a.fled, false)))
      ORDER BY c.updated_at DESC), '[]'::jsonb)
    FROM (SELECT x.owner_id, x.character_name, x.level, x.job_key, x.faction_key, x.major_faction_id, x.health, x.downed_at, x.is_dead, x.profile, x.updated_at
          FROM public.world_characters x WHERE x.location = loc AND x.owner_id <> uid ORDER BY x.updated_at DESC LIMIT 50) c);
END
$f$;

CREATE OR REPLACE FUNCTION public.world_party_overview()
 RETURNS jsonb
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); pid uuid;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT party_id INTO pid FROM public.world_party_members WHERE owner_id = uid;
  RETURN jsonb_build_object(
    'party', (SELECT jsonb_build_object('party_id', p.party_id, 'party_name', p.party_name, 'leader_id', p.leader_id,
        'loot_distribution_method', p.loot_distribution_method) FROM public.world_parties p WHERE p.party_id = pid),
    'members', (SELECT coalesce(jsonb_agg(jsonb_build_object('owner_id', m.owner_id, 'role', m.role, 'character_name', c.character_name,
        'level', c.level, 'job_key', c.job_key, 'location', c.location, 'health', c.health, 'profile', c.profile,
        'downed', c.downed_at IS NOT NULL OR c.health <= 0,
        'away', EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = m.owner_id AND e.status = 'active'),
        'in_combat', EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = m.owner_id AND NOT a.defeated AND NOT coalesce(a.fled, false)))
        ORDER BY (m.role = 'leader') DESC, m.joined_at), '[]'::jsonb)
      FROM public.world_party_members m JOIN public.world_characters c ON c.owner_id = m.owner_id WHERE pid IS NOT NULL AND m.party_id = pid),
    'invites', (SELECT coalesce(jsonb_agg(jsonb_build_object('invite_id', i.invite_id, 'party_id', i.party_id, 'party_name', p.party_name,
        'inviter_name', ic.character_name, 'invitee_name', ec.character_name, 'incoming', i.invitee_id = uid, 'created_at', i.created_at)), '[]'::jsonb)
      FROM public.world_party_invites i JOIN public.world_parties p ON p.party_id = i.party_id
      LEFT JOIN public.world_characters ic ON ic.owner_id = i.inviter_id LEFT JOIN public.world_characters ec ON ec.owner_id = i.invitee_id
      WHERE (i.invitee_id = uid OR i.inviter_id = uid) AND i.status = 'pending'),
    'candidates', (SELECT coalesce(jsonb_agg(jsonb_build_object('owner_id', c.owner_id, 'character_name', c.character_name, 'level', c.level,
        'location', c.location, 'job_key', c.job_key) ORDER BY c.character_name), '[]'::jsonb)
      FROM public.world_characters c WHERE c.owner_id <> uid AND NOT coalesce(c.is_dead, false)
        AND NOT EXISTS (SELECT 1 FROM public.world_party_members pm WHERE pm.owner_id = c.owner_id)));
END
$f$;
REVOKE ALL ON FUNCTION public.world_region_roster(), public.world_party_overview() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_region_roster(), public.world_party_overview() TO authenticated;
RESET ROLE;


-- ── D. 트리거 연결 ──────────────────────────────────────
CREATE TRIGGER trg_world_enforce_bag_capacity BEFORE UPDATE OF inventory ON public.world_characters
  FOR EACH ROW WHEN (new.inventory IS DISTINCT FROM old.inventory) EXECUTE FUNCTION public.world_enforce_bag_capacity();
CREATE TRIGGER trg_world_guard_action_context BEFORE INSERT ON public.world_events
  FOR EACH ROW EXECUTE FUNCTION public.world_guard_action_context();
CREATE TRIGGER trg_world_guard_idle_during_expedition BEFORE INSERT OR UPDATE OF status ON public.world_idle_activities
  FOR EACH ROW EXECUTE FUNCTION public.world_guard_idle_during_expedition();
CREATE TRIGGER trg_world_reward_regional_claim AFTER INSERT ON public.world_regional_case_claims
  FOR EACH ROW EXECUTE FUNCTION public.world_reward_case_resolution();
CREATE TRIGGER trg_world_reward_case_resolution AFTER UPDATE OF combined ON public.world_case_progress
  FOR EACH ROW EXECUTE FUNCTION public.world_reward_case_resolution();

-- 트리거를 연결한 뒤 트리거 함수의 직접 실행 권한을 소유 역할이 회수한다.
SET ROLE fn_owner_expedition;
REVOKE ALL ON FUNCTION public.world_enforce_bag_capacity(), public.world_guard_action_context(), public.world_guard_idle_during_expedition(),
  public.world_reward_case_resolution() FROM PUBLIC;
RESET ROLE;
REVOKE CREATE ON SCHEMA public FROM fn_owner_expedition, fn_owner_social;
GRANT fn_owner_expedition TO postgres WITH SET FALSE, INHERIT FALSE;
GRANT fn_owner_social TO postgres WITH SET FALSE, INHERIT FALSE;

-- ── E. 상점: 안전지대의 상점만 열고, 조회와 구매가 같은 상점을 쓰도록 통일 (소유 역할 유지) ──
GRANT fn_owner_18876 TO postgres WITH SET TRUE;
GRANT fn_owner_18877 TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_18876, fn_owner_18877;
SET ROLE fn_owner_18876;
CREATE OR REPLACE FUNCTION public.world_shop_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; sh record; payload jsonb; slot timestamptz;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select * into c from public.world_characters where owner_id=uid;
 if not found then raise exception '캐릭터가 없습니다.'; end if;
 select * into sh from public.world_current_shop(uid);
 if sh.shop_id is null then
   return jsonb_build_object('available',false,'gil',c.gil,'location',c.location,'stock','[]'::jsonb,
     'content','상점은 안전지대에만 있습니다.');
 end if;
 slot:=date_trunc('day',now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul'
  + case when extract(hour from now() at time zone 'Asia/Seoul')>=23 then interval '23 hours'
         when extract(hour from now() at time zone 'Asia/Seoul')>=15 then interval '15 hours'
         when extract(hour from now() at time zone 'Asia/Seoul')>=7 then interval '7 hours'
         else interval '-1 hour' end;
 if slot>now() then slot:=slot-interval '1 day'; end if;
 insert into public.world_shop_stock(shop_id,item_id,stock,unit_price,refreshed_at)
 select sc.shop_id,sc.item_id,sc.stock_min+floor(random()*(sc.stock_max-sc.stock_min+1))::int,
 greatest(1,round(sc.base_price*(0.9+random()*0.2))::bigint),slot
 from public.world_shop_catalog sc where sc.shop_id=sh.shop_id
 on conflict(shop_id,item_id) do update set stock=excluded.stock,unit_price=excluded.unit_price,refreshed_at=excluded.refreshed_at
 where public.world_shop_stock.refreshed_at<slot;
 select coalesce(jsonb_agg(jsonb_build_object('item_id',ss.item_id,'item_name',i.item_name,'category',i.category,'tier',i.tier,'stock',ss.stock,'unit_price',ss.unit_price,'description',i.description) order by i.category,i.tier,i.item_name),'[]'::jsonb) into payload
 from public.world_shop_stock ss join public.world_item_catalog i on i.item_id=ss.item_id
 where ss.shop_id=sh.shop_id and exists(select 1 from public.world_shop_catalog sc where sc.shop_id=ss.shop_id and sc.item_id=ss.item_id);
 return jsonb_build_object('available',true,'shop_id',sh.shop_id,'shop_name',sh.shop_name,'gil',c.gil,'location',c.location,'stock',payload,
   'refresh_schedule','매일 07:00 / 15:00 / 23:00 (한국 시간)','next_refresh',slot+interval '8 hours');
end $function$;
RESET ROLE;
SET ROLE fn_owner_18877;
CREATE OR REPLACE FUNCTION public.world_shop_buy(p_item_id text, p_qty integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; shop text; s public.world_shop_stock%rowtype; inv jsonb; total bigint; msg text; nm text;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 if p_qty is null or p_qty<1 or p_qty>99 then raise exception '구매 수량은 1~99개입니다.'; end if;
 select * into c from public.world_characters where owner_id=uid for update;
 if not found then raise exception '캐릭터를 먼저 등록하세요.'; end if;
 if c.is_dead or c.health<=0 or c.downed_at is not null then raise exception '현재 상태에서는 구매할 수 없습니다.'; end if;
 select cs.shop_id into shop from public.world_current_shop(uid) cs;
 if shop is null then raise exception '상점은 안전지대에만 있습니다.'; end if;
 perform public.world_shop_snapshot();
 select * into s from public.world_shop_stock where shop_id=shop and item_id=p_item_id for update;
 if not found or s.stock<p_qty then raise exception '상점 재고가 부족합니다.'; end if;
 total:=s.unit_price*p_qty;
 if c.gil<total then raise exception '재화가 부족합니다.'; end if;
 update public.world_shop_stock set stock=stock-p_qty where shop_id=shop and item_id=p_item_id;
 inv:=coalesce(c.inventory,'{}'::jsonb);
 inv:=jsonb_set(inv,array[p_item_id],to_jsonb(coalesce((inv->>p_item_id)::int,0)+p_qty),true);
 update public.world_characters set gil=gil-total,inventory=inv,updated_at=now() where owner_id=uid;
 insert into public.world_economy_ledger(owner_id,action,currency_delta,sink,details) values(uid,'shop_buy',-total,true,jsonb_build_object('shop',shop,'item',p_item_id,'qty',p_qty));
 select item_name into nm from public.world_item_catalog where item_id=p_item_id;
 msg:='구매 완료: '||coalesce(nm,p_item_id)||' ×'||p_qty||' · '||total||'전';
 insert into public.world_events(actor_id,actor_name,event_type,content,payload) values(uid,c.character_name,'shop_buy',msg,jsonb_build_object('shop',shop,'item',p_item_id,'qty',p_qty,'gil',total));
 return jsonb_build_object('content',msg,'gil',c.gil-total,'inventory',inv);
end $function$;
RESET ROLE;
REVOKE CREATE ON SCHEMA public FROM fn_owner_18876, fn_owner_18877;
GRANT fn_owner_18876 TO postgres WITH SET FALSE, INHERIT FALSE;
GRANT fn_owner_18877 TO postgres WITH SET FALSE, INHERIT FALSE;

-- ── F. 탈것 조회: 마구간 위치·획득 방식 표시 (호출자 권한 함수, 소유자 그대로) ──
CREATE OR REPLACE FUNCTION public.world_mount_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$ declare uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; result jsonb; here text; begin if uid is null then raise exception '로그인이 필요합니다.'; end if; select * into c from public.world_characters where owner_id=uid; select r.region_id into here from public.world_map_regions r where r.region_name=c.location or (r.region_id='hq_yard' and c.location in ('본부 로비','야행국 본부 · 정청')) limit 1; select coalesce(jsonb_agg(jsonb_build_object('mount_id',m.mount_id,'mount_name',m.mount_name,'speed_multiplier',m.speed_multiplier,'price',m.price,'description',m.description,'unlock_level',m.unlock_level,'unlock_reputation',m.unlock_reputation,'unlock_faction',m.unlock_faction,'unlock_region',m.unlock_region,'unlock_region_name',(select r.region_name from public.world_map_regions r where r.region_id=m.unlock_region),'unlock_item',m.unlock_item,'tier',m.tier,'passenger_capacity',m.passenger_capacity,'fare_tokens',m.fare_tokens,'fare_free',m.fare_free,'acquire_method',m.acquire_method,'at_stable',m.acquire_method='stable' and m.unlock_region is not null and m.unlock_region=here,'owned',exists(select 1 from public.world_owned_mounts o where o.owner_id=uid and o.mount_id=m.mount_id),'equipped',c.mount_id=m.mount_id) order by case m.tier when '초보자' then 0 when '일반' then 1 when '고급' then 2 when '희귀' then 3 when '영물' then 4 else 5 end,m.price),'[]'::jsonb) into result from public.world_mount_catalog m; return jsonb_build_object('gil',c.gil,'mount_tokens',c.mount_tokens,'mount_id',c.mount_id,'mounts',result,'location',c.location,'region_id',here,'travel_destination',c.travel_destination,'travel_arrives_at',c.travel_arrives_at); end $function$;

-- ── G. 탈것 획득: 마구간(안전지대)에서만, 사건 탈것은 구매 불가.
--    기존 함수는 보유 기록보다 장착을 먼저 해 보유 검사 트리거에 막혀 구매가 불가능했다. 보유 기록을 먼저 넣는다.
GRANT fn_owner_18883 TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_18883;
SET ROLE fn_owner_18883;
CREATE OR REPLACE FUNCTION public.world_mount_acquire(p_mount_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; m public.world_mount_catalog%rowtype; r public.world_map_regions%rowtype; inv jsonb; stable_name text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id=uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 등록하세요.'; END IF;
  IF c.is_dead OR c.health<=0 OR c.downed_at IS NOT NULL THEN RAISE EXCEPTION '현재 상태에서는 탈것을 구할 수 없습니다.'; END IF;
  SELECT * INTO m FROM public.world_mount_catalog WHERE mount_id=p_mount_id;
  IF NOT FOUND THEN RAISE EXCEPTION '존재하지 않는 탈것입니다.'; END IF;
  IF m.acquire_method='event' THEN RAISE EXCEPTION '이 탈것은 특별한 사건으로만 얻을 수 있습니다.'; END IF;
  IF EXISTS(SELECT 1 FROM public.world_owned_mounts WHERE owner_id=uid AND mount_id=p_mount_id) THEN RAISE EXCEPTION '이미 보유한 탈것입니다.'; END IF;
  SELECT * INTO r FROM public.world_map_regions x WHERE x.region_name=c.location OR (x.region_id='hq_yard' AND c.location IN ('본부 로비','야행국 본부 · 정청')) LIMIT 1;
  SELECT region_name INTO stable_name FROM public.world_map_regions WHERE region_id=m.unlock_region;
  IF NOT coalesce(r.has_stable,false) OR (m.unlock_region IS NOT NULL AND r.region_id IS DISTINCT FROM m.unlock_region) THEN
    RAISE EXCEPTION '%', coalesce(stable_name||' 마구간에서 구할 수 있습니다.','안전지대의 마구간에서만 구할 수 있습니다.');
  END IF;
  IF c.level<m.unlock_level THEN RAISE EXCEPTION '레벨 %부터 구할 수 있습니다.', m.unlock_level; END IF;
  IF m.unlock_faction IS NOT NULL AND c.major_faction_id IS DISTINCT FROM m.unlock_faction THEN RAISE EXCEPTION '이 탈것은 특정 대세력 소속만 구할 수 있습니다.'; END IF;
  IF c.faction_reputation<m.unlock_reputation THEN RAISE EXCEPTION '세력 평판 %이 필요합니다.', m.unlock_reputation; END IF;
  inv:=coalesce(c.inventory,'{}'::jsonb);
  IF m.unlock_item IS NOT NULL AND coalesce((inv->>m.unlock_item)::int,0)<1 THEN RAISE EXCEPTION '공물이 필요합니다.'; END IF;
  IF c.gil<m.price THEN RAISE EXCEPTION '재화가 부족합니다. (필요 %전)', m.price; END IF;
  IF m.unlock_item IS NOT NULL THEN inv:=jsonb_set(inv,ARRAY[m.unlock_item],to_jsonb(coalesce((inv->>m.unlock_item)::int,0)-1),true); END IF;
  INSERT INTO public.world_owned_mounts(owner_id,mount_id) VALUES(uid,p_mount_id);
  UPDATE public.world_characters SET gil=gil-m.price,inventory=inv,mount_id=p_mount_id,updated_at=now() WHERE owner_id=uid;
  INSERT INTO public.world_economy_ledger(owner_id,action,currency_delta,sink,details) VALUES(uid,'mount_purchase',-m.price,true,jsonb_build_object('mount_id',p_mount_id));
  INSERT INTO public.world_events(actor_id,actor_name,event_type,content,payload) VALUES(uid,c.character_name,'mount','탈것 획득: '||m.mount_name,jsonb_build_object('mount_id',p_mount_id,'price',m.price));
  RETURN jsonb_build_object('content','탈것 획득: '||m.mount_name||' (사용 중으로 바꿨습니다)','mount_id',p_mount_id,'gil',c.gil-m.price);
END $function$;
RESET ROLE;
REVOKE CREATE ON SCHEMA public FROM fn_owner_18883;
GRANT fn_owner_18883 TO postgres WITH SET FALSE, INHERIT FALSE;
