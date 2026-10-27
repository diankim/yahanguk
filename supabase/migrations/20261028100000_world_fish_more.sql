-- 낚시 확장: 어종 20 → 37종, 낚시터 7 → 11곳(수로·심연 물가 추가), 모든 어종을 제작법에 잇는다.
-- 그리고 제작으로 오르는 기술 계열을 제작 분야에 맞춘다(봉인 공예 → 결계 각인, 연금 → 연금, 요리 → 오르지 않음(요리 숙련이 따로 있음), 그 밖 → 단조).

/* ── 서식지: 수로(canal)·심연(abyss) ───────────────────── */
alter table public.world_fish_grounds drop constraint if exists world_fish_grounds_habitat_check;
alter table public.world_fish_grounds add constraint world_fish_grounds_habitat_check check (habitat = any (array['river', 'marsh', 'sea', 'lake', 'deep', 'canal', 'abyss']));
alter table public.world_fish_species drop constraint if exists world_fish_species_habitat_check;
alter table public.world_fish_species add constraint world_fish_species_habitat_check check (habitat = any (array['river', 'marsh', 'sea', 'lake', 'deep', 'canal', 'abyss']));

insert into public.world_fish_grounds(region_id, habitat, ground_name, description) values
  ('old_canal', 'canal', '구룡 폐수로 물길', '버려진 수로에 검은 물이 고여 흐릅니다. 도성에서 흘러든 것들이 바닥에 쌓였습니다.'),
  ('sunken_district', 'canal', '침수 골목 웅덩이', '물에 잠긴 골목 사이로 물고기 그림자가 지나갑니다.'),
  ('black_tide_rift', 'abyss', '흑조 균열 물가', '갈라진 땅 밑에서 검은 조수가 차오릅니다. 빛을 모르는 것들이 삽니다.'),
  ('sealed_abyss', 'abyss', '봉연 가장자리', '아홉 겹 봉인 아래 고인 물. 낚싯줄이 끝없이 내려갑니다.')
on conflict (region_id) do nothing;

/* ── 새 물품: 어종 17종 ─────────────────────────────────── */
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, rarity,
  acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size) values
  ('dace', '피라미', 'material', 1, '여울에서 반짝이는 작은 물고기.', true, '{}', 1, 'common', 1, 1, '{}', 'cooking', true, 6, 20),
  ('bullhead', '동자개', 'material', 2, '해 질 녘 바닥에서 "빠가빠가" 소리를 냅니다.', true, '{}', 4, 'uncommon', 2, 0.72, '{}', 'cooking', true, 18, 20),
  ('swamp_eel', '드렁허리', 'material', 2, '늪 진흙 속을 파고드는 뱀 같은 물고기.', true, '{}', 7, 'uncommon', 2, 0.72, '{}', 'cooking', true, 24, 20),
  ('mackerel', '고등어', 'material', 1, '떼 지어 다니는 등 푸른 바닷고기.', true, '{}', 10, 'common', 1, 1, '{}', 'cooking', true, 8, 20),
  ('yellow_croaker', '조기', 'material', 2, '새벽 바다에서 울음소리를 내며 몰려옵니다.', true, '{}', 11, 'uncommon', 2, 0.72, '{}', 'cooking', true, 26, 20),
  ('croaker', '민어', 'material', 3, '흐린 날 깊은 물에서 올라오는 큰 물고기. 부레로 아교를 쑵니다.', true, '{}', 13, 'rare', 3, 0.42, '{}', 'cooking', true, 75, 10),
  ('lenok', '열목어', 'material', 2, '눈이 붉은 찬물 물고기.', true, '{}', 13, 'uncommon', 2, 0.72, '{}', 'cooking', true, 26, 20),
  ('ice_char', '얼음 곤들매기', 'material', 3, '눈 내리는 날 얼음 밑에서 문다는 물고기.', true, '{}', 15, 'rare', 3, 0.42, '{}', 'cooking', true, 80, 10),
  ('palace_puffer', '수궁 복어', 'material', 2, '건드리면 부풀어 오릅니다. 독을 품고 있습니다.', true, '{}', 14, 'uncommon', 2, 0.72, '{}', 'cooking', true, 30, 20),
  ('silver_scale', '용궁 은린어', 'material', 4, '깊은 밤 수궁 회랑을 은빛으로 가르는 물고기. 비늘이 단단합니다.', true, '{}', 16, 'epic', 4, 0.22, '{}', 'cooking', true, 200, 5),
  ('canal_carp', '흑잉어', 'material', 1, '검은 수로 물에서 자란 잉어.', true, '{}', 3, 'common', 1, 1, '{}', 'cooking', true, 8, 20),
  ('canal_eel', '수로 뱀장어', 'material', 2, '밤이면 수로 벽을 타고 기어오릅니다.', true, '{}', 5, 'uncommon', 2, 0.72, '{}', 'cooking', true, 18, 20),
  ('ghost_goby', '원귀 망둥어', 'material', 3, '안개 낀 날 물 위로 뛰어오릅니다. 원한 서린 기운이 배어 있습니다.', true, '{}', 6, 'rare', 3, 0.42, '{}', 'cooking', true, 55, 10),
  ('void_hagfish', '흑조 먹장어', 'material', 2, '검은 조수에서 사는 눈 없는 장어. 기름이 많습니다.', true, '{}', 20, 'uncommon', 2, 0.72, '{}', 'cooking', true, 40, 20),
  ('abyss_angler', '심연 초롱아귀', 'material', 3, '깊은 밤 머리 위 초롱으로 먹이를 꾑니다.', true, '{}', 22, 'rare', 3, 0.42, '{}', 'cooking', true, 110, 10),
  ('starless_ray', '무광 가오리', 'material', 4, '안개 낀 날 빛 없는 물에서 날개를 폅니다.', true, '{}', 24, 'epic', 4, 0.22, '{}', 'cooking', true, 240, 5),
  ('abyss_dragonfish', '봉연 흑룡어', 'material', 5, '아홉 겹 봉인 아래에서 피안개 짙은 날 단 한 번 몸을 드러냅니다.', true, '{}', 28, 'legendary', 5, 0.1, '{}', 'cooking', true, 800, 5)
