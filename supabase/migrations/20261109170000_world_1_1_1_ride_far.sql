alter table public.world_travel_party_requests add column if not exists hops smallint;

create or replace function public.world_travel_plan(p_uid uuid, p_dest text, p_lv int)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
DECLARE c public.world_characters%rowtype; here public.world_map_regions%rowtype; dest public.world_map_regions%rowtype;
  ids text[]; xs float8[]; ys float8[]; el float8[]; tc float8[]; terr text[]; lv int[]; lk jsonb[]; d float8[]; prv int[]; done boolean[];
  nn int; i int; u int; v int; best float8; si int; ti int; w float8; speed float8 := 1; path int[] := '{}'; secs float8 := 0; hop float8;
  vis int; fare_per int; fare int := 0; need int := 0; walked boolean := false; names text[] := '{}'; nb text; sk text[]; n_free int := 0;
  oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true); swap boolean;
BEGIN
  SELECT * INTO c FROM public.world_characters WHERE owner_id = p_uid;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  here := public.world_field_region(c.location);
  SELECT * INTO dest FROM public.world_map_regions WHERE region_id = p_dest AND active;
  IF dest.region_id IS NULL THEN RAISE EXCEPTION '지도에 없는 지역입니다.'; END IF;
  IF here.region_id IS NULL THEN RAISE EXCEPTION '지금 있는 곳의 좌표를 알 수 없습니다.'; END IF;
  IF here.region_id = dest.region_id THEN RAISE EXCEPTION '이미 그 지역에 있습니다.'; END IF;
  SELECT array_agg(region_id ORDER BY region_id), array_agg(world_x::float8 ORDER BY region_id), array_agg(world_y::float8 ORDER BY region_id),
         array_agg(coalesce(elevation, 0)::float8 ORDER BY region_id), array_agg(coalesce(terrain_cost, 1)::float8 ORDER BY region_id),
         array_agg(territory_id ORDER BY region_id), array_agg(min_level ORDER BY region_id), array_agg(to_jsonb(coalesce(travel_from, '{}')) ORDER BY region_id)
    INTO ids, xs, ys, el, tc, terr, lv, lk FROM public.world_map_regions WHERE active;
  nn := cardinality(ids);
  si := array_position(ids, here.region_id); ti := array_position(ids, dest.region_id);
  d := array_fill(1e18::float8, ARRAY[nn]); prv := array_fill(0, ARRAY[nn]); done := array_fill(false, ARRAY[nn]);
  d[si] := 0;
  SELECT coalesce(m.speed_multiplier, 1) INTO speed FROM public.world_mount_catalog m WHERE m.mount_id = c.mount_id;
  speed := coalesce(speed, 1) * (1 + 0.04 * coalesce((SELECT o.training FROM public.world_owned_mounts o WHERE o.owner_id = p_uid AND o.mount_id = c.mount_id), 0)) * public.world_river_boat_speed(p_uid, c.mount_id);
  LOOP
    u := NULL; best := 1e18;
    FOR i IN 1..nn LOOP IF NOT done[i] AND d[i] < best THEN best := d[i]; u := i; END IF; END LOOP;
    EXIT WHEN u IS NULL OR u = ti;
    done[u] := true;
    FOR nb IN SELECT jsonb_array_elements_text(lk[u]) LOOP
      v := array_position(ids, nb);
      CONTINUE WHEN v IS NULL OR done[v] OR (lv[v] > p_lv);
      w := (sqrt((xs[u] - xs[v]) ^ 2 + (ys[u] - ys[v]) ^ 2) * 1.4 + abs(el[u] - el[v]) * 6 + 12) * greatest(tc[u], tc[v])
           * CASE WHEN terr[u] IS DISTINCT FROM terr[v] THEN 1.2 ELSE 1 END;
      IF d[u] + w < d[v] THEN d[v] := d[u] + w; prv[v] := u; END IF;
    END LOOP;
  END LOOP;
  IF d[ti] >= 1e17 THEN RAISE EXCEPTION '그곳으로 이어진 길이 없습니다. 레벨이 모자란 지역이 길을 막고 있습니다.'; END IF;
  v := ti;
  WHILE v <> si LOOP path := v || path; v := prv[v]; END LOOP;
  path := si || path;
  SELECT CASE WHEN coalesce(m.fare_free, false) OR public.world_river_boat_member(p_uid, m.mount_id) THEN 0 ELSE greatest(0, coalesce(m.fare_tokens, 1)) END INTO fare_per FROM public.world_mount_catalog m WHERE m.mount_id = c.mount_id;
  sk := public.world_skill_procs(p_uid);
  IF 'tracking_c24b' = ANY (sk) AND coalesce(fare_per, 0) > 0 THEN SELECT count(*) INTO n_free FROM generate_series(1, cardinality(path) - 1) WHERE random() < 0.1; END IF;
  fare := coalesce(fare_per, 0) * (cardinality(path) - 1 - n_free);
  need := fare;
  IF fare > 0 AND c.mount_tokens < fare THEN speed := 1; walked := true; fare := 0; n_free := 0; END IF;
  IF (walked OR c.mount_id IS NULL) AND 'tracking_c43b' = ANY (sk) THEN speed := speed / 0.75; END IF;
  FOR i IN 2..cardinality(path) LOOP
    hop := (sqrt((xs[path[i - 1]] - xs[path[i]]) ^ 2 + (ys[path[i - 1]] - ys[path[i]]) ^ 2) * 1.4 + abs(el[path[i - 1]] - el[path[i]]) * 6 + 12)
           * greatest(tc[path[i - 1]], tc[path[i]]) * CASE WHEN terr[path[i - 1]] IS DISTINCT FROM terr[path[i]] THEN 1.2 ELSE 1 END / speed;
    SELECT coalesce(visits, 0) INTO vis FROM public.world_region_intel WHERE owner_id = p_uid AND region_id = ids[path[i]];
    hop := hop * (1 - least(0.3, coalesce(vis, 0) * 0.06));
    secs := secs + greatest(12, hop);
    names := names || (SELECT region_name FROM public.world_map_regions WHERE region_id = ids[path[i]]);
  END LOOP;
  IF cardinality(path) > 2 THEN secs := secs * 0.9; END IF;
  swap := public.fn_owner_auth_uid() IS DISTINCT FROM p_uid;
  IF swap THEN
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  END IF;
  secs := secs * greatest(0.5, 1 + public.world_status_effect_total('travel_time_pct') / 100.0 + least(0, public.world_title_bonus('travel_time_pct')) / 100.0);
  IF swap THEN
    PERFORM set_config('request.jwt.claims', coalesce(oc, ''), true);
    PERFORM set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  END IF;
  secs := greatest(12, least(10800, secs));
  RETURN jsonb_build_object('hops', cardinality(path) - 1, 'secs', secs, 'names', to_jsonb(names), 'fare', fare, 'need', need, 'fare_per', coalesce(fare_per, 0),
    'n_free', n_free, 'walked', walked, 'mount_id', c.mount_id);
