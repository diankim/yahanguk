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

create or replace function pg_temp.yh_lt_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname in ('service_role', 'postgres') loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function public.world_lantern_rules()
 returns jsonb language sql immutable set search_path to '' as $f$
  select jsonb_build_object(
    'body_max', 60,
    'day', jsonb_build_object('send', 3, 'catch', 1),
    'days', 7,
    'shapes', jsonb_build_array(
      jsonb_build_object('key', 'round', 'name', '둥근 등'), jsonb_build_object('key', 'cho', 'name', '청사초롱'),
      jsonb_build_object('key', 'lotus', 'name', '연꽃 등'), jsonb_build_object('key', 'fish', 'name', '물고기 등')),
    'colors', jsonb_build_array(
      jsonb_build_object('key', 'red', 'name', '붉은'), jsonb_build_object('key', 'blue', 'name', '푸른'),
      jsonb_build_object('key', 'yellow', 'name', '노란'), jsonb_build_object('key', 'white', 'name', '흰')),
    'start', jsonb_build_object('shape', 'round', 'color', 'red'),
    'reply', jsonb_build_object('one', true, 'counts_send', true, 'at_port', true),
    'list', jsonb_build_object('sent', 20, 'caught', 40, 'replies', 30),
    'hanger', jsonb_build_object('item', 'hf_lantern_hanger', 'n', 5),
    'titles', jsonb_build_array(
      jsonb_build_object('key', 'lt_catch1', 'name', '첫 등불을 건진 손', 'by', 'caught', 'n', 1, 'grade', 1, 'hidden', false,
        'desc', '항구 물가에서 처음으로 남의 등불을 건졌습니다.', 'cond', '등불 편지를 1번 건진다'),
      jsonb_build_object('key', 'lt_catch10', 'name', '물가의 등불 줍는 이', 'by', 'caught', 'n', 10, 'grade', 2, 'hidden', false,
        'desc', '여러 항구에서 떠도는 등불을 건져 읽었습니다.', 'cond', '등불 편지를 10번 건진다'),
      jsonb_build_object('key', 'lt_catch30', 'name', '떠도는 불빛의 벗', 'by', 'caught', 'n', 30, 'grade', 3, 'hidden', false,
        'desc', '이름 모를 이들의 등불을 서른 번 건져 올렸습니다.', 'cond', '등불 편지를 30번 건진다'),
      jsonb_build_object('key', 'lt_book16', 'name', '등불첩을 채운 이', 'by', 'book', 'n', 16, 'grade', 3, 'hidden', true,
        'desc', '등불첩 열여섯 칸을 모두 채웠습니다.', 'cond', '등불첩 16칸을 모두 연다'))
  )
$f$;
revoke all on function public.world_lantern_rules() from public, anon;
grant execute on function public.world_lantern_rules() to authenticated, service_role;
do $$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' loop
    execute format('grant execute on function public.world_lantern_rules() to %I', x);
  end loop;
end $$;

select pg_temp.yh_fix('world_rate_rules', array[$a$'raid_ms', 1000)$a$, $a$'raid_ms', 1000, 'lantern_ms', 1500)$a$]);
