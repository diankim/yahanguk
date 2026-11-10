lock table public.world_characters in access exclusive mode;

alter table public.world_gw_fights add column if not exists boss_id text not null default 'gwiheo';
alter table public.world_gw_fights add column if not exists board jsonb not null default '{}'::jsonb;
alter table public.world_gw_members add column if not exists pos smallint;
alter table public.world_gw_members add column if not exists prev text;
alter table public.world_gw_records add column if not exists boss_id text not null default 'gwiheo';
alter table public.world_gw_records drop constraint if exists world_gw_records_pkey;
alter table public.world_gw_records add primary key (owner_id, boss_id);

create or replace function public.world_boss_rules()
 returns jsonb language sql immutable set search_path = ''
as $f$ select '{
  "gwiheo": {"name": "귀허의 주인", "fight": "귀허의 주인", "place": "귀허", "arc": "외전 · 요인록", "region": "gwiheo_core", "lv": 38,
    "quest": "gq_4", "quest_name": "외전 4장 「달 없는 장」", "item": "gwiheo_charm", "item_name": "귀허 부적", "shop_name": "반요촌 잡화",
    "min": 15, "hp_min": 6000, "hp_atk": 40, "hp_n": [1.2, 1.7, 0.8, 0.85], "raw_n": [1, 1.4, 0.8, 0.85], "raw": [35, 4], "enrage": 0.15,
    "first": {"gil": 1500, "xp": 0.5}, "again": {"gil": 120, "xp": 0.05}, "fail": {"dur": 10, "er": 10, "cd": 30}, "falls": 10},
  "mukjeok": {"name": "먹그림자", "fight": "아홉 칸 명부", "place": "아홉 칸 뜰", "arc": "외전 · 묵적록", "region": "nine_court", "lv": 44,
    "quest": "mkq_4", "quest_name": "외전 「묵적록」 4장 「명부 탑」", "item": "seal_inkline", "item_name": "봉인 먹줄", "shop": "mukchang_shop", "shop_name": "묵창 나루 주막",
    "min": 18, "hp_min": 7500, "hp_atk": 44, "hp_n": [0.8, 1.3, 0.8, 1.25], "raw_n": [1, 1.1, 0.8, 0.85], "raw": [38, 4], "enrage": 0.15,
    "first": {"gil": 2000, "xp": 0.5, "mount": "ink_crane", "mount_name": "먹 그림 학", "name_style": "ns:1032", "name_style_name": "묵적", "furniture": "mk_first"},
    "again": {"gil": 150, "xp": 0.05, "item": "meokgwi_lump", "item_name": "먹귀 응어리", "qty": 1},
    "fail": {"dur": 10, "er": 10, "cd": 30}, "falls": 10, "xp_cap_lv": 45,
    "board": {"strokes": 9, "lit_start": 7, "lit_base": 4, "lit_pct": 5, "lit_ward": 10, "center_pres": 60,
      "line_raw": 45, "keep_mul": 1.3, "line_strokes": 2, "line_every": [6, 6, 5, 6], "line_off": [2, 0, 0, 3], "line_n": [1, 1, 2, 1], "aoe_every": 4, "aoe_mul": 0.9,
      "mimic_atk": 0.7, "mimic_stuck": 0.5, "mimic_raw": 12, "hesit_pct": 15, "bound_raw": 10,
      "erase_every": 5, "erase_pct": 6, "erase_raw": 50, "erase_strokes": 4, "erase_sure_lit": 6, "recall_credit": 0.5, "low_pct": 10},
    "solo": {"artificer": {"solo_dmg": -40, "solo_guard": -40}, "scout": {"solo_dmg": -25, "solo_guard": 18}, "exorcist": {"solo_dmg": -41, "solo_guard": 4},
      "medic": {"solo_dmg": -12, "solo_guard": 10}, "sealmaster": {"solo_dmg": -42, "solo_guard": -2}, "analyst": {"solo_dmg": -25, "solo_guard": 2}}}
}'::jsonb $f$;

create or replace function public.world_solo_aid(p_job text, p_boss text)
 returns jsonb language sql immutable set search_path = ''
as $f$ select case when p_boss = 'mukjeok' then coalesce(public.world_boss_rules() -> 'mukjeok' -> 'solo' -> p_job, '{}'::jsonb) else public.world_solo_aid(p_job) end $f$;

create or replace function public.world_mk_lines()
 returns jsonb language sql immutable set search_path = ''
as $f$ select '{
  "lines": {"r0": [4, 9, 2], "r1": [3, 5, 7], "r2": [8, 1, 6], "c0": [4, 3, 8], "c1": [9, 5, 1], "c2": [2, 7, 6], "d0": [4, 5, 6], "d1": [2, 5, 8]},
  "names": {"r0": "맨 윗줄", "r1": "가운데 가로줄", "r2": "맨 아랫줄", "c0": "왼쪽 세로줄", "c1": "가운데 세로줄", "c2": "오른쪽 세로줄", "d0": "왼쪽 위 대각", "d1": "오른쪽 위 대각"},
  "tells": {"r0": "명부 맨 윗줄을 따라 눕는다", "r1": "명부 가운데 가로줄을 따라 눕는다", "r2": "명부 맨 아랫줄을 따라 눕는다",
    "c0": "명부 왼쪽 세로줄을 따라 곧게 선다", "c1": "명부 가운데 세로줄을 따라 곧게 선다", "c2": "명부 오른쪽 세로줄을 따라 곧게 선다",
    "d0": "왼쪽 위 모서리에서 오른쪽 아래로 기운다", "d1": "오른쪽 위 모서리에서 왼쪽 아래로 기운다"},
  "nb": {"1": [8, 5, 6], "2": [9, 7], "3": [4, 5, 8], "4": [9, 3], "5": [9, 3, 7, 1], "6": [7, 1], "7": [2, 5, 6], "8": [3, 1], "9": [4, 2, 5]},
  "outer": [1, 9, 3, 7, 8, 4, 2, 6], "grid": [4, 9, 2, 3, 5, 7, 8, 1, 6]
}'::jsonb $f$;

create or replace function public.world_mk_memories()
 returns jsonb language sql immutable set search_path = ''
as $f$ select '[["기억 조각 — 정청 대청. 젊은 조사원이 동료의 보고서를 고쳐 주고 있다.", "서율: 이름은 정확하게 적어. 돌아오지 못한 사람도, 누군가는 불러야 하니까."], ["기억 조각 — 낮은 담장 너머, 작은 아이가 까치발을 든다.", "서하: 오라버니.", "서율: 왜?", "그는 아이의 머리를 쓰다듬었다. 대답을 듣기도 전에 웃고 있었다."], ["기억 조각 — 붉은 끈이 매인 결정서. 「서하」가 적힌 칸. 서율의 손이 그것을 구겨 쥔다. 손등의 핏줄이 섰다."], ["기억 조각 — 벌판. 서율이 먹귀의 이름을 부른다. 먹귀가 흩어지고, 그의 손등에 먹 한 점이 남는다. 그는 그것을 오래 내려다본다. 털어 내지 않는다."], ["기억 조각 — 촛불 앞. 보고서 작성자 칸. 붓끝이 종이 위에 오래 머문다. 아무것도 적히지 않는다."], ["기억 조각 — 빈 방. 벽 앞에 앉은 등. 「서하」. 「서하」. 「서하」. 붓이 멈추지 않는다."]]'::jsonb $f$;

create or replace function public.world_mk_memory(p_fight uuid, p_round integer, p_force boolean default false)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare b jsonb; n int; t text;
begin
  select board into b from public.world_gw_fights where fight_id = p_fight for update;
  n := coalesce((b ->> 'mem')::int, 0);
  if n >= jsonb_array_length(public.world_mk_memories()) then return false; end if;
  if not p_force and coalesce((b ->> 'mem_r')::int, -1) = p_round then return false; end if;
  for t in select jsonb_array_elements_text(public.world_mk_memories() -> n) loop
    perform public.world_gw_say(p_fight, p_round, 'mem', t);
  end loop;
  update public.world_gw_fights set board = board || jsonb_build_object('mem', n + 1, 'mem_r', p_round) where fight_id = p_fight;
  return true;
end $f$;

