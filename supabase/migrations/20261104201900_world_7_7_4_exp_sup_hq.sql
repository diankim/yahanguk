-- 7.7.4 — 원정 창 보급품에 우수품도 센다(제보 81, 조의신).
-- 원정을 떠날 때(world_expedition_start)는 우수품을 먼저 챙기는데, 원정 창 목록(world_expedition_overview)은 보통 물품만 세어
-- 우수품만 가진 보급품은 아예 보이지 않고, 둘 다 있으면 수가 적게 보였다.
do $p$
declare r record; d text; n int; own text;
begin
  for r in
    select * from (values
      ($A$least(20, (c.inventory ->> k)::int)$A$, $B$least(20, coalesce((c.inventory ->> k)::int, 0) + coalesce((c.inventory ->> (k || '_hq'))::int, 0))$B$),
      ($A$WHERE coalesce((c.inventory ->> k)::int, 0) > 0)$A$, $B$WHERE coalesce((c.inventory ->> k)::int, 0) + coalesce((c.inventory ->> (k || '_hq'))::int, 0) > 0)$B$)
    ) x(a, b)
  loop
    d := replace(pg_get_functiondef('public.world_expedition_overview'::regproc), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.4 exp sup anchor (% of 1): %', n, r.a; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_expedition_overview'::regproc;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
  end loop;
end $p$;

update public.world_app_meta set value = '20261104201900' where key = 'db_version';
