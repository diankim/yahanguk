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
  select '{"hp_mul": 300, "hp_min": 7500, "stay_full": 0.5, "gil_lv": 20}'::jsonb
$function$;

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
- 그림자가 훨씬 단단해집니다. 지난 회차는 몇 분 만에 끝났지만, 이제 모두가 힘을 모아 십여 분은 싸워야 쓰러집니다.
- 결전·귀허의 주인·파티 토벌의 기록판에도 같은 셈법이 보입니다(보상은 그대로).
- 토벌 결과 알림의 경험치가 실제로 받는 양으로 적힙니다.
$n$
where note_id = '1.0.0' and position('토벌 기여도 셈법을 바꿉니다' in body) = 0;

update public.world_app_meta set value = '20261106080000' where key = 'db_version';
