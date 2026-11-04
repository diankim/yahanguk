CREATE OR REPLACE FUNCTION public.world_quest_board()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; q record; st jsonb; act jsonb := '[]'::jsonb; avail jsonb := '[]'::jsonb;
  here_id text; ok boolean; nsteps int; clues jsonb; ndone int := 0; ntotal int := 0; fac jsonb; dn text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select region_id into here_id from public.world_map_regions where region_name = c.location limit 1;
  dn := array(
    select x.quest_id
    from public.world_quests x
    where
      (left(x.quest_id, 3) = 'mq_' and exists (
        select 1
        from public.world_case_progress p
        where p.owner_id = uid
          and p.case_id = substr(x.quest_id, 4)
          and (
            p.combined ? (p.case_id || '_completed')
            or (p.case_id = 'red_seal' and p.combined ? 'redseal_case_completed')
          )
      ))
      or
      (left(x.quest_id, 3) <> 'mq_' and exists (
        select 1
        from public.world_quest_progress g
        where g.owner_id = uid
          and g.quest_id = x.quest_id
          and g.done_at is not null
      ))
  );
  for q in
    select x.*, g.step gstep, g.done_at, g.owner_id has_prog, m.region_name,
           (select count(*) from public.world_quest_steps s where s.quest_id = x.quest_id) nst
    from public.world_quests x
    left join public.world_quest_progress g on g.quest_id = x.quest_id and g.owner_id = uid
    left join public.world_map_regions m on m.region_id = x.region_id
    where x.active
      and (x.job_key is null or x.job_key = c.job_key)
      and (x.faction_key is null or x.faction_key = c.faction_key)
    order by (x.kind = 'main') desc, x.min_level, x.sort, x.quest_id
  loop
    ntotal := ntotal + 1;
    if q.quest_id = any(dn) then ndone := ndone + 1; continue; end if;
    nsteps := q.nst;
    if q.has_prog is not null and coalesce(q.gstep, 0) >= 1 then
      if q.kind = 'main' and coalesce(q.gstep, 0) >= nsteps then
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
        act := act || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'clues', 'clues', clues,
          'step', nsteps, 'steps', nsteps);
      else
        st := public.world_quest_step_state(uid, q.quest_id);
        act := act || (jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'step') || coalesce(st, '{}'::jsonb) || jsonb_build_object('title', q.title, 'step_title', st ->> 'title'));
      end if;
    else
      ok := c.level >= q.min_level and q.after <@ dn;
      if ok or (q.kind = 'main' and q.after <@ dn) then
        avail := avail || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary,
          'region_id', q.region_id, 'region_name', q.region_name, 'min_level', q.min_level, 'locked', not ok, 'here', q.region_id = here_id, 'steps', nsteps);
      end if;
    end if;
  end loop;
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
  return jsonb_build_object('active', act, 'available', avail, 'faction', fac, 'done', ndone, 'total', ntotal, 'here_id', here_id, 'level', c.level);
end
$function$;

create or replace function public.world_source_region_ok(p_kind text, p_safe boolean, p_active boolean) returns boolean
language sql immutable as $f$
  select coalesce(p_active, true) and (p_kind = 'fish' or not coalesce(p_safe, false))
$f$;
revoke all on function public.world_source_region_ok(text, boolean, boolean) from public, anon, authenticated;
grant execute on function public.world_source_region_ok(text, boolean, boolean) to fn_owner_field, postgres, service_role;

