alter table public.world_travel_party_requests add column if not exists group_id uuid;
create index if not exists idx_world_travel_party_requests_group on public.world_travel_party_requests(group_id) where group_id is not null;

create or replace function public.world_ride_rules() returns jsonb language sql immutable set search_path = pg_catalog, public as $f$ select '{"wait_s": 60, "stale_s": 300}'::jsonb $f$;

create or replace function public.world_ride_expire(p_a uuid, p_b uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public as $f$
begin
  update public.world_travel_party_requests q set status = 'cancelled', cancelled_at = now()
   where (q.leader_id in (p_a, p_b) or q.passenger_id in (p_a, p_b))
     and ((q.status = 'pending' and q.created_at < now() - make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int))
       or (q.status = 'accepted' and q.created_at < now() - make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int + (public.world_ride_rules() ->> 'stale_s')::int)));
end $f$;

create or replace function public.world_ride_supersede(p_uid uuid, p_passenger uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public as $f$
declare x record; nm text := coalesce((select character_name from public.world_characters where owner_id = p_uid), '동료');
  g uuid := nullif(current_setting('yh.ride_group', true), '')::uuid;
begin
  for x in select q.request_id, q.leader_id, q.passenger_id from public.world_travel_party_requests q
     where q.status = 'pending' and (q.leader_id in (p_uid, p_passenger) or q.passenger_id in (p_uid, p_passenger))
       and (g is null or q.group_id is distinct from g) for update loop
    update public.world_travel_party_requests set status = 'cancelled', cancelled_at = now() where request_id = x.request_id;
    update public.world_notifications set read_at = now()
     where user_id = x.passenger_id and kind = 'ride_request' and read_at is null and payload ->> 'request_id' = x.request_id::text;
    if x.leader_id <> p_uid then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (x.leader_id, 'ride_declined', '동승 요청 취소',
        nm || '의 동승 요청이 나중에 들어와, 보낸 동승 요청은 취소되었습니다.',
        jsonb_build_object('request_id', x.request_id, 'superseded', true));
    end if;
  end loop;
end $f$;

create or replace function pg_temp.rf(p_fn regprocedure, p_pairs text[]) returns void language plpgsql as $g$
declare src text := pg_get_functiondef(p_fn); i int; n int;
begin
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(src) - length(replace(src, p_pairs[2 * i - 1], ''))) / greatest(length(p_pairs[2 * i - 1]), 1);
    if n <> 1 then raise exception '% 조각 %: % 번 나옴', p_fn, i, n; end if;
    src := replace(src, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute src;
end $g$;

select pg_temp.rf('public.world_travel_party_invite_v2(uuid, text)', array[
$o$  SELECT max(q.created_at) INTO wait_at FROM public.world_travel_party_requests q WHERE q.leader_id = uid AND q.status = 'pending';$o$,
$n$  SELECT max(q.created_at) INTO wait_at FROM public.world_travel_party_requests q WHERE q.leader_id = uid AND q.status = 'pending'
     AND q.group_id IS DISTINCT FROM nullif(current_setting('yh.ride_group', true), '')::uuid;$n$,
$o$    (leader_id, passenger_id, from_region, to_region, status, hops)
  VALUES (uid, p_passenger_id, oldr.region_id, p_region_id, 'pending', v_hops)$o$,
$n$    (leader_id, passenger_id, from_region, to_region, status, hops, group_id)
  VALUES (uid, p_passenger_id, oldr.region_id, p_region_id, 'pending', v_hops, nullif(current_setting('yh.ride_group', true), '')::uuid)$n$,
$o$    jsonb_build_object('request_id', rid, 'from_id', uid, 'to_region', p_region_id, 'hops', v_hops,$o$,
$n$    jsonb_build_object('request_id', rid, 'from_id', uid, 'to_region', p_region_id, 'hops', v_hops,
      'group_id', nullif(current_setting('yh.ride_group', true), ''),$n$]);

create or replace function public.world_ride_go(p_leader uuid, p_reqs uuid[], p_caller uuid, p_strict boolean) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $f$
declare
  c public.world_characters%rowtype; p public.world_characters%rowtype;
  r public.world_map_regions%rowtype; oldr public.world_map_regions%rowtype;
  q record; ok_q uuid[] := '{}'; ok_p uuid[] := '{}'; drop_q uuid[] := '{}'; why text;
  cap int; lv int; pl jsonb; v_hops int; secs float8; fare int; fee int; names text[]; arrive timestamptz;
  pid uuid; n int; first_q record; i int; nm text; cd_s text;
begin
  perform 1 from public.world_characters where owner_id = p_leader
     or owner_id in (select x.passenger_id from public.world_travel_party_requests x where x.request_id = any(p_reqs))
   order by owner_id for update;
  select * into c from public.world_characters where owner_id = p_leader;
  select * into first_q from public.world_travel_party_requests where request_id = any(p_reqs) order by responded_at nulls last, created_at limit 1;
  if c.owner_id is null or first_q.request_id is null then raise exception '유효한 동승 요청이 없습니다.'; end if;
  select party_id into pid from public.world_party_members where owner_id = p_leader;
  select * into r from public.world_map_regions where region_id = first_q.to_region and active;
  select * into oldr from public.world_map_regions
   where region_name = c.location or region_id = c.location
      or (c.location in ('야행국 본부 · 정청','야행국 본부 정청','본부 로비') and region_id = 'hq_yard')
   limit 1;
  select m.passenger_capacity into cap from public.world_mount_catalog m
    join public.world_owned_mounts om on om.mount_id = m.mount_id and om.owner_id = p_leader
   where m.mount_id = c.mount_id;

  why := case
    when c.health <= 0 or c.downed_at is not null then '전투불능 상태에서는 동승할 수 없습니다.'
    when exists (select 1 from public.world_active_encounters e where e.owner_id = p_leader and not e.defeated and not coalesce(e.fled, false))
      then '전투 중에는 이동할 수 없습니다. 전투를 먼저 마치세요.'
    when pid is null then '같은 파티원이 아니므로 동승할 수 없습니다.'
    when c.travel_arrives_at is not null then '출발 위치가 변경되었거나 한 명이 이동 중입니다.'
    when r.region_id is null or oldr.region_id is null or oldr.region_id <> first_q.from_region then '목적지 경로가 만료되었습니다.'
    when coalesce(cap, 0) < 2 then '출발자의 탈것이 동승 조건을 충족하지 않습니다.'
    when c.level < r.min_level then '동승자 모두 목적지의 최소 레벨을 충족해야 합니다.'
    else null end;
  if why is not null then
    if p_strict then raise exception '%', why; end if;
    update public.world_travel_party_requests set status = 'cancelled', cancelled_at = now() where request_id = any(p_reqs) and status in ('pending', 'accepted');
    insert into public.world_notifications(user_id, kind, title, content, payload)
    select x.passenger_id, 'ride_declined', '동승 취소', c.character_name || '이(가) 지금 떠날 수 없어 동승이 취소되었습니다. ' || why, jsonb_build_object('request_id', x.request_id, 'group_id', x.group_id)
      from public.world_travel_party_requests x where x.request_id = any(p_reqs) and x.passenger_id <> p_caller;
    return jsonb_build_object('ok', false, 'content', '동승이 취소되었습니다. ' || why);
  end if;

  for q in select x.* from public.world_travel_party_requests x where x.request_id = any(p_reqs) order by x.responded_at nulls last, x.created_at loop
    select * into p from public.world_characters where owner_id = q.passenger_id;
    cd_s := null;
    if exists (select 1 from public.world_travel_history h where h.owner_id = q.passenger_id and h.cancelled_at > now() - interval '3 minutes') then
      cd_s := ceil(extract(epoch from (select max(h.cancelled_at) from public.world_travel_history h where h.owner_id = q.passenger_id) + interval '3 minutes' - now()))::text;
    end if;
    why := case
      when p.owner_id is null then '캐릭터 정보를 찾을 수 없습니다.'
      when p.health <= 0 or p.downed_at is not null then '전투불능 상태에서는 동승할 수 없습니다.'
      when exists (select 1 from public.world_active_encounters e where e.owner_id = q.passenger_id and not e.defeated and not coalesce(e.fled, false))
        then '전투 중에는 이동할 수 없습니다. 전투를 먼저 마치세요.'
      when not exists (select 1 from public.world_party_members where owner_id = q.passenger_id and party_id = pid) then '같은 파티원이 아니므로 동승할 수 없습니다.'
      when p.travel_arrives_at is not null or p.location <> c.location then '출발 위치가 변경되었거나 한 명이 이동 중입니다.'
      when cd_s is not null then format('이동을 취소한 뒤 3분 동안은 다시 출발할 수 없습니다(%s초 남음).', cd_s)
      when p.level < r.min_level then '동승자 모두 목적지의 최소 레벨을 충족해야 합니다.'
      when not (public.world_domain_open(p_leader, r.territory_id) and public.world_domain_open(q.passenger_id, r.territory_id)
                and public.world_region_open(p_leader, r.region_id) and public.world_region_open(q.passenger_id, r.region_id))
        then coalesce(public.world_domain_rules() -> r.territory_id ->> 'name', '그 영역') || '은(는) 둘 다 길이 열린 뒤에 함께 건너갈 수 있습니다.'
      when cardinality(ok_p) + 2 > cap then format('탈것 정원(%s명)이 다 찼습니다.', cap)
      else null end;
    if why is not null and p_strict then
      if cd_s is not null then raise exception using message = why, hint = 'cd:' || cd_s; end if;
      raise exception '%', why;
    end if;
    if why is null then ok_q := ok_q || q.request_id; ok_p := ok_p || q.passenger_id;
    else
      drop_q := drop_q || q.request_id;
      if q.passenger_id <> p_caller then
        insert into public.world_notifications(user_id, kind, title, content, payload)
        values (q.passenger_id, 'ride_declined', '동승에서 빠짐', '출발할 때 조건이 맞지 않아 함께 떠나지 못했습니다. ' || why, jsonb_build_object('request_id', q.request_id, 'group_id', q.group_id));
      end if;
    end if;
  end loop;
  if drop_q <> '{}' then update public.world_travel_party_requests set status = 'cancelled', cancelled_at = now() where request_id = any(drop_q); end if;
  n := cardinality(ok_p);
  if n = 0 then
    update public.world_travel_party_requests set status = 'cancelled', cancelled_at = now() where request_id = any(p_reqs) and status in ('pending', 'accepted');
    return jsonb_build_object('ok', false, 'content', '함께 떠날 수 있는 파티원이 없어 동승이 취소되었습니다.');
  end if;

  select least(c.level, min(x.level)) into lv from public.world_characters x where x.owner_id = any(ok_p);
  pl := public.world_travel_plan(p_leader, r.region_id, lv);
  v_hops := (pl ->> 'hops')::int; secs := (pl ->> 'secs')::float8; fare := (pl ->> 'fare')::int;
  names := array(select jsonb_array_elements_text(pl -> 'names'));
  fee := 5 * v_hops;
  why := case
    when (pl ->> 'walked')::boolean then format('노정패가 모자라 함께 떠날 수 없습니다(운임 %s개).', pl ->> 'need')
    when c.gil < fee or exists (select 1 from public.world_characters x where x.owner_id = any(ok_p) and x.gil < fee)
      then format('함께 가는 사람 모두 여행 준비금 %s전을 보유해야 합니다.', fee)
    else null end;
  if why is not null then
    if p_strict then raise exception '%', why; end if;
    update public.world_travel_party_requests set status = 'cancelled', cancelled_at = now() where request_id = any(p_reqs) and status in ('pending', 'accepted');
    insert into public.world_notifications(user_id, kind, title, content, payload)
    select u, 'ride_declined', '동승 취소', '동승이 취소되었습니다. ' || why, jsonb_build_object('group_id', first_q.group_id)
      from unnest(ok_p || p_leader) u where u <> p_caller;
    return jsonb_build_object('ok', false, 'content', '동승이 취소되었습니다. ' || why);
  end if;
  arrive := now() + make_interval(secs => round(secs));

  perform public.world_durability_wear(p_leader, 'shoes', v_hops);
  for i in 1 .. n loop perform public.world_durability_wear(ok_p[i], 'shoes', v_hops); end loop;
  update public.world_characters
     set gil = gil - fee, mount_tokens = mount_tokens - case when owner_id = p_leader then fare else 0 end,
         travel_destination = r.region_name, travel_arrives_at = arrive, current_exploration_node_id = null, updated_at = now()
   where owner_id = p_leader or owner_id = any(ok_p);

  insert into public.world_travel_history(owner_id, from_region, to_region, arrives_at, passenger_count, fare_exempt)
  select u, c.location, r.region_name, arrive, n + 1, true from unnest(p_leader || ok_p) u;

  if fare > 0 then
    insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
    values (p_leader, 'mount_fare', -fare, true, jsonb_build_object('mount_id', c.mount_id, 'to', r.region_name, 'hops', v_hops, 'party', first_q.request_id));
  end if;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  select u, 'travel_fee', -fee, true, jsonb_build_object('to', first_q.to_region, 'hops', v_hops, 'seconds', round(secs), 'party', first_q.request_id)
    from unnest(p_leader || ok_p) u;

  update public.world_travel_party_requests set status = 'departed', responded_at = coalesce(responded_at, now()), departed_at = now(), hops = v_hops
   where request_id = any(ok_q);

  nm := (select string_agg(x.character_name, ', ' order by array_position(ok_p, x.owner_id)) from public.world_characters x where x.owner_id = any(ok_p));
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select u, 'ride_departed', '동승 출발',
    case when u = p_leader then nm || '이(가) 동승을 받아 함께 출발했습니다. '
         else c.character_name || '의 탈것으로 함께 출발했습니다. ' end
      || r.region_name || '까지 약 '
      || case when secs >= 3600 then floor(secs / 3600) || '시간 ' else '' end || ceil(mod(secs::numeric, 3600) / 60) || '분.',
    jsonb_build_object('request_id', first_q.request_id, 'group_id', first_q.group_id, 'region_id', r.region_id, 'arrives_at', arrive)
    from unnest(p_leader || ok_p) u where u <> p_caller and (u = p_leader or first_q.group_id is not null);

  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (p_leader, c.character_name, 'travel',
    '동승 출발: ' || r.region_name || case when v_hops > 1 then ' (' || v_hops || '구간)' else '' end,
    jsonb_build_object('region_id', r.region_id, 'region_name', r.region_name, 'arrives_at', arrive, 'travel_seconds', round(secs),
      'passenger_id', ok_p[1], 'passenger_ids', to_jsonb(ok_p), 'route', to_jsonb(names), 'mount', c.mount_id, 'fare_tokens', fare, 'hops', v_hops));

  return jsonb_build_object(
    'ok', true,
    'content', case when first_q.group_id is null then '동승 수락 완료. ' else '' end || case when n = 1 then '두' else (n + 1)::text || '명의' end || ' 조사원이 함께 출발했습니다. 목적지: ' || r.region_name
      || case when v_hops > 1 then ' · ' || array_to_string(names, ' › ') else '' end
      || case when fare > 0 then ' · ' || c.character_name || '이(가) 노정패 ' || fare || '개를 냈습니다' else '' end
      || ' · 약 ' || case when secs >= 3600 then floor(secs / 3600) || '시간 ' else '' end || ceil(mod(secs::numeric, 3600) / 60) || '분 뒤 도착합니다.',
    'region_id', r.region_id, 'region_name', r.region_name, 'route', to_jsonb(names), 'hops', v_hops,
    'arrives_at', arrive, 'travel_seconds', round(secs), 'fare_tokens', fare, 'departed', n + 1);
end $f$;

create or replace function public.world_ride_group_left(p_group uuid) returns int
language sql stable security definer set search_path = pg_catalog, public as $f$
  select count(*)::int from public.world_travel_party_requests where group_id = p_group and status = 'pending'
     and created_at >= now() - make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int)
$f$;

create or replace function public.world_ride_group_go(p_group uuid, p_caller uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $f$
declare ld uuid; ids uuid[];
begin
  update public.world_travel_party_requests set status = 'cancelled', cancelled_at = now() where group_id = p_group and status = 'pending';
  update public.world_notifications nt set read_at = now()
   where nt.kind = 'ride_request' and nt.read_at is null and nt.payload ->> 'group_id' = p_group::text;
  select min(leader_id::text)::uuid, array_agg(request_id order by responded_at) into ld, ids
    from public.world_travel_party_requests where group_id = p_group and status = 'accepted';
  if ids is null then return jsonb_build_object('ok', false, 'content', '함께 타기로 한 파티원이 없어 동승 요청을 거두었습니다.'); end if;
  return public.world_ride_go(ld, ids, p_caller, false);
end $f$;

create or replace function public.world_travel_party_invite_all(p_region_id text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $f$
declare
  uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; pid uuid; cap int;
  g uuid := gen_random_uuid(); m record; sent text[] := '{}'; skipped jsonb := '[]'; first_msg text; first_hint text;
  e_msg text; e_hint text; wait_s int := (public.world_ride_rules() ->> 'wait_s')::int; n int;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select party_id into pid from public.world_party_members where owner_id = uid;
  if pid is null then raise exception '같은 파티원에게만 동승을 요청할 수 있습니다.'; end if;
  perform 1 from public.world_characters where owner_id in (select owner_id from public.world_party_members where party_id = pid) order by owner_id for update;
  select * into c from public.world_characters where owner_id = uid;
  select m2.passenger_capacity into cap from public.world_mount_catalog m2
    join public.world_owned_mounts om on om.mount_id = m2.mount_id and om.owner_id = uid
   where m2.mount_id = c.mount_id;
  select count(*) into n from public.world_characters x join public.world_party_members xm on xm.owner_id = x.owner_id
   where xm.party_id = pid and x.owner_id <> uid and x.location = c.location and x.travel_arrives_at is null and x.health > 0 and x.downed_at is null;
  if n = 0 then raise exception '같은 곳에 있는 파티원이 없습니다.'; end if;
  if coalesce(cap, 0) < 2 then raise exception '탑승 정원 2명 이상의 보유 탈것을 장착해야 합니다.'; end if;
  if n + 1 > cap then
    raise exception '%', format('탈것 정원이 %s명이라 같은 곳의 파티원 %s명을 모두 태울 수 없습니다. 한 사람씩 동승을 요청하세요.', cap, n);
  end if;
  perform set_config('yh.ride_group', g::text, true);
  for m in select x.owner_id, x.character_name from public.world_characters x join public.world_party_members xm on xm.owner_id = x.owner_id
            where xm.party_id = pid and x.owner_id <> uid and x.location = c.location and x.travel_arrives_at is null and x.health > 0 and x.downed_at is null
            order by x.character_name loop
    begin
      perform public.world_travel_party_invite_v2(m.owner_id, p_region_id);
      sent := sent || m.character_name;
    exception when others then
      get stacked diagnostics e_msg = message_text, e_hint = pg_exception_hint;
      if first_msg is null then first_msg := e_msg; first_hint := e_hint; end if;
      skipped := skipped || jsonb_build_object('name', m.character_name, 'why', e_msg);
    end;
  end loop;
  perform set_config('yh.ride_group', '', true);
  if cardinality(sent) = 0 then
    raise exception using message = coalesce(first_msg, '동승을 요청할 수 있는 파티원이 없습니다.'), hint = coalesce(first_hint, '');
  end if;
  return jsonb_build_object('ok', true, 'group_id', g, 'sent', to_jsonb(sent), 'skipped', skipped,
    'expires_at', now() + make_interval(secs => wait_s),
    'content', array_to_string(sent, ', ') || '에게 동승 요청을 보냈습니다. 모두 답하거나 ' || wait_s || '초가 지나면 수락한 사람과 함께 출발합니다.'
      || case when jsonb_array_length(skipped) > 0 then ' 요청하지 못한 파티원: '
         || (select string_agg(s ->> 'name', ', ') from jsonb_array_elements(skipped) s) || '.' else '' end);
end $f$;

create or replace function public.world_travel_party_depart(p_group uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid(); ld uuid; t0 timestamptz; mine text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform 1 from public.world_characters where owner_id in (
      select leader_id from public.world_travel_party_requests where group_id = p_group
      union select passenger_id from public.world_travel_party_requests where group_id = p_group) order by owner_id for update;
  select min(leader_id::text)::uuid, min(created_at) into ld, t0 from public.world_travel_party_requests where group_id = p_group;
  select status into mine from public.world_travel_party_requests where group_id = p_group and passenger_id = uid;
  if ld is null or (ld <> uid and mine is null) then raise exception '유효한 동승 요청이 없습니다.'; end if;
  if not exists (select 1 from public.world_travel_party_requests where group_id = p_group and status in ('pending', 'accepted')) then
    return jsonb_build_object('ok', true, 'done', true, 'content', '이미 출발했거나 끝난 동승 요청입니다.');
  end if;
  if ld <> uid then
    if mine <> 'accepted' then return jsonb_build_object('ok', true, 'done', true, 'content', '이 동승 요청에서 함께 타기로 하지 않았습니다.'); end if;
    if public.world_ride_group_left(p_group) > 0 then
      raise exception '%', '아직 답을 기다리는 파티원이 있습니다. 모두 답하거나 시간이 지나면 출발합니다.';
    end if;
  end if;
  return public.world_ride_group_go(p_group, uid);
end $f$;

create or replace function public.world_travel_party_respond_v2(p_request_id uuid, p_accept boolean)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare
 uid uuid:=public.fn_owner_auth_uid();
 q public.world_travel_party_requests%rowtype;
 nm text;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select * into q from public.world_travel_party_requests where request_id=p_request_id;
 if q.request_id is not null and q.passenger_id=uid then
   if q.group_id is null then
     perform 1 from public.world_characters where owner_id in (q.leader_id, uid) order by owner_id for update;
   else
     perform 1 from public.world_characters where owner_id in (
       select leader_id from public.world_travel_party_requests where group_id = q.group_id
       union select passenger_id from public.world_travel_party_requests where group_id = q.group_id) order by owner_id for update;
   end if;
 end if;
 select * into q from public.world_travel_party_requests where request_id=p_request_id for update;
 if q.request_id is null or q.passenger_id<>uid
   then raise exception '유효한 동승 요청이 없습니다.'; end if;
 if q.status='cancelled'
   then raise exception '취소된 동승 요청입니다. 더 나중에 들어온 동승 요청이 있거나 답할 시간이 지났습니다.'; end if;
 if q.status<>'pending'
   then raise exception '이미 답한 동승 요청입니다.'; end if;
 nm := coalesce((select character_name from public.world_characters where owner_id = uid), '파티원');
 if not p_accept then
   update public.world_travel_party_requests
     set status='declined', responded_at=now()
   where request_id=q.request_id;
   insert into public.world_notifications(user_id, kind, title, content, payload)
   values (q.leader_id, 'ride_declined', '동승 거절',
     nm || '이(가) 동승 요청을 사양했습니다.',
     jsonb_build_object('request_id', q.request_id, 'group_id', q.group_id));
   if q.group_id is not null and public.world_ride_group_left(q.group_id) = 0
      and exists (select 1 from public.world_travel_party_requests where group_id = q.group_id and status = 'accepted') then
     perform public.world_ride_group_go(q.group_id, uid);
   end if;
   return jsonb_build_object('ok',true,'content','동승 요청을 거절했습니다.');
 end if;
 perform public.world_seal_guard();
 if q.created_at < now() - make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int)
   then raise exception '%', '동승 요청에 답할 시간(' || (public.world_ride_rules() ->> 'wait_s') || '초)이 지났습니다.' using hint = 'ride_expired'; end if;
 if q.group_id is null then
   return public.world_ride_go(q.leader_id, array[q.request_id], uid, true);
 end if;
 update public.world_travel_party_requests set status='accepted', responded_at=now() where request_id=q.request_id;
 if public.world_ride_group_left(q.group_id) = 0 then
   return public.world_ride_group_go(q.group_id, uid);
 end if;
 insert into public.world_notifications(user_id, kind, title, content, payload)
 values (q.leader_id, 'ride_accepted', '동승 수락', nm || '이(가) 함께 타기로 했습니다.',
   jsonb_build_object('request_id', q.request_id, 'group_id', q.group_id));
 return jsonb_build_object('ok', true, 'waiting', true, 'group_id', q.group_id,
   'expires_at', q.created_at + make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int),
   'content', '함께 타기로 했습니다. 모두 답하거나 시간이 지나면 함께 출발합니다.');
end
$function$;

select pg_temp.rf('public.world_travel_party_snapshot()', array[
$o$'status',q.status,'created_at',q.created_at,$o$,
$n$'status',q.status,'created_at',q.created_at,'group_id',q.group_id,$n$,
$o$    and (q.status='departed' or (q.status='pending' and q.created_at >= now() - make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int))))$o$,
$n$    and (q.status='departed' or (q.status='pending' and q.created_at >= now() - make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int))
         or (q.status='accepted' and q.created_at >= now() - make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int + (public.world_ride_rules() ->> 'stale_s')::int))))$n$]);

