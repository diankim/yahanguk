do $c$ begin
  if (select count(*) from public.world_item_catalog where item_id in ('seal_shard','raid_norigae','raid_amulet','raid_mask','hf_gayageum','hf_rug_unhak','hp_celadon','hg_okdol','silk','talisman_thread','spirit_core','ward_fragment','fine_paper','ghost_ash','monster_core','lumber','lacquer','moon_moss','ore','herbal_extract')) <> 20 then
    raise exception '봉연 파편 제작법: 없는 물품이 있습니다';
  end if;
  if exists (select 1 from public.world_item_catalog where item_id = 'seal_incense' or item_name = '봉연 진정향') then
    raise exception '봉연 진정향이 이미 있습니다';
  end if;
end $c$;

insert into public.world_item_catalog (item_id, item_name, category, tier, rarity, stackable, stack_size, tradeable, description, reference_price, equipment_traits, minimum_level, use_fx)
values ('seal_incense', '봉연 진정향', 'consumable', 4, 'epic', true, 20, false,
  '봉연 파편을 곱게 갈아 원령재와 함께 사른 향. 연기를 들이마시면 침식이 30 내려가고 정신이 20 돌아오며, 심신 동요와 사념 침식이 풀린다.',
  260, '{}'::jsonb, 20, '{"er":30,"hp":0,"mn":20,"sp":0,"stam":0,"buffs":[],"cures":["shaken","erosion_whisper"]}'::jsonb);

update public.world_item_catalog set reference_price = 2700 where item_id in ('raid_norigae', 'raid_amulet', 'raid_mask');

insert into public.world_crafting_recipes (recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field)
values
  ('r_raid_norigae', '봉연 매듭 엮기', 'raid_norigae', 1, '{"seal_shard":12,"spirit_core":2,"silk":3,"talisman_thread":2}', null, 1, '구중 봉연',
   '봉연 파편을 영사에 꿰어 봉연 매듭을 엮는다.', 25, null, 5, 0, null, 1, 'weaving'),
  ('r_raid_amulet', '봉연 호패 새기기', 'raid_amulet', 1, '{"seal_shard":12,"spirit_core":2,"ward_fragment":4,"fine_paper":2}', null, 1, '구중 봉연',
   '봉연 파편을 결계 파편과 함께 눌러 봉연 호패를 새긴다.', 25, null, 5, 0, null, 1, 'sealing'),
  ('r_raid_mask', '그림자 탈 깎기', 'raid_mask', 1, '{"seal_shard":12,"spirit_core":2,"ghost_ash":3,"monster_core":1}', null, 1, '구중 봉연',
   '봉연 파편으로 그림자 탈의 결을 깎아 낸다.', 25, null, 5, 0, null, 1, 'sealing'),
  ('r_hf_gayageum', '가야금 걸이 만들기', 'hf_gayageum', 1, '{"seal_shard":4,"lumber":2,"silk":1,"lacquer":1}', null, 1, null,
   '별채에 걸 가야금 걸이를 만든다. 줄받침에 봉연 파편을 박는다.', 20, null, 4, 0, null, 1, 'carpentry'),
  ('r_hf_rug_unhak', '운학 양탄자 짜기', 'hf_rug_unhak', 1, '{"seal_shard":4,"silk":2,"talisman_thread":1}', null, 1, null,
   '별채에 깔 운학 양탄자를 짠다. 학의 눈을 봉연 파편 가루로 물들인다.', 20, null, 4, 0, null, 1, 'weaving'),
  ('r_hp_celadon', '청자빛 구름 바르기', 'hp_celadon', 1, '{"seal_shard":4,"fine_paper":2,"moon_moss":1}', null, 1, null,
   '별채 벽에 청자빛 구름을 바른다. 봉연 파편 가루가 은은하게 빛난다.', 20, null, 4, 0, null, 1, 'sealing'),
  ('r_hg_okdol', '옥돌 바닥 깔기', 'hg_okdol', 1, '{"seal_shard":4,"ore":4,"lumber":2}', null, 1, null,
   '별채에 옥돌 바닥을 깐다. 이음새에 봉연 파편을 메운다.', 20, null, 4, 0, null, 1, 'carpentry'),
  ('r_seal_incense', '봉연 진정향 사르기', 'seal_incense', 2, '{"seal_shard":2,"ghost_ash":2,"herbal_extract":1}', null, 1, null,
   '봉연 파편을 갈아 원령재·약초액과 섞어 진정향을 빚는다.', 20, null, 4, 0, null, 1, 'alchemy');

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
  rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade, use_fx)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable,
  i.required_stats, i.required_job, i.required_faction, i.minimum_level, i.rarity, i.acquisition_difficulty, i.drop_rate_modifier,
  case when i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then public.world_item_hq_traits(i.equipment_traits) else i.equipment_traits end,
  i.crafting_specialization, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.item_id, 1, null
  from public.world_item_catalog i
 where i.item_id in ('raid_norigae', 'raid_amulet', 'raid_mask', 'seal_incense')
on conflict (item_id) do nothing;

update public.world_patch_notes set body = body || E'\n- 봉연 파편으로 만드는 제작법이 생겼습니다. 봉연의 그림자 토벌 장비 셋(봉연 매듭·봉연 호패·그림자 탈, Lv25)과 가구 넷(가야금 걸이·운학 양탄자·청자빛 구름·옥돌 바닥, Lv20), 새 소모품 「봉연 진정향」(침식 −30·정신 +20·심신 동요·사념 침식 풀림)을 만들 수 있습니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109000000' where key = 'db_version';
