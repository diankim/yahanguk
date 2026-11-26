create or replace function pg_temp.yh_spec(u uuid, j text, lv int, p_tier int, enh int) returns void language plpgsql as $$
declare base jsonb := public.world_job_base(j); pri text[]; pts int := 3 * (lv - 1); k text; cap int; give int; sl text; cand text; s jsonb; v numeric; best_v numeric; best_i text;
begin
  pri := case when j in ('artificer','bloodknight','analyst','spearman') then array['strength','vitality','agility']
              when j in ('scout','tamer') then array['agility','perception','vitality'] else array['spirit_affinity','willpower','vitality'] end;
  update public.world_characters set job_key = j, level = lv, strength = (base->>'strength')::int, agility = (base->>'agility')::int, vitality = (base->>'vitality')::int,
    perception = (base->>'perception')::int, willpower = (base->>'willpower')::int, spirit_affinity = (base->>'spirit_affinity')::int, stat_points = 0,
    skill_progress = coalesce(skill_progress, '{}') || jsonb_build_object(public.world_job_line(j), jsonb_build_object('xp', 30940, 'rank', 50)),
    downed_at = null, health = 100, mental = 100, erosion = 0, location = '뒤집힌 물목', travel_destination = null, travel_arrives_at = null,
    inventory = coalesce(inventory, '{}') || '{"kelp_scale_shell": 5, "tonic": 5}'::jsonb
   where owner_id = u;
  foreach k in array pri loop
    cap := public.world_stat_cap_of(j, k, lv);
    execute format('select %I from public.world_characters where owner_id = $1', k) into give using u;
    give := least(pts, greatest(0, cap - give));
    execute format('update public.world_characters set %I = %I + $1 where owner_id = $2', k, k) using give, u;
    pts := pts - give;
  end loop;
  delete from public.world_character_equipment where owner_id = u;
  delete from public.world_gear_enhance where owner_id = u;
  delete from public.world_character_statuses where owner_id = u;
  foreach sl in array array['weapon','armor','hat','shoes','norigae','amulet','mask'] loop
    best_v := -1; best_i := null;
    for cand in select item_id from public.world_item_catalog where world_item_catalog.tier = p_tier and category = sl and base_item_id is null and (sl <> 'weapon' or equipment_traits->'jobs' ? j) loop
      delete from public.world_character_equipment e where e.owner_id = u and e.slot = sl;
      insert into public.world_character_equipment(owner_id, slot, item_id) values (u, sl, cand);
      if sl = 'weapon' then insert into public.world_gear_enhance(owner_id, item_id, level) values (u, cand, enh) on conflict do nothing; end if;
      s := public.world_combat_stats(u, null);
      v := (s->>'attack')::numeric + (s->>'crit_pct')::numeric * 2 + (s->>'defense')::numeric * 0.05;
      if v > best_v then best_v := v; best_i := cand; end if;
    end loop;
    delete from public.world_character_equipment e where e.owner_id = u and e.slot = sl;
    if best_i is not null then insert into public.world_character_equipment(owner_id, slot, item_id) values (u, sl, best_i); end if;
  end loop;
end $$;

