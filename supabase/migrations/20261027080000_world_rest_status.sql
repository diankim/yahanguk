-- 휴식 쿨타임 남은 시간(읽기 전용): 잠깐 쉬기 10분·푹 쉬기 30분 뒤 다시 쉴 수 있는 시각을 돌려준다.
-- 쿨타임 판단은 world_field_rest와 같은 기록(world_events의 rest·style)을 쓴다.
create or replace function public.world_rest_status() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); s timestamptz; f timestamptz;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select max(created_at) into s from public.world_events where actor_id = uid and event_type = 'rest' and payload ->> 'style' = 'short' and created_at > now() - interval '10 minutes';
  select max(created_at) into f from public.world_events where actor_id = uid and event_type = 'rest' and payload ->> 'style' = 'full' and created_at > now() - interval '30 minutes';
  return jsonb_build_object('short_ready_at', s + interval '10 minutes', 'full_ready_at', f + interval '30 minutes', 'now', now());
end $$;
alter function public.world_rest_status() owner to fn_owner_field;
revoke all on function public.world_rest_status() from public, anon, authenticated;
grant execute on function public.world_rest_status() to authenticated;
