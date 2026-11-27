import hashlib
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = [os.path.join(HERE, '..', '..', 'gen_part2', f'script_40_{c}.md') for c in range(1, 16)]
REF = os.path.join(HERE, 'ref', 'existing_names.json')
CAT = '외전·도해록'
QID = 'hwq_'
XP = 0.28
AFTER_FIRST = ['mdq_17']

FACTIONS = {'정통파': 'night_office', '적월': 'red_moon_cult', '흑련': 'black_lotus', '북령': 'north_league',
            '수향': 'river_alliance', '남명': 'southern_remnant', '천명': 'mandate_court'}

KNOWN = {
    '서술': None, '한설': 'night_office:han', '모가람': 'night_office:mo', '희수': 'q:mk_hisu', '문수': 'q:dh_munsu', '연서희': 'q:m_yeon',
    '청파': 'q:sn_cheongpa', '좌판 아낙': 'q:yd_stallwife',
}
MAIN_NPCS = {
    '온결': ('q:hw_ongyeol', '우물 너머에서 만난 떠돌이 지리학자 겸 술사. 격의 없는 반말과 농담을 즐기고, 막히면 「한 번만 더」를 입에 단다. 틈이 열리는 때를 읽는다.'),
    '높새': ('q:hw_nopsae', '구름성 출신의 날개 있는 퇴마사. 파도너울성에 파견되어 실종 사건을 맡았다. 책임감이 강하고 남에게 일을 맡기는 데 서툴다.'),
    '바랑': ('q:hw_barang', '눈마루 출신의 망자. 살아서는 행상인이었고 죽은 뒤에도 길잡이로 떠돈다. 침착하고 붙임성이 좋다.'),
    '물꼬': ('q:hw_mulkko', '파도너울성의 선장. 물속에서도 숨을 쉰다. 실용적이고 호탕하며, 청파와 함께 배를 몬다.'),
    '매솔': ('q:hw_maesol', '달맞이성 모음전의 분배관. 결단이 빠르고 일을 잘하지만, 자기 나라 주민을 먼저 챙기고 타협에 인색하다.'),
    '새움': ('q:hw_saeum', '잿빛그늘숲 흑단나무에서 깨어난 어린 요괴. 옥산 할머니가 키웠다. 태어날 동생을 기다리며 물건을 모은다. 청파를 「청파 오빠」라 부른다.'),
    '너설': ('q:hw_neoseol', '염등촌 노인 곁에서 그 이름으로 불리며 지냈던 망자. 틈이 찢길 때 경계에 걸렸다가 건넛누리의 가족에게 돌아간다.'),
    '복만 영감': ('q:hw_bokman', '염등촌의 늙은 소금꾼. 쌀 두 섬도 없어 가장 먼저 부름꾼에게 속은 고을의 사람이다.'),
    '쇠매': ('q:hw_soemae', '불씨들녘의 오래된 장인. 제련소 화로 불씨에서 깨어났고, 기다리는 마을 사람들을 위해 화로와 제련소를 지키자고 한다.'),
    '담금': ('q:hw_damgeum', '불씨들녘의 오래된 장인. 쇠매의 오랜 동료로 품삯 장부를 챙기며, 일꾼들 품삯을 주려면 저장해 둔 요기를 팔자고 한다.'),
    '옥산 할머니': ('q:hw_oksan', '잿빛그늘숲의 인간 노인. 흑단나무에서 깨어난 새움을 거두어 키웠다. 약초와 살림이 모자라 몸이 약해졌다.'),
    '설매': ('q:hw_seolmae', '눈마루 돌마을 사람. 두 번째 장례를 준비한다.'),
    '외솔': ('q:hw_oesol', '눈마루의 망자. 흐려지기 전에 좋아하던 음식을 앞에 두고 작별을 기다린다.'),
    '해진': ('q:hw_haejin', '파도너울성에서 돌아온 실종자의 가족.'),
    '밤울림골 기술자': ('q:hw_bamul', '땅 밑 밤울림골에서 달맞이성으로 파견된 기술자. 마을마다 다른 종소리로 길을 찾고, 지맥의 울림을 잰다.'),
    '왕실 서고 학자': ('q:hw_scholar', '달맞이성 왕실 서고의 학자. 옛 기록을 뒤져 모음전과 고임터의 내력을 찾는다.'),
    '낯선 여행자': ('q:hw_traveler', '수경루 우물가에 나타난 낯선 여행자.'),
    '모음전 일꾼': ('q:hw_moeum', '달맞이성 모음전에서 순번과 몫을 적는 일꾼.'),
}

