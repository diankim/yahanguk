update public.world_mount_catalog set description = '날개에 별자리 무늬가 있는 큰 학. 넓은 등에 넷이 나란히 앉는다.'
 where mount_id = 'fm_mandate_court' and description = '날개에 별자리 무늬가 있는 큰 학. 한 사람만 태운다.';
update public.world_mount_catalog set description = '붉은 달밤에만 눈을 뜨는 검은 표범. 등이 넓어 넷이 탄다.'
 where mount_id = 'fm_red_moon_cult' and description = '붉은 달밤에만 눈을 뜨는 검은 표범. 등이 넓어 둘이 탄다.';

do $p$
declare n int;
begin
  update public.world_quest_steps
     set lines = jsonb_set(lines, '{3,t}', to_jsonb(replace(lines -> 3 ->> 't', '매번 조금씩 깁니다.', '매번 조금씩 길어집니다.')))
   where quest_id = 'sq_sealed_abyss_1' and step = 2 and lines -> 3 ->> 't' like '%매번 조금씩 깁니다.%';
  get diagnostics n = row_count;
  if n > 1 then raise exception '퀘스트 대사 고치기 대상이 예상과 다릅니다'; end if;
end $p$;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
values
  ('hp_heukbyeok', '흙벽', 'furniture', 1, '별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"heukbyeok","cat":"벽지","kind":"paper","grade":1}'::jsonb, true, 100, 1),
  ('hp_saekdong', '색동 벽지', 'furniture', 2, '별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"saekdong","cat":"벽지","kind":"paper","grade":2}'::jsonb, true, 270, 1),
  ('hp_mulgyeol', '물결무늬', 'furniture', 2, '별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"mulgyeol","cat":"벽지","kind":"paper","grade":2}'::jsonb, true, 270, 1),
  ('hp_maehwa', '매화 벽지', 'furniture', 3, '별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"maehwa","cat":"벽지","kind":"paper","grade":3}'::jsonb, true, 470, 1),
  ('hg_daesal', '대살 마루', 'furniture', 1, '별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"daesal","cat":"바닥재","kind":"ground","grade":1}'::jsonb, true, 90, 1),
  ('hg_hwamun', '쪽빛 화문석', 'furniture', 2, '별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"hwamun","cat":"바닥재","kind":"ground","grade":2}'::jsonb, true, 200, 1),
  ('hg_bakseok', '박석 바닥', 'furniture', 2, '별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"bakseok","cat":"바닥재","kind":"ground","grade":2}'::jsonb, true, 200, 1),
  ('hg_wanja', '완자 마루', 'furniture', 3, '별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"wanja","cat":"바닥재","kind":"ground","grade":3}'::jsonb, true, 840, 1)
on conflict (item_id) do nothing;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, description, minimum_level, recipe_difficulty, quality_bonus, required_skill_rank, craft_field)
values
  ('r_hp_heukbyeok', '흙벽 만들기', 'hp_heukbyeok', 1, '{"seal_paper":4}'::jsonb, '별채에 놓을 흙벽을(를) 만든다.', 1, 1, 0, 1, 'sealing'),
  ('r_hp_saekdong', '색동 벽지 만들기', 'hp_saekdong', 1, '{"cinnabar":1,"fine_paper":2}'::jsonb, '별채에 놓을 색동 벽지을(를) 만든다.', 8, 2, 0, 1, 'sealing'),
  ('r_hp_mulgyeol', '물결무늬 만들기', 'hp_mulgyeol', 1, '{"cinnabar":1,"fine_paper":2}'::jsonb, '별채에 놓을 물결무늬을(를) 만든다.', 8, 2, 0, 1, 'sealing'),
  ('r_hp_maehwa', '매화 벽지 만들기', 'hp_maehwa', 1, '{"inkstone":1,"fine_paper":3,"sealing_ink":2}'::jsonb, '별채에 놓을 매화 벽지을(를) 만든다.', 15, 3, 0, 1, 'sealing'),
  ('r_hg_daesal', '대살 마루 만들기', 'hg_daesal', 1, '{"wood":5}'::jsonb, '별채에 놓을 대살 마루을(를) 만든다.', 1, 1, 0, 1, 'carpentry'),
  ('r_hg_hwamun', '쪽빛 화문석 만들기', 'hg_hwamun', 1, '{"ore":2,"lumber":3}'::jsonb, '별채에 놓을 쪽빛 화문석을(를) 만든다.', 8, 2, 0, 1, 'carpentry'),
  ('r_hg_bakseok', '박석 바닥 만들기', 'hg_bakseok', 1, '{"ore":2,"lumber":3}'::jsonb, '별채에 놓을 박석 바닥을(를) 만든다.', 8, 2, 0, 1, 'carpentry'),
  ('r_hg_wanja', '완자 마루 만들기', 'hg_wanja', 1, '{"lumber":2,"reinforced_lumber":2}'::jsonb, '별채에 놓을 완자 마루을(를) 만든다.', 15, 3, 0, 1, 'carpentry')
on conflict (recipe_id) do nothing;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
values
  ('south_market', 'hp_heukbyeok', 100, 0, 10, null), ('underworld_market', 'hp_heukbyeok', 100, 0, 10, null),
  ('river_market', 'hg_daesal', 90, 0, 10, null), ('capital_market', 'hg_daesal', 90, 0, 10, null)
on conflict (shop_id, item_id) do nothing;

insert into public.world_furniture_sources(source, item_id, chance)
values
  ('drop_normal', 'hp_saekdong', 1), ('drop_normal', 'hp_mulgyeol', 1), ('drop_normal', 'hg_hwamun', 1), ('drop_normal', 'hg_bakseok', 1),
  ('drop_guardian', 'hp_maehwa', 1), ('expedition', 'hp_maehwa', 1), ('drop_guardian', 'hg_wanja', 1), ('expedition', 'hg_wanja', 1)
on conflict do nothing;

update public.world_patch_notes set body = body || E'\n- 별채 벽지 넷(흙벽·색동 벽지·물결무늬·매화 벽지)과 바닥재 넷(대살 마루·쪽빛 화문석·박석 바닥·완자 마루)을 더했습니다. 얻는 길은 같은 등급의 다른 벽지·바닥재와 같습니다.'
  || E'\n- 꼬마 동무 돌보기 문구가 그 동무의 몸에 맞는 것만 나옵니다(귀·날개·부리가 없는 동무, 떠다니지 않는 동무 등).'
  || E'\n- 세력 탈것 설명의 태우는 사람 수를 지금 정원에 맞추고, 보조 퀘스트 대사 한 줄을 다듬었습니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109110000' where key = 'db_version';
