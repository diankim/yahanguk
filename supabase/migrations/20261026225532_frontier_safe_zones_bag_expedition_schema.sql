-- 야행국 2차 라이브 테스트 반영 (서버)
-- 1) 안전지대: 요괴 수색·전투 불가, 상점·거래소·마구간은 안전지대에서만.
-- 2) 가방 용량: 기본 60칸, 사건 해결·지역 완전 답사·수향연맹 소속으로 확장. 교환(구매·제작) 시 초과하면 거절, 획득 시 초과분은 버리고 알림.
-- 3) 원정 개편: 지역마다 고유한 이름의 원정지(외곽·심부·핵심). 시간·태세·보급을 정해 보내면 지역 요괴와의 전투·채집·발견이
--    서버에서 계산되고, 지역 답사도가 올라 더 깊은 원정지가 열린다. 능력치·장비·직업·대세력에 따라 결과가 달라진다.
-- 4) 원정 중에는 이동·전투·채집·제작·거래 등 현장 행동을 할 수 없다.
-- 5) 캐릭터 프로필(문장·색·한 줄 소개), 같은 지역 조사원·파티 정보 조회(기존 함수는 RLS 때문에 다른 조사원이 보이지 않았음).
-- 클라이언트 테이블 권한·RLS는 완화하지 않는다. 새 테이블은 RLS를 켜고 클라이언트 권한을 주지 않는다(RPC로만 접근).

-- ── A. 스키마 ───────────────────────────────────────────
ALTER TABLE public.world_map_regions
  ADD COLUMN IF NOT EXISTS is_safe_zone boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS shop_id text,
  ADD COLUMN IF NOT EXISTS shop_name text,
  ADD COLUMN IF NOT EXISTS has_stable boolean NOT NULL DEFAULT false;

UPDATE public.world_map_regions AS r SET is_safe_zone = true, shop_id = v.shop_id, shop_name = v.shop_name, has_stable = v.stable
FROM (VALUES
  ('hq_yard', 'night_office_store', '야행국 보급소', true),
  ('hq_dorm', 'night_office_store', '객사 보급 창구', false),
  ('lantern_market', 'capital_market', '백등 야시장 좌판', false),
  ('river_ferry', 'river_market', '수향연맹 물자시장', true),
  ('bone_market', 'frontier_market', '백골 장터 흥정소', false),
  ('ember_village', 'south_market', '잔불촌 화롯가 장터', true),
  ('iron_monastery', 'north_market', '철벽 고찰 산문 보급고', false),
  ('hidden_bazaar', 'underworld_market', '십삼문 뒷거래상', false),
  ('star_observatory', 'astral_market', '관성대 천문 상회', true)
) AS v(region_id, shop_id, shop_name, stable)
WHERE r.region_id = v.region_id;

-- 새 안전지대 상점 품목 (기존 품목 데이터는 그대로 두고 추가만 한다)
INSERT INTO public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
SELECT v.shop_id, v.item_id, v.price, v.mn, v.mx
FROM (VALUES
  ('north_market','ore',22,3,10),('north_market','wood',15,3,10),('north_market','charcoal',20,2,8),('north_market','frost_salt',65,1,5),
  ('north_market','tonic',58,2,8),('north_market','ward_talisman',78,2,6),('north_market','travel_ration',45,3,10),('north_market','thunder_ore',260,1,3),
  ('north_market','beast_hide',65,1,5),('north_market','repair_kit',150,1,3),
  ('south_market','herb',12,3,10),('south_market','ore',22,2,8),('south_market','wood',15,2,8),('south_market','beast_bone',65,1,5),
  ('south_market','beast_fang',65,1,5),('south_market','ember_crystal',260,1,3),('south_market','travel_ration',42,3,10),('south_market','tonic',55,2,8),
  ('south_market','medicine_base',35,1,5),('south_market','resin',20,2,8),
  ('astral_market','spirit_dust',60,2,8),('astral_market','star_sand',250,1,4),('astral_market','jade_shard',250,1,4),('astral_market','fine_paper',60,2,6),
  ('astral_market','seal_paper',20,3,10),('astral_market','ward_talisman',72,2,8),('astral_market','tonic',55,2,8),('astral_market','cloud_cotton',65,1,5),
  ('astral_market','moon_moss',65,1,5),('astral_market','travel_ration',48,2,8),
  ('capital_market','travel_ration',45,2,8),('night_office_store','travel_ration',45,2,8),('frontier_market','travel_ration',45,2,8),
  ('night_office_store','herbal_extract',90,1,4),('night_office_store','revival_charm',420,1,2),('underworld_market','revival_charm',380,1,2)
) AS v(shop_id, item_id, price, mn, mx)
WHERE EXISTS (SELECT 1 FROM public.world_item_catalog i WHERE i.item_id = v.item_id)
ON CONFLICT DO NOTHING;

