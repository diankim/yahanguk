create or replace function public.world_sys_chat_names()
 returns text[] language sql immutable
as $f$ select array['구조 알림', '세력 소식', '봉연 소식', '비무 소식', '연리 소식'] $f$;
revoke all on function public.world_sys_chat_names() from public, anon, authenticated;
grant execute on function public.world_sys_chat_names() to fn_owner_19111;

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

select pg_temp.yh_fix('world_create_character_v2', array[
$q$  if nm !~ '^[가-힣A-Za-z0-9 ]+$' then raise exception '이름에는 한글·영문·숫자·공백만 사용할 수 있습니다.'; end if;$q$,
$q$  if nm !~ '^[가-힣A-Za-z0-9 ]+$' then raise exception '이름에는 한글·영문·숫자·공백만 사용할 수 있습니다.'; end if;
  if replace(nm, ' ', '') = any (select replace(x, ' ', '') from unnest(public.world_sys_chat_names()) x) then raise exception '채팅 알림에 쓰는 이름이라 고를 수 없습니다.'; end if;$q$], 1);

update public.world_patch_notes set body = body || E'\n- 주간 세력 정산·비무회·혼례 소식도 채팅에서 다른 알림과 같은 알림 줄로 보입니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109100000' where key = 'db_version';
