create or replace function public.world_du_qr(p_cell integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select array[(public.world_boss_rules() -> 'ttangul' -> 'board' -> 'cells' -> (p_cell - 1) ->> 0)::int, (public.world_boss_rules() -> 'ttangul' -> 'board' -> 'cells' -> (p_cell - 1) ->> 1)::int] $f$;

create or replace function public.world_du_cell(p_q integer, p_r integer)
 returns integer language sql immutable set search_path = ''
as $f$ select (select o::int from jsonb_array_elements(public.world_boss_rules() -> 'ttangul' -> 'board' -> 'cells') with ordinality e(v, o)
  where (e.v ->> 0)::int = p_q and (e.v ->> 1)::int = p_r) $f$;

create or replace function public.world_du_ring(p_cell integer)
 returns integer language sql immutable set search_path = ''
as $f$ select greatest(abs(q[1]), abs(q[2]), abs(q[1] + q[2])) from (select public.world_du_qr(p_cell) q) x $f$;

create or replace function public.world_du_dir(p_d integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select (array[array[1,0], array[1,-1], array[0,-1], array[-1,0], array[-1,1], array[0,1]])[1 + ((p_d % 6) + 6) % 6:1 + ((p_d % 6) + 6) % 6][1:2] $f$;

create or replace function public.world_du_step(p_cell integer, p_d integer)
 returns integer language sql immutable set search_path = ''
as $f$ select public.world_du_cell(q[1] + d[1][1], q[2] + d[1][2]) from (select public.world_du_qr(p_cell) q, public.world_du_dir(p_d) d) x $f$;

create or replace function public.world_du_out(p_cell integer)
 returns integer language sql immutable set search_path = ''
as $f$ select d from generate_series(0, 5) d, (select public.world_du_qr(p_cell) q) x
  order by greatest(abs(x.q[1] + (public.world_du_dir(d))[1][1]), abs(x.q[2] + (public.world_du_dir(d))[1][2]), abs(x.q[1] + (public.world_du_dir(d))[1][1] + x.q[2] + (public.world_du_dir(d))[1][2])) desc,
    abs(x.q[1] * (public.world_du_dir(d))[1][1] + x.q[2] * (public.world_du_dir(d))[1][2] + 0) desc, d limit 1 $f$;

create or replace function public.world_du_open(p_fight uuid, p_cell integer)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare b jsonb;
begin
  if p_cell is null or p_cell = 10 then return false; end if;
  select board into b from public.world_gw_fights where fight_id = p_fight;
  if coalesce((b ->> 'gone')::boolean, false) and public.world_du_ring(p_cell) = 2 then return false; end if;
  if coalesce(b -> 'holes', '{}'::jsonb) ? p_cell::text then return false; end if;
  return true;
end $f$;

create or replace function public.world_du_nb(p_cell integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select array(select z from (select public.world_du_step(p_cell, d) z from generate_series(0, 5) d) s where z is not null and z <> 10 order by z) $f$;

create or replace function public.world_du_dmg(p_fight uuid, p_uid uuid, p_raw numeric, p_round integer, p_why text, p_guard numeric)
 returns integer language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare m public.world_gw_members%rowtype; f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight);
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight;
  return public.world_gw_hurt(p_fight, p_uid, round(p_raw * coalesce((br -> 'board' ->> 'mech_mul')::numeric, 1) * (1 + coalesce((br ->> 'enrage')::numeric, 0) * f.enrage)
    * (1 - coalesce((m.stats ->> 'solo_guard')::numeric, 0) / 100.0) * case when coalesce(m.act ->> 'a', 'guard') in ('guard', 'brace') then p_guard else 1 end)::int, p_round, p_why);
end $f$;

create or replace function public.world_du_fall(p_fight uuid, p_uid uuid, p_round integer, p_why text)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare br jsonb := public.world_boss_fight_rules(p_fight); m public.world_gw_members%rowtype; fh numeric := (br -> 'board' ->> 'fall_hp')::numeric;
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if not found or m.out_rounds > 0 then return; end if;
  if fh is not null then
    perform public.world_gw_say(p_fight, p_round, 'bad', m.name || ' — ' || p_why || ' 구덩이로 미끄러졌다가 간신히 기어 올라왔습니다.');
    perform public.world_gw_hurt(p_fight, p_uid, fh::int, p_round, '구덩이에');
    update public.world_gw_members set pos = (select c from unnest(array[5, 9, 11, 15, 6, 14]) c where public.world_du_open(p_fight, c) order by random() limit 1) where fight_id = p_fight and owner_id = p_uid;
    return;
  end if;
  update public.world_gw_members set out_rounds = 9999, rest = false, falls = falls + 1, gval = 0 where fight_id = p_fight and owner_id = p_uid;
  update public.world_gw_fights set board = jsonb_set(coalesce(board, '{}'::jsonb), '{fell}', coalesce(board -> 'fell', '[]'::jsonb) || to_jsonb(p_uid::text)) where fight_id = p_fight;
  perform public.world_gw_say(p_fight, p_round, 'bad', m.name || ' — ' || p_why || ' 고임 구덩이로 떨어졌습니다. 이 싸움에는 다시 돌아올 수 없습니다.');
end $f$;

create or replace function public.world_du_push(p_fight uuid, p_uid uuid, p_dir integer, p_n integer, p_round integer, p_why text)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare m public.world_gw_members%rowtype; n int := p_n; c int; nx int; i int; d int;
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if not found or m.out_rounds > 0 or m.rest or m.pos is null then return; end if;
  if coalesce(m.act ->> 'a', 'guard') = 'brace' then n := n - 1; end if;
  c := m.pos;
  for i in 1 .. greatest(0, n) loop
    d := coalesce(p_dir, public.world_du_out(c));
    nx := public.world_du_step(c, d);
    if nx = 10 then exit; end if;
    if nx is null or not public.world_du_open(p_fight, nx) then
      update public.world_gw_members set prev = pos::text where fight_id = p_fight and owner_id = p_uid;
      perform public.world_du_fall(p_fight, p_uid, p_round, p_why);
      return;
    end if;
    c := nx;
  end loop;
  update public.world_gw_members set prev = pos::text, pos = c where fight_id = p_fight and owner_id = p_uid;
end $f$;

create or replace function public.world_du_seq(p_fight uuid, p_hp integer, p_max integer)
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

create or replace function public.world_du_slide_cells(p_dir integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select array(select c from generate_series(1, 19) c where c <> 10
  and (public.world_du_qr(c))[1] * (public.world_du_dir(p_dir))[1][1] + (public.world_du_qr(c))[2] * (public.world_du_dir(p_dir))[1][2]
      + 0.5 * ((public.world_du_qr(c))[1] * (public.world_du_dir(p_dir))[1][2] + (public.world_du_qr(c))[2] * (public.world_du_dir(p_dir))[1][1]) > 0.4
  and public.world_du_out(c) in (((p_dir) % 6 + 6) % 6, ((p_dir + 1) % 6 + 6) % 6, ((p_dir + 5) % 6 + 6) % 6) order by c) $f$;

create or replace function public.world_du_line(p_cell integer, p_dir integer)
 returns integer[] language plpgsql immutable set search_path = ''
as $f$
declare c int := p_cell; out int[] := '{}'; i int;
begin
  for i in 1 .. 4 loop c := public.world_du_step(c, p_dir + 3); exit when c is null; end loop;
  c := coalesce(c, p_cell);
  c := p_cell;
  while public.world_du_step(c, p_dir + 3) is not null loop c := public.world_du_step(c, p_dir + 3); end loop;
  while c is not null loop
    if c <> 10 then out := out || c; end if;
    c := public.world_du_step(c, p_dir);
  end loop;
  return out;
end $f$;

create or replace function public.world_du_hz_cells(p_fight uuid, p_hz jsonb)
 returns integer[] language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
begin
  if p_hz ->> 'k' in ('weight', 'boulder', 'slide') then return array(select jsonb_array_elements_text(p_hz -> 'cells')::int); end if;
  if p_hz ->> 'k' = 'pull' then return array[(p_hz ->> 'c')::int]; end if;
  if p_hz ->> 'k' = 'fist' then return array_remove(array[(select pos from public.world_gw_members where fight_id = p_fight and owner_id = (p_hz ->> 't')::uuid)], null); end if;
  if p_hz ->> 'k' = 'shave' then return array(select c from generate_series(1, 19) c where public.world_du_ring(c) = 2); end if;
  return '{}'::int[];
end $f$;

create or replace function public.world_du_hp(p_fight uuid, p_n integer)
 returns integer language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare br jsonb := public.world_boss_fight_rules(p_fight); s numeric;
begin
  select coalesce(sum(coalesce((br -> 'dps' -> 'ref' ->> m.job_key)::numeric, 480)), 0) into s from public.world_gw_members m where m.fight_id = p_fight;
  return round(greatest((br ->> 'hp_min')::numeric, s * coalesce((br ->> 'hp_k')::numeric, (br -> 'dps' ->> 'hp_k')::numeric) * coalesce((br -> 'hp_n' ->> (least(4, p_n) - 1))::numeric, 1)));
end $f$;

create or replace function public.world_du_begin(p_fight uuid, p_n integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; x record; k int := 0; pulls jsonb := '{}';
begin
  for x in select owner_id from public.world_gw_members where fight_id = p_fight order by joined_at, owner_id loop
    update public.world_gw_members set gval = 0, pos = (rb -> 'start' ->> (k % 4))::int, prev = null where fight_id = p_fight and owner_id = x.owner_id;
    k := k + 1;
  end loop;
  select jsonb_object_agg(c, 0) into pulls from jsonb_array_elements_text(rb -> 'pulls') c;
  update public.world_gw_fights set board = coalesce(board, '{}'::jsonb) || jsonb_build_object('hz', '[]'::jsonb, 'hid', 0, 'seq', 0, 'holes', '{}'::jsonb, 'cracked', '[]'::jsonb,
    'wedges', '[]'::jsonb, 'pulls', pulls, 'gone', false, 'final', 0, 'fell', '[]'::jsonb, 'cut', 0) where fight_id = p_fight;
  perform public.world_gw_say(p_fight, 0, 'phase', '고임터 바닥이 울린다. 막힌 지맥에 부풀어 오른 거대한 몸이 돌판 한가운데서 고개를 든다. 판 바깥은 빛이 고인 깊은 구덩이다.');
  perform public.world_gw_say(p_fight, 0, 'phase', '땅울이는 막힌 흐름에 아파 날뛸 뿐이다. 끌개를 멈추고 판 위에서 버텨, 흐름을 되돌려 진정시키자.');
end $f$;

create or replace function public.world_du_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb; b jsonb; nr int; ph int; m jsonb; tell text := '';
  n int; na int; alive uuid[]; hz jsonb := '[]'; h jsonb; cur jsonb; mechs text[]; story boolean; len int := 5; hid int; c int; cells int[]; i int; d int;
  due boolean := false; aoe boolean := false; cuts jsonb; cut int; holes jsonb; k text; pulls jsonb; t uuid; fin int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  rb := br -> 'board'; b := coalesce(f.board, '{}'::jsonb); nr := f.round + 1; story := f.mode = 'story';
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  update public.world_gw_members set out_rounds = 9999, rest = false where fight_id = p_fight and owner_id::text in (select jsonb_array_elements_text(coalesce(b -> 'fell', '[]'::jsonb)));
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  select coalesce(array_agg(owner_id order by random()), '{}') into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  na := coalesce(array_length(alive, 1), 0);
  hid := coalesce((b ->> 'hid')::int, 0);
  holes := '{}';
  for k in select jsonb_object_keys(coalesce(b -> 'holes', '{}'::jsonb)) loop
    if (b -> 'holes' ->> k)::int > 50 then holes := holes || jsonb_build_object(k, 99);
    elsif (b -> 'holes' ->> k)::int > 1 then holes := holes || jsonb_build_object(k, (b -> 'holes' ->> k)::int - 1); end if;
  end loop;
  b := b || jsonb_build_object('holes', holes);
  cur := public.world_du_seq(p_fight, f.hp, f.max_hp);
  mechs := array(select jsonb_array_elements_text(cur -> 'm'));
  if (cur ->> 'i')::int <> coalesce((b ->> 'seq')::int, 0) then
    b := b || jsonb_build_object('seq', (cur ->> 'i')::int);
    perform public.world_gw_say(p_fight, nr, 'phase', case
      when 'shave' = any (mechs) then '땅울이가 온 힘으로 땅을 내리친다. 돌판 바깥 고리에 금이 쩍쩍 번진다. 곧 무너진다!'
      when 'fist' = any (mechs) then '땅울이가 돌을 뭉쳐 주먹을 쥔다. 판 가장자리 너머로 바위가 구르기 시작한다.'
      when 'pull' = any (mechs) then '바깥 고리의 끌개 넷이 돌기 시작한다. 끌개가 돌 때마다 땅울이에게 흐름이 몰린다.'
      when 'slide' = any (mechs) then '땅울이가 한쪽으로 몸을 기울인다. 그쪽 돌판에 흙더미가 쌓인다.'
      else '땅울이가 울부짖는다.' end);
  end if;
  if not story then
    cuts := br -> 'dps' -> 'cuts'; cut := coalesce((b ->> 'cut')::int, 0);
    if cuts is not null and cut < jsonb_array_length(cuts) and nr > (cuts ->> cut)::int then
      if f.hp * 4 > f.max_hp * (3 - cut) then
        update public.world_gw_fights set enrage = enrage + coalesce((br -> 'dps' ->> 'cut_enrage')::int, 1) where fight_id = p_fight;
        perform public.world_gw_say(p_fight, nr, 'bad', '땅울이를 제때 달래지 못했습니다. 울음이 거세집니다(받는 피해가 늘어납니다).');
      else
        perform public.world_gw_say(p_fight, nr, 'good', '제때 땅울이를 달랬습니다. 땅울음이 잦아듭니다.');
      end if;
      b := b || jsonb_build_object('cut', cut + 1);
    end if;
  end if;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    h := h || jsonb_build_object('left', (h ->> 'left')::int - 1);
    hz := hz || jsonb_build_array(h);
  end loop;
  fin := coalesce((b ->> 'final')::int, 0);
  if na > 0 then
    if fin > 0 then
      d := floor(random() * 6)::int;
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'tilt', 'dir', d, 'left', 0));
      tell := '돌판이 크게 기운다! 이번 라운드에 버티지 않으면 판 밖으로 미끄러진다.';
      b := b || jsonb_build_object('final', fin - 1);
    else
    if 'pull' = any (mechs) and not coalesce((b ->> 'gone')::boolean, false) then
      pulls := coalesce(b -> 'pulls', '{}');
      if nr % (rb -> 'pull' ->> 'every')::int = 0 then
        k := rb -> 'pulls' ->> ((nr / (rb -> 'pull' ->> 'every')::int) % jsonb_array_length(rb -> 'pulls'));
        if coalesce((pulls ->> k)::int, 0) <= nr and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'pull' and e ->> 'c' = k) then
          hid := hid + 1;
          hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'pull', 'c', k::int, 'left', (rb -> 'pull' ->> 'left')::int));
          tell := tell || case when tell <> '' then ' ' else '' end || k || '번 끌개가 돌기 시작한다. 쐐기돌을 들고 그 칸에 서라.';
          if jsonb_array_length(coalesce(b -> 'wedges', '[]'::jsonb)) = 0 and not exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and coalesce(y.gval, 0) > 0) then
            select z into c from generate_series(1, 19) z where public.world_du_ring(z) = 1 and public.world_du_open(p_fight, z)
              and not exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.pos = z) order by random() limit 1;
            if c is not null then b := b || jsonb_build_object('wedges', jsonb_build_array(c)); end if;
          end if;
        end if;
      end if;
    end if;
    if 'slide' = any (mechs) and nr % (rb -> 'slide' ->> 'every')::int = (rb -> 'slide' ->> 'off')::int then
      d := floor(random() * 6)::int;
      cells := public.world_du_slide_cells(d);
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'slide', 'dir', d, 'cells', to_jsonb(cells), 'left', (rb -> 'slide' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '땅울이가 한쪽으로 몸을 기울인다. 그쪽 흙더미가 곧 바깥으로 쓸려 나간다.';
    end if;
    if 'weight' = any (mechs) and nr % (rb -> 'weight' ->> 'every')::int = (rb -> 'weight' ->> 'off')::int then
      cells := '{}';
      for i in 1 .. least(na, (rb -> 'weight' ->> 'cells')::int) loop
        select pos into c from public.world_gw_members where fight_id = p_fight and owner_id = alive[i];
        if c is not null and public.world_du_open(p_fight, c) and not (c = any (cells)) then cells := cells || c; end if;
      end loop;
      while cardinality(cells) < (rb -> 'weight' ->> 'cells')::int loop
        select z into c from generate_series(1, 19) z where z <> 10 and public.world_du_open(p_fight, z) and not (z = any (cells)) order by random() limit 1;
        exit when c is null;
        cells := cells || c;
      end loop;
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'weight', 'cells', to_jsonb(cells), 'left', (rb -> 'weight' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || array_to_string(cells, '·') || '번 돌판이 땅의 무게에 내려앉으려 한다.';
    end if;
    if 'fist' = any (mechs) and nr % (rb -> 'fist' ->> 'every')::int = (rb -> 'fist' ->> 'off')::int then
      select m2.owner_id into t from public.world_gw_members m2 where m2.fight_id = p_fight and m2.out_rounds = 0 and not m2.rest
        order by coalesce((m2.stats ->> 'presence')::numeric, 30) desc, random() limit 1;
      if t is not null then
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'fist', 't', t, 'left', (rb -> 'fist' ->> 'left')::int));
        tell := tell || case when tell <> '' then ' ' else '' end || '땅울이가 돌주먹을 쥐고 가장 눈에 띄는 이를 노린다.';
      end if;
    end if;
    if 'boulder' = any (mechs) and nr % (rb -> 'boulder' ->> 'every')::int = (rb -> 'boulder' ->> 'off')::int then
      d := floor(random() * 3)::int;
      select pos into c from public.world_gw_members where fight_id = p_fight and owner_id = alive[1];
      cells := public.world_du_line(coalesce(c, 9), d);
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'boulder', 'dir', d, 'cells', to_jsonb(cells), 'left', (rb -> 'boulder' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '판 가장자리 너머에서 바위가 한 줄로 굴러온다.';
    end if;
    if 'shave' = any (mechs) and not coalesce((b ->> 'gone')::boolean, false) and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'shave') then
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'shave', 'left', (rb -> 'shave' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '바깥 고리가 무너지려 한다! 안쪽 여섯 칸으로 들어서라.';
    end if;
    aoe := 'thrash' = any (mechs) and nr % coalesce((rb ->> 'aoe_every')::int, 4) = 0;
    end if;
  end if;
  if exists (select 1 from jsonb_array_elements(hz) e where (e ->> 'left')::int <= 0) then due := true; end if;
  if tell = '' then tell := '땅울이가 낮게 운다. 돌판 밑으로 흐름이 꿈틀거린다.'; end if;
  b := b || jsonb_build_object('hz', hz, 'hid', hid);
  m := jsonb_build_object('k', 'normal', 'phase_name', br -> 'phases' ->> (ph - 1), 'aoe', aoe, 'tell', tell, 'mechs', to_jsonb(mechs));
  if due then len := 10; end if;
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when not story then len when n = 1 then 86400 else (br ->> 'round_s')::int end), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, nr, case when due then 'warn' else 'tell' end, tell);
end $f$;

