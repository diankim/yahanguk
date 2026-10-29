# 7.0 귀허도(歸墟島) 데이터: 지역·답사 길·채집터·요괴·원정지·조사 지점·재료·6단계 장비·반요촌 상점
# gen.py가 읽어 SQL로 바꾼다. 이름은 게임 전체에서 겹치지 않게 지었다(되돌리는 시험에서 한 번 더 확인).

TERR = ('gwiheo', '귀허도')

# region_id, 이름, 유형, 위험도, 레벨, x, y, 고도, 이웃, 테마, 안전지대, 설명
REGIONS = [
    dict(id='banyo_village', name='반요촌', type='village', danger=8, lv=30, x=520, y=860, el=0, nb=['sealed_abyss', 'ash_reeds', 'inverted_shrine'],
         theme='city', safe=True, desc='요기에 물든 사람들이 비늘 지붕 아래 모여 사는 마을. 문간마다 사람이던 시절의 이름이 붙어 있다.',
         rest=('반요촌 객방', 'inn', 150, 2), shop=('banyo_shop', '반요촌 잡화')),
    dict(id='ash_reeds', name='잿빛 갈대숲', type='swamp', danger=10, lv=30, x=430, y=905, el=-1, nb=['banyo_village', 'inverted_shrine', 'moonless_market'],
         theme='water', desc='재가 내려앉은 갈대가 끝없이 이어진 물가. 갈대 사이로 누군가 옛 이름을 부르는 소리가 난다.'),
    dict(id='inverted_shrine', name='거꾸로 선 사당', type='sealed_shrine', danger=10, lv=33, x=395, y=1005, el=1, nb=['banyo_village', 'ash_reeds', 'moonless_market'],
         theme='shrine', desc='지붕이 땅에 박히고 주춧돌이 하늘을 향한 사당. 이곳의 향은 아래로 탄다.'),
    dict(id='moonless_market', name='달 없는 저잣거리', type='ruins', danger=10, lv=36, x=515, y=995, el=0, nb=['ash_reeds', 'inverted_shrine', 'gwiheo_core'],
         theme='city', desc='달이 뜨지 않는 섬의 장터. 값을 치르는 것은 전이 아니라 기억이다.'),
    dict(id='gwiheo_core', name='귀허', type='abyss', danger=10, lv=38, x=615, y=1060, el=-4, nb=['moonless_market'],
         theme='deep', desc='모든 물이 돌아가 사라지는 바다의 끝. 소용돌이 한가운데 누군가의 빈 자리가 있다.'),
]

# 답사 길: L1 하나 → L2 둘 → L3 넷(각 둘) → L4 여섯(L3마다 2·1·2·1) → L5 여덟(L4마다 2·1·1·2·1·1)
NODES = {
    'banyo_village': [['반요촌 어귀'], ['묵호의 마당', '비늘 지붕 골목']],
    'ash_reeds': [
        ['갈대숲 나루터'],
        ['잿빛 물길', '쓰러진 갈대밭'],
        ['젖은 발자국 둔덕', '뒤집힌 거룻배', '갈대 우는 여울', '백로 뼈 무덤'],
        ['재 날리는 모래톱', '물안개 고인 웅덩이', '끊어진 징검다리', '반쯤 잠긴 초막', '갈대 엮은 장승', '썩은 그물 더미'],
        ['달 비친 늪구멍', '이름 새긴 말뚝', '갈대 속 빈 무덤', '잿물 고인 샘', '버려진 물레방아', '갈꽃 덮인 제단', '흰 뼈 쌓인 둑', '물귀신 바위'],
    ],
    'inverted_shrine': [
        ['뒤집힌 일주문'],
        ['거꾸로 걸린 종루', '천장 밟는 회랑'],
        ['아래로 타는 향로', '거꾸로 선 석탑', '뒤집힌 연못', '매달린 불단'],
        ['위로 흐르는 계단', '거꾸로 새긴 비석', '발밑의 단청', '뒤집힌 공양간', '거꾸로 앉은 나한전', '하늘로 떨어진 기와'],
        ['거꾸로 우는 풍경', '머리 위의 우물', '뒤집힌 탱화', '거꾸로 감긴 염주 더미', '천장에 핀 연꽃', '거꾸로 새긴 이름판', '아래로 솟은 당간', '뒤집힌 부처의 손'],
    ],
    'moonless_market': [
        ['꺼진 등롱 거리'],
        ['빈 좌판 골목', '이름 파는 객주'],
        ['얼굴 없는 포목전', '기억 저울집', '문 닫힌 약방', '녹슨 대장간 터'],
        ['그림자 경매터', '값 없는 전당포', '거꾸로 셈하는 주판방', '혼 담는 옹기전', '길 잃은 등짐꾼 쉼터', '이름 쓴 부채 가게'],
        ['달 판 자리', '마지막 손님의 탁자', '빈 갓 걸린 담', '꺼진 청사초롱 아래', '지운 장부 창고', '목소리 파는 노점', '거울 덮은 방', '셈 끝난 계산대'],
    ],
    'gwiheo_core': [
        ['귀허의 물가'],
        ['가라앉는 돌길', '끝없는 소용돌이 가장자리'],
        ['돌아오지 못한 배 무덤', '빛이 지는 해구', '흰 사슬 늘어진 벼랑', '이름 녹는 갯벌'],
        ['바닥 없는 우물', '거꾸로 흐르는 폭포', '망자의 등대', '검은 진주밭', '숨 멎은 산호 숲', '무너진 해신당'],
        ['귀허의 눈', '마지막 물빛', '사라진 이들의 둥지', '검은 물의 왕좌 앞', '소용돌이 밑바닥', '닫힌 바다 문', '침묵의 해저 궁', '주인의 빈 자리'],
    ],
}
NODE_DESC = {
    1: '지역에 막 들어선 곳입니다. 탐색하면 안쪽으로 이어지는 길을 찾을 수 있습니다.',
    2: '지역의 바깥 권역입니다. 탐색을 이어가면 더 안쪽 구역을 찾을 수 있습니다.',
    3: '권역 안쪽의 구역입니다. 요괴의 흔적이 짙어지고 채집터가 드러납니다.',
    4: '깊숙한 곳입니다. 쓸 만한 채집터가 숨어 있지만 위험도 커집니다.',
    5: '가장 깊은 지점입니다. 희귀한 자원과 강한 요괴가 함께 있습니다.',
}
L4_KIDS = [2, 1, 2, 1]          # L3 넷이 가지는 L4 수
L5_KIDS = [2, 1, 1, 2, 1, 1]    # L4 여섯이 가지는 L5 수

