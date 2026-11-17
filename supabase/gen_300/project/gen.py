import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
import importlib.util as _iu
_sp = _iu.spec_from_file_location('pj_data', os.path.join(HERE, 'data.py'))
D = _iu.module_from_spec(_sp)
_sp.loader.exec_module(D)

J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + '$J$::jsonb'
T = lambda s: "'" + str(s).replace("'", "''") + "'"


def part(f):
    return open(os.path.join(HERE, f)).read()


def furniture():
    js = """import { FUR, WALL } from './assets/js/housing/furniture.js';
const keys = %s; const o = {};
for (const k of keys) {
  const f = FUR[k], g = WALL[k];
  if (f) o[k] = { name: f.name, grade: f.grade, W: f.W, D: f.D, layer: f.layer, cat: f.cat, top: f.top || 0, pet: f.pet || null };
  else if (g) o[k] = { name: g.name, grade: g.grade, layer: 'wall', cat: g.cat, ww: g.w, wh: g.h, wall: g.kind };
}
console.log(JSON.stringify(o));""" % json.dumps([v[0] for v in D.FURN.values()])
    return json.loads(subprocess.check_output(['node', '--input-type=module', '-e', js], cwd=ROOT))


def rules():
    projects = {}
    for k, p in D.PROJECTS.items():
        fac = p['kind'] == 'faction'
        base = D.F_BASE if fac else D.C_BASE
        q = dict(kind=p['kind'], name=p['name'], hubs=p['hubs'], shop=p['shop'],
                 stages=[dict(base=base[i], craft=s[:4], gather=s[4:]) for i, s in enumerate(p['stages'])])
        if fac:
            q.update(faction=p['faction'], area=p['area'], area_fx=p['area_fx'], route={r: D.F_ROUTE_CUT for r in p['route']},
                     vault=p['vault'], pattern=list(p['pattern']))
        else:
            q.update(domain=p['domain'], story=p['story'], route=p['route'])
        projects[k] = q
    return dict(pay=D.PAY, urgent=D.URGENT, hq_mul=D.HQ_MUL, mul_cap=D.MUL_CAP, goal=D.GOAL, memento=D.MEMENTO, lift=D.LIFT,
                f_shop=D.F_SHOP, c_shop=D.C_SHOP, perk_text={'faction': D.F_PERK_TEXT, 'common': D.C_PERK_TEXT},
                vault=[dict(id=i, price=pr, rank=rk, stage=sg) for i, pr, rk, sg in D.VAULT_COMMON],
                vault_faction=dict(rank=D.VAULT_FACTION[0], prices=list(D.VAULT_FACTION[1:]), stage=4),
                titles=[t[0] for t in D.TITLES], projects=projects)


