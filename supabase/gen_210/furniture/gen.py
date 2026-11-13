import json
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
VER = '20261117050000'
OUT = os.path.join(ROOT, 'supabase', 'migrations', f'{VER}_world_2_1_0_furniture.sql')
J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + '$J$::jsonb'
RARITY = {1: 'common', 2: 'uncommon', 3: 'rare', 4: 'epic', 5: 'legendary'}

F = json.loads(subprocess.check_output(['node', '--input-type=module', '-e', """
const F = await import('./assets/js/housing/furniture.js');
const o = {};
for (const [k, f] of Object.entries(F.FUR)) o[k] = { t: 'floor', name: f.name, grade: f.grade, W: f.W, D: f.D, layer: f.layer, cat: f.cat, top: f.top || 0, pet: f.pet || null };
for (const [k, f] of Object.entries(F.WALL)) o[k] = { t: 'wall', name: f.name, grade: f.grade, kind: f.kind, w: f.w, h: f.h, cat: f.cat };
console.log(JSON.stringify(o));
"""], cwd=ROOT))

MZ = [
    ('mz_forge_brazier', 'smithing', {'mz_stone_j': 2, 'mz_stone': 4, 'iron_ingot': 6}),
    ('mz_mother_chest', 'carpentry', {'mz_wood_j': 2, 'mz_wood': 4, 'lacquer': 6}),
    ('mz_window_screen', 'artifice', {'mz_wood_j': 1, 'mz_stone_j': 1, 'mz_wood': 3, 'moonless_silk': 2}),
    ('mz_seal_censer', 'sealing', {'mz_herb_j': 1, 'mz_stone_j': 1, 'mz_stone': 3, 'inverted_incense': 2}),
    ('mz_herb_blind', 'weaving', {'mz_herb_j': 2, 'mz_herb': 4, 'moonless_silk': 2}),
    ('mz_stone_hide_mat', 'leatherwork', {'mz_stone_j': 2, 'mz_stone': 3, 'reinforced_leather': 3}),
    ('mz_herb_cabinet', 'alchemy', {'mz_herb_j': 2, 'mz_wood': 3, 'lacquer': 4}),
    ('mz_tea_table', 'cooking', {'mz_herb_j': 2, 'mz_wood': 3, 'mz_herb': 3}),
]
BJ = ['bj_name_chest', 'bj_vault_gate', 'bj_map_frame']
RANK, LV = 40, 38


def traits(k):
    f = F[k]
    if f['t'] == 'wall':
        return {'hk': k, 'kind': 'wall', 'wall': f['kind'], 'ww': f['w'], 'wh': f['h'], 'cat': f['cat'], 'grade': f['grade']}
    t = {'hk': k, 'kind': 'rug' if f['layer'] == 'rug' else 'floor', 'w': f['W'], 'd': f['D'], 'top': f['top'], 'cat': f['cat'], 'grade': f['grade']}
    if f['pet']:
        t['pet'] = f['pet']
    return t


def item(k, tradeable, desc):
    f = F[k]
    return dict(item_id='hf_' + k, item_name=f['name'], category='furniture', tier=f['grade'], description=desc, stackable=False, required_stats={},
                minimum_level=1, rarity=RARITY[f['grade']], acquisition_difficulty=f['grade'], drop_rate_modifier=1, equipment_traits=traits(k),
                tradeable=tradeable, reference_price=2400, stack_size=1)


items = [item(k, True, f"명장 가구 · {F[k]['cat']}. 명소 재료로 짓는 별채 가구입니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.") for k, _, _ in MZ]
items += [item(k, False, f"비장고 가구 · {F[k]['cat']}. 비장고 마지막 방에서만 나옵니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.") for k in BJ]
recipes = [dict(recipe_id='r_hf_' + k, recipe_name=F[k]['name'] + ' 만들기', output_item='hf_' + k, output_qty=1, ingredients=m, required_tool_tier=1,
                required_location=None, description=f"별채에 놓을 {F[k]['name']}을(를) 짓는다. 명장 제작법({RANK}단계).", minimum_level=LV, recipe_difficulty=5,
                quality_bonus=0, required_skill=field, required_skill_rank=RANK, craft_field=field) for k, field, m in MZ]

ICOLS = [('item_id', 'text'), ('item_name', 'text'), ('category', 'text'), ('tier', 'int'), ('description', 'text'), ('stackable', 'boolean'),
         ('required_stats', 'jsonb'), ('minimum_level', 'int'), ('rarity', 'text'), ('acquisition_difficulty', 'int'), ('drop_rate_modifier', 'numeric'),
         ('equipment_traits', 'jsonb'), ('tradeable', 'boolean'), ('reference_price', 'bigint'), ('stack_size', 'int')]
RCOLS = [('recipe_id', 'text'), ('recipe_name', 'text'), ('output_item', 'text'), ('output_qty', 'int'), ('ingredients', 'jsonb'), ('required_tool_tier', 'int'),
         ('required_location', 'text'), ('description', 'text'), ('minimum_level', 'int'), ('recipe_difficulty', 'int'), ('quality_bonus', 'int'),
         ('required_skill', 'text'), ('required_skill_rank', 'int'), ('craft_field', 'text')]
ic, rc = [c for c, _ in ICOLS], [c for c, _ in RCOLS]
w = []
w.append(f"""insert into public.world_item_catalog({', '.join(ic)})
select {', '.join('x.' + c for c in ic)} from jsonb_to_recordset({J(items)}) as x({', '.join(c + ' ' + t for c, t in ICOLS)})
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, stack_size = excluded.stack_size;""")
w.append(f"""insert into public.world_crafting_recipes({', '.join(rc)})
select {', '.join('x.' + c for c in rc)} from jsonb_to_recordset({J(recipes)}) as x({', '.join(c + ' ' + t for c, t in RCOLS)})
on conflict (recipe_id) do update set recipe_name = excluded.recipe_name, output_item = excluded.output_item, ingredients = excluded.ingredients,
  minimum_level = excluded.minimum_level, required_skill = excluded.required_skill, required_skill_rank = excluded.required_skill_rank, craft_field = excluded.craft_field,
  description = excluded.description, recipe_difficulty = excluded.recipe_difficulty;""")
w.append("""update public.world_item_catalog i set reference_price = greatest(2400, ceil(1.1 * (select sum(c.reference_price * v::int) from public.world_crafting_recipes r,
  jsonb_each_text(r.ingredients) e(k, v) join public.world_item_catalog c on c.item_id = e.k where r.output_item = i.item_id)))
 where i.item_id in (select output_item from public.world_crafting_recipes where recipe_id like 'r\\_hf\\_mz\\_%');""")
w.append(f"""update public.world_item_catalog i set reference_price = 4000 where i.item_id in (select 'hf_' || x from jsonb_array_elements_text({J(BJ)}) x);""")
w.append(f"do $c$ begin if (select count(*) from public.world_item_catalog where item_id like 'hf\\_mz\\_%' or item_id like 'hf\\_bj\\_%') <> {len(items)} then raise exception '가구 물품 수가 맞지 않습니다'; end if; end $c$;")
w.append(f"update public.world_app_meta set value = '{VER}' where key = 'db_version';")
open(OUT, 'w', encoding='utf-8').write('\n\n'.join(w) + '\n')
print(OUT, len(items), len(recipes))
