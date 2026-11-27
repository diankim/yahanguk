create temp table if not exists yh_notes(nfid uuid, nround int, k text);

create or replace function pg_temp.yh_nb(kd text, c int) returns int[] language sql immutable as $$
  select case kd when 'gg' then public.world_gg_nb(c) when 'ux' then public.world_ux_nb(c)
    when 'mk' then array(select jsonb_array_elements_text(public.world_mk_lines() -> 'nb' -> c::text)::int)
    when 'dh' then public.world_dh_nb(c) when 'du' then public.world_du_nb(c) else public.world_by_nb(c) end $$;

create or replace function pg_temp.yh_bfs(kd text, a int, b int) returns int language plpgsql immutable as $$
declare seen int[] := array[a]; fr int[] := array[a]; nx int[]; d int := 0; c int; z int;
begin
  if a is null or b is null then return 99; end if;
  while d < 20 loop
    if b = any (fr) then return d; end if;
    nx := '{}';
    foreach c in array fr loop foreach z in array pg_temp.yh_nb(kd, c) loop if not z = any (seen) then seen := seen || z; nx := nx || z; end if; end loop; end loop;
    exit when cardinality(nx) = 0;
    fr := nx; d := d + 1;
  end loop;
  return 99;
end $$;

create or replace function pg_temp.yh_spec(u uuid, j text, lv int, p_tier int, enh int, loc text, inv jsonb) returns void language plpgsql as $$
declare base jsonb := public.world_job_base(j); pri text[]; pts int := 3 * (lv - 1); k text; cap int; give int; sl text; cand text; s jsonb; v numeric; best_v numeric; best_i text;
begin
  pri := case when j in ('artificer','bloodknight','analyst','spearman') then array['strength','vitality','agility']
              when j in ('scout','tamer') then array['agility','perception','vitality'] else array['spirit_affinity','willpower','vitality'] end;
  update public.world_characters set job_key = j, level = lv, strength = (base->>'strength')::int, agility = (base->>'agility')::int, vitality = (base->>'vitality')::int,
    perception = (base->>'perception')::int, willpower = (base->>'willpower')::int, spirit_affinity = (base->>'spirit_affinity')::int, stat_points = 0,
    skill_progress = coalesce(skill_progress, '{}') || jsonb_build_object(public.world_job_line(j), jsonb_build_object('xp', 30940, 'rank', 50)),
    combat_rank = 50, downed_at = null, health = 100, mental = 100, erosion = 0, spiritual_power = 100, location = loc, travel_destination = null, travel_arrives_at = null,
    inventory = coalesce(inventory, '{}') || inv
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
    for cand in select item_id from public.world_item_catalog where world_item_catalog.tier = p_tier and category = sl and base_item_id is null and item_id not like 'raid2%'
                  and (sl <> 'weapon' or equipment_traits->'jobs' ? j) loop
      delete from public.world_character_equipment e where e.owner_id = u and e.slot = sl;
      insert into public.world_character_equipment(owner_id, slot, item_id) values (u, sl, cand);
      if sl = 'weapon' then insert into public.world_gear_enhance(owner_id, item_id, level) values (u, cand, enh) on conflict do nothing; end if;
      s := public.world_combat_stats(u, null);
      v := (s->>'attack')::numeric + (s->>'crit_pct')::numeric * 2 + (s->>'defense')::numeric * case when j in ('artificer', 'bloodknight') then 0.6 else 0.05 end;
      if v > best_v then best_v := v; best_i := cand; end if;
    end loop;
    delete from public.world_character_equipment e where e.owner_id = u and e.slot = sl;
    if best_i is not null then insert into public.world_character_equipment(owner_id, slot, item_id) values (u, sl, best_i); end if;
  end loop;
end $$;

create or replace function pg_temp.yh_cellscore(fid uuid, uid uuid, c int, brace boolean) returns numeric language plpgsql as $$
declare f public.world_gw_fights%rowtype; h jsonb; sc numeric := 0; p int; i int; n int; wet int; nx int; partner int; wetm boolean;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  select coalesce(gval, 0) into wet from public.world_gw_members where fight_id = fid and owner_id = uid;
  wetm := coalesce(f.mech -> 'mechs', '[]'::jsonb) ? 'wet';
  if public.world_dh_rift(fid, c) then sc := sc - 3; end if;
  p := c;
  for h in select * from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) loop
    if h ->> 'k' = 'whirl' then
      nx := coalesce(public.world_dh_step((h ->> 'c')::int, f.board ->> 'dir'), (h ->> 'c')::int);
      if c in ((h ->> 'c')::int, nx) then sc := sc - 40; end if;
      continue;
    end if;
    if h ->> 'k' = 'tentacle' and uid in ((h ->> 'a')::uuid, (h ->> 'b')::uuid) then
      select pos into partner from public.world_gw_members where fight_id = fid and owner_id = case when uid = (h ->> 'a')::uuid then (h ->> 'b')::uuid else (h ->> 'a')::uuid end;
      if (h ->> 'left')::int > 0 then sc := sc + 4 * public.world_dh_dist(c, partner);
      elsif public.world_dh_dist(c, partner) < 4 then
        sc := sc - 50;
        nx := public.world_dh_step(p, 'C');
        if nx is not null and not public.world_dh_rift(fid, nx) then p := nx; end if;
      end if;
      continue;
    end if;
    if (h ->> 'left')::int > 0 then
      if h ->> 'k' = 'spray' and c = any (array(select jsonb_array_elements_text(h -> 'cells')::int)) and (h ->> 'left')::int <= 1 then sc := sc - 30; end if;
      continue;
    end if;
    if h ->> 'k' = 'spray' and p = any (array(select jsonb_array_elements_text(h -> 'cells')::int)) then
      sc := sc - 60; if wetm then wet := least(3, wet + 1); end if;
    end if;
    if h ->> 'k' in ('current', 'surge', 'breath') then
      n := case when h ->> 'k' = 'surge' then 2 else 1 end - case when brace then 1 else 0 end
        + case when wetm and wet >= 3 and h ->> 'k' <> 'breath' then 1 else 0 end;
      for i in 1 .. greatest(0, n) loop
        nx := public.world_dh_step(p, case when h ->> 'k' = 'breath' then 'C' else h ->> 'dir' end);
        if nx is null then exit; end if;
        if public.world_dh_rift(fid, nx) then return sc - 1000; end if;
        p := nx;
      end loop;
      if wetm and h ->> 'k' <> 'breath' then wet := least(3, wet + 1); end if;
    end if;
  end loop;
  return sc;
end $$;

create or replace function pg_temp.yh_hd(a int, b int) returns int language sql immutable as $$
  select (abs(qa[1]-qb[1]) + abs(qa[2]-qb[2]) + abs(qa[1]+qa[2]-qb[1]-qb[2])) / 2 from (select public.world_du_qr(a) qa, public.world_du_qr(b) qb) x $$;

