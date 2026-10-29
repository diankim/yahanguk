"""7.0 SQL 생성기: python3 supabase/gen70/gen.py > supabase/migrations/20261101000000_world_7_0_0.sql
조각: a_level.sql(만렙 40) → 섬 데이터(이 파일) → funcs_island.sql(섬 규칙·반요촌) → funcs_gw.sql(귀허의 주인 라운드 전투)
     → 외전 퀘스트(이 파일) → g_qol.sql(편의) → patch_note.sql"""
import json, os, sys, uuid
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from data_island import *          # noqa
from data_gaiden import QUESTS, NPCS

J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + '$J$::jsonb'
T = lambda s: 'null' if s is None else '$T$' + s + '$T$'
A = lambda xs: "array[" + ", ".join(T(x) for x in xs) + "]::text[]" if xs else "'{}'::text[]"
NS = uuid.UUID('6a1b2c3d-7000-4e00-9a00-000000000700')
U = lambda *k: 'g70/' + '/'.join(k)   # SQL에서 md5(키)::uuid로 바꾼다
out = []
w = out.append
part = lambda f: w(open(os.path.join(HERE, f)).read())

def xp_need(L): return 100 * L + 12 * L * L

w("""-- 7.0.0: 만렙 40 · 귀허도(섬 5곳·반요촌) · 6단계 장비 · 외전 「요인록」 5장 · 최종 보스 「귀허의 주인」(라운드 전투) · 편의
-- 생성기: supabase/gen70/gen.py (손으로 고치지 말고 생성기를 고친 뒤 다시 만든다)
lock table public.world_characters in access exclusive mode;
""")
part('a_level.sql')

# ─── B. 귀허도 ───
w("""
-- ─────────────────────────────────────────────────────────────
-- B. 귀허도: 지역·답사 길·채집터·요괴·원정지·조사 지점·재료·6단계 장비·반요촌 상점
-- ─────────────────────────────────────────────────────────────
alter table public.world_shop_catalog add column if not exists daily_cap int;
""")
def bulk(table, rows, cols, conflict, upd, conv=None):
    """rows(dict 목록)를 JSON 하나로 넘겨 한 번에 넣는다. cols: [(열, 타입)], conv: 열 → SQL 식(jsonb 배열 → text[] 등)"""
    if not rows: return
    conv = conv or {}
    ins = [c for c, _ in cols if c != 'r']
    sel = ', '.join(conv.get(c, 'x.' + c) for c in ins)
    w(f"""insert into public.{table}({', '.join(ins)})
select {sel} from jsonb_to_recordset({J(rows)}) as x({', '.join(c + ' ' + t for c, t in cols)})
on conflict ({conflict}) do {('update set ' + ', '.join(f'{u} = excluded.{u}' for u in upd)) if upd else 'nothing'};""")
TA = lambda c: f"array(select jsonb_array_elements_text(x.{c}))"

# 지역
rows = []
for r in REGIONS:
    rest = r.get('rest') or ('임시 야영지', 'field_camp', 2, 1)
    shop = r.get('shop') or (None, None)
    rows.append(dict(region_id=r['id'], territory_id=TERR[0], territory_name=TERR[1], region_name=r['name'], region_type=r['type'], danger_level=r['danger'], min_level=r['lv'],
        description=r['desc'], travel_from=r['nb'], faction_control='무주 금역', world_x=r['x'], world_y=r['y'], elevation=r['el'], terrain_cost=0.8 if r.get('safe') else 1,
        rest_spot_type=rest[1], rest_spot_name=rest[0], rest_quality=rest[3], rest_fee=rest[2], rest_risk=0 if r.get('safe') else 30, is_safe_zone=bool(r.get('safe')),
        shop_id=shop[0], shop_name=shop[1], theme=r['theme']))
