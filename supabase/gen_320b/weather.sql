select pg_temp.yh_fix('world_environment_snapshot', array[
  E'FROM public.world_weather_climate cl JOIN public.world_environment_catalog e ON e.env_key = public.world_weather_key(cl.territory_id, now()))',
  E'FROM (SELECT DISTINCT r.territory_id FROM public.world_map_regions r WHERE r.territory_id IS NOT NULL) cl JOIN public.world_environment_catalog e ON e.env_key = public.world_weather_key(cl.territory_id, now()))'
]);
