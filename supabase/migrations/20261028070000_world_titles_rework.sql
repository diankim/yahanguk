-- 칭호 개편: 등급과 효과 차별화, 진행 게이지
-- 1) 등급(world_title_catalog.grade): 1 일반 · 2 고급 · 3 희귀 · 4 영웅 · 5 전설. 얻기 어려울수록 높다(16·36·34·19·6개).
-- 2) 효과: 등급이 높을수록 크고 갈래가 많다(일반 1가지 · 희귀 2가지 · 전설 3가지, 둘째·셋째 효과는 한·두 등급 아래 크기).
--    지금까지 칭호에서 쓰던 주는 피해·받는 피해·단서·희귀품·채집·제작·이동·낚시에 더해
--    치명타·회피·달아나기·방어·이목(전투 능력치, world_combat_stats)과 회복량·침식·정신 손실·요괴 조우(상태 효과)도 칭호로 받는다.
--    이목은 앞에서 막는 칭호(검의 길·장사·철골·생명의 은인 등)는 높이고, 몰래 다니는 칭호(야행자·고요한 밤·등잔 밑)는 낮춘다.
--    전투 능력치의 칭호 효과는 그 캐릭터의 칭호로 계산한다(파티 합동 전투에서 동료 칭호가 섞이지 않게, world_title_bonus_of).
-- 3) 이야기 6~9장 칭호 4개를 더한다(칭호 107 → 111개). 마지막 장 칭호의 조건 문구를 「10장」으로 고친다.
-- 4) 진행 게이지: world_title_rule_progress가 조건마다 지금 값·목표를 돌려주고, 칭호 화면(world_title_snapshot.progress)이 숨김이 아닌 못 얻은 칭호에 보여 준다.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 결과가 같다.

alter table public.world_title_catalog add column if not exists grade int not null default 1;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'world_title_catalog_grade_chk') then
    alter table public.world_title_catalog add constraint world_title_catalog_grade_chk check (grade between 1 and 5);
  end if;
end $$;

-- 이야기 6~9장 칭호
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category)
select v.k, v.n, coalesce((select icon from public.world_title_catalog where title_key = 'ch5_done'), 'scroll'), v.d, v.c, '{}'::jsonb, true, false, v.r::jsonb,
       (select sort from public.world_title_catalog where title_key = 'ch5_done') + v.s, '이야기'
  from (values
    ('ch_eclipse', '월식을 본 자', '먹힌 달 아래에서 두 번째 문을 보았다.', '6장 「월식의 문」 해결', '{"ev": "story", "p": {"chapter_id": "eclipse_gate"}}', 1),
    ('ch_sunken', '물 밑의 등불지기', '물 밑의 문을 비추던 등불을 따라갔다.', '7장 「물 밑의 등불」 해결', '{"ev": "story", "p": {"chapter_id": "sunken_lantern"}}', 2),
    ('ch_ash', '재의 바다를 건넌 자', '꺼져 가는 등대 사이를 건넜다.', '8장 「재의 바다」 해결', '{"ev": "story", "p": {"chapter_id": "ash_sea"}}', 3),
    ('ch_lamp', '등잔 밑을 밝힌 자', '가장 가까운 곳의 어둠을 밝혔다.', '9장 「등잔 밑」 해결', '{"ev": "story", "p": {"chapter_id": "lamp_shadow"}}', 4)
  ) as v(k, n, d, c, r, s)
on conflict (title_key) do nothing;
update public.world_title_catalog set condition_text = '10장 「구중 봉연」 해결' where title_key = 'ch6_done' and condition_text = '6장 해결';
update public.world_title_catalog set sort = (select sort from public.world_title_catalog where title_key = 'ch5_done') + 5 where title_key = 'ch6_done' and sort = (select sort from public.world_title_catalog where title_key = 'ch5_done') + 1;
update public.world_title_catalog set condition_text = '레벨 30·칭호 40개·10장 해결' where title_key = 'legend' and condition_text like '%6장 해결%';

