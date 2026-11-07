import json, re, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
REF = json.load(open(os.path.join(HERE, 'ref.json')))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'migrations', '20261108040000_world_1_1_0_side_quests.sql')

def xp_need(L): return 100 * L + 12 * L * L

ISLAND = {'banyo_village', 'ash_reeds', 'inverted_shrine', 'moonless_market', 'gwiheo_core'}
JOBS = {'호위 무사': 'artificer', '월궁 사수': 'scout', '퇴마관': 'exorcist', '의무관': 'medic', '봉인술사': 'sealmaster', '암영 검객': 'analyst'}

META = {
    '얼음 속 편지': ('sq110_ice_letter', 12, 'frost_valley', '채집', '해마다 얼음을 깨는 할미가 스무 해 전 남편의 편지 상자를 찾는다'),
    '노래하는 곡괭이': ('sq110_singing_pick', 13, 'crimson_mine', '채집', '밤마다 연장 창고의 곡괭이가 노래를 부른다'),
    '거꾸로 가는 물시계': ('sq110_backward_clock', 14, 'water_clock', '제작', '하루에 한 번 물시계가 거꾸로 돈다'),
    '벼락 맞은 대추나무': ('sq110_struck_jujube', 16, 'thunder_peak', '채집', '벼락 맞은 나무로 도장을 파겠다는 노인의 주문 백 개'),
    '별똥 줍는 아이': ('sq110_star_child', 17, 'comet_crater', '채집', '어머니 생일 선물을 찾아 낙하지까지 온 아이'),
    '칼 쓴 옥귀의 상소': ('sq110_cangue_ghost', 19, 'old_prison', '전투', '칼을 쓴 채 죽은 죄수가 밤마다 상소문을 읊는다'),
    '잠꾸러기 천문관': ('sq110_sleepy_astronomer', 20, 'white_tower', '제작', '별을 세다 꼭 아흔아홉에서 잠드는 천문관'),
    '뿌리 아래 사는 사람들': ('sq110_root_folk', 21, 'under_root', '전투', '이름을 맡긴 광부 가족에게 지맥포식자가 다가온다'),
    '붉은 제단의 가짜 신탁': ('sq110_false_oracle', 22, 'crimson_altar', '전투', '신탁을 꾸며 공물을 거두던 사제 앞에 진짜 원령이 나타난다'),
    '소금 갈매기 혼례': ('sq110_gull_wedding', 23, 'tide_gate', '채집', '갑문 꼭대기 갈매기 둥지 때문에 갑문이 안 닫힌다'),
    '밀물 도르래': ('sq110_tide_pulley', 24, 'tide_gate', '제작', '은퇴하는 갑문 목수와 그 자리를 이을 손녀'),
    '관성대 요리 겨루기': ('sq110_star_cookoff', 25, 'star_observatory', '제작', '별빛구이 원조를 두고 다투는 두 관측관'),
    '울음 새는 거울': ('sq110_weeping_mirror', 26, 'seal_vault', '전투', '밤마다 다른 봉인관의 얼굴로 우는 압수물 거울'),
    '검은 물결 위의 등': ('sq110_black_tide_lamps', 28, 'black_tide_rift', '제작', '균열에서 돌아오지 않은 어부들을 위해 등을 띄운다'),
    '흑룡 어보탕': ('sq110_dragon_soup', 28, 'black_tide_rift', '제작', '이 탕을 먹고 죽는 게 소원이라는 미식가'),
    '봉연 앞 마지막 보급소': ('sq110_last_depot', 29, 'black_tide_rift', '채집', '봉연으로 가는 조사원들을 몰래 먹이던 노인의 보급소'),
    '갈대가 부르는 이름': ('sq110_reed_name', 31, 'ash_reeds', '전투', '이름을 반쯤 잃은 이의 남은 이름을 갈대가 부른다'),
    '반요촌 첫 장날': ('sq110_first_market', 31, 'banyo_village', '제작', '반요들이 처음으로 장을 연다'),
    '실 잣는 반요 아이': ('sq110_spinning_child', 32, 'ash_reeds', '채집', '갈대 영사로 실을 잣는 반요 아이'),
    '거꾸로 매달린 동자': ('sq110_hanging_boys', 33, 'inverted_shrine', '전투', '처마에 거꾸로 매달린 동자들이 바로 세워 달라고 한다'),
    '거꾸로 피우는 향': ('sq110_inverted_incense', 34, 'inverted_shrine', '채집', '거꾸로 피운 향 연기가 잃은 것을 찾아 준다'),
    '이름 잃은 사공의 탈': ('sq110_ferryman_mask', 35, 'ash_reeds', '제작', '얼굴을 잃은 사공에게 탈을 지어 준다'),
    '기억 저울 장수': ('sq110_memory_scale', 36, 'moonless_market', '전투', '남의 기억을 싸게 사들이던 장수'),
    '달을 판 상주': ('sq110_moon_mourner', 37, 'moonless_market', '채집', '장례 비용을 치르려고 달을 판 상주'),
    '전당포 거미의 장부': ('sq110_pawn_spider', 37, 'moonless_market', '제작', '맡은 물건을 돌려주기 싫은 전당포 거미'),
    '귀허 진주 낚싯대': ('sq110_pearl_rod', 38, 'gwiheo_core', '제작', '마지막으로 귀허에 줄을 드리우고 싶은 노인'),
    '돌아오는 파도': ('sq110_returning_wave', 39, 'gwiheo_core', '전투', '귀허에서는 떠난 것이 파도가 되어 돌아온다'),
}
JOB_META = {}
for jn, jk in JOBS.items():
    JOB_META[(jn, 18)] = f'jq2_{jk}'
    JOB_META[(jn, 32)] = f'jq3_{jk}'

