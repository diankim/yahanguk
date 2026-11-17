OPEN_QUEST = 'mdq_x_ultimate'
LEVEL = 50
PARTY = (2, 4)
TOKENS = {'first': 10, 'clear': 3}
MODE_NAME = '극'
SHOP_REGION = 'jeongni_vault'

BOARDS = {
    'gwiheo': dict(name='극 귀허', short='극귀', boss='gwiheo', token='ug_tok_gwiheo', token_name='귀허 등심',
                   token_desc='극 귀허를 깨고 얻은 등심 한 가닥이다. 소용돌이 바닥에서 건져 올려도 불씨가 꺼지지 않았다. 극의 장부 교환에서 귀허의 물건으로 바꾼다.'),
    'mukjeok': dict(name='극 명부', short='극명', boss='mukjeok', token='ug_tok_mukjeok', token_name='명부 먹심',
                    token_desc='극 명부를 깨고 얻은 먹심 한 토막이다. 아홉 칸 명부를 다시 쓸 때 남은 먹이 굳은 것이다. 극의 장부 교환에서 명부의 물건으로 바꾼다.'),
    'gapgwi': dict(name='극 장부', short='극장', boss='gapgwi', token='ug_tok_gapgwi', token_name='장부 셈가지',
                   token_desc='극 장부를 깨고 얻은 셈가지 하나다. 값귀의 주판에서 빠져나와 흰 밤에도 그림자가 졌다. 극의 장부 교환에서 장부의 물건으로 바꾼다.'),
}

SHOP = [
    ('gwiheo', 'item', 'hf_ug_empty_throne', '빈 왕좌', 40),
    ('gwiheo', 'item', 'hf_ug_chain_lantern', '사슬 매단 등롱', 16),
    ('gwiheo', 'item', 'hf_ug_ninefold_screen', '구중 봉인 병풍', 24),
    ('gwiheo', 'item', 'hf_ug_water_mirror', '귀허 물거울', 14),
    ('gwiheo', 'item', 'hp_ug_vortex', '소용돌이 물빛 벽지', 10),
    ('gwiheo', 'item', 'hg_ug_vortex', '소용돌이 마루', 10),
    ('gwiheo', 'outfit', 'acc:ug_void_crown', '빈 왕관', 30),
    ('gwiheo', 'outfit', 'top:ug_chain_robe', '사슬 수 도포', 26),
    ('gwiheo', 'outfit', 'bottom:ug_tide_skirt', '물결 겹치마', 20),
    ('gwiheo', 'frame', 'fr_ug_gwiheo', '테두리 「극 귀허」', 22),
    ('gwiheo', 'seal', 'sl_ug_heo', '낙관 「虛」', 18),
    ('gwiheo', 'pet', 'ug_vortex_jelly', '아기 소용돌이 해파리', 45),

    ('mukjeok', 'item', 'hf_ug_nine_board', '아홉 칸 바둑상', 20),
    ('mukjeok', 'item', 'hf_ug_ledger_shelf', '명부 서가', 26),
    ('mukjeok', 'item', 'hf_ug_ink_pool', '먹 웅덩이 깔개', 12),
    ('mukjeok', 'item', 'hf_ug_great_brushrack', '큰 붓걸이', 16),
    ('mukjeok', 'item', 'hair_pattern', '머리 그리기 도안', 8),
    ('mukjeok', 'outfit', 'top:ug_ink_longcoat', '먹빛 장포', 26),
    ('mukjeok', 'outfit', 'bottom:ug_ink_hakama', '먹줄 바지', 20),
    ('mukjeok', 'outfit', 'acc:ug_brush_hairpin', '붓 비녀', 18),
    ('mukjeok', 'pattern', 'pt_ug_inkline', '바탕 무늬 「먹줄」', 22),
    ('mukjeok', 'name_style', 'ns:1035', '이름 색 「극묵」', 32),
    ('mukjeok', 'pet', 'ug_ink_tadpole', '먹방울 올챙이', 45),

    ('gapgwi', 'item', 'hf_ug_abacus_table', '주판 탁자', 20),
    ('gapgwi', 'item', 'hf_ug_ledger_chest', '장부 궤짝', 14),
    ('gapgwi', 'item', 'hf_ug_seven_lamps', '일곱 등 진열대', 30),
    ('gapgwi', 'item', 'hf_ug_whitenight_window', '흰 밤 창호', 16),
    ('gapgwi', 'item', 'hp_ug_whitenight', '흰 밤 창호지 벽지', 10),
    ('gapgwi', 'outfit', 'acc:ug_counter_hat', '셈꾼 갓', 18),
    ('gapgwi', 'outfit', 'top:ug_whitenight_cheollik', '흰 밤 철릭', 26),
    ('gapgwi', 'outfit', 'acc:ug_wick_hairpin', '등심 머리꽂이', 16),
    ('gapgwi', 'frame', 'fr_ug_gapgwi', '테두리 「극 장부」', 22),
    ('gapgwi', 'seal', 'sl_ug_jong', '낙관 「終」', 18),
    ('gapgwi', 'pet', 'ug_abacus_ladybug', '주판알 무당벌레', 45),
]

TITLES = [
    ('ug_gwiheo_1', '극 귀허를 건넌 이', 5, {}, {'n': 1, 'ev': 'ug_win', 'p': {'board': 'gwiheo'}}, '극 귀허를 깬다', False),
    ('ug_gwiheo_10', '소용돌이를 길들인 이', 5, {}, {'n': 10, 'ev': 'ug_win', 'p': {'board': 'gwiheo'}}, '극 귀허를 10번 깬다', False),
    ('ug_mukjeok_1', '극 명부를 다시 쓴 이', 5, {}, {'n': 1, 'ev': 'ug_win', 'p': {'board': 'mukjeok'}}, '극 명부를 깬다', False),
    ('ug_mukjeok_10', '아홉 칸의 주인', 5, {}, {'n': 10, 'ev': 'ug_win', 'p': {'board': 'mukjeok'}}, '극 명부를 10번 깬다', False),
    ('ug_gapgwi_1', '극 장부를 덮은 이', 5, {}, {'n': 1, 'ev': 'ug_win', 'p': {'board': 'gapgwi'}}, '극 장부를 깬다', False),
    ('ug_gapgwi_10', '셈이 끝난 밤', 5, {}, {'n': 10, 'ev': 'ug_win', 'p': {'board': 'gapgwi'}}, '극 장부를 10번 깬다', False),
    ('ug_duo', '둘이서 끝을 본 이', 5, {}, {'n': 1, 'ev': 'ug_win', 'p': {'duo': True}}, '둘이서 극 판 하나를 깬다', True),
    ('ug_flawless', '아무도 쓰러지지 않은 끝', 5, {}, {'n': 1, 'ev': 'ug_win', 'p': {'flawless': True}}, '아무도 쓰러지지 않고 극 판 하나를 깬다', True),
    ('ug_all', '극을 셋 다 본 이', 5, {}, {'all': [{'p': {'board': b}, 'ev': 'ug_win'} for b in ('gwiheo', 'mukjeok', 'gapgwi')]}, '극 판 셋을 모두 깬다', False),
]
TITLE_CAT = '극'
DRAFT = True
