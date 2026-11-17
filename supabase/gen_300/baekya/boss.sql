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
begin
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$',
    (public.world_boss_rules() - 'baekya') || jsonb_build_object('baekya', $j${
  "name": "백야", "fight": "흰 밤의 맹약 마당", "place": "맹약 마당", "arc": "명등기", "region": "pact_court", "lv": 50,
  "quest": "mdq_15", "quest_name": "외전 「명등기」 15장 「검은 끈의 장」", "item": "pact_stone_dust", "item_name": "맹약 돌가루", "item_where": "맹약 마당에서 채집해 얻습니다.",
  "min": 18, "hp_min": 9000, "hp_atk": 46, "hp_n": [0.8, 0.9, 0.8, 1.0], "raw_n": [0.6, 0.62, 0.8, 0.85], "raw": [44, 4], "enrage": 0.15,
  "first": {"gil": 2500, "xp": 0.5, "mount": "first_night_horse", "mount_name": "첫 밤 흑마", "name_style": "ns:1037", "name_style_name": "청야", "furniture": "by_first"}, "again": {"gil": 150, "xp": 0.05}, "fail": {"dur": 10, "er": 10, "cd": 30}, "falls": 10, "xp_cap_lv": 50,
  "hard_quest": "mdq_17", "hard_quest_name": "외전 「명등기」 17장 「명등」",
  "modes": {"story": "이야기판", "hard": "깊은 흰 밤"},
  "phases": ["화살비", "붉은 붓", "물방울과 가루", "흰 밤"],
  "mech_names": {"arrow": "화살비", "brush": "붉은 붓", "drop": "물방울·흰 가루", "tower": "등 기둥 탑", "clock": "멈춤 시계", "num": "차례 화살", "big": "굵은 화살", "gust": "꺼져 가는 등", "wn": "흰 밤", "sdrop": "멈춘 물방울", "flick": "흔들리는 등"},
  "story": {"phases": ["멈춘 물방울", "흔들리는 등", "물방울과 등", "흰 밤"], "min": 30, "round_s": 60, "hp_min": 2400, "hp_atk": 26, "hp_n": [1, 1, 1, 1], "raw": [12, 2], "first": {"gil": 1000},
    "board": {"fade": null, "sweep_fade": 0,
      "sdrop": {"every": 3, "off": 1, "left": 2, "raw": 15},
      "flick": {"every": 4, "off": 3, "left": 2},
      "wn": {"need": 5, "need_solo": 5, "rounds": [0, 0, 0, 0], "arrow_left": 0, "fails": 99, "fail_hp": 40},
      "seq": [{"at": 100, "m": ["sdrop"]}, {"at": 75, "m": ["flick"]}, {"at": 50, "m": ["sdrop", "flick"]}, {"at": 25, "m": ["wn"]}]}},
  "board": {
    "dmg_lo": 0.7, "dmg_k": 0.3, "hurt_hi": 1.15, "hurt_k": 0.15,
    "fade": {"pct": 15, "stun": 3, "after": 1, "item": 1, "medic": 2},
    "sweep_fade": 0, "mech_mul": 0.35,
    "arrow": {"every": 2, "off": 0, "n": [1, 2, 2, 3], "left": 3, "raw": 30, "fade": 1},
    "brush": {"every": 4, "off": 1, "left": 2, "raw": 40, "width": 1},
    "drop": {"every": 4, "off": 3, "left": 3, "stack_raw": 44, "spread_raw": 18, "solo_mul": 0.4, "swap": false},
    "tower": {"every": 3, "off": 2, "left": 3, "need": [1, 1, 1, 2], "raw": 18},
    "clock": {"every": 5, "off": 4, "left": 3, "pair_drop": false},
    "num": {"every": 7, "off": 3, "raw": 35, "fade": 1},
    "big": {"every": 5, "off": 2, "left": 3, "raw": 45, "fade": 1},
    "gust": {"every": 5, "off": 4, "left": 3, "raw": 25},
    "wn": {"need": 7, "need_solo": 5, "rounds": [16, 14, 12, 12], "arrow_left": 2, "fail_hp": 40, "fails": 1, "wipe": false},
    "aoe_every": 4,
    "seq": [{"at": 100, "m": ["arrow"]}, {"at": 87.5, "m": ["arrow", "brush"]}, {"at": 75, "m": ["brush", "drop", "gust"]}, {"at": 50, "m": ["brush", "drop", "tower", "gust", "big"]},
      {"at": 37.5, "m": ["arrow", "tower", "clock", "big", "gust", "drop"]}, {"at": 25, "m": ["wn", "arrow", "drop", "brush", "clock", "big"]}],
    "voices": ["남명이 부른다. 내 백성은 내가 부른다.", "북령이 부른다. 다시는, 이 아니라 이번에는.", "적월이 부른다. 값이 아니라 이름으로.",
      "수향이 부른다. 태우지 못한 아이들을, 한 이름씩.", "천명이 부른다. 별이 아니라 사람이 정한다.", "정청이 부른다. 고친 보고서 대신, 거둬 간 동료의 이름을.",
      "흑련이 부른다. 맡아 둔 이름을 돌려준다. — 아이 목소리가 들렸다. 「서율 오라버니!」"]},
  "solo": {"artificer": {"solo_dmg": -35, "solo_guard": 20}, "scout": {"solo_dmg": -15, "solo_guard": 45}, "exorcist": {"solo_dmg": -36, "solo_guard": 20},
    "medic": {"solo_dmg": 20, "solo_guard": 20}, "sealmaster": {"solo_dmg": -15, "solo_guard": 25}, "analyst": {"solo_dmg": -25, "solo_guard": 35},
    "tamer": {"solo_dmg": -25, "solo_guard": 35}}
}$j$::jsonb));
end $$;


