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


CREATE OR REPLACE FUNCTION public.world_gwiheo_open(p_uid uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
#variable_conflict use_column
begin
  return (select * from (select p_uid is not null and public.world_domain_open(p_uid, 'gwiheo')
) yhq limit 1);
end
$function$;

CREATE OR REPLACE FUNCTION public.world_on_island(p_uid uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
#variable_conflict use_column
begin
  return (select * from (select coalesce((select public.world_domain_flag((public.world_region_at(c.location)).territory_id, 'acclimate') from public.world_characters c where c.owner_id = p_uid), false)
) yhq limit 1);
end
$function$;

CREATE OR REPLACE FUNCTION public.world_erosion_effect(p_effect_key text)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
#variable_conflict use_column
begin
  -- 섬 판정은 침식 30 이상일 때만 한다(효과 합계가 키마다 불러서 가볍게)
  return (select * from (select coalesce((select case p_effect_key
        when 'healing_pct' then case when e >= 80 then case when isl then -18 else -35 end when e >= 55 then case when isl then -12 else -25 end when e >= 30 then case when isl then -8 else -15 end else 0 end
        when 'incoming_damage_pct' then case when e >= 80 then case when isl then 10 else 20 end when e >= 55 then case when isl then 5 else 10 end else 0 end
        when 'combat_damage_pct' then case when e >= 80 then case when isl then 8 else -10 end when e >= 55 and isl then 4 else 0 end
        when 'encounter_pct' then case when e >= 80 then case when isl then 10 else 20 end else 0 end
        when 'rare_loot_pct' then case when e >= 80 then 15 when e >= 55 then 10 when e >= 30 then 5 else 0 end
        when 'clue_bonus_pct' then case when e >= 80 then 15 when e >= 55 then 10 when e >= 30 then 5 else 0 end
        else 0 end
      from (select e, e >= 30 and public.world_domain_flag((public.world_region_at(loc)).territory_id, 'acclimate') as isl
            from (select coalesce(erosion, 0) as e, location as loc from public.world_characters where owner_id = public.fn_owner_auth_uid()) y) x), 0)::numeric
) yhq limit 1);
end
$function$;

CREATE OR REPLACE FUNCTION public.world_banyo_here(p_uid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  select coalesce((select public.world_weak_safe((public.world_region_at(c.location)).region_id) from public.world_characters c where c.owner_id = p_uid), false)
$function$;

CREATE OR REPLACE FUNCTION public.world_guard_action_context()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  c public.world_characters%rowtype; r public.world_map_regions%rowtype; m public.world_mount_catalog%rowtype;
  k text := coalesce(new.event_type, ''); p jsonb := coalesce(new.payload, '{}'::jsonb);
  away boolean; passenger uuid; idling boolean; cd_s text;
BEGIN
  IF new.actor_id IS NULL THEN RETURN new; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = new.actor_id;
  IF NOT FOUND THEN RETURN new; END IF;
  r := public.world_region_at(c.location);
  away := EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = new.actor_id AND e.status = 'active');
        idling := EXISTS (SELECT 1 FROM public.world_idle_activities i WHERE i.owner_id = new.actor_id AND i.status = 'active');
  IF k = 'travel' AND p ? 'passenger_id' THEN
    passenger := nullif(p ->> 'passenger_id', '')::uuid;
    IF EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = passenger AND e.status = 'active') THEN
      RAISE EXCEPTION '동승자가 원정 중이라 함께 출발할 수 없습니다.';
    END IF;
  END IF;
  IF k = 'travel' AND p ? 'passenger_id'
        AND EXISTS (SELECT 1 FROM public.world_idle_activities i WHERE i.owner_id = nullif(p ->> 'passenger_id', '')::uuid AND i.status = 'active') THEN
        RAISE EXCEPTION '동승자가 자율 활동 중이라 함께 출발할 수 없습니다.';
        END IF;
        IF idling AND NOT (
        k IN ('progression', 'mission', 'supply', 'case_combine', 'case_resolved', 'story', 'loot', 'use_item', 'equip', 'unequip')
        OR (k = 'trade' AND NOT (p ? 'unit_price') AND NOT (p ? 'gil'))
        OR (k = 'travel' AND p ? 'travel_history_id')) THEN
        RAISE EXCEPTION '자율 활동 중에는 할 수 없습니다. 활동이 끝나 보상을 받은 뒤 다시 시도하세요.';
        END IF;
        IF away AND NOT (
       k IN ('progression', 'mission', 'supply', 'case_combine', 'case_resolved', 'loot', 'downed')
    OR k LIKE 'expedition%'
    OR (k = 'trade' AND NOT (p ? 'unit_price') AND NOT (p ? 'gil'))
    OR (k = 'travel' AND p ? 'travel_history_id')) THEN
    RAISE EXCEPTION '원정 중에는 할 수 없습니다. 원정을 마치거나 귀환한 뒤 다시 시도하세요.';
  END IF;
  IF (k IN ('explore', 'gather', 'fish', 'combat', 'encounter', 'expedition_start') OR (k = 'travel' AND NOT (p ? 'travel_history_id')))
     AND EXISTS (SELECT 1 FROM public.world_overflow_items o WHERE o.owner_id = new.actor_id) THEN
    RAISE EXCEPTION '원정 짐 보따리를 먼저 정리하세요. 챙기거나 버린 뒤 다시 할 수 있습니다.';
  END IF;
  IF k <> 'progression' AND EXISTS (SELECT 1 FROM public.world_character_statuses ys WHERE ys.owner_id = new.actor_id AND ys.status_key = 'yohwa_seal' AND ys.expires_at > now()) THEN
        RAISE EXCEPTION '봉인 해독 중에는 채팅 말고는 할 수 없습니다. 해독이 끝나면 다시 움직일 수 있습니다.';
        END IF;
        IF k = 'travel' AND NOT (p ? 'travel_history_id') THEN
    PERFORM 1 FROM public.world_travel_history h WHERE h.owner_id = new.actor_id AND h.cancelled_at > now() - interval '3 minutes';
    IF FOUND THEN
      cd_s := ceil(extract(epoch FROM (SELECT max(h.cancelled_at) FROM public.world_travel_history h WHERE h.owner_id = new.actor_id) + interval '3 minutes' - now()))::text;
      RAISE EXCEPTION USING MESSAGE = format('이동을 취소한 뒤 3분 동안은 다시 출발할 수 없습니다(%s초 남음).', cd_s), HINT = 'cd:' || cd_s;
    END IF;
  END IF;
  -- 이동 중에는 제작·분해·강화·수리·상점·거래소를 할 수 없다(7.3.6)
  IF (k IN ('craft', 'dismantle', 'enhance', 'repair', 'shop_buy', 'shop_sell') OR (k = 'trade' AND (p ? 'unit_price' OR p ? 'gil')))
     AND EXISTS (SELECT 1 FROM public.world_characters wc WHERE wc.owner_id = new.actor_id AND wc.travel_arrives_at IS NOT NULL) THEN
    RAISE EXCEPTION '이동 중에는 할 수 없습니다. 도착한 뒤 다시 시도하세요.';
  END IF;
  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN ('encounter', 'combat') THEN
    RAISE EXCEPTION '안전지대에서는 요괴 수색과 전투를 할 수 없습니다.';
  END IF;
  IF k IN ('shop_buy', 'shop_sell') AND (r.region_id IS NULL OR NOT r.is_safe_zone OR r.shop_id IS NULL) THEN
    RAISE EXCEPTION '상점은 안전지대에만 있습니다.';
  END IF;
  IF k = 'trade' AND p ? 'unit_price' AND public.world_weak_safe(r.region_id) THEN
    RAISE EXCEPTION '반요촌에는 거래소가 없습니다.';
  END IF;
  IF k = 'trade' AND (p ? 'unit_price' OR (p ? 'gil' AND NOT (p ? 'trade_id'))) AND (r.region_id IS NULL OR NOT r.is_safe_zone) THEN
    RAISE EXCEPTION '거래소는 안전지대에서만 이용할 수 있습니다.';
  END IF;
  IF k = 'mount' AND p ? 'price' THEN
    SELECT * INTO m FROM public.world_mount_catalog WHERE mount_id = p ->> 'mount_id';
    IF m.acquire_method = 'event' THEN RAISE EXCEPTION '이 탈것은 특별한 사건으로만 얻을 수 있습니다.'; END IF;
    IF r.region_id IS NULL OR NOT r.has_stable THEN RAISE EXCEPTION '탈것은 안전지대의 마구간에서만 구할 수 있습니다.'; END IF;
  END IF;
  RETURN new;
END
$function$;

CREATE OR REPLACE FUNCTION public.world_tourney_ensure()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare mon date := date_trunc('week', now() at time zone 'Asia/Seoul')::date; v text;
begin
  select region_id into v from (select region_id, row_number() over (order by region_id) - 1 k, count(*) over () n
      from public.world_map_regions where is_safe_zone and active and not public.world_weak_safe(region_id)) x
   where k = (extract(week from mon)::int % n);
  insert into public.world_tourneys(week, mode, venue_region, signup_ends, starts_at)
  values (mon, 'solo', v, ((mon + 5)::timestamp) at time zone 'Asia/Seoul', ((mon + 5)::timestamp + interval '21 hours') at time zone 'Asia/Seoul'),
         (mon, 'team', v, ((mon + 5)::timestamp) at time zone 'Asia/Seoul', ((mon + 6)::timestamp + interval '21 hours') at time zone 'Asia/Seoul')
  on conflict (week, mode) do nothing;
end $function$;

CREATE OR REPLACE FUNCTION public.world_ucomm_board()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; xp_used int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  update public.world_user_commissions set status = 'expired' where status = 'open' and expires_at <= now();
  r := public.world_field_region(c.location);
  select count(*) into xp_used from public.world_events e where e.actor_id = uid and e.event_type = 'commission' and e.payload ? 'ucomm'
    and e.created_at >= (today::timestamp at time zone 'Asia/Seoul');
  return jsonb_build_object(
    'fee_pct', 10, 'xp_left', greatest(0, 3 - xp_used), 'xp', 20 + c.level * 3, 'max_open', 5,
    'here', jsonb_build_object('safe', coalesce(r.is_safe_zone, false) and not public.world_weak_safe(r.region_id), 'region', r.region_name,
      'faction', (select mf.faction_name from public.world_major_factions mf where mf.faction_id = coalesce(r.control_faction_id, r.home_faction_id))),
    'open', (select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'owner', u.owner_name, 'item', u.item_id, 'qty', u.qty, 'reward', u.reward,
        'region', (select region_name from public.world_map_regions where region_id = u.region_id), 'faction', (select mf.faction_name from public.world_major_factions mf where mf.faction_id = u.fee_faction),
        'expires_at', u.expires_at,
        'have', coalesce((c.inventory ->> u.item_id)::int, 0) + coalesce((c.inventory ->> (u.item_id || '_hq'))::int, 0)) order by u.created_at desc), '[]'::jsonb)
      from public.world_user_commissions u
      where u.status = 'open' and u.owner_id <> uid
        and not exists (select 1 from public.world_blocks b where (b.owner_id = uid and b.blocked_id = u.owner_id) or (b.owner_id = u.owner_id and b.blocked_id = uid))),
    'mine', (select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'item', u.item_id, 'qty', u.qty, 'reward', u.reward, 'status', u.status,
        'region', (select region_name from public.world_map_regions where region_id = u.region_id), 'faction', (select mf.faction_name from public.world_major_factions mf where mf.faction_id = u.fee_faction),
        'fulfiller', u.fulfiller_name, 'delivered', u.delivered, 'expires_at', u.expires_at, 'done_at', u.done_at, 'settled', u.settled_at is not null) order by u.created_at desc), '[]'::jsonb)
      from public.world_user_commissions u
      where u.owner_id = uid and (u.settled_at is null or u.settled_at > now() - interval '3 days')));
