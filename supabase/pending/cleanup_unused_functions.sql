-- ============================================================================
-- 쓰지 않는 옛 함수 정리 (초안, 실행하지 않음) — 2026-11-01 읽기 전용 점검으로 만든 목록
--
-- 고른 기준(모두 만족한 것만 넣음):
--   · 화면 코드(assets/js, *.html)에 이름이 없다 (rpc('…')·load('…')·act('…') 등 문자열 전부 grep -w)
--   · 다른 public 함수 본문(pg_proc.prosrc, \m이름\M)에 나오지 않는다 — 이 목록 안의 함수끼리만 부르는 것은 함께 넣음
--     (world_exploration_snapshot ← world_exploration_back, world_region_explore ← world_party_region_explore,
--      world_travel_region ← world_record_mount_passengers)
--   · 트리거·이벤트 트리거·pg_cron 명령·RLS 정책·열 기본값·check 제약·뷰·다른 스키마 함수에 나오지 않는다
--   · tools/·supabase/tests·maintenance·pending·.github에도 없다
--   · 지금 authenticated·anon 실행 권한이 없다(6.1.1·7.2.1·7.3.6에서 거둔 것) — 예외: world_session_check(text)·
--     world_session_claim(text)는 authenticated가 부를 수 있으나 화면은 인자 없는 판만 부른다(session.js)
-- 넣지 않은 것(애매): world_allocate_stat(문서에 「남아 있다」), world_status_snapshot(문서의 만료 정리 목록),
--   world_invite_admin·world_invite_distribute·world_invite_make(운영진이 SQL 편집기에서 손으로 부를 수 있음),
--   world_craft_line·world_housing_item·world_letter_unread·world_wedding_here(7.x 도우미, 앞으로 쓸 수도).
--
-- 권한: DROP은 주인 역할 권한이 있어야 한다. postgres가 주인 역할을 상속하지 않는(USAGE 없음) 아래 열 역할은
--   CLAUDE.md 방식대로 `grant 역할 to postgres with set true` → set role → drop → reset role → `with set false`.
--   (fn_owner_expedition은 이미 set true라 grant/되돌리기 없이 set role만.)
--
-- 미리 돌려 보기: 이 파일을 그대로 돌리면 맨 끝 rollback으로 모두 되돌아간다.
--   실제 실행은 맨 끝 rollback; 을 commit; 으로 바꾼다(사용자 승인 뒤).
--   큰 DO 블록 방식(yh_deploy.buf)으로 돌릴 때는 begin/commit 줄을 빼고 마지막에
--   raise exception 'ROLLBACK_TEST ok' 를 둔다(set role은 execute 'set local role …'로).
-- 돌린 뒤 확인: select oid::regprocedure from pg_proc where pronamespace='public'::regnamespace and proname in (…);
--   select * from pg_auth_members where member='postgres'::regrole and roleid::regrole::text like 'fn_owner_%' and set_option;
-- ============================================================================

begin;
lock table public.world_characters in access exclusive mode;  -- 배포 규칙(교착 방지). 미리 돌려 보기에서도 짧게 잡힘.

