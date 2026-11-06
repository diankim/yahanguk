insert into public.world_pet_species(pet_id, pet_name, grade, kind, likes, how, sort, egg)
select x.pet_id, x.pet_name, x.grade, x.kind, x.likes, x.how, x.sort, x.egg
  from (values
    ('hermit_crab', '소라게', 1, 'shell', 'treat_fish', '안전지대 상점의 바구니', 48, false),
    ('baby_pangolin', '아기 천산갑', 2, 'shell', 'treat_honey', '탐색 중 「얼룩무늬 알」', 49, true),
    ('ladybug', '무당벌레', 1, 'swarm', 'treat_honey', '안전지대 상점의 바구니', 50, false),
    ('bee_trio', '꿀벌 삼형제', 2, 'swarm', 'treat_honey', '탐색 중 「얼룩무늬 알」', 51, true),
    ('tree_frog', '청개구리', 1, 'venom', 'treat_meat', '안전지대 상점의 바구니', 52, false),
    ('baby_salamander', '아기 도롱뇽', 2, 'venom', 'treat_fish', '탐색 중 「얼룩무늬 알」', 53, true),
    ('baby_tapir', '아기 맥', 1, 'mirror', 'treat_herb', '안전지대 상점의 바구니', 54, false),
    ('baby_jangsanbeom', '아기 장산범', 2, 'mirror', 'treat_meat', '탐색 중 「얼룩무늬 알」', 55, true),
    ('paper_doll', '종이 인형 혼령', 1, 'ghost', 'treat_rice', '안전지대 상점의 바구니', 56, false),
    ('baby_boar', '아기 멧돼지', 1, 'breaker', 'treat_herb', '안전지대 상점의 바구니', 57, false),
    ('baby_white_bear', '아기 흰곰', 3, 'giant', 'treat_fish', '탐색 중 「빛나는 알」', 58, true)
  ) as x(pet_id, pet_name, grade, kind, likes, how, sort, egg)
on conflict (pet_id) do update set pet_name = excluded.pet_name, grade = excluded.grade, kind = excluded.kind, likes = excluded.likes, how = excluded.how, sort = excluded.sort, egg = excluded.egg;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
values
  ('pt_hermit_crab', '소라게 바구니', 'pet', 1, '제 몸보다 큰 소라 껍데기를 집처럼 이고 다니는 게입니다. 낯선 소리가 나면 쏙 숨었다가, 아무 일 없으면 눈자루만 먼저 내밀어 살핍니다. 더 좋은 껍데기를 보면 한참을 망설입니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"hermit_crab"}'::jsonb, true, 300, 1),
  ('pt_ladybug', '무당벌레 바구니', 'pet', 1, '빨간 등에 까만 점이 일곱 개 박힌 벌레입니다. 손가락 끝까지 기어 올라가서야 날개를 펴고 날아오릅니다. 점을 세어 주면 좋아하는지 잠깐 멈춰 섭니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"ladybug"}'::jsonb, true, 300, 1),
  ('pt_tree_frog', '청개구리 바구니', 'pet', 1, '빗방울 소리를 누구보다 먼저 알아듣는 손톱만 한 개구리입니다. 오라 하면 가고 가라 하면 오는 고집쟁이라, 부를 때는 반대로 부르는 편이 빠릅니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"tree_frog"}'::jsonb, true, 300, 1),
  ('pt_baby_tapir', '아기 맥 바구니', 'pet', 1, '수박처럼 줄무늬가 진 새끼 맥입니다. 자라면 줄이 지워지고 검은 몸에 흰 띠를 두른 모습이 됩니다. 옛사람들은 맥이 나쁜 꿈을 먹는다 하여, 머리맡에 맥 그림을 두고 잤습니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"baby_tapir"}'::jsonb, true, 300, 1),
  ('pt_paper_doll', '종이 인형 혼령 바구니', 'pet', 1, '아이가 오려 만든 종이 인형에 깃든 작은 혼령입니다. 바람이 불면 팔랑이며 날아가 버릴까 봐 늘 무언가에 매달려 있습니다. 이름을 적어 주면 그 글자를 소매 속에 소중히 넣어 둡니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"paper_doll"}'::jsonb, true, 300, 1),
  ('pt_baby_boar', '아기 멧돼지 바구니', 'pet', 1, '등에 참외 같은 줄무늬가 난 새끼 멧돼지입니다. 도토리 냄새가 나면 코로 땅을 파헤치며 돌진하고, 멈추는 법은 아직 잘 모릅니다. 자라면 줄무늬가 지워지고 작은 엄니가 돋습니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"baby_boar"}'::jsonb, true, 300, 1)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, x.item_id, 300, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join (values ('pt_hermit_crab'), ('pt_ladybug'), ('pt_tree_frog'), ('pt_baby_tapir'), ('pt_paper_doll'), ('pt_baby_boar')) as x(item_id)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
