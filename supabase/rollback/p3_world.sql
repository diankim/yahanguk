-- ── 3. 세계를 처음 상태로: 세력 판도·장야·예약 작업 ────────────────────────────────
-- 지역 지배는 본래 주인에게, 분쟁 없음
update public.world_map_regions r
   set control_faction_id = r.home_faction_id,
       faction_control = coalesce((select f.faction_name from public.world_major_factions f where f.faction_id = r.home_faction_id), r.faction_control),
       contested = false, control_changed_at = null
 where r.control_faction_id is distinct from r.home_faction_id or r.contested;
-- 세력 관계는 처음 값으로
update public.world_faction_relations set score = base, updated_at = now() where score is distinct from base;

-- 장야 끝: 11/2 0시부터는 늘 평상(0). 전에는 그 뒤로 영원히 4(끝나지 않는 밤)였다(효과 점검 2026-10-31)
create or replace function public.world_long_night_stage(p_ts timestamp with time zone default now())
 returns integer language sql immutable set search_path to 'pg_catalog'
as $function$
  select case when p_ts >= timestamptz '2026-11-02 00:00+09' then 0
              when p_ts >= timestamptz '2026-11-01 00:00+09' then 3
              when p_ts >= timestamptz '2026-10-31 00:00+09' then 2
              when p_ts >= timestamptz '2026-10-30 00:00+09' then 1 else 0 end
$function$;
delete from public.world_app_meta where key in ('long_night_announced', 'influence_at');

-- 예약 작업: 장야 알림은 끝, 롤백용 일회성 둘은 이미 스스로 지웠어야 한다(남아 있으면 지움)
do $c$
declare j text;
begin
  foreach j in array array['yh-long-night', 'yh-last-night-wipe', 'yh-rollback-close', 'yh-invite-day'] loop
    begin perform cron.unschedule(j); exception when others then null; end;
  end loop;
end $c$;

-- 봉연의 그림자 다음 회차를 새로 잡는다(지난 회차는 2에서 비웠다)
select public.world_raid_schedule_next();

-- 롤백 연출이 끝나 더 쓰지 않는 함수(2026-11-02 사용자 결정): 장야 알림·문 닫기·마지막 토벌 쓰러뜨림·마지막 토벌 기운.
-- 부르는 곳이 없고(예약 작업도 위에서 지움) 모두 postgres 주인. 장야 단계(world_long_night_stage)는 위에서 11/2부터 늘 0으로 바꿨고,
-- 날씨·시간대 함수 여러 곳이 부르므로 남긴다(효과 없음).
drop function if exists public.world_long_night_tick();
drop function if exists public.world_rollback_close();
drop function if exists public.world_last_night_wipe();
drop trigger if exists trg_world_last_night_raid on public.world_raids;  -- 마지막 합동 토벌(반드시 실패) 기운을 걸던 트리거
drop function if exists public.world_last_night_raid_fx();
