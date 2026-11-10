import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import data_regions as D
import data_quests as Q

J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + '$J$::jsonb'
U = lambda *k: 'r220/' + '/'.join(k)
T = lambda s: '$T$' + s + '$T$'
TA = lambda c: f"array(select jsonb_array_elements_text(x.{c}))"
out = []
w = out.append
CAP = 45
REF = json.load(open(os.path.join(HERE, 'ref', 'existing_names.json')))
errors = []
TERR_NAME = {'capital': '야행국 직할령', 'east': '수향 연맹령', 'frontier': '적월 교령', 'north': '북령 맹약지', 'south': '남명 망국령', 'underworld': '흑련 지하회랑', 'heavenward': '천명 상계'}
MECH_DESC = {
    'tide': '물살로 끌어당겨 발을 묶는다. 거리를 두고 싸우거나 묶이기 전에 끊어라.', 'aerial': '하늘에서 내리꽂는다. 원거리 사격이 잘 듣는다.',
    'spectral': '몸이 반쯤 비친다. 물리 공격이 덜 듣고 술법이 잘 듣는다.', 'toxic': '독을 뿜는다. 해독할 약초와 회복품을 챙겨라.',
    'armored': '껍질이 단단하다. 방어를 무시하는 공격이나 술법이 낫다.', 'reflect': '공격의 일부를 되돌린다. 원거리 사격이나 봉인 제압을 써라.',
    'warded': '결계를 두른다. 결계를 깨는 한 방을 모아 두어라.', 'seal_breaker': '봉인을 약하게 만든다. 부적과 봉인 재료를 챙겨라.',
    'swarm': '떼로 몰려든다. 세 번째 행동마다 강하게 반격한다.', 'ambush': '숨어 있다 먼저 친다. 낌새를 살피고 방어를 섞어라.',
    'boss': '보스급 위협. 세 번째 행동마다 광역급 강공격을 하므로 방어 태세를 섞어라.',
}
NODE_DESC = {
    1: '지역에 막 들어선 곳입니다. 탐색하면 안쪽으로 이어지는 길을 찾을 수 있습니다.',
    2: '지역의 바깥 권역입니다. 탐색을 이어가면 더 안쪽 구역을 찾을 수 있습니다.',
    3: '권역 안쪽의 구역입니다. 요괴의 흔적이 짙어지고 채집터가 드러납니다.',
    4: '깊숙한 곳입니다. 쓸 만한 채집터가 숨어 있지만 위험도 커집니다.',
    5: '가장 깊은 지점입니다. 희귀한 자원과 강한 요괴가 함께 있습니다.',
}
L4_KIDS = [2, 1, 2, 1]
L5_KIDS = [2, 1, 1, 2, 1, 1]
SITE_DESC = {'supply': '탐사와 제작에 필요한 물자가 남아 있는 곳이다.', 'medical': '약과 고약을 찾을 수 있는 곳이다.', 'relic': '옛 기록과 봉인 재료가 남은 곳이다.', 'abyss': '깊은 곳의 희귀한 재료가 가라앉아 있는 곳이다.'}
SITE_CAT = {'supply': ('materials', ['supply', 'craft_material']), 'medical': ('recovery', ['healing', 'medical_material']), 'relic': ('relics', ['clue', 'seal_material', 'rare_material']), 'abyss': ('materials', ['rare_material', 'craft_material'])}
FACTION_NAME = {'night_office': '야행국 정통파', 'black_lotus': '흑련회', 'north_league': '북령맹', 'river_alliance': '수향연맹', 'southern_remnant': '남명회', 'mandate_court': '천명원', 'red_moon_cult': '적월교'}


def fresh(kind, names, label):
    have, seen = set(REF.get(kind, [])), set()
    for n in names:
        if n in have or n in seen:
            errors.append(f'{label} 이름 겹침: {n}')
        seen.add(n)


