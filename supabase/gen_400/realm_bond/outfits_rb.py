import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
PARTS = os.path.join(HERE, '..', '..', 'gen_avatar', 'parts.json')
DESC = {
    'top:rb_pado': '파도너울성 쪽배 장터 사람들이 입는 청록 민소매 웃옷입니다. 밧줄빛 허리띠를 매고 밑단에 은물결을 놓았습니다.',
    'bottom:rb_pado': '물일에 젖지 않게 무릎까지 걷어 은빛 단을 접은 바다빛 바지입니다.',
    'top:rb_bulssi': '불씨들녘 장인들이 화덕 앞에서 입는 검은 저고리입니다. 가죽 앞판에 놋쇠 징을 박았습니다.',
    'bottom:rb_bulssi': '검은 바지 위에 주홍 불무늬 천을 허리에 둘러 맨 장인 바지입니다.',
    'top:rb_jaebit': '잿빛그늘숲 나루 사람들이 입는 회녹 베 저고리입니다. 억새 비단 앞치마에 잎맥을 수놓았습니다.',
    'bottom:rb_jaebit': '먹비에 젖어도 무겁지 않은 먹빛 긴 두른 치마입니다. 은회 줄 단을 둘렀습니다.',
    'top:rb_nunmaru': '눈마루 고원 사람들이 입는 털소 털 긴 겉옷입니다. 밑단에 깃발 다섯 빛 줄을 둘렀습니다.',
    'bottom:rb_nunmaru': '무릎 아래에 흰 털 단을 두른 덧바지와 가죽 털신입니다.',
    'top:rb_dalmaji': '달맞이성 왕도 사람들이 나들이에 입는 남색 긴 웃옷입니다. 금빛 테에 연분홍 띠를 맵니다.',
    'bottom:rb_dalmaji': '주름을 넉넉히 잡아 발목에서 금빛 단으로 모은 연분홍 너른 바지입니다.',
    'top:rb_haeoreum': '해오름성 탑 사원 둘레 사람들이 입는 백금빛 저고리입니다. 주황 어깨걸이를 비스듬히 걸칩니다.',
    'bottom:rb_haeoreum': '앞 가운데에 금빛 주름을 접어 넣은 노을빛 두른 바지입니다.',
}
TAIL = ' 가방에서 「옷장에」를 누르면 「내 모습」에서 입을 수 있습니다.'


def emit(RB, J, errors):
    parts = json.load(open(PARTS, encoding='utf-8'))
    T = lambda s: "'" + str(s).replace("'", "''") + "'"
    outfits, masks, src, rows = {}, {}, {}, []
    for v in RB['vault']:
        if v['kind'] != 'item' or not v['id'].startswith('of_'):
            continue
        slot = v['id'].split('_')[1]
        look = slot + ':' + v['id'][len('of_' + slot + '_'):]
        if look not in parts['outfits'] or look not in parts['masks']:
            errors.append(f'권역 옷 {v["id"]}: parts.json에 {look} 없음(tools/avatar_art/gen.py)')
            continue
        if look not in DESC:
            errors.append(f'권역 옷 {look}: 설명 없음')
            continue
        o = parts['outfits'][look]
        outfits[look], masks[look] = o, parts['masks'][look]
        src[look] = f'권역 인연 · {RB["realms"][v["realm"]]["name"]} 비고({v["stage"]}단계)'
        rows.append(f"""insert into public.world_item_catalog
select (jsonb_populate_record(null::public.world_item_catalog, to_jsonb(c) || jsonb_build_object('item_id', {T(v['id'])}, 'item_name', {T(o['name'])},
  'tier', 3, 'tradeable', false, 'description', {T(DESC[look] + TAIL)}, 'equipment_traits', jsonb_build_object('look', {T(look)})))).*
  from public.world_item_catalog c where c.item_id = 'of_top_dallyeong'
on conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, equipment_traits = excluded.equipment_traits, tradeable = false;""")
    head = """create or replace function pg_temp.yh_rb_setjson(p_fn regprocedure, p_j jsonb) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); body text := (select prosrc from pg_proc where oid = p_fn);
begin
  if position(body in src) = 0 then raise exception 'yh_rb_setjson %: 본문을 못 찾음', p_fn; end if;
  execute replace(src, body, ' select ' || quote_literal(p_j::text) || '::jsonb ');
end $f$;"""
    av = f"""select pg_temp.yh_rb_setjson('public.world_avatar_parts()'::regprocedure, public.world_avatar_parts()
  || jsonb_build_object('outfits', (public.world_avatar_parts() -> 'outfits') || {T(json.dumps(outfits, ensure_ascii=False))}::jsonb,
                        'masks', (public.world_avatar_parts() -> 'masks') || {T(json.dumps(masks, ensure_ascii=False))}::jsonb));
select pg_temp.yh_rb_setjson('public.world_outfit_rules()'::regprocedure, jsonb_set(public.world_outfit_rules(), '{{src}}',
  (public.world_outfit_rules() -> 'src') || {T(json.dumps(src, ensure_ascii=False))}::jsonb));"""
    return '\n'.join([head, av] + rows), len(rows)