create or replace function public.world_du_steps(p_fight uuid, p_round integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare x record; t int; b jsonb;
begin
  for x in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ? 'm' order by joined_at, owner_id loop
    t := (x.act ->> 'm')::int;
    if t = any (public.world_du_nb(x.pos)) then
      if not public.world_du_open(p_fight, t) then
        perform public.world_du_fall(p_fight, x.owner_id, p_round, '무너진 자리에 발을 디뎌');
        continue;
      end if;
      update public.world_gw_members set prev = pos::text, pos = t where fight_id = p_fight and owner_id = x.owner_id;
      select board into b from public.world_gw_fights where fight_id = p_fight;
      if coalesce(x.gval, 0) = 0 and coalesce(b -> 'wedges', '[]'::jsonb) @> to_jsonb(t) then
        update public.world_gw_members set gval = 1 where fight_id = p_fight and owner_id = x.owner_id;
        update public.world_gw_fights set board = board || jsonb_build_object('wedges', coalesce((select jsonb_agg(e) from jsonb_array_elements(board -> 'wedges') e where e <> to_jsonb(t)), '[]'::jsonb))
         where fight_id = p_fight;
        perform public.world_gw_say(p_fight, p_round, 'good', x.name || ' — 쐐기돌을 주워 들었습니다.');
      end if;
    end if;
  end loop;
end $f$;

create or replace function public.world_du_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; b jsonb; x record; h jsonb; keep jsonb := '[]';
  extra numeric := 0; cells int[]; nm text; c int; heal numeric := 0; k text; pulls jsonb; holes jsonb; cracked jsonb; wedges jsonb; z int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; pulls := coalesce(b -> 'pulls', '{}'); holes := coalesce(b -> 'holes', '{}'); cracked := coalesce(b -> 'cracked', '[]'); wedges := coalesce(b -> 'wedges', '[]');
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    if (h ->> 'left')::int > 0 then keep := keep || jsonb_build_array(h); continue; end if;
    cells := public.world_du_hz_cells(p_fight, h);
    if h ->> 'k' = 'pull' then
      select string_agg(y.name, '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest
        and y.pos = (h ->> 'c')::int and y.act ->> 'a' = 'stop' and coalesce(y.gval, 0) > 0;
      if nm is null then
        heal := heal + f.max_hp * coalesce((rb -> 'pull' ->> 'heal_pct')::numeric, 0) / 100.0;
        perform public.world_gw_say(p_fight, p_round, 'bad', (h ->> 'c') || '번 끌개가 돌아 땅울이에게 흐름이 몰립니다. 땅울이의 체력이 차오릅니다.');
      else
        pulls := pulls || jsonb_build_object(h ->> 'c', p_round + (rb -> 'pull' ->> 'stop')::int);
        update public.world_gw_members y set gval = 0 where y.fight_id = p_fight and y.pos = (h ->> 'c')::int and y.act ->> 'a' = 'stop' and coalesce(y.gval, 0) > 0;
        extra := extra + coalesce((select sum(coalesce((y.stats ->> 'attack')::numeric, 0) * (1 + coalesce((y.stats ->> 'solo_dmg')::numeric, 0) / 100.0)) from public.world_gw_members y where y.fight_id = p_fight and y.pos = (h ->> 'c')::int and y.act ->> 'a' = 'stop'), 0)
          * coalesce((rb -> 'pull' ->> 'hit_mul')::numeric, 0);
        perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — ' || (h ->> 'c') || '번 끌개에 쐐기돌을 박아 멈췄습니다. 땅울이가 휘청입니다.');
      end if;
      continue;
    end if;
    if h ->> 'k' = 'slide' then
      perform public.world_gw_say(p_fight, p_round, 'boss', '산사태가 돌판을 쓸고 지나갑니다!');
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) order by y.joined_at loop
        perform public.world_du_dmg(p_fight, x.owner_id, (rb -> 'slide' ->> 'raw')::numeric, p_round, '산사태에', 0.5);
        perform public.world_du_push(p_fight, x.owner_id, null, (rb -> 'slide' ->> 'push')::int, p_round, '산사태에 쓸려');
      end loop;
    elsif h ->> 'k' = 'weight' then
      perform public.world_gw_say(p_fight, p_round, 'boss', array_to_string(cells, '·') || '번 돌판이 무너져 내립니다!');
      foreach c in array cells loop
        if cracked @> to_jsonb(c) and (select count(*) from jsonb_each_text(holes) e where e.value::int > 50) < coalesce((rb -> 'weight' ->> 'perm_max')::int, 3) then holes := holes || jsonb_build_object(c::text, 99);
        else holes := holes || jsonb_build_object(c::text, (rb -> 'weight' ->> 'hole')::int + 1); cracked := cracked || to_jsonb(c); end if;
        select z2 into z from unnest(public.world_du_nb(c)) z2 where not (holes ? z2::text) and not (wedges @> to_jsonb(z2)) order by random() limit 1;
        if z is not null and jsonb_array_length(wedges) < 4 then wedges := wedges || to_jsonb(z); end if;
      end loop;
      update public.world_gw_fights set board = board || jsonb_build_object('holes', holes) where fight_id = p_fight;
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
        perform public.world_du_fall(p_fight, x.owner_id, p_round, '무너지는 돌판과 함께');
      end loop;
    elsif h ->> 'k' = 'fist' then
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.owner_id = (h ->> 't')::uuid and y.out_rounds = 0 and not y.rest loop
        perform public.world_gw_say(p_fight, p_round, 'boss', '돌주먹이 ' || x.name || '을(를) 내리칩니다!');
        perform public.world_du_dmg(p_fight, x.owner_id, (rb -> 'fist' ->> 'raw')::numeric, p_round, '돌주먹에', 0.25);
        perform public.world_du_push(p_fight, x.owner_id, null, (rb -> 'fist' ->> 'push')::int, p_round, '돌주먹에 밀려');
      end loop;
    elsif h ->> 'k' = 'boulder' then
      perform public.world_gw_say(p_fight, p_round, 'boss', '바위가 한 줄로 굴러 지나갑니다!');
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) order by y.joined_at loop
        perform public.world_du_dmg(p_fight, x.owner_id, (rb -> 'boulder' ->> 'raw')::numeric, p_round, '굴러온 바위에', 0.5);
        perform public.world_du_push(p_fight, x.owner_id, (h ->> 'dir')::int, (rb -> 'boulder' ->> 'push')::int, p_round, '바위에 밀려');
      end loop;
    elsif h ->> 'k' = 'shave' then
      perform public.world_gw_say(p_fight, p_round, 'boss', '바깥 고리가 통째로 무너져 내립니다! 돌판은 일곱 칸만 남았습니다.');
      update public.world_gw_fights set board = board || jsonb_build_object('gone', true, 'final', coalesce((rb -> 'final' ->> 'rounds')::int, 3), 'wedges', '[]'::jsonb) where fight_id = p_fight;
      wedges := '[]'; pulls := '{}';
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and public.world_du_ring(y.pos) = 2 loop
        perform public.world_du_fall(p_fight, x.owner_id, p_round, '무너지는 바깥 고리와 함께');
      end loop;
    elsif h ->> 'k' = 'tilt' then
      perform public.world_gw_say(p_fight, p_round, 'boss', '땅울이가 마지막으로 몸부림칩니다! 돌판이 한쪽으로 기웁니다.');
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest order by y.joined_at loop
        perform public.world_du_push(p_fight, x.owner_id, (h ->> 'dir')::int, (rb -> 'final' ->> 'push')::int, p_round, '기운 돌판에서');
      end loop;
    end if;
  end loop;
  if heal > 0 then update public.world_gw_fights set hp = least(max_hp, hp + round(heal)) where fight_id = p_fight; end if;
  update public.world_gw_fights set board = board || jsonb_build_object('hz', keep, 'pulls', pulls, 'cracked', cracked,
    'wedges', case when coalesce((board ->> 'gone')::boolean, false) then '[]'::jsonb else wedges end) where fight_id = p_fight;
  return extra;
