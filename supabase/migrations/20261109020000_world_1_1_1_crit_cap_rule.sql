CREATE OR REPLACE FUNCTION public.world_agile_rules()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select jsonb_build_object(
    'agi_k', 2, 'tank_k', 0.5,
    'quiet_k', 0.8, 'quiet_cap', 50,
    'sneak_base', 25, 'sneak_k', 0.65, 'sneak_cap', 75, 'sneak_min', 10, 'scout_sneak', 10,
    'flee_base', 50, 'flee_k', 0.5, 'flee_cap', 95, 'flee_min', 10, 'scout_flee', 15,
    'hazard_base', 30, 'hazard_k', 0.75, 'hazard_cap', 90, 'hazard_w_k', 0.05,
    'eva_base', 3, 'eva_k', 0.175, 'eva_cap', 40, 'scout_eva', 6, 'crit_cap', 60)
$function$;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[], p_n int) returns void language plpgsql as $f$
declare d text; i int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> p_n then raise exception '함수 % 모양이 예상과 다릅니다', p_name; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;
select pg_temp.yh_fix('world_combat_stats', array[$q$crit := greatest(0, least(60, 5 + s_per$q$, $q$crit := greatest(0, least((public.world_agile_rules() ->> 'crit_cap')::numeric, 5 + s_per$q$], 1);


update public.world_app_meta set value = '20261109020000' where key = 'db_version';