alter function public.world_travel_party_snapshot() security definer;

select pg_temp.rf('public.world_notify_group(text)', array[
$o$'ride_request', 'ride_departed', 'ride_declined',$o$,
$n$'ride_request', 'ride_departed', 'ride_declined', 'ride_accepted',$n$]);

do $g$
declare f text;
begin
  foreach f in array array['world_ride_go(uuid, uuid[], uuid, boolean)', 'world_ride_group_left(uuid)', 'world_ride_group_go(uuid, uuid)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to fn_owner_party_respond_v2', f);
  end loop;
  foreach f in array array['world_travel_party_invite_all(text)', 'world_travel_party_depart(uuid)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $g$;
grant execute on function public.world_ride_rules() to fn_owner_party_invite_v2, fn_owner_party_respond_v2;

update public.world_patch_notes set body = body || $pn$
- [이동] 지도에서 「모두에게 동승 요청」으로 같은 곳의 파티원 모두에게 한 번에 동승을 요청할 수 있습니다. 모두 답하거나 60초가 지나면 수락한 사람이 함께 출발하고, 요청한 사람은 「지금 출발」로 먼저 떠날 수도 있습니다. 운임은 요청한 사람이 한 번 냅니다.
- [이동] 「이동·탈것」의 동승 요청 칸에 상대 이름 대신 「파티원」으로 나오던 것을 고쳤습니다.$pn$ where note_id = '3.8.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127030000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
