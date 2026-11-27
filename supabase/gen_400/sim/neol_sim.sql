create or replace function public.yh_now() returns timestamptz language sql stable set search_path to 'pg_catalog'
as $f$ select coalesce(nullif(current_setting('yh.now', true), '')::timestamptz, now()) $f$;

do $$ declare f record; d text; begin
  for f in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace
             and (p.proname like 'world_raid%' or p.proname like 'world_neol%' or p.proname in ('world_rate_check', 'world_shadow_pres')) and p.prokind = 'f' loop
    d := pg_get_functiondef(f.oid);
    if position('now()' in d) > 0 and position('yh_now()' in d) = 0 then execute replace(replace(d, 'now()', 'public.yh_now()'), 'public.public.yh_now()', 'public.yh_now()'); end if;
  end loop;
end $$;

create table if not exists public.yh_sim_chars(idx int primary key, owner_id uuid not null, job text not null);
create table if not exists public.yh_sim_runs(id serial primary key, boss text, n int, policy text, seed numeric, won boolean, secs numeric, hp_left numeric, falls int, info jsonb, log_md5 text);

create or replace function public.yh_sim_gear(u uuid, j text, p_lv int, p_tier int, p_enh int) returns void language plpgsql as $f$
declare base jsonb; pri text[]; pts int; cap int; k text; give int; s jsonb; best_v numeric; best_i text; sl text; cand text; v numeric;
begin
  base := public.world_job_base(j);
  pri := case when j in ('artificer', 'bloodknight', 'analyst', 'spearman') then array['strength', 'vitality', 'agility']
              when j in ('scout', 'tamer') then array['agility', 'perception', 'vitality']
              else array['spirit_affinity', 'willpower', 'vitality'] end;
  update public.world_characters set job_key = j, level = p_lv, strength = (base ->> 'strength')::int, agility = (base ->> 'agility')::int, vitality = (base ->> 'vitality')::int,
    perception = (base ->> 'perception')::int, willpower = (base ->> 'willpower')::int, spirit_affinity = (base ->> 'spirit_affinity')::int, stat_points = 0,
    skill_progress = coalesce(skill_progress, '{}') || jsonb_build_object(public.world_job_line(j), jsonb_build_object('xp', 30940, 'rank', 50), 'first_aid', jsonb_build_object('xp', 11670, 'rank', 40)),
    downed_at = null, health = 100, spiritual_power = 100, mental = 100, erosion = 0, travel_destination = null, is_dead = false
   where owner_id = u;
  pts := 3 * (p_lv - 1);
  foreach k in array pri loop
    cap := public.world_stat_cap_of(j, k, p_lv);
    execute format('select %I from public.world_characters where owner_id = $1', k) into give using u;
    give := least(pts, greatest(0, cap - give));
    execute format('update public.world_characters set %I = %I + $1 where owner_id = $2', k, k) using give, u;
    pts := pts - give;
  end loop;
  delete from public.world_idle_activities where owner_id = u and status = 'active';
  delete from public.world_expeditions where owner_id = u and status = 'active';
  delete from public.world_active_encounters where owner_id = u;
  delete from public.world_character_statuses where owner_id = u;
  delete from public.world_character_equipment where owner_id = u;
  delete from public.world_gear_enhance where owner_id = u;
  foreach sl in array array['weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask'] loop
    best_v := -1; best_i := null;
    for cand in select item_id from public.world_item_catalog where tier = p_tier and category = sl and base_item_id is null and item_id not like 'raid2%'
                  and (sl <> 'weapon' or equipment_traits -> 'jobs' ? j) loop
      delete from public.world_character_equipment where owner_id = u and world_character_equipment.slot = sl;
      insert into public.world_character_equipment(owner_id, slot, item_id) values (u, sl, cand);
      if sl = 'weapon' then insert into public.world_gear_enhance(owner_id, item_id, level) values (u, cand, p_enh) on conflict do nothing; end if;
      s := public.world_combat_stats(u, null);
      v := (s ->> 'attack')::numeric + (s ->> 'crit_pct')::numeric * 2 + (s ->> 'defense')::numeric * case when j in ('artificer', 'bloodknight') then 0.6 else 0.05 end;
      if v > best_v then best_v := v; best_i := cand; end if;
    end loop;
    delete from public.world_character_equipment where owner_id = u and world_character_equipment.slot = sl;
    if best_i is not null then insert into public.world_character_equipment(owner_id, slot, item_id) values (u, sl, best_i); end if;
  end loop;
  update public.world_characters set inventory = jsonb_build_object('banyo_salve', 40, 'heavenly_dew', 40, 'ammo_arrow', 300, 'ammo_dart', 300) where owner_id = u;
