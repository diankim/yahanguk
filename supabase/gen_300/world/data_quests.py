import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, '..', 'script5_all.md')
REF = os.path.join(HERE, 'ref', 'quest_ref.json')
CAT = '외전·명등기'

FACTIONS = {'정통파': 'night_office', '적월': 'red_moon_cult', '흑련': 'black_lotus', '북령': 'north_league',
            '수향': 'river_alliance', '남명': 'southern_remnant', '천명': 'mandate_court'}

SPEAK = {
    '서술': None,
    '한설': 'night_office:han', '한설(서신)': 'night_office:han',
    '모가람': 'night_office:mo', '백운서': 'night_office:baek',
    '문수': 'q:dh_munsu', '희수': 'q:mk_hisu', '다온': 'q:mk_daon', '다온(서신)': 'q:mk_daon', '월하': 'q:mk_wolha',
    '윤도한': 'q:m_yun', '연서희': 'q:m_yeon',
    '무명': 'black_lotus:mumyeong', '구슬': 'black_lotus:guseul', '여섯째': 'black_lotus:six',
    '석진악': 'north_league:seok', '혜각': 'north_league:hyegak', '여운비': 'north_league:yeo',
    '월화': 'red_moon_cult:wolhwa', '사마겸': 'red_moon_cult:sama', '단비': 'red_moon_cult:danbi',
    '진소랑': 'river_alliance:jin', '매향': 'river_alliance:maehyang', '노들 영감': 'river_alliance:nodeul', '청파': 'q:sn_cheongpa',
    '장무현': 'southern_remnant:jang', '소이': 'southern_remnant:soi', '갈매': 'southern_remnant:galmae',
    '하후정': 'mandate_court:hahu', '서이연': 'mandate_court:seo', '서하람': 'q:r71_seoharam',
    '경현': 'q:md_gyeonghyeon', '경현(서신)': 'q:md_gyeonghyeon',
    '곽두칠': 'q:md_gwak_duchil',
    '두건 쓴 사람': 'q:md_hooded',
    '정청 서리': 'q:md_clerk',
    '정청 파발꾼': 'q:md_courier',
    '심부름꾼': 'q:md_runner',
    '적월 심부름꾼': 'q:md_red_runner',
    '흑련 심부름꾼': 'q:md_lotus_runner',
    '남명 심부름꾼': 'q:md_south_runner',
    '객사 의원': 'q:md_dorm_doctor',
    '적월 의원': 'q:md_red_doctor',
    '수향 의원': 'q:md_river_doctor',
    '썰매꾼': 'q:md_sledder',
    '산문 지기': 'q:md_gatekeeper',
    '봉인고 문지기': 'q:md_vault_guard',
    '문패 집 아낙': 'q:md_plate_wife',
    '남명 파수꾼': 'q:md_south_watch',
    '아이': 'q:md_child',
}

NPCS = {
    'q:md_gyeonghyeon': ('정리관 경현', '정청 정리소의 정리관. 공손하고 느긋한 말투에 비꼬는 농담을 섞는다. 말하면서 장부 모서리를 접는 버릇이 있다.'),
    'q:md_gwak_duchil': ('곽두칠', '열 해 전 흑련회에 빚을 지고 사라진 사람. 정리 명부에 이름이 올라 줄이 반만 그어진 채 먹손이 되었다.'),
    'q:md_hooded': ('두건 쓴 사람', '무관 거리 우물가에서 일행의 뒤를 밟던 그림자 흐린 사람. 누군가 쥔 제 줄이 마저 그어질까 떤다.'),
    'q:md_clerk': ('불 끄는 젊은 서리', '장서각에 불이 난 밤, 정청 마당에서 물동이를 나르며 소리치던 젊은 서리.'),
    'q:md_courier': ('정청 파발꾼', '한설의 서신을 품고 사흘을 따라온 정청 파발꾼.'),
    'q:md_runner': ('먼 길 심부름꾼', '서신과 등짐을 지고 거점 사이를 뛰어다니는 심부름꾼.'),
    'q:md_red_runner': ('적월 심부름꾼', '백골 장터와 적월 사람들 사이를 오가는 심부름꾼.'),
    'q:md_lotus_runner': ('흑련 심부름꾼', '검은 끈을 손목에 맨 흑련회 심부름꾼. 장부고의 말을 전한다.'),
    'q:md_south_runner': ('남명 심부름꾼', '잔불촌 화로의 소식을 전하는 남명 심부름꾼.'),
    'q:md_dorm_doctor': ('객사 의원', '본부 객사에서 불에 덴 사람들을 돌보는 의원.'),
    'q:md_red_doctor': ('적월 의원', '백골 장터에서 무녀들을 돌보는 적월 의원.'),
    'q:md_river_doctor': ('수향 의원', '구름나루에서 물에 빠진 사람과 물에 홀린 사람을 돌보는 수향 의원.'),
    'q:md_sledder': ('북령 썰매꾼', '여운비의 호송대를 따라 눈 고개를 넘는 북령 썰매꾼.'),
    'q:md_gatekeeper': ('철벽 고찰 산문 지기', '철벽 고찰 산문을 지키는 젊은 지기.'),
    'q:md_vault_guard': ('봉인고 문지기', '봉인고 창고 문을 지키는 문지기. 정청에서 온 서신을 조사원에게 건넨다.'),
    'q:md_plate_wife': ('문패 집 아낙', '구름나루 선창가에 사는 아낙. 사흘 전 아들을 물에 잃었다.'),
    'q:md_south_watch': ('잔불촌 파수꾼', '불씨 고개를 바라보며 잔불촌 어귀를 지키는 남명 파수꾼.'),
    'q:md_child': ('잔불촌 아이', '잔불촌 뒷산 밭에서 뛰어 내려온 아이.'),
}

NEW_ITEMS = [
    ('plank_water_jar', '뱃판 물동이', 'carpentry', {'waterlogged_plank': 2, 'resin': 1}, 3,
     '옛 나루 저자의 물 먹은 뱃판으로 짜고 진흙으로 틈을 메운 나무 동이다. 쇠 냄새가 배지 않아 물이 쉬 흐려지지 않는다.'),
    ('md_litter', '들것', 'carpentry', {'lumber': 2, 'talisman_thread': 2}, 1,
     '가공 부적목 두 대에 부적실을 촘촘히 엮어 만든 들것이다. 사람 하나를 눕혀 둘이 들고 먼 길을 갈 수 있다.'),
]

SPECIAL_TASKS = {'gg': '값귀(귀허 엔진 넷째 갈래 boss_id gapgwi) — 8장', 'by': '백야(맹약 마당 우두머리) — 16장'}

