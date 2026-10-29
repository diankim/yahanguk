"""7.2 SQL 생성기: python3 supabase/gen72/gen.py > supabase/migrations/20261103000000_world_7_2_0.sql
가구 그림(assets/js/housing/furniture.js)·꼬마 동무 그림(pets.js)을 node로 읽어 물품·제작법·상점·출처를 만든다.
조각: _patch_fn.sql(7.1과 같은 도우미) → h_housing.sql(별채) → 가구 데이터 → p_pets.sql(꼬마 동무) → 꼬마 동무 데이터 → x_misc.sql"""
import json, math, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + '$J$::jsonb'
out = []
w = out.append
part = lambda f: w(open(os.path.join(HERE, f)).read())


def node_dump(js):
    return json.loads(subprocess.check_output(['node', '--input-type=module', '-e', js], cwd=ROOT))


FUR = node_dump("""
const F = await import('./assets/js/housing/furniture.js');
const o = { FUR: {}, WALL: {}, PAPER: {}, GROUND: {}, DEFAULT_SET: F.DEFAULT_SET };
for (const [k, f] of Object.entries(F.FUR)) o.FUR[k] = { name: f.name, grade: f.grade, W: f.W, D: f.D, layer: f.layer || 'floor', top: f.top || 0, pet: f.pet || null, cat: f.cat };
for (const [k, f] of Object.entries(F.WALL)) o.WALL[k] = { name: f.name, grade: f.grade, kind: f.kind, w: f.w, h: f.h, cat: f.cat };
for (const [k, f] of Object.entries(F.PAPER)) o.PAPER[k] = { name: f.name, grade: f.grade };
for (const [k, f] of Object.entries(F.GROUND)) o.GROUND[k] = { name: f.name, grade: f.grade };
console.log(JSON.stringify(o));
""")

# 재료 시세(2026-10-29 운영 DB)
MAT = {'wood': 15, 'resin': 25, 'lumber': 40, 'lacquer': 40, 'reinforced_lumber': 310, 'spirit_bark': 260, 'river_reed': 20, 'silk': 65, 'cloud_cotton': 65, 'spirit_thread': 150,
       'raw_iron': 20, 'charcoal': 20, 'iron_ingot': 50, 'steel_ingot': 450, 'ore': 22, 'spirit_dust': 65, 'spirit_glass': 190, 'jade_shard': 260, 'herb': 12, 'moon_moss': 65,
       'seal_paper': 20, 'inkstone': 20, 'fine_paper': 80, 'sealing_ink': 65, 'cinnabar': 65, 'mirror_shard': 260, 'golden_carp': 55, 'lantern_crucian': 60, 'talisman_thread': 85}