on conflict (item_id) do nothing;

insert into public.world_fish_species(fish_id, fish_name, habitat, rarity, min_level, phase, weather, size_min, size_max, description, sort, active) values
  ('dace', '피라미', 'river', 'common', 1, null, null, 6, 14, '여울에서 반짝이는 작은 물고기.', 21, true),
  ('bullhead', '동자개', 'river', 'uncommon', 4, 'dusk', null, 15, 30, '해 질 녘 바닥에서 소리를 냅니다.', 22, true),
  ('swamp_eel', '드렁허리', 'marsh', 'uncommon', 7, 'night', null, 30, 70, '밤이면 진흙 밖으로 나옵니다.', 23, true),
  ('mackerel', '고등어', 'sea', 'common', 10, null, null, 20, 40, '떼 지어 다니는 등 푸른 물고기.', 24, true),
  ('yellow_croaker', '조기', 'sea', 'uncommon', 11, 'dawn', null, 18, 40, '새벽 바다에서 몰려옵니다.', 25, true),
  ('croaker', '민어', 'sea', 'rare', 13, null, 'cloudy', 40, 100, '흐린 날 깊은 물에서 올라옵니다.', 26, true),
  ('lenok', '열목어', 'lake', 'uncommon', 13, null, null, 30, 70, '눈이 붉은 찬물 물고기.', 27, true),
  ('ice_char', '얼음 곤들매기', 'lake', 'rare', 15, null, 'snow', 25, 60, '눈 내리는 날 얼음 밑에서 뭅니다.', 28, true),
  ('palace_puffer', '수궁 복어', 'deep', 'uncommon', 14, null, null, 15, 35, '건드리면 부풀어 오릅니다.', 29, true),
  ('silver_scale', '용궁 은린어', 'deep', 'epic', 16, 'night', null, 50, 120, '깊은 밤 은빛으로 회랑을 가릅니다.', 30, true),
  ('canal_carp', '흑잉어', 'canal', 'common', 3, null, null, 20, 50, '검은 수로 물에서 자란 잉어.', 31, true),
  ('canal_eel', '수로 뱀장어', 'canal', 'uncommon', 5, 'night', null, 40, 90, '밤이면 수로 벽을 타고 오릅니다.', 32, true),
  ('ghost_goby', '원귀 망둥어', 'canal', 'rare', 6, null, 'fog', 8, 20, '안개 낀 날 물 위로 뛰어오릅니다.', 33, true),
  ('void_hagfish', '흑조 먹장어', 'abyss', 'uncommon', 20, null, null, 40, 100, '검은 조수에 사는 눈 없는 장어.', 34, true),
  ('abyss_angler', '심연 초롱아귀', 'abyss', 'rare', 22, 'night', null, 30, 80, '깊은 밤 초롱으로 먹이를 꾑니다.', 35, true),
  ('starless_ray', '무광 가오리', 'abyss', 'epic', 24, null, 'fog', 60, 160, '안개 낀 날 날개를 폅니다.', 36, true),
  ('abyss_dragonfish', '봉연 흑룡어', 'abyss', 'legendary', 28, null, 'bloodmist', 100, 220, '피안개 짙은 날 단 한 번 몸을 드러냅니다.', 37, true)
