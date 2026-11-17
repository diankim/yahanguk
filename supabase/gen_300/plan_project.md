# 세력 거점 사업 · 공동 사업 — 구현 직전 설계안 (11/17, 사용자 검토 전)

따르는 결정: plan_side.md §4.1·4.2·4.3(11/17). plan.md 「세력 거점 사업(3.1.0 안)」의 옛 생각 중 **토벌·탐색·기부·의뢰로 몫이 들어오는 길은 빼고 납품만**으로 했다(4.1이 「납품」으로 정함 — 다시 넣을지는 §8 질문 1).
물품 id·이름·단계·시세는 로컬 복제 DB(yh_300, 11/12 운영 복사본)에서 읽은 값. 등도 물품은 3.0.0 생성기(world/data_world.py) 값이고, 8단계 장비 시세는 생성기가 정한다.

---

## 1. 짜임

### 1.1 표 (RLS 켬·정책 없음 — 함수로만)

| 표 | 열 | 비고 |
|---|---|---|
| `world_projects` | `project_key` text pk(`f:<세력>` · `c:gwiheo` · `c:mukjeok` · `c:deungdo`), `stage` int 0~5(마친 단계 수), `points` bigint(지금 단계 몫), `goal` bigint, `goal_n` int, `goal_day` date, `total` bigint, `stage_at` timestamptz[], `updated_at` | 10줄. 단계는 영구(4.3), 5단계 뒤엔 `points`가 안 차고 `total`만 오름 |
| `world_project_contrib` | `project_key`, `owner_id`, `total` bigint(누계), `cur` bigint(지금 단계 몫), `day` date, `day_pts` int, `marks` int[](기여 1%↑로 기념품을 받은 단계) | pk (project_key, owner_id). **캐릭터 정리 대상**(world_character_purge에 한 줄, precheck ACCOUNT_TABLES 아님) |

- 행동 기록(world_events)은 남기지 않는다 — 칭호는 `contrib.total`을 규칙 `project`로 셈(§4.3). 납품 한 번 = 캐릭터 행 갱신 **한 번**(가방 + 전), 공훈은 world_faction_progress, 창고는 world_storage.
- 세력을 떠나도 그 세력 사업의 `contrib`는 남음(칭호 누계는 세력 사업 전부를 합침).

### 1.2 규칙 함수 한 곳 — `world_project_rules()` (immutable jsonb, 생성기가 만듦)

```
{ pay:    { faction: {per_merit: 40, day_cap: 2400},          -- 몫 40 = 공훈 1, 하루 2,400몫(공훈 60)
            common:  {gil_rate: 0.8, day_cap: 6000} },          -- 몫 1 = 0.8전, 하루 6,000몫(4,800전)
  urgent: {n: 2, mul: 1.5}, hq_mul: 1.5, mul_cap: 2,            -- 급히·우수품 겹치면 ×2.25 → ×2로 자름
  goal:   {window_h: 72, active_min: 60, recalc: 'day'},        -- 영향력과 같은 「움직인 사람」 기준
  memento:{pct: 1, faction_merit: 20, common_gil_pct: 0.5},     -- 단계 몫의 1%↑ 낸 사람
  carry: true,                                                  -- 단계를 넘친 몫은 다음 단계로
  projects: { 'f:night_office': { kind:'faction', faction:'night_office', name:'청사 다시 세우기',
                hubs:['hq_yard','hq_dorm'], area:[…거점+이웃], land:[…본래 땅],
                stages:[ {base:14000, items:[{id, v, lv, kind:'craft'|'gather'}×8], perk:{…}} ×5 ] },
              'c:gwiheo': { kind:'common', domain:'gwiheo', story:'gq_5', hubs:['banyo_village'], … } } }
```
- `v`(1개 기준 몫)는 생성기가 미리 셈: 채집 재료 = 시세, 제작품 = min(시세, 가장 싼 제작법 재료값 ÷ 개수 × 1.2). 장비의 시세가 재료값보다 훨씬 높게 잡혀(§12 시세 규칙) 전으로 바꾸면 남는 장사가 되는 것을 막는다.
- → `tools/gamedata/gen.py`가 `gamedata.project`로 뽑음(이름·단계 혜택 문구·몫·상한) → `rules.js PROJECT` 문구 → 화면·도움말.

### 1.3 몫·목표

| 항목 | 식 |
|---|---|
| 몫(한 번 넘김) | Σ `v` × 수량 × (급히면 1.5) × (우수품이면 1.5), 겹치면 최대 ×2 |
| 목표 | `base[단계]` × max(1, √n) |
| n (세력) | 지난 72시간에 10분 칸 여섯 이상 움직인 **그 세력** 조사원 수 |
| n (공동) | 같은 기준으로 움직였고 **그 영역이 열린**(world_domain_open) 조사원 수 |
| n 다시 셈 | 한국 시각 날마다 그날 첫 납품 때 한 번(`goal_day`). 목표가 지금 몫 아래로 내려가면 그 자리에서 단계가 참 |
| 한 사람 하루 | 세력 2,400몫 · 공동 6,000몫(그 땅마다). 남은 상한이 0보다 크면 받고, 마지막 한 번은 넘쳐도 받음(장비 하나가 상한보다 클 수 있어서) |
| 급히 필요 | 날마다 둘: 그 단계 8품목을 md5(키·단계·한국 날짜) 순으로 놓은 앞 둘(예약 작업 없음, 화면도 같은 식을 gamedata로 셈하지 않고 view가 줌) |

- 「움직인 사람 수」 셈은 지금 world_influence_score 안에 박혀 있다 → **`world_active_actors(p_at, p_window)`(움직인 owner_id 목록) 한 곳으로 빼서** 영향력 점수와 사업이 함께 씀(한 규칙 한 곳).

### 1.4 RPC

| 함수 | 인자 | 돌려줌 | 잠금·검사 |
|---|---|---|---|
| `world_project_view(p_key text default null)` | 비우면 지금 선 곳의 사업(세력 거점이면 내 세력, 공동 안전지대면 그 땅) | `{key, kind, name, stage, points, goal, goal_n, total, items:[{id,name,tier,v,urgent,have,have_st,have_hq,lv}], today:{pts,cap}, mine:{total,cur}, perks:[{stage,done,text}], can:{give, why}, benefit:{ok, why}}` | 읽기만. `have_st`는 창고를 쓸 수 있을 때만(공동은 3단계 이상·이야기를 마친 사람) |
| `world_project_give(p_key text, p_items jsonb)` | `{"물품 id": 수, "물품 id_hq": 수}` — 우수품은 따로 셈 | `{pts, merit | gil, today, stage_up:[단계…], memento, view}` | `world_travel_guard('사업 납품')`·`world_seal_guard()`. 세력: 가입 퀘스트 마침·거점(world_faction_home) 안. 공동: 그 땅 안전지대(hubs) 안·영역 열림. 캐릭터 행 for update → 창고(쓸 때) → `world_projects` 행 for update → contrib upsert. 거르기는 기부와 같은 것(잠금·장착 마지막 하나·강화 장비·임무 물품) — **world_faction_donate_info의 거르기 부분을 `world_give_check(uid, 물품, 수)` 한 곳으로 빼서 둘이 함께** |
| `world_project_brief(uid)` | — | 상태판·현장에 실을 가벼운 값 `{key, stage, pct}` (거점·공동 안전지대에 서 있을 때만) | world_field_snapshot.project로 실음 — 요청 추가 없음 |