# 분야와 등급별 재료(갈래 → (분야, {등급: 재료}))
RECIPE_BY_CAT = {
    '좌석·탁자': ('목공', {1: {'wood': 4, 'resin': 1}, 2: {'lumber': 3, 'lacquer': 1}, 3: {'reinforced_lumber': 2, 'lacquer': 2}}),
    '수납': ('목공', {1: {'wood': 5, 'resin': 1}, 2: {'lumber': 4, 'lacquer': 2}, 3: {'reinforced_lumber': 2, 'lacquer': 3, 'spirit_bark': 1}}),
    '병풍': ('목공', {2: {'lumber': 2, 'fine_paper': 2, 'sealing_ink': 1}, 3: {'reinforced_lumber': 1, 'fine_paper': 3, 'sealing_ink': 2, 'cinnabar': 1}}),
    '침구': ('직조', {1: {'river_reed': 3, 'cloud_cotton': 1}, 2: {'cloud_cotton': 3, 'silk': 1}, 3: {'silk': 3, 'spirit_thread': 2, 'cloud_cotton': 2}}),
    '깔개': ('직조', {1: {'river_reed': 5}, 2: {'river_reed': 6, 'silk': 2}, 3: {'silk': 4, 'spirit_thread': 2}}),
    '조명': ('법구 공예', {1: {'seal_paper': 2, 'wood': 2, 'resin': 1}, 2: {'lumber': 1, 'fine_paper': 2, 'spirit_dust': 1}, 3: {'ore': 4, 'spirit_dust': 2, 'charcoal': 2}}),
    '화분': ('법구 공예', {1: {'herb': 3, 'ore': 1}, 2: {'herb': 3, 'moon_moss': 1, 'ore': 2}, 3: {'spirit_bark': 1, 'moon_moss': 2, 'ore': 2}}),
    '도자': ('법구 공예', {1: {'ore': 2, 'charcoal': 1}, 2: {'ore': 3, 'spirit_dust': 1, 'charcoal': 2}, 3: {'spirit_glass': 1, 'jade_shard': 1, 'charcoal': 2}}),
    '화로': ('단조', {1: {'raw_iron': 2, 'charcoal': 1}, 2: {'iron_ingot': 2, 'charcoal': 2}, 3: {'steel_ingot': 1, 'iron_ingot': 2}}),
    '어항': ('목공', {2: {'lumber': 2, 'spirit_glass': 1, 'lantern_crucian': 1}, 3: {'reinforced_lumber': 1, 'spirit_glass': 1, 'golden_carp': 1, 'ore': 2}}),
    '정원': ('법구 공예', {2: {'ore': 4, 'moon_moss': 1}, 3: {'ore': 4, 'spirit_dust': 1, 'charcoal': 1, 'moon_moss': 1}}),
    '소품': ('단조', {1: {'raw_iron': 1, 'charcoal': 1}, 2: {'iron_ingot': 1, 'charcoal': 1}, 3: {'iron_ingot': 2, 'charcoal': 1, 'spirit_dust': 1}}),
    '족자': ('봉인 공예', {1: {'seal_paper': 3, 'inkstone': 1}, 2: {'fine_paper': 2, 'sealing_ink': 1}, 3: {'fine_paper': 3, 'sealing_ink': 2, 'cinnabar': 1}}),
    '부채': ('봉인 공예', {1: {'seal_paper': 2, 'wood': 1}, 2: {'fine_paper': 1, 'lumber': 1}}),
    '탈': ('목공', {3: {'reinforced_lumber': 1, 'lacquer': 2, 'cinnabar': 1}}),
    '지도': ('봉인 공예', {3: {'fine_paper': 3, 'sealing_ink': 2, 'inkstone': 2}}),
    '창문': ('목공', {1: {'wood': 4, 'seal_paper': 1}, 2: {'lumber': 2, 'seal_paper': 2, 'lacquer': 1}}),
    '문': ('목공', {2: {'lumber': 3, 'seal_paper': 2}}),
    '들보': ('목공', {2: {'lumber': 3, 'cinnabar': 1}}),
    '_paper': ('봉인 공예', {1: {'seal_paper': 4}, 2: {'fine_paper': 2, 'cinnabar': 1}, 3: {'fine_paper': 3, 'sealing_ink': 2, 'inkstone': 1}}),
    '_ground': ('목공', {1: {'wood': 5}, 2: {'lumber': 3, 'ore': 2}, 3: {'reinforced_lumber': 2, 'lumber': 2}}),
}
# 소품이 다른 갈래 재료를 쓰는 것
RECIPE_OVERRIDE = {
    'surf_books': ('봉인 공예', {'seal_paper': 3, 'resin': 1}), 'surf_munbang': ('봉인 공예', {'fine_paper': 1, 'inkstone': 2, 'wood': 1}),
    'surf_teaset': ('법구 공예', {'ore': 3, 'charcoal': 2, 'herb': 1}), 'pet_bell': ('단조', {'raw_iron': 1, 'talisman_thread': 1}),
    'wardrobe_najeon': ('목공', {'reinforced_lumber': 2, 'lacquer': 3, 'mirror_shard': 1}), 'bookshelf': ('목공', {'reinforced_lumber': 2, 'lumber': 3}),
    'pet_perch': ('목공', {'lumber': 2, 'resin': 2}),
}
LEVEL = {1: 1, 2: 8, 3: 15}
# 조건을 채워 한 번 얻는 가구(귀속)
ONCE = {
    'screen_ilwol': 'raid_final', 'lantern_pearl': 'gw_first', 'board_cheonha': 'title:tn_champ', 'bonsai_yeonri': 'title:wed_vow', 'throne_dragon': 'title:gw_kill10',
    'screen_hwajo': 'chapter:eclipse_gate', 'garden_suban': 'chapter:sunken_lantern', 'window_round': 'chapter:ash_sea', 'board_yahaeng': 'chapter:lamp_shadow',
    'door_yeodat': 'chapter:nine_gates', 'scroll_magpie': 'title:tn_team',
}
RAID_WORLD = ['rug_unhak', 'gayageum']                       # 봉연의 그림자 확률(명품, 귀속)
VAULT = {'mask_hahoe': (3, 200), 'map_old': (3, 220), 'gayageum': (5, 400)}   # 세력 비고(공훈, 귀속)
DEFAULT_ONLY = {'table_lacquer', 'lantern_cheongsa', 'beam_dancheong', 'window_flower', 'hp:dancheong', 'hg:maru'}   # 기본 세트에만(귀속)
COND_PRICE = {3: 300, 4: 800, 5: 2000}

