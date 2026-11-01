-- 7.5.9j(긴급) — 봉연의 그림자를 물리친 마지막 한 방이 「DELETE requires a WHERE clause」로 막히던 것.
-- world_raid_settle이 이겼을 때 잠김을 모두 푸는 줄(delete from world_raid_locks;)에 WHERE가 없어,
-- 조사원 요청(PostgREST)으로 정산될 때 Supabase의 안전장치(safeupdate)가 거절했다. 예약 작업으로 끝날 때는 걸리지 않았다.
do $p$
declare d text; own text; inh boolean;
begin
  d := pg_get_functiondef('public.world_raid_settle(uuid,boolean)'::regprocedure);
  if position('delete from public.world_raid_locks;' in d) = 0 then return; end if;
  if (length(d) - length(replace(d, 'delete from public.world_raid_locks;', ''))) / length('delete from public.world_raid_locks;') <> 1 then raise exception '7.5.9j anchor'; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_raid_settle(uuid,boolean)'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, 'delete from public.world_raid_locks;', 'delete from public.world_raid_locks where true;');
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;
