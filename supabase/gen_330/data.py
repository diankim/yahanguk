RULES = {
    'day_n': 6,
    'orders': 3,
    'span': 12,
    'aff': {'give': 10, 'hq': 15, 'cap': 420, 'stages': [0, 60, 150, 270, 420]},
    'xp': {'pct': 25, 'min': 30, 'hq_mul': 1.5},
    'gil': {'rate': 0.3, 'base': 30},
    'qty': {'gear': 1, 'item': 3, 'gather': 10, 'fish': 3},
    'gear': ['weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool'],
    'lines': {'foraging': ['herbs', 'wood', 'supplies', 'water', 'spirit'], 'mining': ['ore', 'relics']},
}

NPCS = [
    dict(k='hanseol', name='감찰관 한설', short='한설', line='wardcraft', region='lantern_market', after=['mq_lamp_shadow'], lv=27,
         title='「감찰관의 예외」', reward='예외 공문 족자'),
    dict(k='yeoul', name='여울', short='여울', line='mining', region='banyo_village', after=['gq_1'], lv=30,
         title='「여울이 맞이한 사람」', reward='맞이 등'),
    dict(k='wolha', name='월하', short='월하', line='alchemy', region='hidden_bazaar', after=['mkq_1'], lv=40,
         title='「월하가 부르는 이름」', reward='귀퉁이 엽전 끈'),
    dict(k='daon', name='다온', short='다온', line='foraging', region='mukchang_ferry', after=['mkq_1'], lv=40,
         title='「다온의 꿀물 친구」', reward='풀꽃 반지'),
    dict(k='hisu', name='서리 희수', short='희수', line='weaving', region='hq_yard', after=['mkq_1'], lv=40,
         title='「희수가 적은 이름」', reward='출납 서리 겉옷'),
    dict(k='danbi', name='단비', short='단비', line='cooking', region='bone_market', after=['mde_danbi_2'], lv=50,
         title='「단비의 엿 반쪽」', reward='단비네 엿판'),
    dict(k='unbi', name='호송대장 여운비', short='여운비', line='leatherwork', region='iron_monastery', after=['mde_unbi_2'], lv=50,
         title='「여운비의 눈길 동무」', reward='호송대 눈길 망토'),
    dict(k='cheongpa', name='청파', short='청파', line='fishing', region='river_ferry', after=['mde_cheongpa_2'], lv=50,
         title='「청파의 생명줄 당번」', reward='생명줄 감개'),
    dict(k='galmae', name='정찰대장 갈매', short='갈매', line='smithing', region='ember_village', after=['mde_galmae_2'], lv=50,
         title='「갈매가 맡긴 등」', reward='쌍 칼걸이'),
    dict(k='haram', name='관측관 서하람', short='서하람', line='artifice', region='star_observatory', after=['mde_haram_2'], lv=50,
         title='「하람의 관측 대상」', reward='관측 담요 의자'),
    dict(k='munsu', name='서리 문수', short='문수', line='carpentry', region='deungdo_landing', after=['mdq_17'], lv=50,
         title='「문수의 수다 상대」', reward='수다 걸상 한 쌍'),
]

MILESTONES = [
    dict(key='rg_one', name='「첫 연담」', n=1, grade=2, desc='연담을 맺은 한 사람과 친밀도가 가장 높은 단계에 닿았다.'),
    dict(key='rg_five', name='「다섯 연담」', n=5, grade=3, desc='연담을 맺은 다섯 사람과 친밀도가 가장 높은 단계에 닿았다.'),
    dict(key='rg_all', name='「열한 연담」', n=11, grade=4, desc='연담을 맺은 열한 사람 모두와 친밀도가 가장 높은 단계에 닿았다.'),
]


TITLE_DESC = {
    'hanseol': '규정밖에 모르는 감찰관이 수첩 마지막 쪽에 손글씨로 적은 단 한 사람의 예외.',
    'yeoul': '배웅 노래밖에 없던 섬이 처음으로 맞이 노래의 첫 줄에 넣은 이름.',
    'wolha': '값을 매기지 않고, 아무 때나 불러도 되는 이름.',
    'daon': '꿀물은 한 잔을 나눠 마시는 거라던 아이가 두 잔을 다 내준 사람.',
    'hisu': '반듯한 글씨로, 처음부터 끝까지 다 적은 이름.',
    'danbi': '기분이 무너지면 안 먹는 엿을 반으로 꺾어 오른손에 쥐여 준 사람.',
    'unbi': '오른 눈을 잃은 호송대장의 길 장부, 오른쪽 칸에 적힌 길동무.',
    'cheongpa': '다시 물에 드는 잠수꾼의 허리 줄 끝을 맡은 사람. 바꾸면 안 된다.',
    'galmae': '늘 등 뒤에 사람을 두지 않던 정찰대장이 처음으로 등을 맡긴 사람.',
    'haram': '별을 못 보게 된 관측관이 관측 대상 명부에 적은 이름.',
    'munsu': '혼자 있으면 무섭다던 서리가 걸상 하나를 더 짜 놓은 자리.',
}