HQ, DORM, SALT, RIVER, MARSH, MIRROR = 'hq_yard', 'hq_dorm', 'salt_village', 'river_ferry', 'lotus_marsh', 'mirror_pavilion'
PD, SHORE, OFF, RIFT = 'pd_city', 'pd_shore', 'pd_offsea', 'pd_rift'
BS, GEO = 'bs_town', 'bs_geo'
JBV, EBONY, FERRY = 'jb_village', 'jb_ebony', 'jb_ferry'
NMV, SNOW = 'nm_village', 'nm_snow'
DM, FIELD, BAMBOO, POOL = 'dm_city', 'dm_field', 'dm_bamboo', 'dm_pool'
HO, OUTER, COAST = 'ho_city', 'ho_outer', 'ho_coast'
PLACE = {'본부 정청': HQ, '염등촌': SALT, '구름나루': RIVER, '수경루': MIRROR, '파도너울성': PD, '쪽빛 앞바다': OFF, '뒤집힌 물목': RIFT,
         '화덕골': BS, '김 오르는 비탈': GEO, '억새 나루': JBV, '검은 고목 숲': EBONY, '먹빛 강 나루터': FERRY, '눈마루 돌마을': NMV,
         '달맞이성': DM, '모음전': DM, '고임터': POOL, '해오름성': HO, '연밥 둑': OUTER, '첫볕 물가': COAST}


def tv(r, phase=None):
    t = {'t': 'travel', 'r': [r], 'n': 1}
    if phase: t['phase'] = phase
    return t


def sr(r, n, phase=None):
    t = {'t': 'search', 'r': [r], 'n': n}
    if phase: t['phase'] = phase
    return t


def cl(r, n):
    return {'t': 'clue', 'r': [r], 'n': n}


def rs(r, phase=None):
    t = {'t': 'rest', 'r': [r], 'n': 1}
    if phase: t['phase'] = phase
    return t


def ga(r, n, items=None):
    t = {'t': 'gather', 'n': n}
    if items: t['items'] = items
    if r: t['r'] = [r]
    return t


def fi(r, n, f=None):
    t = {'t': 'fish', 'n': n}
    if f: t['f'] = f
    if r: t['r'] = [r]
    return t


def wi(n, r=None, m=None):
    t = {'t': 'win', 'n': n}
    if m: t['m'] = m
    if r: t['r'] = [r]
    return t


def ex(r):
    return {'t': 'expedition', 'r': [r], 'n': 1}


def cr(item, n):
    return {'t': 'craft', 'items': [item], 'n': n}


def crf(field, n):
    return {'t': 'craft', 'field': field, 'n': n}


def sl(r):
    return {'t': 'sell', 'r': [r], 'n': 1}


def idle(k):
    return {'t': 'idle', 'k': k, 'n': 1}


def nd(at, *tasks, give=None):
    need = {'at': [at]}
    if tasks: need['tasks'] = list(tasks)
    g = dict(give or {})
    for t in tasks:
        if t['t'] == 'craft' and t.get('items'):
            g.setdefault(t['items'][0], t['n'])
    if g: need['give'] = g
    return need


