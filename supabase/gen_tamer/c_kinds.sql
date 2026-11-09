alter table public.world_monster_kinds add column job_keys text[] not null default '{}';
update public.world_monster_kinds set job_keys = case when job_key is null then '{}' else array[job_key] end;
update public.world_monster_kinds set job_keys = array['scout', 'tamer'] where kind_key = 'shadow';
update public.world_monster_kinds set job_keys = array['tamer'] where kind_key = 'swarm';

create or replace function public.world_kind_job_ok(p_kind text, p_job text)
 returns boolean language sql stable
 set search_path to 'pg_catalog', 'public'
as $function$
  select coalesce((select p_job = any (k.job_keys) from public.world_monster_kinds k where k.kind_key = p_kind), false)
$function$;
select pg_temp.yh_share('public.world_kind_job_ok(text, text)');

create or replace function public.world_kind_jobs_label(p_jobs text[])
 returns text language sql immutable
 set search_path to 'pg_catalog', 'public'
as $function$
  select nullif(array_to_string(array(select public.world_job_label(j) from unnest(p_jobs) with ordinality u(j, o) order by o), '·'), '')
$function$;
select pg_temp.yh_share('public.world_kind_jobs_label(text[])');

select pg_temp.yh_fix('world_kind_mult', array[$q$ case when k.job_key = p_job then 1.2 else 1 end$q$, $q$ case when p_job = any (k.job_keys) then 1.2 else 1 end$q$]);

select pg_temp.yh_fix('world_field_battle_view', array[$q$'job', k.job_key)$q$, $q$'job', k.job_keys[1], 'jobs', to_jsonb(k.job_keys))$q$,
  $q$'known', coalesce(x.defeated, 0) > 0,$q$, $q$'known', coalesce(x.defeated, 0) > 0, 'pet', public.world_pet_partner_of(q.o),$q$]);

select pg_temp.yh_fix('world_monster_codex_snapshot', array[$q$'job', k.job_key,$q$, $q$'job', k.job_keys[1], 'jobs', to_jsonb(k.job_keys),$q$]);

select pg_temp.yh_fix('world_gimmick_tip', array[$q$ and k.job_key is not null then$q$, $q$ and cardinality(k.job_keys) > 0 then$q$,
  $q$coalesce(case k.job_key when 'exorcist' then '퇴마관' when 'sealmaster' then '봉인술사' when 'scout' then '월궁 사수' when 'analyst' then '암영 검객' when 'medic' then '의무관' when 'artificer' then '호위 무사' end, '')$q$,
  $q$coalesce(public.world_kind_jobs_label(k.job_keys), '')$q$]);

select pg_temp.yh_fix('world_exp_fight_story', array[$q$ else 'melee' end, k.job_key
          into gbest, gjob$q$, $q$ else 'melee' end, case when p_job = any (k.job_keys) then p_job end
          into gbest, gjob$q$]);
