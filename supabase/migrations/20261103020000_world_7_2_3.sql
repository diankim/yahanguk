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

-- ② 지도: 세력 땅이 다른 세력 칸에 끊기던 곳 — 소속·레벨 구간·길 연결은 그대로 두고 칸 자리만 맞바꾼다
--  옥문 협로(정통파 Lv10) ↔ 별바라기 언덕(천명원 Lv5), 흑조 균열(흑련회 Lv20) ↔ 불씨 고개(남명회 Lv5)
update public.world_map_regions set world_x = 570, world_y = 280 where region_id = 'jade_pass';
update public.world_map_regions set world_x = 590, world_y = 235 where region_id = 'star_hill';
update public.world_map_regions set world_x = 625, world_y = 490 where region_id = 'black_tide_rift';
update public.world_map_regions set world_x = 720, world_y = 450 where region_id = 'ember_pass';
--  정통파 본토 다섯 곳의 세력 이름이 「야행국」으로 남아 범례에 정통파가 보이지 않던 것
update public.world_map_regions set faction_control = '야행국 정통파'
 where control_faction_id = 'night_office' and faction_control = '야행국';

update public.world_app_meta set value = '20261103020000' where key = 'db_version';
