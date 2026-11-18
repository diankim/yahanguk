lock table public.world_characters in access exclusive mode;
lock table public.world_events in share mode;

create index if not exists idx_world_events_k_combat_line on public.world_events (actor_id, (payload ->> 'line')) where event_type = 'combat' and payload ? 'line';
create index if not exists idx_world_events_k_combat_wick on public.world_events (actor_id, (payload ->> 'wick')) where event_type = 'combat' and payload ? 'wick';
create index if not exists idx_world_events_k_explore_wn_alone on public.world_events (actor_id, (payload ->> 'wn_alone')) where event_type = 'explore' and payload ? 'wn_alone';
create index if not exists idx_world_events_k_use_item_item_id on public.world_events (actor_id, (payload ->> 'item_id')) where event_type = 'use_item' and payload ? 'item_id';
create index if not exists idx_world_events_k_travel_region_id on public.world_events (actor_id, (payload ->> 'region_id')) where event_type = 'travel' and payload ? 'region_id';
create index if not exists idx_world_events_k_gather_item_id on public.world_events (actor_id, (payload ->> 'item_id')) where event_type = 'gather' and payload ? 'item_id';

CREATE OR REPLACE FUNCTION public.world_title_ev_keys()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  select '{"fish": ["fish"], "combat": ["monster_id", "wick", "line"], "explore": ["wn_alone"], "use_item": ["item_id"], "travel": ["region_id"], "gather": ["item_id"]}'::jsonb
$function$;
revoke all on function public.world_title_ev_keys() from public, anon, authenticated;
grant execute on function public.world_title_ev_keys() to fn_owner_field;

