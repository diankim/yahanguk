lock table public.world_characters in access exclusive mode;

do $c$ begin
  if (select ingredients from public.world_crafting_recipes where recipe_id = 'r_a2_iron') is distinct from '{"beast_hide": 3, "iron_ingot": 1}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_k3_awe') is distinct from '{"lumber": 1, "lacquer": 1, "ghost_ash": 2}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_k4_awe') is distinct from '{"ghost_ash": 2, "shadow_fang": 2, "spirit_bark": 1}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_w_melee2_heavy') is distinct from '{"lumber": 1, "iron_ingot": 3}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'guard_spear_recipe') is distinct from '{"lumber": 2, "raw_iron": 3, "beast_bone": 1}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_a2_shade') is distinct from '{"beast_hide": 3, "iron_ingot": 1}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_k3_hide') is distinct from '{"lumber": 1, "lacquer": 1, "ghost_ash": 2}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_w_melee2_silent') is distinct from '{"lumber": 1, "iron_ingot": 3}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_w_melee3_silent') is distinct from '{"steel_ingot": 2, "monster_core": 1, "reinforced_lumber": 1}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_w_ranged3_silent') is distinct from '{"sky_feather": 2, "monster_core": 1, "reinforced_lumber": 2}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_a2_robe') is distinct from '{"beast_hide": 3, "iron_ingot": 1}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_s2_road') is distinct from '{"beast_hide": 2, "river_reed": 2}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_h2_guard') is distinct from '{"silk": 2, "lacquer": 1}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'cook_sweetfish') is distinct from '{"charcoal": 1, "sweetfish": 1}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'cook_dried_croaker') is distinct from '{"yellow_croaker": 2}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'cook_skate_ferment') is distinct from '{"herb": 1, "eclipse_skate": 1}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_s2_sturdy') is distinct from '{"beast_hide": 2, "river_reed": 2}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'seal_knife_recipe') is distinct from '{"ore": 4, "wood": 3, "spirit_dust": 2}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_m2_spell') is distinct from '{"cinnabar": 1, "seal_paper": 2}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_w_magic4_silent') is distinct from '{"star_sand": 3, "rune_plate": 3, "spirit_core": 2}'::jsonb or (select ingredients from public.world_crafting_recipes where recipe_id = 'r_w_melee3_heavy') is distinct from '{"steel_ingot": 2, "monster_core": 1, "reinforced_lumber": 1}'::jsonb then
    raise exception '재료 소모처: 제작법 재료가 예상과 다릅니다';
  end if;
end $c$;

update public.world_crafting_recipes r set ingredients = v.ing::jsonb from (values
  ('r_a2_iron', '{"beast_hide": 2, "beast_fang": 1, "iron_ingot": 1}'),
  ('r_k3_awe', '{"lumber": 1, "lacquer": 1, "ghost_ash": 1, "beast_fang": 1}'),
  ('r_k4_awe', '{"ghost_ash": 1, "beast_fang": 1, "shadow_fang": 2, "spirit_bark": 1}'),
  ('r_w_melee2_heavy', '{"lumber": 1, "iron_ingot": 2, "beast_fang": 1}'),
  ('guard_spear_recipe', '{"lumber": 2, "raw_iron": 3, "beast_fang": 1}'),
  ('r_a2_shade', '{"beast_hide": 2, "shadow_fang": 1, "iron_ingot": 1}'),
  ('r_k3_hide', '{"lumber": 1, "lacquer": 1, "ghost_ash": 1, "shadow_fang": 1}'),
  ('r_w_melee2_silent', '{"lumber": 1, "iron_ingot": 2, "shadow_fang": 1}'),
  ('r_w_melee3_silent', '{"steel_ingot": 2, "venom_gland": 2, "reinforced_lumber": 1}'),
  ('r_w_ranged3_silent', '{"sky_feather": 2, "venom_gland": 2, "reinforced_lumber": 2}'),
  ('r_a2_robe', '{"beast_hide": 2, "drowned_scale": 1, "iron_ingot": 1}'),
  ('r_s2_road', '{"beast_hide": 1, "drowned_scale": 1, "river_reed": 2}'),
  ('r_h2_guard', '{"silk": 1, "drowned_scale": 1, "lacquer": 1}'),
  ('cook_sweetfish', '{"charcoal": 1, "sweetfish": 1, "frost_salt": 1}'),
  ('cook_dried_croaker', '{"yellow_croaker": 2, "frost_salt": 1}'),
  ('cook_skate_ferment', '{"herb": 1, "eclipse_skate": 1, "frost_salt": 1}'),
  ('r_s2_sturdy', '{"beast_hide": 2, "river_reed": 1, "raw_iron": 1}'),
  ('seal_knife_recipe', '{"ore": 3, "raw_iron": 1, "wood": 3, "spirit_dust": 2}'),
  ('r_m2_spell', '{"cinnabar": 1, "seal_paper": 1, "inkstone": 1}'),
  ('r_w_magic4_silent', '{"star_sand": 2, "rune_plate": 3, "spirit_core": 2, "lantern_oil": 1}'),
  ('r_w_melee3_heavy', '{"steel_ingot": 2, "ember_crystal": 1, "reinforced_lumber": 1}')
) v(id, ing) where r.recipe_id = v.id;

update public.world_patch_notes set body = body || E'\n- 덜 쓰이던 재료를 기존 제작법에 나눠 넣었습니다(재료값은 그대로이거나 조금 낮아짐): 요수 송곳니(두정갑·방상씨탈·사자탈·쌍날 대부·순찰 장창)·잠복귀 송곳니(야행 경의·소무탈·연막 단검)·독낭(무영 소도·무음 비궁)·수귀 비늘(수결 도포·행전 짚신·전립)·빙정염(은어 소금구이·굴비 엮기·홍어 삭히기)·생 월철(쇠징 신·각인 공구)·먹정(오색 부적낭)·등롱 어유(유령 등롱)·잔화 결정(파산 철편).'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109070000' where key = 'db_version';