create or replace function public.world_by_nb(p_cell integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select case when p_cell between 1 and 7 then array[((p_cell + 5) % 7) + 1, (p_cell % 7) + 1, p_cell + 7]
  when p_cell between 8 and 14 then array[((p_cell - 7 + 5) % 7) + 8, ((p_cell - 7) % 7) + 8, p_cell - 7] else '{}'::int[] end $f$;

create or replace function public.world_by_sector(p_cell integer)
 returns integer language sql immutable set search_path = ''
as $f$ select case when p_cell between 1 and 14 then ((p_cell - 1) % 7) + 1 end $f$;

create or replace function public.world_by_area(p_cell integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select case when p_cell between 1 and 14 then array[p_cell] || public.world_by_nb(p_cell) else '{}'::int[] end $f$;

create or replace function public.world_by_sweep_cells(p_s integer, p_w integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select array(select c from generate_series(1, 14) c where least(abs(public.world_by_sector(c) - p_s), 7 - abs(public.world_by_sector(c) - p_s)) <= p_w order by c) $f$;

create or replace function public.world_by_lamps(p_board jsonb)
 returns integer language sql immutable set search_path = ''
as $f$ select coalesce(jsonb_array_length(p_board -> 'lamps'), 0) $f$;

create or replace function public.world_by_hz_cells(p_fight uuid, p_hz jsonb)
 returns integer[] language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare p int; rb jsonb;
begin
  if p_hz ->> 'k' in ('arrow', 'sdrop', 'tower') then return array[(p_hz ->> 'c')::int]; end if;
  if p_hz ->> 'k' in ('flick', 'gust') then return array[(p_hz ->> 's')::int]; end if;
  if p_hz ->> 'k' = 'big' then return public.world_by_area((p_hz ->> 'c')::int); end if;
  if p_hz ->> 'k' = 'brush' then
    rb := public.world_boss_fight_rules(p_fight) -> 'board';
    return public.world_by_sweep_cells((p_hz ->> 's')::int, coalesce((rb -> 'brush' ->> 'width')::int, 1));
  end if;
  if p_hz ->> 'k' in ('stack', 'spread', 'num') then
    select pos into p from public.world_gw_members where fight_id = p_fight and owner_id = (p_hz ->> 't')::uuid;
    return public.world_by_area(p);
  end if;
  if p_hz ->> 'k' = 'clock' then
    select pos into p from public.world_gw_members where fight_id = p_fight and owner_id = (p_hz ->> 't')::uuid;
    return case when p is null then '{}'::int[] else array[p] end;
  end if;
  return '{}'::int[];
end $f$;

create or replace function public.world_by_hurt_mul(p_fight uuid, p_uid uuid)
 returns numeric language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; b jsonb;
begin
  select board into b from public.world_gw_fights where fight_id = p_fight;
  return ((rb ->> 'hurt_hi')::numeric - (rb ->> 'hurt_k')::numeric * public.world_by_lamps(b) / 7.0)
    * (1 + coalesce((rb -> 'fade' ->> 'pct')::numeric, 0) * coalesce((b -> 'fade' ->> p_uid::text)::int, 0) / 100.0);
end $f$;

create or replace function public.world_by_on_attack(p_fight uuid, p_uid uuid, p_round integer)
 returns numeric language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; b jsonb;
begin
  select board into b from public.world_gw_fights where fight_id = p_fight;
  return (rb ->> 'dmg_lo')::numeric + (rb ->> 'dmg_k')::numeric * public.world_by_lamps(b) / 7.0;
end $f$;

create or replace function public.world_by_fade(p_fight uuid, p_board jsonb, p_uid uuid, p_n integer, p_round integer)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; v int; nm text;
begin
  if rb -> 'fade' is null or jsonb_typeof(rb -> 'fade') <> 'object' or p_n = 0 then return p_board; end if;
  v := greatest(0, coalesce((p_board -> 'fade' ->> p_uid::text)::int, 0) + p_n);
  if v >= (rb -> 'fade' ->> 'stun')::int then
    select name into nm from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
    perform public.world_gw_say(p_fight, p_round, 'bad', nm || ' — 온몸이 하얗게 바래 다음 라운드에는 꼼짝도 할 수 없습니다.');
    return p_board || jsonb_build_object('fade', coalesce(p_board -> 'fade', '{}'::jsonb) || jsonb_build_object(p_uid::text, (rb -> 'fade' ->> 'after')::int),
      'stun', coalesce(p_board -> 'stun', '{}'::jsonb) || jsonb_build_object(p_uid::text, p_round + 1));
  end if;
  return p_board || jsonb_build_object('fade', coalesce(p_board -> 'fade', '{}'::jsonb) || jsonb_build_object(p_uid::text, v));
end $f$;

create or replace function public.world_by_dmg(p_fight uuid, p_uid uuid, p_raw numeric, p_round integer, p_why text, p_guardable boolean)
 returns integer language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare m public.world_gw_members%rowtype;
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  return public.world_gw_hurt(p_fight, p_uid, round(p_raw * coalesce((public.world_boss_fight_rules(p_fight) -> 'board' ->> 'mech_mul')::numeric, 1) * public.world_by_hurt_mul(p_fight, p_uid)
    * case when p_guardable and coalesce(m.act ->> 'a', 'guard') in ('guard', 'brace') then 0.5 else 1 end)::int, p_round, p_why);
end $f$;

create or replace function public.world_by_begin(p_fight uuid, p_n integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare x record; k int := 0;
begin
  for x in select owner_id from public.world_gw_members where fight_id = p_fight order by joined_at, owner_id loop
    update public.world_gw_members set pos = 8 + floor(k * 7.0 / greatest(1, p_n))::int, prev = null where fight_id = p_fight and owner_id = x.owner_id;
    k := k + 1;
  end loop;
  update public.world_gw_fights set board = coalesce(board, '{}'::jsonb) || jsonb_build_object('lamps', '[1, 2, 3, 4, 5, 6, 7]'::jsonb, 'hz', '[]'::jsonb, 'fade', '{}'::jsonb,
    'stun', '{}'::jsonb, 'seq', 0, 'wn_fail', 0, 'hid', 0) where fight_id = p_fight;
  perform public.world_gw_say(p_fight, 0, 'phase', '경현이 먹 도랑에 두 손을 담근다. 도랑의 먹물이 손을 타고 거꾸로 기어올라 하얗게 바래며 온몸을 덮는다. 정리관 옷 모양 그대로인 하얀 형체 위로 이름 글자가 개미 떼처럼 기어 다닌다.');
  perform public.world_gw_say(p_fight, 0, 'phase', '하얀 손이 허공을 긋자 화살과 물방울이 쏘아지다 말고 그 자리에 멈춘다. 등이 켜진 쪽에서만 멈춘 것들이 조금씩 떨어져 내린다.');
end $f$;

create or replace function public.world_by_seq(p_fight uuid, p_hp integer, p_max integer)
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

create or replace function public.world_by_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb; b jsonb; nr int; ph int; m jsonb; tell text := ''; aoe boolean := false;
  n int; na int; alive uuid[]; lamps int[]; hz jsonb := '[]'; h jsonb; cur jsonb; mechs text[]; cfg jsonb; story boolean; len int := 5; nn int; c int; t uuid;
  hid int; free_cells int[]; w jsonb; need int; rounds int; s int; i int; k int; nm text; due boolean := false;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  rb := br -> 'board'; b := coalesce(f.board, '{}'::jsonb); nr := f.round + 1; story := f.mode = 'story';
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  select coalesce(array_agg(owner_id order by random()), '{}') into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
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
      when 'flick' = any (mechs) then '등 하나가 파르르 떨린다. 누군가 곁에 서 있어야 꺼지지 않는다.'
      else '하얀 몸이 다시 일어선다.' end);
    b := b || jsonb_build_object('seq', (cur ->> 'i')::int);
  end if;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    if h ->> 'k' = 'arrow' and not (public.world_by_sector((h ->> 'c')::int) = any (lamps)) then
      h := h || '{"frozen": true}'::jsonb;
    else
      h := (h - 'frozen') || jsonb_build_object('left', (h ->> 'left')::int - 1);
    end if;
    if h ->> 'k' in ('stack', 'spread') and coalesce((h ->> 'sw')::boolean, false) is false and coalesce((rb -> 'drop' ->> 'swap')::boolean, false) and (h ->> 'left')::int = 1 then
      h := h || jsonb_build_object('k', case h ->> 'k' when 'stack' then 'spread' else 'stack' end, 'sw', true);
      perform public.world_gw_say(p_fight, nr, 'warn', '바람이 거꾸로 분다. 물방울과 흰 가루가 뒤바뀐다.');
    end if;
    hz := hz || jsonb_build_array(h);
  end loop;
  if 'wn' = any (mechs) and not b ? 'wn' then
    cfg := rb -> 'wn';
    need := case when n = 1 then (cfg ->> 'need_solo')::int else (cfg ->> 'need')::int end;
    rounds := coalesce((cfg -> 'rounds' ->> (least(4, greatest(1, n)) - 1))::int, 0);
    lamps := '{}';
    hz := (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(hz) e where e ->> 'k' in ('stack', 'spread', 'clock'));
    if coalesce((cfg ->> 'arrow_left')::int, 0) > 0 then
      for s in 1 .. 7 loop
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'arrow', 'c', case when random() < 0.5 then s else s + 7 end, 'left', (cfg ->> 'arrow_left')::int, 'frozen', true));
      end loop;
    end if;
    b := b || jsonb_build_object('wn', jsonb_build_object('start', nr, 'hp', f.hp, 'need', need, 'lit', 0, 'at', case when rounds > 0 then nr + rounds - 1 end));
    tell := '흰 밤 — 등 기둥 칸에서 「등 켜기」로 등 ' || need || '개를 켜라' || case when rounds > 0 then '(' || rounds || '라운드 안에)' else '' end || '. 켠 등 둘레의 멈춘 화살이 떨어지기 시작한다.';
  end if;
  if na > 0 then
    free_cells := array(select c2 from generate_series(1, 14) c2);
    if 'arrow' = any (mechs) and not b ? 'wn' and nr % (rb -> 'arrow' ->> 'every')::int = (rb -> 'arrow' ->> 'off')::int then
      nn := least(na, coalesce((rb -> 'arrow' -> 'n' ->> (least(4, greatest(1, n)) - 1))::int, 1));
      for i in 1 .. nn loop
        select pos into c from public.world_gw_members where fight_id = p_fight and owner_id = alive[i];
        if c is null then continue; end if;
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'arrow', 'c', c, 'left', (rb -> 'arrow' ->> 'left')::int));
      end loop;
      tell := tell || case when tell <> '' then ' ' else '' end || '허공에 화살이 멈춰 선다. 발밑을 보라.';
    end if;
    if 'brush' = any (mechs) and nr % (rb -> 'brush' ->> 'every')::int = (rb -> 'brush' ->> 'off')::int then
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'brush', 's', 1 + floor(random() * 7)::int, 'left', (rb -> 'brush' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '붉은 붓이 마당 한쪽을 겨눈다.';
    end if;
    if 'drop' = any (mechs) and nr % (rb -> 'drop' ->> 'every')::int = (rb -> 'drop' ->> 'off')::int then
      k := coalesce((b ->> 'dropk')::int, 0); b := b || jsonb_build_object('dropk', k + 1);
      if na >= 3 or na = 1 or k % 2 = 0 then
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'stack', 't', alive[1], 'left', (rb -> 'drop' ->> 'left')::int));
      end if;
      if na >= 3 or (na = 2 and k % 2 = 1) then
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'spread', 't', alive[2], 'left', (rb -> 'drop' ->> 'left')::int));
      end if;
      tell := tell || case when tell <> '' then ' ' else '' end || case when na = 2 and k % 2 = 1 then '흰 가루가 머리 위에 멈춘다.' when na = 2 or na = 1 then '물방울이 머리 위에 멈춘다.' else '물방울과 흰 가루가 머리 위에 멈춘다.' end;
    end if;
    if 'tower' = any (mechs) and nr % (rb -> 'tower' ->> 'every')::int = (rb -> 'tower' ->> 'off')::int then
      need := least(na, coalesce((rb -> 'tower' -> 'need' ->> (least(4, greatest(1, n)) - 1))::int, 1));
      select z into c from unnest(lamps) z where not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'tower' and (e ->> 'c')::int = z) order by random() limit 1;
      if c is not null then
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'tower', 'c', c, 'need', need, 'left', (rb -> 'tower' ->> 'left')::int));
        tell := tell || case when tell <> '' then ' ' else '' end || c || '번 등 기둥 아래로 하얀 기둥이 솟는다.';
      end if;
    end if;
    if 'clock' = any (mechs) and nr % (rb -> 'clock' ->> 'every')::int = (rb -> 'clock' ->> 'off')::int then
      t := alive[na];
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'clock', 't', t, 'left', (rb -> 'clock' ->> 'left')::int));
      if coalesce((rb -> 'clock' ->> 'pair_drop')::boolean, false) then
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'stack', 't', t, 'left', (rb -> 'clock' ->> 'left')::int, 'pair', true));
      end if;
      tell := tell || case when tell <> '' then ' ' else '' end || '머리 위에 모래시계가 멈춘다.';
    end if;
    if 'num' = any (mechs) and rb ? 'num' and nr % (rb -> 'num' ->> 'every')::int = (rb -> 'num' ->> 'off')::int then
      for i in 1 .. na loop
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'num', 't', alive[i], 'i', i, 'left', i + 1));
      end loop;
      tell := tell || case when tell <> '' then ' ' else '' end || '사람마다 숫자가 새겨진 화살이 머리 위에 멈춘다.';
    end if;
    if 'big' = any (mechs) and nr % (rb -> 'big' ->> 'every')::int = (rb -> 'big' ->> 'off')::int then
      select pos into c from public.world_gw_members where fight_id = p_fight and owner_id = alive[na];
      if c is not null then
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'big', 'c', c, 'left', (rb -> 'big' ->> 'left')::int));
        tell := tell || case when tell <> '' then ' ' else '' end || '굵은 화살 하나가 ' || c || '번 칸 위에 멈춘다. 그 둘레가 모두 과녁이다.';
      end if;
    end if;
    if 'gust' = any (mechs) and not b ? 'wn' and nr % (rb -> 'gust' ->> 'every')::int = (rb -> 'gust' ->> 'off')::int then
      select z into c from unnest(lamps) z where not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'gust' and (e ->> 's')::int = z) order by random() limit 1;
      if c is not null then
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'gust', 's', c, 'left', (rb -> 'gust' ->> 'left')::int));
        tell := tell || case when tell <> '' then ' ' else '' end || c || '번 등이 흔들리기 시작한다.';
      end if;
    end if;
    if 'sdrop' = any (mechs) and nr % (rb -> 'sdrop' ->> 'every')::int = (rb -> 'sdrop' ->> 'off')::int then
      hid := hid + 1;
      hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'sdrop', 'c', 8 + floor(random() * 7)::int, 'left', (rb -> 'sdrop' ->> 'left')::int));
      tell := tell || case when tell <> '' then ' ' else '' end || '큰 물방울 하나가 마당 위에 멈춘다. 누군가 그 아래에서 막으면 깨진다.';
    end if;
    if 'flick' = any (mechs) and nr % (rb -> 'flick' ->> 'every')::int = (rb -> 'flick' ->> 'off')::int then
      select z into c from unnest(lamps) z order by random() limit 1;
      if c is not null then
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'flick', 's', c, 'left', (rb -> 'flick' ->> 'left')::int));
        tell := tell || case when tell <> '' then ' ' else '' end || c || '번 등이 흔들린다. 그 등 아래에 서 있어라.';
      end if;
    end if;
  end if;
  if exists (select 1 from jsonb_array_elements(hz) e where (e ->> 'left')::int <= 0 and not coalesce((e ->> 'frozen')::boolean, false)) then due := true; end if;
  if b ? 'wn' then
    tell := tell || case when tell <> '' then ' ' else '' end || '흰 밤 — 켠 등 ' || (b -> 'wn' ->> 'lit') || '/' || (b -> 'wn' ->> 'need')
      || case when b -> 'wn' ->> 'at' is not null then ' · ' || ((b -> 'wn' ->> 'at')::int - nr + 1) || '라운드 남음' else '' end || '.';
  elsif nr % (rb ->> 'aoe_every')::int = 0 then
    aoe := true;
    tell := tell || case when tell <> '' then ' — ' else '' end || '흰 소매가 크게 펼쳐진다. 마당 전체를 휩쓸 것 같다.';
  end if;
  if tell = '' then tell := '사르륵사르륵, 하얀 몸 위로 이름 글자들이 종이 넘기는 소리를 낸다.'; end if;
  b := b || jsonb_build_object('hz', hz, 'lamps', to_jsonb(coalesce(lamps, '{}'::int[])), 'hid', hid);
  m := jsonb_build_object('k', 'normal', 'phase_name', br -> 'phases' ->> (ph - 1), 'aoe', aoe, 'tell', tell, 'lamps', coalesce(array_length(lamps, 1), 0),
    'mechs', to_jsonb(mechs)) || case when b ? 'wn' then jsonb_build_object('wn', b -> 'wn') else '{}'::jsonb end;
  if due or b ? 'wn' then len := 10; end if;
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when not story then len when n = 1 then 86400 else (br ->> 'round_s')::int end), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, nr, case when aoe or due then 'warn' else 'tell' end, tell);
end $f$;

