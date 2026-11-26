import hashlib
import subprocess
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import data_world as D
import data_quests as Q

J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + '$J$::jsonb'
U = lambda *k: 'hw40/' + '/'.join(k)
TA = lambda c: f"array(select jsonb_array_elements_text(x.{c}))"
out = []
w = out.append
part = lambda f: w(open(os.path.join(HERE, f)).read())
CAP = D.CAP
REF = json.load(open(os.path.join(HERE, 'ref', 'existing_names.json')))
errors = []
warns = []
DB_VERSION = '20261128000000'


def fresh(kind, names, label):
    seen = set()
    have = set(REF.get(kind, []))
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


MECH_DESC = {
    'tide': '물살로 끌어당겨 발을 묶는다. 거리를 두고 싸우거나 묶이기 전에 끊어라.', 'aerial': '하늘에서 내리꽂는다. 원거리 사격이 잘 듣는다.',
    'spectral': '몸이 반쯤 비친다. 물리 공격이 덜 듣고 술법이 잘 듣는다.', 'toxic': '독을 뿜는다. 해독할 약초와 회복품을 챙겨라.',
    'armored': '껍질이 단단하다. 방어를 무시하는 공격이나 술법이 낫다.', 'reflect': '공격의 일부를 되돌린다. 원거리 사격이나 봉인 제압을 써라.',
    'warded': '결계를 두른다. 결계를 깨는 한 방을 모아 두어라.', 'seal_breaker': '봉인을 약하게 만든다. 부적과 봉인 재료를 챙겨라.',
    'swarm': '떼로 몰려든다. 세 번째 행동마다 강하게 반격한다.', 'ambush': '숨어 있다 먼저 친다. 낌새를 살피고 방어를 섞어라.',
    'boss': '우두머리급 위협. 세 번째 행동마다 광역급 강공격을 하므로 방어 태세를 섞어라.',
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
ICOLS = [('item_id', 'text'), ('item_name', 'text'), ('category', 'text'), ('tier', 'int'), ('description', 'text'), ('stackable', 'boolean'), ('required_stats', 'jsonb'), ('minimum_level', 'int'),
         ('rarity', 'text'), ('acquisition_difficulty', 'int'), ('drop_rate_modifier', 'numeric'), ('equipment_traits', 'jsonb'), ('tradeable', 'boolean'), ('reference_price', 'bigint'), ('stack_size', 'int'),
         ('use_fx', 'jsonb')]
IUPD = ['item_name', 'category', 'tier', 'description', 'required_stats', 'equipment_traits', 'minimum_level', 'stack_size', 'tradeable', 'reference_price', 'use_fx']
RCOLS = [('recipe_id', 'text'), ('recipe_name', 'text'), ('output_item', 'text'), ('output_qty', 'int'), ('ingredients', 'jsonb'), ('required_tool_tier', 'int'),
         ('required_location', 'text'), ('description', 'text'), ('minimum_level', 'int'), ('recipe_difficulty', 'int'), ('quality_bonus', 'int'), ('required_skill', 'text'),
         ('required_skill_rank', 'int'), ('craft_field', 'text')]
RUPD = ['recipe_name', 'output_item', 'output_qty', 'ingredients', 'craft_field', 'required_location', 'minimum_level', 'description', 'recipe_difficulty', 'required_skill', 'required_skill_rank']
RARITY = {1: 'common', 2: 'uncommon', 3: 'rare', 4: 'epic'}
ACC = {'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool'}
R = D.REGIONS
RID = {r['id']: r for r in R}
GEAR_PLACE_NAME = RID[D.GEAR_PLACE]['name']


def fx_full(fx):
    base = {'er': 0, 'hp': 0, 'mn': 0, 'sp': 0, 'stam': 0, 'buffs': [], 'cures': []}
    base.update(fx or {})
    return base


def item(iid, nm, cat, tier, desc, stack, price, tradeable, lv, traits=None, req=None, fx=None):
    return dict(item_id=iid, item_name=nm, category=cat, tier=tier, description=desc, stackable=stack > 1, required_stats=req or {}, minimum_level=lv,
                rarity=RARITY.get(tier, 'legendary'), acquisition_difficulty=min(5, tier), drop_rate_modifier=1, equipment_traits=traits or {}, tradeable=tradeable,
                reference_price=price, stack_size=stack, use_fx=fx_full(fx) if fx is not None else None)


def recipe(rid, nm, output, qty, mats, field, lv, desc, diff=4, loc=None, skill=None, rank=1):
    return dict(recipe_id=rid, recipe_name=nm, output_item=output, output_qty=qty, ingredients=mats, required_tool_tier=1, required_location=loc,
                description=desc, minimum_level=lv, recipe_difficulty=diff, quality_bonus=0, required_skill=skill, required_skill_rank=rank, craft_field=field)


quests, qsteps = Q.build()
order = {}
for s in qsteps:
    c = int(s['quest'][len(Q.QID):])
    regs = list(s['need'].get('at', []))
    for t in s['need'].get('tasks', []):
        regs += t.get('r', [])
    for rg in regs:
        if rg in RID and rg not in order:
            order[rg] = (c, s['step'])


def gate(rg):
    c, k = order[rg]
    if k > 1:
        return f'{Q.QID}{c}:{k - 1}'
    return Q.QID + str(c - 1) if c > 1 else Q.AFTER_FIRST[0]


for r in R:
    if r['id'] not in order:
        order[r['id']] = (99, 1)


def pull_open():
    import heapq
    nbs = {r['id']: [n for n in r['nb'] if n in RID] for r in R}
    start = [r['id'] for r in R if any(n not in RID for n in r['nb'])]
    for dest in sorted(RID, key=lambda x: order[x]):
        g = order[dest]
        dist, prev, pq = {s: (0 if order[s] <= g else 1) for s in start}, {}, []
        for s0 in start: heapq.heappush(pq, (dist[s0], s0))
        while pq:
            d, u = heapq.heappop(pq)
            if d > dist.get(u, 1e9): continue
            for v in nbs[u]:
                nd = d + (0 if order[v] <= g else 1)
                if nd < dist.get(v, 1e9): dist[v] = nd; prev[v] = u; heapq.heappush(pq, (nd, v))
        if dest not in dist: errors.append('들어갈 길이 없는 지역: ' + dest); continue
        u = dest
        while u in prev:
            u = prev[u]
            if order[u] > g: order[u] = g
        for s0 in start:
            if u == s0 and order[s0] > g: order[s0] = g


pull_open()
REGION_OPEN = {r['id']: gate(r['id']) for r in R}

w("lock table public.world_characters in access exclusive mode;\n")
part('../a_level.sql')
part('b_tier9.sql')
part('c_story.sql')
part('d_realm.sql')

rules = {}
for tid, tname in D.TERRS.items():
    regs = [r['id'] for r in R if r['terr'] == tid]
    first = min(regs, key=lambda x: order[x])
    rule = {'name': tname, 'open_quest': REGION_OPEN[first], 'no_shadow': True, 'rare': D.HW, 'mon_cap': D.MON_CAP, 'realm': D.REALM, 'gap': D.REALM_GAP, 'color': D.TERR_COLORS[tid], 'mirror_x': D.MIRROR_X, 'twins': {rg: D.MIRROR[rg] for rg in regs if rg in D.MIRROR}, 'sea': [rg for rg in regs if rg in D.SEA_FISH_REGIONS],
            'regions': {rg: REGION_OPEN[rg] for rg in regs}}
    if tid in D.PIN_TERRS:
        rule['pin'] = True
    rules[tid] = rule
w(f"""do $d$
declare j jsonb := public.world_domain_rules() || {J(rules)};
begin
  execute format('create or replace function public.world_domain_rules() returns jsonb language sql immutable as %L', format('select %L::jsonb', j::text));
end $d$;
grant execute on function public.world_domain_rules() to anon, authenticated;
do $d$
declare j jsonb := (select jsonb_agg(distinct v) from (select jsonb_array_elements_text(public.world_weak_safe_rules()) v union select jsonb_array_elements_text({J(D.WEAK_SAFE)})) z);
begin
  execute format('create or replace function public.world_weak_safe_rules() returns jsonb language sql immutable as %L', format('select %L::jsonb', j::text));
end $d$;""")

fresh('regions', [r['name'] for r in R], '지역')
fresh('region_ids', [r['id'] for r in R], '지역 id')
fresh('territories', list(D.TERRS), '영역 id')
rows = []
for r in R:
    rest = r.get('rest') or ('임시 야영지', 'field_camp', 2, 1)
    shop = r.get('shop') or (None, None)
    rows.append(dict(region_id=r['id'], territory_id=r['terr'], territory_name=D.TERRS[r['terr']], region_name=r['name'], region_type=r['type'], danger_level=r['danger'], min_level=r['lv'],
                     description=r['desc'], travel_from=r['nb'], faction_control='무주 금역', world_x=r['x'], world_y=r['y'], elevation=r['el'], terrain_cost=0.8 if r.get('safe') else 1,
                     rest_spot_type=rest[1], rest_spot_name=rest[0], rest_quality=rest[3], rest_fee=rest[2], rest_risk=0 if r.get('safe') else 30, is_safe_zone=bool(r.get('safe')),
                     shop_id=shop[0], shop_name=shop[1], theme=r['theme']))
bulk('world_map_regions', rows, [('region_id', 'text'), ('territory_id', 'text'), ('territory_name', 'text'), ('region_name', 'text'), ('region_type', 'text'), ('danger_level', 'int'),
     ('min_level', 'int'), ('description', 'text'), ('travel_from', 'jsonb'), ('gather_nodes', 'jsonb'), ('faction_control', 'text'), ('is_starting_area', 'boolean'), ('active', 'boolean'),
     ('world_x', 'int'), ('world_y', 'int'), ('elevation', 'int'), ('terrain_cost', 'numeric'), ('rest_spot_type', 'text'), ('rest_spot_name', 'text'), ('rest_quality', 'int'), ('rest_fee', 'int'),
     ('rest_risk', 'int'), ('is_safe_zone', 'boolean'), ('shop_id', 'text'), ('shop_name', 'text'), ('has_stable', 'boolean'), ('contested', 'boolean')],
     'region_id', ['travel_from', 'description', 'min_level', 'danger_level', 'world_x', 'world_y', 'rest_fee', 'shop_id', 'shop_name', 'active', 'territory_id', 'territory_name'],
     {'travel_from': TA('travel_from'), 'gather_nodes': "'{}'::text[]", 'is_starting_area': 'false', 'active': 'true', 'has_stable': 'false', 'contested': 'false'})
bulk('world_region_theme', [dict(region_id=r['id'], theme=r['theme']) for r in R], [('region_id', 'text'), ('theme', 'text')], 'region_id', ['theme'])
mine = set(RID)
for r in R:
    for n in r['nb']:
        if n not in mine:
            w(f"update public.world_map_regions set travel_from = array_append(travel_from, '{r['id']}') where region_id = '{n}' and not ('{r['id']}' = any (travel_from));")
        elif r['id'] not in RID[n]['nb']:
            errors.append(f"이웃이 한쪽만: {r['id']} → {n}")
for tid, wts in D.CLIMATES.items():
    w(f"insert into public.world_weather_climate(territory_id, weights) values ('{tid}', {J(wts)}) on conflict (territory_id) do update set weights = excluded.weights;")

rows = []
for rid, (bn, fs, clue, ev, hz, vis) in D.PROFILES.items():
    loot = [i for c in D.SPOT_LOOT[rid].values() for i in c]
    sig = list(dict.fromkeys(reversed(loot)))[:3]
    rows.append(dict(region_id=rid, biome_key=RID[rid]['theme'], biome_name=bn, faction_style=fs, signature_clue=clue, signature_event=ev,
                     signature_items=sig, survival_hazard=hz, visual_identity=vis, signature_resources=sorted(set(loot)), investigation_reward='건넛누리의 흐름 기록'))
bulk('world_region_profiles', rows, [('region_id', 'text'), ('biome_key', 'text'), ('biome_name', 'text'), ('faction_style', 'text'), ('signature_clue', 'text'), ('signature_event', 'text'),
     ('signature_items', 'jsonb'), ('survival_hazard', 'text'), ('visual_identity', 'text'), ('signature_resources', 'jsonb'), ('investigation_reward', 'text')], 'region_id',
     ['biome_name', 'faction_style', 'signature_clue', 'signature_event', 'signature_items', 'survival_hazard', 'visual_identity', 'signature_resources'],
     {'signature_items': TA('signature_items'), 'signature_resources': TA('signature_resources')})
bulk('world_region_lore', [dict(region_id=rid, lines=[{'s': None, 't': t} for t in ls]) for rid, ls in D.LORE.items()], [('region_id', 'text'), ('lines', 'jsonb')], 'region_id', ['lines'])

spot_names = set(REF['spots'])
fresh('nodes', [n for v in D.NODES.values() for row in v for n in row], '답사 지점')


def spot_name(rid, cat, k):
    adj, nouns = D.SPOT_ADJ[rid], D.SPOT_NOUN[cat]
    for i in range(len(adj) * len(nouns)):
        a, n = adj[(k + i) % len(adj)], nouns[(k * 3 + i) % len(nouns)]
        nm = f'{a} {n}'
        if nm not in spot_names:
            spot_names.add(nm)
            return nm
    raise SystemExit('채집터 이름이 모자람: ' + rid + cat)


SPOT_SEQ = {}


def spot_loot(rid, cat):
    import itertools
    pool = D.SPOT_POOL[rid][cat]
    combos = [c for n in (2, 3, 4) for c in itertools.combinations(pool, n)]
    combos.sort(key=lambda c: hashlib.md5((rid + cat + '|'.join(c)).encode()).hexdigest())
    k = SPOT_SEQ.get((rid, cat), 0)
    SPOT_SEQ[(rid, cat)] = k + 1
    if k >= len(combos): errors.append(f'채집터 재료 조합이 모자람: {rid} {cat}')
    return list(combos[k % len(combos)])


nrows, srows = [], []
for r in R:
    rid, lv = r['id'], r['lv']
    levels = D.NODES[rid]
    ids = [[U('node', rid, str(h), str(i)) for i in range(len(row))] for h, row in enumerate(levels)]
    parents = {}
    if len(levels) > 1:
        for i in range(len(levels[1])): parents[(1, i)] = ids[0][0]
    if len(levels) > 2:
        for i in range(len(levels[2])): parents[(2, i)] = ids[1][i // 2]
    if len(levels) > 3:
        k = 0
        for p, n in enumerate(L4_KIDS):
            for _ in range(n): parents[(3, k)] = ids[2][p]; k += 1
    if len(levels) > 4:
        k = 0
        for p, n in enumerate(L5_KIDS):
            for _ in range(n): parents[(4, k)] = ids[3][p]; k += 1
    cats = list(D.SPOT_LOOT[rid].keys())
    sk = 0
    for h, row in enumerate(levels):
        for i, nm in enumerate(row):
            nid = ids[h][i]; hl = h + 1
            nlv = lv if hl == 1 else min(CAP, lv + max(0, hl - 2))
            nrows.append(dict(node_id=nid, region_id=rid, parent_node_id=parents.get((h, i)), hierarchy_level=hl, node_name=nm, min_level=nlv, sort_order=i))
            if hl == 1:
                en, ec = D.ENTRY_SPOT[rid]
                if en in spot_names: errors.append('채집터 이름 겹침: ' + en)
                spot_names.add(en)
                srows.append(dict(spot_id=U('spot', rid, 'entry'), node_id=nid, spot_name=en, category=ec, loot_items=spot_loot(rid, ec), min_level=lv, yield_min=1, yield_max=2, difficulty=1))
                if ec not in D.SPOT_LOOT[rid]: errors.append(f'들머리 채집터 갈래가 SPOT_LOOT에 없음: {rid} {ec}')
                continue
            for j in range(2):
                cat = cats[(sk + j) % len(cats)]
                srows.append(dict(spot_id=U('spot', rid, str(h), str(i), str(j)), node_id=nid, spot_name=spot_name(rid, cat, sk + j), category=cat, loot_items=spot_loot(rid, cat),
                                  min_level=nlv, yield_min=1, yield_max=2 if hl <= 3 else 3, difficulty=10 + hl))
            sk += 2
ND = "(" + J({str(k): v for k, v in NODE_DESC.items()}) + " ->> x.hierarchy_level::text)"
bulk('world_exploration_nodes', sorted(nrows, key=lambda x: x['hierarchy_level']), [('node_id', 'text'), ('region_id', 'text'), ('parent_node_id', 'text'), ('hierarchy_level', 'smallint'),
     ('node_name', 'text'), ('description', 'text'), ('min_level', 'int'), ('sort_order', 'int')], 'node_id', ['node_name', 'parent_node_id', 'min_level'],
     {'node_id': 'md5(x.node_id)::uuid', 'parent_node_id': 'md5(x.parent_node_id)::uuid', 'description': ND})
bulk('world_gathering_spots', srows, [('spot_id', 'text'), ('node_id', 'text'), ('spot_name', 'text'), ('category', 'text'), ('loot_items', 'jsonb'), ('min_level', 'int'),
     ('yield_min', 'int'), ('yield_max', 'int'), ('difficulty', 'int'), ('active', 'boolean')], 'spot_id', ['spot_name', 'loot_items', 'min_level'],
     {'spot_id': 'md5(x.spot_id)::uuid', 'node_id': 'md5(x.node_id)::uuid', 'loot_items': TA('loot_items'), 'active': 'true'})

mons = [m for v in D.MONSTERS.values() for m in v]
fresh('monsters', [m[1] for m in mons], '요괴')
fresh('monster_ids', [m[0] for m in mons], '요괴 id')
rows = []
for rid, ms in D.MONSTERS.items():
    L = RID[rid]['lv']
    for mid, nm, ty, role, kind, mech, desc, drops in ms:
        if role == 'common': lo, hi, hp, atk, wt, dr = L, min(CAP, L + 3), 70 + 14 * L, round(8 + 1.1 * L), 14, 2
        elif role == 'main': lo, hi, hp, atk, wt, dr = min(CAP, L + 1), min(CAP + 1, L + 4), 150 * L, round(7.5 * L), 15, 5
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
    r = RID[rid]
    for d, (gn, gd) in enumerate(gs, 1):
        rows.append(dict(ground_id=rid + '_' + str(d), region_id=rid, ground_name=gn, description=gd, depth=d, danger=min(10, r['danger'] + d - 1), min_level=min(CAP, r['lv'] + (d - 1)), unlock_progress=[0, 30, 70][d - 1]))
bulk('world_expedition_grounds', rows, [('ground_id', 'text'), ('region_id', 'text'), ('ground_name', 'text'), ('description', 'text'), ('depth', 'int'), ('danger', 'int'), ('min_level', 'int'),
     ('unlock_progress', 'int')], 'ground_id', ['ground_name', 'description', 'min_level'])
fresh('fish_grounds', [f[2] for f in D.FISH], '낚시터')
bulk('world_fish_grounds', [dict(region_id=rid, habitat=h, ground_name=gn, description=gd) for rid, h, gn, gd in D.FISH],
     [('region_id', 'text'), ('habitat', 'text'), ('ground_name', 'text'), ('description', 'text')], 'region_id, habitat', ['ground_name', 'description'])
fresh('sites', [s[1] for v in D.SITES.values() for s in v], '조사 지점')
rows = []
for rid, sites in D.SITES.items():
    for k, (ty, nm, loot, rare) in enumerate(sites):
        lc, lcs = SITE_CAT[ty]
        rows.append(dict(site_id=rid + '_s' + str(k + 1), region_id=rid, site_name=nm, site_type=ty, bonus_item=loot[0], loot_table=loot,
                         rare_bonus={'items': rare, 'chance': 0.2, 'remote_bonus': True, 'distance_from_headquarters': 700}, description=SITE_DESC[ty], bonus_chance=18, loot_category=lc, loot_categories=lcs))
bulk('world_region_sites', rows, [('site_id', 'text'), ('region_id', 'text'), ('site_name', 'text'), ('site_type', 'text'), ('bonus_item', 'text'), ('loot_table', 'jsonb'), ('rare_bonus', 'jsonb'),
     ('description', 'text'), ('bonus_chance', 'int'), ('loot_category', 'text'), ('loot_categories', 'jsonb'), ('active', 'boolean')], 'site_id', ['site_name', 'loot_table', 'rare_bonus', 'active'],
     {'loot_categories': TA('loot_categories'), 'active': 'true'})

statuses = [dict(status_key=k, status_name=n, polarity=p, duration_minutes=m, effects=e, icon=ic, description=d) for k, n, p, m, e, ic, d in D.STATUSES]
fresh('statuses', [s['status_key'] for s in statuses], '상태 키')
fresh('status_names', [s['status_name'] for s in statuses], '상태 이름')
bulk('world_status_catalog', statuses, [('status_key', 'text'), ('status_name', 'text'), ('polarity', 'text'), ('description', 'text'), ('duration_minutes', 'int'), ('effects', 'jsonb'), ('icon', 'text')],
     'status_key', ['status_name', 'polarity', 'description', 'duration_minutes', 'effects', 'icon'])

items, recipes, hq, names_new, priced = [], [], [], [], []
for iid, nm, cat, tier, st, pr, tr, ml, desc in D.ITEMS:
    items.append(item(iid, nm, cat, tier, desc, st, pr, tr, ml, fx=D.CONSUMABLE_FX.get(iid)))
    names_new.append(nm)
    if iid in D.CONSUMABLE_FX: hq.append(iid)
for fid, nm, hab, rar, ph, wk, lv, smin, smax, desc, pr in D.FISH_SPECIES:
    items.append(item(fid, nm, 'material', {'common': 1, 'uncommon': 2, 'rare': 3}[rar], desc, 50, pr, True, 1))
    names_new.append(nm)
    recipes.append(recipe('fillet_' + fid, nm + ' 손질하기', 'fish_fillet', D.FILLET_QTY[rar], {fid: 1 if rar != 'common' else 2}, 'cooking', 1, nm + '을(를) 손질해 생선살을 얻는다.', 1))
for fid, nm, hab, ph, wk, grd, smin, smax, desc, baits in D.NAMED_FISH:
    items.append(item(fid, nm, 'material', 5, '이름을 지킨 물고기, 명어(名魚). ' + desc, 50, D.NAMED_PRICE, D.NAMED_TRADEABLE, 1))
    names_new.append(nm)
for goods in (D.FISH_GOODS, D.NAMED_GOODS):
    for iid, nm, cat, tier, st, tr, pr, fx, desc, field, mats, qty, lv in goods:
        items.append(item(iid, nm, cat, tier, desc, st, pr, tr, lv, fx=fx))
        names_new.append(nm)
        hq.append(iid)
        recipes.append(recipe('r_' + iid, nm + ' 만들기', iid, qty, mats, field, lv, nm + '을(를) 만든다.', 4 if goods is D.NAMED_GOODS else 3))
RUB = json.loads(subprocess.check_output(['node', '--input-type=module', '-e', "const F = await import('./assets/js/housing/furniture.js'); const o = {}; for (const [k, f] of Object.entries(F.WALL)) if (k.startsWith('rubbing_hw_')) o[k] = { name: f.name, grade: f.grade, kind: f.kind, w: f.w, h: f.h, cat: f.cat }; console.log(JSON.stringify(o));"], cwd=os.path.join(HERE, '..', '..', '..')))
for nf in D.NAMED_FISH:
    rk = 'rubbing_' + nf[0]
    if rk not in RUB:
        errors.append(f'탁본 그림 없음: {rk}')
        continue
    f = RUB[rk]
    tr = {'hk': rk, 'kind': 'wall', 'wall': f['kind'], 'ww': f['w'], 'wh': f['h'], 'cat': f['cat'], 'grade': f['grade']}
    items.append(item('hf_' + rk, f['name'], 'furniture', f['grade'], f"별채 가구 · {f['cat']}. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.", 1, {4: 800, 5: 2400}[f['grade']], False, D.NAMED_LEVEL, traits=tr))
    names_new.append(f['name'])
    recipes.append(recipe('r_hf_' + rk, f['name'] + ' 만들기', 'hf_' + rk, 1, dict({nf[0]: 1}, **D.RUBBING_MATS), 'sealing', D.NAMED_LEVEL, f"별채에 놓을 {f['name']}을(를) 만든다.", f['grade']))
for iid, mats, field, qty in D.CONSUMABLE_RECIPES:
    nm = next(x[1] for x in D.ITEMS if x[0] == iid)
    recipes.append(recipe('r_' + iid, nm + ' 만들기', iid, qty, mats, field, D.TOOL_LV, nm + '을(를) 만든다.', 3))
for iid, mats, field, qty, lv in D.QUEST_RECIPES:
    nm = next(x[1] for x in D.ITEMS if x[0] == iid)
    recipes.append(recipe('r_' + iid, nm + ' 만들기', iid, qty, mats, field, lv, nm + '을(를) 만든다.', 2))
    priced.append(iid)

tool_lines = []
for iid, nm, line, traits, desc, field, mats in D.TOOLS:
    items.append(item(iid, nm, 'tool', 9, desc, 1, 0, True, D.TOOL_LV, traits=traits))
    names_new.append(nm)
    recipes.append(recipe('r_' + iid, nm + ' 만들기', iid, 1, mats, field, D.TOOL_LV, desc, 8, GEAR_PLACE_NAME))
    tool_lines.append(dict(item_id=iid, line=line))
    hq.append(iid)
    priced.append(iid)

drows = []
for iid, nm, slot, stat, traits, desc, field, mats in D.GEAR:
    req = round(5 + (0.25 if slot in ACC else 0.35) * 3 * (D.LV9 - 1))
    items.append(item(iid, nm, slot, 9, desc, 1, 0, True, D.LV9, traits=traits, req=({} if slot == 'weapon' else {stat: req})))
    names_new.append(nm)
    recipes.append(recipe('r_' + iid, nm + ' 만들기', iid, 1, mats, field, D.LV9, nm + '을(를) 만든다.', 9, GEAR_PLACE_NAME))
    hq.append(iid)
    priced.append(iid)
for iid, mks in D.GEAR_DROP.items():
    for mk in mks:
        drows.append(dict(item_id=iid, mechanic_key=mk, chance_normal=0 if mk == 'boss' else 0.001, chance_elite=0.006 if mk == 'boss' else 0.004))

fresh('items', names_new, '물품')
fresh('item_ids', [i['item_id'] for i in items], '물품 id')
fresh('recipes', [r['recipe_id'] for r in recipes], '제작법 id')
known = set(REF['item_ids']) | {i['item_id'] for i in items}
status_known = set(REF['statuses']) | {s['status_key'] for s in statuses}
for r in recipes:
    for k in r['ingredients']:
        if k not in known: errors.append(f"제작법 {r['recipe_id']} 재료 없음: {k}")
for i in items:
    for b in (i['use_fx'] or {}).get('buffs', []):
        if b not in status_known: errors.append(f"물품 {i['item_id']} 기운 없음: {b}")
for rid, ms in D.MONSTERS.items():
    for m in ms:
        for k in m[7]:
            if k not in known: errors.append(f'요괴 {m[0]} 떨굼 없음: {k}')
for rid, cs in D.SPOT_LOOT.items():
    for c, ls in cs.items():
        for k in ls:
            if k not in known: errors.append(f'채집터 {rid}/{c} 물품 없음: {k}')
for rid, sites in D.SITES.items():
    for _, _, loot, rare in sites:
        for k in loot + rare:
            if k not in known: errors.append(f'조사 지점 {rid} 물품 없음: {k}')
for sid, lst in D.SHOPS.items():
    for k, _, _ in lst:
        if k not in known: errors.append(f'상점 {sid} 물품 없음: {k}')
mat_ids = {i[0] for i in D.ITEMS if i[2] == 'material'}
src_ids = {k for cs in D.SPOT_LOOT.values() for ls in cs.values() for k in ls} | {k for ms in D.MONSTERS.values() for m in ms for k in m[7]} | {i[0] for i in D.QUEST_RECIPES}
for m in mat_ids - src_ids:
    errors.append('얻는 곳 없는 재료: ' + m)
used = {k for r in recipes for k in r['ingredients']}
for m in mat_ids - used - {i[0] for i in D.QUEST_RECIPES}:
    warns.append('제작법에 안 쓰이는 재료: ' + m)

bulk('world_item_catalog', items, ICOLS, 'item_id', IUPD)
w(f"""insert into public.world_tool_lines(item_id, line) select x.item_id, x.line from jsonb_to_recordset({J(tool_lines)}) as x(item_id text, line text)
 where not exists (select 1 from public.world_tool_lines t where t.item_id = x.item_id);""")
bulk('world_crafting_recipes', recipes, RCOLS, 'recipe_id', RUPD)
bulk('world_gear_drops', drows, [('item_id', 'text'), ('mechanic_key', 'text'), ('level_min', 'int'), ('level_max', 'int'), ('chance_normal', 'numeric'), ('chance_elite', 'numeric'),
     ('chance_guardian', 'numeric')], 'item_id, mechanic_key', [], {'level_min': str(D.GEAR_LEVELS[0]), 'level_max': str(D.GEAR_LEVELS[1]), 'chance_guardian': '0.02'})
w(f"""update public.world_item_catalog i set reference_price = greatest(
    ceil(1.2 * (select min(t.v) from (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) v from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id group by cr.recipe_id) t)),
    coalesce(ceil(1.15 * (select max(f.reference_price) from public.world_item_catalog f where f.tier = 8 and f.category = i.category and f.base_item_id is null
      and f.item_id not like 'raid%' and f.equipment_traits::text !~ '"mz_' and coalesce((f.equipment_traits ->> 'life_slot'), '') = coalesce((i.equipment_traits ->> 'life_slot'), ''))), 0))
 where i.item_id in (select jsonb_array_elements_text({J([g[0] for g in D.GEAR] + [t[0] for t in D.TOOLS])}));""")
w(f"""update public.world_item_catalog i set reference_price = greatest(i.reference_price,
    ceil(1.1 * (select min(t.v) from (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) v from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id group by cr.recipe_id) t)))
 where i.item_id in (select jsonb_array_elements_text({J([x[0] for g in (D.FISH_GOODS, D.NAMED_GOODS) for x in g] + [c[0] for c in D.CONSUMABLE_RECIPES] + [q[0] for q in D.QUEST_RECIPES])}))
   and exists (select 1 from public.world_crafting_recipes cr where cr.output_item = i.item_id);""")
w(f"""insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
  rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade, use_fx)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable,
  i.required_stats, i.required_job, i.required_faction, i.minimum_level, i.rarity, i.acquisition_difficulty, i.drop_rate_modifier,
  case when i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then public.world_item_hq_traits(i.equipment_traits) else i.equipment_traits end,
  i.crafting_specialization, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.item_id, 1, null
  from public.world_item_catalog i
 where i.item_id in (select jsonb_array_elements_text({J(hq)}))
on conflict (item_id) do nothing;""")
w("""do $c$ begin
  if exists (select 1 from public.world_item_catalog where tier > 8 and item_id like '%_9%' and tier <> 9) then raise exception '9단계 장비 단계가 어긋남'; end if;
end $c$;""")

w(f"""insert into public.world_fish_species(fish_id, fish_name, habitat, rarity, min_level, phase, weather, size_min, size_max, description, sort, active, grounds, bait_for, named)
select x.fish_id, x.fish_name, x.habitat, x.rarity, x.min_level, x.phase, x.weather, x.size_min, x.size_max, x.description,
       (select coalesce(max(sort), 0) from public.world_fish_species) + x.n, true, case when x.ground is null then null else array[x.ground] end, '{{}}'::text[], x.named
  from jsonb_to_recordset({J([dict(fish_id=f[0], fish_name=f[1], habitat=f[2], rarity=f[3], phase=f[4], weather=f[5], min_level=f[6], size_min=f[7], size_max=f[8], description=f[9], ground=None, named=False, n=k + 1) for k, f in enumerate(D.FISH_SPECIES)]
    + [dict(fish_id=f[0], fish_name=f[1], habitat=f[2], rarity='legendary', phase=f[3], weather=f[4], min_level=D.NAMED_LEVEL, size_min=f[6], size_max=f[7], description=f[8], ground=f[5], named=True, n=len(D.FISH_SPECIES) + k + 1) for k, f in enumerate(D.NAMED_FISH)])})
    as x(fish_id text, fish_name text, habitat text, rarity text, min_level int, phase text, weather text, size_min numeric, size_max numeric, description text, ground text, named boolean, n int)
on conflict (fish_id) do update set fish_name = excluded.fish_name, habitat = excluded.habitat, rarity = excluded.rarity, min_level = excluded.min_level, phase = excluded.phase,
  weather = excluded.weather, size_min = excluded.size_min, size_max = excluded.size_max, description = excluded.description, grounds = excluded.grounds, named = excluded.named;""")
fresh('fish', [f[1] for f in D.FISH_SPECIES] + [f[1] for f in D.NAMED_FISH], '어종')
grounds_hab = {(rid, h) for rid, h, _, _ in D.FISH}
for f in D.NAMED_FISH:
    if (f[5], f[2]) not in grounds_hab: errors.append(f'명어 {f[0]} 낚시터 없음: {f[5]} {f[2]}')
for f in D.FISH_SPECIES:
    if not any(h == f[2] for _, h in grounds_hab): warns.append(f'어종 {f[0]}: 건넛누리 낚시터에 그 물 갈래 없음(본토에서도 나옴)')
baits = {}
for fid, *_rest, bl in D.NAMED_FISH:
    for b in bl: baits.setdefault(b, []).append(fid)
w(f"""update public.world_fish_species s set bait_for = array(select distinct unnest(s.bait_for || array(select jsonb_array_elements_text({J(baits)} -> s.fish_id))) order by 1)
 where s.fish_id in (select jsonb_object_keys({J(baits)}));""")
w("""do $c$ begin
  if exists (select 1 from public.world_fish_species n where n.named and (select count(*) from public.world_fish_species b where n.fish_id = any (b.bait_for) and b.rarity in ('common', 'uncommon', 'rare')) < 3) then
    raise exception '명어마다 미끼가 셋 이상이어야 합니다';
  end if;
end $c$;""")
w(f"""update public.world_fish_species s set min_level = greatest(s.min_level, 50) where s.fish_id in (select jsonb_array_elements_text({J([f[0] for f in D.FISH_SPECIES])}));""")

for rid, lst in D.SHOPS.items():
    sid = RID[rid]['shop'][0]
    rows = [dict(item_id=i, price=p, cap=c) for i, p, c in lst]
    w(f"""insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select '{sid}', x.item_id, case when x.price > 0 then x.price else (select greatest(1, round(i.reference_price * 1.3)) from public.world_item_catalog i where i.item_id = x.item_id) end, 1, 1, x.cap
  from jsonb_to_recordset({J(rows)}) as x(item_id text, price bigint, cap int)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price, daily_cap = excluded.daily_cap;""")

fresh('titles', [t[1] for t in D.TITLES], '칭호')
fresh('title_keys', [t[0] for t in D.TITLES], '칭호 키')
w(f"""insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, hidden, rule, sort, category, grade)
select x.title_key, x.title_name, x.description, case when x.hidden then '숨겨진 조건' else x.cond end, x.bonus, x.hidden, x.rule, 3300 + x.n, '{D.TITLE_CAT}', x.grade
  from jsonb_to_recordset({J([dict(title_key=k, title_name=n, grade=g, bonus=b, rule=r, cond=c, hidden=h, description=c + '.', n=i) for i, (k, n, g, b, r, c, h) in enumerate(D.TITLES)])})
    as x(title_key text, title_name text, grade int, bonus jsonb, rule jsonb, cond text, hidden boolean, description text, n int)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus,
  hidden = excluded.hidden, rule = excluded.rule, category = excluded.category, grade = excluded.grade;""")
fresh('cosmetics', [c[3] for c in D.COSMETICS], '꾸미기')
w(f"""insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, sort)
select x.k, x.kind, x.tier, x.name, x.cond, '{D.TITLE_CAT}', x.rule, false, x.sort
  from jsonb_to_recordset({J([dict(k=k, kind=kd, tier=t, name=n, cond=c, rule=r, sort=s) for k, kd, t, n, c, r, s in D.COSMETICS])}) as x(k text, kind text, tier text, name text, cond text, rule jsonb, sort int)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, tier = excluded.tier, category = excluded.category;""")

ids = ', '.join(f"'{r['id']}'" for r in R)
w(f"""insert into public.world_gathering_discoveries(owner_id, spot_id)
select c.owner_id, gs.spot_id from public.world_characters c
  cross join public.world_gathering_spots gs join public.world_exploration_nodes n on n.node_id = gs.node_id and n.hierarchy_level = 1 and n.region_id in ({ids})
on conflict do nothing;""")

QN = Q.NPCS
fresh('npcs', [nm for nm, _ in QN.values()], '인물')
bulk('world_quest_npcs', [dict(npc_key=k, npc_name=nm, bio=bio) for k, (nm, bio) in QN.items()], [('npc_key', 'text'), ('npc_name', 'text'), ('bio', 'text')], 'npc_key', ['npc_name', 'bio'])
xp_need = lambda L: 100 * L + 12 * L * L
qrows, qsrows = [], []
total_xp = 0
for i, q in enumerate(quests):
    L = q['L']
    tot = round(Q.XP * xp_need(L))
    total_xp += tot
    mine_s = [s for s in qsteps if s['quest'] == q['id']]
    task_steps = [s['step'] for s in mine_s if s['need'].get('tasks') or s['need'].get('give')]
    per = tot // max(1, len(task_steps))
    qrows.append(dict(quest_id=q['id'], cat=Q.CAT, title=q['title'], summary=q['summary'], region_id=q['region'], min_level=L, after=q['after'], sort=1600 + i, epilogue=[]))
    for s in mine_s:
        rw = {'xp': per} if s['step'] in task_steps and per else {}
        if s['step'] == len(mine_s):
            rw['gil'] = 20 + 10 * L
            rw['items'] = q['items']
        qsrows.append(dict(quest_id=q['id'], step=s['step'], title=s['title'], goal=s['goal'], need=s['need'], lines=s['lines'], reward=rw))
for q in quests:
    for k in q['items']:
        if k not in known: errors.append(f"퀘스트 {q['id']} 보상 물품 없음: {k}")
for s in qsteps:
    for t in s['need'].get('tasks', []):
        for k in t.get('items', []):
            if k not in known: errors.append(f"{s['quest']}:{s['step']} 할 일 물품 없음: {k}")
        for rg in t.get('r', []):
            if rg not in RID and rg not in set(REF['region_ids']): errors.append(f"{s['quest']}:{s['step']} 지역 없음: {rg}")
        for m in t.get('m', []):
            if m not in set(REF['monster_ids']) and m not in {x[0] for x in mons}: errors.append(f"{s['quest']}:{s['step']} 요괴 없음: {m}")
    for k in s['need'].get('give', {}):
        if k not in known: errors.append(f"{s['quest']}:{s['step']} 넘길 물품 없음: {k}")
fresh('quest_ids', [q['id'] for q in quests], '퀘스트 id')
bulk('world_quests', qrows, [('quest_id', 'text'), ('kind', 'text'), ('cat', 'text'), ('title', 'text'), ('summary', 'text'), ('region_id', 'text'), ('min_level', 'int'), ('after', 'jsonb'),
     ('sort', 'int'), ('epilogue', 'jsonb'), ('active', 'boolean')], 'quest_id', ['cat', 'title', 'summary', 'region_id', 'min_level', 'after', 'sort', 'epilogue', 'active'],
     {'kind': "'side'", 'after': TA('after'), 'active': 'true'})
bulk('world_quest_steps', qsrows, [('quest_id', 'text'), ('step', 'int'), ('title', 'text'), ('goal', 'text'), ('need', 'jsonb'), ('lines', 'jsonb'), ('reward', 'jsonb')],
     'quest_id, step', ['title', 'goal', 'need', 'lines', 'reward'])

if os.path.exists(os.path.join(HERE, 'data_side.py')):
    import data_side as SQ
    w(SQ.emit(fresh, errors, warns, bulk, J, TA, known, RID, REF, xp_need))

w(f"""select public.world_quest_label_refresh();
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '{DB_VERSION}', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;""")

need_sum = sum(xp_need(L) for L in range(50, 55))
sys.stderr.write(f'본편 경험치 합 {total_xp:,} / 50→55 필요 {need_sum:,} ({total_xp * 100 // need_sum}%)\n')
sys.stderr.write('지역 열림: ' + ', '.join(f'{k}={v}' for k, v in REGION_OPEN.items()) + '\n')
if warns:
    sys.stderr.write('경고:\n' + '\n'.join(warns) + '\n')
if errors:
    sys.stderr.write('\n'.join(errors) + '\n')
    sys.exit(1)
print('\n'.join(out))
sys.stderr.write(f"지역 {len(R)} · 답사 지점 {len(nrows)} · 채집터 {len(srows)} · 요괴 {len(mons)} · 원정지 {sum(len(v) for v in D.GROUNDS.values())} · 낚시터 {len(D.FISH)} · "
                 f"조사 지점 {sum(len(v) for v in D.SITES.values())} · 물품 {len(items)}(+우수 {len(hq)}) · 제작법 {len(recipes)} · 어종 {len(D.FISH_SPECIES) + len(D.NAMED_FISH)} · "
                 f"칭호 {len(D.TITLES)} · 퀘스트 {len(qrows)} · 장면 {len(qsrows)} · 새 인물 {len(QN)}\n")