HQ, DORM, ARCH = 'hq_yard', 'hq_dorm', 'hq_archive'
LEDGER, ROOT = 'ledger_cellar', 'under_root'
IRON, SNOW, PINE, PLAIN, BONE = 'iron_monastery', 'snow_hollow', 'frost_pine_pass', 'red_plain', 'bone_market'
RIVER, MARSH, EMBERV, EMBERP, OBS, WTOWER, VAULT = 'river_ferry', 'lotus_marsh', 'ember_village', 'ember_pass', 'star_observatory', 'white_tower', 'seal_vault'
YAMEN, MARTIAL, SHRINE, OFM, FOBS, PALACE, PACT, JEONGNI = 'dark_yamen', 'martial_row', 'red_shrine_lane', 'old_ferry_market', 'first_observatory', 'ash_palace', 'pact_court', 'jeongni_vault'
FIELD, ABYSS = 'field_outskirts', 'sealed_abyss'


def tv(r):
    return {'t': 'travel', 'r': [r], 'n': 1}


def sr(r, n):
    return {'t': 'search', 'r': [r], 'n': n}


def cl(r, n):
    return {'t': 'clue', 'r': [r], 'n': n}


def rs(r):
    return {'t': 'rest', 'r': [r], 'n': 1}


def ga(r, n, items=None):
    t = {'t': 'gather', 'n': n}
    if items:
        t['items'] = items
    if r:
        t['r'] = [r]
    return t


def fi(r, n):
    t = {'t': 'fish', 'n': n}
    if r:
        t['r'] = [r]
    return t


def wi(n, r=None, m=None):
    t = {'t': 'win', 'n': n}
    if m:
        t['m'] = m
    if r:
        t['r'] = [r]
    return t


def ex(r):
    return {'t': 'expedition', 'r': [r], 'n': 1}


def cr(item, n):
    return {'t': 'craft', 'items': [item], 'n': n}


def idle(k, mins):
    return {'t': 'idle', 'k': k, 'min': mins, 'n': 1}


def nd(at, *tasks, give=None):
    need = {'at': [at]}
    if tasks:
        need['tasks'] = list(tasks)
    g = dict(give or {})
    for t in tasks:
        if t['t'] == 'craft':
            g.setdefault(t['items'][0], t['n'])
    if g:
        need['give'] = g
    return need


def nd_nogive(at, *tasks, give=None):
    need = {'at': [at]}
    if tasks:
        need['tasks'] = list(tasks)
    if give:
        need['give'] = dict(give)
    return need


