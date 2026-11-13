MEISHO = [
    dict(id='mz_reed_dawn', name='물안개 새벽 약초 섶', region='ash_reeds', node='잿빛 물길', kind='herb', phase='dawn', weather='fog', weather2='cloudy',
         desc='잿빛 물길 가장자리의 약초 섶이다. 안개가 끼거나 하늘이 흐린 새벽이면 뿌리 끝이 젖어 드러난다.'),
    dict(id='mz_shrine_ceiling', name='천장에 뿌리 내린 약초밭', region='inverted_shrine', node='천장 밟는 회랑', kind='herb', phase='night', weather='clear', weather2='fog',
         desc='거꾸로 선 사당 회랑 천장에 거꾸로 뿌리 내린 약초밭이다. 맑거나 안개 낀 삼경에만 잎이 아래로 늘어진다.'),
    dict(id='mz_meokbi_herb', name='먹비 머금은 영초 덤불', region='meokbi_forest', node='빗물 고인 덤불', kind='herb', phase='noon', weather='drizzle', weather2='rain',
         desc='비가 가늘게 내리든 세차게 내리든, 비 오는 한낮에만 먹빛을 벗고 푸른 잎을 내미는 영초 덤불이다.'),
    dict(id='mz_court_grass', name='아홉 칸 뜰 이름풀 자리', region='nine_court', node='첫째 칸', kind='herb', phase='dusk', weather='cloudy', weather2='drizzle',
         desc='흐리거나 가는 비가 내리는 땅거미에만 돋는 풀이다. 잎맥이 누군가의 이름 획을 닮았다.'),
    dict(id='mz_shrine_juniper', name='거꾸로 자란 향나무', region='inverted_shrine', node='거꾸로 걸린 종루', kind='wood', phase='dusk', weather='cloudy', weather2='wind',
         desc='종루 들보에서 땅을 향해 자란 향나무다. 흐리거나 삭풍이 부는 땅거미에 결이 풀려 깎아 낼 수 있다.'),
    dict(id='mz_market_beam', name='천 년 묵은 객주 대들보', region='moonless_market', node='빈 좌판 골목', kind='wood', phase='night', weather='fog', weather2='clear',
         desc='달 없는 저잣거리가 생기기 전부터 서 있던 객주의 대들보다. 안개가 짙거나 하늘이 맑은 삼경에만 나뭇결이 살아난다.'),
    dict(id='mz_field_locust', name='벌판의 외톨이 회화나무', region='blank_field', node='흰 억새 들', kind='wood', phase='dawn', weather='wind', weather2='rain',
         desc='빈칸 벌판에 홀로 선 회화나무다. 삭풍이 불거나 장대비가 쏟아지는 새벽에만 마른 가지가 저절로 떨어진다.'),
    dict(id='mz_meokbi_ebony', name='먹비 숲 흑단 고목', region='meokbi_forest', node='검은 잎 오솔길', kind='wood', phase='night', weather='rain', weather2='drizzle',
         desc='먹비를 가장 오래 맞은 흑단 고목이다. 비가 내리는 삼경에만 속살이 비친다.'),
    dict(id='mz_abyss_vein', name='봉인 계단 밑 영석 맥', region='sealed_abyss', node='봉인 계단', kind='stone', phase='noon', weather='cloudy', weather2='fog',
         desc='봉인 계단 아래로 흐르는 영석 맥이다. 흐리거나 안개 낀 한낮에만 맥이 떨며 틈을 연다.'),
    dict(id='mz_market_whetstone', name='녹슨 대장간 숫돌 바닥', region='moonless_market', node='녹슨 대장간 터', kind='stone', phase='dusk', weather='clear', weather2='wind',
         desc='수많은 칼을 갈아 낸 숫돌 바닥이다. 맑거나 삭풍이 부는 땅거미에 바닥 아래 단단한 돌이 드러난다.'),
    dict(id='mz_core_slab', name='가라앉는 돌길 검은 반석', region='gwiheo_core', node='가라앉는 돌길', kind='stone', phase='dawn', weather='cloudy', weather2='fog',
         desc='귀허로 가라앉아 가는 돌길 끝의 검은 반석이다. 흐리거나 안개 낀 새벽에만 물 위로 한 뼘 떠오른다.'),
    dict(id='mz_tower_plinth', name='명부 탑 주춧돌 틈', region='myeongbu_tower', node='무너진 회랑', kind='stone', phase='night', weather='fog', weather2='wind',
         desc='명부 탑을 떠받친 주춧돌 사이 틈이다. 안개가 끼거나 삭풍이 부는 삼경에만 틈 안쪽 돌이 빛을 낸다.'),
]