create or replace function pg_temp.yh_cellscore(fid uuid, uid uuid, c int, brace boolean) returns numeric language plpgsql as $$
declare f public.world_gw_fights%rowtype; rb jsonb := public.world_boss_fight_rules(fid) -> 'board'; h jsonb; sc numeric := 0; p int; i int; n int; wet int; nx int; partner int;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  select coalesce(gval, 0) into wet from public.world_gw_members where fight_id = fid and owner_id = uid;
  if public.world_dh_rift(fid, c) then sc := sc - 3; end if;
  for h in select * from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) loop
    if h ->> 'k' = 'whirl' then
      nx := coalesce(public.world_dh_step((h ->> 'c')::int, f.board ->> 'dir'), (h ->> 'c')::int);
      if c in ((h ->> 'c')::int, nx) then sc := sc - 40; end if;
      continue;
    end if;
    if (h ->> 'left')::int > 0 then
      if h ->> 'k' = 'tentacle' and uid in ((h ->> 'a')::uuid, (h ->> 'b')::uuid) then
        select pos into partner from public.world_gw_members where fight_id = fid and owner_id = case when uid = (h ->> 'a')::uuid then (h ->> 'b')::uuid else (h ->> 'a')::uuid end;
        sc := sc + 4 * public.world_dh_dist(c, partner);
      end if;
      if h ->> 'k' = 'spray' and c = any (array(select jsonb_array_elements_text(h -> 'cells')::int)) and (h ->> 'left')::int <= 1 then sc := sc - 30; end if;
      continue;
    end if;
    if h ->> 'k' = 'spray' and c = any (array(select jsonb_array_elements_text(h -> 'cells')::int)) then sc := sc - 60; end if;
    if h ->> 'k' = 'tentacle' and uid in ((h ->> 'a')::uuid, (h ->> 'b')::uuid) then
      select pos into partner from public.world_gw_members where fight_id = fid and owner_id = case when uid = (h ->> 'a')::uuid then (h ->> 'b')::uuid else (h ->> 'a')::uuid end;
      if public.world_dh_dist(c, partner) < 4 then sc := sc - 50; end if;
    end if;
    if h ->> 'k' in ('current', 'surge', 'breath') then
      n := case when h ->> 'k' = 'surge' then 2 when h ->> 'k' = 'breath' then 2 else 1 end - case when brace then 1 else 0 end
        + case when wet >= 3 and h ->> 'k' <> 'breath' then 1 else 0 end;
      p := c;
      for i in 1 .. greatest(0, n) loop
        nx := public.world_dh_step(p, case when h ->> 'k' = 'breath' then 'C' else h ->> 'dir' end);
        if nx is null then exit; end if;
        if public.world_dh_rift(fid, nx) then sc := sc - 1000; exit; end if;
        p := nx;
      end loop;
    end if;
  end loop;
  return sc;
end $$;

create or replace function pg_temp.yh_pick(fid uuid, pol text) returns void language plpgsql as $$
declare f public.world_gw_fights%rowtype; x record; hd int; need int := 0; guiders uuid[] := '{}'; hz jsonb; due_head boolean := false; due_breath boolean := false;
  c int; best int; bs numeric; s numeric; brace boolean; v_act text; na int; t int; d int; hp int;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  hd := (f.board ->> 'head')::int;
  select count(*) into na from public.world_gw_members where fight_id = fid and out_rounds = 0 and not rest;
  for hz in select * from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) loop
    if hz ->> 'k' = 'head' then need := greatest(need, 1); due_head := due_head or (hz ->> 'left')::int = 0; end if;
    if hz ->> 'k' = 'breath' then need := greatest(need, ceil(na / 2.0)::int); due_breath := due_breath or (hz ->> 'left')::int = 0; end if;
  end loop;
  if pol = 'perfect' and need > 0 then
    guiders := array(select owner_id from public.world_gw_members where fight_id = fid and out_rounds = 0 and not rest order by public.world_dh_dist(pos, hd), joined_at limit need);
  end if;
  for x in select * from public.world_gw_members where fight_id = fid and out_rounds = 0 order by joined_at loop
    v_act := 'attack'; best := x.pos; brace := false; hp := x.hp;
    if pol = 'ignore' then
      update public.world_gw_members set act = jsonb_build_object('a', 'attack') where fight_id = fid and owner_id = x.owner_id; continue;
    end if;
    if x.owner_id = any (guiders) then
      if x.pos = hd then
        if due_head or due_breath then v_act := 'guide'; end if;
        best := hd;
      else
        select z into best from unnest(public.world_dh_nb(x.pos)) z where not public.world_dh_rift(fid, z) order by public.world_dh_dist(z, hd), z limit 1;
      end if;
    else
      bs := -1e9;
      foreach c in array array[x.pos] || public.world_dh_nb(x.pos) loop
        s := pg_temp.yh_cellscore(fid, x.owner_id, c, false) - case when c = x.pos then 0 else 0.5 end;
        if s > bs then bs := s; best := c; brace := false; end if;
        s := pg_temp.yh_cellscore(fid, x.owner_id, c, true) - 6 - case when c = x.pos then 0 else 0.5 end;
        if s > bs then bs := s; best := c; brace := true; end if;
      end loop;
      if brace then v_act := 'brace'; end if;
      if pol = 'real' and random() < 0.12 then best := (array[x.pos] || public.world_dh_nb(x.pos))[1 + floor(random() * (1 + cardinality(public.world_dh_nb(x.pos))))::int]; v_act := 'attack'; end if;
    end if;
    if v_act = 'attack' and hp < 35 and coalesce(x.items_used, 0) < 2 and f.mode = 'hard' then v_act := 'item'; end if;
    update public.world_gw_members set act = jsonb_build_object('a', v_act) || case when v_act = 'item' then jsonb_build_object('i', 'tonic', 't', x.owner_id) else '{}'::jsonb end
      || case when best is distinct from x.pos then jsonb_build_object('m', best) else '{}'::jsonb end where fight_id = fid and owner_id = x.owner_id;
  end loop;