create or replace function public.world_by_steps(p_fight uuid, p_round integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare x record; t int;
begin
  for x in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ? 'm' order by joined_at, owner_id loop
    t := (x.act ->> 'm')::int;
    if t = any (public.world_by_nb(x.pos)) then
      update public.world_gw_members set prev = pos, pos = t where fight_id = p_fight and owner_id = x.owner_id;
    end if;
  end loop;
end $f$;

create or replace function public.world_by_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; b jsonb; n int; na int; w record; x record; h jsonb; keep jsonb := '[]';
  lamps int[]; saved int[] := '{}'; wn jsonb; extra numeric := 0; cells int[]; fails int := 0; cnt int; raw numeric; lit_n int; nm text; c int; s int; solo boolean; fades jsonb := '{}'; k text; v int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
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
      perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — ' || case when exists (select 1 from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) e where e ->> 'k' in ('arrow', 'big') and (e ->> 'c')::int = c)
        then c || '번 칸 화살은 아직 허공에 단단히 멈춰 있어 손에 잡히지 않습니다(떨어지는 라운드에만).' else c || '번 칸에는 걷어 낼 화살이 없습니다.' end); continue;
    end if;
    select string_agg(case when e ->> 'k' = 'big' then '굵은 화살' else '화살' end, '·') into nm from jsonb_array_elements(b -> 'hz') e
     where e ->> 'k' in ('arrow', 'big') and (e ->> 'c')::int = c and (e ->> 'left')::int <= 0 and not coalesce((e ->> 'frozen')::boolean, false);
    b := b || jsonb_build_object('hz', (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(b -> 'hz') e
      where not (e ->> 'k' in ('arrow', 'big') and (e ->> 'c')::int = c and (e ->> 'left')::int <= 0 and not coalesce((e ->> 'frozen')::boolean, false))));
    perform public.world_gw_say(p_fight, p_round, 'good', w.name || ' — ' || c || '번 칸으로 떨어지던 ' || nm || '을(를) 손으로 걷어 냈습니다.');
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
        perform public.world_gw_say(p_fight, p_round, 'miss', c || '번 등은 켜져 있습니다' || case when exists (select 1 from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) e where e ->> 'k' = 'gust' and (e ->> 's')::int = c)
          then ' — 아직 꺼질 때가 아니라 감싸 줄 것이 없습니다(흔들림이 다하는 라운드에만).' else '.' end);
      end if;
      continue;
    end if;
    lamps := lamps || c;
    perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — ' || c || '번 등롱에 손을 얹자 등이 켜집니다. 그 둘레로 저녁 빛깔이 돌아옵니다.');
    if wn is not null then
      lit_n := (wn ->> 'lit')::int + 1;
      wn := wn || jsonb_build_object('lit', lit_n);
      perform public.world_gw_say(p_fight, p_round, 'voice', coalesce(rb -> 'voices' ->> (lit_n - 1), '누군가 부른다.'));
      if lit_n >= (wn ->> 'need')::int then
        extra := f.hp;
        perform public.world_gw_say(p_fight, p_round, 'good', '등이 모두 켜졌습니다. 하얀 몸에서 이름이 우수수 떨어집니다.');
      else
        extra := extra + round((wn ->> 'hp')::numeric / (wn ->> 'need')::int);
        perform public.world_gw_say(p_fight, p_round, 'good', '하얀 몸에서 이름 하나가 떨어져 금빛 가루로 흩어집니다.');
      end if;
    end if;
  end loop;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    if (h ->> 'left')::int > 0 or coalesce((h ->> 'frozen')::boolean, false) then keep := keep || jsonb_build_array(h); continue; end if;
    cells := public.world_by_hz_cells(p_fight, h);
    if h ->> 'k' = 'arrow' then
      if exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells)) then fails := fails + 1; end if;
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
        perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'arrow' ->> 'raw')::numeric, p_round, '떨어진 화살에', true);
        b := public.world_by_fade(p_fight, b, x.owner_id, coalesce((rb -> 'arrow' ->> 'fade')::int, 0), p_round);
      end loop;
    elsif h ->> 'k' = 'big' then
      perform public.world_gw_say(p_fight, p_round, 'boss', '아무도 걷어 내지 않은 굵은 화살이 ' || (h ->> 'c') || '번 칸 둘레를 꿰뚫습니다!');
      fails := fails + 1;
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
        perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'big' ->> 'raw')::numeric, p_round, '굵은 화살에', false);
        b := public.world_by_fade(p_fight, b, x.owner_id, coalesce((rb -> 'big' ->> 'fade')::int, 1), p_round);
      end loop;
      if wn is null and public.world_by_sector((h ->> 'c')::int) = any (lamps) then
        lamps := array_remove(lamps, public.world_by_sector((h ->> 'c')::int));
        perform public.world_gw_say(p_fight, p_round, 'bad', public.world_by_sector((h ->> 'c')::int) || '번 등이 화살에 꿰여 꺼졌습니다.');
      end if;
    elsif h ->> 'k' = 'gust' then
      if (h ->> 's')::int = any (saved) then continue; end if;
      lamps := array_remove(lamps, (h ->> 's')::int);
      perform public.world_gw_say(p_fight, p_round, 'bad', (h ->> 's') || '번 등이 꺼지며 마당 전체에 흰 바람이 휘몰아칩니다!');
      fails := fails + 1;
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
        perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'gust' ->> 'raw')::numeric, p_round, '흰 바람에', true);
      end loop;
    elsif h ->> 'k' = 'brush' then
      perform public.world_gw_say(p_fight, p_round, 'boss', '붉은 붓이 마당 한쪽을 쓸고 지나갑니다!');
      if exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells)) then fails := fails + 1; end if;
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
        perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'brush' ->> 'raw')::numeric, p_round, '붉은 붓에', true);
      end loop;
    elsif h ->> 'k' = 'stack' then
      select count(*) into cnt from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells);
      raw := (rb -> 'drop' ->> 'stack_raw')::numeric * case when solo then (rb -> 'drop' ->> 'solo_mul')::numeric else 1 end;
      select name into nm from public.world_gw_members where fight_id = p_fight and owner_id = (h ->> 't')::uuid;
      if cnt < 2 and not solo then fails := fails + 1; end if;
      perform public.world_gw_say(p_fight, p_round, case when cnt >= 2 or solo then 'good' else 'bad' end, '물방울이 ' || coalesce(nm, '') || ' 위에서 터집니다 — ' || cnt || '명이 나눠 받습니다.');
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
        perform public.world_by_dmg(p_fight, x.owner_id, raw / greatest(1, cnt), p_round, '나눠 받은 물방울에', true);
      end loop;
    elsif h ->> 'k' in ('spread', 'num') then
      raw := case when h ->> 'k' = 'spread' then (rb -> 'drop' ->> 'spread_raw')::numeric else (rb -> 'num' ->> 'raw')::numeric end;
      select name into nm from public.world_gw_members where fight_id = p_fight and owner_id = (h ->> 't')::uuid;
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (cells) loop
        perform public.world_by_dmg(p_fight, x.owner_id, raw, p_round, case when h ->> 'k' = 'num' then (h ->> 'i') || '번 화살에' else '흰 가루에' end, x.owner_id::text = h ->> 't');
        if x.owner_id::text <> h ->> 't' then
          b := public.world_by_fade(p_fight, b, x.owner_id, coalesce((rb -> 'num' ->> 'fade')::int, 1), p_round);
          perform public.world_gw_say(p_fight, p_round, 'bad', x.name || ' — ' || coalesce(nm, '') || ' 곁에 있다가 함께 바랬습니다.');
          fails := fails + 1;
        end if;
      end loop;
    elsif h ->> 'k' = 'tower' then
      select count(*) into cnt from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = (h ->> 'c')::int;
      if cnt >= (h ->> 'need')::int then
        perform public.world_gw_say(p_fight, p_round, 'good', (h ->> 'c') || '번 기둥을 ' || cnt || '명이 받아 냈습니다.');
      else
        perform public.world_gw_say(p_fight, p_round, 'bad', (h ->> 'c') || '번 기둥에 선 사람이 모자랍니다(' || cnt || '/' || (h ->> 'need') || '). 하얀 기둥이 무너지며 등을 덮습니다.');
        fails := fails + 1;
        lamps := array_remove(lamps, (h ->> 'c')::int);
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
          perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'tower' ->> 'raw')::numeric, p_round, '무너진 기둥에', true);
        end loop;
      end if;
    elsif h ->> 'k' = 'clock' then
      select * into x from public.world_gw_members y where y.fight_id = p_fight and y.owner_id = (h ->> 't')::uuid;
      if x.owner_id is not null and x.out_rounds = 0 and x.act ? 'm' then
        b := public.world_by_fade(p_fight, b, x.owner_id, coalesce((rb -> 'fade' ->> 'stun')::int, 3), p_round);
        perform public.world_gw_say(p_fight, p_round, 'bad', x.name || ' — 모래시계가 멈춘 순간 움직였습니다.');
        fails := fails + 1;
      elsif x.owner_id is not null then
        perform public.world_gw_say(p_fight, p_round, 'good', x.name || ' — 숨을 죽이고 그 자리를 지켰습니다. 모래시계가 깨집니다.');
      end if;
    elsif h ->> 'k' = 'sdrop' then
      select string_agg(y.name, '·') into nm from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = (h ->> 'c')::int
        and coalesce(y.act ->> 'a', 'guard') in ('guard', 'brace');
      if nm is not null then
        perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — ' || (h ->> 'c') || '번 칸에서 물방울을 막아 깨뜨렸습니다.');
      else
        perform public.world_gw_say(p_fight, p_round, 'bad', '아무도 막지 않아 물방울이 마당에 흩어집니다.');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
          perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'sdrop' ->> 'raw')::numeric, p_round, '흩어진 물방울에', true);
        end loop;
      end if;
    elsif h ->> 'k' = 'flick' then
      if exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = (h ->> 's')::int) then
        perform public.world_gw_say(p_fight, p_round, 'good', (h ->> 's') || '번 등 곁을 지켜 등이 꺼지지 않았습니다.');
      else
        lamps := array_remove(lamps, (h ->> 's')::int);
        perform public.world_gw_say(p_fight, p_round, 'bad', (h ->> 's') || '번 등이 꺼졌습니다. 그 칸에서 「등 켜기」로 다시 켤 수 있습니다.');
      end if;
    end if;
  end loop;
  if fails > 0 and jsonb_typeof(rb -> 'fail_party') = 'object' then
    perform public.world_gw_say(p_fight, p_round, 'bad', '한 사람이 발을 헛디딘 틈으로 흰 빛이 파고들어 모두가 함께 바랩니다' || case when fails > 1 then '(' || fails || '번)' else '' end || '.');
    for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
      perform public.world_by_dmg(p_fight, x.owner_id, (rb -> 'fail_party' ->> 'raw')::numeric * fails, p_round, '함께 번진 흰 빛에', false);
      b := public.world_by_fade(p_fight, b, x.owner_id, (rb -> 'fail_party' ->> 'fade')::int * fails, p_round);
    end loop;
  end if;
  b := b || jsonb_build_object('hz', keep, 'lamps', to_jsonb(coalesce(lamps, '{}'::int[])));
  if wn is not null then b := b || jsonb_build_object('wn', wn); end if;
  update public.world_gw_fights set board = b where fight_id = p_fight;
  return extra;
