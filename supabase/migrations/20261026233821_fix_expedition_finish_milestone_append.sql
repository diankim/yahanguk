-- 원정 결과 계산: 배열에 이정표를 붙일 때 array_append 사용
GRANT fn_owner_expedition TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_expedition;
DO $$
DECLARE d text; i int;
  src text[] := ARRAY['new_ms := new_ms || ''depth2''', 'new_ms := new_ms || ''depth3''', 'new_ms := new_ms || ''complete'''];
  dst text[] := ARRAY['new_ms := array_append(new_ms, ''depth2'')', 'new_ms := array_append(new_ms, ''depth3'')', 'new_ms := array_append(new_ms, ''complete'')'];
BEGIN
  d := pg_get_functiondef('public.world_expedition_finish(boolean)'::regprocedure);
  FOR i IN 1..array_length(src, 1) LOOP
    IF position(src[i] in d) = 0 THEN RAISE EXCEPTION '치환 대상 없음: %', src[i]; END IF;
    d := replace(d, src[i], dst[i]);
  END LOOP;
  EXECUTE 'SET ROLE fn_owner_expedition';
  EXECUTE d;
  RESET ROLE;
END $$;
REVOKE CREATE ON SCHEMA public FROM fn_owner_expedition;
GRANT fn_owner_expedition TO postgres WITH SET FALSE, INHERIT FALSE;
