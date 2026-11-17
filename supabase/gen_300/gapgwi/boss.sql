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

alter table public.world_gw_members add column if not exists gval smallint;

do $$
begin
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$',
    (public.world_boss_rules() - 'gapgwi') || jsonb_build_object('gapgwi', $j${
  "name": "값귀", "fight": "값을 매기는 장부", "place": "붉은 사당 골목", "arc": "명등기", "region": "red_shrine_lane", "lv": 47,
  "quest": "mdq_7", "quest_name": "외전 「명등기」 7장 「묻은 이름」", "item": "red_shrine_lacquer", "item_name": "붉은 사당 옻", "item_where": "붉은 사당 골목에서 채집해 얻습니다.",
  "min": 18, "hp_min": 8000, "hp_atk": 42, "hp_n": [1.2, 0.8, 0.65, 0.62], "raw_n": [0.6, 0.7, 0.8, 0.85], "raw": [40, 4], "enrage": 0.15,
  "first": {"gil": 2000, "xp": 0.5}, "again": {"gil": 150, "xp": 0.05}, "fail": {"dur": 10, "er": 10, "cd": 30}, "falls": 10, "xp_cap_lv": 50,
  "hard_quest": "mdq_8", "hard_quest_name": "외전 「명등기」 8장 「끊긴 기름」",
  "modes": {"story": "이야기판", "hard": "깊은 장부"},
  "phases": ["판결 망치", "바가지", "장부 맞추기", "장 닫힘"],
  "mech_names": {"judge": "판결 망치", "bargain": "바가지", "ledger": "장부 맞추기", "tether": "외상 줄", "close": "장 닫힘", "basket": "떨이 바구니", "tagm": "값표 맞추기"},
  "story": {"min": 30, "round_s": 60, "hp_min": 2000, "hp_atk": 24, "hp_n": [1, 1, 1, 1], "raw": [12, 2], "first": {"gil": 1000},
    "board": {"mech_mul": 1,
      "basket": {"every": 3, "off": 1, "left": 2, "raw": 12},
      "tagm": {"every": 4, "off": 3, "left": 3, "raw": 8, "hit_pct": 3},
      "seq": [{"at": 100, "m": ["basket"]}, {"at": 66, "m": ["tagm"]}, {"at": 33, "m": ["basket", "tagm"]}]}},
  "board": {
    "start": [0, 4], "delta": {"attack": 1, "coop": 1}, "haggle": -5, "price": 3, "max": 9,
    "mech_mul": 0.45,
    "judge": {"every": 3, "off": 1, "left": 2, "raw": 45, "shift": false},
    "bargain": {"every": 4, "off": 0, "left": 2, "raw": 30, "base": 0.4, "k": 0.09},
    "ledger": {"every": 5, "off": 2, "left": 4, "cells": [2, 2, 3, 3], "raw": 25, "heal_pct": 3, "hit_pct": 4, "broke": 2, "broke_pct": 30},
    "tether": {"every": 5, "off": 4, "left": 3, "dist": 3, "raw": 30},
    "close": {"every": 7, "off": 0, "left": 3, "raw": 20, "max": 4},
    "seq": [{"at": 100, "m": ["judge"]}, {"at": 87.5, "m": ["judge", "bargain"]}, {"at": 75, "m": ["ledger", "judge", "bargain"]},
      {"at": 50, "m": ["ledger", "tether", "judge", "bargain"]}, {"at": 25, "m": ["close", "ledger", "tether", "judge", "bargain"]}],
    "low_pct": 10},
  "solo": {"artificer": {"solo_dmg": -25, "solo_guard": -24}, "scout": {"solo_dmg": -25, "solo_guard": -15}, "exorcist": {"solo_dmg": -26, "solo_guard": -16},
    "medic": {"solo_dmg": 20, "solo_guard": -55}, "sealmaster": {"solo_dmg": -28, "solo_guard": -10}, "analyst": {"solo_dmg": -25, "solo_guard": -36},
    "tamer": {"solo_dmg": -25, "solo_guard": 0}}
}$j$::jsonb));
end $$;

create or replace function public.world_solo_aid(p_job text, p_boss text)
 returns jsonb language sql immutable set search_path = ''
as $f$ select case when public.world_boss_rules() -> p_boss ? 'solo' then coalesce(public.world_boss_rules() -> p_boss -> 'solo' -> p_job, '{}'::jsonb) else public.world_solo_aid(p_job) end $f$;