- 재료 빼기는 `world_materials_take`(가방 → 창고). 우수품을 「그것만」 빼는 판이 없어 **넷째 인자 `p_exact boolean default false`**를 더함(기존 호출 그대로).
- 단계가 차는 처리는 같은 트랜잭션: `stage+1`, `stage_at` 덧붙임, 기여 `cur ≥ goal×1%`인 사람에게 기념품(§4.2)·`marks`, 모든 `cur`를 0(그 사업 줄만, 드묾), 알림·채팅. 넘친 몫은 다음 단계로(`carry`).
- 동시성: 같은 사업에 여럿이 넘겨도 `world_projects` 한 줄 잠금으로 차례. 같은 사람 연타는 캐릭터 행 잠금 + 가방 수 재검사로 이중 차감 없음.

### 1.5 단계 판정 도우미 (한 곳)

| 도우미 | 쓰는 곳 |
|---|---|
| `world_project_stage(p_key) → int` (SQL, 인라인) | 아래 모두 |
| `world_project_shop_ok(uid, shop, item) → bool` | world_shop_refresh(단계 전엔 안 들임)·world_shop_snapshot(그 세력 조사원에게만 보임)·world_shop_buy |
| `world_project_area_fx(uid, key) → numeric` | world_social_effect 한 줄(2단계 지역 효과) |
| `world_project_route(uid, from, to) → {cut, free}` | world_travel_plan 끝에서 한 번(3단계 지름길·공동 2단계) |
| `world_weak_lift(uid, region, key) → bool` | §3 빈약한 안전지대 풀기 |

---

## 2. 세력 거점 사업 (일곱)

공통 규칙
- 단계 목표 base: **14,000 · 16,000 · 17,000 · 18,000 · 20,000몫**(×max(1,√n)).
- 넘기는 곳: world_faction_home(정통파 정청·객사, 천명원은 관성대·객사 분소 둘 다).
- 품목 8 = 제작품 넷 + 채집 재료 넷. 1단계는 Lv1~10이면 낼 수 있는 것, 단계가 오를수록 그 세력 땅 깊은 곳(Lv15~28)·4단계 장신구·생선 요리. 거래소 전용(비취·귀경 파편·뇌철·성진사·요핵·잔화 결정·천공 깃털·각인판·강화 요수 가죽)·명어·거래 불가 물품은 넣지 않음.
- 단계 혜택(4.1 순서): 1 상점 새 품목 둘 → 2 지역 효과(거점과 이웃, 그 세력 조사원) → 3 지름길(거점 ↔ 본래 땅 이동 −20%·운임 없음, 그 세력 조사원) → 4 비고 새 품목(그 세력 것 둘 + §5 공통 품목 일부) → 5 세력 바탕 무늬 `pt_f_<세력>`(그 세력 조사원 모두) + 거점 머리 그림.
- 상점 새 품목: 그 세력 거점 상점 상시(회차마다 늘 들어옴), 값 = 시세 × 1.3, 하루 5개, 그 세력 조사원만 보이고 삼. 모두 지금 어느 상점에도 없는 물품.

표기: `id 이름(단계·시세)`. Lv = 제작법 최저 레벨이나 그 재료가 나는 가장 낮은 그 세력 땅.

### 2.1 정통파 (night_office) — 「청사 다시 세우기」 · 본부 정청·객사 · 땅 Lv1~26

| 단계 | 제작품 넷 | 채집 재료 넷 |
|---|---|---|
| 1 | ward_talisman 정화 부적(1·75) · iron_ingot 월철 주괴(1·50) · tonic 청심환(1·60) · fine_paper 정제 황지(2·80) | seal_paper 황지(1·20) · raw_iron 생 월철(1·20) · ward_fragment 결계 파편(2·65) · ghost_ash 원령재(2·65) |
| 2 | sealing_ink 봉인 먹(2·65) · repair_kit 장비 수리 도구(2·150) · clear_spirit_pill 청령단(2·100) · lumber 가공 부적목(1·40) | talisman_thread 부적실(1·85) · medicine_base 약제 바탕(1·85) · spirit_dust 요기 결정(2·65) · venom_gland 독낭(2·65, 귀죽림 4) |
| 3 | revival_charm 회생 부적(3·320) · spirit_qi_pill 영기환(3·200) · snakehead_broth 가물치 곰국(3·150) · spirit_glass 영유리(2·190) | herbal_extract 농축 약초액(2·90) · spirit_bark 영맥 수피(3·260) · steel_ingot 강철 주괴(3·450, 회산 관문 7) · charcoal 정련 숯(1·20, 순라청 12) |
| 4 | rejuv_pill 회춘단(3·370) · spirit_core 응축 영핵(3·260) · carp_broth 잉어 고음(3·160) · m3_ward 철패 호신부(3·350) | lantern_oil 등롱 어유(3·140, 봉인고 26) · ghost_goby 원귀 망둥어(3·55, 침수 구시가지) · canal_eel 수로 뱀장어(2·18) · sealing_ink 봉인 먹(채집, 순라청 12) |
| 5 | moonlight_essence 월광 정수(4·640) · m4_ward 금강 호신부(4·660) · grand_pill 대환단(4·980) · t3_gather 청강 채집도(3·900) | steel_ingot 강철 주괴 · spirit_bark 영맥 수피 · lantern_oil 등롱 어유 · ghost_goby 원귀 망둥어 |

| 혜택 | 내용 |
|---|---|
| 1 상점 | night_office_store + rejuv_pill 회춘단 · calm_brew 안신탕 |
| 2 지역 | 정청·객사와 이웃(장서각·백지교·잿빛 들녘·백등 야시장·연무장·침수된 구시가지·구룡 폐수로) — 회복 +5 · 정신 손실 −5 |
| 3 지름길 | 정청·객사 ↔ 귀죽림·침수된 구시가지·회산 관문·옛 순라청·옛 의금부 옥사·봉인고 |
| 4 비고 | 가구 「청사 처마 등」 hf_fp_night(벽 등롱, 진품, 3등급 220) · 장신구 「순라 갓끈」 of_acc_fp_night(3등급 200) |
| 5 꾸미기·머리 | 바탕 무늬 「청사 기와 무늬」 pt_f_night · 머리 그림: 처마 끝 청사초롱이 단계마다 하나씩(1·3·5단계 셋), 5단계에 「夜行局」 깃발 둘 |

### 2.2 적월교 (red_moon_cult) — 「장터 제단 고치기」 · 백골 장터 · 땅 Lv5~22

