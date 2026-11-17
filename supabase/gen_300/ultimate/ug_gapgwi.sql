create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  if position(p_new in d) > 0 then return; end if;
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;
create or replace function public.world_ug_nbm(p_kind text)
 returns int[] language plpgsql immutable set search_path = pg_catalog, public
as $f$
declare r int[] := '{}'; c int; m int; z int;
begin
  for c in 1 .. case when p_kind = 'gg' then 15 else 14 end loop
    m := 1 << (c - 1);
    foreach z in array case when p_kind = 'gg' then public.world_gg_nb(c) else public.world_by_nb(c) end loop m := m | (1 << (z - 1)); end loop;
    r := r || m;
  end loop;
  return r;
end $f$;

create or replace function public.world_ug_mask(p_cells int[])
 returns int language sql immutable set search_path = pg_catalog, public
as $f$ select coalesce(bit_or(1 << (z - 1)), 0)::int from unnest(p_cells) z where z between 1 and 30 $f$;

create or replace function public.world_ug_far(p_kind text, p_cell integer, p_d integer)
 returns int language sql immutable set search_path = pg_catalog, public
as $f$ select coalesce(bit_or(1 << (z - 1)), 0)::int from generate_series(1, case when p_kind = 'gg' then 15 else 14 end) z where public.world_gg_dist(z, p_cell) >= p_d $f$;

create or replace function public.world_ug_viab(p_nbm int[], p_pos integer, p_allow int[], p_still boolean[])
 returns int[] language plpgsql immutable set search_path = pg_catalog, public
as $f$
declare k int; kk int := coalesce(array_length(p_allow, 1), 0); fw int[] := '{}'; bw int[]; s int; e int; c int; v int[] := '{}';
begin
  if p_pos is null or kk = 0 then return null; end if;
  s := 1 << (p_pos - 1);
  for k in 1 .. kk loop
    if p_still[k] then e := s; else
      e := 0;
      for c in 1 .. array_length(p_nbm, 1) loop if s & (1 << (c - 1)) <> 0 then e := e | p_nbm[c]; end if; end loop;
    end if;
    s := e & p_allow[k];
    if s = 0 then return null; end if;
    fw := fw || s;
  end loop;
  bw := array_fill(0, array[kk]);
  bw[kk] := fw[kk];
  for k in reverse kk - 1 .. 1 loop
    e := 0;
    for c in 1 .. array_length(p_nbm, 1) loop
      if fw[k] & (1 << (c - 1)) <> 0 and ((p_still[k + 1] and bw[k + 1] & (1 << (c - 1)) <> 0) or (not p_still[k + 1] and p_nbm[c] & bw[k + 1] <> 0)) then e := e | (1 << (c - 1)); end if;
    end loop;
    if e = 0 then return null; end if;
    bw[k] := e;
  end loop;
  return bw;
end $f$;

create or replace function public.world_ug_vreach(p_v integer, p_caps int[], p_fix int[] default null)
 returns int[] language plpgsql immutable set search_path = pg_catalog, public
as $f$
declare k int; s int := 1 << greatest(0, least(9, p_v)); e int; v int; r int[] := '{}';
begin
  for k in 1 .. coalesce(array_length(p_caps, 1), 0) loop
    e := 0;
    for v in 0 .. 9 loop
      if s & (1 << v) <> 0 then
        if p_fix is not null and p_fix[k] is not null then e := e | (1 << least(9, greatest(0, v + p_fix[k])));
        else e := e | (1 << least(9, v + 1)) | (1 << v) | (1 << greatest(0, v - 5)); end if;
      end if;
    end loop;
    s := e & p_caps[k];
    if s = 0 then return null; end if;
    r := r || s;
  end loop;
  return r;
end $f$;

create or replace function public.world_ug_vok(p_val jsonb, p_grp jsonb, p_kk integer)
 returns boolean language plpgsql immutable set search_path = pg_catalog, public
as $f$
declare caps int[]; i int; r int[]; ks int; sums bigint := 1; e bigint; v int;
begin
  if p_val is null then return true; end if;
  caps := array(select (x)::int from jsonb_array_elements_text(p_val -> 'caps') x);
  ks := (p_val -> 'sum' ->> 'k')::int;
  for i in 1 .. jsonb_array_length(p_val -> 'v') loop
    r := public.world_ug_vreach((p_val -> 'v' ->> (i - 1))::int, caps);
    if r is null then return false; end if;
    if ks is not null and coalesce(p_grp -> (p_val -> 'sum' ->> 'g') @> to_jsonb(i), false) then
      e := 0;
      for v in 0 .. 9 loop
        if r[ks] & (1 << v) <> 0 then e := e | (sums << v); end if;
      end loop;
      sums := e & ((1::bigint << 50) - 1);
    end if;
  end loop;
  if ks is null then return true; end if;
  return (p_val -> 'sum' ->> 't')::int between 0 and 49 and sums & (1::bigint << (p_val -> 'sum' ->> 't')::int) <> 0;
end $f$;

create or replace function public.world_ug_solve_rec(p_kind text, p_nbm int[], p_pos int[], p_kk integer, p_allow int[], p_still boolean[], p_act text[],
  p_ch jsonb, p_i integer, p_grp jsonb, p_val jsonb)
 returns jsonb language plpgsql set search_path = pg_catalog, public
as $f$
declare nm int := coalesce(array_length(p_pos, 1), 0); i int; j int; k int; x int; v int[]; vs int[]; ch jsonb; r int; ok boolean; res jsonb;
  al int[]; ac text[]; cm int; g jsonb; who int; oth int; nn int; left_n int; fm int;