MATS = [
    ('mz_herb', '명초', 5, 40, 600, '이름난 자리에서만 자라는 약초. 한 철을 한 시간에 몰아 산다.'),
    ('mz_herb_j', '명초의 정', 6, 40, 1500, '명초에서 가장 맑은 기운만 모인 잎. 손끝에 닿으면 시든 풀도 고개를 든다.'),
    ('mz_herb_n', '이름 서린 명초', 7, 40, 4000, '잎맥마다 옛사람의 이름이 서린 명초. 명부 정리 전에 누군가 지키려 심어 둔 것이라 한다.'),
    ('mz_wood', '명목', 5, 40, 600, '이름난 자리의 나무에서 얻은 목재. 결이 곧고 썩지 않는다.'),
    ('mz_wood_j', '명목의 정', 6, 40, 1500, '명목 한가운데의 단단한 속심. 두드리면 맑은 소리가 오래 남는다.'),
    ('mz_wood_n', '이름 서린 명목', 7, 40, 4000, '나이테마다 이름이 새겨진 명목. 깎는 칼끝이 저절로 결을 따라간다.'),
    ('mz_stone', '명석', 5, 40, 600, '이름난 자리의 돌에서 떼어 낸 조각. 차갑고 무겁다.'),
    ('mz_stone_j', '명석의 정', 6, 40, 1500, '명석 안에 맺힌 맑은 결정. 불에 달궈도 결이 흐트러지지 않는다.'),
    ('mz_stone_n', '이름 서린 명석', 7, 40, 4000, '이름이 결 따라 새겨진 명석. 쥐고 있으면 낯선 이름이 귀에 맴돈다.'),
]

KIND_ITEMS = {'herb': ['mz_herb', 'mz_herb_j', 'mz_herb_n'], 'wood': ['mz_wood', 'mz_wood_j', 'mz_wood_n'], 'stone': ['mz_stone', 'mz_stone_j', 'mz_stone_n']}

STATUSES = [
    ('mz_incense', '명소 향', 1440, {'mz_next': 1}, 'eye', '명소 향의 연기가 다음에 열릴 명소를 짚어 줍니다. 현장 채집터 칸에 다음 명소가 언제·어디서 열리는지 보입니다.'),
    ('mz_ward', '명소 지킴', 360, {'erosion_pct': -20, 'mental_loss_pct': -20, 'rare_loot_pct': 8}, 'shield', '명소의 기운을 접은 부적이 몸을 지킵니다.'),
    ('mz_vigor', '명초 정기', 360, {'healing_pct': 15, 'gather_qty_pct': 10}, 'leaf', '명초의 정이 기운을 북돋아 회복이 잘 되고 손이 바빠집니다.'),
    ('mz_clear', '이름 서린 맑음', 360, {'mental_loss_pct': -25, 'erosion_pct': -20}, 'spark', '이름 서린 명초가 마음을 맑게 붙잡아 줍니다.'),
    ('mz_full', '명초 산채의 든든함', 480, {'healing_pct': 10, 'gather_qty_pct': 8}, 'leaf', '명초 산채 정식으로 배를 채워 오래 든든합니다.'),
    ('mz_smoke', '명목 훈연의 기운', 480, {'incoming_damage_pct': -6, 'combat_damage_pct': 4}, 'flame', '명목 연기에 익힌 한 상이 몸을 단단히 데워 줍니다.'),
    ('mz_feast', '이름 서린 잔치', 720, {'healing_pct': 10, 'gather_qty_pct': 10, 'craft_quality': 5, 'mental_loss_pct': -10}, 'spark', '이름 서린 재료로 차린 잔칫상의 기운이 반나절 갑니다.'),
]


