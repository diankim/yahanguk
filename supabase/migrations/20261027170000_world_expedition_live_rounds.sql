-- 원정 회차별 실시간 정산 + 원정 일지(이름·전투 기록·파티원 일지)
-- - 수색 회차 시각이 지나면 서버가 그 회차(전투·채집·발견·위험)를 바로 정산해 원정 일지(world_expeditions.journal)에 적고,
--   체력·정신·침식을 곧바로 캐릭터에 반영한다(원정이 끝나지 않아도 프로필·상태판에서 보인다).
-- - 전투는 공격·반격·회복·기술·승패를 한 줄씩 남긴다. 전리품의 이름과 수량은 여전히 귀환할 때 정리해 보여 준다.
-- - 귀환(world_expedition_complete)은 남은 회차만 정산한 뒤 전리품·경험치·답사를 정리한다(일찍 귀환하면 지난 회차까지만).
-- - 일지의 모든 줄에 누가 했는지(who)를 붙이고, 같은 파티원의 원정 일지도 함께 보여 준다.
-- - 진행 중인 원정(이 변경 전 출발)도 이어서 정산된다.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

alter table public.world_expeditions add column if not exists settled_rounds int not null default 0;
alter table public.world_expeditions add column if not exists state jsonb;
alter table public.world_expeditions add column if not exists journal jsonb not null default '[]'::jsonb;

