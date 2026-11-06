lock table public.world_characters in access exclusive mode;

create or replace function public.world_contrib_rules()
 returns jsonb
 language sql
 immutable
 set search_path to 'pg_catalog'
as $function$
  select '{"deal": 0.5, "hold": 0.3, "heal": 0.1, "boost": 0.1, "result": 0.2, "eff_cap": 2, "press": 1, "heal_need": 0.25, "boost_need": 0.1}'::jsonb
$function$;

create or replace function public.world_shadow_rules()
 returns jsonb
 language sql
 immutable
 set search_path to 'pg_catalog'
as $function$
  select '{"hp_mul": 350, "hp_min": 9000, "dmg_mul": 1.4, "pow_lo": 0.75, "pow_hi": 1.5, "charge_mul": 5, "stay_full": 0.5, "gil_lv": 20}'::jsonb
$function$;

create or replace function public.world_coop_rules()
 returns jsonb
 language sql
 immutable
 set search_path to 'pg_catalog'
as $function$
  select '{"sure_crit": 2, "all_full": 4, "all_pow": 0.5, "expose_per": 4}'::jsonb
$function$;
revoke all on function public.world_coop_rules() from public, anon, authenticated;
grant execute on function public.world_coop_rules() to fn_owner_field, service_role;

create or replace function public.world_contrib_shares(p_rows jsonb)
 returns jsonb
 language plpgsql
 immutable
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_contrib_rules(); res jsonb;
begin
  with m as (
    select x ->> 'id' id,
           coalesce((x -> 'cr' ->> 'dmg')::numeric, 0) dmg,
           coalesce((x -> 'cr' ->> 'boost')::numeric, 0) boost,
           coalesce((x -> 'cr' ->> 'heal')::numeric, 0) heal,
           coalesce((x -> 'cr' ->> 'taken')::numeric, 0) taken,
           coalesce((x -> 'cr' ->> 'guard')::numeric, 0) guard,
           coalesce((x -> 'cr' ->> 'guard')::numeric, 0) + coalesce((x -> 'cr' ->> 'hit1')::numeric, 0) hold,
           nullif((x ->> 'atk')::numeric, 0) atk,
           coalesce(x -> 'cr', '{}'::jsonb) <> '{}'::jsonb active
      from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) x),
  a as (select coalesce(avg(atk), 1) aa, greatest(1, count(*) filter (where active)) n from m),
  e as (select m.*, m.dmg / greatest(coalesce(m.atk, a.aa), a.aa / (r ->> 'eff_cap')::numeric, 1) eff from m, a),
  t as (select sum(dmg) d, sum(eff) ef, sum(hold) h, sum(heal) hl, sum(boost) b, sum(taken) tk, sum(taken + guard) pr from e),
  w as (select (r ->> 'deal')::numeric * (t.d > 0)::int wd,
               (r ->> 'hold')::numeric * (t.h > 0)::int * least(1, t.pr / (a.n * 100 * (r ->> 'press')::numeric)) wh,
               (r ->> 'heal')::numeric * (t.hl > 0)::int * least(1, t.pr / (a.n * 100 * (r ->> 'press')::numeric))
                 * least(1, t.hl / greatest(1, (r ->> 'heal_need')::numeric * t.tk)) whl,
               (r ->> 'boost')::numeric * (t.b > 0)::int * least(1, t.b / greatest(1, (r ->> 'boost_need')::numeric * t.d)) wb
          from t, a),
  s as (select e.id,
               w.wd * case when t.d > 0 then (r ->> 'result')::numeric * e.dmg / t.d + (1 - (r ->> 'result')::numeric) * e.eff / t.ef else 0 end
             + w.wh * case when t.h > 0 then e.hold / t.h else 0 end
             + w.whl * case when t.hl > 0 then e.heal / t.hl else 0 end
             + w.wb * case when t.b > 0 then e.boost / t.b else 0 end v
          from e, t, w)
  select coalesce(jsonb_object_agg(s.id, case when z.tot > 0 then round(s.v / z.tot * 100, 1) else 0 end), '{}'::jsonb) into res
    from s, (select sum(v) tot from s) z;
  return res;
end $function$;
revoke all on function public.world_contrib_rules() from public, anon, authenticated;
revoke all on function public.world_shadow_rules() from public, anon, authenticated;
revoke all on function public.world_contrib_shares(jsonb) from public, anon, authenticated;
grant execute on function public.world_contrib_rules() to fn_owner_field, service_role;
grant execute on function public.world_shadow_rules() to fn_owner_field, service_role;
grant execute on function public.world_contrib_shares(jsonb) to fn_owner_field, service_role;

create or replace function public.world_raid_shares(p_raid uuid)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select public.world_contrib_shares(coalesce(jsonb_agg(jsonb_build_object('id', owner_id, 'cr', credits, 'atk', (stats ->> 'attack')::numeric)), '[]'::jsonb))
    from public.world_raid_members where raid_id = p_raid
$function$;
revoke all on function public.world_raid_shares(uuid) from public, anon, authenticated;
grant execute on function public.world_raid_shares(uuid) to fn_owner_field, service_role;