-- 등급과 효과
drop table if exists pg_temp.title_fix;
create temporary table title_fix(title_key text primary key, grade int, bonus jsonb);
insert into title_fix values
  ('all_regions', 4, '{"travel_time_pct": -9, "encounter_pct": -8}'::jsonb),
  ('all_rounder', 3, '{"combat_damage_pct": 3, "gather_qty_pct": 3, "craft_quality": 1}'::jsonb),
  ('armored_breaker', 3, '{"melee_pct": 5, "combat_damage_pct": 2}'::jsonb),
  ('artisan_apprentice', 1, '{"craft_quality": 1}'::jsonb),
  ('artisan_master', 2, '{"craft_quality": 2, "gather_qty_pct": 2}'::jsonb),
  ('big_catch', 3, '{"fish_size_pct": 8}'::jsonb),
  ('blade_path', 2, '{"melee_pct": 3, "presence": 5}'::jsonb),
  ('blood_mist_blade', 4, '{"melee_pct": 7, "crit_pct": 3}'::jsonb),
  ('bow_path', 2, '{"ranged_pct": 3, "evasion_pct": 1}'::jsonb),
  ('cache_hunter', 3, '{"rare_loot_pct": 3}'::jsonb),
  ('case_reader', 1, '{"clue_bonus_pct": 2}'::jsonb),
  ('ch1_done', 1, '{"clue_bonus_pct": 2}'::jsonb),
  ('ch2_done', 2, '{"clue_bonus_pct": 4, "mental_loss_pct": -3}'::jsonb),
  ('ch3_done', 2, '{"combat_damage_pct": 2, "flee_pct": 3}'::jsonb),
  ('ch4_done', 3, '{"incoming_damage_pct": -3, "defense": 3}'::jsonb),
  ('ch5_done', 3, '{"rare_loot_pct": 3, "mental_loss_pct": -5}'::jsonb),
  ('ch6_done', 5, '{"combat_damage_pct": 7, "incoming_damage_pct": -5, "erosion_pct": -8}'::jsonb),
  ('ch_ash', 4, '{"rare_loot_pct": 5, "erosion_pct": -8}'::jsonb),
  ('ch_eclipse', 3, '{"crit_pct": 3, "combat_damage_pct": 2}'::jsonb),
  ('ch_lamp', 4, '{"clue_bonus_pct": 9, "presence": -15}'::jsonb),
  ('ch_sunken', 4, '{"healing_pct": 12, "travel_time_pct": -6}'::jsonb),
  ('cleansed', 3, '{"erosion_pct": -8, "mental_loss_pct": -5}'::jsonb),
  ('clear_sky', 1, '{"travel_time_pct": -2}'::jsonb),
  ('commission_10', 2, '{"rare_loot_pct": 2}'::jsonb),
  ('commission_50', 3, '{"rare_loot_pct": 3, "clue_bonus_pct": 4}'::jsonb),
  ('coward', 1, '{"flee_pct": 3}'::jsonb),
  ('craft_200', 4, '{"craft_quality": 6, "gather_qty_pct": 5}'::jsonb),
  ('craft_q90', 3, '{"craft_quality": 4}'::jsonb),
  ('dawn_gatherer', 2, '{"gather_qty_pct": 3, "healing_pct": 3}'::jsonb),
  ('deep_walker', 3, '{"rare_loot_pct": 3, "erosion_pct": -5}'::jsonb),
  ('dragon_koi', 5, '{"fish_rare_pct": 10, "fish_size_pct": 10}'::jsonb),
  ('dusk_seeker', 3, '{"clue_bonus_pct": 6, "rare_loot_pct": 2}'::jsonb),
  ('elite_50', 4, '{"crit_pct": 4, "combat_damage_pct": 3}'::jsonb),
  ('elite_hunter', 2, '{"crit_pct": 2}'::jsonb),
  ('eroded', 3, '{"magic_pct": 5, "presence": 10}'::jsonb),
  ('expedition_vet', 3, '{"gather_qty_pct": 5, "mental_loss_pct": -5}'::jsonb),
  ('fallen', 1, '{"healing_pct": 3}'::jsonb),
  ('fallen_10', 3, '{"healing_pct": 8, "incoming_damage_pct": -2}'::jsonb),
  ('first_bite', 1, '{"fish_bite_pct": 3}'::jsonb),
  ('first_footsteps', 1, '{"travel_time_pct": -2}'::jsonb),
  ('fish_codex_master', 5, '{"fish_rare_pct": 10, "gather_qty_pct": 7, "fish_size_pct": 8}'::jsonb),
  ('fog_walker', 2, '{"clue_bonus_pct": 4, "evasion_pct": 1}'::jsonb),
  ('gather_100', 2, '{"gather_qty_pct": 3}'::jsonb),
  ('gather_500', 4, '{"gather_qty_pct": 7, "rare_loot_pct": 3}'::jsonb),
  ('ghost_exorcist', 3, '{"magic_pct": 5, "erosion_pct": -5}'::jsonb),
  ('guardian_25', 5, '{"combat_damage_pct": 7, "incoming_damage_pct": -5, "crit_pct": 3}'::jsonb),
  ('guardian_breaker', 2, '{"combat_damage_pct": 2, "defense": 2}'::jsonb),
  ('hazard_survivor', 2, '{"incoming_damage_pct": -2, "evasion_pct": 1}'::jsonb),
  ('hoarder', 3, '{"gather_qty_pct": 5}'::jsonb),
  ('hundred_li', 2, '{"travel_time_pct": -4, "flee_pct": 3}'::jsonb),
  ('iron_will', 4, '{"mental_loss_pct": -12, "erosion_pct": -8}'::jsonb),
  ('keen', 4, '{"crit_pct": 4, "clue_bonus_pct": 6}'::jsonb),
  ('legend', 5, '{"combat_damage_pct": 7, "rare_loot_pct": 5, "clue_bonus_pct": 6}'::jsonb),
  ('long_fight', 3, '{"defense": 5, "incoming_damage_pct": -2}'::jsonb),
  ('lv10', 2, '{"incoming_damage_pct": -2, "healing_pct": 3}'::jsonb),
  ('lv20', 3, '{"combat_damage_pct": 3, "defense": 3}'::jsonb),
  ('lv30', 4, '{"combat_damage_pct": 5, "incoming_damage_pct": -3, "healing_pct": 5}'::jsonb),
  ('master_gatherer', 1, '{"gather_qty_pct": 2}'::jsonb),
  ('mission_runner', 3, '{"clue_bonus_pct": 6, "craft_quality": 2}'::jsonb),
  ('monster_slayer', 1, '{"combat_damage_pct": 1}'::jsonb),
  ('mourner', 1, '{"erosion_pct": -3}'::jsonb),
  ('mourner_20', 3, '{"erosion_pct": -8, "clue_bonus_pct": 4}'::jsonb),
  ('night_angler', 2, '{"fish_bite_pct": 5}'::jsonb),
  ('night_guardian', 4, '{"combat_damage_pct": 5, "rare_loot_pct": 3}'::jsonb),
  ('night_hunter', 3, '{"crit_pct": 3, "combat_damage_pct": 2}'::jsonb),
  ('night_owl', 2, '{"clue_bonus_pct": 4, "evasion_pct": 1}'::jsonb),
  ('noon_crafter', 2, '{"craft_quality": 2}'::jsonb),
  ('omen_reader', 2, '{"clue_bonus_pct": 4, "encounter_pct": -3}'::jsonb),
  ('one_hit', 3, '{"crit_pct": 3, "combat_damage_pct": 2}'::jsonb),
  ('pathfinder', 2, '{"travel_time_pct": -4, "encounter_pct": -3}'::jsonb),
  ('pauper', 1, '{"encounter_pct": -3}'::jsonb),
  ('prof_gatherer', 3, '{"gather_qty_pct": 5, "craft_quality": 2}'::jsonb),
  ('quiet_night', 2, '{"presence": -10}'::jsonb),
  ('rain_herbalist', 2, '{"gather_qty_pct": 3, "healing_pct": 3}'::jsonb),
  ('region_full', 2, '{"rare_loot_pct": 2}'::jsonb),
  ('region_full_5', 4, '{"rare_loot_pct": 5, "travel_time_pct": -6, "clue_bonus_pct": 4}'::jsonb),
  ('regional_surveyor', 2, '{"clue_bonus_pct": 4, "encounter_pct": -3}'::jsonb),
  ('repairman', 2, '{"craft_quality": 2, "defense": 2}'::jsonb),
  ('rescuer', 1, '{"healing_pct": 3}'::jsonb),
  ('rescuer_10', 3, '{"healing_pct": 8, "presence": 10, "defense": 2}'::jsonb),
  ('rest_lover', 2, '{"healing_pct": 5}'::jsonb),
  ('revived', 2, '{"healing_pct": 5, "mental_loss_pct": -3}'::jsonb),
  ('rich', 3, '{"rare_loot_pct": 3}'::jsonb),
  ('rider', 1, '{"travel_time_pct": -2}'::jsonb),
  ('river_angler', 2, '{"fish_rare_pct": 3}'::jsonb),
  ('seal_path', 2, '{"magic_pct": 3, "erosion_pct": -3}'::jsonb),
  ('searcher_300', 3, '{"clue_bonus_pct": 6, "rare_loot_pct": 2}'::jsonb),
  ('searcher_50', 1, '{"flee_pct": 3}'::jsonb),
  ('sky_hunter', 3, '{"ranged_pct": 5, "evasion_pct": 2}'::jsonb),
  ('slayer_200', 3, '{"combat_damage_pct": 3, "crit_pct": 2}'::jsonb),
  ('slayer_50', 2, '{"combat_damage_pct": 2, "crit_pct": 1}'::jsonb),
  ('slayer_500', 4, '{"combat_damage_pct": 5, "crit_pct": 3, "incoming_damage_pct": -2}'::jsonb),
  ('snow_marcher', 2, '{"travel_time_pct": -4, "defense": 2}'::jsonb),
  ('spirit_guard', 2, '{"erosion_pct": -5, "magic_pct": 2}'::jsonb),
  ('spirit_vessel', 4, '{"magic_pct": 7, "erosion_pct": -8}'::jsonb),
  ('spot_finder', 2, '{"gather_qty_pct": 3}'::jsonb),
  ('stable_master', 3, '{"travel_time_pct": -6, "flee_pct": 5}'::jsonb),
  ('steady_mind', 1, '{"mental_loss_pct": -3}'::jsonb),
  ('strong', 4, '{"melee_pct": 7, "presence": 15}'::jsonb),
  ('supply_regular', 2, '{"gather_qty_pct": 3}'::jsonb),
  ('swift', 4, '{"ranged_pct": 7, "evasion_pct": 3}'::jsonb),
  ('title_collector', 3, '{"rare_loot_pct": 3, "clue_bonus_pct": 4}'::jsonb),
  ('title_master', 5, '{"rare_loot_pct": 7, "clue_bonus_pct": 9, "combat_damage_pct": 3}'::jsonb),
  ('tonic_lover', 2, '{"healing_pct": 5}'::jsonb),
  ('tough', 4, '{"defense": 8, "incoming_damage_pct": -3, "presence": 10}'::jsonb),
  ('traveler_100', 3, '{"travel_time_pct": -6, "flee_pct": 5}'::jsonb),
  ('tycoon', 4, '{"rare_loot_pct": 5, "gather_qty_pct": 5}'::jsonb),
  ('wanderer_night', 2, '{"travel_time_pct": -4, "presence": -5}'::jsonb),
  ('waterside_soul', 3, '{"fish_bite_pct": 8, "fish_rare_pct": 3}'::jsonb),
  ('well_traveled', 2, '{"travel_time_pct": -4}'::jsonb),
  ('wind_archer', 3, '{"ranged_pct": 5, "crit_pct": 2}'::jsonb);
