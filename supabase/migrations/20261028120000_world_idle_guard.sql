-- 자율 활동 중에는 현장 행동(이동·탐색·전투·채집·낚시·휴식·제작·분해·강화·수리·상점·거래소·직접 거래·원정·구조·의뢰 등)을 막는다.
-- 원정 중 행동을 막는 world_events 트리거(world_guard_action_context)에 같은 규칙을 더한다.
-- 허용: 성장·세력 임무·보급·단서 조합·이야기·전리품 분배·물품 사용·장비 바꾸기, 값 없는 거래 기록(등록 취소 등), 자율 활동 시작 전에 떠난 이동의 도착.
grant fn_owner_expedition to postgres with inherit true;
do $$
declare d text;
  a1 text := $q$away boolean; passenger uuid;$q$;
  a2 text := $q$away := EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = new.actor_id AND e.status = 'active');$q$;
  a3 text := $q$IF away AND NOT ($q$;
begin
  d := pg_get_functiondef('public.world_guard_action_context()'::regprocedure);
  if position('idling' in d) > 0 then return; end if;
  if position(a1 in d) = 0 or position(a2 in d) = 0 or position(a3 in d) = 0 then raise exception '행동 검사 함수에서 고칠 줄을 찾지 못했습니다'; end if;
  d := replace(d, a1, $q$away boolean; passenger uuid; idling boolean;$q$);
  d := replace(d, a2, a2 || $q$
  idling := EXISTS (SELECT 1 FROM public.world_idle_activities i WHERE i.owner_id = new.actor_id AND i.status = 'active');$q$);
  d := replace(d, a3, $q$IF k = 'travel' AND p ? 'passenger_id'
     AND EXISTS (SELECT 1 FROM public.world_idle_activities i WHERE i.owner_id = nullif(p ->> 'passenger_id', '')::uuid AND i.status = 'active') THEN
    RAISE EXCEPTION '동승자가 자율 활동 중이라 함께 출발할 수 없습니다.';
  END IF;
  IF idling AND NOT (
       k IN ('progression', 'mission', 'supply', 'case_combine', 'case_resolved', 'story', 'loot', 'use_item', 'equip', 'unequip')
    OR (k = 'trade' AND NOT (p ? 'unit_price') AND NOT (p ? 'gil'))
    OR (k = 'travel' AND p ? 'travel_history_id')) THEN
    RAISE EXCEPTION '자율 활동 중에는 할 수 없습니다. 활동이 끝나 보상을 받은 뒤 다시 시도하세요.';
  END IF;
  $q$ || a3);
  execute d;
end $$;
grant fn_owner_expedition to postgres with inherit false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028120000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
