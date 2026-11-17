import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, HERE)
import data_world as D

J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + '$J$::jsonb'
U = lambda *k: 'dd30/' + '/'.join(k)
TA = lambda c: f"array(select jsonb_array_elements_text(x.{c}))"
out = []
w = out.append
part = lambda f: w(open(os.path.join(HERE, f)).read())
CAP = D.CAP
REF = json.load(open(os.path.join(HERE, 'ref', 'existing_names.json')))
PRICE = REF['item_price']
errors = []
warns = []
DB_VERSION = '20261126000000'


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


def node_dump(js):
    return json.loads(subprocess.check_output(['node', '--input-type=module', '-e', js], cwd=ROOT))


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
ICOLS = [('item_id', 'text'), ('item_name', 'text'), ('category', 'text'), ('tier', 'int'), ('description', 'text'), ('stackable', 'boolean'), ('required_stats', 'jsonb'), ('minimum_level', 'int'),
         ('rarity', 'text'), ('acquisition_difficulty', 'int'), ('drop_rate_modifier', 'numeric'), ('equipment_traits', 'jsonb'), ('tradeable', 'boolean'), ('reference_price', 'bigint'), ('stack_size', 'int'),
         ('use_fx', 'jsonb')]
IUPD = ['item_name', 'category', 'tier', 'description', 'required_stats', 'equipment_traits', 'minimum_level', 'stack_size', 'tradeable', 'reference_price', 'use_fx']
RCOLS = [('recipe_id', 'text'), ('recipe_name', 'text'), ('output_item', 'text'), ('output_qty', 'int'), ('ingredients', 'jsonb'), ('required_tool_tier', 'int'),
         ('required_location', 'text'), ('description', 'text'), ('minimum_level', 'int'), ('recipe_difficulty', 'int'), ('quality_bonus', 'int'), ('required_skill', 'text'),
         ('required_skill_rank', 'int'), ('craft_field', 'text')]
RUPD = ['recipe_name', 'output_item', 'output_qty', 'ingredients', 'craft_field', 'required_location', 'minimum_level', 'description', 'recipe_difficulty', 'required_skill', 'required_skill_rank']
RARITY = {1: 'common', 2: 'uncommon', 3: 'rare', 4: 'epic'}
FIELD_LINE = {'sealing': 'wardcraft'}
FERRY_NAME = next(r['name'] for r in D.REGIONS if r['id'] == D.FERRY)
ACC = {'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool'}


def terr(r):
    return r.get('terr') or D.TERR


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


w("lock table public.world_characters in access exclusive mode;\n")
part('a_level.sql')

terrs = {}
for r in D.REGIONS:
    terrs.setdefault(terr(r)[0], terr(r)[1])
rules = {}
for tid, tname in terrs.items():
    rule = {'name': tname, 'open_quest': D.OPEN_QUEST[tid], 'no_shadow': True, 'rare': 'lamp_wick_core'}
    if tid == D.TERR[0]:
        rule.update(regions=D.REGION_OPEN, night=D.NIGHT_BACK, fx=D.DOMAIN_FX)
    else:
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
part('b_rules.sql')
part('c_ride.sql')
lamp = {'rank': D.MZ_RULES['rank'], 'pct': D.MZ_RULES['l_pct'], 'territory': [D.TERR[0]], 'items': {k: f'mz_{k}_l' for k in ('herb', 'wood', 'stone')}}
w(f"""do $d$
declare j jsonb := public.world_meisho_rules() || jsonb_build_object('lamp', {J(lamp)});
begin
  execute format('create or replace function public.world_meisho_rules() returns jsonb language sql immutable as %L', format('select %L::jsonb', j::text));
end $d$;
grant execute on function public.world_meisho_rules() to public;""")
part('d_meisho.sql')
part('e_party.sql')
part('f_titles.sql')
part('g_lines.sql')
part('h_replay.sql')
part('i_borrow.sql')
part('k_quest_fix.sql')