END $function$;

grant create on schema public to fn_owner_field;
alter function public.world_travel_plan(uuid, text, int) owner to fn_owner_field;
revoke create on schema public from fn_owner_field;
set role fn_owner_field;
revoke all on function public.world_travel_plan(uuid, text, int) from public, anon, authenticated;
grant execute on function public.world_travel_plan(uuid, text, int) to service_role, fn_owner_party_invite_v2, fn_owner_party_respond_v2;
grant execute on function public.world_durability_wear(uuid, text, integer) to fn_owner_party_respond_v2;
grant execute on function public.world_seal_guard() to fn_owner_party_respond_v2;
reset role;
grant update (mount_tokens, current_exploration_node_id) on public.world_characters to fn_owner_party_respond_v2;
grant select (owner_id, cancelled_at) on public.world_travel_history to fn_owner_party_respond_v2;
grant select (hops), insert (hops) on public.world_travel_party_requests to fn_owner_party_invite_v2;
grant select (hops), update (hops) on public.world_travel_party_requests to fn_owner_party_respond_v2;

CREATE OR REPLACE FUNCTION public.world_travel_route(p_region_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; here public.world_map_regions%rowtype; dest public.world_map_regions%rowtype;
  pl jsonb; hops int; secs float8; fare int; walked boolean; n_free int; names text[]; arrives timestamptz; fee int;
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
  pl := public.world_travel_plan(uid, dest.region_id, c.level);
  hops := (pl ->> 'hops')::int; secs := (pl ->> 'secs')::float8; fare := (pl ->> 'fare')::int; walked := (pl ->> 'walked')::boolean; n_free := (pl ->> 'n_free')::int;
  names := array(SELECT jsonb_array_elements_text(pl -> 'names'));
  fee := 5 * hops;
  IF c.gil < fee THEN RAISE EXCEPTION '%', format('여행 준비금 %s전이 필요합니다.', fee); END IF;
  PERFORM public.world_durability_wear(uid, 'shoes', hops); arrives := now() + make_interval(secs => round(secs));
  UPDATE public.world_characters SET gil = gil - fee, mount_tokens = mount_tokens - fare, travel_destination = dest.region_name, travel_arrives_at = arrives,
    current_exploration_node_id = NULL, updated_at = now() WHERE owner_id = uid;
  INSERT INTO public.world_travel_history(owner_id, from_region, to_region, arrives_at, fare_exempt) VALUES (uid, c.location, dest.region_name, arrives, true);
  IF fare > 0 THEN INSERT INTO public.world_economy_ledger(owner_id, action, currency_delta, sink, details) VALUES (uid, 'mount_fare', -fare, true, jsonb_build_object('mount_id', c.mount_id, 'to', dest.region_name, 'hops', hops)); END IF;
  INSERT INTO public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  VALUES (uid, 'travel_fee', -fee, true, jsonb_build_object('to', dest.region_id, 'hops', hops, 'seconds', round(secs)));
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'travel', '출발: ' || dest.region_name || CASE WHEN hops > 1 THEN ' (' || hops || '구간)' ELSE '' END,
    jsonb_build_object('region_id', dest.region_id, 'region_name', dest.region_name, 'arrives_at', arrives, 'travel_seconds', round(secs), 'route', to_jsonb(names), 'mount', CASE WHEN walked THEN NULL ELSE c.mount_id END, 'fare_tokens', fare, 'walked', walked));
  RETURN jsonb_build_object('ok', true, 'content', dest.region_name || '(으)로 출발했습니다. ' || CASE WHEN n_free > 0 THEN '「샛길」 ' || n_free || '구간은 운임 없이 지납니다. ' ELSE '' END || CASE WHEN walked THEN '노정패가 모자라 탈것에서 내려 걸어갑니다. ' WHEN fare > 0 THEN '노정패 ' || fare || '개를 냈습니다. ' ELSE '' END || CASE WHEN hops > 1 THEN array_to_string(names, ' › ') || ' · ' ELSE '' END
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
  pl jsonb;
  v_hops int;
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

  IF r.region_id IS NULL OR oldr.region_id IS NULL OR r.region_id = oldr.region_id THEN
    RAISE EXCEPTION '목적지가 연결된 경로가 아닙니다.';
  END IF;

  IF NOT (public.world_domain_open(uid, r.territory_id) AND public.world_domain_open(p_passenger_id, r.territory_id)) THEN
    RAISE EXCEPTION '%', coalesce(public.world_domain_rules() -> r.territory_id ->> 'name', '그 영역') || '은(는) 둘 다 길이 열린 뒤에 함께 건너갈 수 있습니다.';
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

  pl := public.world_travel_plan(uid, r.region_id, least(c.level, p.level));
  v_hops := (pl ->> 'hops')::int;

  IF EXISTS (
    SELECT 1 FROM public.world_travel_party_requests q
    WHERE q.leader_id = uid AND q.passenger_id = p_passenger_id
      AND q.status = 'pending'
  ) THEN
    RAISE EXCEPTION '이미 처리 대기 중인 동승 요청이 있습니다.';
  END IF;

  INSERT INTO public.world_travel_party_requests
    (leader_id, passenger_id, from_region, to_region, status, hops)
  VALUES (uid, p_passenger_id, oldr.region_id, p_region_id, 'pending', v_hops)
  RETURNING request_id INTO rid;

  INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
  VALUES (p_passenger_id, 'ride_request', '동승 요청',
    coalesce((SELECT x.character_name FROM public.world_characters x WHERE x.owner_id = uid), '동료') || '이(가) '
      || r.region_name || '(으)로 함께 가자고 합니다'
      || CASE WHEN v_hops > 1 THEN '(' || v_hops || '구간)' ELSE '' END || '. 운임은 파티장이 냅니다.',
    jsonb_build_object('request_id', rid, 'from_id', uid, 'to_region', p_region_id, 'hops', v_hops));

  RETURN jsonb_build_object(
    'ok', true,
    'request_id', rid,
    'hops', v_hops,
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
 pl jsonb; v_hops int; secs float8; fare int; fee int; names text[]; cd_s text;
 arrive timestamptz; pid uuid;
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
 perform public.world_seal_guard();

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
 if exists(select 1 from public.world_travel_history h where h.owner_id=uid and h.cancelled_at>now()-interval '3 minutes') then
   cd_s:=ceil(extract(epoch from (select max(h.cancelled_at) from public.world_travel_history h where h.owner_id=uid)+interval '3 minutes'-now()))::text;
   raise exception using message=format('이동을 취소한 뒤 3분 동안은 다시 출발할 수 없습니다(%s초 남음).', cd_s), hint='cd:'||cd_s;
 end if;

 select * into r from public.world_map_regions where region_id=q.to_region and active;
 select * into oldr from public.world_map_regions
   where region_name=c.location or region_id=c.location
      or (c.location in ('야행국 본부 · 정청','야행국 본부 정청','본부 로비')
          and region_id='hq_yard')
   limit 1;
 if r.region_id is null or oldr.region_id is null or oldr.region_id<>q.from_region
   then raise exception '목적지 경로가 만료되었습니다.'; end if;
 if c.mount_id is null or not exists(
     select 1 from public.world_mount_catalog m
     join public.world_owned_mounts om on om.mount_id=m.mount_id and om.owner_id=q.leader_id
     where m.mount_id=c.mount_id and m.passenger_capacity>=2)
   then raise exception '출발자의 탈것이 동승 조건을 충족하지 않습니다.'; end if;
 if c.level<r.min_level or p.level<r.min_level
   then raise exception '동승자 모두 목적지의 최소 레벨을 충족해야 합니다.'; end if;
 if not (public.world_domain_open(q.leader_id, r.territory_id) and public.world_domain_open(uid, r.territory_id))
   then raise exception '%', coalesce(public.world_domain_rules() -> r.territory_id ->> 'name', '그 영역') || '은(는) 둘 다 길이 열린 뒤에 함께 건너갈 수 있습니다.'; end if;

 pl:=public.world_travel_plan(q.leader_id, r.region_id, least(c.level, p.level));
 if (pl->>'walked')::boolean
   then raise exception '노정패가 모자라 함께 떠날 수 없습니다(운임 %개).', pl->>'need'; end if;
 v_hops:=(pl->>'hops')::int; secs:=(pl->>'secs')::float8; fare:=(pl->>'fare')::int;
 names:=array(select jsonb_array_elements_text(pl->'names'));
 fee:=5*v_hops;
 if c.gil<fee or p.gil<fee
   then raise exception '%', format('두 사람 모두 여행 준비금 %s전을 보유해야 합니다.', fee); end if;
 arrive:=now()+make_interval(secs=>round(secs));

 perform public.world_durability_wear(q.leader_id, 'shoes', v_hops);
 perform public.world_durability_wear(uid, 'shoes', v_hops);
 update public.world_characters
   set gil=gil-fee, mount_tokens=mount_tokens-case when owner_id=q.leader_id then fare else 0 end,
       travel_destination=r.region_name, travel_arrives_at=arrive, current_exploration_node_id=null, updated_at=now()
 where owner_id in (q.leader_id,uid);

 insert into public.world_travel_history(owner_id,from_region,to_region,arrives_at,passenger_count,fare_exempt)
   values(q.leader_id, c.location, r.region_name, arrive, 2, true),
         (uid,         p.location, r.region_name, arrive, 2, true);

 if fare>0 then
   insert into public.world_economy_ledger(owner_id,action,currency_delta,sink,details)
     values(q.leader_id,'mount_fare',-fare,true,jsonb_build_object('mount_id',c.mount_id,'to',r.region_name,'hops',v_hops,'party',q.request_id));
 end if;
 insert into public.world_economy_ledger(owner_id,action,currency_delta,sink,details)
   values(q.leader_id,'travel_fee',-fee,true,
          jsonb_build_object('to',q.to_region,'hops',v_hops,'seconds',round(secs),'party',q.request_id)),
         (uid,'travel_fee',-fee,true,
          jsonb_build_object('to',q.to_region,'hops',v_hops,'seconds',round(secs),'party',q.request_id));

 update public.world_travel_party_requests
   set status='departed', responded_at=now(), departed_at=now(), hops=v_hops
 where request_id=q.request_id;

 insert into public.world_events(actor_id,actor_name,event_type,content,payload)
   values(q.leader_id, c.character_name, 'travel',
          '동승 출발: '||r.region_name||case when v_hops>1 then ' ('||v_hops||'구간)' else '' end,
          jsonb_build_object(
            'region_id',r.region_id,'region_name',r.region_name,
            'arrives_at',arrive,'travel_seconds',round(secs),'passenger_id',uid,
            'route',to_jsonb(names),'mount',c.mount_id,'fare_tokens',fare,'hops',v_hops));

 return jsonb_build_object(
   'ok',true,
   'content','동승 수락 완료. 두 조사원이 함께 출발했습니다. 목적지: '||r.region_name
     ||case when v_hops>1 then ' · '||array_to_string(names,' › ') else '' end
     ||case when fare>0 then ' · 파티장이 노정패 '||fare||'개를 냈습니다' else '' end
     ||' · 약 '||case when secs>=3600 then floor(secs/3600)||'시간 ' else '' end||ceil(mod(secs::numeric,3600)/60)||'분 뒤 도착합니다.',
   'region_id',r.region_id,'region_name',r.region_name,'route',to_jsonb(names),'hops',v_hops,
   'arrives_at',arrive,'travel_seconds',round(secs),'fare_tokens',fare);
end
$function$;

CREATE OR REPLACE FUNCTION public.world_travel_party_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; pid uuid;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select * into c from public.world_characters where owner_id=uid;
 select party_id into pid from public.world_party_members where owner_id=uid;
 return jsonb_build_object(
  'location',c.location,
  'party_id',pid,
  'passengers',(select coalesce(jsonb_agg(jsonb_build_object('owner_id',x.owner_id,'character_name',x.character_name,'level',x.level)), '[]'::jsonb)
   from public.world_characters x join public.world_party_members xm on xm.owner_id=x.owner_id
   where x.owner_id<>uid and xm.party_id=pid and pid is not null and x.location=c.location and x.travel_arrives_at is null and x.health>0 and x.downed_at is null
    and not exists(select 1 from public.world_active_encounters e where e.owner_id=x.owner_id and not e.defeated and not coalesce(e.fled,false))),
  'requests',(select coalesce(jsonb_agg(jsonb_build_object('request_id',q.request_id,'leader_id',q.leader_id,'passenger_id',q.passenger_id,'to_region',q.to_region,
     'to_name',(select mr.region_name from public.world_map_regions mr where mr.region_id=q.to_region),'hops',q.hops,'status',q.status,'created_at',q.created_at)), '[]'::jsonb)
   from public.world_travel_party_requests q where (q.leader_id=uid or q.passenger_id=uid) and q.status in ('pending','departed'))
 );
end $function$;

update public.world_app_meta set value = '20261109170000' where key = 'db_version';
