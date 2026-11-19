create table if not exists public.world_enhance_moves (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  from_item text not null,
  to_item text not null,
  level integer not null,
  moved_at timestamptz not null default now()
);
alter table public.world_enhance_moves enable row level security;
revoke all on public.world_enhance_moves from anon, authenticated;
grant select, insert, update, delete on public.world_enhance_moves to fn_owner_field;

create or replace function public.world_job_change_rules() returns jsonb language sql immutable as $function$
  select jsonb_build_object('cd_min', 60, 'price_base', 100, 'price_lv', 20,
    'alloc', jsonb_build_object(
      'artificer', jsonb_build_array('strength', 'vitality', 'agility'),
      'bloodknight', jsonb_build_array('strength', 'vitality', 'willpower'),
      'analyst', jsonb_build_array('strength', 'agility', 'perception'),
      'spearman', jsonb_build_array('strength', 'agility', 'perception'),
      'scout', jsonb_build_array('agility', 'perception', 'vitality'),
      'tamer', jsonb_build_array('agility', 'perception', 'vitality'),
      'exorcist', jsonb_build_array('spirit_affinity', 'willpower', 'perception'),
      'sealmaster', jsonb_build_array('spirit_affinity', 'willpower', 'vitality'),
      'medic', jsonb_build_array('spirit_affinity', 'willpower', 'vitality'),
      'formation', jsonb_build_array('spirit_affinity', 'willpower', 'perception')))
$function$;

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
               order by i.tier desc, (i.base_item_id is not null) desc, i.item_id loop
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
  execute $f$
CREATE OR REPLACE FUNCTION public.world_enhance_move_info()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); mv public.world_enhance_moves%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into mv from public.world_enhance_moves where owner_id = uid;
  return jsonb_build_object(
    'used', mv.owner_id is not null,
    'moved', case when mv.owner_id is not null then jsonb_build_object('from', mv.from_item, 'to', mv.to_item, 'level', mv.level, 'at', mv.moved_at) end,
    'weapons', coalesce((select jsonb_agg(jsonb_build_object('id', i.item_id, 'name', i.item_name, 'tier', i.tier, 'level', coalesce(g.level, 0),
                   'jobs', i.equipment_traits -> 'jobs', 'locked', exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = i.item_id))
                   order by i.tier desc, coalesce(g.level, 0) desc, i.item_name)
               from public.world_characters c, jsonb_each_text(c.inventory) iv
               join public.world_item_catalog i on i.item_id = iv.key and i.category = 'weapon'
               left join public.world_gear_enhance g on g.owner_id = uid and g.item_id = i.item_id
              where c.owner_id = uid and iv.value::int > 0), '[]'::jsonb));
end $function$
$f$;
  execute $f$
