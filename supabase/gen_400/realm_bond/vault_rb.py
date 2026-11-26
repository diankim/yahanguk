import json
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))

NAME_STYLE = {'pado': 1038, 'bulssi': 1039, 'jaebit': 1040, 'nunmaru': 1041, 'dalmaji': 1042, 'haeoreum': 1043}
PATTERN = {'pado': '장대 다리 무늬', 'bulssi': '불티 무늬', 'jaebit': '먹비 숲 무늬', 'nunmaru': '깃발 등성이 무늬', 'dalmaji': '돔 지붕 무늬', 'haeoreum': '탑 사원 무늬'}
COS_SORT = 1780
FURN_PRICE = 300
MOUNT = dict(speed=2.4, level=50, passengers=4, fare=2, tier='권역')
MOUNTS = {
    'pado': ('야자 돛배', 'pd_city', '야자 잎을 엮어 돛을 단 파도너울성의 쪽배. 장대 다리 밑을 미끄러져 넷을 태우고 물길을 따라간다.'),
    'bulssi': ('흑요 들소', 'bs_town', '화산 유리처럼 검게 번들거리는 뿔의 들소. 재 깔린 비탈도 발굽 한 번 미끄러지지 않는다.'),
    'jaebit': ('흑단 뿔 사슴', 'jb_village', '흑단 고목에서 깨어났다는 큰 사슴. 먹비 속에서도 뿔 끝이 은회색으로 빛나 길을 밝힌다.'),
    'nunmaru': ('방울 털소', 'nm_village', '목에 방울을 단 눈마루의 털소. 털끈으로 짐을 묶으면 눈보라 속 등성이도 넷을 싣고 넘는다.'),
    'dalmaji': ('공작 수레', 'dm_city', '금빛 꼬리깃을 편 공작 한 쌍이 끄는 달맞이성의 남색 수레. 보름 장날이면 수로 다리를 줄지어 건넌다.'),
    'haeoreum': ('해돋이 코끼리', 'ho_city', '등에 연꽃 무늬 가마를 얹은 해오름성의 코끼리. 해가 뜰 때 밤 등불을 끄고 다니던 옛 길을 그대로 걷는다.'),
}


def art():
    js = """const F = await import('./assets/js/housing/furniture.js');
const C = await import('./assets/js/realm_cosmetics.js');
const fur = {};
for (const [k, f] of Object.entries(F.FUR)) if (f.realm) fur[k] = { t: 'floor', name: f.name, grade: f.grade, W: f.W, D: f.D, layer: f.layer || 'floor', cat: f.cat, top: f.top || 0, pet: f.pet || null };
for (const [k, f] of Object.entries(F.WALL)) if (f.realm) fur[k] = { t: 'wall', name: f.name, grade: f.grade, kind: f.kind, w: f.w, h: f.h, cat: f.cat };
console.log(JSON.stringify({ fur, scene: Object.keys(C.RB_SCENE), seals: C.RB_SEALS, tier: C.RB_SEAL_TIER, names: C.RB_NAME_STYLES }));"""
    return json.loads(subprocess.check_output(['node', '--input-type=module', '-e', js], cwd=ROOT))


def traits(k, f):
    if f['t'] == 'wall':
        return {'hk': k, 'kind': 'wall', 'wall': f['kind'], 'ww': round(f['w'], 4), 'wh': f['h'], 'cat': f['cat'], 'grade': f['grade']}
    t = {'hk': k, 'kind': f['layer'], 'w': f['W'], 'd': f['D'], 'top': f['top'], 'cat': f['cat'], 'grade': f['grade']}
    if f['pet']:
        t['pet'] = f['pet']
    return t


def vault_name(kind, k, A):
    if kind == 'name_style':
        return f"이름 색 「{A['names'][str(NAME_STYLE[k])][0]}」"
    if kind == 'mount':
        return MOUNTS[k][0]
    return None