create or replace function public.world_raid_recontrib(p_raid uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare s jsonb := public.world_raid_shares(p_raid);
begin
  update public.world_raid_members x set contrib = coalesce((s ->> x.owner_id::text)::numeric, 0)
   where x.raid_id = p_raid and x.credits <> '{}'::jsonb;
end $function$;

create or replace function public.world_gw_shares(p_fight uuid)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select public.world_contrib_shares(coalesce(jsonb_agg(jsonb_build_object('id', owner_id, 'cr', credits, 'atk', (stats ->> 'attack')::numeric)), '[]'::jsonb))
    from public.world_gw_members where fight_id = p_fight
$function$;

create or replace function public.world_pfight_shares(p_fight uuid)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select public.world_contrib_shares(coalesce(jsonb_agg(jsonb_build_object('id', pm.owner_id,
           'cr', case when pm.dmg > 0 or pm.taken > 0 then jsonb_build_object('dmg', pm.dmg, 'taken', pm.taken, 'hit1', pm.taken) else '{}'::jsonb end,
           'atk', (select (o ->> 'atk')::numeric from jsonb_array_elements(coalesce(f.turn_order, '[]'::jsonb)) o where (o ->> 'id')::uuid = pm.owner_id limit 1))), '[]'::jsonb))
    from public.world_pfight_members pm join public.world_pfights f on f.fight_id = pm.fight_id where pm.fight_id = p_fight
$function$;

CREATE OR REPLACE FUNCTION public.world_raid_hit(p_raid uuid, p_target uuid, p_raw numeric, p_kind text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare m public.world_raid_members%rowtype; pm public.world_raid_members%rowtype; f jsonb; r jsonb; c jsonb; d int; hp int; who uuid := p_target; nm text; absorb int;
  rk text := (select x.kind from public.world_raids x where x.raid_id = p_raid); st jsonb; self_guard numeric;
begin
  select * into m from public.world_raid_members where raid_id = p_raid and owner_id = p_target for update;
  if not found then return 0; end if;
  f := m.fx;
  if f ? 'cover' and (f -> 'cover' ->> 'until')::timestamptz > now() then
    select * into pm from public.world_raid_members where raid_id = p_raid and owner_id = (f -> 'cover' ->> 'by')::uuid for update;
    if found and pm.out_until is null then
      perform public.world_raid_say(p_raid, 'coop', pm.name || ' — ' || m.name || '을(를) 노린 공격을 대신 막았습니다.');
      perform public.world_raid_credit(p_raid, pm.owner_id, p_raw * 0.5 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0), 'guard');
      m := pm; who := pm.owner_id; p_raw := p_raw * 0.5;
    end if;
  end if;
  nm := m.name;
  st := m.stats;
  if rk = 'world' then p_raw := p_raw * least((public.world_shadow_rules() ->> 'pow_hi')::numeric, greatest((public.world_shadow_rules() ->> 'pow_lo')::numeric, coalesce((st ->> 'attack')::numeric, 7.5 * m.level) / greatest(1, 7.5 * m.level))); end if;
  r := public.world_cb_mitigate(p_raw, st, m.fx, who, p_kind in ('slam', 'burst'), p_kind = 'burst', null, p_kind = 'single');
  for c in select * from jsonb_array_elements(r -> 'credits') loop
    perform public.world_raid_credit(p_raid, (c ->> 0)::uuid, (c ->> 1)::numeric, c ->> 2);
  end loop;
  f := r -> 'fx'; d := (r ->> 'd')::int; absorb := (r ->> 'absorb')::int;
  if (r ->> 'evaded')::boolean then
    update public.world_raid_members set fx = f where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say(p_raid, 'miss', nm || ' — 공격을 피했습니다.');
    return 0;
  end if;
  perform public.world_raid_credit(p_raid, who, d, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);
  if p_kind = 'single' and not coalesce((r ->> 'taunt')::boolean, false) then perform public.world_raid_credit(p_raid, who, d, 'hit1'); end if;
  if p_kind = 'single' then
    self_guard := p_raw * (1 - (1 - least(80, coalesce((st ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((st ->> 'inc')::numeric, 0) / 100.0)) * 0.5;
    if self_guard > 0 then perform public.world_raid_credit(p_raid, who, self_guard, 'guard'); end if;
  end if;
  update public.world_characters set health = greatest(1, health - d), updated_at = now() where owner_id = who returning health into hp;
  if hp <= 1 and d > 0 then
    update public.world_raid_members set taken = taken + d, fx = f - 'bound', out_until = now() + case when (select x.kind from public.world_raids x where x.raid_id = p_raid) = 'final' then interval '30 seconds' else interval '60 seconds' end, falls = falls + 1 where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say_n(p_raid, 'fall', nm || ' — ' || d || '의 피해를 입고 물러났습니다(' || case when (select x.kind from public.world_raids x where x.raid_id = p_raid) = 'final' then '30초' else '1분' end || ' 쉰 뒤 행동하면 돌아옴).', nm, d);
  else
    update public.world_raid_members set taken = taken + d, fx = f where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say_n(p_raid, 'hit', nm || ' — ' || d || '의 피해' || '.', nm, d);
  end if;
  return d;
end $function$;

CREATE OR REPLACE FUNCTION public.world_raid_boss_base(p_raid uuid, p_kind text, p_lv integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare al numeric; aa numeric;
begin
  if p_kind is distinct from 'final' then return (4 + 0.7 * (coalesce(p_lv, 1) + 3)) * (public.world_shadow_rules() ->> 'dmg_mul')::numeric; end if;
  select avg(level), avg(coalesce((stats ->> 'attack')::numeric, 50)) into al, aa from public.world_raid_members where raid_id = p_raid;
  al := coalesce(al, p_lv, 30);
  return 0.8 * (4 + 0.7 * (al + 3)) * least(1.5, greatest(0.75, coalesce(aa, 7.5 * al) / greatest(1, 7.5 * al)));
end $function$;

CREATE OR REPLACE FUNCTION public.world_raid_charge_need(p_raid uuid, p_kind text, p_max_hp integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare reg text; s numeric;
begin
  if p_kind <> 'world' then return round(p_max_hp * 0.04)::int; end if;
  select region_id into reg from public.world_raids where raid_id = p_raid;
  select coalesce(sum(greatest(1, coalesce((x.stats ->> 'attack')::numeric, 0))), 0) into s
    from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id
   where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, reg)
     and x.last_action_at > now() - interval '120 seconds' and ch.health > 1;
  return greatest(500, round(s * (public.world_shadow_rules() ->> 'charge_mul')::numeric))::int;
end $function$;

CREATE OR REPLACE FUNCTION public.world_raid_action(p_raid uuid, p_action text, p_skill text DEFAULT NULL::text, p_target uuid DEFAULT NULL::uuid, p_item text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rd public.world_raids%rowtype; mb public.world_raid_members%rowtype;
  tm public.world_raid_members%rowtype; sk public.world_coop_skills%rowtype; st jsonb; f jsonb; rfx jsonb; act text := lower(coalesce(p_action, ''));
  here text; sp int; inv jsonb; ammo text; mul numeric := 1; dmg int := 0; crit boolean := false; credit numeric := 0; h0 int; h1 int; amt int;
  n_act int; pick uuid; lv int; raw numeric; ph_mul numeric; k text; v jsonb; tgt uuid; nm text; newp int; tot numeric; acc numeric; rnd numeric; m record;
  bm text; bp numeric := 0; be text; bep numeric := 0; bc text; bcp numeric := 0; bcn text; ex numeric;
  bt int; tick boolean := true; bnow numeric; cbr jsonb; cbc jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if act not in ('attack', 'guard', 'item', 'coop') then raise exception '알 수 없는 행동입니다.'; end if;
  perform public.world_rate_check('raid', uid, p_raid);
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if not found then raise exception '알 수 없는 토벌입니다.'; end if;
  if rd.status <> 'fight' then raise exception '지금은 싸울 수 없습니다.'; end if;
  if rd.ends_at <= now() then perform public.world_raid_settle(p_raid, false); return public.world_raid_snapshot(p_raid); end if;
  select * into mb from public.world_raid_members where raid_id = p_raid and owner_id = uid for update;
  if not found then raise exception '참가 신청한 조사원만 싸울 수 있습니다. 진행은 관전으로 볼 수 있습니다.'; end if;
  if mb.last_action_at is not null and mb.last_action_at > now() - interval '1 second' then raise exception '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.'; end if;
  if mb.left_at is not null then raise exception '토벌에서 나왔습니다. 「다시 참가」하면 이어서 싸울 수 있습니다.'; end if;
  if mb.out_until is not null and mb.out_until > now() then
    raise exception '물러나 숨을 고르는 중입니다(%초 뒤 돌아옴).', ceil(extract(epoch from mb.out_until - now())); end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태입니다.'; end if;
  select region_id into here from public.world_map_regions where region_name = c.location;
  if here is distinct from rd.region_id then raise exception '토벌이 벌어진 곳에 있어야 합니다.'; end if;
  if exists (select 1 from public.world_expeditions where owner_id = uid and status = 'active') then raise exception '원정 중에는 싸울 수 없습니다.'; end if;
  if c.travel_destination is not null then raise exception '이동 중에는 싸울 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities where owner_id = uid and status = 'active') then raise exception '자율 활동 중에는 싸울 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false) and a.mlevel is not null) then
    raise exception '진행 중인 요괴 전투를 먼저 끝내세요.'; end if;

  st := public.world_raid_stats(uid);
  f := mb.fx; rfx := rd.fx; sp := c.spiritual_power; inv := coalesce(c.inventory, '{}'::jsonb);
  if mb.out_until is not null then mb.out_until := null;
    if rd.kind = 'final' and c.health < 30 then c.health := 30; update public.world_characters set health = 30, updated_at = now() where owner_id = uid; end if;
  end if;

  if act = 'coop' then
    select * into sk from public.world_coop_skills where skill_id = p_skill;
    if found and sk.job_key = c.job_key and coalesce((sk.effect ->> 'strike')::boolean, false) then
      if coalesce(c.combat_rank, 1) < sk.unlock_rank then raise exception '전투 숙련 %단계에 열리는 기술입니다.', sk.unlock_rank; end if;
      if mb.cd ? sk.skill_id and (mb.cd ->> sk.skill_id)::timestamptz > now() then
        raise exception '%은(는) %초 뒤에 다시 쓸 수 있습니다.', sk.skill_name, ceil(extract(epoch from (mb.cd ->> sk.skill_id)::timestamptz - now())); end if;
      if sp < sk.cost then raise exception '영력이 모자랍니다(필요 %).', sk.cost; end if;
      sp := sp - sk.cost;
      mb.cd := mb.cd || jsonb_build_object(sk.skill_id, now() + make_interval(secs => sk.cooldown_s));
      mb.coop := mb.coop + 1;
      f := f || public.world_cb_buff('crit_next', sk.effect, uid);
      perform public.world_raid_say(p_raid, 'coop', mb.name || ' — [' || sk.skill_name || '] ' || sk.exp_text || '.');
      act := 'attack';
    end if;
  end if;
  if act = 'attack' then
    if st ->> 'style' = 'magic' then if sp >= 2 then sp := sp - 2; else mul := mul * 0.5; end if;
    elsif st ->> 'style' = 'ranged' then
      ammo := public.world_ammo_of(uid);
      if ammo is not null and coalesce((inv ->> ammo)::int, 0) >= 1 then inv := public.world_inv_add(inv, ammo, -1); if (inv ->> ammo)::int <= 0 then inv := inv - ammo; end if;
      else mul := mul * 0.5; end if;
    else if sp >= 2 then sp := sp - 2; else mul := mul * 0.5; end if; end if;
    cbr := public.world_cb_attack(st, f, rfx, 0.85, 0.3);
    f := cbr -> 'fx'; rfx := cbr -> 'bfx'; crit := (cbr ->> 'crit')::boolean;
    if rd.kind = 'final' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then
      mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_dmg')::numeric, (public.world_solo_aid(c.job_key) ->> 'solo_dmg')::numeric, 0) / 100.0);
    elsif rd.kind = 'final' then mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_all')::numeric, 0) / 100.0); end if;
    dmg := greatest(1, round((cbr ->> 'd')::numeric * mul))::int;
    rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - dmg); mb.dmg := mb.dmg + dmg; credit := 0;
    for cbc in select * from jsonb_array_elements(public.world_cb_boost_credits(dmg, crit, cbr -> 'src', uid, (st ->> 'crit')::numeric)) loop
      if cbc ->> 2 = 'dmg' then credit := (cbc ->> 1)::numeric; else perform public.world_raid_credit(p_raid, (cbc ->> 0)::uuid, (cbc ->> 1)::numeric, 'boost'); end if;
    end loop;
    if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,got}', to_jsonb((rfx -> 'charge' ->> 'got')::int + dmg)); end if;
    perform public.world_raid_say_n(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.', mb.name, dmg);
  elsif act = 'guard' then
    f := f || jsonb_build_object('guard', 1); mb.guarded := mb.guarded + 1;
    perform public.world_raid_say(p_raid, 'guard', mb.name || ' — 방어 태세를 갖췄습니다.');
  elsif act = 'item' then
    update public.world_characters set spiritual_power = sp where owner_id = uid;
    h0 := c.health;
    perform set_config('yh.raid_item', '1', true);
    perform public.world_use_item(p_item);
    perform set_config('yh.raid_item', '', true);
    select * into c from public.world_characters where owner_id = uid;
    sp := c.spiritual_power; inv := coalesce(c.inventory, '{}'::jsonb); h1 := c.health;
    if rd.kind = 'final' and h1 > h0 then
      if mb.items_used >= 5 then raise exception '결전에서는 체력 회복품을 한 싸움에 다섯 개까지만 쓸 수 있습니다.'; end if;
      mb.items_used := mb.items_used + 1;
    end if;
    mb.heal := mb.heal + greatest(0, h1 - h0); credit := greatest(0, h1 - h0);
    perform public.world_raid_say(p_raid, 'item', mb.name || ' — ' || coalesce((select item_name from public.world_item_catalog where item_id = p_item), '물품') || '을(를) 썼습니다' || case when h1 > h0 then '(체력 +' || (h1 - h0) || ')' else '' end || '.');
  else
    select * into sk from public.world_coop_skills where skill_id = p_skill;
    if not found or sk.job_key <> c.job_key then raise exception '쓸 수 없는 협동 기술입니다.'; end if;
    if coalesce(c.combat_rank, 1) < sk.unlock_rank then raise exception '전투 숙련 %단계에 열리는 기술입니다.', sk.unlock_rank; end if;
    if mb.cd ? sk.skill_id and (mb.cd ->> sk.skill_id)::timestamptz > now() then
      raise exception '%은(는) %초 뒤에 다시 쓸 수 있습니다.', sk.skill_name, ceil(extract(epoch from (mb.cd ->> sk.skill_id)::timestamptz - now())); end if;
    if sp < sk.cost then raise exception '영력이 모자랍니다(필요 %).', sk.cost; end if;
    tgt := case when sk.target = 'self' then uid else coalesce(p_target, uid) end;
    if sk.target = 'ally' then
      select * into tm from public.world_raid_members where raid_id = p_raid and owner_id = tgt for update;
      if not found then raise exception '이 토벌에 참가한 동료에게만 쓸 수 있습니다.'; end if;
      if sk.effect ->> 'type' = 'revive' then
        if tm.out_until is null then raise exception '물러난 동료에게만 쓸 수 있습니다.'; end if;
        if tm.left_at is not null then raise exception '토벌에서 나간 동료입니다.'; end if;
      elsif tm.out_until is not null and tm.out_until > now() then raise exception '물러난 동료에게는 쓸 수 없습니다.'; end if;
    end if;
    sp := sp - sk.cost;
    mb.cd := mb.cd || jsonb_build_object(sk.skill_id, now() + make_interval(secs => sk.cooldown_s));
    mb.coop := mb.coop + 1; credit := 0;
    k := sk.effect ->> 'type'; v := sk.effect;
    if sk.target in ('ally', 'self') and tgt = uid then
      if k in ('ward', 'might', 'evade', 'gward', 'crit_next') then f := f || public.world_cb_buff(k, v, uid);
      elsif k = 'shield' then f := f || jsonb_build_object('shield', coalesce((f ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid);
      elsif k = 'cleanse_heal' then f := f - 'bound';
      elsif k = 'cover' then raise exception '자기 자신은 대신 막을 수 없습니다.';
      end if;
    elsif sk.target = 'ally' then
      update public.world_raid_members set fx = case
          when k in ('ward', 'might', 'evade', 'gward', 'crit_next') then fx || public.world_cb_buff(k, v, uid)
          when k = 'shield' then fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid)
          when k = 'cleanse_heal' then fx - 'bound'
          when k = 'cover' then fx || jsonb_build_object('cover', jsonb_build_object('by', uid, 'until', now() + make_interval(secs => (v ->> 'secs')::int)))
          else fx end,
        out_until = case when k = 'revive' then least(out_until, now()) else out_until end
       where raid_id = p_raid and owner_id = tgt;
    end if;
    if k in ('heal', 'cleanse_heal', 'revive', 'sp', 'gward') then
      amt := case k when 'revive' then (v ->> 'hp')::int when 'sp' then 0 when 'gward' then 0
             else round((v ->> 'amt')::int * (1 + coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) / 100.0)) end;
      if rd.kind = 'final' and k in ('heal', 'cleanse_heal') then amt := ceil(amt * 0.5); end if;
      if k = 'revive' then
        select health into h1 from public.world_characters where owner_id = tgt;
        update public.world_characters set health = greatest(health, amt), updated_at = now() where owner_id = tgt;
        amt := greatest(0, amt - coalesce(h1, 0));
      elsif k = 'sp' then
        if tgt <> uid then perform public.world_raid_credit(p_raid, uid, (select greatest(0, least((v ->> 'amt')::int, 100 - x.spiritual_power)) from public.world_characters x where x.owner_id = tgt) * coalesce((st ->> 'attack')::numeric, 0) * 0.05, 'boost'); end if;
        update public.world_characters set spiritual_power = least(100, spiritual_power + (v ->> 'amt')::int), updated_at = now() where owner_id = tgt and owner_id <> uid;
        if tgt = uid then sp := least(100, sp + (v ->> 'amt')::int); end if;
      elsif k = 'gward' then
        update public.world_characters set mental = least(100, mental + coalesce((v ->> 'mind')::int, 0)), updated_at = now() where owner_id = tgt;
      else
        if tgt = uid then
          select health into h0 from public.world_characters where owner_id = uid;
        end if;
        select health into h1 from public.world_characters where owner_id = tgt;
        update public.world_characters set health = least(100, health + amt), updated_at = now() where owner_id = tgt and health > 0;
        amt := case when coalesce(h1, 0) > 0 then greatest(0, least(100, h1 + amt) - h1) else 0 end;
      end if;
      if amt > 0 then mb.heal := mb.heal + amt; perform public.world_raid_credit(p_raid, uid, amt, case when tgt = uid then 'heal_self' else 'heal' end); end if;
    end if;
    if k = 'heal_all' then
      amt := round((v ->> 'amt')::int * (1 + coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) / 100.0));
      if rd.kind = 'final' then amt := ceil(amt * 0.5); end if; -- heal_all final half
      select sum(greatest(0, least(100, ch.health + amt) - ch.health)) into acc from public.world_characters ch join public.world_raid_members x on x.owner_id = ch.owner_id
       where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and ch.health > 0;
      update public.world_characters ch set health = least(100, ch.health + amt), updated_at = now()
        from public.world_raid_members x where x.raid_id = p_raid and x.owner_id = ch.owner_id and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and ch.health > 0;
      get diagnostics n_act = row_count;
      mb.heal := mb.heal + coalesce(acc, 0)::int; perform public.world_raid_credit(p_raid, uid, coalesce(acc, 0), 'heal');
    elsif k in ('ward_all', 'might_all', 'crit_all', 'rally', 'resonance') then
      if k in ('crit_all', 'rally') then
        select count(*) + 1 into n_act from public.world_raid_members x where x.raid_id = p_raid and x.owner_id <> uid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id);
        v := v || jsonb_build_object('pct', round((v ->> 'pct')::numeric * least(1, power((public.world_coop_rules() ->> 'all_full')::numeric / n_act, (public.world_coop_rules() ->> 'all_pow')::numeric)), 1));
      end if;
      update public.world_raid_members x set fx = x.fx || public.world_cb_buff(k, v, uid)
       where x.raid_id = p_raid and x.owner_id <> uid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id);
      f := f || public.world_cb_buff(k, v, uid);
    elsif k = 'taunt' then
      f := f || public.world_cb_buff('taunt', v, uid);
    elsif k = 'expose' then
      rfx := rfx || jsonb_build_object('expose', jsonb_build_object('pct', v -> 'pct', 'n', case when rd.kind = 'world' then ceil((v ->> 'n')::int * greatest(1, (select count(*) from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and x.last_action_at > now() - interval '120 seconds') / (public.world_coop_rules() ->> 'expose_per')::numeric))::int else (v ->> 'n')::int end, 'by', uid), 'stagger', coalesce((rfx ->> 'stagger')::int, 0) + coalesce((v ->> 'stagger')::int, 0), 'stagger_by', uid);
    elsif k = 'delay' then
      rfx := rfx || jsonb_build_object('stagger', coalesce((rfx ->> 'stagger')::int, 0) + (v ->> 'n')::int, 'stagger_by', uid);
      if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int + 3));
        if (rfx -> 'charge' ->> 'until') is not null then rfx := jsonb_set(rfx, '{charge,until}', to_jsonb((rfx -> 'charge' ->> 'until')::numeric + 6)); end if; end if;
    elsif k = 'smoke' then
      rfx := rfx || jsonb_build_object('smoke', jsonb_build_object('miss', v -> 'miss', 'n', v -> 'n', 'by', uid));
    elsif k = 'break' then
      rfx := rfx || jsonb_build_object('break', v -> 'pct', 'break_by', uid);
    end if;
    select name into nm from public.world_raid_members where raid_id = p_raid and owner_id = tgt;
    perform public.world_raid_say(p_raid, 'coop', mb.name || ' — [' || sk.skill_name || '] ' ||
      case when sk.target = 'ally' and tgt <> uid then nm || '에게 · ' else '' end || sk.exp_text || '.');
  end if;

  update public.world_characters set spiritual_power = sp, inventory = inv, updated_at = now() where owner_id = uid;
  mb.acts := mb.acts + 1; mb.last_action_at := now();
  mb.contrib := mb.contrib + credit;
  update public.world_raid_members set fx = f, cd = mb.cd, dmg = mb.dmg, heal = mb.heal, coop = mb.coop, guarded = mb.guarded, acts = mb.acts,
    contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = case when rd.kind = 'final' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then st || (public.world_solo_aid(c.job_key) - 'solo_guard' - 'final_guard') || jsonb_build_object('solo_guard', coalesce(public.world_solo_aid(c.job_key) -> 'final_guard', '0'::jsonb)) else st end, items_used = mb.items_used where raid_id = p_raid and owner_id = uid;
  perform public.world_raid_credit(p_raid, uid, credit, case act when 'attack' then 'dmg' when 'item' then 'heal_self' end);
  if act = 'coop' then perform public.world_raid_credit(p_raid, uid, 1, 'skill'); end if;

  rd.turn := rd.turn + 1;
  if rd.hp <= 0 then
    update public.world_raids set hp = 0, turn = rd.turn, fx = rfx, updated_at = now() where raid_id = p_raid;
    perform public.world_raid_say(p_raid, 'win', mb.name || '의 일격에 ' || rd.boss_name || '이(가) 무너졌습니다.');
    perform public.world_raid_settle(p_raid, true);
    return public.world_raid_snapshot(p_raid);
  end if;
  newp := case when rd.hp * 100 <= rd.max_hp * 40 then 3 when rd.hp * 100 <= rd.max_hp * 70 then 2 else 1 end;
  if newp > rd.phase then
    rd.phase := newp;
    perform public.world_raid_say(p_raid, 'phase', case newp when 2 then rd.boss_name || '의 사슬이 풀리며 움직임이 사나워집니다(2단계).'
                                                    else rd.boss_name || '이(가) 봉연의 기운을 끌어모으기 시작합니다(3단계).' end);
  end if;
  ph_mul := case rd.phase when 1 then 1 when 2 then 1.15 else 1.3 end * case when rd.kind = 'final' then 1.1 else 1 end;
  select count(*) into n_act from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id
   where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' and ch.health > 1;

  if rd.kind = 'world' then
    bnow := extract(epoch from now()); tick := false;
    if not (rfx ? 'beat_at') then rfx := rfx || jsonb_build_object('beat', 0, 'beat_at', bnow);
    elsif bnow >= (rfx ->> 'beat_at')::numeric + 2 then
      rfx := rfx || jsonb_build_object('beat', (rfx ->> 'beat')::int + 1, 'beat_at', bnow); tick := true;
    end if;
    bt := (rfx ->> 'beat')::int;
  else bt := rd.turn; end if;

  if coalesce((rfx ->> 'stagger')::int, 0) > 0 then
    rfx := case when (rfx ->> 'stagger')::int <= 1 then rfx - 'stagger' else jsonb_set(rfx, '{stagger}', to_jsonb((rfx ->> 'stagger')::int - 1)) end;
    if rfx ? 'stagger_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'stagger_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 0.7 * (least(0.4, 0.8 / greatest(1, n_act)) + 0.8 * greatest(1, n_act) / 7.0), 'guard'); end if;
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 휘청여 반격하지 못합니다.');
  elsif rfx ? 'charge' then
    rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int - case when tick then 1 else 0 end));
    if (rfx -> 'charge' ->> 'got')::int >= (rfx -> 'charge' ->> 'need')::int then
      rfx := rfx - 'charge';
      perform public.world_raid_say(p_raid, 'boss', '몰아친 공격에 ' || rd.boss_name || '의 기운 모으기가 끊겼습니다.');
    elsif (case when (rfx -> 'charge' ->> 'until') is not null then extract(epoch from now()) >= (rfx -> 'charge' ->> 'until')::numeric else (rfx -> 'charge' ->> 'left')::int <= 0 end) then
      rfx := rfx - 'charge';
      perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 모은 봉연의 기운을 터뜨립니다!');
      for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' loop
        raw := public.world_raid_boss_base(p_raid, rd.kind, m.level) * ph_mul * 2.2 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
        perform public.world_raid_hit(p_raid, m.owner_id, raw, 'burst');
      end loop;
      if rfx ? 'break_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'break_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 2.2 * (rfx ->> 'break')::numeric / 100.0 * 0.7 * greatest(1, n_act), 'guard'); end if;
      rfx := rfx - 'break' - 'break_by';
    end if;
  elsif tick and rd.phase = 3 and bt % 11 = 0 then
    rfx := rfx || jsonb_build_object('charge', jsonb_build_object('left', case when rd.kind = 'world' then 4 else 5 + greatest(1, n_act) end, 'until', case when rd.kind = 'world' then round(extract(epoch from now())::numeric + 8, 2) end, 'need', public.world_raid_charge_need(p_raid, rd.kind, rd.max_hp), 'got', 0));
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 기운을 모읍니다. ' || public.world_raid_charge_need(p_raid, rd.kind, rd.max_hp) || ' 넘게 몰아쳐 끊거나, 방어하세요!');
  elsif tick and bt % 7 = 0 then
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 크게 휘둘러 모두를 덮칩니다.');
    for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' loop
      raw := public.world_raid_boss_base(p_raid, rd.kind, m.level) * ph_mul * 0.8 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
      perform public.world_raid_hit(p_raid, m.owner_id, raw, 'slam');
    end loop;
    if rfx ? 'break_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'break_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 0.8 * (rfx ->> 'break')::numeric / 100.0 * 0.7 * greatest(1, n_act), 'guard'); end if;
    rfx := rfx - 'break' - 'break_by';
  elsif tick and rd.phase >= 2 and bt % 5 = 0 then
    select x.owner_id, x.name into pick, nm from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) order by random() limit 1;
    if pick is not null then
      update public.world_raid_members set fx = fx || '{"bound":1}'::jsonb where raid_id = p_raid and owner_id = pick;
      perform public.world_raid_say(p_raid, 'boss', '봉연의 사슬이 ' || nm || '을(를) 휘감습니다(다음 공격 절반).');
    end if;
  elsif random() < least(0.4, 0.8 / greatest(1, n_act)) then
    select x.owner_id, x.level into pick, lv from public.world_raid_members x
     where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds'
     order by public.world_cb_pick_key((x.stats ->> 'pres')::numeric + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)) limit 1;
    if pick is not null then
      if rfx ? 'smoke' and random() * 100 < (rfx -> 'smoke' ->> 'miss')::numeric then
        perform public.world_raid_credit(p_raid, nullif(rfx -> 'smoke' ->> 'by', '')::uuid, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul * 0.7, 'guard');
        perform public.world_raid_say(p_raid, 'miss', '연막 속에서 ' || rd.boss_name || '의 공격이 빗나갔습니다.');
      else
        perform public.world_raid_hit(p_raid, pick, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul, 'single');
      end if;
      if rfx ? 'smoke' then rfx := case when (rfx -> 'smoke' ->> 'n')::int <= 1 then rfx - 'smoke' else jsonb_set(rfx, '{smoke,n}', to_jsonb((rfx -> 'smoke' ->> 'n')::int - 1)) end; end if;
    end if;
  end if;

  if rd.kind = 'final' and not exists (select 1 from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id)) then
    rd.hp := least(rd.max_hp, rd.hp + round(rd.max_hp * 0.015));
    perform public.world_raid_say(p_raid, 'boss', '모두 물러난 사이 ' || rd.boss_name || '이(가) 기운을 되찾습니다(체력 +1.5%).');
  end if;
  rd.intent := case when rfx ? 'charge' then '기운을 모으는 중 — ' || case when rd.kind = 'world' then greatest(0, ceil(coalesce((rfx -> 'charge' ->> 'until')::numeric, extract(epoch from now()) + (rfx -> 'charge' ->> 'left')::int * 2) - extract(epoch from now())))::int || '초' else '남은 ' || (rfx -> 'charge' ->> 'left') || '번' end || ' 안에 ' || greatest(0, (rfx -> 'charge' ->> 'need')::int - (rfx -> 'charge' ->> 'got')::int) || ' 더 몰아치면 끊긴다'
                    when (bt + 1) % 7 = 0 then '크게 휘두를 낌새가 보인다 — 방어하라'
                    when rd.phase >= 2 and (bt + 1) % 5 = 0 then '사슬이 꿈틀거린다'
                    else null end;
  update public.world_raids set hp = rd.hp, turn = rd.turn, phase = rd.phase, fx = rfx, intent = rd.intent, updated_at = now() where raid_id = p_raid;
  return public.world_raid_snapshot(p_raid);