B1 = ['dd_ferry_2']
B1E = ['dd_ferry_4']
B2 = ['dd_yamen_1']
PLAN = {
    1: dict(L=50, region=SALT, items={'travel_ration': 3, 'rejuv_pill': 2}, steps=[
        ('본부 정청에서 한설에게 경현의 약속을 듣는다', nd(HQ)),
        ('염등촌에 도착해 탐색하며 부름꾼이 남긴 실마리 4개를 찾는다', nd(SALT, tv(SALT), cl(SALT, 4))),
        ('염등촌 물가에서 5번 낚시한다', nd(SALT, fi(SALT, 5))),
        ('땅거미나 삼경에 구름나루에 도착해 물가로 향하는 사람을 뒤쫓는다', nd(RIVER, tv(RIVER, ['dusk', 'night']))),
        ('어죽 4그릇을 쑤어 복만 영감에게 넘기고, 천엽 연화늪에서 실마리 4개를 찾는다', nd(SALT, cr('fish_porridge', 4), cl(MARSH, 4))),
        ('염등촌에 끌려온 문패 문 물귀를 4번 쓰러뜨린다', nd(SALT, wi(4, SALT, B1))),
        ('염등촌에서 문패 문 물귀 5번과 물굴 먹장어 떼 1번을 쓰러뜨리고, 회춘단 4개를 지어 넘긴다', nd(SALT, wi(5, SALT, B1), wi(1, SALT, B1E), cr('rejuv_pill', 4))),
        ('수경루에 도착해 옛 우물가에서 5번 낚시한다', nd(MIRROR, tv(MIRROR), fi(MIRROR, 5))),
    ]),
    2: dict(L=50, region=MIRROR, items={'spirit_core': 1, 'tonic': 3}, steps=[
        ('수경루 우물에 걸린 사람을 본다', nd(MIRROR)),
        ('수경루에 끌려온 부르다 굳은 넋을 5번 풀어 보낸다', nd(MIRROR, wi(5, MIRROR, B2))),
        ('수경루에서 어죽 2그릇을 쑤어 너설에게 넘긴다', nd(MIRROR, cr('fish_porridge', 2))),
        ('수경루 우물에서 5번 낚시해 물에 빠진 것을 건진다', nd(MIRROR, fi(MIRROR, 5))),
        ('수경루를 탐색해 우물 밑 장부의 실마리 4개를 찾는다', nd(MIRROR, cl(MIRROR, 4))),
        ('염등촌에 다녀와 4번 채집하고 수경루로 돌아온다', nd(MIRROR, tv(SALT), ga(SALT, 4))),
        ('삼경에 수경루에서 쉬고, 땅거미에 수경루를 4번 탐색하며 틈이 열리는 때를 기다린다', nd(MIRROR, rs(MIRROR, ['night']), sr(MIRROR, 4, ['dusk']))),
        ('우물을 건너 파도너울성에 도착한다', nd(PD, tv(PD))),
    ]),
    3: dict(L=50, region=PD, items={'pd_tide_charm': 2, 'travel_ration': 3}, steps=[
        ('파도너울성 널다리를 걷는다', nd(PD)),
        ('파도너울성 널다리 물골에서 널다리 망둥이 3마리를 낚는다', nd(PD, fi(PD, 3, ['hw_canal_goby']))),
        ('밀물 둑길에서 푸른 소금 결정 5개를 모은다', nd(PD, ga(SHORE, 5, ['blue_salt']))),
        ('망둥이 바삭 튀김 1접시를 만들어 너설 어머니에게 넘긴다', nd(PD, cr('hw_goby_crisp', 1))),
        ('밀물 둑길을 탐색해 실마리 4개를 찾는다', nd(PD, cl(SHORE, 4))),
        ('밀물 둑길에서 이름 흐린 그물꾼을 4번 진압한다', nd(PD, wi(4, SHORE, ['hw_shore_3']))),
        ('밀물 둑길에서 5번 낚시하고, 물꼬에게 노정 건량 4개를 넘긴다', nd(PD, fi(SHORE, 5), give={'travel_ration': 4})),
        ('쪽빛 앞바다에 도착해 5번 탐색한다', nd(PD, tv(OFF), sr(OFF, 5))),
    ]),
    4: dict(L=51, region=OFF, items={'hw_coconut_fish': 2, 'spirit_core': 1}, steps=[
        ('떠나지 못하는 배들을 본다', nd(PD)),
        ('노정 건량 6개를 만들어 물꼬에게 넘긴다', nd(PD, cr('travel_ration', 6))),
        ('쪽빛 앞바다를 5번 탐색한다', nd(OFF, sr(OFF, 5))),
        ('쪽빛 앞바다에서 해초 비늘 껍질 5개를 모은다', nd(OFF, ga(OFF, 5, ['kelp_scale_shell']))),
        ('쪽빛 앞바다에서 물보라 날치와 가시 해파리 떼를 4번 쫓아낸다', nd(OFF, wi(4, OFF, ['hw_off_1', 'hw_off_2']))),
        ('쪽빛 앞바다에서 뒤집힌 물살 덩이를 2번 쫓아낸다', nd(OFF, wi(2, OFF, ['hw_off_3']))),
        ('쪽빛 앞바다에서 쉰다', nd(OFF, rs(OFF))),
        ('쪽빛 앞바다로 원정을 다녀온다', nd(OFF, ex(OFF))),
    ]),
    5: dict(L=51, region=RIFT, items={'flow_essence': 2, 'hw_bream_salt': 2}, steps=[
        ('파도너울성에서 기다리는 사람들을 만난다', nd(PD)),
        ('쪽빛 앞바다를 5번 탐색한다', nd(PD, sr(OFF, 5))),
        ('회춘단 4개를 지어 넘긴다', nd(PD, cr('rejuv_pill', 4))),
        ('뒤집힌 물목에 도착한다', nd(RIFT, tv(RIFT))),
        ('물길을 삼킨 것을 진압한다', nd(RIFT, {'t': 'dh', 'mode': 'story', 'n': 1})),
        ('뒤집힌 물목에서 소용돌이 물귀를 3번 쫓아낸다', nd(RIFT, wi(3, RIFT, ['hw_rift_1']))),
        ('염등촌에 도착해 소식을 전한다', nd(SALT, tv(SALT))),
        ('파도너울성에 도착해 쉰다', nd(PD, tv(PD), rs(PD))),
    ]),
    6: dict(L=51, region=PD, items={'hw_rice_noodle': 2, 'hw_leaf_rice': 3}, steps=[
        ('사건이 끝난 다음 날 아침을 맞는다', nd(PD)),
        ('자율 활동 「휴식」을 끝까지 마친다', nd(PD, idle('rest'))),
        ('밀물 둑길에서 5번 채집한다', nd(PD, ga(SHORE, 5))),
        ('파도너울성 널다리 물골에서 3번 낚시한다', nd(PD, fi(PD, 3))),
        ('파도너울성에서 쉰다', nd(PD, rs(PD))),
        ('파도너울성에서 물건을 판다', nd(PD, sl(PD))),
        ('노정 건량 6개를 만들어 넘기고, 밀물 둑길에서 4번 낚시한다', nd(PD, cr('travel_ration', 6), fi(SHORE, 4))),
    ]),
    7: dict(L=52, region=GEO, items={'hw_chili_fried_rice': 2, 'flow_essence': 2}, steps=[
        ('불이 흐르는 땅, 화덕골에 닿는다', nd(BS)),
        ('김 오르는 비탈을 5번 탐색한다', nd(BS, sr(GEO, 5))),
        ('화덕골 어귀 화덕 재 더미에서 정련 숯 3개를 모은다', nd(BS, ga(BS, 3, ['charcoal']))),
        ('김 오르는 비탈에서 화산 유리 5개를 모은다', nd(BS, ga(GEO, 5, ['volcanic_glass']))),
        ('화덕골에서 물건을 판다', nd(BS, sl(BS))),
        ('장인 손 연장 4벌을 벼려 넘긴다', nd(BS, cr('forge_tool_set', 4))),
        ('김 오르는 비탈에서 잿빛 불나방과 용암 도롱뇽을 4번 쫓아낸다', nd(GEO, wi(4, GEO, ['hw_geo_1', 'hw_geo_2']))),
        ('김 오르는 비탈로 원정을 다녀오고, 화덕골 들낫 4자루를 벼려 넘긴다', nd(BS, ex(GEO), cr('field_sickle', 4))),
    ]),
    8: dict(L=52, region=EBONY, items={'hw_rice_cookie': 3, 'hw_turmeric_broth': 2}, steps=[
        ('꿈이 내리지 않는 숲, 억새 나루에 닿는다', nd(JBV)),
        ('검은 고목 숲을 5번 탐색한다', nd(EBONY, sr(EBONY, 5))),
        ('쌀가루 과자 2개를 쪄서 새움에게 넘긴다', nd(EBONY, cr('hw_rice_cookie', 2))),
        ('검은 고목 숲에서 강황 뿌리 5개를 캔다', nd(JBV, ga(EBONY, 5, ['turmeric_root']))),
        ('먹빛 강 나루터에 도착해 4번 탐색한다', nd(FERRY, tv(FERRY), sr(FERRY, 4))),
        ('강황 약초즙 4잔을 달여 넘긴다', nd(EBONY, cr('hw_turmeric_broth', 4))),
        ('목공으로 끈 달린 나무 새를 만들어 새움에게 넘긴다', nd(EBONY, cr('wood_bird_toy', 1))),
        ('먹빛 강 나루터에서 4번 낚시하고, 검은 고목 숲에서 먹비 달팽이와 고목 껍질 도마뱀을 5번 쫓아낸다',
         nd(EBONY, fi(FERRY, 4), wi(5, EBONY, ['hw_ebony_1', 'hw_ebony_2']))),
    ]),
    9: dict(L=53, region=SNOW, items={'hw_butter_tea': 3, 'flow_essence': 2}, steps=[
        ('눈 속에서 돌아온 사람을 맞는다', nd(NMV)),
        ('깃발 설원에서 고원 보리 5개를 모은다', nd(NMV, ga(SNOW, 5, ['highland_barley']))),
        ('수유차 2잔을 끓여 설매에게 넘긴다', nd(NMV, cr('hw_butter_tea', 2))),
        ('외솔이 좋아하던 고원 만두 4개를 빚어 넘기고, 깃발 설원에서 눈표범 새끼와 얼음 까마귀 떼를 5번 쫓아낸다',
         nd(NMV, cr('hw_highland_dumpling', 4), wi(5, SNOW, ['hw_snow_1', 'hw_snow_2']))),
        ('눈마루 돌마을에서 쉰다', nd(NMV, rs(NMV))),
        ('깃발 설원에서 흐름 맺힌 정 2개를 모은다', nd(NMV, ga(SNOW, 2, ['flow_essence']))),
        ('깃발 설원을 5번 탐색한다', nd(NMV, sr(SNOW, 5))),
        ('깃발 설원으로 원정을 다녀온다', nd(NMV, ex(SNOW))),
    ]),
    10: dict(L=53, region=DM, items={'hw_spice_table': 2, 'hw_flatbread': 3}, steps=[
        ('모든 길이 모이는 곳, 달맞이성에 닿는다', nd(DM)),
        ('달맞이 들녘을 4번 탐색한다', nd(DM, sr(FIELD, 4))),
        ('납작빵 2개를 구워 바랑에게 넘긴다', nd(DM, cr('hw_flatbread', 2))),
        ('강황 약초즙 1잔을 달여 매솔에게 넘긴다', nd(DM, cr('hw_turmeric_broth', 1))),
        ('달맞이성에서 쉰다', nd(DM, rs(DM))),
        ('달그늘 대숲에서 4번 채집하고, 계단 우물 수로에서 4번 낚시한다', nd(DM, ga(BAMBOO, 4), fi(DM, 4))),
        ('달맞이 들녘에서 들쥐 떼와 밭고랑 땅벌을 4번 쫓아낸다', nd(DM, wi(4, FIELD, ['hw_field_1', 'hw_field_2']))),
        ('모음전에 붉은 향신 꼬투리 5개를 넘기고, 달맞이 들녘을 5번 탐색한다', nd(DM, sr(FIELD, 5), give={'red_spice_pod': 5})),
    ]),
    11: dict(L=54, region=POOL, items={'hw_spice_milk_tea': 3, 'flow_essence': 2}, steps=[
        ('낯익은 목소리를 듣는다', nd(DM)),
        ('달맞이성 어귀의 성문 우물 턱에서 미나리 2개를 모은다', nd(DM, ga(DM, 2, ['fd_minari']))),
        ('달그늘 대숲에서 야령초 5개를 캔다', nd(DM, ga(BAMBOO, 5, ['herb']))),
        ('강황 약초즙 4잔을 달여 새움에게 넘긴다', nd(DM, cr('hw_turmeric_broth', 4))),
        ('고임터에 도착해 5번 탐색한다', nd(POOL, tv(POOL), sr(POOL, 5))),
        ('고임터에서 고인 빛 덩이와 끌개 틈 그림자를 4번 해체한다', nd(POOL, wi(4, POOL, ['hw_pool_1', 'hw_pool_2']))),
        ('고임터에서 고인 빛 부스러기 2개를 모은다', nd(DM, ga(POOL, 2, ['pooled_light_shard']))),
        ('달맞이 들녘을 5번 탐색한다', nd(DM, sr(FIELD, 5))),
    ]),
    12: dict(L=54, region=DM, items={'spirit_core': 2, 'tonic': 3}, steps=[
        ('서로 다른 기록을 맞춰 본다', nd(DM)),
        ('본부 정청에 도착한다', nd(HQ, tv(HQ))),
        ('청심환 2개를 지어 연서희에게 넘긴다', nd(HQ, cr('tonic', 2))),
        ('자율 활동 「조사」를 끝까지 마친다', nd(HQ, idle('research'))),
        ('본부 정청에서 쉰다', nd(HQ, rs(HQ))),
        ('달맞이성에 도착한다', nd(DM, tv(DM))),
        ('향신 우유차 3잔을 끓여 청파에게 넘긴다', nd(DM, cr('hw_spice_milk_tea', 3))),
        ('달맞이 들녘을 5번 탐색한다', nd(DM, sr(FIELD, 5))),
    ]),
    13: dict(L=54, region=POOL, items={'flow_essence': 3, 'hw_spice_table': 2}, steps=[
        ('무너지는 길을 본다', nd(DM)),
        ('달맞이 들녘에서 솟은 흙 덩이를 5번 해체한다', nd(DM, wi(5, FIELD, ['hw_field_3']))),
        ('볶은 보릿가루 경단 4개를 만들어 바랑에게 넘긴다', nd(DM, cr('hw_barley_ball', 4))),
        ('회춘단 4개를 지어 넘긴다', nd(DM, cr('rejuv_pill', 4))),
        ('고임터에 도착해 4번 탐색한다', nd(POOL, tv(POOL), sr(POOL, 4))),
        ('고임터에서 얼굴 없는 형상과 넘친 기운 덩이를 4번 해체한다', nd(POOL, wi(4, POOL, ['hw_pool_3', 'hw_pool_4']))),
        ('땅이 우는 것을 진압한다', nd(DM, {'t': 'du', 'mode': 'story', 'n': 1})),
        ('달맞이성에서 쉬고, 달그늘 대숲에서 4번 채집한다', nd(POOL, rs(DM), ga(BAMBOO, 4))),
    ]),
    14: dict(L=55, region=HO, items={'hw_lotus_porridge': 3, 'flow_essence': 2}, steps=[
        ('풍요가 지나간 자리를 본다', nd(DM)),
        ('수로 보수 자재 4개를 짜 넘긴다', nd(DM, cr('channel_timber', 4))),
        ('고임터를 4번 탐색한다', nd(POOL, sr(POOL, 4))),
        ('달맞이성에서 자율 활동 「정비」를 끝까지 마친다', nd(DM, idle('maintenance'))),
        ('해오름성에 도착한다', nd(HO, tv(HO))),
        ('연밥 둑을 5번 탐색한다', nd(OUTER, sr(OUTER, 5))),
        ('해오름성에서 쉬고, 땅거미에 연밥 둑을 4번 탐색한다', nd(OUTER, rs(HO), sr(OUTER, 4, ['dusk']))),
        ('연밥 둑으로 원정을 다녀온다', nd(HO, ex(OUTER))),
    ]),
    15: dict(L=55, region=HO, items={'hw_sweet_sticky_rice': 3, 'flow_essence': 3}, steps=[
        ('어제와 다른 아침을 맞는다', nd(HO)),
        ('목공으로 나무 새 짝을 만들어 넘긴다', nd(HO, cr('wood_toy_pair', 1))),
        ('해오름성에서 물건을 판다', nd(HO, sl(HO))),
        ('첫볕 물가에 도착한다', nd(COAST, tv(COAST))),
        ('땅거미에 첫볕 물가를 4번 탐색한다', nd(COAST, sr(COAST, 4, ['dusk']))),
        ('연밥 죽 4그릇을 쑤어 넘긴다', nd(HO, cr('hw_lotus_porridge', 4))),
        ('첫볕 바위 물가에서 4번 낚시한다', nd(HO, fi(COAST, 4))),
        ('해돋이에 해오름성에서 쉰다', nd(HO, rs(HO, ['dawn']))),
    ]),
}


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