end $function$;

CREATE OR REPLACE FUNCTION public.world_travel_route(p_region_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; here public.world_map_regions%rowtype; dest public.world_map_regions%rowtype;
  ids text[]; xs float8[]; ys float8[]; el float8[]; tc float8[]; terr text[]; lv int[]; lk jsonb[]; d float8[]; prv int[]; done boolean[];
  nn int; i int; u int; v int; best float8; si int; ti int; w float8; speed float8 := 1; path int[] := '{}'; secs float8 := 0; hop float8;
  vis int; fare_per int; fare int := 0; walked boolean := false; arrives timestamptz; fee int; names text[] := '{}'; nb text; sk text[]; n_free int := 0;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태에서는 움직일 수 없습니다.'; END IF;
  IF c.travel_arrives_at IS NOT NULL AND c.travel_arrives_at > now() THEN RAISE EXCEPTION '이미 이동 중입니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = uid AND NOT a.defeated AND NOT coalesce(a.fled, false)) THEN
    RAISE EXCEPTION '전투 중에는 이동할 수 없습니다. 도주하거나 전투를 마치세요.'; END IF;
  here := public.world_field_region(c.location);
  SELECT * INTO dest FROM public.world_map_regions WHERE region_id = p_region_id AND active;
  IF dest.region_id IS NULL OR NOT public.world_domain_open(uid, dest.territory_id) THEN RAISE EXCEPTION '지도에 없는 지역입니다.'; END IF;
  IF here.region_id IS NULL THEN RAISE EXCEPTION '지금 있는 곳의 좌표를 알 수 없습니다.'; END IF;
  IF here.region_id = dest.region_id THEN RAISE EXCEPTION '이미 그 지역에 있습니다.'; END IF;
  IF c.level < dest.min_level THEN RAISE EXCEPTION '%', format('레벨 %s부터 들어갈 수 있는 지역입니다.', dest.min_level); END IF;

  SELECT array_agg(region_id ORDER BY region_id), array_agg(world_x::float8 ORDER BY region_id), array_agg(world_y::float8 ORDER BY region_id),
         array_agg(coalesce(elevation, 0)::float8 ORDER BY region_id), array_agg(coalesce(terrain_cost, 1)::float8 ORDER BY region_id),
         array_agg(territory_id ORDER BY region_id), array_agg(min_level ORDER BY region_id), array_agg(to_jsonb(coalesce(travel_from, '{}')) ORDER BY region_id)
    INTO ids, xs, ys, el, tc, terr, lv, lk FROM public.world_map_regions WHERE active;
  nn := cardinality(ids);
  si := array_position(ids, here.region_id); ti := array_position(ids, dest.region_id);
  d := array_fill(1e18::float8, ARRAY[nn]); prv := array_fill(0, ARRAY[nn]); done := array_fill(false, ARRAY[nn]);
  d[si] := 0;
  SELECT coalesce(m.speed_multiplier, 1) INTO speed FROM public.world_mount_catalog m WHERE m.mount_id = c.mount_id;
  speed := coalesce(speed, 1) * (1 + 0.04 * coalesce((SELECT o.training FROM public.world_owned_mounts o WHERE o.owner_id = uid AND o.mount_id = c.mount_id), 0)) * public.world_river_boat_speed(uid, c.mount_id);
  LOOP
    u := NULL; best := 1e18;
    FOR i IN 1..nn LOOP IF NOT done[i] AND d[i] < best THEN best := d[i]; u := i; END IF; END LOOP;
    EXIT WHEN u IS NULL OR u = ti;
    done[u] := true;
    FOR nb IN SELECT jsonb_array_elements_text(lk[u]) LOOP
      v := array_position(ids, nb);
      CONTINUE WHEN v IS NULL OR done[v] OR (lv[v] > c.level);
      w := (sqrt((xs[u] - xs[v]) ^ 2 + (ys[u] - ys[v]) ^ 2) * 1.4 + abs(el[u] - el[v]) * 6 + 12) * greatest(tc[u], tc[v])
           * CASE WHEN terr[u] IS DISTINCT FROM terr[v] THEN 1.2 ELSE 1 END;
      IF d[u] + w < d[v] THEN d[v] := d[u] + w; prv[v] := u; END IF;
    END LOOP;
  END LOOP;
  IF d[ti] >= 1e17 THEN RAISE EXCEPTION '그곳으로 이어진 길이 없습니다. 레벨이 모자란 지역이 길을 막고 있습니다.'; END IF;
  v := ti;
  WHILE v <> si LOOP path := v || path; v := prv[v]; END LOOP;
  path := si || path;
  SELECT CASE WHEN coalesce(m.fare_free, false) OR public.world_river_boat_member(uid, m.mount_id) THEN 0 ELSE greatest(0, coalesce(m.fare_tokens, 1)) END INTO fare_per FROM public.world_mount_catalog m WHERE m.mount_id = c.mount_id;
  sk := public.world_skill_procs(uid);
  IF 'tracking_c24b' = ANY (sk) AND coalesce(fare_per, 0) > 0 THEN SELECT count(*) INTO n_free FROM generate_series(1, cardinality(path) - 1) WHERE random() < 0.1; END IF;
  fare := coalesce(fare_per, 0) * (cardinality(path) - 1 - n_free);
  IF fare > 0 AND c.mount_tokens < fare THEN speed := 1; walked := true; fare := 0; n_free := 0; END IF;
  IF (walked OR c.mount_id IS NULL) AND 'tracking_c43b' = ANY (sk) THEN speed := speed / 0.75; END IF;
  FOR i IN 2..cardinality(path) LOOP
    hop := (sqrt((xs[path[i - 1]] - xs[path[i]]) ^ 2 + (ys[path[i - 1]] - ys[path[i]]) ^ 2) * 1.4 + abs(el[path[i - 1]] - el[path[i]]) * 6 + 12)
           * greatest(tc[path[i - 1]], tc[path[i]]) * CASE WHEN terr[path[i - 1]] IS DISTINCT FROM terr[path[i]] THEN 1.2 ELSE 1 END / speed;
    SELECT coalesce(visits, 0) INTO vis FROM public.world_region_intel WHERE owner_id = uid AND region_id = ids[path[i]];
    hop := hop * (1 - least(0.3, coalesce(vis, 0) * 0.06));
    secs := secs + greatest(12, hop);
    names := names || (SELECT region_name FROM public.world_map_regions WHERE region_id = ids[path[i]]);
  END LOOP;
  IF cardinality(path) > 2 THEN secs := secs * 0.9; END IF;
  secs := secs * greatest(0.5, 1 + public.world_status_effect_total('travel_time_pct') / 100.0 + least(0, public.world_title_bonus('travel_time_pct')) / 100.0);
  secs := greatest(12, least(10800, secs));
  fee := 5 * (cardinality(path) - 1);
  IF c.gil < fee THEN RAISE EXCEPTION '%', format('여행 준비금 %s전이 필요합니다.', fee); END IF;
  PERFORM public.world_durability_wear(uid, 'shoes', cardinality(path) - 1); arrives := now() + make_interval(secs => round(secs));
  UPDATE public.world_characters SET gil = gil - fee, mount_tokens = mount_tokens - fare, travel_destination = dest.region_name, travel_arrives_at = arrives,
    current_exploration_node_id = NULL, updated_at = now() WHERE owner_id = uid;
  INSERT INTO public.world_travel_history(owner_id, from_region, to_region, arrives_at, fare_exempt) VALUES (uid, c.location, dest.region_name, arrives, true);
  IF fare > 0 THEN INSERT INTO public.world_economy_ledger(owner_id, action, currency_delta, sink, details) VALUES (uid, 'mount_fare', -fare, true, jsonb_build_object('mount_id', c.mount_id, 'to', dest.region_name, 'hops', cardinality(path) - 1)); END IF;
  INSERT INTO public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  VALUES (uid, 'travel_fee', -fee, true, jsonb_build_object('to', dest.region_id, 'hops', cardinality(path) - 1, 'seconds', round(secs)));
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'travel', '출발: ' || dest.region_name || CASE WHEN cardinality(path) > 2 THEN ' (' || (cardinality(path) - 1) || '구간)' ELSE '' END,
    jsonb_build_object('region_id', dest.region_id, 'region_name', dest.region_name, 'arrives_at', arrives, 'travel_seconds', round(secs), 'route', to_jsonb(names), 'mount', CASE WHEN walked THEN NULL ELSE c.mount_id END, 'fare_tokens', fare, 'walked', walked));
  RETURN jsonb_build_object('ok', true, 'content', dest.region_name || '(으)로 출발했습니다. ' || CASE WHEN n_free > 0 THEN '「샛길」 ' || n_free || '구간은 운임 없이 지납니다. ' ELSE '' END || CASE WHEN walked THEN '노정패가 모자라 탈것에서 내려 걸어갑니다. ' WHEN fare > 0 THEN '노정패 ' || fare || '개를 냈습니다. ' ELSE '' END || CASE WHEN cardinality(path) > 2 THEN array_to_string(names, ' › ') || ' · ' ELSE '' END
      || '약 ' || CASE WHEN secs >= 3600 THEN floor(secs / 3600) || '시간 ' ELSE '' END || ceil(mod(secs::numeric, 3600) / 60) || '분 뒤 도착합니다.',
    'route', to_jsonb(names), 'arrives_at', arrives, 'seconds', round(secs), 'fee', fee, 'fare_tokens', fare, 'walked', walked);
