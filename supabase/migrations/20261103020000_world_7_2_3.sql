-- 7.2.3 점검 묶음
-- ① 대화 보관 3일 → 2일(전체·지역·세력 채팅·귓속말·모임·파티). 매일 04:13 KST world_housekeeping이 지운다.
create or replace function public.world_housekeeping()
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare a int; b int; c int; t int; m int; p int;
begin
  delete from public.world_notifications where read_at is not null and read_at < now() - interval '14 days';
  get diagnostics a = row_count;
  delete from public.world_chat_messages where created_at < now() - interval '2 days';
  get diagnostics b = row_count;
  delete from public.world_circle_messages where created_at < now() - interval '2 days';
  get diagnostics m = row_count;
  delete from public.world_party_messages where created_at < now() - interval '2 days';
  get diagnostics p = row_count;
  delete from public.world_economy_ledger where created_at < now() - interval '60 days';
  get diagnostics c = row_count;
  delete from public.world_hidden_trails where expires_at < now() - interval '1 day';
  get diagnostics t = row_count;
  perform public.world_letter_prune(x.recipient_id) from (select distinct recipient_id from public.world_letters where not pinned and created_at < now() - interval '3 days') x;
  delete from public.world_letter_sends where day < (now() at time zone 'Asia/Seoul')::date - 2;
  return jsonb_build_object('notifications', a, 'chat', b, 'circle', m, 'party', p, 'ledger', c, 'trails', t);
end $$;

update public.world_app_meta set value = '20261103020000' where key = 'db_version';