create or replace function pg_temp.yh_dd(a int, b int) returns int language sql immutable as $$ select pg_temp.yh_bfs('du', a, b) $$;

create or replace function pg_temp.yh_ddb(b jsonb, a int, t int) returns int language plpgsql immutable as $$
declare seen int[] := array[a]; fr int[] := array[a]; nx int[]; d int := 0; c int; z int;
begin
  if a is null or t is null then return 99; end if;
  while d < 20 loop
    if t = any (fr) then return d; end if;
    nx := '{}';
    foreach c in array fr loop foreach z in array public.world_du_nb(c) loop
      if not z = any (seen) and (z = t or pg_temp.yh_du_open(b, z)) then seen := seen || z; nx := nx || z; end if;
    end loop; end loop;
    exit when cardinality(nx) = 0;
    fr := nx; d := d + 1;
  end loop;
  return 99;
end $$;

create or replace function pg_temp.yh_du_open(b jsonb, c int) returns boolean language sql immutable as $$
  select c is not null and c <> 10 and not (coalesce((b ->> 'gone')::boolean, false) and public.world_du_ring(c) = 2) and not (coalesce(b -> 'holes', '{}'::jsonb) ? c::text) $$;

create or replace function pg_temp.yh_dupush(b jsonb, c int, d int, n int) returns int language plpgsql immutable as $$
declare i int; nx int; dd int;
begin
  for i in 1 .. greatest(0, n) loop
    dd := coalesce(d, public.world_du_out(c));
    nx := public.world_du_step(c, dd);
    if nx = 10 then exit; end if;
    if nx is null or not pg_temp.yh_du_open(b, nx) then return null; end if;
    c := nx;
  end loop;
  return c;
end $$;

create or replace function pg_temp.yh_ducell(b jsonb, rb jsonb, uid uuid, c int, brace boolean, mpos jsonb) returns jsonb language plpgsql immutable as $$
declare h jsonb; sc numeric := 0; cells int[]; p int; l int; br int := case when brace then 1 else 0 end;
begin
  if not pg_temp.yh_du_open(b, c) then return jsonb_build_object('s', -5000, 'p', c, 'fell', true); end if;
  if public.world_du_ring(c) = 1 then sc := sc + 2; end if;
  sc := sc - 3 * (6 - (select count(*) from unnest(public.world_du_nb(c)) z where pg_temp.yh_du_open(b, z)) - case when public.world_du_ring(c) = 2 then 3 else 0 end);
  p := c;
  for h in select e from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) with ordinality q(e, o) order by case e ->> 'k' when 'weight' then 2 when 'shave' then 3 else 1 end, o loop
    l := (h ->> 'left')::int;
    cells := case when h ->> 'k' in ('weight', 'boulder', 'slide') then array(select jsonb_array_elements_text(h -> 'cells')::int) else '{}'::int[] end;
    if h ->> 'k' = 'pull' then continue; end if;
    if l > 0 then
      if h ->> 'k' = 'fist' and (h ->> 't')::uuid = uid and public.world_du_ring(c) = 2 then sc := sc - 8 / l; end if;
      if h ->> 'k' = 'shave' and public.world_du_ring(c) = 2 then sc := sc - 300 / l; end if;
      if h ->> 'k' = 'weight' and c = any (cells) then sc := sc - 60 / l; end if;
      if h ->> 'k' in ('slide', 'boulder') and c = any (cells) and l <= 1 then sc := sc - 15; end if;
      continue;
    end if;
    if h ->> 'k' = 'fist' then
      continue when (h ->> 't')::uuid <> uid;
      sc := sc - case when brace then 5 else 20 end;
      p := pg_temp.yh_dupush(b, p, null, coalesce((rb -> 'fist' ->> 'push')::int, 1) - br);
    elsif h ->> 'k' = 'slide' and p = any (cells) then
      sc := sc - 30; p := pg_temp.yh_dupush(b, p, null, coalesce((rb -> 'slide' ->> 'push')::int, 1) - br);
    elsif h ->> 'k' = 'boulder' and p = any (cells) then
      sc := sc - 35; p := pg_temp.yh_dupush(b, p, (h ->> 'dir')::int, coalesce((rb -> 'boulder' ->> 'push')::int, 1) - br);
    elsif h ->> 'k' = 'tilt' then
      p := pg_temp.yh_dupush(b, p, (h ->> 'dir')::int, coalesce((rb -> 'final' ->> 'push')::int, 1) - br);
    elsif h ->> 'k' = 'weight' and p = any (cells) then p := null;
    elsif h ->> 'k' = 'shave' and public.world_du_ring(p) = 2 then p := null;
    end if;
    if p is null then return jsonb_build_object('s', -5000, 'p', c, 'fell', true); end if;
  end loop;
  return jsonb_build_object('s', sc, 'p', p);
end $$;

create or replace function pg_temp.yh_support(fid uuid, x public.world_gw_members, v_act text) returns jsonb language plpgsql as $$
declare f public.world_gw_fights%rowtype; tgt uuid; sk text;
begin
  if v_act <> 'attack' then return null; end if;
  select * into f from public.world_gw_fights where fight_id = fid;
  if x.job_key = 'medic' then
    if f.round >= coalesce((x.cds ->> 'med_revive')::int, 0) then
      select owner_id into tgt from public.world_gw_members where fight_id = fid and (rest or (out_rounds > 0 and out_rounds < 9999)) limit 1;
      if tgt is not null then sk := 'med_revive'; end if;
    end if;
    if sk is null and f.round >= coalesce((x.cds ->> 'med_pulse')::int, 0)
       and (select count(*) from public.world_gw_members where fight_id = fid and out_rounds = 0 and world_gw_members.hp < 70) >= 2 then sk := 'med_pulse'; tgt := null; end if;
    if sk is null and f.round >= coalesce((x.cds ->> 'med_aid')::int, 0) then
      select owner_id into tgt from public.world_gw_members where fight_id = fid and out_rounds = 0 and world_gw_members.hp < 60 order by world_gw_members.hp limit 1;
      if tgt is not null then sk := 'med_aid'; end if;
    end if;
  elsif x.job_key = 'formation' then
    if f.round >= coalesce((x.cds ->> 'fm_nine')::int, 0)
       and (select count(*) from public.world_gw_members where fight_id = fid and out_rounds = 0 and world_gw_members.hp < 75) >= 2 then sk := 'fm_nine';
    elsif f.round >= coalesce((x.cds ->> 'fm_point')::int, 0) then
      select owner_id into tgt from public.world_gw_members where fight_id = fid and out_rounds = 0 and world_gw_members.hp < 60 order by world_gw_members.hp limit 1;
      if tgt is not null then sk := 'fm_point'; end if;
    end if;
  elsif x.job_key = 'artificer' and f.round >= coalesce((x.cds ->> 'exo_guardian')::int, 0) then sk := 'exo_guardian';
  elsif x.job_key = 'bloodknight' and f.round >= coalesce((x.cds ->> 'bk_undying')::int, 0) then sk := 'bk_undying';
  end if;
  if sk is null then return null; end if;
  update public.world_characters set spiritual_power = 100 where owner_id = x.owner_id;
  return jsonb_build_object('a', 'coop', 's', sk) || case when tgt is not null then jsonb_build_object('t', tgt) else '{}'::jsonb end;
