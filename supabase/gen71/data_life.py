"""7.1 ② 생활 장비 Lv40까지: 채집(채집도·곡괭이·낫·등) · 탐사(지팡이·나침반) · 낚시(낚싯대) · 제작 공구(가방에 두면 품질 +)
값 규칙(CLAUDE.md §12): 기준 시세 ≥ 재료 시세 합 × 1.1(장비는 1.2 안팎), 같은 계열 높은 단계는 바로 아래보다 15% 이상 비싸다.
숙련 조건은 2026-10-29 전체 29명 기준(채집 숙련 가운데 4·최고 10, 제작 가운데 2·최고 10, 조사 가운데 16·최고 43)."""

# 재료 기준 시세(운영 DB 2026-10-29)
PRICE = dict(iron_ingot=50, lumber=40, charcoal=20, wood=15, resin=25, seal_paper=20, talisman_thread=85, silk=65, beast_bone=65, moon_moss=65,
             cinnabar=65, sealing_ink=65, spirit_thread=150, spirit_glass=190, reinforced_lumber=310, herbal_extract=90, lantern_oil=140,
             steel_ingot=450, thunder_ore=260, spirit_bark=260, star_sand=260, jade_shard=260, sky_feather=260, mirror_shard=260, rune_plate=710,
             reinforced_leather=360, banyo_scale=300, silver_scale=200, dragon_scale_koi=600, abyss_dragonfish=800,
             reed_silk=380, inverted_incense=380, moonless_silk=400, oblivion_crystal=420, gwiheo_iron=480, yoin_blood=520, gwiheo_pearl=900)

