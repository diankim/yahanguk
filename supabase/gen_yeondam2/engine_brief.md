# 연담 넷 — 엔진·화면 지시(담당 한 명)

저장소 /home/user/yahanguk. CLAUDE.md 전체를 먼저 읽는다(특히 §3.5e 연담, §6 기술 계열, §10 퀘스트·대본 규칙, §16 기술 원칙·요청 줄이기·권한, §17 작업 원칙·테스트 기준·화면 점검표). 한국어로 보고. git 커밋·push·운영 DB 쓰기는 하지 않는다(운영 DB는 읽기 SELECT만, 꼭 필요할 때만). 주석을 넣지 않는다.

## 무엇을

연담에 새 인물 넷을 더한다. 기획은 supabase/gen_yeondam2/plan.md(§1·§2·§4·§5), 대본은 supabase/gen_yeondam2/script_mogaram.md·script_yeonseohui.md·script_kangducheol.md·script_yeoseotjjae.md(사용자 승인본 — 문장은 바꾸지 않는다). 지난 연담 묶음(3.3.0)의 생성기·엔진이 본보기: supabase/gen_330/(data.py·gen.py·engine.sql·build.py·patch_note.sql) → migrations/20261122000000_world_3_3_0_yeondam.sql. 그 뒤 연담을 고친 마이그레이션도 찾아 읽는다(grep world_regular_ supabase/migrations).

| 키 | 이름 | 분야(기술 계열) | 곳(region) | 1편 열림 | 칭호 | 5편 기념품 |
|---|---|---|---|---|---|---|
| mogaram | 기록관 모가람 | 분석 analysis | 본부 객사 hq_dorm | mdq_1 마침 | 기록관의 대필 | 가구 「식은 보리차 상」 hf_rg_mogaram_tea (furniture.js FUR rg_mogaram_tea 이미 있음) |
| yeonseohui | 서기관 연서희 | 응급 처치 first_aid | 야행국 본부 정청 hq_yard | mq_nine_gates 마침 | 서희가 기다리는 사람 | 가구 「서당 약상자」 hf_rg_yeonseohui_kit (FUR rg_yeonseohui_kit) |
| kangducheol | 교관 강두철 | 막기 guarding | 철벽 고찰 iron_monastery | sq_hq_training_1 마침(퀘스트는 Lv9 — 철벽 고찰 출입 레벨) | 연무청 기둥에 새긴 이름 | 가구 「수련 목인」 hf_rg_kangducheol_dummy (FUR rg_kangducheol_dummy) |
| yeoseotjjae | 채무 추적자 여섯째 | 전투 — 지금 직업의 계열(world_job_line) | 십삼문 암시장 hidden_bazaar | mdq_17 마침 | 숫자 대신 부른 이름 | 장신구 「검은 두건」 of_acc_rg_yeoseotjjae_veil (tools/avatar_art/tops_art.py ACC rg_yeoseotjjae_veil 이미 있음 — avatar.js·parts.json도 생성돼 있음, world_avatar_parts·옷 물품 행이 필요한지 기존 rg_ 장신구 본보기로 확인) |

말하는 이 키: 모가람 night_office:mo · 연서희 q:m_yeon · 강두철 night_office:kang · 여섯째 black_lotus:six · 구슬 black_lotus:guseul · 수련생 q:sx_ep_trainee · 아이(기존 이름표 찾기) · 좌판 아낙(새로 — 3.0/3.1 생성기의 새 인물 넣는 방식을 따름). 대본의 갈래 줄 `[정통파 1~4]`·`[정통파 5]`·`[정통파 밖]`·`[정통파]`·`[흑련]`·`[흑련 밖]`과 `{직업:…}`·`{이름}`·`{등급}`을 기존 생성기 문법대로 옮긴다(gen_310·gen_330 gen.py를 읽어 같은 꼴로).

## 서버

