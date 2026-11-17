create or replace function public.world_quest_borrow(p_owner uuid, p_region text) returns text[]
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce(array_agg(distinct x), '{}') from (
    select qp.quest_id, qp.step from public.world_quest_progress qp where qp.owner_id = p_owner and qp.done_at is null
    union all
    select rp.quest_id, rp.step from public.world_quest_replays rp where rp.owner_id = p_owner) cur
  join public.world_quest_steps qs on qs.quest_id = cur.quest_id and qs.step = cur.step + 1
  cross join lateral jsonb_array_elements(case when jsonb_typeof(qs.need -> 'tasks') = 'array' then qs.need -> 'tasks' else '[]' end) t
  cross join lateral jsonb_array_elements_text(case when jsonb_typeof(t -> 'm') = 'array' then t -> 'm' else '[]' end) x
  join public.world_region_monsters m on m.monster_id = x
  where t ->> 't' = 'win' and jsonb_typeof(t -> 'r') = 'array' and t -> 'r' ? p_region and m.region_id <> p_region
$$;
revoke all on function public.world_quest_borrow(uuid, text) from public, anon, authenticated;
do $d$
declare o text;
begin
  for o in select rolname from pg_roles where rolname like 'fn_owner%' loop
    execute format('grant execute on function public.world_quest_borrow(uuid, text) to %I', o);
  end loop;
end $d$;

select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  'node_min int; v_intent text; v_qt text[]; v_gq boolean := false;',
  'node_min int; v_intent text; v_qt text[]; v_gq boolean := false; v_bor text[] := public.world_quest_borrow(p_owner, p_region);');
select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  $q$AND (t ->> 'rank' = 'guardian' OR (jsonb_typeof(t -> 'm') = 'array' AND EXISTS (SELECT 1 FROM public.world_region_monsters gm WHERE gm.region_id = p_region AND gm.role = 'guardian' AND t -> 'm' ? gm.monster_id)))$q$,
  $q$AND (t ->> 'rank' = 'guardian' OR (jsonb_typeof(t -> 'm') = 'array' AND EXISTS (SELECT 1 FROM public.world_region_monsters gm WHERE (gm.region_id = p_region OR gm.monster_id = ANY (v_bor)) AND gm.role = 'guardian' AND t -> 'm' ? gm.monster_id)))$q$);
select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  $q$SELECT * INTO m FROM public.world_region_monsters WHERE region_id = p_region AND role = 'guardian' ORDER BY$q$,
  $q$SELECT * INTO m FROM public.world_region_monsters WHERE (region_id = p_region OR monster_id = ANY (v_bor)) AND role = 'guardian' ORDER BY$q$);
select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  $q$SELECT * INTO m FROM public.world_region_monsters WHERE region_id = p_region AND role IN ('common', 'main')$q$,
  $q$SELECT * INTO m FROM public.world_region_monsters WHERE (region_id = p_region OR monster_id = ANY (v_bor)) AND role IN ('common', 'main')$q$);