# (id, 이름, 줄기 line, 단계, 레벨, traits, 숙련 조건(line, 단계) 또는 None, 재료, 제작 장소, 분야, 설명)
G = 'gathering_rank'; I = 'investigation_rank'; C = 'crafting_rank'
DARK = '유물 채집터나 사당·지하·심연 같은 어두운 지역'
ITEMS = [
    # ── 채집: 곡괭이(광맥·유물 +10%p) ──
    ('pick_2', '강철 곡괭이', 'pick', 2, 6, dict(gathering_bonus_pct=9), (G, 2), dict(iron_ingot=3, lumber=2, charcoal=2), '연무장·팔괘진', 'smithing',
     '단단히 벼린 곡괭이. 장착하면 채집량 +9%, 광맥·유물 채집터에서는 +10%를 더 거둔다.'),
    ('pick_3', '청강 곡괭이', 'pick', 3, 11, dict(gathering_bonus_pct=13, rare_loot_pct=1), (G, 4), dict(steel_ingot=1, reinforced_lumber=1, beast_bone=2), '철벽 고찰', 'smithing',
     '청강 날을 박은 곡괭이. 장착하면 채집량 +13%·귀한 것이 조금 잘 보이고, 광맥·유물 채집터에서는 +10%를 더 거둔다.'),
    ('pick_5', '뇌철 곡괭이', 'pick', 5, 24, dict(gathering_bonus_pct=23, rare_loot_pct=6), (G, 9), dict(thunder_ore=4, steel_ingot=2, spirit_bark=1), '무극 관성대', 'smithing',
     '벼락 맞은 쇠로 만든 곡괭이. 장착하면 채집량 +23%·귀한 것이 잘 보이고, 광맥·유물 채집터에서는 +10%를 더 거둔다.'),
    ('pick_6', '귀허 흑철 곡괭이', 'pick', 6, 34, dict(gathering_bonus_pct=28, rare_loot_pct=8), (G, 13), dict(gwiheo_iron=5, oblivion_crystal=2, yoin_blood=1), '반요촌', 'smithing',
     '귀허의 검은 쇠로 만든 곡괭이. 장착하면 채집량 +28%·귀한 것이 잘 보이고, 광맥·유물 채집터에서는 +10%를 더 거둔다.'),
    # ── 채집: 채집도(약초·목재·보급품·물가 +10%p) ──
    ('knife_4', '월광 채집도', 'knife', 4, 16, dict(gathering_bonus_pct=17, rare_loot_pct=3), (G, 6), dict(steel_ingot=1, moon_moss=3, reinforced_lumber=1), '구름나루', 'smithing',
     '달빛 이끼로 날을 닦은 채집도. 장착하면 채집량 +17%·귀한 것이 잘 보이고, 약초·목재·보급품·물가 채집터에서는 +10%를 더 거둔다.'),
    ('knife_7', '월백 채집도', 'knife', 6, 38, dict(gathering_bonus_pct=30, rare_loot_pct=9), (G, 16), dict(gwiheo_iron=5, gwiheo_pearl=2, reed_silk=2), '반요촌', 'smithing',
     '귀허 진주를 박은 하얀 채집도. 장착하면 채집량 +30%·귀한 것이 아주 잘 보이고, 약초·목재·보급품·물가 채집터에서는 +10%를 더 거둔다.'),
    # ── 채집: 낫(약초·영기 채집터에서 그 지역 희귀품) ──
    ('sickle_4', '월광 낫', 'sickle', 4, 18, dict(gathering_bonus_pct=14, sig_pct=5, sig_where='herb'), (G, 7), dict(moon_moss=4, steel_ingot=1, spirit_thread=1), '구름나루', 'smithing',
     '달빛을 머금은 낫. 장착하면 채집량 +14%, 약초·영기 채집터에서 5% 확률로 그 지역의 희귀품을 함께 거둔다.'),
    ('sickle_6', '망각 수정 낫', 'sickle', 6, 35, dict(gathering_bonus_pct=24, sig_pct=8, sig_where='herb'), (G, 14), dict(oblivion_crystal=3, gwiheo_iron=2, reed_silk=2), '반요촌', 'smithing',
     '망각 수정 날이 풀의 기억까지 베는 낫. 장착하면 채집량 +24%, 약초·영기 채집터에서 8% 확률로 그 지역의 희귀품을 함께 거둔다.'),
    # ── 채집: 등(어두운 곳에서 그 지역 희귀품) ──
    ('lantern_4', '청등', 'lantern', 4, 17, dict(gathering_bonus_pct=12, sig_pct=7, sig_where='dark'), (G, 6), dict(lantern_oil=3, spirit_glass=2, iron_ingot=2), '철벽 고찰', 'artifice',
     '푸른 어유를 태우는 등. 장착하면 채집량 +12%, ' + DARK + '에서 7% 확률로 그 지역의 희귀품을 함께 거둔다.'),
    ('lantern_6', '혼등', 'lantern', 6, 36, dict(gathering_bonus_pct=22, sig_pct=10, sig_where='dark'), (G, 15), dict(moonless_silk=2, yoin_blood=2, gwiheo_pearl=1), '반요촌', 'artifice',
     '넋을 비추는 등. 장착하면 채집량 +22%, ' + DARK + '에서 10% 확률로 그 지역의 희귀품을 함께 거둔다.'),
    # ── 탐사: 숨은 길·채집터 찾기 ──
    ('staff_2', '답사 지팡이', 'explore', 2, 5, dict(life_slot='explore', trait='탐사', search_find_pct=10), (I, 3), dict(lumber=3, talisman_thread=1, seal_paper=2), '야행국 본부 정청', 'carpentry',
     '눈금을 새긴 지팡이. 탐사 칸에 장착하면 탐색할 때 숨은 길과 채집터를 더 잘 찾는다(찾을 확률 +10%).'),
    ('compass_4', '별자리 나침반', 'explore', 4, 18, dict(life_slot='explore', trait='탐사', search_find_pct=28, clue_bonus_pct=3), (I, 18), dict(star_sand=2, jade_shard=1, rune_plate=1, spirit_glass=1), '철벽 고찰', 'artifice',
     '별자리를 따라 바늘이 도는 나침반. 탐사 칸에 장착하면 숨은 길과 채집터를 찾을 확률 +28%, 단서 발견 +3%.'),
    ('compass_5', '천문 혼천 나침반', 'explore', 5, 26, dict(life_slot='explore', trait='탐사', search_find_pct=34, clue_bonus_pct=5), (I, 26), dict(star_sand=3, sky_feather=2, rune_plate=1, mirror_shard=1), '무극 관성대', 'artifice',
     '혼천의를 손바닥만 하게 줄인 나침반. 탐사 칸에 장착하면 숨은 길과 채집터를 찾을 확률 +34%, 단서 발견 +5%.'),
    ('compass_6', '귀허 등명 나침반', 'explore', 6, 35, dict(life_slot='explore', trait='탐사', search_find_pct=42, clue_bonus_pct=7), (I, 34), dict(gwiheo_pearl=2, oblivion_crystal=2, rune_plate=1), '반요촌', 'artifice',
     '귀허 진주가 길을 밝히는 나침반. 탐사 칸에 장착하면 숨은 길과 채집터를 찾을 확률 +42%, 단서 발견 +7%.'),
    # ── 낚시 ──
    ('rod_3', '청죽 낚싯대', 'rod', 3, 12, dict(life_slot='fishing', trait='낚시', fish_bite_pct=9, fish_rare_pct=6), None, dict(reinforced_lumber=1, spirit_thread=2, lantern_oil=1), '구름나루', 'carpentry',
     '푸른 대나무를 기름에 절인 낚싯대. 낚시 칸에 두면(비우면 가방의 가장 좋은 것) 입질 +9%·희귀 어종 +6%.'),
    ('rod_4', '수경 낚싯대', 'rod', 4, 17, dict(life_slot='fishing', trait='낚시', fish_bite_pct=12, fish_rare_pct=8), None, dict(silver_scale=2, spirit_bark=1, spirit_thread=2), '구름나루', 'carpentry',
     '은린 비늘을 엮은 낚싯대. 입질 +12%·희귀 어종 +8%.'),
    ('rod_5', '용잠 낚싯대', 'rod', 5, 24, dict(life_slot='fishing', trait='낚시', fish_bite_pct=15, fish_rare_pct=11, fish_size_pct=5), None, dict(dragon_scale_koi=1, sky_feather=1, reinforced_lumber=2), '잔불촌', 'carpentry',
     '용잠 수궁의 비늘잉어로 찌를 단 낚싯대. 입질 +15%·희귀 어종 +11%·물고기 크기 +5%.'),
    ('rod_6', '귀허 진주 낚싯대', 'rod', 6, 34, dict(life_slot='fishing', trait='낚시', fish_bite_pct=18, fish_rare_pct=14, fish_size_pct=8), None, dict(gwiheo_pearl=1, reed_silk=3, abyss_dragonfish=1), '반요촌', 'carpentry',
     '진주 빛이 물속을 비추는 낚싯대. 입질 +18%·희귀 어종 +14%·물고기 크기 +8%.'),
    # ── 제작 공구: 장착하지 않고 가방에 두면 그 분야 제작 품질 + (숙련·레벨이 모자라면 안 붙음) ──
    ('hammer_2', '무쇠 단조 망치', 'hammer', 2, 8, dict(life_slot='craft', trait='제작 공구', craft_quality=3, craft_fields=['smithing', 'carpentry', 'artifice']), (C, 2), dict(iron_ingot=3, lumber=1, charcoal=2), '연무장·팔괘진', 'smithing',
     '단조·목공·법구 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +3(제작 숙련 2단계부터).'),
    ('hammer_4', '청강 단조 망치', 'hammer', 4, 18, dict(life_slot='craft', trait='제작 공구', craft_quality=6, craft_fields=['smithing', 'carpentry', 'artifice']), (C, 5), dict(steel_ingot=2, reinforced_lumber=1), '철벽 고찰', 'smithing',
     '단조·목공·법구 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +6(제작 숙련 5단계부터).'),
    ('hammer_6', '귀허 흑철 망치', 'hammer', 6, 33, dict(life_slot='craft', trait='제작 공구', craft_quality=10, craft_fields=['smithing', 'carpentry', 'artifice']), (C, 10), dict(gwiheo_iron=4, yoin_blood=1), '반요촌', 'smithing',
     '단조·목공·법구 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +10(제작 숙련 10단계부터).'),
    ('needle_2', '영사 바늘집', 'needle', 2, 8, dict(life_slot='craft', trait='제작 공구', craft_quality=3, craft_fields=['weaving', 'leatherwork']), (C, 2), dict(silk=2, iron_ingot=1, talisman_thread=1), '구름나루', 'weaving',
     '직조·가죽 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +3(제작 숙련 2단계부터).'),
    ('needle_4', '요수 뼈 송곳', 'needle', 4, 18, dict(life_slot='craft', trait='제작 공구', craft_quality=6, craft_fields=['weaving', 'leatherwork']), (C, 5), dict(beast_bone=3, spirit_thread=2, reinforced_leather=1), '백골 장터', 'leatherwork',
     '직조·가죽 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +6(제작 숙련 5단계부터).'),
    ('needle_6', '무월 비단 바늘', 'needle', 6, 33, dict(life_slot='craft', trait='제작 공구', craft_quality=10, craft_fields=['weaving', 'leatherwork']), (C, 10), dict(moonless_silk=3, gwiheo_iron=1, reed_silk=1), '반요촌', 'weaving',
     '직조·가죽 공예 제작 공구. 가방에 있으면 그 분야 제작 품질 +10(제작 숙련 10단계부터).'),
    ('still_2', '구리 증류기', 'still', 2, 8, dict(life_slot='craft', trait='제작 공구', craft_quality=3, craft_fields=['alchemy']), (C, 2), dict(iron_ingot=2, spirit_glass=1, charcoal=2), '백등 야시장', 'alchemy',
     '연금 제작 공구. 가방에 있으면 연금 제작 품질 +3(제작 숙련 2단계부터).'),
    ('still_4', '영유리 증류기', 'still', 4, 18, dict(life_slot='craft', trait='제작 공구', craft_quality=6, craft_fields=['alchemy']), (C, 5), dict(spirit_glass=3, steel_ingot=1, herbal_extract=2), '잔불촌', 'alchemy',
     '연금 제작 공구. 가방에 있으면 연금 제작 품질 +6(제작 숙련 5단계부터).'),
    ('still_6', '망각 수정 증류기', 'still', 6, 33, dict(life_slot='craft', trait='제작 공구', craft_quality=10, craft_fields=['alchemy']), (C, 10), dict(oblivion_crystal=3, gwiheo_pearl=1, spirit_glass=2), '반요촌', 'alchemy',
     '연금 제작 공구. 가방에 있으면 연금 제작 품질 +10(제작 숙련 10단계부터).'),
    ('carve_4', '주사 각인도', 'carve', 4, 18, dict(life_slot='craft', trait='제작 공구', craft_quality=6, craft_fields=['sealing']), (C, 5), dict(cinnabar=3, steel_ingot=1, sealing_ink=2), '철벽 고찰', 'sealing',
     '봉인 공예 제작 공구. 가방에 있으면 봉인 공예 품질 +6(제작 숙련 5단계부터). 각인 공구가 필요한 제작법에도 쓴다.'),
    ('carve_6', '귀허 각인도', 'carve', 6, 33, dict(life_slot='craft', trait='제작 공구', craft_quality=10, craft_fields=['sealing']), (C, 10), dict(inverted_incense=2, gwiheo_iron=2, rune_plate=1), '반요촌', 'sealing',
     '봉인 공예 제작 공구. 가방에 있으면 봉인 공예 품질 +10(제작 숙련 10단계부터). 각인 공구가 필요한 제작법에도 쓴다.'),
    ('cook_2', '무쇠 식칼', 'cook', 2, 8, dict(life_slot='craft', trait='제작 공구', craft_quality=3, craft_fields=['cooking']), (C, 1), dict(iron_ingot=2, wood=2, resin=1), '백등 야시장', 'smithing',
     '요리 공구. 가방에 있으면 요리 품질 +3.'),
    ('cook_4', '청강 식칼', 'cook', 4, 18, dict(life_slot='craft', trait='제작 공구', craft_quality=6, craft_fields=['cooking']), (C, 1), dict(steel_ingot=1, beast_bone=2, lumber=1), '잔불촌', 'smithing',
     '요리 공구. 가방에 있으면 요리 품질 +6.'),
    ('cook_6', '귀허 식칼', 'cook', 6, 33, dict(life_slot='craft', trait='제작 공구', craft_quality=10, craft_fields=['cooking']), (C, 1), dict(gwiheo_iron=3, banyo_scale=2), '반요촌', 'smithing',
     '요리 공구. 가방에 있으면 요리 품질 +10.'),
]
# 이미 있는 것을 계열에 넣는다(값 순서 검사에도 씀): (id, line, 단계, 기준 시세)
EXISTING = [('ore_pick', 'pick', 1, 50), ('t4_gather', 'pick', 4, 1750), ('spirit_sickle', 'sickle', 2, 390), ('spirit_lantern', 'lantern', 2, 0),
            ('spirit_compass', 'explore', 3, 1500), ('fishing_rod', 'rod', 1, 180), ('spirit_rod', 'rod', 2, 550), ('seal_knife', 'carve', 2, 320),
            ('field_knife', 'knife', 1, 50), ('field_knife_2', 'knife', 2, 230), ('t3_gather', 'knife', 3, 900), ('t5_gather', 'knife', 5, 2500), ('t6_gather', 'knife', 6, 4560)]
