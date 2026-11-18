CREATE OR REPLACE FUNCTION public.world_quest_journal()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; q record; out jsonb := '[]'::jsonb; arr jsonb[] := '{}';
  here_id text; ok boolean; after_ok boolean; a text; nsteps int; done boolean; stp int; status text; st jsonb; hidden int := 0; dn text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select region_id into here_id from public.world_map_regions where region_name = c.location limit 1;
  dn := public.world_quest_done_ids(uid);
  for q in select x.*, g.step gstep, g.done_at, m.region_name
             from public.world_quests x left join public.world_quest_progress g on g.quest_id = x.quest_id and g.owner_id = uid
             left join public.world_map_regions m on m.region_id = x.region_id
            where x.active and (x.job_key is null or x.job_key = c.job_key) and (x.faction_key is null or x.faction_key = c.faction_key) order by (x.kind = 'main') desc, x.min_level, x.sort, x.quest_id loop
    select count(*) into nsteps from public.world_quest_steps where quest_id = q.quest_id;
    done := q.quest_id = any (dn);
    stp := case when done then nsteps else least(coalesce(q.gstep, 0), nsteps) end;
    st := null;
    if done then status := 'done';
    elsif stp >= 1 then
      status := 'active';
      if stp < nsteps then st := public.world_quest_step_state(uid, q.quest_id); end if;
    else
      ok := c.level >= q.min_level; after_ok := q.after <@ dn;
      if not after_ok and q.kind <> 'main' then if coalesce(q.cat, '') not like '외전·%' then hidden := hidden + 1; end if; continue; end if;
      status := case when ok and after_ok then 'available' else 'locked' end;
      if status = 'available' then st := public.world_quest_step_state(uid, q.quest_id); end if;
    end if;
    arr := arr || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary,
      'region_id', q.region_id, 'region_name', q.region_name, 'min_level', q.min_level, 'chapter_id', q.chapter_id,
      'status', status, 'locked_reason', case when status = 'locked' then case when c.level < q.min_level then 'level' else 'after' end end,
      'step', stp, 'steps', nsteps, 'done_at', q.done_at, 'here', q.region_id = here_id,
      'has_epilogue', q.kind = 'main' and done and jsonb_array_length(coalesce(q.epilogue, '[]'::jsonb)) > 0,
      'scenes', (select coalesce(jsonb_agg(jsonb_build_object('step', s.step, 'title', s.title,
                   'goal', case when s.step <= stp + 1 then s.goal end, 'done', s.step <= stp) order by s.step), '[]'::jsonb)
                   from public.world_quest_steps s where s.quest_id = q.quest_id),
      'cur', case when st is not null then st - 'title' end,
      'replay', case when done then (select jsonb_build_object('step', rp.step, 'cur', public.world_quest_step_state(uid, q.quest_id) - 'title')
                                        from public.world_quest_replays rp where rp.owner_id = uid and rp.quest_id = q.quest_id) end);
  end loop;
  out := to_jsonb(arr);
  return jsonb_build_object('quests', out, 'hidden', hidden, 'here_id', here_id, 'level', c.level);
end $function$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119110000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