create or replace function public.world_mk_begin(p_fight uuid, p_n integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_rules() -> 'mukjeok' -> 'board'; outer_ int[] := array[1, 9, 3, 7, 8, 4, 2, 6]; e int; lit int[]; x record; i int := 0;
begin
  e := outer_[1 + floor(random() * 8)::int];
  lit := array(select o from unnest(outer_) o where o <> e);
  for x in select owner_id from public.world_gw_members where fight_id = p_fight order by coalesce((stats ->> 'pres')::numeric, 30) desc, joined_at, owner_id loop
    update public.world_gw_members set pos = lit[1 + i % array_length(lit, 1)], prev = null where fight_id = p_fight and owner_id = x.owner_id;
    i := i + 1;
  end loop;
  update public.world_gw_fights set board = jsonb_build_object('strokes', (rb ->> 'strokes')::int, 'max', (rb ->> 'strokes')::int, 'lit', to_jsonb(lit), 'mem', 0, 'mem_r', -1,
    'lost', 0, 'delay', 0, 'late', false, 'mimic_last', null, 'low', false, 'ink', '{}'::jsonb) where fight_id = p_fight;
  perform public.world_gw_say(p_fight, 0, 'phase', '바닥이 아홉 칸으로 나뉜 명부가 펼쳐진다. 가운데 칸에 이름이 반쯤 지워진 채 적혀 있다. 명부 저편에서 먹그림자가 붓을 들자, 한 칸이 지워졌다. 「나는 칸을 지웠다. 나는 아프지 않았다.」');
  perform public.world_gw_say(p_fight, 0, 'phase', case when p_n = 1 then '봉인이 육신은 붙잡았다. 그러나 여기서 걸어 나가는 건, 나 혼자 해야 하는 일이었다.'
    else '매듭 안쪽으로 함께 걸어 들어온 이들이 있었다.' end);
end $f$;

create or replace function public.world_mk_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; rb jsonb := public.world_boss_rules() -> 'mukjeok' -> 'board'; lm jsonb := public.world_mk_lines(); b jsonb;
  nr int; ph int; m jsonb; len int := 5; tell text; aoe boolean := false; alive int; every int; off int; due boolean; nline int;
  ids text[] := array['r0', 'r1', 'r2', 'c0', 'c1', 'c2', 'd0', 'd1']; l1 text; l2 text; cells int[]; na int; ng int; mm text; stuck boolean := false; mem boolean := false;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; nr := f.round + 1;
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  if ph <> f.phase then
    perform public.world_gw_say(p_fight, nr, 'phase', case ph
      when 2 then '그림자가 붓을 고쳐 쥔다. 붓끝이 몸짓을 하나하나 베껴 쓰기 시작한다. 「네가 한 대로, 나도 한다.」'
      when 3 then '그림자가 따라 쓰기를 멈춘다. 대신 밟고 지나간 자리마다 먹이 고이기 시작한다.'
      else '그림자가 가운데 칸 위에 선다. 붓이 이름 쪽으로 기운다. 「이 칸만 지우면, 아무도 아프지 않다.」' end);
    f.cycle := 0;
    b := b || jsonb_build_object('mimic_last', null);
  end if;
  select count(*) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  select count(*) filter (where prev = 'attack'), count(*) filter (where prev = 'guard') into na, ng from (
    select case when x.act is null then 'guard' when x.act ->> 'a' = 'attack' then 'attack' when x.act ->> 'a' in ('guard', 'brace') then 'guard' else 'other' end prev
      from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest) z;
  update public.world_gw_members x set prev = case when x.out_rounds > 0 or x.rest then null when x.act is null then 'guard' when x.act ->> 'a' = 'attack' then 'attack'
    when x.act ->> 'a' in ('guard', 'brace') then 'guard' else 'other' end where x.fight_id = p_fight;
  every := (rb -> 'line_every' ->> (ph - 1))::int; off := (rb -> 'line_off' ->> (ph - 1))::int; nline := (rb -> 'line_n' ->> (ph - 1))::int;
  due := alive > 0 and (f.cycle % every = off or coalesce((b ->> 'late')::boolean, false));
  if ph = 4 and alive > 0 and f.cycle % (rb ->> 'erase_every')::int = 0 then
    m := jsonb_build_object('k', 'erase'); len := 10;
    tell := '그림자가 가운데 칸 위로 붓을 든다. 누군가 그 자리를 지키고, 누군가 그 이름을 불러 주어야 한다.';
  elsif due and coalesce((b ->> 'delay')::int, 0) > 0 then
    b := b || jsonb_build_object('delay', 0, 'late', true);
    m := jsonb_build_object('k', 'normal');
    tell := '그림자의 붓끝이 멈칫한다. 흐름이 끊긴 붓이 다음 획을 미룬다.';
  elsif due then
    l1 := ids[1 + floor(random() * 8)::int];
    if nline >= 2 then
      select l into l2 from unnest(ids) l where l <> l1 and (left(l, 1) <> left(l1, 1) or left(l1, 1) = 'd') order by random() limit 1;
    end if;
    cells := array(select distinct jsonb_array_elements_text(lm -> 'lines' -> l)::int from unnest(array_remove(array[l1, l2], null)) l order by 1);
    m := jsonb_build_object('k', 'line', 'lines', to_jsonb(array_remove(array[l1, l2], null)), 'cells', to_jsonb(cells), 'center', 5 = any (cells));
    len := 10; b := b || jsonb_build_object('late', false);
    tell := case when l2 is null then '그림자의 붓끝이 ' || (lm -> 'tells' ->> l1) || '. 먹이 그 줄로 흘러내릴 것만 같다.'
      else '그림자가 붓을 두 번 든다. 붓끝 하나는 ' || (lm -> 'tells' ->> l1) || '. 다른 하나는 ' || (lm -> 'tells' ->> l2) || '. 먹이 두 줄로 흘러내릴 것만 같다.' end
      || case when 5 = any (cells) then ' 가운데 칸의 이름이 그 길 위에서 떨린다. 누군가 그 자리를 지켜야 할 것 같다.' else '' end;
  else
    m := jsonb_build_object('k', 'normal');
    if ph = 2 then
      mm := case when na > ng then 'attack' when ng > na then 'guard' else 'hesit' end;
      stuck := mm in ('attack', 'guard') and b ->> 'mimic_last' = mm;
      b := b || jsonb_build_object('mimic_last', case when mm = 'hesit' then null else mm end);
      m := m || jsonb_build_object('mimic', mm, 'stuck', stuck);
      tell := case mm when 'attack' then '그림자가 방금 벤 자세를 그대로 짓는다. 붓끝이 칼처럼 선다.'
        when 'guard' then '그림자가 방금 막아 선 몸짓을 따라 웅크린다. 웅크린 것끼리 밀어붙이면, 누가 먼저 무너질까.'
        else '그림자가 누구를 따라 해야 할지 몰라 붓을 멈춘다.' end
        || case when stuck then ' 같은 몸짓을 두 번 베낀 붓이 멈추지 않는다.' else '' end;
      mem := stuck;
    elsif ph = 3 then
      m := m || jsonb_build_object('stamp', true);
      tell := '밟고 간 자리에 먹이 고인다. 같은 자리를 또 밟으면 발이 붙잡힐 것 같다.';
    else
      tell := '그림자가 붓에 먹을 다시 찍는다. 명부 위로 먹물이 번진다.';
    end if;
    aoe := nr % (rb ->> 'aoe_every')::int = 0;
  end if;
  if ph = 3 then
    b := b || jsonb_build_object('ink', (select coalesce(jsonb_object_agg(x.owner_id::text, x.pos), '{}'::jsonb) from public.world_gw_members x
      where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest and x.pos is not null and x.pos <> 5));
  else
    b := b || jsonb_build_object('ink', '{}'::jsonb);
  end if;
  if aoe then tell := tell || ' — 먹구름이 뜰 위로 낮게 내려앉는다. 먹비가 한꺼번에 쏟아질 것 같다. 몰려올 것에 대비하라.'; end if;
  m := m || jsonb_build_object('aoe', aoe, 'tell', tell);
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b, round_ends_at = now() + make_interval(secs => len), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, nr, case when aoe or m ->> 'k' in ('line', 'erase') then 'warn' else 'tell' end, tell);
  if mem then perform public.world_mk_memory(p_fight, nr); end if;
end $f$;

create or replace function public.world_mk_held(p_fight uuid, p_uid uuid)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
#variable_conflict use_column
begin
  return (select * from (select coalesce((select (f.board -> 'held' ->> p_uid::text)::int = f.round - 1 from public.world_gw_fights f where f.fight_id = p_fight), false)) yhq limit 1);
end $f$;