end $function$;

CREATE OR REPLACE FUNCTION public.world_gw_resolve(p_fight uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare cbr jsonb; f public.world_gw_fights%rowtype; m record; a jsonb; av text; d numeric; boss_dmg numeric := 0; boss_heal numeric := 0; physical boolean;
  k text; vsum numeric := 0; tank_ok boolean := false; freed uuid[] := '{}'; tgt uuid; raw numeric; r int; alive int; cr boolean;
  sk public.world_coop_skills%rowtype; csp int; vbfx jsonb; vfx jsonb; tn text; e jsonb; aoe boolean; mul numeric; n int; need numeric;
  delayed boolean := false; sealed boolean := false; broke boolean := false; cover_by uuid; hit_who uuid; v_n int; v_hands int; v_h int; v_hit uuid[] := '{}'; v_miss numeric;
  v_mb text; v_mp numeric; v_eb text; v_ep numeric; v_cb text; v_cp numeric; v_cn text; v_brk uuid;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return; end if;
  if now() < f.round_ends_at and exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act is null) then return; end if;
  r := f.round; k := f.mech ->> 'k'; aoe := coalesce((f.mech ->> 'aoe')::boolean, false); vbfx := coalesce(f.bfx, '{}'::jsonb);
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'coop' order by joined_at loop
    select * into sk from public.world_coop_skills where skill_id = m.act ->> 's';
    if sk.skill_id is null then continue; end if;
    select spiritual_power into csp from public.world_characters where owner_id = m.owner_id for update;
    if coalesce(csp, 0) < sk.cost then perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 영력이 모자라 「' || sk.skill_name || '」이(가) 흩어졌습니다.'); continue; end if;
    update public.world_characters set spiritual_power = spiritual_power - sk.cost, updated_at = now() where owner_id = m.owner_id;
    update public.world_gw_members set acts = acts + 1, cds = jsonb_set(cds, array[sk.skill_id], to_jsonb(r + greatest(1, ceil(sk.cooldown_s / 5.0)::int)))
     where fight_id = p_fight and owner_id = m.owner_id;
    perform public.world_gw_credit(p_fight, m.owner_id, 1, 'skill');
    tgt := case when sk.target = 'self' then m.owner_id else coalesce(nullif(m.act ->> 't', '')::uuid, m.owner_id) end;
    select name into tn from public.world_gw_members where fight_id = p_fight and owner_id = tgt;
    e := sk.effect;
    if e ? 'amt' then
      e := e || jsonb_build_object('amt', round((e ->> 'amt')::int * (1 + coalesce((select (x.skill_progress -> 'first_aid' ->> 'rank')::int from public.world_characters x where x.owner_id = m.owner_id), 0) / 100.0)));
    end if;
    case e ->> 'type'
      when 'ward' then update public.world_gw_members set fx = fx || public.world_cb_buff('ward', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'ward_all' then update public.world_gw_members set fx = fx || public.world_cb_buff('ward_all', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'might' then update public.world_gw_members set fx = fx || public.world_cb_buff('might', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'might_all' then update public.world_gw_members set fx = fx || public.world_cb_buff('might_all', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'rally' then update public.world_gw_members set fx = fx || public.world_cb_buff('rally', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'resonance' then update public.world_gw_members set fx = fx || public.world_cb_buff('resonance', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'expose' then vbfx := vbfx || jsonb_build_object('expose', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int, 'by', m.owner_id));
        if e ? 'stagger' then vbfx := vbfx || jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + 1, 'block_by', m.owner_id); sealed := true; end if;
      when 'heal' then
        select least(round((e ->> 'amt')::int * 0.65), 100 - x.hp) into d from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0;
        perform public.world_gw_credit(p_fight, m.owner_id, d, case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.65)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
      when 'heal_all' then
        select sum(least(round((e ->> 'amt')::int * 0.65), 100 - x.hp)) into d from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest;
        perform public.world_gw_credit(p_fight, m.owner_id, d, 'heal');
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.65)::int) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'cleanse_heal' then
        select least(round((e ->> 'amt')::int * 0.65), 100 - x.hp) into d from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0;
        perform public.world_gw_credit(p_fight, m.owner_id, d, case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.65)::int), nameless = false where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
        freed := freed || tgt;
      when 'revive' then
        if exists (select 1 from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds > 0) then
          perform public.world_gw_credit(p_fight, m.owner_id, (e ->> 'hp')::int, 'heal'); end if;
        update public.world_gw_members set out_rounds = 0, rest = true, hp = (e ->> 'hp')::int where fight_id = p_fight and owner_id = tgt and out_rounds > 0;
      when 'cover' then update public.world_gw_members set fx = fx || jsonb_build_object('cover', tgt) where fight_id = p_fight and owner_id = m.owner_id;
      when 'gward' then update public.world_gw_members set fx = fx || public.world_cb_buff('gward', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
        if coalesce((e ->> 'mind')::int, 0) > 0 then
          update public.world_characters set mental = least(100, mental + (e ->> 'mind')::int), updated_at = now() where owner_id = tgt;
        end if;
      when 'break' then broke := true; v_brk := m.owner_id;
      when 'taunt' then update public.world_gw_members set fx = fx || public.world_cb_buff('taunt', e, m.owner_id) where fight_id = p_fight and owner_id = m.owner_id;
      when 'crit_all' then update public.world_gw_members set fx = fx || public.world_cb_buff('crit_all', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'evade' then update public.world_gw_members set fx = fx || public.world_cb_buff('evade', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'smoke' then vbfx := vbfx || jsonb_build_object('smoke', jsonb_build_object('n', (e ->> 'n')::int, 'miss', (e ->> 'miss')::int, 'by', m.owner_id));
      when 'crit_next' then update public.world_gw_members set fx = fx || public.world_cb_buff('crit_next', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'delay' then vbfx := vbfx || jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + (e ->> 'n')::int, 'block_by', m.owner_id); delayed := true;
      when 'shield' then update public.world_gw_members set fx = fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (e ->> 'amt')::int, 'shield_by', m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'sp' then
        if tgt <> m.owner_id then perform public.world_gw_credit(p_fight, m.owner_id, (select greatest(0, least((e ->> 'amt')::int, 100 - x.spiritual_power)) from public.world_characters x where x.owner_id = tgt)
          * coalesce((m.stats ->> 'attack')::numeric, 0) * 0.05, 'boost'); end if;
        update public.world_characters set spiritual_power = least(100, spiritual_power + (e ->> 'amt')::int), updated_at = now() where owner_id = tgt;
      else null;
    end case;
    perform public.world_gw_say(p_fight, r, 'skill', m.name || ' — 「' || sk.skill_name || '」' || case when sk.target = 'ally' and tgt <> m.owner_id then ' → ' || coalesce(tn, '') else '' end || ' · ' || sk.exp_text
      || case e ->> 'type' when 'cleanse_heal' then case when k = 'chain' then ' (사슬이 느슨해집니다)' when k = 'name' then ' (흐려진 이름이 또렷해집니다)' else '' end
                           when 'delay' then case when k = 'vortex' then ' (물살이 잠시 멎습니다)' else '' end
                           when 'expose' then case when k = 'face' then ' (주인의 입이 사슬에 묶입니다)' else '' end
                           when 'break' then ' (물의 기세가 꺾입니다)' else '' end || '.');
  end loop;
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest order by joined_at loop
    a := coalesce(m.act, '{"a":"guard"}'::jsonb); av := a ->> 'a';
    if av = 'coop' then
      if not coalesce((select (s.effect ->> 'strike')::boolean from public.world_coop_skills s where s.skill_id = m.act ->> 's'), false) then continue; end if;
      av := 'attack';
    elsif m.act is not null then update public.world_gw_members set acts = acts + 1 where fight_id = p_fight and owner_id = m.owner_id; end if;
    select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
    if av = 'attack' then
      cbr := public.world_cb_attack(m.stats, vfx, vbfx, 0.9, 0.2);
      vfx := cbr -> 'fx'; vbfx := cbr -> 'bfx'; cr := (cbr ->> 'crit')::boolean;
      v_mb := cbr -> 'src' ->> 'mb'; v_mp := (cbr -> 'src' ->> 'mp')::numeric; v_eb := cbr -> 'src' ->> 'eb'; v_ep := (cbr -> 'src' ->> 'ep')::numeric;
      v_cb := cbr -> 'src' ->> 'cb'; v_cp := (cbr -> 'src' ->> 'cp')::numeric; v_cn := cbr -> 'src' ->> 'cn';
      update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;
      d := (cbr ->> 'd')::numeric * (1 + coalesce((m.stats ->> 'solo_dmg')::numeric, 0) / 100.0);
      physical := coalesce(m.stats ->> 'style', 'melee') in ('melee', 'ranged');
      if m.nameless then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 이름을 잃어 칼끝이 주인에게 닿지 않습니다.');
      elsif k = 'face' and ((f.mech ->> 'face' = 'human') <> physical) then
        if sealed then
          d := d * 0.5; boss_dmg := boss_dmg + d;
          update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
          perform public.world_gw_credit_hit(p_fight, m.owner_id, d, cr, v_mb, v_mp, v_eb, v_ep, v_cb, v_cp, v_cn, coalesce((m.stats ->> 'crit')::numeric, 5));
          perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — 사슬에 묶인 주인이 힘을 삼키지 못합니다. ' || round(d) || '의 피해.');
        else
          boss_heal := boss_heal + round(d * 0.5);
          perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — ' || case when physical then '요괴의 얼굴에 칼을 대자' else '사람의 얼굴에 술법을 쓰자' end || ' 주인이 그 힘을 삼켜 ' || round(d * 0.5) || ' 회복합니다.');
        end if;
      else
        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;
        update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
          perform public.world_gw_credit_hit(p_fight, m.owner_id, d, cr, v_mb, v_mp, v_eb, v_ep, v_cb, v_cp, v_cn, coalesce((m.stats ->> 'crit')::numeric, 5));
        perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — ' || round(d) || case when cr then '의 치명타.' else '의 피해.' end);
      end if;
    elsif av in ('guard', 'brace') then
      if k = 'vortex' and (m.owner_id::text = f.mech ->> 'tank' or (av = 'brace' and vfx ? 'taunt')) then tank_ok := true;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — ' || case when av = 'brace' then '몸을 낮춰 소용돌이를 정면으로 받아 냅니다.' else '방패를 세우고 물살을 버팁니다.' end);
      elsif av = 'brace' and m.act is not null then
        perform public.world_gw_say(p_fight, r, 'guard', m.name || ' — 몸을 낮추고 버팁니다.');
      end if;
    elsif av = 'item' then
      tgt := coalesce(nullif(a ->> 't', '')::uuid, m.owner_id);
      if coalesce(m.items_used, 0) >= 2 then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 이 싸움에서는 회복품을 더 꺼낼 수 없습니다.');
      elsif coalesce(((select x.inventory from public.world_characters x where x.owner_id = m.owner_id) ->> (a ->> 'i'))::int, 0) < 1 then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 꺼낼 회복품이 없습니다.');
      else
        d := coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'hp')::numeric, 0)
             * case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end * case when m.job_key = 'medic' then case when tgt = m.owner_id then 1.15 else 1.4 end else 1 end
             * (1 + coalesce((m.stats ->> 'heal')::numeric, 0) / 100.0);
        update public.world_characters set inventory = public.world_inv_add(inventory, a ->> 'i', -1), updated_at = now() where owner_id = m.owner_id;
        perform public.world_gw_credit(p_fight, m.owner_id, (select least(round(d), 100 - x.hp) from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0),
          case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set hp = least(100, hp + round(d)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
        update public.world_characters set mental = least(100, mental + ceil(coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'mn')::numeric, 0) * case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end)::int)
         where owner_id = tgt and coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'mn')::numeric, 0) > 0;
        update public.world_gw_members set heal = heal + round(d)::int, items_used = items_used + 1 where fight_id = p_fight and owner_id = m.owner_id;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — ' || coalesce((select x.name from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt), '') || '의 체력 +' || round(d)
          || ' (회복품 ' || (coalesce(m.items_used, 0) + 1) || '/2).');
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
  if k = 'chain' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '끊지 못한 사슬에 끌려가');
    end loop;
    if exists (select 1 from public.world_gw_members where fight_id = p_fight and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text) then
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest loop
        if broke then perform public.world_gw_credit(p_fight, v_brk, 30 * 0.7, 'guard'); end if;
        perform public.world_gw_hit(p_fight, m.owner_id, 60 * case when broke then 0.5 else 1 end, r, '사슬이 끌어당긴 물살에', true);
      end loop;
    end if;
  elsif k = 'name' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and nameless loop
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
      if broke then perform public.world_gw_credit(p_fight, v_brk, (select sum(x.hp * 0.25) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest), 'guard'); end if;
      update public.world_gw_members x set hp = greatest(1, (x.hp * case when broke or x.fx ? 'gward' then 0.75 else 0.5 end)::int), fx = x.fx - 'gward'
       where x.fight_id = p_fight and x.out_rounds = 0 and not rest;
      update public.world_gw_fights set enrage = enrage + 1 where fight_id = p_fight;
      f.enrage := f.enrage + 1;
    end if;
  end if;
  update public.world_gw_fights set hp = least(max_hp, greatest(0, hp - round(boss_dmg)::int + round(boss_heal)::int)), updated_at = now() where fight_id = p_fight returning * into f;
  if f.hp <= 0 then update public.world_gw_fights set bfx = vbfx where fight_id = p_fight; perform public.world_gw_settle(p_fight, true); return; end if;
  if k in ('face', 'normal') then
    raw := (35 + 4 * f.phase) * (1 + 0.15 * f.enrage)
           * (select case count(*) when 1 then 1 when 2 then 1.4 when 3 then 0.8 else 0.85 end from public.world_gw_members where fight_id = p_fight);
    if aoe then
      perform public.world_gw_say(p_fight, r, 'boss', '모아 둔 기운이 터집니다. 왕좌 아래의 물이 한꺼번에 쏟아집니다!' || case when broke then ' (퇴마 결계가 물살을 절반으로 꺾었습니다)' else '' end);
      if broke then perform public.world_gw_credit(p_fight, v_brk, raw * 0.9 * 0.5 * 0.7 * (select count(*) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest), 'guard'); end if;
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest loop
        perform public.world_gw_hit(p_fight, m.owner_id, raw * 0.9 * case when broke then 0.5 else 1 end, r, '쏟아지는 물살에', true);
      end loop;
    elsif coalesce((vbfx ->> 'block')::int, 0) > 0 then
      vbfx := case when (vbfx ->> 'block')::int > 1 then jsonb_set(vbfx, '{block}', to_jsonb((vbfx ->> 'block')::int - 1)) else vbfx - 'block' end;
      perform public.world_gw_credit(p_fight, nullif(vbfx ->> 'block_by', '')::uuid, raw * 0.7 * (select case when count(*) >= 4 then 2 when count(*) = 3 then 1.5 else 1 end from public.world_gw_members x where x.fight_id = p_fight), 'guard');
      perform public.world_gw_say(p_fight, r, 'good', '주인의 손길이 묶여 허공을 가릅니다.');
    else
      select count(*) into v_n from public.world_gw_members where fight_id = p_fight;
      v_hands := case when v_n >= 4 then 2 when v_n = 3 then 1 + (r % 2) else 1 end;
      n := coalesce((vbfx -> 'smoke' ->> 'n')::int, 0);
      v_miss := coalesce((vbfx -> 'smoke' ->> 'miss')::numeric, 45);
      for v_h in 1 .. v_hands loop
        select * into m from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest and not (x.owner_id = any (v_hit))
         order by public.world_cb_pick_key(coalesce((x.stats ->> 'pres')::numeric, 30) + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)) limit 1;
        exit when m.owner_id is null;
        v_hit := v_hit || m.owner_id;
        hit_who := m.owner_id; cover_by := null;
        select owner_id into cover_by from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and fx ->> 'cover' = m.owner_id::text and owner_id <> m.owner_id limit 1;
        select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
        if n > 0 and random() * 100 < v_miss then
          perform public.world_gw_credit(p_fight, nullif(vbfx -> 'smoke' ->> 'by', '')::uuid, raw * 0.7, 'guard');
          perform public.world_gw_say(p_fight, r, 'miss', '연막 속에서 주인의 손길이 ' || m.name || '을(를) 비껴갑니다.');
        elsif random() * 100 < coalesce((m.stats ->> 'eva')::numeric, 0) + coalesce((vfx -> 'evade' ->> 'pct')::numeric, 0) + (case when m.stats ->> 'style' = 'magic' then 15 else 0 end) then
          if vfx -> 'evade' ->> 'by' is not null and vfx -> 'evade' ->> 'by' <> m.owner_id::text then
            perform public.world_gw_credit(p_fight, (vfx -> 'evade' ->> 'by')::uuid, raw * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0)
              * (vfx -> 'evade' ->> 'pct')::numeric / greatest(1, coalesce((m.stats ->> 'eva')::numeric, 0) + (vfx -> 'evade' ->> 'pct')::numeric), 'guard'); end if;
          if vfx ? 'evade' then update public.world_gw_members x set fx = case when (x.fx -> 'evade' ->> 'n')::int > 1 then jsonb_set(x.fx, '{evade,n}', to_jsonb((x.fx -> 'evade' ->> 'n')::int - 1)) else x.fx - 'evade' end where x.fight_id = p_fight and x.owner_id = m.owner_id; end if;
          perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 주인의 손길을 피했습니다.');
        elsif cover_by is not null then
          perform public.world_gw_credit(p_fight, cover_by, raw * 0.5 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0), 'guard');
          perform public.world_gw_hit(p_fight, cover_by, raw * 0.5, r, (select name from public.world_gw_members where fight_id = p_fight and owner_id = cover_by) || '이(가) ' || m.name || ' 앞을 막아서 주인의 ' || case when v_h > 1 then '다른 ' else '' end || '손아귀를', false);
        else
          perform public.world_gw_hit(p_fight, hit_who, raw, r, case when v_h > 1 then '주인의 다른 손아귀에' else '주인의 손아귀에' end, false);
        end if;
      end loop;
      if n > 0 and coalesce(array_length(v_hit, 1), 0) > 0 then vbfx := case when n > 1 then jsonb_set(vbfx, '{smoke,n}', to_jsonb(n - 1)) else vbfx - 'smoke' end; end if;
    end if;
  end if;
  update public.world_gw_members set out_rounds = out_rounds - 1, rest = rest or out_rounds = 1, hp = case when out_rounds = 1 then 30 else hp end where fight_id = p_fight and out_rounds > 0;
  update public.world_gw_members set fx = fx - 'cover' where fight_id = p_fight and fx ? 'cover';
  update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
  select count(*) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
  if (select count(*) from public.world_gw_members where fight_id = p_fight) = 1 and (select max(falls) - coalesce(max((stats ->> 'solo_falls')::int), 0) from public.world_gw_members where fight_id = p_fight) > 10 then
    perform public.world_gw_say(p_fight, r, 'bad', '쓰러질 수 있는 횟수를 넘겼습니다. 홀로 선 이의 넋이 더는 버티지 못합니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  if alive = 0 and (select count(*) from public.world_gw_members where fight_id = p_fight) > 1 then
    perform public.world_gw_say(p_fight, r, 'bad', '모두가 물러났습니다. 소용돌이가 왕좌를 덮습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  if now() >= f.ends_at then
    perform public.world_gw_say(p_fight, r, 'bad', '시간이 다 되었습니다. 귀허의 주인이 바다 밑으로 가라앉습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  perform public.world_gw_next_round(p_fight);
end $function$;

CREATE OR REPLACE FUNCTION public.world_cb_attack(p_stats jsonb, p_fx jsonb, p_bfx jsonb, p_lo numeric, p_span numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare f jsonb := coalesce(p_fx, '{}'); b jsonb := coalesce(p_bfx, '{}'); mul numeric := 1; cr boolean; n int; src jsonb;
  base_crit numeric := coalesce((p_stats ->> 'crit')::numeric, 5); cn text := coalesce(f ->> 'crit_next', f ->> 'critnext');
begin
  src := jsonb_build_object(
    'mb', case when coalesce((f -> 'might' ->> 'n')::int, 0) > 0 then f -> 'might' ->> 'by' end, 'mp', coalesce((f -> 'might' ->> 'pct')::numeric, 0),
    'eb', case when coalesce((b -> 'expose' ->> 'n')::int, 0) > 0 then b -> 'expose' ->> 'by' end, 'ep', coalesce((b -> 'expose' ->> 'pct')::numeric, 0),
    'cb', case when coalesce((f -> 'crit' ->> 'n')::int, 0) > 0 then f -> 'crit' ->> 'by' end, 'cp', coalesce((f -> 'crit' ->> 'pct')::numeric, 0), 'cn', cn);
  n := coalesce((f -> 'might' ->> 'n')::int, 0);
  if n > 0 then mul := mul * (1 + (f -> 'might' ->> 'pct')::numeric / 100.0); f := case when n > 1 then jsonb_set(f, '{might,n}', to_jsonb(n - 1)) else f - 'might' end; end if;
  if f ? 'bound' then mul := mul * 0.5; f := f - 'bound'; end if;
  n := coalesce((b -> 'expose' ->> 'n')::int, 0);
  if n > 0 then mul := mul * (1 + (b -> 'expose' ->> 'pct')::numeric / 100.0); b := case when n > 1 then jsonb_set(b, '{expose,n}', to_jsonb(n - 1)) else b - 'expose' end; end if;
  cr := cn is not null;
  f := f - 'crit_next' - 'critnext';
  n := coalesce((f -> 'crit' ->> 'n')::int, 0);
  if not cr then cr := random() * 100 < base_crit + case when n > 0 then (f -> 'crit' ->> 'pct')::numeric else 0 end; end if;
  if n > 0 then f := case when n > 1 then jsonb_set(f, '{crit,n}', to_jsonb(n - 1)) else f - 'crit' end; end if;
  if cr then mul := mul * case when cn is not null then (public.world_coop_rules() ->> 'sure_crit')::numeric else 1.5 end; end if;
  return jsonb_build_object('d', coalesce((p_stats ->> 'attack')::numeric, 50) * (p_lo + random() * p_span) * mul, 'crit', cr, 'fx', f, 'bfx', b, 'src', src);
end $function$;

CREATE OR REPLACE FUNCTION public.world_cb_boost_credits(p_d numeric, p_crit boolean, p_src jsonb, p_self uuid, p_critbase numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare c numeric := coalesce(p_d, 0); ex numeric; out jsonb := '[]'; s jsonb := coalesce(p_src, '{}');
  mb text := s ->> 'mb'; mp numeric := coalesce((s ->> 'mp')::numeric, 0); eb text := s ->> 'eb'; ep numeric := coalesce((s ->> 'ep')::numeric, 0);
  cb text := s ->> 'cb'; cp numeric := coalesce((s ->> 'cp')::numeric, 0); cn text := s ->> 'cn';
begin
  if c <= 0 then return out; end if;
  if mb is not null and mb <> p_self::text and mp > 0 then ex := p_d - p_d / (1 + mp / 100.0); out := out || jsonb_build_array(jsonb_build_array(mb, ex, 'boost')); c := c - ex; end if;
  if eb is not null and eb <> p_self::text and ep > 0 then ex := p_d - p_d / (1 + ep / 100.0); out := out || jsonb_build_array(jsonb_build_array(eb, ex, 'boost')); c := c - ex; end if;
  if p_crit and cn is not null and cn not in ('1', 'true', p_self::text) then ex := p_d - p_d / (public.world_coop_rules() ->> 'sure_crit')::numeric; out := out || jsonb_build_array(jsonb_build_array(cn, ex, 'boost')); c := c - ex;
  elsif p_crit and cb is not null and cb <> p_self::text and cp > 0 then
    ex := (p_d - p_d / 1.5) * cp / greatest(1, coalesce(p_critbase, 5) + cp); out := out || jsonb_build_array(jsonb_build_array(cb, ex, 'boost')); c := c - ex; end if;
  return out || jsonb_build_array(jsonb_build_array(p_self::text, greatest(0, c), 'dmg'));
end $function$;

CREATE OR REPLACE FUNCTION public.world_gw_hit(p_fight uuid, p_uid uuid, p_raw numeric, p_round integer, p_why text, p_aoe boolean)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare m public.world_gw_members%rowtype; r jsonb; c jsonb; av text; self_guard numeric;
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid for update;
  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  av := coalesce(m.act ->> 'a', 'guard');
  r := public.world_cb_mitigate(p_raw, m.stats, m.fx, p_uid, p_aoe, false, case when av in ('guard', 'brace') then av end, false);
  for c in select * from jsonb_array_elements(r -> 'credits') loop
    perform public.world_gw_credit(p_fight, (c ->> 0)::uuid, (c ->> 1)::numeric, c ->> 2);
  end loop;
  update public.world_gw_members set fx = r -> 'fx' where fight_id = p_fight and owner_id = p_uid;
  perform public.world_gw_credit(p_fight, p_uid, (r ->> 'd')::numeric, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);
  if not p_aoe and not coalesce((r ->> 'taunt')::boolean, false) then perform public.world_gw_credit(p_fight, p_uid, (r ->> 'd')::numeric, 'hit1'); end if;
  if not p_aoe then
    self_guard := p_raw * (1 - (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((m.stats ->> 'inc')::numeric, 0) / 100.0)
      * (1 - coalesce((m.stats ->> 'solo_guard')::numeric, 0) / 100.0)) * 0.5;
    if self_guard > 0 then perform public.world_gw_credit(p_fight, p_uid, self_guard, 'guard'); end if;
  end if;
  return public.world_gw_hurt(p_fight, p_uid, (r ->> 'd')::int, p_round, p_why);
end $function$;

CREATE OR REPLACE FUNCTION public.world_raid_snapshot_core(p_raid uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rd public.world_raids%rowtype; rid uuid := p_raid; me public.world_raid_members%rowtype;
  here text; mem jsonb; logs jsonb; tot numeric; ck numeric; can_join boolean := false; why text; coop jsonb := '[]'::jsonb; reveal_region boolean; reveal_c boolean; sh jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if exists (select 1 from public.world_raids where status in ('announced', 'signup', 'fight')
              and ((status = 'announced' and spawn_at <= now()) or (status = 'signup' and signup_until <= now()) or (status = 'fight' and ends_at <= now()))) then
    perform public.world_raid_tick();
  end if;
  if rid is null then
    select x.raid_id into rid from public.world_raid_members m join public.world_raids x on x.raid_id = m.raid_id
     where m.owner_id = uid and x.status in ('signup', 'fight') order by x.created_at desc limit 1;
  end if;
  if rid is null then
    select raid_id into rid from public.world_raids where kind = 'world' and status in ('signup', 'fight') order by created_at desc limit 1;
  end if;
  if rid is null then
    select raid_id into rid from public.world_raids where kind = 'world' order by coalesce(ended_at, spawn_at) desc nulls last limit 1;
  end if;
  select * into rd from public.world_raids where raid_id = rid;
  if not found then return jsonb_build_object('raid', null); end if;
  select * into me from public.world_raid_members where raid_id = rid and owner_id = uid;
  select region_id into here from public.world_map_regions where region_name = c.location;
  reveal_region := rd.status <> 'announced' or '12h' = any (rd.notices);
  reveal_c := rd.status <> 'announced' or '24h' = any (rd.notices);
  if rd.status = 'announced' and not reveal_c then return jsonb_build_object('raid', null); end if;
  sh := case when rd.status not in ('won', 'failed') then public.world_raid_shares(rid) end;
  select coalesce(sum(contrib), 0) into tot from public.world_raid_members where raid_id = rid;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.owner_id, 'name', x.name, 'level', x.level, 'job', x.job_key, 'hp', ch.health, 'sp', ch.spiritual_power,
      'out', case when x.left_at is null and x.out_until > now() then ceil(extract(epoch from x.out_until - now())) end, 'resting', x.left_at is null and x.out_until is not null and x.out_until <= now(), 'left', x.left_at is not null, 'dmg', x.dmg, 'heal', x.heal, 'taken', x.taken, 'coop', x.coop, 'acts', x.acts,
      'share', case when sh is not null then coalesce((sh ->> x.owner_id::text)::numeric, 0) when tot > 0 then round(x.contrib / tot * 100, 1) else 0 end, 'credits', coalesce(x.credits, '{}'::jsonb), 'me', x.owner_id = uid, 'away', rd.status = 'fight' and not public.world_raid_here(x.owner_id, rd.region_id),
      'buffs', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(x.fx) k), 'reward', case when x.owner_id = uid then x.reward end)
      order by x.contrib desc, x.joined_at), '[]'::jsonb)
    into mem from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id where x.raid_id = rid;
  select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'at', l.at, 'kind', l.kind, 'text', l.text, 'who', l.who, 'n', l.n) order by l.id), '[]'::jsonb) into logs
    from (select * from public.world_raid_log where raid_id = rid order by id desc limit 40) l;
  if me.owner_id is null and (rd.status = 'signup' or (rd.kind = 'world' and rd.status = 'fight')) then
    if rd.status = 'signup' and rd.signup_until <= now() then why := '신청 시간이 지났습니다.';
    elsif rd.status = 'fight' and rd.ends_at <= now() then why := '토벌이 끝났습니다.';
    elsif c.health <= 0 or c.downed_at is not null then why := '전투불능 상태에서는 합류할 수 없습니다.';
    elsif here is distinct from rd.region_id then why := (select region_name from public.world_map_regions where region_id = rd.region_id) || case when rd.status = 'fight' then '에 가면 토벌에 합류할 수 있습니다.' else '에 있어야 신청할 수 있습니다.' end;
    elsif rd.kind = 'final' and not exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id where a.owner_id = uid and b.owner_id = rd.leader_id) then why := '시작한 조사원의 파티원만 합류할 수 있습니다.';
    else can_join := true; end if;
  end if;
  if me.owner_id is not null then
    select coalesce(jsonb_agg(jsonb_build_object('id', s.skill_id, 'name', s.skill_name, 'desc', s.description, 'target', s.target, 'cost', s.cost, 'rank', s.unlock_rank,
        'unlocked', coalesce(c.combat_rank, 1) >= s.unlock_rank, 'type', s.effect ->> 'type',
        'cd', case when me.cd ? s.skill_id and (me.cd ->> s.skill_id)::timestamptz > now() then ceil(extract(epoch from (me.cd ->> s.skill_id)::timestamptz - now())) else 0 end) order by s.sort), '[]'::jsonb)
      into coop from public.world_coop_skills s where s.job_key = c.job_key;
  end if;
  return jsonb_build_object('raid', jsonb_build_object('id', rd.raid_id, 'kind', rd.kind, 'boss', rd.boss_name, 'status', rd.status,
      'region_id', case when reveal_region then rd.region_id end, 'region', case when reveal_region then (select region_name from public.world_map_regions where region_id = rd.region_id) end,
      'candidates', case when reveal_c and not reveal_region then (select jsonb_agg(x.region_name) from unnest(rd.candidates) cc join public.world_map_regions x on x.region_id = cc) end,
      'spawn_at', case when reveal_region then rd.spawn_at end, 'signup_until', rd.signup_until, 'ends_at', rd.ends_at, 'ended_at', rd.ended_at,
      'hp', rd.hp, 'max_hp', rd.max_hp, 'phase', rd.phase, 'intent', rd.intent, 'leader', rd.leader_id = uid,
      'charge', case when rd.fx ? 'charge' then (rd.fx -> 'charge') || jsonb_build_object('secs', case when (rd.fx -> 'charge' ->> 'until') is not null then greatest(0, round((rd.fx -> 'charge' ->> 'until')::numeric - extract(epoch from now())::numeric, 1)) end, 'dur', 8) end, 'boss_fx', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(rd.fx) k where k <> 'charge')),
    'members', mem, 'log', logs,
    'me', jsonb_build_object('joined', me.owner_id is not null, 'can_join', can_join, 'why', why, 'here', here = rd.region_id, 'away', me.owner_id is not null and rd.status = 'fight' and not public.world_raid_here(uid, rd.region_id),
      'hp', c.health, 'sp', c.spiritual_power, 'out', case when me.left_at is null and me.out_until > now() then ceil(extract(epoch from me.out_until - now())) end, 'resting', me.left_at is null and me.out_until is not null and me.out_until <= now(), 'left', me.left_at is not null,
      'items_left', case when rd.kind = 'final' and me.owner_id is not null then greatest(0, 5 - me.items_used) end,
      'solo', case when rd.kind = 'final' and me.owner_id is not null and (select count(*) from public.world_raid_members x where x.raid_id = rd.raid_id) = 1 then public.world_solo_aid(me.job_key) end,
      'fx', me.fx, 'coop', coop, 'job', c.job_key, 'combat_rank', coalesce(c.combat_rank, 1)),
    'locks', (select coalesce(jsonb_agg(jsonb_build_object('region_id', l.region_id, 'region', x.region_name, 'until', l.until)), '[]'::jsonb)
                from public.world_raid_locks l join public.world_map_regions x on x.region_id = l.region_id where l.until > now()));