# 채집터: 지역별 꾸밈말 · 분류별 이름 · 분류별 얻는 것
SPOT_ADJ = {
    'banyo_village': ['비늘 덮인', '문패 걸린'],
    'ash_reeds': ['잿빛', '젖은', '바스락대는', '물안개 낀', '백로 우는', '갈꽃 흩날리는', '물비린내 나는', '달빛 젖은', '재 덮인', '늪내 나는', '갈대 부러진'],
    'inverted_shrine': ['거꾸로 선', '향내 스민', '뒤집힌', '종소리 맴도는', '천장에 매달린', '단청 벗겨진', '아래로 흐르는', '목탁 소리 나는', '거꾸로 그을린', '불경 적힌', '주춧돌 들린'],
    'moonless_market': ['달빛 없는', '셈 끝난', '값 매겨진', '얼굴 지운', '흥정 소리 나는', '등불 꺼진', '이름 팔린', '먼지 앉은 좌판의', '저울 기운', '목소리 갇힌', '주판알 흩어진'],
    'gwiheo_core': ['소용돌이치는', '빛 잃은', '바닥 모를', '물살 거꾸로 도는', '진주빛 도는', '물에 잠긴', '파도 멎은', '검은 물 고인', '해신 잠든', '사라져 가는', '끝없이 가라앉는'],
}
SPOT_NOUN = {
    'water': ['갈대 여울', '잿물 웅덩이', '늪가 진흙밭', '물풀 엉킨 굽이', '갈대 뿌리 물가'],
    'herbs': ['약풀 둔덕', '쑥 덤불', '물가 약초밭', '이끼 낀 바위틈', '고사리 그늘'],
    'wood': ['쓰러진 고목', '갈대 울타리', '나룻배 판자 더미', '향나무 그루터기', '부러진 서까래'],
    'supplies': ['버려진 봇짐', '무너진 초막', '떠내려온 궤짝', '주인 없는 짐수레', '빈 객주 광'],
    'relics': ['깨진 위패 더미', '거꾸로 걸린 현판', '그을린 경판', '빛바랜 부적 상자', '이름 지운 족자'],
    'spirit': ['요기 맺힌 돌', '혼불 앉은 자리', '귀기 서린 샘', '푸른 넋 웅덩이', '흐느끼는 바위'],
    'ore': ['흑철 노두', '검은 쇳돌 비탈', '망각 수정 맥', '해저 광맥', '조개껍질 섞인 쇳돌'],
}
SPOT_LOOT = {
    'banyo_village': {'supplies': ['herb', 'travel_ration', 'tonic'], 'herbs': ['herb', 'herb', 'medicine_base']},
    'ash_reeds': {'water': ['river_reed', 'river_reed', 'drowned_scale', 'reed_silk'], 'herbs': ['herb', 'medicine_base', 'moon_moss', 'reed_silk'],
                  'wood': ['wood', 'wood', 'resin', 'reed_silk'], 'supplies': ['herb', 'travel_ration', 'tonic']},
    'inverted_shrine': {'relics': ['seal_paper', 'inkstone', 'talisman_thread', 'inverted_incense'], 'spirit': ['spirit_dust', 'ghost_ash', 'ward_fragment', 'inverted_incense'],
                        'wood': ['wood', 'resin', 'inverted_incense'], 'supplies': ['herb', 'travel_ration', 'tonic']},
    'moonless_market': {'relics': ['seal_paper', 'inkstone', 'moonless_silk', 'oblivion_crystal'], 'supplies': ['herb', 'travel_ration', 'tonic', 'moonless_silk'],
                        'ore': ['ore', 'raw_iron', 'oblivion_crystal'], 'spirit': ['spirit_dust', 'ghost_ash', 'oblivion_crystal']},
    'gwiheo_core': {'ore': ['ore', 'raw_iron', 'gwiheo_iron'], 'spirit': ['spirit_dust', 'ghost_ash', 'spirit_core', 'gwiheo_iron'],
                    'relics': ['seal_paper', 'ward_fragment', 'gwiheo_iron'], 'water': ['river_reed', 'drowned_scale', 'gwiheo_iron']},
}
# 들머리 채집터(처음부터 찾은 것으로 하는 「어귀의 …」)
ENTRY_SPOT = {'banyo_village': ('어귀의 비늘 지붕 텃밭', 'herbs'), 'ash_reeds': ('어귀의 잿빛 갈대 여울', 'water'),
              'inverted_shrine': ('어귀의 거꾸로 선 향나무', 'wood'), 'moonless_market': ('어귀의 꺼진 등롱 좌판', 'supplies'),
              'gwiheo_core': ('어귀의 소용돌이 쇳돌', 'ore')}

