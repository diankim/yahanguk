create or replace function public.world_ride_rules() returns jsonb language sql immutable set search_path = pg_catalog, public as $f$ select '{"wait_s": 60}'::jsonb $f$;
grant execute on function public.world_ride_rules() to anon, authenticated;

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

create or replace function public.world_ride_expire(p_a uuid, p_b uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public as $f$
begin
  update public.world_travel_party_requests q set status = 'cancelled', cancelled_at = now()
   where q.status = 'pending' and q.created_at < now() - make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int)
     and (q.leader_id in (p_a, p_b) or q.passenger_id in (p_a, p_b));
end $f$;

create or replace function public.world_ride_supersede(p_uid uuid, p_passenger uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public as $f$
declare x record; nm text := coalesce((select character_name from public.world_characters where owner_id = p_uid), '동료');
begin
  for x in select q.request_id, q.leader_id, q.passenger_id from public.world_travel_party_requests q
     where q.status = 'pending' and (q.leader_id in (p_uid, p_passenger) or q.passenger_id in (p_uid, p_passenger)) for update loop
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

do $g$
declare f text;
begin
  foreach f in array array['world_ride_expire(uuid, uuid)', 'world_ride_supersede(uuid, uuid)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to fn_owner_party_invite_v2', f);
  end loop;
end $g$;
grant execute on function public.world_ride_rules() to fn_owner_party_invite_v2, fn_owner_party_respond_v2;

select pg_temp.rf('public.world_travel_party_invite_v2(uuid, text)', array[
$o$  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;$o$,
$n$  PERFORM 1 FROM public.world_characters WHERE owner_id IN (uid, p_passenger_id) ORDER BY owner_id FOR UPDATE;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;$n$,
$o$  pl := public.world_travel_plan(uid, r.region_id, least(c.level, p.level));
  v_hops := (pl ->> 'hops')::int;

  UPDATE public.world_travel_party_requests q SET status = 'cancelled', cancelled_at = now()
   WHERE q.leader_id = uid AND q.passenger_id = p_passenger_id AND q.status = 'pending';
$o$,
$n$  pl := public.world_travel_plan(uid, r.region_id, least(c.level, p.level));
  v_hops := (pl ->> 'hops')::int;

  PERFORM public.world_ride_expire(uid, p_passenger_id);
  SELECT max(q.created_at) INTO wait_at FROM public.world_travel_party_requests q WHERE q.leader_id = uid AND q.status = 'pending';
  IF wait_at IS NOT NULL THEN
    wait_left := greatest(1, ceil(extract(epoch FROM wait_at + make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int) - now())))::int;
    RAISE EXCEPTION USING message = format('보낸 동승 요청이 아직 답을 기다리고 있습니다(%s초 남음).', wait_left), hint = 'ride_wait:' || wait_left;
  END IF;
  PERFORM public.world_ride_supersede(uid, p_passenger_id);
$n$,
$o$      || CASE WHEN v_hops > 1 THEN '(' || v_hops || '구간)' ELSE '' END || '. 운임은 파티장이 냅니다.',
    jsonb_build_object('request_id', rid, 'from_id', uid, 'to_region', p_region_id, 'hops', v_hops));$o$,
$n$      || CASE WHEN v_hops > 1 THEN '(' || v_hops || '구간)' ELSE '' END || '. 운임은 요청한 쪽이 냅니다.',
    jsonb_build_object('request_id', rid, 'from_id', uid, 'to_region', p_region_id, 'hops', v_hops,
      'expires_at', now() + make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int)));$n$,
$o$    'hops', v_hops,
    'content', p.character_name || '에게 동승 요청을 보냈습니다. 수락하면 함께 출발합니다.'$o$,
$n$    'hops', v_hops,
    'expires_at', now() + make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int),
    'content', p.character_name || '에게 동승 요청을 보냈습니다. ' || (public.world_ride_rules() ->> 'wait_s') || '초 안에 수락하면 함께 출발합니다.'$n$,
$o$  v_hops int;
BEGIN$o$,
$n$  v_hops int;
  wait_at timestamptz;
  wait_left int;
BEGIN$n$]);

select pg_temp.rf('public.world_travel_party_respond_v2(uuid, boolean)', array[
$o$ select * into q from public.world_travel_party_requests where request_id=p_request_id for update;
 if q.request_id is null or q.passenger_id<>uid or q.status<>'pending'
   then raise exception '유효한 동승 요청이 없습니다.'; end if;$o$,
$n$ select * into q from public.world_travel_party_requests where request_id=p_request_id;
 if q.request_id is not null and q.passenger_id=uid then
   perform 1 from public.world_characters where owner_id in (q.leader_id, uid) order by owner_id for update;
 end if;
 select * into q from public.world_travel_party_requests where request_id=p_request_id for update;
 if q.request_id is null or q.passenger_id<>uid
   then raise exception '유효한 동승 요청이 없습니다.'; end if;
 if q.status='cancelled'
   then raise exception '취소된 동승 요청입니다. 더 나중에 들어온 동승 요청이 있거나 답할 시간이 지났습니다.'; end if;
 if q.status<>'pending'
   then raise exception '이미 답한 동승 요청입니다.'; end if;$n$,
$o$ perform public.world_seal_guard();

 select * into c from public.world_characters where owner_id=q.leader_id for update;$o$,
$n$ perform public.world_seal_guard();
 if q.created_at < now() - make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int)
   then raise exception '%', '동승 요청에 답할 시간(' || (public.world_ride_rules() ->> 'wait_s') || '초)이 지났습니다.' using hint = 'ride_expired'; end if;

 select * into c from public.world_characters where owner_id=q.leader_id for update;$n$,
$o$' · 파티장이 노정패 '$o$,
$n$' · '||c.character_name||'이(가) 노정패 '$n$]);

select pg_temp.rf('public.world_travel_party_snapshot()', array[
$o$'status',q.status,'created_at',q.created_at)), '[]'::jsonb)
   from public.world_travel_party_requests q where (q.leader_id=uid or q.passenger_id=uid) and q.status in ('pending','departed'))$o$,
$n$'status',q.status,'created_at',q.created_at,
     'expires_at',q.created_at + make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int),
     'leader_name',(select x.character_name from public.world_characters x where x.owner_id=q.leader_id),
     'passenger_name',(select x.character_name from public.world_characters x where x.owner_id=q.passenger_id))), '[]'::jsonb)
   from public.world_travel_party_requests q where (q.leader_id=uid or q.passenger_id=uid)
    and (q.status='departed' or (q.status='pending' and q.created_at >= now() - make_interval(secs => (public.world_ride_rules() ->> 'wait_s')::int))))$n$]);
