-- 초대에 응답하면 그 알림을 읽음 처리하는데(coalesce(read_at, now())), 응답 함수 역할에 read_at 조회 권한이 없어
-- 수락·거절이 "permission denied for table world_notifications"로 실패했다. 그 열만 조회 권한을 준다.
grant select (read_at) on public.world_notifications to fn_owner_19387;