# 영맥 낫·영등도 같은 방식(sig_pct·sig_where)으로 옮긴다
RETRAIT = {'spirit_sickle': dict(sig_pct=3, sig_where='herb'), 'spirit_lantern': dict(sig_pct=5, sig_where='dark')}


def price_of(ing):
    return sum(PRICE[k] * v for k, v in ing.items())


def priced():
    """재료값 × 1.2를 50전 단위로 올리고, 같은 계열 아래 단계보다 15% 이상 비싸게 맞춘다."""
    out, best = {}, {}
    for i, ln, t, p in EXISTING:
        best[(ln, t)] = max(best.get((ln, t), 0), p)
    for it in sorted(ITEMS, key=lambda x: x[3]):
        ing = it[7]
        p = -(-price_of(ing) * 12 // 10 // 10) * 10
        below = max([v for (ln, t), v in best.items() if ln == it[2] and t < it[3]] or [0])
        p = max(p, -(-below * 115 // 100 // 10) * 10)
        out[it[0]] = p
        best[(it[2], it[3])] = max(best.get((it[2], it[3]), 0), p)
    # 위 단계 기존 물품이 새 값보다 15% 넘게 비싼지(뒤집히지 않는지) 확인
    for i, ln, t, p in EXISTING:
        for it in ITEMS:
            if it[2] == ln and it[3] < t and p and p < out[it[0]] * 1.15:
                raise SystemExit(f'값 순서가 뒤집힘: {it[0]} {out[it[0]]} ≥ {i} {p}/1.15')
    return out
