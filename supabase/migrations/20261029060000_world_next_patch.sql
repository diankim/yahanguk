-- 다음 패치 묶음(4.0.0 뒤): 한 번에 실행하는 파일이다.
--   ① 이동 중에는 탈것을 바꿀 수 없다(출발한 뒤 다른 탈것으로 갈아타던 것을 막는다)
--   ② 노정 건량 준비(make_travel_ration)의 의무관 전용 조건을 뺀다(원정·이동 보급품으로 쓰이는 곳이 많아 누구나 만들게)
--   (화면) 채팅의 구조 알림 줄: 시각이 「21:/00」처럼 세로로 쪼개지던 것을 한 줄로

grant fn_owner_18885 to postgres with inherit true, set true;

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

grant fn_owner_18885 to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029060000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
