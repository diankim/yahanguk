-- 7.5.9c — 지도에 「답사 완료」 표시(사용자 요청): 길·채집터를 모두 찾은 바깥 지역 목록을 그 조사원에게만 돌려준다.
-- world_survey_full_count와 같은 기준(답사 지점 hierarchy_level ≥ 2 + 쓰는 채집터, 안전지대 제외).
create or replace function public.world_survey_full_regions()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := auth.uid();
begin
  if uid is null then return '[]'::jsonb; end if;
  return coalesce((with dr as materialized (
           select x.region_id from public.world_exploration_discoveries d join public.world_exploration_nodes x on x.node_id = d.node_id where d.owner_id = uid
           union select y.region_id from public.world_gathering_discoveries d join public.world_gathering_spots g on g.spot_id = d.spot_id join public.world_exploration_nodes y on y.node_id = g.node_id where d.owner_id = uid),
       n as (select x.region_id, count(*) t, count(d.node_id) f from public.world_exploration_nodes x
               left join public.world_exploration_discoveries d on d.node_id = x.node_id and d.owner_id = uid
              where x.hierarchy_level >= 2 and x.region_id in (select region_id from dr) group by 1),
       s as (select y.region_id, count(*) t, count(d.spot_id) f from public.world_gathering_spots x
               join public.world_exploration_nodes y on y.node_id = x.node_id
               left join public.world_gathering_discoveries d on d.spot_id = x.spot_id and d.owner_id = uid
              where x.active and y.region_id in (select region_id from dr) group by 1)
  select jsonb_agg(r.region_id order by r.region_id) from public.world_map_regions r
    left join n on n.region_id = r.region_id left join s on s.region_id = r.region_id
   where r.active and not coalesce(r.is_safe_zone, false) and r.region_id in (select region_id from dr)
     and coalesce(n.t, 0) + coalesce(s.t, 0) > 0
     and coalesce(n.f, 0) + coalesce(s.f, 0) >= coalesce(n.t, 0) + coalesce(s.t, 0)), '[]'::jsonb);
end $function$;
revoke all on function public.world_survey_full_regions() from public, anon, authenticated;
grant execute on function public.world_survey_full_regions() to authenticated;

update public.world_patch_notes set body = rtrim(body, E'\n') || $N$
- **지도**: 길과 채집터를 모두 찾은(완전 답사한) 지역은 점 바로 바깥에 금빛 테가 한 겹 더 둘립니다. 나에게만 보이는 표시입니다.
$N$
 where note_id = '7.5.0' and position('완전 답사한) 지역은 점' in body) = 0;

update public.world_app_meta set value = '20261104100000' where key = 'db_version';
