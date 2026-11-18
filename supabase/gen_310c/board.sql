select pg_temp.yh_fix('world_quest_board()', array[
  E'  select coalesce(jsonb_agg(\n    case when jsonb_typeof(a.a1)',
  E'  for q in select x.quest_id, x.kind, x.cat, x.title, x.summary from public.world_quests x
            where x.active and (x.job_key is null or x.job_key = c.job_key) and (x.faction_key is null or x.faction_key = c.faction_key)
              and not (x.quest_id = any(dn)) and c.level >= x.min_level and x.after <@ dn and public.world_quest_gate_ok(x.open_req)
              and not exists (select 1 from public.world_quest_progress g where g.owner_id = uid and g.quest_id = x.quest_id and coalesce(g.step, 0) >= 1)
              and not exists (select 1 from public.world_quest_replays r where r.owner_id = uid and r.quest_id = x.quest_id)
              and public.world_quest_first_tasks(x.quest_id)
            order by (x.kind = ''main'') desc, x.min_level, x.sort, x.quest_id loop
    st := public.world_quest_step_state(uid, q.quest_id);
    acts := acts || (jsonb_build_object(''quest_id'', q.quest_id, ''kind'', q.kind, ''cat'', q.cat, ''title'', q.title, ''summary'', q.summary, ''phase'', ''step'', ''auto'', true)
      || coalesce(st, ''{}''::jsonb) || jsonb_build_object(''title'', q.title, ''step_title'', st ->> ''title''));
  end loop;
  select coalesce(jsonb_agg(
    case when jsonb_typeof(a.a1)',
  E'  where a.ok or (a.kind = ''main'' and a.after <@ dn);',
  E'  where (a.ok or (a.kind = ''main'' and a.after <@ dn)) and not (a.ok and public.world_quest_first_tasks(a.quest_id));'
]);
