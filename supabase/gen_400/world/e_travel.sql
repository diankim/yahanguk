create or replace function public.world_travel_rules()
 returns jsonb language sql immutable set search_path to 'pg_catalog', 'public' as $f$
  select jsonb_build_object('fam', jsonb_build_object('per', 6, 'cap', 30))
$f$;
revoke all on function public.world_travel_rules() from public, anon;
grant execute on function public.world_travel_rules() to authenticated, service_role;
do $$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' loop
    execute format('grant execute on function public.world_travel_rules() to %I', x);
  end loop;
end $$;
select pg_temp.yh_fix('world_travel_plan(uuid,text,integer)', array[
  'swap boolean; pr jsonb;', 'swap boolean; pr jsonb; raw_s float8 := 0; fam int := 0; fr jsonb := public.world_travel_rules() -> ''fam'';',
  'hop := hop * (1 - least(0.3, coalesce(vis, 0) * 0.06));', 'raw_s := raw_s + greatest(12, hop);
    hop := hop * (1 - least((fr ->> ''cap'')::float8 / 100, coalesce(vis, 0) * (fr ->> ''per'')::float8 / 100));',
  'IF cardinality(path) > 2 THEN secs := secs * 0.9; END IF;', 'fam := CASE WHEN raw_s > 0 THEN round((1 - secs / raw_s) * 100)::int ELSE 0 END;
  IF cardinality(path) > 2 THEN secs := secs * 0.9; END IF;',
  '''mount_id'', c.mount_id);', '''mount_id'', c.mount_id, ''fam'', fam);']);
select pg_temp.yh_fix('world_travel_quote(text)', array[
  '''project'', pl ->> ''project'');', '''project'', pl ->> ''project'', ''fam'', coalesce((pl ->> ''fam'')::int, 0));']);
select pg_temp.yh_fix('world_map_snapshot', array[
  '''travel_discount'',least(0.30,v.n*0.06),', '''travel_discount'',least((public.world_travel_rules() -> ''fam'' ->> ''cap'')::numeric / 100, v.n * (public.world_travel_rules() -> ''fam'' ->> ''per'')::numeric / 100),']);
