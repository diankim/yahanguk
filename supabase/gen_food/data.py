ING = [
    ('fd_potato', '감자', 1, 10, '들과 마을 밭둑에서 캐는 감자. 굽든 조리든 배를 든든히 채운다.'),
    ('fd_sweet_potato', '고구마', 1, 12, '볕 좋은 남쪽 땅에서 캐는 고구마. 찌면 달다.'),
    ('fd_greens', '산나물', 1, 10, '숲 가장자리와 고갯길에서 뜯는 산나물.'),
    ('fd_mushroom', '버섯', 1, 15, '그늘진 숲과 땅 밑 습한 곳에서 따는 버섯.'),
    ('fd_rice', '쌀', 1, 12, '나루와 마을에서 구하는 쌀. 밥과 죽의 바탕이다.'),
    ('fd_minari', '미나리', 1, 12, '늪과 물가에서 끊는 미나리. 향이 맑다.'),
    ('fd_garlic', '마늘', 1, 12, '추운 북쪽 땅에서 잘 자라는 마늘. 국물 맛을 잡는다.'),
    ('fd_chestnut', '밤', 2, 18, '숲과 고갯길 밤나무에서 줍는 밤.'),
    ('fd_buckwheat', '메밀', 2, 20, '척박한 고개와 빙곡에서 거두는 메밀.'),
    ('fd_lotus_root', '연근', 2, 22, '연못과 늪 바닥에서 캐는 연근.'),
    ('fd_chili', '고추', 2, 18, '남명 땅의 매운 고추. 한 개면 국 한 솥이 맵다.'),
    ('fd_ginger', '생강', 2, 20, '남쪽 땅과 바닷가에서 캐는 생강. 비린내를 잡는다.'),
    ('fd_jujube', '대추', 2, 20, '적월 사막 가장자리에서 말린 대추.'),
    ('fd_deodeok', '더덕', 2, 25, '높은 고개와 봉우리 바위틈에서 캐는 더덕.'),
    ('fd_spice_seed', '향신 씨앗', 3, 45, '핏빛 모래바다 둘레에서 거두는 향신 씨앗. 고기 누린내를 없앤다.'),
    ('fd_meokbi_fern', '먹비 고사리', 4, 60, '먹비 숲 먹물 비를 맞고 자란 고사리. 데치면 검은 물이 빠진다.'),
    ('fd_white_rice', '흰 밤 찹쌀', 4, 70, '흰 밤이 걷히지 않던 옛 도읍 물가에서 거두는 찹쌀.'),
]

MEAT = [
    ('mt_chicken', '닭고기', 1, 15, '비금 갈래 요괴에게서 얻은 고기. 그대로 요리에 쓴다.'),
    ('mt_beast', '요수 생고기', 1, 15, '거괴·파봉 갈래 요괴에게서 얻은 붉은 고기. 그대로 요리에 쓴다.'),
    ('mt_pheasant', '꿩고기', 2, 30, '하늘을 나는 요괴에게서 얻은 담백한 고기. 그대로 요리에 쓴다.'),
    ('mt_boar', '멧돼지고기', 2, 35, '파봉 갈래 요괴의 질긴 고기. 요기가 배어 있어 숯불에 훈연해야 먹을 수 있다.'),
    ('mt_crab', '독게살', 2, 30, '갑각 갈래 요괴의 게살. 독이 있어 약초액으로 독을 빼야 한다.'),
    ('mt_yofish', '요괴 생선살', 1, 15, '수귀 갈래 요괴의 살. 비린 요기가 있어 소금에 절여야 한다.'),
]

MEAT_DROP = [
    ('mt_chicken', ['bird'], None, 14),
    ('mt_pheasant', ['bird'], 15, None),
    ('mt_pheasant', ['sky'], None, None),
    ('mt_beast', ['giant'], None, None),
    ('mt_beast', ['breaker'], None, 9),
    ('mt_boar', ['breaker'], 10, None),
    ('mt_crab', ['shell'], None, None),
    ('mt_yofish', ['water'], None, None),
]

