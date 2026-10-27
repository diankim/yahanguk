-- 물가 바로잡기: 상위 물품이 하위 물품(재료)보다 싸던 것을 고친다.
-- 예: 월철 광석 3개(22전) + 정련 숯 1개(20전)로 월철 주괴 2개를 만드는데 주괴가 개당 20전이었다(재료값 개당 43전).
-- 규칙
-- 1) 제작품의 기준 시세 ≥ 가장 싼 제작법의 재료 기준 시세 합 ÷ 만드는 개수 × 1.1 (만드는 수고 10%)
--    재료가 다른 제작품이면 아래에서부터 차례로 올린다(월철 주괴 → 강철 주괴 → 강철 장비 …).
-- 2) 같은 종류 장비는 높은 단계가 바로 아래 단계의 가장 비싼 것보다 15% 이상 비싸게.
-- 3) 값은 올리기만 한다(내리는 물품 없음). 100전 아래는 5전, 1,000전 아래는 10전, 그 위는 50전 단위로 올림.
-- 4) 상점·대장간 판매가와 지금 회차의 판매가도 같은 비율로 올린다. 상점에 팔 때 받는 값(기준가의 45%)과 거래소 상한(기준가 10배)도 따라 오른다.
-- 바뀌는 물품 86개(재료·소모품 24 · 장비 62). 목록은 아래 값 표(물품, 지금 값, 새 값).
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 결과가 같다(지금 값이 표의 「지금 값」일 때만 바꾼다).

drop table if exists pg_temp.price_fix;
create temporary table price_fix(item_id text primary key, old_ref int, new_ref int);
insert into price_fix values
  ('ward_robe', 45, 250),
  ('a2_iron', 240, 290),
  ('a2_light', 240, 290),
  ('a2_robe', 240, 290),
  ('a2_shade', 240, 290),
  ('scale_vest', 260, 530),
  ('a3_iron', 900, 1450),
  ('a3_light', 900, 1450),
  ('a3_robe', 900, 1450),
  ('a3_shade', 900, 1450),
  ('spirit_mail', 950, 1700),
  ('fish_porridge', 30, 70),
  ('grilled_fish', 24, 35),
  ('tonic', 55, 60),
  ('travel_ration', 45, 50),
  ('clear_spirit_pill', 75, 200),
  ('eel_tonic', 80, 130),
  ('spicy_stew', 45, 50),
  ('carp_broth', 120, 160),
  ('spirit_qi_pill', 180, 320),
  ('moonlight_essence', 420, 640),
  ('heavenly_dew', 900, 1100),
  ('bronze_charm', 110, 400),
  ('wayfarer_pack', 110, 1300),
  ('h2_calm', 168, 190),
  ('h2_guard', 168, 190),
  ('h2_wise', 168, 190),
  ('iron_ingot', 20, 50),
  ('lacquer', 20, 40),
  ('lumber', 20, 40),
  ('medicine_base', 35, 85),
  ('resin', 20, 25),
  ('talisman_thread', 20, 85),
  ('fine_paper', 65, 80),
  ('reinforced_lumber', 65, 310),
  ('spirit_glass', 65, 190),
  ('spirit_thread', 65, 150),
  ('reinforced_leather', 260, 360),
  ('rune_plate', 260, 710),
  ('steel_ingot', 260, 450),
  ('n2_keen', 192, 260),
  ('n2_luck', 192, 260),
  ('n2_plenty', 192, 260),
  ('s2_road', 144, 190),
  ('s2_sturdy', 144, 190),
  ('s2_swift', 144, 190),
  ('fishing_rod', 60, 180),
  ('field_knife_2', 110, 210),
  ('seal_knife', 110, 210),
  ('spirit_lantern', 110, 210),
  ('spirit_rod', 220, 550),
  ('spirit_sickle', 110, 390),
  ('spirit_compass', 350, 1500),
  ('moon_blade', 110, 360),
  ('reed_crossbow', 240, 370),
  ('w_magic2_heavy', 240, 470),
  ('w_magic2_keen', 240, 470),
  ('w_magic2_silent', 240, 470),
  ('w_ranged2_heavy', 240, 850),
  ('w_ranged2_keen', 240, 850),
  ('w_ranged2_silent', 240, 850),
  ('ward_fan', 240, 600),
  ('star_bow', 900, 2050),
  ('star_mirror', 900, 1600),
  ('thunder_glaive', 900, 2850),
  ('w_magic3_heavy', 900, 1600),
  ('w_magic3_keen', 900, 1600),
  ('w_magic3_silent', 900, 1600),
  ('w_melee3_heavy', 900, 1650),
  ('w_melee3_keen', 900, 1650),
  ('w_melee3_silent', 900, 1650),
  ('w_ranged3_heavy', 900, 1550),
  ('w_ranged3_keen', 900, 1550),
  ('w_ranged3_silent', 900, 1550),
  ('w_magic4_base', 2989, 3300),
  ('w_magic4_heavy', 2600, 3300),
  ('w_magic4_keen', 2600, 3300),
  ('w_magic4_silent', 2600, 3300),
  ('w_melee4_base', 2989, 3300),
  ('w_melee4_heavy', 2600, 3300),
  ('w_melee4_keen', 2600, 3300),
  ('w_melee4_silent', 2600, 3300),
  ('w_ranged4_base', 2989, 3300),
  ('w_ranged4_heavy', 2600, 3300),
  ('w_ranged4_keen', 2600, 3300),
  ('w_ranged4_silent', 2600, 3300);

-- 상점·대장간 기준가와 지금 회차 판매가(물품 값이 아직 옛 값일 때만)
update public.world_shop_catalog s set base_price = greatest(1, round(s.base_price * f.new_ref::numeric / f.old_ref))::bigint
  from price_fix f join public.world_item_catalog i on i.item_id = f.item_id and i.reference_price = f.old_ref
 where s.item_id = f.item_id;
update public.world_shop_stock s set unit_price = greatest(1, round(s.unit_price * f.new_ref::numeric / f.old_ref))::bigint
  from price_fix f join public.world_item_catalog i on i.item_id = f.item_id and i.reference_price = f.old_ref
 where s.item_id = f.item_id;
-- 물품 기준 시세
update public.world_item_catalog i set reference_price = f.new_ref
  from price_fix f where i.item_id = f.item_id and i.reference_price = f.old_ref;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028050000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

-- 확인: 재료보다 싼 제작품(0줄이어야 한다)
select o.item_name, o.reference_price as price, round(min(x.cost / coalesce(r.output_qty, 1))) as material_cost
  from public.world_crafting_recipes r
  join public.world_item_catalog o on o.item_id = r.output_item
  cross join lateral (select sum(i.reference_price * e.value::text::numeric) as cost from jsonb_each(r.ingredients) e join public.world_item_catalog i on i.item_id = e.key) x
 group by o.item_id, o.item_name, o.reference_price
having o.reference_price < min(x.cost / coalesce(r.output_qty, 1));
