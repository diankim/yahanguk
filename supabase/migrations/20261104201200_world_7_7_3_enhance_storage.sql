-- 7.7.3 — 대장간 무기 강화도 창고 재료를 쓴다(사용자 요청 2026-11-01). 제작(world_craft_item)과 같은 규칙:
-- 안전지대(반요촌 제외)에서 가방에 모자란 재료를 개인 창고에서 꺼내 쓴다(가방 먼저). 견적(world_enhance_quote)의 have는 가방+창고, stored는 창고 몫.
do $p$
declare r record; d text; n int; own text; inh boolean;
begin
  for r in
    select * from (values
      ('public.world_weapon_enhance()'::regprocedure,
       $a$  lv int; cost jsonb; chance int; inv jsonb; k text; v int; ok boolean; msg text;$a$,
       $b$  lv int; cost jsonb; chance int; inv jsonb; k text; v int; ok boolean; msg text; st jsonb; hb int; hs int; used_st boolean := false;$b$),
      ('public.world_weapon_enhance()'::regprocedure,
       $a$  if not coalesce(r.is_safe_zone, false) then raise exception '무기 강화는 안전지대의 대장간에서 할 수 있습니다.'; end if;$a$,
       $b$  if not coalesce(r.is_safe_zone, false) then raise exception '무기 강화는 안전지대의 대장간에서 할 수 있습니다.'; end if;
  -- 창고 재료도 쓴다(7.7.3, 반요촌은 창고가 없음)
  if not public.world_banyo_here(uid) then select items into st from public.world_storage where owner_id = uid for update; end if;
  st := coalesce(st, '{}'::jsonb);$b$),
      ('public.world_weapon_enhance()'::regprocedure,
       $a$    if coalesce((inv ->> k)::int, 0) < v then
      raise exception '%', format('재료가 모자랍니다: %s %s개 필요(가진 것 %s개). 대장간에서 살 수 있습니다.',
        coalesce((select item_name from public.world_item_catalog where item_id = k), '재료'), v, coalesce((inv ->> k)::int, 0));
    end if;
    inv := case when (inv ->> k)::int - v <= 0 then inv - k else jsonb_set(inv, array[k], to_jsonb((inv ->> k)::int - v)) end;$a$,
       $b$    hb := coalesce((inv ->> k)::int, 0); hs := coalesce((st ->> k)::int, 0);
    if hb + hs < v then
      raise exception '%', format('재료가 모자랍니다: %s %s개 필요(가방 %s개 · 창고 %s개). 대장간에서 살 수 있습니다.',
        coalesce((select item_name from public.world_item_catalog where item_id = k), '재료'), v, hb, hs);
    end if;
    if hb >= v then
      inv := case when hb - v <= 0 then inv - k else jsonb_set(inv, array[k], to_jsonb(hb - v)) end;
    else
      inv := inv - k;
      st := case when hs - (v - hb) <= 0 then st - k else jsonb_set(st, array[k], to_jsonb(hs - (v - hb))) end;
      used_st := true;
    end if;$b$),
      ('public.world_weapon_enhance()'::regprocedure,
       $a$  ok := random() * 100 < chance;$a$,
       $b$  if used_st then update public.world_storage set items = st, updated_at = now() where owner_id = uid; end if;
  ok := random() * 100 < chance;$b$),
      ('public.world_enhance_quote()'::regprocedure,
       $a$declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; w text; it public.world_item_catalog%rowtype; lv int; cost jsonb; chance int; pw numeric;$a$,
       $b$declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; w text; it public.world_item_catalog%rowtype; lv int; cost jsonb; chance int; pw numeric; st jsonb;$b$),
      ('public.world_enhance_quote()'::regprocedure,
       $a$    'have', (select coalesce(jsonb_object_agg(k, coalesce((c.inventory ->> k)::int, 0)), '{}'::jsonb) from jsonb_object_keys(cost -> 'items') k));$a$,
       $b$    'have', (select coalesce(jsonb_object_agg(k, coalesce((c.inventory ->> k)::int, 0) + coalesce((st ->> k)::int, 0)), '{}'::jsonb) from jsonb_object_keys(cost -> 'items') k),
    'stored', (select coalesce(jsonb_object_agg(k, coalesce((st ->> k)::int, 0)), '{}'::jsonb) from jsonb_object_keys(cost -> 'items') k));$b$),
      ('public.world_enhance_quote()'::regprocedure,
       $a$  cost := public.world_enhance_cost(lv, it.tier);
  chance$a$,
       $b$  cost := public.world_enhance_cost(lv, it.tier);
  -- 창고 몫(7.7.3): 안전지대(반요촌 제외)에서만 강화가 쓰므로 그때만 센다
  if coalesce((public.world_field_region(c.location)).is_safe_zone, false) and not public.world_banyo_here(uid) then
    select items into st from public.world_storage where owner_id = uid; end if;
  st := coalesce(st, '{}'::jsonb);
  chance$b$)
    ) x(fn, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.3 enhance anchor in % (% of 1): %', r.fn, n, left(r.a, 60); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole and am.inherit_option limit 1;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is null and own <> 'postgres' then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

update public.world_app_meta set value = '20261104201200' where key = 'db_version';
