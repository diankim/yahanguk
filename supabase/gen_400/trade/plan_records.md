# 4.0 교역선 — 교역 기록·칭호·꾸미기 가안 (확인 전, 11/26)

결정 원문은 supabase/gen_part2/plan_trade.md·plan_content.md. 이 문서는 **가안**이다(CLAUDE.md 작업 원칙 0-1). 수치·조건·등급·효과는 표마다 사용자가 고른 뒤에만 넣는다. 수치는 들어갈 때 world_trade_rules() 안 `titles`·`records` 칸 한 곳 → gamedata → rules.js → 화면·도움말(「한 규칙은 한 곳에」).

## 0. 지금 교역 코드가 남기는 것 (b_tables·c_funcs 읽은 결과)

교역 함수는 world_events를 남기지 않는다(행동 기록 없음). 그래서 칭호는 기존 `ev` 규칙으로 셀 수 없고, 사업·등불 편지처럼 **새 규칙 갈래**(`{'trade': 갈래, 'n': n}` → world_trade_rule_count)가 필요하다.

| 셀 것 | 지금 표로 되나 | 근거·문제 |
|---|---|---|
| 판매 정가 합·벌이 합(평생) | 된다 | world_trade_sales(owner·day·base_sum·gil_sum) 날마다 한 줄, 정리 대상 아님 |
| 항구별 판매 정가 합·벌이 | **안 됨** | 항구는 world_economy_ledger trade_goods_sale details.port에만 — 장부는 60일 보관 |
| 가장 큰 한 번 벌이 | **안 됨** | 위와 같음(60일) |
| 배로 닿은 항구 수 | 된다 | world_trade_seen 행 수(직접 타고 닿았을 때만 적힘 — 보내 두기·걸어서 온 것은 안 셈, 시세판 규칙과 같아 맞음) |
| 항해 횟수·바다 건넌 횟수 | 반쯤 | world_trade_voyages(done)에 from/to·mode가 남지만 함께 탄 이(world_trade_aboard)는 닿는 순간 지워짐 → 동료 몫은 ships[] → world_ships.ship_id로 거슬러야 함. 무겁고, 나중에 항해 기록을 정리하면 사라짐 |
| 습격 승패 | 반쯤 | voyages.result.raid.won — 위와 같은 문제. 동무 무늬(monsoon_cloud)는 따로 world_pet_skin_tally 'raid'로 셈 |
| 보내 두기 횟수 | 된다(무겁게) | voyages mode 'send'·captain_id |
| 배 단계 이력 | **안 됨** | world_ships는 지금 단계만, 짓기 장부(trade_ship_build)는 60일 |
| 수요 사건 맞추기·하루 몫 한 번에 채우기·파티 덤 | **안 됨** | 어디에도 안 남음 |

**제안: 기록 표 하나 world_trade_record** (owner_id 기본 키 한 줄, RLS·직접 읽기 없음, world_character_purge 대상).

| 칸 | 뜻 | 적는 곳(이미 있는 함수 안, 같은 트랜잭션) |
|---|---|---|
| sold_base bigint · sold_gil bigint · sold_n int | 판 정가 합·받은 돈 합·판 개수 | world_trade_sell_core |
| ports jsonb `{항구: {b, g, n}}` | 항구별 정가 합·벌이·개수 | world_trade_sell_core |
| best_gil int · best_port · best_at | 한 번 팔기로 받은 돈 최고 | world_trade_sell_core |
| demand_n int · demand_day date | 수요 사건 항구에서 판 날 수(하루 한 번만 셈) | world_trade_sell_core(값 tags에 event) |
| full_n int | 한 번 팔기로 그날 몫을 꽉 채운 횟수(정가 합 0 → 상한 − 가장 싼 정가 이상) | world_trade_sell_core |
| voy_n int · cross_n int · send_n int | 직접 타고 닿은 항해·바다 건너기(구름나루↔파도너울성)·보내 둔 배가 닿은 수 | world_trade_finish |
| ocean_cross boolean | 대양함선을 선장으로 몰아 바다 건넘 | world_trade_finish |
| raid_win int · raid_lose int | 습격 이김·짐(배 탄 사람 모두) | world_trade_raid_end |
| send_raid int | 보내 둔 배가 자동 습격을 맞은 수 | world_trade_finish |
| bonus jsonb `{time, guard, haggle}` | 동료와 함께 떠나 그 덤을 쓴 항해 수(선장·동승 모두) | world_trade_finish |
| tiers jsonb `{"2": 시각, …}` | 배 단계를 올린 때 | world_trade_ship_upgrade(나룻배는 world_trade_ship_get 때 "1") |
| broke_fix boolean | 파손(내구도 0)된 배를 고쳐 다시 띄움 | world_trade_repair(고칠 때 0이었으면 표시) → world_trade_launch에서 참 |