begin
  left_n := coalesce(nullif(current_setting('yh.ugb', true), '')::int, 0);
  if left_n <= 0 then return null; end if;
  perform set_config('yh.ugb', (left_n - 1)::text, true);
  vs := array_fill(0, array[nm * p_kk]);
  for i in 1 .. nm loop
    v := public.world_ug_viab(p_nbm, p_pos[i], p_allow[(i - 1) * p_kk + 1 : i * p_kk], p_still[(i - 1) * p_kk + 1 : i * p_kk]);
    if v is null then return null; end if;
    for k in 1 .. p_kk loop vs[(i - 1) * p_kk + k] := v[k]; end loop;
  end loop;
  if p_i > jsonb_array_length(p_ch) then
    if not public.world_ug_vok(p_val, p_grp, p_kk) then return null; end if;
    return jsonb_build_object('act', to_jsonb(p_act), 'grp', p_grp, 'vs', to_jsonb(vs));
  end if;
  ch := p_ch -> (p_i - 1); r := (ch ->> 'k')::int;
  if ch ->> 't' = 'need' then
    cm := (ch ->> 'm')::int; nn := least(nm, coalesce((ch ->> 'n')::int, 1));
    for i in 1 .. nm loop
      continue when vs[(i - 1) * p_kk + r] & cm = 0;
      continue when ch ->> 'a' is not null and p_act[(i - 1) * p_kk + r] is not null;
      for j in i .. case when nn >= 2 then nm else i end loop
        continue when nn >= 2 and j = i;
        continue when vs[(j - 1) * p_kk + r] & cm = 0;
        continue when ch ->> 'a' is not null and p_act[(j - 1) * p_kk + r] is not null;
        al := p_allow; ac := p_act; g := p_grp;
        al[(i - 1) * p_kk + r] := al[(i - 1) * p_kk + r] & cm; al[(j - 1) * p_kk + r] := al[(j - 1) * p_kk + r] & cm;
        if ch ->> 'a' is not null then ac[(i - 1) * p_kk + r] := ch ->> 'a'; ac[(j - 1) * p_kk + r] := ch ->> 'a'; end if;
        if ch ->> 'g' is not null then g := jsonb_set(g, array[ch ->> 'g'], coalesce(g -> (ch ->> 'g'), '[]'::jsonb) || to_jsonb(i) || case when j <> i then to_jsonb(j) else '[]'::jsonb end); end if;
        res := public.world_ug_solve_rec(p_kind, p_nbm, p_pos, p_kk, al, p_still, ac, p_ch, p_i + 1, g, p_val);
        if res is not null then return res; end if;
        if coalesce(nullif(current_setting('yh.ugb', true), '')::int, 0) <= 0 then return null; end if;
      end loop;
    end loop;
    return null;
  elsif ch ->> 't' = 'only' then
    cm := (ch ->> 'm')::int; al := p_allow;
    for i in 1 .. nm loop
      if not coalesce(p_grp -> (ch ->> 'g') @> to_jsonb(i), false) then al[(i - 1) * p_kk + r] := al[(i - 1) * p_kk + r] & ~cm; end if;
    end loop;
    return public.world_ug_solve_rec(p_kind, p_nbm, p_pos, p_kk, al, p_still, p_act, p_ch, p_i + 1, p_grp, p_val);
  end if;
  who := (ch ->> 'w')::int; oth := (ch ->> 'o')::int;
  if who is null or who > nm or (ch ->> 't' = 'apart' and (oth is null or oth > nm)) or (ch ->> 't' = 'near' and nm < 2) then
    return public.world_ug_solve_rec(p_kind, p_nbm, p_pos, p_kk, p_allow, p_still, p_act, p_ch, p_i + 1, p_grp, p_val);
  end if;
  for x in select z from generate_series(1, array_length(p_nbm, 1)) z where vs[(who - 1) * p_kk + r] & (1 << (z - 1)) <> 0 order by (z <> p_pos[who]), z loop
    if ch ->> 't' = 'alone' then
      al := p_allow; ok := true;
      al[(who - 1) * p_kk + r] := al[(who - 1) * p_kk + r] & (1 << (x - 1));
      for i in 1 .. nm loop
        continue when i = who;
        al[(i - 1) * p_kk + r] := al[(i - 1) * p_kk + r] & ~p_nbm[x];
        if vs[(i - 1) * p_kk + r] & al[(i - 1) * p_kk + r] = 0 then ok := false; end if;
      end loop;
      if ok then
        res := public.world_ug_solve_rec(p_kind, p_nbm, p_pos, p_kk, al, p_still, p_act, p_ch, p_i + 1, p_grp, p_val);
        if res is not null then return res; end if;
      end if;
    elsif ch ->> 't' = 'near' then
      for j in 1 .. nm loop
        continue when j = who or vs[(j - 1) * p_kk + r] & p_nbm[x] = 0;
        al := p_allow;
        al[(who - 1) * p_kk + r] := al[(who - 1) * p_kk + r] & (1 << (x - 1));
        al[(j - 1) * p_kk + r] := al[(j - 1) * p_kk + r] & p_nbm[x];
        res := public.world_ug_solve_rec(p_kind, p_nbm, p_pos, p_kk, al, p_still, p_act, p_ch, p_i + 1, p_grp, p_val);
        if res is not null then return res; end if;
        if coalesce(nullif(current_setting('yh.ugb', true), '')::int, 0) <= 0 then return null; end if;
      end loop;
    elsif ch ->> 't' = 'apart' then
      fm := public.world_ug_far(p_kind, x, (ch ->> 'd')::int);
      if vs[(oth - 1) * p_kk + r] & fm <> 0 then
        al := p_allow;
        al[(who - 1) * p_kk + r] := al[(who - 1) * p_kk + r] & (1 << (x - 1));
        al[(oth - 1) * p_kk + r] := al[(oth - 1) * p_kk + r] & fm;
        res := public.world_ug_solve_rec(p_kind, p_nbm, p_pos, p_kk, al, p_still, p_act, p_ch, p_i + 1, p_grp, p_val);
        if res is not null then return res; end if;
      end if;
    end if;
    if coalesce(nullif(current_setting('yh.ugb', true), '')::int, 0) <= 0 then return null; end if;
  end loop;
  return null;
end $f$;

create or replace function public.world_ug_vpick(p_sets int[], p_i integer, p_t integer)
 returns int[] language plpgsql immutable set search_path = pg_catalog, public
as $f$
declare v int; r int[];
begin
  if p_i > coalesce(array_length(p_sets, 1), 0) then return case when p_t = 0 then '{}'::int[] end; end if;
  for v in 0 .. 9 loop
    continue when p_sets[p_i] & (1 << v) = 0 or v > p_t;
    r := public.world_ug_vpick(p_sets, p_i + 1, p_t - v);
    if r is not null then return v || r; end if;
  end loop;
  return null;
end $f$;

create or replace function public.world_ug_solve(p_kind text, p_mem jsonb, p_nr integer, p_cons jsonb, p_budget integer default 300)
 returns jsonb language plpgsql set search_path = pg_catalog, public
as $f$
declare nbm int[] := public.world_ug_nbm(p_kind); nm int := jsonb_array_length(p_mem); nc int := array_length(nbm, 1); fullm int := (1 << nc) - 1;
  kk int; ids text[]; pos int[]; allow int[]; still boolean[]; act text[]; ch jsonb := '[]'; c jsonb; k int; i int; w int; m int; caps int[]; val jsonb; sm jsonb;
  res jsonb; out jsonb := '[]'; vs int[]; grp jsonb; tv int[]; gi int[]; d int; dd int; rr int[]; tgt int; pref int[]; vv int;
begin
  ids := array(select e ->> 'id' from jsonb_array_elements(p_mem) e);
  pos := array(select (e ->> 'pos')::int from jsonb_array_elements(p_mem) e);
  if nm = 0 then return jsonb_build_object('m', '[]'::jsonb); end if;
  select greatest(1, least(10, coalesce(max((e ->> 'r')::int), p_nr) - p_nr + 1)) into kk from jsonb_array_elements(coalesce(p_cons, '[]'::jsonb)) e where (e ->> 'r')::int >= p_nr;
  kk := coalesce(kk, 1);
  allow := array_fill(fullm, array[nm * kk]); still := array_fill(false, array[nm * kk]); act := array_fill(null::text, array[nm * kk]);
  caps := array_fill(1023, array[kk]);
  for c in select * from jsonb_array_elements(coalesce(p_cons, '[]'::jsonb)) loop
    k := (c ->> 'r')::int - p_nr + 1;
    continue when k < 1 or k > kk;
    w := array_position(ids, c ->> 'who');
    if c ? 'who' and c ->> 'who' is not null and w is null then continue; end if;
    m := public.world_ug_mask(array(select (z)::int from jsonb_array_elements_text(coalesce(c -> 'cells', '[]'::jsonb)) z));
    if c ->> 't' = 'avoid' then
      for i in 1 .. nm loop if w is null or i = w then allow[(i - 1) * kk + k] := allow[(i - 1) * kk + k] & ~m; end if; end loop;
    elsif c ->> 't' = 'goal' then allow[(w - 1) * kk + k] := allow[(w - 1) * kk + k] & m;
    elsif c ->> 't' in ('still', 'stun') then
      still[(w - 1) * kk + k] := true;
      if c ->> 't' = 'stun' then act[(w - 1) * kk + k] := 'X'; end if;
    elsif c ->> 't' = 'act' then
      if act[(w - 1) * kk + k] is not null then return null; end if;
      act[(w - 1) * kk + k] := c ->> 'a';
    elsif c ->> 't' = 'need' then ch := ch || jsonb_build_array(jsonb_build_object('t', 'need', 'k', k, 'm', m, 'n', coalesce((c ->> 'n')::int, 1), 'a', c ->> 'a', 'g', c ->> 'g', 'ord', 0));
    elsif c ->> 't' = 'only' then ch := ch || jsonb_build_array(jsonb_build_object('t', 'only', 'k', k, 'm', m, 'g', c ->> 'g', 'ord', 1));
    elsif c ->> 't' in ('near', 'alone') then ch := ch || jsonb_build_array(jsonb_build_object('t', c ->> 't', 'k', k, 'w', w, 'ord', 2));
    elsif c ->> 't' = 'apart' then
      if array_position(ids, c ->> 'a') is null or array_position(ids, c ->> 'b') is null then continue; end if;
      ch := ch || jsonb_build_array(jsonb_build_object('t', 'apart', 'k', k, 'w', array_position(ids, c ->> 'a'), 'o', array_position(ids, c ->> 'b'), 'd', (c ->> 'd')::int, 'ord', 2));
    elsif c ->> 't' = 'cap' then caps[k] := caps[k] & ((1 << ((c ->> 'max')::int + 1)) - 1);
    elsif c ->> 't' = 'sum' then sm := jsonb_build_object('k', k, 'g', c ->> 'g', 't', (c ->> 'v')::int);
    end if;
  end loop;
  select coalesce(jsonb_agg(e - 'ord' order by (e ->> 'ord')::int, (e ->> 'k')::int, coalesce((e ->> 'n')::int, 1) desc), '[]'::jsonb) into ch from jsonb_array_elements(ch) e;
  if p_kind = 'gg' then
    val := jsonb_build_object('v', (select jsonb_agg(coalesce((e ->> 'v')::int, 0)) from jsonb_array_elements(p_mem) e), 'caps', to_jsonb(caps)) || case when sm is not null then jsonb_build_object('sum', sm) else '{}'::jsonb end;
  end if;
  perform set_config('yh.ugb', greatest(1, p_budget)::text, true);
  res := public.world_ug_solve_rec(p_kind, nbm, pos, kk, allow, still, act, ch, 1, '{}'::jsonb, val);
  if res is null then return null; end if;
  vs := array(select (x)::int from jsonb_array_elements_text(res -> 'vs') x);
  grp := res -> 'grp';
  if sm is not null then
    gi := array(select (x)::int from jsonb_array_elements_text(coalesce(grp -> (sm ->> 'g'), '[]'::jsonb)) x order by 1);
    tv := public.world_ug_vpick(array(select (public.world_ug_vreach((val -> 'v' ->> (q - 1))::int, caps))[(sm ->> 'k')::int] from unnest(gi) q), 1, (sm ->> 't')::int);
  end if;
  for i in 1 .. nm loop
    d := null;
    if val is not null then
      pref := coalesce(array(select (x)::int from jsonb_array_elements_text(p_mem -> (i - 1) -> 'pref') x), '{}');
      if cardinality(pref) = 0 then pref := array[1, 0, -5]; end if;
      vv := (val -> 'v' ->> (i - 1))::int;
      tgt := case when gi is not null and array_position(gi, i) is not null then tv[array_position(gi, i)] end;
      foreach dd in array pref loop
        rr := public.world_ug_vreach(vv, caps, array[dd] || array_fill(null::int, array[greatest(0, kk - 1)]));
        continue when rr is null;
        continue when tgt is not null and rr[(sm ->> 'k')::int] & (1 << tgt) = 0;
        d := dd; exit;
      end loop;
    end if;
    out := out || jsonb_build_array(jsonb_build_object('id', ids[i], 'v0', vs[(i - 1) * kk + 1], 'a', nullif((res -> 'act' ->> ((i - 1) * kk)), 'X'), 'd', d, 'stun', coalesce((res -> 'act' ->> ((i - 1) * kk)) = 'X', false)));
  end loop;
  return jsonb_build_object('m', out, 'kk', kk, 'left', current_setting('yh.ugb', true)::int);
