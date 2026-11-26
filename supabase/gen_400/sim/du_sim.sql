create or replace function pg_temp.yh_spec(u uuid, j text, lv int, p_tier int, enh int) returns void language plpgsql as $$
declare base jsonb := public.world_job_base(j); pri text[]; pts int := 3 * (lv - 1); k text; cap int; give int; sl text; cand text; s jsonb; v numeric; best_v numeric; best_i text;
begin
  pri := case when j in ('artificer','bloodknight','analyst','spearman') then array['strength','vitality','agility']
              when j in ('scout','tamer') then array['agility','perception','vitality'] else array['spirit_affinity','willpower','vitality'] end;
  update public.world_characters set job_key = j, level = lv, strength = (base->>'strength')::int, agility = (base->>'agility')::int, vitality = (base->>'vitality')::int,
    perception = (base->>'perception')::int, willpower = (base->>'willpower')::int, spirit_affinity = (base->>'spirit_affinity')::int, stat_points = 0,
    skill_progress = coalesce(skill_progress, '{}') || jsonb_build_object(public.world_job_line(j), jsonb_build_object('xp', 30940, 'rank', 50)),
    downed_at = null, health = 100, mental = 100, erosion = 0, location = '고임터', travel_destination = null, travel_arrives_at = null,
    inventory = coalesce(inventory, '{}') || '{"pooled_light_shard": 5, "tonic": 5}'::jsonb
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

create or replace function pg_temp.yh_hd(a int, b int) returns int language sql immutable as $$
  select (abs(qa[1]-qb[1]) + abs(qa[2]-qb[2]) + abs(qa[1]+qa[2]-qb[1]-qb[2])) / 2 from (select public.world_du_qr(a) qa, public.world_du_qr(b) qb) x $$;

create or replace function pg_temp.yh_dupush(fid uuid, c int, d int, n int) returns int language plpgsql as $$
declare i int; nx int; dd int;
begin
  for i in 1 .. greatest(0, n) loop
    dd := coalesce(d, public.world_du_out(c));
    nx := public.world_du_step(c, dd);
    if nx = 10 then exit; end if;
    if nx is null or not public.world_du_open(fid, nx) then return null; end if;
    c := nx;
  end loop;
  return c;
end $$;

create or replace function pg_temp.yh_ducell(fid uuid, uid uuid, c int, brace boolean) returns numeric language plpgsql as $$
declare f public.world_gw_fights%rowtype; h jsonb; sc numeric := 0; cells int[]; p int; l int; me int;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  if not public.world_du_open(fid, c) then return -2000; end if;
  if public.world_du_ring(c) = 1 then sc := sc + 2; end if;
  p := c;
  for h in select * from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) loop
    l := (h ->> 'left')::int; cells := public.world_du_hz_cells(fid, h);
    if h ->> 'k' = 'fist' then
      if (h ->> 't')::uuid <> uid then continue; end if;
      if l <= 0 then
        sc := sc - case when brace then 5 else 20 end;
        if not brace and pg_temp.yh_dupush(fid, p, null, 1) is null then return sc - 1000; end if;
      elsif public.world_du_ring(c) = 2 then sc := sc - 5; end if;
      continue;
    end if;
    if h ->> 'k' = 'pull' then continue; end if;
    if l > 0 then
      if h ->> 'k' = 'shave' and public.world_du_ring(c) = 2 then sc := sc - 300 / l; end if;
      if h ->> 'k' = 'weight' and c = any (cells) then sc := sc - 40 / l; end if;
      if h ->> 'k' in ('slide', 'boulder') and c = any (cells) and l <= 1 then sc := sc - 15; end if;
      continue;
    end if;
    if h ->> 'k' = 'weight' and c = any (cells) then return sc - 1000; end if;
    if h ->> 'k' = 'shave' and public.world_du_ring(c) = 2 then return sc - 1000; end if;
    if h ->> 'k' = 'slide' and p = any (cells) then
      sc := sc - 30; p := pg_temp.yh_dupush(fid, p, null, 2 - case when brace then 1 else 0 end); if p is null then return sc - 1000; end if;
    end if;
    if h ->> 'k' = 'boulder' and p = any (cells) then
      sc := sc - 35; p := pg_temp.yh_dupush(fid, p, (h ->> 'dir')::int, 1 - case when brace then 1 else 0 end); if p is null then return sc - 1000; end if;
    end if;
    if h ->> 'k' = 'tilt' then
      p := pg_temp.yh_dupush(fid, p, (h ->> 'dir')::int, 1 - case when brace then 1 else 0 end); if p is null then return sc - 1000; end if;
    end if;
  end loop;
  return sc;
end $$;