end $f$;

create or replace function public.world_by_after(p_fight uuid, p_round integer)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; nh int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return true; end if;
  if f.board -> 'wn' ->> 'at' is not null and p_round >= (f.board -> 'wn' ->> 'at')::int and f.hp > 0
     and coalesce((f.board -> 'wn' ->> 'lit')::int, 0) < coalesce((f.board -> 'wn' ->> 'need')::int, 7) then
    if coalesce((rb -> 'wn' ->> 'wipe')::boolean, false) and f.mode = 'ultimate' then
      perform public.world_ug_wipe(p_fight, p_round, '이야기꾼의 말로는 흰 밤이 끝내 걷히지 않았다고 한다 — 등을 다 켜지 못했다.');
      return true;
    end if;
    if coalesce((f.board ->> 'wn_fail')::int, 0) >= (rb -> 'wn' ->> 'fails')::int then
      perform public.world_gw_say(p_fight, p_round, 'bad', '흰 밤이 다시 걷히지 않았습니다. 마당이 하얗게 바랜 채 굳어 갑니다.');
      perform public.world_gw_settle(p_fight, false);
      return true;
    end if;
    nh := round(f.max_hp * (rb -> 'wn' ->> 'fail_hp')::numeric / 100.0);
    update public.world_gw_fights set hp = greatest(hp, nh), enrage = enrage + 1, updated_at = now(),
      board = (board - 'wn') || jsonb_build_object('wn_fail', coalesce((board ->> 'wn_fail')::int, 0) + 1, 'lamps', '[1, 2, 3, 4, 5, 6, 7]'::jsonb, 'hz', '[]'::jsonb) where fight_id = p_fight;
    perform public.world_gw_say(p_fight, p_round, 'bad', '흰 밤 안에 등을 다 켜지 못했습니다. 떨어졌던 이름들이 하얀 몸으로 되돌아 붙고, 마당이 한 단계 앞으로 되감깁니다 — 한 번 더 밀려나면 끝입니다.');
  end if;
  return false;