# 요괴: (id, 이름, 유형 이름, 역할, 갈래, 습성, 설명, 전리품)
MONSTERS = {
    'ash_reeds': [
        ('gw_reed_1', '갈대 물귀신', '수귀', 'common', 'water', 'tide', '갈대 뿌리에 발을 감고 사람을 물속으로 끌어당긴다.', {'river_reed': 1, 'banyo_scale': 1}),
        ('gw_reed_2', '잿빛 백로 떼', '비행 요괴', 'common', 'bird', 'aerial', '재를 뒤집어쓴 백로 떼. 한 마리가 울면 모두 내리꽂힌다.', {'sky_feather': 1, 'banyo_scale': 1}),
        ('gw_reed_3', '이름 잃은 사공', '원령', 'main', 'ghost', 'spectral', '건너편에 데려다준다며 노를 젓지만 배는 늘 같은 자리를 돈다.', {'ghost_ash': 4, 'reed_silk': 2, 'yoin_blood': 1}),
        ('gw_reed_4', '갈대 엮인 요인', '목령', 'main', 'wood', 'toxic', '몸에 갈대를 엮어 사람 꼴을 지키려는 반요. 숨결에 독이 섞였다.', {'reed_silk': 3, 'venom_gland': 1, 'yoin_blood': 1}),
        ('gw_reed_5', '잿빛 갈대 어미', '지역 우두머리', 'guardian', 'swarm', 'swarm', '갈대숲 전체를 제 몸처럼 흔드는 어미 요괴.', {'reed_silk': 3, 'yoin_blood': 2, 'spirit_core': 1}),
    ],
    'inverted_shrine': [
        ('gw_shrine_1', '거꾸로 매달린 동자', '원령', 'common', 'ghost', 'spectral', '천장에 거꾸로 매달려 목탁을 두드리는 아이의 혼.', {'ghost_ash': 1, 'banyo_scale': 1}),
        ('gw_shrine_2', '뒤집힌 향로귀', '결계 요괴', 'common', 'ward', 'warded', '아래로 타는 향 연기를 두른 향로. 연기가 결계가 된다.', {'inverted_incense': 1, 'banyo_scale': 1}),
        ('gw_shrine_3', '목 없는 나한', '갑각 요괴', 'main', 'shell', 'armored', '머리를 잃은 석상이 거꾸로 걸어 다닌다. 돌 몸이 단단하다.', {'monster_core': 1, 'inverted_incense': 2, 'yoin_blood': 1}),
        ('gw_shrine_4', '거울 속 주지', '거울 요괴', 'main', 'mirror', 'reflect', '연못에 비친 주지만 남고 몸은 사라졌다. 공격을 되돌린다.', {'mirror_shard': 2, 'inverted_incense': 2, 'yoin_blood': 1}),
        ('gw_shrine_5', '거꾸로 선 범종귀', '지역 우두머리', 'guardian', 'breaker', 'seal_breaker', '종루에서 떨어진 범종이 요괴가 되었다. 울릴 때마다 봉인이 금 간다.', {'inverted_incense': 3, 'yoin_blood': 2, 'spirit_core': 1}),
    ],
    'moonless_market': [
        ('gw_market_1', '값 매기는 그림자', '매복 요괴', 'common', 'shadow', 'ambush', '좌판 그늘에 숨어 지나는 이의 기억에 값을 매긴다.', {'shadow_fang': 1, 'banyo_scale': 1}),
        ('gw_market_2', '얼굴 없는 손님 떼', '무리 요괴', 'common', 'swarm', 'swarm', '갓만 쓴 손님들이 한꺼번에 몰려든다.', {'moonless_silk': 1, 'banyo_scale': 1}),
        ('gw_market_3', '기억 저울 장수', '결계 요괴', 'main', 'ward', 'warded', '저울 한쪽에 사람의 기억을 올린다. 기운 쪽이 그의 것이 된다.', {'oblivion_crystal': 2, 'moonless_silk': 2, 'yoin_blood': 1}),
        ('gw_market_4', '전당포 거미', '독충', 'main', 'venom', 'toxic', '맡긴 물건을 거미줄로 감아 두는 늙은 거미. 독니가 길다.', {'venom_gland': 2, 'moonless_silk': 2, 'yoin_blood': 1}),
        ('gw_market_5', '달을 판 상주', '지역 우두머리', 'guardian', 'giant', 'boss', '섬의 달을 팔아 치운 장터의 우두머리. 덩치가 저잣거리만 하다.', {'oblivion_crystal': 3, 'yoin_blood': 2, 'spirit_core': 1}),
    ],
    'gwiheo_core': [
        ('gw_core_1', '돌아오는 파도귀', '수귀', 'common', 'water', 'tide', '빠져나간 물이 사람 꼴로 다시 밀려온다.', {'drowned_scale': 1, 'banyo_scale': 1}),
        ('gw_core_2', '흰 사슬 망령', '원령', 'common', 'ghost', 'spectral', '귀허로 끌려온 이들이 차던 사슬이 혼째 떠돈다.', {'ghost_ash': 1, 'banyo_scale': 1}),
        ('gw_core_3', '진주 문 해괴', '갑각 요괴', 'main', 'shell', 'armored', '등에 검은 진주를 박은 거대한 조개 요괴.', {'gwiheo_iron': 2, 'monster_core': 1, 'yoin_blood': 1}),
        ('gw_core_4', '소용돌이 천상귀', '천상 요괴', 'main', 'sky', 'aerial', '소용돌이 위를 맴도는 별빛 요괴. 떨어지는 빛이 사람을 밀어낸다.', {'star_sand': 1, 'gwiheo_iron': 2, 'yoin_blood': 1}),
        ('gw_core_5', '귀허의 문지기', '지역 우두머리', 'guardian', 'mirror', 'reflect', '빈 왕좌로 가는 길목을 지키는 거울 몸의 문지기.', {'gwiheo_iron': 3, 'yoin_blood': 2, 'gwiheo_pearl': 1}),
    ],
}

