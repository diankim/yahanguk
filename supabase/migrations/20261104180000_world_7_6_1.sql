-- 7.6.1 — 봉연 토벌: 물러난 뒤 「원할 때 돌아오기」(제보 67, 사용자 묶음)
-- 전에는 쓰러져 물러나면 60초 뒤 저절로 싸움에 돌아가, 회복하는 사이에도 광역·표적 공격을 맞아 다시 쓰러지곤 했다.
-- 이제 60초가 지나도 out_until을 남겨 두고(쉬는 중), 그 사람이 직접 행동(공격·방어·물품·협동 기술)하면 world_raid_action이
-- out_until을 비워 돌아간다. 쉬는 동안은 요괴의 표적·광역·사슬·함께 거는 효과·대신 막기·「모두 물러남」 판정에서 빠지고,
-- 가방·퀵슬롯 물품도 쓸 수 있다(world_use_item). 화면에는 snapshot의 resting으로 알린다.
lock table public.world_characters in access exclusive mode;

do $p$
declare r record; d text; own text; inh boolean; n int;
begin
  for r in select * from (values
      -- 표적 등: 「물러남이 끝났으면 다시 셈」 → 「직접 돌아왔을 때만 셈」
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure,
       $a$(x.out_until is null or x.out_until <= now()) and public.world_raid_here$a$,
       $b$x.out_until is null and public.world_raid_here$b$, 'x.out_until is null and public.world_raid_here', 10),
      -- 되살리기(소생)는 쉬는 동료에게도 쓸 수 있다
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure,
       $a$if tm.out_until is null or tm.out_until <= now() then raise exception '물러난 동료에게만 쓸 수 있습니다.'; end if;$a$,
       $b$if tm.out_until is null then raise exception '물러난 동료에게만 쓸 수 있습니다.'; end if;$b$, 'if tm.out_until is null then raise', 1),
      -- 대신 막기: 쉬는 사람은 막아 주지 않는다
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure,
       $a$if found and (pm.out_until is null or pm.out_until <= now()) then$a$,
       $b$if found and pm.out_until is null then$b$, 'if found and pm.out_until is null then', 1),
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure,
       $a$'의 피해를 입고 물러났습니다(1분 뒤 돌아옴).'$a$,
       $b$'의 피해를 입고 물러났습니다(1분 쉰 뒤 행동하면 돌아옴).'$b$, '1분 쉰 뒤 행동하면', 1),
      -- 가방·퀵슬롯: 쉬는 동안에도 쓸 수 있다
      ('public.world_use_item(text)'::regprocedure,
       $a$AND coalesce(m.out_until, '-infinity'::timestamptz) <= now()$a$,
       $b$AND m.out_until IS NULL$b$, 'AND m.out_until IS NULL', 1),
      -- 화면: 쉬는 중(물러남 시간은 끝났고 아직 돌아오지 않음)
      ('public.world_raid_snapshot_core(uuid)'::regprocedure,
       $a$'out', case when x.out_until > now() then ceil(extract(epoch from x.out_until - now())) end,$a$,
       $b$'out', case when x.out_until > now() then ceil(extract(epoch from x.out_until - now())) end, 'resting', x.out_until is not null and x.out_until <= now(),$b$, '''resting'', x.out_until', 1),
      ('public.world_raid_snapshot_core(uuid)'::regprocedure,
       $a$'out', case when me.out_until > now() then ceil(extract(epoch from me.out_until - now())) end,$a$,
       $b$'out', case when me.out_until > now() then ceil(extract(epoch from me.out_until - now())) end, 'resting', me.out_until is not null and me.out_until <= now(),$b$, '''resting'', me.out_until', 1)
    ) x(fn, a, b, mark, cnt)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.mark in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> r.cnt then raise exception '7.6.1 anchor in % (% of %)', r.fn, n, r.cnt; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

-- 묶음 크기(사용자 결정 2026-10-31, 제보 67·68): 장비·가구(1)와 탄(100)은 그대로,
-- 고급 소모품(진품 이상 — 전에 한 칸 3·5개였던 대환단·회춘단·천령 감로·영기환·바다 요리 등)은 20개, 나머지 2~39개짜리는 모두 40개.
-- 우수품(_hq)도 같은 줄에 걸려 함께 바뀐다(trg_world_item_hq_sync는 기본 물품을 따라 맞추므로 결과가 같다).
update public.world_item_catalog
   set stack_size = case when category = 'consumable' and stack_size <= 5 then 20 else 40 end
 where stack_size between 2 and 39;

update public.world_app_meta set value = '20261104180000' where key = 'db_version';