/* ── 1) 회차 정산 ─────────────────────────────────────────── */
create or replace function public.world_expedition_settle(p_exp uuid, p_upto int default null)
returns int language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare
  e public.world_expeditions%rowtype; c public.world_characters%rowtype; n public.world_exploration_nodes%rowtype;
  r public.world_map_regions%rowtype; m public.world_region_monsters%rowtype;
  total int; target int; i int; last_i int; t timestamptz; span interval; roll float8; win_p float8; depth int; danger int;
  st jsonb; sup jsonb; loot jsonb; lg jsonb; jr jsonb := '[]'::jsonb; seq int := 0;
  hp int; mn int; er int; wins int; losses int; gathers int; finds int; hazards int; discovered int;
  xp int; cxp int; gxp int; ixp int; gil_gain int; jobn int; job_once boolean; weak_bonus float8; ended text; short int;
  wt int := 0; at_ int := 0; tt int := 0; power float8; defense float8; threat float8; dmg int; heal int;
  p_fight float8; dmg_mul float8; loot_mul float8; disc_mul float8; heal_at int;
  item text; qty int; pool text[]; rare_pool text[]; spirit_mech boolean; found_node uuid; found_spot uuid;
  me text; foe text; a_n int; b_n int; k int; ehp int; my_hit int; left_d int; part int; h0 int; h1 int;
  base_t timestamptz; won boolean;
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
  power := 12 + c.level * 5 + c.strength * 2.5 + c.agility * 1.5 + c.perception + wt * 14 + coalesce(c.combat_rank, 1) * 3;
  if c.job_key = 'exorcist' then power := power * 1.12; end if;
  defense := c.level * 2 + c.vitality * 3 + at_ * 12;
  if c.major_faction_id = 'north_league' then defense := defense * 1.2; end if;
  p_fight := case e.stance when 'cautious' then 0.22 when 'bold' then 0.5 else 0.35 end + danger * 0.012;
  dmg_mul := case e.stance when 'cautious' then 0.7 when 'bold' then 1.3 else 1.0 end;
  loot_mul := case e.stance when 'cautious' then 0.8 when 'bold' then 1.3 else 1.0 end * (1 + (depth - 1) * 0.15);
  if c.major_faction_id = 'red_moon_cult' and e.stance = 'bold' then loot_mul := loot_mul * 1.15; end if;
  disc_mul := case e.stance when 'cautious' then 0.85 when 'bold' then 1.2 else 1.0 end;
  if c.job_key = 'scout' then disc_mul := disc_mul * 1.2; end if;
  if c.major_faction_id = 'mandate_court' then disc_mul := disc_mul * 1.2; end if;
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
    if c.job_key = 'scout' and roll < p_fight and random() < 0.3 then
      roll := p_fight + 0.36; jobn := jobn + 1;
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[흔적 추적] 요괴의 흔적을 먼저 읽고 길을 돌아 피했습니다.');
    end if;

    if roll < p_fight then
      select * into m from public.world_region_monsters where region_id = r.region_id and (role <> 'guardian' or depth >= 3)
        order by -ln(greatest(random(), 1e-9)) / case role when 'common' then 6 when 'guardian' then 0.6 else 4 end limit 1;
      if m.monster_id is not null then
        foe := m.monster_name;
        threat := ((70 + (n.min_level + 1) * 14) / 8.0 + (8 + (n.min_level + 1) * 1.1) * 2) * case when m.role = 'guardian' then 2.4 else 1 end * (1 + (depth - 1) * 0.25);
        spirit_mech := coalesce(m.mechanic_key, '') in ('spectral', 'warded', 'seal_breaker');
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'fight', 'who', me, 'owner', e.owner_id,
          'text', foe || case when m.role = 'guardian' then '(우두머리)' else '' end || '와(과) 마주쳤습니다.');
        win_p := power / (power + threat);
        if spirit_mech then
          win_p := win_p + c.spirit_affinity * 0.004;
          if coalesce((sup ->> 'seal_paper')::int, 0) > 0 then
            sup := jsonb_set(sup, '{seal_paper}', to_jsonb((sup ->> 'seal_paper')::int - 1));
            win_p := win_p + case when c.job_key in ('sealmaster', 'exorcist') then 0.25 else 0.15 end;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '황지에 봉인 술식을 적어 요기를 누릅니다.');
          end if;
        end if;
        if weak_bonus > 0 then
          win_p := win_p + weak_bonus; weak_bonus := 0; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[약점 간파] 앞서 밀렸던 싸움에서 읽어 낸 약점을 노립니다.');
        end if;
        win_p := greatest(0.08, least(0.95, win_p));
        if c.job_key = 'exorcist' and spirit_mech and not job_once then
          win_p := 1; job_once := true; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[파사 부적] ' || foe || '의 요기를 부적으로 단번에 꿰뚫었습니다.');
        end if;
        ehp := greatest(8, round(threat * 1.6)::int);
        won := random() < win_p;
        if won then
          wins := wins + 1; xp := xp + 10 + danger * 2; cxp := cxp + 16; gil_gain := gil_gain + 2 + danger;
          dmg := round((8 + n.min_level * 1.1) * 0.9 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + defense));
          if m.drops is not null and random() < 0.7 * loot_mul then
            select d.k into item from jsonb_each(m.drops) d(k, v) where exists (select 1 from public.world_item_catalog ic where ic.item_id = d.k) order by random() limit 1;
            if item is not null then loot := public.world_inv_add(loot, item, 1); end if;
          end if;
          if wins <= 3 then lg := lg || jsonb_build_array(foe || '을(를) 물리쳤습니다.'); end if;
          a_n := 1 + floor(random() * 3)::int; b_n := greatest(case when dmg > 0 then 1 else 0 end, a_n - 1);
        else
          losses := losses + 1;
          if c.job_key = 'analyst' then weak_bonus := 0.15; end if;
          dmg := round((8 + n.min_level * 1.1) * 2.4 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + defense));
          lg := lg || jsonb_build_array(foe || '에게 밀려 물러났습니다. 체력 -' || dmg);
          a_n := 1 + floor(random() * 2)::int; b_n := a_n + 1;
        end if;
        -- 주고받은 공격을 한 줄씩 적는다(내 공격의 합 = 요괴에게 준 피해, 요괴 공격의 합 = 받은 피해)
        left_d := dmg;
        for k in 1..greatest(a_n, b_n) loop
          if k <= a_n then
            -- 이긴 싸움은 마지막 공격으로 쓰러뜨리고, 진 싸움은 끝내 쓰러뜨리지 못한다
            my_hit := case when won and k = a_n then ehp else greatest(1, least(ehp - 1, round(ehp * (0.25 + random() * 0.3))::int)) end;
            if my_hit <= 0 then my_hit := 1; end if;
            ehp := ehp - my_hit;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'atk', 'who', me, 'owner', e.owner_id,
              'text', foe || '에게 ' || my_hit || ' 피해', 'value', my_hit);
          end if;
          if k <= b_n and left_d > 0 then
            part := case when k = b_n then left_d else greatest(1, round(left_d * (0.3 + random() * 0.3))::int) end;
            left_d := left_d - part;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', me, 'owner', e.owner_id,
              'text', foe || '의 공격 · 체력 -' || part, 'value', part);
          end if;
        end loop;
        seq := seq + 1;
        jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', case when won then 'win' else 'lose' end, 'who', me, 'owner', e.owner_id,
          'text', case when won then foe || '을(를) 물리쳤습니다.' else foe || '에게 밀려 물러났습니다.' end);
        hp := hp - dmg;
        if spirit_mech then mn := mn - 3; else mn := mn - 1; end if;
      end if;
    elsif roll < p_fight + 0.35 then
      if cardinality(pool) > 0 then
        item := pool[1 + floor(random() * cardinality(pool))::int];
        qty := 1 + floor(random() * (1 + least(tt, 3)))::int + coalesce(c.gathering_rank, 1) / 10;
        if tt = 0 then qty := case when random() < 0.5 then 1 else 0 end; end if;
        qty := round(qty * loot_mul * (case when short > 0 then 0.9 else 1 end) * (1 + case when c.major_faction_id = 'southern_remnant' then 0.15 else 0 end
                + case when c.job_key in ('artificer', 'scout') then 0.15 else 0 end + c.perception * 0.005));
        if qty > 0 then
          gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty);
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'gather', 'who', me, 'owner', e.owner_id, 'text', '채집터에서 재료를 거두었습니다. (수확은 귀환 후 정리)');
        else
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'walk', 'who', me, 'owner', e.owner_id, 'text', '채집할 만한 것을 찾았지만 도구가 마땅치 않아 지나칩니다.');
        end if;
        if c.job_key = 'artificer' and qty > 0 and random() < 0.25 then
          loot := public.world_inv_add(loot, item, 1); jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[현장 가공] 캔 재료를 손질해 쓸 만한 것을 하나 더 건졌습니다.');
        end if;
      end if;
    elsif roll < p_fight + 0.35 + 0.22 + c.perception * 0.002 then
      finds := finds + 1; xp := xp + 6; ixp := ixp + 10;
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
      if cardinality(rare_pool) > 0 and random() < 0.04 + depth * 0.03 + (case when c.job_key = 'analyst' then 0.05 else 0 end) then
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
          part := (2 + floor(random() * 4))::int;
          er := er + k; mn := mn - part;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', me, 'owner', e.owner_id,
            'text', '스며드는 요기에 휩쓸렸습니다. 침식 +' || k || ' · 정신 -' || part);
        end if;
      end if;
    end if;

    if er >= 50 and coalesce((sup ->> 'ward_talisman')::int, 0) > 0 then
      sup := jsonb_set(sup, '{ward_talisman}', to_jsonb((sup ->> 'ward_talisman')::int - 1)); er := er - 15; mn := mn + 5;
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '정화 부적을 태웠습니다. 침식 -15 · 정신 +5');
    end if;
    while hp < heal_at loop
      item := case when coalesce((sup ->> 'tonic')::int, 0) > 0 then 'tonic' when coalesce((sup ->> 'herbal_extract')::int, 0) > 0 then 'herbal_extract'
                   when coalesce((sup ->> 'herb')::int, 0) > 0 then 'herb' end;
      if item is null then
        if c.job_key = 'medic' and not job_once then
          hp := least(100, hp + 30); job_once := true; jobn := jobn + 1;
          lg := lg || jsonb_build_array('[야전 처치] 보급품이 떨어지자 주변 약초로 상처를 동여맸습니다. 체력 +30');
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '[야전 처치] 주변 약초로 상처를 동여맸습니다. 체력 +30');
        end if;
        exit;
      end if;
      heal := case item when 'tonic' then 35 when 'herbal_extract' then 22 else 12 end;
      if c.job_key = 'medic' then heal := round(heal * 1.5); end if;
      sup := jsonb_set(sup, array[item], to_jsonb((sup ->> item)::int - 1)); hp := least(100, hp + heal);
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id,
        'text', (select item_name from public.world_item_catalog where item_id = item) || '을(를) 썼습니다. 체력 +' || heal);
    end loop;
    if hp <= 0 then
      if coalesce((sup ->> 'revival_charm')::int, 0) > 0 then
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

  er := greatest(0, least(100, er)); mn := greatest(0, least(100, mn)); hp := greatest(0, least(100, hp));
  update public.world_characters set health = hp, mental = mn, erosion = er,
    erosion_stage = case when er >= 80 then 4 when er >= 55 then 3 when er >= 30 then 2 when er >= 10 then 1 else 0 end, updated_at = now()
   where owner_id = e.owner_id;
  st := jsonb_build_object('sup', sup, 'loot', loot, 'log', lg, 'wins', wins, 'losses', losses, 'gathers', gathers, 'finds', finds, 'hazards', hazards,
    'discovered', discovered, 'xp', xp, 'cxp', cxp, 'gxp', gxp, 'ixp', ixp, 'gil', gil_gain, 'jobn', jobn, 'job_once', job_once, 'weak', weak_bonus, 'ended', ended, 'short', short);
  update public.world_expeditions set settled_rounds = last_i, state = st, journal = coalesce(journal, '[]'::jsonb) || jr where expedition_id = e.expedition_id;
  return last_i;
