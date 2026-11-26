import importlib.util
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, '..', '..', '..', 'tools', 'pet_art')

N = dict(trade=5000, catch=10, float=30, raid=10, exp=10, guard=20, feast=10)
PORT = {'pd_city': '파도너울성 선창', 'bs_town': '화덕골 부두', 'jb_village': '억새 나루 선창', 'ho_city': '첫볕 선창'}
TERR = {'pado': '파도너울성', 'bulssi': '불씨들녘', 'jaebit': '잿빛그늘숲', 'nunmaru': '눈마루', 'dalmaji': '달맞이성', 'haeoreum': '해오름성'}
STORY = {'jaebit': 'hwq_8', 'bulssi': 'hwq_7', 'nunmaru': 'hwq_9', 'haeoreum': 'hwq_14'}
REVEAL = {'ttangul': 'hwq_13', 'dohaesu': 'hwq_5'}
LAST = 'hwq_15'
GEAR = ['weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask']


def load(fn):
    spec = importlib.util.spec_from_file_location(fn[:-3], os.path.join(ART, fn))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return {k['key']: k for k in m.SKINS}


def rules(D, SQ):
    outer = {t: [r['id'] for r in D.REGIONS if r['terr'] == t and not r.get('safe')] for t in TERR}
    side = {t: [] for t in TERR}
    terr_of = {r['id']: r['terr'] for r in D.REGIONS}
    for q in SQ.build()[0]:
        t = terr_of.get(q['region'])
        if t in side:
            side[t].append(q['id'])
    nm_regs = [r['id'] for r in D.REGIONS if r['terr'] == 'nunmaru']
    nm_hab = {f[1] for f in D.FISH if f[0] in nm_regs}
    nm_fish = [f[0] for f in D.FISH_SPECIES if f[2] in nm_hab] + [f[0] for f in D.NAMED_FISH if f[5] in nm_regs]
    E = {}

    def e(key, by, src, **kw):
        E[key] = dict(how='earn', by=by, src=src, **kw)

    def tr(t):
        return TERR[t]
    e('little_stonecry', 'boss', '땅울이 깊은 판을 처음 쓰러뜨리기', boss='ttangul', n=1)
    e('golden_moon_rabbit', 'quest', '건넛누리 이야기 마지막 장을 마치기', q=[LAST])
    e('peacock_sparrow', 'survey', f'{tr("dalmaji")} 권역의 바깥 지역을 모두 완전 답사하기', regs=outer['dalmaji'])
    e('festive_elephant', 'side', f'{tr("dalmaji")} 권역의 보조 퀘스트를 모두 마치기', q=side['dalmaji'])
    e('feast_mask', 'feast_full', f'항구 잔칫상에 그릇을 올려 다 차린 상 {N["feast"]}번', k='feast_full', n=N['feast'])
    e('marigold_puppy', 'feast_eat', f'항구 잔칫상에서 「상에서 먹기」 {N["feast"]}번', k='feast_eat', n=N['feast'])
    e('coral_goldfish', 'boss', '도해수 깊은 판을 처음 쓰러뜨리기', boss='dohaesu', n=1)
    e('jade_whale', 'boss', '도해수 깊은 판을 10번 쓰러뜨리기', boss='dohaesu', n=10)
    e('wave_ddonggae', 'survey', f'{tr("pado")} 권역의 바깥 지역을 모두 완전 답사하기', regs=outer['pado'])
    e('kingfisher_magpie', 'side', f'{tr("pado")} 권역의 보조 퀘스트를 모두 마치기', q=side['pado'])
    e('coconut_crab', 'trade', f'{PORT["pd_city"]}에서 교역품을 정가 합 {N["trade"]:,}전어치 팔기', k='trade:pd_city', n=N['trade'])
    e('boatman_otter', 'ship', '배를 대양함선까지 올리기', n=5)
    e('monsoon_cloud', 'raid', f'뱃길 습격을 {N["raid"]}번 물리치기', k='raid', n=N['raid'])
    e('pandan_squirrel', 'quest', f'{tr("jaebit")} 이야기 장을 마치기', q=[STORY['jaebit']])
    e('umbrella_mushroom', 'survey', f'{tr("jaebit")} 권역의 바깥 지역을 모두 완전 답사하기', regs=outer['jaebit'])
    e('silvergrass_fawn', 'side', f'{tr("jaebit")} 권역의 보조 퀘스트를 모두 마치기', q=side['jaebit'])
    e('turmeric_cat', 'trade', f'{PORT["jb_village"]}에서 교역품을 정가 합 {N["trade"]:,}전어치 팔기', k='trade:jb_village', n=N['trade'])
    e('plantain_raccoon', 'catch', f'{PORT["jb_village"]}에서 등불 {N["catch"]}번 건지기', port='jb_village', n=N['catch'])
    e('inkrain_firefly', 'float', f'등불 편지를 {N["float"]}번 띄우기', n=N['float'])
    e('ebony_pangolin', 'codex', f'{tr("jaebit")} 권역 요괴를 도감에 모두 쓰러뜨려 올리기', regs=outer['jaebit'])
    e('flag_crane', 'quest', f'{tr("nunmaru")} 이야기 장을 마치기', q=[STORY['nunmaru']])
    e('snow_leopard_cat', 'survey', f'{tr("nunmaru")} 권역의 바깥 지역을 모두 완전 답사하기', regs=outer['nunmaru'])
    e('yak_calf', 'side', f'{tr("nunmaru")} 권역의 보조 퀘스트를 모두 마치기', q=side['nunmaru'])
    e('snow_owl', 'codex', f'{tr("nunmaru")} 권역 요괴를 도감에 모두 쓰러뜨려 올리기', regs=outer['nunmaru'])
    e('milk_longhair', 'exp', f'{tr("nunmaru")} 권역 원정을 {N["exp"]}번 끝까지 다녀오기', regs=outer['nunmaru'], n=N['exp'])
    e('pass_glider', 'exp_full', '깃발 설원 원정을 핵심까지 완전 답사하기', region='nm_snow', n=1)
    e('icepond_seal', 'fishdex', f'{tr("nunmaru")} 낚시터에서 나는 건넛누리 어종을 모두 낚기', fish=nm_fish)
    e('barley_bear', 'guard', f'{tr("nunmaru")} 권역 우두머리를 {N["guard"]}번 토벌하기', regs=outer['nunmaru'], k='guard:nunmaru', n=N['guard'])
    e('ember_puppy', 'quest', f'{tr("bulssi")} 이야기 장을 마치기', q=[STORY['bulssi']])
    e('ember_wisp', 'survey', f'{tr("bulssi")} 권역의 바깥 지역을 모두 완전 답사하기', regs=outer['bulssi'])
    e('chili_crab', 'side', f'{tr("bulssi")} 권역의 보조 퀘스트를 모두 마치기', q=side['bulssi'])
    e('brass_ladybug', 'craft', '9단계 장비를 처음 만들기', tier=9, cats=GEAR, n=1)
    e('obsidian_beetle', 'trade', f'{PORT["bs_town"]}에서 교역품을 정가 합 {N["trade"]:,}전어치 팔기', k='trade:bs_town', n=N['trade'])
    e('ember_frog', 'catch', f'{PORT["bs_town"]}에서 등불 {N["catch"]}번 건지기', port='bs_town', n=N['catch'])
    e('redsap_boar', 'codex', f'{tr("bulssi")} 권역 요괴를 도감에 모두 쓰러뜨려 올리기', regs=outer['bulssi'])
    e('gold_puppet', 'quest', f'{tr("haeoreum")} 이야기 장을 마치기', q=[STORY['haeoreum']])
    e('lotus_fox', 'survey', f'{tr("haeoreum")} 권역의 바깥 지역을 모두 완전 답사하기', regs=outer['haeoreum'])
    e('palm_sugar_rabbit', 'side', f'{tr("haeoreum")} 권역의 보조 퀘스트를 모두 마치기', q=side['haeoreum'])
    e('lotus_lantern', 'catch', f'{PORT["ho_city"]}에서 등불 {N["catch"]}번 건지기', port='ho_city', n=N['catch'])
    e('lotusleaf_newt', 'trade', f'{PORT["ho_city"]}에서 교역품을 정가 합 {N["trade"]:,}전어치 팔기', k='trade:ho_city', n=N['trade'])
    for v in E.values():
        if v.get('boss') in REVEAL:
            v['reveal'] = REVEAL[v['boss']]
    return E, side