update public.world_title_catalog c set grade = f.grade, bonus = f.bonus
  from title_fix f where c.title_key = f.title_key and (c.grade is distinct from f.grade or c.bonus is distinct from f.bonus);

/* ── 칭호 효과를 전투 능력치·상태 효과에 잇기 ─────────────── */
-- 그 캐릭터가 장착한 칭호의 효과 합(전투 능력치는 파티 동료 것도 계산하므로 캐릭터를 받는다)
create or replace function public.world_title_bonus_of(p_owner uuid, p_effect_key text)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce(sum(case when (tc.bonus ->> p_effect_key) ~ '^-?[0-9]+(\.[0-9]+)?$' then (tc.bonus ->> p_effect_key)::numeric else 0 end), 0)
    from public.world_character_titles ct join public.world_title_catalog tc using (title_key)
   where ct.owner_id = p_owner and ct.is_equipped and tc.active
$$;
-- 상태 효과 합계에 더할 칭호 효과(다른 곳에서 칭호를 따로 더하지 않는 키만: 회복량·침식·정신 손실·요괴 조우)
create or replace function public.world_title_extra(p_effect_key text)
returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if p_effect_key not in ('healing_pct', 'erosion_pct', 'mental_loss_pct', 'encounter_pct') then return 0; end if;
  return public.world_title_bonus_of(public.fn_owner_auth_uid(), p_effect_key);
