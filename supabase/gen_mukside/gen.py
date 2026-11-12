import json, re, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
REF = json.load(open(os.path.join(HERE, 'ref.json'), encoding='utf-8'))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'migrations', '20261116080000_world_2_0_0_mukjeok_side.sql')
DBV = '20261116080000'

FERRY, FIELD, FOREST, TOWER, COURT = 'mukchang_ferry', 'blank_field', 'meokbi_forest', 'myeongbu_tower', 'nine_court'
ARC = '외전·묵적록'

META = {
    '글자를 삼킨 잉어': ('mks_n_carp', 40, FERRY, '낚시', ['mkq_1']),
    '빈칸을 먹는 고기': ('mks_n_snakehead', 41, FIELD, '낚시', ['mkq_1']),
    '남의 꿈을 거슬러': ('mks_n_salmon', 42, FOREST, '낚시', ['mkq_2']),
    '바람 부는 새벽의 그물': ('mks_n_tuna', 43, FERRY, '낚시', ['mkq_1']),
    '죽간을 감은 장어': ('mks_n_eel', 44, TOWER, '낚시', ['mkq_3']),
    '우물 밑의 눈': ('mks_n_dragon', 45, COURT, '낚시', ['mkq_4']),
    '아래 칸의 이름': ('mks_lower_name', 40, FERRY, '채집', ['mkq_1', 'sq110_e_doorplate']),
    '외상 장부가 지워졌다': ('mks_tab_ledger', 40, FERRY, '조사', ['mkq_1']),
    '이름 없는 나룻배': ('mks_nameless_boat', 41, FERRY, '제작', ['mkq_1']),
    '빙혼곡을 넘는 짐꾼': ('mks_porter', 40, 'frost_valley', '채집', ['mkq_1']),
    '까마귀가 쪼아 간 글자': ('mks_crow_letters', 41, FIELD, '전투', ['mkq_1']),
    '허수아비가 입은 문패': ('mks_scarecrow', 42, FIELD, '전투', ['mkq_2']),
    '억새 속 약막': ('mks_reed_clinic', 41, FIELD, '제작', ['mkq_1']),
    '숙소에 남은 붓': ('mks_other_brush', 42, FOREST, '조사', ['mkq_3']),
    '목장승이 지키던 마을': ('mks_totem', 43, FOREST, '전투', ['mkq_2']),
    '꺾인 붓의 주인': ('mks_broken_brush', 43, FOREST, '전투', ['mkq_2']),
    '서리귀의 마지막 줄': ('mks_last_line', 44, TOWER, '조사', ['mkq_3']),
    '거울 명부에 비친 얼굴': ('mks_mirror_face', 44, TOWER, '전투', ['mkq_3']),
    '탑 꼭대기 번갯불': ('mks_lightning', 44, TOWER, '전투', ['mkq_3']),
    '뜰 가장자리의 돌거북': ('mks_stone_turtle', 45, COURT, '전투', ['mkq_4']),
    '감찰이 온다': ('mke_hisu_1', 45, FERRY, ARC, ['mkq_5']),
    '불러 주는 이 칸': ('mke_hisu_2', 45, FERRY, ARC, ['mke_hisu_1']),
    '데운 국 한 그릇': ('mke_hisu_3', 45, FERRY, ARC, ['mke_hisu_2']),
    '서른 개의 빈 위패': ('mke_daon_1', 45, FERRY, ARC, ['mkq_5']),
    '다온이라는 이름': ('mke_daon_2', 45, FERRY, ARC, ['mke_daon_1']),
    '서당 가는 길': ('mke_daon_3', 45, FERRY, ARC, ['mke_daon_2']),
    '안 파는 항아리': ('mke_wolha_1', 45, FERRY, ARC, ['mkq_5']),
    '맡긴 이름': ('mke_wolha_2', 45, FERRY, ARC, ['mke_wolha_1']),
    '공짜 손님': ('mke_wolha_3', 45, FERRY, ARC, ['mke_wolha_2']),
}
NO_XP = {k for k, v in META.items() if v[3] == ARC}
KEEPSAKE = {
    'mke_hisu_3': {'title': ('mk_keep_hisu', '불러 주는 이의 증인'), 'items': ['hf_mk_brushstand', 'of_acc_mk_hairpin']},
    'mke_daon_3': {'title': ('mk_keep_daon', '두 권째 공책의 첫 이름'), 'items': ['hf_mk_notedesk', 'of_acc_mk_nameplate']},
    'mke_wolha_3': {'title': ('mk_keep_wolha', '값을 부르지 않는 손님'), 'items': ['hf_mk_coinblind', 'of_acc_mk_lotus']},
}
IDLE_K = {'수련': 'training', '조사': 'research', '정비': 'maintenance', '휴식': 'rest'}
UNIT = r'(?:개|마리|줌|덩이|그릇|벌|장|번|회)?'

