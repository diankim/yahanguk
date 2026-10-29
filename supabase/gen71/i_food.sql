
-- ─────────────────────────────────────────────────────────────
-- I. 생선 없이 만드는 체력 회복 음식 셋(요리, 낮은·중간·높은 레벨). 지금 음식은 모두 생선이 들어가 낚시를 안 하면 못 만든다.
--   야령초 나물밥 Lv1  체력 20 · 든든함          (야령초 2·노정 건량 1 → 2개, 45전)
--   월광 이끼죽   Lv12 체력 35 · 정신 10 · 속이 따뜻함 (월광 이끼 1·농축 약초액 1·노정 건량 1 → 2개, 115전)
--   영맥 약선탕   Lv24 체력 50 · 정신 10 · 기운 충천   (영맥 수피 1·약제 바탕 1·빙정염 1 → 2개, 230전)
--   값은 재료 시세 ÷ 개수 × 1.1 이상(경제 규칙). 같은 레벨대 약(청심환 35·회춘단 60)보다 조금 약하게 두고 이로운 상태로 갈음한다.
-- ─────────────────────────────────────────────────────────────
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size, crafting_specialization)
values
  ('herb_rice', '야령초 나물밥', 'consumable', 1, '데친 야령초를 건량 밥에 비빈 소박한 한 그릇. 체력 20을 채우고 든든하게 한다.', true, '{}', 1, '{}', true, 45, 10, 'cooking'),
  ('moss_porridge', '월광 이끼죽', 'consumable', 2, '월광 이끼와 약초액을 넣고 뭉근히 끓인 죽. 체력 35·정신 10을 채우고 속을 데운다.', true, '{}', 12, '{}', true, 115, 10, 'cooking'),
  ('bark_stew', '영맥 약선탕', 'consumable', 3, '영맥 수피와 약제 바탕을 빙정염으로 간한 약선 탕. 체력 50·정신 10을 채우고 기운을 북돋운다.', true, '{}', 24, '{}', true, 230, 5, 'cooking')
on conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, tier = excluded.tier, minimum_level = excluded.minimum_level,
  reference_price = excluded.reference_price, stack_size = excluded.stack_size;
insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, required_skill, required_skill_rank, craft_field)
values
  ('cook_herb_rice', '야령초 나물밥 짓기', 'herb_rice', 2, '{"herb": 2, "travel_ration": 1}', null, 1, null, '야령초를 데쳐 건량 밥에 비빈다.', 1, null, 1, null, 1, 'cooking'),
  ('cook_moss_porridge', '월광 이끼죽 쑤기', 'moss_porridge', 2, '{"moon_moss": 1, "herbal_extract": 1, "travel_ration": 1}', null, 1, null, '월광 이끼와 약초액으로 죽을 쑨다.', 12, null, 2, null, 1, 'cooking'),
  ('cook_bark_stew', '영맥 약선탕 달이기', 'bark_stew', 2, '{"spirit_bark": 1, "medicine_base": 1, "frost_salt": 1}', null, 1, null, '영맥 수피와 약제 바탕을 빙정염으로 간해 달인다.', 24, null, 3, null, 1, 'cooking')
on conflict (recipe_id) do update set ingredients = excluded.ingredients, output_qty = excluded.output_qty, minimum_level = excluded.minimum_level,
  recipe_difficulty = excluded.recipe_difficulty, description = excluded.description;

select pg_temp.yh_patch('public.world_use_item(text)', '''oblivion_incense'', ''wedding_rice_cake'') THEN RAISE EXCEPTION',
  '''oblivion_incense'', ''wedding_rice_cake'', ''herb_rice'', ''moss_porridge'', ''bark_stew'') THEN RAISE EXCEPTION');
select pg_temp.yh_patch('public.world_use_item(text)', 'WHEN ''wedding_rice_cake'' THEN hp := 20; mn := 15;',
  'WHEN ''wedding_rice_cake'' THEN hp := 20; mn := 15; WHEN ''herb_rice'' THEN hp := 20; buffs := ARRAY[''well_fed'']; WHEN ''moss_porridge'' THEN hp := 35; mn := 10; buffs := ARRAY[''warm_belly'']; WHEN ''bark_stew'' THEN hp := 50; mn := 10; buffs := ARRAY[''vigor''];');

-- 안전지대 회복(pg_cron yh-safe-regen, 10분마다): 체력 +5 → +12 · 정신 +5 → +6. 주기는 그대로 두어 쓰기 횟수는 늘리지 않는다(빈 체력도 1시간 반 안팎이면 찬다)
select pg_temp.yh_patch('public.world_safe_regen()', 'set health = least(100, c.health + 5), mental = least(100, c.mental + 5)',
  'set health = least(100, c.health + 12), mental = least(100, c.mental + 6)');

-- 퀘스트 인물 키 맞추기: 대사는 'q:키'로 인물을 찾는데(world_quest_cast) 7.0 외전 인물 일곱(g_*)은 'q:' 없이 들어가 이름·소개가 나오지 않았다
update public.world_quest_npcs n set npc_key = 'q:' || n.npc_key
 where n.npc_key not like 'q:%' and n.npc_key not like '%:%'
   and not exists (select 1 from public.world_quest_npcs x where x.npc_key = 'q:' || n.npc_key);