on conflict (fish_id) do nothing;

/* ── 새 물품: 요리·약·재료·등잔 ─────────────────────────── */
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, rarity,
  acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size) values
  ('sweetfish_grill', '은어 소금구이', 'consumable', 2, '숯불에 소금을 쳐 구운 은어. 수박 향이 납니다. 체력 +30·정신 +5, 든든함.', true, '{}', 3, 'uncommon', 2, 0.72, '{}', 'cooking', true, 60, 10),
  ('catfish_braise', '메기찜', 'consumable', 3, '먹물 메기를 약초와 쪄 낸 찜. 체력 +45, 중독 해소, 속이 따뜻함.', true, '{}', 4, 'rare', 3, 0.42, '{}', 'cooking', true, 110, 5),
  ('snakehead_broth', '가물치 곰국', 'consumable', 3, '가물치를 약제와 오래 곤 국. 체력 +35·정신 +15, 탈진·피로 해소, 기운 충천.', true, '{}', 5, 'rare', 3, 0.42, '{}', 'cooking', true, 150, 5),
  ('goby_soup', '망둥어 맑은국', 'consumable', 3, '원귀 망둥어로 끓인 맑은국. 원한이 풀리듯 마음이 가라앉습니다. 정신 +25·침식 -8, 동요 해소.', true, '{}', 6, 'rare', 3, 0.42, '{}', 'cooking', true, 100, 5),
  ('hairtail_braise', '갈치조림', 'consumable', 3, '백등 갈치를 숯불에 졸인 조림. 체력 +50·정신 +10, 든든함.', true, '{}', 10, 'rare', 3, 0.42, '{}', 'cooking', true, 140, 5),
  ('dried_croaker', '굴비', 'consumable', 2, '조기를 엮어 말린 굴비. 오래 두고 먹는 길 양식입니다. 체력 +15·탐색력 +3, 든든함.', true, '{}', 11, 'uncommon', 2, 0.72, '{}', 'cooking', true, 70, 10),
  ('croaker_soup', '민어탕', 'consumable', 3, '민어를 약제와 끓인 탕. 체력 +60·정신 +15, 속이 따뜻함·기운 충천.', true, '{}', 13, 'rare', 3, 0.42, '{}', 'cooking', true, 220, 5),
  ('char_grill', '곤들매기 구이', 'consumable', 3, '얼음 곤들매기를 숯불에 구웠습니다. 체력 +40·정신 +10, 오한 해소, 든든함.', true, '{}', 15, 'rare', 3, 0.42, '{}', 'cooking', true, 120, 5),
  ('salmon_grill', '산천어 구이', 'consumable', 3, '새벽에 낚은 산천어를 구웠습니다. 체력 +40·정신 +10·영력 +10, 든든함.', true, '{}', 12, 'rare', 3, 0.42, '{}', 'cooking', true, 110, 5),
  ('trout_sashimi', '송어회', 'consumable', 2, '찬 호수의 송어를 저민 회. 체력 +25·정신 +10, 기운 충천.', true, '{}', 10, 'uncommon', 2, 0.72, '{}', 'cooking', true, 70, 10),
  ('mirror_soup', '천경 맑은탕', 'consumable', 4, '천경 백어와 영초 차로 끓인 맑은탕. 정신 +35·영력 +30·침식 -10, 속이 따뜻함.', true, '{}', 13, 'epic', 4, 0.22, '{}', 'cooking', true, 360, 3),
  ('hagfish_grill', '먹장어 구이', 'consumable', 3, '기름진 흑조 먹장어를 구웠습니다. 체력 +55·정신 +10, 기운 충천.', true, '{}', 20, 'rare', 3, 0.42, '{}', 'cooking', true, 90, 5),
  ('ray_steam', '무광 가오리찜', 'consumable', 4, '무광 가오리를 약제와 쪘습니다. 체력 +70·정신 +30·침식 -15, 속이 따뜻함·기운 충천.', true, '{}', 24, 'epic', 4, 0.22, '{}', 'cooking', true, 420, 3),
  ('koi_broth', '용린 잉어 고음', 'consumable', 5, '용잠 비늘잉어를 영초 차와 약제로 고았습니다. 체력 +100·정신 +40·영력 +40, 기운 충천·바다의 복·속이 따뜻함.', true, '{}', 14, 'legendary', 5, 0.1, '{}', 'cooking', true, 800, 3),
  ('dragon_feast', '흑룡 어보탕', 'consumable', 5, '봉연 흑룡어를 응축 영핵과 고아 낸 탕. 체력 +100·정신 +50·영력 +50·침식 -25, 이로운 상태 넷.', true, '{}', 28, 'legendary', 5, 0.1, '{}', 'cooking', true, 1300, 3),
  ('wraith_soul_pill', '귀어 환혼단', 'consumable', 4, '늪 귀어의 정기를 약제에 개어 빚은 환. 정신 +40·침식 -15, 동요·속삭임 해소.', true, '{}', 8, 'epic', 4, 0.22, '{}', null, true, 300, 3),
  ('lantern_oil', '등롱 어유', 'material', 3, '빛을 내는 물고기에서 짜낸 기름. 꺼지지 않는 등잔을 만듭니다.', true, '{}', 5, 'rare', 3, 0.42, '{}', null, true, 140, 10),
  ('fish_oil_lamp', '어유 등잔', 'consumable', 3, '등롱 어유로 밝힌 작은 등잔. 켜 두면 요괴가 덜 꼬이고 마음이 덜 흔들립니다(등잔빛 40분).', true, '{}', 5, 'rare', 3, 0.42, '{}', null, true, 90, 5)