| 단계 | 제작품 넷 | 채집 재료 넷 |
|---|---|---|
| 1 | iron_ingot 월철 주괴 · ward_talisman 정화 부적 · lacquer 칠액(1·40) · tonic 청심환 | cinnabar 주사 광물(2·65) · ore 월철 광석(1·22) · raw_iron 생 월철 · ghost_ash 원령재 |
| 2 | k3_ghost 먹중탈(3·260, Lv10) · sealing_ink 봉인 먹 · calm_brew 안신탕(2·155) · repair_kit 장비 수리 도구 | beast_bone 요수 뼈(2·65) · ward_fragment 결계 파편 · spirit_dust 요기 결정 · talisman_thread 부적실 |
| 3 | bronze_charm 청동 호신패(3·460) · revival_charm 회생 부적 · purify_water 청정수(2·260) · spirit_qi_pill 영기환 | spirit_glass 영유리(유리협곡 8) · medicine_base 약제 바탕 · ward_talisman 정화 부적(채집, 월식성 15) · cinnabar 주사 광물 |
| 4 | skate_ferment 삭힌 홍어(3·160, 월식 홍어) · rejuv_pill 회춘단 · m3_purify 침향 향낭(3·350) · spirit_core 응축 영핵 | eclipse_skate 월식 홍어(3·85, 월식성) · herbal_extract 농축 약초액(핏빛 모래바다 17) · beast_bone 요수 뼈 · spirit_glass 영유리 |
| 5 | k4_ghost 노장탈(4·630) · m4_purify 용연향 향낭(4·660) · grand_pill 대환단 · moonlight_essence 월광 정수 | cinnabar 주사 광물(제단터 22) · raw_iron 생 월철(제단터) · spirit_glass 영유리 · herbal_extract 농축 약초액 |

| 혜택 | 내용 |
|---|---|
| 1 상점 | frontier_market + exp_elixir_tiger 맹호 비약 · skate_ferment 삭힌 홍어 |
| 2 지역 | 백골 장터·서문 폐성벽·유리협곡·회산 관문·적사 황무지 — 회복 +5 · 희귀품 +3 |
| 3 지름길 | 백골 장터 ↔ 적사 황무지·유리협곡·흑사단 폐단·적월교 월식성·핏빛 모래바다·적월 제단터 |
| 4 비고 | 가구 「월식 제단 향로」 hf_fp_redmoon · 아랫옷 「붉은 달 행전」 of_acc_fp_redmoon |
| 5 꾸미기·머리 | 「월식 무늬」 pt_f_redmoon · 머리 그림: 장터 장대에 붉은 천 깃발이 늘고, 5단계에 달 모양 제등 |

### 2.3 흑련회 (black_lotus) — 「암시장 장부고 넓히기」 · 십삼문 암시장 · 땅 Lv5~21

| 단계 | 제작품 넷 | 채집 재료 넷 |
|---|---|---|
| 1 | sealing_ink 봉인 먹 · fine_paper 정제 황지 · ward_talisman 정화 부적 · tonic 청심환 | seal_paper 황지 · inkstone 먹정(1·20) · ghost_ash 원령재 · spirit_dust 요기 결정 |
| 2 | spirit_thread 영사 실타래(2·150) · flounder_sashimi 광어회(2·90) · lacquer 칠액 · repair_kit 장비 수리 도구 | silk 영사(2·65) · shadow_fang 잠복귀 송곳니(2·65) · talisman_thread 부적실 · drowned_scale 수귀 비늘(2·65) |
| 3 | k3_hide 소무탈(3·260) · revival_charm 회생 부적 · fish_oil_lamp 어유 등잔(3·90) · spirit_qi_pill 영기환 | lantern_oil 등롱 어유(연등 하수도 7) · ward_fragment 결계 파편 · frost_salt 빙정염(2·65) · ink_greenling 먹빛 노래미(3·70) |
| 4 | m3_spell 비단 부적낭(3·350) · rejuv_pill 회춘단 · spirit_core 응축 영핵 · goby_soup 망둥어 맑은국(3·100) | lamp_hairtail 백등 갈치(3·70) · ghost_goby 원귀 망둥어 · medicine_base 약제 바탕 · shadow_fang 잠복귀 송곳니 |
| 5 | k4_hide 처용탈(4·630) · m4_spell 옥 부적낭(4·660) · ray_steam 무광 가오리찜(4·420) · moonlight_essence 월광 정수 | spirit_core 응축 영핵(지맥의 뿌리 21) · lantern_oil 등롱 어유 · ink_greenling 먹빛 노래미 · sealing_ink 봉인 먹(채집) |

| 혜택 | 내용 |
|---|---|
| 1 상점 | underworld_market + dark_eye_drops 어둠 눈 약 · ray_steam 무광 가오리찜 |
| 2 지역 | 십삼문·옛 순라청·등잔골·지맥의 뿌리·흑련 장부고·구룡 폐수로 — 회복 +5 · 단서 +5 |
| 3 지름길 | 십삼문 ↔ 등잔골 뒷골목·연등 하수도·만인장·무명 고도·흑련 장부고·지맥의 뿌리 |
| 4 비고 | 가구 「장부지기 서가」 hf_fp_lotus · 장신구 「장부지기 토시」 of_acc_fp_lotus |
| 5 꾸미기·머리 | 「연잎 장부 무늬」 pt_f_lotus · 머리 그림: 골목 처마에 검은 연꽃 등이 늘고, 5단계에 장부 걸린 줄 |

### 2.4 북령맹 (north_league) — 「고찰 겨울채비」 · 철벽 고찰 · 땅 Lv5~27

| 단계 | 제작품 넷 | 채집 재료 넷 |
|---|---|---|
| 1 | iron_ingot 월철 주괴 · medicine_base 약제 바탕(1·85) · lumber 가공 부적목 · travel_ration 노정 건량(1·50) | frost_salt 빙정염 · beast_hide 요수 가죽(2·65) · charcoal 정련 숯 · resin 부적목 수지(1·25) |
| 2 | trout_sashimi 송어회(2·70) · repair_kit 장비 수리 도구 · clear_spirit_pill 청령단 · herbal_extract 농축 약초액(2·90) | moon_moss 월광 이끼(2·65) · drowned_scale 수귀 비늘 · ore 월철 광석 · lake_trout 송어(2·24) |
| 3 | salmon_grill 산천어 구이(3·110) · cod_soup 대구탕(3·220) · spirit_qi_pill 영기환 · reinforced_lumber 강화 부적목(2·310) | spirit_core 응축 영핵(빙혼곡 11) · ward_fragment 결계 파편 · cherry_salmon 산천어(3·65) · cod 대구(3·80) |
| 4 | char_grill 곤들매기 구이(3·120) · bark_stew 영맥 약선탕(3·230) · rejuv_pill 회춘단 · lt_hammer_3 강철 단조 망치(3·710) | ice_char 얼음 곤들매기(3·80, 천년 빙하 27) · raw_iron 생 월철 · spirit_core 응축 영핵 · beast_hide 요수 가죽 |
| 5 | mirror_soup 천경 맑은탕(4·360) · steel_ingot 강철 주괴(3·450) · grand_pill 대환단 · lt_pick_3 청강 곡괭이(3·1070) | spirit_glass 영유리(천년 빙하) · mirror_whitefish 천경 백어(4·190) · ice_char 얼음 곤들매기 · spirit_core 응축 영핵 |

| 혜택 | 내용 |
|---|---|
| 1 상점 | north_market + exp_elixir_iron 철벽 비약 · cod_soup 대구탕 |
| 2 지역 | 철벽 고찰·천경호·옥문 협로·백지교·빙혼곡·뇌명봉·설피골 — 회복 +5 · 채집 +5 |
| 3 지름길 | 고찰 ↔ 설피골·서리솔 고개·빙혼곡·천경호·뇌명봉·천년 빙하 |
| 4 비고 | 가구 「설산 맹약 북」 hf_fp_north · 장신구 「눈길 털모자」 of_acc_fp_north |
| 5 꾸미기·머리 | 「설산 능선 무늬」 pt_f_north · 머리 그림: 고찰 담에 장작더미·횃불이 늘고, 5단계에 맹약 깃발 |