def bulk(table, rows, cols, conflict, upd, conv=None):
    if not rows:
        return
    conv = conv or {}
    ins = [c for c, _ in cols if c != 'r']
    sel = ', '.join(conv.get(c, 'x.' + c) for c in ins)
    w(f"""insert into public.{table}({', '.join(ins)})
select {sel} from jsonb_to_recordset({J(rows)}) as x({', '.join(c + ' ' + t for c, t in cols)})
on conflict ({conflict}) do {('update set ' + ', '.join(f'{u} = excluded.{u}' for u in upd)) if upd else 'nothing'};""")


def xp_need(L):
    return 100 * L + 12 * L * L


ITEMS = set(REF['item_ids'])


def need_items(ids, where):
    for i in ids:
        if i not in ITEMS:
            errors.append(f'없는 물품 {i} ({where})')


w("lock table public.world_characters in access exclusive mode;")

R = D.REGIONS
fresh('regions', [r['name'] for r in R], '지역')
fresh('region_ids', [r['id'] for r in R], '지역 id')
known = set(REF['region_ids']) | {r['id'] for r in R}
for r in R:
    for n in r['nb']:
        if n not in known:
            errors.append('없는 이웃 지역: ' + n)
rows = []
for r in R:
    rows.append(dict(region_id=r['id'], territory_id=r['terr'], territory_name=TERR_NAME[r['terr']], region_name=r['name'], region_type=r['type'], danger_level=r['danger'],
                     min_level=r['lv'], description=r['desc'], travel_from=r['nb'], faction_control=FACTION_NAME[r['faction']], world_x=r['x'], world_y=r['y'], elevation=r['el'],
                     terrain_cost=1, rest_spot_type='field_camp', rest_spot_name='임시 야영지', rest_quality=1, rest_fee=2, rest_risk=30, is_safe_zone=False,
                     home_faction_id=r['faction'], control_faction_id=r['faction']))
bulk('world_map_regions', rows, [('region_id', 'text'), ('territory_id', 'text'), ('territory_name', 'text'), ('region_name', 'text'), ('region_type', 'text'), ('danger_level', 'int'),
     ('min_level', 'int'), ('description', 'text'), ('travel_from', 'jsonb'), ('gather_nodes', 'jsonb'), ('faction_control', 'text'), ('is_starting_area', 'boolean'), ('active', 'boolean'),
     ('world_x', 'int'), ('world_y', 'int'), ('elevation', 'int'), ('terrain_cost', 'numeric'), ('rest_spot_type', 'text'), ('rest_spot_name', 'text'), ('rest_quality', 'int'), ('rest_fee', 'int'),
     ('rest_risk', 'int'), ('is_safe_zone', 'boolean'), ('has_stable', 'boolean'), ('contested', 'boolean'), ('home_faction_id', 'text'), ('control_faction_id', 'text')],
     'region_id', ['territory_id', 'territory_name', 'region_name', 'region_type', 'danger_level', 'min_level', 'description', 'travel_from', 'faction_control', 'world_x', 'world_y',
                   'elevation', 'active', 'home_faction_id', 'control_faction_id'],
     {'travel_from': TA('travel_from'), 'gather_nodes': "'{}'::text[]", 'is_starting_area': 'false', 'active': 'true', 'has_stable': 'false', 'contested': 'false'})
bulk('world_region_theme', [dict(region_id=r['id'], theme=r['theme']) for r in R], [('region_id', 'text'), ('theme', 'text')], 'region_id', ['theme'])
for r in R:
    for n in r['nb']:
        w(f"update public.world_map_regions set travel_from = array_append(travel_from, '{r['id']}') where region_id = '{n}' and not ('{r['id']}' = any (travel_from));")