end $function$;

CREATE OR REPLACE FUNCTION public.world_gw_snapshot(p_fight uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; rec public.world_gw_records%rowtype; c public.world_characters%rowtype;
  fid uuid := p_fight; why text; inv_f uuid; last_f uuid; gsh jsonb;
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
  gsh := public.world_gw_shares(fid);
  return jsonb_build_object('fight', jsonb_build_object('id', f.fight_id, 'status', f.status, 'hp', f.hp, 'max_hp', f.max_hp, 'phase', f.phase, 'round', f.round,
      'round_ends_at', f.round_ends_at, 'ends_at', f.ends_at, 'start_at', f.start_at, 'leader', f.leader_id, 'enrage', f.enrage,
      'mech', case f.mech ->> 'k' when 'chain' then jsonb_build_object('k', 'chain', 'colors', (select jsonb_agg(v order by v) from jsonb_each_text(f.mech -> 'colors') e(kk, v)), 'mine', f.mech -> 'colors' ->> uid::text,
                                                                     'aoe', f.mech -> 'aoe', 'tell', f.mech -> 'tell')
                              when 'vortex' then f.mech - 'need' || jsonb_build_object('need', (f.mech ->> 'need')::int)
                              else f.mech end,
      'bfx', (select coalesce(jsonb_agg(kk), '[]'::jsonb) from jsonb_object_keys(coalesce(f.bfx, '{}'::jsonb)) kk)),
    'now', now(), 'me', uid,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', m.owner_id, 'name', m.name, 'job', m.job_key, 'level', m.level, 'hp', m.hp, 'out', m.out_rounds, 'resting', m.rest,
        'nameless', m.nameless, 'acted', m.act is not null, 'dmg', m.dmg, 'heal', m.heal, 'taken', m.taken, 'falls', m.falls, 'credits', m.credits, 'share', coalesce((gsh ->> m.owner_id::text)::numeric, 0),
        'fx', (select coalesce(jsonb_agg(kk), '[]'::jsonb) from jsonb_object_keys(coalesce(m.fx, '{}'::jsonb)) kk)) order by m.joined_at), '[]'::jsonb) from public.world_gw_members m where m.fight_id = fid),
    'my_act', me.act, 'joined', me.owner_id is not null, 'sp', c.spiritual_power,
    'items', (select coalesce(jsonb_object_agg(k, (c.inventory ->> k)::int), '{}'::jsonb) from unnest(array['tonic', 'tonic_hq', 'herbal_extract', 'rejuv_pill', 'rejuv_pill_hq', 'grand_pill', 'grand_pill_hq', 'banyo_salve']) k
               where coalesce((c.inventory ->> k)::int, 0) > 0),
    'items_left', greatest(0, 2 - coalesce(me.items_used, 0)),
    'falls_cap', 10 + coalesce((select max((x.stats ->> 'solo_falls')::int) from public.world_gw_members x where x.fight_id = fid), 0),
    'solo', case when (select count(*) from public.world_gw_members x where x.fight_id = fid) = 1 then jsonb_build_object('dmg', me.stats -> 'solo_dmg', 'falls', me.stats -> 'solo_falls', 'guard', me.stats -> 'solo_guard') end,
    'skills', case when me.owner_id is not null then (select coalesce(jsonb_agg(jsonb_build_object('id', s.skill_id, 'name', s.skill_name, 'desc', s.description, 'target', s.target, 'cost', s.cost,
        'rounds', greatest(1, ceil(s.cooldown_s / 5.0)::int), 'rank', s.unlock_rank, 'unlocked', coalesce(c.combat_rank, 1) >= s.unlock_rank,
        'wait', greatest(0, coalesce((me.cds ->> s.skill_id)::int, 0) - f.round)) order by s.sort), '[]'::jsonb) from public.world_coop_skills s where s.job_key = c.job_key) end,
    'log', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'round', l.round, 'kind', l.kind, 'text', l.text) order by l.id), '[]'::jsonb)
              from (select * from public.world_gw_log where fight_id = fid order by id desc limit case when f.status in ('won', 'failed') then 200 else 60 end) l),
    'tips', case when coalesce(rec.kills, 0) > 0 then public.world_gw_tips() end);