### 2.5 수향연맹 (river_alliance) — 「나루 뱃길 고치기」 · 구름나루 · 땅 Lv3~24

| 단계 | 제작품 넷 | 채집 재료 넷 |
|---|---|---|
| 1 | spirit_tea 영초 차(1·30) · fish_porridge 어죽(1·70) · tonic 청심환 · lumber 가공 부적목 | river_reed 수향 갈대(1·20) · drowned_scale 수귀 비늘 · medicine_base 약제 바탕 · seal_paper 황지 |
| 2 | sweetfish_grill 은어 소금구이(2·60) · eel_tonic 장어 보양탕(2·130) · purify_water 청정수 · clear_spirit_pill 청령단 | moon_moss 월광 이끼(연화늪 7) · venom_gland 독낭 · herbal_extract 농축 약초액 · golden_carp 금빛 잉어(3·55) |
| 3 | catfish_braise 메기찜(3·110) · carp_broth 잉어 고음 · revival_charm 회생 부적 · reinforced_lumber 강화 부적목 | fine_paper 정제 황지(수경루 9) · spirit_glass 영유리(수궁 14) · ink_catfish 먹물 메기(3·50) · palace_lanternfish 수궁 등롱어(3·90) |
| 4 | wraith_soul_pill 귀어 환혼단(4·300) · yellowtail_sashimi 방어회(3·150) · lt_rod_3 청죽 낚싯대(3·900) · lantern_oil 등롱 어유(제작) | reinforced_lumber 강화 부적목(잠든 포구 19, 채집) · marsh_wraithfish 늪 귀어(4·160) · croaker 민어(3·75) · lumber 가공 부적목(채집) |
| 5 | koi_broth 용린 잉어 고음(5·800) · bream_sashimi 용왕 참돔 회(4·260) · moonlight_essence 월광 정수 · grand_pill 대환단 | dragon_bream 용왕 참돔(180) · frost_salt 빙정염(갑문 24) · lantern_oil 등롱 어유(채집) · spirit_glass 영유리 |

| 혜택 | 내용 |
|---|---|
| 1 상점 | river_market + purify_water 청정수 · eel_tonic 장어 보양탕 |
| 2 지역 | 구름나루·옥문 협로·염등촌·수경루·잿빛 들녘·연화늪·폐쇄 사당 — 회복 +5 · 조우 −5 |
| 3 지름길 | 구름나루 ↔ 염등촌·연화늪·수경루·용잠 수궁·잠든 포구·만조의 갑문(뱃길 속도·운임 없음 혜택과 겹치면 운임 없음은 하나, 시간은 곱함) |
| 4 비고 | 가구 「나룻배 노 걸이」 hf_fp_river · 윗옷 「뱃사공 저고리」 of_top_fp_river |
| 5 꾸미기·머리 | 「물길 무늬」 pt_f_river · 머리 그림: 나루에 매인 돛배·등 단 장대가 늘고, 5단계에 연맹 깃발 단 큰 배 |

### 2.6 남명회 (southern_remnant) — 「잔불 화덕 다시 피우기」 · 잔불촌 · 땅 Lv5~28

| 단계 | 제작품 넷 | 채집 재료 넷 |
|---|---|---|
| 1 | iron_ingot 월철 주괴 · lacquer 칠액 · lumber 가공 부적목 · travel_ration 노정 건량 | ore 월철 광석 · raw_iron 생 월철 · resin 부적목 수지 · charcoal 정련 숯 |
| 2 | dried_croaker 굴비(2·70) · k3_ghost 먹중탈 · repair_kit 장비 수리 도구 · ward_talisman 정화 부적 | cinnabar 주사 광물 · ward_fragment 결계 파편 · drowned_scale 수귀 비늘 · yellow_croaker 조기(2·26) |
| 3 | hairtail_braise 갈치조림(3·140) · croaker_soup 민어탕(3·220) · revival_charm 회생 부적 · spirit_qi_pill 영기환 | spirit_glass 영유리(재의 해안 10) · steel_ingot 강철 주괴(주혈 광산 12) · lamp_hairtail 백등 갈치 · red_scorpionfish 붉은 쏨뱅이(2·28) |
| 4 | grouper_steam 다금바리 찜(4·400) · lt_cook_4 청강 식칼(4·750) · k4_hide 처용탈 · rejuv_pill 회춘단 | venom_gland 독낭(혈엽림 18) · spirit_bark 영맥 수피 · croaker 민어 · void_hagfish 흑조 먹장어(2·40) |
| 5 | haeryong_feast 해룡 어보찜(5·1300) · lt_still_4 영유리 증류기(4·1440) · ember_gall_pill 잔불 쓸개 환(4·940) · grand_pill 대환단 | starless_ray 무광 가오리(4·240, 흑조 균열 28) · abyss_angler 심연 초롱아귀(110) · steel_ingot 강철 주괴 · spirit_bark 영맥 수피 |

| 혜택 | 내용 |
|---|---|
| 1 상점 | south_market + fish_oil_lamp 어유 등잔 · hairtail_braise 갈치조림 |
| 2 지역 | 잔불촌·불씨 고개·흑조 균열·무명 고도·주혈 광산·재의 해안·혈엽림 — 회복 +5 · 받는 피해 −3 |
| 3 지름길 | 잔불촌 ↔ 불씨 고개·재의 해안·주혈 광산·구등대 군도·혈엽림·흑조 균열 |
| 4 비고 | 가구 「잔불 화덕」 hf_fp_south · 장신구 「불씨 두건」 of_acc_fp_south |
| 5 꾸미기·머리 | 「불씨 무늬」 pt_f_south · 머리 그림: 마을 굴뚝 연기와 화톳불이 늘고, 5단계에 남명 깃발 |

### 2.7 천명원 (mandate_court) — 「관성대 별 기록 잇기」 · 무극 관성대(+객사 분소) · 땅 Lv5~25

| 단계 | 제작품 넷 | 채집 재료 넷 |
|---|---|---|
| 1 | fine_paper 정제 황지 · talisman_thread 부적실(1·85) · spirit_tea 영초 차 · ward_talisman 정화 부적 | cloud_cotton 운면(2·65) · moon_moss 월광 이끼 · spirit_dust 요기 결정 · seal_paper 황지 |
| 2 | sealing_ink 봉인 먹 · spirit_thread 영사 실타래 · clear_spirit_pill 청령단 · lumber 가공 부적목 | ghost_ash 원령재 · ward_fragment 결계 파편 · raw_iron 생 월철 · inkstone 먹정 |
| 3 | spirit_glass 영유리 · purify_water 청정수 · spirit_qi_pill 영기환 · reinforced_lumber 강화 부적목 | lumber 가공 부적목(물시계 터 13, 채집) · spirit_thread 영사 실타래(채집) · fine_paper 정제 황지(채집) · talisman_thread 부적실(채집) |
| 4 | moonlight_essence 월광 정수 · m4_spell 옥 부적낭 · rejuv_pill 회춘단 · lt_lantern_3 어유 등(3·680) | reinforced_lumber 강화 부적목(채집) · spirit_bark 영맥 수피(회랑 23) · spirit_glass 영유리(채집) · croaker 민어 |
| 5 | marlin_grill 청새치 별빛구이(4·380) · dragon_feast 흑룡 어보탕(5·1300) · lt_lantern_4 청등(4·1080) · grand_pill 대환단 | starlit_marlin 성하 청새치(4·260) · spirit_bark 영맥 수피 · dragon_bream 용왕 참돔 · cloud_cotton 운면 |