bulk('world_map_regions', rows, [('region_id', 'text'), ('territory_id', 'text'), ('territory_name', 'text'), ('region_name', 'text'), ('region_type', 'text'), ('danger_level', 'int'),
     ('min_level', 'int'), ('description', 'text'), ('travel_from', 'jsonb'), ('gather_nodes', 'jsonb'), ('faction_control', 'text'), ('is_starting_area', 'boolean'), ('active', 'boolean'),
     ('world_x', 'int'), ('world_y', 'int'), ('elevation', 'int'), ('terrain_cost', 'numeric'), ('rest_spot_type', 'text'), ('rest_spot_name', 'text'), ('rest_quality', 'int'), ('rest_fee', 'int'),
     ('rest_risk', 'int'), ('is_safe_zone', 'boolean'), ('shop_id', 'text'), ('shop_name', 'text'), ('has_stable', 'boolean'), ('contested', 'boolean')],
     'region_id', ['travel_from', 'description', 'min_level', 'danger_level', 'world_x', 'world_y', 'rest_fee', 'shop_id', 'shop_name', 'active'],
     {'travel_from': TA('travel_from'), 'gather_nodes': "'{}'::text[]", 'is_starting_area': 'false', 'active': 'true', 'has_stable': 'false', 'contested': 'false'})
bulk('world_region_theme', [dict(region_id=r['id'], theme=r['theme']) for r in REGIONS], [('region_id', 'text'), ('theme', 'text')], 'region_id', ['theme'])
w("update public.world_map_regions set travel_from = array_append(travel_from, 'banyo_village') where region_id = 'sealed_abyss' and not ('banyo_village' = any (travel_from));")

rows = []
for rid, (bn, fs, clue, ev, hz, vis) in PROFILES.items():
    sig = sorted({i for c in SPOT_LOOT[rid].values() for i in c if i in [x[0] for x in ITEMS]})[:3] or ['banyo_scale']
    res = sorted({i for c in SPOT_LOOT[rid].values() for i in c})
    rows.append(dict(region_id=rid, biome_key=next(r['theme'] for r in REGIONS if r['id'] == rid), biome_name=bn, faction_style=fs, signature_clue=clue, signature_event=ev,
                     signature_items=sig, survival_hazard=hz, visual_identity=vis, signature_resources=res, investigation_reward='섬의 옛 기록과 이송 명부의 흔적'))
bulk('world_region_profiles', rows, [('region_id', 'text'), ('biome_key', 'text'), ('biome_name', 'text'), ('faction_style', 'text'), ('signature_clue', 'text'), ('signature_event', 'text'),
     ('signature_items', 'jsonb'), ('survival_hazard', 'text'), ('visual_identity', 'text'), ('signature_resources', 'jsonb'), ('investigation_reward', 'text')], 'region_id',
     ['biome_name', 'faction_style', 'signature_clue', 'signature_event', 'signature_items', 'survival_hazard', 'visual_identity', 'signature_resources'],
     {'signature_items': TA('signature_items'), 'signature_resources': TA('signature_resources')})
bulk('world_region_lore', [dict(region_id=rid, lines=[{'s': None, 't': t} for t in ls]) for rid, ls in LORE.items()], [('region_id', 'text'), ('lines', 'jsonb')], 'region_id', ['lines'])

# 답사 길과 채집터
spot_names = set()
def spot_name(rid, cat, k):
    adj, nouns = SPOT_ADJ[rid], SPOT_NOUN[cat]
    for i in range(len(adj) * len(nouns)):
        a, n = adj[(k + i) % len(adj)], nouns[(k * 3 + i) % len(nouns)]
        nm = f'{a} {n}'
        if nm not in spot_names:
            spot_names.add(nm); return nm
    raise SystemExit('채집터 이름이 모자람: ' + rid + cat)

