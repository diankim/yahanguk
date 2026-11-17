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

lock table public.world_characters in access exclusive mode;

do $$
declare r jsonb := public.world_boss_rules();
begin
  r := jsonb_set(r, '{gwiheo,ultimate,hex}', $j${
    "pillars": [7, 9, 13, 15], "start": [10, 16, 12, 18],
    "lines": [{"a": 7, "b": 13, "cells": [1, 4]}, {"a": 9, "b": 15, "cells": [2, 5]}, {"a": 7, "b": 9, "cells": [8]}, {"a": 13, "b": 15, "cells": [14]}],
    "mech_mul": 1, "crack_max": 3, "fail_raw": 8, "aoe_every": 0,
    "acts": [
      {"phases": ["사슬 끌림", "봉인 터짐", "기운 모으기", "기운 모으기"], "seq": [["drag"], ["drag", "burst"], ["burst", "charge"], ["burst", "charge"]]},
      {"phases": ["물살", "이름 빼앗기", "소용돌이", "귀허의 바다"], "seq": [["tide"], ["tide", "name"], ["name", "vortex", "drag"], ["tide", "name", "vortex", "drag"]]}],
    "names": {"drag": "사슬 끌림", "burst": "봉인 터짐", "charge": "기운 모으기", "tide": "물살", "name": "이름 빼앗김", "vortex": "소용돌이"},
    "drag": {"every": 3, "off": 1, "left": 2, "raw": 50},
    "burst": {"every": 3, "off": 2, "left": 2, "raw": 45, "n": [1, 1, 2, 2]},
    "charge": {"every": 6, "off": 3, "left": 2, "pct": 35, "raw": 55},
    "tide": {"every": 3, "off": 0, "left": 2, "raw": 35, "wall": 15},
    "name": {"every": 6, "off": 2, "left": 3, "raw": 70},
    "vortex": {"every": 5, "off": 4, "left": 2, "raw": 40, "tank": 30},
    "face_every": 3}$j$::jsonb);
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
end $$;

create or replace function public.world_ux_q(p_id integer)
 returns integer language sql immutable set search_path = ''
as $f$ select (array[0, 1, 1, 0, -1, -1, 0, 2, 2, 2, 1, 0, -1, -2, -2, -2, -1, 0, 1])[p_id + 1] $f$;

create or replace function public.world_ux_r(p_id integer)
 returns integer language sql immutable set search_path = ''
as $f$ select (array[0, 0, -1, -1, 0, 1, 1, 0, -1, -2, -2, -2, -1, 0, 1, 2, 2, 2, 1])[p_id + 1] $f$;

create or replace function public.world_ux_at(p_q integer, p_r integer)
 returns integer language sql immutable set search_path = ''
as $f$ select (select i from generate_series(0, 18) i where public.world_ux_q(i) = p_q and public.world_ux_r(i) = p_r) $f$;

create or replace function public.world_ux_dist(p_a integer, p_b integer)
 returns integer language sql immutable set search_path = ''
as $f$ select (abs(public.world_ux_q(p_a) - public.world_ux_q(p_b)) + abs(public.world_ux_r(p_a) - public.world_ux_r(p_b))
  + abs(public.world_ux_q(p_a) + public.world_ux_r(p_a) - public.world_ux_q(p_b) - public.world_ux_r(p_b))) / 2 $f$;

create or replace function public.world_ux_step(p_id integer, p_dir integer)
 returns integer language sql immutable set search_path = ''
as $f$ select public.world_ux_at(public.world_ux_q(p_id) + (array[1, 1, 0, -1, -1, 0])[p_dir + 1], public.world_ux_r(p_id) + (array[0, -1, -1, 0, 1, 1])[p_dir + 1]) $f$;