rows = []
for rid, (bn, fs, clue, ev, hz, vis) in D.PROFILES.items():
    loot = [i for c in D.SPOT_LOOT[rid].values() for i in c]
    sig = list(dict.fromkeys(reversed(loot)))[:3]
    rows.append(dict(region_id=rid, biome_key=next(r['theme'] for r in R if r['id'] == rid), biome_name=bn, faction_style=fs, signature_clue=clue, signature_event=ev,
                     signature_items=sig, survival_hazard=hz, visual_identity=vis, signature_resources=sorted(set(loot)), investigation_reward='그 지역의 옛 기록과 세력의 흔적'))
bulk('world_region_profiles', rows, [('region_id', 'text'), ('biome_key', 'text'), ('biome_name', 'text'), ('faction_style', 'text'), ('signature_clue', 'text'), ('signature_event', 'text'),
     ('signature_items', 'jsonb'), ('survival_hazard', 'text'), ('visual_identity', 'text'), ('signature_resources', 'jsonb'), ('investigation_reward', 'text')], 'region_id',
     ['biome_name', 'faction_style', 'signature_clue', 'signature_event', 'signature_items', 'survival_hazard', 'visual_identity', 'signature_resources'],
     {'signature_items': TA('signature_items'), 'signature_resources': TA('signature_resources')})
bulk('world_region_lore', [dict(region_id=rid, lines=[{'s': None, 't': t} for t in ls]) for rid, ls in D.LORE.items()], [('region_id', 'text'), ('lines', 'jsonb')], 'region_id', ['lines'])

spot_names = set(REF['spots'])
fresh('nodes', [n for v in D.NODES.values() for row in v for n in row], '답사 지점')
for rid, cats in D.SPOT_LOOT.items():
    for c, its in cats.items():
        need_items(its, rid + ' 채집터')
        if c not in D.SPOT_NOUN:
            errors.append('채집터 분류 없음: ' + c)


def spot_name(rid, cat, k):
    adj, nouns = D.SPOT_ADJ[rid], D.SPOT_NOUN[cat]
    for i in range(len(adj) * len(nouns)):
        a, n = adj[(k + i) % len(adj)], nouns[(k * 3 + i) % len(nouns)]
        nm = f'{a} {n}'
        if nm not in spot_names:
            spot_names.add(nm)
            return nm
    raise SystemExit('채집터 이름이 모자람: ' + rid + cat)