R = D.REGIONS
fresh('regions', [r['name'] for r in R], '지역')
fresh('region_ids', [r['id'] for r in R], '지역 id')
rows = []
for r in R:
    rest = r.get('rest') or ('임시 야영지', 'field_camp', 2, 1)
    shop = r.get('shop') or (None, None)
    t = terr(r)
    rows.append(dict(region_id=r['id'], territory_id=t[0], territory_name=t[1], region_name=r['name'], region_type=r['type'], danger_level=r['danger'], min_level=r.get('entry', r['lv']),
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
mine = {r['id'] for r in R}
for r in R:
    for n in r['nb']:
        if n not in mine:
            w(f"update public.world_map_regions set travel_from = array_append(travel_from, '{r['id']}') where region_id = '{n}' and not ('{r['id']}' = any (travel_from));")
for tid, wts in D.CLIMATES.items():
    w(f"insert into public.world_weather_climate(territory_id, weights) values ('{tid}', {J(wts)}) on conflict (territory_id) do update set weights = excluded.weights;")

rows = []
for rid, (bn, fs, clue, ev, hz, vis) in D.PROFILES.items():
    loot = [i for c in D.SPOT_LOOT[rid].values() for i in c]
    sig = list(dict.fromkeys(reversed(loot)))[:3]
    rows.append(dict(region_id=rid, biome_key=next(r['theme'] for r in R if r['id'] == rid), biome_name=bn, faction_style=fs, signature_clue=clue, signature_event=ev,
                     signature_items=sig, survival_hazard=hz, visual_identity=vis, signature_resources=sorted(set(loot)), investigation_reward='흰 밤에 멈춘 이름의 기록'))
bulk('world_region_profiles', rows, [('region_id', 'text'), ('biome_key', 'text'), ('biome_name', 'text'), ('faction_style', 'text'), ('signature_clue', 'text'), ('signature_event', 'text'),
     ('signature_items', 'jsonb'), ('survival_hazard', 'text'), ('visual_identity', 'text'), ('signature_resources', 'jsonb'), ('investigation_reward', 'text')], 'region_id',
     ['biome_name', 'faction_style', 'signature_clue', 'signature_event', 'signature_items', 'survival_hazard', 'visual_identity', 'signature_resources'],
     {'signature_items': TA('signature_items'), 'signature_resources': TA('signature_resources')})
bulk('world_region_lore', [dict(region_id=rid, lines=[{'s': None, 't': t} for t in ls]) for rid, ls in D.LORE.items()], [('region_id', 'text'), ('lines', 'jsonb')], 'region_id', ['lines'])

spot_names = set(REF['spots'])
fresh('nodes', [n for v in D.NODES.values() for row in v for n in row] + [n for v in D.EXTRA_NODES.values() for n, _ in v], '답사 지점')


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
    ent = r.get('entry', lv)
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
            nlv = ent if hl == 1 else min(CAP, lv + max(0, hl - 2) * 2)
            nrows.append(dict(node_id=nid, region_id=rid, parent_node_id=parents.get((h, i)), hierarchy_level=hl, node_name=nm, min_level=nlv, sort_order=i))
            if hl == 1:
                en, ec = D.ENTRY_SPOT[rid]
                if en in spot_names: errors.append('채집터 이름 겹침: ' + en)
                spot_names.add(en)
                srows.append(dict(spot_id=U('spot', rid, 'entry'), node_id=nid, spot_name=en, category=ec, r=rid, min_level=ent, yield_min=1, yield_max=2, difficulty=1))
                continue
            for j in range(2):
                cat = cats[(sk + j) % len(cats)]
                srows.append(dict(spot_id=U('spot', rid, str(h), str(i), str(j)), node_id=nid, spot_name=spot_name(rid, cat, sk + j), category=cat, r=rid,
                                  min_level=nlv, yield_min=1, yield_max=2 if hl <= 3 else 3, difficulty=10 + hl))
            sk += 2
ND = "(" + J({str(k): v for k, v in NODE_DESC.items()}) + " ->> x.hierarchy_level::text)"
bulk('world_exploration_nodes', sorted(nrows, key=lambda x: x['hierarchy_level']), [('node_id', 'text'), ('region_id', 'text'), ('parent_node_id', 'text'), ('hierarchy_level', 'smallint'),
     ('node_name', 'text'), ('description', 'text'), ('min_level', 'int'), ('sort_order', 'int')], 'node_id', ['node_name', 'parent_node_id', 'min_level'],
     {'node_id': 'md5(x.node_id)::uuid', 'parent_node_id': 'md5(x.parent_node_id)::uuid', 'description': ND})
xrows = [dict(node_id=U('node', rid, 'extra', str(k)), region_id=rid, hierarchy_level=hl, node_name=nm, sort_order=90 + k)
         for rid, v in D.EXTRA_NODES.items() for k, (nm, hl) in enumerate(v)]
if xrows:
    w(f"""insert into public.world_exploration_nodes(node_id, region_id, parent_node_id, hierarchy_level, node_name, description, min_level, sort_order)
select md5(x.node_id)::uuid, x.region_id, p.node_id, x.hierarchy_level, x.node_name, {ND}, p.min_level, x.sort_order
  from jsonb_to_recordset({J(xrows)}) as x(node_id text, region_id text, hierarchy_level smallint, node_name text, sort_order int)
  join lateral (select n.node_id, n.min_level from public.world_exploration_nodes n where n.region_id = x.region_id and n.hierarchy_level = x.hierarchy_level - 1 order by n.sort_order limit 1) p on true
on conflict (node_id) do update set node_name = excluded.node_name;""")
LOOT = "array(select jsonb_array_elements_text(" + J(D.SPOT_LOOT) + " -> x.r -> x.category))"
bulk('world_gathering_spots', srows, [('spot_id', 'text'), ('node_id', 'text'), ('spot_name', 'text'), ('category', 'text'), ('loot_items', 'jsonb'), ('min_level', 'int'),
     ('yield_min', 'int'), ('yield_max', 'int'), ('difficulty', 'int'), ('active', 'boolean'), ('r', 'text')], 'spot_id', ['spot_name', 'loot_items', 'min_level'],
     {'spot_id': 'md5(x.spot_id)::uuid', 'node_id': 'md5(x.node_id)::uuid', 'loot_items': LOOT, 'active': 'true'})

mons = [m for v in D.MONSTERS.values() for m in v]
fresh('monsters', [m[1] for m in mons], '요괴')
fresh('monster_ids', [m[0] for m in mons], '요괴 id')
rows = []
for rid, ms in D.MONSTERS.items():
    L = next(r['lv'] for r in R if r['id'] == rid)
    E = next(r.get('entry', r['lv']) for r in R if r['id'] == rid)
    for mid, nm, ty, role, kind, mech, desc, drops in ms:
        if role == 'common': lo, hi, hp, atk, wt, dr = E, min(CAP, L + 3), 70 + 14 * L, round(8 + 1.1 * L), 14, 2
        elif role == 'main': lo, hi, hp, atk, wt, dr = min(CAP, L + 2), min(CAP + 1, L + 6), 150 * L, round(7.5 * L), 15, 5
        else: lo, hi, hp, atk, wt, dr = E, min(CAP, L + 2), round((70 + 14 * L) * 1.5), round((8 + 1.1 * L) * 1.4), 12, 10
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
        rows.append(dict(ground_id=rid + '_' + str(d), region_id=rid, ground_name=gn, description=gd, depth=d, danger=min(10, r['danger'] + d - 1), min_level=min(CAP, r['lv'] + (d - 1) * 2), unlock_progress=[0, 30, 70][d - 1]))
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
                         rare_bonus={'items': rare, 'chance': 0.2, 'remote_bonus': True, 'distance_from_headquarters': 560}, description=SITE_DESC[ty], bonus_chance=18, loot_category=lc, loot_categories=lcs))