create or replace function public.world_ux_nb(p_id integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select coalesce(array(select c from generate_series(1, 18) c where p_id between 0 and 18 and public.world_ux_dist(c, p_id) = 1 order by c), '{}') $f$;

create or replace function public.world_ux_lanes()
 returns jsonb language sql immutable set search_path = ''
as $f$
  select jsonb_agg(jsonb_build_object('ax', ax, 'c', c, 'cells', cells, 'dirs', dirs) order by ax, c) from (
    select ax, c, array(select i from generate_series(1, 18) i where case ax when 'q' then public.world_ux_q(i) when 'r' then public.world_ux_r(i) else -public.world_ux_q(i) - public.world_ux_r(i) end = c order by i) cells,
      case ax when 'q' then array[0, 1, 3, 4] when 'r' then array[1, 2, 4, 5] else array[0, 2, 3, 5] end dirs
    from unnest(array['q', 'r', 's']) ax, unnest(array[-2, -1, 1, 2]) c) x
$f$;

create or replace function public.world_ux_on(p_fight uuid)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
begin
  return coalesce((select x.mode = 'ultimate' and x.board -> 'ug' ->> 'board' = 'gwiheo' from public.world_gw_fights x where x.fight_id = p_fight), false);
end $f$;

create or replace function public.world_ux_cfg(p_fight uuid)
 returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $f$ select public.world_boss_rules() -> 'gwiheo' -> 'ultimate' -> 'hex' $f$;

create or replace function public.world_ux_dmg(p_fight uuid, p_uid uuid, p_raw numeric, p_round integer, p_why text, p_guardable boolean)
 returns integer language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare m public.world_gw_members%rowtype;
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  return public.world_gw_hurt(p_fight, p_uid, round(p_raw * coalesce((public.world_ux_cfg(p_fight) ->> 'mech_mul')::numeric, 1)
    * case when p_guardable and coalesce(m.act ->> 'a', 'guard') in ('guard', 'brace') then 0.5 else 1 end)::int, p_round, p_why);
end $f$;

create or replace function public.world_ux_begin(p_fight uuid, p_act integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare hx jsonb := public.world_ux_cfg(p_fight); x record; k int := 0;
begin
  for x in select owner_id from public.world_gw_members where fight_id = p_fight order by joined_at, owner_id loop
    update public.world_gw_members set pos = (hx -> 'start' ->> (k % jsonb_array_length(hx -> 'start')))::int, prev = null, nameless = false where fight_id = p_fight and owner_id = x.owner_id;
    k := k + 1;
  end loop;
  update public.world_gw_fights set board = coalesce(board, '{}'::jsonb) || jsonb_build_object('ux', jsonb_build_object('hz', '[]'::jsonb, 'hid', 0, 'crack', 0, 'act', p_act, 'line', ''))
   where fight_id = p_fight;
end $f$;

create or replace function public.world_ux_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; hx jsonb := public.world_ux_cfg(p_fight); b jsonb; ux jsonb; nr int; ar int; ph int; act int; mechs text[]; hz jsonb := '[]'::jsonb; h jsonb;
  hid int; alive uuid[]; na int; n int; m jsonb; face text; due boolean := false; line text[] := '{}'; c int; i int; t uuid; mc jsonb; ln jsonb; dir int; nm text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; ux := coalesce(b -> 'ux', '{}'::jsonb); nr := f.round + 1; ar := nr - coalesce((b -> 'ug' ->> 'act_start')::int, 0);
  act := coalesce((b -> 'ug' ->> 'act')::int, 1);
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  mechs := array(select jsonb_array_elements_text(hx -> 'acts' -> (act - 1) -> 'seq' -> (ph - 1)));
  if ph <> f.phase then
    perform public.world_gw_say(p_fight, nr, 'phase', case when act = 1 then case ph when 2 then '봉인 기둥이 금 가며 울린다. 사슬 끝마다 빛이 고인다.' else '봉주가 사슬을 거두어 가슴께로 기운을 끌어모은다. 기둥이 터질 듯 떤다.' end
      else case ph when 2 then '물이 이름을 핥기 시작한다.' when 3 then '바다 가운데가 꺼지며 소용돌이가 인다. 끊겼던 봉주의 사슬이 다시 솟는다.' else '귀허의 바다 전체가 일어선다. 물살·이름·소용돌이·사슬이 한꺼번에 몰려온다.' end end);
  end if;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  select coalesce(array_agg(owner_id order by random()), '{}') into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  na := coalesce(array_length(alive, 1), 0);
  hid := coalesce((ux ->> 'hid')::int, 0);
  for h in select * from jsonb_array_elements(coalesce(ux -> 'hz', '[]'::jsonb)) loop
    hz := hz || jsonb_build_array(h || jsonb_build_object('left', (h ->> 'left')::int - 1));
  end loop;
  if na > 0 then
    mc := hx -> 'drag';
    if 'drag' = any (mechs) and ar % (mc ->> 'every')::int = (mc ->> 'off')::int and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'drag') then
      ln := hx -> 'lines' -> floor(random() * jsonb_array_length(hx -> 'lines'))::int;
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'drag', 'a', ln -> 'a', 'b', ln -> 'b', 'cells', ln -> 'cells', 'left', (mc ->> 'left')::int));
      line := line || '두 기둥 사이로 사슬이 팽팽해진다.'::text;
    end if;
    mc := hx -> 'burst';
    if 'burst' = any (mechs) and ar % (mc ->> 'every')::int = (mc ->> 'off')::int then
      for c in select (p.v)::int from jsonb_array_elements_text(hx -> 'pillars') p(v)
          where not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'burst' and (e ->> 'p')::int = (p.v)::int)
          order by random() limit coalesce((mc -> 'n' ->> (least(4, greatest(1, n)) - 1))::int, 1) loop
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'burst', 'p', c, 'cells', to_jsonb(array[c] || public.world_ux_nb(c)), 'left', (mc ->> 'left')::int));
      end loop;
      line := line || '봉인 기둥 둘레가 붉게 달아오른다.'::text;
    end if;
    mc := hx -> 'charge';
    if 'charge' = any (mechs) and ar % (mc ->> 'every')::int = (mc ->> 'off')::int and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'charge') then
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'charge', 'need', round(f.max_hp * (mc ->> 'pct')::numeric / 100.0), 'dmg', 0, 'left', (mc ->> 'left')::int));
      line := line || '봉주가 가슴께로 기운을 끌어모은다.'::text;
    end if;
    mc := hx -> 'tide';
    if 'tide' = any (mechs) and ar % (mc ->> 'every')::int = (mc ->> 'off')::int and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'tide') then
      ln := public.world_ux_lanes() -> floor(random() * jsonb_array_length(public.world_ux_lanes()))::int;
      dir := (ln -> 'dirs' ->> floor(random() * 4)::int)::int;
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'tide', 'cells', ln -> 'cells', 'd', dir, 'left', (mc ->> 'left')::int));
      line := line || '한 줄로 물살이 밀려온다.'::text;
    end if;
    mc := hx -> 'name';
    if 'name' = any (mechs) and na >= 2 and ar % (mc ->> 'every')::int = (mc ->> 'off')::int then
      select x into t from unnest(alive) x where not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'name' and e ->> 't' = x::text) limit 1;
      if t is not null then
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'name', 't', t, 'left', (mc ->> 'left')::int));
        update public.world_gw_members set nameless = true where fight_id = p_fight and owner_id = t;
        select name into nm from public.world_gw_members where fight_id = p_fight and owner_id = t;
        perform public.world_gw_say(p_fight, nr, 'seal', nm || '의 이름이 물에 녹기 시작했다.');
        line := line || (nm || '의 이름이 물에 녹는다.');
      end if;
    end if;
    mc := hx -> 'vortex';
    if 'vortex' = any (mechs) and ar % (mc ->> 'every')::int = (mc ->> 'off')::int and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'vortex') then
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'vortex', 'left', (mc ->> 'left')::int));
      line := line || '바다 가운데가 꺼지며 물이 돌기 시작한다.'::text;
    end if;
  end if;
  due := exists (select 1 from jsonb_array_elements(hz) e where (e ->> 'left')::int <= 0);
  if act = 2 then
    face := coalesce(b ->> 'face', case when random() < 0.5 then 'human' else 'yokai' end);
    if ar % (hx ->> 'face_every')::int = 1 and ar > 1 then face := case when random() < 0.5 then 'human' else 'yokai' end; end if;
    b := b || jsonb_build_object('face', face);
    m := jsonb_build_object('k', 'face', 'face', face);
  else
    m := jsonb_build_object('k', 'normal');
  end if;
  m := m || jsonb_build_object('aoe', coalesce((hx ->> 'aoe_every')::int, 0) > 0 and ar % (hx ->> 'aoe_every')::int = 0 and not due);
  b := b || jsonb_build_object('ux', ux || jsonb_build_object('hz', hz, 'hid', hid, 'act', act, 'line', array_to_string(line, ' ')));
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when due then 10 else 5 end), updated_at = now() where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
end $f$;