def ref_npcs():
    p = os.path.join(HERE, 'ref', 'npc_map.json')
    return json.load(open(p, encoding='utf-8')) if os.path.exists(p) else {}


NPCS = {}
SPEAK = dict(KNOWN)


def speaker_key(sp):
    if sp in SPEAK:
        return SPEAK[sp]
    if sp in MAIN_NPCS:
        k, bio = MAIN_NPCS[sp]
        NPCS[k] = (sp, bio)
    else:
        have = ref_npcs()
        if sp in have:
            SPEAK[sp] = have[sp]
            return have[sp]
        k = 'q:hw_x' + hashlib.md5(sp.encode()).hexdigest()[:6]
        NPCS[k] = (sp, '건넛누리 이야기에 나오는 사람.')
    SPEAK[sp] = k
    return k


def parse():
    chapters = {}
    bad_tags = []
    for path in SCRIPTS:
        src = open(path, encoding='utf-8').read()
        ch = scene = None
        grp = 0
        in_grp = False
        for raw in src.splitlines():
            line = raw.rstrip()
            m = re.match(r'^# (\d+)장 「(.+?)」\s*$', line)
            if m:
                ch = int(m.group(1)); chapters[ch] = dict(title=m.group(2), summary='', scenes=[]); scene = None
                continue
            if ch is None:
                continue
            if line.startswith('## '):
                scene = None
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
                d = {'s': speaker_key(sp), 't': text}
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
            if line.startswith('- '):
                scene['lines'].append({'s': None, 't': line[2:].strip()})
                in_grp = False
                continue
            if line.strip():
                in_grp = False
    return chapters, bad_tags


