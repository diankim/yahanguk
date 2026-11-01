-- 7.7.4 — 귀허의 주인: 회복품 두 개 · 의무관 회복 절반 · 술법 회피 +15(사용자 요청 2026-11-01).
-- 물품을 막아 둔 뒤로 체력을 채우는 길이 의무관 협동 기술뿐이라 의무관이 끼면 둘이서도 거의 다 이겼다(100%) — 의무관이 필수가 되는 것을 막는다.
--   ① 회복품(청심환·약초액·회춘단·대환단·반요 고약, 우수품 포함)을 한 사람이 한 싸움에 두 개까지 행동으로 쓴다(나 또는 고른 동료, 의무관 ×1.15·우수품 ×1.15).
--   ② 의무관의 회복 기술(응급 처치·해독 침·회춘 진맥)은 귀허의 물살 속에서 절반만 채운다(야전 소생은 그대로).
--   ③ 술법(퇴마관·봉인술사·의무관 등 술법 무기)은 결계로 손아귀를 흘려 회피 +15 — 술법 조합은 회피가 낮아(4~21) 손아귀를 거의 다 맞아 둘이서 10% 안팎이었다.
-- 로컬 복제 DB 정석 플레이 시뮬레이션은 20261104201500 파일 머리말.
alter table public.world_gw_members add column if not exists items_used int not null default 0;

do $p$
declare r record; d text; n int; own text;
begin
  for r in
    select * from (values
      -- world_gw_act: 「item」 행동
      ('public.world_gw_act(uuid,text,uuid,text)'::regprocedure,
$A$  if p_action not in ('attack', 'guard', 'brace', 'coop', 'call', 'chain') then raise exception '알 수 없는 행동입니다.'; end if;$A$,
$B$  if p_action not in ('attack', 'guard', 'brace', 'coop', 'call', 'chain', 'item') then raise exception '알 수 없는 행동입니다.'; end if;$B$),
      ('public.world_gw_act(uuid,text,uuid,text)'::regprocedure,
$A$  if p_action = 'call' and p_target is null then raise exception '이름을 부를 사람을 고르세요.'; end if;$A$,
$B$  if p_action = 'call' and p_target is null then raise exception '이름을 부를 사람을 고르세요.'; end if;
  if p_action = 'item' then
    if coalesce(public.world_item_base(coalesce(p_item, '')), '') not in ('tonic', 'herbal_extract', 'rejuv_pill', 'grand_pill', 'banyo_salve') then
      raise exception '귀허의 주인과 싸우는 동안에는 체력 회복품(청심환·약초액·회춘단·대환단·반요 고약)만 쓸 수 있습니다.'; end if;
    if coalesce(me.items_used, 0) >= 2 then raise exception '이 싸움에서는 회복품을 두 개까지만 쓸 수 있습니다.'; end if;
    select * into c from public.world_characters where owner_id = uid;
    if coalesce((c.inventory ->> p_item)::int, 0) < 1 then raise exception '가방에 그 물품이 없습니다.'; end if;
    if p_target is null then p_target := uid; end if;
  end if;$B$),
      ('public.world_gw_act(uuid,text,uuid,text)'::regprocedure,
$A$|| case when p_action = 'coop' then jsonb_build_object('s', p_item) when p_action = 'chain'$A$,
$B$|| case when p_action = 'coop' then jsonb_build_object('s', p_item) when p_action = 'item' then jsonb_build_object('i', p_item) when p_action = 'chain'$B$),
      -- world_gw_resolve: 회복품 · 의무관 회복 절반 · 술법 회피
      ('public.world_gw_resolve(uuid)'::regprocedure,
$A$    elsif av = 'call' then$A$,
$B$    elsif av = 'item' then
      tgt := coalesce(nullif(a ->> 't', '')::uuid, m.owner_id);
      if coalesce(m.items_used, 0) >= 2 then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 이 싸움에서는 회복품을 더 꺼낼 수 없습니다.');
      elsif coalesce(((select x.inventory from public.world_characters x where x.owner_id = m.owner_id) ->> (a ->> 'i'))::int, 0) < 1 then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 꺼낼 회복품이 없습니다.');
      else
        d := case public.world_item_base(a ->> 'i') when 'tonic' then 35 when 'herbal_extract' then 22 when 'rejuv_pill' then 60 when 'grand_pill' then 100 when 'banyo_salve' then 70 else 0 end
             * case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end * case when m.job_key = 'medic' then 1.15 else 1 end;
        update public.world_characters set inventory = public.world_inv_add(inventory, a ->> 'i', -1), updated_at = now() where owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round(d)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
        update public.world_gw_members set heal = heal + round(d)::int, items_used = items_used + 1 where fight_id = p_fight and owner_id = m.owner_id;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — ' || coalesce((select x.name from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt), '') || '의 체력 +' || round(d)
          || ' (회복품 ' || (coalesce(m.items_used, 0) + 1) || '/2).');
      end if;
    elsif av = 'call' then$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure,
$A$      when 'heal' then update public.world_gw_members set hp = least(100, hp + (e ->> 'amt')::int), heal = heal + (e ->> 'amt')::int where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$A$,
$B$      when 'heal' then update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.5)::int), heal = heal + round((e ->> 'amt')::int * 0.5)::int where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure,
$A$      when 'heal_all' then update public.world_gw_members set hp = least(100, hp + (e ->> 'amt')::int) where fight_id = p_fight and out_rounds = 0;$A$,
$B$      when 'heal_all' then update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.5)::int) where fight_id = p_fight and out_rounds = 0;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure,
$A$        update public.world_gw_members set hp = least(100, hp + (e ->> 'amt')::int), nameless = false where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$A$,
$B$        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.5)::int), nameless = false where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure,
$A$        elsif random() * 100 < coalesce((m.stats ->> 'eva')::numeric, 0) + coalesce((vfx -> 'evade' ->> 'pct')::numeric, 0) then$A$,
$B$        elsif random() * 100 < coalesce((m.stats ->> 'eva')::numeric, 0) + coalesce((vfx -> 'evade' ->> 'pct')::numeric, 0) + (case when m.stats ->> 'style' = 'magic' then 15 else 0 end) then$B$),
      -- world_gw_snapshot: 내 회복품과 남은 횟수
      ('public.world_gw_snapshot(uuid)'::regprocedure,
$A$    'my_act', me.act, 'joined', me.owner_id is not null, 'sp', c.spiritual_power,$A$,
$B$    'my_act', me.act, 'joined', me.owner_id is not null, 'sp', c.spiritual_power,
    'items', (select coalesce(jsonb_object_agg(k, (c.inventory ->> k)::int), '{}'::jsonb) from unnest(array['tonic', 'tonic_hq', 'herbal_extract', 'rejuv_pill', 'rejuv_pill_hq', 'grand_pill', 'grand_pill_hq', 'banyo_salve']) k
               where coalesce((c.inventory ->> k)::int, 0) > 0),
    'items_left', greatest(0, 2 - coalesce(me.items_used, 0)),$B$)
    ) x(fn, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.4 gw items anchor in % (% of 1): %', r.fn, n, left(r.a, 70); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
  end loop;
end $p$;

update public.world_app_meta set value = '20261104202100' where key = 'db_version';
