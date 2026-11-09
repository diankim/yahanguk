lock table public.world_characters in access exclusive mode;

create table if not exists public.world_avatars (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  look jsonb not null default '{}'::jsonb,
  home_on boolean not null default true,
  updated_at timestamptz not null default now()
);
create table if not exists public.world_wardrobe (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  look_key text not null,
  got_at timestamptz not null default now(),
  primary key (owner_id, look_key)
);
alter table public.world_avatars enable row level security;
alter table public.world_wardrobe enable row level security;
revoke all on public.world_avatars from public, anon, authenticated;
revoke all on public.world_wardrobe from public, anon, authenticated;

create or replace function public.world_avatar_parts()
 returns jsonb language sql immutable
as $f$ select '@PARTS@'::jsonb $f$;

create or replace function public.world_avatar_get(p_owner uuid default null)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); who uuid; jk text; a public.world_avatars%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  who := coalesce(p_owner, uid);
  select c.job_key into jk from public.world_characters c where c.owner_id = who;
  if not found then raise exception '조사원을 찾을 수 없습니다.'; end if;
  select * into a from public.world_avatars where owner_id = who;
  if who <> uid then
    return jsonb_build_object('look', a.look, 'job', jk, 'home_on', coalesce(a.home_on, true));
  end if;
  return jsonb_build_object('look', a.look, 'job', jk, 'home_on', coalesce(a.home_on, true),
    'owned', coalesce((select jsonb_agg(w.look_key order by w.look_key) from public.world_wardrobe w where w.owner_id = uid), '[]'::jsonb));
end $f$;

create or replace function public.world_avatar_set(p_look jsonb, p_home_on boolean default null)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); jk text; r jsonb := public.world_avatar_parts(); k text; t text; v text; look jsonb := '{}'::jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select c.job_key into jk from public.world_characters c where c.owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if jsonb_typeof(p_look) is distinct from 'object' then raise exception '모습을 고르세요.'; end if;
  for k, t in select * from (values ('skin', 'skins'), ('hair', 'hair'), ('hair_color', 'hairColors'), ('eyes', 'eyes'), ('eye_color', 'eyeColors'), ('mouth', 'mouth')) x(k, t) loop
    v := p_look ->> k;
    if v is null or not (r -> 'free' -> t ? v) then raise exception '고를 수 없는 모습이 있습니다.'; end if;
    look := look || jsonb_build_object(k, v);
  end loop;
  foreach k in array array['top', 'bottom'] loop
    v := p_look ->> k;
    if v is null or not (r -> 'outfits' ? (k || ':' || v)) then raise exception '고를 수 없는 옷이 있습니다.'; end if;
    if v is distinct from (r -> 'job' -> jk ->> k) and not exists (select 1 from public.world_wardrobe w where w.owner_id = uid and w.look_key = k || ':' || v) then
      raise exception '아직 가지지 않은 옷입니다.'; end if;
    look := look || jsonb_build_object(k, v);
  end loop;
  v := coalesce(p_look ->> 'acc', '');
  if v <> '' and not exists (select 1 from public.world_wardrobe w where w.owner_id = uid and w.look_key = 'acc:' || v) then
    raise exception '아직 가지지 않은 장식입니다.'; end if;
  look := look || jsonb_build_object('acc', v);
  insert into public.world_avatars(owner_id, look, home_on) values (uid, look, coalesce(p_home_on, true))
  on conflict (owner_id) do update set look = excluded.look, home_on = coalesce(p_home_on, public.world_avatars.home_on), updated_at = now();
  return jsonb_build_object('ok', true, 'look', look, 'home_on', (select home_on from public.world_avatars where owner_id = uid));
end $f$;

revoke all on function public.world_avatar_parts() from public, anon, authenticated;
revoke all on function public.world_avatar_get(uuid) from public, anon;
revoke all on function public.world_avatar_set(jsonb, boolean) from public, anon;
grant execute on function public.world_avatar_get(uuid) to authenticated;
grant execute on function public.world_avatar_set(jsonb, boolean) to authenticated;

do $p$
declare d text := pg_get_functiondef('public.world_character_purge(uuid)'::regprocedure);
  a text := 'delete from public.world_quickslots where owner_id = p_uid;';
begin
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '캐릭터 정리 함수 모양이 예상과 다릅니다'; end if;
  if position('world_avatars' in d) = 0 then
    execute replace(d, a, a || E'\n  delete from public.world_avatars where owner_id = p_uid;\n  delete from public.world_wardrobe where owner_id = p_uid;');
  end if;
end $p$;

