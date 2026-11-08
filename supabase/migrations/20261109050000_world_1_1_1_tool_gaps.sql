do $c$ begin
  if (select count(*) from public.world_item_catalog where item_id in ('thunder_ore','star_sand','sky_feather','spirit_bark','steel_ingot','spirit_thread','reinforced_leather','cinnabar','spirit_glass','herbal_extract','lumber','moon_moss','lantern_oil','lt_hammer_4','lt_needle_4','lt_carve_4','lt_still_4','lt_cook_4','lt_sickle_4','lt_lantern_4','iron_ingot','sealing_ink','beast_bone','silk')) <> 24 then
    raise exception '3·5단계 도구: 없는 물품이 있습니다';
  end if;
  if exists (select 1 from public.world_item_catalog where item_id in ('lt_hammer_5','lt_needle_5','lt_carve_5','lt_still_5','lt_cook_5','lt_sickle_5','lt_lantern_5','lt_hammer_3','lt_needle_3','lt_carve_3','lt_still_3','lt_cook_3','lt_sickle_3','lt_lantern_3')) then
    raise exception '3·5단계 도구가 이미 있습니다';
  end if;
end $c$;

insert into public.world_item_catalog (item_id, item_name, category, tier, stackable, stack_size, tradeable, description, reference_price, equipment_traits, minimum_level)
select v.id, v.nm, 'tool', 5, b.stackable, b.stack_size, true, v.descr, v.price, v.traits::jsonb, 26
  from (values
    ('lt_hammer_5', '뇌철 단조 망치', 'lt_hammer_4', 2330, '단조·목공·법구 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +8(제작 숙련 8단계부터).',
     '{"trait": "제작 공구", "req_line": "crafting_rank", "req_rank": 8, "life_slot": "craft", "craft_fields": ["smithing", "carpentry", "artifice"], "craft_quality": 8}'),
    ('lt_needle_5', '천공 깃 바늘', 'lt_needle_4', 1420, '직조·가죽 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +8(제작 숙련 8단계부터).',
     '{"trait": "제작 공구", "req_line": "crafting_rank", "req_rank": 8, "life_slot": "craft", "craft_fields": ["weaving", "leatherwork"], "craft_quality": 8}'),
    ('lt_carve_5', '성진 각인도', 'lt_carve_4', 1400, '봉인 공예 제작 공구. 가방에 있으면 봉인 공예 품질 +8(제작 숙련 8단계부터). 각인 공구가 필요한 제작법에도 쓴다.',
     '{"trait": "제작 공구", "req_line": "crafting_rank", "req_rank": 8, "life_slot": "craft", "craft_fields": ["sealing"], "craft_quality": 8}'),
    ('lt_still_5', '성진 증류기', 'lt_still_4', 2060, '연금 제작 공구. 가방에 있으면 연금 제작 품질 +8(제작 숙련 8단계부터).',
     '{"trait": "제작 공구", "req_line": "crafting_rank", "req_rank": 8, "life_slot": "craft", "craft_fields": ["alchemy"], "craft_quality": 8}'),
    ('lt_cook_5', '뇌철 식칼', 'lt_cook_4', 1210, '요리 공구. 가방에 있으면 요리 품질 +8.',
     '{"trait": "제작 공구", "req_line": "crafting_rank", "req_rank": 1, "life_slot": "craft", "craft_fields": ["cooking"], "craft_quality": 8}'),
    ('lt_sickle_5', '천공 깃 낫', 'lt_sickle_4', 1480, '천공 깃털로 날을 벼린 낫. 장착하면 채집량 +19%, 약초·영기 채집터에서 6% 확률로 그 지역의 희귀품을 함께 거둔다.',
     '{"trait": "정밀 채집", "sig_pct": 6, "req_line": "gathering_rank", "req_rank": 10, "sig_where": "herb", "gathering_bonus_pct": 19}'),
    ('lt_lantern_5', '성진등', 'lt_lantern_4', 1580, '성진사를 갈아 넣은 등. 장착하면 채집량 +17%, 유물 채집터나 사당·지하·심연 같은 어두운 지역에서 8% 확률로 그 지역의 희귀품을 함께 거둔다.',
     '{"trait": "정밀 채집", "sig_pct": 8, "req_line": "gathering_rank", "req_rank": 10, "sig_where": "dark", "gathering_bonus_pct": 17}')
  ) v(id, nm, base, price, descr, traits)
  join public.world_item_catalog b on b.item_id = v.base;

