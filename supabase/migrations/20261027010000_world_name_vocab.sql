-- 세부 지역·채집터 이름 생성용 어휘. 지역마다 지형 주제를 정하고, 주제별 형용사×명사 조합을 겹치지 않게 배정한다.
CREATE TABLE public.world_region_theme (region_id text PRIMARY KEY REFERENCES public.world_map_regions(region_id), theme text NOT NULL);
CREATE TABLE public.world_name_vocab (theme text PRIMARY KEY, adj text[] NOT NULL, n3 text[] NOT NULL, n4 text[] NOT NULL, n5 text[] NOT NULL, cats text[] NOT NULL);
CREATE TABLE public.world_spot_vocab (category text PRIMARY KEY, nouns text[] NOT NULL);
ALTER TABLE public.world_region_theme ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_name_vocab ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_spot_vocab ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.world_region_theme, public.world_name_vocab, public.world_spot_vocab FROM anon, authenticated;
INSERT INTO public.world_region_theme(region_id, theme) VALUES
 ('hq_yard','city'),('hq_dorm','city'),('lantern_market','city'),('hq_training','city'),('hq_archive','city'),('paper_bridge','city'),('west_gate','city'),('bone_market','city'),('hidden_bazaar','city'),('sunken_district','city'),('old_canal','city'),
 ('sealed_garden','wild'),('field_outskirts','wild'),('ghost_bamboo','wild'),('red_forest','wild'),('ember_village','wild'),
 ('shrine_ruins','shrine'),('black_sand_temple','shrine'),('iron_monastery','shrine'),('red_moon_fort','shrine'),('burial_steps','shrine'),
 ('river_ferry','water'),('salt_village','water'),('lotus_marsh','water'),('mirror_pavilion','water'),('sunken_palace','water'),('ash_coast','water'),('nine_lighthouse','water'),
 ('ash_mountain','mountain'),('frost_valley','mountain'),('sky_lake','mountain'),('jade_pass','mountain'),('thunder_peak','mountain'),
 ('red_plain','desert'),('glass_canyon','desert'),
 ('under_root','deep'),('sealed_abyss','deep'),('crimson_mine','deep'),('forgotten_city','deep'),('black_tide_rift','deep'),
 ('white_tower','sky'),('star_observatory','sky');
INSERT INTO public.world_name_vocab(theme, adj, n3, n4, n5, cats) VALUES
 ('city', ARRAY['낡은','그을린','등불 꺼진','비에 젖은','잠긴','버려진','쥐 드나드는','먹물 번진','기울어진','무너진','좁은','숨겨진','이끼 낀','오래된'],
   ARRAY['골목','행랑','담장길','뒷마당','장터','사랑채','창고가','우물터'],
   ARRAY['처마 밑','다락','지하 창고','문간','계단참','담벼락','마구간 터','빨래터','솟을대문','쪽문'],
   ARRAY['장독대','우물','아궁이','쌀뒤주','등롱 걸이','부적 판자','깨진 항아리','문서 궤짝','수레 자국','벽감','신발장','굴뚝','기와 더미','빈 점포','찻집 자리','약방 터','대장간 터','서당 터','사당 감실','하수 구멍'],
   ARRAY['relics','supplies','herbs','wood','ore','spirit']),
 ('wild', ARRAY['안개 낀','이슬 맺힌','바람 우는','그늘진','덤불 우거진','시든','낙엽 쌓인','반딧불 도는','짐승 발자국 난','가시 돋친','고요한','흐릿한'],
   ARRAY['숲길','들판','산비탈','개울가','덤불숲','오솔길'],
   ARRAY['고목 그늘','바위 틈','쓰러진 나무','덩굴 터널','갈대밭','버섯 군락지','옛 무덤가','사냥꾼 움막'],
   ARRAY['여우 굴','벌집 고목','이끼 바위','샘물 구멍','새 둥지 나무','산딸기 덤불','돌무더기','뿌리 동굴','도깨비불 웅덩이','쓰러진 장승','덫 자리','약초 비탈'],
   ARRAY['herbs','wood','herbs','wood','spirit','supplies','ore']),
 ('shrine', ARRAY['향 꺼진','금 간','피 묻은','부적 붙은','먼지 쌓인','촛농 흐른','종소리 남은','경문 새겨진','허물어진','봉인된','어두운','서늘한'],
   ARRAY['법당','승방 회랑','승방','탑원','제단 마당','종루'],
   ARRAY['불단','향로 앞','계단 아래','벽화 앞','경판고','공양간','비석 곁','지하 묘실'],
   ARRAY['목탁','촛대','향합','경전 궤','부서진 불상','공양 그릇','염주 더미','위패','풍경','제기','탁본 벽','사리함 자리'],
   ARRAY['relics','spirit','relics','spirit','herbs','supplies','wood']),
 ('water', ARRAY['물안개 낀','소금기 어린','이끼 덮인','물에 잠긴','갈매기 우는','썩은 물 고인','달빛 비친','거품 이는','푸른','탁한','얼어붙은','잔잔한'],
   ARRAY['물가','갯벌','나루','수로','모래톱','섬'],
   ARRAY['선착장','그물 건조대','수초 밭','바위 웅덩이','난파선 잔해','물레방아 터','갈대 섬','수문'],
   ARRAY['조개 무덤','낚시터','배 밑창','물풀 군락','거북 바위','통발 자리','소금 웅덩이','물속 계단','부서진 노','산호 틈','진주 바위','물귀신 웅덩이','뱃사공 움막','해초 더미'],
   ARRAY['water','water','herbs','spirit','supplies','wood','relics']),
 ('mountain', ARRAY['눈 덮인','서리 내린','바람 거센','깎아지른','구름 걸린','얼음 맺힌','돌 굴러내린','매 우는','가파른','메마른','번개 맞은','적막한'],
   ARRAY['능선','고개','계곡','너덜길','산등성','협곡'],
   ARRAY['동굴 입구','낭떠러지','돌탑','산장 터','얼음 폭포','잔도','바위 선반','광맥 노두'],
   ARRAY['매 둥지','얼음 틈','돌 제단','약초 바위','무너진 돌다리','수정 동굴','곰 굴','온천 구멍','산신 바위','눈사태 자리','깃발 기둥','갈라진 바위틈'],
   ARRAY['ore','ore','herbs','wood','spirit','supplies']),
 ('desert', ARRAY['모래 날리는','붉게 달아오른','유리 조각 박힌','바싹 마른','해골 구르는','신기루 어린','쩍 갈라진','뜨거운'],
   ARRAY['모래언덕','바위 협곡','마른 강','황무지'],
   ARRAY['오아시스 터','유리 기둥','모래 폭포','낙타 뼈 무덤'],
   ARRAY['전갈 굴','모래 우물','유리 꽃밭','부서진 마차','바람 동굴','붉은 바위'],
   ARRAY['ore','ore','spirit','relics','supplies','herbs']),
 ('deep', ARRAY['어둠 짙은','축축한','메아리 울리는','사슬 늘어진','핏빛 감도는','숨 막히는','뿌리 엉킨','무너져 내린','빛 바랜','검게 그을린','차디찬','기분 나쁜'],
   ARRAY['갱도','지하 광장','동굴','폐허 거리','균열','굴길'],
   ARRAY['지하 호수','뼈 무더기','광부 쉼터','무너진 궁문','사슬 다리','석상 회랑','지맥 고인 못','독기 늪'],
   ARRAY['광석 벽','유골 감실','녹슨 수레','버섯 숲','박쥐 굴','수정 맥','사슬 기둥','봉인 석판','피 웅덩이','지하수 샘','부서진 관','이끼 등불'],
   ARRAY['ore','spirit','ore','spirit','relics','supplies']),
 ('sky', ARRAY['별빛 흐르는','구름 위','새하얀','적요한','찬 빛 도는','천문 새겨진','바람 맑은','은하 비친'],
   ARRAY['천문 회랑','관측 마당','하늘 계단','누각'],
   ARRAY['혼천의 앞','별자리 벽','구름 다리','천문 서고'],
   ARRAY['별 지도 석판','해시계','물시계','망원 거울','성좌 제단','천문 궤짝'],
   ARRAY['spirit','relics','ore','spirit','relics','supplies']);
