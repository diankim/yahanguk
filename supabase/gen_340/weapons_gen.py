import json, os, subprocess, sys
from weapon_plan import FORMS, LINES

HERE = os.path.dirname(os.path.abspath(__file__))
DSN = os.environ.get('YH_DSN', '-h /var/tmp/yhpg -p 5499 -U postgres -d yh_330').split()
ALL_JOBS = ['artificer', 'scout', 'exorcist', 'medic', 'sealmaster', 'analyst', 'tamer', 'bloodknight', 'spearman', 'formation']
P = [6, 12, 20, 28, 38, 48, 58, 66]
SUB = {
    'base': lambda t: {'combat_damage_pct': [3, 5, 5, 10, 15, 18, 22, 24][t]},
    'heavy': lambda t: {'presence': [6, 12, 18, 24, 30, 36, 42, 46][t], 'incoming_damage_pct': -[1, 2, 3, 5, 7, 9, 11, 12][t]},
    'keen': lambda t: {'crit_pct': [4, 8, 12, 16, 20, 24, 29, 32][t]},
    'silent': lambda t: {'evasion_pct': [1.5, 3, 4.5, 6, 7.5, 9, 11, 12][t], 'presence': -[6, 12, 18, 24, 30, 36, 42, 46][t]},
}
LINE_OF = lambda s: ''.join(ch for ch in s if not ch.isdigit())
FIELD = {'등패와 환도': 'smithing', '등패와 철퇴': 'smithing', '도끼': 'smithing', '대검': 'smithing', '단도': 'smithing', '수리검': 'smithing',
         '언월도': 'smithing', '장창': 'smithing', '각궁': 'carpentry', '쇠뇌': 'carpentry', '단궁': 'carpentry', '취관': 'carpentry',
         '방울': 'artifice', '법경': 'artifice', '금강령': 'artifice', '사슬': 'artifice', '부채': 'carpentry', '침통': 'artifice',
         '산가지': 'carpentry', '나경': 'artifice'}
FLAVOR = {
    '등패와 환도': '등나무 방패와 환도를 한 벌로 든다', '등패와 철퇴': '등나무 방패와 철퇴를 한 벌로 든다',
    '도끼': '큰 도끼를 휘둘러 베어 낸다', '대검': '두 손으로 드는 큰 칼', '단도': '짧은 칼로 급소를 찌른다',
    '수리검': '던지는 칼날을 품에 지닌다', '언월도': '긴 자루에 반달 날을 단 칼', '장창': '긴 창으로 먼저 찌른다',
    '각궁': '뿔과 힘줄로 만든 활', '쇠뇌': '틀에 걸어 쏘는 활(편전을 쓴다)', '단궁': '짧고 가벼운 활', '취관': '대롱으로 불어 쏜다(편전을 쓴다)',
    '방울': '흔들어 요기를 흩는 방울', '법경': '요괴를 비추는 거울', '금강령': '울려 기운을 묶는 금강령', '사슬': '봉인 부적을 꿴 사슬',
    '부채': '술식을 그린 부채', '침통': '침과 약을 넣은 통', '산가지': '셈을 놓는 산가지', '나경': '방위를 읽는 나경',
}
SUBTXT = {'base': '주는 피해가 오른다', 'heavy': '이목을 끌고 받는 피해를 줄인다', 'keen': '치명타가 잘 난다', 'silent': '눈에 덜 띄고 잘 피한다'}
TRAIT = {'melee': '근접', 'ranged': '원거리', 'magic': '술법'}
TEMPLATE_BASE = {('melee', 0): 'iron_sword', ('melee', 1): 'moon_blade', ('melee', 2): 'thunder_glaive',
                 ('ranged', 0): 'short_bow', ('ranged', 1): 'reed_crossbow', ('ranged', 2): 'star_bow',
                 ('magic', 0): 'spirit_bell', ('magic', 1): 'ward_fan', ('magic', 2): 'star_mirror'}
