import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..', '..')
sys.path.insert(0, HERE)
import data as D

VER = '20261117020000'
OUT = os.path.join(ROOT, 'supabase', 'migrations', f'{VER}_world_2_1_0_meisho.sql')
J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + '$J$::jsonb'
FIELD_LINE = {'sealing': 'wardcraft'}


def fx_full(fx):
    base = {'er': 0, 'hp': 0, 'mn': 0, 'sp': 0, 'stam': 0, 'buffs': [], 'cures': []}
    base.update(fx or {})
    return base


def item(iid, nm, cat, tier, desc, stack, price, lv=1, traits=None, fx=None, stats=None):
    return dict(item_id=iid, item_name=nm, category=cat, tier=tier, description=desc, stackable=stack > 1, required_stats=stats or {}, minimum_level=lv,
                rarity='legendary', acquisition_difficulty=5, drop_rate_modifier=1, equipment_traits=traits or {}, tradeable=True,
                reference_price=price, stack_size=stack, use_fx=fx_full(fx) if fx is not None else None)


def check(items, errors):
    ref = json.load(open(os.path.join(HERE, 'ref', 'existing_names.json')))
    taken = set(ref['regions']) | set(ref['nodes']) | set(ref['spots']) | set(ref['items']) | set(ref['grounds']) | set(ref['fish_grounds']) | set(ref['sites']) | set(ref['monsters'])
    mine = [m['name'] for m in D.MEISHO] + [i['item_name'] for i in items]
    for n in mine:
        if n in taken: errors.append('이름 겹침: ' + n)
    for n in set(mine):
        if mine.count(n) > 1: errors.append('새 이름끼리 겹침: ' + n)
    for i in items:
        if i['item_id'] in ref['item_ids']: errors.append('물품 id 겹침: ' + i['item_id'])
    for s in D.STATUSES:
        if s[0] in ref['statuses'] or s[1] in ref['status_names']: errors.append('상태 겹침: ' + s[0])
    known = set(ref['item_ids']) | {i['item_id'] for i in items}
    for f, rank, out, qty, mats in D.RECIPES:
        for k in mats:
            if k not in known: errors.append(f'없는 재료 {k} ({out})')
        if out not in known: errors.append('없는 완성품 ' + out)
    fields = {}
    for f, rank, *_ in D.RECIPES: fields.setdefault(f, set()).add(rank)
    for f in ['smithing', 'carpentry', 'artifice', 'sealing', 'weaving', 'leatherwork', 'alchemy', 'cooking']:
        if fields.get(f) != {30, 40, 50}: errors.append('분야마다 30·40·50단계가 하나씩 있어야 함: ' + f)
    used = {k for *_, mats in D.RECIPES for k in mats}
    for iid, *_ in D.MATS:
        if iid not in used: errors.append('제작법에 안 쓰이는 명소 재료: ' + iid)
    kinds = {}
    for m in D.MEISHO: kinds[m['kind']] = kinds.get(m['kind'], 0) + 1
    if kinds != {'herb': 4, 'wood': 4, 'stone': 4}: errors.append(f'갈래마다 넷이어야 함: {kinds}')


