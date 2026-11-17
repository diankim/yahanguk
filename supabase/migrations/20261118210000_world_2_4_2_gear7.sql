insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, tradeable, reference_price, stack_size, use_fx)
select x.item_id, x.item_name, x.category, 7, x.description, false, x.required_stats, 42, 'legendary', 5, 0.03, x.equipment_traits, true, 0, 1, null
  from jsonb_to_recordset($J$[
{"item_id":"a7_iron_b","item_name":"먹 비늘 찰갑","category":"armor","description":"먹귀 응어리를 녹여 붙인 청동 비늘을 겹겹이 엮은 찰갑. 단단하지만 요괴의 이목을 끈다.","required_stats":{"vitality":48},"equipment_traits":{"trait":"방호","defense":51,"presence":56,"evasion_pct":-7}},
{"item_id":"a7_robe_b","item_name":"한지 겹 법의","category":"armor","description":"빈칸 한지를 먹비 이끼 풀로 겹겹이 붙여 지은 법의. 받는 피해를 덜고 요기를 막는다.","required_stats":{"willpower":48},"equipment_traits":{"trait":"방호","defense":25,"erosion_pct":-21,"damage_reduction_pct":13}},
{"item_id":"w_melee_mz","item_name":"명석 참명도","category":"weapon","description":"이름 서린 명석을 두드려 날을 세운 칼. 명소에서 「명석의 정」이 더 잘 보인다.","required_stats":{"strength":48},"equipment_traits":{"jobs":["artificer","analyst"],"power":60,"trait":"근접","weapon_type":"melee","combat_damage_pct":22,"mz_j_stone":10}},
{"item_id":"w_ranged_mz","item_name":"명목 흑단궁","category":"weapon","description":"이름 서린 명목으로 등을 댄 흑단 활. 명소에서 「명목의 정」이 더 잘 보인다.","required_stats":{"agility":48},"equipment_traits":{"ammo":"ammo_arrow","jobs":["scout","tamer"],"power":60,"trait":"원거리","weapon_type":"ranged","combat_damage_pct":22,"mz_j_wood":10}},
{"item_id":"w_magic_mz","item_name":"명초 법등","category":"weapon","description":"이름 서린 명초 기름을 먹인 법등. 명소에서 「명초의 정」이 더 잘 보인다.","required_stats":{"spirit_affinity":48},"equipment_traits":{"jobs":["exorcist","sealmaster","medic"],"power":60,"trait":"술법","weapon_type":"magic","combat_damage_pct":22,"mz_j_herb":10}}
]$J$::jsonb) as x(item_id text, item_name text, category text, description text, required_stats jsonb, equipment_traits jsonb)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  required_stats = excluded.required_stats, equipment_traits = excluded.equipment_traits, minimum_level = excluded.minimum_level, tradeable = excluded.tradeable;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool_tier, required_location, description, minimum_level, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field)
select x.recipe_id, x.recipe_name, x.output_item, 1, x.ingredients, 1, '묵창 나루', x.description, 42, 7, 0, x.required_skill, x.required_skill_rank, x.craft_field
  from jsonb_to_recordset($J$[
{"recipe_id":"r_a7_iron_b","recipe_name":"먹 비늘 찰갑 만들기","output_item":"a7_iron_b","ingredients":{"steel_ingot":2,"meokgwi_lump":5,"bronze_scale_plate":5,"drifting_name_thread":3},"description":"먹 비늘 찰갑을(를) 만든다.","required_skill":null,"required_skill_rank":1,"craft_field":"smithing"},
{"recipe_id":"r_a7_robe_b","recipe_name":"한지 겹 법의 만들기","output_item":"a7_robe_b","ingredients":{"blank_hanji":5,"meokbi_moss":3,"mukchang_ink":2,"drifting_name_thread":3},"description":"한지 겹 법의을(를) 만든다.","required_skill":null,"required_skill_rank":1,"craft_field":"weaving"},
{"recipe_id":"r_w_melee_mz","recipe_name":"명석 참명도 만들기","output_item":"w_melee_mz","ingredients":{"mz_stone_j":2,"mz_stone_n":1,"steel_ingot":4,"bronze_scale_plate":3,"drifting_name_thread":3},"description":"명장의 솜씨로 명석 참명도을(를) 만든다.","required_skill":"smithing","required_skill_rank":50,"craft_field":"smithing"},
{"recipe_id":"r_w_ranged_mz","recipe_name":"명목 흑단궁 만들기","output_item":"w_ranged_mz","ingredients":{"mz_wood_j":2,"mz_wood_n":1,"meokbi_ebony":4,"sky_feather":3,"drifting_name_thread":3},"description":"명장의 솜씨로 명목 흑단궁을(를) 만든다.","required_skill":"carpentry","required_skill_rank":50,"craft_field":"carpentry"},
{"recipe_id":"r_w_magic_mz","recipe_name":"명초 법등 만들기","output_item":"w_magic_mz","ingredients":{"mz_herb_j":2,"mz_herb_n":1,"rune_plate":3,"spirit_core":2,"drifting_name_thread":3},"description":"명장의 솜씨로 명초 법등을(를) 만든다.","required_skill":"artifice","required_skill_rank":50,"craft_field":"artifice"}
]$J$::jsonb) as x(recipe_id text, recipe_name text, output_item text, ingredients jsonb, description text, required_skill text, required_skill_rank int, craft_field text)
on conflict (recipe_id) do update set recipe_name = excluded.recipe_name, output_item = excluded.output_item, ingredients = excluded.ingredients, craft_field = excluded.craft_field,
  required_location = excluded.required_location, minimum_level = excluded.minimum_level, description = excluded.description, recipe_difficulty = excluded.recipe_difficulty,
  required_skill = excluded.required_skill, required_skill_rank = excluded.required_skill_rank;