GROUNDS = {
    'ash_reeds': [('잿빛 나루 언저리', '재가 덜 내려앉은 바깥 물가.'), ('갈대 무덤 늪', '쓰러진 갈대가 무덤처럼 쌓인 늪.'), ('이름 부르는 여울', '갈대가 옛 이름을 부르는 가장 깊은 여울.')],
    'inverted_shrine': [('뒤집힌 산문 앞', '사당으로 들어가는 거꾸로 된 문 앞.'), ('아래로 타는 법당', '향이 바닥으로 흘러내리는 법당.'), ('하늘 밑 불단', '천장이 된 바닥에 차려진 불단.')],
    'moonless_market': [('꺼진 좌판 거리', '등불이 꺼진 장터 바깥 골목.'), ('기억 경매장', '기억을 사고파는 저잣거리 한복판.'), ('달 판 상주의 창고', '팔린 달빛이 쌓여 있다는 창고.')],
    'gwiheo_core': [('가라앉는 물가', '발밑이 천천히 가라앉는 귀허의 바깥.'), ('소용돌이 벼랑', '흰 사슬이 늘어진 소용돌이 가장자리.'), ('빈 왕좌의 바다', '귀허의 주인이 기다리는 가장 깊은 곳.')],
}
FISH = {'ash_reeds': ('marsh', '잿빛 갈대 여울', '재 섞인 물에 찌가 잘 보이지 않습니다. 무언가 갈대 뿌리 사이를 스칩니다.'),
        'gwiheo_core': ('abyss', '귀허 물가', '모든 물이 돌아가는 곳. 낚싯줄이 바닥에 닿지 않습니다.')}

PROFILES = {
    'banyo_village': ('도성·마을', '반요촌 사람들·섬의 안내인', '반요촌의 문패: 사람이던 시절의 이름과 지금 불리는 이름이 나란히 적혀 있다.', '반요촌 고유 사건: 촌장 묵호가 잊어 가는 이름을 되찾아 주면 섬의 옛 기록이 열린다.', '비싼 물자·요기', '비늘 지붕, 이름 두 개 걸린 문패, 꺼지지 않는 화로'),
    'ash_reeds': ('물가·늪지', '갈대숲 사공·요화된 이들', '잿빛 갈대숲의 말뚝: 물에 잠긴 이름을 다 읽으면 건너편이 보인다.', '잿빛 갈대숲 고유 사건: 사공이 부르는 이름에 답하면 배가 움직인다.', '침식·익사·환청', '재 덮인 갈대, 물안개, 이름 새긴 말뚝'),
    'inverted_shrine': ('사당·성역', '거꾸로 기도하는 승려들', '거꾸로 선 사당의 이름판: 거꾸로 읽어야 바른 이름이 된다.', '거꾸로 선 사당 고유 사건: 아래로 타는 향을 바로 세우면 사당의 기도가 뒤집힌다.', '침식·결계·환영', '땅에 박힌 지붕, 아래로 타는 향, 하늘을 향한 주춧돌'),
    'moonless_market': ('폐허 도성', '기억 상인·얼굴 없는 손님', '달 없는 저잣거리의 장부: 팔린 기억의 주인 이름이 지워진 채 남아 있다.', '달 없는 저잣거리 고유 사건: 지운 장부를 맞추면 섬으로 보낸 이들의 명단이 드러난다.', '기억 상실·매복·독', '꺼진 청사초롱, 빈 좌판, 기울어진 저울'),
    'gwiheo_core': ('심연·바다 끝', '귀허의 주인과 문지기', '귀허의 물빛: 돌아오지 못한 이들의 이름이 물결에 비친다.', '귀허 고유 사건: 빈 왕좌 앞에서 마지막 이름을 부르면 주인이 깨어난다.', '침식·소용돌이·사슬', '끝없는 소용돌이, 흰 사슬, 빈 왕좌'),
}
LORE = {
    'banyo_village': ['반요촌. 구중 봉연 아래로 흘러 나간 물길 끝에 있는 마을입니다. 사람들은 비늘 돋은 손으로 손님에게 차를 따릅니다.',
                      '문간마다 이름이 두 개씩 걸려 있습니다. 하나는 사람이던 시절의 이름, 하나는 여기서 불리는 이름입니다.'],
    'ash_reeds': ['잿빛 갈대숲. 바람이 불면 갈대가 사람 이름을 하나씩 부릅니다. 대답하지 않는 것이 이곳의 예의입니다.',
                  '물가에 박힌 말뚝마다 이름이 새겨져 있습니다. 대부분은 물에 잠겨 반만 읽힙니다.'],
    'inverted_shrine': ['거꾸로 선 사당. 지붕은 땅에 박히고 주춧돌이 하늘을 받치고 있습니다. 향은 아래로 타고, 종은 거꾸로 웁니다.',
                        '여기서 드리는 기도는 모두 반대로 이루어진다고 합니다. 그래서 이곳 승려들은 잊히기를 빕니다.'],
    'moonless_market': ['달 없는 저잣거리. 섬의 달은 오래전에 팔렸습니다. 장터에서는 지금도 무언가를 사고팝니다. 값은 기억으로 치릅니다.',
                        '좌판 하나에 야행국의 낡은 인장이 찍힌 장부가 놓여 있습니다. 누군가 서둘러 이름을 지운 흔적이 있습니다.'],
    'gwiheo_core': ['귀허. 세상의 모든 물이 돌아와 사라지는 곳입니다. 소용돌이 한가운데에 빈 왕좌가 하나 놓여 있습니다.',
                    '여기까지 온 사람은 다시 돌아가지 않았다고 반요촌 사람들은 말합니다. 그래서 반요촌에는 배웅하는 노래만 있습니다.'],
}

