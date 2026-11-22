import importlib.util as _iu, os as _os

_HERE = _os.path.dirname(_os.path.abspath(__file__))
_sp = _iu.spec_from_file_location('rd330', _os.path.join(_os.path.dirname(_HERE), 'gen_330', 'data.py'))
OLD = _iu.module_from_spec(_sp)
_sp.loader.exec_module(OLD)

COMBAT = {
    'kill': 5,
    'act': {'analysis': ['analysis', 8], 'guarding': ['guarding', 8], 'first_aid': ['first_aid', 5], 'job': ['win', 8]},
    'item': {'analysis': ['loot', 3], 'guarding': ['armor', 1], 'first_aid': ['heal', 3], 'job': ['weapon', 3]},
    'armor': ['armor', 'hat', 'shoes'],
    'gil_n': 3,
    'act_name': {'analysis': '수법 낌새에 맞서기', 'guarding': '방어', 'first_aid': '회복품·처치', 'win': '이긴 토벌'},
}

NPCS = [
    dict(k='mogaram', name='기록관 모가람', short='모가람', line='analysis', region='hq_dorm', after=['mdq_1'], lv=45,
         title='「기록관의 대필」', reward='식은 보리차 상'),
    dict(k='yeonseohui', name='서기관 연서희', short='연서희', line='first_aid', region='hq_yard', after=['mq_nine_gates'], lv=30,
         title='「서희가 기다리는 사람」', reward='서당 약상자'),
    dict(k='kangducheol', name='교관 강두철', short='강두철', line='guarding', region='iron_monastery', after=['sq_hq_training_1'], lv=9,
         title='「연무청 기둥에 새긴 이름」', reward='수련 목인'),
    dict(k='yeoseotjjae', name='채무 추적자 여섯째', short='여섯째', line='job', line_label='직업 전투', region='hidden_bazaar', after=['mdq_17'], lv=50,
         title='「숫자 대신 부른 이름」', reward='검은 두건'),
]

MILESTONES = [
    dict(key='rg_all15', name='「열다섯 연담」', n=15, grade=5, desc='연담을 맺은 열다섯 사람과 친밀도가 가장 높은 단계에 닿았다.'),
]
OLD_FIX = {'rg_all': '연담을 맺은 열한 사람과 친밀도가 가장 높은 단계에 닿았다.'}

TITLE_DESC = {
    'mogaram': '두 손이 굳은 기록관의 요괴 버릇 기록, 지은이 칸 옆에 적힌 대필.',
    'yeonseohui': '나가는 사람 이름만 적던 서기관이 처음으로 기다리는 사람 칸에 적은 이름.',
    'kangducheol': '연무청 기둥, 부순 목인 수 옆에 새로 그은 금 밑에 새긴 이름.',
    'yeoseotjjae': '셀 줄만 알던 채무 추적자가 숫자 대신 처음 부른 이름.',
}

REWARDS = {
    'mogaram': {'title': ('rg_mogaram', '「기록관의 대필」'), 'item': ('hf_rg_mogaram_tea', '식은 보리차 상', '좌석·탁자',
        '모가람이 객사 창가에 두는 낮은 상입니다. 펼친 기록 옆에 식은 보리차 두 잔이 놓여 있습니다.', {'hk': 'rg_mogaram_tea', 'kind': 'floor', 'w': 1, 'd': 1, 'top': 0.36})},
    'yeonseohui': {'title': ('rg_yeonseohui', '「서희가 기다리는 사람」'), 'item': ('hf_rg_yeonseohui_kit', '서당 약상자', '수납',
        '정청 서당 처마 밑에 두던 붉은 약상자입니다. 서랍마다 붕대와 약이 가지런히 들어 있습니다.', {'hk': 'rg_yeonseohui_kit', 'kind': 'floor', 'w': 1, 'd': 1, 'top': 0.7})},
    'kangducheol': {'title': ('rg_kangducheol', '「연무청 기둥에 새긴 이름」'), 'item': ('hf_rg_kangducheol_dummy', '수련 목인', '장식',
        '강두철이 수련생과 쓰던 목인입니다. 몸통에 금이 여러 줄 그어져 있고, 머리에 푸른 끈이 묶여 있습니다.', {'hk': 'rg_kangducheol_dummy', 'kind': 'floor', 'w': 1, 'd': 1, 'top': 0})},
    'yeoseotjjae': {'title': ('rg_yeoseotjjae', '「숫자 대신 부른 이름」'), 'item': ('of_acc_rg_yeoseotjjae_veil', '검은 두건', '장신구',
        '흑련 채무 추적자가 얼굴 아래를 가리던 검은 천과 같은 두건입니다.', {'look': 'acc:rg_yeoseotjjae_veil'})},
}
for _n in NPCS:
    _n['title_desc'] = TITLE_DESC[_n['k']]

ALL = OLD.NPCS + NPCS


def rules():
    r = OLD.rules()
    r['combat'] = COMBAT
    r['npcs'] = {}
    for i, n in enumerate(ALL):
        e = dict(key='rg_' + n['k'], name=n['name'], short=n['short'], line=n['line'], region=n['region'], open='rg_' + n['k'] + '_1',
                 lv=n['lv'], title='rg_' + n['k'], title_name=n['title'], reward=n['reward'], sort=i + 1)
        if n['line'] in COMBAT['act']:
            e['kind'] = 'combat'
        if n.get('line_label'):
            e['line_label'] = n['line_label']
        r['npcs'][n['k']] = e
    return r
