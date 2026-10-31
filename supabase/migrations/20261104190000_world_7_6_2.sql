-- 7.6.2 — 원정 일지: 다른 지역으로 따로 원정 간 파티원의 일지가 섞여 함께 간 것처럼 보이던 것(사용자 제보 2026-10-31)
-- 합동 전투(world_expedition_settle)·함께 간 보너스(world_expedition_complete)는 같은 지역만 세므로, 일지도 같은 지역 파티원만 섞는다.
-- 「원정 중인 동료」 목록(party)은 그대로 모두 보인다(같은 지역 표시).
lock table public.world_characters in access exclusive mode;

do $p$
declare d text; a text; b text; n int; own text; inh boolean;
begin
  d := replace(pg_get_functiondef('public.world_expedition_progress()'::regprocedure), E'\r\n', E'\n');
  if position('if x.region_id = e.region_id then lines := lines' in d) > 0 then return; end if;
  a := $a$      lines := lines || public.world_expedition_walk_lines(x.expedition_id);$a$;
  b := $b$      if x.region_id = e.region_id then lines := lines || public.world_expedition_walk_lines(x.expedition_id); end if;$b$;
  n := (length(d) - length(replace(d, a, ''))) / length(a);
  if n <> 1 then raise exception '7.6.2 anchor (% of 1)', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_expedition_progress()'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, a, b);
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;

update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.6.2
- 원정 일지: 파티원이 다른 지역으로 따로 원정을 떠났는데도 그 사람의 일지가 내 일지에 섞여 함께 간 것처럼 보이던 것을 고쳤습니다. 이제 같은 지역으로 원정 중인 파티원(함께 싸우는 동료)의 일지만 함께 보이고, 다른 곳에 간 파티원은 아래 「원정 중인 동료」 목록에서 진행만 볼 수 있습니다.
$N$
 where note_id = '7.5.0' and position('## 7.6.2' in body) = 0;

update public.world_app_meta set value = '20261104190000' where key = 'db_version';
