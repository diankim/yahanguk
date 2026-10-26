-- 원정 답사도 상승폭 조정: 8시간 원정 한 번에 90%까지 오르던 것을 신규 캐릭터 기준 긴 원정 3~4회로
GRANT fn_owner_expedition TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_expedition;
DO $$
DECLARE d text; i int;
  src text[] := ARRAY[
    'prog_gain := prog_gain + round((4 + c.perception / 4.0 + coalesce(c.investigation_rank, 1)) * prog_mul);',
    E'    prog_gain := prog_gain + 1;\n'];
  dst text[] := ARRAY[
    'prog_gain := prog_gain + round((2 + c.perception / 10.0 + least(coalesce(c.investigation_rank, 1), 10) / 2.0) * prog_mul);',
    ''];
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
