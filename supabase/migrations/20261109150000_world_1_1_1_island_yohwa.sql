create or replace function public.world_yohwa_onset()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare hit boolean := false;
begin
  if exists (select 1 from public.world_character_statuses where owner_id = new.owner_id and status_key in ('yohwa', 'yohwa_seal')) then return null; end if;
  if public.world_on_island(new.owner_id) then return null; end if;
  if old.erosion < 80 and new.erosion >= 80 and random() < 0.001 then hit := true; end if;
  if not hit and old.erosion < 90 and new.erosion >= 90 and random() < 0.01 then hit := true; end if;
  if not hit and old.erosion < 100 and new.erosion >= 100 and random() < 0.05 then hit := true; end if;
  if not hit then
    if old.erosion < 100 and new.erosion >= 100 and not exists (
      select 1 from public.world_notifications n
      where n.user_id = new.owner_id and n.kind = 'yohwa' and n.payload ->> 'warn' = 'true'
        and n.created_at >= date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul') then
      insert into public.world_notifications(user_id, kind, title, content, payload)
        values (new.owner_id, 'yohwa', '침식이 가득 찼습니다', '침식이 100에 닿았습니다. 이제부터 침식이 더 오르는 행동(탐색·토벌·원정)을 할 때마다 넘친 몫이 요기로 스며 요화에 걸릴 수 있습니다. 정화 부적이나 마음 다잡기로 침식을 낮추세요.', jsonb_build_object('stage', 0, 'warn', true));
    end if;
    return null;
  end if;
  insert into public.world_character_statuses(owner_id, status_key, stacks, potency, source_activity, expires_at, metadata)
    values (new.owner_id, 'yohwa', 1, 1, 'erosion', now() + interval '3 days', jsonb_build_object('stage', 1, 'started_at', now()));
  insert into public.world_notifications(user_id, kind, title, content, payload)
    values (new.owner_id, 'yohwa', '요화: 1단계 요기 스밈', '깊은 침식 속에서 요기가 몸에 스며들었습니다. 3일 뒤 2단계로 나빠집니다. 귀령초로 풀 수 있고, 요화로 쓰러지면 「안전지대 봉인」(24시간)으로 풀립니다.', jsonb_build_object('stage', 1));
  perform public.world_yohwa_mark(new.owner_id, 'onset');
  return null;
end $function$;

create or replace function public.world_yohwa_overflow(p_uid uuid, p_over numeric)
 returns boolean
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if p_uid is null or coalesce(p_over, 0) <= 0 then return false; end if;
  if exists (select 1 from public.world_character_statuses where owner_id = p_uid and status_key in ('yohwa', 'yohwa_seal')) then return false; end if;
  if public.world_on_island(p_uid) then return false; end if;
  if random() >= 1 - power(1 - 0.0025, least(p_over, 100)) then return false; end if;
  insert into public.world_character_statuses(owner_id, status_key, stacks, potency, source_activity, expires_at, metadata)
    values (p_uid, 'yohwa', 1, 1, 'erosion', now() + interval '3 days', jsonb_build_object('stage', 1, 'started_at', now(), 'from', 'overflow'));
  insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_uid, 'yohwa', '요화: 1단계 요기 스밈', '가득 찬 침식을 넘어 요기가 몸에 스며들었습니다. 3일 뒤 2단계로 나빠집니다. 귀령초로 풀 수 있고, 요화로 쓰러지면 「안전지대 봉인」(24시간)으로 풀립니다.', jsonb_build_object('stage', 1));
  perform public.world_yohwa_mark(p_uid, 'onset');
  return true;
end $function$;

update public.world_app_meta set value = '20261109150000' where key = 'db_version';
