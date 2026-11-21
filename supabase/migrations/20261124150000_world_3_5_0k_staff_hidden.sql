create or replace function public.world_staff_hidden(p_uid uuid) returns boolean
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  return exists (select 1 from public.world_staff s where s.owner_id = p_uid)
     and exists (select 1 from public.world_app_meta m where m.key = 'staff_hidden' and p_uid::text = any(string_to_array(m.value, ',')));
end $f$;
revoke all on function public.world_staff_hidden(uuid) from public, anon, authenticated;
grant execute on function public.world_staff_hidden(uuid) to fn_owner_social, fn_owner_field, service_role;

create or replace function public.world_avatar_look_of(p_owner uuid) returns jsonb
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  if public.world_staff_hidden(p_owner) and public.fn_owner_auth_uid() is distinct from p_owner then return null; end if;
  return (select public.world_avatar_look_clean(p_owner, a.look) from public.world_avatars a where a.owner_id = p_owner);
end $f$;

create or replace function pg_temp.rf(p_fn regprocedure, p_pairs text[]) returns void language plpgsql as $g$
declare src text := pg_get_functiondef(p_fn); i int; n int;
begin
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(src) - length(replace(src, p_pairs[2 * i - 1], ''))) / greatest(length(p_pairs[2 * i - 1]), 1);
    if n <> 1 then raise exception '% 조각 %: % 번 나옴', p_fn, i, n; end if;
    src := replace(src, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute src;
end $g$;

select pg_temp.rf('public.world_region_roster()'::regprocedure, array[
$o$WHERE x.location = loc AND x.owner_id <> uid ORDER BY$o$,
$n$WHERE x.location = loc AND x.owner_id <> uid AND NOT public.world_staff_hidden(x.owner_id) ORDER BY$n$]);

insert into public.world_app_meta(key, value, changed_at) values ('staff_hidden', 'd3ce7dbb-9d58-4fa5-ade7-33d4e75bb1fe', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124150000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