GATHER = [
    ('fd_potato', ['herbs', 'wood'], {'types': ['wilderness', 'village', 'forest', 'haunted_garden', 'mountain_pass', 'market', 'headquarters', 'safe_zone', 'training']}, 1),
    ('fd_sweet_potato', ['herbs'], {'facs': ['southern_remnant', 'river_alliance'], 'types': ['coast']}, 1),
    ('fd_greens', ['herbs'], {'types': ['forest', 'mountain_pass', 'haunted_garden', 'sealed_shrine', 'ruined_temple', 'wilderness']}, 1),
    ('fd_mushroom', ['wood', 'herbs'], {'types': ['forest', 'underground', 'swamp', 'burial_ground', 'blood_forest', 'archive']}, 1),
    ('fd_rice', ['supplies'], {'types': ['village', 'river_port', 'coast', 'market', 'headquarters', 'safe_zone', 'bridge'], 'facs': ['river_alliance']}, 1),
    ('fd_minari', ['water'], {'types': ['swamp', 'lake', 'river_port', 'village', 'pavilion', 'coast']}, 1),
    ('fd_garlic', ['herbs', 'supplies'], {'facs': ['north_league'], 'types': ['ice_valley']}, 1),
    ('fd_chestnut', ['wood'], {'types': ['forest', 'mountain_pass', 'wilderness', 'mountain_peak']}, 5),
    ('fd_buckwheat', ['supplies'], {'types': ['mountain_pass', 'ice_valley', 'mountain_peak', 'monastery']}, 5),
    ('fd_lotus_root', ['water'], {'types': ['swamp', 'pavilion', 'lake']}, 7),
    ('fd_chili', ['herbs'], {'facs': ['southern_remnant']}, 1),
    ('fd_ginger', ['herbs'], {'facs': ['southern_remnant'], 'types': ['coast', 'islands']}, 5),
    ('fd_jujube', ['wood', 'herbs'], {'facs': ['red_moon_cult'], 'types': ['desert', 'canyon']}, 1),
    ('fd_deodeok', ['herbs'], {'types': ['mountain_pass', 'mountain_peak', 'canyon']}, 8),
    ('fd_spice_seed', ['herbs', 'spirit'], {'regs': ['blood_dunes', 'crimson_altar', 'red_moon_fort']}, 15),
    ('fd_meokbi_fern', ['herbs'], {'regs': ['meokbi_forest', 'blank_field']}, 40),
    ('fd_white_rice', ['water', 'herbs', 'supplies'], {'regs': ['old_ferry_market', 'dark_yamen', 'red_shrine_lane']}, 45),
]

ST = [
    ('st_meat_power', '고기 힘', 'spark', '든든한 고기 덕에 팔에 힘이 붙습니다.', {'combat_damage_pct': 6, 'incoming_damage_pct': -4}, 60),
    ('st_root_warm', '뿌리 온기', 'leaf', '뿌리채소의 온기가 몸속까지 퍼집니다.', {'healing_pct': 8, 'erosion_pct': -8}, 60),
    ('st_grain_full', '곡기 든든', 'leaf', '곡기가 배에 차 발걸음이 가볍습니다.', {'gather_qty_pct': 8, 'travel_time_pct': -5}, 60),
    ('st_great_table', '큰상 기운', 'flame', '잘 차린 큰상을 비워 온몸에 기운이 돕니다.', {'combat_damage_pct': 6, 'incoming_damage_pct': -5, 'healing_pct': 8}, 120),
    ('fs_night_office', '궁중 상의 격식', 'spark', '격식 있는 상을 받고 나니 손끝이 차분합니다.', {'craft_quality': 6, 'clue_bonus_pct': 8}, 90),
    ('fs_red_moon_cult', '사막 화덕', 'flame', '화덕 불맛이 속을 덥혀 흔들리지 않습니다.', {'combat_damage_pct': 6, 'mental_loss_pct': -8}, 90),
    ('fs_black_lotus', '뒷골목 입맛', 'eye', '뒷골목 맛을 알고 나니 눈치가 밝아집니다.', {'rare_loot_pct': 5, 'encounter_pct': -8}, 90),
    ('fs_north_league', '설원 버팀', 'shield', '설원 사람들의 밥심으로 버팁니다.', {'incoming_damage_pct': -8, 'erosion_pct': -8}, 90),
    ('fs_river_alliance', '물길 순풍', 'leaf', '물길 사람들의 밥상을 받아 걸음과 손이 가볍습니다.', {'travel_time_pct': -8, 'fish_bite_pct': 8}, 90),
    ('fs_southern_remnant', '잔불 기세', 'flame', '매운 불맛이 기세를 끌어올립니다.', {'combat_damage_pct': 8}, 90),
    ('fs_mandate_court', '별빛 맑음', 'spark', '별빛 아래 차린 약선이 정신을 맑게 합니다.', {'mental_loss_pct': -10, 'clue_bonus_pct': 8}, 90),
]