ALTER TABLE public.world_characters
  ADD COLUMN IF NOT EXISTS bag_capacity integer NOT NULL DEFAULT 60,
  ADD COLUMN IF NOT EXISTS profile jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.world_characters ALTER COLUMN location SET DEFAULT '야행국 본부 정청';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'world_characters_bag_capacity_range') THEN
    ALTER TABLE public.world_characters ADD CONSTRAINT world_characters_bag_capacity_range CHECK (bag_capacity BETWEEN 20 AND 400);
  END IF;
END $$;

ALTER TABLE public.world_mount_catalog ADD COLUMN IF NOT EXISTS acquire_method text NOT NULL DEFAULT 'stable';
UPDATE public.world_mount_catalog SET unlock_region = 'hq_yard' WHERE mount_id = 'pack_mule' AND unlock_region IS NULL;
INSERT INTO public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, unlock_faction, unlock_region, unlock_item, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method)
VALUES
  ('seal_haetae', '홍인 해태', 1.6, 1, 0, NULL, NULL, NULL, 0, '붉은 인장 사건을 끝까지 해결한 조사원을 따르는 작은 해태. 운임 없이 둘을 태운다.', '영물', 2, 0, true, 'event'),
  ('mist_deer', '안개 사슴', 2.2, 1, 0, NULL, NULL, NULL, 0, '다섯 지역을 완전히 답사한 조사원 앞에 나타나는 안개 사슴. 길을 잃지 않는다.', '영물', 2, 1, false, 'event')
ON CONFLICT (mount_id) DO NOTHING;

