insert into public.world_pet_species(pet_id, pet_name, grade, kind, likes, how, sort, egg)
select x.pet_id, x.pet_name, x.grade, x.kind, x.likes, x.how, x.sort, x.egg
  from (values
    ('hermit_crab', '소라게', 1, 'shell', 'treat_fish', '안전지대 상점의 바구니', 48, false),
    ('baby_pangolin', '아기 천산갑', 2, 'shell', 'treat_honey', '탐색 중 「얼룩무늬 알」', 49, true),
    ('rhino_beetle', '장수풍뎅이', 1, 'swarm', 'treat_honey', '안전지대 상점의 바구니', 50, false),
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
  ('pt_rhino_beetle', '장수풍뎅이 바구니', 'pet', 1, '뿔 하나를 자랑스레 치켜든 갑옷 같은 풍뎅이입니다. 참나무 진 냄새를 맡으면 밤새 나무를 기어오르고, 힘겨루기에서 지면 한참을 뒤집힌 채 버둥거립니다. 등을 쓸어 주면 윤이 나는 게 좋은지 가만히 있습니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"rhino_beetle"}'::jsonb, true, 300, 1),
  ('pt_tree_frog', '청개구리 바구니', 'pet', 1, '빗방울 소리를 누구보다 먼저 알아듣는 손톱만 한 개구리입니다. 오라 하면 가고 가라 하면 오는 고집쟁이라, 부를 때는 반대로 부르는 편이 빠릅니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"tree_frog"}'::jsonb, true, 300, 1),
  ('pt_baby_tapir', '아기 맥 바구니', 'pet', 1, '수박처럼 줄무늬가 진 새끼 맥입니다. 자라면 줄이 지워지고 검은 몸에 흰 띠를 두른 모습이 됩니다. 옛사람들은 맥이 나쁜 꿈을 먹는다 하여, 머리맡에 맥 그림을 두고 잤습니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"baby_tapir"}'::jsonb, true, 300, 1),
  ('pt_paper_doll', '종이 인형 혼령 바구니', 'pet', 1, '아이가 오려 만든 종이 인형에 깃든 작은 혼령입니다. 바람이 불면 팔랑이며 날아가 버릴까 봐 늘 무언가에 매달려 있습니다. 이름을 적어 주면 그 글자를 소매 속에 소중히 넣어 둡니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"paper_doll"}'::jsonb, true, 300, 1),
  ('pt_baby_boar', '아기 멧돼지 바구니', 'pet', 1, '등에 참외 같은 줄무늬가 난 새끼 멧돼지입니다. 도토리 냄새가 나면 코로 땅을 파헤치며 돌진하고, 멈추는 법은 아직 잘 모릅니다. 자라면 줄무늬가 지워지고 작은 엄니가 돋습니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"baby_boar"}'::jsonb, true, 300, 1)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, x.item_id, 300, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join (values ('pt_hermit_crab'), ('pt_rhino_beetle'), ('pt_tree_frog'), ('pt_baby_tapir'), ('pt_paper_doll'), ('pt_baby_boar')) as x(item_id)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
values
  ('hf_rug_hemp', '삼베 깔개', 'furniture', 1, '별채 가구 · 깔개. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":2,"hk":"rug_hemp","cat":"깔개","top":0,"kind":"rug","grade":1,"pet":"bed"}'::jsonb, true, 90, 1),
  ('hf_surf_vase', '백자 꽃병', 'furniture', 1, '별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"surf_vase","cat":"소품","top":0,"kind":"surface","grade":1}'::jsonb, true, 80, 1),
  ('hf_surf_brush', '붓꽂이', 'furniture', 1, '별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"surf_brush","cat":"소품","top":0,"kind":"surface","grade":1}'::jsonb, true, 60, 1),
  ('hf_pet_nest', '짚 둥지', 'furniture', 1, '별채 가구 · 동무 가구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_nest","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"bed"}'::jsonb, true, 70, 1),
  ('hf_pet_ball', '오색 공', 'furniture', 1, '별채 가구 · 동무 가구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_ball","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"toy"}'::jsonb, true, 70, 1),
  ('hf_pet_waterbowl', '돌 물그릇', 'furniture', 1, '별채 가구 · 동무 가구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_waterbowl","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"bowl"}'::jsonb, true, 80, 1),
  ('hf_frame_small', '작은 그림 액자', 'furniture', 1, '별채 가구 · 액자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"frame_small","wh":22,"ww":1.25,"cat":"액자","kind":"wall","wall":"deco","grade":1,"frame":"S"}'::jsonb, true, 80, 1),
  ('hf_surf_lamp', '사기 등잔', 'furniture', 2, '별채 가구 · 조명. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"surf_lamp","cat":"조명","top":0,"kind":"surface","grade":2}'::jsonb, true, 160, 1),
  ('hf_surf_suseok', '수석 받침', 'furniture', 2, '별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"surf_suseok","cat":"소품","top":0,"kind":"surface","grade":2}'::jsonb, true, 130, 1),
  ('hf_pet_quilt', '누비 동무 이불', 'furniture', 2, '별채 가구 · 동무 가구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_quilt","cat":"동무 가구","top":0,"kind":"floor","grade":2,"pet":"bed"}'::jsonb, true, 220, 1),
  ('hf_frame_large', '큰 그림 액자', 'furniture', 2, '별채 가구 · 액자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"hk":"frame_large","wh":30,"ww":2.25,"cat":"액자","kind":"wall","wall":"deco","grade":2,"frame":"L"}'::jsonb, true, 230, 1),
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

insert into public.world_pet_species(pet_id, pet_name, grade, kind, likes, how, sort, egg)
select x.pet_id, x.pet_name, x.grade, x.kind, x.likes, x.how, x.sort, x.egg
  from (values
    ('baby_crab', '아기 게', 1, 'shell', 'treat_fish', '안전지대 상점의 바구니', 59, false),
    ('pill_bug', '아기 공벌레', 2, 'shell', 'treat_herb', '탐색 중 「얼룩무늬 알」', 60, true),
    ('empty_helm', '빈 투구 정령', 3, 'shell', 'treat_rice', '탐색 중 「빛나는 알」', 61, true),
    ('poison_mushroom', '꼬마 독버섯', 1, 'venom', 'treat_herb', '안전지대 상점의 바구니', 62, false),
    ('baby_croc', '새끼 악어', 2, 'venom', 'treat_meat', '탐색 중 「얼룩무늬 알」', 63, true),
    ('baby_scorpion', '아기 전갈', 3, 'venom', 'treat_meat', '탐색 중 「빛나는 알」', 64, true),
    ('dragonfly', '잠자리', 1, 'swarm', 'treat_honey', '안전지대 상점의 바구니', 65, false),
    ('mantis', '꼬마 사마귀', 2, 'swarm', 'treat_meat', '탐색 중 「얼룩무늬 알」', 66, true),
    ('ladybug', '무당벌레', 1, 'swarm', 'treat_honey', '안전지대 상점의 바구니', 67, false),
    ('little_dokkaebi', '꼬마 도깨비', 2, 'mirror', 'treat_rice', '탐색 중 「얼룩무늬 알」', 68, true),
    ('mask_spirit', '꼬마 탈 정령', 3, 'mirror', 'treat_rice', '탐색 중 「빛나는 알」', 69, true),
    ('ox_calf', '새끼 황소', 1, 'breaker', 'treat_herb', '안전지대 상점의 바구니', 70, false),
    ('cracked_jar', '금 간 장독 정령', 1, 'breaker', 'treat_rice', '안전지대 상점의 바구니', 71, false),
    ('thunder_cloud', '꼬마 벼락구름', 2, 'breaker', 'treat_honey', '탐색 중 「얼룩무늬 알」', 72, true),
    ('egg_ghost', '아기 달걀귀신', 2, 'ghost', 'treat_rice', '탐색 중 「얼룩무늬 알」', 73, true),
    ('lantern_spirit', '등롱 혼령', 3, 'ghost', 'treat_rice', '탐색 중 「빛나는 알」', 74, true),
    ('roe_fawn', '아기 노루', 2, 'wood', 'treat_herb', '탐색 중 「얼룩무늬 알」', 75, true),
    ('spotted_seal', '아기 점박이물범', 2, 'water', 'treat_fish', '탐색 중 「얼룩무늬 알」', 76, true),
    ('baby_elephant', '아기 코끼리', 2, 'giant', 'treat_herb', '탐색 중 「얼룩무늬 알」', 77, true),
    ('baby_whale', '아기 고래', 3, 'giant', 'treat_fish', '탐색 중 「빛나는 알」', 78, true)
  ) as x(pet_id, pet_name, grade, kind, likes, how, sort, egg)
on conflict (pet_id) do update set pet_name = excluded.pet_name, grade = excluded.grade, kind = excluded.kind, likes = excluded.likes, how = excluded.how, sort = excluded.sort, egg = excluded.egg;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
values
  ('pt_baby_crab', '아기 게 바구니', 'pet', 1, '등딱지가 손바닥만 한 갯벌의 아기 게입니다. 집게발 두 개를 번쩍 들고 옆으로만 걸어가, 앞으로 오라고 부르면 늘 비스듬히 다가옵니다. 놀라면 집게를 딱딱 부딪쳐 제법 사나운 척을 합니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"baby_crab"}'::jsonb, true, 300, 1),
  ('pt_poison_mushroom', '꼬마 독버섯 바구니', 'pet', 1, '보랏빛 갓에 흰 점이 박힌, 먹으면 큰일 나는 버섯에 깃든 정령입니다. 저도 그걸 알아서 누가 다가오면 갓을 흔들며 먹지 말라고 손사래를 칩니다. 비 온 다음 날이면 키가 한 뼘쯤 자라 있습니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"poison_mushroom"}'::jsonb, true, 300, 1),
  ('pt_dragonfly', '잠자리 바구니', 'pet', 1, '가을 들판을 맴도는 빨간 고추잠자리입니다. 손가락을 세우고 가만히 있으면 슬그머니 내려앉아 커다란 눈으로 이리저리 살핍니다. 빙글빙글 원을 그리면 따라 돌다가 어지러운지 금세 날아가 버립니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"dragonfly"}'::jsonb, true, 300, 1),
  ('pt_ladybug', '무당벌레 바구니', 'pet', 1, '빨간 등에 까만 점이 일곱 개 박힌 벌레입니다. 손가락 끝까지 기어 올라가서야 날개를 펴고 날아오릅니다. 점을 세어 주면 좋아하는지 잠깐 멈춰 섭니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"ladybug"}'::jsonb, true, 300, 1),
  ('pt_ox_calf', '새끼 황소 바구니', 'pet', 1, '뿔이 이제 막 돋기 시작한 누런 송아지입니다. 머리를 앞으로 숙이고 무엇이든 들이받아 보는 게 요즘 제일 재미있는 일입니다. 쓰다듬어 주면 꼬리를 휙휙 내젓고 음매 하고 길게 웁니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"ox_calf"}'::jsonb, true, 300, 1),
  ('pt_cracked_jar', '금 간 장독 정령 바구니', 'pet', 1, '장독대 맨 끝자리를 지키던 오래된 장독에 깃든 정령입니다. 몸에 금이 갔어도 깨지지 않고 버티는 것이 자랑이라, 누가 두드려 보면 일부러 더 크게 둥 하고 울립니다. 뚜껑과 독 사이 틈으로 두 눈이 반짝 빛나며 바깥을 내다봅니다. 쓰면 꼬마 동무가 됩니다.', false, '{}'::jsonb, 1, '{"pet":"cracked_jar"}'::jsonb, true, 300, 1)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, x.item_id, 300, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join (values ('pt_baby_crab'), ('pt_poison_mushroom'), ('pt_dragonfly'), ('pt_ladybug'), ('pt_ox_calf'), ('pt_cracked_jar')) as x(item_id)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;

update public.world_pet_species set kind = x.kind from (values ('neun_puppy', 'ghost'), ('little_jangseung', 'wood'), ('little_raccoon', 'mirror'), ('baby_girin', 'giant')) as x(pet_id, kind) where world_pet_species.pet_id = x.pet_id;

do $g$
declare r record;
begin
  for r in select distinct w.owner_id, w.source from public.world_housing_rewards w
            where w.source in ('title:wed_vow', 'gw_first', 'raid_final') and exists (select 1 from public.world_housing h where h.owner_id = w.owner_id) loop
    perform public.world_housing_grant_once(r.owner_id, r.source, '새로 생긴 보상 가구');
  end loop;
end $g$;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
values
  ('hf_pet_birdhouse', '새집 횃대', 'furniture', 2, '별채 가구 · 동무 가구. 비금 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_birdhouse","cat":"동무 가구","top":1.44,"kind":"floor","grade":2,"pet":"perch","pet_kind":"bird"}'::jsonb, true, 150, 1),
  ('hf_pet_tidepool', '조약돌 물웅덩이', 'furniture', 1, '별채 가구 · 동무 가구. 갑각 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_tidepool","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"bowl","pet_kind":"shell"}'::jsonb, true, 75, 1),
  ('hf_pet_spirit_lamp', '혼불 초롱', 'furniture', 2, '별채 가구 · 동무 가구. 영귀 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_spirit_lamp","cat":"동무 가구","top":0,"kind":"floor","grade":2,"pet":"toy","pet_kind":"ghost"}'::jsonb, true, 160, 1),
  ('hf_pet_mossbed', '이끼 바위 잠자리', 'furniture', 1, '별채 가구 · 동무 가구. 독충 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_mossbed","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"bed","pet_kind":"venom"}'::jsonb, true, 70, 1),
  ('hf_pet_stump', '그루터기', 'furniture', 1, '별채 가구 · 동무 가구. 목령 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_stump","cat":"동무 가구","top":0.5,"kind":"floor","grade":1,"pet":"perch","pet_kind":"wood"}'::jsonb, true, 70, 1),
  ('hf_pet_basket_cave', '대바구니 굴', 'furniture', 2, '별채 가구 · 동무 가구. 은형 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_basket_cave","cat":"동무 가구","top":0,"kind":"floor","grade":2,"pet":"bed","pet_kind":"shadow"}'::jsonb, true, 180, 1),
  ('hf_pet_lotus_basin', '연꽃 수반', 'furniture', 2, '별채 가구 · 동무 가구. 수귀 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_lotus_basin","cat":"동무 가구","top":0,"kind":"floor","grade":2,"pet":"bowl","pet_kind":"water"}'::jsonb, true, 150, 1),
  ('hf_pet_honeycomb', '벌집 놀이판', 'furniture', 1, '별채 가구 · 동무 가구. 군충 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_honeycomb","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"toy","pet_kind":"swarm"}'::jsonb, true, 65, 1),
  ('hf_pet_talisman_cushion', '부적 방석', 'furniture', 1, '별채 가구 · 동무 가구. 금주 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_talisman_cushion","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"bed","pet_kind":"ward"}'::jsonb, true, 90, 1),
  ('hf_pet_mirror_ball', '거울 구슬', 'furniture', 2, '별채 가구 · 동무 가구. 경요 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_mirror_ball","cat":"동무 가구","top":0,"kind":"floor","grade":2,"pet":"toy","pet_kind":"mirror"}'::jsonb, true, 185, 1),
  ('hf_pet_log_scratch', '통나무 긁개', 'furniture', 1, '별채 가구 · 동무 가구. 파봉 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_log_scratch","cat":"동무 가구","top":0,"kind":"floor","grade":1,"pet":"toy","pet_kind":"breaker"}'::jsonb, true, 75, 1),
  ('hf_pet_cloud_cushion', '구름 방석', 'furniture', 3, '별채 가구 · 동무 가구. 천상 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_cloud_cushion","cat":"동무 가구","top":0,"kind":"floor","grade":3,"pet":"bed","pet_kind":"sky"}'::jsonb, true, 540, 1),
  ('hf_pet_stone_seat', '너럭바위', 'furniture', 2, '별채 가구 · 동무 가구. 거괴 갈래 동무가 특히 좋아해 자주 찾아갑니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d":1,"w":1,"hk":"pet_stone_seat","cat":"동무 가구","top":0.44,"kind":"floor","grade":2,"pet":"perch","pet_kind":"giant"}'::jsonb, true, 140, 1)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, description, minimum_level, recipe_difficulty, quality_bonus, required_skill_rank, craft_field)