D = FUR['DEFAULT_SET']
for it in D['items']: assert it['k'] in FUR['FUR'], it
for it in D['wall']: assert it['k'] in FUR['WALL'], it
for k in list(ONCE) + RAID_WORLD + list(VAULT):
    assert k in FUR['FUR'] or k in FUR['WALL'], '가구 키 없음: ' + k


def price_of(mats): return int(math.ceil(sum(MAT[m] * q for m, q in mats.items()) * 1.2 / 10.0) * 10)


rows, recipes, sources, shop, vault, default_shop = [], [], [], [], [], []
for typ in ('FUR', 'WALL', 'PAPER', 'GROUND'):
    for k, f in FUR[typ].items():
        g = f['grade']
        if typ == 'FUR':
            iid = 'hf_' + k; cat = f['cat']
            tr = {'hk': k, 'kind': f['layer'], 'w': f['W'], 'd': f['D'], 'top': f['top'], 'cat': cat, 'grade': g}
            if f['pet']: tr['pet'] = f['pet']
            dkey = k
        elif typ == 'WALL':
            iid = 'hf_' + k; cat = f['cat']
            tr = {'hk': k, 'kind': 'wall', 'wall': f['kind'], 'ww': f['w'], 'wh': f['h'], 'cat': cat, 'grade': g}
            dkey = k
        else:
            pre = 'hp_' if typ == 'PAPER' else 'hg_'
            iid = pre + k; cat = '_paper' if typ == 'PAPER' else '_ground'
            tr = {'hk': k, 'kind': 'paper' if typ == 'PAPER' else 'ground', 'cat': '벽지' if typ == 'PAPER' else '바닥재', 'grade': g}
            dkey = ('hp:' if typ == 'PAPER' else 'hg:') + k
        cond = dkey in DEFAULT_ONLY or k in ONCE or k in RAID_WORLD or k in VAULT or g >= 4
        mats = field = None
        if not cond:
            if k in RECIPE_OVERRIDE: field, mats = RECIPE_OVERRIDE[k]
            else:
                fld, by = RECIPE_BY_CAT[cat]
                mats = by.get(g) or by[max(x for x in by if x <= g)] if any(x <= g for x in by) else by[min(by)]
                field = fld
        price = price_of(mats) if mats else COND_PRICE.get(g, 120)
        if dkey in DEFAULT_ONLY:
            # 기본 세트는 만들 수 없으니 본부 상점(capital_market)에서 늘 판다. 값은 같은 갈래·등급 제작품 재료값의 1.5배(만들 수 없는 몫), 귀속이라 되팔 수 없다
            fld, by = RECIPE_BY_CAT[cat]
            dm = by.get(g) or by[max(x for x in by if x <= g)]
            price = int(math.ceil(price_of(dm) * 1.5 / 10.0) * 10)
            default_shop.append(dict(item_id=iid, price=price))
        src = []
        if dkey in DEFAULT_ONLY: src.append('기본 세트')
        if k in ONCE: src.append({'raid_final': '10장 결전 첫 승리', 'gw_first': '귀허의 주인 첫 처치'}.get(ONCE[k], '칭호 보상' if ONCE[k].startswith('title:') else '이야기 장 보상'))
        if k in RAID_WORLD: src.append('봉연의 그림자 토벌')
        if k in VAULT: src.append('세력 비고')
        if mats: src.append('제작')
        desc = f"별채 가구 · {tr['cat']}. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다."
        rows.append(dict(item_id=iid, item_name=f['name'], tier=g, description=desc, equipment_traits=tr, tradeable=not cond, reference_price=price))
        if mats:
            recipes.append(dict(recipe_id='r_' + iid, recipe_name=f['name'] + ' 만들기', output_item=iid, ingredients=mats, minimum_level=LEVEL[min(g, 3)],
                                recipe_difficulty=g, craft_field=field, description=f"별채에 놓을 {f['name']}을(를) 만든다."))
            if g == 1: shop.append(dict(item_id=iid, price=price))
            if g == 2: sources.append(dict(source='drop_normal', item_id=iid, chance=1))
            if g == 3:
                sources.append(dict(source='drop_guardian', item_id=iid, chance=1))
                sources.append(dict(source='expedition', item_id=iid, chance=1))
        if k in ONCE: sources.append(dict(source=ONCE[k], item_id=iid, chance=1))
        if k in RAID_WORLD: sources.append(dict(source='raid_world', item_id=iid, chance=1))
        if k in VAULT: vault.append(dict(item_id=iid, rank_need=VAULT[k][0], price=VAULT[k][1]))