create or replace function public.world_gg_nb(p_cell integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select array(select z from (values (p_cell - 5), (p_cell + 5), (case when (p_cell - 1) % 5 > 0 then p_cell - 1 end), (case when (p_cell - 1) % 5 < 4 then p_cell + 1 end)) v(z)
  where z between 1 and 15 order by z) $f$;

create or replace function public.world_gg_col(p_col integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select array[p_col, p_col + 5, p_col + 10] $f$;

create or replace function public.world_gg_dist(p_a integer, p_b integer)
 returns integer language sql immutable set search_path = ''
as $f$ select case when p_a is null or p_b is null then 9 else abs((p_a - 1) / 5 - (p_b - 1) / 5) + abs((p_a - 1) % 5 - (p_b - 1) % 5) end $f$;

create or replace function public.world_gg_dmg(p_fight uuid, p_uid uuid, p_raw numeric, p_round integer, p_why text, p_guardable boolean)
 returns integer language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare m public.world_gw_members%rowtype; f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight);
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight;
  return public.world_gw_hurt(p_fight, p_uid, round(p_raw * coalesce((br -> 'board' ->> 'mech_mul')::numeric, 1) * (1 + coalesce((br ->> 'enrage')::numeric, 0) * f.enrage)
    * case when p_guardable and coalesce(m.act ->> 'a', 'guard') in ('guard', 'brace') then 0.5 else 1 end)::int, p_round, p_why);
end $f$;

create or replace function public.world_gg_hz_cells(p_fight uuid, p_hz jsonb)
 returns integer[] language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare a int; b int;
begin
  if p_hz ->> 'k' in ('judge', 'close') then return public.world_gg_col((p_hz ->> 'col')::int); end if;
  if p_hz ->> 'k' = 'ledger' then return array(select jsonb_array_elements_text(p_hz -> 'cells')::int); end if;
  if p_hz ->> 'k' in ('basket', 'tagm') then return array[(p_hz ->> 'c')::int]; end if;
  if p_hz ->> 'k' = 'tether' then
    select pos into a from public.world_gw_members where fight_id = p_fight and owner_id = (p_hz ->> 'a')::uuid;
    select pos into b from public.world_gw_members where fight_id = p_fight and owner_id = (p_hz ->> 'b')::uuid;
    return array_remove(array[a, b], null);
  end if;
  return '{}'::int[];
end $f$;

create or replace function public.world_gg_seq(p_fight uuid, p_hp integer, p_max integer)
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

create or replace function public.world_gg_begin(p_fight uuid, p_n integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; lo int := (rb -> 'start' ->> 0)::int; hi int := (rb -> 'start' ->> 1)::int; x record; k int := 0; tags jsonb := '{}';
begin
  for x in select owner_id from public.world_gw_members where fight_id = p_fight order by joined_at, owner_id loop
    update public.world_gw_members set gval = lo + floor(random() * (hi - lo + 1))::int, pos = 6 + least(4, floor(k * 5.0 / greatest(1, p_n))::int), prev = null
     where fight_id = p_fight and owner_id = x.owner_id;
    k := k + 1;
  end loop;
  select jsonb_object_agg(c::text, floor(random() * 10)::int) into tags from (select generate_series(1, 5) c union all select generate_series(11, 15)) s;
  update public.world_gw_fights set board = coalesce(board, '{}'::jsonb) || jsonb_build_object('hz', '[]'::jsonb, 'tags', tags, 'closed', '[]'::jsonb, 'seq', 0, 'hid', 0, 'broke', 0)
   where fight_id = p_fight;
  perform public.world_gw_say(p_fight, 0, 'phase', '사당 마룻바닥 밑에서 젖은 장부 더미가 기어 나와 골목 끝 저울 위에 앉는다. 위아래 좌판마다 값표가 붙어 있고, 저마다의 머리 위에도 값(섬)이 매겨진다.');
  perform public.world_gw_say(p_fight, 0, 'phase', '값귀가 주판알을 튕긴다. 「한 줄에 쌀 두 섬. 휘두를수록 값이 오르지. 흥정을 하든가, 서로 값을 매겨 주든가.」');
end $f$;

create or replace function public.world_gg_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb; b jsonb; nr int; ph int; m jsonb; tell text := '';
  n int; na int; alive uuid[]; hz jsonb := '[]'; h jsonb; cur jsonb; mechs text[]; story boolean; len int := 5; hid int; c int; k int; t int; cells int[]; closed int[];
  col int; due boolean := false; s int; i int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  rb := br -> 'board'; b := coalesce(f.board, '{}'::jsonb); nr := f.round + 1; story := f.mode = 'story';
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  select coalesce(array_agg(owner_id order by random()), '{}') into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  na := coalesce(array_length(alive, 1), 0);
  hid := coalesce((b ->> 'hid')::int, 0);
  closed := array(select jsonb_array_elements_text(coalesce(b -> 'closed', '[]'::jsonb))::int);
  cur := public.world_gg_seq(p_fight, f.hp, f.max_hp);
  mechs := array(select jsonb_array_elements_text(cur -> 'm'));
  if (cur ->> 'i')::int <> coalesce((b ->> 'seq')::int, 0) then
    perform public.world_gw_say(p_fight, nr, 'phase', case
      when 'close' = any (mechs) then '사당 밑 곳간에 물이 차오른다. 골목 왼쪽 끝부터 좌판이 하나둘 덧문을 내린다. 「장이 파한다. 파하기 전에 셈을 끝내자.」'
      when 'tether' = any (mechs) then '값귀가 두 사람의 소매를 붉은 외상 줄로 묶는다. 「같이 갚든가, 갈라서든가.」'
      when 'ledger' = any (mechs) then '값귀가 낱장을 펼쳐 좌판 위에 깐다. 「그 좌판에 선 이들의 값을 더해 맞추면 장부를 덮어 주마.」'
      when 'bargain' = any (mechs) then '주판알이 사납게 맞부딪친다. 「값이 비싼 놈부터 거둔다.」'
      when 'tagm' = any (mechs) then '좌판의 값표가 하나씩 반짝인다. 제 값과 같은 값표 앞에 서면 값귀가 움찔한다.'
      else '값귀가 장부를 넘긴다.' end);
    b := b || jsonb_build_object('seq', (cur ->> 'i')::int);
  end if;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    h := h || jsonb_build_object('left', (h ->> 'left')::int - 1);
    if h ->> 'k' = 'judge' and coalesce((rb -> 'judge' ->> 'shift')::boolean, false) and (h ->> 'left')::int = 0 and not coalesce((h ->> 'sh')::boolean, false) then
      col := (h ->> 'col')::int;
      col := case when col = 1 then 2 when col = 5 then 4 when random() < 0.5 then col - 1 else col + 1 end;
      h := h || jsonb_build_object('col', col, 'sh', true);
      perform public.world_gw_say(p_fight, nr, 'warn', '망치가 기운다.');
    end if;
    hz := hz || jsonb_build_array(h);
  end loop;
  if na > 0 then
    if 'judge' = any (mechs) and nr % (rb -> 'judge' ->> 'every')::int = (rb -> 'judge' ->> 'off')::int then
      select pos into c from public.world_gw_members where fight_id = p_fight and owner_id = alive[1];
      col := coalesce(((c - 1) % 5) + 1, 1 + floor(random() * 5)::int);
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'judge', 'col', col, 'left', (rb -> 'judge' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '값귀가 판결 망치를 든다. ' || col || '번째 줄을 겨눈다.';
    end if;
    if 'bargain' = any (mechs) and nr % (rb -> 'bargain' ->> 'every')::int = (rb -> 'bargain' ->> 'off')::int then
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'bargain', 'left', (rb -> 'bargain' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '값귀가 주판을 튕긴다. 값이 비싼 사람부터 크게 거둘 것이다.';
    end if;
    if 'ledger' = any (mechs) and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'ledger') and nr % (rb -> 'ledger' ->> 'every')::int = (rb -> 'ledger' ->> 'off')::int then
      k := least(na, coalesce((rb -> 'ledger' -> 'cells' ->> (least(4, greatest(1, n)) - 1))::int, 2));
      cells := '{}';
      for i in 1 .. k loop
        select pos into c from public.world_gw_members where fight_id = p_fight and owner_id = alive[i];
        select z into s from (select generate_series(1, 5) z union all select generate_series(11, 15)) q
         where not (((z - 1) % 5) + 1 = any (closed)) and not (z = any (cells)) order by public.world_gg_dist(z, c), random() limit 1;
        if s is not null then cells := cells || s; end if;
      end loop;
      t := greatest(0, (select coalesce(sum(gval), 0) from public.world_gw_members where fight_id = p_fight and owner_id = any (alive[1:k])) + floor(random() * 5)::int - 2);
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'ledger', 'cells', to_jsonb(cells), 't', t, 'left', (rb -> 'ledger' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '흰 낱장이 좌판 ' || k || '곳에 깔린다. 그 위에 선 이들의 값을 더해 ' || t || '섬을 맞춰라.';
    end if;
    if 'tether' = any (mechs) and na >= 2 and nr % (rb -> 'tether' ->> 'every')::int = (rb -> 'tether' ->> 'off')::int then
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'tether', 'a', alive[1], 'b', alive[2], 'left', (rb -> 'tether' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '붉은 외상 줄이 두 사람을 묶는다. 멀리 떨어져야 끊긴다.';
    end if;
    if 'close' = any (mechs) and coalesce(array_length(closed, 1), 0) < (rb -> 'close' ->> 'max')::int
       and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'close') and nr % (rb -> 'close' ->> 'every')::int = (rb -> 'close' ->> 'off')::int then
      col := coalesce(array_length(closed, 1), 0) + 1;
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'close', 'col', col, 'left', (rb -> 'close' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || col || '번째 줄 좌판이 덧문을 내리려 한다.';
    end if;
    if 'basket' = any (mechs) and nr % (rb -> 'basket' ->> 'every')::int = (rb -> 'basket' ->> 'off')::int then
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'basket', 'c', 6 + floor(random() * 5)::int, 'left', (rb -> 'basket' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '떨이 바구니가 거리 위에 멈춘다. 누군가 그 아래에서 막으면 엎어진다.';
    end if;
    if 'tagm' = any (mechs) and nr % (rb -> 'tagm' ->> 'every')::int = (rb -> 'tagm' ->> 'off')::int then
      select z into c from (select generate_series(1, 5) z union all select generate_series(11, 15)) s order by random() limit 1;
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'tagm', 'c', c, 'left', (rb -> 'tagm' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || c || '번 좌판 값표가 반짝인다(' || (b -> 'tags' ->> c::text) || '섬). 같은 값인 사람이 그 앞에 서라.';
    end if;
  end if;
  if exists (select 1 from jsonb_array_elements(hz) e where (e ->> 'left')::int <= 0) then due := true; end if;
  if tell = '' then tell := '값귀가 주판알을 딸깍인다. 「한 줄에 쌀 두 섬. 한 줄에 쌀 두 섬.」'; end if;
  b := b || jsonb_build_object('hz', hz, 'hid', hid);
  m := jsonb_build_object('k', 'normal', 'phase_name', br -> 'phases' ->> (ph - 1), 'aoe', false, 'tell', tell, 'mechs', to_jsonb(mechs));
  if due then len := 10; end if;
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when not story then len when n = 1 then 86400 else (br ->> 'round_s')::int end), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, nr, case when due then 'warn' else 'tell' end, tell);
end $f$;

create or replace function public.world_gg_steps(p_fight uuid, p_round integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare x record; t int;
begin
  for x in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ? 'm' order by joined_at, owner_id loop
    t := (x.act ->> 'm')::int;
    if t = any (public.world_gg_nb(x.pos)) then
      update public.world_gw_members set prev = pos, pos = t where fight_id = p_fight and owner_id = x.owner_id;
    end if;
  end loop;
end $f$;

create or replace function public.world_gg_on_attack(p_fight uuid, p_uid uuid, p_round integer, p_d numeric)
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  return p_d * case when coalesce((f.board ->> 'broke')::int, 0) > 0 then 1 + coalesce((rb -> 'ledger' ->> 'broke_pct')::numeric, 0) / 100.0 else 1 end;
end $f$;

create or replace function public.world_gg_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; b jsonb; w record; x record; h jsonb; keep jsonb := '[]';
  extra numeric := 0; cells int[]; closed int[]; cnt int; sm int; nm text; tn text; fails int := 0; na int; tv int; hv int; mx int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; mx := coalesce((rb ->> 'max')::int, 9);
  closed := array(select jsonb_array_elements_text(coalesce(b -> 'closed', '[]'::jsonb))::int);
  select count(*) into na from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  if coalesce((b ->> 'broke')::int, 0) > 0 then b := b || jsonb_build_object('broke', (b ->> 'broke')::int - 1); end if;
  update public.world_gw_members x2 set gval = least(mx, greatest(0, x2.gval + coalesce((rb -> 'delta' ->> (x2.act ->> 'a'))::int, 0)))
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
      perform public.world_gw_say(p_fight, p_round, 'boss', '판결 망치가 ' || (h ->> 'col') || '번째 줄을 내리칩니다!');
      if exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells)) then fails := fails + 1; end if;
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
        perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'judge' ->> 'raw')::numeric * case when p_broke then 0.5 else 1 end, p_round, '판결 망치에', true);
      end loop;
    elsif h ->> 'k' = 'bargain' then
      perform public.world_gw_say(p_fight, p_round, 'boss', '값귀가 바가지를 씌웁니다! 값이 비쌀수록 크게 거둡니다.');
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
        perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'bargain' ->> 'raw')::numeric * ((rb -> 'bargain' ->> 'base')::numeric + (rb -> 'bargain' ->> 'k')::numeric * coalesce(x.gval, 0))
          * case when p_broke then 0.5 else 1 end, p_round, x.gval || '섬 바가지에', true);
      end loop;
      if exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.gval >= 8) then fails := fails + 1; end if;
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
          perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'ledger' ->> 'raw')::numeric, p_round, '맞지 않은 장부에', true);
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
    elsif h ->> 'k' = 'close' then
      closed := closed || (h ->> 'col')::int;
      perform public.world_gw_say(p_fight, p_round, 'bad', (h ->> 'col') || '번째 줄 좌판이 덧문을 내렸습니다. 그 줄에 서 있으면 라운드마다 다칩니다.');
    elsif h ->> 'k' = 'basket' then
      select string_agg(y.name, '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = (h ->> 'c')::int
        and coalesce(y.act ->> 'a', 'guard') in ('guard', 'brace');
      if nm is not null then
        perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — 떨이 바구니를 막아 엎었습니다.');
      else
        perform public.world_gw_say(p_fight, p_round, 'bad', '아무도 막지 않아 떨이 바구니가 쏟아집니다.');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
          perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'basket' ->> 'raw')::numeric, p_round, '쏟아진 떨이에', true);
        end loop;
      end if;
    elsif h ->> 'k' = 'tagm' then
      select string_agg(y.name, '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = (h ->> 'c')::int
        and y.gval = (b -> 'tags' ->> (h ->> 'c'))::int;
      if nm is not null then
        extra := extra + round(f.max_hp * (rb -> 'tagm' ->> 'hit_pct')::numeric / 100.0);
        perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — 값표와 값이 꼭 맞았습니다. 값귀가 움찔합니다.');
      else
        perform public.world_gw_say(p_fight, p_round, 'bad', '값표 앞에 같은 값인 사람이 없었습니다.');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
          perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'tagm' ->> 'raw')::numeric, p_round, '어긋난 셈에', true);
        end loop;
      end if;
    end if;
  end loop;
  if cardinality(closed) > 0 then
    for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and ((y.pos - 1) % 5) + 1 = any (closed) loop
      perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'close' ->> 'raw')::numeric, p_round, '닫힌 좌판에 끼여', false);
    end loop;
  end if;
  if fails > 0 and jsonb_typeof(rb -> 'fail_party') = 'object' then
    perform public.world_gw_say(p_fight, p_round, 'bad', '한 사람의 셈이 틀린 틈으로 값귀가 모두의 값을 거둡니다' || case when fails > 1 then '(' || fails || '번)' else '' end || '.');
    for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
      perform public.world_gg_dmg(p_fight, x.owner_id, (rb -> 'fail_party' ->> 'raw')::numeric * fails, p_round, '함께 거둔 값에', false);
    end loop;
  end if;
  update public.world_gw_fights set board = b || jsonb_build_object('hz', keep, 'closed', to_jsonb(closed)) where fight_id = p_fight;
  return extra;
