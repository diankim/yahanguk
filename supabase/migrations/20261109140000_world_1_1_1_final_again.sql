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

select pg_temp.yh_fix('world_quest_board', array[
$q$'here_id', here_id, 'level', c.level);$q$,
$q$'here_id', here_id, 'level', c.level, 'final_again', 'fq_sealed_lord' = any(dn));$q$], 1);

update public.world_patch_notes set body = body || E'\n- 「구중 봉주」 퀘스트를 마친 뒤에도 구중 봉연의 퀘스트 칸에서 결전에 다시 도전할 수 있습니다(다시 이기면 100전과 봉연 조각).'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109140000' where key = 'db_version';