def gear(iid, name, cat, traits, desc, stats=None):
    return dict(id=iid, name=name, cat=cat, traits=traits, desc=desc, stats=stats or {})


GEAR_STATS = {
    'n_mz_iron': {'perception': 36}, 'k_mz_wood': {'agility': 36}, 'm_mz_stone': {'willpower': 36}, 'h_mz_herb': {'willpower': 36},
    's_mz_herb': {'vitality': 36}, 'n_mz_herb': {'spirit_affinity': 36}, 'a_mz_robe': {'willpower': 48}, 's_mz_stone': {'vitality': 36},
    'm_mz_wood': {'spirit_affinity': 36}, 'a_mz_shade': {'agility': 48},
}

GEAR_LV = {'tool': 40, 'armor': 42, 'hat': 42, 'shoes': 42, 'norigae': 42, 'amulet': 42, 'mask': 42}


TOOL_GATHER = {'trait': '정밀 채집', 'req_line': 'gathering_rank', 'req_rank': 30}

GEAR = [
    gear('lt_pick_mz', '명장 곡괭이', 'tool', dict(TOOL_GATHER, gathering_bonus_pct=32, rare_loot_pct=9, mz_j_stone=15), '명장이 명석으로 날을 세운 곡괭이. 명소에서 「명석의 정」을 더 잘 가려낸다.'),
    gear('lt_sickle_mz', '명장 낫', 'tool', dict(TOOL_GATHER, gathering_bonus_pct=28, sig_pct=10, sig_where='herb', mz_j_herb=15), '명장이 명초 줄기를 베어 날을 길들인 낫. 명소에서 「명초의 정」을 더 잘 가려낸다.'),
    gear('n_mz_iron', '명석 쇠고리 노리개', 'norigae', {'trait': '노리개', 'gather_qty_pct': 22, 'mz_extra': 1}, '명석 쇠고리를 꿴 노리개. 명소에서 캘 때 명소 재료를 하나 더 거둔다.'),
    gear('lt_knife_mz', '명장 채집도', 'tool', dict(TOOL_GATHER, gathering_bonus_pct=34, rare_loot_pct=10, mz_j_wood=15), '명목 자루에 맑은 날을 박은 채집도. 명소에서 「명목의 정」을 더 잘 가려낸다.'),
    gear('lt_rod_mz', '명목 낚싯대', 'tool', {'trait': '낚시', 'life_slot': 'fishing', 'fish_bite_pct': 23, 'fish_rare_pct': 18, 'fish_size_pct': 12, 'named_wt': 0.12}, '명목 한 가지를 통째로 깎은 낚싯대. 명어가 조금 더 잘 문다.'),
    gear('k_mz_wood', '명목 탈', 'mask', {'trait': '탈', 'presence': -70, 'encounter_pct': -22, 'mz_soil_pct': 50}, '명목으로 깎은 탈. 쓰고 흙을 살피면 묻힌 것이 더 잘 보인다.'),
    gear('lt_compass_mz', '명장 나침반', 'tool', {'trait': '탐사', 'req_line': 'investigation_rank', 'req_rank': 30, 'life_slot': 'explore', 'search_find_pct': 48, 'clue_bonus_pct': 9, 'mz_sense': 1},
         '명석 바늘을 띄운 나침반. 지금 있는 지역에 열린 명소가 있으면 바늘이 그쪽을 가리킨다.'),
    gear('lt_lantern_mz', '명장 등', 'tool', dict(TOOL_GATHER, gathering_bonus_pct=26, sig_pct=12, sig_where='dark', mz_n_pct=3), '명석의 정을 심지 삼은 등. 명소에서 「이름 서린」 재료가 더 잘 보인다.'),
    gear('m_mz_stone', '명석 영패', 'amulet', {'trait': '호신부', 'presence': 28, 'incoming_damage_pct': -14, 'mz_n_pct': 2}, '이름 서린 명석을 깎은 영패. 지니면 명소에서 「이름 서린」 재료가 더 잘 보인다.'),
    gear('h_mz_herb', '명초 관모', 'hat', {'trait': '관모', 'erosion_pct': -28, 'mental_loss_pct': -42, 'mz_soil_pct': 30}, '명초의 정으로 물들인 관모. 흙을 살필 때 눈이 밝아진다.'),
    gear('s_mz_herb', '명초 미투리', 'shoes', {'trait': '신', 'travel_time_pct': -28, 'mz_soil_pct': 30}, '명초 줄기를 꼬아 삼은 미투리. 발끝으로 흙의 결을 느낀다.'),
    gear('n_mz_herb', '명초 향낭 노리개', 'norigae', {'trait': '노리개', 'rare_loot_pct': 22, 'mz_j_all': 10}, '명초의 정을 넣은 향낭 노리개. 어느 명소에서든 「…의 정」을 더 잘 가려낸다.'),
    gear('a_mz_robe', '이름 서린 도포', 'armor', {'trait': '방호', 'defense': 26, 'erosion_pct': -22, 'damage_reduction_pct': 14, 'mz_n_pct': 2}, '이름 서린 명초로 물들인 도포. 명소에서 「이름 서린」 재료가 더 잘 보인다.'),
    gear('s_mz_stone', '명석 징 장화', 'shoes', {'trait': '신', 'defense': 11, 'presence': 28, 'mz_extra': 1}, '바닥에 명석 징을 박은 장화. 명소에서 캘 때 명소 재료를 하나 더 거둔다.'),
    gear('m_mz_wood', '명목 가죽 부적낭', 'amulet', {'trait': '호신부', 'magic_pct': 22, 'mz_j_all': 10}, '명목의 정을 넣어 꿰맨 가죽 부적낭. 어느 명소에서든 「…의 정」을 더 잘 가려낸다.'),
    gear('a_mz_shade', '명소 야행의', 'armor', {'trait': '방호', 'defense': 23, 'crit_pct': 7, 'presence': -56, 'evasion_pct': 7, 'mz_soil_pct': 30}, '이름 서린 명목 물을 들인 야행의. 흙을 살필 때 묻힌 것의 기척을 잡는다.'),
]