create or replace function public.world_mk_steps(p_fight uuid, p_round integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare x record; t int; lm jsonb := public.world_mk_lines();
begin
  for x in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ? 'm' order by joined_at, owner_id loop
    t := (x.act ->> 'm')::int;
    if public.world_mk_held(p_fight, x.owner_id) then
      perform public.world_gw_say(p_fight, p_round, 'miss', x.name || ' — 고인 먹에 발이 붙어 칸을 옮기지 못했습니다.');
    elsif x.pos is not null and (lm -> 'nb' -> x.pos::text) @> to_jsonb(t) then
      update public.world_gw_members set pos = t where fight_id = p_fight and owner_id = x.owner_id;
    end if;
  end loop;
end $f$;

create or replace function public.world_mk_raw(p_fight uuid)
 returns numeric language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_boss_rules() -> 'mukjeok'; f public.world_gw_fights%rowtype; n int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  return ((r -> 'raw' ->> 0)::numeric + (r -> 'raw' ->> 1)::numeric * f.phase) * (1 + (r ->> 'enrage')::numeric * f.enrage)
    * (r -> 'raw_n' ->> (least(4, greatest(1, n)) - 1))::numeric;
end $f$;

create or replace function public.world_mk_on_attack(p_fight uuid, p_uid uuid, p_round integer)
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_rules() -> 'mukjeok' -> 'board'; f public.world_gw_fights%rowtype; mul numeric; lit int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  lit := jsonb_array_length(coalesce(f.board -> 'lit', '[]'::jsonb));
  mul := 1 + (rb ->> 'lit_pct')::numeric / 100.0 * (lit - (rb ->> 'lit_base')::int);
  if f.mech ->> 'mimic' = 'hesit' then
    mul := mul * (1 + (rb ->> 'hesit_pct')::numeric / 100.0);
  elsif f.mech ->> 'mimic' = 'attack' then
    mul := mul * case when coalesce((f.mech ->> 'stuck')::boolean, false) then (rb ->> 'mimic_stuck')::numeric else (rb ->> 'mimic_atk')::numeric end;
    perform public.world_gw_hit(p_fight, p_uid, (rb ->> 'mimic_raw')::numeric * (1 + (public.world_boss_rules() -> 'mukjeok' ->> 'enrage')::numeric * f.enrage), p_round, '자세를 베낀 그림자가 먼저 휘두른 붓끝에', false);
  end if;
  return mul;
end $f$;

create or replace function public.world_mk_recall(p_fight uuid, p_uid uuid, p_round integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_rules() -> 'mukjeok' -> 'board'; f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; st int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if me.pos is null or me.pos = 5 then
    perform public.world_gw_say(p_fight, p_round, 'miss', me.name || ' — 가운데 칸에서는 기억을 되찾을 수 없습니다.'); return;
  end if;
  if f.board -> 'lit' @> to_jsonb(me.pos) then
    perform public.world_gw_say(p_fight, p_round, 'miss', me.name || ' — 이미 되찾은 칸이라 더 짚을 기억이 없습니다.'); return;
  end if;
  st := least(coalesce((f.board ->> 'max')::int, 9), coalesce((f.board ->> 'strokes')::int, 0) + 1);
  update public.world_gw_fights set board = board || jsonb_build_object('lit', coalesce(board -> 'lit', '[]'::jsonb) || to_jsonb(me.pos), 'strokes', st) where fight_id = p_fight;
  perform public.world_gw_credit(p_fight, p_uid, coalesce((me.stats ->> 'attack')::numeric, 0) * (rb ->> 'recall_credit')::numeric, 'boost');
  perform public.world_gw_say(p_fight, p_round, 'good', me.name || ' — 지워진 칸을 짚어 기억을 되찾았습니다. 가운데 칸의 이름이 한 획 또렷해집니다(이름 획 ' || st || ').');
  perform public.world_mk_memory(p_fight, p_round);
end $f$;

create or replace function public.world_mk_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_rules() -> 'mukjeok' -> 'board'; lm jsonb := public.world_mk_lines(); f public.world_gw_fights%rowtype; b jsonb; k text;
  w record; cells int[]; keeper public.world_gw_members%rowtype; n int; callers int; need int; ok boolean; lit int[]; gone int; st int; extra numeric := 0;
  cover uuid; half numeric := case when p_broke then 0.5 else 1 end; held uuid[] := '{}';
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; k := f.mech ->> 'k';
  st := coalesce((b ->> 'strokes')::int, 0);
  lit := array(select jsonb_array_elements_text(coalesce(b -> 'lit', '[]'::jsonb))::int);
  if coalesce(array_length(p_freed, 1), 0) > 0 then
    update public.world_gw_members set fx = fx - 'bound' where fight_id = p_fight and owner_id = any (p_freed) and fx ? 'bound';
  end if;
  held := array(select kk::uuid from jsonb_each_text(coalesce(b -> 'held', '{}'::jsonb)) e(kk, v) where v::int = p_round - 1);
  if coalesce(array_length(p_freed, 1), 0) > 0 then
    b := b || jsonb_build_object('held', coalesce(b -> 'held', '{}'::jsonb) - array(select u::text from unnest(p_freed) u));
  end if;
  if p_delayed and k <> 'erase' then b := b || jsonb_build_object('delay', 1); end if;
  select count(*) into n from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  select * into keeper from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest
     and (x.act ->> 'a' = 'brace' or (n = 1 and k = 'erase' and x.act ->> 'a' = 'call' and x.act ->> 't' = x.owner_id::text))
     and (x.pos = 5 or (x.fx ? 'taunt' and (lm -> 'nb' -> '5') @> to_jsonb(x.pos)))
   order by (x.pos = 5) desc, x.joined_at limit 1;
  if k = 'line' then
    cells := array(select jsonb_array_elements_text(f.mech -> 'cells')::int);
    for w in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and pos = any (cells)
              and not (owner_id is not distinct from keeper.owner_id and 5 = any (cells)) order by joined_at loop
      select owner_id into cover from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and fx ->> 'cover' = w.owner_id::text and owner_id <> w.owner_id limit 1;
      if cover is not null then
        perform public.world_gw_credit(p_fight, cover, (rb ->> 'line_raw')::numeric * half * 0.5, 'guard');
        perform public.world_gw_hit(p_fight, cover, (rb ->> 'line_raw')::numeric * half * 0.5, p_round, (select name from public.world_gw_members where fight_id = p_fight and owner_id = cover) || '이(가) ' || w.name || ' 앞을 막아서 먹줄을', true);
      else
        perform public.world_gw_hit(p_fight, w.owner_id, (rb ->> 'line_raw')::numeric * half, p_round, '줄을 따라 흘러내린 먹줄에', true);
      end if;
    end loop;
    if 5 = any (cells) then
      if keeper.owner_id is not null then
        perform public.world_gw_hit(p_fight, keeper.owner_id, (rb ->> 'line_raw')::numeric * (rb ->> 'keep_mul')::numeric * half, p_round, '가운데 칸을 지키며 먹줄을 정면으로 받아', true);
        perform public.world_gw_say(p_fight, p_round, 'good', keeper.name || ' — 가운데 칸에서 버텨 이름을 지켰습니다.');
      else
        st := st - (rb ->> 'line_strokes')::int;
        b := b || jsonb_build_object('lost', coalesce((b ->> 'lost')::int, 0) + (rb ->> 'line_strokes')::int);
        perform public.world_gw_say(p_fight, p_round, 'bad', '먹줄이 가운데 칸을 긋고 지나갑니다. 이름 획 ' || (rb ->> 'line_strokes') || '개가 지워졌습니다(남은 획 ' || greatest(0, st) || ').');
      end if;
    end if;
    gone := (select count(*) from unnest(lit) z where z = any (cells));
    lit := array(select z from unnest(lit) z where not (z = any (cells)));
    if gone > 0 then perform public.world_gw_say(p_fight, p_round, 'bad', '줄 위의 기억 칸 ' || gone || '곳이 먹에 덮여 지워졌습니다.'); end if;
    if p_broke then perform public.world_gw_say(p_fight, p_round, 'good', '퇴마 결계가 먹줄의 기세를 절반으로 꺾었습니다.'); end if;
  elsif k = 'erase' then
    if n = 1 then
      ok := keeper.owner_id is not null and (array_length(lit, 1) >= (rb ->> 'erase_sure_lit')::int or random() < coalesce(array_length(lit, 1), 0) / 8.0);
      if keeper.owner_id is not null then perform public.world_gw_say(p_fight, p_round, 'good', keeper.name || ' — 가운데 칸에 서서 제 이름을 외칩니다.'); end if;
    else
      need := ceil((n - 1) / 2.0)::int;
      callers := 0;
      if keeper.owner_id is not null then
        for w in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and owner_id <> keeper.owner_id
                  and act ->> 'a' = 'call' and act ->> 't' = keeper.owner_id::text order by joined_at loop
          callers := callers + 1;
          perform public.world_gw_say(p_fight, p_round, 'good', w.name || ' — 「' || keeper.name || '!」 가운데 칸의 이름을 불러 줍니다.');
        end loop;
      end if;
      ok := keeper.owner_id is not null and callers >= need;
    end if;
    for w in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'call'
              and (keeper.owner_id is null or act ->> 't' <> keeper.owner_id::text) and not (n = 1 and owner_id is not distinct from keeper.owner_id) loop
      perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — 이름을 불렀지만 가운데 칸에 선 사람이 없어 메아리만 돌아옵니다.');
    end loop;
    if ok then
      extra := round(f.max_hp * (rb ->> 'erase_pct')::numeric / 100.0);
      st := least(coalesce((b ->> 'max')::int, 9), st + 1);
      perform public.world_gw_say(p_fight, p_round, 'good', '붓이 꺾인다! 지키고 부르는 소리에 그림자가 휘청이며 ' || extra || '의 피해를 입었습니다. 가운데 칸의 이름이 한 획 또렷해집니다(이름 획 ' || st || ').');
    else
      st := st - (rb ->> 'erase_strokes')::int;
      b := b || jsonb_build_object('lost', coalesce((b ->> 'lost')::int, 0) + (rb ->> 'erase_strokes')::int);
      perform public.world_gw_say(p_fight, p_round, 'bad', case when keeper.owner_id is null then '가운데 칸을 지킨 사람이 없었습니다. ' else '이름을 불러 준 목소리가 모자랐습니다. ' end
        || '붓이 가운데 칸을 긋고, 이름 획 ' || (rb ->> 'erase_strokes') || '개가 지워졌습니다(남은 획 ' || greatest(0, st) || ').'
        || case when p_broke then ' (퇴마 결계가 번지는 먹을 절반으로 꺾었습니다)' else '' end || case when p_delayed then ' (흐름이 끊긴 붓이 먹을 덜 머금었습니다)' else '' end);
      for w in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest loop
        perform public.world_gw_hit(p_fight, w.owner_id, (rb ->> 'erase_raw')::numeric * half * case when p_delayed then 0.5 else 1 end, p_round, '가운데 칸에서 번져 나온 먹에', true);
      end loop;
      update public.world_gw_fights set enrage = enrage + 1 where fight_id = p_fight;
    end if;
  end if;
  if f.phase = 3 then
    for w in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and pos is not null and pos <> 5
              and not (owner_id = any (held)) and (b -> 'ink' ->> owner_id::text)::int = pos order by joined_at loop
      update public.world_gw_members set fx = fx || jsonb_build_object('bound', p_round) where fight_id = p_fight and owner_id = w.owner_id;
      b := b || jsonb_build_object('held', coalesce(b -> 'held', '{}'::jsonb) || jsonb_build_object(w.owner_id::text, p_round));
      perform public.world_gw_hit(p_fight, w.owner_id, (rb ->> 'bound_raw')::numeric, p_round, '같은 자리에 고인 먹에 발이 붙잡혀', false);
    end loop;
  end if;
  update public.world_gw_members set fx = fx - 'bound' where fight_id = p_fight and fx ? 'bound' and owner_id = any (held);
  b := b || jsonb_build_object('held', (select coalesce(jsonb_object_agg(kk, v::int), '{}'::jsonb) from jsonb_each_text(coalesce(b -> 'held', '{}'::jsonb)) e(kk, v) where v::int >= p_round));
  update public.world_gw_fights set board = (b - 'lit' - 'strokes') || jsonb_build_object('lit', to_jsonb(coalesce(lit, '{}'::int[])), 'strokes', greatest(0, st)),
    enrage = enrage where fight_id = p_fight;
  return extra;
end $f$;

create or replace function public.world_mk_after(p_fight uuid, p_round integer)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_rules() -> 'mukjeok' -> 'board'; f public.world_gw_fights%rowtype;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return true; end if;
  if not coalesce((f.board ->> 'low')::boolean, false) and f.hp > 0 and f.hp * 100 < f.max_hp * (rb ->> 'low_pct')::numeric then
    perform public.world_gw_say(p_fight, p_round, 'shadow', '그림자의 붓이 느려졌다. 그가 지운 칸들 사이로 되찾은 기억이 반짝였다.');
    perform public.world_gw_say(p_fight, p_round, 'shadow', '먹그림자: 내려놓으면 아프지 않다.');
    perform public.world_gw_say(p_fight, p_round, 'shadow', '먹그림자: ……그래도, 같이 남아 다오.');
    update public.world_gw_fights set board = board || '{"low": true}'::jsonb where fight_id = p_fight;
  end if;
  if coalesce((f.board ->> 'strokes')::int, 1) <= 0 then
    perform public.world_gw_say(p_fight, p_round, 'bad', '가운데 칸의 이름이 끝내 지워졌습니다. 명부가 먹으로 덮입니다.');
    perform public.world_gw_settle(p_fight, false);
    return true;
  end if;
  return false;
end $f$;

create or replace function public.world_mk_settle(p_fight uuid, p_won boolean)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_boss_rules() -> 'mukjeok'; f public.world_gw_fights%rowtype; m record; today date := (now() at time zone 'Asia/Seoul')::date;
  rec public.world_gw_records%rowtype; n int; solo boolean; flawless boolean; alllit boolean; lost int; is_first boolean; xp int; msg text; lv int; v_gil int; drop_item text; drop_ok boolean;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status not in ('fight', 'wait') then return; end if;
  update public.world_gw_fights set status = case when p_won then 'won' else 'failed' end, ended_at = now(), updated_at = now(), hp = case when p_won then 0 else hp end where fight_id = p_fight;
  select count(*), coalesce(sum(falls), 0) = 0 into n, flawless from public.world_gw_members where fight_id = p_fight;
  solo := n = 1; lost := coalesce((f.board ->> 'lost')::int, 0);
  alllit := jsonb_array_length(coalesce(f.board -> 'lit', '[]'::jsonb)) >= 8;
  drop_item := r -> 'again' ->> 'item';
  drop_ok := exists (select 1 from public.world_item_catalog where item_id = drop_item);
  if p_won then
    while public.world_mk_memory(p_fight, f.round, true) loop end loop;
  end if;
  for m in select * from public.world_gw_members where fight_id = p_fight loop
    if p_won then
      update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
      insert into public.world_gw_records(owner_id, boss_id) values (m.owner_id, 'mukjeok') on conflict do nothing;
      select * into rec from public.world_gw_records where owner_id = m.owner_id and boss_id = 'mukjeok' for update;
      if rec.last_kill_day is distinct from today then
        is_first := coalesce(rec.kills, 0) = 0;
        update public.world_gw_records set kills = kills + 1, last_kill_day = today, first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id and boss_id = 'mukjeok';
        select level into lv from public.world_characters where owner_id = m.owner_id;
        xp := case when lv >= (r ->> 'xp_cap_lv')::int then 0
          else round(public.world_xp_need(lv) * case when is_first then (r -> 'first' ->> 'xp')::numeric else (r -> 'again' ->> 'xp')::numeric end) end;
        v_gil := case when is_first then (r -> 'first' ->> 'gil')::int else (r -> 'again' ->> 'gil')::int end;
        update public.world_characters set gil = gil + v_gil, updated_at = now() where owner_id = m.owner_id;
        if xp > 0 then perform public.world_grant_xp(m.owner_id, xp); end if;
        if is_first then
          insert into public.world_owned_mounts(owner_id, mount_id) values (m.owner_id, r -> 'first' ->> 'mount') on conflict do nothing;
          insert into public.world_faction_unlocks(owner_id, unlock_key) values (m.owner_id, r -> 'first' ->> 'name_style') on conflict do nothing;
        elsif drop_ok then
          perform set_config('yh.bag_drop', 'on', true);
          update public.world_characters set inventory = public.world_inv_add(inventory, drop_item, (r -> 'again' ->> 'qty')::int), updated_at = now() where owner_id = m.owner_id;
          perform set_config('yh.bag_drop', '', true);
        end if;
        msg := case when is_first then '먹그림자를 처음으로 보냈습니다. ' || to_char(v_gil, 'FM999,999') || '전'
            || case when xp > 0 then ' · 경험치 ' || xp else '' end || ' · 탈것 「' || (r -> 'first' ->> 'mount_name') || '」 · 이름 색 「' || (r -> 'first' ->> 'name_style_name') || '」을 얻었습니다.'
          else '먹그림자를 보냈습니다(' || (coalesce(rec.kills, 0) + 1) || '번째). ' || v_gil || '전' || case when xp > 0 then ' · 경험치 ' || xp else '' end
            || case when drop_ok then ' · ' || (r -> 'again' ->> 'item_name') || ' ' || (r -> 'again' ->> 'qty') || '개' else '' end || '.' end;
        insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '먹그림자 처치', msg, jsonb_build_object('fight_id', p_fight, 'first', is_first, 'boss', 'mukjeok'));
        insert into public.world_events(actor_id, actor_name, event_type, content, payload)
        values (m.owner_id, m.name, 'mk_win', m.name || '이(가) 아홉 칸 뜰에서 먹그림자를 보냈습니다.',
                jsonb_build_object('fight_id', p_fight, 'boss', 'mukjeok', 'first', is_first, 'solo', solo, 'flawless', flawless and n >= 2 and lost = 0, 'alllit', alllit,
                  'members', n, 'kills', coalesce(rec.kills, 0) + 1, 'strokes_lost', lost));
      else
        insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '먹그림자 처치', '오늘은 이미 처치를 인정받아 보상은 없습니다.', jsonb_build_object('fight_id', p_fight, 'boss', 'mukjeok'));
      end if;
    else
      update public.world_item_durability d set durability = greatest(0, d.durability - ceil(public.world_item_max_durability(d.item_id) * (r -> 'fail' ->> 'dur')::numeric / 100.0)::int), updated_at = now()
        from public.world_character_equipment e where e.owner_id = m.owner_id and d.owner_id = m.owner_id and d.item_id = e.item_id;
      perform public.world_yohwa_overflow(m.owner_id, (select erosion from public.world_characters where owner_id = m.owner_id) + (r -> 'fail' ->> 'er')::int - 100);
      update public.world_characters set health = greatest(1, m.hp), erosion = least(100, erosion + (r -> 'fail' ->> 'er')::int),
             erosion_stage = case when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 80 then 4 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 55 then 3
               when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 30 then 2 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 10 then 1 else 0 end,
             updated_at = now() where owner_id = m.owner_id;
      insert into public.world_gw_records(owner_id, boss_id, last_fail_at) values (m.owner_id, 'mukjeok', now()) on conflict (owner_id, boss_id) do update set last_fail_at = now();
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (m.owner_id, 'gw', '먹그림자 도전 실패', '명부가 먹으로 덮여 밀려났습니다. 장착한 장비 내구도가 ' || (r -> 'fail' ->> 'dur') || '% 닳고 침식이 ' || (r -> 'fail' ->> 'er') || ' 올랐습니다. '
        || (r -> 'fail' ->> 'cd') || '분 뒤 다시 도전할 수 있습니다.', jsonb_build_object('fight_id', p_fight, 'boss', 'mukjeok'));
    end if;
  end loop;
  perform public.world_gw_say(p_fight, f.round, case when p_won then 'win' else 'bad' end, case when p_won
    then '먹그림자의 붓이 꺾였다. 먹이 흘러내리고, 가운데 칸의 이름이 검게, 또렷하게 돌아왔다.'
    else '도전이 끝났습니다.' end);
