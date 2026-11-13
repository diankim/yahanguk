select pg_temp.yh_fix('world_field_search', array[
$q$d_ixp int := 0; d_mn int := 0; d_sp int := 0; e_add int := 0;$q$,
$q$d_ixp int := 0; d_mn int := 0; d_sp int := 0; e_add int := 0; mz public.world_meisho%rowtype; w_mz float8 := 0;$q$,

$q$  IF spot.spot_id IS NOT NULL THEN w_spot := 18; END IF;$q$,
$q$  IF spot.spot_id IS NOT NULL THEN w_spot := 18; END IF;
  SELECT * INTO mz FROM public.world_meisho x WHERE x.node_id = n.node_id AND x.active AND c.level >= x.min_level
    AND NOT EXISTS (SELECT 1 FROM public.world_meisho_finds f WHERE f.owner_id = uid AND f.meisho_id = x.meisho_id)
    AND coalesce((public.world_meisho_when(x.meisho_id) ->> 'open')::boolean, false) ORDER BY x.sort LIMIT 1;
  IF mz.meisho_id IS NOT NULL THEN w_mz := (public.world_meisho_rules() ->> 'find_w')::numeric * (1 + public.world_explore_find_pct(uid) / 100.0); END IF;$q$,

$q$  outcome := CASE
    WHEN roll < w_path THEN 'path'$q$,
$q$  outcome := CASE
    WHEN w_mz > 0 AND random() * (tot + w_mz) < w_mz THEN 'meisho'
    WHEN roll < w_path THEN 'path'$q$,

$q$  IF outcome = 'path' THEN
    INSERT INTO public.world_exploration_discoveries$q$,
$q$  IF outcome = 'meisho' THEN
    INSERT INTO public.world_meisho_finds(owner_id, meisho_id) VALUES (uid, mz.meisho_id) ON CONFLICT DO NOTHING;
    txt := '이름난 자리를 찾았다 — 명소 「' || mz.meisho_name || '」. ' || mz.description;
    xp := (public.world_meisho_rules() ->> 'find_xp')::int; payload := jsonb_build_object('meisho_id', mz.meisho_id, 'meisho', mz.meisho_name, 'kind', mz.kind);
  ELSIF outcome = 'path' THEN
    INSERT INTO public.world_exploration_discoveries$q$]);

select pg_temp.yh_fix('world_field_snapshot', array[
$q$    'hidden_spots', (SELECT count(*) FROM public.world_gathering_spots s WHERE s.node_id = n.node_id AND s.active$q$,
$q$    'meisho', public.world_meisho_field(uid, r.region_id, n.node_id),
    'hidden_spots', (SELECT count(*) FROM public.world_gathering_spots s WHERE s.node_id = n.node_id AND s.active$q$]);

select pg_temp.yh_fix('world_item_sources_all', array[
$q$public.world_source_region_ok('fish', r.is_safe_zone, r.active))
  select jsonb_build_object($q$,
$q$public.world_source_region_ok('fish', r.is_safe_zone, r.active)),
       z as (select distinct r.region_name, r.min_level from public.world_meisho x join public.world_map_regions r using (region_id)
               where x.active and (public.world_item_base(p_item) in (select jsonb_array_elements_text(public.world_meisho_rules() -> 'kinds' -> x.kind -> 'items'))
                 or public.world_bijang_tier_of(public.world_item_base(p_item)) = public.world_meisho_grade(x.min_level)))
  select jsonb_build_object(
    'meisho', (select coalesce(jsonb_agg(region_name order by min_level, region_name), '[]') from (select * from z order by min_level, region_name) x), 'meisho_n', (select count(*) from z),$q$]);

select pg_temp.yh_fix('world_item_sources', array[
$q$    'fish',     (select coalesce(jsonb_agg(v order by o), '[]') from jsonb_array_elements(s -> 'fish') with ordinality a(v, o) where o <= 6))$q$,
$q$    'fish',     (select coalesce(jsonb_agg(v order by o), '[]') from jsonb_array_elements(s -> 'fish') with ordinality a(v, o) where o <= 6),
    'meisho',   (select coalesce(jsonb_agg(v order by o), '[]') from jsonb_array_elements(s -> 'meisho') with ordinality a(v, o) where o <= 6))$q$]);

select pg_temp.yh_fix('world_gather_codex_snapshot', array[
$q$  return jsonb_build_object(
    'items', (with it as ($q$,
$q$  return jsonb_build_object(
    'meisho', (select coalesce(jsonb_agg(case when f.owner_id is null
        then jsonb_build_object('found', false, 'kind_name', public.world_meisho_rules() -> 'kinds' -> x.kind ->> 'name', 'region', r.region_name, 'level', x.min_level)
        else jsonb_build_object('found', true, 'id', x.meisho_id, 'name', x.meisho_name, 'kind_name', public.world_meisho_rules() -> 'kinds' -> x.kind ->> 'name', 'region', r.region_name,
          'level', x.min_level, 'phase', x.phase, 'weather', x.weather, 'weather2', x.weather2, 'digs', f.dig_count) end order by x.min_level, x.sort), '[]'::jsonb)
      from public.world_meisho x join public.world_map_regions r on r.region_id = x.region_id
      left join public.world_meisho_finds f on f.owner_id = uid and f.meisho_id = x.meisho_id where x.active),
    'meisho_items', (select coalesce(jsonb_agg(jsonb_build_object('id', i.v, 'name', ic.item_name, 'got', exists (select 1 from public.world_events e
        where e.actor_id = uid and e.event_type = 'gather' and e.payload ? 'meisho_id' and (e.payload ->> 'item_id' = i.v or coalesce(e.payload -> 'extra', '{}'::jsonb) ? i.v))) order by kk.k, i.o), '[]'::jsonb)
      from jsonb_each(public.world_meisho_rules() -> 'kinds') kk(k, kv), jsonb_array_elements_text(kk.kv -> 'items') with ordinality i(v, o)
      join public.world_item_catalog ic on ic.item_id = i.v),
    'items', (with it as ($q$]);

select pg_temp.yh_fix('world_character_purge', array[
$q$  delete from public.world_fish_log where owner_id = p_uid;$q$,
$q$  delete from public.world_fish_log where owner_id = p_uid;
  delete from public.world_meisho_finds where owner_id = p_uid;$q$]);

select pg_temp.yh_fix('world_item_sources_all', array[
$q$    'vault', exists (select 1 from public.world_faction_vault where item_id = p_item))$q$,
$q$    'vault', exists (select 1 from public.world_faction_vault where item_id = p_item),
    'bijang', case when exists (select 1 from jsonb_array_elements(public.world_bijang_rules() -> 'final' -> 'items') v where v ->> 'id' = public.world_item_base(p_item)) then 'final'
      when exists (select 1 from jsonb_each(public.world_bijang_rules() -> 'chest') c, jsonb_array_elements(c.value -> 'items') v where v ->> 'id' = public.world_item_base(p_item)) then 'chest' end)$q$]);