end $$;

create or replace function pg_temp.yh_set(fid uuid, x public.world_gw_members, v_act text, best int, extra jsonb) returns void language plpgsql as $$
declare f public.world_gw_fights%rowtype; a jsonb; sup jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  if v_act = 'attack' and x.hp < (case when coalesce(extra ? '_nosup', false) then 12 else 35 end) and coalesce(x.items_used, 0) < (case when f.mode = 'ultimate' then 3 when f.mode = 'hard' then 2 else 9 end) then v_act := 'item'; end if;
  sup := case when coalesce(extra ? '_nosup', false) then null else pg_temp.yh_support(fid, x, v_act) end;
  a := coalesce(sup, jsonb_build_object('a', v_act) || case when v_act = 'item' then jsonb_build_object('i', 'tonic', 't', x.owner_id) else '{}'::jsonb end || coalesce(extra - '_nosup', '{}'::jsonb));
  if best is not null and best is distinct from x.pos then a := a || jsonb_build_object('m', best); end if;
  update public.world_gw_members set act = a, rest = false where fight_id = fid and owner_id = x.owner_id;
end $$;

create or replace function pg_temp.yh_dh_trace(b jsonb, rb jsonb, wetm boolean, na int, uid uuid, c int, brace boolean, wet0 int, blocked boolean, glim int default 0) returns jsonb language plpgsql immutable as $$
declare h jsonb; sc numeric := 0; p int := c; i int; n int; nx int; wet int := wet0; tpos int; rift int[]; ex int; fell boolean := false; pf int;
begin
  rift := array(select jsonb_array_elements_text(rb -> 'rift')::int);
  ex := coalesce((rb -> 'wet' ->> 'extra_at')::int, 99);
  if c = any (rift) then sc := sc - 3; end if;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    if h ->> 'k' = 'whirl' then
      if p = (h ->> 'c')::int then
        sc := sc - 150;
        nx := public.world_dh_step(p, coalesce(b ->> 'dir', 'E'));
        if nx is not null and not nx = any (rift) then p := nx; if wetm then wet := least(3, wet + 1); end if; end if;
      elsif (h ->> 'life')::int > 1 and p = public.world_dh_step((h ->> 'c')::int, coalesce(b ->> 'dir', 'E')) then sc := sc - 8;
      end if;
      continue;
    end if;
    if (h ->> 'left')::int > 0 then
      if h ->> 'k' = 'spray' and (h ->> 'left')::int <= 1 and c = any (array(select jsonb_array_elements_text(h -> 'cells')::int)) then sc := sc - 25; end if;
      continue;
    end if;
    if h ->> 'k' in ('current', 'surge') or (h ->> 'k' = 'breath' and not blocked) then
      n := case when h ->> 'k' = 'surge' then coalesce((rb -> 'surge' ->> 'push')::int, 2) when h ->> 'k' = 'breath' then coalesce((rb -> 'breath' ->> 'pull')::int, 1) else 1 end
        - case when brace then 1 else 0 end + case when wetm and h ->> 'k' <> 'breath' and wet >= ex then 1 else 0 end;
      for i in 1 .. greatest(0, n) loop
        nx := public.world_dh_step(p, case when h ->> 'k' = 'breath' then 'C' else h ->> 'dir' end);
        exit when nx is null;
        if nx = any (rift) then fell := true; exit; end if;
        p := nx;
      end loop;
      exit when fell;
      if wetm and h ->> 'k' <> 'breath' then wet := least(3, wet + 1); end if;
    elsif h ->> 'k' = 'spray' and p = any (array(select jsonb_array_elements_text(h -> 'cells')::int)) then
      sc := sc - 60; if wetm then wet := least(3, wet + 1); end if;
    elsif h ->> 'k' = 'tentacle' and uid in ((h ->> 'a')::uuid, (h ->> 'b')::uuid) then
      tpos := p;
    end if;
  end loop;
  if fell then return jsonb_build_object('s', -5000, 'fell', true, 'p', p, 't', coalesce(tpos, p), 'pf', p); end if;
  if p = any (rift) then sc := sc - 3; end if;
  pf := p;
  for h in select e from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) e where e ->> 'k' in ('current', 'surge') and (e ->> 'left')::int > 0 and (e ->> 'left')::int < glim order by (e ->> 'left')::int loop
    n := case when h ->> 'k' = 'surge' then coalesce((rb -> 'surge' ->> 'push')::int, 2) else 1 end - 1 + case when wetm and wet >= ex then 1 else 0 end;
    for i in 1 .. greatest(0, n) loop
      nx := public.world_dh_step(pf, h ->> 'dir');
      exit when nx is null or nx = any (rift);
      pf := nx;
    end loop;
  end loop;
  return jsonb_build_object('s', sc - case when wetm then 2 * wet else 0 end, 'p', p, 't', coalesce(tpos, p), 'pf', pf);
end $$;

