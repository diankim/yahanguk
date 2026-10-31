-- 7.5.5 — 이동 중 퀘스트 받기·보고 막기(제보) + PC 가방 › 장비 좌우 배치(화면만) 패치노트
-- 이동 중(travel_arrives_at이 남아 있는 동안)에는 world_quest_report(받기·장면 보고)·world_faction_report(세력 퀘스트 보고)를 거절한다.
-- 전에는 출발한 곳(location)이 그대로 남아 있어 이동 중에도 그곳 인물에게 받기·보고가 됐다.
do $p$
declare d text; a text; n int; f text;
begin
  -- 보조·주 이야기 퀘스트
  f := 'public.world_quest_report(text)';
  d := replace(pg_get_functiondef(f::regprocedure), E'\r\n', E'\n');
  if position('이동 중에는 퀘스트를' in d) = 0 then
    a := $o$  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 보고할 수 없습니다.'; end if;$o$;
    n := (length(d) - length(replace(d, a, ''))) / length(a);
    if n <> 1 then raise exception '7.5.5 quest_report anchor %', n; end if;
    execute replace(d, a, a || $n$
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 퀘스트를 받거나 보고할 수 없습니다. 도착한 뒤에 하세요.'; end if;$n$);
  end if;
  -- 세력 퀘스트
  f := 'public.world_faction_report()';
  d := replace(pg_get_functiondef(f::regprocedure), E'\r\n', E'\n');
  if position('이동 중에는 세력 퀘스트를' in d) = 0 then
    a := $o$  if c.major_faction_id is null then raise exception '대세력에 들어야 합니다.'; end if;$o$;
    n := (length(d) - length(replace(d, a, ''))) / length(a);
    if n <> 1 then raise exception '7.5.5 faction_report anchor %', n; end if;
    execute replace(d, a, a || $n$
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 세력 퀘스트를 보고할 수 없습니다. 도착한 뒤에 하세요.'; end if;$n$);
  end if;
end $p$;

-- 이동 중 막기 넓히기(사용자 요청): 퀘스트·창고·세력·마구간·서신·시설·거래 같은 「그 자리」 행동은 이동 중에 거절한다.
-- 도우미 world_travel_guard(무엇)를 함수 본문 첫머리에 넣는다(이미 넣었으면 건너뜀). 자율 활동 막기(world_guard_action_context)처럼
-- 행동 기록 트리거에 기대면 앞쪽 검사(재료·장소)에서 먼저 걸려 이동 중인데도 그 일이 되던 것(창고 버리기·의뢰 보고 등)이 있었다.
create or replace function public.world_travel_guard(p_what text default null)
returns void language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $g$
declare t timestamptz;
begin
  select travel_arrives_at into t from public.world_characters where owner_id = public.fn_owner_auth_uid();
  if t is not null and t > now() then
    raise exception '이동 중에는 %을(를) 할 수 없습니다. 도착한 뒤에 하세요.', coalesce(p_what, '이 일');
  end if;
end $g$;
revoke all on function public.world_travel_guard(text) from public, anon, authenticated;

do $p$
declare
  m jsonb := jsonb_build_object(
    'world_storage_discard(text,integer)', '창고 정리',
    'world_housing_store_move(text,integer,text)', '곳간 정리',
    'world_quest_abandon(text)', '퀘스트 포기',
    'world_commission_claim(integer)', '의뢰 보고',
    'world_faction_request_claim(text)', '세력 의뢰 보고',
    'world_faction_donate(jsonb)', '세력 기부',
    'world_faction_vault_buy(text,integer)', '비고 교환',
    'world_faction_trial()', '수련장 도전',
    'world_claim_faction_supply()', '보급 수령',
    'world_faction_mission_action(text)', '소속 임무',
    'world_join_major_faction(text)', '세력 가입',
    'world_leave_major_faction()', '세력 떠나기',
    'world_mount_acquire(text)', '탈것 들이기',
    'world_mount_train(text)', '탈것 단련',
    'world_letter_claim(bigint)', '서신 물품 받기',
    'world_letter_place_check(uuid)', '물품 서신',
    'world_corpse_loot(uuid)', '시신 수습',
    'world_rescue_character(uuid)', '구조',
    'world_equipment_repair(text,text)', '수리',
    'world_equipment_repair_all()', '수리',
    'world_weapon_enhance()', '강화',
    'world_dismantle_item(text)', '분해',
    'world_shop_buy(text,integer)', '상점 거래',
    'world_shop_sell(text,integer)', '상점 거래',
    'world_trade_offer_create(text,integer,bigint)', '거래소 등록',
    'world_trade_offer_buy(uuid)', '거래소 구매',
    'world_trade_direct_offer(uuid,jsonb,bigint,jsonb,bigint)', '직접 거래',
    'world_trade_direct_respond(uuid,boolean)', '직접 거래',
    'world_tourney_signup(text,uuid)', '비무회 신청',
    'world_wedding_ask()', '혼례 청하기',
    'world_raid_join(uuid)', '토벌 합류',
    'world_raid_final_start()', '결전',
    'world_pfight_call()', '동료 부르기',
    'world_pfight_join(uuid)', '함께 싸우기',
    'world_case_combine_regional()', '사건 보고',
    'world_story_combine(text)', '가설 확정',
    'world_survival_action(text)', '마음 다잡기');
  k text; d text; nd text; own text; inh boolean; granted text[] := '{}';
begin
  for k in select jsonb_object_keys(m) loop
    select p.proowner::regrole::text into own from pg_proc p where p.oid = k::regprocedure;
    if not own = any (granted) then
      execute format('grant execute on function public.world_travel_guard(text) to %I', own);
      granted := granted || own;
    end if;
    d := replace(pg_get_functiondef(k::regprocedure), E'\r\n', E'\n');
    continue when position('world_travel_guard(' in d) > 0;
    -- 함수 머리(AS $function$) 뒤 첫 begin 바로 다음에 넣는다
    nd := substr(d, 1, position('$function$' in d) + 9)
       || regexp_replace(substr(d, position('$function$' in d) + 10), '\mbegin\M', 'begin perform public.world_travel_guard(' || quote_literal(m ->> k) || ');', 'i');
    if nd = d then raise exception '7.5.5 travel guard: % 첫 begin을 못 찾음', k; end if;
    -- postgres가 주인 역할로 행동할 수 없으면 잠깐 이어 주고 되돌린다(앞선 패치와 같은 방식)
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute nd;
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

update public.world_patch_notes set body = body || $N$

## 7.5.5
- PC 가방 › 장비를 왼쪽 「장착 중인 장비」 칸과 오른쪽 「고른 부위」(지금 장비·수리·벗기·바꿔 낄 장비)로 나란히 보이게 바꿨습니다. 왼쪽 칸을 누르면 오른쪽이 그 부위로 바뀌어, 벗은 뒤 바로 옆에서 다시 낄 수 있습니다.
- 이동 중에는 그 자리에서 하는 일을 할 수 없게 했습니다: 퀘스트 받기·보고·포기(세력 퀘스트 포함), 의뢰 보고, 가설 확정, 창고·곳간 정리, 세력 의뢰·기부·비고·수련장·보급·가입·떠나기, 마구간, 물품 서신, 상점·대장간·거래소·직접 거래, 구조, 비무회 신청, 토벌 합류 등. 전에는 떠나온 곳이 그대로 남아 있어 이동 중에도 몇 가지가 됐습니다. 도착한 뒤에 하세요.
- 배경음악이 겹쳐 들리던 것을 고쳤습니다. 게임 창을 여러 개 열면 창마다 음악을 틀었는데, 이제 가장 최근에 누른 창 하나만 배경음악·환경음을 냅니다. 채팅·귓속말 새 창은 효과음을 포함해 소리를 내지 않습니다.
- 채팅을 새 창에서 게임 창으로 되돌렸을 때 그 사이의 말이 비어 중간이 잘려 보이던 것을 고쳤습니다. 되돌릴 때 전체·지역·세력 탭마다 최근 말을 다시 읽어 붙입니다.
- 현장 장소 그림의 비·눈·바람·별빛이 기기의 「동작 줄이기」 설정과 상관없이 움직입니다(붉은 안개와 같음). 그 밖의 화면 움직임은 설정대로 멈춥니다.
$N$
 where note_id = '7.5.0' and position('## 7.5.5' in body) = 0;

update public.world_app_meta set value = '20261104040000' where key = 'db_version';
