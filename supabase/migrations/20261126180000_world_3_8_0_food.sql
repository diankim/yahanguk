create temp table yh_patch_n(n int) on commit drop;

create or replace function pg_temp.yh_patch(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text; n int;
begin
  select prosrc into src from pg_proc where oid = p_fn;
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'patch % : % 번 나옴 — %', p_fn, n, left(p_old, 60); end if;
  src := replace(src, p_old, p_new);
  execute regexp_replace(pg_get_functiondef(p_fn), 'AS \$function\$.*\$function\$', '', 's') || ' AS $yhfn$' || src || '$yhfn$';
end $f$;

create or replace function public.world_food_rules() returns jsonb language sql immutable as $f$ select '{"meats": ["mt_chicken", "mt_beast", "mt_pheasant", "mt_boar", "mt_crab", "mt_yofish"], "meat_p": {"normal": 0.25, "elite": 0.4, "guardian": 0.6}, "meat_n": [1, 2], "fixed": ["sp_night_office_1", "sp_night_office_2", "sp_red_moon_cult_1", "sp_red_moon_cult_2", "sp_black_lotus_1", "sp_black_lotus_2", "sp_north_league_1", "sp_north_league_2", "sp_river_alliance_1", "sp_river_alliance_2", "sp_southern_remnant_1", "sp_southern_remnant_2", "sp_mandate_court_1", "sp_mandate_court_2"], "cap": 5, "shop_mul": 1.3, "show_min": [10, 6], "specials": {"night_office": ["sp_night_office_1", "sp_night_office_2"], "red_moon_cult": ["sp_red_moon_cult_1", "sp_red_moon_cult_2"], "black_lotus": ["sp_black_lotus_1", "sp_black_lotus_2"], "north_league": ["sp_north_league_1", "sp_north_league_2"], "river_alliance": ["sp_river_alliance_1", "sp_river_alliance_2"], "southern_remnant": ["sp_southern_remnant_1", "sp_southern_remnant_2"], "mandate_court": ["sp_mandate_court_1", "sp_mandate_court_2"]}, "hubs": {"night_office": "백등 야시장", "red_moon_cult": "백골 장터", "black_lotus": "십삼문 암시장", "north_league": "철벽 고찰", "river_alliance": "구름나루", "southern_remnant": "잔불촌", "mandate_court": "무극 관성대"}, "buffs": ["st_meat_power", "st_root_warm", "st_grain_full", "st_great_table", "fs_night_office", "fs_red_moon_cult", "fs_black_lotus", "fs_north_league", "fs_river_alliance", "fs_southern_remnant", "fs_mandate_court"]}'::jsonb $f$;

create or replace function public.world_food_is_meat(p_item text) returns boolean language sql immutable as $f$ select coalesce((public.world_food_rules() -> 'meats') ? p_item, false) $f$;

create or replace function public.world_food_fixed() returns text[] language sql immutable as $f$ select array(select jsonb_array_elements_text(public.world_food_rules() -> 'fixed')) $f$;

create or replace function public.world_food_meat_roll(p_loot jsonb, p_drops jsonb, p_rank text) returns jsonb language plpgsql volatile set search_path = pg_catalog, public as $f$
declare r jsonb := public.world_food_rules(); k text; p numeric; lo int := (r -> 'meat_n' ->> 0)::int; hi int := (r -> 'meat_n' ->> 1)::int; out jsonb := coalesce(p_loot, '{}'::jsonb);
begin
  p := coalesce((r -> 'meat_p' ->> coalesce(p_rank, 'normal'))::numeric, (r -> 'meat_p' ->> 'normal')::numeric);
  for k in select d.key from jsonb_each(coalesce(p_drops, '{}'::jsonb)) d where public.world_food_is_meat(d.key) loop
    if random() < p then out := public.world_inv_add(out, k, lo + floor(random() * (hi - lo + 1))::int); end if;
  end loop;
  return out;
end $f$;

revoke all on function public.world_food_rules() from public, anon, authenticated;

grant execute on function public.world_food_rules() to service_role, fn_owner_field;

revoke all on function public.world_food_is_meat(text) from public, anon, authenticated;

grant execute on function public.world_food_is_meat(text) to service_role, fn_owner_field;

revoke all on function public.world_food_fixed() from public, anon, authenticated;

grant execute on function public.world_food_fixed() to service_role, fn_owner_field;

revoke all on function public.world_food_meat_roll(jsonb, jsonb, text) from public, anon, authenticated;

grant execute on function public.world_food_meat_roll(jsonb, jsonb, text) to service_role, fn_owner_field;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, use_fx, crafting_specialization) values
  ('fd_potato', '감자', 'material', 1, '들과 마을 밭둑에서 캐는 감자. 굽든 조리든 배를 든든히 채운다.', true, true, 10, 50, null, 'cooking'),
  ('fd_sweet_potato', '고구마', 'material', 1, '볕 좋은 남쪽 땅에서 캐는 고구마. 찌면 달다.', true, true, 12, 50, null, 'cooking'),
  ('fd_greens', '산나물', 'material', 1, '숲 가장자리와 고갯길에서 뜯는 산나물.', true, true, 10, 50, null, 'cooking'),
  ('fd_mushroom', '버섯', 'material', 1, '그늘진 숲과 땅 밑 습한 곳에서 따는 버섯.', true, true, 15, 50, null, 'cooking'),
  ('fd_rice', '쌀', 'material', 1, '나루와 마을에서 구하는 쌀. 밥과 죽의 바탕이다.', true, true, 12, 50, null, 'cooking'),
  ('fd_minari', '미나리', 'material', 1, '늪과 물가에서 끊는 미나리. 향이 맑다.', true, true, 12, 50, null, 'cooking'),
  ('fd_garlic', '마늘', 'material', 1, '추운 북쪽 땅에서 잘 자라는 마늘. 국물 맛을 잡는다.', true, true, 12, 50, null, 'cooking'),
  ('fd_chestnut', '밤', 'material', 2, '숲과 고갯길 밤나무에서 줍는 밤.', true, true, 18, 50, null, 'cooking'),
  ('fd_buckwheat', '메밀', 'material', 2, '척박한 고개와 빙곡에서 거두는 메밀.', true, true, 20, 50, null, 'cooking'),
  ('fd_lotus_root', '연근', 'material', 2, '연못과 늪 바닥에서 캐는 연근.', true, true, 22, 50, null, 'cooking'),
  ('fd_chili', '고추', 'material', 2, '남명 땅의 매운 고추. 한 개면 국 한 솥이 맵다.', true, true, 18, 50, null, 'cooking'),
  ('fd_ginger', '생강', 'material', 2, '남쪽 땅과 바닷가에서 캐는 생강. 비린내를 잡는다.', true, true, 20, 50, null, 'cooking'),
  ('fd_jujube', '대추', 'material', 2, '적월 사막 가장자리에서 말린 대추.', true, true, 20, 50, null, 'cooking'),
  ('fd_deodeok', '더덕', 'material', 2, '높은 고개와 봉우리 바위틈에서 캐는 더덕.', true, true, 25, 50, null, 'cooking'),
  ('fd_spice_seed', '향신 씨앗', 'material', 3, '핏빛 모래바다 둘레에서 거두는 향신 씨앗. 고기 누린내를 없앤다.', true, true, 45, 50, null, 'cooking'),
  ('fd_meokbi_fern', '먹비 고사리', 'material', 4, '먹비 숲 먹물 비를 맞고 자란 고사리. 데치면 검은 물이 빠진다.', true, true, 60, 50, null, 'cooking'),
  ('fd_white_rice', '흰 밤 찹쌀', 'material', 4, '흰 밤이 걷히지 않던 옛 도읍 물가에서 거두는 찹쌀.', true, true, 70, 50, null, 'cooking'),
  ('mt_chicken', '닭고기', 'material', 1, '비금 갈래 요괴에게서 얻은 고기. 그대로 요리에 쓴다.', true, true, 15, 50, null, 'cooking'),
  ('mt_beast', '요수 생고기', 'material', 1, '거괴·파봉 갈래 요괴에게서 얻은 붉은 고기. 그대로 요리에 쓴다.', true, true, 15, 50, null, 'cooking'),
  ('mt_pheasant', '꿩고기', 'material', 2, '하늘을 나는 요괴에게서 얻은 담백한 고기. 그대로 요리에 쓴다.', true, true, 30, 50, null, 'cooking'),
  ('mt_boar', '멧돼지고기', 'material', 2, '파봉 갈래 요괴의 질긴 고기. 요기가 배어 있어 숯불에 훈연해야 먹을 수 있다.', true, true, 35, 50, null, 'cooking'),
  ('mt_crab', '독게살', 'material', 2, '갑각 갈래 요괴의 게살. 독이 있어 약초액으로 독을 빼야 한다.', true, true, 30, 50, null, 'cooking'),
  ('mt_yofish', '요괴 생선살', 'material', 1, '수귀 갈래 요괴의 살. 비린 요기가 있어 소금에 절여야 한다.', true, true, 15, 50, null, 'cooking'),
  ('dish_potato_grill', '감자 숯불구이', 'consumable', 1, '감자를 숯불에 껍질째 굽는다.', true, true, null, 50, '{"er": 0, "hp": 20, "mn": 0, "sp": 0, "stam": 0, "buffs": ["well_fed"], "cures": []}'::jsonb, 'cooking'),
  ('dish_sweet_potato', '고구마 찜', 'consumable', 1, '고구마를 김에 쪄 낸다.', true, true, null, 50, '{"er": 0, "hp": 15, "mn": 5, "sp": 0, "stam": 0, "buffs": ["well_fed"], "cures": []}'::jsonb, 'cooking'),
  ('dish_greens', '산나물 무침', 'consumable', 1, '산나물을 데쳐 마늘에 무친다.', true, true, null, 50, '{"er": 0, "hp": 0, "mn": 15, "sp": 0, "stam": 0, "buffs": ["clear_mind"], "cures": []}'::jsonb, 'cooking'),
  ('dish_mushroom_soup', '버섯국', 'consumable', 1, '버섯과 야령초로 맑게 끓인 국.', true, true, null, 50, '{"er": 0, "hp": 20, "mn": 10, "sp": 0, "stam": 0, "buffs": ["warm_belly"], "cures": []}'::jsonb, 'cooking'),
  ('dish_chicken_porridge', '닭죽', 'consumable', 1, '닭고기를 쌀과 함께 푹 쑨 죽.', true, true, null, 50, '{"er": 0, "hp": 35, "mn": 0, "sp": 0, "stam": 0, "buffs": ["well_fed"], "cures": []}'::jsonb, 'cooking'),
  ('dish_chicken_skewer', '매운 닭꼬치', 'consumable', 1, '고추 양념을 발라 숯불에 구운 닭꼬치.', true, true, null, 50, '{"er": 0, "hp": 30, "mn": 0, "sp": 0, "stam": 0, "buffs": ["vigor"], "cures": []}'::jsonb, 'cooking'),
  ('dish_beast_grill', '요수 고기 구이', 'consumable', 1, '요수 생고기를 숯불에 굽는다.', true, true, null, 50, '{"er": 0, "hp": 35, "mn": 0, "sp": 0, "stam": 0, "buffs": ["vigor"], "cures": []}'::jsonb, 'cooking'),
  ('dish_minari_pancake', '미나리 메밀전', 'consumable', 1, '메밀 반죽에 미나리를 얹어 부친다.', true, true, null, 50, '{"er": 0, "hp": 20, "mn": 10, "sp": 0, "stam": 0, "buffs": ["well_fed"], "cures": []}'::jsonb, 'cooking'),
  ('dish_potato_braise', '감자 고기 조림', 'consumable', 1, '고기와 감자를 마늘 넣고 졸인다.', true, true, null, 50, '{"er": 0, "hp": 40, "mn": 0, "sp": 0, "stam": 0, "buffs": ["warm_belly"], "cures": []}'::jsonb, 'cooking'),
  ('dish_chestnut_rice', '밤밥', 'consumable', 1, '밤을 넣고 지은 밥.', true, true, null, 50, '{"er": 0, "hp": 30, "mn": 0, "sp": 0, "stam": 0, "buffs": ["well_fed"], "cures": []}'::jsonb, 'cooking'),
  ('dish_yofish_salt', '생선살 소금구이', 'consumable', 1, '요괴 생선살을 소금에 절였다가 숯불에 굽는다.', true, true, null, 50, '{"er": 0, "hp": 35, "mn": 10, "sp": 0, "stam": 0, "buffs": ["warm_belly"], "cures": []}'::jsonb, 'cooking'),
  ('dish_lotus_braise', '연근 대추 조림', 'consumable', 1, '연근을 대추와 함께 달게 졸인다.', true, true, null, 50, '{"er": 0, "hp": 0, "mn": 20, "sp": 0, "stam": 0, "buffs": ["clear_mind"], "cures": []}'::jsonb, 'cooking'),
  ('dish_buckwheat_jelly', '메밀묵', 'consumable', 2, '메밀 앙금을 쑤어 굳힌 묵.', true, true, null, 50, '{"er": 0, "hp": 15, "mn": 15, "sp": 0, "stam": 0, "buffs": ["well_rested"], "cures": []}'::jsonb, 'cooking'),
  ('dish_pheasant_dumpling', '꿩 만둣국', 'consumable', 2, '꿩고기로 소를 넣은 메밀 만두를 끓인다.', true, true, null, 50, '{"er": 0, "hp": 50, "mn": 0, "sp": 0, "stam": 0, "buffs": ["st_meat_power"], "cures": []}'::jsonb, 'cooking'),
  ('dish_deodeok_grill', '더덕 구이', 'consumable', 2, '더덕을 두드려 고추 양념에 굽는다.', true, true, null, 50, '{"er": 0, "hp": 30, "mn": 0, "sp": 15, "stam": 0, "buffs": ["vigor"], "cures": []}'::jsonb, 'cooking'),
  ('dish_crab_porridge', '게살죽', 'consumable', 2, '약초액으로 독을 뺀 게살을 쌀과 쑨다.', true, true, null, 50, '{"er": 0, "hp": 45, "mn": 15, "sp": 0, "stam": 0, "buffs": ["warm_belly"], "cures": []}'::jsonb, 'cooking'),
  ('dish_boar_smoke', '멧돼지 훈제', 'consumable', 2, '멧돼지고기를 숯불 연기에 오래 훈연한다.', true, true, null, 50, '{"er": 0, "hp": 55, "mn": 0, "sp": 0, "stam": 0, "buffs": ["st_meat_power"], "cures": []}'::jsonb, 'cooking'),
  ('dish_root_hotpot', '뿌리 전골', 'consumable', 2, '뿌리채소와 버섯을 약제 국물에 끓인다.', true, true, null, 50, '{"er": 0, "hp": 50, "mn": 20, "sp": 0, "stam": 0, "buffs": ["st_root_warm"], "cures": []}'::jsonb, 'cooking'),
  ('dish_sweet_candy', '고구마 맛탕', 'consumable', 2, '고구마를 튀겨 대추 조청에 버무린다.', true, true, null, 50, '{"er": 0, "hp": 25, "mn": 0, "sp": 10, "stam": 0, "buffs": ["well_fed"], "cures": []}'::jsonb, 'cooking'),
  ('dish_lotus_rice', '연잎 찰밥', 'consumable', 2, '연근·대추를 넣은 밥을 연잎에 싸서 찐다.', true, true, null, 50, '{"er": 0, "hp": 45, "mn": 15, "sp": 0, "stam": 0, "buffs": ["st_grain_full"], "cures": []}'::jsonb, 'cooking'),
  ('dish_ginger_tea', '생강 대추차', 'consumable', 2, '생강과 대추를 오래 달인 차.', true, true, null, 50, '{"er": 5, "hp": 0, "mn": 20, "sp": 0, "stam": 0, "buffs": ["clear_mind"], "cures": []}'::jsonb, 'cooking'),
  ('dish_spice_skewer', '향신 고기 꼬치', 'consumable', 3, '향신 씨앗을 뿌려 구운 고기 꼬치.', true, true, null, 50, '{"er": 0, "hp": 50, "mn": 0, "sp": 10, "stam": 0, "buffs": ["st_meat_power"], "cures": []}'::jsonb, 'cooking'),
  ('dish_chicken_baeksuk', '닭 백숙', 'consumable', 3, '닭을 마늘·대추와 통째로 고아 낸다.', true, true, null, 50, '{"er": 0, "hp": 70, "mn": 20, "sp": 0, "stam": 0, "buffs": ["st_root_warm"], "cures": []}'::jsonb, 'cooking'),
  ('dish_yofish_stew', '생선살 매운 찜', 'consumable', 3, '절인 요괴 생선살을 고추 양념에 찐다.', true, true, null, 50, '{"er": 0, "hp": 60, "mn": 20, "sp": 0, "stam": 0, "buffs": ["warm_belly", "vigor"], "cures": []}'::jsonb, 'cooking'),
  ('dish_crab_rice', '게살 볶음밥', 'consumable', 3, '독을 뺀 게살과 마늘로 볶은 밥.', true, true, null, 50, '{"er": 0, "hp": 60, "mn": 0, "sp": 0, "stam": 0, "buffs": ["st_grain_full"], "cures": []}'::jsonb, 'cooking'),
  ('dish_boar_suyuk', '멧돼지 수육', 'consumable', 3, '훈연한 멧돼지고기를 생강·마늘 물에 삶는다.', true, true, null, 50, '{"er": 0, "hp": 80, "mn": 20, "sp": 0, "stam": 0, "buffs": ["st_meat_power", "warm_belly"], "cures": []}'::jsonb, 'cooking'),
  ('dish_pheasant_soup', '꿩탕', 'consumable', 4, '꿩고기와 더덕을 약제 국물에 고은 탕.', true, true, null, 50, '{"er": 0, "hp": 80, "mn": 30, "sp": 0, "stam": 0, "buffs": ["st_root_warm"], "cures": []}'::jsonb, 'cooking'),
  ('dish_mushroom_hotpot', '버섯 전골', 'consumable', 4, '버섯을 가득 넣고 끓인 전골.', true, true, null, 50, '{"er": 0, "hp": 70, "mn": 30, "sp": 20, "stam": 0, "buffs": ["st_root_warm"], "cures": []}'::jsonb, 'cooking'),
  ('dish_spice_rice', '향신 고기 덮밥', 'consumable', 4, '향신 씨앗으로 볶은 고기를 밥에 얹는다.', true, true, null, 50, '{"er": 0, "hp": 90, "mn": 0, "sp": 0, "stam": 0, "buffs": ["st_meat_power"], "cures": []}'::jsonb, 'cooking'),
  ('dish_fern_bibim', '먹비 고사리 비빔밥', 'consumable', 4, '검은 물을 뺀 먹비 고사리와 나물로 비빈 밥.', true, true, null, 50, '{"er": 0, "hp": 80, "mn": 30, "sp": 0, "stam": 0, "buffs": ["st_great_table"], "cures": []}'::jsonb, 'cooking'),
  ('dish_white_rice_cake', '흰 밤 찹쌀떡', 'consumable', 4, '흰 밤 찹쌀을 쪄서 친 떡에 대추 소를 넣는다.', true, true, null, 50, '{"er": 0, "hp": 0, "mn": 40, "sp": 30, "stam": 0, "buffs": ["st_great_table"], "cures": []}'::jsonb, 'cooking'),
  ('dish_great_table', '큰 상차림', 'consumable', 4, '훈연한 고기·꿩·찹쌀·고사리로 차린 큰상.', true, true, null, 50, '{"er": 0, "hp": 100, "mn": 40, "sp": 40, "stam": 0, "buffs": ["st_great_table"], "cures": []}'::jsonb, 'cooking'),
  ('sp_night_office_1', '야시장 장국수', 'consumable', 2, '닭 육수에 메밀 국수를 만 백등 야시장 국수. 백등 야시장에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 40, "mn": 15, "sp": 0, "stam": 0, "buffs": ["fs_night_office"], "cures": []}'::jsonb, 'cooking'),
  ('sp_night_office_2', '궁중 신선로', 'consumable', 4, '정청 잔칫날에만 내는 신선로. 백등 야시장에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 80, "mn": 30, "sp": 20, "stam": 0, "buffs": ["fs_night_office"], "cures": []}'::jsonb, 'cooking'),
  ('sp_red_moon_cult_1', '대추 향신 꼬치', 'consumable', 2, '백골 장터 노점의 대추 양념 고기 꼬치. 백골 장터에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 40, "mn": 15, "sp": 0, "stam": 0, "buffs": ["fs_red_moon_cult"], "cures": []}'::jsonb, 'cooking'),
  ('sp_red_moon_cult_2', '화덕 통고기', 'consumable', 4, '사막 화덕에 통째로 구운 고기. 백골 장터에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 80, "mn": 30, "sp": 20, "stam": 0, "buffs": ["fs_red_moon_cult"], "cures": []}'::jsonb, 'cooking'),
  ('sp_black_lotus_1', '뒷골목 떡꼬치', 'consumable', 2, '십삼문 골목에서 파는 매운 떡꼬치. 십삼문 암시장에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 40, "mn": 15, "sp": 0, "stam": 0, "buffs": ["fs_black_lotus"], "cures": []}'::jsonb, 'cooking'),
  ('sp_black_lotus_2', '먹물 만두', 'consumable', 4, '먹물로 반죽을 물들인 흑련회 만두. 십삼문 암시장에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 80, "mn": 30, "sp": 20, "stam": 0, "buffs": ["fs_black_lotus"], "cures": []}'::jsonb, 'cooking'),
  ('sp_north_league_1', '메밀 고깃국', 'consumable', 2, '설원 사람들이 아침마다 끓이는 메밀 고깃국. 철벽 고찰에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 40, "mn": 15, "sp": 0, "stam": 0, "buffs": ["fs_north_league"], "cures": []}'::jsonb, 'cooking'),
  ('sp_north_league_2', '언 고기 수육', 'consumable', 4, '눈 속에 얼려 둔 고기를 삶아 낸 북령 수육. 철벽 고찰에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 80, "mn": 30, "sp": 20, "stam": 0, "buffs": ["fs_north_league"], "cures": []}'::jsonb, 'cooking'),
  ('sp_river_alliance_1', '연근 생선 정식', 'consumable', 2, '구름나루 뱃사람들의 한 상. 구름나루에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 40, "mn": 15, "sp": 0, "stam": 0, "buffs": ["fs_river_alliance"], "cures": []}'::jsonb, 'cooking'),
  ('sp_river_alliance_2', '연잎 생선찜', 'consumable', 4, '생선을 연잎에 싸서 찐 수향 잔칫상. 구름나루에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 80, "mn": 30, "sp": 20, "stam": 0, "buffs": ["fs_river_alliance"], "cures": []}'::jsonb, 'cooking'),
  ('sp_southern_remnant_1', '잔불 고추 찌개', 'consumable', 2, '잔불촌 화로에서 끓는 고추 찌개. 잔불촌에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 40, "mn": 15, "sp": 0, "stam": 0, "buffs": ["fs_southern_remnant"], "cures": []}'::jsonb, 'cooking'),
  ('sp_southern_remnant_2', '화산 매운 고기구이', 'consumable', 4, '화산 돌판에 구운 남명 고기구이. 잔불촌에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 80, "mn": 30, "sp": 20, "stam": 0, "buffs": ["fs_southern_remnant"], "cures": []}'::jsonb, 'cooking'),
  ('sp_mandate_court_1', '관성 대추 다과', 'consumable', 2, '별을 보며 곁들이는 대추·밤 다과. 무극 관성대에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 40, "mn": 15, "sp": 0, "stam": 0, "buffs": ["fs_mandate_court"], "cures": []}'::jsonb, 'cooking'),
  ('sp_mandate_court_2', '별빛 약선죽', 'consumable', 4, '천명원 관측관들이 밤샘 뒤 먹는 약선죽. 무극 관성대에서 늘 판다.', true, true, null, 50, '{"er": 0, "hp": 80, "mn": 30, "sp": 20, "stam": 0, "buffs": ["fs_mandate_court"], "cures": []}'::jsonb, 'cooking');

