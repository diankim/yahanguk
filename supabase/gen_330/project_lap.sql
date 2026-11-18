alter table public.world_projects add column if not exists laps int not null default 0;

select pg_temp.yh_pj_setjson('public.world_project_rules()'::regprocedure, jsonb_set(public.world_project_rules(), '{pay,after_mul}', '1'::jsonb));

update public.world_projects set goal = public.world_project_goal(project_key, 4) where stage >= 5 and coalesce(goal, 0) <= 0;

create or replace function public.world_project_lap(p_key text, p_giver uuid)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare p jsonb := public.world_project_rule(p_key); m jsonb := public.world_project_rules() -> 'memento'; pr public.world_projects%rowtype;
  need bigint; carry bigint; got uuid[] := '{}'; v_gil bigint := 0; fac boolean := p ->> 'kind' = 'faction'; place text; first boolean; who uuid; x record; nl int;
begin
  select * into pr from public.world_projects where project_key = p_key;
  if pr.stage < 5 or pr.goal <= 0 or pr.points < pr.goal then return null; end if;
  nl := pr.laps + 1;
  need := ceil(pr.goal * (m ->> 'pct')::numeric / 100);
  carry := pr.points - pr.goal;
  if not fac then v_gil := floor(pr.goal * (m ->> 'common_gil_pct')::numeric / 100); end if;
  place := case when fac then public.world_mf_name(p ->> 'faction') || ' 거점 사업' else (public.world_domain_rules() -> (p ->> 'domain') ->> 'name') || ' 공동 사업' end;
  for x in select c.owner_id, c.marks from public.world_project_contrib c where c.project_key = p_key and c.cur >= need order by c.owner_id loop
    got := got || x.owner_id;
    first := not (5 = any (coalesce(x.marks, '{}'::int[])));
    if first then update public.world_project_contrib set marks = marks || 5 where project_key = p_key and owner_id = x.owner_id; end if;
    insert into public.world_storage(owner_id, items) values (x.owner_id, jsonb_build_object(m ->> 'cake', (m ->> 'cake_n')::int))
    on conflict (owner_id) do update set items = public.world_inv_add(world_storage.items, m ->> 'cake', (m ->> 'cake_n')::int), updated_at = now();
    if fac then
      if public.world_project_member(x.owner_id, p_key) then
        update public.world_faction_progress set merit = merit + (m ->> 'faction_merit')::int, updated_at = now() where owner_id = x.owner_id and faction_id = p ->> 'faction';
      end if;
      if first then update public.world_storage set items = public.world_inv_add(items, m ->> 'plaque', 1), updated_at = now() where owner_id = x.owner_id; end if;
    else
      update public.world_characters set gil = gil + v_gil, updated_at = now() where owner_id = x.owner_id;
      insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (x.owner_id, 'project_memento', v_gil, false, jsonb_build_object('project', p_key, 'lap', nl));
      if first then insert into public.world_character_cosmetics(owner_id, cosmetic_key) values (x.owner_id, m ->> 'seal') on conflict do nothing; end if;
    end if;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    select x.owner_id, 'project_stage', '사업 한 바퀴 더',
      place || ' 「' || (p ->> 'name') || '」이(가) ' || nl || '바퀴째를 채웠습니다. 힘을 보탠 몫으로 낙성 떡을 창고에 넣었습니다' ||
      case when not fac then ' · ' || v_gil || '전' when ch.major_faction_id = p ->> 'faction' then ' · 공훈 +' || (m ->> 'faction_merit') else '' end ||
      case when first then case when fac then ' · 낙성 기념패' else ' · 낙관 「拓」' end else '' end || '.',
      jsonb_build_object('project', p_key, 'stage', 5, 'lap', nl)
      from public.world_characters ch where ch.owner_id = x.owner_id;
  end loop;
  update public.world_project_contrib set cur = 0, updated_at = now() where project_key = p_key and cur <> 0;
  if carry > 0 and p_giver is not null then
    update public.world_project_contrib set cur = carry where project_key = p_key and owner_id = p_giver;
  end if;
  update public.world_projects set laps = nl, points = carry, stage_at = stage_at || now(), updated_at = now() where project_key = p_key;
  foreach who in array got loop perform public.world_title_award_check(who, 'project'); end loop;
  return jsonb_build_object('stage', 5, 'lap', nl, 'got', to_jsonb(got));
end $f$;
select pg_temp.pj_own('public.world_project_lap(text, uuid)', 'fn_owner_field');
select pg_temp.pj_share('public.world_project_lap(text, uuid)');

select pg_temp.pj_fix('world_project_stage_up', array[
  E'  if pr.stage >= 5 or pr.points < pr.goal or pr.goal <= 0 then return null; end if;',
  E'  if pr.points < pr.goal or pr.goal <= 0 then return null; end if;\n  if pr.stage >= 5 then return public.world_project_lap(p_key, p_giver); end if;',
  E'    points = case when done >= 5 then 0 else carry end,\n    goal = public.world_project_goal(p_key, done),',
  E'    points = carry,\n    goal = coalesce(nullif(public.world_project_goal(p_key, done), 0), public.world_project_goal(p_key, 4)),'
]);

select pg_temp.pj_fix('world_project_give', array[
  E'cur = cur + case when pr.stage >= 5 then 0 else pts end,',
  E'cur = cur + pts,',
  E'points = points + case when stage >= 5 then 0 else pts end,',
  E'points = points + pts,',
  E'      case when jsonb_array_length(ups) > 0 then '' · 사업이 '' || (ups -> -1 ->> ''stage'') || ''단계를 마쳤습니다!'' else '''' end,',
  E'      case when jsonb_array_length(ups) > 0 and ups -> -1 ? ''lap'' then '' · 사업이 한 바퀴를 더 채웠습니다!'' when jsonb_array_length(ups) > 0 then '' · 사업이 '' || (ups -> -1 ->> ''stage'') || ''단계를 마쳤습니다!'' else '''' end,'
]);

select pg_temp.pj_fix('world_project_view(text)', array[
  E'''after'', pr.stage >= 5);',
  E'''after'', pr.stage >= 5, ''laps'', pr.laps);'
]);