ITEMS = REF['items']; MONS = REF['monsters']; REGIONS = REF['regions']; RECIPES = REF['recipes']; SPOTS = REF['spots']; FISH = set(REF['fishing'])
NPC_OLD = REF['npcs']
REGION_NAMES = sorted(REGIONS, key=len, reverse=True)
ITEM_NAME = {v: k for k, v in ITEMS.items()}
MON_NAME = {m[0]: k for k, v in MONS.items() for m in v}
REGION_NAME = {v[0]: k for k, v in REGIONS.items()}
errors = []

def item_id(name):
    name = name.strip()
    if name in ITEMS: return ITEMS[name]
    errors.append(f'물품 이름 모름: {name}'); return name

def region_of(text):
    for n in REGION_NAMES:
        if n in text: return REGIONS[n][0]
    return None

def mon_id(name, regions):
    name = name.strip()
    c = MONS.get(name)
    if not c:
        errors.append(f'요괴 이름 모름: {name}'); return name, None
    for mid, rg, lv, role in c:
        if rg in regions: return mid, role
    return c[0][0], c[0][3]

def split_tasks(s):
    return [p.strip() for p in re.split(r'\s*[·,]\s*|\s+그리고\s+', s) if p.strip()]

def parse_task(p, ctx_regions, qid):
    r = region_of(p)
    regs = [r] if r else ctx_regions
    body = p
    for n in REGION_NAMES:
        body = body.replace(n + '에서', '').replace(n + ' 곁에서', '').replace(n, '')
    body = re.sub(r'\(.*?\)', '', body).strip()
    m = re.match(r'^(?:.*\s)?탐색\s*(\d+)\s*회?$', body)
    if m: return ('task', {'t': 'search', 'r': regs[:1], 'n': int(m.group(1))})
    m = re.match(r'^(?:.*\s)?낚시\s*(\d+)\s*회?$', body)
    if m:
        rr = regs[:1]
        if rr and rr[0] not in FISH: errors.append(f'{qid}: 낚시터 없는 곳 {rr[0]}')
        return ('task', {'t': 'fish', 'r': rr, 'n': int(m.group(1))})
    m = re.match(r'^(.+?)\s*(\d+)\s*(?:개|마리|줌|덩이|그릇|벌)?\s*(모으기|처치|만들기|넘기기|캐기|쫓기)$', body)
    if not m:
        errors.append(f'{qid}: 할 일을 못 읽음 — {p}'); return None
    name, n, verb = m.group(1).strip(), int(m.group(2)), m.group(3)
    if verb in ('모으기', '캐기'):
        iid = item_id(name)
        rr = regs[:1]
        if rr and iid not in SPOTS.get(rr[0], []): errors.append(f'{qid}: {rr[0]} 채집터에 {name} 없음')
        return ('task', {'t': 'gather', 'items': [iid], 'r': rr, 'n': n})
    if verb in ('처치', '쫓기'):
        mid, role = mon_id(name, regs)
        t = {'t': 'win', 'm': [mid], 'n': n}
        return ('task', t)
    if verb == '만들기':
        iid = item_id(name)
        if iid not in RECIPES: errors.append(f'{qid}: 제작법 없음 {name}')
        return ('task', {'t': 'craft', 'items': [iid], 'n': n})
    if verb == '넘기기':
        return ('give', (item_id(name), n))

