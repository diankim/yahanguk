-- 세계 지형 개편: 같은 세력이 다스리는 지역을 하나의 영역으로 묶고(영역=세력령), 좌표와 길을 다시 놓는다.
-- 세부 지역 1,638곳과 채집터 3,024곳에 숫자 없는 고유 이름과 지형에 맞는 자원을 배정한다.

ALTER TABLE public.world_map_regions ADD COLUMN IF NOT EXISTS control_faction_id text REFERENCES public.world_major_factions(faction_id);
GRANT SELECT (control_faction_id) ON public.world_map_regions TO authenticated;

-- 숫자가 붙은 지역 이름 교체
UPDATE public.world_characters SET location = '잿빛 들녘' WHERE location = '제4구역 · 야외 현장';
UPDATE public.world_characters SET location = '폐쇄 사당' WHERE location = '제4구역 · 폐쇄 사당';
UPDATE public.world_characters SET travel_destination = '잿빛 들녘' WHERE travel_destination = '제4구역 · 야외 현장';
UPDATE public.world_characters SET travel_destination = '폐쇄 사당' WHERE travel_destination = '제4구역 · 폐쇄 사당';
UPDATE public.world_map_regions SET region_name = '잿빛 들녘' WHERE region_id = 'field_outskirts';
UPDATE public.world_map_regions SET region_name = '폐쇄 사당' WHERE region_id = 'shrine_ruins';

-- 좌표·영역·길
WITH v(region_id, x, y, terr, links) AS (VALUES
('hq_yard',480,360,'capital',ARRAY['field_outskirts','hq_archive','hq_dorm','hq_training','lantern_market','paper_bridge']),
('hq_dorm',445,388,'capital',ARRAY['hq_archive','hq_yard','lantern_market','old_canal','sunken_district']),
('lantern_market',438,340,'capital',ARRAY['ghost_bamboo','hq_dorm','hq_yard','paper_bridge','sunken_district']),
('hq_training',522,382,'capital',ARRAY['field_outskirts','hq_archive','hq_yard','sealed_garden','shrine_ruins']),
('hq_archive',488,410,'capital',ARRAY['hq_dorm','hq_training','hq_yard','old_canal','sealed_garden']),
('sealed_garden',545,425,'capital',ARRAY['burial_steps','hq_archive','hq_training','shrine_ruins']),
('field_outskirts',530,330,'capital',ARRAY['hq_training','hq_yard','jade_pass','paper_bridge','river_ferry','shrine_ruins']),
('shrine_ruins',588,385,'capital',ARRAY['field_outskirts','hq_training','river_ferry','salt_village','sealed_garden']),
('paper_bridge',470,298,'capital',ARRAY['field_outskirts','ghost_bamboo','hq_yard','iron_monastery','lantern_market']),
('old_canal',418,420,'capital',ARRAY['hidden_bazaar','hq_archive','hq_dorm','sunken_district']),
('ghost_bamboo',408,286,'capital',ARRAY['ash_mountain','lantern_market','paper_bridge','sunken_district','west_gate']),
('sunken_district',375,358,'capital',ARRAY['black_sand_temple','ghost_bamboo','hq_dorm','lantern_market','old_canal','red_plain','west_gate']),
('west_gate',335,312,'capital',ARRAY['ash_mountain','bone_market','ghost_bamboo','red_plain','sunken_district']),
('ash_mountain',355,215,'north',ARRAY['bone_market','frost_valley','ghost_bamboo','west_gate']),
('frost_valley',420,150,'north',ARRAY['ash_mountain','iron_monastery','sky_lake']),
('iron_monastery',500,205,'north',ARRAY['frost_valley','jade_pass','paper_bridge','sky_lake','thunder_peak']),
('sky_lake',485,105,'north',ARRAY['frost_valley','iron_monastery','thunder_peak']),
('jade_pass',590,235,'north',ARRAY['field_outskirts','iron_monastery','river_ferry','thunder_peak','white_tower']),
('thunder_peak',590,85,'north',ARRAY['iron_monastery','jade_pass','sky_lake','star_observatory','white_tower']),
('white_tower',695,150,'heavenward',ARRAY['jade_pass','mirror_pavilion','star_observatory','thunder_peak']),
('star_observatory',780,80,'heavenward',ARRAY['mirror_pavilion','thunder_peak','white_tower']),
('river_ferry',655,300,'east',ARRAY['field_outskirts','jade_pass','lotus_marsh','mirror_pavilion','salt_village','shrine_ruins']),
('salt_village',665,378,'east',ARRAY['black_tide_rift','lotus_marsh','river_ferry','shrine_ruins']),
('lotus_marsh',740,330,'east',ARRAY['black_tide_rift','mirror_pavilion','red_forest','river_ferry','salt_village','sunken_palace']),
('mirror_pavilion',745,245,'east',ARRAY['lotus_marsh','river_ferry','star_observatory','sunken_palace','white_tower']),
('sunken_palace',835,290,'east',ARRAY['lotus_marsh','mirror_pavilion']),
('red_plain',265,335,'frontier',ARRAY['black_sand_temple','bone_market','glass_canyon','sunken_district','west_gate']),
('bone_market',250,255,'frontier',ARRAY['ash_mountain','glass_canyon','red_plain','west_gate']),
('glass_canyon',170,300,'frontier',ARRAY['black_sand_temple','bone_market','red_moon_fort','red_plain']),
('black_sand_temple',215,405,'frontier',ARRAY['glass_canyon','red_moon_fort','red_plain','sunken_district']),
('red_moon_fort',140,470,'frontier',ARRAY['black_sand_temple','glass_canyon']),
('hidden_bazaar',420,490,'underworld',ARRAY['old_canal','under_root']),
('under_root',485,535,'underworld',ARRAY['burial_steps','hidden_bazaar','sealed_abyss']),
('burial_steps',570,500,'underworld',ARRAY['black_tide_rift','forgotten_city','sealed_abyss','sealed_garden','under_root']),
('forgotten_city',620,560,'underworld',ARRAY['black_tide_rift','burial_steps','crimson_mine','ember_village','sealed_abyss']),
('black_tide_rift',720,450,'underworld',ARRAY['burial_steps','ember_village','forgotten_city','lotus_marsh','red_forest','salt_village']),
('ember_village',700,555,'south',ARRAY['ash_coast','black_tide_rift','crimson_mine','forgotten_city','red_forest']),
('red_forest',790,505,'south',ARRAY['ash_coast','black_tide_rift','ember_village','lotus_marsh']),
('crimson_mine',725,635,'south',ARRAY['ash_coast','ember_village','forgotten_city','nine_lighthouse']),
('ash_coast',820,600,'south',ARRAY['crimson_mine','ember_village','nine_lighthouse','red_forest']),
('nine_lighthouse',890,665,'south',ARRAY['ash_coast','crimson_mine']),
('sealed_abyss',520,620,'abyss',ARRAY['burial_steps','forgotten_city','under_root'])),
t(terr, tname, fid, fname) AS (VALUES
('capital','야행국 직할령','night_office','야행국'),
('north','북령 맹약지','north_league','북령맹'),
('heavenward','천명 상계','mandate_court','천명원'),
('east','수향 연맹령','river_alliance','수향연맹'),
('frontier','적월 교령','red_moon_cult','적월교'),
('underworld','흑련 지하회랑','black_lotus','흑련회'),
('south','남명 망국령','southern_remnant','남명회'),
('abyss','구중 금역',NULL,'무주 금역'))
UPDATE public.world_map_regions r SET world_x = v.x, world_y = v.y, territory_id = v.terr, territory_name = t.tname,
  control_faction_id = t.fid, faction_control = t.fname, travel_from = v.links