end $f$;

create or replace function public.world_by_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb := br -> 'board'; f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; b jsonb; L int; cur jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  b := coalesce(f.board, '{}'::jsonb); L := public.world_by_lamps(b);
  cur := public.world_by_seq(p_fight, f.hp, f.max_hp);
  return jsonb_build_object(
    'phase_name', br -> 'phases' ->> (f.phase - 1), 'phases', br -> 'phases',
    'mechs', cur -> 'm', 'mech_names', br -> 'mech_names',
    'lamps', coalesce(b -> 'lamps', '[]'::jsonb), 'lit', L,
    'dmg_mul', round((rb ->> 'dmg_lo')::numeric + (rb ->> 'dmg_k')::numeric * L / 7.0, 3),
    'hurt_mul', round((rb ->> 'hurt_hi')::numeric - (rb ->> 'hurt_k')::numeric * L / 7.0, 3),
    'my_pos', me.pos,
    'moves', case when me.pos is not null and f.status = 'fight' then to_jsonb(public.world_by_nb(me.pos)) else '[]'::jsonb end,
    'hz', (select coalesce(jsonb_agg(e || jsonb_build_object('cells', to_jsonb(public.world_by_hz_cells(p_fight, e)))), '[]'::jsonb) from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) e),
    'fade', coalesce(b -> 'fade', '{}'::jsonb), 'fade_stun', rb -> 'fade' -> 'stun',
    'stunned', coalesce((b -> 'stun' ->> p_uid::text)::int = f.round, false),
    'sweep_fade', coalesce((rb ->> 'sweep_fade')::int, 0),
    'wn', case when b ? 'wn' then (b -> 'wn') || jsonb_build_object('left', case when b -> 'wn' ->> 'at' is not null then (b -> 'wn' ->> 'at')::int - f.round end) end,
    'wn_fail', coalesce((b ->> 'wn_fail')::int, 0), 'wn_fails', (rb -> 'wn' ->> 'fails')::int);
end $f$;

