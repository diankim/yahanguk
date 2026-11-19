import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SIDE = os.path.join(HERE, '..', 'gen_side110')
sys.path.insert(0, SIDE)
import gen as side

side.REF = json.load(open(os.path.join(HERE, '..', 'gen_300', 'side', 'ref.json'), encoding='utf-8'))
side.RULES = side.REF['reward_rules']['side']
side.ITEMS = side.REF['items']; side.MONS = side.REF['monsters']; side.REGIONS = side.REF['regions']; side.SPOTS = side.REF['spots']
side.REGION_NAMES = sorted(side.REGIONS, key=len, reverse=True)
side.ITEM_NAME = {v: k for k, v in side.ITEMS.items()}; side.MON_NAME = {m[0]: k for k, v in side.MONS.items() for m in v}; side.REGION_NAME = {v[0]: k for k, v in side.REGIONS.items()}
DSN = os.environ.get('YH_DSN', '-h /var/tmp/yhpg -p 5499 -U postgres -d yh_340')
JOBS = {'혈기사': 'bloodknight', '진법가': 'formation', '여명 창객': 'spearman'}
FILES = ['script_bloodknight.md', 'script_formation.md', 'script_spearman.md']
SORT = {'jq': 908, 'jq2': 1117, 'jq3': 1184}
SUMMARY = {
    'jq_bloodknight': '잔불촌의 늙은 근위병이 베면서 버티는 싸움법을 가르친다.',
    'jq2_bloodknight': '혈엽림에 남은 근위대의 넋이 끝내지 못한 맹세를 붙들고 있다.',
    'jq3_bloodknight': '늙은 근위병이 남긴 도끼날을 흑조 균열의 쇠로 다시 벼린다.',
    'jq_formation': '정청 출납 서리가 다칠 자리를 미리 셈하는 법을 가르친다.',
    'jq2_formation': '흑련 장부고 장부의 빈 칸마다 바깥 것이 새어 든다.',
    'jq3_formation': '뒤틀린 지맥의 뿌리에서 바른 방위를 찾아 진을 친다.',
    'jq_spearman': '구름나루의 늙은 창잡이가 「여명」이라는 말의 뜻을 일러 준다.',
    'jq2_spearman': '잠든 포구 여명 말뚝의 이름들을 스무 해 만에 다시 부른다.',
    'jq3_spearman': '큰 만조 날, 창잡이의 외손자가 갑문 수문 날개 끝에 선다.',
}
errors = []


def goal_text(tasks, give):
    out = []
    rn = lambda t: side.REGION_NAME.get(t['r'][0], t['r'][0]) if t.get('r') else ''
    for t in tasks:
        k = t['t']
        if k in ('gather', 'craft', 'win', 'search', 'fish'): out.append(side.goal_text([t], {}))
        elif k == 'rest': out.append(f"{rn(t)}에서 쉰다")
        elif k == 'expedition': out.append(f"{rn(t)} 원정을 다녀온다")
        elif k == 'travel': out.append(f"{rn(t)}에 간다")
        else: errors.append(f"목표 글 없는 할 일 {k}")
    for kk in give: out.append(f"{side.ITEM_NAME.get(kk, kk)}을(를) 넘긴다")
    return ', '.join(out)


def q(sql):
    out = subprocess.run(['psql', *DSN.split(), '-At', '-c', sql], capture_output=True, text=True)
    if out.returncode: sys.exit(out.stderr)
    return out.stdout


def spec(s):
    s = s.strip()
    if s.startswith('give '):
        k, n = s[5:].split(':')
        return ('give', k.strip(), int(n))
    t, rest = s.split(' ', 1)
    d = {'t': t}
    for k, v in re.findall(r'(\w+):(\[[^\]]*\]|\S+)', rest):
        d[k] = [x.strip() for x in v[1:-1].split(',')] if v.startswith('[') else (int(v) if v.isdigit() else v)
    return ('task', d)


def parse(path):
    quests, cur, scene, npcs, meta = [], None, None, {}, {}
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        t = re.match(r'^\|\s*([^|]+?)\s*\|\s*(jq\d?_[a-z]+)\s*\|\s*(\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|', line)
        if t:
            reg = re.search(r'\b([a-z][a-z0-9_]+)\b', t.group(4)).group(1)
            after = [x.strip() for x in t.group(5).split(',') if x.strip() not in ('—', '-', '')]
            meta[t.group(1)] = dict(id=t.group(2), L=int(t.group(3)), region=reg, after=after)
            continue
        h = re.match(r'^###\s+(혈기사|진법가|여명 창객)\s+Lv(\d+)\s+「(.+?)」', line)
        if h:
            m = meta[h.group(3)]
            cur = dict(m, job=JOBS[h.group(1)], jobname=h.group(1), title=h.group(3), scenes=[], npcs={}, summary=None); quests.append(cur); scene = None; continue
        if line.startswith('## 설정 정리') or line.startswith('## 검토') or line.startswith('## 쓰지'): cur = None
        if cur is None: continue
        if line.startswith('요약:'):
            cur['summary'] = line[3:].strip(); continue
        if line.startswith('인물:'):
            for key, name, bio in re.findall(r'`(q:[a-z0-9_]+)`\s*([^(·`]+?)\s*\(([^)]*)\)', line):
                npcs[key] = (name.strip(), bio.strip())
            for key, (name, bio) in npcs.items():
                if name in line: cur['npcs'][name] = key
            continue
        s = re.match(r'^####\s+장면\s*(\d+)\s*·\s*(.+?)\s*\((받기|보고)\s*:\s*(.+?)\)\s*$', line)
        if s:
            place = side.region_of(s.group(4))
            if not place: errors.append(f"{cur['id']}: 장면 곳 모름 {s.group(4)}")
            scene = dict(title=s.group(2).strip(), place=place, lines=[], todo=None); cur['scenes'].append(scene); continue
        if scene is None: continue
        l = re.match(r'^-\s+([^:]+?):\s*(.+)$', line)
        if not l: continue
        who, text = l.group(1).strip(), l.group(2).strip()
        if who == '할 일':
            scene['todo'] = [spec(x) for x in re.findall(r'`([^`]+)`', text)]; continue
        if who == '서술': scene['lines'].append({'s': None, 't': text}); continue
        key = cur['npcs'].get(who) or next((k for k, (n, _) in npcs.items() if n == who), None)
        if not key:
            known = q(f"select npc_key from world_quest_npcs where npc_name = {side.T(who)} limit 1").strip()
            key = known or None
        if not key: errors.append(f"{cur['id']}: 말하는 이 모름 {who}")
        scene['lines'].append({'s': key, 't': text})
    return quests, npcs


