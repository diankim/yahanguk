-- 날씨·시간대, 장비 내구도·수리, 전투 능력치 계산을 들인다.
-- 함수는 postgres로 만든 뒤 함수 전용 역할(fn_owner_field)에게 넘긴다. 클라이언트에는 RPC만 연다.

-- ── 날씨·시간대 자료 ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.world_environment_catalog (
  env_key text PRIMARY KEY,
  kind text NOT NULL CHECK (kind IN ('weather', 'phase')),
  env_name text NOT NULL,
  description text NOT NULL,
  effects jsonb NOT NULL DEFAULT '{}'::jsonb,
  sort int NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS public.world_weather_climate (
  territory_id text PRIMARY KEY,
  weights jsonb NOT NULL
);
ALTER TABLE public.world_environment_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_weather_climate ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.world_environment_catalog, public.world_weather_climate FROM anon, authenticated;
GRANT SELECT ON public.world_environment_catalog, public.world_weather_climate TO fn_owner_field;

INSERT INTO public.world_environment_catalog(env_key, kind, env_name, description, effects, sort) VALUES
 ('dawn', 'phase', '해돋이', '오전 6시부터 정오까지. 밤의 요기가 물러가고 이슬 맺힌 풀이 잘 뜯긴다.', '{"gather_qty_pct":8,"healing_pct":10,"erosion_pct":-10,"encounter_pct":-10}', 1),
 ('noon', 'phase', '한낮', '정오부터 오후 6시까지. 볕이 밝아 손이 정확해지지만 술법의 기운은 옅다.', '{"craft_quality":5,"travel_time_pct":-5,"magic_pct":-5,"encounter_pct":-5}', 2),
 ('dusk', 'phase', '땅거미', '오후 6시부터 자정까지. 그림자가 길어지며 숨은 것들이 드러나기 시작한다.', '{"clue_bonus_pct":8,"rare_loot_pct":3,"encounter_pct":5}', 3),
 ('night', 'phase', '삼경', '자정부터 오전 6시까지. 요괴가 가장 사나워지지만 귀한 것도 이때 모습을 보인다.', '{"combat_damage_pct":5,"incoming_damage_pct":10,"rare_loot_pct":8,"erosion_pct":10,"magic_pct":10,"encounter_pct":15}', 4),
 ('clear', 'weather', '청명', '하늘이 맑아 멀리까지 보인다. 활을 쏘기 좋고 길도 빠르다.', '{"ranged_pct":10,"gather_qty_pct":5,"travel_time_pct":-5}', 11),
 ('cloudy', 'weather', '담운', '옅은 구름이 해를 가린다. 영기가 고르게 퍼져 단서와 술법에 유리하다.', '{"clue_bonus_pct":6,"magic_pct":5,"ranged_pct":-5}', 12),
 ('rain', 'weather', '장우', '긴 비가 내린다. 약초가 잘 자라고 몸이 빨리 낫지만 길이 질고 활시위가 젖는다.', '{"gather_qty_pct":10,"healing_pct":5,"travel_time_pct":10,"ranged_pct":-10,"craft_quality":-3}', 13),
 ('fog', 'weather', '농무', '짙은 안개가 깔렸다. 가까이 붙어 싸우기 좋지만 활은 빗나가고, 안개 속에서 무언가 자주 나타난다.', '{"encounter_pct":15,"clue_bonus_pct":10,"rare_loot_pct":3,"melee_pct":5,"ranged_pct":-20}', 14),
 ('wind', 'weather', '삭풍', '찬바람이 거세다. 화살이 흔들리고 걸음이 느리지만 바람이 사기를 흩어 침식이 덜하다.', '{"travel_time_pct":8,"ranged_pct":-10,"erosion_pct":-10,"healing_pct":-5,"magic_pct":5}', 15),
 ('snow', 'weather', '설한', '눈이 쌓이고 몹시 춥다. 다니기 힘들고 상처가 더디 낫지만 눈 밑의 귀한 것이 드러난다.', '{"travel_time_pct":15,"gather_qty_pct":-10,"healing_pct":-10,"rare_loot_pct":6,"melee_pct":-5,"craft_quality":3}', 16),
 ('bloodmist', 'weather', '혈무', '붉은 안개가 내려앉았다. 요괴가 들끓고 침식이 빠르지만, 위험한 만큼 얻는 것도 크다.', '{"combat_damage_pct":10,"incoming_damage_pct":15,"rare_loot_pct":10,"erosion_pct":20,"encounter_pct":20,"magic_pct":10}', 17)
ON CONFLICT (env_key) DO UPDATE SET kind = excluded.kind, env_name = excluded.env_name, description = excluded.description, effects = excluded.effects, sort = excluded.sort;

-- 영역마다 날씨가 나오는 비중이 다르다(합 100).
INSERT INTO public.world_weather_climate(territory_id, weights) VALUES
 ('capital',    '{"clear":30,"cloudy":20,"rain":15,"fog":15,"wind":12,"snow":5,"bloodmist":3}'),
 ('north',      '{"clear":20,"cloudy":15,"rain":5,"fog":10,"wind":25,"snow":22,"bloodmist":3}'),
 ('east',       '{"clear":20,"cloudy":20,"rain":28,"fog":22,"wind":6,"snow":2,"bloodmist":2}'),
 ('south',      '{"clear":25,"cloudy":25,"rain":22,"fog":18,"wind":6,"snow":1,"bloodmist":3}'),
 ('frontier',   '{"clear":22,"cloudy":18,"rain":10,"fog":15,"wind":15,"snow":5,"bloodmist":15}'),
 ('underworld', '{"clear":15,"cloudy":30,"rain":10,"fog":30,"wind":5,"snow":2,"bloodmist":8}'),
 ('heavenward', '{"clear":40,"cloudy":25,"rain":8,"fog":7,"wind":15,"snow":3,"bloodmist":2}'),
 ('abyss',      '{"clear":8,"cloudy":20,"rain":10,"fog":22,"wind":10,"snow":5,"bloodmist":25}')
ON CONFLICT (territory_id) DO UPDATE SET weights = excluded.weights;

-- 시간대: 한국 시간 기준 6시간마다(해돋이 6~12시, 한낮 12~18시, 땅거미 18~24시, 삼경 0~6시)
CREATE OR REPLACE FUNCTION public.world_time_phase(p_ts timestamptz)
 RETURNS text LANGUAGE sql STABLE SET search_path TO 'pg_catalog'
AS $f$
  SELECT CASE WHEN h >= 6 AND h < 12 THEN 'dawn' WHEN h >= 12 AND h < 18 THEN 'noon' WHEN h >= 18 THEN 'dusk' ELSE 'night' END
  FROM (SELECT extract(hour FROM p_ts AT TIME ZONE 'Asia/Seoul')::int AS h) x
$f$;

-- 날씨: 한국 시간 0시·12시마다 영역별로 정해진다. 같은 때 같은 영역이면 누구에게나 같다.
CREATE OR REPLACE FUNCTION public.world_weather_key(p_territory text, p_ts timestamptz)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
  WITH t AS (SELECT coalesce((SELECT territory_id FROM public.world_weather_climate WHERE territory_id = p_territory), 'capital') AS tid),
  w AS (SELECT e.key AS k, sum(e.value::int) OVER (ORDER BY e.key) AS cum, sum(e.value::int) OVER () AS tot
        FROM public.world_weather_climate cl, t, jsonb_each_text(cl.weights) e WHERE cl.territory_id = t.tid)
  SELECT w.k FROM w, t
  WHERE abs(hashtext(t.tid || ':' || floor(extract(epoch FROM p_ts + interval '9 hours') / 43200)::bigint)::bigint) % w.tot < w.cum
  ORDER BY w.cum LIMIT 1
$f$;

CREATE OR REPLACE FUNCTION public.world_owner_territory(p_owner uuid)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT coalesce((SELECT r.territory_id FROM public.world_characters c JOIN public.world_map_regions r ON r.region_name = c.location OR r.region_id = c.location
                   WHERE c.owner_id = p_owner LIMIT 1), 'capital')
$f$;

-- 지금 이 조사원이 받는 날씨·시간대 효과의 합
CREATE OR REPLACE FUNCTION public.world_env_total(p_owner uuid, p_key text)
 RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT coalesce(sum(CASE WHEN (e.effects ->> p_key) ~ '^-?[0-9]+(\.[0-9]+)?$' THEN (e.effects ->> p_key)::numeric ELSE 0 END), 0)
  FROM public.world_environment_catalog e
  WHERE p_owner IS NOT NULL
    AND e.env_key IN (public.world_time_phase(now()), public.world_weather_key(public.world_owner_territory(p_owner), now()))
$f$;

-- 상태이상 효과 합계에 날씨·시간대를 더한다. 채집·제작·이동·회복·전투가 모두 이 값을 쓴다.
CREATE OR REPLACE FUNCTION public.world_status_effect_total(p_effect_key text)
 RETURNS numeric LANGUAGE sql STABLE SET search_path TO 'pg_catalog', 'public'
AS $function$
 select coalesce(sum(
   case when (cat.effects->>p_effect_key) ~ '^-?[0-9]+(\.[0-9]+)?$'
     then (cat.effects->>p_effect_key)::numeric * cs.potency
     else 0 end
 ),0) + public.world_env_total(public.fn_owner_auth_uid(), p_effect_key)
 from public.world_character_statuses cs
 join public.world_status_catalog cat using(status_key)
 where cs.owner_id=public.fn_owner_auth_uid() and cs.expires_at>now()
$function$;

-- 화면용: 지금 있는 영역의 시간대·날씨, 다음 날씨, 모든 영역의 날씨
CREATE OR REPLACE FUNCTION public.world_environment_snapshot()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); terr text; ph text; wk text; nx text; slot bigint; phase_end timestamptz; weather_end timestamptz; h int;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  terr := public.world_owner_territory(uid);
  ph := public.world_time_phase(now());
  wk := public.world_weather_key(terr, now());
  slot := floor(extract(epoch FROM now() + interval '9 hours') / 43200)::bigint;
  weather_end := to_timestamp((slot + 1) * 43200) - interval '9 hours';
  nx := public.world_weather_key(terr, weather_end + interval '1 minute');
  h := extract(hour FROM now() AT TIME ZONE 'Asia/Seoul')::int;
  phase_end := (date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') + make_interval(hours => (h / 6 + 1) * 6)) AT TIME ZONE 'Asia/Seoul';
  RETURN jsonb_build_object(
    'territory_id', terr,
    'phase', (SELECT jsonb_build_object('key', env_key, 'name', env_name, 'description', description, 'effects', effects, 'ends_at', phase_end) FROM public.world_environment_catalog WHERE env_key = ph),
    'weather', (SELECT jsonb_build_object('key', env_key, 'name', env_name, 'description', description, 'effects', effects, 'ends_at', weather_end) FROM public.world_environment_catalog WHERE env_key = wk),
    'next_weather', (SELECT jsonb_build_object('key', env_key, 'name', env_name) FROM public.world_environment_catalog WHERE env_key = nx),
    'territories', (SELECT jsonb_object_agg(cl.territory_id, jsonb_build_object('key', e.env_key, 'name', e.env_name))
                    FROM public.world_weather_climate cl JOIN public.world_environment_catalog e ON e.env_key = public.world_weather_key(cl.territory_id, now())),
    'catalog', (SELECT jsonb_agg(jsonb_build_object('key', env_key, 'kind', kind, 'name', env_name, 'description', description, 'effects', effects) ORDER BY sort) FROM public.world_environment_catalog));
END $f$;

-- 모든 기록에 그때의 시간대·날씨를 남긴다(칭호 조건 등에 쓴다).
CREATE OR REPLACE FUNCTION public.world_stamp_event_env()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
BEGIN
  IF new.actor_id IS NOT NULL THEN
    new.payload := coalesce(new.payload, '{}'::jsonb) || jsonb_build_object('env_phase', public.world_time_phase(now()),
      'env_weather', public.world_weather_key(public.world_owner_territory(new.actor_id), now()));
  END IF;
  RETURN new;
END $f$;
DROP TRIGGER IF EXISTS trg_world_stamp_event_env ON public.world_events;
CREATE TRIGGER trg_world_stamp_event_env BEFORE INSERT ON public.world_events FOR EACH ROW EXECUTE FUNCTION public.world_stamp_event_env();

-- ── 장비 내구도 ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.world_item_durability (
  owner_id uuid NOT NULL REFERENCES public.world_characters(owner_id) ON DELETE CASCADE,
  item_id text NOT NULL REFERENCES public.world_item_catalog(item_id),
  durability int NOT NULL CHECK (durability >= 0),
  max_durability int NOT NULL CHECK (max_durability > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (owner_id, item_id)
);
ALTER TABLE public.world_item_durability ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.world_item_durability FROM anon, authenticated;
GRANT SELECT ON public.world_item_durability TO authenticated;
DROP POLICY IF EXISTS world_item_durability_own ON public.world_item_durability;
CREATE POLICY world_item_durability_own ON public.world_item_durability FOR SELECT TO authenticated USING (owner_id = (SELECT auth.uid()));
GRANT SELECT, INSERT, UPDATE ON public.world_item_durability TO fn_owner_field;

-- 최대 내구도: 무기·방어구 50+단계×30, 도구 40+단계×20
CREATE OR REPLACE FUNCTION public.world_item_max_durability(p_item text)
 RETURNS int LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
  SELECT CASE WHEN category IN ('weapon', 'armor') THEN 50 + coalesce(tier, 1) * 30 WHEN category = 'tool' THEN 40 + coalesce(tier, 1) * 20 ELSE NULL END
  FROM public.world_item_catalog WHERE item_id = p_item
$f$;

-- 장착한 장비를 닳게 한다. 0이 되면 부서져 수리할 때까지 효과가 없다.
CREATE OR REPLACE FUNCTION public.world_durability_wear(p_owner uuid, p_slot text, p_amount int)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE it text; nm text; mx int; cur int; nxt int;
BEGIN
  SELECT e.item_id, i.item_name INTO it, nm FROM public.world_character_equipment e JOIN public.world_item_catalog i ON i.item_id = e.item_id
    WHERE e.owner_id = p_owner AND e.slot = p_slot;
  IF it IS NULL OR p_amount <= 0 THEN RETURN NULL; END IF;
  mx := public.world_item_max_durability(it); IF mx IS NULL THEN RETURN NULL; END IF;
  SELECT durability INTO cur FROM public.world_item_durability WHERE owner_id = p_owner AND item_id = it FOR UPDATE;
  cur := coalesce(cur, mx);
  IF cur <= 0 THEN RETURN jsonb_build_object('item_id', it, 'name', nm, 'durability', 0, 'max', mx, 'broke', false); END IF;
  nxt := greatest(0, cur - p_amount);
  INSERT INTO public.world_item_durability(owner_id, item_id, durability, max_durability, updated_at) VALUES (p_owner, it, nxt, mx, now())
  ON CONFLICT (owner_id, item_id) DO UPDATE SET durability = excluded.durability, max_durability = excluded.max_durability, updated_at = now();
  RETURN jsonb_build_object('item_id', it, 'name', nm, 'durability', nxt, 'max', mx, 'broke', nxt = 0, 'worn', nxt > 0 AND nxt * 4 < mx AND cur * 4 >= mx);
END $f$;

-- 수리: 수리 도구(어디서나, 최대치의 절반) 또는 안전지대 대장간에서 전으로(전부)
CREATE OR REPLACE FUNCTION public.world_equipment_repair(p_item_id text, p_method text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; r public.world_map_regions%rowtype;
  mx int; cur int; nxt int; cost int := 0; inv jsonb; msg text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_method NOT IN ('kit', 'gil') THEN RAISE EXCEPTION '알 수 없는 수리 방법입니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태에서는 수리할 수 없습니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = uid AND NOT a.defeated AND NOT coalesce(a.fled, false)) THEN RAISE EXCEPTION '전투 중에는 수리할 수 없습니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = uid AND e.status = 'active') THEN RAISE EXCEPTION '원정 중에는 수리할 수 없습니다.'; END IF;
  SELECT * INTO it FROM public.world_item_catalog WHERE item_id = p_item_id;
  IF NOT FOUND OR it.category NOT IN ('weapon', 'armor', 'tool') THEN RAISE EXCEPTION '수리할 수 없는 물품입니다.'; END IF;
  inv := coalesce(c.inventory, '{}'::jsonb);
  IF coalesce((inv ->> p_item_id)::int, 0) < 1 THEN RAISE EXCEPTION '가방에 그 장비가 없습니다.'; END IF;
  mx := public.world_item_max_durability(p_item_id);
  SELECT durability INTO cur FROM public.world_item_durability WHERE owner_id = uid AND item_id = p_item_id FOR UPDATE;
  cur := coalesce(cur, mx);
  IF cur >= mx THEN RAISE EXCEPTION '이미 멀쩡한 장비입니다.'; END IF;
  IF p_method = 'kit' THEN
    IF coalesce((inv ->> 'repair_kit')::int, 0) < 1 THEN RAISE EXCEPTION '장비 수리 도구가 없습니다. 안전지대 상점에서 사거나 만들 수 있습니다.'; END IF;
    inv := public.world_inv_add(inv, 'repair_kit', -1);
    nxt := least(mx, cur + ceil(mx * 0.5)::int);
    UPDATE public.world_characters SET inventory = inv, updated_at = now() WHERE owner_id = uid;
    msg := it.item_name || '을(를) 수리 도구로 손봤습니다. 내구도 ' || nxt || '/' || mx;
  ELSE
    r := public.world_field_region(c.location);
    IF NOT coalesce(r.is_safe_zone, false) THEN RAISE EXCEPTION '전을 내고 맡기는 수리는 안전지대에서만 할 수 있습니다. 바깥에서는 수리 도구를 쓰세요.'; END IF;
    cost := greatest(5, ceil((mx - cur) * (coalesce(it.tier, 1) + 1) / 2.0)::int);
    IF c.gil < cost THEN RAISE EXCEPTION '%', format('수리비 %s전이 모자랍니다.', cost); END IF;
    nxt := mx;
    UPDATE public.world_characters SET gil = gil - cost, updated_at = now() WHERE owner_id = uid;
    msg := it.item_name || ' 수리 완료 · ' || cost || '전';
  END IF;
  INSERT INTO public.world_item_durability(owner_id, item_id, durability, max_durability, updated_at) VALUES (uid, p_item_id, nxt, mx, now())
  ON CONFLICT (owner_id, item_id) DO UPDATE SET durability = excluded.durability, max_durability = excluded.max_durability, updated_at = now();
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'repair', msg, jsonb_build_object('item_id', p_item_id, 'method', p_method, 'cost', cost, 'durability', nxt));
  RETURN jsonb_build_object('ok', true, 'content', msg, 'durability', nxt, 'max', mx, 'cost', cost);
END $f$;

-- ── 전투 능력치 ─────────────────────────────────────────
-- 전투 엔진과 화면이 같은 값을 쓴다. p_delta로 능력치를 올렸을 때의 값을 미리 볼 수 있다.
CREATE OR REPLACE FUNCTION public.world_combat_stats(p_owner uuid, p_delta jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE c public.world_characters%rowtype; s_str int; s_agi int; s_vit int; s_per int; s_wil int; s_spi int;
  w_id text; w_name text; w_tr jsonb; w_dur int; w_max int; a_id text; a_name text; a_tr jsonb; a_dur int; a_max int;
  style text := 'melee'; wpow numeric := 2; wbonus numeric := 0; adef numeric := 0; adr numeric := 0; w_state text := 'none'; a_state text := 'none';
  base numeric; mind numeric := 1; pct numeric; style_pct numeric; attack numeric; defense numeric; red numeric; inc numeric; eva numeric; crit numeric; flee numeric;
BEGIN
  SELECT * INTO c FROM public.world_characters WHERE owner_id = p_owner;
  IF NOT FOUND THEN RETURN NULL; END IF;
  s_str := c.strength + coalesce((p_delta ->> 'strength')::int, 0); s_agi := c.agility + coalesce((p_delta ->> 'agility')::int, 0);
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

  base := CASE style
    WHEN 'ranged' THEN 6 + s_agi * 0.9 + s_per * 0.7 + wpow * 1.5 + c.level * 0.8
    WHEN 'magic' THEN 6 + s_spi * 1.1 + s_wil * 0.6 + wpow * 1.5 + c.level * 0.8
    ELSE 8 + s_str * 1.5 + wpow * 1.6 + c.level * 0.8 END;
  IF c.mental < 20 THEN mind := mind * 0.7; ELSIF c.mental < 40 THEN mind := mind * 0.85; END IF;
  IF c.erosion >= 80 THEN mind := mind * 0.7; ELSIF c.erosion >= 55 THEN mind := mind * 0.8; ELSIF c.erosion >= 30 THEN mind := mind * 0.9; END IF;
  style_pct := public.world_status_effect_total(style || '_pct') + public.world_title_bonus(style || '_pct');
  pct := public.world_status_effect_total('combat_damage_pct') + public.world_title_bonus('combat_damage_pct') + wbonus + style_pct;
  attack := base * (1 + coalesce(c.combat_rank, 1) * 0.015) * mind * (1 + pct / 100.0);
  defense := s_vit * 0.8 + adef + c.level * 0.5;
  red := 1 - (100.0 / (100 + defense * 3)) * (1 - adr / 100.0);
  inc := public.world_status_effect_total('incoming_damage_pct') + public.world_title_bonus('incoming_damage_pct');
  eva := least(30, 3 + s_agi * 0.35 + CASE WHEN c.job_key = 'scout' THEN 6 ELSE 0 END);
  crit := least(45, 5 + s_per * 0.4 + CASE WHEN style = 'ranged' THEN 8 ELSE 0 END + CASE WHEN c.job_key = 'analyst' THEN 8 ELSE 0 END);
  flee := least(90, 50 + s_agi + CASE WHEN c.job_key = 'scout' THEN 15 ELSE 0 END);
  RETURN jsonb_build_object(
    'style', style, 'attack', round(attack), 'attack_raw', attack, 'damage_pct', round(pct, 1), 'style_pct', round(style_pct, 1),
    'defense', round(defense, 1), 'reduction_pct', round(red * 100, 1), 'incoming_pct', round(inc, 1),
    'evasion_pct', round(eva, 1), 'crit_pct', round(crit, 1), 'crit_mult', 160, 'flee_pct', round(flee),
    'spell_cost', CASE WHEN style = 'magic' THEN 3 ELSE 0 END, 'mind_mul', round(mind, 2),
    'weapon', CASE WHEN w_id IS NULL THEN NULL ELSE jsonb_build_object('item_id', w_id, 'name', w_name, 'type', style, 'power', round(wpow, 1),
      'durability', w_dur, 'max', w_max, 'state', w_state) END,
    'armor', CASE WHEN a_id IS NULL THEN NULL ELSE jsonb_build_object('item_id', a_id, 'name', a_name, 'defense', round(adef, 1), 'reduction', adr,
      'durability', a_dur, 'max', a_max, 'state', a_state) END,
    'stats', jsonb_build_object('strength', s_str, 'agility', s_agi, 'vitality', s_vit, 'perception', s_per, 'willpower', s_wil, 'spirit_affinity', s_spi));
END $f$;

-- 화면용: 지금 능력치와, 능력치를 하나씩 올렸을 때의 값
CREATE OR REPLACE FUNCTION public.world_combat_profile()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); k text; prev jsonb := '{}'::jsonb;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  FOREACH k IN ARRAY ARRAY['strength', 'agility', 'vitality', 'perception', 'willpower', 'spirit_affinity'] LOOP
    prev := prev || jsonb_build_object(k, public.world_combat_stats(uid, jsonb_build_object(k, 1)) - 'weapon' - 'armor' - 'stats');
  END LOOP;
  RETURN jsonb_build_object('current', public.world_combat_stats(uid), 'plus_one', prev,
    'durability', (SELECT coalesce(jsonb_object_agg(d.item_id, jsonb_build_object('durability', d.durability, 'max', d.max_durability)), '{}'::jsonb)
                   FROM public.world_item_durability d WHERE d.owner_id = uid));
END $f$;

-- ── 수리 도구 제작법·판매처 ──────────────────────────────
INSERT INTO public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location,
  description, minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill, required_skill_rank)