end $f$;

create or replace function public.world_ug_mem(p_fight uuid)
 returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $f$ select coalesce(jsonb_agg(jsonb_build_object('id', owner_id::text, 'pos', pos, 'v', coalesce(gval, 0)) order by joined_at, owner_id), '[]'::jsonb)
  from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest $f$;

create or replace function public.world_ug_gg_cons(p_fight uuid, p_hz jsonb, p_nr integer)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; h jsonb; r int; out jsonb := '[]'; c text;
begin
  for h in select * from jsonb_array_elements(coalesce(p_hz, '[]'::jsonb)) loop
    r := p_nr + greatest(0, (h ->> 'left')::int);
    if h ->> 'k' = 'judge' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'avoid', 'r', r, 'cells', to_jsonb(public.world_gg_col((h ->> 'col')::int))));
    elsif h ->> 'k' = 'bargain' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'cap', 'r', r, 'max', (rb -> 'bargain' ->> 'cap')::int));
    elsif h ->> 'k' = 'ledger' then
      for c in select jsonb_array_elements_text(h -> 'cells') loop
        out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r, 'cells', jsonb_build_array(c::int), 'n', 1, 'g', 'L' || (h ->> 'id')));
      end loop;
      out := out || jsonb_build_array(jsonb_build_object('t', 'only', 'r', r, 'cells', h -> 'cells', 'g', 'L' || (h ->> 'id')),
        jsonb_build_object('t', 'sum', 'r', r, 'g', 'L' || (h ->> 'id'), 'v', (h ->> 't')::int));
    elsif h ->> 'k' = 'tether' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'apart', 'r', r, 'a', h ->> 'a', 'b', h ->> 'b', 'd', (rb -> 'tether' ->> 'dist')::int));
    end if;
  end loop;
  return out;
end $f$;

create or replace function public.world_ug_gg_ok(p_fight uuid, p_hz jsonb, p_nr integer)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
begin
  return public.world_ug_solve('gg', public.world_ug_mem(p_fight), p_nr, public.world_ug_gg_cons(p_fight, p_hz, p_nr),
    coalesce((public.world_boss_fight_rules(p_fight) -> 'board' ->> 'budget')::int, 300)) is not null;
end $f$;

create or replace function public.world_ug_gg_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb; b jsonb; nr int; ar int; ph int; m jsonb;
  na int; alive uuid[]; hz jsonb := '[]'; h jsonb; cur jsonb; mechs text[]; hid int; c int; k int; t int; cells int[]; col int; due boolean; i int; j int;
  cand jsonb; cue text[] := '{}'; tries int; base int; offs int[]; o int; pick uuid[]; n int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  rb := br -> 'board'; b := coalesce(f.board, '{}'::jsonb); nr := f.round + 1; ar := nr - coalesce((b -> 'ug' ->> 'act_start')::int, 0);
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  alive := array(select owner_id from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest order by random());
  na := coalesce(array_length(alive, 1), 0);
  hid := coalesce((b ->> 'hid')::int, 0);
  cur := public.world_gg_seq(p_fight, f.hp, f.max_hp);
  mechs := array(select jsonb_array_elements_text(cur -> 'm'));
  if (cur ->> 'i')::int <> coalesce((b ->> 'seq')::int, 0) then
    perform public.world_gw_say(p_fight, nr, 'phase', case
      when 'tether' = any (mechs) then '값귀가 두 사람의 소매를 붉은 외상 줄로 묶는다. 「같이 갚든가, 갈라서든가.」'
      when 'ledger' = any (mechs) then '값귀가 낱장을 펼쳐 좌판 위에 깐다. 「그 좌판에 선 이들의 값을 더해 맞추면 장부를 덮어 주마.」'
      when 'bargain' = any (mechs) then '주판알이 사납게 맞부딪친다. 「값이 비싼 놈부터 거둔다.」'
      else '값귀가 장부를 넘긴다.' end);
    b := b || jsonb_build_object('seq', (cur ->> 'i')::int);
  end if;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    hz := hz || jsonb_build_array(h || jsonb_build_object('left', (h ->> 'left')::int - 1));
  end loop;
  if na > 0 and ar > 0 then
    if 'ledger' = any (mechs) and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'ledger') and ar % (rb -> 'ledger' ->> 'every')::int = (rb -> 'ledger' ->> 'off')::int then
      k := least(na, coalesce((rb -> 'ledger' -> 'cells' ->> (least(4, greatest(1, n)) - 1))::int, 2));
      <<led>>
      for tries in 1 .. 4 loop
        pick := alive[1:k];
        cells := '{}';
        for i in 1 .. k loop
          select pos into c from public.world_gw_members where fight_id = p_fight and owner_id = pick[i];
          select z into t from (select generate_series(1, 5) z union all select generate_series(11, 15)) q
           where not (z = any (cells)) order by public.world_gg_dist(z, c) + random() * 1.5, random() limit 1;
          if t is not null then cells := cells || t; end if;
        end loop;
        base := (select coalesce(sum(gval), 0) from public.world_gw_members where fight_id = p_fight and owner_id = any (pick));
        offs := array(select o2 from unnest(array[-2, -1, 0, 1, 2, 3]) o2 order by random());
        foreach o in array offs loop
          continue when base + o < 0;
          cand := hz || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'ledger', 'cells', to_jsonb(cells), 't', base + o, 'left', (rb -> 'ledger' ->> 'left')::int));
          if public.world_ug_gg_ok(p_fight, cand, nr) then hz := cand; hid := hid + 1; cue := cue || '장부'::text; exit led; end if;
        end loop;
        alive := array(select x from unnest(alive) x order by random());
      end loop;
    end if;
    if 'tether' = any (mechs) and na >= 2 and ar % (rb -> 'tether' ->> 'every')::int = (rb -> 'tether' ->> 'off')::int then
      <<teth>>
      for i in 1 .. na loop
        for j in i + 1 .. na loop
          cand := hz || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'tether', 'a', alive[i], 'b', alive[j], 'left', (rb -> 'tether' ->> 'left')::int));
          if public.world_ug_gg_ok(p_fight, cand, nr) then hz := cand; hid := hid + 1; cue := cue || '외상 줄'::text; exit teth; end if;
        end loop;
      end loop;
    end if;
    if 'judge' = any (mechs) and ar % (rb -> 'judge' ->> 'every')::int = (rb -> 'judge' ->> 'off')::int then
      for col in select q from (select ((x.pos - 1) % 5) + 1 q, min(array_position(alive, x.owner_id)) o2 from public.world_gw_members x
          where x.fight_id = p_fight and x.owner_id = any (alive) and x.pos is not null group by 1) s order by o2 loop
        cand := hz || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'judge', 'col', col, 'left', (rb -> 'judge' ->> 'left')::int));
        if public.world_ug_gg_ok(p_fight, cand, nr) then hz := cand; hid := hid + 1; cue := cue || '판결 망치'::text; exit; end if;
      end loop;
    end if;
    if 'bargain' = any (mechs) and ar % (rb -> 'bargain' ->> 'every')::int = (rb -> 'bargain' ->> 'off')::int then
      cand := hz || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'bargain', 'left', (rb -> 'bargain' ->> 'left')::int));
      if public.world_ug_gg_ok(p_fight, cand, nr) then hz := cand; hid := hid + 1; cue := cue || '바가지'::text; end if;
    end if;
  end if;
  due := exists (select 1 from jsonb_array_elements(hz) e where (e ->> 'left')::int <= 0);
  b := b || jsonb_build_object('hz', hz, 'hid', hid);
  m := jsonb_build_object('k', 'normal', 'phase_name', br -> 'phases' ->> (ph - 1), 'aoe', false, 'due', due, 'cue', to_jsonb(cue), 'mechs', to_jsonb(mechs),
    'tell', case when due then '값귀가 주판알을 멈춘다.' else '값귀가 주판알을 딸깍인다.' end);
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when due then 10 else 5 end), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
end $f$;

