insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, rarity, acquisition_difficulty, drop_rate_modifier,
  equipment_traits, tradeable, reference_price, stack_size)
select x.item_id, x.item_name, x.category, x.tier, x.description, x.stack_size > 1, x.required_stats, x.minimum_level, 'legendary', least(5, x.tier), 1, x.equipment_traits, x.tradeable, x.reference_price, x.stack_size
  from jsonb_to_recordset($J$[
  {"item_id": "neol_drop", "item_name": "흩은 너울 방울", "category": "material", "tier": 4, "description": "엉긴 너울을 흩어 보낸 자리에 남은 물방울. 손바닥에 올리면 한쪽으로 흐르려 한다.", "required_stats": {}, "minimum_level": 1, "equipment_traits": {}, "tradeable": true, "reference_price": 300, "stack_size": 50},
  {"item_id": "raid2_norigae", "item_name": "너울 매듭", "category": "norigae", "tier": 9, "description": "흩은 너울 방울을 흐름 맺힌 정에 꿰어 묶은 노리개. 쥐면 마음이 물살처럼 가라앉는다.", "required_stats": {"willpower": 44}, "minimum_level": 53, "equipment_traits": {"trait": "노리개", "erosion_pct": -11, "mental_loss_pct": -9, "incoming_damage_pct": -8}, "tradeable": false, "reference_price": 10300, "stack_size": 1},
  {"item_id": "raid2_amulet", "item_name": "너울 호패", "category": "amulet", "tier": 9, "description": "너울이 흩어진 자리의 굳은 물빛을 깎아 만든 호패. 앞장서는 이를 단단히 받친다.", "required_stats": {"vitality": 44}, "minimum_level": 53, "equipment_traits": {"trait": "호신부", "defense": 8, "presence": 34, "incoming_damage_pct": -17}, "tradeable": false, "reference_price": 10300, "stack_size": 1},
  {"item_id": "raid2_mask", "item_name": "너울 탈", "category": "mask", "tier": 9, "description": "물살이 비친 얼굴을 본뜬 탈. 쓰면 흐름의 빈틈이 보인다.", "required_stats": {"perception": 44}, "minimum_level": 53, "equipment_traits": {"trait": "탈", "crit_pct": 9, "encounter_pct": -9, "combat_damage_pct": 9}, "tradeable": false, "reference_price": 10300, "stack_size": 1},
  {"item_id": "hf_neol_jar", "item_name": "고인 빛 항아리", "category": "furniture", "tier": 4, "description": "별채 가구 · 도자. 엉긴 너울을 처음 흩어 보낸 이에게 남는 항아리입니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.", "required_stats": {}, "minimum_level": 1, "equipment_traits": {"hk": "neol_jar", "w": 1, "d": 1, "top": 0, "cat": "도자", "kind": "floor", "grade": 4}, "tradeable": false, "reference_price": 800, "stack_size": 1},
  {"item_id": "hf_neol_screen", "item_name": "너울 물그림 병풍", "category": "furniture", "tier": 4, "description": "별채 가구 · 병풍. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.", "required_stats": {}, "minimum_level": 1, "equipment_traits": {"hk": "neol_screen", "w": 3, "d": 1, "top": 0, "cat": "병풍", "kind": "floor", "grade": 4}, "tradeable": false, "reference_price": 800, "stack_size": 1},
  {"item_id": "hf_neol_blind", "item_name": "흩은 물빛 발", "category": "furniture", "tier": 4, "description": "별채 가구 · 장식. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.", "required_stats": {}, "minimum_level": 1, "equipment_traits": {"hk": "neol_blind", "ww": 1.6, "wh": 32, "cat": "장식", "kind": "wall", "wall": "deco", "grade": 4}, "tradeable": false, "reference_price": 800, "stack_size": 1}
]$J$::jsonb) as x(item_id text, item_name text, category text, tier int, description text, required_stats jsonb, minimum_level int, equipment_traits jsonb, tradeable boolean, reference_price bigint, stack_size int)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description, required_stats = excluded.required_stats,
  minimum_level = excluded.minimum_level, equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool_tier, required_location, description, minimum_level, recipe_difficulty, quality_bonus, required_skill_rank, craft_field)
select x.recipe_id, x.recipe_name, x.output_item, 1, x.ingredients, 1, '달맞이성', x.description, 53, 9, 0, 1, x.craft_field
  from jsonb_to_recordset($J$[
  {"recipe_id": "r_raid2_norigae", "recipe_name": "너울 매듭 엮기", "output_item": "raid2_norigae", "ingredients": {"neol_drop": 12, "flow_essence": 2}, "description": "흩은 너울 방울을 흐름 맺힌 정에 꿰어 너울 매듭을 엮는다.", "craft_field": "weaving"},
  {"recipe_id": "r_raid2_amulet", "recipe_name": "너울 호패 깎기", "output_item": "raid2_amulet", "ingredients": {"neol_drop": 12, "flow_essence": 2}, "description": "흩은 너울 방울을 굳혀 너울 호패를 깎는다.", "craft_field": "sealing"},
  {"recipe_id": "r_raid2_mask", "recipe_name": "너울 탈 빚기", "output_item": "raid2_mask", "ingredients": {"neol_drop": 12, "flow_essence": 2}, "description": "흩은 너울 방울을 흐름 맺힌 정에 개어 너울 탈을 빚는다.", "craft_field": "sealing"}
]$J$::jsonb) as x(recipe_id text, recipe_name text, output_item text, ingredients jsonb, description text, craft_field text)
on conflict (recipe_id) do update set recipe_name = excluded.recipe_name, output_item = excluded.output_item, ingredients = excluded.ingredients, required_location = excluded.required_location,
  description = excluded.description, minimum_level = excluded.minimum_level, recipe_difficulty = excluded.recipe_difficulty, craft_field = excluded.craft_field;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
  rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade, use_fx)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable,
  i.required_stats, i.required_job, i.required_faction, i.minimum_level, i.rarity, i.acquisition_difficulty, i.drop_rate_modifier, public.world_item_hq_traits(i.equipment_traits),
  i.crafting_specialization, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.item_id, 1, null
  from public.world_item_catalog i where i.item_id in ('raid2_norigae', 'raid2_amulet', 'raid2_mask')