CREATE OR REPLACE FUNCTION public.world_enhance_move(p_from text, p_to text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; fi public.world_item_catalog%rowtype; ti public.world_item_catalog%rowtype; lv int; tlv int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  perform public.world_travel_guard('강화 옮기기');
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if not exists (select 1 from public.world_map_regions r where r.region_name = c.location and r.is_safe_zone) then raise exception '강화 옮기기는 안전지대 대장간에서 할 수 있습니다.'; end if;
  if exists (select 1 from public.world_enhance_moves where owner_id = uid) then raise exception '강화 옮기기는 한 사람에 한 번만 할 수 있습니다. 이미 썼습니다.'; end if;
  if p_from is null or p_to is null or p_from = p_to then raise exception '옮길 무기와 받을 무기를 따로 고르세요.'; end if;
  select * into fi from public.world_item_catalog where item_id = p_from;
  select * into ti from public.world_item_catalog where item_id = p_to;
  if fi.category is distinct from 'weapon' or ti.category is distinct from 'weapon' then raise exception '무기끼리만 옮길 수 있습니다.'; end if;
  if coalesce((c.inventory ->> p_from)::int, 0) < 1 or coalesce((c.inventory ->> p_to)::int, 0) < 1 then raise exception '두 무기가 모두 가방에 있어야 합니다.'; end if;
  if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id in (p_from, p_to)) then raise exception '잠긴 무기는 옮길 수 없습니다. 잠금을 풀고 오세요.'; end if;
  if ti.tier > fi.tier then raise exception '받을 무기의 단계가 옮길 무기보다 높으면 옮길 수 없습니다.'; end if;
  select level into lv from public.world_gear_enhance where owner_id = uid and item_id = p_from for update;
  if coalesce(lv, 0) < 1 then raise exception '옮길 무기에 강화가 없습니다.'; end if;
  select level into tlv from public.world_gear_enhance where owner_id = uid and item_id = p_to for update;
  if coalesce(tlv, 0) >= lv then raise exception '받을 무기의 강화가 이미 같거나 높습니다.'; end if;
  delete from public.world_gear_enhance where owner_id = uid and item_id = p_from;
  insert into public.world_gear_enhance(owner_id, item_id, level, updated_at) values (uid, p_to, lv, now())
  on conflict (owner_id, item_id) do update set level = excluded.level, updated_at = now();
  insert into public.world_enhance_moves(owner_id, from_item, to_item, level) values (uid, p_from, p_to, lv);
  return jsonb_build_object('ok', true, 'from', p_from, 'to', p_to, 'level', lv,
    'content', fi.item_name || '의 강화 +' || lv || '을(를) ' || ti.item_name || '(으)로 옮겼습니다. ' || fi.item_name || '은(는) +0이 되었습니다.');
end $function$
$f$;
  execute 'revoke all on function public.world_enhance_move_info() from public, anon';
  execute 'revoke all on function public.world_enhance_move(text, text) from public, anon';
  execute 'grant execute on function public.world_enhance_move_info(), public.world_enhance_move(text, text) to authenticated';
  execute 'reset role';
  if g then execute 'revoke create on schema public from fn_owner_field'; end if;
  if s then execute 'grant fn_owner_field to ' || quote_ident(current_user) || ' with set false'; end if;
end $m$;


do $p$
declare d text := pg_get_functiondef('public.world_character_purge(uuid)'::regprocedure);
begin
  if position('world_enhance_moves' in d) = 0 then
    if position('delete from public.world_gear_sets where owner_id = p_uid;' in d) = 0 then raise exception 'purge 자리 못 찾음'; end if;
    execute replace(d, 'delete from public.world_gear_sets where owner_id = p_uid;', 'delete from public.world_gear_sets where owner_id = p_uid;
  delete from public.world_enhance_moves where owner_id = p_uid;');
  end if;
end $p$;

update public.world_patch_notes
   set body = replace(replace(body,
     '새 직업 무기가 하나도 없으면 시작 무기 하나를 받습니다. 주 능력치가 상한에 닿아 남는 점수는 직접 나눕니다.',
     '무기 칸이 비면 가진 새 직업 무기 가운데 가장 높은 단계를 저절로 낍니다. 새 직업 무기가 하나도 없으면 맨손이 되니 미리 마련해 두세요(바꾸기 전 확인 창과 현장에 안내가 뜹니다). 주 능력치가 상한에 닿아 남는 점수는 직접 나눕니다.'),
     '- 떨어지는 무기는 내 직업 갈래가 더 잘 나옵니다.',
     '- 떨어지는 무기는 내 직업 갈래가 더 잘 나옵니다.
- 대장간 › 무기 강화의 「강화 옮기기」로, 강화한 무기의 강화 단계를 가방에 든 다른 무기(같은 단계 이하)로 옮길 수 있습니다. 한 사람에 한 번, 전·재료 없이 됩니다. 옮긴 무기는 +0이 됩니다.')
 where note_id = '3.0.0' and position('강화 옮기기' in body) = 0;
update public.world_app_meta set value = '20261123040000' where key = 'db_version';