create or replace function public.world_ux_mech(p_fight uuid, p_round integer, p_dmg numeric)
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare hx jsonb := public.world_ux_cfg(p_fight); f public.world_gw_fights%rowtype; ux jsonb; hz jsonb := '[]'::jsonb; keep jsonb := '[]'::jsonb; h jsonb; x record; w record;
  fails int := 0; crack int; hit boolean; nm text; cells int[]; t int; dest int; chainers int[] := '{}'; used int[] := '{}'; tank uuid; need numeric; ord text[] := array['tide', 'vortex', 'drag', 'burst', 'charge', 'name'];
  pillars int[]; kk text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  ux := coalesce(f.board -> 'ux', '{}'::jsonb);
  pillars := array(select (v)::int from jsonb_array_elements_text(hx -> 'pillars') v);
  for x in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ? 'm' order by joined_at, owner_id loop
    t := (x.act ->> 'm')::int;
    if x.pos is not null and t = any (public.world_ux_nb(x.pos)) then
      update public.world_gw_members set prev = pos, pos = t where fight_id = p_fight and owner_id = x.owner_id;
    end if;
  end loop;
  for h in select * from jsonb_array_elements(coalesce(ux -> 'hz', '[]'::jsonb)) loop
    if h ->> 'k' = 'charge' then h := h || jsonb_build_object('dmg', round((h ->> 'dmg')::numeric + p_dmg)); end if;
    hz := hz || jsonb_build_array(h);
  end loop;
  for w in select y.*, z.pos as tpos, z.name as tname, z.nameless as tnl from public.world_gw_members y left join public.world_gw_members z on z.fight_id = y.fight_id and z.owner_id = nullif(y.act ->> 't', '')::uuid
      where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'call' order by y.joined_at loop
    if (w.act ->> 't')::uuid = w.owner_id then
      perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — 제 이름은 스스로 불러 되찾을 수 없습니다. 곁의 동료가 불러야 합니다.');
    elsif not coalesce(w.tnl, false) or not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'name' and e ->> 't' = w.act ->> 't') then
      perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — ' || coalesce(w.tname, '') || '을(를) 불렀지만 메아리만 돌아옵니다.');
    elsif w.pos is null or w.tpos is null or public.world_ux_dist(w.pos, w.tpos) <> 1 then
      perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — 부르는 소리가 물살에 흩어집니다. 바로 옆 칸에 서야 닿습니다.');
    else
      update public.world_gw_members set nameless = false where fight_id = p_fight and owner_id = (w.act ->> 't')::uuid;
      hz := (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(hz) e where not (e ->> 'k' = 'name' and e ->> 't' = w.act ->> 't'));
      perform public.world_gw_say(p_fight, p_round, 'good', w.name || ' — 「' || w.tname || '!」 곁에서 부르는 소리에 물에 녹던 이름이 되돌아옵니다.');
    end if;
  end loop;
  chainers := array(select y.pos from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'chain' and y.pos = any (pillars));
  for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'chain' and not (y.pos = any (pillars)) loop
    perform public.world_gw_say(p_fight, p_round, 'miss', x.name || ' — 봉인 기둥 칸에 서야 사슬을 끊을 수 있습니다.');
  end loop;
  for kk in select unnest(ord) loop
    for h in select e from jsonb_array_elements(hz) e where e ->> 'k' = kk loop
      if (h ->> 'left')::int > 0 then keep := keep || jsonb_build_array(h); continue; end if;
      cells := array(select (v)::int from jsonb_array_elements_text(coalesce(h -> 'cells', '[]'::jsonb)) v);
      hit := false;
      if kk = 'tide' then
        perform public.world_gw_say(p_fight, p_round, 'boss', '물살이 한 줄로 들이친다!');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) order by y.joined_at loop
          if x.act ->> 'a' = 'brace' then
            perform public.world_gw_say(p_fight, p_round, 'good', x.name || ' — 몸을 낮추고 발을 디뎌 물살을 버텼습니다.');
            continue;
          end if;
          hit := true;
          dest := public.world_ux_step(x.pos, (h ->> 'd')::int);
          if dest is null or dest = 0 then
            perform public.world_ux_dmg(p_fight, x.owner_id, (hx -> 'tide' ->> 'raw')::numeric + (hx -> 'tide' ->> 'wall')::numeric, p_round, '물살에 떠밀려 벽에 부딪혀', true);
          else
            update public.world_gw_members set prev = pos, pos = dest where fight_id = p_fight and owner_id = x.owner_id;
            perform public.world_ux_dmg(p_fight, x.owner_id, (hx -> 'tide' ->> 'raw')::numeric, p_round, '물살에 떠밀려 ' || dest || '번 칸으로 밀려나며', true);
          end if;
        end loop;
      elsif kk = 'vortex' then
        select y.owner_id, y.name into tank, nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos between 1 and 6 and y.act ->> 'a' = 'brace'
          order by coalesce((y.stats ->> 'pres')::numeric, 30) desc, y.joined_at limit 1;
        if tank is not null then
          perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — 가운데 곁에서 몸을 낮춰 소용돌이를 홀로 받아 냈습니다.');
          perform public.world_ux_dmg(p_fight, tank, (hx -> 'vortex' ->> 'tank')::numeric, p_round, '홀로 받아 낸 소용돌이에', false);
        else
          hit := true;
          perform public.world_gw_say(p_fight, p_round, 'bad', '가운데 곁에서 소용돌이를 받아 낸 사람이 없었습니다. 모두가 가운데로 끌려갑니다.');
          for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest order by y.joined_at loop
            if x.pos > 6 then
              dest := (select z from unnest(public.world_ux_nb(x.pos)) z where z between 1 and 6 order by z limit 1);
              if dest is not null then update public.world_gw_members set prev = pos, pos = dest where fight_id = p_fight and owner_id = x.owner_id; end if;
            end if;
            perform public.world_ux_dmg(p_fight, x.owner_id, (hx -> 'vortex' ->> 'raw')::numeric, p_round, '소용돌이에 끌려가며', true);
          end loop;
        end if;
      elsif kk = 'drag' then
        if (h ->> 'a')::int = any (chainers) or (h ->> 'b')::int = any (chainers) then
          used := used || case when (h ->> 'a')::int = any (chainers) then (h ->> 'a')::int else (h ->> 'b')::int end;
          select string_agg(y.name, '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'chain'
            and y.pos in ((h ->> 'a')::int, (h ->> 'b')::int);
          perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — 당겨지던 사슬을 기둥 곁에서 끊어 냈습니다.');
        else
          perform public.world_gw_say(p_fight, p_round, 'boss', (h ->> 'a') || '번과 ' || (h ->> 'b') || '번 기둥 사이 사슬이 홱 당겨진다!');
          for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) order by y.joined_at loop
            hit := true;
            dest := case when public.world_ux_dist(x.pos, (h ->> 'a')::int) <= public.world_ux_dist(x.pos, (h ->> 'b')::int) then (h ->> 'a')::int else (h ->> 'b')::int end;
            update public.world_gw_members set prev = pos, pos = dest where fight_id = p_fight and owner_id = x.owner_id;
            perform public.world_ux_dmg(p_fight, x.owner_id, (hx -> 'drag' ->> 'raw')::numeric, p_round, '사슬에 감겨 ' || dest || '번 기둥으로 끌려가며', false);
          end loop;
        end if;
      elsif kk = 'burst' then
        perform public.world_gw_say(p_fight, p_round, 'boss', (h ->> 'p') || '번 봉인 기둥이 터진다!');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) order by y.joined_at loop
          hit := true;
          perform public.world_ux_dmg(p_fight, x.owner_id, (hx -> 'burst' ->> 'raw')::numeric, p_round, '터진 봉인 기둥에', false);
        end loop;
      elsif kk = 'charge' then
        need := (h ->> 'need')::numeric;
        if exists (select 1 from unnest(chainers) z where not (z = any (used))) then
          need := round(need * 0.5);
          select string_agg(y.name, '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'chain' and y.pos = any (pillars)
            and not (y.pos = any (used));
          used := used || chainers;
          perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — 기둥의 사슬을 끊어 봉주가 끌어모으던 기운의 절반을 흩었습니다.');
        end if;
        if (h ->> 'dmg')::numeric >= need then
          perform public.world_gw_say(p_fight, p_round, 'good', '봉주가 모으던 기운이 흩어졌다(' || (h ->> 'dmg') || '/' || need || ').');
        else
          hit := true;
          perform public.world_gw_say(p_fight, p_round, 'bad', '봉주가 모은 기운이 터졌다(' || (h ->> 'dmg') || '/' || need || ').');
          for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest order by y.joined_at loop
            perform public.world_ux_dmg(p_fight, x.owner_id, (hx -> 'charge' ->> 'raw')::numeric, p_round, '터진 기운에', false);
          end loop;
        end if;
      elsif kk = 'name' then
        select * into x from public.world_gw_members y where y.fight_id = p_fight and y.owner_id = (h ->> 't')::uuid;
        if x.owner_id is not null and x.out_rounds = 0 and not x.rest and x.nameless then
          hit := true;
          update public.world_gw_members set nameless = false where fight_id = p_fight and owner_id = x.owner_id;
          perform public.world_ux_dmg(p_fight, x.owner_id, (hx -> 'name' ->> 'raw')::numeric, p_round, '이름을 끝내 되찾지 못해', false);
        end if;
      end if;
      if hit then fails := fails + 1; end if;
    end loop;
  end loop;
  for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'chain' and y.pos = any (pillars) and not (y.pos = any (used)) loop
    perform public.world_gw_say(p_fight, p_round, 'miss', x.name || ' — 기둥의 사슬을 내리쳤지만 아직 끊을 때가 아닙니다.');
  end loop;
  keep := (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(keep) e
    where not (e ->> 'k' = 'name' and not exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.owner_id = (e ->> 't')::uuid and y.nameless and y.out_rounds = 0)));
  crack := coalesce((ux ->> 'crack')::int, 0);
  if fails > 0 then
    crack := crack + fails;
    perform public.world_gw_say(p_fight, p_round, 'bad', '한 사람이 놓친 틈으로 봉인에 금이 번져 모두가 함께 다칩니다(봉인 균열 ' || least(crack, (hx ->> 'crack_max')::int) || '/' || (hx ->> 'crack_max') || ').');
    for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest order by y.joined_at loop
      perform public.world_ux_dmg(p_fight, x.owner_id, (hx ->> 'fail_raw')::numeric * crack, p_round, '번진 균열에', false);
    end loop;
  end if;
  update public.world_gw_fights set board = jsonb_set(board, '{ux}', ux || jsonb_build_object('hz', keep, 'crack', crack, 'wipe', crack >= (hx ->> 'crack_max')::int)) where fight_id = p_fight;
  return 0;