nrows, srows = [], []
for r in REGIONS:
    rid, lv = r['id'], r['lv']
    levels = NODES[rid]
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
    cats = list(SPOT_LOOT[rid].keys())
    sk = 0
    for h, row in enumerate(levels):
        for i, nm in enumerate(row):
            nid = ids[h][i]; hl = h + 1
            nlv = min(40, lv + max(0, hl - 2) * 2)
            nrows.append(dict(node_id=nid, region_id=rid, parent_node_id=parents.get((h, i)), hierarchy_level=hl, node_name=nm, min_level=nlv, sort_order=i))
            if hl == 1:
                en, ec = ENTRY_SPOT[rid]
                srows.append(dict(spot_id=U('spot', rid, 'entry'), node_id=nid, spot_name=en, category=ec, r=rid, min_level=lv, yield_min=1, yield_max=2, difficulty=1))
                continue
            for j in range(2):
                cat = cats[(sk + j) % len(cats)]
                srows.append(dict(spot_id=U('spot', rid, str(h), str(i), str(j)), node_id=nid, spot_name=spot_name(rid, cat, sk + j), category=cat, r=rid,
                                  min_level=nlv, yield_min=1, yield_max=2 if hl <= 3 else 3, difficulty=10 + hl))
            sk += 2
# 부모가 먼저 들어가도록 깊이 순서로
ND = "(" + J({str(k): v for k, v in NODE_DESC.items()}) + " ->> x.hierarchy_level::text)"
bulk('world_exploration_nodes', sorted(nrows, key=lambda x: x['hierarchy_level']), [('node_id', 'text'), ('region_id', 'text'), ('parent_node_id', 'text'), ('hierarchy_level', 'smallint'),
     ('node_name', 'text'), ('description', 'text'), ('min_level', 'int'), ('sort_order', 'int')], 'node_id', ['node_name', 'parent_node_id', 'min_level'],
     {'node_id': 'md5(x.node_id)::uuid', 'parent_node_id': 'md5(x.parent_node_id)::uuid', 'description': ND})
LOOT = "array(select jsonb_array_elements_text(" + J(SPOT_LOOT) + " -> x.r -> x.category))"
bulk('world_gathering_spots', srows, [('spot_id', 'text'), ('node_id', 'text'), ('spot_name', 'text'), ('category', 'text'), ('loot_items', 'jsonb'), ('min_level', 'int'),
     ('yield_min', 'int'), ('yield_max', 'int'), ('difficulty', 'int'), ('active', 'boolean'), ('r', 'text')], 'spot_id', ['spot_name', 'loot_items', 'min_level'],
     {'spot_id': 'md5(x.spot_id)::uuid', 'node_id': 'md5(x.node_id)::uuid', 'loot_items': LOOT, 'active': 'true'})

# 요괴
MECH_DESC = {
    'tide': '물살로 끌어당겨 발을 묶는다. 거리를 두고 싸우거나 묶이기 전에 끊어라.', 'aerial': '하늘에서 내리꽂는다. 원거리 사격이 잘 듣는다.',
    'spectral': '몸이 반쯤 비친다. 물리 공격이 덜 듣고 술법이 잘 듣는다.', 'toxic': '독을 뿜는다. 해독할 약초와 회복품을 챙겨라.',
    'armored': '껍질이 단단하다. 방어를 무시하는 공격이나 술법이 낫다.', 'reflect': '공격의 일부를 되돌린다. 원거리 사격이나 봉인 제압을 써라.',
    'warded': '결계를 두른다. 결계를 깨는 한 방을 모아 두어라.', 'seal_breaker': '봉인을 약하게 만든다. 부적과 봉인 재료를 챙겨라.',
    'swarm': '떼로 몰려든다. 세 번째 행동마다 강하게 반격한다.', 'ambush': '숨어 있다 먼저 친다. 낌새를 살피고 방어를 섞어라.',
    'boss': '보스급 위협. 세 번째 행동마다 광역급 강공격을 하므로 방어 태세를 섞어라.',
}
rows = []
for rid, mons in MONSTERS.items():
    L = next(r['lv'] for r in REGIONS if r['id'] == rid)
    for mid, nm, ty, role, kind, mech, desc, drops in mons:
        if role == 'common': lo, hi, hp, atk, wt, dr = L, min(40, L + 3), 70 + 14 * L, round(8 + 1.1 * L), 14, 2
        elif role == 'main': lo, hi, hp, atk, wt, dr = L + 2, min(41, L + 6), 150 * L, round(7.5 * L), 15, 5
        else: lo, hi, hp, atk, wt, dr = L, min(40, L + 2), round((70 + 14 * L) * 1.5), round((8 + 1.1 * L) * 1.4), 12, 10
        rows.append(dict(monster_id=mid, region_id=rid, monster_name=nm, monster_type=ty, min_level=lo, max_level=hi, hp=hp, attack_power=atk, spawn_weight=wt, description=desc,
                         drops=drops, difficulty_rank=dr, mechanic_key=mech, mechanic_description=MECH_DESC[mech], role=role, kind=kind))
