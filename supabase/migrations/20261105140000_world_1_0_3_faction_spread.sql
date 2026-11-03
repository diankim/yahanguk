create or replace function public.world_faction_spread_rules() returns jsonb language sql immutable as $f$
  select jsonb_build_object('steps', jsonb_build_array(jsonb_build_array(0, 100), jsonb_build_array(1, 75), jsonb_build_array(2, 55),
                                                       jsonb_build_array(3, 40), jsonb_build_array(4, 25)))
$f$;
revoke all on function public.world_faction_spread_rules() from public, anon, authenticated;

create or replace function public.world_faction_spread_mult(p_faction text, p_region text) returns numeric
language sql stable set search_path = '' as $f$
  select case when (select home_faction_id from public.world_map_regions where region_id = p_region) = p_faction then 1::numeric
    else (select coalesce((select (s ->> 1)::numeric / 100 from jsonb_array_elements(public.world_faction_spread_rules() -> 'steps') s
                            where (s ->> 0)::int <= x.n order by (s ->> 0)::int desc limit 1), 1)
            from (select count(*) n from public.world_map_regions mr where mr.active and not mr.is_safe_zone and mr.control_faction_id = p_faction
                   and mr.home_faction_id is not null and mr.home_faction_id <> p_faction) x) end
$f$;
revoke all on function public.world_faction_spread_mult(text, text) from public, anon, authenticated;

update public.world_patch_notes set body = body || $pn$

## 1.0.3 · 세력 독식 보정
- 본래 땅 밖을 여러 곳 차지한 세력이 더 넓히기 어렵게 독식 보정을 세게 바꿨습니다. 본래 땅 밖에서 이미 차지한 지역 수에 따라, 본래 땅 밖에 새로 쌓는 영향력이 1곳 75% · 2곳 55% · 3곳 40% · 4곳 이상 25%가 됩니다(전에는 3곳부터 80%·65%·50%). 본래 땅에서 쌓는 영향력은 그대로입니다.
$pn$
where note_id = '1.0.0' and position('## 1.0.3 · 세력 독식 보정' in body) = 0;

update public.world_app_meta set value = '20261105140000' where key = 'db_version';