insert into public.world_item_catalog (item_id, item_name, category, tier, stackable, stack_size, tradeable, description, reference_price, equipment_traits, minimum_level)
select v.id, v.nm, 'tool', 3, b.stackable, b.stack_size, true, v.descr, v.price, v.traits::jsonb, v.lv
  from (values
    ('lt_hammer_3', '강철 단조 망치', 'lt_hammer_4', 710, 13, '단조·목공·법구 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +4(제작 숙련 3단계부터).',
     '{"trait": "제작 공구", "req_line": "crafting_rank", "req_rank": 3, "life_slot": "craft", "craft_fields": ["smithing", "carpentry", "artifice"], "craft_quality": 4}'),
    ('lt_needle_3', '요수 뼈 바늘', 'lt_needle_4', 490, 13, '직조·가죽 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +4(제작 숙련 3단계부터).',
     '{"trait": "제작 공구", "req_line": "crafting_rank", "req_rank": 3, "life_slot": "craft", "craft_fields": ["weaving", "leatherwork"], "craft_quality": 4}'),
    ('lt_carve_3', '주사 새김칼', 'lt_carve_4', 430, 13, '봉인 공예 제작 공구. 가방에 있으면 봉인 공예 품질 +4(제작 숙련 3단계부터). 각인 공구가 필요한 제작법에도 쓴다.',
     '{"trait": "제작 공구", "req_line": "crafting_rank", "req_rank": 3, "life_slot": "craft", "craft_fields": ["sealing"], "craft_quality": 4}'),
    ('lt_still_3', '영유리 증류관', 'lt_still_4', 680, 13, '연금 제작 공구. 가방에 있으면 연금 제작 품질 +4(제작 숙련 3단계부터).',
     '{"trait": "제작 공구", "req_line": "crafting_rank", "req_rank": 3, "life_slot": "craft", "craft_fields": ["alchemy"], "craft_quality": 4}'),
    ('lt_cook_3', '요수 뼈 식칼', 'lt_cook_4', 320, 13, '요리 공구. 가방에 있으면 요리 품질 +4.',
     '{"trait": "제작 공구", "req_line": "crafting_rank", "req_rank": 1, "life_slot": "craft", "craft_fields": ["cooking"], "craft_quality": 4}'),
    ('lt_sickle_3', '주사 낫', 'lt_sickle_4', 510, 10, '주사 광물로 날을 붉게 벼린 낫. 장착하면 채집량 +9%, 약초·영기 채집터에서 4% 확률로 그 지역의 희귀품을 함께 거둔다.',
     '{"trait": "정밀 채집", "sig_pct": 4, "req_line": "gathering_rank", "req_rank": 4, "sig_where": "herb", "gathering_bonus_pct": 9}'),
    ('lt_lantern_3', '어유 등', 'lt_lantern_4', 680, 10, '등롱 어유를 태우는 등. 장착하면 채집량 +9%, 유물 채집터나 사당·지하·심연 같은 어두운 지역에서 6% 확률로 그 지역의 희귀품을 함께 거둔다.',
     '{"trait": "정밀 채집", "sig_pct": 6, "req_line": "gathering_rank", "req_rank": 4, "sig_where": "dark", "gathering_bonus_pct": 9}')
  ) v(id, nm, base, price, lv, descr, traits)
  join public.world_item_catalog b on b.item_id = v.base;