CREATE OR REPLACE FUNCTION public.world_title_rule_ok(p_owner uuid, p_rule jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE n numeric := coalesce((p_rule ->> 'n')::numeric, 1); v numeric; x jsonb; ik text;
BEGIN
  IF p_rule IS NULL THEN RETURN false; END IF;
  IF p_rule ? 'all' THEN
    FOR x IN SELECT value FROM jsonb_array_elements(p_rule -> 'all') LOOP
      IF NOT public.world_title_rule_ok(p_owner, x) THEN RETURN false; END IF;
    END LOOP;
    RETURN true;
  ELSIF p_rule ? 'ev' THEN
    SELECT k INTO ik FROM jsonb_array_elements_text(public.world_title_ev_keys() -> (p_rule ->> 'ev')) WITH ORDINALITY z(k, o)
     WHERE jsonb_typeof(p_rule -> 'p' -> k) IN ('string', 'boolean') ORDER BY o LIMIT 1;
    IF ik IS NOT NULL THEN
      EXECUTE format($q$SELECT count(*) FROM (SELECT 1 FROM public.world_events e
      WHERE e.actor_id = $1 AND e.event_type = %L AND e.payload ? %L AND e.payload ->> %L = $3
        AND e.payload @> ($2 -> 'p')
        AND (NOT $2 ? 'has' OR e.payload ? ($2 ->> 'has'))
        AND (NOT $2 ? 'phase' OR coalesce(e.payload ->> 'env_phase', public.world_time_phase(e.created_at)) = $2 ->> 'phase')
        AND (NOT $2 ? 'gte' OR NOT EXISTS (SELECT 1 FROM jsonb_each_text($2 -> 'gte') g
               WHERE NOT (coalesce(e.payload ->> g.key, '') ~ '^-?[0-9]+(\.[0-9]+)?$' AND (e.payload ->> g.key)::numeric >= g.value::numeric)))
        LIMIT $4) x$q$, p_rule ->> 'ev', ik, ik)
      INTO v USING p_owner, p_rule, p_rule -> 'p' ->> ik, greatest(1, ceil(n))::bigint;
    ELSE
      SELECT count(*) INTO v FROM (SELECT 1 FROM public.world_events e
      WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> 'ev'
        AND (NOT p_rule ? 'p' OR e.payload @> (p_rule -> 'p'))
        AND (NOT p_rule ? 'has' OR e.payload ? (p_rule ->> 'has'))
        AND (NOT p_rule ? 'phase' OR coalesce(e.payload ->> 'env_phase', public.world_time_phase(e.created_at)) = p_rule ->> 'phase')
        AND (NOT p_rule ? 'gte' OR NOT EXISTS (SELECT 1 FROM jsonb_each_text(p_rule -> 'gte') g
               WHERE NOT (coalesce(e.payload ->> g.key, '') ~ '^-?[0-9]+(\.[0-9]+)?$' AND (e.payload ->> g.key)::numeric >= g.value::numeric)))
        LIMIT greatest(1, ceil(n))::bigint) x;
    END IF;
    RETURN v >= n;
  ELSIF p_rule ? 'distinct' THEN
    SELECT count(*) INTO v FROM (SELECT DISTINCT e.payload ->> (p_rule ->> 'key') FROM public.world_events e
    WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> 'distinct' AND e.payload ? (p_rule ->> 'key') AND e.payload ->> (p_rule ->> 'key') IS NOT NULL
      AND (NOT p_rule ? 'has' OR e.payload ? (p_rule ->> 'has')) LIMIT greatest(1, ceil(n))::bigint) x;
    RETURN v >= n;
  ELSIF p_rule ? 'char' THEN
    SELECT (to_jsonb(ch) ->> (p_rule ->> 'char'))::numeric INTO v FROM public.world_characters ch WHERE ch.owner_id = p_owner;
    IF v IS NULL THEN RETURN false; END IF;
    IF p_rule ? 'max' THEN RETURN v <= (p_rule ->> 'max')::numeric; END IF;
    RETURN v >= n;
  ELSIF p_rule ? 'nodes' THEN
    SELECT count(*) INTO v FROM public.world_exploration_discoveries WHERE owner_id = p_owner; RETURN v >= (p_rule ->> 'nodes')::numeric;
  ELSIF p_rule ? 'spots' THEN
    SELECT count(*) INTO v FROM public.world_gathering_discoveries WHERE owner_id = p_owner; RETURN v >= (p_rule ->> 'spots')::numeric;
  ELSIF p_rule ? 'mounts' THEN
    SELECT count(*) INTO v FROM public.world_owned_mounts WHERE owner_id = p_owner; RETURN v >= (p_rule ->> 'mounts')::numeric;
  ELSIF p_rule ? 'titles' THEN
    SELECT count(*) INTO v FROM public.world_character_titles WHERE owner_id = p_owner; RETURN v >= (p_rule ->> 'titles')::numeric;
  ELSIF p_rule ? 'spar' THEN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       RETURN public.world_spar_rule_count(p_owner, p_rule) >= n;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         ELSIF p_rule ? 'yohwa' THEN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             RETURN public.world_yohwa_rule_count(p_owner, p_rule) >= n;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ELSIF p_rule ? 'project' THEN RETURN public.world_project_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'mentor' THEN RETURN public.world_mentor_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'home' THEN RETURN public.world_home_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'tourney' THEN RETURN public.world_tourney_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'raid' THEN RETURN public.world_raid_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'codex' THEN
    RETURN public.world_codex_rule_count(p_owner, p_rule) >= n;
  ELSIF p_rule ? 'skill' THEN
    SELECT coalesce((ch.skill_progress -> (p_rule ->> 'skill') ->> 'rank')::int, 1) INTO v FROM public.world_characters ch WHERE ch.owner_id = p_owner;
    RETURN coalesce(v, 0) >= n;
  ELSIF p_rule ? 'skill_all' THEN
    SELECT count(*) INTO v FROM public.world_characters ch, jsonb_array_elements_text(p_rule -> 'skill_all') s(k)
     WHERE ch.owner_id = p_owner AND coalesce((ch.skill_progress -> s.k ->> 'rank')::int, 1) >= n;
    RETURN v >= jsonb_array_length(p_rule -> 'skill_all');
  ELSIF p_rule ? 'survey_full' THEN
    SELECT count(*) INTO v FROM public.world_map_regions r
    WHERE false; v := public.world_survey_full_count(p_owner);
    RETURN v >= (p_rule ->> 'survey_full')::numeric;
  END IF;
  RETURN false;
END $function$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119100000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
