create or replace function public.world_faction_spread_rules() returns jsonb language sql immutable as $f$
  select jsonb_build_object('steps', jsonb_build_array(jsonb_build_array(0, 100), jsonb_build_array(1, 75), jsonb_build_array(2, 55),
                                                       jsonb_build_array(3, 40), jsonb_build_array(4, 25)),
    'boost_max', 2.5, 'home_pct', 150, 'person_cap', 60, 'region_cap', 40)
$f$;

create or replace function public.world_faction_boost(p text) returns numeric
language sql stable set search_path to 'pg_catalog', 'public' as $f$
  with t as (select f.faction_id, coalesce((select sum(i.points) from public.world_region_influence i where i.faction_id = f.faction_id), 0) pts
               from public.world_major_factions f where f.active)
  select coalesce((select round(least((public.world_faction_spread_rules() ->> 'boost_max')::numeric,
                     greatest(1, sqrt((select max(pts) from t) / greatest(t.pts, 1)))), 2) from t where t.faction_id = p), 1)
$f$;

create or replace function public.world_faction_spread_mult(p_faction text, p_region text) returns numeric
language sql stable set search_path to '' as $f$
  select case when (select home_faction_id from public.world_map_regions where region_id = p_region) = p_faction
              then (public.world_faction_spread_rules() ->> 'home_pct')::numeric / 100
    else (select coalesce((select (s ->> 1)::numeric / 100 from jsonb_array_elements(public.world_faction_spread_rules() -> 'steps') s
                            where (s ->> 0)::int <= x.n order by (s ->> 0)::int desc limit 1), 1)
            from (select count(*) n from public.world_map_regions mr
                   where mr.active and not mr.is_safe_zone and mr.home_faction_id is not null and mr.home_faction_id <> p_faction
                     and (mr.control_faction_id = p_faction
                          or (mr.contested and mr.control_faction_id is distinct from p_faction
                              and p_faction = (select f.faction_id from public.world_major_factions f
                                                 left join public.world_region_influence i on i.region_id = mr.region_id and i.faction_id = f.faction_id
                                                where f.active and f.faction_id is distinct from mr.control_faction_id
                                                order by coalesce(i.points, 0) + case when f.faction_id = mr.home_faction_id then 150 else 0 end desc limit 1)))) x) end
$f$;

do $w$
declare d text; a text; b text;
begin
  d := replace(pg_get_functiondef('public.world_influence_tick()'::regprocedure), E'\r\n', E'\n');
  if position('person_cap' in d) > 0 then return; end if;
  a := $a$group by 1, 2, 3 having sum(pts) > 0),
  agg as (select f, region_id, sum(pts) pts, (array_agg(actor_id order by pts desc))[1] top from per group by 1, 2)$a$;
  b := $b$group by 1, 2, 3 having sum(pts) > 0),
  per2 as (select f, region_id, actor_id, pts * least(1, (public.world_faction_spread_rules() ->> 'person_cap')::numeric / sum(pts) over (partition by actor_id)) pts from per),
  agg as (select f, region_id, sum(pts) pts, (array_agg(actor_id order by pts desc))[1] top from per2 group by 1, 2)$b$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.4e world_influence_tick 기준 문구가 없습니다'; end if;
  d := replace(d, a, b);
  a := 'least(40, sum(pts))';
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.4e world_influence_tick 지역 상한 문구가 없습니다'; end if;
  execute replace(d, a, $c$least((public.world_faction_spread_rules() ->> 'region_cap')::numeric, sum(pts))$c$);
end $w$;

update public.world_patch_notes set body = replace(body,
  $o$본래 땅에서 쌓는 영향력은 그대로입니다.
$o$,
  $n$본래 땅에서 쌓는 영향력에는 독식 보정이 걸리지 않습니다.
- 독식 보정에 남의 땅에서 1위로 분쟁 중인 곳도 함께 셉니다(차지한 곳 + 앞서 있는 곳).
- 인원 보정을 「약세 보정」으로 바꿨습니다. 가입 인원이 아니라 세력마다 지금 쌓여 있는 영향력 합으로 정하며, 가장 많이 쌓은 세력과의 차이에 따라 √(그 세력 합 ÷ 우리 합)배(1~2.5배)가 붙습니다. 가장 앞선 세력은 보정이 없습니다.
- 본래 주인 세력이 자기 본래 땅에서 쌓는 영향력은 ×1.5입니다.
- 한 사람이 한 번 정산(한 시간)에 쌓는 영향력은 지역마다 40, 모든 지역을 합쳐 60까지입니다.
$n$)
where note_id = '1.0.0' and position('약세 보정' in body) = 0;

update public.world_app_meta set value = '20261105234000' where key = 'db_version';