| 혜택 | 내용 |
|---|---|
| 1 상점 | astral_market + exp_elixir_clear 청명 비약 · marlin_grill 청새치 별빛구이 |
| 2 지역 | 관성대·구름 위 회랑·수경루·백옥 천문탑·뇌명봉(객사 분소는 빼고) — 회복 +5 · 희귀품 +2 · 단서 +3 |
| 3 지름길 | 관성대 ↔ 별바라기 언덕·옥문 협로·물시계 터·혜성 낙하지·백옥 천문탑·구름 위 회랑 |
| 4 비고 | 가구 「작은 혼천의」 hf_fp_mandate · 윗옷 「별 수놓은 도포」 of_top_fp_mandate |
| 5 꾸미기·머리 | 「성도 무늬」 pt_f_mandate · 머리 그림: 관성대 위 별 깃발·혼천의 고리가 늘고, 5단계에 별자리 등 |

- 지역 효과는 world_social_effect가 받는 키(채집·희귀품·회복·조우·정신 손실·받는 피해·단서)에서만 골랐다. 수치는 기존 「내 세력 지배 땅」 덤(채집 +8·희귀품 +3·회복 +5)과 겹쳐도 넘치지 않게 그보다 작게.
- 머리 그림: `scenery.js sceneArt(theme, phase, weather, deco)` 넷째 인자 `{faction, stage}`로 앞땅 위에 `ln-deco` 한 겹(등롱·깃발·장대 — 세력 색 `--sc` 그대로, 평면). 값은 world_field_snapshot.region.project(§1.4 brief)에서.

---

## 3. 공동 사업 셋 (모든 조사원, 그 땅 빈약한 안전지대에서 납품)

공통 규칙
- base: **34,000 · 38,000 · 42,000 · 46,000 · 50,000몫**(×√n). 보상은 전(몫 × 0.8).
- **넘기기는 그 땅에 갈 수 있는 누구나, 혜택은 그 땅 이야기를 마친 사람만**(4.3): 귀허도 gq_5 · 묵적 mkq_5 · 등도 mdq_17.
- 지름길(2단계): 그 땅 안전지대 ↔ 가까운 바깥 안전지대, 시간 −30%·운임 없음(수치 §8 질문 4).

### 3.1 막힘을 푸는 한 곳 — `world_weak_lift(p_uid, p_region, p_key)`

```
world_weak_lift(uid, region, key) =
  world_weak_safe(region)
  and (rules.projects 중 hubs에 region이 든 사업 P가 있음)
  and world_project_stage(P) >= rules.lift[key]
  and world_quest_done(uid, P.story)
```
- 판정 키·단계(`rules.lift`): shop 1 · route 2 · storage 3 · market 4 · stable 4 · letter 3 · ucomm 4 · repair 5 · sell 5 · smithy 5 · house 5.
- 지금 사람마다 판정하는 `world_banyo_here(uid)`를 **`world_weak_here(uid, key)` = 빈약한 곳 and not world_weak_lift**로 바꾸고, 부르는 곳마다 키를 넣는다. `world_banyo_here(uid)`는 `world_weak_here(uid, 'any')`(풀리지 않음)로 남겨 지역 단위 판정만 쓰게. 지역 단위(world_weak_safe(region)) — 비무회 개최지(world_tourney_ensure)·조사원 의뢰 게시판 here는 그대로(사람마다 다를 수 없음).

| 단계 | 푸는 것 | 키 | 고치는 함수(지금 world_banyo_here/weak_shop/has_stable 자리) |
|---|---|---|---|
| 1 | 상점 품목 4 → 6가지(**모두에게** — 상점 회차는 사람마다 나눌 수 없음) + 새 품목 둘 + 하루 개수 ×2(이야기 마친 사람) | shop | world_shop_refresh(품목 수: world_weak_shop → 단계 ≥1이면 보통 수) · world_shop_buy·world_shop_snapshot(daily_cap × 2) |
| 2 | 지름길 | route | world_travel_plan → world_project_route |
| 3 | 창고 열림·제작/강화/옷 짓기에 창고 재료·서신 물품 | storage · letter | world_storage_check · world_storage_snapshot(use_here) · world_craft_item · world_weapon_enhance · world_enhance_quote · world_outfit_design_weave · world_letter_place_check |
| 4 | 거래소·마구간·조사원 의뢰 | market · stable · ucomm | world_guard_action_context(trade unit_price 줄) · world_mount_acquire·world_mount_train·world_field_snapshot(has_stable 자리 → `has_stable or world_weak_lift(uid, region, 'stable')`, 마구간 목록은 가장 가까운 정청 마구간과 같은 것) · world_ucomm_place_check |
| 5 | 수리비 ×1 · 되팔기·판매 한도 보통 · 대장간 보통 · 별채 고치기 + 머리 그림 | repair · sell · smithy · house | world_repair_mult · world_shop_sell · world_shop_sell_status · world_smithy_snapshot·world_shop_buy(smithy 줄 — 거르기를 사람마다) · world_housing_edit_block |

- 화면: 지금 `rules.js weakSafe(region)`으로 숨기는 곳(home.js town 거래소·창고 칸, item.js 바로 맡기기)은 **서버가 주는 world_field_snapshot.region.weak = {storage, market, stable, …}(풀리면 false)**로 바꿈 — 문구는 그대로 WEAK_NAMES.
- 등도는 두 곳(남문 수로 선착·등지기 쉼막)이 한 사업(hubs 둘). 「백야」 구조대 막힘(no_rescue)은 빈약한 안전지대 규칙이 아니라 손대지 않음.

### 3.2 귀허도 — 「반요촌 살림 일으키기」 c:gwiheo · 반요촌 · Lv30~38

| 단계 | 제작품 넷(그 땅 재료로 만든 것) | 채집 재료 넷 |
|---|---|---|
| 1 | ashwhisker_herbal_soup 잿빛 메기 약선(4·1010, Lv30) · lt_cook_6 귀허 식칼(6·2450) · lt_needle_6 무월 비단 바늘(6·2480) · lt_hammer_6 귀허 흑철 망치(6·2930) | reed_silk 갈대 영사(4·380, 잿빛 갈대숲 30) · inverted_incense 거꾸로 향목(4·380, 33) · banyo_scale 반요 비늘(3·300, 토벌) · ashwhisker_catfish 잿빛 수염 메기(5·1120, 낚시) |
| 2 | lt_still_6 망각 수정 증류기(6·3050) · lt_carve_6 귀허 각인도(6·2920) · s6_road 갈대 짚신(6·4830) · s6_sturdy 흑철 장화(6·4830) | moonless_silk 무월 비단(4·400, 36) · oblivion_crystal 망각 수정(4·420, 36) · ghost_ash 원령재(거꾸로 선 사당) · yoin_blood 요인 혈정(4·520) |
| 3 | lt_sickle_6 망각 수정 낫(6·3580) · lt_rod_6 귀허 진주 낚싯대(6·3410) · s6_swift 무월 비단신(6·4830) · h6_calm 망각 관모(6·5635) | gwiheo_iron 귀허 흑철(4·480, 귀허 38) · spirit_core 응축 영핵(귀허) · yoin_blood 요인 혈정 · reed_silk 갈대 영사 |
| 4 | h6_guard 흑철 투구 · h6_wise 거꾸로 익선관 · lt_pick_6 귀허 흑철 곡괭이(6·4520) · t6_gather 귀허 흑철 채집도(6·4560) | gwiheo_pearl 귀허 진주(5·900) · oblivion_crystal 망각 수정 · gwiheo_iron 귀허 흑철 · inverted_incense 거꾸로 향목 |
| 5 | n6_plenty 반요촌 풍년 노리개(6·6440) · k6_awe 반요 탈 · m6_ward 귀허 문지기 호패 · k6_ghost 사공 탈 | gwiheo_pearl 귀허 진주 · yoin_blood 요인 혈정 · banyo_scale 반요 비늘 · moonless_silk 무월 비단 |