MZ = ['w_melee_mz', 'w_ranged_mz', 'w_magic_mz', 'w_melee_mzl', 'w_ranged_mzl', 'w_magic_mzl']
NEW_ID = {'artificer': 'guard', 'bloodknight': 'blood', 'analyst': 'shadow', 'spearman': 'spear', 'scout': 'scout', 'tamer': 'tamer',
          'exorcist': 'exo', 'sealmaster': 'seal', 'medic': 'medic', 'formation': 'form'}


def q(sql):
    out = subprocess.run(['psql', *DSN, '-At', '-c', sql], capture_output=True, text=True)
    if out.returncode:
        sys.exit(out.stderr)
    return out.stdout


def T(s):
    return 'null' if s is None else "'" + str(s).replace("'", "''") + "'"


def J(o):
    return T(json.dumps(o, ensure_ascii=False)) + '::jsonb'


cat = {r['item_id']: r for r in (json.loads(x) for x in q("select to_jsonb(i) from world_item_catalog i where category='weapon'").splitlines())}
rec = {r['output_item']: r for r in (json.loads(x) for x in q("select to_jsonb(r) from world_crafting_recipes r join world_item_catalog i on i.item_id = r.output_item where i.category='weapon'").splitlines())}
drops = {}
for x in q("select to_jsonb(g) from world_gear_drops g join world_item_catalog i on i.item_id = g.item_id where i.category='weapon'").splitlines():
    r = json.loads(x)
    drops.setdefault(r['item_id'], []).append(r)


def template(wt, line, t):
    v = LINE_OF(line)
    if v == 'base' and t < 3:
        return TEMPLATE_BASE[(wt, t)]
    return f'w_{wt}{t + 1}_{v}'


def traits(wt, line, t, job, keep=None, form=None):
    v = LINE_OF(line)
    tr = {'jobs': [job] if job else ALL_JOBS, 'power': P[t], 'trait': TRAIT[wt], 'weapon_type': wt}
    tr.update(SUB[v](t) if v in SUB else {})
    if wt == 'ranged':
        tr['ammo'] = 'ammo_dart' if form in ('쇠뇌', '취관') else 'ammo_arrow'
    if keep:
        tr.update({k: v2 for k, v2 in keep.items() if k.startswith('mz_') or k in ('look', 'hk')})
    return tr


sql = []
w = sql.append
w("update public.world_item_catalog set item_name = '편전', description = '쇠뇌와 취관에 재는 짧은 살. 통아(대롱)에 넣어 쏘거나 불어 쏜다. 쇠뇌·취관으로 공격할 때마다 하나씩 쓴다.' where item_id = 'ammo_dart';")
w("update public.world_crafting_recipes set recipe_name = '편전 만들기', description = '편전을(를) 만든다.' where output_item = 'ammo_dart';")
moved_ids, new_rows, plan = [], [], []
for (job, k), cells in LINES.items():
    form, wt, line = FORMS[job][k]
    for t, cell in enumerate(cells):
        for part in cell.split('|'):
            if part.startswith('+'):
                name = part[1:]
                nid = f'w_{NEW_ID[job]}{t + 1}_{"a" if k == 0 else "b"}'
                tpl = template(wt, line, t)
                plan.append(('new', nid, name, job, form, wt, line, t, tpl))
            else:
                iid, name = part.split('=')
                plan.append(('old', iid, name, job, form, wt, line, t, iid))