create or replace function pg_temp.yh_pick_dh(fid uuid, pol text, plan jsonb default null) returns void language plpgsql as $$
declare f public.world_gw_fights%rowtype; rb jsonb; x public.world_gw_members; pm jsonb; mask int; hd int; need int := 0; guiders uuid[] := '{}'; hz jsonb; due_g boolean := false;
  c int; na int; wetm boolean; blocked boolean := false; opts jsonb := '{}'; o jsonb; tr jsonb; k int; ch jsonb := '{}'; tn jsonb; a uuid; bb uuid; oa jsonb; ob jsonb; bs numeric; s numeric; pa jsonb; pb jsonb; tdist int;
  v_act text; best int; br boolean; g_left int := 99; tl int; keep_only boolean := false;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  rb := public.world_boss_fight_rules(fid) -> 'board';
  hd := (f.board ->> 'head')::int;
  wetm := coalesce(f.mech -> 'mechs', '[]'::jsonb) ? 'wet';
  select count(*) into na from public.world_gw_members where fight_id = fid and out_rounds = 0 and not rest;
  for hz in select * from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) loop
    if hz ->> 'k' = 'head' then need := greatest(need, 1); g_left := least(g_left, (hz ->> 'left')::int); due_g := due_g or (hz ->> 'left')::int = 0; end if;
    if hz ->> 'k' = 'breath' then need := greatest(need, ceil(na / 2.0)::int); g_left := least(g_left, (hz ->> 'left')::int); due_g := due_g or (hz ->> 'left')::int = 0; end if;
  end loop;
  if public.world_ug_wm_on(fid) and f.board -> 'wm' ->> 'k' = 'rift4' then
    select (f.board -> 'wm' -> 'ord' ->> (q.oo::int - 1))::int, q.zz::int - f.round into hd, g_left
      from jsonb_array_elements_text(f.board -> 'wm' -> 'steps') with ordinality q(zz, oo) where q.zz::int >= f.round order by q.zz::int limit 1;
    need := case when hd is not null then 1 else 0 end; due_g := g_left = 0;
  end if;
  if need = 0 and coalesce(f.mech -> 'mechs', '[]'::jsonb) ? 'head' then
    need := case when f.mech -> 'mechs' ? 'breath' then ceil(na / 2.0)::int else 1 end; g_left := 3; keep_only := true;
  end if;
  if pol <> 'ignore' and need > 0 then
    guiders := array(select owner_id from public.world_gw_members where fight_id = fid and out_rounds = 0 and not rest order by public.world_dh_dist(pos, hd), joined_at limit need);
    blocked := not keep_only and cardinality(guiders) * 2 >= na and (select count(*) from public.world_gw_members where owner_id = any (guiders) and fight_id = fid and public.world_dh_dist(pos, hd) <= 1) = cardinality(guiders);
  end if;
  for x in select * from public.world_gw_members where fight_id = fid and out_rounds = 0 order by joined_at loop
    if pol = 'ignore' then perform pg_temp.yh_set(fid, x, 'attack', null, null); continue; end if;
    pm := plan -> x.owner_id::text; mask := coalesce((pm ->> 'v0')::int, 0);
    o := '[]';
    foreach c in array array[x.pos] || public.world_dh_nb(x.pos) loop
      continue when mask <> 0 and mask & (1 << (c - 1)) = 0;
      for k in 0 .. 1 loop
        continue when k = 1 and pm ->> 'a' is not null and pm ->> 'a' <> 'brace';
        continue when k = 0 and pm ->> 'a' = 'brace';
        tr := pg_temp.yh_dh_trace(f.board, rb, wetm, na, x.owner_id, c, k = 1, coalesce(x.gval, 0), blocked, g_left);
        s := (tr ->> 's')::numeric - case when k = 1 then 6 else 0 end - case when c = x.pos then 0 else 0.5 end;
        if x.owner_id = any (guiders) then
          s := s - case when keep_only then 15 * greatest(0, public.world_dh_dist((tr ->> 'p')::int, hd) - 1) + 3 * public.world_dh_dist((tr ->> 'p')::int, hd)
            when g_left = 0 then 0 else 60 * greatest(0, public.world_dh_dist((tr ->> 'pf')::int, hd) - g_left) + 4 * public.world_dh_dist((tr ->> 'pf')::int, hd) end;
          if due_g and c = hd then s := s + 300; end if;
        end if;
        o := o || jsonb_build_array(tr || jsonb_build_object('s', s, 'c', c, 'br', k = 1));
      end loop;
    end loop;
    if (pm ->> 'a' is not null or mask <> 0) and coalesce((select max((e ->> 's')::numeric) from jsonb_array_elements(o) e), -1e9) <= -4000 then
      insert into yh_notes values (fid, f.round, 'plan_fatal');
      o := '[]';
      foreach c in array array[x.pos] || public.world_dh_nb(x.pos) loop
        for k in 0 .. 1 loop
          tr := pg_temp.yh_dh_trace(f.board, rb, wetm, na, x.owner_id, c, k = 1, coalesce(x.gval, 0), blocked, g_left);
          o := o || jsonb_build_array(tr || jsonb_build_object('s', (tr ->> 's')::numeric - case when k = 1 then 6 else 0 end, 'c', c, 'br', k = 1));
        end loop;
      end loop;
      plan := plan - x.owner_id::text;
    end if;
    if jsonb_array_length(o) = 0 then o := jsonb_build_array(jsonb_build_object('s', 0, 'c', x.pos, 'br', false, 'p', x.pos, 't', x.pos)); end if;
    opts := opts || jsonb_build_object(x.owner_id::text, o);
    ch := ch || jsonb_build_object(x.owner_id::text, (select e from jsonb_array_elements(o) e order by (e ->> 's')::numeric desc limit 1));
  end loop;
  if pol <> 'ignore' then
    for tn in select * from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) e where e ->> 'k' = 'tentacle' loop
      a := (tn ->> 'a')::uuid; bb := (tn ->> 'b')::uuid; tl := (tn ->> 'left')::int;
      continue when not (opts ? a::text or opts ? bb::text);
      bs := -1e12;
      for oa in select * from jsonb_array_elements(coalesce(opts -> a::text, (select jsonb_build_array(jsonb_build_object('s', 0, 'fixed', true, 'c', pos, 'p', pos, 't', pos)) from public.world_gw_members where fight_id = fid and owner_id = a))) loop
        for ob in select * from jsonb_array_elements(coalesce(opts -> bb::text, (select jsonb_build_array(jsonb_build_object('s', 0, 'fixed', true, 'c', pos, 'p', pos, 't', pos)) from public.world_gw_members where fight_id = fid and owner_id = bb))) loop
          tdist := public.world_dh_dist(case when tl = 0 then (oa ->> 't')::int else (oa ->> 'p')::int end, case when tl = 0 then (ob ->> 't')::int else (ob ->> 'p')::int end);
          s := (oa ->> 's')::numeric + (ob ->> 's')::numeric
            + case when tl = 0 then case when tdist >= coalesce((rb -> 'tentacle' ->> 'dist')::int, 4) then 0 else -400 end
                   else 8 * least(tdist, 6) - case when tl <= 2 then 40 * greatest(0, coalesce((rb -> 'tentacle' ->> 'dist')::int, 4) + 1 - tdist) else 0 end end;
          if s > bs then bs := s; pa := oa; pb := ob; end if;
        end loop;
      end loop;
      if opts ? a::text then ch := ch || jsonb_build_object(a::text, pa); end if;
      if opts ? bb::text then ch := ch || jsonb_build_object(bb::text, pb); end if;
    end loop;
  end if;
  for x in select * from public.world_gw_members where fight_id = fid and out_rounds = 0 order by joined_at loop
    continue when pol = 'ignore';
    pm := plan -> x.owner_id::text; o := ch -> x.owner_id::text;
    best := (o ->> 'c')::int; br := (o ->> 'br')::boolean;
    v_act := case when br then 'brace' else 'attack' end;
    if pm ->> 'a' is not null then v_act := pm ->> 'a';
    elsif x.owner_id = any (guiders) and due_g and best = hd then v_act := 'guide'; end if;
    if pol = 'real' and random() < 0.12 then best := (array[x.pos] || public.world_dh_nb(x.pos))[1 + floor(random() * (1 + cardinality(public.world_dh_nb(x.pos))))::int]; v_act := 'attack'; end if;
    if v_act in ('guide', 'brace') then
      update public.world_gw_members set act = jsonb_build_object('a', v_act) || case when best is distinct from x.pos then jsonb_build_object('m', best) else '{}'::jsonb end, rest = false
       where fight_id = fid and owner_id = x.owner_id;
    else perform pg_temp.yh_set(fid, x, v_act, best, null); end if;
  end loop;
