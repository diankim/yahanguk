-- [미적용 제안] 승인 후 apply_migration 으로 적용한다. 운영 DB에는 아직 적용되지 않았다.
--
-- 증상(2026-10-26 롤백 테스트로 재현): world_exploration_enter(소유 fn_owner_19603)가
--   INSERT INTO world_region_intel ... ON CONFLICT DO UPDATE 에서 42501 permission denied.
--   fn_owner_19603 은 world_region_intel 에 SELECT·INSERT 는 있으나 UPDATE 가 없어,
--   해당 지역 방문 기록이 이미 있는 캐릭터는 세부 지역 진입(계층 1~5)이 항상 실패한다.
-- 수정: DO UPDATE SET 이 갱신하는 컬럼 4개에만 UPDATE 를 부여한다.
-- 이 내용 그대로 롤백 트랜잭션에서 적용 후 진입 1→5단계, 탐색, 되돌아가기 정상 동작을 확인했다.
-- 클라이언트(anon/authenticated) 권한, RLS, 함수 소유권은 변경하지 않는다.

GRANT UPDATE (visits, surveyed_sites, last_visited_at, updated_at)
  ON public.world_region_intel TO fn_owner_19603;