values
  ('r_hf_pet_birdhouse', '새집 횃대 만들기', 'hf_pet_birdhouse', 1, '{"lumber":2,"seal_paper":1,"resin":1}'::jsonb, '별채에 놓을 새집 횃대을(를) 만든다.', 8, 2, 0, 1, 'carpentry'),
  ('r_hf_pet_tidepool', '조약돌 물웅덩이 만들기', 'hf_pet_tidepool', 1, '{"ore":2,"river_reed":1}'::jsonb, '별채에 놓을 조약돌 물웅덩이을(를) 만든다.', 1, 1, 0, 1, 'artifice'),
  ('r_hf_pet_spirit_lamp', '혼불 초롱 만들기', 'hf_pet_spirit_lamp', 1, '{"fine_paper":1,"lumber":1,"charcoal":1}'::jsonb, '별채에 놓을 혼불 초롱을(를) 만든다.', 8, 2, 0, 1, 'artifice'),
  ('r_hf_pet_mossbed', '이끼 바위 잠자리 만들기', 'hf_pet_mossbed', 1, '{"ore":1,"herb":3}'::jsonb, '별채에 놓을 이끼 바위 잠자리을(를) 만든다.', 1, 1, 0, 1, 'weaving'),
  ('r_hf_pet_stump', '그루터기 만들기', 'hf_pet_stump', 1, '{"wood":4}'::jsonb, '별채에 놓을 그루터기을(를) 만든다.', 1, 1, 0, 1, 'carpentry'),
  ('r_hf_pet_basket_cave', '대바구니 굴 만들기', 'hf_pet_basket_cave', 1, '{"river_reed":4,"lumber":1,"lacquer":1}'::jsonb, '별채에 놓을 대바구니 굴을(를) 만든다.', 8, 2, 0, 1, 'weaving'),
  ('r_hf_pet_lotus_basin', '연꽃 수반 만들기', 'hf_pet_lotus_basin', 1, '{"ore":3,"lacquer":1,"herb":2}'::jsonb, '별채에 놓을 연꽃 수반을(를) 만든다.', 8, 2, 0, 1, 'artifice'),
  ('r_hf_pet_honeycomb', '벌집 놀이판 만들기', 'hf_pet_honeycomb', 1, '{"wood":2,"resin":1}'::jsonb, '별채에 놓을 벌집 놀이판을(를) 만든다.', 1, 1, 0, 1, 'carpentry'),
  ('r_hf_pet_talisman_cushion', '부적 방석 만들기', 'hf_pet_talisman_cushion', 1, '{"seal_paper":2,"river_reed":2}'::jsonb, '별채에 놓을 부적 방석을(를) 만든다.', 1, 1, 0, 1, 'weaving'),
  ('r_hf_pet_mirror_ball', '거울 구슬 만들기', 'hf_pet_mirror_ball', 1, '{"ore":2,"lacquer":1,"fine_paper":1}'::jsonb, '별채에 놓을 거울 구슬을(를) 만든다.', 8, 2, 0, 1, 'artifice'),
  ('r_hf_pet_log_scratch', '통나무 긁개 만들기', 'hf_pet_log_scratch', 1, '{"wood":3,"river_reed":1}'::jsonb, '별채에 놓을 통나무 긁개을(를) 만든다.', 1, 1, 0, 1, 'carpentry'),
  ('r_hf_pet_cloud_cushion', '구름 방석 만들기', 'hf_pet_cloud_cushion', 1, '{"cloud_cotton":3,"silk":2,"spirit_thread":1}'::jsonb, '별채에 놓을 구름 방석을(를) 만든다.', 15, 3, 0, 1, 'weaving'),
  ('r_hf_pet_stone_seat', '너럭바위 만들기', 'hf_pet_stone_seat', 1, '{"ore":5,"herb":1}'::jsonb, '별채에 놓을 너럭바위을(를) 만든다.', 8, 2, 0, 1, 'artifice')