end $f$;

create or replace function public.yh_sim_as(u uuid) returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
end $f$;

create or replace function public.yh_sim_try(u uuid, p_raid uuid, p_act text, p_skill text default null, p_tgt uuid default null, p_item text default null) returns boolean language plpgsql as $f$
begin
  perform public.yh_sim_as(u);
  perform public.world_raid_action(p_raid, p_act, p_skill, p_tgt, p_item);
  return true;
exception when others then return false;
end $f$;

create or replace function public.yh_sim_fight(p_boss text, p_jobs text[], p_policy text, p_seed numeric, p_cap int default 7200, p_region text default null, p_t0 timestamptz default '2026-12-01 13:00+09', p_start numeric default 100)
 returns jsonb language plpgsql as $f$
declare rid uuid; reg text; rname text; t numeric := 0; i int; n int := array_length(p_jobs, 1); u uuid[]; nxt numeric[]; rd public.world_raids%rowtype; m record;
  fx jsonb; mf jsonb; hp int; job text; a text; sk text; tg uuid; ok boolean; follow boolean; tanks text[] := array['artificer', 'bloodknight']; heal_tgt uuid; low int;
  ph text; cs record; outu timestamptz; guard_n int; tot_falls int; sp int; itm text; must text;
  late_n int := coalesce(nullif(split_part(current_setting('yh.sim_late', true), ':', 1), '')::int, 0); late_t numeric := coalesce(nullif(split_part(current_setting('yh.sim_late', true), ':', 2), '')::numeric, 0);