insert into public.world_status_catalog(status_key, status_name, polarity, description, duration_minutes, effects, max_stacks, active, icon, cure) values
  ('st_meat_power', '고기 힘', 'positive', '든든한 고기 덕에 팔에 힘이 붙습니다.', 60, '{"combat_damage_pct": 6, "incoming_damage_pct": -4}'::jsonb, 1, true, 'spark', '시간이 지나면 사라집니다.'),
  ('st_root_warm', '뿌리 온기', 'positive', '뿌리채소의 온기가 몸속까지 퍼집니다.', 60, '{"healing_pct": 8, "erosion_pct": -8}'::jsonb, 1, true, 'leaf', '시간이 지나면 사라집니다.'),
  ('st_grain_full', '곡기 든든', 'positive', '곡기가 배에 차 발걸음이 가볍습니다.', 60, '{"gather_qty_pct": 8, "travel_time_pct": -5}'::jsonb, 1, true, 'leaf', '시간이 지나면 사라집니다.'),
  ('st_great_table', '큰상 기운', 'positive', '잘 차린 큰상을 비워 온몸에 기운이 돕니다.', 120, '{"combat_damage_pct": 6, "incoming_damage_pct": -5, "healing_pct": 8}'::jsonb, 1, true, 'flame', '시간이 지나면 사라집니다.'),
  ('fs_night_office', '궁중 상의 격식', 'positive', '격식 있는 상을 받고 나니 손끝이 차분합니다.', 90, '{"craft_quality": 6, "clue_bonus_pct": 8}'::jsonb, 1, true, 'spark', '시간이 지나면 사라집니다.'),
  ('fs_red_moon_cult', '사막 화덕', 'positive', '화덕 불맛이 속을 덥혀 흔들리지 않습니다.', 90, '{"combat_damage_pct": 6, "mental_loss_pct": -8}'::jsonb, 1, true, 'flame', '시간이 지나면 사라집니다.'),
  ('fs_black_lotus', '뒷골목 입맛', 'positive', '뒷골목 맛을 알고 나니 눈치가 밝아집니다.', 90, '{"rare_loot_pct": 5, "encounter_pct": -8}'::jsonb, 1, true, 'eye', '시간이 지나면 사라집니다.'),
  ('fs_north_league', '설원 버팀', 'positive', '설원 사람들의 밥심으로 버팁니다.', 90, '{"incoming_damage_pct": -8, "erosion_pct": -8}'::jsonb, 1, true, 'shield', '시간이 지나면 사라집니다.'),
  ('fs_river_alliance', '물길 순풍', 'positive', '물길 사람들의 밥상을 받아 걸음과 손이 가볍습니다.', 90, '{"travel_time_pct": -8, "fish_bite_pct": 8}'::jsonb, 1, true, 'leaf', '시간이 지나면 사라집니다.'),
  ('fs_southern_remnant', '잔불 기세', 'positive', '매운 불맛이 기세를 끌어올립니다.', 90, '{"combat_damage_pct": 8}'::jsonb, 1, true, 'flame', '시간이 지나면 사라집니다.'),
  ('fs_mandate_court', '별빛 맑음', 'positive', '별빛 아래 차린 약선이 정신을 맑게 합니다.', 90, '{"mental_loss_pct": -10, "clue_bonus_pct": 8}'::jsonb, 1, true, 'spark', '시간이 지나면 사라집니다.');

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field) values
  ('r_dish_potato_grill', '감자 숯불구이 만들기', 'dish_potato_grill', 3, '{"fd_potato": 2, "charcoal": 1}'::jsonb, null, 1, null, '감자를 숯불에 껍질째 굽는다.', 1, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_sweet_potato', '고구마 찜 만들기', 'dish_sweet_potato', 2, '{"fd_sweet_potato": 2}'::jsonb, null, 1, null, '고구마를 김에 쪄 낸다.', 1, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_greens', '산나물 무침 만들기', 'dish_greens', 2, '{"fd_greens": 2, "fd_garlic": 1}'::jsonb, null, 1, null, '산나물을 데쳐 마늘에 무친다.', 2, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_mushroom_soup', '버섯국 만들기', 'dish_mushroom_soup', 2, '{"fd_mushroom": 2, "herb": 1}'::jsonb, null, 1, null, '버섯과 야령초로 맑게 끓인 국.', 3, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_chicken_porridge', '닭죽 만들기', 'dish_chicken_porridge', 2, '{"mt_chicken": 1, "fd_rice": 1}'::jsonb, null, 1, null, '닭고기를 쌀과 함께 푹 쑨 죽.', 3, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_chicken_skewer', '매운 닭꼬치 만들기', 'dish_chicken_skewer', 2, '{"mt_chicken": 1, "fd_chili": 1, "charcoal": 1}'::jsonb, null, 1, null, '고추 양념을 발라 숯불에 구운 닭꼬치.', 4, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_beast_grill', '요수 고기 구이 만들기', 'dish_beast_grill', 2, '{"mt_beast": 1, "charcoal": 1}'::jsonb, null, 1, null, '요수 생고기를 숯불에 굽는다.', 5, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_minari_pancake', '미나리 메밀전 만들기', 'dish_minari_pancake', 2, '{"fd_minari": 2, "fd_buckwheat": 1}'::jsonb, null, 1, null, '메밀 반죽에 미나리를 얹어 부친다.', 5, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_potato_braise', '감자 고기 조림 만들기', 'dish_potato_braise', 2, '{"mt_beast": 1, "fd_potato": 1, "fd_garlic": 1}'::jsonb, null, 1, null, '고기와 감자를 마늘 넣고 졸인다.', 7, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_chestnut_rice', '밤밥 만들기', 'dish_chestnut_rice', 3, '{"fd_chestnut": 1, "fd_rice": 1}'::jsonb, null, 1, null, '밤을 넣고 지은 밥.', 8, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_yofish_salt', '생선살 소금구이 만들기', 'dish_yofish_salt', 2, '{"mt_yofish": 1, "frost_salt": 1, "charcoal": 1}'::jsonb, null, 1, null, '요괴 생선살을 소금에 절였다가 숯불에 굽는다.', 8, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_lotus_braise', '연근 대추 조림 만들기', 'dish_lotus_braise', 2, '{"fd_lotus_root": 1, "fd_jujube": 1}'::jsonb, null, 1, null, '연근을 대추와 함께 달게 졸인다.', 9, null, 1, 0, null, 1, 'cooking'),
  ('r_dish_buckwheat_jelly', '메밀묵 만들기', 'dish_buckwheat_jelly', 3, '{"fd_buckwheat": 2}'::jsonb, null, 1, null, '메밀 앙금을 쑤어 굳힌 묵.', 10, null, 2, 0, null, 1, 'cooking'),
  ('r_dish_pheasant_dumpling', '꿩 만둣국 만들기', 'dish_pheasant_dumpling', 2, '{"mt_pheasant": 1, "fd_buckwheat": 1, "fd_garlic": 1}'::jsonb, null, 1, null, '꿩고기로 소를 넣은 메밀 만두를 끓인다.', 12, null, 2, 0, null, 1, 'cooking'),
  ('r_dish_deodeok_grill', '더덕 구이 만들기', 'dish_deodeok_grill', 2, '{"fd_deodeok": 1, "fd_chili": 1, "charcoal": 1}'::jsonb, null, 1, null, '더덕을 두드려 고추 양념에 굽는다.', 12, null, 2, 0, null, 1, 'cooking'),
  ('r_dish_crab_porridge', '게살죽 만들기', 'dish_crab_porridge', 2, '{"mt_crab": 1, "herbal_extract": 1, "fd_rice": 1}'::jsonb, null, 1, null, '약초액으로 독을 뺀 게살을 쌀과 쑨다.', 14, null, 2, 0, null, 1, 'cooking'),
  ('r_dish_boar_smoke', '멧돼지 훈제 만들기', 'dish_boar_smoke', 2, '{"mt_boar": 1, "charcoal": 2}'::jsonb, null, 1, null, '멧돼지고기를 숯불 연기에 오래 훈연한다.', 15, null, 2, 0, null, 1, 'cooking'),
  ('r_dish_root_hotpot', '뿌리 전골 만들기', 'dish_root_hotpot', 2, '{"fd_potato": 1, "fd_deodeok": 1, "fd_mushroom": 1, "medicine_base": 1}'::jsonb, null, 1, null, '뿌리채소와 버섯을 약제 국물에 끓인다.', 15, null, 2, 0, null, 1, 'cooking'),
  ('r_dish_sweet_candy', '고구마 맛탕 만들기', 'dish_sweet_candy', 3, '{"fd_sweet_potato": 2, "fd_jujube": 1}'::jsonb, null, 1, null, '고구마를 튀겨 대추 조청에 버무린다.', 16, null, 2, 0, null, 1, 'cooking'),
  ('r_dish_lotus_rice', '연잎 찰밥 만들기', 'dish_lotus_rice', 2, '{"fd_lotus_root": 1, "fd_rice": 2, "fd_jujube": 1}'::jsonb, null, 1, null, '연근·대추를 넣은 밥을 연잎에 싸서 찐다.', 18, null, 2, 0, null, 1, 'cooking'),
  ('r_dish_ginger_tea', '생강 대추차 만들기', 'dish_ginger_tea', 3, '{"fd_ginger": 1, "fd_jujube": 1}'::jsonb, null, 1, null, '생강과 대추를 오래 달인 차.', 18, null, 2, 0, null, 1, 'cooking'),
  ('r_dish_spice_skewer', '향신 고기 꼬치 만들기', 'dish_spice_skewer', 2, '{"mt_beast": 1, "fd_spice_seed": 1, "charcoal": 1}'::jsonb, null, 1, null, '향신 씨앗을 뿌려 구운 고기 꼬치.', 20, null, 3, 0, null, 1, 'cooking'),
  ('r_dish_chicken_baeksuk', '닭 백숙 만들기', 'dish_chicken_baeksuk', 2, '{"mt_chicken": 2, "fd_garlic": 1, "fd_jujube": 1, "medicine_base": 1}'::jsonb, null, 1, null, '닭을 마늘·대추와 통째로 고아 낸다.', 22, null, 3, 0, null, 1, 'cooking'),
  ('r_dish_yofish_stew', '생선살 매운 찜 만들기', 'dish_yofish_stew', 2, '{"mt_yofish": 2, "frost_salt": 1, "fd_chili": 1}'::jsonb, null, 1, null, '절인 요괴 생선살을 고추 양념에 찐다.', 24, null, 3, 0, null, 1, 'cooking'),
  ('r_dish_crab_rice', '게살 볶음밥 만들기', 'dish_crab_rice', 2, '{"mt_crab": 1, "herbal_extract": 1, "fd_rice": 1, "fd_garlic": 1}'::jsonb, null, 1, null, '독을 뺀 게살과 마늘로 볶은 밥.', 26, null, 3, 0, null, 1, 'cooking'),
  ('r_dish_boar_suyuk', '멧돼지 수육 만들기', 'dish_boar_suyuk', 2, '{"mt_boar": 2, "charcoal": 1, "fd_garlic": 1, "fd_ginger": 1}'::jsonb, null, 1, null, '훈연한 멧돼지고기를 생강·마늘 물에 삶는다.', 28, null, 3, 0, null, 1, 'cooking'),
  ('r_dish_pheasant_soup', '꿩탕 만들기', 'dish_pheasant_soup', 2, '{"mt_pheasant": 2, "fd_deodeok": 1, "medicine_base": 1}'::jsonb, null, 1, null, '꿩고기와 더덕을 약제 국물에 고은 탕.', 30, null, 4, 0, null, 1, 'cooking'),
  ('r_dish_mushroom_hotpot', '버섯 전골 만들기', 'dish_mushroom_hotpot', 2, '{"fd_mushroom": 3, "fd_greens": 1, "medicine_base": 1}'::jsonb, null, 1, null, '버섯을 가득 넣고 끓인 전골.', 32, null, 4, 0, null, 1, 'cooking'),
  ('r_dish_spice_rice', '향신 고기 덮밥 만들기', 'dish_spice_rice', 2, '{"mt_beast": 2, "fd_spice_seed": 1, "fd_rice": 1}'::jsonb, null, 1, null, '향신 씨앗으로 볶은 고기를 밥에 얹는다.', 35, null, 4, 0, null, 1, 'cooking'),
  ('r_dish_fern_bibim', '먹비 고사리 비빔밥 만들기', 'dish_fern_bibim', 2, '{"fd_meokbi_fern": 2, "fd_rice": 1, "fd_greens": 1}'::jsonb, null, 1, null, '검은 물을 뺀 먹비 고사리와 나물로 비빈 밥.', 42, null, 5, 0, null, 1, 'cooking'),
  ('r_dish_white_rice_cake', '흰 밤 찹쌀떡 만들기', 'dish_white_rice_cake', 3, '{"fd_white_rice": 2, "fd_jujube": 1}'::jsonb, null, 1, null, '흰 밤 찹쌀을 쪄서 친 떡에 대추 소를 넣는다.', 46, null, 5, 0, null, 1, 'cooking'),
  ('r_dish_great_table', '큰 상차림 만들기', 'dish_great_table', 2, '{"mt_boar": 1, "charcoal": 1, "mt_pheasant": 1, "fd_white_rice": 1, "fd_meokbi_fern": 1, "medicine_base": 1}'::jsonb, null, 1, null, '훈연한 고기·꿩·찹쌀·고사리로 차린 큰상.', 48, null, 5, 0, null, 1, 'cooking'),
  ('r_sp_night_office_1', '야시장 장국수 만들기', 'sp_night_office_1', 2, '{"fd_buckwheat": 1, "mt_chicken": 1, "fd_garlic": 1}'::jsonb, null, 1, '백등 야시장', '닭 육수에 메밀 국수를 만 백등 야시장 국수. 백등 야시장에서 만들면 솜씨가 더 난다.', 10, null, 2, 0, null, 1, 'cooking'),
  ('r_sp_night_office_2', '궁중 신선로 만들기', 'sp_night_office_2', 2, '{"mt_beast": 1, "fd_mushroom": 1, "fd_lotus_root": 1, "fd_jujube": 1, "medicine_base": 1}'::jsonb, null, 1, '백등 야시장', '정청 잔칫날에만 내는 신선로. 백등 야시장에서 만들면 솜씨가 더 난다.', 30, null, 4, 0, null, 1, 'cooking'),
  ('r_sp_red_moon_cult_1', '대추 향신 꼬치 만들기', 'sp_red_moon_cult_1', 2, '{"mt_beast": 1, "fd_jujube": 1, "fd_chili": 1}'::jsonb, null, 1, '백골 장터', '백골 장터 노점의 대추 양념 고기 꼬치. 백골 장터에서 만들면 솜씨가 더 난다.', 10, null, 2, 0, null, 1, 'cooking'),
  ('r_sp_red_moon_cult_2', '화덕 통고기 만들기', 'sp_red_moon_cult_2', 2, '{"mt_beast": 2, "fd_spice_seed": 1, "charcoal": 1}'::jsonb, null, 1, '백골 장터', '사막 화덕에 통째로 구운 고기. 백골 장터에서 만들면 솜씨가 더 난다.', 30, null, 4, 0, null, 1, 'cooking'),
  ('r_sp_black_lotus_1', '뒷골목 떡꼬치 만들기', 'sp_black_lotus_1', 2, '{"fd_rice": 2, "fd_chili": 1}'::jsonb, null, 1, '십삼문 암시장', '십삼문 골목에서 파는 매운 떡꼬치. 십삼문 암시장에서 만들면 솜씨가 더 난다.', 10, null, 2, 0, null, 1, 'cooking'),
  ('r_sp_black_lotus_2', '먹물 만두 만들기', 'sp_black_lotus_2', 2, '{"fd_buckwheat": 1, "mt_beast": 1, "fd_mushroom": 1, "fd_garlic": 1}'::jsonb, null, 1, '십삼문 암시장', '먹물로 반죽을 물들인 흑련회 만두. 십삼문 암시장에서 만들면 솜씨가 더 난다.', 30, null, 4, 0, null, 1, 'cooking'),
  ('r_sp_north_league_1', '메밀 고깃국 만들기', 'sp_north_league_1', 2, '{"fd_buckwheat": 1, "mt_beast": 1, "fd_garlic": 1}'::jsonb, null, 1, '철벽 고찰', '설원 사람들이 아침마다 끓이는 메밀 고깃국. 철벽 고찰에서 만들면 솜씨가 더 난다.', 10, null, 2, 0, null, 1, 'cooking'),
  ('r_sp_north_league_2', '언 고기 수육 만들기', 'sp_north_league_2', 2, '{"mt_boar": 2, "charcoal": 1, "fd_garlic": 1, "frost_salt": 1}'::jsonb, null, 1, '철벽 고찰', '눈 속에 얼려 둔 고기를 삶아 낸 북령 수육. 철벽 고찰에서 만들면 솜씨가 더 난다.', 30, null, 4, 0, null, 1, 'cooking'),
  ('r_sp_river_alliance_1', '연근 생선 정식 만들기', 'sp_river_alliance_1', 2, '{"fd_lotus_root": 1, "fd_rice": 1, "fish_fillet": 1}'::jsonb, null, 1, '구름나루', '구름나루 뱃사람들의 한 상. 구름나루에서 만들면 솜씨가 더 난다.', 10, null, 2, 0, null, 1, 'cooking'),
  ('r_sp_river_alliance_2', '연잎 생선찜 만들기', 'sp_river_alliance_2', 2, '{"fish_fillet": 2, "fd_lotus_root": 1, "fd_minari": 1, "fd_ginger": 1}'::jsonb, null, 1, '구름나루', '생선을 연잎에 싸서 찐 수향 잔칫상. 구름나루에서 만들면 솜씨가 더 난다.', 30, null, 4, 0, null, 1, 'cooking'),
  ('r_sp_southern_remnant_1', '잔불 고추 찌개 만들기', 'sp_southern_remnant_1', 2, '{"fd_chili": 2, "fd_potato": 1, "mt_beast": 1}'::jsonb, null, 1, '잔불촌', '잔불촌 화로에서 끓는 고추 찌개. 잔불촌에서 만들면 솜씨가 더 난다.', 10, null, 2, 0, null, 1, 'cooking'),
  ('r_sp_southern_remnant_2', '화산 매운 고기구이 만들기', 'sp_southern_remnant_2', 2, '{"mt_boar": 1, "fd_chili": 2, "fd_ginger": 1, "charcoal": 2}'::jsonb, null, 1, '잔불촌', '화산 돌판에 구운 남명 고기구이. 잔불촌에서 만들면 솜씨가 더 난다.', 30, null, 4, 0, null, 1, 'cooking'),
  ('r_sp_mandate_court_1', '관성 대추 다과 만들기', 'sp_mandate_court_1', 2, '{"fd_jujube": 2, "fd_chestnut": 1}'::jsonb, null, 1, '무극 관성대', '별을 보며 곁들이는 대추·밤 다과. 무극 관성대에서 만들면 솜씨가 더 난다.', 10, null, 2, 0, null, 1, 'cooking'),
  ('r_sp_mandate_court_2', '별빛 약선죽 만들기', 'sp_mandate_court_2', 2, '{"fd_rice": 1, "fd_jujube": 1, "fd_deodeok": 1, "medicine_base": 1}'::jsonb, null, 1, '무극 관성대', '천명원 관측관들이 밤샘 뒤 먹는 약선죽. 무극 관성대에서 만들면 솜씨가 더 난다.', 30, null, 4, 0, null, 1, 'cooking');

update public.world_crafting_recipes set ingredients = (ingredients - array['travel_ration']::text[]) || '{"fd_rice": 1, "fd_greens": 1, "herb": 1}'::jsonb where recipe_id = 'cook_herb_rice' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_chili": 1}'::jsonb where recipe_id = 'cook_spicy_stew' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_chili": 1}'::jsonb where recipe_id = 'stew_lenok' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_chili": 1}'::jsonb where recipe_id = 'cook_rockfish_stew' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_chili": 1}'::jsonb where recipe_id = 'r_paperboat_spicy_stew' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"herb": 1, "fd_ginger": 1}'::jsonb where recipe_id = 'cook_herb_fish' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"herb": 1, "fd_garlic": 1}'::jsonb where recipe_id = 'cook_catfish' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_jujube": 1}'::jsonb where recipe_id = 'cook_carp_broth' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_ginger": 1}'::jsonb where recipe_id = 'cook_eel_tonic' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_ginger": 1}'::jsonb where recipe_id = 'tonic_swamp_eel' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_garlic": 1}'::jsonb where recipe_id = 'cook_snakehead' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - array['herb']::text[]) || '{"fd_potato": 1, "fd_chili": 1}'::jsonb where recipe_id = 'cook_hairtail' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - array['herb']::text[]) || '{"fd_garlic": 1}'::jsonb where recipe_id = 'cook_cod_soup' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - array['herb']::text[]) || '{"fd_minari": 1}'::jsonb where recipe_id = 'cook_croaker_soup' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - array['travel_ration']::text[]) || '{"fd_rice": 1}'::jsonb where recipe_id = 'cook_moss_porridge' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_rice": 1}'::jsonb where recipe_id = 'r_crucian_reed_porridge' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - array['herb']::text[]) || '{"fd_chili": 1}'::jsonb where recipe_id = 'r_goby_braise' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"herb": 1, "fd_ginger": 1}'::jsonb where recipe_id = 'r_mist_crucian_steam' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_ginger": 1}'::jsonb where recipe_id = 'cook_grouper_steam' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"fd_jujube": 1}'::jsonb where recipe_id = 'cook_bark_stew' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - array['herb']::text[]) || '{"fd_buckwheat": 1}'::jsonb where recipe_id = 'r_minnow_fritter' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - array['river_reed']::text[]) || '{"fd_minari": 1}'::jsonb where recipe_id = 'r_smelt_clear_soup' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"herb": 1, "fd_lotus_root": 1}'::jsonb where recipe_id = 'r_cheong_carp_steam' and craft_field = 'cooking';