def fx(hp=0, mn=0, sp=0, er=0, buffs=()):
    return {'er': er, 'hp': hp, 'mn': mn, 'sp': sp, 'stam': 0, 'buffs': list(buffs), 'cures': []}

DISH = [
    ('dish_potato_grill', '감자 숯불구이', 1, {'fd_potato': 2, 'charcoal': 1}, 3, fx(hp=20, buffs=['well_fed']), '감자를 숯불에 껍질째 굽는다.'),
    ('dish_sweet_potato', '고구마 찜', 1, {'fd_sweet_potato': 2}, 2, fx(hp=15, mn=5, buffs=['well_fed']), '고구마를 김에 쪄 낸다.'),
    ('dish_greens', '산나물 무침', 2, {'fd_greens': 2, 'fd_garlic': 1}, 2, fx(mn=15, buffs=['clear_mind']), '산나물을 데쳐 마늘에 무친다.'),
    ('dish_mushroom_soup', '버섯국', 3, {'fd_mushroom': 2, 'herb': 1}, 2, fx(hp=20, mn=10, buffs=['warm_belly']), '버섯과 야령초로 맑게 끓인 국.'),
    ('dish_chicken_porridge', '닭죽', 3, {'mt_chicken': 1, 'fd_rice': 1}, 2, fx(hp=35, buffs=['well_fed']), '닭고기를 쌀과 함께 푹 쑨 죽.'),
    ('dish_chicken_skewer', '매운 닭꼬치', 4, {'mt_chicken': 1, 'fd_chili': 1, 'charcoal': 1}, 2, fx(hp=30, buffs=['vigor']), '고추 양념을 발라 숯불에 구운 닭꼬치.'),
    ('dish_beast_grill', '요수 고기 구이', 5, {'mt_beast': 1, 'charcoal': 1}, 2, fx(hp=35, buffs=['vigor']), '요수 생고기를 숯불에 굽는다.'),
    ('dish_minari_pancake', '미나리 메밀전', 5, {'fd_minari': 2, 'fd_buckwheat': 1}, 2, fx(hp=20, mn=10, buffs=['well_fed']), '메밀 반죽에 미나리를 얹어 부친다.'),
    ('dish_potato_braise', '감자 고기 조림', 7, {'mt_beast': 1, 'fd_potato': 1, 'fd_garlic': 1}, 2, fx(hp=40, buffs=['warm_belly']), '고기와 감자를 마늘 넣고 졸인다.'),
    ('dish_chestnut_rice', '밤밥', 8, {'fd_chestnut': 1, 'fd_rice': 1}, 3, fx(hp=30, buffs=['well_fed']), '밤을 넣고 지은 밥.'),
    ('dish_yofish_salt', '생선살 소금구이', 8, {'mt_yofish': 1, 'frost_salt': 1, 'charcoal': 1}, 2, fx(hp=35, mn=10, buffs=['warm_belly']), '요괴 생선살을 소금에 절였다가 숯불에 굽는다.'),
    ('dish_lotus_braise', '연근 대추 조림', 9, {'fd_lotus_root': 1, 'fd_jujube': 1}, 2, fx(mn=20, buffs=['clear_mind']), '연근을 대추와 함께 달게 졸인다.'),
    ('dish_buckwheat_jelly', '메밀묵', 10, {'fd_buckwheat': 2}, 3, fx(hp=15, mn=15, buffs=['well_rested']), '메밀 앙금을 쑤어 굳힌 묵.'),
    ('dish_pheasant_dumpling', '꿩 만둣국', 12, {'mt_pheasant': 1, 'fd_buckwheat': 1, 'fd_garlic': 1}, 2, fx(hp=50, buffs=['st_meat_power']), '꿩고기로 소를 넣은 메밀 만두를 끓인다.'),
    ('dish_deodeok_grill', '더덕 구이', 12, {'fd_deodeok': 1, 'fd_chili': 1, 'charcoal': 1}, 2, fx(hp=30, sp=15, buffs=['vigor']), '더덕을 두드려 고추 양념에 굽는다.'),
    ('dish_crab_porridge', '게살죽', 14, {'mt_crab': 1, 'herbal_extract': 1, 'fd_rice': 1}, 2, fx(hp=45, mn=15, buffs=['warm_belly']), '약초액으로 독을 뺀 게살을 쌀과 쑨다.'),
    ('dish_boar_smoke', '멧돼지 훈제', 15, {'mt_boar': 1, 'charcoal': 2}, 2, fx(hp=55, buffs=['st_meat_power']), '멧돼지고기를 숯불 연기에 오래 훈연한다.'),
    ('dish_root_hotpot', '뿌리 전골', 15, {'fd_potato': 1, 'fd_deodeok': 1, 'fd_mushroom': 1, 'medicine_base': 1}, 2, fx(hp=50, mn=20, buffs=['st_root_warm']), '뿌리채소와 버섯을 약제 국물에 끓인다.'),
    ('dish_sweet_candy', '고구마 맛탕', 16, {'fd_sweet_potato': 2, 'fd_jujube': 1}, 3, fx(hp=25, sp=10, buffs=['well_fed']), '고구마를 튀겨 대추 조청에 버무린다.'),
    ('dish_lotus_rice', '연잎 찰밥', 18, {'fd_lotus_root': 1, 'fd_rice': 2, 'fd_jujube': 1}, 2, fx(hp=45, mn=15, buffs=['st_grain_full']), '연근·대추를 넣은 밥을 연잎에 싸서 찐다.'),
    ('dish_ginger_tea', '생강 대추차', 18, {'fd_ginger': 1, 'fd_jujube': 1}, 3, fx(mn=20, er=5, buffs=['clear_mind']), '생강과 대추를 오래 달인 차.'),
    ('dish_spice_skewer', '향신 고기 꼬치', 20, {'mt_beast': 1, 'fd_spice_seed': 1, 'charcoal': 1}, 2, fx(hp=50, sp=10, buffs=['st_meat_power']), '향신 씨앗을 뿌려 구운 고기 꼬치.'),
    ('dish_chicken_baeksuk', '닭 백숙', 22, {'mt_chicken': 2, 'fd_garlic': 1, 'fd_jujube': 1, 'medicine_base': 1}, 2, fx(hp=70, mn=20, buffs=['st_root_warm']), '닭을 마늘·대추와 통째로 고아 낸다.'),
    ('dish_yofish_stew', '생선살 매운 찜', 24, {'mt_yofish': 2, 'frost_salt': 1, 'fd_chili': 1}, 2, fx(hp=60, mn=20, buffs=['warm_belly', 'vigor']), '절인 요괴 생선살을 고추 양념에 찐다.'),
    ('dish_crab_rice', '게살 볶음밥', 26, {'mt_crab': 1, 'herbal_extract': 1, 'fd_rice': 1, 'fd_garlic': 1}, 2, fx(hp=60, buffs=['st_grain_full']), '독을 뺀 게살과 마늘로 볶은 밥.'),
    ('dish_boar_suyuk', '멧돼지 수육', 28, {'mt_boar': 2, 'charcoal': 1, 'fd_garlic': 1, 'fd_ginger': 1}, 2, fx(hp=80, mn=20, buffs=['st_meat_power', 'warm_belly']), '훈연한 멧돼지고기를 생강·마늘 물에 삶는다.'),
    ('dish_pheasant_soup', '꿩탕', 30, {'mt_pheasant': 2, 'fd_deodeok': 1, 'medicine_base': 1}, 2, fx(hp=80, mn=30, buffs=['st_root_warm']), '꿩고기와 더덕을 약제 국물에 고은 탕.'),
    ('dish_mushroom_hotpot', '버섯 전골', 32, {'fd_mushroom': 3, 'fd_greens': 1, 'medicine_base': 1}, 2, fx(hp=70, mn=30, sp=20, buffs=['st_root_warm']), '버섯을 가득 넣고 끓인 전골.'),
    ('dish_spice_rice', '향신 고기 덮밥', 35, {'mt_beast': 2, 'fd_spice_seed': 1, 'fd_rice': 1}, 2, fx(hp=90, buffs=['st_meat_power']), '향신 씨앗으로 볶은 고기를 밥에 얹는다.'),
    ('dish_fern_bibim', '먹비 고사리 비빔밥', 42, {'fd_meokbi_fern': 2, 'fd_rice': 1, 'fd_greens': 1}, 2, fx(hp=80, mn=30, buffs=['st_great_table']), '검은 물을 뺀 먹비 고사리와 나물로 비빈 밥.'),
    ('dish_white_rice_cake', '흰 밤 찹쌀떡', 46, {'fd_white_rice': 2, 'fd_jujube': 1}, 3, fx(mn=40, sp=30, buffs=['st_great_table']), '흰 밤 찹쌀을 쪄서 친 떡에 대추 소를 넣는다.'),
    ('dish_great_table', '큰 상차림', 48, {'mt_boar': 1, 'charcoal': 1, 'mt_pheasant': 1, 'fd_white_rice': 1, 'fd_meokbi_fern': 1, 'medicine_base': 1}, 2, fx(hp=100, mn=40, sp=40, buffs=['st_great_table']), '훈연한 고기·꿩·찹쌀·고사리로 차린 큰상.'),
]

