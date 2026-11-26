create or replace function public.world_dh_nb(p_cell integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select array(select z from (values (p_cell - 4), (p_cell + 4), (case when (p_cell - 1) % 4 > 0 then p_cell - 1 end), (case when (p_cell - 1) % 4 < 3 then p_cell + 1 end)) v(z)
  where z between 1 and 16 order by z) $f$;

create or replace function public.world_dh_dist(p_a integer, p_b integer)
 returns integer language sql immutable set search_path = ''
as $f$ select case when p_a is null or p_b is null then 9 else abs((p_a - 1) / 4 - (p_b - 1) / 4) + abs((p_a - 1) % 4 - (p_b - 1) % 4) end $f$;

create or replace function public.world_dh_step(p_cell integer, p_dir text)
 returns integer language sql immutable set search_path = ''
as $f$ select case
  when p_dir = 'C' then public.world_dh_step(p_cell, case when abs(1.5 - (p_cell - 1) / 4) >= abs(1.5 - (p_cell - 1) % 4)
      then case when (p_cell - 1) / 4 < 2 then 'S' else 'N' end else case when (p_cell - 1) % 4 < 2 then 'E' else 'W' end end)
  when p_dir = 'N' and (p_cell - 1) / 4 > 0 then p_cell - 4
  when p_dir = 'S' and (p_cell - 1) / 4 < 3 then p_cell + 4
  when p_dir = 'W' and (p_cell - 1) % 4 > 0 then p_cell - 1
  when p_dir = 'E' and (p_cell - 1) % 4 < 3 then p_cell + 1 end $f$;

create or replace function public.world_dh_opp(p_dir text)
 returns text language sql immutable set search_path = ''
as $f$ select case p_dir when 'N' then 'S' when 'S' then 'N' when 'E' then 'W' when 'W' then 'E' else p_dir end $f$;

create or replace function public.world_dh_dirname(p_dir text)
 returns text language sql immutable set search_path = ''
as $f$ select case p_dir when 'N' then '위쪽' when 'S' then '아래쪽' when 'E' then '오른쪽' when 'W' then '왼쪽' else '가운데' end $f$;

create or replace function public.world_dh_rift(p_fight uuid, p_cell integer)
 returns boolean language sql stable security definer set search_path = pg_catalog, public
as $f$ select p_cell = any (array(select jsonb_array_elements_text(public.world_boss_fight_rules(p_fight) -> 'board' -> 'rift')::int)) $f$;

create or replace function public.world_dh_hurt_mul(p_fight uuid, p_uid uuid)
 returns numeric language sql stable security definer set search_path = pg_catalog, public
as $f$ select case when public.world_dh_rift(p_fight, m.pos) then 1 + coalesce((public.world_boss_fight_rules(p_fight) -> 'board' ->> 'rift_hurt')::numeric, 0) / 100.0 else 1 end
  from public.world_gw_members m where m.fight_id = p_fight and m.owner_id = p_uid $f$;

create or replace function public.world_dh_dmg(p_fight uuid, p_uid uuid, p_raw numeric, p_round integer, p_why text, p_guardable boolean)
 returns integer language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare m public.world_gw_members%rowtype; f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight);
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight;
  return public.world_gw_hurt(p_fight, p_uid, round(p_raw * coalesce((br -> 'board' ->> 'mech_mul')::numeric, 1) * (1 + coalesce((br ->> 'enrage')::numeric, 0) * f.enrage)
    * public.world_dh_hurt_mul(p_fight, p_uid) * case when p_guardable and coalesce(m.act ->> 'a', 'guard') in ('guard', 'brace') then 0.5 else 1 end)::int, p_round, p_why);
end $f$;