update public.world_crafting_recipes set ingredients = (ingredients - '{}'::text[]) || '{"herb": 1, "fd_lotus_root": 1}'::jsonb where recipe_id = 'r_goldcarp_feast' and craft_field = 'cooking';

do $c$ begin if (select count(*) from public.world_crafting_recipes where recipe_id = any(array['cook_herb_rice','cook_spicy_stew','stew_lenok','cook_rockfish_stew','r_paperboat_spicy_stew','cook_herb_fish','cook_catfish','cook_carp_broth','cook_eel_tonic','tonic_swamp_eel','cook_snakehead','cook_hairtail','cook_cod_soup','cook_croaker_soup','cook_moss_porridge','r_crucian_reed_porridge','r_goby_braise','r_mist_crucian_steam','cook_grouper_steam','cook_bark_stew','r_minnow_fritter','r_smelt_clear_soup','r_cheong_carp_steam','r_goldcarp_feast']::text[])) <> 24 then raise exception '고칠 요리 제작법이 다 있지 않음'; end if; end $c$;

with cost as (
  select r.output_item, min(ceil((select sum(e.value::numeric * coalesce(i.reference_price, 0)) from jsonb_each_text(r.ingredients) e join public.world_item_catalog i on i.item_id = e.key) / r.output_qty * 1.1)) v
  from public.world_crafting_recipes r where r.output_item = any(array['dish_potato_grill','dish_sweet_potato','dish_greens','dish_mushroom_soup','dish_chicken_porridge','dish_chicken_skewer','dish_beast_grill','dish_minari_pancake','dish_potato_braise','dish_chestnut_rice','dish_yofish_salt','dish_lotus_braise','dish_buckwheat_jelly','dish_pheasant_dumpling','dish_deodeok_grill','dish_crab_porridge','dish_boar_smoke','dish_root_hotpot','dish_sweet_candy','dish_lotus_rice','dish_ginger_tea','dish_spice_skewer','dish_chicken_baeksuk','dish_yofish_stew','dish_crab_rice','dish_boar_suyuk','dish_pheasant_soup','dish_mushroom_hotpot','dish_spice_rice','dish_fern_bibim','dish_white_rice_cake','dish_great_table','sp_night_office_1','sp_night_office_2','sp_red_moon_cult_1','sp_red_moon_cult_2','sp_black_lotus_1','sp_black_lotus_2','sp_north_league_1','sp_north_league_2','sp_river_alliance_1','sp_river_alliance_2','sp_southern_remnant_1','sp_southern_remnant_2','sp_mandate_court_1','sp_mandate_court_2']::text[]) or r.output_item in (select output_item from public.world_crafting_recipes where recipe_id = any(array['cook_herb_rice','cook_spicy_stew','stew_lenok','cook_rockfish_stew','r_paperboat_spicy_stew','cook_herb_fish','cook_catfish','cook_carp_broth','cook_eel_tonic','tonic_swamp_eel','cook_snakehead','cook_hairtail','cook_cod_soup','cook_croaker_soup','cook_moss_porridge','r_crucian_reed_porridge','r_goby_braise','r_mist_crucian_steam','cook_grouper_steam','cook_bark_stew','r_minnow_fritter','r_smelt_clear_soup','r_cheong_carp_steam','r_goldcarp_feast']::text[])) group by r.output_item)