-- ── 1) postgres가 이미 상속하는 주인 역할(또는 postgres 자신) ──────────────────
drop function if exists public.world_rpg_action(text,text);                 -- fn_owner_18347  옛 방 기반 행동
drop function if exists public.world_story_choice(text);                    -- fn_owner_18371  옛 분기 사건(2026-10-26 제거)
drop function if exists public.world_combat_snapshot();                     -- fn_owner_18390
drop function if exists public.world_combat_action(text);                   -- fn_owner_18391
drop function if exists public.world_gather_action(text);                   -- fn_owner_18451
drop function if exists public.world_region_combat_action(text);            -- fn_owner_18706
drop function if exists public.world_region_tactic_action(text);            -- fn_owner_18925
drop function if exists public.world_use_recovery_item(text);               -- fn_owner_18989  → world_use_item
drop function if exists public.world_rest_at_spot(text,text);               -- fn_owner_19041  → world_field_rest
drop function if exists public.world_case_investigate(text);                -- fn_owner_19094
drop function if exists public.world_case_combine(text);                    -- fn_owner_19095  → world_story_combine
drop function if exists public.world_expedition_prepare(jsonb);             -- fn_owner_19096
drop function if exists public.world_expedition_retreat(text);              -- fn_owner_19097
drop function if exists public.world_create_character(text);                -- fn_owner_19111  → world_create_character_v2
drop function if exists public.world_mark_character_dead(text);             -- fn_owner_19188
drop function if exists public.world_region_site_explore(text);             -- fn_owner_19255
drop function if exists public.world_exploration_enter(uuid);               -- fn_owner_19603
drop function if exists public.world_exploration_search_spot();             -- fn_owner_19604
drop function if exists public.world_exploration_gather(uuid);              -- fn_owner_19605
drop function if exists public.world_party_loot_deposit(text,integer,integer); -- fn_owner_19658
drop function if exists public.world_exploration_back();                    -- fn_owner_19681
drop function if exists public.world_status_treat(text);                    -- fn_owner_20256
drop function if exists public.world_party_expedition_call();               -- fn_owner_field  옛 「함께 가기」(화면에서 뺌)
drop function if exists public.world_session_check(text);                   -- fn_owner_field  화면은 world_session_check()
drop function if exists public.world_session_claim(text);                   -- fn_owner_field  화면은 world_session_claim()
drop function if exists public.world_party_candidates();                    -- postgres (invoker)
drop function if exists public.world_party_snapshot();                      -- postgres (invoker) → world_party_overview
drop function if exists public.world_public_activity_feed(integer);         -- postgres (invoker)
drop function if exists public.world_public_roster();                       -- postgres (sql)     → world_region_roster
drop function if exists public.world_region_encounter_snapshot();           -- postgres (invoker)
drop function if exists public.world_ride_candidates();                     -- postgres (invoker) 옛 동승
drop function if exists public.world_ride_inbox();                          -- postgres (invoker) 옛 동승
drop function if exists public.world_status_clear(text);                    -- postgres (invoker)
drop function if exists public.world_trade_market_snapshot();               -- postgres (invoker)
-- world_party_region_explore(아래 2)만 부르던 것 (plpgsql 본문 호출은 pg_depend가 없어 순서 무관)
drop function if exists public.world_region_explore(text,text);             -- fn_owner_19301
-- world_record_mount_passengers(아래 2)만 부르던 것
drop function if exists public.world_travel_region(text);                   -- fn_owner_18663  운임 없는 옛 이동

-- ── 2) postgres가 상속하지 않는 주인 역할: set true로 잠깐 열고 되돌림 ──────────
grant fn_owner_18351 to postgres with set true;
set role fn_owner_18351; drop function if exists public.world_move_location(text); reset role;
grant fn_owner_18351 to postgres with set false;

grant fn_owner_18664 to postgres with set true;
set role fn_owner_18664; drop function if exists public.world_region_encounter(text); reset role;
grant fn_owner_18664 to postgres with set false;

grant fn_owner_18915 to postgres with set true;
set role fn_owner_18915; drop function if exists public.world_set_life_profession(text,text); reset role;  -- → _v2
grant fn_owner_18915 to postgres with set false;

grant fn_owner_19208 to postgres with set true;
set role fn_owner_19208; drop function if exists public.world_record_mount_passengers(text,integer); reset role;
grant fn_owner_19208 to postgres with set false;

grant fn_owner_19258 to postgres with set true;
set role fn_owner_19258; drop function if exists public.world_ride_request(uuid,text); reset role;
grant fn_owner_19258 to postgres with set false;

grant fn_owner_19259 to postgres with set true;
set role fn_owner_19259; drop function if exists public.world_ride_respond(uuid,boolean); reset role;
grant fn_owner_19259 to postgres with set false;

grant fn_owner_19305 to postgres with set true;
set role fn_owner_19305; drop function if exists public.world_travel_party_invite(uuid,text); reset role;   -- → _v2
grant fn_owner_19305 to postgres with set false;

grant fn_owner_19306 to postgres with set true;
set role fn_owner_19306; drop function if exists public.world_travel_party_respond(uuid,boolean); reset role; -- → _v2 (본문이 _v2를 부르는 한 줄)
grant fn_owner_19306 to postgres with set false;

grant fn_owner_19602 to postgres with set true;
set role fn_owner_19602; drop function if exists public.world_exploration_snapshot(); reset role;
grant fn_owner_19602 to postgres with set false;

grant fn_owner_19684 to postgres with set true;
set role fn_owner_19684; drop function if exists public.world_party_region_explore(text,text); reset role;
grant fn_owner_19684 to postgres with set false;

-- fn_owner_expedition: postgres가 이미 set true(상속은 없음)
set role fn_owner_expedition;
drop function if exists public.world_expedition_board();
drop function if exists public.world_expedition_finish(boolean);
drop function if exists public.world_expedition_launch(text,integer,text,jsonb);
drop function if exists public.world_exploration_overview();
drop function if exists public.world_set_profile(text,text,text);           -- → world_set_profile_v2
reset role;

-- 함수를 하나도 갖지 않게 된 fn_owner_* 역할(18351·18664·18915·19208·19258·19259·19305·19306·19602·19684 등)은
-- 지우지 않는다(다른 권한·기본 권한이 걸려 있을 수 있음, 따로 점검 뒤 결정).

rollback;  -- 실제 실행 때 commit; 으로 바꾼다
