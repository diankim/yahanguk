"""7.1 SQL 생성기: python3 supabase/gen71/gen.py > supabase/migrations/20261102000000_world_7_1_0.sql
조각: a_basic.sql(방어구·능력치 분배·생활 칸) → 생활 장비(data_life.py) → b_life.sql(생활 장비 규칙) → …"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import data_life as L

J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + '$J$::jsonb'
out = []
w = out.append
part = lambda f: w(open(os.path.join(HERE, f)).read())

w("""-- 7.1.0: 방어구 짝 능력치 · 능력치 나눠 두고 확정 · 생활 칸 셋 · 생활 장비 Lv40까지 · …
-- 생성기: supabase/gen71/gen.py (손으로 고치지 말고 생성기를 고친 뒤 다시 만든다)
lock table public.world_characters in access exclusive mode;
""")
part('_patch_fn.sql')
part('a_basic.sql')

# ─── B. 생활 장비 ───
w("""
-- ─────────────────────────────────────────────────────────────
-- B. 생활 장비 Lv40까지(채집·탐사·낚시·제작 공구 32가지)
-- ─────────────────────────────────────────────────────────────""")
price = L.priced()
items, recipes, lines = [], [], []
for (i, name, line, tier, lv, tr, req, ing, loc, field, desc) in L.ITEMS:
    iid = 'lt_' + i
    t = dict(tr); t.setdefault('trait', '정밀 채집')
    if req: t['req_line'], t['req_rank'] = req
    items.append(dict(item_id=iid, item_name=name, tier=tier, description=desc, minimum_level=lv, equipment_traits=t, reference_price=price[i]))
    recipes.append(dict(recipe_id='r_' + iid, recipe_name=name + ' 만들기', output_item=iid, ingredients=ing, required_location=loc, minimum_level=lv,
                        recipe_difficulty=tier, craft_field=field, description=desc.split('.')[0] + '.'))
    lines.append(dict(item_id=iid, line=line))
for i, line, *_ in L.EXISTING:
    lines.append(dict(item_id=i, line=line))
w(f"""insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
select x.item_id, x.item_name, 'tool', x.tier, x.description, false, '{{}}'::jsonb, x.minimum_level, x.equipment_traits, true, x.reference_price, 1
  from jsonb_to_recordset({J(items)}) as x(item_id text, item_name text, tier int, description text, minimum_level int, equipment_traits jsonb, reference_price int)
on conflict (item_id) do update set item_name = excluded.item_name, tier = excluded.tier, description = excluded.description, minimum_level = excluded.minimum_level,
  equipment_traits = excluded.equipment_traits, reference_price = excluded.reference_price;
insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, required_skill, required_skill_rank, craft_field)
select x.recipe_id, x.recipe_name, x.output_item, 1, x.ingredients, null, 1, x.required_location, x.description, x.minimum_level, null, x.recipe_difficulty, null, 1, x.craft_field
  from jsonb_to_recordset({J(recipes)}) as x(recipe_id text, recipe_name text, output_item text, ingredients jsonb, required_location text, description text, minimum_level int, recipe_difficulty int, craft_field text)
on conflict (recipe_id) do update set ingredients = excluded.ingredients, required_location = excluded.required_location, minimum_level = excluded.minimum_level,
  recipe_difficulty = excluded.recipe_difficulty, craft_field = excluded.craft_field, description = excluded.description;
insert into public.world_tool_lines(item_id, line) select x.item_id, x.line from jsonb_to_recordset({J(lines)}) as x(item_id text, line text)
on conflict do nothing;""")
for i, t in L.RETRAIT.items():
    w(f"update public.world_item_catalog set equipment_traits = equipment_traits || {J(t)} where item_id = '{i}';")
part('b_life.sql')

w("""
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261102000000', now())
  on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
""")
print('\n'.join(out))
