alter table public.world_idle_activities add column if not exists skill_line text;

create or replace function public.world_idle_choices(p_uid uuid) returns jsonb
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare c public.world_characters%rowtype; tr text[]; mt text[] := array['smithing', 'carpentry', 'artifice', 'wardcraft', 'weaving', 'leatherwork', 'alchemy', 'cooking'];
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if not found then return null; end if;
  tr := array[coalesce(public.world_job_line(c.job_key), 'melee'), 'guarding', 'first_aid', 'analysis'];
  return jsonb_build_object(
    'training', (select jsonb_agg(jsonb_build_object('line', l, 'name', public.world_line_name(l)) order by o) from unnest(tr) with ordinality u(l, o)),
    'maintenance', (select jsonb_agg(jsonb_build_object('line', l, 'name', public.world_line_name(l)) order by o) from unnest(mt) with ordinality u(l, o)),
    'default', jsonb_build_object('training', public.world_idle_skill_for(p_uid, 'training'), 'maintenance', public.world_idle_skill_for(p_uid, 'maintenance')));
end $$;
select pg_temp.yh_own('public.world_idle_choices(uuid)', 'fn_owner_field');
select pg_temp.yh_share('public.world_idle_choices(uuid)');

select pg_temp.yh_fix('world_start_idle_activity', array[
  $q$ insert into public.world_idle_activities(owner_id,activity_type,duration_minutes) values(public.fn_owner_auth_uid(),p_activity,p_duration_minutes) returning id into v_id;$q$,
  $q$ insert into public.world_idle_activities(owner_id,activity_type,duration_minutes,skill_line) values(public.fn_owner_auth_uid(),p_activity,p_duration_minutes,nullif(current_setting('yh.idle_line', true), '')) returning id into v_id;
 perform set_config('yh.idle_line', '', true);$q$]);

create or replace function public.world_start_idle_activity(p_activity text, p_duration_minutes integer, p_line text)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); ch jsonb; ln text := nullif(btrim(coalesce(p_line, '')), '');
begin
  if uid is null then raise exception '로그인 후 이용할 수 있습니다.'; end if;
  if ln is not null then
    if p_activity not in ('training', 'maintenance') then raise exception '기술은 수련과 정비에서만 고를 수 있습니다.'; end if;
    ch := public.world_idle_choices(uid);
    if not exists (select 1 from jsonb_array_elements(ch -> p_activity) x where x ->> 'line' = ln) then raise exception '고를 수 없는 기술입니다.'; end if;
  end if;
  perform set_config('yh.idle_line', coalesce(ln, ''), true);
  return public.world_start_idle_activity(p_activity, p_duration_minutes);
end $$;
select pg_temp.yh_own('public.world_start_idle_activity(text, integer, text)', 'fn_owner_19180');
select pg_temp.yh_share('public.world_start_idle_activity(text, integer, text)');
grant execute on function public.world_start_idle_activity(text, integer, text) to authenticated;

select pg_temp.yh_fix('world_claim_idle_activity', array[
  $q$ v_skill:=public.world_idle_skill_for(v.owner_id, v.activity_type);$q$,
  $q$ v_skill:=coalesce(v.skill_line, public.world_idle_skill_for(v.owner_id, v.activity_type));$q$,
  $q$v_result:=jsonb_build_object('message','자율수련 완료','combat_xp',v_skill_xp,$q$,
  $q$v_result:=jsonb_build_object('message','자율수련 완료','skill_line',v_skill,'skill_name',public.world_line_name(v_skill),'combat_xp',v_skill_xp,$q$,
  $q$v_result:=jsonb_build_object('message','장비 정비 완료','crafting_xp',v_skill_xp,$q$,
  $q$v_result:=jsonb_build_object('message','장비 정비 완료','skill_line',v_skill,'skill_name',public.world_line_name(v_skill),'crafting_xp',v_skill_xp,$q$]);

create or replace function public.world_idle_info(p_activity text, p_line text) returns jsonb
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); ln text;
begin
  if uid is null then return null; end if;
  ln := case when p_activity is null then null else coalesce(p_line, public.world_idle_skill_for(uid, p_activity)) end;
  return jsonb_build_object('skill_line', ln, 'skill_name', case when ln is not null then public.world_line_name(ln) end, 'choices', public.world_idle_choices(uid));
end $$;
select pg_temp.yh_own('public.world_idle_info(text, text)', 'fn_owner_field');
select pg_temp.yh_share('public.world_idle_info(text, text)');
grant execute on function public.world_idle_info(text, text) to authenticated;

select pg_temp.yh_fix('world_idle_activity_snapshot', array[
  $q$ if not found then return jsonb_build_object('active',false); end if;$q$,
  $q$ if not found then return jsonb_build_object('active',false) || coalesce(public.world_idle_info(null, null), '{}'::jsonb); end if;$q$,
  $q$ 'ready',now()>=v.started_at+make_interval(mins=>v.duration_minutes));$q$,
  $q$ 'ready',now()>=v.started_at+make_interval(mins=>v.duration_minutes)) || coalesce(public.world_idle_info(v.activity_type, v.skill_line), '{}'::jsonb);$q$]);
