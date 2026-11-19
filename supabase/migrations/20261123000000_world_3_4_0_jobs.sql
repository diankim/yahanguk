lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE'); s boolean := not pg_has_role(current_user, p_role, 'SET');
begin
  if s then execute format('grant %I to %I with set true', p_role, current_user); end if;
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
  if s then execute format('grant %I to %I with set false', p_role, current_user); end if;
end $f$;

update public.world_item_catalog set item_name = '편전', description = '쇠뇌와 취관에 재는 짧은 살. 통아(대롱)에 넣어 쏘거나 불어 쏜다. 쇠뇌·취관으로 공격할 때마다 하나씩 쓴다.' where item_id = 'ammo_dart';
update public.world_crafting_recipes set recipe_name = '편전 만들기', description = '편전을(를) 만든다.' where output_item = 'ammo_dart';
update public.world_item_catalog set item_name = '월철 등패와 환도', description = '등나무 방패와 환도를 한 벌로 든다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["artificer"], "power": 6, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 3}'::jsonb where item_id = 'iron_sword';
update public.world_crafting_recipes set recipe_name = '월철 등패와 환도 만들기', description = '월철 등패와 환도을(를) 만든다.' where output_item = 'iron_sword';
update public.world_item_catalog set item_name = '월식 등패와 환도', description = '등나무 방패와 환도를 한 벌로 든다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["artificer"], "power": 12, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 5}'::jsonb where item_id = 'moon_blade';
update public.world_crafting_recipes set recipe_name = '월식 등패와 환도 만들기', description = '월식 등패와 환도을(를) 만든다.' where output_item = 'moon_blade';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_guard3_a', '청강 등패와 환도', 'weapon', 3, 'rare', '등나무 방패와 환도를 한 벌로 든다. 근접 공격을 하며 주는 피해가 오른다.', false, true, 2850, 1, 14, '{"strength": 19}'::jsonb, null, null, '{"jobs": ["artificer"], "power": 20, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 5}'::jsonb, 0.42, 3, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_guard3_a', '청강 등패와 환도 만들기', '청강 등패와 환도을(를) 만든다.', 'w_guard3_a', 1, '{"steel_ingot": 2, "thunder_ore": 3, "monster_core": 1, "reinforced_lumber": 2}'::jsonb, 'smithing', 14, '철벽 고찰', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
update public.world_item_catalog set item_name = '용린 등패와 환도', description = '등나무 방패와 환도를 한 벌로 든다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["artificer"], "power": 28, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 10}'::jsonb where item_id = 'w_melee4_base';
update public.world_crafting_recipes set recipe_name = '용린 등패와 환도 만들기', description = '용린 등패와 환도을(를) 만든다.' where output_item = 'w_melee4_base';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_guard5_a', '태극 등패와 환도', 'weapon', 5, 'legendary', '등나무 방패와 환도를 한 벌로 든다. 근접 공격을 하며 주는 피해가 오른다.', false, true, 5600, 1, 20, '{"strength": 25}'::jsonb, null, null, '{"jobs": ["artificer"], "power": 38, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 15}'::jsonb, 0.08, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_guard5_a', '태극 등패와 환도 만들기', '태극 등패와 환도을(를) 만든다.', 'w_guard5_a', 1, '{"spirit_core": 3, "steel_ingot": 4, "thunder_ore": 5, "monster_core": 3}'::jsonb, 'smithing', 20, '무극 관성대', null, 1, null, 1, null, 5, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard5_a', 'armored', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard5_a', 'swarm', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard5_a', 'boss', 20, 40, 0, 0.01, 0.03);
update public.world_item_catalog set item_name = '귀허 등패와 환도', description = '등나무 방패와 환도를 한 벌로 든다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["artificer"], "power": 48, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 18}'::jsonb where item_id = 'w_melee6_base';
update public.world_crafting_recipes set recipe_name = '귀허 등패와 환도 만들기', description = '귀허 등패와 환도을(를) 만든다.' where output_item = 'w_melee6_base';
update public.world_item_catalog set item_name = '묵창 등패와 환도', description = '등나무 방패와 환도를 한 벌로 든다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["artificer"], "power": 58, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 22}'::jsonb where item_id = 'w_melee7_base';
update public.world_crafting_recipes set recipe_name = '묵창 등패와 환도 만들기', description = '묵창 등패와 환도을(를) 만든다.' where output_item = 'w_melee7_base';
update public.world_item_catalog set item_name = '언 종루 등패와 환도', description = '등나무 방패와 환도를 한 벌로 든다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["artificer"], "power": 66, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 24}'::jsonb where item_id = 'w_melee8_base';
update public.world_crafting_recipes set recipe_name = '언 종루 등패와 환도 만들기', description = '언 종루 등패와 환도을(를) 만든다.' where output_item = 'w_melee8_base';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_guard1_b', '무쇠 등패와 철퇴', 'weapon', 1, 'common', '등나무 방패와 철퇴를 한 벌로 든다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', false, true, 80, 1, 1, '{}'::jsonb, null, null, '{"jobs": ["artificer"], "power": 6, "trait": "근접", "weapon_type": "melee", "presence": 6, "incoming_damage_pct": -1}'::jsonb, 1.0, 1, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard1_b', 'armored', 1, 6, 0.015, 0.03, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard1_b', 'swarm', 1, 6, 0.015, 0.03, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_guard2_b', '순라 등패와 철퇴', 'weapon', 2, 'uncommon', '등나무 방패와 철퇴를 한 벌로 든다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', false, true, 230, 1, 5, '{"strength": 9}'::jsonb, null, null, '{"jobs": ["artificer"], "power": 12, "trait": "근접", "weapon_type": "melee", "presence": 12, "incoming_damage_pct": -2}'::jsonb, 0.72, 2, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_guard2_b', '순라 등패와 철퇴 만들기', '순라 등패와 철퇴을(를) 만든다.', 'w_guard2_b', 1, '{"lumber": 1, "beast_fang": 1, "iron_ingot": 2}'::jsonb, 'smithing', 5, '철벽 고찰', null, 1, null, 1, null, 2, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard2_b', 'armored', 3, 12, 0.012, 0.03, 0.06);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard2_b', 'swarm', 3, 12, 0.012, 0.03, 0.06);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_guard3_b', '청강 등패와 철퇴', 'weapon', 3, 'rare', '등나무 방패와 철퇴를 한 벌로 든다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', false, true, 1650, 1, 10, '{"strength": 14}'::jsonb, null, null, '{"jobs": ["artificer"], "power": 20, "trait": "근접", "weapon_type": "melee", "presence": 18, "incoming_damage_pct": -3}'::jsonb, 0.42, 3, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_guard3_b', '청강 등패와 철퇴 만들기', '청강 등패와 철퇴을(를) 만든다.', 'w_guard3_b', 1, '{"steel_ingot": 2, "ember_crystal": 1, "reinforced_lumber": 1}'::jsonb, 'smithing', 10, '철벽 고찰', null, 1, null, 1, null, 3, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard3_b', 'armored', 8, 18, 0.006, 0.025, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard3_b', 'swarm', 8, 18, 0.006, 0.025, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_guard4_b', '현무 등패와 철퇴', 'weapon', 4, 'epic', '등나무 방패와 철퇴를 한 벌로 든다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', false, true, 3750, 1, 15, '{"strength": 20}'::jsonb, null, null, '{"jobs": ["artificer"], "power": 28, "trait": "근접", "weapon_type": "melee", "presence": 24, "incoming_damage_pct": -5}'::jsonb, 0.2, 4, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_guard4_b', '현무 등패와 철퇴 만들기', '현무 등패와 철퇴을(를) 만든다.', 'w_guard4_b', 1, '{"spirit_core": 2, "steel_ingot": 4, "thunder_ore": 3}'::jsonb, 'smithing', 15, '철벽 고찰', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard4_b', 'armored', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard4_b', 'swarm', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_guard5_b', '진산 등패와 철퇴', 'weapon', 5, 'legendary', '등나무 방패와 철퇴를 한 벌로 든다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', false, true, 7000, 1, 20, '{"strength": 25}'::jsonb, null, null, '{"jobs": ["artificer"], "power": 38, "trait": "근접", "weapon_type": "melee", "presence": 30, "incoming_damage_pct": -7}'::jsonb, 0.08, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_guard5_b', '진산 등패와 철퇴 만들기', '진산 등패와 철퇴을(를) 만든다.', 'w_guard5_b', 1, '{"spirit_core": 3, "steel_ingot": 4, "thunder_ore": 5, "monster_core": 3}'::jsonb, 'smithing', 20, '무극 관성대', null, 1, null, 1, null, 5, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard5_b', 'armored', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard5_b', 'swarm', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard5_b', 'boss', 20, 40, 0, 0.01, 0.03);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_guard6_b', '갈대 물살 등패와 철퇴', 'weapon', 6, 'legendary', '등나무 방패와 철퇴를 한 벌로 든다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', false, true, 8112, 1, 32, '{"strength": 38}'::jsonb, null, null, '{"jobs": ["artificer"], "power": 48, "trait": "근접", "weapon_type": "melee", "presence": 36, "incoming_damage_pct": -9}'::jsonb, 0.05, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_guard6_b', '갈대 물살 등패와 철퇴 만들기', '갈대 물살 등패와 철퇴을(를) 만든다.', 'w_guard6_b', 1, '{"yoin_blood": 3, "gwiheo_iron": 6, "steel_ingot": 4, "monster_core": 2}'::jsonb, 'smithing', 32, '반요촌', null, 1, null, 1, null, 6, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard6_b', 'armored', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard6_b', 'swarm', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard6_b', 'boss', 31, 40, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_guard7_b', '먹비 등패와 철퇴', 'weapon', 7, 'legendary', '등나무 방패와 철퇴를 한 벌로 든다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', false, true, 9453, 1, 42, '{"strength": 48}'::jsonb, null, null, '{"jobs": ["artificer"], "power": 58, "trait": "근접", "weapon_type": "melee", "presence": 42, "incoming_damage_pct": -11}'::jsonb, 0.03, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_guard7_b', '먹비 등패와 철퇴 만들기', '먹비 등패와 철퇴을(를) 만든다.', 'w_guard7_b', 1, '{"steel_ingot": 4, "erased_plate": 2, "bronze_scale_plate": 6, "drifting_name_thread": 3}'::jsonb, 'smithing', 42, '묵창 나루', null, 1, null, 1, null, 7, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard7_b', 'armored', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard7_b', 'swarm', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard7_b', 'boss', 41, 45, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_guard8_b', '등불 지기 등패와 철퇴', 'weapon', 8, 'legendary', '등나무 방패와 철퇴를 한 벌로 든다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', false, true, 10871, 1, 47, '{"strength": 53}'::jsonb, null, null, '{"jobs": ["artificer"], "power": 66, "trait": "근접", "weapon_type": "melee", "presence": 46, "incoming_damage_pct": -12}'::jsonb, 0.02, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_guard8_b', '등불 지기 등패와 철퇴 만들기', '등불 지기 등패와 철퇴을(를) 만든다.', 'w_guard8_b', 1, '{"balance_weight": 2, "lamp_wick_core": 3, "frost_bell_iron": 5, "pact_stone_dust": 3}'::jsonb, 'smithing', 47, '남문 수로 선착', null, 1, null, 1, null, 8, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard8_b', 'armored', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard8_b', 'swarm', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_guard8_b', 'boss', 46, 50, 0, 0.006, 0.02);
update public.world_item_catalog set item_name = '무쇠 도끼', description = '큰 도끼를 휘둘러 베어 낸다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', equipment_traits = '{"jobs": ["bloodknight"], "power": 6, "trait": "근접", "weapon_type": "melee", "presence": 6, "incoming_damage_pct": -1}'::jsonb where item_id = 'w_melee1_heavy';
update public.world_crafting_recipes set recipe_name = '무쇠 도끼 만들기', description = '무쇠 도끼을(를) 만든다.' where output_item = 'w_melee1_heavy';
update public.world_item_catalog set item_name = '쌍날 도끼', description = '큰 도끼를 휘둘러 베어 낸다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', equipment_traits = '{"jobs": ["bloodknight"], "power": 12, "trait": "근접", "weapon_type": "melee", "presence": 12, "incoming_damage_pct": -2}'::jsonb where item_id = 'w_melee2_heavy';
update public.world_crafting_recipes set recipe_name = '쌍날 도끼 만들기', description = '쌍날 도끼을(를) 만든다.' where output_item = 'w_melee2_heavy';
update public.world_item_catalog set item_name = '파산 도끼', description = '큰 도끼를 휘둘러 베어 낸다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', equipment_traits = '{"jobs": ["bloodknight"], "power": 20, "trait": "근접", "weapon_type": "melee", "presence": 18, "incoming_damage_pct": -3}'::jsonb where item_id = 'w_melee3_heavy';
update public.world_crafting_recipes set recipe_name = '파산 도끼 만들기', description = '파산 도끼을(를) 만든다.' where output_item = 'w_melee3_heavy';
update public.world_item_catalog set item_name = '진산 도끼', description = '큰 도끼를 휘둘러 베어 낸다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', equipment_traits = '{"jobs": ["bloodknight"], "power": 28, "trait": "근접", "weapon_type": "melee", "presence": 24, "incoming_damage_pct": -5}'::jsonb where item_id = 'w_melee4_heavy';
update public.world_crafting_recipes set recipe_name = '진산 도끼 만들기', description = '진산 도끼을(를) 만든다.' where output_item = 'w_melee4_heavy';
update public.world_item_catalog set item_name = '붕산 도끼', description = '큰 도끼를 휘둘러 베어 낸다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', equipment_traits = '{"jobs": ["bloodknight"], "power": 38, "trait": "근접", "weapon_type": "melee", "presence": 30, "incoming_damage_pct": -7}'::jsonb where item_id = 'w_melee5_heavy';
update public.world_crafting_recipes set recipe_name = '붕산 도끼 만들기', description = '붕산 도끼을(를) 만든다.' where output_item = 'w_melee5_heavy';
update public.world_item_catalog set item_name = '소용돌이 도끼', description = '큰 도끼를 휘둘러 베어 낸다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', equipment_traits = '{"jobs": ["bloodknight"], "power": 48, "trait": "근접", "weapon_type": "melee", "presence": 36, "incoming_damage_pct": -9}'::jsonb where item_id = 'w_melee6_heavy';
update public.world_crafting_recipes set recipe_name = '소용돌이 도끼 만들기', description = '소용돌이 도끼을(를) 만든다.' where output_item = 'w_melee6_heavy';
update public.world_item_catalog set item_name = '아홉 칸 도끼', description = '큰 도끼를 휘둘러 베어 낸다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', equipment_traits = '{"jobs": ["bloodknight"], "power": 58, "trait": "근접", "weapon_type": "melee", "presence": 42, "incoming_damage_pct": -11}'::jsonb where item_id = 'w_melee7_heavy';
update public.world_crafting_recipes set recipe_name = '아홉 칸 도끼 만들기', description = '아홉 칸 도끼을(를) 만든다.' where output_item = 'w_melee7_heavy';
update public.world_item_catalog set item_name = '맹약 주춧돌 도끼', description = '큰 도끼를 휘둘러 베어 낸다. 근접 공격을 하며 이목을 끌고 받는 피해를 줄인다.', equipment_traits = '{"jobs": ["bloodknight"], "power": 66, "trait": "근접", "weapon_type": "melee", "presence": 46, "incoming_damage_pct": -12}'::jsonb where item_id = 'w_melee8_heavy';
update public.world_crafting_recipes set recipe_name = '맹약 주춧돌 도끼 만들기', description = '맹약 주춧돌 도끼을(를) 만든다.' where output_item = 'w_melee8_heavy';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_blood1_b', '무쇠 대검', 'weapon', 1, 'common', '두 손으로 드는 큰 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 90, 1, 1, '{}'::jsonb, null, null, '{"jobs": ["bloodknight"], "power": 6, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 3}'::jsonb, 1.0, 1, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_blood2_b', '청동 대검', 'weapon', 2, 'uncommon', '두 손으로 드는 큰 칼. 근접 공격을 하며 주는 피해가 오른다.', true, true, 360, 1, 2, '{"strength": 8}'::jsonb, null, null, '{"jobs": ["bloodknight"], "power": 12, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 5}'::jsonb, 0.72, 2, 'smithing', false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_blood2_b', '청동 대검 만들기', '청동 대검을(를) 만든다.', 'w_blood2_b', 1, '{"ore": 5, "wood": 1, "spirit_dust": 3}'::jsonb, 'smithing', 3, '연무장·팔괘진', 'seal_knife', 2, null, 1, null, 3, 0) on conflict (recipe_id) do nothing;
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_blood3_b', '뇌문 대검', 'weapon', 3, 'rare', '두 손으로 드는 큰 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 2850, 1, 14, '{"strength": 19}'::jsonb, null, null, '{"jobs": ["bloodknight"], "power": 20, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 5}'::jsonb, 0.42, 3, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_blood3_b', '뇌문 대검 만들기', '뇌문 대검을(를) 만든다.', 'w_blood3_b', 1, '{"steel_ingot": 2, "thunder_ore": 3, "monster_core": 1, "reinforced_lumber": 2}'::jsonb, 'smithing', 14, '철벽 고찰', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_blood4_b', '흑룡 대검', 'weapon', 4, 'epic', '두 손으로 드는 큰 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 3750, 1, 15, '{"strength": 20}'::jsonb, null, null, '{"jobs": ["bloodknight"], "power": 28, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 10}'::jsonb, 0.2, 4, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_blood4_b', '흑룡 대검 만들기', '흑룡 대검을(를) 만든다.', 'w_blood4_b', 1, '{"spirit_core": 2, "steel_ingot": 4, "thunder_ore": 3}'::jsonb, 'smithing', 15, '철벽 고찰', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood4_b', 'armored', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood4_b', 'swarm', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_blood5_b', '개천 대검', 'weapon', 5, 'legendary', '두 손으로 드는 큰 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 5600, 1, 20, '{"strength": 25}'::jsonb, null, null, '{"jobs": ["bloodknight"], "power": 38, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 15}'::jsonb, 0.08, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_blood5_b', '개천 대검 만들기', '개천 대검을(를) 만든다.', 'w_blood5_b', 1, '{"spirit_core": 3, "steel_ingot": 4, "thunder_ore": 5, "monster_core": 3}'::jsonb, 'smithing', 20, '무극 관성대', null, 1, null, 1, null, 5, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood5_b', 'armored', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood5_b', 'swarm', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood5_b', 'boss', 20, 40, 0, 0.01, 0.03);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_blood6_b', '소용돌이 대검', 'weapon', 6, 'legendary', '두 손으로 드는 큰 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 8050, 1, 32, '{"strength": 38}'::jsonb, null, null, '{"jobs": ["bloodknight"], "power": 48, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 18}'::jsonb, 0.05, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_blood6_b', '소용돌이 대검 만들기', '소용돌이 대검을(를) 만든다.', 'w_blood6_b', 1, '{"yoin_blood": 3, "banyo_scale": 3, "gwiheo_iron": 5, "steel_ingot": 4}'::jsonb, 'smithing', 32, '반요촌', null, 1, null, 1, null, 6, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood6_b', 'armored', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood6_b', 'swarm', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood6_b', 'boss', 31, 40, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_blood7_b', '명부 대검', 'weapon', 7, 'legendary', '두 손으로 드는 큰 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 9453, 1, 42, '{"strength": 48}'::jsonb, null, null, '{"jobs": ["bloodknight"], "power": 58, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 22}'::jsonb, 0.03, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_blood7_b', '명부 대검 만들기', '명부 대검을(를) 만든다.', 'w_blood7_b', 1, '{"steel_ingot": 4, "meokgwi_lump": 3, "bronze_scale_plate": 5, "drifting_name_thread": 3}'::jsonb, 'smithing', 42, '묵창 나루', null, 1, null, 1, null, 7, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood7_b', 'armored', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood7_b', 'swarm', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood7_b', 'boss', 41, 45, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_blood8_b', '맹약 대검', 'weapon', 8, 'legendary', '두 손으로 드는 큰 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 10871, 1, 47, '{"strength": 53}'::jsonb, null, null, '{"jobs": ["bloodknight"], "power": 66, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 24}'::jsonb, 0.02, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_blood8_b', '맹약 대검 만들기', '맹약 대검을(를) 만든다.', 'w_blood8_b', 1, '{"lamp_wick_core": 3, "frost_bell_iron": 6, "white_night_frost": 3, "century_form_scrap": 2}'::jsonb, 'smithing', 47, '남문 수로 선착', null, 1, null, 1, null, 8, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood8_b', 'armored', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood8_b', 'swarm', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_blood8_b', 'boss', 46, 50, 0, 0.006, 0.02);
update public.world_item_catalog set item_name = '날선 단도', description = '짧은 칼로 급소를 찌른다. 근접 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["analyst"], "power": 6, "trait": "근접", "weapon_type": "melee", "crit_pct": 4}'::jsonb where item_id = 'w_melee1_keen';
update public.world_crafting_recipes set recipe_name = '날선 단도 만들기', description = '날선 단도을(를) 만든다.' where output_item = 'w_melee1_keen';
update public.world_item_catalog set item_name = '은월 단도', description = '짧은 칼로 급소를 찌른다. 근접 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["analyst"], "power": 12, "trait": "근접", "weapon_type": "melee", "crit_pct": 8}'::jsonb where item_id = 'w_melee2_keen';
update public.world_crafting_recipes set recipe_name = '은월 단도 만들기', description = '은월 단도을(를) 만든다.' where output_item = 'w_melee2_keen';
update public.world_item_catalog set item_name = '청강 쌍 단도', description = '짧은 칼로 급소를 찌른다. 근접 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["analyst"], "power": 20, "trait": "근접", "weapon_type": "melee", "crit_pct": 12}'::jsonb where item_id = 'w_melee3_keen';
update public.world_crafting_recipes set recipe_name = '청강 쌍 단도 만들기', description = '청강 쌍 단도을(를) 만든다.' where output_item = 'w_melee3_keen';
update public.world_item_catalog set item_name = '청룡 단도', description = '짧은 칼로 급소를 찌른다. 근접 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["analyst"], "power": 28, "trait": "근접", "weapon_type": "melee", "crit_pct": 16}'::jsonb where item_id = 'w_melee4_keen';
update public.world_crafting_recipes set recipe_name = '청룡 단도 만들기', description = '청룡 단도을(를) 만든다.' where output_item = 'w_melee4_keen';
update public.world_item_catalog set item_name = '일섬 단도', description = '짧은 칼로 급소를 찌른다. 근접 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["analyst"], "power": 38, "trait": "근접", "weapon_type": "melee", "crit_pct": 20}'::jsonb where item_id = 'w_melee5_keen';
update public.world_crafting_recipes set recipe_name = '일섬 단도 만들기', description = '일섬 단도을(를) 만든다.' where output_item = 'w_melee5_keen';
update public.world_item_catalog set item_name = '이름 베는 단도', description = '짧은 칼로 급소를 찌른다. 근접 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["analyst"], "power": 48, "trait": "근접", "weapon_type": "melee", "crit_pct": 24}'::jsonb where item_id = 'w_melee6_keen';
update public.world_crafting_recipes set recipe_name = '이름 베는 단도 만들기', description = '이름 베는 단도을(를) 만든다.' where output_item = 'w_melee6_keen';
update public.world_item_catalog set item_name = '이름 긋는 단도', description = '짧은 칼로 급소를 찌른다. 근접 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["analyst"], "power": 58, "trait": "근접", "weapon_type": "melee", "crit_pct": 29}'::jsonb where item_id = 'w_melee7_keen';
update public.world_crafting_recipes set recipe_name = '이름 긋는 단도 만들기', description = '이름 긋는 단도을(를) 만든다.' where output_item = 'w_melee7_keen';
update public.world_item_catalog set item_name = '서식 긋는 단도', description = '짧은 칼로 급소를 찌른다. 근접 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["analyst"], "power": 66, "trait": "근접", "weapon_type": "melee", "crit_pct": 32}'::jsonb where item_id = 'w_melee8_keen';
update public.world_crafting_recipes set recipe_name = '서식 긋는 단도 만들기', description = '서식 긋는 단도을(를) 만든다.' where output_item = 'w_melee8_keen';
update public.world_item_catalog set item_name = '그림자 수리검', description = '던지는 칼날을 품에 지닌다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["analyst"], "power": 6, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 3}'::jsonb where item_id = 'w_melee1_silent';
update public.world_crafting_recipes set recipe_name = '그림자 수리검 만들기', description = '그림자 수리검을(를) 만든다.' where output_item = 'w_melee1_silent';
update public.world_item_catalog set item_name = '연막 수리검', description = '던지는 칼날을 품에 지닌다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["analyst"], "power": 12, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 5}'::jsonb where item_id = 'w_melee2_silent';
update public.world_crafting_recipes set recipe_name = '연막 수리검 만들기', description = '연막 수리검을(를) 만든다.' where output_item = 'w_melee2_silent';
update public.world_item_catalog set item_name = '무영 수리검', description = '던지는 칼날을 품에 지닌다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["analyst"], "power": 20, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 5}'::jsonb where item_id = 'w_melee3_silent';
update public.world_crafting_recipes set recipe_name = '무영 수리검 만들기', description = '무영 수리검을(를) 만든다.' where output_item = 'w_melee3_silent';
update public.world_item_catalog set item_name = '야음 수리검', description = '던지는 칼날을 품에 지닌다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["analyst"], "power": 28, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 10}'::jsonb where item_id = 'w_melee4_silent';
update public.world_crafting_recipes set recipe_name = '야음 수리검 만들기', description = '야음 수리검을(를) 만든다.' where output_item = 'w_melee4_silent';
update public.world_item_catalog set item_name = '무형 수리검', description = '던지는 칼날을 품에 지닌다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["analyst"], "power": 38, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 15}'::jsonb where item_id = 'w_melee5_silent';
update public.world_crafting_recipes set recipe_name = '무형 수리검 만들기', description = '무형 수리검을(를) 만든다.' where output_item = 'w_melee5_silent';
update public.world_item_catalog set item_name = '무월 수리검', description = '던지는 칼날을 품에 지닌다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["analyst"], "power": 48, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 18}'::jsonb where item_id = 'w_melee6_silent';
update public.world_crafting_recipes set recipe_name = '무월 수리검 만들기', description = '무월 수리검을(를) 만든다.' where output_item = 'w_melee6_silent';
update public.world_item_catalog set item_name = '먹비 수리검', description = '던지는 칼날을 품에 지닌다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["analyst"], "power": 58, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 22}'::jsonb where item_id = 'w_melee7_silent';
update public.world_crafting_recipes set recipe_name = '먹비 수리검 만들기', description = '먹비 수리검을(를) 만든다.' where output_item = 'w_melee7_silent';
update public.world_item_catalog set item_name = '그림자 없는 수리검', description = '던지는 칼날을 품에 지닌다. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["analyst"], "power": 66, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 24}'::jsonb where item_id = 'w_melee8_silent';
update public.world_crafting_recipes set recipe_name = '그림자 없는 수리검 만들기', description = '그림자 없는 수리검을(를) 만든다.' where output_item = 'w_melee8_silent';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear1_a', '박달 언월도', 'weapon', 1, 'common', '긴 자루에 반달 날을 단 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 90, 1, 1, '{}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 6, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 3}'::jsonb, 1.0, 1, null, false, 0, null) on conflict (item_id) do nothing;
update public.world_item_catalog set item_name = '순찰 언월도', description = '긴 자루에 반달 날을 단 칼. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["spearman"], "power": 12, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 5}'::jsonb where item_id = 'guard_spear';
update public.world_crafting_recipes set recipe_name = '순찰 언월도 만들기', description = '순찰 언월도을(를) 만든다.' where output_item = 'guard_spear';
update public.world_item_catalog set item_name = '뇌철 언월도', description = '긴 자루에 반달 날을 단 칼. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["spearman"], "power": 20, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 5}'::jsonb where item_id = 'thunder_glaive';
update public.world_crafting_recipes set recipe_name = '뇌철 언월도 만들기', description = '뇌철 언월도을(를) 만든다.' where output_item = 'thunder_glaive';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear4_a', '용린 언월도', 'weapon', 4, 'epic', '긴 자루에 반달 날을 단 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 3750, 1, 15, '{"strength": 20}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 28, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 10}'::jsonb, 0.2, 4, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear4_a', '용린 언월도 만들기', '용린 언월도을(를) 만든다.', 'w_spear4_a', 1, '{"spirit_core": 2, "steel_ingot": 4, "thunder_ore": 3}'::jsonb, 'smithing', 15, '철벽 고찰', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear4_a', 'armored', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear4_a', 'swarm', 13, 24, 0.004, 0.012, 0.05);
update public.world_item_catalog set item_name = '천뢰 언월도', description = '긴 자루에 반달 날을 단 칼. 근접 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["spearman"], "power": 38, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 15}'::jsonb where item_id = 'w_melee5_base';
update public.world_crafting_recipes set recipe_name = '천뢰 언월도 만들기', description = '천뢰 언월도을(를) 만든다.' where output_item = 'w_melee5_base';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear6_a', '갈대 물결 언월도', 'weapon', 6, 'legendary', '긴 자루에 반달 날을 단 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 8050, 1, 32, '{"strength": 38}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 48, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 18}'::jsonb, 0.05, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear6_a', '갈대 물결 언월도 만들기', '갈대 물결 언월도을(를) 만든다.', 'w_spear6_a', 1, '{"yoin_blood": 3, "banyo_scale": 3, "gwiheo_iron": 5, "steel_ingot": 4}'::jsonb, 'smithing', 32, '반요촌', null, 1, null, 1, null, 6, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear6_a', 'armored', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear6_a', 'swarm', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear6_a', 'boss', 31, 40, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear7_a', '먹비 언월도', 'weapon', 7, 'legendary', '긴 자루에 반달 날을 단 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 9453, 1, 42, '{"strength": 48}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 58, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 22}'::jsonb, 0.03, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear7_a', '먹비 언월도 만들기', '먹비 언월도을(를) 만든다.', 'w_spear7_a', 1, '{"steel_ingot": 4, "meokgwi_lump": 3, "bronze_scale_plate": 5, "drifting_name_thread": 3}'::jsonb, 'smithing', 42, '묵창 나루', null, 1, null, 1, null, 7, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear7_a', 'armored', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear7_a', 'swarm', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear7_a', 'boss', 41, 45, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear8_a', '새벽 종루 언월도', 'weapon', 8, 'legendary', '긴 자루에 반달 날을 단 칼. 근접 공격을 하며 주는 피해가 오른다.', false, true, 10871, 1, 47, '{"strength": 53}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 66, "trait": "근접", "weapon_type": "melee", "combat_damage_pct": 24}'::jsonb, 0.02, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear8_a', '새벽 종루 언월도 만들기', '새벽 종루 언월도을(를) 만든다.', 'w_spear8_a', 1, '{"lamp_wick_core": 3, "frost_bell_iron": 6, "white_night_frost": 3, "century_form_scrap": 2}'::jsonb, 'smithing', 47, '남문 수로 선착', null, 1, null, 1, null, 8, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear8_a', 'armored', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear8_a', 'swarm', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear8_a', 'boss', 46, 50, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear1_b', '무쇠 장창', 'weapon', 1, 'common', '긴 창으로 먼저 찌른다. 근접 공격을 하며 치명타가 잘 난다.', false, true, 80, 1, 1, '{}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 6, "trait": "근접", "weapon_type": "melee", "crit_pct": 4}'::jsonb, 1.0, 1, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear1_b', 'armored', 1, 6, 0.015, 0.03, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear1_b', 'swarm', 1, 6, 0.015, 0.03, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear2_b', '청동 장창', 'weapon', 2, 'uncommon', '긴 창으로 먼저 찌른다. 근접 공격을 하며 치명타가 잘 난다.', false, true, 230, 1, 5, '{"strength": 9}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 12, "trait": "근접", "weapon_type": "melee", "crit_pct": 8}'::jsonb, 0.72, 2, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear2_b', '청동 장창 만들기', '청동 장창을(를) 만든다.', 'w_spear2_b', 1, '{"lumber": 1, "iron_ingot": 3}'::jsonb, 'smithing', 5, '철벽 고찰', null, 1, null, 1, null, 2, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear2_b', 'armored', 3, 12, 0.012, 0.03, 0.06);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear2_b', 'swarm', 3, 12, 0.012, 0.03, 0.06);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear3_b', '청강 장창', 'weapon', 3, 'rare', '긴 창으로 먼저 찌른다. 근접 공격을 하며 치명타가 잘 난다.', false, true, 1650, 1, 10, '{"strength": 14}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 20, "trait": "근접", "weapon_type": "melee", "crit_pct": 12}'::jsonb, 0.42, 3, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear3_b', '청강 장창 만들기', '청강 장창을(를) 만든다.', 'w_spear3_b', 1, '{"steel_ingot": 2, "monster_core": 1, "reinforced_lumber": 1}'::jsonb, 'smithing', 10, '철벽 고찰', null, 1, null, 1, null, 3, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear3_b', 'armored', 8, 18, 0.006, 0.025, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear3_b', 'swarm', 8, 18, 0.006, 0.025, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear4_b', '비연 장창', 'weapon', 4, 'epic', '긴 창으로 먼저 찌른다. 근접 공격을 하며 치명타가 잘 난다.', false, true, 3750, 1, 15, '{"strength": 20}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 28, "trait": "근접", "weapon_type": "melee", "crit_pct": 16}'::jsonb, 0.2, 4, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear4_b', '비연 장창 만들기', '비연 장창을(를) 만든다.', 'w_spear4_b', 1, '{"spirit_core": 2, "steel_ingot": 4, "thunder_ore": 3}'::jsonb, 'smithing', 15, '철벽 고찰', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear4_b', 'armored', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear4_b', 'swarm', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear5_b', '일섬 장창', 'weapon', 5, 'legendary', '긴 창으로 먼저 찌른다. 근접 공격을 하며 치명타가 잘 난다.', false, true, 5600, 1, 20, '{"strength": 25}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 38, "trait": "근접", "weapon_type": "melee", "crit_pct": 20}'::jsonb, 0.08, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear5_b', '일섬 장창 만들기', '일섬 장창을(를) 만든다.', 'w_spear5_b', 1, '{"spirit_core": 3, "steel_ingot": 4, "thunder_ore": 5, "monster_core": 3}'::jsonb, 'smithing', 20, '무극 관성대', null, 1, null, 1, null, 5, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear5_b', 'armored', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear5_b', 'swarm', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear5_b', 'boss', 20, 40, 0, 0.01, 0.03);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear6_b', '백로 깃 장창', 'weapon', 6, 'legendary', '긴 창으로 먼저 찌른다. 근접 공격을 하며 치명타가 잘 난다.', false, true, 8050, 1, 32, '{"strength": 38}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 48, "trait": "근접", "weapon_type": "melee", "crit_pct": 24}'::jsonb, 0.05, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear6_b', '백로 깃 장창 만들기', '백로 깃 장창을(를) 만든다.', 'w_spear6_b', 1, '{"yoin_blood": 3, "gwiheo_iron": 5, "steel_ingot": 3, "oblivion_crystal": 2}'::jsonb, 'smithing', 32, '반요촌', null, 1, null, 1, null, 6, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear6_b', 'armored', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear6_b', 'swarm', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear6_b', 'boss', 31, 40, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear7_b', '이름 꿰는 장창', 'weapon', 7, 'legendary', '긴 창으로 먼저 찌른다. 근접 공격을 하며 치명타가 잘 난다.', false, true, 9453, 1, 42, '{"strength": 48}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 58, "trait": "근접", "weapon_type": "melee", "crit_pct": 29}'::jsonb, 0.03, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear7_b', '이름 꿰는 장창 만들기', '이름 꿰는 장창을(를) 만든다.', 'w_spear7_b', 1, '{"steel_ingot": 3, "register_slip": 2, "bronze_scale_plate": 5, "drifting_name_thread": 3}'::jsonb, 'smithing', 42, '묵창 나루', null, 1, null, 1, null, 7, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear7_b', 'armored', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear7_b', 'swarm', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear7_b', 'boss', 41, 45, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_spear8_b', '여명 장창', 'weapon', 8, 'legendary', '긴 창으로 먼저 찌른다. 근접 공격을 하며 치명타가 잘 난다.', false, true, 10871, 1, 47, '{"strength": 53}'::jsonb, null, null, '{"jobs": ["spearman"], "power": 66, "trait": "근접", "weapon_type": "melee", "crit_pct": 32}'::jsonb, 0.02, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_spear8_b', '여명 장창 만들기', '여명 장창을(를) 만든다.', 'w_spear8_b', 1, '{"lamp_wick_core": 3, "frost_bell_iron": 5, "white_night_frost": 2, "century_form_scrap": 4}'::jsonb, 'smithing', 47, '남문 수로 선착', null, 1, null, 1, null, 8, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear8_b', 'armored', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear8_b', 'swarm', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_spear8_b', 'boss', 46, 50, 0, 0.006, 0.02);
update public.world_item_catalog set item_name = '매눈 각궁', description = '뿔과 힘줄로 만든 활. 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["scout"], "power": 6, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 4, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged1_keen';
update public.world_crafting_recipes set recipe_name = '매눈 각궁 만들기', description = '매눈 각궁을(를) 만든다.' where output_item = 'w_ranged1_keen';
update public.world_item_catalog set item_name = '학익 각궁', description = '뿔과 힘줄로 만든 활. 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["scout"], "power": 12, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 8, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged2_keen';
update public.world_crafting_recipes set recipe_name = '학익 각궁 만들기', description = '학익 각궁을(를) 만든다.' where output_item = 'w_ranged2_keen';
update public.world_item_catalog set item_name = '천리 각궁', description = '뿔과 힘줄로 만든 활. 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["scout"], "power": 20, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 12, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged3_keen';
update public.world_crafting_recipes set recipe_name = '천리 각궁 만들기', description = '천리 각궁을(를) 만든다.' where output_item = 'w_ranged3_keen';
update public.world_item_catalog set item_name = '관일 각궁', description = '뿔과 힘줄로 만든 활. 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["scout"], "power": 28, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 16, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged4_keen';
update public.world_crafting_recipes set recipe_name = '관일 각궁 만들기', description = '관일 각궁을(를) 만든다.' where output_item = 'w_ranged4_keen';
update public.world_item_catalog set item_name = '성시 각궁', description = '뿔과 힘줄로 만든 활. 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["scout"], "power": 38, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 20, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged5_keen';
update public.world_crafting_recipes set recipe_name = '성시 각궁 만들기', description = '성시 각궁을(를) 만든다.' where output_item = 'w_ranged5_keen';
update public.world_item_catalog set item_name = '백로 깃 각궁', description = '뿔과 힘줄로 만든 활. 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["scout"], "power": 48, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 24, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged6_keen';
update public.world_crafting_recipes set recipe_name = '백로 깃 각궁 만들기', description = '백로 깃 각궁을(를) 만든다.' where output_item = 'w_ranged6_keen';
update public.world_item_catalog set item_name = '까마귀 깃 각궁', description = '뿔과 힘줄로 만든 활. 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["scout"], "power": 58, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 29, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged7_keen';
update public.world_crafting_recipes set recipe_name = '까마귀 깃 각궁 만들기', description = '까마귀 깃 각궁을(를) 만든다.' where output_item = 'w_ranged7_keen';
update public.world_item_catalog set item_name = '별 쏘는 각궁', description = '뿔과 힘줄로 만든 활. 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["scout"], "power": 66, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 32, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged8_keen';
update public.world_crafting_recipes set recipe_name = '별 쏘는 각궁 만들기', description = '별 쏘는 각궁을(를) 만든다.' where output_item = 'w_ranged8_keen';
update public.world_item_catalog set item_name = '박달 쇠뇌', description = '틀에 걸어 쏘는 활(편전을 쓴다). 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["scout"], "power": 6, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 3, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged1_heavy';
update public.world_crafting_recipes set recipe_name = '박달 쇠뇌 만들기', description = '박달 쇠뇌을(를) 만든다.' where output_item = 'w_ranged1_heavy';
update public.world_item_catalog set item_name = '철태 쇠뇌', description = '틀에 걸어 쏘는 활(편전을 쓴다). 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["scout"], "power": 12, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 5, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged2_heavy';
update public.world_crafting_recipes set recipe_name = '철태 쇠뇌 만들기', description = '철태 쇠뇌을(를) 만든다.' where output_item = 'w_ranged2_heavy';
update public.world_item_catalog set item_name = '수향 쇠뇌', description = '틀에 걸어 쏘는 활(편전을 쓴다). 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["scout"], "power": 12, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 5, "ammo": "ammo_dart"}'::jsonb where item_id = 'reed_crossbow';
update public.world_crafting_recipes set recipe_name = '수향 쇠뇌 만들기', description = '수향 쇠뇌을(를) 만든다.' where output_item = 'reed_crossbow';
update public.world_item_catalog set item_name = '연발 쇠뇌', description = '틀에 걸어 쏘는 활(편전을 쓴다). 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["scout"], "power": 20, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 5, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged3_heavy';
update public.world_crafting_recipes set recipe_name = '연발 쇠뇌 만들기', description = '연발 쇠뇌을(를) 만든다.' where output_item = 'w_ranged3_heavy';
update public.world_item_catalog set item_name = '팔우 쇠뇌', description = '틀에 걸어 쏘는 활(편전을 쓴다). 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["scout"], "power": 28, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 10, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged4_heavy';
update public.world_crafting_recipes set recipe_name = '팔우 쇠뇌 만들기', description = '팔우 쇠뇌을(를) 만든다.' where output_item = 'w_ranged4_heavy';
update public.world_item_catalog set item_name = '천균 쇠뇌', description = '틀에 걸어 쏘는 활(편전을 쓴다). 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["scout"], "power": 38, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 15, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged5_heavy';
update public.world_crafting_recipes set recipe_name = '천균 쇠뇌 만들기', description = '천균 쇠뇌을(를) 만든다.' where output_item = 'w_ranged5_heavy';
update public.world_item_catalog set item_name = '해신 쇠뇌', description = '틀에 걸어 쏘는 활(편전을 쓴다). 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["scout"], "power": 48, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 18, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged6_heavy';
update public.world_crafting_recipes set recipe_name = '해신 쇠뇌 만들기', description = '해신 쇠뇌을(를) 만든다.' where output_item = 'w_ranged6_heavy';
update public.world_item_catalog set item_name = '명부 탑 쇠뇌', description = '틀에 걸어 쏘는 활(편전을 쓴다). 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["scout"], "power": 58, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 22, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged7_heavy';
update public.world_crafting_recipes set recipe_name = '명부 탑 쇠뇌 만들기', description = '명부 탑 쇠뇌을(를) 만든다.' where output_item = 'w_ranged7_heavy';
update public.world_item_catalog set item_name = '종루 들보 쇠뇌', description = '틀에 걸어 쏘는 활(편전을 쓴다). 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["scout"], "power": 66, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 24, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged8_heavy';
update public.world_crafting_recipes set recipe_name = '종루 들보 쇠뇌 만들기', description = '종루 들보 쇠뇌을(를) 만든다.' where output_item = 'w_ranged8_heavy';
update public.world_item_catalog set item_name = '대나무 단궁', description = '짧고 가벼운 활. 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["tamer"], "power": 6, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 3, "ammo": "ammo_arrow"}'::jsonb where item_id = 'short_bow';
update public.world_crafting_recipes set recipe_name = '대나무 단궁 만들기', description = '대나무 단궁을(를) 만든다.' where output_item = 'short_bow';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_tamer2_a', '물버들 단궁', 'weapon', 2, 'uncommon', '짧고 가벼운 활. 원거리 공격을 하며 주는 피해가 오른다.', false, true, 370, 1, 5, '{"agility": 9}'::jsonb, null, null, '{"jobs": ["tamer"], "power": 12, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 5, "ammo": "ammo_arrow"}'::jsonb, 0.72, 2, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_tamer2_a', '물버들 단궁 만들기', '물버들 단궁을(를) 만든다.', 'w_tamer2_a', 1, '{"lumber": 2, "river_reed": 4, "talisman_thread": 2}'::jsonb, 'carpentry', 5, '구름나루', null, 1, null, 1, null, 2, 0) on conflict (recipe_id) do nothing;
update public.world_item_catalog set item_name = '성진 단궁', description = '짧고 가벼운 활. 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["tamer"], "power": 20, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 5, "ammo": "ammo_arrow"}'::jsonb where item_id = 'star_bow';
update public.world_crafting_recipes set recipe_name = '성진 단궁 만들기', description = '성진 단궁을(를) 만든다.' where output_item = 'star_bow';
update public.world_item_catalog set item_name = '흑룡 단궁', description = '짧고 가벼운 활. 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["tamer"], "power": 28, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 10, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged4_base';
update public.world_crafting_recipes set recipe_name = '흑룡 단궁 만들기', description = '흑룡 단궁을(를) 만든다.' where output_item = 'w_ranged4_base';
update public.world_item_catalog set item_name = '사일 단궁', description = '짧고 가벼운 활. 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["tamer"], "power": 38, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 15, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged5_base';
update public.world_crafting_recipes set recipe_name = '사일 단궁 만들기', description = '사일 단궁을(를) 만든다.' where output_item = 'w_ranged5_base';
update public.world_item_catalog set item_name = '갈대 단궁', description = '짧고 가벼운 활. 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["tamer"], "power": 48, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 18, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged6_base';
update public.world_crafting_recipes set recipe_name = '갈대 단궁 만들기', description = '갈대 단궁을(를) 만든다.' where output_item = 'w_ranged6_base';
update public.world_item_catalog set item_name = '흑단 단궁', description = '짧고 가벼운 활. 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["tamer"], "power": 58, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 22, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged7_base';
update public.world_crafting_recipes set recipe_name = '흑단 단궁 만들기', description = '흑단 단궁을(를) 만든다.' where output_item = 'w_ranged7_base';
update public.world_item_catalog set item_name = '멈춘 화살 단궁', description = '짧고 가벼운 활. 원거리 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["tamer"], "power": 66, "trait": "원거리", "weapon_type": "ranged", "combat_damage_pct": 24, "ammo": "ammo_arrow"}'::jsonb where item_id = 'w_ranged8_base';
update public.world_crafting_recipes set recipe_name = '멈춘 화살 단궁 만들기', description = '멈춘 화살 단궁을(를) 만든다.' where output_item = 'w_ranged8_base';
update public.world_item_catalog set item_name = '소리 없는 취관', description = '대롱으로 불어 쏜다(편전을 쓴다). 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["tamer"], "power": 6, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 4, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged1_silent';
update public.world_crafting_recipes set recipe_name = '소리 없는 취관 만들기', description = '소리 없는 취관을(를) 만든다.' where output_item = 'w_ranged1_silent';
update public.world_item_catalog set item_name = '갈대 취관', description = '대롱으로 불어 쏜다(편전을 쓴다). 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["tamer"], "power": 12, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 8, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged2_silent';
update public.world_crafting_recipes set recipe_name = '갈대 취관 만들기', description = '갈대 취관을(를) 만든다.' where output_item = 'w_ranged2_silent';
update public.world_item_catalog set item_name = '무음 취관', description = '대롱으로 불어 쏜다(편전을 쓴다). 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["tamer"], "power": 20, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 12, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged3_silent';
update public.world_crafting_recipes set recipe_name = '무음 취관 만들기', description = '무음 취관을(를) 만든다.' where output_item = 'w_ranged3_silent';
update public.world_item_catalog set item_name = '월영 취관', description = '대롱으로 불어 쏜다(편전을 쓴다). 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["tamer"], "power": 28, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 16, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged4_silent';
update public.world_crafting_recipes set recipe_name = '월영 취관 만들기', description = '월영 취관을(를) 만든다.' where output_item = 'w_ranged4_silent';
update public.world_item_catalog set item_name = '허공 취관', description = '대롱으로 불어 쏜다(편전을 쓴다). 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["tamer"], "power": 38, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 20, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged5_silent';
update public.world_crafting_recipes set recipe_name = '허공 취관 만들기', description = '허공 취관을(를) 만든다.' where output_item = 'w_ranged5_silent';
update public.world_item_catalog set item_name = '숨 죽인 취관', description = '대롱으로 불어 쏜다(편전을 쓴다). 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["tamer"], "power": 48, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 24, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged6_silent';
update public.world_crafting_recipes set recipe_name = '숨 죽인 취관 만들기', description = '숨 죽인 취관을(를) 만든다.' where output_item = 'w_ranged6_silent';
update public.world_item_catalog set item_name = '붓대 취관', description = '대롱으로 불어 쏜다(편전을 쓴다). 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["tamer"], "power": 58, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 29, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged7_silent';
update public.world_crafting_recipes set recipe_name = '붓대 취관 만들기', description = '붓대 취관을(를) 만든다.' where output_item = 'w_ranged7_silent';
update public.world_item_catalog set item_name = '등롱 대 취관', description = '대롱으로 불어 쏜다(편전을 쓴다). 원거리 공격을 하며 치명타가 잘 난다.', equipment_traits = '{"jobs": ["tamer"], "power": 66, "trait": "원거리", "weapon_type": "ranged", "crit_pct": 32, "ammo": "ammo_dart"}'::jsonb where item_id = 'w_ranged8_silent';
update public.world_crafting_recipes set recipe_name = '등롱 대 취관 만들기', description = '등롱 대 취관을(를) 만든다.' where output_item = 'w_ranged8_silent';
update public.world_item_catalog set item_name = '영령 방울', description = '흔들어 요기를 흩는 방울. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["exorcist"], "power": 6, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 3}'::jsonb where item_id = 'spirit_bell';
update public.world_crafting_recipes set recipe_name = '영령 방울 만들기', description = '영령 방울을(를) 만든다.' where output_item = 'spirit_bell';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_exo2_a', '청동 영령 방울', 'weapon', 2, 'uncommon', '흔들어 요기를 흩는 방울. 술법 공격을 하며 주는 피해가 오른다.', false, true, 600, 1, 5, '{"spirit_affinity": 9}'::jsonb, null, null, '{"jobs": ["exorcist"], "power": 12, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 5}'::jsonb, 0.72, 2, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_exo2_a', '청동 영령 방울 만들기', '청동 영령 방울을(를) 만든다.', 'w_exo2_a', 1, '{"fine_paper": 3, "ward_fragment": 2, "talisman_thread": 2}'::jsonb, 'artifice', 5, '장서각 지하서고', null, 1, null, 1, null, 2, 0) on conflict (recipe_id) do nothing;
update public.world_item_catalog set item_name = '천문 방울', description = '흔들어 요기를 흩는 방울. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["exorcist"], "power": 20, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 5}'::jsonb where item_id = 'star_mirror';
update public.world_crafting_recipes set recipe_name = '천문 방울 만들기', description = '천문 방울을(를) 만든다.' where output_item = 'star_mirror';
update public.world_item_catalog set item_name = '현무 방울', description = '흔들어 요기를 흩는 방울. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["exorcist"], "power": 28, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 10}'::jsonb where item_id = 'w_magic4_base';
update public.world_crafting_recipes set recipe_name = '현무 방울 만들기', description = '현무 방울을(를) 만든다.' where output_item = 'w_magic4_base';
update public.world_item_catalog set item_name = '태극 방울', description = '흔들어 요기를 흩는 방울. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["exorcist"], "power": 38, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 15}'::jsonb where item_id = 'w_magic5_base';
update public.world_crafting_recipes set recipe_name = '태극 방울 만들기', description = '태극 방울을(를) 만든다.' where output_item = 'w_magic5_base';
update public.world_item_catalog set item_name = '거꾸로 방울', description = '흔들어 요기를 흩는 방울. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["exorcist"], "power": 48, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 18}'::jsonb where item_id = 'w_magic6_base';
update public.world_crafting_recipes set recipe_name = '거꾸로 방울 만들기', description = '거꾸로 방울을(를) 만든다.' where output_item = 'w_magic6_base';
update public.world_item_catalog set item_name = '명부 방울', description = '흔들어 요기를 흩는 방울. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["exorcist"], "power": 58, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 22}'::jsonb where item_id = 'w_magic7_base';
update public.world_crafting_recipes set recipe_name = '명부 방울 만들기', description = '명부 방울을(를) 만든다.' where output_item = 'w_magic7_base';
update public.world_item_catalog set item_name = '일곱 자리 방울', description = '흔들어 요기를 흩는 방울. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["exorcist"], "power": 66, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 24}'::jsonb where item_id = 'w_magic8_base';
update public.world_crafting_recipes set recipe_name = '일곱 자리 방울 만들기', description = '일곱 자리 방울을(를) 만든다.' where output_item = 'w_magic8_base';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_exo1_b', '구리 법경', 'weapon', 1, 'common', '요괴를 비추는 거울. 술법 공격을 하며 치명타가 잘 난다.', false, true, 80, 1, 1, '{}'::jsonb, null, null, '{"jobs": ["exorcist"], "power": 6, "trait": "술법", "weapon_type": "magic", "crit_pct": 4}'::jsonb, 1.0, 1, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo1_b', 'spectral', 1, 6, 0.015, 0.03, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo1_b', 'warded', 1, 6, 0.015, 0.03, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo1_b', 'seal_breaker', 1, 6, 0.015, 0.03, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_exo2_b', '청동 법경', 'weapon', 2, 'uncommon', '요괴를 비추는 거울. 술법 공격을 하며 치명타가 잘 난다.', false, true, 470, 1, 5, '{"spirit_affinity": 9}'::jsonb, null, null, '{"jobs": ["exorcist"], "power": 12, "trait": "술법", "weapon_type": "magic", "crit_pct": 8}'::jsonb, 0.72, 2, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_exo2_b', '청동 법경 만들기', '청동 법경을(를) 만든다.', 'w_exo2_b', 1, '{"seal_paper": 2, "spirit_glass": 2}'::jsonb, 'artifice', 5, '철벽 고찰', null, 1, null, 1, null, 2, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo2_b', 'spectral', 3, 12, 0.012, 0.03, 0.06);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo2_b', 'warded', 3, 12, 0.012, 0.03, 0.06);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo2_b', 'seal_breaker', 3, 12, 0.012, 0.03, 0.06);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_exo3_b', '성진 법경', 'weapon', 3, 'rare', '요괴를 비추는 거울. 술법 공격을 하며 치명타가 잘 난다.', false, true, 1600, 1, 10, '{"spirit_affinity": 14}'::jsonb, null, null, '{"jobs": ["exorcist"], "power": 20, "trait": "술법", "weapon_type": "magic", "crit_pct": 12}'::jsonb, 0.42, 3, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_exo3_b', '성진 법경 만들기', '성진 법경을(를) 만든다.', 'w_exo3_b', 1, '{"rune_plate": 1, "mirror_shard": 2, "spirit_glass": 1}'::jsonb, 'artifice', 10, '철벽 고찰', null, 1, null, 1, null, 3, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo3_b', 'spectral', 8, 18, 0.006, 0.025, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo3_b', 'warded', 8, 18, 0.006, 0.025, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo3_b', 'seal_breaker', 8, 18, 0.006, 0.025, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_exo4_b', '흑룡 법경', 'weapon', 4, 'epic', '요괴를 비추는 거울. 술법 공격을 하며 치명타가 잘 난다.', false, true, 4150, 1, 15, '{"spirit_affinity": 20}'::jsonb, null, null, '{"jobs": ["exorcist"], "power": 28, "trait": "술법", "weapon_type": "magic", "crit_pct": 16}'::jsonb, 0.2, 4, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_exo4_b', '흑룡 법경 만들기', '흑룡 법경을(를) 만든다.', 'w_exo4_b', 1, '{"star_sand": 3, "rune_plate": 3, "spirit_core": 2}'::jsonb, 'artifice', 15, '철벽 고찰', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo4_b', 'spectral', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo4_b', 'warded', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo4_b', 'seal_breaker', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_exo5_b', '개천 법경', 'weapon', 5, 'legendary', '요괴를 비추는 거울. 술법 공격을 하며 치명타가 잘 난다.', false, true, 6550, 1, 20, '{"spirit_affinity": 25}'::jsonb, null, null, '{"jobs": ["exorcist"], "power": 38, "trait": "술법", "weapon_type": "magic", "crit_pct": 20}'::jsonb, 0.08, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_exo5_b', '개천 법경 만들기', '개천 법경을(를) 만든다.', 'w_exo5_b', 1, '{"star_sand": 4, "rune_plate": 4, "spirit_core": 3, "mirror_shard": 3}'::jsonb, 'artifice', 20, '무극 관성대', null, 1, null, 1, null, 5, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo5_b', 'spectral', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo5_b', 'warded', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo5_b', 'seal_breaker', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo5_b', 'boss', 20, 40, 0, 0.01, 0.03);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_exo6_b', '귀허 법경', 'weapon', 6, 'legendary', '요괴를 비추는 거울. 술법 공격을 하며 치명타가 잘 난다.', false, true, 8050, 1, 32, '{"spirit_affinity": 38}'::jsonb, null, null, '{"jobs": ["exorcist"], "power": 48, "trait": "술법", "weapon_type": "magic", "crit_pct": 24}'::jsonb, 0.05, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_exo6_b', '귀허 법경 만들기', '귀허 법경을(를) 만든다.', 'w_exo6_b', 1, '{"yoin_blood": 3, "mirror_shard": 3, "moonless_silk": 2, "oblivion_crystal": 5}'::jsonb, 'artifice', 32, '반요촌', null, 1, null, 1, null, 6, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo6_b', 'spectral', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo6_b', 'warded', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo6_b', 'seal_breaker', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo6_b', 'boss', 31, 40, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_exo7_b', '먹빛 법경', 'weapon', 7, 'legendary', '요괴를 비추는 거울. 술법 공격을 하며 치명타가 잘 난다.', false, true, 9453, 1, 42, '{"spirit_affinity": 48}'::jsonb, null, null, '{"jobs": ["exorcist"], "power": 58, "trait": "술법", "weapon_type": "magic", "crit_pct": 29}'::jsonb, 0.03, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_exo7_b', '먹빛 법경 만들기', '먹빛 법경을(를) 만든다.', 'w_exo7_b', 1, '{"blank_hanji": 5, "mirror_shard": 3, "mukchang_ink": 2, "drifting_name_thread": 3}'::jsonb, 'artifice', 42, '묵창 나루', null, 1, null, 1, null, 7, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo7_b', 'spectral', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo7_b', 'warded', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo7_b', 'seal_breaker', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo7_b', 'boss', 41, 45, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_exo8_b', '첫 불씨 법경', 'weapon', 8, 'legendary', '요괴를 비추는 거울. 술법 공격을 하며 치명타가 잘 난다.', false, true, 10871, 1, 47, '{"spirit_affinity": 53}'::jsonb, null, null, '{"jobs": ["exorcist"], "power": 66, "trait": "술법", "weapon_type": "magic", "crit_pct": 32}'::jsonb, 0.02, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_exo8_b', '첫 불씨 법경 만들기', '첫 불씨 법경을(를) 만든다.', 'w_exo8_b', 1, '{"king_ember_ash": 5, "lamp_wick_core": 3, "white_night_frost": 3, "bleached_lantern_paper": 3}'::jsonb, 'artifice', 47, '남문 수로 선착', null, 1, null, 1, null, 8, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo8_b', 'spectral', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo8_b', 'warded', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo8_b', 'seal_breaker', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_exo8_b', 'boss', 46, 50, 0, 0.006, 0.02);
update public.world_item_catalog set item_name = '무쇠 금강령', description = '울려 기운을 묶는 금강령. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["sealmaster"], "power": 6, "trait": "술법", "weapon_type": "magic", "evasion_pct": 1.5, "presence": -6}'::jsonb where item_id = 'w_magic1_heavy';
update public.world_crafting_recipes set recipe_name = '무쇠 금강령 만들기', description = '무쇠 금강령을(를) 만든다.' where output_item = 'w_magic1_heavy';
update public.world_item_catalog set item_name = '청동 금강령', description = '울려 기운을 묶는 금강령. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["sealmaster"], "power": 12, "trait": "술법", "weapon_type": "magic", "evasion_pct": 3, "presence": -12}'::jsonb where item_id = 'w_magic2_heavy';
update public.world_crafting_recipes set recipe_name = '청동 금강령 만들기', description = '청동 금강령을(를) 만든다.' where output_item = 'w_magic2_heavy';
update public.world_item_catalog set item_name = '뇌문 금강령', description = '울려 기운을 묶는 금강령. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["sealmaster"], "power": 20, "trait": "술법", "weapon_type": "magic", "evasion_pct": 4.5, "presence": -18}'::jsonb where item_id = 'w_magic3_heavy';
update public.world_crafting_recipes set recipe_name = '뇌문 금강령 만들기', description = '뇌문 금강령을(를) 만든다.' where output_item = 'w_magic3_heavy';
update public.world_item_catalog set item_name = '진령 금강령', description = '울려 기운을 묶는 금강령. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["sealmaster"], "power": 28, "trait": "술법", "weapon_type": "magic", "evasion_pct": 6, "presence": -24}'::jsonb where item_id = 'w_magic4_heavy';
update public.world_crafting_recipes set recipe_name = '진령 금강령 만들기', description = '진령 금강령을(를) 만든다.' where output_item = 'w_magic4_heavy';
update public.world_item_catalog set item_name = '개천 금강령', description = '울려 기운을 묶는 금강령. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["sealmaster"], "power": 38, "trait": "술법", "weapon_type": "magic", "evasion_pct": 7.5, "presence": -30}'::jsonb where item_id = 'w_magic5_heavy';
update public.world_crafting_recipes set recipe_name = '개천 금강령 만들기', description = '개천 금강령을(를) 만든다.' where output_item = 'w_magic5_heavy';
update public.world_item_catalog set item_name = '귀허 금강령', description = '울려 기운을 묶는 금강령. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["sealmaster"], "power": 48, "trait": "술법", "weapon_type": "magic", "evasion_pct": 9, "presence": -36}'::jsonb where item_id = 'w_magic6_heavy';
update public.world_crafting_recipes set recipe_name = '귀허 금강령 만들기', description = '귀허 금강령을(를) 만든다.' where output_item = 'w_magic6_heavy';
update public.world_item_catalog set item_name = '묵창 금강령', description = '울려 기운을 묶는 금강령. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["sealmaster"], "power": 58, "trait": "술법", "weapon_type": "magic", "evasion_pct": 11, "presence": -42}'::jsonb where item_id = 'w_magic7_heavy';
update public.world_crafting_recipes set recipe_name = '묵창 금강령 만들기', description = '묵창 금강령을(를) 만든다.' where output_item = 'w_magic7_heavy';
update public.world_item_catalog set item_name = '혼천 금강령', description = '울려 기운을 묶는 금강령. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["sealmaster"], "power": 66, "trait": "술법", "weapon_type": "magic", "evasion_pct": 12, "presence": -46}'::jsonb where item_id = 'w_magic8_heavy';
update public.world_crafting_recipes set recipe_name = '혼천 금강령 만들기', description = '혼천 금강령을(를) 만든다.' where output_item = 'w_magic8_heavy';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_seal1_b', '무쇠 봉인 사슬', 'weapon', 1, 'common', '봉인 부적을 꿴 사슬. 술법 공격을 하며 주는 피해가 오른다.', false, true, 90, 1, 1, '{}'::jsonb, null, null, '{"jobs": ["sealmaster"], "power": 6, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 3}'::jsonb, 1.0, 1, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_seal2_b', '청동 봉인 사슬', 'weapon', 2, 'uncommon', '봉인 부적을 꿴 사슬. 술법 공격을 하며 주는 피해가 오른다.', false, true, 600, 1, 5, '{"spirit_affinity": 9}'::jsonb, null, null, '{"jobs": ["sealmaster"], "power": 12, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 5}'::jsonb, 0.72, 2, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_seal2_b', '청동 봉인 사슬 만들기', '청동 봉인 사슬을(를) 만든다.', 'w_seal2_b', 1, '{"fine_paper": 3, "ward_fragment": 2, "talisman_thread": 2}'::jsonb, 'artifice', 5, '장서각 지하서고', null, 1, null, 1, null, 2, 0) on conflict (recipe_id) do nothing;
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_seal3_b', '청강 봉인 사슬', 'weapon', 3, 'rare', '봉인 부적을 꿴 사슬. 술법 공격을 하며 주는 피해가 오른다.', false, true, 1600, 1, 14, '{"spirit_affinity": 19}'::jsonb, null, null, '{"jobs": ["sealmaster"], "power": 20, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 5}'::jsonb, 0.42, 3, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_seal3_b', '청강 봉인 사슬 만들기', '청강 봉인 사슬을(를) 만든다.', 'w_seal3_b', 1, '{"star_sand": 2, "sealing_ink": 2, "spirit_core": 1, "mirror_shard": 2}'::jsonb, 'artifice', 14, '무극 관성대', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_seal4_b', '현무 봉인 사슬', 'weapon', 4, 'epic', '봉인 부적을 꿴 사슬. 술법 공격을 하며 주는 피해가 오른다.', false, true, 4150, 1, 15, '{"spirit_affinity": 20}'::jsonb, null, null, '{"jobs": ["sealmaster"], "power": 28, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 10}'::jsonb, 0.2, 4, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_seal4_b', '현무 봉인 사슬 만들기', '현무 봉인 사슬을(를) 만든다.', 'w_seal4_b', 1, '{"star_sand": 3, "rune_plate": 3, "spirit_core": 2}'::jsonb, 'artifice', 15, '철벽 고찰', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal4_b', 'spectral', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal4_b', 'warded', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal4_b', 'seal_breaker', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_seal5_b', '태을 봉인 사슬', 'weapon', 5, 'legendary', '봉인 부적을 꿴 사슬. 술법 공격을 하며 주는 피해가 오른다.', false, true, 6550, 1, 20, '{"spirit_affinity": 25}'::jsonb, null, null, '{"jobs": ["sealmaster"], "power": 38, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 15}'::jsonb, 0.08, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_seal5_b', '태을 봉인 사슬 만들기', '태을 봉인 사슬을(를) 만든다.', 'w_seal5_b', 1, '{"star_sand": 4, "rune_plate": 4, "spirit_core": 3, "mirror_shard": 3}'::jsonb, 'artifice', 20, '무극 관성대', null, 1, null, 1, null, 5, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal5_b', 'spectral', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal5_b', 'warded', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal5_b', 'seal_breaker', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal5_b', 'boss', 20, 40, 0, 0.01, 0.03);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_seal6_b', '귀허 봉인 사슬', 'weapon', 6, 'legendary', '봉인 부적을 꿴 사슬. 술법 공격을 하며 주는 피해가 오른다.', false, true, 8220, 1, 32, '{"spirit_affinity": 38}'::jsonb, null, null, '{"jobs": ["sealmaster"], "power": 48, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 18}'::jsonb, 0.05, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_seal6_b', '귀허 봉인 사슬 만들기', '귀허 봉인 사슬을(를) 만든다.', 'w_seal6_b', 1, '{"rune_plate": 3, "yoin_blood": 3, "inverted_incense": 5, "oblivion_crystal": 3}'::jsonb, 'artifice', 32, '반요촌', null, 1, null, 1, null, 6, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal6_b', 'spectral', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal6_b', 'warded', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal6_b', 'seal_breaker', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal6_b', 'boss', 31, 40, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_seal7_b', '먹 봉인 사슬', 'weapon', 7, 'legendary', '봉인 부적을 꿴 사슬. 술법 공격을 하며 주는 피해가 오른다.', false, true, 9453, 1, 42, '{"spirit_affinity": 48}'::jsonb, null, null, '{"jobs": ["sealmaster"], "power": 58, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 22}'::jsonb, 0.03, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_seal7_b', '먹 봉인 사슬 만들기', '먹 봉인 사슬을(를) 만든다.', 'w_seal7_b', 1, '{"rune_plate": 3, "mukchang_ink": 3, "register_slip": 5, "drifting_name_thread": 3}'::jsonb, 'artifice', 42, '묵창 나루', null, 1, null, 1, null, 7, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal7_b', 'spectral', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal7_b', 'warded', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal7_b', 'seal_breaker', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal7_b', 'boss', 41, 45, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_seal8_b', '일곱 자리 봉인 사슬', 'weapon', 8, 'legendary', '봉인 부적을 꿴 사슬. 술법 공격을 하며 주는 피해가 오른다.', false, true, 10871, 1, 47, '{"spirit_affinity": 53}'::jsonb, null, null, '{"jobs": ["sealmaster"], "power": 66, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 24}'::jsonb, 0.02, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_seal8_b', '일곱 자리 봉인 사슬 만들기', '일곱 자리 봉인 사슬을(를) 만든다.', 'w_seal8_b', 1, '{"lamp_wick_core": 3, "star_record_plate": 3, "white_night_frost": 3, "century_form_scrap": 5}'::jsonb, 'artifice', 47, '남문 수로 선착', null, 1, null, 1, null, 8, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal8_b', 'spectral', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal8_b', 'warded', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal8_b', 'seal_breaker', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_seal8_b', 'boss', 46, 50, 0, 0.006, 0.02);
update public.world_item_catalog set item_name = '먹 부채', description = '술식을 그린 부채. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["medic"], "power": 6, "trait": "술법", "weapon_type": "magic", "evasion_pct": 1.5, "presence": -6}'::jsonb where item_id = 'w_magic1_silent';
update public.world_crafting_recipes set recipe_name = '먹 부채 만들기', description = '먹 부채을(를) 만든다.' where output_item = 'w_magic1_silent';
update public.world_item_catalog set item_name = '연기 부채', description = '술식을 그린 부채. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["medic"], "power": 12, "trait": "술법", "weapon_type": "magic", "evasion_pct": 3, "presence": -12}'::jsonb where item_id = 'w_magic2_silent';
update public.world_crafting_recipes set recipe_name = '연기 부채 만들기', description = '연기 부채을(를) 만든다.' where output_item = 'w_magic2_silent';
update public.world_item_catalog set item_name = '결계 부채', description = '술식을 그린 부채. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["medic"], "power": 12, "trait": "술법", "weapon_type": "magic", "evasion_pct": 3, "presence": -12}'::jsonb where item_id = 'ward_fan';
update public.world_crafting_recipes set recipe_name = '결계 부채 만들기', description = '결계 부채을(를) 만든다.' where output_item = 'ward_fan';
update public.world_item_catalog set item_name = '몽환 부채', description = '술식을 그린 부채. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["medic"], "power": 20, "trait": "술법", "weapon_type": "magic", "evasion_pct": 4.5, "presence": -18}'::jsonb where item_id = 'w_magic3_silent';
update public.world_crafting_recipes set recipe_name = '몽환 부채 만들기', description = '몽환 부채을(를) 만든다.' where output_item = 'w_magic3_silent';
update public.world_item_catalog set item_name = '유령 부채', description = '술식을 그린 부채. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["medic"], "power": 28, "trait": "술법", "weapon_type": "magic", "evasion_pct": 6, "presence": -24}'::jsonb where item_id = 'w_magic4_silent';
update public.world_crafting_recipes set recipe_name = '유령 부채 만들기', description = '유령 부채을(를) 만든다.' where output_item = 'w_magic4_silent';
update public.world_item_catalog set item_name = '허무 부채', description = '술식을 그린 부채. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["medic"], "power": 38, "trait": "술법", "weapon_type": "magic", "evasion_pct": 7.5, "presence": -30}'::jsonb where item_id = 'w_magic5_silent';
update public.world_crafting_recipes set recipe_name = '허무 부채 만들기', description = '허무 부채을(를) 만든다.' where output_item = 'w_magic5_silent';
update public.world_item_catalog set item_name = '꺼진 등 부채', description = '술식을 그린 부채. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["medic"], "power": 48, "trait": "술법", "weapon_type": "magic", "evasion_pct": 9, "presence": -36}'::jsonb where item_id = 'w_magic6_silent';
update public.world_crafting_recipes set recipe_name = '꺼진 등 부채 만들기', description = '꺼진 등 부채을(를) 만든다.' where output_item = 'w_magic6_silent';
update public.world_item_catalog set item_name = '꺼진 붓 부채', description = '술식을 그린 부채. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["medic"], "power": 58, "trait": "술법", "weapon_type": "magic", "evasion_pct": 11, "presence": -42}'::jsonb where item_id = 'w_magic7_silent';
update public.world_crafting_recipes set recipe_name = '꺼진 붓 부채 만들기', description = '꺼진 붓 부채을(를) 만든다.' where output_item = 'w_magic7_silent';
update public.world_item_catalog set item_name = '꺼진 자리 부채', description = '술식을 그린 부채. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', equipment_traits = '{"jobs": ["medic"], "power": 66, "trait": "술법", "weapon_type": "magic", "evasion_pct": 12, "presence": -46}'::jsonb where item_id = 'w_magic8_silent';
update public.world_crafting_recipes set recipe_name = '꺼진 자리 부채 만들기', description = '꺼진 자리 부채을(를) 만든다.' where output_item = 'w_magic8_silent';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_medic1_b', '무쇠 침통', 'weapon', 1, 'common', '침과 약을 넣은 통. 술법 공격을 하며 주는 피해가 오른다.', false, true, 90, 1, 1, '{}'::jsonb, null, null, '{"jobs": ["medic"], "power": 6, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 3}'::jsonb, 1.0, 1, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_medic2_b', '청동 침통', 'weapon', 2, 'uncommon', '침과 약을 넣은 통. 술법 공격을 하며 주는 피해가 오른다.', false, true, 600, 1, 5, '{"spirit_affinity": 9}'::jsonb, null, null, '{"jobs": ["medic"], "power": 12, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 5}'::jsonb, 0.72, 2, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_medic2_b', '청동 침통 만들기', '청동 침통을(를) 만든다.', 'w_medic2_b', 1, '{"fine_paper": 3, "ward_fragment": 2, "talisman_thread": 2}'::jsonb, 'artifice', 5, '장서각 지하서고', null, 1, null, 1, null, 2, 0) on conflict (recipe_id) do nothing;
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_medic3_b', '은침 침통', 'weapon', 3, 'rare', '침과 약을 넣은 통. 술법 공격을 하며 주는 피해가 오른다.', false, true, 1600, 1, 14, '{"spirit_affinity": 19}'::jsonb, null, null, '{"jobs": ["medic"], "power": 20, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 5}'::jsonb, 0.42, 3, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_medic3_b', '은침 침통 만들기', '은침 침통을(를) 만든다.', 'w_medic3_b', 1, '{"star_sand": 2, "sealing_ink": 2, "spirit_core": 1, "mirror_shard": 2}'::jsonb, 'artifice', 14, '무극 관성대', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_medic4_b', '현무 침통', 'weapon', 4, 'epic', '침과 약을 넣은 통. 술법 공격을 하며 주는 피해가 오른다.', false, true, 4150, 1, 15, '{"spirit_affinity": 20}'::jsonb, null, null, '{"jobs": ["medic"], "power": 28, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 10}'::jsonb, 0.2, 4, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_medic4_b', '현무 침통 만들기', '현무 침통을(를) 만든다.', 'w_medic4_b', 1, '{"star_sand": 3, "rune_plate": 3, "spirit_core": 2}'::jsonb, 'artifice', 15, '철벽 고찰', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic4_b', 'spectral', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic4_b', 'warded', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic4_b', 'seal_breaker', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_medic5_b', '태을 침통', 'weapon', 5, 'legendary', '침과 약을 넣은 통. 술법 공격을 하며 주는 피해가 오른다.', false, true, 6550, 1, 20, '{"spirit_affinity": 25}'::jsonb, null, null, '{"jobs": ["medic"], "power": 38, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 15}'::jsonb, 0.08, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_medic5_b', '태을 침통 만들기', '태을 침통을(를) 만든다.', 'w_medic5_b', 1, '{"star_sand": 4, "rune_plate": 4, "spirit_core": 3, "mirror_shard": 3}'::jsonb, 'artifice', 20, '무극 관성대', null, 1, null, 1, null, 5, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic5_b', 'spectral', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic5_b', 'warded', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic5_b', 'seal_breaker', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic5_b', 'boss', 20, 40, 0, 0.01, 0.03);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_medic6_b', '갈대 침통', 'weapon', 6, 'legendary', '침과 약을 넣은 통. 술법 공격을 하며 주는 피해가 오른다.', false, true, 8220, 1, 32, '{"spirit_affinity": 38}'::jsonb, null, null, '{"jobs": ["medic"], "power": 48, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 18}'::jsonb, 0.05, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_medic6_b', '갈대 침통 만들기', '갈대 침통을(를) 만든다.', 'w_medic6_b', 1, '{"rune_plate": 3, "yoin_blood": 3, "inverted_incense": 5, "oblivion_crystal": 3}'::jsonb, 'artifice', 32, '반요촌', null, 1, null, 1, null, 6, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic6_b', 'spectral', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic6_b', 'warded', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic6_b', 'seal_breaker', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic6_b', 'boss', 31, 40, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_medic7_b', '먹 침통', 'weapon', 7, 'legendary', '침과 약을 넣은 통. 술법 공격을 하며 주는 피해가 오른다.', false, true, 9453, 1, 42, '{"spirit_affinity": 48}'::jsonb, null, null, '{"jobs": ["medic"], "power": 58, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 22}'::jsonb, 0.03, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_medic7_b', '먹 침통 만들기', '먹 침통을(를) 만든다.', 'w_medic7_b', 1, '{"rune_plate": 3, "mukchang_ink": 3, "register_slip": 5, "drifting_name_thread": 3}'::jsonb, 'artifice', 42, '묵창 나루', null, 1, null, 1, null, 7, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic7_b', 'spectral', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic7_b', 'warded', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic7_b', 'seal_breaker', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic7_b', 'boss', 41, 45, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_medic8_b', '등불 침통', 'weapon', 8, 'legendary', '침과 약을 넣은 통. 술법 공격을 하며 주는 피해가 오른다.', false, true, 10871, 1, 47, '{"spirit_affinity": 53}'::jsonb, null, null, '{"jobs": ["medic"], "power": 66, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 24}'::jsonb, 0.02, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_medic8_b', '등불 침통 만들기', '등불 침통을(를) 만든다.', 'w_medic8_b', 1, '{"lamp_wick_core": 3, "star_record_plate": 3, "white_night_frost": 3, "century_form_scrap": 5}'::jsonb, 'artifice', 47, '남문 수로 선착', null, 1, null, 1, null, 8, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic8_b', 'spectral', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic8_b', 'warded', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic8_b', 'seal_breaker', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_medic8_b', 'boss', 46, 50, 0, 0.006, 0.02);
update public.world_item_catalog set item_name = '복사 산가지', description = '셈을 놓는 산가지. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["formation"], "power": 6, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 3}'::jsonb where item_id = 'w_magic1_keen';
update public.world_crafting_recipes set recipe_name = '복사 산가지 만들기', description = '복사 산가지을(를) 만든다.' where output_item = 'w_magic1_keen';
update public.world_item_catalog set item_name = '팔괘 산가지', description = '셈을 놓는 산가지. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["formation"], "power": 12, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 5}'::jsonb where item_id = 'w_magic2_keen';
update public.world_crafting_recipes set recipe_name = '팔괘 산가지 만들기', description = '팔괘 산가지을(를) 만든다.' where output_item = 'w_magic2_keen';
update public.world_item_catalog set item_name = '북두 칠성 산가지', description = '셈을 놓는 산가지. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["formation"], "power": 20, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 5}'::jsonb where item_id = 'w_magic3_keen';
update public.world_crafting_recipes set recipe_name = '북두 칠성 산가지 만들기', description = '북두 칠성 산가지을(를) 만든다.' where output_item = 'w_magic3_keen';
update public.world_item_catalog set item_name = '천기 산가지', description = '셈을 놓는 산가지. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["formation"], "power": 28, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 10}'::jsonb where item_id = 'w_magic4_keen';
update public.world_crafting_recipes set recipe_name = '천기 산가지 만들기', description = '천기 산가지을(를) 만든다.' where output_item = 'w_magic4_keen';
update public.world_item_catalog set item_name = '천명 산가지', description = '셈을 놓는 산가지. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["formation"], "power": 38, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 15}'::jsonb where item_id = 'w_magic5_keen';
update public.world_crafting_recipes set recipe_name = '천명 산가지 만들기', description = '천명 산가지을(를) 만든다.' where output_item = 'w_magic5_keen';
update public.world_item_catalog set item_name = '망각 수정 산가지', description = '셈을 놓는 산가지. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["formation"], "power": 48, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 18}'::jsonb where item_id = 'w_magic6_keen';
update public.world_crafting_recipes set recipe_name = '망각 수정 산가지 만들기', description = '망각 수정 산가지을(를) 만든다.' where output_item = 'w_magic6_keen';
update public.world_item_catalog set item_name = '먹 번진 산가지', description = '셈을 놓는 산가지. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["formation"], "power": 58, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 22}'::jsonb where item_id = 'w_magic7_keen';
update public.world_crafting_recipes set recipe_name = '먹 번진 산가지 만들기', description = '먹 번진 산가지을(를) 만든다.' where output_item = 'w_magic7_keen';
update public.world_item_catalog set item_name = '임금 불씨 산가지', description = '셈을 놓는 산가지. 술법 공격을 하며 주는 피해가 오른다.', equipment_traits = '{"jobs": ["formation"], "power": 66, "trait": "술법", "weapon_type": "magic", "combat_damage_pct": 24}'::jsonb where item_id = 'w_magic8_keen';
update public.world_crafting_recipes set recipe_name = '임금 불씨 산가지 만들기', description = '임금 불씨 산가지을(를) 만든다.' where output_item = 'w_magic8_keen';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_form1_b', '대나무 나경', 'weapon', 1, 'common', '방위를 읽는 나경. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', false, true, 80, 1, 1, '{}'::jsonb, null, null, '{"jobs": ["formation"], "power": 6, "trait": "술법", "weapon_type": "magic", "evasion_pct": 1.5, "presence": -6}'::jsonb, 1.0, 1, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form1_b', 'spectral', 1, 6, 0.015, 0.03, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form1_b', 'warded', 1, 6, 0.015, 0.03, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form1_b', 'seal_breaker', 1, 6, 0.015, 0.03, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_form2_b', '청동 나경', 'weapon', 2, 'uncommon', '방위를 읽는 나경. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', false, true, 470, 1, 5, '{"spirit_affinity": 9}'::jsonb, null, null, '{"jobs": ["formation"], "power": 12, "trait": "술법", "weapon_type": "magic", "evasion_pct": 3, "presence": -12}'::jsonb, 0.72, 2, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_form2_b', '청동 나경 만들기', '청동 나경을(를) 만든다.', 'w_form2_b', 1, '{"seal_paper": 2, "spirit_glass": 2}'::jsonb, 'artifice', 5, '철벽 고찰', null, 1, null, 1, null, 2, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form2_b', 'spectral', 3, 12, 0.012, 0.03, 0.06);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form2_b', 'warded', 3, 12, 0.012, 0.03, 0.06);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form2_b', 'seal_breaker', 3, 12, 0.012, 0.03, 0.06);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_form3_b', '성진 나경', 'weapon', 3, 'rare', '방위를 읽는 나경. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', false, true, 1600, 1, 10, '{"spirit_affinity": 14}'::jsonb, null, null, '{"jobs": ["formation"], "power": 20, "trait": "술법", "weapon_type": "magic", "evasion_pct": 4.5, "presence": -18}'::jsonb, 0.42, 3, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_form3_b', '성진 나경 만들기', '성진 나경을(를) 만든다.', 'w_form3_b', 1, '{"rune_plate": 1, "mirror_shard": 2, "spirit_glass": 1}'::jsonb, 'artifice', 10, '철벽 고찰', null, 1, null, 1, null, 3, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form3_b', 'spectral', 8, 18, 0.006, 0.025, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form3_b', 'warded', 8, 18, 0.006, 0.025, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form3_b', 'seal_breaker', 8, 18, 0.006, 0.025, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_form4_b', '현무 나경', 'weapon', 4, 'epic', '방위를 읽는 나경. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', false, true, 4150, 1, 15, '{"spirit_affinity": 20}'::jsonb, null, null, '{"jobs": ["formation"], "power": 28, "trait": "술법", "weapon_type": "magic", "evasion_pct": 6, "presence": -24}'::jsonb, 0.2, 4, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_form4_b', '현무 나경 만들기', '현무 나경을(를) 만든다.', 'w_form4_b', 1, '{"star_sand": 2, "rune_plate": 3, "lantern_oil": 1, "spirit_core": 2}'::jsonb, 'artifice', 15, '철벽 고찰', null, 1, null, 1, null, 4, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form4_b', 'spectral', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form4_b', 'warded', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form4_b', 'seal_breaker', 13, 24, 0.004, 0.012, 0.05);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_form5_b', '태극 나경', 'weapon', 5, 'legendary', '방위를 읽는 나경. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', false, true, 7000, 1, 20, '{"spirit_affinity": 25}'::jsonb, null, null, '{"jobs": ["formation"], "power": 38, "trait": "술법", "weapon_type": "magic", "evasion_pct": 7.5, "presence": -30}'::jsonb, 0.08, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_form5_b', '태극 나경 만들기', '태극 나경을(를) 만든다.', 'w_form5_b', 1, '{"star_sand": 4, "rune_plate": 4, "spirit_core": 3, "mirror_shard": 3}'::jsonb, 'artifice', 20, '무극 관성대', null, 1, null, 1, null, 5, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form5_b', 'spectral', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form5_b', 'warded', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form5_b', 'seal_breaker', 20, 40, 0.002, 0.006, 0.03);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form5_b', 'boss', 20, 40, 0, 0.01, 0.03);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_form6_b', '무월 나경', 'weapon', 6, 'legendary', '방위를 읽는 나경. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', false, true, 8050, 1, 32, '{"spirit_affinity": 38}'::jsonb, null, null, '{"jobs": ["formation"], "power": 48, "trait": "술법", "weapon_type": "magic", "evasion_pct": 9, "presence": -36}'::jsonb, 0.05, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_form6_b', '무월 나경 만들기', '무월 나경을(를) 만든다.', 'w_form6_b', 1, '{"yoin_blood": 3, "spirit_core": 2, "moonless_silk": 3, "oblivion_crystal": 4}'::jsonb, 'artifice', 32, '반요촌', null, 1, null, 1, null, 6, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form6_b', 'spectral', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form6_b', 'warded', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form6_b', 'seal_breaker', 31, 40, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form6_b', 'boss', 31, 40, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_form7_b', '아홉 칸 나경', 'weapon', 7, 'legendary', '방위를 읽는 나경. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', false, true, 9453, 1, 42, '{"spirit_affinity": 48}'::jsonb, null, null, '{"jobs": ["formation"], "power": 58, "trait": "술법", "weapon_type": "magic", "evasion_pct": 11, "presence": -42}'::jsonb, 0.03, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_form7_b', '아홉 칸 나경 만들기', '아홉 칸 나경을(를) 만든다.', 'w_form7_b', 1, '{"meokbi_moss": 3, "spirit_core": 2, "meokbi_ebony": 4, "drifting_name_thread": 3}'::jsonb, 'artifice', 42, '묵창 나루', null, 1, null, 1, null, 7, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form7_b', 'spectral', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form7_b', 'warded', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form7_b', 'seal_breaker', 41, 45, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form7_b', 'boss', 41, 45, 0, 0.006, 0.02);
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id) values ('w_form8_b', '첫 관상대 나경', 'weapon', 8, 'legendary', '방위를 읽는 나경. 술법 공격을 하며 눈에 덜 띄고 잘 피한다.', false, true, 10871, 1, 47, '{"spirit_affinity": 53}'::jsonb, null, null, '{"jobs": ["formation"], "power": 66, "trait": "술법", "weapon_type": "magic", "evasion_pct": 12, "presence": -46}'::jsonb, 0.02, 5, null, false, 0, null) on conflict (item_id) do nothing;
insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values ('r_w_form8_b', '첫 관상대 나경 만들기', '첫 관상대 나경을(를) 만든다.', 'w_form8_b', 1, '{"lamp_wick_core": 3, "severed_lamp_oil": 6, "white_night_frost": 4, "red_shrine_lacquer": 2}'::jsonb, 'artifice', 47, '남문 수로 선착', null, 1, null, 1, null, 8, 0) on conflict (recipe_id) do nothing;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form8_b', 'spectral', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form8_b', 'warded', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form8_b', 'seal_breaker', 46, 50, 0.001, 0.004, 0.02);
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ('w_form8_b', 'boss', 46, 50, 0, 0.006, 0.02);
update public.world_item_catalog set equipment_traits = '{"jobs": ["artificer", "scout", "exorcist", "medic", "sealmaster", "analyst", "tamer", "bloodknight", "spearman", "formation"], "power": 58, "trait": "근접", "mz_j_stone": 10, "weapon_type": "melee", "combat_damage_pct": 22}'::jsonb where item_id = 'w_melee_mz';
update public.world_item_catalog set equipment_traits = '{"ammo": "ammo_arrow", "jobs": ["artificer", "scout", "exorcist", "medic", "sealmaster", "analyst", "tamer", "bloodknight", "spearman", "formation"], "power": 58, "trait": "원거리", "mz_j_wood": 10, "weapon_type": "ranged", "combat_damage_pct": 22}'::jsonb where item_id = 'w_ranged_mz';
update public.world_item_catalog set equipment_traits = '{"jobs": ["artificer", "scout", "exorcist", "medic", "sealmaster", "analyst", "tamer", "bloodknight", "spearman", "formation"], "power": 58, "trait": "술법", "mz_j_herb": 10, "weapon_type": "magic", "combat_damage_pct": 22}'::jsonb where item_id = 'w_magic_mz';
update public.world_item_catalog set equipment_traits = '{"jobs": ["artificer", "scout", "exorcist", "medic", "sealmaster", "analyst", "tamer", "bloodknight", "spearman", "formation"], "power": 66, "trait": "근접", "mz_j_stone": 10, "weapon_type": "melee", "combat_damage_pct": 24}'::jsonb where item_id = 'w_melee_mzl';
update public.world_item_catalog set equipment_traits = '{"ammo": "ammo_arrow", "jobs": ["artificer", "scout", "exorcist", "medic", "sealmaster", "analyst", "tamer", "bloodknight", "spearman", "formation"], "power": 66, "trait": "원거리", "mz_j_wood": 10, "weapon_type": "ranged", "combat_damage_pct": 24}'::jsonb where item_id = 'w_ranged_mzl';
update public.world_item_catalog set equipment_traits = '{"jobs": ["artificer", "scout", "exorcist", "medic", "sealmaster", "analyst", "tamer", "bloodknight", "spearman", "formation"], "power": 66, "trait": "술법", "mz_j_herb": 10, "weapon_type": "magic", "combat_damage_pct": 24}'::jsonb where item_id = 'w_magic_mzl';
set local yh.hq_sync = 'off';
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.rarity, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.minimum_level, i.required_stats, i.required_job, i.required_faction, public.world_item_hq_traits(i.equipment_traits), i.drop_rate_modifier, i.acquisition_difficulty, i.crafting_specialization, i.market_only, 1, i.item_id
  from public.world_item_catalog i where i.item_id = any(array['w_guard3_a', 'w_guard5_a', 'w_guard2_b', 'w_guard3_b', 'w_guard4_b', 'w_guard5_b', 'w_guard6_b', 'w_guard7_b', 'w_guard8_b', 'w_blood2_b', 'w_blood3_b', 'w_blood4_b', 'w_blood5_b', 'w_blood6_b', 'w_blood7_b', 'w_blood8_b', 'w_spear4_a', 'w_spear6_a', 'w_spear7_a', 'w_spear8_a', 'w_spear2_b', 'w_spear3_b', 'w_spear4_b', 'w_spear5_b', 'w_spear6_b', 'w_spear7_b', 'w_spear8_b', 'w_tamer2_a', 'w_exo2_a', 'w_exo2_b', 'w_exo3_b', 'w_exo4_b', 'w_exo5_b', 'w_exo6_b', 'w_exo7_b', 'w_exo8_b', 'w_seal2_b', 'w_seal3_b', 'w_seal4_b', 'w_seal5_b', 'w_seal6_b', 'w_seal7_b', 'w_seal8_b', 'w_medic2_b', 'w_medic3_b', 'w_medic4_b', 'w_medic5_b', 'w_medic6_b', 'w_medic7_b', 'w_medic8_b', 'w_form2_b', 'w_form3_b', 'w_form4_b', 'w_form5_b', 'w_form6_b', 'w_form7_b', 'w_form8_b']) on conflict (item_id) do nothing;
