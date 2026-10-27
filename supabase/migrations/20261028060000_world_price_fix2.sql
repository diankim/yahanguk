-- 물가 결정 반영
-- 1) 회복약: 청령단 200 → 100전, 영기환 320 → 200전(기본 회복약이라 부담을 낮춘다).
--    값이 재료값보다 싸지지 않도록 두 제작법은 한 번에 2개씩 만든다(재료는 그대로: 청령단 개당 재료 약 87전, 영기환 약 143전).
-- 2) 재료값에 비해 너무 비싼 장비(재료값의 1.25배 초과)를 재료값의 1.2배로 낮춘다.
--    낮추면 바로 아래 단계보다 싸지는 장비(같은 종류에서 높은 단계가 15% 이상 비싸야 한다)는 값을 낮추는 대신 제작 재료 수를 늘려
--    값 = 재료값 × 약 1.2가 되게 한다(제작법 22개: 4·5단계 무기, 각인 공구, 강화 곡괭이 등).
-- 3) 상점 판매 수익 한도: 레벨×150전(적어도 1,000) → 24시간에 2,000전으로 고정.
-- 상점·대장간 판매가와 지금 회차의 판매가도 값과 같은 비율로 바꾼다.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 결과가 같다.

drop table if exists pg_temp.price_fix2;
create temporary table price_fix2(item_id text primary key, old_ref int, new_ref int);
insert into price_fix2 values
  ('m2_purify', 192, 130),
  ('m2_spell', 192, 130),
  ('m2_ward', 192, 130),
  ('m3_purify', 720, 350),
  ('m3_spell', 720, 350),
  ('m3_ward', 720, 350),
  ('m4_purify', 2080, 660),
  ('m4_spell', 2080, 660),
  ('m4_ward', 2080, 660),
  ('m5_spell', 5600, 1200),
  ('a5_light', 7000, 4600),
  ('clear_spirit_pill', 200, 100),
  ('spirit_qi_pill', 320, 200),
  ('h3_calm', 630, 520),
  ('h3_guard', 630, 520),
  ('h3_wise', 630, 520),
  ('h4_calm', 1819, 1300),
  ('h4_guard', 1819, 1300),
  ('h4_wise', 1819, 1300),
  ('h5_calm', 4900, 2100),
  ('k2_awe', 192, 150),
  ('k2_ghost', 192, 150),
  ('k2_hide', 192, 150),
  ('k3_awe', 720, 260),
  ('k3_ghost', 720, 260),
  ('k3_hide', 720, 260),
  ('k4_awe', 2080, 630),
  ('k4_ghost', 2080, 630),
  ('k4_hide', 2080, 630),
  ('k5_hide', 5600, 1200),
  ('n3_keen', 720, 470),
  ('n3_luck', 720, 470),
  ('n3_plenty', 720, 470),
  ('n4_keen', 2080, 1150),
  ('n4_luck', 2080, 1150),
  ('n4_plenty', 2080, 1150),
  ('n5_keen', 5600, 1900),
  ('n5_luck', 5600, 1900),
  ('s5_swift', 4200, 2550),
  ('field_knife_2', 210, 230),
  ('seal_knife', 210, 320),
  ('t2_gather', 240, 300),
  ('t4_gather', 2600, 1750),
  ('t5_gather', 7000, 2500),
  ('w_melee2_heavy', 240, 230),
  ('w_melee2_keen', 240, 230),
  ('w_melee2_silent', 240, 230),
  ('w_magic4_base', 3300, 4150),
  ('w_magic4_heavy', 3300, 4150),
  ('w_magic4_keen', 3300, 4150),
  ('w_magic4_silent', 3300, 4150),
  ('w_melee4_base', 3300, 3750),
  ('w_melee4_heavy', 3300, 3750),
  ('w_melee4_keen', 3300, 3750),
  ('w_melee4_silent', 3300, 3750),
  ('w_ranged4_base', 3300, 3750),
  ('w_ranged4_heavy', 3300, 3750),
  ('w_ranged4_keen', 3300, 3750),
  ('w_ranged4_silent', 3300, 3750),
  ('w_magic5_base', 8049, 6550),
  ('w_magic5_keen', 7000, 6550),
  ('w_melee5_base', 8049, 5600),
  ('w_melee5_keen', 7000, 5600),
  ('w_ranged5_base', 8049, 5350),
  ('w_ranged5_keen', 7000, 5350);