INSERT INTO public.world_spot_vocab(category, nouns) VALUES
 ('herbs', ARRAY['야령초 군락','약초 둔덕','이슬풀 무리','쑥대밭','버섯 무리','산삼 그늘','독초 덤불','꽃무리','덩굴 약초','뿌리 덤불','약쑥 밭','감초 언덕','이끼 융단']),
 ('ore', ARRAY['월철 노두','광석 무더기','녹슨 철맥','돌 부스러기 더미','주사 얼룩 바위','비취 맥','은빛 광맥','검은 돌무지','수정 박힌 벽','철광 웅덩이','광부가 버린 더미','쇳돌 비탈','붉은 흙벽']),
 ('wood', ARRAY['쓰러진 고목','부적목 그루터기','송진 흐르는 나무','장작 더미','말라 죽은 숲','대나무 무리','옹이 박힌 통나무','뿌리 뽑힌 나무','버드나무 그늘','가시나무 덤불','썩은 목재 더미','껍질 벗겨진 기둥','잔가지 무덤']),
 ('water', ARRAY['갈대 물가','비늘 밀려온 모래','조개 더미','수초 웅덩이','물비린내 바위','그물 걸린 말뚝','물풀 덤불','거품 고인 웅덩이','물고기 뼈 더미','갯바위','진흙 둔덕','개구리 우는 웅덩이','안개 갈대섬']),
 ('spirit', ARRAY['요기 맺힌 돌','원령재 쌓인 터','결계 파편 무더기','영유리 조각밭','도깨비불 고인 곳','영맥 샘','한기 서린 구멍','귀기 어린 석상','기도 흔적','부서진 결계석','푸른 불꽃 자리','속삭이는 바위','혼백 웅덩이']),
 ('relics', ARRAY['먹물 번진 상자','찢긴 황지 묶음','버려진 벼루','봉인 먹 항아리','부적실 꾸러미','낡은 경서 더미','각인 석판','깨진 거울','녹슨 법구','무너진 서가','인장 상자','옛 지도 조각','장부 궤짝']),
 ('supplies', ARRAY['버려진 봇짐','보급 상자','야영 흔적','약 상자','건량 자루','숨겨둔 꾸러미','상인 수레','부적 상자','구급 주머니','화로 자리','순찰대 은닉처','짐말 안장','행상 좌판']);