end $$;

/* ── 2) 걸음·회차·날씨 줄(이름 포함) ─────────────────────── */
create or replace function public.world_expedition_walk_lines(p_exp uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare e public.world_expeditions%rowtype; r public.world_map_regions%rowtype; c public.world_characters%rowtype;
  total int; done int; i int; t timestamptz; ph text; wk text; pph text; pwk text; lines jsonb := '[]'::jsonb; nm text; mons text[]; h0 int; h1 int;
  rations int; eaten int := 0; pool text[]; line text; me text; stop_round int;
  span_s float8; beat_s float8; beats int; b int; bt timestamptz; grp text; cat int; h bigint; prev text := ''; mon text; stop_at timestamptz;
  p_gen text[]; p_reg text[]; p_stance text[]; p_job text[]; p_env text[];
begin
  select * into e from public.world_expeditions where expedition_id = p_exp;
  if not found then return '[]'::jsonb; end if;
  select * into c from public.world_characters where owner_id = e.owner_id;
  select * into r from public.world_map_regions where region_id = e.region_id;
  select node_name into nm from public.world_exploration_nodes where node_id = e.node_id;
  me := c.character_name;
  total := case e.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end;
  span_s := extract(epoch from e.ends_at - e.started_at);
  done := greatest(0, least(total, floor(total * extract(epoch from least(now(), e.ends_at) - e.started_at) / span_s)::int));
  -- 쓰러지거나 정신이 바닥나 멈춘 원정은 그 회차 뒤로 걸음 기록을 잇지 않는다
  if e.state ->> 'ended' in ('downed', 'exhausted') then
    stop_round := e.settled_rounds; done := least(done, stop_round);
    stop_at := e.started_at + (e.ends_at - e.started_at) * stop_round / total;
  end if;
  mons := array(select monster_name from public.world_region_monsters where region_id = e.region_id order by monster_name);
  rations := coalesce((e.supplies ->> 'travel_ration')::int, 0);
  lines := lines || jsonb_build_object('at', e.started_at, 'kind', 'start', 'who', me, 'owner', e.owner_id, 'text', coalesce(nm, '원정지') || '(으)로 들어섰습니다. 태세: '
    || case e.stance when 'cautious' then '신중' when 'bold' then '강행' else '균형' end || ' · 예정 수색 ' || total || '회');
  pph := public.world_time_phase(e.started_at); pwk := public.world_weather_key(r.territory_id, e.started_at);
  pool := array['%s번째 수색을 마치고 다음 갈래로 나아갑니다.', '%s번째 수색을 마쳤습니다. 지나온 길을 지도에 옮겨 적습니다.', '%s번째 구역을 훑고 표식을 남겨 둡니다.',
    '%s번째 수색. 짐을 고쳐 메고 더 안쪽으로 향합니다.'];
  for i in 1..done loop
    t := e.started_at + (e.ends_at - e.started_at) * i / total;
    ph := public.world_time_phase(t); wk := public.world_weather_key(r.territory_id, t);
    if ph is distinct from pph then
      lines := lines || jsonb_build_object('at', t, 'kind', 'env', 'who', me, 'owner', e.owner_id, 'text', '시간이 흘러 ' || case ph when 'dawn' then '해돋이' when 'noon' then '한낮' when 'dusk' then '땅거미' else '삼경' end || '이 되었습니다.');
    end if;
    if wk is distinct from pwk then
      lines := lines || jsonb_build_object('at', t, 'kind', 'env', 'who', me, 'owner', e.owner_id, 'text', '날씨가 ' || case wk when 'clear' then '청명' when 'cloudy' then '담운' when 'rain' then '장우'
        when 'fog' then '농무' when 'wind' then '삭풍' when 'snow' then '설한' when 'bloodmist' then '혈무' else wk end || '(으)로 바뀌었습니다.');
    end if;
    pph := ph; pwk := wk;
    h0 := floor(e.minutes * (i - 1) / total / 60.0)::int; h1 := floor(e.minutes * i / total / 60.0)::int;
    if h1 > h0 and eaten < rations then
      eaten := eaten + 1; lines := lines || jsonb_build_object('at', t - interval '55 seconds', 'kind', 'supply', 'who', me, 'owner', e.owner_id, 'text', '노정 건량을 하나 꺼내 먹었습니다. (남은 건량 ' || (rations - eaten) || ')');
    end if;
    line := replace(pool[1 + abs(hashtext(e.expedition_id::text || ':' || i)::bigint) % cardinality(pool)], '%s', i::text);
    lines := lines || jsonb_build_object('at', t, 'kind', 'round', 'round', i, 'who', me, 'owner', e.owner_id, 'text', line);
  end loop;

  grp := case
    when r.region_type in ('lake', 'coast', 'swamp', 'river_port', 'islands', 'underwater_ruins', 'bridge') then 'water'
    when r.region_type in ('ruined_temple', 'sealed_shrine', 'monastery', 'burial_ground', 'haunted_garden', 'pavilion') then 'shrine'
    when r.region_type in ('mountain_pass', 'mountain_peak', 'canyon', 'ice_valley', 'frontier_gate') then 'mountain'
    when r.region_type in ('underground', 'mine', 'abyss', 'rift', 'lost_city', 'ruins', 'archive', 'underworld_market') then 'deep'
    when r.region_type in ('observatory', 'celestial_tower') then 'sky'
    else 'wild' end;
  p_reg := case grp
    when 'water' then array['물안개가 발목까지 차올라 걸음을 조심스럽게 옮깁니다.', '물가의 갈대가 바람도 없이 한쪽으로 눕습니다.', '젖은 돌 위로 %m의 발자국이 이어져 있습니다.',
      '수면 아래에서 무언가 반짝였다가 사라집니다.', '떠내려온 나무판에 오래된 글씨가 새겨져 있습니다.', '물살 소리에 섞여 낮은 노랫소리가 들리는 듯합니다.',
      '썩은 말뚝에 묶인 빈 배 한 척이 삐걱거립니다.', '진흙에 빠진 신을 빼내느라 한참 애를 씁니다.', '물비린내 속에 비린 요기가 섞여 있습니다.', '수초 사이로 길이 하나 보여 그쪽으로 건너갑니다.']
    when 'shrine' then array['무너진 석등 아래에 아직 마르지 않은 향 자국이 있습니다.', '처마 끝 풍경이 혼자 울립니다.', '깨진 현판의 글자를 손끝으로 더듬어 읽어 봅니다.',
      '불단 뒤에서 %m의 그림자가 스쳐 지나갑니다.', '바닥에 흩어진 부적 조각을 주워 살펴봅니다.', '누군가 놓고 간 제물이 아직 상하지 않았습니다.',
      '돌계단 하나하나에 오래된 이름이 새겨져 있습니다.', '향 냄새가 짙어지는 쪽으로 천천히 다가갑니다.', '쓰러진 비석을 일으켜 세우고 잠시 묵념합니다.', '종루 위에서 누군가 내려다보는 기척이 듭니다.']
    when 'mountain' then array['가파른 비탈을 밧줄에 의지해 오릅니다.', '돌이 굴러떨어지는 소리에 바위 뒤로 몸을 숨깁니다.', '능선 너머로 %m의 울음이 메아리칩니다.',
      '바위틈에서 찬 바람이 새어 나옵니다.', '발아래 구름이 흘러가는 것을 내려다봅니다.', '오래된 돌무더기 이정표를 따라 방향을 잡습니다.',
      '미끄러운 얼음길에서 한 걸음씩 디딜 곳을 고릅니다.', '절벽에 새겨진 수호 문양이 희미하게 빛납니다.', '숨이 가빠 잠시 바위에 기대어 쉽니다.', '골짜기 아래로 길이 갈라집니다. 왼쪽 길을 택합니다.']
    when 'deep' then array['횃불이 흔들리며 벽의 긁힌 자국을 비춥니다.', '천장에서 떨어지는 물방울 소리만 이어집니다.', '좁은 통로를 몸을 옆으로 틀어 지나갑니다.',
      '어둠 저편에서 %m의 숨소리가 들립니다.', '무너진 서가 사이로 젖은 종이 냄새가 납니다.', '바닥에 그려진 오래된 진법을 밟지 않게 돌아갑니다.',
      '갱도 벽에 박힌 광석이 횃불에 반짝입니다.', '갈림길마다 분필로 표시를 남깁니다.', '발소리가 메아리쳐 몇 걸음 뒤에 따라오는 것 같습니다.', '깊은 곳에서 차가운 바람이 거꾸로 불어옵니다.']
    when 'sky' then array['별자리 판이 저절로 조금씩 돌아갑니다.', '높은 난간 너머로 밤하늘이 손에 닿을 듯합니다.', '관측 기록 한 장이 바람에 날려 와 발밑에 떨어집니다.',
      '하늘 위로 %m의 날개 그림자가 지나갑니다.', '청동 혼천의가 낮게 웅웅 울립니다.', '계단이 끝없이 이어지는 듯해 층수를 세며 오릅니다.',
      '흩어진 성진사가 발밑에서 반짝입니다.', '탑 꼭대기에서 별빛이 한 줄기 내려와 길을 비춥니다.']
    else array['수풀을 헤치며 짐승길을 따라 걷습니다.', '쓰러진 나무 아래에서 잠시 숨을 고릅니다.', '바람결에 %m의 기척이 스칩니다.',
      '풀숲에 버려진 낡은 등롱을 발견합니다.', '나뭇가지에 묶인 붉은 천 조각이 바람에 날립니다.', '%m이(가) 남긴 흔적을 따라 걸음을 옮깁니다.',
      '멀리서 낯선 소리가 들려 걸음을 늦춥니다.', '약초 냄새가 나는 쪽을 기억해 둡니다.', '오래된 표식을 발견하고 기록해 둡니다.', '잡초가 웃자란 옛길이 숲 안쪽으로 이어집니다.'] end;
  p_gen := array['잠시 멈춰 지도를 고쳐 그립니다.', '물을 긷고 짐을 다시 꾸립니다.', '신발 끈을 고쳐 묶고 다시 걷습니다.', '가방 속 보급품을 하나하나 세어 봅니다.',
    '발밑의 흙빛이 바뀌었습니다. 다른 구역으로 들어선 듯합니다.', '지나온 길을 돌아보며 표식이 남았는지 확인합니다.', '목이 말라 물을 한 모금 마십니다.',
    '잠깐 귀를 기울입니다. 주변이 너무 조용합니다.', '무기를 한 번 더 점검합니다.', '야행국에 보낼 짧은 보고를 적어 둡니다.', '바람 방향을 확인하고 냄새가 실려 오지 않는 쪽으로 돕니다.',
    '앉을 만한 돌을 찾아 잠시 다리를 쉽니다.'];
  p_stance := case e.stance
    when 'cautious' then array['기척이 나는 쪽을 피해 먼 길로 돌아갑니다.', '몸을 낮추고 소리를 죽여 지나갑니다.', '위험해 보이는 곳은 표시만 하고 지나칩니다.', '쉴 곳을 미리 봐 두고 천천히 나아갑니다.']
    when 'bold' then array['%m의 흔적을 일부러 따라 더 깊이 들어갑니다.', '거친 덤불을 칼로 베어 길을 냅니다.', '쉬지 않고 걸음을 재촉합니다.', '기척이 짙은 쪽으로 방향을 틉니다.']
    else array['갈림길에서 잠시 고민하다 넓은 길을 택합니다.', '경계를 늦추지 않고 일정한 걸음으로 나아갑니다.', '싸울 곳과 물러날 곳을 눈여겨봅니다.', '숨을 고르며 주변을 한 바퀴 둘러봅니다.'] end;
  p_job := case c.job_key
    when 'exorcist' then array['부적 한 장을 손에 쥐고 요기의 흐름을 읽습니다.', '나쁜 기운이 고인 곳에 정화 부적을 붙여 둡니다.', '방울을 한 번 흔들어 주변 혼백을 달랩니다.']
    when 'scout' then array['꺾인 풀잎으로 무엇이 언제 지나갔는지 가늠합니다.', '높은 곳에 올라 지형을 살핍니다.', '바닥의 발자국 크기를 재어 기록합니다.']
    when 'medic' then array['길가의 약초를 몇 줄기 꺾어 챙깁니다.', '작은 상처를 소독하고 붕대를 고쳐 맵니다.', '쓸 만한 약초가 자라는 곳을 지도에 표시합니다.']
    when 'sealmaster' then array['쉴 자리 둘레에 작은 결계를 그려 둡니다.', '봉인 먹으로 갈림길 바위에 표식을 남깁니다.', '결계가 흐트러진 자리를 찾아 손으로 짚어 봅니다.']
    when 'analyst' then array['지금까지 본 요괴의 습성을 수첩에 정리합니다.', '흔적의 순서를 맞춰 보며 동선을 추론합니다.', '모순되는 단서 하나에 밑줄을 그어 둡니다.']
    when 'artificer' then array['쓸 만한 부품을 주워 주머니에 넣습니다.', '헐거워진 장비의 매듭을 고쳐 조입니다.', '이상한 광택의 금속 조각을 살펴봅니다.']
    else array['주변을 살피며 천천히 나아갑니다.'] end;

  beat_s := greatest(75, span_s / 48.0);
  beats := floor(extract(epoch from least(now(), e.ends_at) - e.started_at) / beat_s)::int;
  for b in 1..beats loop
    bt := e.started_at + make_interval(secs => b * beat_s);
    if bt >= e.ends_at or (stop_at is not null and bt > stop_at) then exit; end if;
    h := abs(hashtext(e.expedition_id::text || '~' || b)::bigint);
    cat := h % 20;
    mon := coalesce(mons[1 + (h / 7) % greatest(1, cardinality(mons))], '요괴');
    if cat < 9 then line := p_reg[1 + (h / 20) % cardinality(p_reg)];
    elsif cat < 14 then line := p_gen[1 + (h / 20) % cardinality(p_gen)];
    elsif cat < 16 then line := p_stance[1 + (h / 20) % cardinality(p_stance)];
    elsif cat < 18 then line := p_job[1 + (h / 20) % cardinality(p_job)];
    else
      ph := public.world_time_phase(bt); wk := public.world_weather_key(r.territory_id, bt);
      p_env := case wk when 'rain' then array['빗줄기가 굵어져 처마 같은 바위 밑으로 잠시 피합니다.', '빗물에 흔적이 씻겨 내려가 길을 다시 찾습니다.']
        when 'fog' then array['안개가 짙어 한 걸음 앞도 잘 보이지 않습니다.', '안개 속에서 누군가 이름을 부르는 듯합니다.']
        when 'snow' then array['눈이 발목까지 쌓여 걸음이 무거워집니다.', '눈 위에 찍힌 낯선 발자국을 따라가 봅니다.']
        when 'wind' then array['삭풍이 옷깃을 파고들어 몸을 웅크립니다.', '바람에 실려 온 재가 눈을 따갑게 합니다.']
        when 'bloodmist' then array['붉은 안개가 피부에 닿아 따끔거립니다.', '혈무 속에서 요기가 한층 짙어집니다.']
        when 'cloudy' then array['구름이 낮게 깔려 사방이 어둑합니다.', '흐린 하늘 아래 바람이 눅눅합니다.']
        else array['맑은 하늘 덕에 먼 곳까지 내다보입니다.', '햇볕이 따뜻해 잠시 걸음이 가볍습니다.'] end
        || case ph when 'night' then array['달빛에 기대어 발밑을 더듬습니다.', '삼경의 정적 속에 풀벌레 소리마저 멎었습니다.']
        when 'dawn' then array['동이 트며 이슬이 반짝입니다.', '새벽 새 우는 소리에 긴장이 조금 풀립니다.']
        when 'dusk' then array['노을이 지며 그림자가 길어집니다.', '땅거미가 내려 등불을 켭니다.']
        else array['한낮의 열기에 땀이 흐릅니다.', '그늘을 골라 걸으며 숨을 돌립니다.'] end;
      line := p_env[1 + (h / 20) % cardinality(p_env)];
    end if;
    line := replace(replace(line, '%m', mon), '%p', coalesce(nm, '원정지'));
    if line = prev then line := p_gen[1 + (h / 3) % cardinality(p_gen)]; end if;
    prev := line;
    lines := lines || jsonb_build_object('at', bt, 'kind', 'walk', 'who', me, 'owner', e.owner_id, 'text', line);
  end loop;
  if now() >= e.ends_at and stop_at is null then
    lines := lines || jsonb_build_object('at', e.ends_at, 'kind', 'end', 'who', me, 'owner', e.owner_id, 'text', '원정을 마쳤습니다. 결과를 받으세요.');
  end if;
  -- 회차 정산 기록(전투·채집·발견·회복)
  lines := lines || coalesce(e.journal, '[]'::jsonb);
  return lines;
end $$;

/* ── 3) 원정 일지: 내 원정 + 같은 파티원의 원정(들어올 때 지난 회차를 정산) ── */
create or replace function public.world_expedition_progress() returns jsonb
language plpgsql security definer set search_path = '' as $$
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
    for x in select pe.expedition_id, pe.minutes, pe.started_at, pe.ends_at, pe.region_id, pe.settled_rounds, pc.character_name, pn.node_name, pr.region_name
             from public.world_party_members pm join public.world_expeditions pe on pe.owner_id = pm.owner_id and pe.status = 'active'
             join public.world_characters pc on pc.owner_id = pm.owner_id left join public.world_exploration_nodes pn on pn.node_id = pe.node_id
             left join public.world_map_regions pr on pr.region_id = pe.region_id
             where pm.party_id = pid and pm.owner_id <> uid order by pc.character_name loop
      perform public.world_expedition_settle(x.expedition_id);
      lines := lines || public.world_expedition_walk_lines(x.expedition_id);
      party := party || jsonb_build_array(jsonb_build_object('name', x.character_name, 'place', x.node_name, 'region', x.region_name, 'same_region', x.region_id = e.region_id,
        'rounds_done', greatest(0, least(case x.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end,
          floor((case x.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end) * extract(epoch from least(now(), x.ends_at) - x.started_at) / (x.minutes * 60.0))::int)),
        'total_rounds', case x.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end, 'ends_at', x.ends_at));
    end loop;
  end if;
  lines := (select coalesce(jsonb_agg(l order by (l ->> 'at')::timestamptz, n), '[]'::jsonb) from jsonb_array_elements(lines) with ordinality as a(l, n)
            where (l ->> 'at')::timestamptz <= now());
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
    'job_skill', case c.job_key when 'exorcist' then '파사 부적' when 'scout' then '흔적 추적' when 'medic' then '야전 처치'
      when 'sealmaster' then '결계 야영' when 'analyst' then '약점 간파' when 'artificer' then '현장 가공' end);