create or replace function public.world_dh_fall(p_fight uuid, p_uid uuid, p_round integer, p_why text)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare br jsonb := public.world_boss_fight_rules(p_fight); m public.world_gw_members%rowtype; fh numeric := (br -> 'board' ->> 'fall_hp')::numeric;
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if not found or m.out_rounds > 0 then return; end if;
  if fh is not null then
    perform public.world_gw_say(p_fight, p_round, 'bad', m.name || ' — ' || p_why || ' 틈으로 빨려 들 뻔했다가 간신히 빠져나왔습니다.');
    perform public.world_gw_hurt(p_fight, p_uid, fh::int, p_round, '틈의 물살에');
    update public.world_gw_members set pos = (select c from unnest(array[1, 4, 13, 16]) c order by public.world_dh_dist(c, m.pos), c limit 1) where fight_id = p_fight and owner_id = p_uid;
    return;
  end if;
  update public.world_gw_members set out_rounds = 9999, rest = false, falls = falls + 1 where fight_id = p_fight and owner_id = p_uid;
  update public.world_gw_fights set board = jsonb_set(coalesce(board, '{}'::jsonb), '{fell}', coalesce(board -> 'fell', '[]'::jsonb) || to_jsonb(p_uid::text)) where fight_id = p_fight;
  perform public.world_gw_say(p_fight, p_round, 'bad', m.name || ' — ' || p_why || ' 틈으로 빨려 들어갔습니다. 이 싸움에는 다시 돌아올 수 없습니다.');
end $f$;

create or replace function public.world_dh_push(p_fight uuid, p_uid uuid, p_dir text, p_n integer, p_round integer, p_why text, p_wet boolean, p_safe boolean default false)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; m public.world_gw_members%rowtype; n int := p_n; c int; nx int; i int; moved int := 0;
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if not found or m.out_rounds > 0 or m.rest or m.pos is null then return; end if;
  if coalesce(m.act ->> 'a', 'guard') = 'brace' then n := n - 1; end if;
  if p_wet and coalesce(m.gval, 0) >= coalesce((rb -> 'wet' ->> 'extra_at')::int, 99) then n := n + 1; end if;
  c := m.pos;
  for i in 1 .. greatest(0, n) loop
    nx := public.world_dh_step(c, p_dir);
    if nx is null then exit; end if;
    if public.world_dh_rift(p_fight, nx) and p_safe then exit; end if;
    if public.world_dh_rift(p_fight, nx) then
      update public.world_gw_members set prev = pos::text, pos = nx where fight_id = p_fight and owner_id = p_uid;
      perform public.world_dh_fall(p_fight, p_uid, p_round, p_why);
      return;
    end if;
    c := nx; moved := moved + 1;
  end loop;
  update public.world_gw_members set prev = pos::text, pos = c,
    gval = case when p_wet then least(coalesce((rb -> 'wet' ->> 'max')::int, 3), coalesce(gval, 0) + 1) else gval end
   where fight_id = p_fight and owner_id = p_uid;
end $f$;

create or replace function public.world_dh_seq(p_fight uuid, p_hp integer, p_max integer)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; e jsonb; pick jsonb; i int := -1; k int := 0; pct numeric := p_hp * 100.0 / greatest(1, p_max);
begin
  for e in select * from jsonb_array_elements(rb -> 'seq') loop
    if pct <= (e ->> 'at')::numeric then pick := e; i := k; end if;
    k := k + 1;
  end loop;
  return coalesce(pick, rb -> 'seq' -> 0) || jsonb_build_object('i', greatest(i, 0));
end $f$;

create or replace function public.world_dh_hz_cells(p_fight uuid, p_hz jsonb)
 returns integer[] language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare a int; b int;
begin
  if p_hz ->> 'k' = 'spray' then return array(select jsonb_array_elements_text(p_hz -> 'cells')::int); end if;
  if p_hz ->> 'k' in ('whirl') then return array[(p_hz ->> 'c')::int]; end if;
  if p_hz ->> 'k' in ('head', 'breath') then return array[(select (board ->> 'head')::int from public.world_gw_fights where fight_id = p_fight)]; end if;
  if p_hz ->> 'k' = 'tentacle' then
    select pos into a from public.world_gw_members where fight_id = p_fight and owner_id = (p_hz ->> 'a')::uuid;
    select pos into b from public.world_gw_members where fight_id = p_fight and owner_id = (p_hz ->> 'b')::uuid;
    return array_remove(array[a, b], null);
  end if;
  return '{}'::int[];
