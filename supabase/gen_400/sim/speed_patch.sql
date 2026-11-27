do $$
declare cells jsonb := public.world_boss_rules() -> 'ttangul' -> 'board' -> 'cells'; k text; arms text := ''; ref jsonb := '{}';
begin
  foreach k in array array['gg', 'ux', 'mk', 'dh', 'du', 'by'] loop
    ref := ref || jsonb_build_object(k, to_jsonb(public.world_ug_nbm(k)));
    arms := arms || format(' when %L then %L::int[]', k, public.world_ug_nbm(k)::text);
  end loop;
  execute format('create or replace function public.world_du_qr(p_cell integer) returns integer[] language sql immutable set search_path to '''' as $f$ select array[(%L::jsonb -> (p_cell - 1) ->> 0)::int, (%L::jsonb -> (p_cell - 1) ->> 1)::int] $f$', cells, cells);
  execute format('create or replace function public.world_du_cell(p_q integer, p_r integer) returns integer language sql immutable set search_path to '''' as $f$ select (select o::int from jsonb_array_elements(%L::jsonb) with ordinality e(v, o) where (e.v ->> 0)::int = p_q and (e.v ->> 1)::int = p_r) $f$', cells);
  execute format('create or replace function public.world_ug_nbm(p_kind text) returns integer[] language sql immutable set search_path to ''pg_catalog'', ''public'' as $f$ select case p_kind %s end $f$', arms);
  foreach k in array array['gg', 'ux', 'mk', 'dh', 'du', 'by'] loop
    if to_jsonb(public.world_ug_nbm(k)) <> ref -> k then raise exception 'nbm % differs', k; end if;
  end loop;
end $$;
