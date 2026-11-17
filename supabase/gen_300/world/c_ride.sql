grant insert on table public.world_notifications to fn_owner_party_respond_v2;

select pg_temp.yh_patch('public.world_notify_group(text)', $q$when p_kind in ('ride_request', $q$, $q$when p_kind in ('ride_request', 'ride_departed', 'ride_declined', $q$);

select pg_temp.yh_patch('public.world_travel_party_respond_v2(uuid,boolean)',
  $q$   update public.world_travel_party_requests
     set status='declined', responded_at=now()
   where request_id=q.request_id;$q$,
  $q$   update public.world_travel_party_requests
     set status='declined', responded_at=now()
   where request_id=q.request_id;
   insert into public.world_notifications(user_id, kind, title, content, payload)
   values (q.leader_id, 'ride_declined', '동승 거절',
     coalesce((select character_name from public.world_characters where owner_id = uid), '파티원') || '이(가) 동승 요청을 사양했습니다.',
     jsonb_build_object('request_id', q.request_id));$q$);

select pg_temp.yh_patch('public.world_travel_party_respond_v2(uuid,boolean)',
  $q$ update public.world_travel_party_requests
   set status='departed', responded_at=now(), departed_at=now(), hops=v_hops
 where request_id=q.request_id;$q$,
  $q$ update public.world_travel_party_requests
   set status='departed', responded_at=now(), departed_at=now(), hops=v_hops
 where request_id=q.request_id;

 insert into public.world_notifications(user_id, kind, title, content, payload)
 values (q.leader_id, 'ride_departed', '동승 출발',
   p.character_name || '이(가) 동승을 받아 함께 출발했습니다. ' || r.region_name || '까지 약 '
     || case when secs >= 3600 then floor(secs / 3600) || '시간 ' else '' end || ceil(mod(secs::numeric, 3600) / 60) || '분.',
   jsonb_build_object('request_id', q.request_id, 'region_id', r.region_id, 'arrives_at', arrive));$q$);
