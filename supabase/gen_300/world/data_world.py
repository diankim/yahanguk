TERR = ('deungdo', '등도 옛터')
TERR_JEONGNI = ('jeongni', '정리소')
QUESTS = ['mdq_' + str(n) for n in range(1, 18)]
OPEN_QUEST = {'deungdo': 'mdq_5:2', 'jeongni': 'mdq_13:6'}
FERRY = 'deungdo_landing'
WEAK_SAFE = ['deungdo_landing', 'lamp_rest']
CAP = 50
LV8 = 47
TOOL_LV = 45

REGIONS = [
    dict(id='deungdo_landing', name='남문 수로 선착', type='village', danger=9, lv=45, x=252, y=528, el=-1, nb=['seal_vault', 'dark_yamen'],
         theme='water', safe=True, desc='옛 남문 물길이 닿는 돌계단이다. 흑련 장부지기와 수향 뱃사람이 임시 야영소를 차려 두었고, 거룻배 몇 척이 말뚝에 매여 있다.',
         rest=('선착 야영소 천막', 'inn', 170, 2), shop=('deungdo_landing_shop', '선착 야영소')),
    dict(id='dark_yamen', name='꺼진 관아 터', type='ruins', danger=10, lv=45, x=226, y=562, el=1, nb=['deungdo_landing', 'martial_row', 'red_shrine_lane', 'old_ferry_market'],
         theme='city', desc='흰 하늘 아래 쓰러진 대문과 현판 하나만 남은 옛 관아다. 안채 벽에는 백 년 전 서식이 그대로 붙어 있다.'),
    dict(id='martial_row', name='무관 거리', type='ruins', danger=10, lv=46, x=172, y=578, el=1, nb=['dark_yamen', 'lamp_rest'],
         theme='mountain', desc='북령 무관들이 살던 거리다. 돌바닥 틈마다 녹지 않는 서리가 끼었고, 연무 마당에는 화살이 허공에 멈춰 있다.'),
    dict(id='red_shrine_lane', name='붉은 사당 골목', type='ruined_temple', danger=10, lv=47, x=214, y=612, el=0, nb=['dark_yamen', 'lamp_rest'],
         theme='shrine', desc='적월 무리가 등을 거꾸로 걸어 둔 골목이다. 사당 벽은 기름때 낀 축문으로 덮였고, 담장 너머에 기름 곳간이 있다.'),
    dict(id='old_ferry_market', name='옛 나루 저자', type='coast', danger=10, lv=48, x=268, y=602, el=-1, nb=['dark_yamen', 'lamp_rest'],
         theme='water', desc='물이 마른 물길 위에 배들이 얹혀 있는 수향 무리의 저자다. 돛대 셋이 만나는 자리의 우물 밑으로 물굴이 이어진다.'),
    dict(id='lamp_rest', name='등지기 쉼막', type='village', danger=9, lv=48, x=216, y=650, el=0, nb=['martial_row', 'red_shrine_lane', 'old_ferry_market', 'first_observatory', 'ash_palace'],
         theme='city', safe=True, desc='명등지기가 등을 고치던 쉼막 터다. 수향 뱃사람들이 처마를 고쳐 거처를 차렸고, 늘 등 하나를 켜 둔다.',
         rest=('쉼막 등불 곁 자리', 'inn', 180, 2), shop=('lamp_rest_shop', '쉼막 등 가게')),
    dict(id='first_observatory', name='첫 관상대', type='celestial_tower', danger=10, lv=49, x=170, y=690, el=3, nb=['lamp_rest', 'pact_court'],
         theme='sky', desc='천명 무리가 별을 재던 옛 관상대다. 녹슨 혼천의와 별 기록판이 남았지만 흰 하늘에는 별이 하나도 없다.'),
    dict(id='ash_palace', name='잿빛 왕궁 터', type='ruins', danger=10, lv=49, x=262, y=692, el=1, nb=['lamp_rest', 'pact_court'],
         theme='desert', desc='등도 남쪽 끝, 남명 무리의 옛 궁궐 터다. 하얗게 바랜 기둥 사이 돌 단 위에 빈 옥좌가 놓여 있다.'),
    dict(id='pact_court', name='맹약 마당', type='sealed_shrine', danger=10, lv=50, x=216, y=732, el=0, nb=['first_observatory', 'ash_palace'],
         theme='shrine', desc='흰 밤이 가장 짙은 등도 한가운데다. 일곱 홈이 원을 그린 돌상 둘레에 꺼진 등롱 일곱이 서 있고, 가장자리로 먹 도랑이 감돈다.'),
    dict(id='jeongni_vault', name='정리소', type='underground', danger=10, lv=49, x=492, y=418, el=-3, nb=['hq_archive'], terr=TERR_JEONGNI,
         theme='deep', desc='장서각 지하서고 맨 끝 우물로 내려가면 나오는 정청 밑 방들이다. 먹 도랑이 흐르고, 가늠 저울과 봉연 수위 표가 줄지어 있다.'),
]

REGION_OPEN = {'deungdo_landing': 'mdq_5:2', 'dark_yamen': 'mdq_5:2', 'martial_row': 'mdq_5', 'red_shrine_lane': 'mdq_7', 'old_ferry_market': 'mdq_9', 'lamp_rest': 'mdq_9',
               'first_observatory': 'mdq_11', 'ash_palace': 'mdq_14:6', 'pact_court': 'mdq_16:3'}
NIGHT_BACK = {'deungdo_landing': 'mdq_4', 'dark_yamen': 'mdq_16', 'martial_row': 'mdq_6', 'red_shrine_lane': 'mdq_8', 'old_ferry_market': 'mdq_10', 'lamp_rest': 'mdq_10',
              'first_observatory': 'mdq_11', 'ash_palace': 'mdq_13', 'pact_court': 'mdq_16'}
DOMAIN_FX = {
    'name': '백야',
    'white_night': True,
    'no_rescue': True,
    'guard': ['beneath_lamp', 'undying_glow'],
    'effects': {'mental_loss_pct': 15, 'incoming_damage_pct': 5, 'encounter_pct': 5, 'wn_sneak': 15, 'wn_quiet': 10, 'wn_eva': 3},
    'recall': {'per_day': 1, 'hp': 1, 'status': 'faded_name'},
}

NODES = {
    'deungdo_landing': [['남문 물길 돌계단'], ['거룻배 매는 말뚝', '야영소 천막 앞']],
    'lamp_rest': [['쉼막 들머리 디딤돌'], ['등 고치던 마루', '뱃사람 거처 처마']],
    'dark_yamen': [
        ['관아 앞 돌계단'],
        ['쓰러진 대문 자리', '무너진 담장 셋'],
        ['흰 기와 골목', '현판 걸린 기둥', '안마당 불 자리', '바랜 등롱 처마 길'],
        ['안채 서식 벽', '셈표 새긴 방', '미룸 칸 그린 벽', '물방울 멈춘 처마 밑', '마른 서까래 더미', '관아 뒷간 우물'],
        ['맨 안쪽 서식 방', '뒤뜰 느티나무', '도제조 집무실', '백 년 전 서고', '빈 인장함 자리', '이름 바랜 등롱 줄', '관아 뒤 흰 골목', '부르다 굳은 마당'],
    ],
    'martial_row': [
        ['무관 거리 어귀'],
        ['서리 낀 돌바닥', '세 번째 갈림길'],
        ['연무 마당', '짚 목인 줄', '무관 우물가', '닫힌 무기고 앞'],
        ['연무 마당 끝', '허공에 멈춘 화살 앞', '이름 새긴 목인 곁', '무기고 안 시렁', '종루 아래 돌계단', '얼어붙은 과녁 터'],
        ['종루 꼭대기', '녹아내린 종채 자리', '소등 밤 종 아래', '북령 무관 숙소', '무너진 활터 담', '서리 앉은 우물 바닥', '술 늘어진 깃대', '거리 끝 망루'],
    ],
    'red_shrine_lane': [
        ['붉은 골목 어귀'],
        ['거꾸로 건 등 아래', '기름 얼룩 담장'],
        ['축문 벽 사당', '붉은 칠 벗겨진 문', '좁은 기름 골목', '향 꺼진 제단 앞'],
        ['돌 궤짝 제단', '해 지는 쪽 담장', '기름 곳간 문', '무녀 거처 툇마루', '거꾸로 쓴 축문 기둥', '반쪽 달 그린 처마'],
        ['첫 기름 곳간', '사당 맨 안쪽 감실', '서약 새긴 돌판', '열네 살 무녀 방', '달 지는 담 너머', '붉은 등 끊긴 줄', '기름 마른 항아리 줄', '골목 끝 붉은 우물'],
    ],
    'old_ferry_market': [
        ['마른 물길 둑'],
        ['얹힌 배 사이 길', '빈 좌판 줄'],
        ['청씨 선단 뱃머리', '돛대 셋 만나는 자리', '값 적은 장부 좌판', '마른 갈대 둑'],
        ['붙드는 물 우물', '청씨 선단 선실', '갈라진 뱃바닥', '수향 뱃사람 거처', '물 빠진 선창 계단', '닻 걸린 돌기둥'],
        ['우물 밑 물굴 어귀', '정리소 배 대는 돌 나루', '물굴 안 매듭 자리', '두 번째 잠수 바위', '물 없는 나루 끝', '숨 고르던 바위턱', '배 위 장부방', '마른 물길 가장 깊은 곳'],
    ],
    'first_observatory': [
        ['관상대 오르는 길'],
        ['녹슨 혼천의 마당', '별 기록판 방 문'],
        ['혼천의 받침 아래', '출입 장부 책상', '관상대 둘레 우물', '관측관 숙소'],
        ['별 기록판 방', '녹슨 열쇠 걸이', '잘못 읽은 별 표', '구름 없는 흰 하늘 아래', '관측 누대 계단', '별 이름 지운 판'],
        ['관상대 맨 위 누대', '숨은 별 자리', '업힌 관측관이 쉬던 곳', '그날 밤 기록 상자', '반만 남은 별자리 판', '하늘 재던 자 걸이', '관상대 뒤 낭떠러지', '빈 별 아래 마당'],
    ],
    'ash_palace': [
        ['왕궁 터 남문'],
        ['하얗게 바랜 기둥 줄', '재 덮인 궁 계단'],
        ['빈 회랑', '궁녀 처소 터', '임금 뜰 돌길', '재 쌓인 연못'],
        ['옥좌 뒤 정원', '옥좌 돌 단 아래', '서명 지운 서고', '불씨 항아리 놓던 자리', '동틀 녘 망루', '부서진 궁문'],
        ['빈 옥좌 앞', '임금의 등 자리', '둥근 자국 남은 바닥', '남쪽 끝 궁벽', '불 꺼진 침전', '재 날리는 누각', '마지막 아이 숨던 곳', '왕궁 맨 안쪽 뜰'],
    ],
    'pact_court': [
        ['맹약 마당 둘레 길'],
        ['꺼진 등롱 첫 자리', '먹 도랑 가장자리'],
        ['둘레 등롱 셋째 자리', '흰 밤 짙은 길', '도랑에 귀 대던 곳', '일곱 홈 바깥 금'],
        ['둥근 돌상 앞', '일곱 홈 원', '꺼진 등롱 일곱째 자리', '먹 도랑 물머리', '이름 떼어 낸 자리', '흰 밤 된 사람 서던 곳'],
        ['돌상 한가운데', '일곱째 홈', '둥근 돌상 아래', '닫힌 문틈 앞', '재가 된 일곱 장 자리', '처음 생긴 그림자 자리', '마당 한가운데 흰빛', '먹 도랑 끝'],
    ],
    'jeongni_vault': [
        ['정리소 내려가는 우물'],
        ['먹 도랑 첫 굽이', '젖은 돌계단'],
        ['가늠 저울 방', '봉연 수위 표 앞', '장독 늘어선 곳', '정리 명부 서가'],
        ['먹 도랑 둑', '모서리 접힌 서류 더미', '저울추 쌓인 시렁', '수위 표석 아래', '정리관 서안', '등잔 꺼진 복도'],
        ['금고 문 앞', '금고 안쪽', '첫 줄 적힌 벽', '도랑 물 고이는 웅덩이', '정리소 맨 밑바닥', '저울 받침돌', '장서각 쪽 막힌 길', '먹 도랑 끝 수문'],
    ],
}
EXTRA_NODES = {'seal_vault': [('갈라진 창고 끝 계단', 3)]}