HUBS = {
    'night_office': ('capital_market', '백등 야시장'),
    'red_moon_cult': ('frontier_market', '백골 장터'),
    'black_lotus': ('underworld_market', '십삼문 암시장'),
    'north_league': ('north_market', '철벽 고찰'),
    'river_alliance': ('river_market', '구름나루'),
    'southern_remnant': ('south_market', '잔불촌'),
    'mandate_court': ('astral_market', '무극 관성대'),
}

SPECIAL = [
    ('night_office', '야시장 장국수', {'fd_buckwheat': 1, 'mt_chicken': 1, 'fd_garlic': 1}, '닭 육수에 메밀 국수를 만 백등 야시장 국수.',
     '궁중 신선로', {'mt_beast': 1, 'fd_mushroom': 1, 'fd_lotus_root': 1, 'fd_jujube': 1, 'medicine_base': 1}, '정청 잔칫날에만 내는 신선로.'),
    ('red_moon_cult', '대추 향신 꼬치', {'mt_beast': 1, 'fd_jujube': 1, 'fd_chili': 1}, '백골 장터 노점의 대추 양념 고기 꼬치.',
     '화덕 통고기', {'mt_beast': 2, 'fd_spice_seed': 1, 'charcoal': 1}, '사막 화덕에 통째로 구운 고기.'),
    ('black_lotus', '뒷골목 떡꼬치', {'fd_rice': 2, 'fd_chili': 1}, '십삼문 골목에서 파는 매운 떡꼬치.',
     '먹물 만두', {'fd_buckwheat': 1, 'mt_beast': 1, 'fd_mushroom': 1, 'fd_garlic': 1}, '먹물로 반죽을 물들인 흑련회 만두.'),
    ('north_league', '메밀 고깃국', {'fd_buckwheat': 1, 'mt_beast': 1, 'fd_garlic': 1}, '설원 사람들이 아침마다 끓이는 메밀 고깃국.',
     '언 고기 수육', {'mt_boar': 2, 'charcoal': 1, 'fd_garlic': 1, 'frost_salt': 1}, '눈 속에 얼려 둔 고기를 삶아 낸 북령 수육.'),
    ('river_alliance', '연근 생선 정식', {'fd_lotus_root': 1, 'fd_rice': 1, 'fish_fillet': 1}, '구름나루 뱃사람들의 한 상.',
     '연잎 생선찜', {'fish_fillet': 2, 'fd_lotus_root': 1, 'fd_minari': 1, 'fd_ginger': 1}, '생선을 연잎에 싸서 찐 수향 잔칫상.'),
    ('southern_remnant', '잔불 고추 찌개', {'fd_chili': 2, 'fd_potato': 1, 'mt_beast': 1}, '잔불촌 화로에서 끓는 고추 찌개.',
     '화산 매운 고기구이', {'mt_boar': 1, 'fd_chili': 2, 'fd_ginger': 1, 'charcoal': 2}, '화산 돌판에 구운 남명 고기구이.'),
    ('mandate_court', '관성 대추 다과', {'fd_jujube': 2, 'fd_chestnut': 1}, '별을 보며 곁들이는 대추·밤 다과.',
     '별빛 약선죽', {'fd_rice': 1, 'fd_jujube': 1, 'fd_deodeok': 1, 'medicine_base': 1}, '천명원 관측관들이 밤샘 뒤 먹는 약선죽.'),
]
SPECIAL_LV = (10, 30)
SPECIAL_FX = (dict(hp=40, mn=15), dict(hp=80, mn=30, sp=20))

