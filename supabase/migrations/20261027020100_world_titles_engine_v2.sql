-- 칭호 100개(공개 50·숨김 50), 대표 칭호, 채팅 칭호 표시, 날씨·내구도를 반영한 탐색·채집·전투, 완전 답사 가방 +1
-- 함수 전용 역할(fn_owner_field) 소유 함수는 SET ROLE로 고친다. 클라이언트에는 RPC만 연다.

-- ── 칭호 목록 ───────────────────────────────────────────
ALTER TABLE public.world_title_catalog ADD COLUMN IF NOT EXISTS hidden boolean NOT NULL DEFAULT false;
ALTER TABLE public.world_title_catalog ADD COLUMN IF NOT EXISTS rule jsonb;
ALTER TABLE public.world_title_catalog ADD COLUMN IF NOT EXISTS sort int NOT NULL DEFAULT 0;
ALTER TABLE public.world_title_catalog ADD COLUMN IF NOT EXISTS category text;
-- 숨김 칭호의 조건이 화면 밖으로 새지 않게 목록은 함수로만 읽는다.
REVOKE ALL ON public.world_title_catalog FROM anon, authenticated;
GRANT INSERT ON public.world_character_titles TO fn_owner_field;
GRANT SELECT ON public.world_owned_mounts TO fn_owner_field;

