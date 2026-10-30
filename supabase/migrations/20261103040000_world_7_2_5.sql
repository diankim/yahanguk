-- 7.2.5 서버 부담 줄이기(결과는 같고 셈만 바꿈)
-- ① 작은 SQL 함수(주인 역할로 도는 것·search_path가 고정된 것)는 부를 때마다 실행 계획을 새로 짠다(실행 0.1ms에 계획 1~2ms).
--    탐색·토벌·현장·상태판이 자주 부르는 60개를 같은 내용의 plpgsql로 옮겨 계획을 연결마다 한 번만 짜게 한다.
--    #variable_conflict use_column은 SQL 함수처럼 열 이름을 먼저 보게 하고, limit 1은 여러 줄이면 첫 줄을 돌려주던 SQL 함수와 같게 한다.
--    복제 DB에서 조사원 30명의 현장·상태판·전투 능력치·칭호·퀘스트·지도·가방·기술·상태 화면이 모두 같고(현장의 요괴 목록 하나는 정렬 기준이 없던 순서만 다름),
--    탐색 12번·토벌·화면 읽기 묶음이 약 800ms → 340~450ms.
-- ② 날씨·시간대 효과(world_env_total): 7.2.3에서 한 번만 계산하게 했으나 질의가 펼쳐져 환경 표 줄마다 다시 계산하던 것(materialized로 고정)

create or replace function public.world_env_total(p_owner uuid, p_key text)
returns numeric language sql stable security definer set search_path = pg_catalog, public as $f$
  with k as materialized (select public.world_time_phase(now()) tp, public.world_weather_key(public.world_owner_territory(p_owner), now()) wk where p_owner is not null)
  select coalesce(sum(case when (e.effects ->> p_key) ~ '^-?[0-9]+(\.[0-9]+)?$' then (e.effects ->> p_key)::numeric else 0 end), 0)
    from k join public.world_environment_catalog e on e.env_key in (k.tp, k.wk)
$f$;

create or replace function pg_temp.yh_to_plpgsql(p_fn regprocedure) returns text language plpgsql as $f$
declare r record; body text; hdr text; d text; o text;
begin
  select p.*, l.lanname into r from pg_proc p join pg_language l on l.oid = p.prolang where p.oid = p_fn;
  if r.lanname = 'sql' and r.prosrc !~* '^\s*(select|with|\()' then return 'skip notselect ' || p_fn::text; end if;
  if r.lanname <> 'sql' or r.proretset or r.prokind <> 'f' or (select typtype from pg_type where oid = r.prorettype) in ('c','p') then return 'skip ' || p_fn::text; end if;
  body := btrim(r.prosrc, E' \n\t;');
  if body ~ ';' and body !~* '^\s*(select|with)' then return 'skip multi ' || p_fn::text; end if;
  if position(';' in regexp_replace(body, '''[^'']*''', '', 'g')) > 0 then return 'skip semicolon ' || p_fn::text; end if;
  d := pg_get_functiondef(p_fn);
  hdr := substr(d, 1, position('AS $' in d) - 1);
  hdr := replace(hdr, 'LANGUAGE sql', 'LANGUAGE plpgsql');
  o := pg_get_userbyid(r.proowner);
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute hdr || 'AS $yhc$' || E'\n#variable_conflict use_column\nbegin\n  return (select * from (' || body || E'\n) yhq limit 1);\nend\n$yhc$';
  return 'ok ' || p_fn::text;
end $f$;

select p, pg_temp.yh_to_plpgsql(p::regprocedure) from unnest(array[
  'fn_owner_auth_uid()',
  'world_affil_effect(text)',
  'world_bag_count(jsonb)',
  'world_bond_bonus(uuid,text)',
  'world_bond_partner(uuid)',
  'world_bond_self(text)',
  'world_bond_together(uuid)',
  'world_codex_rule_count(uuid,jsonb)',
  'world_enhance_level(uuid,text)',
  'world_env_total(uuid,text)',
  'world_erosion_effect(text)',
  'world_erosion_pct_self()',
  'world_explore_find_pct(uuid)',
  'world_faction_rank_effect(text)',
  'world_faction_rel(text,text)',
  'world_faction_task_count(uuid,jsonb,timestamp with time zone)',
  'world_faction_task_label(jsonb)',
  'world_field_battle_view(uuid)',
  'world_field_survey(uuid,text)',
  'world_gear_self(text)',
  'world_gear_total(uuid,text)',
  'world_gwiheo_open(uuid)',
  'world_gwiryeong_chance(text,jsonb)',
  'world_home_rule_count(uuid,jsonb)',
  'world_housing_owned_kinds(uuid)',
  'world_inv_add(jsonb,text,integer)',
  'world_item_max_durability(text)',
  'world_job_effect(text)',
  'world_kind_mult(text,text,text)',
  'world_level_gap_effect(text)',
  'world_monster_tier(integer)',
  'world_on_island(uuid)',
  'world_owner_territory(uuid)',
  'world_pending_clue_task(uuid,text)',
  'world_quest_chapter_done(uuid,text)',
  'world_quest_done(uuid,text)',
  'world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  'world_quest_task_label(jsonb)',
  'world_raid_rule_count(uuid,jsonb)',
  'world_region_danger(text)',
  'world_skill_has(jsonb,jsonb,text,integer,text,jsonb)',
  'world_skill_line_rank(integer)',
  'world_skill_line_xp(integer)',
  'world_skill_procs(uuid)',
  'world_spar_rule_count(uuid,jsonb)',
  'world_stamina_max(integer)',
  'world_stamina_now(integer,timestamp with time zone,integer)',
  'world_status_effect_total(text)',
  'world_status_self(uuid,text)',
  'world_story_current(uuid)',
  'world_survey_full_count(uuid)',
  'world_time_phase(timestamp with time zone)',
  'world_title_bonus(text)',
  'world_title_bonus_of(uuid,text)',
  'world_title_preset_slots(uuid)',
  'world_tourney_rule_count(uuid,jsonb)',
  'world_weather_key(text,timestamp with time zone)',
  'world_xp_gap_mul(integer)',
  'world_xp_need(integer)',
  'world_yohwa_rule_count(uuid,jsonb)'
]) p;

-- 패치노트: 7.2.0 본문 맨 아래에 덧붙임(공지 없이)
update public.world_patch_notes set body = body || $n$

## 7.2.5
- 서버 부담 줄이기: 탐색·토벌·현장 화면이 부르는 계산 60가지를 다시 짜 같은 일을 약 두 배 빠르게 합니다(결과는 같습니다).
- 휴대폰에서 화면을 껐다 켠 뒤 모임 채팅에 보낸 말이 바로 보이지 않고 한참 뒤에 올라오던 것을 고쳤습니다. 화면으로 돌아오면 그사이 온 모임·파티 말도 바로 채웁니다.
$n$ where note_id = '7.2.0' and position('## 7.2.5' in body) = 0;

update public.world_app_meta set value = '20261103040000' where key = 'db_version';
