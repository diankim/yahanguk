create or replace function public.world_wedding_now()
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); loc text; r jsonb;
begin
  if uid is null then return null; end if;
  select location into loc from public.world_characters where owner_id = uid;
  select jsonb_build_object('wed_id', w.wed_id, 'a', w.a_name, 'b', w.b_name, 'place', g.region_name, 'status', w.status, 'starts_at', w.starts_at, 'ends_at', w.ends_at)
    into r
    from public.world_weddings w
    left join public.world_map_regions g on g.region_id = w.region_id
   where w.status in ('ready', 'ceremony') and w.ends_at > now() and w.starts_at < now() + interval '30 minutes'
     and (uid in (w.a_id, w.b_id) or g.region_name = loc
       or exists (select 1 from public.world_notifications n where n.user_id = uid and n.kind = 'wedding_invite' and n.payload ->> 'wed_id' = w.wed_id::text))
   order by w.starts_at limit 1;
  return r;
end $function$;
revoke all on function public.world_wedding_now() from public, anon, authenticated;
grant execute on function public.world_wedding_now() to authenticated, service_role;
update public.world_app_meta set value = '20261108235000' where key = 'db_version';
