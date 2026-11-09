# 묵적록(2.0.0) — CLAUDE.md에 합칠 것

생성기 supabase/gen_mukjeok/(data_world.py·data_quests.py·a_level.sql·b_rules.sql·patch_note.sql·gen.py, 이름 사전 ref/existing_names.json ← dump_names.py) → migrations/20261116000000_world_2_0_0_mukjeok.sql.
돌리는 법: `python3 supabase/gen_mukjeok/dump_names.py --dsn="…"`(마이그레이션 전 DB로, 이름 사전) → `python3 supabase/gen_mukjeok/gen.py > supabase/migrations/20261116000000_world_2_0_0_mukjeok.sql` (겹치는 이름이 있으면 멈춤).

## 규칙(§ 자리에 한 줄씩)

- §2 최고 레벨 45(쌓아 둘 능력치 포인트 132): 수치는 world_level_rules() 한 곳(cap·per_level·stat_points_cap) → world_level_cap()·world_stat_points_cap()이 world_event_char_apply·world_grant_xp·world_claim_idle_activity·world_xp_damp_apply·world_xp_damp_pct·world_expedition_gear에 들어감 → gamedata level → core.js LEVEL_CAP·guide.js. 경험치 식 그대로(Lv44 → 45 27,632).
- §3.2 출입 레벨 최고 45(생성기 CAP). 요괴 레벨 상한: 일반 min(45, L+3), 정예 min(46, L+6).
- §3.3 안전지대 11곳(묵창 나루 더함, 빈약한 안전지대 — world_weak_safe_rules). 빈약한 안전지대의 상점 판정은 world_weak_shop(상점) 하나(world_shop_refresh·world_shop_buy·world_smithy_snapshot이 부름, 옛 'banyo_shop' 박은 곳 없앰), 거절 문구의 장소 이름은 world_weak_name(uid)(창고·역참·의뢰 게시판·별채·거래소 문구가 「묵창 나루에는 …」으로). 하루 개수(daily_cap)는 상점마다(sc.shop_id = s.shop_id).
- §3.5 다음에 「§3.5b 묵적록」: 영역 mukjeok(world_domain_rules 한 줄 — open_quest gq_5·no_shadow·rare meokgwi_lump·fx). 지역 다섯 묵창 나루 Lv40(빈약한 안전지대, 상점 mukchang_shop 「묵창 주막」, 숙소 묵창 주막)·빈칸 벌판 41·먹비 숲 42·명부 탑 44·아홉 칸 뜰 45, 좌표 (310,128)~(52,172) 지도 왼쪽 위, 들어가는 길은 빙혼곡 ↔ 묵창 나루 하나. 날씨 world_weather_climate mukjeok(세우·담운·장우·농무·청명·삭풍, 혈무·설한 없음). geo.js buildCells로 확인: 기존 이웃 관계 잃은 것 0, 나루–빙혼곡 맞닿음.
- 영역 효과(지역 규칙) world_domain_rules().<영역>.fx 한 칸: effects(효과 키 → 값)·name(늘 보이는 상태 이름, 없으면 상태판에 안 보임)·guard(막는 상태 키). world_domain_fx(uid)(지금 있는 영역의 fx + guard_until)·world_domain_effect(키)(막는 상태가 있으면 0). world_island_effect는 이것을 부르는 한 줄(귀허도 침식 +60도 이 칸으로 옮김, 순응 acclimate는 그대로). world_hud_snapshot.domain → hud.js domainNow·domainChip·domainPin(요화처럼 늘 보임, 상태 칸에 안 셈), 문구 rules.js DOMAIN_FX.
- 이름 흐림(mukjeok fx): 정신 손실 +15%·받는 피해 +5%·조우 +5%, 막는 상태 clear_name 「또렷한 이름」 120분(이름 새김 탕)·name_ward 「이름 지킴」 60분(이름 먹 부적).
- §7 낚시: 낚시터는 지역마다 물 갈래 하나씩(world_fish_grounds 기본 키 (region_id, habitat) — 묵창 나루는 강 「먹물 여울」·바다 「묵창 앞바다」 둘). world_fish_at(p_habitat, p_bait)가 yh.fish_habitat·yh.fish_bait을 켜고 world_fish()를 부름(화면은 늘 이것으로, changes.js `^world_fish(_at)?$`). world_fish_spot.grounds = world_fish_ground_list(uid, 지역)(낚시터마다 이름·설명·도감 수·named(못 낚으면 이름 null, 힌트)·baits(가방에 있는 이 낚시터 명어의 미끼만)). 화면 home.js fishPanel·bindFish·redrawFish(낚시터 칩 yh-fish-hab:<지역>, 미끼 yh-fish-bait).
- 명어: world_fish_species.named, 물 갈래마다 하나·그 낚시터에서만(grounds)·시간대·날씨 둘 다 맞고 미끼(bait_for에 그 명어가 든 물고기)를 걸었을 때만 굴림에 듦. 무게 world_fish_rules.named.weight 0.3 + 낚싯대 named_wt, 희귀 보정은 boost 0.5배, 시간대·날씨 배수(×3)는 안 받음, 미끼는 던질 때마다 named.bait 1마리(걸리든 말든). 미끼가 셋 아래인 명어가 있으면 마이그레이션이 멈춤. 명어 물품·명어로 만든 것은 거래 불가. 낚시 날씨 제약에 세우(drizzle) 더함.
- §7 장비 1~7단계(7단계 묵적록 장착 Lv42, world_item_catalog_tier_check 1~7, world_normalize_item_rarity 7단계 = 신품·drop_rate 0.03). 7단계 장비 32 + 채집도 lt_knife_8 = 33(귀허 6단계 짜임), 드롭 world_gear_drops Lv41~45. 7단계 생활 도구 12(lt_knife_8·lt_pick_7·lt_sickle_7·lt_lantern_7·lt_compass_7·lt_rod_7·lt_rod_7b 용비늘 낚싯대(거래 불가, named_wt 0.1)·lt_hammer_7·lt_needle_7·lt_carve_7·lt_still_7·lt_cook_7), world_tool_lines 사슬에 이음. 모두 묵창 나루 제작(장소 덤).
- 시세: 7단계 = max(재료값×1.2, 같은 칸 6단계 최고가×1.15), 소모품·가구 = max(기준가, 재료값÷개수×1.1).

