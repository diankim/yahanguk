do $m$
declare s text := pg_get_functiondef('public.world_pfight_join(uuid)'::regprocedure);
  a text := $a$  select * into c from public.world_characters where owner_id = uid for update;
  perform public.world_stamina_change(uid, -1);
  select * into la from public.world_active_encounters where owner_id = f.leader_id;
$a$;
  b text := $b$  select * into c from public.world_characters where owner_id = uid for update;
  select * into la from public.world_active_encounters where owner_id = f.leader_id;
  if la.node_id is not null and c.level < coalesce((select n.min_level from public.world_exploration_nodes n where n.node_id = la.node_id), 0) then
    raise exception '이 싸움이 벌어진 곳은 Lv.%부터 들어갈 수 있어 함께 싸울 수 없습니다.', (select n.min_level from public.world_exploration_nodes n where n.node_id = la.node_id) using hint = 'node_level';
  end if;
  perform public.world_stamina_change(uid, -1);
$b$;
begin
  if (length(s) - length(replace(s, a, ''))) / length(a) <> 1 then raise exception 'pfight_join 조각이 정확히 한 번 있지 않습니다'; end if;
  execute replace(s, a, b);
end $m$;