REWARDS = {
    'hanseol': {'title': ('rg_hanseol', '「감찰관의 예외」'), 'item': ('hf_rg_hanseol_scroll', '예외 공문 족자', '족자',
        '결재 칸에 도장 대신 한설의 손글씨 한 줄이 들어간 공문을 족자로 꾸몄습니다.', {'hk': 'rg_hanseol_scroll', 'kind': 'wall', 'wall': 'deco', 'ww': 1.1, 'wh': 34})},
    'yeoul': {'title': ('rg_yeoul', '「여울이 맞이한 사람」'), 'item': ('hf_rg_yeoul_lamp', '맞이 등', '조명',
        '반요촌 문간에 처음 건 맞이 등과 같은 모양입니다. 배웅 등과 달리 따뜻한 빛이 납니다.', {'hk': 'rg_yeoul_lamp', 'kind': 'floor', 'w': 1, 'd': 1, 'top': 0})},
    'wolha': {'title': ('rg_wolha', '「월하가 부르는 이름」'), 'item': ('of_acc_rg_wolha_coin', '귀퉁이 엽전 끈', '장신구',
        '귀퉁이가 빠진 상평통보를 꿴 손목끈입니다. 월하가 엽전을 튕기던 버릇을 닮았습니다.', {'look': 'acc:rg_wolha_coin'})},
    'daon': {'title': ('rg_daon', '「다온의 꿀물 친구」'), 'item': ('of_acc_rg_daon_ring', '풀꽃 반지', '장신구',
        '다온이 둘만 아는 갯가 풀밭에서 꺾어 엮어 준 풀꽃 반지입니다.', {'look': 'acc:rg_daon_ring'})},
    'hisu': {'title': ('rg_hisu', '「희수가 적은 이름」'), 'item': ('of_top_rg_hisu_coat', '출납 서리 겉옷', '옷',
        '희수가 해진 소매를 꿰매 준 겉옷입니다. 소매 안쪽에 내 이름이 반듯하게 수놓여 있습니다.', {'look': 'top:rg_hisu_coat'})},
    'danbi': {'title': ('rg_danbi', '「단비의 엿 반쪽」'), 'item': ('hf_rg_danbi_stall', '단비네 엿판', '좌석·탁자',
        '백골 장터 「단비네」 엿판을 닮은 판입니다. 반으로 꺾인 엿 하나가 올려져 있습니다.', {'hk': 'rg_danbi_stall', 'kind': 'floor', 'w': 2, 'd': 1, 'top': 0.56})},
    'unbi': {'title': ('rg_unbi', '「여운비의 눈길 동무」'), 'item': ('of_top_rg_unbi_cape', '호송대 눈길 망토', '옷',
        '북령 호송대가 길동무에게 지어 주는 털 망토입니다. 가슴에 붉은 술이 달렸습니다.', {'look': 'top:rg_unbi_cape'})},
    'cheongpa': {'title': ('rg_cheongpa', '「청파의 생명줄 당번」'), 'item': ('hf_rg_cheongpa_reel', '생명줄 감개', '장식',
        '수향 잠수꾼의 생명줄을 감는 감개입니다. 줄 끝에 식구 매듭 하나가 남아 있습니다.', {'hk': 'rg_cheongpa_reel', 'kind': 'floor', 'w': 1, 'd': 1, 'top': 0})},
    'galmae': {'title': ('rg_galmae', '「갈매가 맡긴 등」'), 'item': ('hf_rg_galmae_rack', '쌍 칼걸이', '장식',
        '고리 둘 달린 칼걸이입니다. 한쪽에는 갈매의 칼이, 한쪽에는 내 무기가 걸립니다.', {'hk': 'rg_galmae_rack', 'kind': 'floor', 'w': 1, 'd': 1, 'top': 0})},
    'haram': {'title': ('rg_haram', '「하람의 관측 대상」'), 'item': ('hf_rg_haram_chair', '관측 담요 의자', '좌석·탁자',
        '관성대 지붕에서 쓰던 낮은 관측 의자에 별 무늬 담요를 걸쳤습니다.', {'hk': 'rg_haram_chair', 'kind': 'floor', 'w': 1, 'd': 1, 'top': 0.3, 'pet': 'bed'})},
    'munsu': {'title': ('rg_munsu', '「문수의 수다 상대」'), 'item': ('hf_rg_munsu_stools', '수다 걸상 한 쌍', '좌석·탁자',
        '남문 수로 선착에 문수가 하나 더 짜 놓은 걸상까지 둘입니다. 둘 사이에 찻잔이 놓여 있습니다.', {'hk': 'rg_munsu_stools', 'kind': 'floor', 'w': 2, 'd': 1, 'top': 0.34, 'pet': 'bed'})},
}
for _n in NPCS:
    _n['title_desc'] = TITLE_DESC[_n['k']]

def rules():
    r = dict(RULES)
    r['npcs'] = {
        n['k']: dict(key='rg_' + n['k'], name=n['name'], short=n['short'], line=n['line'], region=n['region'], open='rg_' + n['k'] + '_1',
                     lv=n['lv'], title='rg_' + n['k'], title_name=n['title'], reward=n['reward'], sort=i + 1)
        for i, n in enumerate(NPCS)}
    return r
