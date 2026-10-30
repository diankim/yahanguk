-- 7.3.3 「맡은 일의 실마리」가 끝없이 나오던 것(제보 34)
--   world_pending_clue_task는 퀘스트·세력 장면에 「단서 찾기」(clue) 할 일이 있기만 하면 참이라, 이미 다 찾은 뒤에도
--   탐색마다 단서 무게가 붙어 「맡은 일의 실마리」만 연달아 나왔다(6.1.4부터, 감각·조사 숙련이 높을수록 심함).
--   이제 그 할 일을 아직 다 채우지 못했을 때만(센 수 < n) 참이다.
create or replace function public.world_pending_clue_task(p_uid uuid, p_region text) returns boolean
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
#variable_conflict use_column
begin
  return (select * from (select exists (
      select 1 from public.world_quest_progress p
        join public.world_quest_steps s on s.quest_id = p.quest_id and s.step = p.step + 1
        cross join lateral jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t
       where p.owner_id = p_uid and p.done_at is null and t ->> 't' = 'clue'
         and (not t ? 'r' or t -> 'r' ? p_region)
         and public.world_quest_task_count(p_uid, t, coalesce(p.step_started_at, p.started_at)) < coalesce((t ->> 'n')::int, 1))
    or exists (
      select 1 from public.world_faction_progress fp
        join public.world_faction_scenes fs on fs.faction_id = fp.faction_id
        cross join lateral jsonb_array_elements(coalesce(fs.need -> 'tasks', '[]'::jsonb)) t
       where fp.owner_id = p_uid and t ->> 't' = 'clue' and (not t ? 'r' or t -> 'r' ? p_region)
         and ((fs.kind = 'join' and fp.join_done_at is null and fs.step between fp.join_step - 1 and fp.join_step + 1)
           or (fs.kind = 'rank' and fs.step = coalesce(fp.rank, 1) + 1))
         and public.world_faction_task_count(p_uid, t, coalesce(fp.step_started_at, fp.joined_at, fp.updated_at)) < coalesce((t ->> 'n')::int, 1))
) yhq limit 1);
end
$function$;

update public.world_patch_notes set body = body || $n$
## 7.3.3
- 퀘스트의 「단서 찾기」를 이미 채운 뒤에도 탐색할 때마다 「맡은 일의 실마리」만 연달아 나오던 것을 고쳤습니다. 이제 아직 채우지 못한 단서 할 일이 있을 때만 나옵니다. (제보 고맙습니다)
- 모임 채팅에서 몇 시간 전 말이 새 말 아래로 끌려 올라와 섞이던 것을 고쳤습니다. 이제 늘 보낸 시각 순서대로 보입니다. (제보 고맙습니다)
$n$ where note_id = '7.2.0' and position('## 7.3.3' in body) = 0;
update public.world_app_meta set value = '20261103170000' where key = 'db_version';