PLAN = {
    1: dict(L=45, region=ARCH, after=['mkq_5'], items={'night_tea': 2, 'revival_charm': 2}, steps=[
        ('본부 정청 마당에서 비상 종소리를 듣는다', nd(HQ)),
        ('장서각 지하서고에 도착해 연기 속을 2번 탐색하며 봉인 서가로 가는 길을 찾는다', nd(ARCH, tv(ARCH), sr(ARCH, 2))),
        ('야령초 6개를 모아 농축 약초액 2개를 만들고 본부 객사의 의원에게 넘긴다', nd(DORM, ga(None, 6, ['herb']), cr('herbal_extract', 2))),
        ('장서각 지하서고를 4번 탐색해 재 속의 젖은 발자국과 타다 남은 종이를 찾는다', nd(ARCH, sr(ARCH, 4))),
        ('장서각 지하서고 끝 우물에서 1번 낚시해 물을 떠 본다', nd(ARCH, fi(ARCH, 1))),
        ('정화 부적 2장을 만들어 우물물 병을 봉하고 본부 정청에 도착한다', nd(HQ, cr('ward_talisman', 2), tv(HQ))),
        ('월광 이끼죽 1그릇을 쑤어 본부 객사의 모가람에게 넘긴다', nd(DORM, cr('moss_porridge', 1), tv(DORM))),
    ]),
    2: dict(L=45, region=LEDGER, after=['mdq_1'], items={'ledger_tab': 2, 'moonlight_essence': 2}, steps=[
        ('흑련 장부고에 도착해 월하와 다온을 만난다', nd(LEDGER, tv(LEDGER))),
        ('흑련 장부고에서 쉬며 다온 곁에서 밤을 지킨다', nd(LEDGER, rs(LEDGER))),
        ('물고기를 2번 낚아 어죽 2그릇을 쑤고, 꿀 약과 2개와 함께 흑련 장부고의 다온에게 넘긴다', nd(LEDGER, fi(None, 2), cr('fish_porridge', 2), give={'treat_honey': 2})),
        ('흑련 장부고 금고 계단에서 부르다 굳은 넋을 3번 풀어 보낸다', nd(LEDGER, wi(3, r=LEDGER, m=['dd_yamen_1']))),
        ('지맥의 뿌리에 도착해 물길을 막은 현판 아래 문지기를 쓰러뜨리고, 2번 탐색하며 실마리를 찾아 흑련 장부고로 돌아간다', nd(LEDGER, tv(ROOT), wi(1, r=ROOT, m=['dd_yamen_5']), cl(ROOT, 2))),
        ('지맥의 뿌리로 원정을 한 번 끝까지 다녀와 먹 물길이 끝나는 곳을 살핀다', nd(LEDGER, ex(ROOT))),
        ('먼 길 채비로 노정 건량 4개를 만들어 흑련 장부고에서 넘긴다', nd(LEDGER, cr('travel_ration', 4))),
    ]),
    3: dict(L=45, region=IRON, after=['mdq_2'], items={'heavenly_dew': 1, 'ward_talisman': 4}, steps=[
        ('철벽 고찰에 도착해 무너지는 눈 소리를 듣는다', nd(IRON, tv(IRON))),
        ('설피골에 도착해 썰매 길을 막은 바랜 등롱 나방을 4번 쫓아낸다', nd(SNOW, tv(SNOW), wi(4, r=SNOW, m=['dd_yamen_2']))),
        ('설피골에서 눈 굴 야영으로 쉬고, 설피골 원정을 끝까지 다녀와 철벽 고찰에 도착한다', nd(IRON, rs(SNOW), ex(SNOW), tv(IRON))),
        ('철벽 고찰에서 저녁 공양을 들고 쉰다', nd(IRON, rs(IRON))),
        ('설피골에서 6번 채집하고 적사 황무지에 도착해 야영으로 쉰다', nd(PLAIN, ga(SNOW, 6), tv(PLAIN), rs(PLAIN))),
        ('적사 황무지 새벽 길목에서 부르다 굳은 넋을 3번 풀어 보내고 백골 장터에 도착한다', nd(BONE, wi(3, r=PLAIN, m=['dd_yamen_1']), tv(BONE))),
        ('정화 부적 4장을 만들어 백골 장터의 단비에게 넘긴다', nd(BONE, cr('ward_talisman', 4))),
        ('적사 황무지 사당에 들러붙은 서식 긁는 손톱귀를 4번 쫓아내고 백골 장터에 도착한다', nd(BONE, wi(4, r=PLAIN, m=['dd_yamen_3']), tv(BONE))),
    ]),
    4: dict(L=45, region=RIVER, after=['mdq_3'], items={'grand_pill': 1, 'spirit_core': 2}, steps=[
        ('구름나루에 도착해 물 위의 장부방을 찾는다', nd(RIVER, tv(RIVER))),
        ('구름나루에서 3번 낚시하며 물 밑 청파의 줄을 잡아 준다', nd(RIVER, fi(RIVER, 3))),
        ('구름나루에서 3번 낚시하고 생선구이 4마리를 구워 청파에게 넘긴다', nd(RIVER, fi(RIVER, 3), cr('grilled_fish', 4))),
        ('잔불촌에 도착하고, 불씨 고개를 2번 탐색해 마을 어귀를 살핀다', nd(EMBERV, tv(EMBERV), sr(EMBERP, 2))),
        ('불씨 고개에 도착해 갈매와 국경을 정찰하며 종소리 먹은 늑대를 5번 쓰러뜨린다', nd(EMBERP, tv(EMBERP), wi(5, r=EMBERP, m=['dd_martial_4']))),
        ('불씨 고개에서 야영으로 쉬고 잔불촌에 도착한다', nd(EMBERV, rs(EMBERP), tv(EMBERV))),
        ('불씨 고개에서 4번 채집해 땔감을 챙기고 무극 관성대에 도착한다', nd(OBS, ga(EMBERP, 4), tv(OBS))),
        ('자율 활동 「자료 조사」를 1시간 넘게 끝까지 하며 서하람과 별을 받아 적는다', nd(OBS, idle('research', 60))),
        ('봉인고에 도착해 2번 탐색하며 압수물 창고를 찾는다', nd(VAULT, tv(VAULT), sr(VAULT, 2))),
    ]),
    5: dict(L=45, region=YAMEN, after=['mdq_4'], items={'century_form_scrap': 2, 'bleached_lantern_paper': 2}, steps=[
        ('봉인고에서 다섯이 함께 첫 밤을 쉬고 식은 찻잔을 앞에 둔다', nd(VAULT, rs(VAULT))),
        ('부적목 6개를 모아 가공 부적목 3개를 만들고 봉인고에서 청파에게 넘긴다', nd(VAULT, ga(None, 6, ['wood']), cr('lumber', 3))),
        ('꺼진 관아 터에 도착해 3번 탐색한다', nd(YAMEN, tv(YAMEN), sr(YAMEN, 3))),
        ('꺼진 관아 터에서 4번 채집하고 영맥 약선탕 1그릇을 끓여 첫 저녁으로 넘긴다', nd(YAMEN, ga(YAMEN, 4), cr('bark_stew', 1))),
        ('꺼진 관아 터에서 첫 야영으로 쉰다', nd(YAMEN, rs(YAMEN))),
        ('꺼진 관아 터에서 부르다 굳은 넋을 5번 풀어 보낸다', nd(YAMEN, wi(5, m=['dd_yamen_1']))),
        ('꺼진 관아 터로 원정을 한 번 끝까지 다녀와 북쪽 길을 살핀다', nd(YAMEN, ex(YAMEN))),
    ]),
    6: dict(L=46, region=MARTIAL, after=['mdq_5'], items={'frozen_arrow_shaft': 2, 'frost_bell_iron': 1}, steps=[
        ('꺼진 관아 터에서 쉬고 무관 거리에 도착해 늘어진 술을 본다', nd(MARTIAL, rs(YAMEN), tv(MARTIAL))),
        ('무관 거리를 4번 탐색하고 요괴를 3번 쓰러뜨린다', nd(MARTIAL, sr(MARTIAL, 4), wi(3, r=MARTIAL))),
        ('무관 거리를 3번 탐색해 무기고를 찾는다', nd(MARTIAL, sr(MARTIAL, 3))),
        ('무관 거리에서 5번 채집하고 강화 부적목 4개를 만들어 계단 디딤판으로 청파에게 넘긴다', nd(MARTIAL, ga(MARTIAL, 5), cr('reinforced_lumber', 4))),
        ('무관 거리에서 4번 채집하고 장비 수리 도구 1개를 만들어 먹 벗기는 끌로 갈매에게 넘긴다', nd(MARTIAL, ga(MARTIAL, 4), cr('repair_kit', 1))),
        ('무관 거리 연무장 처마 아래에서 야영으로 쉰다', nd(MARTIAL, rs(MARTIAL))),
        ('불빛으로 모여든 무관 거리의 요괴를 3번 쓰러뜨린다', nd(MARTIAL, wi(3, r=MARTIAL))),
        ('무관 거리에서 3번 채집해 밤새 불을 지킬 땔감을 모은다', nd(MARTIAL, ga(MARTIAL, 3))),
    ]),
    7: dict(L=46, region=IRON, after=['mdq_6'], items={'white_night_frost': 3, 'ember_ash_pill': 2}, steps=[
        ('무관 거리에서 쉬고 철벽 고찰에 도착해 북쪽 바람을 맞는다', nd(IRON, rs(MARTIAL), tv(IRON))),
        ('서리솔 고개에서 6번 채집하고 부적목 3개를 겨울 장작으로 철벽 고찰에 넘긴다', nd(IRON, ga(PINE, 6), give={'wood': 3})),
        ('자율 활동 「자율 수련」을 1시간 넘게 끝까지 한다', nd(IRON, idle('training', 60))),
        ('설피골에 도착해 3번 낚시하고 매운탕 2그릇을 끓여 석굴 앞에서 넘긴다', nd(IRON, tv(SNOW), fi(SNOW, 3), cr('spicy_stew', 2))),
        ('설피골로 원정을 한 번 끝까지 다녀와 얼음 녹은 물길을 따라 석굴 아래를 살핀다', nd(IRON, ex(SNOW))),
        ('서리솔 고개에서 금빛을 보고 몰려온 종소리 먹은 늑대를 4번 쓰러뜨린다', nd(IRON, wi(4, r=PINE, m=['dd_martial_4']))),
        ('철벽 고찰 사당 문밖에서 기다리며 쉰다', nd(IRON, rs(IRON))),
    ]),
    8: dict(L=47, region=SHRINE, after=['mdq_7'], items={'severed_lamp_oil': 2, 'red_shrine_lacquer': 2}, steps=[
        ('붉은 사당 골목에 도착해 거꾸로 건 등을 본다', nd(SHRINE, tv(SHRINE))),
        ('붉은 사당 골목을 4번 탐색하고 요괴를 3번 쓰러뜨린다', nd(SHRINE, sr(SHRINE, 4), wi(3, r=SHRINE))),
        ('붉은 사당 골목에서 5번 채집하고 청정수 3개를 만들어 벽을 닦을 물로 단비에게 넘긴다', nd(SHRINE, ga(SHRINE, 5), cr('purify_water', 3))),
        ('붉은 사당 골목에서 값귀를 쓰러뜨린다', nd(SHRINE, {'t': 'gg', 'mode': 'story', 'n': 1})),
        ('붉은 사당 골목 사당 처마 아래에서 야영으로 쉰다', nd(SHRINE, rs(SHRINE))),
        ('붉은 사당 골목으로 원정을 한 번 끝까지 다녀와 해 지는 쪽 담장 너머 기름 곳간을 찾는다', nd(SHRINE, ex(SHRINE))),
    ]),
    9: dict(L=47, region=BONE, after=['mdq_8'], items={'night_tea': 3, 'revival_charm': 2}, steps=[
        ('의식에 쓸 부적실 3개를 지어 단비에게 넘기고 백골 장터에 도착한다', nd(BONE, cr('talisman_thread', 3), tv(BONE))),
        ('적사 황무지에서 6번 채집하고 의식 자리를 노리는 기름 핥는 쥐떼를 4번 쫓아낸다', nd(BONE, ga(PLAIN, 6), wi(4, r=PLAIN, m=['dd_shrine_2']))),
        ('의식에 대비해 청심환 2개와 영초 차 2개를 만든다', nd_nogive(BONE, cr('tonic', 2), cr('spirit_tea', 2))),
        ('백골 장터에서 의식 전날 밤을 쉰다', nd(BONE, rs(BONE))),
        ('백골 장터에서 청심환 2개와 영초 차 2개를 단비에게 넘긴다', nd(BONE, give={'tonic': 2, 'spirit_tea': 2})),
        ('백골 장터에서 단비 곁을 지키며 쉰다', nd(BONE, rs(BONE))),
    ]),
    10: dict(L=48, region=OFM, after=['mdq_9'], items={'waterlogged_plank': 2, 'cheong_carp_steam': 2}, steps=[
        ('단비를 들것에 싣고 옛 나루 저자에 도착한다', nd(OFM, tv(OFM))),
        ('옛 나루 저자에서 요괴를 3번 쓰러뜨리고 4번 탐색해 우물 자리를 찾는다', nd(OFM, wi(3, r=OFM), sr(OFM, 4))),
        ('옛 나루 저자에서 5번 채집하고 뱃판 물동이 2개를 짜서 청파에게 넘긴다', nd(OFM, ga(OFM, 5), cr('plank_water_jar', 2))),
        ('옛 나루 저자에서 단비 곁을 지키며 쉬고, 원정을 한 번 끝까지 다녀와 배 무덤 안쪽을 살핀다', nd(OFM, rs(OFM), ex(OFM))),
        ('옛 나루 저자에서 청파 곁에서 쉰다', nd(OFM, rs(OFM))),
        ('구름나루에 도착해 붙드는 물을 담은 뱃판 물동이 1개를 수향 의원에게 넘긴다', nd(RIVER, tv(RIVER), give={'plank_water_jar': 1})),
        ('천엽 연화늪에서 4번 채집하고 영초 차 4잔을 우려 일행에게 넘긴다', nd(RIVER, ga(MARSH, 4), cr('spirit_tea', 4))),
        ('구름나루에서 청파와 나란히 3번 낚시한다', nd(RIVER, fi(RIVER, 3))),
        ('천엽 연화늪에서 선창으로 기어 나온 문패 문 물귀를 4번 쓰러뜨리고 구름나루에서 쉰다', nd(RIVER, wi(4, r=MARSH, m=['dd_ferry_2']), rs(RIVER))),
    ]),
    11: dict(L=48, region=OFM, after=['mdq_10'], items={'burrow_scale': 3, 'lamp_wick_core': 1}, steps=[
        ('옛 나루 저자에 도착해 우물 밑 물굴을 내려다본다', nd(OFM, tv(OFM))),
        ('옛 나루 저자에서 5번 채집하고 영사 실타래 1개를 자아 잠수 줄로 청파에게 넘긴다', nd(OFM, ga(OFM, 5), cr('spirit_thread', 1))),
        ('옛 나루 저자 물굴에서 청파를 기다리며 쉰다', nd(OFM, rs(OFM))),
        ('옛 나루 저자에서 4번 채집하고 물굴에서 2번 낚시해 청씨 잉어찜 1그릇을 쪄 청파에게 넘긴다', nd(OFM, ga(OFM, 4), fi(OFM, 2), cr('cheong_carp_steam', 1))),
        ('옛 나루 저자에서 청심환 1개와 영초 차 1개를 청파에게 넘긴다', nd(OFM, give={'tonic': 1, 'spirit_tea': 1})),
        ('옛 나루 저자 정리소 배 위에서 청파를 데우며 쉰다', nd(OFM, rs(OFM))),
        ('구름나루에 도착해 진소랑 앞에서 넷째 장 「이을 이」 칸을 채운다', nd(RIVER, tv(RIVER))),
    ]),
    12: dict(L=49, region=FOBS, after=['mdq_11'], items={'faded_star_glass': 2, 'star_record_plate': 1}, steps=[
        ('첫 관상대에 도착해 업힌 관측관을 본다', nd(FOBS, tv(FOBS))),
        ('첫 관상대에 도착해 녹슨 혼천의 바퀴를 3번 쓰러뜨리고 무극 관성대에 도착한다', nd(OBS, tv(FOBS), wi(3, m=['dd_obs_2']), tv(OBS))),
        ('백옥 천문탑에서 5번 채집하고 안신탕 1그릇을 달여 서이연에게 넘긴다', nd(OBS, ga(WTOWER, 5), cr('calm_brew', 1))),
        ('첫 관상대에 도착해 야영으로 쉰다', nd(FOBS, tv(FOBS), rs(FOBS))),
        ('첫 관상대에서 쉬고 영기 국밥 1그릇을 끓여 아침국으로 일행에게 넘긴다', nd(FOBS, rs(FOBS), cr('spirit_gukbap', 1))),
        ('첫 관상대를 탐색해 기록판 뒷장의 실마리를 2번 찾고, 원정을 한 번 끝까지 다녀와 관상대 둘레 우물을 살핀다', nd(FOBS, cl(FOBS, 2), ex(FOBS))),
        ('첫 관상대에서 단비 곁을 지키며 야영으로 쉰다', nd(FOBS, rs(FOBS))),
        ('물고기를 1번 낚고 매운탕 2그릇을 끓여 첫 관상대에서 단비에게 넘긴다', nd(FOBS, fi(None, 1), cr('spicy_stew', 2))),
    ]),
    13: dict(L=49, region=HQ, after=['mdq_12'], items={'ledger_tab': 3, 'balance_weight': 1}, steps=[
        ('본부 정청에 도착해 안쪽 방의 열린 문 앞에 선다', nd(HQ, tv(HQ))),
        ('잿빛 들녘에서 4번 채집하고 밤빛 차 1잔을 우려 본부 정청의 도제조에게 넘긴다', nd(HQ, ga(FIELD, 4), cr('night_tea', 1))),
        ('장서각 지하서고에 도착해 4번 탐색하며 봉인 서가 잿더미를 헤치고, 우물에서 기어 나온 먹 도랑 검은 손을 3번 쓰러뜨려 본부 객사로 간다', nd(DORM, tv(ARCH), sr(ARCH, 4), wi(3, r=ARCH, m=['dd_vault_1']))),
        ('잿빛 들녘에서 4번 채집하고 정제 황지 1장을 떠 서식 사본으로 모가람에게 넘긴다', nd(HQ, ga(FIELD, 4), cr('fine_paper', 1))),
        ('감찰관이 올 잿빛 들녘 길목에서 종소리 먹은 늑대를 3번 쓰러뜨리고 본부 정청에서 쉰다', nd(HQ, wi(3, r=FIELD, m=['dd_martial_4']), rs(HQ))),
        ('본부 객사에서 감찰관과 함께 쉰다', nd(DORM, rs(DORM))),
        ('장서각 지하서고에 도착해 탐색하며 정리소로 가는 길의 실마리를 2번 찾는다', nd(JEONGNI, tv(ARCH), cl(ARCH, 2))),
        ('정리소에서 먹 도랑 검은 손을 4번 쓰러뜨리고 가늠 저울 둘레를 3번 탐색한다', nd(JEONGNI, wi(4, m=['dd_vault_1']), sr(JEONGNI, 3))),
        ('정리소 우물 손잡이로 기어오르는 요괴를 2번 쓰러뜨리고 장서각 지하서고로 올라간다', nd(ARCH, wi(2, r=JEONGNI))),
    ]),
    14: dict(L=49, region=EMBERV, after=['mdq_13'], items={'king_ember_ash': 2, 'ember_ash_pill': 2}, steps=[
        ('잔불촌에 도착해 화로 앞에서 옅어진 그림자를 본다', nd(EMBERV, tv(EMBERV))),
        ('불씨 고개에서 5번 채집해 화로에 넣을 장작을 모은다', nd(EMBERV, ga(EMBERP, 5))),
        ('잔불촌에서 한 시진씩 돌아가며 장군의 이름을 부르며 쉰다', nd(EMBERV, rs(EMBERV))),
        ('불씨 고개에서 4번 채집해 국수에 넣을 메밀과 들나물을 모은다', nd(EMBERV, ga(EMBERP, 4))),
        ('불씨 고개에서 마을로 내려오는 재 덮인 궁녀 넋을 4번 풀어 보낸다', nd(EMBERV, wi(4, r=EMBERP, m=['dd_palace_1']))),
        ('잔불촌에서 모두 둘러앉아 이름을 부르며 둘째 밤을 쉰다', nd(EMBERV, rs(EMBERV))),
        ('들것 1개를 만들어 장군을 모시고 잿빛 왕궁 터에 도착한다', nd(PALACE, cr('md_litter', 1), tv(PALACE))),
        ('잿빛 왕궁 터를 맴도는 요괴를 3번 쓰러뜨리고 잿빛 왕궁 터에서 마지막 밤을 쉰다', nd(PALACE, wi(3, m=['dd_palace_1', 'dd_palace_2']), rs(PALACE))),
        ('장군의 옷과 신을 모시고 잔불촌에 도착해 장군을 부르며 쉰다', nd(EMBERV, tv(EMBERV), rs(EMBERV))),
    ]),
    15: dict(L=50, region=LEDGER, after=['mdq_14'], items={'balance_weight': 2, 'lamp_wick_core': 1}, steps=[
        ('잔불촌에서 쉬고 갈매가 남긴 쪽지를 편다', nd(EMBERV, rs(EMBERV))),
        ('불씨 고개에 도착해 원정을 한 번 끝까지 다녀오며 고개 길에서 갈매를 찾는다', nd(EMBERP, tv(EMBERP), ex(EMBERP))),
        ('불씨 고개 무덤 둘레를 맴도는 잿불 도마뱀을 3번 쓰러뜨린다', nd(EMBERP, wi(3, r=EMBERP, m=['dd_palace_4']))),
        ('흑련 장부고에 도착해 탐색하며 금고 문에 남은 먹 자국의 실마리를 2번 찾는다', nd(LEDGER, tv(LEDGER), cl(LEDGER, 2))),
        ('지맥의 뿌리에 도착해 먹 도랑을 지키는 먹 도랑 검은 손을 5번 쓰러뜨린다', nd(ROOT, tv(ROOT), wi(5, r=ROOT, m=['dd_vault_1']))),
        ('정리소에 도착해 3번 탐색하며 금고와 먹손을 피해 갈 길을 찾는다', nd(JEONGNI, tv(JEONGNI), sr(JEONGNI, 3))),
        ('정리소에서 먹 도랑 검은 손을 3번 쓰러뜨리고 흑련 장부고에 도착한다', nd(LEDGER, wi(3, m=['dd_vault_1']), tv(LEDGER))),
        ('어죽 2그릇을 쑤어 흑련 장부고에서 월하와 다온에게 넘긴다', nd(LEDGER, cr('fish_porridge', 2))),
    ]),
    16: dict(L=50, region=PACT, after=['mdq_15'], items={'pact_stone_dust': 2, 'lamp_wick_core': 2}, steps=[
        ('꺼진 관아 터에 다시 도착한다', nd(YAMEN, tv(YAMEN))),
        ('꺼진 관아 터에서 3번 채집하고 봉인 먹 1개를 갈아 단비에게 넘긴다', nd(YAMEN, ga(YAMEN, 3), cr('sealing_ink', 1))),
        ('꺼진 관아 터에서 싸움 전 마지막 밤을 쉰다', nd(YAMEN, rs(YAMEN))),
        ('맹약 마당에 도착해 2번 탐색하며 일곱 자리와 돌상을 살핀다', nd(PACT, tv(PACT), sr(PACT, 2))),
        ('맹약 마당에서 동트기 전 마지막 밤을 쉰다', nd(PACT, rs(PACT))),
        ('맹약 마당에서 백야를 쓰러뜨린다', nd(PACT, {'t': 'by', 'mode': 'story', 'n': 1})),
        ('맹약 마당에서 여운비 곁에 모여 이름을 부르며 쉰다', nd(PACT, rs(PACT))),
    ]),
    17: dict(L=50, region=PACT, after=['mdq_16'], items={'myeongdeung_lamp': 4, 'lamp_wick_core': 2}, steps=[
        ('맹약 마당에서 쉬고 일곱 장이 재가 되는 것을 본다', nd(PACT, rs(PACT))),
        ('맹약 마당에서 서하람과 여운비 곁을 지키며 쉰다', nd(PACT, rs(PACT))),
        ('맹약 마당에서 쉬고, 정리소를 1번 탐색해 경현이 남긴 장부를 찾는다', nd(JEONGNI, rs(PACT), sr(JEONGNI, 1))),
        ('들것 1개를 만들어 도제조를 모시고 꺼진 관아 터에 도착한다', nd(YAMEN, cr('md_litter', 1), tv(YAMEN))),
        ('꺼진 관아 터에서 도제조를 보내는 밤을 쉰다', nd(YAMEN, rs(YAMEN))),
        ('구중 봉연에 도착해 가라앉은 문 둘레에 남은 흰 밤 서리 떼를 3번 쓸어 낸다', nd(ABYSS, tv(ABYSS), wi(3, r=ABYSS, m=['dd_pact_2']))),
        ('구중 봉연에서 쉬고 흑련 장부고에 도착한다', nd(LEDGER, rs(ABYSS), tv(LEDGER))),
        ('흑련 장부고에서 쉬고 본부 정청에 도착한다', nd(HQ, rs(LEDGER), tv(HQ))),
        ('본부 정청에서 쉬고 명등 등롱 3개를 만들어 꺼진 관아 터의 명등제에 쓴다', nd(YAMEN, rs(HQ), cr('myeongdeung_lamp', 3))),
    ]),
}