bulk('world_region_sites', rows, [('site_id', 'text'), ('region_id', 'text'), ('site_name', 'text'), ('site_type', 'text'), ('bonus_item', 'text'), ('loot_table', 'jsonb'), ('rare_bonus', 'jsonb'),
     ('description', 'text'), ('bonus_chance', 'int'), ('loot_category', 'text'), ('loot_categories', 'jsonb'), ('active', 'boolean')], 'site_id', ['site_name', 'loot_table', 'rare_bonus', 'active'],
     {'loot_categories': TA('loot_categories'), 'active': 'true'})

statuses = [dict(status_key=k, status_name=n, polarity=p, duration_minutes=m, effects=dict(e, party_only=1) if k in D.PARTY_STATUSES else e, icon=ic, description=d)
            for k, n, p, m, e, ic, d in D.STATUSES]
statuses += [dict(status_key=k, status_name=n, polarity='positive', duration_minutes=m, effects=e, icon=ic, description=d) for k, n, m, e, ic, d in D.MZ_STATUSES]
fresh('statuses', [s['status_key'] for s in statuses], '상태 키')
fresh('status_names', [s['status_name'] for s in statuses], '상태 이름')
bulk('world_status_catalog', statuses, [('status_key', 'text'), ('status_name', 'text'), ('polarity', 'text'), ('description', 'text'), ('duration_minutes', 'int'), ('effects', 'jsonb'), ('icon', 'text')],
     'status_key', ['status_name', 'polarity', 'description', 'duration_minutes', 'effects', 'icon'])

items, recipes, hq = [], [], []
names_new = []
for iid, nm, cat, tier, st, pr, tr, ml, desc in D.ITEMS:
    items.append(item(iid, nm, cat, tier, desc, st, pr, tr, ml, fx=D.CONSUMABLE_FX.get(iid)))
    names_new.append(nm)
    if iid in D.CONSUMABLE_FX: hq.append(iid)
for iid, nm, tier, st, pr, desc in D.MZ_MATS:
    items.append(item(iid, nm, 'material', tier, desc, st, pr, True, 1))
    names_new.append(nm)
for fid, nm, hab, rar, ph, wk, lv, smin, smax, desc, pr in D.FISH_SPECIES:
    items.append(item(fid, nm, 'material', {'common': 1, 'uncommon': 2, 'rare': 3}[rar], desc, 40, pr, True, 1))
    names_new.append(nm)
for fid, nm, hab, ph, wk, grd, smin, smax, desc, baits in D.NAMED_FISH:
    items.append(item(fid, nm, 'material', 5, '이름을 지킨 물고기, 명어(名魚). ' + desc, 20, D.NAMED_PRICE, D.NAMED_TRADEABLE, 1))
    names_new.append(nm)
for fid, nm, hab, rar, ph, wk, lv, smin, smax, desc, pr in D.FISH_SPECIES:
    recipes.append(recipe('fillet_' + fid, nm + ' 손질하기', 'fish_fillet', D.FILLET_QTY[rar], {fid: 1 if rar != 'common' else 2}, 'cooking', 1, nm + '을(를) 손질해 생선살을 얻는다.', 1))
for goods in (D.FISH_GOODS, D.NAMED_GOODS):
    for iid, nm, cat, tier, st, tr, pr, fx, desc, field, mats, qty, lv in goods:
        if nm is not None:
            items.append(item(iid, nm, cat, tier, desc, st, pr, tr, lv, fx=fx))
            names_new.append(nm)
            hq.append(iid)
        out_name = nm or next(x[1] for x in D.ITEMS if x[0] == iid)
        recipes.append(recipe('r_' + iid, out_name + ' 만들기', iid, qty, mats, field, lv, out_name + '을(를) 만든다.', 4 if goods is D.NAMED_GOODS else 3))
for iid, mats, field, qty in D.CONSUMABLE_RECIPES:
    nm = next(x[1] for x in D.ITEMS if x[0] == iid)
    recipes.append(recipe('r_' + iid, nm + ' 만들기', iid, qty, mats, field, D.TOOL_LV, nm + '을(를) 만든다.', 4, FERRY_NAME))
