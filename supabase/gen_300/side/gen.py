import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORLD = os.path.join(os.path.dirname(HERE), 'world')
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, WORLD)
import data_quests as DQ
import data_world as DW

REF = json.load(open(os.path.join(HERE, 'ref.json'), encoding='utf-8'))
ARC = '외전·명등기'
SORT0 = 1420

LANDING, YAMEN, MARTIAL, SHRINE, OFM, REST, FOBS, PALACE, PACT, VAULT = (
    'deungdo_landing', 'dark_yamen', 'martial_row', 'red_shrine_lane', 'old_ferry_market', 'lamp_rest', 'first_observatory', 'ash_palace', 'pact_court', 'jeongni_vault')

META = {
    'mds_n_lamp': (45, LANDING, '낚시', ['mdq_5']),
    'mds_n_gold': (48, OFM, '낚시', ['mdq_11']),
    'mds_skiff': (45, LANDING, '제작', ['mdq_5']),
    'mds_tally': (45, LANDING, '조사', ['mdq_5']),
    'mds_shoes': (45, YAMEN, '채집', ['mdq_5']),
    'mds_dummy': (46, MARTIAL, '전투', ['mdq_6']),
    'mds_arrows': (46, MARTIAL, '채집', ['mdq_7']),
    'mds_lantern': (47, SHRINE, '제작', ['mdq_8']),
    'mds_prayer': (47, SHRINE, '조사', ['mdq_9']),
    'mds_cargo': (48, OFM, '조사', ['mdq_10']),
    'mds_lampshop': (48, REST, '제작', ['mdq_10']),
    'mds_ledger': (49, FOBS, '조사', ['mdq_12']),
    'mds_bison': (49, PALACE, '전투', ['mdq_14']),
    'mds_scale': (50, VAULT, '조사', ['mdq_17']),
    'mds_hands': (50, VAULT, '채집', ['mdq_17']),
    'mds_seven': (50, PACT, '제작', ['mdq_17']),
    'mde_danbi_1': (50, 'ledger_cellar', ARC, ['mdq_17']),
    'mde_danbi_2': (50, 'red_plain', ARC, ['mde_danbi_1']),
    'mde_unbi_1': (50, MARTIAL, ARC, ['mdq_17']),
    'mde_unbi_2': (50, 'iron_monastery', ARC, ['mde_unbi_1']),
    'mde_cheongpa_1': (50, OFM, ARC, ['mdq_17']),
    'mde_cheongpa_2': (50, OFM, ARC, ['mde_cheongpa_1']),
    'mde_galmae_1': (50, YAMEN, ARC, ['mdq_17']),
    'mde_galmae_2': (50, 'ember_village', ARC, ['mde_galmae_1']),
    'mde_haram_1': (50, 'star_observatory', ARC, ['mdq_17']),
    'mde_haram_2': (50, 'star_observatory', ARC, ['mde_haram_1']),
    'mde_hanseol': (50, 'hq_yard', ARC, ['mde_danbi_2', 'mde_unbi_2', 'mde_cheongpa_2', 'mde_galmae_2', 'mde_haram_2']),
}