end $$;
do $$
declare f text;
begin
  foreach f in array array['world_title_bonus_of(uuid,text)', 'world_title_extra(text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to public', f);
    execute format('revoke execute on function public.%s from anon', f);
  end loop;
end $$;

do $$
declare d text; a text;
begin
  -- 상태 효과 합계
  d := pg_get_functiondef('public.world_status_effect_total'::regproc);
  if position('world_title_extra' in d) = 0 then
    a := '+ public.world_bond_self(p_effect_key)';
    if position(a in d) = 0 then raise exception '상태 효과 합계에서 더할 자리를 찾지 못했습니다'; end if;
    execute replace(d, a, a || ' + public.world_title_extra(p_effect_key)');
  end if;
  -- 전투 능력치: 방어·회피·치명타·달아나기·이목에 칭호, 그리고 칭호 효과를 그 캐릭터 것으로
  d := pg_get_functiondef('public.world_combat_stats'::regproc);
  if position('world_title_bonus_of' in d) = 0 then
    d := replace(d, $q$g_def := public.world_gear_total(p_owner, 'defense'); g_eva := public.world_gear_total(p_owner, 'evasion_pct');$q$,
      $q$g_def := public.world_gear_total(p_owner, 'defense') + public.world_title_bonus_of(p_owner, 'defense'); g_eva := public.world_gear_total(p_owner, 'evasion_pct') + public.world_title_bonus_of(p_owner, 'evasion_pct');$q$);
    d := replace(d, $q$g_crit := public.world_gear_total(p_owner, 'crit_pct'); g_flee := public.world_gear_total(p_owner, 'flee_pct');$q$,
      $q$g_crit := public.world_gear_total(p_owner, 'crit_pct') + public.world_title_bonus_of(p_owner, 'crit_pct'); g_flee := public.world_gear_total(p_owner, 'flee_pct') + public.world_title_bonus_of(p_owner, 'flee_pct');$q$);
    d := replace(d, $q$g_pres := public.world_gear_total(p_owner, 'presence');$q$,
      $q$g_pres := public.world_gear_total(p_owner, 'presence') + public.world_title_bonus_of(p_owner, 'presence');$q$);
    d := replace(d, 'public.world_title_bonus(', 'public.world_title_bonus_of(p_owner, ');
    if (length(d) - length(replace(d, 'world_title_bonus_of', ''))) / 20 < 8 then raise exception '전투 능력치에서 칭호를 넣을 줄을 다 찾지 못했습니다'; end if;
    execute d;
  end if;