create or replace function public.world_ug_fail(p_fight uuid, p_round integer, p_fails integer, p_raw numeric, p_fade boolean)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; x record; cap int := coalesce((rb ->> 'fail_cap')::int, 3); e int; b jsonb;
begin
  if p_fails <= 0 then return; end if;
  update public.world_gw_fights set enrage = enrage + p_fails where fight_id = p_fight returning enrage, board into e, b;
  perform public.world_gw_say(p_fight, p_round, 'bad', '이야기꾼이 침을 튀긴다 — 「거기서 발을 헛디뎠지!」 실수 ' || least(e, cap) || '/' || cap || case when e >= cap then ' — 이야기가 그 자리에서 끝장난다.' else '. 모두가 함께 다친다.' end);
  for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
    perform public.world_gw_hurt(p_fight, x.owner_id, round(p_raw * p_fails)::int, p_round, '번진 실수에');
    if p_fade then b := public.world_by_fade(p_fight, b, x.owner_id, p_fails, p_round); end if;
  end loop;
  if p_fade then update public.world_gw_fights set board = b where fight_id = p_fight; end if;
end $f$;

create or replace function public.world_ug_gg_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; b jsonb; w record; x record; h jsonb; keep jsonb := '[]';
  extra numeric := 0; cells int[]; cnt int; sm int; nm text; tn text; fails int := 0; na int; tv int; hv int; mx int; cap int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; mx := coalesce((rb ->> 'max')::int, 9); cap := (rb -> 'bargain' ->> 'cap')::int;
  select count(*) into na from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  if coalesce((b ->> 'broke')::int, 0) > 0 then b := b || jsonb_build_object('broke', (b ->> 'broke')::int - 1); end if;
  update public.world_gw_members x2 set gval = least(mx, greatest(0, x2.gval + coalesce((rb -> 'delta' ->> coalesce(x2.act ->> 'a', 'guard'))::int, 0)))
   where x2.fight_id = p_fight and x2.out_rounds = 0 and not x2.rest and x2.gval is not null;
  for w in select x2.* from public.world_gw_members x2 where x2.fight_id = p_fight and x2.out_rounds = 0 and not x2.rest and x2.act ->> 'a' = 'deal' order by x2.joined_at loop
    update public.world_gw_members set gval = greatest(0, gval + (rb ->> 'haggle')::int) where fight_id = p_fight and owner_id = w.owner_id returning gval into tv;
    perform public.world_gw_say(p_fight, p_round, 'good', w.name || ' — 값귀에게 흥정을 걸어 제 값을 ' || tv || '섬으로 깎았습니다.');
  end loop;
  for w in select x2.* from public.world_gw_members x2 where x2.fight_id = p_fight and x2.out_rounds = 0 and not x2.rest and x2.act ->> 'a' = 'call' and nullif(x2.act ->> 't', '') is not null
            and (x2.act ->> 't')::uuid <> x2.owner_id order by x2.joined_at loop
    select name, pos into tn, hv from public.world_gw_members where fight_id = p_fight and owner_id = (w.act ->> 't')::uuid and out_rounds = 0;
    if tn is null then continue; end if;
    if public.world_gg_dist(w.pos, hv) > 1 then
      perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — ' || tn || '이(가) 너무 멀어 값을 매겨 줄 수 없습니다(바로 옆 칸만).'); continue;
    end if;
    update public.world_gw_members set gval = least(mx, gval + (rb ->> 'price')::int) where fight_id = p_fight and owner_id = (w.act ->> 't')::uuid returning gval into tv;
    perform public.world_gw_say(p_fight, p_round, 'good', w.name || ' — ' || tn || '의 값을 ' || tv || '섬으로 매겨 주었습니다.');
  end loop;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    if (h ->> 'left')::int > 0 then keep := keep || jsonb_build_array(h); continue; end if;
    cells := public.world_gg_hz_cells(p_fight, h);
    if h ->> 'k' = 'judge' then
      select string_agg(y.name, '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells);
      if nm is null then
        perform public.world_gw_say(p_fight, p_round, 'good', '판결 망치가 ' || (h ->> 'col') || '번째 줄을 내리쳤지만 아무도 없었습니다.');
      else
        fails := fails + 1;
        perform public.world_gw_say(p_fight, p_round, 'boss', '판결 망치가 ' || (h ->> 'col') || '번째 줄을 내리칩니다! — ' || nm);
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
          perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'judge' ->> 'raw')::numeric * case when p_broke then 0.5 else 1 end, p_round, '판결 망치에', false);
        end loop;
      end if;
    elsif h ->> 'k' = 'bargain' then
      select string_agg(y.name || '(' || y.gval || '섬)', '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.gval > cap;
      if nm is null then
        perform public.world_gw_say(p_fight, p_round, 'good', '값귀가 바가지를 씌우려 했지만 ' || cap || '섬을 넘는 사람이 없었습니다.');
      else
        fails := fails + 1;
        perform public.world_gw_say(p_fight, p_round, 'boss', '값귀가 ' || cap || '섬을 넘은 값에 바가지를 씌웁니다! — ' || nm);
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.gval > cap loop
          perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'bargain' ->> 'raw')::numeric * case when p_broke then 0.5 else 1 end, p_round, x.gval || '섬 바가지에', false);
        end loop;
      end if;
    elsif h ->> 'k' = 'ledger' then
      select count(distinct y.pos), coalesce(sum(y.gval), 0) into cnt, sm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells);
      if cnt >= least(cardinality(cells), na) and sm = (h ->> 't')::int then
        extra := extra + round(f.max_hp * (rb -> 'ledger' ->> 'hit_pct')::numeric / 100.0);
        b := b || jsonb_build_object('broke', (rb -> 'ledger' ->> 'broke')::int);
        perform public.world_gw_say(p_fight, p_round, 'good', '좌판 위 값의 합 ' || sm || '섬 — 장부가 맞았습니다! 값귀가 제 장부에 걸려 휘청입니다.');
      else
        fails := fails + 1;
        update public.world_gw_fights set hp = least(max_hp, hp + round(max_hp * (rb -> 'ledger' ->> 'heal_pct')::numeric / 100.0)), updated_at = now() where fight_id = p_fight;
        perform public.world_gw_say(p_fight, p_round, 'bad', '좌판 위 값의 합 ' || sm || '섬(선 곳 ' || cnt || '/' || least(cardinality(cells), na) || ') — 장부가 맞지 않았습니다(목표 ' || (h ->> 't') || '섬). 값귀가 물 밑 장부에서 값을 꺼내 낫습니다.');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
          perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'ledger' ->> 'raw')::numeric, p_round, '맞지 않은 장부에', false);
        end loop;
      end if;
    elsif h ->> 'k' = 'tether' then
      if cardinality(cells) = 2 and public.world_gg_dist(cells[1], cells[2]) < (rb -> 'tether' ->> 'dist')::int then
        fails := fails + 1;
        perform public.world_gw_say(p_fight, p_round, 'bad', '외상 줄이 팽팽해지기 전에 두 사람이 너무 가까웠습니다. 줄이 두 사람을 함께 조입니다.');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.owner_id in ((h ->> 'a')::uuid, (h ->> 'b')::uuid) loop
          perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'tether' ->> 'raw')::numeric, p_round, '외상 줄에', false);
        end loop;
      else
        perform public.world_gw_say(p_fight, p_round, 'good', '멀리 떨어져 선 두 사람 사이에서 외상 줄이 툭 끊어졌습니다.');
      end if;
    end if;
  end loop;
  update public.world_gw_fights set board = b || jsonb_build_object('hz', keep) where fight_id = p_fight;
  perform public.world_ug_fail(p_fight, p_round, fails, coalesce((rb -> 'fail_party' ->> 'raw')::numeric, 0), false);
  return extra;
