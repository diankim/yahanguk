-- 7.7.4 — 기여도 일원화 ②(사용자 요청 2026-11-01): 귀허의 주인·파티 토벌도 합동 토벌(20261104202200)과 같은 공식 world_contrib_score로 센다.
--   준 피해 + 0.75×늘려 준 피해 + 0.4×공격력×기술 횟수 + K×(막아 준 피해 + 동료 회복 + ½자기 회복 + ½받아 낸 피해)
--   K = 1.5 × 참가자 평균 공격력 ÷ 요괴 한 대(귀허: (35+4×단계)×인원 배율 · 파티 토벌: 4+0.7×(요괴Lv+3)).
-- 귀허의 주인(world_gw_members.credits): 효과에 건 사람(by)을 적고, 결계·북돋움·약점·급소·보호막·진언·대신 막기·피할 길·연막·
--   묶은 손길(봉인 사슬·흐름 끊기)·퇴마 결계(물살·사슬 물살·소용돌이)·호법 신장·영력 보급·회복(기술·회복품)·받은 피해를 같은 갈래로 센다.
--   기술 회복의 「회복」 수치는 이제 기술을 쓴 사람에게 붙는다(전에는 받은 사람 칸에 쌓였다).
-- 파티 토벌: 협동 기술이 없으므로 준 피해·받은 피해·자기 회복만(world_pfight_members.dmg·taken·heal, 20261104202300).
--   공격력은 라운드를 열 때 이미 부르는 world_combat_stats에서 차례 줄(turn_order)에 함께 적는다.
-- 기여도는 화면 표시용(귀허·파티 토벌 보상은 기여도와 상관없음). 스냅샷 members[].share·credits.
-- 호위 무사 「전장 지휘」(모두 공격 +15% 세 번)를 「파진 돌격」(제 공격 +30% 세 번, 나에게만)으로 바꾼다 — 남을 북돋우는 몫이 커서
--   기여도 정산이 호위 무사 쪽으로 쏠렸다(사용자 결정). 효과 종류는 might 그대로, 대상만 self.
alter table public.world_gw_members add column if not exists credits jsonb not null default '{}'::jsonb;

update public.world_coop_skills set skill_name = '파진 돌격', target = 'self', effect = '{"n": 3, "pct": 30, "type": "might"}'::jsonb,
  description = '제 다음 세 번 공격 피해 +30%.', exp_text = '진을 깨고 앞장서 돌격했습니다'
 where skill_id = 'an_command';

create or replace function public.world_gw_credit(p_fight uuid, p_owner uuid, p_amt numeric, p_kind text)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
begin
  if p_owner is null or coalesce(p_amt, 0) <= 0 or p_kind is null then return; end if;
  update public.world_gw_members set credits = jsonb_set(coalesce(credits, '{}'::jsonb), array[p_kind], to_jsonb(round(coalesce((credits ->> p_kind)::numeric, 0) + p_amt, 1)))
   where fight_id = p_fight and owner_id = p_owner;
end $function$;

-- 공격 한 번: 동료가 늘려 준 몫은 건 사람에게(때린 사람 몫에서 뺀다)
create or replace function public.world_gw_credit_hit(p_fight uuid, p_uid uuid, p_d numeric, p_cr boolean, p_mb text, p_mp numeric, p_eb text, p_ep numeric,
  p_cb text, p_cp numeric, p_cn text, p_crit numeric)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare c numeric := coalesce(p_d, 0); ex numeric;