create or replace function public.world_avatar_room(p_owner uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return (select coalesce(jsonb_agg(jsonb_build_object('id', c.owner_id, 'name', c.character_name, 'job', c.job_key, 'look', a.look) order by c.owner_id = p_owner desc), '[]'::jsonb)
    from public.world_characters c left join public.world_avatars a on a.owner_id = c.owner_id
   where c.owner_id in (p_owner, public.world_housing_mate(p_owner)) and coalesce(a.home_on, true));
end $f$;
revoke all on function public.world_avatar_room(uuid) from public, anon, authenticated;
grant execute on function public.world_avatar_room(uuid) to fn_owner_field;

do $p$
declare d text := pg_get_functiondef((select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'world_housing_snapshot'));
  a text := $q$'drawings', public.world_drawing_room(uid, h.wall),$q$;
begin
  if position('world_avatar_room' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '별채 정보 함수 모양이 예상과 다릅니다'; end if;
  execute replace(d, a, a || $q$ 'avatars', public.world_avatar_room(own),$q$);
end $p$;

create or replace function public.world_avatar_look_of(p_owner uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return (select a.look from public.world_avatars a where a.owner_id = p_owner);
end $f$;
revoke all on function public.world_avatar_look_of(uuid) from public, anon, authenticated;
grant execute on function public.world_avatar_look_of(uuid) to fn_owner_field;

do $p$
declare d text := pg_get_functiondef((select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'world_character_card'));
  a text := $q$'pet', public.world_pet_profile_of(c.owner_id),$q$;
begin
  if position('world_avatar_look_of' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '조사원 카드 함수 모양이 예상과 다릅니다'; end if;
  execute replace(d, a, a || $q$ 'look', public.world_avatar_look_of(c.owner_id),$q$);
end $p$;

create or replace function public.world_set_avatar_px(p_image text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_image is null or length(p_image) > 40000 or p_image !~ '^data:image/png;base64,[A-Za-z0-9+/]+={0,2}$' then raise exception '얼굴 그림 형식이 올바르지 않습니다.'; end if;
  update public.world_characters set profile = coalesce(profile, '{}'::jsonb) || jsonb_build_object('avatar', p_image, 'avatar_px', true), updated_at = now() where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  return jsonb_build_object('ok', true, 'content', '내 모습을 얼굴로 씁니다.');
end $f$;
revoke all on function public.world_set_avatar_px(text) from public, anon;
grant execute on function public.world_set_avatar_px(text) to authenticated;

do $p$
declare d text := pg_get_functiondef((select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'world_set_avatar'));
  a text := $q$coalesce(profile, '{}'::jsonb) - 'avatar'$q$;
  b text := $q$ELSE coalesce(profile, '{}'::jsonb) || jsonb_build_object('avatar', p_image)$q$;
begin
  if position('avatar_px' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 or (length(d) - length(replace(d, b, ''))) / length(b) <> 1 then raise exception '프로필 사진 함수 모양이 예상과 다릅니다'; end if;
  execute replace(replace(d, a, a || $q$ - 'avatar_px'$q$), b, $q$ELSE (coalesce(profile, '{}'::jsonb) - 'avatar_px') || jsonb_build_object('avatar', p_image)$q$);
end $p$;

alter table public.world_item_catalog drop constraint if exists world_item_catalog_category_check;
alter table public.world_item_catalog add constraint world_item_catalog_category_check check (category = any (array['material', 'consumable', 'equipment', 'tool', 'weapon', 'armor', 'quest', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'furniture', 'pet', 'outfit']));

create or replace function public.world_outfit_rules()
 returns jsonb language sql immutable
as $f$ select '{"box_exp_pct": 2, "box_boss_pct": 1, "box": "of_bundle", "pool": ["of_top_vest", "of_top_jeoksam", "of_acc_scarf", "of_top_jeogori", "of_bottom_chima", "of_acc_norigae", "of_top_magoja", "of_acc_earring", "of_acc_glasses", "of_top_guard", "of_bottom_guard", "of_top_scout", "of_bottom_scout", "of_top_exorcist", "of_bottom_exorcist", "of_top_medic", "of_bottom_medic", "of_top_seal", "of_bottom_seal", "of_top_shadow", "of_bottom_shadow"], "tourney": "acc:foxmask"}'::jsonb $f$;
revoke all on function public.world_outfit_rules() from public, anon, authenticated;
grant execute on function public.world_outfit_rules() to fn_owner_field;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values
('of_top_vest', '무명 조끼', 'outfit', 1, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 300, 1, '{"look": "top:vest"}'::jsonb),
('of_top_jeoksam', '짧은 적삼', 'outfit', 1, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 350, 1, '{"look": "top:jeoksam"}'::jsonb),
('of_acc_scarf', '목도리', 'outfit', 1, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 400, 1, '{"look": "acc:scarf"}'::jsonb),
('of_top_jeogori', '연분홍 저고리', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 260, 1, '{"look": "top:jeogori"}'::jsonb),
('of_bottom_chima', '남빛 치마', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 320, 1, '{"look": "bottom:chima"}'::jsonb),
('of_acc_norigae', '노리개', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 300, 1, '{"look": "acc:norigae"}'::jsonb),
('of_top_magoja', '짧은 마고자', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 350, 1, '{"look": "top:magoja"}'::jsonb),
('of_acc_earring', '구슬 귀걸이', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 300, 1, '{"look": "acc:earring"}'::jsonb),
('of_acc_glasses', '둥근 안경', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 500, 1, '{"look": "acc:glasses"}'::jsonb),
('of_acc_flowerpin', '꽃 머리핀', 'outfit', 2, '객사 별채를 고쳐 준 답례로 받은 머리핀입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, false, 100, 1, '{"look": "acc:flowerpin"}'::jsonb),
('of_top_guard', '쇠미늘 갑옷', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:guard"}'::jsonb),
('of_bottom_guard', '검은 바지와 가죽 장화', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:guard"}'::jsonb),
('of_top_scout', '무명 철릭', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:scout"}'::jsonb),
('of_bottom_scout', '고동 바지와 미투리', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:scout"}'::jsonb),
('of_top_exorcist', '삼베 도포', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:exorcist"}'::jsonb),
('of_bottom_exorcist', '쪽빛 대님 바지', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:exorcist"}'::jsonb),
('of_top_medic', '쑥빛 앞치마 도포', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:medic"}'::jsonb),
('of_bottom_medic', '무명 대님 바지', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:medic"}'::jsonb),
('of_top_seal', '누비 전포', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:seal"}'::jsonb),
('of_bottom_seal', '검은 바지', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:seal"}'::jsonb),
('of_top_shadow', '먹빛 누비 전포', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:shadow"}'::jsonb),
('of_bottom_shadow', '먹빛 바지와 짚신', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:shadow"}'::jsonb),
('of_bundle', '옷 꾸러미', 'outfit', 2, '풀어 보면 옷이나 장신구 하나가 들어 있습니다. 다른 직업의 차림이 나오기도 합니다.', false, true, 400, 1, '{"box": true}'::jsonb)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = 1, equipment_traits = excluded.equipment_traits;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max) values
('capital_market', 'of_top_vest', 300, 0, 5), ('capital_market', 'of_acc_scarf', 400, 0, 5),
('river_market', 'of_top_jeoksam', 350, 0, 5), ('river_market', 'of_top_vest', 300, 0, 5),
('north_market', 'of_acc_scarf', 400, 0, 5), ('north_market', 'of_top_jeoksam', 350, 0, 5),
('south_market', 'of_top_vest', 300, 0, 5), ('south_market', 'of_top_jeoksam', 350, 0, 5)
on conflict do nothing;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, description, minimum_level, recipe_difficulty, craft_field) values
('r_of_jeogori', '연분홍 저고리 짓기', 'of_top_jeogori', 1, '{"silk": 2, "cloud_cotton": 1}', '영사와 운면으로 연분홍 저고리를 짓습니다.', 5, 1, 'weaving'),
('r_of_chima', '남빛 치마 짓기', 'of_bottom_chima', 1, '{"silk": 2, "cloud_cotton": 2}', '영사와 운면으로 남빛 치마를 짓습니다.', 5, 1, 'weaving'),
('r_of_norigae', '노리개 엮기', 'of_acc_norigae', 1, '{"talisman_thread": 2, "silk": 1}', '부적실을 꼬아 노리개를 엮습니다.', 8, 1, 'weaving'),
('r_of_magoja', '짧은 마고자 짓기', 'of_top_magoja', 1, '{"spirit_thread": 1, "silk": 2}', '영사 실타래로 짧은 마고자를 짓습니다.', 10, 2, 'weaving'),
('r_of_earring', '구슬 귀걸이 깎기', 'of_acc_earring', 1, '{"spirit_glass": 1, "ore": 2}', '영유리를 구슬로 깎아 귀걸이를 만듭니다.', 8, 1, 'artifice'),
('r_of_glasses', '둥근 안경 짜기', 'of_acc_glasses', 1, '{"spirit_glass": 2, "ore": 1}', '영유리 알 두 개를 월철 테에 끼웁니다.', 8, 1, 'artifice')
on conflict (recipe_id) do update set ingredients = excluded.ingredients, minimum_level = excluded.minimum_level, output_item = excluded.output_item, craft_field = excluded.craft_field;

update public.world_quest_steps set reward = reward || jsonb_build_object('items', coalesce(reward -> 'items', '{}'::jsonb) || '{"of_acc_flowerpin": 1}'::jsonb)
 where quest_id = 'hs_byeolchae' and step = (select max(step) from public.world_quest_steps where quest_id = 'hs_byeolchae') and not coalesce(reward -> 'items', '{}'::jsonb) ? 'of_acc_flowerpin';
insert into public.world_wardrobe(owner_id, look_key)
select g.owner_id, 'acc:flowerpin' from public.world_quest_progress g join public.world_characters c on c.owner_id = g.owner_id
 where g.quest_id = 'hs_byeolchae' and g.done_at is not null on conflict do nothing;

create or replace function public.world_wardrobe_add(p_item text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; k text; pick text; inv jsonb; r jsonb := public.world_outfit_rules();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select * into it from public.world_item_catalog where item_id = p_item and category = 'outfit';
  if not found then raise exception '옷이 아닙니다.'; end if;
  if coalesce((c.inventory ->> p_item)::int, 0) < 1 then raise exception '가방에 없습니다.'; end if;
  inv := c.inventory;
  inv := case when (inv ->> p_item)::int <= 1 then inv - p_item else jsonb_set(inv, array[p_item], to_jsonb((inv ->> p_item)::int - 1)) end;
  if coalesce((it.equipment_traits ->> 'box')::boolean, false) then
    select x into pick from jsonb_array_elements_text(r -> 'pool') x order by random() limit 1;
    inv := jsonb_set(inv, array[pick], to_jsonb(coalesce((inv ->> pick)::int, 0) + 1));
    update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
    return jsonb_build_object('ok', true, 'item', pick, 'content', '옷 꾸러미를 풀자 ' || public.world_josa((select item_name from public.world_item_catalog where item_id = pick), '이', '가') || ' 나왔습니다.');
  end if;
  k := it.equipment_traits ->> 'look';
  if k is null then raise exception '옷장에 넣을 수 없습니다.'; end if;
  if exists (select 1 from public.world_wardrobe w where w.owner_id = uid and w.look_key = k)
     or (public.world_avatar_parts() -> 'job' -> c.job_key ->> split_part(k, ':', 1)) = split_part(k, ':', 2) then
    raise exception '이미 옷장에 있는 옷입니다. 팔거나 다른 조사원에게 넘길 수 있습니다.';
  end if;
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  insert into public.world_wardrobe(owner_id, look_key) values (uid, k);
  return jsonb_build_object('ok', true, 'look', k, 'content', public.world_josa(it.item_name, '을', '를') || ' 옷장에 넣었습니다. 「내 모습」에서 고를 수 있습니다.');
end $f$;
revoke all on function public.world_wardrobe_add(text) from public, anon;
grant execute on function public.world_wardrobe_add(text) to authenticated;
grant insert on public.world_wardrobe to fn_owner_field;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[], p_n int) returns void language plpgsql as $x$
declare d text; i int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if position(p_pairs[2 * i] in d) > 0 then return; end if;
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> p_n then raise exception '함수 % 모양이 예상과 다릅니다', p_name; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $x$;

select pg_temp.yh_fix('world_expedition_complete', array[
$q$if e.settled_rounds >= total_rounds and ended = 'complete' and e.node_id is not null$q$,
$q$if e.settled_rounds >= total_rounds and ended = 'complete' and random() * 100 < (public.world_outfit_rules() ->> 'box_exp_pct')::numeric then
      loot := public.world_inv_add(loot, public.world_outfit_rules() ->> 'box', 1);
      lg := lg || jsonb_build_array('길가에 떨어진 옷 꾸러미 하나를 주웠습니다.');
    end if;
    if e.settled_rounds >= total_rounds and ended = 'complete' and e.node_id is not null$q$], 1);

select pg_temp.yh_fix('world_event_char_apply', array[
$q$  if hp_tick = 0 and mn_tick = 0 and tok = 0 and xp_e = 0$q$,
$q$  if k = 'combat' and won and rare is null and p ->> 'rank' = 'guardian' and random() * 100 < (public.world_outfit_rules() ->> 'box_boss_pct')::numeric then rare := public.world_outfit_rules() ->> 'box'; end if;
  if hp_tick = 0 and mn_tick = 0 and tok = 0 and xp_e = 0$q$], 1);

select pg_temp.yh_fix('world_tourney_finish', array[
$q$on conflict do nothing;
    select count(*) into nchamp$q$,
$q$on conflict do nothing;
    insert into public.world_wardrobe(owner_id, look_key) values (u, public.world_outfit_rules() ->> 'tourney') on conflict do nothing;
    select count(*) into nchamp$q$], 1);

update public.world_app_meta set value = '20261110000000' where key = 'db_version';