end $f$;

create or replace function public.world_ug_by_cons(p_fight uuid, p_hz jsonb, p_nr integer, p_board jsonb)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; h jsonb; r int; out jsonb := '[]'; na int; k text; v text;
begin
  select count(*) into na from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  for h in select * from jsonb_array_elements(coalesce(p_hz, '[]'::jsonb)) loop
    continue when coalesce((h ->> 'frozen')::boolean, false);
    r := p_nr + greatest(0, (h ->> 'left')::int);
    if h ->> 'k' = 'arrow' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'avoid', 'r', r, 'cells', jsonb_build_array((h ->> 'c')::int)));
    elsif h ->> 'k' = 'brush' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'avoid', 'r', r, 'cells', to_jsonb(public.world_by_sweep_cells((h ->> 's')::int, coalesce((rb -> 'brush' ->> 'width')::int, 1)))));
    elsif h ->> 'k' = 'big' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r, 'cells', to_jsonb(public.world_by_area((h ->> 'c')::int)), 'n', 1, 'a', 'sweep:' || (h ->> 'c')));
    elsif h ->> 'k' = 'gust' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r, 'cells', jsonb_build_array((h ->> 's')::int), 'n', 1, 'a', 'light'));
    elsif h ->> 'k' = 'tower' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'need', 'r', r, 'cells', jsonb_build_array((h ->> 'c')::int), 'n', (h ->> 'need')::int));
    elsif h ->> 'k' = 'stack' and na >= 2 then
      out := out || jsonb_build_array(jsonb_build_object('t', 'near', 'r', r, 'who', h ->> 't'));
    elsif h ->> 'k' in ('spread', 'num') then
      out := out || jsonb_build_array(jsonb_build_object('t', 'alone', 'r', r, 'who', h ->> 't'));
    elsif h ->> 'k' = 'clock' then
      out := out || jsonb_build_array(jsonb_build_object('t', 'still', 'r', r, 'who', h ->> 't'));
    end if;
  end loop;
  for k, v in select * from jsonb_each_text(coalesce(p_board -> 'stun', '{}'::jsonb)) loop
    if v::int >= p_nr then out := out || jsonb_build_array(jsonb_build_object('t', 'stun', 'r', v::int, 'who', k)); end if;
  end loop;
  return out;
end $f$;

create or replace function public.world_ug_by_ok(p_fight uuid, p_hz jsonb, p_nr integer, p_board jsonb)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; wn jsonb := p_board -> 'wn'; na int; un int; pend int; lft int;
begin
  if wn is not null and wn ->> 'at' is not null then
    select count(*) into na from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
    un := greatest(0, (wn ->> 'need')::int - (wn ->> 'lit')::int);
    select count(*) into pend from jsonb_array_elements(coalesce(p_hz, '[]'::jsonb)) e where e ->> 'k' <> 'arrow';
    lft := (wn ->> 'at')::int - p_nr + 1;
    if lft < ceil(un::numeric / greatest(1, na)) + coalesce((rb -> 'wn' ->> 'slack')::int, 3) + coalesce((rb -> 'wn' ->> 'cost')::int, 2) * pend then return false; end if;
  end if;
  return public.world_ug_solve('by', public.world_ug_mem(p_fight), p_nr, public.world_ug_by_cons(p_fight, p_hz, p_nr, p_board),
    coalesce((rb ->> 'budget')::int, 300)) is not null;
end $f$;

