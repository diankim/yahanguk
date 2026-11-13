TERR = ('mukjeok', '묵적 봉쇄령')
FERRY = 'mukchang_ferry'
LV7 = 42
TOOL_LV = 40

REGIONS = [
    dict(id='mukchang_ferry', name='묵창 나루', type='village', danger=9, lv=40, x=310, y=128, el=0, nb=['frost_valley', 'blank_field'],
         theme='water', safe=True, desc='먹빛 강을 건너는 나룻배가 닿는 작은 나루. 문패마다 글자가 반쯤 지워져 있고, 사람들은 서로를 사는 자리로 부른다.',
         rest=('묵창 주막 객방', 'inn', 160, 2), shop=('mukchang_shop', '묵창 주막')),
    dict(id='blank_field', name='빈칸 벌판', type='wilderness', danger=10, lv=41, entry=40, x=222, y=168, el=0, nb=['mukchang_ferry', 'meokbi_forest'],
         theme='wild', desc='이름이 거둬지고 정리되지 못한 먹귀들이 모여드는 벌판. 풀잎마다 지워진 글자의 얼룩이 묻어 있다.'),
    dict(id='meokbi_forest', name='먹비 숲', type='forest', danger=10, lv=42, x=148, y=222, el=1, nb=['blank_field', 'myeongbu_tower'],
         theme='wild', desc='먹물 같은 비가 그치지 않는 숲. 잎에 맺힌 빗방울을 손등에 받으면 남의 꿈이 비친다.'),
    dict(id='myeongbu_tower', name='명부 탑', type='archive', danger=10, lv=44, x=118, y=122, el=3, nb=['meokbi_forest', 'nine_court'],
         theme='shrine', desc='정청이 거둔 이름의 원부를 쌓아 두던 옛 탑. 층마다 죽간이 무너져 내려 먹귀가 모여 산다.'),
    dict(id='nine_court', name='아홉 칸 뜰', type='haunted_garden', danger=10, lv=45, x=52, y=172, el=0, nb=['myeongbu_tower'],
         theme='shrine', desc='명부 탑 아래, 바닥에 아홉 칸 진이 그려진 뜰. 가운데 칸의 먹은 아직 마르지 않았다.'),
]

NODES = {
    'mukchang_ferry': [['나루 어귀 선창'], ['주막 앞 평상', '문패 지운 골목']],
    'blank_field': [
        ['벌판 들머리 둔덕'],
        ['흰 억새 들', '먹 얼룩 진 둑길'],
        ['이름 없는 사당 터', '지운 문패 무더기', '빈 허수아비 밭', '먹물 고인 고랑'],
        ['까마귀 앉은 장승', '끊어진 명줄 말뚝', '바람 멎은 풀밭', '흐린 글씨 비석', '먹귀 모이는 웅덩이', '쓰러진 이정표'],
        ['한가운데 빈 무덤', '지운 이름 쌓인 언덕', '먹비 스민 구렁', '마른 붓 꽂힌 자리', '흰 들꽃 빈자리', '손자국 남은 바위', '부르다 만 고개', '벌판 끝 낭떠러지'],
    ],
    'meokbi_forest': [
        ['숲 들머리 비가림'],
        ['검은 잎 오솔길', '빗물 고인 덤불'],
        ['흑단 고목 숲길', '옛 조사원 숙소', '꿈 비치는 웅덩이', '먹 젖은 이끼 둔덕'],
        ['붓끝 같은 가지 숲', '빗소리 그친 빈터', '무너진 정자 터', '먹물 흐르는 개울', '젖은 서책 더미', '흑단 뿌리 굴'],
        ['비가 처음 내린 자리', '벽에 이름 쓴 방', '먹그림자 서는 언덕', '마른 잎 하나 없는 숲', '꿈이 끊기는 곳', '꺼진 등불 가지', '숲의 가장 깊은 그늘', '빗줄기 멎은 샘'],
    ],
    'myeongbu_tower': [
        ['탑 아래 돌계단'],
        ['첫째 층 서고', '무너진 회랑'],
        ['죽간 쏟아진 층', '먹 갈던 방', '대조하던 서안', '좁은 나선 계단'],
        ['이름 묶은 서가', '창 없는 열람실', '회수 명부 보관함', '먹물 마른 우물방', '봉인된 문', '꼭대기 아래 층'],
        ['탑 꼭대기 누각', '마지막 서가', '지워진 원부 더미', '바람 드는 창틀', '죽간 엮던 자리', '먹귀 엉킨 다락', '하늘 보이는 지붕', '서리의 빈 의자'],
    ],
    'nine_court': [
        ['뜰 어귀 돌문'],
        ['첫째 칸', '둘째 칸'],
        ['셋째 칸', '넷째 칸', '다섯째 칸', '여섯째 칸'],
        ['일곱째 칸', '여덟째 칸', '진 그린 바닥 가장자리', '마르지 않은 먹 자국', '돌 주춧돌 줄', '탑 그늘 아래'],
        ['아홉째 칸', '가운데 칸', '매듭 바깥 금', '진의 첫 획', '진의 마지막 획', '지워진 칸 자리', '이름 부르던 자리', '뜰 끝 우물'],
    ],
}

SPOT_ADJ = {
    'mukchang_ferry': ['문패 지운', '먹빛 젖은'],
    'blank_field': ['이름 지운', '먹 얼룩 진', '흰 억새 덮인', '바람 멎은', '빈칸 남은', '글씨 번진', '까마귀 우는', '끊어진 명줄의', '흐린 들꽃 핀', '지워진 발자국의', '먹물 스민'],
    'meokbi_forest': ['먹비 젖은', '흑단 그늘 진', '빗소리 나는', '꿈 비치는', '검은 잎 덮인', '이끼 낀', '안개 고인', '젖은 서책 흩어진', '빗방울 맺힌', '붓끝 같은', '먹 번진'],
    'myeongbu_tower': ['죽간 쏟아진', '먹 마른', '원부 쌓인', '서리 앉은', '창 없는', '봉인 벗겨진', '먹귀 엉킨', '바람 드는', '서가 기운', '이름 묶인', '붓 꺾인'],
    'nine_court': ['진 그려진', '칸 나뉜', '먹 마르지 않은', '주춧돌 놓인', '획 끊어진', '탑 그늘 진', '매듭 맺힌', '돌 깔린', '지워진 칸의', '이름 새긴', '우물 곁'],
}
SPOT_NOUN = {
    'relics': ['문패 조각 더미', '지운 명패 무덤', '부서진 위패 상자', '먹 바랜 족자 틈', '깨진 현판 자리'],
    'water': ['먹물 여울목', '갈대 먹 고랑', '검은 물웅덩이', '먹 가라앉은 개울', '젖은 갈대밭'],
    'supplies': ['버려진 서리 짐', '빈 종이 궤짝', '주인 잃은 봇짐', '흩어진 한지 꾸러미', '무너진 초막'],
    'herbs': ['먹비 이끼 바위', '검은 약풀 둔덕', '젖은 고사리 그늘', '이끼 덮인 그루터기', '약초 자란 비탈'],
    'wood': ['흑단 고목', '쓰러진 흑단 둥치', '붓대 같은 나무숲', '젖은 장작 더미', '검은 가지 덤불'],
    'spirit': ['넋 맺힌 돌', '먹귀 앉았던 자리', '이름 흐르는 샘', '혼불 고인 구렁', '흐느끼는 비석'],
    'ore': ['검은 쇳돌 맥', '명부 철 노두', '주춧돌 밑 광맥', '먹 밴 바위 틈', '쇳물 굳은 자리'],
}
SPOT_LOOT = {
    'mukchang_ferry': {'supplies': ['herb', 'travel_ration', 'tonic'], 'water': ['river_reed', 'river_reed', 'mukchang_ink']},
    'blank_field': {'relics': ['seal_paper', 'inkstone', 'erased_plate', 'erased_plate'], 'water': ['river_reed', 'river_reed', 'mukchang_ink'],
                    'supplies': ['herb', 'travel_ration', 'blank_hanji', 'blank_hanji'], 'herbs': ['herb', 'medicine_base', 'moon_moss']},
    'meokbi_forest': {'herbs': ['herb', 'medicine_base', 'meokbi_moss', 'meokbi_moss'], 'wood': ['wood', 'resin', 'meokbi_ebony', 'meokbi_ebony'],
                      'spirit': ['spirit_dust', 'ghost_ash', 'meokbi_moss'], 'supplies': ['herb', 'travel_ration', 'tonic']},
    'myeongbu_tower': {'relics': ['seal_paper', 'inkstone', 'register_slip', 'register_slip'], 'spirit': ['spirit_dust', 'ghost_ash', 'register_slip'],
                       'ore': ['ore', 'raw_iron', 'erased_plate'], 'supplies': ['herb', 'travel_ration', 'blank_hanji']},
    'nine_court': {'ore': ['ore', 'raw_iron', 'erased_plate'], 'spirit': ['spirit_dust', 'spirit_core', 'register_slip'],
                   'relics': ['seal_paper', 'register_slip', 'erased_plate'], 'water': ['river_reed', 'mukchang_ink', 'meokbi_moss']},
}
ENTRY_SPOT = {'mukchang_ferry': ('어귀의 먹빛 갈대밭', 'water'), 'blank_field': ('어귀의 흰 억새 물가', 'water'),
              'meokbi_forest': ('어귀의 흑단 비가림', 'wood'), 'myeongbu_tower': ('어귀의 무너진 죽간 더미', 'relics'),
              'nine_court': ('어귀의 돌문 밑 쇳돌', 'ore')}

