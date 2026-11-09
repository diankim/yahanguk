create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

create or replace function public.world_level_rules() returns jsonb
language sql immutable as $$ select '{"cap": 45, "per_level": 3, "stat_points_cap": 132}'::jsonb $$;
create or replace function public.world_level_cap() returns integer
language sql immutable as $$ select (public.world_level_rules() ->> 'cap')::int $$;
create or replace function public.world_stat_points_cap() returns integer
language sql immutable as $$ select (public.world_level_rules() ->> 'stat_points_cap')::int $$;
grant execute on function public.world_level_rules() to anon, authenticated;
grant execute on function public.world_level_cap() to anon, authenticated;
grant execute on function public.world_stat_points_cap() to anon, authenticated;

select pg_temp.yh_patch('public.world_event_char_apply()', 'if nl < 40 then', 'if nl < public.world_level_cap() then');
select pg_temp.yh_patch('public.world_event_char_apply()', 'if nl >= 40 then nx := 0; end if;', 'if nl >= public.world_level_cap() then nx := 0; end if;');
select pg_temp.yh_patch('public.world_event_char_apply()', 'level = least(40, nl)', 'level = least(public.world_level_cap(), nl)');
select pg_temp.yh_patch('public.world_event_char_apply()', 'nx := case when nl >= 40 then 0', 'nx := case when nl >= public.world_level_cap() then 0');
select pg_temp.yh_patch('public.world_event_char_apply()', 'least(117, stat_points + gained * 3)', 'least(public.world_stat_points_cap(), stat_points + gained * 3)');
select pg_temp.yh_patch('public.world_event_char_apply()', 'while nl < 40 and', 'while nl < public.world_level_cap() and');

select pg_temp.yh_patch('public.world_grant_xp(uuid,integer)', 'IF lv >= 40 THEN', 'IF lv >= public.world_level_cap() THEN');
select pg_temp.yh_patch('public.world_grant_xp(uuid,integer)', 'least(117,', 'least(public.world_stat_points_cap(),');
select pg_temp.yh_patch('public.world_grant_xp(uuid,integer)', 'WHILE lv < 40 AND', 'WHILE lv < public.world_level_cap() AND');

select pg_temp.yh_patch('public.world_claim_idle_activity()', 'v_new_level<40', 'v_new_level<public.world_level_cap()', 2);
select pg_temp.yh_patch('public.world_claim_idle_activity()', 'v_new_level>=40', 'v_new_level>=public.world_level_cap()');
select pg_temp.yh_patch('public.world_claim_idle_activity()', 'c.level>=40', 'c.level>=public.world_level_cap()');
select pg_temp.yh_patch('public.world_claim_idle_activity()', 'least(117,', 'least(public.world_stat_points_cap(),');
select pg_temp.yh_patch('public.world_claim_idle_activity()', '''level_cap'',40', '''level_cap'',public.world_level_cap()');

select pg_temp.yh_patch('public.world_xp_damp_apply()', 'case when nl >= 40 then 0', 'case when nl >= public.world_level_cap() then 0');
select pg_temp.yh_patch('public.world_xp_damp_apply()', 'least(117,', 'least(public.world_stat_points_cap(),');
select pg_temp.yh_patch('public.world_xp_damp_apply()', 'while nl < 40 and', 'while nl < public.world_level_cap() and');
select pg_temp.yh_patch('public.world_xp_damp_pct(uuid,integer)', 'p_level >= 40', 'p_level >= public.world_level_cap()');

select pg_temp.yh_patch('public.world_expedition_gear(integer)', 'least(40, p_level)', 'least(public.world_level_cap(), p_level)');
