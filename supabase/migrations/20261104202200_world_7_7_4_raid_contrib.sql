-- 7.7.4 — 봉연 토벌·결전 기여도 개편(사용자 요청 2026-11-01).
-- 전에는 준 피해·회복량×2만 셌고, 북돋기·약화·보호 기술은 효과와 상관없이 공격력×0.6만 받아 봉인술사 같은 보조가 낮게 잡혔다.
-- 이제 기여도 = 직접 준 피해 + 내가 늘려 준 동료의 피해 + 내가 막아 준 동료의 피해 + 동료를 회복시킨 양 + 받아 낸 피해의 절반.
--   · 북돋기(기세 부적·전장 지휘·추격 신호·공명 법진 등 might)·봉인 사슬(expose)·약점 표시(crit)·급소 지시(crit_next): 늘어난 몫을 건 사람에게(때린 사람의 몫에서는 뺌)
--   · 호신부·팔괘 결계·패턴 공유(ward)·파사 진언(gward)·방호 법구(shield)·길 터주기(evade)·대신 막기(cover)·연막(smoke): 동료가 덜 받은 피해를 건 사람에게
--   · 회복: 동료를 채운 양 ×1, 자기 자신 ×0.5(물품 포함) — 전에는 ×2
--   · 받아 낸 피해: 맞은 피해 ×0.5(이목을 끌어 맞아 주는 방패 몫)
--   · 기술을 쓴 것만으로 주던 몫: 공격력×0.6 → ×0.2(효과가 따로 셈해지므로)
-- 기여도 갈래는 world_raid_members.credits(dmg·boost·guard·heal·taken·skill)에 따로 적어 화면이 「내 기여」에 나눠 보인다.
-- 효과에 건 사람(by)을 적어 두므로, 이 배포 전에 걸린 효과는 건 사람 몫을 셈하지 않는다.
alter table public.world_raid_members add column if not exists credits jsonb not null default '{}'::jsonb;

-- 갈래만 적는다(기여도 합계는 그대로)
create or replace function public.world_raid_credit_note(p_raid uuid, p_owner uuid, p_amt numeric, p_kind text)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
begin
  if p_owner is null or coalesce(p_amt, 0) <= 0 then return; end if;
  update public.world_raid_members set credits = jsonb_set(coalesce(credits, '{}'::jsonb), array[p_kind], to_jsonb(round(coalesce((credits ->> p_kind)::numeric, 0) + p_amt)))
   where raid_id = p_raid and owner_id = p_owner;
end $function$;
-- 다른 사람에게 기여도를 더한다(서버 보스는 레벨 배율 L/30, 결전은 그대로) + 갈래
create or replace function public.world_raid_credit(p_raid uuid, p_owner uuid, p_amt numeric, p_kind text)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
begin
  if p_owner is null or coalesce(p_amt, 0) <= 0 then return; end if;
  update public.world_raid_members x set contrib = x.contrib + p_amt * case when (select r.kind from public.world_raids r where r.raid_id = p_raid) = 'world' then least(1, x.level / 30.0) else 1 end,
    credits = jsonb_set(coalesce(x.credits, '{}'::jsonb), array[p_kind], to_jsonb(round(coalesce((x.credits ->> p_kind)::numeric, 0) + p_amt)))
   where x.raid_id = p_raid and x.owner_id = p_owner;
end $function$;
revoke all on function public.world_raid_credit_note(uuid, uuid, numeric, text) from public, anon, authenticated;
revoke all on function public.world_raid_credit(uuid, uuid, numeric, text) from public, anon, authenticated;
grant execute on function public.world_raid_credit_note(uuid, uuid, numeric, text) to fn_owner_field;
grant execute on function public.world_raid_credit(uuid, uuid, numeric, text) to fn_owner_field;