ITEMS = REF['items']; MONS = REF['monsters']; REGIONS = REF['regions']; RECIPES = REF['recipes']; SPOTS = REF['spots']
FISHING = set(REF['fishing']); FISH = REF['fish']; CATS = REF['categories']
NPC_OLD = dict(REF['npcs'])
for _n, _k in list(REF['npcs'].items()):
    _s = _n.split()[-1]
    if _s != _n and sum(1 for x in REF['npcs'] if x.split()[-1] == _s) == 1: NPC_OLD.setdefault(_s, _k)
REGION_NAMES = sorted(REGIONS, key=len, reverse=True)
ITEM_NAME = {v: k for k, v in ITEMS.items()}
MON_NAME = {m[0]: k for k, v in MONS.items() for m in v}
REGION_NAME = {v[0]: k for k, v in REGIONS.items()}
FISH_NAMES = sorted(FISH, key=len, reverse=True)
errors = []
SX_NAMES = {}
PENDING_ITEMS = {i for v in KEEPSAKE.values() for i in v['items']}

def item_id(name, q):
    name = name.strip()
    if name in ITEMS: return ITEMS[name]
    errors.append(f'{q}: 물품 이름 모름 — {name}'); return name

def region_of(text):
    for n in REGION_NAMES:
        if n in text: return REGIONS[n][0]
    return None

def strip_region(p):
    for n in REGION_NAMES:
        p = re.sub(re.escape(n) + r'\s*(에서|에|으로|로)?\s*', '', p)
    return re.sub(r'\(.*?\)', '', p).strip()

def split_tasks(s):
    return [p.strip() for p in re.split(r'\s*·\s*', s) if p.strip()]

