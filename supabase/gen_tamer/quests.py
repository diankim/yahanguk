import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SIDE = os.path.join(HERE, '..', 'gen_side110')
sys.path.insert(0, SIDE)
import gen as side

DSN = os.environ.get('YH_DSN', 'host=/var/tmp/yhpg4 port=5496 user=postgres dbname=yh')
NEW_NAMES = ['곰실', '두석', '무던', '깜부기', '꼬미', '달봉', '갈대지기']
META = {
    '이름 없는 불씨': dict(id='jq_tamer', L=3, region='hq_dorm', after=[], sort=907, items={'ammo_arrow': 60, 'pet_food': 3},
                       summary='객사 뒤뜰의 늙은 조련사 곰실이 동무가 사람을 따르는 까닭을 일러 준다'),
    '옥사에 남은 족제비': dict(id='jq2_tamer', L=18, region='old_prison', after=['jq_tamer'], sort=1116, items=None,
                         summary='옛 의금부 옥사의 쥐 떼 속에서 이름을 잃어 가는 족제비'),
    '서로 부르는 이름': dict(id='jq3_tamer', L=32, region='ash_reeds', after=['jq2_tamer', 'mq_nine_gates'], sort=1183, items=None,
                        summary='섬으로 보내진 곰실의 옛 짝과, 그 이름을 놓지 않은 수달'),
}
BIO = {'q:dh_gomsil': '객사 뒤뜰 동무 우리를 지키는 늙은 조련사. 젊을 때 옛 의금부 옥사에서 일했다.',
       'q:sx_duseok': '옥사가 버려지기 전에 죽은 열네 살 죄수의 영.',
       'q:sx_galdae': '서른 해 전 섬으로 보내진 늙은 반요. 갈대숲 가에서 수달 한 마리와 산다.'}
errors = []


def q(sql):
    out = subprocess.run(['psql', DSN, '-At', '-c', sql], capture_output=True, text=True)
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
        d[k] = [x.strip() for x in v[1:-1].split(',')] if v.startswith('[') else int(v)
    return ('task', d)


def parse(path):
    quests, cur, scene, npcs = [], None, None, {}
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        h = re.match(r'^###\s+조련사 Lv(\d+)\s+「(.+?)」', line)
        if h:
            m = META[h.group(2)]
            cur = dict(m, title=h.group(2), scenes=[], npcs={}); quests.append(cur); scene = None; continue
        if line.startswith('## 설정 정리'): cur = None
        if cur is None: continue
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
        if not key: errors.append(f"{cur['id']}: 말하는 이 모름 {who}")
        scene['lines'].append({'s': key, 't': text})
    return quests, npcs


def check(quests, npcs):
    ref = side.REF
    for name in NEW_NAMES:
        hits = q(f"""select string_agg(x, ', ') from (
          select 'npc:' || npc_key x from world_quest_npcs where npc_name like '%{name}%' and npc_key not in ('q:dh_gomsil', 'q:sx_duseok', 'q:sx_galdae')
          union all select 'item:' || item_id from world_item_catalog where item_name like '%{name}%'
          union all select 'mon:' || monster_id from world_region_monsters where monster_name like '%{name}%'
          union all select 'pet:' || pet_id from world_pet_species where pet_name like '%{name}%'
          union all select 'region:' || region_id from world_map_regions where region_name like '%{name}%'
          union all select 'line:' || quest_id from world_quest_steps where lines::text like '%{name}%' and quest_id not like 'jq%\\_tamer') z""").strip()
        if hits: errors.append(f'이름 겹침 {name}: {hits}')
    for qq in quests:
        for sc in qq['scenes']:
            for kind, *rest in sc['todo'] or []:
                if kind == 'give':
                    if rest[0] not in ref['items'].values(): errors.append(f"{qq['id']}: 물품 모름 {rest[0]}")
                    continue
                t = rest[0]
                for m in t.get('m', []):
                    if not any(m == x[0] for v in ref['monsters'].values() for x in v): errors.append(f"{qq['id']}: 요괴 모름 {m}")
                for r in t.get('r', []):
                    if r not in {v[0] for v in ref['regions'].values()}: errors.append(f"{qq['id']}: 지역 모름 {r}")
                for i in t.get('items', []):
                    if t['t'] == 'gather' and i not in ref['spots'].get(t['r'][0], []): errors.append(f"{qq['id']}: {t['r'][0]} 채집터에 {i} 없음")


def build(quests, npcs):
    out = []; w = out.append
    for k, (name, bio) in sorted(npcs.items()):
        if k == 'q:sx_solmoe': continue
        w(f"insert into public.world_quest_npcs(npc_key, npc_name, bio) values ({side.T(k)}, {side.T(name)}, {side.T(BIO.get(k, bio))}) on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;")
    rules = side.RULES
    for qq in quests:
        L = qq['L']; sc = qq['scenes']; steps = []
        for k, s in enumerate(sc):
            need = {'at': [s['place']]}; goal = s['title']
            if k > 0:
                tasks = [x[1] for x in sc[k - 1]['todo'] if x[0] == 'task']
                give = {x[1]: x[2] for x in sc[k - 1]['todo'] if x[0] == 'give'}
                if tasks: need['tasks'] = tasks
                if give: need['give'] = give
                goal = side.goal_text(tasks, give)
            steps.append((s['title'], goal, need, s['lines']))
        if sc[-1]['todo']: errors.append(f"{qq['id']}: 마지막 장면에 할 일")
        tot = round(rules['xp'] * side.xp_need(L)); task_steps = [k for k, st in enumerate(steps) if st[2].get('tasks') or st[2].get('give')]
        per = tot // max(1, len(task_steps))
        w(f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ({side.T(qq['id'])}, 'side', '직업·조련사', {side.T(qq['title'])}, {side.T(qq['summary'])}, {side.T(qq['region'])}, {L}, {side.T('{' + ','.join(qq['after']) + '}')}::text[], null, {qq['sort']}, '[]'::jsonb, true, 'tamer', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;""")
        for k, (title, goal, need, ls) in enumerate(steps):
            rw = {}
            if k in task_steps: rw['xp'] = per
            if k == len(steps) - 1:
                rw['gil'] = rules['gil'][0] + rules['gil'][1] * L; rw['items'] = qq['items'] or side.reward_items(L)
            w(f"""insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ({side.T(qq['id'])}, {k + 1}, {side.T(title)}, {side.T(goal)}, {side.J(need)}, {side.J(ls)}, {side.J(rw)})
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""")
    w("insert into public.world_pet_sources(source, pet_id) values ('quest:jq2_tamer', 'little_ferret') on conflict do nothing;")
    w("select public.world_quest_label_refresh();")
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    qs, npcs = parse(os.path.join(HERE, 'script.md'))
    check(qs, npcs)
    sql = build(qs, npcs)
    if errors: print('\n'.join(errors)); sys.exit(1)
    open(os.path.join(HERE, 'm_quests.sql'), 'w', encoding='utf-8').write(sql)
    print(f'퀘스트 {len(qs)} · 장면 {sum(len(x["scenes"]) for x in qs)} · 인물 {len(npcs)}')