end $f$;

create or replace function public.world_gw_start(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; x record; s jsonb; sa numeric := 0; n int := 0; v_item text; br jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'wait' then return; end if;
  v_item := case when f.boss_id = 'mukjeok' then public.world_boss_rules() -> 'mukjeok' ->> 'item' else 'gwiheo_charm' end;
  for x in select m.owner_id, c.inventory, c.health from public.world_gw_members m join public.world_characters c using (owner_id) where m.fight_id = p_fight for update of c loop
    if coalesce((x.inventory ->> v_item)::int, 0) < 1 or x.health <= 0 then
      delete from public.world_gw_members where fight_id = p_fight and owner_id = x.owner_id;
      continue;
    end if;
    update public.world_characters set inventory = public.world_inv_add(inventory, v_item, -1), updated_at = now() where owner_id = x.owner_id;
    s := public.world_raid_stats(x.owner_id);
    update public.world_gw_members set stats = s, hp = greatest(30, least(100, x.health)) where fight_id = p_fight and owner_id = x.owner_id;
    insert into public.world_gw_records(owner_id, boss_id, tries) values (x.owner_id, f.boss_id, 1) on conflict (owner_id, boss_id) do update set tries = world_gw_records.tries + 1;
    sa := sa + coalesce((s ->> 'attack')::numeric, 50); n := n + 1;
  end loop;
  if n = 0 then
    update public.world_gw_fights set status = 'failed', ended_at = now(), updated_at = now() where fight_id = p_fight;
    return;
  end if;
  if f.boss_id = 'mukjeok' then
    br := public.world_boss_rules() -> 'mukjeok';
    update public.world_gw_fights set status = 'fight',
           max_hp = round(greatest((br ->> 'hp_min')::numeric, sa * (br ->> 'hp_atk')::numeric) * (br -> 'hp_n' ->> (least(4, n) - 1))::numeric),
           hp = round(greatest((br ->> 'hp_min')::numeric, sa * (br ->> 'hp_atk')::numeric) * (br -> 'hp_n' ->> (least(4, n) - 1))::numeric), phase = 1, round = 0, cycle = 0,
           ends_at = now() + make_interval(mins => (br ->> 'min')::int), updated_at = now() where fight_id = p_fight;
    if n = 1 then update public.world_gw_members m set stats = m.stats || public.world_solo_aid(m.job_key, 'mukjeok') where fight_id = p_fight; end if;
    perform public.world_mk_begin(p_fight, n);
    perform public.world_gw_next_round(p_fight);
    return;
  end if;
  update public.world_gw_fights set status = 'fight', max_hp = round(greatest(6000, sa * 40) * case n when 1 then 1.2 when 2 then 1.7 when 3 then 0.8 else 0.85 end),
         hp = round(greatest(6000, sa * 40) * case n when 1 then 1.2 when 2 then 1.7 when 3 then 0.8 else 0.85 end), phase = 1, round = 0, cycle = 0,
         ends_at = now() + interval '15 minutes', updated_at = now() where fight_id = p_fight;
  if n = 1 then update public.world_gw_members m set stats = m.stats || public.world_solo_aid(m.job_key) where fight_id = p_fight; end if;
  perform public.world_gw_say(p_fight, 0, 'phase', '빈 왕좌 위로 물이 솟아 사람 꼴이 된다. 귀허의 주인이 두 얼굴을 번갈아 든다. 「사람의 얼굴에는 사람의 칼을, 요괴의 얼굴에는…」 말끝이 물에 녹는다.');
  perform public.world_gw_next_round(p_fight);
end $f$;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[], p_n int) returns void language plpgsql as $f$
declare d text; i int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> p_n then raise exception '함수 % 모양이 예상과 다릅니다(%)', p_name, i; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_gw_next_round', array[
$q$  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  nr := f.round + 1;$q$,
$q$  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.boss_id = 'mukjeok' then perform public.world_mk_round(p_fight); return; end if;
  nr := f.round + 1;$q$], 1);

select pg_temp.yh_fix('world_gw_settle', array[
$q$  if f.status not in ('fight', 'wait') then return; end if;$q$,
$q$  if f.status not in ('fight', 'wait') then return; end if;
  if f.boss_id = 'mukjeok' then perform public.world_mk_settle(p_fight, p_won); return; end if;$q$,
$q$select * into rec from public.world_gw_records where owner_id = m.owner_id for update;$q$,
$q$select * into rec from public.world_gw_records where owner_id = m.owner_id and boss_id = 'gwiheo' for update;$q$,
$q$first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id;$q$,
$q$first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id and boss_id = 'gwiheo';$q$,
$q$insert into public.world_gw_records(owner_id, last_fail_at) values (m.owner_id, now()) on conflict (owner_id) do update set last_fail_at = now();$q$,
$q$insert into public.world_gw_records(owner_id, boss_id, last_fail_at) values (m.owner_id, 'gwiheo', now()) on conflict (owner_id, boss_id) do update set last_fail_at = now();$q$], 1);

select pg_temp.yh_fix('world_gw_hit', array[
$q$declare m public.world_gw_members%rowtype; r jsonb; c jsonb; av text; self_guard numeric;$q$,
$q$declare m public.world_gw_members%rowtype; r jsonb; c jsonb; av text; self_guard numeric; v_mech jsonb; v_board jsonb;$q$,
$q$  av := coalesce(m.act ->> 'a', 'guard');$q$,
$q$  av := coalesce(m.act ->> 'a', 'guard');
  if m.pos is not null then
    select x.mech, x.board into v_mech, v_board from public.world_gw_fights x where x.fight_id = p_fight;
    if coalesce(v_board -> 'lit', '[]'::jsonb) @> to_jsonb(m.pos) then
      p_raw := p_raw * (1 - (public.world_boss_rules() -> 'mukjeok' -> 'board' ->> 'lit_ward')::numeric / 100.0);
    end if;
    if v_mech ->> 'mimic' = 'guard' and av in ('guard', 'brace') then
      p_raw := p_raw * case when coalesce((v_mech ->> 'stuck')::boolean, false) then 1
        else (1 + case when av = 'guard' then 0.4 when p_aoe then 0.2 else 0.3 end) / 2 end;
      av := 'none';
    end if;
  end if;$q$], 1);