end $f$;

create or replace function public.world_du_after(p_fight uuid, p_round integer)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return true; end if;
  if not exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds < 9999) then
    perform public.world_gw_say(p_fight, p_round, 'bad', '모두 고임 구덩이로 떨어졌습니다. 땅울이의 울음이 고임터를 뒤덮습니다.');
    perform public.world_gw_settle(p_fight, false);
    return true;
  end if;
  if not coalesce((f.board ->> 'low')::boolean, false) and f.hp > 0 and f.hp * 100 < f.max_hp * coalesce((rb ->> 'low_pct')::numeric, 10) then
    perform public.world_gw_say(p_fight, p_round, 'boss', '땅울이의 울음이 갈라진다. 막혔던 흐름이 돌판 밑으로 조금씩 빠져나간다.');
    update public.world_gw_fights set board = board || '{"low": true}'::jsonb where fight_id = p_fight;
  end if;
  return false;
end $f$;

create or replace function public.world_du_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb := br -> 'board'; f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; b jsonb; cur jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  b := coalesce(f.board, '{}'::jsonb);
  cur := public.world_du_seq(p_fight, f.hp, f.max_hp);
  return jsonb_build_object(
    'phase_name', br -> 'phases' ->> (f.phase - 1), 'phases', br -> 'phases', 'mechs', cur -> 'm', 'mech_names', br -> 'mech_names',
    'cells', rb -> 'cells', 'center', 10, 'holes', coalesce(b -> 'holes', '{}'::jsonb), 'cracked', coalesce(b -> 'cracked', '[]'::jsonb),
    'gone', coalesce((b ->> 'gone')::boolean, false), 'wedges', coalesce(b -> 'wedges', '[]'::jsonb), 'pulls', coalesce(b -> 'pulls', '{}'::jsonb), 'round', f.round,
    'final', coalesce((b ->> 'final')::int, 0), 'fell', coalesce(b -> 'fell', '[]'::jsonb),
    'carry', (select coalesce(jsonb_object_agg(x.owner_id::text, coalesce(x.gval, 0)), '{}'::jsonb) from public.world_gw_members x where x.fight_id = p_fight),
    'mine', me.gval, 'my_pos', me.pos,
    'moves', case when me.pos is not null and f.status = 'fight' and me.out_rounds = 0 then to_jsonb(public.world_du_nb(me.pos)) else '[]'::jsonb end,
    'cut', case when f.mode <> 'story' and br -> 'dps' -> 'cuts' is not null then jsonb_build_object('i', coalesce((b ->> 'cut')::int, 0), 'cuts', br -> 'dps' -> 'cuts',
      'next', (br -> 'dps' -> 'cuts' ->> coalesce((b ->> 'cut')::int, 0))::int) end,
    'hz', (select coalesce(jsonb_agg(e || jsonb_build_object('cells', to_jsonb(public.world_du_hz_cells(p_fight, e)))), '[]'::jsonb)
      from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) e));
end $f$;
