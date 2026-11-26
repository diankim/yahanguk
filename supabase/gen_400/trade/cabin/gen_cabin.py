import json
import math
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))

FIELD_PLACE = {'carpentry': '구름나루', 'weaving': '철벽 고찰', 'smithing': '잔불촌'}

RECIPES = {
    'cb_hammock': ('weaving', 10, {'river_reed': 4, 'cloud_cotton': 2, 'lumber': 2}),
    'cb_captain_desk': ('carpentry', 20, {'reinforced_lumber': 2, 'lacquer': 2, 'iron_ingot': 1}),
    'cb_chart_table': ('carpentry', 10, {'lumber': 3, 'fine_paper': 1}),
    'cb_compass_stand': ('smithing', 20, {'iron_ingot': 2, 'spirit_glass': 1, 'lumber': 1}),
    'cb_water_cask': ('carpentry', 10, {'wood': 4, 'raw_iron': 1}),
    'cb_wine_barrel': ('carpentry', 10, {'lumber': 2, 'iron_ingot': 1, 'resin': 1}),
    'cb_cargo_crate': ('carpentry', 10, {'wood': 5, 'resin': 1}),
    'cb_janggi': ('carpentry', 10, {'lumber': 2, 'lacquer': 1}),
    'cb_net_pile': ('weaving', 10, {'river_reed': 5}),
    'cb_porthole': ('smithing', 10, {'iron_ingot': 2, 'spirit_glass': 1}),
    'cb_ship_lamp': ('smithing', 10, {'iron_ingot': 1, 'lantern_oil': 1, 'charcoal': 1}),
    'cb_anchor_rack': ('smithing', 20, {'steel_ingot': 1, 'iron_ingot': 2}),
    'cb_sailcloth': ('weaving', 10, {'cloud_cotton': 2, 'river_reed': 3}),
    'cb_deck': ('carpentry', 10, {'lumber': 3, 'resin': 1}),
}
REWARD_PRICE = {3: 300, 4: 800}

RULES = {
    'name': '객실',
    'small': '나룻배에는 객실이 없습니다. 거룻배부터 객실이 생깁니다.',
    'cap': {'4': 8, '5': 12, '6': 15, '7': 20},
    'default': {'paper': 'cb_sailcloth', 'ground': 'cb_deck'},
    'fit': {'no_cat': ['창문', '문', '들보', '병풍', '정원', '계단', '현판', '어항', '화로'], 'no_wall': ['window', 'door'],
            'floor_cells': 4, 'wall_w': 2, 'wall_h': 40},
    'sources': {
        'cross': {'key': 'cabin_cross', 'note': '첫 바다 건너기', 'items': ['hf_cb_helm']},
        'raid': {'key': 'cabin_raid', 'note': '뱃길 습격 전리품', 'p': 0.05, 'items': {'hf_cb_fish_mount': 1, 'hf_cb_anchor_rack': 1}},
    },
    'craft': FIELD_PLACE,
}


def furn():
    js = """const F = await import('./assets/js/housing/furniture.js');
const o = {};
for (const [k, f] of Object.entries(F.FUR)) if (f.ship) o[k] = { t: 'floor', name: f.name, grade: f.grade, W: f.W, D: f.D, layer: f.layer || 'floor', cat: f.cat, top: f.top || 0, pet: f.pet || null };
for (const [k, f] of Object.entries(F.WALL)) if (f.ship) o[k] = { t: 'wall', name: f.name, grade: f.grade, kind: f.kind, w: f.w, h: f.h, cat: f.cat };
for (const [k, f] of Object.entries(F.PAPER)) if (f.ship) o[k] = { t: 'paper', name: f.name, grade: f.grade };
for (const [k, f] of Object.entries(F.GROUND)) if (f.ship) o[k] = { t: 'ground', name: f.name, grade: f.grade };
console.log(JSON.stringify(o));"""
    return json.loads(subprocess.check_output(['node', '--input-type=module', '-e', js], cwd=ROOT))


def iid(k, f):
    return {'paper': 'hp_', 'ground': 'hg_'}.get(f['t'], 'hf_') + k