end $$;

create or replace function pg_temp.yh_fight(jobs text[], pol text, md text, lv int, tier int, enh int) returns jsonb language plpgsql as $$
declare us uuid[]; fid uuid; i int; f public.world_gw_fights%rowtype; t numeric := 0; marks jsonb := '{}'; r int := 0; len numeric; pct numeric;
begin
  us := array(select owner_id from public.world_characters where level >= 50 order by owner_id limit cardinality(jobs));
  for i in 1 .. cardinality(jobs) loop perform pg_temp.yh_spec(us[i], jobs[i], lv, tier, enh); end loop;
  delete from public.world_gw_records where owner_id = any (us);
  insert into public.world_gw_fights(leader_id, status, start_at, boss_id, mode) values (us[1], 'wait', now(), 'dohaesu', md) returning fight_id into fid;
  for i in 1 .. cardinality(jobs) loop
    insert into public.world_gw_members(fight_id, owner_id, name, job_key, level) select fid, owner_id, character_name, job_key, level from public.world_characters where owner_id = us[i];
  end loop;
  perform public.world_gw_start(fid);
  loop
    select * into f from public.world_gw_fights where fight_id = fid;
    exit when f.status <> 'fight' or r > 400;
    len := extract(epoch from f.round_ends_at - f.updated_at);
    t := t + case when len > 7 then 10 else 5 end;
    pct := f.hp * 100.0 / f.max_hp;
    if pct <= 75 and not marks ? '75' then marks := marks || jsonb_build_object('75', f.round); end if;
    if pct <= 50 and not marks ? '50' then marks := marks || jsonb_build_object('50', f.round); end if;
    if pct <= 25 and not marks ? '25' then marks := marks || jsonb_build_object('25', f.round); end if;
    perform pg_temp.yh_pick(fid, pol);
    update public.world_gw_fights set round_ends_at = now() - interval '1 second', ends_at = now() + interval '1 hour' where fight_id = fid;
    perform public.world_gw_resolve(fid);
    r := r + 1;
  end loop;
  select * into f from public.world_gw_fights where fight_id = fid;
  return jsonb_build_object('n', cardinality(jobs), 'pol', pol, 'status', f.status, 'round', f.round, 'sec', t, 'hp_pct', round(f.hp * 100.0 / greatest(1, f.max_hp)), 'max_hp', f.max_hp,
    'marks', marks, 'enrage', f.enrage, 'fell', coalesce(jsonb_array_length(f.board -> 'fell'), 0),
    'falls', (select sum(falls) from public.world_gw_members where fight_id = fid));
end $$;