create or replace function public.world_by_settle(p_fight uuid, p_won boolean)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_boss_fight_rules(p_fight); f public.world_gw_fights%rowtype; m record; today date := (now() at time zone 'Asia/Seoul')::date;
  rec public.world_gw_records%rowtype; n int; solo boolean; flawless boolean; is_first boolean; xp int; msg text; lv int; v_gil int; gone int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status not in ('fight', 'wait') then return; end if;
  update public.world_gw_fights set status = case when p_won then 'won' else 'failed' end, ended_at = now(), updated_at = now(), hp = case when p_won then 0 else hp end where fight_id = p_fight;
  select count(*), coalesce(sum(falls), 0) = 0, count(*) filter (where fx ? 'gone') into n, flawless, gone from public.world_gw_members where fight_id = p_fight;
  solo := n = 1;
  if f.mode = 'story' then
    for m in select * from public.world_gw_members where fight_id = p_fight loop
      update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
      if p_won then
        insert into public.world_gw_records(owner_id, boss_id) values (m.owner_id, 'baekya_story') on conflict do nothing;
        select * into rec from public.world_gw_records where owner_id = m.owner_id and boss_id = 'baekya_story' for update;
        is_first := coalesce(rec.kills, 0) = 0;
        update public.world_gw_records set kills = kills + 1, last_kill_day = today, first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id and boss_id = 'baekya_story';
        v_gil := 0;
        if is_first then
          v_gil := (r -> 'first' ->> 'gil')::int;
          update public.world_characters set gil = gil + v_gil, updated_at = now() where owner_id = m.owner_id;
        end if;
        insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '흰 밤을 걷어 냈습니다',
          case when is_first then '맹약 마당에서 백야를 이겼습니다. ' || to_char(v_gil, 'FM999,999') || '전을 받았습니다. 이야기를 이어 가세요.'
            else '맹약 마당에서 다시 한 번 백야를 이겼습니다.' end,
          jsonb_build_object('fight_id', p_fight, 'boss', 'baekya', 'mode', 'story', 'first', is_first));
      else
        insert into public.world_notifications(user_id, kind, title, content, payload)
        values (m.owner_id, 'gw', '백야 앞에서 밀려났습니다', '이야기판은 밀려나도 잃는 것이 없습니다. 숨을 고르고 다시 서세요.', jsonb_build_object('fight_id', p_fight, 'boss', 'baekya', 'mode', 'story'));
      end if;
    end loop;
  else
    for m in select * from public.world_gw_members where fight_id = p_fight loop
      if p_won then
        update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
        insert into public.world_gw_records(owner_id, boss_id) values (m.owner_id, 'baekya') on conflict do nothing;
        select * into rec from public.world_gw_records where owner_id = m.owner_id and boss_id = 'baekya' for update;
        if rec.last_kill_day is distinct from today then
          is_first := coalesce(rec.kills, 0) = 0;
          update public.world_gw_records set kills = kills + 1, last_kill_day = today, first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id and boss_id = 'baekya';
          select level into lv from public.world_characters where owner_id = m.owner_id;
          xp := case when lv >= (r ->> 'xp_cap_lv')::int then 0
            else round(public.world_xp_need(lv) * case when is_first then (r -> 'first' ->> 'xp')::numeric else (r -> 'again' ->> 'xp')::numeric end) end;
          v_gil := case when is_first then (r -> 'first' ->> 'gil')::int else (r -> 'again' ->> 'gil')::int end;
          update public.world_characters set gil = gil + v_gil, updated_at = now() where owner_id = m.owner_id;
          if xp > 0 then xp := coalesce((public.world_grant_xp_got(m.owner_id, xp) ->> 'xp')::int, 0); end if;
          if is_first then
            insert into public.world_owned_mounts(owner_id, mount_id) values (m.owner_id, r -> 'first' ->> 'mount') on conflict do nothing;
            insert into public.world_faction_unlocks(owner_id, unlock_key) values (m.owner_id, r -> 'first' ->> 'name_style') on conflict do nothing;
          end if;
          msg := case when is_first then '백야를 처음으로 이겼습니다. ' || to_char(v_gil, 'FM999,999') || '전' || case when xp > 0 then ' · 경험치 ' || xp else '' end || ' · 탈것 「' || (r -> 'first' ->> 'mount_name') || '」 · 이름 색 「' || (r -> 'first' ->> 'name_style_name') || '」을(를) 받았습니다.'
            else '백야를 이겼습니다(' || (coalesce(rec.kills, 0) + 1) || '번째). ' || v_gil || '전' || case when xp > 0 then ' · 경험치 ' || xp else '' end || '.' end;
          insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '백야를 이김', msg, jsonb_build_object('fight_id', p_fight, 'first', is_first, 'boss', 'baekya'));
          insert into public.world_events(actor_id, actor_name, event_type, content, payload)
          values (m.owner_id, m.name, 'by_win', m.name || '이(가) 맹약 마당에서 흰 밤을 걷어 냈습니다.',
                  jsonb_build_object('fight_id', p_fight, 'boss', 'baekya', 'first', is_first, 'solo', solo, 'flawless', flawless and n >= 2 and gone = 0,
                    'members', n, 'kills', coalesce(rec.kills, 0) + 1, 'gone', gone, 'wn_fail', coalesce((f.board ->> 'wn_fail')::int, 0)));
        else
          insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '백야를 이김', '오늘은 이미 처치를 인정받아 보상은 없습니다.', jsonb_build_object('fight_id', p_fight, 'boss', 'baekya'));
        end if;
      else
        update public.world_item_durability d set durability = greatest(0, d.durability - ceil(public.world_item_max_durability(d.item_id) * (r -> 'fail' ->> 'dur')::numeric / 100.0)::int), updated_at = now()
          from public.world_character_equipment e where e.owner_id = m.owner_id and d.owner_id = m.owner_id and d.item_id = e.item_id;
        perform public.world_yohwa_overflow(m.owner_id, (select erosion from public.world_characters where owner_id = m.owner_id) + (r -> 'fail' ->> 'er')::int - 100);
        update public.world_characters set health = greatest(1, m.hp), erosion = least(100, erosion + (r -> 'fail' ->> 'er')::int),
               erosion_stage = case when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 80 then 4 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 55 then 3
                 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 30 then 2 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 10 then 1 else 0 end,
               updated_at = now() where owner_id = m.owner_id;
        insert into public.world_gw_records(owner_id, boss_id, last_fail_at) values (m.owner_id, 'baekya', now()) on conflict (owner_id, boss_id) do update set last_fail_at = now();
        insert into public.world_notifications(user_id, kind, title, content, payload)
        values (m.owner_id, 'gw', '백야 도전 실패', '흰 밤에 밀려났습니다. 장착한 장비 내구도가 ' || (r -> 'fail' ->> 'dur') || '% 닳고 침식이 ' || (r -> 'fail' ->> 'er') || ' 올랐습니다. '
          || (r -> 'fail' ->> 'cd') || '분 뒤 다시 도전할 수 있습니다.', jsonb_build_object('fight_id', p_fight, 'boss', 'baekya'));
      end if;
    end loop;
  end if;
  perform public.world_gw_say(p_fight, f.round, case when p_won then 'win' else 'bad' end, case when p_won
    then '일곱 등이 다 켜지자 하얀 몸에서 이름이 우수수 떨어진다. 솔내의 이름 몇 줄과, 그 맨 위의 한 이름만 남았다. 「이것만은 못 내주오.」 — 이제 누군가 그의 이름을 불러야 한다.'
    else '도전이 끝났습니다.' end);
end $f$;

revoke all on function public.world_by_nb(integer), public.world_by_lamps(jsonb), public.world_by_hurt_mul(uuid, uuid), public.world_by_on_attack(uuid, uuid, integer),
  public.world_by_sector(integer), public.world_by_area(integer), public.world_by_sweep_cells(integer, integer), public.world_by_hz_cells(uuid, jsonb),
  public.world_by_fade(uuid, jsonb, uuid, integer, integer), public.world_by_seq(uuid, integer, integer), public.world_by_dmg(uuid, uuid, numeric, integer, text, boolean),
  public.world_by_begin(uuid, integer), public.world_by_round(uuid), public.world_by_steps(uuid, integer), public.world_by_mech(uuid, integer, boolean, boolean, uuid[]),
  public.world_by_after(uuid, integer), public.world_by_view(uuid, uuid), public.world_by_settle(uuid, boolean) from public, anon, authenticated;