SWAPPED = {
    (1, 3): '화상 고약 → 농축 약초액(herbal_extract) — 의원이 약초액으로 고약을 갬',
    (1, 6): '봉인 부적 → 정화 부적(ward_talisman)',
    (1, 7): '약초죽 → 월광 이끼죽(moss_porridge)',
    (2, 3): '엿 → 꿀 약과(treat_honey, 동무 먹이 가게 별미·거래 불가) — 장면 제목 「엿 두 가락」 → 「약과 두 개」, 15장 장면 8의 다온 손수건도 「약과와 반 토막 엿」',
    (5, 2): '거룻배 판자 → 가공 부적목(lumber)',
    (5, 4): '요리 1그릇(국) → 영맥 약선탕(bark_stew)',
    (6, 4): '계단 디딤판 → 강화 부적목(reinforced_lumber)',
    (6, 5): '먹 벗기는 끌 → 장비 수리 도구(repair_kit) — 꾸러미의 가는 끌을 씀',
    (7, 2): '장작 꾸러미 → 부적목(wood) 3개 넘기기',
    (7, 4): '생선국(빙어국) → 매운탕(spicy_stew)',
    (8, 3): '잿물 → 청정수(purify_water) — 청정수에 재를 풂',
    (9, 1): '붉은 실 → 부적실(talisman_thread) — 붉은 사당 옻에 물들여 꼼',
    (10, 7): '꿀 생강물 → 영초 차(spirit_tea)에 꿀을 탐',
    (11, 2): '잠수 줄 → 영사 실타래(spirit_thread) — 세 겹 가운데 한 겹',
    (11, 4): '요리 1그릇(생선국) → 청씨 잉어찜(cheong_carp_steam, 물굴 청씨 잉어)',
    (12, 3): '약초 달인 물 → 안신탕(calm_brew)',
    (12, 5): '아침국 → 영기 국밥(spirit_gukbap)',
    (12, 8): '요리 2그릇(국) → 매운탕(spicy_stew, 맵지 않게)',
    (13, 2): '송화차 → 송화를 넣은 밤빛 차(night_tea)',
    (13, 4): '서식 사본 → 정제 황지(fine_paper) — 사본을 받아 적을 종이',
    (16, 2): '등 그을음 먹 → 봉인 먹(sealing_ink) — 등 그을음을 넣음',
    (17, 9): '등롱 → 명등 등롱(myeongdeung_lamp)',
}