FOOD = [
    dict(id='mz_incense', name='명소 향', tier=6, fx={'buffs': ['mz_incense']}, desc='명초와 명목을 함께 사른 향. 피우면 하루 동안 다음에 열릴 명소가 언제·어디서 열리는지 보인다.', hq=True),
    dict(id='mz_ward', name='명소 지킴 부적', tier=7, fx={'buffs': ['mz_ward']}, desc='이름 서린 명초를 넣어 접은 부적. 여섯 시간 침식과 정신 손실을 덜고 귀한 것이 잘 보인다.', hq=True),
    dict(id='mz_pill', name='명초 정기환', tier=6, fx={'hp': 60, 'mn': 30, 'sp': 40}, desc='명초를 달여 빚은 환약. 체력·정신·영력을 한꺼번에 채운다.', hq=True),
    dict(id='mz_elixir', name='명초 정 영단', tier=6, fx={'mn': 20, 'buffs': ['mz_vigor']}, desc='명초의 정을 굳힌 영단. 여섯 시간 회복이 잘 되고 채집량이 늘어난다.', hq=True),
    dict(id='mz_clear', name='이름 서린 환', tier=7, fx={'er': 40, 'mn': 40, 'buffs': ['mz_clear']}, desc='이름 서린 명초로 빚은 환. 침식을 크게 덜고 여섯 시간 마음을 맑게 붙잡는다.', hq=True),
    dict(id='mz_meal_herb', name='명초 산채 정식', tier=6, fx={'hp': 50, 'mn': 15, 'buffs': ['mz_full']}, desc='명초를 데쳐 차린 산채 정식. 여덟 시간 든든하다.', hq=True),
    dict(id='mz_meal_wood', name='명목 훈연 한 상', tier=6, fx={'hp': 70, 'buffs': ['mz_smoke']}, desc='명목 연기에 생선을 익힌 한 상. 여덟 시간 몸이 단단하다.', hq=True),
    dict(id='mz_meal_feast', name='이름 서린 잔칫상', tier=7, fx={'hp': 100, 'mn': 40, 'buffs': ['mz_feast']}, desc='이름 서린 재료로 차린 잔칫상. 기운이 반나절 이어진다.', hq=True),
]