end $$;

/* ── 진행 게이지 ──────────────────────────────────────── */
-- 조건의 지금 값과 목표({cur, need}). 여러 조건(all)은 각 조건의 달성률 합 / 조건 수.
create or replace function public.world_title_rule_progress(p_owner uuid, p_rule jsonb)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare n numeric := coalesce((p_rule ->> 'n')::numeric, 1); v numeric := 0; x jsonb; s numeric := 0; k int := 0; pr jsonb;
begin
  if p_rule is null then return null; end if;
  if p_rule ? 'all' then
    for x in select value from jsonb_array_elements(p_rule -> 'all') loop
      pr := public.world_title_rule_progress(p_owner, x); k := k + 1;
      s := s + least(1, coalesce((pr ->> 'cur')::numeric, 0) / greatest(1, coalesce((pr ->> 'need')::numeric, 1)));
    end loop;
    return jsonb_build_object('cur', round(s * 100), 'need', greatest(1, k) * 100, 'pct', true);
  elsif p_rule ? 'ev' then
    select count(*) into v from public.world_events e
     where e.actor_id = p_owner and e.event_type = p_rule ->> 'ev'
       and (not p_rule ? 'p' or e.payload @> (p_rule -> 'p'))
       and (not p_rule ? 'has' or e.payload ? (p_rule ->> 'has'))
       and (not p_rule ? 'phase' or public.world_time_phase(e.created_at) = p_rule ->> 'phase')
       and (not p_rule ? 'gte' or not exists (select 1 from jsonb_each_text(p_rule -> 'gte') g
              where not (coalesce(e.payload ->> g.key, '') ~ '^-?[0-9]+(\.[0-9]+)?$' and (e.payload ->> g.key)::numeric >= g.value::numeric)));
  elsif p_rule ? 'distinct' then
    select count(distinct e.payload ->> (p_rule ->> 'key')) into v from public.world_events e
     where e.actor_id = p_owner and e.event_type = p_rule ->> 'distinct' and e.payload ? (p_rule ->> 'key');
  elsif p_rule ? 'char' then
    select coalesce((to_jsonb(ch) ->> (p_rule ->> 'char'))::numeric, 0) into v from public.world_characters ch where ch.owner_id = p_owner;
    if p_rule ? 'max' then return jsonb_build_object('cur', case when v <= (p_rule ->> 'max')::numeric then 1 else 0 end, 'need', 1); end if;
  elsif p_rule ? 'nodes' then
    select count(*) into v from public.world_exploration_discoveries where owner_id = p_owner; n := (p_rule ->> 'nodes')::numeric;
  elsif p_rule ? 'spots' then
    select count(*) into v from public.world_gathering_discoveries where owner_id = p_owner; n := (p_rule ->> 'spots')::numeric;
  elsif p_rule ? 'mounts' then
    select count(*) into v from public.world_owned_mounts where owner_id = p_owner; n := (p_rule ->> 'mounts')::numeric;
  elsif p_rule ? 'titles' then
    select count(*) into v from public.world_character_titles where owner_id = p_owner; n := (p_rule ->> 'titles')::numeric;
  elsif p_rule ? 'survey_full' then
    select count(*) into v from public.world_map_regions r
     where r.active and not coalesce(r.is_safe_zone, false) and coalesce((public.world_field_survey(p_owner, r.region_id) ->> 'pct')::int, 0) >= 100;
    n := (p_rule ->> 'survey_full')::numeric;
  else
    return null;
  end if;
  return jsonb_build_object('cur', least(v, n), 'need', n);
