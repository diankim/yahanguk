-- 7.5.9g — 퀘스트 장면 목표(goal) 문구: 물품을 정한 채집은 캔 개수로 세므로 「세 번 채집」을 「세 개 모으기」처럼 고친다(사용자 요청).
-- 토벌·탐색·제작·낚시 횟수(「2번 쓰러뜨린다」 등)는 그대로. 고친 목표는 38줄.
update public.world_quest_steps s set goal = v.g
  from (values
  ('aq_archivebureau', 2, '장서각 지하서고에서 먹정을 2개 거두고 책벌레 요괴를 2번 쓰러뜨린다'),
  ('aq_fieldbureau', 3, '귀죽림에서 약제 바탕과 부적목 수지를 2개씩 거둬 수지를 건넨다'),
  ('aq_medicalbureau', 3, '연화원에서 약제 바탕과 월광 이끼를 2개씩 거둬 약제 바탕을 건넨다'),
  ('jq_analyst', 2, '백지교에서 정제 황지를 3개, 연무장·팔괘진에서 부적목을 3개 거둬 둘씩 건넨다'),
  ('jq_exorcist', 3, '방울먹는 무녀귀를 쓰러뜨리고, 사당에서 부적실을 2개 거둬 방울을 다시 맨다'),
  ('jq_medic', 2, '잿빛 들녘에서 야령초를 4개, 약제 바탕을 2개 거둬 온다'),
  ('jq_sealmaster', 2, '폐쇄 사당에서 황지를 3개 거두고 금줄식귀를 2번 쓰러뜨린다'),
  ('mq_drowned_ledger', 4, '염등촌에서 수귀 비늘을 세 개 모아 노들에게 건넨다'),
  ('mq_frost_seal', 4, '빙혼곡에서 빙정염을 세 개 모아 백무에게 건넨다'),
  ('mq_red_seal', 4, '잿빛 들녘에서 야령초를 세 개 모아 모가람에게 건넨다'),
  ('rq_comet_crater', 2, '혜성 낙하지에서 성진사를 2개 거둔다'),
  ('rq_ember_pass', 2, '불씨 고개에서 숯을 4개 거둔다'),
  ('rq_snow_hollow', 3, '설피골에서 월광 이끼를 3개 거둔다'),
  ('rq_star_hill', 3, '별바라기 언덕에서 운면을 2개 거둔다'),
  ('rq_water_clock', 2, '물시계 터에서 영유리를 2개 거두고 누리에게 생 월철 3개를 건넨다'),
  ('sq_ash_coast_1', 2, '재의 해안에서 수향 갈대 세 개 모으기'),
  ('sq_ash_mountain_1', 2, '생 월철을 네 개, 월철 광석을 두 개 캔다'),
  ('sq_burial_steps_2', 2, '만인장에서 원령재를 네 개 모아 세 줌 건넨다'),
  ('sq_burial_steps_2', 3, '비석 까마귀를 쫓고 황지를 두 개 모은다'),
  ('sq_crimson_mine_2', 2, '주혈 광산에서 월철 광석 세 개, 생 월철 두 개 모으기'),
  ('sq_ember_village_1', 2, '부적목 세 개를 모아 잔불촌으로 돌아오기'),
  ('sq_ember_village_2', 2, '월철 광석 세 개, 생 월철 두 개 모으기'),
  ('sq_hidden_bazaar_2', 2, '만인장에서 요기 결정을 세 개 모은다'),
  ('sq_hq_dorm_1', 2, '잿빛 들녘에서 야령초를 3개 캐 온다'),
  ('sq_hq_training_2', 2, '연무장에서 부적목을 3개 베어 온다'),
  ('sq_lantern_market_1', 2, '잿빛 들녘에서 야령초를 4개 캐 온다'),
  ('sq_lotus_marsh_1', 2, '천엽 연화늪에서 월광 이끼 세 개 모으기'),
  ('sq_mirror_pavilion_1', 2, '수경루에서 귀경 파편 세 개 모으기'),
  ('sq_red_forest_1', 2, '혈엽림에서 영맥 수피와 약제 바탕 두 개씩 모으기'),
  ('sq_salt_village_2', 2, '염등촌에서 농축 약초액 세 개 모으기'),
  ('sq_sealed_abyss_2', 2, '구중 봉연에서 응축 영핵을 세 개 모은다'),
  ('sq_sealed_abyss_2', 3, '구중 봉연을 두 번 살피고 요기 결정을 세 개 모은다'),
  ('sq_sealed_garden_2', 2, '연화원에서 약제 바탕을 2개 캐고 안신탕을 1번 만든다'),
  ('sq_thunder_peak_1', 2, '뇌명봉에서 응축 영핵과 요기 결정을 세 개씩 캐고 영핵 둘을 넘긴다'),
  ('sq_under_root_1', 2, '지맥의 뿌리에서 응축 영핵을 세 개 모은다'),
  ('sq_under_root_1', 3, '뿌리 지네를 물리치고 요기 결정을 세 개 모아 영핵 둘을 건넨다'),
  ('sq_white_tower_1', 2, '백옥 천문탑에서 성진사를 세 개 모은다'),
  ('sq_white_tower_1', 3, '별빛 나비 떼를 쫓고 귀경 파편을 두 개 모아 성진사 둘을 건넨다')
  ) v(q, n, g)
 where s.quest_id = v.q and s.step = v.n and s.goal is distinct from v.g;

update public.world_app_meta set value = '20261104130000' where key = 'db_version';