end $$;

create or replace function pg_temp.yh_pick_du(fid uuid, pol text, plan jsonb default null) returns void language plpgsql as $$
declare f public.world_gw_fights%rowtype; rb jsonb; x public.world_gw_members; pm jsonb; mask int; c int; best int; bs numeric; s numeric; brace boolean; v_act text; z int; tr jsonb;
  pull jsonb; pc int; pl int; carrier uuid; carriers uuid[] := '{}'; picker uuid; w int; wd int; stopc int; stopped boolean := false;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  rb := public.world_boss_fight_rules(fid) -> 'board';
  select e into pull from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) e where e ->> 'k' = 'pull' and not coalesce((e ->> 'wm')::boolean, false) order by (e ->> 'left')::int, (e ->> 'c')::int limit 1;
  pc := (pull ->> 'c')::int; pl := (pull ->> 'left')::int;
  if pull is not null and plan is null or (pull is not null and not public.world_ug_wm_on(fid)) then
    carriers := array(select owner_id from public.world_gw_members where fight_id = fid and out_rounds = 0 and not rest and coalesce(gval, 0) > 0);
    carrier := carriers[1];
    if carrier is null then
      select (w2)::int into w from jsonb_array_elements_text(coalesce(f.board -> 'wedges', '[]'::jsonb)) w2 order by pg_temp.yh_ddb(f.board, (w2)::int, pc) limit 1;
      if w is not null then
        select owner_id into picker from public.world_gw_members where fight_id = fid and out_rounds = 0 and not rest and pos <> w order by pg_temp.yh_ddb(f.board, pos, w) + case when job_key in ('artificer', 'bloodknight') then 1 else 0 end, joined_at limit 1;
      end if;
    end if;
  end if;
  for x in select * from public.world_gw_members where fight_id = fid and out_rounds = 0 order by joined_at loop
    if pol = 'ignore' then perform pg_temp.yh_set(fid, x, 'attack', null, null); continue; end if;
    v_act := 'attack'; best := x.pos; brace := false; stopc := null;
    pm := plan -> x.owner_id::text; mask := coalesce((pm ->> 'v0')::int, 0);
    bs := -1e9;
    foreach c in array array[x.pos] || public.world_du_nb(x.pos) loop
      continue when mask <> 0 and mask & (1 << (c - 1)) = 0;
      for z in 0 .. 1 loop
        continue when pm ->> 'a' is not null and ((pm ->> 'a' = 'brace') <> (z = 1));
        tr := pg_temp.yh_ducell(f.board, rb, x.owner_id, c, z = 1, null);
        s := (tr ->> 's')::numeric - case when z = 1 then 6 else 0 end - case when c = x.pos then 0 else 0.5 end;
        if x.owner_id = any (carriers) and pc is not null then
          if pl = 0 then s := s + case when c = pc and z = 0 then 400 else 0 end;
          else s := s - 60 * greatest(0, pg_temp.yh_ddb(f.board, coalesce((tr ->> 'p')::int, c), pc) - greatest(0, pl - 1)) - 35 * pg_temp.yh_ddb(f.board, coalesce((tr ->> 'p')::int, c), pc); end if;
        elsif x.owner_id = picker and w is not null then
          s := s + case when c = w and c <> x.pos then 250 else -40 * pg_temp.yh_ddb(f.board, c, w) end;
        end if;
        if s > bs then bs := s; best := c; brace := z = 1; end if;
      end loop;
    end loop;
    if bs <= -4000 and (mask <> 0 or pm ->> 'a' is not null) then
      pm := null; mask := 0; bs := -1e9;
      foreach c in array array[x.pos] || public.world_du_nb(x.pos) loop
        for z in 0 .. 1 loop
          tr := pg_temp.yh_ducell(f.board, rb, x.owner_id, c, z = 1, null);
          s := (tr ->> 's')::numeric - case when z = 1 then 6 else 0 end - case when c = x.pos then 0 else 0.5 end;
          if s > bs then bs := s; best := c; brace := z = 1; end if;
        end loop;
      end loop;
      insert into yh_notes values (fid, f.round, 'plan_fatal');
    end if;
    if brace then v_act := 'brace'; end if;
    if pm ->> 'a' is not null then v_act := pm ->> 'a';
    elsif x.owner_id = any (carriers) and pl = 0 and best = pc and not brace then v_act := 'stop'; stopped := true; end if;
    if pol = 'real' and random() < 0.12 then best := (array[x.pos] || public.world_du_nb(x.pos))[1 + floor(random() * (1 + cardinality(public.world_du_nb(x.pos))))::int]; v_act := 'attack'; end if;
    if v_act in ('stop', 'brace') then
      update public.world_gw_members set act = jsonb_build_object('a', v_act) || case when best is distinct from x.pos then jsonb_build_object('m', best) else '{}'::jsonb end, rest = false
       where fight_id = fid and owner_id = x.owner_id;
    else perform pg_temp.yh_set(fid, x, v_act, best, null); end if;
  end loop;
  if pol <> 'ignore' and pc is not null and pl = 0 and not stopped then
    insert into yh_notes values (fid, f.round, case when cardinality(carriers) = 0 then 'pull_nowedge'
      when not pg_temp.yh_du_open(f.board, pc) or exists (select 1 from jsonb_array_elements(f.board -> 'hz') e where (e ->> 'left')::int = 0 and (e ->> 'k' = 'shave' or (e ->> 'k' in ('slide', 'boulder') and e -> 'cells' @> to_jsonb(pc)))) then 'pull_forced'
      else 'pull_bot' end);
  end if;
end $$;