values
  ('hf_rug_hemp', '삼베 깔개', 'furniture', 1, '별채 가구 · 깔개. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":2,"hk":"rug_hemp","cat":"깔개","top":0,"kind":"rug","grade":1,"pet":"bed"}'::jsonb, true, 90, 1),
  ('hf_surf_vase', '백자 꽃병', 'furniture', 1, '별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"surf_vase","cat":"소품","top":0,"kind":"surface","grade":1}'::jsonb, true, 80, 1),
  ('hf_surf_brush', '붓꽂이', 'furniture', 1, '별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"surf_brush","cat":"소품","top":0,"kind":"surface","grade":1}'::jsonb, true, 60, 1),
  ('hf_pet_nest', '짚 둥지', 'furniture', 1, '별채 가구 · 동무 가구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_nest","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"bed"}'::jsonb, true, 70, 1),
  ('hf_pet_ball', '오색 공', 'furniture', 1, '별채 가구 · 동무 가구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_ball","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"toy"}'::jsonb, true, 70, 1),
  ('hf_pet_waterbowl', '돌 물그릇', 'furniture', 1, '별채 가구 · 동무 가구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_waterbowl","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"bowl"}'::jsonb, true, 80, 1),
  ('hf_frame_small', '작은 그림 액자', 'furniture', 1, '별채 가구 · 액자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"frame_small","wh":20,"ww":1,"cat":"액자","kind":"wall","wall":"deco","grade":1,"frame":true}'::jsonb, true, 80, 1),
  ('hf_surf_lamp', '사기 등잔', 'furniture', 2, '별채 가구 · 조명. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"surf_lamp","cat":"조명","top":0,"kind":"surface","grade":2}'::jsonb, true, 160, 1),
  ('hf_surf_suseok', '수석 받침', 'furniture', 2, '별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"surf_suseok","cat":"소품","top":0,"kind":"surface","grade":2}'::jsonb, true, 130, 1),
  ('hf_pet_quilt', '누비 동무 이불', 'furniture', 2, '별채 가구 · 동무 가구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_quilt","cat":"동무 가구","top":0,"kind":"floor","grade":2,"pet":"bed"}'::jsonb, true, 220, 1),
  ('hf_frame_large', '큰 그림 액자', 'furniture', 2, '별채 가구 · 액자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"frame_large","wh":30,"ww":2,"cat":"액자","kind":"wall","wall":"deco","grade":2,"frame":true}'::jsonb, true, 230, 1),
  ('hf_rug_mojeon', '꽃수 모전', 'furniture', 3, '별채 가구 · 깔개. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":2,"w":3,"hk":"rug_mojeon","cat":"깔개","top":0,"kind":"rug","grade":3,"pet":"bed"}'::jsonb, true, 560, 1),
  ('hf_surf_najeon_box', '자개 함', 'furniture', 3, '별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"surf_najeon_box","cat":"소품","top":0,"kind":"surface","grade":3}'::jsonb, true, 450, 1),
  ('hf_pet_tower', '동무 놀이 층대', 'furniture', 3, '별채 가구 · 동무 가구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_tower","cat":"동무 가구","top":1.6,"kind":"floor","grade":3,"pet":"perch"}'::jsonb, true, 520, 1),
  ('hf_bedding_wonang', '원앙금침', 'furniture', 4, '별채 가구 · 침구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":2,"hk":"bedding_wonang","cat":"침구","top":0,"kind":"floor","grade":4,"pet":"bed"}'::jsonb, false, 800, 1),
  ('hg_okdol', '옥돌 바닥', 'furniture', 4, '별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"okdol","cat":"바닥재","kind":"ground","grade":4}'::jsonb, false, 800, 1),
  ('hp_celadon', '청자빛 구름', 'furniture', 4, '별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"celadon","cat":"벽지","kind":"paper","grade":4}'::jsonb, false, 800, 1),
  ('hf_rug_manhwa', '만화 융단', 'furniture', 5, '별채 가구 · 깔개. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":3,"w":3,"hk":"rug_manhwa","cat":"깔개","top":0,"kind":"rug","grade":5,"pet":"bed"}'::jsonb, false, 2000, 1),
  ('hg_geumbak', '금박 장판', 'furniture', 5, '별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"geumbak","cat":"바닥재","kind":"ground","grade":5}'::jsonb, false, 2000, 1),
  ('hp_geumni', '금니 단청', 'furniture', 5, '별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"geumni","cat":"벽지","kind":"paper","grade":5}'::jsonb, false, 2000, 1)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, description, minimum_level, recipe_difficulty, quality_bonus, required_skill_rank, craft_field)