MONSTERS = {
    'blank_field': [
        ('mk_field_1', '떠도는 먹귀', '원령', 'common', 'ghost', 'spectral', '거둬진 이름의 미련이 먹물 꼴로 굳었다. 지나는 이의 소매를 붙들고 「기억해 줘」라고 속삭인다.', {'drifting_name_thread': 1, 'meokgwi_lump': 1}),
        ('mk_field_2', '빈칸 까마귀 떼', '비행 요괴', 'common', 'bird', 'aerial', '지운 문패의 글자를 쪼아 먹는 까마귀 떼. 한 마리가 울면 하늘이 새카매진다.', {'blank_hanji': 1, 'meokgwi_lump': 1}),
        ('mk_field_3', '문패 뜯는 손', '매복 요괴', 'main', 'shadow', 'ambush', '억새 그늘에 숨어 있다가 문패를 뜯듯 사람의 이름을 잡아챈다.', {'erased_plate': 2, 'drifting_name_thread': 2, 'meokgwi_lump': 1}),
        ('mk_field_4', '먹물 두꺼비', '독충', 'main', 'venom', 'toxic', '고랑에 고인 먹물을 마시고 부풀어 오른 두꺼비. 내뿜는 숨에 독이 섞였다.', {'mukchang_ink': 2, 'venom_gland': 1, 'drifting_name_thread': 1}),
        ('mk_field_5', '이름 걸린 허수아비', '지역 우두머리', 'guardian', 'giant', 'boss', '벌판 한가운데 선 거대한 허수아비. 몸에 지운 문패를 수백 장 매달았다.', {'erased_plate': 3, 'drifting_name_thread': 2, 'spirit_core': 1}),
    ],
    'meokbi_forest': [
        ('mk_forest_1', '먹비 넋', '수귀', 'common', 'water', 'tide', '빗물에 섞여 내리는 넋. 발목을 감고 웅덩이로 끌어당긴다.', {'meokbi_moss': 1, 'meokgwi_lump': 1}),
        ('mk_forest_2', '흑단 덩굴귀', '목령', 'common', 'wood', 'toxic', '흑단 가지에 붙어 사는 덩굴 요괴. 가시에 먹물 독이 배었다.', {'meokbi_ebony': 1, 'meokgwi_lump': 1}),
        ('mk_forest_3', '먹비 반딧불 떼', '무리 요괴', 'main', 'swarm', 'swarm', '남의 꿈을 한 조각씩 물고 나는 검은 반딧불. 떼로 몰려와 눈을 가린다.', {'meokbi_moss': 2, 'drifting_name_thread': 2, 'meokgwi_lump': 1}),
        ('mk_forest_4', '먹 먹은 목장승', '갑각 요괴', 'main', 'shell', 'armored', '먹비를 백 년 맞아 돌처럼 굳은 장승. 새긴 이름이 지워져 누구를 지키는지 모른다.', {'meokbi_ebony': 2, 'monster_core': 1, 'drifting_name_thread': 1}),
        ('mk_forest_5', '꺾인 붓 고목', '지역 우두머리', 'guardian', 'breaker', 'seal_breaker', '붓대처럼 곧던 고목이 꺾인 자리에서 요괴가 되었다. 가지를 흔들 때마다 봉인 먹이 번진다.', {'meokbi_ebony': 3, 'drifting_name_thread': 2, 'spirit_core': 1}),
    ],
    'myeongbu_tower': [
        ('mk_tower_1', '명부 갈피귀', '결계 요괴', 'common', 'ward', 'warded', '죽간 사이에 끼어 사는 요괴. 갈피마다 금줄을 둘러 몸을 감싼다.', {'register_slip': 1, 'meokgwi_lump': 1}),
        ('mk_tower_2', '탑 꼭대기 번갯불', '천상 요괴', 'common', 'sky', 'aerial', '탑 꼭대기에 떨어진 번개가 흩어지지 않고 남았다. 창틀을 타고 내리꽂힌다.', {'star_sand': 1, 'meokgwi_lump': 1}),
        ('mk_tower_3', '거울 명부', '거울 요괴', 'main', 'mirror', 'reflect', '이름 대신 얼굴을 비춰 적는 명부. 공격을 받으면 그 모습을 되비춘다.', {'register_slip': 2, 'mirror_shard': 2, 'drifting_name_thread': 1}),
        ('mk_tower_4', '이름 지우는 서리귀', '원령', 'main', 'ghost', 'spectral', '평생 명부의 이름을 지우던 서리의 넋. 지금도 붓을 들고 탑을 오르내린다.', {'register_slip': 2, 'ghost_ash': 3, 'drifting_name_thread': 1}),
        ('mk_tower_5', '엉킨 먹귀 무리', '지역 우두머리', 'guardian', 'swarm', 'swarm', '탑 꼭대기에 모인 마지막 먹귀들이 서로 엉켜 한 덩어리가 되었다.', {'register_slip': 3, 'drifting_name_thread': 2, 'spirit_core': 1}),
    ],
    'nine_court': [
        ('mk_court_1', '칸 지키는 돌거북', '갑각 요괴', 'common', 'shell', 'armored', '진의 칸마다 엎드린 돌거북. 등에 새긴 글자가 반쯤 지워졌다.', {'erased_plate': 1, 'meokgwi_lump': 1}),
        ('mk_court_2', '지워진 칸의 그림자', '매복 요괴', 'common', 'shadow', 'ambush', '먹이 벗겨진 칸에서 일어서는 그림자. 밟는 순간 발목을 잡는다.', {'register_slip': 1, 'meokgwi_lump': 1}),
        ('mk_court_3', '우물가 먹귀', '수귀', 'main', 'water', 'tide', '뜰 끝 우물에서 기어 나오는 먹귀. 물살처럼 몸을 펴 사람을 우물로 당긴다.', {'mukchang_ink': 2, 'drowned_scale': 1, 'drifting_name_thread': 1}),
        ('mk_court_4', '진 그리는 손', '파봉 요괴', 'main', 'breaker', 'seal_breaker', '바닥의 진을 고쳐 그리려는 손 하나. 그릴 때마다 봉인이 비틀린다.', {'register_slip': 2, 'ward_fragment': 2, 'drifting_name_thread': 1}),
        ('mk_court_5', '아홉째 칸의 먹귀', '지역 우두머리', 'guardian', 'giant', 'boss', '아홉째 칸에 묶인 채 커다랗게 부푼 먹귀. 몸에서 이름들이 흘러내린다.', {'register_slip': 3, 'drifting_name_thread': 2, 'spirit_core': 1}),
    ],
}

GROUNDS = {
    'blank_field': [('흰 억새 들머리', '억새가 먹 얼룩을 덮어 주는 바깥 들판.'), ('지운 문패 고랑', '뜯긴 문패가 고랑마다 쌓인 벌판 안쪽.'), ('부르다 만 고개', '누군가 이름을 부르다 멈춘 벌판 끝.')],
    'meokbi_forest': [('비가림 숲길', '먹비가 덜 들이치는 바깥 숲길.'), ('흑단 고목 숲', '꿈이 비치는 웅덩이가 이어진 숲 안쪽.'), ('비가 처음 내린 자리', '먹비가 그치지 않는 숲의 가장 깊은 곳.')],
    'myeongbu_tower': [('무너진 아래층', '죽간이 쏟아져 내린 탑 아래층.'), ('회수 명부 층', '거둔 이름을 묶어 둔 서가가 늘어선 층.'), ('탑 꼭대기 누각', '마지막 먹귀들이 엉켜 있는 꼭대기.')],
    'nine_court': [('뜰 가장자리', '진의 바깥 금을 따라 도는 길.'), ('넷째 칸에서 여섯째 칸', '먹이 반쯤 마른 진의 안쪽.'), ('가운데 칸 앞', '매듭 안쪽으로 이어진 진의 한가운데.')],
}