| 혜택 | 내용 |
|---|---|
| 1 | banyo_shop 6가지 + rejuv_pill 회춘단 · moonlight_essence 월광 정수(반요촌 값 규칙 — 시세×3.5 안팎), 하루 개수 ×2 |
| 2 | 지름길 반요촌 ↔ 십삼문 암시장(지맥의 뿌리·구중 봉연 길) |
| 3~5 | §3.1 표대로 |
| 5 머리 | 갈대 지붕에 반요 등(푸른 불) 줄이 걸리고 장터 천막 둘 |

### 3.3 묵적 — 「묵창 나루 넓히기」 c:mukjeok · 묵창 나루 · Lv40~45

| 단계 | 제작품 넷 | 채집 재료 넷 |
|---|---|---|
| 1 | meokgwi_incense 먹귀 쫓는 향(4·480) · name_ink_charm 이름 먹 부적(4·619) · meokbi_umbrella 먹비 우산(4·693) · carp_glue 잉어 비늘 아교(3·120) | mukchang_ink 묵창 갈대 먹(4·360, 40) · blank_hanji 빈칸 한지(4·360, 40) · erased_plate 지워진 문패 조각(4·380, 40) · meokgwi_lump 먹귀 응어리(3·300, 토벌) |
| 2 | lt_cook_7 묵창 식칼(7·3508) · lt_carve_7 먹귀 각인도 · lt_still_7 먹비 증류기 · rainproof_oil 먹비 막이 기름(5·900) | meokbi_moss 먹비 이끼(4·380, 42) · meokbi_ebony 먹비 흑단(4·420, 42) · drifting_name_thread 떠도는 이름 실(4·420) · mukchang_ink 묵창 갈대 먹 |
| 3 | lt_rod_7 묵창 낚싯대(7·3922) · lt_compass_7 명부 나침반(7·4623) · register_eel_grill 명부 장어 구이(5·1400) · salmon_ink_grill 산천어 먹구이(5·1400) | register_slip 명부 죽간(4·440, 44) · bamboo_eel 죽간 대장어(5·1500) · meokbi_salmon 먹비 대산천어(5·1500) · blank_hanji 빈칸 한지 |
| 4 | s7_road 억새 짚신(7·5555) · s7_swift 먹비 비단신 · h7_calm 이름 지킴 관모(7·6481) · name_carving_soup 이름 새김 탕(5·1400) | doorplate_carp 문패 잉어(5·1500) · meokbi_ebony 먹비 흑단 · erased_plate 지워진 문패 조각 · spirit_core 응축 영핵(아홉 칸 뜰 45) |
| 5 | n7_plenty 나루 풍년 노리개(7·7406) · m7_purify 먹비 향낭 · k7_ghost 먹귀 탈 · tuna_ink_feast 다랑어 먹회 한 상(5·1400) | inkscale_tuna 먹비늘 다랑어(5·1500) · register_slip 명부 죽간 · drifting_name_thread 떠도는 이름 실 · meokgwi_lump 먹귀 응어리 |

| 혜택 | 내용 |
|---|---|
| 1 | mukchang_shop 6가지 + grand_pill 대환단 · heavenly_dew 천령 감로, 하루 개수 ×2 |
| 2 | 지름길 묵창 나루 ↔ 철벽 고찰(빙혼곡 길) |
| 5 머리 | 나루 말뚝에 먹등 줄·빨래처럼 널린 한지, 배 한 척 |

### 3.4 등도 — 「흰 밤 나루 살리기」 c:deungdo · 남문 수로 선착 + 등지기 쉼막 · Lv45~50

| 단계 | 제작품 넷 | 채집 재료 넷 |
|---|---|---|
| 1 | night_tea 밤빛 차(3·300) · ember_ash_pill 불씨 재 환(4·360) · smelt_clear_soup 빙어 맑은국(2·80) · burrow_scale 물굴 비늘(3·150, 제작) | century_form_scrap 백 년 서식 조각(4·420, 꺼진 관아 45) · white_night_frost 흰 밤 서리(4·320) · bleached_lantern_paper 바랜 등롱 종이(4·380) · frozen_arrow_shaft 멈춘 화살대(4·400, 무관 거리 46) |
| 2 | myeongdeung_lamp 명등 등롱(4·900) · cheong_carp_steam 청씨 잉어찜(3·220) · lt_cook_8 선착 식칼 · lt_needle_8 등롱 실 바늘 | severed_lamp_oil 끊긴 등 기름(4·380) · red_shrine_lacquer 붉은 사당 옻(4·420, 47) · frost_bell_iron 언 종루 쇠(5·460) · lamp_wick_core 명등 심지(5·480, 토벌) |
| 3 | lt_carve_8 서식 각인도 · lt_still_8 등 기름 증류기 · lt_hammer_8 종루 쇠 망치 · lt_rod_8 물굴 낚싯대 | waterlogged_plank 물 먹은 뱃판(4·400, 옛 나루 저자 48) · faded_star_glass 바랜 별유리(5·460, 49) · star_record_plate 별 기록 동판(5·480, 49) · white_night_frost 흰 밤 서리 |
| 4 | lt_sickle_8 서리 날 낫 · lt_lantern_8 명등 손등 · lt_compass_8 별 기록 나침반 · h8_calm 명등지기 관 | king_ember_ash 임금 불씨 재(5·480, 잿빛 왕궁 49) · ledger_tab 정리 명부 갈피(4·360, 정리소) · balance_weight 가늠 저울추(5·500, 정리소) · severed_lamp_oil 끊긴 등 기름 |
| 5 | lt_pick_8 저울추 곡괭이 · lt_knife_9 뱃판 자루 채집도 · a8_light 뱃판 누빔 경갑 · a8_robe 명등지기 법의 | pact_stone_dust 맹약 돌가루(5·520, 맹약 마당 50) · lamp_wick_core 명등 심지 · king_ember_ash 임금 불씨 재 · frost_bell_iron 언 종루 쇠 |

| 혜택 | 내용 |
|---|---|
| 1 | deungdo_landing_shop·lamp_rest_shop 6가지 + grand_pill 대환단 · heavenly_dew 천령 감로(쉼막엔 불씨 재 환이 이미 있음), 하루 개수 ×2 |
| 2 | 지름길 남문 수로 선착 ↔ 본부 정청(봉인고·옥사·순라청 길 — 정리소 이야기와 맞춤), 선착 ↔ 쉼막은 운임 없음만 |
| 5 머리 | 흰 하늘 아래 선착 돌계단에 켜진 명등이 늘어서고(백야 덧그림 위) 쉼막 처마에 등 일곱 |

