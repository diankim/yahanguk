-- 1) 캐릭터 생성: 이름·직업·소속은 최초 생성 시에만 지정하고 이후 변경할 수 없다(클라이언트 UPDATE 권한 없음 유지).
--    이름은 대소문자·앞뒤 공백을 무시하고 중복 불가.
-- 2) 본인 알림만 읽음 처리하는 RPC.
-- 3) 제작은 어디서나 가능하고, 제작법의 지정 장소에서 제작하면 품질 +12 가산.
--    제작 결과·오류 문구의 내부 키(아이템·직업·숙련) 대신 이름을 표시한다.
-- 클라이언트 테이블 권한, RLS, 기존 함수 소유권은 변경하지 않는다.

CREATE UNIQUE INDEX IF NOT EXISTS world_characters_name_unique
  ON public.world_characters (lower(btrim(character_name)));

-- ── 1) 캐릭터 생성 RPC (기존 world_create_character 소유 역할 fn_owner_19111 사용: SELECT·INSERT 보유) ──
GRANT fn_owner_19111 TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_19111;
SET ROLE fn_owner_19111;
CREATE OR REPLACE FUNCTION public.world_create_character_v2(p_name text, p_job text, p_faction text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  uid uuid := public.fn_owner_auth_uid();
  nm text := btrim(coalesce(p_name, ''));
  r public.world_characters%rowtype;
  job_label text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.' USING errcode = '28000'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_characters WHERE owner_id = uid) THEN
    RAISE EXCEPTION '이미 캐릭터가 있습니다. 이름·직업·소속은 생성 후 변경할 수 없습니다.';
  END IF;
  IF char_length(nm) < 2 OR char_length(nm) > 12 THEN RAISE EXCEPTION '이름은 2~12자로 입력하세요.'; END IF;
  IF nm !~ '^[가-힣A-Za-z0-9 ]+$' THEN RAISE EXCEPTION '이름에는 한글·영문·숫자·공백만 사용할 수 있습니다.'; END IF;
  job_label := CASE p_job WHEN 'exorcist' THEN '퇴마관' WHEN 'scout' THEN '현장 조사원' WHEN 'medic' THEN '의무관'
                 WHEN 'sealmaster' THEN '봉인술사' WHEN 'analyst' THEN '기록 분석관' WHEN 'artificer' THEN '법구 제작사' END;
  IF job_label IS NULL THEN RAISE EXCEPTION '직업을 선택하세요.'; END IF;
  IF p_faction IS NULL OR p_faction NOT IN ('headquarters','fieldbureau','archivebureau','sealbureau','medicalbureau','independent') THEN
    RAISE EXCEPTION '소속을 선택하세요.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.world_characters WHERE lower(btrim(character_name)) = lower(nm)) THEN
    RAISE EXCEPTION '이미 사용 중인 이름입니다.';
  END IF;
  BEGIN
    INSERT INTO public.world_characters(owner_id, character_name, occupation, inventory, job_key, faction_key)
    VALUES (uid, nm, job_label,
            '{"herb":2,"ward_talisman":1,"field_knife":1,"ore_pick":1,"seal_paper":1,"wood":0,"ore":0}'::jsonb,
            p_job, p_faction)
    RETURNING * INTO r;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION '이미 사용 중인 이름이거나 캐릭터가 이미 있습니다.';
  END;
  RETURN jsonb_build_object('ok', true, 'character_name', r.character_name, 'job_key', r.job_key, 'faction_key', r.faction_key);
END
$function$;
REVOKE ALL ON FUNCTION public.world_create_character_v2(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_create_character_v2(text, text, text) TO authenticated, service_role;
-- 기본 직업·소속으로 자동 생성하던 기존 RPC는 클라이언트 호출을 막는다(생성 흐름을 v2로 일원화).
-- 실행 권한 부여자가 소유 역할이므로 소유 역할로 회수한다.
REVOKE EXECUTE ON FUNCTION public.world_create_character(text) FROM authenticated;
RESET ROLE;
REVOKE CREATE ON SCHEMA public FROM fn_owner_19111;
GRANT fn_owner_19111 TO postgres WITH SET FALSE, INHERIT FALSE;


-- ── 2) 알림 읽음 처리 RPC (전용 최소 권한 역할) ──
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fn_owner_notification_read') THEN
    CREATE ROLE fn_owner_notification_read NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
END $$;
GRANT USAGE ON SCHEMA public TO fn_owner_notification_read;
GRANT EXECUTE ON FUNCTION public.fn_owner_auth_uid() TO fn_owner_notification_read;
GRANT SELECT (id, user_id, read_at) ON public.world_notifications TO fn_owner_notification_read;
GRANT UPDATE (read_at) ON public.world_notifications TO fn_owner_notification_read;
GRANT fn_owner_notification_read TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_notification_read;
SET ROLE fn_owner_notification_read;
CREATE OR REPLACE FUNCTION public.world_mark_notification_read(p_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE uid uuid := public.fn_owner_auth_uid(); nid bigint;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  UPDATE public.world_notifications SET read_at = coalesce(read_at, now())
   WHERE id = p_id AND user_id = uid
  RETURNING id INTO nid;
  IF nid IS NULL THEN RAISE EXCEPTION '알림을 찾을 수 없습니다.'; END IF;
  RETURN jsonb_build_object('ok', true, 'id', nid);
END
$function$;
REVOKE ALL ON FUNCTION public.world_mark_notification_read(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.world_mark_notification_read(bigint) TO authenticated, service_role;
RESET ROLE;
REVOKE CREATE ON SCHEMA public FROM fn_owner_notification_read;
GRANT fn_owner_notification_read TO postgres WITH SET FALSE, INHERIT FALSE;

-- ── 3) 제작: 장소 제한 → 장소 가산, 문구의 내부 키를 이름으로 ──
GRANT fn_owner_18452 TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_18452;
DO $$
DECLARE d text; nd text; i int;
  src text[] := ARRAY[
    'quality int; result_text text;',
    $s$ if r.required_location is not null and coalesce(c.location,'')<>r.required_location and not ((r.required_location='야행국 본부 정청' and c.location in ('본부 로비','야행국 본부 · 정청')) or (r.required_location='연무장·팔괘진' and c.location in ('훈련실','야행국 본부 · 연무장')) or (r.required_location='장서각 지하서고' and c.location in ('기록 보관실','야행국 본부 · 장서각'))) then raise exception '제작 장소가 맞지 않습니다. 필요 장소: %',r.required_location; end if;$s$,
    $s$+public.world_status_effect_total('action_quality_pct')));$s$,
    $s$' → '||r.output_item||' ×'||out_qty||' · 품질 '||quality||case when quality>=85 then ' · 고품질 추가 생산!' else '' end;$s$,
    $s$'quality',quality);$s$,
    $s$raise exception '필요 직업: %',r.required_job;$s$,
    $s$raise exception '필요 숙련도: % R%',r.required_skill,r.required_skill_rank;$s$,
    $s$raise exception '필요 도구를 장착해야 합니다: %',r.required_tool;$s$,
    $s$raise exception '재료 부족: % (필요 %, 보유 %)',k,need,have;$s$
  ];
  dst text[] := ARRAY[
    'quality int; result_text text; loc_bonus int:=0;',
    $s$ if r.required_location is not null and (coalesce(c.location,'')=r.required_location or (r.required_location='야행국 본부 정청' and c.location in ('본부 로비','야행국 본부 · 정청')) or (r.required_location='연무장·팔괘진' and c.location in ('훈련실','야행국 본부 · 연무장')) or (r.required_location='장서각 지하서고' and c.location in ('기록 보관실','야행국 본부 · 장서각'))) then loc_bonus:=12; end if;$s$,
    $s$+public.world_status_effect_total('action_quality_pct')+loc_bonus));$s$,
    $s$' → '||coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id=r.output_item),r.output_item)||' ×'||out_qty||' · 품질 '||quality||case when loc_bonus>0 then ' · 제작 장소 가산 +'||loc_bonus else '' end||case when quality>=85 then ' · 고품질 추가 생산!' else '' end;$s$,
    $s$'quality',quality,'location_bonus',loc_bonus);$s$,
    $s$raise exception '필요 직업: %',case r.required_job when 'exorcist' then '퇴마관' when 'scout' then '현장 조사원' when 'medic' then '의무관' when 'sealmaster' then '봉인술사' when 'analyst' then '기록 분석관' when 'artificer' then '법구 제작사' else r.required_job end;$s$,
    $s$raise exception '필요 숙련도: % R%',case r.required_skill when 'alchemy' then '연금' when 'smithing' then '단조' when 'spirit_gathering' then '영기 채집' when 'wardcraft' then '결계 각인' else r.required_skill end,r.required_skill_rank;$s$,
    $s$raise exception '필요 도구를 장착해야 합니다: %',coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id=r.required_tool),r.required_tool);$s$,
    $s$raise exception '재료 부족: % (필요 %, 보유 %)',coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id=k),k),need,have;$s$
  ];
BEGIN
  d := pg_get_functiondef('public.world_craft_item(text)'::regprocedure); nd := d;
  FOR i IN 1..array_length(src,1) LOOP
    IF position(src[i] in nd) = 0 THEN RAISE EXCEPTION '제작 함수 치환 대상 없음: %', left(src[i],60); END IF;
    nd := replace(nd, src[i], dst[i]);
  END LOOP;
  EXECUTE 'SET ROLE fn_owner_18452';
  EXECUTE nd;
  RESET ROLE;
END $$;
REVOKE CREATE ON SCHEMA public FROM fn_owner_18452;
GRANT fn_owner_18452 TO postgres WITH SET FALSE, INHERIT FALSE;