end $f$;

create or replace function public.world_dh_hp(p_fight uuid, p_n integer)
 returns integer language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare br jsonb := public.world_boss_fight_rules(p_fight); f public.world_gw_fights%rowtype; s numeric;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select coalesce(sum(coalesce((br -> 'dps' -> 'ref' ->> m.job_key)::numeric, 480)), 0) into s from public.world_gw_members m where m.fight_id = p_fight;
  return round(greatest((br ->> 'hp_min')::numeric, s * coalesce((br ->> 'hp_k')::numeric, (br -> 'dps' ->> 'hp_k')::numeric) * coalesce((br -> 'hp_n' ->> (least(4, p_n) - 1))::numeric, 1)));
end $f$;

create or replace function public.world_dh_begin(p_fight uuid, p_n integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; x record; k int := 0;
begin
  for x in select owner_id from public.world_gw_members where fight_id = p_fight order by joined_at, owner_id loop
    update public.world_gw_members set gval = 0, pos = (rb -> 'start' ->> (k % 4))::int, prev = null where fight_id = p_fight and owner_id = x.owner_id;
    k := k + 1;
  end loop;
  update public.world_gw_fights set board = coalesce(board, '{}'::jsonb) || jsonb_build_object('hz', '[]'::jsonb, 'hid', 0, 'seq', 0, 'head', (rb -> 'corner' ->> 0)::int,
    'fell', '[]'::jsonb, 'stun', 0, 'cut', 0, 'dir', 'E') where fight_id = p_fight;
  perform public.world_gw_say(p_fight, 0, 'phase', '물목이 거꾸로 돌기 시작한다. 가운데 갈라진 틈에 거대한 몸이 끼어 버둥거리고, 머리를 들 때마다 바닷물이 판 위로 넘친다.');
  perform public.world_gw_say(p_fight, 0, 'phase', '도해수는 바다로 돌아가려는 것뿐이다. 해류에 밀려 틈으로 빨려 들지 않게, 머리 칸에서 길을 알려 주어 제 바다로 돌려보내자.');
end $f$;

create or replace function public.world_dh_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb; b jsonb; nr int; ph int; m jsonb; tell text := '';
  n int; na int; alive uuid[]; hz jsonb := '[]'; h jsonb; cur jsonb; mechs text[]; story boolean; len int := 5; hid int; c int; k int; cells int[]; i int;
  due boolean := false; dir text; aoe boolean := false; cuts jsonb; cut int; hd int; corners int[]; nx int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  rb := br -> 'board'; b := coalesce(f.board, '{}'::jsonb); nr := f.round + 1; story := f.mode = 'story';
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  update public.world_gw_members set out_rounds = 9999, rest = false where fight_id = p_fight and owner_id::text in (select jsonb_array_elements_text(coalesce(b -> 'fell', '[]'::jsonb)));
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  select coalesce(array_agg(owner_id order by random()), '{}') into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  na := coalesce(array_length(alive, 1), 0);
  hid := coalesce((b ->> 'hid')::int, 0);
  corners := array(select jsonb_array_elements_text(rb -> 'corner')::int);
  cur := public.world_dh_seq(p_fight, f.hp, f.max_hp);
  mechs := array(select jsonb_array_elements_text(cur -> 'm'));
  if (cur ->> 'i')::int <> coalesce((b ->> 'seq')::int, 0) then
    hd := corners[1 + ((array_position(corners, coalesce((b ->> 'head')::int, corners[1])) - 1 + 1) % cardinality(corners))];
    b := b || jsonb_build_object('seq', (cur ->> 'i')::int, 'head', hd);
    perform public.world_gw_say(p_fight, nr, 'phase', case
      when 'breath' = any (mechs) then '틈이 숨을 들이쉰다. 판 위의 물이 한꺼번에 가운데로 쏠리기 시작한다. 「길을… 길을 알려 줘…」'
      when 'wet' = any (mechs) then '물보라가 그치지 않는다. 젖은 몸은 물살에 더 멀리 떠밀린다.'
      when 'whirl' = any (mechs) then '판 가장자리에 소용돌이 기둥이 솟는다. 해류를 따라 흘러 다닌다.'
      when 'tentacle' = any (mechs) then '틈 밑에서 촉수가 올라와 두 사람의 발목을 감는다.'
      when 'spray' = any (mechs) then '도해수가 몸을 비틀자 물보라가 칸 위로 쏟아질 자리를 고른다.'
      else '도해수가 버둥거린다.' end || ' 머리가 ' || (b ->> 'head') || '번 칸 쪽으로 돌아간다.');
  end if;
  if not story then
    cuts := br -> 'dps' -> 'cuts'; cut := coalesce((b ->> 'cut')::int, 0);
    if cuts is not null and cut < jsonb_array_length(cuts) and nr > (cuts ->> cut)::int then
      if f.hp * 4 > f.max_hp * (3 - cut) then
        update public.world_gw_fights set enrage = enrage + coalesce((br -> 'dps' ->> 'cut_enrage')::int, 1) where fight_id = p_fight;
        perform public.world_gw_say(p_fight, nr, 'bad', '도해수를 제때 달래지 못했습니다. 버둥거림이 거세집니다(받는 피해가 늘어납니다).');
      else
        perform public.world_gw_say(p_fight, nr, 'good', '제때 도해수를 달랬습니다. 버둥거림이 잦아듭니다.');
      end if;
      b := b || jsonb_build_object('cut', cut + 1);
    end if;
  end if;
  if coalesce((b ->> 'stun')::int, 0) > 0 then b := b || jsonb_build_object('stun', (b ->> 'stun')::int - 1); end if;
  dir := coalesce(b ->> 'dir', 'E');
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    if h ->> 'k' = 'whirl' then
      nx := public.world_dh_step((h ->> 'c')::int, dir);
      if nx is null or (h ->> 'life')::int <= 1 then continue; end if;
      h := h || jsonb_build_object('c', case when public.world_dh_rift(p_fight, nx) then (h ->> 'c')::int else nx end, 'life', (h ->> 'life')::int - 1);
    else
      h := h || jsonb_build_object('left', (h ->> 'left')::int - 1);
    end if;
    hz := hz || jsonb_build_array(h);
  end loop;
  if na > 0 then
    if 'current' = any (mechs) and nr % (rb -> 'current' ->> 'every')::int = (rb -> 'current' ->> 'off')::int and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' in ('current', 'surge')) then
      dir := (array['N', 'S', 'E', 'W'])[1 + floor(random() * 4)::int];
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'current', 'dir', dir, 'left', (rb -> 'current' ->> 'left')::int));
      b := b || jsonb_build_object('dir', dir);
      tell := tell || case when tell <> '' then ' ' else '' end || '해류가 ' || public.world_dh_dirname(dir) || '으로 흐른다.';
    end if;
    if 'surge' = any (mechs) and nr % (rb -> 'surge' ->> 'every')::int = (rb -> 'surge' ->> 'off')::int and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'surge') then
      hz := coalesce((select jsonb_agg(e) from jsonb_array_elements(hz) e where e ->> 'k' <> 'current'), '[]'::jsonb);
      dir := public.world_dh_opp(dir);
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'surge', 'dir', dir, 'left', (rb -> 'surge' ->> 'left')::int));
      b := b || jsonb_build_object('dir', dir);
      tell := tell || case when tell <> '' then ' ' else '' end || '해류가 뒤집힌다! ' || public.world_dh_dirname(dir) || '으로 두 칸 밀어낼 것이다.';
    end if;
    if 'spray' = any (mechs) and nr % (rb -> 'spray' ->> 'every')::int = (rb -> 'spray' ->> 'off')::int then
      cells := '{}';
      for i in 1 .. least(na, (rb -> 'spray' ->> 'cells')::int) loop
        select pos into c from public.world_gw_members where fight_id = p_fight and owner_id = alive[i];
        if c is not null and not (c = any (cells)) then cells := cells || c; end if;
      end loop;
      while cardinality(cells) < (rb -> 'spray' ->> 'cells')::int loop
        select z into c from generate_series(1, 16) z where not public.world_dh_rift(p_fight, z) and not (z = any (cells)) order by random() limit 1;
        cells := cells || c;
      end loop;
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'spray', 'cells', to_jsonb(cells), 'left', (rb -> 'spray' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '물보라가 ' || array_to_string(cells, '·') || '번 칸 위에서 부풀어 오른다.';
    end if;
    if 'tentacle' = any (mechs) and na >= 2 and nr % (rb -> 'tentacle' ->> 'every')::int = (rb -> 'tentacle' ->> 'off')::int then
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'tentacle', 'a', alive[1], 'b', alive[2], 'left', (rb -> 'tentacle' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '촉수가 두 사람을 묶는다. 세 칸 넘게 떨어져야 끊긴다.';
    end if;
    if 'whirl' = any (mechs) and nr % (rb -> 'whirl' ->> 'every')::int = (rb -> 'whirl' ->> 'off')::int then
      select z into c from generate_series(1, 16) z where not public.world_dh_rift(p_fight, z) and z <> all (corners)
        and not exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.pos = z) order by random() limit 1;
      if c is not null then
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'whirl', 'c', c, 'life', (rb -> 'whirl' ->> 'life')::int, 'left', 1));
        tell := tell || case when tell <> '' then ' ' else '' end || c || '번 칸에 소용돌이 기둥이 솟는다. 해류를 따라 흐른다.';
      end if;
    end if;
    if 'head' = any (mechs) and nr % (rb -> 'head' ->> 'every')::int = (rb -> 'head' ->> 'off')::int and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' in ('head', 'breath')) then
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'head', 'left', (rb -> 'head' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '도해수가 머리를 든다. 머리 칸에서 길을 알려 주면 크게 휘청인다.';
    end if;
    if 'breath' = any (mechs) and nr % (rb -> 'breath' ->> 'every')::int = (rb -> 'breath' ->> 'off')::int and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'breath') then
      hz := coalesce((select jsonb_agg(e) from jsonb_array_elements(hz) e where e ->> 'k' <> 'head'), '[]'::jsonb);
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'breath', 'left', (rb -> 'breath' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '틈이 숨을 들이쉰다! 절반 넘게 머리 칸에서 길을 알려 주지 않으면 모두 가운데로 끌려간다.';
    end if;
    aoe := 'thrash' = any (mechs) and nr % coalesce((rb ->> 'aoe_every')::int, 4) = 0;
  end if;
  if exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' <> 'whirl' and (e ->> 'left')::int <= 0) then due := true; end if;
  if tell = '' then tell := '도해수가 틈 속에서 낮게 운다. 물이 판 가장자리를 핥는다.'; end if;
  b := b || jsonb_build_object('hz', hz, 'hid', hid);
  m := jsonb_build_object('k', 'normal', 'phase_name', br -> 'phases' ->> (ph - 1), 'aoe', aoe, 'tell', tell, 'mechs', to_jsonb(mechs));
  if due then len := 10; end if;
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when not story then len when n = 1 then 86400 else (br ->> 'round_s')::int end), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, nr, case when due then 'warn' else 'tell' end, tell);
end $f$;

