# 백년지기 넷 붙이기 — 지시(담당 한 명)

저장소 /home/user/yahanguk. CLAUDE.md를 먼저 읽는다(§3.5f 백년지기, §3.5e 연담, §16, §17 작업 원칙·테스트 기준·화면 점검표). 한국어로 보고. git 커밋·push·운영 DB 쓰기는 하지 않는다. 주석을 넣지 않는다.

## 무엇을

3.6.0 백년지기(supabase/gen_bond/ — plan.md·parse.py·gen.py·engine.sql → migrations/20261124170000_world_3_6_0_kinship.sql)에 연담 새 인물 넷을 더한다. 넷의 연담 엔진은 이미 migrations/20261125070000_world_3_7_0_yeondam4.sql(생성기 supabase/gen_yeondam2/)에 있다.

| 키 | 인물 | 정표 | 답례(item_id, 우수품이 있으면 _hq) |
|---|---|---|---|
| mogaram | 기록관 모가람 | 대나무 서표 | moss_porridge (월광 이끼죽) |
| yeonseohui | 서기관 연서희 | 무명 약낭 | herb_rice (야령초 나물밥) |
| kangducheol | 교관 강두철 | 연무 토시 | cod_soup (대구탕) |
| yeoseotjjae | 채무 추적자 여섯째 | 맡긴 이름패 | dark_eye_drops (어둠 눈 약) |

item_id는 복제 DB에서 이름으로 확인한다(위 id가 틀리면 맞는 id를 찾아 쓰고 보고). 기존 11명은 reward가 기본 id(engine.sql npcs)이니 같은 꼴로.

대사 원고(사용자 승인본 — 문장은 바꾸지 않는다): supabase/gen_bond/talk_mogaram.md·talk_yeonseohui.md·talk_kangducheol.md·talk_yeoseotjjae.md(키는 talk_hanseol.md와 같음), 정인 상호작용 묶음 mates_<키>.md 넷((가) 새 인물이 다른 인물을 말하는 줄·(나) 기존 인물이 새 인물을 말하는 줄 — talk_mates.md의 mate_ 키 꼴로 합쳐야 함, 파일 끝 메모 줄·「새로 정한 설정」 표 같은 대사 아닌 부분은 넣지 않음). parse.py가 이 파일들을 읽게 고치고 talk.json을 다시 만든다.

## 할 일

1. 새 마이그레이션 supabase/migrations/20261125080000_world_3_7_0_kin4.sql (gen_bond/gen.py에 새 묶음을 만드는 방식을 더하거나 별도 build — 3.6.0 마이그레이션을 다시 만들지 않는다): world_kin_rules().npcs에 넷(token·reward) 더하기, world_kin_lines에 넷의 대사·정인 상호작용 줄 넣기(기존 행은 그대로, 넣는 방식은 3.6.0 엔진 그대로), 끝에 world_app_meta db_version 20261125080000. 패치노트는 새 행을 만들지 말고 3.7.0 본문에 한 줄 덧붙이는 update(「네 사람과도 백년지기를 맺을 수 있습니다」 결, 스포일러 없이 — supabase/gen_yeondam2/patch_note.sql은 건드리지 말고 이 마이그레이션 안에서 update).
2. 엔진이 연담 kind combat 인물(world_regular_rules().npcs[].kind)에서도 그대로 도는지 확인: world_kin_make 조건(rg_<키>_5 마침), world_kin_gift의 「그 인물 분야 물품이면 답례」 판정 — 싸움 쪽 넷은 제작·채집 분야가 없으니 분야 물품 판정이 어떻게 되는지 보고, 넷에게 맞는 「분야 물품」을 연담 물품 주문과 같은 목록(world_regular_cpool 갈래: 분석 요괴 전리품 재료·막기 방어구·응급 처치 체력 회복약·여섯째 지금 무기 갈래 소모품)으로 판정하게 고치는 것이 자연스러우면 그렇게 하고 근거를 보고(규칙은 한 곳 — 판정 함수 하나).
3. 별채 걸어 다니는 그림: assets/js/housing/npcs.js에 넷이 이미 있다(NPC_LOOKS mogaram·yeonseohui·kangducheol·yeoseotjjae) — 키가 맞는지만 확인.
4. 정표 아이콘 assets/js/kintoken.js KIN_TOKENS에 넷을 더한다 — 기존 열한 개와 같은 꼴(24×24 viewBox, stroke 1.6, 선 그림 한 path). 넣기 전에 미리보기 그림(기존 열한 개와 새 넷을 한 장에, 크게)을 /tmp/claude-0/-home-user-yahanguk/80621dde-8946-5cd5-b559-a325658108d7/scratchpad/kin4_tokens.png 로 찍어 둔다(사용자 확인용 — 넣은 채로 두되 보고에 「사용자 확인 전」으로 적음). 정표 뜻: 대나무 서표(책갈피, 대 마디·끈), 무명 약낭(작은 주머니·끈·약초 잎), 연무 토시(팔 토시·매듭 끈), 맡긴 이름패(작은 패에 끈, 뒷면을 검은 천이 덮음 — 천 자락이 보이게).
5. tools/gamedata/gen.py를 복제 DB로 다시 돌려 gamedata.js(kin 넷·답례 이름) 갱신. guide.js 「백년지기」 표가 넷을 보이는지, CLAUDE.md §3.5f를 지금 규칙대로 고침(인물 열다섯·싸움 쪽 분야 물품 판정 등 — 내력은 쓰지 않음).

## 시험

- 복제 DB: `bash /var/tmp/yh_pgstart.sh`(꺼져 있으면), DSN postgresql://postgres@/yh_y4c?host=/var/tmp/yhpg&port=5499 — 이미 20261125070000까지 들어가 있다(망가뜨렸으면 `createdb -T yh_bj2` 후 그 마이그레이션부터 다시). 새 마이그레이션 적용 → 조사원처럼(set role authenticated + request.jwt.claim.sub, rg_<키>_5 진행 행·위치를 트랜잭션 안에서 꾸며) 넷 각각 view·make·talk(여러 번 — 같은 줄 되풀이 없는지)·gift(분야 물품·아닌 물품)·wear·break·greet, 정인 상호작용 줄이 실제로 골라지는지. 되돌리는 시험(raise exception 'ROLLBACK_TEST …')·`set local role fn_owner_…` 호출·precheck.py(--dsn) 0건.
- 화면: 로컬 정적 서버 + Playwright(시험 계정 YH_TEST_ID·YH_TEST_PW — 값 출력·기록 금지, 운영 데이터를 바꾸는 행동 금지; 필요한 RPC 응답은 복제 DB 값으로 page.route 끼워 넣기)로 연담 창 아래 백년지기 칸(넷 중 하나)·가방 정표 칸·도움말 표를 PC·휴대폰으로 찍는다. 못 본 화면은 「화면 직접 확인 못 함」.

## 보고

바꾼 파일(git diff --stat)·마이그레이션 경로·크기, 시험 항목별 실제 결과, 아이콘 미리보기 경로, 정한 것과 물을 것(특히 싸움 쪽 넷의 「분야 물품」 판정).
