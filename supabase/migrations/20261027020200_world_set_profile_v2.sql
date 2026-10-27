-- 프로필 저장이 사진·대표 칭호까지 지우던 문제: 문장·색·소개만 합쳐 넣는 새 함수(적용 기록: 2026-10-27 SQL 도구로 실행)
CREATE OR REPLACE FUNCTION public.world_set_profile_v2(p_emblem text, p_color text, p_bio text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $f$
DECLARE uid uuid := public.fn_owner_auth_uid(); bio text := btrim(coalesce(p_bio, '')); prof jsonb;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_emblem IS NULL OR p_emblem NOT IN ('moon','lantern','seal','bell','lotus','blade','crane','flame','wave','mountain','star','eye') THEN RAISE EXCEPTION '문장을 선택하세요.'; END IF;
  IF p_color IS NULL OR p_color NOT IN ('vermilion','gold','jade','indigo','violet','ash','crimson','teal','amber','ivory') THEN RAISE EXCEPTION '색을 선택하세요.'; END IF;
  IF char_length(bio) > 60 THEN RAISE EXCEPTION '소개는 60자 이내로 적어 주세요.'; END IF;
  -- 사진·대표 칭호는 그대로 두고 문장·색·소개만 바꾼다.
  UPDATE public.world_characters SET profile = coalesce(profile, '{}'::jsonb) || jsonb_build_object('emblem', p_emblem, 'color', p_color, 'bio', bio), updated_at = now()
  WHERE owner_id = uid RETURNING profile INTO prof;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  RETURN jsonb_build_object('ok', true, 'profile', prof, 'content', '프로필을 저장했습니다.');
END $f$;
ALTER FUNCTION public.world_set_profile_v2(text, text, text) OWNER TO fn_owner_field;
SET ROLE fn_owner_field;
REVOKE ALL ON FUNCTION public.world_set_profile_v2(text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.world_set_profile_v2(text, text, text) TO authenticated;
RESET ROLE;

-- 전투 능력치에 익힌 전투 기술의 상시 효과를 더한다(근접·원거리·봉인 계열 피해, 분석 계열 치명타).
-- 적용 기록: 2026-10-27 SQL 도구로 world_combat_stats를 다시 만들었다(본문은 20261027020000의 함수에 아래 부분을 더한 것).
--   skill_cat := CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'sealing' ELSE 'melee' END;
--   skill_pct  = 익힌(계열 단계 ≥ 해금 단계) 같은 계열 기술의 passive_effect.damage_pct 합 → 주는 피해 %에 더함
--   skill_crit = 같은 계열·분석 계열 기술의 passive_effect.crit_pct 합 → 치명타율에 더함
--   반환값에 skill_pct, skills(적용 중인 기술 이름) 추가
GRANT SELECT ON public.world_skill_catalog TO fn_owner_field;
