import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'realm_bond'))
import vault_rb as VRB

NAMES = {'main': '본토', 'hanul': '건넛누리'}
DEFAULT = 'main'
BOSS_MOUNTS = ['dh_wave_skiff']
STABLE = [
    ('hn_fin_pony', '물갈퀴 망아지', 'pado', 1.6, 1, 1, 50, 1500, '일반', {},
     '발굽 사이에 물갈퀴가 돋은 파도너울성의 망아지. 장대 다리 사이 얕은 물도 첨벙첨벙 건너, 틈을 막 건너온 손님이 처음 들이는 탈것이다.'),
    ('hn_ash_mule', '잿빛 노새 수레', 'bulssi', 2.0, 3, 2, 51, 6000, '고급', {},
     '재를 뒤집어쓴 듯 잿빛 털의 노새가 끄는 화덕골 수레. 뜨거운 비탈 자갈길에도 바퀴를 헛돌리지 않고 셋을 싣는다.'),
    ('hn_reed_buffalo', '억새 물소', 'jaebit', 2.0, 3, 2, 52, 6000, '고급', {},
     '억새 나루 뱃사람이 기르는 물소. 먹빛 강 얕은 여울은 그대로 건너고, 등에 억새 방석을 깔아 셋을 태운다.'),
    ('hn_flag_goat', '깃발 털염소', 'nunmaru', 2.1, 2, 1, 53, 8000, '희귀', {},
     '뿔에 작은 깃발을 매단 눈마루의 털염소. 깎아지른 돌계단도 깡충깡충 올라 눈 쌓인 등성이를 둘이서 넘는다.'),
    ('hn_gold_coach', '금테 마차', 'dalmaji', 2.3, 4, 2, 54, 15000, '영물', {'red_spice_pod': 3, 'pooled_light_shard': 3},
     '바퀴에 금테를 두른 달맞이성의 마차. 보름 장날 수로 다리 위를 덜컹대며 넷을 싣고 달린다.'),
    ('hn_lotus_goose', '연밥 큰 거위', 'haeoreum', 2.3, 3, 1, 55, 15000, '영물', {'lotus_seed': 3, 'dawn_scale': 3},
     '연밥을 먹고 자라 사람 키만큼 커진 해오름성의 거위. 연밥 둑 물길을 미끄러지듯 헤엄쳐 셋을 태운다.'),
]


def emit(D, J, errors, fresh=None, known=None):
    hubs = D.HUB
    regions = {r['id']: r for r in D.REGIONS}
    hanul = {mid: 'hanul' for mid, *_ in STABLE}
    for k in VRB.MOUNTS:
        hanul['rb_mount_' + k] = 'hanul'
    for k in BOSS_MOUNTS:
        hanul[k] = 'hanul'
    rows, mats = [], {}
    for mid, nm, realm, speed, seats, fare, lv, price, tier, m, desc in STABLE:
        reg = hubs.get(realm)
        if reg not in regions or not regions[reg].get('safe'):
            errors.append(f'건넛누리 마구간 {mid}: 들이는 곳 {reg}이 그 권역 안전지대가 아님')
        if regions.get(reg, {}).get('terr') != realm:
            errors.append(f'건넛누리 마구간 {mid}: {reg}이 {realm} 권역이 아님')
        for it in m:
            if known is not None and it not in known:
                errors.append(f'건넛누리 마구간 {mid}: 재료 없음 {it}')
        if m:
            mats[mid] = m
        rows.append(dict(mount_id=mid, mount_name=nm, speed_multiplier=speed, unlock_level=lv, unlock_region=reg, description=desc, tier=tier,
                         passenger_capacity=seats, fare_tokens=fare, price=price))
    if len({r['mount_name'] for r in rows} | {v[0] for v in VRB.MOUNTS.values()}) != len(rows) + len(VRB.MOUNTS):
        errors.append('건넛누리 탈것 이름 겹침')
    if D.REALM != 'hanul':
        errors.append('땅 이름표가 hanul이 아님: ' + D.REALM)
    rules = {'default': DEFAULT, 'names': NAMES, 'mounts': hanul, 'mats': mats}
    eng = open(os.path.join(HERE, 'engine.sql'), encoding='utf-8').read()
    hubs_sql = ', '.join(f"'{hubs[r[2]]}'" for r in STABLE)
    return eng.replace('%%RULES%%', J(rules)).replace('%%ROWS%%', J(rows)).replace('%%HUBS%%', hubs_sql)
