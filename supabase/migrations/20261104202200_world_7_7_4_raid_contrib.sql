-- 7.7.4 — 기여도 일원화(사용자 요청 2026-11-01): 합동 토벌·결전(이 파일)·귀허의 주인·파티 토벌(20261104202400)이 같은 공식을 쓴다.
-- 전에는 준 피해·회복량×2만 셌고, 북돋기·약화·보호 기술은 효과와 상관없이 공격력×0.6만 받아 봉인술사 같은 보조가 낮게 잡혔다.
-- 행동마다는 갈래별 원값만 world_raid_members.credits에 쌓는다(dmg 준 피해 · boost 늘려 준 동료 피해 · guard 막아 준 피해 ·
--   heal 동료 회복 · heal_self 자기 회복 · taken 받아 낸 피해 · skill 협동 기술 쓴 횟수).
-- 점수는 world_contrib_score 하나로 계산한다:
--   준 피해 + 0.75×늘려 준 피해 + 0.4×공격력×기술 횟수 + K×(막아 준 피해 + 동료 회복 + ½자기 회복 + ½받아 낸 피해)
--   K = 1.5 × 참가자 평균 공격력 ÷ 보스 한 대(world_raid_k) — 체력 단위(보스 한 대 20~30)를 피해 단위(공격 한 번 200~300)로 바꾸는 값.
--   서버 보스(kind world)는 지금처럼 레벨 배율 L/30을 곱한다.
-- 전에는 세지 않던 효과도 막아 준 피해로 센다: 퇴마 결계(광역 공격을 꺾은 몫) · 호법 신장(끌어와 맞은 피해 전부 + 줄인 몫) ·
--   휘청임(봉인 사슬·흐름 끊기로 보스가 반격을 건너뛴 기대 피해) · 영력 보급(채워 준 영력×공격력×0.05를 늘려 준 피해로).
-- 계수는 6직업 넷·둘 모든 조합 정석 모형으로 맞췄다(직업마다 넷 24~26%·둘 46~54%, 전에는 17~31%).
-- 행동마다 점수를 다시 쓰지 않는다: 스냅샷은 읽을 때 계산하고, 정산(world_raid_settle) 첫머리에서 한 번 contrib에 적는다.
-- 이 배포 전에 쌓인 기여도(credits 없음)는 그대로 둔다.
alter table public.world_raid_members add column if not exists credits jsonb not null default '{}'::jsonb;

-- 점수(세 전투 공통). 테이블을 읽지 않는 계산이라 누구나 부를 수 있게 둔다
create or replace function public.world_contrib_score(p_cr jsonb, p_atk numeric, p_k numeric)
returns numeric language sql immutable as $function$
  select coalesce((p_cr ->> 'dmg')::numeric, 0) + 0.75 * coalesce((p_cr ->> 'boost')::numeric, 0)
       + 0.4 * coalesce(p_atk, 0) * coalesce((p_cr ->> 'skill')::numeric, 0)
       + coalesce(p_k, 0) * (coalesce((p_cr ->> 'guard')::numeric, 0) + coalesce((p_cr ->> 'heal')::numeric, 0)
                             + 0.5 * coalesce((p_cr ->> 'heal_self')::numeric, 0) + 0.5 * coalesce((p_cr ->> 'taken')::numeric, 0))
$function$;

-- 갈래에 원값을 더한다(점수는 따로 계산)
create or replace function public.world_raid_credit(p_raid uuid, p_owner uuid, p_amt numeric, p_kind text)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
begin
  if p_owner is null or coalesce(p_amt, 0) <= 0 or p_kind is null then return; end if;
  update public.world_raid_members set credits = jsonb_set(coalesce(credits, '{}'::jsonb), array[p_kind], to_jsonb(round(coalesce((credits ->> p_kind)::numeric, 0) + p_amt, 1)))
   where raid_id = p_raid and owner_id = p_owner;
end $function$;
-- 체력 단위를 피해 단위로 바꾸는 값
create or replace function public.world_raid_k(p_raid uuid)
returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare rk text; aa numeric; al numeric;
begin
  select kind into rk from public.world_raids where raid_id = p_raid;
  select avg((stats ->> 'attack')::numeric), avg(level) into aa, al from public.world_raid_members where raid_id = p_raid and stats ? 'attack';
  if aa is null then return 1; end if;
  return 1.5 * aa / greatest(1, public.world_raid_boss_base(p_raid, rk, round(al)::int));
end $function$;
-- 한 사람의 점수(배포 전 기여도는 그대로)
create or replace function public.world_raid_score(p_kind text, p_level int, p_cr jsonb, p_stats jsonb, p_old numeric, p_k numeric)
returns numeric language sql immutable as $function$
  select case when coalesce(p_cr, '{}'::jsonb) = '{}'::jsonb then coalesce(p_old, 0)
              else public.world_contrib_score(p_cr, (p_stats ->> 'attack')::numeric, p_k) * case when p_kind = 'world' then least(1, coalesce(p_level, 1) / 30.0) else 1 end end
