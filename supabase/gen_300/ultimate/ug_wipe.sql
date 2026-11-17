do $$
declare r jsonb := public.world_boss_rules();
begin
  r := jsonb_set(r, '{gwiheo,ultimate,wm}', $j${
    "sealed_lord": {"k": "seal9", "name": "아홉 겹 봉인", "easy": ["drag"], "steps": 4, "charge_k": 0.5, "tries": 16, "budget": 800, "hand": 0.6},
    "gwiheo": {"k": "sea", "name": "귀허의 바다", "easy": ["tide"], "faces": 3, "tries": 16, "budget": 800, "hand": 0.6}}$j$::jsonb);
  r := jsonb_set(r, '{mukjeok,ultimate,wm}', $j${
    "mukjeok": {"k": "rewrite", "name": "다시 쓰는 명부", "easy": {"line": 1, "mimic": 1}, "cells": 3, "wait": 5, "tries": 24, "budget": 800, "hand": 0.6}}$j$::jsonb);
  r := jsonb_set(r, '{gapgwi,ultimate,wm}', $j${
    "gapgwi": {"k": "close", "name": "마감 결산", "easy": ["judge"], "stalls": 3, "rounds": 3, "tries": 16, "budget": 800, "hand": 0.6},
    "baekya": {"k": "dongji", "name": "동짓밤", "easy": ["arrow", "clock"], "lead": 2, "arrow_left": 2, "gap": [1.5, 1.5, 1], "slack": 1, "tries": 20, "budget": 800, "hand": 0.6}}$j$::jsonb);
  r := jsonb_set(r, '{gwiheo,ultimate,acts}', '[{"boss": "sealed_lord", "cuts": [9, 17, 23], "name": "구중 봉주", "rounds": 32}, {"boss": "gwiheo", "cuts": [15, 26, 36], "name": "귀허의 주인", "rounds": 45}]'::jsonb);
  r := jsonb_set(r, '{mukjeok,ultimate,acts}', '[{"boss": "mukjeok", "cuts": [10, 20, 30], "name": "먹그림자", "rounds": 42}]'::jsonb);
  r := jsonb_set(r, '{gapgwi,ultimate,acts}', '[{"boss": "gapgwi", "cuts": [13, 24, 32], "name": "값귀", "rounds": 39}, {"boss": "baekya", "cuts": [12, 23, 33], "name": "백야", "rounds": 47}]'::jsonb);
  
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
end $$;

create or replace function public.world_ug_wm_cfg(p_fight uuid)
 returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $f$ select public.world_ug_cfg(p_fight) -> 'wm' -> f.boss_id from public.world_gw_fights f where f.fight_id = p_fight and f.mode = 'ultimate' $f$;

create or replace function public.world_ug_wm_kind(p_boss text)
 returns text language sql immutable set search_path = ''
as $f$ select case p_boss when 'sealed_lord' then 'ux' when 'gwiheo' then 'ux' when 'mukjeok' then 'mk' when 'gapgwi' then 'gg' when 'baekya' then 'by' end $f$;

create or replace function public.world_ug_wm_on(p_fight uuid)
 returns boolean language sql stable security definer set search_path = pg_catalog, public
as $f$ select coalesce((select f.mode = 'ultimate' and f.board -> 'wm' ->> 'status' = 'on' from public.world_gw_fights f where f.fight_id = p_fight), false) $f$;

create or replace function public.world_ug_wm_hold(p_fight uuid)
 returns boolean language sql stable security definer set search_path = pg_catalog, public
as $f$ select coalesce((select f.mode = 'ultimate' and coalesce(f.board -> 'wm' ->> 'status', '') <> 'done' and public.world_ug_wm_cfg(p_fight) is not null
  from public.world_gw_fights f where f.fight_id = p_fight), false) $f$;

create or replace function public.world_ug_wm_easy_a(p_fight uuid)
 returns text[] language sql stable security definer set search_path = pg_catalog, public
as $f$ select case when public.world_ug_wm_on(p_fight) then array(select jsonb_array_elements_text(public.world_ug_wm_cfg(p_fight) -> 'easy')) end $f$;

create or replace function public.world_ug_wm_easy_j(p_fight uuid)
 returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $f$ select case when public.world_ug_wm_on(p_fight) then public.world_ug_wm_cfg(p_fight) -> 'easy' end $f$;

create or replace function public.world_ug_hz_of(p_board jsonb, p_kind text)
 returns jsonb language sql immutable set search_path = ''
as $f$ select coalesce(case when p_kind = 'ux' then p_board -> 'ux' -> 'hz' else p_board -> 'hz' end, '[]'::jsonb) $f$;

create or replace function public.world_ug_hz_cons(p_fight uuid, p_hz jsonb, p_nr integer)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; kd text; h jsonb; out jsonb := '[]'; r int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  kd := public.world_ug_wm_kind(f.boss_id);
  p_hz := (select coalesce(jsonb_agg(e - 'frozen'), '[]'::jsonb) from jsonb_array_elements(coalesce(p_hz, '[]'::jsonb)) e where not coalesce((e ->> 'wm')::boolean, false));
  if kd = 'gg' then return public.world_ug_gg_cons(p_fight, p_hz, p_nr); end if;
  if kd = 'by' then return public.world_ug_by_cons(p_fight, p_hz, p_nr, f.board); end if;
  for h in select * from jsonb_array_elements(coalesce(p_hz, '[]'::jsonb)) loop
    continue when coalesce((h ->> 'wm')::boolean, false);
    r := p_nr + greatest(0, (h ->> 'left')::int);
    if kd = 'ux' and h ->> 'k' in ('drag', 'tide', 'burst') then
      out := out || jsonb_build_array(jsonb_build_object('t', 'avoid', 'r', r, 'cells', coalesce(h -> 'cells', '[]'::jsonb)));
    elsif kd = 'mk' and h ->> 'k' in ('line', 'step') then
      out := out || jsonb_build_array(jsonb_build_object('t', 'avoid', 'r', r, 'cells', to_jsonb(public.world_ug_mk_cells(h))));
    elsif kd = 'mk' and h ->> 'k' = 'mimic' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'act', 'r', r, 'who', h ->> 't', 'a', 'guard'));
    end if;
  end loop;
  return out;
