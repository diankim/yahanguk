create index if not exists idx_world_events_combat_monster on public.world_events (actor_id, (payload ->> 'monster_id'), created_at) where event_type = 'combat';

do $m$
declare s text := pg_get_functiondef('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)'::regprocedure);
  r1 text := $a$(select n.region_id from public.world_exploration_nodes n
                                   where n.node_id = case when e.payload ->> 'node_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (e.payload ->> 'node_id')::uuid end)
                                 in (select jsonb_array_elements_text(p_task -> 'r'))$a$;
  r2 text := $b$(select n.region_id from public.world_exploration_nodes n
                                          where n.node_id = case when e.payload ->> 'node_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (e.payload ->> 'node_id')::uuid end)
                                        in (select jsonb_array_elements_text(p_task -> 'r'))$b$;
  rn text := $c$lower(e.payload ->> 'node_id') = any (array(select n.node_id::text from public.world_exploration_nodes n where n.region_id in (select jsonb_array_elements_text(p_task -> 'r'))))$c$;
  w1 text := $d$    when p_task ->> 't' = 'win' then (select count(*)::int from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'combat' and coalesce((e.payload ->> 'defeated')::boolean, false)
$d$;
  wn text := $e$    when p_task ->> 't' = 'win' and p_task ? 'm' then (select count(*)::int from public.world_events e
     where e.actor_id = p_uid and e.event_type = 'combat' and e.payload ->> 'monster_id' = any (array(select jsonb_array_elements_text(p_task -> 'm'))) and e.created_at >= p_since
       and coalesce((e.payload ->> 'defeated')::boolean, false)
       and (not p_task ? 'r' or e.payload ->> 'region_id' in (select jsonb_array_elements_text(p_task -> 'r')))
       and (not p_task ? 'rank' or e.payload ->> 'rank' = p_task ->> 'rank')) + public.world_exp_win_count(p_uid, p_task, p_since)
    when p_task ->> 't' = 'win' then (select count(*)::int from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'combat' and coalesce((e.payload ->> 'defeated')::boolean, false)
$e$;
begin
  if (length(s) - length(replace(s, r1, ''))) / length(r1) <> 1 then raise exception 'task_count 채집 지역 조각(1)이 정확히 한 번 있지 않습니다'; end if;
  if (length(s) - length(replace(s, r2, ''))) / length(r2) <> 1 then raise exception 'task_count 채집 지역 조각(2)이 정확히 한 번 있지 않습니다'; end if;
  if (length(s) - length(replace(s, w1, ''))) / length(w1) <> 1 then raise exception 'task_count 처치 조각이 정확히 한 번 있지 않습니다'; end if;
  execute replace(replace(replace(s, r1, rn), r2, rn), w1, wn);
end $m$;

do $m$
declare s text := pg_get_functiondef('public.world_storage_snapshot()'::regprocedure);
  a0 text := $x0$can boolean := true; why text;$x0$;
  b0 text := $y0$can boolean := true; why text; bused int; bfree int;$y0$;
  a1 text := $x1$  cap := public.world_bag_limit(uid);
$x1$;
  b1 text := $y1$  cap := public.world_bag_limit(uid);
  bused := public.world_bag_count(c.inventory);
  bfree := greatest(0, cap - bused);
$y1$;
  a2 text := $x2$'stack', public.world_item_stack(x.key),
        'room', public.world_bag_room(c.inventory, x.key, cap))$x2$;
  b2 text := $y2$'stack', greatest(1, coalesce(i.stack_size, 1)),
        'room', (case when greatest(0, coalesce((c.inventory ->> x.key)::numeric, 0))::int % greatest(1, coalesce(i.stack_size, 1)) = 0 then 0 else greatest(1, coalesce(i.stack_size, 1)) - greatest(0, coalesce((c.inventory ->> x.key)::numeric, 0))::int % greatest(1, coalesce(i.stack_size, 1)) end) + bfree * greatest(1, coalesce(i.stack_size, 1)))$y2$;
  a3 text := $x3$'bag', jsonb_build_object('used', public.world_bag_count(c.inventory), 'limit', cap)$x3$;
  b3 text := $y3$'bag', jsonb_build_object('used', bused, 'limit', cap)$y3$;
begin
  if (length(s) - length(replace(s, a0, ''))) / length(a0) <> 1 then raise exception 'storage_snapshot 조각 0이 정확히 한 번 있지 않습니다'; end if;
  s := replace(s, a0, b0);
  if (length(s) - length(replace(s, a1, ''))) / length(a1) <> 1 then raise exception 'storage_snapshot 조각 1이 정확히 한 번 있지 않습니다'; end if;
  s := replace(s, a1, b1);
  if (length(s) - length(replace(s, a2, ''))) / length(a2) <> 1 then raise exception 'storage_snapshot 조각 2이 정확히 한 번 있지 않습니다'; end if;
  s := replace(s, a2, b2);
  if (length(s) - length(replace(s, a3, ''))) / length(a3) <> 1 then raise exception 'storage_snapshot 조각 3이 정확히 한 번 있지 않습니다'; end if;
  s := replace(s, a3, b3);
  execute s;
end $m$;

analyze public.world_events;
update public.world_app_meta set value = '20261111030000' where key = 'db_version';