NEW_ITEM_USE = {
    (10, 3): '물동이 → 새 물품 뱃판 물동이(plank_water_jar, 한 번에 3개 — 2개 넘기고 1개는 10장 장면 6에)',
    (10, 6): '붙드는 물 한 동이 → 뱃판 물동이 1개 넘기기',
    (14, 7): '들것 → 새 물품 들것(md_litter)',
    (17, 4): '들것 → 새 물품 들것(md_litter)',
}

BORROWED = {
    (2, 4): (LEDGER, 'dd_yamen_1', 3),
    (2, 5): (ROOT, 'dd_yamen_5', 1),
    (3, 2): (SNOW, 'dd_yamen_2', 4),
    (3, 6): (PLAIN, 'dd_yamen_1', 3),
    (3, 8): (PLAIN, 'dd_yamen_3', 4),
    (4, 5): (EMBERP, 'dd_martial_4', 5),
    (7, 6): (PINE, 'dd_martial_4', 4),
    (9, 2): (PLAIN, 'dd_shrine_2', 4),
    (10, 9): (MARSH, 'dd_ferry_2', 4),
    (13, 3): (ARCH, 'dd_vault_1', 3),
    (13, 5): (FIELD, 'dd_martial_4', 3),
    (14, 5): (EMBERP, 'dd_palace_1', 4),
    (15, 3): (EMBERP, 'dd_palace_4', 3),
    (15, 5): (ROOT, 'dd_vault_1', 5),
    (17, 6): (ABYSS, 'dd_pact_2', 3),
}