VALUES ('repair_kit_recipe', '장비 수리 도구 제작', 'repair_kit', 2, '{"iron_ingot":1,"lumber":1,"talisman_thread":1}', NULL, 0, '연무장·팔괘진',
  '월철 주괴와 가공 부적목을 실로 묶어 수리 도구 두 벌을 만든다. 무기·방어구·도구의 내구도를 최대치의 절반만큼 되살린다.', 3, NULL, 2, 0, NULL, 1)
ON CONFLICT (recipe_id) DO NOTHING;
INSERT INTO public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
SELECT s, 'repair_kit', 150, 1, 4 FROM unnest(ARRAY['capital_market', 'river_market', 'south_market', 'frontier_market', 'underworld_market', 'astral_market']) s
WHERE NOT EXISTS (SELECT 1 FROM public.world_shop_catalog x WHERE x.shop_id = s AND x.item_id = 'repair_kit');
UPDATE public.world_item_catalog SET description = '무기·방어구·도구의 내구도를 최대치의 절반만큼 되살리는 정비 도구. 어디서나 쓸 수 있다.' WHERE item_id = 'repair_kit';

-- ── 소유권과 실행 권한 ─────────────────────────────────
ALTER FUNCTION public.world_weather_key(text, timestamptz) OWNER TO fn_owner_field;
ALTER FUNCTION public.world_owner_territory(uuid) OWNER TO fn_owner_field;
ALTER FUNCTION public.world_env_total(uuid, text) OWNER TO fn_owner_field;
ALTER FUNCTION public.world_environment_snapshot() OWNER TO fn_owner_field;
ALTER FUNCTION public.world_stamp_event_env() OWNER TO fn_owner_field;
ALTER FUNCTION public.world_item_max_durability(text) OWNER TO fn_owner_field;
ALTER FUNCTION public.world_durability_wear(uuid, text, int) OWNER TO fn_owner_field;
ALTER FUNCTION public.world_equipment_repair(text, text) OWNER TO fn_owner_field;
ALTER FUNCTION public.world_combat_stats(uuid, jsonb) OWNER TO fn_owner_field;
ALTER FUNCTION public.world_combat_profile() OWNER TO fn_owner_field;
REVOKE ALL ON FUNCTION public.world_time_phase(timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.world_time_phase(timestamptz) TO fn_owner_field;

SET ROLE fn_owner_field;
DO $$
DECLARE f record; ro text;
  rpc text[] := ARRAY['world_environment_snapshot', 'world_equipment_repair', 'world_combat_profile'];
BEGIN
  FOR f IN SELECT p.oid::regprocedure AS sig, p.proname FROM pg_proc p JOIN pg_roles r ON r.oid = p.proowner
           WHERE p.pronamespace = 'public'::regnamespace AND r.rolname = 'fn_owner_field'
             AND p.proname IN ('world_weather_key', 'world_owner_territory', 'world_env_total', 'world_environment_snapshot', 'world_stamp_event_env',
                               'world_item_max_durability', 'world_durability_wear', 'world_equipment_repair', 'world_combat_stats', 'world_combat_profile') LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f.sig);
    IF f.proname = ANY (rpc) THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f.sig); END IF;
  END LOOP;
END $$;
-- world_status_effect_total을 부르는 함수의 실행 역할이 날씨 합계를 읽을 수 있게 한다.
DO $$
DECLARE ro text;
BEGIN
  FOR ro IN SELECT DISTINCT r.rolname FROM pg_proc p JOIN pg_roles r ON r.oid = p.proowner
            WHERE p.pronamespace = 'public'::regnamespace AND p.prosrc LIKE '%world_status_effect_total%' AND r.rolname NOT IN ('postgres', 'fn_owner_field') LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.world_env_total(uuid, text) TO %I', ro);
  END LOOP;
END $$;
RESET ROLE;