def build():
    chapters, bad = parse()
    if bad:
        raise SystemExit(f'갈래 표식 오류: {bad}')
    quests, steps = [], []
    for c in range(1, 16):
        P, C = PLAN[c], chapters[c]
        if len(C['scenes']) != len(P['steps']):
            raise SystemExit(f'{c}장 장면 수가 다름: 대본 {len(C["scenes"])} · 계획 {len(P["steps"])}')
        qid = QID + str(c)
        quests.append(dict(id=qid, cat=CAT, title=C['title'], L=P['L'], region=P['region'], after=AFTER_FIRST if c == 1 else [QID + str(c - 1)],
                           summary=C['summary'], items=P['items']))
        for k, s in enumerate(C['scenes']):
            goal, need = P['steps'][k]
            steps.append(dict(quest=qid, step=k + 1, title=s['title'], goal=goal, need=need, lines=[dict(x) for x in s['lines']]))
    return quests, steps


def check():
    chapters, bad = parse()
    errs, warns = [], []
    for c in range(1, 16):
        C = chapters[c]
        for k, s in enumerate(C['scenes']):
            want = PLACE.get(s['place'])
            if want is None:
                errs.append(f'{c}장 장면 {s["no"]} 장소 이름 모름: {s["place"]}')
                continue
            at = PLAN[c]['steps'][k][1]['at'][0]
            if at != want:
                warns.append(f'{c}장 장면 {s["no"]}: 대본 장소 {s["place"]}({want}) · 계획 {at}')
    return errs, warns


if __name__ == '__main__':
    e, w = check()
    q, s = build()
    print(f'퀘스트 {len(q)} · 장면 {len(s)} · 할 일 {sum(len(x["need"].get("tasks", [])) for x in s)} · 새 인물 {len(NPCS)}')
    for x in w: print('주의', x)
    for x in e: print('오류', x)