end $f$;

create or replace function public.world_ug_wm_solve(p_fight uuid, p_mem jsonb, p_nr integer, p_hz jsonb, p_cons jsonb)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  return public.world_ug_solve(public.world_ug_wm_kind(f.boss_id), p_mem, p_nr,
    public.world_ug_hz_cons(p_fight, p_hz, p_nr) || coalesce((select jsonb_agg(e) from jsonb_array_elements(coalesce(p_cons, '[]'::jsonb)) e where (e ->> 'r')::int >= p_nr), '[]'::jsonb),
    coalesce((public.world_ug_wm_cfg(p_fight) ->> 'budget')::int, 800));
end $f$;

create or replace function public.world_ug_wm_mem(p_fight uuid, p_pos jsonb)
 returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $f$ select coalesce(jsonb_agg(e || case when p_pos ? (e ->> 'id') then jsonb_build_object('pos', (p_pos ->> (e ->> 'id'))::int) else '{}'::jsonb end), '[]'::jsonb)
  from jsonb_array_elements(public.world_ug_mem(p_fight)) e $f$;

create or replace function public.world_ug_wm_dj_cons(p_fight uuid, p_wm jsonb, p_nr integer, p_base integer, p_g numeric)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare cfg jsonb := public.world_ug_wm_cfg(p_fight); out jsonb := '[]'; lit int := (p_wm ->> 'lit')::int; j int; r int; c int; own text; e jsonb; al int := coalesce((cfg ->> 'arrow_left')::int, 2);
begin
  for j in lit + 1 .. 7 loop
    r := case when p_g is null then (p_wm -> 'sched' ->> (j - 1))::int else p_base + ceil((j - lit - 1) * p_g)::int end;
    if r < p_nr or r > coalesce((p_wm -> 'sched' ->> (j - 1))::int, (p_wm ->> 'dl')::int) then return null; end if;
    c := (p_wm -> 'seq' ->> (j - 1))::int; own := p_wm -> 'own' ->> c::text;
    if exists (select 1 from public.world_gw_members m where m.fight_id = p_fight and m.owner_id::text = own and m.out_rounds = 0 and not m.rest) then
      out := out || jsonb_build_array(jsonb_build_object('t', 'goal', 'r', r, 'who', own, 'cells', jsonb_build_array(c)), jsonb_build_object('t', 'act', 'r', r, 'who', own, 'a', 'light'));
    else
      out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r, 'cells', jsonb_build_array(c), 'n', 1, 'a', 'light'));
    end if;
    if j < 7 then out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r + al, 'cells', to_jsonb(array[c] || public.world_by_nb(c)), 'n', 1, 'a', 'sweep:' || c)); end if;
  end loop;
  for e in select * from jsonb_array_elements(coalesce(p_wm -> 'arrows', '[]'::jsonb)) loop
    continue when (e ->> 'r')::int < p_nr;
    out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', (e ->> 'r')::int, 'cells', to_jsonb(array[(e ->> 'c')::int] || public.world_by_nb((e ->> 'c')::int)), 'n', 1, 'a', 'sweep:' || (e ->> 'c')));
  end loop;
  return out;
end $f$;

create or replace function public.world_ug_wm_fit(p_fight uuid, p_nr integer, p_hz jsonb, p_relax boolean default false)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; wm jsonb; b int; g numeric; c jsonb; mem jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  wm := f.board -> 'wm'; mem := public.world_ug_mem(p_fight);
  if wm is null then return null; end if;
  if wm ->> 'k' = 'rewrite' then
    c := coalesce((select jsonb_agg(e) from jsonb_array_elements(wm -> 'cons') e where e ->> 'a' is distinct from 'call'), '[]'::jsonb);
    if jsonb_array_length(mem) > 2 then
      c := c || coalesce((select jsonb_agg(jsonb_build_object('t', 'need', 'r', (z)::int, 'cells', '[1, 2, 3, 4, 5, 6, 7, 8, 9]'::jsonb, 'n', jsonb_array_length(mem) - 2, 'a', 'call'))
        from jsonb_array_elements_text(wm -> 'steps') z), '[]'::jsonb);
    end if;
    return case when public.world_ug_wm_solve(p_fight, mem, p_nr, p_hz, c) is not null then c end;
  end if;
  if wm ->> 'k' <> 'dongji' then
    return case when public.world_ug_wm_solve(p_fight, mem, p_nr, p_hz, wm -> 'cons') is not null then coalesce(wm -> 'cons', '[]'::jsonb) end;
  end if;
  if not p_relax then
    c := public.world_ug_wm_dj_cons(p_fight, wm, p_nr, null, null);
    return case when c is not null and public.world_ug_wm_solve(p_fight, mem, p_nr, p_hz, c) is not null then c end;
  end if;
  wm := wm - 'sched';
  for b in 0 .. 2 loop
    foreach g in array array[1, 1.5, 2]::numeric[] loop
      c := public.world_ug_wm_dj_cons(p_fight, wm, p_nr, p_nr + b, g);
      continue when c is null;
      if public.world_ug_wm_solve(p_fight, mem, p_nr, p_hz, c) is not null then return c; end if;
    end loop;
  end loop;
  return null;