- 등도 8단계 장비 시세가 1만 전 안팎이라 `v`(재료값×1.2 상한) 덕에 하나 넘겨도 공동 하루 상한(6,000몫)에 한 번에 닿음 — 「하루 장비 한 벌」이 되도록 맞춘 값.

---

## 4. 납품 보상

### 4.1 몫당 보상과 견줌

| 견줄 것 | 지금 | 사업 |
|---|---|---|
| 세력 기부 | 시세 50전 = 공훈 1, 하루 30 | **몫 40 = 공훈 1, 하루 60**(2,400몫). 아무거나 받는 기부보다 「정한 물품」이라 조금 낫게 |
| 의뢰판 | 하루 셋 × 공훈 15 ≈ 45 | 사업을 다 채워도 하루 공훈 합 ≈ 135(기부 30 + 의뢰 45 + 사업 60) — 비고 최고가 600(탈것)이 4~5일 |
| 상점 되팔기 | 시세 × 0.45, 하루 2,000전 | 공동: 몫 × 0.8전, 하루 6,000몫(4,800전) |
| 거래소 | 시세 안팎 − 수수료 10% | 채집 재료는 시세 × 0.8(거래소보다 조금 싸지만 살 사람을 안 기다림), 제작품은 재료값 × 1.2 × 0.8 ≈ 재료값 × 0.96 — **그냥 내면 거의 본전, 급히·우수품이면 1.4배 남음** |
| 상시 의뢰 납품 | 시세×수량×1.2+30+5L, 하루 셋 | 그보다 낮지만 횟수 제한이 없고 상한 안에서 여러 번 |

- 몫은 전이 사라지는 곳이 없어 새 전이 생김(공동) → 서버 전체 한 주 상한 ≈ 사람 × 4,800 × 7. 20명 서버에서 다 채워도 하루 10만 전 아래 — 지금 상시 의뢰(하루 셋 Lv30 약 2,000전)와 같은 자리. 5단계 뒤에도 납품은 되지만 보상을 **절반**(gil_rate·per_merit ×0.5)으로(질문 5).

### 4.2 단계가 찰 때 (기여 = 그 단계에 낸 몫이 목표의 1% 이상)

| | 세력 사업 | 공동 사업 |
|---|---|---|
| 모두에게 | 알림 `project_stage`(갈래 **새 갈래 `project`** — 설정 › 알림 「사업」) + 전체 채팅 「세력 소식」 | 알림 `project_stage` + 전체 채팅 **새 이름 「사업 소식」**(world_sys_chat_names·rules.js SYS_CHAT에 함께) |
| 기여한 사람 | 공훈 +20 · 「낙성 떡」 3(새 소모품, 체력 30·정신 10·든든함, 거래 불가, 공통) | 전 = 단계 목표 × 0.5% · 「낙성 떡」 3 |
| 5단계 기여 | + 가구 「낙성 기념패」 hf_proj_plaque(공통, 명품, 거래 불가 — 패에 세력/땅 이름은 별채 그림이 정보로 그림) | + 낙관 「拓」 sl_tak(그 땅 하나라도) |

### 4.3 누계 기여 칭호 — 분류 **「사업」**, 규칙 `{project: 'faction'|'c:<땅>'|'all', n}` → world_project_rule_count(contrib.total 합)

| 키 | 이름 | 등급 | 조건 | 효과(안) |
|---|---|---|---|---|
| pj_f_1 | 거점의 짐꾼 | 범품 | 세력 사업 누계 5,000몫 | 채집 +2 |
| pj_f_2 | 거점의 일꾼 | 양품 | 30,000몫 | 제작 품질 +2 · 채집 +2 |
| pj_f_3 | 거점을 세운 손 | 진품 | 100,000몫 | 제작 품질 +3 · 희귀품 +1 |
| pj_f_x | 주춧돌 | 명품(숨김) | 한 세력 사업 다섯 단계 모두 기여 | 제작 품질 +4 · 회복 +3 |
| pj_c_gw | 반요촌 살림꾼 | 양품 | 귀허도 사업 20,000몫 | 정신 손실 −3 |
| pj_c_mk | 묵창 나루 뱃사람 | 양품 | 묵적 사업 20,000몫 | 침식 −3 |
| pj_c_dd | 흰 밤의 등지기 | 진품 | 등도 사업 30,000몫 | 정신 손실 −3 · 회복 +2 |
| pj_c_all | 먼 땅의 물주 | 진품 | 공동 사업 합 150,000몫 | 채집 +3 · 희귀품 +1 |
| pj_c_x | 세 나루를 연 사람 | 명품(숨김) | 세 땅 모두 5단계에 기여 | 이동 −3 · 회복 +3 |

- 판정은 납품 함수가 문턱을 넘는 순간 world_title_award_check(uid, 'project') 한 번(행동 기록 없이, 선배와 새내기 칭호와 같은 틀).

---

## 5. 새 공통 공훈 품목 (일곱 세력 비고에 같은 줄, 세력 사업 단계로 열림)

world_faction_vault에 열 **`stage_need int default 0`** 하나 더함(기존 줄은 0). 비고가 「그 세력 사업 단계 ≥ stage_need」일 때만 보이고 팖(world_faction_vault_buy·world_faction_snapshot).

| 물품 | 갈래 | 새/기존 | 공훈 | 등급 | 사업 단계 |
|---|---|---|---|---|---|
| 「자재 궤짝」 hf_proj_crate | 가구(바닥 1×1, 양품) | 새 | 90 | 1 | 1 |
| 「사업 일꾼 조끼」 of_top_proj_vest | 윗옷 | 새 | 120 | 2 | 1 |
| 「일꾼 수건」 of_acc_proj_towel | 장신구(머리) | 새 | 80 | 1 | 1 |
| 「노정패 묶음」 tk_bundle | 소모품(쓰면 노정패 +10, use_fx 새 키 `tokens`) | 새 | 30 | 1 | 1 |
| 「동무 새참 바구니」 pet_treat_box | 동무 먹이(어느 동무든 좋아하는 별미로 침 +12, world_pet_act 한 줄) | 새 | 15 | 1 | 2 |
| 「납품 수레」 hf_proj_cart | 가구(바닥 2×1, 진품, 위에 소품) | 새 | 180 | 2 | 2 |
| 옷 꾸러미 of_bundle | 옷 뽑기 | 기존(비고엔 없음) | 60 | 2 | 2 |
| 「공사 깃대」 hf_proj_pole | 가구(바닥 1×1, 진품, 깃발 색 = 놓은 사람 세력 색) | 새 | 200 | 3 | 3 |
| 얼룩무늬 알 pet_egg_2 | 동무 알 | 기존 | 120 | 3 | 3 |
| 머리 그리기 도안 hair_pattern | 소모품 | 기존(비장고에만 있던 것) | 150 | 3 | 4 |
| 「상량 현판」 hf_proj_beam | 가구(벽, 명품) | 새 | 300 | 4 | 5 |

- 새 가구 5는 furniture.js(그림·크기 한 곳) → 생성기가 물품 행. 새 옷 둘은 tools/avatar_art tops_art.py → parts.json. 비고 가구·옷은 지금처럼 거래 불가. 낙성 기념패·세력별 4단계 가구/옷(§2)은 이 표와 따로.

---

## 6. 화면

