-- 1.0.1 파티 원정 공동 전투(제보: 같이 갔는데 각자 따로 싸우고, 두 사람 기록이 서로 잘림)
-- 같은 원정지로 함께 떠난 파티원은 회차마다 한 싸움을 함께 치른다: 먼저 정산하는 사람이 파티 전체 싸움을 굴려
-- world_expedition_pfights에 남기고, 나머지는 같은 결과(승패·줄)를 받아 쓴다. 요괴 수 = 인원, 승률은 파티 평균 전투력·방어,
-- 요괴는 이목으로 표적, 기를 모아 터뜨리는·휩쓸리는 수법은 모두를 친다. 누구든 체력 30 아래면 그 싸움에서 모두 함께 물러난다.
-- 화면: 싸움 줄마다 fk(같은 싸움 열쇠) → 한 칸으로 묶음, 파티원 일지에 같은 줄이 들어 있어도 한 번만(world_expedition_progress).
create table if not exists public.world_expedition_pfights (
  fkey text primary key,
  fight boolean not null,
  data jsonb,
  created_at timestamptz not null default now()
);
alter table public.world_expedition_pfights enable row level security;
revoke all on public.world_expedition_pfights from public, anon, authenticated;
grant select, insert, delete on public.world_expedition_pfights to fn_owner_field;

-- 「파티 원정으로 함께 떠난 두 원정인가」 판정 원본(1.0.1). 같은 제안(world_party_exp_offers departed)의 출발자 명단에 둘 다 있고,
-- 그 제안이 처리된 순간(resolved_at = 같은 트랜잭션 now() = 출발 시각)에 같은 원정지·같은 기간으로 떠났어야 참.
-- 우연히 같은 때·같은 곳으로 따로 떠난 원정(파티원끼리든 아니든)은 거짓. 공동 전투(settle)·일지 섞기(progress)·함께 다녀온 덤(complete)이 이것만 쓴다.
create or replace function public.world_pexp_together(p_e1 uuid, p_e2 uuid) returns boolean
language sql stable set search_path = '' as $f$
  select coalesce((select a.node_id = b.node_id and a.minutes = b.minutes and a.started_at = b.started_at and a.owner_id <> b.owner_id
      and exists (select 1 from public.world_party_exp_offers po
                   where po.status = 'departed' and po.node_id = a.node_id and po.minutes = a.minutes and po.resolved_at = a.started_at
                     and po.result -> 'started' ? a.owner_id::text and po.result -> 'started' ? b.owner_id::text)
    from public.world_expeditions a, public.world_expeditions b where a.expedition_id = p_e1 and b.expedition_id = p_e2), false)
$f$;
revoke all on function public.world_pexp_together(uuid, uuid) from public, anon, authenticated;

-- 파티 원정 규칙 수치 원본(1.0.1). 서버 함수와 화면·도움말(tools/gamedata/gen.py → gamedata.js partyExp → rules.js)이 이것만 읽는다.
create or replace function public.world_pexp_rules() returns jsonb language sql immutable as $f$
  select jsonb_build_object('flee_hp', 30, 'threat_pct', 45, 'bonus_pct', 10, 'bonus_cap', 3, 'overlap_min', 10)
$f$;
revoke all on function public.world_pexp_rules() from public, anon, authenticated;
grant execute on function public.world_pexp_rules() to fn_owner_field;
grant execute on function public.world_pexp_together(uuid, uuid) to fn_owner_field;

CREATE OR REPLACE FUNCTION public.world_expedition_settle(p_exp uuid, p_upto integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  e public.world_expeditions%rowtype; c public.world_characters%rowtype; n public.world_exploration_nodes%rowtype;
  r public.world_map_regions%rowtype; m public.world_region_monsters%rowtype;
  total int; target int; i int; last_i int; t timestamptz; span interval; roll float8; win_p float8; depth int; danger int;
  st jsonb; sup jsonb; loot jsonb; lg jsonb; jr jsonb := '[]'::jsonb; seq int := 0;
  hp int; mn int; er int; wins int; losses int; gathers int; finds int; hazards int; discovered int;
  xp int; cxp int; gxp int; ixp int; gil_gain int; jobn int; job_once boolean; weak_bonus float8; ended text; short int;
  wt int := 0; at_ int := 0; tt int := 0; power float8; defense float8; threat float8; dmg int; heal int;
  grit boolean := false; p_fight float8; dmg_mul float8; loot_mul float8; disc_mul float8; heal_at int;
  item text; qty int; pool text[]; rare_pool text[]; spirit_mech boolean; found_node uuid; found_spot uuid;
  me text; foe text; a_n int; b_n int; k int; ehp int; my_hit int; left_d int; part int; h0 int; h1 int;
  base_t timestamptz; won boolean;
  oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true); g_gq float8; g_heal float8; v_pct float8;
  g_inc float8; g_ml float8; g_er float8; g_rare float8; pres float8; allies jsonb := '[]'::jsonb; act jsonb; al jsonb;
  nal int; sum_ally float8; tot_w float8; pick float8; my_taken int; gear_item text; who_n text; who_o uuid; pend int; fx jsonb; wtype text; brank int; ammo_k text; ammo_have int := 0; ammo_used int := 0; cfx jsonb; cl jsonb; skf jsonb; skl jsonb;
  -- 1.0.1 파티 원정 공동 전투: 회차마다 같은 원정의 파티원은 한 싸움(world_expedition_pfights)을 나눠 쓴다
  v_fkey text; fk text; pfd jsonb; fthr float8; joined boolean; j0 int; minhp int; lowp text; flee boolean; apow float8; adef float8; plines jsonb; pend_at timestamptz; k2 int;