NOTES = {
    (1, 3): '약초 채집 6개 — 지역이 없어 야령초 6개를 어디서나 모으기로',
    (2, 3): '낚시 2회 — 흑련 장부고에 낚시터가 없어 지역 없이',
    (4, 4): '잔불촌은 안전지대라 탐색 불가 → 불씨 고개 탐색 2',
    (4, 7): '잔불촌 채집(안전지대) → 불씨 고개 채집 4',
    (7, 2): '철벽 고찰 둘레 채집(안전지대) → 서리솔 고개 채집 6',
    (7, 5): '철벽 고찰 원정(안전지대) → 설피골 원정',
    (7, 6): '철벽 고찰 둘레(안전지대) 처치 → 서리솔 고개에서',
    (9, 2): '백골 장터 둘레(안전지대) → 적사 황무지',
    (9, 3): '청심환·영초 차 만들기만(넘기기는 대본대로 장면 5에 따로)',
    (10, 7): '구름나루 둘레 채집(안전지대) → 천엽 연화늪 채집 4',
    (10, 9): '구름나루 둘레(안전지대) 처치 → 천엽 연화늪에서',
    (11, 7): '「이을 이」 칸 채우기 — 할 일 갈래 없음, 이동만',
    (12, 3): '무극 관성대 둘레 채집(안전지대) → 백옥 천문탑 채집 5',
    (12, 8): '첫 관상대 낚시 1 — 첫 관상대에 낚시터가 없어 지역 없이',
    (13, 2): '본부 정청 둘레 채집(안전지대) → 잿빛 들녘 채집 4',
    (13, 4): '본부 정청 둘레 채집 → 잿빛 들녘 채집 4',
    (13, 5): '본부 정청 둘레(안전지대) 처치 → 잿빛 들녘에서',
    (14, 2): '잔불촌 둘레 채집(안전지대) → 불씨 고개 채집 5',
    (14, 4): '잔불촌 둘레 채집 → 불씨 고개 채집 4',
    (14, 5): '잔불촌 둘레(안전지대) 처치 → 불씨 고개에서',
    (17, 9): '17장 장면 9(마지막)의 할 일 「꺼진 관아 터에서 쉬기(명등기 마침)」는 다음 장이 없어 need에 넣지 않음',
}

