-- 현장 탐색(탐색력 제한)·세부 지역 이동·채집·새 전투 엔진.
-- 탐색 한 번에 길 발견·채집터 발견·요괴 조우·보급 발견·단서·함정·징조 중 하나가 일어난다.
-- 전투는 장착한 무기 종류(근접·원거리·술법)로 공격 방식이 정해지고, 요괴는 다음 행동을 미리 드러낸다.

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fn_owner_field') THEN
    CREATE ROLE fn_owner_field NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
END $$;
GRANT USAGE ON SCHEMA public TO fn_owner_field;
GRANT EXECUTE ON FUNCTION public.fn_owner_auth_uid(), public.world_skill_rank(integer, text), public.world_status_effect_total(text),
  public.world_title_bonus(text) TO fn_owner_field;
GRANT SELECT ON public.world_map_regions, public.world_exploration_nodes, public.world_gathering_spots, public.world_region_monsters,
  public.world_item_catalog, public.world_character_equipment, public.world_region_profiles, public.world_status_catalog,
  public.world_major_factions, public.world_idle_activities, public.world_region_sites, public.world_region_theme,
  public.world_mount_catalog, public.world_title_catalog TO fn_owner_field;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.world_active_encounters, public.world_exploration_discoveries, public.world_gathering_discoveries,
  public.world_character_statuses, public.world_case_progress, public.world_region_progress, public.world_region_intel TO fn_owner_field;
GRANT SELECT, INSERT, UPDATE ON public.world_expeditions TO fn_owner_field;
GRANT SELECT, INSERT ON public.world_owned_mounts TO fn_owner_field;
GRANT SELECT ON public.world_characters TO fn_owner_field;
GRANT UPDATE (location, travel_destination, travel_arrives_at, current_exploration_node_id, stamina, stamina_at, health, mental,
  spiritual_power, erosion, erosion_stage, experience, level, stat_points, combat_xp, combat_rank, gathering_xp, gathering_rank,
  investigation_xp, investigation_rank, gil, inventory, bag_capacity, downed_at, mount_tokens, updated_at) ON public.world_characters TO fn_owner_field;
GRANT INSERT ON public.world_events, public.world_notifications, public.world_economy_ledger, public.world_travel_history TO fn_owner_field;
GRANT SELECT ON public.world_travel_history, public.world_events, public.world_character_titles TO fn_owner_field;
GRANT USAGE ON SEQUENCE public.world_events_id_seq, public.world_notifications_id_seq TO fn_owner_field;
GRANT EXECUTE ON FUNCTION public.world_status_roll(text, jsonb) TO fn_owner_field;

ALTER TABLE public.world_expeditions ALTER COLUMN ground_id DROP NOT NULL;
ALTER TABLE public.world_expeditions ADD COLUMN IF NOT EXISTS node_id uuid REFERENCES public.world_exploration_nodes(node_id);

-- 주 이야기: 장·단서·가설. 진행도는 기존 world_case_progress(case_id = 장 id)에 쌓는다.
CREATE TABLE IF NOT EXISTS public.world_story_chapters (
  chapter_id text PRIMARY KEY, seq integer NOT NULL UNIQUE, title text NOT NULL, summary text NOT NULL,
  intro text NOT NULL, outro text NOT NULL, min_level integer NOT NULL DEFAULT 1, rewards jsonb NOT NULL DEFAULT '{}'::jsonb);
CREATE TABLE IF NOT EXISTS public.world_story_clues (
  clue_id text PRIMARY KEY, chapter_id text NOT NULL REFERENCES public.world_story_chapters(chapter_id),
  name text NOT NULL, tag text NOT NULL, region_id text NOT NULL REFERENCES public.world_map_regions(region_id),
  description text NOT NULL, sort integer NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS public.world_story_combos (
  combo_id text PRIMARY KEY, chapter_id text NOT NULL REFERENCES public.world_story_chapters(chapter_id),
  name text NOT NULL, needs text[] NOT NULL, description text NOT NULL, conclusion text NOT NULL, sort integer NOT NULL DEFAULT 0);
ALTER TABLE public.world_story_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_story_clues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_story_combos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.world_story_chapters, public.world_story_clues, public.world_story_combos FROM anon, authenticated;
GRANT SELECT ON public.world_story_chapters, public.world_story_clues, public.world_story_combos TO fn_owner_field;

GRANT fn_owner_field TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_field;
SET ROLE fn_owner_field;

-- ── 공용 도우미 ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.world_field_region(p_location text)
 RETURNS public.world_map_regions LANGUAGE sql STABLE SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT r.* FROM public.world_map_regions r
  WHERE r.region_name = p_location OR r.region_id = p_location
     OR (r.region_id = 'hq_yard' AND p_location IN ('본부 로비', '야행국 본부 · 정청', '야행국 본부 · 로비'))
  ORDER BY (r.region_name = p_location) DESC LIMIT 1
$f$;

CREATE OR REPLACE FUNCTION public.world_stamina_max(p_level integer)
 RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO 'pg_catalog'
AS $f$ SELECT 20 + greatest(1, coalesce(p_level, 1)) / 5 $f$;

-- 탐색력은 6분마다 1씩 찬다.
CREATE OR REPLACE FUNCTION public.world_stamina_now(p_stamina integer, p_at timestamptz, p_level integer)
 RETURNS integer LANGUAGE sql STABLE SET search_path TO 'pg_catalog', 'public'
AS $f$ SELECT least(public.world_stamina_max(p_level), greatest(0, p_stamina) + floor(greatest(0, extract(epoch FROM now() - p_at)) / 360)::int) $f$;

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

RESET ROLE;