create or replace function public.world_ug_by_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb; b jsonb; nr int; ar int; ph int; m jsonb; aoe boolean := false;
  n int; na int; alive uuid[]; lamps int[]; hz jsonb := '[]'; h jsonb; cur jsonb; mechs text[]; cfg jsonb; nn int; c int; t uuid; hid int; need int; rounds int; s int; i int; k int;
  due boolean; cand jsonb; cue text[] := '{}'; x record;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  rb := br -> 'board'; b := coalesce(f.board, '{}'::jsonb); nr := f.round + 1; ar := nr - coalesce((b -> 'ug' ->> 'act_start')::int, 0);
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  alive := array(select owner_id from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest order by random());
  na := coalesce(array_length(alive, 1), 0);
  lamps := array(select jsonb_array_elements_text(coalesce(b -> 'lamps', '[]'::jsonb))::int);
  hid := coalesce((b ->> 'hid')::int, 0);
  cur := public.world_by_seq(p_fight, f.hp, f.max_hp);
  mechs := array(select jsonb_array_elements_text(cur -> 'm'));
  if (cur ->> 'i')::int <> coalesce((b ->> 'seq')::int, 0) then
    perform public.world_gw_say(p_fight, nr, 'phase', case
      when 'wn' = any (mechs) then '겹친 목소리가 비명을 지른다. 일곱 등이 한꺼번에 꺼지고 마당이 새하얗게 바랜다. 공중에 멈춘 것들이 꺼진 등 둘레에 매달린 채 숨을 죽인다.'
      when 'clock' = any (mechs) then '하얀 몸이 숨을 멈춘다. 누군가의 머리 위에 모래가 멈춘 모래시계가 떠오른다.'
      when 'tower' = any (mechs) then '등 기둥 아래로 하얀 기둥이 솟는다. 아무도 서 있지 않은 기둥은 등을 덮어 끌 것이다.'
      when 'drop' = any (mechs) then '하얀 소매에서 물방울과 흰 가루가 흩어져 사람들 머리 위에 멈춘다.'
      when 'brush' = any (mechs) then '붉은 붓끝이 마당 한쪽을 겨눈다. 붓이 지나간 자리는 하얗게 지워진다.'
      else '하얀 몸이 다시 일어선다.' end);
    b := b || jsonb_build_object('seq', (cur ->> 'i')::int);
  end if;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    if h ->> 'k' = 'arrow' and not (public.world_by_sector((h ->> 'c')::int) = any (lamps)) then
      h := h || '{"frozen": true}'::jsonb;
    else
      h := (h - 'frozen') || jsonb_build_object('left', (h ->> 'left')::int - 1);
    end if;
    hz := hz || jsonb_build_array(h);
  end loop;
  if 'wn' = any (mechs) and not b ? 'wn' then
    cfg := rb -> 'wn';
    need := (cfg ->> 'need')::int;
    rounds := coalesce((cfg -> 'rounds' ->> (least(4, greatest(1, n)) - 1))::int, 0);
    lamps := '{}';
    hz := (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(hz) e where e ->> 'k' in ('stack', 'spread', 'clock', 'num'));
    for s in 1 .. 7 loop
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'arrow', 'c', case when random() < 0.5 then s else s + 7 end, 'left', (cfg ->> 'arrow_left')::int, 'frozen', true));
    end loop;
    b := b || jsonb_build_object('wn', jsonb_build_object('start', nr, 'hp', f.hp, 'need', need, 'lit', 0, 'at', case when rounds > 0 then nr + rounds - 1 end));
    cue := cue || '흰 밤'::text;
  end if;
  b := b || jsonb_build_object('lamps', to_jsonb(coalesce(lamps, '{}'::int[])));
  if na > 0 and ar > 0 then
    if 'drop' = any (mechs) and ar % (rb -> 'drop' ->> 'every')::int = (rb -> 'drop' ->> 'off')::int then
      k := coalesce((b ->> 'dropk')::int, 0); b := b || jsonb_build_object('dropk', k + 1);
      for i in 1 .. na loop
        cand := hz;
        if na >= 3 or na = 1 or k % 2 = 0 then cand := cand || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'stack', 't', alive[i], 'left', (rb -> 'drop' ->> 'left')::int)); end if;
        if na >= 3 or (na = 2 and k % 2 = 1) then cand := cand || jsonb_build_array(jsonb_build_object('id', hid + 2, 'k', 'spread', 't', alive[(i % na) + 1], 'left', (rb -> 'drop' ->> 'left')::int)); end if;
        if public.world_ug_by_ok(p_fight, cand, nr, b) then hz := cand; hid := hid + 2; cue := cue || '물방울'::text; exit; end if;
      end loop;
    end if;
    if 'tower' = any (mechs) and ar % (rb -> 'tower' ->> 'every')::int = (rb -> 'tower' ->> 'off')::int then
      need := least(na, coalesce((rb -> 'tower' -> 'need' ->> (least(4, greatest(1, n)) - 1))::int, 1));
      for c in select z from unnest(lamps) z where not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' in ('tower', 'gust') and coalesce((e ->> 'c')::int, (e ->> 's')::int) = z) order by random() loop
        cand := hz || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'tower', 'c', c, 'need', need, 'left', (rb -> 'tower' ->> 'left')::int));
        if public.world_ug_by_ok(p_fight, cand, nr, b) then hz := cand; hid := hid + 1; cue := cue || '등 기둥'::text; exit; end if;
      end loop;
    end if;
    if 'gust' = any (mechs) and not b ? 'wn' and ar % (rb -> 'gust' ->> 'every')::int = (rb -> 'gust' ->> 'off')::int then
      for c in select z from unnest(lamps) z where not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' in ('tower', 'gust') and coalesce((e ->> 'c')::int, (e ->> 's')::int) = z) order by random() loop
        cand := hz || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'gust', 's', c, 'left', (rb -> 'gust' ->> 'left')::int));
        if public.world_ug_by_ok(p_fight, cand, nr, b) then hz := cand; hid := hid + 1; cue := cue || '꺼져 가는 등'::text; exit; end if;
      end loop;
    end if;
    if 'big' = any (mechs) and ar % (rb -> 'big' ->> 'every')::int = (rb -> 'big' ->> 'off')::int then
      for i in 1 .. na loop
        select pos into c from public.world_gw_members where fight_id = p_fight and owner_id = alive[i];
        continue when c is null;
        cand := hz || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'big', 'c', c, 'left', (rb -> 'big' ->> 'left')::int));
        if public.world_ug_by_ok(p_fight, cand, nr, b) then hz := cand; hid := hid + 1; cue := cue || '굵은 화살'::text; exit; end if;
      end loop;
    end if;
    if 'clock' = any (mechs) and ar % (rb -> 'clock' ->> 'every')::int = (rb -> 'clock' ->> 'off')::int then
      for i in 1 .. na loop
        cand := hz || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'clock', 't', alive[i], 'left', (rb -> 'clock' ->> 'left')::int));
        if public.world_ug_by_ok(p_fight, cand, nr, b) then hz := cand; hid := hid + 1; cue := cue || '멈춤 시계'::text; exit; end if;
      end loop;
    end if;
    if 'num' = any (mechs) and rb ? 'num' and na >= 2 and ar % (rb -> 'num' ->> 'every')::int = (rb -> 'num' ->> 'off')::int then
      cand := hz;
      for i in 1 .. na loop
        cand := cand || jsonb_build_array(jsonb_build_object('id', hid + i, 'k', 'num', 't', alive[i], 'i', i, 'left', i + 1));
      end loop;
      if public.world_ug_by_ok(p_fight, cand, nr, b) then hz := cand; hid := hid + na; cue := cue || '차례 화살'::text; end if;
    end if;
    if 'brush' = any (mechs) and ar % (rb -> 'brush' ->> 'every')::int = (rb -> 'brush' ->> 'off')::int then
      for s in select z from generate_series(1, 7) z order by random() loop
        cand := hz || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'brush', 's', s, 'left', (rb -> 'brush' ->> 'left')::int));
        if public.world_ug_by_ok(p_fight, cand, nr, b) then hz := cand; hid := hid + 1; cue := cue || '붉은 붓'::text; exit; end if;
      end loop;
    end if;
    if 'arrow' = any (mechs) and not b ? 'wn' and ar % (rb -> 'arrow' ->> 'every')::int = (rb -> 'arrow' ->> 'off')::int then
      nn := least(na, coalesce((rb -> 'arrow' -> 'n' ->> (least(4, greatest(1, n)) - 1))::int, 1));
      k := 0;
      for i in 1 .. na loop
        exit when k >= nn;
        select pos into c from public.world_gw_members where fight_id = p_fight and owner_id = alive[i];
        continue when c is null or exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'arrow' and (e ->> 'c')::int = c);
        cand := hz || jsonb_build_array(jsonb_build_object('id', hid + 1, 'k', 'arrow', 'c', c, 'left', (rb -> 'arrow' ->> 'left')::int));
        if public.world_ug_by_ok(p_fight, cand, nr, b) then hz := cand; hid := hid + 1; k := k + 1; end if;
      end loop;
      if k > 0 then cue := cue || '화살비'::text; end if;
    end if;
  end if;
  due := exists (select 1 from jsonb_array_elements(hz) e where (e ->> 'left')::int <= 0 and not coalesce((e ->> 'frozen')::boolean, false));
  if not b ? 'wn' and ar > 0 and ar % (rb ->> 'aoe_every')::int = 0 then aoe := true; end if;
  b := b || jsonb_build_object('hz', hz, 'hid', hid);
  m := jsonb_build_object('k', 'normal', 'phase_name', br -> 'phases' ->> (ph - 1), 'aoe', aoe, 'due', due, 'cue', to_jsonb(cue), 'lamps', coalesce(array_length(lamps, 1), 0),
    'mechs', to_jsonb(mechs), 'tell', case when due then '하얀 손끝이 떨린다.' else '사르륵사르륵, 하얀 몸 위로 이름 글자들이 종이 넘기는 소리를 낸다.' end)
    || case when b ? 'wn' then jsonb_build_object('wn', b -> 'wn') else '{}'::jsonb end;
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when due or b ? 'wn' then 10 else 5 end), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
end $f$;