def traits(k, f):
    if f['t'] == 'wall':
        t = {'hk': k, 'kind': 'wall', 'wall': f['kind'], 'ww': round(f['w'], 4), 'wh': f['h'], 'cat': f['cat'], 'grade': f['grade']}
    elif f['t'] == 'paper':
        t = {'hk': k, 'kind': 'paper', 'cat': '벽지', 'grade': f['grade']}
    elif f['t'] == 'ground':
        t = {'hk': k, 'kind': 'ground', 'cat': '바닥재', 'grade': f['grade']}
    else:
        t = {'hk': k, 'kind': f['layer'], 'w': f['W'], 'd': f['D'], 'top': f['top'], 'cat': f['cat'], 'grade': f['grade']}
        if f['pet']:
            t['pet'] = f['pet']
    t['ship_only'] = True
    return t


def parts(J, known, errors):
    F = furn()
    out = [open(os.path.join(HERE, 'a_layout.sql')).read()]
    out.append(f"""create or replace function public.world_cabin_rules() returns jsonb language sql immutable set search_path to 'pg_catalog', 'public' as $f$ select {J(RULES)} $f$;
select pg_temp.yh_cb_share('public.world_cabin_rules()');
grant execute on function public.world_cabin_rules() to authenticated;""")
    out.append(open(os.path.join(HERE, 'b_cabin.sql')).read())
    reward = set(RULES['sources']['cross']['items']) | set(RULES['sources']['raid']['items'])
    for k in RECIPES:
        if k not in F:
            errors.append(f'객실 가구 그림 없음(cabin_furn.js): {k}')
    for i in reward:
        if i[3:] not in F:
            errors.append(f'객실 보상 가구 그림 없음: {i}')
    for k, f in F.items():
        if k not in RECIPES and iid(k, f) not in reward:
            errors.append(f'객실 가구 얻는 곳 없음: {k}')
    for k, (fld, lv, mats) in RECIPES.items():
        for m in mats:
            if m not in known:
                errors.append(f'객실 가구 재료 물품 없음: {k} {m}')
    for k in (RULES['default']['paper'], RULES['default']['ground']):
        if k not in F:
            errors.append(f'객실 기본 벽지·바닥재 없음: {k}')
    items, recipes = [], []
    for k, f in F.items():
        crafted = k in RECIPES
        g = f['grade']
        where = '조선소 제작' if crafted else ('첫 바다 건너기' if iid(k, f) in RULES['sources']['cross']['items'] else '뱃길 습격 전리품')
        desc = f"배 객실 전용 가구 · {traits(k, f)['cat']}. {where}(으)로 얻습니다. 별채에는 놓을 수 없고 배 객실(거룻배부터)에만 놓습니다. 거두면 곳간으로 갑니다."
        items.append(dict(item_id=iid(k, f), item_name=f['name'], category='furniture', tier=g, description=desc, stackable=False, required_stats={}, minimum_level=1,
                          rarity={1: 'common', 2: 'uncommon', 3: 'rare', 4: 'epic'}.get(g, 'legendary'), acquisition_difficulty=g, drop_rate_modifier=1,
                          equipment_traits=traits(k, f), tradeable=crafted, reference_price=REWARD_PRICE.get(g, 300) if not crafted else 1, stack_size=1))
        if crafted:
            fld, lv, mats = RECIPES[k]
            recipes.append(dict(recipe_id='r_' + iid(k, f), recipe_name=f['name'] + ' 만들기', output_item=iid(k, f), output_qty=1, ingredients=mats, required_tool_tier=1,
                                required_location=FIELD_PLACE[fld], description=f"배 객실에 놓을 {f['name']}을(를) 짓는다. {FIELD_PLACE[fld]} 조선소에서 지으면 품질이 오른다.",
                                minimum_level=lv, recipe_difficulty=min(3, g), quality_bonus=0, required_skill=None, required_skill_rank=1, craft_field=fld))
    ic = [('item_id', 'text'), ('item_name', 'text'), ('category', 'text'), ('tier', 'int'), ('description', 'text'), ('stackable', 'boolean'), ('required_stats', 'jsonb'),
          ('minimum_level', 'int'), ('rarity', 'text'), ('acquisition_difficulty', 'int'), ('drop_rate_modifier', 'numeric'), ('equipment_traits', 'jsonb'),
          ('tradeable', 'boolean'), ('reference_price', 'bigint'), ('stack_size', 'int')]
    rc = [('recipe_id', 'text'), ('recipe_name', 'text'), ('output_item', 'text'), ('output_qty', 'int'), ('ingredients', 'jsonb'), ('required_tool_tier', 'int'),
          ('required_location', 'text'), ('description', 'text'), ('minimum_level', 'int'), ('recipe_difficulty', 'int'), ('quality_bonus', 'int'), ('required_skill', 'text'),
          ('required_skill_rank', 'int'), ('craft_field', 'text')]
    return out, items, ic, recipes, rc


