-- 점검 시작: 게임 화면·외부 호출 모두 public 스키마(게임 데이터·RPC)에 접근하지 못하게 한다.
-- 데이터는 건드리지 않는다. 함수 전용 역할(fn_owner_*)·postgres·service_role은 따로 권한이 있어 영향이 없다.
-- 되돌리기: end.sql. SQL Editor에서 실행한다.
REVOKE USAGE ON SCHEMA public FROM PUBLIC, anon, authenticated;
-- 확인: 둘 다 false여야 한다.
SELECT has_schema_privilege('anon', 'public', 'USAGE') AS anon_usage, has_schema_privilege('authenticated', 'public', 'USAGE') AS authenticated_usage;