on conflict (item_id) do nothing;

-- 새 이로운 상태: 등잔빛
insert into public.world_status_catalog(status_key, status_name, description, icon, polarity, effects, duration_minutes, max_stacks, triggers, cure_items, cure, active)
values ('lamp_glow', '등잔빛', '어유 등잔이 주위를 밝혀 요괴가 덜 꼬이고 마음이 덜 흔들립니다.', 'flame', 'positive',
  '{"encounter_pct": -15, "erosion_pct": -5, "mental_loss_pct": -10}', 40, 1, '{}', '{}', '시간이 지나면 사라집니다.', true)
on conflict (status_key) do nothing;

/* ── 제작법 28개: 모든 어종이 쓰이게 ────────────────────── */
insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location,
  description, minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field) values
  -- 손질(생선살)
  ('fillet_dace', '피라미 손질', 'fish_fillet', 1, '{"dace": 2}', 'field_knife', 1, '구름나루', '작은 물고기 둘을 손질해 생선살 하나를 얻습니다.', 1, null, 1, 0, null, 1, 'cooking'),
  ('fillet_bullhead', '동자개 손질', 'fish_fillet', 2, '{"bullhead": 1}', 'field_knife', 1, '구름나루', '가시를 조심해 살을 발라냅니다.', 1, null, 1, 0, null, 1, 'cooking'),
  ('fillet_mackerel', '고등어 손질', 'fish_fillet', 1, '{"mackerel": 1}', 'field_knife', 1, '잔불촌', '등 푸른 살을 발라냅니다.', 1, null, 1, 0, null, 1, 'cooking'),
  ('fillet_canal_carp', '흑잉어 손질', 'fish_fillet', 1, '{"canal_carp": 1}', 'field_knife', 1, '구름나루', '흙내를 빼고 살을 발라냅니다.', 1, null, 1, 0, null, 1, 'cooking'),
  ('fillet_canal_eel', '수로 뱀장어 손질', 'fish_fillet', 2, '{"canal_eel": 1}', 'field_knife', 1, '구름나루', '긴 몸을 갈라 살을 발라냅니다.', 1, null, 1, 0, null, 1, 'cooking'),
  -- 요리
  ('cook_sweetfish', '은어 소금구이', 'sweetfish_grill', 1, '{"sweetfish": 1, "charcoal": 1}', 'field_knife', 1, '구름나루', '은어에 소금을 쳐 숯불에 굽습니다.', 3, null, 1, 0, null, 1, 'cooking'),
  ('cook_catfish', '메기찜', 'catfish_braise', 1, '{"ink_catfish": 1, "herb": 2}', 'field_knife', 1, '백등 야시장', '먹물 메기를 약초와 함께 찝니다.', 4, null, 2, 0, null, 1, 'cooking'),
  ('cook_snakehead', '가물치 곰국', 'snakehead_broth', 1, '{"snakehead": 1, "medicine_base": 1}', 'field_knife', 1, '백등 야시장', '가물치를 약제와 오래 곱니다.', 5, null, 2, 0, null, 1, 'cooking'),
  ('cook_goby', '망둥어 맑은국', 'goby_soup', 1, '{"ghost_goby": 1, "herb": 1}', 'field_knife', 1, '백등 야시장', '원귀 망둥어로 맑은국을 끓입니다.', 6, null, 2, 0, null, 1, 'cooking'),
  ('cook_hairtail', '갈치조림', 'hairtail_braise', 1, '{"lamp_hairtail": 1, "herb": 1, "charcoal": 1}', 'field_knife', 1, '잔불촌', '백등 갈치를 졸입니다.', 10, null, 3, 0, null, 1, 'cooking'),
  ('cook_dried_croaker', '굴비 엮기', 'dried_croaker', 1, '{"yellow_croaker": 2}', 'field_knife', 1, '잔불촌', '조기 두 마리를 엮어 말립니다.', 11, null, 2, 0, null, 1, 'cooking'),
  ('cook_croaker_soup', '민어탕', 'croaker_soup', 1, '{"croaker": 1, "medicine_base": 1, "herb": 1}', 'field_knife', 1, '잔불촌', '민어를 약제와 끓입니다.', 13, null, 3, 0, null, 1, 'cooking'),
  ('cook_char', '곤들매기 구이', 'char_grill', 1, '{"ice_char": 1, "charcoal": 1}', 'field_knife', 1, '철벽 고찰', '얼음 곤들매기를 숯불에 굽습니다.', 15, null, 3, 0, null, 1, 'cooking'),
  ('cook_salmon', '산천어 구이', 'salmon_grill', 1, '{"cherry_salmon": 1, "charcoal": 1}', 'field_knife', 1, '철벽 고찰', '새벽에 낚은 산천어를 굽습니다.', 12, null, 3, 0, null, 1, 'cooking'),
  ('cook_trout', '송어회', 'trout_sashimi', 1, '{"lake_trout": 2}', 'field_knife', 1, '철벽 고찰', '찬 호수의 송어를 얇게 저밉니다.', 10, null, 2, 0, null, 1, 'cooking'),
  ('cook_mirror_soup', '천경 맑은탕', 'mirror_soup', 1, '{"mirror_whitefish": 1, "spirit_tea": 1, "medicine_base": 1}', 'field_knife', 1, '철벽 고찰', '천경 백어로 맑은탕을 끓입니다.', 13, null, 4, 0, null, 1, 'cooking'),
  ('stew_lenok', '열목어 매운탕', 'spicy_stew', 1, '{"lenok": 1, "herb": 1}', 'field_knife', 1, '철벽 고찰', '열목어로 얼큰한 탕을 끓입니다.', 13, null, 2, 0, null, 1, 'cooking'),
  ('tonic_swamp_eel', '드렁허리 보양탕', 'eel_tonic', 1, '{"swamp_eel": 1, "herbal_extract": 1}', 'field_knife', 1, '백등 야시장', '드렁허리를 약초액과 끓인 보양탕.', 7, null, 2, 0, null, 1, 'cooking'),
  ('cook_hagfish', '먹장어 구이', 'hagfish_grill', 1, '{"void_hagfish": 1, "charcoal": 1}', 'field_knife', 1, '십삼문 암시장', '기름진 먹장어를 굽습니다.', 20, null, 3, 0, null, 1, 'cooking'),
  ('cook_ray', '무광 가오리찜', 'ray_steam', 1, '{"starless_ray": 1, "medicine_base": 1, "spirit_tea": 1}', 'field_knife', 1, '십삼문 암시장', '무광 가오리를 약제와 찝니다.', 24, null, 4, 0, null, 1, 'cooking'),
  ('cook_koi_broth', '용린 잉어 고음', 'koi_broth', 1, '{"dragon_scale_koi": 1, "spirit_tea": 1, "medicine_base": 1}', 'field_knife', 1, '구름나루', '용잠 비늘잉어를 오래 고아 냅니다.', 14, null, 5, 0, null, 1, 'cooking'),
  ('cook_dragon_feast', '흑룡 어보탕', 'dragon_feast', 1, '{"abyss_dragonfish": 1, "spirit_core": 1, "medicine_base": 1}', 'field_knife', 1, '무극 관성대', '봉연 흑룡어를 응축 영핵과 고아 냅니다.', 28, null, 5, 0, null, 1, 'cooking'),
  -- 연금·법구·가죽
  ('brew_wraith_pill', '귀어 환혼단 빚기', 'wraith_soul_pill', 1, '{"marsh_wraithfish": 1, "medicine_base": 1}', null, 1, '백골 장터', '늪 귀어의 정기를 약제에 개어 환을 빚습니다.', 8, null, 4, 0, null, 1, 'alchemy'),
  ('oil_crucian', '연등 붕어 기름 짜기', 'lantern_oil', 1, '{"lantern_crucian": 2}', null, 1, '백등 야시장', '빛을 내는 붕어에서 기름을 짭니다.', 5, null, 2, 0, null, 1, 'alchemy'),
  ('oil_lanternfish', '등롱어 기름 짜기', 'lantern_oil', 1, '{"palace_lanternfish": 1}', null, 1, '백등 야시장', '수궁 등롱어에서 기름을 짭니다.', 14, null, 2, 0, null, 1, 'alchemy'),
  ('oil_angler', '초롱아귀 기름 짜기', 'lantern_oil', 2, '{"abyss_angler": 1}', null, 1, '십삼문 암시장', '초롱아귀의 초롱에서 기름을 짭니다.', 22, null, 3, 0, null, 1, 'alchemy'),
  ('puffer_venom', '복어 독 빼기', 'venom_gland', 2, '{"palace_puffer": 3}', 'field_knife', 1, '백골 장터', '수궁 복어에서 독낭을 조심스레 떼어 냅니다.', 14, null, 3, 0, null, 1, 'alchemy'),
  ('make_oil_lamp', '어유 등잔 만들기', 'fish_oil_lamp', 2, '{"lantern_oil": 1, "seal_paper": 1}', null, 1, '본부 정청', '등롱 어유를 황지 심지에 먹여 등잔 둘을 만듭니다.', 5, null, 2, 0, null, 1, 'artifice'),
  ('strip_silver_scale', '은린 비늘 벗기기', 'drowned_scale', 4, '{"silver_scale": 1}', 'field_knife', 1, '구름나루', '은린어의 단단한 비늘을 벗겨 갑옷 재료로 씁니다.', 16, null, 3, 0, null, 1, 'leatherwork'),
  ('oil_hagfish', '먹장어 기름 짜기', 'lantern_oil', 1, '{"void_hagfish": 2}', null, 1, '십삼문 암시장', '기름진 먹장어에서 기름을 짭니다.', 20, null, 2, 0, null, 1, 'alchemy')
