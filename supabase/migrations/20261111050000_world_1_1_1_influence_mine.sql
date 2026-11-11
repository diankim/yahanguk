create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function public.world_influence_pts(p_type text, p_payload jsonb)
 returns numeric
 language sql
 immutable
as $function$
  select case p_type when 'combat' then case when (p_payload ->> 'defeated')::boolean then case p_payload ->> 'rank' when 'boss' then 4 when 'elite' then 2 else 1 end else 0 end
    else 0.3 + least(3, coalesce((p_payload ->> 'infl')::numeric, 0)) end
$function$;
revoke all on function public.world_influence_pts(text, jsonb) from public, anon, authenticated;
grant execute on function public.world_influence_pts(text, jsonb) to fn_owner_field;

select pg_temp.yh_fix('world_influence_tick', array[
  E'case e.event_type when ''combat'' then case when (e.payload ->> ''defeated'')::boolean then case e.payload ->> ''rank'' when ''boss'' then 4 when ''elite'' then 2 else 1 end else 0 end\n                        else 0.3 + least(3, coalesce((e.payload ->> ''infl'')::numeric, 0)) end pts',
  'public.world_influence_pts(e.event_type, e.payload) pts']);

create or replace function public.world_influence_mine(p_uid uuid, p_region text, p_faction text)
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare t0 timestamptz; rr jsonb := public.world_faction_spread_rules(); cap numeric := (rr ->> 'region_cap')::numeric; pcap numeric := (rr ->> 'person_cap')::numeric; here numeric; total numeric;
begin
  if p_uid is null or p_faction is null or not exists (select 1 from public.world_map_regions mr where mr.region_id = p_region and mr.active and not mr.is_safe_zone and mr.home_faction_id is not null) then
    return null;
  end if;
  select value::timestamptz into t0 from public.world_app_meta where key = 'influence_at';
  t0 := greatest(coalesce(t0, now() - interval '1 hour'), now() - interval '3 hours');
  with ev as (
    select coalesce(e.payload ->> 'region_id', n.region_id) region_id, public.world_influence_pts(e.event_type, e.payload) pts
    from public.world_events e left join public.world_exploration_nodes n on e.event_type = 'gather' and n.node_id::text = e.payload ->> 'node_id'
    where e.actor_id = p_uid and e.event_type in ('combat', 'explore', 'gather') and e.created_at > t0
    union all
    select x.region_id, least(24, least(x.minutes, extract(epoch from x.finished_at - x.started_at) / 60) / 20.0) from public.world_expeditions x
    where x.owner_id = p_uid and x.status = 'done' and x.finished_at > t0),
  per as (select ev.region_id, sum(ev.pts) pts from ev join public.world_map_regions mr on mr.region_id = ev.region_id
          where mr.active and not mr.is_safe_zone and mr.home_faction_id is not null group by 1)
  select coalesce(max(least(cap, pts)) filter (where region_id = p_region), 0), coalesce(sum(least(cap, pts)), 0) into here, total from per;
  return jsonb_build_object('n', round(here, 1), 'cap', cap, 'all', round(total, 1), 'all_cap', pcap,
    'next_at', date_trunc('hour', now() - interval '7 minutes') + interval '1 hour 7 minutes');
end $function$;
revoke all on function public.world_influence_mine(uuid, text, text) from public, anon, authenticated;
grant execute on function public.world_influence_mine(uuid, text, text) to fn_owner_field;

select pg_temp.yh_fix('world_field_snapshot', array[
  E'    ''recent'', (SELECT coalesce(jsonb_agg(jsonb_build_object(''content'', e.content',
  E'    ''infl'', public.world_influence_mine(uid, r.region_id, c.major_faction_id),\n    ''recent'', (SELECT coalesce(jsonb_agg(jsonb_build_object(''content'', e.content']);

update public.world_patch_notes set body = body || E'\n- 현장 머리의 세력 줄에 「이번 정산 몫 n/40」을 보입니다. 한 사람이 한 시간 정산에 한 지역에 쌓을 수 있는 영향력 몫이 얼마나 찼는지와 다음 정산 시각이 나옵니다(모든 지역 합 60까지).'
where note_id = '1.1.0' and position('이번 정산 몫 n/40' in body) = 0;

update public.world_app_meta set value = '20261111050000' where key = 'db_version';