def parse_files(paths):
    quests = []; cur = None; scene = None
    for path in paths:
        for raw in open(path, encoding='utf-8'):
            line = raw.rstrip('\n')
            h = re.match(r'^###\s+(.+)$', line)
            if h and not line.startswith('####'):
                head = h.group(1)
                t = re.search(r'「(.+?)」', head)
                if not t: cur = None; continue
                title = t.group(1)
                job = next((j for j in JOBS if head.startswith(j)), None)
                lv = re.search(r'Lv\s*(\d+)', head)
                if job:
                    L = int(lv.group(1)); qid = JOB_META.get((job, L))
                    if not qid: errors.append(f'직업 퀘스트 레벨 모름: {head}'); cur = None; continue
                    parts = [x.strip() for x in head.split('·')]
                    reg = region_of(head.split('」', 1)[1]) or None
                    cur = dict(id=qid, title=title, L=L, region=reg, cat=f'직업·{job}', job=JOBS[job], summary='', npcs={}, scenes=[])
                elif title in META:
                    qid, L, reg, cat, summ = META[title]
                    cur = dict(id=qid, title=title, L=L, region=reg, cat=f"{cat}·{REGION_NAME.get(reg, reg)}", job=None, summary=summ, npcs={}, scenes=[])
                else:
                    cur = None; continue
                if any(q['id'] == cur['id'] for q in quests): errors.append(f'퀘스트 겹침: {title}')
                quests.append(cur); scene = None; continue
            if cur is None: continue
            if line.startswith('인물:'):
                for key, name, bio in re.findall(r'`(sx_[a-z0-9_]+)`\s*([^(·`]+?)\s*\(([^)]*)\)', line):
                    cur['npcs'][name.strip()] = ('q:' + key, bio.strip())
                for name in NPC_OLD:
                    if name in line and name not in cur['npcs']: cur['npcs'][name] = (NPC_OLD[name], None)
                continue
            s = re.match(r'^####\s+장면\s*(\d+)\s*·\s*(.+?)\s*\((받기|보고)\s*:\s*(.+?)\)\s*$', line)
            if s:
                scene = dict(title=s.group(2).strip(), place=region_of(s.group(4)) or cur['region'], lines=[], todo=None)
                if not region_of(s.group(4)): errors.append(f"{cur['id']}: 장면 곳 모름 — {s.group(4)}")
                cur['scenes'].append(scene); continue
            if scene is None: continue
            l = re.match(r'^-\s+([^:]+?):\s*(.+)$', line)
            if not l: continue
            who, text = l.group(1).strip(), l.group(2).strip()
            if who == '할 일': scene['todo'] = text; continue
            if who == '서술': scene['lines'].append({'s': None, 't': text}); continue
            key = None
            for name, (k, _) in cur['npcs'].items():
                if who == name or name.endswith(' ' + who) or name.endswith(who): key = k; break
            if not key: errors.append(f"{cur['id']}: 말하는 이 모름 — {who}")
            scene['lines'].append({'s': key, 't': text})
    return quests


def goal_text(tasks, give):
    out = []
    for t in tasks:
        if t['t'] == 'gather': out.append(f"{ITEM_NAME.get(t['items'][0], t['items'][0])}을(를) 모은다")
        elif t['t'] == 'win': out.append(f"{MON_NAME.get(t['m'][0], t['m'][0])}을(를) 물리친다")
        elif t['t'] == 'craft': out.append(f"{ITEM_NAME.get(t['items'][0], t['items'][0])}을(를) 만든다")
        elif t['t'] == 'search': out.append(f"{REGION_NAME.get(t['r'][0], t['r'][0])}을(를) 살핀다")
        elif t['t'] == 'fish': out.append(f"{REGION_NAME.get(t['r'][0], t['r'][0])}에서 낚시를 한다")
    for k in give: out.append(f"{ITEM_NAME.get(k, k)}을(를) 넘긴다")
    return ', '.join(out)

def T(s): return 'null' if s is None else "'" + str(s).replace("'", "''") + "'"
def J(o): return T(json.dumps(o, ensure_ascii=False)) + '::jsonb'

def reward_items(L):
    if L < 20: return {ITEMS['청심환']: 2, ITEMS['노정 건량']: 1}
    if L < 31: return {ITEMS['영기환']: 2, ITEMS['노정 건량']: 2}
    return {ITEMS['월광 정수']: 2, ITEMS['노정 건량']: 2}

