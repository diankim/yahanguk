create or replace function public.world_travel_quote(p_region_id text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); lv int; pl jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select c.level into lv from public.world_characters c where c.owner_id = uid;
  if lv is null then return null; end if;
  begin
    pl := public.world_travel_plan(uid, p_region_id, lv);
  exception when others then return jsonb_build_object('error', sqlerrm);
  end;
  return jsonb_build_object('secs', round((pl ->> 'secs')::numeric), 'hops', (pl ->> 'hops')::int, 'fare', (pl ->> 'fare')::int, 'need', (pl ->> 'need')::int,
    'walked', (pl ->> 'walked')::boolean, 'project', pl ->> 'project');
end $f$;
revoke all on function public.world_travel_quote(text) from public, anon;
grant execute on function public.world_travel_quote(text) to authenticated, service_role;
grant create on schema public to fn_owner_field;
alter function public.world_travel_quote(text) owner to fn_owner_field;
revoke create on schema public from fn_owner_field;