INSERT INTO public.world_title_catalog(title_key,title_name,icon,description,condition_text,bonus,active,hidden,rule,sort,category) VALUES
('first_footsteps','첫 야행','search','처음으로 밤길에 나선 조사원.','탐색 1회','{"gather_qty_pct": 1, "travel_time_pct": -2}'::jsonb,true,false,'{"ev": "explore"}'::jsonb,1,'탐사'),
('hundred_li','백 리 행보','route','발이 닳도록 고을을 오갔다.','이동 20회','{"rare_loot_pct": 2, "travel_time_pct": -5}'::jsonb,true,false,'{"ev": "travel", "n": 20}'::jsonb,2,'이동'),
('monster_slayer','요괴 토벌자','sword','요괴 열을 쓰러뜨린 조사원.','요괴 10마리 토벌','{"combat_damage_pct": 3, "incoming_damage_pct": -2}'::jsonb,true,false,'{"ev": "combat", "n": 10}'::jsonb,3,'전투'),
('case_reader','사건 판독자','scroll','흩어진 흔적에서 실마리를 읽어 낸다.','탐색 중 단서 5개 발견','{"rare_loot_pct": 2, "clue_bonus_pct": 5}'::jsonb,true,false,'{"ev": "explore", "p": {"outcome": "clue"}, "n": 5}'::jsonb,4,'이야기'),
('master_gatherer','산야의 눈','leaf','풀 한 포기도 놓치지 않는다.','채집 30회','{"rare_loot_pct": 2, "gather_qty_pct": 5}'::jsonb,true,false,'{"ev": "gather", "n": 30}'::jsonb,5,'채집'),
('artisan_apprentice','솜씨 입문','hammer','손에 익기 시작한 제작자.','제작 10회','{"craft_quality": 3}'::jsonb,true,false,'{"ev": "craft", "n": 10}'::jsonb,6,'제작'),
('artisan_master','백련 장인','hammer','백 번을 두드려 하나를 만드는 장인.','제작 50회','{"craft_quality": 7, "gather_qty_pct": 2}'::jsonb,true,false,'{"ev": "craft", "n": 50}'::jsonb,7,'제작'),
('regional_surveyor','사방 답사자','search','숨은 길을 차례로 찾아냈다.','숨은 장소 10곳 발견','{"clue_bonus_pct": 8, "travel_time_pct": -3}'::jsonb,true,false,'{"nodes": 10}'::jsonb,8,'탐사'),
('well_traveled','길에 밝은 자','route','열 고을의 길을 안다.','서로 다른 지역 10곳 방문','{"travel_time_pct": -8}'::jsonb,true,false,'{"distinct": "travel", "key": "region_id", "n": 10}'::jsonb,9,'이동'),
('steady_mind','흔들림 없는 마음','spark','쉬어 갈 때를 알아 마음이 고요하다.','휴식 5번','{"clue_bonus_pct": 5}'::jsonb,true,false,'{"ev": "rest", "n": 5}'::jsonb,10,'성장'),
('spirit_guard','사기 퇴치자','sword','정화 부적을 아끼지 않는다.','정화 부적 10번 사용','{"incoming_damage_pct": -3, "magic_pct": 3}'::jsonb,true,false,'{"ev": "use_item", "p": {"item_id": "ward_talisman"}, "n": 10}'::jsonb,11,'전투'),
('all_rounder','다재다능','spark','싸움도 손재주도 고루 갖췄다.','토벌·채집·제작 각 5회, 단서 5개','{"craft_quality": 2, "clue_bonus_pct": 3, "gather_qty_pct": 2, "combat_damage_pct": 2}'::jsonb,true,false,'{"all": [{"ev": "combat", "n": 5}, {"ev": "gather", "n": 5}, {"ev": "craft", "n": 5}, {"ev": "explore", "p": {"outcome": "clue"}, "n": 5}]}'::jsonb,12,'성장'),
('slayer_50','백귀 토벌','sword','쉰의 요괴가 이 손에 쓰러졌다.','요괴 50마리 토벌','{"combat_damage_pct": 3}'::jsonb,true,false,'{"ev": "combat", "n": 50}'::jsonb,13,'전투'),
('slayer_200','요괴 사냥꾼','sword','요괴들 사이에 이름이 돈다.','요괴 200마리 토벌','{"combat_damage_pct": 4, "rare_loot_pct": 1}'::jsonb,true,false,'{"ev": "combat", "n": 200}'::jsonb,14,'전투'),
('slayer_500','천귀 퇴치','sword','오백의 요괴를 물리친 전설의 손.','요괴 500마리 토벌','{"combat_damage_pct": 5, "incoming_damage_pct": -2}'::jsonb,true,false,'{"ev": "combat", "n": 500}'::jsonb,15,'전투'),
('elite_hunter','정예 사냥','sword','살기 짙은 정예를 꺾었다.','정예 요괴 5마리 토벌','{"combat_damage_pct": 3}'::jsonb,true,false,'{"ev": "combat", "p": {"rank": "elite"}, "n": 5}'::jsonb,16,'전투'),
('guardian_breaker','우두머리 격파','sword','지역의 우두머리를 무너뜨렸다.','우두머리 1마리 토벌','{"combat_damage_pct": 3, "incoming_damage_pct": -2}'::jsonb,true,false,'{"ev": "combat", "p": {"rank": "guardian"}}'::jsonb,17,'전투'),
('blade_path','검의 길','sword','칼과 창으로 길을 연다.','근접 무기로 50마리 토벌','{"melee_pct": 5}'::jsonb,true,false,'{"ev": "combat", "p": {"action": "attack"}, "n": 50}'::jsonb,18,'전투'),
('bow_path','활의 길','sword','시위 소리 한 번에 하나씩.','원거리 무기로 50마리 토벌','{"ranged_pct": 5}'::jsonb,true,false,'{"ev": "combat", "p": {"action": "ranged"}, "n": 50}'::jsonb,19,'전투'),
('seal_path','술의 길','sword','방울과 부채로 요기를 다스린다.','술법 무기로 50마리 토벌','{"magic_pct": 5}'::jsonb,true,false,'{"ev": "combat", "p": {"action": "seal"}, "n": 50}'::jsonb,20,'전투'),
('searcher_50','발 빠른 탐색자','search','구석구석 살피는 버릇이 들었다.','탐색 50회','{"clue_bonus_pct": 3}'::jsonb,true,false,'{"ev": "explore", "n": 50}'::jsonb,21,'탐사'),
('searcher_300','지칠 줄 모르는 발','search','삼백 번을 살피고도 또 나선다.','탐색 300회','{"gather_qty_pct": 3, "clue_bonus_pct": 3}'::jsonb,true,false,'{"ev": "explore", "n": 300}'::jsonb,22,'탐사'),
('pathfinder','길잡이','search','남들이 못 본 길을 찾아낸다.','탐색으로 새 길 10번 발견','{"travel_time_pct": -3}'::jsonb,true,false,'{"ev": "explore", "p": {"outcome": "path"}, "n": 10}'::jsonb,23,'탐사'),
('spot_finder','채집터 발견자','search','좋은 채집터를 알아본다.','채집터 10곳 발견','{"gather_qty_pct": 3}'::jsonb,true,false,'{"spots": 10}'::jsonb,24,'탐사'),
('deep_walker','심처 답파','search','깊은 곳까지 발을 들였다.','숨은 장소 30곳 발견','{"rare_loot_pct": 2}'::jsonb,true,false,'{"nodes": 30}'::jsonb,25,'탐사'),
('region_full','완전 답사','search','한 지역의 구석까지 모두 안다.','지역 1곳 완전 답사','{"rare_loot_pct": 2}'::jsonb,true,false,'{"survey_full": 1}'::jsonb,26,'탐사'),
('region_full_5','다섯 고을 답사','search','다섯 지역을 손바닥 보듯 안다.','지역 5곳 완전 답사','{"rare_loot_pct": 3, "travel_time_pct": -3}'::jsonb,true,false,'{"survey_full": 5}'::jsonb,27,'탐사'),
('cache_hunter','보따리 사냥꾼','search','남이 숨긴 꾸러미를 잘 찾는다.','숨겨진 꾸러미 20번 발견','{"rare_loot_pct": 3}'::jsonb,true,false,'{"ev": "explore", "p": {"outcome": "cache"}, "n": 20}'::jsonb,28,'탐사'),
('gather_100','부지런한 손','leaf','하루도 쉬지 않고 캐고 뜯는다.','채집 100회','{"gather_qty_pct": 4}'::jsonb,true,false,'{"ev": "gather", "n": 100}'::jsonb,29,'채집'),
('gather_500','대지의 손','leaf','땅이 먼저 내어 주는 사람.','채집 500회','{"gather_qty_pct": 6}'::jsonb,true,false,'{"ev": "gather", "n": 500}'::jsonb,30,'채집'),
('prof_gatherer','전문 채집가','leaf','자기 분야의 채집터를 정확히 고른다.','전문 분야 채집터에서 50회 채집','{"gather_qty_pct": 4}'::jsonb,true,false,'{"ev": "gather", "p": {"profession_match": true}, "n": 50}'::jsonb,31,'채집'),
('craft_q90','명품 장인','hammer','품질 90을 넘긴 물건을 만들었다.','품질 90 이상 제작','{"craft_quality": 4}'::jsonb,true,false,'{"ev": "craft", "gte": {"quality": 90}}'::jsonb,32,'제작'),
('craft_200','공방의 주인','hammer','공방의 불이 꺼지지 않는다.','제작 200회','{"craft_quality": 6}'::jsonb,true,false,'{"ev": "craft", "n": 200}'::jsonb,33,'제작'),
('ch1_done','붉은 인장 해결자','scroll','사라진 붉은 인장의 행방을 밝혔다.','1장 「붉은 인장의 실종」 해결','{"clue_bonus_pct": 4}'::jsonb,true,false,'{"ev": "story", "p": {"chapter_id": "red_seal"}}'::jsonb,34,'이야기'),
('ch2_done','수몰 장부 해독','scroll','물에 잠긴 장부의 비밀을 풀었다.','2장 해결','{"clue_bonus_pct": 4}'::jsonb,true,false,'{"ev": "story", "p": {"chapter_id": "drowned_ledger"}}'::jsonb,35,'이야기'),
('ch3_done','적월 맹약 파훼','scroll','붉은 달 아래의 맹약을 깨뜨렸다.','3장 해결','{"combat_damage_pct": 3}'::jsonb,true,false,'{"ev": "story", "p": {"chapter_id": "red_moon_oath"}}'::jsonb,36,'이야기'),
('ch4_done','서리 봉인 수호','scroll','북녘의 서리 봉인을 지켜 냈다.','4장 해결','{"incoming_damage_pct": -3}'::jsonb,true,false,'{"ev": "story", "p": {"chapter_id": "frost_seal"}}'::jsonb,37,'이야기'),
('ch5_done','이름 없는 종지기','scroll','울리지 않던 종의 이름을 찾았다.','5장 해결','{"rare_loot_pct": 3}'::jsonb,true,false,'{"ev": "story", "p": {"chapter_id": "nameless_bell"}}'::jsonb,38,'이야기'),
('ch6_done','구문 돌파','scroll','아홉 겹의 문을 모두 넘었다.','6장 해결','{"combat_damage_pct": 3, "rare_loot_pct": 3}'::jsonb,true,false,'{"ev": "story", "p": {"chapter_id": "nine_gates"}}'::jsonb,39,'이야기'),
('commission_10','의뢰 해결사','scroll','게시판의 단골 해결사.','상시 의뢰 10건 완료','{"rare_loot_pct": 2}'::jsonb,true,false,'{"ev": "commission", "n": 10}'::jsonb,40,'이야기'),
('commission_50','믿음직한 해결사','scroll','의뢰인들이 이름을 찾아 부른다.','상시 의뢰 50건 완료','{"rare_loot_pct": 3, "clue_bonus_pct": 3}'::jsonb,true,false,'{"ev": "commission", "n": 50}'::jsonb,41,'이야기'),
('traveler_100','천 리 나그네','route','길 위에서 해가 뜨고 진다.','이동 100회','{"travel_time_pct": -6}'::jsonb,true,false,'{"ev": "travel", "n": 100}'::jsonb,42,'이동'),
('all_regions','팔도 유람','route','서른 고을을 두루 밟았다.','서로 다른 지역 30곳 방문','{"travel_time_pct": -8}'::jsonb,true,false,'{"distinct": "travel", "key": "region_id", "n": 30}'::jsonb,43,'이동'),
('rider','말 탄 조사원','route','처음으로 자기 탈것을 얻었다.','탈것 1마리 보유','{"travel_time_pct": -3}'::jsonb,true,false,'{"mounts": 1}'::jsonb,44,'이동'),
('stable_master','마구간 주인','route','탈것이 넷이나 된다.','탈것 4마리 보유','{"travel_time_pct": -5}'::jsonb,true,false,'{"mounts": 4}'::jsonb,45,'이동'),
('lv10','견습 딱지를 떼다','spark','이제 혼자서도 밤길을 걷는다.','레벨 10','{"incoming_damage_pct": -1}'::jsonb,true,false,'{"char": "level", "n": 10}'::jsonb,46,'성장'),
('lv20','노련한 조사원','spark','어지간한 요괴는 눈빛으로 안다.','레벨 20','{"combat_damage_pct": 2}'::jsonb,true,false,'{"char": "level", "n": 20}'::jsonb,47,'성장'),
('lv30','야행국의 기둥','spark','야행국이 믿고 맡기는 조사원.','레벨 30','{"combat_damage_pct": 3, "incoming_damage_pct": -3}'::jsonb,true,false,'{"char": "level", "n": 30}'::jsonb,48,'성장'),
('rescuer','구조대원','users','쓰러진 동료를 일으켜 세웠다.','다른 조사원 1명 구조','{"incoming_damage_pct": -2}'::jsonb,true,false,'{"ev": "rescue", "has": "target_id"}'::jsonb,49,'교류'),
('rescuer_10','생명의 은인','users','열 명이 이 사람 덕에 살았다.','다른 조사원 10명 구조','{"incoming_damage_pct": -4}'::jsonb,true,false,'{"ev": "rescue", "has": "target_id", "n": 10}'::jsonb,50,'교류'),
('night_owl','삼경의 산책자','moon','남들이 잠든 시각에 홀로 길을 살핀다.','삼경에 탐색 30회','{"clue_bonus_pct": 5}'::jsonb,true,true,'{"ev": "explore", "phase": "night", "n": 30}'::jsonb,51,'비밀'),
('night_hunter','삼경의 사냥꾼','moon','요괴가 가장 사나운 때에 사냥을 나선다.','삼경에 요괴 20마리 토벌','{"combat_damage_pct": 4}'::jsonb,true,true,'{"ev": "combat", "phase": "night", "n": 20}'::jsonb,52,'비밀'),
('dawn_gatherer','새벽 이슬','moon','해 뜰 무렵의 풀이 가장 향기롭다는 것을 안다.','해돋이에 채집 30회','{"gather_qty_pct": 5}'::jsonb,true,true,'{"ev": "gather", "phase": "dawn", "n": 30}'::jsonb,53,'비밀'),
('noon_crafter','한낮의 장인','moon','볕 좋은 한낮에 손이 가장 정확하다.','한낮에 제작 30회','{"craft_quality": 5}'::jsonb,true,true,'{"ev": "craft", "phase": "noon", "n": 30}'::jsonb,54,'비밀'),
('dusk_seeker','땅거미 탐정','moon','그림자가 길어질 때 실마리가 보인다.','땅거미에 단서 5개 발견','{"clue_bonus_pct": 6}'::jsonb,true,true,'{"ev": "explore", "phase": "dusk", "p": {"outcome": "clue"}, "n": 5}'::jsonb,55,'비밀'),
('wanderer_night','야행자','moon','이름 그대로 밤에만 길을 떠난다.','삼경에 이동 20회','{"travel_time_pct": -5}'::jsonb,true,true,'{"ev": "travel", "phase": "night", "n": 20}'::jsonb,56,'비밀'),
('blood_mist_blade','혈무 속의 칼','moon','붉은 안개 속에서도 칼끝이 흔들리지 않는다.','혈무 속에서 요괴 5마리 토벌','{"combat_damage_pct": 5}'::jsonb,true,true,'{"ev": "combat", "p": {"env_weather": "bloodmist"}, "n": 5}'::jsonb,57,'비밀'),
('fog_walker','안개 너머','moon','짙은 안개 속에서도 길을 잃지 않는다.','농무 속에서 탐색 20회','{"clue_bonus_pct": 5}'::jsonb,true,true,'{"ev": "explore", "p": {"env_weather": "fog"}, "n": 20}'::jsonb,58,'비밀'),
('rain_herbalist','빗속의 약초꾼','moon','비 오는 날이 약초꾼의 대목이다.','장우 속에서 채집 20회','{"gather_qty_pct": 5}'::jsonb,true,true,'{"ev": "gather", "p": {"env_weather": "rain"}, "n": 20}'::jsonb,59,'비밀'),
('snow_marcher','설한 행군','moon','눈보라도 걸음을 막지 못한다.','설한 속에서 이동 5회','{"travel_time_pct": -4}'::jsonb,true,true,'{"ev": "travel", "p": {"env_weather": "snow"}, "n": 5}'::jsonb,60,'비밀'),
('wind_archer','삭풍의 궁수','moon','바람을 읽어 화살을 보낸다.','삭풍 속에서 원거리 무기로 10마리 토벌','{"ranged_pct": 6}'::jsonb,true,true,'{"ev": "combat", "p": {"env_weather": "wind", "action": "ranged"}, "n": 10}'::jsonb,61,'비밀'),
('clear_sky','청명한 날','moon','맑은 하늘 아래 고을 셋을 돌았다.','청명한 날 이동 10회','{"travel_time_pct": -3}'::jsonb,true,true,'{"ev": "travel", "p": {"env_weather": "clear"}, "n": 10}'::jsonb,62,'비밀'),
('one_hit','일격필살','moon','싸움은 한 번에 끝난다.','첫 공격으로 10마리 토벌','{"combat_damage_pct": 3}'::jsonb,true,true,'{"ev": "combat", "p": {"turns": 1}, "n": 10}'::jsonb,63,'비밀'),
('long_fight','끈질긴 싸움','moon','열다섯 합을 넘겨 끝내 이겼다.','15턴 이상 걸린 싸움에서 승리','{"incoming_damage_pct": -3}'::jsonb,true,true,'{"ev": "combat", "gte": {"turns": 15}}'::jsonb,64,'비밀'),
('coward','삼십육계','moon','도망도 병법이다.','전투에서 10번 달아남','{"travel_time_pct": -3}'::jsonb,true,true,'{"ev": "battle_fled", "n": 10}'::jsonb,65,'비밀'),
('fallen','쓰러져도 다시','moon','쓰러진 만큼 단단해진다.','전투에서 3번 쓰러짐','{"incoming_damage_pct": -2}'::jsonb,true,true,'{"ev": "battle_lost", "n": 3}'::jsonb,66,'비밀'),
('fallen_10','칠전팔기','moon','열 번 쓰러지고 열한 번 일어났다.','전투에서 10번 쓰러짐','{"incoming_damage_pct": -4}'::jsonb,true,true,'{"ev": "battle_lost", "n": 10}'::jsonb,67,'비밀'),
('revived','저승 문턱','moon','저승 문 앞에서 돌아왔다.','회생 부적으로 일어남','{"incoming_damage_pct": -3}'::jsonb,true,true,'{"ev": "use_item", "p": {"item_id": "revival_charm"}}'::jsonb,68,'비밀'),
('mourner','조문객','moon','길에 쓰러진 이의 명복을 빌어 주었다.','시신 5구에 명복을 빎','{"clue_bonus_pct": 3}'::jsonb,true,true,'{"ev": "respect", "n": 5}'::jsonb,69,'비밀'),
('mourner_20','넋을 기리는 자','moon','떠난 이들을 잊지 않는다.','시신 20구에 명복을 빎','{"clue_bonus_pct": 5, "rare_loot_pct": 2}'::jsonb,true,true,'{"ev": "respect", "n": 20}'::jsonb,70,'비밀'),
('rich','전대 가득','moon','전대가 무거워 걸음이 느려질 지경.','소지금 5만 전','{"rare_loot_pct": 2}'::jsonb,true,true,'{"char": "gil", "n": 50000}'::jsonb,71,'비밀'),
('tycoon','거부','moon','야행국에서 손꼽히는 부자.','소지금 30만 전','{"rare_loot_pct": 4}'::jsonb,true,true,'{"char": "gil", "n": 300000}'::jsonb,72,'비밀'),
('pauper','빈털터리','moon','전대가 텅 비었다. 이제 올라갈 일만 남았다.','소지금 0전','{"gather_qty_pct": 2}'::jsonb,true,true,'{"char": "gil", "max": 0, "n": 0}'::jsonb,73,'비밀'),
('eroded','사기에 물든 자','moon','침식이 뼛속까지 스몄다. 그 힘을 다루는 법을 익혔다.','침식 80 이상','{"magic_pct": 6}'::jsonb,true,true,'{"char": "erosion", "n": 80}'::jsonb,74,'비밀'),
('cleansed','맑게 씻긴 영혼','moon','부적을 태운 재가 산을 이룬다.','정화 부적 50번 사용','{"incoming_damage_pct": -3}'::jsonb,true,true,'{"ev": "use_item", "p": {"item_id": "ward_talisman"}, "n": 50}'::jsonb,75,'비밀'),
('tonic_lover','청심환 애호가','moon','주머니에 늘 청심환이 있다.','청심환 30번 사용','{"incoming_damage_pct": -2}'::jsonb,true,true,'{"ev": "use_item", "p": {"item_id": "tonic"}, "n": 30}'::jsonb,76,'비밀'),
('hoarder','보따리 장수','moon','가방이 집채만 하다.','가방 120칸','{"gather_qty_pct": 3}'::jsonb,true,true,'{"char": "bag_capacity", "n": 120}'::jsonb,77,'비밀'),
('title_collector','칭호 수집가','moon','불리는 이름이 스물을 넘었다.','칭호 20개 획득','{"rare_loot_pct": 3}'::jsonb,true,true,'{"titles": 20}'::jsonb,78,'비밀'),
('title_master','칭호의 주인','moon','이름 앞에 붙는 말이 끝이 없다.','칭호 60개 획득','{"rare_loot_pct": 5, "clue_bonus_pct": 5}'::jsonb,true,true,'{"titles": 60}'::jsonb,79,'비밀'),
('strong','장사','moon','바위도 들어 올린다.','근력 40','{"melee_pct": 4}'::jsonb,true,true,'{"char": "strength", "n": 40}'::jsonb,80,'비밀'),
('swift','바람 같은 자','moon','그림자도 따라오지 못한다.','민첩 40','{"ranged_pct": 4}'::jsonb,true,true,'{"char": "agility", "n": 40}'::jsonb,81,'비밀'),
('tough','철골','moon','뼈가 쇠처럼 단단하다.','체질 40','{"incoming_damage_pct": -4}'::jsonb,true,true,'{"char": "vitality", "n": 40}'::jsonb,82,'비밀'),
('keen','천리안','moon','천 리 밖의 기척도 느낀다.','감각 40','{"clue_bonus_pct": 5}'::jsonb,true,true,'{"char": "perception", "n": 40}'::jsonb,83,'비밀'),
('iron_will','불굴','moon','어떤 곡성에도 꺾이지 않는다.','의지 40','{"incoming_damage_pct": -3}'::jsonb,true,true,'{"char": "willpower", "n": 40}'::jsonb,84,'비밀'),
('spirit_vessel','영험한 그릇','moon','영기가 몸에 고인다.','영성 40','{"magic_pct": 4}'::jsonb,true,true,'{"char": "spirit_affinity", "n": 40}'::jsonb,85,'비밀'),
('hazard_survivor','함정 전문가','moon','함정이란 함정은 다 밟아 봤다.','탐색 중 위험 15번 겪음','{"incoming_damage_pct": -2}'::jsonb,true,true,'{"ev": "explore", "p": {"outcome": "hazard"}, "n": 15}'::jsonb,86,'비밀'),
('omen_reader','징조를 읽는 자','moon','바람결과 새 울음에서 뜻을 읽는다.','탐색 중 징조 15번 만남','{"clue_bonus_pct": 4}'::jsonb,true,true,'{"ev": "explore", "p": {"outcome": "omen"}, "n": 15}'::jsonb,87,'비밀'),
('quiet_night','고요한 밤','moon','아무 일도 없는 밤도 소중하다.','탐색에서 아무것도 못 찾음 30번','{"rare_loot_pct": 2}'::jsonb,true,true,'{"ev": "explore", "p": {"outcome": "quiet"}, "n": 30}'::jsonb,88,'비밀'),
('rest_lover','쉼표','moon','쉴 줄 아는 자가 오래 간다.','휴식 20번','{"gather_qty_pct": 2}'::jsonb,true,true,'{"ev": "rest", "n": 20}'::jsonb,89,'비밀'),
('expedition_vet','원정 고참','moon','스무 번을 떠나 스무 번을 돌아왔다.','원정 20번 마침','{"gather_qty_pct": 4}'::jsonb,true,true,'{"ev": "expedition_end", "n": 20}'::jsonb,90,'비밀'),
('supply_regular','보급 단골','moon','보급 담당이 얼굴을 기억한다.','일일 보급 30번 수령','{"rare_loot_pct": 2}'::jsonb,true,true,'{"ev": "supply", "n": 30}'::jsonb,91,'비밀'),
('mission_runner','부서의 일꾼','moon','소속 부서의 일이라면 마다하지 않는다.','소속 임무 20번 완료','{"clue_bonus_pct": 3}'::jsonb,true,true,'{"ev": "mission", "n": 20}'::jsonb,92,'비밀'),
('repairman','손재주','moon','부서진 것을 그냥 두지 못한다.','장비 20번 수리','{"craft_quality": 3}'::jsonb,true,true,'{"ev": "repair", "n": 20}'::jsonb,93,'비밀'),
('armored_breaker','껍질 깨기','moon','단단한 껍질 속의 약점을 안다.','장갑 요괴 20마리 토벌','{"combat_damage_pct": 2, "magic_pct": 2}'::jsonb,true,true,'{"ev": "combat", "p": {"mechanic": "armored"}, "n": 20}'::jsonb,94,'비밀'),
('sky_hunter','하늘 사냥꾼','moon','나는 것은 활로 떨어뜨린다.','비행 요괴 20마리 토벌','{"ranged_pct": 5}'::jsonb,true,true,'{"ev": "combat", "p": {"mechanic": "aerial"}, "n": 20}'::jsonb,95,'비밀'),
('ghost_exorcist','혼백 퇴치','moon','떠도는 혼백을 제자리로 돌려보낸다.','영체 요괴 20마리 토벌','{"magic_pct": 5}'::jsonb,true,true,'{"ev": "combat", "p": {"mechanic": "spectral"}, "n": 20}'::jsonb,96,'비밀'),
('elite_50','정예 학살자','moon','정예라는 이름이 무색하다.','정예 요괴 50마리 토벌','{"combat_damage_pct": 5}'::jsonb,true,true,'{"ev": "combat", "p": {"rank": "elite"}, "n": 50}'::jsonb,97,'비밀'),
('guardian_25','수호자의 천적','moon','우두머리들이 이 이름을 두려워한다.','우두머리 25마리 토벌','{"combat_damage_pct": 6, "incoming_damage_pct": -3}'::jsonb,true,true,'{"ev": "combat", "p": {"rank": "guardian"}, "n": 25}'::jsonb,98,'비밀'),
('night_guardian','삼경의 우두머리 사냥','moon','가장 어두운 때 가장 강한 것을 꺾었다.','삼경에 우두머리 토벌','{"combat_damage_pct": 4, "rare_loot_pct": 3}'::jsonb,true,true,'{"ev": "combat", "phase": "night", "p": {"rank": "guardian"}}'::jsonb,99,'비밀'),
('legend','야행의 전설','moon','야행국의 밤을 끝까지 걸은 자.','레벨 30·칭호 40개·6장 해결','{"combat_damage_pct": 5, "rare_loot_pct": 5, "clue_bonus_pct": 5}'::jsonb,true,true,'{"all": [{"char": "level", "n": 30}, {"titles": 40}, {"ev": "story", "p": {"chapter_id": "nine_gates"}}]}'::jsonb,100,'비밀')
ON CONFLICT (title_key) DO UPDATE SET title_name=excluded.title_name, icon=excluded.icon, description=excluded.description, condition_text=excluded.condition_text, bonus=excluded.bonus, active=true, hidden=excluded.hidden, rule=excluded.rule, sort=excluded.sort, category=excluded.category;