w("""-- 7.2.0: 별채(하우징) · 꼬마 동무 · …
-- 생성기: supabase/gen72/gen.py (손으로 고치지 말고 생성기를 고친 뒤 다시 만든다). 7.1.0(20261102000000) 뒤에 돈다.
lock table public.world_characters in access exclusive mode;
""")
part('../gen71/_patch_fn.sql')
part('h_housing.sql')
w(f"""
-- ─── 가구 {len(rows)}가지(바닥·벽·벽지·바닥재) · 제작법 {len(recipes)} · 상점 · 출처 ───
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
select x.item_id, x.item_name, 'furniture', x.tier, x.description, false, '{{}}'::jsonb, 1, x.equipment_traits, x.tradeable, x.reference_price, 1
  from jsonb_to_recordset({J(rows)}) as x(item_id text, item_name text, tier int, description text, equipment_traits jsonb, tradeable boolean, reference_price int)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = 1;
insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, required_skill, required_skill_rank, craft_field)
select x.recipe_id, x.recipe_name, x.output_item, 1, x.ingredients, null, 1, null, x.description, x.minimum_level, null, x.recipe_difficulty, null, 1, x.craft_field
  from jsonb_to_recordset({J(recipes)}) as x(recipe_id text, recipe_name text, output_item text, ingredients jsonb, description text, minimum_level int, recipe_difficulty int, craft_field text)
on conflict (recipe_id) do update set ingredients = excluded.ingredients, minimum_level = excluded.minimum_level, recipe_difficulty = excluded.recipe_difficulty,
  craft_field = excluded.craft_field, description = excluded.description, recipe_name = excluded.recipe_name;
-- 범품 가구는 안전지대 상점(대장간·반요촌 빼고)마다 다섯 가지씩 돌아가며 판다
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, x.item_id, x.price, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join lateral (select y.item_id, y.price from jsonb_to_recordset({J(shop)}) as y(item_id text, price int) order by md5(s.shop_id || y.item_id) limit 5) x
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;
-- 기본 세트 「단청 별채」 여섯 가지는 본부 상점에서 늘 판다(버려도 다시 살 수 있게, 귀속)
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select 'capital_market', x.item_id, x.price, 0, 10, null from jsonb_to_recordset({J(default_shop)}) as y(item_id text, price int) cross join lateral (select y.item_id, y.price) x
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;
delete from public.world_furniture_sources;
insert into public.world_furniture_sources(source, item_id, chance) select x.source, x.item_id, x.chance from jsonb_to_recordset({J(sources)}) as x(source text, item_id text, chance numeric);
insert into public.world_faction_vault(faction_id, item_id, rank_need, price, sort, kind)
select f.faction_id, x.item_id, x.rank_need, x.price, 900 + x.rank_need, 'item' from public.world_major_factions f cross join jsonb_to_recordset({J(vault)}) as x(item_id text, rank_need int, price int)
on conflict do nothing;
-- 기본 세트 「단청 별채」
create or replace function public.world_housing_default_set() returns jsonb language sql immutable set search_path = '' as $D$ select {J(D)} $D$;
""")