def emit(D, SQ, errors, J):
    old, new = load('skins.py'), load('skins_40.py')
    E, side = rules(D, SQ)
    if set(E) != set(new):
        errors.append('무늬 얻는 길과 그림이 다름: ' + ', '.join(sorted(set(E) ^ set(new))))
    for k, v in E.items():
        if v.get('boss') and v['boss'] not in REVEAL:
            errors.append('보스 무늬에 보일 때(reveal)가 없음: ' + k)
    for t, qs in side.items():
        if not qs:
            errors.append('보조 퀘스트가 없는 권역: ' + t)
    for k, v in E.items():
        if v['by'] in ('survey', 'codex', 'exp', 'guard') and not v.get('regs'):
            errors.append('지역이 빈 무늬: ' + k)
    skins = {k: {'pet': s['pet'], 'name': s['name'], 'how': 'pet'} for k, s in old.items()}
    for k, s in new.items():
        if k in E:
            skins[k] = {'pet': s['pet'], 'name': s['name'], **E[k]}
    body = json.dumps({'skins': skins}, ensure_ascii=False, separators=(',', ':'))
    head = f"""create or replace function public.world_pet_skin_rules() returns jsonb language sql immutable set search_path = pg_catalog as $R$
  select $J${body}$J$::jsonb
$R$;
"""
    return head + open(os.path.join(HERE, 'engine.sql')).read()
