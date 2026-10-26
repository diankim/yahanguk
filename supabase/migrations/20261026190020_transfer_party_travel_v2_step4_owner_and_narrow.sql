-- 단계 4: world_travel_party_invite_v2 / world_travel_party_respond_v2 소유권을
-- postgres 에서 전용 최소 권한 역할로 이전하고, 단계 3 에서 넓게 준 권한을
-- 운영에서 검증된 fn_owner_19305 / fn_owner_19306 수준으로 축소한다.

-- 다른 fn_owner_* 정의자 역할과 동일하게 RLS 우회 (파티원 행 조회/잠금에 필요)
ALTER ROLE fn_owner_party_invite_v2  BYPASSRLS;
ALTER ROLE fn_owner_party_respond_v2 BYPASSRLS;

-- invite_v2: world_characters 는 FOR UPDATE 잠금만 필요
REVOKE UPDATE ON public.world_characters FROM fn_owner_party_invite_v2;
GRANT UPDATE (updated_at) ON public.world_characters TO fn_owner_party_invite_v2;
REVOKE UPDATE ON public.world_travel_party_requests FROM fn_owner_party_invite_v2;

-- respond_v2: 실제로 갱신하는 컬럼만 허용, 요청 INSERT 불필요
REVOKE UPDATE ON public.world_characters FROM fn_owner_party_respond_v2;
GRANT UPDATE (gil, travel_destination, travel_arrives_at, updated_at)
  ON public.world_characters TO fn_owner_party_respond_v2;
REVOKE INSERT, UPDATE ON public.world_travel_party_requests FROM fn_owner_party_respond_v2;
GRANT UPDATE (status, responded_at, departed_at)
  ON public.world_travel_party_requests TO fn_owner_party_respond_v2;

-- identity 컬럼 INSERT 에는 시퀀스 권한이 필요 없음
REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public
  FROM fn_owner_party_invite_v2, fn_owner_party_respond_v2;

ALTER FUNCTION public.world_travel_party_respond_v2(uuid, boolean)
  SET search_path TO 'pg_catalog', 'public';

-- 소유권 이전 (새 소유자에게 스키마 CREATE 가 필요하므로 임시 부여 후 회수)
GRANT CREATE ON SCHEMA public TO fn_owner_party_invite_v2, fn_owner_party_respond_v2;
ALTER FUNCTION public.world_travel_party_invite_v2(uuid, text)     OWNER TO fn_owner_party_invite_v2;
ALTER FUNCTION public.world_travel_party_respond_v2(uuid, boolean) OWNER TO fn_owner_party_respond_v2;
REVOKE CREATE ON SCHEMA public FROM fn_owner_party_invite_v2, fn_owner_party_respond_v2;

-- 단계 2 에서 생긴 postgres 의 SET/INHERIT 멤버십을 기존 패턴대로 제한
GRANT fn_owner_party_invite_v2  TO postgres WITH SET FALSE, INHERIT FALSE;
GRANT fn_owner_party_respond_v2 TO postgres WITH SET FALSE, INHERIT FALSE;
