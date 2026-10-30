"""꼬마 동무 데이터: assets/js/housing/pets.js(PETS)를 읽어 종·물품(바구니·알·먹이)·상점·출처·칭호·꾸미기를 만든다."""
import os

# 조건을 채워 바로 도감에 들어오는 동무(이름 앞부분으로 찾는다)
SOURCE_BY_NAME = [
    ('먹물 고양이', 'quest:sq_black_sand_temple_2'), ('새끼 구미호', 'quest:sq_red_forest_2'), ('아기 해태', 'quest:sq_iron_monastery_1'),
    ('구슬 이무기', 'quest:sq_sunken_palace_1'), ('아기 산군', 'quest:sq_thunder_peak_1'), ('달토끼', 'quest:sq_red_moon_fort_2'), ('목각 인형', 'quest:sq_nine_lighthouse_1'),
    ('아기 불가사리', 'title:craft_200'), ('삼족오', 'quest:sq_star_observatory_2'), ('아기 기린', 'quest:sq_white_tower_2'), ('꼬마 청룡', 'quest:sq_black_tide_rift_2'),
    ('꼬마 장승', 'quest:sq_sealed_abyss_1'), ('아기 백택', 'title:codex_100'), ('귀허 나비', 'gw_first'),
]
SRC_TEXT = {'quest': '퀘스트 「{}」을(를) 마친다', 'title': '칭호 「{}」을(를) 얻는다', 'gw_first': '귀허의 주인을 처음 쓰러뜨린다'}
QUEST_TITLE = {'sq_black_sand_temple_2': '빈 명부의 마지막 줄', 'sq_red_forest_2': '지지 않는 단풍', 'sq_iron_monastery_1': '잔도 위의 목탁', 'sq_sunken_palace_1': '수궁 문지기 교대',
               'sq_thunder_peak_1': '벼락이 굳힌 핵', 'sq_red_moon_fort_2': '달빛 끓이는 밤', 'sq_nine_lighthouse_1': '꺼진 등대에 다시 불을', 'sq_star_observatory_2': '내려오지 않은 별지기',
               'sq_white_tower_2': '마흔 해 깨어 있던 눈', 'sq_black_tide_rift_2': '거꾸로 떠도는 선원들', 'sq_sealed_abyss_1': '다시 감기는 사슬'}
TITLE_NAME = {'craft_200': '공방의 주인', 'codex_100': '만귀보'}
FOOD = [('pet_food', '동무 주먹밥', 10, '꼬마 동무가 먹는 작은 주먹밥. 별채에서 먹이면 친밀도가 오른다.'),
        ('treat_fish', '말린 생선포', 30, '꼬마 동무 별미. 생선을 좋아하는 동무가 반긴다.'),
        ('treat_rice', '쌀 강정', 30, '꼬마 동무 별미. 곡식을 좋아하는 동무가 반긴다.'),
        ('treat_honey', '꿀 약과', 50, '꼬마 동무 별미. 단것을 좋아하는 동무가 반긴다.'),
        ('treat_herb', '향긋한 풀단', 30, '꼬마 동무 별미. 풀과 잎을 좋아하는 동무가 반긴다.'),
        ('treat_meat', '육포 조각', 40, '꼬마 동무 별미. 고기를 좋아하는 동무가 반긴다.')]