CREATE OR REPLACE FUNCTION public.world_item_sources_all(p_item text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  with g as (select distinct r.region_name, r.min_level from public.world_gathering_spots s join public.world_exploration_nodes n on n.node_id = s.node_id
               join public.world_map_regions r on r.region_id = n.region_id where s.active and p_item = any (s.loot_items) and public.world_source_region_ok('gather', r.is_safe_zone, r.active)),
       t as (select distinct r.region_name, r.min_level from public.world_region_sites s join public.world_map_regions r using (region_id)
               where s.active and (s.loot_table ? p_item or s.bonus_item = p_item) and public.world_source_region_ok('sites', r.is_safe_zone, r.active)),
       m as (select distinct r.region_name, r.min_level from public.world_region_monsters x join public.world_map_regions r using (region_id) where x.drops ? p_item and public.world_source_region_ok('monsters', r.is_safe_zone, r.active)),
       f as (select distinct r.region_name, r.min_level from public.world_fish_species sp join public.world_fish_grounds fg on fg.habitat = sp.habitat
               join public.world_map_regions r on r.region_id = fg.region_id where sp.fish_id = p_item and sp.active and (sp.grounds is null or fg.region_id = any(sp.grounds)) and public.world_source_region_ok('fish', r.is_safe_zone, r.active))
  select jsonb_build_object(
    'gather', (select coalesce(jsonb_agg(region_name order by min_level, region_name), '[]') from (select * from g order by min_level, region_name) x), 'gather_n', (select count(*) from g),
    'sites', (select coalesce(jsonb_agg(region_name order by min_level, region_name), '[]') from (select * from t order by min_level, region_name) x), 'sites_n', (select count(*) from t),
    'monsters', (select coalesce(jsonb_agg(region_name order by min_level, region_name), '[]') from (select * from m order by min_level, region_name) x), 'monsters_n', (select count(*) from m),
    'fish', (select coalesce(jsonb_agg(region_name order by min_level, region_name), '[]') from (select * from f order by min_level, region_name) x), 'fish_n', (select count(*) from f),
    'craft', exists (select 1 from public.world_crafting_recipes where output_item = public.world_item_base(p_item)), 'hq', p_item like '%\_hq',
    'shop', exists (select 1 from public.world_shop_catalog where item_id = p_item and shop_id <> 'smithy'),
    'smithy', exists (select 1 from public.world_shop_catalog where item_id = p_item and shop_id = 'smithy'),
    'vault', exists (select 1 from public.world_faction_vault where item_id = p_item))
$function$;

CREATE OR REPLACE FUNCTION public.world_gather_codex_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object(
    'items', (with it as (
        select x as item_id, min(s.category) as cat, min(s.min_level) as lv,
          (select jsonb_agg(z.n order by z.l) from (select distinct r2.region_name as n, coalesce(r2.min_level, 1) as l from public.world_gathering_spots s2
             join public.world_exploration_nodes n2 on n2.node_id = s2.node_id join public.world_map_regions r2 on r2.region_id = n2.region_id
            where s2.active and x = any (s2.loot_items) and public.world_source_region_ok('gather', r2.is_safe_zone, r2.active) order by 2 limit 6) z) as regions
          from public.world_gathering_spots s, unnest(s.loot_items) x where s.active group by x),
      got as (select e.payload ->> 'item_id' as item_id, count(*) as n, sum(coalesce((e.payload ->> 'qty')::int, 1)) as q
          from public.world_events e where e.actor_id = uid and e.event_type = 'gather' and e.payload ? 'item_id' group by 1)
      select jsonb_agg(case when g.item_id is null then jsonb_build_object('known', false, 'cat', it.cat, 'level', it.lv)
          else jsonb_build_object('known', true, 'id', it.item_id, 'name', coalesce(ic.item_name, it.item_id), 'desc', ic.description, 'cat', it.cat, 'level', it.lv,
            'regions', it.regions,
            'spots', (select jsonb_agg(jsonb_build_object('r', rr.n, 'l', rr.l, 'c', rr.c, 'fc', rr.fc, 's', rr.s) order by rr.l, rr.n) from (
              select q.n, min(q.l) as l, count(*) as c, count(*) filter (where q.f) as fc,
                jsonb_path_query_array(jsonb_agg(jsonb_build_object('n', q.sn, 'lv', q.lv, 'f', q.f) order by q.f desc, q.lv, q.sn), '$[0 to 3]') as s
                from (select r2.region_name as n, coalesce(r2.min_level, 1) as l, s2.spot_name as sn, s2.min_level as lv,
                        exists (select 1 from public.world_gathering_discoveries d2 where d2.owner_id = uid and d2.spot_id = s2.spot_id) as f
                        from public.world_gathering_spots s2 join public.world_exploration_nodes n2 on n2.node_id = s2.node_id
                        join public.world_map_regions r2 on r2.region_id = n2.region_id
                       where s2.active and it.item_id = any (s2.loot_items) and public.world_source_region_ok('gather', r2.is_safe_zone, r2.active)) q
               group by q.n order by 2, 1 limit 8) rr), 'count', g.n, 'qty', g.q) end order by it.cat, it.lv, it.item_id)
        from it left join got g on g.item_id = it.item_id left join public.world_item_catalog ic on ic.item_id = it.item_id),
    'titles', (select jsonb_agg(jsonb_build_object('name', tc.title_name, 'condition', tc.condition_text, 'earned', ct.title_key is not null,
        'progress', public.world_codex_rule_count(uid, tc.rule), 'need', (tc.rule ->> 'n')::int) order by tc.sort)
      from public.world_title_catalog tc left join public.world_character_titles ct on ct.owner_id = uid and ct.title_key = tc.title_key
      where tc.active and tc.rule ->> 'codex' = 'gather'));
end $function$;

create or replace function public.world_exp_task_count(p_uid uuid, p_task jsonb, p_since timestamptz) returns integer
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
#variable_conflict use_column
begin
  if p_uid is null or p_since is null then return 0; end if;
  if p_task ->> 't' = 'win' then
    return (select * from (select count(*)::int from public.world_expeditions x, jsonb_array_elements(coalesce(x.journal, '[]'::jsonb)) j
      where x.owner_id = p_uid and x.status = 'done' and x.finished_at >= p_since
        and j ->> 'kind' = 'win' and j ? 'mid' and j ->> 'owner' = p_uid::text
        and (not p_task ? 'm' or j ->> 'mid' in (select jsonb_array_elements_text(p_task -> 'm')))
        and (not p_task ? 'r' or j ->> 'rg' in (select jsonb_array_elements_text(p_task -> 'r')))
        and (not p_task ? 'rank' or j ->> 'rank' = p_task ->> 'rank')) yhq limit 1);
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
end $f$;
revoke all on function public.world_exp_task_count(uuid, jsonb, timestamptz) from public, anon, authenticated;
grant execute on function public.world_exp_task_count(uuid, jsonb, timestamptz) to fn_owner_field, postgres, service_role;

create or replace function public.world_exp_gather_count(p_uid uuid, p_task jsonb, p_since timestamptz) returns integer
language sql stable as $f$ select public.world_exp_task_count(p_uid, p_task || '{"t":"gather"}'::jsonb, p_since) $f$;
revoke all on function public.world_exp_gather_count(uuid, jsonb, timestamptz) from public, anon, authenticated;
grant execute on function public.world_exp_gather_count(uuid, jsonb, timestamptz) to fn_owner_field, postgres, service_role;

create or replace function public.world_exp_win_count(p_uid uuid, p_task jsonb, p_since timestamptz) returns integer
language sql stable as $f$ select public.world_exp_task_count(p_uid, p_task || '{"t":"win"}'::jsonb, p_since) $f$;

CREATE OR REPLACE FUNCTION public.world_quest_task_count(p_uid uuid, p_task jsonb, p_since timestamp with time zone)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
#variable_conflict use_column
begin
  return (select * from (select case when p_task ->> 't' = 'gw' then (select count(*)::int from public.world_gw_members m join public.world_gw_fights x on x.fight_id = m.fight_id
                where m.owner_id = p_uid and x.status = 'won' and m.acts > 0 and x.ended_at >= p_since)
    when p_task ->> 't' = 'raid' then (select count(*)::int from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id
                where m.owner_id = p_uid and r.kind = coalesce(p_task ->> 'kind', 'final') and r.status = 'won' and m.acts > 0 and r.ended_at >= p_since)
    when p_task ->> 't' = 'gather' and p_task ? 'items' then (
    select coalesce(sum(
        (case when e.payload ->> 'item_id' in (select jsonb_array_elements_text(p_task -> 'items')) then greatest(1, coalesce((e.payload ->> 'qty')::int, 1)) else 0 end)
      + coalesce((select sum((x.value)::text::int) from jsonb_each(case when jsonb_typeof(e.payload -> 'extra') = 'object' then e.payload -> 'extra' else '{}'::jsonb end) x
                   where jsonb_typeof(x.value) = 'number' and x.key in (select jsonb_array_elements_text(p_task -> 'items'))), 0)), 0)::int
      from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'gather'
       and (not p_task ? 'r' or (select n.region_id from public.world_exploration_nodes n
                                   where n.node_id = case when e.payload ->> 'node_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (e.payload ->> 'node_id')::uuid end)
                                 in (select jsonb_array_elements_text(p_task -> 'r')))) + public.world_exp_gather_count(p_uid, p_task, p_since)
    when p_task ->> 't' = 'craft' and p_task ? 'items' then (
    select coalesce(sum(greatest(1, coalesce((e.payload ->> 'qty')::int, 1))), 0)::int from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'craft'
       and e.payload ->> 'output' in (select jsonb_array_elements_text(p_task -> 'items'))
       and (not p_task ? 'field' or exists (select 1 from public.world_crafting_recipes cr where cr.recipe_id = e.payload ->> 'recipe' and cr.craft_field = p_task ->> 'field')))
    when p_task ->> 't' = 'win' then (select count(*)::int from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'combat' and coalesce((e.payload ->> 'defeated')::boolean, false)
       and (not p_task ? 'm' or e.payload ->> 'monster_id' in (select jsonb_array_elements_text(p_task -> 'm')))
       and (not p_task ? 'r' or e.payload ->> 'region_id' in (select jsonb_array_elements_text(p_task -> 'r')))
       and (not p_task ? 'rank' or e.payload ->> 'rank' = p_task ->> 'rank')) + public.world_exp_win_count(p_uid, p_task, p_since)
    when p_task ->> 't' in ('win', 'gather', 'craft', 'fish') then (
    select count(*)::int from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since
       and e.event_type = case p_task ->> 't' when 'win' then 'combat' when 'gather' then 'gather' when 'craft' then 'craft' else 'fish' end
       and case p_task ->> 't'
             when 'win' then coalesce((e.payload ->> 'defeated')::boolean, false)
               and (not p_task ? 'm' or e.payload ->> 'monster_id' in (select jsonb_array_elements_text(p_task -> 'm')))
               and (not p_task ? 'r' or e.payload ->> 'region_id' in (select jsonb_array_elements_text(p_task -> 'r')))
               and (not p_task ? 'rank' or e.payload ->> 'rank' = p_task ->> 'rank')
             when 'gather' then (not p_task ? 'items' or e.payload ->> 'item_id' in (select jsonb_array_elements_text(p_task -> 'items')))
               and (not p_task ? 'r' or (select n.region_id from public.world_exploration_nodes n
                                          where n.node_id = case when e.payload ->> 'node_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (e.payload ->> 'node_id')::uuid end)
                                        in (select jsonb_array_elements_text(p_task -> 'r')))
             when 'craft' then (not p_task ? 'items' or e.payload ->> 'output' in (select jsonb_array_elements_text(p_task -> 'items')))
               and (not p_task ? 'field' or exists (select 1 from public.world_crafting_recipes cr where cr.recipe_id = e.payload ->> 'recipe' and cr.craft_field = p_task ->> 'field'))
             else coalesce((e.payload ->> 'caught')::boolean, false)
               and (not p_task ? 'r' or e.payload ->> 'region_id' in (select jsonb_array_elements_text(p_task -> 'r'))) end)
      + case when p_task ->> 't' = 'gather' then public.world_exp_gather_count(p_uid, p_task, p_since) else 0 end
    else public.world_faction_task_count(p_uid, p_task, p_since) end
) yhq limit 1);
end
$function$;

CREATE OR REPLACE FUNCTION public.world_faction_task_count(p_uid uuid, p_task jsonb, p_since timestamp with time zone)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
#variable_conflict use_column
begin
  return (select * from (with ev as (
    select e.payload, case when p_task ? 'r' or p_task ? 'safe' or coalesce((p_task ->> 'distinct')::boolean, false) then coalesce(e.payload ->> 'region_id',
      (select n.region_id from public.world_exploration_nodes n
        where n.node_id = case when e.payload ->> 'node_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (e.payload ->> 'node_id')::uuid end)) end region
      from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since
       and e.event_type = case p_task ->> 't' when 'search' then 'explore' when 'clue' then 'explore' when 'win' then 'combat' when 'gather' then 'gather'
                            when 'travel' then 'travel' when 'expedition' then 'expedition_end' when 'sell' then 'shop_sell' when 'trade' then 'trade' when 'craft' then 'craft' end
  ), ok as (
    select ev.region from ev
     where case p_task ->> 't'
             when 'search' then ev.payload ->> 'kind' = 'field_search'
             when 'clue' then ev.payload ->> 'kind' = 'field_search' and ev.payload ->> 'outcome' = 'clue'
             when 'win' then coalesce((ev.payload ->> 'defeated')::boolean, false)
             when 'travel' then ev.payload ? 'travel_history_id'
             when 'expedition' then ev.payload ->> 'ended' = 'complete'
             else true end
       and (not p_task ? 'r' or ev.region in (select jsonb_array_elements_text(p_task -> 'r')))
       and (not p_task ? 'rank' or ev.payload ->> 'rank' = p_task ->> 'rank')
       and (not p_task ? 'phase' or ev.payload ->> 'env_phase' in (select jsonb_array_elements_text(p_task -> 'phase')))
       and (not p_task ? 'weather' or ev.payload ->> 'env_weather' in (select jsonb_array_elements_text(p_task -> 'weather')))
       and (not coalesce((p_task ->> 'safe')::boolean, false) or exists (select 1 from public.world_map_regions m where m.region_id = ev.region and m.is_safe_zone))
  )
  select case when coalesce((p_task ->> 'distinct')::boolean, false) then (select count(distinct region) from ok)::int
    else (select count(*) from ok)::int
      + case when p_task ->> 't' = 'win' and not p_task ? 'phase' and not p_task ? 'weather' then public.world_exp_win_count(p_uid, p_task, p_since) else 0 end
      + case when p_task ->> 't' = 'gather' and not p_task ? 'phase' and not p_task ? 'weather' and not p_task ? 'safe' then public.world_exp_gather_count(p_uid, p_task, p_since) else 0 end end
) yhq limit 1);
end
$function$;

do $w$
declare d text; a text; b text; n int;
begin
  d := replace(pg_get_functiondef('public.world_expedition_settle(uuid,integer)'::regprocedure), E'\r\n', E'\n');
  if position('gl := public.world_inv_add(gl' in d) = 0 then
  foreach a in array array['hp int; mn int; er int; wins int;',
    $a$sup := st -> 'sup'; loot := st -> 'loot'; lg := st -> 'log';$a$,
    'gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty);',
    $a$'ended', ended, 'short', short);$a$] loop
    n := (length(d) - length(replace(d, a, ''))) / length(a);
    if n <> 1 then raise exception '1.0.3e world_expedition_settle 기준 문구가 %번 있습니다: %', n, a; end if;
  end loop;
  d := replace(d, 'hp int; mn int; er int; wins int;', 'gl jsonb; hp int; mn int; er int; wins int;');
  d := replace(d, $a$sup := st -> 'sup'; loot := st -> 'loot'; lg := st -> 'log';$a$, $a$sup := st -> 'sup'; loot := st -> 'loot'; lg := st -> 'log'; gl := coalesce(st -> 'gl', '{}'::jsonb);$a$);
  d := replace(d, 'gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty);',
    'gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty); gl := public.world_inv_add(gl, item, qty);');
  d := replace(d, $a$'ended', ended, 'short', short);$a$, $a$'ended', ended, 'short', short, 'gl', gl);$a$);
  execute d;
  end if;

  d := replace(pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure), E'\r\n', E'\n');
  a := $a$'gathers', (st ->> 'gathers')::int, 'progress', prog_after));$a$;
  if position($a$'progress', prog_after, 'region_id', r.region_id,$a$ in d) = 0 then
  n := (length(d) - length(replace(d, a, ''))) / length(a);
  if n <> 1 then raise exception '1.0.3e world_expedition_complete 기준 문구가 %번 있습니다', n; end if;
  execute replace(d, a, $a$'gathers', (st ->> 'gathers')::int, 'progress', prog_after, 'region_id', r.region_id,
      'gl', (select coalesce(jsonb_object_agg(g.key, least(g.value::text::int, coalesce((loot ->> g.key)::int, 0))) filter (where least(g.value::text::int, coalesce((loot ->> g.key)::int, 0)) > 0), '{}'::jsonb)
               from jsonb_each(coalesce(st -> 'gl', '{}'::jsonb)) g where jsonb_typeof(g.value) = 'number')));$a$);
  end if;

  d := replace(pg_get_functiondef('public.world_craft_item(text)'::regprocedure), E'\r\n', E'\n');
  a := 'and (coalesce((c.inventory ->> i.item_id)::numeric, 0) > 0 or exists (select 1 from public.world_character_equipment e where e.owner_id = uid and e.item_id = i.item_id));';
  b := '필요 도구가 가방에 있어야 합니다: %';
  if position('or coalesce((st ->> i.item_id)::numeric, 0) > 0' in d) = 0 then
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 or (length(d) - length(replace(d, b, ''))) / length(b) <> 1 then
    raise exception '1.0.3e world_craft_item 기준 문구가 없습니다'; end if;
  d := replace(d, a, 'and (coalesce((c.inventory ->> i.item_id)::numeric, 0) > 0 or coalesce((st ->> i.item_id)::numeric, 0) > 0 or exists (select 1 from public.world_character_equipment e where e.owner_id = uid and e.item_id = i.item_id));');
  d := replace(d, b, '필요 도구(같은 갈래의 더 높은 단계 도구도 됨)가 가방이나 안전지대 창고에 있어야 합니다: %');
  execute d;
  end if;
end $w$;

update public.world_app_meta set value = '20261105190000' where key = 'db_version';