on conflict (recipe_id) do update set recipe_name = excluded.recipe_name, output_item = excluded.output_item, ingredients = excluded.ingredients, description = excluded.description,
  minimum_level = excluded.minimum_level, recipe_difficulty = excluded.recipe_difficulty, craft_field = excluded.craft_field;

insert into public.world_furniture_sources(source, item_id, chance)
values
  ('drop_normal', 'hf_pet_birdhouse', 1),
  ('drop_normal', 'hf_pet_spirit_lamp', 1),
  ('drop_normal', 'hf_pet_basket_cave', 1),
  ('drop_normal', 'hf_pet_lotus_basin', 1),
  ('drop_normal', 'hf_pet_mirror_ball', 1),
  ('drop_guardian', 'hf_pet_cloud_cushion', 1),
  ('expedition', 'hf_pet_cloud_cushion', 1),
  ('drop_normal', 'hf_pet_stone_seat', 1)
on conflict do nothing;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
values
  ('capital_market', 'hf_pet_tidepool', 75, 0, 10, null),
  ('river_market', 'hf_pet_tidepool', 75, 0, 10, null),
  ('south_market', 'hf_pet_mossbed', 70, 0, 10, null),
  ('astral_market', 'hf_pet_mossbed', 70, 0, 10, null),
  ('night_office_store', 'hf_pet_stump', 70, 0, 10, null),
  ('north_market', 'hf_pet_stump', 70, 0, 10, null),
  ('frontier_market', 'hf_pet_honeycomb', 65, 0, 10, null),
  ('underworld_market', 'hf_pet_honeycomb', 65, 0, 10, null),
  ('capital_market', 'hf_pet_talisman_cushion', 90, 0, 10, null),
  ('river_market', 'hf_pet_talisman_cushion', 90, 0, 10, null),
  ('south_market', 'hf_pet_log_scratch', 75, 0, 10, null),
  ('astral_market', 'hf_pet_log_scratch', 75, 0, 10, null)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;

