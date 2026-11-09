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
select pg_temp.yh_fix('world_chat_send', array[$q$  select count(*) into day_count from public.world_chat_messages where sender_id=uid and channel_type='global' and created_at>=date_trunc('day',now());
  if day_count>=50 then raise exception '전체 채팅은 하루 50회까지 보낼 수 있어요.'; end if;$q$, $q$  null;$q$], 1);


update public.world_patch_notes set body = body || E'\n- 전체 채팅 하루 50회 제한을 없앴습니다(도배 방지 2초 간격은 그대로).'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109040000' where key = 'db_version';
