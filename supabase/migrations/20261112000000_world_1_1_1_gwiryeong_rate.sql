create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_gwiryeong_rules', array[
  $a$'cap_div', 1,$a$,
  $b$'cap_div', 1, 'rate_mul', 0.25,$b$]);

select pg_temp.yh_fix('world_gwiryeong_chance', array[
  $a$select case when p_type in ('gw_win', 'raid_win') then 0.01 else$a$,
  $b$select (public.world_gwiryeong_rules() ->> 'rate_mul')::numeric * case when p_type in ('gw_win', 'raid_win') then 0.01 else$b$]);

select pg_temp.yh_fix('world_field_search', array[
  $a$random() < 0.002 AND public.world_gwiryeong_reserve(uid, 'skill_tracking')$a$,
  $b$random() < 0.002 * (public.world_gwiryeong_rules() ->> 'rate_mul')::numeric AND public.world_gwiryeong_reserve(uid, 'skill_tracking')$b$]);

update public.world_skill_catalog set description = '추가 기술 · 위험도 7 이상 지역에서 탐색할 때 드물게 귀령초 하나(한 번 얻으면 72시간 다시 나오지 않음)'
 where skill_id = 'tracking_x36';

update public.world_app_meta set value = '20261112000000' where key = 'db_version';
