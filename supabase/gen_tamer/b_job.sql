alter table public.world_characters drop constraint world_characters_job_key_check;
alter table public.world_characters add constraint world_characters_job_key_check
  check (job_key = any (array['exorcist', 'scout', 'medic', 'sealmaster', 'analyst', 'artificer', 'tamer']));

select pg_temp.yh_fix('world_job_base', array[$q$
    when 'analyst'    then$q$, $q$
    when 'tamer'      then '{"strength":4,"agility":7,"vitality":5,"perception":8,"willpower":3,"spirit_affinity":3}'
    when 'analyst'    then$q$]);

select pg_temp.yh_fix('world_job_effect', array[$q$
      when 'analyst'    then 0$q$, $q$
      when 'analyst'    then 0
      when 'tamer'      then 0$q$]);

select pg_temp.yh_fix('world_job_label', array[$q$ when 'artificer' then '호위 무사' end$q$, $q$ when 'artificer' then '호위 무사' when 'tamer' then '조련사' end$q$]);
select pg_temp.yh_fix('world_job_name', array[$q$ when 'artificer' then '호위 무사' else$q$, $q$ when 'artificer' then '호위 무사' when 'tamer' then '조련사' else$q$]);

create or replace function public.world_job_line(p_job text)
 returns text language sql immutable
as $function$
  select case p_job when 'artificer' then 'melee' when 'scout' then 'ranged' when 'sealmaster' then 'sealing'
    when 'exorcist' then 'exorcism' when 'analyst' then 'dagger' when 'medic' then 'medicine' when 'tamer' then 'taming' end
$function$;

create or replace function public.world_combat_lines()
 returns text[] language sql immutable
as $function$
  select array['melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine', 'taming']
$function$;
select pg_temp.yh_share('public.world_combat_lines()');
grant execute on function public.world_combat_lines() to authenticated;

select pg_temp.yh_fix('world_job_skill_rules', array[$q$ 'line', '{me}의 「약점 간파」: 상대의 빈틈을 읽었다.'))$q$, $q$ 'line', '{me}의 「약점 간파」: 상대의 빈틈을 읽었다.'),
    'tamer', jsonb_build_object('name', '휘파람', 'desc', '원거리 ×1.2로 쏘고, 이번 차례 동무의 동작이 반드시 터지며 동무 피해가 두 배가 됩니다.', 'duel', jsonb_build_object('kind', 'focus', 'n', 1, 'mul', 1.3), 'line', '{me}의 「휘파람」: 동무가 함께 달려들었다.'))$q$]);

select pg_temp.yh_fix('world_solo_aid', array[$q$
    when 'analyst'    then$q$, $q$
    when 'tamer'      then '{"solo_dmg": -25, "solo_guard": -46, "final_dmg": -47}'
    when 'analyst'    then$q$]);

create or replace function public.world_weapon_jobs_of(p_type text)
 returns jsonb language sql immutable
as $function$
  select case coalesce(p_type, 'melee') when 'ranged' then '["scout","tamer"]'::jsonb when 'magic' then '["exorcist","sealmaster","medic"]'::jsonb
    else '["artificer","analyst"]'::jsonb end
$function$;

update public.world_item_catalog set equipment_traits = jsonb_set(equipment_traits, '{jobs}', (equipment_traits -> 'jobs') || '["tamer"]'::jsonb)
 where category = 'weapon' and equipment_traits -> 'jobs' ? 'scout' and not equipment_traits -> 'jobs' ? 'tamer';

select pg_temp.yh_fix('world_craft_item', array[$q$ when 'artificer' then '호위 무사' else r.required_job end$q$, $q$ else coalesce(public.world_job_label(r.required_job), r.required_job) end$q$]);

select pg_temp.yh_fix('world_expedition_complete', array[$q$ when 'artificer' then '반격 태세' end;$q$, $q$ when 'artificer' then '반격 태세' when 'tamer' then '동무의 코' end;$q$]);
select pg_temp.yh_fix('world_expedition_progress', array[$q$ when 'artificer' then '반격 태세' end);$q$, $q$ when 'artificer' then '반격 태세' when 'tamer' then '동무의 코' end);$q$]);

select pg_temp.yh_fix('world_expedition_walk_lines', array[$q$
    else array['주변을 살피며 천천히 나아갑니다.'] end;$q$, $q$
    when 'tamer' then array['동무가 앞서 달려가 냄새를 맡고는 뒤를 돌아봅니다.', '동무의 이름을 낮게 불러 곁에 붙여 둡니다.', '동무가 귀를 세운 쪽을 눈여겨봅니다.']
    else array['주변을 살피며 천천히 나아갑니다.'] end;$q$]);

select pg_temp.yh_fix('world_exp_fight_story', array[$q$
    when 'artificer' then '[호위 일격] 앞을 막아서며 {f}을(를) 베어 넘겼습니다' else null end;$q$, $q$
    when 'artificer' then '[호위 일격] 앞을 막아서며 {f}을(를) 베어 넘겼습니다'
    when 'tamer' then '[짝 사냥] 동무가 {f}에게 달려든 틈에 화살을 박아 넣었습니다' else null end;$q$]);