## 제안값(사용자 확인 필요)

- 지역 좌표·위험도(나루 9·바깥 10)·나루 숙박비 160·주막 상점 값(이름 먹 부적 780·먹귀 쫓는 향 720·먹비 우산 690, 하루 4개) — 귀허도(반요촌)를 따름.
- 새 보통 어종 출현 레벨 20~28(범품 20·양품 24·진품 28), 어디서나(같은 물 갈래). 명어 최소 레벨 40.
- 새 상태: 먹귀 쫓김(조우 −20%·정신 손실 −5%, 1시간), 먹비 가림(받는 피해 −8%, 1시간), 어둠 눈(단서 +6%), 빈칸 메움(침식 −30%), 먹비 걷힘(입질 +10·채집량 +8%), 붓끝 정신(기술 경험 +10%), 용안(희귀품·단서 +5%), 순한 물길(이동 −10%·받는 피해 −5%). 기획의 「먹비 숲 받는 피해 −」「원정 받는 피해 −5%」는 지역·원정 한정 효과 키가 없어 어디서나 붙는 받는 피해로 넣음.
- 7단계 장비 수치: 6단계 ×약 1.2(위력 58/68/52/54 등), 장착 능력치 조건은 같은 식(Lv42).
- 가구 여덟: 문패 장식·죽간 발(1단계, 주막 상점·제작) · 먹 연못 깔개·먹비 창호(2단계, 일반 전리품·제작) · 명부 책장(3단계, 우두머리·원정·제작) · 아홉 칸 주춧돌 등(4단계, 칭호 「아홉 칸을 지나온 이」 한 번) · 문패 잉어 어탁·장어 수조(5단계, 명어 제작, 거래 불가).
- 칭호 12(분류 「묵적록」): 나루 도착·다섯 곳 도착·문패 조각 20번·흑단 20번·우두머리 넷·명어 여섯 각각(숨김)·명어 모두(숨김). 테두리 fr_mukjeok(다섯 곳 도착 칭호), 낙관 sl_muk 「墨」(명어 모두), 이름 색 1031 「먹빛 금」(묵적록 칭호 6개, world_name_styles 규칙 'cat').
- 비워 둔 자리: 외전 「묵적록」 완주 칭호·꾸미기, 5장 우두머리(먹그림자) 처치 칭호·꾸미기·가구 — 보스 작업이 끝나면 같은 분류 「묵적록」에 더함(이름 색 6개 문턱에 들어감).