select pg_temp.yh_fix('world_gw_resolve', array[
$q$  v_mb text; v_mp numeric; v_eb text; v_ep numeric; v_cb text; v_cp numeric; v_cn text; v_brk uuid;$q$,
$q$  v_mb text; v_mp numeric; v_eb text; v_ep numeric; v_cb text; v_cp numeric; v_cn text; v_brk uuid; v_who text;$q$,
$q$  r := f.round; k := f.mech ->> 'k'; aoe := coalesce((f.mech ->> 'aoe')::boolean, false); vbfx := coalesce(f.bfx, '{}'::jsonb);$q$,
$q$  r := f.round; k := f.mech ->> 'k'; aoe := coalesce((f.mech ->> 'aoe')::boolean, false); vbfx := coalesce(f.bfx, '{}'::jsonb);
  v_who := case when f.boss_id = 'mukjeok' then '그림자' else '주인' end;
  if f.boss_id = 'mukjeok' then perform public.world_mk_steps(p_fight, r); end if;$q$,
$q$        when 'delay' then case when k = 'vortex' then ' (물살이 잠시 멎습니다)' else '' end$q$,
$q$        when 'delay' then case when k = 'vortex' then ' (물살이 잠시 멎습니다)' when f.boss_id = 'mukjeok' then ' (그림자의 붓끝이 멈칫합니다)' else '' end$q$,
$q$  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest order by joined_at loop
    a := coalesce(m.act, '{"a":"guard"}'::jsonb); av := a ->> 'a';$q$,
$q$  if f.boss_id = 'mukjeok' and sealed and f.mech ->> 'mimic' in ('attack', 'guard') then
    f.mech := f.mech || '{"mimic": "hesit", "stuck": false}'::jsonb;
    update public.world_gw_fights set mech = f.mech where fight_id = p_fight;
    perform public.world_gw_say(p_fight, r, 'good', '봉인 사슬에 묶인 그림자가 따라 쓰지 못하고 붓을 멈춥니다.');
  end if;
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest order by joined_at loop
    a := coalesce(m.act, '{"a":"guard"}'::jsonb); av := a ->> 'a';$q$,
$q$      d := (cbr ->> 'd')::numeric * (1 + coalesce((m.stats ->> 'solo_dmg')::numeric, 0) / 100.0);$q$,
$q$      d := (cbr ->> 'd')::numeric * (1 + coalesce((m.stats ->> 'solo_dmg')::numeric, 0) / 100.0);
      if f.boss_id = 'mukjeok' then d := d * public.world_mk_on_attack(p_fight, m.owner_id, r); end if;$q$,
$q$    elsif av = 'call' then
      tgt := nullif(a ->> 't', '')::uuid;$q$,
$q$    elsif av = 'recall' then
      perform public.world_mk_recall(p_fight, m.owner_id, r);
    elsif av = 'call' and f.boss_id = 'mukjeok' then
      null;
    elsif av = 'call' then
      tgt := nullif(a ->> 't', '')::uuid;$q$,
$q$  if k = 'chain' then
    for m in select$q$,
$q$  if f.boss_id = 'mukjeok' then boss_dmg := boss_dmg + public.world_mk_mech(p_fight, r, broke, delayed, freed); end if;
  if k = 'chain' then
    for m in select$q$,
$q$  if f.hp <= 0 then update public.world_gw_fights set bfx = vbfx where fight_id = p_fight; perform public.world_gw_settle(p_fight, true); return; end if;$q$,
$q$  if f.hp <= 0 then update public.world_gw_fights set bfx = vbfx where fight_id = p_fight; perform public.world_gw_settle(p_fight, true); return; end if;
  if f.boss_id = 'mukjeok' then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if public.world_mk_after(p_fight, r) then return; end if;
    select * into f from public.world_gw_fights where fight_id = p_fight;
  end if;$q$,
$q$    raw := (35 + 4 * f.phase) * (1 + 0.15 * f.enrage)
        * (select case count(*) when 1 then 1 when 2 then 1.4 when 3 then 0.8 else 0.85 end from public.world_gw_members where fight_id = p_fight);$q$,
$q$    if f.boss_id = 'mukjeok' then raw := public.world_mk_raw(p_fight); else
    raw := (35 + 4 * f.phase) * (1 + 0.15 * f.enrage)
        * (select case count(*) when 1 then 1 when 2 then 1.4 when 3 then 0.8 else 0.85 end from public.world_gw_members where fight_id = p_fight);
    end if;$q$,
$q$'모아 둔 기운이 터집니다. 왕좌 아래의 물이 한꺼번에 쏟아집니다!' || case when broke then ' (퇴마 결계가 물살을 절반으로 꺾었습니다)' else '' end$q$,
$q$case when f.boss_id = 'mukjeok' then '먹구름이 터집니다. 먹비가 뜰 위로 한꺼번에 쏟아집니다!' || case when broke then ' (퇴마 결계가 먹비를 절반으로 꺾었습니다)' else '' end
        else '모아 둔 기운이 터집니다. 왕좌 아래의 물이 한꺼번에 쏟아집니다!' || case when broke then ' (퇴마 결계가 물살을 절반으로 꺾었습니다)' else '' end end$q$,
$q$r, '쏟아지는 물살에', true);$q$,
$q$r, case when f.boss_id = 'mukjeok' then '쏟아지는 먹비에' else '쏟아지는 물살에' end, true);$q$,
$q$'주인의 손길이 묶여 허공을 가릅니다.'$q$,
$q$v_who || '의 손길이 묶여 허공을 가릅니다.'$q$,
$q$      v_hands := case when v_n >= 4 then 2 when v_n = 3 then 1 + (r % 2) else 1 end;$q$,
$q$      v_hands := case when v_n >= 4 then 2 when v_n = 3 then 1 + (r % 2) else 1 end;
      if f.boss_id = 'mukjeok' and f.mech ->> 'mimic' = 'guard' then v_hands := v_hands + 1; end if;$q$,
$q$coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)) limit 1;$q$,
$q$coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)
          + case when x.pos = 5 then (public.world_boss_rules() -> 'mukjeok' -> 'board' ->> 'center_pres')::numeric else 0 end) limit 1;$q$,
$q$'연막 속에서 주인의 손길이 '$q$,
$q$'연막 속에서 ' || v_who || '의 손길이 '$q$,
$q$' — 주인의 손길을 피했습니다.'$q$,
$q$' — ' || v_who || '의 손길을 피했습니다.'$q$,
$q$' 앞을 막아서 주인의 '$q$,
$q$' 앞을 막아서 ' || v_who || '의 '$q$,
$q$case when v_h > 1 then '주인의 다른 손아귀에' else '주인의 손아귀에' end$q$,
$q$case when v_h > 1 then v_who || '의 다른 손아귀에' else v_who || '의 손아귀에' end$q$,
$q$'모두가 물러났습니다. 소용돌이가 왕좌를 덮습니다.'$q$,
$q$case when f.boss_id = 'mukjeok' then '모두가 물러났습니다. 먹이 가운데 칸을 덮습니다.' else '모두가 물러났습니다. 소용돌이가 왕좌를 덮습니다.' end$q$,
$q$'시간이 다 되었습니다. 귀허의 주인이 바다 밑으로 가라앉습니다.'$q$,
$q$case when f.boss_id = 'mukjeok' then '시간이 다 되었습니다. 먹그림자가 명부를 먹으로 덮습니다.' else '시간이 다 되었습니다. 귀허의 주인이 바다 밑으로 가라앉습니다.' end$q$], 1);

select pg_temp.yh_fix('world_gw_join', array[
$q$  c := public.world_gw_ready(uid);$q$,
$q$  c := public.world_gw_ready(uid, f.boss_id);$q$,
$q$raise exception '귀허의 주인 앞에는 4명까지 설 수 있습니다.';$q$,
$q$raise exception '% 앞에는 4명까지 설 수 있습니다.', public.world_boss_rules() -> f.boss_id ->> 'name';$q$], 1);

select pg_temp.yh_fix('world_quest_task_count', array[
$q$p_task ->> 't' not in ('gw', 'raid', 'win', 'gather', 'craft', 'fish')$q$,
$q$p_task ->> 't' not in ('gw', 'mj', 'raid', 'win', 'gather', 'craft', 'fish')$q$,
$q$    when p_task ->> 't' = 'gw' then (select count(*)::int$q$,
$q$    when p_task ->> 't' in ('gw', 'mj') then (select count(*)::int$q$,
$q$where m.owner_id = p_uid and x.status = 'won' and m.acts > 0 and x.ended_at >= p_since)$q$,
$q$where m.owner_id = p_uid and x.status = 'won' and m.acts > 0 and x.ended_at >= p_since
                  and x.boss_id = case when p_task ->> 't' = 'mj' then 'mukjeok' else coalesce(p_task ->> 'boss', 'gwiheo') end)$q$], 1);

select pg_temp.yh_fix('world_quest_task_label', array[
$q$    when p_task ->> 't' = 'raid' then case$q$,
$q$    when p_task ->> 't' = 'mj' then '아홉 칸 명부에서 먹그림자 보내기'
    when p_task ->> 't' = 'raid' then case$q$], 1);

select pg_temp.yh_fix('world_shop_refresh', array[
$q$or sc.item_id = 'gwiheo_charm' or$q$,
$q$or sc.item_id in ('gwiheo_charm', 'seal_inkline') or$q$], 1);

select pg_temp.yh_fix('world_gwiryeong_chance', array[
$q$p_type in ('gw_win', 'raid_win')$q$,
$q$p_type in ('gw_win', 'raid_win', 'mk_win')$q$], 1);

select pg_temp.yh_fix('world_housing_event_trg', array[
$q$    perform public.world_pet_grant_source(new.actor_id, 'gw_first');$q$,
$q$    perform public.world_pet_grant_source(new.actor_id, 'gw_first');
  elsif new.event_type = 'mk_win' then
    perform public.world_housing_grant_once(new.actor_id, 'mk_first', '먹그림자 첫 처치');$q$], 1);

drop trigger if exists trg_world_gwiryeong_roll on public.world_events;
create trigger trg_world_gwiryeong_roll after insert on public.world_events for each row
  when (new.event_type = any (array['gather', 'combat', 'expedition_end', 'gw_win', 'mk_win'])) execute function public.world_gwiryeong_roll();
drop trigger if exists trg_world_housing_event on public.world_events;
create trigger trg_world_housing_event after insert on public.world_events for each row
  when (new.event_type = any (array['combat', 'expedition_end', 'story', 'gw_win', 'mk_win'])) execute function public.world_housing_event_trg();

drop function if exists public.world_gw_ready(uuid);
create or replace function public.world_gw_ready(p_uid uuid, p_boss text default 'gwiheo')
 returns public.world_characters language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare c public.world_characters%rowtype; rec public.world_gw_records%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; br jsonb := public.world_boss_rules() -> p_boss;
