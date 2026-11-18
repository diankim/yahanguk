lock table public.world_characters in access exclusive mode;

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

create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;


select pg_temp.yh_fix('world_environment_snapshot', array[
  E'FROM public.world_weather_climate cl JOIN public.world_environment_catalog e ON e.env_key = public.world_weather_key(cl.territory_id, now()))',
  E'FROM (SELECT DISTINCT r.territory_id FROM public.world_map_regions r WHERE r.territory_id IS NOT NULL) cl JOIN public.world_environment_catalog e ON e.env_key = public.world_weather_key(cl.territory_id, now()))'
]);


update public.world_patch_notes set body = body || $N$
- 지도에서 귀허도 영역 이름 아래에 날씨가 보이지 않던 것을 고쳤습니다(날씨 자체는 그대로입니다).$N$
 where note_id = '3.0.0' and position('귀허도 영역 이름 아래에 날씨가' in body) = 0;


insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261121010000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