end $f$;

create or replace function public.world_ux_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare hx jsonb := public.world_ux_cfg(p_fight); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; ux jsonb; act int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  ux := coalesce(f.board -> 'ux', '{}'::jsonb); act := coalesce((ux ->> 'act')::int, (f.board -> 'ug' ->> 'act')::int, 1);
  return jsonb_build_object('hex', true, 'act', act, 'pillars', hx -> 'pillars', 'my_pos', me.pos,
    'moves', case when me.pos is not null and me.out_rounds = 0 and f.status = 'fight' then to_jsonb(public.world_ux_nb(me.pos)) else '[]'::jsonb end,
    'hz', coalesce(ux -> 'hz', '[]'::jsonb), 'crack', coalesce((ux ->> 'crack')::int, 0), 'crack_max', (hx ->> 'crack_max')::int,
    'face', case when act = 2 then f.board ->> 'face' end, 'line', coalesce(ux ->> 'line', ''), 'names', hx -> 'names',
    'mechs', hx -> 'acts' -> (act - 1) -> 'seq' -> (greatest(1, f.phase) - 1), 'phases', hx -> 'acts' -> (act - 1) -> 'phases');
end $f$;

revoke all on function public.world_ux_q(integer), public.world_ux_r(integer), public.world_ux_at(integer, integer), public.world_ux_dist(integer, integer), public.world_ux_step(integer, integer),
  public.world_ux_nb(integer), public.world_ux_lanes(), public.world_ux_on(uuid), public.world_ux_cfg(uuid), public.world_ux_dmg(uuid, uuid, numeric, integer, text, boolean),
  public.world_ux_begin(uuid, integer), public.world_ux_round(uuid), public.world_ux_mech(uuid, integer, numeric), public.world_ux_view(uuid, uuid) from public, anon, authenticated;