end $f$;

create or replace function public.world_gg_after(p_fight uuid, p_round integer)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return true; end if;
  if not coalesce((f.board ->> 'low')::boolean, false) and f.hp > 0 and f.hp * 100 < f.max_hp * coalesce((rb ->> 'low_pct')::numeric, 10) then
    perform public.world_gw_say(p_fight, p_round, 'boss', '값귀의 낱장이 하나둘 하얗게 바랜다. 주판알이 헛돈다. 「한 줄에 쌀 두… 두…」');
    update public.world_gw_fights set board = board || '{"low": true}'::jsonb where fight_id = p_fight;
  end if;
  if rb ? 'close' and jsonb_array_length(coalesce(f.board -> 'closed', '[]'::jsonb)) >= (rb -> 'close' ->> 'max')::int and f.hp > 0 then
    perform public.world_gw_say(p_fight, p_round, 'bad', '장날이 파했습니다. 물이 곳간을 채우고 값귀가 장부를 안은 채 물 밑으로 가라앉습니다.');
    perform public.world_gw_settle(p_fight, false);
    return true;
  end if;
  return false;
end $f$;

create or replace function public.world_gg_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb := br -> 'board'; f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; b jsonb; cur jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  b := coalesce(f.board, '{}'::jsonb);
  cur := public.world_gg_seq(p_fight, f.hp, f.max_hp);
  return jsonb_build_object(
    'phase_name', br -> 'phases' ->> (f.phase - 1), 'phases', br -> 'phases', 'mechs', cur -> 'm', 'mech_names', br -> 'mech_names',
    'vals', (select coalesce(jsonb_object_agg(x.owner_id::text, x.gval), '{}'::jsonb) from public.world_gw_members x where x.fight_id = p_fight),
    'mine', me.gval, 'my_pos', me.pos,
    'moves', case when me.pos is not null and f.status = 'fight' then to_jsonb(public.world_gg_nb(me.pos)) else '[]'::jsonb end,
    'tags', coalesce(b -> 'tags', '{}'::jsonb), 'closed', coalesce(b -> 'closed', '[]'::jsonb),
    'hz', (select coalesce(jsonb_agg(e || jsonb_build_object('cells', to_jsonb(public.world_gg_hz_cells(p_fight, e)))
      || case when e ->> 'k' = 'ledger' then jsonb_build_object('sum', (select coalesce(sum(y.gval), 0) from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0
        and y.pos = any (array(select jsonb_array_elements_text(e -> 'cells')::int)))) else '{}'::jsonb end), '[]'::jsonb)
      from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) e),
    'delta', rb -> 'delta', 'haggle', (rb ->> 'haggle')::int, 'price', (rb ->> 'price')::int, 'max', coalesce((rb ->> 'max')::int, 9),
    'bargain', case when rb ? 'bargain' then jsonb_build_object('base', (rb -> 'bargain' ->> 'base')::numeric, 'k', (rb -> 'bargain' ->> 'k')::numeric) end,
    'close_max', (rb -> 'close' ->> 'max')::int,
    'broke', coalesce((b ->> 'broke')::int, 0));