# 재료·소모품: (id, 이름, 분류, 단계, 희귀도, 묶음, 기준가, 거래, 최소 레벨, 설명)
ITEMS = [
    ('reed_silk', '갈대 영사', 'material', 4, 'epic', 5, 380, True, 30, '잿빛 갈대 속에서 뽑은 실. 요기를 머금어도 끊어지지 않는다.'),
    ('inverted_incense', '거꾸로 향목', 'material', 4, 'epic', 5, 380, True, 30, '아래로 타는 향의 나무. 결이 위아래로 뒤집혀 있다.'),
    ('oblivion_crystal', '망각 수정', 'material', 4, 'epic', 5, 420, True, 30, '팔린 기억이 굳은 수정. 들여다보면 낯선 얼굴이 비친다.'),
    ('moonless_silk', '무월 비단', 'material', 4, 'epic', 5, 400, True, 30, '달빛 없이 짠 비단. 빛을 머금지 않아 밤에 몸을 숨기기 좋다.'),
    ('gwiheo_iron', '귀허 흑철', 'material', 4, 'epic', 5, 480, True, 30, '소용돌이 밑바닥에서 건진 검은 쇠. 물에 녹지 않는다.'),
    ('banyo_scale', '반요 비늘', 'material', 3, 'rare', 10, 300, True, 30, '반요가 된 요괴에게서 떨어진 비늘. 사람 살갗의 결이 남아 있다.'),
    ('yoin_blood', '요인 혈정', 'material', 4, 'epic', 5, 520, True, 30, '요화된 이의 피가 굳은 붉은 결정. 6단계 장비의 심이 된다.'),
    ('gwiheo_pearl', '귀허 진주', 'material', 5, 'legendary', 5, 900, True, 30, '귀허의 문지기가 품은 검은 진주. 돌아오지 못한 이의 마지막 빛이 담겼다.'),
    ('gwiheo_charm', '귀허 부적', 'consumable', 4, 'epic', 5, 800, False, 38, '귀허의 주인 앞에 서려면 하나씩 지녀야 하는 부적. 반요촌에서만 판다.'),
    ('banyo_salve', '반요 고약', 'consumable', 3, 'rare', 5, 120, False, 30, '반요촌에서 비늘 상처에 바르는 고약. 체력 +70, 정신 +15, 출혈·화상·중독을 푼다.'),
    ('oblivion_incense', '망각 향', 'consumable', 3, 'rare', 5, 150, False, 30, '나쁜 기억을 잠시 잊게 하는 향. 침식 −30, 정신 +20.'),
]

# 반요촌 잡화: (물품, 기준가(이미 ×2.5~4), 하루 살 수 있는 개수)
BANYO_SHOP = [
    ('gwiheo_charm', 1200, 4), ('banyo_salve', 360, 6), ('oblivion_incense', 520, 4),
    ('tonic', 210, 10), ('ward_talisman', 260, 8), ('travel_ration', 160, 10), ('repair_kit', 0, 3),
    ('spirit_qi_pill', 0, 5), ('revival_charm', 1100, 1), ('ammo_arrow', 0, 200), ('ammo_bolt', 0, 200), ('ammo_dart', 0, 200),
]  # 기준가 0은 원래 기준가 ×3으로 채운다

