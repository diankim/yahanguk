-- 탐색·전투 함수 전용 역할(로그인 불가, RLS 우회는 함수 안에서만).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fn_owner_field') THEN
    CREATE ROLE fn_owner_field NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
END $$;
GRANT USAGE ON SCHEMA public TO fn_owner_field;
