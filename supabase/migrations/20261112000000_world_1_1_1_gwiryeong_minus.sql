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
  $b$'cap_div', 1, 'cap_minus', 1,$b$]);

select pg_temp.yh_fix('world_gwiryeong_reserve', array[
  $a$cap := greatest(1, (select count(distinct s.owner_id) from public.world_character_statuses s where s.status_key = 'yohwa')::int / (ru ->> 'cap_div')::int);$a$,
  $b$cap := greatest(0, (select count(distinct s.owner_id) from public.world_character_statuses s where s.status_key = 'yohwa')::int / (ru ->> 'cap_div')::int - coalesce((ru ->> 'cap_minus')::int, 0));$b$]);

update public.world_app_meta set value = '20261112000000' where key = 'db_version';
