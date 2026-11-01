-- 7.7.2d — 조사원 의뢰 넘기기가 「한 번에 8가지 물품까지」로 막히던 것(7.7.2 실수).
-- world_ucomm_fulfill이 world_trade_bundle_check(p_owner, p_inv, p_items)에 가방과 넘길 물품을 거꾸로 넘겨 가방 전체를 검사했다.
do $p$
declare d text; n int; own text; inh boolean;
  a text := 'public.world_trade_bundle_check(uid, give, inv)';
  b text := 'public.world_trade_bundle_check(uid, inv, give)';
begin
  d := replace(pg_get_functiondef('public.world_ucomm_fulfill(bigint)'::regprocedure), E'\r\n', E'\n');
  if position(b in d) > 0 then return; end if;
  n := (length(d) - length(replace(d, a, ''))) / length(a);
  if n <> 1 then raise exception '7.7.2d anchor (% of 1)', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_ucomm_fulfill(bigint)'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, a, b);
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;

update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.7.2d
- 조사원 의뢰에 물품을 넘길 때 가방에 물품이 여러 가지 있으면 「한 번에 8가지 물품까지 거래할 수 있습니다」로 막히던 것을 고쳤습니다(넘길 물품 대신 가방 전체를 검사하고 있었습니다).
$N$
 where note_id = '7.7.0' and position('## 7.7.2d' in body) = 0;

update public.world_app_meta set value = '20261104200900' where key = 'db_version';
