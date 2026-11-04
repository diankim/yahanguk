create or replace function public.world_busy_rules() returns jsonb language sql immutable as $f$
  select jsonb_build_object(
    'travel', jsonb_build_object('name', '이동', 'after', '도착한 뒤에 하세요.'),
    'expedition', jsonb_build_object('name', '원정', 'after', '원정에서 돌아온 뒤에 하세요.'),
    'idle', jsonb_build_object('name', '자율 활동', 'after', '자율 활동을 마치거나 그만둔 뒤에 하세요.'),
    'downed', jsonb_build_object('name', '전투불능', 'after', '구조를 받거나 구조대를 부른 뒤에 하세요.'),
    'self', '{name} 중에는 {what}을(를) 할 수 없습니다. {after}',
    'other', '그 동료는 지금 {name} 중입니다.',
    'what', '이 일')
$f$;
revoke all on function public.world_busy_rules() from public, anon, authenticated;

create or replace function public.world_busy_kind(p_uid uuid) returns text
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  if exists (select 1 from public.world_characters c where c.owner_id = p_uid and c.travel_arrives_at is not null and c.travel_arrives_at > now()) then return 'travel'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then return 'expedition'; end if;
  if exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = 'active') then return 'idle'; end if;
  return null;
end $f$;
revoke all on function public.world_busy_kind(uuid) from public, anon, authenticated;

create or replace function public.world_busy_msg(p_uid uuid, p_what text default null, p_other boolean default false) returns text
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare k text := public.world_busy_kind(p_uid); r jsonb := public.world_busy_rules();
begin
  if k is null then return null; end if;
  return replace(replace(replace(r ->> (case when p_other then 'other' else 'self' end), '{name}', r -> k ->> 'name'),
    '{what}', coalesce(p_what, r ->> 'what')), '{after}', r -> k ->> 'after');
end $f$;
revoke all on function public.world_busy_msg(uuid, text, boolean) from public, anon, authenticated;
grant execute on function public.world_busy_msg(uuid, text, boolean) to fn_owner_field;

create or replace function public.world_travel_guard(p_what text default null) returns void
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare m text := public.world_busy_msg(public.fn_owner_auth_uid(), p_what, false);
begin
  if m is not null then raise exception '%', m; end if;
end $f$;

do $w$
declare d text; n int;
  procedure_list text[][] := array[
    array['public.world_quest_report(text)',
      $a$if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 퀘스트를 받거나 보고할 수 없습니다. 도착한 뒤에 하세요.'; end if;$a$,
      $b$perform public.world_travel_guard('퀘스트 받기·보고');$b$],
    array['public.world_faction_report()',
      $a$if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 세력 퀘스트를 보고할 수 없습니다. 도착한 뒤에 하세요.'; end if;$a$,
      $b$perform public.world_travel_guard('세력 퀘스트 보고');$b$],
    array['public.world_use_item(text)',
      $a$IF c.travel_destination IS NOT NULL AND public.world_item_base(p_item_id) <> 'revival_charm' THEN RAISE EXCEPTION '이동 중에는 물품을 쓸 수 없습니다. 도착한 뒤 쓰세요.'; END IF;$a$,
      $b$IF public.world_item_base(p_item_id) <> 'revival_charm' THEN PERFORM public.world_travel_guard('물품 사용'); END IF;$b$],
    array['public.world_party_use_item(uuid,text)',
      $a$  if c.travel_destination is not null then raise exception '이동 중에는 동료를 돌볼 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then raise exception '원정 중에는 동료를 돌볼 수 없습니다.'; end if;$a$,
      $b$  perform public.world_travel_guard('동료 돌보기');$b$],
    array['public.world_party_use_item(uuid,text)',
      $a$  if t.travel_destination is not null then raise exception '그 동료는 지금 이동 중입니다. 도착한 뒤에 돌봐 주세요.'; end if;$a$,
      $b$  if public.world_busy_msg(p_target, null, true) is not null then raise exception '%', public.world_busy_msg(p_target, null, true); end if;$b$],
    array['public.world_party_use_item(uuid,text)',
      $a$  if exists (select 1 from public.world_expeditions e where e.owner_id = p_target and e.status = 'active') then raise exception '원정 중인 동료에게는 쓸 수 없습니다.'; end if;
$a$,
      '']];
  i int;
begin
  for i in 1 .. array_length(procedure_list, 1) loop
    d := replace(pg_get_functiondef(procedure_list[i][1]::regprocedure), E'\r\n', E'\n');
    n := (length(d) - length(replace(d, procedure_list[i][2], ''))) / length(procedure_list[i][2]);
    if n <> 1 then raise exception '1.0.3d % 기준 문구가 % 번 있습니다', procedure_list[i][1], n; end if;
    execute replace(d, procedure_list[i][2], procedure_list[i][3]);
  end loop;
end $w$;

update public.world_app_meta set value = '20261105180000' where key = 'db_version';