FROM v JOIN t USING (terr) WHERE r.region_id = v.region_id;

-- 흑련회 본거지는 지하회랑의 암시장이다(기존과 같음). 금역은 어느 세력도 다스리지 않는다.

-- 세부 지역: 1단계는 지역 초입, 2단계는 지역마다 지은 권역 이름, 3~5단계는 지형 어휘 조합.
UPDATE public.world_exploration_nodes n SET node_name = r.region_name || ' 초입',
  description = '지역에 막 들어선 곳입니다. 탐색하면 안쪽 권역으로 이어지는 길을 찾을 수 있습니다.', min_level = r.min_level
FROM public.world_map_regions r WHERE n.region_id = r.region_id AND n.hierarchy_level = 1;

WITH z(region_id, a, b) AS (VALUES
('hq_yard','등롱 앞마당','북쪽 행랑채'),('hq_dorm','객사 안뜰','뒤뜰 우물가'),('lantern_market','등롱 골목','야시장 뒷길'),
('hq_training','팔괘 연무터','목인 훈련장'),('hq_archive','서고 계단참','봉인 서가'),('sealed_garden','시든 연못가','덩굴 회랑'),
('field_outskirts','갈대 둑길','버려진 초소'),('shrine_ruins','무너진 산문','사당 뒤 숲'),('paper_bridge','종이 난간','다리 밑 그늘'),
('old_canal','물길 어귀','아홉 갈래 수문'),('ghost_bamboo','대숲 어귀','울음 대밭'),('sunken_district','잠긴 장터','기울어진 기와골'),
('west_gate','허물어진 성루','성벽 아래 해자'),('ash_mountain','잿빛 등성이','화구 가장자리'),('frost_valley','얼음골 어귀','서리 동굴'),
('iron_monastery','산문 돌계단','종루 마당'),('sky_lake','거울 물가','구름 섬'),('jade_pass','비취 잔도','바람 협곡'),
('thunder_peak','벼락 바위','정상 제단'),('white_tower','탑 아래 회랑','별빛 계단'),('star_observatory','관측대 마당','혼천의 전각'),
('river_ferry','나루 선착장','물안개 둔치'),('salt_village','소금밭','염등 골목'),('lotus_marsh','연잎 습지','고인 물웅덩이'),
('mirror_pavilion','수경 누각','비치는 연못'),('sunken_palace','수궁 정문','산호 회랑'),('red_plain','붉은 모래언덕','마른 강바닥'),
('bone_market','뼈 좌판 거리','해골 천막촌'),('glass_canyon','유리 절벽','빛 갈라진 틈'),('black_sand_temple','검은 모래 마당','무너진 법당'),
('red_moon_fort','월식성 외벽','핏빛 망루'),('hidden_bazaar','숨은 문 앞','암거래 회랑'),('under_root','뿌리 터널','지맥 웅덩이'),
('burial_steps','무덤 계단','비석 숲'),('forgotten_city','이름 없는 성문','폐궁 거리'),('black_tide_rift','검은 물결 해안','균열 가장자리'),
('ember_village','잔불 마을 어귀','숯가마 골목'),('red_forest','핏빛 단풍길','피눈물 샘'),('crimson_mine','갱도 입구','붉은 광맥'),
('ash_coast','잿빛 모래톱','난파선 무덤'),('nine_lighthouse','등대 바위섬','안개 해협'),('sealed_abyss','봉인 계단','사슬 심연'))
UPDATE public.world_exploration_nodes n SET node_name = CASE WHEN n.sort_order <= 1 THEN z.a ELSE z.b END,
  description = '지역의 바깥 권역입니다. 탐색을 이어가면 더 안쪽 구역을 찾을 수 있습니다.', min_level = r.min_level
