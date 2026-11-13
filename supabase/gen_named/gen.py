import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import data as D

J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + '$J$::jsonb'
out = []
w = out.append
RARITY = {1: 'common', 2: 'uncommon', 3: 'rare', 4: 'epic', 5: 'legendary'}


def fx_full(fx):
    base = {'er': 0, 'hp': 0, 'mn': 0, 'sp': 0, 'stam': 0, 'buffs': [], 'cures': []}
    base.update(fx or {})
    return base


def item(iid, nm, cat, tier, desc, stack, price, tradeable, traits=None, fx=None):
    return dict(item_id=iid, item_name=nm, category=cat, tier=tier, description=desc, stackable=stack > 1, required_stats={}, minimum_level=1,
                rarity=RARITY[tier], acquisition_difficulty=min(5, tier), drop_rate_modifier=1, equipment_traits=traits or {}, tradeable=tradeable,
                reference_price=price, stack_size=stack, use_fx=fx_full(fx) if fx is not None else None)


def recipe(rid, nm, output, qty, mats, field, lv, desc, diff):
    return dict(recipe_id=rid, recipe_name=nm, output_item=output, output_qty=qty, ingredients=mats, required_tool_tier=1, required_location=None,
                description=desc, minimum_level=lv, recipe_difficulty=diff, quality_bonus=0, required_skill_rank=1, craft_field=field)


FUR = json.loads(subprocess.check_output(['node', '--input-type=module', '-e', """
const F = await import('./assets/js/housing/furniture.js');
const o = {};
for (const [k, f] of Object.entries(F.WALL)) o[k] = { name: f.name, grade: f.grade, kind: f.kind, w: f.w, h: f.h, cat: f.cat };
console.log(JSON.stringify(o));
"""], cwd=ROOT))