create or replace procedure pg_temp.yh_gw_play(p_boss text, p_jobs text[], p_pol text, p_mode text, p_seed numeric, p_opt jsonb, inout res jsonb) language plpgsql as $$
declare us uuid[]; fid uuid; i int; f public.world_gw_fights%rowtype; r int := 0; t numeric := 0; pct numeric; marks jsonb := '{}'; br jsonb; reg text; rname text; item text; inv jsonb;
  lv int := coalesce((p_opt ->> 'lv')::int, 55); tier int := coalesce((p_opt ->> 'tier')::int, 9); enh int := coalesce((p_opt ->> 'enh')::int, 10); cap int := coalesce((p_opt ->> 'cap')::int, 400);
  acted int := 0; act2 boolean := false; t0 timestamptz := clock_timestamp(); ms jsonb; bads jsonb;
begin
  perform setseed(p_seed);
  br := public.world_boss_rules() -> p_boss;
  reg := case when p_mode = 'ultimate' then public.world_ultimate_rules() -> 'boards' -> p_boss ->> 'region' else br ->> 'region' end;
  select region_name into rname from public.world_map_regions where region_id = reg;
  item := br ->> 'item';
  inv := jsonb_build_object('tonic', 10) || case when item is not null then jsonb_build_object(item, 5) else '{}'::jsonb end;
  us := array(select owner_id from public.world_characters order by (level >= 50) desc, owner_id limit cardinality(p_jobs));
  for i in 1 .. cardinality(p_jobs) loop perform pg_temp.yh_spec(us[i], p_jobs[i], lv, tier, enh, rname, inv); end loop;
  delete from public.world_gw_records where owner_id = any (us);
  insert into public.world_gw_fights(leader_id, status, start_at, boss_id, mode) values (us[1], 'wait', now(), p_boss, p_mode) returning fight_id into fid;
  for i in 1 .. cardinality(p_jobs) loop
    insert into public.world_gw_members(fight_id, owner_id, name, job_key, level, fx)
      select fid, owner_id, character_name, job_key, level, case when p_opt ? 'hold' then jsonb_build_object('hold', p_opt ->> 'hold') else '{}'::jsonb end
      from public.world_characters where owner_id = us[i];
  end loop;
  perform set_config('yh.plan_lvl', '0', false);
  perform public.world_gw_start(fid);
  if p_opt ? 'start' then update public.world_gw_fights set hp = round(max_hp * (p_opt ->> 'start')::numeric / 100.0) where fight_id = fid; end if;
  loop
    select * into f from public.world_gw_fights where fight_id = fid;
    exit when f.status <> 'fight' or r >= cap;
    if p_mode = 'ultimate' and not act2 and coalesce((f.board -> 'ug' ->> 'act')::int, 1) = 2 then
      act2 := true;
      if p_opt ? 'start2' then update public.world_gw_fights set hp = round(max_hp * (p_opt ->> 'start2')::numeric / 100.0) where fight_id = fid; select * into f from public.world_gw_fights where fight_id = fid; end if;
    end if;
    t := t + case when f.round_ends_at - f.updated_at > interval '7 seconds' then 10 else 5 end;
    pct := f.hp * 100.0 / greatest(1, f.max_hp);
    if pct <= 75 and not marks ? ('75a' || coalesce(f.board -> 'ug' ->> 'act', '')) then marks := marks || jsonb_build_object('75a' || coalesce(f.board -> 'ug' ->> 'act', ''), f.round); end if;
    if pct <= 50 and not marks ? ('50a' || coalesce(f.board -> 'ug' ->> 'act', '')) then marks := marks || jsonb_build_object('50a' || coalesce(f.board -> 'ug' ->> 'act', ''), f.round); end if;
    if pct <= 25 and not marks ? ('25a' || coalesce(f.board -> 'ug' ->> 'act', '')) then marks := marks || jsonb_build_object('25a' || coalesce(f.board -> 'ug' ->> 'act', ''), f.round); end if;
    if coalesce(f.mech ->> 'k', '') <> 'rest' then
      if p_mode = 'ultimate' then perform pg_temp.yh_pick_ug(fid, p_pol);
      elsif f.boss_id = 'dohaesu' then perform pg_temp.yh_pick_dh(fid, p_pol);
      elsif f.boss_id = 'ttangul' then perform pg_temp.yh_pick_du(fid, p_pol);
      else raise exception 'no bot for % %', f.boss_id, p_mode; end if;
    end if;
    update public.world_gw_fights set round_ends_at = now() - interval '1 second', ends_at = now() + interval '1 hour' where fight_id = fid;
    perform public.world_gw_resolve(fid);
    r := r + 1;
    commit;
  end loop;
  select * into f from public.world_gw_fights where fight_id = fid;
  select coalesce(jsonb_object_agg(k, n), '{}'::jsonb) into ms from (select kind || ':' || left(regexp_replace(text, '^[^—]*— ', ''), 34) k, count(*) n
    from public.world_gw_log where fight_id = fid and kind in ('miss', 'bad') group by 1 order by 2 desc limit 12) q;
  res := jsonb_build_object('boss', p_boss, 'mode', p_mode, 'jobs', to_jsonb(p_jobs), 'n', cardinality(p_jobs), 'pol', p_pol, 'seed', p_seed, 'opt', p_opt,
    'status', f.status, 'won', f.status = 'won', 'round', f.round, 'sec', t, 'hp_pct', round(f.hp * 100.0 / greatest(1, f.max_hp)), 'max_hp', f.max_hp,
    'act', coalesce((f.board -> 'ug' ->> 'act')::int, 1), 'marks', marks, 'enrage', f.enrage,
    'miss', (select count(*) from public.world_gw_log where fight_id = fid and kind = 'miss'),
    'bad', (select count(*) from public.world_gw_log where fight_id = fid and kind = 'bad'),
    'cut', (select count(*) from public.world_gw_log where fight_id = fid and kind = 'bad' and (text like '%제때 %달래지 못했%' or text like '%제때 %잠재우지 못했%' or text like '%기세를 꺾지 못했%' or text like '%라운드가 다 지났다%')),
    'mech', (select count(*) from public.world_gw_log where fight_id = fid and kind = 'bad' and text not like '도전이 끝났습니다%' and text not like '모두가 쓰러졌습니다%'
      and text not like '모두가 물러났습니다%' and text not like '이야기꾼이 침을 튀긴다%' and text not like '%수법을 놓쳐 「%' and text not like '%제때 %달래지 못했%'
      and text not like '%제때 %잠재우지 못했%' and text not like '%기세를 꺾지 못했%' and text not like '%라운드가 다 지났다%' and text not like '%은(는) 둘 이상이 함께여야%'),
    'fist', (select count(*) from public.world_gw_log where fight_id = fid and kind = 'hit' and text like '%돌주먹에 %의 피해%'),
    'head_phase', (select count(*) from public.world_gw_log l where l.fight_id = fid and l.kind = 'bad' and l.text like '아무도 길을 알려 주지 않았습니다%'
      and exists (select 1 from public.world_gw_log p where p.fight_id = fid and p.kind = 'phase' and p.round between l.round - 1 and l.round and p.text like '%머리가%')),
    'notes', (select coalesce(jsonb_object_agg(k, n), '{}'::jsonb) from (select k, count(*) n from yh_notes where nfid = fid group by k) q),
    'wipe', (select text from public.world_gw_log where fight_id = fid and kind = 'bad' and text like '이야기꾼의 말로는%' order by id desc limit 1),
    'weak', (select coalesce(sum(case when jsonb_typeof(weak) = 'array' then jsonb_array_length(weak) else 0 end), 0) from public.world_gw_members where fight_id = fid),
    'fell', coalesce(jsonb_array_length(f.board -> 'fell'), 0),
    'falls', (select sum(falls) from public.world_gw_members where fight_id = fid),
    'wm', (select jsonb_agg(left(text, 40) order by id) from public.world_gw_log where fight_id = fid and kind = 'wm'),
    'lines', ms,
    'shares', (select jsonb_object_agg(q.k, q.v) from (select m.job_key || case when count(*) over (partition by m.job_key) > 1 then '#' || row_number() over (partition by m.job_key order by m.joined_at) else '' end k,
        (public.world_gw_shares(fid) ->> m.owner_id::text)::numeric v from public.world_gw_members m where m.fight_id = fid) q),
    'plan_lvl', nullif(current_setting('yh.plan_lvl', true), '')::int,
    'ms', round(extract(epoch from clock_timestamp() - t0) * 1000));
  commit;