update public.world_item_catalog c set reference_price = greatest(coalesce(c.reference_price, 0), cost.v) from cost where c.item_id = cost.output_item;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, use_fx, crafting_specialization, base_item_id, quality_grade)
select c.item_id || '_hq', c.item_name || ' (우수)', c.category, c.tier, c.description || ' ' || public.world_item_hq_note(c.item_id, c.category), true, c.tradeable, ceil(c.reference_price * 1.3), c.stack_size, null, c.crafting_specialization, c.item_id, 1
from public.world_item_catalog c where c.item_id = any(array['dish_potato_grill','dish_sweet_potato','dish_greens','dish_mushroom_soup','dish_chicken_porridge','dish_chicken_skewer','dish_beast_grill','dish_minari_pancake','dish_potato_braise','dish_chestnut_rice','dish_yofish_salt','dish_lotus_braise','dish_buckwheat_jelly','dish_pheasant_dumpling','dish_deodeok_grill','dish_crab_porridge','dish_boar_smoke','dish_root_hotpot','dish_sweet_candy','dish_lotus_rice','dish_ginger_tea','dish_spice_skewer','dish_chicken_baeksuk','dish_yofish_stew','dish_crab_rice','dish_boar_suyuk','dish_pheasant_soup','dish_mushroom_hotpot','dish_spice_rice','dish_fern_bibim','dish_white_rice_cake','dish_great_table','sp_night_office_1','sp_night_office_2','sp_red_moon_cult_1','sp_red_moon_cult_2','sp_black_lotus_1','sp_black_lotus_2','sp_north_league_1','sp_north_league_2','sp_river_alliance_1','sp_river_alliance_2','sp_southern_remnant_1','sp_southern_remnant_2','sp_mandate_court_1','sp_mandate_court_2']::text[]);