create or replace function public.world_dh_steps(p_fight uuid, p_round integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare x record; t int;
begin
  for x in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ? 'm' order by joined_at, owner_id loop
    t := (x.act ->> 'm')::int;
    if t = any (public.world_dh_nb(x.pos)) then
      update public.world_gw_members set prev = pos::text, pos = t where fight_id = p_fight and owner_id = x.owner_id;
    end if;
  end loop;
end $f$;

create or replace function public.world_dh_on_attack(p_fight uuid, p_uid uuid, p_round integer, p_d numeric)
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  return p_d * case when coalesce((f.board ->> 'stun')::int, 0) > 0 then 1 + coalesce((rb -> 'head' ->> 'stun_pct')::numeric, 0) / 100.0 else 1 end;
end $f$;

create or replace function public.world_dh_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; b jsonb; x record; h jsonb; keep jsonb := '[]';
  extra numeric := 0; cells int[]; na int; ng int; nm text; wet boolean; mechs text[]; hd int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; hd := (b ->> 'head')::int;
  mechs := array(select jsonb_array_elements_text(coalesce(f.mech -> 'mechs', '[]'::jsonb)));
  wet := 'wet' = any (mechs);
  select count(*) into na from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  select count(*), string_agg(y.name, '·') into ng, nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'guide' and y.pos = hd;
  if ng > 0 then
    update public.world_gw_members y set gval = 0 where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'guide' and y.pos = hd;
  end if;
  for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'guide' and y.pos is distinct from hd loop
    perform public.world_gw_say(p_fight, p_round, 'miss', x.name || ' — 머리 칸(' || hd || '번)에 서야 길을 알려 줄 수 있습니다.');
  end loop;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    if h ->> 'k' = 'whirl' then
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = (h ->> 'c')::int loop
        perform public.world_gw_say(p_fight, p_round, 'bad', x.name || ' — 소용돌이 기둥에 휘말렸습니다.');
        perform public.world_dh_dmg(p_fight, x.owner_id, (rb -> 'whirl' ->> 'raw')::numeric, p_round, '소용돌이에', false);
        perform public.world_dh_push(p_fight, x.owner_id, coalesce(b ->> 'dir', 'E'), 1, p_round, '소용돌이에 휘말려', wet, true);
      end loop;
      keep := keep || jsonb_build_array(h); continue;
    end if;
    if (h ->> 'left')::int > 0 then keep := keep || jsonb_build_array(h); continue; end if;
    cells := public.world_dh_hz_cells(p_fight, h);
    if h ->> 'k' in ('current', 'surge') then
      perform public.world_gw_say(p_fight, p_round, 'boss', case when h ->> 'k' = 'surge' then '뒤집힌 해류가 ' else '해류가 ' end || public.world_dh_dirname(h ->> 'dir') || '으로 판을 쓸고 지나갑니다!');
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest order by y.joined_at loop
        perform public.world_dh_push(p_fight, x.owner_id, h ->> 'dir', case when h ->> 'k' = 'surge' then (rb -> 'surge' ->> 'push')::int else 1 end, p_round, '해류에 떠밀려', wet);
      end loop;
    elsif h ->> 'k' = 'spray' then
      perform public.world_gw_say(p_fight, p_round, 'boss', '물보라가 ' || array_to_string(cells, '·') || '번 칸을 덮칩니다!');
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
        perform public.world_dh_dmg(p_fight, x.owner_id, (rb -> 'spray' ->> 'raw')::numeric * case when p_broke then 0.5 else 1 end, p_round, '물보라에', true);
        if wet then update public.world_gw_members set gval = least(coalesce((rb -> 'wet' ->> 'max')::int, 3), coalesce(gval, 0) + 1) where fight_id = p_fight and owner_id = x.owner_id; end if;
      end loop;
    elsif h ->> 'k' = 'tentacle' then
      if cardinality(cells) = 2 and public.world_dh_dist(cells[1], cells[2]) < (rb -> 'tentacle' ->> 'dist')::int then
        perform public.world_gw_say(p_fight, p_round, 'bad', '촉수가 끊기지 않았습니다. 묶인 두 사람이 틈 가장자리까지 끌려가 세게 조입니다.');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.owner_id in ((h ->> 'a')::uuid, (h ->> 'b')::uuid) loop
          perform public.world_dh_dmg(p_fight, x.owner_id, (rb -> 'tentacle' ->> 'raw')::numeric, p_round, '촉수에', false);
          perform public.world_dh_push(p_fight, x.owner_id, 'C', 1, p_round, '촉수에 끌려', false, true);
        end loop;
      else
        perform public.world_gw_say(p_fight, p_round, 'good', '멀리 떨어져 선 두 사람 사이에서 촉수가 툭 끊어졌습니다.');
      end if;
    elsif h ->> 'k' = 'head' then
      if ng > 0 then
        extra := extra + round(f.max_hp * (rb -> 'head' ->> 'hit_pct')::numeric / 100.0);
        b := b || jsonb_build_object('stun', coalesce((rb -> 'head' ->> 'stun')::int, 0));
        perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — 머리 칸에서 바다 쪽 길을 알려 주었습니다. 도해수가 그쪽으로 몸을 틀며 크게 휘청입니다.');
      else
        perform public.world_gw_say(p_fight, p_round, 'bad', '아무도 길을 알려 주지 않았습니다. 도해수가 머리를 거칠게 내젓습니다.');
      end if;
    elsif h ->> 'k' = 'breath' then
      if ng * 2 >= na and ng > 0 then
        extra := extra + round(f.max_hp * (rb -> 'head' ->> 'hit_pct')::numeric / 100.0);
        perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — 길을 알려 주어 틈의 숨을 막았습니다.');
      else
        perform public.world_gw_say(p_fight, p_round, 'boss', '틈이 숨을 들이쉽니다! 판 위의 물이 가운데로 쏠립니다.');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest order by y.joined_at loop
          perform public.world_dh_push(p_fight, x.owner_id, 'C', (rb -> 'breath' ->> 'pull')::int, p_round, '틈의 숨에 끌려', false);
        end loop;
      end if;
    end if;
  end loop;
  update public.world_gw_fights set board = (select board from public.world_gw_fights where fight_id = p_fight) || jsonb_build_object('hz', keep, 'stun', coalesce((b ->> 'stun')::int, 0))
   where fight_id = p_fight;
  return extra;
end $f$;

create or replace function public.world_dh_after(p_fight uuid, p_round integer)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return true; end if;
  if not exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds < 9999) then
    perform public.world_gw_say(p_fight, p_round, 'bad', '모두 틈으로 빨려 들어갔습니다. 물목이 다시 거꾸로 돌기 시작합니다.');
    perform public.world_gw_settle(p_fight, false);
    return true;
  end if;
  if not coalesce((f.board ->> 'low')::boolean, false) and f.hp > 0 and f.hp * 100 < f.max_hp * coalesce((rb ->> 'low_pct')::numeric, 10) then
    perform public.world_gw_say(p_fight, p_round, 'boss', '도해수의 버둥거림이 느려진다. 틈에 끼였던 몸이 조금씩 바다 쪽으로 미끄러진다.');
    update public.world_gw_fights set board = board || '{"low": true}'::jsonb where fight_id = p_fight;
  end if;
  return false;