- 디스크 I/O: 팔기·닿기·습격 끝·짓기마다 이 한 줄을 한 번 갱신(캐릭터 행은 안 고침, §16 방침 1). 팔기는 이미 world_trade_sales·장부·흐름 표를 쓰는 자리라 한 줄 더.
- 문턱을 넘는 순간만 world_title_award_check(uid, 'trade') (사업 칭호와 같은 틀).
- 동무 무늬 셈(world_pet_skin_tally 'trade:<항구>'·'raid')은 그대로 둔다 — 원하면 나중에 이 표를 읽게 모을 수 있음(지금 묶음에서는 안 건드림 제안).
- 덧붙여 확인할 일: 배로 파도너울성에 닿을 때 world_events travel이 안 남아 도해록 칭호 `hw_arrive`(파도너울성에 닿는다, ev travel + travel_history_id)·`hw_walker`가 **배로 온 사람에게 안 잡힘**. 건넛누리 첫 진입은 구름나루 ↔ 파도너울성 건너기뿐이면 hw_arrive를 아무도 못 얻을 수 있음 — world_trade_finish가 도착 기록을 남길지, hw_arrive 조건을 바꿀지 정해야 함.
- world_trade_voyages는 정리 작업이 없어 계속 쌓임 — 기록 표가 생기면 끝난 항해를 world_housekeeping에서 n일 뒤 지울 수 있음(따로 제안).

## 1. 교역 기록 화면에 보일 것

`world_trade_record_view()`(읽기만) 한 번 → 항구 화면 「장부」 칸과 일지 › 기록 「교역」 칸이 함께 씀.

| 묶음 | 보일 것 |
|---|---|
| 내 배 | 지금 배·이름·내구도, 단계 사다리(나룻배 → 대양함선)에 올린 날짜(tiers) |
| 장사 | 판 개수·정가 합·받은 돈 합·평균 덤(받은 돈 ÷ 정가 합, 「정가의 1.34배에 팔았음」), 오늘 남은 몫(world_trade_sales) |
| 항구별 | 13곳 줄: 판 개수·벌이·마지막으로 본 시세 때(world_trade_seen.at) — 닿은 적 없는 곳은 「?」, 가장 많이 판 곳 금빛 |
| 기록 | 가장 큰 한 번 벌이(항구·날짜)·하루 몫을 한 번에 채운 수·수요 사건 맞춘 날 수 |
| 뱃길 | 직접 항해 수·바다 건넌 수·보내 둔 수·들른 항구 n/13 |
| 습격 | 이김 a · 짐 b · 보내 둔 배가 맞은 수 |
| 함께 | 덤마다 쓴 수(물길 줄이기·함께 막기·함께 흥정) |
| 칭호 | 교역 칭호 진행(칭호 화면 진행 게이지와 같은 값) |

## 2. 칭호 가안 (14 — 공개 12·숨김 2)

- 분류: (가) 새 분류 「교역」 ← 제안 · (나) 「도해록」에 넣기(4.0 이야기 칭호와 섞임). 정렬 sort 3600+.
- 효과: (가) 아래 표처럼 작은 효과(기존 키만, 등급 규칙 — 첫 효과 그 등급 수준) ← 제안 · (나) 등불 편지·선배와 새내기처럼 효과 없음.
- 문턱 셈: 하루 상한이 정가 합 3,000이라 정가 합 30,000 ≈ 꽉 채운 날 10일, 150,000 ≈ 50일, 300,000 ≈ 100일.
- 동무 무늬(plan_boss.md §11)와 같은 조건은 피함 — 무늬: 항구별 정가 합 5,000·습격 이기기 10·대양함선까지 짓기. 그래서 칭호는 습격 1·30, 「대양함선으로 건너기」, 항구 구분 없는 누적으로 둠.

