select pg_temp.yh_patch('public.world_storage_capacity(uuid)',
  $o$lateral (select 2 * count(*)::int v from public.world_quest_progress g
                   where g.owner_id = p_uid and g.done_at is not null
                     and g.quest_id = any (array['gq_1','gq_2','gq_3','gq_4','gq_5','mkq_1','mkq_2','mkq_3','mkq_4','mkq_5'])) ar,$o$,
  $n$lateral (select coalesce(sum(case when g.quest_id like 'mdq_%' then 3 else 2 end), 0)::int v from public.world_quest_progress g
                   where g.owner_id = p_uid and g.done_at is not null
                     and g.quest_id = any (array['gq_1','gq_2','gq_3','gq_4','gq_5','mkq_1','mkq_2','mkq_3','mkq_4','mkq_5','mdq_3','mdq_6','mdq_9','mdq_12','mdq_15'])) ar,$n$);