bulk('world_region_monsters', rows, [('monster_id', 'text'), ('region_id', 'text'), ('monster_name', 'text'), ('monster_type', 'text'), ('min_level', 'int'), ('max_level', 'int'),
     ('hp', 'int'), ('attack_power', 'int'), ('spawn_weight', 'int'), ('description', 'text'), ('drops', 'jsonb'), ('difficulty_rank', 'int'), ('mechanic_key', 'text'),
     ('mechanic_description', 'text'), ('role', 'text'), ('kind', 'text')], 'monster_id',
     ['monster_name', 'description', 'drops', 'min_level', 'max_level', 'hp', 'attack_power', 'mechanic_key', 'kind', 'role'])

# 원정지·낚시터·조사 지점
rows = []
for rid, gs in GROUNDS.items():
    r = next(x for x in REGIONS if x['id'] == rid)
    for d, (gn, gd) in enumerate(gs, 1):
        rows.append(dict(ground_id=rid + '_' + str(d), region_id=rid, ground_name=gn, description=gd, depth=d, danger=r['danger'] + d - 1, min_level=min(40, r['lv'] + (d - 1) * 2), unlock_progress=[0, 30, 70][d - 1]))
bulk('world_expedition_grounds', rows, [('ground_id', 'text'), ('region_id', 'text'), ('ground_name', 'text'), ('description', 'text'), ('depth', 'int'), ('danger', 'int'), ('min_level', 'int'),
     ('unlock_progress', 'int')], 'ground_id', ['ground_name', 'description', 'min_level'])
bulk('world_fish_grounds', [dict(region_id=rid, habitat=h, ground_name=gn, description=gd) for rid, (h, gn, gd) in FISH.items()],
     [('region_id', 'text'), ('habitat', 'text'), ('ground_name', 'text'), ('description', 'text')], 'region_id', ['habitat', 'ground_name', 'description'])
SITE_DESC = {'supply': '탐사와 제작에 필요한 물자가 남아 있는 곳이다.', 'medical': '약과 고약을 찾을 수 있는 곳이다.', 'relic': '옛 기록과 봉인 재료가 남은 곳이다.', 'abyss': '섬 깊은 곳의 희귀한 재료가 가라앉아 있는 곳이다.'}
SITE_CAT = {'supply': ('materials', ['supply', 'craft_material']), 'medical': ('recovery', ['healing', 'medical_material']), 'relic': ('relics', ['clue', 'seal_material', 'rare_material']), 'abyss': ('materials', ['rare_material', 'craft_material'])}
rows = []
for rid, sites in SITES.items():
    for k, (ty, nm, loot, rare) in enumerate(sites):
        lc, lcs = SITE_CAT[ty]
        rows.append(dict(site_id=rid + '_s' + str(k + 1), region_id=rid, site_name=nm, site_type=ty, bonus_item=loot[0], loot_table=loot,
                         rare_bonus={'items': rare, 'chance': 0.2, 'remote_bonus': True, 'distance_from_headquarters': 520}, description=SITE_DESC[ty], bonus_chance=18, loot_category=lc, loot_categories=lcs))
bulk('world_region_sites', rows, [('site_id', 'text'), ('region_id', 'text'), ('site_name', 'text'), ('site_type', 'text'), ('bonus_item', 'text'), ('loot_table', 'jsonb'), ('rare_bonus', 'jsonb'),
     ('description', 'text'), ('bonus_chance', 'int'), ('loot_category', 'text'), ('loot_categories', 'jsonb'), ('active', 'boolean')], 'site_id', ['site_name', 'loot_table', 'rare_bonus', 'active'],
     {'loot_categories': TA('loot_categories'), 'active': 'true'})

