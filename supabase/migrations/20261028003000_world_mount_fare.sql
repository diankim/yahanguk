-- 노정패 소모 바로잡기 + 현장 화면 오류(무기 위력 소수) 고치기
-- 1) 현장 화면 오류: world_field_snapshot이 무기 위력(power)을 정수로 읽어 2단계 묵직 무기(위력 13.8)를 끼면
--    "invalid input syntax for type integer: 13.8"로 현장 화면 전체가 멈췄다 → 소수로 읽는다.
--    채집 도구 보너스(world_field_gather)도 같은 식으로 읽는다. (2026-10-27 운영 DB에 이미 적용함, 다시 실행해도 같다)
-- 2) 노정패가 쌓이기만 하던 문제: 모두가 운임 없는 탈것(낡은 손수레·홍인 해태)을 타고, 탐색·채집·제작·매매마다 1개씩 들어왔다.
--    - 모든 탈것에 구간당 운임을 둔다: 낡은 손수레·짐노새·홍인 해태·안개 사슴 1 · 야행마·수향 나룻배·재빛 늑대·월광록 2.
--    - 지도 경로 이동(world_travel_route)은 구간 수 × 운임을 출발할 때 낸다(동승 요청은 지금처럼 파티장이 1회).
--    - 노정패가 모자라면 탈것에서 내려 걸어간다(속도 ×1, 운임 없음). 길이 막히지 않는다.
--    - 얻는 곳: 토벌 승리 1 · 탐색·채집 4번에 1번꼴 1 · 이야기 3 · 의뢰·임무 2 · 원정 귀환 2 (제작·매매·거래는 주지 않는다).
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 결과가 같다.

-- 1) 현장 화면
do $$
declare d text; a text;
begin
  d := pg_get_functiondef('public.world_field_snapshot'::regproc);
  a := $a$coalesce((i.equipment_traits ->> 'power')::int, 0)$a$;
  if position(a in d) > 0 then
    execute replace(d, a, $b$round(coalesce((i.equipment_traits ->> 'power')::numeric, 0), 1)$b$);
  end if;
  d := pg_get_functiondef('public.world_field_gather'::regproc);
  a := $a$coalesce((i.equipment_traits ->> 'gathering_bonus_pct')::int, 0)$a$;
  if position(a in d) > 0 then
    execute replace(d, a, $b$round(coalesce((i.equipment_traits ->> 'gathering_bonus_pct')::numeric, 0))::int$b$);
  end if;
end $$;

-- 2) 탈것 운임(구간당)
update public.world_mount_catalog m
   set fare_free = false, fare_tokens = v.fare
  from (values ('starter_cart', 1), ('pack_mule', 1), ('seal_haetae', 1), ('mist_deer', 1),
               ('night_horse', 2), ('river_skiff', 2), ('ash_wolf', 2), ('moon_elk', 2)) as v(mount_id, fare)
 where m.mount_id = v.mount_id and (m.fare_free or m.fare_tokens <> v.fare);

-- 경로 이동: 구간 수 × 운임, 모자라면 걸어서
do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_travel_route'::regproc);
  if position('walked boolean' in d) > 0 then return; end if;
  d := replace(d, 'vis int; arrives timestamptz;', 'vis int; fare_per int; fare int := 0; walked boolean := false; arrives timestamptz;');
  if position('fare_per int' in d) = 0 then raise exception 'anchor 1'; end if;
  d := replace(d, 'path := si || path;',
    'path := si || path;' || chr(10) ||
    '  SELECT CASE WHEN coalesce(m.fare_free, false) THEN 0 ELSE greatest(0, coalesce(m.fare_tokens, 1)) END INTO fare_per FROM public.world_mount_catalog m WHERE m.mount_id = c.mount_id;' || chr(10) ||
    '  fare := coalesce(fare_per, 0) * (cardinality(path) - 1);' || chr(10) ||
    '  IF fare > 0 AND c.mount_tokens < fare THEN speed := 1; walked := true; fare := 0; END IF;');
  if position('walked := true' in d) = 0 then raise exception 'anchor 2'; end if;
  d := replace(d, 'UPDATE public.world_characters SET gil = gil - fee,', 'UPDATE public.world_characters SET gil = gil - fee, mount_tokens = mount_tokens - fare,');
  if position('mount_tokens = mount_tokens - fare' in d) = 0 then raise exception 'anchor 3'; end if;
  d := replace(d, 'INSERT INTO public.world_travel_history(owner_id, from_region, to_region, arrives_at) VALUES (uid, c.location, dest.region_name, arrives);',
    'INSERT INTO public.world_travel_history(owner_id, from_region, to_region, arrives_at, fare_exempt) VALUES (uid, c.location, dest.region_name, arrives, true);' || chr(10) ||
    '  IF fare > 0 THEN INSERT INTO public.world_economy_ledger(owner_id, action, currency_delta, sink, details) VALUES (uid, ''mount_fare'', -fare, true, jsonb_build_object(''mount_id'', c.mount_id, ''to'', dest.region_name, ''hops'', cardinality(path) - 1)); END IF;');
  if position('arrives, true);' in d) = 0 then raise exception 'anchor 4'; end if;
  d := replace(d, $q$'mount', c.mount_id));$q$, $q$'mount', CASE WHEN walked THEN NULL ELSE c.mount_id END, 'fare_tokens', fare, 'walked', walked));$q$);
  if position($q$'walked', walked));$q$ in d) = 0 then raise exception 'anchor 5'; end if;
  d := replace(d, $q$'(으)로 출발했습니다. ' ||$q$,
    $q$'(으)로 출발했습니다. ' || CASE WHEN walked THEN '노정패가 모자라 탈것에서 내려 걸어갑니다. ' WHEN fare > 0 THEN '노정패 ' || fare || '개를 냈습니다. ' ELSE '' END ||$q$);
  if position('걸어갑니다' in d) = 0 then raise exception 'anchor 6'; end if;
  d := replace(d, $q$'fee', fee);$q$, $q$'fee', fee, 'fare_tokens', fare, 'walked', walked);$q$);
  if position($q$'fee', fee, 'fare_tokens'$q$ in d) = 0 then raise exception 'anchor 7'; end if;
  execute d;
end $$;

-- 노정패 얻는 곳 줄이기
grant fn_owner_19205 to postgres with inherit true;
create or replace function public.world_award_mount_tokens()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare reward integer := 0;
begin
  if new.actor_id is null then return new; end if;
  if new.event_type = 'combat' and coalesce((new.payload ->> 'defeated')::boolean, false) then reward := 1;
  elsif new.event_type in ('explore', 'gather') and random() < 0.25 then reward := 1;
  elsif new.event_type = 'story' then reward := 3;
  elsif new.event_type in ('commission', 'mission', 'expedition_end') then reward := 2;
  end if;
  if reward > 0 then
    update public.world_characters set mount_tokens = least(9999, mount_tokens + reward), updated_at = now()
     where owner_id = new.actor_id and not is_dead;
  end if;
  return new;
end $function$;
alter function public.world_award_mount_tokens() owner to fn_owner_19205;
grant fn_owner_19205 to postgres with inherit false;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028003000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select mount_id, mount_name, fare_free, fare_tokens from public.world_mount_catalog order by fare_tokens, mount_id;