drop table if exists pg_temp.recipe_fix2;
create temporary table recipe_fix2(recipe_id text primary key, old_ing jsonb, new_ing jsonb);
insert into recipe_fix2 values
  ('r_w_magic4_base', '{"rune_plate": 2, "spirit_core": 1, "star_sand": 2}'::jsonb, '{"rune_plate": 3, "spirit_core": 2, "star_sand": 3}'::jsonb),
  ('r_w_magic4_heavy', '{"rune_plate": 2, "spirit_core": 1, "star_sand": 2}'::jsonb, '{"rune_plate": 3, "spirit_core": 2, "star_sand": 3}'::jsonb),
  ('r_w_magic4_keen', '{"rune_plate": 2, "spirit_core": 1, "star_sand": 2}'::jsonb, '{"rune_plate": 3, "spirit_core": 2, "star_sand": 3}'::jsonb),
  ('r_w_magic4_silent', '{"rune_plate": 2, "spirit_core": 1, "star_sand": 2}'::jsonb, '{"rune_plate": 3, "spirit_core": 2, "star_sand": 3}'::jsonb),
  ('r_w_melee4_base', '{"spirit_core": 1, "steel_ingot": 3, "thunder_ore": 2}'::jsonb, '{"spirit_core": 2, "steel_ingot": 4, "thunder_ore": 3}'::jsonb),
  ('r_w_melee4_heavy', '{"spirit_core": 1, "steel_ingot": 3, "thunder_ore": 2}'::jsonb, '{"spirit_core": 2, "steel_ingot": 4, "thunder_ore": 3}'::jsonb),
  ('r_w_melee4_keen', '{"spirit_core": 1, "steel_ingot": 3, "thunder_ore": 2}'::jsonb, '{"spirit_core": 2, "steel_ingot": 4, "thunder_ore": 3}'::jsonb),
  ('r_w_melee4_silent', '{"spirit_core": 1, "steel_ingot": 3, "thunder_ore": 2}'::jsonb, '{"spirit_core": 2, "steel_ingot": 4, "thunder_ore": 3}'::jsonb),
  ('r_w_ranged4_base', '{"sky_feather": 3, "spirit_bark": 2, "spirit_core": 1}'::jsonb, '{"sky_feather": 6, "spirit_bark": 4, "spirit_core": 2}'::jsonb),
  ('r_w_ranged4_heavy', '{"sky_feather": 3, "spirit_bark": 2, "spirit_core": 1}'::jsonb, '{"sky_feather": 6, "spirit_bark": 4, "spirit_core": 2}'::jsonb),
  ('r_w_ranged4_keen', '{"sky_feather": 3, "spirit_bark": 2, "spirit_core": 1}'::jsonb, '{"sky_feather": 6, "spirit_bark": 4, "spirit_core": 2}'::jsonb),
  ('r_w_ranged4_silent', '{"sky_feather": 3, "spirit_bark": 2, "spirit_core": 1}'::jsonb, '{"sky_feather": 6, "spirit_bark": 4, "spirit_core": 2}'::jsonb),
  ('r_w_melee5_keen', '{"monster_core": 2, "spirit_core": 2, "steel_ingot": 3, "thunder_ore": 4}'::jsonb, '{"monster_core": 3, "spirit_core": 3, "steel_ingot": 4, "thunder_ore": 5}'::jsonb),
  ('r_w_melee5_base', '{"monster_core": 2, "spirit_core": 2, "steel_ingot": 3, "thunder_ore": 4}'::jsonb, '{"monster_core": 3, "spirit_core": 3, "steel_ingot": 4, "thunder_ore": 5}'::jsonb),
  ('r_w_ranged5_keen', '{"sky_feather": 4, "spirit_bark": 3, "spirit_core": 2, "star_sand": 2}'::jsonb, '{"sky_feather": 6, "spirit_bark": 5, "spirit_core": 3, "star_sand": 3}'::jsonb),
  ('r_w_ranged5_base', '{"sky_feather": 4, "spirit_bark": 3, "spirit_core": 2, "star_sand": 2}'::jsonb, '{"sky_feather": 6, "spirit_bark": 5, "spirit_core": 3, "star_sand": 3}'::jsonb),
  ('r_w_magic5_keen', '{"mirror_shard": 2, "rune_plate": 3, "spirit_core": 2, "star_sand": 3}'::jsonb, '{"mirror_shard": 3, "rune_plate": 4, "spirit_core": 3, "star_sand": 4}'::jsonb),
  ('r_w_magic5_base', '{"mirror_shard": 2, "rune_plate": 3, "spirit_core": 2, "star_sand": 3}'::jsonb, '{"mirror_shard": 3, "rune_plate": 4, "spirit_core": 3, "star_sand": 4}'::jsonb),
  ('seal_knife_recipe', '{"ore": 3, "spirit_dust": 1, "wood": 2}'::jsonb, '{"ore": 4, "spirit_dust": 2, "wood": 3}'::jsonb),
  ('pick_upgrade', '{"herb": 2, "ore": 3, "wood": 2}'::jsonb, '{"herb": 3, "ore": 5, "wood": 3}'::jsonb),
  ('r_t2_gather', '{"river_reed": 3, "talisman_thread": 1}'::jsonb, '{"river_reed": 4, "talisman_thread": 2}'::jsonb),
  ('r_t5_gather', '{"spirit_core": 1, "star_sand": 1, "thunder_ore": 2}'::jsonb, '{"spirit_core": 2, "star_sand": 2, "thunder_ore": 4}'::jsonb);