for kind, iid, name, job, form, wt, line, t, tpl in plan:
    tr = traits(wt, line, t, job, keep=cat[tpl]['equipment_traits'] if kind == 'old' else None, form=form)
    desc = f'{FLAVOR[form]}. {TRAIT[wt]} 공격을 하며 {SUBTXT[LINE_OF(line)]}.'
    if kind == 'old':
        w(f"update public.world_item_catalog set item_name = {T(name)}, description = {T(desc)}, equipment_traits = {J(tr)} where item_id = {T(iid)};")
        w(f"update public.world_crafting_recipes set recipe_name = {T(name + ' 만들기')}, description = {T(name + '을(를) 만든다.')} where output_item = {T(iid)};")
        continue
    src = cat[tpl]
    cols = ['item_id', 'item_name', 'category', 'tier', 'rarity', 'description', 'stackable', 'tradeable', 'reference_price', 'stack_size',
            'minimum_level', 'required_stats', 'required_job', 'required_faction', 'equipment_traits', 'drop_rate_modifier', 'acquisition_difficulty',
            'crafting_specialization', 'market_only', 'quality_grade', 'base_item_id']
    vals = {**src, 'item_id': iid, 'item_name': name, 'description': desc, 'equipment_traits': tr, 'base_item_id': None, 'quality_grade': 0}
    def V(c):
        x = vals.get(c)
        if c in ('required_stats', 'equipment_traits'):
            return J(x) if x is not None else 'null'
        if isinstance(x, bool):
            return 'true' if x else 'false'
        if isinstance(x, (int, float)):
            return str(x)
        return T(x)
    w(f"insert into public.world_item_catalog({', '.join(cols)}) values ({', '.join(V(c) for c in cols)}) on conflict (item_id) do nothing;")
    r = rec.get(tpl) or next((rec[i] for i in rec if cat[i]['tier'] == src['tier'] and cat[i]['equipment_traits'].get('weapon_type') == wt), None)
    if r:
        w(f"insert into public.world_crafting_recipes(recipe_id, recipe_name, description, output_item, output_qty, ingredients, craft_field, minimum_level, required_location, required_tool, required_tool_tier, required_skill, required_skill_rank, required_job, recipe_difficulty, quality_bonus) values "
          f"({T('r_' + iid)}, {T(name + ' 만들기')}, {T(name + '을(를) 만든다.')}, {T(iid)}, {r['output_qty']}, {J(r['ingredients'])}, {T(FIELD[form])}, {r['minimum_level']}, {T(r['required_location'])}, {T(r['required_tool'])}, {r['required_tool_tier'] if r['required_tool_tier'] is not None else 'null'}, {T(r['required_skill'])}, {r['required_skill_rank'] if r['required_skill_rank'] is not None else 'null'}, null, {r['recipe_difficulty']}, {r['quality_bonus']}) on conflict (recipe_id) do nothing;")
        new_rows.append(iid)
    for g in drops.get(tpl, []):
        w(f"insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values ({T(iid)}, {T(g['mechanic_key'])}, {g['level_min']}, {g['level_max']}, {g['chance_normal']}, {g['chance_elite']}, {g['chance_guardian']});")

for iid in MZ:
    src = cat[iid]
    t = src['tier'] - 1
    tr = dict(src['equipment_traits'])
    tr['jobs'] = ALL_JOBS
    tr['power'] = P[t]
    w(f"update public.world_item_catalog set equipment_traits = {J(tr)} where item_id = {T(iid)};")

ids = [p[1] for p in plan if p[0] == 'new' and p[1] in new_rows]
w("set local yh.hq_sync = 'off';")
w(f"""insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, required_job, required_faction, equipment_traits, drop_rate_modifier, acquisition_difficulty, crafting_specialization, market_only, quality_grade, base_item_id)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.rarity, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.minimum_level, i.required_stats, i.required_job, i.required_faction, public.world_item_hq_traits(i.equipment_traits), i.drop_rate_modifier, i.acquisition_difficulty, i.crafting_specialization, i.market_only, 1, i.item_id
  from public.world_item_catalog i where i.item_id = any(array[{', '.join(T(x) for x in ids)}]) on conflict (item_id) do nothing;""")
w("set local yh.hq_sync = 'on';")
open(os.path.join(HERE, 'sql', 'a_weapons.sql'), 'w').write('\n'.join(sql) + '\n')
json.dump([p[:9] for p in plan], open(os.path.join(HERE, 'sql', 'weapon_map.json'), 'w'), ensure_ascii=False)
print(len(plan), len(ids))