values
  ('r_hf_rug_hemp', '삼베 깔개 만들기', 'hf_rug_hemp', 1, '{"river_reed":3,"wood":1}'::jsonb, '별채에 놓을 삼베 깔개을(를) 만든다.', 1, 1, 0, 1, 'weaving'),
  ('r_hf_surf_vase', '백자 꽃병 만들기', 'hf_surf_vase', 1, '{"ore":2,"herb":2}'::jsonb, '별채에 놓을 백자 꽃병을(를) 만든다.', 1, 1, 0, 1, 'artifice'),
  ('r_hf_surf_brush', '붓꽂이 만들기', 'hf_surf_brush', 1, '{"wood":2,"inkstone":1}'::jsonb, '별채에 놓을 붓꽂이을(를) 만든다.', 1, 1, 0, 1, 'carpentry'),
  ('r_hf_pet_nest', '짚 둥지 만들기', 'hf_pet_nest', 1, '{"river_reed":3}'::jsonb, '별채에 놓을 짚 둥지을(를) 만든다.', 1, 1, 0, 1, 'weaving'),
  ('r_hf_pet_ball', '오색 공 만들기', 'hf_pet_ball', 1, '{"river_reed":1,"seal_paper":2}'::jsonb, '별채에 놓을 오색 공을(를) 만든다.', 1, 1, 0, 1, 'weaving'),
  ('r_hf_pet_waterbowl', '돌 물그릇 만들기', 'hf_pet_waterbowl', 1, '{"ore":3}'::jsonb, '별채에 놓을 돌 물그릇을(를) 만든다.', 1, 1, 0, 1, 'artifice'),
  ('r_hf_frame_small', '작은 그림 액자 만들기', 'hf_frame_small', 1, '{"wood":2,"seal_paper":2}'::jsonb, '별채에 놓을 작은 그림 액자을(를) 만든다.', 1, 1, 0, 1, 'carpentry'),
  ('r_hf_surf_lamp', '사기 등잔 만들기', 'hf_surf_lamp', 1, '{"ore":2,"charcoal":1,"fine_paper":1}'::jsonb, '별채에 놓을 사기 등잔을(를) 만든다.', 8, 2, 0, 1, 'artifice'),
  ('r_hf_surf_suseok', '수석 받침 만들기', 'hf_surf_suseok', 1, '{"lumber":1,"ore":3}'::jsonb, '별채에 놓을 수석 받침을(를) 만든다.', 8, 2, 0, 1, 'carpentry'),
  ('r_hf_pet_quilt', '누비 동무 이불 만들기', 'hf_pet_quilt', 1, '{"silk":1,"cloud_cotton":2}'::jsonb, '별채에 놓을 누비 동무 이불을(를) 만든다.', 8, 2, 0, 1, 'weaving'),
  ('r_hf_frame_large', '큰 그림 액자 만들기', 'hf_frame_large', 1, '{"lumber":2,"fine_paper":1,"lacquer":1}'::jsonb, '별채에 놓을 큰 그림 액자을(를) 만든다.', 8, 2, 0, 1, 'carpentry'),
  ('r_hf_rug_mojeon', '꽃수 모전 만들기', 'hf_rug_mojeon', 1, '{"silk":3,"cloud_cotton":2,"spirit_thread":1}'::jsonb, '별채에 놓을 꽃수 모전을(를) 만든다.', 15, 3, 0, 1, 'weaving'),
  ('r_hf_surf_najeon_box', '자개 함 만들기', 'hf_surf_najeon_box', 1, '{"lacquer":2,"mirror_shard":1,"lumber":1}'::jsonb, '별채에 놓을 자개 함을(를) 만든다.', 15, 3, 0, 1, 'carpentry'),
  ('r_hf_pet_tower', '동무 놀이 층대 만들기', 'hf_pet_tower', 1, '{"lumber":3,"reinforced_lumber":1,"resin":1}'::jsonb, '별채에 놓을 동무 놀이 층대을(를) 만든다.', 15, 3, 0, 1, 'carpentry')