def emit(RB, J, known, fresh, errors):
    A = art()
    realms = {k: v['name'] for k, v in RB['realms'].items()}
    for k in realms:
        if k not in NAME_STYLE or k not in PATTERN or k not in MOUNTS:
            errors.append(f'권역 비고 {k}: 이름 색·바탕 무늬·탈것 표에 없음')
    for n, (nm, why) in A['names'].items():
        k = next((x for x, v in NAME_STYLE.items() if str(v) == n), None)
        if k is None or realms.get(k, '?') not in why:
            errors.append(f'권역 이름 색 {n}: 권역 짝이 맞지 않음')
    items, cos, mounts, furn_ids = [], [], [], set()
    for v in RB['vault']:
        k, kind, iid = v['realm'], v['kind'], v['id']
        nm = vault_name(kind, k, A)
        if nm:
            v['name'] = nm
        if kind == 'item' and iid.startswith('hf_'):
            f = A['fur'].get(iid[3:])
            if not f:
                errors.append(f'권역 비고 가구 그림 없음(realm_furn.js): {iid}')
                continue
            if f['grade'] != 3:
                errors.append(f'권역 비고 가구 등급이 3이 아님: {iid}')
            furn_ids.add(iid[3:])
            cat = traits(iid[3:], f)['cat']
            items.append(dict(item_id=iid, item_name=f['name'], category='furniture', tier=f['grade'], stackable=False, required_stats={}, minimum_level=1,
                              description=f"별채 가구 · {cat}. {realms[k]} 권역 인연 비고에서 인연 표로 받습니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.",
                              rarity='rare', acquisition_difficulty=f['grade'], drop_rate_modifier=1, equipment_traits=traits(iid[3:], f), tradeable=False,
                              reference_price=FURN_PRICE, stack_size=1))
        elif kind == 'item' and not iid.startswith('of_') and iid not in known:
            errors.append(f'권역 비고 물품 없음: {iid}')
        elif kind == 'cosmetic':
            if iid.startswith('pt_'):
                if iid not in A['scene']:
                    errors.append(f'권역 바탕 무늬 그림 없음(realm_cosmetics.js): {iid}')
                    continue
                cos.append(dict(k=iid, kind='pattern', tier='legend', name=PATTERN[k]))
            elif iid.startswith('sl_'):
                if iid not in A['seals']:
                    errors.append(f'권역 낙관 글자 없음(realm_cosmetics.js): {iid}')
                    continue
                cos.append(dict(k=iid, kind='seal', tier=A['tier'].get(iid, 'legend'), name=f"낙관 「{A['seals'][iid]}」"))
            else:
                errors.append(f'권역 비고 꾸미기 갈래 모름: {iid}')
                continue
            cos[-1].update(cond=f"{realms[k]} 권역 인연 비고({v['stage']}단계)", sort=COS_SORT + len(cos))
            v['name'] = cos[-1]['name']
        elif kind == 'name_style':
            n = iid.split(':')[1]
            if not iid.startswith('ns:') or n not in A['names']:
                errors.append(f'권역 이름 색 없음(realm_cosmetics.js RB_NAME_STYLES): {iid}')
        elif kind == 'mount':
            mn, reg, desc = MOUNTS[k]
            if reg not in RB['realms'][k]['hubs']:
                errors.append(f'권역 탈것 {iid}: 들이는 곳 {reg}이 그 권역 안전지대가 아님')
            mounts.append(dict(mount_id=iid, mount_name=mn, speed_multiplier=MOUNT['speed'], unlock_level=MOUNT['level'], unlock_region=reg, description=desc,
                               tier=MOUNT['tier'], passenger_capacity=MOUNT['passengers'], fare_tokens=MOUNT['fare']))
        elif kind == 'title':
            pass
        if not v.get('ready'):
            errors.append(f'권역 비고 {iid}: 아직 ready가 꺼져 있음')
    extra = {k for k, f in A['fur'].items()} - furn_ids
    if extra:
        errors.append('realm_furn.js에 비고에 없는 가구: ' + ', '.join(sorted(extra)))
    fresh('item_ids', [i['item_id'] for i in items], '권역 가구 id')
    fresh('items', [i['item_name'] for i in items], '권역 가구')
    fresh('cosmetics', [c['name'] for c in cos], '권역 꾸미기')
    if len({m['mount_name'] for m in mounts}) != len(mounts):
        errors.append('권역 탈것 이름 겹침')
    ic = [('item_id', 'text'), ('item_name', 'text'), ('category', 'text'), ('tier', 'int'), ('description', 'text'), ('stackable', 'boolean'), ('required_stats', 'jsonb'),
          ('minimum_level', 'int'), ('rarity', 'text'), ('acquisition_difficulty', 'int'), ('drop_rate_modifier', 'numeric'), ('equipment_traits', 'jsonb'),
          ('tradeable', 'boolean'), ('reference_price', 'bigint'), ('stack_size', 'int')]
    cols = ', '.join(c for c, _ in ic)
    typed = ', '.join(c + ' ' + t for c, t in ic)
    nv = len(RB['vault'])
    out = [f"""insert into public.world_item_catalog({cols})
select {', '.join('x.' + c for c, _ in ic)} from jsonb_to_recordset({J(items)}) as x({typed})
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = false, reference_price = excluded.reference_price, stack_size = 1;""",
           f"""insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, sort)
select x.k, x.kind, x.tier, x.name, x.cond, {J(RB['title_cat'])} #>> '{{}}', '{{"shop": "realm_bond"}}'::jsonb, false, x.sort
  from jsonb_to_recordset({J(cos)}) as x(k text, kind text, tier text, name text, cond text, sort int)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, tier = excluded.tier, category = excluded.category;""",
           f"""insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, unlock_faction, unlock_region, unlock_item, price, description, tier,
  passenger_capacity, fare_tokens, fare_free, acquire_method)
select x.mount_id, x.mount_name, x.speed_multiplier, x.unlock_level, 0, null, x.unlock_region, null, 0, x.description, x.tier, x.passenger_capacity, x.fare_tokens, false, 'event'
  from jsonb_to_recordset({J(mounts)}) as x(mount_id text, mount_name text, speed_multiplier numeric, unlock_level int, unlock_region text, description text, tier text,
    passenger_capacity int, fare_tokens int)
on conflict (mount_id) do update set mount_name = excluded.mount_name, speed_multiplier = excluded.speed_multiplier, unlock_level = excluded.unlock_level, unlock_region = excluded.unlock_region,
  description = excluded.description, tier = excluded.tier, passenger_capacity = excluded.passenger_capacity, fare_tokens = excluded.fare_tokens, acquire_method = 'event';"""]
    return out, f"""do $c$ declare v jsonb; begin
  for v in select x from jsonb_array_elements(public.world_realm_bond_rules() -> 'vault') x loop
    if not public.world_realm_bond_vault_ready(v) then raise exception '권역 비고 품목이 준비되지 않음: %', v ->> 'id'; end if;
  end loop;
  if (select count(*) from jsonb_array_elements(public.world_realm_bond_rules() -> 'vault')) <> {nv} then raise exception '권역 비고 품목 수가 맞지 않음'; end if;
  if exists (select 1 from public.world_item_catalog where item_id like 'hf\\_rb\\_%' and (tradeable or category <> 'furniture')) then raise exception '권역 가구 물품 행이 맞지 않음'; end if;
end $c$;""", dict(furn=len(items), cos=len(cos), mounts=len(mounts))