SHOP_ROT = {
    'capital_market': ['fd_rice', 'fd_greens', 'fd_potato', 'mt_chicken'],
    'frontier_market': ['fd_jujube', 'fd_spice_seed', 'mt_beast'],
    'underworld_market': ['fd_mushroom', 'fd_potato', 'mt_chicken'],
    'north_market': ['fd_garlic', 'fd_buckwheat', 'fd_potato', 'mt_beast'],
    'river_market': ['fd_rice', 'fd_lotus_root', 'fd_minari', 'mt_yofish'],
    'south_market': ['fd_chili', 'fd_ginger', 'fd_sweet_potato', 'mt_boar'],
    'astral_market': ['fd_jujube', 'fd_chestnut', 'fd_deodeok', 'mt_pheasant'],
    'night_office_store': ['fd_rice', 'fd_potato'],
}
SHOP_MUL = 1.3
SPECIAL_CAP = 5
SHOW_MIN = (10, 6)

EDIT = {
    'cook_herb_rice': ({'fd_rice': 1, 'fd_greens': 1, 'herb': 1}, ['travel_ration']),
    'cook_spicy_stew': ({'fd_chili': 1}, []),
    'stew_lenok': ({'fd_chili': 1}, []),
    'cook_rockfish_stew': ({'fd_chili': 1}, []),
    'r_paperboat_spicy_stew': ({'fd_chili': 1}, []),
    'cook_herb_fish': ({'herb': 1, 'fd_ginger': 1}, []),
    'cook_catfish': ({'herb': 1, 'fd_garlic': 1}, []),
    'cook_carp_broth': ({'fd_jujube': 1}, []),
    'cook_eel_tonic': ({'fd_ginger': 1}, []),
    'tonic_swamp_eel': ({'fd_ginger': 1}, []),
    'cook_snakehead': ({'fd_garlic': 1}, []),
    'cook_hairtail': ({'fd_potato': 1, 'fd_chili': 1}, ['herb']),
    'cook_cod_soup': ({'fd_garlic': 1}, ['herb']),
    'cook_croaker_soup': ({'fd_minari': 1}, ['herb']),
    'cook_moss_porridge': ({'fd_rice': 1}, ['travel_ration']),
    'r_crucian_reed_porridge': ({'fd_rice': 1}, []),
    'r_goby_braise': ({'fd_chili': 1}, ['herb']),
    'r_mist_crucian_steam': ({'herb': 1, 'fd_ginger': 1}, []),
    'cook_grouper_steam': ({'fd_ginger': 1}, []),
    'cook_bark_stew': ({'fd_jujube': 1}, []),
    'r_minnow_fritter': ({'fd_buckwheat': 1}, ['herb']),
    'r_smelt_clear_soup': ({'fd_minari': 1}, ['river_reed']),
    'r_cheong_carp_steam': ({'herb': 1, 'fd_lotus_root': 1}, []),
    'r_goldcarp_feast': ({'herb': 1, 'fd_lotus_root': 1}, []),
}

KIN_FOOD = {
    'hanseol': 'dish_ginger_tea', 'yeoul': 'dish_potato_grill', 'wolha': 'sp_black_lotus_2', 'daon': 'dish_sweet_candy',
    'hisu': 'dish_chestnut_rice', 'danbi': 'sp_red_moon_cult_1', 'unbi': 'sp_north_league_1', 'cheongpa': 'sp_river_alliance_2',
    'galmae': 'sp_southern_remnant_2', 'haram': 'sp_mandate_court_2', 'munsu': 'sp_night_office_1', 'mogaram': 'dish_buckwheat_jelly',
    'yeonseohui': 'dish_chicken_porridge', 'kangducheol': 'dish_boar_suyuk', 'yeoseotjjae': 'sp_black_lotus_1',
}
KIN_FOOD_MUL = 1.5
MEAT_P = {'normal': 0.25, 'elite': 0.4, 'guardian': 0.6}
MEAT_N = [1, 2]
STORAGE_BASE = (70, 90)
DB_VERSION = '20261126180000'
