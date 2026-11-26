import json
import os

import data_trade as T
from cabin import gen_cabin as CB

HERE = os.path.dirname(os.path.abspath(__file__))


def emit(fresh, errors, bulk, J, REF, also_items, also_monsters, out):
    w = out.append
    fresh('items', also_items + [g[1] for g in T.GOODS], '물품')
    fresh('item_ids', [g[0] for g in T.GOODS], '물품 id')
    fresh('monsters', also_monsters + [T.ROBBER[1]], '요괴')
    fresh('monster_ids', [T.ROBBER[0]], '요괴 id')
    known = set(REF['item_ids'])
    for t, cats in T.parts().items():
        for k, v in cats.items():
            for i in v:
                if i not in known:
                    errors.append(f'조선 재료 물품 없음: {i}')
    for i in T.ROBBER[6]:
        if i not in known:
            errors.append(f'물길 강도 전리품 없음: {i}')
    regs = set(REF['region_ids'])
    for p in T.PORTS:
        for s in p[5]:
            if s not in regs and not s.startswith(('pd_', 'jb_', 'bs_', 'ho_')):
                errors.append(f'항구 바다 지역 없음: {s}')
    w(open(os.path.join(HERE, 'b_tables.sql')).read())
    rules = T.rules()
    w(f"""create or replace function public.world_trade_rules() returns jsonb language sql immutable set search_path to 'pg_catalog', 'public' as $f$ select {J(rules)} $f$;
revoke all on function public.world_trade_rules() from public, anon;
grant execute on function public.world_trade_rules() to authenticated, service_role;
do $$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\\_owner%' loop
    execute format('grant execute on function public.world_trade_rules() to %I', x);
  end loop;
end $$;""")
    rows = [dict(item_id=g[0], item_name=g[1], category='trade', tier=1 if rules['ports'][g[2]]['realm'] == 'main' else 2, description=g[5], stackable=True,
                 required_stats={}, minimum_level=1, rarity='common', acquisition_difficulty=1, drop_rate_modifier=1, equipment_traits={'trade': True, 'port': g[2]},
                 tradeable=False, reference_price=g[3], stack_size=rules['slot_n'], use_fx=None) for g in T.GOODS]
    bulk('world_item_catalog', rows, [('item_id', 'text'), ('item_name', 'text'), ('category', 'text'), ('tier', 'int'), ('description', 'text'), ('stackable', 'boolean'),
         ('required_stats', 'jsonb'), ('minimum_level', 'int'), ('rarity', 'text'), ('acquisition_difficulty', 'int'), ('drop_rate_modifier', 'numeric'), ('equipment_traits', 'jsonb'),
         ('tradeable', 'boolean'), ('reference_price', 'bigint'), ('stack_size', 'int'), ('use_fx', 'jsonb')], 'item_id',
         ['item_name', 'category', 'tier', 'description', 'equipment_traits', 'tradeable', 'reference_price', 'stack_size'])
    mid, nm, rg, kind, mech, desc, drops = T.ROBBER
    w(f"""insert into public.world_region_monsters(monster_id, region_id, monster_name, monster_type, min_level, max_level, hp, attack_power, spawn_weight, description, drops,
  difficulty_rank, mechanic_key, mechanic_description, role, kind)
select {J(mid)} #>> '{{}}', {J(rg)} #>> '{{}}', {J(nm)} #>> '{{}}', 'human', 1, public.world_level_cap() + 1, 84, 9, 0, {J(desc)} #>> '{{}}', {J(drops)}, 2, {J(mech)} #>> '{{}}',
  '숨어 있다 먼저 친다. 낌새를 살피고 방어를 섞어라.', 'raider', {J(kind)} #>> '{{}}'
on conflict (monster_id) do update set monster_name = excluded.monster_name, description = excluded.description, drops = excluded.drops, max_level = excluded.max_level,
  role = excluded.role, kind = excluded.kind, mechanic_key = excluded.mechanic_key;""")
    for f in ('c_funcs.sql', 'd_hooks.sql'):
        w(open(os.path.join(HERE, f)).read())
    w(CB.sql(J, known, errors))
