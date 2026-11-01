-- 7.7.4 — 귀허의 주인: 협동 기술·기믹 전용 행동·암시(사용자 요청 2026-11-01 「너무 루즈하다」)
-- · 행동: 공격 · 방어 · 버티기(brace, 몸을 낮춰 막기만 — 모두를 치는 물살·소용돌이에 강함) · 기술(coop, 봉연과 같은 협동 기술 24가지)
--         · 이름 부르기(call, 이름 빼앗기에서 동료의 이름을 불러 되찾음) · 사슬 끊기(chain). 물품(item)·정화 부적(purify)은 뺐다.
-- · 기술 비용 = 영력(기력), 다시 쓰기 = 봉연의 초를 라운드(5초)로(올림). 라운드가 풀릴 때 기술이 먼저 걸리고 그다음 공격·반격.
-- · 기믹과 엮인 기술: 해독 침 = 사슬 풀기·이름 되찾기 / 야전 소생 = 물러난 동료 바로 복귀 / 퇴마 결계 = 물살·소용돌이 실패 피해 절반
--   / 파사 진언 = 그 동료의 물살·소용돌이 피해 절반 / 흐름 끊기 = 반격 막기 + 소용돌이 끊을 힘 절반 / 봉인 사슬 = 반격 막기·받는 피해 +15%·두 얼굴이 힘을 삼키지 못함
--   / 호법 신장 = 버티는 사람이 아니어도 소용돌이를 받아 낼 수 있음 / 대신 막기 = 그 라운드 그 동료를 노린 손길을 절반으로 대신 맞음.
-- · 암시: 다음 라운드에 모두를 치는 물살이 오면 그 라운드를 열 때 「기를 모으기 시작했습니다」 줄과 mech.aoe, 기믹 문구는 대처법을 대놓고 말하지 않고 넌지시.
-- · 끝난 싸움은 기록 200줄까지(실패 화면에서 되짚어 보기), 대기실은 지난 도전(last)을 알려 준다.
lock table public.world_gw_fights in share row exclusive mode;
alter table public.world_gw_members
  add column if not exists fx jsonb not null default '{}'::jsonb,
  add column if not exists cds jsonb not null default '{}'::jsonb;
alter table public.world_gw_fights add column if not exists bfx jsonb not null default '{}'::jsonb;

set role fn_owner_field;

-- 받는 피해(기믹 즉사 999는 world_gw_hurt를 바로 부른다): 능력치·방어/버티기·기술 효과(보호막·호신·진언·신장)를 거친 뒤 world_gw_hurt
create or replace function public.world_gw_hit(p_fight uuid, p_uid uuid, p_raw numeric, p_round int, p_why text, p_aoe boolean)
returns int language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare m public.world_gw_members%rowtype; d numeric := greatest(0, p_raw); vfx jsonb; av text; n int; sh int; ab int;
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid for update;
  if not found or m.out_rounds > 0 then return 0; end if;
  vfx := coalesce(m.fx, '{}'::jsonb); av := coalesce(m.act ->> 'a', 'guard');
  d := d * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((m.stats ->> 'inc')::numeric, 0) / 100.0);
  if av = 'brace' then d := d * case when p_aoe then 0.2 else 0.3 end;
  elsif av = 'guard' then d := d * 0.4; end if;
  if p_aoe and vfx ? 'gward' then d := d * 0.5; vfx := vfx - 'gward'; end if;
  n := coalesce((vfx -> 'ward' ->> 'n')::int, 0);
  if n > 0 then d := d * (1 - coalesce((vfx -> 'ward' ->> 'pct')::numeric, 0) / 100.0);
    vfx := case when n - 1 > 0 then jsonb_set(vfx, '{ward,n}', to_jsonb(n - 1)) else vfx - 'ward' end; end if;
  n := coalesce((vfx -> 'taunt' ->> 'n')::int, 0);
  if n > 0 then d := d * (1 - coalesce((vfx -> 'taunt' ->> 'pct')::numeric, 0) / 100.0);
    vfx := case when n - 1 > 0 then jsonb_set(vfx, '{taunt,n}', to_jsonb(n - 1)) else vfx - 'taunt' end; end if;
  sh := coalesce((vfx ->> 'shield')::int, 0);
  if sh > 0 and d > 0 then ab := least(sh, round(d)::int); d := d - ab;
    vfx := case when sh - ab > 0 then jsonb_set(vfx, '{shield}', to_jsonb(sh - ab)) else vfx - 'shield' end;
    perform public.world_gw_say(p_fight, p_round, 'good', m.name || ' — 방호 법구가 ' || ab || '을(를) 먼저 받아 냈습니다.'); end if;
  update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = p_uid;
  return public.world_gw_hurt(p_fight, p_uid, round(d)::int, p_round, p_why);
