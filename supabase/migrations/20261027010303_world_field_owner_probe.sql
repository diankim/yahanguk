-- 함수 소유권 이전 방식 확인. 함수는 postgres로 만든 뒤 fn_owner_field에 소유권을 넘긴다
-- (SQL Editor에서 GRANT fn_owner_field TO postgres WITH SET TRUE 를 실행해 둔 상태).
GRANT CREATE ON SCHEMA public TO fn_owner_field;
CREATE OR REPLACE FUNCTION public.world_stamina_max(p_level integer)
 RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO 'pg_catalog'
AS $f$ SELECT 20 + greatest(1, coalesce(p_level, 1)) / 5 $f$;
ALTER FUNCTION public.world_stamina_max(integer) OWNER TO fn_owner_field;
CREATE OR REPLACE FUNCTION public.world_stamina_now(p_stamina integer, p_at timestamptz, p_level integer)
 RETURNS integer LANGUAGE sql STABLE SET search_path TO 'pg_catalog', 'public'
AS $f$ SELECT least(public.world_stamina_max(p_level), greatest(0, p_stamina) + floor(greatest(0, extract(epoch FROM now() - p_at)) / 360)::int) $f$;
REVOKE ALL ON FUNCTION public.world_stamina_now(integer, timestamptz, integer) FROM PUBLIC;
ALTER FUNCTION public.world_stamina_now(integer, timestamptz, integer) OWNER TO fn_owner_field;
