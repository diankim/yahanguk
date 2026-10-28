-- 다음 대규모 패치(5.0.0) 묶음: 그 패치 때 한 번에 실행하는 파일이다(작은 SQL을 따로따로 돌리지 않는다).
--   ① 이동 중에는 탈것을 바꿀 수 없다(출발한 뒤 다른 탈것으로 갈아타던 것을 막는다)
--   ② 노정 건량 준비(make_travel_ration)의 의무관 전용 조건을 뺀다(원정·이동 보급품으로 쓰이는 곳이 많아 누구나 만들게)
--   ③ 전체 채팅에 쓰러짐을 알린 조사원이 다시 일어나면(구조·본부 구조대·회복품·요화 봉인) 그 소식도 한 줄 남긴다(헛걸음 방지)
--   (화면) 채팅의 구조 알림 줄: 시각이 「21:/00」처럼 세로로 쪼개지던 것을 한 줄로
--   (화면) 환골탈태 서첩 창: 모바일에서 직업·소속 12칸이 한 줄씩 쌓여 「이대로 다시 시작」 단추가 한참 아래로 밀려 안 보이던 것을 두 줄 격자·아래 고정 단추로
--   (화면) 동료 화면 친구·모임: 단추가 이름에서 멀리 떨어져 늘어나던 것을 사람·모임마다 카드로 나누고 단추를 이름 곁에
--   (화면) 채팅 안내 문구 「하루 50회」 (가방 검색 한글 깨짐은 4.0.0 32번으로 먼저 배포함)

grant fn_owner_18885 to postgres with inherit true, set true;
grant fn_owner_18987 to postgres with inherit true, set true;

-- ① ─────────────────────────────────────────
-- world_mount_equip: 이동 중(travel_destination이 남아 있는 동안 — 도착·취소 때 비워진다)에는 거절한다
do $$ declare d text := pg_get_functiondef('public.world_mount_equip(text)'::regprocedure);
  a text := 'IF NOT EXISTS(SELECT 1 FROM public.world_owned_mounts WHERE owner_id=uid AND mount_id=p_mount_id) THEN';
  b text := 'IF c.travel_destination IS NOT NULL THEN RAISE EXCEPTION ''이동 중에는 탈것을 바꿀 수 없습니다. 도착한 뒤에 바꾸세요.''; END IF; ';
begin
  if position('이동 중에는 탈것을 바꿀 수 없습니다' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '탈것 바꾸기 고칠 자리'; end if;
  execute replace(d, a, b || a);
end $$;

-- ② ─────────────────────────────────────────
-- 노정 건량 준비: 직업 조건 없음(재료·도구·지정 장소 품질 보너스는 그대로)
update public.world_crafting_recipes set required_job = null where recipe_id = 'make_travel_ration' and required_job = 'medic';

-- ③ ─────────────────────────────────────────
-- world_notify_downed(world_characters 갱신 트리거): 쓰러짐(health 0)을 알리던 같은 트리거에, downed_at이 비워지며 다시 일어난 경우를 더한다.
-- 다시 일어나는 길(world_rescue_character·world_call_rescue·world_use_item·world_use_recovery_item·world_yohwa_seal)은 모두 downed_at을 비우므로 여기 한 곳에서 잡힌다.
-- 사망(is_dead)은 알리지 않는다. 행동마다 쓰기를 늘리지 않는다(다시 일어날 때 채팅 한 줄뿐).
do $$ declare d text := pg_get_functiondef('public.world_notify_downed()'::regprocedure);
  a text := E' end if;\n return new;\nend';
  b text := E' elsif old.downed_at is not null and new.downed_at is null and new.health > 0 and not coalesce(new.is_dead, false) then\n'
    || E'  insert into public.world_chat_messages(channel_type,sender_id,sender_name,content) values(''global'',new.owner_id,''구조 알림'',\n'
    || E'    new.character_name||'' 조사원이 다시 일어났습니다''||case when new.location is distinct from old.location then ''(''||coalesce(new.location,''안전지대'')||''(으)로 옮겨짐)'' else '''' end||''. 구조하러 가지 않아도 됩니다.'');\n'
    || E' end if;\n return new;\nend';
begin
  if position('다시 일어났습니다' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '쓰러짐 알림 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

grant fn_owner_18885 to postgres with inherit false, set false;
grant fn_owner_18987 to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029060000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