begin
  select * into e from public.world_expeditions where expedition_id = p_exp and status = 'active' for update;
  if not found then return 0; end if;
  total := case e.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end;
  target := coalesce(p_upto, floor(total * extract(epoch from least(now(), e.ends_at) - e.started_at) / (e.minutes * 60.0))::int);
  target := greatest(0, least(total, target));
  if target <= e.settled_rounds then return e.settled_rounds; end if;

  st := coalesce(e.state, jsonb_build_object('sup', e.supplies, 'loot', '{}'::jsonb, 'log', '[]'::jsonb, 'wins', 0, 'losses', 0, 'gathers', 0, 'finds', 0,
    'hazards', 0, 'discovered', 0, 'xp', 0, 'cxp', 0, 'gxp', 0, 'ixp', 0, 'gil', 0, 'jobn', 0, 'job_once', false, 'weak', 0, 'ended', 'complete', 'short', 0));
  if st ->> 'ended' in ('downed', 'exhausted') then return e.settled_rounds; end if;

  select * into c from public.world_characters where owner_id = e.owner_id for update;
  -- 효과는 원정 주인 기준으로 잰다(7.5.2: 예약 작업·파티원이 불러도 같은 값)
  perform set_config('request.jwt.claim.sub', e.owner_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', e.owner_id, 'role', 'authenticated')::text, true);
  -- 동료 원정의 합동 전투에서 이 캐릭터가 대신 맞은 피해(쓰러뜨리지는 않는다)
  delete from public.world_expedition_hits where owner_id = e.owner_id and created_at < e.started_at;
  with d as (delete from public.world_expedition_hits where owner_id = e.owner_id returning amount) select coalesce(sum(amount), 0) into pend from d;
  if pend > 0 then c.health := greatest(1, c.health - pend); end if;
  select * into r from public.world_map_regions where region_id = e.region_id;
  select * into n from public.world_exploration_nodes where node_id = e.node_id;
  if n.node_id is null then select * into n from public.world_exploration_nodes where region_id = e.region_id and hierarchy_level = 2 limit 1; end if;
  depth := greatest(1, least(3, n.hierarchy_level - 1));
  danger := r.danger_level + n.hierarchy_level - 2;
  me := c.character_name;
  span := e.ends_at - e.started_at;

  select coalesce(max(case when eq.slot = 'weapon' then ic.tier end), 0), coalesce(max(case when eq.slot = 'armor' then ic.tier end), 0),
         coalesce(max(case when eq.slot = 'tool' then ic.tier end), 0)
    into wt, at_, tt from public.world_character_equipment eq join public.world_item_catalog ic on ic.item_id = eq.item_id where eq.owner_id = e.owner_id;
  power := 12 + c.level * 5 + greatest(c.strength, c.spirit_affinity * 0.75 + c.willpower * 0.4) * 2.5 + c.agility * 1.5 + c.perception + wt * 14 + coalesce(c.combat_rank, 1) * 1.2;
  defense := c.level * 2 + c.vitality * 3 + at_ * 12;

  -- 장비 특성: 관모·신·노리개·호신부·탈과 무기·방어구의 덧붙은 성능
  -- 장비·칭호·상태·날씨·소속·직업·침식·섬·레벨 차·봉연 잠김(7.5.2, 전에는 장비만)
  defense := defense + (public.world_status_effect_total('defense') + public.world_title_bonus('defense')) * 2;
  g_inc := greatest(-60, public.world_status_effect_total('incoming_damage_pct') + public.world_title_bonus('incoming_damage_pct')
    - (public.world_status_effect_total('evasion_pct') + public.world_title_bonus('evasion_pct')) * 0.5);
  g_ml := public.world_status_effect_total('mental_loss_pct'); g_er := public.world_status_effect_total('erosion_pct');
  g_rare := public.world_status_effect_total('rare_loot_pct') + public.world_title_bonus('rare_loot_pct');
  g_gq := public.world_status_effect_total('gather_qty_pct') + public.world_title_bonus('gather_qty_pct');
  g_heal := greatest(-50, public.world_status_effect_total('healing_pct'));
  pres := coalesce((public.world_combat_stats(e.owner_id) ->> 'presence')::float8, 30);
 wtype := coalesce((select ic.equipment_traits ->> 'weapon_type' from public.world_character_equipment q join public.world_item_catalog ic on ic.item_id = q.item_id where q.owner_id = e.owner_id and q.slot = 'weapon' limit 1), 'melee');
  -- 주는 피해(근접·원거리·술법 포함, 합 35%까지)와 치명타 절반(직업 피해 %는 그 역할 무기를 들었을 때만)
  v_pct := least(35, public.world_status_effect_total('combat_damage_pct') + public.world_title_bonus('combat_damage_pct')
    + public.world_status_effect_total(wtype || '_pct') + public.world_title_bonus(wtype || '_pct'));
  power := power * (1 + (v_pct + (public.world_status_effect_total('crit_pct') + public.world_title_bonus('crit_pct')) * 0.5) / 100.0);
  ammo_k := public.world_ammo_of(e.owner_id);
  ammo_have := CASE WHEN ammo_k IS NULL THEN 0 ELSE coalesce((c.inventory ->> ammo_k)::int, 0) END;
  IF ammo_k IS NOT NULL AND ammo_have < 1 THEN power := power * 0.6; END IF;
 brank := coalesce((c.skill_progress -> 'guarding' ->> 'rank')::int, 0);
  skf := public.world_exp_skill_fx(e.owner_id); power := power * (1 + coalesce((skf ->> 'atk')::float8, 0) / 100.0);
  -- 같은 지역으로 원정 중인 파티원: 같은 시각에 있으면 함께 싸우고, 요괴는 이목이 높은 쪽을 먼저 노린다
  select coalesce(jsonb_agg(jsonb_build_object('owner', pc.owner_id, 'name', pc.character_name,
      'power', 12 + pc.level * 5 + greatest(pc.strength, pc.spirit_affinity * 0.75 + pc.willpower * 0.4) * 2.5 + pc.agility * 1.5 + pc.perception + coalesce(w.tier, 0) * 14 + coalesce(pc.combat_rank, 1) * 1.2,
      'def', pc.level * 2 + pc.vitality * 3 + coalesce(ar.tier, 0) * 12, 'hp', pc.health,
      'pres', coalesce((public.world_combat_stats(pc.owner_id) ->> 'presence')::float8, 30), 'from', pe.started_at, 'to', pe.ends_at)), '[]'::jsonb)
    into allies
    from public.world_party_members mp join public.world_party_members pm on pm.party_id = mp.party_id and pm.owner_id <> e.owner_id
    join public.world_expeditions pe on pe.owner_id = pm.owner_id and pe.status = 'active' and pe.region_id = e.region_id
      and coalesce(pe.state ->> 'ended', 'complete') not in ('downed', 'exhausted')
    join public.world_characters pc on pc.owner_id = pm.owner_id and pc.health > 0
    left join lateral (select ic.tier from public.world_character_equipment q join public.world_item_catalog ic on ic.item_id = q.item_id
      where q.owner_id = pm.owner_id and q.slot = 'weapon') w on true
    left join lateral (select ic.tier from public.world_character_equipment q join public.world_item_catalog ic on ic.item_id = q.item_id
      where q.owner_id = pm.owner_id and q.slot = 'armor') ar on true
   where mp.owner_id = e.owner_id
     -- 1.0.1 함께 싸우는 것은 「파티 원정」으로 함께 떠난 사람들만: 같은 제안(world_party_exp_offers departed)의 출발자이고,
     -- 그 제안이 처리된 순간(resolved_at = 같은 트랜잭션의 now())에 둘 다 떠났으며 같은 원정지·같은 기간. 우연히 같은 때 따로 떠난 원정은 각자 싸운다.
     and public.world_pexp_together(e.expedition_id, pe.expedition_id);
  if random() < 0.05 then delete from public.world_expedition_pfights where created_at < now() - interval '1 day'; end if;
  p_fight := case e.stance when 'cautious' then 0.22 when 'bold' then 0.5 else 0.35 end + danger * 0.012;
  dmg_mul := case e.stance when 'cautious' then 0.7 when 'bold' then 1.3 else 1.0 end;
  loot_mul := case e.stance when 'cautious' then 0.8 when 'bold' then 1.3 else 1.0 end * (1 + (depth - 1) * 0.15); loot_mul := loot_mul * ((e.minutes / 10.0) / total);
  if c.major_faction_id = 'red_moon_cult' and e.stance = 'bold' then loot_mul := loot_mul * 1.15; end if;
  disc_mul := case e.stance when 'cautious' then 0.85 when 'bold' then 1.2 else 1.0 end;
  if c.major_faction_id = 'mandate_court' then disc_mul := disc_mul * 1.2; end if;
  disc_mul := disc_mul * (1 + coalesce((skf ->> 'find')::float8, 0) / 100.0); loot_mul := loot_mul * (1 + coalesce((skf ->> 'loot')::float8, 0) / 100.0);
  heal_at := case e.stance when 'cautious' then 60 when 'bold' then 30 else 45 end;
  pool := array(select distinct x from public.world_gathering_spots s join public.world_exploration_nodes y on y.node_id = s.node_id, unnest(s.loot_items) x
                where y.region_id = r.region_id and y.hierarchy_level <= n.hierarchy_level + 1);
  rare_pool := array(select x from public.world_region_profiles p, unnest(p.signature_items) x join public.world_item_catalog ic on ic.item_id = x
                     where p.region_id = r.region_id and x not in ('courier_token', 'spirit_compass'));

  sup := st -> 'sup'; loot := st -> 'loot'; lg := st -> 'log';
  wins := (st ->> 'wins')::int; losses := (st ->> 'losses')::int; gathers := (st ->> 'gathers')::int; finds := (st ->> 'finds')::int;
  hazards := (st ->> 'hazards')::int; discovered := (st ->> 'discovered')::int; xp := (st ->> 'xp')::int; cxp := (st ->> 'cxp')::int;
  gxp := (st ->> 'gxp')::int; ixp := (st ->> 'ixp')::int; gil_gain := (st ->> 'gil')::int; jobn := (st ->> 'jobn')::int;
  job_once := (st ->> 'job_once')::boolean; weak_bonus := (st ->> 'weak')::float8; ended := st ->> 'ended'; short := (st ->> 'short')::int;
  hp := c.health; mn := c.mental; er := c.erosion;
  last_i := e.settled_rounds;

  for i in e.settled_rounds + 1 .. target loop
    t := e.started_at + span * i / total;
    base_t := t - interval '60 seconds';
    seq := 0;
    last_i := i;
    -- 한 시간마다 노정 건량
    h0 := floor(e.minutes * (i - 1) / total / 60.0)::int; h1 := floor(e.minutes * i / total / 60.0)::int;
    if h1 > h0 then
      if coalesce((sup ->> 'travel_ration')::int, 0) > 0 then sup := jsonb_set(sup, '{travel_ration}', to_jsonb((sup ->> 'travel_ration')::int - 1));
      else short := short + 1; mn := mn - 6;
        if short = 1 then lg := lg || jsonb_build_array('노정 건량이 모자라 허기진 채로 걸었습니다.'); end if;
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', me, 'owner', e.owner_id, 'text', '허기 때문에 정신 -6');
      end if;
    end if;

    roll := random();
    fthr := least(p_fight, 1) * (1 - (0.03 + danger * 0.01) * case e.stance when 'bold' then 1.3 when 'cautious' then 0.7 else 1 end);
    act := coalesce((select jsonb_agg(x) from jsonb_array_elements(allies) x where (x ->> 'from')::timestamptz <= t and (x ->> 'to')::timestamptz >= t), '[]'::jsonb);
    nal := jsonb_array_length(act); joined := false; pfd := null; v_fkey := null;
    fk := md5(e.expedition_id::text || '|' || i);
    if nal > 0 then
      -- 같은 회차·같은 지역·같은 사람들 = 한 싸움. 먼저 정산하는 사람이 굴리고, 나머지는 그 결과를 받아 쓴다(회차 시각이 같아야 함 = 함께 떠난 원정)
      v_fkey := md5(r.region_id || '|' || t::text || '|' || (select string_agg(o, ',' order by o) from (select e.owner_id::text o union select x ->> 'owner' from jsonb_array_elements(act) x) q));
      perform pg_advisory_xact_lock(hashtext('yh_pexp:' || v_fkey));
      select jsonb_build_object('fight', pf.fight) || coalesce(pf.data, '{}'::jsonb) into pfd from public.world_expedition_pfights pf where pf.fkey = v_fkey;
      if pfd is not null then
        if (pfd ->> 'fight')::boolean then joined := true; fk := coalesce(pfd ->> 'fk', fk);
        elsif roll < fthr then roll := fthr + random() * (1 - fthr); end if;
      elsif roll >= fthr then
        insert into public.world_expedition_pfights(fkey, fight) values (v_fkey, false) on conflict do nothing;
      end if;
    end if;
    if coalesce((skf ->> 'heal')::int, 0) > 0 and hp > 0 and hp < 100 and random() < 0.5 then
      hp := least(100, hp + (skf ->> 'heal')::int);
      if random() < 0.15 and jsonb_array_length(coalesce(skf -> 'camp', '[]'::jsonb)) > 0 then
        skl := (skf -> 'camp') -> floor(random() * jsonb_array_length(skf -> 'camp'))::int;
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[' || (skl ->> 'n') || '] ' || (skl ->> 't'));
      end if;
    end if;

    if joined then
      -- 1.0.1 동료가 먼저 굴린 공동 싸움: 같은 줄을 일지에 받아 적고(화면은 중복을 걸러 한 번만), 승패·수는 함께, 전리품·경험은 각자
      plines := coalesce(pfd -> 'lines', '[]'::jsonb);
      jr := jr || plines;
      won := coalesce((pfd ->> 'won')::boolean, false); flee := coalesce((pfd ->> 'flee')::boolean, false); foe := pfd ->> 'foe';
      select * into m from public.world_region_monsters where monster_id = pfd ->> 'mid' limit 1;
      spirit_mech := coalesce(m.mechanic_key, '') in ('spectral', 'warded', 'seal_breaker');
      perform public.world_codex_mark(e.owner_id, x, 1, case when won then 1 else 0 end) from jsonb_array_elements_text(coalesce(pfd -> 'ids', '[]'::jsonb)) x where x is not null;
      pend_at := coalesce((pfd ->> 'end_at')::timestamptz, base_t);
      k2 := greatest(1, coalesce((pfd ->> 'n')::int, 2) - 1);
      if won then
        wins := wins + 1; xp := xp + 10 + danger * 2 + (5 + danger) * k2; cxp := cxp + 16; gil_gain := gil_gain + 2 + danger;
        if m.drops is not null and random() < 0.7 * loot_mul then
          select d.k into item from jsonb_each(m.drops) d(k, v) where exists (select 1 from public.world_item_catalog ic where ic.item_id = d.k) order by random() limit 1;
          if item is not null then loot := public.world_inv_add(loot, item, 1); end if;
        end if;
        for k in 1..k2 loop
          if m.drops is not null and random() < 0.35 * loot_mul then
            select dd.k into item from jsonb_each(m.drops) dd(k, v) where exists (select 1 from public.world_item_catalog ic where ic.item_id = dd.k) order by random() limit 1;
            if item is not null then loot := public.world_inv_add(loot, item, 1); end if;
          end if;
        end loop;
        gear_item := public.world_gear_roll(m.mechanic_key, n.min_level + 1, case when m.role = 'guardian' then 'guardian' else 'normal' end, (g_rare - 40)::numeric);
        if gear_item is not null then
          loot := public.world_inv_add(loot, gear_item, 1);
          lg := lg || jsonb_build_array(foe || '이(가) 지니고 있던 ' || (select item_name from public.world_item_catalog where item_id = gear_item) || '을(를) 챙겼습니다.');
          jr := jr || jsonb_build_object('at', pend_at + interval '2 seconds', 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', foe || '이(가) 지니고 있던 장비를 챙겼습니다. (귀환 후 정리)');
        end if;
        if wins <= 3 then lg := lg || jsonb_build_array(foe || '을(를) 동료와 함께 물리쳤습니다.'); end if;
      else
        losses := losses + 1;
        if c.job_key = 'artificer' and not flee then weak_bonus := 0.15; end if;
        lg := lg || jsonb_build_array(case when flee then foe || '에게서 동료와 함께 물러났습니다.' else foe || '에게 동료와 함께 밀려 물러났습니다.' end);
      end if;
      -- 일지 승리 줄(퀘스트 셈용, 화면에는 안 보임): 내 이름으로
      jr := jr || jsonb_build_object('at', pend_at, 'kind', case when won then 'win' else 'lose' end, 'who', me, 'owner', e.owner_id, 'mid', m.monster_id,
        'rank', case when m.role = 'guardian' then 'guardian' else 'normal' end, 'rg', r.region_id, 'fk', fk, 'hide', true, 'text', foe);
      mn := mn - round((case when spirit_mech then 3 else 1 end) * greatest(0, 1 + g_ml / 100.0))::int;
    elsif roll < fthr then
      j0 := jsonb_array_length(jr);
      select * into m from public.world_region_monsters where (region_id = r.region_id or (role = 'common' and region_id in (select x.region_id from public.world_map_regions x where x.territory_id = r.territory_id and x.region_id <> r.region_id and not coalesce(x.is_safe_zone, false) and abs(coalesce(x.min_level, 1) - coalesce(r.min_level, 1)) <= 3))) and (role <> 'guardian' or depth >= 3)
        order by -ln(greatest(random(), 1e-9)) / (case role when 'common' then 6 when 'guardian' then 0.6 else 4 end * case when region_id = r.region_id then 1 else 0.3 end) limit 1;
      if m.monster_id is null and v_fkey is not null then
        insert into public.world_expedition_pfights(fkey, fight) values (v_fkey, false) on conflict do nothing;
      end if;
      if m.monster_id is not null then
        foe := m.monster_name;
        threat := ((70 + (n.min_level + 1) * 14) / 8.0 + (8 + (n.min_level + 1) * 1.1) * 2) * case when m.role = 'guardian' then 2.4 else 1 end * (1 + (depth - 1) * 0.25);
        spirit_mech := coalesce(m.mechanic_key, '') in ('spectral', 'warded', 'seal_breaker');
        threat := threat / power(public.world_kind_mult(m.kind, wtype, c.job_key)::float8, 0.6);
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'fight', 'who', me, 'owner', e.owner_id,
          'text', foe || case when m.role = 'guardian' then '(우두머리)' else '' end || '와(과) 마주쳤습니다.');
        sum_ally := coalesce((select sum((x ->> 'power')::float8) from jsonb_array_elements(act) x), 0);
        if nal > 0 then
          threat := threat * (1 + (public.world_pexp_rules() ->> 'threat_pct')::numeric / 100 * nal);
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'fight', 'who', me, 'owner', e.owner_id,
            'text', (select string_agg(x ->> 'name', '·') from jsonb_array_elements(act) x) || '와(과) 함께 맞섭니다.');
        end if;
        apow := (power + sum_ally) / (1 + nal);
        adef := (defense + coalesce((select sum((x ->> 'def')::float8) from jsonb_array_elements(act) x), 0)) / (1 + nal);
        win_p := (apow * (1 + 0.6 * nal)) / (apow * (1 + 0.6 * nal) + threat);
    -- 협동 기술(6.1.0): 함께 싸우는 사람들의 열린 협동 기술이 확률로 저절로 나온다
    if nal > 0 then
      cfx := public.world_coop_exp_procs(e.owner_id, act);
      win_p := win_p + coalesce((cfx ->> 'win')::float8, 0);
      hp := least(100, hp + coalesce((cfx ->> 'heal')::int, 0));
      for cl in select value from jsonb_array_elements(coalesce(cfx -> 'lines', '[]'::jsonb)) loop
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', cl ->> 'who', 'owner', cl ->> 'owner', 'text', cl ->> 'text');
      end loop;
    end if;
        if spirit_mech then
          win_p := win_p + c.spirit_affinity * 0.004;
          if coalesce((sup ->> 'seal_paper')::int, 0) > 0 then
            sup := jsonb_set(sup, '{seal_paper}', to_jsonb((sup ->> 'seal_paper')::int - 1));
            win_p := win_p + case when c.job_key in ('sealmaster', 'exorcist') then 0.25 else 0.15 end;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '황지에 봉인 술식을 적어 요기를 누릅니다.');
          end if;
        end if;
        if c.job_key = 'scout' and random() < 0.3 then
          win_p := win_p + 0.12; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[선제 사격] 요괴가 다가오기 전에 먼저 쏘아 기세를 꺾었습니다.');
        end if;
        if c.job_key = 'analyst' and random() < 0.25 then
          win_p := win_p + 0.1; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[급소 찌르기] 요괴의 급소를 짚어 단번에 파고듭니다.');
        end if;
        if weak_bonus > 0 then
          win_p := win_p + weak_bonus; weak_bonus := 0; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[반격 태세] 앞서 밀렸던 싸움을 되새겨 빈틈없이 맞받아칩니다.');
        end if;
        win_p := win_p + coalesce((skf ->> 'win')::float8, 0);
        if jsonb_array_length(coalesce(skf -> 'fight', '[]'::jsonb)) > 0 and random() < 0.3 then
          skl := (skf -> 'fight') -> floor(random() * jsonb_array_length(skf -> 'fight'))::int;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[' || (skl ->> 'n') || '] ' || (skl ->> 't'));
        end if;
        win_p := greatest(0.08, least(0.95, win_p));
        if c.job_key = 'exorcist' and spirit_mech and not job_once then
          win_p := 1; job_once := true; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[파사 부적] ' || foe || '의 요기를 부적으로 단번에 꿰뚫었습니다.');
        end if;
        ehp := greatest(8, round(threat * 1.6)::int);
        flee := false; minhp := hp; lowp := me;
        if nal > 0 then
          select x ->> 'name', (x ->> 'hp')::int into lowp, minhp from jsonb_array_elements(act) x order by (x ->> 'hp')::int limit 1;
          if hp <= minhp then minhp := hp; lowp := me; end if;
          flee := minhp < (public.world_pexp_rules() ->> 'flee_hp')::int;
        end if;
        won := not flee and random() < win_p; grit := false;
        IF NOT won AND NOT flee AND nal = 0 AND hp >= 70 AND random() < least(0.5, (hp - 50) / 100.0) THEN
          won := true; grit := true;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[버팀] ' || foe || '에게 밀렸지만 체력이 넉넉해 물러서지 않고 다시 맞섭니다.');
        END IF;
        if won then
          wins := wins + 1; xp := xp + 10 + danger * 2; cxp := cxp + 16; gil_gain := gil_gain + 2 + danger;
          dmg := round((8 + n.min_level * 1.1) * 0.9 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + case when nal > 0 then adef else defense end) * case when c.major_faction_id = 'north_league' then 0.8 else 1 end);
          IF grit THEN dmg := dmg * 2; END IF;
          if m.drops is not null and random() < 0.7 * loot_mul then
            select d.k into item from jsonb_each(m.drops) d(k, v) where exists (select 1 from public.world_item_catalog ic where ic.item_id = d.k) order by random() limit 1;
            if item is not null then loot := public.world_inv_add(loot, item, 1); end if;
          end if;
          gear_item := public.world_gear_roll(m.mechanic_key, n.min_level + 1, case when m.role = 'guardian' then 'guardian' else 'normal' end, (g_rare - 40)::numeric);
          if gear_item is not null then
            loot := public.world_inv_add(loot, gear_item, 1);
            lg := lg || jsonb_build_array(foe || '이(가) 지니고 있던 ' || (select item_name from public.world_item_catalog where item_id = gear_item) || '을(를) 챙겼습니다.');
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', foe || '이(가) 지니고 있던 장비를 챙겼습니다. (귀환 후 정리)');
          end if;
          if wins <= 3 then lg := lg || jsonb_build_array(foe || case when nal > 0 then '을(를) 동료와 함께 물리쳤습니다.' else '을(를) 물리쳤습니다.' end); end if;
          a_n := 1 + floor(random() * 3)::int; b_n := greatest(case when dmg > 0 then 1 else 0 end, a_n - 1);
        else
          losses := losses + 1;
          if c.job_key = 'artificer' and not flee then weak_bonus := 0.15; end if;
          dmg := round((8 + n.min_level * 1.1) * case when flee then 0.8 else 2.4 end * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + case when nal > 0 then adef else defense end) * case when c.major_faction_id = 'north_league' then 0.8 else 1 end);
          lg := lg || jsonb_build_array(case when flee then lowp || '의 상처가 깊어 ' || foe || '에게서 동료와 함께 물러났습니다.' when nal > 0 then foe || '에게 동료와 함께 밀려 물러났습니다.' else foe || '에게 밀려 물러났습니다.' end);
          a_n := 1 + floor(random() * 2)::int; b_n := a_n + 1;
        end if;
        -- 장비(호신부·회피)와 동료 수에 따른 피해. 동료가 있으면 요괴가 더 여러 번 공격하고, 이목에 따라 맞는 사람이 갈린다
        dmg := round(dmg * greatest(0.7, least(1.3, 1 - 0.03 * (c.level - n.min_level - 1))) * greatest(0.3, 1 + g_inc / 100.0) * (1 + (public.world_pexp_rules() ->> 'threat_pct')::numeric / 100 * nal) * (1 - coalesce((skf ->> 'guard')::float8, 0) / 100.0));
        my_taken := 0;
   if flee then
     seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'foe', 'who', me, 'owner', e.owner_id,
       'text', lowp || '의 상처가 깊습니다(체력 ' || minhp || '). 혼자 남기지 않고 모두 함께 물러납니다.');
     fx := jsonb_build_object('lines', '[]'::jsonb, 'seq', seq, 'taken', 0, 'mn', 0, 'er', 0, 'ids', jsonb_build_array(m.monster_id));
     -- 물러나는 동안 맞은 피해는 고르게 나눈다
     k := greatest(0, round(dmg / (1.0 + nal))::int);
     if k > 0 then
       my_taken := k;
       seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', me, 'owner', e.owner_id, 'text', '물러나다 ' || foe || '에게 등을 맞았습니다 · 체력 -' || k, 'value', k);
       for al in select x from jsonb_array_elements(act) x loop
         insert into public.world_expedition_hits(owner_id, amount) values ((al ->> 'owner')::uuid, k);
         seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', al ->> 'name', 'owner', (al ->> 'owner')::uuid, 'text', '물러나다 ' || foe || '에게 등을 맞았습니다 · 체력 -' || k, 'value', k);
       end loop;
     end if;
   else
   fx := public.world_exp_fight_story(e.owner_id, me, r.region_id, jsonb_build_object('n', foe, 'mech', m.mechanic_key, 'role', m.role, 'id', m.monster_id, 'kind', m.kind), nal, won, ehp, dmg, act, power, pres, base_t, seq, c.job_key, wtype, brank,
     jsonb_build_object('lv', c.level, 'mlv', n.min_level + 1, 'sp', c.skill_progress, 'st', jsonb_build_object('agility', c.agility, 'vitality', c.vitality, 'willpower', c.willpower, 'perception', c.perception)));
   jr := jr || (fx -> 'lines'); seq := (fx ->> 'seq')::int; my_taken := (fx ->> 'taken')::int;
   end if;
   mn := mn - coalesce((fx ->> 'mn')::int, 0); er := er + coalesce((fx ->> 'er')::int, 0);
   if won and nal > 0 then
     xp := xp + (5 + danger) * nal;
     for k in 1..nal loop
       if m.drops is not null and random() < 0.35 * loot_mul then
         select dd.k into item from jsonb_each(m.drops) dd(k, v) where exists (select 1 from public.world_item_catalog ic where ic.item_id = dd.k) order by random() limit 1;
         if item is not null then loot := public.world_inv_add(loot, item, 1); end if;
       end if;
     end loop;
   end if;
        seq := seq + 1;
        jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', case when won then 'win' else 'lose' end, 'who', me, 'owner', e.owner_id, 'mid', m.monster_id, 'rank', case when m.role = 'guardian' then 'guardian' else 'normal' end, 'rg', r.region_id,
          'text', case when won and nal > 0 then foe || '을(를) 동료와 함께 물리쳤습니다.' when won then foe || '을(를) 물리쳤습니다.'
            when flee then foe || '에게서 동료와 함께 물러났습니다.' when nal > 0 then foe || '에게 동료와 함께 밀려 물러났습니다.' else foe || '에게 밀려 물러났습니다.' end);
        -- 이 싸움의 줄을 한 칸으로 묶는 열쇠(fk). 함께 싸웠으면 동료가 받아 쓰도록 남긴다
        plines := (select coalesce(jsonb_agg(l || jsonb_build_object('fk', fk) order by o), '[]'::jsonb) from jsonb_array_elements(jr) with ordinality q(l, o) where o > j0);
        jr := (select coalesce(jsonb_agg(l order by o), '[]'::jsonb) from jsonb_array_elements(jr) with ordinality q(l, o) where o <= j0) || plines;
        if v_fkey is not null then
          insert into public.world_expedition_pfights(fkey, fight, data) values (v_fkey, true, jsonb_build_object('fk', fk, 'won', won, 'flee', flee, 'foe', foe, 'mid', m.monster_id,
            'n', 1 + nal, 'ids', coalesce(fx -> 'ids', jsonb_build_array(m.monster_id)), 'end_at', plines -> -1 ->> 'at',
            'lines', plines))
          on conflict (fkey) do nothing;
        end if;
        hp := hp - my_taken;
        mn := mn - round((case when spirit_mech then 3 else 1 end) * greatest(0, 1 + g_ml / 100.0))::int;
      end if;
    elsif roll < least(p_fight + 0.35, 1) * (1 - (0.03 + danger * 0.01) * case e.stance when 'bold' then 1.3 when 'cautious' then 0.7 else 1 end) then
      if cardinality(pool) > 0 then
        item := pool[1 + floor(random() * cardinality(pool))::int];
        qty := 1 + floor(random() * (1 + least(tt, 3)))::int + coalesce(c.gathering_rank, 1) / 20;
        qty := floor(qty * (1 + least(30, public.world_line_base(c.skill_progress, 'foraging', 'gather_qty_pct')) / 100.0) + random())::int;
        if tt = 0 then qty := case when random() < 0.5 then 1 else 0 end; end if;
        qty := round(qty * loot_mul * (case when short > 0 then 0.9 else 1 end) * (1 + case when c.major_faction_id = 'southern_remnant' then 0.15 else 0 end
                + c.perception * 0.005) * greatest(0.5, 1 + g_gq / 100.0));
        if qty > 0 then
          gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty);
          if random() < 0.2 and jsonb_array_length(coalesce(skf -> 'gather', '[]'::jsonb)) > 0 then
            skl := (skf -> 'gather') -> floor(random() * jsonb_array_length(skf -> 'gather'))::int;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[' || (skl ->> 'n') || '] ' || (skl ->> 't'));
          end if;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'gather', 'who', me, 'owner', e.owner_id, 'text', '채집터에서 재료를 거두었습니다. (수확은 귀환 후 정리)');
        else
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'walk', 'who', me, 'owner', e.owner_id, 'text', '채집할 만한 것을 찾았지만 도구가 마땅치 않아 지나칩니다.');
        end if;
      end if;
    elsif roll < least(p_fight + 0.35 + 0.22 + c.perception * 0.002, 1) * (1 - (0.03 + danger * 0.01) * case e.stance when 'bold' then 1.3 when 'cautious' then 0.7 else 1 end) then
      finds := finds + 1; xp := xp + 6; ixp := ixp + 10;
      if random() < 0.25 and jsonb_array_length(coalesce(skf -> 'find_l', '[]'::jsonb)) > 0 then
        skl := (skf -> 'find_l') -> floor(random() * jsonb_array_length(skf -> 'find_l'))::int;
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[' || (skl ->> 'n') || '] ' || (skl ->> 't'));
      end if;
      if random() < 0.55 * disc_mul then
        found_node := null; found_spot := null;
        select z.node_id into found_node from public.world_exploration_nodes z
          where z.region_id = r.region_id and z.hierarchy_level >= 2 and z.min_level <= c.level + 2
            and not exists (select 1 from public.world_exploration_discoveries d where d.owner_id = e.owner_id and d.node_id = z.node_id)
            and (z.hierarchy_level = 2 or exists (select 1 from public.world_exploration_discoveries d where d.owner_id = e.owner_id and d.node_id = z.parent_node_id))
          order by (z.parent_node_id = n.node_id) desc, random() limit 1;
        if found_node is not null and random() < 0.5 then
          insert into public.world_exploration_discoveries(owner_id, node_id) values (e.owner_id, found_node) on conflict do nothing;
          discovered := discovered + 1;
          if discovered <= 3 then lg := lg || jsonb_build_array('새로운 곳을 찾았습니다: ' || (select node_name from public.world_exploration_nodes where node_id = found_node)); end if;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id,
            'text', '새로운 곳을 찾았습니다: ' || (select node_name from public.world_exploration_nodes where node_id = found_node));
        else
          select s.spot_id into found_spot from public.world_gathering_spots s join public.world_exploration_discoveries d on d.node_id = s.node_id and d.owner_id = e.owner_id
            join public.world_exploration_nodes y on y.node_id = s.node_id
            where y.region_id = r.region_id and s.active and not exists (select 1 from public.world_gathering_discoveries g where g.owner_id = e.owner_id and g.spot_id = s.spot_id)
            order by (s.node_id = n.node_id) desc, random() limit 1;
          if found_spot is not null then
            insert into public.world_gathering_discoveries(owner_id, spot_id) values (e.owner_id, found_spot) on conflict do nothing;
            discovered := discovered + 1;
            if discovered <= 3 then lg := lg || jsonb_build_array('채집터를 찾았습니다: ' || (select spot_name from public.world_gathering_spots where spot_id = found_spot)); end if;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id,
              'text', '채집터를 찾았습니다: ' || (select spot_name from public.world_gathering_spots where spot_id = found_spot));
          else
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', '쓸 만한 단서와 흔적을 기록했습니다.');
          end if;
        end if;
      else
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', '쓸 만한 단서와 흔적을 기록했습니다.');
      end if;
      if cardinality(rare_pool) > 0 and random() < 0.04 + depth * 0.03 + greatest(0, g_rare) / 400.0 then
        item := rare_pool[1 + floor(random() * cardinality(rare_pool))::int];
        loot := public.world_inv_add(loot, item, 1);
        lg := lg || jsonb_build_array('숨겨진 곳에서 ' || (select item_name from public.world_item_catalog where item_id = item) || '을(를) 찾았습니다.');
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', '숨겨진 곳에서 귀한 것을 찾아 챙겼습니다. (귀환 후 정리)');
      end if;
    else
      if random() < 0.6 then
        hazards := hazards + 1;
        if c.job_key = 'sealmaster' and random() < 0.5 then
          jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[결계 야영] 스며드는 요기를 결계로 막아 냈습니다.');
        else
          k := round((danger + depth) / 2.0 * (case when c.job_key = 'sealmaster' then 0.5 else 1 end) * greatest(0.3, 1 - c.willpower / 100.0));
          part := round((2 + floor(random() * 4)) * greatest(0, 1 + g_ml / 100.0))::int;
          k := round(k * greatest(0, 1 + g_er / 100.0) * (1 - coalesce((skf ->> 'ward')::float8, 0) / 100.0))::int;
          er := er + k; mn := mn - part;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', me, 'owner', e.owner_id,
            'text', '스며드는 요기에 휩쓸렸습니다. 침식 +' || k || ' · 정신 -' || part);
        end if;
      end if;
    end if;

    -- 원정 전용 물품(20261028200000)
                                                                                                                                                                                                                                                                                  item := public.world_expedition_bonus_item(depth, e.stance, (e.minutes / 10.0) / total);
                                                                                                                                                                                                                                                                                      if item is not null then
                                                                                                                                                                                                                                                                                            loot := public.world_inv_add(loot, item, 1);
                                                                                                                                                                                                                                                                                                  seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', '원정길에서만 얻는 것을 챙겼습니다. (귀환 후 정리)');
                                                                                                                                                                                                                                                                                                      end if;
                                                                                                                                                                                                                                                                                                          if er >= 50 and coalesce((sup ->> 'ward_talisman_hq')::int, 0) > 0 then
      sup := jsonb_set(sup, '{ward_talisman_hq}', to_jsonb((sup ->> 'ward_talisman_hq')::int - 1)); er := er - 18; mn := mn + 6;
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '정화 부적 (우수)을 태웠습니다. 침식 -18 · 정신 +6');
    elsif er >= 50 and coalesce((sup ->> 'ward_talisman')::int, 0) > 0 then
      sup := jsonb_set(sup, '{ward_talisman}', to_jsonb((sup ->> 'ward_talisman')::int - 1)); er := er - 15; mn := mn + 5;
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '정화 부적을 태웠습니다. 침식 -15 · 정신 +5');
    end if;
    while hp < heal_at loop
      -- 7.7.7m 의무관 [야전 처치]: 보급품보다 먼저, 원정 한 번에 세 번까지(jobn은 의무관에게 이 기술만 센다)
      if c.job_key = 'medic' and jobn < 3 and hp > 0 then
        heal := greatest(1, round(25 * (1 + g_heal / 100.0))); hp := least(100, hp + heal); jobn := jobn + 1; job_once := true;
        lg := lg || jsonb_build_array('[야전 처치] 주변 약초로 상처를 동여맸습니다. 체력 +' || heal);
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '[야전 처치] 주변 약초로 상처를 동여맸습니다. 체력 +' || heal || ' (' || jobn || '/3)');
        continue;
      end if;
      item := case when coalesce((sup ->> 'tonic_hq')::int, 0) > 0 then 'tonic_hq' when coalesce((sup ->> 'tonic')::int, 0) > 0 then 'tonic'
                   when coalesce((sup ->> 'herbal_extract_hq')::int, 0) > 0 then 'herbal_extract_hq' when coalesce((sup ->> 'herbal_extract')::int, 0) > 0 then 'herbal_extract'
                   when coalesce((sup ->> 'herb')::int, 0) > 0 then 'herb' end;
      if item is null then
        if false then
          lg := lg || jsonb_build_array('[야전 처치] 보급품이 떨어지자 주변 약초로 상처를 동여맸습니다. 체력 +30');
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '[야전 처치] 주변 약초로 상처를 동여맸습니다. 체력 +30');
        end if;
        exit;
      end if;
      heal := ceil(coalesce((public.world_item_fx(public.world_item_base(item)) ->> 'hp')::numeric, 0) * case when item like '%\_hq' then 1.15 else 1 end)::int;
      if c.job_key = 'medic' then heal := round(heal * 1.15); end if;
      heal := greatest(1, round(heal * (1 + g_heal / 100.0)));
      sup := jsonb_set(sup, array[item], to_jsonb((sup ->> item)::int - 1)); hp := least(100, hp + heal);
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id,
        'text', (select item_name from public.world_item_catalog where item_id = item) || '을(를) 썼습니다. 체력 +' || heal);
    end loop;
    if hp <= 0 then
      if coalesce((sup ->> 'revival_charm_hq')::int, 0) > 0 then
        sup := jsonb_set(sup, '{revival_charm_hq}', to_jsonb((sup ->> 'revival_charm_hq')::int - 1)); hp := 35;
        lg := lg || jsonb_build_array('쓰러지기 직전 회생 부적 (우수)이 타올라 몸을 일으켰습니다.');
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '쓰러지기 직전 회생 부적 (우수)이 타올라 몸을 일으켰습니다. 체력 35');
      elsif coalesce((sup ->> 'revival_charm')::int, 0) > 0 then
        sup := jsonb_set(sup, '{revival_charm}', to_jsonb((sup ->> 'revival_charm')::int - 1)); hp := 30;
        lg := lg || jsonb_build_array('쓰러지기 직전 회생 부적이 타올라 몸을 일으켰습니다.');
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '쓰러지기 직전 회생 부적이 타올라 몸을 일으켰습니다. 체력 30');
      else
        hp := 0; ended := 'downed';
        lg := lg || jsonb_build_array('쓰러졌습니다. 챙긴 전리품 절반을 잃었습니다. 구조가 필요합니다.');
        select coalesce(jsonb_object_agg(lk, (lv::int / 2)) filter (where lv::int / 2 > 0), '{}'::jsonb) into loot from jsonb_each_text(loot) l(lk, lv);
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'down', 'who', me, 'owner', e.owner_id, 'text', '쓰러졌습니다. 더 나아갈 수 없습니다. 귀환해 구조를 받아야 합니다.');
        exit;
      end if;
    end if;
    if mn <= 0 then
      mn := 5; ended := case when ended = 'complete' then 'exhausted' else ended end;
      lg := lg || jsonb_build_array('정신이 바닥나 서둘러 돌아왔습니다.');
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'down', 'who', me, 'owner', e.owner_id, 'text', '정신이 바닥났습니다. 더 나아가지 못하고 돌아갈 채비를 합니다.');
      exit;
    end if;
  end loop;

  if er > 100 then perform public.world_yohwa_overflow(e.owner_id, er - 100); end if;
  er := greatest(0, least(100, er)); mn := greatest(0, least(100, mn)); hp := greatest(0, least(100, hp));
  ammo_used := CASE WHEN ammo_k IS NULL THEN 0 ELSE least(ammo_have, greatest(0, last_i - e.settled_rounds) * 2) END;
  update public.world_characters set inventory = CASE WHEN ammo_used > 0 THEN public.world_inv_add(inventory, ammo_k, -ammo_used) ELSE inventory END, health = hp, mental = mn, erosion = er,
    erosion_stage = case when er >= 80 then 4 when er >= 55 then 3 when er >= 30 then 2 when er >= 10 then 1 else 0 end, updated_at = now()
   where owner_id = e.owner_id;
  st := jsonb_build_object('sup', sup, 'loot', loot, 'log', lg, 'wins', wins, 'losses', losses, 'gathers', gathers, 'finds', finds, 'hazards', hazards,
    'discovered', discovered, 'xp', xp, 'cxp', cxp, 'gxp', gxp, 'ixp', ixp, 'gil', gil_gain, 'jobn', jobn, 'job_once', job_once, 'weak', weak_bonus, 'ended', ended, 'short', short);
  update public.world_expeditions set settled_rounds = last_i, state = st, journal = coalesce(journal, '[]'::jsonb) || jr where expedition_id = e.expedition_id;
  perform set_config('request.jwt.claims', coalesce(oc, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  return last_i;
end $function$;

CREATE OR REPLACE FUNCTION public.world_exp_fight_story(p_owner uuid, p_me text, p_region text, p_foe jsonb, p_extra integer, p_won boolean, p_ehp integer, p_dmg integer, p_allies jsonb, p_power double precision, p_pres double precision, p_base timestamp with time zone, p_seq integer, p_job text, p_wtype text, p_guard integer, p_ctx jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  foes jsonb := jsonb_build_array(p_foe); nf int; fhp int[]; a_n int; b_n int; t int; i int; seq int := p_seq; lines jsonb := '[]'::jsonb;
  dealt int; hits int[]; w float8[]; wsum float8; acc int; hi int := 0; ei int := 0; tgt int; carry int; nm text; mech text;
  who_n text; who_o uuid; pick float8; al jsonb; tot_w float8; nal int := coalesce(jsonb_array_length(p_allies), 0);
  etype text[]; parts int[]; left_d int; part int; taken int := 0; skill_at int; txt text; blk float8; told text[] := '{}'; kind_ text;
  vm text[]; va text[]; vh text[]; sk text;
  g public.world_monster_gimmicks%rowtype; mlv int := coalesce((p_ctx ->> 'mlv')::int, 1); gt int; gch float8; cn text[]; gx int; gml int := 0; ger int := 0;
  gbest text; gjob text;
begin
  if p_extra > 0 then
    foes := foes || coalesce((select jsonb_agg(jsonb_build_object('n', x.monster_name, 'mech', x.mechanic_key, 'role', x.role, 'id', x.monster_id, 'kind', x.kind))
      from (select monster_name, mechanic_key, role, monster_id, kind from public.world_region_monsters where region_id = p_region and role <> 'guardian' order by random() limit p_extra) x), '[]'::jsonb);
  end if;
  nf := jsonb_array_length(foes);
  -- 요괴 도감: 만난 요괴(이기면 쓰러뜨린 요괴)로 적는다
  perform public.world_codex_mark(p_owner, x ->> 'id', 1, case when p_won then 1 else 0 end) from jsonb_array_elements(foes) x where x ? 'id';
  gt := public.world_monster_tier(mlv);
  fhp := array_fill(p_ehp / nf, array[nf]); fhp[nf] := fhp[nf] + p_ehp - (p_ehp / nf) * nf;
  if nf > 1 then
    seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'fight', 'who', p_me, 'owner', p_owner,
      'text', (select string_agg(x ->> 'n', '·' order by o) from jsonb_array_elements(foes) with ordinality q(x, o) where o > 1) || '도 함께 덤벼듭니다. (요괴 ' || nf || ')');
  end if;

  -- 무기 갈래별 묘사
  vm := case p_wtype
    when 'ranged' then array['{f}에게 화살을 날렸습니다', '숨을 고르고 {f}의 눈을 노려 쏘았습니다', '거리를 벌리며 {f}에게 연달아 쏘았습니다', '{f}의 다리를 꿰뚫었습니다', '바람을 읽고 {f}의 등 뒤를 쏘았습니다']
    when 'magic' then array['영령 방울을 흔들어 {f}의 요기를 흩었습니다', '부적을 날려 {f}을(를) 태웠습니다', '주문을 외워 {f}을(를) 옭아맸습니다', '방울 소리로 {f}의 혼을 뒤흔들었습니다', '먹물로 쓴 술식이 {f}에게 달라붙었습니다']
    else array['{f}에게 칼날을 내리그었습니다', '{f}의 옆구리를 베어 냈습니다', '한 걸음 파고들어 {f}을(를) 찔렀습니다', '{f}의 공격을 흘리고 되받아쳤습니다', '자세를 낮춰 {f}의 다리를 쳐 냈습니다'] end;
  va := array['{f}에게 일격을 넣었습니다', '{f}의 빈틈을 파고들었습니다', '{f}을(를) 몰아붙였습니다', '{f}의 등을 노려 쳤습니다'];
  vh := array['{f}의 발톱에 긁혔습니다', '{f}이(가) 들이받았습니다', '{f}의 일격을 정면으로 맞았습니다', '{f}이(가) 물어뜯었습니다', '{f}이(가) 휘두른 팔에 밀려났습니다', '{f}의 요기에 살갗이 그을렸습니다'];
  sk := case p_job when 'exorcist' then '[파사검결] 부적을 두른 일격이 {f}의 요기를 갈랐습니다'
    when 'sealmaster' then '[봉인 결계] 결계를 펼쳐 {f}의 발을 묶었습니다'
    when 'medic' then '[응급 지혈] 싸우는 틈에 상처를 눌러 피를 멈췄습니다'
    when 'analyst' then '[급소 찌르기] {f}의 급소를 정확히 찔렀습니다'
    when 'scout' then '[연속 사격] 몸을 낮추고 {f}에게 연달아 쏘았습니다'
    when 'artificer' then '[호위 일격] 앞을 막아서며 {f}을(를) 베어 넘겼습니다' else null end;

  -- 내 쪽 공격 횟수와 각 공격의 피해(합 = 요괴에게 준 피해. 이기면 요괴 체력 전부)
  a_n := least(16, case when p_won then 4 + floor(random() * 4)::int else 3 + floor(random() * 3)::int end + 2 * (nf - 1) + nal);
  dealt := case when p_won then p_ehp else greatest(1, round(p_ehp * (0.45 + random() * 0.35))::int) end;
  w := array[]::float8[]; for i in 1..a_n loop w := w || (0.6 + random()); end loop;
  wsum := (select sum(x) from unnest(w) x); hits := array[]::int[]; acc := 0;
  for i in 1..a_n loop
    if i = a_n then hits := hits || greatest(1, dealt - acc); else hits := hits || greatest(1, round(dealt * w[i] / wsum)::int); acc := acc + hits[i]; end if;
  end loop;
  -- 요괴 쪽 행동: 이기면 내 마지막 공격보다 먼저 끝나고, 지면 한두 번 더 몰아친다. 회피한 공격은 피해가 없다.
  b_n := greatest(2, case when p_won then a_n - 1 else a_n + 1 end + (nf - 1));
  if p_won then b_n := least(b_n, a_n); end if;
  etype := array[]::text[];
  for i in 1..b_n loop etype := etype || case when random() < 0.14 then 'dodge' else 'hit' end; end loop;
  if p_dmg > 0 and not ('hit' = any (etype)) then etype[1] := 'hit'; end if;
  w := array[]::float8[]; for i in 1..b_n loop w := w || case when etype[i] = 'hit' then 0.6 + random() else 0 end; end loop;
  wsum := greatest(0.0001, (select sum(x) from unnest(w) x)); parts := array[]::int[]; acc := 0;
  for i in 1..b_n loop
    if etype[i] <> 'hit' then parts := parts || 0;
    elsif i = (select max(j) from generate_subscripts(etype, 1) j where etype[j] = 'hit') then parts := parts || greatest(0, p_dmg - acc);
    else parts := parts || round(p_dmg * w[i] / wsum)::int; acc := acc + parts[i]; end if;
  end loop;
  blk := least(0.35, 0.06 + coalesce(p_guard, 0) * 0.006);
  skill_at := case when sk is not null then 2 + floor(random() * greatest(1, a_n - 2))::int else 0 end;

  for t in 1..greatest(a_n, b_n) loop
    -- 요괴 기믹(Lv10부터): 두 번째 합에 한 번. 기술 단계·레벨 차·능력치로 대처하고, 상성 무기나 직업이면 더 잘 대처한다
    if t = 2 and gt >= 2 and p_foe ? 'kind' then
      select * into g from public.world_monster_gimmicks where kind_key = p_foe ->> 'kind' and tier between 2 and gt order by random() limit 1;
      if g.gimmick_key is not null and random() < (case gt when 2 then 0.55 else 0.75 end) then
        cn := public.world_gimmick_counter(g.gtype);
        gch := 35 + ((CASE WHEN cn[1] = 'sealing' THEN CASE WHEN public.world_job_line(p_job) IN ('sealing', 'exorcism', 'medicine') THEN coalesce((p_ctx -> 'sp' -> public.world_job_line(p_job) ->> 'rank')::int, 1) ELSE 1 END ELSE coalesce((p_ctx -> 'sp' -> cn[1] ->> 'rank')::int, 1) END) - case g.tier when 2 then 15 else 30 end) * 1.5
          + (coalesce((p_ctx ->> 'lv')::int, 1) - mlv) * 2 + coalesce((p_ctx -> 'st' ->> cn[2])::int, 0) * 0.3;
        gch := greatest(10, least(75, gch));
        select case when greatest(k.melee, k.ranged, k.magic) <= 1 then null when k.ranged >= greatest(k.melee, k.magic) then 'ranged' when k.magic >= k.melee then 'magic' else 'melee' end, k.job_key
          into gbest, gjob from public.world_monster_kinds k where k.kind_key = g.kind_key;
        if p_wtype = gbest or p_job = gjob then gch := gch + 25; end if;
        nm := p_foe ->> 'n';
        seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'foe', 'who', p_me, 'owner', p_owner, 'text', nm || ' · 「' || g.name || '」 ' || g.tell);
        if random() * 100 < gch then
          txt := case g.gtype when 'big' then '[막기] 「' || g.name || '」을(를) 받아 흘렸습니다'
            when 'charge' then '[끊기] 기를 모으는 틈을 파고들어 「' || g.name || '」을(를) 끊었습니다'
            when 'status' then '[버티기] 「' || g.name || '」을(를) 견뎌 냈습니다'
            when 'drain' then '[떨치기] 「' || g.name || '」을(를) 떨쳐 냈습니다' when 'grapple' then '[떨치기] 「' || g.name || '」을(를) 뿌리쳤습니다'
            when 'evade' then '[탐사] 「' || g.name || '」 속 진짜 몸을 찾아냈습니다' when 'thorns' then '[추적] 가시가 없는 틈을 골라 쳤습니다'
            else '[간파] 「' || g.name || '」의 흐름을 읽어 냈습니다' end;
          seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'guard', 'who', p_me, 'owner', p_owner, 'text', txt, 'value', 0);
        else
          gx := greatest(1, round((2 + mlv * 0.25) * greatest(1, g.power))::int);
          taken := taken + gx; gml := gml + g.mental; ger := ger + g.erosion;
          if nal > 0 and g.gtype in ('charge', 'status') then
            insert into public.world_expedition_hits(owner_id, amount) select (x ->> 'owner')::uuid, gx from jsonb_array_elements(p_allies) x;
          end if;
          txt := case g.gtype when 'big' then '「' || g.name || '」에 정통으로 맞았습니다' when 'charge' then '「' || g.name || '」이(가) 터졌습니다'
            when 'status' then '「' || g.name || '」에 휩쓸렸습니다' when 'drain' then '「' || g.name || '」에 기운을 빼앗겼습니다'
            when 'grapple' then '「' || g.name || '」에 붙잡혔습니다' when 'evade' then '「' || g.name || '」에 속아 헛손질했습니다'
            when 'thorns' then '가시에 손을 베였습니다' else '「' || g.name || '」 때문에 공격이 무뎌졌습니다' end
            || case when nal > 0 and g.gtype in ('charge', 'status') then ' · 모두' else '' end || ' · 체력 -' || gx || case when g.mental > 0 then ' · 정신 -' || g.mental else '' end || case when g.erosion > 0 then ' · 침식 +' || g.erosion else '' end;
          seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', p_me, 'owner', p_owner, 'text', txt, 'value', gx);
        end if;
      end if;
    end if;
    -- 요괴의 차례
    if t <= b_n then
      ei := ei + 1;
      tgt := (select min(j) from generate_subscripts(fhp, 1) j where fhp[j] > 0);
      if tgt is null then tgt := nf; end if;
      -- 살아 있는 요괴 가운데 하나
      tgt := coalesce((select j from generate_subscripts(fhp, 1) j where fhp[j] > 0 order by random() limit 1), tgt);
      nm := foes -> (tgt - 1) ->> 'n'; mech := coalesce(foes -> (tgt - 1) ->> 'mech', '');
      if not (nm = any (told)) and random() < 0.55 then
        told := told || nm;
        txt := case mech
          when 'toxic' then '{f}이(가) 짙은 독기를 내뿜습니다' when 'spectral' then '{f}의 모습이 흐려졌다가 등 뒤에서 나타납니다'
          when 'ambush' then '{f}이(가) 그림자 속으로 몸을 숨깁니다' when 'tide' then '검은 물결이 일어 발목을 휘감습니다'
          when 'armored' then '{f}의 단단한 껍질에 공격이 미끄러집니다' when 'aerial' then '{f}이(가) 머리 위로 날아올라 덮쳐 옵니다'
          when 'swarm' then '{f}이(가) 사방에서 몰려듭니다' when 'seal_breaker' then '{f}이(가) 봉인의 틈을 비집고 요기를 터뜨립니다'
          when 'reflect' then '{f}이(가) 거울처럼 공격을 되비춥니다' when 'warded' then '{f} 주위의 금줄이 공격을 튕겨 냅니다'
          when 'boss' then '{f}의 포효에 땅이 울립니다' else '{f}이(가) 낮게 으르렁거리며 틈을 엿봅니다' end;
        seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'foe', 'who', p_me, 'owner', p_owner, 'text', replace(txt, '{f}', nm));
      end if;
      -- 이목(어그로)을 따라 맞는 사람을 고른다: 무게 = 이목^1.3
      who_n := p_me; who_o := p_owner;
      if nal > 0 then
        tot_w := public.world_cb_aggro(p_pres::numeric)::float8 + coalesce((select sum(public.world_cb_aggro((x ->> 'pres')::numeric)::float8) from jsonb_array_elements(p_allies) x), 0);
        pick := random() * tot_w - public.world_cb_aggro(p_pres::numeric)::float8;
        if pick >= 0 then
          for al in select x from jsonb_array_elements(p_allies) x loop
            who_n := al ->> 'name'; who_o := (al ->> 'owner')::uuid;
            exit when pick < public.world_cb_aggro((al ->> 'pres')::numeric)::float8;
            pick := pick - public.world_cb_aggro((al ->> 'pres')::numeric)::float8;
          end loop;
        end if;
      end if;
      part := parts[ei];
      if etype[ei] = 'dodge' or part <= 0 then
        kind_ := 'guard'; txt := (array['{f}의 공격을 몸을 틀어 피했습니다', '{f}의 일격이 허공을 갈랐습니다', '한 발 물러서 {f}의 공격을 흘려보냈습니다'])[1 + floor(random() * 3)::int];
        part := 0;
      elsif random() < blk and who_o = p_owner then
        part := greatest(1, round(part * 0.5)::int);
        kind_ := 'guard'; txt := '[막기] {f}의 공격을 받아 냈습니다 · 체력 -' || part;
      else
        kind_ := 'hurt'; txt := vh[1 + floor(random() * cardinality(vh))::int] || ' · 체력 -' || part;
      end if;
      if part > 0 then
        if who_o = p_owner then taken := taken + part; else insert into public.world_expedition_hits(owner_id, amount) values (who_o, part); end if;
      end if;
      seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', kind_, 'who', who_n, 'owner', who_o, 'text', replace(txt, '{f}', nm), 'value', part);
    end if;
    -- 내 쪽의 차례(동료는 전투력에 비례해 나선다)
    if t <= a_n then
      hi := hi + 1;
      tgt := coalesce((select min(j) from generate_subscripts(fhp, 1) j where fhp[j] > 0), nf);
      nm := foes -> (tgt - 1) ->> 'n';
      who_n := p_me; who_o := p_owner;
      if nal > 0 then
        pick := random() * (p_power + coalesce((select sum((x ->> 'power')::float8) from jsonb_array_elements(p_allies) x), 0));
        if pick >= p_power then
          pick := pick - p_power;
          for al in select x from jsonb_array_elements(p_allies) x loop
            who_n := al ->> 'name'; who_o := (al ->> 'owner')::uuid;
            exit when pick < (al ->> 'power')::float8;
            pick := pick - (al ->> 'power')::float8;
          end loop;
        end if;
      end if;
      if hi = skill_at then
        who_n := p_me; who_o := p_owner;
        seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'skill', 'who', p_me, 'owner', p_owner, 'text', replace(sk, '{f}', nm));
      end if;
      txt := case when who_o = p_owner then vm[1 + floor(random() * cardinality(vm))::int] else va[1 + floor(random() * cardinality(va))::int] end;
      if random() < 0.12 then txt := '급소를 찔렀습니다! ' || txt || ' · 치명타 ' || hits[hi] || ' 피해';
      else txt := txt || ' · ' || hits[hi] || ' 피해'; end if;
      seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'atk', 'who', who_n, 'owner', who_o, 'text', replace(txt, '{f}', nm), 'value', hits[hi]);
      -- 피해를 앞 요괴부터 깎고, 넘친 만큼은 다음 요괴로 이어진다
      carry := hits[hi];
      while carry > 0 loop
        tgt := (select min(j) from generate_subscripts(fhp, 1) j where fhp[j] > 0);
        exit when tgt is null;
        if carry >= fhp[tgt] then
          carry := carry - fhp[tgt]; fhp[tgt] := 0;
          if tgt < nf or not p_won then
            seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'fight', 'who', p_me, 'owner', p_owner, 'text', (foes -> (tgt - 1) ->> 'n') || '이(가) 쓰러졌습니다.');
          end if;
        else fhp[tgt] := fhp[tgt] - carry; carry := 0; end if;
      end loop;
    end if;
  end loop;
  if not p_won then
    seq := seq + 1; lines := lines || jsonb_build_object('at', p_base + make_interval(secs => seq * 2), 'kind', 'foe', 'who', p_me, 'owner', p_owner,
      'text', (array['요괴의 기세가 꺾이지 않습니다. 더 버티기 어렵습니다', '숨이 가빠져 더는 맞서기 어렵습니다', '상처가 깊어 거리를 벌립니다'])[1 + floor(random() * 3)::int]);
  end if;
  return jsonb_build_object('lines', lines, 'seq', seq, 'taken', taken, 'mn', gml, 'er', ger, 'ids', (select jsonb_agg(x -> 'id') from jsonb_array_elements(foes) x));
