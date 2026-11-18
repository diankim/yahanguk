alter table public.world_quests add column if not exists open_req jsonb;

create or replace function public.world_quest_gate_ok(p_req jsonb) returns boolean
language sql stable as $f$
  select p_req is null or coalesce((select p.stage from public.world_projects p where p.project_key = p_req ->> 'project'), 0) >= coalesce((p_req ->> 'stage')::int, 0)
$f$;

create or replace function public.world_quest_gate_text(p_req jsonb) returns text
language sql stable as $f$
  select case when p_req is null then null
    else coalesce(public.world_project_rules() -> 'projects' -> (p_req ->> 'project') ->> 'name', '거점 사업') || ' ' || (p_req ->> 'stage') || '단계를 마치면 열립니다.' end
$f$;

select pg_temp.yh_share('public.world_quest_gate_ok(jsonb)');
select pg_temp.yh_share('public.world_quest_gate_text(jsonb)');

select pg_temp.yh_fix('world_quest_board', array[
  'select b.*, (c.level >= b.min_level and b.after <@ dn) ok,',
  'select b.*, (c.level >= b.min_level and b.after <@ dn and public.world_quest_gate_ok(b.open_req)) ok,',
  'x.min_level, x.after, x.chapter_id, g.step gstep, g.owner_id has_prog,
             coalesce((select count(*) from public.world_quest_steps s where s.quest_id = x.quest_id), 0)::int nst,
             (x.kind = ''main'') ismain, x.sort, x.quest_id = any(dn) done
      from public.world_quests x
      left join public.world_quest_progress g on g.quest_id = x.quest_id and g.owner_id = uid
      left join public.world_map_regions m on m.region_id = x.region_id
      where x.active
        and (x.job_key is null or x.job_key = c.job_key)
        and (x.faction_key is null or x.faction_key = c.faction_key)) b
    where not b.done and not',
  'x.min_level, x.after, x.chapter_id, g.step gstep, g.owner_id has_prog, x.open_req,
             coalesce((select count(*) from public.world_quest_steps s where s.quest_id = x.quest_id), 0)::int nst,
             (x.kind = ''main'') ismain, x.sort, x.quest_id = any(dn) done
      from public.world_quests x
      left join public.world_quest_progress g on g.quest_id = x.quest_id and g.owner_id = uid
      left join public.world_map_regions m on m.region_id = x.region_id
      where x.active
        and (x.job_key is null or x.job_key = c.job_key)
        and (x.faction_key is null or x.faction_key = c.faction_key)) b
    where not b.done and not'
]);

select pg_temp.yh_fix('world_quest_journal', array[
  'status := case when ok and after_ok then ''available'' else ''locked'' end;',
  'gate_ok := public.world_quest_gate_ok(q.open_req);
      status := case when ok and after_ok and gate_ok then ''available'' else ''locked'' end;',
  'here_id text; ok boolean; after_ok boolean;',
  'here_id text; ok boolean; after_ok boolean; gate_ok boolean := true;',
  '''locked_reason'', case when status = ''locked'' then case when c.level < q.min_level then ''level'' else ''after'' end end,',
  '''locked_reason'', case when status = ''locked'' then case when c.level < q.min_level then ''level'' when not gate_ok then ''project'' else ''after'' end end,
      ''open_text'', case when status = ''locked'' and not gate_ok then public.world_quest_gate_text(q.open_req) end,'
]);

select pg_temp.yh_fix('world_quest_report', array[
  'if not public.world_quest_done(uid, a) then raise exception ''먼저 마쳐야 하는 퀘스트가 있습니다.''; end if;
    end loop;',
  'if not public.world_quest_done(uid, a) then raise exception ''먼저 마쳐야 하는 퀘스트가 있습니다.''; end if;
    end loop;
    if not public.world_quest_gate_ok(q.open_req) then raise exception ''%'', public.world_quest_gate_text(q.open_req); end if;'
]);
