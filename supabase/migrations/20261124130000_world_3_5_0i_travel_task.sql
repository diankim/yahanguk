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

select pg_temp.rf('public.world_task_row(uuid, jsonb, timestamp with time zone, text, boolean)'::regprocedure, array[
$o$            else least((p_task ->> 'n')::int, public.world_quest_task_count(p_uid, p_task, p_since)) end;$o$,
$n$            when p_task ->> 't' = 'travel' and p_task ? 'r' and (select e.payload ->> 'region_id' from public.world_events e
                   where e.actor_id = p_uid and e.event_type = 'travel' and e.created_at <= p_since and e.payload ? 'travel_history_id'
                   order by e.created_at desc limit 1) in (select jsonb_array_elements_text(p_task -> 'r')) then (p_task ->> 'n')::int
            else least((p_task ->> 'n')::int, public.world_quest_task_count(p_uid, p_task, p_since)) end;$n$]);

update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n- 한 장면에 「…에 도착」이 둘 이상인 퀘스트에서, 장면을 받을 때 이미 서 있던 곳의 「도착」이 다른 곳으로 옮기면 0으로 돌아가던 것을 고쳤습니다. 장면을 받을 때 그곳에 있었거나 그 뒤에 한 번이라도 도착했으면 채운 것으로 셉니다.\n'
 where note_id = '3.5.0' and position('도착」이 다른 곳으로 옮기면' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124130000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
