select pg_temp.yh_patch('public.world_quest_step_state(uuid,text)',
  $o$nsteps int; since timestamptz; rp$o$,
  $n$nsteps int; since timestamptz; live boolean; rp$n$);
select pg_temp.yh_patch('public.world_quest_step_state(uuid,text)',
  $o$  since := coalesce(g.step_started_at, now());$o$,
  $n$  since := g.step_started_at; live := g.owner_id is not null;
  if not live and cardinality(coalesce(q.after, '{}'::text[])) > 0 then
    select max(d.done_at) into since from public.world_quest_progress d where d.owner_id = p_uid and d.quest_id = any (q.after) and d.done_at is not null;
    live := since is not null and (select count(*) from public.world_quest_progress d where d.owner_id = p_uid and d.quest_id = any (q.after) and d.done_at is not null) = cardinality(q.after);
  end if;
  since := coalesce(since, now());$n$);
select pg_temp.yh_patch('public.world_quest_step_state(uuid,text)',
  $o$t := public.world_task_row(p_uid, t, since, c.location, g.owner_id is not null);$o$,
  $n$t := public.world_task_row(p_uid, t, since, c.location, live);$n$);

select pg_temp.yh_patch('public.world_quest_report(text)',
  $o$msg := msg || '경험치 ' || (gx ->> 'xp') || ' · '; end if;$o$,
  $n$if (gx ->> 'xp')::int > 0 then msg := msg || '경험치 ' || (gx ->> 'xp') || ' · '; end if; end if;$n$);

select pg_temp.yh_patch('public.world_quest_task_label(jsonb)',
  $o$    when p_task ->> 't' = 'win' and p_task ? 'm' then
      (select string_agg$o$,
  $n$    when p_task ->> 't' = 'win' and p_task ? 'm' then
      coalesce((select string_agg(x.region_name, '·') || '에서 ' from public.world_map_regions x where x.region_id in (select jsonb_array_elements_text(p_task -> 'r'))), '') ||
      (select string_agg$n$);

select pg_temp.yh_patch('public.world_faction_task_label(jsonb)', $o$분 넘게)$o$, $n$분 이상)$n$);
