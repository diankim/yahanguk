create or replace function public.world_pet_start(p_owner uuid, p_pet text)
 returns void language plpgsql security definer
 set search_path to 'pg_catalog', 'public'
as $function$
begin
  insert into public.world_pets(owner_id, pet_id, source) values (p_owner, p_pet, 'tamer_start')
  on conflict (owner_id, pet_id) do update set affinity = least(300, public.world_pets.affinity + 30);
  insert into public.world_pet_profile(owner_id, pet_id) values (p_owner, p_pet) on conflict (owner_id) do update set pet_id = excluded.pet_id, set_at = now();
  update public.world_housing set pet_id = null, pet_out = false, updated_at = now() where owner_id = p_owner and pet_id = p_pet;
end $function$;
select pg_temp.yh_own('public.world_pet_start(uuid, text)', 'fn_owner_field');
select pg_temp.yh_share('public.world_pet_start(uuid, text)');

drop function public.world_create_character_v2(text, text, text);
create function public.world_create_character_v2(p_name text, p_job text, p_faction text, p_pet text default null)
 returns jsonb language plpgsql security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare
  uid uuid := public.fn_owner_auth_uid();
  nm text := btrim(coalesce(p_name, ''));
  r public.world_characters%rowtype;
  job_label text; b jsonb; kit jsonb; inv jsonb; it record; pr jsonb := public.world_pet_partner_rules();
begin
  if uid is null then raise exception '로그인이 필요합니다.' using errcode = '28000'; end if;
  perform public.world_open_gate(uid);
  if exists (select 1 from public.world_characters where owner_id = uid) then
    raise exception '이미 캐릭터가 있습니다. 이름·직업·소속은 생성 후 변경할 수 없습니다.';
  end if;
  if char_length(nm) < 2 or char_length(nm) > 12 then raise exception '이름은 2~12자로 입력하세요.'; end if;
  if nm !~ '^[가-힣A-Za-z0-9 ]+$' then raise exception '이름에는 한글·영문·숫자·공백만 사용할 수 있습니다.'; end if;
  if replace(nm, ' ', '') = any (select replace(x, ' ', '') from unnest(public.world_sys_chat_names()) x) then raise exception '채팅 알림에 쓰는 이름이라 고를 수 없습니다.'; end if;
  job_label := public.world_job_label(p_job);
  if job_label is null then raise exception '직업을 선택하세요.'; end if;
  if p_job = 'tamer' and not coalesce(pr -> 'first' ? p_pet, false) then raise exception '함께 시작할 꼬마 동무를 고르세요.'; end if;
  if p_faction is null or p_faction not in ('headquarters','fieldbureau','archivebureau','sealbureau','medicalbureau','independent') then
    raise exception '소속을 선택하세요.';
  end if;
  if exists (select 1 from public.world_characters where lower(btrim(character_name)) = lower(nm)) then
    raise exception '이미 사용 중인 이름입니다.';
  end if;
  b := public.world_job_base(p_job);
  kit := case p_job
    when 'artificer'  then '{"weapon":"iron_sword","armor":"a1_iron","hat":"h1_guard","amulet":"m1_ward","tool":"field_knife"}'
    when 'scout'      then '{"weapon":"w_ranged1_keen","armor":"a1_light","shoes":"s1_swift","tool":"field_knife"}'
    when 'tamer'      then '{"weapon":"short_bow","armor":"a1_light","shoes":"s1_swift","tool":"field_knife"}'
    when 'exorcist'   then '{"weapon":"spirit_bell","armor":"a1_robe","amulet":"m1_spell","tool":"field_knife"}'
    when 'medic'      then '{"weapon":"w_magic1_silent","armor":"a1_robe","amulet":"m1_purify","tool":"field_knife"}'
    when 'sealmaster' then '{"weapon":"w_magic1_heavy","armor":"padded_coat","hat":"h1_calm","tool":"field_knife"}'
    else                   '{"weapon":"w_melee1_keen","armor":"padded_coat","norigae":"n1_keen","shoes":"s1_road","tool":"field_knife"}' end::jsonb;
  inv := '{"herb":2,"ward_talisman":1,"ore_pick":1,"seal_paper":1,"wood":0,"ore":0}'::jsonb;
  for it in select value v from jsonb_each_text(kit) loop inv := inv || jsonb_build_object(it.v, coalesce((inv ->> it.v)::int, 0) + 1); end loop;
  inv := inv || case p_job
    when 'scout'      then '{"ammo_arrow":100}'
    when 'tamer'      then jsonb_build_object('ammo_arrow', 100, 'pet_food', (pr ->> 'first_food')::int)
    when 'medic'      then '{"herb":5,"tonic":3}'
    when 'sealmaster' then '{"seal_paper":4,"ward_talisman":2}'
    when 'analyst'    then '{"tonic":2}'
    else '{}' end::jsonb;
  begin
    insert into public.world_characters(owner_id, character_name, occupation, inventory, job_key, faction_key,
                                        strength, agility, vitality, perception, willpower, spirit_affinity)
    values (uid, nm, job_label, inv, p_job, p_faction,
            (b ->> 'strength')::int, (b ->> 'agility')::int, (b ->> 'vitality')::int, (b ->> 'perception')::int, (b ->> 'willpower')::int, (b ->> 'spirit_affinity')::int)
    returning * into r;
  exception when unique_violation then
    raise exception '이미 사용 중인 이름이거나 캐릭터가 이미 있습니다.';
  end;
  insert into public.world_character_equipment(owner_id, slot, item_id)
  select uid, k.key, k.value from jsonb_each_text(kit) k
  on conflict (owner_id, slot) do nothing;
  if p_job = 'tamer' then perform public.world_pet_start(uid, p_pet); end if;
  return jsonb_build_object('ok', true, 'character_name', r.character_name, 'job_key', r.job_key, 'faction_key', r.faction_key, 'pet', case when p_job = 'tamer' then p_pet end);
end
$function$;
select pg_temp.yh_own('public.world_create_character_v2(text, text, text, text)', 'fn_owner_19111');
revoke all on function public.world_create_character_v2(text, text, text, text) from public, anon;
grant execute on function public.world_create_character_v2(text, text, text, text) to authenticated, service_role;