-- ── 칭호 조건 판정 ───────────────────────────────────────
-- 조건 형식: {"ev":기록종류,"n":횟수,"p":{기록 내용 일치},"has":키,"gte":{키:최솟값},"phase":시간대}
--            {"distinct":기록종류,"key":키,"n":개수} {"char":열,"n":최솟값|"max":최댓값}
--            {"nodes":n} {"spots":n} {"mounts":n} {"titles":n} {"survey_full":n} {"all":[조건…]}
CREATE OR REPLACE FUNCTION public.world_title_rule_ok(p_owner uuid, p_rule jsonb)
 RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE n numeric := coalesce((p_rule ->> 'n')::numeric, 1); v numeric; x jsonb;
BEGIN
  IF p_rule IS NULL THEN RETURN false; END IF;
  IF p_rule ? 'all' THEN
    FOR x IN SELECT value FROM jsonb_array_elements(p_rule -> 'all') LOOP
      IF NOT public.world_title_rule_ok(p_owner, x) THEN RETURN false; END IF;
    END LOOP;
    RETURN true;
  ELSIF p_rule ? 'ev' THEN
    SELECT count(*) INTO v FROM public.world_events e
    WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> 'ev'
      AND (NOT p_rule ? 'p' OR e.payload @> (p_rule -> 'p'))
      AND (NOT p_rule ? 'has' OR e.payload ? (p_rule ->> 'has'))
      AND (NOT p_rule ? 'phase' OR public.world_time_phase(e.created_at) = p_rule ->> 'phase')
      AND (NOT p_rule ? 'gte' OR NOT EXISTS (SELECT 1 FROM jsonb_each_text(p_rule -> 'gte') g
             WHERE NOT (coalesce(e.payload ->> g.key, '') ~ '^-?[0-9]+(\.[0-9]+)?$' AND (e.payload ->> g.key)::numeric >= g.value::numeric)));
    RETURN v >= n;
  ELSIF p_rule ? 'distinct' THEN
    SELECT count(DISTINCT e.payload ->> (p_rule ->> 'key')) INTO v FROM public.world_events e
    WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> 'distinct' AND e.payload ? (p_rule ->> 'key');
    RETURN v >= n;
  ELSIF p_rule ? 'char' THEN
    SELECT (to_jsonb(ch) ->> (p_rule ->> 'char'))::numeric INTO v FROM public.world_characters ch WHERE ch.owner_id = p_owner;
    IF v IS NULL THEN RETURN false; END IF;
    IF p_rule ? 'max' THEN RETURN v <= (p_rule ->> 'max')::numeric; END IF;
    RETURN v >= n;
  ELSIF p_rule ? 'nodes' THEN
    SELECT count(*) INTO v FROM public.world_exploration_discoveries WHERE owner_id = p_owner; RETURN v >= (p_rule ->> 'nodes')::numeric;
  ELSIF p_rule ? 'spots' THEN
    SELECT count(*) INTO v FROM public.world_gathering_discoveries WHERE owner_id = p_owner; RETURN v >= (p_rule ->> 'spots')::numeric;
  ELSIF p_rule ? 'mounts' THEN
    SELECT count(*) INTO v FROM public.world_owned_mounts WHERE owner_id = p_owner; RETURN v >= (p_rule ->> 'mounts')::numeric;
  ELSIF p_rule ? 'titles' THEN
    SELECT count(*) INTO v FROM public.world_character_titles WHERE owner_id = p_owner; RETURN v >= (p_rule ->> 'titles')::numeric;
  ELSIF p_rule ? 'survey_full' THEN
    SELECT count(*) INTO v FROM public.world_map_regions r
    WHERE r.active AND NOT coalesce(r.is_safe_zone, false) AND coalesce((public.world_field_survey(p_owner, r.region_id) ->> 'pct')::int, 0) >= 100;
    RETURN v >= (p_rule ->> 'survey_full')::numeric;
  END IF;
  RETURN false;