$function$;
-- 정산 첫머리에서 한 번 contrib에 적는다
create or replace function public.world_raid_recontrib(p_raid uuid)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare ck numeric := public.world_raid_k(p_raid); rk text;
begin
  select kind into rk from public.world_raids where raid_id = p_raid;
  update public.world_raid_members x set contrib = public.world_raid_score(rk, x.level, x.credits, x.stats, x.contrib, ck)
   where x.raid_id = p_raid and x.credits <> '{}'::jsonb;
end $function$;
revoke all on function public.world_raid_credit(uuid, uuid, numeric, text) from public, anon, authenticated;
revoke all on function public.world_raid_k(uuid) from public, anon, authenticated;
revoke all on function public.world_raid_recontrib(uuid) from public, anon, authenticated;
grant execute on function public.world_raid_credit(uuid, uuid, numeric, text) to fn_owner_field;
grant execute on function public.world_raid_k(uuid) to fn_owner_field;
grant execute on function public.world_raid_recontrib(uuid) to fn_owner_field;

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
      -- 회복·기술: 원값만(점수는 공식이 계산)
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$credit := greatest(0, h1 - h0) * 2;$A$,
$B$credit := greatest(0, h1 - h0);$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$credit := (st ->> 'attack')::numeric * 0.6;$A$,
$B$credit := 0;$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$if amt > 0 then mb.heal := mb.heal + amt; credit := credit + amt * 2; end if;$A$,
$B$if amt > 0 then mb.heal := mb.heal + amt; perform public.world_raid_credit(p_raid, uid, amt, case when tgt = uid then 'heal_self' else 'heal' end); end if;$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$credit := credit + coalesce(acc, 0) * 2;$A$,
$B$perform public.world_raid_credit(p_raid, uid, coalesce(acc, 0), 'heal');$B$),
      -- 행동마다 점수를 쌓지 않는다(contrib은 정산 때 world_raid_recontrib)
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$  mb.contrib := mb.contrib + credit * case when rd.kind = 'world' then least(1, mb.level / 30.0) else 1 end;
$A$,
$B$$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$    contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = st where raid_id = p_raid and owner_id = uid;$A$,
$B$    contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = st where raid_id = p_raid and owner_id = uid;
  perform public.world_raid_credit(p_raid, uid, credit, case act when 'attack' then 'dmg' when 'item' then 'heal_self' end);
  if act = 'coop' then perform public.world_raid_credit(p_raid, uid, 1, 'skill'); end if;$B$),
      -- 「나에게만」 기술(호위 무사 파진 돌격)
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$    tgt := coalesce(p_target, uid);$A$,
$B$    tgt := case when sk.target = 'self' then uid else coalesce(p_target, uid) end;$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$    if sk.target = 'ally' and tgt = uid then$A$,
$B$    if sk.target in ('ally', 'self') and tgt = uid then$B$),
      -- 영력 보급: 채워 준 영력 × 공격력 × 0.05를 늘려 준 피해로
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$      elsif k = 'sp' then
$A$,
$B$      elsif k = 'sp' then
        if tgt <> uid then perform public.world_raid_credit(p_raid, uid, (select greatest(0, least((v ->> 'amt')::int, 100 - x.spiritual_power)) from public.world_characters x where x.owner_id = tgt) * coalesce((st ->> 'attack')::numeric, 0) * 0.05, 'boost'); end if;
$B$),
      -- 퇴마 결계: 꺾은 광역 피해
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$rfx := rfx || jsonb_build_object('break', v -> 'pct');$A$,
$B$rfx := rfx || jsonb_build_object('break', v -> 'pct', 'break_by', uid);$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$      end loop;
      rfx := rfx - 'break';
$A$,
$B$      end loop;
      if rfx ? 'break_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'break_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 2.2 * (rfx ->> 'break')::numeric / 100.0 * 0.7 * greatest(1, n_act), 'guard'); end if;
      rfx := rfx - 'break' - 'break_by';
$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$    end loop;
    rfx := rfx - 'break';
$A$,
$B$    end loop;
    if rfx ? 'break_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'break_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 0.8 * (rfx ->> 'break')::numeric / 100.0 * 0.7 * greatest(1, n_act), 'guard'); end if;
    rfx := rfx - 'break' - 'break_by';