end $f$;

create or replace function public.world_ug_wm_start(p_fight uuid, p_nr integer)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; cfg jsonb := public.world_ug_wm_cfg(p_fight); kd text; alive uuid[]; na int; t int; i int; k int; c int; v_pos jsonb; cons jsonb; ok jsonb;
  pil int[] := array[7, 9, 13, 15]; ord int[]; asg int[]; x record; need int; tg uuid; faces text[]; phys boolean; mag boolean; cells int[]; stalls int[]; tv int; v int; vr int[]; tt jsonb;
  plan jsonb; seq int[]; s0 int; dir int; rk int[]; own jsonb; lead int; al int; nb int[]; g numeric; wm jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  kd := public.world_ug_wm_kind(f.boss_id);
  alive := array(select owner_id from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest order by random());
  na := coalesce(array_length(alive, 1), 0);
  if na < 2 then return null; end if;
  for t in 1 .. coalesce((cfg ->> 'tries')::int, 12) loop
    v_pos := '{}'; cons := '[]';
    if cfg ->> 'k' = 'seal9' then
      ord := array(select z from unnest(pil) z order by random());
      asg := array(select z from unnest(pil) z order by random());
      for i in 1 .. least(na, 4) loop v_pos := v_pos || jsonb_build_object(alive[i]::text, asg[i]); end loop;
      for i in 1 .. 4 loop cons := cons || jsonb_build_array(jsonb_build_object('t', 'need', 'r', p_nr + i, 'cells', jsonb_build_array(ord[i]), 'n', 1, 'a', 'chain')); end loop;
      ok := public.world_ug_wm_solve(p_fight, public.world_ug_wm_mem(p_fight, v_pos), p_nr, '[]'::jsonb, cons);
      if ok is not null then
        select round(coalesce((cfg ->> 'charge_k')::numeric, 0.8) * (sum((stats ->> 'attack')::numeric) - max((stats ->> 'attack')::numeric))) into need
          from public.world_gw_members where fight_id = p_fight and owner_id = any (alive);
        return jsonb_build_object('k', 'seal9', 'status', 'on', 'start', p_nr, 'ord', to_jsonb(ord), 'pos', v_pos, 'cons', cons, 'need', greatest(1, need), 'end', p_nr + 4);
      end if;
    elsif cfg ->> 'k' = 'sea' then
      tg := alive[1 + (t - 1) % na];
      select bool_or(coalesce(stats ->> 'style', 'melee') in ('melee', 'ranged')), bool_or(coalesce(stats ->> 'style', 'melee') not in ('melee', 'ranged')) into phys, mag
        from public.world_gw_members where fight_id = p_fight and owner_id = any (alive) and owner_id <> tg;
      faces := '{}';
      for i in 1 .. coalesce((cfg ->> 'faces')::int, 3) loop
        faces := faces || case when phys and mag then case when random() < 0.5 then 'human' else 'yokai' end when phys then 'human' else 'yokai' end;
      end loop;
      for x in select owner_id, pos from public.world_gw_members where fight_id = p_fight and owner_id = any (alive) loop
        v_pos := v_pos || jsonb_build_object(x.owner_id::text, coalesce(public.world_ux_at(-public.world_ux_q(x.pos), -public.world_ux_r(x.pos)), x.pos));
      end loop;
      cons := jsonb_build_array(jsonb_build_object('t', 'goal', 'r', p_nr + 4, 'who', tg::text, 'cells', '[1, 2, 3, 4, 5, 6]'::jsonb),
        jsonb_build_object('t', 'act', 'r', p_nr + 4, 'who', tg::text, 'a', 'brace'),
        jsonb_build_object('t', 'adj', 'r', p_nr + 4, 'who', tg::text));
      ok := public.world_ug_wm_solve(p_fight, public.world_ug_wm_mem(p_fight, v_pos), p_nr, '[]'::jsonb, cons);
      if ok is not null then
        return jsonb_build_object('k', 'sea', 'status', 'on', 'start', p_nr, 'faces', to_jsonb(faces), 't', tg, 'pos', v_pos, 'cons', cons, 'end', p_nr + 4);
      end if;
    elsif cfg ->> 'k' = 'rewrite' then
      cells := array(select z from unnest(array[1, 2, 3, 4, 6, 7, 8, 9]) z order by random() limit coalesce((cfg ->> 'cells')::int, 3));
      rk := '{}';
      for i in 1 .. cardinality(cells) loop
        k := p_nr + coalesce((cfg ->> 'wait')::int, 5) + i - 1; rk := rk || k;
        cons := cons || jsonb_build_array(jsonb_build_object('t', 'need', 'r', k, 'cells', jsonb_build_array(cells[i]), 'n', 1, 'a', 'recall'),
          jsonb_build_object('t', 'need', 'r', k, 'cells', '[5]'::jsonb, 'n', 1, 'a', 'guard'));
        if na > 2 then cons := cons || jsonb_build_array(jsonb_build_object('t', 'need', 'r', k, 'cells', '[1, 2, 3, 4, 5, 6, 7, 8, 9]'::jsonb, 'n', na - 2, 'a', 'call')); end if;
      end loop;
      ok := public.world_ug_wm_solve(p_fight, public.world_ug_mem(p_fight), p_nr, '[]'::jsonb, cons);
      if ok is not null then
        return jsonb_build_object('k', 'rewrite', 'status', 'on', 'start', p_nr, 'cells', to_jsonb(cells), 'steps', to_jsonb(rk), 'cons', cons, 'end', rk[cardinality(rk)]);
      end if;
    elsif cfg ->> 'k' = 'close' then
      k := least(coalesce((cfg ->> 'stalls')::int, 3), na);
      stalls := array(select z from unnest(array[1, 2, 3, 4, 5, 11, 12, 13, 14, 15]) z order by random() limit k);
      tt := '{}'; plan := '{}';
      al := p_nr + coalesce((cfg ->> 'rounds')::int, 3) - 1;
      for i in 1 .. na loop
        c := stalls[1 + (i - 1) % k];
        v := floor(random() * 10)::int;
        vr := public.world_ug_vreach(v, array_fill(1023, array[al - p_nr + 1]));
        select z into tv from generate_series(0, 9) z where vr[cardinality(vr)] & (1 << z) <> 0 order by random() limit 1;
        plan := plan || jsonb_build_object(alive[i]::text, jsonb_build_object('c', c, 'v0', v, 'v', tv));
        tt := tt || jsonb_build_object(c::text, coalesce((tt ->> c::text)::int, 0) + tv);
        cons := cons || jsonb_build_array(jsonb_build_object('t', 'goal', 'r', al, 'who', alive[i]::text, 'cells', jsonb_build_array(c)));
      end loop;
      ok := public.world_ug_wm_solve(p_fight, public.world_ug_mem(p_fight), p_nr, '[]'::jsonb, cons);
      if ok is not null then
        return jsonb_build_object('k', 'close', 'status', 'on', 'start', p_nr, 'stalls', (select jsonb_agg(jsonb_build_object('c', z, 't', (tt ->> z::text)::int) order by z) from unnest(stalls) z),
          'plan', plan, 'cons', cons, 'end', al);
      end if;
    elsif cfg ->> 'k' = 'dongji' then
      s0 := 1 + floor(random() * 7)::int; dir := case when random() < 0.5 then 1 else -1 end; lead := coalesce((cfg ->> 'lead')::int, 2);
      seq := array(select 1 + ((s0 - 1 + dir * (q - 1) + 70) % 7) from generate_series(1, 7) q);
      own := '{}';
      for i in 1 .. 7 loop own := own || jsonb_build_object(seq[i]::text, alive[1 + (i - 1) % na]::text); end loop;
      g := coalesce((cfg -> 'gap' ->> (least(4, na) - 2))::numeric, 1);
      wm := jsonb_build_object('k', 'dongji', 'status', 'on', 'start', p_nr, 'seq', to_jsonb(seq), 'own', own, 'lit', 0, 'arrows', '[]'::jsonb,
        'sched', (select jsonb_agg(p_nr + lead + ceil((q - 1) * g)::int order by q) from generate_series(1, 7) q),
        'dl', p_nr + lead + ceil(6 * g)::int + coalesce((cfg ->> 'slack')::int, 1));
      cons := public.world_ug_wm_dj_cons(p_fight, wm, p_nr, p_nr + lead, g);
      ok := public.world_ug_wm_solve(p_fight, public.world_ug_mem(p_fight), p_nr, '[]'::jsonb, cons);
      if ok is not null then
        return wm || jsonb_build_object('cons', cons, 'end', (wm ->> 'dl')::int + coalesce((cfg ->> 'arrow_left')::int, 2));
      end if;
    end if;
  end loop;
  return null;
