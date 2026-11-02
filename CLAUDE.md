# 야행국(夜行局) — 게임 기획 및 개발 기준서

지금 적용된 규칙과 그 규칙이 사는 곳(함수·표·파일·선택자)을 적는다. 바뀐 내력은 패치노트(world_patch_notes)와 git 기록에서 본다.

## 1. 프로젝트의 정체성

여러 플레이어가 하나의 공용 세계에서 캐릭터를 육성하고 탐사·전투·채집·제작·거래·사건 조사·세력 활동을 하는 텍스트 중심 온라인 RPG. 웹 기반으로 PC와 모바일을 모두 지원하고, 진행과 데이터는 서버에 저장하며, 이동·자율 활동 등은 현실 시간으로 흐른다.

핵심 목표:
- 세계를 돌아다니며 새 지역과 채집터를 발견하는 탐사
- 전투·생활·조사·제작 등 여러 활동을 통한 장기 성장
- 지역·세력·경제·사건이 연결되는 살아 있는 공용 세계
- 혼자서도 성장하지만 협력하면 이점이 있는 구조
- 반복 작업만 강요하지 않는 다양한 활동
- 모바일에서 불편하지 않고 PC 넓은 화면을 잘 쓰는 UI
- 20명 미만 소규모 이용자, 무료 또는 최소 비용 운영

## 2. 게임 디자인 철학

- **탐험과 발견 중심**: 메뉴에서 보상을 받는 게 아니라 이동·조사로 자원을 발견한다. 지역마다 환경·위험도·자원·몬스터·사건·보상이 다르고 탐사에 목적과 선택의 의미가 있다.
- **활동이 서로 연결**: 전투만이 성장 수단이 아니다. 탐사 자원 → 제작, 제작 장비 → 전투·고위험 탐사, 조사 단서 → 사건 해결. 채집·제작·전투·조사·거래·세력 활동은 각각 성장 경로를 가지면서 서로 자원을 공급한다.
- **협력은 유용하되 강제하지 않음**: 직업·역할에 따라 협력 효율이 오르지만 특정 직업이 없으면 핵심 콘텐츠를 못 하는 구조는 피한다. 파티 탐사·전투·이동·분배에서 협력 이점을 명확히 한다.
- **장기 목표와 후발주자의 기회**: 성장 상한과 기능별 숙련 상한을 둔다. 최고 레벨 40(쌓아 둘 능력치 포인트 상한 117). 다음 레벨 경험치 world_xp_need = 100×레벨 + 12×레벨²(화면 core.js xpNeed). 같은 레벨 요괴 한 마리 = 사냥 (6+레벨×3) + 토벌 기록 12라 Lv10 약 46마리 → Lv20 87 → Lv29 124 → Lv39 170마리(실제로는 탐색·퀘스트가 섞여 더 빠름). 후발 플레이어가 효율적 경로와 전문화로 따라잡을 수 있어야 하고, 오래 했다는 이유만으로 모든 영역에서 영구 우위를 갖지 않는다.

## 3. 세계와 지역 탐사

### 3.1 계층형 세계 지도

영역 → 지역 → 원정지(외곽·심부·핵심). 원정을 다녀올수록 답사도가 올라 깊은 원정지가 열린다(30% 심부, 70% 핵심, 100% 완전 답사 보상). 지역·원정지 이름에 숫자를 붙이지 않고 모든 이름은 중복되지 않는다. 지도에서 목적지를 골라 이동한 뒤 탐사하며, 이동·탈것은 세계 지도 흐름에 통합한다.

**화면 용어 규칙**: '파밍'·'스팟' 같은 외래어 대신 채집·채집터·원정지. 다른 게임에서 온 말(돌발 임무·던전·탱커·딜러·폭딜·버프·디버프·기믹 등)을 화면·도움말·서버 문구에 쓰지 않는다 — 기믹 → 요괴의 수법·수법 대처법, 탱커 → 방패, 딜러 → 공격(수), 폭딜 → 몰아치기, 버프·디버프 → 북돋기·약화. 내부 이름(world_monster_gimmicks 등)은 그대로(이 문서의 「기믹」도 내부 용어).

### 3.2 지역별 차별화

지역마다 환경·지형, 위험도·권장 수준, 출현 몬스터와 수법, 채집 자원, 회복·의료·제작 관련 자원, 사건·단서, 희귀 자원·고유 보상, 먼 지역을 찾을 동기를 둔다. 자원 분포는 세계관에 맞게(회복 자원은 의료 시설·약재 환경), 고위험 지역은 보상이 크지만 준비·생존 부담도 크다. 지역 수만 늘리지 말고 방문할 이유를 만든다. 답사 지점·채집터·원정지의 출입 레벨은 지역 레벨에 깊이마다 +2(최고 40).

### 3.3 안전지대

10곳: 본부 정청·본부 객사·백등 야시장·구름나루·백골 장터·잔불촌·철벽 고찰·십삼문 암시장·무극 관성대·반요촌(빈약한 안전지대, §3.5). 서버가 강제한다:
- 안전지대에서는 요괴 수색·전투·원정 불가.
- 상점과 거래소는 안전지대에만.
- 현장 화면에는 전투 대신 상점·대장간·거래소·창고(·마구간).

### 3.4 원정

원정지에 기간(30분~8시간)·태세(신중·균형·강행)·보급품을 정해 보내면 서버가 전투·채집·발견·위험을 계산한다. 결과는 능력치·장비 단계·숙련·직업·대세력에 따라 다르다.

- 보급품(회복품·정화 부적·봉인 부적·회생 부적·노정 건량)을 쓰고, 쓰러지면 전리품 절반을 잃고 구조가 필요하다. 원정 중에는 현장 행동 불가, 자율 활동과 동시 불가. 조기 귀환은 지난 회차만큼. 직접 플레이보다 시간당 효율이 낮아야 한다.
- 정산: 회차 시각이 지나면 world_expedition_settle이 그 회차를 바로 정산해 일지(world_expeditions.journal)에 적고 체력·정신·침식을 캐릭터에 반영(상태판은 world_expedition_tick). 귀환은 남은 회차만 정산 후 전리품·경험치·답사 정리. 쓰러지거나 정신이 바닥나면 멈추고 바로 결과. 회차 수 30분 3·1시간 6·2시간 10·4시간 16·8시간 24.
- 정산 효과: 정산 동안 JWT를 원정 주인으로 바꿔 world_status_effect_total·world_title_bonus를 읽는다(주는 피해(무기 갈래 % 포함, 합 35%)·치명타 절반·방어·받는 피해(−60%까지)·회피·정신 손실·침식·희귀품·채집량·회복량). 퇴마관 전투력 ×1.12·백공 채집 +15%는 따로 붙이지 않음(직업 효과와 겹침).
- 일지(world_expedition_progress): 모든 줄에 캐릭터 이름, 걸음마다 지역 종류·태세·직업·날씨에 맞는 풍경·흔적·기척 줄(world_expedition_walk_lines), 회차, 전투(행동별 절제된 색)를 시간순으로 위→아래. 같은 지역으로 원정 중인 파티원 일지만 섞는다. 처음 열면 맨 아래. 전리품 이름·수량은 귀환 때 공개. 전투는 마주침~승패를 테 두른 칸으로 묶어 결과 한 줄만 보이고 누르면 펼침, 끼어든 다른 줄이 칸을 끊지 않음(expedition.js battleGroups).
- 보상: 보낸 시간 10분 ≈ 탐색 1번이 되게 회차로 나눔. Lv10까지 경험치 +30%, 원정지마다 첫 완주 길잡이 등불. 회차마다 원정 전용 물품(world_expedition_bonus_item: 길잡이 등불·비경 지도·철벽/맹호/청명 비약·봉인된 보따리·강화 재료, 모두 거래 가능). 경험치는 완주했을 때만 (60+지역Lv×15)×시간^0.8×깊이(1·1.2·1.4)×레벨 차 배율. 2시간 이상 완주 경험치·전·숙련 +20%(4시간 +30%·8시간 +40%). 완주 장비(world_expedition_gear): 2시간 50%·4시간 이상 반드시, 심부·핵심 덤 4%·8%. 2시간 이상 완주 시 비경(world_hidden_trails, 3시간: 그 지역 채집량 +50%·희귀품·단서 +10%, 파티원 공유, world_trail_effect).
- 원정 전투에는 같은 영역 이웃 지역(수준 ±3) 일반 요괴도 30% 무게로 섞인다. 전투·채집·조사 경험의 절반은 든 무기 계열·채집·탐사 기술에.
- 원정 장비(행군 노리개·비경 호신부·야행 탈, exg_*_2→_1→_0)는 원정 두 번에 부서지고 부서진 것은 효과 없이 싸게 팔린다.
- 전투 묘사(world_exp_fight_story): 승패·피해 합은 settle이 정하고 이 함수가 무기 갈래별 공격·치명타·직업 기술(한 번)·요괴 수법(kind foe)·회피·막기(kind guard: guarding 단계로 6%+단계×0.6%·최대 35%, 그 공격 피해 절반)를 여러 합으로 적는다. 승패는 win_p로 굴리되 밀린 싸움도 체력 70 이상이면 (체력−50)/100(최대 50%)로 버텨 이김(피해 두 배, [버팀]).
- 파티 합동 전투: 동료 한 명마다 같은 지역 일반 요괴가 하나 더, 위협 +45%, 이기면 더 나온 요괴마다 경험치 5+위험도·전리품 35% 굴림. 동료 전투력 60%가 승률에, 요괴는 이목^1.3로 표적(동료가 대신 맞은 피해는 world_expedition_hits로 동료 정산 때 반영, 쓰러뜨리지는 않음).
- 보급품 고르기: world_expedition_start(p_node_id, p_minutes, p_stance, p_supplies jsonb)가 보급품마다 0~20(0 = 안 씀)을 yh.exp_sup으로 3인자 함수에 넘기고 3인자는 읽은 뒤 비움. 고르지 않은 것은 가진 만큼(20까지). 파티 원정(world_pexp_resolve)은 3인자 기본값. 화면 expedition.js supPick.
- 짐 보따리(world_overflow_items): 원정 귀환(world_expedition_complete가 yh.overflow_to=expedition) 중 가방이 넘치면 world_enforce_bag_capacity가 넘친 몫을 담고 bag_overflow 알림. world_overflow_snapshot·world_overflow_take(들어가는 만큼)·world_overflow_discard. 비기 전에는 world_guard_action_context(explore·gather·fish·combat·encounter·expedition_start·travel 출발)·world_field_move가 막음. 현장 안내 world_field_snapshot.overflow(overflow.js). 원정 밖의 얻기는 넘친 만큼 버림.
- 직업별 원정 기술: 퇴마관 파사 부적·조사원 흔적 추적·의무관 야전 처치·봉인술사 결계 야영·호위 무사 반격 태세·백공 현장 가공(결과에 발동 횟수). 기술 고유 효과는 §6.
- 의무관 [야전 처치]: 체력이 회복 기준(heal_at) 아래면 보급품보다 먼저 체력 +25(회복 보정), 원정 한 번에 세 번(jobn). 원정 중 쓰러짐 기록(downed)은 world_guard_action_context가 허용(정산이 쓰러짐에서 되돌려지지 않게).
- 화면: 지금 서 있는 답사 지점(world_characters.current_exploration_node_id)을 먼저 고르고 맨 위 「지금 있는 곳」(expedition.js preferHere), 같은 설정으로 다시 보내기(yh-exp-last), 탐색력 0이면 현장에 원정 권유. PC 두 칸(왼쪽 보낼 곳·기간·태세 / 오른쪽 보급품·기술·안내·출발), 모바일 한 칸.

### 3.5 귀허도

- 영역 gwiheo: 반요촌(안전지대 Lv30, 상점 banyo_shop)·잿빛 갈대숲 Lv30·거꾸로 선 사당 Lv33·달 없는 저잣거리 Lv36·귀허 Lv38(위험도 10, 반요촌 8 — world_map_regions.danger_level 상한 10). 구중 봉연에서 이어진다. 생성기 supabase/gen70/(data_island.py·data_gaiden.py·funcs_island.sql·funcs_gw.sql·g_qol.sql·gen.py → migrations/20261101000000_world_7_0_0.sql).
- 열림 world_gwiheo_open(uid) = 10장(nine_gates) 마침 또는 world_staff. 그 전에는 world_map_snapshot이 섬 지역과 그리로 가는 travel_from을 숨기고 world_travel_route·world_travel_region·동승(world_travel_party_invite_v2·respond_v2)이 막는다. 봉연의 그림자는 섬에 안 나온다.
- 섬 규칙: world_island_effect 침식 보정 +60%, 섬에서는 world_yohwa_tick이 단계를 넘기지 않고 10분 미룸, 섬 토벌 희귀 전리품 반요 비늘(banyo_scale). 요기 순응: world_erosion_effect가 섬(침식 30 이상일 때만 world_region_at으로 판정)에서 침식 불이익을 절반(회복 −8/−12/−18·받는 피해 +5/+10·조우 +10)으로, 주는 피해를 위험 +4·붕괴 직전 +8로 바꾸고, world_combat_stats의 침식 공격력 불이익(mind)을 없앤다(world_on_island). 정신 40·20 아래 불이익·희귀품·단서 덤·정신 −1·100 정신 0·요화는 그대로. 화면 character.js erosionNote(ISLAND)·guide.js.
- 반요촌: 거래소(world_guard_action_context)·창고(world_storage_check)·마구간 없음, 제작은 창고 재료를 안 씀(world_craft_item, bag.js 재료 수·「전부」도). 상점은 회차마다 4가지 이상·귀허 부적은 늘, 사람마다 품목별 하루 개수(world_shop_catalog.daily_cap·world_shop_buy_caps), 되팔기·판매 한도 절반, 대장간은 월철 주괴·정련 숯만, 수리비 ×3(world_repair_mult). home.js town이 거래소·창고 칸을 숨김.
- 재료 8(갈대 영사·거꾸로 향목·망각 수정·무월 비단·귀허 흑철·반요 비늘·요인 혈정·귀허 진주), 소모품 귀허 부적(거래 불가, 보스 입장)·반요 고약·망각 향, 6단계 장비 33(Lv32, 반요촌 제작, world_gear_drops 31~40).
- 외전 「요인록」 gq_1~gq_5(kind side, cat 「외전·요인록」, Lv30·32·34·36·38, 앞 장이 after), 인물 g_*, 마지막 장 할 일 {t:'gw'}.

#### 최종 보스 「귀허의 주인」