for rid, nm, output, qty, mats, field, lv, loc in getattr(D, 'EXTRA_RECIPES', []):
    recipes.append(recipe(rid, nm, output, qty, mats, field, lv, nm + '.', 2, loc))

tool_lines = []
for iid, nm, line, traits, desc, field, mats in D.TOOLS:
    items.append(item(iid, nm, 'tool', 8, desc, 1, 0, iid not in getattr(D, 'UNTRADEABLE_TOOLS', set()), D.TOOL_LV, traits=traits))
    names_new.append(nm)
    recipes.append(recipe('r_' + iid, nm + ' 만들기', iid, 1, mats, field, D.TOOL_LV, desc, 8, FERRY_NAME))
    tool_lines.append(dict(item_id=iid, line=line))
    hq.append(iid)

drows = []
priced = []
for iid, nm, slot, stat, traits, desc, field, mats in D.GEAR:
    req = round(5 + (0.25 if slot in ACC else 0.35) * 3 * (D.LV8 - 1))
    items.append(item(iid, nm, slot, 8, desc, 1, 0, True, D.LV8, traits=traits, req={stat: req}))
    names_new.append(nm)
    recipes.append(recipe('r_' + iid, nm + ' 만들기', iid, 1, mats, field, D.LV8, nm + '을(를) 만든다.', 8, FERRY_NAME))
    hq.append(iid)
    priced.append(iid)
for iid, mks in D.GEAR_DROP.items():
    for mk in mks:
        drows.append(dict(item_id=iid, mechanic_key=mk, chance_normal=0 if mk == 'boss' else 0.001, chance_elite=0.006 if mk == 'boss' else 0.004))
for g in D.MZ_GEAR:
    cat, tier = g['cat'], 8
    stack = 20 if cat == 'consumable' else 1
    req = {g['stat']: round(5 + (0.25 if cat in ACC else 0.35) * 3 * (D.LV8 - 1))} if g.get('stat') else None
    items.append(item(g['id'], g['name'], cat, tier, g['desc'], stack, 0, True, D.LV8, traits=g.get('traits'), req=req, fx=g.get('fx')))
    names_new.append(g['name'])
    recipes.append(recipe('r_' + g['id'], g['name'] + ' 만들기', g['id'], g.get('qty', 1), g['mats'], g['field'], D.LV8, f"명장의 솜씨로 {g['name']}을(를) 만든다.",
                          8 if cat != 'consumable' else 4, FERRY_NAME if cat != 'consumable' else None, FIELD_LINE.get(g['field'], g['field']), g['rank']))
    if g.get('line'): tool_lines.append(dict(item_id=g['id'], line=g['line']))
    if cat != 'consumable' or g.get('hq') or g.get('fx'): hq.append(g['id'])
    priced.append(g['id'])

FUR = node_dump("""
const F = await import('./assets/js/housing/furniture.js');
const o = {};
for (const [k, f] of Object.entries(F.FUR)) o[k] = { t: 'FUR', name: f.name, grade: f.grade, W: f.W, D: f.D, layer: f.layer || 'floor', top: f.top || 0, pet: f.pet || null, petKind: f.petKind || null, cat: f.cat };
for (const [k, f] of Object.entries(F.WALL)) o[k] = { t: 'WALL', name: f.name, grade: f.grade, kind: f.kind, w: f.w, h: f.h, cat: f.cat, frame: f.frame || null };
for (const [k, f] of Object.entries(F.PAPER)) o['paper:' + k] = { t: 'PAPER', name: f.name, grade: f.grade };
for (const [k, f] of Object.entries(F.GROUND)) o['ground:' + k] = { t: 'GROUND', name: f.name, grade: f.grade };
console.log(JSON.stringify(o));
""")
fsrc, shop_fur, fur_ids = [], [], []
for k, spec in D.FURNITURE.items():
    if k not in FUR:
        warns.append('가구 그림 없음(furniture.js에 더해야 함): ' + k)
        continue
    f = FUR[k]
    g = f['grade']
    if f['t'] == 'FUR':
        tr = {'hk': k, 'kind': f['layer'], 'w': f['W'], 'd': f['D'], 'top': f['top'], 'cat': f['cat'], 'grade': g}
        if f['pet']: tr['pet'] = f['pet']
        if f['petKind']: tr['pet_kind'] = f['petKind']
    elif f['t'] in ('PAPER', 'GROUND'):
        pk = k.split(':', 1)[1]
        tr = {'hk': pk, 'kind': 'paper' if f['t'] == 'PAPER' else 'ground', 'cat': '벽지' if f['t'] == 'PAPER' else '바닥재', 'grade': g}
    else:
        tr = {'hk': k, 'kind': 'wall', 'wall': f['kind'], 'ww': f['w'], 'wh': f['h'], 'cat': f['cat'], 'grade': g}
    tradeable = spec['source'] in ('shop', 'drop_normal', 'drop_guardian')
    iid = {'PAPER': 'hp_', 'GROUND': 'hg_'}.get(f['t'], 'hf_') + k.split(':', 1)[-1]
    items.append(dict(item(iid, f['name'], 'furniture', g, f"별채 가구 · {tr['cat']}. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.", 1,
                           {1: 0, 2: 0, 3: 0, 4: 800, 5: 2400}[g], tradeable, 1, traits=tr), stackable=False))
    names_new.append(f['name'])
    if spec['mats']:
        recipes.append(recipe('r_' + iid, f['name'] + ' 만들기', iid, 1, spec['mats'], spec['field'], spec['lv'], f"별채에 놓을 {f['name']}을(를) 만든다.", g))
        fur_ids.append(iid)
    src = spec['source']
    if src == 'shop': shop_fur.append(iid)
    elif src == 'drop_normal': fsrc.append(dict(source='drop_normal', item_id=iid, chance=1))
    elif src == 'drop_guardian':
        fsrc.append(dict(source='drop_guardian', item_id=iid, chance=1))
        fsrc.append(dict(source='expedition', item_id=iid, chance=1))
    elif src.startswith('title:') or src.startswith('boss:'): fsrc.append(dict(source=src, item_id=iid, chance=1))