end $f$;

create or replace function public.world_ug_wm_pre(p_fight uuid, p_nr integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; cfg jsonb := public.world_ug_wm_cfg(p_fight); wm jsonb; kd text; b jsonb; x record; e text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if cfg is null or f.board ? 'wm' or f.hp * 4 > f.max_hp then return; end if;
  wm := public.world_ug_wm_start(p_fight, p_nr);
  if wm is null then return; end if;
  kd := public.world_ug_wm_kind(f.boss_id); b := f.board;
  if kd = 'ux' then
    b := jsonb_set(b, '{ux,hz}', '[]'::jsonb);
    update public.world_gw_members set nameless = false where fight_id = p_fight;
  else
    b := b || jsonb_build_object('hz', '[]'::jsonb);
  end if;
  if wm ? 'pos' then
    for e in select jsonb_object_keys(wm -> 'pos') loop
      update public.world_gw_members set prev = pos, pos = (wm -> 'pos' ->> e)::int where fight_id = p_fight and owner_id = e::uuid;
    end loop;
  end if;
  if wm ->> 'k' = 'sea' then
    update public.world_gw_members set nameless = true where fight_id = p_fight and owner_id = (wm ->> 't')::uuid;
    b := jsonb_set(b, '{ux,hid}', to_jsonb(coalesce((b -> 'ux' ->> 'hid')::int, 0) + 1));
    b := jsonb_set(b, '{ux,hz}', jsonb_build_array(jsonb_build_object('id', (b -> 'ux' ->> 'hid')::int, 'k', 'name', 't', wm ->> 't', 'left', 5, 'wm', true)));
  elsif wm ->> 'k' = 'close' then
    for e in select jsonb_object_keys(wm -> 'plan') loop
      update public.world_gw_members set gval = (wm -> 'plan' -> e ->> 'v0')::int where fight_id = p_fight and owner_id = e::uuid;
    end loop;
  elsif wm ->> 'k' = 'dongji' then
    b := b || jsonb_build_object('lamps', '[]'::jsonb);
  end if;
  update public.world_gw_fights set board = b || jsonb_build_object('wm', wm) where fight_id = p_fight;
  perform public.world_gw_say(p_fight, p_nr, 'wm', case wm ->> 'k'
    when 'seal9' then '봉주가 사슬을 한꺼번에 잡아당긴다. 모두가 저마다 다른 봉인 기둥으로 끌려가고, 기둥 넷에 번호가 잠깐 떠올랐다 꺼진다.'
    when 'sea' then '귀허의 바다가 뒤집혀 모두를 벌집 반대편으로 쓸어 간다. 주인의 두 얼굴이 차례로 바뀌는 모습이 잠깐 비쳤다 사라지고, 누군가의 이름이 물에 녹는다.'
    when 'rewrite' then '그림자가 명부를 처음부터 다시 쓰기 시작한다. 아홉 칸 가운데 세 칸이 차례로 깜빡였다 꺼진다.'
    when 'close' then '장 마감 종이 울린다. 모두의 값이 새로 매겨지고, 흰 좌판 위에 맞춰야 할 값이 적힌다.'
    else '일곱 등이 한꺼번에 꺼진다. 동짓밤 — 저마다의 손끝에 켜야 할 등 번호가 떠오른다.' end);
end $f$;

create or replace function public.world_ug_wm_post(p_fight uuid, p_nr integer, p_hid0 integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; cfg jsonb := public.world_ug_wm_cfg(p_fight); wm jsonb; kd text; hz jsonb; easy text[]; nw int[]; i int; ok jsonb; m jsonb; ar int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  wm := f.board -> 'wm';
  if wm is null or wm ->> 'status' <> 'on' then return; end if;
  kd := public.world_ug_wm_kind(f.boss_id);
  easy := case when jsonb_typeof(cfg -> 'easy') = 'object' then array(select jsonb_object_keys(cfg -> 'easy')) else array(select jsonb_array_elements_text(cfg -> 'easy')) end;
  hz := public.world_ug_hz_of(f.board, kd);
  hz := (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(hz) e where coalesce((e ->> 'wm')::boolean, false) or (e ->> 'id')::int <= p_hid0
    or (e ->> 'k' = any (easy) and not (kd = 'by' and e ->> 'k' = 'arrow' and not coalesce(f.board -> 'lamps', '[]'::jsonb) @> to_jsonb(public.world_by_sector((e ->> 'c')::int)))));
  nw := array(select (e ->> 'id')::int from jsonb_array_elements(hz) e where (e ->> 'id')::int > p_hid0 and not coalesce((e ->> 'wm')::boolean, false) order by (e ->> 'id')::int desc);
  ok := public.world_ug_wm_fit(p_fight, p_nr, hz);
  i := 1;
  while ok is null and i <= coalesce(cardinality(nw), 0) loop
    hz := (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(hz) e where (e ->> 'id')::int <> nw[i]);
    ok := public.world_ug_wm_fit(p_fight, p_nr, hz);
    i := i + 1;
  end loop;
  m := f.mech - 'tell' - 'cue';
  ar := p_nr - (wm ->> 'start')::int;
  if wm ->> 'k' = 'sea' and ar between 1 and jsonb_array_length(wm -> 'faces') then
    m := m || jsonb_build_object('k', 'face', 'face', wm -> 'faces' ->> (ar - 1), 'hide', true);
    update public.world_gw_fights set board = board || jsonb_build_object('face', wm -> 'faces' ->> (ar - 1)) where fight_id = p_fight;
  elsif wm ->> 'k' = 'sea' then
    m := (m - 'face') || jsonb_build_object('k', 'normal');
  end if;
  m := m || jsonb_build_object('aoe', false, 'due', coalesce((m ->> 'due')::boolean, false) or p_nr = (wm ->> 'end')::int, 'wm', wm ->> 'k');
  update public.world_gw_fights set mech = m,
    board = case when kd = 'ux' then jsonb_set(board, '{ux,hz}', hz) else board || jsonb_build_object('hz', hz) end,
    round_ends_at = now() + interval '10 seconds' where fight_id = p_fight;
end $f$;

create or replace function public.world_ug_wm_dmg(p_fight uuid, p_round integer, p_dmg numeric)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
begin
  update public.world_gw_fights set board = jsonb_set(board, '{wm,dmg}', to_jsonb(round(p_dmg))) where fight_id = p_fight and mode = 'ultimate' and board -> 'wm' ->> 'status' = 'on';
end $f$;

create or replace function public.world_ug_wm_fail(p_fight uuid, p_round integer, p_why text)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare nm text;
begin
  select coalesce(public.world_ug_wm_cfg(p_fight) ->> 'name', '전멸기') into nm;
  update public.world_gw_fights set board = jsonb_set(board, '{wm,status}', '"fail"') where fight_id = p_fight;
  perform public.world_ug_wipe(p_fight, p_round, '이야기꾼의 말로는 「' || nm || '」 앞에서 ' || p_why || ' —');
  return true;
end $f$;

create or replace function public.world_ug_wm_check(p_fight uuid, p_round integer)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; wm jsonb; i int; x record; ok boolean; wrong boolean; c int; n int; calls int; tgt uuid; face text; good int; bad int; st jsonb; sm int;
  own uuid; lit int[]; k int; nm text; cfg jsonb := public.world_ug_wm_cfg(p_fight);
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  wm := f.board -> 'wm';
  if wm is null or wm ->> 'status' <> 'on' then return false; end if;
  i := p_round - (wm ->> 'start')::int;
  if wm ->> 'k' = 'seal9' and i between 1 and 4 then
    c := (wm -> 'ord' ->> (i - 1))::int;
    wrong := exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'chain' and pos in (7, 9, 13, 15) and pos <> c);
    ok := exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'chain' and pos = c);
    if wrong then return public.world_ug_wm_fail(p_fight, p_round, '순서가 틀린 기둥의 사슬을 끊었다고 한다'); end if;
    if not ok then return public.world_ug_wm_fail(p_fight, p_round, i || '번째 기둥의 사슬을 제때 끊지 못했다고 한다'); end if;
    perform public.world_gw_say(p_fight, p_round, 'good', c || '번 기둥의 사슬이 끊어졌습니다(' || i || '/4).');
    if i = 4 then
      if coalesce((wm ->> 'dmg')::int, 0) < (wm ->> 'need')::int then
        return public.world_ug_wm_fail(p_fight, p_round, '마지막 사슬을 끊는 순간 봉주가 모은 기운을 꺾지 못했다고 한다(' || coalesce(wm ->> 'dmg', '0') || '/' || (wm ->> 'need') || ')');
      end if;
      perform public.world_gw_say(p_fight, p_round, 'good', '봉주가 모으던 기운이 흩어졌습니다(' || (wm ->> 'dmg') || '/' || (wm ->> 'need') || '). 아홉 겹 봉인이 다시 잠깁니다.');
      update public.world_gw_fights set board = jsonb_set(board, '{wm,status}', '"done"') where fight_id = p_fight;
    end if;
  elsif wm ->> 'k' = 'sea' and i between 1 and jsonb_array_length(wm -> 'faces') then
    face := wm -> 'faces' ->> (i - 1); good := 0; bad := 0;
    for x in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and not nameless
        and (act ->> 'a' = 'attack' or (act ->> 'a' = 'coop' and coalesce((select (s.effect ->> 'strike')::boolean from public.world_coop_skills s where s.skill_id = act ->> 's'), false))) loop
      if (face = 'human') = (coalesce(x.stats ->> 'style', 'melee') in ('melee', 'ranged')) then good := good + 1; else bad := bad + 1; end if;
    end loop;
    if bad > 0 then return public.world_ug_wm_fail(p_fight, p_round, '주인이 든 얼굴과 같은 쪽을 쳐 힘을 내주었다고 한다'); end if;
    if good = 0 then return public.world_ug_wm_fail(p_fight, p_round, '아무도 주인이 든 얼굴의 반대쪽을 치지 않았다고 한다'); end if;
    perform public.world_gw_say(p_fight, p_round, 'good', '바뀐 얼굴의 반대쪽을 쳤습니다(' || i || '/' || jsonb_array_length(wm -> 'faces') || ').');
  elsif wm ->> 'k' = 'sea' and i = jsonb_array_length(wm -> 'faces') + 1 then
    select * into x from public.world_gw_members where fight_id = p_fight and owner_id = (wm ->> 't')::uuid;
    if x.owner_id is null or x.out_rounds > 0 or x.rest or x.nameless or x.act ->> 'a' is distinct from 'brace' or not (x.pos between 1 and 6) then
      return public.world_ug_wm_fail(p_fight, p_round, '이름을 되찾은 이가 가운데 곁에서 소용돌이를 받아 내지 못했다고 한다');
    end if;
    perform public.world_gw_say(p_fight, p_round, 'good', x.name || ' — 되찾은 이름으로 귀허의 바다를 홀로 받아 냈습니다.');
    update public.world_gw_fights set board = jsonb_set(board, '{wm,status}', '"done"') where fight_id = p_fight;
  elsif wm ->> 'k' = 'rewrite' and wm -> 'steps' @> to_jsonb(p_round) then
    k := (select o from jsonb_array_elements_text(wm -> 'steps') with ordinality s(v, o) where v::int = p_round)::int;
    c := (wm -> 'cells' ->> (k - 1))::int;
    select count(*) into n from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
    if exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'recall' and pos is distinct from c) then
      return public.world_ug_wm_fail(p_fight, p_round, '깜빡였던 순서와 다른 칸을 되새겼다고 한다'); end if;
    select owner_id into tgt from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'recall' and pos = c limit 1;
    if tgt is null then return public.world_ug_wm_fail(p_fight, p_round, k || '번째 칸을 제때 되새기지 못했다고 한다'); end if;
    if not exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and pos = 5 and owner_id <> tgt and coalesce(act ->> 'a', 'guard') in ('guard', 'brace')) then
      return public.world_ug_wm_fail(p_fight, p_round, '가운데 칸을 지킨 사람이 없어 이름이 지워졌다고 한다'); end if;
    select count(*) into calls from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'call';
    if n < 2 or calls < n - 2 then return public.world_ug_wm_fail(p_fight, p_round, '이름을 불러 준 목소리가 모자랐다고 한다(' || calls || '/' || greatest(0, n - 2) || ')'); end if;
    perform public.world_gw_say(p_fight, p_round, 'good', public.world_mk_cell_name(c) || ' 칸을 되새기고 가운데 이름을 지켰습니다(' || k || '/' || jsonb_array_length(wm -> 'cells') || ').');
    if k = jsonb_array_length(wm -> 'cells') then
      perform public.world_gw_say(p_fight, p_round, 'good', '다시 쓰던 명부가 멈췄습니다. 그림자의 붓이 갈라집니다.');
      update public.world_gw_fights set board = jsonb_set(board, '{wm,status}', '"done"') where fight_id = p_fight;
    end if;
  elsif wm ->> 'k' = 'close' and p_round = (wm ->> 'end')::int then
    for st in select * from jsonb_array_elements(wm -> 'stalls') loop
      select coalesce(sum(gval), 0) into sm from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and pos = (st ->> 'c')::int;
      if sm <> (st ->> 't')::int then
        return public.world_ug_wm_fail(p_fight, p_round, (st ->> 'c') || '번 좌판의 값이 맞지 않았다고 한다(' || sm || '/' || (st ->> 't') || '섬)');
      end if;
    end loop;
    perform public.world_gw_say(p_fight, p_round, 'good', '마감 결산이 맞았습니다. 값귀의 주판이 멈춥니다.');
    update public.world_gw_fights set board = jsonb_set(board, '{wm,status}', '"done"') where fight_id = p_fight;
  elsif wm ->> 'k' = 'dongji' then
    for st in select * from jsonb_array_elements(coalesce(wm -> 'arrows', '[]'::jsonb)) loop
      continue when (st ->> 'r')::int <> p_round;
      c := (st ->> 'c')::int;
      if not exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'sweep' and act ->> 'c' = c::text
          and (pos = c or c = any (public.world_by_nb(pos)))) then
        return public.world_ug_wm_fail(p_fight, p_round, c || '번 등 바깥의 화살을 걷어 내지 못해 등이 다시 꺼졌다고 한다'); end if;
      perform public.world_gw_say(p_fight, p_round, 'good', c || '번 등 바깥의 화살을 걷어 냈습니다.');
    end loop;
    k := (wm ->> 'lit')::int;
    lit := array(select (wm -> 'seq' ->> q)::int from generate_series(0, k - 1) q);
    select count(distinct pos) into n from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'light' and pos <= 7 and not (pos = any (lit));
    if n > 1 then return public.world_ug_wm_fail(p_fight, p_round, '등 여럿을 한꺼번에 켜려 했다고 한다'); end if;
    if n = 1 then
      c := (wm -> 'seq' ->> k)::int;
      own := (wm -> 'own' ->> c::text)::uuid;
      if exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'light' and pos <= 7 and pos <> c and not (pos = any (lit))) then
        return public.world_ug_wm_fail(p_fight, p_round, '차례가 아닌 등을 먼저 켰다고 한다'); end if;
      if not exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'light' and y.pos = c
          and (y.owner_id = own or not exists (select 1 from public.world_gw_members z where z.fight_id = p_fight and z.owner_id = own and z.out_rounds = 0 and not z.rest))) then
        return public.world_ug_wm_fail(p_fight, p_round, (k + 1) || '번째 등을 맡지 않은 이가 켰다고 한다'); end if;
      k := k + 1;
      perform public.world_gw_say(p_fight, p_round, 'good', c || '번 등이 차례대로 켜졌습니다(' || k || '/7).');
      wm := wm || jsonb_build_object('lit', k);
      if k < 7 then
        wm := wm || jsonb_build_object('arrows', coalesce(wm -> 'arrows', '[]'::jsonb) || jsonb_build_array(jsonb_build_object('c', c, 'r', p_round + coalesce((cfg ->> 'arrow_left')::int, 2))));
        update public.world_gw_fights set board = board || jsonb_build_object('hid', coalesce((board ->> 'hid')::int, 0) + 1,
          'hz', coalesce(board -> 'hz', '[]'::jsonb) || jsonb_build_array(jsonb_build_object('id', coalesce((board ->> 'hid')::int, 0) + 1, 'k', 'arrow', 'c', c,
            'left', coalesce((cfg ->> 'arrow_left')::int, 2), 'wm', true)))
         where fight_id = p_fight;
      end if;
    end if;
    if k < 7 and p_round >= (wm ->> 'dl')::int then
      return public.world_ug_wm_fail(p_fight, p_round, '동짓밤이 끝나기 전에 일곱째 등까지 켜지 못했다고 한다'); end if;
    if k >= 7 and not exists (select 1 from jsonb_array_elements(coalesce(wm -> 'arrows', '[]'::jsonb)) e where (e ->> 'r')::int > p_round) then
      perform public.world_gw_say(p_fight, p_round, 'good', '동짓밤이 지났습니다. 일곱 등이 차례대로 다시 섰습니다.');
      wm := wm || jsonb_build_object('status', 'done');
    end if;
    update public.world_gw_fights set board = jsonb_set(board, '{wm}', wm) where fight_id = p_fight;
  end if;
  return false;
