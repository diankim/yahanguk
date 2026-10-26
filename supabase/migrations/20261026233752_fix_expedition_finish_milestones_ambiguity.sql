-- 원정 결과 계산: 변수 milestones가 열 이름과 겹쳐 실패하던 문제
GRANT fn_owner_expedition TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_expedition;
DO $$
DECLARE d text; i int;
  src text[] := ARRAY[
    'milestones text[]; new_ms',
    'SELECT progress, milestones INTO prog_before, milestones FROM public.world_region_progress WHERE owner_id = uid AND region_id = r.region_id FOR UPDATE;',
    '''depth2'' = ANY (milestones)', '''depth3'' = ANY (milestones)', '''complete'' = ANY (milestones)',
    'milestones = milestones || new_ms'];
  dst text[] := ARRAY[
    'ms_list text[]; new_ms',
    'SELECT p.progress, p.milestones INTO prog_before, ms_list FROM public.world_region_progress p WHERE p.owner_id = uid AND p.region_id = r.region_id FOR UPDATE;',
    '''depth2'' = ANY (ms_list)', '''depth3'' = ANY (ms_list)', '''complete'' = ANY (ms_list)',
    'milestones = world_region_progress.milestones || new_ms'];
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
