create or replace function public.world_status_dismiss(p_status text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); n int; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select s.status_name into nm from public.world_status_catalog s
   where s.status_key = p_status and s.polarity = 'positive'
     and not (public.world_status_rules() -> 'outside') ? s.status_key;
  if nm is null then raise exception '이로운 상태만 끌 수 있습니다.'; end if;
  delete from public.world_character_statuses where owner_id = uid and status_key = p_status and expires_at > now();
  get diagnostics n = row_count;
  if n = 0 then raise exception '지금 받고 있는 상태가 아닙니다.'; end if;
  return jsonb_build_object('ok', true, 'status', p_status, 'name', nm);
end $function$;

alter function public.world_status_dismiss(text) owner to fn_owner_field;
revoke all on function public.world_status_dismiss(text) from public, anon, authenticated;
grant execute on function public.world_status_dismiss(text) to authenticated, service_role;

update public.world_patch_notes set body = body || E'\n- 이로운 상태는 상태 창에서 「이 효과 끄기」로 직접 끌 수 있습니다. 새 기운을 받을 칸을 비울 때 쓰세요.'
where note_id = '1.1.0' and position('이 효과 끄기' in body) = 0;

update public.world_app_meta set value = '20261113020000' where key = 'db_version';