begin
  if c <= 0 then return; end if;
  if p_mb is not null and p_mb <> p_uid::text and coalesce(p_mp, 0) > 0 then ex := p_d - p_d / (1 + p_mp / 100.0); perform public.world_gw_credit(p_fight, p_mb::uuid, ex, 'boost'); c := c - ex; end if;
  if p_eb is not null and p_eb <> p_uid::text and coalesce(p_ep, 0) > 0 then ex := p_d - p_d / (1 + p_ep / 100.0); perform public.world_gw_credit(p_fight, p_eb::uuid, ex, 'boost'); c := c - ex; end if;
  if p_cr and p_cn is not null and p_cn not in ('true', p_uid::text) then ex := p_d - p_d / 1.5; perform public.world_gw_credit(p_fight, p_cn::uuid, ex, 'boost'); c := c - ex;
  elsif p_cr and p_cb is not null and p_cb <> p_uid::text and coalesce(p_cp, 0) > 0 then
    ex := (p_d - p_d / 1.5) * p_cp / greatest(1, coalesce(p_crit, 5) + p_cp); perform public.world_gw_credit(p_fight, p_cb::uuid, ex, 'boost'); c := c - ex; end if;
  perform public.world_gw_credit(p_fight, p_uid, greatest(0, c), 'dmg');
end $function$;

-- 체력 단위 → 피해 단위
create or replace function public.world_gw_k(p_fight uuid)
returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare aa numeric; n int; ph int;
begin
  select avg((stats ->> 'attack')::numeric), count(*) into aa, n from public.world_gw_members where fight_id = p_fight;
  select phase into ph from public.world_gw_fights where fight_id = p_fight;
  if aa is null then return 1; end if;
  return 1.5 * aa / ((35 + 4 * coalesce(ph, 1)) * case n when 1 then 1 when 2 then 0.95 when 3 then 0.8 else 0.85 end);
end $function$;
create or replace function public.world_gw_shares(p_fight uuid)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare k numeric := public.world_gw_k(p_fight); res jsonb;
begin
  with s as (select owner_id, public.world_contrib_score(credits, (stats ->> 'attack')::numeric, k) v from public.world_gw_members where fight_id = p_fight)
  select coalesce(jsonb_object_agg(s.owner_id, case when z.t > 0 then round(s.v / z.t * 100, 1) else 0 end), '{}'::jsonb) into res
    from s, (select sum(v) t from s) z;
  return res;
end $function$;

-- 파티 토벌: 준 피해·받은 피해·자기 회복
create or replace function public.world_pfight_shares(p_fight uuid)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare f public.world_pfights%rowtype; aa numeric; k numeric; res jsonb;
begin
  select * into f from public.world_pfights where fight_id = p_fight;
  if not found then return '{}'::jsonb; end if;
  select avg((o ->> 'atk')::numeric) into aa from jsonb_array_elements(coalesce(f.turn_order, '[]'::jsonb)) o where o ? 'atk';
  k := 1.5 * coalesce(aa, 0) / (4 + 0.7 * (coalesce(f.mlevel, 1) + 3));
  with s as (select pm.owner_id, public.world_contrib_score(jsonb_build_object('dmg', pm.dmg, 'taken', pm.taken, 'heal_self', pm.heal), 0, k) v
               from public.world_pfight_members pm where pm.fight_id = p_fight)
  select coalesce(jsonb_object_agg(s.owner_id, case when z.t > 0 then round(s.v / z.t * 100, 1) else 0 end), '{}'::jsonb) into res
    from s, (select sum(v) t from s) z;
  return res;
end $function$;

