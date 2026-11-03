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

update public.world_app_meta set value = '20261105060000' where key = 'db_version';