update public.world_shop_catalog s set base_price = greatest(1, round(s.base_price * f.new_ref::numeric / f.old_ref))::bigint
  from price_fix2 f join public.world_item_catalog i on i.item_id = f.item_id and i.reference_price = f.old_ref
 where s.item_id = f.item_id;
update public.world_shop_stock s set unit_price = greatest(1, round(s.unit_price * f.new_ref::numeric / f.old_ref))::bigint
  from price_fix2 f join public.world_item_catalog i on i.item_id = f.item_id and i.reference_price = f.old_ref
 where s.item_id = f.item_id;
update public.world_item_catalog i set reference_price = f.new_ref
  from price_fix2 f where i.item_id = f.item_id and i.reference_price = f.old_ref;
update public.world_crafting_recipes r set ingredients = f.new_ing
  from recipe_fix2 f where r.recipe_id = f.recipe_id and r.ingredients = f.old_ing;
update public.world_crafting_recipes set output_qty = 2
 where output_item in ('clear_spirit_pill', 'spirit_qi_pill') and coalesce(output_qty, 1) = 1;

-- 3) 판매 수익 한도 2,000전
grant fn_owner_18878 to postgres with inherit true;
do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_shop_sell'::regproc);
  if position('greatest(1000, coalesce(c.level, 1) * 150)' in d) > 0 then execute replace(d, 'greatest(1000, coalesce(c.level, 1) * 150)', '2000'); end if;
  d := pg_get_functiondef('public.world_shop_sell_status'::regproc);
  if position('greatest(1000, coalesce(lv, 1) * 150)' in d) > 0 then execute replace(d, 'greatest(1000, coalesce(lv, 1) * 150)', '2000'); end if;
end $$;
grant fn_owner_18878 to postgres with inherit false;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028060000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

-- 확인 1: 재료보다 싼 제작품(0줄이어야 한다)
select o.item_name, o.reference_price as price, round(min(x.cost / coalesce(r.output_qty, 1))) as material_cost
  from public.world_crafting_recipes r
  join public.world_item_catalog o on o.item_id = r.output_item
  cross join lateral (select sum(i.reference_price * e.value::text::numeric) as cost from jsonb_each(r.ingredients) e join public.world_item_catalog i on i.item_id = e.key) x
 group by o.item_id, o.item_name, o.reference_price
having o.reference_price < min(x.cost / coalesce(r.output_qty, 1));
