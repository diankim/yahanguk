# 롤백 · 1.0.0 「두 번째 밤」 순서표

준비해 둔 것(2026-10-31):
- 서버: `supabase/rollback/rollback_1_0_0.sql`(조각 p1~p8 → `build.py`). 복제 DB에서 끝까지 돌리고 새 캐릭터 만들기까지 시험했다.
- 화면: 로컬 브랜치 `rollback-1.0.0`(push하지 않음). 꼬마 동무 1.0.0(wt-pets) 합침, 패치노트 「시험 기간 기록」, 정청 기록고(본부 정청 칸 → 첫째 밤 조사원 기록을 깨진 장부 조각으로, 서버 world_legacy_records), maintenance.json의 scene 지움, version `20261105-1.0.0`.

사용자 결정(2026-10-31): 계정·초대권·운영진 명단만 남기고 캐릭터와 관련된 것은 모두 지운다(친구·차단·모임·서신·제보·첫 의견 보상 포함). 제보 동무 선물은 하지 않는다.

## 이미 예약돼 있는 것(손대지 않아도 됨)
| 때(KST) | 무엇 |
|---|---|
| 11/1 20:00 | 마지막 합동 토벌(반드시 실패) |
| 11/1 23:50 | `yh-last-night-wipe` 토벌대 쓰러뜨림 |
| 11/2 00:00 | `yh-rollback-close` 마지막 토벌 실패 정리 · 봉연 소식 · 게임 문 닫음(anon·authenticated의 public 사용 거둠) |

## 일요일 밤(문 닫은 뒤, 롤백 SQL 전에): 휴면 계정 정리
- 사용자가 명단을 요청하면 뽑는다: 일요일 기준 3일 동안 접속하지 않은 계정(마지막 캐릭터 활동 updated_at·world_active_sessions·auth.users last_sign_in_at 가운데 가장 늦은 때).
- 계정 삭제는 되돌릴 수 없으니 명단을 보여 드리고 승인을 받은 뒤 지운다(auth.users를 지우면 딸린 표는 외래 키로 함께 지워진다). 지운 계정은 레거시 명단·정청 기록고에서도 빠진다.

## 점검 중에 할 일(11/2 00:00 뒤)
1. **문이 닫혔는지 확인**: `select has_schema_privilege('authenticated','public','USAGE');` → false
2. **서버 사양**: 대시보드에서 Small로 올림(사용자, 하루 뒤 Micro로 — 할 일 #117).
3. **롤백 SQL 올리기**: `rollback_1_0_0.sql`을 `yh_deploy.buf`에 올리고 md5를 저장소 파일과 맞춘다(CLAUDE.md 11-1).
4. **되돌리는 시험**: `do $$ begin execute (select string_agg(body,'' order by n) from yh_deploy.buf); raise exception 'ROLLBACK_TEST ok'; end $$;`
5. **적용**: raise 줄 없이 실행. 끝의 확인 블록이 다음을 검사하고, 어긋나면 모두 되돌린다.
   - 캐릭터 0
   - 운영진 명단과 레거시 명단이 남음
   - 11/5 장야 단계 0
6. **적용 뒤 확인**
   - 아래 값이 맞는지 본다.
     - `world_characters` 0
     - `world_legacy_marks` = 롤백 전 캐릭터 수
     - `world_staff` 1
     - `world_pet_species` 38
     - 패치노트 `1.0.0`과 `0-…` 13개
     - `db_version` 20261105000000
   - 예약 작업에서 `yh-long-night`·`yh-last-night-wipe`·`yh-rollback-close`·`yh-invite-day`가 없어야 한다.
   - `world_raids`에 다음 봉연의 그림자 회차가 하나 잡혀야 한다.
7. **화면 배포**: 브랜치 `rollback-1.0.0`을 작업 브랜치에 합쳐 push한다. 들어 있는 것은 동무 38종, 동무 두 자리, 시험 기간 기록, maintenance.json(scene 없음), version 1.0.0이다.
8. **문 열기**: `supabase/maintenance/end.sql`(public 사용 돌려줌, 결과 둘 다 true).
9. **확인**: GM 계정으로 로그인한다. 「아침」 컷씬이 보이고, 캐릭터를 만들면 레거시 세트와 GM 표식이 붙는지 본다.
10. **알림**: GM 전체 채팅에 「두 번째 밤이 열렸습니다 · #패치노트:1.0.0」을 남긴다.
11. **임시 칸 정리**: `drop schema yh_deploy cascade;`

## 다시 연 뒤
- 일주일은 큰 업데이트 없이 1.0.x만 한다(CLAUDE.md 12-1).
- 서버 사양을 Micro로 되돌린다(하루 뒤).
- 공지(0.0.0)는 GM이 패치노트 화면에서 고친다.

## 주의
- `world_staff`의 외래 키를 캐릭터 표에서 계정(auth.users)으로 바꾼다(p2). 그대로 두면 캐릭터를 지울 때 운영진 명단도 지워진다.
- 동무·레거시 원본에 있던 `grant fn_owner_field to postgres … inherit false` 줄은 build.py가 뺀다. 운영 postgres는 이미 그 역할로 행동할 수 있고, 그 줄이 권한을 꺼 이후 패치를 막는다.
- 봉연의 그림자 예약(`world_raid_schedule_next`)은 실행하는 때의 장야 단계를 본다. 11/2 0시 전에 돌리면 11/2 0시로 잡히니 반드시 문이 닫힌 뒤에 돌린다.