# 개방 퀘스트 「객사 별채」(Lv15 + 4장 마침)
L = 15; xp = round(0.4 * (100 * L + 12 * L * L))
NPC = {'hs_bomi': ('객사 살림꾼 보미', '본부 객사의 살림을 맡은 사람. 손님 방부터 뒤뜰 장독까지 모르는 것이 없다. 오래 비어 있던 별채를 아까워한다.')}
STEPS = [
    ('빈 별채', '본부 객사의 살림꾼 보미에게 말을 겁니다.', {'at': ['hq_dorm']}, [
        (None, '객사 뒤뜰, 마른 감나무 너머로 지붕 낮은 별채가 보인다. 문살에 먼지가 하얗게 앉았다.'),
        ('q:hs_bomi', '저 별채 말이우? 예전엔 오래 머무는 조사원들이 쓰던 방이었지.'),
        ('q:hs_bomi', '주인이 안 돌아온 지 몇 해째라, 이제 들일 사람을 찾고 있었수.'),
        ('q:hs_bomi', '손 좀 보면 쓸 만해. 마음 있으면 채비부터 같이 해 봅시다.')], {}),
    ('채비', '부적목 6개·황지 4개를 채집해 오고, 오방색 방석 하나를 직접 만듭니다.', {'at': ['hq_dorm'], 'give': {'wood': 6, 'seal_paper': 4},
        'tasks': [{'t': 'gather', 'n': 6, 'items': ['wood']}, {'t': 'gather', 'n': 4, 'items': ['seal_paper']}, {'t': 'craft', 'n': 1, 'items': ['hf_cushion_obang']}]}, [
        (None, '보미가 부적목을 하나씩 두드려 보고 고개를 끄덕인다.'),
        ('q:hs_bomi', '나무는 좋수. 황지는 문창에 바를 거라 넉넉해야 해.'),
        ('q:hs_bomi', '방석은 손수 만든 거네. 바느질이 삐뚤어도 처음 깔 자리는 제 손으로 만든 게 제일이우.'),
        ('q:hs_bomi', '이제 수리비만 치르면 열쇠를 넘겨 드리지.')], {'xp': xp // 2}),
    ('입주', '수리비 1,000전을 치르고 별채 열쇠를 받습니다.', {'at': ['hq_dorm'], 'gil': 1000}, [
        (None, '보미가 허리춤에서 녹슨 열쇠 꾸러미를 풀어 하나를 골라낸다.'),
        ('q:hs_bomi', '자, 이제 당신 방이우. 단청 들보랑 꽃살창은 옛 주인이 남기고 간 걸 닦아 둔 거고.'),
        ('q:hs_bomi', '가구는 안전지대에 있을 때 들이고 옮길 수 있수. 바깥에선 구경만 하고.'),
        ('q:hs_bomi', '손님이 오면 방명록도 받아 보구려. 빈방에 사람 냄새가 나야 집이 살아.'),
        (None, '문을 밀자 마루 냄새가 훅 끼친다. 오래 잠들어 있던 방이 숨을 쉬기 시작한다.')], {'xp': xp - xp // 2}),
]
w(f"""insert into public.world_quest_npcs(npc_key, npc_name, bio) select x.k, x.n, x.b from jsonb_to_recordset({J([dict(k='q:' + k, n=v[0], b=v[1]) for k, v in NPC.items()])}) as x(k text, n text, b text)
on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active)
values ('hs_byeolchae', 'side', '생활·별채', '객사 별채', '본부 객사 뒤뜰의 빈 별채를 손봐 내 방으로 삼는다. (주 이야기 4장을 마친 뒤 Lv15부터)', 'hq_dorm', 15, array['mq_frost_seal'], null, 950, '[]'::jsonb, true)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward)
select 'hs_byeolchae', x.step, x.title, x.goal, x.need, x.lines, x.reward from jsonb_to_recordset({J([dict(step=i + 1, title=t, goal=g, need=n, lines=[{'s': s, 't': tx} for s, tx in ls], reward=r) for i, (t, g, n, ls, r) in enumerate(STEPS)])})
  as x(step int, title text, goal text, need jsonb, lines jsonb, reward jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
""")

if os.path.exists(os.path.join(HERE, 'p_pets.sql')):
    import pets_data
    pets_data.emit(w, J, node_dump)
# 기본 세트를 늘 파는 품목에(꼬마 동무 조각이 pet_food를 넣은 뒤라 그 뒤에 잇는다)
w("select pg_temp.yh_patch('public.world_shop_refresh(text)', '''pet_food''];', '''pet_food'', " + ', '.join("''" + d['item_id'] + "''" for d in default_shop) + "];');")
if os.path.exists(os.path.join(HERE, 'x_misc.sql')):
    part('x_misc.sql')
part('s_expskill.sql')
part('patch_note.sql')
w("""
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261103000000', now())
  on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
""")
print('\n'.join(out))
