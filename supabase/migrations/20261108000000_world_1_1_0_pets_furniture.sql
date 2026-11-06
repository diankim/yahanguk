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