update public.world_item_catalog i set reference_price = greatest(
    ceil(1.2 * (select min(t.v) from (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) v from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id group by cr.recipe_id) t)),
    coalesce(ceil(1.15 * (select max(f.reference_price) from public.world_item_catalog f where f.tier = 6 and f.category = i.category and f.base_item_id is null
      and f.item_id not like 'raid%' and coalesce((f.equipment_traits ->> 'life_slot'), '') = coalesce((i.equipment_traits ->> 'life_slot'), ''))), 0))
 where i.item_id in ('a7_iron_b', 'a7_robe_b', 'w_melee_mz', 'w_ranged_mz', 'w_magic_mz');

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
  rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade, use_fx)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable,
  i.required_stats, i.required_job, i.required_faction, i.minimum_level, i.rarity, i.acquisition_difficulty, i.drop_rate_modifier,
  public.world_item_hq_traits(i.equipment_traits), i.crafting_specialization, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.item_id, 1, null
  from public.world_item_catalog i
 where i.item_id in ('a7_iron_b', 'a7_robe_b', 'w_melee_mz', 'w_ranged_mz', 'w_magic_mz')
on conflict (item_id) do nothing;

insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian)
select x.n, d.mechanic_key, d.level_min, d.level_max, d.chance_normal, d.chance_elite, d.chance_guardian
  from (values ('a7_iron_b', 'a7_iron'), ('a7_robe_b', 'a7_robe')) x(n, o)
  join public.world_gear_drops d on d.item_id = x.o
 where not exists (select 1 from public.world_gear_drops e where e.item_id = x.n and e.mechanic_key = d.mechanic_key);

do $c$ begin
  if (select count(*) from public.world_item_catalog where item_id in ('a7_iron_b', 'a7_robe_b', 'w_melee_mz', 'w_ranged_mz', 'w_magic_mz', 'a7_iron_b_hq', 'a7_robe_b_hq', 'w_melee_mz_hq', 'w_ranged_mz_hq', 'w_magic_mz_hq')) <> 10 then
    raise exception '7단계 장비 다섯과 우수품이 다 들어가지 않았습니다'; end if;
  if (select count(*) from public.world_crafting_recipes where output_item in ('a7_iron_b', 'a7_robe_b', 'w_melee_mz', 'w_ranged_mz', 'w_magic_mz')) <> 5 then
    raise exception '제작법 다섯이 다 들어가지 않았습니다'; end if;
  if exists (select 1 from jsonb_array_elements_text('["a7_iron_b","a7_robe_b","w_melee_mz","w_ranged_mz","w_magic_mz"]'::jsonb) g(id)
      join public.world_crafting_recipes r on r.output_item = g.id, jsonb_object_keys(r.ingredients) k
      where not exists (select 1 from public.world_item_catalog c where c.item_id = k)) then raise exception '없는 재료가 있습니다'; end if;
  if exists (select 1 from public.world_item_catalog where item_id in ('a7_iron_b', 'a7_robe_b', 'w_melee_mz', 'w_ranged_mz', 'w_magic_mz') and coalesce(reference_price, 0) <= 0) then
    raise exception '시세가 비었습니다'; end if;
end $c$;

update public.world_patch_notes set body = body || $N$


## 2.4.2
- 7단계 몸 방어구에 쉽게 만드는 길을 더했습니다. 체질 「먹 비늘 찰갑」(단조)·의지 「한지 겹 법의」(직조)는 명어·명소 재료 없이 묵창 나루에서 만들 수 있고, 묵적록 요괴에게서도 얻습니다.
- 7단계 무기에 명장 제작을 더했습니다. 근접 「명석 참명도」(단조)·원거리 「명목 흑단궁」(목공)·술법 「명초 법등」(법구 공예)은 명소 재료로 만들고, 그 갈래 50단계가 필요합니다.
- 지도에서 걸어가게 되는 길의 안내 글이 한 글자씩 세로로 깨져 보이던 것을 고쳤습니다.$N$ where note_id = '2.4.0';

update public.world_app_meta set value = '20261118210000' where key = 'db_version';