create temp table yh_fg(item text, cats text[], types text[], facs text[], regs text[], minlv int) on commit drop;

insert into yh_fg values
  ('fd_potato', array['herbs','wood']::text[], array['wilderness','village','forest','haunted_garden','mountain_pass','market','headquarters','safe_zone','training']::text[], '{}'::text[], '{}'::text[], 1),
  ('fd_sweet_potato', array['herbs']::text[], array['coast']::text[], array['southern_remnant','river_alliance']::text[], '{}'::text[], 1),
  ('fd_greens', array['herbs']::text[], array['forest','mountain_pass','haunted_garden','sealed_shrine','ruined_temple','wilderness']::text[], '{}'::text[], '{}'::text[], 1),
  ('fd_mushroom', array['wood','herbs']::text[], array['forest','underground','swamp','burial_ground','blood_forest','archive']::text[], '{}'::text[], '{}'::text[], 1),
  ('fd_rice', array['supplies']::text[], array['village','river_port','coast','market','headquarters','safe_zone','bridge']::text[], array['river_alliance']::text[], '{}'::text[], 1),
  ('fd_minari', array['water']::text[], array['swamp','lake','river_port','village','pavilion','coast']::text[], '{}'::text[], '{}'::text[], 1),
  ('fd_garlic', array['herbs','supplies']::text[], array['ice_valley']::text[], array['north_league']::text[], '{}'::text[], 1),
  ('fd_chestnut', array['wood']::text[], array['forest','mountain_pass','wilderness','mountain_peak']::text[], '{}'::text[], '{}'::text[], 5),
  ('fd_buckwheat', array['supplies']::text[], array['mountain_pass','ice_valley','mountain_peak','monastery']::text[], '{}'::text[], '{}'::text[], 5),
  ('fd_lotus_root', array['water']::text[], array['swamp','pavilion','lake']::text[], '{}'::text[], '{}'::text[], 7),
  ('fd_chili', array['herbs']::text[], '{}'::text[], array['southern_remnant']::text[], '{}'::text[], 1),
  ('fd_ginger', array['herbs']::text[], array['coast','islands']::text[], array['southern_remnant']::text[], '{}'::text[], 5),
  ('fd_jujube', array['wood','herbs']::text[], array['desert','canyon']::text[], array['red_moon_cult']::text[], '{}'::text[], 1),
  ('fd_deodeok', array['herbs']::text[], array['mountain_pass','mountain_peak','canyon']::text[], '{}'::text[], '{}'::text[], 8),
  ('fd_spice_seed', array['herbs','spirit']::text[], '{}'::text[], '{}'::text[], array['blood_dunes','crimson_altar','red_moon_fort']::text[], 15),
  ('fd_meokbi_fern', array['herbs']::text[], '{}'::text[], '{}'::text[], array['meokbi_forest','blank_field']::text[], 40),
  ('fd_white_rice', array['water','herbs','supplies']::text[], '{}'::text[], '{}'::text[], array['old_ferry_market','dark_yamen','red_shrine_lane']::text[], 45);