FISH = [
    ('mukchang_ferry', 'river', '먹물 여울', '먹빛 강물이 나루 앞에서 여울져 흐릅니다. 찌가 먹물에 반쯤 잠깁니다.'),
    ('mukchang_ferry', 'sea', '묵창 앞바다', '나루 끝 선창 너머로 검푸른 바다가 열립니다. 물결마다 지워진 글자 같은 무늬가 일렁입니다.'),
    ('blank_field', 'marsh', '번진 먹 늪', '먹이 번진 늪. 물풀 사이로 무언가 천천히 지나갑니다.'),
    ('meokbi_forest', 'lake', '먹비 고인 못', '먹비가 고여 생긴 못. 빗방울이 떨어질 때마다 남의 꿈이 비쳤다 사라집니다.'),
    ('myeongbu_tower', 'canal', '탑 밑 먹 수로', '탑 아래로 먹물 섞인 물이 흐르는 수로. 죽간 조각이 떠내려옵니다.'),
    ('nine_court', 'deep', '아홉째 칸 우물', '뜰 끝의 깊은 우물. 낚싯줄을 다 풀어도 바닥에 닿지 않습니다.'),
]
SEA_FISH_REGIONS = ['mukchang_ferry']
CLIMATE = {'drizzle': 20, 'cloudy': 18, 'rain': 16, 'fog': 18, 'clear': 14, 'wind': 14}

PROFILES = {
    'mukchang_ferry': ('물가·나루', '나루 사람들·정청 서리', '묵창 나루의 문패: 글자가 반쯤 지워져 사는 자리로만 서로를 부른다.', '묵창 나루 고유 사건: 주민 명부에서 이름이 하나둘 흐려진다.', '이름 흐림·비싼 물자', '먹빛 강, 반쯤 지워진 문패, 주막 등불'),
    'blank_field': ('들판·초원', '먹귀와 흑련회 거둠꾼', '빈칸 벌판의 문패 무더기: 뜯긴 문패마다 지운 이름의 획이 남았다.', '빈칸 벌판 고유 사건: 먹귀를 풀어 보내면 그 기억이 손등에 먹으로 남는다.', '이름 흐림·매복·독', '흰 억새, 먹 얼룩, 이름 걸린 허수아비'),
    'meokbi_forest': ('숲·먹비', '꿈을 무는 요괴들', '먹비 숲의 숙소 벽: 옛 조사원이 쓴 이름이 먹비에 번져 읽히지 않는다.', '먹비 숲 고유 사건: 빗방울을 받으면 남의 꿈이 비친다.', '이름 흐림·환영·물살', '그치지 않는 먹비, 흑단 고목, 꿈 비치는 웅덩이'),
    'myeongbu_tower': ('탑·서고', '서리의 넋과 엉킨 먹귀', '명부 탑의 원부: 거둔 이름의 작성자 칸만 먹이 번져 있다.', '명부 탑 고유 사건: 꼭대기에 먹귀가 엉켜 한 덩어리가 되었다.', '이름 흐림·결계·거울', '쏟아진 죽간, 나선 계단, 바람 드는 누각'),
    'nine_court': ('뜰·진법', '진에 묶인 먹귀', '아홉 칸 뜰의 진: 가운데 칸의 먹이 아직 마르지 않았다.', '아홉 칸 뜰 고유 사건: 아홉째 칸에 묶인 먹귀가 커다랗게 부풀었다.', '이름 흐림·봉인·우물', '아홉 칸 진, 주춧돌 줄, 끝 모를 우물'),
}
LORE = {
    'mukchang_ferry': ['먹빛 강을 건너는 나룻배가 닿는 작은 나루입니다. 문패마다 글자가 반쯤 지워져 있고, 물가에 매인 배의 이름도 읽을 수 없습니다.',
                       '나루 사람들은 서로를 이름 대신 사는 자리로 부릅니다. 주막 한 채가 가게와 숙소를 겸하고, 그 구석 등불 아래에서 정청 서리가 명부를 대조하고 있습니다.'],
    'blank_field': ['빈칸 벌판입니다. 흰 억새가 끝없이 이어지고, 풀잎마다 지워진 글자의 얼룩이 묻어 있습니다.',
                    '이름이 거둬진 뒤 갈 곳을 잃은 먹귀들이 이곳으로 모여듭니다. 바람이 멎으면 누군가 「기억해 줘」라고 속삭이는 소리가 들립니다.'],
    'meokbi_forest': ['먹비 숲입니다. 먹물 같은 비가 그치지 않습니다. 잎에 맺힌 빗방울을 손등에 받으면 남의 꿈이 비칩니다.',
                      '숲 안쪽 어딘가에 옛 정청 조사원이 머물던 숙소가 있다고 합니다. 그가 누구였는지는 아무도 기억하지 못합니다.'],
    'myeongbu_tower': ['명부 탑입니다. 정청이 거둔 이름의 원부를 쌓아 두던 옛 탑입니다. 층마다 죽간이 무너져 내려 계단을 덮었습니다.',
                       '원부의 작성자 칸만 하나같이 먹이 번져 있습니다. 탑 꼭대기에서는 엉킨 먹귀들이 서로를 부르는 소리가 내려옵니다.'],
    'nine_court': ['아홉 칸 뜰입니다. 명부 탑 아래 바닥에 아홉 칸 진이 그려져 있습니다. 가운데 칸의 먹은 아직 마르지 않았습니다.',
                   '칸을 하나 밟을 때마다 누군가의 기억이 발밑에서 올라옵니다. 뜰 끝의 우물은 바닥이 보이지 않습니다.'],
}