end $function$;

CREATE OR REPLACE FUNCTION public.world_expedition_progress()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); e public.world_expeditions%rowtype; c public.world_characters%rowtype; x record;
  total int; done int; lines jsonb; party jsonb := '[]'::jsonb; pid uuid; span_s float8; beat_s float8; beats int; next_beat timestamptz; next_round timestamptz;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into e from public.world_expeditions where owner_id = uid and status = 'active';
  if not found then return jsonb_build_object('active', false); end if;
  perform public.world_expedition_settle(e.expedition_id);
  select * into e from public.world_expeditions where expedition_id = e.expedition_id;
  select * into c from public.world_characters where owner_id = uid;
  lines := public.world_expedition_walk_lines(e.expedition_id);
  select party_id into pid from public.world_party_members where owner_id = uid;
  if pid is not null then
    for x in select pe.expedition_id, pe.minutes, pe.started_at, pe.ends_at, pe.region_id, pe.settled_rounds, pc.character_name, pn.node_name, pr.region_name,
               -- 1.0.1 일지를 섞는 것도 파티 원정으로 함께 떠난 동료만(같은 제안·같은 순간 출발)
               public.world_pexp_together(e.expedition_id, pe.expedition_id) as together
             from public.world_party_members pm join public.world_expeditions pe on pe.owner_id = pm.owner_id and pe.status = 'active'
             join public.world_characters pc on pc.owner_id = pm.owner_id left join public.world_exploration_nodes pn on pn.node_id = pe.node_id
             left join public.world_map_regions pr on pr.region_id = pe.region_id
             where pm.party_id = pid and pm.owner_id <> uid order by pc.character_name loop
      perform public.world_expedition_settle(x.expedition_id);
      if x.together then lines := lines || public.world_expedition_walk_lines(x.expedition_id); end if;
      party := party || jsonb_build_array(jsonb_build_object('name', x.character_name, 'place', x.node_name, 'region', x.region_name, 'same_region', x.region_id = e.region_id,
        'rounds_done', greatest(0, least(case x.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end,
          floor((case x.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end) * extract(epoch from least(now(), x.ends_at) - x.started_at) / (x.minutes * 60.0))::int)),
        'total_rounds', case x.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end, 'ends_at', x.ends_at));
    end loop;
  end if;
  -- 1.0.1 공동 싸움 줄은 파티원 일지마다 같은 것이 들어 있으므로 한 번만, 퀘스트 셈용 줄(hide)은 빼고
  lines := (select coalesce(jsonb_agg(l order by (l ->> 'at')::timestamptz, n), '[]'::jsonb)
            from (select distinct on (l) l, n from jsonb_array_elements(lines) with ordinality as a(l, n)
                  where (l ->> 'at')::timestamptz <= now() and not coalesce((l ->> 'hide')::boolean, false) order by l, n) q);
  total := case e.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end;
  span_s := extract(epoch from e.ends_at - e.started_at);
  done := greatest(0, least(total, floor(total * extract(epoch from least(now(), e.ends_at) - e.started_at) / span_s)::int));
  beat_s := greatest(75, span_s / 48.0);
  beats := floor(extract(epoch from least(now(), e.ends_at) - e.started_at) / beat_s)::int;
  next_round := case when done < total then e.started_at + (e.ends_at - e.started_at) * (done + 1) / total end;
  next_beat := e.started_at + make_interval(secs => (beats + 1) * beat_s);
  if next_beat >= e.ends_at then next_beat := null; end if;
  return jsonb_build_object('active', true, 'me', c.character_name, 'stance', e.stance, 'rounds_done', done, 'total_rounds', total,
    'started_at', e.started_at, 'ends_at', e.ends_at, 'stopped', e.state ->> 'ended' in ('downed', 'exhausted'),
    'health', c.health, 'mental', c.mental, 'erosion', c.erosion,
    'next_at', case when next_round is null then next_beat when next_beat is null then next_round else least(next_round, next_beat) end,
    'next_round_at', next_round, 'lines', lines, 'party', party,
    'job_skill', case c.job_key when 'exorcist' then '파사 부적' when 'scout' then '선제 사격' when 'medic' then '야전 처치'
      when 'sealmaster' then '결계 야영' when 'analyst' then '급소 찌르기' when 'artificer' then '반격 태세' end);