end $f$;

create or replace function public.world_gg_settle(p_fight uuid, p_won boolean)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_boss_fight_rules(p_fight); f public.world_gw_fights%rowtype; m record; today date := (now() at time zone 'Asia/Seoul')::date;
  rec public.world_gw_records%rowtype; n int; solo boolean; flawless boolean; is_first boolean; xp int; msg text; lv int; v_gil int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status not in ('fight', 'wait') then return; end if;
  update public.world_gw_fights set status = case when p_won then 'won' else 'failed' end, ended_at = now(), updated_at = now(), hp = case when p_won then 0 else hp end where fight_id = p_fight;
  select count(*), coalesce(sum(falls), 0) = 0 into n, flawless from public.world_gw_members where fight_id = p_fight;
  solo := n = 1;
  if f.mode = 'story' then
    for m in select * from public.world_gw_members where fight_id = p_fight loop
      update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
      if p_won then
        insert into public.world_gw_records(owner_id, boss_id) values (m.owner_id, 'gapgwi_story') on conflict do nothing;
        select * into rec from public.world_gw_records where owner_id = m.owner_id and boss_id = 'gapgwi_story' for update;
        is_first := coalesce(rec.kills, 0) = 0;
        update public.world_gw_records set kills = kills + 1, last_kill_day = today, first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id and boss_id = 'gapgwi_story';
        v_gil := 0;
        if is_first then
          v_gil := (r -> 'first' ->> 'gil')::int;
          update public.world_characters set gil = gil + v_gil, updated_at = now() where owner_id = m.owner_id;
        end if;
        insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '값귀를 쓰러뜨렸습니다',
          case when is_first then '붉은 사당 골목에서 값귀를 쓰러뜨렸습니다. ' || to_char(v_gil, 'FM999,999') || '전을 받았습니다. 이야기를 이어 가세요.'
            else '붉은 사당 골목에서 다시 한 번 값귀를 쓰러뜨렸습니다.' end,
          jsonb_build_object('fight_id', p_fight, 'boss', 'gapgwi', 'mode', 'story', 'first', is_first));
      else
        insert into public.world_notifications(user_id, kind, title, content, payload)
        values (m.owner_id, 'gw', '값귀 앞에서 밀려났습니다', '이야기판은 밀려나도 잃는 것이 없습니다. 숨을 고르고 다시 서세요.', jsonb_build_object('fight_id', p_fight, 'boss', 'gapgwi', 'mode', 'story'));
      end if;
    end loop;
  else
    for m in select * from public.world_gw_members where fight_id = p_fight loop
      if p_won then
        update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
        insert into public.world_gw_records(owner_id, boss_id) values (m.owner_id, 'gapgwi') on conflict do nothing;
        select * into rec from public.world_gw_records where owner_id = m.owner_id and boss_id = 'gapgwi' for update;
        if rec.last_kill_day is distinct from today then
          is_first := coalesce(rec.kills, 0) = 0;
          update public.world_gw_records set kills = kills + 1, last_kill_day = today, first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id and boss_id = 'gapgwi';
          select level into lv from public.world_characters where owner_id = m.owner_id;
          xp := case when lv >= (r ->> 'xp_cap_lv')::int then 0
            else round(public.world_xp_need(lv) * case when is_first then (r -> 'first' ->> 'xp')::numeric else (r -> 'again' ->> 'xp')::numeric end) end;
          v_gil := case when is_first then (r -> 'first' ->> 'gil')::int else (r -> 'again' ->> 'gil')::int end;
          update public.world_characters set gil = gil + v_gil, updated_at = now() where owner_id = m.owner_id;
          if xp > 0 then xp := coalesce((public.world_grant_xp_got(m.owner_id, xp) ->> 'xp')::int, 0); end if;
          msg := case when is_first then '값귀를 처음으로 쓰러뜨렸습니다. ' || to_char(v_gil, 'FM999,999') || '전' || case when xp > 0 then ' · 경험치 ' || xp else '' end || '을 받았습니다.'
            else '값귀를 쓰러뜨렸습니다(' || (coalesce(rec.kills, 0) + 1) || '번째). ' || v_gil || '전' || case when xp > 0 then ' · 경험치 ' || xp else '' end || '.' end;
          insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '값귀 처치', msg, jsonb_build_object('fight_id', p_fight, 'first', is_first, 'boss', 'gapgwi'));
          insert into public.world_events(actor_id, actor_name, event_type, content, payload)
          values (m.owner_id, m.name, 'gg_win', m.name || '이(가) 붉은 사당 골목에서 값귀를 쓰러뜨렸습니다.',
                  jsonb_build_object('fight_id', p_fight, 'boss', 'gapgwi', 'first', is_first, 'solo', solo, 'flawless', flawless and n >= 2, 'members', n, 'kills', coalesce(rec.kills, 0) + 1));
        else
          insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '값귀 처치', '오늘은 이미 처치를 인정받아 보상은 없습니다.', jsonb_build_object('fight_id', p_fight, 'boss', 'gapgwi'));
        end if;
      else
        update public.world_item_durability d set durability = greatest(0, d.durability - ceil(public.world_item_max_durability(d.item_id) * (r -> 'fail' ->> 'dur')::numeric / 100.0)::int), updated_at = now()
          from public.world_character_equipment e where e.owner_id = m.owner_id and d.owner_id = m.owner_id and d.item_id = e.item_id;
        perform public.world_yohwa_overflow(m.owner_id, (select erosion from public.world_characters where owner_id = m.owner_id) + (r -> 'fail' ->> 'er')::int - 100);
        update public.world_characters set health = greatest(1, m.hp), erosion = least(100, erosion + (r -> 'fail' ->> 'er')::int),
               erosion_stage = case when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 80 then 4 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 55 then 3
                 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 30 then 2 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 10 then 1 else 0 end,
               updated_at = now() where owner_id = m.owner_id;
        insert into public.world_gw_records(owner_id, boss_id, last_fail_at) values (m.owner_id, 'gapgwi', now()) on conflict (owner_id, boss_id) do update set last_fail_at = now();
        insert into public.world_notifications(user_id, kind, title, content, payload)
        values (m.owner_id, 'gw', '값귀 도전 실패', '장부에 값을 거두어져 밀려났습니다. 장착한 장비 내구도가 ' || (r -> 'fail' ->> 'dur') || '% 닳고 침식이 ' || (r -> 'fail' ->> 'er') || ' 올랐습니다. '
          || (r -> 'fail' ->> 'cd') || '분 뒤 다시 도전할 수 있습니다.', jsonb_build_object('fight_id', p_fight, 'boss', 'gapgwi'));
      end if;
    end loop;
  end if;
  perform public.world_gw_say(p_fight, f.round, case when p_won then 'win' else 'bad' end, case when p_won
    then '값귀가 「한 줄에 쌀 두…」 하다가 말을 잇지 못한다. 덩어리가 무너지며 낱장이 눈보라처럼 흩날리고, 바닥에 닿은 낱장마다 먹 글씨가 하얗게 바랜다. 머리 위의 「섬」 글씨도 함께 사라졌다.'
    else '도전이 끝났습니다.' end);