- 표 world_gw_fights·members·log·records(실시간 목록 아님). 귀허에서 Lv38·외전 4장·귀허 부적, 혼자 또는 같은 곳 파티원 4명까지(world_gw_open 60초 모음·world_gw_join·world_gw_begin).
- 라운드 5초(수법 라운드 10초), 참가자마다 행동 하나: attack·guard·brace(버티기: 받는 피해 물살 20%·손길 30%, 소용돌이 받아 내기)·item(체력 회복품, 한 싸움 두 개 world_gw_members.items_used)·coop(world_coop_skills, 영력, 다시 쓰기 ceil(초/5)라운드 world_gw_members.cds)·call(이름 부르기)·chain. 안 고르면 방어. 마감이 지났거나 모두 고르면 누군가 world_gw_snapshot·world_gw_act를 부를 때 world_gw_resolve가 푼다(예약 작업 없음).
- 단계 4(두 얼굴·사슬 넷·이름 빼앗기·귀허의 소용돌이), 체력 max(6000, Σ공격×40), 15분. 주인 체력·받는 피해 인원 배율 1·0.95·0.8·0.85(혼자면 체력 ×1.12 더). 의무관 회복 기술 ×0.65·술법 회피 +15(world_gw_start·world_gw_resolve).
- 쓰러지면 물러남(1·2·3·4명에 1·2·4·5라운드, world_gw_hurt), 체력 30. 물러남이 끝나거나 [야전 소생]을 받으면 「쉬는 중」(world_gw_members.rest — 주인이 안 노리고, 모두에게 거는 효과·수법·라운드 기다림에서 빠지며, 한 사람 회복은 받음, 「모두 물러남」은 물러난 사람만 셈, 아무 행동이나 고르면 풀림). 혼자는 쓰러짐 10 + 직업 보정 solo_falls까지(그다음 실패, 스냅샷 falls_cap).
- 혼자 도전 직업 보정 world_solo_aid(직업)(둘 이상이면 없음, 혼자 10판 시뮬로 맞춤 — 직업마다 혼자 승률 약 3~4/10): 귀허 solo_dmg(주는 피해 %)·solo_guard(받는 피해 −%, world_cb_mitigate가 stats.solo_guard)·solo_falls, 결전 혼자는 final_dmg가 solo_dmg 대신, final_all은 결전에서 인원 무관(퇴마관·봉인술사 +15). world_gw_start·world_raid_action이 stats에 섞고 스냅샷 solo로 보임.
- 손아귀(반격): 1·2명 하나·3명 라운드마다 하나·둘·4명 둘(같은 사람 두 번 안 노림). 모두를 치는 물살은 4의 배수 라운드(수법 아닌)에 mech.aoe로 미리 알리고 낌새 mech.tell(대처법은 넌지시)을 라운드 띠에 크게.
- 난이도 목표(사용자 기준): 정석 플레이로 넷 10/10·둘 5/10·혼자 2~3/10. 시뮬레이션은 로컬 복제 DB에서만(운영에서 돌리면 캐릭터 행을 잠가 시간 초과).
- 기운: 참가자 world_gw_members.fx(ward·might·crit·critnext·evade·shield·gward·taunt·cover)·주인 world_gw_fights.bfx(expose·block·smoke). 받는 피해 world_gw_hit(world_cb_mitigate → world_gw_hurt, 수법 즉사 999는 hurt 바로). 수법 연계: 해독 침 = 사슬 풀기·이름 되찾기 / 야전 소생 = 물러난 동료를 쉬는 중으로 / 퇴마 결계 = 물살·사슬 물살·소용돌이 실패 피해 절반 / 파사 진언 = 그 동료만 / 흐름 끊기 = 반격 막기·소용돌이 끊을 힘 절반 / 봉인 사슬 = 반격 막기·받는 피해 +15%·두 얼굴이 힘을 못 삼킴(반대 공격도 절반 피해) / 호법 신장 = 버티기로 소용돌이 대신 받아 내기 / 대신 막기 = 그 동료를 노린 손길 절반.
- 실패: 장착 장비 내구도 −10%·침식 +10·30분 뒤 재도전. 처치는 하루 한 번(처음 1,500전·경험치 0.5배·탈것 moonless_boat·이름 색 ns:1028, 뒤로는 120전·0.05배), 처치마다 world_events gw_win → 칭호 gw_kill1/3/10/25·gw_solo·gw_flawless(분류 '외전')·꾸미기 fr_gwiheo·pt_gwiheo·sl_gwi. 파훼법(world_gw_tips)은 처치한 사람만. 끝난 싸움 기록 200줄, 대기실 last로 지난 기록.
- 화면 views/gw.js(#/gw/<id>, 공용 부품 fightui.js §10): .raid-wrap.pf-wrap.gw-wrap, PC 싸우는 중 grid-template-areas "boss mem" "boss log" "act log", 끝난 화면 참가자 네 칸 한 줄. 단계 사다리 .gw-ladder(휴대폰 한 줄 「1 두 얼굴」), 라운드 띠 .gw-band(라운드·마감·고른 수·낌새·내 행동, 긴 낌새는 tellSize), 게이지 안 숫자 .gw-vits, 단추 공격·방어·버티기 .gw-btns 아래 협동 기술 늘 펼침 .gw-skills(네 칸 한 줄, 설명·다시 쓰기는 title), 이번 라운드만의 행동 .gw-gim, 기록 .gw-log(갈래마다 색, 휴대폰은 최근이 위, 끝난 뒤는 처음부터). 참가자 .raid-mem.pf-mem(누르면 대상 .pick). 다시 읽기: 라운드 마감 직후·내가 고른 뒤 2초·모이는 중 3초.

### 3.6 새 지역·세력 배치

- 생성기 supabase/gen71/(data_regions.py·regions.py·d_faction.sql·gen.py → migrations/20261102000000_world_7_1_0.sql). 지역 11곳: 옛 의금부 옥사 15·봉인고 19(정통파)·만조의 갑문 18(수향)·적월 제단터 19(적월)·설피골 5(북령)·불씨 고개 5(남명)·등잔골 뒷골목 5(흑련)·별바라기 언덕 5·물시계 터 9·혜성 낙하지 13·구름 위 회랑 16(천명). 지역마다 답사 길·채집터(들머리 「어귀의 …」)·요괴 r71_*·원정지·조사 지점·처음 방문 글·보조 퀘스트 rq_*. 이름 겹침은 ref/existing_names.json으로 검사.
- 직할령 Lv1~3 여덟 곳은 중립(home_faction_id null, 겨루기 제외, 지도 회색). 본래 주인 기준 지도에서 세력 땅·중립 직할령이 끊기지 않아야 하고, 세력마다 1~5·6~10·11~15·16~20 구간 지역이 하나 이상(21 이상은 천명원 무극 관성대만). 소속·좌표를 바꾸면 geo.js buildCells로 연결과 레벨 구간을 확인(좌표는 이동 시간에도 쓰임).
- 세력마다 들머리 지역(world_faction_join_regions)에서 가입·가입 퀘스트 보고. 대세력 가입 Lv5부터(faction_open 알림 한 번).
- 겨루기: A 방치 점령지(본래 주인 아닌 세력이 6시간 활동 없으면 감소 3%→8%/시간, 24시간이면 본래 주인에게) · B 독식 보정(본래 땅 밖 차지 수로 새 영향력 ×1·0.8(3)·0.65(4)·0.5(5+)) · C 주간 정산(pg_cron yh-faction-week 월 04:00 KST: 지킨 지역마다 그 주 활동한 조사원 공훈 5, 그 뒤 영향력 절반, faction_week 알림).

### 3.7 탐사 방식

텍스트 서술·발견·자원·조우를 조합하고 반복해도 결과가 다양하다. 결과는 서버에서 검증·저장한다.

- 빈손(outcome quiet, 기척이 사라진 조우 포함)은 탐색력 1을 돌려줌(world_stamina_change +1, 그때만 캐릭터 행 갱신 한 번 더).
- 꾸러미 2~3개·지역 특산물 50%+깊이×8%·전 3~(8+위험도×3). 대세력 조사원은 25%로 길에서 만난 이와 나눠(개수 −1·전 절반) payload.infl 1.5 → world_influence_tick이 탐색 0.3에 더함.
- 조용히 살피기 world_field_search_quiet(yh.quiet): 조우 무게 ×(1−q)·꾸러미 ×(1−q/2), q = min(0.5, (민첩+감각)×0.008), payload.quiet_mode, home.js quietOn(yh-quiet-search).
- 기척 숨기기 world_battle_action('sneak'): 마주친 직후(turn_count 0) 한 번, world_sneak_pct = 25+민첩×0.8+감각×0.5(+조사원 10)−(요괴Lv−내Lv)×3−우두머리 15, 10~75%. 성공 fled(battle_fled.sneak), 실패면 그 턴에 요괴가 침, 탐색력 반환 없음. battle.js sneak-ask(world_field_battle_view.sneak).
- 채집 간격 12초(world_guard_repeat_farming, 채집터 무관 — 함수 맨 앞 world_rate_check('gather')가 잠그기 전에 먼저 돌려보냄). 화면은 성공 뒤 기기 시계로 12초 모든 채집 단추를 잠그고 남은 초 표시(home.js setGatherCd·paintGather, yh-gather-cd, 거절되면 3초).
- 채집은 한국 시각 하루 처음 10번 탐색력 무료(payload.free_day, 응답 free_left). 채집터마다 하루 제한은 두지 않는다(찾은 채집터가 많아 재료가 넘침).
- 바깥 지역마다 들머리(답사 첫 칸)에 「어귀의 …」 채집터를 두고 처음부터 찾은 것으로(새 캐릭터 trg_world_entry_spots).

## 4. 이동과 탈것

이동 시간은 거리·위치·지형을 반영한다. 탈것은 안전지대 마구간에서 들이거나 특별한 사건으로만 얻는다(가방·메뉴 바로 구매 없음). 세계 지도에서 이해하기 쉽게 제공한다.

- 운임: 구간마다 노정패 1~2개(world_travel_route가 출발 때 구간 수×운임 차감), 모자라면 걸어감(×1, 운임 없음). 내리기 world_mount_unequip(mount_id null이면 걸어서, fn_owner_field에 world_characters.mount_id 열 쓰기만 줌).
- 노정패: 토벌 승리 1·탐색·채집 6번에 1번꼴 1·이야기 3·의뢰·임무 2(원정 귀환 없음). 쓰는 곳: 원정 운임(외곽 1·심부 2·핵심 3), 탈것 단련 world_mount_train(마구간, 20×다음 단계, 단계마다 속도 +4%, 최고 5, world_owned_mounts.training).
- 이동 보상(경험치·탐사 기술·상태 굴림·세력 임무·이동 칭호/꾸미기)은 도착 기록(world_events travel + travel_history_id)에만. 상태 굴림은 안전지대 도착이면 없음, 바깥 도착은 1/3.
- 취소 world_travel_cancel: 출발 60초 안, 위약금 없음, 뒤 3분 출발 불가(world_guard_action_context).
- 이동 중(travel_destination 남음) world_mount_equip 거절(map.js도 막음).
- 이동을 시작하면 남은 시간이 화면 위에 계속 보이고 도착을 알린다.

### 파티 동승 규칙

- 파티원에게만, 탑승 정원과 탈것 조건 검증. 수락하면 검증 뒤 출발.
- 전투 중·자율 활동 중인 캐릭터는 이동·동승 불가.
- 동승 요청이 취소되어도 상대의 독립 이동은 계속되고, 제안자도 자기 이동을 독립적으로 취소할 수 있다.
- 출발·도착·운임 차감은 서버에서 일관되게, 동승 수락 시 운임 이중 차감 없음, 양측 위치·이동 상태 일치.

동시 요청을 실제로 테스트한다. 버튼 비활성화로 중복 이동·차감 방지를 대신하지 않는다.

## 5. 전투와 몬스터

전투는 중요한 축이지만 유일한 콘텐츠가 아니다. 몬스터는 체력·공격력만이 아니라 행동 수법과 대응법을 갖는다.

설계 기준: 몬스터별 체력·공격력·난이도·행동 구분, 일부는 조건부 행동 / 직업별 이점과 근거리·원거리 특화(필수 직업은 없게) / 행동·결과 서버 검증, 중복 공격·보상·상태 충돌 방지 / 상태이상·생존 수치가 결과에 영향 / 전리품은 몬스터·지역 특성에 연결.

### 요괴 갈래·수법·도감

- 13갈래(world_monster_kinds: 비금·갑각·영귀·독충·목령·은형·수귀·군충·금주·경요·파봉·천상·거괴, world_region_monsters.kind). 갈래마다 무기(근접·원거리·술법) 배율과 유리한 직업(+20%)(world_kind_mult: 현장은 피해에, 원정은 위협을 배율^0.6으로 나눔).
- 수법 39개(world_monster_gimmicks, 갈래마다 Lv1·10·20부터 하나씩, gtype big·charge·status·drain·heal·shield·evade·thorns·grapple·mirror·summon). 현장은 world_battle_intent_k가 단계별 12/22/30%(정예·우두머리 +6%p)로 'g:키'(터뜨리는 턴 'g!:키') 예고, 화면엔 이름·낌새만(대처 안내·버튼 없음). 방어는 어느 수법이든 피해를 줄임(큰 한 방·터뜨림은 1/4). 거울막(mirror)은 바로 다음 행동 한 번에만, 되돌리는 피해 술법 피해 30%·최대 15, 체력 1 아래로는 안 깎음. 모으는 턴에 체력 15% 넘게 깎거나 봉인술로 묶으면 끊김. 원정은 world_exp_fight_story가 두 번째 합에 한 번(Lv10부터), 기술 단계(2단계 수법 15·3단계 30 기준)·레벨 차·능력치로 10~75%(상성 무기·직업 +25%p) 저절로 대처.
- 요괴 도감 world_monster_codex(world_battle_open·trg_world_codex_on_event(전투 한 번에 한 번, p_seen=1)·원정 묘사가 적음): 만나면 기본 정보, 쓰러뜨리면 상성·파훼법(world_gimmick_tip)·전리품(world_monster_codex_snapshot). 전투 화면 상성 배율도 쓰러뜨린 요괴만.
- 채집 도감 world_gather_codex_snapshot(현장 채집 기록 32가지 재료): spots(지역 8곳까지, c 채집터 수·fc 찾은 수·s 이름 넷 — 찾은 곳 먼저·출입 레벨 순)를 journal.js spotsHtml이 지역마다 한 줄(「지역 Lv.n+ · 찾음 a/b — 채집터 둘(Lv) 외 n곳」, 지역 둘까지·「외 지역 n곳」). 일지 › 도감 = 요괴·채집·어종.
- 지역 정보 공개(world_field_snapshot, 서버가 가림, 답사도는 한 번만 계산 svj): 출몰 요괴 갈래만 → 답사도 30% 일반 요괴 → 70% 우두머리(만난 요괴는 바로), 얻는 것 30% 채집 재료 → 70% 전리품 → 100% 희귀품.

### 레벨 차와 장비 상태

- 체력은 레벨 무관 100, 요괴 공격력은 레벨마다 오르므로 요괴보다 높으면 받는 피해 레벨마다 −3%(최대 30%), 낮으면 +3%(최대 30%). world_battle_action·world_expedition_settle(원정지 최소 레벨 + 1 기준) 같은 식.
- world_field_snapshot.gear_warn(내구도 1/4 아래 장착 장비)을 현장·전투 화면에 띄움. 체력 35 아래에서 탐색하면 한 번 묻는다(home.js doSearch).

### 파티 현장 토벌(c_pfight.sql)

- 현장 토벌 중 world_pfight_call(전투 행동 칸 여섯째 battle.js renderBattle opts.call .act.call) → 같은 곳 파티원에게 pfight_invite 60초 → world_pfight_join(탐색력 1, 요괴 체력 +70%×기준, 4명까지) → world_pfight_start 또는 마감.
- 속도순 차례: world_pfight_round가 라운드마다 속도(world_combat_stats.stats 민첩 + 감각×0.5) 순 turn_order와 노릴 사람(target_id, 이목^1.3)을 정함. world_pfight_act는 turn_id만 받고 world_pfight_resolve가 그 사람만 바로 푼 뒤 다음 차례(world_battle_action을 그 사람 JWT sub로, yh.pf_resolve로 1초 간격 건너뜀). 요괴는 노린 사람 차례에만 반격(yh.pf_skip 0, 빠졌으면 그 뒤 첫 차례, mon_done), 기운 모으기 끊기는 라운드 누적 피해 round_dmg. 차례를 30초(round_ends) 비우면 스냅샷 읽을 때 방어로(예약 작업 없음, 초를 세지 않음). 파티 토벌 중 world_battle_action 직접 호출 불가.
- 쓰러짐은 실제 전투불능(구조 필요) — 물러남·쉬는 중 없음.
- 보상은 혼자 토벌과 같음(전리품 각자 굴림, 분배 풀 안 씀) + 경험치 +10%/명(3명까지).
- 화면 views/pfight.js(#/pfight/<id>): .raid-wrap.pf-wrap(PC 왼쪽 요괴·행동·기록, 오른쪽 참가자), 「내 차례」 띠 .pf-turn, 차례 줄 .pf-order(요괴는 노린 사람 뒤), 단추는 내 차례에만, 참가자 .raid-mem.pf-mem 두 칸(순번·체력·직업·차례/행동함/기다림·노림받음). 다시 읽기: 남의 차례 2초·내 차례 10초·모이는 중 3초 world_pfight_snapshot(turn_id·my_turn·order·mon_done·members[].spd).

### 전투불능과 구조

전투불능은 실제 영향을 주는 상태로, 다른 플레이어의 구조나 허용된 수단이 필요하다. 상태·구조 요청·구조 성공·복귀가 서버와 화면에서 일치해야 하고, 구조가 필요한 사람을 알아볼 알림·표시를 둔다(§14).

- 본부 구조대 world_call_rescue: 소지금 15%(최소 30전·최대 레벨×80전, Lv15 미만 레벨×40전, 한국 시각 하루 첫 구조 반값) + 이번 레벨 필요 경험치 5%(레벨 하락 없음). 옮겨 가는 가장 가까운 안전지대가 내 대세력 지배면 다시 반값·경험치 손실 없음·체력 50. 정통파는 어디서든 세력 구조대(§11).
- 요화로 쓰러진 사람은 구조할 수 없다(§8).

## 6. 캐릭터 성장과 직업

능력치·직업·소속·특성으로 차별화하고, 레벨 하나가 아니라 실제 행동에 따라 관련 기능의 숙련과 경험을 얻는다. 숙련 원칙: 행동 종류·결과에 맞는 경험, 숙련이 오르면 효율·선택지 개선, 상한 있음, 관계없는 능력이 함께 오르지 않음, 반복 입력·비정상 요청 방지.

### 기술 계열과 숙련

- skill_progress에 경험: 단계 r→r+1에 80+8r, 30단계부터 6×(r−29)²를 더함(누적 40단계 11,670·50단계 30,940), 최고 50(world_skill_line_xp·world_skill_line_rank). 탐색 한 번 탐사 경험 5.
- 계열: 전투 근접·원거리·봉인술·분석·막기(guarding)·응급 처치(first_aid) / 조사 탐사(tracking) / 채집 foraging(herbs·wood·supplies·water·spirit)·mining(ore·relics)·fishing(던질 때마다 8) / 제작 smithing 단조·carpentry 목공·artifice 법구 공예·wardcraft 봉인 공예(분야 키 sealing)·weaving 직조·leatherwork 가죽 공예·alchemy 연금·cooking 요리(world_craft_line_of(분야)·world_line_name). 옛 herbalism·spirit_gathering 키와 요리 숙련(cooking_rank·cooking_xp)은 남아 있어도 쓰지 않는다.
- 숙련 4갈래(combat/gathering/crafting/investigation_rank) = 그 갈래 계열의 최고 단계(trg_world_skill_sync·world_skill_sync). 제작으로 오르는 계열 = world_craft_line_of(제작법 craft_field)(world_event_char_apply).
- 토벌 행동 기술: world_battle_action이 승리 기록 payload.acts(analysis·guarding·first_aid: 집중·방어·회복품/처치 횟수), world_skill_add가 종류마다 least(3,n)×8.
- 단계 보상(3·8·13·18·24·30·36·43·50단계): 기본(slot base), 13·30 추가(extra), 24·43 택일(a·b, world_skill_choose, world_skill_picks — 처음 무료, 바꾸기 24단계 2,000·43단계 5,000전), 50 숙달(master). 근접은 13·24·30·43 모두 택일(A 공격 발도·일격·유수검·파천 / B 방패 호령·도발·철갑 강기·사자후, 이목은 world_combat_stats). 봉인술도 13·24·30·43 모두 택일(A 몰아치기 연쇄부·폭렬부·연환부·천뢰부 / B 북돋기·약화 부적 접기·호체부·겹술식·청정결계; 바꾸기 13단계 1,000·24 2,000·30 3,000·43 5,000전). 무료 다시 고르기 world_skill_picks.free_repick(기한 없음, 롤백 때 사라짐). 무기 강화 택일은 근접 단조·원거리 목공·술법 법구 공예 43a.
- 조합 기술 12(category combo, requires 두 계열 18단계, 원본 world_skill_catalog): 대장장이 검객·사냥꾼의 눈·영맥 판독(분석·채집)·야전 약방(응급 처치·채집)·현장 조제(채집·연금)·바위 몸(막기·채광)·영맥 세공(채광·법구 공예)·짐꾼의 요령(채광·가죽 공예)·그물 짓기(낚시·직조)·갯가 주방(낚시·요리)·낚싯대 깎는 손(낚시·목공)·겹봉인(봉인술·봉인 공예).
- 보유 판정 world_skill_has 하나(world_skill_effect·world_combat_stats·world_skill_snapshot 공용). 전투 피해·치명타는 world_combat_stats, 그 밖은 world_skill_effect(상한: 채집량 40·희귀품 22·단서 28·회복 45·제작 품질 40·주는 피해 15·받는 피해 −28·정신 손실 −32·침식 −28·이동 −20·조우 −15) → world_status_effect_total. 숙련 효과는 50단계 기준(전투 숙련 공격력 단계마다 +0.6% 등). 기본 기술 효과는 그 계열 분야에서만.
- 고유 효과: 이름 있는 기술(추가·택일·숙달·조합)은 passive_effect가 비고 행동을 바꾼다. world_skill_procs(uid)가 skill_id 목록을 주고 world_battle_action·world_field_gather·world_craft_item·world_field_search·world_travel_route·world_field_rest·world_weapon_enhance·world_enhance_quote·world_equipment_repair·world_repair_quote·world_rescue_character·world_combat_stats(도발 이목 +60)가 처리. 원정은 world_exp_skill_def(atk·guard·win·loot·find·heal·ward·일지 줄)를 world_exp_skill_fx가 합쳐(상한 전투력 25·피해 30·승률 0.08·채집 30·발견 35·회복 4·침식 35) settle에 보정과 「[기술] …」 줄로. 새 고유 효과를 넣으면 이 함수들과 skill_catalog.description을 함께 고친다.
- 기술 칭호 32(ct_<계열>_15·35·50, gt_<계열>_25·50, ct_all_50·gt_all_50, 규칙 'skill'·'skill_all'). 함수 주인 역할은 기술표를 못 읽으므로 이름은 world_skill_name. 생성기 supabase/gen750(skills_draft.json(사용자 확정 시안 5, decisions_5) + f_*.sql·m_*.sql → gen.py).
- 분해 world_dismantle_item: 언제나, 그 장비 계열(world_gear_line: 제작법 분야 → world_gear_line_map(제작법 없는 장비, 새 장비마다 한 줄) → 부위) 경험 12. 계열 단계가 world_dismantle_need(1·3·6·9·12·15)보다 낮으면 경험만(하루 제한 없음), 아니면 제작법 재료 절반 반환. 미리 알림 world_dismantle_info.
- 화면 캐릭터 › 기술: 갈래(전투 | 채집+조사 | 제작)별로 계열마다 단계·경험 게이지와 ㅁ-ㅁ-ㅁ 노드, 누르면 기술·효과 펼침. 고를 택일 기술이 있으면 캐릭터 탭·기술 칸 빨간 점(world_skill_pending, titledot.js가 칭호 수와 같은 때 읽음, 노드 점 .sk-node.pick inline-block). 협동 기술 목록 world_coop_list.

### 퀵슬롯

world_quickslots(8칸, world_quickslots_get·set), 캐릭터 › 상태 맨 위(기본 QS_DEFAULT), 상태판 hud.js qsCard(소지금 아래 4×2, 10분 캐시, 칸을 바꾸면 yh-qs-changed).

### 능력치(a_basic.sql)

- + / − 로 쌓고 다 누른 뒤 600ms에 world_combat_preview(p_alloc) 한 번, world_allocate_stats(p_alloc jsonb)로 한 트랜잭션 반영(포인트 합·상한 검사, 캐릭터 행 갱신 한 번·progression 한 줄). 옛 world_allocate_stat은 남아 있음.
- 한 능력치 상한 world_stat_cap_of = 직업 기본값 + floor(1.5×레벨)(character.js statCap). 세심단·환골탈태·world_reset_points도 직업 기본값 기준.
- 방어구 조건은 적힌 능력치와 짝(world_stat_pair: 체질↔힘·민첩↔감각·의지↔영기) 중 높은 것(world_equip_item·item.js STAT_PAIR), 장신구(관모·신·노리개·호신부·탈)는 가장 높은 능력치, 무기·도구는 그대로.

### 캐릭터 신원

- 가입 후 최초 1회 생성 화면에서 이름·직업·소속, 이후 로그인은 바로 게임. 이름·직업·소속은 바꿀 수 없고 설정에도 변경 선택지가 없다. 예외 귀속 소모품(거래 불가·창고 가능, 모두에게 하나씩): 환골탈태 서첩(reset_identity, world_reset_identity: 직업·소속 다시 고르기·대세력 탈퇴·전용 장비 해제·포인트 반환), 세심단(reset_stats, world_reset_stats: 능력치만). 이름은 불변. 창 item.js openResetIdentity(모바일 .ri-grid·.sticky-actions).
- 이름 중복은 서버가 막는다(대소문자·앞뒤 공백 무시).
- 소속 효과(world_affil_effect → world_status_effect_total, 경제 world_affil_cap·world_affil_tax): 본부 직속 제작 품질 +4·회복 +5%·판매 한도 +500전 / 현장대응국 채집 +6%·이동 −6%·조우 −5% / 기록감찰국 단서 +8%·희귀품 +3%·주는 피해 +2% / 봉인관리국 정신 손실 −10%·침식 −8%·주는 피해 +3% / 의무지원국 회복 +10%·받는 피해 −4%·채집 +3% / 외부 협력자 이동 −5%·희귀품 +2%·판매 수수료 3%. 하루 소속 보급·소속 임무도 소속마다. 화면 core.js FACTIONS.
- 직업(내부 키 / 이름 world_job_label·world_job_name / 화면 core.js JOBS): 호위 무사 artificer 근접 · 현장 조사원 scout 원거리 · 퇴마관 exorcist 술법 · 의무관 medic 치유 · 봉인술사 sealmaster 보조(북돋기·약화) · 백공 기술관 analyst 생활.
- 기본 능력치 world_job_base(합 30): 호위 무사 힘9·체질7·민첩5 / 조사원 민첩8·감각8 / 퇴마관 영기9·의지7 / 의무관 의지8·영기7·체질6 / 봉인술사 의지8·영기7·체질5 / 백공 감각7·민첩6·체질6·힘5, 나머지 3~4.
- 직업 효과 world_job_effect(피해 %는 그 역할 무기를 들었을 때만): 호위 무사 근접 +8·받는 피해 −6(이목 +30은 world_combat_stats) / 조사원 원거리 +8·회피 +6·도주 +15 / 퇴마관 술법 +8 / 의무관 회복 +10(물품 ×1.15, world_party_use_item ×1.4) / 봉인술사 정신 손실 −10·침식 −5 / 백공 채집 +15·희귀품 +3(제작 품질 +15·강화 +10%p·현장 가공·채집터 찾기). 호위 무사 현장 기술 파갑참(근접 ×1.7·방어·결계 무시). 백공은 다른 직업 전용 제작법(required_job)도 만든다(world_craft_item·bag.js jobOk, 장착 조건은 그대로).
- 의무관 응급 처방(현장): 한 전투 한 번(world_active_encounters.pfx med_used)·기력/영력 25·체력 least(40, 15+체질/2+의지/2). 의무관 회복품 ×1.15(world_battle_action 두 곳·world_use_item·world_expedition_settle).
- 시작 장비(world_create_character_v2): 호위 무사 월철 환도·쇠미늘 갑옷·무명 두건·주사 호신부 / 조사원 매눈 활·화살 100·무명 철릭·미투리 / 퇴마관 영령 방울·삼베 도포·무명 부적낭 / 의무관 먹 부채·삼베 도포·쑥 향낭(+약초·탕약) / 봉인술사 무쇠 금강령·누비 전포·유건(+봉인 부적) / 백공 날선 단도·누비 전포·술 노리개·짚신(+낚싯대), 모두 현장 채집도 장착·월철 곡괭이.
- 세계관 안내 assets/js/lore.js: WORLD_PRIMER·JOB_LORE(한자 이름·한 줄 말·내력·전투·원정·무기·유리한/덜 듣는 갈래·어울리는 사람·조심할 점·인연)·AFFIL_LORE를 생성 화면(고르면 카드 아래 펼침)과 도움말이 함께 쓴다. 도움말 세력 이야기 guide.js FACTION_LORE(이름·소개 common.js MAJOR_FACTIONS). 수치 원본은 core.js JOBS·FACTIONS.

### 전투 능력치

- 탐색력 1 회복 15분(world_stamina_now·world_stamina_change /900), 노정 건량 +2.
- 피해 계수: 근접 힘 1.0 · 술법 영기 0.75·의지 0.4 · 원거리 민첩 0.6·감각 0.45. 피해 % 합 상한 +35%, 칭호 피해 % 절반, 치명타 150%(world_combat_stats·world_battle_action).
- 사냥 경험치 (6+요괴Lv×3)×world_xp_gap_mul(요괴Lv−내Lv: −6↓ 0.2·−3~−5 0.5·−1~−2 0.85·+1~+2 1.15·+3~+4 1.3·+5↑ 1.5), 토벌 기록 12. 내 레벨보다 3·5 높은 바깥 지역은 침식 +50%·+100%(world_level_gap_effect). 퀘스트·이야기 전 ×0.4.
- 상시 의뢰 world_commission_board(×0.4 없음, trg_world_commission_gil_v6는 남았지만 안 깎음): 토벌 160+25L·채집/정찰 110+19L·납품 시세×수량×1.2+30+5L(하루 셋 합 Lv10 약 1,000·Lv30 약 2,000전).
- 전투 행동 간격 1초(world_battle_action, 토벌 기록 world_guard_repeat_farming도 1초). 간격 검사는 잠그기 전에 공용 world_rate_check(kind gather·fish·battle·raid)로 먼저(연타가 처리 후 되돌림·공용 행 잠금을 만들지 않게). 새 연타 행동도 이 함수로. 화면은 응답 받은 때부터 기기 시계로 1초, 캐릭터는 단추를 잠그지 않고 뒤에서 다시 읽음.
- 공격·방어·회피·치명타·도주 확률은 world_combat_stats 하나로 계산해 엔진과 화면이 같은 값을 쓰고, 올리기 전에 바뀔 값을 미리 보인다.

### 칭호

- 249개(공개 179): 세력 수련장 14(분류 '세력', world_faction_trial) / 기본 100(공개 50·숨김 50) / 낚시 / 이야기 6~9장 4 / 비무 10(공개 8·숨김 2, 규칙 'spar') / 요화 5(귀령의 손길(성장)·나머지 비밀 숨김, 규칙 'yohwa' — world_yohwa_log onset·stage3·seal·cure) / 도감 20(규칙 'codex' kind·all·kinds·gather, world_codex_rule_count). 토벌·별채·외전·레거시는 해당 절.
- 「야행국 운영진」(gm_staff, 분류 '운영', 효과 없음)은 world_staff에만, 남의 목록에 안 나옴.
- 등급 world_title_catalog.grade 1 범품·2 양품·3 진품·4 명품·5 신품(색 회색·초록·파랑·보라 칠·주홍 칠), 어려울수록 높고 효과도 큼(첫 효과 그 등급, 둘째·셋째 한·두 등급 아래). 효과 키: 주는/받는 피해·근접/원거리/술법·치명타·회피·달아나기·방어·이목(world_combat_stats가 world_title_bonus_of로)·회복·침식·정신 손실·조우(world_status_effect_total이 world_title_extra로)·단서·희귀품·채집·제작·이동·낚시.
- 최대 3개 장착 + 대표 칭호 하나(채팅·프로필). 숨김 칭호는 얻기 전까지 이름·조건을 서버가 감춤.
- 칭호 묶음 world_title_presets(world_title_preset_save·apply·clear, world_title_snapshot.presets·preset_slots·preset_unlocks): 처음 3칸, 「믿음직한 해결사」(의뢰 50)·「대지의 손」(채집 500)·「공방의 주인」(제작 200)마다 한 칸(최대 6, world_title_preset_slots). 상태판 「칭호 바꾸기」 hud.js openTitleSwap(누를 때만 world_title_snapshot).
- 화면: 분류별 카드 격자(더 보기 없음)·분류 칩·「얻은 칭호만·장착 중만」·못 얻은 공개 칭호 진행 게이지(world_title_rule_progress)·장착/대표 단추는 카드 아래. 모바일(640px↓) 두 칸 카드에 설명·조건·효과 모두, 대표 단추는 카드 오른쪽 위(.t-rep). 새 칭호는 캐릭터 탭·칭호 줄 빨간 점, 화면을 열면 world_character_titles.seen_at으로 확인. 알림 「보러 가기」는 sessionStorage yh-title-focus·yh-cos-focus.

직업·세력은 플레이 스타일을 나누는 수단이며 모두를 같은 경로로 강제하지 않는다. 성장 수치와 공식은 기존 구현을 조사한 뒤 조정하고, 확정되지 않은 수치를 임의로 새 규칙으로 만들지 않는다.

## 7. 채집과 제작

### 가방 용량

- 같은 물품은 묶음(world_item_catalog.stack_size)까지 한 칸: 장비·가구 1 · 탄 100 · 고급 소모품(진품 이상) 20 · 그 밖 재료·소모품·임무 물품 40(사용자 결정). 새 물품도 같은 기준. 희귀도 이름은 칭호 등급과 같음.
- 칸 = 물품마다 올림(수량÷묶음)의 합(world_bag_count·world_inv_count·world_bag_room, core.js bagUsed). 기본 24칸, 넓히기: 이야기 1장(붉은 인장) +5·2~5장 +3씩·지역 답사 보고서 +4·지역 완전 답사 +1·수향연맹 +6 등.
- 완전 답사(+1칸)는 길·채집터를 찾을 때마다 판정(world_survey_award, world_exploration_discoveries·world_gathering_discoveries 삽입 트리거 trg_world_survey_award).
- 장착 장비는 칸을 안 쓴다: inventory에 남으므로 서버는 장착 수만큼 용량을 더하고(world_bag_limit·world_enforce_bag_capacity·원정 귀환·보따리·직접 거래), core.js bagUsed는 뺀다. 장착 목록은 접속 때와 장착을 바꾸는 행동(장착·해제·원정 귀환·환골탈태·분해, core.js act) 뒤에만 다시 읽는다. 서버에서 가방 자리는 bag_capacity가 아니라 world_bag_limit으로 따진다.
- 내주는 행동(구매·제작)은 가방이 넘치면 거절, 얻기만 하는 행동(전리품·채집)은 넘친 만큼 버리고 알림. 같은 갱신에서 물품이 줄기도 하면(마지막 한 방의 화살·회복품) world_enforce_bag_capacity가 맞바꾸기로 보고 거절하므로 얻기만 하는 함수는 yh.bag_drop을 켠다(world_battle_action).
- 트리거 world_normalize_item_rarity가 단계(1~6)로 희귀도(1 범품…5·6 신품)·acquisition_difficulty(최대 5)·drop_rate_modifier를 덮어쓴다(검사 world_item_catalog_tier_check 1~6) — 새 물품은 단계만 정하면 된다.
- 잠금(world_item_locks)은 팔기·버리기·거래를 막음(사용·재료는 됨). 장착 중인 장비의 마지막 한 개도 내줄 수 없다.
- 물품 정보 창: 들어가는 제작법과 제작 화면 바로 가기. 분해·버리기(·창고에 모두 넣기) 성공하면 닫힘(item.js run — 반환값이 아니라 성공 여부로 판단, world_item_discard는 값을 안 돌려줌). 「얻는 곳」 world_item_sources: 채집터·조사 지점·요괴·낚시터 지역을 낮은 레벨부터 갈래마다 두 곳까지 한 줄(「외 n곳」을 누르면 world_item_sources_all 겹친 창), 제작·대장간 smithy·상점 shop·세력 비고 vault. 지역 이름을 누르면 지도에서 짚음(item.js src-go). 바로 맡기기 item.js stash(zonesNow로 안전지대·반요촌 아님·이동 중 아님일 때만, 서버 world_storage_put이 재검사).
- 물품 한 원본(7.7.7o): 사용 효과는 world_item_catalog.use_fx 한 칸(world_item_fx가 읽음) — 가방 정보(world_inventory_snapshot)의 물품 목록 fx·mk·tl과 fx_names(상태 이름·지속·효과)로 화면 item.js USABLE(효과 문구·사용 단추·색·거르기)·토벌 물품 칸(fightui.js battleItems·isSpItem)·동료 돌보기·퀵슬롯이 따른다. 새 소모품은 use_fx만 채우고, 회복·기운으로 못 적는 특별 물품만 item.js USE_SPECIAL. 물품 목록은 로그인 때 views/common.js ensureCatalog(같은 db_version이면 기기 것). 등급 이름은 core.js GRADES, 직업 이름은 JOBS, 날씨·시간대·희귀도 이름은 nameOf.
- 소지품: 정렬 기본(단계)·획득순·이름순·희귀도순 × 정/역순, 획득순은 world_item_acquired(수량이 늘 때 트리거가 기록, 기록 전 물품은 오래된 것). 「칸대로 나눠 보기」(기본 켬·yh-bag-split): 묶음 크기만큼 한 줄씩(가득 찬 칸 먼저, 장착 중인 하나는 따로), 「사용」·「열기」는 줄마다. 물품마다 「창고 n」(world_storage_snapshot 5분 캐시, 창고 행동 뒤 새로). 「효과」 칩 회복 종류 거르기(bag.js fxPick, 하나라도 맞으면). 이름 아래 짧은 설명 core.js brief.

### 개인 창고(world_storage)

- 어느 안전지대에서나 같은 창고, 기본 60칸(가방과 같은 묶음). world_storage_snapshot·world_storage_put·world_storage_take(들어가는 만큼)·world_storage_expand.
- 넓히기(world_storage_capacity, 최대 98): 전 4번 +4씩(1,000·2,500·5,000·10,000전)·이야기 6~10장 +2씩·대세력 평판 300·600·1000 +2씩·완전 답사 10·20·30곳 +2씩. 줄어 넘쳐도 물품은 남고 맡기기만 막음.
- 보기는 어디서나(snapshot can_move·reason·in_safe, 가방 › 제작 「창고 보기」), 맡기기·꺼내기는 안전지대만. 버리기 world_storage_discard는 어디서나(잠금·귀속 소모품 거절). 장착 중·강화한 장비의 마지막 하나·임무 물품은 못 맡기고, 전투불능·이동·원정·자율 중엔 못 씀(world_storage_check, world_seal_guard). 행동 기록 없음.
- 안전지대 제작은 world_craft_item이 모자란 재료를 창고에서 꺼내 씀(가방 먼저, 반요촌 제외), 제작 화면 재료 수에 창고 몫 표시. 결과가 가방에 안 들어가면 제작 전에 거절.
- 창고 창 분류 칩·이름 찾기(services.js renderStorage, 줄만 숨김).

### 장비 칸과 이목

- 칸: 무기·방어구·관모(hat)·신(shoes)·노리개(norigae)·호신부(amulet)·탈(mask) + 생활 칸 채집(tool)·탐사(explore: 나침반, search_find_pct, world_explore_find_pct)·낚시(fishing: 낚싯대, world_fish_rod). 생활 칸은 equipment_traits.life_slot(없으면 채집). 'craft'(제작 공구)는 장착 안 하고 가방에 있으면 world_craft_tool_bonus가 그 분야(craft_fields) 품질 +craft_quality(가장 큰 것 하나). world_equip_item / world_unequip_item, 전투·원정 중 착탈 불가. 장비 category는 반드시 칸 이름 중 하나. 화면 item.js SLOTS·bag.js TOOL_LINE.
- 장비 1~6단계(6단계 귀허도 Lv32), 같은 단계도 갈래가 다름(무기 묵직·예리·소리 없음, 방어구 쇠미늘·철릭·도포·야행복). 5단계도 거래·되팔기·분해 가능.
- 특성 합 world_gear_total(무기 위력·피해·방어구 방어·피해 감소·도구 채집·낚싯대 특성 제외) → world_status_effect_total, world_combat_stats가 방어·회피·치명타·달아나기·이목을 더함(상한 회피 40·치명타 60·달아나기 95).
- 이목 = 30 + 체질×0.8 − 민첩×0.4 + 방어구 방어력×0.6 + 장비 이목(5~300). 원정 합동 전투·파티 토벌·보스가 이목^1.3로 표적.
- 주 능력치 조건(레벨당 3점 기준): 무기·방어구 5+0.35×3×(장착 레벨−1), 관모·신·노리개·호신부·탈·채집 도구 5+0.25×3×(장착 레벨−1). 주 능력치는 무기 종류·장비 갈래로. 새 장비도 같은 식.
- 생활 도구(g_tools.sql·b_life.sql·data_life.py): 능력치 조건 없이 equipment_traits.req_line(gathering_rank·crafting_rank·investigation_rank)·req_rank(world_equip_item, item.js statReqs). 제작 공구 조건은 craft_fields 계열 중 최고 단계. 효과(world_field_gather): 곡괭이(world_tool_lines pick)는 ore·relics, 채집도(knife)는 herbs·wood·supplies·water에서 채집량 +10%p, 낫·등은 sig_pct·sig_where로 지역 signature_items(영맥 낫 herbs·spirit 3%·영등 relics 또는 어두운 region_type 5%). 영맥 나침반은 길·채집터 무게 ×1.2. 낚싯대 단계 덤은 2단계까지, 그 위는 fish_bite_pct·fish_rare_pct·fish_size_pct. 생활 장비 32가지 lt_*(곡괭이·채집도·낫·등·나침반·낚싯대 6단계·제작 공구 15, 제작법 r_lt_*). 새 도구도 이 규칙.
- 상위 도구: world_tool_lines(채집도 field_knife→field_knife_2→t3_gather→t5_gather, 곡괭이 ore_pick→t4_gather)·world_tool_covers로 높은 단계 도구가 낮은 단계 조건을 채움(world_craft_item, 화면 bag.js toolCovers는 물품 목록 tl·tier — world_tool_lines 한 곳만 고침). 채집은 도구를 조건으로 보지 않는다.
- 장착 조건(레벨·직업·소속·능력치)은 world_equip_item이 검사, 가방 › 장비·물품 정보에 「장착 조건」 초록/빨강. 여러 직업 제작법에 쓰는 도구는 한 직업 전용으로 두지 않는다(각인 공구·강화 채집도 무제한, 영맥 낫은 조사원 전용).
- 드롭(world_gear_drops, world_gear_roll): 한 번에 하나, 일반 최대 1%·정예 5%·우두머리 15%(희귀품 보정), 3단계 이상은 우두머리만, 원정 60% 수준. 2~4단계 제작법, 5단계 일부 무극 관성대 제작, 1·2단계 일부 상점.
- 가방 › 장비: 900px 이상 왼쪽 장착 칸(eqMini pick)·오른쪽 고른 부위(#eq-detail: equipRowLi + 바꿔 낄 장비, bag.js eqSel 유지) 나란히(.eq-split), 좁은 화면은 칸을 누르면 부위 창(성공하면 닫힘).

### 무기 소모

- 근접 기력(spiritual_power, 근접 무기면 노란 「기력」 core.js spOf) 공격마다 2, 술법 영력 3, 원거리 equipment_traits.ammo(ammo_arrow·ammo_bolt·ammo_dart, 묶음 100, world_ammo_of) 한 발 하나. 없으면 피해 절반. 원정은 회차마다 둘, 떠날 때 없으면 원정 전투력 ×0.6. 새 원거리 무기에는 ammo를 단다.
- 현장에서 그래서 피해가 절반이면 화면 아래 알림(battle.js weakNote: 서버 문구 「쏠 것이 떨어져」「기력이 바닥나」「영력이 바닥나」, 5초에 한 번; pfight.js는 「내 이름 · 」로 시작하는 새 줄만). 서버 문구를 바꾸면 여기도.

### 싸우는 중의 물품

현장 토벌(world_active_encounters result null·defeated·fled 아님)·파티 토벌(status fight·out_reason null)·귀허의 주인(status fight) 중에는 world_use_item·world_party_use_item 거절. 화면은 퀵슬롯·가방·상태 창의 물품을 core.js useItemAct → battleItemRoute(yh-battle-item)로 전투 화면(battle.js·pfight.js·gw.js)의 「물품」 행동으로 보낸다(턴·라운드를 씀). 새 물품 단추는 useItemAct를 쓴다. 현장·파티 물품 칸 battle.js trayList는 보통·우수품(_hq)을 함께, 귀허는 world_gw_snapshot.items가 _hq 수도. 합동 토벌은 §10. 꼬마 동무 바구니·알은 「열기」(world_pet_adopt).

### 장비 내구도

무기는 공격, 방어구·관모는 맞을 때, 도구는 채집, 신은 이동 구간마다 1씩 닳는다(노리개·호신부·탈은 안 닳음). 1/4 아래 성능 −20%, 0이면 효과 없음. 수리 도구(어디서나 절반) 또는 안전지대에서 전으로 완전 수리. world_item_durability는 사람×물품 하나(여럿이면 장착해 닳은 한 벌). 팔기·버리기·분해로 하나를 내놓으면 닳은 쪽 먼저, 0개면 기록 삭제(trg_world_wear_leaves_first, 세 함수가 yh.wear_leaves). 창고·거래는 그대로(공짜 수리 방지).

### 채집

자원은 지역 환경과 채집터에 따라 다르고, 위험이 클수록 보상도 크지만 이동·생존 부담을 따진다. 대기시간과 서버 반복 방지를 둔다(§3.7).

### 제작

- 재료·조건·결과는 서버가 검증하고 차감과 지급은 한 처리로, 중복 요청에 이중 차감·지급 없음. 제작 아이템은 전투·탐사·생존·생활에 실제로 쓰인다.
- 어디서나 제작, 지정 장소면 품질 +12.
- 분야 world_crafting_recipes.craft_field: 단조·목공·법구 공예·봉인 공예·직조·가죽 공예·연금·요리, 분야별 제작법 수는 고르게.
- 품질 = 10 + 계열 단계 + 계열 기본 기술(world_line_base ≤40) + 생활 전문화 분야 일치 12 + 백공 15 + 장비 crafting_specialization 10 + 제작 공구 + 상태·칭호(craft_quality, cq_<계열>) + 장소 12 − 8×난이도 + 0~19(world_craft_item). 개수는 안 바뀌고 85 이상(30단계 추가 기술이 있으면 80)이면 우수품.
- 우수품 <id>_hq(「… (우수)」, base_item_id·quality_grade 1, 시세 ×1.3, trg_world_item_hq_sync, world_item_base(id)): 제작법 있는 장비(수치 ×1.05 최소 +1·최대 내구도 ×1.1 world_item_max_durability)와 수치 효과 소모품(회복 ×1.15 올림·요리 기운 지속 ×1.2·수리 도구 60%, 탄·노정 건량·말린 생선포 제외)에만. 쓰는 곳은 world_item_base로 기본 효과를 찾음(world_use_item·world_battle_action·world_party_use_item·world_gw_act/resolve·world_tourney_*). 제작 재료·납품(world_quest_report·world_commission_claim)은 보통 먼저, 원정 보급은 우수품 먼저.
- 많이 쓰는 소모품·재료 기본 개수는 실제 평균에 맞춤(응축 영핵 3·청심환 2). 가구는 언제나 1개(덤·하나 더·칭호 cx_ 없음).
- 생활 전문화(world_set_life_profession_v2): 제작 분야 여덟 중 하나(기본 smithing, check 제약), 채집 fieldwork·mining·fishing.
- 노정 건량 준비(make_travel_ration)는 누구나.
- 즐겨찾기 world_craft_favorites(RLS·직접 읽기 없음), world_craft_favs()·world_craft_fav_toggle(p_recipe)(30개). bag.js는 접속 동안 한 번 읽고 거르기 칸·이름 앞 별·어느 정렬에서나 먼저.
- 여러 개 world_craft_batch(p_recipe_id, p_times 1~50): 한 요청 안에서 world_craft_item을 차례로(매번 검사·품질·덤·craft 기록). 실패한 한 번만 되돌리고 멈춰 만든 만큼 반환, 한 번도 못 만들면 그 까닭을 오류로. n=1이면 world_craft_item.
- 제작 화면(bag.js): 검색은 제작법·완성품 이름만(검색 중엔 거르기 무시). 이름·재료·도구를 누르면 물품 정보. 카드에 조건(레벨·직업·기술) 초록/빨강, 장비는 부위·단계. 설명 글의 완성품 이름 뒤에 「(효과: …)」(.desc-fx, descFx·gearFx, item.js traitText, 이름이 없으면 끝에, 부위 이름은 뺌, 효과 없으면 비움). 접는 「거르기·정렬」(craftFilterBox, 닫히면 한 줄 요약·켠 수, yh-craft-filt, 칩, 「거르기 모두 풀기」): 분야·「만드는 것」(부위 여덟·제작 공구·소모품·재료·가구, world_item_catalog.category로 가름, 장비·생활 도구·그 밖 묶음), 아무것도 안 고르면 전체. 정렬: 가능한 것 먼저·레벨 낮은/높은순(같은 레벨은 완성품 단계순). 횟수 [초기화] − n + [전부](craftN, 가방·창고·우수품으로 되는 만큼, 50까지), 「제작 ×n」은 오른쪽 아래(.craft-act, 한 줄: 횟수 단추 28px·제작 36px 오른쪽 끝, 카드 300px 아래면 여백 줄이고 망치 아이콘 뺌 — container query, 입력칸 input.cq-n).
- 효과 문구 색 item.js fxHtml·FX_KINDS: 체력 --hp·정신 --mp·영력 --sp·침식 --er·치료 --ok·탐색력 --gold.

### 영력 회복약

영초 차(+10, Lv1) → 청령단(+20) → 영기환(+35, Lv4) → 월광 정수(+55, Lv8) → 천령 감로(+80, Lv12). 의무관·회복 보정 적용, 전투 중에도 사용. 영초 차·청령단은 상점, 다섯 모두 제작법(야령초·수향 갈대·월광 이끼·약제 바탕·약초액·요기 결정·영유리·응축 영핵·성진사·영맥 수피).

### 낚시와 요리

- 낚시터 24곳: 강(백지교·구름나루)/늪(천엽 연화늪·폐쇄된 연화원·잿빛 갈대숲)/바다(재의 해안·구등대 군도·염등촌·만조의 갑문)/호수(천경호·수경루·설피골·유리협곡 월영 유리못)/깊은 물(용잠 수궁)/수로(구룡 폐수로·침수된 구시가지)/심연(흑조 균열·구중 봉연·귀허) + 바다 낚시터 다섯(십삼문 밀수 부두·빙혼곡 얼음 해안·주혈 광산 폐선창·월식성 바위 해안·관성대 별빛 벼랑). 풍경이 물가(water)인 지역에는 낚시터를 둔다.
- 낚싯대를 가방에 두고 탐색력 1로 20초마다. 원정·전투·이동 중 불가.
- 어종 37종(서식지·희귀도·시간대·날씨). world_fish_species.grounds(그 낚시터에서만, 비우면 같은 물 어디서나 — world_fish·world_fish_spot·world_fish_codex.where·world_item_sources가 거름, 도감 「…에서만」). 모든 어종은 제작법 하나 이상에 쓰인다(손질·요리, 등롱 어유→어유 등잔(등잔빛: 조우·침식·정신 손실 감소), 귀어 환혼단, 복어→독낭, 은린어→수귀 비늘, 봉인 먹·말린 생선포·4~6단계 낚싯대·수조) — 새 어종도 제작법을 잇는다. 도감은 못 낚은 어종 이름을 감추고 힌트만.
- 낚시 칭호 11(바다 sea_angler·tide_reader·nine_harbors·sea_dragon 포함): 입질·희귀 어종·크기 효과.
- 요리: 손질한 생선으로(바다 요리 9 포함). 생선 없는 음식(gen71/i_food.sql): 야령초 나물밥 Lv1 체력 20·월광 이끼죽 Lv12 체력 35·정신 10·영맥 약선탕 Lv24 체력 50·정신 10(두 그릇씩). 먹으면 회복 + 이로운 상태(든든함·속이 따뜻함·기운 충천·바다의 복).

### 별채

- 생성기 supabase/gen72/(h_housing.sql·p_pets.sql·pets_data.py·x_misc.sql·patch_note.sql·gen.py → migrations/20261103000000_world_7_2_0.sql). 그림 assets/js/housing/(render.js·furniture.js 가구·벽지·바닥재·기본 세트·pets.js·petsprite.js), 화면 views/housing.js(#/house·#/house/<주인>, 캐릭터 › 별채 탭은 이리로).
- 표(RLS·직접 읽기 없음): world_housing(size 6~9·items [{k,x,y,r}]·wall [{k,side L|R,t,z}]·paper·ground·gate open|friends|closed·발걸음·pet_id·pet_out)·world_housing_store(곳간)·world_housing_guestbook(최근 20)·world_housing_visits(하루 한 번)·world_housing_rewards(한 번 주는 가구)·world_furniture_sources(drop_normal·drop_guardian·expedition·raid_world 확률 / title:·chapter:·raid_final·gw_first 한 번).
- 가구 = 물품(category furniture, 단계=등급 1~5, 묶음 1, hf_<키>·벽지 hp_·바닥재 hg_, equipment_traits {hk, kind floor|rug|surface|wall|paper|ground, w, d, top, ww, wh, cat, pet bed|toy|bowl|perch}). 상점(범품, 상점마다 다섯)·제작·전리품 가구는 거래 가능, 조건 보상·기본 세트·비고 가구는 거래 불가(world_shop_sell도 막음, 기부는 됨). world_item_catalog_category_check에 furniture·pet.
- world_housing_save(p_owner, p_state)가 배치 전체 재검사: 칸 안·겹침(바닥·깔개 따로)·소품은 top 있는 가구 위·벽 장식은 벽 안(t 0.1칸, z 4~75px)·같은 벽 겹침·설치 상한(6×6 15·7×7 20·8×8 26·9×9 32)·같은 가구 상한(범품 4·양품 3·진품 2·명품·신품 1). 늘어난 가구는 곳간 → 고치는 사람 가방, 줄어든 가구는 주인 곳간(30 + 넓힐 때마다 5).
- 고치기·곳간 put·take(world_housing_store_move)·넓히기(world_housing_expand: 7×7 2,500전·가공 부적목 10 / 8×8 Lv20·6,000전·강화 부적목 4·칠액 6 / 9×9 Lv25·15,000전·강화 부적목 6·영맥 수피 4·비취 파편 2)는 world_housing_edit_block(창고와 같은 조건, 반요촌 불가)이 막고, 곳간 discard는 어디서나. 구경 world_housing_snapshot은 어디서나, 대문·차단 world_housing_can_view. 조사원 카드 「별채 구경」은 먼저 snapshot을 불러 막히면 알림만, 받은 값은 store.houseSnap으로. 혼례 정인(world_housing_married: bonds.marks.married)은 서로의 별채를 고친다.
- 한 지붕: 혼례 정인이 한 별채를 골라 제안(world_housing_merge_ask 'mine'|'theirs', world_housing_merge_asks 24시간), 받으면(world_housing_merge_answer) world_housing_shared(home_id·mate_id·contrib). world_housing_home(uid)이 사는 집을 돌려주고 보기·저장·곳간·넓히기·대문·방명록 지우기·보상 가구(world_housing_grant)가 집을 씀(정인 별채 주소로 와도 집, 들어온 정인도 role owner). 넓이 그대로, 설치·곳간 상한 두 사람 몫(world_housing_cap_of·store_cap_of), 같은 가구 상한 ×2(world_housing_kind_mul). 들어온 정인 별채는 두고 곳간 가구만 옮기며 들여온 수를 contrib에 적고 꺼내거나 버리면 뺌. 갈라서기(world_housing_split, 연리 끝·혼례 표시 사라짐 trg_world_housing_bond)는 world_housing_unshare가 contrib만큼 곳간 → 놓인 것(뒤에 놓인 것부터) 순으로 돌려줌. 동무는 집주인 것만(world_pet_place). 화면 housing.js mergePanel·알림 housing_merge.
- 개방: 보조 퀘스트 hs_byeolchae 「객사 별채」(본부 객사, Lv15, after mq_frost_seal, 인물 q:hs_bomi 「순덕」, 마지막 장면 need.gil 1,000) → trg_world_housing_quest가 world_housing_open으로 6×6과 기본 세트 「단청 별채」(world_housing_default_set). 기본 세트 여섯은 capital_market에서 늘 판다(재료값×1.5, 귀속).
- 가구 보상: trg_world_housing_event(world_events combat·expedition_end·story·gw_win, 캐릭터 행은 안 고치고 곳간·알림만: 일반 0.4%·정예 1.2%·우두머리 3%·원정 완주 4%, 별채 있는 사람만, 곳간이 차면 가방(그때만 캐릭터 행) → 가방도 차면 버리고 알림, 한 번 주는 보상은 곳간을 넘어도)·trg_world_housing_title(칭호)·trg_world_housing_raid(봉연의 그림자 기여 1%↑ 6%+20%×몫, 10장 결전 첫 승리). 방명록 80자·한 별채 하루 3개. 알림 갈래 housing(housing_visit·housing_guest·housing_item·pet_play).

### 꼬마 동무

- 44종(1.0.0, 조사원 제보 9종 포함, 원본 supabase/rollback/p6_pets.src.sql) world_pet_species(grade·kind·likes·how·egg), world_pets(affinity 0~300, 100 다 자람, 하루 쓰다듬기 5·놀기 3·먹이 3), 손님 world_pet_guest(하루 쓰다듬기·놀기 한 번씩 +1), 출처 world_pet_sources(quest:·title:·gw_first).
- 범품 8: 바구니 pt_<종>(상점마다 둘, 300전, 거래 가능) · 양품 8: pet_egg_2 「얼룩무늬 알」 · 진품 7: 퀘스트 + pet_egg_3 「빛나는 알」 · 명품 5: 어려운 퀘스트·칭호 공방의 주인 · 신품 2: 칭호 만귀보·귀허의 주인 첫 처치. 알은 탐색·채집·낚시(잡았을 때)마다 world_event_char_apply 희귀 전리품 길로 0.5%·0.06%.
- world_pet_adopt: 알은 그 등급 egg 종 중 고르게, 이미 있으면 친밀도 +30(최대 300), 친밀도 가득이면 「동무 정표」 pet_token(거래 불가, 가방이 차면 창고). 정표 5 → 빛나는 알 world_pet_token_trade(어디서나, 가방 「알로 바꾸기」·물품 정보·별채 동무 창). 조건 보상 world_pet_grant(이미 있으면 pet_food 3을 창고로).
- 두 자리(1.0.0): 데리고 다니는 동무 world_pet_profile(조사원 카드 pet = world_pet_profile_of, 별채 없어도 world_pet_profile_set)·별채 동무 world_housing.pet_id(world_pet_place), 같은 동무는 한 자리에만(서로 빼고 계정마다 advisory 잠금, pet_out은 안 씀, world_pet_walk는 옛 화면 호환), 별명 8자 world_pet_nickname, world_pet_act(pat·play·feed, pet_food 10전·별미 treat_* 30~50전, 좋아하는 별미 +12). 능력치 효과 없음.
- 규칙 'home'(world_home_rule_count: open·size·visits·guest·furn·pets·adult·pet_grade·eggdup — 알에서 잇달아 겹친 최장 횟수 world_pet_streak), 칭호 14 분류 '별채'(pet_dup3 「또 너니?」·숨김 pet_dup5 「끊어지지 않는 인연」, 효과 없음), 꾸미기 fr_home·pt_home·sl_dong.
- 그림 원본 tools/pet_art/(art*.py → gen.py가 테두리를 둘러 pets.js 생성).

## 8. 생존과 침식

체력·정신 등 생존 상태와 침식은 화면에서 보이고 실제 행동·전투에 영향을 준다. 낮아지면 페널티, 회복과 페널티는 서버에서 일관되게. 침식은 장식이 아니라 관리할 위험이다.

### 휴식과 회복

- 잠깐 쉬기 10분·푹 쉬기 30분 쿨타임(본부 무료 휴식 포함) 서버 강제. 바깥 야영은 숙소 회복의 ⅔(home.js 예상치도). 단추에 예상량, 쉰 뒤 실제 오른 값(world_field_rest의 recovered).
- 안전지대 체류 pg_cron yh-safe-regen(10분, world_safe_regen) 체력 +12·정신 +6(전투불능·이동·원정 제외).
- 마음 다잡기(본부 정청·객사·연무장, 정신 +18·침식 −10) 15분 쿨타임, 정신 가득·침식 0이면 불가.
- 부적 정화(world_survival_action cleanse): 정화 부적 1(보통 먼저, 없으면 우수품 침식 −21·정신 +7)로 침식 −18·정신 +6, cure_items에 ward_talisman인 상태이상(중독·심신 동요·사념 침식)도 푼다. 둘 다 없으면 불가.
- 물품 기운(등잔빛·비약·음식 등 world_use_item의 이로운 상태)은 남아 있을 때 다시 쓰면 남은 시간에 더하고 두 번 몫까지(item.js 「다시 쓰면」).
- 감소 상한: world_status_effect_total 받는 피해 −60%·침식 −75%·정신 손실 −75%·이동 −50%, world_combat_stats 받는 피해(칭호 포함)·world_travel_route(칭호 포함)도 같음. 행동마다 잃는 정신(world_event_char_apply)에도 정신 손실 감소를 곱함(최소 ×0.25, 「맑은 정신」 등 음수 상태는 침식 위험 +1을 상쇄).
- 남의 능력치를 잴 때(world_raid_stats: 귀허·합동 토벌) JWT를 그 사람으로 바꿔 world_combat_stats를 부르고 되돌린다.
- 효과 키(gen71/h_effects.sql) training_xp_pct(기술 경험에 곱함, 최소 ×0.5)·agility_pct(민첩에 곱함)는 world_status_self(uid, 키)로 상태 칸만 더한다. 새 효과 키를 만들면 쓰는 곳도 반드시 함께.
- 상태판 상태이상은 작은 둥근 칩(.vitals .st-chip, 11px·높이 18px, 앞에 빨강/초록 점).

### 날씨와 시간대

- 시간대 한국 시각 6시간마다(해돋이 6~12·한낮 12~18·땅거미 18~24·삼경 0~6), 날씨 12시간마다(0·12시) 영역별(청명·담운·장우·세우·농무·삭풍·설한·혈무). 효과는 world_status_effect_total로 채집·제작·이동·회복·전투·조우·침식에. 모든 world_events에 시간대·날씨가 남음. world_env_total은 날씨·시간대 키를 한 번만(with … as materialized).
- 세우(細雨, drizzle): 채집 +6%·회복 +5%·침식 −5%·단서 +4%·원거리 −5%·낚시 입질 +5%p(world_fish), 땅 밑·심연 영역엔 없음(world_weather_climate). 날씨 이름은 두 글자 한자어. 새 날씨마다 core.js ENV·journal.js WEATHER·world_expedition_walk_lines를 함께 고친다.
- 장야(롤백 전 연출, 끝남): world_long_night_stage는 11/2부터 늘 0이라 효과 없음(시간대·날씨 함수가 부르므로 남김). 알림 예약·붉은 안개 화면·롤백 문 닫기·마지막 토벌 함수는 롤백 때 지움(2026-11-02).

### 침식

방침: 보통 속도 · 모든 직업에 불이익 · 고위험 보상.

- 오르는 곳: 탐색(world_field_search) 위험도 1~2 반쯤 +1·3~4 +1·5↑ +2, 삼경 +0.5, 어두운 곳(사당·폐단·묘역·지하·심연·균열·고도·수궁·흉가 정원·혈림) +0.5, 침식 보정(world_status_effect_total('erosion_pct'))을 곱하고 소수는 확률로 올림. 토벌(world_event_char_apply): 위험도 3↑ 승리 +1·패배(battle_lost) +3, 영체·독성·반사·매복·정예·우두머리 +2(world_erosion_pct_self). 원정은 위험도·깊이별 회차마다.
- 단계 효과(world_erosion_effect): 주의 30 회복 −15%·희귀품·단서 +5% / 위험 55 회복 −25%·받는 피해 +10%·행동마다 정신 −1·희귀품·단서 +10% / 붕괴 직전 80 회복 −35%·받는 피해 +20%·주는 피해 −10%·조우 +20%·희귀품·단서 +15%. 공격력 −10/−20/−30%(world_combat_stats mind, 무기 갈래 무관; 정신 40↓ ×0.85·20↓ ×0.7도 같은 곳). 100이면 정신 0(trg_world_erosion_overflow). 캐릭터 › 상태에 지금 단계 효과.
- 수치를 바꾸면 위 함수들과 character.js erosionNote·guide.js를 함께.

### 요화(妖化)

- 걸림: 침식 80·90·100에 처음 닿을 때 0.1%·1%·5%(trg_world_yohwa_onset). 넘친 침식(사용자 결정): 100에서 더 오르려던 1점마다 0.25%(1−0.9975^몫, world_yohwa_overflow — world_field_search·world_event_char_apply·world_expedition_settle(er>100)·world_gw_settle의 기존 계산 자리에서, 걸렸을 때만 상태·알림·world_yohwa_mark). 처음 100에 닿고 안 걸리면 world_yohwa_onset이 「침식이 가득 찼습니다」 알림(kind yohwa, payload warn). 새로 침식을 올리는 곳도 넘친 몫을 이 함수로.
- 진행 world_character_statuses 'yohwa'(세기 = 단계): 1 요기 스밈 3일 → 2 요문 발현 2일 → 3 반요 1일 → 요괴화 1시간('yohwa_frenzy': 주는 피해 +30·받는 피해 −30·회복 +30·정신 손실 −50·민첩 +15; 3단계와 합친 표기 주는 피해 +42·받는 피해 −12·정신 손실 −20·민첩 +15·침식 +24로 화면·알림에 적음; world_yohwa_tick이 metadata.frenzy_at으로 가름; 상태 칸에 안 셈 world_status_roll·hud.js PINNED; 요화 줄이 지워지면 trg_world_yohwa_frenzy_clear) → 전투불능(원정 중이면 1시간 미룸, 풀 때까지 하루마다 다시). pg_cron yh-yohwa(5분, world_yohwa_tick).
- 남에게 보임: 1·2단계 본인만, 3단계 조사원 카드 「지금」 칸 칩, 요괴화는 조사원 카드·채팅 이름 옆(전체·지역·세력·귓속말·모임 — world_chat_stamp_title·world_circle_send가 sender_mark 'frenzy', 파티 채팅은 아직 없음) 붉은 「요괴화」(.yohwa-mark). 판정 world_yohwa_public(uid) = 'frenzy'·'3'·null(world_character_card.yohwa).
- 요화로 쓰러진 사람은 구조·본부 구조대·회생 부적으로 못 일으킨다(trg_world_yohwa_down_guard: downed_at이 풀리는 순간, 요화 줄 down_epoch가 그 쓰러짐과 같으면 거절 — 본인이 world_yohwa_seal을 골라야 함, 사용자 결정). 요화 쓰러짐(metadata.down_epoch = downed_at)은 world_death_sweep이 사망 처리하지 않음(요화 사망 OFF).
- 봉인 world_yohwa_seal: 가까운 안전지대로 옮겨 24시간 'yohwa_seal' 뒤 요화가 풀리고 침식 40 아래. 봉인 중엔 채팅만 — 행동 기록을 남기는 것은 world_guard_action_context, 안 남기는 것(현장 이동·조사 지점·자율 시작/수령·보따리·파티 전리품·직접 거래 제안·동승 요청·연리 선물/신청)은 함수 첫머리 world_seal_guard(), 비무도 막음. 채팅·귓속말·친구·파티 맺기·프로필·칭호·꾸미기는 됨. 새 행동 함수는 행동 기록을 남기거나 world_seal_guard()를 부른다.
- 요화·봉인은 상태 칸 10칸에 안 세고(world_status_roll) 상태판·띠에 따로 늘 보임(hud.js yohwaOf).
- 요화 줄 지우기 금지: 만료 정리 함수(world_status_snapshot·world_apply_activity_status·world_hud_snapshot·world_field_status)는 모두 status_key <> 'yohwa'. 새 만료 정리도 같게.
- 귀령초(gwiryeong_cho, 명품·거래 가능) world_use_item → 풀림·침식 −20. 얻는 곳(world_gwiryeong_chance·world_gwiryeong_give): 위험도 7↑ 채집 0.02%·토벌 일반 0.02%·정예 0.08%·우두머리 0.3%·구중 봉연 우두머리 1%·원정 완주 0.15%, 위험도 10은 ×1.5, 합동 토벌·결전 승리(trg_world_gwiryeong_raid, 싸운 사람마다)·귀허의 주인 처치 1%, 탐사 36단계 「영초 감별」(tracking_x36) 0.2%. 얻으면 72시간 다시 안 나옴(world_gwiryeong_log), 서버 7일 몫 = 지난 7일 요화 걸린 수의 절반(최소 1). 모든 길(새 길 포함)은 world_gwiryeong_reserve를 거친다. 전리품 표·조사 지점 world_region_sites.rare_bonus에는 넣지 않는다(trg_world_gwiryeong_roll, 맞을 때만 캐릭터 행·알림). 사망 위험이 없는 동안 다른 희귀품보다 낮게, 공급량은 그대로(사용자 결정: 봉인으로 풀어 남으면 그때 조정).
- 구중 봉연 전리품: 구중 봉주 응축 영핵 3·천령 감로·성진사 2, 사슬 끊는 자 응축 영핵·월광 정수·결계 파편, 심연 사슬귀 응축 영핵·결계 파편·귀령 재, 토벌 22% 희귀 전리품도 응축 영핵.

## 9. 자율 활동과 현실 시간

자율수련·조사·정비·휴식을 현실 시간으로 진행한다. 시작·종료·수령은 서버가 관리하고 클라이언트 시간 조작을 막는다. 보조 시스템이며 직접 플레이의 가치를 없애지 않는다. 유형별 보상과 상태 변화는 서로 구분된다.

- 자율 중에는 현장 행동(이동·탐색·전투·채집·낚시·휴식·제작·분해·강화·수리·상점·거래소·직접 거래·원정·구조·의뢰)을 world_guard_action_context·world_events 트리거가 막고, 성장·세력 임무·보급·단서 조합·이야기·전리품 분배·물품 사용·장비 바꾸기는 된다.
- 끝나기 전 그만두기(캐릭터 › 자율, world_claim_idle_activity를 일찍 부르면 중단) = 지난 시간만큼, 최소 1 보정 없음.
- 보상 world_claim_idle_activity(시간 h): 숙련·회복 floor(4.2h), 경험치 floor(h×비율×0.35)(수련 12·조사 10·정비 8·휴식 3, 최소 1, 최고 레벨이면 0). 수련 = 전투 숙련·든 무기 기술(근접·원거리·술법은 봉인술), 조사 = 조사 숙련·탐사, 정비 = 제작 숙련·world_craft_line_of(생활 전문화 제작 분야), 휴식 = 체력·정신·영력(world_idle_skill_for).
- 화면(캐릭터 › 자율)은 시간 단추마다 같은 식의 예상 보상, 누르면 확인 창. training·research·maintenance·rest 각 분기와 수령을 검증한다.

이동 중 막는 행동:
- 이동 중(travel_arrives_at 남음) 제작·분해·강화·수리·상점·거래소는 world_guard_action_context, 물품 사용은 world_use_item(쓰러졌을 때 회생 부적 예외), 퀘스트 받기·보고(world_quest_report)·세력 퀘스트 보고(world_faction_report)도 막음.
- 「그 자리」 행동 37가지(창고·곳간 정리·퀘스트 포기·의뢰/세력 의뢰 보고·기부·비고·수련장·보급·소속 임무·가입·떠나기·마구간·서신 물품(world_letter_place_check·claim)·시신·구조·수리·강화·분해·상점·거래소·직접 거래·비무회·혼례·토벌 합류·결전·동료 부르기·사건 보고·가설 확정·마음 다잡기)는 본문 첫머리 world_travel_guard(무엇)가 막는다. 새 「그 자리」 함수도 world_travel_guard를 부르고 주인 역할에 실행 권한을 준다.

## 10. 사건 조사와 단서 조합

사건은 텍스트 서술·분기·조사 결과·단서 수집과 조합으로 진행한다. 지역·사건마다 다른 단서를 찾고 조합해 원인·해결을 추론한다. 진행과 단서는 서버에 저장하고 중복 보상·임의 변경을 막는다. 전투력만으로 해결하지 않는 성장 동기를 준다. 선택지 하나를 고르는 분기형 사건 화면은 쓰지 않는다.

주 이야기 10장: 1 붉은 인장의 실종 Lv1 · 2 물 밑의 장부 Lv5 · 3 적월의 서약 Lv8 · 4 북령의 얼음 인장 Lv12 · 5 이름 없는 종 Lv15 · 6 월식의 문 Lv18(적월·뇌명봉) · 7 물 밑의 등불 Lv21(수향) · 8 재의 바다 Lv24(남명) · 9 등잔 밑 Lv27(직할령) · 10 구중 봉연 Lv30. 가방 칸 보상은 1~5장에만, 6장부터 능력치 포인트(rewards.stat)·고유 탈것(rewards.mount, 연화 거북)·고유 장비(구등대 등불 노리개, 거래 불가)·낙관(sl_deung)·강화 재료. 보상이 가방에 안 들어가면 world_story_combine이 마지막 가설 확정을 막는다.

### 퀘스트

- 표 world_quests(kind main·side, cat 분류 접두, region_id·min_level·after·chapter_id·epilogue·job_key·faction_key)·world_quest_steps(need {tasks, at, give, gil}·lines·reward {xp, gil, items})·world_quest_npcs·world_quest_progress(step·step_started_at·done_at). 원본·검사기 작업 공간 quest/gen/build.py(JSON → quest_data.sql), 생성기 supabase/gen611/(data_quests.py·data_lore.py·funcs.sql·gen.py).
- 진행: 첫 장면 보고가 받기. 할 일(win m·r·rank / gather items·r / craft items·field / fish r / 그 밖은 world_faction_task_count)은 지난 보고 뒤 world_events를 센다(world_quest_task_count). win은 원정 일지 승리 줄도 world_exp_win_count로 더함(settle이 mid·rank·rg를 남김, 세력 할 일도). 물품 지정 채집은 얻은 개수(qty + 덤 extra), 물품 지정 제작은 만든 개수(craft payload qty). travel은 지금 거기 있으면 마침.
- 문구 world_quest_task_label: 물품 지정 채집 「…에서 ○○ 모으기」, 아니면 「…에서 채집하기」, 지역·물품 지정 채집은 채집터 종류·최저 출입 레벨(「(목재 채집터 Lv8~)」). 화면 quests.js taskLine·factionquest.js taskRows unitOf가 「0/3개」「0/3회」.
- 지금 장면의 처치 대상(win m)은 탐색·야영 조우 무게 ×3(world_battle_open, 우두머리 판정 그대로), 채집 할 일 물품(지역 일치 또는 지역 조건 없음)은 나오는 채집터에서 무게 ×3(world_field_gather v_qw).
- world_quest_report: 장소·할 일·넘길 물품(잠금·장착 마지막 하나 거절)·need.gil·가방 자리를 확인하고 보상·대사를 한 번에. 직업·소속 전용(job_key·faction_key, jq_<직업>·aq_<소속> Lv3·4, cat 「직업·…」「소속·…」)은 board·journal·report가 거름. 대사 줄 job·affil 키는 그 직업·소속에게만(world_quest_lines_for).
- world_quest_board: 진행 중·받을 수 있는 것·세력 퀘스트를 한 번에(마친 퀘스트는 한 번만 dn, 받을 수 있는 것은 world_quest_step_state 안 부름). 현장 칸 quests.js(yh-fold-quests): 지역 없는 채집·넘길 물품에 fillSrc가 world_item_sources로 5곳까지 바로 가기(물품마다 접속 동안 한 번), 지금 지역(here_id)이 걸린 퀘스트를 위로(isHere, 세력도), 세력 퀘스트는 맨 위 접는 칸(facBox, yh-q-open '!fac'), 잠긴 등급 퀘스트(world_faction_current.locked)는 열리는 조건만·진행 수·지역 안내에서 제외. 900px↑ 카드 240px 이상·한 줄 세 칸(.q-board).
- 주 이야기: mq_<장> 장면을 다 보고해야 그 장 단서가 탐색에 나온다(world_quest_main_open). 장 마침은 world_story_combine(결말 epilogue 반환).
- 「단서 찾기」: 보조·세력 clue 할 일이 걸려 있고(world_pending_clue_task: step+1·세력 가입/등급 장면, r 조건) 아직 못 채웠을 때만(task_count < n) world_field_search가 같은 확률로 「맡은 일의 실마리」(outcome clue, payload side_clue). 이야기 단서가 먼저.
- 보상 기준: 보조 퀘스트 경험치 합 0.4×xp_need(L)을 할 일·넘김 있는 장면에 나누고 마지막 장면 전 5+4L, 주 이야기 장면 0.15×xp_need(L)·전 5+2L.
- 포기 world_quest_abandon(p_quest): side만, 진행 행을 지우고 world_quest_abandons.paid_step까지는 보상을 비움(넘길 물품은 다시). 일지 진행 중 카드 「포기하기」(확인 창).
- 일지 views/journal.js: 칸 주 이야기·보조 퀘스트·의뢰·기록(답사·원정·요괴·채집·어종, 옛 주소 #/log/survey·history·codex·fish도 기록으로). 장 목록 단추 → 그 장 펼침, 장면 순서(world_quest_journal: done·active·available·locked·장면·할 일, 앞 퀘스트를 못 마친 보조는 수만 hidden) → 단서 → 가설. 마친 장면·결말은 world_quest_scene(p_quest, p_step, 0 = 결말), 안 마친 장면은 서버가 안 줌. 보조는 분야(cat 「·」 앞)별 접는 칸·상태 거르기·레벨/지역/이름 정렬, 바꿀 때 다시 안 읽음. journal은 15초 캐시, 할 일이 진행될 수 있는 행동 뒤에만 버림(common.js QUEST_CHANGERS). 단서 지역으로 바로 이동할 수 있어야 한다.
- 세계관 표(함수로만): world_item_lore·world_kind_witness(갈래 목격담, 토벌 1·10마리, 못 연 줄은 글을 안 줌)·world_region_lore+world_region_visits(첫 방문 글, world_region_intro 한 번·world_region_lore_seen)·world_title_lore(world_title_story는 얻은 칭호만)·world_affil_letters(소속 보급 편지, world_claim_faction_supply가 letter로, min_chapters)·world_lore_bundle. 화면 lore.js(loreBundle·refreshLore·regionIntro(다른 창이 있으면 미룸)·showLetter·rebirthScene).

### 대본 규칙

- 생성기 supabase/gen744(data/*.json·gen.py → migrations/20261103234000_world_7_4_4_quest_lines.sql). 다음 장면 할 일(어디서·무엇을·왜)은 앞 장면 끝에서 인물이 게임 속 이름으로 맡기고(별칭은 「별모래 = 성진사」처럼), 일을 마친 장면은 방금 한 일로 시작. 장면 대사는 그 장면 할 일을 마치고 보고할 때(장면 1은 받을 때), 세력 장면도 보고할 때. 새 대본도 지킨다.
- 주인공 대사(사용자 결정): 조사원은 말하는 이로 나오지 않는다. 말하는 이 없는 서술 줄로 「나는 ~라고 했다 / ~를 물었다」(원본 supabase/gen740/me_lines.py). 새 대본에 'me'를 쓰지 않는다.
- 옛 생성기(gen611·gen70·gen71·quest/gen)를 다시 돌리면 'me' 줄이 되살아나므로 그 뒤 gen740, 이어서 gen744도 다시 돌린다.
- 「이름(名)」 설정(사용자 결정, supabase/gen744/LORE_NAME.md): 이름은 넋을 묶는 명줄(스스로 아는·불리는·적힌 세 가닥). 죽음은 이름이 잊히는 것(이름이 남으면 영), 요화는 이름을 잃어 가는 것(다 잃으면 요괴가 되어 갈래로 불림), 정청은 해마다 「명부 정리(먹 거두기)」로 오래된 이름을 거둔다(9장에서 처음 드러남). 흑련회는 이름을 맡아 장부에 따로 지키고 회원은 호칭으로 불린다. 「무명」은 이름이 사라진 사람을 이르는 말(회주의 호칭이기도). 대사·도움말·새 퀘스트는 이를 따른다. lore.js WORLD_PRIMER에는 명줄 세 가닥·영·요화와 갈래만(명부 정리는 9장 전이라 뺌).
- 회산 관문·주혈 광산 보조 퀘스트 채집은 월철 광석·생 월철.

### 합동 토벌·결전·협동 기술

- 엔진 world_raids(kind final·world, status announced·signup·fight·won·failed, 체력 하나를 함께 깎음)·world_raid_members·world_raid_log·world_raid_locks. world_raid_action(attack·guard·item(world_use_item)·coop, 1초 간격). 싸우는 동안(물러남 아님·자리에 있음) world_use_item은 yh.raid_item(item 행동이 켬) 없으면 거절. 행동할 때도 이동·자율·원정·요괴 전투를 막고, 회복·소생은 실제 오른 체력만, 협동 기술 기본 기여 공격력 ×0.6.
- 결전(final)은 차례 기준: 광역 7턴 ×0.8·사슬 2단계부터 5턴·기운 모으기 3단계 11턴(최대 체력 4% 몰아치면 끊김, 터지면 ×2.2). 서버 보스(kind world)는 2초 박자(world_raids.fx.beat·beat_at, 행동할 때 2초가 지났으면 한 박자, 한 번에 하나): 광역 14초·사슬 10초·기운 모으기 22초·터짐 8초(4박자), 인원 무관. 반격 확률 least(0.4, 0.8/n). 서버 보스 기운 모으기는 실제 8초(fx.charge.until = 시작+8, 그 뒤 첫 행동에서 터짐, [흐름 끊기] +6초, 스냅샷 charge.secs·dur → raid.js chargeTick·.ch-time 0.1초마다, 3초 아래 붉게), 끊는 피해 = 지난 2분 안에 행동한·물러나지 않은 참가자 공격력 합 ×3(최소 500, world_raid_charge_need, 사용자 결정). 단계 70%·40%.
- 쓰러짐: 체력 1로 60초(결전 30초) 물러남. 지나도 저절로 안 돌아감 — 표적·광역·함께 거는 효과·「모두 물러남」·world_raid_hit 대신 막기는 out_until이 빈(직접 행동해 돌아온) 사람만, 행동하면 out_until을 비움. 쉬는 동안 world_use_item·소생 기술 받기 가능. [야전 소생](med_revive)은 out_until을 now()로 당겨 「쉬는 중」으로만. 스냅샷 me.resting·members[].resting.
- 자리 비움 world_raid_here(uid, 지역)(그 지역·이동/원정/전투불능 아님)가 거짓이면 물러난 것으로 봄(조건 (x.out_until …) and world_raid_here, 스냅샷 members[].away·me.away). 기록·기여는 그대로라 돌아오면 바로 싸움. 돌아오면 현장 띠가 「토벌로 돌아가기」를 한 번 묻는다(raid.js backPrompt, sessionStorage yh-raid-back:<id>).
- 보스 한 대 = (4+0.7×(지역Lv+3))×단계 배율(1·1.15·1.3, 결전 ×1.1). world_raids는 실시간 목록, authenticated 읽기는 announced 아닌 회차만(출현지·후보는 world_raid_brief가 때맞춰).
- 10장 결전(fq_sealed_lord, mq_nine_gates 뒤 Lv30, 구중 봉연): world_raid_final_start, 혼자 또는 같은 곳 파티원 4명까지(raid_invite, 90초 뒤 또는 world_raid_begin). 체력 max(4716, 평균 공격×100)×{1.6,2.5,2.9,3.3}(world_raid_begin_fight, 혼자 보정 뒤 혼자 약 3~4/10·둘 어렵지만 해볼 만하게), 20분, 모두 물러나 있으면 보스 +3%. 체력 회복품은 한 싸움 다섯 개(world_raid_members.items_used, 결전 중엔 world_use_item 직접 거절 — 결전 화면 「물품」만), 회복 기술 절반, 쉬다 돌아오면 체력 30. 받는 피해(world_raid_boss_base) = 도전자 평균 레벨 (4+0.7×(평균Lv+3)) × 전투력 배율(평균 공격÷(7.5×평균Lv), 0.75~1.5)로 모두 같게(서버 보스는 그대로). 할 일 {t:'raid', kind:'final'}. 첫 승리 400전·필요 경험치 0.5배, 다시는 100전·조각 2, 아무도 없으면 실패. 포기(world_raid_forfeit·world_raid_forfeit_vote·world_raid_votes): 혼자면 바로 실패(world_raid_settle false), 함께면 제안 60초(raid_vote, 갈래 raid) — 모두 동의하면 함께 실패, 한 명이라도 반대·시간 초과면 계속. world_raid_snapshot(본체 world_raid_snapshot_core)이 vote를 덧붙이고 화면 raid.js askVote가 제안마다 한 번. 결전 머리 「포기하고 나오기」, 열기 전 확인 창(quests.js askFinal, 혼자면 core.js ask({alarm}) 빨간 경고).
- 서버 보스 「봉연의 그림자」: world_raid_schedule_next(72시간 뒤 기준, 그날 또는 다음 날 한국 시각 16:00~21:30, world_raid_evening — 모임 30분 + 토벌 2시간이 자정 전에 끝남), pg_cron yh-raid(5분, world_raid_tick): 24h(후보 셋)·12h(확정)·6h·3h 알림(전체 채팅 sender_name '봉연 소식', 보낸 이 world_staff 첫 사람)·30분 신청·2시간 토벌. 토벌 중 합류 world_raid_join(공격력×110×남은 시간 비율(최소 ¼)만큼 체력·최대 체력 증가, 기여는 합류 뒤부터). 아무도 없어도 시작. 모든 레벨, 보스는 지역Lv+3, 기여 ×L/30. 체력 max(2500, Σ공격×110). 보상(기여 1%↑): 전 min(1800, 300+1700·몫)·경험치 need×min(0.35, 0.10+0.6·몫)·봉연 조각·확률 물품·토벌 장비(raid_norigae·raid_amulet·raid_mask, 5단계·거래 불가·Lv25) 4%+8%·몫, 실패는 위로 보상. 출현지 확정 뒤(12시간 전·모임·토벌) 지도에 보라 마름모 테 + 네 갈래 별(map.js shadow-mark, raid.js raidShadow, 범례 「봉연의 그림자」) — 다른 표시는 원 고리라 새 표시도 원을 피한다. 현장 띠 world_raid_brief(fillRaidBand, 1분 캐시), 지도 「봉연에 잠김」도 같은 값.
- 잠김(world_raid_lock_effect, 다음 회차까지): 출현 지역 침식 +30·조우 +10·채집 −25·받는 피해 +10, 이웃(world_region_neighbors: travel_from 양방향) 침식 +30·조우 +10, 이웃의 이웃 침식 +10·조우 +5.
- 기여도(합동 토벌·결전·귀허·파티 토벌 공통) world_contrib_score(갈래 원값, 공격력, K) = 준 피해 + 0.75×늘려 준 동료 피해 + 0.4×공격력×협동 기술 횟수 + K×(막아 준 피해 + 동료 회복 + ½자기 회복 + ½받아 낸 피해). K = 1.5×평균 공격력÷요괴 한 대(world_raid_k: world_raid_boss_base · world_gw_k: (35+4×단계)×인원 배율 · 파티 토벌 4+0.7×(요괴Lv+3)). 계수는 6직업 넷·둘 모든 조합 정석 모형(넷 24~26%·둘 46~54%) 기준. 행동마다 원값만 credits(dmg·boost·guard·heal·heal_self·taken·skill)에 쌓고(world_raid_credit·world_gw_credit·world_gw_credit_hit, 효과 json의 건 사람 by·shield_by·critnext/crit_next uid·gward uid·block_by·break_by·stagger_by), 점수는 스냅샷이 계산(world_raid_score·world_gw_shares·world_pfight_shares), 합동 토벌 정산 첫머리 world_raid_recontrib가 contrib에 적음(서버 보스 L/30). 막아 준 피해에 드는 것: 퇴마 결계(꺾은 광역)·호법 신장(끌어와 맞은 전부 + 줄인 몫)·휘청임/묶은 손길(놓친 반격 기대 피해)·영력 보급(채운 영력×공격력×0.05를 북돋움으로). 화면 raid.js creditLine, 기록판 「기여」.
- 협동 기술 world_coop_skills 24개(직업마다 4, 전투 숙련 3·8·18·36): 합동 토벌·귀허에서 그 턴 행동으로(영력·다시 쓰기). 호위 무사 패턴 공유·급소 지시·흐름 끊기·파진 돌격(제 공격 세 번 +30%, target self), 백공 현장 수선·영력 보급·방호 법구·공명 법진. 파티 원정 합동 전투는 world_coop_exp_procs가 기술마다 10%, 한 싸움 두 번까지(win_p 뒤).
- 받는 피해 공용 world_cb_mitigate(원값, 능력치, 효과, 나, 광역, 터뜨림, 태세, 피하기): 능력치 → 방어·버티기 → 진언(봉연 {by,pct}·귀허 건 사람 id 50%) → 결계 → 호법 → 보호막 순, 효과를 닳게 하고 막아 준 credits를 돌려주면 world_raid_hit·world_gw_hit가 기여·체력·기록에 적음(대신 막기는 world_raid_hit). 새 보스 전투도 이 함수를 쓴다. 엔진마다 따로: 물품(봉연 world_use_item, 귀허 world_gw_resolve 안), 쓰러짐/쉬는 중(봉연 초·out_until, 귀허 라운드·out_rounds·rest), 협동 기술 효과 걸기.
- 파티 전투 공용 함수(7.7.7n — 새 전투도 이것을 쓴다): 물품 효과 world_item_fx(원본 world_item_catalog.use_fx, 기본 물품 → hp·mn·sp·er·stam·cures·buffs, world_use_item·world_party_use_item·귀허·원정 보급), 공격 굴림 world_cb_attack(능력치, fx, bfx, 하한, 폭 → d·crit·fx·bfx·src: 기세·사슬·약점 드러내기·약점·급소 crit_next), 늘려 준 몫 world_cb_boost_credits(→ [[사람, 몫, boost]…, [나, 남은 몫, dmg]]), 기운 걸기 world_cb_buff(종류, 효과, 건 사람 → fx 조각), 표적 order by world_cb_pick_key(이목) limit 1(무게 world_cb_aggro = max(5,이목)^1.3).
- 칭호 13(분류 '토벌', 규칙 'raid' → world_raid_rule_count, world_title_award_check는 이벤트 'raid'일 때만).
- 피해 기록판 views/meter.js mountMeter(합동·파티 토벌·귀허): 파티원마다 준 피해·받은 피해·회복의 수치·몫·게이지, 갈래 단추 정렬. 받은 피해 world_raid_members.taken(world_raid_hit)·world_gw_members.taken(world_gw_hurt), 파티 토벌 world_pfight_members.dmg·taken·heal(world_pfight_resolve가 차례 앞뒤 체력 차, yh.pf_hb). 스냅샷 members로 — 따로 안 묻는다. 휴대폰(899px↓) 오른쪽 손잡이 반투명 창(yh-meter-open·yh-meter-tab), PC 참가자 칸 아래.

#### 파티 전투 화면(봉연 토벌 화면이 기준)

- 공용 부품 views/fightui.js: 효과 이름·아이콘·설명 FX_NAME·FX_ICON·FX_TIP(봉연 fx·귀허 fx/bfx 한 표), 떠 있는 설명 bindTips(.fx-tip, 마우스 올린 동안·휴대폰 누르면 1.8초, 창 아님, 아이콘 누름은 참가자 고르기 아님), 참가자 칸 memberLi(직업 색 .raid-mem .jb-<직업> --jb, 체력 숫자는 막대 안 .bar.mem-hp em)·자세히 showMemDetail(#raid-memdetail: 직업·상태·체력·기여·준/받은 피해·회복·효과·기여 내역, 다시 누르거나 ×로 닫음, 싸우는 중이면 기술 대상도 그 사람), 내 막대 vitHtml(.raid-vit), 기술 단추 coopBtn(SKILL_ICON, 기술 id별), 물품 itemListHtml·itemGroups(이름·남은 수·회복 수치만 — item.js USABLE 체력·정신·영력·침식·치료 마디, fxHtml 색, 설명은 title; .raid-item-list minmax 92px — PC 넷·휴대폰 셋, 체력·정신/영력 두 칸 SP_ITEMS). raid.js·pfight.js·gw.js가 함께 쓰고 새 전투 화면도 이 파일을 쓴다. 새 기술·효과는 아이콘 표에 더한다.
- 합동 토벌 #/raid/<id>(views/raid.js): world_raid_snapshot을 실시간 변경마다(참가 1초·관전 2초 간격, 내 행동 직후 같은 값은 건너뜀, 남의 마지막 한 방으로 끝나도 캐릭터 다시 읽음, 고른 물품·기록 자리 유지). 회차·상태·참가 여부가 바뀔 때만 build, 그 뒤 patch. 요괴의 말·기운 모으기는 높이 고정 #raid-says, 참가자 세 칸 #raid-mem(누르면 기술 대상, 물러남·쉬는 중·자리 비움은 흑백·점선·옅게 li.out, 휴대폰 스크롤 없이 모두), 북돋기·약화 아이콘은 이름 옆 .fx-icons(members[].buffs)·내 칩·요괴 칩(core.js ICONS), 내 피해·기여 .raid-mine(한 줄 말줄임 + 칩 한 줄, 높이 고정, 물품 창 설명 common.js itemDesc). 기록은 새 줄만 덧붙임(logLine: 「이름 — N의 피해」를 k-out 금빛 「이름 → 요괴 N 피해」, 받은 피해 k-in 빨강 「요괴 → 이름 −N 맞음」, 내 줄 .mine — 서버 문구를 바꾸면 여기도). 물품 창 openLayer(다시 읽어도 안 닫힘, 쉬는 중엔 world_use_item). 물러남 안내 #raid-out(쉬는 중 .rest 초록). PC(900px↑) 왼쪽 요괴·행동·기록·오른쪽 참가자, 휴대폰(640px↓) 한 화면: 공격·방어·물품 아래 협동 기술 넷 늘 한 줄, #raid-says 한 줄 18px(기운 모을 때만 그 자리에 막대, :has). 휴대폰 기록은 최근이 위·화면 아래까지(fitLog — 파티 토벌·귀허도 640px↓ 같게).

## 11. 세력과 거점

세력은 소속과 활동 목표를 준다. 세력마다 거점과 전용 콘텐츠가 있고 특징은 활동·임무·상점·보상 차이로 드러난다. 동양풍 미학을 쓰되 세부 세력명·설정은 기존 기획을 유지한다. 거점·상점·임무·평판·전용 보상·교류·채팅과 연결하고, 소속이 활동을 불필요하게 제한하지 않는다.

### 세력 퀘스트·등급

- 대본 표 world_faction_npcs·world_faction_scenes(join 3·rejoin·rank 2~5·vault·hall), 진행 world_faction_progress(join_step·rank·merit·npcs_met·rejoin_pending·show_rank·hall_day/best). world_characters에 열을 더하지 않는다. 등급 이름 world_faction_ranks. 원본 작업 공간 faction_script(gen.py).
- 가입 퀘스트(처음 들 때만, 다시 들면 rejoin 대사 한 번·등급 1): world_faction_sync가 마지막 가입 기록(world_events faction)으로 맞춤. 할 일 need.tasks(search·clue·win·gather·travel·expedition·sell·trade·craft, r·rank·phase·weather·safe·distinct)는 world_faction_task_count가 step_started_at부터 셈. need.at·erosion·cost. world_faction_report가 대사·보상(가방 확인)·다음 장면을 한 번에. 정청 연락관도 보고를 받음.
- 가입만으로 받는 혜택: 정통파 원정 귀환 경험치·숙련·전 +15%(world_expedition_complete)·어디서든 소속 세력 구조대(world_call_rescue own: 반값·경험치 손실 없음·체력 50) / 적월교 강행 원정 전리품 +15% / 흑련회 희귀품 +5%(world_faction_rank_effect, 가입 퀘스트 무관)·판매 한도 +500전(world_affil_cap) / 북령맹 원정 받는 피해 −20% / 수향연맹 가방 +6칸 / 남명회 원정 채집 +15% / 천명원 원정 답사도 +20%(world_expedition_settle). 화면 character.js PERKS·guide.js.
- 등급 퀘스트: 평판(누적, 상한 5000) 300·800·1,600·3,000과 레벨 조건. 등급 효과 world_faction_rank_effect(가입 퀘스트를 마친 지금 세력, (등급−1)×값). 천명원 등급은 예언(조우 −2%씩)과 날씨·시간대 불이익 10%씩 되돌림(world_env_total).
- 공훈(merit): 의뢰판(world_faction_request_claim, 하루 셋 md5(키·세력·날짜) 순, 그날 한 일, 평판·공훈)·퀘스트·수련장·기부로 얻고 비고(world_faction_vault_buy, 세력 안전지대·등급 조건, 팔기 없음)에서만 씀. 비고 world_faction_vault.kind item·title·frame·name_style('ns:1021'~'ns:1027', world_faction_unlocks → world_name_styles)·mount(acquire_method 'faction', 마구간 world_mount_acquire 거절), 물품 아닌 것은 하나만(world_faction_vault_owned). 세력마다 칭호 fv_<세력>(2등급 150)·테두리 fr_f_*(3등급 250)·장비 fv_*(3등급 300, 4단계·거래 불가)·이름 색(4등급 350)·탈것 fm_<세력>(5등급 600, 운임 1, 수향 화방선 ×2.3·나머지 ×1.9 — 수향 나룻배 ×2.1보다 느리게).
- 수향연맹 뱃길(world_river_boat_rank·speed·member): 가입 퀘스트를 마친 수향 조사원이 배(river_skiff·fm_river_alliance)를 타면 속도 ×(1.05+0.05×등급)·운임 없음(world_travel_route·world_charge_mount_fare·world_mount_snapshot river_speed/river_free, map.js). 동승(world_ride_respond) 속도에는 아직 안 넣음.
- 기부 world_faction_donate(세력 안전지대, world_faction_donations): 거래 불가 포함, 기준 시세 50전마다 공훈 1, 하루 30. 장착 마지막 하나·잠금·강화 장비·임무 물품·시세 0 불가(world_faction_donate_info). 진품 이상이 섞이면 한 번 더 묻는다(factionquest.js bindDonate).
- 수련장 world_faction_trial(하루 한 번): world_combat_stats로 등급별 시련 상대(Lv 3·7·12·18·24, 기세 100+8×Lv, 공격 10+2.6×Lv)와 12합까지, log를 replay.js로 한 줄씩(건너뛰기). 3·5등급 첫 통과 칭호 fac_<세력>_t3/_t5, t5는 낙관 sl_f_*.
- 세력 안전지대 world_faction_home: 정통파 정청·객사, 적월교 백골 장터(월식성 아님), 흑련회 십삼문, 북령맹 철벽 고찰, 수향 구름나루, 남명 잔불촌, 천명원 무극 관성대·본부 객사(Lv25 전 분소).
- 화면 캐릭터 › 세력(factionquest.js: 등급 사다리·퀘스트 카드·playDialogue·의뢰판·비고·수련장·인물): 칸 단추(소속 임무·일일 보급·거점·등급·퀘스트·의뢰판·비고·기부·수련장·인물, 할 일이 있으면 빨간 점) → 팝업(character.js openPop, 행동 뒤 refreshPop), 세력 판도만 화면에. 「세력 떠나기」는 거점 팝업 안. replay.js는 550ms마다 한 줄(움직임 줄이기 무관). 안전지대 현장 「세력」 칸, 퀘스트 칸 「세력 화면」은 등급 팝업(sessionStorage yh-fpop). 인물 world_faction_npcs.quote·detail은 누르면 펼침. 조사원 카드 「세력 · 등급」(world_character_card.faction_rank, world_faction_rank_label).

### 세력 판도

- 영향력 world_region_influence: 대세력 조사원이 안전지대 밖에서 토벌 승리 1(정예 2·우두머리 4)·탐색 0.3·채집 0.3·원정 20분마다 1(최대 24)(한 사람·지역·정산 40까지). pg_cron yh-influence(매시 7분, world_influence_tick): ×0.97 후 지난 시간 활동을 더함.
- 지배: 본래 주인(home_faction_id) 기본 150. 도전 세력이 max(150, 지배 점수×1.25) 이상이면 control_faction_id·faction_control 변경(world_faction_log·알림·전체 채팅 '세력 소식'), 60% 이상이면 contested. 안전지대는 안 바뀜.
- 인원 보정 world_faction_boost: √(최다 세력 인원 ÷ 이 세력 인원)배(1~2.5).
- 떠나기 world_leave_major_faction(원정 중 불가, 평판 0, 쌓은 영향력은 세력에 남음). world_join_major_faction은 떠난 지 12시간 뒤(payload.left).
- 관계 world_faction_relations(−100~100, 동맹 40·우호 15·중립·경계 −15·적대 −40, world_faction_rel·world_faction_stance): 한 파티로 활동하면 +0.5(쌍마다 시간당 +1까지), 같은 지역에서 둘 다 3 이상 쌓으면 −0.5(−1.5까지), base로 1%씩 회귀.
- 효과 world_social_effect: 내 세력 지배 채집 +8·희귀품 +3·회복 +5, 동맹 지배 채집 +4·회복 +3, 적대 지배(바깥) 조우 +8·정신 손실 +5, 분쟁 중 누구나 희귀품 +3·조우 +5. 같은 곳 파티원(전투불능 제외, 3명까지) 한 명마다 받는 피해 −3·있으면 회복 +4, 동맹 동료 단서 +5·희귀품 +2, 적대 동료 정신 손실 +5.
- 화면: 「세력 판도」(world_faction_board), 지도 분쟁 지역 붉은 빗금·점선 테두리·퍼지는 고리(map.js cell-contest·contest-ring, 범례 「분쟁 중」), 현장 머리 세력 색 점·「분쟁 중」(common.js safeZones가 10분마다), 조사원 카드 세력 칩(geo.js factionColor, FACTION_COLORS — 남명회 #c2571f·천명원 #a68a3c).

## 12. 경제와 거래

화폐는 전. 채집·제작·상점·거래·탐사 보상을 연결하고 얻는 길과 함께 쓰는 길을 둬 무한 누적을 막는다.

### 상점

- 재고 없음. 하루 세 번(07·15·23시, world_shop_slot) 품목·값(기준가 ×0.85~1.15) 교체(world_shop_refresh: 기본 물품 + 그 밖 절반쯤, 최소 6가지), 한 번에 99개까지. 현장 채집도·월철 곡괭이는 상점 8곳(정청·객사 포함) 상시(기준가 50전, 되팔기·분해보다 비싸게).
- 장비도 판매 가능(임무 물품만 불가, 잠금·장착 마지막 하나는 서버가 막음). 판매 수익 24시간 2,000전(world_shop_sell_status), 팔기 칸에 받은 돈·한도·남은 한도.
- 화면: 사기·팔기 칸에서 항목마다 수량, 아래 구매하기/판매하기 → 확인 팝업 → 한꺼번에. 「이름 ×수량」, 단추는 오른쪽 끝. 시설 창(상점·대장간·거래소·창고·마구간)은 다시 그려도 스크롤 유지(services.js keepScroll — home.js·openStorage·openMarket).
- 대장간(모든 안전지대, world_smithy_snapshot): 제작·강화 재료(흔함·보통)·수리 도구(회차마다, 월철 주괴·정련 숯 상시). 수리(world_repair_quote, world_equipment_repair 'gil'·world_equipment_repair_all)·강화·분해.
- 무기 강화 world_weapon_enhance·world_gear_enhance: 장착 무기 +10까지, 단계마다 위력 +5%. +3까지 100%, 이후 90→30%(백공 +10%p), 실패 시 유지. 비용 전 30×단계×(n+1)·월철 주괴 2+n·정련 숯 1+n/2·+4부터 강철 주괴·+7부터 응축 영핵. 재료는 가방 먼저, 모자라면 창고(반요촌 제외, world_enhance_quote have = 가방+창고·stored = 창고 몫, services.js 「(창고 n)」). 그 무기를 모두 내주면 강화도 지움.
- 구매는 화폐·물품을 원자적으로, 중복 요청 부정 거래 방지.

### 플레이어 간 거래

- 등록 가격 서버 검증: 0전 불가·기준 시세 10배 이하, 동시 10건. 완료·취소 상태 명확, 이동 중복 없음.
- 거래소 창 사기·팔기·직접 거래 세 칸. 사기는 분류 칩·검색으로 줄만 숨김(안 다시 읽음). 팔기는 물품 한 줄·수량/가격 한 줄·등록과 내 등록(범위 밖 가격은 알리고 가장 가까운 값으로 고친 뒤 다시 누르게 — services.js fixPrice, 올린 뒤에도 lastSell). 목록·내 등록·고르기에 등급(rar-tag)·짧은 설명(brief), 640px↑ 두 칸(.mk-list·.mk-mine), 금액 굵게(.mk-price b), 접는 「거래 규칙」(details.mk-rules). 찾기 칸(pick-q·mk-q)·폼 입력칸의 엔터는 보내지 않고 키패드만 내림(noEnterSubmit). 물품 고르기 pickerHtml·bindPicker(분류 칩 장비·소모품·재료·기타·검색·가나다순). 목록 아래 빠진 물품과 까닭(untradeNote).
- 직접 거래 world_direct_trades: 같은 곳 조사원에게(안전지대 밖도 — 성사 기록 trade payload trade_id·gil은 world_guard_action_context 거래소 막기에서 뺀다) 물품·전 제안, 수락하면 서버가 한 번에 맞바꿈. 전 받는 쪽 거래세 5%, 30분 유효, 대기 3건.
- 조사원 의뢰 world_user_commissions(RLS만): 안전지대(반요촌 제외, world_ucomm_place_check)에서 물품(보통·거래 가능·거래소 전용 아님·임무 물품 아님)·수량 1~999·보수(시세×수량×0.5 이상·10전 이상·1,000,000 이하)를 올리면 보수를 맡김(world_ucomm_post, 동시 5건, 3일). 넘기기 world_ucomm_fulfill(안전지대, 보통 먼저, world_trade_bundle_check, 자기 의뢰·차단 사이 불가): 보수 − 수수료(10% × world_trade_tax_mult, 최소 1) + 경험치 20+레벨×3 — 경험치·world_events commission(payload.ucomm)은 하루 세 번까지. 수수료는 올린 곳 지배 세력(fee_faction) 기록만, 전은 사라짐. 알림 ucomm_done(갈래 trade), 안전지대에서 world_ucomm_collect(다 들어가야 함). 거두기·마감 world_ucomm_cancel(전액). world_ucomm_board(마감 지난 것 expired). 화면 journal.js userCommissions·openUcommPost(분류 칩·찾기·150개·수량·보수).
- 세력 경제: 수향연맹 세금 감면(world_trade_tax_mult, 등급마다 −20%, 5등급 −80% — 상점 팔기·거래소 판매자·직접 거래 받는 쪽), 흑련회 그림자 장부(world_affil_cap, 판매 한도 +300전씩).

### 거래 가능 여부

- 희귀 성장 아이템 거래 불가, 사망 관련 아이템 거래 가능. 거래 가능 여부는 서버가 검증한다.
- 거래소 전용(원본 world_item_catalog.market_only 한 칸 → world_market_only·화면 core.js MARKET_ONLY는 물품 목록 mk로 채움): 비취 파편·귀경 파편·뇌철 광석·성진사·요핵·잔화 결정·천공 깃털·각인판·강화 요수 가죽. 직접 거래·정인 선물(world_bond_gift) 불가, 등록가 시세 70% 이상·24시간 20개(world_trade_offer_create), 거래세 10%(world_trade_offer_buy, 수향 감면 적용). 응축 영핵은 거래 불가(+7 강화 핵심).

### 경제 균형

고위험은 기대 보상이 크되 한 지역·행동이 다른 활동을 압도하지 않게 하고, 시세·채집 기대 가치·이동 비용·재료 수요·상점 공급을 함께 본다. 수치는 실제 데이터와 테스트로 조정한다.

- 제작품 시세 ≥ 가장 싼 제작법 재료 시세 합 ÷ 개수 × 1.1. 같은 종류 장비는 높은 단계가 바로 아래 단계 최고가보다 15% 이상 비쌈. 장비는 재료값 1.2배 안팎(넘으면 낮추고, 낮추면 단계 순서가 뒤집히는 장비는 재료를 늘림). 청령단 100·영기환 200전은 제작법이 2개씩. 새 물품·제작법도 지킨다.

## 13. 파티와 협력

파티원 동승·파티 탐사·전투 연계 검증·전리품 분배(기여도순·지정순·균등)·수령 서버 관리·기여도 조작 방지·파티원 전투불능·구조 확인을 지원한다. 파티가 없어도 핵심 콘텐츠를 즐길 수 있어야 한다. 파티 관리는 헤더 동료 화면.

- 현장 파티 칸 home.js partyHtml: 있는 곳·상황(원정 남은 시간·전투·전투불능)·체력·정신·침식·세력 색(world_party_overview mental·erosion·major_faction_id·expedition), 같은 곳 쓰러진 동료 구조, 「파티 원정」, 「돌보기」 openAid.
- world_party_use_item(p_target, p_item_id): 같은 파티·같은 곳·쓰러짐/원정/이동 아님, 약·부적 9가지, 의무관 ×1.4·그 밖 ×1, owner_id 순서로 두 캐릭터 잠금, 받는 쪽 알림.
- 파티 원정: world_party_expedition_propose(원정지·기간·태세) → 같은 곳·떠날 수 있는 동료(world_pexp_ready)에게 party_exp_offer(3분, world_party_exp_offers) → world_party_expedition_respond, 모두 답하면 world_pexp_resolve가 한 트랜잭션에서 파티장·수락자의 world_expedition_start를 차례로(그 사람 JWT sub로, 같은 now()라 시각이 같음). 2명은 수락해야 출발, 3명 이상은 거절·무응답 빼고 출발, 아무도 수락 안 하거나 파티장이 못 떠나면 아무도 안 떠남. world_party_expedition_depart(지금 출발·거두기), world_party_expedition_offer_status(제안 칸). 옛 world_party_expedition_call은 화면에서 뺐다. 같은 지역은 합동 전투(§3.4), 10분 이상 겹친 파티원 한 명마다 귀환 경험치·숙련 +10%(3명까지).
- 동료 초대·거래 제안·원정 귀환은 화면 위에 바로 띄워 그 자리에서 답한다.

### 비무·비무회·혼례(e_tourney.sql·f_bond.sql)

- 비무 world_spars: 같은 곳 조사원에게 카드에서 신청(world_spar_challenge, 한 번에 하나·5분·같은 상대 3분에 한 번) → world_spar_respond → world_combat_stats로 10합(기세 100+8×레벨, 결과 replay.js·spar.js openSparResult). 목숨·체력·물품·전·경험치 그대로, world_events 안 남김(토벌·칭호·기술로 안 셈). 둘 다 전투불능·원정·자율·이동·요괴 전투 아님, 차단 아님.
- 비무회 world_tourneys·entries·entrants·matches, pg_cron yh-tourney(1분, world_tourney_tick). 신청 월 00:00~금 23:59 KST(안전지대 「비무 방」 views/tourney.js #/tourney), 토 21:00 1:1·일 21:00 팀전(같은 파티 2명), 개최지는 주마다 도는 안전지대(반요촌 제외), 1시간·30분 전 알림, 개최지에 없어도 출전(10분 전에 쓰러졌거나 숨졌으면 불참·부전승), 최소 4명(팀). 단판 토너먼트, 작전(태세·회복품 둘·기술 쓰는 때), 기세 100+8×평균 레벨, 레벨 차 1마다 2%(최대 20%), 능력치·장비 차 절반, 합마다 2초. world_events 없음, 규칙 'tourney'(world_tourney_rule_count). 탈것 tn_white_horse(3회 우승), 카드 tn_champ(7일).
- 혼례 world_weddings·guests·lines: 인연도 300·둘 다 Lv20·6장 마침, 본부 정청 또는 한 사람의 세력 거점, 3,000전(1,500씩), 받은 5분 뒤 10분, 하객 박수 3·꽃잎 3·축사 1(40자, 15초 간격), 혼례 떡, 칭호 wed_vow·fr_wed·sl_hap·marks.married(한 지붕). 혼례 올린 연리가 끝나면 다시 맺기 7일. bond.js openWedding.

## 14. 인게임 채팅과 커뮤니케이션

채팅은 방 없이 게임 화면 안에서 늘 쓴다. PC는 오른쪽 열 상시, 좁은 화면은 떠 있는 버튼 → 하단 시트. 활동 로그 같은 불필요한 패널은 두지 않는다. 전송·권한·도배 방지·갱신은 서버와 클라이언트가 일관되게.

### 갈래

- 전체 하루 50회(world_chat_send) · 지역 무제한(도배 방지) · 세력 · 파티 · 모임 · 귓속말.
- 시스템 줄: 쓰러지면 world_notify_downed가 전체 채팅에 sender_name '구조 알림', 다시 일어나면(downed_at이 비는 모든 길) 같은 트리거가 「다시 일어났습니다」(초록 chat-notice sys up). 지배 세력 변경은 world_influence_tick '세력 소식', 봉연 소식도 시스템 줄(chat-notice sys).
- 탭 빨간 점: 전체·지역·세력은 다른 탭을 볼 때 실시간으로 받은 새 말(chat.js chanNew), 파티는 world_party_messages 구독(subscribeParty, 닫힌 시트 안 읽은 수), 모임은 모임마다. 점을 위해 따로 서버에 묻지 않는다.
- 귓속말: 헤더 단추로 여는 별도 창, 상대별(world_whisper_threads·world_whisper_mark_read), 안 읽음 빨간 점, 읽음은 world_whisper_reads(기기 무관).
- 모임 world_circles·world_circle_members·world_circle_invites·world_circle_messages: 모임장·총무(3)·모임원. Lv.5부터 만들고 모임장인 모임 2·든 모임 5·정원 20. 초대는 모임장·총무가 카드에서, 24시간 안에 위 팝업으로 수락. 「모임」 탭은 든 사람만, 탭 아래 단추로 한 모임씩, 모임마다 내 채팅 색(world_circle_members.color), 순서(world_circle_members.sort, world_circle_reorder, 동료 화면 위·아래 단추, 채팅 단추 줄도). 모임원만 읽고(RLS) 2일 보관.
- 서신(gen71/g_letter.sql·letters.js): world_letters(items jsonb·pinned·read_at·claimed_at)·world_letter_sends. 친구(accepted)·차단 아님, 하루 10통, 제목 24·본문 400자. 물품 다섯 가지(world_trade_bundle_check + 임무 물품·강화한 마지막 하나 거절)는 부치는 즉시 빠지고, 물품 부치기·받기는 안전지대(반요촌 제외, world_letter_place_check), 글만이면 어디서나. 받은 서신함 10통(고정 5까지), 넘치거나 고정 안 한 채 3일이면 world_letter_prune이 오래된 것부터 지우고 안 받은 물품은 창고로(칸 넘어도). world_letter_box·send·mark(read·pin·unpin·delete — 안 받은 물품 있으면 지우기 거절)·claim(들어가는 만큼, 하나도 못 받으면 거절). world_housekeeping이 매일 정리. 알림 kind letter. 화면 동료 「서신」 칸·친구 줄·카드 「서신 보내기」(친구일 때), 서신함 1분 캐시(행동 뒤 force).
- 연리(world_bonds·world_bond_requests, 상대 「정인」): 둘 다 Lv.5·친구·정인 없음·헤어진 지 3일·차단 아님. 정표 6종은 정표 칸에 착용, 짓는 값 300전(거절·취소·24시간 경과 반환). 둘 다 착용·같은 곳·같은 파티면 회복 +5%·침식 −5%, 정인 구조 시 체력 50. 인연도 하루 100: 함께 토벌 +2·탐색·채집 +1·안부 +5·선물 +10·원정 완주 +20·구조 +20, 100/300/700에서 꾸미기(pt_yeonri·fr_yeonri·sl_yeon). 선물 하루 1번(거래 가능 물품 또는 전). 파기하면 상대에게 알림·깨진 정표, 차단 시 자동 파기. 공개 숨김 world_bond_public.

### 채팅 화면 동작

- 시트: 위 손잡이로 높이 조절(두 번 누르면 최대↔처음, 기기 저장). 위로 올려 읽는 동안 새 말이 와도 안 끌어내리고 「새 메시지 · 맨 아래로」만. 열린 동안(1099px↓) 바탕 고정(chat.js lockSheetPage: body fixed·top −scrollY, 닫으면 복귀), 시트는 키패드 바로 위(fitSheetToKeyboard: visualViewport --kb·--vvh). 목록 높이가 바뀌면 맨 아래를 보던 중이면 맨 아래로(ResizeObserver).
- 입력: 보내기 단추는 입력칸 한 줄 높이 가운데(grow.js --ta-one, .chat-send margin-bottom). 입력칸은 160px까지 늘고 위 손잡이로 화면 45%까지(grow.js, 기기 저장, 두 번 누르면 처음). 보내도 초점 유지(grow.js keepKeyboard — 터치는 touchend 기본 동작을 막고 requestSubmit). 모바일에서 열 때 키패드를 자동으로 띄우지 않는다.
- 읽기: 실시간이 끊기면 10초마다(살아 있으면 예비 5분) 마지막 메시지 뒤만. 탭 전환·보낸 뒤 전체 재읽기 없음(전체는 loadNew만). 맨 위 근처면 지금 탭 이전 말 50개씩(chat.js loadOlder, 끝이면 「2일 보관」 줄). 파티 20초 읽기는 끊겼을 때만. 모임은 보낸 뒤·30초 넘게 비웠다 오면 loadCircleNew. 모임 읽음(world_circle_mark_read)은 안 읽은 말이 있을 때만 20초 묶음, 숨김 때 보류.
- 모양: 얼굴(프로필 사진·문장, world_chat_faces로 처음 보는 사람만 한 번에 묻고 기억, 못 읽으면 첫 글자)·이름·칭호·시각 머리글, 같은 사람이 5분 안이면 머리글 없이(chat.js msgRow). 입력은 알약 한 줄(귓속말은 말풍선). 얼굴 28px, 테두리 단 얼굴은 프로필 카드 얼굴(72px, 모서리 문양까지)을 34px로(.av.mini, world_chat_faces.frame 등급색 테).
- 이름 색: 설정 › 프로필 색상환 각도(0~359, 비우면 자동, world_set_chat_hue → profile.chat_hue), 보낼 때 서버가 sender_color(world_chat_stamp_title·world_circle_send, 파티 world_party_chat_snapshot), 밝기는 테마. 특별 이름 색 1001~1015(자개빛·주홍 칠·금박·청자빛·물비늘·월백·묵영·단풍·송화·무쇠·혈홍·무혼·도화·바람결·성운; 등급·칭호 수·분류별 수로 엶, world_name_styles·world_set_name_style, chat.js NAME_STYLES) = 평면 색 + 이름 앞 작은 마름모(채팅·카드). 세력 1021~1027, 귀허 1028, 레거시 1016.
- 「#패치노트」·「#패치노트:id」는 링크(chat.js richText).
- 새 창 ?pop=chat·?pop=whisper: app.js renderPop이 채팅(mountChat)·귓속말(whisper.js mountWhisperPage, 받는 귓속말 직접 구독)만 그림, 같은 로그인이라 한 곳 접속 규칙에 안 걸림. window.yahangPop(kind)(.chat-pop·.wh-pop, 마우스 화면만), 새 창 #/ 링크는 opener로. 채팅 새 창 동안 본 창 채팅 정지(chat.js popLink·suspend·resume, BroadcastChannel 'yh-pop': 열 때·20초마다 chat-open, 닫을 때 chat-closed; 본 창은 실시간 셋을 끊고 받는 귓속말만 whisper.js whisperFeed; 60초 무소식·「게임 창으로 되돌리기」(.chat-home·.wh-home)·본 창 「채팅 되돌리기」(#btn-chat-back, 멈춘 동안 헤더 여섯째)면 재연결; body.chat-out이 오른쪽 칸을 뺌). 되돌릴 때 refillAfterPop: 최근 80 + 전체·지역·세력 각 50, 모임·파티는 다음에 열 때. 본 창을 새로 열어도 ping으로 알아챔. 귓속말 새 창도 같은 신호(whLink: wh-open·wh-closed·wh-unread / wh-ping·wh-target), 그동안 본 창은 world_whisper_threads를 안 읽고 단추·openWhisperWindow가 window.open('', 'yh-pop-whisper')로 앞으로 불러 상대를 넘김.

### 사람 사이

- 이름을 누르면(채팅·여기 있는 이들·동료) 조사원 카드 world_character_card(레벨·직업·소속·대표/장착 칭호·숙련·지금 상황·있는 곳). 전·가방·능력치는 안 내보냄. 숨김 칭호도 내건 것은 이름을 보이되 못 얻은 사람에겐 설명을 가림.
- 카드에서 친구 신청·수락·끊기·귓속말·파티 초대(없으면 만들고)·거래 제안(같은 곳)·구조(같은 곳·전투불능)·비무·차단. 친구 world_friends(50명·대기 20건)는 동료 화면 카드(.people.cards, 단추는 이름 아래)에서 위치·상황·최근 활동. 차단 world_blocks: 친구 끊김, 상대의 귓속말·친구 신청·파티 초대·직접 거래를 서버가 막고 채팅에서도 숨김.

## 15. UX/UI 디자인 방향

### 시각적 정체성

현대적인 다크 판타지: 어두운 배경·절제된 포인트 색·야간 도시의 은은함·읽기 편한 글꼴과 명확한 위계·일관된 패널·버튼·상태 표시·장식보다 편의.

- 이모지를 장식으로 쓰지 않는다(아이콘과 글).
- 평면 디자인(그라데이션·그림자·흐림 없음). 예외(사용자 요청): 컷씬, 색 고르기 판·막대.
- 테마 theme.js THEMES 32가지: 프리셋(야행·한지·청자·단청·쪽빛·황토·월하·홍매·송연·나전 등)과 흑·백 버전, 모서리·글꼴(고딕·명조)·선 굵기, deco {tex(tile·brush·dot·bamboo·wave·lattice·star·grain·hanji), frame(bracket·dot·round·double·line·none), head(plain·band·under)} → :root data-tex·data-frame·data-head(또렷한 선·점만). 새 테마도 deco를 단다. 바탕·강조·포인트 색 직접 고르기.
- 색 고르기 colorpick.js: app.js installColorPicker가 모든 input[type=color] 누름을 가로채 openColorPicker → 「설정」하면 value를 바꿔 input·change. 사각형 판(가로 채도·세로 밝기)·색조 막대·Hex·추천색 24(PICKS: 바탕 8·강조 16).
- 글자 크기 다섯 단계(theme.js FONT_SIZES, --fz 0.85~1.22, yh-fz), CSS는 calc(Npx * var(--fz, 1)), 터치 입력칸은 16px 아래로 안 내려감.
- 촘촘하게: 본문 14px·줄 간격 1.5·단추 38px/작은 단추 32px·입력 40px(터치 입력만 16px). 화면 글은 줄이고 설명은 작게(모바일 11.5px).
- 꾸미기(등롱+꺾쇠 액자): .scene 네 모서리 꺾쇠 .frame-c, .view-head 왼쪽 위·오른쪽 아래 꺾쇠, 하위 탭(segmented 셋째 값) 아이콘 + 짧은 이름(모바일 위아래로). 현장 행동 아이콘 칸 .act-tiles(탐색·원정·야영·자율 휴식·지도, 설명은 title; 「자율 휴식」은 캐릭터 › 자율 휴식 칸으로 sessionStorage yh-idle-focus).
- 현장 머리 배경 scenery.js: 네 겹(하늘·먼 산 둘·장소 상징물·앞땅과 풀) 장소 테마별 전경(도성 기와집·탑·석등 / 들과 숲 소나무·활엽수 / 사당 도리이·석등·소나무 / 물가 돛단배·갈대·물결 / 산악 설산·폭포 / 황무지 모래언덕·부서진 기둥 / 지하 종유석·수정 / 천문 관성대·혼천의·별자리) + 시간대 해·달 + 날씨 덧그림(비·눈·안개·흐림·바람·혈무, 세우 .scene-fx[data-w=drizzle]). 장소 색으로 옅게. 넓은 화면은 640 한 폭을 하나 걸러 좌우 뒤집어 세 번(REPEAT, 해·달은 오른쪽 한 번, 아래 앞땅 띠, .scene-art 폭 100%). .scene-fx 움직임은 「동작 줄이기」 무관(같은 선택자에 !important, 다른 움직임은 멈춤).
- 내부 코드(예: hq_archive)·영문 분류명(예: equipment)을 화면에 노출하지 않는다.
- 조사: 서버 문구는 「이(가)」「을(를)」「(으)로」로 쓰고 화면 core.js josa(esc가 부름)가 받침에 맞춤. 서버에서 정해야 하면 world_josa(낱말, '이', '가'). 조사를 문자열에 박아 두지 않는다.

### PC

2~3열, 주요 콘텐츠와 보조 정보 구분, 상태·로그 배치, 인벤토리·지도·전투 빠른 접근, 페이지 이동 줄이기. 현장은 왼쪽(탐색·기록)·오른쪽(길·채집터)을 따로 쌓고, 이동 띠가 뜨면 상태판·채팅 높이 −46px. 상태판은 한 화면(높이 900px): 상태이상은 생존 칸(.vitals .statuses) 안, 소지금·노정패·가방·위치 2×2(.money), 1100px↑ 카드 여백 10px.

### 모바일

별도 설계(PC 축소 아님). 핵심 내비 최대 5개 한 화면, 가로 스크롤 탭 없음, 한 손 크기 버튼, 모달·로그·인벤토리·지도·입력창이 잘리지 않게. 아래 탭은 아이콘만 둔 떠 있는 알약(이름은 aria-label·title).

### 공통 편의 기능

- 내비: 헤더 아이콘 알림·귓속말·동료·도움말·설정 5개, 핵심 탭 현장·지도·캐릭터·가방·일지 5개. .head-actions는 줄바꿈 없이 넘치면 다음 줄, 도움말 머리 단추 넷은 모바일 2×2(.grid4).
- 로그인 페이지와 게임 화면 분리, 방 생성 없이 로그인 후 바로 게임.
- 로그아웃: 설정 페이지 위 단추·설정 › 계정·프로필 창(확인 팝업). 서버가 막혀도 3초 안에 기기 로그인을 지우고 로그인 화면으로.
- 한 계정 한 곳 접속: 로그인한 브라우저가 현재 접속(world_active_sessions, JWT session_id), 다른 곳의 갱신 토큰을 끊고, 다른 브라우저는 실시간·화면 복귀·1분 확인으로 알아채 스스로 로그아웃하며 까닭을 로그인 화면에. 게임 중 SIGNED_OUT이면 app.js가 페이지를 새로 열어 타이머를 끊는다.
- 설정 페이지 #/settings: 프로필·테마·소리·알림·계정, 프로필·테마는 한 번에 저장. 프로필 버튼은 보기 화면 → 그 안 수정 버튼. 캐릭터 프로필(문장·색·소개)과 계정(이메일·비밀번호) 분리, 프로필이 없으면 캐릭터마다 고정 무작위 문장. 제보는 도움말·설정.
- 현재 상황(이동·자율·전투·원정·전투불능)을 늘 보인다: PC 왼쪽 상태판, 모바일 상단 띠(펼침 화살표 앞 상태 칸 10개 5×2 점 hud.js hs-slots: 나쁜 상태 깜빡이는 빨강·이로운 초록·빈칸 투명, 나쁜 것 먼저). 「원정 보기」는 그 자리 팝업, 현장을 안 볼 때만 「현장 보기」.
- 캐릭터 › 상태: 맨 위 퀵슬롯, 조사원 상태 칸(생존 2×2·정화/마음 다잡기·착용 장비 8칸(누르면 물품 정보)·전투 능력 한 줄), 옆 상태이상. 회복·치료 물품은 확인 창(효과·남은 수량)을 거침.
- 확인 창은 게임 안 팝업(ask). 도주는 확인 없이 바로, 결과 팝업(받은 피해·남은 체력).
- 팝업(openModal·openLayer)을 여닫아도 바탕이 안 튐: core.js lockPage·unlockPage(첫 창 때 자리 기록, 마지막 창이 닫히면 같은 주소일 때 되돌림, 250·700ms 뒤 한 번 더), 창 안 초점 preventScroll. 다시 그리며 새 자리를 정하면 scrollAfterModal(y)(창이 있으면 닫을 때, 없으면 위로 밀렸을 때만). 현장 home.js draw는 늦게 채우는 퀘스트 칸·토벌 띠에 지난 내용을 두고 채운 뒤 맞추며, 현장 토벌이 끝나면 fieldY로 되돌림(scrollAfterModal(y, force)). 캐릭터 draw soft도 유지. 창 위 물품 정보·카드는 겹쳐 뜨고(openLayer) 닫으면 아래 창이 남음.
- 입력할 때마다 다시 그리는 검색칸은 한글 조합 중(e.isComposing)엔 안 그리고 compositionend에(bag.js 가방·제작).
- 화면을 옮겨도 쓰던 내용(채팅·귓속말·저장 전 프로필·생성 화면의 이름·직업·소속) 유지.
- 성장 알림 growth.js: 레벨·숙련 단계·가방 칸이 늘면 잠깐 뜸(지난 값은 기기에 캐릭터별 — 접속 안 한 사이도).
- 알림: 실시간 + 행동 뒤(15초에 한 번, 전투 턴 중 제외)·화면 복귀·1분마다 다시 읽기(settings.js loadNotes, 실시간이 살면 예비 5분). 설정 › 알림: world_notify_prefs(off 갈래), world_notify_group(kind→갈래: rescue·friend_rescue·party·friend·trade·raid·title·reward·bag·circle·spar·bond·faction·letter·housing, 나머지 못 끔), BEFORE INSERT trg_world_notify_prefs가 끈 갈래를 읽음으로. world_notify_prefs_get·set. 새 알림 종류는 world_notify_group에도. 친구가 쓰러지면 다른 곳 친구에게 friend_down(같은 곳은 rescue_request), 「지도에서 보기」 map.js focusRegion(지역 이름도 받음, 다른 화면 지역 짚기도 같음). 확인한 알림은 「지난 알림」.
- 처음 안내: 처음 만들면 단계별 안내(13단계, 진행 중 스크롤 고정)와 현장 「첫 걸음」(보급·바깥 이동·탐색·채집·토벌·단서; 접기, 항목마다 알림, 직접 닫기 전까지 남음), 도움말에서 다시 봄. 진행은 world_events, 상태는 world_tutorial_state(캐릭터별).
- 도움말: 별도 페이지, 튜토리얼을 대신할 만큼 규칙·수치를 담음. 묶음(처음·세계·이동·탐색·전투·생활·원정·성장·세력·가방·경제·교류·사건) 카드, 항목은 접는 칸, 검색은 묶음 무관하게 펼치고 찾은 말 표시(views/guide.js GROUPS, 새 항목은 묶음에도). 소속 항목(6가지 보급·임무) 따로. 로그인 화면 한 줄 안내 app.js TIPS(누르면 다음 줄).
- 지도: 확대·축소·이동, 이름표 겹침 없음. 모바일은 지역을 누르면 위 띠(확대 단추 왼편)에 예상 시간·자세히·출발(또는 현장). 완전 답사 바깥 지역(world_survey_full_regions, 나만·10분 캐시·탐색/채집/원정 뒤 새로)은 금빛 테 .survey-ring + 바탕색 테 .survey-edge, 범례 「답사 완료」. 세력 경계선 .b-border는 .b-coast와 같은 굵기 1.6.
- 지도 물길 assets/js/water.js(화면만, 좌표 위 손그림 — 좌표를 옮기면 함께 고침): 큰 강(천경호→설피골→백지교→구름나루→연화늪→용잠 수궁→만조의 갑문, 끝은 해안 안쪽 938)·수경루 호수·염등촌 개울→흑조 균열·구룡 폐수로(땅 밑 점선)·못·늪 갈대·연꽃·심연(구중 봉연·귀허 소용돌이)·월영 유리못·해안 얕은 물 띠·구등대 군도 섬(가장 큰 섬에 등대 lighthouse, 가까이 볼 때 불빛). 물마다 in(그 지역이 있을 때만, 귀허도는 열린 뒤), 1.35배 아래에선 잔 물줄기·갈대·연꽃 생략, 색은 테마 바탕 + 물빛(app.css #map-svg --water), 땅 위·국경 아래·누르기 판정 없음. 이름표 색·강 이름은 두지 않음(사용자 결정). 바다낚시 지역(SEA_FISH: 바다 물가 넷 + 바다 낚시터 다섯) 해안 변 밝은 물빛 3.2(.b-coast.sea)·얕은 띠 .w-shallow.sea, 범례 「바다낚시」(바다에 안 닿는 칸은 표시 없음). 바다 낚시터를 바꾸면 SEA_FISH도.
- 현장 답사 지도 home.js tree: 「길 찾은/전체 · 채집터 찾은/전체」, 다 찾은 곳 표시, 못 찾은 길은 빈칸, 위에 답사도 막대(30·70·100%). 「이어진 길」에서 못 가는 곳은 단추 안에 까닭(필요/지금 레벨·전투불능·이동 중·원정 중).
- 상점·대장간·거래소는 안전지대 현장에서 연다.
- 공지·패치노트 #/patch(views/patch.js, world_patch_notes note_id·title·body, 읽기 전용 RLS): note_id '0.0.0'이 맨 위 늘 펼친 공지(patch.js NOTICE), 운영진 「공지 고치기」 world_patch_notice_save(제목 80·본문 6,000자, 남은 서버가 거절), 링크 「#패치노트:0.0.0」. 도움말·설정·새로고침 안내에 단추.
- 제보·소감(도움말·설정): 분류 오류·밸런스·제안·소감 및 기타(review)(옛 화면·기타는 표시만)·제목·내용, 원하면 화면 위치·크기·기기·최근 오류(world_bug_reports, 1시간 5건). GM 알림, GM은 「받은 제보」에서 상태(접수·확인 중·고침·닫음)·답(보낸 이 알림). 조사원은 자기 것만, 「지우기」 world_bug_report_hide(행은 남아 운영진 칸 「보낸 이가 지움」). 첫 의견 보상: 계정마다 한 번 노정 건량 2·청심환 2(world_report_reward_give, world_report_rewards, 운영진 제외, 넘치면 창고, world_bug_report_list.reward_done 안내).
- 운영진은 world_staff 명단, GM 표식은 명단 캐릭터만(이름에 GM을 넣어도 안 붙음). 채팅·귓속말에서 GM은 이름 대신 표식만(누르면 카드). 현재 GM: 아이디 mu5ician(테스트용).
- 꾸미기: 테두리 22·바탕 무늬 6·낙관 17(세력 낙관 7, world_cosmetic_catalog). 여러 활동으로 얻고 칭호 판정 때 함께 판정·알림. 장착 world_cosmetic_equip(소유 확인 → profile.frame/pattern/seal). 카드·내 프로필·여기 있는 이들·동료 목록에, 채팅엔 테두리만. 숨김은 얻기 전 이름·조건을 가림. 설정의 꾸미기 칸은 누르면 묶음 아래 줄에 얻은 경로(잠긴 것은 방법). 움직임 효과는 최종 콘텐츠 단계에서.
- 로딩·오류·비활성·수령 가능 상태를 명확히, 연타해도 중복 요청 없음.

### 소리

- 배경음악 sound.js: FluidR3 GM 사운드폰트(CC BY 3.0, 도움말에 출처) 샘플 assets/audio/*.mp3(3.2초 칸: 고토=가야금·샤쿠하치·플루트=대금·피들=해금·첼로·현악·하프·종·북·피아노), 그 지역 악기만 받아 풀고 나머지는 내려놓음(AudioContext 32kHz). 조각은 tools/bgm_samples/build.py로 만들고 각각 최대 −1.5dB로 맞춤.
- 편성 PROFILES: 빠르기·박자(meter 4·3)·rhy·acc(ACC)·bass(half·long·waltz·drive·march·pedal·tango)·drum(DRUM, drumIn)·pad(swell·sustain·light·cluster·open·none)·form(도입·A·A2·B·C·A3·잇는 마디·북 마디, 단락마다 악기·세기·echo·duet·trem·oct). 직할령 D단조 72 대금·가야금 / 수향 E장조 108 3박 춤곡 플루트·가야금 / 북령 A단조 54 피아노 애가·첼로 / 남명 C장조 124 대금·가야금 16분음 / 변경 E단조 88 해금·현악 8분음·북 행진(해금은 변경 중심, 심연 절정에만) / 지하 C#프리지안 48 대금·낮은 피아노·심장 북 / 천문 F장조 66 피아노·하프·종 / 심연 B단조 56(전투 72) 피아노만 탱고 애가(PROG.tango i–♭VII–VI–V·RHY oblivion·ACC tango 3+3+2·bass tango, bassIns piano, pad none) / 귀허도 D단조 54(전투 70) 같은 결을 첼로·현악·하프로. 주제(A)는 영역마다 고정, 나머지는 되풀이마다 새로. 전투 편성(battleOf) PROFILES[].bt(100~140·4박, pad 기본 light(B 단락만), 현악을 길게 까는 곳은 변경·북령 전투뿐), 안전지대는 조금 느리고 북 없이.
- 음악 규칙: 마디 자리마다 세기 DYN·첫 박 강세, 긴 관·현악 playNote o.expr·o.vib, pad·첼로 긴 음 o.swell. 1박 넘는 선율 음은 그 마디 화음 음, duet은 화음 음 중 3~6도 아래, echo·받아치는 음도 화음 음, 단조 V는 이끎음 올림(hm), 프리지안 V는 ♭II, 어두운 곳 pad는 뿌리·5도·옥타브(open), 3~6도 도약 허용. 큰북 playDrum(녹음 북 + 사인파 몸통 + 걸러 낸 잡음, big·mid·small), DRUM 장단 main·alt(짝수 마디)·fill(프레이즈 끝).
- 전투 음악은 원정대가 나가 있는 동안만('expedition' 알림의 귀환 시각까지 scene.exp), 현장 토벌(home.js setScene battle)은 곡을 안 바꿈(사용자 요청). 컷씬 곡 동안(yh-cutscene) 배경음악 쉼. 소리가 막혀 있으면 「소리 켜기」 깜빡임.
- 미리듣기 tools/bgm_preview(render.js가 sound.js를 그대로 읽어 구움). 컷씬 곡(첫째 밤의 끝·아침) tools/cutscene_music(compose.js·render.js → assets/audio/cutscene.mp3·cutscene_morning.mp3): 마디 길이를 표본 수로 맞추고 되풀이 8마디를 세 번 구워 가운데를 loopStart~loopEnd로(시각 cutscene.js MUSIC). 로그인 화면은 다시 연 뒤(app.js REOPEN_AT) 「아침」 되풀이 여덟 마디를 조용히(cutscene.js loginMusic, 처음 누를 때 시작, 로그인하면 잦아듦).
- 환경음(재료 assets/js/ambience.js, 세기·때는 sound.js updateAmbience·critters): 비·바람·물·풀벌레·새·부엉이·물방울. 비 rainBuffer = 짧은 빗방울을 흩뿌린 결(장우 1초 1500개 + 굵은 방울 10개, 이음매 없이 · 세우는 「똑 · 또독」 굵은 방울 1초 1.6번 위주 + 장우 결 아주 작게). 바람은 삭풍에만: 좁은 띠 잡음 세 갈래를 돌풍 곡선(2.5~5초)으로 세기·음 높이 함께. 미리듣기 tools/ambience_preview/render.html(OfflineAudioContext).
- 음량: 배경음악·환경음·효과음 따로 + 전체 sound.vol(master 0.9×vol, 컷씬·로그인 곡도). 효과음은 행동 종류마다 다름.
- 모바일(터치)은 화면을 내리거나 다른 앱·탭이면 멈추고 돌아오면 다시. PC는 다른 창이어도 계속. 배경음악·환경음은 한 창만(soundLink: 누르거나 고른 창이 BroadcastChannel 'yh-sound'로 맡고 나머지 yielded), 새 창(?pop=)은 소리 없음(initSound 즉시 반환, playSfx 막음).
- 알림음 「띠로링」(playAlarm·armAlarm·ALARMS): 귓속말(whisper.js onWhisper)·채팅 @캐릭터 이름(chat.js mentionAlarm: 전체·지역·세력·파티·모임, 받은 지 2분 안)·탐색력 가득(hud.js bumpStamina·다시 읽기)·잠깐/푹 쉬기 쿨타임 끝(rest_short·rest_full, 10초 안 겹치면 한 번, views/common.js가 world_rest_status를 읽을 때)·원정 귀환·자율 끝(hud.js). 설정 › 소리 「알림음」에서 종류마다(sound.alarm, 기기, 들어 보기는 효과음 견본 줄 끝 「알림」), 제 길(alarmBus), 크기는 효과음 음량(최소 25%), 새 창에서도 울림, 같은 일은 localStorage yh-alarm:<key>로 한 창만. 탐색력 가득·쉬기·자율 끝은 화면 아래 글도(ALARM_TEXT, 소리가 막혀도, 끈 종류·새 창 제외). 서버 요청을 늘리지 않는다.

### 롤백·초대·점검

- 컷씬 cutscene.js: 다시 연 뒤 생성 화면(app.js renderCreate)이 계정마다 한 번(yh-morning:<uid>) 「아침」(REOPEN_AT 이후만), 로그인 화면 「아침」 되풀이 음악(loginMusic). 롤백 순간의 「첫째 밤의 끝」·점검 페이지 컷씬·cutscene.mp3는 롤백을 마쳐 지움(2026-11-02, 점검 문 닫기·열기는 supabase/maintenance/start.sql·end.sql).
- 점검 중 도움말 help.html: 대기 화면 단추·컷씬 오른쪽 위 「도움말」(.cs-tr .cs-help, stay면 늘 보임), guide.js render(el, {standalone:true})가 서버 필요한 단추(패치노트·처음 안내·첫 걸음·제보)를 빼고 그림(DB 요청 없음).
- 점검 차단: public 사용을 거두면 authenticated RPC·표 읽기와 anon 표 읽기가 42501, 가입 훅은 supabase_auth_admin이 public 사용 권한을 따로 가져 돌고 invite_open_at이 없으면 403. 롤백 SQL은 world_app_meta invite_required를 지우면 안 된다(지우면 초대권 없이 가입). Edge Function·Storage 버킷 없음. 1장 첫 장면 대사 덧붙임 supabase/pending/rollback_intro.sql.
- 계정 zjaqorgha(캐릭터 「고창덕」)는 GM 배부 초대권으로 운영진이 만든 정식 계정 — 계정(auth.users·초대권 사용 기록)은 보존, 캐릭터는 똑같이 롤백 대상(사용자 결정, 휴면 정리 대상 아님).
- 초대권 world_invites(함수로만): 정원 60 = 계정 + 초대권. world_invite_distribute가 60 − 계정 수만큼 만들어 계정마다 한 장(고정 서신·알림), 남은 것은 비축, invite_required를 켬. 가입은 world_hook_before_user_created가 user_metadata.invite를 확인, trg on_auth_user_invite(world_invite_on_user)가 사용 기록(같은 번호 동시 가입은 하나만). 사용 기간 world_app_meta invite_open_at(롤백을 마친 때)부터 7일, 그 전엔 가입 불가. 내 초대권 world_invite_mine(계정·생성 화면, account.js fillInvites), 운영진 world_invite_admin(비축 보기·정원 안 추가). 가입 화면 초대권 번호 칸.

## 16. 서버 및 기술 운영 원칙

20명 미만, 비용 최소. 백엔드 Supabase, 프런트 정적 호스팅(Cloudflare Pages). 무료·최소 비용은 목표이지 무중단 보장이 아니며 사용량 제한·일시 중지 정책을 고려한다.

- 서버: Supabase Pro, 서울(ap-northeast-2) 프로젝트 wphhqfkxrqjxxmfyozff(Ranway). Cloudflare Pages는 작업 브랜치에 올려도 배포될 수 있다.
- 이사 도구 .github/workflows/db-move.yml(수동, 비밀값 OLD_DB_URL·NEW_DB_URL — 지금은 지워져 있어 이사 때 새로 등록): CHECK 접속 시험 · MOVE 덤프·복원(점검 모드·fn_owner 역할·실시간·auth 트리거·행 수 비교) · ACL(supabase/maintenance/acl_sync.sql). 새 프로젝트 기본 권한 때문에 복원 객체에 anon·authenticated 권한이 붙으므로 MOVE 뒤 반드시 ACL. 이사 뒤 Auth 설정(이메일 확인 끄기·Site URL·Before User Created 훅 world_hook_before_user_created)은 대시보드에서.

### 기술 원칙

- 게임 데이터는 서버에서 검증·저장. 클라이언트의 재화·보상·기여도·시간·소유권을 믿지 않는다.
- RPC는 인증·권한 검증. RLS를 끄지 않는다. SECURITY DEFINER는 최소 권한·고정 search_path. 비밀 키·service_role 키를 프런트에 노출하지 않는다.
- 반복 폴링 최소화, 지금 화면에 필요 없는 데이터는 갱신하지 않음. 중복 요청·동시성 충돌·거래/보상 중복 방지. 실제 테스트 결과와 추정을 구분.
- world_characters는 열마다 권한이 걸려 새 열을 더하면 함수 주인 역할의 select *가 깨지므로 캐릭터별 새 값은 별도 표에.
- manifest.webmanifest(orientation 없음 — "any"면 안드로이드 설치 앱이 회전 잠금을 무시)와 assets/icons(192·512·maskable 512·apple-touch·svg)를 index.html·maintenance.html이 건다.
- 접속 속도: index.html이 서버·esm.sh에 미리 연결하고 모듈을 modulepreload(새 JS 파일은 목록에 추가). 점검 확인 둘은 동시, 로그인 이벤트가 두 번 와도 한 번만 꾸림(app.js route). 캐릭터·묶음 크기 함께 읽기, 이름 사전은 기기 yh-names-v1. 「접속 중」 8초 늦음 안내·25초 바쁨 안내 + 「다시 시도」·파일 실패 까닭(boot.js).
- 라우터는 화면마다 새 칸(.view-host)을 넘겨 늦은 응답이 다른 화면을 덮지 않게.

### 요청 줄이기

- 행동(act)은 캐릭터를 한 번 읽고 changed를 보냄. 전투 중 끝나지 않은 턴(core.js midBattle)엔 다른 화면이 안 읽음. 행동 뒤 재요청은 캐릭터·상태판·현재 화면 정도(여기 있는 이들·동료는 자리·파티가 바뀔 때만 views/common.js ROSTER_CHANGERS, 첫 걸음 15초에 한 번). 새 기능도 changed마다 여러 요청을 보내지 않는다.
- 상태판 hud.js: world_hud_snapshot을 common.load로(다른 화면과 1초 안의 값 공유), 1분 읽기는 45초 안에 읽었으면 건너뜀, 캐릭터 3분, 화면 복귀는 30초 넘게 비웠을 때만, 탐색력 회복은 화면에서(bumpStamina), 자율 상태는 자율 행동 뒤에만.
- 가방: 물품 목록·제작법은 접속 동안 한 번(common.js inventorySnap), 그 뒤 world_inventory_state만.
- 캐시: 낚시터 30분·휴식·자율 10분(버리기 common.js FISH_CHANGERS 등), 캐릭터 › 상태 쉼·정인(관련 행동 뒤에만), 전투 능력치 1분(COMBAT_CHANGERS 뒤 버림). world_combat_profile은 미리보기(plus_one, world_combat_stats 7번)를 p_preview=true일 때만.
- 칭호 점은 알림(title·cosmetic) 때와 행동 뒤 2분에 한 번. 알림·채팅·접속 확인·귓속말은 실시간이 살면 예비 5분(끊기면 예전 간격), 알림 구독 user_id 필터, 파티 채팅 party_id 필터. 동료 화면 45초·가벼운 읽기(모임·연리·서신·전리품은 관련 행동 뒤). 운영진 명단 6시간. 묶음 크기·무기 갈래(yh-stacks-v3)·가방 사전(yh-inv-static-v1)은 db_version(core.js dbVersion)이 같으면 기기 것. 버전 확인 2분.
- 서버: world_survey_full_count(질의 하나, 하나라도 찾은 지역만), 꾸미기 답사 규칙은 탐색에서 길·채집터를 찾았을 때만, 지도는 답사 기록·지역 소개를 join으로 한 번씩.
- 작은 SQL 함수: security definer이거나 search_path를 고정한 SQL 함수는 인라인되지 않아 매번 계획을 짠다. 자주 불리는 것은 plpgsql `#variable_conflict use_column` + `return (select * from (본문) yhq limit 1)`. 새 도우미도 definer·SET이 필요하면 plpgsql, 둘 다 필요 없으면 인라인되게 SQL.
- 실시간(supabase_realtime)에는 화면이 구독하는 표만: world_active_sessions·world_chat_messages·world_circle_messages·world_notifications·world_raids·world_party_messages. 자주 고쳐지는 표(world_characters·world_events)는 넣지 않는다. 새로 구독하는 표가 생기면 그때 더한다.

### 디스크 I/O 방침

1. 행동 한 번의 쓰기를 늘리지 않는다. 기준: 탐색 1번 캐릭터 행 갱신 3번(world_stamina_change·탐색 마무리·world_events 트리거)·변경 기록 약 7.7KB, 토벌 승리 기록 1번·3.5KB. world_events가 캐릭터를 고치는 몫(노정패·숙련·토벌 침식·희귀 전리품·기술 경험·경험치/레벨·평판·상태 피해)은 trg_world_aa_event_char(world_event_char_apply, 이름순 가장 먼저 — 칭호 판정·상태 굴림보다 앞)가 한 번에. 옛 트리거 함수 다섯(world_award_mount_tokens·world_apply_event_progress·world_track_specialized_skill·world_award_progression_from_event·world_track_major_faction_reputation)은 트리거만 지우고 남김, world_apply_activity_status는 칭호 판정·상태 굴림만. 탐색은 모든 캐릭터 몫을 마무리 갱신 하나로. 새 기록 보상은 world_event_char_apply에 더하고, 새 트리거·함수가 캐릭터 행을 따로 또 고치지 않는다. 측정: 되돌리는 시험에서 world_characters에 임시 AFTER UPDATE 트리거(pg_context 기록)와 pg_current_wal_insert_lsn() 차이(앞에 lock table을 걸어 교착 방지).
2. 행동 뒤 재요청 최소(위).
3. DB 변경은 작은 SQL 여러 번이 아니라 한 파일로 한 번에(실행마다 API 서버가 스키마를 다시 읽음).
4. 기록 정리 pg_cron yh-housekeeping 매일 04:13 KST world_housekeeping(): 읽은 알림 14일·채팅·귓속말·모임·파티 채팅 2일·경제 장부 60일·지난 비경 1일. world_events는 칭호 진행·첫 걸음이 처음부터 세므로 지우지 않는다.
5. 주 1회 대시보드 Reports Disk IO와 pg_stat_statements wal_bytes 상위 확인.

### 권한

- 새 함수는 기본 권한이 anon·authenticated에도 실행을 주므로, 공개용이 아니면 revoke all ... from public, anon, authenticated를 함께. 주인이 fn_owner_*인 함수의 권한은 그 역할이 준 것이라 postgres의 revoke가 조용히 무시된다 — `set role 주인` 뒤 revoke, `reset role`. postgres에 ADMIN만 있고 SET이 없으면(fn_owner_18664 등) `grant 역할 to postgres with set true` → set role → revoke → `with set false`. PUBLIC으로 열린 것을 거둘 땐 먼저 fn_owner_*·postgres·service_role에 직접 준다.
- 화면·함수·예약 작업 어디서도 안 부르는 옛 행동 함수·안쪽 도우미·트리거 함수의 실행 권한은 거둬 두었다(함수는 남음). 점검: authenticated가 부를 수 있는 security definer 목록을 assets/js가 부르는 이름과 견준다. invoker 함수(world_economy_price_snapshot·world_mount_snapshot·world_map_snapshot)가 부르는 world_shop_sell_unit·world_river_boat_member·world_gwiheo_open은 남긴다. profiles는 handle_new_user가 쓰므로 남긴다.
- security invoker 도우미(world_bag_room·world_bag_count·world_item_stack·world_inv_count 등)를 definer 함수에서 새로 부르면 그 주인 역할에 안쪽 함수까지 실행 권한이 필요하다. 되돌리는 시험은 postgres로 돌아 못 잡으므로 `set local role fn_owner_…`로도 불러 본다.
- 주인 역할 점검: definer 본문이 부르는 public 함수를 주인이 실행할 수 있는지 pg_proc.prosrc의 `public.이름(`을 모아 has_function_privilege로 본다. 새 호출을 넣거나 권한을 거둔 뒤 다시 돌린다.

### 서버 전체 롤백 계획

11월 초 큰 개편이 끝나면 서버 전체 롤백(날짜 따로 공지, 연출 §15). 보상 「야행(夜行)의 흔적」 세트(능력치 효과 없음, 다른 길 없음): 칭호 「제일야(第一夜)의 증인」·「미완(未完)의 길을 연 자」·「꺼지지 않은 불씨」(신품·분류 레거시, 가진 사람만 목록에 보임), 테두리 「야행(夜行)의 테」·바탕 무늬 「흑야 운문」·낙관 「痕」(등급 「흔적」 legacy), 이름 색 1016 「야행묵금」. 대기 파일 supabase/pending/legacy_yahaeng_set.sql(되돌리는 시험 통과): 1단계 롤백 직전(지금 계정 명단 world_legacy_marks), 2단계 롤백 직후(세트·지급 함수·새 캐릭터 자동 지급 트리거). 그림은 들어가 있음(cosmetics.js fr_yahaeng·pt_yahaeng·sl_heun, chat.js 1016, app.css t-legacy). 레거시 표시: 테두리는 팔각 패에 오른쪽 위가 끊기고 육각 별(legacySvg), 바탕 무늬는 한 폭 장면(SCENE), 낙관은 백문 깨진 도장, 1016은 「痕」 표식과 붉은 붓 획, 칭호는 옻칠 현판(character.js t-card.legacy, 세로 낙관 「흔적」·한자 이름).

## 17. 개발 진행 규칙

개별 기능보다 전체 시스템의 연결 관계를 고려한다.

### 작업 원칙

1. 기존 코드와 DB 구조를 먼저 확인한다.
2. 이미 적용된 기능과 마이그레이션을 중복 적용하지 않는다.
3. 기존 데이터를 삭제하거나 프로젝트를 초기화하지 않는다.
4. 기존 게임 기능을 임의로 제거하지 않는다.
5. DB 변경과 프런트엔드 변경을 구분해 관리한다.
6. 위험이 낮고 되돌릴 수 있는 작업은 묶어서 연속 수행한다.
7. 운영 DB의 위험한 변경, 데이터 삭제, 인증·권한 완화, 유료 서비스 가입과 배포 등은 명시적인 승인 없이 진행하지 않는다.
8. 작업마다 실제 수정 여부와 테스트 결과를 기록한다.
9. 실행하지 않은 테스트를 통과했다고 보고하지 않는다.
10. 화면만 정상적으로 보이는 것을 게임 기능 전체가 정상이라는 근거로 삼지 않는다.
11. 배포할 SQL을 사용자에게 줄 때는 실제 실행용과 함께 「begin; + 파일 + rollback;」으로 감싼 미리 돌려 보기용도 준다. 배포 승인: 건의·패치는 배포 직전(로컬 커밋, SQL 파일 준비·되돌리는 시험)까지만 하고 사용자가 승인하면 배포한다. 작업 브랜치에 올려도 Cloudflare가 배포하므로 승인 전에는 브랜치에도 push하지 않는다. 게임을 막는 오류·보안 문제도 고친 뒤 승인을 묻는다.
11-1. 큰 SQL 배포: SQL Editor에 큰 파일을 붙이면 잘려 중간부터 실행된다. 그래서 Claude가 SQL을 조각내 운영 DB 임시 칸 yh_deploy.buf(n 순번, body; anon·authenticated는 스키마 접근 불가)에 올리고 md5를 저장소 파일과 맞춘다. 사용자는 SQL Editor(왼쪽 >_ 아이콘, Run as postgres)에서 ① `select md5(string_agg(body, '' order by n)) from yh_deploy.buf;` ② `do $$ begin execute (select string_agg(body, '' order by n) from yh_deploy.buf); raise exception 'ROLLBACK_TEST ok'; end $$;`(「ERROR: ROLLBACK_TEST ok」가 성공, 모두 되돌려짐). 승인 뒤 실제 실행은 raise 줄을 뺀 것. 끝나면 바로 `drop schema yh_deploy cascade;`, 작업마다 남긴 임시 표·시험 객체가 없는지 확인해 지운다(world_events는 지우지 않음).
11-2. 되돌리는 시험은 예외를 삼키는 블록(exception when others then null 등)을 쓰지 말고 마지막 줄이 raise exception 'ROLLBACK_TEST …'인지 반드시 확인한다.
11-3. 큰 DO 블록은 `lock table public.world_characters in access exclusive mode;`로 시작한다(pg_cron·접속자와 교착 방지 — share row exclusive는 더 센 잠금으로 올라가다 교착).
12. 패치 번호: 패치노트(world_patch_notes.note_id)와 GM 전체 채팅 공지는 「대규모.소규모.버그」(채팅엔 「#패치노트:7.0.0」 링크). 윗자리를 올리면 아랫자리 0. 대규모·소규모 안의 버그 수정은 따로 세지 않는다. 버그 자리가 9까지 차면 7.2.9b·7.2.9c처럼 글자를 붙인다. 대규모 배포 뒤 자잘한 수정은 GM 채팅에 따로 안 올리고 그 대규모 패치노트 본문 끝에 번호 단 항목(「## 7.7.7b」 등)으로 덧붙인다. 7.7.0은 7.5.0 본문과 따로 한 줄(사용자 요청)이며 7.7.x 수정은 7.7.0 본문 끝에.
12-1. 다시 연 뒤(롤백 후) 번호는 1.0.0부터: 첫째 = 확장팩(퀘스트·지역·직업 추가 등), 둘째 = 그 안의 소규모 패치, 셋째 = 버그·밸런스 수치·편의 기능, 윗자리를 올리면 아랫자리 0. 지난 패치노트(1.0.0~7.x)는 「시험 기간 기록」으로 옮긴다. 다시 연 뒤 일주일은 큰 업데이트 없이 1.0.x만.
12-2. 큰 배포 예고: ① version.json notice에 한 줄(version은 그대로 → 새로고침 안내 없음) → 접속 화면 맨 위 띠(version.js가 2분마다 정적 파일만, DB 요청 없음) ② 5분 전 GM 전체 채팅 예고 ③ 적용 ④ 「적용 끝났습니다 · #패치노트:…」 한 줄, notice 비움.
13. 배포 시기: 수정은 로컬 커밋으로 모아 두고 사용자가 말할 때만 배포(push·SQL 적용·version)한다(2026-11-01 사용자 결정, 아래보다 앞섬). 기본 기준은 커밋 10개 이상이 모이면 배포, 진행을 막는 치명적 버그만 예외로 바로(번호에 알파벳, 예 1.0.0b). 7.7.7 뒤 작은 수정은 7.7.7b·7.7.7c(패치노트 7.7.0 본문 끝 「## 7.7.7b」, GM 공지 없음). 작은 화면 수정은 모아서(배포마다 접속 화면이 새로고침해 서버 부담). 게임을 막는 오류·보안은 바로(승인은 받음). 문서만 바꾸면 version을 올리지 않는다. 배포마다 version.json version을 올리고, SQL 마이그레이션 끝에 world_app_meta db_version을 그 파일 시각으로 올리는 줄. version.js가 이 값과 주요 파일 ETag를 화면 복귀·5분마다 비교해 「새로고침」 안내. 대규모·소규모는 패치노트를 넣고 GM 전체 채팅에 링크.

### 테스트 기준

- 큰 SQL은 먼저 로컬 복제 DB에서: 운영 DB를 읽기 전용 SELECT로만 받아(역할·표·열 권한·정책·함수·트리거·카탈로그 데이터, 큰 표는 최근 3천 줄) 로컬 PostgreSQL 16 `yh`로 만들고 `createdb -T yh yh_test`로 복사본, 마이그레이션을 `-1 -v ON_ERROR_STOP=1`로 돌린 뒤 `set role authenticated` + `request.jwt.claim.sub`로 조사원처럼 함수 호출. 운영은 PostgreSQL 17이라 17 전용 문법은 따로 본다. 복제 스크립트는 세션 작업 공간(scratchpad/replica)이라 세션이 끝나면 사라지므로 새 세션에서 같은 방법으로 다시 만든다(운영 데이터·이메일이 든 덤프는 저장소에 안 올림). 캐릭터 행을 오래 잠그는 시뮬레이션은 복제 DB에서만.
- 연속 클릭과 중복 요청
- 두 플레이어의 동시 행동
- 네트워크 오류와 요청 실패
- 이동 도중 취소와 동승 수락
- 화폐 및 아이템 차감·지급
- 활동 종료와 보상 수령
- 전투불능과 구조
- 모바일과 PC에서의 화면 잘림 및 가로 넘침
- 화면 이동 후 데이터 갱신
- 기존 기능이 UI 개편 후에도 유지되는지 여부

## 18. 우선순위

1. **데이터와 기능 안정성**(최우선): 운임 중복 차감 · 자율 활동 보상 오류 · 이동과 동승 상태 동기화 · 거래와 보상 중복 실행 · 인증 및 권한 검증 · 기존 DB와 게임 기능 보존
2. **전체 UX/UI 개편**: 공통 디자인 시스템 · PC와 모바일 레이아웃 · 핵심 내비게이션 · 캐릭터 상태와 지도 · 탐사·전투·인벤토리·거래 화면 · 채팅과 로그 · 도움말 및 설정
3. **실제 플레이 균형 검증**: 지역별 위험과 보상 · 성장 속도와 상한 · 직업별 효율과 협력 · 경제 인플레이션 · 사건과 단서 조합 · 자율 활동의 효율과 직접 플레이의 가치
4. **배포 검증**(마지막): 실제 계정 로그인·진입 · 핵심 기능 회귀 테스트 · 모바일·PC 화면 · 초대·접근 권한 · 무료 호스팅과 Supabase 사용량 · 최종 배포와 운영 안내

## 19. 변경해서는 안 되는 핵심 방향

- 공용 세계에서 여러 플레이어가 활동한다.
- 지역 탐사와 세부 채집터는 핵심 플레이 방식이다.
- 전투뿐 아니라 채집·제작·조사·생활도 성장 경로다.
- 현실 시간 기반 이동과 자율 활동을 지원한다.
- 화폐 단위는 전이다.
- 파티 동승은 파티원에게만 허용한다.
- 전투 중 이동은 허용하지 않는다.
- 동승 취소와 제안자의 이동 취소는 독립적으로 처리한다.
- 전체·지역·귓속말·세력 채팅을 게임 안에서 제공한다.
- 핵심 모바일 내비게이션은 최대 5개로 구성한다.
- 별도의 방을 생성해야만 게임을 시작할 수 있는 구조로 만들지 않는다.
- 기존 기능을 유지하면서 PC와 모바일의 사용성을 개선한다.
- 무료 또는 최소 비용 운영을 우선한다.

## 20. Claude의 최종 판단 기준

새 기능을 제안하거나 기존 시스템을 바꿀 때 확인한다.

1. 탐사와 발견의 재미를 높이는가?
2. 기존 활동들과 연결되는가?
3. 솔로와 협력 플레이 모두에 의미가 있는가?
4. 장기 성장과 후발주자의 기회를 해치지 않는가?
5. 경제와 보상을 악용할 여지가 없는가?
6. PC와 모바일 모두에서 편리한가?
7. 비용과 유지보수 부담을 불필요하게 늘리지 않는가?
8. 기존 데이터와 기능을 안전하게 보존하는가?

최종 목표는 기능이 많은 웹사이트가 아니라, 플레이어가 세계를 돌아다니고 성장하며 협력하고 오래 이용할 이유가 있는 야행국만의 공용 세계 RPG를 완성하는 것이다.
