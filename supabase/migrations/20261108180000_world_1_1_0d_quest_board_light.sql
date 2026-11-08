create or replace function public.world_task_row(p_uid uuid, p_task jsonb, p_since timestamptz, p_loc text, p_live boolean)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare n int; it jsonb := case when jsonb_typeof(p_task -> 'items') = 'array' then p_task -> 'items' else '[]'::jsonb end;
begin
  n := case when not p_live then 0
            when p_task ->> 't' = 'travel' and p_task ? 'r' and exists (select 1 from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(p_task -> 'r')) and m.region_name = p_loc) then (p_task ->> 'n')::int
            else least((p_task ->> 'n')::int, public.world_quest_task_count(p_uid, p_task, p_since)) end;
  return jsonb_build_object('label', public.world_quest_task_label(p_task), 'cur', n, 'n', (p_task ->> 'n')::int, 't', p_task ->> 't',
    'regions', coalesce(p_task -> 'r', case when p_task ->> 't' = 'win' and p_task ? 'm' then (select jsonb_agg(distinct rm.region_id) from public.world_region_monsters rm where rm.monster_id in (select jsonb_array_elements_text(p_task -> 'm'))) end, '[]'::jsonb),
    'items', p_task -> 'items',
    'mn', case when p_task ->> 't' = 'win' and p_task ? 'm' then (select jsonb_agg(rm.monster_name order by rm.monster_name) from public.world_region_monsters rm where rm.monster_id in (select jsonb_array_elements_text(p_task -> 'm'))) end,
    'unit', case when p_task ->> 't' = 'gather' then case when jsonb_array_length(it) > 0 then '개' else '회' end when p_task ->> 't' = 'craft' and jsonb_array_length(it) > 0 then '개' else '' end);
end
$function$;

create or replace function public.world_quest_board()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; q record; st jsonb; act jsonb := '[]'::jsonb; avail jsonb;
  here_id text; clues jsonb; ndone int; ntotal int; fac jsonb; dn text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select region_id into here_id from public.world_map_regions where region_name = c.location limit 1;
  dn := public.world_quest_done_ids(uid);
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
      act := act || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'clues', 'clues', clues,
        'step', q.nst, 'steps', q.nst);
    else
      st := public.world_quest_step_state(uid, q.quest_id);
      act := act || (jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'step') || coalesce(st, '{}'::jsonb) || jsonb_build_object('title', q.title, 'step_title', st ->> 'title'));
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
  return jsonb_build_object('active', act, 'available', avail, 'faction', fac, 'done', ndone, 'total', ntotal, 'here_id', here_id, 'level', c.level);
end
$function$;

update public.world_patch_notes set body = body || E'\n\n## 1.1.0d\n- 현장 퀘스트 칸이 할 일과 상관없는 행동 뒤에도 매번 다시 읽히던 것을 줄였습니다. 보이는 내용은 같습니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261108180000' where key = 'db_version';
