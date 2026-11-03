-- 1.0.1 날씨·시간대 공격 갈래 균형: 원거리(월궁 사수)만 영역 평균 −2~−8%로 깎이고 술법은 +2~+5%로 오르던 것을
-- 근접 −0.6~+1.8 · 원거리 −1.6~+1.8 · 술법 +1.1~+3.6(혈무 영역)으로 맞춘다(날씨 확률 world_weather_climate 가중 평균).
-- 농무 원거리 −20→−10 · 장우 원거리 −10→−5 · 담운 술법 +5→+3 · 삼경 술법 +10→+5 · 해돋이·한낮 원거리 +5(밝을 때 활이 잘 보임)
update public.world_environment_catalog set effects = effects || '{"ranged_pct": -10}'::jsonb where env_key = 'fog';
update public.world_environment_catalog set effects = effects || '{"ranged_pct": -5}'::jsonb where env_key = 'rain';
update public.world_environment_catalog set effects = effects || '{"magic_pct": 3}'::jsonb where env_key = 'cloudy';
update public.world_environment_catalog set effects = effects || '{"magic_pct": 5}'::jsonb where env_key = 'night';
update public.world_environment_catalog set effects = effects || '{"ranged_pct": 5}'::jsonb where env_key in ('dawn', 'noon');

do $c$ begin
  if (select count(*) from public.world_environment_catalog where (env_key = 'fog' and (effects->>'ranged_pct')::int = -10)
        or (env_key = 'rain' and (effects->>'ranged_pct')::int = -5) or (env_key = 'cloudy' and (effects->>'magic_pct')::int = 3)
        or (env_key = 'night' and (effects->>'magic_pct')::int = 5) or (env_key in ('dawn','noon') and (effects->>'ranged_pct')::int = 5)) <> 6
  then raise exception '1.0.1 날씨 값이 기대와 다릅니다'; end if;
end $c$;

-- 1.0.1 퀘스트 「요괴 처치」 할 일에 지역(r)을 적지 않은 122개는 화면 지도 단추가 안 생기던 것(제보: 2장 구룡 폐수로):
-- 지역이 없으면 그 요괴가 사는 지역을 regions로 돌려준다(셈 조건은 그대로, 보이는 단추만)
do $q$ declare d text; a text; begin
  d := replace(pg_get_functiondef('public.world_quest_step_state(uuid,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$'regions', coalesce(t -> 'r', '[]'::jsonb)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.1 world_quest_step_state 기준 문구가 없습니다'; end if;
  execute replace(d, a, $b$'regions', coalesce(t -> 'r', case when t ->> 't' = 'win' and t ? 'm' then (select jsonb_agg(distinct rm.region_id) from public.world_region_monsters rm where rm.monster_id in (select jsonb_array_elements_text(t -> 'm'))) end, '[]'::jsonb)$b$);
end $q$;

-- 1.0.1 돌보기(제보: 같은 곳인데 「같은 곳에 있어야」): 동료가 이동을 시작해도 파티 칸 위치는 출발지라 「같은 곳」·돌보기 단추가 남던 것.
-- 파티 정보에 이동 중(traveling: 가는 곳)을 넣고, 서버 거절 문구도 이동 중이면 그렇게 알린다.
-- world_party_overview 주인(fn_owner_social, 함수 주인 역할 — 조사원 권한 아님)이 이동 중 칸 하나만 읽게
grant select (travel_destination) on public.world_characters to fn_owner_social;
do $p$ declare d text; a text; b text; begin
  d := replace(pg_get_functiondef('public.world_party_overview()'::regprocedure), E'\r\n', E'\n');
  a := $a$'downed', c.downed_at IS NOT NULL OR c.health <= 0,$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.1 world_party_overview 기준 문구가 없습니다'; end if;
  execute replace(d, a, $x$'traveling', c.travel_destination, $x$ || a);
  d := replace(pg_get_functiondef('public.world_party_use_item(uuid,text)'::regprocedure), E'\r\n', E'\n');
  b := $a$if coalesce(c.location, '') <> coalesce(t.location, '') or t.travel_destination is not null then raise exception '같은 곳에 있는 동료에게만 쓸 수 있습니다.'; end if;$a$;
  if (length(d) - length(replace(d, b, ''))) / length(b) <> 1 then raise exception '1.0.1 world_party_use_item 기준 문구가 없습니다'; end if;
  execute replace(d, b, $x$if t.travel_destination is not null then raise exception '그 동료는 지금 이동 중입니다. 도착한 뒤에 돌봐 주세요.'; end if;
  if coalesce(c.location, '') <> coalesce(t.location, '') then raise exception '같은 곳에 있는 동료에게만 쓸 수 있습니다.'; end if;$x$);
end $p$;

-- 1.0.1 영력(기력) 회복(제보: 체력보다 소모가 커서 시간이 많이 듦): 안전지대 체류 10분마다 +15, 잠깐 쉬기 12→27·푹 쉬기 35→50
do $s$ declare d text; a text; begin
  d := replace(pg_get_functiondef('public.world_safe_regen()'::regprocedure), E'\r\n', E'\n');
  a := $a$set health = least(100, c.health + 12), mental = least(100, c.mental + 6)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.1 world_safe_regen 기준 문구가 없습니다'; end if;
  d := replace(d, a, a || $x$, spiritual_power = least(100, c.spiritual_power + 15)$x$);
  a := $a$and (c.health < 100 or c.mental < 100)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.1 world_safe_regen 조건 문구가 없습니다'; end if;
  execute replace(d, a, $x$and (c.health < 100 or c.mental < 100 or c.spiritual_power < 100)$x$);
  d := replace(pg_get_functiondef('public.world_field_rest(text)'::regprocedure), E'\r\n', E'\n');
  a := $a$sp := CASE WHEN is_full THEN 35 ELSE 12 END;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.1 world_field_rest 기준 문구가 없습니다'; end if;
  execute replace(d, a, $x$sp := CASE WHEN is_full THEN 50 ELSE 27 END;$x$);
end $s$;

update public.world_app_meta set value = '20261105060000' where key = 'db_version';