end $function$;

CREATE OR REPLACE FUNCTION public.world_pfight_snapshot(p_fight uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_pfights%rowtype; me public.world_pfight_members%rowtype; psh jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into f from public.world_pfights where fight_id = p_fight;
  if not found then raise exception '없는 싸움입니다.'; end if;
  if not exists (select 1 from public.world_party_members m where m.party_id = f.party_id and m.owner_id = uid)
     and not exists (select 1 from public.world_pfight_members where fight_id = p_fight and owner_id = uid) then raise exception '파티원만 볼 수 있습니다.'; end if;
  if f.status = 'gather' and now() >= f.gather_ends then perform public.world_pfight_start(p_fight); end if;
  perform public.world_pfight_resolve(p_fight);
  select * into f from public.world_pfights where fight_id = p_fight;
  select * into me from public.world_pfight_members where fight_id = p_fight and owner_id = uid;
  psh := public.world_pfight_shares(p_fight);
  return jsonb_build_object('fight_id', f.fight_id, 'status', f.status, 'round', f.round, 'leader_id', f.leader_id, 'monster', f.monster_name, 'rank', f.rank, 'level', f.mlevel,
    'hp', f.hp, 'max_hp', f.max_hp, 'intent', f.intent, 'target_id', f.target_id, 'now', now(), 'gather_ends', f.gather_ends,
    'turn_id', f.turn_id, 'my_turn', f.status = 'fight' and f.turn_id = uid, 'mon_done', f.mon_done,
    'order', (select coalesce(jsonb_agg((o.v ->> 'id')::uuid order by o.i), '[]'::jsonb) from jsonb_array_elements(f.turn_order) with ordinality o(v, i)),
    'log', f.log, 'result', f.result, 'region_id', f.region_id,
    'can_join', me.owner_id is null and f.status in ('gather', 'fight') and now() <= f.gather_ends and public.world_pfight_ready(uid, f.region_id),
    'me', case when me.owner_id is null then null else jsonb_build_object('action', me.action, 'item', me.item, 'out', me.out_reason) end,
    'battle', case when me.owner_id is not null and me.out_reason is null then public.world_field_battle_view(uid) end,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', pm.owner_id, 'name', pm.name, 'out', pm.out_reason,
        'spd', (select (o.v ->> 'spd')::int from jsonb_array_elements(f.turn_order) o(v) where (o.v ->> 'id')::uuid = pm.owner_id),
        'health', c.health, 'mental', c.mental, 'sp', c.spiritual_power, 'job', c.job_key, 'dmg', pm.dmg, 'taken', pm.taken, 'heal', pm.heal, 'weak', pm.weak, 'share', coalesce((psh ->> pm.owner_id::text)::numeric, 0)) order by pm.joined_at), '[]'::jsonb)
      from public.world_pfight_members pm join public.world_characters c on c.owner_id = pm.owner_id where pm.fight_id = p_fight));