END $f$;

-- 기록이 생길 때마다 아직 얻지 못한 칭호만 살핀다. 기록 종류와 관계없는 조건은 건너뛴다.
CREATE OR REPLACE FUNCTION public.world_title_award_check(p_owner_id uuid, p_event_type text DEFAULT NULL::text)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE t record; got int := 0; last_outcome text; r jsonb;
BEGIN
  IF p_owner_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.world_characters WHERE owner_id = p_owner_id AND NOT coalesce(is_dead, false)) THEN RETURN 0; END IF;
  IF p_event_type = 'explore' THEN
    SELECT e.payload ->> 'outcome' INTO last_outcome FROM public.world_events e WHERE e.actor_id = p_owner_id ORDER BY e.created_at DESC, e.id DESC LIMIT 1;
  END IF;
  FOR t IN SELECT tc.title_key, tc.title_name, tc.hidden, tc.rule FROM public.world_title_catalog tc
           WHERE tc.active AND tc.rule IS NOT NULL
             AND NOT EXISTS (SELECT 1 FROM public.world_character_titles ct WHERE ct.owner_id = p_owner_id AND ct.title_key = tc.title_key)
           ORDER BY tc.sort LOOP
    r := t.rule;
    -- 이번 기록과 관계없는 조건은 건너뛴다(성능).
    IF r ? 'ev' AND p_event_type IS NOT NULL AND r ->> 'ev' <> p_event_type THEN CONTINUE; END IF;
    IF r ? 'distinct' AND p_event_type IS NOT NULL AND r ->> 'distinct' <> p_event_type THEN CONTINUE; END IF;
    IF (r ? 'nodes' OR r ? 'spots') AND p_event_type IS NOT NULL AND NOT (p_event_type = 'explore' AND last_outcome IN ('path', 'spot')) AND p_event_type <> 'expedition_end' THEN CONTINUE; END IF;
    IF r ? 'survey_full' AND p_event_type IS NOT NULL AND NOT (p_event_type = 'explore' AND last_outcome IN ('path', 'spot')) AND p_event_type <> 'expedition_end' THEN CONTINUE; END IF;
    IF r ? 'mounts' AND p_event_type IS NOT NULL AND p_event_type NOT IN ('mount', 'story', 'expedition_end', 'case_resolved') THEN CONTINUE; END IF;
    IF public.world_title_rule_ok(p_owner_id, r) THEN
      INSERT INTO public.world_character_titles(owner_id, title_key) VALUES (p_owner_id, t.title_key) ON CONFLICT DO NOTHING;
      IF FOUND THEN
        got := got + 1;
        INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
        VALUES (p_owner_id, 'title', CASE WHEN t.hidden THEN '숨겨진 칭호를 얻었습니다' ELSE '칭호를 얻었습니다' END,
                '「' || t.title_name || '」 · 캐릭터 › 칭호에서 장착할 수 있습니다.', jsonb_build_object('title_key', t.title_key));
      END IF;
    END IF;
  END LOOP;
  -- 칭호 개수 조건은 새로 얻은 뒤 한 번 더 본다.
  IF got > 0 THEN
    FOR t IN SELECT tc.title_key, tc.title_name, tc.hidden, tc.rule FROM public.world_title_catalog tc
             WHERE tc.active AND (tc.rule ? 'titles' OR tc.rule ? 'all')
               AND NOT EXISTS (SELECT 1 FROM public.world_character_titles ct WHERE ct.owner_id = p_owner_id AND ct.title_key = tc.title_key) LOOP
      IF public.world_title_rule_ok(p_owner_id, t.rule) THEN
        INSERT INTO public.world_character_titles(owner_id, title_key) VALUES (p_owner_id, t.title_key) ON CONFLICT DO NOTHING;
        IF FOUND THEN
          got := got + 1;
          INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
          VALUES (p_owner_id, 'title', '숨겨진 칭호를 얻었습니다', '「' || t.title_name || '」 · 캐릭터 › 칭호에서 장착할 수 있습니다.', jsonb_build_object('title_key', t.title_key));
        END IF;
      END IF;
    END LOOP;
  END IF;
  RETURN got;