MOVED = {c: f'{c - 1}장 마지막 장면의 할 일을 {c}장 장면 1 need로' for c in range(2, 18)}


def parse_tag(tag):
    tag = tag.strip()
    m = re.match(r'^(\S+) 밖$', tag)
    if m and m.group(1) in FACTIONS:
        return {'fac_not': FACTIONS[m.group(1)], 'spec': 2}
    m = re.match(r'^(\S+) (\d)(?:~(\d))?$', tag)
    if m and m.group(1) in FACTIONS:
        lo = int(m.group(2)); hi = int(m.group(3) or m.group(2))
        return {'fac': FACTIONS[m.group(1)], 'rank': [lo, hi], 'spec': 0}
    if tag in FACTIONS:
        return {'fac': FACTIONS[tag], 'spec': 1}
    return None


def parse():
    src = open(SCRIPT, encoding='utf-8').read()
    chapters = {}
    ch = scene = None
    bad_tags, bad_speakers = [], []
    grp = 0
    in_grp = False
    for raw in src.splitlines():
        line = raw.rstrip()
        m = re.match(r'^# (\d+)장 「(.+?)」 · Lv(\d+)', line)
        if m:
            ch = int(m.group(1)); chapters[ch] = dict(title=m.group(2), L=int(m.group(3)), summary='', scenes=[]); scene = None
            continue
        if ch is None:
            continue
        if line.startswith('> ') and not chapters[ch]['scenes']:
            chapters[ch]['summary'] = line[2:].strip()
            continue
        m = re.match(r'^### 장면 (\d+) · (.+?) \((받기|보고): (.+?)\)\s*$', line)
        if m:
            scene = dict(no=int(m.group(1)), title=m.group(2), kind=m.group(3), place=m.group(4), lines=[], task=None)
            chapters[ch]['scenes'].append(scene); grp = 0; in_grp = False
            continue
        if scene is None:
            continue
        m = re.match(r'^- 할 일: (.+)$', line)
        if m:
            scene['task'] = m.group(1).strip(); in_grp = False
            continue
        m = re.match(r'^- (?:\[([^\]]+)\] )?([^:\[\]]+?): (.+)$', line)
        if m:
            tag, sp, text = m.group(1), m.group(2).strip(), m.group(3)
            if sp not in SPEAK:
                bad_speakers.append((ch, scene['no'], sp))
            d = {'s': SPEAK.get(sp), 't': text}
            if tag:
                k = parse_tag(tag)
                if k is None:
                    bad_tags.append((ch, scene['no'], tag))
                else:
                    if not in_grp:
                        grp += 1; in_grp = True
                    d.update(k); d['grp'] = grp
            else:
                in_grp = False
            scene['lines'].append(d)
            continue
        if line.strip():
            in_grp = False
    return chapters, bad_tags, bad_speakers


def build():
    chapters, _, _ = parse()
    quests, steps = [], []
    for c in range(1, 18):
        P, C = PLAN[c], chapters[c]
        if len(C['scenes']) != len(P['steps']):
            raise SystemExit(f'{c}장 장면 수가 다름: 대본 {len(C["scenes"])} · 계획 {len(P["steps"])}')
        qid = f'mdq_{c}'
        quests.append(dict(id=qid, cat=CAT, title=C['title'], L=P['L'], region=P['region'], after=P['after'], summary=C['summary'], items=P['items']))
        for k, s in enumerate(C['scenes']):
            goal, need = P['steps'][k]
            steps.append(dict(quest=qid, step=k + 1, title=s['title'], goal=goal, need=need, lines=[dict(x) for x in s['lines']]))
    return quests, steps


def dropped():
    chapters, _, _ = parse()
    out = []
    for c in range(1, 18):
        last = chapters[c]['scenes'][-1]
        if last['task']:
            out.append((c, last['no'], last['task']))
    return out