def check(quests, npcs):
    ref = side.REF
    mons = {x[0] for v in ref['monsters'].values() for x in v}
    regs = {v[0] for v in ref['regions'].values()}
    for qq in quests:
        if not qq['summary']: errors.append(f"{qq['id']}: 요약 없음")
        for sc in qq['scenes']:
            for kind, *rest in sc['todo'] or []:
                if kind == 'give':
                    if rest[0] not in ref['items'].values(): errors.append(f"{qq['id']}: 물품 모름 {rest[0]}")
                    continue
                t = rest[0]
                for m in t.get('m', []):
                    if m not in mons: errors.append(f"{qq['id']}: 요괴 모름 {m}")
                for r in t.get('r', []):
                    if r not in regs: errors.append(f"{qq['id']}: 지역 모름 {r}")
                for i in t.get('items', []):
                    if t['t'] == 'gather' and i not in ref['spots'].get(t['r'][0], []): errors.append(f"{qq['id']}: {t['r'][0]} 채집터에 {i} 없음")
                    if t['t'] == 'craft' and i not in ref['items'].values(): errors.append(f"{qq['id']}: 만들 물품 모름 {i}")
    for k, (name, bio) in npcs.items():
        hits = q(f"select string_agg(npc_key, ',') from world_quest_npcs where npc_name = {side.T(name)} and npc_key <> {side.T(k)}").strip()
        if hits: errors.append(f'인물 이름 겹침 {name}: {hits}')


def build(quests, npcs):
    out = []; w = out.append
    new = q("select string_agg(npc_key, ',') from world_quest_npcs").strip().split(',')
    for k, (name, bio) in sorted(npcs.items()):
        if k in new: continue
        w(f"insert into public.world_quest_npcs(npc_key, npc_name, bio) values ({side.T(k)}, {side.T(name)}, {side.T(bio)}) on conflict (npc_key) do nothing;")
    rules = side.RULES
    for qq in quests:
        L = qq['L']; sc = qq['scenes']; steps = []
        for k, s in enumerate(sc):
            need = {'at': [s['place']]}; goal = s['title']
            if k > 0:
                tasks = [x[1] for x in (sc[k - 1]['todo'] or []) if x[0] == 'task']
                give = {x[1]: x[2] for x in (sc[k - 1]['todo'] or []) if x[0] == 'give'}
                if tasks: need['tasks'] = tasks
                if give: need['give'] = give
                goal = goal_text(tasks, give)
            steps.append((s['title'], goal, need, s['lines']))
        if sc[-1]['todo']: errors.append(f"{qq['id']}: 마지막 장면에 할 일")
        tot = round(rules['xp'] * side.xp_need(L)); task_steps = [k for k, st in enumerate(steps) if st[2].get('tasks') or st[2].get('give')]
        per = tot // max(1, len(task_steps))
        tier = qq['id'].split('_')[0]
        w(f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ({side.T(qq['id'])}, 'side', {side.T('직업·' + qq['jobname'])}, {side.T(qq['title'])}, {side.T(SUMMARY[qq['id']])}, {side.T(qq['region'])}, {L}, {side.T('{' + ','.join(qq['after']) + '}')}::text[], null, {SORT[tier]}, '[]'::jsonb, true, {side.T(qq['job'])}, null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;""")
        for k, (title, goal, need, ls) in enumerate(steps):
            rw = {}
            if k in task_steps: rw['xp'] = per
            if k == len(steps) - 1:
                rw['gil'] = rules['gil'][0] + rules['gil'][1] * L; rw['items'] = side.reward_items(L)
            w(f"""insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ({side.T(qq['id'])}, {k + 1}, {side.T(title)}, {side.T(goal)}, {side.J(need)}, {side.J(ls)}, {side.J(rw)})
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""")
    w("select public.world_quest_label_refresh();")
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    qs, npcs = [], {}
    for f in FILES:
        a, b = parse(os.path.join(HERE, f)); qs += a; npcs.update(b)
    check(qs, npcs)
    sql = build(qs, npcs)
    if errors: print('\n'.join(errors)); sys.exit(1)
    open(os.path.join(HERE, 'sql', 'l_quests.sql'), 'w', encoding='utf-8').write(sql)
    print(f'퀘스트 {len(qs)} · 장면 {sum(len(x["scenes"]) for x in qs)} · 인물 {len(npcs)}')
