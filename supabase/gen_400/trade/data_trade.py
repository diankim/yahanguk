import math

PORTS = [
    ('river_ferry', '구름나루', '강 나루', True, 'main', ['tide_gate']),
    ('ember_village', '잔불촌', '재의 해안 부두', True, 'main', ['ash_coast', 'crimson_mine']),
    ('iron_monastery', '철벽 고찰', '빙혼곡 얼음 해안', True, 'main', ['frost_valley']),
    ('hidden_bazaar', '십삼문 암시장', '밀수 부두', False, 'main', ['hidden_bazaar', 'ledger_cellar']),
    ('red_moon_fort', '적월교 월식성', '바위 해안', True, 'main', ['red_moon_fort']),
    ('sleeping_port', '잠든 포구', '방파제', False, 'main', ['sleeping_port']),
    ('star_observatory', '무극 관성대', '별빛 벼랑', False, 'main', ['star_observatory', 'cloud_corridor']),
    ('banyo_village', '반요촌', '섬 나루', False, 'main', ['ash_reeds']),
    ('lamp_rest', '등지기 쉼막', '옛 나루 저자', False, 'main', ['old_ferry_market']),
    ('pd_city', '파도너울성', '물 위 선창', True, 'hanul', ['pd_shore', 'pd_offsea']),
    ('jb_village', '억새 나루', '억새 선창', False, 'hanul', ['jb_ferry']),
    ('bs_town', '화덕골', '김 오르는 부두', False, 'hanul', ['bs_geo']),
    ('ho_city', '해오름성', '첫볕 선창', False, 'hanul', ['ho_coast']),
]

MAIN = ['river_ferry', 'sleeping_port', 'star_observatory', 'iron_monastery', 'red_moon_fort', 'lamp_rest', 'hidden_bazaar', 'banyo_village', 'ember_village']
TABLE = '''
- 1:15 1:35 2:40 4:00 2:50 3:00 2:15 1:50
1:15 - 0:35 1:40 3:30 3:05 3:15 2:25 2:05
1:35 0:35 - 1:20 3:10 3:25 3:35 2:45 2:20
2:40 1:40 1:20 - 2:10 3:40 3:50 3:45 3:25
4:00 3:30 3:10 2:10 - 1:50 2:00 2:10 2:25
2:50 3:05 3:25 3:40 1:50 - 0:30 1:05 1:20
3:00 3:15 3:35 3:50 2:00 0:30 - 1:10 1:30
2:15 2:25 2:45 3:45 2:10 1:05 1:10 - 0:45
1:50 2:05 2:20 3:25 2:25 1:20 1:30 0:45 -
'''
HANUL_ROUTES = [('pd_city', 'bs_town', 80), ('pd_city', 'jb_village', 100), ('jb_village', 'ho_city', 100), ('bs_town', 'ho_city', 145), ('pd_city', 'ho_city', 180), ('bs_town', 'jb_village', 160)]
CROSS = [('river_ferry', 'pd_city', 120)]


def mins(s):
    h, m = s.split(':')
    return int(h) * 60 + int(m)


def routes():
    out = []
    rows = [r.split() for r in TABLE.strip().splitlines()]
    for i, a in enumerate(MAIN):
        for j, b in enumerate(MAIN):
            if j <= i:
                continue
            x, y = rows[i][j], rows[j][i]
            if x != y:
                raise SystemExit(f'뱃길 표가 엇갈림: {a}-{b} {x}/{y}')
            out.append([a, b, mins(x)])
    out += [list(r) for r in HANUL_ROUTES]
    out += [list(r) for r in CROSS]
    return out