on conflict (recipe_id) do nothing;

/* ── 먹고 쓰기 ──────────────────────────────────────────── */
do $$
declare d text;
  a text := $q$'herb_fish_steam', 'spirit_gukbap') THEN$q$;
  b text := $q$WHEN 'bream_sashimi' THEN hp := 40; mn := 10; buffs := ARRAY['sea_luck', 'vigor'];$q$;
begin
  d := pg_get_functiondef('public.world_use_item(text)'::regprocedure);
  if position('dragon_feast' in d) > 0 then return; end if;
  if position(a in d) = 0 or position(b in d) = 0 then raise exception '물품 사용 함수에서 고칠 줄을 찾지 못했습니다'; end if;
  d := replace(d, a, $q$'herb_fish_steam', 'spirit_gukbap', 'sweetfish_grill', 'catfish_braise', 'snakehead_broth', 'goby_soup', 'hairtail_braise', 'dried_croaker', 'croaker_soup', 'char_grill', 'salmon_grill', 'trout_sashimi', 'mirror_soup', 'hagfish_grill', 'ray_steam', 'koi_broth', 'dragon_feast', 'wraith_soul_pill', 'fish_oil_lamp') THEN$q$);
  d := replace(d, b, b || $q$
    WHEN 'sweetfish_grill' THEN hp := 30; mn := 5; buffs := ARRAY['well_fed'];
    WHEN 'catfish_braise' THEN hp := 45; cures := ARRAY['poisoned']; buffs := ARRAY['warm_belly'];
    WHEN 'snakehead_broth' THEN hp := 35; mn := 15; cures := ARRAY['exhausted', 'fatigue']; buffs := ARRAY['vigor'];
    WHEN 'goby_soup' THEN mn := 25; er := 8; cures := ARRAY['shaken'];
    WHEN 'hairtail_braise' THEN hp := 50; mn := 10; buffs := ARRAY['well_fed'];
    WHEN 'dried_croaker' THEN hp := 15; stam := 3; buffs := ARRAY['well_fed'];
    WHEN 'croaker_soup' THEN hp := 60; mn := 15; buffs := ARRAY['warm_belly', 'vigor'];
    WHEN 'char_grill' THEN hp := 40; mn := 10; cures := ARRAY['cold']; buffs := ARRAY['well_fed'];
    WHEN 'salmon_grill' THEN hp := 40; mn := 10; spg := 10; buffs := ARRAY['well_fed'];
    WHEN 'trout_sashimi' THEN hp := 25; mn := 10; buffs := ARRAY['vigor'];
    WHEN 'mirror_soup' THEN mn := 35; spg := 30; er := 10; buffs := ARRAY['warm_belly'];
    WHEN 'hagfish_grill' THEN hp := 55; mn := 10; buffs := ARRAY['vigor'];
    WHEN 'ray_steam' THEN hp := 70; mn := 30; er := 15; buffs := ARRAY['warm_belly', 'vigor'];
    WHEN 'koi_broth' THEN hp := 100; mn := 40; spg := 40; buffs := ARRAY['vigor', 'sea_luck', 'warm_belly'];
    WHEN 'dragon_feast' THEN hp := 100; mn := 50; spg := 50; er := 25; buffs := ARRAY['vigor', 'sea_luck', 'warm_belly', 'well_fed'];
    WHEN 'wraith_soul_pill' THEN mn := 40; er := 15; cures := ARRAY['shaken', 'erosion_whisper'];
    WHEN 'fish_oil_lamp' THEN buffs := ARRAY['lamp_glow'];$q$);
  execute d;
