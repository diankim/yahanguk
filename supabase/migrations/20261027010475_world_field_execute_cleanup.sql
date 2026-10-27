-- fn_owner_field 함수의 실행 권한 정리: Supabase 기본 권한으로 붙은 anon·authenticated 실행 권한을 걷고,
-- 화면이 직접 부르는 RPC만 로그인 사용자에게 연다. 다시 실행해도 같은 결과가 나온다.
SET ROLE fn_owner_field;
DO $$
DECLARE f record;
  rpc text[] := ARRAY['world_field_snapshot','world_field_move','world_battle_action','world_field_search','world_field_gather','world_hud_snapshot',
    'world_travel_route','world_expedition_overview','world_expedition_start','world_expedition_complete','world_survey_overview','world_use_item',
    'world_call_rescue','world_field_rest','world_set_life_profession_v2','world_set_avatar','world_corpse_respect','world_corpse_loot',
    'world_character_delete','world_story_board','world_story_combine','world_commission_board','world_commission_claim'];
BEGIN
  FOR f IN SELECT p.oid::regprocedure AS sig, p.proname FROM pg_proc p JOIN pg_roles r ON r.oid = p.proowner
           WHERE p.pronamespace = 'public'::regnamespace AND r.rolname = 'fn_owner_field' LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f.sig);
    IF f.proname = ANY (rpc) THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f.sig); END IF;
  END LOOP;
END $$;
RESET ROLE;