NPCS = {
    'q:sx_md_maksoe': ('흑련 문지기 막쇠', '흑련 장부고 문을 지키던 문지기. 칼을 늘 칼집째 쥐고 다니며 말수가 적다. 남문 수로 선착 야영소를 지키러 등도까지 내려왔다.'),
    'q:sx_md_durye': ('흑련 문지기 두례', '흑련 장부고 문지기. 겁이 많아 칼끝이 떨리지만 칼을 내려놓지는 않는다.'),
    'q:sx_md_makdong': ('흑련 문지기 막동이', '흑련 문지기 막내. 어머니가 앓아누운 뒤로 밤마다 어머니 이름을 불러 드려, 글자만 보면 소리 내어 읽는다.'),
    'q:sx_md_satdae': ('수향 뱃사람 삿대', '청파와 같은 나루에서 자란 젊은 뱃사람. 거룻배로 봉인고와 남문 수로 선착을 오가며 짐을 나른다.'),
    'q:sx_md_ongsim': ('수향 뱃사람 옹심', '등지기 쉼막에 사는 수향 뱃사람. 쉼막 등에 넣을 기름을 얻으러 다닌다. 남의 물건에 손대기 전에 꼭 고개를 숙인다.'),
    'q:sx_md_gaedong': ('그물 깁는 개동 영감', '구름나루 선창 끝에서 그물을 깁는 여든 남짓한 노인. 어려서 구름나루 장부방 사환이었다.'),
    'q:sx_md_hambak': ('쉼막 맏이 함박', '등지기 쉼막에 거처를 차린 수향 뱃사람들의 맏이. 손이 커서 무엇이든 넉넉히 퍼 준다.'),
    'q:sx_md_eopdong': ('저울추지기 업동', '정리소에서 마흔 해 동안 가늠 저울추를 닦던 사람. 진이 꺼진 뒤 발밑에 그림자가 돌아왔다.'),
    'q:sx_md_eonnyeon': ('엿집 할멈 언년', '적사 황무지 어귀 사당 아랫마을에서 사당에 올릴 엿을 고는 노파. 엿 주걱을 손에서 놓지 않는다.'),
    'q:sx_md_meoru': ('잔불촌 아낙 머루댁', '갈매를 어릴 때부터 「갈매야」라고 부르던 잔불촌 아낙. 말끝마다 혀를 끌끌 찬다.'),
    'q:sx_md_chunbo': ('객사 이야기꾼 춘보', '본부 객사 대청에서 손님들에게 무용담을 들려주는 이야기꾼. 숫자는 서너 곱절 부풀려도 이름은 버리지 않는다.'),
    'q:sx_md_elder': ('잔불촌 노인', '잔불촌 화로 곁에서 밤을 새우는 마을 노인.'),
}
NEW_SPEAK = {'막쇠': 'q:sx_md_maksoe', '두례': 'q:sx_md_durye', '막동이': 'q:sx_md_makdong', '삿대': 'q:sx_md_satdae', '옹심': 'q:sx_md_ongsim',
             '개동': 'q:sx_md_gaedong', '함박': 'q:sx_md_hambak', '업동': 'q:sx_md_eopdong', '언년': 'q:sx_md_eonnyeon', '머루댁': 'q:sx_md_meoru',
             '춘보': 'q:sx_md_chunbo', '노인': 'q:sx_md_elder', '진소랑(서신)': 'river_alliance:jin'}
SPEAK = dict(DQ.SPEAK); SPEAK.update(NEW_SPEAK)