end $f$;

create or replace function public.world_dh_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb := br -> 'board'; f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; b jsonb; cur jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  b := coalesce(f.board, '{}'::jsonb);
  cur := public.world_dh_seq(p_fight, f.hp, f.max_hp);
  return jsonb_build_object(
    'phase_name', br -> 'phases' ->> (f.phase - 1), 'phases', br -> 'phases', 'mechs', cur -> 'm', 'mech_names', br -> 'mech_names',
    'rift', rb -> 'rift', 'head', (b ->> 'head')::int, 'dir', b ->> 'dir', 'stun', coalesce((b ->> 'stun')::int, 0), 'fell', coalesce(b -> 'fell', '[]'::jsonb),
    'wet', (select coalesce(jsonb_object_agg(x.owner_id::text, coalesce(x.gval, 0)), '{}'::jsonb) from public.world_gw_members x where x.fight_id = p_fight),
    'wet_max', coalesce((rb -> 'wet' ->> 'max')::int, 3), 'mine', me.gval, 'my_pos', me.pos,
    'moves', case when me.pos is not null and f.status = 'fight' and me.out_rounds = 0 then to_jsonb(public.world_dh_nb(me.pos)) else '[]'::jsonb end,
    'cut', case when f.mode <> 'story' and br -> 'dps' -> 'cuts' is not null then jsonb_build_object('i', coalesce((b ->> 'cut')::int, 0), 'cuts', br -> 'dps' -> 'cuts',
      'next', (br -> 'dps' -> 'cuts' ->> coalesce((b ->> 'cut')::int, 0))::int) end,
    'hz', (select coalesce(jsonb_agg(e || jsonb_build_object('cells', to_jsonb(public.world_dh_hz_cells(p_fight, e)))), '[]'::jsonb)
      from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) e));
end $f$;
