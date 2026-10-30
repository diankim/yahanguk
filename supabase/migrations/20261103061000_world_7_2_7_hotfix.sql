-- 7.2.7 긴급 수정(운영 DB에 바로 적용함): 「안전지대 도착이면 상태 굴림 안 함」이 world_status_roll 안에서 world_map_regions를 읽었는데,
-- 이 함수를 부르는 이동 기록 트리거(world_apply_activity_status, 주인 fn_owner_20175)에는 그 표를 읽을 권한이 없어
-- 이동 도착 처리(world_travel_status)가 「permission denied for table world_map_regions」로 실패했다(이동이 끝나지 않음).
-- 안전지대 여부만 돌려주는 world_region_safe(주인 postgres, security definer)를 두고 그것을 부른다. 멈춰 있던 4명은 도착 처리를 대신 돌렸다.
create or replace function public.world_region_safe(p_region text) returns boolean
  language sql stable security definer set search_path = pg_catalog, public
  as $f$ select coalesce((select m.is_safe_zone from public.world_map_regions m where m.region_id = p_region), false) $f$;
revoke all on function public.world_region_safe(text) from public, anon, authenticated;
grant execute on function public.world_region_safe(text) to fn_owner_20175, fn_owner_field;
do $$ begin
  execute replace(pg_get_functiondef('public.world_status_roll(text,jsonb)'::regprocedure),
    $o$exists (select 1 from public.world_map_regions m where m.region_id = p_context->>'region_id' and m.is_safe_zone)$o$,
    $o$public.world_region_safe(p_context->>'region_id')$o$);
end $$;
