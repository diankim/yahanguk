import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SIDE = os.path.join(os.path.dirname(HERE), 'gen_300', 'side')
WORLD = os.path.join(os.path.dirname(HERE), 'gen_300', 'world')
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, SIDE)
sys.path.insert(0, WORLD)
import data_quests as DQ
import data_world as DW

REF = json.load(open(os.path.join(SIDE, 'ref.json'), encoding='utf-8'))
ARC = '연담'
SORT0 = 1600
sys.path.insert(0, HERE)
import data as RD

LANDING, YAMEN, MARTIAL, SHRINE, OFM, REST, FOBS, PALACE, PACT, VAULT = (
    'deungdo_landing', 'dark_yamen', 'martial_row', 'red_shrine_lane', 'old_ferry_market', 'lamp_rest', 'first_observatory', 'ash_palace', 'pact_court', 'jeongni_vault')

META, OPEN, NPC_OF = {}, {}, {}
for _n in RD.NPCS:
    for _i in range(1, 6):
        _q = f"rg_{_n['k']}_{_i}"
        META[_q] = (_n['lv'], _n['region'], ARC, list(_n['after']) if _i == 1 else [f"rg_{_n['k']}_{_i - 1}"])
        NPC_OF[_q] = _n
        if _i > 1:
            OPEN[_q] = {'regular': _n['k'], 'stage': _i}

import importlib.util as _iu
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parents[1] / 'quest_short'))
from short import SHORT
_sp = _iu.spec_from_file_location('side_gen', os.path.join(SIDE, 'gen.py')); _side = _iu.module_from_spec(_sp); _sp.loader.exec_module(_side)
_sp2 = _iu.spec_from_file_location('epi_gen', os.path.join(os.path.dirname(HERE), 'gen_310', 'epi_meta.py')); EM = _iu.module_from_spec(_sp2); _sp2.loader.exec_module(EM)
NPCS = {}
NEW_SPEAK = dict(_side.NEW_SPEAK); NEW_SPEAK.update(EM.NEW_SPEAK)
SPEAK = dict(DQ.SPEAK); SPEAK.update(NEW_SPEAK)
SPEAK.setdefault('여울', 'q:g_yeoul')

