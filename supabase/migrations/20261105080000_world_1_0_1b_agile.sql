create or replace function public.world_agile_rules() returns jsonb language sql immutable as $f$
  select jsonb_build_object(
    'agi_k', 2, 'tank_k', 0.5,
    'quiet_k', 0.8, 'quiet_cap', 50,
    'sneak_base', 25, 'sneak_k', 0.65, 'sneak_cap', 75, 'sneak_min', 10, 'scout_sneak', 10,
    'flee_base', 50, 'flee_k', 0.5, 'flee_cap', 95, 'flee_min', 10, 'scout_flee', 15,
    'hazard_base', 30, 'hazard_k', 0.75, 'hazard_cap', 90, 'hazard_w_k', 0.05,
    'eva_base', 3, 'eva_k', 0.175, 'eva_cap', 40, 'scout_eva', 6)
$f$;

create or replace function public.world_agile_of(p_str numeric, p_agi numeric, p_vit numeric, p_per numeric, p_wil numeric, p_spi numeric) returns numeric
language sql immutable as $f$
  select greatest(coalesce(p_agi, 0) + coalesce(p_per, 0), coalesce(p_agi, 0) * (public.world_agile_rules() ->> 'agi_k')::numeric,
    coalesce(p_wil, 0) + coalesce(p_spi, 0), (coalesce(p_str, 0) + coalesce(p_vit, 0)) * (public.world_agile_rules() ->> 'tank_k')::numeric)
$f$;

revoke all on function public.world_agile_rules() from public, anon, authenticated;
revoke all on function public.world_agile_of(numeric, numeric, numeric, numeric, numeric, numeric) from public, anon, authenticated;
grant execute on function public.world_agile_rules() to fn_owner_field;
grant execute on function public.world_agile_of(numeric, numeric, numeric, numeric, numeric, numeric) to fn_owner_field;

do $w$
declare d text; a text; b text;
begin
  d := replace(pg_get_functiondef('public.world_combat_stats(uuid,jsonb)'::regprocedure), E'\r\n', E'\n');
  a := $a$  eva := greatest(0, least(40, 3 + s_agi * 0.35 + CASE WHEN c.job_key = 'scout' THEN 6 WHEN c.job_key = 'sealmaster' THEN 12 WHEN c.job_key = 'exorcist' THEN 4 + c.level * 0.3 ELSE 0 END + g_eva));$a$;
  b := $a$  flee := greatest(10, least(95, 50 + s_agi + CASE WHEN c.job_key = 'scout' THEN 15 WHEN c.job_key = 'exorcist' THEN 8 ELSE 0 END + g_flee));$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 or (length(d) - length(replace(d, b, ''))) / length(b) <> 1 then raise exception '1.0.1b world_combat_stats 기준 문구가 없습니다'; end if;
  d := replace(d, a, $x$  eva := greatest(0, least((public.world_agile_rules() ->> 'eva_cap')::numeric, (public.world_agile_rules() ->> 'eva_base')::numeric
    + public.world_agile_of(s_str, s_agi, s_vit, s_per, s_wil, s_spi) * (public.world_agile_rules() ->> 'eva_k')::numeric
    + CASE WHEN c.job_key = 'scout' THEN (public.world_agile_rules() ->> 'scout_eva')::numeric ELSE 0 END + g_eva));$x$);
  d := replace(d, b, $x$  flee := greatest((public.world_agile_rules() ->> 'flee_min')::numeric, least((public.world_agile_rules() ->> 'flee_cap')::numeric, (public.world_agile_rules() ->> 'flee_base')::numeric
    + public.world_agile_of(s_str, s_agi, s_vit, s_per, s_wil, s_spi) * (public.world_agile_rules() ->> 'flee_k')::numeric
    + CASE WHEN c.job_key = 'scout' THEN (public.world_agile_rules() ->> 'scout_flee')::numeric ELSE 0 END + g_flee));$x$);
  execute d;
end $w$;

