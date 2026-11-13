lock table public.world_characters in access exclusive mode;

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

create or replace function public.world_reset_identity(p_job text, p_faction text, p_pet text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); owned boolean; out jsonb; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_job = 'tamer' then
    perform pg_advisory_xact_lock(hashtext('yh_pet_slot:' || uid::text));
    owned := exists (select 1 from public.world_pets p where p.owner_id = uid);
    if not owned and (p_pet is null or not (public.world_pet_partner_rules() -> 'first') ? p_pet) then
      raise exception '함께 시작할 꼬마 동무를 고르세요.';
    end if;
    if owned and p_pet is not null and not exists (select 1 from public.world_pets p where p.owner_id = uid and p.pet_id = p_pet) then
      raise exception '함께하는 동무가 아닙니다.';
    end if;
    if owned and p_pet is null and not exists (select 1 from public.world_pet_profile f where f.owner_id = uid) then
      raise exception '데리고 다닐 동무를 고르세요.';
    end if;
  end if;
  out := public.world_reset_identity(p_job, p_faction);
  if p_job = 'tamer' and p_pet is not null then
    if not owned then perform public.world_pet_start(uid, p_pet);
    else
      update public.world_housing set pet_id = null, pet_out = false, updated_at = now() where owner_id = uid and pet_id = p_pet;
      insert into public.world_pet_profile(owner_id, pet_id) values (uid, p_pet)
      on conflict (owner_id) do update set pet_id = excluded.pet_id, set_at = now();
    end if;
    select coalesce(p.nickname, s.pet_name) into nm from public.world_pets p join public.world_pet_species s using (pet_id) where p.owner_id = uid and p.pet_id = p_pet;
    out := out || jsonb_build_object('pet', p_pet, 'content', (out ->> 'content') || ' ' || public.world_josa(nm, '과', '와') || ' 함께 다닙니다.');
  end if;
  return out;
end $$;
revoke all on function public.world_reset_identity(text, text, text) from public, anon;
grant execute on function public.world_reset_identity(text, text, text) to authenticated, service_role;
select pg_temp.yh_own('public.world_reset_identity(text, text, text)', 'fn_owner_field');
grant execute on function public.world_reset_identity(text, text) to fn_owner_field;
set role fn_owner_18475;
revoke all on function public.world_reset_identity(text, text) from public, anon, authenticated;
reset role;
select pg_temp.yh_share('public.world_reset_identity(text, text)');

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116160000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