SPOT_ADJ = {
    'deungdo_landing': ['물길 젖은', '말뚝 박힌'],
    'lamp_rest': ['등불 켜 둔', '처마 고친'],
    'dark_yamen': ['흰 기와 덮인', '서식 붙은', '현판 기운', '빛 바랜', '대문 쓰러진', '물방울 멈춘', '서까래 마른', '셈표 새긴', '담장 무너진', '등롱 줄 늘어진', '도장 찍힌'],
    'martial_row': ['서리 낀', '화살 멈춘', '목인 선', '종소리 그친', '술 늘어진', '과녁 언', '시위 끊긴', '돌바닥 언', '무기고 닫힌', '깃대 꺾인', '연무 자국 남은'],
    'red_shrine_lane': ['거꾸로 건 등 아래', '기름때 낀', '붉은 칠 벗겨진', '축문 적힌', '향 꺼진', '반쪽 달 그린', '기름 고인', '담장 너머', '서약 새긴', '무녀 다녀간', '달 지는'],
    'old_ferry_market': ['배 얹힌', '물 마른', '돛대 기운', '장부 펼친', '닻 걸린', '좌판 빈', '갈대 마른', '뱃바닥 갈라진', '청씨 깃발 단', '물굴 냄새 나는', '선창 무너진'],
    'first_observatory': ['혼천의 녹슨', '별 없는', '기록판 놓인', '흰 하늘 비친', '누대 기운', '자 걸린', '출입 장부 펼친', '별자리 새긴', '열쇠 걸린', '관측관 다녀간', '우물 곁'],
    'ash_palace': ['재 덮인', '기둥 바랜', '옥좌 향한', '궁문 부서진', '불씨 꺼진', '연못 마른', '궁녀 다니던', '침전 곁', '누각 아래', '돌 단 앞', '동틀 녘'],
    'pact_court': ['흰 밤 짙은', '등롱 꺼진', '도랑 감도는', '일곱 홈 새긴', '돌상 곁', '원 그린', '그림자 없는', '빛먼지 뜬', '맹약 새긴', '이름 떼어 낸', '마당 끝'],
    'jeongni_vault': ['먹 도랑 흐르는', '저울 놓인', '수위 표 선', '장독 줄 선', '서류 접힌', '등잔 꺼진', '정리관 다녀간', '돌계단 젖은', '금고 곁', '수문 닫힌', '모서리 접힌'],
}
SPOT_NOUN = {
    'relics': ['바랜 서식 더미', '흰 등롱 무더기', '빈 인장 궤짝', '지워진 현판 조각', '먼지 앉은 장부 함'],
    'water': ['마른 물길 웅덩이', '흰 물 고인 홈', '흐르지 않는 개울', '바랜 갈대 둑', '멈춘 물 고인 독'],
    'supplies': ['두고 간 야영 짐', '빈 뱃짐 궤짝', '흰 천 덮은 짐더미', '바랜 기름 단지', '주인 없는 행낭'],
    'herbs': ['흰 밤 약풀 틈', '바랜 쑥 둔덕', '빛 바랜 약초 그늘', '흰 이끼 바위', '서리 앉은 풀섶'],
    'wood': ['색 빠진 서까래', '흰 고목 둥치', '마른 뱃판 더미', '멈춘 화살대 묶음', '바랜 대들보'],
    'spirit': ['흰빛 고인 구렁', '부르다 굳은 자리', '이름 바랜 돌', '빛먼지 맺힌 곳', '넋 머문 등롱'],
    'ore': ['흰 서리 쇳돌', '녹슨 종루 쇠 더미', '바랜 주춧돌 틈', '흰 광맥 바위', '저울추 굴러든 틈'],
}
SPOT_LOOT = {
    'deungdo_landing': {'supplies': ['herb', 'travel_ration', 'tonic'], 'water': ['river_reed', 'river_reed', 'white_night_frost']},
    'lamp_rest': {'supplies': ['herb', 'travel_ration', 'severed_lamp_oil'], 'water': ['river_reed', 'river_reed', 'white_night_frost']},
    'dark_yamen': {'relics': ['seal_paper', 'bleached_lantern_paper', 'century_form_scrap', 'century_form_scrap'], 'supplies': ['herb', 'travel_ration', 'bleached_lantern_paper', 'bleached_lantern_paper'],
                   'herbs': ['herb', 'medicine_base', 'white_night_frost']},
    'martial_row': {'ore': ['ore', 'raw_iron', 'frost_bell_iron', 'frost_bell_iron'], 'wood': ['wood', 'frozen_arrow_shaft', 'frozen_arrow_shaft'],
                    'supplies': ['herb', 'travel_ration', 'white_night_frost']},
    'red_shrine_lane': {'supplies': ['herb', 'travel_ration', 'severed_lamp_oil', 'severed_lamp_oil'], 'water': ['river_reed', 'severed_lamp_oil', 'white_night_frost'],
                        'wood': ['wood', 'resin', 'red_shrine_lacquer', 'red_shrine_lacquer']},
    'old_ferry_market': {'wood': ['wood', 'waterlogged_plank', 'waterlogged_plank'], 'water': ['river_reed', 'river_reed', 'white_night_frost'],
                         'herbs': ['herb', 'medicine_base', 'white_night_frost']},
    'first_observatory': {'spirit': ['spirit_dust', 'star_sand', 'faded_star_glass'], 'ore': ['ore', 'faded_star_glass', 'faded_star_glass'],
                          'relics': ['seal_paper', 'star_record_plate', 'star_record_plate']},
    'ash_palace': {'relics': ['seal_paper', 'king_ember_ash', 'king_ember_ash'], 'spirit': ['ghost_ash', 'spirit_dust', 'king_ember_ash'],
                   'herbs': ['herb', 'medicine_base', 'white_night_frost']},
    'pact_court': {'ore': ['ore', 'raw_iron', 'pact_stone_dust', 'pact_stone_dust'], 'relics': ['seal_paper', 'pact_stone_dust'],
                   'spirit': ['spirit_dust', 'white_night_frost', 'white_night_frost']},
    'jeongni_vault': {'ore': ['ore', 'raw_iron', 'balance_weight'], 'relics': ['seal_paper', 'ledger_tab', 'ledger_tab']},
}
ENTRY_SPOT = {
    'deungdo_landing': ('어귀의 물길 돌계단 틈', 'water'), 'lamp_rest': ('어귀의 쉼막 처마 밑', 'supplies'),
    'dark_yamen': ('어귀의 바랜 등롱 처마', 'relics'), 'martial_row': ('어귀의 언 과녁 더미', 'wood'),
    'red_shrine_lane': ('어귀의 기름 고인 처마 밑', 'supplies'), 'old_ferry_market': ('어귀의 얹힌 거룻배', 'wood'),
    'first_observatory': ('어귀의 녹슨 혼천의 받침', 'ore'), 'ash_palace': ('어귀의 재 덮인 계단', 'relics'),
    'pact_court': ('어귀의 돌상 둘레 돌', 'ore'), 'jeongni_vault': ('어귀의 도랑 둑', 'ore'),
}