END $function$;

CREATE OR REPLACE FUNCTION public.world_travel_party_invite_v2(p_passenger_id uuid, p_region_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  uid uuid := public.fn_owner_auth_uid();
  c public.world_characters%rowtype;
  p public.world_characters%rowtype;
  r public.world_map_regions%rowtype;
  oldr public.world_map_regions%rowtype;
  rid uuid;
  pid uuid;
BEGIN perform public.world_seal_guard();
  IF uid IS NULL OR p_passenger_id = uid THEN
    RAISE EXCEPTION '동승 대상을 확인하세요.';
  END IF;

  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  SELECT * INTO p FROM public.world_characters WHERE owner_id = p_passenger_id FOR UPDATE;
  IF c.owner_id IS NULL OR p.owner_id IS NULL THEN
    RAISE EXCEPTION '대상 캐릭터를 찾을 수 없습니다.';
  END IF;

  IF c.health <= 0 OR c.downed_at IS NOT NULL OR p.health <= 0 OR p.downed_at IS NOT NULL THEN
    RAISE EXCEPTION '전투불능 상태에서는 동승할 수 없습니다.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.world_active_encounters e
    WHERE e.owner_id IN (uid, p_passenger_id)
      AND NOT e.defeated
      AND NOT coalesce(e.fled, false)
  ) THEN
    RAISE EXCEPTION '전투 중에는 이동할 수 없습니다. 전투를 먼저 마치세요.';
  END IF;

  SELECT party_id INTO pid FROM public.world_party_members WHERE owner_id = uid;
  IF pid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.world_party_members
    WHERE owner_id = p_passenger_id AND party_id = pid
  ) THEN
    RAISE EXCEPTION '같은 파티원에게만 동승을 요청할 수 있습니다.';
  END IF;

  IF c.travel_arrives_at IS NOT NULL OR p.travel_arrives_at IS NOT NULL THEN
    RAISE EXCEPTION '이동 중인 캐릭터는 동승할 수 없습니다.';
  END IF;
  IF c.location <> p.location THEN
    RAISE EXCEPTION '같은 지역에 있는 파티원에게만 동승을 요청할 수 있습니다.';
  END IF;

  SELECT * INTO r FROM public.world_map_regions
  WHERE region_id = p_region_id AND active;
  SELECT * INTO oldr FROM public.world_map_regions
  WHERE region_name = c.location OR region_id = c.location
     OR (c.location IN ('야행국 본부 · 정청', '야행국 본부 정청', '본부 로비')
         AND region_id = 'hq_yard')
  LIMIT 1;

  IF r.region_id IS NULL OR oldr.region_id IS NULL
     OR NOT (r.region_id = ANY(coalesce(oldr.travel_from, '{}'::text[]))) THEN
    RAISE EXCEPTION '목적지가 연결된 경로가 아닙니다.';
  END IF;

  IF NOT (public.world_domain_open(uid, r.territory_id) AND public.world_domain_open(p_passenger_id, r.territory_id)) THEN
    RAISE EXCEPTION '귀허도는 10장 「구중 봉연」을 마친 조사원만 건너갈 수 있습니다.';
  END IF;
  IF c.level < r.min_level OR p.level < r.min_level THEN
    RAISE EXCEPTION '동승자 모두 목적지의 최소 레벨을 충족해야 합니다.';
  END IF;

  IF c.mount_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.world_mount_catalog m
    JOIN public.world_owned_mounts om
      ON om.mount_id = m.mount_id AND om.owner_id = uid
    WHERE m.mount_id = c.mount_id AND m.passenger_capacity >= 2
  ) THEN
    RAISE EXCEPTION '탑승 정원 2명 이상의 보유 탈것을 장착해야 합니다.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.world_travel_party_requests q
    WHERE q.leader_id = uid AND q.passenger_id = p_passenger_id
      AND q.status = 'pending'
  ) THEN
    RAISE EXCEPTION '이미 처리 대기 중인 동승 요청이 있습니다.';
  END IF;

  INSERT INTO public.world_travel_party_requests
    (leader_id, passenger_id, from_region, to_region, status)
  VALUES (uid, p_passenger_id, oldr.region_id, p_region_id, 'pending')
  RETURNING request_id INTO rid;

  INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
  VALUES (p_passenger_id, 'ride_request', '동승 요청',
    coalesce((SELECT x.character_name FROM public.world_characters x WHERE x.owner_id = uid), '동료') || '이(가) '
      || coalesce((SELECT mr.region_name FROM public.world_map_regions mr WHERE mr.region_id = p_region_id), '다른 곳') || '(으)로 함께 가자고 합니다.',
    jsonb_build_object('request_id', rid, 'from_id', uid, 'to_region', p_region_id));

  RETURN jsonb_build_object(
    'ok', true,
    'request_id', rid,
    'content', p.character_name || '에게 동승 요청을 보냈습니다. 수락하면 함께 출발합니다.'
  );