def build(quests):
    out = []; w = out.append
    w("lock table public.world_characters in access exclusive mode;")
    npcs = {}
    for q in quests:
        for name, (k, bio) in q['npcs'].items():
            if k.startswith('q:sx_'):
                if name in NPC_OLD: errors.append(f'{q["id"]}: 기존 인물과 이름 겹침 {name}')
                if k in npcs and npcs[k][0] != name: errors.append(f'인물 키 겹침 {k}')
                npcs[k] = (name, bio or name)
    for k, (name, bio) in sorted(npcs.items()):
        w(f"insert into public.world_quest_npcs(npc_key, npc_name, bio) values ({T(k)}, {T(name)}, {T(bio)}) on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;")
    for i, q in enumerate(sorted(quests, key=lambda x: (x['L'], x['id']))):
        sc = q['scenes']
        if len(sc) < 2: errors.append(f"{q['id']}: 장면이 둘보다 적음"); continue
        steps = []
        for k, s in enumerate(sc):
            need = {'at': [s['place']]}
            goal = s['title']
            if k > 0:
                todo = sc[k - 1]['todo']
                if not todo: errors.append(f"{q['id']}: 장면 {k} 끝에 할 일이 없음")
                else:
                    tasks, give = [], {}
                    ctx = [sc[k - 1]['place'], s['place'], q['region']]
                    for p in split_tasks(todo):
                        r = parse_task(p, [x for x in ctx if x], q['id'])
                        if not r: continue
                        if r[0] == 'task': tasks.append(r[1])
                        else: give[r[1][0]] = give.get(r[1][0], 0) + r[1][1]
                    if tasks: need['tasks'] = tasks
                    if give: need['give'] = give
                    goal = goal_text(tasks, give)
                    for t in tasks:
                        if t['t'] in ('search', 'fish', 'gather') and t.get('r') and t['r'][0] in ISLAND and q['L'] < 30: errors.append(f"{q['id']}: 섬 할 일인데 레벨 낮음")
            elif sc[-1]['todo']:
                pass
            steps.append([s['title'], goal, need, s['lines']])
        if sc[-1]['todo']: errors.append(f"{q['id']}: 마지막 장면에 할 일이 있음")
        L = q['L']; tot = round(0.4 * xp_need(L))
        task_steps = [k for k, st in enumerate(steps) if st[2].get('tasks') or st[2].get('give')]
        per = tot // max(1, len(task_steps))
        after = []
        if q['job']:
            after = [f"jq_{q['job']}"] if L < 30 else [f"jq2_{q['job']}"]
        if q['region'] in ISLAND or L >= 31: after.append('mq_nine_gates')
        if not q['summary']: q['summary'] = q['title']
        w(f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ({T(q['id'])}, 'side', {T(q['cat'])}, {T(q['title'])}, {T(q['summary'])}, {T(q['region'])}, {L}, {T('{' + ','.join(after) + '}')}::text[], null, {1100 + i}, '[]'::jsonb, true, {T(q['job'])}, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;""")
        w(f"delete from public.world_quest_steps where quest_id = {T(q['id'])} and step > {len(steps)};")
        for k, (title, goal, need, ls) in enumerate(steps):
            rw = {}
            if k in task_steps: rw['xp'] = per
            if k == len(steps) - 1:
                rw['gil'] = 5 + 4 * L; rw['items'] = reward_items(L)
            w(f"""insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ({T(q['id'])}, {k + 1}, {T(title)}, {T(goal)}, {J(need)}, {J(ls)}, {J(rw)})
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""")
    w('select public.world_quest_label_refresh();')
    w("update public.world_app_meta set value = '20261108040000' where key = 'db_version';")
    return '\n'.join(out) + '\n'

if __name__ == '__main__':
    files = [os.path.join(HERE, f) for f in ('plan.md', 'script_a.md', 'script_b.md', 'script_c.md', 'script_d.md') if os.path.exists(os.path.join(HERE, f))]
    qs = parse_files(files)
    sql = build(qs)
    missing = [t for t in META if t not in {q['title'] for q in qs}]
    if missing: print('대본 없음:', ', '.join(missing))
    if errors:
        print('\n'.join(errors)); sys.exit(1)
    open(OUT, 'w', encoding='utf-8').write(sql)
    print(f'퀘스트 {len(qs)} · 인물 · {OUT}')