def build(fresh, errors, ref):
    out = []
    w = out.append
    w(part('a_tables.sql'))
    fur = furniture()
    parts = json.load(open(os.path.join(ROOT, 'supabase', 'gen_avatar', 'parts.json')))
    rows = []
    for iid, nm, cat, tier, desc, stack, price, trade, fx in D.ITEMS:
        rows.append(dict(item_id=iid, item_name=nm, category=cat, tier=tier, description=desc, stack_size=stack, reference_price=price, tradeable=trade,
                         equipment_traits={}, use_fx=None if fx is None else dict({'er': 0, 'hp': 0, 'mn': 0, 'sp': 0, 'stam': 0, 'buffs': [], 'cures': []}, **fx)))
    for iid, (hk, desc, price, trade) in D.FURN.items():
        f = fur.get(hk)
        if not f:
            errors.append(f'사업 가구 그림 없음(furniture.js): {hk}')
            continue
        tr = {'hk': hk, 'kind': f['layer'], 'cat': f['cat'], 'grade': f['grade']}
        if f['layer'] != 'wall':
            tr.update(w=f['W'], d=f['D'], top=f['top'])
        for x in ('pet', 'ww', 'wh', 'wall'):
            if f.get(x) is not None:
                tr[x] = f[x]
        rows.append(dict(item_id=iid, item_name=f['name'], category='furniture', tier=f['grade'], stack_size=1, reference_price=price, tradeable=trade,
                         description=f"별채 가구 · {f['cat']}. {desc} 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.", equipment_traits=tr, use_fx=None))
    look_add = {}
    for iid, (look, desc) in D.OUTFITS.items():
        o = parts['outfits'].get(look)
        if not o:
            errors.append(f'사업 옷 그림 없음(tools/avatar_art): {look}')
            continue
        look_add[look] = o
        rows.append(dict(item_id=iid, item_name=o['name'], category='outfit', tier=2, stack_size=1, reference_price=200, tradeable=False,
                         description=f"{desc} 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.", equipment_traits={'look': look}, use_fx=None))
    fresh('items', [r['item_name'] for r in rows], '사업 물품')
    fresh('item_ids', [r['item_id'] for r in rows], '사업 물품 id')
    w(f"""insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits, use_fx, minimum_level, required_stats)
select x.item_id, x.item_name, x.category, x.tier, x.description, x.stack_size > 1, x.tradeable, x.reference_price, x.stack_size, x.equipment_traits, x.use_fx, 1, '{{}}'::jsonb
  from jsonb_to_recordset({J(rows)}) as x(item_id text, item_name text, category text, tier int, description text, tradeable boolean, reference_price bigint, stack_size int, equipment_traits jsonb, use_fx jsonb)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description, stackable = excluded.stackable,
  tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size, equipment_traits = excluded.equipment_traits, use_fx = excluded.use_fx;""")
    masks = {k: parts['masks'][k] for k in look_add if k in parts.get('masks', {})}
    w(f"""do $d$
declare j jsonb := public.world_avatar_parts();
begin
  j := jsonb_set(j, '{{outfits}}', (j -> 'outfits') || {J(look_add)});
  j := jsonb_set(j, '{{masks}}', coalesce(j -> 'masks', '{{}}'::jsonb) || {J(masks)});
  perform pg_temp.yh_pj_setjson('public.world_avatar_parts()'::regprocedure, j);
end $d$;""")
    R = rules()
    w(f"""do $d$
declare j jsonb := {J(R)}; k text; p jsonb; s jsonb; id text; bad text[] := '{{}}'; sh text[]; vv jsonb := '{{}}'::jsonb; ids text[] := '{{}}'; src jsonb; i int;
begin
  for k, p in select key, value from jsonb_each(j -> 'projects') loop
    sh := array(select r.shop_id from public.world_map_regions r
                 where r.region_id = any (case when p ->> 'kind' = 'faction' then array[p -> 'hubs' ->> 0] else array(select jsonb_array_elements_text(p -> 'hubs')) end)
                   and r.shop_id is not null order by r.shop_id);
    j := jsonb_set(j, array['projects', k, 'shops'], to_jsonb(sh));
    for i in 0 .. 4 loop
      s := p -> 'stages' -> i;
      if (select count(distinct x) from (select jsonb_array_elements_text(s -> 'craft') x union all select jsonb_array_elements_text(s -> 'gather')) z) <> 8 then
        bad := bad || (k || ' ' || (i + 1) || '단계 품목이 여덟 가지가 아님'); end if;
      for id in select jsonb_array_elements_text(s -> 'craft') loop
        if not exists (select 1 from public.world_crafting_recipes r where r.output_item = id) then bad := bad || (k || ' 제작법 없음: ' || id); end if;
      end loop;
      for id in select jsonb_array_elements_text(s -> 'gather') loop
        src := public.world_item_sources_all(id);
        if coalesce(jsonb_array_length(src -> 'gather'), 0) + coalesce(jsonb_array_length(src -> 'sites'), 0) + coalesce(jsonb_array_length(src -> 'monsters'), 0)
           + coalesce(jsonb_array_length(src -> 'fish'), 0) + coalesce(jsonb_array_length(src -> 'meisho'), 0) = 0
           and not exists (select 1 from public.world_crafting_recipes r where r.output_item = id) then bad := bad || (k || ' 얻는 곳 없음: ' || id); end if;
      end loop;
      ids := ids || array(select jsonb_array_elements_text(s -> 'craft')) || array(select jsonb_array_elements_text(s -> 'gather'));
    end loop;
    for id in select jsonb_array_elements_text(p -> 'shop') loop
      if not exists (select 1 from public.world_item_catalog where item_id = id) then bad := bad || (k || ' 상점 물품 없음: ' || id); end if;
      if exists (select 1 from public.world_shop_catalog c where c.shop_id = any (sh) and c.item_id = id) then bad := bad || (k || ' 상점에 이미 있음: ' || id); end if;
    end loop;
    if p ->> 'kind' = 'faction' then
      for id in select unnest(array(select jsonb_array_elements_text(s2 -> 'craft')) || array(select jsonb_array_elements_text(s2 -> 'gather'))) from jsonb_array_elements(p -> 'stages') s2 loop
        if exists (select 1 from public.world_fish_species f where f.fish_id = id and f.named) then bad := bad || (k || ' 명어: ' || id); end if;
      end loop;
    end if;
  end loop;
  for id in select distinct unnest(ids) loop
    if not exists (select 1 from public.world_item_catalog i where i.item_id = id) then bad := bad || ('물품 없음: ' || id);
    elsif exists (select 1 from public.world_item_catalog i where i.item_id = id and (not i.tradeable or i.market_only or i.category = 'quest' or coalesce(i.reference_price, 0) <= 0)) then
      bad := bad || ('거래 불가·거래소 전용·임무 물품·시세 0: ' || id); end if;
    vv := vv || jsonb_build_object(id, (select greatest(1, round(least(i.reference_price::numeric, coalesce((select min((select sum(coalesce(ic.reference_price, 0) * (e.value)::text::int)
        from jsonb_each(rc.ingredients) e join public.world_item_catalog ic on ic.item_id = e.key) / greatest(rc.output_qty, 1)::numeric * 1.2) from public.world_crafting_recipes rc where rc.output_item = id), i.reference_price::numeric))))::int
      from public.world_item_catalog i where i.item_id = id));
  end loop;
  if cardinality(bad) > 0 then raise exception '사업 규칙 검사: %', array_to_string(bad, ' / '); end if;
  j := j || jsonb_build_object('v', vv);
  execute format('create or replace function public.world_project_rules() returns jsonb language sql immutable set search_path = '''' as %L', format('select %L::jsonb', j::text));
end $d$;""")
    w(part('b_give.sql'))
    w(part('c_lift.sql'))
    w(part('d_perks.sql'))
    w(part('e_hooks.sql'))
    shop = []
    for k, p in D.PROJECTS.items():
        fac = p['kind'] == 'faction'
        sp = D.F_SHOP if fac else D.C_SHOP
        for it in p['shop']:
            shop.append(dict(k=k, item=it, mul=sp['price_mul'], cap=sp['daily_cap']))
    w(f"""insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop, x.item, greatest(1, round(i.reference_price * x.mul))::bigint, 1, 1, x.cap
  from jsonb_to_recordset({J(shop)}) as x(k text, item text, mul numeric, cap int)
  join public.world_item_catalog i on i.item_id = x.item
  cross join lateral jsonb_array_elements_text(public.world_project_rule(x.k) -> 'shops') s(shop)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price, daily_cap = excluded.daily_cap;""")
    vrows = []
    for k, p in D.PROJECTS.items():
        if p['kind'] != 'faction':
            continue
        for n, (iid, pr, rk, sg) in enumerate(D.VAULT_COMMON):
            vrows.append(dict(faction_id=p['faction'], item_id=iid, rank_need=rk, price=pr, sort=950 + n, stage_need=sg))
        rk, fp, op = D.VAULT_FACTION
        for n, iid in enumerate(p['vault']):
            vrows.append(dict(faction_id=p['faction'], item_id=iid, rank_need=rk, price=fp if iid.startswith('hf_') else op, sort=970 + n, stage_need=4))
    w(f"""insert into public.world_faction_vault(faction_id, item_id, rank_need, price, sort, kind, stage_need)
select x.faction_id, x.item_id, x.rank_need, x.price, x.sort, 'item', x.stage_need
  from jsonb_to_recordset({J(vrows)}) as x(faction_id text, item_id text, rank_need int, price int, sort int, stage_need int)
on conflict (faction_id, item_id) do update set rank_need = excluded.rank_need, price = excluded.price, sort = excluded.sort, stage_need = excluded.stage_need;""")
    cos = [dict(k=p['pattern'][0], kind='pattern', tier='legend', name=p['pattern'][1], cond=f"「{p['name']}」 5단계", n=1750 + i)
           for i, p in enumerate(v for v in D.PROJECTS.values() if v['kind'] == 'faction')]
    cos.append(dict(k=D.MEMENTO['seal'], kind='seal', tier='legend', name='낙관 「拓」', cond='공동 사업 마지막 단계에 기여', n=1760))
    fresh('cosmetics', [c['name'] for c in cos], '사업 꾸미기')
    w(f"""insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort)
select x.k, x.kind, x.tier, x.name, x.cond, '사업', '{{"shop": "project"}}'::jsonb, false, true, x.n from jsonb_to_recordset({J(cos)}) as x(k text, kind text, tier text, name text, cond text, n int)
on conflict (cosmetic_key) do update set kind = excluded.kind, tier = excluded.tier, cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text,
  category = excluded.category, rule = excluded.rule, active = excluded.active, sort = excluded.sort;""")
    fresh('titles', [t[1] for t in D.TITLES], '사업 칭호')
    fresh('title_keys', [t[0] for t in D.TITLES], '사업 칭호 키')
    w(f"""insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, hidden, rule, sort, category, grade, active)
select x.title_key, x.title_name, x.description, case when x.hidden then '숨겨진 조건' else x.cond end, x.bonus, x.hidden, x.rule, 3300 + x.n, {T(D.TITLE_CAT)}, x.grade, true
  from jsonb_to_recordset({J([dict(title_key=k, title_name=n, grade=g, bonus=b, rule=r, cond=c, hidden=h, description=c + '.', n=i) for i, (k, n, g, b, r, c, h) in enumerate(D.TITLES)])})
    as x(title_key text, title_name text, grade int, bonus jsonb, rule jsonb, cond text, hidden boolean, description text, n int)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus,
  hidden = excluded.hidden, rule = excluded.rule, category = excluded.category, grade = excluded.grade;""")
    return '\n'.join(out)


if __name__ == '__main__':
    errs = []
    sql = build(lambda *a: None, errs, {})
    if errs:
        sys.stderr.write('\n'.join(errs) + '\n')
        sys.exit(1)
    print(sql)