grant execute on function public.world_ux_q(integer), public.world_ux_r(integer), public.world_ux_at(integer, integer), public.world_ux_dist(integer, integer), public.world_ux_step(integer, integer),
  public.world_ux_nb(integer), public.world_ux_lanes(), public.world_ux_on(uuid), public.world_ux_cfg(uuid), public.world_ux_dmg(uuid, uuid, numeric, integer, text, boolean),
  public.world_ux_begin(uuid, integer), public.world_ux_round(uuid), public.world_ux_mech(uuid, integer, numeric), public.world_ux_view(uuid, uuid) to service_role, fn_owner_field;

select pg_temp.yh_patch('public.world_ug_begin_act(uuid,integer)',
  $o$  update public.world_gw_fights set board = board || jsonb_build_object('ug', ug) where fight_id = p_fight;$o$,
  $n$  update public.world_gw_fights set board = board || jsonb_build_object('ug', ug) where fight_id = p_fight;
  if public.world_ux_on(p_fight) then perform public.world_ux_begin(p_fight, p_act); end if;$n$);

select pg_temp.yh_patch('public.world_ug_round(uuid)',
  $o$  if f.boss_id = 'sealed_lord' then perform public.world_ug_lord_round(p_fight);$o$,
  $n$  if public.world_ux_on(p_fight) then perform public.world_ux_round(p_fight);
  elsif f.boss_id = 'sealed_lord' then perform public.world_ug_lord_round(p_fight);$n$);

