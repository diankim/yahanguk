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


create or replace function public.world_avatar_px_drop(p_grp bigint) returns int
language plpgsql security definer set search_path = '' as $f$
declare n int;
begin
  update public.world_characters c set profile = c.profile - 'avatar' - 'avatar_px', updated_at = now()
    from public.world_avatars a
   where a.owner_id = c.owner_id and coalesce((c.profile ->> 'avatar_px')::boolean, false)
     and exists (select 1 from public.world_outfit_designs d, jsonb_each_text(a.look) k
                  where k.key in ('top_d', 'bottom_d', 'face_d', 'hair_d') and k.value ~ '^[0-9]+$'
                    and d.id = k.value::bigint and coalesce(d.origin, d.id) = p_grp);
  get diagnostics n = row_count;
  return n;
end $f$;
revoke all on function public.world_avatar_px_drop(bigint) from public, anon, authenticated;
grant execute on function public.world_avatar_px_drop(bigint) to fn_owner_field;

select pg_temp.yh_fix('world_outfit_design_remove', array[
  E'  get diagnostics n = row_count;\n  if n > 0 then',
  E'  get diagnostics n = row_count;\n  if n > 0 then\n    perform public.world_avatar_px_drop(p_grp);'
]);


update public.world_patch_notes set body = body || $N$
- 「내 모습」의 「얼굴로 쓰기」가 직접 그린 윗옷·아랫옷 도안도 그대로 담습니다(전에는 도안 옷을 빼고 기본 옷으로 그렸습니다). 바뀐 뒤 「내 모습」에서 한 번 저장하면 얼굴 그림이 새로 그려집니다.
- 운영진이 도안을 내리면 그 도안이 들어간 얼굴 그림은 기본 얼굴로 돌아갑니다.$N$
 where note_id = '3.0.0' and position('직접 그린 윗옷·아랫옷 도안도 그대로 담습니다' in body) = 0;


insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261120030000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