on conflict (recipe_id) do update set recipe_name = excluded.recipe_name, output_item = excluded.output_item, ingredients = excluded.ingredients, description = excluded.description,
  minimum_level = excluded.minimum_level, recipe_difficulty = excluded.recipe_difficulty, craft_field = excluded.craft_field;

insert into public.world_furniture_sources(source, item_id, chance)
values
  ('drop_normal', 'hf_surf_lamp', 1),
  ('drop_normal', 'hf_surf_suseok', 1),
  ('drop_normal', 'hf_pet_quilt', 1),
  ('drop_normal', 'hf_frame_large', 1),
  ('drop_guardian', 'hf_rug_mojeon', 1),
  ('expedition', 'hf_rug_mojeon', 1),
  ('drop_guardian', 'hf_surf_najeon_box', 1),
  ('expedition', 'hf_surf_najeon_box', 1),
  ('drop_guardian', 'hf_pet_tower', 1),
  ('expedition', 'hf_pet_tower', 1),
  ('title:wed_vow', 'hf_bedding_wonang', 1),
  ('raid_world', 'hg_okdol', 1),
  ('raid_world', 'hp_celadon', 1),
  ('gw_first', 'hf_rug_manhwa', 1),
  ('raid_final', 'hg_geumbak', 1),
  ('raid_final', 'hp_geumni', 1)
on conflict do nothing;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
values
  ('capital_market', 'hf_rug_hemp', 90, 0, 10, null),
  ('river_market', 'hf_rug_hemp', 90, 0, 10, null),
  ('south_market', 'hf_rug_hemp', 90, 0, 10, null),
  ('capital_market', 'hf_surf_vase', 80, 0, 10, null),
  ('astral_market', 'hf_surf_vase', 80, 0, 10, null),
  ('night_office_store', 'hf_surf_brush', 60, 0, 10, null),
  ('north_market', 'hf_surf_brush', 60, 0, 10, null),
  ('capital_market', 'hf_pet_nest', 70, 0, 10, null),
  ('frontier_market', 'hf_pet_nest', 70, 0, 10, null),
  ('underworld_market', 'hf_pet_nest', 70, 0, 10, null),
  ('river_market', 'hf_pet_ball', 70, 0, 10, null),
  ('astral_market', 'hf_pet_ball', 70, 0, 10, null),
  ('north_market', 'hf_pet_waterbowl', 80, 0, 10, null),
  ('south_market', 'hf_pet_waterbowl', 80, 0, 10, null),
  ('capital_market', 'hf_frame_small', 80, 0, 10, null),
  ('night_office_store', 'hf_frame_small', 80, 0, 10, null),
  ('underworld_market', 'hf_frame_small', 80, 0, 10, null),
  ('frontier_market', 'hf_frame_small', 80, 0, 10, null)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;

do $g$
declare r record;
begin
  for r in select distinct w.owner_id, w.source from public.world_housing_rewards w
            where w.source in ('title:wed_vow', 'gw_first', 'raid_final') and exists (select 1 from public.world_housing h where h.owner_id = w.owner_id) loop
    perform public.world_housing_grant_once(r.owner_id, r.source, '새로 생긴 보상 가구');
  end loop;
end $g$;

update public.world_app_meta set value = '20261108000000' where key = 'db_version';