end $function$;
revoke all on function public.world_gw_hit(uuid, uuid, numeric, int, text, boolean) from public, anon, authenticated;

create or replace function public.world_gw_act(p_fight uuid, p_action text, p_target uuid default null, p_item text default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; a jsonb;
  sk public.world_coop_skills%rowtype; c public.world_characters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_action not in ('attack', 'guard', 'brace', 'coop', 'call', 'chain') then raise exception '알 수 없는 행동입니다.'; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if not found or f.status <> 'fight' then raise exception '싸움이 끝났습니다.'; end if;
  if now() >= f.round_ends_at then perform public.world_gw_resolve(p_fight); select * into f from public.world_gw_fights where fight_id = p_fight; end if;
  if f.status <> 'fight' then return public.world_gw_snapshot(p_fight); end if;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = uid for update;
  if not found then raise exception '이 싸움에 들지 않았습니다.'; end if;
  if me.out_rounds > 0 then raise exception '물러나 있습니다. %라운드 뒤 돌아옵니다.', me.out_rounds; end if;
  if p_target is not null and not exists (select 1 from public.world_gw_members where fight_id = p_fight and owner_id = p_target) then raise exception '함께 싸우는 조사원이 아닙니다.'; end if;
  if p_action = 'coop' then
    select * into sk from public.world_coop_skills where skill_id = coalesce(p_item, '');
    select * into c from public.world_characters where owner_id = uid;
    if sk.skill_id is null or sk.job_key is distinct from c.job_key then raise exception '쓸 수 없는 기술입니다.'; end if;
    if coalesce(c.combat_rank, 1) < sk.unlock_rank then raise exception '전투 숙련 %단계에 열리는 기술입니다.', sk.unlock_rank; end if;
    if coalesce((me.cds ->> sk.skill_id)::int, 0) > f.round then raise exception '%라운드 뒤에 다시 쓸 수 있습니다.', (me.cds ->> sk.skill_id)::int - f.round; end if;
    if coalesce(c.spiritual_power, 0) < sk.cost then raise exception '영력(기력)이 모자랍니다(%).', sk.cost; end if;
    if sk.target = 'ally' and p_target is null then p_target := uid; end if;
  end if;
  if p_action = 'call' and p_target is null then raise exception '이름을 부를 사람을 고르세요.'; end if;
  a := jsonb_build_object('a', p_action) || case when p_target is not null then jsonb_build_object('t', p_target) else '{}'::jsonb end
       || case when p_action = 'coop' then jsonb_build_object('s', p_item) when p_action = 'chain' then jsonb_build_object('c', coalesce(p_item, '')) else '{}'::jsonb end;
  update public.world_gw_members set act = a where fight_id = p_fight and owner_id = uid;
  perform public.world_gw_resolve(p_fight);
  return public.world_gw_snapshot(p_fight);
end $function$;

create or replace function public.world_gw_resolve(p_fight uuid)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare f public.world_gw_fights%rowtype; m record; a jsonb; av text; d numeric; boss_dmg numeric := 0; boss_heal numeric := 0; physical boolean;
  k text; vsum numeric := 0; tank_ok boolean := false; freed uuid[] := '{}'; tgt uuid; raw numeric; r int; alive int; cr boolean;
  sk public.world_coop_skills%rowtype; csp int; vbfx jsonb; vfx jsonb; tn text; e jsonb; aoe boolean; mul numeric; n int; need numeric;
  delayed boolean := false; sealed boolean := false; broke boolean := false; cover_by uuid; hit_who uuid;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return; end if;
  if now() < f.round_ends_at and exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and act is null) then return; end if;
  r := f.round; k := f.mech ->> 'k'; aoe := coalesce((f.mech ->> 'aoe')::boolean, false); vbfx := coalesce(f.bfx, '{}'::jsonb);
  -- ⓪ 기술이 먼저 걸린다
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and act ->> 'a' = 'coop' order by joined_at loop
    select * into sk from public.world_coop_skills where skill_id = m.act ->> 's';
    if sk.skill_id is null then continue; end if;
    select spiritual_power into csp from public.world_characters where owner_id = m.owner_id for update;
    if coalesce(csp, 0) < sk.cost then perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 영력이 모자라 「' || sk.skill_name || '」이(가) 흩어졌습니다.'); continue; end if;
    update public.world_characters set spiritual_power = spiritual_power - sk.cost, updated_at = now() where owner_id = m.owner_id;
    update public.world_gw_members set acts = acts + 1, cds = jsonb_set(cds, array[sk.skill_id], to_jsonb(r + greatest(1, ceil(sk.cooldown_s / 5.0)::int)))
     where fight_id = p_fight and owner_id = m.owner_id;
    tgt := coalesce(nullif(m.act ->> 't', '')::uuid, m.owner_id);
    select name into tn from public.world_gw_members where fight_id = p_fight and owner_id = tgt;
    e := sk.effect;
    case e ->> 'type'
      when 'ward' then update public.world_gw_members set fx = fx || jsonb_build_object('ward', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int)) where fight_id = p_fight and owner_id = tgt;
      when 'ward_all' then update public.world_gw_members set fx = fx || jsonb_build_object('ward', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int)) where fight_id = p_fight and out_rounds = 0;
      when 'might' then update public.world_gw_members set fx = fx || jsonb_build_object('might', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int)) where fight_id = p_fight and owner_id = tgt;
      when 'might_all' then update public.world_gw_members set fx = fx || jsonb_build_object('might', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int)) where fight_id = p_fight and out_rounds = 0;
      when 'rally' then update public.world_gw_members set fx = fx || jsonb_build_object('might', jsonb_build_object('n', 1, 'pct', (e ->> 'pct')::int)) where fight_id = p_fight and out_rounds = 0;
      when 'resonance' then update public.world_gw_members set fx = fx || jsonb_build_object('might', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int),
                                                                                          'ward', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int)) where fight_id = p_fight and out_rounds = 0;
      when 'expose' then vbfx := vbfx || jsonb_build_object('expose', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int), 'block', coalesce((vbfx ->> 'block')::int, 0) + 1); sealed := true;
      when 'heal' then update public.world_gw_members set hp = least(100, hp + (e ->> 'amt')::int), heal = heal + (e ->> 'amt')::int where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
      when 'heal_all' then update public.world_gw_members set hp = least(100, hp + (e ->> 'amt')::int) where fight_id = p_fight and out_rounds = 0;
      when 'cleanse_heal' then
        update public.world_gw_members set hp = least(100, hp + (e ->> 'amt')::int), nameless = false where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
        freed := freed || tgt;
      when 'revive' then
        update public.world_gw_members set out_rounds = 0, hp = (e ->> 'hp')::int where fight_id = p_fight and owner_id = tgt and out_rounds > 0;
      when 'cover' then update public.world_gw_members set fx = fx || jsonb_build_object('cover', tgt) where fight_id = p_fight and owner_id = m.owner_id;
      when 'gward' then update public.world_gw_members set fx = fx || jsonb_build_object('gward', true) where fight_id = p_fight and owner_id = tgt;
      when 'break' then broke := true;
      when 'taunt' then update public.world_gw_members set fx = fx || jsonb_build_object('taunt', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int, 'pres', (e ->> 'pres')::int)) where fight_id = p_fight and owner_id = m.owner_id;
      when 'crit_all' then update public.world_gw_members set fx = fx || jsonb_build_object('crit', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int)) where fight_id = p_fight and out_rounds = 0;
      when 'evade' then update public.world_gw_members set fx = fx || jsonb_build_object('evade', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int)) where fight_id = p_fight and owner_id = tgt;
      when 'smoke' then vbfx := vbfx || jsonb_build_object('smoke', jsonb_build_object('n', (e ->> 'n')::int, 'miss', (e ->> 'miss')::int));
      when 'crit_next' then update public.world_gw_members set fx = fx || jsonb_build_object('critnext', true) where fight_id = p_fight and owner_id = tgt;
      when 'delay' then vbfx := vbfx || jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + (e ->> 'n')::int); delayed := true;
      when 'shield' then update public.world_gw_members set fx = fx || jsonb_build_object('shield', (e ->> 'amt')::int) where fight_id = p_fight and owner_id = tgt;
      when 'sp' then update public.world_characters set spiritual_power = least(100, spiritual_power + (e ->> 'amt')::int), updated_at = now() where owner_id = tgt;
      else null;
    end case;
    perform public.world_gw_say(p_fight, r, 'skill', m.name || ' — 「' || sk.skill_name || '」' || case when sk.target = 'ally' and tgt <> m.owner_id then ' → ' || coalesce(tn, '') else '' end || ' · ' || sk.exp_text
      || case e ->> 'type' when 'cleanse_heal' then case when k = 'chain' then ' (사슬이 느슨해집니다)' when k = 'name' then ' (흐려진 이름이 또렷해집니다)' else '' end
                           when 'delay' then case when k = 'vortex' then ' (물살이 잠시 멎습니다)' else '' end
                           when 'expose' then case when k = 'face' then ' (주인의 입이 사슬에 묶입니다)' else '' end
                           when 'break' then ' (물의 기세가 꺾입니다)' else '' end || '.');
  end loop;
  -- ① 조사원들의 행동
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 order by joined_at loop
    a := coalesce(m.act, '{"a":"guard"}'::jsonb); av := a ->> 'a';
    if av = 'coop' then continue; end if;
    if m.act is not null then update public.world_gw_members set acts = acts + 1 where fight_id = p_fight and owner_id = m.owner_id; end if;
    select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
    if av = 'attack' then
      mul := 1;
      n := coalesce((vfx -> 'might' ->> 'n')::int, 0);
      if n > 0 then mul := mul * (1 + (vfx -> 'might' ->> 'pct')::numeric / 100); vfx := case when n > 1 then jsonb_set(vfx, '{might,n}', to_jsonb(n - 1)) else vfx - 'might' end; end if;
      cr := vfx ? 'critnext';
      if cr then vfx := vfx - 'critnext'; end if;
      n := coalesce((vfx -> 'crit' ->> 'n')::int, 0);
      if not cr then cr := random() * 100 < coalesce((m.stats ->> 'crit')::numeric, 5) + case when n > 0 then (vfx -> 'crit' ->> 'pct')::numeric else 0 end; end if;
      if n > 0 then vfx := case when n > 1 then jsonb_set(vfx, '{crit,n}', to_jsonb(n - 1)) else vfx - 'crit' end; end if;
      n := coalesce((vbfx -> 'expose' ->> 'n')::int, 0);
      if n > 0 then mul := mul * (1 + (vbfx -> 'expose' ->> 'pct')::numeric / 100); vbfx := case when n > 1 then jsonb_set(vbfx, '{expose,n}', to_jsonb(n - 1)) else vbfx - 'expose' end; end if;
      update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;
      d := coalesce((m.stats ->> 'attack')::numeric, 50) * (0.9 + random() * 0.2) * case when cr then 1.5 else 1 end * mul;
      physical := coalesce(m.stats ->> 'style', 'melee') in ('melee', 'ranged');
      if m.nameless then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 이름을 잃어 칼끝이 주인에게 닿지 않습니다.');
      elsif k = 'face' and ((f.mech ->> 'face' = 'human') <> physical) then
        if sealed then
          d := d * 0.5; boss_dmg := boss_dmg + d;
          update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
          perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — 사슬에 묶인 주인이 힘을 삼키지 못합니다. ' || round(d) || '의 피해.');
        else
          boss_heal := boss_heal + round(d * 0.5);
          perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — ' || case when physical then '요괴의 얼굴에 칼을 대자' else '사람의 얼굴에 술법을 쓰자' end || ' 주인이 그 힘을 삼켜 ' || round(d * 0.5) || ' 회복합니다.');
        end if;
      else
        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;
        update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
        perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — ' || round(d) || case when cr then '의 치명타.' else '의 피해.' end);
      end if;
    elsif av in ('guard', 'brace') then
      if k = 'vortex' and (m.owner_id::text = f.mech ->> 'tank' or (av = 'brace' and vfx ? 'taunt')) then tank_ok := true;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — ' || case when av = 'brace' then '몸을 낮춰 소용돌이를 정면으로 받아 냅니다.' else '방패를 세우고 물살을 버팁니다.' end);
      elsif av = 'brace' and m.act is not null then
        perform public.world_gw_say(p_fight, r, 'guard', m.name || ' — 몸을 낮추고 버팁니다.');
      end if;
    elsif av = 'call' then
      tgt := nullif(a ->> 't', '')::uuid;
      select name into tn from public.world_gw_members where fight_id = p_fight and owner_id = tgt;
      if k <> 'name' or not exists (select 1 from public.world_gw_members where fight_id = p_fight and owner_id = tgt and nameless) then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — ' || coalesce(tn, '') || '을(를) 불렀지만 메아리만 돌아옵니다.');
      elsif tgt <> m.owner_id or random() < 0.3 then
        update public.world_gw_members set nameless = false where fight_id = p_fight and owner_id = tgt;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — 「' || tn || '!」 부르는 소리에 물에 녹던 이름이 되돌아옵니다.');
      else
        perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — 제 이름을 스스로 부르려 했지만 목소리가 물에 녹았습니다.');
      end if;
    elsif av = 'chain' then
      if k <> 'chain' then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 끊을 사슬이 없습니다.');
      elsif a ->> 'c' = f.mech -> 'colors' ->> m.owner_id::text then
        freed := freed || m.owner_id;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — 자기 사슬(' || (a ->> 'c') || ')을 끊었습니다.');
      else
        perform public.world_gw_hurt(p_fight, m.owner_id, 20, r, '남의 사슬(' || coalesce(a ->> 'c', '?') || ')을 쳐 되튕긴 사슬에');
      end if;
    end if;
  end loop;
  -- ② 기믹 결과
  if k = 'chain' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '끊지 못한 사슬에 끌려가');
    end loop;
    if exists (select 1 from public.world_gw_members where fight_id = p_fight and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text) then
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 loop
        perform public.world_gw_hit(p_fight, m.owner_id, 60 * case when broke then 0.5 else 1 end, r, '사슬이 끌어당긴 물살에', true);
      end loop;
    end if;
  elsif k = 'name' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and nameless loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '이름을 끝내 찾지 못해');
    end loop;
  elsif k = 'vortex' then
    need := coalesce((f.mech ->> 'need')::numeric, 0) * case when delayed then 0.5 else 1 end;
    if tank_ok and vsum >= need then
      boss_dmg := boss_dmg + round(vsum * 0.5);
      perform public.world_gw_say(p_fight, r, 'good', '소용돌이를 끊었습니다! 흩어진 물살이 주인에게 되돌아가 ' || round(vsum * 0.5) || '의 피해를 더 줍니다.');
    else
      perform public.world_gw_say(p_fight, r, 'bad', case when not tank_ok then '쏠린 물살을 받아 낸 사람이 없었습니다. ' else '왕좌를 몰아친 힘이 모자랐습니다. ' end
        || '소용돌이가 모두를 삼키고 주인이 더 사나워집니다.' || case when broke then ' (퇴마 결계가 물살을 절반으로 꺾었습니다)' else '' end);
      update public.world_gw_members x set hp = greatest(1, (x.hp * case when broke or x.fx ? 'gward' then 0.75 else 0.5 end)::int), fx = x.fx - 'gward'
       where x.fight_id = p_fight and x.out_rounds = 0;
      update public.world_gw_fights set enrage = enrage + 1 where fight_id = p_fight;
      f.enrage := f.enrage + 1;
    end if;
  end if;
  -- ③ 보스 체력
  update public.world_gw_fights set hp = least(max_hp, greatest(0, hp - round(boss_dmg)::int + round(boss_heal)::int)), updated_at = now() where fight_id = p_fight returning * into f;
  if f.hp <= 0 then update public.world_gw_fights set bfx = vbfx where fight_id = p_fight; perform public.world_gw_settle(p_fight, true); return; end if;
  -- ④ 보스의 반격(기믹 라운드에는 쉰다): 모으던 기운이 터지는 라운드(mech.aoe)에는 모두에게 물살, 아니면 이목에 비례해 하나를 노림
  if k in ('face', 'normal') then
    raw := (35 + 4 * f.phase) * (1 + 0.15 * f.enrage);
    if aoe then
      perform public.world_gw_say(p_fight, r, 'boss', '모아 둔 기운이 터집니다. 왕좌 아래의 물이 한꺼번에 쏟아집니다!' || case when broke then ' (퇴마 결계가 물살을 절반으로 꺾었습니다)' else '' end);
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 loop
        perform public.world_gw_hit(p_fight, m.owner_id, raw * 0.9 * case when broke then 0.5 else 1 end, r, '쏟아지는 물살에', true);
      end loop;
    elsif coalesce((vbfx ->> 'block')::int, 0) > 0 then
      vbfx := case when (vbfx ->> 'block')::int > 1 then jsonb_set(vbfx, '{block}', to_jsonb((vbfx ->> 'block')::int - 1)) else vbfx - 'block' end;
      perform public.world_gw_say(p_fight, r, 'good', '주인의 손길이 묶여 허공을 가릅니다.');
    else
      select * into m from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0
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
      end if;
    end if;
  end if;
  -- ⑤ 물러난 이의 복귀, 끝 판정, 다음 라운드
  update public.world_gw_members set out_rounds = out_rounds - 1, hp = case when out_rounds = 1 then 30 else hp end where fight_id = p_fight and out_rounds > 0;
  update public.world_gw_members set fx = fx - 'cover' where fight_id = p_fight and fx ? 'cover';
  update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
  select count(*) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
  if alive = 0 then
    perform public.world_gw_say(p_fight, r, 'bad', '모두가 물러났습니다. 소용돌이가 왕좌를 덮습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  if now() >= f.ends_at then
    perform public.world_gw_say(p_fight, r, 'bad', '시간이 다 되었습니다. 귀허의 주인이 바다 밑으로 가라앉습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  perform public.world_gw_next_round(p_fight);
end $function$;

-- 다음 라운드: 기믹·모으기(aoe)·암시 문구(tell)를 정해 mech에 담는다
create or replace function public.world_gw_next_round(p_fight uuid)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare f public.world_gw_fights%rowtype; ph int; m jsonb; len int := 5; alive uuid[]; colors text[] := array['청', '적', '황', '백']; t uuid; need int; tell text; nr int; aoe boolean := false; tname text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  nr := f.round + 1;
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select array_agg(owner_id order by random()) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
  if ph <> f.phase then
    perform public.world_gw_say(p_fight, nr, 'phase', case ph
      when 2 then '귀허의 주인이 두 얼굴을 거둔다. 바닥에서 흰 사슬 네 줄이 솟아 조사원들의 손목을 감는다. 「너희 이름을 묶어 두마.」'
      when 3 then '사슬이 끊긴 자리에서 물이 솟는다. 「이름을 다오. 하나씩 빼앗아 주마.」'
      else '귀허의 주인이 왕좌에서 일어선다. 바다 전체가 소용돌이친다. 「모두 함께 가라앉자.」' end);
    f.cycle := 0;
  end if;
  if ph = 1 then
    m := jsonb_build_object('k', 'face', 'face', case when random() < 0.5 then 'human' else 'yokai' end);
    aoe := nr % 4 = 0;
    tell := case when m ->> 'face' = 'human' then '주인이 사람의 얼굴을 든다. 낯익은 노인의 눈, 살과 뼈로 된 얼굴이 이쪽을 본다.'
                 else '주인이 요괴의 얼굴을 든다. 비늘 덮인 입이 귀까지 찢어지고, 칼날이 미끄러질 듯한 기운이 서린다.' end;
  elsif ph = 2 and f.cycle % 6 = 0 and alive is not null then
    m := jsonb_build_object('k', 'chain', 'colors', (select jsonb_object_agg(a::text, colors[o]) from unnest(alive) with ordinality u(a, o)));
    len := 10;
    tell := '흰 사슬이 저마다의 손목을 휘감는다. 사슬마다 빛깔이 다르고, 남의 사슬은 손을 대자마자 거칠게 튕겨 낼 것만 같다.';
  elsif ph = 3 and f.cycle % 6 = 0 and alive is not null then
    t := alive[1];
    update public.world_gw_members set nameless = true where fight_id = p_fight and owner_id = t;
    select name into tname from public.world_gw_members where fight_id = p_fight and owner_id = t;
    m := jsonb_build_object('k', 'name', 'target', t);
    len := 10;
    tell := tname || '의 이름이 물에 녹아 흘러간다. 제 입으로는 제 이름이 떠오르지 않는다. 곁에서 누군가 불러 준다면…';
  elsif ph = 4 and f.cycle % 5 = 0 and alive is not null then
    select owner_id, name into t, tname from public.world_gw_members where fight_id = p_fight and out_rounds = 0 order by (stats ->> 'pres')::numeric desc, random() limit 1;
    select greatest(1, round(coalesce(sum((stats ->> 'attack')::numeric), 0) * 0.8)) into need from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and owner_id <> t;
    m := jsonb_build_object('k', 'vortex', 'tank', t, 'need', need);
    len := 10;
    tell := '귀허의 소용돌이가 일어난다. 물살이 ' || tname || ' 쪽으로 쏠린다. 누군가는 그 자리에서 몸을 낮춰 버텨야 하고, 나머지는 왕좌를 몰아쳐 물길을 끊어야 할 것 같다.';
  else
    m := jsonb_build_object('k', 'normal');
    aoe := nr % 4 = 0;
    tell := '주인이 숨을 고른다. 물살이 왕좌를 감싸 돈다.';
  end if;
  if aoe then tell := tell || ' — 발밑의 물이 크게 부풀어 오른다. 귀허의 주인이 기를 모으기 시작했다. 몰려올 것에 대비하라.'; end if;
  m := m || jsonb_build_object('aoe', aoe, 'tell', tell);
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, round_ends_at = now() + make_interval(secs => len), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, nr, case when aoe or m ->> 'k' in ('chain', 'name', 'vortex') then 'warn' else 'tell' end, tell);
end $function$;

create or replace function public.world_gw_snapshot(p_fight uuid default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; rec public.world_gw_records%rowtype; c public.world_characters%rowtype;
  fid uuid := p_fight; why text; inv_f uuid; last_f uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if fid is null then
    select m.fight_id into fid from public.world_gw_members m join public.world_gw_fights x using (fight_id) where m.owner_id = uid and x.status in ('wait', 'fight') order by x.created_at desc limit 1;
  end if;
  select * into c from public.world_characters where owner_id = uid;
  select * into rec from public.world_gw_records where owner_id = uid;
  if fid is null then
    select x.fight_id into inv_f from public.world_gw_fights x join public.world_party_members a on a.owner_id = x.leader_id join public.world_party_members b on b.party_id = a.party_id and b.owner_id = uid
     where x.status = 'wait' and x.start_at > now() order by x.created_at desc limit 1;
    -- 지난 도전(하루 안): 대기실에서 그 기록을 되짚어 볼 수 있게
    select m.fight_id into last_f from public.world_gw_members m join public.world_gw_fights x using (fight_id)
     where m.owner_id = uid and x.status in ('won', 'failed') and x.created_at > now() - interval '1 day' order by x.created_at desc limit 1;
    begin perform public.world_gw_ready_check(uid); exception when others then why := sqlerrm; end;
    return jsonb_build_object('none', true, 'invite', inv_f, 'last', last_f, 'can_open', why is null, 'why', why, 'charms', coalesce((c.inventory ->> 'gwiheo_charm')::int, 0),
      'kills', coalesce(rec.kills, 0), 'tips', case when coalesce(rec.kills, 0) > 0 then public.world_gw_tips() end, 'here', (public.world_region_at(c.location)).region_id = 'gwiheo_core');
  end if;
  select * into f from public.world_gw_fights where fight_id = fid;
  if not found then raise exception '싸움을 찾을 수 없습니다.'; end if;
  if not exists (select 1 from public.world_gw_members where fight_id = fid and owner_id = uid)
     and not (f.status = 'wait' and exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id where a.owner_id = f.leader_id and b.owner_id = uid)) then
    raise exception '함께 싸우는 조사원만 볼 수 있습니다.';
  end if;
  if f.status = 'wait' and f.start_at <= now() then perform public.world_gw_start(fid); end if;
  if f.status = 'fight' then perform public.world_gw_resolve(fid); end if;
  select * into f from public.world_gw_fights where fight_id = fid;
  select * into me from public.world_gw_members where fight_id = fid and owner_id = uid;
  return jsonb_build_object('fight', jsonb_build_object('id', f.fight_id, 'status', f.status, 'hp', f.hp, 'max_hp', f.max_hp, 'phase', f.phase, 'round', f.round,
      'round_ends_at', f.round_ends_at, 'ends_at', f.ends_at, 'start_at', f.start_at, 'leader', f.leader_id, 'enrage', f.enrage,
      'mech', case f.mech ->> 'k' when 'chain' then jsonb_build_object('k', 'chain', 'colors', (select jsonb_agg(v order by v) from jsonb_each_text(f.mech -> 'colors') e(kk, v)), 'mine', f.mech -> 'colors' ->> uid::text,
                                                                     'aoe', f.mech -> 'aoe', 'tell', f.mech -> 'tell')
                              when 'vortex' then f.mech - 'need' || jsonb_build_object('need', (f.mech ->> 'need')::int)
                              else f.mech end,
      'bfx', (select coalesce(jsonb_agg(kk), '[]'::jsonb) from jsonb_object_keys(coalesce(f.bfx, '{}'::jsonb)) kk)),
    'now', now(), 'me', uid,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', m.owner_id, 'name', m.name, 'job', m.job_key, 'level', m.level, 'hp', m.hp, 'out', m.out_rounds,
        'nameless', m.nameless, 'acted', m.act is not null, 'dmg', m.dmg, 'heal', m.heal, 'falls', m.falls,
        'fx', (select coalesce(jsonb_agg(kk), '[]'::jsonb) from jsonb_object_keys(coalesce(m.fx, '{}'::jsonb)) kk)) order by m.joined_at), '[]'::jsonb) from public.world_gw_members m where m.fight_id = fid),
    'my_act', me.act, 'joined', me.owner_id is not null, 'sp', c.spiritual_power,
    'skills', case when me.owner_id is not null then (select coalesce(jsonb_agg(jsonb_build_object('id', s.skill_id, 'name', s.skill_name, 'desc', s.description, 'target', s.target, 'cost', s.cost,
        'rounds', greatest(1, ceil(s.cooldown_s / 5.0)::int), 'rank', s.unlock_rank, 'unlocked', coalesce(c.combat_rank, 1) >= s.unlock_rank,
        'wait', greatest(0, coalesce((me.cds ->> s.skill_id)::int, 0) - f.round)) order by s.sort), '[]'::jsonb) from public.world_coop_skills s where s.job_key = c.job_key) end,
    'log', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'round', l.round, 'kind', l.kind, 'text', l.text) order by l.id), '[]'::jsonb)
              from (select * from public.world_gw_log where fight_id = fid order by id desc limit case when f.status in ('won', 'failed') then 200 else 60 end) l),
    'tips', case when coalesce(rec.kills, 0) > 0 then public.world_gw_tips() end);