END
$function$;

CREATE OR REPLACE FUNCTION public.world_travel_party_respond_v2(p_request_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
 uid uuid:=public.fn_owner_auth_uid();
 q public.world_travel_party_requests%rowtype;
 c public.world_characters%rowtype;
 p public.world_characters%rowtype;
 r public.world_map_regions%rowtype;
 oldr public.world_map_regions%rowtype;
 speed numeric:=1; secs int; dist numeric; dx numeric; dy numeric;
 arrive timestamptz; pid uuid; fare int:=0;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select * into q from public.world_travel_party_requests where request_id=p_request_id for update;
 if q.request_id is null or q.passenger_id<>uid or q.status<>'pending'
   then raise exception '유효한 동승 요청이 없습니다.'; end if;
 if not p_accept then
   update public.world_travel_party_requests
     set status='declined', responded_at=now()
   where request_id=q.request_id;
   return jsonb_build_object('ok',true,'content','동승 요청을 거절했습니다.');
 end if;

 select * into c from public.world_characters where owner_id=q.leader_id for update;
 select * into p from public.world_characters where owner_id=uid for update;
 if c.owner_id is null or p.owner_id is null
   then raise exception '캐릭터 정보를 찾을 수 없습니다.'; end if;
 if c.health<=0 or c.downed_at is not null or p.health<=0 or p.downed_at is not null
   then raise exception '전투불능 상태에서는 동승할 수 없습니다.'; end if;
 if exists(
     select 1 from public.world_active_encounters e
     where e.owner_id in (q.leader_id,uid)
       and not e.defeated and not coalesce(e.fled,false))
   then raise exception '전투 중에는 이동할 수 없습니다. 전투를 먼저 마치세요.'; end if;
 select party_id into pid from public.world_party_members where owner_id=q.leader_id;
 if pid is null or not exists(
     select 1 from public.world_party_members where owner_id=uid and party_id=pid)
   then raise exception '같은 파티원이 아니므로 동승할 수 없습니다.'; end if;
 if c.travel_arrives_at is not null or p.travel_arrives_at is not null
    or c.location<>p.location
   then raise exception '출발 위치가 변경되었거나 한 명이 이동 중입니다.'; end if;
 if c.gil<5 or p.gil<5
   then raise exception '두 사람 모두 여행 준비금 5전을 보유해야 합니다.'; end if;

 select * into r from public.world_map_regions where region_id=q.to_region and active;
 select * into oldr from public.world_map_regions
   where region_name=c.location or region_id=c.location
      or (c.location in ('야행국 본부 · 정청','야행국 본부 정청','본부 로비')
          and region_id='hq_yard')
   limit 1;
 if r.region_id is null or oldr.region_id is null or oldr.region_id<>q.from_region
    or not (r.region_id=any(coalesce(oldr.travel_from,'{}')))
   then raise exception '목적지 경로가 만료되었습니다.'; end if;
 if c.mount_id is null or not exists(
     select 1 from public.world_mount_catalog m
     join public.world_owned_mounts om on om.mount_id=m.mount_id and om.owner_id=q.leader_id
     where m.mount_id=c.mount_id and m.passenger_capacity>=2)
   then raise exception '출발자의 탈것이 동승 조건을 충족하지 않습니다.'; end if;

 -- 운임 확인만 하고 차감은 트리거(world_charge_mount_fare)에 위임
 select case when coalesce(m.fare_free,false) or public.world_river_boat_member(q.leader_id, m.mount_id) then 0
             else greatest(0,coalesce(m.fare_tokens,1)) end
   into fare
   from public.world_mount_catalog m where m.mount_id=c.mount_id;
 fare:=coalesce(fare,0);
 if c.mount_tokens<fare
   then raise exception '노정패가 모자라 함께 떠날 수 없습니다(운임 %개).', fare; end if;
 if c.level<r.min_level or p.level<r.min_level
   then raise exception '동승자 모두 목적지의 최소 레벨을 충족해야 합니다.'; end if;

 if not (public.world_domain_open(q.leader_id, r.territory_id) and public.world_domain_open(uid, r.territory_id))
   then raise exception '귀허도는 10장 「구중 봉연」을 마친 조사원만 건너갈 수 있습니다.'; end if;
 dx:=(r.world_x-oldr.world_x)::numeric;
 dy:=(r.world_y-oldr.world_y)::numeric;
 dist:=sqrt(dx*dx+dy*dy);
 select coalesce(speed_multiplier,1) into speed
   from public.world_mount_catalog where mount_id=c.mount_id;
 secs:=greatest(12,least(1800,round(
   (dist*2.2+abs(r.elevation-oldr.elevation)*9+15)
   *greatest(r.terrain_cost,oldr.terrain_cost)
   *case when r.territory_id<>oldr.territory_id then 1.35 else 1 end
   /(coalesce(speed,1)*public.world_river_boat_speed(q.leader_id, c.mount_id)))::int));
 arrive:=now()+make_interval(secs=>secs);

 update public.world_characters
   set gil=gil-5, travel_destination=r.region_name,
       travel_arrives_at=arrive, updated_at=now()
 where owner_id in (q.leader_id,uid);

 -- 운임은 world_travel_history INSERT BEFORE 트리거(world_charge_mount_fare)가
 -- 파티장 행에 대해서만 파티장 탈것 기준으로 정확히 1회 처리한다.
 -- 동승자 행은 fare_exempt=true 이므로 동승자 본인 탈것과 무관하게 운임이 없다.
 insert into public.world_travel_history(owner_id,from_region,to_region,arrives_at,passenger_count,fare_exempt)
   values(q.leader_id, c.location, r.region_name, arrive, 2, false),
         (uid,         p.location, r.region_name, arrive, 2, true);

 insert into public.world_economy_ledger(owner_id,action,currency_delta,sink,details)
   values(q.leader_id,'travel_fee',-5,true,
          jsonb_build_object('to',q.to_region,'seconds',secs,'party',q.request_id)),
         (uid,'travel_fee',-5,true,
          jsonb_build_object('to',q.to_region,'seconds',secs,'party',q.request_id));

 update public.world_travel_party_requests
   set status='departed', responded_at=now(), departed_at=now()
 where request_id=q.request_id;

 insert into public.world_events(actor_id,actor_name,event_type,content,payload)
   values(q.leader_id, c.character_name, 'travel',
          '동승 출발: '||r.region_name,
          jsonb_build_object(
            'region_id',r.region_id,'region_name',r.region_name,
            'arrives_at',arrive,'travel_seconds',secs,'passenger_id',uid));

 return jsonb_build_object(
   'ok',true,
   'content','동승 수락 완료. 두 조사원이 함께 출발했습니다. 목적지: '||r.region_name,
   'region_id',r.region_id,'region_name',r.region_name,
   'arrives_at',arrive,'travel_seconds',secs,'fare_tokens',fare);
end
$function$;

CREATE OR REPLACE FUNCTION public.world_raid_schedule_next()
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare cnt int; lo int; hi int; pick text; cands text[]; at timestamptz;
begin
  if exists (select 1 from public.world_raids where kind = 'world' and status in ('announced', 'signup', 'fight')) then
    return (select spawn_at from public.world_raids where kind = 'world' and status in ('announced', 'signup', 'fight') order by spawn_at limit 1);
  end if;
  if public.world_long_night_stage(now()) between 1 and 4 then
    if exists (select 1 from public.world_raids where kind = 'world' and fx ? 'last_night') or now() >= timestamptz '2026-11-01 20:00+09' then return timestamptz '2026-11-02 00:00+09'; end if; -- 정산이 이 시각으로 지역 잠금을 잡는다(빈 값이면 실패 정산이 멈춤)
    insert into public.world_raids(kind, boss_name, region_id, status, candidates, spawn_at, fx)
    values ('world', '봉연의 그림자', 'hq_training', 'announced', array['hq_training', 'field_outskirts', 'shrine_ruins'],
            timestamptz '2026-11-01 20:00+09', '{"last_night": true}');
    return timestamptz '2026-11-01 20:00+09';
  end if;
  select count(*) into cnt from public.world_raids where kind = 'world';
  lo := case cnt % 3 when 0 then 1 when 1 then 11 else 21 end; hi := case cnt % 3 when 0 then 10 when 1 then 20 else 30 end;
  select array_agg(region_id order by random()) into cands from (
    select region_id from public.world_map_regions where active and not coalesce(is_safe_zone, false) and not public.world_domain_flag(territory_id, 'no_shadow') and coalesce(min_level, 1) between lo and hi
     order by random() limit 3) z;
  if cands is null or array_length(cands, 1) = 0 then
    select array_agg(region_id) into cands from (select region_id from public.world_map_regions where active and not coalesce(is_safe_zone, false) and not public.world_domain_flag(territory_id, 'no_shadow') order by random() limit 3) z;
  end if;
  pick := cands[1];
  at := public.world_raid_evening(greatest(now(), coalesce((select m.value::timestamptz from public.world_app_meta m where m.key = 'open_at'), now())) + interval '72 hours'); -- 저녁 18:00~21:30(KST)에만
  insert into public.world_raids(kind, boss_name, region_id, status, candidates, spawn_at)
  values ('world', '봉연의 그림자', pick, 'announced', (select array_agg(x order by random()) from unnest(cands) x), at);
  return at;
end $function$;

CREATE OR REPLACE FUNCTION public.world_event_char_apply()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  uid uuid := new.actor_id; k text := coalesce(new.event_type, ''); p jsonb := coalesce(new.payload, '{}'::jsonb);
  won boolean := coalesce((new.payload ->> 'defeated')::boolean, false); trav boolean;
  c public.world_characters%rowtype; act text; hp_tick int := 0; mn_tick int := 0;
  tok int := 0; xp_e int := 0; award int := 0; er int := 0; er_x int := 0; rep int := 0;
  sk text; sk_xp int := 0; rcp text; rare text;
  cx int; gx int; crx int; ix int; nx int; nl int; gained int := 0; sp jsonb; ero int; hp int; mn int; dn timestamptz;
begin
  if uid is null then return new; end if;
  trav := k in ('travel', 'move') and p ? 'travel_history_id';
  perform set_config('request.jwt.claim.sub', uid::text, true);
  -- 행동마다 상태 피해를 받는 활동(옛 world_apply_activity_status)
  act := case when k = 'combat' then 'combat' when k in ('explore', 'regional_explore') then 'explore' when k in ('gather', 'gathering') then 'gather'
    when k in ('craft', 'crafting') then 'craft' when k in ('investigation', 'investigate', 'case') then 'investigation' when k in ('training', 'train') then 'training'
    when trav then 'travel' when k = 'rest' then 'rest' when k = 'rescue' then 'rescue' when k = 'story' then 'story' end;
  -- 노정패(옛 world_award_mount_tokens)
  if k = 'combat' and won then tok := 1;
  elsif k in ('explore', 'gather') and random() < 1.0 / 6 then tok := 1;
  elsif k = 'story' then tok := 3;
  elsif k in ('commission', 'mission') then tok := 2; end if;
  -- 숙련 경험(옛 world_apply_event_progress)
  xp_e := case when k = 'combat' then case when won then 45 else 0 end when k = 'gather' then 18 when k = 'craft' then 22
    when k in ('explore', 'story', 'faction') then 16 else 0 end;
  -- 경험치(옛 world_award_progression_from_event)
  award := case k when 'combat' then case when won then 12 else 0 end when 'craft' then 18 when 'gather' then 14 when 'explore' then 8
    when 'story' then 20 when 'equip' then 4 when 'travel' then case when p ? 'travel_history_id' then 5 else 0 end
    when 'travel_arrive' then 5 when 'trade' then 5 when 'shop_buy' then 3 when 'shop_sell' then 3 when 'mount' then 5
    when 'supply' then 3 when 'craft_refine' then 18 when 'rest' then 2 else 0 end;
  -- 기술 경험(옛 world_track_specialized_skill)
  if k in ('combat', 'gather', 'craft', 'explore', 'story', 'rescue') or (k = 'travel' and p ? 'travel_history_id') then
    sk := case
      when k = 'combat' and coalesce(p ->> 'action', '') = 'analyze' then 'analysis'
      when k = 'combat' and coalesce(p ->> 'action', '') = 'support' then 'first_aid'
      when k = 'combat' and coalesce(p ->> 'action', '') = 'guard' then 'guarding'
      when k = 'combat' then coalesce(p ->> 'line', public.world_job_line((select x.job_key from public.world_characters x where x.owner_id = uid)), 'melee')
      when k = 'gather' and coalesce(p ->> 'node', '') = 'ore' then 'mining'
      when k = 'gather' and p ? 'line' then p ->> 'line'
      when k = 'gather' and coalesce(p ->> 'category', '') = 'relics' then 'mining'
      when k = 'gather' then 'foraging'
      when k in ('explore', 'story', 'travel') then 'tracking' end;
    if k = 'craft' then
      select public.world_craft_line_of(craft_field)
        into rcp from public.world_crafting_recipes where recipe_id = coalesce(p ->> 'recipe', '');
      sk := nullif(coalesce(rcp, case when coalesce(p ->> 'recipe', '') ilike '%seal%' then 'wardcraft' when coalesce(p ->> 'recipe', '') ilike '%alchemy%' then 'alchemy' else 'smithing' end), '-');
    end if;
    sk_xp := case k when 'combat' then 10 when 'gather' then 8 when 'craft' then 12 when 'explore' then 5 when 'story' then 10 when 'travel' then 3 else 0 end;
    if sk_xp <= 0 then sk := null; end if;
  end if;
  -- 대세력 평판(옛 world_track_major_faction_reputation): 토벌은 이긴 기록에만
  if not (k = 'combat' and not won) then
    rep := case k when 'combat' then 3 when 'story' then 3 when 'explore' then 2 when 'gather' then 1 when 'craft' then 1 when 'mission' then 4 else 0 end;
  end if;
  -- 토벌 침식(옛 world_apply_event_progress, 보정은 아래에서)
  if k in ('combat', 'battle_lost') then
    er := case when won then case when public.world_region_danger(p ->> 'region_id') >= 3 then 1 else 0 end else 3 end
      + case when p ->> 'mechanic' in ('독성', 'toxic', '영체', 'spectral', '반사', 'reflect', '매복', 'ambush', 'boss') or p ->> 'rank' in ('elite', 'boss', 'guardian') then 2 else 0 end;
  elsif k = 'explore' and coalesce(p ->> 'kind', '') <> 'field_search' and coalesce(p ->> 'location', '') not in ('야행국 본부 · 로비', '본부 로비', 'hq_yard') then
    er_x := 2;
  end if;
  if act is null and tok = 0 and xp_e = 0 and award = 0 and sk is null and rep = 0 and er = 0 and er_x = 0 then return new; end if;

  select * into c from public.world_characters where owner_id = uid for update;
  if not found or coalesce(c.is_dead, false) then return new; end if;
  if sk = 'tracking' and sk_xp > 0 then
    if coalesce((c.skill_progress -> 'tracking' ->> 'rank')::int, 0) >= 3 then sk_xp := floor(sk_xp * 1.1)::int + case when random() < sk_xp * 1.1 - floor(sk_xp * 1.1) then 1 else 0 end; end if;
    if coalesce((c.skill_progress -> 'tracking' ->> 'rank')::int, 0) >= 8 and coalesce((p ->> 'danger')::int, 0) >= 5 then sk_xp := sk_xp + 4; end if;
  end if;
  if act is not null then
    select greatest(0, coalesce(sum(case when (cat.effects ->> 'health_per_action') ~ '^-?[0-9]+$' then (cat.effects ->> 'health_per_action')::int * cs.potency else 0 end), 0)),
           coalesce(sum(case when (cat.effects ->> 'mental_per_action') ~ '^-?[0-9]+$' then (cat.effects ->> 'mental_per_action')::int * cs.potency else 0 end), 0)
      into hp_tick, mn_tick
      from public.world_character_statuses cs join public.world_status_catalog cat using (status_key)
     where cs.owner_id = uid and cs.expires_at > now() and act = any (cat.triggers);
    -- 침식 위험(55) 이상이면 행동마다 정신 1을 더 잃는다
    mn_tick := mn_tick + case when c.erosion >= 55 then 1 else 0 end;
    -- 정신 손실 감소(소속·직업·칭호·관모·등잔빛 등, 7.5.2)를 곱한다. 「맑은 정신」(−1)은 침식 위험의 +1을 상쇄
    if mn_tick > 0 then mn_tick := greatest(0, floor(mn_tick * greatest(0.25, 1 + public.world_status_effect_total('mental_loss_pct') / 100.0) + random())::int);
    else mn_tick := 0; end if;
  end if;
  if er > 0 then er := floor(er * greatest(0, 1 + public.world_erosion_pct_self() / 100.0) + random())::int; end if;
  if k in ('combat', 'battle_lost') and won and random() < 0.22 then
    rare := case when p ->> 'region_id' = 'sealed_abyss' then 'spirit_core' when public.world_domain_rare(p ->> 'region_id') is not null then public.world_domain_rare(p ->> 'region_id') else case coalesce(p ->> 'mechanic', '')
      when '독성' then 'venom_gland' when 'toxic' then 'venom_gland' when '영체' then 'ghost_ash' when 'spectral' then 'ghost_ash'
      when '수계' then 'drowned_scale' when 'tide' then 'drowned_scale' when '장갑' then 'monster_core' when 'armored' then 'monster_core'
      when '비행' then 'sky_feather' when 'aerial' then 'sky_feather' when '반사' then 'mirror_shard' when 'reflect' then 'mirror_shard'
      when '결계' then 'ward_fragment' when 'warded' then 'ward_fragment' when '매복' then 'shadow_fang' when 'ambush' then 'shadow_fang'
      else 'monster_core' end end;
  end if;
  if ((k = 'explore' and p ->> 'kind' = 'field_search') or k = 'gather' or (k = 'fish' and coalesce((p ->> 'caught')::boolean, false))) and rare is null then
    rare := case when random() < 0.0006 then 'pet_egg_3' when random() < 0.005 then 'pet_egg_2' end;
  end if;
  if hp_tick = 0 and mn_tick = 0 and tok = 0 and xp_e = 0 and award = 0 and sk is null and (rep = 0 or c.major_faction_id is null)
     and er <= 0 and er_x = 0 and rare is null then return new; end if;

  cx := c.combat_xp + case when k = 'combat' then xp_e else 0 end;
  gx := c.gathering_xp + case when k = 'gather' then xp_e else 0 end;
  crx := c.crafting_xp + case when k = 'craft' then xp_e else 0 end;
  ix := c.investigation_xp + case when k in ('explore', 'story', 'faction') then xp_e else 0 end;
  nl := c.level; nx := c.experience;
  if award > 0 then
    gx := least(500000, gx + case when k = 'gather' then award else 0 end);
    crx := least(600000, crx + case when k in ('craft', 'craft_refine') then award else 0 end);
    ix := least(500000, ix + case when k = 'explore' then award else 0 end);
    nx := case when nl >= 40 then 0 else nx + award end;
    if nl < 40 then
      while nl < 40 and nx >= public.world_xp_need(nl) loop nx := nx - public.world_xp_need(nl); nl := nl + 1; gained := gained + 1; end loop;
    else nx := 0; end if;
    if nl >= 40 then nx := 0; end if;
  end if;
  sp := case when sk is not null then public.world_skill_add(c.skill_progress, sk, round(sk_xp * greatest(0.5, 1 + public.world_status_self(c.owner_id, 'training_xp_pct') / 100.0))::int, case when k = 'combat' then p -> 'acts' end) else c.skill_progress end;
  hp := c.health; mn := c.mental; dn := c.downed_at;
  if hp_tick > 0 or mn_tick > 0 then
    hp := greatest(0, c.health - hp_tick); mn := greatest(0, c.mental - mn_tick);
    dn := case when c.health - hp_tick <= 0 then coalesce(c.downed_at, now()) else c.downed_at end;
  end if;
  if er > 0 then mn := greatest(0, mn - case when won then 0 else 1 end); end if;
  ero := case when er > 0 or er_x > 0 then least(100, c.erosion + greatest(er, 0) + er_x) else c.erosion end;
  if er > 0 or er_x > 0 then perform public.world_yohwa_overflow(c.owner_id, c.erosion + greatest(er, 0) + er_x - 100); end if;
  if award > 0 then hp := least(100, hp + gained * 10); mn := least(100, mn + gained * 5); end if;

  update public.world_characters set
    health = hp, mental = mn, downed_at = dn,
    mount_tokens = least(9999, mount_tokens + tok),
    combat_xp = cx, gathering_xp = gx, crafting_xp = crx, investigation_xp = ix,
    level = least(40, nl), experience = nx,
    stat_points = case when gained > 0 then least(117, stat_points + gained * 3) else stat_points end,
    spiritual_power = case when gained > 0 then least(100, spiritual_power + gained * 5) else spiritual_power end,
    skill_progress = sp,
    faction_reputation = case when rep > 0 and major_faction_id is not null then least(5000, greatest(-1000, coalesce(faction_reputation, 0) + rep)) else faction_reputation end,
    erosion = ero,
    erosion_stage = case when er > 0 or er_x > 0 then case when ero >= 80 then 4 when ero >= 55 then 3 when ero >= 30 then 2 when ero >= 10 then 1 else 0 end else erosion_stage end,
    inventory = case when rare is not null then jsonb_set(coalesce(inventory, '{}'::jsonb), array[rare], to_jsonb(coalesce((inventory ->> rare)::int, 0) + 1), true) else inventory end,
    updated_at = now()
  where owner_id = uid;
  if rare is not null then
    insert into public.world_events(actor_id, actor_name, event_type, content, payload)
    values (uid, coalesce(c.character_name, '조사원'), 'loot', '희귀 전리품 획득: ' || rare || ' ×1', jsonb_build_object('item', rare, 'qty', 1, 'source', 'monster_rare_drop'));
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.world_map_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; regions jsonb; current_region text; shut text[]; hide text[]; reach text[];
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select * into c from public.world_characters where owner_id=uid;
 select region_id into current_region from public.world_map_regions where region_name=c.location or region_id=c.location or (c.location in ('야행국 본부 · 정청','야행국 본부 정청','본부 로비') and region_id='hq_yard') limit 1;
 shut := public.world_domain_shut();
 hide := coalesce((select array_agg(x.region_id) from public.world_map_regions x where x.territory_id = any(shut)), '{}');
 reach := coalesce((select x.travel_from from public.world_map_regions x where x.region_id=current_region),'{}');
 select coalesce(jsonb_agg(jsonb_build_object('region_id',r.region_id,'territory_id',r.territory_id,'territory_name',r.territory_name,'region_name',r.region_name,'region_type',r.region_type,'danger_level',r.danger_level,'min_level',r.min_level,'level_locked',coalesce(c.level,1)<r.min_level,
 'description',CASE WHEN (v.n>0 OR r.region_id=current_region) THEN r.description ELSE '미답사 지역. 직접 방문하면 상세 정보가 공개됩니다.' END,
 'biome_name',CASE WHEN (v.n>0 OR r.region_id=current_region) THEN p.biome_name ELSE '미확인 지형' END,
 'visual_identity',CASE WHEN (v.n>0 OR r.region_id=current_region) THEN p.visual_identity ELSE NULL END,
 'survival_hazard',CASE WHEN v.n>=2 THEN p.survival_hazard ELSE NULL END,
 'signature_resources',CASE WHEN v.n>=2 THEN to_jsonb(p.signature_resources) ELSE '[]'::jsonb END,
 'signature_items',CASE WHEN coalesce(i.investigations_completed,0)>0 THEN to_jsonb(p.signature_items) ELSE '[]'::jsonb END,
 'signature_clue',CASE WHEN v.n>=3 THEN p.signature_clue ELSE NULL END,
 'signature_event',CASE WHEN (v.n>0 OR r.region_id=current_region) THEN p.signature_event ELSE '미확인 사건 기록' END,
 'faction_style',CASE WHEN v.n>=2 THEN p.faction_style ELSE '현지 세력 미확인' END,
 'visits',v.n,
 'travel_discount',least(0.30,v.n*0.06),
 'travel_from',case when cardinality(hide) = 0 then r.travel_from else array(select x from unnest(r.travel_from) x where x <> all(hide)) end,'gather_nodes',r.gather_nodes,'faction_control',r.faction_control,'is_starting_area',r.is_starting_area,'world_x',r.world_x,'world_y',r.world_y,'elevation',r.elevation,'terrain_cost',r.terrain_cost,'rest_spot_type',r.rest_spot_type,'rest_spot_name',r.rest_spot_name,'rest_quality',r.rest_quality,'rest_fee',r.rest_fee,'rest_risk',r.rest_risk,'reachable',r.region_id=any(reach),'monsters',coalesce((select jsonb_agg(jsonb_build_object('monster_id',m.monster_id,'monster_name',m.monster_name,'min_level',m.min_level,'max_level',m.max_level,'description',m.description,'hp',m.hp,'attack_power',m.attack_power) order by m.min_level) from public.world_region_monsters m where m.region_id=r.region_id),'[]'::jsonb)) order by r.territory_id,r.world_y,r.world_x),'[]'::jsonb) into regions
   from public.world_map_regions r
   left join public.world_region_intel i on i.owner_id=uid and i.region_id=r.region_id
   left join public.world_region_profiles p on p.region_id=r.region_id
   cross join lateral (select coalesce(i.visits,0) n) v
  where r.active and not (coalesce(r.territory_id, '') = any(shut));
 return jsonb_build_object('regions',regions,'location',c.location,'level',c.level,'major_faction_id',c.major_faction_id,'faction_reputation',c.faction_reputation,'current_region_id',current_region);
end $function$;

CREATE OR REPLACE FUNCTION public.world_fish()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; g public.world_fish_grounds%rowtype;
  sp public.world_fish_species%rowtype; rod int; last timestamptz; ph text; wk text; bite numeric; boost numeric; size numeric; first boolean; rod_m numeric := 1;
  xp int := 0; left_st int; inv jsonb; msg text; rname text; sk text[]; prog jsonb; gap int := 20; mx int; ticks int; cur int; base_at timestamptz;
  cost int := 1; caught boolean; notes text[] := '{}'; sxp int; more int := 0; nmore int := 0;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  -- 7.7.7m: 가장 짧은 간격(15초) 안의 연타는 잠그기 전에 돌려보낸다
  perform public.world_rate_check('fish', uid);
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 낚시할 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 낚시할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '전투 중에는 낚시할 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then raise exception '원정 중에는 낚시할 수 없습니다.'; end if;
  r := public.world_field_region(c.location);
  select * into g from public.world_fish_grounds where region_id = r.region_id;
  if g.region_id is null then raise exception '이곳에는 낚시터가 없습니다. 강·늪·바다·호수가 있는 지역에서 낚을 수 있습니다.'; end if;
  rod := coalesce((select i.tier from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0);
  if rod = 0 then raise exception '낚싯대가 있어야 낚시할 수 있습니다. 구름나루·백등 야시장·잔불촌 상점에서 사거나 직접 만들 수 있습니다.'; end if;
  rod_m := coalesce((select CASE WHEN x.mx IS NULL THEN 1 WHEN coalesce(dd.durability, x.mx) <= 0 THEN 0 WHEN coalesce(dd.durability, x.mx) * 4 < x.mx THEN 0.8 ELSE 1 END
      from (select public.world_fish_rod(uid) as it) ri cross join lateral (select public.world_item_max_durability(ri.it) as mx) x
      left join public.world_item_durability dd on dd.owner_id = uid and dd.item_id = ri.it), 1);
  sk := public.world_skill_procs(uid);
  gap := public.world_fish_gap(uid);
  select max(created_at) into last from public.world_events where actor_id = uid and event_type = 'fish' and created_at > now() - make_interval(secs => gap);
  if last is not null then raise exception '%', format('찌를 다시 던지려면 %s초 기다리세요.', ceil(extract(epoch from (last + make_interval(secs => gap) - now())))::int); end if;
  -- 탐색력(용왕의 손 25%는 쓰지 않음, 놓친 고기 없다는 놓치면 돌려받음)
  if 'fishing_m50' = any (sk) and random() < 0.25 then cost := 0; notes := notes || '「용왕의 손」 탐색력을 쓰지 않았습니다'::text; end if;
  mx := public.world_stamina_max(c.level);
  ticks := floor(greatest(0, extract(epoch from now() - c.stamina_at)) / 900)::int;
  cur := least(mx, greatest(0, c.stamina) + ticks);
  if cur - cost < 0 then
    raise exception '%', format('탐색력이 부족합니다. %s분 뒤에 1 회복됩니다.', greatest(1, ceil((900 - mod(greatest(0, extract(epoch from now() - c.stamina_at))::numeric, 900)) / 60)::int));
  end if;
  base_at := case when cur >= mx then now() else c.stamina_at + make_interval(secs => ticks * 900) end;
  ph := public.world_time_phase(now()); wk := public.world_weather_key(r.territory_id, now());
  bite := 0.62 + least(rod, case when 'combo_fishing_carpentry' = any (sk) then 3 else 2 end) * 0.06 * rod_m + case when c.gathering_profession = 'fishing' then 0.08 else 0 end + case when wk in ('rain', 'drizzle', 'fog', 'cloudy') then 0.05 else 0 end
    + (public.world_title_bonus('fish_bite_pct') + public.world_status_effect_total('fish_bite_pct') + public.world_line_base(c.skill_progress, 'fishing', 'fish_bite_pct')) / 100.0
    + coalesce((select (i.equipment_traits ->> 'fish_bite_pct')::numeric * rod_m from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0) / 100.0
    + case when 'fishing_c43b' = any (sk) and exists (select 1 from public.world_fish_species s where s.habitat = g.habitat and s.active and (s.phase = ph or s.weather = wk)) then 0.10 else 0 end;
  bite := least(0.95, greatest(0.3, bite));
  caught := random() <= bite;
  sxp := round(8 * greatest(0.5, 1 + public.world_status_self(uid, 'training_xp_pct') / 100.0))::int;
  prog := public.world_skill_add(c.skill_progress, 'fishing', sxp);
  if not caught then
    if 'fishing_c24b' = any (sk) and cost > 0 then cost := 0; notes := notes || '「놓친 고기 없다」 탐색력을 돌려받았습니다'::text; end if;
    left_st := least(mx, cur - cost);
    update public.world_characters set stamina = left_st, stamina_at = base_at, skill_progress = prog, updated_at = now() where owner_id = uid;
    msg := g.ground_name || '에서 찌가 흔들렸지만 놓쳤습니다.' || case when cardinality(notes) > 0 then ' ' || array_to_string(notes, ' · ') || '.' else '' end;
    insert into public.world_events(actor_id, actor_name, event_type, content, payload)
    values (uid, c.character_name, 'fish', msg, jsonb_build_object('caught', false, 'region_id', r.region_id, 'habitat', g.habitat, 'skill_xp', sxp));
    return jsonb_build_object('ok', true, 'caught', false, 'content', msg, 'stamina', left_st, 'ready_at', now() + make_interval(secs => gap));
  end if;
  boost := public.world_title_bonus('fish_rare_pct') + public.world_status_effect_total('fish_rare_pct') + public.world_status_effect_total('rare_loot_pct') + public.world_title_bonus('rare_loot_pct')
    + least(rod, case when 'combo_fishing_carpentry' = any (sk) then 3 else 2 end) * 3 * rod_m + public.world_line_base(c.skill_progress, 'fishing', 'fish_rare_pct')
    + coalesce((select (i.equipment_traits ->> 'fish_rare_pct')::numeric * rod_m from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0);
  select * into sp from public.world_fish_species s
   where s.habitat = g.habitat and s.active and s.min_level <= c.level + 2 and (s.grounds is null or r.region_id = any(s.grounds))
   order by -ln(greatest(random(), 1e-9)) / (
       (coalesce((public.world_fish_rules() -> 'weight' ->> s.rarity)::numeric, (public.world_fish_rules() -> 'weight' ->> 'legendary')::numeric) * case when (public.world_fish_rules() -> 'boosted') ? s.rarity then 1 + boost / 100.0 else 1 end)
     * (case when s.rarity in ('epic', 'legendary') and 'fishing_c43a' = any (sk) then 1.5 else 1 end)
     * (case when s.phase is null then 1 when s.phase = ph then (public.world_fish_rules() ->> 'match')::numeric when 'fishing_x30' = any (sk) then (public.world_fish_rules() ->> 'miss_skill')::numeric else (public.world_fish_rules() ->> 'miss')::numeric end)
     * (case when s.weather is null then 1 when s.weather = wk then (public.world_fish_rules() ->> 'match')::numeric when 'fishing_x30' = any (sk) then (public.world_fish_rules() ->> 'miss_skill')::numeric else (public.world_fish_rules() ->> 'miss')::numeric end)) limit 1;
  if sp.fish_id is null then raise exception '물고기가 보이지 않습니다.'; end if;
  size := round(least(sp.size_max * 1.1, (sp.size_min + (sp.size_max - sp.size_min) * power(random(), 1.6)::numeric)
    * (1 + (public.world_title_bonus('fish_size_pct') + public.world_line_base(c.skill_progress, 'fishing', 'fish_size_pct')
       + coalesce((select (i.equipment_traits ->> 'fish_size_pct')::numeric * rod_m from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0)) / 100.0)), 1);
  first := not exists (select 1 from public.world_fish_log where owner_id = uid and fish_id = sp.fish_id);
  -- 두 마리(낚시 13)·그물 짓기(낚시·직조 조합): 따로 굴리되 한 번에 하나만 더
  if ('fishing_x13' = any (sk) and random() < 0.08) or ('combo_fishing_weaving' = any (sk) and random() < 0.10) then more := 1; notes := notes || '같은 물고기를 하나 더 낚았습니다'::text; end if;
  insert into public.world_fish_log(owner_id, fish_id, caught, best_size) values (uid, sp.fish_id, 1 + more, size)
  on conflict (owner_id, fish_id) do update set caught = public.world_fish_log.caught + 1 + more, best_size = greatest(public.world_fish_log.best_size, excluded.best_size), last_at = now();
  xp := case sp.rarity when 'common' then 6 when 'uncommon' then 10 when 'rare' then 18 when 'epic' then 30 else 50 end;
  inv := public.world_inv_add(c.inventory, sp.fish_id, 1 + more);
  -- 갯가 주방(낚시·요리 조합): 20% 손질한 생선 하나
  if 'combo_fishing_cooking' = any (sk) and random() < 0.20 then inv := public.world_inv_add(inv, 'fish_fillet', 1); nmore := 1; notes := notes || '「갯가 주방」 손질한 생선 하나'::text; end if;
  left_st := least(mx, cur - cost);
  update public.world_characters set inventory = inv, gathering_xp = gathering_xp + xp, skill_progress = prog,
    stamina = left_st, stamina_at = base_at, updated_at = now() where owner_id = uid;
  rname := case sp.rarity when 'uncommon' then '양품' when 'rare' then '진품' when 'epic' then '명품' when 'legendary' then '신품' else '' end;
  msg := g.ground_name || '에서 ' || sp.fish_name || '을(를) 낚았습니다. ' || size || 'cm' || case when rname <> '' then ' · ' || rname else '' end
    || case when first then ' · 도감에 새로 올랐습니다' else '' end || case when cardinality(notes) > 0 then ' · ' || array_to_string(notes, ' · ') else '' end;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'fish', msg, jsonb_build_object('caught', true, 'fish', sp.fish_id, 'rarity', sp.rarity, 'size', size,
    'region_id', r.region_id, 'habitat', g.habitat, 'first', first, 'qty', 1 + more, 'skill_xp', sxp));
  perform public.world_title_award_check(uid, 'fish');
  return jsonb_build_object('ok', true, 'caught', true, 'content', msg, 'fish', sp.fish_id, 'fish_name', sp.fish_name, 'rarity', sp.rarity,
    'size', size, 'first', first, 'xp', xp, 'qty', 1 + more, 'stamina', left_st, 'ready_at', now() + make_interval(secs => gap));
end $function$;


update public.world_patch_notes set body = body || E'\n- 서버 안쪽 정리: 영역 열림·빈약한 안전지대·낚시 희귀도 무게를 규칙 한 곳에서 읽게 했습니다(바뀌는 수치 없음).'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109060000' where key = 'db_version';