set local yh.hq_sync = 'on';

create or replace function pg_temp.yh_rekey_map(m jsonb, a text, b text) returns jsonb language sql immutable as $$
  select case when m ? a then (m - a) || jsonb_build_object(b, coalesce((m ->> b)::int, 0) + (m ->> a)::int) else m end
$$;

update public.world_characters set inventory = pg_temp.yh_rekey_map(inventory, 'ammo_bolt', 'ammo_dart') where inventory ? 'ammo_bolt';
update public.world_storage set items = pg_temp.yh_rekey_map(items, 'ammo_bolt', 'ammo_dart') where items ? 'ammo_bolt';
update public.world_letters set items = pg_temp.yh_rekey_map(items, 'ammo_bolt', 'ammo_dart') where jsonb_typeof(items) = 'object' and items ? 'ammo_bolt';
insert into public.world_overflow_items(owner_id, item_id, qty, source, created_at)
select owner_id, 'ammo_dart', qty, source, created_at from public.world_overflow_items where item_id = 'ammo_bolt'
on conflict (owner_id, item_id) do update set qty = public.world_overflow_items.qty + excluded.qty;
delete from public.world_overflow_items where item_id = 'ammo_bolt';
update public.world_trade_offers set item_id = 'ammo_dart' where item_id = 'ammo_bolt';
update public.world_user_commissions set item_id = 'ammo_dart' where item_id = 'ammo_bolt';
update public.world_party_loot_pool set item_id = 'ammo_dart' where item_id = 'ammo_bolt';
delete from public.world_shop_stock s where s.item_id = 'ammo_bolt' and exists (select 1 from public.world_shop_stock d where d.shop_id = s.shop_id and d.item_id = 'ammo_dart');
update public.world_shop_stock set item_id = 'ammo_dart' where item_id = 'ammo_bolt';
delete from public.world_crafting_recipes where output_item = 'ammo_bolt';
update public.world_item_catalog set description = '이제 쓰지 않는 쇠뇌살. 3.4.0부터 쇠뇌는 편전을 쓴다.', tradeable = false where item_id = 'ammo_bolt';

