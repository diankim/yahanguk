grant execute on function public.world_chat_mark(uuid) to fn_owner_19419;

CREATE OR REPLACE FUNCTION public.world_quest_board()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; q record; st jsonb; act jsonb := '[]'::jsonb; avail jsonb := '[]'::jsonb;
  here_id text; ok boolean; nsteps int; clues jsonb; ndone int := 0; ntotal int := 0; fac jsonb; dn text[]; a1 jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select region_id into here_id from public.world_map_regions where region_name = c.location limit 1;
  dn := public.world_quest_done_ids(uid);
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
        select s.need -> 'at' into a1 from public.world_quest_steps s where s.quest_id = q.quest_id and s.step = 1;
        if jsonb_typeof(a1) = 'array' and jsonb_array_length(a1) > 0 then
          avail := avail || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary,
            'region_id', a1 ->> 0,
            'region_name', (select string_agg(m.region_name, '·' order by m.region_name) from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(a1))),
            'min_level', q.min_level, 'locked', not ok, 'here', coalesce(a1 ? here_id, false), 'steps', nsteps);
        else
          avail := avail || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary,
            'region_id', q.region_id, 'region_name', q.region_name, 'min_level', q.min_level, 'locked', not ok, 'here', q.region_id = here_id, 'steps', nsteps);
        end if;
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

update public.world_patch_notes set body = body || E'\n\n## 1.1.0b\n- 파티 채팅을 보낼 수 없던 문제를 고쳤습니다.\n- 직업 둘째·셋째 퀘스트 등 12편이 어디서도 받아지지 않던 문제를 고쳤습니다. 퀘스트 판은 이제 첫 장면을 받는 곳을 보여 줍니다.\n- 별채에서 위에 얹힌 조각이 있는 가구(이부자리 등)를 돌리면 일부 방향에서 윗조각이 가려지던 그림을 고쳤습니다.'
 where note_id = '1.1.0';

update public.world_app_meta set value = '20261108060000' where key = 'db_version';