grant execute on function public.world_by_nb(integer), public.world_by_lamps(jsonb), public.world_by_hurt_mul(uuid, uuid), public.world_by_on_attack(uuid, uuid, integer),
  public.world_by_sector(integer), public.world_by_area(integer), public.world_by_sweep_cells(integer, integer), public.world_by_hz_cells(uuid, jsonb),
  public.world_by_fade(uuid, jsonb, uuid, integer, integer), public.world_by_seq(uuid, integer, integer), public.world_by_dmg(uuid, uuid, numeric, integer, text, boolean),
  public.world_by_begin(uuid, integer), public.world_by_round(uuid), public.world_by_steps(uuid, integer), public.world_by_mech(uuid, integer, boolean, boolean, uuid[]),
  public.world_by_after(uuid, integer), public.world_by_view(uuid, uuid), public.world_by_settle(uuid, boolean) to service_role, fn_owner_field;

select pg_temp.yh_patch('public.world_gw_next_round(uuid)',
  $o$  if f.boss_id = 'gapgwi' then perform public.world_gg_round(p_fight); return; end if;$o$,
  $n$  if f.boss_id = 'baekya' then perform public.world_by_round(p_fight); return; end if;
  if f.boss_id = 'gapgwi' then perform public.world_gg_round(p_fight); return; end if;$n$);

select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$  v_item := case when f.boss_id in ('mukjeok', 'gapgwi') then public.world_boss_rules() -> f.boss_id ->> 'item' else 'gwiheo_charm' end;$o$,
  $n$  v_item := case when f.boss_id in ('mukjeok', 'gapgwi') then public.world_boss_rules() -> f.boss_id ->> 'item' else 'gwiheo_charm' end;
  if f.boss_id = 'baekya' then v_item := public.world_boss_rules() -> 'baekya' ->> 'item'; end if;$n$);
select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$  if f.boss_id = 'gapgwi' then
    br := public.world_boss_fight_rules(p_fight);$o$,
  $n$  if f.boss_id = 'baekya' then
    br := public.world_boss_fight_rules(p_fight);
    update public.world_gw_fights set status = 'fight',
           max_hp = round(greatest((br ->> 'hp_min')::numeric, sa * (br ->> 'hp_atk')::numeric) * (br -> 'hp_n' ->> (least(4, n) - 1))::numeric),
           hp = round(greatest((br ->> 'hp_min')::numeric, sa * (br ->> 'hp_atk')::numeric) * (br -> 'hp_n' ->> (least(4, n) - 1))::numeric), phase = 1, round = 0, cycle = 0,
           ends_at = now() + make_interval(mins => (br ->> 'min')::int), updated_at = now() where fight_id = p_fight;
    if n = 1 and f.mode <> 'story' then update public.world_gw_members m set stats = m.stats || public.world_solo_aid(m.job_key, 'baekya') where fight_id = p_fight; end if;
    perform public.world_by_begin(p_fight, n);
    perform public.world_gw_next_round(p_fight);
    return;
  end if;
  if f.boss_id = 'gapgwi' then
    br := public.world_boss_fight_rules(p_fight);$n$);

select pg_temp.yh_patch('public.world_gw_settle(uuid,boolean)',
  $o$  if f.boss_id = 'gapgwi' then perform public.world_gg_settle(p_fight, p_won); return; end if;$o$,
  $n$  if f.boss_id = 'baekya' then perform public.world_by_settle(p_fight, p_won); return; end if;
  if f.boss_id = 'gapgwi' then perform public.world_gg_settle(p_fight, p_won); return; end if;$n$);

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$when f.boss_id = 'gapgwi' then '값귀' else '주인' end;$o$,
  $n$when f.boss_id = 'gapgwi' then '값귀' else '주인' end;
  if f.boss_id = 'baekya' then v_who := '백야'; end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'mukjeok' then perform public.world_mk_steps(p_fight, r); end if;$o$,
  $n$  if f.boss_id = 'mukjeok' then perform public.world_mk_steps(p_fight, r); end if;
  if f.boss_id = 'baekya' then perform public.world_by_steps(p_fight, r); end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$      physical := coalesce(m.stats ->> 'style', 'melee') in ('melee', 'ranged');$o$,
  $n$      if f.boss_id = 'baekya' then d := d * public.world_by_on_attack(p_fight, m.owner_id, r); end if;
      physical := coalesce(m.stats ->> 'style', 'melee') in ('melee', 'ranged');$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$    elsif av = 'call' and (f.boss_id in ('mukjeok', 'gapgwi') or f.mode = 'story') then$o$,
  $n$    elsif av in ('call', 'move', 'light', 'sweep') and f.boss_id = 'baekya' then
      null;
    elsif av = 'call' and (f.boss_id in ('mukjeok', 'gapgwi') or f.mode = 'story') then$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'gapgwi' then boss_dmg := boss_dmg + public.world_gg_mech(p_fight, r, broke, delayed, freed);$o$,
  $n$  if f.boss_id = 'baekya' then boss_dmg := boss_dmg + public.world_by_mech(p_fight, r, broke, delayed, freed); end if;
  if f.boss_id = 'baekya' then null;
  elsif f.boss_id = 'gapgwi' then boss_dmg := boss_dmg + public.world_gg_mech(p_fight, r, broke, delayed, freed);$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id in ('mukjeok', 'gapgwi') then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;$o$,
  $n$  if f.boss_id = 'baekya' then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if public.world_by_after(p_fight, r) then return; end if;
    select * into f from public.world_gw_fights where fight_id = p_fight;
  end if;
  if f.boss_id in ('mukjeok', 'gapgwi') then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$    if aoe then
      perform public.world_gw_say(p_fight, r, 'boss', case when f.boss_id = 'gapgwi'$o$,
  $n$    if f.boss_id = 'baekya' then raw := public.world_mk_raw(p_fight); end if;
    if aoe then
      perform public.world_gw_say(p_fight, r, 'boss', case when f.boss_id = 'gapgwi'$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$        when f.boss_id = 'mukjeok' then '먹구름이 터집니다.$o$,
  $n$        when f.boss_id = 'baekya' then '흰 소매가 마당을 한꺼번에 휩씁니다! 닿은 자리마다 색이 하얗게 바랩니다.' || case when broke then ' (퇴마 결계가 소매를 절반으로 꺾었습니다)' else '' end
        when f.boss_id = 'mukjeok' then '먹구름이 터집니다.$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$when f.boss_id = 'gapgwi' then '휘몰아치는 낱장에'$o$,
  $n$when f.boss_id = 'baekya' then '휩쓰는 흰 소매에' when f.boss_id = 'gapgwi' then '휘몰아치는 낱장에'$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$when f.boss_id = 'gapgwi' then '모두가 물러났습니다.$o$,
  $n$when f.boss_id = 'baekya' then '모두가 물러났습니다. 마당이 흰 밤에 잠깁니다.' when f.boss_id = 'gapgwi' then '모두가 물러났습니다.$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$when f.boss_id = 'gapgwi' then '시간이 다 되었습니다.$o$,
  $n$when f.boss_id = 'baekya' then '시간이 다 되었습니다. 동이 트지 않은 채 마당이 하얗게 굳습니다.' when f.boss_id = 'gapgwi' then '시간이 다 되었습니다.$n$);

select pg_temp.yh_patch('public.world_gw_hit(uuid,uuid,numeric,integer,text,boolean)',
  $o$  av := coalesce(m.act ->> 'a', 'guard');$o$,
  $n$  av := coalesce(m.act ->> 'a', 'guard');
  if exists (select 1 from public.world_gw_fights x where x.fight_id = p_fight and x.boss_id = 'baekya') then p_raw := p_raw * public.world_by_hurt_mul(p_fight, p_uid); end if;$n$);

select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$'recall', 'deal') then raise exception$o$,
  $n$'recall', 'deal', 'move', 'light', 'sweep') then raise exception$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$when p_action = 'chain' then jsonb_build_object('c', coalesce(p_item, ''))$o$,
  $n$when p_action in ('chain', 'sweep') then jsonb_build_object('c', coalesce(p_item, ''))$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if not mk and (p_action = 'recall' or p_move is not null) then$o$,
  $n$  if (f.boss_id <> 'baekya' and p_action in ('light', 'sweep')) or (f.boss_id not in ('baekya', 'gapgwi') and p_action = 'move') then raise exception '알 수 없는 행동입니다.'; end if;
  if f.boss_id = 'baekya' then
    if p_action in ('chain', 'recall', 'deal', 'call') then raise exception '알 수 없는 행동입니다.'; end if;
    if coalesce((f.board -> 'stun' ->> uid::text)::int = f.round, false) then raise exception '온몸이 하얗게 바래 이번 라운드에는 꼼짝도 할 수 없습니다.'; end if;
    if p_move is not null and p_move = me.pos then p_move := null; end if;
    if p_move is not null and not (p_move::int = any (public.world_by_nb(me.pos))) then raise exception '바로 옆 칸으로만 옮겨 설 수 있습니다.'; end if;
    if p_action = 'move' and p_move is null then raise exception '옮겨 설 칸을 고르세요.'; end if;
    if p_action = 'attack' and f.board ? 'wn' then raise exception '%', case when f.mode = 'story' then '흰 밤에는 칼끝이 닿지 않습니다. 등 기둥 칸에서 등을 켜세요.' else '흰 밤에는 칼끝이 닿지 않습니다.' end; end if;
    if p_action = 'coop' and f.board ? 'wn' and coalesce((select (s.effect ->> 'strike')::boolean from public.world_coop_skills s where s.skill_id = p_item), false) then
      raise exception '%', case when f.mode = 'story' then '흰 밤에는 칼끝이 닿지 않습니다. 등 기둥 칸에서 등을 켜세요.' else '흰 밤에는 칼끝이 닿지 않습니다.' end; end if;
    if p_action = 'sweep' and (p_item is null or p_item !~ '^[0-9]+$') then raise exception '걷어 낼 칸을 고르세요.'; end if;
  end if;
  if not mk and f.boss_id not in ('baekya', 'gapgwi') and (p_action = 'recall' or p_move is not null) then$n$);