do $p$
declare r record; d text; n int; own text; fn text;
begin
  for r in
    select * from (values
      -- world_gw_resolve ① 효과에 건 사람
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$v_hit uuid[] := '{}'; v_miss numeric;$A$,
$B$v_hit uuid[] := '{}'; v_miss numeric;
  v_mb text; v_mp numeric; v_eb text; v_ep numeric; v_cb text; v_cp numeric; v_cn text; v_brk uuid;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 9,
$A$jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int)$A$,
$B$jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int, 'by', m.owner_id)$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$jsonb_build_object('might', jsonb_build_object('n', 1, 'pct', (e ->> 'pct')::int))$A$,
$B$jsonb_build_object('might', jsonb_build_object('n', 1, 'pct', (e ->> 'pct')::int, 'by', m.owner_id))$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$jsonb_build_object('smoke', jsonb_build_object('n', (e ->> 'n')::int, 'miss', (e ->> 'miss')::int))$A$,
$B$jsonb_build_object('smoke', jsonb_build_object('n', (e ->> 'n')::int, 'miss', (e ->> 'miss')::int, 'by', m.owner_id))$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$jsonb_build_object('gward', true)$A$,
$B$jsonb_build_object('gward', m.owner_id)$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$jsonb_build_object('critnext', true)$A$,
$B$jsonb_build_object('critnext', m.owner_id)$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$jsonb_build_object('shield', (e ->> 'amt')::int)$A$,
$B$jsonb_build_object('shield', (e ->> 'amt')::int, 'shield_by', m.owner_id)$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$when 'break' then broke := true;$A$,
$B$when 'break' then broke := true; v_brk := m.owner_id;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$'block', coalesce((vbfx ->> 'block')::int, 0) + 1); sealed := true;$A$,
$B$'block', coalesce((vbfx ->> 'block')::int, 0) + 1, 'block_by', m.owner_id); sealed := true;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + (e ->> 'n')::int); delayed := true;$A$,
$B$jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + (e ->> 'n')::int, 'block_by', m.owner_id); delayed := true;$B$),
      -- ⓪ 「나에게만」 기술 · 기술 횟수
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$    tgt := coalesce(nullif(m.act ->> 't', '')::uuid, m.owner_id);$A$,
$B$    tgt := case when sk.target = 'self' then m.owner_id else coalesce(nullif(m.act ->> 't', '')::uuid, m.owner_id) end;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$     where fight_id = p_fight and owner_id = m.owner_id;
    tgt :=$A$,
$B$     where fight_id = p_fight and owner_id = m.owner_id;
    perform public.world_gw_credit(p_fight, m.owner_id, 1, 'skill');
    tgt :=$B$),
      -- ⓪ 회복·소생·영력: 실제로 채운 만큼(기술 「회복」 수치는 쓴 사람에게)
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$      when 'heal' then update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.5)::int), heal = heal + round((e ->> 'amt')::int * 0.5)::int where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$A$,
$B$      when 'heal' then
        select least(round((e ->> 'amt')::int * 0.5), 100 - x.hp) into d from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0;
        perform public.world_gw_credit(p_fight, m.owner_id, d, case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.5)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$      when 'heal_all' then update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.5)::int) where fight_id = p_fight and out_rounds = 0;$A$,
$B$      when 'heal_all' then
        select sum(least(round((e ->> 'amt')::int * 0.5), 100 - x.hp)) into d from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0;
        perform public.world_gw_credit(p_fight, m.owner_id, d, 'heal');
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.5)::int) where fight_id = p_fight and out_rounds = 0;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.5)::int), nameless = false where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$A$,
$B$        select least(round((e ->> 'amt')::int * 0.5), 100 - x.hp) into d from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0;
        perform public.world_gw_credit(p_fight, m.owner_id, d, case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.5)::int), nameless = false where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$        update public.world_gw_members set out_rounds = 0, hp = (e ->> 'hp')::int where fight_id = p_fight and owner_id = tgt and out_rounds > 0;$A$,
$B$        if exists (select 1 from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds > 0) then
          perform public.world_gw_credit(p_fight, m.owner_id, (e ->> 'hp')::int, 'heal'); end if;
        update public.world_gw_members set out_rounds = 0, hp = (e ->> 'hp')::int where fight_id = p_fight and owner_id = tgt and out_rounds > 0;$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$      when 'sp' then update public.world_characters set spiritual_power = least(100, spiritual_power + (e ->> 'amt')::int), updated_at = now() where owner_id = tgt;$A$,
$B$      when 'sp' then
        if tgt <> m.owner_id then perform public.world_gw_credit(p_fight, m.owner_id, (select greatest(0, least((e ->> 'amt')::int, 100 - x.spiritual_power)) from public.world_characters x where x.owner_id = tgt)
          * coalesce((m.stats ->> 'attack')::numeric, 0) * 0.05, 'boost'); end if;
        update public.world_characters set spiritual_power = least(100, spiritual_power + (e ->> 'amt')::int), updated_at = now() where owner_id = tgt;$B$),
      -- ① 공격: 걸려 있던 효과의 건 사람을 적어 두고, 준 피해를 나눈다
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$      mul := 1;
      n := coalesce((vfx -> 'might' ->> 'n')::int, 0);$A$,