end $$;

/* ── 제작으로 오르는 기술 계열을 제작 분야에 맞춘다 ─────────── */
grant fn_owner_18962 to postgres with inherit true;
do $$
declare d text;
  a text := $q$select required_skill into v_recipe_skill from public.world_crafting_recipes where recipe_id=coalesce(new.payload->>'recipe','');$q$;
  b text := $q$v_key:=coalesce(v_recipe_skill,$q$;
begin
  d := pg_get_functiondef('public.world_track_specialized_skill()'::regprocedure);
  if position('craft_field' in d) > 0 then return; end if;
  if position(a in d) = 0 or position(b in d) = 0 then raise exception '기술 경험 함수에서 고칠 줄을 찾지 못했습니다'; end if;
  d := replace(d, a, $q$select coalesce(required_skill, case craft_field when 'sealing' then 'wardcraft' when 'alchemy' then 'alchemy' when 'cooking' then '-' else 'smithing' end) into v_recipe_skill from public.world_crafting_recipes where recipe_id=coalesce(new.payload->>'recipe','');$q$);
  d := replace(d, b, $q$v_key:=nullif(coalesce(v_recipe_skill,$q$);
  d := replace(d, $q$else 'smithing' end);
 end if;$q$, $q$else 'smithing' end), '-');
 end if;$q$);
  if position($q$'smithing' end), '-');$q$ in d) = 0 then raise exception '기술 경험 함수의 끝줄을 찾지 못했습니다'; end if;
  execute d;
end $$;
grant fn_owner_18962 to postgres with inherit false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028100000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
