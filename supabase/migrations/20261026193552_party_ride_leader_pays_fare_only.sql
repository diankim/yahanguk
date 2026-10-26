-- 동승 운임 규칙: 파티장만 운임을 낸다.
-- 동승자 행(world_travel_history)은 fare_exempt=true 로 기록되어
-- world_charge_mount_fare 트리거가 동승자 본인 탈것 기준 운임을 차감하지 않는다.
-- 파티장 행은 기존대로 파티장 탈것 기준으로 정확히 1회 차감된다.
-- 클라이언트는 world_travel_history 에 SELECT 권한만 있으므로 이 값은 서버 함수만 정할 수 있다.

ALTER TABLE public.world_travel_history
  ADD COLUMN IF NOT EXISTS fare_exempt boolean NOT NULL DEFAULT false;

-- 1) 운임 트리거: 영구 사망 검사 뒤 fare_exempt 행은 차감하지 않음 (그 외 본문 동일)
GRANT fn_owner_19203 TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_19203;
SET ROLE fn_owner_19203;
CREATE OR REPLACE FUNCTION public.world_charge_mount_fare()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$ declare c public.world_characters%rowtype; m public.world_mount_catalog%rowtype; fare integer:=0; begin select * into c from public.world_characters where owner_id=new.owner_id for update; if not found then return new; end if; if c.is_dead then raise exception '영구 사망한 캐릭터는 이동할 수 없습니다.'; end if; if new.fare_exempt then return new; end if; if c.mount_id is null then return new; end if; select * into m from public.world_mount_catalog where mount_id=c.mount_id; if not found or coalesce(m.fare_free,false) then return new; end if; fare:=greatest(0,coalesce(m.fare_tokens,1)); if c.mount_tokens<fare then raise exception '운행 재화가 부족합니다. 필요 %개 / 보유 %개. 탐험·전투·채집·제작으로 획득할 수 있습니다.',fare,c.mount_tokens; end if; update public.world_characters set mount_tokens=mount_tokens-fare,updated_at=now() where owner_id=new.owner_id; insert into public.world_economy_ledger(owner_id,action,currency_delta,sink,details) values(new.owner_id,'mount_fare',-fare,true,jsonb_build_object('mount_id',m.mount_id,'to',new.to_region)); return new; end $function$;
RESET ROLE;
REVOKE CREATE ON SCHEMA public FROM fn_owner_19203;
GRANT fn_owner_19203 TO postgres WITH SET FALSE, INHERIT FALSE;

-- 2) 동승 수락: 동승자 행만 fare_exempt=true 로 기록 (그 외 본문 동일)
GRANT fn_owner_party_respond_v2 TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_party_respond_v2;
SET ROLE fn_owner_party_respond_v2;
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
 select case when coalesce(m.fare_free,false) then 0
             else greatest(0,coalesce(m.fare_tokens,1)) end
   into fare
   from public.world_mount_catalog m where m.mount_id=c.mount_id;
 fare:=coalesce(fare,0);
 if c.mount_tokens<fare
   then raise exception '운행 재화가 부족합니다. 탈것 운임을 확인한 뒤 다시 시도하세요.'; end if;
 if c.level<r.min_level or p.level<r.min_level
   then raise exception '동승자 모두 목적지의 최소 레벨을 충족해야 합니다.'; end if;

 dx:=(r.world_x-oldr.world_x)::numeric;
 dy:=(r.world_y-oldr.world_y)::numeric;
 dist:=sqrt(dx*dx+dy*dy);
 select coalesce(speed_multiplier,1) into speed
   from public.world_mount_catalog where mount_id=c.mount_id;
 secs:=greatest(12,least(1800,round(
   (dist*2.2+abs(r.elevation-oldr.elevation)*9+15)
   *greatest(r.terrain_cost,oldr.terrain_cost)
   *case when r.territory_id<>oldr.territory_id then 1.35 else 1 end
   /coalesce(speed,1))::int));
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
RESET ROLE;
REVOKE CREATE ON SCHEMA public FROM fn_owner_party_respond_v2;
GRANT fn_owner_party_respond_v2 TO postgres WITH SET FALSE, INHERIT FALSE;
