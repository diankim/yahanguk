"""7.1 새 지역 11곳을 SQL로 바꾼다(7.0 귀허도 생성기 gen70/gen.py의 지역 부분을 일반화).
data_regions.py(REGIONS·NODES·SPOT_*·ENTRY_SPOT·MONSTERS·GROUNDS·FISH·PROFILES·LORE·SITES·NPCS·QUESTS)를 받아 w()로 내보낸다."""
NODE_DESC = {
    1: '지역에 막 들어선 곳입니다. 탐색하면 안쪽으로 이어지는 길을 찾을 수 있습니다.',
    2: '지역의 바깥 권역입니다. 탐색을 이어가면 더 안쪽 구역을 찾을 수 있습니다.',
    3: '권역 안쪽의 구역입니다. 요괴의 흔적이 짙어지고 채집터가 드러납니다.',
    4: '깊숙한 곳입니다. 쓸 만한 채집터가 숨어 있지만 위험도 커집니다.',
    5: '가장 깊은 지점입니다. 희귀한 자원과 강한 요괴가 함께 있습니다.',
}
L4_KIDS = [2, 1, 2, 1]
L5_KIDS = [2, 1, 1, 2, 1, 1]
MECH_DESC = {
    'tide': '물살로 끌어당겨 발을 묶는다. 거리를 두고 싸우거나 묶이기 전에 끊어라.', 'aerial': '하늘에서 내리꽂는다. 원거리 사격이 잘 듣는다.',
    'spectral': '몸이 반쯤 비친다. 물리 공격이 덜 듣고 술법이 잘 듣는다.', 'toxic': '독을 뿜는다. 해독할 약초와 회복품을 챙겨라.',
    'armored': '껍질이 단단하다. 방어를 무시하는 공격이나 술법이 낫다.', 'reflect': '공격의 일부를 되돌린다. 원거리 사격이나 봉인 제압을 써라.',
    'warded': '결계를 두른다. 결계를 깨는 한 방을 모아 두어라.', 'seal_breaker': '봉인을 약하게 만든다. 부적과 봉인 재료를 챙겨라.',
    'swarm': '떼로 몰려든다. 세 번째 행동마다 강하게 반격한다.', 'ambush': '숨어 있다 먼저 친다. 낌새를 살피고 방어를 섞어라.',
    'boss': '보스급 위협. 세 번째 행동마다 광역급 강공격을 하므로 방어 태세를 섞어라.',
}
SITE_DESC = {'supply': '탐사와 제작에 필요한 물자가 남아 있는 곳이다.', 'medical': '약과 고약을 찾을 수 있는 곳이다.', 'relic': '옛 기록과 봉인 재료가 남은 곳이다.', 'abyss': '깊은 곳의 희귀한 재료가 가라앉아 있는 곳이다.'}
SITE_CAT = {'supply': ('materials', ['supply', 'craft_material']), 'medical': ('recovery', ['healing', 'medical_material']), 'relic': ('relics', ['clue', 'seal_material', 'rare_material']), 'abyss': ('materials', ['rare_material', 'craft_material'])}
TERR_NAME = {'capital': '야행국 직할령', 'east': '수향 연맹령', 'frontier': '적월 교령', 'north': '북령 맹약지', 'south': '남명 망국령', 'underworld': '흑련 지하회랑', 'heavenward': '천명 상계'}


def xp_need(L): return 100 * L + 12 * L * L


