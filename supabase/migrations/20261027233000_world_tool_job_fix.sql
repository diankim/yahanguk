-- 장착 조건 바로잡기: 다른 직업의(또는 직업 무관) 제작법이 필요로 하는 도구가 한 직업 전용이라 그 제작법을 영영 못 만들던 문제
-- - 각인 공구(seal_knife): 법구 제작사 전용이었지만 봉인술사 전용 제작법(각인판 가공·봉인 먹 제조)과
--   직업 무관 제작법(정화 부적·회생 부적·영유리 용해)이 이 도구를 장착해야 한다 → 직업 제한을 푼다(감각 7 조건은 유지).
-- - 강화 채집도(field_knife_2): 법구 제작사 전용이었지만 직업 무관 제작법(영사 방적·강화 부적목·강화 요수 가죽·영맥 낫 제작)의 도구다
--   → 직업 제한을 푼다(근력 7 조건은 유지).
-- - 그대로 두는 것: 영맥 낫(현장 조사원 전용·감각 6, 다른 제작법의 도구가 아님) · 호신 도포(의지·영성 7) · 월식도(근력 8, 근접 무기).
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

update public.world_item_catalog set required_job = null where item_id in ('seal_knife', 'field_knife_2') and required_job is not null;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261027233000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select item_id, item_name, required_job, required_stats from public.world_item_catalog where item_id in ('seal_knife', 'field_knife_2', 'spirit_sickle', 'ward_robe', 'moon_blade') order by item_id;