GOODS = [
    ('tg_lotus_tea', '연잎 차', 'river_ferry', 20, ['iron_monastery', 'red_moon_fort'], '구름나루 물가 연잎을 말려 덖은 차. 뭍 깊은 곳일수록 귀하게 친다.'),
    ('tg_ember_ware', '잔불 도자기', 'ember_village', 20, ['iron_monastery', 'star_observatory'], '잔불촌 가마에서 구운 그릇. 불씨 무늬가 은은하게 남았다.'),
    ('tg_snow_honey', '설산 꿀', 'iron_monastery', 25, ['ember_village', 'banyo_village'], '눈 덮인 산벌이 모은 꿀. 추운 데서 굳어 하얗게 엉긴다.'),
    ('tg_smuggle_incense', '밀수 향', 'hidden_bazaar', 25, ['sleeping_port', 'star_observatory'], '십삼문 뒷골목으로 흘러든 향. 어디서 왔는지는 묻지 않는 것이 예의다.'),
    ('tg_red_dye', '붉은 염료', 'red_moon_fort', 25, ['river_ferry', 'sleeping_port'], '월식성 바위틈 풀뿌리로 낸 붉은 물감. 한 번 들면 잘 빠지지 않는다.'),
    ('tg_dried_seafood', '말린 해산물', 'sleeping_port', 25, ['red_moon_fort', 'lamp_rest'], '잠든 포구 방파제에서 말린 생선과 조개. 오래 두고 먹는다.'),
    ('tg_star_glass', '별빛 유리', 'star_observatory', 30, ['hidden_bazaar', 'lamp_rest'], '관성대 별빛 벼랑의 모래로 녹인 유리. 빛에 비추면 잔별이 돈다.'),
    ('tg_gwiheo_shell', '귀허 조개 가루', 'banyo_village', 30, ['river_ferry', 'iron_monastery'], '귀허 앞바다 조개껍데기를 빻은 가루. 약재와 칠에 두루 쓴다.'),
    ('tg_wick_oil', '등심지 기름', 'lamp_rest', 30, ['sleeping_port', 'iron_monastery'], '등지기들이 심지를 적시는 기름. 흰 밤에도 불이 오래 간다.'),
    ('tg_coral_salt', '산호 소금', 'pd_city', 40, ['ho_city', 'bs_town'], '파도너울성 산호 갯벌에서 구운 소금. 분홍빛이 돈다.'),
    ('tg_reed_silk', '억새 비단', 'jb_village', 40, ['pd_city', 'bs_town'], '억새 나루 사람들이 억새 속심으로 짠 가벼운 비단.'),
    ('tg_iron_pot', '쇠솥', 'bs_town', 40, ['jb_village', 'ho_city'], '화덕골 대장간이 두들겨 만든 무쇠솥. 무겁지만 대를 물려 쓴다.'),
    ('tg_dawn_oil', '해오름 향유', 'ho_city', 40, ['pd_city', 'jb_village'], '해오름성 첫볕에 우린 꽃기름. 바르면 아침 냄새가 난다.'),
]

ROBBER = ('tr_water_bandit', '물길 강도', 'tide_gate', 'shadow', 'ambush',
          '뱃길을 따라 숨어 다니며 짐배를 노리는 무리다. 안개 낀 물목에서 갈고리를 던져 뱃전에 붙는다.',
          {'beast_bone': 1, 'resin': 1})

SHIPS = [
    dict(tier=1, name='나룻배', slots=3, dur=100, speed=1.0, crew=2, cabin=0, lv=1, gil=0),
    dict(tier=2, name='거룻배', slots=5, dur=150, speed=0.9, crew=2, cabin=4, lv=10, gil=2000),
    dict(tier=3, name='돛배', slots=8, dur=220, speed=0.75, crew=3, cabin=5, lv=20, gil=8000),
    dict(tier=4, name='판옥배', slots=12, dur=300, speed=0.6, crew=4, cabin=6, lv=30, gil=20000),
    dict(tier=5, name='대양함선', slots=20, dur=400, speed=0.5, crew=4, cabin=7, lv=45, gil=50000),
]

