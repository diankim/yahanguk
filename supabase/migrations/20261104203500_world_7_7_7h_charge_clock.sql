-- 7.7.7h — 봉연의 그림자 「기운 모으기」에 실제 마감 시각(until)을 둔다(사용자 요청 2026-11-01).
-- 전에는 남은 「박자」(누가 행동할 때 2초가 지났으면 하나씩 줄어듦)로 세어 화면이 초를 셀 수 없었다.
-- 이제 모으기 시작 때 until = 지금 + 8초, 그 시각이 지난 뒤 처음 들어온 행동에서 터진다(끊기 판정은 그대로 · [흐름 끊기]는 6초 늦춤).
-- 스냅샷은 charge.secs(남은 초, 서버 시계)를 함께 내줘 화면이 기기 시계 차이 없이 초를 세고 게이지를 줄인다. 결전은 그대로(차례 수).
do $p$
declare r record; d text; n int; own text; fn regprocedure;
begin
  for r in
    select * from (values
      ('public.world_raid_action(uuid,text,text,uuid,text)',
       $A$    elsif (rfx -> 'charge' ->> 'left')::int <= 0 then$A$,
       $B$    elsif (case when (rfx -> 'charge' ->> 'until') is not null then extract(epoch from now()) >= (rfx -> 'charge' ->> 'until')::numeric else (rfx -> 'charge' ->> 'left')::int <= 0 end) then$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)',
       $A$      if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int + 3)); end if;$A$,
       $B$      if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int + 3));
        if (rfx -> 'charge' ->> 'until') is not null then rfx := jsonb_set(rfx, '{charge,until}', to_jsonb((rfx -> 'charge' ->> 'until')::numeric + 6)); end if; end if;$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)',
       $A$'left', case when rd.kind = 'world' then 4 else 5 + greatest(1, n_act) end,$A$,
       $B$'left', case when rd.kind = 'world' then 4 else 5 + greatest(1, n_act) end, 'until', case when rd.kind = 'world' then round(extract(epoch from now())::numeric + 8, 2) end,$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)',
       $A$'약 ' || ((rfx -> 'charge' ->> 'left')::int * 2) || '초'$A$,
       $B$greatest(0, ceil(coalesce((rfx -> 'charge' ->> 'until')::numeric, extract(epoch from now()) + (rfx -> 'charge' ->> 'left')::int * 2) - extract(epoch from now())))::int || '초'$B$),
      ('public.world_raid_snapshot_core(uuid)',
       $A$'charge', rd.fx -> 'charge',$A$,
       $B$'charge', case when rd.fx ? 'charge' then (rd.fx -> 'charge') || jsonb_build_object('secs', case when (rd.fx -> 'charge' ->> 'until') is not null then greatest(0, round((rd.fx -> 'charge' ->> 'until')::numeric - extract(epoch from now())::numeric, 1)) end, 'dur', 8) end,$B$)
    ) x(f, a, b)
  loop
    fn := r.f::regprocedure;
    d := replace(pg_get_functiondef(fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.7h anchor in % (% of 1): %', r.f, n, left(r.a, 70); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = fn;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
  end loop;
end $p$;

update public.world_patch_notes set body = body || $N$
## 7.7.7h
- 봉연의 그림자 「기운 모으기」가 실제 8초 시계로 흐릅니다. 화면에 남은 초가 실시간으로 줄어드는 게이지로 보이고(끊기까지 남은 피해 막대도 함께), 8초 안에 몰아쳐 끊지 못하면 터집니다. [흐름 끊기]는 6초 늦춥니다.
$N$ where note_id = '7.7.0' and position('## 7.7.7h' in body) = 0;

update public.world_app_meta set value = '20261104203500' where key = 'db_version';
-- (패치노트 줄에 제보 85 회복 효과 색·거르기도 함께 적음 — 운영 DB에는 별도 update로 넣음)