$B$      v_mb := case when coalesce((vfx -> 'might' ->> 'n')::int, 0) > 0 then vfx -> 'might' ->> 'by' end; v_mp := coalesce((vfx -> 'might' ->> 'pct')::numeric, 0);
      v_cb := case when coalesce((vfx -> 'crit' ->> 'n')::int, 0) > 0 then vfx -> 'crit' ->> 'by' end; v_cp := coalesce((vfx -> 'crit' ->> 'pct')::numeric, 0); v_cn := vfx ->> 'critnext';
      v_eb := case when coalesce((vbfx -> 'expose' ->> 'n')::int, 0) > 0 then vbfx -> 'expose' ->> 'by' end; v_ep := coalesce((vbfx -> 'expose' ->> 'pct')::numeric, 0);
      mul := 1;
      n := coalesce((vfx -> 'might' ->> 'n')::int, 0);$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 2,
$A$update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;$A$,
$B$update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
          perform public.world_gw_credit_hit(p_fight, m.owner_id, d, cr, v_mb, v_mp, v_eb, v_ep, v_cb, v_cp, v_cn, coalesce((m.stats ->> 'crit')::numeric, 5));$B$),
      -- 회복품(나 또는 동료)
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$        update public.world_gw_members set hp = least(100, hp + round(d)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$A$,
$B$        perform public.world_gw_credit(p_fight, m.owner_id, (select least(round(d), 100 - x.hp) from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0),
          case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set hp = least(100, hp + round(d)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$B$),
      -- ② 퇴마 결계가 꺾은 사슬 물살·소용돌이
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$        perform public.world_gw_hit(p_fight, m.owner_id, 60 * case when broke then 0.5 else 1 end, r, '사슬이 끌어당긴 물살에', true);$A$,
$B$        if broke then perform public.world_gw_credit(p_fight, v_brk, 30 * 0.7, 'guard'); end if;
        perform public.world_gw_hit(p_fight, m.owner_id, 60 * case when broke then 0.5 else 1 end, r, '사슬이 끌어당긴 물살에', true);$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$      update public.world_gw_members x set hp = greatest(1, (x.hp * case when broke or x.fx ? 'gward' then 0.75 else 0.5 end)::int), fx = x.fx - 'gward'$A$,
$B$      if broke then perform public.world_gw_credit(p_fight, v_brk, (select sum(x.hp * 0.25) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0), 'guard'); end if;
      update public.world_gw_members x set hp = greatest(1, (x.hp * case when broke or x.fx ? 'gward' then 0.75 else 0.5 end)::int), fx = x.fx - 'gward'$B$),
      -- ④ 반격: 퇴마 결계·묶은 손길·연막·피할 길·대신 막기
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 loop
        perform public.world_gw_hit(p_fight, m.owner_id, raw * 0.9 * case when broke then 0.5 else 1 end, r, '쏟아지는 물살에', true);$A$,
$B$      if broke then perform public.world_gw_credit(p_fight, v_brk, raw * 0.9 * 0.5 * 0.7 * (select count(*) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0), 'guard'); end if;
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 loop
        perform public.world_gw_hit(p_fight, m.owner_id, raw * 0.9 * case when broke then 0.5 else 1 end, r, '쏟아지는 물살에', true);$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$      perform public.world_gw_say(p_fight, r, 'good', '주인의 손길이 묶여 허공을 가릅니다.');$A$,
$B$      perform public.world_gw_credit(p_fight, nullif(vbfx ->> 'block_by', '')::uuid, raw * 0.7 * (select case when count(*) >= 4 then 2 when count(*) = 3 then 1.5 else 1 end from public.world_gw_members x where x.fight_id = p_fight), 'guard');
      perform public.world_gw_say(p_fight, r, 'good', '주인의 손길이 묶여 허공을 가릅니다.');$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$          perform public.world_gw_say(p_fight, r, 'miss', '연막 속에서 주인의 손길이 ' || m.name || '을(를) 비껴갑니다.');$A$,
$B$          perform public.world_gw_credit(p_fight, nullif(vbfx -> 'smoke' ->> 'by', '')::uuid, raw * 0.7, 'guard');
          perform public.world_gw_say(p_fight, r, 'miss', '연막 속에서 주인의 손길이 ' || m.name || '을(를) 비껴갑니다.');$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$          if vfx ? 'evade' then update public.world_gw_members x set fx = case when (x.fx -> 'evade' ->> 'n')::int > 1$A$,
$B$          if vfx -> 'evade' ->> 'by' is not null and vfx -> 'evade' ->> 'by' <> m.owner_id::text then
            perform public.world_gw_credit(p_fight, (vfx -> 'evade' ->> 'by')::uuid, raw * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0)
              * (vfx -> 'evade' ->> 'pct')::numeric / greatest(1, coalesce((m.stats ->> 'eva')::numeric, 0) + (vfx -> 'evade' ->> 'pct')::numeric), 'guard'); end if;
          if vfx ? 'evade' then update public.world_gw_members x set fx = case when (x.fx -> 'evade' ->> 'n')::int > 1$B$),
      ('public.world_gw_resolve(uuid)'::regprocedure, 1,
$A$          perform public.world_gw_hit(p_fight, cover_by, raw * 0.5, r,$A$,
$B$          perform public.world_gw_credit(p_fight, cover_by, raw * 0.5 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0), 'guard');
          perform public.world_gw_hit(p_fight, cover_by, raw * 0.5, r,$B$),
      -- world_gw_hit: 결계·진언·호법 신장·보호막·받은 피해
      ('public.world_gw_hit(uuid,uuid,numeric,integer,text,boolean)'::regprocedure, 1,
$A$sh int; ab int;$A$,
$B$sh int; ab int; tf boolean := false;$B$),
      ('public.world_gw_hit(uuid,uuid,numeric,integer,text,boolean)'::regprocedure, 1,
$A$  if p_aoe and vfx ? 'gward' then d := d * 0.5; vfx := vfx - 'gward'; end if;$A$,
$B$  if p_aoe and vfx ? 'gward' then
    if vfx ->> 'gward' not in ('true', p_uid::text) then perform public.world_gw_credit(p_fight, (vfx ->> 'gward')::uuid, d * 0.5, 'guard'); end if;
    d := d * 0.5; vfx := vfx - 'gward'; end if;$B$),
      ('public.world_gw_hit(uuid,uuid,numeric,integer,text,boolean)'::regprocedure, 1,
$A$  if n > 0 then d := d * (1 - coalesce((vfx -> 'ward' ->> 'pct')::numeric, 0) / 100.0);$A$,
$B$  if n > 0 and vfx -> 'ward' ->> 'by' is not null and vfx -> 'ward' ->> 'by' <> p_uid::text then
    perform public.world_gw_credit(p_fight, (vfx -> 'ward' ->> 'by')::uuid, d * coalesce((vfx -> 'ward' ->> 'pct')::numeric, 0) / 100.0, 'guard'); end if;
  if n > 0 then d := d * (1 - coalesce((vfx -> 'ward' ->> 'pct')::numeric, 0) / 100.0);$B$),
      ('public.world_gw_hit(uuid,uuid,numeric,integer,text,boolean)'::regprocedure, 1,
$A$  if n > 0 then d := d * (1 - coalesce((vfx -> 'taunt' ->> 'pct')::numeric, 0) / 100.0);$A$,
$B$  if n > 0 then perform public.world_gw_credit(p_fight, p_uid, d * coalesce((vfx -> 'taunt' ->> 'pct')::numeric, 0) / 100.0, 'guard'); tf := true; end if;
  if n > 0 then d := d * (1 - coalesce((vfx -> 'taunt' ->> 'pct')::numeric, 0) / 100.0);$B$),
      ('public.world_gw_hit(uuid,uuid,numeric,integer,text,boolean)'::regprocedure, 1,
$A$  if sh > 0 and d > 0 then ab := least(sh, round(d)::int); d := d - ab;$A$,
$B$  if sh > 0 and d > 0 then ab := least(sh, round(d)::int); d := d - ab;
    if vfx ->> 'shield_by' is not null and vfx ->> 'shield_by' <> p_uid::text then perform public.world_gw_credit(p_fight, (vfx ->> 'shield_by')::uuid, ab, 'guard'); end if;$B$),
      ('public.world_gw_hit(uuid,uuid,numeric,integer,text,boolean)'::regprocedure, 1,
$A$  return public.world_gw_hurt(p_fight, p_uid, round(d)::int, p_round, p_why);$A$,
$B$  perform public.world_gw_credit(p_fight, p_uid, round(d), case when tf then 'guard' else 'taken' end);
  return public.world_gw_hurt(p_fight, p_uid, round(d)::int, p_round, p_why);$B$),
      -- 스냅샷: 기여도 몫과 갈래
      ('public.world_gw_snapshot(uuid)'::regprocedure, 1,
$A$'dmg', m.dmg, 'heal', m.heal, 'taken', m.taken, 'falls', m.falls,$A$,
$B$'dmg', m.dmg, 'heal', m.heal, 'taken', m.taken, 'falls', m.falls, 'credits', m.credits, 'share', coalesce((public.world_gw_shares(m.fight_id) ->> m.owner_id::text)::numeric, 0),$B$),
      -- 파티 토벌: 라운드를 열 때 공격력도 적고, 스냅샷에 몫
      ('public.world_pfight_round(uuid,integer)'::regprocedure, 1,
$A$jsonb_build_object('id', s.owner_id, 'spd', s.spd)$A$,
$B$jsonb_build_object('id', s.owner_id, 'spd', s.spd, 'atk', s.atk)$B$),
      ('public.world_pfight_round(uuid,integer)'::regprocedure, 1,
$A$coalesce((cs -> 'stats' ->> 'perception')::numeric, 0) * 0.5) spd$A$,
$B$coalesce((cs -> 'stats' ->> 'perception')::numeric, 0) * 0.5) spd, coalesce((cs ->> 'attack')::numeric, 0) atk$B$),
      ('public.world_pfight_snapshot(uuid)'::regprocedure, 1,
$A$'dmg', pm.dmg, 'taken', pm.taken, 'heal', pm.heal)$A$,
$B$'dmg', pm.dmg, 'taken', pm.taken, 'heal', pm.heal, 'share', coalesce((public.world_pfight_shares(p_fight) ->> pm.owner_id::text)::numeric, 0))$B$)
    ) x(fn, cnt, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> r.cnt then raise exception '7.7.4 contrib anchor in % (% vs %): %', r.fn, n, r.cnt, left(r.a, 70); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
  end loop;
  -- 새 도우미: 조사원은 못 부르고, 부르는 함수의 주인 역할만
  foreach fn in array array['public.world_gw_credit(uuid,uuid,numeric,text)', 'public.world_gw_credit_hit(uuid,uuid,numeric,boolean,text,numeric,text,numeric,text,numeric,text,numeric)',
                            'public.world_gw_k(uuid)', 'public.world_gw_shares(uuid)', 'public.world_pfight_shares(uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', fn);
    for own in select distinct p.proowner::regrole::text from pg_proc p
                where p.oid in ('public.world_gw_resolve(uuid)'::regprocedure, 'public.world_gw_hit(uuid,uuid,numeric,integer,text,boolean)'::regprocedure,
                                'public.world_gw_snapshot(uuid)'::regprocedure, 'public.world_pfight_snapshot(uuid)'::regprocedure) loop
      if own <> 'postgres' then execute format('grant execute on function %s to %I', fn, own); end if;
    end loop;
  end loop;
end $p$;

update public.world_app_meta set value = '20261104202400' where key = 'db_version';