# 6단계 장비: 5단계 짜임을 따라가고 수치는 약 ×1.25. (id, 이름, 칸, 주 능력치, 최소 레벨, 특성, 설명, 분야, 재료)
LV6 = 32
GEAR = [
    # 근접
    ('w_melee6_base', '귀허 참월도', 'weapon', 'strength', {'power': 48, 'trait': '근접', 'weapon_type': 'melee', 'combat_damage_pct': 18}, '귀허 흑철을 두드려 벼린 달 모양 칼. 고르게 강하다.', 'smithing', {'gwiheo_iron': 5, 'yoin_blood': 3, 'steel_ingot': 4, 'banyo_scale': 3}),
    ('w_melee6_heavy', '소용돌이 철퇴', 'weapon', 'strength', {'power': 57, 'trait': '근접', 'presence': 36, 'weapon_type': 'melee'}, '휘두를 때마다 물살 소리가 난다. 위력이 높지만 노려지기 쉽다.', 'smithing', {'gwiheo_iron': 6, 'yoin_blood': 3, 'steel_ingot': 4, 'monster_core': 2}),
    ('w_melee6_keen', '이름 베는 검', 'weapon', 'strength', {'power': 43, 'trait': '근접', 'crit_pct': 18, 'weapon_type': 'melee'}, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', 'smithing', {'gwiheo_iron': 5, 'yoin_blood': 3, 'oblivion_crystal': 2, 'steel_ingot': 3}),
    ('w_melee6_silent', '무월 귀도', 'weapon', 'strength', {'power': 45, 'trait': '근접', 'presence': -36, 'evasion_pct': 9, 'weapon_type': 'melee'}, '달빛 없는 밤처럼 소리가 없다. 몸놀림도 가벼워진다.', 'smithing', {'gwiheo_iron': 5, 'yoin_blood': 3, 'moonless_silk': 3, 'steel_ingot': 3}),
    # 원거리
    ('w_ranged6_base', '갈대 영궁', 'weapon', 'agility', {'ammo': 'ammo_arrow', 'power': 48, 'trait': '원거리', 'weapon_type': 'ranged', 'combat_damage_pct': 18}, '갈대 영사로 시위를 맨 활. 고르게 강하다.', 'carpentry', {'reed_silk': 5, 'inverted_incense': 3, 'yoin_blood': 3, 'sky_feather': 4}),
    ('w_ranged6_heavy', '해신 쇠뇌', 'weapon', 'agility', {'ammo': 'ammo_bolt', 'power': 57, 'trait': '원거리', 'presence': 36, 'weapon_type': 'ranged'}, '해신당 대들보로 짠 쇠뇌. 위력이 높지만 노려지기 쉽다.', 'carpentry', {'inverted_incense': 4, 'gwiheo_iron': 3, 'yoin_blood': 3, 'reed_silk': 3}),
    ('w_ranged6_keen', '백로 깃 신궁', 'weapon', 'agility', {'ammo': 'ammo_arrow', 'power': 43, 'trait': '원거리', 'crit_pct': 18, 'weapon_type': 'ranged'}, '잿빛 백로 깃을 단 활. 치명타가 잘 터진다.', 'carpentry', {'reed_silk': 5, 'yoin_blood': 3, 'sky_feather': 5, 'oblivion_crystal': 2}),
    ('w_ranged6_silent', '숨 죽인 취관', 'weapon', 'agility', {'ammo': 'ammo_dart', 'power': 45, 'trait': '원거리', 'presence': -36, 'evasion_pct': 9, 'weapon_type': 'ranged'}, '갈대 마디로 만든 취관. 소리 없이 쏜다.', 'carpentry', {'reed_silk': 5, 'moonless_silk': 3, 'yoin_blood': 3, 'shadow_fang': 3}),
    # 술법
    ('w_magic6_base', '거꾸로 법륜', 'weapon', 'spirit_affinity', {'power': 48, 'trait': '술법', 'weapon_type': 'magic', 'combat_damage_pct': 18}, '거꾸로 도는 법륜. 고르게 강하다.', 'artifice', {'inverted_incense': 5, 'oblivion_crystal': 3, 'yoin_blood': 3, 'rune_plate': 3}),
    ('w_magic6_heavy', '귀허 범종', 'weapon', 'spirit_affinity', {'power': 57, 'trait': '술법', 'presence': 36, 'weapon_type': 'magic'}, '귀허에서 건진 작은 범종. 위력이 높지만 노려지기 쉽다.', 'artifice', {'gwiheo_iron': 4, 'inverted_incense': 3, 'yoin_blood': 3, 'rune_plate': 3}),
    ('w_magic6_keen', '망각 수정 부채', 'weapon', 'spirit_affinity', {'power': 43, 'trait': '술법', 'crit_pct': 18, 'weapon_type': 'magic'}, '망각 수정을 박은 부채. 치명타가 잘 터진다.', 'artifice', {'oblivion_crystal': 5, 'moonless_silk': 2, 'yoin_blood': 3, 'mirror_shard': 3}),
    ('w_magic6_silent', '꺼진 등롱 법등', 'weapon', 'spirit_affinity', {'power': 45, 'trait': '술법', 'presence': -36, 'evasion_pct': 9, 'weapon_type': 'magic'}, '불 없이 밝히는 법등. 요괴의 눈에 덜 띈다.', 'artifice', {'oblivion_crystal': 4, 'moonless_silk': 3, 'yoin_blood': 3, 'spirit_core': 2}),
    # 방어구
    ('a6_iron', '흑철 비늘갑', 'armor', 'vitality', {'trait': '방호', 'defense': 44, 'presence': 48, 'evasion_pct': -6}, '귀허 흑철과 반요 비늘을 엮은 갑옷. 단단하지만 요괴의 이목을 끈다.', 'smithing', {'gwiheo_iron': 5, 'banyo_scale': 5, 'yoin_blood': 3, 'steel_ingot': 3}),
    ('a6_light', '갈대 영사 경갑', 'armor', 'agility', {'trait': '방호', 'defense': 27, 'evasion_pct': 9}, '갈대 영사로 누빈 가벼운 갑옷. 몸을 틀어 피하기 좋다.', 'leatherwork', {'reed_silk': 5, 'banyo_scale': 4, 'yoin_blood': 3, 'reinforced_leather': 3}),
    ('a6_robe', '거꾸로 법의', 'armor', 'willpower', {'trait': '방호', 'defense': 22, 'erosion_pct': -18, 'damage_reduction_pct': 12}, '거꾸로 수놓은 법의. 받는 피해를 덜고 요기를 막는다.', 'weaving', {'inverted_incense': 4, 'moonless_silk': 3, 'yoin_blood': 3, 'spirit_thread': 3}),
    ('a6_shade', '무월 야행의', 'armor', 'agility', {'trait': '방호', 'defense': 19, 'crit_pct': 6, 'presence': -48, 'evasion_pct': 6}, '달 없는 밤의 비단옷. 요괴의 눈을 피하고 빈틈을 노린다.', 'leatherwork', {'moonless_silk': 5, 'banyo_scale': 4, 'yoin_blood': 3, 'shadow_fang': 3}),
    # 관모
    ('h6_calm', '망각 관모', 'hat', 'willpower', {'trait': '관모', 'erosion_pct': -24, 'mental_loss_pct': -36}, '나쁜 기억을 덮어 주는 관모. 요기와 두려움을 막는다.', 'weaving', {'oblivion_crystal': 3, 'moonless_silk': 3, 'yoin_blood': 2}),
    ('h6_guard', '흑철 투구', 'hat', 'vitality', {'trait': '관모', 'defense': 12, 'presence': 30}, '귀허 흑철로 두드린 투구. 앞장서는 이에게 어울린다.', 'smithing', {'gwiheo_iron': 4, 'banyo_scale': 3, 'yoin_blood': 2}),
    ('h6_wise', '거꾸로 익선관', 'hat', 'perception', {'trait': '관모', 'crit_pct': 6, 'clue_bonus_pct': 24}, '거꾸로 읽어야 보이는 글이 새겨진 관. 단서가 잘 보이고 급소를 읽는다.', 'weaving', {'inverted_incense': 3, 'reed_silk': 3, 'yoin_blood': 2}),
    # 신
    ('s6_road', '갈대 짚신', 'shoes', 'vitality', {'trait': '신', 'travel_time_pct': -24}, '갈대 영사로 삼은 신. 먼 길을 덜 지치게 걷는다.', 'leatherwork', {'reed_silk': 4, 'banyo_scale': 3, 'yoin_blood': 2}),
    ('s6_sturdy', '흑철 장화', 'shoes', 'vitality', {'trait': '신', 'defense': 9, 'presence': 24}, '땅을 굳게 딛는 흑철 장화.', 'leatherwork', {'gwiheo_iron': 3, 'banyo_scale': 4, 'yoin_blood': 2}),
    ('s6_swift', '무월 비단신', 'shoes', 'agility', {'trait': '신', 'flee_pct': 18, 'evasion_pct': 9}, '발소리가 나지 않는 비단신. 피하고 달아나기 좋다.', 'leatherwork', {'moonless_silk': 4, 'banyo_scale': 3, 'yoin_blood': 2}),
    # 노리개
    ('n6_keen', '사슬 장도 노리개', 'norigae', 'perception', {'trait': '노리개', 'crit_pct': 12}, '흰 사슬 한 마디를 단 장도 노리개. 급소를 노리는 눈이 밝아진다.', 'weaving', {'gwiheo_iron': 2, 'reed_silk': 3, 'yoin_blood': 2}),
    ('n6_luck', '귀허 진주 노리개', 'norigae', 'spirit_affinity', {'trait': '노리개', 'rare_loot_pct': 18}, '검은 진주를 꿴 노리개. 귀한 전리품이 잘 나온다.', 'weaving', {'gwiheo_pearl': 1, 'reed_silk': 3, 'yoin_blood': 2}),
    ('n6_plenty', '반요촌 풍년 노리개', 'norigae', 'vitality', {'trait': '노리개', 'craft_quality': 6, 'gather_qty_pct': 18}, '반요촌 아낙들이 엮는 노리개. 거두는 양과 솜씨가 는다.', 'weaving', {'reed_silk': 4, 'banyo_scale': 3, 'yoin_blood': 2}),
    # 호신부
    ('m6_purify', '거꾸로 향낭', 'amulet', 'willpower', {'trait': '호신부', 'erosion_pct': -18, 'healing_pct': 18}, '거꾸로 향목을 넣은 향낭. 침식이 덜하고 회복이 잘 된다.', 'sealing', {'inverted_incense': 4, 'moonless_silk': 2, 'yoin_blood': 2}),
    ('m6_spell', '망각 부적낭', 'amulet', 'spirit_affinity', {'trait': '호신부', 'magic_pct': 18}, '망각 수정 가루로 그린 부적을 품는다. 술법이 세진다.', 'sealing', {'oblivion_crystal': 3, 'inverted_incense': 2, 'yoin_blood': 2}),
    ('m6_ward', '귀허 문지기 호패', 'amulet', 'willpower', {'trait': '호신부', 'presence': 24, 'incoming_damage_pct': -12}, '문지기의 거울 조각을 댄 호패. 받는 피해가 줄고 요괴가 먼저 노린다.', 'sealing', {'gwiheo_iron': 3, 'mirror_shard': 2, 'yoin_blood': 2}),
    # 탈
    ('k6_awe', '반요 탈', 'mask', 'strength', {'trait': '탈', 'presence': 60, 'combat_damage_pct': 9}, '비늘 돋은 얼굴을 본뜬 탈. 요괴가 먼저 덤비지만 기세가 오른다.', 'sealing', {'banyo_scale': 5, 'yoin_blood': 2, 'inverted_incense': 2}),
    ('k6_ghost', '사공 탈', 'mask', 'spirit_affinity', {'trait': '탈', 'encounter_pct': 18, 'rare_loot_pct': 12}, '이름 잃은 사공의 얼굴. 요괴를 불러들이고 귀한 것을 끌어낸다.', 'sealing', {'reed_silk': 3, 'ghost_ash': 4, 'yoin_blood': 2}),
    ('k6_hide', '얼굴 지운 탈', 'mask', 'agility', {'trait': '탈', 'presence': -60, 'encounter_pct': -18}, '저잣거리 손님의 얼굴 없는 탈. 요괴의 눈에 덜 띄고 덜 마주친다.', 'sealing', {'moonless_silk': 3, 'shadow_fang': 3, 'yoin_blood': 2}),
    # 채집도
    ('t6_gather', '귀허 흑철 채집도', 'tool', 'perception', {'trait': '정밀 채집', 'rare_loot_pct': 7, 'gathering_bonus_pct': 26}, '물에 녹지 않는 흑철 날. 채집할 때 더 많이 거둔다.', 'smithing', {'gwiheo_iron': 4, 'oblivion_crystal': 2, 'yoin_blood': 2}),
]
# 드롭: 습성별로 어느 6단계 장비가 나오는지(5단계 짜임과 같은 갈래)
GEAR_DROP = {
    'w_melee6_base': ['armored', 'swarm', 'boss'], 'w_melee6_heavy': ['armored', 'swarm', 'boss'], 'w_melee6_keen': ['armored', 'swarm', 'boss'], 'w_melee6_silent': ['armored', 'swarm', 'boss'],
    'w_ranged6_base': ['aerial', 'ambush', 'boss'], 'w_ranged6_heavy': ['aerial', 'ambush', 'boss'], 'w_ranged6_keen': ['aerial', 'ambush', 'boss'], 'w_ranged6_silent': ['aerial', 'ambush', 'boss'],
    'w_magic6_base': ['spectral', 'warded', 'seal_breaker', 'boss'], 'w_magic6_heavy': ['spectral', 'warded', 'seal_breaker', 'boss'], 'w_magic6_keen': ['spectral', 'warded', 'seal_breaker', 'boss'], 'w_magic6_silent': ['spectral', 'warded', 'seal_breaker', 'boss'],
    'a6_iron': ['armored', 'boss'], 'a6_light': ['aerial', 'swarm', 'boss'], 'a6_robe': ['spectral', 'warded', 'boss'], 'a6_shade': ['ambush', 'boss'],
    'h6_calm': ['spectral', 'seal_breaker', 'boss'], 'h6_guard': ['armored', 'boss'], 'h6_wise': ['warded', 'reflect', 'boss'],
    's6_road': ['swarm', 'tide', 'boss'], 's6_sturdy': ['armored', 'boss'], 's6_swift': ['aerial', 'boss'],
    'n6_keen': ['ambush', 'boss'], 'n6_luck': ['tide', 'reflect', 'boss'], 'n6_plenty': ['toxic', 'swarm', 'boss'],
    'm6_purify': ['toxic', 'boss'], 'm6_spell': ['spectral', 'boss'], 'm6_ward': ['seal_breaker', 'warded', 'boss'],
    'k6_awe': ['armored', 'boss'], 'k6_ghost': ['spectral', 'reflect', 'boss'], 'k6_hide': ['ambush', 'boss'],
    't6_gather': ['toxic', 'swarm', 'boss'],
}

# 섬 조사 지점(지역마다 셋)
SITES = {
    'ash_reeds': [('supply', '잿빛 갈대숲 · 떠내려온 짐', ['herb', 'travel_ration', 'tonic', 'river_reed', 'reed_silk', 'wood', 'resin'], ['reed_silk', 'yoin_blood', 'banyo_scale']),
                  ('medical', '잿빛 갈대숲 · 물가 약막', ['herb', 'medicine_base', 'tonic', 'moon_moss', 'herbal_extract'], ['banyo_salve', 'herbal_extract', 'reed_silk']),
                  ('relic', '잿빛 갈대숲 · 이름 말뚝', ['seal_paper', 'ghost_ash', 'reed_silk', 'ward_fragment'], ['yoin_blood', 'reed_silk', 'spirit_core'])],
    'inverted_shrine': [('relic', '거꾸로 선 사당 · 뒤집힌 장경각', ['seal_paper', 'inkstone', 'talisman_thread', 'inverted_incense', 'ward_fragment'], ['inverted_incense', 'rune_plate', 'spirit_core']),
                        ('medical', '거꾸로 선 사당 · 약사전', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['banyo_salve', 'inverted_incense', 'medicine_base']),
                        ('supply', '거꾸로 선 사당 · 공양간 광', ['herb', 'travel_ration', 'tonic', 'wood', 'inverted_incense'], ['yoin_blood', 'banyo_scale', 'inverted_incense'])],
    'moonless_market': [('supply', '달 없는 저잣거리 · 빈 객주 광', ['herb', 'travel_ration', 'tonic', 'moonless_silk', 'silk'], ['moonless_silk', 'yoin_blood', 'banyo_scale']),
                        ('relic', '달 없는 저잣거리 · 지운 장부 창고', ['seal_paper', 'inkstone', 'oblivion_crystal', 'ward_fragment'], ['oblivion_crystal', 'spirit_core', 'yoin_blood']),
                        ('medical', '달 없는 저잣거리 · 문 닫힌 약방', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['banyo_salve', 'oblivion_incense', 'herbal_extract'])],
    'gwiheo_core': [('abyss', '귀허 · 가라앉은 배', ['gwiheo_iron', 'drowned_scale', 'ward_fragment', 'spirit_dust', 'travel_ration'], ['gwiheo_iron', 'yoin_blood', 'gwiheo_pearl']),
                    ('relic', '귀허 · 무너진 해신당', ['seal_paper', 'ward_fragment', 'gwiheo_iron', 'ghost_ash'], ['gwiheo_pearl', 'spirit_core', 'yoin_blood']),
                    ('medical', '귀허 · 마지막 배웅터', ['herb', 'medicine_base', 'tonic', 'banyo_salve'], ['banyo_salve', 'oblivion_incense', 'revival_charm'])],
}
