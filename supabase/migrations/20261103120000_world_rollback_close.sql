-- 월 11/2 00:00(한국 시각) 점검 전환: 조사원 쪽(anon·authenticated)의 public 스키마 사용을 거둬 게임을 닫는다(supabase/maintenance/start.sql과 같은 일).
-- 화면은 첫 요청이 거절되면 점검 페이지로 가고, maintenance.json scene 'rollback'으로 「첫째 밤의 끝」 컷씬을 튼다.
-- 데이터는 건드리지 않는다(롤백은 점검 중에 따로 검토해 돌린다). 다시 열기는 supabase/maintenance/end.sql.
create or replace function public.world_rollback_close()
returns void language plpgsql security definer set search_path = pg_catalog, public as $f$
begin
  -- 마지막 토벌이 아직 열려 있으면 실패로 마무리한다(예약 작업 yh-raid가 5분 뒤에 할 일을 먼저)
  perform public.world_raid_settle(r.raid_id, false) from public.world_raids r where r.fx ? 'last_night' and r.status = 'fight';
  insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
  select 'global', s.owner_id, '봉연 소식', '정청의 마지막 등불 아래, 붉은 인장이 찍혔습니다. 첫째 밤이 끝납니다.' from public.world_staff s limit 1;
  revoke usage on schema public from public, anon, authenticated;
  begin perform cron.unschedule('yh-rollback-close'); exception when others then null; end;
end $f$;
revoke all on function public.world_rollback_close() from public, anon, authenticated;
select cron.schedule('yh-rollback-close', '0 15 1 11 *', 'select public.world_rollback_close()');

update public.world_app_meta set value = '20261103120000' where key = 'db_version';