begin
  perform setseed(p_seed);
  reg := coalesce(p_region, case when p_boss = 'neol' then 'pd_shore' else 'field_outskirts' end);
  select region_name into rname from public.world_map_regions where region_id = reg;
  u := array(select owner_id from public.yh_sim_chars order by idx limit n);
  for i in 1 .. n loop
    perform public.yh_sim_gear(u[i], p_jobs[i], 55, 9, 5);
    update public.world_characters set location = rname, health = 100, spiritual_power = 100, inventory = jsonb_build_object('banyo_salve', 40, 'heavenly_dew', 40, 'ammo_arrow', 300, 'ammo_dart', 300) where owner_id = u[i];
  end loop;
  perform set_config('yh.now', p_t0::text, true);
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'world_raids' and column_name = 'boss_key') then
    execute 'insert into public.world_raids(kind, boss_key, boss_name, region_id, status, signup_until, spawn_at) values (''world'', $1, $2, $3, ''signup'', $4, $5) returning raid_id'
      into rid using p_boss, case when p_boss = 'neol' then '엉긴 너울' else '사슬 벗은 그림자' end, reg, p_t0 + interval '1 second', p_t0;
  else
    insert into public.world_raids(kind, boss_name, region_id, status, signup_until, spawn_at)
    values ('world', '사슬 벗은 그림자', reg, 'signup', p_t0 + interval '1 second', p_t0) returning raid_id into rid;
  end if;
  for i in 1 .. n - late_n loop perform public.yh_sim_as(u[i]); perform public.world_raid_join(rid); end loop;
  perform set_config('yh.now', (p_t0 + interval '2 seconds')::text, true);
  perform public.world_raid_begin_fight(rid);
  update public.world_raids set hp = round(max_hp * p_start / 100.0) where raid_id = rid;
  nxt := array(select case when g > n - late_n then late_t + random() * 1.2 else 0.1 + random() * 1.2 end from generate_series(1, n) g);
  while t < p_cap loop
    t := t + 0.25;
    perform set_config('yh.now', (p_t0 + interval '2 seconds' + make_interval(secs => t))::text, true);
    for i in 1 .. n loop
      continue when nxt[i] > t;
      if i > n - late_n and not exists (select 1 from public.world_raid_members x where x.raid_id = rid and x.owner_id = u[i]) then perform public.yh_sim_as(u[i]); perform public.world_raid_join(rid); end if;
      nxt[i] := t + 1.05 + random() * 0.5;
      select * into rd from public.world_raids where raid_id = rid;
      exit when rd.status <> 'fight';
      fx := rd.fx; job := p_jobs[i];
      select x.fx, x.out_until into mf, outu from public.world_raid_members x where x.raid_id = rid and x.owner_id = u[i];
      select health, spiritual_power into hp, sp from public.world_characters where owner_id = u[i];
      if outu is not null and outu > public.yh_now() then
        if hp < 60 then perform public.yh_sim_as(u[i]); begin perform public.world_use_item('banyo_salve'); exception when others then null; end; end if;
        continue;
      end if;
      follow := case p_policy when 'best' then true when 'half' then random() < 0.5 else false end;
      a := 'attack'; sk := null; tg := null; itm := 'banyo_salve'; must := null;
      if follow then
        if fx ? 'nt' and fx -> 'nt' ->> 's' = 'tell' then must := 'guard';
        elsif fx ? 'nt' and fx -> 'nt' ->> 's' = 'ebb' then must := 'attack';
        elsif fx ? 'nw' and (job = any (tanks) or (fx -> 'nw' ->> 'tgt')::uuid = u[i] or i % 3 = 0) then must := 'guard';
        elsif exists (select 1 from public.world_raid_members b where b.raid_id = rid and b.fx ? 'brand')
          and (job = any (tanks) or u[i] = (select b.owner_id from public.world_raid_members b join public.world_characters c2 on c2.owner_id = b.owner_id
              where b.raid_id = rid and b.out_until is null and b.left_at is null and c2.health > 1 order by public.world_shadow_pres('world', b.job_key, b.stats, b.fx) desc limit 1)) then must := 'guard';
        elsif exists (select 1 from public.world_raid_members b where b.raid_id = rid and b.fx ? 'grip') and (job = any (tanks) or job = 'medic')
          and public.yh_sim_try(u[i], rid, 'coop', case job when 'artificer' then 'exo_guardian' when 'bloodknight' then 'bk_undying' else 'med_needle' end,
                (select b.owner_id from public.world_raid_members b where b.raid_id = rid and b.fx ? 'grip' limit 1)) then continue;
        elsif mf ? 'dry' and hp < 90 and job <> 'medic' then must := 'item';
        end if;
      end if;
      if must is not null and hp >= 25 then
        ok := case when must = 'item' then public.yh_sim_try(u[i], rid, 'item', null, null, itm) else public.yh_sim_try(u[i], rid, must) end;
        if not ok and must = 'item' then ok := public.yh_sim_try(u[i], rid, 'attack'); end if;
        if not ok and must = 'attack' then ok := public.yh_sim_try(u[i], rid, 'item', null, null, itm); end if;
        continue;
      end if;
      if hp < 50 then a := 'item';
      elsif sp < 16 then a := 'item'; itm := 'heavenly_dew';
      elsif job = 'medic' then
        select x.owner_id, ch.health into heal_tgt, low from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id
         where x.raid_id = rid and x.out_until is null and ch.health > 1 and (ch.health < 75 or (follow and x.fx ? 'dry' and ch.health < 90))
         order by (x.fx ? 'dry') desc, ch.health limit 1;
        if heal_tgt is not null then
          if (select count(*) from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id where x.raid_id = rid and x.out_until is null and ch.health < 70) >= 3
             and public.yh_sim_try(u[i], rid, 'coop', 'med_pulse') then continue; end if;
          if public.yh_sim_try(u[i], rid, 'coop', 'med_aid', heal_tgt) then continue; end if;
          if public.yh_sim_try(u[i], rid, 'coop', 'med_needle', heal_tgt) then continue; end if;
        end if;
      elsif job = 'formation' then
        select x.owner_id into heal_tgt from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id
         where x.raid_id = rid and x.out_until is null and ch.health > 1 order by (x.fx ? 'nw') desc, (x.job_key = any (tanks)) desc, ch.health limit 1;
        if public.yh_sim_try(u[i], rid, 'coop', 'fm_nine') then continue; end if;
        if random() < 0.5 and public.yh_sim_try(u[i], rid, 'coop', 'fm_point', heal_tgt) then continue; end if;
      end if;
      if a = 'attack' and follow then
        if fx ? 'nt' and fx -> 'nt' ->> 's' = 'tell' then a := 'guard';
        elsif fx ? 'nt' and fx -> 'nt' ->> 's' = 'ebb' then a := 'attack';
        elsif fx ? 'nw' and (job = any (tanks) or (fx -> 'nw' ->> 'tgt')::uuid = u[i] or i % 3 = 0) then a := 'guard';
        elsif job = any (tanks) and exists (select 1 from public.world_raid_members b where b.raid_id = rid and b.fx ? 'brand') then a := 'guard';
        elsif fx ? 'nc' then a := 'attack';
        elsif fx ? 'charge' then a := 'attack';
        elsif rd.intent like '크게 휘두를%' then a := 'guard';
        elsif mf ? 'dry' and hp < 90 and job <> 'medic' and random() < 0.3 then a := 'item';
        end if;
      end if;
      if a = 'item' then ok := public.yh_sim_try(u[i], rid, 'item', null, null, itm); if not ok then ok := public.yh_sim_try(u[i], rid, case when fx -> 'nt' ->> 's' = 'ebb' then 'attack' else 'guard' end); end if;
      else ok := public.yh_sim_try(u[i], rid, a); end if;
    end loop;
    select * into rd from public.world_raids where raid_id = rid;
    exit when rd.status <> 'fight';
  end loop;
  select * into rd from public.world_raids where raid_id = rid;
  if rd.status = 'fight' then perform public.world_raid_settle(rid, false); select * into rd from public.world_raids where raid_id = rid; end if;
  select coalesce(sum(falls), 0) into tot_falls from public.world_raid_members where raid_id = rid;
  insert into public.yh_sim_runs(boss, n, policy, seed, won, secs, hp_left, falls, info, log_md5)
  values (p_boss, n, p_policy, p_seed, rd.status = 'won', t, round(rd.hp * 100.0 / greatest(1, rd.max_hp), 1), tot_falls,
    jsonb_build_object('start', p_start, 'late', late_n, 'late_t', late_t, 'rate_min', round((p_start - rd.hp * 100.0 / greatest(1, rd.max_hp)) / greatest(1, t) * 60, 3), 'max_hp', rd.max_hp, 'phase', rd.phase, 'shares', (select jsonb_object_agg(x.job_key, round(x.contrib, 1)) from public.world_raid_members x where x.raid_id = rid),
      'nc', (select jsonb_agg(x.fx -> 'ncnt') from public.world_raid_members x where x.raid_id = rid), 'stiff', (select count(*) from public.world_raid_members x where x.raid_id = rid and x.fx ? 'stiff'),
      'miss', (select jsonb_build_object(
        'regrow', count(*) filter (where l.text like '수법을 놓친 틈에%'),
        'burst', count(*) filter (where l.text like '%기운을 터뜨립니다%'),
        'core', count(*) filter (where l.text like '고임 심을 트지 못했습니다%'),
        'stiff', count(*) filter (where l.text like '%마른 몸이 굳었습니다%'),
        'ebb', count(*) filter (where l.text like '물이 거꾸로 되밀려 옵니다 — 방어하던%'),
        'alone', count(*) filter (where l.text like '고인 무게가 %(혼자 받음)%'),
        'brand', count(*) filter (where l.text like '검은 낙인이 %에게 내리꽂힙니다%'),
        'grip', count(*) filter (where l.text like '그림자 손아귀가 %움켜쥡니다%'),
        'grip_off', count(*) filter (where l.text like '%그림자 손아귀를 떼어 냈습니다%'),
        'charge_cut', count(*) filter (where l.text like '%기운 모으기가 끊겼습니다%'))
        from public.world_raid_log l where l.raid_id = rid)),
    (select md5(string_agg(l.kind || '|' || l.text, E'\n' order by l.id)) from public.world_raid_log l where l.raid_id = rid));
  return jsonb_build_object('won', rd.status = 'won', 'secs', t, 'hp', rd.hp, 'max', rd.max_hp, 'falls', tot_falls);
end $f$;