end $$;

-- 상태판이 원정 중에 불러 회차를 정산하고 지금 상태를 받아 간다(원정이 끝나지 않아도 체력·정신·침식이 맞도록)
create or replace function public.world_expedition_tick() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); eid uuid; before int; after int; c public.world_characters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select expedition_id, settled_rounds into eid, before from public.world_expeditions where owner_id = uid and status = 'active';
  if eid is null then return jsonb_build_object('active', false); end if;
  after := public.world_expedition_settle(eid);
  select * into c from public.world_characters where owner_id = uid;
  return jsonb_build_object('active', true, 'changed', after > before, 'settled', after, 'health', c.health, 'mental', c.mental, 'erosion', c.erosion);
end $$;

/* ── 4) 귀환: 남은 회차만 정산한 뒤 정리 ───────────────────── */
create or replace function public.world_expedition_complete(p_recall boolean default false)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare
  uid uuid := public.fn_owner_auth_uid();
  e public.world_expeditions%rowtype; c public.world_characters%rowtype; n public.world_exploration_nodes%rowtype; r public.world_map_regions%rowtype;
  total_rounds int; rounds int; st jsonb; sup jsonb; loot jsonb; lg jsonb; ended text; prog_before int; prog_after int;
  inv jsonb; used int; cap int; lost jsonb := '{}'::jsonb; k text; q int; space int; gained int := 0;
  ms_list text[]; new_ms text[] := '{}'; fully int; mount_gift text; nm text; job_name text;
  xp int; cxp int; gxp int; ixp int; gil_gain int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into e from public.world_expeditions where owner_id = uid and status = 'active' for update;
  if not found then raise exception '진행 중인 원정이 없습니다.'; end if;
  if now() < e.ends_at and not coalesce(p_recall, false) and not (e.state ->> 'ended' in ('downed', 'exhausted')) then
    raise exception '아직 원정이 끝나지 않았습니다. 일찍 돌아오려면 귀환을 고르세요.'; end if;
  total_rounds := case e.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end;
  rounds := case when now() >= e.ends_at then total_rounds else floor(total_rounds * extract(epoch from now() - e.started_at) / (e.minutes * 60.0))::int end;
  rounds := greatest(0, least(total_rounds, rounds));
  select * into r from public.world_map_regions where region_id = e.region_id;
  prog_before := (public.world_field_survey(uid, r.region_id) ->> 'pct')::int;
  perform public.world_expedition_settle(e.expedition_id, rounds);
  select * into e from public.world_expeditions where expedition_id = e.expedition_id for update;
  select * into c from public.world_characters where owner_id = uid for update;
  select * into n from public.world_exploration_nodes where node_id = e.node_id;
  nm := coalesce(n.node_name, '원정지');
  job_name := case c.job_key when 'exorcist' then '파사 부적' when 'scout' then '흔적 추적' when 'medic' then '야전 처치'
    when 'sealmaster' then '결계 야영' when 'analyst' then '약점 간파' when 'artificer' then '현장 가공' end;

  st := coalesce(e.state, jsonb_build_object('sup', e.supplies, 'loot', '{}'::jsonb, 'log', '[]'::jsonb, 'wins', 0, 'losses', 0, 'gathers', 0, 'finds', 0,
    'hazards', 0, 'discovered', 0, 'xp', 0, 'cxp', 0, 'gxp', 0, 'ixp', 0, 'gil', 0, 'jobn', 0, 'ended', 'complete'));
  sup := st -> 'sup'; loot := st -> 'loot'; lg := st -> 'log'; ended := st ->> 'ended';
  if ended = 'complete' and e.settled_rounds < total_rounds then ended := 'recalled'; end if;
  xp := (st ->> 'xp')::int; cxp := (st ->> 'cxp')::int; gxp := (st ->> 'gxp')::int; ixp := (st ->> 'ixp')::int; gil_gain := (st ->> 'gil')::int;

  inv := coalesce(c.inventory, '{}'::jsonb);
  for k, q in select key, value::text::int from jsonb_each(sup) where value::text::int > 0 loop inv := public.world_inv_add(inv, k, q); end loop;
  cap := c.bag_capacity + case when c.major_faction_id = 'river_alliance' then 20 else 0 end;
  select coalesce(sum(greatest(0, case when jsonb_typeof(v) = 'number' then v::text::numeric else 0 end)), 0)::int into used from jsonb_each(inv) t(kk, v);
  for k, q in select key, value::text::int from jsonb_each(loot) where value::text::int > 0 order by key loop
    space := greatest(0, cap - used);
    if space < q then lost := lost || jsonb_build_object(k, q - space); end if;
    if least(space, q) > 0 then inv := public.world_inv_add(inv, k, least(space, q)); used := used + least(space, q); end if;
  end loop;
  if lost <> '{}'::jsonb then lg := lg || jsonb_build_array('가방이 가득 차 일부 전리품을 두고 왔습니다.'); end if;

  update public.world_characters set
    health = case when ended = 'downed' then 0 else health end,
    combat_xp = combat_xp + cxp, combat_rank = public.world_skill_rank(combat_xp + cxp, 'combat'),
    gathering_xp = gathering_xp + gxp, gathering_rank = public.world_skill_rank(gathering_xp + gxp, 'gathering'),
    investigation_xp = investigation_xp + ixp, investigation_rank = public.world_skill_rank(investigation_xp + ixp, 'investigation'),
    gil = gil + gil_gain, inventory = inv, updated_at = now()
  where owner_id = uid;
  gained := public.world_grant_xp(uid, xp);
  select * into c from public.world_characters where owner_id = uid;

  prog_after := (public.world_field_survey(uid, r.region_id) ->> 'pct')::int;
  insert into public.world_region_progress(owner_id, region_id) values (uid, r.region_id) on conflict do nothing;
  select coalesce(p.milestones, '{}') into ms_list from public.world_region_progress p where p.owner_id = uid and p.region_id = r.region_id for update;
  if prog_after >= 100 and not ('complete' = any (ms_list)) then
    new_ms := array_append(new_ms, 'complete');
    update public.world_characters set bag_capacity = least(400, bag_capacity + 1) where owner_id = uid;
    lg := lg || jsonb_build_array(r.region_name || ' 완전 답사 — 가방 용량 +1');
  end if;
  update public.world_region_progress set progress = prog_after, expeditions = expeditions + 1, milestones = world_region_progress.milestones || new_ms, updated_at = now()
  where owner_id = uid and region_id = r.region_id;
  if 'complete' = any (new_ms) then
    select count(*) into fully from public.world_region_progress where owner_id = uid and 'complete' = any (milestones);
    if fully >= 5 then
      insert into public.world_owned_mounts(owner_id, mount_id) values (uid, 'mist_deer') on conflict do nothing;
      if found then mount_gift := 'mist_deer'; lg := lg || jsonb_build_array('다섯 지역을 완전히 답사하자 안개 사슴이 따라왔습니다.'); end if;
    end if;
  end if;

  update public.world_expeditions set status = 'done', finished_at = now(), result = jsonb_build_object(
    'ended', ended, 'rounds', e.settled_rounds, 'total_rounds', total_rounds, 'wins', (st ->> 'wins')::int, 'losses', (st ->> 'losses')::int,
    'gathers', (st ->> 'gathers')::int, 'finds', (st ->> 'finds')::int, 'hazards', (st ->> 'hazards')::int,
    'discovered', (st ->> 'discovered')::int, 'loot', loot, 'lost', lost, 'supplies_left', sup,
    'supplies_used', (select coalesce(jsonb_object_agg(s.key, s.value::text::int - coalesce((sup ->> s.key)::int, 0)) filter (where s.value::text::int - coalesce((sup ->> s.key)::int, 0) > 0), '{}'::jsonb) from jsonb_each(e.supplies) s),
    'experience', xp, 'combat_xp', cxp, 'gathering_xp', gxp, 'investigation_xp', ixp, 'gil', gil_gain, 'levels', gained,
    'health', c.health, 'mental', c.mental, 'erosion', c.erosion,
    'progress_before', prog_before, 'progress_after', prog_after, 'mount', mount_gift, 'log', lg, 'job_skill', jsonb_build_object('name', job_name, 'count', (st ->> 'jobn')::int))
  where expedition_id = e.expedition_id;

  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'expedition_end', nm || ' 원정 종료',
    jsonb_build_object('node_id', n.node_id, 'ended', ended, 'wins', (st ->> 'wins')::int, 'gathers', (st ->> 'gathers')::int, 'progress', prog_after));

  return (select jsonb_build_object('ok', true, 'place_name', nm, 'content', nm || ' 원정을 마쳤습니다.', 'result', x.result)
          from public.world_expeditions x where x.expedition_id = e.expedition_id);
end $$;

do $$ declare f text;
begin
  foreach f in array array['world_expedition_settle(uuid, integer)', 'world_expedition_walk_lines(uuid)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['world_expedition_progress()', 'world_expedition_tick()', 'world_expedition_complete(boolean)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
grant select, update on public.world_expeditions to fn_owner_field;

select 'ok' as result,
  exists (select 1 from information_schema.columns where table_name = 'world_expeditions' and column_name = 'journal') as journal_column,
  (select count(*) from pg_proc where proname in ('world_expedition_settle', 'world_expedition_walk_lines', 'world_expedition_tick')) as new_functions;
