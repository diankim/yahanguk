create or replace function public.world_dot_counts() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object('titles', (select count(*) from public.world_character_titles t where t.owner_id = uid and t.seen_at is null),
    'skills', coalesce(public.world_skill_pending(), 0));
end $f$;
revoke all on function public.world_dot_counts() from public, anon, authenticated;
grant execute on function public.world_dot_counts() to authenticated, service_role;