TITLES = [
    ('hs_open', '별채 주인', 'home', '본부 객사 뒤뜰의 별채를 얻었다.', '「객사 별채」를 마쳐 별채를 얻는다', {'home': 'open', 'n': 1}, 1, False),
    ('hs_visit50', '발걸음이 잦은 집', 'home', '별채 문턱을 넘은 발걸음이 쉰을 넘었다.', '별채 발걸음 50', {'home': 'visits', 'n': 50}, 2, False),
    ('hs_guest20', '스무 손님의 방명록', 'home', '스무 사람이 별채 방명록에 이름을 남겼다.', '서로 다른 손님 20명이 방명록을 남긴다', {'home': 'guest', 'n': 20}, 3, False),
    ('hs_size9', '아홉 칸 별채', 'home', '별채를 가장 넓게 넓혔다.', '별채를 9×9로 넓힌다', {'home': 'size', 'n': 9}, 3, False),
    ('hs_furn30', '가구 수집가', 'home', '서른 가지 가구를 모았다.', '가구 30가지를 모은다', {'home': 'furn', 'n': 30}, 3, False),
    ('hs_visit300', '문턱이 닳은 집', 'home', '별채 문턱이 반들반들 닳았다.', '별채 발걸음 300', {'home': 'visits', 'n': 300}, 4, False),
    ('hs_furn60', '별채의 장인', 'home', '야행국의 가구를 거의 다 모았다.', '가구 60가지를 모은다', {'home': 'furn', 'n': 60}, 5, True),
    ('pet_5', '동무 다섯', 'heart', '꼬마 동무 다섯과 함께한다.', '꼬마 동무 5마리를 모은다', {'home': 'pets', 'n': 5}, 2, False),
    ('pet_adult5', '잘 키운 동무들', 'heart', '꼬마 동무 다섯을 다 자라게 했다.', '꼬마 동무 5마리를 다 자라게 한다', {'home': 'adult', 'n': 5}, 3, False),
    ('pet_15', '동무 열다섯', 'heart', '꼬마 동무 열다섯과 함께한다.', '꼬마 동무 15마리를 모은다', {'home': 'pets', 'n': 15}, 3, False),
    ('pet_legend', '상서로운 짐승의 벗', 'heart', '신품 꼬마 동무와 벗이 되었다.', '신품 꼬마 동무를 얻는다', {'home': 'pet_grade', 'g': 5, 'n': 1}, 5, False),
    ('pet_30', '모든 동무의 벗', 'heart', '야행국의 꼬마 동무 서른을 모두 만났다.', '꼬마 동무 30마리를 모두 모은다', {'home': 'pets', 'n': 30}, 5, True),
]
COSMETICS = [
    ('fr_home', 'frame', 'legend', '처마 끝 테', '가구 20가지를 모은다', {'home': 'furn', 'n': 20}),
    ('pt_home', 'pattern', 'rare', '단청 무늬', '별채를 8×8로 넓힌다', {'home': 'size', 'n': 8}),
    ('sl_dong', 'seal', 'rare', '낙관 「同」', '꼬마 동무 10마리를 모은다', {'home': 'pets', 'n': 10}),
]