end $function$;

-- 1.0.1 「동료와 함께 다녀온 원정」 경험치·숙련 +10%/명도 파티 원정으로 함께 떠난 동료만(사용자 결정; 전에는 같은 지역에 10분 이상 겹치면 누구나)
do $c$ declare d text; a text; begin
  d := replace(pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure), E'\r\n', E'\n');
  a := $a$join public.world_expeditions px on px.owner_id = om.owner_id and px.region_id = e.region_id and px.status in ('active', 'done')$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.1 world_expedition_complete 기준 문구가 없습니다'; end if;
  d := replace(d, a, a || $b$ and public.world_pexp_together(e.expedition_id, px.expedition_id)$b$);
  -- 수치도 규칙 함수에서(10분 겹침·세 명까지·한 명마다 10%)
  foreach a in array array[$a$e.started_at + interval '10 minutes'$a$, $a$pa := least(coalesce(pa, 0), 3);$a$, $a$|| (10 * pa) ||$a$] loop
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.1 world_expedition_complete 수치 문구가 없습니다: %', a; end if;
  end loop;
  if (length(d) - length(replace(d, '(1 + 0.1 * pa)', ''))) / length('(1 + 0.1 * pa)') <> 4 then raise exception '1.0.1 world_expedition_complete 덤 배율 문구가 4개가 아닙니다'; end if;
  d := replace(d, $a$e.started_at + interval '10 minutes'$a$, $a$e.started_at + make_interval(mins => (public.world_pexp_rules() ->> 'overlap_min')::int)$a$);
  d := replace(d, $a$pa := least(coalesce(pa, 0), 3);$a$, $a$pa := least(coalesce(pa, 0), (public.world_pexp_rules() ->> 'bonus_cap')::int);$a$);
  d := replace(d, '(1 + 0.1 * pa)', $a$(1 + (public.world_pexp_rules() ->> 'bonus_pct')::numeric / 100 * pa)$a$);
  d := replace(d, $a$|| (10 * pa) ||$a$, $a$|| ((public.world_pexp_rules() ->> 'bonus_pct')::int * pa) ||$a$);
  execute d;
end $c$;

update public.world_app_meta set value = '20261105070000' where key = 'db_version';
