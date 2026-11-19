
do $m$
declare s boolean := not pg_has_role(current_user, 'fn_owner_field', 'SET'); g boolean := not has_schema_privilege('fn_owner_field', 'public', 'CREATE');
begin
  if s then execute 'grant fn_owner_field to ' || quote_ident(current_user) || ' with set true'; end if;
  if g then execute 'grant create on schema public to fn_owner_field'; end if;
  execute 'set role fn_owner_field';
  execute $f$
CREATE OR REPLACE FUNCTION public.world_reset_identity(p_job text, p_faction text, p_pet text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); owned boolean; out jsonb; nm text; wp record; wpn text;
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
  if not exists (select 1 from public.world_character_equipment e where e.owner_id = uid and e.slot = 'weapon') then
    for wp in select i.item_id from public.world_characters x, jsonb_each_text(x.inventory) iv join public.world_item_catalog i on i.item_id = iv.key
               where x.owner_id = uid and iv.value::int > 0 and i.category = 'weapon' and public.world_weapon_job_ok(i.category, i.equipment_traits, p_job)
                 and coalesce(i.minimum_level, 1) <= x.level
               order by i.tier desc, coalesce((select g.level from public.world_gear_enhance g where g.owner_id = uid and g.item_id = i.item_id), 0) desc, (i.base_item_id is not null) desc, i.item_id loop
      begin
        perform public.world_equip_item(wp.item_id);
        wpn := wp.item_id; exit;
      exception when others then null;
      end;
    end loop;
    if wpn is not null then
      out := out || jsonb_build_object('equipped', wpn, 'content', (out ->> 'content') || ' ' || public.world_josa((select item_name from public.world_item_catalog where item_id = wpn), '을', '를') || ' 손에 쥐었습니다.');
    else
      out := out || jsonb_build_object('no_weapon', true, 'content', (out ->> 'content') || ' 새 직업이 들 수 있는 무기가 없어 맨손입니다. 상점·제작·거래소에서 무기를 마련해 가방 › 장비에서 끼우세요.');
    end if;
  end if;
  if p_job = 'tamer' and p_pet is not null then
    if not owned then perform public.world_pet_start(uid, p_pet);
    else
      delete from public.world_housing_pets where keeper_id = uid and pet_id = p_pet;
      insert into public.world_pet_profile(owner_id, pet_id) values (uid, p_pet)
      on conflict (owner_id) do update set pet_id = excluded.pet_id, set_at = now();
    end if;
    select coalesce(p.nickname, s.pet_name) into nm from public.world_pets p join public.world_pet_species s using (pet_id) where p.owner_id = uid and p.pet_id = p_pet;
    out := out || jsonb_build_object('pet', p_pet, 'content', (out ->> 'content') || ' ' || public.world_josa(nm, '과', '와') || ' 함께 다닙니다.');
  end if;
  return out;
end $function$
$f$;
  execute 'reset role';
  if g then execute 'revoke create on schema public from fn_owner_field'; end if;
  if s then execute 'grant fn_owner_field to ' || quote_ident(current_user) || ' with set false'; end if;
end $m$;
update public.world_patch_notes set body = replace(body, '다른 무기(같은 단계 이하)로', '같은 단계거나 그 밑 단계의 다른 무기로') where note_id = '3.0.0' and body like '%다른 무기(같은 단계 이하)로%';