insert into public.world_crafting_recipes (recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field)
values
  ('r_lt_hammer_5', '뇌철 단조 망치 만들기', 'lt_hammer_5', 1, '{"thunder_ore":3,"steel_ingot":2,"spirit_bark":1}', null, 1, '무극 관성대', '단조·목공·법구 공예 제작 공구.', 26, null, 5, 0, null, 1, 'smithing'),
  ('r_lt_needle_5', '천공 깃 바늘 만들기', 'lt_needle_5', 1, '{"sky_feather":2,"spirit_thread":2,"reinforced_leather":1}', null, 1, '무극 관성대', '직조·가죽 공예 제작 공구.', 26, null, 5, 0, null, 1, 'leatherwork'),
  ('r_lt_carve_5', '성진 각인도 만들기', 'lt_carve_5', 1, '{"star_sand":2,"cinnabar":3,"steel_ingot":1}', null, 1, '무극 관성대', '봉인 공예 제작 공구.', 26, null, 5, 0, null, 1, 'sealing'),
  ('r_lt_still_5', '성진 증류기 만들기', 'lt_still_5', 1, '{"star_sand":2,"spirit_glass":3,"herbal_extract":2,"steel_ingot":1}', null, 1, '무극 관성대', '연금 제작 공구.', 26, null, 5, 0, null, 1, 'alchemy'),
  ('r_lt_cook_5', '뇌철 식칼 만들기', 'lt_cook_5', 1, '{"thunder_ore":2,"steel_ingot":1,"lumber":1}', null, 1, '무극 관성대', '요리 공구.', 26, null, 5, 0, null, 1, 'smithing'),
  ('r_lt_sickle_5', '천공 깃 낫 만들기', 'lt_sickle_5', 1, '{"sky_feather":2,"steel_ingot":1,"moon_moss":4}', null, 1, '무극 관성대', '천공 깃털로 날을 벼린 낫.', 26, null, 5, 0, null, 1, 'smithing'),
  ('r_lt_lantern_5', '성진등 만들기', 'lt_lantern_5', 1, '{"star_sand":2,"lantern_oil":3,"spirit_glass":2}', null, 1, '무극 관성대', '성진사를 갈아 넣은 등.', 26, null, 5, 0, null, 1, 'artifice'),
  ('r_lt_hammer_3', '강철 단조 망치 만들기', 'lt_hammer_3', 1, '{"steel_ingot":1,"iron_ingot":2,"lumber":1}', null, 1, '철벽 고찰', '단조·목공·법구 공예 제작 공구.', 13, null, 3, 0, null, 1, 'smithing'),
  ('r_lt_needle_3', '요수 뼈 바늘 만들기', 'lt_needle_3', 1, '{"beast_bone":2,"spirit_thread":1,"silk":2}', null, 1, '구름나루', '직조·가죽 공예 제작 공구.', 13, null, 3, 0, null, 1, 'leatherwork'),
  ('r_lt_carve_3', '주사 새김칼 만들기', 'lt_carve_3', 1, '{"cinnabar":2,"sealing_ink":2,"iron_ingot":2}', null, 1, '철벽 고찰', '봉인 공예 제작 공구.', 13, null, 3, 0, null, 1, 'sealing'),
  ('r_lt_still_3', '영유리 증류관 만들기', 'lt_still_3', 1, '{"spirit_glass":2,"iron_ingot":2,"herbal_extract":1}', null, 1, '백등 야시장', '연금 제작 공구.', 13, null, 3, 0, null, 1, 'alchemy'),
  ('r_lt_cook_3', '요수 뼈 식칼 만들기', 'lt_cook_3', 1, '{"beast_bone":2,"iron_ingot":2,"lumber":1}', null, 1, '백등 야시장', '요리 공구.', 13, null, 3, 0, null, 1, 'smithing'),
  ('r_lt_sickle_3', '주사 낫 만들기', 'lt_sickle_3', 1, '{"iron_ingot":2,"cinnabar":2,"moon_moss":3}', null, 1, '구름나루', '주사 광물로 날을 붉게 벼린 낫.', 10, null, 3, 0, null, 1, 'smithing'),
  ('r_lt_lantern_3', '어유 등 만들기', 'lt_lantern_3', 1, '{"lantern_oil":2,"iron_ingot":2,"spirit_glass":1}', null, 1, '철벽 고찰', '등롱 어유를 태우는 등.', 10, null, 3, 0, null, 1, 'artifice');

insert into public.world_tool_lines (item_id, line)
values ('lt_hammer_5', 'hammer'), ('lt_needle_5', 'needle'), ('lt_carve_5', 'carve'), ('lt_still_5', 'still'), ('lt_cook_5', 'cook'), ('lt_sickle_5', 'sickle'), ('lt_lantern_5', 'lantern'),
  ('lt_hammer_3', 'hammer'), ('lt_needle_3', 'needle'), ('lt_carve_3', 'carve'), ('lt_still_3', 'still'), ('lt_cook_3', 'cook'), ('lt_sickle_3', 'sickle'), ('lt_lantern_3', 'lantern');

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
  rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade, use_fx)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable,
  i.required_stats, i.required_job, i.required_faction, i.minimum_level, i.rarity, i.acquisition_difficulty, i.drop_rate_modifier,
  public.world_item_hq_traits(i.equipment_traits), i.crafting_specialization, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.item_id, 1, null
  from public.world_item_catalog i
 where i.item_id in ('lt_hammer_5', 'lt_needle_5', 'lt_carve_5', 'lt_still_5', 'lt_cook_5', 'lt_sickle_5', 'lt_lantern_5', 'lt_hammer_3', 'lt_needle_3', 'lt_carve_3', 'lt_still_3', 'lt_cook_3', 'lt_sickle_3', 'lt_lantern_3')
on conflict (item_id) do nothing;

update public.world_patch_notes set body = body || E'\n- 비어 있던 3·5단계 채집·제작 도구 열네 가지를 만들 수 있습니다. 3단계(Lv10~13): 제작 공구 다섯(강철 단조 망치·요수 뼈 바늘·주사 새김칼·영유리 증류관·요수 뼈 식칼, 품질 +4)과 주사 낫·어유 등. 5단계(Lv26, 무극 관성대): 제작 공구 다섯(뇌철 단조 망치·천공 깃 바늘·성진 각인도·성진 증류기·뇌철 식칼, 품질 +8)과 천공 깃 낫·성진등.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109050000' where key = 'db_version';