end $f$;

create or replace function public.world_ug_wm_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; wm jsonb; cfg jsonb := public.world_ug_wm_cfg(p_fight); i int; v jsonb; c int; k int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  wm := f.board -> 'wm';
  if wm is null or wm ->> 'status' <> 'on' then return null; end if;
  i := f.round - (wm ->> 'start')::int;
  v := jsonb_build_object('k', wm ->> 'k', 'name', cfg ->> 'name', 'i', i, 'end', (wm ->> 'end')::int - f.round, 'show', i = 0);
  if wm ->> 'k' = 'seal9' then
    v := v || jsonb_build_object('step', i, 'steps', 4, 'due', i between 1 and 4)
      || case when i = 0 then jsonb_build_object('order', (select jsonb_object_agg(z, o) from jsonb_array_elements_text(wm -> 'ord') with ordinality q(z, o))) else '{}'::jsonb end;
  elsif wm ->> 'k' = 'sea' then
    v := v || jsonb_build_object('t', wm ->> 't', 'vortex', i = jsonb_array_length(wm -> 'faces') + 1, 'due', i >= 1)
      || case when i = 0 then jsonb_build_object('faces', wm -> 'faces') else '{}'::jsonb end;
  elsif wm ->> 'k' = 'rewrite' then
    k := (select o from jsonb_array_elements_text(wm -> 'steps') with ordinality s(z, o) where z::int = f.round)::int;
    v := v || jsonb_build_object('due', k is not null, 'left', greatest(0, (wm -> 'steps' ->> 0)::int - f.round))
      || case when i = 0 then jsonb_build_object('cells', wm -> 'cells') else '{}'::jsonb end;
  elsif wm ->> 'k' = 'close' then
    v := v || jsonb_build_object('stalls', wm -> 'stalls', 'due', f.round = (wm ->> 'end')::int);
  elsif wm ->> 'k' = 'dongji' then
    v := v || jsonb_build_object('mine', (select coalesce(jsonb_agg(jsonb_build_object('c', z::int, 'n', o)), '[]'::jsonb) from jsonb_array_elements_text(wm -> 'seq') with ordinality q(z, o)
        where wm -> 'own' ->> z = p_uid::text), 'lit', (wm ->> 'lit')::int, 'left', greatest(0, (wm ->> 'dl')::int - f.round),
      'due', exists (select 1 from jsonb_array_elements(coalesce(wm -> 'arrows', '[]'::jsonb)) e where (e ->> 'r')::int = f.round));
  end if;
  return v;
