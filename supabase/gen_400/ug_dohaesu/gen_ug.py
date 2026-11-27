import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PARTS = os.path.join(HERE, '..', '..', 'gen_avatar', 'parts.json')
BOARD = 'dohaesu'
SRC = '무용담 교환 · 무용담 · 도해수'
FURN = [
    ('hf_ug_tide_basin', '물목 거울 수반', 4, 'floor', 1, 1, '소품', 14),
    ('hf_ug_stone_drum', '땅울림 돌북', 4, 'floor', 1, 1, '장식', 16),
    ('hf_ug_skiff_bed', '쪽배 침상', 5, 'floor', 2, 1, '침구', 40),
    ('hf_ug_kelp_screen', '해초 비늘 병풍', 4, 'floor', 3, 1, '병풍', 24),
    ('hp_ug_tide', '물때 너울 벽지', 4, 'paper', 0, 0, '벽지', 10),
    ('hg_ug_pool', '고임 돌 바닥', 4, 'ground', 0, 0, '바닥재', 10),
]
OUTFITS = [('top:ug_tide_coat', 26), ('bottom:ug_kelp_skirt', 20), ('acc:ug_wedge_pin', 18)]
COSM = [('fr_ug_dohaesu', 'frame', '무용담 · 물목', 22), ('sl_ug_seok', 'seal', '낙관 「汐」', 18)]
SKINS = [('ug_neol_imugi', 'bead_imugi', '너울 구슬 이무기', 45), ('ug_rift_seahorse', 'bj_seahorse', '물목 해마', 40),
         ('ug_tide_platypus', 'platypus', '물때 부리너구리', 36), ('ug_stone_pillbug', 'pill_bug', '땅울림 공벌레', 32)]
TITLES = [('ug_dohaesu_1', '무용담 속 물목을 건넌 이', 1, '무용담 · 도해수를 깬다'), ('ug_dohaesu_10', '물때를 다스린 이', 10, '무용담 · 도해수를 10번 깬다')]
PRICE = {4: 800, 5: 2400}


