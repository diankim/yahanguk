lock table public.world_characters in access exclusive mode;

create or replace function public.world_storage_capacity(p_uid uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  select jsonb_build_object('base', 70, 'bought', b.v, 'story', st.v, 'arc', ar.v, 'faction', fa.v, 'survey', sv.v,
           'total', 70 + b.v + st.v + ar.v + fa.v + sv.v, 'bought_steps', b.n, 'surveyed', sv.n,
           'next_price', (array[1000, 2500, 5000, 10000])[b.n + 1])
    from (select coalesce((select s.bought from public.world_storage s where s.owner_id = p_uid), 0) n) b0,
         lateral (select b0.n n, b0.n * 4 v) b,
         lateral (select 2 * count(*)::int v from public.world_story_chapters ch join public.world_case_progress p
                    on p.owner_id = p_uid and p.case_id = ch.chapter_id
                   where ch.seq between 6 and 10 and coalesce(p.combined, '[]'::jsonb) ? (ch.chapter_id || '_completed')) st,
         lateral (select 2 * count(*)::int v from public.world_quest_progress g
                   where g.owner_id = p_uid and g.done_at is not null
                     and g.quest_id = any (array['gq_1','gq_2','gq_3','gq_4','gq_5','mkq_1','mkq_2','mkq_3','mkq_4','mkq_5'])) ar,
         lateral (select case when c.major_faction_id is null then 0
                    else 2 * ((coalesce(c.faction_reputation, 0) >= 300)::int + (coalesce(c.faction_reputation, 0) >= 600)::int
                            + (coalesce(c.faction_reputation, 0) >= 1000)::int) end v
                    from public.world_characters c where c.owner_id = p_uid) fa,
         lateral (select x.n, 2 * least(3, x.n / 10) v
                    from (select count(*)::int n from public.world_region_progress r where r.owner_id = p_uid and 'complete' = any (r.milestones)) x) sv
$function$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116110000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