fresh('items', names_new, '물품')
fresh('item_ids', [i['item_id'] for i in items], '물품 id')
fresh('recipes', [r['recipe_id'] for r in recipes], '제작법 id')
known = set(REF['item_ids']) | {i['item_id'] for i in items}
for r in recipes:
    for k in r['ingredients']:
        if k not in known: errors.append(f"제작법 {r['recipe_id']} 재료 없음: {k}")
for rid, ms in D.MONSTERS.items():
    for m in ms:
        for k in m[7]:
            if k not in known: errors.append(f'요괴 {m[0]} 떨굼 없음: {k}')
for rid, cs in D.SPOT_LOOT.items():
    for c, ls in cs.items():
        for k in ls:
            if k not in known: errors.append(f'채집터 {rid}/{c} 물품 없음: {k}')

bulk('world_item_catalog', items, ICOLS, 'item_id', IUPD)
w(f"""insert into public.world_tool_lines(item_id, line) select x.item_id, x.line from jsonb_to_recordset({J(tool_lines)}) as x(item_id text, line text)
 where not exists (select 1 from public.world_tool_lines t where t.item_id = x.item_id);""")
bulk('world_crafting_recipes', recipes, RCOLS, 'recipe_id', RUPD)
bulk('world_gear_drops', drows, [('item_id', 'text'), ('mechanic_key', 'text'), ('level_min', 'int'), ('level_max', 'int'), ('chance_normal', 'numeric'), ('chance_elite', 'numeric'),
     ('chance_guardian', 'numeric')], 'item_id, mechanic_key', [], {'level_min': str(D.GEAR_LEVELS[0]), 'level_max': str(D.GEAR_LEVELS[1]), 'chance_guardian': '0.02'})
w(f"""update public.world_item_catalog i set reference_price = greatest(
    ceil(1.2 * (select min(t.v) from (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) v from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id group by cr.recipe_id) t)),
    coalesce(ceil(1.15 * (select max(f.reference_price) from public.world_item_catalog f where f.tier = 7 and f.category = i.category and f.base_item_id is null
      and f.item_id not like 'raid%' and coalesce((f.equipment_traits ->> 'life_slot'), '') = coalesce((i.equipment_traits ->> 'life_slot'), ''))), 0))
 where i.item_id in (select jsonb_array_elements_text({J(priced + [t[0] for t in D.TOOLS])})) and i.category <> 'consumable';""")