def main():
    items = []
    for iid, nm, tier, stack, price, desc in D.MATS:
        items.append(item(iid, nm, 'material', tier, desc, stack, price, 30))
    out_of = {r[2]: r for r in D.RECIPES}
    for g in D.GEAR:
        items.append(item(g['id'], g['name'], g['cat'], 7, g['desc'], 1, 100, D.GEAR_LV[g['cat']], traits=g['traits'], stats=D.GEAR_STATS.get(g['id'])))
    for f in D.FOOD:
        items.append(item(f['id'], f['name'], 'consumable', f['tier'], f['desc'], 20, 100, D.RANK_LV[out_of[f['id']][1]], fx=f['fx']))
    errors = []
    check(items, errors)
    if errors:
        print('\n'.join(errors)); sys.exit(1)
    name_of = {i['item_id']: i['item_name'] for i in items}
    recipes = []
    for f, rank, out, qty, mats in D.RECIPES:
        it = next(i for i in items if i['item_id'] == out)
        recipes.append(dict(recipe_id='r_' + out, recipe_name=name_of[out] + ' 만들기', output_item=out, output_qty=qty, ingredients=mats,
                            required_location='묵창 나루' if it['category'] != 'consumable' else None, description=f"명장의 솜씨로 {name_of[out]}을(를) 만든다.",
                            minimum_level=max(D.RANK_LV[rank], it['minimum_level']), recipe_difficulty=7 if it['category'] != 'consumable' else 4,
                            required_skill=FIELD_LINE.get(f, f), required_skill_rank=rank, craft_field=f))
    gear_ids = [g['id'] for g in D.GEAR]
    food_ids = [f['id'] for f in D.FOOD]
    hq_ids = gear_ids + [f['id'] for f in D.FOOD if f['hq']]
    new_names = [m['name'] for m in D.MEISHO] + [i['item_name'] for i in items]
    new_ids = [i['item_id'] for i in items]
    meisho = [dict(m, sort=k + 1) for k, m in enumerate(D.MEISHO)]
    statuses = [dict(status_key=s[0], status_name=s[1], duration_minutes=s[2], effects=s[3], icon=s[4], description=s[5]) for s in D.STATUSES]
    w = []
    w.append(open(os.path.join(HERE, 'a_head.sql'), encoding='utf-8').read())
    w.append('\n' + open(os.path.join(HERE, 'a_hq.sql'), encoding='utf-8').read())
    w.append(f"""
create or replace function public.world_meisho_rules()
 returns jsonb
 language sql
 immutable
as $function$ select {J(D.RULES)} $function$;
grant execute on function public.world_meisho_rules() to public;

do $c$ begin
  if exists (select 1 from jsonb_array_elements_text({J(new_names)}) n(v)
     where n.v in (select region_name from public.world_map_regions) or n.v in (select node_name from public.world_exploration_nodes)
        or n.v in (select spot_name from public.world_gathering_spots) or n.v in (select ground_name from public.world_fish_grounds)
        or n.v in (select ground_name from public.world_expedition_grounds) or n.v in (select site_name from public.world_region_sites)
        or n.v in (select item_name from public.world_item_catalog where public.world_item_base(item_id) <> all (array(select jsonb_array_elements_text({J(new_ids)}))))) then
    raise exception '명소·명소 물품 이름이 이미 있는 이름과 겹칩니다';
  end if;
end $c$;
""")
    w.append(open(os.path.join(HERE, 'b_tables.sql'), encoding='utf-8').read())
    w.append(f"""
insert into public.world_status_catalog(status_key, status_name, polarity, description, duration_minutes, effects, max_stacks, active, icon, cure)
select x.status_key, x.status_name, 'positive', x.description, x.duration_minutes, x.effects, 1, true, x.icon, '시간이 지나면 사라집니다.'
  from jsonb_to_recordset({J(statuses)}) as x(status_key text, status_name text, description text, duration_minutes int, effects jsonb, icon text)
on conflict (status_key) do update set status_name = excluded.status_name, description = excluded.description, duration_minutes = excluded.duration_minutes, effects = excluded.effects, icon = excluded.icon;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, tradeable, reference_price, stack_size, use_fx)
select x.item_id, x.item_name, x.category, x.tier, x.description, x.stackable, x.required_stats, x.minimum_level, x.rarity, x.acquisition_difficulty, x.drop_rate_modifier, x.equipment_traits, x.tradeable, x.reference_price, x.stack_size, x.use_fx
  from jsonb_to_recordset({J(items)}) as x(item_id text, item_name text, category text, tier int, description text, stackable boolean, required_stats jsonb, minimum_level int, rarity text,
    acquisition_difficulty int, drop_rate_modifier numeric, equipment_traits jsonb, tradeable boolean, reference_price bigint, stack_size int, use_fx jsonb)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description, required_stats = excluded.required_stats,
  equipment_traits = excluded.equipment_traits, minimum_level = excluded.minimum_level, stack_size = excluded.stack_size, tradeable = excluded.tradeable, use_fx = excluded.use_fx;

insert into public.world_meisho(meisho_id, meisho_name, region_id, node_id, kind, phase, weather, weather2, min_level, description, sort)
select x.id, x.name, x.region, n.node_id, x.kind, x.phase, x.weather, x.weather2, n.min_level, x."desc", x.sort
  from jsonb_to_recordset({J(meisho)}) as x(id text, name text, region text, node text, kind text, phase text, weather text, weather2 text, "desc" text, sort int)
  join lateral (select z.node_id, z.min_level from public.world_exploration_nodes z where z.region_id = x.region and z.node_name = x.node order by z.hierarchy_level limit 1) n on true
on conflict (meisho_id) do update set meisho_name = excluded.meisho_name, region_id = excluded.region_id, node_id = excluded.node_id, kind = excluded.kind, phase = excluded.phase,
  weather = excluded.weather, weather2 = excluded.weather2, min_level = excluded.min_level, description = excluded.description, sort = excluded.sort;
do $c$ begin
  if (select count(*) from public.world_meisho) <> {len(meisho)} then raise exception '명소 답사 지점을 찾지 못했습니다'; end if;
  if exists (select 1 from public.world_meisho m join public.world_map_regions r using (region_id) where r.is_safe_zone or not r.active) then raise exception '명소는 바깥 지역에만'; end if;
  if exists (select 1 from public.world_meisho m join public.world_map_regions r using (region_id) join public.world_weather_climate cl on cl.territory_id = coalesce((select territory_id from public.world_weather_climate where territory_id = r.territory_id), 'capital')
      where not cl.weights ? m.weather or (m.weather2 is not null and not cl.weights ? m.weather2)) then raise exception '그 땅에 오지 않는 날씨를 고른 명소가 있습니다'; end if;
end $c$;

insert into public.world_tool_lines(item_id, line) select x.key, x.value from jsonb_each_text({J(D.TOOL_LINES)}) x
 where not exists (select 1 from public.world_tool_lines t where t.item_id = x.key);

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool_tier, required_location, description, minimum_level, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field)
select x.recipe_id, x.recipe_name, x.output_item, x.output_qty, x.ingredients, 1, x.required_location, x.description, x.minimum_level, x.recipe_difficulty, 0, x.required_skill, x.required_skill_rank, x.craft_field
  from jsonb_to_recordset({J(recipes)}) as x(recipe_id text, recipe_name text, output_item text, output_qty int, ingredients jsonb, required_location text, description text, minimum_level int,
    recipe_difficulty int, required_skill text, required_skill_rank int, craft_field text)
on conflict (recipe_id) do update set recipe_name = excluded.recipe_name, output_item = excluded.output_item, output_qty = excluded.output_qty, ingredients = excluded.ingredients, craft_field = excluded.craft_field,
  required_location = excluded.required_location, minimum_level = excluded.minimum_level, description = excluded.description, recipe_difficulty = excluded.recipe_difficulty,
  required_skill = excluded.required_skill, required_skill_rank = excluded.required_skill_rank;

update public.world_item_catalog i set reference_price = greatest(
    ceil(1.2 * (select min(t.v) from (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) v from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id group by cr.recipe_id) t)),
    coalesce(ceil(1.15 * (select max(f.reference_price) from public.world_item_catalog f where f.tier = 6 and f.category = i.category and f.base_item_id is null
      and f.item_id not like 'raid%' and coalesce((f.equipment_traits ->> 'life_slot'), '') = coalesce((i.equipment_traits ->> 'life_slot'), ''))), 0))
 where i.item_id in (select jsonb_array_elements_text({J(gear_ids)}));
update public.world_item_catalog i set reference_price = greatest(100,
    ceil(1.1 * (select min(t.v) from (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) v from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id group by cr.recipe_id) t)))
 where i.item_id in (select jsonb_array_elements_text({J(food_ids)}));

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
  rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade, use_fx)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable,
  i.required_stats, i.required_job, i.required_faction, i.minimum_level, i.rarity, i.acquisition_difficulty, i.drop_rate_modifier,
  case when i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then public.world_item_hq_traits(i.equipment_traits) else i.equipment_traits end,
  i.crafting_specialization, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.item_id, 1, null
  from public.world_item_catalog i
 where i.item_id in (select jsonb_array_elements_text({J(hq_ids)}))
on conflict (item_id) do nothing;
""")
    w.append(open(os.path.join(HERE, 'c_funcs.sql'), encoding='utf-8').read())
    w.append('\n' + open(os.path.join(HERE, 'd_hooks.sql'), encoding='utf-8').read())
    w.append(f"\nupdate public.world_app_meta set value = '{VER}' where key = 'db_version';\n")
    open(OUT, 'w', encoding='utf-8').write(''.join(w))
    print(OUT, sum(len(x) for x in w))


if __name__ == '__main__':
    main()