PART_NAMES = {'wood': '목재', 'sail': '돛', 'iron': '쇠붙이', 'seal': '방수', 'guide': '길잡이', 'ballast': '바닥짐', 'once': '한 번만'}
PART_BASE = {
    2: {'wood': {'lumber': 20, 'wood': 15}, 'sail': {'talisman_thread': 6, 'river_reed': 20}, 'iron': {'iron_ingot': 10, 'raw_iron': 20},
        'seal': {'resin': 10, 'beast_hide': 6}, 'guide': {'seal_paper': 10, 'inkstone': 10}, 'ballast': {'ore': 20}},
    3: {'wood': {'reinforced_lumber': 10, 'beast_bone': 10}, 'sail': {'spirit_thread': 10, 'cloud_cotton': 10}, 'iron': {'iron_ingot': 20, 'beast_fang': 10},
        'seal': {'lacquer': 15, 'drowned_scale': 10, 'venom_gland': 6}, 'guide': {'ward_fragment': 10, 'bitterling_ink': 10}, 'ballast': {'frost_salt': 20},
        'once': {'sky_feather': 2}},
    4: {'wood': {'reinforced_lumber': 20, 'plank_water_jar': 2}, 'sail': {'reed_silk': 10, 'spirit_thread': 10}, 'iron': {'gwiheo_iron': 15, 'steel_ingot': 8},
        'seal': {'carp_glue': 10, 'lantern_oil': 6, 'shad_oil': 6}, 'guide': {'jade_shard': 4, 'rune_plate': 1, 'seal_shard': 6}, 'ballast': {'thunder_ore': 6, 'ember_crystal': 4},
        'once': {'banyo_scale': 4}},
    5: {'wood': {'reinforced_lumber': 30, 'waterlogged_plank': 20, 'meokbi_ebony': 10}, 'sail': {'moonless_silk': 15, 'spirit_thread': 20, 'bleached_lantern_paper': 10},
        'iron': {'steel_ingot': 20, 'frost_bell_iron': 10, 'frozen_arrow_shaft': 10}, 'seal': {'reinforced_leather': 10, 'red_shrine_lacquer': 10, 'burrow_scale': 6},
        'guide': {'star_record_plate': 6, 'faded_star_glass': 6, 'balance_weight': 6, 'erased_plate': 10}, 'ballast': {'pact_stone_dust': 30, 'king_ember_ash': 10},
        'once': {'spirit_core': 5}},
}
PART_MUL = {2: 1, 3: 1.5, 4: 2.5, 5: 3.5}


def parts():
    out = {}
    for t, cats in PART_BASE.items():
        out[str(t)] = {k: {i: (n if k == 'once' else math.ceil(n * PART_MUL[t])) for i, n in v.items()} for k, v in cats.items()}
    return out


def rules():
    return {
        'ports': {p: dict(region=p, name=n, dock=d, shipyard=y, realm=rm, sea=s, good=next(g[0] for g in GOODS if g[2] == p)) for p, n, d, y, rm, s in PORTS},
        'routes': routes(),
        'cross': [[a, b] for a, b, _ in CROSS],
        'ships': SHIPS,
        'parts': parts(),
        'part_names': PART_NAMES,
        'part_xp': {'line': 'carpentry', 'per': 2, 'cap': 40},
        'goods': {g[0]: dict(name=g[1], port=g[2], base=g[3], want=g[4]) for g in GOODS},
        'price': {'origin': 0.7, 'normal': 1.0, 'want': 1.3, 'far': 1.5, 'wobble': 0.1,
                  'seek': {'mul': 1.2, 'n': 2, 'days': 3}, 'event': {'mul': 1.3, 'names': ['잔치', '흉년', '큰 장', '제사']},
                  'flow': {'per': 0.002, 'min': 0.6, 'hours': 24}, 'hot': 0.95},
        'slot_n': 10,
        'day_cap': 3000,
        'sail': {'direct_div': 4, 'tokens': 2, 'send_mul': 0.8, 'board_s': 60},
        'bonus': {'time': {'per': 5, 'name': '물길 줄이기'}, 'guard': {'per': 15, 'name': '함께 막기'}, 'haggle': {'per': 2, 'name': '함께 흥정'}, 'max_mates': 3},
        'raid': {'p': 10, 'p_far': 15, 'far_min': 180, 'robber': 0.34, 'lose_pct': 20, 'send_lose': [10, 20], 'lv_up': 1, 'robber_id': ROBBER[0]},
        'dur': {'voyage': 2, 'raid': 10, 'repair_gil': 2},
        'name_max': 12,
    }