W = 'lamp_wick_core'
F = 'white_night_frost'
C = 'spirit_core'
MONSTERS = {
    'dark_yamen': [
        ('dd_yamen_1', '부르다 굳은 넋', '원령', 'common', 'ghost', 'spectral', '누군가의 이름을 부르다 그대로 굳어 버린 넋이다. 입은 크게 벌렸는데 소리는 한 걸음 밖으로 나가지 않는다.', {W: 1, F: 1}),
        ('dd_yamen_2', '바랜 등롱 나방', '비행 요괴', 'common', 'bird', 'aerial', '꺼진 등롱 종이를 갉아 먹고 자란 흰 나방이다. 날개를 털 때마다 바랜 글자 가루가 흩날린다.', {'bleached_lantern_paper': 1, W: 1}),
        ('dd_yamen_3', '서식 긁는 손톱귀', '매복 요괴', 'main', 'shadow', 'ambush', '안채 벽 서식 뒤에 숨어 칸마다 손톱자국을 내는 요괴다. 서식을 읽는 이의 등 뒤로 소리 없이 다가온다.', {'century_form_scrap': 2, W: 2, F: 1}),
        ('dd_yamen_4', '멈춘 물방울 무리', '무리 요괴', 'main', 'swarm', 'swarm', '처마 끝에서 떨어지다 멈춘 물방울들이 떼를 지었다. 살갗에 닿으면 얼음처럼 들러붙는다.', {F: 2, W: 2}),
        ('dd_yamen_5', '현판 아래 문지기', '지역 우두머리', 'guardian', 'giant', 'boss', '비스듬히 매달린 현판 아래를 지키는 거대한 문지기다. 서식에 이름이 없는 자는 한 발짝도 들이지 않는다.', {'century_form_scrap': 3, W: 3, C: 1}),
    ],
    'martial_row': [
        ('dd_martial_1', '과녁 못 닿은 화살귀', '비행 요괴', 'common', 'bird', 'aerial', '과녁에 닿지 못하고 허공에 멈췄던 화살이 요괴가 되었다. 일흔 해 묵은 기세로 사람을 과녁 삼아 날아든다.', {'frozen_arrow_shaft': 1, W: 1}),
        ('dd_martial_2', '짚 목인 그림자', '매복 요괴', 'common', 'shadow', 'ambush', '그림자 없는 땅에서 목인이 제 그림자를 찾아 걸어 나왔다. 줄지어 선 목인 사이에 섞여 있다가 덮친다.', {F: 1, W: 1}),
        ('dd_martial_3', '서리 갑옷 무관', '갑각 요괴', 'main', 'shell', 'armored', '녹지 않는 서리를 갑옷처럼 두른 무관의 넋이다. 소등 밤 종이 울린 그날의 자세로 연무 마당을 지킨다.', {'frost_bell_iron': 2, W: 2, F: 1}),
        ('dd_martial_4', '종소리 먹은 늑대', '거울 요괴', 'main', 'mirror', 'reflect', '종루에서 흩어진 종소리를 삼킨 늑대다. 맞은 소리를 그대로 되울려 상대에게 돌려준다.', {'frost_bell_iron': 2, W: 2, F: 1}),
        ('dd_martial_5', '녹아내린 종지기 그림자', '지역 우두머리', 'guardian', 'breaker', 'seal_breaker', '종채가 녹아내린 종루 꼭대기에서 일어선 종지기의 그림자다. 몸을 흔들 때마다 봉인이 종소리처럼 갈라진다.', {'frost_bell_iron': 3, W: 3, C: 1}),
    ],
    'red_shrine_lane': [
        ('dd_shrine_1', '거꾸로 매달린 등귀', '원령', 'common', 'ghost', 'spectral', '거꾸로 건 등 안에 갇힌 넋이다. 등이 흔들릴 때마다 뒤집힌 얼굴이 종이 너머로 비친다.', {'severed_lamp_oil': 1, W: 1}),
        ('dd_shrine_2', '기름 핥는 쥐떼', '무리 요괴', 'common', 'swarm', 'swarm', '끊긴 등 기름을 핥으며 불어난 흰 쥐떼다. 지나간 자리마다 기름 자국이 길게 남는다.', {'severed_lamp_oil': 1, W: 1}),
        ('dd_shrine_3', '거꾸로 외는 축문귀', '결계 요괴', 'main', 'ward', 'warded', '사당 벽의 축문을 끝에서부터 거꾸로 외는 요괴다. 한 구절을 욀 때마다 몸에 붉은 금줄이 한 겹 감긴다.', {'red_shrine_lacquer': 2, W: 2, F: 1}),
        ('dd_shrine_4', '달 지기 허물', '독충', 'main', 'venom', 'toxic', '반쪽 달을 지키던 벌레가 벗어 둔 허물이 스스로 움직인다. 허물 틈으로 붉은 독기가 샌다.', {'red_shrine_lacquer': 2, W: 2, F: 1}),
        ('dd_shrine_5', '반쪽 달 무녀', '지역 우두머리', 'guardian', 'ward', 'warded', '얼굴 반쪽만 남은 무녀의 넋이다. 첫 기름 곳간 앞을 지키며 서약을 거꾸로 되뇐다.', {'red_shrine_lacquer': 3, W: 3, C: 1}),
    ],
    'old_ferry_market': [
        ('dd_ferry_1', '마른 물길 게', '갑각 요괴', 'common', 'shell', 'armored', '물이 마른 물길 바닥에서 껍질만 단단해진 커다란 게다. 얹힌 배 밑에 숨어 집게를 벌린다.', {'waterlogged_plank': 1, W: 1}),
        ('dd_ferry_2', '문패 문 물귀', '수귀', 'common', 'water', 'tide', '배 이름이 적힌 문패를 입에 문 채 마른 물길을 헤엄치는 물귀다. 물 한 방울 없는 바닥에서도 물살을 일으킨다.', {F: 1, W: 1}),
        ('dd_ferry_3', '값 매기는 뱃사공', '거울 요괴', 'main', 'mirror', 'reflect', '빈 좌판마다 값을 매기던 뱃사공의 넋이다. 받은 만큼 꼭 되갚아야 직성이 풀린다.', {'waterlogged_plank': 2, W: 2, F: 1}),
        ('dd_ferry_4', '물굴 먹장어 떼', '수귀', 'main', 'water', 'tide', '우물 밑 물굴에서 기어 나온 먹장어 떼다. 몸을 감아 물굴 쪽으로 끌어당긴다.', {'burrow_scale': 1, W: 2, F: 1}),
        ('dd_ferry_5', '가라앉은 배의 선장', '지역 우두머리', 'guardian', 'giant', 'boss', '물이 마를 때 함께 가라앉은 배의 선장이다. 뱃판을 갑옷처럼 겹쳐 두르고 선단을 지킨다.', {'waterlogged_plank': 3, W: 3, C: 1}),
    ],
    'first_observatory': [
        ('dd_obs_1', '빈 별자리 나비', '천상 요괴', 'common', 'sky', 'aerial', '별이 사라진 하늘에서 별자리 모양으로 날아다니는 흰 나비다. 날갯짓마다 바랜 빛 부스러기가 떨어진다.', {'faded_star_glass': 1, W: 1}),
        ('dd_obs_2', '녹슨 혼천의 바퀴', '갑각 요괴', 'common', 'shell', 'armored', '혼천의에서 빠져나와 굴러다니는 녹슨 바퀴다. 녹이 껍질처럼 두꺼워 칼날이 미끄러진다.', {'faded_star_glass': 1, W: 1}),
        ('dd_obs_3', '잘못 읽힌 별귀', '천상 요괴', 'main', 'sky', 'aerial', '그날 밤 잘못 읽힌 별이 기록판에서 떨어져 나왔다. 하늘 높이 떠 있다가 빛줄기로 내리꽂힌다.', {'star_record_plate': 2, W: 2, F: 1}),
        ('dd_obs_4', '출입 장부 갈피귀', '매복 요괴', 'main', 'shadow', 'ambush', '출입 장부 갈피 사이에 숨어 사는 요괴다. 장부를 넘기는 손끝을 노려 갑자기 튀어나온다.', {'star_record_plate': 2, W: 2, F: 1}),
        ('dd_obs_5', '숨은 별을 찾는 눈', '지역 우두머리', 'guardian', 'sky', 'aerial', '관상대 맨 위 누대에 떠 있는 커다란 눈 하나다. 숨은 별을 찾느라 일흔 해 동안 한 번도 감지 않았다.', {'star_record_plate': 3, W: 3, C: 1}),
    ],
    'ash_palace': [
        ('dd_palace_1', '재 덮인 궁녀 넋', '원령', 'common', 'ghost', 'spectral', '재를 뒤집어쓴 채 빈 회랑을 오가는 궁녀의 넋이다. 아직도 누군가에게 등을 들고 가는 길이다.', {'king_ember_ash': 1, W: 1}),
        ('dd_palace_2', '빈 소매 망령', '매복 요괴', 'common', 'shadow', 'ambush', '팔 없는 빈 소매만 바람 없이 나부끼는 망령이다. 기둥 뒤에서 소매를 휘감아 목을 조인다.', {F: 1, W: 1}),
        ('dd_palace_3', '지워진 서명 먹귀', '결계 요괴', 'main', 'ward', 'warded', '서고 서류에서 지워진 서명이 먹귀가 되었다. 지워진 획을 금줄 삼아 몸에 두른다.', {'king_ember_ash': 2, W: 2, F: 1}),
        ('dd_palace_4', '잿불 도마뱀', '독충', 'main', 'venom', 'toxic', '불씨 항아리 놓던 자리의 잿불 속에서 자란 도마뱀이다. 뱉는 재에 독이 섞여 숨이 막힌다.', {'king_ember_ash': 2, W: 2, F: 1}),
        ('dd_palace_5', '빈 옥좌의 그림자', '지역 우두머리', 'guardian', 'giant', 'boss', '그림자 없는 땅에서 오직 빈 옥좌만 그림자를 드리운다. 그 그림자가 일어서 임금의 자리를 지킨다.', {'king_ember_ash': 3, W: 3, C: 1}),
    ],
    'pact_court': [
        ('dd_pact_1', '꺼진 자리 등롱', '원령', 'common', 'ghost', 'spectral', '맹약 마당 둘레에서 꺼진 채 서 있던 등롱 하나가 걸어 나왔다. 빈 등롱 안에서 이름 부르는 소리가 맴돈다.', {'pact_stone_dust': 1, W: 1}),
        ('dd_pact_2', '흰 밤 서리 떼', '무리 요괴', 'common', 'swarm', 'swarm', '흰 밤이 가장 짙은 곳에서 서리 알갱이가 떼를 지어 움직인다. 지나간 자리마다 색이 한 겹 더 바랜다.', {F: 2, W: 1}),
        ('dd_pact_3', '일곱 자리 파수', '갑각 요괴', 'main', 'shell', 'armored', '돌상의 일곱 홈을 하나씩 지키는 돌 파수꾼이다. 등에 새긴 맹약 글자가 껍질처럼 굳었다.', {'pact_stone_dust': 2, W: 2, F: 1}),
        ('dd_pact_4', '이름 빨아들이는 손', '파봉 요괴', 'main', 'breaker', 'seal_breaker', '먹 도랑에서 뻗어 나온 손이다. 움켜쥔 것의 이름을 빨아들이고, 쥘 때마다 봉인이 헐거워진다.', {'pact_stone_dust': 2, W: 2, F: 1}),
        ('dd_pact_5', '돌상 아래 흰 손', '지역 우두머리', 'guardian', 'giant', 'boss', '둥근 돌상 아래에서 올라오는 커다란 흰 손이다. 일곱 홈에 놓인 것을 하나도 내주지 않으려 한다.', {'pact_stone_dust': 3, W: 3, C: 1}),
    ],
    'jeongni_vault': [
        ('dd_vault_1', '먹 도랑 검은 손', '수귀', 'common', 'water', 'tide', '먹 도랑 물속에서 손목만 내민 검은 손이다. 발목을 잡아 도랑 쪽으로 끌어당긴다.', {'ledger_tab': 1, W: 1}),
        ('dd_vault_2', '모서리 접는 서리귀', '매복 요괴', 'common', 'shadow', 'ambush', '서류 모서리를 하나씩 접어 두던 서리의 넋이다. 접힌 모서리 그늘에 숨어 있다가 덮친다.', {'ledger_tab': 1, W: 1}),
        ('dd_vault_3', '가늠 저울추귀', '갑각 요괴', 'main', 'shell', 'armored', '이름의 무게를 재던 저울추가 스스로 굴러다닌다. 쇳덩이 몸이라 웬만한 칼날은 튕겨 낸다.', {'balance_weight': 2, W: 2, F: 1}),
        ('dd_vault_4', '수위 표석 먹귀', '원령', 'main', 'ghost', 'spectral', '봉연 수위 표석에 눈금마다 들러붙은 먹귀다. 수위가 오를 때마다 몸이 한 뼘씩 자란다.', {'ledger_tab': 2, W: 2, F: 1}),
        ('dd_vault_5', '금고 지기', '지역 우두머리', 'guardian', 'giant', 'boss', '정리소 금고 문 앞에 붙박인 거대한 지기다. 열쇠가 없는 이에게는 금고 문 대신 제 몸을 내민다.', {'balance_weight': 3, W: 3, C: 1}),
    ],
}

GROUNDS = {
    'dark_yamen': [('흰 기와 담장 길', '무너진 담장 사이로 흰 기와가 이어지는 관아 바깥 골목이다.'), ('관아 안채 뒤뜰', '느티나무가 선 안채 뒤뜰로, 서식 벽이 가까운 곳이다.'),
                   ('비스듬한 현판 아래', '현판 아래 문지기가 지키는 관아 한가운데다.')],
    'martial_row': [('서리 돌바닥 길', '녹지 않는 서리가 깔린 거리 바깥 길이다.'), ('멈춘 화살 연무 마당', '화살이 허공에 멈춘 연무 마당과 무기고 언저리다.'),
                    ('소등 종루 꼭대기', '소등 밤 종이 울렸던 종루 꼭대기다.')],
    'red_shrine_lane': [('거꾸로 건 등 골목', '거꾸로 건 등이 늘어선 골목 바깥이다.'), ('축문 벽 사당 안', '기름때 낀 축문으로 벽이 덮인 사당 안쪽이다.'),
                        ('첫 기름 곳간 앞', '해 지는 쪽 담장 너머, 첫 기름을 두었던 곳간 앞이다.')],
    'old_ferry_market': [('얹힌 배 저잣길', '마른 물길 위에 배들이 얹힌 저자 바깥 길이다.'), ('돛대 셋 우물가', '돛대 셋이 만나는 자리의 우물 둘레다.'),
                         ('물굴 돌 나루', '우물 밑 물굴을 지나 정리소 배가 대던 돌 나루다.')],
    'first_observatory': [('혼천의 마당 둘레', '녹슨 혼천의가 놓인 관상대 아래 마당이다.'), ('별 기록판 방 계단', '별 기록판 방으로 오르는 계단과 출입 장부 둘레다.'),
                          ('숨은 별 누대', '숨은 별을 찾는 눈이 떠 있는 맨 위 누대다.')],
    'ash_palace': [('바랜 기둥 회랑', '하얗게 바랜 기둥이 늘어선 궁 바깥 회랑이다.'), ('옥좌 뒤 재 정원', '재가 쌓인 옥좌 뒤 정원과 서고 언저리다.'),
                   ('빈 옥좌 돌 단', '임금의 등이 놓였던 둥근 자국이 남은 돌 단이다.')],
    'pact_court': [('꺼진 등롱 둘레', '꺼진 등롱 일곱이 원을 그린 마당 둘레다.'), ('먹 도랑 물가', '마당 가장자리를 감도는 먹 도랑 물가다.'),
                   ('일곱 홈 돌상', '일곱 홈이 원을 그린 둥근 돌상 한가운데다.')],
    'jeongni_vault': [('먹 도랑 첫 굽이길', '우물을 내려와 처음 만나는 먹 도랑 둑길이다.'), ('가늠 저울 서가', '가늠 저울과 정리 명부 서가가 늘어선 방들이다.'),
                      ('금고 앞 수문', '금고 지기가 지키는 정리소 맨 안쪽이다.')],
}

FISH = [
    ('deungdo_landing', 'canal', '남문 물길', '옛 남문으로 이어지는 수로입니다. 찌가 떨어지는 소리가 세 걸음 밖으로 나가지 않습니다.'),
    ('old_ferry_market', 'deep', '우물 밑 물굴', '돛대 셋이 만나는 자리의 우물 밑 물굴입니다. 줄을 내리면 손등이 서늘하게 바랩니다.'),
    ('hq_archive', 'deep', '서고 끝 우물', '장서각 지하서고 맨 끝 칸의 우물입니다. 물을 떠 보면 먹 냄새가 납니다.'),
]
SEA_FISH_REGIONS = []
CLIMATE = {'fog': 26, 'clear': 26, 'cloudy': 24, 'drizzle': 16, 'wind': 8}
CLIMATES = {'deungdo': CLIMATE, 'jeongni': {'cloudy': 40, 'fog': 35, 'drizzle': 25}}