w(f"""update public.world_item_catalog i set reference_price = greatest(i.reference_price,
    ceil(1.1 * (select min(t.v) from (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) v from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id group by cr.recipe_id) t)))
 where i.item_id in (select jsonb_array_elements_text({J([x[0] for g in (D.FISH_GOODS, D.NAMED_GOODS) for x in g] + [c[0] for c in D.CONSUMABLE_RECIPES] + fur_ids + [g['id'] for g in D.MZ_GEAR if g['cat'] == 'consumable'])}))
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

w(f"""insert into public.world_fish_species(fish_id, fish_name, habitat, rarity, min_level, phase, weather, size_min, size_max, description, sort, active, grounds, bait_for, named)
select x.fish_id, x.fish_name, x.habitat, x.rarity, x.min_level, x.phase, x.weather, x.size_min, x.size_max, x.description,
       (select coalesce(max(sort), 0) from public.world_fish_species) + x.n, true, case when x.ground is null then null else array[x.ground] end, '{{}}'::text[], x.named
  from jsonb_to_recordset({J([dict(fish_id=f[0], fish_name=f[1], habitat=f[2], rarity=f[3], phase=f[4], weather=f[5], min_level=f[6], size_min=f[7], size_max=f[8], description=f[9], ground=None, named=False, n=k + 1) for k, f in enumerate(D.FISH_SPECIES)]
    + [dict(fish_id=f[0], fish_name=f[1], habitat=f[2], rarity='legendary', phase=f[3], weather=f[4], min_level=D.NAMED_LEVEL, size_min=f[6], size_max=f[7], description=f[8], ground=f[5], named=True, n=len(D.FISH_SPECIES) + k + 1) for k, f in enumerate(D.NAMED_FISH)])})
    as x(fish_id text, fish_name text, habitat text, rarity text, min_level int, phase text, weather text, size_min numeric, size_max numeric, description text, ground text, named boolean, n int)
on conflict (fish_id) do update set fish_name = excluded.fish_name, habitat = excluded.habitat, rarity = excluded.rarity, min_level = excluded.min_level, phase = excluded.phase,
  weather = excluded.weather, size_min = excluded.size_min, size_max = excluded.size_max, description = excluded.description, grounds = excluded.grounds, named = excluded.named;""")
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

for region_id, lst in ((D.FERRY, [dict(item_id=i, price=p, cap=c) for i, p, c in D.SHOP] + [dict(item_id=f, price=0, cap=2) for f in shop_fur]),
                       ('lamp_rest', [dict(item_id=i, price=p, cap=c) for i, p, c in D.SHOP_REST])):
    sid = next(r['shop'][0] for r in R if r['id'] == region_id)
    w(f"""insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select '{sid}', x.item_id, case when x.price > 0 then x.price else (select i.reference_price * 3 from public.world_item_catalog i where i.item_id = x.item_id) end, 1, 1, x.cap
  from jsonb_to_recordset({J(lst)}) as x(item_id text, price bigint, cap int)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price, daily_cap = excluded.daily_cap;""")
w(f"""insert into public.world_furniture_sources(source, item_id, chance) select x.source, x.item_id, x.chance from jsonb_to_recordset({J(fsrc)}) as x(source text, item_id text, chance numeric)
 where not exists (select 1 from public.world_furniture_sources s where s.source = x.source and s.item_id = x.item_id);""")

fresh('meisho', [m['name'] for m in D.MEISHO], '명소')
meisho = [dict(m, sort=100 + k) for k, m in enumerate(D.MEISHO)]
w(f"""insert into public.world_meisho(meisho_id, meisho_name, region_id, node_id, kind, phase, weather, weather2, min_level, description, sort)
select x.id, x.name, x.region, n.node_id, x.kind, x.phase, x.weather, x.weather2, n.min_level, x."desc", x.sort
  from jsonb_to_recordset({J(meisho)}) as x(id text, name text, region text, node text, kind text, phase text, weather text, weather2 text, "desc" text, sort int)
  join lateral (select z.node_id, z.min_level from public.world_exploration_nodes z where z.region_id = x.region and z.node_name = x.node order by z.hierarchy_level limit 1) n on true
on conflict (meisho_id) do update set meisho_name = excluded.meisho_name, region_id = excluded.region_id, node_id = excluded.node_id, kind = excluded.kind, phase = excluded.phase,
  weather = excluded.weather, weather2 = excluded.weather2, min_level = excluded.min_level, description = excluded.description, sort = excluded.sort;
do $c$ begin
  if (select count(*) from public.world_meisho where meisho_id in (select jsonb_array_elements_text({J([m['id'] for m in D.MEISHO])}))) <> {len(D.MEISHO)} then raise exception '등도 명소 답사 지점을 찾지 못했습니다'; end if;
end $c$;""")

fresh('titles', [t[1] for t in D.TITLES], '칭호')
fresh('title_keys', [t[0] for t in D.TITLES], '칭호 키')
w(f"""insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, hidden, rule, sort, category, grade)
select x.title_key, x.title_name, x.description, case when x.hidden then '숨겨진 조건' else x.cond end, x.bonus, x.hidden, x.rule, 3100 + x.n, '{D.TITLE_CAT}', x.grade
  from jsonb_to_recordset({J([dict(title_key=k, title_name=n, grade=g, bonus=b, rule=r, cond=c, hidden=h, description=c + '.', n=i) for i, (k, n, g, b, r, c, h) in enumerate(D.TITLES)])})
    as x(title_key text, title_name text, grade int, bonus jsonb, rule jsonb, cond text, hidden boolean, description text, n int)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus,
  hidden = excluded.hidden, rule = excluded.rule, category = excluded.category, grade = excluded.grade;""")
fresh('cosmetics', [c[3] for c in D.COSMETICS], '꾸미기')
w(f"""insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, sort)
select x.k, x.kind, x.tier, x.name, x.cond, '{D.TITLE_CAT}', x.rule, false, x.sort
  from jsonb_to_recordset({J([dict(k=k, kind=kd, tier=t, name=n, cond=c, rule=r, sort=s) for k, kd, t, n, c, r, s in D.COSMETICS])}) as x(k text, kind text, tier text, name text, cond text, rule jsonb, sort int)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, tier = excluded.tier, category = excluded.category;""")
ns, ns_name, ns_kind, ns_arg, ns_n = D.NAME_STYLE
w(f"select pg_temp.yh_patch('public.world_name_styles()', '(1031, ''cat'', ''묵적록'', 6)', '(1031, ''cat'', ''묵적록'', 6), ({ns}, ''{ns_kind}'', ''{ns_arg}'', {ns_n})');")

ids = ', '.join(f"'{r['id']}'" for r in R)
w(f"""insert into public.world_gathering_discoveries(owner_id, spot_id)
select c.owner_id, gs.spot_id from public.world_characters c
  cross join public.world_gathering_spots gs join public.world_exploration_nodes n on n.node_id = gs.node_id and n.hierarchy_level = 1 and n.region_id in ({ids})
