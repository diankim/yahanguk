-- 2026-10-26 운영 DB 적용 (버전 20261026200537).
-- 클라이언트 RPC 전수 점검(롤백)에서 42501 로 실패한 3개 함수의 행 잠금 권한 복구.
-- 세 함수 모두 해당 테이블을 FOR UPDATE 로 잠그기만 하고 쓰지 않으므로
-- least_privilege_party_invite_row_lock 과 같은 패턴으로 updated_at 컬럼 UPDATE 만 부여한다.
--   world_equip_item (fn_owner_18453), world_title_equip (fn_owner_20254) -> world_characters
--   world_case_combine_regional (fn_owner_19968)                          -> world_case_progress
-- 클라이언트(anon/authenticated) 권한, RLS, 함수 소유권은 변경하지 않는다.
GRANT UPDATE (updated_at) ON public.world_characters TO fn_owner_18453, fn_owner_20254;
GRANT UPDATE (updated_at) ON public.world_case_progress TO fn_owner_19968;
