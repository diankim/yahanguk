-- 상태이상·칭호 카탈로그와 서버 메시지의 중국어 표기를 한국어로 통일한다.
-- 키(status_key, title_key)와 게임 로직은 변경하지 않는다. 원문 백업: supabase/backups/20261026_status_title_catalog_original_zh.sql
-- 함수는 현재 정의에서 따옴표 포함 문자열 리터럴만 치환해 같은 소유 역할로 다시 만든다(소유자·ACL·search_path 유지).

UPDATE public.world_status_catalog s SET status_name=v.n, description=v.d FROM (VALUES
('adrenaline','혈기 분출','피가 끓어올라 공격이 강해지고 받는 피해가 약간 줄어든다.'),
('bleeding','출혈','기혈이 새어 나가 행동할 때마다 기혈이 줄고, 피격 시 상처가 깊어진다.'),
('burned','화상','화상이 아물지 않아 행동할 때 기혈이 줄고 제작에 집중하기 어렵다.'),
('careful_notes','기록 정리','기록이 체계적이라 단서 조합과 희귀 물자 발견이 수월하다.'),
('clear_mind','맑은 정신','마음이 맑아 정신 소모가 줄고 조사에서 단서를 찾기 쉽다.'),
('cold','한기 침입','한기가 몸에 스며 치료와 수련 효율이 떨어진다.'),
('combat_rhythm','전투 흐름','공수의 흐름을 타 공격이 날카로워지고 받는 피해가 약간 줄어든다.'),
('disoriented','방향 상실','방향 감각이 흐트러져 이동 시간이 늘고 조사 단서를 찾기 어렵다.'),
('erosion_whisper','사념 침식','사악한 속삭임이 정신을 어지럽혀 행동할 때 정신이 소모되지만, 이상 흔적을 알아챌 수도 있다.'),
('exhausted','탈진','기력이 다해 대부분의 행동 효율이 크게 떨어진다.'),
('fatigue','기력 저하','기력이 부족해 연구·단조·조사 효율이 떨어진다.'),
('fieldcraft','야외 숙련','야외 지리에 익숙해 채집과 흔적 식별에 능숙하다.'),
('focused','집중','정신을 모아 조사·연구·제작이 수월하다.'),
('inspired','영감','영감이 떠올라 수련 성과와 제작 품질이 오른다.'),
('keen_senses','예리한 감각','감각이 예민해 단서와 희귀 물자를 더 쉽게 발견한다.'),
('lucky_find','행운','운이 따라 탐사나 채집에서 수확을 얻기 쉽다.'),
('overtrained','근육통','과도한 훈련으로 근육이 아파 공격과 채집 효율이 떨어진다.'),
('poisoned','중독','독기가 몸에 퍼져 행동할 때마다 기혈이 계속 줄어든다.'),
('shaken','심신 동요','마음이 불안해 정신이 손상되고 공격이 약해진다.'),
('sprain','근맥 손상','근맥이 다쳐 몸놀림과 채집 효율이 떨어진다.'),
('steady_hands','안정된 손','손과 마음이 맞아 제작과 치료가 안정적이다.'),
('stomach_upset','소화 불량','속이 불편해 채집과 수련에 약간 지장이 있다.'),
('warded','부적 보호','부적이 몸을 지켜 받는 피해와 사기 침식이 줄어든다.'),
('well_rested','충분한 휴식','휴식을 마쳐 연구·조사·제작 효율이 오른다.'),
('well_tuned','근맥 이완','근맥을 풀어 행동과 공격이 더 조화롭다.')) v(k,n,d) WHERE s.status_key=v.k;

