-- 7.7.7k — 롤백 전 서버 정리(2026-11-01, 사용자 요청: 안 쓰는 함수·어색한 문장·서버 부담 점검)
-- ① 아무 데서도 부르지 않는 옛 함수 51개 지우기(화면 코드·다른 함수 본문·트리거·예약 작업·정책·기본값·뷰를 모두 찾아본 것만 —
--    목록과 고른 기준은 supabase/pending/cleanup_unused_functions.sql 머리말). 되돌리는 시험: 51개 모두 지워지고 인자 없는 접속 함수 둘만 남음.
-- ② 서버 문장 다듬기: 「기믹」 → 「수법」, 조사 박아 둔 곳 → 「을(를)」, 숫자 뒤 「으로」 없애기, 별채 가구 내부 코드 노출 빼기,
--    노정패 얻는 곳 안내(원정 귀환은 주지 않음), 장착 조건 문구.
-- ③ 보안: 기여도 계산 함수 둘에 search_path 고정, world_raid_snapshot_core는 조사원이 직접 못 부르게(world_raid_snapshot만 부름).
-- ④ 예약 작업 기록(cron.job_run_details)을 매일 정리(7일 지난 것) — 지금은 아무도 지우지 않아 쌓이기만 한다.

lock table public.world_characters in access exclusive mode;

-- ── ① 쓰지 않는 함수 ───────────────────────────────
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


-- ── ② 서버 문장 ───────────────────────────────
create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := replace(pg_get_functiondef(p_fn::regprocedure), E'\r\n', E'\n');
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번): %', p_fn, p_n, k, left(p_old, 60); end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

select pg_temp.yh_patch('public.world_gimmick_tip(text)', '가벼운 기믹입니다.', '가벼운 수법입니다.');
select pg_temp.yh_patch('public.world_battle_action(text,text)', $q$, '기믹') || '을(를) 미리 끊었다.'$q$, $q$, '그 수법') || '을(를) 미리 끊었다.'$q$);
select pg_temp.yh_patch('public.world_cosmetic_equip(text,text)', $q$'」을 달았습니다.'$q$, $q$'」을(를) 달았습니다.'$q$);
select pg_temp.yh_patch('public.world_faction_request_claim(text)', $q$'」를 마쳤습니다. 평판 +'$q$, $q$'」을(를) 마쳤습니다. 평판 +'$q$);
select pg_temp.yh_patch('public.world_faction_trial()', $q$foe || '(Lv' || flv || ')를 내보낸다. 기세 '$q$, $q$foe || '을(를) 내보낸다(Lv' || flv || '). 기세 '$q$);
select pg_temp.yh_patch('public.world_faction_vault_buy(text,integer)', $q$nm || ' ×' || p_qty || '을(를) 공훈 ' || cost || '으로 받았습니다.'$q$, $q$nm || '을(를) ' || p_qty || '개 받았습니다(공훈 ' || cost || ').'$q$);
select pg_temp.yh_patch('public.world_faction_vault_buy(text,integer)', $q$nm || '을(를) 공훈 ' || cost || '으로 받았습니다.'$q$, $q$nm || '을(를) 받았습니다(공훈 ' || cost || ').'$q$);
select pg_temp.yh_patch('public.world_housing_save(uuid,jsonb)', $q$raise exception '바닥에 놓을 수 없는 물건입니다: %', coalesce(k, '?');$q$, $q$raise exception '바닥에 놓을 수 없는 물건이 섞여 있습니다.';$q$);
select pg_temp.yh_patch('public.world_housing_save(uuid,jsonb)', $q$raise exception '벽에 걸 수 없는 물건입니다: %', coalesce(k, '?');$q$, $q$raise exception '벽에 걸 수 없는 물건이 섞여 있습니다.';$q$);
select pg_temp.yh_patch('public.world_charge_mount_fare()', '토벌 승리·이야기·의뢰·원정 귀환으로 얻을 수 있습니다.', '토벌 승리·탐색·채집·이야기·의뢰로 얻을 수 있습니다.');
select pg_temp.yh_patch('public.world_equip_item(text)', $q$'레벨 조건 미달: 필요 레벨 %'$q$, $q$'레벨이 모자랍니다: 레벨 % 이상이어야 합니다.'$q$);
select pg_temp.yh_patch('public.world_equip_item(text)', $q$'능력치 조건 미달: 가장 높은 능력치 % 필요(장신구는 어느 능력치든 됩니다)'$q$, $q$'능력치가 모자랍니다: 가장 높은 능력치가 % 이상이어야 합니다(장신구는 어느 능력치든 됩니다).'$q$);
select pg_temp.yh_patch('public.world_equip_item(text)', $q$'능력치 조건 미달: % % 필요'$q$, $q$'능력치가 모자랍니다: % % 이상이어야 합니다.'$q$);
select pg_temp.yh_patch('public.world_equip_item(text)', $q$'숙련 조건 미달: % %단계 필요(지금 %단계)'$q$, $q$'숙련이 모자랍니다: % %단계 이상이어야 합니다(지금 %단계).'$q$);

-- ── ③ 보안 ───────────────────────────────
alter function public.world_contrib_score(jsonb, numeric, numeric) set search_path to 'pg_catalog', 'public';
alter function public.world_raid_score(text, integer, jsonb, jsonb, numeric, numeric) set search_path to 'pg_catalog', 'public';
set role fn_owner_field;
revoke execute on function public.world_raid_snapshot_core(uuid) from public, anon, authenticated;
reset role;

-- ── ④ 예약 작업 기록 정리 ───────────────────────────────
select pg_temp.yh_patch('public.world_housekeeping()', $q$  delete from public.world_notifications where read_at is not null and read_at < now() - interval '14 days';$q$,
  $q$  delete from public.world_notifications where read_at is not null and read_at < now() - interval '14 days';
  delete from cron.job_run_details where end_time < now() - interval '7 days';$q$);

update public.world_patch_notes set body = body || $N$
## 7.7.7k
- 롤백 전 정리: 쓰지 않는 옛 서버 함수와 화면 코드·꾸밈 규칙을 걷어 냈습니다. 몇몇 안내 문구(조사 표기·「수법」·장착 조건·노정패 얻는 곳)를 다듬었습니다.
$N$ where note_id = '7.7.0' and position('## 7.7.7k' in body) = 0;

update public.world_app_meta set value = '20261104203800' where key = 'db_version';