PROFILES = {
    'deungdo_landing': ('물가·나루', '흑련 장부지기·수향 뱃사람', '남문 수로 선착의 말뚝: 거룻배마다 판자를 덧댄 자국이 남아 있다.', '남문 수로 선착 고유 사건: 수로 물에 닿은 손등이 잿빛으로 바랜다.', '흰 밤·비싼 물자', '돌계단, 거룻배, 야영소 천막'),
    'dark_yamen': ('관아·옛터', '부르다 굳은 넋들', '꺼진 관아 터의 현판: 「등도 관아, 도제조 백운서 쓰다」라는 글씨만 바래지 않았다.', '꺼진 관아 터 고유 사건: 안채 벽 서식의 미룸 칸이 하나도 채워지지 않았다.', '흰 밤·매복·무리', '흰 하늘, 쓰러진 대문, 이름 바랜 등롱'),
    'martial_row': ('거리·연무장', '북령 무관의 넋', '무관 거리의 목인: 가슴께에 새긴 이름이 모두 하얗게 바랬다.', '무관 거리 고유 사건: 허공에 멈춘 화살이 일흔 해째 과녁으로 날아가는 중이다.', '흰 밤·서리·되울림', '녹지 않는 서리, 멈춘 화살, 종루'),
    'red_shrine_lane': ('사당·골목', '적월 무리의 넋', '붉은 사당 골목의 축문 벽: 구절 하나만 거꾸로 적혀 있다.', '붉은 사당 골목 고유 사건: 첫 기름 곳간의 기름이 끊긴 날짜가 그날 밤과 같다.', '흰 밤·결계·독', '거꾸로 건 등, 기름때 낀 축문, 붉은 우물'),
    'old_ferry_market': ('물가·저자', '수향 무리의 넋', '옛 나루 저자의 장부 좌판: 값을 적은 칸 옆에 빈칸이 하나씩 남아 있다.', '옛 나루 저자 고유 사건: 우물의 물이 붙드는 손처럼 사람을 놓아주지 않는다.', '흰 밤·물살·되갚음', '마른 물길, 얹힌 배, 돛대 셋'),
    'lamp_rest': ('쉼막·등 가게', '수향 뱃사람·명등지기의 자취', '등지기 쉼막의 마루: 등을 고치던 연장 자국이 마루에 깊게 남았다.', '등지기 쉼막 고유 사건: 쉼막에 켜 둔 등 하나 둘레만 저녁 빛깔이 돈다.', '흰 밤·비싼 물자', '고친 처마, 등 하나, 뱃사람 거처'),
    'first_observatory': ('누대·관측', '잘못 읽힌 별의 넋', '첫 관상대의 별 기록판: 그날 밤 적은 별 하나가 지워져 있다.', '첫 관상대 고유 사건: 출입 장부의 마지막 줄에 이름 없는 관측관이 적혀 있다.', '흰 밤·하늘·매복', '녹슨 혼천의, 별 없는 흰 하늘, 기록판'),
    'ash_palace': ('궁궐·재', '남명 무리의 넋', '잿빛 왕궁 터의 돌 단: 임금의 등이 놓였던 둥근 자국이 남았다.', '잿빛 왕궁 터 고유 사건: 그림자 없는 땅에서 빈 옥좌만 그림자를 드리운다.', '흰 밤·결계·독', '바랜 기둥, 빈 옥좌, 재 덮인 정원'),
    'pact_court': ('마당·맹약', '맹약에 묶인 것들', '맹약 마당의 돌상: 일곱 홈 가운데 하나만 비어 있다.', '맹약 마당 고유 사건: 먹 도랑에 귀를 대면 정리된 이름들이 웅얼거린다.', '흰 밤·봉인·껍질', '둥근 돌상, 꺼진 등롱 일곱, 먹 도랑'),
    'jeongni_vault': ('지하·정리', '정리소의 넋', '정리소의 가늠 저울: 접시 한쪽이 늘 내려앉아 있다.', '정리소 고유 사건: 봉연 수위 표의 눈금이 해마다 한 칸씩 오른다.', '먹 도랑·껍질·매복', '먹 도랑, 가늠 저울, 봉연 수위 표'),
}
LORE = {
    'deungdo_landing': ['남문 수로 선착입니다. 옛 남문 물길이 닿는 돌계단 아래로 거룻배 몇 척이 말뚝에 매여 있습니다.',
                        '흑련 장부지기와 수향 뱃사람이 이곳에 임시 야영소를 차렸습니다. 수로 물에 손을 담그지 말라는 말이 천막마다 붙어 있습니다.'],
    'dark_yamen': ['꺼진 관아 터입니다. 하늘은 해도 달도 없이 동트기 직전처럼 희고, 발밑에는 그림자가 생기지 않습니다.',
                   '쓰러진 대문 위로 현판 하나만 비스듬히 매달려 있습니다. 안채 벽에는 백 년 전 서식과 셈표가 바래지 않은 채 남아 있습니다.'],
    'martial_row': ['무관 거리입니다. 돌바닥 틈마다 서리가 끼었는데, 공기는 차갑지 않은데도 서리가 녹지 않습니다.',
                    '연무 마당의 짚 목인 앞에 화살 몇 대가 허공에 멈춰 있습니다. 거리 끝 종루는 소등 밤 종을 울린 뒤로 한 번도 울리지 않았습니다.'],
    'red_shrine_lane': ['붉은 사당 골목입니다. 처마마다 등이 거꾸로 걸려 있고, 담장마다 기름 얼룩이 번져 있습니다.',
                        '사당 벽은 기름때 낀 축문으로 빈틈없이 덮였습니다. 해 지는 쪽 담장 너머에 첫 기름을 두었던 곳간이 있다고 합니다.'],
    'old_ferry_market': ['옛 나루 저자입니다. 물이 마른 물길 위에 배들이 얹혀 있고, 빈 좌판마다 값을 적은 나무패가 꽂혀 있습니다.',
                         '돛대 셋이 만나는 자리에 우물이 하나 있습니다. 수향 사람들은 그 물을 「붙드는 물」이라 부르며 가까이 가지 않습니다.'],
    'lamp_rest': ['등지기 쉼막입니다. 명등지기가 등을 고치던 쉼막 터에 수향 뱃사람들이 처마를 고쳐 거처를 차렸습니다.',
                  '쉼막 한가운데에 등 하나가 늘 켜져 있습니다. 그 등 둘레에서만 하늘이 저녁 빛깔로 물듭니다.'],
    'first_observatory': ['첫 관상대입니다. 녹슨 혼천의가 마당에 놓여 있고, 계단 위로 별 기록판 방이 있습니다.',
                          '흰 하늘에는 별이 하나도 없습니다. 기록판에 적힌 별 가운데 하나는 누군가 일부러 지운 듯 긁혀 있습니다.'],
    'ash_palace': ['잿빛 왕궁 터입니다. 하얗게 바랜 궁궐 기둥이 늘어섰고, 계단마다 재가 고르게 덮여 있습니다.',
                   '돌 단 위에 빈 옥좌가 놓여 있습니다. 그 앞 바닥에는 임금의 등이 놓였던 둥근 자국이 선명합니다.'],
    'pact_court': ['맹약 마당입니다. 흰 밤이 가장 짙어 손끝조차 흐리게 보입니다.',
                   '일곱 홈이 원을 그린 둥근 돌상 둘레로 꺼진 등롱 일곱이 서 있습니다. 마당 가장자리를 감도는 먹 도랑에서 웅얼거리는 소리가 올라옵니다.'],
    'jeongni_vault': ['정리소입니다. 장서각 지하서고 맨 끝 우물을 내려오면 먹 도랑이 흐르는 돌방들이 이어집니다.',
                      '가늠 저울과 봉연 수위 표가 줄지어 서 있습니다. 맨 안쪽 금고 문 앞을 무언가 커다란 것이 지키고 있습니다.'],
}