FROM z JOIN public.world_map_regions r USING (region_id)
WHERE n.region_id = z.region_id AND n.hierarchy_level = 2;

WITH ranked AS (
  SELECT n.node_id, n.hierarchy_level lv, v.adj, CASE n.hierarchy_level WHEN 3 THEN v.n3 WHEN 4 THEN v.n4 ELSE v.n5 END nouns,
    row_number() OVER (PARTITION BY t.theme, n.hierarchy_level ORDER BY md5(n.node_id::text)) - 1 k,
    count(*) OVER (PARTITION BY t.theme, n.hierarchy_level) cnt
  FROM public.world_exploration_nodes n JOIN public.world_region_theme t USING (region_id) JOIN public.world_name_vocab v USING (theme)
  WHERE n.hierarchy_level BETWEEN 3 AND 5),
s AS (SELECT *, (k * (cardinality(adj) * cardinality(nouns)) / cnt) kk FROM ranked)
UPDATE public.world_exploration_nodes n
SET node_name = s.adj[1 + (s.kk / cardinality(s.nouns)) % cardinality(s.adj)] || ' ' || s.nouns[1 + s.kk % cardinality(s.nouns)],
    description = CASE s.lv WHEN 3 THEN '권역 안쪽의 구역입니다. 요괴의 흔적이 짙어지고 채집터가 드러납니다.'
                            WHEN 4 THEN '깊숙한 곳입니다. 쓸 만한 채집터가 숨어 있지만 위험도 커집니다.'
                            ELSE '가장 깊은 지점입니다. 희귀한 자원과 강한 요괴가 함께 있습니다.' END
FROM s WHERE n.node_id = s.node_id;

UPDATE public.world_exploration_nodes n SET min_level = least(100, r.min_level + (n.hierarchy_level - 2) * 2)
FROM public.world_map_regions r WHERE n.region_id = r.region_id AND n.hierarchy_level >= 3;

ALTER TABLE public.world_gathering_spots DROP CONSTRAINT IF EXISTS world_gathering_spots_category_check;
UPDATE public.world_spot_vocab SET nouns = array_replace(nouns, '버려진 봇짐', '주인 잃은 봇짐') WHERE category = 'supplies';
UPDATE public.world_spot_vocab SET nouns = array_replace(nouns, '무너진 서가', '쓰러진 서가') WHERE category = 'relics';

