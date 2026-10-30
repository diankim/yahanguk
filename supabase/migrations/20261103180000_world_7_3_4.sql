-- 7.3.4 묶음
-- ① 퀘스트 「○○ 만들기」(craft, 물품 지정)를 만든 횟수가 아니라 만든 개수로 센다(제보 35).
--    노정 건량은 한 번에 3개(고품질이면 더) 나오는데 「3개 만들기」가 제작 3번으로 세어져 9개 넘게 만들어야 했다.
--    물품을 정한 채집(6.1.1)과 같은 방식. 물품을 정하지 않은 제작(분야만)은 지금처럼 횟수.

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;

select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  '    when p_task ->> ''t'' = ''win'' then (select count(*)::int from public.world_events e',
  '    -- 제작(물품 지정): 만든 개수(7.3.4, 제보 35)
    when p_task ->> ''t'' = ''craft'' and p_task ? ''items'' then (
    select coalesce(sum(greatest(1, coalesce((e.payload ->> ''qty'')::int, 1))), 0)::int from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = ''craft''
       and e.payload ->> ''output'' in (select jsonb_array_elements_text(p_task -> ''items''))
       and (not p_task ? ''field'' or exists (select 1 from public.world_crafting_recipes cr where cr.recipe_id = e.payload ->> ''recipe'' and cr.craft_field = p_task ->> ''field'')))
    when p_task ->> ''t'' = ''win'' then (select count(*)::int from public.world_events e');

update public.world_patch_notes set body = body || $n$
## 7.3.4
- 퀘스트의 「○○ 만들기」가 만든 횟수로 세어지던 것을 만든 개수로 세게 고쳤습니다. 노정 건량처럼 한 번에 여러 개 나오는 물품은 이제 필요한 개수만큼만 만들면 됩니다. (제보 고맙습니다)
- 설정 › 소리 맨 위에 「전체 음량」을 더했습니다. 배경음악·환경음·효과음(컷씬 음악 포함)을 한꺼번에 올리고 내립니다.
$n$ where note_id = '7.2.0' and position('## 7.3.4' in body) = 0;
update public.world_app_meta set value = '20261103180000' where key = 'db_version';