# 재료·소모품·6단계 장비
ICOLS = [('item_id', 'text'), ('item_name', 'text'), ('category', 'text'), ('tier', 'int'), ('description', 'text'), ('stackable', 'boolean'), ('required_stats', 'jsonb'), ('minimum_level', 'int'),
         ('rarity', 'text'), ('acquisition_difficulty', 'int'), ('drop_rate_modifier', 'numeric'), ('equipment_traits', 'jsonb'), ('tradeable', 'boolean'), ('reference_price', 'bigint'), ('stack_size', 'int')]
rows = [dict(item_id=i, item_name=nm, category=cat, tier=t, description=d, stackable=True, required_stats={}, minimum_level=ml, rarity=rar, acquisition_difficulty=t, drop_rate_modifier=1,
             equipment_traits={}, tradeable=tr, reference_price=pr, stack_size=st) for i, nm, cat, t, rar, st, pr, tr, ml, d in ITEMS]
ACC = {'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool'}
rrows, drows = [], []
for iid, nm, slot, stat, traits, desc, field, mats in GEAR:
    req = round(5 + (0.25 if slot in ACC else 0.35) * 3 * (LV6 - 1))
    rows.append(dict(item_id=iid, item_name=nm, category=slot, tier=6, description=desc, stackable=False, required_stats={stat: req}, minimum_level=LV6, rarity='legendary',
                     acquisition_difficulty=6, drop_rate_modifier=0.05, equipment_traits=traits, tradeable=True, reference_price=0, stack_size=1))
    rrows.append(dict(recipe_id='r_' + iid, recipe_name=nm + ' 만들기', output_item=iid, ingredients=mats, description=nm + '을(를) 만든다.', craft_field=field))
    for mk in GEAR_DROP[iid]:
        drows.append(dict(item_id=iid, mechanic_key=mk, chance_normal=0 if mk == 'boss' else 0.001, chance_elite=0.006 if mk == 'boss' else 0.004))
bulk('world_item_catalog', rows, ICOLS, 'item_id', ['item_name', 'description', 'required_stats', 'equipment_traits', 'minimum_level', 'stack_size', 'tradeable', 'reference_price'])
bulk('world_crafting_recipes', rrows, [('recipe_id', 'text'), ('recipe_name', 'text'), ('output_item', 'text'), ('output_qty', 'int'), ('ingredients', 'jsonb'), ('required_tool_tier', 'int'),
     ('required_location', 'text'), ('description', 'text'), ('minimum_level', 'int'), ('recipe_difficulty', 'int'), ('quality_bonus', 'int'), ('required_skill_rank', 'int'), ('craft_field', 'text')],
     'recipe_id', ['ingredients', 'craft_field', 'required_location', 'minimum_level'],
     {'output_qty': '1', 'required_tool_tier': '1', 'required_location': "'반요촌'", 'minimum_level': str(LV6), 'recipe_difficulty': '6', 'quality_bonus': '0', 'required_skill_rank': '1'})
bulk('world_gear_drops', drows, [('item_id', 'text'), ('mechanic_key', 'text'), ('level_min', 'int'), ('level_max', 'int'), ('chance_normal', 'numeric'), ('chance_elite', 'numeric'),
     ('chance_guardian', 'numeric')], 'item_id, mechanic_key', [], {'level_min': '31', 'level_max': '40', 'chance_guardian': '0.02'})
w("""-- 6단계 기준 시세: 가장 싼 제작법 재료값 ×1.2와 같은 칸 5단계 가장 비싼 것 ×1.15 가운데 큰 값
update public.world_item_catalog i set reference_price = greatest(
    ceil(1.2 * (select sum(m.reference_price * (x.value)::int) from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id)),
    ceil(1.15 * (select max(f.reference_price) from public.world_item_catalog f where f.tier = 5 and f.category = i.category and f.item_id not like 'raid%' and f.item_id <> 'n5_lighthouse')))
 where i.tier = 6;""")