end $function$;
alter function public.world_title_rule_progress(uuid, jsonb) owner to fn_owner_field;
revoke all on function public.world_title_rule_progress(uuid, jsonb) from public, anon, authenticated;

-- 칭호 화면: 등급과 진행(숨김이 아닌 못 얻은 칭호만)
create or replace function public.world_title_snapshot()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); out jsonb; disp text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select profile ->> 'title' into disp from public.world_characters where owner_id = uid;
  select jsonb_build_object(
    'earned_count', count(*) filter (where ct.owner_id is not null),
    'equipped_count', count(*) filter (where ct.owner_id is not null and ct.is_equipped),
    'max_equipped', 3, 'display', disp,
    'total', count(*), 'visible_total', count(*) filter (where not tc.hidden), 'hidden_total', count(*) filter (where tc.hidden),
    'hidden_earned', count(*) filter (where tc.hidden and ct.owner_id is not null),
    'titles', coalesce(jsonb_agg(jsonb_build_object(
      'key', tc.title_key, 'hidden', tc.hidden, 'category', coalesce(tc.category, '기타'), 'icon', tc.icon, 'grade', tc.grade,
      'name', case when tc.hidden and ct.owner_id is null then '숨겨진 칭호' else tc.title_name end,
      'description', case when tc.hidden and ct.owner_id is null then '어떤 조건으로 얻는지 알려지지 않았습니다.' else tc.description end,
      'condition', case when tc.hidden and ct.owner_id is null then '???' else tc.condition_text end,
      'bonus', case when tc.hidden and ct.owner_id is null then null else tc.bonus end,
      'progress', case when ct.owner_id is null and not tc.hidden then public.world_title_rule_progress(uid, tc.rule) end,
      'earned', ct.owner_id is not null, 'new', ct.owner_id is not null and ct.seen_at is null, 'earned_at', ct.earned_at,
      'equipped', coalesce(ct.is_equipped, false), 'display', tc.title_key = disp)
      order by (ct.owner_id is not null) desc, tc.hidden, tc.sort), '[]'::jsonb))
  into out
  from public.world_title_catalog tc left join public.world_character_titles ct on ct.title_key = tc.title_key and ct.owner_id = uid
  where tc.active;
  return out;
end $function$;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028070000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select grade, count(*) from public.world_title_catalog where active group by grade order by grade;