with cand as (
  select s.spot_id, g.item from public.world_gathering_spots s
  join public.world_exploration_nodes n on n.node_id = s.node_id
  join public.world_map_regions r on r.region_id = n.region_id
  join yh_fg g on s.category = any(g.cats) and r.min_level >= g.minlv
    and (r.region_type = any(g.types) or r.home_faction_id = any(g.facs) or r.region_id = any(g.regs))
  where not (s.loot_items && (select array_agg(item) from yh_fg))),
pick as (select distinct on (spot_id) spot_id, item from cand order by spot_id, md5(spot_id::text || item))
update public.world_gathering_spots s set loot_items = s.loot_items || array[p.item] from pick p where s.spot_id = p.spot_id;

do $c$ declare x text; begin for x in select item from yh_fg loop if not exists (select 1 from public.world_gathering_spots where x = any(loot_items)) then raise exception '채집터에 안 들어간 식재료 %', x; end if; end loop; end $c$;

update public.world_region_monsters set drops = coalesce(drops, '{}'::jsonb) || jsonb_build_object('mt_chicken', 1) where kind = any(array['bird']::text[]) and min_level <= 14;

update public.world_region_monsters set drops = coalesce(drops, '{}'::jsonb) || jsonb_build_object('mt_pheasant', 1) where kind = any(array['bird']::text[]) and min_level >= 15;