SITES = {
    'dark_yamen': [('relic', '꺼진 관아 터 · 맨 안쪽 방 서식', ['seal_paper', 'century_form_scrap', 'bleached_lantern_paper', 'ward_fragment'], ['century_form_scrap', W, C]),
                   ('supply', '꺼진 관아 터 · 안마당 불 자리', ['herb', 'travel_ration', 'tonic', 'bleached_lantern_paper'], ['bleached_lantern_paper', F, W]),
                   ('medical', '꺼진 관아 터 · 관아 약방 궤', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', F, 'night_tea'])],
    'martial_row': [('relic', '무관 거리 · 종루 꼭대기', ['seal_paper', 'frost_bell_iron', 'ward_fragment', F], ['frost_bell_iron', W, C]),
                    ('supply', '무관 거리 · 닫힌 무기고', ['herb', 'travel_ration', 'frozen_arrow_shaft', 'frost_bell_iron'], ['frozen_arrow_shaft', W, F]),
                    ('medical', '무관 거리 · 무관 숙소 약궤', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', F, 'ember_ash_pill'])],
    'red_shrine_lane': [('relic', '붉은 사당 골목 · 돌 궤짝 제단', ['seal_paper', 'red_shrine_lacquer', 'ward_fragment', 'ghost_ash'], ['red_shrine_lacquer', W, C]),
                        ('supply', '붉은 사당 골목 · 기름 곳간 문', ['herb', 'travel_ration', 'severed_lamp_oil', 'resin'], ['severed_lamp_oil', W, F]),
                        ('medical', '붉은 사당 골목 · 무녀 거처 약단지', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', 'night_tea', F])],
    'old_ferry_market': [('relic', '옛 나루 저자 · 청씨 선단 선실', ['seal_paper', 'waterlogged_plank', 'ward_fragment', F], ['waterlogged_plank', W, C]),
                         ('supply', '옛 나루 저자 · 값 적은 장부 좌판', ['herb', 'travel_ration', 'tonic', 'waterlogged_plank'], ['waterlogged_plank', 'burrow_scale', W]),
                         ('medical', '옛 나루 저자 · 뱃사람 약 궤짝', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', F, 'revival_charm'])],
    'first_observatory': [('relic', '첫 관상대 · 별 기록판 방', ['seal_paper', 'star_record_plate', 'faded_star_glass', 'star_sand'], ['star_record_plate', W, C]),
                          ('supply', '첫 관상대 · 출입 장부 책상', ['herb', 'travel_ration', 'faded_star_glass', 'star_sand'], ['faded_star_glass', W, F]),
                          ('medical', '첫 관상대 · 관측관 숙소 약상자', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', 'night_tea', F])],
    'ash_palace': [('relic', '잿빛 왕궁 터 · 옥좌 앞 등 자리', ['seal_paper', 'king_ember_ash', 'ward_fragment', 'ghost_ash'], ['king_ember_ash', W, C]),
                   ('supply', '잿빛 왕궁 터 · 불씨 항아리 놓던 자리', ['herb', 'travel_ration', 'king_ember_ash', 'tonic'], ['king_ember_ash', W, F]),
                   ('medical', '잿빛 왕궁 터 · 궁녀 처소 약장', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', 'ember_ash_pill', F])],
    'pact_court': [('abyss', '맹약 마당 · 먹 도랑 물머리', ['pact_stone_dust', F, 'ward_fragment', 'spirit_dust'], ['pact_stone_dust', W, C]),
                   ('relic', '맹약 마당 · 둥근 돌상', ['seal_paper', 'pact_stone_dust', 'ward_fragment', 'ghost_ash'], [C, W, 'pact_stone_dust']),
                   ('medical', '맹약 마당 · 꺼진 등롱 아래 약 꾸러미', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', 'revival_charm', F])],
    'jeongni_vault': [('relic', '정리소 · 가늠 저울', ['seal_paper', 'balance_weight', 'ledger_tab', 'ward_fragment'], ['balance_weight', W, C]),
                      ('supply', '정리소 · 봉연 수위 표', ['herb', 'travel_ration', 'ledger_tab', 'ore'], ['ledger_tab', W, F]),
                      ('medical', '정리소 · 정리관 약장', ['herb', 'medicine_base', 'tonic', 'herbal_extract'], ['herbal_extract', 'ember_ash_pill', 'revival_charm'])],
}

ITEMS = [
    ('lamp_wick_core', '명등 심지', 'material', 5, 40, 480, True, 45, '꺼진 등롱에서 거둔 심지 한 가닥이다. 불을 붙이지 않아도 손끝이 따뜻하다. 8단계 장비와 도구의 심이 된다.'),
    ('white_night_frost', '흰 밤 서리', 'material', 4, 40, 320, True, 45, '흰 밤의 땅에서 녹지 않는 서리 알갱이다. 손바닥에 올려도 차갑기만 하고 녹지 않는다.'),
    ('bleached_lantern_paper', '바랜 등롱 종이', 'material', 4, 40, 380, True, 45, '이름 적은 종이가 붙어 있던 등롱 종이다. 글자는 하얗게 바랬지만 결은 질기다.'),
    ('century_form_scrap', '백 년 서식 조각', 'material', 4, 40, 420, True, 45, '관아 안채 벽에서 떼어 낸 백 년 전 서식 조각이다. 미룸 칸에 찍힌 인장이 아직 붉다.'),
    ('frozen_arrow_shaft', '멈춘 화살대', 'material', 4, 40, 400, True, 45, '허공에 멈췄던 화살에서 거둔 화살대다. 날아가던 기세가 결 속에 그대로 남아 있다.'),
    ('frost_bell_iron', '언 종루 쇠', 'material', 5, 40, 460, True, 45, '소등 밤 종을 울린 종루에서 떼어 낸 쇠다. 두드리면 서리가 부서지는 소리가 난다.'),
    ('severed_lamp_oil', '끊긴 등 기름', 'material', 4, 40, 380, True, 45, '첫 기름 곳간에서 끊긴 채 굳어 있던 등 기름이다. 데우면 다시 맑게 풀린다.'),
    ('red_shrine_lacquer', '붉은 사당 옻', 'material', 4, 40, 420, True, 45, '붉은 사당 기둥에서 긁어낸 옻이다. 칠하면 색이 바래지 않는다.'),
    ('waterlogged_plank', '물 먹은 뱃판', 'material', 4, 40, 400, True, 45, '마른 물길에 얹힌 배에서 뜯은 뱃판이다. 물이 마른 지 일흔 해인데도 속은 젖어 있다.'),
    ('faded_star_glass', '바랜 별유리', 'material', 5, 40, 460, True, 45, '혼천의에 박혀 있던 별유리다. 빛은 바랬지만 들여다보면 별이 있던 자리가 비친다.'),
    ('star_record_plate', '별 기록 동판', 'material', 5, 40, 480, True, 45, '첫 관상대 기록판에서 떨어져 나온 동판이다. 그날 밤 읽은 별의 이름이 새겨져 있다.'),
    ('king_ember_ash', '임금 불씨 재', 'material', 5, 40, 480, True, 45, '임금의 등이 놓였던 자리에 쌓인 재다. 쥐고 있으면 손바닥이 은근히 데워진다.'),
    ('pact_stone_dust', '맹약 돌가루', 'material', 5, 40, 520, True, 45, '맹약 마당 돌상 둘레에서 긁어 모은 돌가루다. 8단계 장비 가운데 가장 무거운 것들에 들어간다.'),
    ('balance_weight', '가늠 저울추', 'material', 5, 40, 500, True, 45, '정리소에서 이름의 무게를 재던 저울추다. 크기에 비해 지나치게 무겁다.'),
    ('ledger_tab', '정리 명부 갈피', 'material', 4, 40, 360, True, 45, '정리 명부 사이에 끼워 둔 갈피다. 갈피마다 정리된 이름의 첫 글자가 적혀 있다.'),
    ('burrow_scale', '물굴 비늘', 'material', 3, 40, 150, True, 45, '물굴 먹장어에서 벗긴 비늘이다. 질기고 물에 젖지 않아 낚싯대와 신에 쓴다.'),
    ('myeongdeung_lamp', '명등 등롱', 'consumable', 4, 20, 900, True, 45, '바랜 등롱 종이에 명등 심지를 넣고 끊긴 등 기름을 부은 등롱이다. 켜 두면 1시간 동안 백야가 미치지 않는다.'),
    ('night_tea', '밤빛 차', 'consumable', 3, 20, 300, True, 45, '끊긴 등 기름에 약초를 덖어 우린 차다. 정신을 채우고 1시간 동안 마음이 덜 흔들린다.'),
    ('ember_ash_pill', '불씨 재 환', 'consumable', 4, 20, 360, True, 45, '임금 불씨 재를 약제 바탕에 섞어 빚은 환약이다. 침식을 덜고 체력을 채운다.'),
]

STATUSES = [
    ('beneath_lamp', '등불 아래', 'positive', 60, {}, 'flame', '명등 등롱 불빛 아래에 있습니다. 등도의 백야가 미치지 않습니다.'),
    ('night_breath', '밤 숨', 'positive', 60, {'mental_loss_pct': -15}, 'leaf', '밤빛 차 기운이 숨을 고르게 해 마음이 덜 흔들립니다.'),
    ('faded_name', '바랜 이름', 'negative', 60, {'combat_damage_pct': -10}, 'spark', '제 이름을 홀로 외어 일어났습니다. 이름이 잠시 바래 주는 피해가 줄어듭니다.'),
    ('undying_glow', '꺼지지 않는 등빛', 'positive', 180, {'mental_loss_pct': -10}, 'flame', '등어 기름 불빛이 곁을 지킵니다. 백야의 기본 효과가 미치지 않고 마음이 덜 흔들립니다.'),
    ('calling_night', '함께 부르는 밤', 'positive', 120, {'combat_damage_pct': 5, 'mental_loss_pct': -15}, 'spark', '같은 지역에 파티원이 있으면 서로를 부르는 소리가 닿아 주는 피해가 늘고 마음이 덜 흔들립니다.'),
]
PARTY_STATUSES = {'calling_night'}

FISH_SPECIES = [
    ('snow_minnow', '흰눈 송사리', 'canal', 'common', None, None, 30, 3, 7, '흰 밤의 물길에서 눈송이처럼 하얗게 떼 지어 다니는 송사리다.', 8),
    ('lantern_smelt', '등불 빙어', 'canal', 'uncommon', 'dusk', None, 30, 8, 16, '몸속이 등불처럼 비치는 빙어다. 땅거미가 지면 물길 위로 떠오른다.', 30),
    ('burrow_hagfish', '물굴 먹장어', 'deep', 'rare', 'night', None, 32, 50, 110, '우물 밑 물굴 바닥에 숨어 사는 먹장어다. 삼경에만 굴 밖으로 몸을 내민다.', 95),
    ('cheong_carp', '청씨 잉어', 'deep', 'uncommon', None, None, 30, 30, 70, '청씨 선단 뱃사람들이 우물에 놓아 길렀다는 잉어의 후손이다. 비늘이 푸른빛을 띤다.', 32),
]
NAMED_FISH = [
    ('undying_lampfish', '꺼지지 않는 등어', 'canal', 'dusk', 'fog', 'deungdo_landing', 40, 90, '배 속에 꺼지지 않는 불씨를 품은 물고기다. 안개 낀 땅거미에 물길 물고기 냄새를 따라 올라온다더라.',
     ['snow_minnow', 'lantern_smelt', 'stone_goby', 'sluice_carp']),
    ('burrow_goldcarp', '물굴 금잉어', 'deep', 'night', 'cloudy', 'old_ferry_market', 70, 150, '물굴 가장 깊은 곳에 산다는 금빛 잉어다. 구름 낀 삼경에 깊은 물고기 냄새가 내려가면 올라온다더라.',
     ['cheong_carp', 'well_blindfish', 'bronze_catfish']),
]
NAMED_PRICE = 1600
NAMED_LEVEL = 45
NAMED_TRADEABLE = True

COOK = 'cooking'
FISH_GOODS = [
    ('minnow_fritter', '송사리 튀김', 'consumable', 2, 40, True, 40, {'hp': 30, 'buffs': ['well_fed']}, '흰눈 송사리를 통째로 튀겼다. 체력을 조금 채운다.', 'cooking', {'snow_minnow': 3, 'herb': 1}, 2, 45),
    ('smelt_clear_soup', '빙어 맑은국', 'consumable', 2, 40, True, 80, {'mn': 30, 'buffs': ['warm_belly']}, '등불 빙어를 맑게 끓였다. 정신을 채우고 속이 따뜻해진다.', 'cooking', {'lantern_smelt': 2, 'river_reed': 1}, 2, 45),
    ('burrow_scale', None, None, None, None, None, None, None, None, 'leatherwork', {'burrow_hagfish': 1, 'charcoal': 1}, 2, 46),
    ('cheong_carp_steam', '청씨 잉어찜', 'consumable', 3, 20, True, 220, {'hp': 45, 'mn': 15, 'buffs': ['vigor']}, '청씨 잉어를 약초와 함께 쪘다. 체력과 정신을 함께 채운다.', 'cooking', {'cheong_carp': 1, 'herb': 2, 'plank_water_jar': 1}, 2, 46),
]
NAMED_GOODS = [
    ('lampfish_oil_lamp', '등어 기름 명등', 'consumable', 5, 20, True, 1600, {'buffs': ['undying_glow']}, '꺼지지 않는 등어의 기름을 부은 등이다. 3시간 동안 백야의 기본 효과가 미치지 않고 마음이 덜 흔들린다.', 'artifice', {'undying_lampfish': 1, 'severed_lamp_oil': 1}, 2, 48),
    ('goldcarp_feast', '금잉어 찜 한 상', 'consumable', 5, 20, True, 1600, {'hp': 80, 'mn': 30, 'buffs': ['calling_night']}, '물굴 금잉어를 쪄 차린 한 상이다. 2시간 동안 같은 지역에 파티원이 있으면 주는 피해가 늘고 마음이 덜 흔들린다.', 'cooking', {'burrow_goldcarp': 1, 'herb': 2}, 2, 48),
]
CONSUMABLE_RECIPES = [
    ('myeongdeung_lamp', {'bleached_lantern_paper': 2, 'severed_lamp_oil': 1, W: 1}, 'sealing', 2),
    ('night_tea', {'severed_lamp_oil': 1, 'herb': 2}, 'alchemy', 2),
    ('ember_ash_pill', {'king_ember_ash': 1, 'medicine_base': 1}, 'alchemy', 2),
]
CONSUMABLE_FX = {
    'myeongdeung_lamp': {'buffs': ['beneath_lamp']},
    'night_tea': {'mn': 30, 'buffs': ['night_breath']},
    'ember_ash_pill': {'er': 30, 'hp': 30},
}
EXTRA_RECIPES = []
FILLET_QTY = {'common': 2, 'uncommon': 3, 'rare': 4}

TOOLS = [
    ('lt_knife_9', '뱃판 자루 채집도', 'knife', {'trait': '정밀 채집', 'req_line': 'gathering_rank', 'req_rank': 20, 'rare_loot_pct': 11, 'gathering_bonus_pct': 38},
     '물 먹은 뱃판 자루에 언 종루 쇠 날을 박은 채집도다. 장착하면 채집량이 38%, 희귀품이 11% 는다.', 'smithing', {'waterlogged_plank': 3, 'frost_bell_iron': 2, W: 1}),
    ('lt_pick_8', '저울추 곡괭이', 'pick', {'trait': '정밀 채집', 'req_line': 'gathering_rank', 'req_rank': 17, 'rare_loot_pct': 10, 'gathering_bonus_pct': 36},
     '가늠 저울추를 머리로 단 곡괭이다. 광맥·유물 채집량이 는다.', 'smithing', {'balance_weight': 3, 'frost_bell_iron': 2, W: 1}),
    ('lt_sickle_8', '서리 날 낫', 'sickle', {'trait': '정밀 채집', 'sig_pct': 11, 'req_line': 'gathering_rank', 'req_rank': 18, 'sig_where': 'herb', 'gathering_bonus_pct': 31},
     '흰 밤 서리로 날을 식힌 낫이다. 채집량이 31% 늘고, 약초·영기 채집터에서 11% 확률로 그 지역의 희귀품을 함께 거둔다.', 'smithing', {F: 3, 'frost_bell_iron': 2, W: 1}),
    ('lt_lantern_8', '명등 손등', 'lantern', {'trait': '정밀 채집', 'sig_pct': 13, 'req_line': 'gathering_rank', 'req_rank': 19, 'sig_where': 'dark', 'gathering_bonus_pct': 29},
     '명등 심지에 끊긴 등 기름을 부은 손등이다. 채집량이 29% 늘고, 유물 채집터나 어두운 지역에서 13% 확률로 그 지역의 희귀품을 함께 거둔다.', 'artifice', {W: 2, 'severed_lamp_oil': 3, 'faded_star_glass': 1}),
    ('lt_compass_8', '별 기록 나침반', 'explore', {'trait': '탐사', 'req_line': 'investigation_rank', 'req_rank': 40, 'life_slot': 'explore', 'clue_bonus_pct': 10, 'search_find_pct': 52},
     '별 기록 동판 위에 바랜 별유리 바늘을 띄운 나침반이다. 탐색에서 길·채집터를 더 잘 찾는다.', 'artifice', {'faded_star_glass': 2, 'star_record_plate': 2, W: 1}),
    ('lt_rod_8', '물굴 낚싯대', 'rod', {'trait': '낚시', 'life_slot': 'fishing', 'fish_bite_pct': 23, 'fish_rare_pct': 18, 'fish_size_pct': 12},
     '물 먹은 뱃판 대에 물굴 비늘을 감아 마디를 이은 낚싯대다.', 'carpentry', {'waterlogged_plank': 3, 'burrow_scale': 2, W: 1}),
    ('lt_hammer_8', '종루 쇠 망치', 'hammer', {'trait': '제작 공구', 'req_line': 'crafting_rank', 'req_rank': 12, 'life_slot': 'craft', 'craft_fields': ['smithing', 'carpentry', 'artifice'], 'craft_quality': 13},
     '단조·목공·법구 공예 제작 공구다. 제작 숙련 12단계부터 가방에 넣어 두면 그 분야 제작 품질이 13 오른다.', 'smithing', {'frost_bell_iron': 3, W: 1}),
    ('lt_needle_8', '등롱 실 바늘', 'needle', {'trait': '제작 공구', 'req_line': 'crafting_rank', 'req_rank': 12, 'life_slot': 'craft', 'craft_fields': ['weaving', 'leatherwork'], 'craft_quality': 13},
     '직조·가죽 공예 제작 공구다. 제작 숙련 12단계부터 가방에 넣어 두면 그 분야 제작 품질이 13 오른다.', 'leatherwork', {'bleached_lantern_paper': 2, W: 2}),
    ('lt_carve_8', '서식 각인도', 'carve', {'trait': '제작 공구', 'req_line': 'crafting_rank', 'req_rank': 12, 'life_slot': 'craft', 'craft_fields': ['sealing'], 'craft_quality': 13},
     '봉인 공예 제작 공구다. 제작 숙련 12단계부터 가방에 넣어 두면 봉인 공예 품질이 13 오른다. 각인 공구가 필요한 제작법에도 쓴다.', 'smithing', {'century_form_scrap': 2, 'frost_bell_iron': 1, W: 1}),
    ('lt_still_8', '등 기름 증류기', 'still', {'trait': '제작 공구', 'req_line': 'crafting_rank', 'req_rank': 12, 'life_slot': 'craft', 'craft_fields': ['alchemy'], 'craft_quality': 13},
     '연금 제작 공구다. 제작 숙련 12단계부터 가방에 넣어 두면 연금 제작 품질이 13 오른다.', 'artifice', {'severed_lamp_oil': 3, 'faded_star_glass': 1, W: 1}),
    ('lt_cook_8', '선착 식칼', 'cook', {'trait': '제작 공구', 'req_line': 'crafting_rank', 'req_rank': 1, 'life_slot': 'craft', 'craft_fields': ['cooking'], 'craft_quality': 13},
     '요리 공구다. 가방에 넣어 두면 요리 품질이 13 오른다.', 'smithing', {'frost_bell_iron': 2, 'waterlogged_plank': 1}),
]
UNTRADEABLE_TOOLS = set()

B = 'frost_bell_iron'
A = 'frozen_arrow_shaft'
P = 'bleached_lantern_paper'
S = 'century_form_scrap'
O = 'severed_lamp_oil'
Q = 'red_shrine_lacquer'
K = 'waterlogged_plank'
G = 'faded_star_glass'
R = 'star_record_plate'
E = 'king_ember_ash'
D = 'pact_stone_dust'
T = 'balance_weight'
LG = 'ledger_tab'
GEAR = [
    ('w_melee8_base', '언 종루 환도', 'weapon', 'strength', {'power': 66, 'trait': '근접', 'weapon_type': 'melee', 'combat_damage_pct': 24}, '언 종루 쇠를 두드려 벼린 환도다. 고르게 강하다.', 'smithing', {B: 6, W: 3, F: 3, S: 2}),
    ('w_melee8_heavy', '맹약 주춧돌 철퇴', 'weapon', 'strength', {'power': 77, 'trait': '근접', 'presence': 46, 'weapon_type': 'melee'}, '맹약 마당 주춧돌을 깎아 단 철퇴다. 위력이 높지만 노려지기 쉽다.', 'smithing', {B: 5, D: 3, T: 2, W: 3}),
    ('w_melee8_keen', '서식 긋는 검', 'weapon', 'strength', {'power': 60, 'trait': '근접', 'crit_pct': 24, 'weapon_type': 'melee'}, '날이 서식의 칸 금처럼 곧다. 치명타가 잘 터진다.', 'smithing', {B: 5, S: 4, W: 3, F: 2}),
    ('w_melee8_silent', '그림자 없는 단검', 'weapon', 'strength', {'power': 62, 'trait': '근접', 'presence': -46, 'evasion_pct': 12, 'weapon_type': 'melee'}, '흰 밤 서리로 날을 식힌 단검이다. 그림자처럼 소리가 없다.', 'smithing', {B: 5, F: 5, W: 3, Q: 2}),
    ('w_ranged8_base', '멈춘 화살 각궁', 'weapon', 'agility', {'ammo': 'ammo_arrow', 'power': 66, 'trait': '원거리', 'weapon_type': 'ranged', 'combat_damage_pct': 24}, '멈춘 화살대를 덧대어 짠 각궁이다. 고르게 강하다.', 'carpentry', {A: 7, K: 3, W: 3, F: 2}),
    ('w_ranged8_heavy', '종루 들보 쇠뇌', 'weapon', 'agility', {'ammo': 'ammo_bolt', 'power': 77, 'trait': '원거리', 'presence': 46, 'weapon_type': 'ranged'}, '종루 들보로 짠 쇠뇌다. 위력이 높지만 노려지기 쉽다.', 'carpentry', {A: 4, B: 3, D: 2, K: 2, W: 3}),
    ('w_ranged8_keen', '별 쏘는 신궁', 'weapon', 'agility', {'ammo': 'ammo_arrow', 'power': 60, 'trait': '원거리', 'crit_pct': 24, 'weapon_type': 'ranged'}, '바랜 별유리로 겨냥 구멍을 낸 활이다. 치명타가 잘 터진다.', 'carpentry', {A: 5, G: 4, W: 3, F: 2}),
    ('w_ranged8_silent', '등롱 대 취관', 'weapon', 'agility', {'ammo': 'ammo_dart', 'power': 62, 'trait': '원거리', 'presence': -46, 'evasion_pct': 12, 'weapon_type': 'ranged'}, '등롱 대를 깎아 만든 취관이다. 소리 없이 쏜다.', 'carpentry', {A: 5, P: 5, W: 3, F: 2}),
    ('w_magic8_base', '일곱 자리 법륜', 'weapon', 'spirit_affinity', {'power': 66, 'trait': '술법', 'weapon_type': 'magic', 'combat_damage_pct': 24}, '백 년 서식 조각을 둥글게 엮은 법륜이다. 고르게 강하다.', 'artifice', {S: 5, R: 3, W: 3, F: 3}),
    ('w_magic8_heavy', '첫 관상대 혼천 방울', 'weapon', 'spirit_affinity', {'power': 77, 'trait': '술법', 'presence': 46, 'weapon_type': 'magic'}, '혼천의 고리를 본떠 만든 큰 방울이다. 위력이 높지만 노려지기 쉽다.', 'artifice', {R: 5, D: 3, W: 3, F: 2}),
    ('w_magic8_keen', '임금 불씨 부채', 'weapon', 'spirit_affinity', {'power': 60, 'trait': '술법', 'crit_pct': 24, 'weapon_type': 'magic'}, '임금 불씨 재를 바랜 등롱 종이에 먹인 부채다. 치명타가 잘 터진다.', 'artifice', {E: 5, P: 3, W: 3, F: 3}),
    ('w_magic8_silent', '꺼진 자리 법등', 'weapon', 'spirit_affinity', {'power': 62, 'trait': '술법', 'presence': -46, 'evasion_pct': 12, 'weapon_type': 'magic'}, '맹약 마당 꺼진 자리의 등롱을 본뜬 법등이다. 요괴의 눈에 덜 띈다.', 'artifice', {O: 6, F: 4, W: 3, Q: 2}),
    ('a8_iron', '언 종루 비늘갑', 'armor', 'vitality', {'trait': '방호', 'defense': 60, 'presence': 60, 'evasion_pct': -7}, '언 종루 쇠 비늘을 겹쳐 엮은 갑옷이다. 단단하지만 요괴의 이목을 끈다.', 'smithing', {B: 5, D: 3, W: 3, F: 2}),
    ('a8_brig', '맹약 돌비늘 두정갑', 'armor', 'vitality', {'trait': '방호', 'defense': 57, 'presence': 48, 'damage_reduction_pct': 6, 'evasion_pct': -5}, '붉은 사당 옻을 먹인 가죽 안에 맹약 돌가루로 구운 비늘을 박은 두정갑이다. 받는 피해를 덜어 준다.', 'leatherwork', {Q: 4, D: 3, W: 3, F: 3}),
    ('a8_light', '뱃판 누빔 경갑', 'armor', 'agility', {'trait': '방호', 'defense': 36, 'evasion_pct': 12}, '물 먹은 뱃판 조각을 누벼 넣은 가벼운 갑옷이다. 몸을 틀어 피하기 좋다.', 'leatherwork', {K: 5, Q: 3, W: 3, F: 2}),
    ('a8_shade', '흰 밤 야행의', 'armor', 'agility', {'trait': '방호', 'defense': 26, 'crit_pct': 8, 'presence': -60, 'evasion_pct': 8}, '흰 밤 서리빛으로 짠 옷이다. 요괴의 눈을 피하고 빈틈을 노린다.', 'weaving', {F: 6, Q: 3, W: 3, P: 2}),
    ('a8_robe', '명등지기 법의', 'armor', 'willpower', {'trait': '방호', 'defense': 30, 'erosion_pct': -24, 'damage_reduction_pct': 15}, '바랜 등롱 종이 결을 살려 짠 법의다. 받는 피해를 덜고 요기를 막는다.', 'weaving', {P: 5, E: 3, W: 3, F: 2}),
    ('a8_star', '별자리 학창의', 'armor', 'willpower', {'trait': '방호', 'defense': 32, 'mental_loss_pct': -24, 'damage_reduction_pct': 13}, '별 기록 동판 조각을 깃에 단 학창의다. 받는 피해를 덜고 마음이 덜 흔들린다.', 'artifice', {R: 4, S: 3, G: 1, W: 3, F: 1}),
    ('h8_calm', '명등지기 관', 'hat', 'willpower', {'trait': '관모', 'erosion_pct': -30, 'mental_loss_pct': -45}, '명등지기가 쓰던 관이다. 요기와 두려움을 막는다.', 'weaving', {P: 3, E: 2, W: 2}),
    ('h8_guard', '저울추 투구', 'hat', 'vitality', {'trait': '관모', 'defense': 16, 'presence': 40}, '가늠 저울추를 녹여 부은 투구다. 앞장서는 이에게 어울린다.', 'smithing', {T: 3, B: 1, W: 2}),
    ('h8_wise', '별 읽는 사모', 'hat', 'perception', {'trait': '관모', 'crit_pct': 8, 'clue_bonus_pct': 30}, '관측관이 쓰던 사모다. 단서가 잘 보이고 급소를 읽는다.', 'weaving', {R: 3, P: 2, W: 2}),
    ('s8_road', '남문 짚신', 'shoes', 'vitality', {'trait': '신', 'travel_time_pct': -30}, '남문 뱃사람이 삼은 짚신이다. 먼 길을 덜 지치게 걷는다.', 'leatherwork', {K: 3, F: 2, W: 2}),
    ('s8_sturdy', '종루 쇠 장화', 'shoes', 'vitality', {'trait': '신', 'defense': 12, 'presence': 30}, '언 종루 쇠 징을 박은 장화다. 땅을 굳게 딛는다.', 'leatherwork', {B: 3, Q: 1, W: 2}),
    ('s8_swift', '서리 비단신', 'shoes', 'agility', {'trait': '신', 'flee_pct': 24, 'evasion_pct': 12}, '흰 밤 서리빛 비단으로 지은 신이다. 피하고 달아나기 좋다.', 'leatherwork', {F: 3, Q: 2, W: 2}),
    ('n8_keen', '멈춘 화살촉 노리개', 'norigae', 'perception', {'trait': '노리개', 'crit_pct': 15}, '멈춘 화살의 촉을 단 노리개다. 급소를 노리는 눈이 밝아진다.', 'weaving', {A: 3, R: 2, W: 2}),
    ('n8_luck', '별 하나 노리개', 'norigae', 'spirit_affinity', {'trait': '노리개', 'rare_loot_pct': 24}, '바랜 별유리 한 알을 꿴 노리개다. 귀한 전리품이 잘 나온다.', 'weaving', {G: 3, R: 1, W: 2}),
    ('n8_plenty', '남문 뱃사람 노리개', 'norigae', 'vitality', {'trait': '노리개', 'craft_quality': 8, 'gather_qty_pct': 24}, '남문 뱃사람들이 엮는 노리개다. 거두는 양과 솜씨가 는다.', 'weaving', {K: 3, F: 3, W: 2}),
    ('m8_purify', '등 기름 향낭', 'amulet', 'willpower', {'trait': '호신부', 'erosion_pct': -24, 'healing_pct': 24}, '끊긴 등 기름을 적신 향낭이다. 침식이 덜하고 회복이 잘 된다.', 'sealing', {O: 3, E: 2, W: 2}),
    ('m8_spell', '첫 부름이 부적낭', 'amulet', 'spirit_affinity', {'trait': '호신부', 'magic_pct': 24}, '처음 이름을 불러 준 이의 부적을 품는 부적낭이다. 술법이 세진다.', 'sealing', {E: 2, S: 2, W: 2}),
    ('m8_ward', '일곱 자리 호패', 'amulet', 'willpower', {'trait': '호신부', 'presence': 30, 'incoming_damage_pct': -15}, '돌상의 일곱 홈을 본뜬 호패다. 받는 피해가 줄고 요괴가 먼저 노린다.', 'sealing', {D: 2, LG: 2, W: 2}),
    ('k8_awe', '빈 옥좌 탈', 'mask', 'strength', {'trait': '탈', 'presence': 75, 'combat_damage_pct': 12}, '빈 옥좌 그림자의 얼굴을 본뜬 탈이다. 요괴가 먼저 덤비지만 기세가 오른다.', 'sealing', {E: 2, T: 2, W: 2}),
    ('k8_ghost', '부르다 굳은 탈', 'mask', 'spirit_affinity', {'trait': '탈', 'encounter_pct': 24, 'rare_loot_pct': 15}, '부르다 굳은 넋의 얼굴을 본뜬 탈이다. 요괴를 불러들이고 귀한 것을 끌어낸다.', 'sealing', {Q: 2, F: 3, W: 2}),
    ('k8_hide', '그림자 없는 탈', 'mask', 'agility', {'trait': '탈', 'presence': -75, 'encounter_pct': -24}, '얼굴 자리가 하얗게 바랜 탈이다. 요괴의 눈에 덜 띄고 덜 마주친다.', 'sealing', {F: 3, P: 2, W: 2}),
]
GEAR_DROP = {
    'w_melee8_base': ['armored', 'swarm', 'boss'], 'w_melee8_heavy': ['armored', 'swarm', 'boss'], 'w_melee8_keen': ['armored', 'swarm', 'boss'], 'w_melee8_silent': ['armored', 'swarm', 'boss'],
    'w_ranged8_base': ['aerial', 'ambush', 'boss'], 'w_ranged8_heavy': ['aerial', 'ambush', 'boss'], 'w_ranged8_keen': ['aerial', 'ambush', 'boss'], 'w_ranged8_silent': ['aerial', 'ambush', 'boss'],
    'w_magic8_base': ['spectral', 'warded', 'seal_breaker', 'boss'], 'w_magic8_heavy': ['spectral', 'warded', 'seal_breaker', 'boss'], 'w_magic8_keen': ['spectral', 'warded', 'seal_breaker', 'boss'], 'w_magic8_silent': ['spectral', 'warded', 'seal_breaker', 'boss'],
    'a8_iron': ['armored', 'boss'], 'a8_brig': ['seal_breaker', 'boss'], 'a8_light': ['aerial', 'swarm', 'boss'], 'a8_shade': ['ambush', 'boss'],
    'a8_robe': ['spectral', 'warded', 'boss'], 'a8_star': ['reflect', 'boss'],
    'h8_calm': ['spectral', 'seal_breaker', 'boss'], 'h8_guard': ['armored', 'boss'], 'h8_wise': ['warded', 'reflect', 'boss'],
    's8_road': ['swarm', 'tide', 'boss'], 's8_sturdy': ['armored', 'boss'], 's8_swift': ['aerial', 'boss'],
    'n8_keen': ['ambush', 'boss'], 'n8_luck': ['tide', 'reflect', 'boss'], 'n8_plenty': ['toxic', 'swarm', 'boss'],
    'm8_purify': ['toxic', 'boss'], 'm8_spell': ['spectral', 'boss'], 'm8_ward': ['seal_breaker', 'warded', 'boss'],
    'k8_awe': ['armored', 'boss'], 'k8_ghost': ['spectral', 'reflect', 'boss'], 'k8_hide': ['ambush', 'boss'],
}
GEAR_LEVELS = (46, 50)
BODY_LINE = {'vitality': '체질', 'agility': '민첩', 'willpower': '의지'}

SHOP = [
    ('myeongdeung_lamp', 1200, 3), ('night_tea', 420, 5),
    ('tonic', 210, 10), ('ward_talisman', 260, 8), ('travel_ration', 160, 10), ('repair_kit', 0, 3),
    ('spirit_qi_pill', 0, 5), ('revival_charm', 1100, 1), ('ammo_arrow', 0, 200), ('ammo_bolt', 0, 200), ('ammo_dart', 0, 200),
]
SHOP_REST = [
    ('myeongdeung_lamp', 1200, 3), ('night_tea', 420, 5), ('ember_ash_pill', 520, 4),
    ('tonic', 210, 10), ('travel_ration', 160, 10), ('repair_kit', 0, 3), ('revival_charm', 1100, 1),
    ('ammo_arrow', 0, 200), ('ammo_bolt', 0, 200), ('ammo_dart', 0, 200),
]

FURNITURE = {
    'wall_bleached_eave_lamp': dict(source='shop', mats={P: 2, 'wood': 2}, field='carpentry', lv=45),
    'floor_frozen_target': dict(source='drop_normal', mats={A: 2, 'lumber': 2}, field='carpentry', lv=45),
    'floor_cheong_prow': dict(source='drop_normal', mats={K: 2, 'lacquer': 1, 'plank_water_jar': 1}, field='carpentry', lv=45),
    'surface_armillary_model': dict(source='drop_guardian', mats={G: 2, R: 1, 'iron_ingot': 2}, field='artifice', lv=45),
    'floor_empty_throne_stool': dict(source='drop_guardian', mats={E: 2, 'md_litter': 1, 'lacquer': 2}, field='carpentry', lv=45),
    'floor_seven_seat_table': dict(source='boss:dd_pact_5', mats=None, field=None, lv=45),
    'rubbing_undying_lampfish': dict(source='named', mats={'undying_lampfish': 1, 'fine_paper': 2, P: 2}, field='sealing', lv=45),
    'rubbing_burrow_goldcarp': dict(source='named', mats={'burrow_goldcarp': 1, 'fine_paper': 2, P: 2}, field='sealing', lv=45),
    'ug_empty_throne': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_chain_lantern': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_ninefold_screen': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_water_mirror': dict(source='ultimate', mats=None, field=None, lv=50),
    'paper:ug_vortex': dict(source='ultimate', mats=None, field=None, lv=50),
    'ground:ug_vortex': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_nine_board': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_ledger_shelf': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_ink_pool': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_great_brushrack': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_abacus_table': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_ledger_chest': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_seven_lamps': dict(source='ultimate', mats=None, field=None, lv=50),
    'ug_whitenight_window': dict(source='ultimate', mats=None, field=None, lv=50),
    'paper:ug_whitenight': dict(source='ultimate', mats=None, field=None, lv=50),
}

DD_WALK = ['dark_yamen', 'martial_row', 'red_shrine_lane', 'old_ferry_market', 'first_observatory', 'ash_palace', 'pact_court']
DD_BOSSES = ['dd_yamen_5', 'dd_martial_5', 'dd_shrine_5', 'dd_ferry_5', 'dd_obs_5', 'dd_palace_5', 'dd_pact_5']
TITLES = [
    ('dd_arrive', '흰 밤에 닿은 이', 3, {'mental_loss_pct': -3}, {'n': 1, 'p': {'region_id': 'deungdo_landing'}, 'ev': 'travel', 'has': 'travel_history_id'}, '남문 수로 선착에 닿는다', False),
    ('dd_walker', '흰 거리를 걸은 이', 4, {'travel_time_pct': -4, 'encounter_pct': -3}, {'all': [{'p': {'region_id': r}, 'ev': 'travel', 'has': 'travel_history_id'} for r in DD_WALK]}, '등도 일곱 구역에 모두 닿는다', False),
    ('dd_boss_all', '일곱 등을 밝힌 이', 5, {'erosion_pct': -5, 'mental_loss_pct': -5, 'combat_damage_pct': 2},
     {'all': [{'p': {'monster_id': m, 'defeated': True}, 'ev': 'combat'} for m in DD_BOSSES]}, '등도 일곱 구역의 우두머리를 모두 풀어 보낸다', False),
    ('dd_alone', '홀로 흰 밤을 헤맨 이', 4, {'mental_loss_pct': -4}, {'n': 100, 'p': {'kind': 'field_search', 'wn_alone': True}, 'ev': 'explore'}, '흰 밤 속에서 파티원 없이 100번 탐색한다', True),
    ('dd_wick', '심지를 모은 이', 3, {'rare_loot_pct': 3}, {'n': 50, 'p': {'wick': True}, 'ev': 'combat'}, '요괴를 풀어 보내고 명등 심지를 50번 거둔다', False),
    ('dd_fish_undying_lampfish', '꺼지지 않는 이름을 낚은 이', 4, {'fish_bite_pct': 3}, {'n': 1, 'p': {'fish': 'undying_lampfish'}, 'ev': 'fish'}, '꺼지지 않는 등어를 낚는다', True),
    ('dd_fish_burrow_goldcarp', '물굴의 금빛을 낚은 이', 4, {'fish_rare_pct': 3}, {'n': 1, 'p': {'fish': 'burrow_goldcarp'}, 'ev': 'fish'}, '물굴 금잉어를 낚는다', True),
    ('dd_named_all', '등도의 명어를 낚은 이', 5, {'fish_bite_pct': 4, 'fish_rare_pct': 8, 'fish_size_pct': 8},
     {'all': [{'p': {'fish': f}, 'ev': 'fish'} for f in ['undying_lampfish', 'burrow_goldcarp']]}, '등도의 명어 둘을 모두 낚는다', True),
    ('gg_kill1', '값을 치르지 않은 이', 5, {'presence': 6, 'erosion_pct': -6, 'combat_damage_pct': 3}, {'n': 1, 'ev': 'gg_win'}, '깊은 장부에서 값귀를 쓰러뜨린다', False),
    ('gg_kill10', '장부를 덮은 이', 5, {'mental_loss_pct': -6, 'combat_damage_pct': 2}, {'n': 10, 'ev': 'gg_win'}, '깊은 장부에서 값귀를 10번 쓰러뜨린다', False),
    ('gg_solo', '홀로 셈을 맞춘 이', 5, {'evasion_pct': 2, 'combat_damage_pct': 3}, {'p': {'solo': True}, 'ev': 'gg_win'}, '혼자 깊은 장부에서 값귀를 쓰러뜨린다', False),
    ('gg_flawless', '한 섬도 뜯기지 않은 장부', 5, {'healing_pct': 5, 'incoming_damage_pct': -3}, {'p': {'flawless': True}, 'ev': 'gg_win'}, '둘 이상이 함께, 아무도 물러나지 않고 깊은 장부에서 값귀를 쓰러뜨린다', True),
    ('by_kill1', '흰 밤을 걷어 낸 이', 5, {'presence': 6, 'erosion_pct': -8, 'mental_loss_pct': -4}, {'n': 1, 'ev': 'by_win'}, '깊은 판에서 백야를 이긴다', False),
    ('by_kill10', '맹약 마당의 등지기', 5, {'mental_loss_pct': -6, 'combat_damage_pct': 3}, {'n': 10, 'ev': 'by_win'}, '깊은 판에서 백야를 10번 이긴다', False),
    ('by_solo', '제 이름으로 등을 켠 이', 5, {'evasion_pct': 2, 'combat_damage_pct': 3}, {'p': {'solo': True}, 'ev': 'by_win'}, '혼자 깊은 판에서 백야를 이긴다', False),
    ('by_flawless', '일곱 등이 꺼지지 않은 밤', 5, {'healing_pct': 5, 'incoming_damage_pct': -3}, {'p': {'flawless': True}, 'ev': 'by_win'}, '둘 이상이 함께, 아무도 물러나지 않고 깊은 판에서 백야를 이긴다', True),
]
TITLE_CAT = '명등기'
NAME_STYLE = (1034, '흰 밤 은', 'cat', TITLE_CAT, 6)
COSMETICS = [
    ('fr_white_night', 'frame', 'legend', '흰 밤 테', '등도 일곱 구역에 모두 닿으면', {'title': 'dd_walker'}, 1510),
    ('sl_myeongdeung', 'seal', 'legend', '낙관 「明燈」', '등도 일곱 구역의 우두머리를 모두 풀어 보내면', {'title': 'dd_boss_all'}, 1511),
]

MEISHO = [
    dict(id='mz_dd_target_tree', name='과녁 못 닿은 고목', region='martial_row', node='연무 마당 끝', kind='wood', phase='dawn', weather='clear', weather2='wind',
         desc='연무 마당 끝에 선 고목이다. 빗나간 화살이 일흔 해째 가지 끝에 멈춰 있고, 밤을 되찾은 뒤 맑거나 삭풍 부는 해돋이에만 결이 풀린다.'),
    dict(id='mz_dd_star_plinth', name='별 떨어진 주춧돌', region='first_observatory', node='혼천의 받침 아래', kind='stone', phase='night', weather='clear', weather2='cloudy',
         desc='혼천의 받침 아래 박힌 주춧돌이다. 별이 하나 떨어져 박혔다는 말이 있고, 밤을 되찾은 뒤 맑거나 흐린 삼경에만 돌결이 빛난다.'),
    dict(id='mz_dd_ash_flower', name='임금 뜰의 재꽃', region='ash_palace', node='옥좌 뒤 정원', kind='herb', phase='dusk', weather='drizzle', weather2='fog',
         desc='옥좌 뒤 정원 재 속에서 피는 꽃이다. 밤을 되찾은 뒤 가는 비가 내리거나 안개 낀 땅거미에만 잎을 연다.'),
]
MEISHO_NIGHT_ONLY = True

MZ_MATS = [
    ('mz_herb_l', '등불 서린 명초', 8, 40, 9000, '흰 밤이 걷힌 등도 명소에서만 나는 명초다. 잎맥 사이로 등불 같은 빛이 돈다.'),
    ('mz_wood_l', '등불 서린 명목', 8, 40, 9000, '흰 밤이 걷힌 등도 명소에서만 나는 명목이다. 나이테 안쪽이 등불처럼 따뜻하다.'),
    ('mz_stone_l', '등불 서린 명석', 8, 40, 9000, '흰 밤이 걷힌 등도 명소에서만 나는 명석이다. 쥐면 돌 속에서 작은 불이 켜진다.'),
]
MZ_KIND_ITEMS = {'herb': 'mz_herb_l', 'wood': 'mz_wood_l', 'stone': 'mz_stone_l'}
MZ_RULES = {'rank': 50, 'l_pct': {'base': 3, 'cap': 10}, 'deungdo_only': True}

MZ_STATUSES = [
    ('mz_lamp_incense', '등불 명소 향', 1440, {'mz_next': 2}, 'eye', '등불 명소 향의 연기가 다음에 열릴 명소 둘을 짚어 줍니다.'),
]

TG = {'trait': '정밀 채집', 'req_line': 'gathering_rank', 'req_rank': 30}
MZ_GEAR = [
    dict(id='lt_knife_mzl', name='등불 서린 채집도', cat='tool', line='knife', stat=None, field='carpentry', rank=40, qty=1,
         traits=dict(TG, gathering_bonus_pct=38, rare_loot_pct=11, mz_j_wood=15, mz_j_herb=3), desc='등불 서린 명초를 물 먹은 뱃판 자루에 감은 채집도다. 명소에서 「…의 정」을 더 잘 가려낸다.',
         mats={'mz_herb_l': 1, 'mz_wood_j': 2, K: 3, W: 2}),
    dict(id='lt_pick_mzl', name='등불 서린 곡괭이', cat='tool', line='pick', stat=None, field='smithing', rank=40, qty=1,
         traits=dict(TG, gathering_bonus_pct=36, rare_loot_pct=10, mz_j_stone=18, mz_extra=1), desc='등불 서린 명석으로 날을 세운 곡괭이다. 명소에서 캘 때 명소 재료를 하나 더 거둔다.',
         mats={'mz_stone_l': 1, 'mz_stone_j': 2, T: 3, W: 2}),
    dict(id='lt_sickle_mzl', name='등불 서린 낫', cat='tool', line='sickle', stat=None, field='smithing', rank=40, qty=1,
         traits=dict(TG, gathering_bonus_pct=31, sig_pct=11, sig_where='herb', mz_j_herb=15, mz_j_wood=3, mz_n_pct=1), desc='등불 서린 명목 자루에 흰 밤 서리로 식힌 날을 단 낫이다. 명소에서 「이름 서린」 재료가 조금 더 잘 보인다.',
         mats={'mz_wood_l': 1, 'mz_herb_j': 2, F: 3, W: 2}),
    dict(id='lt_lantern_mzl', name='명등지기 등', cat='tool', line='lantern', stat=None, field='artifice', rank=50, qty=1,
         traits=dict(TG, gathering_bonus_pct=29, sig_pct=14, sig_where='dark', mz_sense=1, mz_n_pct=3), desc='명등지기가 들던 등을 되살렸다. 지금 있는 지역에 열린 명소가 있으면 불꽃이 그쪽으로 기운다.',
         mats={'mz_herb_l': 1, 'mz_wood_l': 1, 'mz_stone_l': 1, W: 3, O: 2}),
    dict(id='n_mzl_night', name='밤 명소 노리개', cat='norigae', line=None, stat='spirit_affinity', field='weaving', rank=50, qty=1,
         traits={'trait': '노리개', 'rare_loot_pct': 12, 'mz_soil_pct': 10}, desc='등불 서린 명초와 별 기록 동판을 꿴 노리개다. 흙을 살필 때 묻힌 것이 더 잘 보인다.',
         mats={'mz_herb_l': 1, 'mz_herb_n': 1, R: 2, W: 2}),
    dict(id='mz_lamp_incense', name='등불 명소 향', cat='consumable', line=None, stat=None, field='sealing', rank=40, qty=2, fx={'buffs': ['mz_lamp_incense']},
         traits=None, desc='등불 서린 명목을 끊긴 등 기름에 적셔 사른 향이다. 피우면 하루 동안 다음에 열릴 명소 둘이 언제·어디서 열리는지 보인다.',
         mats={'mz_wood_l': 1, 'mz_herb': 2, O: 2}),
    dict(id='w_melee_mzl', name='등불 서린 명석 환도', cat='weapon', line=None, stat='strength', field='smithing', rank=50, qty=1,
         traits={'power': 68, 'trait': '근접', 'weapon_type': 'melee', 'combat_damage_pct': 24, 'mz_j_stone': 10}, desc='등불 서린 명석을 두드려 날을 세운 환도다. 명소에서 「명석의 정」이 더 잘 보인다.',
         mats={'mz_stone_l': 1, 'mz_stone_n': 1, B: 4, W: 3}),
    dict(id='w_ranged_mzl', name='등불 서린 명목 각궁', cat='weapon', line=None, stat='agility', field='carpentry', rank=50, qty=1,
         traits={'ammo': 'ammo_arrow', 'power': 68, 'trait': '원거리', 'weapon_type': 'ranged', 'combat_damage_pct': 24, 'mz_j_wood': 10}, desc='등불 서린 명목으로 짠 각궁이다. 명소에서 「명목의 정」이 더 잘 보인다.',
         mats={'mz_wood_l': 1, 'mz_wood_n': 1, A: 4, W: 3}),
    dict(id='w_magic_mzl', name='등불 서린 명초 법등', cat='weapon', line=None, stat='spirit_affinity', field='artifice', rank=50, qty=1,
         traits={'power': 68, 'trait': '술법', 'weapon_type': 'magic', 'combat_damage_pct': 24, 'mz_j_herb': 10}, desc='등불 서린 명초를 심지 둘레에 감은 법등이다. 명소에서 「명초의 정」이 더 잘 보인다.',
         mats={'mz_herb_l': 1, 'mz_herb_n': 1, O: 4, W: 3}),
    dict(id='a_mzl_vit', name='등불 서린 명석 비늘갑', cat='armor', line=None, stat='vitality', field='smithing', rank=50, qty=1,
         traits={'trait': '방호', 'defense': 61, 'presence': 58, 'evasion_pct': -6, 'mz_extra': 1}, desc='등불 서린 명석 비늘을 겹친 갑옷이다. 명소에서 캘 때 명소 재료를 하나 더 거둔다.',
         mats={'mz_stone_l': 1, 'mz_stone_j': 2, B: 4, W: 3}),
    dict(id='a_mzl_agi', name='등불 서린 명목 경갑', cat='armor', line=None, stat='agility', field='leatherwork', rank=50, qty=1,
         traits={'trait': '방호', 'defense': 37, 'evasion_pct': 12, 'mz_soil_pct': 20}, desc='등불 서린 명목 조각을 누빈 경갑이다. 흙을 살필 때 묻힌 것의 기척을 잡는다.',
         mats={'mz_wood_l': 1, 'mz_wood_j': 2, Q: 4, W: 3}),
    dict(id='a_mzl_will', name='등불 서린 명초 법의', cat='armor', line=None, stat='willpower', field='weaving', rank=50, qty=1,
         traits={'trait': '방호', 'defense': 31, 'erosion_pct': -24, 'damage_reduction_pct': 15, 'mz_n_pct': 2}, desc='등불 서린 명초 물을 들인 법의다. 명소에서 「이름 서린」 재료가 더 잘 보인다.',
         mats={'mz_herb_l': 1, 'mz_herb_j': 2, P: 4, W: 3}),
    dict(id='h_mzl_herb', name='등불 서린 명초 관', cat='hat', line=None, stat='willpower', field='weaving', rank=50, qty=1,
         traits={'trait': '관모', 'erosion_pct': -30, 'mental_loss_pct': -45, 'mz_soil_pct': 20}, desc='등불 서린 명초로 물들인 관이다. 흙을 살필 때 눈이 밝아진다.',
         mats={'mz_herb_l': 1, 'mz_herb_j': 1, P: 2, W: 2}),
    dict(id='s_mzl_wood', name='등불 서린 명목 짚신', cat='shoes', line=None, stat='vitality', field='leatherwork', rank=50, qty=1,
         traits={'trait': '신', 'travel_time_pct': -30, 'mz_j_all': 5}, desc='등불 서린 명목 껍질을 꼬아 삼은 짚신이다. 어느 명소에서든 「…의 정」을 조금 더 잘 가려낸다.',
         mats={'mz_wood_l': 1, 'mz_wood_j': 1, K: 2, W: 2}),
    dict(id='m_mzl_stone', name='등불 서린 명석 호패', cat='amulet', line=None, stat='willpower', field='sealing', rank=50, qty=1,
         traits={'trait': '호신부', 'presence': 30, 'incoming_damage_pct': -15, 'mz_n_pct': 2}, desc='등불 서린 명석을 깎은 호패다. 지니면 명소에서 「이름 서린」 재료가 더 잘 보인다.',
         mats={'mz_stone_l': 1, 'mz_stone_j': 1, D: 2, W: 2}),
    dict(id='k_mzl_wood', name='등불 서린 명목 탈', cat='mask', line=None, stat='agility', field='sealing', rank=50, qty=1,
         traits={'trait': '탈', 'presence': -75, 'encounter_pct': -24, 'mz_soil_pct': 30}, desc='등불 서린 명목으로 깎은 탈이다. 쓰고 흙을 살피면 묻힌 것이 더 잘 보인다.',
         mats={'mz_wood_l': 1, 'mz_wood_j': 1, F: 2, W: 2}),
]
MZ_GEAR_LV = 47