end $function$;

CREATE OR REPLACE FUNCTION public.world_raid_begin_fight(p_raid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare rd public.world_raids%rowtype; n int; s numeric; a numeric; hpv int;
begin
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if rd.status <> 'signup' then return; end if;
  select count(*), coalesce(sum((stats ->> 'attack')::numeric), 0), coalesce(avg((stats ->> 'attack')::numeric), 0) into n, s, a
    from public.world_raid_members where raid_id = p_raid;
  if n = 0 and rd.kind = 'final' then
    perform public.world_raid_settle(p_raid, false); return;
  end if;
  hpv := case when rd.kind = 'world' then greatest((public.world_shadow_rules() ->> 'hp_min')::numeric, round(s * (public.world_shadow_rules() ->> 'hp_mul')::numeric))
              else round(greatest(4716, a * 100) * case least(n, 4) when 1 then 2.4 when 2 then 3.3 when 3 then 2.9 else 3.3 end) end;
  update public.world_raids set status = 'fight', hp = hpv, max_hp = hpv, turn = 0, phase = 1,
    ends_at = now() + case when kind = 'world' then interval '2 hours' else interval '20 minutes' end, updated_at = now() where raid_id = p_raid;
  perform public.world_raid_say(p_raid, 'phase', rd.boss_name || '이(가) 모습을 드러냈습니다. 참가자 ' || n || '명 · 체력 ' || hpv || '.');
  if rd.kind = 'world' then
    perform public.world_raid_chat('「' || rd.boss_name || '」 토벌이 시작되었습니다(참가 ' || n || '명). ' || (select region_name from public.world_map_regions where region_id = rd.region_id) || '에 가면 지금도 합류할 수 있고, 현장의 봉연 띠에서 진행을 볼 수 있습니다.');
  end if;
end $function$;

CREATE OR REPLACE FUNCTION public.world_raid_join(p_raid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rd public.world_raids%rowtype; here text; hp_add int;
begin perform public.world_travel_guard('토벌 합류');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if not found then raise exception '알 수 없는 토벌입니다.'; end if;
  if not ((rd.status = 'signup' and rd.signup_until > now()) or (rd.kind = 'world' and rd.status = 'fight' and rd.ends_at > now())) then
    raise exception '%', case when rd.kind = 'final' then '합류 시간이 지났습니다. 진행은 관전으로 볼 수 있습니다.' else '토벌이 끝났습니다.' end; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 신청할 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions where owner_id = uid and status = 'active') then raise exception '원정 중에는 신청할 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities where owner_id = uid and status = 'active') then raise exception '자율 활동 중에는 신청할 수 없습니다.'; end if;
  select region_id into here from public.world_map_regions where region_name = c.location;
  if here is distinct from rd.region_id then
    raise exception '%에 있어야 참가할 수 있습니다.', (select region_name from public.world_map_regions where region_id = rd.region_id); end if;
  if rd.kind = 'final' and not exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id
                                        where a.owner_id = uid and b.owner_id = rd.leader_id) then
    raise exception '결전은 시작한 조사원의 파티원만 합류할 수 있습니다.'; end if;
  if rd.kind = 'final' and (select count(*) from public.world_raid_members where raid_id = p_raid) >= 4 then raise exception '결전은 4명까지입니다.'; end if;
  if exists (select 1 from public.world_raid_members where raid_id = p_raid and owner_id = uid and left_at is not null) then
    update public.world_raid_members set left_at = null, out_until = greatest(now(), left_at + interval '60 seconds') where raid_id = p_raid and owner_id = uid;
    perform public.world_raid_say(p_raid, 'join', c.character_name || ' — 토벌에 돌아왔습니다.');
    update public.world_raids set updated_at = now() where raid_id = p_raid;
    return jsonb_build_object('ok', true, 'content', '토벌에 돌아왔습니다. 쉬는 중이니 준비되면 행동하세요.');
  end if;
  if exists (select 1 from public.world_raid_members where raid_id = p_raid and owner_id = uid) then raise exception '이미 신청했습니다.'; end if;
  insert into public.world_raid_members(raid_id, owner_id, name, level, job_key, stats)
  values (p_raid, uid, c.character_name, c.level, c.job_key, public.world_raid_stats(uid));
  if rd.status = 'fight' then
    hp_add := round(coalesce((public.world_raid_stats(uid) ->> 'attack')::numeric, 0) * (public.world_shadow_rules() ->> 'hp_mul')::numeric * greatest(0.25, least(1, extract(epoch from rd.ends_at - now()) / 7200)));
    if not exists (select 1 from public.world_raid_members where raid_id = p_raid and owner_id <> uid) then hp_add := greatest(0, hp_add - rd.max_hp); end if;
    update public.world_raids set hp = hp + hp_add, max_hp = max_hp + hp_add, updated_at = now() where raid_id = p_raid;
    perform public.world_raid_say(p_raid, 'join', c.character_name || '(Lv' || c.level || ') — 토벌에 뛰어들었습니다. 그림자의 체력 +' || hp_add || '.');
  else
    perform public.world_raid_say(p_raid, 'join', c.character_name || '(Lv' || c.level || ') — 참가했습니다.');
    update public.world_raids set updated_at = now() where raid_id = p_raid;
  end if;
  return public.world_raid_snapshot(p_raid);