| 키 | 이름(가안) | 조건 | 등급 | 효과(키·값) | 숨김 |
|---|---|---|---|---|---|
| tr_cross | 물을 건넌 장사꾼 | 배를 직접 타고 처음 바다를 건넌다(구름나루 ↔ 파도너울성) | 2 양품 | travel_time_pct −2 | 아니오 |
| tr_sold_1 | 뱃짐 장수 | 교역품을 정가 합 30,000전어치 판다 | 2 양품 | rare_loot_pct +1 · gather_qty_pct +1 | 아니오 |
| tr_sold_2 | 물길의 객주 | 정가 합 150,000전어치 판다 | 3 진품 | rare_loot_pct +2 · gather_qty_pct +2 | 아니오 |
| tr_sold_3 | 열세 나루 큰손 | 정가 합 300,000전어치 판다 | 4 명품 | rare_loot_pct +3 · gather_qty_pct +2 · travel_time_pct −2 | 아니오 |
| tr_ports | 나루마다 이름 난 배 | 배로 열세 항구에 모두 닿는다(world_trade_seen 13) | 3 진품 | travel_time_pct −3 | 아니오 |
| tr_demand | 소식 빠른 장사꾼 | 수요 사건이 난 항구에서 그날 교역품을 판 날이 10일 | 3 진품 | rare_loot_pct +2 · encounter_pct −2 | 아니오 |
| tr_full | 하루 장사 한 배 | 한 번 팔기로 그날 몫(정가 합 3,000)을 꽉 채운다 | 2 양품 | gather_qty_pct +2 | 아니오 |
| tr_send | 앉아서 버는 선주 | 보내 둔 배가 30번 항구에 닿는다 | 2 양품 | travel_time_pct −2 | 아니오 |
| tr_raid_1 | 뱃전을 지킨 이 | 뱃길 습격을 처음 물리친다 | 2 양품 | incoming_damage_pct −1 | 아니오 |
| tr_raid_2 | 물길 강도의 악몽 | 뱃길 습격을 30번 물리친다 | 4 명품 | combat_damage_pct +2 · incoming_damage_pct −2 | 아니오 |
| tr_ocean | 대양을 가르는 선주 | 대양함선 선장으로 바다를 건넌다 | 4 명품 | travel_time_pct −3 · encounter_pct −3 | 아니오 |
| tr_crew | 세 가지 덤을 아는 뱃사람 | 동료와 함께 떠나 물길 줄이기·함께 막기·함께 흥정을 한 번씩 모두 쓴다(선장·동승 모두 셈) | 3 진품 | healing_pct +2 · mental_loss_pct −2 | 아니오 |
| tr_best | 한탕의 전설 | 한 번 팔기로 5,000전 넘게 받는다(먼 땅 물건 + 찾는 물건·수요 사건이 겹쳐야 닿음) | 4 명품 | rare_loot_pct +3 · craft_quality +2 | **예** |
| tr_broke | 바닥까지 닳은 배 | 파손(내구도 0)된 배를 고쳐 다시 띄운다 | 1 범품 | 없음(재미 칭호) | **예** |

- tr_best 닿는지 계산: 하루 몫 정가 3,000 전부를 건넛누리 물건으로 본토에서 팔면 배율 1.5 × 흔들림 0.9~1.1 × 찾는 물건 1.2 × 수요 사건 1.3 × 흥정 덤 최대 1.06. 먼 땅 1.5 × 찾는 물건 1.2 = 1.8배 → 5,400전, 흔들림이 낮은 날이면 못 닿음. 문턱 후보 (가) 5,000 ← 제안 · (나) 4,500(먼 땅 + 흔들림만으로도 가끔) · (다) 6,000(셋이 겹쳐야).
- tr_full 판정: 정가가 20~40이라 3,000을 딱 맞추지 못할 수 있어 「그 팔기 전 오늘 판 몫 0, 팔고 난 몫 ≥ 3,000 − 그 짐 가장 싼 정가」로 셈(가안).
- tr_demand는 같은 날 여러 번 팔아도 하루 하나.
- tr_ocean·tr_cross는 직접 타고 간 항해만(보내 두기는 사람이 안 탐).
- 다른 안(골라 바꿀 거리): 「찾는 물건」 꼬리표 값으로 판 개수(tr_seek 「입맛을 맞춘 장사꾼」 300개 · 2 양품) · 세력 특선 음식을 교역품으로 판매(tr_food 「잔칫감을 실은 배」 100개 · 1 범품) · 덤 셋을 각각 따로 칭호로(물길 줄이기 20번 등) · 숨김 「빈 배의 귀향」(습격에 져 짐을 모두 잃는다).

