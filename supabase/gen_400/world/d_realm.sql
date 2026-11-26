create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function public.world_hop_dist(x1 float8, y1 float8, x2 float8, y2 float8, t1 text, t2 text)
 returns float8 language sql stable set search_path to 'pg_catalog', 'public' as $f$
  select case when t1 is not distinct from t2 then sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
    else (select case when coalesce(r -> t1 ->> 'realm', 'main') = coalesce(r -> t2 ->> 'realm', 'main') then sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
      else coalesce(r -> t2 ->> 'gap', r -> t1 ->> 'gap', '78')::float8 end from (select public.world_domain_rules() r) z) end
$f$;
select pg_temp.yh_share('public.world_hop_dist(float8, float8, float8, float8, text, text)');
select pg_temp.yh_fix('world_travel_plan(uuid,text,integer)', array[
  'w := (sqrt((xs[u] - xs[v]) ^ 2 + (ys[u] - ys[v]) ^ 2) * 1.4', 'w := (public.world_hop_dist(xs[u], ys[u], xs[v], ys[v], terr[u], terr[v]) * 1.4',
  'hop := (sqrt((xs[path[i - 1]] - xs[path[i]]) ^ 2 + (ys[path[i - 1]] - ys[path[i]]) ^ 2) * 1.4', 'hop := (public.world_hop_dist(xs[path[i - 1]], ys[path[i - 1]], xs[path[i]], ys[path[i]], terr[path[i - 1]], terr[path[i]]) * 1.4']);
select pg_temp.yh_fix('world_region_dist(uuid)', array[
  'w := (sqrt((xs[u] - xs[v]) ^ 2 + (ys[u] - ys[v]) ^ 2) * 1.4', 'w := (public.world_hop_dist(xs[u], ys[u], xs[v], ys[v], terr[u], terr[v]) * 1.4']);
