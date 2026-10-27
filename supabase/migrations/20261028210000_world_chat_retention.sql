-- 대화 기록 보관 단축(2026-10-28 결정): 전체·지역·세력·파티 채팅과 귓속말, 모임 채팅은 5일만 남긴다.
--   읽은 알림 14일 · 경제 장부 60일 · 지난 비경 1일은 그대로. 매일 04:13(KST) pg_cron yh-housekeeping이 부른다.
create or replace function public.world_housekeeping()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare a int; b int; c int; t int; m int;
begin
  delete from public.world_notifications where read_at is not null and read_at < now() - interval '14 days';
  get diagnostics a = row_count;
  delete from public.world_chat_messages where created_at < now() - interval '5 days';
  get diagnostics b = row_count;
  delete from public.world_circle_messages where created_at < now() - interval '5 days';
  get diagnostics m = row_count;
  delete from public.world_economy_ledger where created_at < now() - interval '60 days';
  get diagnostics c = row_count;
  delete from public.world_hidden_trails where expires_at < now() - interval '1 day';
  get diagnostics t = row_count;
  return jsonb_build_object('notifications', a, 'chat', b, 'circle', m, 'ledger', c, 'trails', t);
end $$;
revoke all on function public.world_housekeeping() from public, anon, authenticated;

-- 지금 한 번 정리한다(5일 지난 대화가 바로 사라진다)
select public.world_housekeeping();

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028210000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