## 3. 꾸미기 한 벌 가안

이미 있는 것과 겹치지 않게 골랐다(낙관 「舟」 수향·「潮」 건넛누리, 테두리 fr_wave·fr_compass·물때 테, 바탕 무늬 pt_ripple·pt_mapline는 이미 있음).

| 키 | 갈래 | 이름 | 얻는 길(칭호) | 등급 | 그림 가안 |
|---|---|---|---|---|---|
| fr_hull | 테두리 | 뱃전 테 | tr_sold_2 물길의 객주 | legend | 뱃전 널판 이음새가 테를 두르고 네 모서리에 놋쇠 못·작은 닻 고리 |
| pt_sealane | 바탕 무늬 | 뱃길 장부 | tr_ports 나루마다 이름 난 배 | legend | 장부 칸 줄 위로 항구 점을 잇는 점선 뱃길과 작은 돛 |
| sl_bak | 낙관 | 「舶」 | tr_ocean 대양을 가르는 선주 | legend | 주문(朱文) 네모 도장, 왼쪽 아래 물결 한 획 |

- 다른 안: 낙관을 「商」(장사)·「航」(뱃길)로 · 세 꾸미기를 칭호 대신 기록 문턱(정가 합 150,000 등)에 바로 묶기 · 이름 색 하나 더(「물빛 금」 — 도해록 「해오름」과 겹치지 않게) — 넣을지부터 정해야 함.

## 4. 화면 위치

- 항구 칸(현장 「항구」 창, plan_trade.md §8) 맨 끝 탭 「장부」: 위 표 §1 전부. 칭호 진행은 짧게(남은 문턱 하나씩).
- 일지 › 기록에 「교역」 칸(요괴·채집·어종 도감 옆): 같은 world_trade_record_view, 항구 줄을 누르면 지도 짚기(sources.js regionBtn).
- 칭호 화면: 분류 칩 「교역」(새 분류면), 진행 게이지는 world_title_rule_progress가 world_trade_rule_count를 부름.
- 알림: 칭호는 기존 title 알림. 기록 갱신만으로는 알림 없음.
- 도움말 「교역선」 항목 끝에 「교역 칭호」 표(gamedata에서 — 숨김 둘은 「??? 2」).
- 다시 읽기: changes.js에 trade_sell·trade_sail·trade_* 뒤 기록 캐시 버리기 한 줄(장부 탭을 열 때만 읽음, 10분 캐시).

## 5. 정해 주실 것

1. 기록 표 world_trade_record 하나로 모으기 — 좋은지(대안: 칭호에 필요한 몇 칸만).
2. 칭호 분류 「교역」 / 「도해록」, 효과 있음 / 없음.
3. 칭호 14개 이름·문턱(30,000·150,000·300,000, 습격 1·30, 보내 두기 30, 수요 10일, tr_best 5,000)·등급·효과값. 바꿀 거리 넷 중 넣을 것.
4. 꾸미기 셋 이름·조건·낙관 글자.
5. hw_arrive가 배로 닿을 때 안 잡히는 문제 처리(도착 기록을 남길지 / 조건을 바꿀지).
6. 끝난 항해 기록 정리(world_housekeeping n일) 넣을지.

## 사용자 결정 11/26
1. 칭호 14·문턱·등급 가안 그대로. 2. 효과는 표대로 작게. 3. 분류 「교역」(5.0에도 더해질 것이라). 4. 배로 도착할 때도 world_events travel 도착 기록을 남김(hw_arrive·hw_walker가 잡히게). 5. 지난 항해 기록은 world_housekeeping에서 2일 뒤 지움(다른 기록과 같게). 꾸미기 한 벌·장부 화면 위치도 가안대로.