do $w$
declare d text; a text; b text;
begin
  d := replace(pg_get_functiondef('public.world_sneak_pct(uuid,integer,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$greatest(10, least(75, round(25 + greatest(1, round(c.agility * (1 + public.world_status_self(c.owner_id, 'agility_pct') / 100.0))) * 0.8 + c.perception * 0.5 + case when c.job_key = 'scout' then 10 else 0 end$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.1b world_sneak_pct 기준 문구가 없습니다'; end if;
  execute replace(d, a, $x$greatest((public.world_agile_rules() ->> 'sneak_min')::numeric, least((public.world_agile_rules() ->> 'sneak_cap')::numeric, round((public.world_agile_rules() ->> 'sneak_base')::numeric
    + public.world_agile_of(c.strength, greatest(1, round(c.agility * (1 + public.world_status_self(c.owner_id, 'agility_pct') / 100.0))), c.vitality, c.perception, c.willpower, c.spirit_affinity) * (public.world_agile_rules() ->> 'sneak_k')::numeric
    + case when c.job_key = 'scout' then (public.world_agile_rules() ->> 'scout_sneak')::numeric else 0 end$x$);
end $w$;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_field_search()'::regprocedure), E'\r\n', E'\n');
  foreach a in array array[
    $a$w_quiet float8 := 6; q_mode float8 := 0;$a$,
    $a$  w_haz := greatest(3, 8 + depth * 2 - c.agility / 10.0);$a$,
    $a$    q_mode := least(0.5, (greatest(1, round(coalesce(c.agility, 0) * (1 + public.world_status_self(uid, 'agility_pct') / 100.0))) + coalesce(c.perception, 0)) * 0.008);$a$,
    $a$    IF random() < 0.3 + c.agility * 0.01 + c.perception * 0.005 THEN$a$] loop
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.1b world_field_search 기준 문구가 없습니다: %', a; end if;
  end loop;
  d := replace(d, $a$w_quiet float8 := 6; q_mode float8 := 0;$a$, $a$w_quiet float8 := 6; q_mode float8 := 0; v_ag numeric;$a$);
  d := replace(d, $a$  w_haz := greatest(3, 8 + depth * 2 - c.agility / 10.0);$a$,
    $a$  v_ag := public.world_agile_of(c.strength, greatest(1, round(coalesce(c.agility, 0) * (1 + public.world_status_self(uid, 'agility_pct') / 100.0))), c.vitality, c.perception, c.willpower, c.spirit_affinity);
  w_haz := greatest(3, 8 + depth * 2 - v_ag * (public.world_agile_rules() ->> 'hazard_w_k')::numeric);$a$);
  d := replace(d, $a$    q_mode := least(0.5, (greatest(1, round(coalesce(c.agility, 0) * (1 + public.world_status_self(uid, 'agility_pct') / 100.0))) + coalesce(c.perception, 0)) * 0.008);$a$,
    $a$    q_mode := least((public.world_agile_rules() ->> 'quiet_cap')::numeric, v_ag * (public.world_agile_rules() ->> 'quiet_k')::numeric) / 100.0;$a$);
  d := replace(d, $a$    IF random() < 0.3 + c.agility * 0.01 + c.perception * 0.005 THEN$a$,
    $a$    IF random() * 100 < least((public.world_agile_rules() ->> 'hazard_cap')::numeric, (public.world_agile_rules() ->> 'hazard_base')::numeric + v_ag * (public.world_agile_rules() ->> 'hazard_k')::numeric) THEN$a$);
  execute d;
end $w$;

create or replace function public.world_solo_aid(p_job text) returns jsonb language sql immutable as $f$
  select case p_job
    when 'artificer'  then '{"solo_dmg": -40, "solo_guard": -24, "final_dmg": -2}'
    when 'scout'      then '{"solo_dmg": -25, "solo_guard": -46, "final_dmg": -47}'
    when 'exorcist'   then '{"solo_dmg": -41, "solo_guard": -16, "final_dmg": 13}'
    when 'medic'      then '{"solo_dmg": -30, "solo_guard": -55, "final_dmg": 18}'
    when 'sealmaster' then '{"solo_dmg": -42, "solo_guard": -32, "final_dmg": 5}'
    when 'analyst'    then '{"solo_dmg": -25, "solo_guard": -36, "final_dmg": 34}'
    else '{}' end::jsonb
$f$;

update public.world_patch_notes set body = body || $pn$

## 1.0.1b · 기민 — 직업마다 주 능력치로
- 조용히 살피기·기척 숨기기·도주·위험 피하기·회피가 민첩·감각만 보던 것을, 직업의 주 능력치로 보도록 바꿨습니다. 「기민」 = 민첩+감각, 민첩×2, 의지+영성, (근력+체질)×½ 가운데 가장 큰 값입니다. 퇴마관·의무관·봉인술사도 의지·영성을 올리면 함께 오릅니다.
- 상한은 모든 직업이 같습니다: 조용히 살피기 50%·기척 숨기기 75%·도주 95%·위험 피하기 90%·회피 40%.
- 직업 덤은 월궁 사수만 남깁니다(기척 숨기기 +10·도주 +15·회피 +6). 퇴마관 회피·도주 덤과 봉인술사 회피 +12는 기민에 들어갔습니다.
- 회피가 바뀐 만큼 귀허의 주인 혼자 도전 보정을 다시 맞췄습니다(호위 무사·퇴마관·의무관·암영 검객, 직업마다 혼자 2~3/10).
$pn$
where note_id = '1.0.0' and position('## 1.0.1b' in body) = 0;

update public.world_app_meta set value = '20261105080000' where key = 'db_version';