SITES = {
    'blank_field': [('relic', '빈칸 벌판 · 이름 없는 사당', ['seal_paper', 'inkstone', 'erased_plate', 'ghost_ash', 'ward_fragment'], ['erased_plate', 'drifting_name_thread', 'meokgwi_lump']),
                    ('supply', '빈칸 벌판 · 버려진 서리 짐', ['herb', 'travel_ration', 'tonic', 'blank_hanji', 'seal_paper'], ['blank_hanji', 'drifting_name_thread', 'meokgwi_lump']),
                    ('medical', '빈칸 벌판 · 억새 속 약막', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', 'blank_hanji', 'meokgwi_incense'])],
    'meokbi_forest': [('relic', '먹비 숲 · 옛 조사원 숙소', ['seal_paper', 'inkstone', 'meokbi_moss', 'ward_fragment'], ['meokbi_moss', 'drifting_name_thread', 'spirit_core']),
                      ('medical', '먹비 숲 · 비 피하던 약초막', ['herb', 'medicine_base', 'tonic', 'meokbi_moss', 'herbal_extract'], ['meokbi_moss', 'herbal_extract', 'meokbi_umbrella']),
                      ('supply', '먹비 숲 · 젖은 서책 더미', ['herb', 'travel_ration', 'wood', 'meokbi_ebony'], ['meokbi_ebony', 'drifting_name_thread', 'meokgwi_lump'])],
    'myeongbu_tower': [('relic', '명부 탑 · 회수 명부 보관함', ['seal_paper', 'inkstone', 'register_slip', 'ward_fragment'], ['register_slip', 'spirit_core', 'drifting_name_thread']),
                       ('supply', '명부 탑 · 먹 갈던 방', ['herb', 'travel_ration', 'tonic', 'mukchang_ink', 'register_slip'], ['mukchang_ink', 'register_slip', 'meokgwi_lump']),
                       ('medical', '명부 탑 · 서리의 약 상자', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', 'name_ink_charm', 'register_slip'])],
    'nine_court': [('abyss', '아홉 칸 뜰 · 뜰 끝 우물', ['erased_plate', 'register_slip', 'ward_fragment', 'spirit_dust', 'travel_ration'], ['register_slip', 'drifting_name_thread', 'spirit_core']),
                   ('relic', '아홉 칸 뜰 · 진의 첫 획', ['seal_paper', 'ward_fragment', 'register_slip', 'ghost_ash'], ['spirit_core', 'drifting_name_thread', 'meokgwi_lump']),
                   ('medical', '아홉 칸 뜰 · 주춧돌 아래 약 단지', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', 'name_ink_charm', 'revival_charm'])],
}

ITEMS = [
    ('erased_plate', '지워진 문패 조각', 'material', 4, 40, 380, True, 40, '글자를 긁어 지운 문패 조각. 지운 자리에 이름의 획이 희미하게 남았다.'),
    ('mukchang_ink', '묵창 갈대 먹', 'material', 4, 40, 360, True, 40, '먹빛 강가 갈대 뿌리에 엉긴 먹. 물에 풀어도 번지지 않는다.'),
    ('blank_hanji', '빈칸 한지', 'material', 4, 40, 360, True, 40, '빈칸 벌판에 흩어진 서리 짐에서 나온 한지. 무엇을 적어도 한 칸은 비어 있다.'),
    ('drifting_name_thread', '떠도는 이름 실', 'material', 4, 40, 420, True, 40, '먹귀를 풀어 보낼 때 남는 가는 실. 7단계 장비의 심이 된다.'),
    ('meokbi_moss', '먹비 이끼', 'material', 4, 40, 380, True, 40, '먹비를 맞고 자란 검은 이끼. 달여 마시면 남의 꿈을 덜 꾼다.'),
    ('meokbi_ebony', '먹비 흑단', 'material', 4, 40, 420, True, 40, '먹비를 백 년 맞은 흑단. 결이 붓털처럼 곧다.'),
    ('register_slip', '명부 죽간', 'material', 4, 40, 440, True, 40, '명부 탑에서 무너져 내린 죽간. 거둔 이름이 한 줄씩 적혀 있다.'),
    ('meokgwi_lump', '먹귀 응어리', 'material', 3, 40, 300, True, 40, '풀어 보낸 먹귀가 남긴 먹 덩어리. 쥐면 누군가의 기억이 손바닥에서 식는다.'),
    ('carp_glue', '잉어 비늘 아교', 'material', 3, 40, 120, True, 30, '수문 잉어 비늘을 고아 만든 아교. 7단계 생활 도구와 방어구를 붙인다.'),
    ('bronze_scale_plate', '청동 비늘 판', 'material', 4, 40, 260, True, 30, '청동 메기 비늘을 쇠에 덧대어 두드린 판. 7단계 방어구와 곡괭이의 재료.'),
    ('shad_oil', '샛비늘 기름', 'material', 3, 40, 110, True, 30, '잿빛 샛비늘치에서 짠 기름. 불을 붙이면 먹귀가 싫어하는 냄새가 난다.'),
    ('bitterling_ink', '납자루 먹물', 'material', 2, 40, 45, True, 24, '먹점 납자루가 뱉는 먹물을 모은 것. 봉인 먹과 부적에 섞는다.'),
    ('rainproof_oil', '먹비 막이 기름', 'material', 5, 40, 900, False, 40, '먹비 대산천어 기름으로 만든 방수 기름. 7단계 방어구 최상위 재료.'),
    ('name_ink_charm', '이름 먹 부적', 'consumable', 4, 20, 520, True, 40, '묵창 갈대 먹으로 제 이름을 적어 품는 부적. 1시간 동안 이름 흐림을 한 단계 가볍게 한다(침식 30 아래면 막는다).'),
    ('meokgwi_incense', '먹귀 쫓는 향', 'consumable', 4, 20, 480, True, 40, '샛비늘 기름과 먹비 이끼를 섞어 빚은 향. 1시간 동안 요괴와 덜 마주친다.'),
    ('meokbi_umbrella', '먹비 우산', 'consumable', 4, 20, 460, True, 40, '먹비 흑단 살에 빈칸 한지를 바른 우산. 1시간 동안 받는 피해가 준다.'),
]

STATUSES = [
    ('clear_name', '또렷한 이름', 'positive', 120, {}, 'spark', '제 이름이 또렷이 새겨져 있습니다. 묵적 봉쇄령의 이름 흐림이 한 단계 가볍고, 침식 30 아래면 걸리지 않습니다.'),
    ('name_ward', '이름 지킴', 'positive', 60, {}, 'shield', '이름 먹 부적이 이름을 지킵니다. 묵적 봉쇄령의 이름 흐림이 한 단계 가볍고, 침식 30 아래면 걸리지 않습니다.'),
    ('meokgwi_repel', '먹귀 쫓김', 'positive', 60, {'encounter_pct': -20, 'mental_loss_pct': -5}, 'flame', '먹귀 쫓는 향 냄새가 배어 요괴와 덜 마주칩니다.'),
    ('rain_shelter', '먹비 가림', 'positive', 60, {'incoming_damage_pct': -8}, 'shield', '먹비 우산이 먹비와 함께 날아드는 것을 막아 줍니다.'),
    ('dark_eye', '어둠 눈', 'positive', 60, {'clue_bonus_pct': 6}, 'spark', '어둠 속에서도 작은 흔적이 눈에 들어옵니다.'),
    ('blank_fill', '빈칸 메움', 'positive', 60, {'erosion_pct': -30}, 'leaf', '빈칸이 메워져 몸에 스미는 요기가 줄어듭니다.'),
    ('rain_clear', '먹비 걷힘', 'positive', 120, {'fish_bite_pct': 10, 'gather_qty_pct': 8}, 'leaf', '눈앞의 먹비가 걷힌 듯 물고기와 채집거리가 잘 보입니다.'),
    ('brush_mind', '붓끝 정신', 'positive', 120, {'training_xp_pct': 10}, 'spark', '붓끝처럼 정신이 모여 기술이 잘 늡니다.'),
    ('dragon_eye', '용안', 'positive', 180, {'rare_loot_pct': 5, 'clue_bonus_pct': 5}, 'spark', '눈먼 용의 눈이 대신 봐 주어 귀한 것과 단서가 잘 보입니다.'),
    ('gentle_tide', '순한 물길', 'positive', 120, {'travel_time_pct': -10, 'incoming_damage_pct': -5}, 'leaf', '물길이 순해져 길이 빠르고 몸이 덜 다칩니다.'),
]

FISH_SPECIES = [
    ('stone_goby', '돌틈 망둥이', 'canal', 'common', None, None, 20, 8, 18, '수로 돌틈에 붙어 사는 망둥이. 손으로 집어도 잘 놀라지 않는다.', 6),
    ('sluice_carp', '수문 잉어', 'canal', 'uncommon', None, None, 24, 30, 70, '수문 아래 거슬러 오르는 잉어. 비늘이 두껍고 질기다.', 24),
    ('inkline_eel', '먹줄 장어', 'canal', 'rare', 'night', None, 28, 50, 110, '등에 먹줄을 그은 듯한 장어. 삼경에만 굴에서 나온다.', 72),
    ('well_blindfish', '우물 장님고기', 'deep', 'uncommon', None, None, 24, 10, 25, '깊은 우물에 사는 눈 없는 물고기. 몸이 반쯤 비친다.', 28),
    ('bronze_catfish', '청동 메기', 'deep', 'rare', 'dusk', None, 28, 60, 140, '비늘이 청동처럼 굳은 메기. 땅거미가 지면 바닥에서 올라온다.', 80),
    ('ash_lanternfish', '잿빛 샛비늘치', 'abyss', 'uncommon', None, None, 24, 8, 20, '심연에서 잿빛으로 빛나는 작은 물고기. 기름이 많다.', 30),
    ('nameless_angler', '이름 없는 아귀', 'abyss', 'rare', None, 'fog', 28, 40, 100, '안개 낀 날 심연에서 올라오는 아귀. 등불 대신 지운 글자를 매달았다.', 85),
    ('reed_crucian', '갈대 버들붕어', 'marsh', 'common', None, None, 20, 8, 20, '갈대 뿌리 사이에 숨어 사는 붕어. 버들잎처럼 납작하다.', 6),
    ('inkdot_bitterling', '먹점 납자루', 'marsh', 'uncommon', None, None, 24, 6, 14, '몸에 먹점이 찍힌 납자루. 잡으면 먹물을 뱉는다.', 24),
    ('mist_bitterling', '물안개 각시붕어', 'lake', 'uncommon', None, 'fog', 24, 6, 15, '물안개 낀 날 수면 가까이 떠오르는 각시붕어.', 26),
]
NAMED_FISH = [
    ('doorplate_carp', '문패 잉어', 'river', 'dusk', 'drizzle', 'mukchang_ferry', 60, 140, '비늘에 지워진 문패의 글자가 새겨진 잉어. 땅거미 가랑비에 강물고기 냄새를 따라 올라온다더라.',
     ['minnow', 'dace', 'mandarin_fish', 'bullhead']),
    ('blank_snakehead', '빈칸 가물치', 'marsh', 'night', 'cloudy', 'blank_field', 70, 160, '몸 한가운데가 빈칸처럼 하얀 가물치. 구름 낀 삼경에 늪물고기 냄새를 좋아한다더라.',
     ['loach', 'swamp_eel', 'reed_crucian', 'inkdot_bitterling']),
    ('meokbi_salmon', '먹비 대산천어', 'lake', 'dawn', 'rain', 'meokbi_forest', 50, 110, '먹비가 쏟아지는 해돋이에 못물고기 냄새를 맡고 떠오른다는 커다란 산천어.',
     ['pond_smelt', 'lenok', 'mist_bitterling']),
    ('blind_dragon', '눈먼 용', 'deep', 'noon', 'clear', 'nine_court', 120, 260, '우물 바닥에 산다는 눈먼 용. 맑은 한낮, 깊은 물고기 냄새가 내려가면 올라온다더라.',
     ['palace_puffer', 'well_blindfish', 'bronze_catfish']),
    ('bamboo_eel', '죽간 대장어', 'canal', 'night', 'fog', 'myeongbu_tower', 90, 200, '죽간을 엮은 듯 마디진 장어. 안개 낀 삼경, 수로 물고기 냄새를 따라 나온다더라.',
     ['canal_carp', 'canal_eel', 'stone_goby', 'sluice_carp']),
    ('inkscale_tuna', '먹비늘 다랑어', 'sea', 'dawn', 'wind', 'mukchang_ferry', 120, 240, '먹물 비늘을 두른 다랑어. 삭풍 부는 해돋이에 바닷물고기 냄새를 좇아 앞바다로 든다더라.',
     ['gizzard_shad', 'mackerel', 'flounder', 'sea_eel']),
]
NAMED_PRICE = 1500
NAMED_LEVEL = 40

COOK = 'cooking'
FISH_GOODS = [
    ('goby_braise', '망둥이 조림', 'consumable', 2, 40, True, 30, {'hp': 30, 'buffs': ['well_fed']}, '돌틈 망둥이를 간장에 졸였다. 체력을 조금 채운다.', 'cooking', {'stone_goby': 2, 'herb': 1}, 2, 20),
    ('carp_glue', None, None, None, None, None, None, None, None, 'leatherwork', {'sluice_carp': 2, 'charcoal': 1}, 2, 24),
    ('inkline_eel_grill', '먹줄 장어 구이', 'consumable', 3, 20, True, 220, {'hp': 45, 'mn': 15, 'buffs': ['vigor']}, '먹줄 장어를 숯불에 구웠다. 체력과 정신을 함께 채운다.', 'cooking', {'inkline_eel': 1, 'charcoal': 1}, 2, 28),
    ('dark_eye_drops', '어둠 눈 약', 'consumable', 3, 20, True, 160, {'buffs': ['dark_eye']}, '우물 장님고기 눈을 달인 약. 1시간 동안 단서가 잘 보인다.', 'alchemy', {'well_blindfish': 2, 'herbal_extract': 1}, 2, 24),
    ('bronze_scale_plate', None, None, None, None, None, None, None, None, 'smithing', {'bronze_catfish': 1, 'iron_ingot': 2}, 2, 28),
    ('shad_oil', None, None, None, None, None, None, None, None, 'alchemy', {'ash_lanternfish': 2}, 2, 24),
    ('shad_lamp', '샛비늘 등잔', 'consumable', 3, 20, True, 160, {'buffs': ['lamp_glow']}, '샛비늘 기름을 부은 등잔. 등잔빛처럼 요괴가 덜 꼬이고 마음이 덜 흔들린다.', 'artifice', {'shad_oil': 1, 'ore': 1}, 1, 24),
    ('angler_gall_pill', '아귀 쓸개 환', 'consumable', 3, 20, True, 240, {'er': 25, 'mn': 10}, '이름 없는 아귀 쓸개로 빚은 환약. 침식 −25, 정신 +10.', 'alchemy', {'nameless_angler': 1, 'medicine_base': 1}, 2, 28),
    ('crucian_reed_porridge', '붕어 갈대죽', 'consumable', 2, 40, True, 30, {'hp': 25, 'buffs': ['well_fed']}, '갈대 버들붕어와 갈대순으로 쑨 죽. 든든하다.', 'cooking', {'reed_crucian': 2, 'river_reed': 1}, 2, 20),
    ('bitterling_ink', None, None, None, None, None, None, None, None, 'sealing', {'inkdot_bitterling': 2, 'inkstone': 1}, 2, 24),
    ('mist_crucian_steam', '각시붕어 찜', 'consumable', 2, 40, True, 70, {'mn': 30, 'buffs': ['warm_belly']}, '물안개 각시붕어를 약초와 쪘다. 정신을 채우고 속이 따뜻해진다.', 'cooking', {'mist_bitterling': 1, 'herb': 2}, 1, 24),
]
NAMED_GOODS = [
    ('name_carving_soup', '이름 새김 탕', 'consumable', 5, 20, False, 1400, {'hp': 40, 'mn': 30, 'buffs': ['clear_name']}, '문패 잉어를 고아 이름을 새기듯 끓인 탕. 2시간 동안 이름 흐림을 한 단계 가볍게 한다(침식 30 아래면 막는다).', 'cooking', {'doorplate_carp': 1, 'medicine_base': 1}, 2, 40),
    ('blank_fill_pill', '빈칸 메움 환', 'consumable', 5, 20, False, 1400, {'er': 40, 'buffs': ['blank_fill']}, '빈칸 가물치로 빚은 환약. 침식 −40, 1시간 동안 오르는 침식이 준다.', 'alchemy', {'blank_snakehead': 1, 'herbal_extract': 1}, 2, 40),
    ('salmon_ink_grill', '산천어 먹구이', 'consumable', 5, 20, False, 1400, {'hp': 60, 'buffs': ['rain_clear']}, '먹비 대산천어를 먹소금에 구웠다. 2시간 동안 입질과 채집량이 는다.', 'cooking', {'meokbi_salmon': 1, 'charcoal': 1}, 2, 40),
    ('rainproof_oil', None, None, None, None, None, None, None, None, 'alchemy', {'meokbi_salmon': 1}, 2, 40),
    ('register_eel_grill', '명부 장어 구이', 'consumable', 5, 20, False, 1400, {'hp': 50, 'buffs': ['brush_mind']}, '죽간 대장어를 구웠다. 2시간 동안 기술 경험이 는다.', 'cooking', {'bamboo_eel': 1, 'charcoal': 1}, 2, 40),
    ('dragon_eye_essence', '용안 정수', 'consumable', 5, 20, False, 1400, {'buffs': ['dragon_eye']}, '눈먼 용의 눈에서 거둔 정수. 3시간 동안 희귀품과 단서가 잘 보인다.', 'alchemy', {'blind_dragon': 1, 'spirit_core': 1}, 2, 40),
    ('tuna_ink_feast', '다랑어 먹회 한 상', 'consumable', 5, 20, False, 1400, {'hp': 80, 'mn': 30, 'buffs': ['gentle_tide']}, '먹비늘 다랑어를 회로 떠 차린 한 상. 2시간 동안 길이 빠르고 받는 피해가 준다.', 'cooking', {'inkscale_tuna': 1, 'herb': 2}, 2, 40),
]
CONSUMABLE_RECIPES = [
    ('name_ink_charm', {'mukchang_ink': 2, 'blank_hanji': 1, 'bitterling_ink': 1}, 'sealing', 2),
    ('meokgwi_incense', {'shad_oil': 2, 'meokbi_moss': 1, 'ghost_ash': 1}, 'alchemy', 2),
    ('meokbi_umbrella', {'meokbi_ebony': 1, 'blank_hanji': 2, 'carp_glue': 1}, 'carpentry', 2),
]
CONSUMABLE_FX = {
    'name_ink_charm': {'buffs': ['name_ward']},
    'meokgwi_incense': {'buffs': ['meokgwi_repel']},
    'meokbi_umbrella': {'buffs': ['rain_shelter']},
}
EXTRA_RECIPES = [
    ('r_sealing_ink_bitterling', '납자루 봉인 먹 갈기', 'sealing_ink', 2, {'bitterling_ink': 2, 'inkstone': 1}, 'sealing', 24, None),
]
FILLET_QTY = {'common': 2, 'uncommon': 3, 'rare': 4}

TOOLS = [
    ('lt_knife_8', '먹비 흑단 채집도', 'knife', {'trait': '정밀 채집', 'req_line': 'gathering_rank', 'req_rank': 18, 'rare_loot_pct': 10, 'gathering_bonus_pct': 34},
     '먹비 흑단 자루에 청동 비늘 판을 댄 채집도. 장착하면 채집량 +34%·희귀품 +10%.', 'smithing', {'meokbi_ebony': 3, 'bronze_scale_plate': 2, 'drifting_name_thread': 1}),
    ('lt_pick_7', '명부 철 곡괭이', 'pick', {'trait': '정밀 채집', 'req_line': 'gathering_rank', 'req_rank': 15, 'rare_loot_pct': 9, 'gathering_bonus_pct': 32},
     '명부 탑 쇳돌과 청동 비늘 판으로 벼린 곡괭이. 광맥·유물 채집량이 는다.', 'smithing', {'bronze_scale_plate': 3, 'erased_plate': 3, 'drifting_name_thread': 1}),
    ('lt_sickle_7', '이름 실 낫', 'sickle', {'trait': '정밀 채집', 'sig_pct': 10, 'req_line': 'gathering_rank', 'req_rank': 16, 'sig_where': 'herb', 'gathering_bonus_pct': 28},
     '떠도는 이름 실을 감은 낫. 채집량 +28%, 약초·영기 채집터에서 10% 확률로 그 지역의 희귀품을 함께 거둔다.', 'smithing', {'drifting_name_thread': 2, 'meokbi_moss': 3, 'steel_ingot': 2}),
    ('lt_lantern_7', '먹귀 등', 'lantern', {'trait': '정밀 채집', 'sig_pct': 12, 'req_line': 'gathering_rank', 'req_rank': 17, 'sig_where': 'dark', 'gathering_bonus_pct': 26},
     '먹귀 응어리를 심지 삼은 등. 채집량 +26%, 유물 채집터나 어두운 지역에서 12% 확률로 그 지역의 희귀품을 함께 거둔다.', 'artifice', {'meokgwi_lump': 3, 'shad_oil': 2, 'spirit_glass': 1}),
    ('lt_compass_7', '명부 나침반', 'explore', {'trait': '탐사', 'req_line': 'investigation_rank', 'req_rank': 38, 'life_slot': 'explore', 'clue_bonus_pct': 9, 'search_find_pct': 48},
     '명부 죽간 바늘이 지워진 이름 쪽을 가리키는 나침반. 탐색에서 길·채집터를 더 잘 찾는다.', 'artifice', {'register_slip': 3, 'erased_plate': 2, 'spirit_glass': 1}),
    ('lt_rod_7', '묵창 낚싯대', 'rod', {'trait': '낚시', 'life_slot': 'fishing', 'fish_bite_pct': 21, 'fish_rare_pct': 16, 'fish_size_pct': 10},
     '먹비 흑단 대에 잉어 비늘 아교로 마디를 이은 낚싯대.', 'carpentry', {'meokbi_ebony': 3, 'carp_glue': 2, 'mukchang_ink': 1}),
    ('lt_rod_7b', '용비늘 낚싯대', 'rod', {'trait': '낚시', 'life_slot': 'fishing', 'fish_bite_pct': 23, 'fish_rare_pct': 18, 'fish_size_pct': 12, 'named_wt': 0.1},
     '눈먼 용의 비늘을 감은 낚싯대. 명어가 조금 더 잘 문다.', 'carpentry', {'blind_dragon': 1, 'meokbi_ebony': 3, 'carp_glue': 2}),
    ('lt_hammer_7', '묵창 단조 망치', 'hammer', {'trait': '제작 공구', 'req_line': 'crafting_rank', 'req_rank': 12, 'life_slot': 'craft', 'craft_fields': ['smithing', 'carpentry', 'artifice'], 'craft_quality': 12},
     '단조·목공·법구 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +12(제작 숙련 12단계부터).', 'smithing', {'bronze_scale_plate': 3, 'meokbi_ebony': 1, 'drifting_name_thread': 1}),
    ('lt_needle_7', '이름 실 바늘', 'needle', {'trait': '제작 공구', 'req_line': 'crafting_rank', 'req_rank': 12, 'life_slot': 'craft', 'craft_fields': ['weaving', 'leatherwork'], 'craft_quality': 12},
     '직조·가죽 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +12(제작 숙련 12단계부터).', 'leatherwork', {'drifting_name_thread': 2, 'carp_glue': 1, 'blank_hanji': 1}),
    ('lt_carve_7', '먹귀 각인도', 'carve', {'trait': '제작 공구', 'req_line': 'crafting_rank', 'req_rank': 12, 'life_slot': 'craft', 'craft_fields': ['sealing'], 'craft_quality': 12},
     '봉인 공예 제작 공구. 가방에 있으면 봉인 공예 품질 +12(제작 숙련 12단계부터). 각인 공구가 필요한 제작법에도 쓴다.', 'smithing', {'meokgwi_lump': 3, 'bronze_scale_plate': 1, 'bitterling_ink': 2}),
    ('lt_still_7', '먹비 증류기', 'still', {'trait': '제작 공구', 'req_line': 'crafting_rank', 'req_rank': 12, 'life_slot': 'craft', 'craft_fields': ['alchemy'], 'craft_quality': 12},
     '연금 제작 공구. 가방에 있으면 연금 제작 품질 +12(제작 숙련 12단계부터).', 'artifice', {'meokbi_moss': 3, 'spirit_glass': 1, 'shad_oil': 2}),
    ('lt_cook_7', '묵창 식칼', 'cook', {'trait': '제작 공구', 'req_line': 'crafting_rank', 'req_rank': 1, 'life_slot': 'craft', 'craft_fields': ['cooking'], 'craft_quality': 12},
     '요리 공구. 가방에 있으면 요리 품질 +12.', 'smithing', {'bronze_scale_plate': 2, 'meokbi_ebony': 1}),
]
UNTRADEABLE_TOOLS = {'lt_rod_7b'}

H = 'drifting_name_thread'
L = 'meokgwi_lump'
GEAR = [
    ('w_melee7_base', '묵창 참명도', 'weapon', 'strength', {'power': 58, 'trait': '근접', 'weapon_type': 'melee', 'combat_damage_pct': 22}, '명부 철을 두드려 벼린 칼. 고르게 강하다.', 'smithing', {'bronze_scale_plate': 5, H: 3, 'steel_ingot': 4, L: 3}),
    ('w_melee7_heavy', '아홉 칸 철퇴', 'weapon', 'strength', {'power': 68, 'trait': '근접', 'presence': 42, 'weapon_type': 'melee'}, '진의 주춧돌을 깎아 단 철퇴. 위력이 높지만 노려지기 쉽다.', 'smithing', {'bronze_scale_plate': 6, H: 3, 'steel_ingot': 4, 'erased_plate': 2}),
    ('w_melee7_keen', '이름 긋는 검', 'weapon', 'strength', {'power': 52, 'trait': '근접', 'crit_pct': 22, 'weapon_type': 'melee'}, '날이 붓끝처럼 가늘다. 치명타가 잘 터진다.', 'smithing', {'bronze_scale_plate': 5, H: 3, 'register_slip': 2, 'steel_ingot': 3}),
    ('w_melee7_silent', '먹비 단검', 'weapon', 'strength', {'power': 54, 'trait': '근접', 'presence': -42, 'evasion_pct': 11, 'weapon_type': 'melee'}, '먹비 소리에 묻히는 칼. 몸놀림도 가벼워진다.', 'smithing', {'bronze_scale_plate': 5, H: 3, 'meokbi_moss': 3, 'steel_ingot': 3}),
    ('w_ranged7_base', '흑단 명궁', 'weapon', 'agility', {'ammo': 'ammo_arrow', 'power': 58, 'trait': '원거리', 'weapon_type': 'ranged', 'combat_damage_pct': 22}, '먹비 흑단으로 짠 활. 고르게 강하다.', 'carpentry', {'meokbi_ebony': 5, 'carp_glue': 3, H: 3, 'sky_feather': 4}),
    ('w_ranged7_heavy', '명부 탑 쇠뇌', 'weapon', 'agility', {'ammo': 'ammo_bolt', 'power': 68, 'trait': '원거리', 'presence': 42, 'weapon_type': 'ranged'}, '탑 대들보로 짠 쇠뇌. 위력이 높지만 노려지기 쉽다.', 'carpentry', {'meokbi_ebony': 4, 'bronze_scale_plate': 3, H: 3, 'register_slip': 3}),
    ('w_ranged7_keen', '까마귀 깃 신궁', 'weapon', 'agility', {'ammo': 'ammo_arrow', 'power': 52, 'trait': '원거리', 'crit_pct': 22, 'weapon_type': 'ranged'}, '빈칸 까마귀 깃을 단 활. 치명타가 잘 터진다.', 'carpentry', {'meokbi_ebony': 5, H: 3, 'sky_feather': 5, 'blank_hanji': 2}),
    ('w_ranged7_silent', '붓대 취관', 'weapon', 'agility', {'ammo': 'ammo_dart', 'power': 54, 'trait': '원거리', 'presence': -42, 'evasion_pct': 11, 'weapon_type': 'ranged'}, '붓대를 깎아 만든 취관. 소리 없이 쏜다.', 'carpentry', {'meokbi_ebony': 5, 'meokbi_moss': 3, H: 3, 'shadow_fang': 3}),
    ('w_magic7_base', '명부 법륜', 'weapon', 'spirit_affinity', {'power': 58, 'trait': '술법', 'weapon_type': 'magic', 'combat_damage_pct': 22}, '죽간을 둥글게 엮은 법륜. 고르게 강하다.', 'artifice', {'register_slip': 5, 'mukchang_ink': 3, H: 3, 'rune_plate': 3}),
    ('w_magic7_heavy', '묵창 범종', 'weapon', 'spirit_affinity', {'power': 68, 'trait': '술법', 'presence': 42, 'weapon_type': 'magic'}, '나루 사당에서 떼어 온 작은 범종. 위력이 높지만 노려지기 쉽다.', 'artifice', {'bronze_scale_plate': 4, 'register_slip': 3, H: 3, 'rune_plate': 3}),
    ('w_magic7_keen', '먹 번진 부채', 'weapon', 'spirit_affinity', {'power': 52, 'trait': '술법', 'crit_pct': 22, 'weapon_type': 'magic'}, '빈칸 한지에 먹을 번지게 한 부채. 치명타가 잘 터진다.', 'artifice', {'blank_hanji': 5, 'mukchang_ink': 2, H: 3, 'mirror_shard': 3}),
    ('w_magic7_silent', '꺼진 붓 법등', 'weapon', 'spirit_affinity', {'power': 54, 'trait': '술법', 'presence': -42, 'evasion_pct': 11, 'weapon_type': 'magic'}, '꺾인 붓 고목 가지로 만든 법등. 요괴의 눈에 덜 띈다.', 'artifice', {'meokbi_ebony': 4, 'meokbi_moss': 3, H: 3, 'spirit_core': 2}),
    ('a7_iron', '청동 비늘갑', 'armor', 'vitality', {'trait': '방호', 'defense': 53, 'presence': 56, 'evasion_pct': -7}, '청동 비늘 판을 겹쳐 엮은 갑옷. 단단하지만 요괴의 이목을 끈다.', 'smithing', {'bronze_scale_plate': 5, L: 5, H: 3, 'rainproof_oil': 1}),
    ('a7_light', '이름 실 경갑', 'armor', 'agility', {'trait': '방호', 'defense': 32, 'evasion_pct': 11}, '떠도는 이름 실로 누빈 가벼운 갑옷. 몸을 틀어 피하기 좋다.', 'leatherwork', {H: 5, L: 4, 'carp_glue': 3, 'reinforced_leather': 3}),
    ('a7_robe', '먹비 법의', 'armor', 'willpower', {'trait': '방호', 'defense': 26, 'erosion_pct': -22, 'damage_reduction_pct': 14}, '먹비 막이 기름을 먹인 법의. 받는 피해를 덜고 요기를 막는다.', 'weaving', {'blank_hanji': 4, 'meokbi_moss': 3, H: 3, 'rainproof_oil': 1}),
    ('a7_shade', '빈칸 야행의', 'armor', 'agility', {'trait': '방호', 'defense': 23, 'crit_pct': 7, 'presence': -56, 'evasion_pct': 7}, '빈칸 벌판 억새빛으로 물들인 옷. 요괴의 눈을 피하고 빈틈을 노린다.', 'leatherwork', {'blank_hanji': 5, L: 4, H: 3, 'shadow_fang': 3}),
    ('h7_calm', '이름 지킴 관모', 'hat', 'willpower', {'trait': '관모', 'erosion_pct': -28, 'mental_loss_pct': -42}, '안쪽에 제 이름을 적어 쓰는 관모. 요기와 두려움을 막는다.', 'weaving', {'blank_hanji': 3, 'mukchang_ink': 3, H: 2}),
    ('h7_guard', '청동 투구', 'hat', 'vitality', {'trait': '관모', 'defense': 14, 'presence': 36}, '청동 비늘 판으로 두드린 투구. 앞장서는 이에게 어울린다.', 'smithing', {'bronze_scale_plate': 4, L: 3, H: 2}),
    ('h7_wise', '서리 익선관', 'hat', 'perception', {'trait': '관모', 'crit_pct': 7, 'clue_bonus_pct': 28}, '명부를 대조하던 서리의 관. 단서가 잘 보이고 급소를 읽는다.', 'weaving', {'register_slip': 3, 'blank_hanji': 3, H: 2}),
    ('s7_road', '억새 짚신', 'shoes', 'vitality', {'trait': '신', 'travel_time_pct': -28}, '흰 억새로 삼은 신. 먼 길을 덜 지치게 걷는다.', 'leatherwork', {'blank_hanji': 2, 'carp_glue': 2, L: 3, H: 2}),
    ('s7_sturdy', '청동 장화', 'shoes', 'vitality', {'trait': '신', 'defense': 11, 'presence': 28}, '땅을 굳게 딛는 청동 장화.', 'leatherwork', {'bronze_scale_plate': 3, L: 4, H: 2}),
    ('s7_swift', '먹비 비단신', 'shoes', 'agility', {'trait': '신', 'flee_pct': 22, 'evasion_pct': 11}, '먹비에 젖지 않는 비단신. 피하고 달아나기 좋다.', 'leatherwork', {'meokbi_moss': 3, 'carp_glue': 2, L: 3, H: 2}),
    ('n7_keen', '붓끝 장도 노리개', 'norigae', 'perception', {'trait': '노리개', 'crit_pct': 14}, '붓끝 모양 장도를 단 노리개. 급소를 노리는 눈이 밝아진다.', 'weaving', {'bronze_scale_plate': 2, 'blank_hanji': 3, H: 2}),
    ('n7_luck', '명부 죽간 노리개', 'norigae', 'spirit_affinity', {'trait': '노리개', 'rare_loot_pct': 22}, '죽간 한 쪽을 꿴 노리개. 귀한 전리품이 잘 나온다.', 'weaving', {'register_slip': 4, 'blank_hanji': 2, H: 2}),
    ('n7_plenty', '나루 풍년 노리개', 'norigae', 'vitality', {'trait': '노리개', 'craft_quality': 7, 'gather_qty_pct': 22}, '나루 아낙들이 엮는 노리개. 거두는 양과 솜씨가 는다.', 'weaving', {'meokbi_moss': 4, L: 3, H: 2}),
    ('m7_purify', '먹비 향낭', 'amulet', 'willpower', {'trait': '호신부', 'erosion_pct': -22, 'healing_pct': 22}, '먹비 이끼를 넣은 향낭. 침식이 덜하고 회복이 잘 된다.', 'sealing', {'meokbi_moss': 4, 'mukchang_ink': 2, H: 2}),
    ('m7_spell', '이름 먹 부적낭', 'amulet', 'spirit_affinity', {'trait': '호신부', 'magic_pct': 22}, '묵창 갈대 먹으로 그린 부적을 품는다. 술법이 세진다.', 'sealing', {'mukchang_ink': 3, 'register_slip': 2, H: 2}),
    ('m7_ward', '아홉 칸 호패', 'amulet', 'willpower', {'trait': '호신부', 'presence': 28, 'incoming_damage_pct': -14}, '진의 한 칸을 본뜬 호패. 받는 피해가 줄고 요괴가 먼저 노린다.', 'sealing', {'erased_plate': 3, 'mirror_shard': 2, H: 2}),
    ('k7_awe', '허수아비 탈', 'mask', 'strength', {'trait': '탈', 'presence': 70, 'combat_damage_pct': 11}, '이름 걸린 허수아비의 얼굴을 본뜬 탈. 요괴가 먼저 덤비지만 기세가 오른다.', 'sealing', {L: 5, H: 2, 'erased_plate': 2}),
    ('k7_ghost', '먹귀 탈', 'mask', 'spirit_affinity', {'trait': '탈', 'encounter_pct': 22, 'rare_loot_pct': 14}, '먹귀의 흐린 얼굴. 요괴를 불러들이고 귀한 것을 끌어낸다.', 'sealing', {'mukchang_ink': 3, 'ghost_ash': 4, H: 2}),
    ('k7_hide', '빈칸 탈', 'mask', 'agility', {'trait': '탈', 'presence': -70, 'encounter_pct': -22}, '얼굴 자리가 빈칸으로 남은 탈. 요괴의 눈에 덜 띄고 덜 마주친다.', 'sealing', {'blank_hanji': 3, 'shadow_fang': 3, H: 2}),
]
GEAR_DROP = {
    'w_melee7_base': ['armored', 'swarm', 'boss'], 'w_melee7_heavy': ['armored', 'swarm', 'boss'], 'w_melee7_keen': ['armored', 'swarm', 'boss'], 'w_melee7_silent': ['armored', 'swarm', 'boss'],
    'w_ranged7_base': ['aerial', 'ambush', 'boss'], 'w_ranged7_heavy': ['aerial', 'ambush', 'boss'], 'w_ranged7_keen': ['aerial', 'ambush', 'boss'], 'w_ranged7_silent': ['aerial', 'ambush', 'boss'],
    'w_magic7_base': ['spectral', 'warded', 'seal_breaker', 'boss'], 'w_magic7_heavy': ['spectral', 'warded', 'seal_breaker', 'boss'], 'w_magic7_keen': ['spectral', 'warded', 'seal_breaker', 'boss'], 'w_magic7_silent': ['spectral', 'warded', 'seal_breaker', 'boss'],
    'a7_iron': ['armored', 'boss'], 'a7_light': ['aerial', 'swarm', 'boss'], 'a7_robe': ['spectral', 'warded', 'boss'], 'a7_shade': ['ambush', 'boss'],
    'h7_calm': ['spectral', 'seal_breaker', 'boss'], 'h7_guard': ['armored', 'boss'], 'h7_wise': ['warded', 'reflect', 'boss'],
    's7_road': ['swarm', 'tide', 'boss'], 's7_sturdy': ['armored', 'boss'], 's7_swift': ['aerial', 'boss'],
    'n7_keen': ['ambush', 'boss'], 'n7_luck': ['tide', 'reflect', 'boss'], 'n7_plenty': ['toxic', 'swarm', 'boss'],
    'm7_purify': ['toxic', 'boss'], 'm7_spell': ['spectral', 'boss'], 'm7_ward': ['seal_breaker', 'warded', 'boss'],
    'k7_awe': ['armored', 'boss'], 'k7_ghost': ['spectral', 'reflect', 'boss'], 'k7_hide': ['ambush', 'boss'],
    'lt_knife_8': ['toxic', 'swarm', 'boss'],
}
GEAR_LEVELS = (41, 45)

SHOP = [
    ('name_ink_charm', 780, 4), ('meokgwi_incense', 720, 4), ('meokbi_umbrella', 690, 4),
    ('tonic', 210, 10), ('ward_talisman', 260, 8), ('travel_ration', 160, 10), ('repair_kit', 0, 3),
    ('spirit_qi_pill', 0, 5), ('revival_charm', 1100, 1), ('ammo_arrow', 0, 200), ('ammo_bolt', 0, 200), ('ammo_dart', 0, 200),
]

FURNITURE = {
    'wall_doorplate': dict(source='shop', mats={'erased_plate': 1, 'wood': 2}, field='carpentry', lv=40),
    'wall_bamboo_blind': dict(source='shop', mats={'register_slip': 1, 'river_reed': 3}, field='weaving', lv=40),
    'rug_ink_pond': dict(source='drop_normal', mats={'mukchang_ink': 2, 'blank_hanji': 2, 'silk': 1}, field='weaving', lv=40),
    'window_meokbi': dict(source='drop_normal', mats={'meokbi_ebony': 1, 'blank_hanji': 2, 'lumber': 1}, field='carpentry', lv=40),
    'shelf_register': dict(source='drop_guardian', mats={'meokbi_ebony': 2, 'register_slip': 2, 'lacquer': 2}, field='carpentry', lv=40),
    'lamp_nine_pillar': dict(source='title:mk_court_all', mats=None, field=None, lv=40),
    'rubbing_doorplate_carp': dict(source='named', mats={'doorplate_carp': 1, 'fine_paper': 2, 'mukchang_ink': 2}, field='sealing', lv=40),
    'rubbing_blank_snakehead': dict(source='named', mats={'blank_snakehead': 1, 'fine_paper': 2, 'mukchang_ink': 2}, field='sealing', lv=40),
    'rubbing_blind_dragon': dict(source='named', mats={'blind_dragon': 1, 'fine_paper': 2, 'mukchang_ink': 2}, field='sealing', lv=40),
    'rubbing_inkscale_tuna': dict(source='named', mats={'inkscale_tuna': 1, 'fine_paper': 2, 'mukchang_ink': 2}, field='sealing', lv=40),
    'rubbing_meokbi_salmon': dict(source='named', mats={'meokbi_salmon': 1, 'fine_paper': 2, 'mukchang_ink': 2}, field='sealing', lv=40),
    'rubbing_bamboo_eel': dict(source='named', mats={'bamboo_eel': 1, 'fine_paper': 2, 'mukchang_ink': 2}, field='sealing', lv=40),
    'tank_bamboo_eel': dict(source='named', mats={'bamboo_eel': 1, 'spirit_glass': 2, 'meokbi_ebony': 2}, field='carpentry', lv=40),
}

TITLES = [
    ('mk_arrive', '먹빛 나루에 닿은 이', 3, {'mental_loss_pct': -3}, {'n': 1, 'p': {'region_id': 'mukchang_ferry'}, 'ev': 'travel', 'has': 'travel_history_id'}, '묵창 나루에 닿는다', False),
    ('mk_walker', '흐린 이름의 길손', 4, {'travel_time_pct': -4, 'encounter_pct': -3}, {'all': [{'p': {'region_id': r}, 'ev': 'travel', 'has': 'travel_history_id'} for r in ['mukchang_ferry', 'blank_field', 'meokbi_forest', 'myeongbu_tower', 'nine_court']]}, '묵적 봉쇄령의 다섯 곳에 모두 닿는다', False),
    ('mk_plate_reader', '지워진 문패를 읽는 이', 3, {'clue_bonus_pct': 4}, {'n': 20, 'p': {'item_id': 'erased_plate'}, 'ev': 'gather'}, '지워진 문패 조각을 20번 거둔다', False),
    ('mk_ebony_hand', '먹비 숲의 나무꾼', 3, {'gather_qty_pct': 4}, {'n': 20, 'p': {'item_id': 'meokbi_ebony'}, 'ev': 'gather'}, '먹비 흑단을 20번 거둔다', False),
    ('mk_court_all', '아홉 칸을 지나온 이', 5, {'erosion_pct': -5, 'mental_loss_pct': -5, 'combat_damage_pct': 2},
     {'all': [{'p': {'monster_id': m, 'defeated': True}, 'ev': 'combat'} for m in ['mk_field_5', 'mk_forest_5', 'mk_tower_5', 'mk_court_5']]}, '묵적 봉쇄령 네 곳의 우두머리를 모두 풀어 보낸다', False),
    ('mk_fish_doorplate_carp', '문패를 낚은 이', 4, {'fish_bite_pct': 3}, {'n': 1, 'p': {'fish': 'doorplate_carp'}, 'ev': 'fish'}, '문패 잉어를 낚는다', True),
    ('mk_fish_blank_snakehead', '빈칸을 낚은 이', 4, {'fish_rare_pct': 3}, {'n': 1, 'p': {'fish': 'blank_snakehead'}, 'ev': 'fish'}, '빈칸 가물치를 낚는다', True),
    ('mk_fish_meokbi_salmon', '먹비를 낚은 이', 4, {'gather_qty_pct': 3}, {'n': 1, 'p': {'fish': 'meokbi_salmon'}, 'ev': 'fish'}, '먹비 대산천어를 낚는다', True),
    ('mk_fish_blind_dragon', '눈먼 용을 낚은 이', 4, {'rare_loot_pct': 3}, {'n': 1, 'p': {'fish': 'blind_dragon'}, 'ev': 'fish'}, '눈먼 용을 낚는다', True),
    ('mk_fish_bamboo_eel', '죽간을 낚은 이', 4, {'clue_bonus_pct': 3}, {'n': 1, 'p': {'fish': 'bamboo_eel'}, 'ev': 'fish'}, '죽간 대장어를 낚는다', True),
    ('mk_fish_inkscale_tuna', '먹비늘을 낚은 이', 4, {'travel_time_pct': -3}, {'n': 1, 'p': {'fish': 'inkscale_tuna'}, 'ev': 'fish'}, '먹비늘 다랑어를 낚는다', True),
    ('mk_named_all', '이름을 낚은 이', 5, {'fish_bite_pct': 5, 'fish_rare_pct': 10, 'fish_size_pct': 10},
     {'all': [{'p': {'fish': f}, 'ev': 'fish'} for f in ['doorplate_carp', 'blank_snakehead', 'meokbi_salmon', 'blind_dragon', 'bamboo_eel', 'inkscale_tuna']]}, '명어 여섯을 모두 낚는다', True),
]
TITLE_CAT = '묵적록'
NAME_STYLE = (1031, '먹빛 금', 'cat', TITLE_CAT, 6)
COSMETICS = [
    ('fr_mukjeok', 'frame', 'legend', '먹비 테', '묵적 봉쇄령 다섯 곳에 모두 닿으면', {'title': 'mk_walker'}, 1500),
    ('sl_muk', 'seal', 'legend', '낙관 「墨」', '명어 여섯을 모두 낚으면', {'title': 'mk_named_all'}, 1501),
]