KEEP_DESC = '별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.'
KEEPSAKE = {
    'mde_danbi_2': {'title': ('md_keep_danbi', '엿집 동업자'),
                    'item': ('hf_md_yeotjar', '앵두 엿 항아리', '소품', '뚜껑에 아이 손자국이 남은 엿 항아리입니다. 동짓밤마다 엿을 가득 채워 적사 황무지로 들고 갑니다.',
                             {'hk': 'md_yeotjar', 'kind': 'surface', 'w': 1, 'd': 1, 'top': 0})},
    'mde_unbi_2': {'title': ('md_keep_unbi', '바람을 물려받은 이'),
                   'item': ('hf_md_swordrack', '붉은 술 단 칼걸이', '소품', '여씨 집안 목인 받침 나무로 짠 칼걸이입니다. 윗단에 붉은 술 끈이 매여 있어 창을 열면 바람 부는 쪽으로 날립니다.',
                            {'hk': 'md_swordrack', 'kind': 'floor', 'w': 1, 'd': 1, 'top': 0})},
    'mde_cheongpa_2': {'title': ('md_keep_cheongpa', '다음 배의 뱃사람'),
                       'item': ('hf_md_shipmodel', '청씨 배 모형', '소품', '노들 영감이 깎은 손바닥만 한 배입니다. 돛대 밑에 금 서른둘이 새겨져 있고, 실처럼 가는 청씨 깃발이 달려 있습니다.',
                                {'hk': 'md_shipmodel', 'kind': 'surface', 'w': 1, 'd': 1, 'top': 0})},
    'mde_galmae_2': {'title': ('md_keep_galmae', '화로 곁에 앉은 이'),
                     'item': ('hf_md_brazier', '남명 화로', '조명', '장무현 화로의 흰 불씨를 나눠 담은 놋쇠 화로입니다. 뚜껑 틈으로 흔들리지 않는 흰빛이 새어 나옵니다.',
                              {'hk': 'md_brazier', 'kind': 'floor', 'w': 1, 'd': 1, 'top': 0})},
    'mde_haram_2': {'title': ('md_keep_haram', '빈 별을 받아 적은 이'),
                    'item': ('hf_md_starplate', '작은 별 기록판', '족자', '하후정이 첫 관상대 별 기록판을 줄여 깎은 돌판입니다. 송곳 점으로 「빈」의 자리와 엉뚱한 데 찍힌 점 하나가 남아 있습니다.',
                             {'hk': 'md_starplate', 'kind': 'wall', 'wall': 'deco', 'ww': 1.2, 'wh': 30})},
    'mde_hanseol': {'title': ('md_keep_hanseol', '해마다 등을 켜는 이'),
                    'item': ('hf_md_feastlamp', '명등제 등롱', '조명', '이름을 적자 기름 없이 불이 붙은 등롱입니다. 아랫단에 「내년 동지 · 꺼진 관아 터」가 적혀 있습니다.',
                             {'hk': 'md_feastlamp', 'kind': 'wall', 'wall': 'deco', 'ww': 1, 'wh': 40})},
}
TITLE_DESC = {
    'mde_danbi_2': '단비와 함께 판 이름의 나머지 반쪽을 찾아, 모래 우물 집 마당에 등을 켰다.',
    'mde_unbi_2': '여운비에게서 붉은 술 몇 가닥과 앞에 서는 자리를 물려받았다.',
    'mde_cheongpa_2': '청파와 함께 일흔 해 땅에 앉아 있던 청씨 배를 띄워, 서른두 이름을 그 아이들이 가야 했던 물가까지 데려갔다.',
    'mde_galmae_2': '잔불촌 화로의 흰 불씨를 다시 피우고, 갓난아이 새벽의 이름 짓는 날 굵은 국수를 나눠 먹었다.',
    'mde_haram_2': '두 눈을 잃은 관측관과 함께 새 별 「빈」의 자리를 재고, 그 관측관이 처음 사람의 명부에 적히는 밤을 지켰다.',
    'mde_hanseol': '두 번째 명등제에서 등도에서 찾은 이름들을 등롱에 적고, 「등도 · 꺼진 관아 터」 장의 부르는 이 칸에 이름을 적었다.',
}

ALIAS = {'본부 정청': 'hq_yard'}
IDLE_K = {'수련': 'training', '조사': 'research', '정비': 'maintenance', '휴식': 'rest'}
UNIT = r'(?:개|마리|줌|덩이|그릇|벌|장|번|회|병|단지|대)?'

ITEMS = REF['items']; MONS = REF['monsters']; RECIPES = REF['recipes']; SPOTS = REF['spots']
FISHING = set(REF['fishing']); FISH = REF['fish']
REGIONS = {k: v for k, v in REF['regions'].items()}
for a, rid in ALIAS.items():
    REGIONS[a] = next(v for v in REF['regions'].values() if v[0] == rid)
REGION_NAMES = sorted(REGIONS, key=len, reverse=True)
REGION_BY_ID = {v[0]: k for k, v in REF['regions'].items()}
SAFE = {v[0] for v in REF['regions'].values() if v[2]}
ITEM_NAME = {v: k for k, v in ITEMS.items()}
for _q, ks in KEEPSAKE.items():
    ITEM_NAME[ks['item'][0]] = ks['item'][1]
MON_NAME = {m[0]: k for k, v in MONS.items() for m in v}
FISH_NAME = {v[0]: k for k, v in FISH.items()}
REG_LV = {v[0]: v[1] for v in REF['regions'].values()}
MON_LV = {m[0]: m[2] for v in MONS.values() for m in v}
MON_MIN = {}
for _v in MONS.values():
    for _m in _v:
        MON_MIN[_m[1]] = min(MON_MIN.get(_m[1], 99), _m[2])