end $$;

create or replace function pg_temp.yh_gg_d(v int, tgt int, steps int) returns int language plpgsql immutable as $$
declare d int; v2 int; r int[];
begin
  foreach d in array array[1, 0, -5] loop
    v2 := least(9, greatest(0, v + d));
    if steps <= 1 then if v2 = tgt then return d; end if; continue; end if;
    r := public.world_ug_vreach(v2, array_fill(1023, array[steps - 1]));
    if r is not null and r[steps - 1] & (1 << tgt) <> 0 then return d; end if;
  end loop;
  return null;
end $$;

create or replace function pg_temp.yh_ug_extra(fid uuid, kd text, hz jsonb, nr int) returns jsonb language plpgsql as $$
declare f public.world_gw_fights%rowtype; h jsonb; r int; out jsonb := '[]'; n int; need int; pil jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  select count(*) into n from public.world_gw_members where fight_id = fid and out_rounds = 0 and not rest;
  pil := public.world_ux_cfg(fid) -> 'pillars';
  for h in select * from jsonb_array_elements(coalesce(hz, '[]'::jsonb)) loop
    continue when coalesce((h ->> 'wm')::boolean, false);
    r := nr + greatest(0, (h ->> 'left')::int);
    if kd = 'ux' and h ->> 'k' = 'vortex' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r, 'cells', '[1,2,3,4,5,6]'::jsonb, 'n', 1, 'a', 'brace'));
    elsif kd = 'ux' and h ->> 'k' = 'charge' and not public.world_ug_wm_on(fid) then
      out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r, 'cells', pil, 'n', 1, 'a', 'chain'));
    elsif kd = 'ux' and h ->> 'k' = 'name' and n >= 2 then
      out := out || jsonb_build_array(jsonb_build_object('t', 'adj', 'r', r, 'who', h ->> 't'));
    elsif kd = 'du' and h ->> 'k' = 'slide' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'avoid', 'r', r, 'cells', h -> 'cells'));
    elsif kd = 'dh' and h ->> 'k' = 'whirl' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'avoid', 'r', nr, 'cells', jsonb_build_array((h ->> 'c')::int)));
      if (h ->> 'life')::int > 1 and public.world_dh_step((h ->> 'c')::int, coalesce(f.board ->> 'dir', 'E')) is not null then
        out := out || jsonb_build_array(jsonb_build_object('t', 'avoid', 'r', nr + 1, 'cells', jsonb_build_array(public.world_dh_step((h ->> 'c')::int, coalesce(f.board ->> 'dir', 'E')))));
      end if;
    elsif kd = 'mk' and h ->> 'k' = 'mem' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r, 'cells', jsonb_build_array((h ->> 'c')::int), 'n', 1, 'a', 'recall'));
    elsif kd = 'mk' and h ->> 'k' = 'erase' then
      need := case when n <= 1 then 0 else ceil((n - 1) / 2.0)::int end;
      out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r, 'cells', '[5]'::jsonb, 'n', 1, 'a', 'guard'));
      if need > 0 then out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r, 'cells', '[1,2,3,4,5,6,7,8,9]'::jsonb, 'n', need, 'a', 'call')); end if;
    end if;
  end loop;
  if kd = 'du' then
    for h in select jsonb_build_object('c', k2::int, 'v', v2::int) from jsonb_each_text(coalesce(f.board -> 'holes', '{}'::jsonb)) q(k2, v2) loop
      for r in nr .. nr + least(5, (h ->> 'v')::int - 1) loop
        out := out || jsonb_build_array(jsonb_build_object('t', 'avoid', 'r', r, 'cells', jsonb_build_array((h ->> 'c')::int)));
      end loop;
    end loop;
  end if;
  return out;
end $$;

create or replace function pg_temp.yh_ug_plan(fid uuid) returns jsonb language plpgsql as $$
declare f public.world_gw_fights%rowtype; kd text; hz jsonb; nr int; base jsonb; ex jsonb; wc jsonb := '[]'; mem jsonb; sol jsonb; e jsonb; out jsonb := '{}'; lvl int := 0;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  kd := public.world_ug_wm_kind(f.boss_id); hz := public.world_ug_hz_of(f.board, kd); nr := f.round;
  base := public.world_ug_hz_cons(fid, hz, nr);
  ex := pg_temp.yh_ug_extra(fid, kd, hz, nr);
  if public.world_ug_wm_on(fid) then
    wc := coalesce(public.world_ug_wm_fit(fid, nr, hz), public.world_ug_wm_fit(fid, nr, hz, true), f.board -> 'wm' -> 'cons', '[]'::jsonb);
    wc := coalesce((select jsonb_agg(e2) from jsonb_array_elements(wc) e2 where (e2 ->> 'r')::int >= nr), '[]'::jsonb);
  end if;
  mem := public.world_ug_mem(fid);
  sol := public.world_ug_solve(kd, mem, nr, base || wc || ex, 1500);
  if sol is null then lvl := 1; sol := public.world_ug_solve(kd, mem, nr, base || wc, 1500); end if;
  if sol is null then lvl := 2; sol := public.world_ug_solve(kd, mem, nr, base, 1500); end if;
  if sol is null then return jsonb_build_object('_lvl', 3); end if;
  for e in select * from jsonb_array_elements(sol -> 'm') loop out := out || jsonb_build_object(e ->> 'id', e); end loop;
  return out || jsonb_build_object('_lvl', lvl);
