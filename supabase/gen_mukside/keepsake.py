import json, pathlib

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
FURN = 'hf_'
ITEMS = [
    ('hf_mk_brushstand', '서리의 붓꽂이', 'furniture', '별채 가구 · 소품. 희수가 명부를 쓰던 붓을 꽂아 두던 붓꽂이입니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.',
     {'d': 1, 'w': 1, 'hk': 'mk_brushstand', 'cat': '소품', 'top': 0, 'kind': 'surface', 'grade': 4}),
    ('hf_mk_notedesk', '두 권째 공책 책상', 'furniture', '별채 가구 · 좌석·탁자. 다온이 두 권째 공책을 펴 두던 낮은 책상입니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.',
     {'d': 1, 'w': 2, 'hk': 'mk_notedesk', 'cat': '좌석·탁자', 'top': 0.46, 'kind': 'floor', 'grade': 4}),
    ('hf_mk_coinblind', '연꽃 매듭 엽전 발', 'furniture', '별채 가구 · 발. 월하가 좌판에 걸어 두던 엽전 발입니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.',
     {'hk': 'mk_coinblind', 'wh': 30, 'ww': 1.6, 'cat': '발', 'kind': 'wall', 'wall': 'deco', 'grade': 4}),
    ('of_acc_mk_hairpin', '먹 묻은 붓 비녀', 'outfit', '희수가 쓰던 붓을 깎아 만든 비녀입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', {'look': 'acc:mk_hairpin'}),
    ('of_acc_mk_nameplate', '삐뚤빼뚤 이름패', 'outfit', '다온이 내 이름을 처음 따라 쓴 이름패입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', {'look': 'acc:mk_nameplate'}),
    ('of_acc_mk_lotus', '연꽃 매듭 노리개', 'outfit', '월하의 연꽃 매듭을 노리개로 엮은 것입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', {'look': 'acc:mk_lotus'}),
]


def T(s): return "'" + str(s).replace("'", "''") + "'"


parts = (ROOT / 'supabase/gen_avatar/parts.json').read_text()
pj = json.loads(parts)
for iid, *_ , tr in ITEMS:
    if 'look' in tr and tr['look'] not in pj['outfits']: raise SystemExit(f'parts.json에 {tr["look"]} 없음(tools/avatar_art/gen.py)')
furn = (ROOT / 'assets/js/housing/furniture.js').read_text()
for iid, *_ , tr in ITEMS:
    if 'hk' in tr and f"  {tr['hk']}: {{" not in furn: raise SystemExit(f'furniture.js에 {tr["hk"]} 없음')
rows = ',\n'.join(f"({T(i)}, {T(n)}, {T(c)}, 4, {T(d)}, false, false, {800 if c == 'furniture' else 100}, 1, {T(json.dumps(tr, ensure_ascii=False))}::jsonb)" for i, n, c, d, tr in ITEMS)
sql = f"""create or replace function public.world_avatar_parts()
 returns jsonb language sql immutable
as $f$ select {T(parts)}::jsonb $f$;
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values
{rows}
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  stackable = excluded.stackable, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size, equipment_traits = excluded.equipment_traits;
"""
(HERE / 'keepsake.sql').write_text(sql)
print(HERE / 'keepsake.sql', len(sql))