end $f$;

revoke all on function public.world_gg_nb(integer), public.world_gg_col(integer), public.world_gg_dist(integer, integer), public.world_gg_dmg(uuid, uuid, numeric, integer, text, boolean),
  public.world_gg_hz_cells(uuid, jsonb), public.world_gg_seq(uuid, integer, integer), public.world_gg_steps(uuid, integer) from public, anon, authenticated;
grant execute on function public.world_gg_nb(integer), public.world_gg_col(integer), public.world_gg_dist(integer, integer), public.world_gg_dmg(uuid, uuid, numeric, integer, text, boolean),
  public.world_gg_hz_cells(uuid, jsonb), public.world_gg_seq(uuid, integer, integer), public.world_gg_steps(uuid, integer) to service_role, fn_owner_field;

revoke all on function public.world_gg_begin(uuid, integer), public.world_gg_round(uuid), public.world_gg_on_attack(uuid, uuid, integer, numeric),
  public.world_gg_mech(uuid, integer, boolean, boolean, uuid[]), public.world_gg_after(uuid, integer), public.world_gg_view(uuid, uuid),
  public.world_gg_settle(uuid, boolean) from public, anon, authenticated;
grant execute on function public.world_gg_begin(uuid, integer), public.world_gg_round(uuid), public.world_gg_on_attack(uuid, uuid, integer, numeric),
  public.world_gg_mech(uuid, integer, boolean, boolean, uuid[]), public.world_gg_after(uuid, integer), public.world_gg_view(uuid, uuid),
  public.world_gg_settle(uuid, boolean) to service_role, fn_owner_field;