do $p$
declare r record; d text; n int; own text;
begin
  for r in
    select * from (values
      -- world_raid_action ----------------------------------------------------------------------
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$rnd numeric; m record;$A$,
$B$rnd numeric; m record;
  bm text; bp numeric := 0; be text; bep numeric := 0; bc text; bcp numeric := 0; bcn text; ex numeric;$B$),
      -- 효과에 건 사람(by)을 적는다
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 0,
$A$jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n')$A$,
$B$jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n', 'by', uid)$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 2,
$A$jsonb_build_object('gward', jsonb_build_object('pct', v -> 'pct'))$A$,
$B$jsonb_build_object('gward', jsonb_build_object('pct', v -> 'pct', 'by', uid))$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$jsonb_build_object('shield', coalesce((f ->> 'shield')::int, 0) + (v ->> 'amt')::int)$A$,
$B$jsonb_build_object('shield', coalesce((f ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid)$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (v ->> 'amt')::int)$A$,
$B$jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid)$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 2,
$A$'{"crit_next":1}'::jsonb$A$,
$B$jsonb_build_object('crit_next', uid)$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$jsonb_build_object('smoke', jsonb_build_object('miss', v -> 'miss', 'n', v -> 'n'))$A$,
$B$jsonb_build_object('smoke', jsonb_build_object('miss', v -> 'miss', 'n', v -> 'n', 'by', uid))$B$),
      -- 공격: 동료가 걸어 준 몫을 미리 적어 둔다
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$    if f ? 'might' then mul := mul * (1 + (f -> 'might' ->> 'pct')::numeric / 100.0);$A$,
$B$    bm := f -> 'might' ->> 'by'; bp := coalesce((f -> 'might' ->> 'pct')::numeric, 0);
    be := rfx -> 'expose' ->> 'by'; bep := coalesce((rfx -> 'expose' ->> 'pct')::numeric, 0);
    bc := f -> 'crit' ->> 'by'; bcp := coalesce((f -> 'crit' ->> 'pct')::numeric, 0); bcn := f ->> 'crit_next';
    if f ? 'might' then mul := mul * (1 + (f -> 'might' ->> 'pct')::numeric / 100.0);$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$mb.dmg := mb.dmg + dmg; credit := dmg;$A$,
$B$mb.dmg := mb.dmg + dmg; credit := dmg;
    -- 7.7.4 기여도: 동료가 늘려 준 몫은 건 사람에게(때린 사람 몫에서는 뺀다)
    if bm is not null and bm <> uid::text and bp > 0 then ex := dmg - dmg / (1 + bp / 100.0); perform public.world_raid_credit(p_raid, bm::uuid, ex, 'boost'); credit := credit - ex; end if;
    if be is not null and be <> uid::text and bep > 0 then ex := dmg - dmg / (1 + bep / 100.0); perform public.world_raid_credit(p_raid, be::uuid, ex, 'boost'); credit := credit - ex; end if;
    if crit and bcn is not null and bcn <> '1' and bcn <> uid::text then ex := dmg - dmg / 1.5; perform public.world_raid_credit(p_raid, bcn::uuid, ex, 'boost'); credit := credit - ex;
    elsif crit and bc is not null and bc <> uid::text and bcp > 0 then ex := (dmg - dmg / 1.5) * bcp / greatest(1, coalesce((st ->> 'crit')::numeric, 0) + bcp);
      perform public.world_raid_credit(p_raid, bc::uuid, ex, 'boost'); credit := credit - ex; end if;
    credit := greatest(0, credit);$B$),
      -- 회복: 동료 ×1, 자기 ×0.5
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$credit := greatest(0, h1 - h0) * 2;$A$,
$B$credit := greatest(0, h1 - h0) * 0.5;$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$credit := (st ->> 'attack')::numeric * 0.6;$A$,
$B$credit := (st ->> 'attack')::numeric * 0.2;$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$if amt > 0 then mb.heal := mb.heal + amt; credit := credit + amt * 2; end if;$A$,
$B$if amt > 0 then mb.heal := mb.heal + amt; credit := credit + amt * case when tgt = uid then 0.5 else 1 end; end if;$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$credit := credit + coalesce(acc, 0) * 2;$A$,
$B$credit := credit + coalesce(acc, 0);$B$),
      -- 내 행동 몫의 갈래
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$    contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = st where raid_id = p_raid and owner_id = uid;$A$,
$B$    contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = st where raid_id = p_raid and owner_id = uid;
  perform public.world_raid_credit_note(p_raid, uid, credit, case act when 'attack' then 'dmg' when 'item' then 'heal' when 'coop' then case when mb.heal > 0 and k in ('heal', 'heal_all', 'cleanse_heal', 'revive') then 'heal' else 'skill' end else 'skill' end);$B$),
      -- 연막으로 빗나간 공격: 막아 준 몫(보스 한 대의 절반쯤)
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$        perform public.world_raid_say(p_raid, 'miss', '연막 속에서 ' || rd.boss_name || '의 공격이 빗나갔습니다.');$A$,
$B$        perform public.world_raid_credit(p_raid, nullif(rfx -> 'smoke' ->> 'by', '')::uuid, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul * 0.5, 'guard');
        perform public.world_raid_say(p_raid, 'miss', '연막 속에서 ' || rd.boss_name || '의 공격이 빗나갔습니다.');$B$),
      -- world_raid_hit -------------------------------------------------------------------------
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure, 1,
$A$      m := pm; f := pm.fx; who := pm.owner_id; p_raw := p_raw * 0.5;$A$,
$B$      perform public.world_raid_credit(p_raid, pm.owner_id, p_raw * 0.5 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0), 'guard');
      m := pm; f := pm.fx; who := pm.owner_id; p_raw := p_raw * 0.5;$B$),
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure, 1,
$A$    if f ? 'evade' then f := case when (f -> 'evade' ->> 'n')::int <= 1$A$,
$B$    if f -> 'evade' ->> 'by' is not null and f -> 'evade' ->> 'by' <> who::text then
      perform public.world_raid_credit(p_raid, (f -> 'evade' ->> 'by')::uuid, p_raw * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0), 'guard'); end if;
    if f ? 'evade' then f := case when (f -> 'evade' ->> 'n')::int <= 1$B$),
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure, 1,
$A$  if f ? 'ward' then
    d := d * (1 - (f -> 'ward' ->> 'pct')::numeric / 100.0);$A$,
