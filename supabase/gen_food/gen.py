import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from data import *

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'migrations', f'{DB_VERSION}_world_3_8_0_food.sql')

def q(s):
    return "'" + str(s).replace("'", "''") + "'"

def js(o):
    return q(json.dumps(o, ensure_ascii=False)) + '::jsonb'

def arr(xs):
    return 'array[' + ','.join(q(x) for x in xs) + ']::text[]' if xs else "'{}'::text[]"

def tier_of(lv):
    return 1 if lv < 10 else 2 if lv < 20 else 3 if lv < 30 else 4

def diff_of(lv):
    return min(5, 1 + lv // 10)

ids = set()
for t in (ING, MEAT):
    for r in t:
        assert r[0] not in ids, r[0]; ids.add(r[0])
for r in DISH:
    assert r[0] not in ids, r[0]; ids.add(r[0])
spec = []
for fac, n1, i1, d1, n2, i2, d2 in SPECIAL:
    shop, place = HUBS[fac]
    for k, (nm, ing, ds) in enumerate([(n1, i1, d1), (n2, i2, d2)]):
        sid = f'sp_{fac}_{k + 1}'
        assert sid not in ids; ids.add(sid)
        f = dict(SPECIAL_FX[k]); f['buffs'] = [f'fs_{fac}']
        spec.append((sid, nm, SPECIAL_LV[k], ing, 2, fx(**f), ds, fac, shop, place))

raw = {r[0] for r in ING} | {r[0] for r in MEAT}
used = set()
for r in DISH: used |= set(r[3])
for r in spec: used |= set(r[3])
for k, (st, rm) in EDIT.items(): used |= set(st)
missing = raw - used
assert not missing, f'안 쓰이는 재료: {missing}'
st_keys = {s[0] for s in ST} | {'well_fed', 'warm_belly', 'vigor', 'clear_mind', 'well_rested'}
for r in DISH + [x[:7] for x in spec]:
    for b in r[5]['buffs']:
        assert b in st_keys, (r[0], b)
for r in DISH + [x[:7] for x in spec]:
    ing = r[3]
    if 'mt_boar' in ing: assert 'charcoal' in ing, r[0]
    if 'mt_crab' in ing: assert 'herbal_extract' in ing, r[0]
    if 'mt_yofish' in ing: assert 'frost_salt' in ing, r[0]
for npc, it in KIN_FOOD.items():
    assert it in ids, (npc, it)

S = []
w = S.append

w("create temp table yh_patch_n(n int) on commit drop;")
w("""create or replace function pg_temp.yh_patch(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text; n int;
begin
  select prosrc into src from pg_proc where oid = p_fn;
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'patch % : % 번 나옴 — %', p_fn, n, left(p_old, 60); end if;
  src := replace(src, p_old, p_new);
  execute regexp_replace(pg_get_functiondef(p_fn), 'AS \\$function\\$.*\\$function\\$', '', 's') || ' AS $yhfn$' || src || '$yhfn$';
end $f$;""")

rules = {
    'meats': [r[0] for r in MEAT], 'meat_p': MEAT_P, 'meat_n': MEAT_N,
    'fixed': [r[0] for r in spec], 'cap': SPECIAL_CAP, 'shop_mul': SHOP_MUL, 'show_min': list(SHOW_MIN),
    'specials': {r[7]: [x[0] for x in spec if x[7] == r[7]] for r in spec},
    'hubs': {k: v[1] for k, v in HUBS.items()},
    'buffs': [r[0] for r in ST],
}
w(f"create or replace function public.world_food_rules() returns jsonb language sql immutable as $f$ select {js(rules)} $f$;")
w("create or replace function public.world_food_is_meat(p_item text) returns boolean language sql immutable as $f$ select coalesce((public.world_food_rules() -> 'meats') ? p_item, false) $f$;")
w("create or replace function public.world_food_fixed() returns text[] language sql immutable as $f$ select array(select jsonb_array_elements_text(public.world_food_rules() -> 'fixed')) $f$;")
w("""create or replace function public.world_food_meat_roll(p_loot jsonb, p_drops jsonb, p_rank text) returns jsonb language plpgsql volatile set search_path = pg_catalog, public as $f$
declare r jsonb := public.world_food_rules(); k text; p numeric; lo int := (r -> 'meat_n' ->> 0)::int; hi int := (r -> 'meat_n' ->> 1)::int; out jsonb := coalesce(p_loot, '{}'::jsonb);
begin
  p := coalesce((r -> 'meat_p' ->> coalesce(p_rank, 'normal'))::numeric, (r -> 'meat_p' ->> 'normal')::numeric);
  for k in select d.key from jsonb_each(coalesce(p_drops, '{}'::jsonb)) d where public.world_food_is_meat(d.key) loop
    if random() < p then out := public.world_inv_add(out, k, lo + floor(random() * (hi - lo + 1))::int); end if;
  end loop;
  return out;
end $f$;""")
for fn in ['world_food_rules()', 'world_food_is_meat(text)', 'world_food_fixed()', 'world_food_meat_roll(jsonb, jsonb, text)']:
    w(f"revoke all on function public.{fn} from public, anon, authenticated;")
    w(f"grant execute on function public.{fn} to service_role, fn_owner_field;")

def item_row(iid, nm, cat, tier, desc, price, use_fx, spec_=None):
    return (f"({q(iid)}, {q(nm)}, {q(cat)}, {tier}, {q(desc)}, true, true, {price if price is not None else 'null'}, 50, "
            f"{js(use_fx) if use_fx else 'null'}, {q(spec_) if spec_ else 'null'})")

rows = []
for iid, nm, t, p, d in ING: rows.append(item_row(iid, nm, 'material', t, d, p, None, 'cooking'))
for iid, nm, t, p, d in MEAT: rows.append(item_row(iid, nm, 'material', t, d, p, None, 'cooking'))
for r in DISH: rows.append(item_row(r[0], r[1], 'consumable', tier_of(r[2]), r[6], None, r[5], 'cooking'))
for r in spec: rows.append(item_row(r[0], r[1], 'consumable', tier_of(r[2]), r[6] + f' {r[9]}에서 늘 판다.', None, r[5], 'cooking'))
w("insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, use_fx, crafting_specialization) values\n  "
  + ",\n  ".join(rows) + ";")

srows = []
for k, nm, icon, d, eff, mins in ST:
    srows.append(f"({q(k)}, {q(nm)}, 'positive', {q(d)}, {mins}, {js(eff)}, 1, true, {q(icon)}, '시간이 지나면 사라집니다.')")
w("insert into public.world_status_catalog(status_key, status_name, polarity, description, duration_minutes, effects, max_stacks, active, icon, cure) values\n  " + ",\n  ".join(srows) + ";")

rrows = []
for r in DISH:
    rrows.append(f"({q('r_' + r[0])}, {q(r[1] + ' 만들기')}, {q(r[0])}, {r[4]}, {js(r[3])}, null, 1, null, {q(r[6])}, {r[2]}, null, {diff_of(r[2])}, 0, null, 1, 'cooking')")
for r in spec:
    rrows.append(f"({q('r_' + r[0])}, {q(r[1] + ' 만들기')}, {q(r[0])}, {r[4]}, {js(r[3])}, null, 1, {q(r[9])}, {q(r[6] + ' ' + r[9] + '에서 만들면 솜씨가 더 난다.')}, {r[2]}, null, {diff_of(r[2])}, 0, null, 1, 'cooking')")
w("insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field) values\n  "
  + ",\n  ".join(rrows) + ";")

for rid, (st, rm) in EDIT.items():
    w(f"update public.world_crafting_recipes set ingredients = (ingredients - {arr(rm)}) || {js(st)} where recipe_id = {q(rid)} and craft_field = 'cooking';")
w(f"do $c$ begin if (select count(*) from public.world_crafting_recipes where recipe_id = any({arr(list(EDIT))})) <> {len(EDIT)} then raise exception '고칠 요리 제작법이 다 있지 않음'; end if; end $c$;")

new_out = [r[0] for r in DISH] + [r[0] for r in spec]
edit_out_sql = f"(select output_item from public.world_crafting_recipes where recipe_id = any({arr(list(EDIT))}))"
w(f"""with cost as (
  select r.output_item, min(ceil((select sum(e.value::numeric * coalesce(i.reference_price, 0)) from jsonb_each_text(r.ingredients) e join public.world_item_catalog i on i.item_id = e.key) / r.output_qty * 1.1)) v
  from public.world_crafting_recipes r where r.output_item = any({arr(new_out)}) or r.output_item in {edit_out_sql} group by r.output_item)
update public.world_item_catalog c set reference_price = greatest(coalesce(c.reference_price, 0), cost.v) from cost where c.item_id = cost.output_item;""")

w(f"""insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, use_fx, crafting_specialization, base_item_id, quality_grade)
select c.item_id || '_hq', c.item_name || ' (우수)', c.category, c.tier, c.description || ' ' || public.world_item_hq_note(c.item_id, c.category), true, c.tradeable, ceil(c.reference_price * 1.3), c.stack_size, null, c.crafting_specialization, c.item_id, 1
from public.world_item_catalog c where c.item_id = any({arr(new_out)});""")

w("create temp table yh_fg(item text, cats text[], types text[], facs text[], regs text[], minlv int) on commit drop;")
w("insert into yh_fg values\n  " + ",\n  ".join(
    f"({q(i)}, {arr(c)}, {arr(m.get('types', []))}, {arr(m.get('facs', []))}, {arr(m.get('regs', []))}, {lv})" for i, c, m, lv in GATHER) + ";")
w("""with cand as (
  select s.spot_id, g.item from public.world_gathering_spots s
  join public.world_exploration_nodes n on n.node_id = s.node_id
  join public.world_map_regions r on r.region_id = n.region_id
  join yh_fg g on s.category = any(g.cats) and r.min_level >= g.minlv
    and (r.region_type = any(g.types) or r.home_faction_id = any(g.facs) or r.region_id = any(g.regs))
  where not (s.loot_items && (select array_agg(item) from yh_fg))),
pick as (select distinct on (spot_id) spot_id, item from cand order by spot_id, md5(spot_id::text || item))
update public.world_gathering_spots s set loot_items = s.loot_items || array[p.item] from pick p where s.spot_id = p.spot_id;""")
w("do $c$ declare x text; begin for x in select item from yh_fg loop if not exists (select 1 from public.world_gathering_spots where x = any(loot_items)) then raise exception '채집터에 안 들어간 식재료 %', x; end if; end loop; end $c$;")

for it, kinds, lo, hi in MEAT_DROP:
    cond = f"kind = any({arr(kinds)})"
    if lo is not None: cond += f" and min_level >= {lo}"
    if hi is not None: cond += f" and min_level <= {hi}"
    w(f"update public.world_region_monsters set drops = coalesce(drops, '{{}}'::jsonb) || jsonb_build_object({q(it)}, 1) where {cond};")
w("do $c$ declare x text; begin for x in select jsonb_array_elements_text(public.world_food_rules() -> 'meats') loop if not exists (select 1 from public.world_region_monsters where drops ? x) then raise exception '떨어뜨리는 요괴가 없는 고기 %', x; end if; end loop; end $c$;")

shop_rows = []
for shop, items in SHOP_ROT.items():
    for it in items:
        shop_rows.append(f"({q(shop)}, {q(it)}, ceil((select reference_price from public.world_item_catalog where item_id = {q(it)}) * {SHOP_MUL}), 1, 1, null)")
for r in spec:
    shop_rows.append(f"({q(r[8])}, {q(r[0])}, ceil((select reference_price from public.world_item_catalog where item_id = {q(r[0])}) * {SHOP_MUL}), 1, 1, {SPECIAL_CAP})")
w("insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap) values\n  " + ",\n  ".join(shop_rows) + "\non conflict do nothing;")

w("select pg_temp.yh_patch('public.world_battle_action(text, text)'::regprocedure, 'IF random() < 0.25 + rare / 100.0 THEN', 'loot := public.world_food_meat_roll(loot, m.drops, a.rank);\n    IF random() < 0.25 + rare / 100.0 THEN');")
w("select pg_temp.yh_patch('public.world_battle_action(text, text)'::regprocedure, 'WHERE ic.item_id = k) AND random() < drop_p THEN', 'WHERE ic.item_id = k) AND random() < drop_p AND NOT public.world_food_is_meat(k) THEN');")
w("select pg_temp.yh_patch('public.world_shop_refresh(text)'::regprocedure, 'or sc.item_id = any(story)', 'or sc.item_id = any(story) or sc.item_id = any(public.world_food_fixed())');")
w(f"select pg_temp.yh_patch('public.world_shop_refresh(text)'::regprocedure, 'then 4 else 6 end', 'then {SHOW_MIN[1]} else {SHOW_MIN[0]} end');")
food_js = json.dumps(KIN_FOOD, ensure_ascii=False)
w(f"select pg_temp.yh_patch('public.world_kin_rules()'::regprocedure, '\"faded\": \"빛바랜 정표\"', {q(chr(34) + 'faded' + chr(34) + ': ' + chr(34) + '빛바랜 정표' + chr(34) + ', ' + chr(34) + 'food' + chr(34) + ': ' + food_js + ', ' + chr(34) + 'food_mul' + chr(34) + ': ' + str(KIN_FOOD_MUL))});")
w("select pg_temp.yh_patch('public.world_kin_gift(text)'::regprocedure, 'infield := public.world_kin_in_field(uid, k.npc, base);', 'infield := public.world_kin_in_field(uid, k.npc, base) or base = (r -> ''food'' ->> k.npc);');")
w("select pg_temp.yh_patch('public.world_kin_gift(text)'::regprocedure, 'random() * 100 < (r -> ''reward'' ->> ''pct'')::numeric', 'random() * 100 < (r -> ''reward'' ->> ''pct'')::numeric * (case when base = (r -> ''food'' ->> k.npc) then (r ->> ''food_mul'')::numeric else 1 end)');")
w("""do $yhm$ declare fn regprocedure := 'public.world_use_item(text)'::regprocedure; src text; o text := 'buff IN (''well_fed'', ''warm_belly'', ''vigor'', ''sea_luck'')'; n int;
begin
  select prosrc into src from pg_proc where oid = fn;
  n := (length(src) - length(replace(src, o, ''))) / length(o);
  if n <> 3 then raise exception 'use_item meal patch: % 번 나옴', n; end if;
  src := replace(src, o, '(' || o || ' OR public.world_food_rules() -> ''buffs'' ? buff)');
  execute regexp_replace(pg_get_functiondef(fn), 'AS \\$function\\$.*\\$function\\$', '', 's') || ' AS $yhfn$' || src || '$yhfn$';
end $yhm$;""")
w("update public.world_skill_catalog set description = replace(description, '(든든함·속이 따뜻함·기운 충천·바다의 복)', '(든든함·속이 따뜻함·기운 충천·바다의 복과 고기 힘·뿌리 온기·곡기 든든·큰상 기운·세력 특선 기운)') where skill_id = 'cooking_c43b' and description like '%(든든함·속이 따뜻함·기운 충천·바다의 복)%';")
w(f"select pg_temp.yh_patch('public.world_storage_rules()'::regprocedure, '''base'', {STORAGE_BASE[0]},', '''base'', {STORAGE_BASE[1]},');")

with open(os.path.join(HERE, 'patch_note.sql')) as f:
    w(f.read().strip())
w(f"insert into public.world_app_meta(key, value, changed_at) values ('db_version', {q(DB_VERSION)}, now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;")

with open(OUT, 'w') as f:
    f.write('\n\n'.join(S) + '\n')
print(OUT, len(ING), 'ing', len(MEAT), 'meat', len(DISH), 'dish', len(spec), 'special', len(EDIT), 'edit')