items, recipes, hq, fish, titles = [], [], [], [], []
baits = {}
for k, n in enumerate(D.NAMED):
    price = max(300, round(1500 * n['lv'] / 40 / 10) * 10)
    items.append(item(n['id'], n['name'], 'material', 5, '이름을 지킨 물고기, 명어(名魚). ' + n['desc'], 40, price, False))
    fid, fname, field, extra, fx, fdesc = n['food']
    tier = 3 if n['lv'] < 20 else 4
    items.append(item(fid, fname, 'consumable', tier, fdesc, 20, round(price * 0.9 / 10) * 10, False, fx=fx))
    hq.append(fid)
    recipes.append(recipe('r_' + fid, fname + ' 만들기', fid, 2, dict({n['id']: 1}, **extra), field, n['lv'], fname + '을(를) 만든다.', min(4, 1 + n['lv'] // 10)))
    rk = 'rubbing_' + n['id']
    f = FUR[rk]
    tr = {'hk': rk, 'kind': 'wall', 'wall': f['kind'], 'ww': f['w'], 'wh': f['h'], 'cat': f['cat'], 'grade': f['grade']}
    items.append(dict(item('hf_' + rk, f['name'], 'furniture', f['grade'], f"별채 가구 · {f['cat']}. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.", 1,
                           {4: 800, 5: 2400}[f['grade']], False, traits=tr), stackable=False))
    recipes.append(recipe('r_hf_' + rk, f['name'] + ' 만들기', 'hf_' + rk, 1, dict({n['id']: 1}, **D.RUBBING_MATS), 'sealing', n['lv'],
                          f"별채에 놓을 {f['name']}을(를) 만든다.", f['grade']))
    fish.append(dict(fish_id=n['id'], fish_name=n['name'], habitat=n['hab'], phase=n['ph'], weather=n['wk'], min_level=n['lv'], size_min=n['size'][0],
                     size_max=n['size'][1], description=n['desc'], ground=n['ground'], n=k + 1))
    for b in n['bait']:
        baits.setdefault(b, []).append(n['id'])
    tk, tn, tg, tb = n['title']
    titles.append(dict(title_key=tk, title_name=tn, grade=tg, bonus=tb, rule={'n': 1, 'p': {'fish': n['id']}, 'ev': 'fish'}, cond=n['name'] + '을(를) 낚는다', hidden=True, n=k + 1))
tk, tn, tg, tb, tc = D.ALL_TITLE
titles.append(dict(title_key=tk, title_name=tn, grade=tg, bonus=tb, rule={'all': [{'p': {'fish': n['id']}, 'ev': 'fish'} for n in D.NAMED]}, cond=tc, hidden=True, n=len(D.NAMED) + 1))
tk, tn, tg, tb, tc = D.EVERY_TITLE
titles.append(dict(title_key=tk, title_name=tn, grade=tg, bonus=tb, rule={'all': [{'p': {'fish': f}, 'ev': 'fish'} for f in D.MUKJEOK_NAMED + [n['id'] for n in D.NAMED]]}, cond=tc, hidden=True, n=len(D.NAMED) + 2))

w("lock table public.world_characters in access exclusive mode;")
w(f"""do $c$ declare d text; begin
  select string_agg(x, ', ') into d from (
    select i.item_name x from public.world_item_catalog i where i.item_name in (select jsonb_array_elements_text({J([i['item_name'] for i in items])})) and i.item_id not in (select jsonb_array_elements_text({J([i['item_id'] for i in items])}))
    union all select s.fish_name from public.world_fish_species s where s.fish_name in (select jsonb_array_elements_text({J([f['fish_name'] for f in fish])})) and s.fish_id not in (select jsonb_array_elements_text({J([f['fish_id'] for f in fish])}))
    union all select t.title_name from public.world_title_catalog t where t.title_name in (select jsonb_array_elements_text({J([t['title_name'] for t in titles])})) and t.title_key not in (select jsonb_array_elements_text({J([t['title_key'] for t in titles])}))
    union all select g.ground_name from public.world_fish_grounds g where false) q;
  if d is not null then raise exception '이름 겹침: %', d; end if;
  if (select count(*) from public.world_fish_grounds g where (g.region_id, g.habitat) in (select x.ground, x.habitat from jsonb_to_recordset({J(fish)}) as x(ground text, habitat text))) <> {len(fish)} then
    raise exception '낚시터가 없는 명어 자리가 있습니다';
  end if;
  if exists (select 1 from jsonb_array_elements_text({J(sorted(baits))}) b where not exists (select 1 from public.world_fish_species s where s.fish_id = b)) then
    raise exception '없는 미끼 물고기가 있습니다';
  end if;
end $c$;""")

ICOLS = [('item_id', 'text'), ('item_name', 'text'), ('category', 'text'), ('tier', 'int'), ('description', 'text'), ('stackable', 'boolean'), ('required_stats', 'jsonb'), ('minimum_level', 'int'),
         ('rarity', 'text'), ('acquisition_difficulty', 'int'), ('drop_rate_modifier', 'numeric'), ('equipment_traits', 'jsonb'), ('tradeable', 'boolean'), ('reference_price', 'bigint'), ('stack_size', 'int'),
         ('use_fx', 'jsonb')]
ins = [c for c, _ in ICOLS]
w(f"""insert into public.world_item_catalog({', '.join(ins)})
select {', '.join('x.' + c for c in ins)} from jsonb_to_recordset({J(items)}) as x({', '.join(c + ' ' + t for c, t in ICOLS)})
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, stack_size = excluded.stack_size, tradeable = excluded.tradeable, reference_price = excluded.reference_price, use_fx = excluded.use_fx;""")
RCOLS = [('recipe_id', 'text'), ('recipe_name', 'text'), ('output_item', 'text'), ('output_qty', 'int'), ('ingredients', 'jsonb'), ('required_tool_tier', 'int'),
         ('required_location', 'text'), ('description', 'text'), ('minimum_level', 'int'), ('recipe_difficulty', 'int'), ('quality_bonus', 'int'), ('required_skill_rank', 'int'), ('craft_field', 'text')]
rins = [c for c, _ in RCOLS]
w(f"""insert into public.world_crafting_recipes({', '.join(rins)})
select {', '.join('x.' + c for c in rins)} from jsonb_to_recordset({J(recipes)}) as x({', '.join(c + ' ' + t for c, t in RCOLS)})
on conflict (recipe_id) do update set recipe_name = excluded.recipe_name, output_item = excluded.output_item, output_qty = excluded.output_qty, ingredients = excluded.ingredients,
  craft_field = excluded.craft_field, minimum_level = excluded.minimum_level, description = excluded.description, recipe_difficulty = excluded.recipe_difficulty;""")
w(f"""update public.world_item_catalog i set reference_price = greatest(i.reference_price,
    ceil(1.1 * (select min(t.v) from (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) v from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id group by cr.recipe_id) t)))
 where i.item_id in (select jsonb_array_elements_text({J([r['output_item'] for r in recipes])}));""")
w(f"""insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
  rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade, use_fx)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable,
  i.required_stats, i.required_job, i.required_faction, i.minimum_level, i.rarity, i.acquisition_difficulty, i.drop_rate_modifier, i.equipment_traits,
  i.crafting_specialization, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.item_id, 1, null
  from public.world_item_catalog i
 where i.item_id in (select jsonb_array_elements_text({J(hq)}))
on conflict (item_id) do nothing;""")
w(f"""insert into public.world_fish_species(fish_id, fish_name, habitat, rarity, min_level, phase, weather, size_min, size_max, description, sort, active, grounds, bait_for, named)
select x.fish_id, x.fish_name, x.habitat, 'legendary', x.min_level, x.phase, x.weather, x.size_min, x.size_max, x.description,
       (select coalesce(max(sort), 0) from public.world_fish_species) + x.n, true, array[x.ground], '{{}}'::text[], true
  from jsonb_to_recordset({J(fish)}) as x(fish_id text, fish_name text, habitat text, min_level int, phase text, weather text, size_min numeric, size_max numeric, description text, ground text, n int)
on conflict (fish_id) do update set fish_name = excluded.fish_name, habitat = excluded.habitat, rarity = excluded.rarity, min_level = excluded.min_level, phase = excluded.phase,
  weather = excluded.weather, size_min = excluded.size_min, size_max = excluded.size_max, description = excluded.description, grounds = excluded.grounds, named = excluded.named;""")
w(f"""update public.world_fish_species s set bait_for = array(select distinct unnest(s.bait_for || array(select jsonb_array_elements_text({J(baits)} -> s.fish_id))) order by 1)
 where s.fish_id in (select jsonb_object_keys({J(baits)}));""")
w("""do $c$ begin
  if exists (select 1 from public.world_fish_species n where n.named and (select count(*) from public.world_fish_species b where n.fish_id = any (b.bait_for) and b.rarity in ('common', 'uncommon', 'rare')) < 3) then
    raise exception '명어마다 미끼가 셋 이상이어야 합니다';
  end if;
end $c$;""")
w(f"""insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, hidden, rule, sort, category, grade)
select x.title_key, x.title_name, x.cond || '.', '숨겨진 조건', x.bonus, x.hidden, x.rule, 150 + x.n, '{D.TITLE_CAT}', x.grade
  from jsonb_to_recordset({J(titles)}) as x(title_key text, title_name text, grade int, bonus jsonb, rule jsonb, cond text, hidden boolean, n int)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus,
  hidden = excluded.hidden, rule = excluded.rule, category = excluded.category, grade = excluded.grade;""")
w(open(os.path.join(HERE, 'patch_note.sql')).read())
w("""select public.world_quest_label_refresh();
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116040000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;""")
print('\n'.join(out))
sys.stderr.write(f"명어 {len(fish)} · 물품 {len(items)}(+우수 {len(hq)}) · 제작법 {len(recipes)} · 칭호 {len(titles)}\n")