END $f$;

-- 칭호 목록: 숨김 칭호는 얻기 전까지 이름·조건을 감춘다.
CREATE OR REPLACE FUNCTION public.world_title_snapshot()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); out jsonb; disp text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT profile ->> 'title' INTO disp FROM public.world_characters WHERE owner_id = uid;
  SELECT jsonb_build_object(
    'earned_count', count(*) FILTER (WHERE ct.owner_id IS NOT NULL),
    'equipped_count', count(*) FILTER (WHERE ct.owner_id IS NOT NULL AND ct.is_equipped),
    'max_equipped', 3, 'display', disp,
    'total', count(*), 'visible_total', count(*) FILTER (WHERE NOT tc.hidden), 'hidden_total', count(*) FILTER (WHERE tc.hidden),
    'hidden_earned', count(*) FILTER (WHERE tc.hidden AND ct.owner_id IS NOT NULL),
    'titles', coalesce(jsonb_agg(jsonb_build_object(
      'key', tc.title_key, 'hidden', tc.hidden, 'category', coalesce(tc.category, '기타'), 'icon', tc.icon,
      'name', CASE WHEN tc.hidden AND ct.owner_id IS NULL THEN '숨겨진 칭호' ELSE tc.title_name END,
      'description', CASE WHEN tc.hidden AND ct.owner_id IS NULL THEN '어떤 조건으로 얻는지 알려지지 않았습니다.' ELSE tc.description END,
      'condition', CASE WHEN tc.hidden AND ct.owner_id IS NULL THEN '???' ELSE tc.condition_text END,
      'bonus', CASE WHEN tc.hidden AND ct.owner_id IS NULL THEN NULL ELSE tc.bonus END,
      'earned', ct.owner_id IS NOT NULL, 'earned_at', ct.earned_at, 'equipped', coalesce(ct.is_equipped, false), 'display', tc.title_key = disp)
      ORDER BY (ct.owner_id IS NOT NULL) DESC, tc.hidden, tc.sort), '[]'::jsonb))
  INTO out
  FROM public.world_title_catalog tc LEFT JOIN public.world_character_titles ct ON ct.title_key = tc.title_key AND ct.owner_id = uid
  WHERE tc.active;
  RETURN out;
END $f$;

-- 대표 칭호: 채팅과 프로필에 보이는 칭호(장착 여부와 별개, 얻은 칭호 중에서 고른다)
CREATE OR REPLACE FUNCTION public.world_title_set_display(p_title_key text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); nm text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  PERFORM 1 FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF p_title_key IS NULL OR p_title_key = '' THEN
    UPDATE public.world_characters SET profile = coalesce(profile, '{}'::jsonb) - 'title' - 'title_name', updated_at = now() WHERE owner_id = uid;
    RETURN jsonb_build_object('ok', true, 'content', '대표 칭호를 내렸습니다.');
  END IF;
  SELECT tc.title_name INTO nm FROM public.world_character_titles ct JOIN public.world_title_catalog tc USING (title_key)
  WHERE ct.owner_id = uid AND ct.title_key = p_title_key;
  IF nm IS NULL THEN RAISE EXCEPTION '얻은 칭호만 대표로 걸 수 있습니다.'; END IF;
  UPDATE public.world_characters SET profile = coalesce(profile, '{}'::jsonb) || jsonb_build_object('title', p_title_key, 'title_name', nm), updated_at = now() WHERE owner_id = uid;
  RETURN jsonb_build_object('ok', true, 'content', '대표 칭호: 「' || nm || '」', 'title_name', nm);
END $f$;

-- 채팅에 대표 칭호를 함께 남긴다(보낸 사람이 실제로 얻은 칭호일 때만).
ALTER TABLE public.world_chat_messages ADD COLUMN IF NOT EXISTS sender_title text;
CREATE OR REPLACE FUNCTION public.world_chat_stamp_title()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
BEGIN
  new.sender_title := (SELECT tc.title_name FROM public.world_characters c
    JOIN public.world_character_titles ct ON ct.owner_id = c.owner_id AND ct.title_key = c.profile ->> 'title'
    JOIN public.world_title_catalog tc ON tc.title_key = ct.title_key
    WHERE c.owner_id = new.sender_id);
  RETURN new;
END $f$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_world_chat_stamp_title' AND tgrelid = 'public.world_chat_messages'::regclass) THEN
    CREATE TRIGGER trg_world_chat_stamp_title BEFORE INSERT ON public.world_chat_messages FOR EACH ROW EXECUTE FUNCTION public.world_chat_stamp_title();
  END IF;
END $$;

-- 지하회랑에는 눈이 오지 않는다.
UPDATE public.world_weather_climate SET weights = '{"clear":15,"cloudy":32,"rain":10,"fog":35,"bloodmist":8}' WHERE territory_id = 'underworld';

-- ── 소유권 ───────────────────────────────────────────────
ALTER FUNCTION public.world_title_rule_ok(uuid, jsonb) OWNER TO fn_owner_field;
ALTER FUNCTION public.world_title_award_check(uuid, text) OWNER TO fn_owner_field;
ALTER FUNCTION public.world_title_snapshot() OWNER TO fn_owner_field;
ALTER FUNCTION public.world_title_set_display(text) OWNER TO fn_owner_field;
ALTER FUNCTION public.world_chat_stamp_title() OWNER TO fn_owner_field;
GRANT SELECT ON public.world_chat_messages TO fn_owner_field;