RANK_LV = {30: 30, 40: 36, 50: 42}

RECIPES = [
    ('smithing', 30, 'lt_pick_mz', 1, {'mz_stone': 4, 'erased_plate': 2, 'bronze_scale_plate': 2, 'drifting_name_thread': 1}),
    ('smithing', 40, 'lt_sickle_mz', 1, {'mz_herb_j': 2, 'mz_herb': 3, 'steel_ingot': 2, 'drifting_name_thread': 2}),
    ('smithing', 50, 'n_mz_iron', 1, {'mz_stone_n': 1, 'mz_stone_j': 2, 'gwiheo_iron': 4, 'drifting_name_thread': 2}),
    ('carpentry', 30, 'lt_knife_mz', 1, {'mz_wood': 4, 'meokbi_ebony': 2, 'bronze_scale_plate': 2, 'drifting_name_thread': 1}),
    ('carpentry', 40, 'lt_rod_mz', 1, {'mz_wood_j': 2, 'mz_wood': 3, 'carp_glue': 2, 'mukchang_ink': 1}),
    ('carpentry', 50, 'k_mz_wood', 1, {'mz_wood_n': 1, 'mz_wood_j': 2, 'shadow_fang': 3, 'drifting_name_thread': 2}),
    ('artifice', 30, 'lt_compass_mz', 1, {'mz_stone': 3, 'spirit_glass': 1, 'register_slip': 2, 'erased_plate': 1}),
    ('artifice', 40, 'lt_lantern_mz', 1, {'mz_stone_j': 2, 'mz_wood': 2, 'shad_oil': 2, 'meokgwi_lump': 2}),
    ('artifice', 50, 'm_mz_stone', 1, {'mz_stone_n': 1, 'mz_stone_j': 2, 'mirror_shard': 2, 'drifting_name_thread': 2}),
    ('sealing', 30, 'mz_incense', 2, {'mz_herb': 2, 'mz_wood': 1, 'ghost_ash': 1, 'mukchang_ink': 1}),
    ('sealing', 40, 'h_mz_herb', 1, {'mz_herb_j': 2, 'blank_hanji': 3, 'mukchang_ink': 2, 'drifting_name_thread': 2}),
    ('sealing', 50, 'mz_ward', 2, {'mz_herb_n': 1, 'mz_stone_j': 1, 'blank_hanji': 2, 'mukchang_ink': 2}),
    ('weaving', 30, 's_mz_herb', 1, {'mz_herb': 4, 'reed_silk': 3, 'moonless_silk': 2, 'drifting_name_thread': 1}),
    ('weaving', 40, 'n_mz_herb', 1, {'mz_herb_j': 2, 'mz_wood_j': 1, 'moonless_silk': 3, 'drifting_name_thread': 2}),
    ('weaving', 50, 'a_mz_robe', 1, {'mz_herb_n': 1, 'mz_herb_j': 2, 'moonless_silk': 4, 'meokbi_moss': 3, 'drifting_name_thread': 3}),
    ('leatherwork', 30, 's_mz_stone', 1, {'mz_stone': 4, 'meokgwi_lump': 3, 'bronze_scale_plate': 2, 'drifting_name_thread': 1}),
    ('leatherwork', 40, 'm_mz_wood', 1, {'mz_wood_j': 2, 'mz_herb': 2, 'shadow_fang': 2, 'drifting_name_thread': 2}),
    ('leatherwork', 50, 'a_mz_shade', 1, {'mz_wood_n': 1, 'mz_stone_j': 2, 'shadow_fang': 3, 'meokgwi_lump': 3, 'drifting_name_thread': 3}),
    ('alchemy', 30, 'mz_pill', 2, {'mz_herb': 2, 'herbal_extract': 1, 'medicine_base': 1}),
    ('alchemy', 40, 'mz_elixir', 2, {'mz_herb_j': 1, 'mz_herb': 1, 'spirit_core': 1}),
    ('alchemy', 50, 'mz_clear', 2, {'mz_herb_n': 1, 'mz_herb_j': 1, 'spirit_core': 1, 'oblivion_crystal': 1}),
    ('cooking', 30, 'mz_meal_herb', 2, {'mz_herb': 2, 'herb': 2, 'fish_fillet': 1}),
    ('cooking', 40, 'mz_meal_wood', 2, {'mz_wood_j': 1, 'mz_wood': 1, 'fish_fillet': 2}),
    ('cooking', 50, 'mz_meal_feast', 2, {'mz_herb_n': 1, 'mz_wood_j': 1, 'mz_stone_j': 1, 'fish_fillet': 3}),
]

