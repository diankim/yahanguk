CREATE OR REPLACE FUNCTION public.world_exp_win_lines(p_uid uuid, p_since timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
#variable_conflict use_column
begin
  return (select * from (select coalesce(jsonb_agg(jsonb_build_array(z.m, z.g, z.k, z.f, z.n)), '[]'::jsonb)
    from (select j ->> 'mid' m, j ->> 'rg' g, j ->> 'rank' k, extract(epoch from x.finished_at) f, count(*) n
      from public.world_expeditions x, jsonb_array_elements(coalesce(x.journal, '[]'::jsonb)) j
     where x.owner_id = p_uid and x.status = 'done' and x.finished_at >= p_since
       and j ->> 'kind' = 'win' and j ? 'mid' and j ->> 'owner' = p_uid::text
     group by 1, 2, 3, 4) z) yhq limit 1);
end $function$;

revoke all on function public.world_exp_win_lines(uuid, timestamp with time zone) from public, anon, authenticated;
grant execute on function public.world_exp_win_lines(uuid, timestamp with time zone) to fn_owner_field, service_role;

CREATE OR REPLACE FUNCTION public.world_exp_task_count(p_uid uuid, p_task jsonb, p_since timestamp with time zone)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
#variable_conflict use_column
declare v_c text; v_l jsonb;
begin
  if p_uid is null or p_since is null then return 0; end if;
  if p_task ->> 't' = 'win' then
    v_c := current_setting('yh.exp_wins', true);
    if v_c is not null and length(v_c) > 36 and left(v_c, 36) = p_uid::text then
      v_l := substr(v_c, 37)::jsonb;
    else
      v_l := public.world_exp_win_lines(p_uid, p_since);
    end if;
    return (select coalesce(sum((j ->> 4)::int), 0)::int from jsonb_array_elements(v_l) j
      where (j ->> 3)::numeric >= extract(epoch from p_since)
        and (not p_task ? 'm' or j ->> 0 in (select jsonb_array_elements_text(p_task -> 'm')))
        and (not p_task ? 'r' or j ->> 1 in (select jsonb_array_elements_text(p_task -> 'r')))
        and (not p_task ? 'rank' or j ->> 2 = p_task ->> 'rank'));
  end if;
  if p_task ->> 't' <> 'gather' then return 0; end if;
  return (select * from (select coalesce(sum(case when p_task ? 'items'
      then (select coalesce(sum(x.value::text::int), 0) from jsonb_each(case when jsonb_typeof(e.payload -> 'gl') = 'object' then e.payload -> 'gl' else '{}'::jsonb end) x
             where jsonb_typeof(x.value) = 'number' and x.key in (select jsonb_array_elements_text(p_task -> 'items')))
      else greatest(0, coalesce((e.payload ->> 'gathers')::int, 0)) end), 0)::int
    from public.world_events e
   where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'expedition_end'
     and (not p_task ? 'r' or coalesce(e.payload ->> 'region_id', (select n.region_id from public.world_exploration_nodes n
            where n.node_id = case when e.payload ->> 'node_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (e.payload ->> 'node_id')::uuid end))
          in (select jsonb_array_elements_text(p_task -> 'r')))
) yhq limit 1);
end $function$;

CREATE OR REPLACE FUNCTION public.world_quest_task_count(p_uid uuid, p_task jsonb, p_since timestamp with time zone)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
#variable_conflict use_column
declare tt text := p_task ->> 't'; v_n int;
begin
  if tt is null or p_task ?| array['phase', 'weather', 'safe', 'distinct'] or tt not in ('gw', 'mj', 'raid', 'win', 'gather', 'craft', 'fish') then
    return public.world_faction_task_count(p_uid, p_task, p_since);
  end if;
  if tt in ('gw', 'mj') then
    select count(*)::int into v_n from public.world_gw_members m join public.world_gw_fights x on x.fight_id = m.fight_id
     where m.owner_id = p_uid and x.status = 'won' and m.acts > 0 and x.ended_at >= p_since
       and x.boss_id = case when tt = 'mj' then 'mukjeok' else coalesce(p_task ->> 'boss', 'gwiheo') end
       and (p_task ->> 'mode' = 'any' or x.mode = coalesce(p_task ->> 'mode', 'hard'));
    return v_n;
  end if;
  if tt = 'raid' then
    select count(*)::int into v_n from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id
     where m.owner_id = p_uid and r.kind = coalesce(p_task ->> 'kind', 'final') and r.status = 'won' and m.acts > 0 and r.ended_at >= p_since;
    return v_n;
  end if;
  if tt = 'gather' and p_task ? 'items' then
    select coalesce(sum(
        (case when e.payload ->> 'item_id' in (select jsonb_array_elements_text(p_task -> 'items')) then greatest(1, coalesce((e.payload ->> 'qty')::int, 1)) else 0 end)
      + coalesce((select sum((x.value)::text::int) from jsonb_each(case when jsonb_typeof(e.payload -> 'extra') = 'object' then e.payload -> 'extra' else '{}'::jsonb end) x
                   where jsonb_typeof(x.value) = 'number' and x.key in (select jsonb_array_elements_text(p_task -> 'items'))), 0)), 0)::int into v_n
      from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'gather'
       and (not p_task ? 'r' or lower(e.payload ->> 'node_id') = any (array(select n.node_id::text from public.world_exploration_nodes n where n.region_id = any (array(select jsonb_array_elements_text(p_task -> 'r'))))));
    return v_n + public.world_exp_task_count(p_uid, p_task || '{"t":"gather"}'::jsonb, p_since);
  end if;
  if tt = 'craft' and p_task ? 'items' then
    select coalesce(sum(greatest(1, coalesce((e.payload ->> 'qty')::int, 1))), 0)::int into v_n from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'craft'
       and e.payload ->> 'output' in (select jsonb_array_elements_text(p_task -> 'items'))
       and (not p_task ? 'field' or exists (select 1 from public.world_crafting_recipes cr where cr.recipe_id = e.payload ->> 'recipe' and cr.craft_field = p_task ->> 'field'));
    return v_n;
  end if;
  if tt = 'win' and p_task ? 'm' then
    select count(*)::int into v_n from public.world_events e
     where e.actor_id = p_uid and e.event_type = 'combat' and e.payload ->> 'monster_id' = any (array(select jsonb_array_elements_text(p_task -> 'm'))) and e.created_at >= p_since
       and coalesce((e.payload ->> 'defeated')::boolean, false)
       and (not p_task ? 'r' or e.payload ->> 'region_id' in (select jsonb_array_elements_text(p_task -> 'r')))
       and (not p_task ? 'rank' or e.payload ->> 'rank' = p_task ->> 'rank');
    return v_n + public.world_exp_task_count(p_uid, p_task || '{"t":"win"}'::jsonb, p_since);
  end if;
  if tt = 'win' then
    select count(*)::int into v_n from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'combat' and coalesce((e.payload ->> 'defeated')::boolean, false)
       and (not p_task ? 'r' or e.payload ->> 'region_id' in (select jsonb_array_elements_text(p_task -> 'r')))
       and (not p_task ? 'rank' or e.payload ->> 'rank' = p_task ->> 'rank');
    return v_n + public.world_exp_task_count(p_uid, p_task || '{"t":"win"}'::jsonb, p_since);
  end if;
  if tt = 'gather' then
    select count(*)::int into v_n from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'gather'
       and (not p_task ? 'r' or lower(e.payload ->> 'node_id') = any (array(select n.node_id::text from public.world_exploration_nodes n where n.region_id = any (array(select jsonb_array_elements_text(p_task -> 'r'))))));
    return v_n + public.world_exp_task_count(p_uid, p_task || '{"t":"gather"}'::jsonb, p_since);
  end if;
  if tt = 'craft' then
    select count(*)::int into v_n from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'craft'
       and (not p_task ? 'field' or exists (select 1 from public.world_crafting_recipes cr where cr.recipe_id = e.payload ->> 'recipe' and cr.craft_field = p_task ->> 'field'));
    return v_n;
  end if;
  if tt <> 'fish' then
    return public.world_faction_task_count(p_uid, p_task, p_since);
  end if;
  select count(*)::int into v_n from public.world_events e
   where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'fish'
     and coalesce((e.payload ->> 'caught')::boolean, false)
     and (not p_task ? 'f' or e.payload ->> 'fish' in (select jsonb_array_elements_text(p_task -> 'f')))
     and (not p_task ? 'r' or e.payload ->> 'region_id' in (select jsonb_array_elements_text(p_task -> 'r')));
  return v_n;
end
$function$;

CREATE OR REPLACE FUNCTION public.world_quest_board()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; q record; st jsonb; act jsonb; acts jsonb[] := '{}'; avail jsonb;
  here_id text; clues jsonb; ndone int; ntotal int; fac jsonb; dn text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select region_id into here_id from public.world_map_regions where region_name = c.location limit 1;
  dn := public.world_quest_done_ids(uid);
  perform set_config('yh.exp_wins', uid::text || public.world_exp_win_lines(uid, '-infinity'::timestamptz)::text, true);
  select count(*), count(*) filter (where x.quest_id = any(dn)) into ntotal, ndone
  from public.world_quests x
  where x.active and (x.job_key is null or x.job_key = c.job_key) and (x.faction_key is null or x.faction_key = c.faction_key);
  for q in select * from (select x.quest_id, x.kind, x.cat, x.title, x.summary, x.region_id, m.region_name, x.min_level, x.after, x.chapter_id, g.step gstep, g.owner_id has_prog,
             coalesce((select count(*) from public.world_quest_steps s where s.quest_id = x.quest_id), 0)::int nst,
             (x.kind = 'main') ismain, x.sort, x.quest_id = any(dn) done
      from public.world_quests x
      left join public.world_quest_progress g on g.quest_id = x.quest_id and g.owner_id = uid
      left join public.world_map_regions m on m.region_id = x.region_id
      where x.active
        and (x.job_key is null or x.job_key = c.job_key)
        and (x.faction_key is null or x.faction_key = c.faction_key)) b where not b.done and b.has_prog is not null and coalesce(b.gstep, 0) >= 1
    order by b.ismain desc, b.min_level, b.sort, b.quest_id loop
    if q.kind = 'main' and coalesce(q.gstep, 0) >= q.nst then
      select jsonb_build_object(
        'found', count(*) filter (where exists (
          select 1 from public.world_case_progress p
          where p.owner_id = uid and p.case_id = k.chapter_id
            and p.clues @> jsonb_build_array(jsonb_build_object('id', k.clue_id))
        )),
        'total', count(*),
        'regions', jsonb_agg(distinct k.region_id),
        'region_names', jsonb_agg(distinct (select region_name from public.world_map_regions where region_id = k.region_id))
      )
      into clues
      from public.world_story_clues k
      where k.chapter_id = q.chapter_id;
      acts := acts || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'clues', 'clues', clues,
        'step', q.nst, 'steps', q.nst);
    else
      st := public.world_quest_step_state(uid, q.quest_id);
      acts := acts || (jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'step') || coalesce(st, '{}'::jsonb) || jsonb_build_object('title', q.title, 'step_title', st ->> 'title'));
    end if;
  end loop;
  select coalesce(jsonb_agg(
    case when jsonb_typeof(a.a1) = 'array' and jsonb_array_length(a.a1) > 0 then
      jsonb_build_object('quest_id', a.quest_id, 'kind', a.kind, 'cat', a.cat, 'title', a.title, 'summary', a.summary,
        'region_id', a.a1 ->> 0,
        'region_name', (select string_agg(m.region_name, '·' order by m.region_name) from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(a.a1))),
        'min_level', a.min_level, 'locked', not a.ok, 'here', coalesce(a.a1 ? here_id, false), 'steps', a.nst)
    else
      jsonb_build_object('quest_id', a.quest_id, 'kind', a.kind, 'cat', a.cat, 'title', a.title, 'summary', a.summary,
        'region_id', a.region_id, 'region_name', a.region_name, 'min_level', a.min_level, 'locked', not a.ok, 'here', a.region_id = here_id, 'steps', a.nst)
    end order by a.ismain desc, a.min_level, a.sort, a.quest_id), '[]'::jsonb)
  into avail
  from (
    select b.*, (c.level >= b.min_level and b.after <@ dn) ok,
      (select s.need -> 'at' from public.world_quest_steps s where s.quest_id = b.quest_id and s.step = 1) a1
    from (select x.quest_id, x.kind, x.cat, x.title, x.summary, x.region_id, m.region_name, x.min_level, x.after, x.chapter_id, g.step gstep, g.owner_id has_prog,
             coalesce((select count(*) from public.world_quest_steps s where s.quest_id = x.quest_id), 0)::int nst,
             (x.kind = 'main') ismain, x.sort, x.quest_id = any(dn) done
      from public.world_quests x
      left join public.world_quest_progress g on g.quest_id = x.quest_id and g.owner_id = uid
      left join public.world_map_regions m on m.region_id = x.region_id
      where x.active
        and (x.job_key is null or x.job_key = c.job_key)
        and (x.faction_key is null or x.faction_key = c.faction_key)) b
    where not b.done and not (b.has_prog is not null and coalesce(b.gstep, 0) >= 1)
  ) a
  where a.ok or (a.kind = 'main' and a.after <@ dn);
  if c.major_faction_id is not null and exists (
    select 1 from public.world_faction_progress p
    where p.owner_id = uid and p.faction_id = c.major_faction_id and not p.rejoin_pending
  ) then
    fac := public.world_faction_current(uid, false);
    if fac is not null then
      fac := fac || jsonb_build_object('faction_id', c.major_faction_id,
        'regions', (select coalesce(jsonb_agg(distinct x), '[]'::jsonb)
          from public.world_faction_scenes s,
          lateral (
            select jsonb_array_elements_text(t -> 'r') x
            from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t
            union
            select jsonb_array_elements_text(coalesce(s.need -> 'at', '[]'::jsonb))
          ) z
          where s.scene_key = fac ->> 'scene_key'));
    end if;
  end if;
  perform set_config('yh.exp_wins', '', true);
  act := to_jsonb(acts);
  return jsonb_build_object('active', act, 'available', avail, 'faction', fac, 'done', ndone, 'total', ntotal, 'here_id', here_id, 'level', c.level, 'final_again', 'fq_sealed_lord' = any(dn));
end
$function$

;