-- 채집터: 지역마다 72곳을 권역(2)·구역(1)·구획(2)·지점(2) 순으로 다시 배치하고, 지형 주제에 맞는 분류와 자원을 준다.
CREATE TEMP TABLE tmp_item_cat(item_id text PRIMARY KEY, cat text) ON COMMIT DROP;
INSERT INTO tmp_item_cat VALUES
('tonic','supplies'),('travel_ration','supplies'),('ward_talisman','supplies'),
('seal_paper','relics'),('fine_paper','relics'),('inkstone','relics'),('sealing_ink','relics'),('talisman_thread','relics'),('rune_plate','relics'),('beast_bone','relics'),
('herb','herbs'),('herbal_extract','herbs'),('moon_moss','herbs'),('venom_gland','herbs'),('medicine_base','herbs'),
('river_reed','water'),('drowned_scale','water'),('silk','water'),
('ore','ore'),('raw_iron','ore'),('steel_ingot','ore'),('cinnabar','ore'),('jade_shard','ore'),('frost_salt','ore'),('thunder_ore','ore'),('iron_ingot','ore'),
('wood','wood'),('resin','wood'),('lumber','wood'),('spirit_bark','wood'),
('spirit_dust','spirit'),('ghost_ash','spirit'),('ward_fragment','spirit'),('spirit_glass','spirit'),('spirit_core','spirit'),('mirror_shard','spirit'),('star_sand','spirit');

CREATE TEMP TABLE tmp_spot_map ON COMMIT DROP AS
WITH slots AS (
  SELECT n.region_id, n.node_id, n.hierarchy_level lv,
    row_number() OVER (PARTITION BY n.region_id ORDER BY n.hierarchy_level, n.sort_order, n.node_id, g) rn
  FROM public.world_exploration_nodes n
  CROSS JOIN LATERAL generate_series(1, CASE n.hierarchy_level WHEN 2 THEN 2 WHEN 3 THEN 1 WHEN 4 THEN 2 WHEN 5 THEN 2 ELSE 0 END) g
  WHERE n.hierarchy_level >= 2),
sp AS (
  SELECT s.spot_id, n.region_id, row_number() OVER (PARTITION BY n.region_id ORDER BY s.spot_id) rn
  FROM public.world_gathering_spots s JOIN public.world_exploration_nodes n ON n.node_id = s.node_id)
SELECT sp.spot_id, slots.region_id, slots.node_id, slots.lv, t.theme,
  v.cats[1 + (slots.rn - 1) % cardinality(v.cats)] cat
FROM sp JOIN slots ON slots.region_id = sp.region_id AND slots.rn = sp.rn
JOIN public.world_region_theme t ON t.region_id = slots.region_id JOIN public.world_name_vocab v ON v.theme = t.theme;

WITH ranked AS (
  SELECT m.*, v.adj, sv.nouns,
    row_number() OVER (PARTITION BY m.theme, m.cat ORDER BY md5(m.spot_id::text)) - 1 k,
    count(*) OVER (PARTITION BY m.theme, m.cat) cnt
  FROM tmp_spot_map m JOIN public.world_name_vocab v ON v.theme = m.theme JOIN public.world_spot_vocab sv ON sv.category = m.cat),
s AS (SELECT *, (k * (cardinality(adj) * cardinality(nouns)) / cnt) kk FROM ranked),
base(cat, items) AS (VALUES
  ('herbs', ARRAY['herb','herb','medicine_base']), ('ore', ARRAY['ore','ore','raw_iron']), ('wood', ARRAY['wood','wood','resin']),
  ('water', ARRAY['river_reed','river_reed','drowned_scale']), ('spirit', ARRAY['spirit_dust','ghost_ash','ward_fragment']),
  ('relics', ARRAY['seal_paper','seal_paper','inkstone','talisman_thread']), ('supplies', ARRAY['herb','travel_ration','tonic']))
UPDATE public.world_gathering_spots g SET
  node_id = s.node_id, category = s.cat, active = true,
  spot_name = s.adj[1 + (s.kk / cardinality(s.nouns)) % cardinality(s.adj)] || ' ' || s.nouns[1 + s.kk % cardinality(s.nouns)],
  loot_items = b.items || coalesce((
    SELECT array_agg(x ORDER BY x) FROM unnest(p.signature_items) x JOIN tmp_item_cat ic ON ic.item_id = x JOIN public.world_item_catalog i ON i.item_id = x
    WHERE ic.cat = s.cat AND (i.tier <= 2 OR s.lv >= 4)), '{}'),
  min_level = n.min_level, yield_min = 1, yield_max = CASE WHEN s.lv >= 4 THEN 2 ELSE 1 END + CASE WHEN r.danger_level >= 7 THEN 1 ELSE 0 END,
  difficulty = r.danger_level + s.lv - 2
FROM s JOIN base b ON b.cat = s.cat
JOIN public.world_exploration_nodes n ON n.node_id = s.node_id
JOIN public.world_map_regions r ON r.region_id = s.region_id
LEFT JOIN public.world_region_profiles p ON p.region_id = s.region_id
WHERE g.spot_id = s.spot_id;

ALTER TABLE public.world_gathering_spots ADD CONSTRAINT world_gathering_spots_category_check
  CHECK (category IN ('herbs','ore','wood','water','spirit','relics','supplies'));