on conflict (item_id) do nothing;

insert into public.world_furniture_sources(source, item_id, chance) values
  ('raid_neol_first', 'hf_neol_jar', 1), ('raid_world', 'hf_neol_screen', 1), ('raid_world', 'hf_neol_blind', 1)
on conflict (source, item_id) do update set chance = excluded.chance;

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade)
select x.k, x.name, x.icon, x.descr, x.cond, x.bonus, true, x.hidden, x.rule, x.sort, '토벌', x.grade
  from jsonb_to_recordset($J$[
  {"k": "neol_win1", "name": "너울을 흩은 이", "icon": "flag", "descr": "고여 굳은 것을 쓰러뜨리지 않고 흩어 보냈다.", "cond": "엉긴 너울을 기여도 1% 넘게 흩어 보내기", "bonus": {"presence": 4}, "hidden": false, "rule": {"raid": "neol_win", "n": 1}, "sort": 413, "grade": 2},
  {"k": "neol_win10", "name": "흐름지기", "icon": "flag", "descr": "너울이 고이는 자리마다 이 이름이 먼저 와 있었다.", "cond": "엉긴 너울을 기여도 1% 넘게 10번 흩어 보내기", "bonus": {"defense": 2, "combat_damage_pct": 1}, "hidden": false, "rule": {"raid": "neol_win", "n": 10}, "sort": 414, "grade": 3},
  {"k": "neol_win30", "name": "고임을 푼 손", "icon": "flag", "descr": "서른 번 고인 물이 이 손을 거쳐 다시 흘렀다.", "cond": "엉긴 너울을 기여도 1% 넘게 30번 흩어 보내기", "bonus": {"crit_pct": 1, "erosion_pct": -3, "combat_damage_pct": 2}, "hidden": false, "rule": {"raid": "neol_win", "n": 30}, "sort": 415, "grade": 4},
  {"k": "neol_w30", "name": "함께 진 무게", "icon": "shield", "descr": "혼자 받으면 무너질 무게를 여럿이 나눠 졌다.", "cond": "고임 무게를 셋 이상이 나눠 진 때에 30번 함께 지기", "bonus": {"defense": 2, "incoming_damage_pct": -1}, "hidden": false, "rule": {"raid": "neol_w", "n": 30}, "sort": 416, "grade": 3},
  {"k": "neol_d30", "name": "마름을 적신 이", "icon": "heart", "descr": "말라 가던 동료들이 이 손에서 다시 젖었다.", "cond": "동료의 마름을 회복으로 30번 풀어 주기", "bonus": {"healing_pct": 4, "mental_loss_pct": -2}, "hidden": false, "rule": {"raid": "neol_d", "n": 30}, "sort": 417, "grade": 3},
  {"k": "neol_c20", "name": "물길을 튼 이", "icon": "bolt", "descr": "흐름은 한 갈래로 트이지 않는다는 것을 안다.", "cond": "고임 심 트기에 20번 함께 치기", "bonus": {"crit_pct": 1, "combat_damage_pct": 1}, "hidden": false, "rule": {"raid": "neol_c", "n": 20}, "sort": 418, "grade": 3},
  {"k": "neol_e30", "name": "거슬러 읽은 물", "icon": "spark", "descr": "되밀려 오는 물을 막지 않고 비켜섰다.", "cond": "엇박 해일의 되밀린 물을 30번 무사히 넘기기", "bonus": {"evasion_pct": 2}, "hidden": false, "rule": {"raid": "neol_e", "n": 30}, "sort": 419, "grade": 2},
  {"k": "neol_both10", "name": "두 세계의 토벌꾼", "icon": "flag", "descr": "넘쳐흐른 것과 고여 굳은 것, 두 세계의 반쪽씩을 모두 마주했다.", "cond": "사슬 벗은 그림자와 엉긴 너울을 모두 10번씩 물리치기", "bonus": {"erosion_pct": -4, "combat_damage_pct": 2, "incoming_damage_pct": -2}, "hidden": true, "rule": {"raid": "both", "n": 10}, "sort": 420, "grade": 4}
]$J$::jsonb) as x(k text, name text, icon text, descr text, cond text, bonus jsonb, hidden boolean, rule jsonb, sort int, grade int)
on conflict (title_key) do update set title_name = excluded.title_name, icon = excluded.icon, description = excluded.description, condition_text = excluded.condition_text,
  bonus = excluded.bonus, hidden = excluded.hidden, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;

insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, sort)
values ('fr_neol', 'frame', 'legend', '너울결', '칭호 「흐름지기」를 얻으면', '토벌', '{"title": "neol_win10"}', false, 1793),
       ('sl_neol', 'seal', 'legend', '낙관 「流」', '칭호 「고임을 푼 손」을 얻으면', '토벌', '{"title": "neol_win30"}', false, 1794)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, tier = excluded.tier, category = excluded.category;
