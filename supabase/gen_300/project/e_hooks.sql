select pg_temp.pj_fix('world_title_rule_ok', array[
$q$ELSIF p_rule ? 'mentor' THEN RETURN public.world_mentor_rule_count(p_owner, p_rule) >= n;$q$,
$q$ELSIF p_rule ? 'project' THEN RETURN public.world_project_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'mentor' THEN RETURN public.world_mentor_rule_count(p_owner, p_rule) >= n;$q$]);
select pg_temp.pj_fix('world_title_rule_progress', array[
$q$elsif p_rule ? 'mentor' then v := public.world_mentor_rule_count(p_owner, p_rule);$q$,
$q$elsif p_rule ? 'project' then v := public.world_project_rule_count(p_owner, p_rule); elsif p_rule ? 'mentor' then v := public.world_mentor_rule_count(p_owner, p_rule);$q$]);
select pg_temp.pj_fix('world_title_award_check', array[
$q$    IF r ? 'mentor' AND p_event_type IS NOT NULL AND p_event_type <> 'mentor' THEN CONTINUE; END IF;$q$,
$q$    IF r ? 'mentor' AND p_event_type IS NOT NULL AND p_event_type <> 'mentor' THEN CONTINUE; END IF;
    IF r ? 'project' AND p_event_type IS NOT NULL AND p_event_type <> 'project' THEN CONTINUE; END IF;
    IF p_event_type = 'project' AND NOT (r ? 'project') THEN CONTINUE; END IF;$q$]);

select pg_temp.pj_fix('world_notify_group', array[
$q$when p_kind in ('meisho_open') then 'meisho'$q$, $q$when p_kind in ('meisho_open') then 'meisho'
    when p_kind in ('project_stage') then 'project'$q$]);

create or replace function public.world_sys_chat_names()
 returns text[] language sql immutable
as $function$ select array['구조 알림', '세력 소식', '봉연 소식', '비무 소식', '연리 소식', '운영 공지', '선배 소식', '사업 소식'] $function$;

select pg_temp.pj_fix('world_character_purge(uuid)', array[
$q$  delete from public.world_mentor_posts where owner_id = p_uid;$q$,
$q$  delete from public.world_mentor_posts where owner_id = p_uid;
  delete from public.world_project_contrib where owner_id = p_uid;$q$]);

select pg_temp.pj_fix('world_field_snapshot', array[
$q$'has_stable', r.has_stable,$q$,
$q$'has_stable', r.has_stable OR public.world_weak_lift(uid, r.region_id, 'stable'), 'weak', public.world_weak_view(uid, r.region_id), 'project', public.world_project_brief(uid),$q$]);

do $g$
declare f text;
begin
  foreach f in array array['world_project_rules()', 'world_project_rule(text)', 'world_project_items(text, int)', 'world_project_urgent(text, int, date)',
    'world_project_goal(text, int)', 'world_project_text(text, int)'] loop
    perform pg_temp.pj_share('public.' || f);
  end loop;
  foreach f in array array['world_project_stage(text)', 'world_project_role(uuid, text)', 'world_project_day_pts(uuid, date)', 'world_project_member(uuid, text)', 'world_project_story(uuid, text)',
    'world_project_at(uuid)', 'world_project_rel_up(uuid, text, int, bigint)', 'world_project_stage_up(text, uuid)', 'world_project_have(uuid, jsonb, jsonb, text)', 'world_project_st_ok(uuid)',
    'world_project_brief(uuid)', 'world_project_rule_count(uuid, jsonb)', 'world_project_view(text)', 'world_project_give(text, jsonb)'] loop
    perform pg_temp.pj_share('public.' || f);
    perform pg_temp.pj_own('public.' || f, 'fn_owner_field');
  end loop;
end $g$;
grant execute on function public.world_project_view(text) to authenticated;
grant execute on function public.world_project_give(text, jsonb) to authenticated;
grant execute on function public.world_project_rules() to anon, authenticated;
grant select, update on public.world_faction_relations to fn_owner_field;
grant insert on public.world_faction_log to fn_owner_field;
grant usage on sequence public.world_faction_log_id_seq to fn_owner_field;
