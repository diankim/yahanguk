-- 7.7.6 — 봉연의 그림자(서버 보스)의 큰 수법을 행동 횟수가 아니라 시계로 센다 + [야전 소생]이 쉬는 사람을 끌어들이지 않게(사용자 요청 2026-11-01, 제보 84).
-- ① 요괴 박자: 서버 보스(kind world)는 2초마다 박자 1(world_raids.fx.beat·beat_at, 예약 작업 없이 누가 행동할 때 2초가 지났으면 한 박자).
--    크게 휘두르기 7박자(14초)·사슬 5박자(10초, 2단계부터)·기운 모으기 11박자(22초, 3단계) 시작 → 4박자(8초) 뒤 터짐.
--    전에는 누가 행동할 때마다 차례가 1 올라 9명이면 광역이 1초에 한 번꼴, 기운 모으기가 4~8초마다 모였다 터졌다.
--    10장 결전(kind final, 4명까지)은 맞춰 둔 난이도대로 차례 방식을 그대로 쓴다.
-- ② [야전 소생]: 물러난 동료의 숨 고르기를 끝내고 체력 35로 일으키되 싸움터로 끌어들이지 않는다(「쉬는 중」 — 본인이 행동하면 돌아감).
--    전에는 소생하면 곧바로 복귀로 쳐서, 행동하지 않던 사람이 다시 맞고 쓰러지기를 되풀이했다. 귀허의 주인의 소생은 그대로(라운드 행동).
do $p$
declare r record; d text; n int; own text;
begin
  for r in
    select * from (values
      ($A$  bm text; bp numeric := 0; be text; bep numeric := 0; bc text; bcp numeric := 0; bcn text; ex numeric;$A$,
       $B$  bm text; bp numeric := 0; be text; bep numeric := 0; bc text; bcp numeric := 0; bcn text; ex numeric;
  bt int; tick boolean := true; bnow numeric;$B$),
      ($A$        out_until = case when k = 'revive' then null else out_until end$A$,
       $B$        out_until = case when k = 'revive' then least(out_until, now()) else out_until end$B$),
      ($A$
  if coalesce((rfx ->> 'stagger')::int, 0) > 0 then$A$,
       $B$
  -- 7.7.6: 서버 보스는 큰 수법을 2초 박자로 센다(결전은 차례 그대로)
  if rd.kind = 'world' then
    bnow := extract(epoch from now()); tick := false;
    if not (rfx ? 'beat_at') then rfx := rfx || jsonb_build_object('beat', 0, 'beat_at', bnow);
    elsif bnow >= (rfx ->> 'beat_at')::numeric + 2 then
      rfx := rfx || jsonb_build_object('beat', (rfx ->> 'beat')::int + 1, 'beat_at', bnow); tick := true;
    end if;
    bt := (rfx ->> 'beat')::int;
  else bt := rd.turn; end if;

  if coalesce((rfx ->> 'stagger')::int, 0) > 0 then$B$),
      ($A$    rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int - 1));$A$,
       $B$    rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int - case when tick then 1 else 0 end));$B$),
      ($A$  elsif rd.phase = 3 and rd.turn % 11 = 0 then
    rfx := rfx || jsonb_build_object('charge', jsonb_build_object('left', 5 + greatest(1, n_act),$A$,
       $B$  elsif tick and rd.phase = 3 and bt % 11 = 0 then
    rfx := rfx || jsonb_build_object('charge', jsonb_build_object('left', case when rd.kind = 'world' then 4 else 5 + greatest(1, n_act) end,$B$),
      ($A$  elsif rd.turn % 7 = 0 then$A$, $B$  elsif tick and bt % 7 = 0 then$B$),
      ($A$  elsif rd.phase >= 2 and rd.turn % 5 = 0 then$A$, $B$  elsif tick and rd.phase >= 2 and bt % 5 = 0 then$B$),
      ($A$'기운을 모으는 중 — 남은 ' || (rfx -> 'charge' ->> 'left') || '번 안에 '$A$,
       $B$'기운을 모으는 중 — ' || case when rd.kind = 'world' then '약 ' || ((rfx -> 'charge' ->> 'left')::int * 2) || '초' else '남은 ' || (rfx -> 'charge' ->> 'left') || '번' end || ' 안에 '$B$),
      ($A$when (rd.turn + 1) % 7 = 0 then$A$, $B$when (bt + 1) % 7 = 0 then$B$),
      ($A$when rd.phase >= 2 and (rd.turn + 1) % 5 = 0 then$A$, $B$when rd.phase >= 2 and (bt + 1) % 5 = 0 then$B$)
    ) x(a, b)
  loop
    d := replace(pg_get_functiondef('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.6 raid clock anchor (% of 1): %', n, left(r.a, 70); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
  end loop;
end $p$;

update public.world_coop_skills set description = '물러난 동료를 체력 35로 일으켜 숨 고르기를 끝낸다(봉연 토벌은 그 동료가 행동하면 싸움에 돌아가고, 귀허의 주인은 곧바로 돌아온다).' where skill_id = 'med_revive';
update public.world_coop_skills set description = '보스의 다음 반격 두 번을 막고, 기운을 모으는 중이면 더 늦춘다(봉연의 그림자 6초·그 밖 세 번).' where skill_id = 'an_break';

update public.world_patch_notes set body = body || $N$
## 7.7.6
- **봉연의 그림자가 시계에 맞춰 움직입니다.** 전에는 누군가 행동할 때마다 그림자의 차례가 돌아, 모인 사람이 많을수록 크게 휘두르기·사슬·기운 모으기가 몇 초마다 쏟아졌습니다. 이제 인원과 상관없이 크게 휘두르기는 14초, 사슬은 10초(2단계부터), 기운 모으기는 22초(3단계)마다 오고, 모은 기운은 8초 뒤에 터집니다. 행동한 사람에게 돌아오는 반격은 그대로입니다. 10장 결전은 그대로입니다.
- **[야전 소생]이 쉬는 동료를 싸움으로 끌어들이지 않습니다.** 물러난 동료를 체력 35로 일으키고 숨 고르기만 끝내 주며, 그 동료가 직접 행동해야 싸움에 돌아갑니다(전에는 소생하자마자 다시 노려져 행동하지 않던 사람이 맞고 쓰러지기를 되풀이했습니다). 귀허의 주인에서는 전처럼 곧바로 돌아옵니다.
$N$ where note_id = '7.7.0' and position('## 7.7.6' in body) = 0;

update public.world_app_meta set value = '20261104202700' where key = 'db_version';
