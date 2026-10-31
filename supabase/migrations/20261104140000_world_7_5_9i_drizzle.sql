-- 7.5.9i — 날씨 「세우(細雨)」(drizzle, 사용자 요청): 장우보다 가늘고 고운 비. 채집 +6%·회복 +5%·침식 −5%·단서 +4%·원거리 −5%,
-- 낚시 입질 +5%p(비·안개·흐림과 같음). 영역마다 날씨 무게를 장우·청명에서 덜어 넣는다(땅 밑·심연에는 없음).
-- 날씨는 영역·12시간 칸마다 무게 누계로 정하므로, 배포한 그 칸의 날씨가 바뀔 수 있다.
insert into public.world_environment_catalog(kind, sort, effects, env_key, env_name, description)
select 'weather', 18, '{"healing_pct":5,"gather_qty_pct":6,"erosion_pct":-5,"clue_bonus_pct":4,"ranged_pct":-5}'::jsonb, 'drizzle', '세우',
       '가랑비가 보슬보슬 내린다. 풀잎이 촉촉해 채집이 잘되고 마음이 가라앉아 침식이 덜하지만, 활시위가 조금 눅눅하다.'
 where not exists (select 1 from public.world_environment_catalog where env_key = 'drizzle');

update public.world_weather_climate c set weights = c.weights || v.w
  from (values
    ('capital',    '{"rain":10,"drizzle":10,"clear":25}'::jsonb),
    ('north',      '{"drizzle":4,"clear":16}'::jsonb),
    ('east',       '{"rain":20,"drizzle":12,"clear":16}'::jsonb),
    ('south',      '{"rain":16,"drizzle":12,"clear":19}'::jsonb),
    ('frontier',   '{"rain":8,"drizzle":6,"clear":18}'::jsonb),
    ('heavenward', '{"rain":6,"drizzle":8,"clear":34}'::jsonb)
  ) v(t, w)
 where c.territory_id = v.t and not (c.weights ? 'drizzle');

do $p$
declare r record; d text; own text; inh boolean;
begin
  for r in select * from (values
      ('public.world_expedition_walk_lines', $a$when 'rain' then '장우'$a$, $b$when 'rain' then '장우' when 'drizzle' then '세우'$b$),
      ('public.world_expedition_walk_lines', $a$p_env := case wk when 'rain' then$a$, $b$p_env := case wk when 'drizzle' then array['가는 빗방울이 잎을 또도독 두드려 발소리가 잘 묻힙니다.', '세우에 흙내가 올라와 숨이 한결 편합니다.'] when 'rain' then$b$),
      ('public.world_fish', $a$wk in ('rain', 'fog', 'cloudy')$a$, $b$wk in ('rain', 'drizzle', 'fog', 'cloudy')$b$)
    ) x(fn, a, b)
  loop
    select p.oid::regprocedure::text into d from pg_proc p where p.oid = (select min(oid) from pg_proc where oid::regprocedure::text like substr(r.fn, 8) || '(%' and pronamespace = 'public'::regnamespace);
    d := replace(pg_get_functiondef(d::regprocedure), E'\r\n', E'\n');
    if position('drizzle' in d) > 0 and position(r.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, replace(r.a, E'\r\n', E'\n'), ''))) / length(r.a) <> 1 then raise exception '7.5.9i anchor % in %', r.a, r.fn; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = (select min(oid) from pg_proc where oid::regprocedure::text like substr(r.fn, 8) || '(%' and pronamespace = 'public'::regnamespace);
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

update public.world_app_meta set value = '20261104140000' where key = 'db_version';