UPDATE public.world_title_catalog t SET title_name=v.n, description=v.d, condition_text=v.c FROM (VALUES
('all_rounder','다재다능','이동·조사·전투·제작을 두루 경험했다.','전투·조사·채집·제작 각각 누적 5회.'),
('artisan_apprentice','솜씨 입문','손재주를 거듭 다듬어 제작 품질이 안정되었다.','제작 누적 10회.'),
('artisan_master','백련 장인','숙련된 손으로 평범한 재료를 좋은 물건으로 만든다.','제작 누적 50회.'),
('case_reader','사건 판독자','증거를 정리해 작은 실마리에서 진실을 찾는다.','조사 누적 5회.'),
('first_footsteps','첫 야행','처음으로 탐사할 수 있는 땅에 발을 들여 길에 익숙해지기 시작했다.','첫 지역 탐사 완료.'),
('hundred_li','백 리 행보','여러 지역을 다녀 산천의 길에 익숙하다.','이동 기록 누적 20회.'),
('master_gatherer','산야의 눈','풀과 광맥에 밝아 채집 시 추가 수확이 잦다.','채집 누적 30회.'),
('monster_slayer','요괴 토벌자','여러 차례 요괴를 토벌해 손놀림이 더욱 과감해졌다.','전투 참여 누적 10회.'),
('regional_surveyor','사방 답사자','지역 간 차이와 이상 흔적을 잘 기록한다.','서로 다른 탐사 지점 10곳 발견.'),
('spirit_guard','사기 퇴치자','부적과 심법으로 침식을 막는 법을 안다.','호신 부적 누적 10회 사용.'),
('steady_mind','흔들림 없는 마음','이변을 겪고도 마음이 흔들리지 않는다.','조사 누적 10회, 정신 70 이상 유지.'),
('well_traveled','길에 밝은 자','여러 곳을 오가 흔한 길 위의 장애를 피할 줄 안다.','서로 다른 대지역 10곳 도착.')) v(k,n,d,c) WHERE t.title_key=v.k;

GRANT fn_owner_19041, fn_owner_20170, fn_owner_20256, fn_owner_20254 TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_19041, fn_owner_20170, fn_owner_20256, fn_owner_20254;

DO $$
DECLARE
  f record; d text; nd text; i int;
  src text[] := ARRAY[
    '''休息方式不正确。''','''先创建角色。''','''只能在当前所在区域休息。''','''在''','''找不到休息地点。''','''此地没有合适的休息地点。''',
    '''稍作调息，疲惫与心神不宁有所缓解。''','''行路途中无法休息。''','''请先登录。''','''调息休养。''','''重伤昏迷时无法自行休息。''',
    '''钱财不足，所需：%''','''静养完毕，部分伤势与负面状态已缓解。''',
    '''使用''','''此物品不能用于疗伤或祛除状态。''','''用药完毕，已恢复气血或心神，并解除对应异常。''','''背包中没有此物品。''',
    '''，恢复气血/心神并解除部分异常状态。''','''尚未获得此称号。'''];
  dst text[] := ARRAY[
    '''휴식 방식이 올바르지 않습니다.''','''캐릭터를 먼저 등록하세요.''','''현재 있는 지역에서만 휴식할 수 있습니다.''',''' · ''','''휴식 장소를 찾을 수 없습니다.''','''이곳에는 알맞은 휴식 장소가 없습니다.''',
    '''잠시 숨을 고르자 피로와 불안이 조금 가라앉았습니다.''','''이동 중에는 휴식할 수 없습니다.''','''로그인이 필요합니다.''','''에서 휴식했습니다.''','''중상으로 의식을 잃은 상태에서는 스스로 휴식할 수 없습니다.''',
    '''전이 부족합니다. 필요: %전''','''요양을 마쳐 일부 상처와 해로운 상태가 완화되었습니다.''',
    '''''','''이 물품은 치료나 상태 해제에 사용할 수 없습니다.''','''약품 사용 완료: 기혈 또는 정신을 회복하고 해당 이상 상태를 해제했습니다.''','''가방에 이 물품이 없습니다.''',
    ''' 사용 · 기혈/정신을 회복하고 일부 이상 상태를 해제했습니다.''','''아직 획득하지 않은 칭호입니다.'''];
BEGIN
  FOR f IN SELECT p.oid, p.proname, pg_get_userbyid(p.proowner) AS o FROM pg_proc p
           WHERE p.pronamespace='public'::regnamespace
             AND p.proname IN ('world_rest_at_spot','world_status_snapshot','world_status_treat','world_title_equip','world_title_snapshot')
  LOOP
    d := pg_get_functiondef(f.oid); nd := d;
    FOR i IN 1..array_length(src,1) LOOP nd := replace(nd, src[i], dst[i]); END LOOP;
    IF nd = d THEN RAISE EXCEPTION '변경 없음: %', f.proname; END IF;
    IF nd ~ '[一-鿿]' THEN RAISE EXCEPTION '한자 잔존: %', f.proname; END IF;
    IF f.o <> 'postgres' THEN EXECUTE format('SET ROLE %I', f.o); END IF;
    EXECUTE nd;
    RESET ROLE;
  END LOOP;
END $$;

REVOKE CREATE ON SCHEMA public FROM fn_owner_19041, fn_owner_20170, fn_owner_20256, fn_owner_20254;
GRANT fn_owner_19041, fn_owner_20170, fn_owner_20256, fn_owner_20254 TO postgres WITH SET FALSE, INHERIT FALSE;