select pg_temp.yh_patch('public.world_ug_mech(uuid,integer,numeric,boolean,boolean,uuid[])',
  $o$  if f.boss_id <> 'sealed_lord' then return 0; end if;$o$,
  $n$  if public.world_ux_on(p_fight) then return public.world_ux_mech(p_fight, p_round, p_dmg); end if;
  if f.boss_id <> 'sealed_lord' then return 0; end if;$n$);

select pg_temp.yh_patch('public.world_ug_after(uuid,integer)',
  $o$  if coalesce((ug ->> 'rest')::int, 0) > 0 then return false; end if;$o$,
  $n$  if coalesce((ug ->> 'rest')::int, 0) > 0 then return false; end if;
  if coalesce((f.board -> 'ux' ->> 'wipe')::boolean, false) then
    perform public.world_ug_wipe(p_fight, p_round, '이야기꾼의 말로는 놓친 틈마다 금이 번져 봉인이 통째로 무너졌다고 한다 — 봉인 균열이 가득 찼다.');
    return true;
  end if;$n$);

select pg_temp.yh_patch('public.world_ug_view(uuid,uuid)',
  $o$  if f.boss_id = 'mukjeok' then
    v := jsonb_build_object('strokes',$o$,
  $n$  if public.world_ux_on(p_fight) then
    v := public.world_ux_view(p_fight, p_uid);
  elsif f.boss_id = 'mukjeok' then
    v := jsonb_build_object('strokes',$n$);
select pg_temp.yh_patch('public.world_ug_view(uuid,uuid)',
  $o$  return v || jsonb_build_object('phase_name', br -> 'phases' ->> (f.phase - 1), 'phases', br -> 'phases',$o$,
  $n$  if v ? 'hex' then br := br || jsonb_build_object('phases', v -> 'phases'); end if;
  return v || jsonb_build_object('phase_name', br -> 'phases' ->> (f.phase - 1), 'phases', br -> 'phases',$n$);

select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if (f.boss_id <> 'baekya' and p_action in ('light', 'sweep')) or (f.boss_id not in ('baekya', 'gapgwi') and p_action = 'move') then raise exception '알 수 없는 행동입니다.'; end if;$o$,
  $n$  if public.world_ux_on(p_fight) then
    if p_action in ('light', 'sweep', 'recall', 'deal') then raise exception '알 수 없는 행동입니다.'; end if;
    if p_move is not null and p_move = me.pos then p_move := null; end if;
    if p_move is not null and not (p_move::int = any (public.world_ux_nb(me.pos))) then raise exception '바로 옆 칸으로만 옮겨 설 수 있습니다(가운데 소용돌이 칸은 못 들어갑니다).'; end if;
    if p_action = 'move' and p_move is null then raise exception '옮겨 설 칸을 고르세요.'; end if;
  end if;
  if (f.boss_id <> 'baekya' and p_action in ('light', 'sweep')) or (f.boss_id not in ('baekya', 'gapgwi') and not public.world_ux_on(p_fight) and p_action = 'move') then raise exception '알 수 없는 행동입니다.'; end if;$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if not mk and f.boss_id not in ('baekya', 'gapgwi') and (p_action = 'recall' or p_move is not null) then$o$,
  $n$  if not mk and f.boss_id not in ('baekya', 'gapgwi') and not public.world_ux_on(p_fight) and (p_action = 'recall' or p_move is not null) then$n$);

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$    elsif av = 'call' and (f.boss_id in ('mukjeok', 'gapgwi') or f.mode = 'story') then$o$,
  $n$    elsif av = 'call' and (f.boss_id in ('mukjeok', 'gapgwi') or f.mode = 'story' or public.world_ux_on(p_fight)) then$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$    elsif av = 'chain' and f.mode = 'story' then$o$,
  $n$    elsif av = 'chain' and (f.mode = 'story' or public.world_ux_on(p_fight)) then$n$);