NO_PLACE = ('탐색', '처치', '모으기', '채집', '원정', '실마리')
errors, warns = [], []


def region_of(text):
    for n in REGION_NAMES:
        if n in text:
            return REGIONS[n][0]
    return None


def strip_note(p):
    return re.sub(r'\s*\([^)]*\)\s*$', '', p).strip()


def strip_region(p):
    for n in REGION_NAMES:
        p = re.sub(re.escape(n) + r'\s*(에서|에|으로|로)?\s*', '', p, count=1)
    return p.strip()


def item_id(name, q):
    name = name.strip()
    if name in ITEMS:
        return ITEMS[name]
    errors.append(f'{q}: 물품 이름 모름 — {name}')
    return name


def level_check(t, L, q, p):
    r = (t.get('r') or [None])[0]
    if r and REG_LV.get(r, 0) > L:
        errors.append(f'{q}: 퀘스트 Lv{L}보다 높은 지역 {REGION_BY_ID.get(r, r)}(Lv{REG_LV.get(r)}) — {p}')
    lv = None
    if t['t'] == 'gather':
        lv = REF['spot_lv'].get(r, {}).get(t['items'][0]) if 'items' in t else REF['spot_min'].get(r)
    elif t['t'] == 'win':
        lv = MON_LV.get(t['m'][0]) if 'm' in t else MON_MIN.get(r)
    elif t['t'] == 'expedition':
        lv = REF['ground_min'].get(r)
    elif t['t'] in ('search', 'clue'):
        lv = REF['node_min'].get(r)
    if lv is not None and lv > L:
        errors.append(f'{q}: 퀘스트 Lv{L}보다 높은 출입 레벨 Lv{lv} — {p}')
    if t['t'] == 'fish' and 'f' in t and META.get(q, (0, 0, ''))[2] != '낚시':
        errors.append(f'{q}: 정해진 물고기를 낚는 할 일(운·시간대·날씨에 기댐) — {p}')
    if t.get('phase') or t.get('weather'):
        errors.append(f'{q}: 시간대·날씨 할 일 — {p}')
    return t


def parse_task(p, ctx, q, L):
    r = _parse_task(p, ctx, q, L)
    if r and r[0] == 'task':
        level_check(r[1], L, q, p)
    if os.environ.get('SIDE_LIST') and r:
        sys.stderr.write(f'  {q} {p}\n')
    return r