-- 적용 기록: 2026-10-27 SQL 도구로 두 번에 나눠 실행(칭호·함수 / 탐색·채집·원정 수정·전투·권한). 이미 쌓인 기록으로 칭호 6개 지급.
-- ── 기존 함수 고치기(본문의 한 구절만 바꾼다. 바꿀 구절이 없으면 멈춘다) ────────
SET ROLE fn_owner_field;
DO $$
DECLARE d text; nd text; prev text;
BEGIN
  -- 탐색: 날씨·시간대에 따라 조우 빈도, 칭호의 단서·희귀품 보너스, 침식 가중
  d := pg_get_functiondef('public.world_field_search()'::regprocedure); nd := d;
  prev := nd;
  nd := replace(nd, 'w_enc := CASE WHEN depth = 0 THEN 18 ELSE 30 + depth * 3 END;',
    'w_enc := (CASE WHEN depth = 0 THEN 18 ELSE 30 + depth * 3 END) * greatest(0.3, 1 + public.world_status_effect_total(''encounter_pct'') / 100.0);');
  IF nd = prev THEN RAISE EXCEPTION '탐색 함수에서 고칠 구절을 찾지 못했습니다(1).'; END IF;
  prev := nd;
  nd := replace(nd, 'public.world_status_effect_total(''clue_bonus_pct'') * 0.5',
    '(public.world_status_effect_total(''clue_bonus_pct'') + public.world_title_bonus(''clue_bonus_pct'')) * 0.5');
  IF nd = prev THEN RAISE EXCEPTION '탐색 함수에서 고칠 구절을 찾지 못했습니다.'; END IF;
  prev := nd;
  nd := replace(nd, 'IF random() < 0.35 + depth * 0.08 THEN',
    'IF random() < 0.35 + depth * 0.08 + (public.world_status_effect_total(''rare_loot_pct'') + public.world_title_bonus(''rare_loot_pct'')) / 100.0 THEN');
  IF nd = prev THEN RAISE EXCEPTION '탐색 함수에서 고칠 구절을 찾지 못했습니다.'; END IF;
  prev := nd;
  nd := replace(nd, 'erosion - 2 + CASE WHEN r.danger_level >= 5 AND random() < 0.4 THEN 1 ELSE 0 END',
    'erosion - 2 + CASE WHEN (r.danger_level >= 5 AND random() < 0.4) OR random() < greatest(0, public.world_status_effect_total(''erosion_pct'')) / 60.0 THEN 1 ELSE 0 END');
  IF nd = prev THEN RAISE EXCEPTION '탐색 함수에서 고칠 구절을 찾지 못했습니다.'; END IF;
  EXECUTE nd;

  -- 채집: 도구가 부서지면 도구 보너스가 없고, 채집할 때마다 도구가 1씩 닳는다.
  d := pg_get_functiondef('public.world_field_gather(uuid)'::regprocedure); nd := d;
  nd := replace(nd, '  qty := greatest(1, round(qty * (1 + (coalesce(tool_bonus, 0)',
    '  IF EXISTS (SELECT 1 FROM public.world_character_equipment e JOIN public.world_item_durability dd ON dd.owner_id = e.owner_id AND dd.item_id = e.item_id
             WHERE e.owner_id = uid AND e.slot = ''tool'' AND dd.durability <= 0) THEN tool_bonus := 0; END IF;
  PERFORM public.world_durability_wear(uid, ''tool'', 1);
  qty := greatest(1, round(qty * (1 + (coalesce(tool_bonus, 0)');
  IF nd = d THEN RAISE EXCEPTION '채집 함수에서 고칠 구절을 찾지 못했습니다.'; END IF;
  EXECUTE nd;

  -- 원정: 지역 완전 답사 보상 가방 +5 → +1
  d := pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure); nd := d;
  nd := replace(nd, 'bag_capacity = least(400, bag_capacity + 5)', 'bag_capacity = least(400, bag_capacity + 1)');
  nd := replace(nd, '완전 답사 — 가방 용량 +5', '완전 답사 — 가방 용량 +1');
  IF nd = d THEN RAISE EXCEPTION '원정 함수에서 고칠 구절을 찾지 못했습니다.'; END IF;
  EXECUTE nd;
END $$;

-- ── 전투: 능력치 함수·내구도·날씨를 쓰는 판 ─────────────────
CREATE OR REPLACE FUNCTION public.world_battle_action(p_action text, p_item text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE
  uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; a public.world_active_encounters%rowtype;
  m public.world_region_monsters%rowtype; r public.world_map_regions%rowtype; st jsonb;
  act text := lower(coalesce(p_action, '')); style text := 'melee'; adr numeric := 0; eva numeric; flee_p numeric; crit_p numeric; defv numeric; inc numeric;
  turn int; v_fx jsonb; v_pfx jsonb; lines jsonb := '[]'::jsonb; dmg int := 0; mdmg int := 0; heal int := 0; crit boolean := false;
  base numeric; mul numeric := 1; cc numeric; mdef numeric; hit numeric; v_intent text; next_intent text; skip_monster boolean := false;
  guarding boolean := false; fled boolean := false; ended text; hp int; mn int; sp int; er int; inv jsonb; it text; k text; v int;
  loot jsonb := '{}'::jsonb; xp int := 0; gil_gain int := 0; rk_mul numeric; drop_p numeric; reflect int := 0; shield int;
  skill_name text; qty int; job_cd int; v_result jsonb; statuses text[] := '{}'; sig text; attacked boolean := false; wear jsonb; rare numeric;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF act NOT IN ('attack', 'skill', 'guard', 'item', 'flee') THEN RAISE EXCEPTION '알 수 없는 행동입니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태입니다.'; END IF;
  SELECT * INTO a FROM public.world_active_encounters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND OR a.defeated OR coalesce(a.fled, false) OR a.mlevel IS NULL THEN RAISE EXCEPTION '진행 중인 전투가 없습니다.'; END IF;
  IF a.last_action_at IS NOT NULL AND a.last_action_at > now() - interval '2 seconds' THEN
    RAISE EXCEPTION '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.'; END IF;
  SELECT * INTO m FROM public.world_region_monsters WHERE monster_id = a.monster_id;
  r := public.world_field_region(c.location);
  IF r.region_id IS DISTINCT FROM a.region_id THEN RAISE EXCEPTION '전투가 벌어진 지역에 있어야 합니다.'; END IF;

  -- 능력치(장비·내구도·상태이상·칭호·날씨·시간대가 모두 들어 있다)
  st := public.world_combat_stats(uid);
  style := st ->> 'style';
  eva := (st ->> 'evasion_pct')::numeric; flee_p := (st ->> 'flee_pct')::numeric; crit_p := (st ->> 'crit_pct')::numeric;
  defv := (st ->> 'defense')::numeric; inc := (st ->> 'incoming_pct')::numeric;
  IF st -> 'armor' IS NOT NULL AND st -> 'armor' <> 'null'::jsonb AND st -> 'armor' ->> 'state' <> 'broken' THEN adr := coalesce((st -> 'armor' ->> 'reduction')::numeric, 0); END IF;

  turn := a.turn_count + 1; v_fx := coalesce(a.fx, '{}'::jsonb); v_pfx := coalesce(a.pfx, '{}'::jsonb);
  hp := c.health; mn := c.mental; sp := c.spiritual_power; er := c.erosion; inv := coalesce(c.inventory, '{}'::jsonb);
  v_intent := coalesce(a.intent, 'strike');
  job_cd := coalesce((v_pfx ->> 'skill_ready')::int, 0);

  IF act = 'skill' THEN
    IF turn < job_cd THEN RAISE EXCEPTION '%', format('기술은 %s턴 뒤에 다시 쓸 수 있습니다.', job_cd - turn); END IF;
    IF sp < 12 THEN RAISE EXCEPTION '영력이 모자랍니다. (필요 12)'; END IF;
    sp := sp - 12; v_pfx := v_pfx || jsonb_build_object('skill_ready', turn + 3);
  END IF;

  -- ① 조사원의 행동
  IF act = 'flee' THEN
    IF random() * 100 < least(90, flee_p - greatest(0, a.mlevel - c.level) * 3 - (CASE WHEN a.rank = 'guardian' THEN 20 ELSE 0 END)) THEN
      fled := true; lines := lines || jsonb_build_array('몸을 돌려 달아났다.');
    ELSE
      lines := lines || jsonb_build_array('달아나려 했지만 길이 막혔다.');
    END IF;
  ELSIF act = 'guard' THEN
    guarding := true; sp := least(100, sp + 4);
    lines := lines || jsonb_build_array('자세를 낮추고 막을 준비를 했다.');
  ELSIF act = 'item' THEN
    it := coalesce(p_item, '');
    IF it NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman') THEN RAISE EXCEPTION '전투 중에 쓸 수 없는 물품입니다.'; END IF;
    IF coalesce((inv ->> it)::int, 0) < 1 THEN RAISE EXCEPTION '가방에 그 물품이 없습니다.'; END IF;
    inv := public.world_inv_add(inv, it, -1);
    IF it = 'ward_talisman' THEN
      mn := least(100, mn + 8);
      UPDATE public.world_character_statuses SET expires_at = now() WHERE owner_id = uid AND expires_at > now() AND status_key IN ('erosion_whisper', 'shaken', 'poisoned');
      IF (v_fx ->> 'barrier') IS NOT NULL THEN v_fx := v_fx - 'barrier'; END IF;
      lines := lines || jsonb_build_array('정화 부적을 태워 사기를 걷어냈다. 정신 +8');
    ELSE
      heal := CASE it WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 ELSE 12 END;
      IF c.job_key = 'medic' THEN heal := round(heal * 1.4); END IF;
      heal := round(heal * (1 + public.world_status_effect_total('healing_pct') / 100.0));
      hp := least(100, hp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 체력 ' || heal || ' 회복');
    END IF;
  ELSIF act = 'skill' AND c.job_key = 'medic' THEN
    heal := least(60, 25 + c.vitality + c.willpower / 2); hp := least(100, hp + heal);
    UPDATE public.world_character_statuses SET expires_at = now() WHERE status_id = (SELECT cs.status_id FROM public.world_character_statuses cs JOIN public.world_status_catalog sc USING (status_key)
      WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' ORDER BY cs.expires_at LIMIT 1);
    lines := lines || jsonb_build_array('응급 처방: 체력 ' || heal || ' 회복, 나쁜 상태 하나를 걷어냈다.');
  ELSIF act = 'skill' AND c.job_key = 'analyst' THEN
    v_pfx := v_pfx || jsonb_build_object('focus', 3);
    lines := lines || jsonb_build_array('약점 간파: ' || m.monster_name || '의 빈틈을 읽었다. 다음 세 번의 공격이 강해진다.');
  ELSE
    attacked := true;
    IF act = 'skill' AND c.job_key = 'exorcist' THEN style := 'magic'; skill_name := '퇴마진';
    ELSIF act = 'skill' AND c.job_key = 'scout' THEN style := 'ranged'; skill_name := '급소 사격';
    ELSIF act = 'skill' AND c.job_key = 'sealmaster' THEN skill_name := '봉인술';
    ELSIF act = 'skill' AND c.job_key = 'artificer' THEN skill_name := '폭렬 부적';
    END IF;
    base := (st ->> 'attack_raw')::numeric;
    IF style = 'magic' AND act = 'attack' THEN
      IF sp >= 3 THEN sp := sp - 3; ELSE base := base * 0.5; lines := lines || jsonb_build_array('영력이 바닥나 술법이 약해졌다.'); END IF;
    END IF;
    mul := 0.85 + random() * 0.3;
    mul := mul * CASE coalesce(m.mechanic_key, '')
      WHEN 'aerial' THEN CASE style WHEN 'melee' THEN 0.6 WHEN 'ranged' THEN 1.35 ELSE 1 END
      WHEN 'armored' THEN CASE style WHEN 'melee' THEN 0.85 WHEN 'ranged' THEN 0.7 ELSE 1.25 END
      WHEN 'spectral' THEN CASE style WHEN 'melee' THEN 0.6 WHEN 'ranged' THEN 0.8 ELSE 1.4 END
      WHEN 'warded' THEN CASE style WHEN 'melee' THEN 1.1 WHEN 'ranged' THEN 1 ELSE 0.8 END
      WHEN 'reflect' THEN CASE style WHEN 'melee' THEN 1 WHEN 'ranged' THEN 1.15 ELSE 0.7 END
      WHEN 'swarm' THEN CASE style WHEN 'melee' THEN 1.25 WHEN 'ranged' THEN 0.9 ELSE 1.1 END
      WHEN 'toxic' THEN CASE style WHEN 'melee' THEN 0.9 WHEN 'ranged' THEN 1.15 ELSE 1 END
      WHEN 'tide' THEN CASE style WHEN 'melee' THEN 1 WHEN 'ranged' THEN 0.9 ELSE 1.15 END
      WHEN 'seal_breaker' THEN CASE style WHEN 'melee' THEN 1.1 WHEN 'ranged' THEN 1 ELSE 0.85 END
      ELSE 1 END;
    IF coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN mul := mul * 1.4; v_pfx := v_pfx || jsonb_build_object('focus', (v_pfx ->> 'focus')::int - 1); END IF;
    IF coalesce((v_fx ->> 'marked')::int, 0) > 0 THEN mul := mul * 1.25; v_fx := v_fx || jsonb_build_object('marked', (v_fx ->> 'marked')::int - 1); END IF;
    IF coalesce((v_fx ->> 'airborne')::boolean, false) THEN
      mul := mul * CASE style WHEN 'melee' THEN 0.4 WHEN 'ranged' THEN 1.2 ELSE 0.9 END;
    END IF;
    IF skill_name = '퇴마진' THEN mul := mul * 2.0; v_fx := v_fx - 'barrier';
    ELSIF skill_name = '급소 사격' THEN mul := mul * 1.8; v_fx := v_fx || jsonb_build_object('marked', 2);
    ELSIF skill_name = '폭렬 부적' THEN mul := mul * 1.7;
    ELSIF skill_name = '봉인술' THEN mul := mul * 1.1;
    END IF;
    cc := least(0.55, crit_p / 100.0 + (CASE WHEN (v_pfx ? 'focus') THEN 0.1 ELSE 0 END));
    crit := skill_name = '급소 사격' OR random() < cc;
    IF crit AND skill_name IS DISTINCT FROM '급소 사격' THEN mul := mul * 1.6; END IF;
    mdef := a.def;
    IF coalesce((v_fx ->> 'harden')::int, 0) > 0 AND style IN ('melee', 'ranged') AND skill_name IS DISTINCT FROM '폭렬 부적' THEN mdef := mdef * 3; END IF;
    v_fx := v_fx - 'harden';
    IF skill_name = '폭렬 부적' THEN mdef := 0; END IF;
    dmg := greatest(1, round(base * mul - mdef * 0.8));
    shield := coalesce((v_fx ->> 'barrier')::int, 0);
    IF shield > 0 AND skill_name IS DISTINCT FROM '폭렬 부적' THEN
      IF style = 'magic' THEN shield := shield - dmg * 2; ELSE shield := shield - dmg; END IF;
      IF shield > 0 THEN v_fx := v_fx || jsonb_build_object('barrier', shield); lines := lines || jsonb_build_array('결계가 공격을 삼켰다.'); dmg := 0;
      ELSE v_fx := v_fx - 'barrier'; dmg := greatest(1, -shield / (CASE WHEN style = 'magic' THEN 2 ELSE 1 END)); lines := lines || jsonb_build_array('결계가 깨졌다.'); END IF;
    END IF;
    IF coalesce((v_fx ->> 'mirror')::int, 0) > 0 AND style = 'magic' AND dmg > 0 THEN
      reflect := round(dmg * 0.5); v_fx := v_fx - 'mirror';
    END IF;
    a.current_hp := greatest(0, a.current_hp - dmg);
    lines := lines || jsonb_build_array(coalesce(skill_name, CASE style WHEN 'ranged' THEN '사격' WHEN 'magic' THEN '술법' ELSE '베기' END) || ': ' || dmg || ' 피해'
      || CASE WHEN crit THEN ' (치명타)' ELSE '' END);
    IF reflect > 0 THEN hp := greatest(0, hp - reflect); lines := lines || jsonb_build_array('거울막이 술법을 되돌려 ' || reflect || ' 피해를 입었다.'); END IF;
    IF skill_name = '봉인술' THEN
      IF a.rank = 'guardian' AND random() < 0.5 THEN lines := lines || jsonb_build_array('우두머리가 봉인을 떨쳐냈다.');
      ELSE v_fx := v_fx || jsonb_build_object('stunned', 1); lines := lines || jsonb_build_array(m.monster_name || '의 움직임을 봉했다.'); END IF;
    END IF;
    wear := public.world_durability_wear(uid, 'weapon', 1);
    IF coalesce((wear ->> 'broke')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 부서졌다! 수리할 때까지 맨손만 못한 위력으로 싸운다.');
    ELSIF coalesce((wear ->> 'worn')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '의 날이 무뎌졌다. 수리가 필요하다.'); END IF;
  END IF;

  -- ② 결판
  IF a.current_hp <= 0 THEN
    ended := 'victory';
  ELSIF fled THEN
    ended := 'fled';
  ELSE
    -- ③ 요괴의 행동(예고한 대로)
    IF coalesce((v_fx ->> 'stunned')::int, 0) > 0 THEN
      skip_monster := true; v_fx := v_fx - 'stunned';
      lines := lines || jsonb_build_array(m.monster_name || '이(가) 봉인에 묶여 움직이지 못했다.');
      next_intent := public.world_battle_intent(m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank);
    END IF;
    IF NOT skip_monster THEN
      hit := a.atk * (0.9 + random() * 0.2);
      IF coalesce((v_fx ->> 'swarm')::int, 0) > 0 AND v_intent IN ('strike', 'heavy') THEN hit := hit * 1.3; v_fx := v_fx - 'swarm'; END IF;
      hit := hit * CASE v_intent WHEN 'strike' THEN 1 WHEN 'heavy' THEN 1.9 WHEN 'dive' THEN 1.7 WHEN 'pounce' THEN 2.0 WHEN 'unleash' THEN 2.6
        WHEN 'harden' THEN 0.5 WHEN 'wail' THEN 0.6 WHEN 'venom' THEN 0.6 WHEN 'mirror' THEN 0.4 WHEN 'tide' THEN 0.8 WHEN 'barrier' THEN 0.3
        WHEN 'breach' THEN 0.7 ELSE 0 END;
      v_fx := v_fx - 'airborne';
      IF v_intent = 'soar' THEN v_fx := v_fx || jsonb_build_object('airborne', true); next_intent := 'dive'; lines := lines || jsonb_build_array(m.monster_name || '이(가) 하늘로 솟구쳤다.');
      ELSIF v_intent = 'lurk' THEN next_intent := 'pounce'; lines := lines || jsonb_build_array(m.monster_name || '이(가) 그림자 속으로 숨었다.');
      ELSIF v_intent = 'charge' THEN next_intent := 'unleash'; lines := lines || jsonb_build_array(m.monster_name || '이(가) 기를 모은다.');
      ELSIF v_intent = 'harden' THEN v_fx := v_fx || jsonb_build_object('harden', 1); lines := lines || jsonb_build_array(m.monster_name || '이(가) 껍질을 굳혔다.');
      ELSIF v_intent = 'swarm' THEN
        a.current_hp := least(a.max_hp, a.current_hp + round(a.max_hp * 0.1)); v_fx := v_fx || jsonb_build_object('swarm', 1);
        lines := lines || jsonb_build_array(m.monster_name || '이(가) 무리를 불러 모았다.');
      ELSIF v_intent = 'mirror' THEN v_fx := v_fx || jsonb_build_object('mirror', 1); lines := lines || jsonb_build_array(m.monster_name || '이(가) 거울막을 둘렀다.');
      ELSIF v_intent = 'barrier' THEN v_fx := v_fx || jsonb_build_object('barrier', round(a.max_hp * 0.12)); lines := lines || jsonb_build_array(m.monster_name || '이(가) 결계를 펼쳤다.');
      ELSIF v_intent = 'rest' THEN a.current_hp := least(a.max_hp, a.current_hp + round(a.max_hp * 0.06)); lines := lines || jsonb_build_array(m.monster_name || '이(가) 숨을 골랐다.');
      END IF;
      IF hit > 0 THEN
        mdmg := round(hit * 100.0 / (100 + defv * 3));
        IF guarding THEN mdmg := round(mdmg * (CASE WHEN v_intent IN ('heavy', 'dive', 'pounce', 'unleash') THEN 0.25 ELSE 0.35 END)); END IF;
        mdmg := round(mdmg * (1 + inc / 100.0) * (1 - adr / 100.0));
        IF c.health < 30 THEN mdmg := ceil(mdmg * 1.15); END IF;
        -- 회피: 막는 중이 아닐 때 민첩에 따라 피한다. 큰 기술은 피하기 어렵다.
        IF NOT guarding AND random() * 100 < eva * (CASE WHEN v_intent IN ('heavy', 'pounce', 'unleash') THEN 0.6 ELSE 1 END) THEN
          mdmg := 0; lines := lines || jsonb_build_array('몸을 틀어 공격을 피했다.');
        END IF;
        mdmg := greatest(0, mdmg);
        hp := greatest(0, hp - mdmg);
        IF mdmg > 0 THEN
          lines := lines || jsonb_build_array(m.monster_name || CASE v_intent WHEN 'heavy' THEN '의 강타' WHEN 'dive' THEN '의 급강하' WHEN 'pounce' THEN '의 기습'
            WHEN 'unleash' THEN '의 폭발' WHEN 'venom' THEN '의 독 분사' WHEN 'wail' THEN '의 곡성' WHEN 'tide' THEN '의 물살' WHEN 'breach' THEN '의 봉인 깨기' ELSE '의 공격' END
            || ': ' || mdmg || ' 피해' || CASE WHEN guarding THEN ' (막음)' ELSE '' END);
          wear := public.world_durability_wear(uid, 'armor', 1);
          IF coalesce((wear ->> 'broke')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 찢어졌다! 수리할 때까지 막아 주지 못한다.');
          ELSIF coalesce((wear ->> 'worn')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 해어졌다. 수리가 필요하다.'); END IF;
          IF guarding AND v_intent IN ('heavy', 'dive', 'pounce', 'unleash') AND style = 'melee' THEN
            dmg := round(mdmg * 1.2 + c.strength * 0.5); a.current_hp := greatest(0, a.current_hp - dmg);
            lines := lines || jsonb_build_array('받아치기: ' || dmg || ' 피해');
          END IF;
          IF v_intent = 'wail' THEN mn := greatest(0, mn - 6); IF random() < 0.35 THEN statuses := array_append(statuses, 'shaken'); END IF; END IF;
          IF v_intent = 'venom' AND random() < 0.45 THEN statuses := array_append(statuses, 'poisoned'); END IF;
          IF v_intent = 'tide' AND random() < 0.3 THEN statuses := array_append(statuses, 'cold'); END IF;
          IF v_intent = 'breach' THEN er := least(100, er + greatest(1, round(4 * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int)); END IF;
          IF v_intent IN ('heavy', 'pounce') AND NOT guarding AND random() < 0.2 THEN statuses := array_append(statuses, 'bleeding'); END IF;
        END IF;
      END IF;
    END IF;
    IF a.current_hp <= 0 THEN ended := 'victory'; END IF;
    IF ended IS NULL AND hp <= 0 THEN
      IF coalesce((inv ->> 'revival_charm')::int, 0) > 0 AND NOT coalesce((v_pfx ->> 'revived')::boolean, false) THEN
        inv := public.world_inv_add(inv, 'revival_charm', -1); hp := 30; v_pfx := v_pfx || jsonb_build_object('revived', true);
        lines := lines || jsonb_build_array('쓰러지는 순간 회생 부적이 타올라 다시 일어섰다.');
      ELSE
        ended := 'defeat';
      END IF;
    END IF;
    IF ended IS NULL THEN
      next_intent := coalesce(next_intent, public.world_battle_intent(m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank));
    END IF;
  END IF;

  FOREACH k IN ARRAY statuses LOOP PERFORM public.world_field_status(uid, k, 'combat'); END LOOP;

  -- ④ 정리
  IF ended = 'victory' THEN
    rk_mul := CASE a.rank WHEN 'elite' THEN 1.8 WHEN 'guardian' THEN 3 ELSE 1 END;
    rare := public.world_status_effect_total('rare_loot_pct') + public.world_title_bonus('rare_loot_pct');
    xp := round((12 + a.mlevel * 6) * rk_mul * (CASE WHEN a.mlevel < c.level - 5 THEN 0.3 ELSE 1 END));
    gil_gain := round((2 + a.mlevel) * rk_mul);
    drop_p := least(1, (CASE a.rank WHEN 'elite' THEN 0.8 WHEN 'guardian' THEN 1 ELSE 0.6 END) * (1 + rare / 100.0));
    FOR k, v IN SELECT d.key, CASE WHEN jsonb_typeof(d.value) = 'number' THEN d.value::text::int ELSE 1 END FROM jsonb_each(coalesce(m.drops, '{}'::jsonb)) d LOOP
      IF EXISTS (SELECT 1 FROM public.world_item_catalog ic WHERE ic.item_id = k) AND random() < drop_p THEN
        qty := greatest(1, 1 + floor(random() * greatest(1, v))::int) * (CASE WHEN a.rank = 'guardian' THEN 2 ELSE 1 END);
        loot := public.world_inv_add(loot, k, qty);
      END IF;
    END LOOP;
    IF random() < 0.25 + rare / 100.0 THEN
      SELECT x INTO sig FROM public.world_region_profiles p, unnest(p.signature_items) x JOIN public.world_item_catalog ic ON ic.item_id = x
        WHERE p.region_id = a.region_id AND ic.tier <= 2 AND x NOT IN ('courier_token', 'spirit_compass') ORDER BY random() LIMIT 1;
      IF sig IS NOT NULL THEN loot := public.world_inv_add(loot, sig, 1); END IF;
    END IF;
    IF a.rank <> 'normal' AND random() < (CASE a.rank WHEN 'guardian' THEN 1 ELSE 0.3 END) THEN loot := public.world_inv_add(loot, 'monster_core', 1); END IF;
    IF loot = '{}'::jsonb THEN loot := public.world_inv_add(loot, CASE WHEN random() < 0.5 THEN 'spirit_dust' ELSE 'beast_bone' END, 1); END IF;
    FOR k, v IN SELECT key, value::text::int FROM jsonb_each(loot) LOOP inv := public.world_inv_add(inv, k, v); END LOOP;
    lines := lines || jsonb_build_array(m.monster_name || '을(를) 쓰러뜨렸다.');
    v_result := jsonb_build_object('outcome', 'victory', 'monster', m.monster_name, 'rank', a.rank, 'level', a.mlevel, 'xp', xp + 24, 'gil', gil_gain, 'loot', loot);
  ELSIF ended = 'defeat' THEN
    hp := 0;
    lines := lines || jsonb_build_array('정신이 아득해진다… 쓰러졌다.');
    v_result := jsonb_build_object('outcome', 'defeat', 'monster', m.monster_name);
  ELSIF ended = 'fled' THEN
    v_result := jsonb_build_object('outcome', 'fled', 'monster', m.monster_name);
  END IF;

  UPDATE public.world_characters SET health = hp, mental = mn, spiritual_power = sp, erosion = er,
    erosion_stage = CASE WHEN er >= 80 THEN 4 WHEN er >= 55 THEN 3 WHEN er >= 30 THEN 2 WHEN er >= 10 THEN 1 ELSE 0 END,
    inventory = inv, gil = gil + gil_gain, experience = experience + greatest(0, xp), updated_at = now()
  WHERE owner_id = uid;

  UPDATE public.world_active_encounters SET current_hp = a.current_hp, turn_count = turn, fx = v_fx, pfx = v_pfx,
    intent = CASE WHEN ended IS NULL THEN next_intent ELSE v_intent END,
    defeated = coalesce(ended = 'victory', false), fled = coalesce(ended IN ('fled', 'defeat'), false), result = v_result,
    log = (SELECT coalesce(jsonb_agg(x ORDER BY o), '[]'::jsonb) FROM (SELECT x, o FROM jsonb_array_elements(a.log || lines) WITH ORDINALITY t(x, o) ORDER BY o DESC LIMIT 14) s),
    last_action_at = now(), updated_at = now()
  WHERE owner_id = uid;

  IF ended = 'victory' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'combat', m.monster_name || ' 토벌' || CASE a.rank WHEN 'elite' THEN '(정예)' WHEN 'guardian' THEN '(우두머리)' ELSE '' END,
      jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id, 'monster_name', m.monster_name, 'defeated', true,
        'mechanic', m.mechanic_key, 'action', CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'seal' ELSE 'attack' END,
        'rank', a.rank, 'level', a.mlevel, 'loot', loot, 'turns', turn));
  ELSIF ended = 'defeat' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'battle_lost', m.monster_name || '에게 쓰러졌습니다.', jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id));
  ELSIF ended = 'fled' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'battle_fled', m.monster_name || '에게서 달아났습니다.', jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id));
  END IF;

  RETURN jsonb_build_object('ok', true, 'lines', lines, 'ended', ended, 'result', v_result, 'damage', dmg, 'taken', mdmg, 'heal', heal,
    'crit', crit, 'health', hp, 'battle', public.world_field_battle_view(uid), 'next_action_at', now() + interval '2 seconds');
END $f$;

-- 실행 권한: 새 RPC만 로그인 사용자에게 열고, 칭호 판정은 기록 트리거를 소유한 역할만 부른다.
DO $$
DECLARE f record; ro text;
  rpc text[] := ARRAY['world_title_snapshot', 'world_title_set_display', 'world_battle_action', 'world_field_search', 'world_field_gather', 'world_expedition_complete'];
BEGIN
  FOR f IN SELECT p.oid::regprocedure AS sig, p.proname FROM pg_proc p JOIN pg_roles r ON r.oid = p.proowner
           WHERE p.pronamespace = 'public'::regnamespace AND r.rolname = 'fn_owner_field'
             AND p.proname IN ('world_title_rule_ok', 'world_title_award_check', 'world_title_snapshot', 'world_title_set_display', 'world_chat_stamp_title',
                               'world_battle_action', 'world_field_search', 'world_field_gather', 'world_expedition_complete') LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f.sig);
    IF f.proname = ANY (rpc) THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f.sig); END IF;
  END LOOP;
  FOR ro IN SELECT DISTINCT r.rolname FROM pg_proc p JOIN pg_roles r ON r.oid = p.proowner
            WHERE p.pronamespace = 'public'::regnamespace AND p.prosrc LIKE '%world_title_award_check%' AND p.proname <> 'world_title_award_check'
              AND r.rolname NOT IN ('postgres', 'fn_owner_field') LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.world_title_award_check(uuid, text) TO %I', ro);
  END LOOP;
END $$;
RESET ROLE;

-- 이미 쌓인 기록으로 얻을 수 있는 칭호를 지금 한 번 정리한다.
SET ROLE fn_owner_field;
SELECT public.world_title_award_check(owner_id, NULL) FROM public.world_characters WHERE NOT coalesce(is_dead, false);
RESET ROLE;