begin
  if br is null then raise exception '알 수 없는 우두머리입니다.'; end if;
  select * into c from public.world_characters where owner_id = p_uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 도전할 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 도전할 수 없습니다.'; end if;
  if p_boss = 'mukjeok' then
    if (public.world_region_at(c.location)).region_id is distinct from br ->> 'region' then raise exception '%에서만 %의 앞에 설 수 있습니다.', br ->> 'place', br ->> 'name'; end if;
    if c.level < (br ->> 'lv')::int then raise exception 'Lv%부터 도전할 수 있습니다.', br ->> 'lv'; end if;
    if br ->> 'quest' is not null and not public.world_quest_done(p_uid, br ->> 'quest') then raise exception '%을(를) 마쳐야 %의 앞에 설 수 있습니다.', br ->> 'quest_name', br ->> 'name'; end if;
  else
    if (public.world_region_at(c.location)).region_id is distinct from 'gwiheo_core' then raise exception '귀허에서만 귀허의 주인 앞에 설 수 있습니다.'; end if;
    if not public.world_gwiheo_open(p_uid) then raise exception '귀허도에 아직 건너오지 못했습니다.'; end if;
    if c.level < 38 then raise exception 'Lv38부터 도전할 수 있습니다.'; end if;
    if not public.world_quest_done(p_uid, 'gq_4') then raise exception '외전 4장 「달 없는 장」을 마쳐야 귀허의 주인 앞에 설 수 있습니다.'; end if;
  end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = p_uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '요괴와 싸우는 중입니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then raise exception '원정 중에는 도전할 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = 'active') then raise exception '자율 활동 중에는 도전할 수 없습니다.'; end if;
  select * into rec from public.world_gw_records where owner_id = p_uid and boss_id = p_boss;
  if p_boss = 'mukjeok' then
    if rec.last_kill_day = today then raise exception '오늘은 이미 먹그림자를 보냈습니다. 내일(한국 시각 0시 뒤) 다시 도전할 수 있습니다.'; end if;
    if rec.last_fail_at > now() - make_interval(mins => (br -> 'fail' ->> 'cd')::int) then
      raise exception '명부의 먹이 아직 마르지 않았습니다. %분 뒤 다시 도전할 수 있습니다.', ceil(extract(epoch from rec.last_fail_at + make_interval(mins => (br -> 'fail' ->> 'cd')::int) - now()) / 60);
    end if;
    if coalesce((c.inventory ->> (br ->> 'item'))::int, 0) < 1 then raise exception '%이(가) 필요합니다. %에서 팝니다.', br ->> 'item_name', br ->> 'shop_name'; end if;
  else
    if rec.last_kill_day = today then raise exception '오늘은 이미 귀허의 주인을 쓰러뜨렸습니다. 내일(한국 시각 0시 뒤) 다시 도전할 수 있습니다.'; end if;
    if rec.last_fail_at > now() - interval '30 minutes' then
      raise exception '귀허의 소용돌이가 아직 가라앉지 않았습니다. %분 뒤 다시 도전할 수 있습니다.', ceil(extract(epoch from rec.last_fail_at + interval '30 minutes' - now()) / 60);
    end if;
    if coalesce((c.inventory ->> 'gwiheo_charm')::int, 0) < 1 then raise exception '귀허 부적이 필요합니다. 반요촌 잡화에서 팝니다.'; end if;
  end if;
  if exists (select 1 from public.world_gw_members m join public.world_gw_fights f using (fight_id) where m.owner_id = p_uid and f.status in ('wait', 'fight')) then
    raise exception '이미 %와(과) 싸우는 중입니다.', (select public.world_boss_rules() -> x.boss_id ->> 'name' from public.world_gw_members m join public.world_gw_fights x using (fight_id)
      where m.owner_id = p_uid and x.status in ('wait', 'fight') limit 1); end if;
  return c;
end $f$;

drop function if exists public.world_gw_ready_check(uuid);
create or replace function public.world_gw_ready_check(p_uid uuid, p_boss text default 'gwiheo')
 returns void language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare c public.world_characters%rowtype; rec public.world_gw_records%rowtype; br jsonb := public.world_boss_rules() -> p_boss;
begin
  if br is null then raise exception '알 수 없는 우두머리입니다.'; end if;
  select * into c from public.world_characters where owner_id = p_uid;
  if (public.world_region_at(c.location)).region_id is distinct from br ->> 'region' then raise exception '%에서만 도전할 수 있습니다.', br ->> 'place'; end if;
  if c.level < (br ->> 'lv')::int then raise exception 'Lv%부터 도전할 수 있습니다.', br ->> 'lv'; end if;
  if br ->> 'quest' is not null and not public.world_quest_done(p_uid, br ->> 'quest') then raise exception '%을(를) 마쳐야 합니다.', br ->> 'quest_name'; end if;
  select * into rec from public.world_gw_records where owner_id = p_uid and boss_id = p_boss;
  if rec.last_kill_day = (now() at time zone 'Asia/Seoul')::date then raise exception '오늘은 이미 처치했습니다. 내일 다시 도전할 수 있습니다.'; end if;
  if rec.last_fail_at > now() - make_interval(mins => (br -> 'fail' ->> 'cd')::int) then
    raise exception '%분 뒤 다시 도전할 수 있습니다.', ceil(extract(epoch from rec.last_fail_at + make_interval(mins => (br -> 'fail' ->> 'cd')::int) - now()) / 60); end if;
  if coalesce((c.inventory ->> (br ->> 'item'))::int, 0) < 1 then raise exception '%이(가) 필요합니다(%).', br ->> 'item_name', br ->> 'shop_name'; end if;
end $f$;

drop function if exists public.world_gw_open();
create or replace function public.world_gw_open(p_boss text default 'gwiheo')
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; fid uuid; x record; n int := 0; boss text := coalesce(p_boss, 'gwiheo'); br jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  br := public.world_boss_rules() -> boss;
  if br is null then raise exception '알 수 없는 우두머리입니다.'; end if;
  perform public.world_seal_guard();
  c := public.world_gw_ready(uid, boss);
  select count(*) into n from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id and b.owner_id <> a.owner_id
    join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null;
  insert into public.world_gw_fights(leader_id, status, start_at, boss_id) values (uid, 'wait', now() + case when n > 0 then interval '60 seconds' else interval '0' end, boss)
    returning fight_id into fid;
  insert into public.world_gw_members(fight_id, owner_id, name, job_key, level) values (fid, uid, c.character_name, c.job_key, c.level);
  for x in select b.owner_id from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id and b.owner_id <> a.owner_id
             join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null limit 3 loop
    if boss = 'mukjeok' then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (x.owner_id, 'gw_invite', '먹그림자 · 함께 싸우기', c.character_name || '이(가) 아홉 칸 명부 앞에 섰습니다. 60초 안에 합류하세요(' || (br ->> 'item_name') || ' 1개).',
        jsonb_build_object('fight_id', fid, 'boss', boss));
    else
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (x.owner_id, 'gw_invite', '귀허의 주인 · 함께 싸우기', c.character_name || '이(가) 귀허의 주인 앞에 섰습니다. 60초 안에 합류하세요(귀허 부적 1개).', jsonb_build_object('fight_id', fid));
    end if;
  end loop;
  if n = 0 then perform public.world_gw_start(fid); end if;
  return public.world_gw_snapshot(fid);
end $f$;

drop function if exists public.world_gw_tips();
create or replace function public.world_gw_tips(p_boss text default 'gwiheo')
 returns jsonb language sql immutable set search_path = pg_catalog
as $f$
  select case when p_boss = 'mukjeok' then jsonb_build_array(
    '진법 판: 가운데 칸의 이름 획이 다 지워지면 진다. 라운드마다 가로·세로 이웃 칸으로 한 칸 옮겨 설 수 있고(행동과 따로), 빛나는 칸에 서면 받는 피해가 줄어든다. 빛나는 칸이 많을수록 그림자가 더 아파한다.',
    '먹줄 긋기: 붓끝이 기우는 줄(빨간 띠) 밖으로 옮겨 선다. 줄이 가운데를 지나면 한 사람이 가운데 칸에서 버티기로 이름을 지킨다(철벽 수호를 건 호위 무사는 가운데 바로 옆 칸에서도 된다). 줄 위의 기억 칸은 지워진다.',
    '되찾기: 지워진 빈칸에 서서 고르면 그 칸이 다시 빛나고 이름 획이 하나 돌아온다. 공격을 쉬는 사람이 틈틈이 되찾는다.',
    '따라 쓰는 붓(2단계): 그림자는 지난 라운드에 가장 많이 고른 갈래(공격 / 방어·버티기)를 따라 한다. 공격과 막기를 같은 수로 나누거나, 혼자라면 공격과 기술·물품·되찾기를 번갈아 쓰면 머뭇거린다. 봉인 사슬도 붓을 멈춘다.',
    '발자국(3단계): 두 라운드 잇달아 같은 칸에 서면 먹에 묶인다(가운데 칸은 괜찮다). 묶이면 해독 침으로 푼다.',
    '이름 지우기(4단계): 한 사람이 가운데 칸에서 버티고, 나머지 절반 이상이 그 사람의 이름을 불러 준다. 혼자라면 가운데 칸에서 제 이름을 부른다 — 빛나는 칸이 여섯 이상이면 반드시 된다.')
  else jsonb_build_array(
    '두 얼굴: 사람의 얼굴에는 근접·원거리(물리), 요괴의 얼굴에는 술법만 듣는다. 반대로 치면 주인이 회복한다 — 봉인술사의 「봉인 사슬」로 묶으면 그 라운드에는 삼키지 못한다.',
    '사슬 넷: 저마다 손목 사슬의 빛깔이 다르다. 10초 안에 자기 빛깔의 사슬만 끊는다. 남의 사슬을 치면 되튕기고, 못 끊은 사람은 끌려간다. 의무관의 「해독 침」은 동료의 사슬을 대신 풀어 준다.',
    '이름 빼앗기: 이름을 잃은 사람의 공격은 닿지 않는다. 동료가 10초 안에 「이름 부르기」로 그 사람을 불러 줘야 풀린다(스스로는 잘 안 된다). 「해독 침」도 풀어 준다.',
    '귀허의 소용돌이: 물살이 쏠린 사람이 「버티기」나 방어로 받아 내고, 나머지는 모두 공격해 정해진 양을 넘겨야 끊긴다. 「흐름 끊기」는 끊을 양을 절반으로, 「철벽 수호」(호위 무사)을 건 사람은 대신 버틸 수 있다. 실패하면 모두 체력 절반(퇴마 결계·파사 진언이 있으면 ¼)·주인 분노.',
    '「기를 모으기 시작했다」가 보이면 그 라운드 끝에 모두를 치는 물살이 온다. 「버티기」(피해 20%)·방어(40%)·퇴마 결계(절반)로 대비한다. 고르지 않으면 저절로 방어한다.') end
$f$;

