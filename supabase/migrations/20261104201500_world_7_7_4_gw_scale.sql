-- 7.7.4 — 귀허의 주인: 인원에 맞춘 물러남·손아귀(사용자 요청 2026-11-01).
-- 둘이 했을 때 돌아가며 버티다 겹쳐 쓰러져 실패했는데, 넷이면 손아귀(한 라운드 한 명)가 넷에게 나뉘고 넷이 한꺼번에 빠질 일이 거의 없어 너무 쉬웠다.
-- ① 물러남: 혼자 1·둘 3(그대로)·셋 4·넷 5라운드. 혼자는 「모두 물러남」으로 끝나지 않는다(15분이 지나면 실패).
-- ② 손아귀: 1·2명 하나, 3명 하나·둘 번갈아(짝수 라운드 둘), 4명 둘 — 같은 사람을 두 번 노리지 않고, 연막은 라운드에 한 번만 줄어든다.
do $p$
declare r record; d text; n int; own text; inh boolean;
begin
  for r in
    select * from (values
      ('public.world_gw_hurt(uuid,uuid,integer,integer,text)'::regprocedure,
$A$declare m public.world_gw_members%rowtype; d int := greatest(0, p_dmg);$A$,
$B$declare m public.world_gw_members%rowtype; d int := greatest(0, p_dmg); v_n int; v_out int;$B$),
      ('public.world_gw_hurt(uuid,uuid,integer,integer,text)'::regprocedure,
$A$    update public.world_gw_members set hp = 0, out_rounds = 4, falls = falls + 1, nameless = false where fight_id = p_fight and owner_id = p_uid;
    perform public.world_gw_say(p_fight, p_round, 'fall', m.name || ' — ' || p_why || ' ' || d || '의 피해를 입고 물러났습니다(세 라운드 뒤 돌아옴).');$A$,
$B$    -- 물러남 길이는 인원에 맞춘다(7.7.4): 혼자 한 라운드·둘 세 라운드·셋 네 라운드·넷 다섯 라운드(라운드 끝에 하나 줄어드니 +1로 넣음)
    select count(*) into v_n from public.world_gw_members where fight_id = p_fight;
    v_out := case when v_n <= 1 then 2 when v_n = 2 then 4 when v_n = 3 then 5 else 6 end;
    update public.world_gw_members set hp = 0, out_rounds = v_out, falls = falls + 1, nameless = false where fight_id = p_fight and owner_id = p_uid;
    perform public.world_gw_say(p_fight, p_round, 'fall', m.name || ' — ' || p_why || ' ' || d || '의 피해를 입고 물러났습니다(' || (v_out - 1) || '라운드 뒤 돌아옴).');$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure,
$A$  delayed boolean := false; sealed boolean := false; broke boolean := false; cover_by uuid; hit_who uuid;$A$,
$B$  delayed boolean := false; sealed boolean := false; broke boolean := false; cover_by uuid; hit_who uuid; v_n int; v_hands int; v_h int; v_hit uuid[] := '{}'; v_miss numeric;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure,
$A$      select * into m from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0
       order by -ln(greatest(random(), 1e-9)) / power(greatest(1, coalesce((x.stats ->> 'pres')::numeric, 30) + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)), 1.3) limit 1;
      if m.owner_id is not null then
        hit_who := m.owner_id;
        select owner_id into cover_by from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and fx ->> 'cover' = m.owner_id::text and owner_id <> m.owner_id limit 1;
        n := coalesce((vbfx -> 'smoke' ->> 'n')::int, 0);
        if n > 0 then vbfx := case when n > 1 then jsonb_set(vbfx, '{smoke,n}', to_jsonb(n - 1)) else vbfx - 'smoke' end; end if;
        select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
        if n > 0 and random() * 100 < coalesce((vbfx -> 'smoke' ->> 'miss')::numeric, 45) then
          perform public.world_gw_say(p_fight, r, 'miss', '연막 속에서 주인의 손길이 ' || m.name || '을(를) 비껴갑니다.');
        elsif random() * 100 < coalesce((m.stats ->> 'eva')::numeric, 0) + coalesce((vfx -> 'evade' ->> 'pct')::numeric, 0) then
          if vfx ? 'evade' then update public.world_gw_members x set fx = case when (x.fx -> 'evade' ->> 'n')::int > 1 then jsonb_set(x.fx, '{evade,n}', to_jsonb((x.fx -> 'evade' ->> 'n')::int - 1)) else x.fx - 'evade' end where x.fight_id = p_fight and x.owner_id = m.owner_id; end if;
          perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 주인의 손길을 피했습니다.');
        elsif cover_by is not null then
          perform public.world_gw_hit(p_fight, cover_by, raw * 0.5, r, (select name from public.world_gw_members where fight_id = p_fight and owner_id = cover_by) || '이(가) ' || m.name || ' 앞을 막아서 주인의 손아귀를', false);
        else
          perform public.world_gw_hit(p_fight, hit_who, raw, r, '주인의 손아귀에', false);
        end if;
      end if;$A$,
$B$      -- 손아귀 수는 인원에 맞춘다(7.7.4): 1·2명 하나, 3명 하나·둘 번갈아, 4명 둘 — 같은 사람을 두 번 노리지 않음
      select count(*) into v_n from public.world_gw_members where fight_id = p_fight;
      v_hands := case when v_n >= 4 then 2 when v_n = 3 then 1 + (r % 2) else 1 end;
      n := coalesce((vbfx -> 'smoke' ->> 'n')::int, 0);
      v_miss := coalesce((vbfx -> 'smoke' ->> 'miss')::numeric, 45);
      for v_h in 1 .. v_hands loop
        select * into m from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not (x.owner_id = any (v_hit))
         order by -ln(greatest(random(), 1e-9)) / power(greatest(1, coalesce((x.stats ->> 'pres')::numeric, 30) + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)), 1.3) limit 1;
        exit when m.owner_id is null;
        v_hit := v_hit || m.owner_id;
        hit_who := m.owner_id; cover_by := null;
        select owner_id into cover_by from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and fx ->> 'cover' = m.owner_id::text and owner_id <> m.owner_id limit 1;
        select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
        if n > 0 and random() * 100 < v_miss then
          perform public.world_gw_say(p_fight, r, 'miss', '연막 속에서 주인의 손길이 ' || m.name || '을(를) 비껴갑니다.');
        elsif random() * 100 < coalesce((m.stats ->> 'eva')::numeric, 0) + coalesce((vfx -> 'evade' ->> 'pct')::numeric, 0) then
          if vfx ? 'evade' then update public.world_gw_members x set fx = case when (x.fx -> 'evade' ->> 'n')::int > 1 then jsonb_set(x.fx, '{evade,n}', to_jsonb((x.fx -> 'evade' ->> 'n')::int - 1)) else x.fx - 'evade' end where x.fight_id = p_fight and x.owner_id = m.owner_id; end if;
          perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 주인의 손길을 피했습니다.');
        elsif cover_by is not null then
          perform public.world_gw_hit(p_fight, cover_by, raw * 0.5, r, (select name from public.world_gw_members where fight_id = p_fight and owner_id = cover_by) || '이(가) ' || m.name || ' 앞을 막아서 주인의 ' || case when v_h > 1 then '다른 ' else '' end || '손아귀를', false);
        else
          perform public.world_gw_hit(p_fight, hit_who, raw, r, case when v_h > 1 then '주인의 다른 손아귀에' else '주인의 손아귀에' end, false);
        end if;
      end loop;
      if n > 0 and coalesce(array_length(v_hit, 1), 0) > 0 then vbfx := case when n > 1 then jsonb_set(vbfx, '{smoke,n}', to_jsonb(n - 1)) else vbfx - 'smoke' end; end if;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure,
$A$  if alive = 0 then
    perform public.world_gw_say(p_fight, r, 'bad', '모두가 물러났습니다.$A$,
$B$  -- 혼자면 쓰러져도 한 라운드 쉬고 돌아오므로 「모두 물러남」으로 끝내지 않는다(7.7.4, 시간이 다 되면 실패)
  if alive = 0 and (select count(*) from public.world_gw_members where fight_id = p_fight) > 1 then
    perform public.world_gw_say(p_fight, r, 'bad', '모두가 물러났습니다.$B$)
    ) x(fn, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.4 gw scale anchor in % (% of 1): %', r.fn, n, left(r.a, 60); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole and am.inherit_option limit 1;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is null and own <> 'postgres' then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

update public.world_app_meta set value = '20261104201500' where key = 'db_version';