def _parse_task(p, ctx, q, L):
    p = strip_note(p)
    r = region_of(p)
    rr = [r] if r else ctx[:1]
    body = strip_region(p)
    if r in SAFE and any(body.endswith(x) or x in body for x in NO_PLACE):
        errors.append(f'{q}: 안전지대에서 하는 할 일 — {p}')
    m = re.match(r'^탐색\s*(\d+)\s*회?$', body)
    if m:
        return ('task', {'t': 'search', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^실마리\s*(\d+)\s*' + UNIT + '$', body)
    if m:
        return ('task', {'t': 'clue', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^낚시\s*(\d+)\s*회?$', body)
    if m:
        if rr[0] not in FISHING:
            errors.append(f'{q}: 낚시터 없는 곳 {rr[0]}')
        return ('task', {'t': 'fish', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^(.+?)\s*(?:(\d+)\s*마리\s*)?낚기$', body)
    if m:
        fn = m.group(1).strip()
        if fn not in FISH:
            errors.append(f'{q}: 물고기 이름 모름 — {fn}')
            return None
        fid, hab, grounds, named, _ = FISH[fn]
        if grounds and rr[0] not in grounds:
            errors.append(f'{q}: {fn}은 {grounds}에서만 — {rr[0]}')
        return ('task', {'t': 'fish', 'r': rr, 'f': [fid], 'n': int(m.group(2) or 1)})
    if body == '쉬기':
        return ('task', {'t': 'rest', 'r': rr, 'n': 1})
    m = re.match(r'^자율 활동(?:\s*「(.+?)」)?\s*마치기$', body)
    if m:
        t = {'t': 'idle', 'n': 1}
        if m.group(1):
            if m.group(1) not in IDLE_K:
                errors.append(f'{q}: 자율 활동 종류 모름 — {m.group(1)}')
            else:
                t['k'] = IDLE_K[m.group(1)]
        return ('task', t)
    m = re.match(r'^원정\s*(\d+)\s*회?$', body)
    if m:
        return ('task', {'t': 'expedition', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^채집\s*(\d+)\s*회?$', body)
    if m:
        if not SPOTS.get(rr[0]):
            errors.append(f'{q}: 채집터 없는 곳 {rr[0]}')
        return ('task', {'t': 'gather', 'r': rr, 'n': int(m.group(1))})
    if body == '도착':
        if not r:
            errors.append(f'{q}: 도착할 곳 모름 — {p}')
        return ('task', {'t': 'travel', 'r': rr, 'n': 1})
    m = re.match(r'^요괴\s*(\d+)\s*' + UNIT + r'\s*처치$', body)
    if m:
        return ('task', {'t': 'win', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^(.+?)\s*(\d+)\s*' + UNIT + r'\s*(모으기|처치|만들기|넘기기)$', body)
    if not m:
        errors.append(f'{q}: 할 일을 못 읽음 — {p}')
        return None
    name, n, verb = m.group(1).strip(), int(m.group(2)), m.group(3)
    if verb == '처치':
        c = MONS.get(name)
        if not c:
            errors.append(f'{q}: 요괴 이름 모름 — {name}')
            return None
        mid = next((x[0] for x in c if x[1] in ctx), None)
        if not mid:
            warns.append(f'{q}: {name}은(는) {[x[1] for x in c]}에 나옴 — 장면 곳 {ctx}')
            mid = c[0][0]
        return ('task', {'t': 'win', 'm': [mid], 'n': n})
    iid = item_id(name, q)
    if verb == '모으기':
        if not r:
            errors.append(f'{q}: 모을 곳을 적지 않음 — {p}')
        elif iid not in SPOTS.get(rr[0], []):
            errors.append(f'{q}: {REGION_BY_ID.get(rr[0], rr[0])} 채집터에 {name} 없음')
        return ('task', {'t': 'gather', 'items': [iid], 'r': rr, 'n': n})
    if verb == '만들기':
        rc = RECIPES.get(iid)
        if not rc:
            errors.append(f'{q}: 제작법 없음 — {name}')
        elif rc[1] > L:
            errors.append(f'{q}: {name} 제작 레벨 {rc[1]}이 퀘스트 레벨 {L}보다 높음')
        return ('task', {'t': 'craft', 'items': [iid], 'n': n})
    return ('give', (iid, n))


def parse_files(paths):
    quests = []
    for path in paths:
        cur = scene = None
        grp = 0
        in_grp = False
        for raw in open(path, encoding='utf-8'):
            line = raw.rstrip('\n')
            h = re.match(r'^###\s+「(.+?)」\s*·\s*Lv(\d+)\s*·\s*([^·]+?)\s*·', line)
            if h:
                cur = dict(title=h.group(1), L=int(h.group(2)), place=h.group(3).strip(), id=None, after=None, summary='', scenes=[], file=os.path.basename(path))
                quests.append(cur)
                scene = None
                continue
            if line.startswith('## '):
                cur = scene = None
                continue
            if cur is None:
                continue
            m = re.match(r'^id:\s*(\S+)\s*·\s*앞:\s*(.+)$', line)
            if m:
                cur['id'] = m.group(1)
                cur['after'] = [x.strip() for x in m.group(2).split('·')]
                continue
            if line.startswith('요약:'):
                cur['summary'] = line[3:].strip()
                continue
            s = re.match(r'^####\s+장면\s*(\d+)\s*·\s*(.+?)\s*\((받기|보고)\s*:\s*(.+?)\)\s*$', line)
            if s:
                place = region_of(s.group(4))
                if not place:
                    errors.append(f"{cur['title']}: 장면 곳 모름 — {s.group(4)}")
                scene = dict(no=int(s.group(1)), title=s.group(2).strip(), kind=s.group(3), place=place, lines=[], todo=None)
                cur['scenes'].append(scene)
                grp = 0
                in_grp = False
                continue
            if scene is None:
                continue
            m = re.match(r'^-\s+할 일:\s*(.+)$', line)
            if m:
                scene['todo'] = m.group(1).strip()
                in_grp = False
                continue
            if re.match(r'^-\s+보상', line):
                continue
            m = re.match(r'^-\s+(?:\[([^\]]+)\]\s+)?([^:\[\]]+?):\s*(.+)$', line)
            if not m:
                if line.strip():
                    in_grp = False
                continue
            tag, who, text = m.group(1), m.group(2).strip(), m.group(3).strip()
            if who == '서술':
                d = {'s': None, 't': text}
            else:
                if who not in SPEAK or SPEAK[who] is None:
                    errors.append(f"{cur['title']} 장면 {scene['no']}: 말하는 이 모름 — {who}")
                d = {'s': SPEAK.get(who), 't': text}
            if tag:
                k = DQ.parse_tag(tag)
                if k is None:
                    errors.append(f"{cur['title']} 장면 {scene['no']}: 갈래 머리 해석 못 함 — {tag}")
                else:
                    if not in_grp:
                        grp += 1
                        in_grp = True
                    d.update(k)
                    d['grp'] = grp
            else:
                in_grp = False
            scene['lines'].append(d)
    return quests


def goal_text(tasks, give):
    out = []
    for t in tasks:
        rg = REGION_BY_ID.get((t.get('r') or [None])[0], '')
        if t['t'] == 'gather':
            out.append(f"{rg}에서 {ITEM_NAME.get(t['items'][0])}을(를) 모은다" if 'items' in t else f"{rg}에서 채집한다")
        elif t['t'] == 'win':
            out.append(f"{MON_NAME.get(t['m'][0])}을(를) 물리친다" if 'm' in t else f"{rg}의 요괴를 물리친다")
        elif t['t'] == 'craft':
            out.append(f"{ITEM_NAME.get(t['items'][0])}을(를) 만든다")
        elif t['t'] == 'search':
            out.append(f"{rg}을(를) 살핀다")
        elif t['t'] == 'clue':
            out.append(f"{rg}에서 실마리를 찾는다")
        elif t['t'] == 'fish':
            out.append(f"{rg}에서 {FISH_NAME.get(t['f'][0])}을(를) 낚는다" if 'f' in t else f"{rg}에서 낚시를 한다")
        elif t['t'] == 'rest':
            out.append(f"{rg}에서 쉰다")
        elif t['t'] == 'idle':
            out.append('자율 활동을 끝까지 마친다')
        elif t['t'] == 'expedition':
            out.append(f"{rg}에 원정을 다녀온다")
        elif t['t'] == 'travel':
            out.append(f"{rg}에 간다")
    for k in give:
        out.append(f"{ITEM_NAME.get(k, k)}을(를) 넘긴다")
    return ', '.join(out)


def check_lines(q):
    for s in q['scenes']:
        for ln in s['lines']:
            t = ln['t'].rstrip()
            if ln['s'] is None and t.endswith('.') and not t.endswith('」.') and t[-2] not in '다요까지네죠오소군라야자어아해니게':
                errors.append(f"{q['id']} 「{s['title']}」 서술 끝맺음 확인 — …{t[-20:]}")
            if re.search(r'(?<![가-힣])(me|ME):', t):
                errors.append(f"{q['id']}: 주인공 말하는 이")


GENERIC = {'영감', '노인', '할멈', '아이', '아낙'}
NAME_OK = {('잔불촌', '잔불촌'), ('두례', '두칠'), ('두례', '두석'), ('춘보', '춘화')}


def base_name(n):
    ws = [x for x in n.split('(')[0].split() if x not in GENERIC]
    return ws[-1] if ws else ''


def near(a, b):
    if not a or not b:
        return False
    if a == b:
        return True
    if len(a) != len(b) or sum(x != y for x, y in zip(a, b)) != 1:
        return False
    return len(a) > 2 or a[0] == b[0]


def check_names():
    old = [n for n in REF['npcs'] if REF['npcs'][n] not in NPCS] + list(REF['faction_npcs'].values())
    for k, (nm, _) in NPCS.items():
        b = base_name(nm)
        for o in old:
            ob = base_name(o)
            if near(b, ob) and (b, ob) not in NAME_OK and nm != o:
                errors.append(f'새 인물 이름이 기존과 닮음: {nm} / {o}')
    titles = {k: v for k, v in REF['titles'].items() if not k.startswith('md_keep_')}
    for q, ks in KEEPSAKE.items():
        key, nm = ks['title']
        for tk, tv in titles.items():
            if tv == nm or tv.endswith(nm) or nm.endswith(tv):
                errors.append(f'칭호 이름 겹침: {nm} / {tv}({tk})')
        iid, inm = ks['item'][0], ks['item'][1]
        if inm in ITEMS and ITEMS[inm] != iid:
            errors.append(f'기념 가구 이름 겹침: {inm}')


def T(s):
    return 'null' if s is None else "'" + str(s).replace("'", "''") + "'"


def J(o):
    return T(json.dumps(o, ensure_ascii=False)) + '::jsonb'


RULES = REF['reward_rules']['side']


def reward_items(L):
    return dict(next((it for top, it in RULES['items'] if L <= top), RULES['items'][-1][1]))


def build(quests):
    out = []
    w = out.append
    for k, (nm, bio) in sorted(NPCS.items()):
        w(f"insert into public.world_quest_npcs(npc_key, npc_name, bio) values ({T(k)}, {T(nm)}, {T(bio)}) on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;")
    furn = open(os.path.join(ROOT, 'assets', 'js', 'housing', 'furniture.js'), encoding='utf-8').read()
    rows = []
    for q, ks in KEEPSAKE.items():
        iid, nm, cat, desc, tr = ks['item']
        if f"  {tr['hk']}: {{" not in furn:
            errors.append(f'furniture.js에 {tr["hk"]} 없음')
        traits = dict(tr, cat=cat, grade=4)
        rows.append(f"({T(iid)}, {T(nm)}, 'furniture', 4, {T('별채 가구 · ' + cat + '. ' + desc + ' ' + KEEP_DESC)}, false, false, 800, 1, {J(traits)})")
    w("""insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values
""" + ',\n'.join(rows) + """
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  stackable = excluded.stackable, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size, equipment_traits = excluded.equipment_traits;""")
    for q, ks in KEEPSAKE.items():
        key, nm = ks['title']
        title = next(x['title'] for x in quests if x['id'] == q)
        w(f"""insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, hidden, rule, sort, category, grade)
values ({T(key)}, {T(nm)}, {T(TITLE_DESC[q])}, {T('「' + title + '」을(를) 마친다')}, '{{}}'::jsonb, false, null, 3300, '명등기', 4)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, category = excluded.category, grade = excluded.grade;""")
    order = sorted(quests, key=lambda x: (x['L'], x['id'].startswith('mde_'), x['id']))
    for i, q in enumerate(order):
        L, reg, field, after = META[q['id']]
        check_lines(q)
        sc = q['scenes']
        if len(sc) < 3:
            errors.append(f"{q['id']}: 장면이 셋보다 적음")
        for s0 in sc:
            if s0['place'] and REG_LV.get(s0['place'], 0) > L:
                errors.append(f"{q['id']} 장면 {s0['no']}: 퀘스트 Lv{L}보다 높은 곳 {REGION_BY_ID.get(s0['place'])}")
        if sc and sc[0]['place'] != reg:
            errors.append(f"{q['id']}: 받는 곳이 META와 다름 {sc[0]['place']} / {reg}")
        steps = []
        for k, s in enumerate(sc):
            need = {'at': [s['place']]}
            goal = s['title']
            if k > 0:
                todo = sc[k - 1]['todo']
                if not todo:
                    errors.append(f"{q['id']}: 장면 {k} 끝에 할 일이 없음")
                else:
                    tasks, give = [], {}
                    ctx = [x for x in (sc[k - 1]['place'], s['place'], reg) if x]
                    for p in [x.strip() for x in re.split(r'\s+·\s+', todo) if x.strip()]:
                        r = parse_task(p, ctx, q['id'], L)
                        if not r:
                            continue
                        if r[0] == 'task':
                            tasks.append(r[1])
                        else:
                            give[r[1][0]] = give.get(r[1][0], 0) + r[1][1]
                    for t in tasks:
                        if t['t'] == 'craft':
                            for iid in t['items']:
                                give.setdefault(iid, t['n'])
                    kinds = [t['t'] for t in tasks]
                    if kinds == ['travel'] and not give:
                        errors.append(f"{q['id']} 장면 {k + 1}: 이동만 하는 할 일")
                    if len(tasks) + (1 if give and not any(t['t'] == 'craft' for t in tasks) else 0) > 2:
                        warns.append(f"{q['id']} 장면 {k + 1}: 할 일 {len(tasks)}개")
                    if tasks:
                        need['tasks'] = tasks
                    if give:
                        need['give'] = give
                    goal = goal_text(tasks, give)
            steps.append([s['title'], goal, need, s['lines']])
        if sc and sc[-1]['todo']:
            errors.append(f"{q['id']}: 마지막 장면에 할 일이 있음")
        xp = 0 if field == ARC or L >= DW.CAP else round(RULES['xp'] * REF['xp_need'][L])
        task_steps = [k for k, st in enumerate(steps) if st[2].get('tasks') or st[2].get('give')]
        per = xp // max(1, len(task_steps))
        if not q['summary']:
            errors.append(f"{q['id']}: 요약 없음")
        for a in after:
            if a not in REF['quests'] and a not in META:
                errors.append(f"{q['id']}: 앞 퀘스트 모름 {a}")
        cat = ARC if field == ARC else f'{field}·{REGION_BY_ID.get(reg, reg)}'
        w(f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ({T(q['id'])}, 'side', {T(cat)}, {T(q['title'])}, {T(q['summary'])}, {T(reg)}, {L}, {T('{' + ','.join(after) + '}')}::text[], null, {SORT0 + i}, '[]'::jsonb, true, null, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true;""")
        w(f"delete from public.world_quest_steps where quest_id = {T(q['id'])} and step > {len(steps)};")
        for k, (title, goal, need, ls) in enumerate(steps):
            rw = {}
            if k in task_steps and per:
                rw['xp'] = per
            if k == len(steps) - 1:
                rw['gil'] = RULES['gil'][0] + RULES['gil'][1] * L
                rw['items'] = reward_items(L)
                ks = KEEPSAKE.get(q['id'])
                if ks:
                    rw['title'] = ks['title'][0]
                    rw['items'][ks['item'][0]] = 1
            w(f"""insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ({T(q['id'])}, {k + 1}, {T(title)}, {T(goal)}, {J(need)}, {J(ls)}, {J(rw)})
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""")
    return out


def main():
    files = sorted(os.path.join(HERE, f) for f in os.listdir(HERE) if re.match(r'^script_[a-z]\.md$', f))
    qs = parse_files(files)
    for q in qs:
        if not q['id'] or q['id'] not in META:
            errors.append(f"{q['title']}: META에 없는 퀘스트 {q['id']}")
            continue
        L, reg, field, after = META[q['id']]
        if q['L'] != L:
            errors.append(f"{q['id']}: 머리 레벨 {q['L']} / META {L}")
        if region_of(q['place']) != reg:
            errors.append(f"{q['id']}: 머리 곳 {q['place']} / META {REGION_BY_ID.get(reg, reg)}")
        if q['after'] != after:
            errors.append(f"{q['id']}: 앞 퀘스트 {q['after']} / META {after}")
    seen = [q['id'] for q in qs]
    for k in META:
        if seen.count(k) != 1:
            errors.append(f'대본 수 {k}: {seen.count(k)}')
    qs = [q for q in qs if q['id'] in META]
    check_names()
    body = build(qs)
    sys.stderr.write(f"명등기 보조 퀘스트 {len(qs)} · 장면 {sum(len(q['scenes']) for q in qs)} · 새 인물 {len(NPCS)} · 기념 가구 {len(KEEPSAKE)}\n")
    if warns:
        sys.stderr.write('경고:\n' + '\n'.join(warns) + '\n')
    if errors:
        sys.stderr.write('\n'.join(errors) + '\n')
        sys.exit(1)
    print('\n'.join(body))


if __name__ == '__main__':
    main()