| 곳 | 무엇 |
|---|---|
| 캐릭터 › 세력 칸 | 단추 「거점 사업」(급히 필요 품목을 가방에 가졌으면 빨간 점 — titledot.js DOTS에 한 줄, 값은 view를 연 뒤 캐시라 따로 묻지 않음) → openPop |
| 거점 현장(세력 안전지대) | 띠 한 줄 「청사 다시 세우기 2단계 · 63%」 + 「납품」 단추(world_field_snapshot.project — 요청 추가 없음) |
| 공동 안전지대 현장(반요촌·묵창 나루·선착·쉼막) | 시설 칸 「공동 사업」 타일(상점·대장간 옆), 같은 띠 |
| 납품 창 **views/project.js openProject(key)** | 머리: 단계 사다리(5칸, 마친 칸 금빛·다음 혜택 글) · 진행 막대(몫/목표, 「n명 기준 목표」 `?`) · 오늘 내 몫/상한 · 내 누계. 몸: 8품목 카드(.pj-items — PC 네 칸·휴대폰 두 칸): 이름(물품 정보 열림)·단계·「급히」 칩·1개 몫·가방 n·창고 n·우수 n·「얻는 곳」(sources.js). 아래 「골라 넘기기」 → **views/itempick.js openItemPick many**(행 = 8품목 중 가진 것만 pickRows, 수량 qtyHtml, 우수품은 hq.js pairOf로 줄 나눔) → 확인 창(받을 공훈/전·상한 넘김 경고) → world_project_give |
| 이야기를 안 마친 사람(공동) | 창 머리에 「혜택은 ○○를 마치면」 한 줄(benefit.why), 넘기기는 됨 |
| 도움말 | guide.js 묶음 「세력」에 「거점 사업」, 「경제」에 「공동 사업」(gamedata.project로 단계·혜택·몫·상한·급히·우수품·칭호 표) |
| 다시 읽기 | changes.js CHANGES: `project_give` → 가방·창고(storageIfUsed)·세력 칸(공훈)·캐릭터(전)·칭호 점. 퀘스트 판은 안 버림(사업은 퀘스트 할 일이 아님) |
| 현장 채집터 표시(안) | quests.js markNeeded처럼 「사업」 칩을 급히 필요 채집 재료에 — 질문 7 |

gamedata로 나갈 것: pay(per_merit·gil_rate·day_cap)·urgent·hq_mul·mul_cap·goal(window·active_min)·memento·stages(base·perk 문구)·items(id·v·kind)·lift(공동 단계 키)·칭호 수.

---

## 7. 생성기와 시험

- 위치 **supabase/gen_300/project/**: `data.py`(PROJECTS 한 표 — 사업·거점·단계 base·품목·혜택·꾸미기·칭호·공통 비고 품목) · `a_tables.sql`(표·열·도우미) · `b_give.sql`(view·give·brief·give_check·materials_take p_exact) · `c_lift.sql`(world_weak_lift·world_weak_here와 §3.1 함수들 고치기 — pg_temp.yh_fix로 조각 바꿈) · `d_perks.sql`(상점·지역 효과·지름길·비고) · `patch_note.sql`. **world/gen.py에 붙임**(ultimate처럼 importlib로 data.py를 읽어 world_project_rules()를 쓰고 part()).
- gen.py 검사(어기면 멈춤): 품목 id가 있음 · 거래 가능 · 거래소 전용 아님 · 명어 아님 · 제작품은 제작법이 있음 · 채집 재료는 world_item_sources에 얻는 곳이 있음 · 한 단계 8품목이 서로 다름 · 상점 새 품목이 그 상점에 이미 없음 · 새 이름(가구·옷·칭호·꾸미기) 겹침(ref/existing_names.json) · `v` 계산.
- 시뮬(복제 DB 밖, 파이썬 — tools/sim 아님 gen_300/project/sim.py): 세력마다 지금 인원·레벨(복제 DB 11/12 값: 정통파 11·천명 4·수향 4·적월 3·흑련 3·남명 3·북령 1)로 「하루 낼 수 있는 몫」을 레벨·채집 숙련·낚시로 뽑아 단계마다 걸리는 날을 잼. 목표: **4명 한 단계 1주 안팎**, 1명(북령) 2주 안팎(하루 상한 때문에 최소 6일), 11명(정통파) 4일 아래로는 안 내려감.
  - 어림(1인 하루 1,200몫): 4명 5.8~8.3일 · 1명 11.7~16.7일 · 11명 3.5~5일 — 정통파가 빠른 것은 √n 틀의 결과(질문 2).
  - 공동(활동 n 12, 실제로 넘기는 사람 8, 1인 하루 2,500몫): 단계마다 6~9일.
- 복제 DB 시험: 동시 납품(같은 사업 두 사람·같은 사람 연타)·하루 상한 넘김·단계가 차며 넘친 몫·목표가 n 감소로 내려가 바로 차는 경우·공동 3단계 뒤 반요촌 창고 맡기기(이야기 마친 사람만)·4단계 거래소 등록·5단계 수리비·캐릭터 정리. `set local role fn_owner_…`로도 부름(§16 권한).
- 화면 검증: 납품 창 PC 1440·iPhone 13, 물품 고르기 겹침 창, 현장 띠, 반요촌 town 칸이 풀린 사람/아닌 사람에게 다르게.

---

## 8. 물어야 할 것

1. 몫은 **납품만**(이 안)인가, plan.md 옛 안처럼 기부·의뢰판도 사업 몫에 더하나?
2. 목표 √n 그대로면 큰 세력(정통파 11명)이 4~5배 빠름 — 그대로 둘지, 큰 세력 기본값을 올릴지(예 n^0.7).
3. 1단계 상점 새 품목·4단계 비고 품목을 **그 세력 조사원만** 보게(이 안) 할지, 거점을 찾은 누구나 사게 할지.
4. 지름길 수치: 세력 −20%(결정)·공동 −30%(이 안), 등도 지름길 상대를 본부 정청으로 할지 십삼문으로 할지.
5. 5단계 뒤 납품 보상 절반(이 안) / 그대로 / 받지 않음.
6. 공동 1단계 「품목 수 4 → 6」은 사람마다 나눌 수 없어 이야기를 안 마친 사람에게도 보임 — 괜찮은지.
7. 급히 필요 채집 재료를 현장 채집터에 「사업」 칩으로 보일지(요청은 안 늘지만 칩이 하나 더 생김).
8. 세력 사업 기본값(14k~20k)·공동(34k~50k)·하루 상한(2,400·6,000몫)·몫 환산(공훈 40·전 0.8)은 시뮬 뒤 다시 보여 드림 — 먼저 이 크기 느낌이 맞는지.
9. 3.0.0에 같이 낼지 / 3.1.0으로 따로(plan.md 정할 것 4번 그대로 남음).

## 9. 사용자 결정 (11/17)
- §8의 1·3·4·5·6·7은 이 안 그대로(몫은 납품만 · 1단계 상점·4단계 비고 새 품목은 그 세력 조사원만 · 공동 지름길 −30%, 등도 지름길 상대는 본부 정청 · 5단계 뒤 납품 보상 절반 · 공동 1단계 품목 수 늘림은 모두에게 · 급히 필요한 채집 재료는 현장 채집터에 「사업」 칩).
- 2: 목표 √n 그대로.
- 9: 3.0.0에 같이, 이번 주 안에 모두 끝냄.
- 8: 크기는 시뮬 뒤 다시 보임.
