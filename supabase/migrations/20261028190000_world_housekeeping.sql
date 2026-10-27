-- 기록 정리(서버 디스크 부담 줄이기, 2026-10-28 결정): 매일 한국 시각 04:13에 오래된 기록을 지운다.
--   읽은 알림 14일 · 채팅·귓속말 30일 · 경제 장부 60일(상점 판매 한도는 최근 24시간만 본다)
-- 행동 기록(world_events)은 칭호 진행도(world_title_rule_progress)·첫 걸음(world_tutorial_snapshot)이 처음부터 세므로 지우지 않는다.
-- 안 읽은 알림은 남긴다. 모임 채팅은 world_circle_send가 이미 30일만 남긴다.
create extension if not exists pg_cron;

create or replace function public.world_housekeeping()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare a int; b int; c int;
begin
  delete from public.world_notifications where read_at is not null and read_at < now() - interval '14 days';
  get diagnostics a = row_count;
  delete from public.world_chat_messages where created_at < now() - interval '30 days';
  get diagnostics b = row_count;
  delete from public.world_economy_ledger where created_at < now() - interval '60 days';
  get diagnostics c = row_count;
  return jsonb_build_object('notifications', a, 'chat', b, 'ledger', c);
end $$;
-- 새 프로젝트의 기본 권한은 새 함수를 anon·authenticated에도 열어 두므로 명시적으로 거둔다(pg_cron은 postgres로 돈다)
revoke all on function public.world_housekeeping() from public, anon, authenticated;

select cron.schedule('yh-housekeeping', '13 19 * * *', $$select public.world_housekeeping()$$);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028190000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
