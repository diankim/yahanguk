create or replace function pg_temp.rf(p_fn regprocedure, p_pairs text[]) returns void language plpgsql as $g$
declare src text := pg_get_functiondef(p_fn); i int; n int;
begin
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(src) - length(replace(src, p_pairs[2 * i - 1], ''))) / greatest(length(p_pairs[2 * i - 1]), 1);
    if n <> 1 then raise exception '% 조각 %: % 번 나옴', p_fn, i, n; end if;
    src := replace(src, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute src;
end $g$;

select pg_temp.rf((select oid from pg_proc where proname = 'world_quest_board' and pronamespace = 'public'::regnamespace)::regprocedure, array[
$o$              and public.world_quest_first_tasks(x.quest_id)
            order by$o$,
$n$              and (public.world_quest_first_tasks(x.quest_id) or x.kind = 'main' or x.quest_id = 'fq_sealed_lord' or x.quest_id ~ '^(gq|mkq|mdq)_[0-9]+$')
            order by$n$,
$o$  where (a.ok or (a.kind = 'main' and a.after <@ dn)) and not (a.ok and public.world_quest_first_tasks(a.quest_id));$o$,
$n$  where (a.ok or (a.kind = 'main' and a.after <@ dn)) and not (a.ok and (public.world_quest_first_tasks(a.quest_id) or a.kind = 'main' or a.quest_id = 'fq_sealed_lord' or a.quest_id ~ '^(gq|mkq|mdq)_[0-9]+$'));$n$]);

update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n- 본편 이야기(홍인사·요인록·묵적록·명등기)는 한 장을 마치면 다음 장이 바로 「진행 중」에 올라옵니다. 어디로 가서 받는지 카드에 보이고, 그곳에서 보고하면 다음 장이 시작됩니다.\n'
 where note_id = '3.5.0' and position('다음 장이 바로 「진행 중」' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124110000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