-- 원정지: 지역마다 외곽(1)·심부(2)·핵심(3). 이름은 전 세계에서 중복되지 않는다.
CREATE TABLE IF NOT EXISTS public.world_expedition_grounds (
  ground_id text PRIMARY KEY,
  region_id text NOT NULL REFERENCES public.world_map_regions(region_id),
  ground_name text NOT NULL UNIQUE,
  depth smallint NOT NULL CHECK (depth BETWEEN 1 AND 3),
  description text NOT NULL,
  min_level integer NOT NULL DEFAULT 1,
  unlock_progress integer NOT NULL DEFAULT 0,
  danger integer NOT NULL DEFAULT 1,
  UNIQUE (region_id, depth)
);
CREATE TABLE IF NOT EXISTS public.world_region_progress (
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  region_id text NOT NULL REFERENCES public.world_map_regions(region_id),
  progress integer NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
  expeditions integer NOT NULL DEFAULT 0,
  milestones text[] NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (owner_id, region_id)
);
CREATE TABLE IF NOT EXISTS public.world_expeditions (
  expedition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ground_id text NOT NULL REFERENCES public.world_expedition_grounds(ground_id),
  region_id text NOT NULL,
  minutes integer NOT NULL CHECK (minutes IN (30, 60, 120, 240, 480)),
  stance text NOT NULL CHECK (stance IN ('cautious', 'balanced', 'bold')),
  supplies jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'done')),
  result jsonb,
  finished_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS world_expeditions_one_active ON public.world_expeditions(owner_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS world_expeditions_owner_recent ON public.world_expeditions(owner_id, started_at DESC);

ALTER TABLE public.world_expedition_grounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_region_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_expeditions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.world_expedition_grounds, public.world_region_progress, public.world_expeditions FROM anon, authenticated, PUBLIC;

INSERT INTO public.world_expedition_grounds(ground_id, region_id, ground_name, depth, description)
VALUES
 ('field_outskirts_1','field_outskirts','비젖은 돌길',1,'순찰조가 매일 밤 걷는 돌길. 빗물 고인 틈마다 작은 요기가 숨어 있다.'),
 ('field_outskirts_2','field_outskirts','무너진 순찰초소',2,'지붕이 내려앉은 초소. 마지막 순찰 일지가 아직 책상 위에 펼쳐져 있다.'),
 ('field_outskirts_3','field_outskirts','버려진 약초밭',3,'관리인이 사라진 약초밭. 밤마다 누군가 이랑을 새로 갈아 놓는다.'),
 ('hq_training_1','hq_training','목인형 마당',1,'수련생들이 두드린 목인형이 한밤에는 스스로 자세를 바꾼다.'),
 ('hq_training_2','hq_training','팔괘 미로',2,'팔괘진의 방위가 시간마다 뒤바뀌는 수련용 미로.'),
 ('hq_training_3','hq_training','봉인 잔향실',3,'모의 요괴를 만들던 방. 지워지지 않은 봉인의 잔향이 형체를 이룬다.'),
 ('shrine_ruins_1','shrine_ruins','금줄 늘어진 참배로',1,'끊어진 금줄이 바람도 없이 흔들리는 참배로.'),
 ('shrine_ruins_2','shrine_ruins','방울 우는 회랑',2,'청동 방울이 벽 너머에서 울리는 좁은 회랑.'),
 ('shrine_ruins_3','shrine_ruins','봉인 틈 본전',3,'봉인이 갈라진 본전. 틈 사이로 요기가 끊임없이 새어 나온다.'),
 ('hq_archive_1','hq_archive','먹내 나는 열람실',1,'젖은 먹 냄새가 가시지 않는 열람실. 책장이 저절로 넘어간다.'),
 ('hq_archive_2','hq_archive','압수 문서 창고',2,'사교 문서를 쌓아 둔 창고. 금서들이 서로 속삭인다.'),
 ('hq_archive_3','hq_archive','이름 잃은 죽간고',3,'이름이 지워진 죽간이 잠든 가장 깊은 서고.'),
 ('paper_bridge_1','paper_bridge','소원지 난간',1,'소원을 적은 종이가 난간마다 매달려 바스락거린다.'),
 ('paper_bridge_2','paper_bridge','다리 밑 종이 둥지',2,'떨어진 소원지가 모여 만든 둥지. 그 안에서 무언가 자란다.'),
 ('paper_bridge_3','paper_bridge','이름 먹는 교각',3,'사람 이름을 먹고 자란 교각. 가까이 가면 자기 이름이 흐려진다.'),
 ('old_canal_1','old_canal','용문 수문',1,'용 문양이 새겨진 녹슨 수문. 물이 거꾸로 흐르는 밤이 있다.'),
 ('old_canal_2','old_canal','이끼 낀 배수 통로',2,'허리를 숙여야 지나는 통로. 물비늘이 발목을 스친다.'),
 ('old_canal_3','old_canal','물비늘 저수조',3,'운하의 물이 모이는 거대한 저수조. 수귀들이 배 밑을 두드린다.'),
 ('sealed_garden_1','sealed_garden','시든 연꽃 회랑',1,'시든 연꽃이 늘어선 회랑. 꽃잎마다 낯선 얼굴이 비친다.'),
 ('sealed_garden_2','sealed_garden','얼굴 비추는 연못',2,'들여다보면 내가 아닌 얼굴이 웃는 연못.'),
 ('sealed_garden_3','sealed_garden','폐원 별채',3,'정원의 주인이 머물던 별채. 문이 안쪽에서 잠겨 있다.'),
 ('ghost_bamboo_1','ghost_bamboo','속삭이는 대숲길',1,'대나무가 서로 부딪히며 지나간 사람의 목소리를 흉내 낸다.'),
 ('ghost_bamboo_2','ghost_bamboo','부러진 죽순 골짜기',2,'죽순이 칼날처럼 꺾여 있는 골짜기.'),
 ('ghost_bamboo_3','ghost_bamboo','목소리의 샘',3,'숲의 모든 목소리가 흘러드는 샘. 오래 들으면 대답하고 싶어진다.'),
 ('sunken_district_1','sunken_district','잠긴 지붕길',1,'물 위로 드러난 지붕을 밟고 건너는 길.'),
 ('sunken_district_2','sunken_district','기울어진 사당가',2,'기울어진 사당들이 줄지은 거리. 종이 물속에서 울린다.'),
 ('sunken_district_3','sunken_district','수괴의 둥지',3,'침수 장군이 부하를 거느리고 머무는 옛 관아.'),
 ('salt_village_1','salt_village','소금 바른 골목',1,'집집마다 문지방에 소금을 발라 둔 골목.'),
 ('salt_village_2','salt_village','이름 없는 우물',2,'마을 사람들이 이름을 버린다는 우물.'),
 ('salt_village_3','salt_village','봉해진 촌장댁',3,'문과 창을 소금으로 봉한 촌장의 집. 안에서 누군가 이름을 부른다.'),
 ('lotus_marsh_1','lotus_marsh','발목 잡는 갈대밭',1,'갈대 사이로 연꽃 줄기가 뻗어 발목을 잡는다.'),
 ('lotus_marsh_2','lotus_marsh','숨 쉬는 진흙못',2,'진흙 아래에서 거대한 숨소리가 올라오는 못.'),
 ('lotus_marsh_3','lotus_marsh','천엽 연꽃 심처',3,'천 장의 꽃잎을 가진 연꽃이 피는 늪의 중심.'),
 ('mirror_pavilion_1','mirror_pavilion','물안개 다리',1,'누각으로 이어지는 다리. 안개 속에서 발소리가 하나 더 들린다.'),
 ('mirror_pavilion_2','mirror_pavilion','계절 거울 복도',2,'거울마다 다른 계절이 비치는 복도.'),
 ('mirror_pavilion_3','mirror_pavilion','무희의 무대',3,'수경무희가 끝나지 않는 춤을 추는 무대.'),
 ('sunken_palace_1','sunken_palace','산호 문루',1,'산호가 뒤덮은 수궁의 문루.'),
 ('sunken_palace_2','sunken_palace','물의 법정',2,'물의 법도로 죄를 가리는 법정. 숨 쉬는 방식이 바뀐다.'),
 ('sunken_palace_3','sunken_palace','용왕의 침전',3,'용왕이 잠들었다는 침전. 보물과 함정이 함께 잠겨 있다.'),
 ('black_tide_rift_1','black_tide_rift','검은 물결 기슭',1,'균열에서 흘러나온 검은 물결이 닿는 기슭.'),
 ('black_tide_rift_2','black_tide_rift','거꾸로 선 별자리',2,'지도에 없는 별자리가 거꾸로 떠 있는 하늘 아래.'),
 ('black_tide_rift_3','black_tide_rift','역천의 문',3,'다른 하늘로 이어지는 균열의 중심.'),
 ('west_gate_1','west_gate','부적 덧붙은 성벽길',1,'성벽 틈마다 부적이 겹겹이 붙은 길.'),
 ('west_gate_2','west_gate','통행세 망루',2,'밤마다 정체 모를 문지기가 통행세를 받는 망루.'),
 ('west_gate_3','west_gate','무너진 옹성',3,'반쯤 무너진 옹성. 옛 수비대의 망령이 아직 성문을 지킨다.'),
 ('red_plain_1','red_plain','유리 모래언덕',1,'붉은 모래가 유리처럼 굳은 언덕.'),
 ('red_plain_2','red_plain','환영의 오아시스',2,'다가갈수록 멀어지는 오아시스.'),
 ('red_plain_3','red_plain','붉은 모래 폭풍의 눈',3,'모래 폭풍 한가운데의 고요한 땅. 사막귀들이 모여든다.'),
 ('glass_canyon_1','glass_canyon','바람 깎인 협곡 입구',1,'바람에 깎인 유리 절벽이 시작되는 곳.'),
 ('glass_canyon_2','glass_canyon','반사 절벽',2,'절벽에 비친 자신이 먼저 움직이는 구간.'),
 ('glass_canyon_3','glass_canyon','쌍생의 거울굴',3,'경면쌍생이 태어나는 거울 동굴.'),
 ('black_sand_temple_1','black_sand_temple','검은 모래 계단',1,'제단으로 오르는 계단. 모래가 발자국을 기억한다.'),
 ('black_sand_temple_2','black_sand_temple','피를 기억하는 제단',2,'사교가 버리고 간 제단. 검은 모래가 피 냄새를 품고 있다.'),
 ('black_sand_temple_3','black_sand_temple','주술승의 지하 법당',3,'흑사 주술승들이 의식을 이어 가는 지하 법당.'),
 ('red_moon_fort_1','red_moon_fort','월식성 외벽',1,'추적자가 순찰하는 적월교 요새의 외벽.'),
 ('red_moon_fort_2','red_moon_fort','혈위 연병장',2,'적월 혈위들이 주술 병기를 시험하는 연병장.'),
 ('red_moon_fort_3','red_moon_fort','붉은 달 제단',3,'월식 때마다 붉은 달을 부르는 요새의 심장.'),
 ('white_tower_1','white_tower','매달린 계단',1,'하늘과 땅 사이에 매달린 탑의 계단.'),
 ('white_tower_2','white_tower','느리게 흐르는 층',2,'시간이 느리게 흐르는 층. 한 걸음이 한나절이다.'),
 ('white_tower_3','white_tower','천문식자의 서고',3,'별의 문자를 먹는 천문식자가 머무는 서고.'),
 ('ash_mountain_1','ash_mountain','재 내리는 산길',1,'재가 눈처럼 내리는 산길.'),
 ('ash_mountain_2','ash_mountain','화산석 협곡',2,'달궈진 화산석 사이로 불귀가 오가는 협곡.'),
 ('ash_mountain_3','ash_mountain','불귀의 분화구',3,'불귀들이 태어나는 분화구의 가장자리.'),
 ('jade_pass_1','jade_pass','옛 관도 초입',1,'절벽 사이로 난 옛 관도의 시작.'),
 ('jade_pass_2','jade_pass','호송대 실종 지점',2,'호송대가 사라진 굽잇길. 짐수레 바퀴 자국만 남았다.'),
 ('jade_pass_3','jade_pass','푸른 등불 고개',3,'청등 호송귀가 등불을 들고 길손을 부르는 고개.'),
 ('frost_valley_1','frost_valley','얼음 종루',1,'얼어붙은 종이 저절로 울리는 종루.'),
 ('frost_valley_2','frost_valley','갇힌 혼의 빙하',2,'얼음 아래 갇힌 영혼들이 비치는 빙하.'),
 ('frost_valley_3','frost_valley','빙혼 장수의 무덤',3,'빙혼 장수가 잠들지 못하는 얼음 무덤.'),
 ('sky_lake_1','sky_lake','거꾸로 비친 물가',1,'하늘이 거꾸로 비치는 호숫가.'),
 ('sky_lake_2','sky_lake','별 가라앉은 여울',2,'물속에 별이 가라앉아 반짝이는 여울.'),
 ('sky_lake_3','sky_lake','천경 호심',3,'사람을 끌어당기는 호수의 한가운데.'),
 ('thunder_peak_1','thunder_peak','번개 맞은 능선',1,'번개에 그을린 바위가 늘어선 능선.'),
 ('thunder_peak_2','thunder_peak','바위 던지는 비탈',2,'산귀가 바위를 굴려 보내는 가파른 비탈.'),
 ('thunder_peak_3','thunder_peak','뇌각 산군의 정상',3,'번개를 먹은 산군이 군림하는 봉우리 끝.'),
 ('burial_steps_1','burial_steps','묘비 계단 아랫단',1,'산을 오르는 묘비 계단의 첫머리.'),
 ('burial_steps_2','burial_steps','이름 없는 병사의 무덤길',2,'이름 없는 병사들이 일어나 행군하는 무덤길.'),
 ('burial_steps_3','burial_steps','만인 행군로',3,'만 명의 망령이 끝없이 행군하는 산정의 길.'),
 ('ash_coast_1','ash_coast','재 섞인 모래톱',1,'검은 재와 모래가 뒤섞인 모래톱.'),
 ('ash_coast_2','ash_coast','난파선 무덤',2,'난파선들이 겹겹이 쌓인 해안.'),
 ('ash_coast_3','ash_coast','종이 물고기 동굴',3,'종이 물고기가 헤엄치는 해식 동굴.'),
 ('red_forest_1','red_forest','붉은 수액 숲길',1,'나무껍질에서 붉은 수액이 흐르는 숲길.'),
 ('red_forest_2','red_forest','심장 박동 잎그늘',2,'잎이 심장 박동처럼 접혔다 펴지는 그늘.'),
 ('red_forest_3','red_forest','혈엽수인의 뿌리터',3,'혈엽수인이 뿌리를 내린 숲의 심부.'),
 ('crimson_mine_1','crimson_mine','붉은 광맥 입갱',1,'붉은 광맥이 드러난 갱도 입구.'),
 ('crimson_mine_2','crimson_mine','대답하는 갱도',2,'곡괭이 소리에 무언가 대답하는 갱도.'),
 ('crimson_mine_3','crimson_mine','맥동하는 광심',3,'광맥이 심장처럼 뛰는 광산의 중심.'),
 ('nine_lighthouse_1','nine_lighthouse','가짜 등대섬',1,'죽은 배를 부르는 가짜 등대가 선 섬.'),
 ('nine_lighthouse_2','nine_lighthouse','죽은 배의 정박지',2,'유령선들이 닻을 내린 정박지.'),
 ('nine_lighthouse_3','nine_lighthouse','진짜 등대',3,'아홉 등대 가운데 유일하게 진짜 바다를 비추는 등대.'),
 ('forgotten_city_1','forgotten_city','지워진 성문',1,'지도에서 지워진 옛 수도의 성문.'),
 ('forgotten_city_2','forgotten_city','기억 잃는 대로',2,'걸을수록 기억 하나를 잃는 대로.'),
 ('forgotten_city_3','forgotten_city','무명 황제의 궁',3,'이름을 잃은 황제가 다스리는 궁.'),
 ('under_root_1','under_root','뿌리 갈래 통로',1,'영맥의 뿌리가 갈라지는 지하 통로.'),
 ('under_root_2','under_root','환청의 동공',2,'자신의 과거가 환청으로 들리는 동굴.'),
 ('under_root_3','under_root','영맥의 심장',3,'도시 아래 잠든 영맥의 심장부.'),
 ('sealed_abyss_1','sealed_abyss','봉연 경계선',1,'금단 구역을 둘러싼 봉인의 경계.'),
 ('sealed_abyss_2','sealed_abyss','실패한 봉인진',2,'봉인에 실패한 진법이 일그러진 채 남은 곳.'),
 ('sealed_abyss_3','sealed_abyss','봉주의 잠자리',3,'구중 봉주가 잠들어 있다는 봉연의 바닥.')
ON CONFLICT (ground_id) DO NOTHING;

UPDATE public.world_expedition_grounds g
SET min_level = r.min_level + (g.depth - 1) * 2,
    unlock_progress = CASE g.depth WHEN 1 THEN 0 WHEN 2 THEN 30 ELSE 70 END,
    danger = LEAST(12, r.danger_level + g.depth - 1)
FROM public.world_map_regions r WHERE r.region_id = g.region_id;