# 반요촌 잡화(기준가 0은 원래 기준가 ×3)
w(f"""insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select 'banyo_shop', x.item_id, case when x.price > 0 then x.price else (select i.reference_price * 3 from public.world_item_catalog i where i.item_id = x.item_id) end, 1, 1, x.cap
  from jsonb_to_recordset({J([dict(item_id=i, price=p, cap=c) for i, p, c in BANYO_SHOP])}) as x(item_id text, price bigint, cap int)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price, daily_cap = excluded.daily_cap;""")

# 기존 캐릭터: 섬 들머리 채집터를 찾은 것으로(새 캐릭터는 trg_world_entry_spots)
w("""insert into public.world_gathering_discoveries(owner_id, spot_id)
select c.owner_id, gs.spot_id from public.world_characters c
  cross join public.world_gathering_spots gs join public.world_exploration_nodes n on n.node_id = gs.node_id and n.hierarchy_level = 1 and n.region_id in
    ('banyo_village', 'ash_reeds', 'inverted_shrine', 'moonless_market', 'gwiheo_core')
on conflict do nothing;
""")

part('funcs_island.sql')
part('funcs_gw.sql')

# ─── 외전 「요인록」 ───
w("""
-- ─────────────────────────────────────────────────────────────
-- 외전 「요인록」 5장(보조 퀘스트 틀, 분류 「외전·요인록」)
-- ─────────────────────────────────────────────────────────────""")
bulk('world_quest_npcs', [dict(npc_key=k, npc_name=nm, bio=bio) for k, (nm, bio) in NPCS.items()], [('npc_key', 'text'), ('npc_name', 'text'), ('bio', 'text')], 'npc_key', ['npc_name', 'bio'])
qrows, strows = [], []
for i, q in enumerate(QUESTS):
    L = q['L']; tot = round(0.6 * xp_need(L))
    task_steps = [k for k, st in enumerate(q['steps']) if st[2].get('tasks') or st[2].get('give')]
    per = tot // max(1, len(task_steps)); gil = 20 + 10 * L
    epi = [{'s': s_, 't': t} for s_, t in q.get('epilogue', [])]
    qrows.append(dict(quest_id=q['id'], cat='외전·요인록', title=q['title'], summary=q['summary'], region_id=q['region'], min_level=L, after=q['after'], sort=1000 + i, epilogue=epi))
    for k, (title, goal, need, ls) in enumerate(q['steps']):
        rw = {}
        if k in task_steps: rw['xp'] = per
        if k == len(q['steps']) - 1:
            rw['gil'] = gil; rw['items'] = q['items']
        lines = [{'s': s_, 't': t} for s_, t in ls] + (epi if k == len(q['steps']) - 1 else [])
        strows.append(dict(quest_id=q['id'], step=k + 1, title=title, goal=goal, need=need, lines=lines, reward=rw))
bulk('world_quests', qrows, [('quest_id', 'text'), ('kind', 'text'), ('cat', 'text'), ('title', 'text'), ('summary', 'text'), ('region_id', 'text'), ('min_level', 'int'), ('after', 'jsonb'),
     ('sort', 'int'), ('epilogue', 'jsonb'), ('active', 'boolean')], 'quest_id', ['cat', 'title', 'summary', 'region_id', 'min_level', 'after', 'sort', 'epilogue', 'active'],
     {'kind': "'side'", 'after': TA('after'), 'active': 'true'})
bulk('world_quest_steps', strows, [('quest_id', 'text'), ('step', 'int'), ('title', 'text'), ('goal', 'text'), ('need', 'jsonb'), ('lines', 'jsonb'), ('reward', 'jsonb')],
     'quest_id, step', ['title', 'goal', 'need', 'lines', 'reward'])

part('g_qol.sql')
part('g_tools.sql')
part('patch_note.sql')
w("""insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261101000000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;""")
print('\n'.join(out))