$B$),
      -- 휘청임(봉인 사슬·흐름 끊기): 보스가 건너뛴 반격의 기대 피해
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$'stagger', coalesce((rfx ->> 'stagger')::int, 0) + coalesce((v ->> 'stagger')::int, 0));$A$,
$B$'stagger', coalesce((rfx ->> 'stagger')::int, 0) + coalesce((v ->> 'stagger')::int, 0), 'stagger_by', uid);$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$rfx := rfx || jsonb_build_object('stagger', coalesce((rfx ->> 'stagger')::int, 0) + (v ->> 'n')::int);$A$,
$B$rfx := rfx || jsonb_build_object('stagger', coalesce((rfx ->> 'stagger')::int, 0) + (v ->> 'n')::int, 'stagger_by', uid);$B$),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 휘청여 반격하지 못합니다.');$A$,
$B$    if rfx ? 'stagger_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'stagger_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 0.7 * (least(0.4, 0.8 / greatest(1, n_act)) + 0.8 * greatest(1, n_act) / 7.0), 'guard'); end if;
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 휘청여 반격하지 못합니다.');$B$),
      -- 연막으로 빗나간 공격: 막아 준 몫
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure, 1,
$A$        perform public.world_raid_say(p_raid, 'miss', '연막 속에서 ' || rd.boss_name || '의 공격이 빗나갔습니다.');$A$,
$B$        perform public.world_raid_credit(p_raid, nullif(rfx -> 'smoke' ->> 'by', '')::uuid, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul * 0.7, 'guard');
        perform public.world_raid_say(p_raid, 'miss', '연막 속에서 ' || rd.boss_name || '의 공격이 빗나갔습니다.');$B$),
      -- world_raid_hit -------------------------------------------------------------------------
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure, 1,
$A$      m := pm; f := pm.fx; who := pm.owner_id; p_raw := p_raw * 0.5;$A$,
$B$      perform public.world_raid_credit(p_raid, pm.owner_id, p_raw * 0.5 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0), 'guard');
      m := pm; f := pm.fx; who := pm.owner_id; p_raw := p_raw * 0.5;$B$),
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure, 1,
$A$    if f ? 'evade' then f := case when (f -> 'evade' ->> 'n')::int <= 1$A$,
$B$    if f -> 'evade' ->> 'by' is not null and f -> 'evade' ->> 'by' <> who::text then
      perform public.world_raid_credit(p_raid, (f -> 'evade' ->> 'by')::uuid, p_raw * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0)
        * (f -> 'evade' ->> 'pct')::numeric / greatest(1, coalesce((m.stats ->> 'eva')::numeric, 0) + (f -> 'evade' ->> 'pct')::numeric), 'guard'); end if;
    if f ? 'evade' then f := case when (f -> 'evade' ->> 'n')::int <= 1$B$),
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure, 1,
$A$  if f ? 'ward' then
    d := d * (1 - (f -> 'ward' ->> 'pct')::numeric / 100.0);$A$,
$B$  if f ? 'ward' then
    if f -> 'ward' ->> 'by' is not null and f -> 'ward' ->> 'by' <> who::text then
      perform public.world_raid_credit(p_raid, (f -> 'ward' ->> 'by')::uuid, d * (f -> 'ward' ->> 'pct')::numeric / 100.0, 'guard'); end if;
    d := d * (1 - (f -> 'ward' ->> 'pct')::numeric / 100.0);$B$),
      -- 호법 신장: 줄인 몫 + 끌어와 맞은 피해 전부를 막아 준 피해로(pct를 표시로 씀)
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure, 1,
$A$  if f ? 'taunt' then
    d := d * (1 - (f -> 'taunt' ->> 'pct')::numeric / 100.0);$A$,
$B$  if f ? 'taunt' then
    perform public.world_raid_credit(p_raid, who, d * (f -> 'taunt' ->> 'pct')::numeric / 100.0, 'guard'); pct := -1;
    d := d * (1 - (f -> 'taunt' ->> 'pct')::numeric / 100.0);$B$),
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
  perform public.world_raid_credit(p_raid, who, d, case when pct = -1 then 'guard' else 'taken' end);$B$),
      -- 정산: 점수를 한 번 적고 시작(별채 보상 트리거가 상태가 바뀔 때 contrib을 읽음)
      ('public.world_raid_settle(uuid,boolean)'::regprocedure, 1,
$A$  update public.world_raids set status = case when p_won then 'won' else 'failed' end, ended_at = now(), intent = null, updated_at = now() where raid_id = p_raid;$A$,
$B$  perform public.world_raid_recontrib(p_raid);
  update public.world_raids set status = case when p_won then 'won' else 'failed' end, ended_at = now(), intent = null, updated_at = now() where raid_id = p_raid;$B$),
      -- 스냅샷: 읽을 때 점수 계산, 갈래도 내준다
      ('public.world_raid_snapshot_core(uuid)'::regprocedure, 1,
$A$logs jsonb; tot numeric;$A$,
$B$logs jsonb; tot numeric; ck numeric;$B$),
      ('public.world_raid_snapshot_core(uuid)'::regprocedure, 1,
$A$  select coalesce(sum(contrib), 0) into tot from public.world_raid_members where raid_id = rid;$A$,
$B$  ck := public.world_raid_k(rid);
  select coalesce(sum(public.world_raid_score(rd.kind, level, credits, stats, contrib, ck)), 0) into tot from public.world_raid_members where raid_id = rid;$B$),
      ('public.world_raid_snapshot_core(uuid)'::regprocedure, 1,
$A$'share', case when tot > 0 then round(x.contrib / tot * 100, 1) else 0 end,$A$,
$B$'share', case when tot > 0 then round(public.world_raid_score(rd.kind, x.level, x.credits, x.stats, x.contrib, ck) / tot * 100, 1) else 0 end, 'credits', coalesce(x.credits, '{}'::jsonb),$B$)
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