select pg_temp.yh_patch('public.world_gw_next_round(uuid)',
  $o$  if f.mode = 'story' then perform public.world_story_round(p_fight); return; end if;$o$,
  $n$  if f.boss_id = 'gapgwi' then perform public.world_gg_round(p_fight); return; end if;
  if f.mode = 'story' then perform public.world_story_round(p_fight); return; end if;$n$);

select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$  if f.mode = 'story' then
    br := public.world_boss_fight_rules(p_fight);$o$,
  $n$  if f.boss_id = 'gapgwi' then
    br := public.world_boss_fight_rules(p_fight);
    update public.world_gw_fights set status = 'fight',
           max_hp = round(greatest((br ->> 'hp_min')::numeric, sa * (br ->> 'hp_atk')::numeric) * (br -> 'hp_n' ->> (least(4, n) - 1))::numeric),
           hp = round(greatest((br ->> 'hp_min')::numeric, sa * (br ->> 'hp_atk')::numeric) * (br -> 'hp_n' ->> (least(4, n) - 1))::numeric), phase = 1, round = 0, cycle = 0,
           ends_at = now() + make_interval(mins => (br ->> 'min')::int), updated_at = now() where fight_id = p_fight;
    if n = 1 and f.mode <> 'story' then update public.world_gw_members m set stats = m.stats || public.world_solo_aid(m.job_key, 'gapgwi') where fight_id = p_fight; end if;
    perform public.world_gg_begin(p_fight, n);
    perform public.world_gw_next_round(p_fight);
    return;
  end if;
  if f.mode = 'story' then
    br := public.world_boss_fight_rules(p_fight);$n$);