def check():
    ref = json.load(open(REF, encoding='utf-8'))
    regions, monsters, items, recipes = ref['regions'], ref['monsters'], ref['items'], ref['recipes']
    kinds = set(ref['task_kinds']) | set(SPECIAL_TASKS)
    new_ids = {i[0] for i in NEW_ITEMS}
    all_items = set(items) | new_ids
    makes = {r['out'] for r in recipes.values()} | new_ids
    npc_names = set(ref['npcs'].values()) | set(ref['faction_npcs'].values())
    known_keys = set(ref['npcs']) | set(ref['faction_npcs']) | set(NPCS)
    item_names = {v['name'] for v in items.values()}
    errs, warns, infos = [], [], []
    chapters, bad_tags, bad_speakers = parse()
    for t in bad_tags:
        errs.append(f'갈래 머리 해석 못 함 {t}')
    for t in bad_speakers:
        errs.append(f'말하는 이 SPEAK에 없음 {t}')
    for sp, key in SPEAK.items():
        if key and key not in known_keys:
            errs.append(f'인물 키 없음 {sp} → {key}')
    for key, (nm, _) in NPCS.items():
        if nm in npc_names:
            errs.append(f'새 인물 이름 겹침 {nm}')
    for iid, nm, field, mats, qty, _ in NEW_ITEMS:
        if iid in items:
            errs.append(f'새 물품 id 겹침 {iid}')
        if nm in item_names:
            errs.append(f'새 물품 이름 겹침 {nm}')
        for m in mats:
            if m not in items:
                errs.append(f'새 물품 재료 없음 {iid}: {m}')
    if sorted(chapters) != list(range(1, 18)):
        errs.append(f'장 번호 {sorted(chapters)}')
    total = 0
    for c in range(1, 18):
        P, C = PLAN[c], chapters.get(c)
        if C is None:
            continue
        if C['L'] != P['L']:
            errs.append(f'{c}장 레벨 대본 {C["L"]} · 계획 {P["L"]}')
        if len(C['scenes']) != len(P['steps']):
            errs.append(f'{c}장 장면 수 대본 {len(C["scenes"])} · 계획 {len(P["steps"])}')
        total += len(C['scenes'])
        if P['region'] not in regions:
            errs.append(f'{c}장 지역 없음 {P["region"]}')
        for i in P['items']:
            if i not in items:
                errs.append(f'{c}장 보상 물품 없음 {i}')
        for k, (goal, need) in enumerate(P['steps']):
            tag = f'{c}장 장면 {k + 1}'
            if '가안' in goal:
                errs.append(f'{tag} 목표 문구에 가안')
            if k < len(C['scenes']):
                sc = C['scenes'][k]
                rid = need['at'][0]
                pname = regions.get(rid, {}).get('name', '')
                if sc['place'] not in pname and pname not in sc['place'] and not (sc['place'] == '장서각' and rid == ARCH):
                    warns.append(f'{tag} 보고 장소 대본 「{sc["place"]}」 · 계획 {rid}({pname})')
            if k > 0 and not need.get('tasks') and not need.get('give'):
                errs.append(f'{tag} 할 일 없음')
            for r in need['at']:
                if r not in regions:
                    errs.append(f'{tag} 장소 없음 {r}')
            for t in need.get('tasks', []):
                if t['t'] not in kinds:
                    errs.append(f'{tag} 할 일 갈래 없음 {t["t"]}')
                for r in t.get('r', []):
                    if r not in regions:
                        errs.append(f'{tag} 지역 없음 {r}')
                    elif t['t'] in ('search', 'clue', 'win', 'gather', 'expedition') and regions[r]['safe']:
                        errs.append(f'{tag} 안전지대에서 {t["t"]}: {r}')
                for m in t.get('m', []):
                    if m not in monsters:
                        errs.append(f'{tag} 요괴 없음 {m}')
                    elif not (P['L'] - 3 <= monsters[m]['lo'] <= P['L'] + 3):
                        errs.append(f'{tag} 요괴 레벨이 장과 안 맞음 {m} Lv{monsters[m]["lo"]}')
                    elif 'r' in t and monsters[m]['region'] not in t['r'] and not regions[monsters[m]['region']]['terr'] in ('deungdo', 'jeongni'):
                        errs.append(f'{tag} 빌려 오는 요괴가 등도·정리소 것이 아님 {m}')
                    elif 'r' in t and monsters[m]['region'] not in t['r'] and (c, k + 1) not in BORROWED:
                        errs.append(f'{tag} BORROWED 표에 없는 빌려 온 요괴 {m}')
                if t['t'] == 'win' and 'r' in t and not t.get('m'):
                    lvs = [v['lo'] for v in monsters.values() if v['region'] in t['r']]
                    if not lvs or min(lvs) < P['L'] - 3:
                        errs.append(f'{tag} 처치 지역 요괴 레벨 낮음 {t["r"]}')
                for i in t.get('items', []):
                    if i not in all_items:
                        errs.append(f'{tag} 물품 없음 {i}')
                    if t['t'] == 'craft' and i not in makes:
                        errs.append(f'{tag} 제작법 없음 {i}')
                if t['t'] == 'craft':
                    g = need.get('give', {})
                    if g.get(t['items'][0]) != t['n'] and (c, k + 1) != (9, 3):
                        errs.append(f'{tag} 만들기 뒤 넘기기 수가 다름 {t["items"][0]}')
                if t['t'] == 'fish' and 'r' in t:
                    if not any(g['region'] in t['r'] for g in ref['fish_grounds']):
                        errs.append(f'{tag} 낚시터 없음 {t["r"]}')
                if t['t'] == 'expedition':
                    if not any(g['region'] in t['r'] for g in ref['grounds'].values()):
                        errs.append(f'{tag} 원정지 없음 {t["r"]}')
            for i in need.get('give', {}):
                if i not in all_items:
                    errs.append(f'{tag} 넘길 물품 없음 {i}')
        if c > 1 and not P['steps'][0][1].get('tasks'):
            errs.append(f'{c}장 장면 1에 앞 장 끝 할 일이 없음')
        if c > 1 and P['after'] != [f'mdq_{c - 1}']:
            errs.append(f'{c}장 after {P["after"]}')
        for s in C['scenes']:
            groups = {}
            for ln in s['lines']:
                if 'grp' in ln:
                    groups.setdefault(ln['grp'], []).append(ln)
            for g, lns in groups.items():
                if not any('fac_not' in ln for ln in lns):
                    infos.append(f'{c}장 장면 {s["no"]} 묶음 {g}: 「밖」 줄 없는 묶음 — {"·".join(sorted({ln["fac"] for ln in lns}))} 사람에게만 한 줄 더 보임(허용)')
                    continue
                for fk in [None] + list(FACTIONS.values()):
                    for rk in ([0] if fk is None else range(1, 6)):
                        seen = False
                        for ln in lns:
                            if 'fac_not' in ln and ln['fac_not'] != fk:
                                seen = True
                            elif ln.get('fac') == fk and fk is not None and ('rank' not in ln or ln['rank'][0] <= rk <= ln['rank'][1]):
                                seen = True
                        if not seen:
                            errs.append(f'{c}장 장면 {s["no"]} 묶음 {g}: {fk or "무소속"} {rk}등급에게 보이는 줄이 없음')
                            break
    if total != 131:
        errs.append(f'장면 합 {total}')
    for (c, k), (r, m, n) in BORROWED.items():
        t = [x for x in PLAN[c]['steps'][k - 1][1].get('tasks', []) if x['t'] == 'win' and x.get('m') == [m] and x.get('r') == [r] and x['n'] == n]
        if not t:
            errs.append(f'BORROWED {c}장 장면 {k}: PLAN에 {{t:win, m:[{m}], r:[{r}], n:{n}}} 없음')
    return errs, warns, infos


if __name__ == '__main__':
    e, w, i = check()
    q, s = build()
    print(f'퀘스트 {len(q)} · 장면 {len(s)} · 할 일 있는 장면 {sum(1 for x in s if x["need"].get("tasks") or x["need"].get("give"))} · 할 일 {sum(len(x["need"].get("tasks", [])) for x in s)}')
    print(f'갈래 줄 {sum(1 for x in s for l in x["lines"] if "grp" in l)} · 묶음 {sum(len({l["grp"] for l in x["lines"] if "grp" in l}) for x in s)}')
    for x in i:
        print('참고', x)
    for x in w:
        print('주의', x)
    for x in e:
        print('오류', x)
    print('오류 없음' if not e else f'오류 {len(e)}')
