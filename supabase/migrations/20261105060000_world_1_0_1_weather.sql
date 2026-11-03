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

do $q$ declare d text; a text; begin
  d := replace(pg_get_functiondef('public.world_quest_step_state(uuid,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$'regions', coalesce(t -> 'r', '[]'::jsonb)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.1 world_quest_step_state 기준 문구가 없습니다'; end if;
  execute replace(d, a, $b$'regions', coalesce(t -> 'r', case when t ->> 't' = 'win' and t ? 'm' then (select jsonb_agg(distinct rm.region_id) from public.world_region_monsters rm where rm.monster_id in (select jsonb_array_elements_text(t -> 'm'))) end, '[]'::jsonb)$b$);
end $q$;

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