select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$v_item := case when f.boss_id = 'mukjeok' then public.world_boss_rules() -> 'mukjeok' ->> 'item' else 'gwiheo_charm' end;$o$,
  $n$v_item := case when f.boss_id in ('mukjeok', 'gapgwi') then public.world_boss_rules() -> f.boss_id ->> 'item' else 'gwiheo_charm' end;$n$);

select pg_temp.yh_patch('public.world_gw_settle(uuid,boolean)',
  $o$  if f.boss_id = 'mukjeok' then perform public.world_mk_settle(p_fight, p_won); return; end if;$o$,
  $n$  if f.boss_id = 'gapgwi' then perform public.world_gg_settle(p_fight, p_won); return; end if;
  if f.boss_id = 'mukjeok' then perform public.world_mk_settle(p_fight, p_won); return; end if;$n$);

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$v_who := case when f.boss_id = 'mukjeok' then '그림자' else '주인' end;$o$,
  $n$v_who := case when f.boss_id = 'mukjeok' then '그림자' when f.boss_id = 'gapgwi' then '값귀' else '주인' end;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'mukjeok' then perform public.world_mk_steps(p_fight, r); end if;$o$,
  $n$  if f.boss_id = 'mukjeok' then perform public.world_mk_steps(p_fight, r); end if;
  if f.boss_id = 'gapgwi' then perform public.world_gg_steps(p_fight, r); end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$      if f.boss_id = 'mukjeok' then d := d * public.world_mk_on_attack(p_fight, m.owner_id, r);$o$,
  $n$      if f.boss_id = 'gapgwi' then d := public.world_gg_on_attack(p_fight, m.owner_id, r, d);
      elsif f.boss_id = 'mukjeok' then d := d * public.world_mk_on_attack(p_fight, m.owner_id, r);$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$elsif av = 'call' and (f.boss_id = 'mukjeok' or f.mode = 'story') then$o$,
  $n$elsif av in ('deal', 'move') and f.boss_id = 'gapgwi' then
      null;
    elsif av = 'call' and (f.boss_id in ('mukjeok', 'gapgwi') or f.mode = 'story') then$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.mode = 'story' then boss_dmg := boss_dmg + public.world_story_mech(p_fight, r, broke, delayed, freed);$o$,
  $n$  if f.boss_id = 'gapgwi' then boss_dmg := boss_dmg + public.world_gg_mech(p_fight, r, broke, delayed, freed);
  elsif f.mode = 'story' then boss_dmg := boss_dmg + public.world_story_mech(p_fight, r, broke, delayed, freed);$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'mukjeok' then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if public.world_mk_after(p_fight, r) then return; end if;$o$,
  $n$  if f.boss_id in ('mukjeok', 'gapgwi') then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if (case when f.boss_id = 'gapgwi' then public.world_gg_after(p_fight, r) else public.world_mk_after(p_fight, r) end) then return; end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$if f.boss_id = 'mukjeok' or f.mode = 'story' then raw := public.world_mk_raw(p_fight); else$o$,
  $n$if f.boss_id in ('mukjeok', 'gapgwi') or f.mode = 'story' then raw := public.world_mk_raw(p_fight); else$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$case when f.boss_id = 'mukjeok' then '먹구름이 터집니다.$o$,
  $n$case when f.boss_id = 'gapgwi' then '값귀가 장부를 통째로 펼칩니다. 낱장이 사당 안을 한꺼번에 휩쓸며 쏟아집니다!' || case when broke then ' (퇴마 결계가 낱장을 절반으로 꺾었습니다)' else '' end
        when f.boss_id = 'mukjeok' then '먹구름이 터집니다.$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$case when f.boss_id = 'mukjeok' then '쏟아지는 먹비에' else '쏟아지는 물살에' end$o$,
  $n$case when f.boss_id = 'mukjeok' then '쏟아지는 먹비에' when f.boss_id = 'gapgwi' then '휘몰아치는 낱장에' else '쏟아지는 물살에' end$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$case when f.boss_id = 'mukjeok' then '모두가 물러났습니다. 먹이 가운데 칸을 덮습니다.'$o$,
  $n$case when f.boss_id = 'mukjeok' then '모두가 물러났습니다. 먹이 가운데 칸을 덮습니다.' when f.boss_id = 'gapgwi' then '모두가 물러났습니다. 값귀가 모두의 값을 장부에 거두어 갑니다.'$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$case when f.boss_id = 'mukjeok' then '시간이 다 되었습니다. 먹그림자가 명부를 먹으로 덮습니다.'$o$,
  $n$case when f.boss_id = 'mukjeok' then '시간이 다 되었습니다. 먹그림자가 명부를 먹으로 덮습니다.' when f.boss_id = 'gapgwi' then '시간이 다 되었습니다. 값귀가 장부를 안고 사당 밑 곳간으로 가라앉습니다.'$n$);

select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$if p_action not in ('attack', 'guard', 'brace', 'coop', 'call', 'chain', 'item', 'recall') then$o$,
  $n$if p_action not in ('attack', 'guard', 'brace', 'coop', 'call', 'chain', 'item', 'recall', 'deal') then$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if mk and p_action = 'chain' then raise exception '알 수 없는 행동입니다.'; end if;$o$,
  $n$  if mk and p_action = 'chain' then raise exception '알 수 없는 행동입니다.'; end if;
  if p_action = 'deal' and f.boss_id <> 'gapgwi' then raise exception '알 수 없는 행동입니다.'; end if;
  if f.boss_id = 'gapgwi' then
    if p_action = 'chain' then raise exception '알 수 없는 행동입니다.'; end if;
    if p_action = 'call' and (p_target is null or p_target = uid) then raise exception '값을 매겨 줄 동료를 고르세요.'; end if;
    if p_move is not null and p_move = me.pos then p_move := null; end if;
    if p_move is not null and not (p_move::int = any (public.world_gg_nb(me.pos))) then raise exception '바로 옆(가로·세로) 칸으로만 옮겨 설 수 있습니다.'; end if;
  end if;$n$);