$B$  if f ? 'ward' then
    if f -> 'ward' ->> 'by' is not null and f -> 'ward' ->> 'by' <> who::text then
      perform public.world_raid_credit(p_raid, (f -> 'ward' ->> 'by')::uuid, d * (f -> 'ward' ->> 'pct')::numeric / 100.0, 'guard'); end if;
    d := d * (1 - (f -> 'ward' ->> 'pct')::numeric / 100.0);$B$),
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure, 1,
$A$  if p_kind in ('slam', 'burst') and f ? 'gward' then
$A$,
$B$  if p_kind in ('slam', 'burst') and f ? 'gward' and f -> 'gward' ->> 'by' is not null and f -> 'gward' ->> 'by' <> who::text then
    perform public.world_raid_credit(p_raid, (f -> 'gward' ->> 'by')::uuid, d * (f -> 'gward' ->> 'pct')::numeric / 100.0, 'guard'); end if;
  if p_kind in ('slam', 'burst') and f ? 'gward' then
$B$),
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure, 1,
$A$  if absorb > 0 then d := d - absorb;$A$,
$B$  if absorb > 0 and f ->> 'shield_by' is not null and f ->> 'shield_by' <> who::text then perform public.world_raid_credit(p_raid, (f ->> 'shield_by')::uuid, absorb, 'guard'); end if;
  if absorb > 0 then d := d - absorb;$B$),
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure, 1,
$A$  d := greatest(0, round(d));$A$,
$B$  d := greatest(0, round(d));
  -- 받아 낸 피해의 절반(이목을 끌어 맞아 주는 몫)
  perform public.world_raid_credit(p_raid, who, d * 0.5, 'taken');$B$),
      -- 스냅샷: 갈래
      ('public.world_raid_snapshot_core(uuid)'::regprocedure, 1,
$A$'share', case when tot > 0 then round(x.contrib / tot * 100, 1) else 0 end,$A$,
$B$'share', case when tot > 0 then round(x.contrib / tot * 100, 1) else 0 end, 'credits', coalesce(x.credits, '{}'::jsonb),$B$)
    ) x(fn, cnt, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if (r.cnt = 0 and n < 8) or (r.cnt > 0 and n <> r.cnt) then raise exception '7.7.4 raid contrib anchor in % (% vs %): %', r.fn, n, r.cnt, left(r.a, 70); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
  end loop;
end $p$;

update public.world_app_meta set value = '20261104202200' where key = 'db_version';