## 못 한 것·물어볼 것

- 기존 귀허도 지역의 깊은 답사 지점은 4.0/7.0 때 최고 40으로 묶여 있음(Lv38 귀허 L5 = 40). 이번에 45로 풀면 Lv40 조사원이 들어가던 곳이 막혀 그대로 둠.
- 묵적록 배경음악 편성(sound.js PROFILES)은 없어 직할령 곡으로 나옴.
- 지도 물길(water.js): 나루 강·명부 탑 수로·벌판 늪·먹비 숲 못·뜰 우물을 대강 그림 — 화면에서 모양 확인 필요.

## 외전 「묵적록」 퀘스트(data_quests.py)

- mkq_1~mkq_5(kind side, cat 「외전·묵적록」, Lv40·41·42·44·45, 정렬 1300~). mkq_1의 after = gq_5·sq110_e_ink·sq110_e_doorplate(외전 암시 퀘스트에서 이어짐 — 둘을 빼려면 이 한 줄). 받는 곳 1장 본부 정청·2장 빈칸 벌판·3·4장 묵창 나루·5장 아홉 칸 뜰.
- 대사는 script.md를 그대로 읽어 만든다(gen.py 때 파싱 — 대본을 고치면 다시 돌리면 됨). 고친 자리는 FIX 표 한 곳(plan_world.md 「대본 고칠 곳」 다섯 + 그로 이어지는 첫 줄): 1장 2 강둑·1장 3 강둑/주막·3장 3 「내일 주막으로」·3장 4 「이튿날 주막」·3장 7 길목 지시·4장 1·2 길목 들렀다 다온의 집. 첫 장면에는 할 일을 못 두므로(받기 전이라 셀 때가 없음) 3장 끝의 벌판 길목 탐색은 4장 장면 2의 할 일로 옮김.
- 나루 안 조사 지점 할 일은 모두 없앰(나루가 안전지대) — 2장 「이름 없는 사당」은 빈칸 벌판 탐색 2회(조사 지점 「빈칸 벌판 · 이름 없는 사당」이 탐색으로 나옴).
- 새 할 일 갈래 rest(쉬기, world_events rest 기록, r = 지역): world_faction_task_count·world_faction_task_label에 한 줄, 화면 changes.js TASK_ACTS rest. 1장 장면 4 「묵창 나루 주막에서 쉬기」.
- 5장 장면 2 할 일 {t:'mj', n:1} 자리만(보스 엔진이 셈·라벨을 채울 때까지 마칠 수 없음, 라벨도 빈 글). 싸움 중 기억 조각 줄은 ref/mj_fight_lines.json(보스 작업자 몫).
- 결말은 5장 마지막 장면 대사 끝에 붙임(외전 틀). 보상: 할 일 장면에 0.6×xp_need(L) 나눔, 마지막 장면 전 20+10L·물품(외전 값). 결말 카드 표식 「먹 자국」은 보스·완주 몫으로 비워 둠.