def emit(w, J, node_dump):
    P = node_dump("""
const P = await import('./assets/js/housing/pets.js');
const o = {}; let i = 0;
for (const [k, v] of Object.entries(P.PETS)) o[k] = { name: v.name, grade: v.grade, kind: v.kind, likes: v.likes, desc: v.desc, sort: i++ };
console.log(JSON.stringify(o));
""")
    assert len(P) == 30, f'꼬마 동무는 30종이어야 합니다(지금 {len(P)})'
    src = {}
    for pre, s in SOURCE_BY_NAME:
        hit = [k for k, v in P.items() if v['name'].startswith(pre)]
        assert len(hit) == 1, (pre, hit)
        src[hit[0]] = s
    species, items, sources, shop = [], [], [], []
    for k, v in P.items():
        g = v['grade']
        if k in src:
            s = src[k]; kind = s.split(':')[0]
            how = SRC_TEXT[kind].format(QUEST_TITLE.get(s.split(':')[-1]) or TITLE_NAME.get(s.split(':')[-1], '')) if ':' in s else SRC_TEXT[kind]
            if g == 3: how += ' · 빛나는 알'
            sources.append(dict(source=s, pet_id=k))
        elif g == 1:
            how = '안전지대 상점의 바구니'
            items.append(dict(item_id='pt_' + k, item_name=v['name'] + ' 바구니', tier=1, description=v['desc'] + ' 쓰면 꼬마 동무가 된다(한 종은 한 번만).',
                              equipment_traits={'pet': k}, tradeable=True, reference_price=300, stack_size=1, category='pet'))
            shop.append('pt_' + k)
        elif g == 2:
            how = '탐색 중 「얼룩무늬 알」'
        else:
            how = '탐색 중 「빛나는 알」'
        species.append(dict(pet_id=k, pet_name=v['name'], grade=g, kind=v['kind'], likes=v['likes'], how=how, sort=v['sort'], egg=g in (2, 3)))
    items.append(dict(item_id='pet_egg_2', item_name='얼룩무늬 알', tier=2, description='탐색하다 주운 따뜻한 알. 쓰면 아직 만나지 못한 양품 꼬마 동무가 태어난다.',
                      equipment_traits={'egg': 2}, tradeable=True, reference_price=400, stack_size=5, category='pet'))
    items.append(dict(item_id='pet_egg_3', item_name='빛나는 알', tier=3, description='안쪽에서 은은한 빛이 새는 알. 쓰면 아직 만나지 못한 진품 꼬마 동무가 태어난다.',
                      equipment_traits={'egg': 3}, tradeable=True, reference_price=1500, stack_size=5, category='pet'))
    for iid, nm, pr, ds in FOOD:
        items.append(dict(item_id=iid, item_name=nm, tier=1, description=ds, equipment_traits={'pet_food': True}, tradeable=True, reference_price=pr, stack_size=20, category='consumable'))
    w(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'p_pets.sql')).read())
    w(f"""
-- ─── 꼬마 동무 30종 · 바구니·알·먹이 ───
insert into public.world_pet_species(pet_id, pet_name, grade, kind, likes, how, sort, egg)
select x.pet_id, x.pet_name, x.grade, x.kind, x.likes, x.how, x.sort, x.egg from jsonb_to_recordset({J(species)}) as x(pet_id text, pet_name text, grade int, kind text, likes text, how text, sort int, egg boolean)
on conflict (pet_id) do update set pet_name = excluded.pet_name, grade = excluded.grade, kind = excluded.kind, likes = excluded.likes, how = excluded.how, sort = excluded.sort, egg = excluded.egg;
delete from public.world_pet_sources;
insert into public.world_pet_sources(source, pet_id) select x.source, x.pet_id from jsonb_to_recordset({J(sources)}) as x(source text, pet_id text);
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
select x.item_id, x.item_name, x.category, x.tier, x.description, x.stack_size > 1, '{{}}'::jsonb, 1, x.equipment_traits, x.tradeable, x.reference_price, x.stack_size
  from jsonb_to_recordset({J(items)}) as x(item_id text, item_name text, category text, tier int, description text, equipment_traits jsonb, tradeable boolean, reference_price int, stack_size int)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;
-- 상점: 주먹밥·별미 다섯은 모든 상점, 범품 바구니는 상점마다 두 가지씩
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, f.item_id, f.price, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join jsonb_to_recordset({J([dict(item_id=i, price=p) for i, _, p, _ in FOOD])}) as f(item_id text, price int)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, x.item_id, 300, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join lateral (select y.item_id from jsonb_array_elements_text({J(shop)}) as y(item_id) order by md5(s.shop_id || y.item_id) limit 2) x
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;
-- 요리: 말린 생선포(손질한 생선 2 → 3개)
insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, required_skill, required_skill_rank, craft_field)
values ('r_treat_fish', '말린 생선포 만들기', 'treat_fish', 3, '{{"fish_fillet": 2}}'::jsonb, null, 1, null, '손질한 생선을 말려 꼬마 동무 별미를 만든다.', 1, null, 1, null, 1, 'cooking')
on conflict (recipe_id) do update set ingredients = excluded.ingredients, output_qty = excluded.output_qty;
-- 칭호(효과 없음)·꾸미기: 별채·꼬마 동무
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade)
select x.k, x.n, x.i, x.d, x.c, '{{}}'::jsonb, true, x.h, x.r, 1400 + x.o, '별채', x.g
  from jsonb_to_recordset({J([dict(k=k, n=n, i=i, d=d, c=c, r=r, g=g, h=h, o=o) for o, (k, n, i, d, c, r, g, h) in enumerate(TITLES)])}) as x(k text, n text, i text, d text, c text, r jsonb, g int, h boolean, o int)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, rule = excluded.rule,
  category = excluded.category, grade = excluded.grade, hidden = excluded.hidden, bonus = excluded.bonus;
insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort)
select x.k, x.kind, x.t, x.n, x.c, '별채', x.r, false, true, 1400 + x.o
  from jsonb_to_recordset({J([dict(k=k, kind=kd, t=t, n=n, c=c, r=r, o=o) for o, (k, kd, t, n, c, r) in enumerate(COSMETICS)])}) as x(k text, kind text, t text, n text, c text, r jsonb, o int)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, category = excluded.category;
""")