def sql(J, known, errors):
    out, items, ic, recipes, rc = parts(J, known, errors)
    cols = lambda cs: ', '.join(c for c, _ in cs)
    typed = lambda cs: ', '.join(c + ' ' + t for c, t in cs)
    out.append(f"""insert into public.world_item_catalog({cols(ic)})
select {', '.join('x.' + c for c, _ in ic)} from jsonb_to_recordset({J(items)}) as x({typed(ic)})
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, stack_size = 1;""")
    out.append(f"""insert into public.world_crafting_recipes({cols(rc)})
select {', '.join('x.' + c for c, _ in rc)} from jsonb_to_recordset({J(recipes)}) as x({typed(rc)})
on conflict (recipe_id) do update set recipe_name = excluded.recipe_name, output_item = excluded.output_item, ingredients = excluded.ingredients, minimum_level = excluded.minimum_level,
  required_location = excluded.required_location, craft_field = excluded.craft_field, description = excluded.description, recipe_difficulty = excluded.recipe_difficulty;""")
    out.append(f"""update public.world_item_catalog i set reference_price = ceil(1.1 * (select sum(c.reference_price * e.v::int) from public.world_crafting_recipes r,
  jsonb_each_text(r.ingredients) e(k, v) join public.world_item_catalog c on c.item_id = e.k where r.recipe_id = 'r_' || i.item_id))
 where i.item_id in (select output_item from public.world_crafting_recipes where recipe_id = any (array(select 'r_' || x from jsonb_array_elements_text({J([i['item_id'] for i in items if i['tradeable']])}) x)));
update public.world_item_catalog i set reference_price = x.p from jsonb_to_recordset({J([dict(id=i['item_id'], p=i['reference_price']) for i in items if not i['tradeable']])}) as x(id text, p int)
 where i.item_id = x.id;""")
    src = [(RULES['sources']['cross']['key'], i, 1) for i in RULES['sources']['cross']['items']]
    src += [(RULES['sources']['raid']['key'], i, w) for i, w in RULES['sources']['raid']['items'].items()]
    out.append(f"""delete from public.world_furniture_sources where source in ({', '.join(repr(s) for s in sorted({s for s, _, _ in src}))});
insert into public.world_furniture_sources(source, item_id, chance) select x.s, x.i, x.c from jsonb_to_recordset({J([dict(s=s, i=i, c=c) for s, i, c in src])}) as x(s text, i text, c numeric);
update public.world_item_catalog set equipment_traits = equipment_traits where category = 'furniture';
do $c$ begin
  if (select count(*) from public.world_item_catalog where category = 'furniture' and (equipment_traits ->> 'ship_only')::boolean) <> {len(items)} then raise exception '객실 가구 물품 수가 맞지 않습니다'; end if;
  if exists (select 1 from public.world_item_catalog where category = 'furniture' and (equipment_traits ->> 'ship_only')::boolean and not coalesce((equipment_traits ->> 'cabin')::boolean, false)) then
    raise exception '객실 전용 가구에 객실 표시가 빠졌습니다'; end if;
end $c$;""")
    return '\n\n'.join(out)