drop function if exists public.world_gw_act(uuid, text, uuid, text);
create or replace function public.world_gw_act(p_fight uuid, p_action text, p_target uuid default null, p_item text default null, p_move smallint default null)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; a jsonb;
  sk public.world_coop_skills%rowtype; c public.world_characters%rowtype; mk boolean; dest int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_action not in ('attack', 'guard', 'brace', 'coop', 'call', 'chain', 'item', 'recall') then raise exception '알 수 없는 행동입니다.'; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if not found or f.status <> 'fight' then raise exception '싸움이 끝났습니다.'; end if;
  if now() >= f.round_ends_at then perform public.world_gw_resolve(p_fight); select * into f from public.world_gw_fights where fight_id = p_fight; end if;
  if f.status <> 'fight' then return public.world_gw_snapshot(p_fight); end if;
  mk := f.boss_id = 'mukjeok';
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = uid for update;
  if not found then raise exception '이 싸움에 들지 않았습니다.'; end if;
  if me.out_rounds > 0 then raise exception '물러나 있습니다. %라운드 뒤 돌아옵니다.', me.out_rounds; end if;
  if p_target is not null and not exists (select 1 from public.world_gw_members where fight_id = p_fight and owner_id = p_target) then raise exception '함께 싸우는 조사원이 아닙니다.'; end if;
  if not mk and (p_action = 'recall' or p_move is not null) then raise exception '알 수 없는 행동입니다.'; end if;
  if mk and p_action = 'chain' then raise exception '알 수 없는 행동입니다.'; end if;
  if mk and p_move is not null then
    if p_move = me.pos then p_move := null;
    elsif public.world_mk_held(p_fight, uid) then raise exception '먹에 발이 묶여 이번 라운드에는 칸을 옮길 수 없습니다.';
    elsif me.pos is null or not ((public.world_mk_lines() -> 'nb' -> me.pos::text) @> to_jsonb(p_move::int)) then raise exception '바로 옆(가로·세로) 칸으로만 옮겨 설 수 있습니다.';
    end if;
  end if;
  if p_action = 'recall' then
    dest := coalesce(p_move, me.pos);
    if dest is null or dest = 5 or coalesce(f.board -> 'lit', '[]'::jsonb) @> to_jsonb(dest) then raise exception '지워진 빈칸에 서 있어야 기억을 되찾을 수 있습니다.'; end if;
  end if;
  if mk and p_action = 'call' and f.mech ->> 'k' is distinct from 'erase' then raise exception '이름 부르기는 그림자가 가운데 칸의 이름을 지우려 할 때만 할 수 있습니다.'; end if;
  if p_action = 'coop' then
    select * into sk from public.world_coop_skills where skill_id = coalesce(p_item, '');
    select * into c from public.world_characters where owner_id = uid;
    if sk.skill_id is null or sk.job_key is distinct from c.job_key then raise exception '쓸 수 없는 기술입니다.'; end if;
    if coalesce(c.combat_rank, 1) < sk.unlock_rank then raise exception '전투 숙련 %단계에 열리는 기술입니다.', sk.unlock_rank; end if;
    if coalesce((me.cds ->> sk.skill_id)::int, 0) > f.round then raise exception '%라운드 뒤에 다시 쓸 수 있습니다.', (me.cds ->> sk.skill_id)::int - f.round; end if;
    if coalesce(c.spiritual_power, 0) < sk.cost then raise exception '영력(기력)이 모자랍니다(%).', sk.cost; end if;
    if sk.target = 'ally' and p_target is null then p_target := uid; end if;
  end if;
  if p_action = 'call' and p_target is null then raise exception '이름을 부를 사람을 고르세요.'; end if;
  if p_action = 'item' then
    if coalesce(public.world_item_base(coalesce(p_item, '')), '') <> all (public.world_battle_item_ids('gw')) then
      raise exception '%과(와) 싸우는 동안에는 체력 회복품(%)만 쓸 수 있습니다.', public.world_boss_rules() -> f.boss_id ->> 'name', public.world_battle_item_names('gw'); end if;
    if coalesce(me.items_used, 0) >= 2 then raise exception '이 싸움에서는 회복품을 두 개까지만 쓸 수 있습니다.'; end if;
    select * into c from public.world_characters where owner_id = uid;
    if coalesce((c.inventory ->> p_item)::int, 0) < 1 then raise exception '가방에 그 물품이 없습니다.'; end if;
    if p_target is null then p_target := uid; end if;
  end if;
  a := jsonb_build_object('a', p_action) || case when p_target is not null then jsonb_build_object('t', p_target) else '{}'::jsonb end
       || case when p_action = 'coop' then jsonb_build_object('s', p_item) when p_action = 'item' then jsonb_build_object('i', p_item) when p_action = 'chain' then jsonb_build_object('c', coalesce(p_item, '')) else '{}'::jsonb end
       || case when p_move is not null then jsonb_build_object('m', p_move) else '{}'::jsonb end;
  if me.rest then perform public.world_gw_say(p_fight, f.round, 'good', me.name || ' — 숨을 고르고 다시 싸움에 나섭니다.'); end if;
  update public.world_gw_members set act = a, rest = false where fight_id = p_fight and owner_id = uid;
  perform public.world_gw_resolve(p_fight);
  return public.world_gw_snapshot(p_fight);
end $f$;

drop function if exists public.world_gw_snapshot(uuid);
create or replace function public.world_gw_snapshot(p_fight uuid default null, p_boss text default null)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; rec public.world_gw_records%rowtype; c public.world_characters%rowtype;
  fid uuid := p_fight; why text; inv_f uuid; last_f uuid; gsh jsonb; boss text := coalesce(p_boss, 'gwiheo'); br jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if public.world_boss_rules() -> boss is null then raise exception '알 수 없는 우두머리입니다.'; end if;
  if fid is null then
    select m.fight_id into fid from public.world_gw_members m join public.world_gw_fights x using (fight_id) where m.owner_id = uid and x.status in ('wait', 'fight')
      and (p_boss is null or x.boss_id = p_boss) order by x.created_at desc limit 1;
  end if;
  select * into c from public.world_characters where owner_id = uid;
  if fid is null then
    br := public.world_boss_rules() -> boss;
    select * into rec from public.world_gw_records where owner_id = uid and boss_id = boss;
    select x.fight_id into inv_f from public.world_gw_fights x join public.world_party_members a on a.owner_id = x.leader_id join public.world_party_members b on b.party_id = a.party_id and b.owner_id = uid
     where x.status = 'wait' and x.start_at > now() and x.boss_id = boss order by x.created_at desc limit 1;
    select m.fight_id into last_f from public.world_gw_members m join public.world_gw_fights x using (fight_id)
     where m.owner_id = uid and x.status in ('won', 'failed') and x.boss_id = boss and x.created_at > now() - interval '1 day' order by x.created_at desc limit 1;
    begin perform public.world_gw_ready_check(uid, boss); exception when others then why := sqlerrm; end;
    return jsonb_build_object('none', true, 'boss', boss, 'invite', inv_f, 'last', last_f, 'can_open', why is null, 'why', why, 'charms', coalesce((c.inventory ->> (br ->> 'item'))::int, 0),
      'kills', coalesce(rec.kills, 0), 'tips', case when coalesce(rec.kills, 0) > 0 then public.world_gw_tips(boss) end, 'here', (public.world_region_at(c.location)).region_id = br ->> 'region');
  end if;
  select * into f from public.world_gw_fights where fight_id = fid;
  if not found then raise exception '싸움을 찾을 수 없습니다.'; end if;
  if not exists (select 1 from public.world_gw_members where fight_id = fid and owner_id = uid)
     and not (f.status = 'wait' and exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id where a.owner_id = f.leader_id and b.owner_id = uid)) then
    raise exception '함께 싸우는 조사원만 볼 수 있습니다.';
  end if;
  if f.status = 'wait' and f.start_at <= now() then perform public.world_gw_start(fid); end if;
  if f.status = 'fight' then perform public.world_gw_resolve(fid); end if;
  select * into f from public.world_gw_fights where fight_id = fid;
  select * into me from public.world_gw_members where fight_id = fid and owner_id = uid;
  select * into rec from public.world_gw_records where owner_id = uid and boss_id = f.boss_id;
  gsh := public.world_gw_shares(fid);
  return jsonb_build_object('boss', f.boss_id, 'fight', jsonb_build_object('id', f.fight_id, 'status', f.status, 'hp', f.hp, 'max_hp', f.max_hp, 'phase', f.phase, 'round', f.round,
      'round_ends_at', f.round_ends_at, 'ends_at', f.ends_at, 'start_at', f.start_at, 'leader', f.leader_id, 'enrage', f.enrage,
      'mech', case f.mech ->> 'k' when 'chain' then jsonb_build_object('k', 'chain', 'colors', (select jsonb_agg(v order by v) from jsonb_each_text(f.mech -> 'colors') e(kk, v)), 'mine', f.mech -> 'colors' ->> uid::text,
        'aoe', f.mech -> 'aoe', 'tell', f.mech -> 'tell')
        when 'vortex' then f.mech - 'need' || jsonb_build_object('need', (f.mech ->> 'need')::int)
        else f.mech end,
      'bfx', (select coalesce(jsonb_agg(kk), '[]'::jsonb) from jsonb_object_keys(coalesce(f.bfx, '{}'::jsonb)) kk)),
    'board', case when f.boss_id = 'mukjeok' then jsonb_build_object('strokes', coalesce((f.board ->> 'strokes')::int, 0), 'max', coalesce((f.board ->> 'max')::int, 9),
        'lit', coalesce(f.board -> 'lit', '[]'::jsonb), 'mem', coalesce((f.board ->> 'mem')::int, 0), 'lost', coalesce((f.board ->> 'lost')::int, 0),
        'ink', (select coalesce(jsonb_agg(distinct v::int), '[]'::jsonb) from jsonb_each_text(coalesce(f.board -> 'ink', '{}'::jsonb)) e(kk, v)),
        'moves', case when me.pos is not null and not public.world_mk_held(fid, uid) and f.status = 'fight' then public.world_mk_lines() -> 'nb' -> me.pos::text else '[]'::jsonb end,
        'my_pos', me.pos) end,
    'now', now(), 'me', uid,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', m.owner_id, 'name', m.name, 'job', m.job_key, 'level', m.level, 'hp', m.hp, 'out', m.out_rounds, 'resting', m.rest,
        'nameless', m.nameless, 'acted', m.act is not null, 'dmg', m.dmg, 'heal', m.heal, 'taken', m.taken, 'falls', m.falls, 'credits', m.credits, 'share', coalesce((gsh ->> m.owner_id::text)::numeric, 0),
        'pos', m.pos, 'bound', f.boss_id = 'mukjeok' and public.world_mk_held(fid, m.owner_id),
        'fx', (select coalesce(jsonb_agg(kk), '[]'::jsonb) from jsonb_object_keys(coalesce(m.fx, '{}'::jsonb)) kk)) order by m.joined_at), '[]'::jsonb) from public.world_gw_members m where m.fight_id = fid),
    'my_act', me.act, 'joined', me.owner_id is not null, 'sp', c.spiritual_power, 'ammo', public.world_ammo_left(c.owner_id),
    'items', (select coalesce(jsonb_object_agg(k, (c.inventory ->> k)::int), '{}'::jsonb) from unnest(public.world_battle_item_have('gw')) k
        where coalesce((c.inventory ->> k)::int, 0) > 0),
    'items_left', greatest(0, 2 - coalesce(me.items_used, 0)),
    'falls_cap', 10 + coalesce((select max((x.stats ->> 'solo_falls')::int) from public.world_gw_members x where x.fight_id = fid), 0),
    'solo', case when (select count(*) from public.world_gw_members x where x.fight_id = fid) = 1 then jsonb_build_object('dmg', me.stats -> 'solo_dmg', 'falls', me.stats -> 'solo_falls', 'guard', me.stats -> 'solo_guard') end,
    'skills', case when me.owner_id is not null then (select coalesce(jsonb_agg(jsonb_build_object('id', s.skill_id, 'name', s.skill_name, 'desc', s.description, 'target', s.target, 'cost', s.cost,
        'rounds', greatest(1, ceil(s.cooldown_s / 5.0)::int), 'rank', s.unlock_rank, 'unlocked', coalesce(c.combat_rank, 1) >= s.unlock_rank,
        'wait', greatest(0, coalesce((me.cds ->> s.skill_id)::int, 0) - f.round)) order by s.sort), '[]'::jsonb) from public.world_coop_skills s where s.job_key = c.job_key) end,
    'log', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'round', l.round, 'kind', l.kind, 'text', l.text) order by l.id), '[]'::jsonb)
        from (select * from public.world_gw_log where fight_id = fid order by id desc limit case when f.status in ('won', 'failed') then 200 else 60 end) l),
    'tips', case when coalesce(rec.kills, 0) > 0 then public.world_gw_tips(f.boss_id) end);
