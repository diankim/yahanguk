import json, pathlib
HERE = pathlib.Path(__file__).resolve().parent
parts = json.loads((HERE.parents[0] / 'gen_avatar' / 'parts.json').read_text())
JOBS = [('blood', '혈기사'), ('formation', '진법가'), ('spear', '여명 창객')]
T = lambda s: "'" + str(s).replace("'", "''") + "'"
out = ["select pg_temp.yh_setjson('public.world_avatar_parts()'::regprocedure, " + T(json.dumps(parts, ensure_ascii=False, separators=(',', ':'))) + "::jsonb);"]
pool, src = [], {}
for k, jn in JOBS:
    for slot in ('top', 'bottom'):
        o = parts['outfits'][f'{slot}:{k}']
        iid = f'of_{slot}_{k}'
        out.append(f"""insert into public.world_item_catalog
select (jsonb_populate_record(null::public.world_item_catalog, to_jsonb(c) || jsonb_build_object('item_id', {T(iid)}, 'item_name', {T(o['name'])},
  'description', {T(f"{jn} 기본 옷. 가방에서 「옷장에」를 누르면 「내 모습」에서 입을 수 있습니다.")}, 'equipment_traits', jsonb_build_object('look', {T(f'{slot}:{k}')})))).*
  from public.world_item_catalog c where c.item_id = {T(f'of_{slot}_tamer')}
on conflict (item_id) do nothing;""")
        pool.append(iid); src[f'{slot}:{k}'] = f'{jn} 기본 옷 · 옷 꾸러미'
out.append(f"""select pg_temp.yh_setjson('public.world_outfit_rules()'::regprocedure, public.world_outfit_rules()
  || jsonb_build_object('pool', (public.world_outfit_rules() -> 'pool') || {T(json.dumps(pool, ensure_ascii=False))}::jsonb,
                        'src', (public.world_outfit_rules() -> 'src') || {T(json.dumps(src, ensure_ascii=False))}::jsonb));""")
head = (HERE.parents[0] / 'gen_avatar' / 'outfits_240.sql').read_text().split('select pg_temp.yh_setjson')[0]
(HERE / 'sql' / 'n_outfits.sql').write_text(head + '\n'.join(out) + '\n')
print('ok', len(pool))