on conflict do nothing;""")

if os.path.exists(os.path.join(HERE, 'data_quests.py')):
    import data_quests as Q
    quests, qsteps = Q.build()
    QN = Q.NPCS
    have_npc = set(json.load(open(os.path.join(HERE, 'ref', 'quest_ref.json')))['npcs'].values())
    for k, (nm, _) in QN.items():
        if nm in have_npc: errors.append('인물 이름 겹침: ' + nm)
    bulk('world_quest_npcs', [dict(npc_key=k, npc_name=nm, bio=bio) for k, (nm, bio) in QN.items()], [('npc_key', 'text'), ('npc_name', 'text'), ('bio', 'text')], 'npc_key', ['npc_name', 'bio'])
    qitems, qrecs = [], []
    for iid, nm, field, mats, qty, desc in getattr(Q, 'NEW_ITEMS', []):
        if nm in set(REF['items']) or iid in set(REF['item_ids']): errors.append('퀘스트 물품 이름 겹침: ' + nm)
        qitems.append(item(iid, nm, 'material', 3, desc, 40, 0, True, 1))
        qrecs.append(recipe('r_' + iid, nm + ' 만들기', iid, qty, mats, field, 45, nm + '을(를) 만든다.', 3))
    bulk('world_item_catalog', qitems, ICOLS, 'item_id', IUPD)
    bulk('world_crafting_recipes', qrecs, RCOLS, 'recipe_id', RUPD)
    if qitems:
        w(f"""update public.world_item_catalog i set reference_price = ceil(1.1 * (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id))
 where i.item_id in (select jsonb_array_elements_text({J([i['item_id'] for i in qitems])}));""")
    qrows, qsrows = [], []
    for i, q in enumerate(quests):
        L = q['L']
        tot = round(0.6 * (100 * L + 12 * L * L))
        mine = [s for s in qsteps if s['quest'] == q['id']]
        task_steps = [s['step'] for s in mine if s['need'].get('tasks') or s['need'].get('give')]
        per = tot // max(1, len(task_steps))
        qrows.append(dict(quest_id=q['id'], cat=Q.CAT, title=q['title'], summary=q['summary'], region_id=q['region'], min_level=L, after=q['after'], sort=1400 + i, epilogue=[]))
        for s in mine:
            rw = {'xp': per} if s['step'] in task_steps else {}
            if s['step'] == len(mine):
                rw['gil'] = 20 + 10 * L
                rw['items'] = q['items']
            qsrows.append(dict(quest_id=q['id'], step=s['step'], title=s['title'], goal=s['goal'], need=s['need'], lines=s['lines'], reward=rw))
    bulk('world_quests', qrows, [('quest_id', 'text'), ('kind', 'text'), ('cat', 'text'), ('title', 'text'), ('summary', 'text'), ('region_id', 'text'), ('min_level', 'int'), ('after', 'jsonb'),
         ('sort', 'int'), ('epilogue', 'jsonb'), ('active', 'boolean')], 'quest_id', ['cat', 'title', 'summary', 'region_id', 'min_level', 'after', 'sort', 'epilogue', 'active'],
         {'kind': "'side'", 'after': TA('after'), 'active': 'true'})
    bulk('world_quest_steps', qsrows, [('quest_id', 'text'), ('step', 'int'), ('title', 'text'), ('goal', 'text'), ('need', 'jsonb'), ('lines', 'jsonb'), ('reward', 'jsonb')],
         'quest_id, step', ['title', 'goal', 'need', 'lines', 'reward'])
    sys.stderr.write(f"퀘스트 {len(qrows)} · 장면 {len(qsrows)} · 새 인물 {len(QN)}\n")

for bs in ('gapgwi/boss.sql', 'baekya/boss.sql', 'ultimate/boss.sql', 'ultimate/ug_gwiheo.sql', 'ultimate/ug_mukjeok.sql'):
    bp = os.path.join(os.path.dirname(HERE), bs)
    if os.path.exists(bp): w(open(bp).read())
part('j_boss_hooks.sql')
import importlib.util as _iu
_sp = _iu.spec_from_file_location('ug_data', os.path.join(os.path.dirname(HERE), 'ultimate', 'data.py'))
U = _iu.module_from_spec(_sp); _sp.loader.exec_module(U)
ug_items = [item(b['token'], b['token_name'], 'material', 5, b['token_desc'], 40, 0, False, 1) for b in U.BOARDS.values()]
fresh('items', [i['item_name'] for i in ug_items], '물품')
fresh('item_ids', [i['item_id'] for i in ug_items], '물품 id')
bulk('world_item_catalog', ug_items, ICOLS, 'item_id', IUPD)
ug_rules = dict(level=U.LEVEL, party=list(U.PARTY), tokens=U.TOKENS, mode_name=U.MODE_NAME,
                boards=U.BOARDS, shop=[dict(key=f'{b}:{i}', board=b, kind=k, id=i, name=n, price=pr) for b, k, i, n, pr in U.SHOP])
w(f"""create or replace function public.world_ultimate_rules() returns jsonb language sql immutable set search_path = '' as $r$ select {J(ug_rules)}::jsonb $r$;""")
part('../ultimate/shop.sql')
for _f in ('outfits.sql', 'pets_cosmetics.sql'):
    if os.path.exists(os.path.join(os.path.dirname(HERE), 'ultimate', _f)): part('../ultimate/' + _f)
w(f"""do $c$ declare x jsonb; ok boolean; miss text[] := '{{}}';
begin
  for x in select jsonb_array_elements(public.world_ultimate_rules() -> 'shop') loop
    ok := case x ->> 'kind'
      when 'item' then exists (select 1 from public.world_item_catalog where item_id = x ->> 'id')
      when 'outfit' then public.world_avatar_parts() -> 'outfits' ? (x ->> 'id')
      when 'pet' then exists (select 1 from public.world_pet_species where pet_id = x ->> 'id')
      when 'name_style' then x ->> 'id' like 'ns:%'
      else exists (select 1 from public.world_cosmetic_catalog where cosmetic_key = x ->> 'id') end;
    if not ok then miss := miss || (x ->> 'name'); end if;
  end loop;
  if cardinality(miss) > 0 then raise {'notice' if getattr(U, 'DRAFT', False) else 'exception'} '극 판 교환 물품이 없음: %', array_to_string(miss, ', '); end if;