create or replace function pg_temp.yh_pick(fid uuid, pol text) returns void language plpgsql as $$
declare f public.world_gw_fights%rowtype; x record; c int; best int; bs numeric; s numeric; brace boolean; v_act text; tgt uuid; sk text; hp int;
  goal int; pullc int; pl jsonb; w int; busy uuid[] := '{}'; pick uuid; z int;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  for x in select * from public.world_gw_members where fight_id = fid and out_rounds = 0 order by joined_at loop
    v_act := 'attack'; best := x.pos; brace := false; hp := x.hp; goal := null;
    if pol = 'ignore' then
      update public.world_gw_members set act = jsonb_build_object('a', 'attack'), rest = false where fight_id = fid and owner_id = x.owner_id; continue;
    end if;
    if pol = 'perfect' then
      select (e ->> 'c')::int into pullc from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) e where e ->> 'k' = 'pull' order by (e ->> 'left')::int, random() limit 1;
      if pullc is not null then
        if coalesce(x.gval, 0) > 0 then goal := pullc;
        else
          select w2::int into w from jsonb_array_elements_text(coalesce(f.board -> 'wedges', '[]'::jsonb)) w2 order by pg_temp.yh_hd(x.pos, w2::int) limit 1;
          if w is not null and not exists (select 1 from public.world_gw_members y where y.fight_id = fid and y.out_rounds = 0 and coalesce(y.gval, 0) > 0)
             and x.owner_id = (select y.owner_id from public.world_gw_members y where y.fight_id = fid and y.out_rounds = 0 and not y.rest order by pg_temp.yh_hd(y.pos, w), y.joined_at limit 1) then goal := w; end if;
        end if;
      end if;
    end if;
    bs := -1e9;
    foreach c in array array[x.pos] || public.world_du_nb(x.pos) loop
      for z in 0 .. 1 loop
        s := pg_temp.yh_ducell(fid, x.owner_id, c, z = 1) - case when z = 1 then 6 else 0 end - case when c = x.pos then 0 else 0.5 end
          - case when goal is not null then 8 * pg_temp.yh_hd(c, goal) else 0 end;
        if s > bs then bs := s; best := c; brace := z = 1; end if;
      end loop;
    end loop;
    if brace then v_act := 'brace'; end if;
    if goal is not null and best = goal and coalesce(x.gval, 0) > 0 and x.pos = goal
       and exists (select 1 from jsonb_array_elements(f.board -> 'hz') e where e ->> 'k' = 'pull' and (e ->> 'c')::int = goal and (e ->> 'left')::int <= 0) then v_act := 'stop'; end if;
    if pol = 'real' and random() < 0.12 then best := (array[x.pos] || public.world_du_nb(x.pos))[1 + floor(random() * (1 + cardinality(public.world_du_nb(x.pos))))::int]; v_act := 'attack'; end if;
    if v_act = 'attack' and hp < 35 and coalesce(x.items_used, 0) < 2 and f.mode = 'hard' then v_act := 'item'; end if;
    tgt := null; sk := null;
    if v_act = 'attack' and x.job_key = 'medic' then
      if f.round >= coalesce((x.cds ->> 'med_revive')::int, 0) then
        select owner_id into tgt from public.world_gw_members where fight_id = fid and (rest or (out_rounds > 0 and out_rounds < 9999)) limit 1;
        if tgt is not null then sk := 'med_revive'; end if;
      end if;
      if sk is null and f.round >= coalesce((x.cds ->> 'med_pulse')::int, 0)
         and (select count(*) from public.world_gw_members where fight_id = fid and out_rounds = 0 and world_gw_members.hp < 70) >= 2 then sk := 'med_pulse'; end if;
      if sk is null and f.round >= coalesce((x.cds ->> 'med_aid')::int, 0) then
        select owner_id into tgt from public.world_gw_members where fight_id = fid and out_rounds = 0 and world_gw_members.hp < 60 order by world_gw_members.hp limit 1;
        if tgt is not null then sk := 'med_aid'; end if;
      end if;
    end if;
    if v_act = 'attack' and x.job_key = 'artificer' and f.round >= coalesce((x.cds ->> 'exo_guardian')::int, 0) then sk := 'exo_guardian'; end if;
    if sk is not null then v_act := 'coop'; update public.world_characters set spiritual_power = 100 where owner_id = x.owner_id; end if;
    update public.world_gw_members set act = jsonb_build_object('a', v_act) || case when v_act = 'item' then jsonb_build_object('i', 'tonic', 't', x.owner_id) when v_act = 'coop' then jsonb_build_object('s', sk) || case when tgt is not null then jsonb_build_object('t', tgt) else '{}'::jsonb end else '{}'::jsonb end
      || case when best is distinct from x.pos then jsonb_build_object('m', best) else '{}'::jsonb end, rest = false where fight_id = fid and owner_id = x.owner_id;
  end loop;
end $$;

create or replace function pg_temp.yh_fight(jobs text[], pol text, md text, lv int, tier int, enh int) returns jsonb language plpgsql as $$
declare us uuid[]; fid uuid; i int; f public.world_gw_fights%rowtype; t numeric := 0; marks jsonb := '{}'; r int := 0; len numeric; pct numeric;
begin
  us := array(select owner_id from public.world_characters where level >= 50 order by owner_id limit cardinality(jobs));
  for i in 1 .. cardinality(jobs) loop perform pg_temp.yh_spec(us[i], jobs[i], lv, tier, enh); end loop;
  delete from public.world_gw_records where owner_id = any (us);
  insert into public.world_gw_fights(leader_id, status, start_at, boss_id, mode) values (us[1], 'wait', now(), 'ttangul', md) returning fight_id into fid;
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
  return jsonb_build_object('fell_at', (select jsonb_agg(round || ':' || left(text, 60)) from public.world_gw_log where fight_id = fid and text like '%떨어졌습니다%'), 'n', cardinality(jobs), 'pol', pol, 'status', f.status, 'round', f.round, 'sec', t, 'hp_pct', round(f.hp * 100.0 / greatest(1, f.max_hp)), 'max_hp', f.max_hp,
    'marks', marks, 'enrage', f.enrage, 'fell', coalesce(jsonb_array_length(f.board -> 'fell'), 0),
    'falls', (select sum(falls) from public.world_gw_members where fight_id = fid));
end $$;