def parse_task(p, ctx, q):
    r = region_of(p); rr = [r] if r else ctx[:1]; body = strip_region(p)
    m = re.match(r'^탐색\s*(\d+)\s*회?$', body)
    if m: return ('task', {'t': 'search', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^실마리\s*(\d+)\s*' + UNIT + '$', body)
    if m: return ('task', {'t': 'clue', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^낚시\s*(\d+)\s*회?$', body)
    if m:
        if rr[0] not in FISHING: errors.append(f'{q}: 낚시터 없는 곳 {rr[0]}')
        return ('task', {'t': 'fish', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^(.+?)\s*(?:(\d+)\s*마리\s*)?낚기$', body)
    if m:
        fn = m.group(1).strip()
        if fn not in FISH: errors.append(f'{q}: 물고기 이름 모름 — {fn}'); return None
        fid, hab, grounds, named = FISH[fn]
        if grounds and rr[0] not in grounds: errors.append(f'{q}: {fn}은 {grounds}에서만 — {rr[0]}')
        return ('task', {'t': 'fish', 'r': rr, 'f': [fid], 'n': int(m.group(2) or 1)})
    if re.match(r'^쉬기$', body): return ('task', {'t': 'rest', 'r': rr, 'n': 1})
    m = re.match(r'^자율 활동(?:\s*「(.+?)」)?\s*마치기$', body)
    if m:
        t = {'t': 'idle', 'n': 1}
        if m.group(1):
            if m.group(1) not in IDLE_K: errors.append(f'{q}: 자율 활동 종류 모름 — {m.group(1)}')
            else: t['k'] = IDLE_K[m.group(1)]
        return ('task', t)
    m = re.match(r'^원정\s*(\d+)\s*회?$', body)
    if m: return ('task', {'t': 'expedition', 'r': rr, 'n': int(m.group(1))})
    if re.match(r'^도착$', body):
        if not r: errors.append(f'{q}: 도착할 곳 모름 — {p}')
        return ('task', {'t': 'travel', 'r': rr, 'n': 1})
    m = re.match(r'^요괴\s*(\d+)\s*' + UNIT + r'\s*처치$', body)
    if m: return ('task', {'t': 'win', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^(.+?)\s*(\d+)\s*' + UNIT + r'\s*(모으기|처치|만들기|넘기기)$', body)
    if not m: errors.append(f'{q}: 할 일을 못 읽음 — {p}'); return None
    name, n, verb = m.group(1).strip(), int(m.group(2)), m.group(3)
    if verb == '처치':
        c = MONS.get(name)
        if not c: errors.append(f'{q}: 요괴 이름 모름 — {name}'); return None
        mid = next((x[0] for x in c if x[1] in ctx), c[0][0])
        return ('task', {'t': 'win', 'm': [mid], 'n': n})
    iid = item_id(name, q)
    if verb == '모으기':
        if rr[0] and iid not in SPOTS.get(rr[0], []): errors.append(f'{q}: {rr[0]} 채집터에 {name} 없음')
        return ('task', {'t': 'gather', 'items': [iid], 'r': rr, 'n': n})
    if verb == '만들기':
        if iid not in RECIPES: errors.append(f'{q}: 제작법 없음 — {name}')
        return ('task', {'t': 'craft', 'items': [iid], 'n': n})
    return ('give', (iid, n))

def parse_files(paths):
    quests = []; cur = None; scene = None; seen_sx = {}
    for path in paths:
        for raw in open(path, encoding='utf-8'):
            line = raw.rstrip('\n')
            h = re.match(r'^###\s+(?!#)(.+)$', line)
            if h:
                t = re.search(r'「(.+?)」', h.group(1))
                if not t or t.group(1) not in META: cur = None; continue
                title = t.group(1); qid, L, reg, cat, after = META[title]
                cur = dict(id=qid, title=title, L=L, region=reg, cat=cat if cat == ARC else f'{cat}·{REGION_NAME.get(reg, reg)}',
                           after=after, summary='', npcs={}, scenes=[], file=os.path.basename(path))
                if any(x['id'] == qid for x in quests): errors.append(f'퀘스트 겹침: {title}')
                quests.append(cur); scene = None; continue
            if cur is None: continue
            if line.startswith('요약:'): cur['summary'] = line[3:].strip(); continue
            if line.startswith('인물:'):
                for key, name, bio in re.findall(r'`(sx_[a-z0-9_]+)`\s*([^(·`]+?)\s*\(([^)]*)\)', line):
                    name = name.strip()
                    if key in seen_sx and seen_sx[key] != name: errors.append(f'인물 키 겹침 {key}: {seen_sx[key]} / {name}')
                    seen_sx[key] = name
                    cur['npcs'][name] = ('q:' + key, bio.strip())
                    SX_NAMES[name] = ('q:' + key, bio.strip())
                for name in sorted(SX_NAMES, key=len, reverse=True):
                    if name in line and name not in cur['npcs']: cur['npcs'][name] = SX_NAMES[name]
                for name in sorted(NPC_OLD, key=len, reverse=True):
                    if name in line and name not in cur['npcs'] and not any(name in x for x in cur['npcs']): cur['npcs'][name] = (NPC_OLD[name], None)
                continue
            s = re.match(r'^####\s+장면\s*(\d+)\s*·\s*(.+?)\s*\((받기|보고)\s*:\s*(.+?)\)\s*$', line)
            if s:
                place = region_of(s.group(4))
                if not place: errors.append(f"{cur['id']}: 장면 곳 모름 — {s.group(4)}")
                scene = dict(title=s.group(2).strip(), place=place or cur['region'], lines=[], todo=None)
                cur['scenes'].append(scene); continue
            if scene is None: continue
            l = re.match(r'^-\s+([^:]+?):\s*(.+)$', line)
            if not l: continue
            who, text = l.group(1).strip(), l.group(2).strip()
            if who == '할 일': scene['todo'] = text; continue
            if who == '서술': scene['lines'].append({'s': None, 't': text}); continue
            key = next((k for name, (k, _) in cur['npcs'].items() if who == name or name.endswith(who) or who in name.split()), None)
            if not key and who in NPC_OLD: key = NPC_OLD[who]
            if not key: errors.append(f"{cur['id']}: 말하는 이 모름 — {who}")
            scene['lines'].append({'s': key, 't': text})
    return quests

def goal_text(tasks, give):
    out = []
    for t in tasks:
        rg = REGION_NAME.get((t.get('r') or [None])[0], '')
        if t['t'] == 'gather': out.append(f"{rg}에서 {ITEM_NAME.get(t['items'][0])}을(를) 모은다")
        elif t['t'] == 'win': out.append(f"{MON_NAME.get(t['m'][0]) if 'm' in t else rg + '의 요괴'}을(를) 물리친다")
        elif t['t'] == 'craft': out.append(f"{ITEM_NAME.get(t['items'][0])}을(를) 만든다")
        elif t['t'] == 'search': out.append(f"{rg}을(를) 살핀다")
        elif t['t'] == 'clue': out.append(f"{rg}에서 실마리를 찾는다")
        elif t['t'] == 'fish': out.append(f"{rg}에서 {next(k for k, v in FISH.items() if v[0] == t['f'][0])}을(를) 낚는다" if 'f' in t else f"{rg}에서 낚시를 한다")
        elif t['t'] == 'rest': out.append(f"{rg}에서 쉰다")
        elif t['t'] == 'idle': out.append('자율 활동을 끝까지 마친다')
        elif t['t'] == 'expedition': out.append(f"{rg}에 원정을 다녀온다")
        elif t['t'] == 'travel': out.append(f"{rg}에 간다")
    for k in give: out.append(f"{ITEM_NAME.get(k, k)}을(를) 넘긴다")
    return ', '.join(out)

def T(s): return 'null' if s is None else "'" + str(s).replace("'", "''") + "'"
def J(o): return T(json.dumps(o, ensure_ascii=False)) + '::jsonb'

RULES = REF['reward_rules']['side']
def reward_items(L): return dict(next((it for top, it in RULES['items'] if L <= top), RULES['items'][-1][1]))

def check_lines(q):
    for s in q['scenes']:
        for ln in s['lines']:
            t = ln['t'].rstrip()
            if ln['s'] is None and t.endswith('.') and not t.endswith('」.') and t[-2] not in '다요까지네죠오소군라야자어아해니게':
                errors.append(f"{q['id']} 「{s['title']}」 서술 끝맺음 확인 — …{t[-20:]}")

def build(quests):
    out = []; w = out.append
    npcs = {}
    for q in quests:
        for name, (k, bio) in q['npcs'].items():
            if bio is not None:
                if name in NPC_OLD: errors.append(f"{q['id']}: 기존 인물과 이름 겹침 {name}")
                if k in npcs and npcs[k][0] != name: errors.append(f'인물 키 겹침 {k}')
                npcs[k] = (name, bio)
    for k, (name, bio) in sorted(npcs.items()):
        w(f"insert into public.world_quest_npcs(npc_key, npc_name, bio) values ({T(k)}, {T(name)}, {T(bio)}) on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;")
    for i, q in enumerate(sorted(quests, key=lambda x: (x['L'], x['id']))):
        check_lines(q)
        sc = q['scenes']
        if len(sc) < 2: errors.append(f"{q['id']}: 장면이 둘보다 적음"); continue
        steps = []
        for k, s in enumerate(sc):
            need = {'at': [s['place']]}; goal = s['title']
            if k > 0:
                todo = sc[k - 1]['todo']
                if not todo: errors.append(f"{q['id']}: 장면 {k} 끝에 할 일이 없음")
                else:
                    tasks, give = [], {}
                    ctx = [x for x in (sc[k - 1]['place'], s['place'], q['region']) if x]
                    for p in split_tasks(todo):
                        r = parse_task(p, ctx, q['id'])
                        if not r: continue
                        if r[0] == 'task': tasks.append(r[1])
                        else: give[r[1][0]] = give.get(r[1][0], 0) + r[1][1]
                    for t in tasks:
                        if t['t'] == 'craft':
                            for iid in t['items']: give.setdefault(iid, t['n'])
                    kinds = [t['t'] for t in tasks]
                    if 'travel' in kinds and len(kinds) == 1: errors.append(f"{q['id']} 장면 {k + 1}: 이동만 하는 할 일")
                    if tasks: need['tasks'] = tasks
                    if give: need['give'] = give
                    goal = goal_text(tasks, give)
            steps.append([s['title'], goal, need, s['lines']])
        if sc[-1]['todo']: errors.append(f"{q['id']}: 마지막 장면에 할 일이 있음")
        L = q['L']; xp = 0 if q['title'] in NO_XP else round(RULES['xp'] * REF['xp_need'][L])
        task_steps = [k for k, st in enumerate(steps) if st[2].get('tasks') or st[2].get('give')]
        per = xp // max(1, len(task_steps))
        if not q['summary']: errors.append(f"{q['id']}: 요약 없음"); q['summary'] = q['title']
        for a in q['after']:
            if a not in REF['quests'] and a not in {v[0] for v in META.values()}: errors.append(f"{q['id']}: 앞 퀘스트 모름 {a}")
        w(f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ({T(q['id'])}, 'side', {T(q['cat'])}, {T(q['title'])}, {T(q['summary'])}, {T(q['region'])}, {L}, {T('{' + ','.join(q['after']) + '}')}::text[], null, {1310 + i}, '[]'::jsonb, true, null, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true;""")
        w(f"delete from public.world_quest_steps where quest_id = {T(q['id'])} and step > {len(steps)};")
        for k, (title, goal, need, ls) in enumerate(steps):
            rw = {}
            if k in task_steps and per: rw['xp'] = per
            if k == len(steps) - 1:
                rw['gil'] = RULES['gil'][0] + RULES['gil'][1] * L; rw['items'] = reward_items(L)
                ks = KEEPSAKE.get(q['id'])
                if ks:
                    rw['title'] = ks['title'][0]
                    for it in ks['items']: rw['items'][it] = 1
            w(f"""insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ({T(q['id'])}, {k + 1}, {T(title)}, {T(goal)}, {J(need)}, {J(ls)}, {J(rw)})
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""")
    for qid, ks in KEEPSAKE.items():
        key, name = ks['title']
        if name in REF['titles']: errors.append(f'칭호 이름 겹침 {name}')
        w(f"""insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, hidden, rule, sort, category, grade)
values ({T(key)}, {T(name)}, {T('외전 「묵적록」 뒤 이야기를 끝까지 함께했다.')}, {T('「' + next(t for t, v in META.items() if v[0] == qid) + '」를 마친다')}, '{{}}'::jsonb, false, null, 980, '묵적록', 4)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, category = excluded.category, grade = excluded.grade;""")
    return out

if __name__ == '__main__':
    files = sorted(os.path.join(HERE, f) for f in os.listdir(HERE) if re.match(r'^script_[a-z]\.md$', f))
    qs = parse_files(files)
    body = build(qs)
    missing = [t for t in META if t not in {q['title'] for q in qs}]
    if missing: errors.append('대본 없음: ' + ', '.join(missing))
    head = open(os.path.join(HERE, 'engine.sql'), encoding='utf-8').read()
    keep = open(os.path.join(HERE, 'keepsake.sql'), encoding='utf-8').read() if os.path.exists(os.path.join(HERE, 'keepsake.sql')) else ''
    if not keep: errors.append('기념품 물품 SQL(keepsake.sql) 없음')
    tail = open(os.path.join(HERE, 'patch_note.sql'), encoding='utf-8').read() if os.path.exists(os.path.join(HERE, 'patch_note.sql')) else ''
    sql = '\n'.join([head, keep] + body + [tail, 'select public.world_quest_label_refresh();',
        f"insert into public.world_app_meta(key, value, changed_at) values ('db_version', '{DBV}', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;"]) + '\n'
    print(f"퀘스트 {len(qs)} · 장면 {sum(len(q['scenes']) for q in qs)} · 할 일 장면 {sum(1 for q in qs for s in q['scenes'][:-1] if s['todo'])}")
    if errors:
        print('\n'.join(errors)); sys.exit(1)
    open(OUT, 'w', encoding='utf-8').write(sql)
    print(OUT)
