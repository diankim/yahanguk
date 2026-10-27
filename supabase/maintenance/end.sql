-- 점검 종료: start.sql에서 거둔 권한을 점검 전과 똑같이 돌려준다(기본값: PUBLIC·anon·authenticated에 USAGE).
GRANT USAGE ON SCHEMA public TO PUBLIC, anon, authenticated;
-- 확인: 둘 다 true여야 한다.
SELECT has_schema_privilege('anon', 'public', 'USAGE') AS anon_usage, has_schema_privilege('authenticated', 'public', 'USAGE') AS authenticated_usage;