create or replace function public.world_ug_by_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; b jsonb; na int; w record; x record; h jsonb; keep jsonb := '[]';
  lamps int[]; saved int[] := '{}'; wn jsonb; extra numeric := 0; cells int[]; fails int := 0; cnt int; lit_n int; nm text; c int; solo boolean; half numeric := case when p_broke then 0.5 else 1 end;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board;
  select count(*) into na from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  solo := na <= 1;
  lamps := array(select jsonb_array_elements_text(coalesce(b -> 'lamps', '[]'::jsonb))::int);
  wn := b -> 'wn';
  for w in select x2.* from public.world_gw_members x2 where x2.fight_id = p_fight and x2.out_rounds = 0 and not x2.rest and x2.act ->> 'a' = 'sweep' order by x2.joined_at loop
    c := nullif(w.act ->> 'c', '')::int;
    if c is null or not (c = w.pos or c = any (public.world_by_nb(w.pos))) then
      perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — 손이 닿지 않는 칸입니다(제 칸이나 바로 옆 칸만).'); continue;
    end if;
    cnt := (select count(*) from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) e where e ->> 'k' in ('arrow', 'big') and (e ->> 'c')::int = c
      and (e ->> 'left')::int <= 0 and not coalesce((e ->> 'frozen')::boolean, false));
    if cnt = 0 then
      perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — ' || c || '번 칸에는 지금 걷어 낼 화살이 없습니다(떨어지는 라운드에만).'); continue;
    end if;
    b := b || jsonb_build_object('hz', (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(b -> 'hz') e
      where not (e ->> 'k' in ('arrow', 'big') and (e ->> 'c')::int = c and (e ->> 'left')::int <= 0 and not coalesce((e ->> 'frozen')::boolean, false))));
    perform public.world_gw_say(p_fight, p_round, 'good', w.name || ' — ' || c || '번 칸으로 떨어지던 화살을 손으로 걷어 냈습니다.');
  end loop;
  for w in select x2.* from public.world_gw_members x2 where x2.fight_id = p_fight and x2.out_rounds = 0 and not x2.rest and x2.act ->> 'a' in ('item', 'coop') loop
    if jsonb_typeof(rb -> 'fade') = 'object' then
      if w.act ->> 'a' = 'item' then
        b := public.world_by_fade(p_fight, b, coalesce(nullif(w.act ->> 't', '')::uuid, w.owner_id), -(rb -> 'fade' ->> 'item')::int, p_round);
      elsif w.job_key = 'medic' and w.act ->> 't' is not null then
        b := public.world_by_fade(p_fight, b, (w.act ->> 't')::uuid, -(rb -> 'fade' ->> 'medic')::int, p_round);
      end if;
    end if;
  end loop;
  for c in select distinct x2.pos from public.world_gw_members x2 where x2.fight_id = p_fight and x2.out_rounds = 0 and not x2.rest and x2.act ->> 'a' = 'light' loop
    select string_agg(x2.name, '·') into nm from public.world_gw_members x2 where x2.fight_id = p_fight and x2.out_rounds = 0 and not x2.rest and x2.act ->> 'a' = 'light' and x2.pos = c;
    if c is null or c > 7 then
      perform public.world_gw_say(p_fight, p_round, 'miss', nm || ' — 등 기둥 칸(바깥 고리)에 서야 등을 켤 수 있습니다.'); continue;
    end if;
    if c = any (lamps) then
      if exists (select 1 from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) e where e ->> 'k' = 'gust' and (e ->> 's')::int = c and (e ->> 'left')::int <= 0) then
        saved := saved || c;
        perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — 꺼져 가던 ' || c || '번 등롱을 두 손으로 감싸 불씨를 지켰습니다.');
      else
        perform public.world_gw_say(p_fight, p_round, 'miss', c || '번 등은 켜져 있습니다.');
      end if;
      continue;
    end if;
    lamps := lamps || c;
    perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — ' || c || '번 등롱에 손을 얹자 등이 켜집니다.');
    if wn is not null then
      lit_n := (wn ->> 'lit')::int + 1;
      wn := wn || jsonb_build_object('lit', lit_n);
      perform public.world_gw_say(p_fight, p_round, 'voice', coalesce(rb -> 'voices' ->> (lit_n - 1), '누군가 부른다.'));
      if lit_n >= (wn ->> 'need')::int then
        extra := f.hp;
        perform public.world_gw_say(p_fight, p_round, 'good', '등이 모두 켜졌다. 하얀 몸에서 이름이 우수수 떨어진다.');
      else
        extra := extra + round((wn ->> 'hp')::numeric / (wn ->> 'need')::int);
      end if;
    end if;
  end loop;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    if (h ->> 'left')::int > 0 or coalesce((h ->> 'frozen')::boolean, false) then keep := keep || jsonb_build_array(h); continue; end if;
    cells := public.world_by_hz_cells(p_fight, h);
    if h ->> 'k' in ('arrow', 'brush') then
      select string_agg(y.name, '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells);
      if nm is not null then
        fails := fails + 1;
        perform public.world_gw_say(p_fight, p_round, 'boss', case when h ->> 'k' = 'arrow' then (h ->> 'c') || '번 칸에 화살이 떨어집니다! — ' else '붉은 붓이 마당 한쪽을 쓸고 지나갑니다! — ' end || nm);
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
          perform public.world_by_dmg(p_fight, x.owner_id, (rb -> (h ->> 'k') ->> 'raw')::numeric * half, p_round, case when h ->> 'k' = 'arrow' then '떨어진 화살에' else '붉은 붓에' end, false);
          b := public.world_by_fade(p_fight, b, x.owner_id, 1, p_round);
        end loop;
      end if;
    elsif h ->> 'k' = 'big' then
      fails := fails + 1;
      perform public.world_gw_say(p_fight, p_round, 'boss', '아무도 걷어 내지 않은 굵은 화살이 ' || (h ->> 'c') || '번 칸 둘레를 꿰뚫습니다!');
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
        perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'big' ->> 'raw')::numeric * half, p_round, '굵은 화살에', false);
        b := public.world_by_fade(p_fight, b, x.owner_id, 1, p_round);
      end loop;
      if wn is null and public.world_by_sector((h ->> 'c')::int) = any (lamps) then
        lamps := array_remove(lamps, public.world_by_sector((h ->> 'c')::int));
        perform public.world_gw_say(p_fight, p_round, 'bad', public.world_by_sector((h ->> 'c')::int) || '번 등이 화살에 꿰여 꺼졌습니다.');
      end if;
    elsif h ->> 'k' = 'gust' then
      if (h ->> 's')::int = any (saved) then continue; end if;
      fails := fails + 1;
      lamps := array_remove(lamps, (h ->> 's')::int);
      perform public.world_gw_say(p_fight, p_round, 'bad', (h ->> 's') || '번 등이 꺼지며 마당 전체에 흰 바람이 휘몰아칩니다!');
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
        perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'gust' ->> 'raw')::numeric * half, p_round, '흰 바람에', false);
      end loop;
    elsif h ->> 'k' = 'stack' then
      select count(*) into cnt from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells);
      select name into nm from public.world_gw_members where fight_id = p_fight and owner_id = (h ->> 't')::uuid;
      if cnt >= 2 or solo then
        perform public.world_gw_say(p_fight, p_round, 'good', '물방울이 ' || coalesce(nm, '') || ' 위에서 터졌지만 ' || cnt || '명이 함께 받아 흩어졌습니다.');
      else
        fails := fails + 1;
        perform public.world_gw_say(p_fight, p_round, 'bad', '물방울이 ' || coalesce(nm, '') || ' 위에서 홀로 터집니다.');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
          perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'drop' ->> 'stack_raw')::numeric * half, p_round, '홀로 받은 물방울에', false);
        end loop;
      end if;
    elsif h ->> 'k' in ('spread', 'num') then
      select name into nm from public.world_gw_members where fight_id = p_fight and owner_id = (h ->> 't')::uuid;
      cnt := 0;
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) and y.owner_id::text <> h ->> 't' loop
        perform public.world_by_dmg(p_fight, x.owner_id, (case when h ->> 'k' = 'spread' then (rb -> 'drop' ->> 'spread_raw') else (rb -> 'num' ->> 'raw') end)::numeric * half, p_round,
          case when h ->> 'k' = 'num' then (h ->> 'i') || '번 화살에' else '흰 가루에' end, false);
        b := public.world_by_fade(p_fight, b, x.owner_id, 1, p_round);
        perform public.world_gw_say(p_fight, p_round, 'bad', x.name || ' — ' || coalesce(nm, '') || ' 곁에 있다가 함께 바랬습니다.');
        cnt := cnt + 1;
      end loop;
      if cnt > 0 then fails := fails + 1; else perform public.world_gw_say(p_fight, p_round, 'good', coalesce(nm, '') || ' — 홀로 떨어져 서서 ' || case when h ->> 'k' = 'num' then (h ->> 'i') || '번 화살' else '흰 가루' end || '을(를) 흘려보냈습니다.'); end if;
    elsif h ->> 'k' = 'tower' then
      select count(*) into cnt from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = (h ->> 'c')::int;
      if cnt >= least(na, (h ->> 'need')::int) then
        perform public.world_gw_say(p_fight, p_round, 'good', (h ->> 'c') || '번 기둥을 ' || cnt || '명이 받아 냈습니다.');
      else
        fails := fails + 1;
        lamps := array_remove(lamps, (h ->> 'c')::int);
        perform public.world_gw_say(p_fight, p_round, 'bad', (h ->> 'c') || '번 기둥에 선 사람이 모자랍니다(' || cnt || '/' || (h ->> 'need') || '). 하얀 기둥이 무너지며 등을 덮습니다.');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
          perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'tower' ->> 'raw')::numeric * half, p_round, '무너진 기둥에', false);
        end loop;
      end if;
    elsif h ->> 'k' = 'clock' then
      select * into x from public.world_gw_members y where y.fight_id = p_fight and y.owner_id = (h ->> 't')::uuid;
      if x.owner_id is not null and x.out_rounds = 0 and x.act ? 'm' then
        fails := fails + 1;
        b := public.world_by_fade(p_fight, b, x.owner_id, coalesce((rb -> 'fade' ->> 'stun')::int, 3), p_round);
        perform public.world_gw_say(p_fight, p_round, 'bad', x.name || ' — 모래시계가 멈춘 순간 움직였습니다.');
      elsif x.owner_id is not null then
        perform public.world_gw_say(p_fight, p_round, 'good', x.name || ' — 숨을 죽이고 그 자리를 지켰습니다. 모래시계가 깨집니다.');
      end if;
    end if;
  end loop;
  b := b || jsonb_build_object('hz', keep, 'lamps', to_jsonb(coalesce(lamps, '{}'::int[])));
  if wn is not null then b := b || jsonb_build_object('wn', wn); end if;
  update public.world_gw_fights set board = b where fight_id = p_fight;
  perform public.world_ug_fail(p_fight, p_round, fails, coalesce((rb -> 'fail_party' ->> 'raw')::numeric, 0), true);
  return extra;