end $f$;

grant create on schema public to fn_owner_field;
do $g$
declare fn text;
begin
  foreach fn in array array['world_gw_ready(uuid, text)', 'world_gw_ready_check(uuid, text)', 'world_gw_open(text)', 'world_gw_tips(text)',
    'world_gw_act(uuid, text, uuid, text, smallint)', 'world_gw_snapshot(uuid, text)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', fn);
    execute format('alter function public.%s owner to fn_owner_field', fn);
  end loop;
end $g$;
revoke create on schema public from fn_owner_field;
set role fn_owner_field;
revoke all on function public.world_gw_ready(uuid, text) from public, anon, authenticated;
revoke all on function public.world_gw_ready_check(uuid, text) from public, anon, authenticated;
revoke all on function public.world_gw_tips(text) from public, anon, authenticated;
revoke all on function public.world_gw_open(text) from public, anon;
revoke all on function public.world_gw_act(uuid, text, uuid, text, smallint) from public, anon;
revoke all on function public.world_gw_snapshot(uuid, text) from public, anon;
grant execute on function public.world_gw_ready(uuid, text) to service_role;
grant execute on function public.world_gw_ready_check(uuid, text) to service_role;
grant execute on function public.world_gw_tips(text) to service_role;
grant execute on function public.world_gw_open(text) to service_role, authenticated;
grant execute on function public.world_gw_act(uuid, text, uuid, text, smallint) to service_role, authenticated;
grant execute on function public.world_gw_snapshot(uuid, text) to service_role, authenticated;
reset role;
do $g$
declare fn text;
begin
  foreach fn in array array['world_boss_rules()', 'world_solo_aid(text, text)', 'world_mk_lines()', 'world_mk_memories()', 'world_mk_memory(uuid, integer, boolean)',
    'world_mk_begin(uuid, integer)', 'world_mk_round(uuid)', 'world_mk_steps(uuid, integer)', 'world_mk_held(uuid, uuid)', 'world_mk_raw(uuid)', 'world_mk_on_attack(uuid, uuid, integer)',
    'world_mk_recall(uuid, uuid, integer)', 'world_mk_mech(uuid, integer, boolean, boolean, uuid[])', 'world_mk_after(uuid, integer)', 'world_mk_settle(uuid, boolean)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', fn);
    execute format('grant execute on function public.%s to service_role, fn_owner_field', fn);
  end loop;
end $g$;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size, quality_grade, market_only)
values ('seal_inkline', '봉인 먹줄', 'consumable', 4, '먹그림자 앞에 서려면 하나씩 지녀야 하는 먹줄. 아홉 칸 명부의 바깥 테두리를 묶어 둔다. 묵창 나루 주막에서만 판다.', true, '{}'::jsonb, 44, '{}'::jsonb, false, 800, 20, 0, false)
on conflict (item_id) do nothing;
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
values ('mukchang_shop', 'seal_inkline', 1200, 1, 1, 4) on conflict do nothing;

insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, unlock_faction, unlock_region, unlock_item, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method)
select 'ink_crane', '먹 그림 학', speed_multiplier, 44, unlock_reputation, unlock_faction, unlock_region, unlock_item, price,
  '먹그림자를 보낸 조사원을 태우는 학. 먹으로 그린 날개가 바람을 타면 획이 번지듯 소리 없이 미끄러진다. 운임은 구간당 노정패 1.', tier, passenger_capacity, fare_tokens, fare_free, acquire_method
  from public.world_mount_catalog where mount_id = 'moonless_boat'
on conflict (mount_id) do nothing;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size, quality_grade, market_only)
values ('hf_screen_ninefold', '아홉 칸 명부 병풍', 'furniture', 5, '별채 가구 · 병풍. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1,
  '{"d": 1, "w": 3, "hk": "screen_ninefold", "cat": "병풍", "top": 0, "kind": "floor", "grade": 5}'::jsonb, false, 2000, 1, 0, false)
on conflict (item_id) do nothing;
insert into public.world_furniture_sources(source, item_id, chance) values ('mk_first', 'hf_screen_ninefold', 1) on conflict do nothing;

insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
  ('fr_ninecourt', 'frame', 'legend', '아홉 칸 명부 테', '먹그림자를 보낸다', '외전', '{"ev": "mk_win"}', false, true, 1110),
  ('pt_ninecourt', 'pattern', 'legend', '먹줄 구궁 무늬', '먹그림자를 3번 보낸다', '외전', '{"n": 3, "ev": "mk_win"}', false, true, 1111),
  ('sl_jeok', 'seal', 'legend', '낙관 「跡」', '먹그림자를 10번 보낸다', '외전', '{"n": 10, "ev": "mk_win"}', false, true, 1112)
on conflict (cosmetic_key) do nothing;

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('mk_kill1', '먹그림자를 보낸 이', 'flag', '아홉 칸 명부에서 먹그림자를 처음으로 보냈다.', '먹그림자를 보낸다', '{"presence": 6, "erosion_pct": -6, "combat_damage_pct": 3}', true, false, '{"n": 1, "ev": "mk_win"}', 1110, '외전', 5),
  ('mk_kill3', '명부 뜰의 손님', 'flag', '아홉 칸 뜰에 세 번 들어섰다가 걸어 나왔다.', '먹그림자를 3번 보낸다', '{"healing_pct": 4, "incoming_damage_pct": -3}', true, false, '{"n": 3, "ev": "mk_win"}', 1111, '외전', 4),
  ('mk_kill10', '아홉 칸을 지킨 이', 'flag', '가운데 칸의 이름을 열 번 지켜 냈다.', '먹그림자를 10번 보낸다', '{"mental_loss_pct": -6, "combat_damage_pct": 2}', true, false, '{"n": 10, "ev": "mk_win"}', 1112, '외전', 5),
  ('mk_kill25', '묵적을 거둔 이', 'flag', '명부에 번진 먹 자국을 스물다섯 번 걷어 냈다.', '먹그림자를 25번 보낸다', '{"crit_pct": 2, "erosion_pct": -8, "rare_loot_pct": 3}', true, false, '{"n": 25, "ev": "mk_win"}', 1113, '외전', 5),
  ('mk_solo', '제 이름을 부른 이', 'flag', '아무도 곁에 없이 가운데 칸에서 제 이름을 외쳐 먹그림자를 보냈다.', '혼자 먹그림자를 보낸다', '{"evasion_pct": 2, "combat_damage_pct": 3}', true, false, '{"p": {"solo": true}, "ev": "mk_win"}', 1114, '외전', 5),
  ('mk_flawless', '한 획도 잃지 않은 뜰', 'flag', '누구 하나 물러나지 않고, 이름 획을 한 번도 잃지 않은 채 먹그림자를 보냈다.', '둘 이상이 함께, 아무도 물러나지 않고 이름 획을 잃지 않은 채 먹그림자를 보낸다', '{"healing_pct": 5, "incoming_damage_pct": -3}', true, false, '{"p": {"flawless": true}, "ev": "mk_win"}', 1115, '외전', 5),
  ('mk_alllit', '아홉 칸을 밝힌 이', 'flag', '바깥 여덟 칸이 모두 빛나는 가운데 먹그림자를 보냈다.', '바깥 여덟 칸이 모두 빛나는 채로 먹그림자를 보낸다', '{"clue_bonus_pct": 4, "mental_loss_pct": -4}', true, true, '{"p": {"alllit": true}, "ev": "mk_win"}', 1116, '외전', 5)
on conflict (title_key) do nothing;

select public.world_quest_label_refresh();

update public.world_patch_notes set body = rtrim(body) || $N$

## 외전 5장 · 먹그림자
- 외전 「묵적록」 마지막 장, 아홉 칸 뜰에서 우두머리 「먹그림자」와 싸웁니다. 외전 4장을 마친 Lv44부터, 봉인 먹줄 하나(묵창 주막)를 들고 혼자 또는 같은 곳 파티원 넷까지 18분 동안 겨룹니다.
- 바닥은 아홉 칸 명부입니다. 가운데 칸의 이름 획 아홉이 모두 지워지면 집니다. 라운드마다 이웃 칸으로 한 칸 옮겨 설 수 있고, 지워진 칸에 서서 「되찾기」를 고르면 잃은 기억이 돌아옵니다. 빛나는 칸이 많을수록 그림자가 약해집니다.
- 먹줄 긋기 · 따라 쓰는 붓 · 발자국 · 이름 지우기의 네 단계가 있습니다. 따라 쓰는 붓은 지난 라운드에 많이 고른 행동을 흉내 내고, 발자국 단계에서는 같은 칸에 두 번 서면 먹에 묶이며, 이름 지우기에서는 한 사람이 가운데를 지키는 동안 나머지가 이름을 불러 주어야 합니다.
- 싸우는 동안 떠오르는 기억 조각은 화면 아래에 잠깐 떴다 사라지고, 끝난 뒤 전투 기록에서 모두 다시 볼 수 있습니다.
- 처음 보내면 2,000전과 탈것 「먹 그림 학」, 이름 색 「묵적」, 별채 가구 「아홉 칸 명부 병풍」을 받습니다. 칭호 일곱(숨김 하나)과 테두리·바탕 무늬·낙관 「跡」도 있습니다.
$N$ where note_id = '2.0.0' and position('먹그림자' in body) = 0;

update public.world_app_meta set value = '20261116010000' where key = 'db_version';