end $c$;""")
fresh('titles', [t[1] for t in U.TITLES], '칭호')
fresh('title_keys', [t[0] for t in U.TITLES], '칭호 키')
w(f"""insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, hidden, rule, sort, category, grade)
select x.title_key, x.title_name, x.description, case when x.hidden then '숨겨진 조건' else x.cond end, x.bonus, x.hidden, x.rule, 3200 + x.n, '{U.TITLE_CAT}', x.grade
  from jsonb_to_recordset({J([dict(title_key=k, title_name=n, grade=g, bonus=b, rule=r, cond=c, hidden=h, description=c + '.', n=i) for i, (k, n, g, b, r, c, h) in enumerate(U.TITLES)])})
    as x(title_key text, title_name text, grade int, bonus jsonb, rule jsonb, cond text, hidden boolean, description text, n int)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus,
  hidden = excluded.hidden, rule = excluded.rule, category = excluded.category, grade = excluded.grade;""")
_qp = _iu.spec_from_file_location('ug_quest', os.path.join(os.path.dirname(HERE), 'ultimate', 'quest.py'))
UQ = _iu.module_from_spec(_qp); _qp.loader.exec_module(UQ)
w(f"""insert into public.world_quest_npcs(npc_key, npc_name, bio) select x.k, x.n, x.b from jsonb_to_recordset({J([dict(k=k, n=v[0], b=v[1]) for k, v in UQ.NPCS.items()])}) as x(k text, n text, b text)
on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;""")
fresh('npcs', [v[0] for v in UQ.NPCS.values()], '인물')
bulk('world_quests', [dict(quest_id=q['id'], cat='무용담', title=q['title'], summary=q['summary'], region_id=q['region'], min_level=UQ.LEVEL, after=q['after'], sort=1490 + k, epilogue=[])
                      for k, q in enumerate(UQ.QUESTS)],
     [('quest_id', 'text'), ('kind', 'text'), ('cat', 'text'), ('title', 'text'), ('summary', 'text'), ('region_id', 'text'), ('min_level', 'int'), ('after', 'jsonb'),
      ('sort', 'int'), ('epilogue', 'jsonb'), ('active', 'boolean')], 'quest_id', ['cat', 'title', 'summary', 'region_id', 'min_level', 'after', 'sort', 'epilogue', 'active'],
     {'kind': "'side'", 'after': TA('after'), 'active': 'true'})
bulk('world_quest_steps', [dict(quest_id=q['id'], step=k + 1, title=st['title'], goal=st['goal'], need={'at': st['at'], 'tasks': st['tasks']}, lines=st['lines'], reward={})
                           for q in UQ.QUESTS for k, st in enumerate(q['steps'])],
     [('quest_id', 'text'), ('step', 'int'), ('title', 'text'), ('goal', 'text'), ('need', 'jsonb'), ('lines', 'jsonb'), ('reward', 'jsonb')],
     'quest_id, step', ['title', 'goal', 'need', 'lines', 'reward'])
for q in UQ.QUESTS:
    if U.BOARDS[q['board']]['open_quest'] != q['id'] or U.BOARDS[q['board']]['region'] != q['region']: errors.append('무용담 퀘스트와 판 규칙이 어긋남: ' + q['id'])
_rw = subprocess.run([sys.executable, os.path.join(HERE, '..', '..', 'gen_rewrite', 'gen.py')], capture_output=True, text=True)
if _rw.returncode:
    errors.append('홍인사·요인록 대본: ' + _rw.stderr.strip())
else:
    w(_rw.stdout)
part('patch_note.sql')
w(f"""select public.world_quest_label_refresh();
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '{DB_VERSION}', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;""")

if warns:
    sys.stderr.write('경고:\n' + '\n'.join(warns) + '\n')
if errors:
    sys.stderr.write('\n'.join(errors) + '\n')
    sys.exit(1)
print('\n'.join(out))
sys.stderr.write(f"지역 {len(R)} · 답사 지점 {len(nrows) + len(xrows)} · 채집터 {len(srows)} · 요괴 {len(mons)} · 원정지 {sum(len(v) for v in D.GROUNDS.values())} · 낚시터 {len(D.FISH)} · "
                 f"조사 지점 {sum(len(v) for v in D.SITES.values())} · 물품 {len(items)}(+우수 {len(hq)}) · 제작법 {len(recipes)} · 어종 {len(D.FISH_SPECIES) + len(D.NAMED_FISH)} · "
                 f"명소 {len(D.MEISHO)} · 칭호 {len(D.TITLES)}\n")
