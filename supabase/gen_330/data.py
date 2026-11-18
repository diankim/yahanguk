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


def rules():
    r = dict(RULES)
    r['npcs'] = {
        n['k']: dict(key='rg_' + n['k'], name=n['name'], short=n['short'], line=n['line'], region=n['region'], open='rg_' + n['k'] + '_1',
                     lv=n['lv'], title='rg_' + n['k'], title_name=n['title'], reward=n['reward'], sort=i + 1)
        for i, n in enumerate(NPCS)}
    return r