end $function$;

CREATE OR REPLACE FUNCTION public.world_raid_settle(p_raid uuid, p_won boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare rd public.world_raids%rowtype; m record; tot numeric; share numeric; rw_gil int; xp int; items jsonb; inv jsonb; lim int; k text; v int; room int;
  got text; lost text; cleared boolean; top uuid; revenge boolean; nxt timestamptz; reg text; sr jsonb := public.world_shadow_rules(); t0 timestamptz; stay numeric; lvm numeric;
begin
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if rd.status in ('won', 'failed') then return; end if;
  perform public.world_raid_recontrib(p_raid);
  t0 := coalesce(rd.signup_until, rd.created_at);
  update public.world_raids set status = case when p_won then 'won' else 'failed' end, ended_at = now(), intent = null, updated_at = now() where raid_id = p_raid;
  select coalesce(sum(contrib), 0) into tot from public.world_raid_members where raid_id = p_raid;
  select owner_id into top from public.world_raid_members where raid_id = p_raid order by contrib desc limit 1;
  revenge := rd.kind = 'world' and p_won and exists (select 1 from public.world_raid_locks where until > now());
  for m in select x.*, ch.level clv from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id where x.raid_id = p_raid loop
    share := case when tot > 0 then m.contrib / tot else 0 end;
    stay := least(1, greatest(0, extract(epoch from now() - greatest(m.joined_at, t0))) / greatest(1, extract(epoch from now() - t0)) / (sr ->> 'stay_full')::numeric);
    lvm := least(1, m.clv / (sr ->> 'gil_lv')::numeric);
    rw_gil := 0; xp := 0; items := '{}'::jsonb;
    if rd.kind = 'world' then
      if share >= 0.01 and m.acts > 0 then
        if p_won then
          rw_gil := round(least(1800, 300 * stay + 1700 * share) * lvm); xp := round(public.world_xp_need(m.clv) * least(0.35, 0.10 * stay + 0.6 * share));
          items := jsonb_build_object('seal_shard', 3 + floor(12 * share)::int);
          if random() < 0.45 then items := items || jsonb_build_object('spirit_core', 1 + (random() < 0.4)::int); end if;
          if random() < 0.25 then items := items || jsonb_build_object('heavenly_dew', 1); end if;
          if random() < 0.04 + 0.08 * share then items := items || jsonb_build_object((array['raid_norigae', 'raid_amulet', 'raid_mask'])[1 + floor(random() * 3)::int], 1); end if;
        else
          rw_gil := round((80 * stay + 300 * share) * lvm); xp := round(public.world_xp_need(m.clv) * 0.03 * stay); items := '{"seal_shard":1}'::jsonb;
        end if;
      end if;
    else
      cleared := exists (select 1 from public.world_raid_members y join public.world_raids z on z.raid_id = y.raid_id
                          where y.owner_id = m.owner_id and z.kind = 'final' and z.status = 'won' and z.raid_id <> p_raid);
      if p_won and m.acts > 0 then
        if cleared then rw_gil := 100; items := '{"seal_shard":2}'::jsonb;
        else rw_gil := 400; xp := round(public.world_xp_need(m.clv) * 0.5); items := '{"spirit_core":3,"heavenly_dew":2,"seal_shard":5}'::jsonb; end if;
      end if;
    end if;
    got := ''; lost := '';
    if rw_gil > 0 or items <> '{}'::jsonb then
      select inventory into inv from public.world_characters where owner_id = m.owner_id for update;
      inv := coalesce(inv, '{}'::jsonb); lim := public.world_bag_limit(m.owner_id);
      for k, v in select key, value::int from jsonb_each_text(items) loop
        room := least(v, public.world_bag_room(inv, k, lim));
        if room > 0 then inv := public.world_inv_add(inv, k, room); got := got || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || room || ' · '; end if;
        if room < v then lost := lost || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || (v - room) || ' · '; end if;
      end loop;
      update public.world_characters set inventory = inv, gil = gil + rw_gil, updated_at = now() where owner_id = m.owner_id;
    end if;
    if xp > 0 then perform public.world_grant_xp(m.owner_id, xp); end if;
    update public.world_raid_members set reward = jsonb_build_object('share', round(share * 100, 1), 'gil', rw_gil, 'xp', xp, 'items', items,
      'top', m.owner_id = top, 'revenge', revenge, 'lost', nullif(lost, '')) where raid_id = p_raid and owner_id = m.owner_id;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (m.owner_id, 'raid_result', case when p_won then rd.boss_name || ' 토벌 성공' else rd.boss_name || ' 토벌 실패' end,
      '기여도 ' || round(share * 100, 1) || '%' || case when rw_gil > 0 then ' · ' || rw_gil || '전' else '' end || case when xp > 0 then ' · 경험치 ' || round(xp * public.world_xp_damp_pct(m.owner_id, m.clv) / 100.0) else '' end
      || case when got <> '' then ' · ' || regexp_replace(got, ' · $', '') else '' end
      || case when lost <> '' then ' (가방이 모자라 두고 옴: ' || regexp_replace(lost, ' · $', '') || ')' else '' end
      || case when share < 0.01 and rd.kind = 'world' then ' · 기여도 1% 미만이라 보상이 없습니다' else '' end,
      jsonb_build_object('raid_id', p_raid));
    perform public.world_title_award_check(m.owner_id, 'raid');
  end loop;
  if rd.kind = 'world' then
    nxt := public.world_raid_schedule_next();
    if p_won then
      delete from public.world_raid_locks where true;
      perform public.world_raid_chat('「' || rd.boss_name || '」을(를) 물리쳤습니다! 봉연의 기운이 걷힙니다.' || case when revenge then ' 잠겼던 땅도 풀려납니다.' else '' end);
    else
      select region_name into reg from public.world_map_regions where region_id = rd.region_id;
      insert into public.world_raid_locks(region_id, raid_id, until) values (rd.region_id, p_raid, nxt + interval '3 hours')
      on conflict (region_id) do update set raid_id = excluded.raid_id, until = excluded.until;
      perform public.world_raid_chat('「' || rd.boss_name || '」을(를) 막지 못했습니다. ' || reg || '이(가) 봉연에 잠겼습니다. 그 둘레의 침식과 요괴가 짙어집니다. 다음 그림자를 물리치면 풀립니다.');
    end if;
  end if;
end $function$;

update public.world_patch_notes set body = body || $n$
### 토벌 기여도 셈법을 바꿉니다
봉연의 그림자에는 모든 레벨대의 조사원이 함께 모입니다. 그런데 지금까지는 공격력이 높은 사람이 기여 1등을 거의 차지했고, 방패나 의무관은 제 몫을 다해도 위에 오르기 어려웠습니다. 앞으로는 **레벨과 역할이 1등을 막지 않고, 그 판에서 가장 성실하게 싸운 사람이 위에 오르도록** 셈합니다.
- 기여도를 공격·버팀·치유·북돋움 네 갈래로 나누어, 갈래마다 각자 차지한 몫을 따로 잰 뒤 합칩니다. 방패는 버팀에서, 의무관은 치유에서, 북돋는 직업은 북돋움에서 1등을 노릴 수 있습니다.
- 공격 갈래는 실제로 깎은 피해도 조금 보지만, 대부분은 **자기 힘으로 얼마나 성실히 쳤는지**로 셉니다. 레벨과 장비에 들인 시간은 같은 노력이면 조금 앞서는 만큼만 반영되고, 덜 싸우면 뒤집힐 수 있습니다.
- 버팀은 나를 노린 공격을 받아 낸 것과 동료 대신 막아 준 것만 셉니다. 모두가 함께 맞는 광역은 셈하지 않습니다.
- 그림자가 거의 아프게 치지 않은 판에서는 버팀·치유가 작게, 거세게 친 판에서는 크게 셉니다.
- 레벨이 낮다고 기여도를 깎던 규칙은 없앴습니다. 다만 전 보상은 낮은 레벨일수록 조금 덜 받습니다.
- 토벌의 절반 넘게 함께했다면 기본 보상을 모두 받습니다. 끝무렵에 들어오면 기본 몫이 그만큼 줄어듭니다.
- 그림자가 훨씬 단단해집니다. 지난 회차는 몇 분 만에 끝났지만, 이제는 모두가 힘을 모아도 십오 분에서 이십 분쯤 싸워야 쓰러집니다.
- 그림자의 공격도 맞서는 사람의 힘에 맞춰 거세집니다. 방어와 회복을 챙기지 않으면 물러나게 되고, 기운 모으기는 다 함께 몰아쳐야 아슬아슬하게 끊깁니다.
- 결전·귀허의 주인·파티 토벌의 기록판에도 같은 셈법이 보입니다(보상은 그대로).
- 토벌 결과 알림의 경험치가 실제로 받는 양으로 적힙니다.

### 협동 기술 다듬기
- 암영 검객 「그림자 찌르기」는 그 자리에서 바로 찌르는 공격이 됩니다. 반드시 치명타이고, 보통 치명타보다 훨씬 아픕니다.
- 퇴마관 「약점 진언」으로 만든 치명타도 보통 치명타보다 크게 들어갑니다.
- 「급소 드러내기」·「봉인 사슬」은 봉연의 그림자에서 사람이 많을수록 더 여러 번 이어집니다.
- 월궁 사수 「약점 표시」·「추격 신호」는 함께 받는 사람이 많을수록 한 사람 몫이 조금씩 줄어듭니다. 넷까지는 그대로입니다.
$n$
where note_id = '1.0.0' and position('토벌 기여도 셈법을 바꿉니다' in body) = 0;

update public.world_coop_skills set effect = effect || '{"strike": true}'::jsonb,
  description = '그림자에서 급소를 찔러 곧바로 한 번 공격한다. 반드시 치명타이고 치명타 피해가 두 배.',
  exp_text = '그림자에서 급소를 찔렀습니다' where skill_id = 'art_mend';
update public.world_coop_skills set description = '동료 한 명의 다음 공격을 치명타로 만든다. 이 치명타는 피해가 두 배.' where skill_id = 'an_point';
update public.world_coop_skills set description = '요괴의 급소를 드러내 다음 세 번 받는 피해 +15%(봉연의 그림자에서는 사람이 많을수록 더 여러 번).' where skill_id = 'art_supply';
update public.world_coop_skills set description = '보스를 사슬로 묶는다. 다음 반격 한 번을 막고, 보스가 받는 피해가 여섯 번 동안 +15%(봉연의 그림자에서는 사람이 많을수록 더 여러 번).' where skill_id = 'seal_chain';
update public.world_coop_skills set description = '참가자 모두의 다음 두 번 공격 치명타율 +15%(함께 받는 사람이 넷보다 많으면 한 사람 몫이 줄어든다).' where skill_id = 'sc_mark';
update public.world_coop_skills set description = '참가자 모두의 다음 공격 피해 +25%(함께 받는 사람이 넷보다 많으면 한 사람 몫이 줄어든다).' where skill_id = 'sc_signal';

update public.world_app_meta set value = '20261106080000' where key = 'db_version';

update public.world_patch_notes set title = '[공지] 이번 주말, 별채에 새 식구가 옵니다', body = $n$두 번째 밤의 첫 주를 함께해 주셔서 고맙습니다. 이번 주말 업데이트와, 한두 주 뒤에 들어올 것들을 미리 알려 드립니다.

## 오늘 밤 바뀐 것
· **봉연의 그림자**가 서버 진도에 맞춰 더 단단하고 거세집니다. 기여도는 레벨이나 역할보다 **그 판에서 얼마나 성실하게 싸웠는지**를 크게 봅니다.
· 자세한 내용은 아래 **1.0.0** 패치노트에 있습니다.

## 이번 주말 · 별채와 꼬마 동무
· 꼬마 동무가 몇 종 더 찾아옵니다.
· 동무 도감에 갈래 표시와 소개 글이 붙습니다.
· 돌볼 때 동무가 하는 말이 다양해집니다.
· 별채 가구가 늘어납니다.

## 한두 주 뒤 · 확장 예고
아직 만드는 중이라 세부는 바뀔 수 있습니다.
· 새 외전
· 새 지역과 최고 레벨 상향
· 새 직업 **「조련사」**
· 새 보스와 새 장비, 새 꾸미기

## 늘 그렇듯
· 고칠 점이나 하고 싶은 말은 도움말·설정의 **「제보·소감」**으로 보내 주세요. 하나하나 읽고 답합니다.
· 스크린샷과 플레이 소감은 언제든 자유롭게 나눠 주세요.
· 초대권은 **11월 10일(화) 오전 10시**까지 쓸 수 있습니다. **설정 › 계정 › 「내 초대권」**에서 확인하세요.

오늘 밤도 등불을 들고, 함께 걸어요.$n$
where note_id = '0.0.0';
