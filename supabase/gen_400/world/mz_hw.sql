create or replace function public.world_meisho_grade_at(p_region text, p_level integer) returns integer language plpgsql stable set search_path to 'pg_catalog', 'public' as $f$
begin
  return coalesce((public.world_meisho_rules() #>> array['soil', 'realm', coalesce(public.world_region_realm(p_region), 'main')])::int, public.world_meisho_grade(p_level));
end $f$;
alter function public.world_meisho_grade_at(text, integer) owner to fn_owner_field;
revoke all on function public.world_meisho_grade_at(text, integer) from public, anon, authenticated;
select pg_temp.yh_hw_fix('public.world_meisho_soil(text)'::regprocedure, 'g := public.world_meisho_grade(m.min_level);', 'g := public.world_meisho_grade_at(m.region_id, m.min_level);');
select pg_temp.yh_hw_fix('public.world_meisho_card(uuid, text, jsonb)'::regprocedure, '''grade'', public.world_meisho_grade(m.min_level)', '''grade'', public.world_meisho_grade_at(m.region_id, m.min_level)');
select pg_temp.yh_hw_fix('public.world_item_sources_all(text)'::regprocedure, '= public.world_meisho_grade(x.min_level)', '= public.world_meisho_grade_at(x.region_id, x.min_level)');
select pg_temp.yh_hw_fix('public.world_item_sources_all(text)'::regprocedure,
  'or (public.world_item_base(p_item) = public.world_meisho_rules() -> ''lamp'' -> ''items'' ->> x.kind',
  'or (public.world_item_base(p_item) = public.world_meisho_rules() -> ''flow'' -> ''items'' ->> x.kind and r.territory_id in (select jsonb_array_elements_text(public.world_meisho_rules() -> ''flow'' -> ''territory'')))
                 or (public.world_item_base(p_item) = public.world_meisho_rules() -> ''lamp'' -> ''items'' ->> x.kind');
select pg_temp.yh_hw_fix('public.world_regular_rare()'::regprocedure, 'union select l.value #>> ''{}'' from jsonb_each(m -> ''lamp'' -> ''items'') l',
  'union select l.value #>> ''{}'' from jsonb_each(m -> ''lamp'' -> ''items'') l union select l.value #>> ''{}'' from jsonb_each(m -> ''flow'' -> ''items'') l');
select pg_temp.yh_hw_fix('public.world_meisho_dig(text)'::regprocedure, '  lim := public.world_bag_limit(uid);',
'  if ru ? ''flow'' and rank >= (ru #>> ''{flow,rank}'')::int
     and (select r.territory_id from public.world_map_regions r where r.region_id = m.region_id) in (select jsonb_array_elements_text(ru -> ''flow'' -> ''territory'')) then
    lp := least((ru #>> ''{flow,pct,cap}'')::numeric, (ru #>> ''{flow,pct,base}'')::numeric + public.world_meisho_gear(uid, ''mz_l_pct''));
    if random() * 100 < lp then extra := extra || jsonb_build_object(ru -> ''flow'' -> ''items'' ->> m.kind, 1); end if;
  end if;
  lim := public.world_bag_limit(uid);');
alter table public.world_bijang_maps drop constraint world_bijang_maps_tier_check;
alter table public.world_bijang_maps add constraint world_bijang_maps_tier_check check (tier >= 1 and tier <= 4);