select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'board', case when f.boss_id = 'gapgwi' then$o$,
  $n$'board', case when f.boss_id = 'baekya' then public.world_by_view(fid, uid) when f.boss_id = 'gapgwi' then$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'pos', m.pos, 'val', m.gval,$o$,
  $n$'pos', m.pos, 'fade', case when f.boss_id = 'baekya' then coalesce((f.board -> 'fade' ->> m.owner_id::text)::int, 0) end, 'val', m.gval,$n$);

select pg_temp.yh_patch('public.world_gw_open(text,text)',
  $o$    if boss = 'gapgwi' then$o$,
  $n$    if boss = 'baekya' then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (x.owner_id, 'gw_invite', '백야 · 함께 싸우기', c.character_name || '이(가) 맹약 마당에서 백야 앞에 섰습니다. 60초 안에 합류하세요' || case when md = 'story' then '.' else '(' || (br ->> 'item_name') || ' 1개).' end,
        jsonb_build_object('fight_id', fid, 'boss', boss, 'mode', md));
    elsif boss = 'gapgwi' then$n$);

select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$  if p_boss in ('mukjeok', 'gapgwi') then$o$,
  $n$  if p_boss in ('mukjeok', 'gapgwi', 'baekya') then$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$raise exception '%', case when p_boss = 'gapgwi' then$o$,
  $n$raise exception '%', case when p_boss in ('gapgwi', 'baekya') then$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$when p_boss = 'gapgwi' then '값귀를 쓰러뜨렸습니다'$o$,
  $n$when p_boss = 'baekya' then '흰 밤을 걷어 냈습니다' when p_boss = 'gapgwi' then '값귀를 쓰러뜨렸습니다'$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$when p_boss = 'gapgwi' then '값귀의 장부가 아직 젖어 있습니다'$o$,
  $n$when p_boss = 'baekya' then '맹약 마당이 아직 하얗게 바래 있습니다' when p_boss = 'gapgwi' then '값귀의 장부가 아직 젖어 있습니다'$n$);

select pg_temp.yh_patch('public.world_gw_tips(text)',
  $o$select case when p_boss = 'gapgwi' then jsonb_build_array($o$,
  $n$select case when p_boss = 'baekya' then jsonb_build_array(
    '맵: 맹약 마당은 바깥 고리 등 기둥 일곱 칸, 안쪽 마당 일곱 칸, 가운데 백야로 되어 있다. 한 라운드에 바로 옆 칸으로 한 칸 옮겨 선다. 켜진 등이 많을수록 우리 공격이 세지고 받는 피해가 줄어든다.',
    '멈춘 것: 백야의 공격은 허공에 멈춰 숫자를 센다. 0이 되는 라운드에 떨어진다. 등이 꺼진 쪽의 화살은 숫자가 줄지 않는다.',
    '화살비: 발밑 칸에 화살이 멈춘다 — 숫자가 다 되기 전에 비킨다. 「걷어 내기」로 제 칸이나 옆 칸 화살을 지울 수 있지만 손이 바랜다.',
    '붉은 붓: 마당 한쪽이 붉게 칠해진다 — 반대쪽으로 피한다.',
    '물방울·흰 가루: 물방울은 그 사람 둘레(제 칸과 옆 칸)에 모여 나눠 받고, 흰 가루 둘레는 비운다.',
    '등 기둥 탑: 하얀 기둥이 선 등 칸에 적힌 수만큼 서 있어야 한다. 모자라면 모두 다치고 그 등이 꺼진다. 꺼진 등은 그 칸에서 「등 켜기」.',
    '멈춤 시계: 모래시계가 0이 되는 라운드에 그 사람은 움직이면 안 된다(행동은 해도 됨).',
    '바램: 화살·가루에 닿으면 바램이 쌓여 받는 피해가 늘고, 세 겹이면 다음 라운드에 꼼짝 못 한다. 회복품이나 의무관의 협동 기술이 바램을 덜어 준다.',
    '흰 밤(체력 25% 아래): 등이 모두 꺼지고 공격이 닿지 않는다. 등 기둥 칸에서 「등 켜기」로 등을 켤 때마다 백야의 체력이 깎이고, 그 둘레에 멈춰 있던 화살이 떨어지기 시작한다. 정해진 라운드 안에 다 켜지 못하면 한 단계 앞으로 되감기고, 두 번째면 진다.')
  when p_boss = 'gapgwi' then jsonb_build_array($n$);

select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$tt not in ('gw', 'mj', 'gg', 'raid',$o$, $n$tt not in ('gw', 'mj', 'gg', 'by', 'raid',$n$);
select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$  if tt in ('gw', 'mj', 'gg') then$o$, $n$  if tt in ('gw', 'mj', 'gg', 'by') then$n$);
select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$when tt = 'gg' then 'gapgwi' else$o$, $n$when tt = 'gg' then 'gapgwi' when tt = 'by' then 'baekya' else$n$);

select pg_temp.yh_patch('public.world_quest_task_label(jsonb)',
  $o$    when p_task ->> 't' = 'gg' then$o$,
  $n$    when p_task ->> 't' = 'by' then case when p_task ->> 'mode' = 'story' then '맹약 마당에서 백야를 이기기' else '깊은 흰 밤에서 백야를 이기기' end
    when p_task ->> 't' = 'gg' then$n$);