nrows, srows = [], []
for r in R:
    rid, lv = r['id'], r['lv']
    levels = D.NODES[rid]
    if [len(x) for x in levels] != [1, 2, 4, 6, 8]:
        errors.append('답사 지점 수가 1·2·4·6·8이 아님: ' + rid)
    ids = [[U('node', rid, str(h), str(i)) for i in range(len(row))] for h, row in enumerate(levels)]
    parents = {}
    for i in range(len(levels[1])): parents[(1, i)] = ids[0][0]
    for i in range(len(levels[2])): parents[(2, i)] = ids[1][i // 2]
    k = 0
    for p, n in enumerate(L4_KIDS):
        for _ in range(n): parents[(3, k)] = ids[2][p]; k += 1
    k = 0
    for p, n in enumerate(L5_KIDS):
        for _ in range(n): parents[(4, k)] = ids[3][p]; k += 1
    cats = list(D.SPOT_LOOT[rid].keys())
    sk = 0
    for h, row in enumerate(levels):
        for i, nm in enumerate(row):
            nid = ids[h][i]; hl = h + 1
            nlv = min(CAP, lv + max(0, hl - 2) * 2)
            nrows.append(dict(node_id=nid, region_id=rid, parent_node_id=parents.get((h, i)), hierarchy_level=hl, node_name=nm, min_level=nlv, sort_order=i))
            if hl == 1:
                en, ec = D.ENTRY_SPOT[rid]
                if en in spot_names: errors.append('채집터 이름 겹침: ' + en)
                if ec not in D.SPOT_LOOT[rid]: errors.append('들머리 채집터 분류가 지역에 없음: ' + rid)
                spot_names.add(en)
                srows.append(dict(spot_id=U('spot', rid, 'entry'), node_id=nid, spot_name=en, category=ec, r=rid, min_level=lv, yield_min=1, yield_max=2, difficulty=1))
                continue
            for j in range(2):
                cat = cats[(sk + j) % len(cats)]
                srows.append(dict(spot_id=U('spot', rid, str(h), str(i), str(j)), node_id=nid, spot_name=spot_name(rid, cat, sk + j), category=cat, r=rid,
                                  min_level=nlv, yield_min=1, yield_max=2 if hl <= 3 else 3, difficulty=min(10, 2 + hl + lv // 5)))
            sk += 2
ND = "(" + J({str(k): v for k, v in NODE_DESC.items()}) + " ->> x.hierarchy_level::text)"
bulk('world_exploration_nodes', sorted(nrows, key=lambda x: x['hierarchy_level']), [('node_id', 'text'), ('region_id', 'text'), ('parent_node_id', 'text'), ('hierarchy_level', 'smallint'),
     ('node_name', 'text'), ('description', 'text'), ('min_level', 'int'), ('sort_order', 'int')], 'node_id', ['node_name', 'parent_node_id', 'min_level'],
     {'node_id': 'md5(x.node_id)::uuid', 'parent_node_id': 'md5(x.parent_node_id)::uuid', 'description': ND})
LOOT = "array(select jsonb_array_elements_text(" + J(D.SPOT_LOOT) + " -> x.r -> x.category))"
bulk('world_gathering_spots', srows, [('spot_id', 'text'), ('node_id', 'text'), ('spot_name', 'text'), ('category', 'text'), ('loot_items', 'jsonb'), ('min_level', 'int'),
     ('yield_min', 'int'), ('yield_max', 'int'), ('difficulty', 'int'), ('active', 'boolean'), ('r', 'text')], 'spot_id', ['spot_name', 'loot_items', 'min_level'],
     {'spot_id': 'md5(x.spot_id)::uuid', 'node_id': 'md5(x.node_id)::uuid', 'loot_items': LOOT, 'active': 'true'})

mons = [m for v in D.MONSTERS.values() for m in v]
fresh('monsters', [m[1] for m in mons], '요괴')
fresh('monster_ids', [m[0] for m in mons], '요괴 id')
KINDS = {'bird', 'shell', 'ghost', 'venom', 'wood', 'shadow', 'water', 'swarm', 'ward', 'mirror', 'breaker', 'sky', 'giant'}
rows = []
for rid, ms in D.MONSTERS.items():
    L = next(r['lv'] for r in R if r['id'] == rid)
    if sorted(m[3] for m in ms) != ['common', 'common', 'guardian', 'main', 'main']:
        errors.append('요괴 역할 짜임이 다름: ' + rid)
    for mid, nm, ty, role, kind, mech, desc, drops in ms:
        if kind not in KINDS: errors.append('없는 갈래: ' + kind)
        if mech not in MECH_DESC: errors.append('없는 습성: ' + mech)
        need_items(drops, mid)
        if role == 'common': lo, hi, hp, atk, wt, dr = L, min(CAP, L + 3), 70 + 14 * L, round(8 + 1.1 * L), 14, 2
        elif role == 'main': lo, hi, hp, atk, wt, dr = min(CAP, L + 2), min(CAP + 1, L + 6), 150 * L, round(7.5 * L), 15, 5
        else: lo, hi, hp, atk, wt, dr = L, min(CAP, L + 2), round((70 + 14 * L) * 1.5), round((8 + 1.1 * L) * 1.4), 12, 10
        rows.append(dict(monster_id=mid, region_id=rid, monster_name=nm, monster_type=ty, min_level=lo, max_level=hi, hp=hp, attack_power=atk, spawn_weight=wt, description=desc,
                         drops=drops, difficulty_rank=dr, mechanic_key=mech, mechanic_description=MECH_DESC[mech], role=role, kind=kind))
bulk('world_region_monsters', rows, [('monster_id', 'text'), ('region_id', 'text'), ('monster_name', 'text'), ('monster_type', 'text'), ('min_level', 'int'), ('max_level', 'int'),
     ('hp', 'int'), ('attack_power', 'int'), ('spawn_weight', 'int'), ('description', 'text'), ('drops', 'jsonb'), ('difficulty_rank', 'int'), ('mechanic_key', 'text'),
     ('mechanic_description', 'text'), ('role', 'text'), ('kind', 'text')], 'monster_id',
     ['monster_name', 'description', 'drops', 'min_level', 'max_level', 'hp', 'attack_power', 'mechanic_key', 'kind', 'role'])

fresh('grounds', [g for v in D.GROUNDS.values() for g, _ in v], '원정지')
rows = []
for rid, gs in D.GROUNDS.items():
    r = next(x for x in R if x['id'] == rid)
    for d, (gn, gd) in enumerate(gs, 1):
        rows.append(dict(ground_id=rid + '_' + str(d), region_id=rid, ground_name=gn, description=gd, depth=d, danger=min(10, r['danger'] + d - 1),
                         min_level=min(CAP, r['lv'] + (d - 1) * 2), unlock_progress=[0, 30, 70][d - 1]))
bulk('world_expedition_grounds', rows, [('ground_id', 'text'), ('region_id', 'text'), ('ground_name', 'text'), ('description', 'text'), ('depth', 'int'), ('danger', 'int'), ('min_level', 'int'),
     ('unlock_progress', 'int')], 'ground_id', ['ground_name', 'description', 'min_level'])
fresh('fish_grounds', [f[2] for f in D.FISH], '낚시터')
bulk('world_fish_grounds', [dict(region_id=rid, habitat=h, ground_name=gn, description=gd) for rid, h, gn, gd in D.FISH],
     [('region_id', 'text'), ('habitat', 'text'), ('ground_name', 'text'), ('description', 'text')], 'region_id, habitat', ['ground_name', 'description'])
fresh('sites', [s[1] for v in D.SITES.values() for s in v], '조사 지점')
rows = []
for rid, sites in D.SITES.items():
    for k, (ty, nm, loot, rare) in enumerate(sites):
        need_items(loot + rare, nm)
        lc, lcs = SITE_CAT[ty]
        rows.append(dict(site_id=rid + '_s' + str(k + 1), region_id=rid, site_name=nm, site_type=ty, bonus_item=loot[0], loot_table=loot,
                         rare_bonus={'items': rare, 'chance': 0.2, 'remote_bonus': True, 'distance_from_headquarters': 300}, description=SITE_DESC[ty], bonus_chance=18, loot_category=lc, loot_categories=lcs))
bulk('world_region_sites', rows, [('site_id', 'text'), ('region_id', 'text'), ('site_name', 'text'), ('site_type', 'text'), ('bonus_item', 'text'), ('loot_table', 'jsonb'), ('rare_bonus', 'jsonb'),
     ('description', 'text'), ('bonus_chance', 'int'), ('loot_category', 'text'), ('loot_categories', 'jsonb'), ('active', 'boolean')], 'site_id', ['site_name', 'loot_table', 'rare_bonus', 'active'],
     {'loot_categories': TA('loot_categories'), 'active': 'true'})

ids = ', '.join(f"'{r['id']}'" for r in R)
w(f"""insert into public.world_gathering_discoveries(owner_id, spot_id)
select c.owner_id, gs.spot_id from public.world_characters c
  cross join public.world_gathering_spots gs join public.world_exploration_nodes n on n.node_id = gs.node_id and n.hierarchy_level = 1 and n.region_id in ({ids})
on conflict do nothing;""")

moves = [m for m in D.MOVES if m['apply']]
GUARD = open(os.path.join(HERE, 'move_guard.sql')).read()


def relocate():
    import data_relocate as RL
    w(open(os.path.join(HERE, 'line_fix.sql')).read())
    for kind, key, step, old, new in RL.LINE_FIX:
        w(f"select pg_temp.yh_line_fix('{kind}', '{key}', {step}, {T(old)}, {T(new)});")
    for qid, st, need in RL.STEP_NEED:
        w(f"""do $c$ declare n int; begin
  update public.world_quest_steps set need = {J(need)} where quest_id = '{qid}' and step = {st} and need::text like '%"m_21"%';
  get diagnostics n = row_count;
  if n <> 1 then raise exception '고칠 할 일을 못 찾음: {qid} {st}'; end if;
end $c$;""")
    for cid, old, new in RL.CHAPTER_FIX:
        w(f"""do $c$ declare n int; begin
  update public.world_story_chapters set summary = replace(summary, {T(old)}, {T(new)}), intro = replace(intro, {T(old)}, {T(new)}), outro = replace(outro, {T(old)}, {T(new)})
   where chapter_id = '{cid}' and position({T(old)} in coalesce(summary, '') || coalesce(intro, '') || coalesce(outro, '')) > 0;
  get diagnostics n = row_count;
  if n <> 1 then raise exception '고칠 장 소개를 못 찾음: {cid}'; end if;
end $c$;""")
    for cid, name, rid in RL.CLUE_FIX:
        w(f"update public.world_story_clues set name = {T(name)}, region_id = '{rid}' where clue_id = '{cid}';")
    for qid, st, ot, nt, og, ng in RL.STEP_TEXT:
        w(f"""do $c$ declare n int; begin
  update public.world_quest_steps set title = {T(nt)}, goal = {T(ng)} where quest_id = '{qid}' and step = {st} and title = {T(ot)} and goal = {T(og)};
  get diagnostics n = row_count;
  if n <> 1 then raise exception '고칠 장면 제목·설명을 못 찾음: {qid} {st}'; end if;
end $c$;""")
    for case, cid, on, nn, orr, nr in RL.CASE_CLUE_FIX:
        w(f"""do $c$ declare n int; begin
  update public.world_case_progress p set clues = (select jsonb_agg(case when e->>'id' = '{cid}' then e || jsonb_build_object('title', case when e->>'title' = {T(on)} then {T(nn)} else e->>'title' end, 'region', case when e->>'region' = '{orr}' then '{nr}' else e->>'region' end) - case when e ? 'title' then '' else 'title' end - case when e ? 'region' then '' else 'region' end else e end order by o)
    from jsonb_array_elements(p.clues) with ordinality t(e, o))
   where p.case_id = '{case}' and jsonb_typeof(p.clues) = 'array' and exists (select 1 from jsonb_array_elements(p.clues) e where e->>'id' = '{cid}' and (e->>'title' = {T(on)} or e->>'region' = '{orr}'));
  get diagnostics n = row_count;
  raise notice '단서 기록 고침 {cid}: %', n;
end $c$;""")
    for qid, q in RL.QUESTS.items():
        w(f"update public.world_quests set region_id = '{q['region']}', title = {T(q['title'])}, summary = {T(q['summary'])} where quest_id = '{qid}';")
        for st, (title, goal, need, ls) in q['steps'].items():
            w(f"update public.world_quest_steps set title = {T(title)}, goal = {T(goal)}, need = {J(need)}, lines = {J([{'s': a, 't': b} for a, b in ls])} where quest_id = '{qid}' and step = {st};")
    for key, sc in RL.SCENES.items():
        if 'drop_tail' in sc:
            w(f"""update public.world_faction_scenes f set lines = (select jsonb_agg(e order by o) from jsonb_array_elements(f.lines) with ordinality t(e, o) where position({T(sc['drop_tail'])} in e->>'t') = 0)
  || {J([{'s': a, 't': b} for a, b in sc['lines_tail']])} where f.scene_key = '{key}' and position({T(sc['drop_tail'])} in f.lines::text) > 0;""")
        else:
            w(f"update public.world_faction_scenes set title = {T(sc['title'])}, goal = {T(sc['goal'])}, need = {J(sc['need'])}, lines = {J([{'s': a, 't': b} for a, b in sc['lines']])} where scene_key = '{key}';")
    w(open(os.path.join(HERE, 'relocate_check.sql')).read())
if moves:
    vals = ', '.join(f"('{m['region']}', {m['d']})" for m in moves)
    w(f"""create temp table yh_lvshift(region_id text primary key, d int) on commit drop;
insert into yh_lvshift values {vals};
create temp table yh_lvkeep(quest_id text primary key) on commit drop;
insert into yh_lvkeep select jsonb_array_elements_text({J([k for m in moves for k in m.get('keep', [])])});
update public.world_map_regions r set min_level = r.min_level + x.d from yh_lvshift x where x.region_id = r.region_id;
update public.world_exploration_nodes n set min_level = greatest(1, least({CAP}, n.min_level + x.d)) from yh_lvshift x where x.region_id = n.region_id;
update public.world_gathering_spots g set min_level = greatest(1, least({CAP}, g.min_level + x.d))
  from public.world_exploration_nodes n, yh_lvshift x where n.node_id = g.node_id and x.region_id = n.region_id;
update public.world_expedition_grounds e set min_level = greatest(1, least({CAP}, e.min_level + x.d)) from yh_lvshift x where x.region_id = e.region_id;
update public.world_region_monsters m set
    hp = round(m.hp * (70 + (m.min_level + x.d) * 14.0) / (70 + m.min_level * 14.0)),
    attack_power = round(m.attack_power * (8 + (m.min_level + x.d) * 1.1) / (8 + m.min_level * 1.1)),
    min_level = m.min_level + x.d, max_level = m.max_level + x.d
  from yh_lvshift x where x.region_id = m.region_id;
update public.world_quest_steps s set reward = s.reward
      || case when s.reward ? 'xp' then jsonb_build_object('xp', round((s.reward ->> 'xp')::numeric * (100 * (q.min_level + x.d) + 12 * (q.min_level + x.d) ^ 2) / (100 * q.min_level + 12 * q.min_level ^ 2))::int) else '{{}}'::jsonb end
      || case when s.reward ? 'gil' then jsonb_build_object('gil', round((s.reward ->> 'gil')::numeric * (5 + 4 * (q.min_level + x.d)) / (5 + 4 * q.min_level))::int) else '{{}}'::jsonb end
  from public.world_quests q, yh_lvshift x
 where q.quest_id = s.quest_id and q.region_id = x.region_id and q.kind = 'side' and s.reward is not null and s.reward <> '{{}}'::jsonb
   and q.quest_id not in (select quest_id from yh_lvkeep);
update public.world_quests q set min_level = greatest(1, least({CAP}, q.min_level + x.d)) from yh_lvshift x where x.region_id = q.region_id and q.kind = 'side'
   and q.quest_id not in (select quest_id from yh_lvkeep);""")
    if any(m.get('relocate') for m in moves):
        relocate()
    up = [m['region'] for m in moves if m['d'] > 0]
    if up:
        w(GUARD.replace('@UP@', J(up)))

fresh('npcs', [nm for nm, _ in Q.NPCS.values()], '인물')
fresh('npc_keys', list(Q.NPCS), '인물 키')
fresh('quests', [q['id'] for q in Q.QUESTS], '퀘스트 id')
bulk('world_quest_npcs', [dict(npc_key=k, npc_name=nm, bio=bio) for k, (nm, bio) in Q.NPCS.items()], [('npc_key', 'text'), ('npc_name', 'text'), ('bio', 'text')], 'npc_key', ['npc_name', 'bio'])
RR = REF['reward_rules']['side']
qrows, strows = [], []
mon_region = {m[0]: rid for rid, ms in D.MONSTERS.items() for m in ms}
spot_items = {rid: {i for c in cats.values() for i in c} for rid, cats in D.SPOT_LOOT.items()}
for i, q in enumerate(Q.QUESTS):
    L = q['L']
    if L != next(r['lv'] for r in R if r['id'] == q['region']):
        errors.append('퀘스트 레벨이 지역 레벨과 다름: ' + q['id'])
    tot = round(RR['xp'] * xp_need(L))
    task_steps = [k for k, st in enumerate(q['steps']) if st[2].get('tasks') or st[2].get('give')]
    per = tot // max(1, len(task_steps))
    gil = RR['gil'][0] + RR['gil'][1] * L
    items = dict(next(v for lim, v in RR['items'] if L <= lim))
    for k_, v_ in q.get('items_extra', {}).items():
        items[k_] = items.get(k_, 0) + v_
    need_items(items, q['id'] + ' 보상')
    qrows.append(dict(quest_id=q['id'], cat=q['cat'], title=q['title'], summary=q['summary'], region_id=q['region'], min_level=L, after=[], sort=1400 + i, epilogue=[]))
    for k, (title, goal, need, ls) in enumerate(q['steps']):
        for t in need.get('tasks', []):
            if isinstance(t.get('r'), str): t['r'] = [t['r']]
            for m in t.get('m', []):
                if mon_region.get(m) != q['region']: errors.append('할 일 요괴가 그 지역에 없음: ' + m)
            for it in t.get('items', []):
                if it not in spot_items[q['region']]: errors.append('할 일 물품이 그 지역 채집터에 없음: ' + it)
        need_items(need.get('give', {}), q['id'] + ' 넘기기')
        prev = None
        for s_, t_ in ls:
            if s_ == 'me': errors.append('주인공 말하는 이 금지: ' + q['id'])
            if s_ is not None and s_ != prev and prev is not None:
                errors.append(f'말하는 이가 바뀌기 전에 서술이 없음: {q["id"]} {k + 1} {t_[:12]}')
            if s_ is None and t_.rstrip()[-1:] not in ('.', '다', '?', '」'):
                errors.append(f'서술 끝맺음 확인: {q["id"]} {t_[-12:]}')
            prev = s_
        rw = {}
        if k in task_steps: rw['xp'] = per
        if k == len(q['steps']) - 1:
            rw['gil'] = gil
            rw['items'] = items
        strows.append(dict(quest_id=q['id'], step=k + 1, title=title, goal=goal, need=need, lines=[{'s': s_, 't': t_} for s_, t_ in ls], reward=rw))
bulk('world_quests', qrows, [('quest_id', 'text'), ('kind', 'text'), ('cat', 'text'), ('title', 'text'), ('summary', 'text'), ('region_id', 'text'), ('min_level', 'int'), ('after', 'jsonb'),
     ('sort', 'int'), ('epilogue', 'jsonb'), ('active', 'boolean')], 'quest_id', ['cat', 'title', 'summary', 'region_id', 'min_level', 'after', 'sort', 'epilogue', 'active'],
     {'kind': "'side'", 'after': TA('after'), 'active': 'true'})
bulk('world_quest_steps', strows, [('quest_id', 'text'), ('step', 'int'), ('title', 'text'), ('goal', 'text'), ('need', 'jsonb'), ('lines', 'jsonb'), ('reward', 'jsonb')],
     'quest_id, step', ['title', 'goal', 'need', 'lines', 'reward'])

w(open(os.path.join(HERE, 'patch_note.sql')).read())
w("""select public.world_quest_label_refresh();
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116030000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;""")

if errors:
    sys.stderr.write('\n'.join(errors) + '\n')
    sys.exit(1)
print('\n'.join(out))
sys.stderr.write(f"지역 {len(R)} · 답사 지점 {len(nrows)} · 채집터 {len(srows)} · 요괴 {len(mons)} · 원정지 {sum(len(v) for v in D.GROUNDS.values())} · 낚시터 {len(D.FISH)} · "
                 f"조사 지점 {sum(len(v) for v in D.SITES.values())} · 퀘스트 {len(Q.QUESTS)} · 레벨 옮김 {len(moves)}\n")