do $$
declare r record; give int;
begin
  for r in
    select c.owner_id, coalesce((c.inventory ->> 'ammo_arrow')::int, 0) arrows
      from public.world_characters c join public.world_character_equipment e on e.owner_id = c.owner_id and e.slot = 'weapon'
     where coalesce((select i.base_item_id from public.world_item_catalog i where i.item_id = e.item_id), e.item_id)
           in ('w_ranged1_heavy', 'w_ranged1_silent', 'w_ranged3_silent', 'w_ranged4_silent', 'w_ranged5_silent')
  loop
    give := least(100, r.arrows);
    if give > 0 then
      update public.world_characters set inventory = jsonb_strip_nulls(
          (inventory - 'ammo_arrow')
          || case when r.arrows - give > 0 then jsonb_build_object('ammo_arrow', r.arrows - give) else '{}'::jsonb end
          || jsonb_build_object('ammo_dart', coalesce((inventory ->> 'ammo_dart')::int, 0) + give))
       where owner_id = r.owner_id;
    end if;
  end loop;
end $$;

do $$
declare r record; tgt text; tgt_hq text; inv jsonb;
begin
  for r in
    select c.owner_id, c.job_key, e.item_id, i.tier, i.base_item_id is not null as hq, coalesce(i.base_item_id, i.item_id) base_id,
           case when i.equipment_traits ? 'crit_pct' then 'keen' when i.equipment_traits ? 'evasion_pct' then 'silent'
                when i.equipment_traits ? 'incoming_damage_pct' then 'heavy' else 'base' end as line
      from public.world_characters c
      join public.world_character_equipment e on e.owner_id = c.owner_id and e.slot = 'weapon'
      join public.world_item_catalog i on i.item_id = e.item_id
     where not (coalesce(i.equipment_traits -> 'jobs', '[]'::jsonb) ? c.job_key)
  loop
    select x.item_id into tgt from public.world_item_catalog x
     where x.category = 'weapon' and x.base_item_id is null and x.tier = r.tier and x.equipment_traits -> 'jobs' ? r.job_key
       and jsonb_array_length(x.equipment_traits -> 'jobs') = 1
     order by (case when x.equipment_traits ? 'crit_pct' then 'keen' when x.equipment_traits ? 'evasion_pct' then 'silent'
                    when x.equipment_traits ? 'incoming_damage_pct' then 'heavy' else 'base' end) = r.line desc, x.item_id
     limit 1;
    if tgt is null then continue; end if;
    tgt_hq := case when r.hq and exists (select 1 from public.world_item_catalog h where h.item_id = tgt || '_hq') then tgt || '_hq' else tgt end;
    select inventory into inv from public.world_characters where owner_id = r.owner_id for update;
    inv := case when coalesce((inv ->> r.item_id)::int, 0) > 1 then jsonb_set(inv, array[r.item_id], to_jsonb((inv ->> r.item_id)::int - 1)) else inv - r.item_id end;
    inv := jsonb_set(inv, array[tgt_hq], to_jsonb(coalesce((inv ->> tgt_hq)::int, 0) + 1));
    update public.world_characters set inventory = inv where owner_id = r.owner_id;
    update public.world_character_equipment set item_id = tgt_hq where owner_id = r.owner_id and slot = 'weapon';
    if not exists (select 1 from public.world_item_durability where owner_id = r.owner_id and item_id = tgt_hq) then
      update public.world_item_durability set item_id = tgt_hq where owner_id = r.owner_id and item_id = r.item_id;
    end if;
    if not exists (select 1 from public.world_gear_enhance where owner_id = r.owner_id and item_id = tgt_hq) then
      update public.world_gear_enhance set item_id = tgt_hq where owner_id = r.owner_id and item_id = r.item_id;
    end if;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.owner_id, 'guide', '무기를 바꿔 드렸습니다',
            '무기 개편으로 끼고 있던 ' || (select item_name from public.world_item_catalog where item_id = r.item_id) || '을(를) 같은 단계의 직업 무기 '
              || (select item_name from public.world_item_catalog where item_id = tgt_hq) || '(으)로 바꿔 끼워 드렸습니다. 강화와 내구도는 그대로입니다.',
            jsonb_build_object('tip', 'weapon_swap', 'from', r.item_id, 'to', tgt_hq));
  end loop;
end $$;

create or replace function public.world_weapon_rules() returns jsonb language sql immutable as $$
  select jsonb_build_object('drop_job_mul', 4, 'ammo', jsonb_build_object('arrow', jsonb_build_array('각궁', '단궁'), 'dart', jsonb_build_array('쇠뇌', '취관')),
    'kinds', jsonb_build_object('base', '기본 — 주는 피해', 'heavy', '묵직 — 이목·받는 피해 감소', 'keen', '예리 — 치명타', 'silent', '소리 없음 — 회피·이목 낮춤'),
    'forms', jsonb_build_object('artificer', jsonb_build_array(jsonb_build_array('등패와 환도', 'base'), jsonb_build_array('등패와 철퇴', 'heavy')), 'bloodknight', jsonb_build_array(jsonb_build_array('도끼', 'heavy'), jsonb_build_array('대검', 'base')), 'analyst', jsonb_build_array(jsonb_build_array('단도', 'keen'), jsonb_build_array('수리검', 'base')), 'spearman', jsonb_build_array(jsonb_build_array('언월도', 'base'), jsonb_build_array('장창', 'keen')), 'scout', jsonb_build_array(jsonb_build_array('각궁', 'keen'), jsonb_build_array('쇠뇌', 'base')), 'tamer', jsonb_build_array(jsonb_build_array('단궁', 'base'), jsonb_build_array('취관', 'keen')), 'exorcist', jsonb_build_array(jsonb_build_array('방울', 'base'), jsonb_build_array('법경', 'keen')), 'sealmaster', jsonb_build_array(jsonb_build_array('금강령', 'silent'), jsonb_build_array('사슬', 'base')), 'medic', jsonb_build_array(jsonb_build_array('부채', 'silent'), jsonb_build_array('침통', 'base')), 'formation', jsonb_build_array(jsonb_build_array('산가지', 'base'), jsonb_build_array('나경', 'silent'))))
$$;

create or replace function public.world_gear_roll(p_mech text, p_level integer, p_rank text, p_rare numeric DEFAULT 0)
 returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare total numeric; cap numeric; got text; v_job text;
begin
  select coalesce(sum(case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end), 0)
    into total from public.world_gear_drops g join public.world_item_catalog i on i.item_id = g.item_id
   where g.mechanic_key = p_mech and p_level between g.level_min and g.level_max and (p_rank = 'guardian' or coalesce(i.tier, 1) <= 2);
  if total <= 0 then return null; end if;
  cap := case p_rank when 'guardian' then 0.15 when 'elite' then 0.05 else 0.01 end;
  if random() >= least(cap, total) * greatest(0, 1 + coalesce(p_rare, 0) / 100.0) then return null; end if;
  select c.job_key into v_job from public.world_characters c where c.owner_id = public.fn_owner_auth_uid();
  select g.item_id into got from public.world_gear_drops g join public.world_item_catalog i on i.item_id = g.item_id
   where g.mechanic_key = p_mech and p_level between g.level_min and g.level_max and (p_rank = 'guardian' or coalesce(i.tier, 1) <= 2)
     and (case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end) > 0
   order by -ln(greatest(random(), 1e-9)) / ((case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end)
     * case when v_job is not null and i.category = 'weapon' and i.equipment_traits -> 'jobs' ? v_job
              and jsonb_array_length(i.equipment_traits -> 'jobs') = 1 then coalesce((public.world_weapon_rules() ->> 'drop_job_mul')::numeric, 4) else 1 end)
   limit 1;
  return got;
end $$;


alter table public.world_characters drop constraint world_characters_job_key_check;
alter table public.world_characters add constraint world_characters_job_key_check
  check (job_key = any (array['exorcist', 'scout', 'medic', 'sealmaster', 'analyst', 'artificer', 'tamer', 'bloodknight', 'spearman', 'formation']));

select pg_temp.yh_fix('world_job_base', array[$q$
    when 'analyst'    then$q$, $q$
    when 'bloodknight' then '{"strength":9,"agility":3,"vitality":8,"perception":3,"willpower":4,"spirit_affinity":3}'
    when 'spearman'   then '{"strength":8,"agility":7,"vitality":5,"perception":4,"willpower":3,"spirit_affinity":3}'
    when 'formation'  then '{"strength":3,"agility":3,"vitality":3,"perception":5,"willpower":7,"spirit_affinity":9}'
    when 'analyst'    then$q$]);

select pg_temp.yh_fix('world_job_effect', array[$q$
      when 'tamer'      then 0$q$, $q$
      when 'tamer'      then 0
      when 'bloodknight' then case p_key when 'incoming_damage_pct' then -6 else 0 end
      when 'spearman'   then 0
      when 'formation'  then case p_key when 'shield_pct' then 15 when 'healing_pct' then -10 when 'mental_loss_pct' then -5 else 0 end$q$]);

select pg_temp.yh_fix('world_job_label', array[$q$ when 'tamer' then '조련사' end$q$, $q$ when 'tamer' then '조련사' when 'bloodknight' then '혈기사' when 'spearman' then '여명 창객' when 'formation' then '진법가' end$q$]);
select pg_temp.yh_fix('world_job_name', array[$q$ when 'tamer' then '조련사' else$q$, $q$ when 'tamer' then '조련사' when 'bloodknight' then '혈기사' when 'spearman' then '여명 창객' when 'formation' then '진법가' else$q$]);

create or replace function public.world_job_line(p_job text)
 returns text language sql immutable
as $function$
  select case p_job when 'artificer' then 'melee' when 'scout' then 'ranged' when 'sealmaster' then 'sealing'
    when 'exorcist' then 'exorcism' when 'analyst' then 'dagger' when 'medic' then 'medicine' when 'tamer' then 'taming'
    when 'bloodknight' then 'bloodcraft' when 'spearman' then 'spear' when 'formation' then 'formation' end
$function$;

create or replace function public.world_combat_lines()
 returns text[] language sql immutable
as $function$
  select array['melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine', 'taming', 'bloodcraft', 'spear', 'formation']
$function$;

select pg_temp.yh_fix('world_job_skill_rules', array[$q$ 'line', '{me}의 「휘파람」: 동무가 함께 달려들었다.'))$q$, $q$ 'line', '{me}의 「휘파람」: 동무가 함께 달려들었다.'),
    'bloodknight', jsonb_build_object('name', '피 갑주', 'desc', '체력 15를 깎아 보호막 30을 두릅니다(보호막 세기 덤 적용). 다 깨지면 깎은 체력의 절반을 돌려받습니다.', 'duel', jsonb_build_object('kind', 'heal', 'heal', 0.2), 'line', '{me}의 「피 갑주」: 제 피로 갑주를 둘러 기세 {n}을(를) 버텼다.'),
    'spearman', jsonb_build_object('name', '관통 찌르기', 'desc', '근접 ×1.6으로 찌르고 상대 방어의 절반을 무시합니다.', 'duel', jsonb_build_object('kind', 'pierce', 'n', 1, 'mul', 1.6), 'line', '{me}의 「관통 찌르기」: 창끝이 갑주 틈을 꿰었다.'),
    'formation', jsonb_build_object('name', '산가지 진', 'desc', '세 턴 동안 받는 피해가 35% 줄고, 진이 걷힐 때 체력 10을 되찾습니다.', 'duel', jsonb_build_object('kind', 'heal', 'heal', 0.18), 'line', '{me}의 「산가지 진」: 다칠 자리를 미리 막아 기세 {n}을(를) 지켰다.'))$q$]);

select pg_temp.yh_fix('world_solo_aid(text)', array[$q$
    when 'analyst'    then$q$, $q$
    when 'bloodknight' then '{"solo_dmg": -52, "solo_guard": -27, "final_dmg": -2}'
    when 'spearman'   then '{"solo_dmg": -25, "solo_guard": -36, "final_dmg": 34}'
    when 'formation'  then '{"solo_dmg": -30, "solo_guard": -55, "final_dmg": 18}'
    when 'analyst'    then$q$]);

do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_boss_rules()'::regprocedure);
  d := regexp_replace(d, '"tamer": \{"solo_dmg": (-?[0-9.]+), "solo_guard": (-?[0-9.]+)\}',
    '"tamer": {"solo_dmg": \1, "solo_guard": \2}, "bloodknight": {"solo_dmg": \1, "solo_guard": \2}, "spearman": {"solo_dmg": \1, "solo_guard": \2}, "formation": {"solo_dmg": \1, "solo_guard": \2}', 'g');
  execute d;
end $$;

create or replace function public.world_weapon_jobs_of(p_type text)
 returns jsonb language sql immutable
as $function$
  select case coalesce(p_type, 'melee') when 'ranged' then '["scout","tamer"]'::jsonb when 'magic' then '["exorcist","sealmaster","medic","formation"]'::jsonb
    else '["artificer","analyst","bloodknight","spearman"]'::jsonb end
$function$;

update public.world_monster_kinds set job_keys = job_keys || array['bloodknight'] where kind_key in ('giant', 'shell') and not 'bloodknight' = any (job_keys);
update public.world_monster_kinds set job_keys = job_keys || array['spearman'] where kind_key in ('bird', 'sky') and not 'spearman' = any (job_keys);
update public.world_monster_kinds set job_keys = job_keys || array['formation'] where kind_key in ('ward', 'water') and not 'formation' = any (job_keys);

select pg_temp.yh_fix('world_create_character_v2', array[
  $q$    else                   '{"weapon":"w_melee1_keen"$q$, $q$    when 'bloodknight' then '{"weapon":"w_melee1_heavy","armor":"a1_iron","amulet":"m1_ward","tool":"field_knife"}'
    when 'spearman'   then '{"weapon":"w_spear1_b","armor":"padded_coat","shoes":"s1_road","tool":"field_knife"}'
    when 'formation'  then '{"weapon":"w_magic1_keen","armor":"a1_robe","amulet":"m1_purify","tool":"field_knife"}'
    else                   '{"weapon":"w_melee1_keen"$q$,
  $q$    when 'analyst'    then '{"tonic":2}'$q$, $q$    when 'analyst'    then '{"tonic":2}'
    when 'bloodknight' then '{"tonic":2}'
    when 'spearman'   then '{"tonic":2}'
    when 'formation'  then '{"ward_talisman":2,"seal_paper":2}'$q$]);

select pg_temp.yh_fix('world_combat_stats', array[
  $q$WHEN c.job_key = 'analyst' AND style = 'melee' THEN 1.18 ELSE 1 END;$q$,
  $q$WHEN c.job_key = 'analyst' AND style = 'melee' THEN 1.18 WHEN c.job_key = 'bloodknight' THEN 0.95 WHEN c.job_key = 'spearman' AND style = 'melee' THEN 1.12 ELSE 1 END;$q$,
  $q$WHEN c.job_key = 'artificer' THEN 80 WHEN c.job_key = 'sealmaster' THEN 60$q$,
  $q$WHEN c.job_key = 'artificer' THEN 80 WHEN c.job_key = 'bloodknight' THEN 50 WHEN c.job_key = 'sealmaster' THEN 60$q$]);

select pg_temp.yh_fix('world_expedition_complete', array[$q$ when 'tamer' then '동무의 코' end;$q$, $q$ when 'tamer' then '동무의 코' when 'bloodknight' then '베어 버티기' when 'spearman' then '새벽 돌파' when 'formation' then '길흉 셈' end;$q$]);
select pg_temp.yh_fix('world_expedition_progress', array[$q$ when 'tamer' then '동무의 코' end);$q$, $q$ when 'tamer' then '동무의 코' when 'bloodknight' then '베어 버티기' when 'spearman' then '새벽 돌파' when 'formation' then '길흉 셈' end);$q$]);

select pg_temp.yh_fix('world_expedition_walk_lines', array[$q$
    else array['주변을 살피며 천천히 나아갑니다.'] end;$q$, $q$
    when 'bloodknight' then array['도끼날에 묻은 피를 닦으며 묵묵히 앞장섭니다.', '상처를 동여매고 다시 걸음을 재촉합니다.', '무거운 갑주를 고쳐 메고 숨을 고릅니다.']
    when 'spearman' then array['긴 창끝으로 앞길의 풀숲을 먼저 헤칩니다.', '창 자루를 어깨에 걸고 새벽빛 쪽을 바라봅니다.', '창끝이 닿는 거리를 가늠하며 발을 옮깁니다.']
    when 'formation' then array['나경을 꺼내 방위를 읽고 길을 고릅니다.', '산가지를 몇 개 놓아 오늘 길의 길흉을 셈합니다.', '땅 기운이 흐린 자리를 피해 돌아갑니다.']
    else array['주변을 살피며 천천히 나아갑니다.'] end;$q$]);

select pg_temp.yh_fix('world_exp_fight_story', array[$q$
    when 'tamer' then '[짝 사냥] 동무가 {f}에게 달려든 틈에 화살을 박아 넣었습니다' else null end;$q$, $q$
    when 'tamer' then '[짝 사냥] 동무가 {f}에게 달려든 틈에 화살을 박아 넣었습니다'
    when 'bloodknight' then '[베어 버티기] {f}의 공격을 몸으로 받으며 도끼로 베어 넘겼습니다'
    when 'spearman' then '[새벽 돌파] {f}이(가) 다가오기 전에 창끝이 먼저 닿았습니다'
    when 'formation' then '[길흉 셈] 미리 셈해 둔 자리로 비켜서며 {f}의 공격을 흘렸습니다' else null end;$q$]);