end $f$;

select pg_temp.yh_patch('public.world_gg_mech(uuid,integer,boolean,boolean,uuid[])',
  $o$  b := f.board; mx := coalesce((rb ->> 'max')::int, 9);$o$,
  $n$  if f.mode = 'ultimate' then return public.world_ug_gg_mech(p_fight, p_round, p_broke, p_delayed, p_freed); end if;
  b := f.board; mx := coalesce((rb ->> 'max')::int, 9);$n$);
select pg_temp.yh_patch('public.world_by_mech(uuid,integer,boolean,boolean,uuid[])',
  $o$  solo := na <= 1;$o$,
  $n$  if f.mode = 'ultimate' then return public.world_ug_by_mech(p_fight, p_round, p_broke, p_delayed, p_freed); end if;
  solo := na <= 1;$n$);

revoke all on function public.world_ug_nbm(text), public.world_ug_mask(int[]), public.world_ug_far(text, integer, integer), public.world_ug_viab(int[], integer, int[], boolean[]),
  public.world_ug_vreach(integer, int[], int[]), public.world_ug_vok(jsonb, jsonb, integer), public.world_ug_solve_rec(text, int[], int[], integer, int[], boolean[], text[], jsonb, integer, jsonb, jsonb),
  public.world_ug_vpick(int[], integer, integer), public.world_ug_solve(text, jsonb, integer, jsonb, integer), public.world_ug_mem(uuid), public.world_ug_gg_cons(uuid, jsonb, integer),
  public.world_ug_gg_ok(uuid, jsonb, integer), public.world_ug_gg_round(uuid), public.world_ug_fail(uuid, integer, integer, numeric, boolean),
  public.world_ug_gg_mech(uuid, integer, boolean, boolean, uuid[]), public.world_ug_by_cons(uuid, jsonb, integer, jsonb), public.world_ug_by_ok(uuid, jsonb, integer, jsonb),
  public.world_ug_by_round(uuid), public.world_ug_by_mech(uuid, integer, boolean, boolean, uuid[]) from public, anon, authenticated;
grant execute on function public.world_ug_nbm(text), public.world_ug_mask(int[]), public.world_ug_far(text, integer, integer), public.world_ug_viab(int[], integer, int[], boolean[]),
  public.world_ug_vreach(integer, int[], int[]), public.world_ug_vok(jsonb, jsonb, integer), public.world_ug_solve_rec(text, int[], int[], integer, int[], boolean[], text[], jsonb, integer, jsonb, jsonb),
  public.world_ug_vpick(int[], integer, integer), public.world_ug_solve(text, jsonb, integer, jsonb, integer), public.world_ug_mem(uuid), public.world_ug_gg_cons(uuid, jsonb, integer),
  public.world_ug_gg_ok(uuid, jsonb, integer), public.world_ug_gg_round(uuid), public.world_ug_fail(uuid, integer, integer, numeric, boolean),
  public.world_ug_gg_mech(uuid, integer, boolean, boolean, uuid[]), public.world_ug_by_cons(uuid, jsonb, integer, jsonb), public.world_ug_by_ok(uuid, jsonb, integer, jsonb),
  public.world_ug_by_round(uuid), public.world_ug_by_mech(uuid, integer, boolean, boolean, uuid[]) to service_role, fn_owner_field;

create or replace function public.world_ug_weak(p_fight uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare f record; w jsonb; k int; strong boolean;
begin
  select g.mode, g.boss_id, g.enrage into f from public.world_gw_fights g where g.fight_id = p_fight;
  if f.mode is distinct from 'ultimate' or f.boss_id not in ('gapgwi', 'baekya') or coalesce(f.enrage, 0) <= 0 then
    return jsonb_build_object('n', 0, 'deal', 1, 'take', 1);
  end if;
  w := public.world_boss_fight_rules(p_fight) -> 'board' -> 'weak';
  k := f.enrage; strong := k >= (w ->> 'strong_at')::int;
  return jsonb_build_object('n', k, 'strong', strong,
    'name', case when strong then w ->> 'strong_name' else w ->> 'name' end,
    'deal', case when strong then 1 - (w ->> 'strong_deal')::numeric else greatest(0.1, 1 - (w ->> 'deal')::numeric * k) end,
    'take', case when strong then 1 + (w ->> 'strong_take')::numeric + (w ->> 'more_take')::numeric * (k - (w ->> 'strong_at')::int) else 1 + (w ->> 'take')::numeric * k end);
end $f$;

select pg_temp.yh_patch('public.world_gw_hurt(uuid,uuid,integer,integer,text)',
  $o$d int := greatest(0, p_dmg); v_n int; v_out int;
begin$o$,
  $n$d int := greatest(0, p_dmg); v_n int; v_out int;
begin
  if d > 0 and exists (select 1 from public.world_gw_fights wf where wf.fight_id = p_fight and wf.mode = 'ultimate' and wf.enrage > 0 and wf.boss_id in ('gapgwi', 'baekya')) then
    d := round(d * (public.world_ug_weak(p_fight) ->> 'take')::numeric)::int;
  end if;$n$);

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$      if f.boss_id = 'baekya' then d := d * public.world_by_on_attack(p_fight, m.owner_id, r); end if;$o$,
  $n$      if f.boss_id = 'baekya' then d := d * public.world_by_on_attack(p_fight, m.owner_id, r); end if;
      if f.mode = 'ultimate' and f.enrage > 0 then d := d * (public.world_ug_weak(p_fight) ->> 'deal')::numeric; end if;$n$);

select pg_temp.yh_patch('public.world_ug_fail(uuid,integer,integer,numeric,boolean)',
  $o$declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; x record; cap int := coalesce((rb ->> 'fail_cap')::int, 3); e int; b jsonb;$o$,
  $n$declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; x record; e int; b jsonb; wk jsonb;$n$);
select pg_temp.yh_patch('public.world_ug_fail(uuid,integer,integer,numeric,boolean)',
  $o$  perform public.world_gw_say(p_fight, p_round, 'bad', '이야기꾼이 침을 튀긴다 — 「거기서 발을 헛디뎠지!」 실수 ' || least(e, cap) || '/' || cap || case when e >= cap then ' — 이야기가 그 자리에서 끝장난다.' else '. 모두가 함께 다친다.' end);$o$,
  $n$  wk := public.world_ug_weak(p_fight);
  perform public.world_gw_say(p_fight, p_round, 'bad', '이야기꾼이 침을 튀긴다 — 「거기서 발을 헛디뎠지!」 모두가 함께 다치고 「' || (wk ->> 'name') || '」 ' || e || '겹 — 주는 피해 ×' || round((wk ->> 'deal')::numeric, 2) || ' · 받는 피해 ×' || round((wk ->> 'take')::numeric, 2) || case when (wk ->> 'strong')::boolean then '. 이야기꾼이 고개를 젓는다.' else '.' end);$n$);

do $d$
declare o text;
begin
  for o in select distinct pg_get_userbyid(p.proowner) from pg_proc p where p.proname in ('world_gw_hurt', 'world_gw_resolve', 'world_ug_view', 'world_ug_fail', 'world_gw_snapshot') and pg_get_userbyid(p.proowner) like 'fn_owner%' loop
    execute format('grant execute on function public.world_ug_weak(uuid) to %I', o);
  end loop;
end $d$;
revoke all on function public.world_ug_weak(uuid) from public, anon, authenticated;