def emit(D, w, J, bulk, TA, U, existing_spot_names=()):
    w("""
-- ─────────────────────────────────────────────────────────────
-- D. 새 지역 11곳(세력마다 낮음·중간·높음을 고루): 지역·답사 길·채집터·요괴·원정지·낚시터·조사 지점·처음 방문 글·보조 퀘스트
-- ─────────────────────────────────────────────────────────────""")
    R = D.REGIONS
    rows = []
    for r in R:
        rows.append(dict(region_id=r['id'], territory_id=r['terr'], territory_name=TERR_NAME[r['terr']], region_name=r['name'], region_type=r['type'], danger_level=r['danger'],
                         min_level=r['lv'], description=r['desc'], travel_from=r['nb'], faction_control='', world_x=r['x'], world_y=r['y'], elevation=r['el'], terrain_cost=1,
                         rest_spot_type='field_camp', rest_spot_name='임시 야영지', rest_quality=1, rest_fee=2, rest_risk=30, is_safe_zone=False, shop_id=None, shop_name=None))
    bulk('world_map_regions', rows, [('region_id', 'text'), ('territory_id', 'text'), ('territory_name', 'text'), ('region_name', 'text'), ('region_type', 'text'), ('danger_level', 'int'),
         ('min_level', 'int'), ('description', 'text'), ('travel_from', 'jsonb'), ('gather_nodes', 'jsonb'), ('faction_control', 'text'), ('is_starting_area', 'boolean'), ('active', 'boolean'),
         ('world_x', 'int'), ('world_y', 'int'), ('elevation', 'int'), ('terrain_cost', 'numeric'), ('rest_spot_type', 'text'), ('rest_spot_name', 'text'), ('rest_quality', 'int'), ('rest_fee', 'int'),
         ('rest_risk', 'int'), ('is_safe_zone', 'boolean'), ('shop_id', 'text'), ('shop_name', 'text'), ('has_stable', 'boolean'), ('contested', 'boolean')],
         'region_id', ['travel_from', 'description', 'min_level', 'danger_level', 'world_x', 'world_y', 'active', 'territory_id', 'territory_name'],
         {'travel_from': TA('travel_from'), 'gather_nodes': "'{}'::text[]", 'is_starting_area': 'false', 'active': 'true', 'has_stable': 'false', 'contested': 'false'})
    bulk('world_region_theme', [dict(region_id=r['id'], theme=r['theme']) for r in R], [('region_id', 'text'), ('theme', 'text')], 'region_id', ['theme'])
    # 이어진 길은 양쪽으로
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

    spot_names = set(existing_spot_names)

    def spot_name(rid, cat, k):
        adj, nouns = D.SPOT_ADJ[rid], D.SPOT_NOUN[cat]
        for i in range(len(adj) * len(nouns)):
            a, n = adj[(k + i) % len(adj)], nouns[(k * 3 + i) % len(nouns)]
            nm = f'{a} {n}'
            if nm not in spot_names:
                spot_names.add(nm); return nm
        raise SystemExit('채집터 이름이 모자람: ' + rid + cat)

    nrows, srows = [], []
    for r in R:
        rid, lv = r['id'], r['lv']
        levels = D.NODES[rid]
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
                nlv = min(40, lv + max(0, hl - 2) * 2)
                nrows.append(dict(node_id=nid, region_id=rid, parent_node_id=parents.get((h, i)), hierarchy_level=hl, node_name=nm, min_level=nlv, sort_order=i))
                if hl == 1:
                    en, ec = D.ENTRY_SPOT[rid]
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

    rows = []
    for rid, mons in D.MONSTERS.items():
        L = next(r['lv'] for r in R if r['id'] == rid)
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

    rows = []
    for rid, gs in D.GROUNDS.items():
        r = next(x for x in R if x['id'] == rid)
        for d, (gn, gd) in enumerate(gs, 1):
            rows.append(dict(ground_id=rid + '_' + str(d), region_id=rid, ground_name=gn, description=gd, depth=d, danger=min(10, r['danger'] + d - 1),
                             min_level=min(40, r['lv'] + (d - 1) * 2), unlock_progress=[0, 30, 70][d - 1]))
    bulk('world_expedition_grounds', rows, [('ground_id', 'text'), ('region_id', 'text'), ('ground_name', 'text'), ('description', 'text'), ('depth', 'int'), ('danger', 'int'), ('min_level', 'int'),
         ('unlock_progress', 'int')], 'ground_id', ['ground_name', 'description', 'min_level'])
    if D.FISH:
        bulk('world_fish_grounds', [dict(region_id=rid, habitat=h, ground_name=gn, description=gd) for rid, (h, gn, gd) in D.FISH.items()],
             [('region_id', 'text'), ('habitat', 'text'), ('ground_name', 'text'), ('description', 'text')], 'region_id', ['habitat', 'ground_name', 'description'])
    rows = []
    for rid, sites in D.SITES.items():
        for k, (ty, nm, loot, rare) in enumerate(sites):
            lc, lcs = SITE_CAT[ty]
            rows.append(dict(site_id=rid + '_s' + str(k + 1), region_id=rid, site_name=nm, site_type=ty, bonus_item=loot[0], loot_table=loot,
                             rare_bonus={'items': rare, 'chance': 0.2, 'remote_bonus': True, 'distance_from_headquarters': 300}, description=SITE_DESC[ty], bonus_chance=18, loot_category=lc, loot_categories=lcs))
    bulk('world_region_sites', rows, [('site_id', 'text'), ('region_id', 'text'), ('site_name', 'text'), ('site_type', 'text'), ('bonus_item', 'text'), ('loot_table', 'jsonb'), ('rare_bonus', 'jsonb'),
         ('description', 'text'), ('bonus_chance', 'int'), ('loot_category', 'text'), ('loot_categories', 'jsonb'), ('active', 'boolean')], 'site_id', ['site_name', 'loot_table', 'rare_bonus', 'active'],
         {'loot_categories': TA('loot_categories'), 'active': 'true'})
    ids = ', '.join(f"'{r['id']}'" for r in R)
    w(f"""-- 기존 캐릭터: 새 지역 들머리 채집터를 찾은 것으로(새 캐릭터는 trg_world_entry_spots)
insert into public.world_gathering_discoveries(owner_id, spot_id)
select c.owner_id, gs.spot_id from public.world_characters c
  cross join public.world_gathering_spots gs join public.world_exploration_nodes n on n.node_id = gs.node_id and n.hierarchy_level = 1 and n.region_id in ({ids})
on conflict do nothing;""")

    # 보조 퀘스트(지역마다 하나): 경험치 합 0.4×xp_need(L)을 할 일·넘김 장면에 나누고, 마지막 장면에 전 5+4L와 물품
    bulk('world_quest_npcs', [dict(npc_key=('' if k.startswith('q:') else 'q:') + k, npc_name=nm, bio=bio) for k, (nm, bio) in D.NPCS.items()], [('npc_key', 'text'), ('npc_name', 'text'), ('bio', 'text')], 'npc_key', ['npc_name', 'bio'])
    qrows, strows = [], []
    for i, q in enumerate(D.QUESTS):
        L = q['L']; tot = round(0.4 * xp_need(L))
        task_steps = [k for k, st in enumerate(q['steps']) if st[2].get('tasks') or st[2].get('give')]
        per = tot // max(1, len(task_steps)); gil = 5 + 4 * L
        epi = [{'s': s_, 't': t} for s_, t in q.get('epilogue', [])]
        qrows.append(dict(quest_id=q['id'], cat=q['cat'], title=q['title'], summary=q['summary'], region_id=q['region'], min_level=L, after=q.get('after', []), sort=900 + i, epilogue=epi))
        for k, (title, goal, need, ls) in enumerate(q['steps']):
            for t in need.get('tasks', []):          # 지역은 기존 퀘스트처럼 목록으로
                if isinstance(t.get('r'), str): t['r'] = [t['r']]
            rw = {}
            if k in task_steps: rw['xp'] = per
            if k == len(q['steps']) - 1:
                rw['gil'] = gil; rw['items'] = q.get('items', {})
            lines = [{'s': s_, 't': t} for s_, t in ls] + (epi if k == len(q['steps']) - 1 else [])
            strows.append(dict(quest_id=q['id'], step=k + 1, title=title, goal=goal, need=need, lines=lines, reward=rw))
    bulk('world_quests', qrows, [('quest_id', 'text'), ('kind', 'text'), ('cat', 'text'), ('title', 'text'), ('summary', 'text'), ('region_id', 'text'), ('min_level', 'int'), ('after', 'jsonb'),
         ('sort', 'int'), ('epilogue', 'jsonb'), ('active', 'boolean')], 'quest_id', ['cat', 'title', 'summary', 'region_id', 'min_level', 'after', 'sort', 'epilogue', 'active'],
         {'kind': "'side'", 'after': TA('after'), 'active': 'true'})
    bulk('world_quest_steps', strows, [('quest_id', 'text'), ('step', 'int'), ('title', 'text'), ('goal', 'text'), ('need', 'jsonb'), ('lines', 'jsonb'), ('reward', 'jsonb')],
         'quest_id, step', ['title', 'goal', 'need', 'lines', 'reward'])
