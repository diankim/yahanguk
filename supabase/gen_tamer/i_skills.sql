insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values
  ('taming_t3', '눈 맞춤', 'taming', '원거리 피해 +2% · 치명타 +3% · 동무 피해 +4%.', '{"damage_pct": 2, "crit_pct": 3, "pet_pct": 4}', 3, 'base'),
  ('taming_t8', '같이 겨누기', 'taming', '원거리 피해 +6% · 동무 피해 +12%, 군충·은형 요괴에게 동무 피해 +8% 더.', '{"damage_pct": 6, "pet_pct": 12}', 8, 'base'),
  ('taming_t13', '발맞춤', 'taming', '원거리 피해 +2% · 동무 피해 +3%.', '{"damage_pct": 2, "pet_pct": 3}', 13, 'base'),
  ('taming_x13', '눈짓', 'taming', '추가 기술 · 전투의 첫 공격 차례에 동무의 동작이 반드시 터진다', '{}', 13, 'extra'),
  ('taming_t18', '냄새 맡기', 'taming', '치명타 +3%.', '{"crit_pct": 3}', 18, 'base'),
  ('taming_c24a', '물고 늘어지기', 'taming', '택일 기술(사냥) · 동무의 동작이 터질 확률 ×1.5', '{}', 24, 'a'),
  ('taming_c24b', '몸 낮춰', 'taming', '택일 기술(돌봄) · 내 체력이 50 아래면 동무가 막아서 받는 피해 −15%', '{}', 24, 'b'),
  ('taming_t24', '몰이 사냥', 'taming', '원거리 피해 +2% · 동무 피해 +4%.', '{"damage_pct": 2, "pet_pct": 4}', 24, 'base'),
  ('taming_t30', '짝눈', 'taming', '치명타 +3%.', '{"crit_pct": 3}', 30, 'base'),
  ('taming_x30', '군충몰이', 'taming', '추가 기술 · 군충·은형 요괴에게 동무 피해 +25%', '{}', 30, 'extra'),
  ('taming_t36', '앞서 달리기', 'taming', '원거리 피해 +2% · 동무 피해 +4%.', '{"damage_pct": 2, "pet_pct": 4}', 36, 'base'),
  ('taming_c43a', '사냥 본능', 'taming', '택일 기술(사냥) · 요괴 체력이 30% 아래면 동무 피해 ×2', '{}', 43, 'a'),
  ('taming_c43b', '끝까지 곁에', 'taming', '택일 기술(돌봄) · 쓰러질 피해를 받으면 한 전투에 한 번 동무가 막아 체력 1로 버틴다(그 전투 동안 동무는 쉰다)', '{}', 43, 'b'),
  ('taming_t43', '소리 없는 몰이', 'taming', '원거리 피해 +2% · 치명타 +2% · 동무 피해 +2%.', '{"damage_pct": 2, "crit_pct": 2, "pet_pct": 2}', 43, 'base'),
  ('taming_t50', '한 호흡', 'taming', '원거리 피해 +2% · 치명타 +3% · 동무 피해 +6%.', '{"damage_pct": 2, "crit_pct": 3, "pet_pct": 6}', 50, 'base'),
  ('taming_m50', '이름의 끈', 'taming', '숙달 기술 · 동무의 힘이 친밀도와 상관없이 0.8 아래로 내려가지 않고, 동무 피해 ×1.2', '{}', 50, 'master');

create or replace function public.world_skill_line_ok(p_cat text, p_req jsonb, p_job text)
 returns boolean language sql immutable
as $function$
  select case when p_job is null then true
    when p_cat = any (public.world_combat_lines()) then p_cat = coalesce(public.world_job_line(p_job), p_cat)
    when p_cat = 'combo' then not ((coalesce(p_req, '{}'::jsonb) - coalesce(public.world_job_line(p_job), '')) ?| public.world_combat_lines())
    else true end
$function$;

select pg_temp.yh_fix('world_skill_pending', array[
$q$(s.category not in ('melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine') or$q$,
$q$(not s.category = any (public.world_combat_lines()) or$q$]);

select pg_temp.yh_fix('world_skill_sync', array[
$q$k = (case new.job_key when 'artificer' then 'melee' when 'scout' then 'ranged' when 'sealmaster' then 'sealing'
        when 'exorcist' then 'exorcism' when 'analyst' then 'dagger' when 'medic' then 'medicine' else k end)$q$,
$q$k = coalesce(public.world_job_line(new.job_key), k)$q$]);

select pg_temp.yh_fix('world_line_name', array[
$q$when 'medicine' then '의술' when$q$, $q$when 'medicine' then '의술' when 'taming' then '조련' when$q$]);

select pg_temp.yh_fix('world_initialize_skill_tracks', array[
$q$ 'medicine',coalesce(new.skill_progress->'medicine','{"xp":0,"rank":1}'::jsonb),$q$,
$q$ 'medicine',coalesce(new.skill_progress->'medicine','{"xp":0,"rank":1}'::jsonb),
 'taming',coalesce(new.skill_progress->'taming','{"xp":0,"rank":1}'::jsonb),$q$]);