KEEP_DESC = '별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.'
OUT_DESC = '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.'
KEEPSAKE = {f"rg_{k}_5": v for k, v in RD.REWARDS.items()}
TITLE_DESC = {f"rg_{n['k']}_5": n['title_desc'] for n in RD.NPCS}

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
            line = re.sub(r'\s*·\s*열림:.*$', '', line) if line.startswith('id:') else line
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
NAME_OK = {('잔불촌', '잔불촌'), ('두례', '두칠'), ('두례', '두석'), ('춘보', '춘화')} | EM.NAME_OK


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
    for k, (nm, _) in EM.NPCS.items():
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
    av = open(os.path.join(ROOT, 'assets', 'js', 'housing', 'avatar.js'), encoding='utf-8').read()
    for q, ks in KEEPSAKE.items():
        iid, nm, cat, desc, tr = ks['item']
        if 'look' in tr:
            slot, key = tr['look'].split(':')
            if f'"{key}":{{"name":"{nm}"' not in av:
                errors.append(f'avatar.js에 {tr["look"]} {nm} 없음')
            rows.append(f"({T(iid)}, {T(nm)}, 'outfit', 4, {T(desc + ' ' + OUT_DESC)}, false, false, 100, 1, {J(tr)})")
            continue
        if f"  {tr['hk']}: {{" not in furn:
            errors.append(f'furniture.js에 {tr["hk"]} 없음')
        traits = dict(tr, cat=cat, grade=4)
        rows.append(f"({T(iid)}, {T(nm)}, 'furniture', 4, {T('별채 가구 · ' + cat + '. ' + desc + ' ' + KEEP_DESC)}, false, false, 800, 1, {J(traits)})")
    if rows: w("""insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values
""" + ',\n'.join(rows) + """
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  stackable = excluded.stackable, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size, equipment_traits = excluded.equipment_traits;""")
    for q, ks in KEEPSAKE.items():
        key, nm = ks['title']
        title = next((x['title'] for x in quests if x['id'] == q), q)
        w(f"""insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, hidden, rule, sort, category, grade)
values ({T(key)}, {T(nm)}, {T(TITLE_DESC[q])}, {T(NPC_OF[q]['short'] + '와(과)의 다섯째 이야기 「' + title + '」을(를) 마친다')}, '{{}}'::jsonb, false, null, 3400, '연담', 4)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, category = excluded.category, grade = excluded.grade;""")
    for i, ms in enumerate(RD.MILESTONES):
        w(f"""insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, hidden, rule, sort, category, grade)
values ({T(ms['key'])}, {T(ms['name'])}, {T(ms['desc'])}, {T('연담을 맺은 ' + str(ms['n']) + '사람과 친밀도 5단계(가장 높은 단계)에 닿는다')}, '{{}}'::jsonb, false, {J({'regular': 'max', 'n': ms['n']})}, {3390 + i}, '연담', {ms['grade']})
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, rule = excluded.rule, category = excluded.category, grade = excluded.grade;""")
    order = sorted(quests, key=lambda x: ([n['k'] for n in RD.NPCS].index(NPC_OF[x['id']]['k']), x['id']))
    for i, q in enumerate(order):
        L, reg, field, after = META[q['id']]
        field = ARC
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
        xp = 0 if L >= 50 else round(RULES['xp'] * REF['xp_need'][L])
        task_steps = [k for k, st in enumerate(steps) if st[2].get('tasks') or st[2].get('give')]
        per = xp // max(1, len(task_steps))
        if not q['summary']:
            errors.append(f"{q['id']}: 요약 없음")
        for a in after:
            if a not in REF['quests'] and a not in META and a not in _side.META:
                errors.append(f"{q['id']}: 앞 퀘스트 모름 {a}")
        cat = f"{ARC}·{NPC_OF[q['id']]['short']}"
        w(f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ({T(q['id'])}, 'side', {T(cat)}, {T(q['title'])}, {T(SHORT.get(q['id'], q['summary']))}, {T(reg)}, {L}, {T('{' + ','.join(after) + '}')}::text[], null, {SORT0 + i}, '[]'::jsonb, true, null, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true;""")
        w(f"update public.world_quests set open_req = {J(OPEN[q['id']]) if OPEN.get(q['id']) else 'null'} where quest_id = {T(q['id'])};")
        w(f"delete from public.world_quest_steps where quest_id = {T(q['id'])} and step > {len(steps)};")
        for k, (title, goal, need, ls) in enumerate(steps):
            rw = {}
            if k in task_steps and per:
                rw['xp'] = per
            if k == len(steps) - 1:
                rw['gil'] = RULES['gil'][0] + RULES['gil'][1] * L
                if L < 50:
                    rw['items'] = reward_items(L)
                ks = KEEPSAKE.get(q['id'])
                if ks:
                    rw['title'] = ks['title'][0]
                    rw.setdefault('items', {})[ks['item'][0]] = 1
            w(f"""insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ({T(q['id'])}, {k + 1}, {T(title)}, {T(goal)}, {J(need)}, {J(ls)}, {J(rw)})
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""")
    return out


def main():
    files = sorted(os.path.join(HERE, f) for f in os.listdir(HERE) if re.match(r'^script_[a-z]\.md$', f))
    for f in files:
        for ln in open(f, encoding='utf-8'):
            m = re.match(r'^id:\s*(\S+).*·\s*열림:\s*(.+)$', ln.strip())
            if m and m.group(1) in META:
                want = OPEN.get(m.group(1))
                got = None if m.group(2).strip() == '없음' else m.group(2).strip()
                exp = f"연담 {want['regular']} {want['stage']}단계" if want else None
                if got != exp:
                    errors.append(f'{m.group(1)}: 열림 {got} / META {exp}')
    qs = parse_files(files)
    for q in qs:
        if not q['id'] or q['id'] not in META:
            errors.append(f"{q['title']}: META에 없는 퀘스트 {q['id']}")
            continue
        L, reg, field, after = META[q['id']]
        if q['L'] != L:
            errors.append(f"{q['id']}: 머리 레벨 {q['L']} / META {L}")
        if region_of(q['place']) != reg:
            warns.append(f"{q['id']}: 머리 곳 {q['place']} / META {REGION_BY_ID.get(reg, reg)}")
        if q['after'] != after:
            errors.append(f"{q['id']}: 앞 퀘스트 {q['after']} / META {after}")
    seen = [q['id'] for q in qs]
    for k in META:
        if seen.count(k) != 1:
            errors.append(f'대본 수 {k}: {seen.count(k)}')
    qs = [q for q in qs if q['id'] in META]
    check_names()
    body = build(qs)
    sys.stderr.write(f"뒷이야기 {len(qs)} · 장면 {sum(len(q['scenes']) for q in qs)} · 새 인물 {len(NPCS)} · 기념 가구 {len(KEEPSAKE)}\n")
    if warns:
        sys.stderr.write('경고:\n' + '\n'.join(warns) + '\n')
    if errors:
        sys.stderr.write('\n'.join(errors) + '\n')
        sys.exit(1)
    print('\n'.join(body))


if __name__ == '__main__':
    main()