end $$;

create or replace function pg_temp.yh_pick_ug(fid uuid, pol text) returns void language plpgsql as $$
declare f public.world_gw_fights%rowtype; kd text; plan jsonb; x public.world_gw_members; pm jsonb; mask int; c int; best int; bs numeric; s numeric; v_act text; ex jsonb;
  lamps int[]; nml uuid; called uuid[] := '{}'; nmpos int; face text; phys boolean; wm jsonb; tv int; stun boolean; lighting int[] := '{}'; hold int[]; d int; npos jsonb := '{}'; y record; cfg jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = fid;
  kd := public.world_ug_wm_kind(f.boss_id);
  if pol = 'ignore' then
    for x in select * from public.world_gw_members where fight_id = fid and out_rounds = 0 order by joined_at loop perform pg_temp.yh_set(fid, x, 'attack', null, null); end loop;
    return;
  end if;
  plan := pg_temp.yh_ug_plan(fid);
  perform set_config('yh.plan_lvl', greatest(coalesce(nullif(current_setting('yh.plan_lvl', true), '')::int, 0), (plan ->> '_lvl')::int)::text, false);
  if kd = 'dh' then perform pg_temp.yh_pick_dh(fid, pol, plan); return; end if;
  if kd = 'du' then perform pg_temp.yh_pick_du(fid, pol, plan); return; end if;
  wm := case when public.world_ug_wm_on(fid) then f.board -> 'wm' end;
  lamps := array(select jsonb_array_elements_text(coalesce(f.board -> 'lamps', '[]'::jsonb))::int);
  face := case when wm ->> 'k' = 'sea' and f.board ? 'face' then f.board ->> 'face' when wm is null and f.mech ->> 'k' = 'face' then f.mech ->> 'face' end;
  for x in select * from public.world_gw_members where fight_id = fid and out_rounds = 0 order by nameless desc, joined_at loop
    pm := plan -> x.owner_id::text; mask := coalesce((pm ->> 'v0')::int, 0); ex := null;
    stun := coalesce((pm ->> 'stun')::boolean, false) or coalesce((f.board -> 'stun' ->> x.owner_id::text)::int = f.round, false);
    if stun then update public.world_gw_members set act = null where fight_id = fid and owner_id = x.owner_id; continue; end if;
    nml := (select owner_id from public.world_gw_members y2 where y2.fight_id = fid and y2.out_rounds = 0 and not y2.rest and y2.nameless and y2.owner_id <> x.owner_id order by joined_at limit 1);
    bs := -1e9; best := x.pos;
    foreach c in array array[x.pos] || pg_temp.yh_nb(kd, x.pos) loop
      continue when mask <> 0 and mask & (1 << (c - 1)) = 0;
      continue when kd = 'mk' and c <> x.pos and public.world_mk_held(fid, x.owner_id);
      s := case when c = x.pos then 0 else -0.5 end;
      if kd = 'by' and f.board ? 'wn' and not (pm ->> 'a' is not null) then
        s := s - 3 * coalesce((select min(pg_temp.yh_bfs('by', c, z)) from generate_series(1, 7) z where not z = any (lamps) and not z = any (lighting)), 0);
      end if;
      if kd = 'ux' and nml is not null then
        select coalesce((npos ->> nml::text)::int, pos) into nmpos from public.world_gw_members where fight_id = fid and owner_id = nml;
        s := s - 2 * abs(public.world_ux_dist(c, nmpos) - 1);
      end if;
      if s > bs then bs := s; best := c; end if;
    end loop;
    v_act := pm ->> 'a';
    if v_act like 'sweep:%' then ex := jsonb_build_object('c', split_part(v_act, ':', 2)); v_act := 'sweep'; end if;
    if v_act is null then
      v_act := 'attack';
      if kd = 'gg' then
        d := (pm ->> 'd')::int;
        if wm ->> 'k' = 'close' and wm -> 'plan' ? x.owner_id::text then
          tv := (wm -> 'plan' -> x.owner_id::text ->> 'v')::int;
          d := coalesce(pg_temp.yh_gg_d(coalesce(x.gval, 0), tv, (wm ->> 'end')::int - f.round + 1), d);
        end if;
        v_act := case d when 0 then 'guard' when -5 then 'deal' else 'attack' end;
      elsif kd = 'by' then
        if best <= 7 and not best = any (lamps) and not best = any (lighting) and (f.board ? 'wn' or wm is null) then v_act := 'light'; lighting := lighting || best;
        elsif f.board ? 'wn' then v_act := 'guard'; end if;
      elsif kd = 'ux' then
        if nml is not null and not nml = any (called) and not (wm ->> 'k' = 'sea' and f.round - (wm ->> 'start')::int between 1 and jsonb_array_length(wm -> 'faces'))
           and public.world_ux_dist(best, (select coalesce((npos ->> nml::text)::int, pos) from public.world_gw_members where fight_id = fid and owner_id = nml)) = 1 then
          v_act := 'call'; ex := jsonb_build_object('t', nml); called := called || nml;
        end if;
      end if;
      if v_act = 'attack' and face is not null then
        phys := coalesce(x.stats ->> 'style', 'melee') in ('melee', 'ranged');
        if (face = 'human') <> phys then v_act := 'guard'; elsif wm ->> 'k' = 'sea' then ex := coalesce(ex, '{}'::jsonb) || '{"_nosup": true}'::jsonb; end if;
      end if;
      if v_act = 'attack' and x.nameless and kd = 'ux' then v_act := 'guard'; end if;
      if v_act = 'attack' and wm ->> 'k' = 'seal9' then ex := coalesce(ex, '{}'::jsonb) || '{"_nosup": true}'::jsonb; end if;
    elsif v_act = 'call' and kd = 'mk' then ex := jsonb_build_object('t', x.owner_id);
    end if;
    npos := npos || jsonb_build_object(x.owner_id::text, best);
    if pol = 'real' and random() < 0.12 then best := (array[x.pos] || pg_temp.yh_nb(kd, x.pos))[1 + floor(random() * (1 + cardinality(pg_temp.yh_nb(kd, x.pos))))::int]; v_act := 'attack'; ex := null; end if;
    if v_act in ('guard', 'brace', 'call', 'chain', 'recall', 'deal', 'light', 'sweep', 'guide', 'stop') then
      update public.world_gw_members set act = jsonb_build_object('a', v_act) || coalesce(ex, '{}'::jsonb) || case when best is distinct from x.pos then jsonb_build_object('m', best) else '{}'::jsonb end, rest = false
       where fight_id = fid and owner_id = x.owner_id;
    else
      perform pg_temp.yh_set(fid, x, v_act, best, ex);
    end if;
  end loop;
end $$;
