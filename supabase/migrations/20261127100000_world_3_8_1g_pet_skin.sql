create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

alter table public.world_pets add column if not exists skin text;

create or replace function public.world_pet_skin_rules() returns jsonb language sql immutable set search_path = pg_catalog as $$
  select '{"skins": {"snow_calico": {"pet": "spotted_cat", "how": "pet"}}}'::jsonb
$$;
alter function public.world_pet_skin_rules() owner to fn_owner_field;
revoke all on function public.world_pet_skin_rules() from public, anon, authenticated;
grant execute on function public.world_pet_skin_rules() to authenticated, service_role;

create or replace function public.world_pet_skins_for(p_uid uuid, p_pet text) returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  return coalesce((select jsonb_agg(k.key order by k.key) from jsonb_each(public.world_pet_skin_rules() -> 'skins') k
    where k.value ->> 'pet' = p_pet and k.value ->> 'how' = 'pet'
      and exists (select 1 from public.world_pets p where p.owner_id = p_uid and p.pet_id = p_pet)), '[]'::jsonb);
end $$;
alter function public.world_pet_skins_for(uuid, text) owner to fn_owner_field;
revoke all on function public.world_pet_skins_for(uuid, text) from public, anon, authenticated;

create or replace function public.world_pet_skin(p_pet text, p_skin text) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); sk text := nullif(btrim(coalesce(p_skin, '')), '');
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform 1 from public.world_pets where owner_id = uid and pet_id = p_pet for update;
  if not found then raise exception '함께하는 동무가 아닙니다.'; end if;
  if sk is not null and not (public.world_pet_skins_for(uid, p_pet) ? sk) then raise exception '이 동무가 입을 수 없는 무늬입니다.'; end if;
  update public.world_pets set skin = sk where owner_id = uid and pet_id = p_pet;
  return jsonb_build_object('ok', true, 'skin', sk, 'content', case when sk is null then '원래 무늬로 돌아갔습니다.' else '무늬를 바꿨습니다.' end);
end $$;
alter function public.world_pet_skin(text, text) owner to fn_owner_field;
revoke all on function public.world_pet_skin(text, text) from public, anon, authenticated;
grant execute on function public.world_pet_skin(text, text) to authenticated, service_role;

select pg_temp.yh_fix('world_pet_profile_of(uuid)', array[
$q$'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'affinity', p.affinity)$q$,
$q$'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'affinity', p.affinity, 'skin', p.skin)$q$]);

select pg_temp.yh_fix('world_housing_pets_view(uuid,uuid)', array[
$q$'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'grown'$q$,
$q$'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'skin', p.skin, 'grown'$q$]);

select pg_temp.yh_fix('world_pet_snapshot()', array[
$q$'baby', p.baby_look, 'got_at', p.got_at$q$,
$q$'baby', p.baby_look, 'skin', p.skin, 'skins', public.world_pet_skins_for(uid, p.pet_id), 'got_at', p.got_at$q$]);

select pg_temp.yh_fix('world_scene_folks(jsonb)', array[
$q$jsonb_build_object('id', f.pet_id, 'adult', public.world_pet_look_adult(p.affinity, p.baby_look))$q$,
$q$jsonb_build_object('id', f.pet_id, 'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'skin', p.skin)$q$]);

update public.world_patch_notes set body = body || E'\n- [동무] 꼬마 동무 도감에서 「무늬」로 동무의 무늬를 바꿀 수 있습니다. 얼룩 고양이에게 「눈송이 삼색」 무늬가 생겼습니다.'
where note_id = '3.8.0' and position('「눈송이 삼색」' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127100000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