def emit(J, errors, known_skins):
    parts = json.load(open(PARTS, encoding='utf-8'))
    T = lambda s: "'" + str(s).replace("'", "''") + "'"
    out, shop, outfits, masks = [], [], {}, {}
    rows = []
    for iid, nm, g, kind, w, d, cat, price in FURN:
        tr = {'hk': iid[3:], 'cat': cat, 'kind': kind, 'grade': g}
        if kind == 'floor':
            tr.update({'w': w, 'd': d, 'top': 0})
        rows.append({'item_id': iid, 'item_name': nm, 'tier': g, 'reference_price': PRICE[g], 'equipment_traits': tr,
                     'description': f'별채 가구 · {cat}. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.'})
        shop.append({'id': iid, 'key': f'{BOARD}:{iid}', 'kind': 'item', 'name': nm, 'board': BOARD, 'price': price})
    out.append(f"""insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size, quality_grade, market_only)
select x.item_id, x.item_name, 'furniture', x.tier, x.description, false, '{{}}'::jsonb, 1, x.equipment_traits, false, x.reference_price, 1, 0, false
  from jsonb_to_recordset({J(rows)}) as x(item_id text, item_name text, tier int, description text, equipment_traits jsonb, reference_price bigint)
on conflict (item_id) do update set item_name = excluded.item_name, tier = excluded.tier, description = excluded.description, equipment_traits = excluded.equipment_traits, tradeable = false, reference_price = excluded.reference_price;""")
    for look, price in OUTFITS:
        if look not in parts['outfits']:
            errors.append(f'무용담 · 도해수 옷 {look}: parts.json에 없음(tools/avatar_art/gen.py)')
            continue
        outfits[look] = parts['outfits'][look]
        if look in parts.get('masks', {}):
            masks[look] = parts['masks'][look]
        shop.append({'id': look, 'key': f'{BOARD}:{look}', 'kind': 'outfit', 'name': outfits[look]['name'], 'board': BOARD, 'price': price})
    for k, kind, nm, price in COSM:
        shop.append({'id': k, 'key': f'{BOARD}:{k}', 'kind': kind, 'name': nm, 'board': BOARD, 'price': price})
    for k, pet, nm, price in SKINS:
        if k not in known_skins:
            errors.append(f'무용담 · 도해수 무늬 {k}: tools/pet_art/skins_ug40.py에 없음')
        shop.append({'id': k, 'key': f'{BOARD}:{k}', 'kind': 'skin', 'pet': pet, 'name': nm, 'board': BOARD, 'price': price})
    out.append(f"""insert into public.world_cosmetic_catalog (cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort)
select x.k, x.kind, 'legend', x.nm, '무용담 교환', '무용담', '{{"shop": "ultimate"}}'::jsonb, false, true, x.s
  from jsonb_to_recordset({J([{'k': k, 'kind': kind, 'nm': nm, 's': 1705 + i} for i, (k, kind, nm, _) in enumerate(COSM)])}) as x(k text, kind text, nm text, s int)
on conflict (cosmetic_key) do update set kind = excluded.kind, cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, category = excluded.category, rule = excluded.rule;""")
    out.append(f"""create or replace function pg_temp.yh_ug_setjson(p_fn regprocedure, p_j jsonb) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); body text := (select prosrc from pg_proc where oid = p_fn);
begin
  if position(body in src) = 0 then raise exception 'yh_ug_setjson %: 본문을 못 찾음', p_fn; end if;
  execute replace(src, body, ' select ' || quote_literal(p_j::text) || '::jsonb ');
end $f$;
select pg_temp.yh_ug_setjson('public.world_avatar_parts()'::regprocedure, public.world_avatar_parts()
  || jsonb_build_object('outfits', (public.world_avatar_parts() -> 'outfits') || {J(outfits)},
                        'masks', (public.world_avatar_parts() -> 'masks') || {J(masks)}));
select pg_temp.yh_ug_setjson('public.world_outfit_rules()'::regprocedure, jsonb_set(public.world_outfit_rules(), '{{src}}',
  coalesce(public.world_outfit_rules() -> 'src', '{{}}'::jsonb) || {J({look: SRC for look in outfits})}));
do $$
begin
  execute format('create or replace function public.world_ultimate_rules() returns jsonb language sql immutable set search_path = '''' as $g$ select %L::jsonb $g$',
    jsonb_set(public.world_ultimate_rules(), '{{shop}}', coalesce((select jsonb_agg(e) from jsonb_array_elements(public.world_ultimate_rules() -> 'shop') e where e ->> 'board' <> {T(BOARD)}), '[]'::jsonb) || {J(shop)}));
end $$;""")
    tnames = [t[1] for t in TITLES]
    out.append(f"""do $c$
begin
  if exists (select 1 from public.world_title_catalog where title_name = any (array[{', '.join(T(n) for n in tnames)}]) and title_key not in ({', '.join(T(t[0]) for t in TITLES)})) then
    raise exception '칭호 이름 겹침: 무용담 · 도해수';
  end if;
  if exists (select 1 from public.world_item_catalog where item_name = any (array[{', '.join(T(f[1]) for f in FURN)}]) and item_id not in ({', '.join(T(f[0]) for f in FURN)})) then
    raise exception '물품 이름 겹침: 무용담 · 도해수 가구';
  end if;
  if exists (select 1 from public.world_cosmetic_catalog where cosmetic_name = any (array[{', '.join(T(c[2]) for c in COSM)}]) and cosmetic_key not in ({', '.join(T(c[0]) for c in COSM)})) then
    raise exception '꾸미기 이름 겹침: 무용담 · 도해수';
  end if;
end $c$;
insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, active, hidden, rule, sort, category, grade)
select x.k, x.nm, x.cond || '.', x.cond, '{{}}'::jsonb, true, false, jsonb_build_object('n', x.n, 'ev', 'ug_win', 'p', jsonb_build_object('board', {T(BOARD)})), x.s, '무용담', 5
  from jsonb_to_recordset({J([{'k': k, 'nm': nm, 'n': n, 'cond': c, 's': 3990 + i} for i, (k, nm, n, c) in enumerate(TITLES)])}) as x(k text, nm text, n int, cond text, s int)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, rule = excluded.rule, category = excluded.category, grade = excluded.grade;""")
    out.append("""select pg_temp.yh_patch('public.world_ultimate_buy(text)',
  $q$  elsif s ->> 'kind' = 'pet' then perform public.world_pet_grant(uid, s ->> 'id', 'ultimate', false);$q$,
  $q$  elsif s ->> 'kind' = 'pet' then perform public.world_pet_grant(uid, s ->> 'id', 'ultimate', false);
  elsif s ->> 'kind' = 'skin' then insert into public.world_pet_skin_earned(owner_id, skin) values (uid, s ->> 'id') on conflict do nothing;$q$);
select pg_temp.yh_patch('public.world_ultimate_buy(text)',
  $q$when 'pet' then ' 꼬마 동무 도감에 들어왔습니다.'$q$,
  $q$when 'pet' then ' 꼬마 동무 도감에 들어왔습니다.' when 'skin' then ' 바탕 동무가 있으면 동무 도감의 「무늬」에서 고릅니다.'$q$);""")
    return '\n'.join(out), len(shop)