insert into public.world_patch_notes(note_id, title, body) values ('1.1.0', '1.1.0 · 별채의 새 식구', $n$이번 주말, 별채와 꼬마 동무에 새 식구가 찾아옵니다.

## 꼬마 동무
- 새 동무가 많이 늘었습니다. 바닷가 아기 게와 아기 고래, 장독대를 지키던 장독 정령, 밤길을 밝히던 등롱 혼령, 굿판의 탈 정령까지 동물이 아닌 친구들도 함께 왔습니다.
- 모든 갈래의 동무 수를 똑같이 맞췄습니다. 성격이 더 어울리는 갈래로 옮긴 동무도 몇 있습니다. 친밀도와 칭호는 그대로입니다.
- 새 동무는 상점 바구니, 「얼룩무늬 알」, 「빛나는 알」에서 만날 수 있습니다.
- 동무 도감에 갈래 표시가 붙고, 그림이나 이름을 누르면 소개 글을 볼 수 있습니다.
- 쓰다듬고 놀아 주고 먹일 때 동무가 하는 말이 갈래와 친밀도에 따라 훨씬 다양해집니다.

## 별채 가구
- 새 가구가 들어옵니다. 깔개, 상 위에 올리는 작은 소품, 동무가 쓰는 둥지·물그릇·놀이 층대, 그림 액자, 원앙금침과 귀한 벽지·바닥재가 있습니다.
- 흔한 가구는 상점과 제작으로, 귀한 가구는 토벌·원정·칭호 같은 큰 일을 해냈을 때 얻습니다.
- 이미 그 조건을 채운 조사원에게는 새로 생긴 보상 가구를 곳간으로 보내 드립니다.
- 동무 가구가 갈래마다 하나씩 더 생겼습니다(새집 횃대·조약돌 물웅덩이·혼불 초롱·구름 방석 등 열세 가지). 갈래가 맞는 동무는 그 가구를 자주 찾아가고, 횃대나 그루터기 같은 곳에는 올라앉습니다.

## 도트 그림 액자
- 별채 › 그림첩에서 작은 그림(16×16)과 큰 그림(32×24)을 직접 그릴 수 있습니다. 붓·채우기·지우개와 열여섯 가지 색을 씁니다.
- 꾸미기에서 그림 액자를 고른 뒤 「그림 걸기」로 그림첩의 그림을 겁니다. 작은 그림은 작은 액자, 큰 그림은 큰 액자에 걸립니다.
- 새 그림은 하루 다섯 장까지 그리고, 그림첩에는 마흔 장까지 담습니다. 그린 그림은 언제든 고칠 수 있습니다.
- 친구에게 그림을 보낼 수 있습니다(하루 열 장). 받은 그림은 고칠 수 없지만 걸 수 있습니다.
- 남의 별채에서 그림을 누르면 크게 볼 수 있고, 보기 싫은 그림은 내 화면에서 숨기거나 운영진에게 제보할 수 있습니다. 운영진이 내린 그림은 모든 사본이 함께 내려갑니다.

## 그 밖에
- 원정을 끝까지 다녀왔을 때 받는 경험치를 크게 올렸습니다. 30분~2시간 원정은 그 시간 동안 탐색했을 때와 비슷한 만큼, 4시간·8시간은 그보다 조금 덜 받습니다(2시간 이상은 끝까지 다녀온 덤까지 합쳐서).
- 귀허의 주인 앞에 설 때, 함께하는 인원에 맞는 안내를 한 번 보여 드립니다.
- 대세력에 들 수 있게 되면 캐릭터 › 세력에 빨간 점이 켜집니다.
- 파티 채팅에도 요괴화 표시가 보입니다.
$n$)
on conflict (note_id) do update set title = excluded.title, body = excluded.body;

update public.world_app_meta set value = '20261108000000' where key = 'db_version';