1. 규칙 world_regular_rules() npcs에 넷 더함(key·line·region·open·title — 여섯째 line은 「지금 직업 계열」을 뜻하는 값, 엔진이 world_job_line으로 풀게). 주문 갈래 규칙을 같은 규칙 함수 한 곳에: 행동 act(분석 「집중」 8 · 막기 「방어」 8 · 응급 처치 「회복품·처치」 5 · 여섯째 「이긴 토벌」 8), 처치 kill(〈갈래〉 요괴 5), 물품 item(분석: 요괴 전리품 재료 3 / 막기: 방어구(몸·관모·신) 제작품 1 / 응급 처치: 체력 회복품 3 / 여섯째: 내 무기 갈래 소모품 3 — 원거리면 내 무기 탄, 그 밖은 영력·기력 회복약).
2. 새 넷은 하루 주문 셋을 이 세 갈래에서 고름(지금처럼 md5(날짜·인물·사람) 결정적). 처치 주문의 〈갈래〉는 내가 갈 수 있는(내 레벨 이하·열린 지역) 바깥 지역에 나오는 13갈래 가운데서.
3. 셈: 한국 시각 그날 0시부터의 현장 토벌 승리 기록(혼자·파티 토벌)만. 원정·비무·보스(봉연·결전·귀허류)·비장고 파수꾼 제외 여부는 실제 world_events 종류와 payload를 운영과 같은 복제 DB에서 확인하고 정한다(비장고 파수꾼은 파티 토벌 엔진이라 들어가도 됨 — 판단 근거를 보고). 행동 수는 승리 기록 payload.acts(analysis·guarding·first_aid), 갈래는 요괴의 kind. 한 번의 토벌이 여러 주문에 함께 셈. 주문 글에 「탐사에서」를 붙임.
4. view: 행동·처치 주문은 진행 n/목표를 보여 주고, 다 차면 그 인물 곳(안전지대)에서 「보고」로 world_regular_give가 받음(물품 없이). 물품 주문은 지금 그대로. 같은 주문 하루 한 번, 하루 납품 모든 연담 합쳐 6번, 친밀도 +10(우수품 +15), 경험치 = 그 계열 다음 단계 필요 경험의 25%(최소 30) — 지금 규칙 그대로(여섯째는 지금 직업 계열에).
5. 전: 물품 주문은 지금 식(시세×수량×0.3+30), 행동·처치 주문은 그 인물 물품 주문 목록(같은 단계) 평균 시세×3×0.3+30.
6. 한 곳에 둘: world_regular_here가 목록을 주게(본부 정청 희수·연서희, 십삼문 월하·여섯째, 철벽 고찰 여운비·강두철). 화면·brief·here를 쓰는 모든 곳을 찾아 맞춘다(view(p_npc) 비우면 지금 곳의 첫 인물).
7. 퀘스트 20편 rg_<키>_1~5: 1편 open은 위 표, 2~5편 open_req {regular, stage}. 보상·경험치 공식은 3.3.0과 같게(Lv50은 경험치 0 등 — gen_330 gen.py 그대로). 5편 reward.title = 칭호 키. 칭호 넷(분류 「연담」, 효과 없음) + 연담 칭호에 「열다섯 연담」 하나 더(「열한 연담」은 그대로 둠 — 기존 rg_all 규칙을 확인해 새 칭호 키로).
8. 기념품 물품 넷(거래 불가, 5편 보상) — 3.3.0 rg_ 기념품 본보기대로.
9. 창고: 연담 인물 이야기 5편을 마칠 때마다 +1 — 지금 열한 명 → 열다섯 명(world_storage_rules·capacity와 CLAUDE.md 문구).
10. 여섯째 성별 서술 고치기 supabase/gen_yeondam2/fix_six_gender.sql 을 이 마이그레이션에 그대로 넣는다(복제 DB에서 시험됨).
11. 초상 화첩 cast·백년지기(kin)는 이번 일에서 하지 않는다(다른 담당).
12. 마이그레이션 하나: supabase/migrations/20261125070000_world_3_7_0_yeondam4.sql (생성기 supabase/gen_yeondam2/gen.py·engine.sql·build.py — gen_330처럼). 끝에 world_quest_label_refresh()가 필요하면 넣고, world_app_meta db_version을 20261125070000으로. 패치노트 3.7.0(새 note_id '3.7.0', 「연담에 네 사람이 더해졌습니다」 결 — 확률·숨은 수치 없이 규칙만, 스포일러 없이; 지도 십삼문 물길 고침 한 줄도 넣을 자리를 비워 둠) — gen_330/patch_note.sql 본보기.

## 화면

- views/regular.js: 주문 카드에 행동·처치 갈래(진행 막대 n/목표, 다 차면 「보고」 단추, 「탐사에서」 문구), 한 곳에 인물 둘이면 고르기. home.js 현장 연담 칸: 인물마다 단추. 일지 › 의뢰 연담 칸(journal.js)에 넷. guide.js 「연담」 도움말. rules.js REGULAR 문구. changes.js(토벌 승리 뒤 연담 진행이 바뀌니 캐시 버리기를 changes.js 한 표에 — 요청이 늘지 않게 기존 패턴 확인).
- tools/gamedata/gen.py로 gamedata.js 다시 만들기(--dsn 복제 DB).
- 화면 점검표(CLAUDE.md §17 「화면을 서버와 같은 무게로」) 줄마다. 로컬 정적 서버 + Playwright로 연담 창·현장 칸을 열어 보고(로그인이 필요하면 시험 계정 YH_TEST_ID·YH_TEST_PW — 값을 출력·기록하지 말 것, 운영 데이터를 바꾸는 행동 금지), 못 본 화면은 「화면 직접 확인 못 함」으로 적는다. 스크린샷은 /tmp/claude-0/-home-user-yahanguk/80621dde-8946-5cd5-b559-a325658108d7/scratchpad/ 에.

## 시험

- 복제 DB: PostgreSQL 16 `/var/tmp/yhpg` 포트 5499(꺼져 있으면 `bash /var/tmp/yh_pgstart.sh`). 최신 DB는 yh_bj2(운영 db_version 20261125060000까지). `createdb -h /var/tmp/yhpg -p 5499 -U postgres -T yh_bj2 yh_y4` 로 복사해 마이그레이션을 `psql -1 -v ON_ERROR_STOP=1 -f` 로 돌리고, `set role authenticated` + `set request.jwt.claim.sub` 로 조사원처럼 불러 본다: 주문 고르기(넷 × 여러 날짜), 행동·처치 셈(토벌 승리 기록을 넣어 보고 되돌리기), give(물품·행동·처치), here 목록, 퀘스트 받기·보고, 칭호·기념품·창고 칸.
- 운영처럼 함수 주인 역할(fn_owner_*) 권한: `set local role fn_owner_…` 로도 불러 보기(CLAUDE.md 권한 절).
- 되돌리는 시험은 마지막 줄 raise exception 'ROLLBACK_TEST …'.
- tools/check/precheck.py (--dsn 복제 DB) 0건, node --check, eslint.
- CLAUDE.md §3.5e 연담 절과 §7 창고 절을 새 규칙에 맞게 고친다(지금 규칙과 그 자리만 — 내력은 쓰지 않음).

## 보고

바꾼 파일 목록(git diff --stat), 마이그레이션 경로·크기, 복제 DB 시험 항목별 결과(실제 돌린 것만), 화면에서 직접 본 것·못 본 것, 정한 것(예: 비장고 파수꾼 셈 여부·〈갈래〉 고르는 법)과 사용자에게 물을 것.