update public.world_region_monsters set drops = coalesce(drops, '{}'::jsonb) || jsonb_build_object('mt_pheasant', 1) where kind = any(array['sky']::text[]);

update public.world_region_monsters set drops = coalesce(drops, '{}'::jsonb) || jsonb_build_object('mt_beast', 1) where kind = any(array['giant']::text[]);

update public.world_region_monsters set drops = coalesce(drops, '{}'::jsonb) || jsonb_build_object('mt_beast', 1) where kind = any(array['breaker']::text[]) and min_level <= 9;

update public.world_region_monsters set drops = coalesce(drops, '{}'::jsonb) || jsonb_build_object('mt_boar', 1) where kind = any(array['breaker']::text[]) and min_level >= 10;

update public.world_region_monsters set drops = coalesce(drops, '{}'::jsonb) || jsonb_build_object('mt_crab', 1) where kind = any(array['shell']::text[]);

update public.world_region_monsters set drops = coalesce(drops, '{}'::jsonb) || jsonb_build_object('mt_yofish', 1) where kind = any(array['water']::text[]);

do $c$ declare x text; begin for x in select jsonb_array_elements_text(public.world_food_rules() -> 'meats') loop if not exists (select 1 from public.world_region_monsters where drops ? x) then raise exception '떨어뜨리는 요괴가 없는 고기 %', x; end if; end loop; end $c$;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap) values
  ('capital_market', 'fd_rice', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_rice') * 1.3), 1, 1, null),
  ('capital_market', 'fd_greens', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_greens') * 1.3), 1, 1, null),
  ('capital_market', 'fd_potato', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_potato') * 1.3), 1, 1, null),
  ('capital_market', 'mt_chicken', ceil((select reference_price from public.world_item_catalog where item_id = 'mt_chicken') * 1.3), 1, 1, null),
  ('frontier_market', 'fd_jujube', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_jujube') * 1.3), 1, 1, null),
  ('frontier_market', 'fd_spice_seed', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_spice_seed') * 1.3), 1, 1, null),
  ('frontier_market', 'mt_beast', ceil((select reference_price from public.world_item_catalog where item_id = 'mt_beast') * 1.3), 1, 1, null),
  ('underworld_market', 'fd_mushroom', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_mushroom') * 1.3), 1, 1, null),
  ('underworld_market', 'fd_potato', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_potato') * 1.3), 1, 1, null),
  ('underworld_market', 'mt_chicken', ceil((select reference_price from public.world_item_catalog where item_id = 'mt_chicken') * 1.3), 1, 1, null),
  ('north_market', 'fd_garlic', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_garlic') * 1.3), 1, 1, null),
  ('north_market', 'fd_buckwheat', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_buckwheat') * 1.3), 1, 1, null),
  ('north_market', 'fd_potato', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_potato') * 1.3), 1, 1, null),
  ('north_market', 'mt_beast', ceil((select reference_price from public.world_item_catalog where item_id = 'mt_beast') * 1.3), 1, 1, null),
  ('river_market', 'fd_rice', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_rice') * 1.3), 1, 1, null),
  ('river_market', 'fd_lotus_root', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_lotus_root') * 1.3), 1, 1, null),
  ('river_market', 'fd_minari', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_minari') * 1.3), 1, 1, null),
  ('river_market', 'mt_yofish', ceil((select reference_price from public.world_item_catalog where item_id = 'mt_yofish') * 1.3), 1, 1, null),
  ('south_market', 'fd_chili', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_chili') * 1.3), 1, 1, null),
  ('south_market', 'fd_ginger', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_ginger') * 1.3), 1, 1, null),
  ('south_market', 'fd_sweet_potato', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_sweet_potato') * 1.3), 1, 1, null),
  ('south_market', 'mt_boar', ceil((select reference_price from public.world_item_catalog where item_id = 'mt_boar') * 1.3), 1, 1, null),
  ('astral_market', 'fd_jujube', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_jujube') * 1.3), 1, 1, null),
  ('astral_market', 'fd_chestnut', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_chestnut') * 1.3), 1, 1, null),
  ('astral_market', 'fd_deodeok', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_deodeok') * 1.3), 1, 1, null),
  ('astral_market', 'mt_pheasant', ceil((select reference_price from public.world_item_catalog where item_id = 'mt_pheasant') * 1.3), 1, 1, null),
  ('night_office_store', 'fd_rice', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_rice') * 1.3), 1, 1, null),
  ('night_office_store', 'fd_potato', ceil((select reference_price from public.world_item_catalog where item_id = 'fd_potato') * 1.3), 1, 1, null),
  ('capital_market', 'sp_night_office_1', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_night_office_1') * 1.3), 1, 1, 5),
  ('capital_market', 'sp_night_office_2', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_night_office_2') * 1.3), 1, 1, 5),
  ('frontier_market', 'sp_red_moon_cult_1', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_red_moon_cult_1') * 1.3), 1, 1, 5),
  ('frontier_market', 'sp_red_moon_cult_2', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_red_moon_cult_2') * 1.3), 1, 1, 5),
  ('underworld_market', 'sp_black_lotus_1', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_black_lotus_1') * 1.3), 1, 1, 5),
  ('underworld_market', 'sp_black_lotus_2', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_black_lotus_2') * 1.3), 1, 1, 5),
  ('north_market', 'sp_north_league_1', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_north_league_1') * 1.3), 1, 1, 5),
  ('north_market', 'sp_north_league_2', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_north_league_2') * 1.3), 1, 1, 5),
  ('river_market', 'sp_river_alliance_1', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_river_alliance_1') * 1.3), 1, 1, 5),
  ('river_market', 'sp_river_alliance_2', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_river_alliance_2') * 1.3), 1, 1, 5),
  ('south_market', 'sp_southern_remnant_1', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_southern_remnant_1') * 1.3), 1, 1, 5),
  ('south_market', 'sp_southern_remnant_2', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_southern_remnant_2') * 1.3), 1, 1, 5),
  ('astral_market', 'sp_mandate_court_1', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_mandate_court_1') * 1.3), 1, 1, 5),
  ('astral_market', 'sp_mandate_court_2', ceil((select reference_price from public.world_item_catalog where item_id = 'sp_mandate_court_2') * 1.3), 1, 1, 5)
on conflict do nothing;

select pg_temp.yh_patch('public.world_battle_action(text, text)'::regprocedure, 'IF random() < 0.25 + rare / 100.0 THEN', 'loot := public.world_food_meat_roll(loot, m.drops, a.rank);
    IF random() < 0.25 + rare / 100.0 THEN');

select pg_temp.yh_patch('public.world_battle_action(text, text)'::regprocedure, 'WHERE ic.item_id = k) AND random() < drop_p THEN', 'WHERE ic.item_id = k) AND random() < drop_p AND NOT public.world_food_is_meat(k) THEN');

select pg_temp.yh_patch('public.world_shop_refresh(text)'::regprocedure, 'or sc.item_id = any(story)', 'or sc.item_id = any(story) or sc.item_id = any(public.world_food_fixed())');

select pg_temp.yh_patch('public.world_shop_refresh(text)'::regprocedure, 'then 4 else 6 end', 'then 6 else 10 end');

select pg_temp.yh_patch('public.world_kin_rules()'::regprocedure, '"faded": "빛바랜 정표"', '"faded": "빛바랜 정표", "food": {"hanseol": "dish_ginger_tea", "yeoul": "dish_potato_grill", "wolha": "sp_black_lotus_2", "daon": "dish_sweet_candy", "hisu": "dish_chestnut_rice", "danbi": "sp_red_moon_cult_1", "unbi": "sp_north_league_1", "cheongpa": "sp_river_alliance_2", "galmae": "sp_southern_remnant_2", "haram": "sp_mandate_court_2", "munsu": "sp_night_office_1", "mogaram": "dish_buckwheat_jelly", "yeonseohui": "dish_chicken_porridge", "kangducheol": "dish_boar_suyuk", "yeoseotjjae": "sp_black_lotus_1"}, "food_mul": 1.5');

select pg_temp.yh_patch('public.world_kin_gift(text)'::regprocedure, 'infield := public.world_kin_in_field(uid, k.npc, base);', 'infield := public.world_kin_in_field(uid, k.npc, base) or base = (r -> ''food'' ->> k.npc);');

select pg_temp.yh_patch('public.world_kin_gift(text)'::regprocedure, 'random() * 100 < (r -> ''reward'' ->> ''pct'')::numeric', 'random() * 100 < (r -> ''reward'' ->> ''pct'')::numeric * (case when base = (r -> ''food'' ->> k.npc) then (r ->> ''food_mul'')::numeric else 1 end)');

select pg_temp.yh_patch('public.world_storage_rules()'::regprocedure, '''base'', 70,', '''base'', 90,');

insert into public.world_patch_notes(note_id, title, body) values ('3.8.0', '3.8.0 · 야행 식탁', $pn$땅에서 나는 식재료와 요괴 고기가 생기고, 요리와 세력 특선 음식이 크게 늘었습니다.

## 3.8.0
- [식재료] 감자·고구마·산나물·버섯·쌀·미나리·마늘·밤·메밀·연근·고추·생강·대추·더덕·향신 씨앗·먹비 고사리·흰 밤 찹쌀이 생겼습니다. 이미 있는 채집터에서 함께 나오고, 지역 풍경과 세력 땅마다 나는 것이 다릅니다.
- [고기] 비금·거괴·파봉·갑각·수귀·천상 갈래 요괴를 물리치면 닭고기·요수 생고기·꿩고기·멧돼지고기·독게살·요괴 생선살을 얻을 때가 있습니다. 넋 갈래 요괴에게서는 나오지 않습니다.
- [고기] 고기는 그대로 먹을 수 없는 재료입니다. 멧돼지고기는 숯불 훈연, 독게살은 약초액으로 독 빼기, 요괴 생선살은 소금 절이기가 필요해, 이 고기가 드는 요리에는 정련 숯·농축 약초액·빙정염이 함께 들어갑니다.
- [요리] 새 요리 32가지가 생겼습니다. 낮은 단계 요리는 지금 음식처럼 30~45분, 높은 단계 요리는 새 기운 「고기 힘」·「뿌리 온기」·「곡기 든든」(1시간)·「큰상 기운」(2시간)을 줍니다.
- [요리] 매운탕·찜·조림·탕·죽 같은 기존 요리 24가지에 새 식재료가 들어가도록 제작법을 고쳤습니다. 효과는 그대로입니다.
- [특선] 일곱 세력 거점 상점이 그 세력의 특선 음식 두 가지를 늘 팝니다(사람마다 품목별 하루 5개). 같은 음식은 제작법으로도 만들 수 있고, 그 거점에서 만들면 솜씨가 더 납니다. 특선 음식은 세력마다 다른 기운(1시간 30분)을 줍니다.
- [상점] 거점 상점이 교체 품목으로 그 땅의 식재료와 고기를 팝니다. 한 번에 진열되는 품목도 늘었습니다.
- [연담] 연담 인물마다 좋아하는 음식이 생겼습니다. 백년지기에게 좋아하는 음식을 선물하면 분야 물품처럼 답례를 받고, 답례를 받을 기회도 더 큽니다.
- [창고] 개인 창고 기본 칸이 70칸에서 90칸으로 늘었습니다.$pn$);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126180000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