select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'board', case when f.boss_id = 'mukjeok' then$o$,
  $n$'board', case when f.boss_id = 'gapgwi' then public.world_gg_view(fid, uid) when f.boss_id = 'mukjeok' then$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'pos', m.pos, 'bound',$o$,
  $n$'pos', m.pos, 'val', m.gval, 'bound',$n$);

select pg_temp.yh_patch('public.world_gw_open(text,text)',
  $o$    if boss = 'mukjeok' then
      insert into public.world_notifications(user_id, kind, title, content, payload)$o$,
  $n$    if boss = 'gapgwi' then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (x.owner_id, 'gw_invite', '값귀 · 함께 싸우기', c.character_name || '이(가) 붉은 사당 골목에서 값귀 앞에 섰습니다. 60초 안에 합류하세요' || case when md = 'story' then '.' else '(' || (br ->> 'item_name') || ' 1개).' end,
        jsonb_build_object('fight_id', fid, 'boss', boss, 'mode', md));
    elsif boss = 'mukjeok' then
      insert into public.world_notifications(user_id, kind, title, content, payload)$n$);

select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$  if p_boss = 'mukjeok' then$o$,
  $n$  if p_boss in ('mukjeok', 'gapgwi') then$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$raise exception '%을(를) 마친 뒤에 더 깊은 명부가 열립니다.', br ->> 'hard_quest_name'; end if;$o$,
  $n$raise exception '%', case when p_boss = 'gapgwi' then br ->> 'hard_quest_name' || '을(를) 마친 뒤에 ' || (br -> 'modes' ->> 'hard') || '이(가) 열립니다.'
      else br ->> 'hard_quest_name' || '을(를) 마친 뒤에 더 깊은 명부가 열립니다.' end; end if;$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$case when p_boss = 'mukjeok' then '먹그림자를 보냈습니다' else '귀허의 주인을 쓰러뜨렸습니다' end$o$,
  $n$case when p_boss = 'mukjeok' then '먹그림자를 보냈습니다' when p_boss = 'gapgwi' then '값귀를 쓰러뜨렸습니다' else '귀허의 주인을 쓰러뜨렸습니다' end$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$case when p_boss = 'mukjeok' then '명부의 먹이 아직 마르지 않았습니다' else '귀허의 소용돌이가 아직 가라앉지 않았습니다' end$o$,
  $n$case when p_boss = 'mukjeok' then '명부의 먹이 아직 마르지 않았습니다' when p_boss = 'gapgwi' then '값귀의 장부가 아직 젖어 있습니다' else '귀허의 소용돌이가 아직 가라앉지 않았습니다' end$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$raise exception '%이(가) 필요합니다. %에서 팝니다.', br ->> 'item_name', br ->> 'shop_name'; end if;$o$,
  $n$raise exception '%이(가) 필요합니다. %', br ->> 'item_name', coalesce(br ->> 'item_where', br ->> 'shop_name' || '에서 팝니다.'); end if;$n$);

select pg_temp.yh_patch('public.world_gw_tips(text)',
  $o$select case when p_boss = 'mukjeok' then jsonb_build_array($o$,
  $n$select case when p_boss = 'gapgwi' then jsonb_build_array(
    '장터: 위아래 좌판 두 줄과 가운데 거리 한 줄, 다섯 칸씩. 라운드마다 가로·세로 바로 옆 칸으로 한 칸 옮겨 선다. 망치·장부·외상 줄은 모두 칸 위에 숫자로 미리 보이고, !가 되는 라운드에 떨어진다.',
    '값(섬): 공격·협동 기술마다 값이 오른다. 「흥정」으로 내 값을 깎고, 바로 옆 칸 동료에게 「값 매기기」로 값을 올려 준다.',
    '판결 망치: 붉게 칠해진 세로줄에서 비킨다. 바가지: 떨어지는 라운드에 값이 비쌀수록 크게 맞으니 미리 깎아 둔다.',
    '장부 맞추기: 흰 좌판마다 한 사람씩 서서 그 사람들의 값을 더해 합을 맞춘다. 숫자가 줄어드는 동안 흥정과 값 매기기로 값을 맞춰 두고, 마지막 라운드에 좌판 위에 서 있어야 한다.',
    '외상 줄: 묶인 두 사람이 세 칸 이상 떨어지면 끊긴다. 장 닫힘: 왼쪽 줄부터 닫히니 오른쪽(저울 쪽)으로 옮겨 가며 싸운다. 네 줄이 닫히기 전에 쓰러뜨린다.')
  when p_boss = 'mukjeok' then jsonb_build_array($n$);

select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$tt not in ('gw', 'mj', 'raid',$o$, $n$tt not in ('gw', 'mj', 'gg', 'raid',$n$);
select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$  if tt in ('gw', 'mj') then$o$, $n$  if tt in ('gw', 'mj', 'gg') then$n$);
select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$case when tt = 'mj' then 'mukjeok' else$o$, $n$case when tt = 'mj' then 'mukjeok' when tt = 'gg' then 'gapgwi' else$n$);

select pg_temp.yh_patch('public.world_quest_task_label(jsonb)',
  $o$    when p_task ->> 't' = 'mj' then$o$,
  $n$    when p_task ->> 't' = 'gg' then case when p_task ->> 'mode' = 'story' then '붉은 사당 골목에서 값귀 쓰러뜨리기' else '깊은 장부에서 값귀 쓰러뜨리기' end
    when p_task ->> 't' = 'mj' then$n$);