end $function$;

-- 파훼법(처치한 조사원만): 정화 부적 → 이름 부르기, 기술 연계
create or replace function public.world_gw_tips() returns jsonb
language sql immutable set search_path to 'pg_catalog' as $function$
  select jsonb_build_array(
    '두 얼굴: 사람의 얼굴에는 근접·원거리(물리), 요괴의 얼굴에는 술법만 듣는다. 반대로 치면 주인이 회복한다 — 봉인술사의 「봉인 사슬」로 묶으면 그 라운드에는 삼키지 못한다.',
    '사슬 넷: 저마다 손목 사슬의 빛깔이 다르다. 10초 안에 자기 빛깔의 사슬만 끊는다. 남의 사슬을 치면 되튕기고, 못 끊은 사람은 끌려간다. 의무관의 「해독 침」은 동료의 사슬을 대신 풀어 준다.',
    '이름 빼앗기: 이름을 잃은 사람의 공격은 닿지 않는다. 동료가 10초 안에 「이름 부르기」로 그 사람을 불러 줘야 풀린다(스스로는 잘 안 된다). 「해독 침」도 풀어 준다.',
    '귀허의 소용돌이: 물살이 쏠린 사람이 「버티기」나 방어로 받아 내고, 나머지는 모두 공격해 정해진 양을 넘겨야 끊긴다. 「흐름 끊기」는 끊을 양을 절반으로, 「호법 신장」을 건 사람은 대신 버틸 수 있다. 실패하면 모두 체력 절반(퇴마 결계·파사 진언이 있으면 ¼)·주인 분노.',
    '「기를 모으기 시작했다」가 보이면 그 라운드 끝에 모두를 치는 물살이 온다. 「버티기」(피해 20%)·방어(40%)·퇴마 결계(절반)로 대비한다. 고르지 않으면 저절로 방어한다.')
$function$;

reset role;
update public.world_app_meta set value = '20261104201300' where key = 'db_version';
