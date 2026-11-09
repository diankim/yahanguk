lock table public.world_characters in access exclusive mode;

alter table public.world_fish_species add column if not exists bait_for text[] not null default '{}';

create or replace function public.world_domain_rules()
 returns jsonb language sql immutable
as $f$ select '{"gwiheo": {"name": "귀허도", "open_chapter": "nine_gates", "acclimate": true, "no_shadow": true, "rare": "banyo_scale"}}'::jsonb $f$;

create or replace function public.world_domain_flag(p_territory text, p_key text)
 returns boolean language sql immutable
as $f$ select coalesce((public.world_domain_rules() -> p_territory ->> p_key)::boolean, false) $f$;

create or replace function public.world_domain_rare(p_region text)
 returns text language sql stable set search_path to 'pg_catalog', 'public'
as $f$ select public.world_domain_rules() -> r.territory_id ->> 'rare' from public.world_map_regions r where r.region_id = p_region and not coalesce(r.is_safe_zone, false) $f$;

create or replace function public.world_domain_open(p_uid uuid, p_territory text)
 returns boolean language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare d jsonb := public.world_domain_rules() -> p_territory;
begin
  if d is null then return true; end if;
  if p_uid is null then return false; end if;
  if exists (select 1 from public.world_staff s where s.owner_id = p_uid) then return true; end if;
  if d ? 'open_chapter' and not public.world_quest_chapter_done(p_uid, d ->> 'open_chapter') then return false; end if;
  if d ? 'open_quest' and not ((d ->> 'open_quest') = any (public.world_quest_done_ids(p_uid))) then return false; end if;
  return true;
end $f$;

create or replace function public.world_domain_shut()
 returns text[] language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  return coalesce((select array_agg(t) from jsonb_object_keys(public.world_domain_rules()) t where not public.world_domain_open(uid, t)), '{}');
end $f$;

create or replace function public.world_weak_safe_rules()
 returns jsonb language sql immutable
as $f$ select '["banyo_village"]'::jsonb $f$;

create or replace function public.world_weak_safe(p_region text)
 returns boolean language sql immutable
as $f$ select coalesce(public.world_weak_safe_rules() ? p_region, false) $f$;

create or replace function public.world_fish_rules()
 returns jsonb language sql immutable
as $f$ select '{"weight": {"common": 60, "uncommon": 25, "rare": 9, "epic": 3, "legendary": 0.6}, "boosted": ["rare", "epic", "legendary"], "match": 3, "miss": 0.3, "miss_skill": 0.6}'::jsonb $f$;

