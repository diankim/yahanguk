-- 2026-10-26 운영 DB 적용 (버전 20261026194654). 적용 전후 함수 소유자·ACL·search_path·RLS 정책·클라이언트 권한 변화 없음 확인.
--
-- 증상(2026-10-26 롤백 테스트로 재현): 아래 클라이언트 RPC가 42501 permission denied 로 실패한다.
--   world_region_site_explore  -> world_character_statuses / world_status_catalog (INVOKER 헬퍼 world_status_effect_total)
--   world_travel_region        -> world_character_titles (INVOKER 헬퍼 world_title_bonus)
--   world_exploration_search_spot, world_region_encounter, world_start_idle_activity
--                              -> world_characters ... FOR UPDATE 잠금에 UPDATE 권한 필요
-- 원인: 정의자 함수 소유자를 최소 권한 역할로 이전하면서 헬퍼/행 잠금에 필요한 권한이 누락됨.
-- 이 파일 내용 그대로 롤백 트랜잭션에서 적용 후 위 RPC 전부 정상 동작을 확인했다.
-- 클라이언트(anon/authenticated) 권한은 바뀌지 않으며 RLS 는 그대로다.

-- 행 잠금(FOR UPDATE)만 필요한 역할: least_privilege_party_invite_row_lock 과 같은 패턴
GRANT UPDATE (updated_at) ON public.world_characters TO fn_owner_19604, fn_owner_18664, fn_owner_19180;

-- 상태이상·칭호 보너스 헬퍼(INVOKER)를 호출하는 정의자 함수의 소유 역할
GRANT SELECT ON public.world_character_statuses, public.world_status_catalog,
                public.world_character_titles, public.world_title_catalog
  TO fn_owner_18452, fn_owner_19605, fn_owner_18706, fn_owner_19255;
GRANT SELECT ON public.world_character_titles, public.world_title_catalog TO fn_owner_18663;