RULES = {
    'open_min': 60, 'phase_h': 6, 'look_days': 21,
    'phase_start': {'night': 0, 'dawn': 6, 'noon': 12, 'dusk': 18},
    'find_w': 30, 'find_xp': 10,
    'rank': {'base': 30, 'j': 40, 'n': 50},
    'qty': {'base': 2, 'r40': 1, 'r50': 1}, 'extra_cap': 2,
    'j_pct': {'base': 50, 'per_rank': 3, 'cap': 95},
    'n_pct': {'base': 4, 'cap': 15},
    'stamina': 1,
    'soil': {'pct': {'1': 12, '2': 9, '3': 6}, 'cap': 30, 'grade_lv': [[44, 3], [38, 2], [30, 1]]},
    'incense': 'mz_incense', 'next_n': 3,
    'kinds': {
        'herb': {'name': '명초', 'line': 'foraging', 'cat': 'herbs', 'items': KIND_ITEMS['herb']},
        'wood': {'name': '명목', 'line': 'foraging', 'cat': 'wood', 'items': KIND_ITEMS['wood']},
        'stone': {'name': '명석', 'line': 'mining', 'cat': 'ore', 'items': KIND_ITEMS['stone']},
    },
    'fx': {'mz_j_herb': '명소 「명초의 정」', 'mz_j_wood': '명소 「명목의 정」', 'mz_j_stone': '명소 「명석의 정」', 'mz_j_all': '명소 「…의 정」',
           'mz_n_pct': '명소 「이름 서린」', 'mz_extra': '명소 재료 덤', 'mz_soil_pct': '흙 살피기 비장도', 'mz_sense': '열린 명소 기척', 'mz_next': '다음 명소 보기'},
    'flags': ['mz_sense', 'mz_next'], 'flat': ['mz_extra'],
}

TOOL_LINES = {'lt_pick_mz': 'pick', 'lt_sickle_mz': 'sickle', 'lt_knife_mz': 'knife', 'lt_rod_mz': 'rod', 'lt_compass_mz': 'explore', 'lt_lantern_mz': 'lantern'}