select pg_temp.yh_fix('world_expedition_duo_lines', array[$q$
    'tamer', jsonb_build_array($q$, $q$
    'bloodknight', jsonb_build_array('%a이(가) 다친 %b의 팔을 제 붕대로 단단히 동여매 줍니다.', '%a이(가) 무거운 짐을 대신 지고 %b에게 앞서 가라고 턱짓합니다.', '%a이(가) 도끼를 갈다가 %b의 무기 날도 봐 줍니다.'),
    'spearman', jsonb_build_array('%a이(가) 창끝으로 %b의 발 앞 풀숲을 먼저 헤쳐 줍니다.', '%a이(가) 새벽빛이 드는 쪽을 가리키며 %b에게 길을 일러 줍니다.', '%a이(가) %b에게 창 자루 잡는 법을 장난스레 가르쳐 줍니다.'),
    'formation', jsonb_build_array('%a이(가) 나경을 보며 %b에게 오늘 피할 방위를 일러 줍니다.', '%a이(가) %b의 발치에 산가지를 놓아 쉴 자리를 골라 줍니다.', '%a이(가) %b의 걸음 수를 셈해 쉬어 갈 때를 알려 줍니다.'),
    'tamer', jsonb_build_array($q$]);

create or replace function public.world_job_skill_cost(p_job text) returns integer language sql immutable as $$
  select case when p_job in ('medic', 'formation') then 25 when p_job in ('bloodknight', 'spearman') then 20 else 12 end
$$;
select pg_temp.yh_share('public.world_job_skill_cost(text)');

create or replace function public.world_spear_rules() returns jsonb language sql immutable as $$
  select jsonb_build_object('name', '창끝 기세', 'per', 5, 'per24', 1, 'rank24', 24, 'max', 5, 'finish_name', '마무리 찌르기', 'finish_pct', 15, 'finish_at', 30)
$$;
create or replace function public.world_spear_mul(p_uid uuid, p_n integer, p_hp numeric, p_max numeric) returns numeric
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare r jsonb := public.world_spear_rules(); rk int; m numeric;
begin
  select coalesce((c.skill_progress -> 'spear' ->> 'rank')::int, 0) into rk from public.world_characters c where c.owner_id = p_uid;
  m := 1 + ((r ->> 'per')::numeric + case when coalesce(rk, 0) >= (r ->> 'rank24')::int then (r ->> 'per24')::numeric else 0 end) / 100.0 * least((r ->> 'max')::int, greatest(0, coalesce(p_n, 0)));
  if coalesce(p_max, 0) > 0 and p_hp * 100 < p_max * (r ->> 'finish_at')::numeric and 'spear_m50' = any (public.world_skill_procs(p_uid)) then
    m := m * (1 + (r ->> 'finish_pct')::numeric / 100.0);
  end if;
  return m;
end $$;
select pg_temp.yh_own('public.world_spear_mul(uuid, integer, numeric, numeric)', 'fn_owner_field');
select pg_temp.yh_share('public.world_spear_mul(uuid, integer, numeric, numeric)');
select pg_temp.yh_share('public.world_spear_rules()');
grant execute on function public.world_spear_rules() to authenticated;

select pg_temp.yh_fix('world_battle_action', array[
  $q$sp := sp - CASE WHEN c.job_key = 'medic' THEN 25 ELSE 12 END;$q$,
  $q$sp := sp - public.world_job_skill_cost(c.job_key);$q$,

  $q$  first_atk := NOT coalesce((v_pfx ->> 'opened')::boolean, false);$q$,
  $q$  first_atk := NOT coalesce((v_pfx ->> 'opened')::boolean, false);
  IF act NOT IN ('attack', 'skill') THEN v_pfx := v_pfx - 'chain'; END IF;$q$,

  $q$  ELSIF act = 'skill' AND c.job_key = 'analyst' THEN$q$,
  $q$  ELSIF act = 'skill' AND c.job_key = 'bloodknight' THEN
    IF NOT ('bloodcraft_m50' = ANY (sk)) THEN
      IF hp <= 15 THEN RAISE EXCEPTION '체력이 모자라 피 갑주를 두를 수 없습니다.'; END IF;
      hp := hp - 15;
    END IF;
    extra := round(CASE WHEN 'bloodcraft_c24b' = ANY (sk) THEN 40 ELSE 30 END * (1 + public.world_status_effect_total('shield_pct') / 100.0));
    v_pfx := v_pfx || jsonb_build_object('pshield', least(90, coalesce((v_pfx ->> 'pshield')::int, 0) + extra), 'bk_paid', CASE WHEN 'bloodcraft_m50' = ANY (sk) THEN 0 ELSE 15 END);
    lines := lines || jsonb_build_array((public.world_job_skill_rules() -> 'bloodknight' ->> 'name') || ': ' || CASE WHEN 'bloodcraft_m50' = ANY (sk) THEN '' ELSE '체력 15를 깎아 ' END || '보호막 ' || extra || '을(를) 둘렀다.');
  ELSIF act = 'skill' AND c.job_key = 'formation' THEN
    v_pfx := v_pfx || jsonb_build_object('zin', CASE WHEN 'formation_c13a' = ANY (sk) THEN 4 ELSE 3 END);
    lines := lines || jsonb_build_array((public.world_job_skill_rules() -> 'formation' ->> 'name') || ': 다칠 자리를 셈해 진을 쳤다. 세 턴 동안 받는 피해가 줄어든다.');
  ELSIF act = 'skill' AND c.job_key = 'analyst' THEN$q$,

  $q$    ELSIF act = 'skill' AND c.job_key = 'tamer' THEN style := 'ranged'; skill_name := public.world_job_skill_rules() -> 'tamer' ->> 'name';$q$,
  $q$    ELSIF act = 'skill' AND c.job_key = 'tamer' THEN style := 'ranged'; skill_name := public.world_job_skill_rules() -> 'tamer' ->> 'name';
    ELSIF act = 'skill' AND c.job_key = 'spearman' THEN style := 'melee'; skill_name := public.world_job_skill_rules() -> 'spearman' ->> 'name';$q$,

  $q$    ELSIF skill_name = '파갑참' THEN mul := mul * 1.7;$q$,
  $q$    ELSIF skill_name = '파갑참' THEN mul := mul * 1.7;
    ELSIF skill_name = '관통 찌르기' THEN mul := mul * 1.6;$q$,

  $q$    IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN mul := mul * 1.2; END IF;$q$,
  $q$    IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN mul := mul * 1.2; END IF;
    IF c.job_key = 'bloodknight' AND 'bloodcraft_c24a' = ANY (sk) AND hp < 50 THEN mul := mul * 1.15; END IF;
    IF c.job_key = 'formation' AND 'formation_c30b' = ANY (sk) AND coalesce((v_pfx ->> 'zin')::int, 0) > 0 THEN mul := mul * 1.15; END IF;
    IF c.job_key = 'formation' AND coalesce((v_pfx ->> 'turned')::boolean, false) THEN mul := mul * 1.2; v_pfx := v_pfx - 'turned'; END IF;
    IF c.job_key = 'spearman' AND 'spear_c30b' = ANY (sk) AND v_intent LIKE 'g%:%' THEN mul := mul * 1.25; END IF;
    IF c.job_key = 'spearman' AND 'spear_c24a' = ANY (sk) AND style = 'melee' THEN crit_x := crit_x + 0.2; END IF;
    IF c.job_key = 'spearman' AND 'spear_m50' = ANY (sk) AND first_atk THEN force_crit := true; END IF;
    IF c.job_key = 'spearman' AND style = 'melee' THEN
      mul := mul * public.world_spear_mul(uid, coalesce((v_pfx ->> 'chain')::int, 0), a.current_hp, a.max_hp);
      v_pfx := v_pfx || jsonb_build_object('chain', least((public.world_spear_rules() ->> 'max')::int, coalesce((v_pfx ->> 'chain')::int, 0) + 1));
    END IF;$q$,

  $q$    dmg := greatest(1, round(base * mul - mdef * 0.8));$q$,
  $q$    dmg := greatest(1, round(base * mul - mdef * 0.8 * CASE WHEN skill_name = '관통 찌르기' AND 'spear_c43a' = ANY (sk) THEN 0 WHEN skill_name = '관통 찌르기' THEN 0.5 ELSE 1 END));
    IF coalesce((v_pfx ->> 'bsurge')::int, 0) > 0 THEN dmg := dmg + (v_pfx ->> 'bsurge')::int; lines := lines || jsonb_build_array('「갑주 되갚기」 막아 낸 피해를 되갚았다. +' || (v_pfx ->> 'bsurge')); v_pfx := v_pfx - 'bsurge'; END IF;$q$,

  $q$    a.current_hp := greatest(0, a.current_hp - dmg);
    lines := lines || jsonb_build_array(coalesce(skill_name,$q$,
  $q$    a.current_hp := greatest(0, a.current_hp - dmg);
    IF c.job_key = 'bloodknight' AND style = 'melee' AND dmg > 0 THEN
      extra := public.world_leech_of(uid, dmg);
      IF 'bloodcraft_c13a' = ANY (sk) AND random() < 0.25 THEN extra := extra * 2; END IF;
      IF coalesce((v_pfx ->> 'bk_last')::boolean, false) THEN extra := extra * 3; v_pfx := v_pfx - 'bk_last'; END IF;
      IF hp >= 100 AND 'bloodcraft_c30a' = ANY (sk) THEN
        v_pfx := v_pfx || jsonb_build_object('pshield', least(coalesce((v_pfx ->> 'pshield')::int, 0) + extra, greatest(coalesce((v_pfx ->> 'pshield')::int, 0), 20)));
        lines := lines || jsonb_build_array('「끊기지 않는 숨」 넘친 피가 보호막이 됐다. +' || extra);
      ELSIF hp < 100 THEN
        hp := least(100, hp + extra); lines := lines || jsonb_build_array('흘린 피를 갈무리했다. 체력 +' || extra);
      END IF;
    END IF;
    IF c.job_key = 'spearman' AND style = 'melee' AND dmg > 0 AND a.current_hp > 0 THEN
      IF 'spear_c13a' = ANY (sk) AND coalesce((v_pfx ->> 'chain')::int, 0) >= 3 AND random() < 0.25 THEN
        extra := greatest(1, round(dmg * 0.6)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「세 번 찌르기」 +' || extra);
      END IF;
      IF 'spear_c13b' = ANY (sk) AND random() < 0.2 AND a.current_hp > 0 THEN
        extra := greatest(1, round(dmg * 0.4)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「반달 베기」 +' || extra);
      END IF;
      IF 'spear_c24b' = ANY (sk) AND random() < 0.15 THEN v_fx := v_fx || jsonb_build_object('weak', greatest(2, coalesce((v_fx ->> 'weak')::int, 0))); lines := lines || jsonb_build_array('「자루 쳐내기」 요괴가 휘청였다.'); END IF;
      IF 'spear_c30a' = ANY (sk) AND coalesce((v_pfx ->> 'chain')::int, 0) >= 3 THEN v_fx := v_fx || jsonb_build_object('marked', greatest(1, coalesce((v_fx ->> 'marked')::int, 0))); END IF;
      IF 'spear_c43b' = ANY (sk) THEN
        v_pfx := v_pfx || jsonb_build_object('spin', coalesce((v_pfx ->> 'spin')::int, 0) + 1);
        IF (v_pfx ->> 'spin')::int % 4 = 0 AND a.current_hp > 0 THEN
          extra := greatest(1, round(dmg * 0.5)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「언월 회전」 +' || extra);
        END IF;
      END IF;
    END IF;
    IF c.job_key = 'formation' AND style = 'magic' AND dmg > 0 AND 'formation_c24b' = ANY (sk) AND random() < 0.2 THEN
      v_fx := v_fx || jsonb_build_object('weak', greatest(2, coalesce((v_fx ->> 'weak')::int, 0))); lines := lines || jsonb_build_array('「허를 셈」 요괴의 다음 수가 무뎌졌다.');
    END IF;
    IF first_atk AND c.job_key = 'spearman' AND style = 'melee' AND dmg > 0 AND a.current_hp > 0 THEN
      extra := greatest(1, round(dmg * 0.5)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra;
      lines := lines || jsonb_build_array('「선제」 요괴보다 먼저 한 번 더 찔렀다. +' || extra);
    END IF;
    lines := lines || jsonb_build_array(coalesce(skill_name,$q$,

  $q$        IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 THEN mdmg := round(mdmg * CASE WHEN 'exorcism_c43b' = ANY (sk) THEN 0.74 ELSE 0.8 END); END IF;$q$,
  $q$        IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 THEN mdmg := round(mdmg * CASE WHEN 'exorcism_c43b' = ANY (sk) THEN 0.74 ELSE 0.8 END); END IF;
        IF coalesce((v_pfx ->> 'zin')::int, 0) > 0 THEN mdmg := round(mdmg * CASE WHEN 'formation_c24a' = ANY (sk) THEN 0.55 ELSE 0.65 END); END IF;
        IF c.job_key = 'formation' AND 'formation_c13b' = ANY (sk) AND v_intent LIKE 'g%:%' THEN mdmg := round(mdmg * 0.7); END IF;
        IF c.job_key = 'formation' AND 'formation_c43b' = ANY (sk) AND v_intent LIKE 'g%:%' THEN v_pfx := v_pfx || jsonb_build_object('turned', true); END IF;$q$,

  $q$        lines := lines || jsonb_build_array('「강기」가 ' || absorb || ' 피해를 막았다.');$q$,
  $q$        lines := lines || jsonb_build_array('보호막이 ' || absorb || ' 피해를 막았다.');
        IF 'bloodcraft_c30b' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('babs', coalesce((v_pfx ->> 'babs')::int, 0) + absorb); END IF;
        IF (v_pfx ->> 'pshield')::int <= 0 AND v_pfx ? 'bk_paid' THEN
          IF (v_pfx ->> 'bk_paid')::int > 0 THEN hp := least(100, hp + ((v_pfx ->> 'bk_paid')::int / 2)); lines := lines || jsonb_build_array('피 갑주가 깨지며 깎았던 체력 일부가 돌아왔다.'); END IF;
          IF 'bloodcraft_c30b' = ANY (sk) THEN v_pfx := (v_pfx - 'babs') || jsonb_build_object('bsurge', least(40, coalesce((v_pfx ->> 'bsurge')::int, 0) + round(coalesce((v_pfx ->> 'babs')::int, 0) * 0.3))); lines := lines || jsonb_build_array('「갑주 되갚기」 막아 낸 힘을 다음 공격에 싣는다.'); END IF;
          v_pfx := v_pfx - 'bk_paid';
        END IF;$q$,

  $q$  v_pfx := v_pfx - 'bound'; v_fx := v_fx - 'evade' - 'thorns' - 'mirror';$q$,
  $q$  IF coalesce((v_pfx ->> 'zin')::int, 0) > 0 THEN
    IF 'formation_c30a' = ANY (sk) AND hp < 100 THEN hp := least(100, hp + 3); END IF;
    v_pfx := v_pfx || jsonb_build_object('zin', (v_pfx ->> 'zin')::int - 1);
    IF (v_pfx ->> 'zin')::int <= 0 THEN
      v_pfx := v_pfx - 'zin'; extra := round(10 * CASE WHEN 'formation_m50' = ANY (sk) THEN 2 ELSE 1 END * (1 + public.world_status_effect_total('healing_pct') / 100.0)); hp := least(100, hp + extra);
      IF 'formation_m50' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('pshield', greatest(coalesce((v_pfx ->> 'pshield')::int, 0), round(15 * (1 + public.world_status_effect_total('shield_pct') / 100.0)))); END IF;
      lines := lines || jsonb_build_array('산가지 진이 걷히며 체력 +' || extra);
    END IF;
  END IF;
  v_pfx := v_pfx - 'bound'; v_fx := v_fx - 'evade' - 'thorns' - 'mirror';$q$,

  $q$    IF ended IS NULL AND hp <= 0 AND 'medicine_c43b' = ANY (sk) AND NOT coalesce((v_pfx ->> 'reborn')::boolean, false) THEN$q$,
  $q$    IF ended IS NULL AND hp <= 0 AND 'bloodcraft_c43a' = ANY (sk) AND NOT coalesce((v_pfx ->> 'endured')::boolean, false) THEN
      hp := 1; v_pfx := v_pfx || jsonb_build_object('endured', true, 'bk_last', true); lines := lines || jsonb_build_array('「마지막 한 모금」 쓰러질 일격을 버텨 냈다. 체력 1');
    END IF;
    IF ended IS NULL AND hp <= 0 AND 'formation_c43a' = ANY (sk) AND NOT coalesce((v_pfx ->> 'endured')::boolean, false) THEN
      hp := 25; v_pfx := v_pfx || jsonb_build_object('endured', true); lines := lines || jsonb_build_array('「무너지지 않는 진」 진이 쓰러질 일격을 대신 받았다. 체력 25');
    END IF;
    IF ended IS NULL AND hp <= 0 AND 'medicine_c43b' = ANY (sk) AND NOT coalesce((v_pfx ->> 'reborn')::boolean, false) THEN$q$
]);

select pg_temp.yh_fix('world_battle_action', array[
  $q$    IF sp < (CASE WHEN c.job_key = 'medic' THEN 25 ELSE 12 END) THEN RAISE EXCEPTION '%', CASE WHEN style = 'melee' THEN '기력' ELSE '영력' END || '이 모자랍니다. (필요 ' || CASE WHEN c.job_key = 'medic' THEN 25 ELSE 12 END || ')'; END IF;$q$,
  $q$    IF sp < public.world_job_skill_cost(c.job_key) THEN RAISE EXCEPTION '%', CASE WHEN style = 'melee' THEN '기력' ELSE '영력' END || '이 모자랍니다. (필요 ' || public.world_job_skill_cost(c.job_key) || ')'; END IF;$q$]);

insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values
('bloodcraft_t3', '피 맛', 'bloodcraft', '근접 피해 +4% · 피흡 +1%p.', '{"damage_pct": 4, "leech_pct": 1}'::jsonb, 3, 'base'),
('bloodcraft_t8', '거친 숨', 'bloodcraft', '근접 피해 +12%, 거괴·갑각 요괴에게 +12% 더.', '{"damage_pct": 12}'::jsonb, 8, 'base'),
('bloodcraft_t13', '굳은 살', 'bloodcraft', '받는 피해 −3%.', '{"incoming_damage_pct": -3}'::jsonb, 13, 'base'),
('bloodcraft_t18', '피 돌리기', 'bloodcraft', '피흡 +1%p · 회복량 +3%.', '{"leech_pct": 1, "healing_pct": 3}'::jsonb, 18, 'base'),
('bloodcraft_t24', '쇠 근육', 'bloodcraft', '받는 피해 −3% · 근접 피해 +2%.', '{"incoming_damage_pct": -3, "damage_pct": 2}'::jsonb, 24, 'base'),
('bloodcraft_t30', '흘린 만큼', 'bloodcraft', '피흡 +1%p.', '{"leech_pct": 1}'::jsonb, 30, 'base'),
('bloodcraft_t36', '붉은 갑주', 'bloodcraft', '보호막 세기 +6% · 받는 피해 −2%.', '{"shield_pct": 6, "incoming_damage_pct": -2}'::jsonb, 36, 'base'),
('bloodcraft_t43', '핏줄 단련', 'bloodcraft', '회복량 +5% · 피흡 +1%p.', '{"healing_pct": 5, "leech_pct": 1}'::jsonb, 43, 'base'),
('bloodcraft_t50', '혈기 일체', 'bloodcraft', '받는 피해 −3% · 근접 피해 +3%.', '{"incoming_damage_pct": -3, "damage_pct": 3}'::jsonb, 50, 'base'),
('bloodcraft_c13a', '휘둘러 마시기', 'bloodcraft', '택일 기술(베어 버팀) · 공격이 적중하면 25% 확률로 그 한 방의 피흡이 두 배', '{}'::jsonb, 13, 'a'),
('bloodcraft_c13b', '나눠 두른 갑주', 'bloodcraft', '택일 기술(피 갑주) · 보스전(합동 토벌·귀허류)에서 협동 기술로 두르는 보호막이 50% 두꺼워진다', '{}'::jsonb, 13, 'b'),
('bloodcraft_c24a', '피바람', 'bloodcraft', '택일 기술(베어 버팀) · 체력이 50 아래면 근접 피해 +15%', '{}'::jsonb, 24, 'a'),
('bloodcraft_c24b', '두꺼운 피', 'bloodcraft', '택일 기술(피 갑주) · 피 갑주의 보호막 30 → 40', '{}'::jsonb, 24, 'b'),
('bloodcraft_c30a', '끊기지 않는 숨', 'bloodcraft', '택일 기술(베어 버팀) · 체력이 가득할 때 피흡으로 얻을 체력이 보호막으로 쌓인다(20까지)', '{}'::jsonb, 30, 'a'),
('bloodcraft_c30b', '갑주 되갚기', 'bloodcraft', '택일 기술(피 갑주) · 보호막이 깨질 때 막아 낸 피해의 30%를 다음 공격에 실어 되갚는다', '{}'::jsonb, 30, 'b'),
('bloodcraft_c43a', '마지막 한 모금', 'bloodcraft', '택일 기술(베어 버팀) · 쓰러질 피해를 받으면 한 전투에 한 번 체력 1로 버티고, 다음 공격의 피흡이 세 배', '{}'::jsonb, 43, 'a'),
('bloodcraft_c43b', '피로 잇는 맹세', 'bloodcraft', '택일 기술(피 갑주) · 보스전(합동 토벌·귀허류)에서 동료가 쓰러질 피해를 받으면 한 싸움에 한 번 내 체력 20을 내어 대신 버티게 한다', '{}'::jsonb, 43, 'b'),
('bloodcraft_m50', '혈해(血海)', 'bloodcraft', '숙달 기술 · 피흡으로 한 번에 얻는 체력 상한 6 → 10, 피 갑주를 쓸 때 체력을 깎지 않는다', '{}'::jsonb, 50, 'master'),
('spear_t3', '창끝 고르기', 'spear', '근접 피해 +4% · 치명타 +1%.', '{"damage_pct": 4, "crit_pct": 1}'::jsonb, 3, 'base'),
('spear_t8', '꿰뚫는 눈', 'spear', '근접 피해 +16%, 비금·천상 요괴에게 +12% 더.', '{"damage_pct": 16}'::jsonb, 8, 'base'),
('spear_t13', '긴 호흡', 'spear', '근접 피해 +3%.', '{"damage_pct": 3}'::jsonb, 13, 'base'),
('spear_t18', '자루 휘두르기', 'spear', '근접 피해 +3%.', '{"damage_pct": 3}'::jsonb, 18, 'base'),
('spear_t24', '겹쳐 찌르기', 'spear', '근접 피해 +2%, 창끝 기세 한 겹 +1%p.', '{"damage_pct": 2}'::jsonb, 24, 'base'),
('spear_t30', '날 세우기', 'spear', '치명타 +3%.', '{"crit_pct": 3}'::jsonb, 30, 'base'),
('spear_t36', '먼 걸음', 'spear', '근접 피해 +3% · 치명타 +1%.', '{"damage_pct": 3, "crit_pct": 1}'::jsonb, 36, 'base'),
('spear_t43', '새벽 기세', 'spear', '근접 피해 +4%.', '{"damage_pct": 4}'::jsonb, 43, 'base'),
('spear_t50', '창도(槍道)', 'spear', '근접 피해 +3% · 치명타 +2%.', '{"damage_pct": 3, "crit_pct": 2}'::jsonb, 50, 'base'),
('spear_c13a', '세 번 찌르기', 'spear', '택일 기술(찌르기) · 창끝 기세가 셋 이상 쌓인 공격에 25% 확률로 한 번 더 찌른다(피해 60%)', '{}'::jsonb, 13, 'a'),
('spear_c13b', '반달 베기', 'spear', '택일 기술(휘두르기) · 공격 때 20% 확률로 언월도를 크게 휘둘러 피해 40%를 한 번 더', '{}'::jsonb, 13, 'b'),
('spear_c24a', '급소 꿰기', 'spear', '택일 기술(찌르기) · 근접 치명타 피해 +20%', '{}'::jsonb, 24, 'a'),
('spear_c24b', '자루 쳐내기', 'spear', '택일 기술(휘두르기) · 공격 때 15% 확률로 요괴를 휘청이게 해 다음 공격을 약하게 한다', '{}'::jsonb, 24, 'b'),
('spear_c30a', '창끝 표식', 'spear', '택일 기술(찌르기) · 창끝 기세가 셋 이상이면 요괴에 표식을 남겨 다음 공격 피해 +25%', '{}'::jsonb, 30, 'a'),
('spear_c30b', '휘몰이', 'spear', '택일 기술(휘두르기) · 요괴가 수법을 예고한 턴에 공격하면 피해 +25%', '{}'::jsonb, 30, 'b'),
('spear_c43a', '꿰뚫는 새벽', 'spear', '택일 기술(찌르기) · 관통 찌르기가 방어를 모두 무시한다', '{}'::jsonb, 43, 'a'),
('spear_c43b', '언월 회전', 'spear', '택일 기술(휘두르기) · 네 번째 공격마다 한 번 더 휘둘러 피해 50%', '{}'::jsonb, 43, 'b'),
('spear_m50', '여명일섬(黎明一閃)', 'spear', '숙달 기술 · 싸움의 첫 공격이 반드시 치명타, 체력이 30% 아래로 떨어진 요괴에게 주는 피해 +15%(마무리 찌르기)', '{}'::jsonb, 50, 'master'),
('formation_t3', '산가지 놓기', 'formation', '술법 피해 +3% · 보호막 세기 +3%.', '{"damage_pct": 3, "shield_pct": 3}'::jsonb, 3, 'base'),
('formation_t8', '방위 읽기', 'formation', '술법 피해 +14%, 금주·수귀 요괴에게 +12% 더.', '{"damage_pct": 14}'::jsonb, 8, 'base'),
('formation_t13', '팔괘 셈', 'formation', '보호막 세기 +4%.', '{"shield_pct": 4}'::jsonb, 13, 'base'),
('formation_t18', '명당 잡기', 'formation', '받는 피해 −3% · 정신 손실 −5%.', '{"incoming_damage_pct": -3, "mental_loss_pct": -5}'::jsonb, 18, 'base'),
('formation_t24', '터 다지기', 'formation', '보호막 세기 +4% · 회복량 +2%.', '{"shield_pct": 4, "healing_pct": 2}'::jsonb, 24, 'base'),
('formation_t30', '구궁 셈', 'formation', '보호막 세기 +5%.', '{"shield_pct": 5}'::jsonb, 30, 'base'),
('formation_t36', '길흉 가리기', 'formation', '받는 피해 −3% · 침식 −5%.', '{"incoming_damage_pct": -3, "erosion_pct": -5}'::jsonb, 36, 'base'),
('formation_t43', '천지 방위', 'formation', '보호막 세기 +6%.', '{"shield_pct": 6}'::jsonb, 43, 'base'),
('formation_t50', '진법 대성', 'formation', '보호막 세기 +5% · 술법 피해 +3%.', '{"shield_pct": 5, "damage_pct": 3}'::jsonb, 50, 'base'),
('formation_c13a', '겹진', 'formation', '택일 기술(진 치기) · 산가지 진이 한 턴 더 간다(네 턴)', '{}'::jsonb, 13, 'a'),
('formation_c13b', '낌새 셈', 'formation', '택일 기술(셈 맞추기) · 요괴가 수법을 예고한 턴에 받는 피해 −30% 더', '{}'::jsonb, 13, 'b'),
('formation_c24a', '두른 진', 'formation', '택일 기술(진 치기) · 산가지 진의 받는 피해 감소 35% → 45%', '{}'::jsonb, 24, 'a'),
('formation_c24b', '허를 셈', 'formation', '택일 기술(셈 맞추기) · 술법이 적중하면 20% 확률로 요괴를 휘청이게 해 다음 공격을 약하게 한다', '{}'::jsonb, 24, 'b'),
('formation_c30a', '진 안의 숨', 'formation', '택일 기술(진 치기) · 산가지 진 동안 턴마다 체력 +3', '{}'::jsonb, 30, 'a'),
('formation_c30b', '수 읽기', 'formation', '택일 기술(셈 맞추기) · 산가지 진 동안 술법 피해 +15%', '{}'::jsonb, 30, 'b'),
('formation_c43a', '무너지지 않는 진', 'formation', '택일 기술(진 치기) · 쓰러질 피해를 받으면 한 전투에 한 번 진이 대신 받아 체력 25로 버틴다', '{}'::jsonb, 43, 'a'),
('formation_c43b', '판 뒤집기', 'formation', '택일 기술(셈 맞추기) · 요괴가 수법을 예고한 턴을 버틴 뒤 다음 공격 +20%', '{}'::jsonb, 43, 'b'),
('formation_m50', '구궁팔괘진(九宮八卦陣)', 'formation', '숙달 기술 · 산가지 진이 걷힐 때 회복이 두 배가 되고 보호막 15를 남긴다', '{}'::jsonb, 50, 'master')
on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;

select pg_temp.yh_fix('world_line_name', array[$q$ when 'taming' then '조련'$q$, $q$ when 'taming' then '조련' when 'bloodcraft' then '혈투' when 'spear' then '창술' when 'formation' then '진법'$q$]);
select pg_temp.yh_fix('world_initialize_skill_tracks', array[$q$ 'taming',coalesce(new.skill_progress->'taming','{"xp":0,"rank":1}'::jsonb),$q$, $q$ 'taming',coalesce(new.skill_progress->'taming','{"xp":0,"rank":1}'::jsonb),
 'bloodcraft',coalesce(new.skill_progress->'bloodcraft','{"xp":0,"rank":1}'::jsonb),
 'spear',coalesce(new.skill_progress->'spear','{"xp":0,"rank":1}'::jsonb),
 'formation',coalesce(new.skill_progress->'formation','{"xp":0,"rank":1}'::jsonb),$q$]);
select pg_temp.yh_fix('world_skill_effect', array[
  $q$'combat_damage_pct', 'encounter_pct') then return 0; end if;$q$, $q$'combat_damage_pct', 'encounter_pct', 'shield_pct', 'leech_pct') then return 0; end if;$q$,
  $q$when 'encounter_pct' then greatest(v, -15) else v end;$q$, $q$when 'encounter_pct' then greatest(v, -15) when 'shield_pct' then least(v, 40) when 'leech_pct' then least(v, 6) else v end;$q$]);

create or replace function public.world_eff_as(p_uid uuid, p_key text) returns numeric
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare os text := current_setting('request.jwt.claim.sub', true); oc text := current_setting('request.jwt.claims', true); v numeric;
begin
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  v := coalesce(public.world_status_effect_total(p_key), 0);
  perform set_config('request.jwt.claims', coalesce(oc, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  return v;
end $$;
select pg_temp.yh_own('public.world_eff_as(uuid, text)', 'fn_owner_field');
select pg_temp.yh_share('public.world_eff_as(uuid, text)');

create or replace function public.world_leech_of(p_uid uuid, p_dmg numeric) returns integer
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  if coalesce(p_dmg, 0) <= 0 then return 0; end if;
  return least(case when 'bloodcraft_m50' = any (public.world_skill_procs(p_uid)) then 10 else 6 end,
               greatest(1, round(p_dmg * (8 + least(6, public.world_eff_as(p_uid, 'leech_pct'))) / 100.0)))::int;
end $$;
select pg_temp.yh_own('public.world_leech_of(uuid, numeric)', 'fn_owner_field');
select pg_temp.yh_share('public.world_leech_of(uuid, numeric)');

create or replace function public.world_shield_amt(p_uid uuid, p_amt numeric) returns integer
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  return round(coalesce(p_amt, 0) * (1 + least(40, public.world_eff_as(p_uid, 'shield_pct')) / 100.0)
    * case when 'bloodcraft_c13b' = any (public.world_skill_procs(p_uid)) then 1.5 else 1 end)::int;
end $$;
select pg_temp.yh_own('public.world_shield_amt(uuid, numeric)', 'fn_owner_field');
select pg_temp.yh_share('public.world_shield_amt(uuid, numeric)');

insert into public.world_coop_skills(skill_id, job_key, unlock_rank, skill_name, description, target, effect, cost, cooldown_s, exp_win, exp_heal, exp_text, sort) values
('bk_drink', 'bloodknight', 3, '피 갈무리', '세 번의 공격이 20% 강해집니다.', 'self', '{"type": "might", "n": 3, "pct": 20}', 4, 10, 0.04, 0, '흘린 피를 다잡아 도끼에 힘을 실었습니다', 401),
('bk_mantle', 'bloodknight', 8, '갑주 나눠 주기', '동료 하나에게 보호막 30을 둘러 줍니다.', 'ally', '{"type": "shield", "amt": 30}', 6, 15, 0.04, 0, '동료 앞에 서서 피 갑주를 나눠 둘렀습니다', 402),
('bk_brace', 'bloodknight', 18, '버티는 기세', '세 번 받는 피해를 30% 줄입니다.', 'self', '{"type": "ward", "n": 3, "pct": 30}', 8, 20, 0.05, 0, '무릎을 꿇지 않고 버텼습니다', 403),
('bk_undying', 'bloodknight', 36, '꺾이지 않는 몸', '세 번 동안 요괴를 끌어당기고 받는 피해를 40% 줄입니다.', 'self', '{"type": "taunt", "n": 3, "pct": 40, "pres": 100}', 12, 30, 0.07, 0, '요괴를 제게로 끌어당겨 버텼습니다', 404),
('sp_aim', 'spearman', 3, '창끝 겨누기', '요괴가 받는 피해가 두 번 12% 늘어납니다.', 'boss', '{"type": "expose", "n": 2, "pct": 12}', 4, 10, 0.04, 0, '창끝으로 요괴의 빈틈을 짚었습니다', 411),
('sp_wall', 'spearman', 8, '창벽', '두 번 공격을 40% 확률로 흘립니다.', 'self', '{"type": "evade", "n": 2, "pct": 40}', 5, 12, 0.04, 0, '창 자루로 공격을 흘려 냈습니다', 412),
('sp_hook', 'spearman', 18, '자루 걸기', '요괴가 모으는 기운을 늦춥니다.', 'boss', '{"type": "delay", "n": 2}', 9, 22, 0.06, 0, '창 자루로 요괴의 발을 걸었습니다', 413),
('sp_charge', 'spearman', 36, '새벽 돌격', '세 번의 공격이 35% 강해집니다.', 'self', '{"type": "might", "n": 3, "pct": 35}', 14, 30, 0.07, 0, '새벽빛처럼 앞으로 내달렸습니다', 414),
('fm_point', 'formation', 3, '방위 진', '동료 하나에게 보호막 25를 둘러 줍니다.', 'ally', '{"type": "shield", "amt": 25}', 4, 8, 0.04, 0, '다칠 방위를 셈해 진을 쳐 두었습니다', 421),
('fm_gate', 'formation', 8, '팔문 진', '모두 세 번 받는 피해를 15% 줄입니다.', 'all', '{"type": "ward_all", "n": 3, "pct": 15}', 8, 20, 0.05, 0, '여덟 문을 닫아 모두를 감쌌습니다', 422),
('fm_reckon', 'formation', 18, '셈 맞추기', '이번 수법 피해를 모두 절반으로 줄입니다.', 'all', '{"type": "break", "pct": 50}', 10, 20, 0.06, 0, '요괴의 수를 미리 셈해 피해를 덜었습니다', 423),
('fm_nine', 'formation', 36, '구궁 진', '모두에게 보호막 20을 둘러 줍니다.', 'all', '{"type": "shield_all", "amt": 20}', 14, 30, 0.07, 0, '아홉 칸 진으로 모두를 감쌌습니다', 424)
on conflict (skill_id) do update set job_key = excluded.job_key, unlock_rank = excluded.unlock_rank, skill_name = excluded.skill_name, description = excluded.description,
  target = excluded.target, effect = excluded.effect, cost = excluded.cost, cooldown_s = excluded.cooldown_s, exp_win = excluded.exp_win, exp_text = excluded.exp_text, sort = excluded.sort;

select pg_temp.yh_fix('world_raid_action', array[
  $q$    elsif k = 'taunt' then
      f := f || public.world_cb_buff('taunt', v, uid);$q$,
  $q$    elsif k = 'shield_all' then
      update public.world_raid_members x set fx = x.fx || jsonb_build_object('shield', coalesce((x.fx ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid)
       where x.raid_id = p_raid and x.owner_id <> uid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id);
      f := f || jsonb_build_object('shield', coalesce((f ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid);
    elsif k = 'taunt' then
      f := f || public.world_cb_buff('taunt', v, uid);$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
  $q$      when 'cover' then update public.world_gw_members set fx = fx || jsonb_build_object('cover', tgt) where fight_id = p_fight and owner_id = m.owner_id;$q$,
  $q$      when 'shield' then update public.world_gw_members set fx = fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (e ->> 'amt')::int, 'shield_by', m.owner_id) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
      when 'shield_all' then update public.world_gw_members set fx = fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (e ->> 'amt')::int, 'shield_by', m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'cover' then update public.world_gw_members set fx = fx || jsonb_build_object('cover', tgt) where fight_id = p_fight and owner_id = m.owner_id;$q$]);

select pg_temp.yh_fix('world_raid_action', array[
  $q$    rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - dmg); mb.dmg := mb.dmg + dmg; credit := 0;$q$,
  $q$    rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - dmg); mb.dmg := mb.dmg + dmg; credit := 0;
    if c.job_key = 'bloodknight' and dmg > 0 then
      perform set_config('yh.leech', public.world_leech_of(uid, dmg)::text, true);
    end if;$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
  $q$        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;$q$,
  $q$        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;
        if m.job_key = 'bloodknight' and d > 0 then
          update public.world_gw_members set hp = least(100, hp + public.world_leech_of(m.owner_id, d)) where fight_id = p_fight and owner_id = m.owner_id and out_rounds = 0 and hp > 0;
        end if;$q$]);

select pg_temp.yh_fix('world_raid_action', array[
  $q$  if act = 'attack' then
    if st ->> 'style' = 'magic' then$q$,
  $q$  if c.job_key = 'spearman' and act not in ('attack', 'coop') then f := f - 'spch'; end if;
  if act = 'attack' then
    if st ->> 'style' = 'magic' then$q$,
  $q$    mul := mul * psolo;
    dmg := greatest(1, round((cbr ->> 'd')::numeric * mul))::int;$q$,
  $q$    mul := mul * psolo;
    if c.job_key = 'spearman' and st ->> 'style' = 'melee' then
      mul := mul * public.world_spear_mul(uid, coalesce((f ->> 'spch')::int, 0), rd.hp, rd.max_hp);
      f := f || jsonb_build_object('spch', least((public.world_spear_rules() ->> 'max')::int, coalesce((f ->> 'spch')::int, 0) + 1));
    end if;
    dmg := greatest(1, round((cbr ->> 'd')::numeric * mul))::int;$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
  $q$    select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
    if av = 'attack' then$q$,
  $q$    select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
    if m.job_key = 'spearman' and av <> 'attack' and vfx ? 'spch' then
      vfx := vfx - 'spch'; update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;
    end if;
    if av = 'attack' then$q$,
  $q$      if f.mode = 'ultimate' and m.weak <> '[]'::jsonb then d := d * (public.world_ug_weak(p_fight, m.owner_id) ->> 'deal')::numeric; end if;$q$,
  $q$      if f.mode = 'ultimate' and m.weak <> '[]'::jsonb then d := d * (public.world_ug_weak(p_fight, m.owner_id) ->> 'deal')::numeric; end if;
      if m.job_key = 'spearman' and coalesce(m.stats ->> 'style', 'melee') = 'melee' then
        d := d * public.world_spear_mul(m.owner_id, coalesce((vfx ->> 'spch')::int, 0), f.hp, f.max_hp);
        vfx := vfx || jsonb_build_object('spch', least((public.world_spear_rules() ->> 'max')::int, coalesce((vfx ->> 'spch')::int, 0) + 1));
        update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;
      end if;$q$]);

select pg_temp.yh_fix('world_raid_action', array[
  $q$  update public.world_characters set spiritual_power = sp, inventory = inv, updated_at = now() where owner_id = uid;$q$,
  $q$  update public.world_characters set spiritual_power = sp, inventory = inv,
    health = case when health > 0 then least(100, health + coalesce(nullif(current_setting('yh.leech', true), '')::int, 0)) else health end, updated_at = now() where owner_id = uid;
  perform set_config('yh.leech', '', true);$q$,
  $q$    k := sk.effect ->> 'type'; v := sk.effect;$q$,
  $q$    k := sk.effect ->> 'type'; v := sk.effect;
    if k in ('shield', 'shield_all') and v ? 'amt' then v := v || jsonb_build_object('amt', public.world_shield_amt(uid, (v ->> 'amt')::numeric)); end if;$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
  $q$    if e ? 'amt' then
      e := e || jsonb_build_object('amt', round((e ->> 'amt')::int * (1 + coalesce((select (x.skill_progress -> 'first_aid' ->> 'rank')::int from public.world_characters x where x.owner_id = m.owner_id), 0) / 100.0)));
    end if;$q$,
  $q$    if e ? 'amt' and e ->> 'type' in ('shield', 'shield_all') then
      e := e || jsonb_build_object('amt', public.world_shield_amt(m.owner_id, (e ->> 'amt')::numeric));
    elsif e ? 'amt' then
      e := e || jsonb_build_object('amt', round((e ->> 'amt')::int * (1 + coalesce((select (x.skill_progress -> 'first_aid' ->> 'rank')::int from public.world_characters x where x.owner_id = m.owner_id), 0) / 100.0)));
    end if;$q$]);

select pg_temp.yh_fix('world_gw_hurt', array[
  $q$declare m public.world_gw_members%rowtype; d int := greatest(0, p_dmg); v_n int; v_out int;$q$,
  $q$declare m public.world_gw_members%rowtype; d int := greatest(0, p_dmg); v_n int; v_out int; bk public.world_gw_members%rowtype;$q$,
  $q$  if m.hp - d <= 0 then
    -- $q$,
  $q$  if m.hp - d <= 0 and m.hp > 1 then
    select * into bk from public.world_gw_members w where w.fight_id = p_fight and w.owner_id <> p_uid and w.job_key = 'bloodknight' and w.out_rounds = 0 and not w.rest and w.hp > 20
       and not coalesce((w.fx ->> 'oath')::boolean, false) and 'bloodcraft_c43b' = any (public.world_skill_procs(w.owner_id)) order by w.joined_at limit 1 for update;
    if found then
      update public.world_gw_members set hp = hp - 20, taken = taken + 20, fx = fx || '{"oath": true}'::jsonb where fight_id = p_fight and owner_id = bk.owner_id;
      d := m.hp - 1;
      perform public.world_gw_say(p_fight, p_round, 'good', bk.name || ' — 「피로 잇는 맹세」 제 피 20을 내어 ' || m.name || '을(를) 버티게 했습니다.');
    end if;
  end if;
  if m.hp - d <= 0 then
    -- $q$]);

select pg_temp.yh_fix('world_raid_hit', array[
  $q$  update public.world_characters set health = greatest(1, health - d), updated_at = now() where owner_id = who returning health into hp;$q$,
  $q$  if d > 0 and (select ch.health from public.world_characters ch where ch.owner_id = who) - d <= 1 then
    perform 1 from public.world_raid_members bm join public.world_characters bc on bc.owner_id = bm.owner_id
     where bm.raid_id = p_raid and bm.owner_id <> who and bc.job_key = 'bloodknight' and bc.health > 21 and bm.out_until is null and bm.left_at is null
       and not coalesce((bm.fx ->> 'oath')::boolean, false) and 'bloodcraft_c43b' = any (public.world_skill_procs(bm.owner_id)) limit 1;
    if found then
      with b as (select bm.owner_id from public.world_raid_members bm join public.world_characters bc on bc.owner_id = bm.owner_id
                  where bm.raid_id = p_raid and bm.owner_id <> who and bc.job_key = 'bloodknight' and bc.health > 21 and bm.out_until is null and bm.left_at is null
                    and not coalesce((bm.fx ->> 'oath')::boolean, false) and 'bloodcraft_c43b' = any (public.world_skill_procs(bm.owner_id)) order by bm.owner_id limit 1),
           u1 as (update public.world_raid_members x set fx = x.fx || '{"oath": true}'::jsonb, taken = x.taken + 20 from b where x.raid_id = p_raid and x.owner_id = b.owner_id returning x.owner_id)
      update public.world_characters ch set health = ch.health - 20, updated_at = now() from u1 where ch.owner_id = u1.owner_id;
      d := greatest(0, (select ch.health from public.world_characters ch where ch.owner_id = who) - 2);
      perform public.world_raid_say_n(p_raid, 'good', nm || ' — 「피로 잇는 맹세」로 쓰러지지 않고 버텼습니다.', nm, 0);
    end if;
  end if;
  update public.world_characters set health = greatest(1, health - d), updated_at = now() where owner_id = who returning health into hp;$q$]);

select pg_temp.yh_fix('world_expedition_settle', array[
  $q$        if c.job_key = 'analyst' and random() < 0.25 then$q$,
  $q$        if c.job_key = 'spearman' and random() < 0.3 then
          win_p := win_p + 0.1; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[새벽 돌파] 요괴가 다가오기 전에 창끝이 먼저 닿습니다.');
        end if;
        if c.job_key = 'analyst' and random() < 0.25 then$q$,
  $q$        hp := hp - my_taken;$q$,
  $q$        if c.job_key = 'formation' and my_taken > 0 and random() < 0.3 then
          my_taken := round(my_taken * 0.7)::int; er := greatest(0, er - 1); jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[길흉 셈] 미리 셈해 둔 자리로 비켜서 피해를 덜었습니다.');
        end if;
        hp := hp - my_taken;
        if c.job_key = 'bloodknight' and my_taken > 0 and hp > 0 and random() < 0.25 then
          hp := least(100, hp + greatest(1, my_taken / 2)); jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '[베어 버티기] 베어 낸 기운으로 받은 상처의 절반을 되찾았습니다.');
        end if;$q$]);

create table if not exists public.world_gear_sets (
  owner_id uuid not null,
  n integer not null check (n between 1 and 20),
  name text not null,
  items jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (owner_id, n)
);
alter table public.world_gear_sets enable row level security;
revoke all on public.world_gear_sets from anon, authenticated;
grant select, insert, update, delete on public.world_gear_sets to fn_owner_field;

create or replace function public.world_gear_set_rules() returns jsonb language sql immutable as $$
  select jsonb_build_object('base', 4, 'max', 10, 'rank', 15, 'name_max', 12)
$$;

create or replace function public.world_gear_set_cap(p_uid uuid) returns integer language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare r jsonb := public.world_gear_set_rules(); n int;
begin
  select count(*) into n from public.world_characters c, unnest(public.world_combat_lines()) l
   where c.owner_id = p_uid and coalesce((c.skill_progress -> l ->> 'rank')::int, 1) >= (r ->> 'rank')::int;
  return least((r ->> 'max')::int, (r ->> 'base')::int + coalesce(n, 0));
end $$;

create or replace function public.world_gear_set_list() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object('cap', public.world_gear_set_cap(uid), 'rules', public.world_gear_set_rules(),
    'sets', coalesce((select jsonb_agg(jsonb_build_object('n', s.n, 'name', s.name, 'items', s.items, 'at', s.updated_at) order by s.n) from public.world_gear_sets s where s.owner_id = uid), '[]'::jsonb));
end $$;

create or replace function public.world_gear_set_save(p_n integer, p_name text) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); nm text := btrim(coalesce(p_name, '')); its jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_n is null or p_n < 1 or p_n > public.world_gear_set_cap(uid) then raise exception '쓸 수 없는 세트 칸입니다.'; end if;
  if nm = '' then nm := coalesce((select s.name from public.world_gear_sets s where s.owner_id = uid and s.n = p_n), '세트 ' || p_n); end if;
  if char_length(nm) > (public.world_gear_set_rules() ->> 'name_max')::int then raise exception '세트 이름은 %자까지입니다.', public.world_gear_set_rules() ->> 'name_max'; end if;
  select coalesce(jsonb_object_agg(e.slot, e.item_id), '{}'::jsonb) into its from public.world_character_equipment e where e.owner_id = uid;
  insert into public.world_gear_sets(owner_id, n, name, items, updated_at) values (uid, p_n, nm, its, now())
  on conflict (owner_id, n) do update set name = excluded.name, items = excluded.items, updated_at = now();
  return jsonb_build_object('ok', true, 'n', p_n, 'name', nm, 'items', its);
end $$;

create or replace function public.world_gear_set_rename(p_n integer, p_name text) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); nm text := btrim(coalesce(p_name, ''));
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if nm = '' or char_length(nm) > (public.world_gear_set_rules() ->> 'name_max')::int then raise exception '세트 이름은 1~%자입니다.', public.world_gear_set_rules() ->> 'name_max'; end if;
  update public.world_gear_sets set name = nm, updated_at = now() where owner_id = uid and n = p_n;
  if not found then raise exception '저장한 세트가 없습니다.'; end if;
  return jsonb_build_object('ok', true, 'n', p_n, 'name', nm);
end $$;

create or replace function public.world_gear_set_clear(p_n integer) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  delete from public.world_gear_sets where owner_id = uid and n = p_n;
  return jsonb_build_object('ok', true, 'n', p_n);
end $$;

create or replace function public.world_gear_set_apply(p_n integer) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); s public.world_gear_sets%rowtype; inv jsonb; k text; v text; pick text; done jsonb := '[]'::jsonb; skip jsonb := '[]'::jsonb; msg text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into s from public.world_gear_sets where owner_id = uid and n = p_n;
  if not found then raise exception '저장한 세트가 없습니다.'; end if;
  for k, v in select key, value #>> '{}' from jsonb_each(s.items) loop
    if exists (select 1 from public.world_character_equipment e where e.owner_id = uid and e.slot = k and e.item_id = v) then continue; end if;
    select inventory into inv from public.world_characters where owner_id = uid;
    pick := case when coalesce((inv ->> v)::int, 0) > 0 then v
                 when v like '%\_hq' and coalesce((inv ->> public.world_item_base(v))::int, 0) > 0 then public.world_item_base(v)
                 when v not like '%\_hq' and coalesce((inv ->> (v || '_hq'))::int, 0) > 0 then v || '_hq' end;
    if pick is null then
      skip := skip || jsonb_build_object('slot', k, 'item', v, 'why', '가진 물품이 없습니다.'); continue;
    end if;
    begin
      perform public.world_equip_item(pick);
      done := done || jsonb_build_object('slot', k, 'item', pick);
    exception when others then
      get stacked diagnostics msg = message_text;
      skip := skip || jsonb_build_object('slot', k, 'item', pick, 'why', msg);
    end;
  end loop;
  return jsonb_build_object('ok', true, 'n', p_n, 'name', s.name, 'equipped', done, 'skipped', skip);
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.world_gear_set_cap(uuid)', 'public.world_gear_set_list()', 'public.world_gear_set_save(integer, text)', 'public.world_gear_set_rename(integer, text)',
                           'public.world_gear_set_clear(integer)', 'public.world_gear_set_apply(integer)'] loop
    perform pg_temp.yh_own(f, 'fn_owner_field');
    perform pg_temp.yh_share(f);
  end loop;
end $$;
grant execute on function public.world_gear_set_list(), public.world_gear_set_save(integer, text), public.world_gear_set_rename(integer, text),
  public.world_gear_set_clear(integer), public.world_gear_set_apply(integer) to authenticated;
grant execute on function public.world_gear_set_rules() to authenticated;

select pg_temp.yh_fix('world_character_purge', array[$q$delete from public.world_title_presets where owner_id = p_uid;$q$,
  $q$delete from public.world_title_presets where owner_id = p_uid;
  delete from public.world_gear_sets where owner_id = p_uid;$q$]);

create table if not exists public.world_job_changes (
  owner_id uuid primary key,
  changed_at timestamptz not null default now()
);
alter table public.world_job_changes enable row level security;
revoke all on public.world_job_changes from anon, authenticated;
grant select, insert, update, delete on public.world_job_changes to fn_owner_field;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn\_owner%' loop execute format('grant select, insert, update, delete on public.world_job_changes to %I', r); end loop;
end $$;

create or replace function public.world_job_change_rules() returns jsonb language sql immutable as $$
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
      'formation', jsonb_build_array('spirit_affinity', 'willpower', 'perception')),
    'weapon', jsonb_build_object('artificer', 'iron_sword', 'bloodknight', 'w_melee1_heavy', 'analyst', 'w_melee1_keen', 'spearman', 'w_spear1_b',
      'scout', 'w_ranged1_keen', 'tamer', 'short_bow', 'exorcist', 'spirit_bell', 'sealmaster', 'w_magic1_heavy', 'medic', 'w_magic1_silent', 'formation', 'w_magic1_keen'))
$$;
grant execute on function public.world_job_change_rules() to authenticated;

create or replace function public.world_job_change_until(p_uid uuid) returns timestamptz language sql stable security definer set search_path = pg_catalog, public as $$
  select j.changed_at + make_interval(mins => (public.world_job_change_rules() ->> 'cd_min')::int) from public.world_job_changes j
   where j.owner_id = p_uid and j.changed_at + make_interval(mins => (public.world_job_change_rules() ->> 'cd_min')::int) > now()
$$;

create or replace function public.world_job_change_status() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); lv int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select level into lv from public.world_characters where owner_id = uid;
  return jsonb_build_object('until', public.world_job_change_until(uid),
    'price', (public.world_job_change_rules() ->> 'price_base')::int + (public.world_job_change_rules() ->> 'price_lv')::int * coalesce(lv, 1));
end $$;

create or replace function public.world_reset_identity(p_job text, p_faction text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; back int; job_label text; off_items text[];
  r jsonb := public.world_job_change_rules(); pts int; st text; cur int; cap int; add int; vals jsonb; until timestamptz; wpn text; got_wpn boolean := false;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce((c.inventory ->> 'reset_identity')::int, 0) < 1 then raise exception '환골탈태 서첩이 없습니다.'; end if;
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 쓸 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then raise exception '원정 중에는 쓸 수 없습니다.'; end if;
  until := public.world_job_change_until(uid);
  if until is not null then
    raise exception '직업을 바꾼 지 얼마 되지 않았습니다. %분 뒤에 다시 쓸 수 있습니다.', ceil(extract(epoch from until - now()) / 60)
      using hint = 'cd:' || ceil(extract(epoch from until - now()))::int;
  end if;
  job_label := public.world_job_label(p_job);
  if job_label is null then raise exception '직업을 고르세요.'; end if;
  if p_job = c.job_key then raise exception '지금과 같은 직업입니다.'; end if;
  back := public.world_reset_points(uid);
  select array_agg(e.item_id) into off_items from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
   where e.owner_id = uid and ((i.required_job is not null and i.required_job <> p_job) or not public.world_weapon_job_ok(i.category, i.equipment_traits, p_job));
  delete from public.world_character_equipment e using public.world_item_catalog i
   where e.owner_id = uid and i.item_id = e.item_id and ((i.required_job is not null and i.required_job <> p_job) or not public.world_weapon_job_ok(i.category, i.equipment_traits, p_job));
  vals := public.world_job_base(p_job);
  select stat_points + back into pts from public.world_characters where owner_id = uid;
  for st in select jsonb_array_elements_text(r -> 'alloc' -> p_job) loop
    exit when pts <= 0;
    cur := (vals ->> st)::int;
    cap := public.world_stat_cap_of(p_job, st, c.level);
    add := greatest(0, least(pts, cap - cur));
    vals := jsonb_set(vals, array[st], to_jsonb(cur + add));
    pts := pts - add;
  end loop;
  wpn := r -> 'weapon' ->> p_job;
  update public.world_characters
     set job_key = p_job, occupation = job_label,
         strength = (vals ->> 'strength')::int, agility = (vals ->> 'agility')::int, vitality = (vals ->> 'vitality')::int, perception = (vals ->> 'perception')::int,
         willpower = (vals ->> 'willpower')::int, spirit_affinity = (vals ->> 'spirit_affinity')::int, stat_points = pts,
         inventory = case when (inventory ->> 'reset_identity')::int <= 1 then inventory - 'reset_identity' else jsonb_set(inventory, '{reset_identity}', to_jsonb((inventory ->> 'reset_identity')::int - 1)) end,
         updated_at = now()
   where owner_id = uid;
  if wpn is not null and not exists (select 1 from public.world_characters x, jsonb_each(x.inventory) iv join public.world_item_catalog ic on ic.item_id = iv.key
                                      where x.owner_id = uid and ic.category = 'weapon' and public.world_weapon_job_ok(ic.category, ic.equipment_traits, p_job)) then
    update public.world_characters set inventory = inventory || jsonb_build_object(wpn, coalesce((inventory ->> wpn)::int, 0) + 1) where owner_id = uid;
    got_wpn := true;
  end if;
  insert into public.world_job_changes(owner_id, changed_at) values (uid, now()) on conflict (owner_id) do update set changed_at = now();
  return jsonb_build_object('ok', true, 'refunded', back, 'left_points', pts, 'stats', vals, 'weapon', case when got_wpn then wpn end,
    'unequipped', coalesce(to_jsonb(off_items), '[]'::jsonb),
    'content', format('%s(으)로 새 길을 걷습니다. 레벨로 받은 능력치를 새 직업에 맞게 다시 놓았습니다.%s%s%s', job_label,
      case when got_wpn then ' ' || (select item_name from public.world_item_catalog where item_id = wpn) || '을(를) 받았습니다.' else '' end,
      case when off_items is not null then ' 새 직업이 쓸 수 없는 장비는 벗었습니다.' else '' end,
      case when pts > 0 then ' 주 능력치가 상한에 닿아 남은 ' || pts || '점은 캐릭터 › 성장에서 직접 나누세요.' else '' end));
end
$function$;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, 'reset_identity', 100, 99, 99, null from (select distinct shop_id from public.world_shop_catalog where shop_id <> 'smithy') s
on conflict do nothing;
delete from public.world_shop_catalog where item_id = 'ammo_bolt';

select pg_temp.yh_fix('world_shop_refresh', array[$q$'ammo_bolt', $q$, $q$'reset_identity', $q$]);

select pg_temp.yh_fix('world_shop_buy', array[$q$  total := s.unit_price * p_qty;$q$,
  $q$  if p_item_id = 'reset_identity' then s.unit_price := (public.world_job_change_rules() ->> 'price_base')::int + (public.world_job_change_rules() ->> 'price_lv')::int * c.level; end if;
  total := s.unit_price * p_qty;$q$]);

select pg_temp.yh_fix('world_shop_snapshot', array[$q$'unit_price', ss.unit_price,$q$,
  $q$'unit_price', case when ss.item_id = 'reset_identity' then (public.world_job_change_rules() ->> 'price_base')::int + (public.world_job_change_rules() ->> 'price_lv')::int * coalesce((select x.level from public.world_characters x where x.owner_id = public.fn_owner_auth_uid()), 1) else ss.unit_price end,$q$]);

update public.world_faction_vault set item_id = 'reset_stats' where item_id = 'reset_identity';
update public.world_item_catalog set description = '레벨로 받은 능력치 포인트를 모두 돌려받아 다시 나눈다. 직업은 그대로다.' where item_id = 'reset_stats';
update public.world_item_catalog set description = '직업을 새로 고른다. 레벨로 받은 능력치는 새 직업의 주 능력치에 맞게 저절로 놓이고, 소속·레벨·기술 단계는 그대로다. 쓴 뒤 1시간은 다시 쓸 수 없다.', reference_price = 100 where item_id = 'reset_identity';

do $$
declare f text;
begin
  foreach f in array array['public.world_job_change_until(uuid)', 'public.world_job_change_status()'] loop
    perform pg_temp.yh_own(f, 'fn_owner_field');
    perform pg_temp.yh_share(f);
  end loop;
end $$;
grant execute on function public.world_job_change_status() to authenticated;

select pg_temp.yh_fix('world_character_purge', array[$q$  delete from public.world_gear_sets where owner_id = p_uid;$q$,
  $q$  delete from public.world_gear_sets where owner_id = p_uid;
  delete from public.world_job_changes where owner_id = p_uid;$q$]);

select pg_temp.yh_fix('world_hud_snapshot', array[$q$'bijang', public.world_bijang_brief(uid),$q$, $q$'bijang', public.world_bijang_brief(uid), 'job_cd', public.world_job_change_until(uid),$q$]);

alter table public.world_idle_activities add column if not exists skill_line text;

create or replace function public.world_idle_choices(p_uid uuid) returns jsonb
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare c public.world_characters%rowtype; tr text[]; mt text[] := array['smithing', 'carpentry', 'artifice', 'wardcraft', 'weaving', 'leatherwork', 'alchemy', 'cooking'];
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if not found then return null; end if;
  tr := array[coalesce(public.world_job_line(c.job_key), 'melee'), 'guarding', 'first_aid', 'analysis'];
  return jsonb_build_object(
    'training', (select jsonb_agg(jsonb_build_object('line', l, 'name', public.world_line_name(l)) order by o) from unnest(tr) with ordinality u(l, o)),
    'maintenance', (select jsonb_agg(jsonb_build_object('line', l, 'name', public.world_line_name(l)) order by o) from unnest(mt) with ordinality u(l, o)),
    'default', jsonb_build_object('training', public.world_idle_skill_for(p_uid, 'training'), 'maintenance', public.world_idle_skill_for(p_uid, 'maintenance')));
end $$;
select pg_temp.yh_own('public.world_idle_choices(uuid)', 'fn_owner_field');
select pg_temp.yh_share('public.world_idle_choices(uuid)');

select pg_temp.yh_fix('world_start_idle_activity', array[
  $q$ insert into public.world_idle_activities(owner_id,activity_type,duration_minutes) values(public.fn_owner_auth_uid(),p_activity,p_duration_minutes) returning id into v_id;$q$,
  $q$ insert into public.world_idle_activities(owner_id,activity_type,duration_minutes,skill_line) values(public.fn_owner_auth_uid(),p_activity,p_duration_minutes,nullif(current_setting('yh.idle_line', true), '')) returning id into v_id;
 perform set_config('yh.idle_line', '', true);$q$]);

create or replace function public.world_start_idle_activity(p_activity text, p_duration_minutes integer, p_line text)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); ch jsonb; ln text := nullif(btrim(coalesce(p_line, '')), '');
begin
  if uid is null then raise exception '로그인 후 이용할 수 있습니다.'; end if;
  if ln is not null then
    if p_activity not in ('training', 'maintenance') then raise exception '기술은 수련과 정비에서만 고를 수 있습니다.'; end if;
    ch := public.world_idle_choices(uid);
    if not exists (select 1 from jsonb_array_elements(ch -> p_activity) x where x ->> 'line' = ln) then raise exception '고를 수 없는 기술입니다.'; end if;
  end if;
  perform set_config('yh.idle_line', coalesce(ln, ''), true);
  return public.world_start_idle_activity(p_activity, p_duration_minutes);
end $$;
select pg_temp.yh_own('public.world_start_idle_activity(text, integer, text)', 'fn_owner_19180');
select pg_temp.yh_share('public.world_start_idle_activity(text, integer, text)');
grant execute on function public.world_start_idle_activity(text, integer, text) to authenticated;

select pg_temp.yh_fix('world_claim_idle_activity', array[
  $q$ v_skill:=public.world_idle_skill_for(v.owner_id, v.activity_type);$q$,
  $q$ v_skill:=coalesce(v.skill_line, public.world_idle_skill_for(v.owner_id, v.activity_type));$q$,
  $q$v_result:=jsonb_build_object('message','자율수련 완료','combat_xp',v_skill_xp,$q$,
  $q$v_result:=jsonb_build_object('message','자율수련 완료','skill_line',v_skill,'skill_name',public.world_line_name(v_skill),'combat_xp',v_skill_xp,$q$,
  $q$v_result:=jsonb_build_object('message','장비 정비 완료','crafting_xp',v_skill_xp,$q$,
  $q$v_result:=jsonb_build_object('message','장비 정비 완료','skill_line',v_skill,'skill_name',public.world_line_name(v_skill),'crafting_xp',v_skill_xp,$q$]);

create or replace function public.world_idle_info(p_activity text, p_line text) returns jsonb
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); ln text;
begin
  if uid is null then return null; end if;
  ln := case when p_activity is null then null else coalesce(p_line, public.world_idle_skill_for(uid, p_activity)) end;
  return jsonb_build_object('skill_line', ln, 'skill_name', case when ln is not null then public.world_line_name(ln) end, 'choices', public.world_idle_choices(uid));
end $$;
select pg_temp.yh_own('public.world_idle_info(text, text)', 'fn_owner_field');
select pg_temp.yh_share('public.world_idle_info(text, text)');
grant execute on function public.world_idle_info(text, text) to authenticated;

select pg_temp.yh_fix('world_idle_activity_snapshot', array[
  $q$ if not found then return jsonb_build_object('active',false); end if;$q$,
  $q$ if not found then return jsonb_build_object('active',false) || coalesce(public.world_idle_info(null, null), '{}'::jsonb); end if;$q$,
  $q$ 'ready',now()>=v.started_at+make_interval(mins=>v.duration_minutes));$q$,
  $q$ 'ready',now()>=v.started_at+make_interval(mins=>v.duration_minutes)) || coalesce(public.world_idle_info(v.activity_type, v.skill_line), '{}'::jsonb);$q$]);

insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:bk_arong', '대장간 도제 아롱', '늙은 근위병의 손녀. 열다섯 살로, 잔불촌 대장장이 쇠불 밑에서 망치를 배움. 씩씩한 해요체, 말하면서도 손을 쉬지 않음') on conflict (npc_key) do nothing;
insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:bk_gangseok', '늙은 근위병', '잔불촌에 사는 일흔 노인, 남녘 왕궁 근위대에서 살아남은 마지막 사람. 이름 강석은 둘째 편에서 처음 불림. 숨을 끊어 가며 말하는 반말, 말끝을 「…지」로 자주 맺음') on conflict (npc_key) do nothing;
insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:bk_sipjang', '근위 십장의 넋', '서른 해 전 혈엽림 길목에서 근위 넷과 함께 행렬 뒤를 막다 쓰러진 근위대 십장. 제 이름은 끝까지 밝히지 않음. 옛 군대 말투의 하오체, 말이 짧음') on conflict (npc_key) do nothing;
insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:dh_heojuhak', '출납 서리 허주학', '일흔 가까운 정청 출납청 서리. 젊을 때 흑련회 장부방에서 산가지 셈을 배웠고, 맡긴 이름을 도로 찾아 나와 정청에 들었다. 느릿한 하게체') on conflict (npc_key) do nothing;
insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:sx_changbok', '늙은 창잡이 창복', '일흔을 넘긴 수향 뱃사람. 마흔 해 동안 구름나루 새벽 첫 배 앞머리에 섰다. 짧고 퉁명스러운 반말, 기분이 좋으면 말이 길어짐') on conflict (npc_key) do nothing;
insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:sx_haedeun', '수문지기 도제 해든', '창복의 외손자, 스무 살. 조막심에게 배운 딱딱한 하십시오체, 당황하면 반말이 튀어나옴') on conflict (npc_key) do nothing;
insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:sx_nameoji', '흑련 셈꾼 나머지', '허주학과 장부방에서 함께 산가지를 배운 노파. 이름은 회원 장부에 맡겨 두었다. 셈 말이 입에 붙은 빠른 해요체') on conflict (npc_key) do nothing;
insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:sx_neodeol', '지관 너덜', '지맥의 뿌리 갱 밑에 사는 늙은 지관. 흑련 굴꾼들의 갱도 자리를 나경으로 잡아 주며 산다. 흑련 회원은 아니다. 투박한 반말, 땅에 빗댄 말을 즐겨 씀') on conflict (npc_key) do nothing;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq_bloodknight', 'side', '직업·혈기사', '피로 지킨 문', '잔불촌의 늙은 근위병이 베면서 버티는 싸움법을 가르친다.', 'west_gate', 3, '{}'::text[], null, 908, '[]'::jsonb, true, 'bloodknight', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_bloodknight', 1, '객사 마루의 숫돌', '객사 마루의 숫돌', '{"at": ["hq_dorm"]}'::jsonb, '[{"s": null, "t": "해가 막 진 본부 객사 마루 끝에 백발 노인 하나가 앉아 있었다. 노인은 무릎에 얹은 도끼날을 숫돌로 천천히 갈았고, 쇠 가는 소리가 저녁밥 짓는 냄새 사이로 사각사각 번졌다."}, {"s": null, "t": "노인은 내 허리에 걸린 무쇠 도끼를 보더니 숫돌을 내려놓았다. 노인의 왼손 손등부터 소매 속까지 오래된 칼자국이 겹겹이 나 있었다."}, {"s": "q:bk_gangseok", "t": "정청 장부에 「혈기사」라는 줄이 새로 생겼다길래 잔불촌에서 여기까지 걸어 올라왔지. 그게 너로구나."}, {"s": "q:bk_gangseok", "t": "남녘이 무너지기 전에 나는 왕궁 근위였다. 남녘 사람들은 우리를 혈기사라고 불렀지. 말이 쓰러져도 제 피를 갑주 삼아 문 앞에 섰다고 해서."}, {"s": null, "t": "나는 방패도 없이 어떻게 문을 지켰느냐고 물었다."}, {"s": null, "t": "노인은 도끼 자루로 마룻바닥을 쿵 하고 한 번 찍었다."}, {"s": "q:bk_gangseok", "t": "방패는 남을 가려 주는 물건이야. 그건 호위 무사들 몫이지. 우리는 베면서 버텼다. 한 번 벨 때마다 놈의 기운을 조금씩 내 피로 끌어오는 거야. 맞은 만큼 도로 마시면 몸이 안 무너지거든."}, {"s": "q:bk_gangseok", "t": "말로 배울 일은 아니지. 서문 폐성벽 해자에 악어귀가 산다. 껍데기가 두꺼워서 밀어 봐야 꿈쩍도 안 하는 놈들이야. 피하지 말고 맞으면서 세 마리만 쪼개 와라."}, {"s": null, "t": "나는 도끼를 고쳐 메고 서문 폐성벽으로 가겠다고 했다. 노인은 숫돌을 품에 넣고 지팡이 대신 도끼를 짚으며 일어섰다."}, {"s": "q:bk_gangseok", "t": "나도 간다. 문이 있는 데라면 아직 내 발로 걸어가지."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_bloodknight', 2, '쪼개진 등껍데기', '해자 악어귀을(를) 물리친다', '{"at": ["west_gate"], "tasks": [{"t": "win", "m": ["g_west_gate"], "n": 3}]}'::jsonb, '[{"s": null, "t": "해자의 물비린내가 무너진 성벽 밑동까지 차올라 있었다. 노인은 마지막 악어귀의 갈라진 등껍데기를 도끼 끝으로 뒤집어 보고 코웃음을 쳤다."}, {"s": "q:bk_gangseok", "t": "팔뚝에 성한 데가 하나도 없구나. 그래도 아직 서 있네. 몇 대나 맞았는지 세어 봤냐?"}, {"s": null, "t": "나는 세지 못했다고 했다. 다만 벨 때마다 쑤시던 팔이 조금씩 덜 아팠다고 했다."}, {"s": null, "t": "노인은 성벽 돌에 등을 기대며 짧게 웃었다."}, {"s": "q:bk_gangseok", "t": "그게 피를 마시는 맛이야. 처음엔 다들 그런 줄도 모르고 지나가지."}, {"s": null, "t": "그때 성벽 위 무너진 망루에서 쇠 긁히는 소리가 들렸다. 녹슨 창을 든 그림자 둘이 성문이 있던 자리 앞을 천천히 오가고 있었다."}, {"s": null, "t": "노인은 한참 동안 그 그림자들을 올려다보았다. 노인의 턱이 단단하게 굳었다."}, {"s": "q:bk_gangseok", "t": "이 나라 수비병들이로군. 문이 무너진 줄도 모르고 아직 문을 지키고 있어. 나랑 다를 게 없지."}, {"s": "q:bk_gangseok", "t": "저것들도 제가 지키던 문을 기억할 게다. 성벽을 두어 번 돌면서 성문이 서 있던 자리부터 찾아 봐라. 그다음에 녹슨 창귀 둘을 쉬게 해 주고."}]'::jsonb, '{"xp": 54}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_bloodknight', 3, '앞에 두르는 피', '서문 폐성벽을(를) 살핀다, 녹슨 창귀을(를) 물리친다', '{"at": ["west_gate"], "tasks": [{"t": "search", "r": ["west_gate"], "n": 2}, {"t": "win", "m": ["x_west_gate_2"], "n": 2}]}'::jsonb, '[{"s": null, "t": "성문이 서 있던 자리에는 돌 틈에 박힌 경첩 하나만 남아 있었다. 녹슨 창귀가 흩어진 자리에서 쇠녹 가루가 바람에 날렸다."}, {"s": null, "t": "노인은 경첩 앞에 쪼그려 앉아 녹을 손톱으로 긁어냈다. 노인의 손가락 끝이 쇠녹으로 붉게 물들었다."}, {"s": "q:bk_gangseok", "t": "창귀 하나가 쓰러지면서 내 쪽으로 창을 들이밀더구나. 네가 그 앞을 막아서는 걸 봤다."}, {"s": null, "t": "나는 막아서는 순간 몸 앞에 피가 얇게 굳어 갑주처럼 둘러졌다고 했다. 그 대신 숨이 한 번 턱 막혔다고도 했다."}, {"s": null, "t": "노인은 고개를 천천히 끄덕이고 왼팔 소매를 걷어 올렸다. 팔뚝의 칼자국 가운데 몇은 남이 벤 자국이 아니라 노인이 스스로 그은 자국이었다."}, {"s": "q:bk_gangseok", "t": "그게 피 갑주다. 제 피를 덜어서 앞에 두르는 거지. 덜어 낸 만큼 몸은 가벼워지고 숨은 무거워져. 그래서 혈기사는 쉬는 법도 알아야 한다."}, {"s": "q:bk_gangseok", "t": "오늘 밤은 여기서 한뎃잠을 자 봐라. 성벽 밑에서 한 번 쉬면서 덜어 낸 피를 도로 채우고, 성문 자리를 기웃거리는 파수망령 하나만 마저 보내 주고 와."}]'::jsonb, '{"xp": 54}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_bloodknight', 4, '두고 온 사람', '서문 폐성벽에서 쉰다, 성문 파수망령을(를) 물리친다', '{"at": ["west_gate"], "tasks": [{"t": "rest", "r": ["west_gate"], "n": 1}, {"t": "win", "m": ["m_west"], "n": 1}]}'::jsonb, '[{"s": null, "t": "새벽이슬이 성벽 돌에 맺혀서 손바닥이 닿는 곳마다 서늘했다. 파수망령이 사라진 자리에는 통행증처럼 생긴 낡은 나뭇조각 하나가 떨어져 있었다."}, {"s": null, "t": "노인은 나뭇조각을 주워 경첩 옆 돌 틈에 꽂아 두었다. 그러고는 도끼를 무릎에 가로 얹고 동쪽 하늘이 밝아 오는 것을 바라보았다."}, {"s": "q:bk_gangseok", "t": "남녘 왕궁이 무너지던 밤, 우리 근위는 피난 행렬을 이끌고 빠져나왔다. 쫓아오는 요괴 떼를 막으려고 동무들은 숲 길목에 남았지. 그런데 십장이 내 품에 불씨 항아리를 안기고 행렬 맨 앞으로 쫓아 보냈어. 어린 아들 둔 놈은 살아서 불을 날라야 한다면서."}, {"s": "q:bk_gangseok", "t": "그러니 나는 끝까지 길을 지킨 사람이 아니야. 동무들을 두고 온 사람이지. 서른 해를 그 생각만 하며 살았다."}, {"s": null, "t": "나는 어제 창귀 앞을 막아선 것도 노인에게 배운 대로 한 것이라고 했다. 노인이 살아서 걸어 나왔기에 그 싸움법이 내 손에까지 닿았다고도 했다."}, {"s": null, "t": "노인은 한참 말이 없다가 품에서 숫돌을 꺼냈다. 노인은 내 도끼를 건네받아 날을 몇 번 쓱쓱 갈아 주었다."}, {"s": "q:bk_gangseok", "t": "그러면 됐다. 문은 무너져도 문 앞에 서는 사람은 남는 법이지."}, {"s": "q:bk_gangseok", "t": "{이름}, 배울 게 아직 남았다. 도끼가 손에 붙거든 잔불촌으로 내려와라. 혈엽림에 내가 두고 온 사람들이 있어."}]'::jsonb, '{"xp": 54, "gil": 17, "items": {"tonic": 2, "travel_ration": 1}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq2_bloodknight', 'side', '직업·혈기사', '붉은 잎의 맹세', '혈엽림에 남은 근위대의 넋이 끝내지 못한 맹세를 붙들고 있다.', 'red_forest', 18, '{jq_bloodknight}'::text[], null, 1117, '[]'::jsonb, true, 'bloodknight', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_bloodknight', 1, '깨진 불씨 항아리', '깨진 불씨 항아리', '{"at": ["ember_village"]}'::jsonb, '[{"s": null, "t": "잔불촌은 집집마다 화로가 꺼지지 않아서 늦가을인데도 골목 안이 훈훈했다. 노인의 집 화롯가에는 아가리가 깨진 옹기 항아리 하나가 놓여 있었고, 항아리 바닥에서 숯 한 덩이가 붉게 숨을 쉬고 있었다."}, {"s": null, "t": "노인은 화로에 숯을 한 덩이 더 얹고 나를 맞았다. 노인의 숨이 서문에서보다 더 짧았다."}, {"s": "q:bk_gangseok", "t": "왔구나. 도끼 쥔 손을 보니 그새 굳은살이 박였네."}, {"s": "q:bk_gangseok", "t": "이게 그날 내가 안고 온 불씨 항아리다. 서문에서 말했지, 동무들을 숲 길목에 두고 왔다고. 그 숲이 혈엽림이다. 십장까지 다섯이 거기 남아서 베면서, 맞으면서, 마지막 한 사람이 쓰러질 때까지 길을 막았지."}, {"s": "q:bk_gangseok", "t": "혈엽림 잎이 그때부터 붉어졌다는 말이 남녘 사람들 사이에 돈다. 동무들이 흘린 피를 나무가 마셨다고."}, {"s": null, "t": "나는 그 숲에 지금도 무언가 남아 있느냐고 물었다."}, {"s": null, "t": "노인은 화로 불빛을 오래 들여다보다가 입을 열었다."}, {"s": "q:bk_gangseok", "t": "혈엽림을 지나는 나그네들이 갑주 입은 그림자를 봤다더군. 붉은 잎 사이에서 길을 막고 「못 지나간다」고 한다지. 그 사람들은 아직 맹세를 끝내지 못한 거야."}, {"s": "q:bk_gangseok", "t": "그날 밤 우리는 길목 나무에 도끼로 제 이름을 새겼다. 누가 어디서 쓰러졌는지 나중에라도 알아보라고. 네가 먼저 가서 그 나무들을 찾아 다오. 나는 다리가 굳어서 반나절은 늦을 거다."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_bloodknight', 2, '지워진 여섯째 이름', '혈엽림을(를) 살핀다', '{"at": ["red_forest"], "tasks": [{"t": "search", "r": ["red_forest"], "n": 3}]}'::jsonb, '[{"s": null, "t": "혈엽림 길목의 고목 여섯 그루에 도끼로 판 글자가 남아 있었다. 글자 홈마다 붉은 수액이 고여 있어서, 손끝을 대자 피처럼 끈적하게 묻어났다."}, {"s": null, "t": "다섯 그루에는 이름이 하나씩 새겨져 있었지만, 여섯째 나무에는 이름이 없었다. 누군가 새기다 만 획 위를 도끼날로 몇 번이나 긁어 지운 자국만 남아 있었다."}, {"s": null, "t": "반나절 뒤에 노인이 도끼를 짚고 길목에 닿았다. 노인은 여섯째 나무 앞에서 걸음을 멈추고 긁힌 자국을 손바닥으로 쓸었다."}, {"s": "q:bk_gangseok", "t": "이건 내 나무다. 그날 밤 나도 여기에 이름을 새기고 있었지. 그런데 십장이 내 손에서 도끼를 빼앗고 나를 행렬 쪽으로 떠밀었어."}, {"s": "q:bk_gangseok", "t": "다 새기지도 못한 내 이름을 십장이 지운 거로구나. 나를 맹세에서 빼 주려고. 서른 해 동안 그것도 몰랐다."}, {"s": null, "t": "그때 고목 사이에서 붉은 잎이 한꺼번에 일어섰다. 잎을 사람 모양으로 두른 혈엽수인들이 나무 밑동에 뿌리를 박고 글자 홈의 수액을 빨아들이고 있었다."}, {"s": null, "t": "노인은 도끼 자루를 움켜쥐며 이를 악물었다."}, {"s": "q:bk_gangseok", "t": "저놈들이 동무들 피를 아직도 빨아 먹고 있었구나. 저것들도 피를 마시는 놈들이야. 그러니 네가 더 빨리 마셔야 이긴다. 피가 절반 밑으로 빠져도 물러서지 말고, 베어서 도로 채워. 네 마리를 쓰러뜨려라."}]'::jsonb, '{"xp": 568}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_bloodknight', 3, '못 지나가오', '혈엽수인을(를) 물리친다', '{"at": ["red_forest"], "tasks": [{"t": "win", "m": ["m_21"], "n": 4}]}'::jsonb, '[{"s": null, "t": "마지막 혈엽수인이 쓰러지자 숲 안쪽에서 쇠 부딪치는 소리가 울렸다. 붉은 잎 사이로 갑주를 걸친 그림자 다섯이 걸어 나와 길목을 가로막았다. 맨 앞 그림자의 투구 끝에서 붉은 술이 흔들렸다."}, {"s": "q:bk_sipjang", "t": "거기 서시오. 이 길은 못 지나가오."}, {"s": null, "t": "나는 노인 앞으로 나서서 피 갑주를 둘렀다. 그림자들의 도끼가 내 앞의 붉은 막에 부딪혀 둔한 소리를 내며 튕겨 나갔다."}, {"s": null, "t": "노인은 내 어깨를 짚고 앞으로 나섰다. 노인은 나무에 새겨진 이름을 하나씩 불렀다. 목소리는 쉬어 있었지만 노인은 이름 하나 빼먹지 않았다."}, {"s": null, "t": "이름이 불릴 때마다 그림자가 하나씩 도끼를 내렸다. 마지막으로 맨 앞의 그림자가 투구를 벗었다."}, {"s": "q:bk_sipjang", "t": "…강석이오? 어린 아들 둔 그 강석이가 맞소?"}, {"s": null, "t": "노인은 대답 대신 무릎을 꿇었다. 노인의 어깨가 떨렸다."}, {"s": "q:bk_gangseok", "t": "접니다, 십장님. 서른 해 만에 왔습니다."}, {"s": null, "t": "십장의 넋은 노인을 내려다보다가 다시 길 아래쪽으로 고개를 돌렸다."}, {"s": "q:bk_sipjang", "t": "행렬은 어찌 되었소. 불씨는 고개를 넘었소? 그걸 모르니 우리는 아직 물러설 수가 없소."}, {"s": null, "t": "노인은 무릎을 짚고 일어나 나를 돌아보았다. 노인의 눈에 화롯불 같은 것이 일렁였다."}, {"s": "q:bk_gangseok", "t": "말로 해서는 안 믿을 거다. 저 사람들은 원래 그래. 불을 직접 보여 줘야 해. 잔불촌 화로에서 옮겨 붙인 불이라야 알아본다."}, {"s": "q:bk_gangseok", "t": "이 숲 나무에서 흐르는 수지를 세 덩이만 거둬 다오. 붉은 수지는 불이 오래 가지. 그걸로 홰를 매어야겠다. 잔불촌까지 같이 내려가자."}]'::jsonb, '{"xp": 568}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_bloodknight', 4, '서른 해 묵은 불', '부적목 수지을(를) 모은다, 부적목 수지을(를) 넘긴다', '{"at": ["ember_village"], "tasks": [{"t": "gather", "items": ["resin"], "r": ["red_forest"], "n": 3}], "give": {"resin": 3}}'::jsonb, '[{"s": null, "t": "잔불촌으로 내려오는 동안 노인은 한 번도 쉬자고 하지 않았다. 노인은 마을 한가운데 큰 화로 앞에 서서 내가 건넨 수지를 싸리 홰에 칭칭 감았다."}, {"s": null, "t": "노인은 깨진 불씨 항아리에서 숯을 집게로 꺼내 홰 끝에 대었다. 붉은 수지가 지글거리며 타올랐고, 송진 냄새와 매캐한 연기가 골목으로 번졌다."}, {"s": "q:bk_gangseok", "t": "그날 내가 안고 온 불이다. 서른 해 동안 이 마을 화로를 옮겨 다니면서 한 번도 안 꺼졌지."}, {"s": "q:bk_gangseok", "t": "이 홰는 네가 들어라. 내가 들면 손이 떨려서 십장이 걱정할 거다."}, {"s": null, "t": "나는 홰를 받아 들었다. 홰는 생각보다 무거웠고, 쥔 손바닥이 금세 뜨거워졌다."}, {"s": null, "t": "노인은 집 안에서 자루가 반쯤 부러진 도끼 한 자루를 꺼내 와 등에 묶었다."}, {"s": "q:bk_gangseok", "t": "숲에 다시 들면 사슴귀들이 불을 보고 달려들 거다. 핏빛 사슴귀는 불을 끄려고 뿔부터 들이밀지. 세 마리쯤 막아 내면서 길목까지 홰를 지켜 다오."}]'::jsonb, '{"xp": 568}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_bloodknight', 5, '내려놓은 도끼 다섯', '핏빛 사슴귀을(를) 물리친다', '{"at": ["red_forest"], "tasks": [{"t": "win", "m": ["g_red_forest"], "n": 3}]}'::jsonb, '[{"s": null, "t": "해가 지자 혈엽림의 붉은 잎이 홰 불빛을 받아 젖은 듯 번들거렸다. 마지막 사슴귀가 쓰러지자 길목에 다섯 그림자가 다시 늘어섰다."}, {"s": null, "t": "나는 홰를 높이 들어 십장의 넋 앞에 내밀었다. 불길이 숲 바람을 받아 크게 일렁였다."}, {"s": null, "t": "십장의 넋은 불 앞에 손바닥을 펴 보였다. 불빛은 넋의 손바닥을 그대로 뚫고 지나가 붉은 낙엽 위에 떨어졌다."}, {"s": "q:bk_sipjang", "t": "이 냄새를 아오. 남녘 왕궁 부엌 화로에서 나던 냄새요. 그 불이 아직 살아 있었구려."}, {"s": null, "t": "노인은 십장 앞에 서서 북쪽 고개 쪽을 가리켰다."}, {"s": "q:bk_gangseok", "t": "행렬은 고개를 넘었습니다. 잔불촌에 닿아서 집집마다 이 불을 나눠 붙였습니다. 서른 해 동안 한 집도 불을 꺼뜨리지 않았습니다. 십장님들이 지킨 길이 거기까지 이어졌습니다."}, {"s": null, "t": "다섯 그림자가 하나씩 도끼를 땅에 내려놓았다. 도끼날이 붉은 낙엽 속에 묻히는 소리가 사락사락 들렸다."}, {"s": "q:bk_sipjang", "t": "그러면 맹세는 끝났소. 이제야 물러설 수 있겠소."}, {"s": null, "t": "십장의 넋은 노인의 등에 묶인 부러진 도끼를 보았다. 넋은 그 도끼 자루를 한 번 쓰다듬었다."}, {"s": "q:bk_sipjang", "t": "강석이, 자네 이름을 지운 건 미안하오. 그 나무에 다시 새기지는 마시오. 자네 이름은 자네 식구들이 불러 줄 테니."}, {"s": null, "t": "넋들은 붉은 잎이 지는 쪽으로 천천히 흩어졌다. 길목에는 도끼 다섯 자루와 꺼지지 않은 홰만 남았다."}, {"s": null, "t": "노인은 도끼 다섯 자루를 하나씩 주워 이름이 새겨진 나무 밑동에 기대어 세웠다. 등에 묶은 제 부러진 도끼는 풀지 않았다."}, {"s": "q:bk_gangseok", "t": "내 것은 아직 내려놓을 때가 아니지. 이건 따로 쓸 데가 있어서 손녀한테 맡길 거다."}, {"s": "q:bk_gangseok", "t": "{이름}, 이 숲에서 또 갑주 입은 그림자가 길을 막거든 그건 저 사람들이 아니다. 저 사람들은 오늘 다 쉬러 갔어."}, {"s": "q:bk_gangseok", "t": "너는 서문에서 맞으면서 베는 법을 배웠고, 오늘은 남 앞에 피를 두르는 법을 썼다. 그거면 혈기사 일은 반은 한 거야. 나머지 반은 언제 물러설지 아는 거지."}]'::jsonb, '{"xp": 568, "gil": 77, "items": {"tonic": 2, "travel_ration": 1}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq3_bloodknight', 'side', '직업·혈기사', '꺼지지 않는 쇠', '늙은 근위병이 남긴 도끼날을 흑조 균열의 쇠로 다시 벼린다.', 'black_tide_rift', 32, '{jq2_bloodknight,mq_nine_gates}'::text[], null, 1184, '[]'::jsonb, true, 'bloodknight', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_bloodknight', 1, '금 간 도끼날', '금 간 도끼날', '{"at": ["ember_village"]}'::jsonb, '[{"s": null, "t": "잔불촌 대장간 앞마당에는 풀무 바람에 섞인 쇳가루가 반짝이며 날렸다. 앳된 도제 하나가 모루 앞에 쪼그려 앉아 자루가 부러진 도끼날을 망치로 톡톡 두드려 보고 있었다."}, {"s": null, "t": "도제는 나를 보자 망치를 내려놓고 앞치마에 손을 닦았다. 도제의 뺨에 숯검정이 길게 묻어 있었다."}, {"s": "q:bk_arong", "t": "조사원님이 할아버지를 혈엽림에 모시고 가 주신 분이죠? 저는 아롱이에요. 쇠불 아저씨 밑에서 망치를 배우고 있어요."}, {"s": "q:bk_arong", "t": "할아버지는 지난겨울에 화롯가에서 주무시다가 그대로 숨을 거두셨어요. 아프다는 말씀 한마디도 없이요."}, {"s": null, "t": "아롱은 도끼날을 두 손으로 들어 내게 보여 주었다. 날 한가운데로 머리카락 같은 금이 길게 나 있었다."}, {"s": "q:bk_arong", "t": "이게 할아버지가 남기신 도끼예요. 돌아가시기 며칠 전에 그러셨어요. 날을 다시 벼려서 잔불촌 어귀 문설주에 걸어 달라고요. 문지기는 문 앞에 있어야 한다고요."}, {"s": "q:bk_arong", "t": "그런데 금 간 날은 아무 쇠나 덧댄다고 붙지 않아요. 쇠불 아저씨 말로는 남녘 근위 도끼는 흑조 균열 자리에서 나는 쇠로 벼렸대요. 균열이 열리기 전에는 거기가 근위 대장간이 있던 강가였대요."}, {"s": null, "t": "나는 균열에 가서 그 쇠를 찾아오겠다고 했다."}, {"s": null, "t": "아롱은 앞치마를 벗어 망치와 함께 망태에 쑤셔 넣었다."}, {"s": "q:bk_arong", "t": "저도 같이 가요. 쇠는 두드려 봐야 알거든요. 할아버지가 적어 두신 글을 보니까 옛 대장간 터에 돌무지를 쌓아서 표시해 두셨더라고요. 균열을 몇 번 돌아보면서 그 돌무지부터 찾아 주세요."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_bloodknight', 2, '그을린 돌무지', '흑조 균열을(를) 살핀다', '{"at": ["black_tide_rift"], "tasks": [{"t": "search", "r": ["black_tide_rift"], "n": 3}]}'::jsonb, '[{"s": null, "t": "흑조 균열 가장자리는 발밑이 늘 축축했고, 갈라진 땅 틈으로 지도에 없는 별빛이 새어 올라왔다. 검은 물이 거꾸로 흐르는 바위 사이에 그을린 돌무지 하나가 무너지지 않고 서 있었다."}, {"s": null, "t": "아롱은 돌무지 앞에 무릎을 꿇고 돌 틈에서 녹슨 집게 하나를 꺼냈다. 아롱은 집게를 쥔 채 한참 동안 손을 놓지 않았다."}, {"s": "q:bk_arong", "t": "여기가 맞아요. 근위 대장간 집게예요. 할아버지 도끼 자루에 찍힌 것하고 같은 표식이 있어요."}, {"s": null, "t": "돌무지 뒤 바위벽에는 붉은 기운이 도는 쇳맥이 드러나 있었다. 그런데 검은 물결 촉수 여럿이 그 쇳맥을 칭칭 감고 있었다. 촉수가 조일 때마다 쇳돌에서 끼익 하는 소리가 났다."}, {"s": null, "t": "아롱은 집게를 품에 넣고 내 뒤로 물러섰다."}, {"s": "q:bk_arong", "t": "저것들이 쇳맥을 감고 있으면 쇠가 다 물러져요. 촉수를 걷어 내 주세요. 할아버지 말씀대로라면 혈기사는 맞으면서 베는 사람이잖아요. 저 촉수들이 사방에서 후려칠 텐데, 그럴수록 버티시는 거죠?"}, {"s": null, "t": "나는 그렇다고 했다."}, {"s": null, "t": "아롱은 씩 웃으며 망태에서 망치를 꺼내 들었다."}, {"s": "q:bk_arong", "t": "그럼 촉수 넷만 끊어 주세요. 그동안 저는 망을 볼게요. 촉수가 풀리면 생 월철을 네 덩이 캐 주시고요. 쇠는 날것일수록 옛 쇠하고 잘 붙어요."}]'::jsonb, '{"xp": 1548}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_bloodknight', 3, '거꾸로 떨어진 것', '검은 물결 촉수을(를) 물리친다, 생 월철을(를) 모은다', '{"at": ["black_tide_rift"], "tasks": [{"t": "win", "m": ["g_black_tide_rift"], "n": 4}, {"t": "gather", "items": ["raw_iron"], "r": ["black_tide_rift"], "n": 4}]}'::jsonb, '[{"s": null, "t": "내가 캔 생 월철을 손바닥에 올려 보이자 아롱은 망치 끝으로 한 덩이씩 두드려 보았다. 맑은 소리가 균열 벽에 부딪혀 길게 울렸다."}, {"s": "q:bk_arong", "t": "들리세요? 이렇게 우는 쇠가 좋은 쇠예요. 할아버지 도끼날도 처음엔 이렇게 울었을 거예요."}, {"s": null, "t": "그 순간 균열 너머 하늘에서 무언가가 거꾸로 떨어져 내렸다. 몸속에 낯선 별자리를 품은 커다란 덩어리 둘이 쇳맥 앞 바위를 짓누르며 내려앉았다. 바위 깨지는 소리가 쇠 우는 소리를 덮었다."}, {"s": null, "t": "아롱은 집게를 움켜쥐고 돌무지 뒤로 몸을 숨겼다."}, {"s": "q:bk_arong", "t": "역천 표류체예요! 쇠불 아저씨가 그랬어요, 저건 몸집이 커서 오히려 혈기사 도끼가 잘 먹힌다고요. 저걸 못 쓰러뜨리면 쇳맥이 통째로 깔려 버려요!"}, {"s": "q:bk_arong", "t": "다 끝나면 그 생 월철은 저한테 맡겨 주세요. 품에 넣어서 식지 않게 들고 갈게요."}]'::jsonb, '{"xp": 1548}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_bloodknight', 4, '혈기사의 손을 탄 쇠', '역천 표류체을(를) 물리친다, 생 월철을(를) 넘긴다', '{"at": ["black_tide_rift"], "tasks": [{"t": "win", "m": ["m_rift"], "n": 2}], "give": {"raw_iron": 4}}'::jsonb, '[{"s": null, "t": "쓰러진 역천 표류체의 몸에서 별빛 같은 가루가 흘러나와 균열 아래로 빨려 들어갔다. 쇳맥 앞 바위는 반쯤 깨졌지만 붉은 쇳줄은 무사했다."}, {"s": null, "t": "아롱은 돌무지 뒤에서 나와 내가 건넨 생 월철 네 덩이를 천으로 하나씩 싸서 망태에 넣었다."}, {"s": "q:bk_arong", "t": "이제 날에 덧댈 쇠는 됐어요. 그런데 날을 다시 벼리려면 바탕 쇠가 더 있어야 해요. 월철 주괴 여섯 개요."}, {"s": "q:bk_arong", "t": "주괴는 조사원님 손으로 녹여 주셨으면 해요. 할아버지가 그러셨거든요. 근위 도끼는 그 도끼를 들 사람이 바탕 쇠를 녹였다고요. 이제 이 도끼를 들 사람은 없지만, 할아버지한테 배운 혈기사의 손을 탄 쇠라면 할아버지도 좋아하실 거예요."}, {"s": null, "t": "나는 월철 광석을 녹여 주괴를 만든 뒤 잔불촌 대장간으로 가져가겠다고 했다."}, {"s": null, "t": "아롱은 고개를 크게 끄덕이고 녹슨 집게를 품에서 꺼내 내게 보여 주었다."}, {"s": "q:bk_arong", "t": "숯은 대장간에서 파는 정련 숯이면 돼요. 저는 먼저 내려가서 이 집게로 풀무에 불을 올려 둘게요."}]'::jsonb, '{"xp": 1548}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_bloodknight', 5, '문설주에 건 이름', '월철 주괴을(를) 만든다, 월철 주괴을(를) 넘긴다', '{"at": ["ember_village"], "tasks": [{"t": "craft", "items": ["iron_ingot"], "n": 6}], "give": {"iron_ingot": 6}}'::jsonb, '[{"s": null, "t": "그날 밤 잔불촌 대장간 풀무는 쉬지 않고 숨을 쉬었다. 아롱은 내가 건넨 주괴를 달궈 바탕을 깔고, 그 위에 생 월철을 접어 넣은 뒤 금 간 도끼날을 사이에 물려 망치로 내리쳤다. 쇠 두드리는 소리가 골목의 화로마다 울려 퍼졌다."}, {"s": null, "t": "새벽녘에 아롱은 벼린 날을 물통에 담갔다. 물이 끓어오르며 하얀 김이 대장간 서까래까지 피어올랐다. 김이 걷히자 날에 나 있던 금은 자취도 없었다."}, {"s": null, "t": "아롱은 가는 정을 들어 날 옆면에 글자 두 자를 새겼다. 아롱은 한 획을 그을 때마다 숨을 멈췄다가 내쉬었다."}, {"s": "q:bk_arong", "t": "강석. 할아버지 이름이에요. 혈엽림에서 십장 할아버지가 지워 주신 이름을 여기에 새겨요. 이번엔 나무가 아니라 쇠예요. 쇠는 안 썩으니까요."}, {"s": null, "t": "아롱은 새 자루를 끼운 도끼를 두 손으로 들고 마을 어귀로 걸어갔다. 나는 그 뒤를 따랐다. 어귀 문설주에는 쇠못 하나가 이미 박혀 있었다."}, {"s": null, "t": "아롱이 도끼를 못에 걸자 날이 아침 햇빛을 받아 붉게 빛났다. 지나가던 아낙 하나가 걸음을 멈추고 날에 새긴 두 글자를 소리 내어 읽었다."}, {"s": null, "t": "그 순간 문설주 그림자 안에 백발 노인 하나가 도끼를 짚고 서 있는 것이 보였다. 노인은 문 바깥 길을 바라보고 있었다. 화롯가에서 보던 굽은 등이 아니라 꼿꼿하게 편 등이었다."}, {"s": "q:bk_gangseok", "t": "이제야 문 앞에 섰구나."}, {"s": null, "t": "아롱은 그 자리에 굳은 채 입술만 달싹였다. 아롱의 눈가가 붉어졌다."}, {"s": "q:bk_arong", "t": "할아버지……."}, {"s": null, "t": "노인의 영은 고개를 돌려 아롱을 한 번, 나를 한 번 보았다. 그러고는 내 도끼날 쪽으로 턱짓을 했다. 서문 성벽 밑에서 숫돌로 내 날을 갈아 주던 때와 같은 몸짓이었다."}, {"s": "q:bk_gangseok", "t": "{이름}, 도끼는 늘 갈아 둬라. 베면서 버티는 몸은 날이 무디면 제일 먼저 무너진다."}, {"s": null, "t": "바람이 한 번 불자 문설주 그림자 속 노인은 더 보이지 않았다. 걸린 도끼만 바람에 흔들리며 낮게 울었다."}, {"s": null, "t": "아롱은 소매로 눈가를 훔치고 나를 돌아보았다."}, {"s": "q:bk_arong", "t": "이름이 불리는 동안은 안 떠나신 거래요. 이 문을 지나는 사람마다 저 글자를 읽을 테니까, 할아버지는 이제 아무 데도 안 가세요."}, {"s": "q:bk_arong", "t": "조사원님 도끼에 금이 가면 꼭 잔불촌으로 오세요. 그때는 제가 벼려 드릴게요. 할아버지 손녀니까 품삯은 안 받아요. 아, 숯값은 받을 거예요."}]'::jsonb, '{"xp": 1548, "gil": 133, "items": {"moonlight_essence": 2, "travel_ration": 2}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq_formation', 'side', '직업·진법가', '셈이 맞지 않는 날', '정청 출납 서리가 다칠 자리를 미리 셈하는 법을 가르친다.', 'hq_archive', 3, '{}'::text[], null, 908, '[]'::jsonb, true, 'formation', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_formation', 1, '맞지 않는 셈', '맞지 않는 셈', '{"at": ["hq_yard"]}'::jsonb, '[{"s": null, "t": "해가 막 넘어가 정청 마당 처마에 등이 하나씩 켜지고 있었다. 출납청 창 너머에서 대나무 가지가 탁자에 부딪는 소리가 잘그락잘그락 새어 나왔다."}, {"s": null, "t": "창 안에서는 머리가 하얗게 센 늙은 서리가 붉고 검은 산가지를 탁자 가득 늘어놓고 있었다. 서리는 산가지 하나를 집었다 놓기를 몇 번 되풀이하더니 이마를 짚었다."}, {"s": "q:dh_heojuhak", "t": "허, 또 안 맞는군. 오늘은 영 셈이 맞지를 않아."}, {"s": null, "t": "서리는 그제야 내 허리춤에 꽂힌 산가지 묶음을 보고 눈을 가늘게 떴다."}, {"s": "q:dh_heojuhak", "t": "자네가 이번에 들어온 진법가로군. 나는 출납청 서리 허주학일세. 정청 곳간에 드나드는 것을 세는 늙은이지."}, {"s": null, "t": "나는 무엇이 맞지 않느냐고 물었다."}, {"s": null, "t": "허주학은 산가지 세 개를 집어 탁자 동쪽 끝에 나란히 세워 놓았다."}, {"s": "q:dh_heojuhak", "t": "장서각 지하서고 서고지기들이 지난 열흘 동안 열한 번이나 다쳤네. 책벌레에 물리고, 쓰러지는 서가에 깔리고. 그런데 다친 자리가 늘 서고 동쪽 끝 세 칸이야. 셈으로 치면 그 자리는 처음부터 다칠 자리였던 걸세."}, {"s": "q:dh_heojuhak", "t": "진법가는 다친 사람을 고치는 사람이 아닐세. 누가 어디서 다칠지 먼저 셈해 두고, 맞기 전에 막는 사람이지."}, {"s": "q:dh_heojuhak", "t": "지하서고를 세 번만 둘러보고 오게. 요괴를 쫓기 전에 그놈들이 어디서 나와서 어디를 노리는지부터 세어 와. 셈 없이 놓은 진은 허수아비만도 못하네. 나도 출납을 닫는 대로 서고로 내려가겠네."}, {"s": null, "t": "나는 산가지 묶음을 고쳐 쥐고 장서각 지하서고로 내려가겠다고 했다."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_formation', 2, '젖은 서가 세 칸', '장서각 지하서고을(를) 살핀다', '{"at": ["hq_archive"], "tasks": [{"t": "search", "r": ["hq_archive"], "n": 3}]}'::jsonb, '[{"s": null, "t": "지하서고 돌벽에서는 물기가 스며 나와 서가 밑동이 거뭇하게 젖어 있었다. 곰팡이 냄새가 코끝을 찔렀다. 내가 세 번을 돌고 나오자 계단참에서 허주학이 등잔을 들고 기다리고 있었다."}, {"s": null, "t": "나는 본 것을 하나씩 일렀다. 책벌레는 늘 물이 스민 동쪽 서가 밑에서 기어 나왔고, 기어 나오면 맨 먼저 가장 가까운 등잔 아래로 몰려갔다."}, {"s": null, "t": "허주학은 내 말을 다 듣고 나서 무릎을 탁 쳤다."}, {"s": "q:dh_heojuhak", "t": "옳지, 그걸세! 불빛 아래에 사람이 서 있으니 거기를 무는 거야. 놈들은 셈을 할 줄 몰라도 늘 같은 길로 다니네. 그러니 우리는 그 길을 셀 수 있지."}, {"s": null, "t": "허주학은 등잔을 바닥에 내려놓고 동쪽 서가 앞 바닥에 산가지 넷을 네모나게 꽂았다. 그러고는 내 손에도 산가지 넷을 쥐여 주었다."}, {"s": "q:dh_heojuhak", "t": "자네는 저 등잔 아래에 꽂게. 동서남북에 하나씩. 진법가가 맨 처음 배우는 「산가지 진」일세. 네 귀의 셈이 맞으면 그 안으로 드는 이빨이 무뎌지네."}, {"s": null, "t": "나는 허주학의 말대로 등잔 아래 네 귀에 산가지를 꽂았다. 꽂을 때마다 차가운 바닥 돌이 손끝에 서늘하게 울렸다."}, {"s": null, "t": "허주학은 등잔을 다시 집어 들고 진 바깥으로 한 걸음 물러섰다."}, {"s": "q:dh_heojuhak", "t": "이제 진 안에 서서 책벌레 요괴를 셋만 쫓아내 보게. 물려도 진 밖보다 얕게 물릴 걸세. 얼마나 얕은지 몸으로 세어 두게."}]'::jsonb, '{"xp": 54}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_formation', 3, '봉서함을 두드리는 소리', '책벌레 요괴을(를) 물리친다', '{"at": ["hq_archive"], "tasks": [{"t": "win", "m": ["g_hq_archive"], "n": 3}]}'::jsonb, '[{"s": null, "t": "마지막 책벌레가 종잇조각처럼 바스러지자 등잔불이 한 번 크게 흔들렸다. 내 팔뚝에는 이빨 자국이 났지만 피는 겨우 배어 나올 만큼이었다."}, {"s": null, "t": "허주학은 내 팔을 등잔 쪽으로 돌려 보더니 흡족하게 고개를 끄덕였다."}, {"s": "q:dh_heojuhak", "t": "보게, 얕지? 셈이 맞은 걸세. 진은 다친 뒤에 감는 붕대가 아닐세. 칼날이 떨어지기 전에 먼저 내미는 손바닥이지."}, {"s": null, "t": "그때 서고 안쪽에서 쿵, 쿵, 쇠를 두드리는 소리가 울렸다. 봉서를 넣어 둔 쇠함 둘레에 금줄을 몸에 칭칭 감은 요괴들이 몰려 있었다."}, {"s": null, "t": "허주학은 등잔을 들어 그쪽을 비추더니 혀를 찼다."}, {"s": "q:dh_heojuhak", "t": "봉서 결계귀로군. 제 몸에 금줄을 감고 막을 두르는 놈들이야. 결계는 둘레를 통째로 막고, 진은 자리를 하나하나 셈해서 막네. 겉보기엔 비슷해도 셈하는 법이 다르지."}, {"s": "q:dh_heojuhak", "t": "저놈들은 막을 두르고 버티니 술법으로 끈질기게 두드려야 하네. 진법가 산가지가 저런 놈들한테 잘 듣거든. 둘만 쓰러뜨려 주게."}, {"s": "q:dh_heojuhak", "t": "그리고 서가를 뒤져서 부적실 두 타래만 찾아 출납청으로 가져오게. 자네 산가지 묶음을 매어 줄 걸세. 산가지가 흩어지면 셈도 흩어지거든."}]'::jsonb, '{"xp": 54}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_formation', 4, '열세 번째 문의 셈', '봉서 결계귀을(를) 물리친다, 부적실을(를) 모은다, 부적실을(를) 넘긴다', '{"at": ["hq_yard"], "tasks": [{"t": "win", "m": ["x_hq_archive_2"], "n": 2}, {"t": "gather", "items": ["talisman_thread"], "r": ["hq_archive"], "n": 2}], "give": {"talisman_thread": 2}}'::jsonb, '[{"s": null, "t": "내가 출납청으로 돌아왔을 때 허주학은 탁자 위에 산가지를 다시 늘어놓고 있었다. 창밖에서 정청 순라꾼이 밤 북을 두 번 울렸다."}, {"s": null, "t": "허주학은 내가 건넨 부적실 두 타래를 받아 내 산가지 묶음 허리를 두 겹으로 감았다. 매듭은 작고 단단했다."}, {"s": "q:dh_heojuhak", "t": "서고지기들한테 일러 두었네. 동쪽 세 칸 앞에는 이제 진을 놓고 들어가라고. 오늘 밤은 셈이 맞았어. 다친 사람이 하나도 없네."}, {"s": null, "t": "나는 그 셈을 어디서 배웠느냐고 물었다. 정청 서리들이 쓰는 셈과는 결이 달라 보였다."}, {"s": null, "t": "허주학은 산가지 하나를 손가락 사이에서 굴리다가 창밖 남쪽 하늘을 바라보았다. 십삼문 암시장이 있는 쪽이었다."}, {"s": "q:dh_heojuhak", "t": "젊을 때 흑련회 장부방에서 배웠네. 십삼문 열세 번째 문 안쪽 말일세. 나도 한때는 이름을 회에 맡기고 호칭으로 불렸지. 맡긴 이름을 도로 찾아 나온 지 마흔 해가 넘었네."}, {"s": "q:dh_heojuhak", "t": "장부방 셈꾼들은 이름을 맡아 둔 칸마다 산가지로 진을 쳐서 지켰다네. 장부는 제 칸이 비어도 모르지만 셈꾼은 알아. 칸이 비면 그 틈으로 무언가가 기어 들어오거든."}, {"s": "q:dh_heojuhak", "t": "장부방에서 같이 산가지를 배운 동문이 하나 있네. 호칭이 「나머지」야. 셈하고 남는 것을 끝까지 센다고 그렇게 불렸지. 그 사람이 아직 장부고 셈을 본다고 들었어."}, {"s": null, "t": "허주학은 묶어 준 산가지 묶음을 내 손에 쥐여 주고, 그 손등을 마른 손바닥으로 한 번 덮었다."}, {"s": "q:dh_heojuhak", "t": "{이름}, 언젠가 십삼문에 가거든 나머지를 찾아서 이 늙은이가 잘 있다고 전해 주게. 그리고 이것 하나만 기억해 두게. 진법가가 셈을 놓는 건 누가 다칠지 미리 아는 게 무서워서일세. 무서우니까 먼저 막는 거야."}]'::jsonb, '{"xp": 54, "gil": 17, "items": {"tonic": 2, "travel_ration": 1}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq2_formation', 'side', '직업·진법가', '장부고의 빈 칸', '흑련 장부고 장부의 빈 칸마다 바깥 것이 새어 든다.', 'ledger_cellar', 18, '{jq_formation}'::text[], null, 1117, '[]'::jsonb, true, 'formation', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_formation', 1, '남는 수를 세는 사람', '남는 수를 세는 사람', '{"at": ["hidden_bazaar"]}'::jsonb, '[{"s": null, "t": "십삼문 암시장 골목은 처마마다 기름등이 달려 있어 한밤인데도 환했다. 비에 젖은 돌바닥 위로 등불이 번져 발밑이 온통 누런빛이었다."}, {"s": null, "t": "나는 열세 번째 문 근처에서 「나머지」라는 호칭을 아느냐고 물었다. 엽전을 세던 노점 아이가 턱으로 골목 끝을 가리켰다."}, {"s": null, "t": "골목 끝 처마 밑에서 머리를 틀어 올린 노파가 돗자리에 산가지를 펴 놓고 있었다. 노파는 산가지를 열 개씩 묶어 밀어 놓다가, 맨 끝에 남은 두 개를 손바닥에 올려 한참 들여다보았다."}, {"s": "q:sx_nameoji", "t": "또 둘이 남네. 어제도 둘, 그제도 둘이었어요. 이상하죠? 남는 수는 늘 똑같은데 장부는 늘 비거든요."}, {"s": null, "t": "나는 허주학이 잘 있다는 말을 전했다. 노파의 손바닥에서 산가지 두 개가 돗자리로 굴러떨어졌다."}, {"s": "q:sx_nameoji", "t": "허주학이요? 아이고, 그 고집쟁이가 아직 살아 있네요. 마흔 해 만에 듣는 소식이라 손이 다 떨려요."}, {"s": null, "t": "노파는 굴러간 산가지를 주워 들고 나를 다시 훑어보았다. 노파의 눈길이 내 허리춤의 산가지 묶음에 머물렀다. 허주학이 감아 준 두 겹 매듭이었다."}, {"s": "q:sx_nameoji", "t": "그 매듭, 장부방 매듭이에요. 그 사람한테 배웠군요. 그럼 내 셈 하나만 같이 봐 줘요."}, {"s": "q:sx_nameoji", "t": "흑련 장부고 장부에는 맡긴 이름마다 칸이 하나씩 있어요. 맡긴 사람이 이름을 되찾아 가면 그 칸을 산가지 진으로 닫아야 하고요. 그런데 진을 칠 줄 아는 셈꾼이 이제 나 하나뿐이라, 닫지 못한 칸이 생겼어요. 그 빈 칸으로 자꾸 뭐가 기어 들어와요."}, {"s": "q:sx_nameoji", "t": "장부고를 세 번 돌면서 서가 사이 어디가 서늘한지 세어 봐요. 빈 칸 자리는 늘 서늘하거든요. 나도 금방 뒤따라 내려갈게요."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_formation', 2, '서늘한 자리 넷', '흑련 장부고을(를) 살핀다', '{"at": ["ledger_cellar"], "tasks": [{"t": "search", "r": ["ledger_cellar"], "n": 3}]}'::jsonb, '[{"s": null, "t": "장부고 서가 사이를 세 번 돌자 등잔불이 유난히 한쪽으로 기우는 자리가 넷 있었다. 그 자리에서 숨을 내쉬면 여름밤인데도 입김이 하얗게 피었다."}, {"s": null, "t": "나머지는 계단을 내려와 내가 짚은 자리마다 산가지를 하나씩 꽂아 표를 해 두었다. 표를 다 해 두고 나서 노파는 서가에서 장부 한 권을 빼 들어 펼쳤다."}, {"s": "q:sx_nameoji", "t": "서늘한 데가 넷, 장부에 빈 칸도 넷. 딱 맞네요. 이런 셈은 좀 틀려 주면 좋으련만."}, {"s": null, "t": "그때 표를 해 둔 자리 하나에서 사금파리 같은 것이 서가 틈으로 스르르 미끄러져 나왔다. 먹빛 거울 조각들이 등잔불을 받아 내 얼굴을 비뚤게 비추었다."}, {"s": null, "t": "나머지는 장부를 가슴에 끌어안고 한 걸음 물러섰다."}, {"s": "q:sx_nameoji", "t": "빈 칸은 거울이랑 같아요. 아무것도 안 적혀 있으니 들여다보는 걸 그대로 비추거든요. 그래서 저런 게 제일 먼저 기어 나와요."}, {"s": "q:sx_nameoji", "t": "진을 치기 전에 칸 앞부터 비워야 해요. 거울 조각을 넷만 깨 줘요. 하나 깰 때마다 비뚤게 비친 셈이 하나씩 지워질 거예요."}]'::jsonb, '{"xp": 568}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_formation', 3, '헐거워진 땅', '먹빛 거울 조각을(를) 물리친다', '{"at": ["ledger_cellar"], "tasks": [{"t": "win", "m": ["r220_ledger_2"], "n": 4}]}'::jsonb, '[{"s": null, "t": "마지막 거울 조각이 바닥에 떨어져 쨍그랑 깨지자 서가 틈의 찬 기운이 조금 가셨다. 깨진 조각에서는 녹슨 쇠 냄새가 비릿하게 풍겼다."}, {"s": null, "t": "나머지는 첫째 빈 칸 앞에 쪼그려 앉아 산가지를 꽂아 보았다. 산가지는 꽂히자마자 저절로 기울어 바닥에 쓰러졌다."}, {"s": "q:sx_nameoji", "t": "오래 비워 둔 칸이라 땅이 헐거워졌어요. 산가지만으로는 못 버텨요. 진 귀마다 결계 파편을 받쳐야 해요. 옛 셈꾼들도 깨진 금줄 조각을 귀에 묻고 그 위에 산가지를 세웠거든요."}, {"s": null, "t": "나는 어쩌다 칸이 넷이나 닫히지 않은 채 남았느냐고 물었다."}, {"s": null, "t": "나머지는 대답 대신 쓰러진 산가지를 주워 다시 세웠다. 노파의 손가락은 마디가 굵고 거칠었다."}, {"s": "q:sx_nameoji", "t": "셈꾼이 줄었어요. 진 치는 법은 장부에 안 적히거든요. 손에서 손으로만 가르쳤는데, 그 손들이 하나둘 떠났어요. 허주학도 그 손 가운데 하나였고요."}, {"s": "q:sx_nameoji", "t": "장부고에 푸른 기운이 고인 데가 있어요. 그런 데를 뒤지면 결계 파편이 나와요. 셋만 모아 줘요. 넷째 귀는 내가 가진 걸로 받칠게요."}]'::jsonb, '{"xp": 568}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_formation', 4, '장부를 찢는 손', '결계 파편을(를) 모은다, 결계 파편을(를) 넘긴다', '{"at": ["ledger_cellar"], "tasks": [{"t": "gather", "items": ["ward_fragment"], "r": ["ledger_cellar"], "n": 3}], "give": {"ward_fragment": 3}}'::jsonb, '[{"s": null, "t": "나머지는 내가 건넨 결계 파편을 빈 칸 귀마다 하나씩 묻고 그 위에 산가지를 꽂았다. 이번에는 산가지가 쓰러지지 않았다. 노파는 셈하듯 입술을 달싹이며 칸을 하나씩 짚어 나갔다."}, {"s": null, "t": "노파가 셋째 칸을 짚을 때 장부고 안쪽에서 종이 찢기는 소리가 길게 울렸다. 손가락이 열 개도 넘는 시커먼 손이 서가 꼭대기를 기어 나머지 쪽으로 뻗어 왔다."}, {"s": null, "t": "나머지는 산가지를 쥔 채 칸 앞에서 꼼짝하지 않았다."}, {"s": "q:sx_nameoji", "t": "장부 찢는 손이에요! 칸이 닫히는 게 싫은 거예요. 빈 칸이 있어야 저것들이 드나들 수 있으니까요. 나는 지금 셈을 멈추면 안 돼요. 여기서 멈추면 진이 반쯤 친 채로 무너져요."}, {"s": null, "t": "나는 나머지 앞을 막아서고 노파의 등 뒤 바닥에 산가지 넷을 꽂았다. 허주학에게 배운 대로 저 손이 떨어질 자리를 먼저 셈했다."}, {"s": null, "t": "나머지는 내가 꽂은 산가지를 곁눈으로 세어 보고 짧게 웃었다."}, {"s": "q:sx_nameoji", "t": "그래요, 바로 그거예요! 내 셈은 내가 맞출 테니, 당신은 저 손이 어디로 떨어질지 셈해 줘요. 둘만 떼어 내면 마저 닫을 수 있어요."}]'::jsonb, '{"xp": 568}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_formation', 5, '「되찾음. 셈 끝」', '장부 찢는 손을(를) 물리친다', '{"at": ["ledger_cellar"], "tasks": [{"t": "win", "m": ["r220_ledger_4"], "n": 2}]}'::jsonb, '[{"s": null, "t": "마지막 손이 서가 틈으로 미끄러져 들어가 흩어지자 장부고에는 다시 먹 냄새만 남았다. 나머지는 넷째 칸 귀에 제 몫의 결계 파편을 묻고 산가지를 꽂았다."}, {"s": null, "t": "넷째 칸까지 닫히자 서가 사이를 돌던 찬 바람이 뚝 멎었다. 한쪽으로 누워 있던 등잔불이 곧게 섰다."}, {"s": null, "t": "나머지는 장부를 펼쳐 빈 칸 넷에 붓으로 한 줄씩 적어 넣었다. 셋째 칸에서 노파의 붓끝이 오래 멈춰 있었다."}, {"s": "q:sx_nameoji", "t": "이 칸이 허주학 거예요. 마흔 해 전에 그 사람이 이름을 도로 찾아 나갈 때 내가 닫아 줘야 했는데, 닫지 않았어요. 칸을 열어 두면 언젠가 돌아올 것 같았거든요."}, {"s": "q:sx_nameoji", "t": "셈꾼이 셈을 미뤘으니 셈이 틀어진 거죠. 이 빈 칸으로 저런 것들이 드나든 것도 다 내 셈이 늦은 탓이에요."}, {"s": null, "t": "나머지는 셋째 칸에 「되찾음. 셈 끝」이라고 적고 붓을 내려놓았다. 그러고는 골목 돗자리에서처럼 산가지 두 개를 손바닥에 올려 보았다."}, {"s": "q:sx_nameoji", "t": "이제야 셈이 맞네요. 남는 건 이 둘뿐이에요. 하나는 허주학 몫으로 남겨 두고, 하나는 내 몫이에요. 나는 아직 이름을 회에 맡겨 두었으니까요."}, {"s": null, "t": "나는 허주학에게 무엇이라고 전하면 좋겠느냐고 물었다."}, {"s": null, "t": "나머지는 장부를 덮고 표지에 앉은 먼지를 소매로 훔쳤다."}, {"s": "q:sx_nameoji", "t": "칸을 닫았다고만 전해 줘요. 그 사람은 그 한마디면 나머지 셈은 다 할 거예요."}, {"s": null, "t": "나머지는 일어서다 말고 바닥에 꽂힌 산가지 하나를 내려다보았다. 산가지 끝이 북쪽으로 아주 조금 기울어 있었다."}, {"s": "q:sx_nameoji", "t": "그리고 {이름}, 하나만 더요. 진을 치는 내내 산가지가 자꾸 북쪽으로 기울었어요. 장부고 땅 밑 방위가 틀어진 것 같아요. 지맥의 뿌리 쪽 일일지도 모르겠어요. 그건 내 셈 밖이라, 땅을 읽는 사람을 따로 찾아봐야겠어요."}]'::jsonb, '{"xp": 568, "gil": 77, "items": {"tonic": 2, "travel_ration": 1}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq3_formation', 'side', '직업·진법가', '땅 밑의 방위', '뒤틀린 지맥의 뿌리에서 바른 방위를 찾아 진을 친다.', 'under_root', 32, '{jq2_formation,mq_nine_gates}'::text[], null, 1184, '[]'::jsonb, true, 'formation', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_formation', 1, '눕는 산가지', '눕는 산가지', '{"at": ["hidden_bazaar"]}'::jsonb, '[{"s": null, "t": "저녁 소나기가 지나간 뒤라 십삼문 암시장 지붕마다 빗물이 고였다가 떨어지고 있었다. 처마 밑 바닥에는 작은 웅덩이가 줄지어 패어 있었고, 비에 젖은 기름등 냄새가 골목에 낮게 깔려 있었다."}, {"s": null, "t": "나머지는 여느 때처럼 골목 끝 처마 밑 돗자리에 앉아 있었다. 노파 앞에 꽂힌 산가지 다섯 개가 모두 한쪽으로 비스듬히 누워 있었다."}, {"s": "q:sx_nameoji", "t": "왔군요. 이것 좀 봐요. 꽂기만 하면 죄다 북쪽으로 누워요. 장부고 칸을 다 닫은 뒤로 빈 칸은 안 생기는데, 이번엔 장부가 놓인 방위가 틀어졌어요. 동쪽 서가에 꽂아 둔 장부가 아침이면 서쪽 칸 장부와 셈이 엇갈려요."}, {"s": "q:sx_nameoji", "t": "내 셈 밖이라 땅 읽는 사람을 수소문했어요. 지맥의 뿌리 갱 밑에 너덜이라는 지관 영감이 산대요. 굴꾼들 갱도 자리를 나경으로 잡아 주던 사람이래요."}, {"s": null, "t": "나머지는 품에서 접은 종이 한 장을 꺼내 내 손에 쥐여 주었다. 종이에는 장부고 서가 자리와 산가지가 누운 방향이 화살표로 빼곡하게 그려져 있었다."}, {"s": "q:sx_nameoji", "t": "이걸 보여 주면 알아들을 거예요. 그런데 영감 나경도 요즘 바늘이 제멋대로 돈다더라고요. 뿌리 안을 세 번쯤 돌면서 바늘이 떨릴 만한 자리부터 찾아봐요. 그런 자리에선 당신 산가지도 기울 거예요."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_formation', 2, '바늘이 도는 갈림길', '지맥의 뿌리을(를) 살핀다', '{"at": ["under_root"], "tasks": [{"t": "search", "r": ["under_root"], "n": 3}]}'::jsonb, '[{"s": null, "t": "지맥의 뿌리 안은 축축하고 이상하리만치 따뜻했다. 굵은 나무뿌리가 천장에서 늘어져 있었고, 손바닥을 대면 뿌리 속으로 무언가가 느리게 흘러가는 것이 느껴졌다."}, {"s": null, "t": "산가지가 눕는 자리를 세 군데 짚고 돌아오자, 갱 갈림길에 등이 굽은 영감 하나가 놋쇠 나경을 두 손으로 받쳐 들고 서 있었다. 나경 한가운데 바늘이 쉬지 않고 빙글빙글 돌았다."}, {"s": null, "t": "영감은 바늘에서 눈을 떼지 않은 채 내 허리춤의 산가지를 턱으로 가리켰다."}, {"s": "q:sx_neodeol", "t": "나머지가 보낸 사람이지? 산가지 꽂는 손을 보니 알겠다. 나는 너덜이다. 땅이 너덜너덜해진 데만 찾아다닌다고 붙은 이름이지."}, {"s": null, "t": "너덜은 나머지의 종이를 받아 펼치고, 내가 짚은 세 자리와 종이 위 화살표를 하나씩 맞춰 보았다. 영감의 굵은 손가락이 화살표를 따라 천천히 미끄러졌다."}, {"s": "q:sx_neodeol", "t": "맞다, 지맥이 비틀렸어. 땅 밑 물길이 뿌리를 휘감고 엉뚱한 쪽으로 흐르니까 기운이 다 그리로 쏠리는 거다. 장부고 산가지가 북으로 눕는 것도, 내 바늘이 도는 것도 다 그래서야."}, {"s": "q:sx_neodeol", "t": "물길을 비튼 건 지하 수맥귀들이다. 뿌리 밑 물에 붙어 사는 놈들인데, 요즘 떼로 불어나서 물길을 제 쪽으로 끌어당기지. 셋만 떼어 내라. 물길이 조금이라도 풀려야 바늘이 선다."}]'::jsonb, '{"xp": 1548}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_formation', 3, '금 간 나경', '지하 수맥귀을(를) 물리친다', '{"at": ["under_root"], "tasks": [{"t": "win", "m": ["x_under_root_2"], "n": 3}]}'::jsonb, '[{"s": null, "t": "수맥귀들이 흩어지자 갱 바닥을 흐르던 물소리가 한결 낮아졌다. 너덜의 나경 바늘이 한 바퀴를 더 돌더니 부르르 떨면서 멈칫거렸다."}, {"s": null, "t": "너덜은 나경을 등잔 쪽으로 기울여 들여다보다가 혀를 찼다. 나경 판에 머리카락 같은 금이 길게 가 있었다."}, {"s": "q:sx_neodeol", "t": "비틀린 땅에서 너무 오래 돌렸구나. 판이 갈라졌으니 이제는 바늘이 서도 못 믿는다. 쉰 해를 쓴 판인데, 아깝다."}, {"s": null, "t": "나는 새 나경을 구할 길이 있느냐고 물었다."}, {"s": null, "t": "너덜은 금 간 나경을 품에 넣고 축축한 뿌리 벽에 등을 기댔다."}, {"s": "q:sx_neodeol", "t": "나경을 새로 깎자면 열흘은 걸린다. 그사이에 땅이 더 비틀려. 진법가라면 법구는 좀 만질 줄 알겠지? 영맥 나침반 하나만 지어다 다오. 영맥 나침반 바늘은 땅 기운을 따라 서니까 당장은 그걸로 방위를 잡을 수 있다."}, {"s": "q:sx_neodeol", "t": "이 뿌리 벽에 박힌 응축 영핵을 캐서 써라. 이 땅 영핵을 넣어 지으면 바늘이 이 땅 기운부터 알아본다. 두 덩이쯤 캐 와."}]'::jsonb, '{"xp": 1548}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_formation', 4, '반 바퀴 돌아누운 땅', '응축 영핵을(를) 모은다, 영맥 나침반을(를) 만든다, 영맥 나침반을(를) 넘긴다', '{"at": ["under_root"], "tasks": [{"t": "gather", "items": ["spirit_core"], "r": ["under_root"], "n": 2}, {"t": "craft", "items": ["spirit_compass"], "n": 1}], "give": {"spirit_compass": 1}}'::jsonb, '[{"s": null, "t": "너덜은 내가 지은 영맥 나침반을 받아 손바닥에 올려놓았다. 바늘이 잠깐 흔들리더니 갱 안쪽 어둠을 곧게 가리켰다."}, {"s": "q:sx_neodeol", "t": "저쪽이 북이다. 내 나경은 바로 반대쪽을 북이라 했지. 땅이 반 바퀴나 돌아누웠던 셈이구나."}, {"s": null, "t": "너덜은 바늘이 가리키는 쪽으로 몇 걸음 걸어가 뿌리 바닥에 귀를 댔다. 깊은 데서 무언가를 씹어 삼키는 소리가 우둑우둑 둔하게 울려 왔다."}, {"s": "q:sx_neodeol", "t": "들리냐? 지맥포식자다. 뿌리를 갉아 먹고 땅을 무너뜨리는 놈이지. 놈들이 뿌리 한가운데를 파먹어 구멍을 내니까 물길이 다 그 구멍으로 쏠린 거다."}, {"s": null, "t": "너덜은 일어나서 나침반을 든 손으로 갱 바닥 다섯 군데를 차례로 짚었다."}, {"s": "q:sx_neodeol", "t": "진 자리는 내가 이 나침반으로 잡으마. 동서남북 넷에 가운데 하나. 그런데 놈들이 진 자리를 그냥 두지는 않을 거다. 놈들이 어디로 튀어나올지는 네가 셈해라. 산가지 쥔 사람이 할 일이 그거잖냐. 두 놈만 쓰러뜨리면 진 귀를 박을 수 있다."}]'::jsonb, '{"xp": 1548}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_formation', 5, '곧게 선 산가지', '지맥포식자을(를) 물리친다', '{"at": ["hidden_bazaar"], "tasks": [{"t": "win", "m": ["m_26"], "n": 2}]}'::jsonb, '[{"s": null, "t": "지맥포식자 둘이 무너진 뒤, 너덜은 영맥 나침반으로 다섯 자리를 잡았고 나는 그 자리마다 산가지를 깊이 박았다. 가운데 산가지까지 박자 갱 바닥 물소리가 한쪽으로 고르게 모여 흘러갔다."}, {"s": null, "t": "너덜은 셈꾼 산가지가 서는지 제 눈으로 보아야겠다며 지팡이를 짚고 나를 따라 십삼문 암시장으로 올라왔다. 처마 밑 돗자리에서 나머지가 산가지를 꽂아 보고 있었다. 산가지 다섯 개가 하나도 눕지 않고 곧게 서 있었다."}, {"s": "q:sx_nameoji", "t": "섰어요! 다섯 개 다요. 아침에 장부를 맞춰 봤는데, 동쪽 칸하고 서쪽 칸 셈이 처음으로 딱 맞았어요."}, {"s": null, "t": "너덜은 돗자리 옆에 쪼그려 앉아 곧게 선 산가지를 손가락으로 툭 건드려 보았다. 산가지는 잠깐 흔들리다가 다시 바로 섰다."}, {"s": "q:sx_neodeol", "t": "셈꾼 산가지가 서는 걸 보니 땅도 제자리로 돌아누웠구나. 땅이란 놈은 사람이 보든 말든 늘 한쪽으로 기울려 들어. 그러니까 기울기 전에 박아 둬야 하는 거다. 다 무너진 다음에 고치는 건 지관 일이 아니지."}, {"s": null, "t": "나머지는 너덜의 말을 듣더니 소리 내어 웃음을 터뜨렸다. 나는 노파가 그렇게 크게 웃는 소리를 처음 들었다."}, {"s": "q:sx_nameoji", "t": "허주학이 장부방에서 맨날 하던 소리랑 똑같네요. 진법가는 맞기 전에 막는다고요. 땅 읽는 사람이나 셈하는 사람이나, 결국 같은 셈을 하고 사네요."}, {"s": null, "t": "너덜은 영맥 나침반을 품에 넣고 지팡이를 고쳐 짚으며 일어섰다."}, {"s": "q:sx_neodeol", "t": "나침반은 내가 갖는다. 값은 다음에 땅이 또 비틀리면 그때 셈하자. 그때도 산가지 들고 내려와라, 진법가."}, {"s": null, "t": "나머지는 산가지 다섯 개를 하나씩 뽑아 묶으면서 나를 올려다보았다."}, {"s": "q:sx_nameoji", "t": "{이름}, 정청에 가거든 허주학한테도 전해 줘요. 장부고 땅도 바로 섰다고요. 이번엔 셈을 하루도 미루지 않았다고요."}]'::jsonb, '{"xp": 1548, "gil": 133, "items": {"moonlight_essence": 2, "travel_ration": 2}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq_spearman', 'side', '직업·여명 창객', '새벽 뱃길', '구름나루의 늙은 창잡이가 「여명」이라는 말의 뜻을 일러 준다.', 'river_ferry', 3, '{}'::text[], null, 908, '[]'::jsonb, true, 'spearman', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_spearman', 1, '선창 끝 말뚝', '선창 끝 말뚝', '{"at": ["river_ferry"]}'::jsonb, '[{"s": null, "t": "동트기 전이었다. 구름나루 강물 위로 물안개가 무릎 높이까지 깔려 있었고, 밤이슬에 젖은 선창 판자가 발밑에서 미끈거렸다."}, {"s": null, "t": "선창 맨 끝 말뚝에 허리가 굽은 노인 하나가 기대앉아 있었다. 노인은 날을 뺀 긴 자루를 무릎에 가로 얹고 기름 먹인 헝겊으로 천천히 문지르고 있었다."}, {"s": null, "t": "노인은 내 손에 들린 긴 자루 무기를 보더니 헝겊을 멈추고 눈을 가늘게 떴다."}, {"s": "q:sx_changbok", "t": "자루가 긴 걸 들었구나. 정청에서 새로 낸 창객이 너냐? 나는 창복이다. 이 나루에서 마흔 해 동안 첫 배 앞머리에 섰지."}, {"s": null, "t": "나는 창객이라는 이름 앞에 붙은 「여명」이 무슨 뜻이냐고 물었다."}, {"s": null, "t": "창복은 대답 대신 자루 끝으로 강 하류를 가리켰다. 안개 너머 동쪽 하늘이 막 희붐하게 밝아 오고 있었다."}, {"s": "q:sx_changbok", "t": "수향 배는 새벽에 떠. 그런데 맨 먼저 뜨는 배는 짐을 안 실어. 사람 둘만 타지. 하나는 노를 젓고, 하나는 앞머리에 서서 창을 든다."}, {"s": "q:sx_changbok", "t": "밤새 물 밑에 고인 물귀들이 첫 배 뱃전으로 손을 뻗거든. 노를 붙잡히면 배가 빙빙 돌고, 사람이 붙잡히면 그날로 끝이야. 그러니까 앞머리 창잡이는 놈들이 손을 얹기 전에 먼저 찔러야 해."}, {"s": "q:sx_changbok", "t": "해가 뜨면 빛이 맨 먼저 닿는 데가 앞머리 창끝이다. 선창에서 보면 창끝이 제일 먼저 하얗게 빛나. 그래서 사람들이 앞머리 창잡이를 여명이라고 불렀어. 우리가 물길을 열어 놓으면 그 뒤로 짐배들이 떴지."}, {"s": null, "t": "창복은 자루를 짚고 일어서더니 강 위쪽을 턱으로 가리켰다."}, {"s": "q:sx_changbok", "t": "요즘 백지교 다리 밑으로 종이학 무리가 내려와서 물길을 휘젓는다더라. 날짐승은 칼로는 잘 안 닿아. 자루가 길어야 닿지. 가서 종이학 무리를 세 번 흩어 놔라. 놈들이 내리꽂기 전에 네 창끝이 먼저 닿아야 한다."}, {"s": null, "t": "나는 백지교로 가 보겠다고 했다."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_spearman', 2, '앞쪽만 찢긴 종이', '종이학 무리을(를) 물리친다', '{"at": ["river_ferry"], "tasks": [{"t": "win", "m": ["g_paper_bridge"], "n": 3}]}'::jsonb, '[{"s": null, "t": "구름나루로 돌아오니 해가 높이 떠 있었다. 선창에는 짐배들이 줄지어 매여 있었고, 생선 비린내와 젖은 밧줄 냄새가 뒤섞여 코를 찔렀다."}, {"s": null, "t": "창복은 새벽과 같은 말뚝에 앉아 있었다. 창복은 내 옷자락에 붙은 종이 부스러기를 집어 들고 손끝으로 비벼 보았다."}, {"s": "q:sx_changbok", "t": "찢어진 자리가 죄다 앞쪽이네. 놈들이 날아들기 전에 찔렀다는 뜻이야. 첫걸음은 뗐다."}, {"s": "q:sx_changbok", "t": "그런데 물에 사는 놈들은 날짐승하고 달라. 한 번 찔러서 물리면 물속으로 숨었다가 다시 올라와. 그때 물러서면 안 돼. 같은 놈을 잇달아 찔러야 해. 찌를수록 창끝이 그놈 버릇을 알아서 더 깊이 들어가거든."}, {"s": null, "t": "나는 백지교 물에도 그런 놈이 있느냐고 물었다."}, {"s": null, "t": "창복은 고개를 끄덕이고 자루 끝으로 선창 판자를 톡톡 두 번 두드렸다. 일을 맡길 때마다 나오는 버릇 같았다."}, {"s": "q:sx_changbok", "t": "다리 밑 먹물 든 물에 먹물 잉어가 산다. 뛰어오를 때마다 찔러서 두 마리만 잡아 와."}, {"s": "q:sx_changbok", "t": "그리고 다리 셋째 기둥 밑을 좀 살펴봐라. 첫 배 사공들은 새벽마다 거기에 붉은 천을 매 뒀어. 천이 물 쪽으로 늘어지면 물이 순한 날이고, 하늘 쪽으로 펄럭이면 그날은 배를 안 띄웠지. 아직 매여 있는지 궁금하다."}]'::jsonb, '{"xp": 54}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_spearman', 3, '셋째 기둥의 붉은 천', '먹물 잉어을(를) 물리친다, 백지교을(를) 살핀다', '{"at": ["river_ferry"], "tasks": [{"t": "win", "m": ["x_paper_bridge_1"], "n": 2}, {"t": "search", "r": ["paper_bridge"], "n": 2}]}'::jsonb, '[{"s": null, "t": "나는 백지교 셋째 기둥 밑에서 이끼 낀 쇠고리 하나를 찾았다. 고리에는 한 뼘쯤 되는 천 조각이 남아 있었다. 붉던 천은 볕에 바래 분홍빛이 되었고, 먹물이 배어 검은 얼룩투성이였다."}, {"s": null, "t": "내가 천 조각을 내밀자 창복은 그것을 두 손으로 받아 무릎 위에 펼쳤다. 창복의 손등에는 굵은 핏줄이 강줄기처럼 불거져 있었다."}, {"s": "q:sx_changbok", "t": "아직 있었구나. 이건 내가 마지막으로 맨 천이야. 벌써 다섯 해가 됐네."}, {"s": null, "t": "나는 그 뒤로는 왜 아무도 천을 매지 않았느냐고 물었다."}, {"s": null, "t": "창복은 천 조각을 접어 품에 넣고 강물 쪽으로 고개를 돌렸다. 한참 뒤에야 창복이 다시 입을 열었다."}, {"s": "q:sx_changbok", "t": "요즘 배는 장대 등을 달고 다니니까 새벽에 굳이 창잡이를 안 태워. 앞머리에 서겠다는 젊은 놈도 없고. 나도 눈이 어두워져서 그해에 창을 내려놨다."}, {"s": "q:sx_changbok", "t": "그래도 너 같은 놈이 자루가 긴 걸 들고 왔으니 한 번은 보여 줘야겠다. 내일 새벽에 내 거룻배를 띄우마. 노는 내가 젓고, 앞머리에는 네가 서라."}, {"s": "q:sx_changbok", "t": "앞머리 장대가 썩었어. 잿빛 들녘에서 부적목 두 토막만 베어 와. 그러면 내가 깎을게. 그다음엔 오늘 밤 이 선창에서 눈을 좀 붙여 둬. 첫 배는 해 뜨기 전에 뜬다."}]'::jsonb, '{"xp": 54}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_spearman', 4, '맨 먼저 밝아진 창끝', '부적목을(를) 모은다, 구름나루에서 쉰다, 부적목을(를) 넘긴다', '{"at": ["river_ferry"], "tasks": [{"t": "gather", "items": ["wood"], "r": ["field_outskirts"], "n": 2}, {"t": "rest", "r": ["river_ferry"], "n": 1}], "give": {"wood": 2}}'::jsonb, '[{"s": null, "t": "나는 선창 판자에 누워 물소리를 들으며 잠들었다가 창복이 어깨를 흔드는 바람에 깼다. 강바람이 소매 속으로 파고들어 이가 딱딱 부딪쳤다."}, {"s": null, "t": "창복은 내가 베어 온 부적목으로 새 앞머리 장대를 깎아 거룻배 이물에 박아 두었다. 송진 냄새가 아직 가시지 않은 장대였다. 나는 그 장대 옆에 서서 자루를 고쳐 쥐었다."}, {"s": null, "t": "창복이 노를 한 번 젓자 거룻배가 미끄러지듯 말뚝에서 떨어졌다. 안개 속에서 물이 뱃전을 찰박찰박 핥았다."}, {"s": null, "t": "배가 강 한가운데에 이르자 이물 앞 물이 불룩 솟았다. 허연 손 하나가 뱃전을 향해 올라왔다. 나는 그 손이 뱃전에 닿기 전에 창끝을 내리꽂았다. 손이 물속으로 사라졌다가 조금 옆에서 다시 솟았고, 나는 물러서지 않고 같은 자리를 두 번 더 찔렀다. 물귀는 다시 올라오지 않았다."}, {"s": null, "t": "등 뒤에서 노 젓는 소리가 잠깐 멎었다. 창복은 노를 쥔 채 낮게 웃고 있었다."}, {"s": "q:sx_changbok", "t": "그렇지! 그거야. 먼저 찌르고, 물러서지 말고, 같은 놈을 끝까지. 다섯 해 만에 앞머리에서 창끝이 물 가르는 소리를 들었네."}, {"s": null, "t": "그때 강 하류 쪽 안개가 엷어지며 해가 산마루 위로 머리를 내밀었다. 첫 햇살이 강물을 가로질러 와서 내 창끝에 맨 먼저 닿았다. 창끝이 흰 불씨처럼 반짝였다."}, {"s": null, "t": "선창 쪽에서 누군가 소리쳤다. 짐배 사공들이 선창 끝에 몰려서서 이쪽을 보고 손을 흔들고 있었다."}, {"s": null, "t": "창복은 노를 무릎에 걸쳐 놓고 그 소리를 한참 듣다가 나를 돌아보았다."}, {"s": "q:sx_changbok", "t": "들리냐? 여명이 떴다고 하는 거다. 저 사람들 할아비들도 다 저렇게 소리쳤어. 창끝이 밝아지면 짐배를 띄워도 된다는 뜻이거든."}, {"s": "q:sx_changbok", "t": "{이름}, 앞으로 어디서 싸우든 이것만 잊지 마라. 요괴보다 먼저 닿아야 하고, 한 번 겨눈 놈은 끝까지 쫓아야 해. 자루가 긴 건 물러서라고 긴 게 아니야. 남보다 한 걸음 먼저 닿으라고 긴 거다."}, {"s": null, "t": "거룻배가 선창으로 돌아오자 짐배들이 하나둘 밧줄을 풀었다. 창복은 품에서 바랜 붉은 천을 꺼내 새 앞머리 장대 끝에 매어 주었다. 천이 물 쪽으로 늘어졌다. 물이 순한 날이었다."}]'::jsonb, '{"xp": 54, "gil": 17, "items": {"tonic": 2, "travel_ration": 1}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq2_spearman', 'side', '직업·여명 창객', '잠든 포구의 첫 배', '잠든 포구 여명 말뚝의 이름들을 스무 해 만에 다시 부른다.', 'sleeping_port', 19, '{jq_spearman}'::text[], null, 1117, '[]'::jsonb, true, 'spearman', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_spearman', 1, '스승의 포구', '스승의 포구', '{"at": ["river_ferry"]}'::jsonb, '[{"s": null, "t": "구름나루에 장맛비가 그친 뒤라 강물이 누렇게 불어 있었다. 선창 끝 말뚝 아래로 떠내려온 나뭇가지들이 빙글빙글 돌다가 하류로 쓸려 갔다."}, {"s": null, "t": "창복은 말뚝에 등을 기댄 채 손바닥만 한 나무패 하나를 엄지로 문지르고 있었다. 나무패는 짠물에 절어 결이 보풀처럼 일어나 있었다."}, {"s": "q:sx_changbok", "t": "왔냐. 요새 네 창끝 소리가 나루까지 들린다. 이것 좀 봐라."}, {"s": null, "t": "창복은 나무패를 내 손바닥에 올려 주었다. 패 앞면에는 「앞머리 창복」, 뒷면에는 작은 글씨로 「잠든 포구 여명 말뚝」이 새겨져 있었다."}, {"s": "q:sx_changbok", "t": "나는 열다섯에 잠든 포구에서 창을 배웠다. 그땐 포구가 잠들기 전이라 수향에서 배가 제일 일찍 뜨는 데였지. 내 스승은 백파 영감이었다."}, {"s": "q:sx_changbok", "t": "그 포구 선창 끝에는 여명 말뚝이라는 게 있어. 앞머리에 서 본 창잡이는 다 거기에 제 이름패를 걸었다. 첫 배가 물목까지 길을 열고 돌아오면, 그날 앞머리 선 놈이 말뚝에 걸린 이름을 하나씩 다 불러 줬지. 길을 열어 준 사람들 이름을 새벽마다 불러야 그 길이 안 닫힌다고 했거든."}, {"s": null, "t": "나는 이 나무패가 왜 구름나루에 있느냐고 물었다."}, {"s": null, "t": "창복은 나무패를 도로 받아 쥐고 한동안 누런 강물만 내려다보았다."}, {"s": "q:sx_changbok", "t": "서른 살에 이 나루로 오면서 떼어 왔다. 스승은 거기 남았고. 그러다 스무 해 전, 그 포구 마지막 무역선이 떠나던 새벽에 스승이 첫 배 앞머리에 섰다. 물목까지 길을 열고는 바다 끝까지 열어 주겠다며 무역선으로 옮겨 탔지. 그 배는 돌아오지 않았어. 그 뒤로 포구가 잠들었고, 새벽 첫 배를 띄운 사람이 아무도 없었다."}, {"s": "q:sx_changbok", "t": "그러니 여명 말뚝 이름들은 스무 해 동안 아무한테도 안 불렸을 거다. 스승 이름도 거기 있어."}, {"s": null, "t": "창복은 자루를 짚고 일어섰다. 무릎에서 뚝 하는 소리가 났다."}, {"s": "q:sx_changbok", "t": "내 다리로는 거기까지 못 걸어간다. 나는 배를 얻어 타고 물길로 갈 테니, 너는 먼저 가서 포구를 세 번쯤 돌아보며 말뚝부터 찾아 놔라. 안개가 짙어서 선창 끝이 어딘지도 안 보일 거다."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_spearman', 2, '따개비 덮인 말뚝', '잠든 포구을(를) 살핀다', '{"at": ["sleeping_port"], "tasks": [{"t": "search", "r": ["sleeping_port"], "n": 3}]}'::jsonb, '[{"s": null, "t": "잠든 포구 방파제 끝, 물안개가 가장 짙게 고인 곳에 굵은 말뚝 하나가 서 있었다. 말뚝은 밑동부터 허리까지 따개비로 덮여 있었고, 위쪽에는 삭은 끈에 매달린 나무패가 수십 개 늘어져 바람에 달그락거렸다."}, {"s": null, "t": "내가 말뚝을 찾았을 무렵 짐배 한 척이 방파제에 닿았다. 창복은 사공의 부축을 받아 내리더니 지팡이 삼은 자루를 짚고 말뚝 앞까지 한 걸음씩 걸어왔다."}, {"s": null, "t": "창복은 나무패들을 손으로 하나하나 뒤집어 보았다. 글자가 지워진 패가 절반이 넘었다."}, {"s": "q:sx_changbok", "t": "다 닳았네. 스무 해를 안 불렀으니 이럴 만도 하지."}, {"s": null, "t": "그때 방파제 쪽에서 등잔 불빛 하나가 안개를 가르며 다가왔다. 젊은 여인이 낡은 장부를 품에 안고 우리를 살폈다."}, {"s": "q:r220_gyewol", "t": "말뚝 앞에 사람이 서 있는 건 처음 봐요. 혹시 이 말뚝을 아시는 분들이세요?"}, {"s": null, "t": "창복이 제 이름패를 들어 보이자 여인의 눈이 커졌다. 여인은 장부를 펼쳐 손가락으로 줄을 짚어 내려갔다."}, {"s": "q:r220_gyewol", "t": "저는 계월이에요. 아버지가 이 포구 선주였어요. 아버지 장부에 날마다 「첫 배 앞머리」 칸이 있는데, 거기 창복이라는 이름이 아주 많이 적혀 있어요. 그리고 마지막 장에는 백파라는 이름이 있고요."}, {"s": null, "t": "창복은 계월이 내민 장부의 마지막 장을 오래 들여다보았다. 창복은 아무 말 없이 장부 귀퉁이를 엄지로 한 번 쓸었다."}, {"s": "q:sx_changbok", "t": "아가씨, 그 장부 좀 빌려줄 수 있겠어? 말뚝 패는 다 닳았어도 장부에는 이름이 남아 있을 거야. 내일 새벽에 첫 배를 한 번 띄우고 돌아와서 그 이름들을 다 불러 줄 생각이다."}, {"s": null, "t": "계월은 장부를 가슴에 꼭 끌어안았다가 이내 고개를 끄덕였다. 그러고는 말뚝 꼭대기를 올려다보며 얼굴을 찌푸렸다."}, {"s": "q:r220_gyewol", "t": "그런데 저 위 좀 보세요. 안개 갈매기들이 말뚝 꼭대기에 둥지를 틀었어요. 사람이 다가가면 한꺼번에 내리꽂아요. 저것들부터 쫓아 주셔야 패를 내릴 수 있어요."}, {"s": null, "t": "창복이 자루 끝으로 방파제 바닥을 톡톡 두 번 두드렸다. 나는 그 소리를 듣고 먼저 자루를 고쳐 쥐었다."}, {"s": "q:sx_changbok", "t": "들었지. 날짐승이다. 놈들이 날개를 펴기 전에 닿아라. 세 번만 흩어 놓으면 다시는 저 꼭대기에 못 앉을 거다."}]'::jsonb, '{"xp": 623}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_spearman', 3, '장부에 남은 이름', '안개 갈매기 떼을(를) 물리친다', '{"at": ["sleeping_port"], "tasks": [{"t": "win", "m": ["r220_port_2"], "n": 3}]}'::jsonb, '[{"s": null, "t": "갈매기 떼가 흩어진 말뚝 꼭대기에는 깃털과 생선 뼈만 수북했다. 계월은 사다리를 놓고 올라가 삭은 끈을 하나씩 풀어 나무패를 내렸다. 짠 바람에 계월의 소맷자락이 파닥였다."}, {"s": null, "t": "창복은 방파제에 쪼그려 앉아 나무패와 장부를 나란히 놓고 하나씩 맞춰 보았다. 글자가 지워진 패를 집을 때마다 계월이 장부에서 그날의 이름을 찾아 읽어 주었다."}, {"s": "q:r220_gyewol", "t": "이건 칠월 열흘 날이에요. 앞머리 「물매」. 이건 동짓달… 「덕삼」 아니고 「덕손」이네요."}, {"s": null, "t": "창복은 계월이 읽어 주는 이름을 숯으로 패 뒷면에 다시 적었다. 숯이 패의 나뭇결을 따라 사각사각 소리를 냈다."}, {"s": "q:sx_changbok", "t": "아가씨 아버지가 장부를 꼼꼼히도 적었네. 덕분에 이름 줄이 안 끊겼어."}, {"s": null, "t": "계월은 장부를 덮고 포구 끝 물목 쪽을 바라보았다. 계월의 목소리가 조금 낮아졌다."}, {"s": "q:r220_gyewol", "t": "아버지는 늘 그랬어요. 배는 잊어도 앞머리 선 사람 이름은 잊으면 안 된다고요. 그 사람들이 맨 먼저 물에 손을 내밀었으니까요."}, {"s": null, "t": "창복은 마지막 패에 「백파」 두 글자를 또박또박 적고 숯을 내려놓았다. 그러고는 방파제 아래 매인 작은 거룻배를 내려다보았다."}, {"s": "q:sx_changbok", "t": "저 거룻배를 빌려 타자. 그런데 배 밑에 잠든 배 물귀들이 잔뜩 붙어 있어. 저대로 띄우면 노부터 붙잡혀. 세 놈만 떼어 내라."}, {"s": "q:sx_changbok", "t": "그리고 말뚝 등에 넣을 등롱 어유를 두 병만 구해 와. 물목에서 돌아올 때 말뚝 등이 켜져 있어야 배가 안개 속에서 말뚝을 찾는다. 이 포구 궤짝 더미를 뒤지면 나올 거다."}]'::jsonb, '{"xp": 623}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_spearman', 4, '노는 내가, 앞머리는 네가', '잠든 배 물귀을(를) 물리친다, 등롱 어유을(를) 모은다, 등롱 어유을(를) 넘긴다', '{"at": ["sleeping_port"], "tasks": [{"t": "win", "m": ["r220_port_1"], "n": 3}, {"t": "gather", "items": ["lantern_oil"], "r": ["sleeping_port"], "n": 2}], "give": {"lantern_oil": 2}}'::jsonb, '[{"s": null, "t": "동트기 한참 전이었다. 계월이 내가 건넨 어유를 말뚝 등에 부어 불을 붙였다. 기름 타는 냄새가 짠 안개에 섞였고, 노란 불빛이 다시 적은 나무패들을 비추었다."}, {"s": null, "t": "창복은 거룻배 고물에 앉아 노를 쥐었다. 창복의 손이 노 손잡이를 쥐었다 놓았다 하며 길을 들였다."}, {"s": "q:sx_changbok", "t": "나는 이제 앞머리에 못 선다. 눈이 흐려서 물귀 손이 안 보여. 노는 내가 젓고, 앞머리는 네가 서라."}, {"s": "q:sx_changbok", "t": "방파제를 지나 물목까지 나가는 동안 안개는 한 번도 안 걷힐 거다. 다녀와서 이름을 부르자."}, {"s": null, "t": "계월은 말뚝 등 아래에서 장부를 품에 안고 우리를 올려다보았다."}, {"s": "q:r220_gyewol", "t": "등은 제가 지킬게요. 꺼지지 않게요. 꼭 돌아오세요."}, {"s": null, "t": "나는 이물에 서서 자루를 앞으로 겨누었다. 창복의 노가 물에 꽂히자 거룻배가 안개 속으로 미끄러져 나갔다."}]'::jsonb, '{"xp": 623}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_spearman', 5, '여명 말뚝', '잠든 포구 원정을 다녀온다', '{"at": ["sleeping_port"], "tasks": [{"t": "expedition", "r": ["sleeping_port"], "n": 1}]}'::jsonb, '[{"s": null, "t": "물목에서 돌아오는 길에 안개 사이로 노란 불빛이 보였다. 말뚝 등이었다. 계월은 밤새 그 자리를 떠나지 않은 모양이었다. 계월의 머리칼이 안개에 젖어 이마에 들러붙어 있었다."}, {"s": null, "t": "거룻배가 방파제에 닿을 무렵 바다 쪽 하늘이 희게 트였다. 첫 햇살이 안개를 뚫고 들어와 내 창끝에 맨 먼저 닿았다. 계월이 손으로 입을 막았다."}, {"s": "q:r220_gyewol", "t": "창끝이 빛나요. 아버지가 말했던 게 이거였구나."}, {"s": null, "t": "창복은 노를 거두고 지팡이 삼은 자루를 짚고 말뚝 앞에 섰다. 창복은 계월에게서 장부를 받아 들고, 숯으로 다시 적은 나무패들을 처음부터 하나씩 짚어 나갔다."}, {"s": "q:sx_changbok", "t": "물매. 덕손. 갈바위. 오목이."}, {"s": null, "t": "창복의 목소리는 쉬어 있었지만 끊기지 않았다. 이름 하나를 부를 때마다 창복은 그 패를 말뚝에 다시 걸었다. 바닷바람이 패들을 흔들어 달그락 소리가 났다. 그 소리가 대답처럼 들렸다."}, {"s": null, "t": "마지막 패를 든 창복의 손이 한 번 떨렸다. 창복은 숨을 길게 들이쉬었다."}, {"s": "q:sx_changbok", "t": "백파."}, {"s": null, "t": "창복은 백파의 패를 맨 위에 걸고, 그 아래에 제 이름패를 나란히 걸었다. 계월은 장부 맨 끝 빈 줄을 펼쳐 붓을 들었다."}, {"s": "q:r220_gyewol", "t": "오늘 첫 배 앞머리는 누구라고 적을까요?"}, {"s": null, "t": "창복이 턱으로 나를 가리켰다. 계월은 고개를 끄덕이고 내 이름을 장부에 한 자씩 눌러 적었다."}, {"s": null, "t": "창복은 품에서 새 나무패 하나를 꺼냈다. 창복이 구름나루에서부터 깎아 온 패였다. 패 앞면에는 내 이름이 새겨져 있었다."}, {"s": "q:sx_changbok", "t": "이건 네 패다. 여기 걸어 둬라. 이제 이 포구에서 누가 새벽에 이름을 부르면 네 이름도 같이 불린다."}, {"s": "q:sx_changbok", "t": "아가씨, 내가 또 오기는 어려울 거야. 그래도 이 말뚝 등만은 가끔 켜 줘. 등이 켜져 있으면 언젠가 또 자루 긴 놈이 와서 앞머리에 설 테니까."}, {"s": null, "t": "계월은 장부를 끌어안고 웃었다."}, {"s": "q:r220_gyewol", "t": "그럴게요. 그리고 {이름} 님이 다시 오시면, 그날은 제가 노를 저을게요."}]'::jsonb, '{"xp": 623, "gil": 81, "items": {"tonic": 2, "travel_ration": 1}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq3_spearman', 'side', '직업·여명 창객', '갑문을 여는 창', '큰 만조 날, 창잡이의 외손자가 갑문 수문 날개 끝에 선다.', 'tide_gate', 32, '{jq2_spearman,mq_nine_gates}'::text[], null, 1184, '[]'::jsonb, true, 'spearman', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_spearman', 1, '기름종이에 싼 창날', '기름종이에 싼 창날', '{"at": ["river_ferry"]}'::jsonb, '[{"s": null, "t": "늦가을이었다. 구름나루 선창 판자에 서리가 희끗희끗 내려앉아 걸을 때마다 사박사박 부서졌다."}, {"s": null, "t": "창복은 말뚝 옆에 놓인 걸상에 앉아 있었다. 창복의 무릎 위에는 기름종이로 꽁꽁 싼 길쭉한 꾸러미가 놓여 있었다. 창복은 나를 보자 꾸러미를 두 손으로 들어 올렸다."}, {"s": "q:sx_changbok", "t": "구중 봉연까지 다녀왔다더니 얼굴이 많이 상했다. 그래도 창 쥔 손은 그대로구나."}, {"s": null, "t": "창복은 기름종이를 한 겹 벗겼다. 날이 시퍼렇게 선 창날 하나가 드러났다. 자루를 박는 슴베 둘레에는 오래된 손때가 검게 배어 있었다."}, {"s": "q:sx_changbok", "t": "마흔 해 동안 앞머리에서 쓴 날이다. 이걸 해든이한테 갖다줘. 내 외손자야. 만조의 갑문에서 수문지기 노파 밑에 들어가 일을 배우고 있다."}, {"s": null, "t": "나는 손자에게 창날을 직접 주지 않고 왜 나에게 맡기느냐고 물었다."}, {"s": null, "t": "창복은 창날을 다시 기름종이로 싸며 쓴웃음을 지었다."}, {"s": "q:sx_changbok", "t": "그놈이 열두 살 때 내가 앞머리에 세웠다가 물에 빠뜨렸어. 물귀가 발목을 잡았지. 내가 건져 올렸지만 그 뒤로 그놈은 창 근처에도 안 왔다. 길을 여는 건 무섭다고, 물을 막는 걸 배우겠다고 갑문으로 갔지."}, {"s": "q:sx_changbok", "t": "그런데 요번 큰 만조에 갑문을 열어야 한다는 기별이 왔어. 바다에 묶인 연맹 배들을 갑실 안으로 들여야 한대. 수문을 열면 그 위가 배 앞머리랑 똑같다. 맨 먼저 맞는 자리지. 해든이가 거기 서겠다고 했다더라."}, {"s": null, "t": "창복은 꾸러미를 내 품에 안겨 주고 자루 끝으로 선창 판자를 톡톡 두 번 두드렸다. 손이 조금 떨렸다."}, {"s": "q:sx_changbok", "t": "나는 그놈한테 이걸 주라고 말할 낯이 없다. 네가 가서 그놈 하는 걸 보고, 쓸 만하면 줘. 먼저 갑문을 두어 번 돌아보면서 그놈부터 찾아 다오. 아마 망루 근처에 있을 거다."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_spearman', 2, '망루 위의 도제', '만조의 갑문을(를) 살핀다', '{"at": ["tide_gate"], "tasks": [{"t": "search", "r": ["tide_gate"], "n": 2}]}'::jsonb, '[{"s": null, "t": "만조의 갑문 망루 꼭대기에서 연맹 깃발이 거센 바닷바람에 찢어질 듯 펄럭였다. 망루 아래 둑길에서 한 청년이 쇠갈고리 달린 장대를 들고 서서 바다 쪽 구름을 노려보고 있었다."}, {"s": null, "t": "청년은 내가 다가가자 장대를 바로 세우고 허리를 반듯하게 굽혔다. 콧등에 소금기가 허옇게 말라붙어 있었다."}, {"s": "q:sx_haedeun", "t": "정청에서 오신 조사원이십니까. 저는 해든이라고 합니다. 조막심 어르신 밑에서 수문 일을 배우고 있습니다."}, {"s": null, "t": "나는 구름나루 창복 영감이 보내서 왔다고 했다. 기름종이 꾸러미 이야기는 아직 꺼내지 않았다."}, {"s": null, "t": "해든의 얼굴이 잠깐 굳었다. 해든은 장대를 고쳐 쥐며 시선을 바다 쪽으로 돌렸다."}, {"s": "q:sx_haedeun", "t": "할아버지가요? …아니, 할아버님께서 보내셨습니까. 무슨 일로 오셨는지는 대강 알 것 같습니다."}, {"s": null, "t": "그때 망루 계단에서 늙은 여인이 손가락 마디를 하나씩 접으며 내려왔다. 수문지기 조막심이었다."}, {"s": "q:r71_jomaksim", "t": "사흘 뒤가 큰 만조우. 이번엔 물만 오는 게 아니야. 저 구름 좀 보시우."}, {"s": null, "t": "조막심이 가리킨 둑 바깥 물에 무언가가 투명하게 일렁이며 떼로 밀려들고 있었다. 그 위로는 갈매기 떼가 낮게 맴돌았다. 짠 바람에 비린 쇠 냄새가 섞여 있었다."}, {"s": "q:r71_jomaksim", "t": "큰 만조가 오기 전에는 바다 것들이 물을 타고 먼저 몰려온다우. 해초 독해파리가 날개 밑에 들러붙고, 갈매기 놈들은 덩달아 날뛰지. 저것들이 수문 날개에 달라붙으면 도르래가 안 돌아."}, {"s": null, "t": "해든은 갈고리 장대를 물 쪽으로 겨누다가 이내 끝을 내렸다. 장대 끝이 조금 떨렸다."}, {"s": "q:sx_haedeun", "t": "저는 갈고리로 걷어 내는 것까지만 배웠습니다. 날아드는 것은 먼저 닿아야 하는데, 제 장대는 늘 반 박자 늦습니다."}, {"s": null, "t": "나는 둑길에 앉은 것들부터 걷어 내겠다고 했다. 해든은 고개를 꾸벅 숙이고 망루 쪽으로 물러섰다."}, {"s": null, "t": "조막심이 접었던 손가락 마디를 다시 펴며 셈을 마쳤다."}, {"s": "q:r71_jomaksim", "t": "갈매기 넷, 해파리 셋은 떨어뜨려야 사흘 동안 날개가 조용할 거유. 부탁하우."}]'::jsonb, '{"xp": 1548}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_spearman', 3, '자루를 고르는 손', '소금 갈매기 떼을(를) 물리친다, 해초 독해파리을(를) 물리친다', '{"at": ["tide_gate"], "tasks": [{"t": "win", "m": ["r71_tide_2"], "n": 4}, {"t": "win", "m": ["r71_tide_4"], "n": 3}]}'::jsonb, '[{"s": null, "t": "둑길에 끌려 올라온 독해파리들은 볕을 받자 물방울처럼 터져 흩어졌다. 터진 자리마다 비린 김이 피어올라 손등이 얼얼했다."}, {"s": null, "t": "해든은 둑길 끝에 서서 내가 싸우는 모습을 처음부터 끝까지 지켜보고 있었다. 내가 돌아오자 해든은 망설이다가 입을 열었다."}, {"s": "q:sx_haedeun", "t": "조사원님은 해파리가 내려앉기 전에 찌르시더군요. 그리고 한 놈을 겨누시면 끝까지 그놈만 찌르셨습니다. 할아버님이 제게 가르치려던 게 그거였습니다."}, {"s": null, "t": "나는 그제야 기름종이 꾸러미를 풀어 창복의 창날을 해든에게 보여 주었다."}, {"s": null, "t": "해든은 창날을 보자마자 한 걸음 물러섰다. 그러다가 슴베의 검은 손때를 보고는 천천히 손을 뻗어 날 등을 쓸었다."}, {"s": "q:sx_haedeun", "t": "이건 할아버지 날이잖아. …할아버님 날입니다. 마흔 해 동안 앞머리에서 쓰시던 겁니다. 제가 물에 빠진 날에도 이 날이 제 눈앞에서 빛났습니다."}, {"s": null, "t": "해든은 창날을 두 손으로 받쳐 들고 한참 동안 내려다보았다. 바닷바람이 해든의 젖은 소매를 펄럭였다."}, {"s": "q:sx_haedeun", "t": "큰 만조에 수문 날개 끝에 서겠다고 한 건 저입니다. 문을 여는 동안 누군가는 거기 서 있어야 하니까요. 이 날을 쓰겠습니다. 다만 날만으로는 안 됩니다. 자루가 있어야 합니다."}, {"s": null, "t": "조막심이 망루 계단참에서 내려다보다가 혀를 찼다."}, {"s": "q:r71_jomaksim", "t": "갑문 물은 짜고 거세우. 맨 부적목 자루는 사흘이면 휘어. 강화 부적목으로 하시우. 축에 쓰려고 두었던 건 지난번에 다 썼수."}, {"s": null, "t": "해든은 갈고리 장대를 둑에 기대어 세워 놓고 내 쪽으로 허리를 굽혔다."}, {"s": "q:sx_haedeun", "t": "강화 부적목 두 토막을 만들어 주시겠습니까. 두 토막을 이어 붙이면 할아버님 자루만 한 길이가 나옵니다. 깎는 것은 제가 하겠습니다."}]'::jsonb, '{"xp": 1548}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_spearman', 4, '물이 같아지는 한때', '강화 부적목을(를) 만든다, 강화 부적목을(를) 넘긴다', '{"at": ["tide_gate"], "tasks": [{"t": "craft", "items": ["reinforced_lumber"], "n": 2}], "give": {"reinforced_lumber": 2}}'::jsonb, '[{"s": null, "t": "해든은 내가 건넨 강화 부적목 두 토막을 이어 붙이고 밤새 대패질을 했다. 새벽녘 둑길에는 대팻밥 냄새와 갯내가 한데 엉겨 있었다. 해든은 다 깎은 자루 끝에 창복의 창날을 박고 쐐기를 쳐 넣었다."}, {"s": null, "t": "해든이 새 창을 한 번 휘두르자 자루가 휘익 바람 소리를 냈다. 해든의 손바닥에는 물집이 서너 개 잡혀 있었다."}, {"s": "q:sx_haedeun", "t": "할아버님 자루보다 손가락 두 마디 깁니다. 일부러 그렇게 깎았습니다. 저는 남보다 반 박자 늦으니까 한 마디쯤은 먼저 닿아야 합니다."}, {"s": null, "t": "그날 낮부터 바다가 부풀기 시작했다. 해가 질 무렵에는 둑 바깥 물이 갑문 턱까지 차올랐고, 비바람이 둑길을 옆으로 후려쳤다. 둑 바깥 물 위에서는 연맹 배 일곱 척이 서로 밧줄로 묶인 채 들썩이고 있었다."}, {"s": null, "t": "조막심이 도르래 손잡이에 두 손을 얹고 손가락 마디를 하나씩 접으며 물때를 셌다."}, {"s": "q:r71_jomaksim", "t": "바깥 물이 안쪽 물하고 같아지는 한때가 오우. 그때 열고, 배가 다 들어오면 닫는 거유. 그 사이에 날개 위로 뭐가 내려앉든 버텨야 하우."}, {"s": null, "t": "해든은 수문 날개 끝으로 걸어 나갔다. 비에 젖은 날개 끝은 뱃전처럼 좁고 미끄러웠다. 해든은 거기 서서 새 창을 앞으로 겨누었다."}, {"s": null, "t": "그 순간 둑 밑 물속에서 쇠를 긁는 소리가 올라왔다. 집채만 한 집게 둘이 물을 가르고 솟아 수문 도르래의 쇠사슬을 움켜쥐었다. 집게가 오므라들 때마다 사슬 고리가 끼익 비틀렸다."}, {"s": null, "t": "조막심이 도르래 손잡이를 움켜쥔 채 목청을 높였다."}, {"s": "q:r71_jomaksim", "t": "도르래 집게우! 저놈들이 사슬을 물고 늘어지면 도르래가 끊어져. 조사원 양반, 저놈들을 맡아 주시우. 해든이는 제자리를 지키고!"}, {"s": null, "t": "해든은 이를 악물고 날개 끝에 발을 디딘 채 움직이지 않았다. 나는 둑을 따라 도르래 쪽으로 달려 나갔다."}]'::jsonb, '{"xp": 1548}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_spearman', 5, '갑문을 여는 창', '도르래 집게을(를) 물리친다', '{"at": ["tide_gate"], "tasks": [{"t": "win", "m": ["r71_tide_3"], "n": 2}]}'::jsonb, '[{"s": null, "t": "마지막 집게가 사슬을 놓고 둑 바깥 바다로 떨어졌다. 그와 동시에 조막심이 도르래를 힘껏 돌렸다. 쇠사슬이 끼익 울리며 수문 날개가 천천히 벌어졌다."}, {"s": null, "t": "열린 수문 틈으로 바깥 물이 넘실거리며 밀려들었다. 물살 위로 허연 손들이 솟아 날개를 향해 뻗어 왔다. 해든은 그 손들이 날개에 닿기 전에 먼저 창끝을 내리꽂았다. 한 손이 물러났다가 다시 솟자 해든은 물러서지 않고 같은 자리를 두 번 더 찔렀다."}, {"s": null, "t": "해든은 찌르다 말고 고개를 들어 바다 쪽을 향해 소리쳤다. 목소리가 비바람을 뚫고 둑 바깥 배들까지 퍼졌다."}, {"s": "q:sx_haedeun", "t": "길 열렸다! 들어와!"}, {"s": null, "t": "묶인 배 일곱 척이 차례로 노를 저어 수문을 지나 갑실 안으로 들어섰다. 일곱째 배의 고물이 수문 턱을 넘자 조막심이 도르래를 거꾸로 돌렸고, 날개가 쿵 소리를 내며 닫혔다."}, {"s": null, "t": "그 무렵 비가 그쳤다. 먹구름이 걷힌 동쪽 바다 위로 해가 떠올랐다. 첫 햇살이 젖은 수문 날개를 따라 미끄러져 와서 해든의 창끝에 맨 먼저 닿았다."}, {"s": null, "t": "갑실 안 배 위의 뱃사람들이 그 빛을 보고 한목소리로 외쳤다. 여명이 떴다는 소리였다."}, {"s": null, "t": "해든은 창을 내리고 날개 끝에 털썩 주저앉았다. 해든의 어깨가 크게 들썩였다. 조막심이 도르래에서 손을 떼고 손가락 마디를 하나 더 접었다."}, {"s": "q:r71_jomaksim", "t": "이번 물때도 넘겼수. 그리고 이 갑문에서 문을 연 건 우리 집안 삼대에 처음이구먼. 막는 법만 가르쳤는데 여는 놈이 나왔어."}, {"s": null, "t": "해든은 젖은 창을 무릎에 눕히고 날 등을 손바닥으로 쓸었다. 그러고는 나를 올려다보았다. 해든의 말투에서 딱딱한 존댓말이 반쯤 빠져 있었다."}, {"s": "q:sx_haedeun", "t": "조사원님. 할아버지한테 전해 주세요. 날이 아직 잘 들더라고요. 그리고 자루는 제가 깎았다고요. 손가락 두 마디 더 길게."}, {"s": "q:sx_haedeun", "t": "다음 큰 만조 때도 제가 여기 서겠습니다. 그때는 할아버지를 모셔 올 겁니다. 할아버지는 노만 저으시면 되니까요."}, {"s": null, "t": "나는 구름나루로 돌아가 창복에게 그 말을 그대로 전해 주겠다고 했다. 해든은 고개를 끄덕이고 다시 일어나 수문 날개 끝에 섰다. 해든은 갑실 쪽 배들을 등지고 아직 물이 출렁이는 바다를 바라보았다. 창끝에는 첫 햇살이 아직 머물러 있었다."}]'::jsonb, '{"xp": 1548, "gil": 133, "items": {"moonlight_essence": 2, "travel_ration": 2}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
select public.world_quest_label_refresh();

create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

create or replace function pg_temp.yh_setjson(p_fn regprocedure, p_j jsonb) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); body text := (select prosrc from pg_proc where oid = p_fn);
begin
  if position(body in src) = 0 then raise exception 'yh_setjson %: 본문을 못 찾음', p_fn; end if;
  execute replace(src, body, ' select ' || quote_literal(p_j::text) || '::jsonb ');
end $f$;

select pg_temp.yh_setjson('public.world_avatar_parts()'::regprocedure, '{"free":{"skins":["deep","fair","tan","warm"],"hair":["buns","calm","cloud","curly","curtain","fluffy","halfup","layered","long","pony","princess","sports","twintail"],"hairColors":["black","brown","chestnut","gold","indigo","peach","red","silver"],"eyes":["cat","dot","droopy","round","sharp","sleepy","smile","sparkle","teary","wink"],"eyeColors":["amber","blue","brown","crimson","dark","jade"],"mouth":["cat","grin","open","pout","small","smile"]},"outfits":{"top:guard":{"slot":"top","name":"쇠미늘 갑옷","grade":1},"top:scout":{"slot":"top","name":"무명 철릭","grade":1},"top:exorcist":{"slot":"top","name":"삼베 도포","grade":1},"top:medic":{"slot":"top","name":"쑥빛 앞치마 도포","grade":1},"top:seal":{"slot":"top","name":"누비 전포","grade":1},"top:shadow":{"slot":"top","name":"먹빛 누비 전포","grade":1},"top:tamer":{"slot":"top","name":"털깃 사냥 저고리","grade":1},"top:blood":{"slot":"top","name":"검붉은 가죽 흉갑","grade":1},"top:formation":{"slot":"top","name":"팔괘 띠 쪽빛 도포","grade":1},"top:spear":{"slot":"top","name":"새벽빛 전복","grade":1},"top:jeogori":{"slot":"top","name":"연분홍 저고리","grade":1},"top:vest":{"slot":"top","name":"무명 조끼","grade":1},"top:magoja":{"slot":"top","name":"짧은 마고자","grade":1},"top:jeoksam":{"slot":"top","name":"짧은 적삼","grade":1},"top:dallyeong":{"slot":"top","name":"청사 단령","grade":1},"top:furvest":{"slot":"top","name":"설원 털배자","grade":1},"top:saekdong":{"slot":"top","name":"잔치 색동 저고리","grade":1},"top:shadowrobe":{"slot":"top","name":"봉연 그림자 도포","grade":1},"top:fisher":{"slot":"top","name":"어부 등거리","grade":1},"top:galot":{"slot":"top","name":"갈옷 적삼","grade":1},"top:silkcheollik":{"slot":"top","name":"비단 철릭","grade":1},"top:hoodie":{"slot":"top","name":"쓰개 달린 겉옷","grade":1},"top:knitvest":{"slot":"top","name":"털실 조끼","grade":1},"top:doroni":{"slot":"top","name":"도롱이","grade":1},"top:durumagi":{"slot":"top","name":"흰 두루마기","grade":1},"top:apron":{"slot":"top","name":"앞치마 저고리","grade":1},"top:shirt":{"slot":"top","name":"단추 셔츠","grade":1},"top:ug_chain_robe":{"slot":"top","name":"사슬 수 도포","grade":1},"top:ug_ink_longcoat":{"slot":"top","name":"먹빛 장포","grade":1},"top:ug_whitenight_cheollik":{"slot":"top","name":"흰 밤 철릭","grade":1},"top:proj_vest":{"slot":"top","name":"사업 일꾼 조끼","grade":1},"top:fp_river":{"slot":"top","name":"뱃사공 저고리","grade":1},"top:fp_mandate":{"slot":"top","name":"별 수놓은 도포","grade":1},"top:rg_unbi_cape":{"slot":"top","name":"호송대 눈길 망토","grade":1},"top:rg_hisu_coat":{"slot":"top","name":"출납 서리 겉옷","grade":1},"bottom:guard":{"slot":"bottom","name":"검은 바지와 가죽 장화","grade":1},"bottom:scout":{"slot":"bottom","name":"고동 바지와 미투리","grade":1},"bottom:exorcist":{"slot":"bottom","name":"쪽빛 대님 바지","grade":1},"bottom:medic":{"slot":"bottom","name":"무명 대님 바지","grade":1},"bottom:seal":{"slot":"bottom","name":"검은 바지","grade":1},"bottom:shadow":{"slot":"bottom","name":"먹빛 바지와 짚신","grade":1},"bottom:tamer":{"slot":"bottom","name":"각반 바지와 미투리","grade":1},"bottom:blood":{"slot":"bottom","name":"쇠징 장화 바지","grade":1},"bottom:formation":{"slot":"bottom","name":"먹빛 너른 바지","grade":1},"bottom:spear":{"slot":"bottom","name":"짚신 각반 바지","grade":1},"bottom:chima":{"slot":"bottom","name":"남빛 치마","grade":1},"bottom:redmoon":{"slot":"bottom","name":"붉은 달 치마바지","grade":1},"bottom:emberwrap":{"slot":"bottom","name":"잔불 각반 바지","grade":1},"bottom:inkpleat":{"slot":"bottom","name":"먹빛 주름치마","grade":1},"bottom:haengjeon":{"slot":"bottom","name":"행전 두른 바지","grade":1},"bottom:jjokchima":{"slot":"bottom","name":"쪽빛 홑치마","grade":1},"bottom:leatherboots":{"slot":"bottom","name":"가죽 장화 바지","grade":1},"bottom:okchima":{"slot":"bottom","name":"옥색 치마","grade":1},"bottom:jeans":{"slot":"bottom","name":"청바지와 운동화","grade":1},"bottom:jogger":{"slot":"bottom","name":"줄무늬 운동 바지","grade":1},"bottom:shorts":{"slot":"bottom","name":"무릎 반바지","grade":1},"bottom:miniskirt":{"slot":"bottom","name":"주름 짧은 치마","grade":1},"bottom:flowerskirt":{"slot":"bottom","name":"꽃무늬 치마","grade":1},"bottom:ug_tide_skirt":{"slot":"bottom","name":"물결 겹치마","grade":1},"bottom:ug_ink_hakama":{"slot":"bottom","name":"먹줄 바지","grade":1},"bottom:fp_redmoon":{"slot":"bottom","name":"붉은 달 행전","grade":1},"acc:flowerpin":{"slot":"acc","name":"꽃 머리핀","grade":1},"acc:glasses":{"slot":"acc","name":"둥근 안경","grade":1},"acc:earring":{"slot":"acc","name":"구슬 귀걸이","grade":1},"acc:scarf":{"slot":"acc","name":"목도리","grade":1},"acc:norigae":{"slot":"acc","name":"노리개","grade":1},"acc:mk_hairpin":{"slot":"acc","name":"먹 묻은 붓 비녀","grade":1},"acc:mk_nameplate":{"slot":"acc","name":"삐뚤빼뚤 이름패","grade":1},"acc:mk_lotus":{"slot":"acc","name":"연꽃 매듭 노리개","grade":1},"acc:foxmask":{"slot":"acc","name":"여우 탈","grade":1},"acc:gat":{"slot":"acc","name":"흑립 갓","grade":1},"acc:jokduri":{"slot":"acc","name":"혼례 족두리","grade":1},"acc:lotushood":{"slot":"acc","name":"흑련 두건","grade":1},"acc:satgat":{"slot":"acc","name":"삿갓","grade":1},"acc:starpin":{"slot":"acc","name":"별빛 떨잠","grade":1},"acc:paeraengi":{"slot":"acc","name":"밀짚 패랭이","grade":1},"acc:horns":{"slot":"acc","name":"도깨비 뿔 머리띠","grade":1},"acc:nambawi":{"slot":"acc","name":"남바위","grade":1},"acc:cap":{"slot":"acc","name":"챙 모자","grade":1},"acc:headphone":{"slot":"acc","name":"소리 귀덮개","grade":1},"acc:shades":{"slot":"acc","name":"검은 색안경","grade":1},"acc:flowercrown":{"slot":"acc","name":"꽃 화관","grade":1},"acc:catears":{"slot":"acc","name":"고양이 귀 머리띠","grade":1},"acc:ribbon":{"slot":"acc","name":"붉은 머리끈","grade":1},"acc:beanie":{"slot":"acc","name":"털실 모자","grade":1},"acc:ug_void_crown":{"slot":"acc","name":"빈 왕관","grade":1},"acc:ug_brush_hairpin":{"slot":"acc","name":"붓 비녀","grade":1},"acc:ug_counter_hat":{"slot":"acc","name":"셈꾼 갓","grade":1},"acc:ug_wick_hairpin":{"slot":"acc","name":"등심 머리꽂이","grade":1},"acc:proj_towel":{"slot":"acc","name":"일꾼 수건","grade":1},"acc:fp_night":{"slot":"acc","name":"순라 갓끈","grade":1},"acc:fp_lotus":{"slot":"acc","name":"장부지기 토시","grade":1},"acc:fp_north":{"slot":"acc","name":"눈길 털모자","grade":1},"acc:fp_south":{"slot":"acc","name":"불씨 두건","grade":1},"acc:rg_wolha_coin":{"slot":"acc","name":"귀퉁이 엽전 끈","grade":1},"acc:rg_daon_ring":{"slot":"acc","name":"풀꽃 반지","grade":1}},"job":{"artificer":{"top":"guard","bottom":"guard"},"scout":{"top":"scout","bottom":"scout"},"exorcist":{"top":"exorcist","bottom":"exorcist"},"medic":{"top":"medic","bottom":"medic"},"sealmaster":{"top":"seal","bottom":"seal"},"analyst":{"top":"shadow","bottom":"shadow"},"tamer":{"top":"tamer","bottom":"tamer"},"bloodknight":{"top":"blood","bottom":"blood"},"formation":{"top":"formation","bottom":"formation"},"spearman":{"top":"spear","bottom":"spear"}},"masks":{"top:guard":{"n":40,"deco":3},"top:scout":{"n":70,"deco":3},"top:exorcist":{"n":79,"deco":3},"top:medic":{"n":46,"deco":3},"top:seal":{"n":42,"deco":3},"top:shadow":{"n":58,"deco":3},"top:tamer":{"n":64,"deco":3},"top:blood":{"n":53,"deco":3},"top:formation":{"n":77,"deco":3},"top:spear":{"n":65,"deco":3},"top:jeogori":{"n":35,"deco":3},"top:vest":{"n":28,"deco":3},"top:magoja":{"n":44,"deco":2},"top:jeoksam":{"n":47,"deco":2},"top:dallyeong":{"n":73,"deco":3},"top:furvest":{"n":34,"deco":3},"top:saekdong":{"n":29,"deco":3},"top:shadowrobe":{"n":69,"deco":3},"top:fisher":{"n":50,"deco":2},"top:galot":{"n":47,"deco":2},"top:silkcheollik":{"n":70,"deco":3},"top:hoodie":{"n":59,"deco":3},"top:knitvest":{"n":45,"deco":2},"top:doroni":{"n":43,"deco":3},"top:durumagi":{"n":83,"deco":2},"top:apron":{"n":24,"deco":3},"top:shirt":{"n":54,"deco":2},"top:ug_chain_robe":{"n":58,"deco":3},"top:ug_ink_longcoat":{"n":65,"deco":3},"top:ug_whitenight_cheollik":{"n":54,"deco":3},"top:proj_vest":{"n":42,"deco":3},"top:fp_river":{"n":55,"deco":3},"top:fp_mandate":{"n":73,"deco":3},"top:rg_unbi_cape":{"n":75,"deco":3},"top:rg_hisu_coat":{"n":74,"deco":3},"bottom:guard":{"n":20,"deco":1},"bottom:scout":{"n":32,"deco":1},"bottom:exorcist":{"n":30,"deco":2},"bottom:medic":{"n":30,"deco":2},"bottom:seal":{"n":32,"deco":1},"bottom:shadow":{"n":32,"deco":1},"bottom:tamer":{"n":32,"deco":1},"bottom:blood":{"n":20,"deco":1},"bottom:formation":{"n":48,"deco":2},"bottom:spear":{"n":22,"deco":2},"bottom:chima":{"n":64,"deco":1},"bottom:redmoon":{"n":45,"deco":1},"bottom:emberwrap":{"n":22,"deco":2},"bottom:inkpleat":{"n":64,"deco":1},"bottom:haengjeon":{"n":22,"deco":2},"bottom:jjokchima":{"n":64,"deco":1},"bottom:leatherboots":{"n":20,"deco":1},"bottom:okchima":{"n":64,"deco":1},"bottom:jeans":{"n":32,"deco":1},"bottom:jogger":{"n":24,"deco":2},"bottom:shorts":{"n":20,"deco":1},"bottom:miniskirt":{"n":28,"deco":1},"bottom:flowerskirt":{"n":59,"deco":2},"bottom:ug_tide_skirt":{"n":54,"deco":2},"bottom:ug_ink_hakama":{"n":48,"deco":2},"bottom:fp_redmoon":{"n":22,"deco":2}},"face":{"n":112},"hair":{"w":28,"n":952,"bx":6,"by":14,"bw":16,"bh":7}}'::jsonb);
insert into public.world_item_catalog
select (jsonb_populate_record(null::public.world_item_catalog, to_jsonb(c) || jsonb_build_object('item_id', 'of_top_blood', 'item_name', '검붉은 가죽 흉갑',
  'description', '혈기사 기본 옷. 가방에서 「옷장에」를 누르면 「내 모습」에서 입을 수 있습니다.', 'equipment_traits', jsonb_build_object('look', 'top:blood')))).*
  from public.world_item_catalog c where c.item_id = 'of_top_tamer'
on conflict (item_id) do nothing;
insert into public.world_item_catalog
select (jsonb_populate_record(null::public.world_item_catalog, to_jsonb(c) || jsonb_build_object('item_id', 'of_bottom_blood', 'item_name', '쇠징 장화 바지',
  'description', '혈기사 기본 옷. 가방에서 「옷장에」를 누르면 「내 모습」에서 입을 수 있습니다.', 'equipment_traits', jsonb_build_object('look', 'bottom:blood')))).*
  from public.world_item_catalog c where c.item_id = 'of_bottom_tamer'
on conflict (item_id) do nothing;
insert into public.world_item_catalog
select (jsonb_populate_record(null::public.world_item_catalog, to_jsonb(c) || jsonb_build_object('item_id', 'of_top_formation', 'item_name', '팔괘 띠 쪽빛 도포',
  'description', '진법가 기본 옷. 가방에서 「옷장에」를 누르면 「내 모습」에서 입을 수 있습니다.', 'equipment_traits', jsonb_build_object('look', 'top:formation')))).*
  from public.world_item_catalog c where c.item_id = 'of_top_tamer'
on conflict (item_id) do nothing;
insert into public.world_item_catalog
select (jsonb_populate_record(null::public.world_item_catalog, to_jsonb(c) || jsonb_build_object('item_id', 'of_bottom_formation', 'item_name', '먹빛 너른 바지',
  'description', '진법가 기본 옷. 가방에서 「옷장에」를 누르면 「내 모습」에서 입을 수 있습니다.', 'equipment_traits', jsonb_build_object('look', 'bottom:formation')))).*
  from public.world_item_catalog c where c.item_id = 'of_bottom_tamer'
on conflict (item_id) do nothing;
insert into public.world_item_catalog
select (jsonb_populate_record(null::public.world_item_catalog, to_jsonb(c) || jsonb_build_object('item_id', 'of_top_spear', 'item_name', '새벽빛 전복',
  'description', '여명 창객 기본 옷. 가방에서 「옷장에」를 누르면 「내 모습」에서 입을 수 있습니다.', 'equipment_traits', jsonb_build_object('look', 'top:spear')))).*
  from public.world_item_catalog c where c.item_id = 'of_top_tamer'
on conflict (item_id) do nothing;
insert into public.world_item_catalog
select (jsonb_populate_record(null::public.world_item_catalog, to_jsonb(c) || jsonb_build_object('item_id', 'of_bottom_spear', 'item_name', '짚신 각반 바지',
  'description', '여명 창객 기본 옷. 가방에서 「옷장에」를 누르면 「내 모습」에서 입을 수 있습니다.', 'equipment_traits', jsonb_build_object('look', 'bottom:spear')))).*
  from public.world_item_catalog c where c.item_id = 'of_bottom_tamer'
on conflict (item_id) do nothing;
select pg_temp.yh_setjson('public.world_outfit_rules()'::regprocedure, public.world_outfit_rules()
  || jsonb_build_object('pool', (public.world_outfit_rules() -> 'pool') || '["of_top_blood", "of_bottom_blood", "of_top_formation", "of_bottom_formation", "of_top_spear", "of_bottom_spear"]'::jsonb,
                        'src', (public.world_outfit_rules() -> 'src') || '{"top:blood": "혈기사 기본 옷 · 옷 꾸러미", "bottom:blood": "혈기사 기본 옷 · 옷 꾸러미", "top:formation": "진법가 기본 옷 · 옷 꾸러미", "bottom:formation": "진법가 기본 옷 · 옷 꾸러미", "top:spear": "여명 창객 기본 옷 · 옷 꾸러미", "bottom:spear": "여명 창객 기본 옷 · 옷 꾸러미"}'::jsonb));

update public.world_patch_notes set body = body || $N$

## 3.4.0

- 새 직업 셋이 생겼습니다.
  - 혈기사: 도끼·대검을 드는 방패입니다. 근접 공격마다 준 피해의 일부를 체력으로 되찾고(피흡), 「피 갑주」로 제 체력을 깎아 보호막을 두릅니다.
  - 여명 창객: 언월도·장창을 드는 근접 공격수입니다. 연달아 공격할수록 「창끝 기세」가 겹으로 쌓여 세지고(다섯 겹까지), 방어·버티기·물품·이동을 하면 끊깁니다. 현장 토벌에서는 첫 공격에 선제로 한 번 더 찌르고, 「관통 찌르기」는 요괴 방어의 절반을 꿰뚫습니다.
  - 진법가: 산가지·나경을 드는 치유사입니다. 다친 뒤 고치는 의무관과 달리 보호막과 피해 감소로 맞기 전에 지킵니다. 「산가지 진」은 세 턴 동안 받는 피해를 크게 줄입니다.
  - 세 직업 모두 기술 계열(혈투·창술·진법), 협동 기술 넷, 원정 기술, 비무회 기술이 있습니다. 직업 퀘스트도 세 편씩 생겼습니다(혈기사 남명회 땅 · 진법가 흑련회 땅 · 여명 창객 수향연맹 땅).
  - 잘 듣는 요괴 갈래: 혈기사 거괴·갑각 · 여명 창객 비금·천상 · 진법가 금주·수귀.
  - 기본 옷도 직업마다 한 벌씩 생겼고, 옷 꾸러미에서도 나옵니다.
- 무기를 직업마다 두 갈래로 나눴습니다. 같은 단계 무기는 위력이 같고, 갈래마다 보조 수치(묵직·예리·소리 없음)만 다릅니다. 직업별 갈래는 도움말 › 직업에 있습니다.
  - 이미 낀 무기가 새 직업 갈래에 맞지 않으면 같은 단계의 내 직업 무기로 바꿔 끼워 드렸습니다(우수품은 우수품으로, 강화·내구도는 그대로 옮김). 바뀐 조사원에게는 알림이 갑니다. 가방·창고에 있는 맞지 않는 무기는 그대로 남고, 분해·판매할 수 있습니다.
  - 갈래에 맞게 기존 무기 이름이 여럿 바뀌었습니다(예: 무쇠 철퇴 → 무쇠 도끼, 월철 환도 → 월철 등패와 환도). 바뀐 이름은 물품 정보에서 볼 수 있습니다.
  - 새 갈래를 채우는 무기 65자루와 그 제작법이 생겼습니다(1~8단계).
  - 떨어지는 무기는 내 직업 갈래가 더 잘 나옵니다.
  - 쇠뇌·취관은 화살 대신 「편전」을 씁니다. 가지고 있던 쇠뇌살은 편전으로 바뀌었습니다. 활이 쇠뇌·취관으로 바뀐 무기를 끼고 있던 조사원은 가진 화살 가운데 100개까지를 편전으로 바꿔 드렸습니다.
- 「장비 세트」가 생겼습니다. 가방 › 장비에서 지금 낀 장비를 세트로 저장해 두었다가 한 번에 바꿔 낍니다. 처음 네 칸이고, 어느 직업이든 전투 기술 계열 하나가 15단계에 닿을 때마다 한 칸씩 늘어 열 칸까지입니다(직업을 바꿔도 줄지 않습니다).
- 「환골탈태 서첩」을 모든 안전지대 상점에서 늘 팝니다(값은 레벨에 따라 다름). 이제 서첩은 직업만 바꾸고 소속은 그대로 둡니다. 레벨로 받은 능력치는 새 직업의 주 능력치에 맞게 저절로 놓이고, 쓴 뒤 한 시간은 다시 쓸 수 없습니다(남은 시간은 가방의 서첩 단추에 보입니다). 새 직업 무기가 하나도 없으면 시작 무기 하나를 받습니다. 주 능력치가 상한에 닿아 남는 점수는 직접 나눕니다.
- 직업을 바꿔도 계열마다 쌓은 기술 단계는 그대로 남고, 새 직업의 계열은 따로 키웁니다. 캐릭터 › 기술의 「다른 직업 기술」을 펼치면 다른 직업 계열의 단계와 기술을 볼 수 있습니다.
- 「세심단」(능력치만 다시 나누기)은 대세력 비고 2등급에서 공훈으로 삽니다.
- 자율 활동 「자율 수련」은 직업 계열·막기·응급 처치·분석 가운데, 「장비 정비」는 제작 분야 여덟 가운데 올릴 기술을 고를 수 있습니다. 오르는 양은 그대로입니다.$N$
 where note_id = '3.0.0' and position('## 3.4.0' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261123000000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