end $f$;

revoke all on function public.world_ug_wm_cfg(uuid), public.world_ug_wm_kind(text), public.world_ug_wm_on(uuid), public.world_ug_wm_hold(uuid), public.world_ug_wm_easy_a(uuid),
  public.world_ug_wm_easy_j(uuid), public.world_ug_hz_of(jsonb, text), public.world_ug_hz_cons(uuid, jsonb, integer), public.world_ug_wm_solve(uuid, jsonb, integer, jsonb, jsonb),
  public.world_ug_wm_mem(uuid, jsonb), public.world_ug_wm_dj_cons(uuid, jsonb, integer, integer, numeric), public.world_ug_wm_fit(uuid, integer, jsonb, boolean), public.world_ug_wm_start(uuid, integer), public.world_ug_wm_pre(uuid, integer), public.world_ug_wm_post(uuid, integer, integer),
  public.world_ug_wm_dmg(uuid, integer, numeric), public.world_ug_wm_fail(uuid, integer, text), public.world_ug_wm_check(uuid, integer), public.world_ug_wm_view(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.world_ug_wm_cfg(uuid), public.world_ug_wm_kind(text), public.world_ug_wm_on(uuid), public.world_ug_wm_hold(uuid), public.world_ug_wm_easy_a(uuid),
  public.world_ug_wm_easy_j(uuid), public.world_ug_hz_of(jsonb, text), public.world_ug_hz_cons(uuid, jsonb, integer), public.world_ug_wm_solve(uuid, jsonb, integer, jsonb, jsonb),
  public.world_ug_wm_mem(uuid, jsonb), public.world_ug_wm_dj_cons(uuid, jsonb, integer, integer, numeric), public.world_ug_wm_fit(uuid, integer, jsonb, boolean), public.world_ug_wm_start(uuid, integer), public.world_ug_wm_pre(uuid, integer), public.world_ug_wm_post(uuid, integer, integer),
  public.world_ug_wm_dmg(uuid, integer, numeric), public.world_ug_wm_fail(uuid, integer, text), public.world_ug_wm_check(uuid, integer), public.world_ug_wm_view(uuid, uuid)
  to service_role, fn_owner_field;

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  update public.world_gw_fights set hp = least(max_hp, greatest(0, hp - round(boss_dmg)::int + round(boss_heal)::int)), updated_at = now() where fight_id = p_fight returning * into f;$o$,
  $n$  update public.world_gw_fights set hp = least(max_hp, greatest(case when f.mode = 'ultimate' and public.world_ug_wm_hold(p_fight) then 1 else 0 end, hp - round(boss_dmg)::int + round(boss_heal)::int)), updated_at = now() where fight_id = p_fight returning * into f;$n$);

select pg_temp.yh_patch('public.world_mk_after(uuid,integer)',
  $o$  if coalesce((f.board ->> 'strokes')::int, 1) <= 0 then$o$,
  $n$  if f.mode <> 'ultimate' and coalesce((f.board ->> 'strokes')::int, 1) <= 0 then$n$);

select pg_temp.yh_patch('public.world_ug_raw(uuid)',
  $o$  return public.world_mk_raw(p_fight) * case when d then 2 else 1 end;$o$,
  $n$  return public.world_mk_raw(p_fight) * case when d then 2 else 1 end * case when public.world_ug_wm_on(p_fight) then coalesce((public.world_ug_wm_cfg(p_fight) ->> 'hand')::numeric, 1) else 1 end;$n$);