do $g$
declare f text; r record; owner_set boolean;
begin
  foreach f in array array['public.world_domain_rules()', 'public.world_domain_flag(text, text)', 'public.world_domain_rare(text)',
    'public.world_domain_open(uuid, text)', 'public.world_domain_shut()', 'public.world_weak_safe_rules()', 'public.world_weak_safe(text)', 'public.world_fish_rules()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    for r in select distinct a.grantee::regrole::text g from pg_proc p, aclexplode(p.proacl) a
              where p.oid = 'public.world_gwiheo_open(uuid)'::regprocedure and a.grantee <> 0 and a.grantee::regrole::text not in ('authenticated', 'postgres') loop
      execute format('grant execute on function %s to %s', f, r.g);
    end loop;
  end loop;
  grant execute on function public.world_domain_shut() to authenticated;
  owner_set := has_schema_privilege('fn_owner_field', 'public', 'CREATE');
  if not owner_set then grant create on schema public to fn_owner_field; end if;
  alter function public.world_domain_open(uuid, text) owner to fn_owner_field;
  alter function public.world_domain_shut() owner to fn_owner_field;
  if not owner_set then revoke create on schema public from fn_owner_field; end if;
end $g$;


create or replace function pg_temp.yh_fix(p_name text, p_pairs text[], p_n int) returns void language plpgsql as $f$
declare d text; i int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> p_n then raise exception '함수 % 모양이 예상과 다릅니다', p_name; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_gwiheo_open', array[$q$select p_uid is not null and (public.world_quest_chapter_done(p_uid, 'nine_gates') or exists (select 1 from public.world_staff s where s.owner_id = p_uid))$q$, $q$select p_uid is not null and public.world_domain_open(p_uid, 'gwiheo')$q$], 1);

select pg_temp.yh_fix('world_on_island', array[$q$(public.world_region_at(c.location)).territory_id = 'gwiheo'$q$, $q$public.world_domain_flag((public.world_region_at(c.location)).territory_id, 'acclimate')$q$], 1);

select pg_temp.yh_fix('world_erosion_effect', array[$q$coalesce((public.world_region_at(loc)).territory_id = 'gwiheo', false)$q$, $q$public.world_domain_flag((public.world_region_at(loc)).territory_id, 'acclimate')$q$], 1);

select pg_temp.yh_fix('world_banyo_here', array[$q$(public.world_region_at(c.location)).region_id = 'banyo_village'$q$, $q$public.world_weak_safe((public.world_region_at(c.location)).region_id)$q$], 1);

select pg_temp.yh_fix('world_guard_action_context', array[$q$r.region_id = 'banyo_village'$q$, $q$public.world_weak_safe(r.region_id)$q$], 1);

select pg_temp.yh_fix('world_tourney_ensure', array[$q$region_id <> 'banyo_village'$q$, $q$not public.world_weak_safe(region_id)$q$], 1);

select pg_temp.yh_fix('world_ucomm_board', array[$q$r.region_id <> 'banyo_village'$q$, $q$not public.world_weak_safe(r.region_id)$q$], 1);

select pg_temp.yh_fix('world_travel_route', array[$q$(dest.territory_id = 'gwiheo' AND NOT public.world_gwiheo_open(uid))$q$, $q$NOT public.world_domain_open(uid, dest.territory_id)$q$], 1);

select pg_temp.yh_fix('world_travel_party_invite_v2', array[$q$r.territory_id = 'gwiheo' AND NOT (public.world_gwiheo_open(uid) AND public.world_gwiheo_open(p_passenger_id))$q$, $q$NOT (public.world_domain_open(uid, r.territory_id) AND public.world_domain_open(p_passenger_id, r.territory_id))$q$], 1);

select pg_temp.yh_fix('world_travel_party_respond_v2', array[$q$r.territory_id='gwiheo' and not (public.world_gwiheo_open(q.leader_id) and public.world_gwiheo_open(uid))$q$, $q$not (public.world_domain_open(q.leader_id, r.territory_id) and public.world_domain_open(uid, r.territory_id))$q$], 1);

select pg_temp.yh_fix('world_raid_schedule_next', array[$q$territory_id is distinct from 'gwiheo'$q$, $q$not public.world_domain_flag(territory_id, 'no_shadow')$q$], 2);

select pg_temp.yh_fix('world_event_char_apply', array[$q$when p ->> 'region_id' in ('ash_reeds', 'inverted_shrine', 'moonless_market', 'gwiheo_core') then 'banyo_scale'$q$, $q$when public.world_domain_rare(p ->> 'region_id') is not null then public.world_domain_rare(p ->> 'region_id')$q$], 1);

select pg_temp.yh_fix('world_map_snapshot', array[$q$gw boolean;$q$, $q$shut text[]; hide text[];$q$, $q$ gw := public.world_gwiheo_open(uid);
$q$, $q$ shut := public.world_domain_shut();
 hide := coalesce((select array_agg(x.region_id) from public.world_map_regions x where x.territory_id = any(shut)), '{}');
$q$, $q$case when gw then r.travel_from else array(select x from unnest(r.travel_from) x where x not in ('banyo_village','ash_reeds','inverted_shrine','moonless_market','gwiheo_core')) end$q$, $q$case when cardinality(hide) = 0 then r.travel_from else array(select x from unnest(r.travel_from) x where x <> all(hide)) end$q$, $q$(r.territory_id is distinct from 'gwiheo' or gw)$q$, $q$not (coalesce(r.territory_id, '') = any(shut))$q$], 1);

select pg_temp.yh_fix('world_fish', array[$q$(case s.rarity when 'common' then 60 when 'uncommon' then 25 when 'rare' then 9 * (1 + boost / 100.0) when 'epic' then 3 * (1 + boost / 100.0) else 0.6 * (1 + boost / 100.0) end)$q$, $q$(coalesce((public.world_fish_rules() -> 'weight' ->> s.rarity)::numeric, (public.world_fish_rules() -> 'weight' ->> 'legendary')::numeric) * case when (public.world_fish_rules() -> 'boosted') ? s.rarity then 1 + boost / 100.0 else 1 end)$q$, $q$(case when s.phase is null then 1 when s.phase = ph then 3 when 'fishing_x30' = any (sk) then 0.6 else 0.3 end)$q$, $q$(case when s.phase is null then 1 when s.phase = ph then (public.world_fish_rules() ->> 'match')::numeric when 'fishing_x30' = any (sk) then (public.world_fish_rules() ->> 'miss_skill')::numeric else (public.world_fish_rules() ->> 'miss')::numeric end)$q$, $q$(case when s.weather is null then 1 when s.weather = wk then 3 when 'fishing_x30' = any (sk) then 0.6 else 0.3 end)$q$, $q$(case when s.weather is null then 1 when s.weather = wk then (public.world_fish_rules() ->> 'match')::numeric when 'fishing_x30' = any (sk) then (public.world_fish_rules() ->> 'miss_skill')::numeric else (public.world_fish_rules() ->> 'miss')::numeric end)$q$], 1);


update public.world_patch_notes set body = body || E'\n- 서버 안쪽 정리: 영역 열림·빈약한 안전지대·낚시 희귀도 무게를 규칙 한 곳에서 읽게 했습니다(바뀌는 수치 없음).'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109060000' where key = 'db_version';
