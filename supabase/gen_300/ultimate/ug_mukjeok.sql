do $$
declare r jsonb := public.world_boss_rules();
begin
  r := jsonb_set(r, '{mukjeok,ultimate}', $j${"min": 25, "raw": [60, 6], "tip": "역할을 나눠 둘 이상이 함께 가야 깰 수 있습니다 — 몰아칠 사람(공격)에 더해, 노림을 받아 버티거나 돕는 사람(방패·보조) 또는 돌볼 사람(치유)을 함께 꾸리세요.",
    "acts": [{"boss": "mukjeok", "cuts": [10, 20, 30], "name": "먹그림자", "rounds": 36}], "phases": ["먹줄", "따라 쓰는 붓", "가운데 칸", "먹비"],
    "hp_n": [1, 1.0, 1.35, 1.5], "items": 3, "raw_n": [1, 1.2, 1.3, 1.3], "hp_atk": 10.5, "hp_min": 12000, "rest_hp": 30, "rest_rounds": 2,
    "board": {"hand_mul": 1.6, "mech_mul": 1, "strokes": 9, "aoe_every": 6,
      "fail": {"raw": 15},
      "line": {"every": 3, "off": 1, "left": 2, "raw": 60},
      "step": {"every": 2, "off": 0, "left": 1, "raw": 55},
      "mimic": {"every": 4, "off": 2, "left": 1, "raw": 50},
      "erase": {"every": 6, "off": 4, "left": 2, "raw": 45, "pct": 4},
      "mem": {"every": 4, "off": 0, "left": 1},
      "seq": [{"at": 100, "m": {"line": 1}}, {"at": 87.5, "m": {"line": 1, "step": 1}}, {"at": 75, "m": {"step": 1, "mimic": 1}},
        {"at": 50, "m": {"step": 1, "mimic": 1, "erase": 1}}, {"at": 25, "m": {"line": 2, "step": 1, "mimic": 1, "erase": 1}}]}}$j$::jsonb);
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
end $$;

create or replace function public.world_ug_mk_cells(p_h jsonb)
 returns int[] language sql immutable set search_path = pg_catalog, public
as $f$
  select case when p_h ->> 'k' = 'line' then array(select jsonb_array_elements_text(p_h -> 'cells')::int)
    when p_h ->> 'k' in ('step', 'erase', 'mem') then array[(p_h ->> 'c')::int] else '{}'::int[] end
$f$;

create or replace function public.world_ug_mk_reach(p_hz jsonb, p_pos integer, p_nr integer, p_goal integer default null, p_goal_r integer default null)
 returns boolean language plpgsql immutable set search_path = pg_catalog, public
as $f$
declare nb jsonb := public.world_mk_lines() -> 'nb'; s int[]; t int; last int; d int[];
begin
  if p_pos is null then return p_goal is null; end if;
  s := array[p_pos];
  select max(p_nr + (e ->> 'left')::int) into last from jsonb_array_elements(coalesce(p_hz, '[]'::jsonb)) e where e ->> 'k' in ('line', 'step');
  last := greatest(coalesce(last, p_nr), coalesce(p_goal_r, p_nr));
  for t in p_nr .. last loop
    d := array(select distinct z from jsonb_array_elements(coalesce(p_hz, '[]'::jsonb)) e, unnest(public.world_ug_mk_cells(e)) z
      where e ->> 'k' in ('line', 'step') and p_nr + (e ->> 'left')::int = t);
    s := array(select distinct q.z from (select unnest(s) z union select jsonb_array_elements_text(nb -> c::text)::int from unnest(s) c) q where not (q.z = any (d)));
    if p_goal is not null and t = p_goal_r then s := array(select z from unnest(s) z where z = p_goal); end if;
    if coalesce(array_length(s, 1), 0) = 0 then return false; end if;
  end loop;
  return true;
end $f$;

create or replace function public.world_ug_mk_ok(p_fight uuid, p_hz jsonb, p_nr integer, p_goal integer default null, p_goal_r integer default null)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare x record;
begin
  for x in select pos from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest loop
    if not public.world_ug_mk_reach(p_hz, x.pos, p_nr) then return false; end if;
  end loop;
  if p_goal is not null and not exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest
      and public.world_ug_mk_reach(p_hz, pos, p_nr, p_goal, p_goal_r)) then return false; end if;
  return true;
end $f$;

create or replace function public.world_ug_mk_due_at(p_hz jsonb, p_k text, p_left integer)
 returns boolean language sql immutable set search_path = pg_catalog, public
as $f$ select exists (select 1 from jsonb_array_elements(coalesce(p_hz, '[]'::jsonb)) e where e ->> 'k' = p_k and (e ->> 'left')::int = p_left) $f$;

create or replace function public.world_ug_mk_dmg(p_fight uuid, p_uid uuid, p_raw numeric, p_round integer, p_why text, p_guardable boolean)
 returns integer language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare m public.world_gw_members%rowtype;
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  return public.world_gw_hurt(p_fight, p_uid, round(p_raw * coalesce((public.world_boss_fight_rules(p_fight) -> 'board' ->> 'mech_mul')::numeric, 1)
    * case when p_guardable and coalesce(m.act ->> 'a', 'guard') in ('guard', 'brace') then 0.5 else 1 end)::int, p_round, p_why);
end $f$;

create or replace function public.world_ug_mk_seq(p_fight uuid, p_hp integer, p_max integer)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare e jsonb; pick jsonb; i int := -1; k int := 0; pct numeric := p_hp * 100.0 / greatest(1, p_max);
begin
  for e in select * from jsonb_array_elements(public.world_boss_fight_rules(p_fight) -> 'board' -> 'seq') loop
    if pct <= (e ->> 'at')::numeric then pick := e; i := k; end if;
    k := k + 1;
  end loop;
  return coalesce(pick, public.world_boss_fight_rules(p_fight) -> 'board' -> 'seq' -> 0) || jsonb_build_object('i', greatest(i, 0));
end $f$;

create or replace function public.world_ug_mk_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb := br -> 'board'; lm jsonb := public.world_mk_lines();
  b jsonb; nr int; ar int; ph int; hz jsonb := '[]'; h jsonb; cur jsonb; ms jsonb; hid int; alive uuid[]; na int; aoe boolean := false; due boolean;
  ids text[] := array['r0', 'r1', 'r2', 'c0', 'c1', 'c2']; pick text[]; try int; cand jsonb; nl int; c int; t uuid; cells int[]; cfg jsonb; v_left int;
  cue text[] := '{}'; lit int[]; eg int; egr int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := coalesce(f.board, '{}'::jsonb); nr := f.round + 1; ar := nr - coalesce((b -> 'ug' ->> 'act_start')::int, 0);
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  alive := array(select owner_id from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest order by random());
  na := coalesce(array_length(alive, 1), 0);
  hid := coalesce((b ->> 'hid')::int, 0);
  lit := array(select jsonb_array_elements_text(coalesce(b -> 'lit', '[]'::jsonb))::int);
  cur := public.world_ug_mk_seq(p_fight, f.hp, f.max_hp); ms := coalesce(public.world_ug_wm_easy_j(p_fight), cur -> 'm');
  if (cur ->> 'i')::int <> coalesce((b ->> 'seq')::int, 0) then
    perform public.world_gw_say(p_fight, nr, 'phase', case
      when ms ? 'erase' and ms ? 'line' then '먹구름이 명부 위로 내려앉는다. 먹줄과 발자국, 흉내와 이름 지우기가 한꺼번에 몰려온다.'
      when ms ? 'erase' then '그림자가 가운데 칸 위에 선다. 붓이 이름 쪽으로 기운다.'
      when ms ? 'mimic' then '그림자가 붓을 고쳐 쥔다. 누군가의 몸짓을 그대로 베껴 쓰려 한다.'
      when ms ? 'step' then '밟고 선 자리마다 먹이 스며들기 시작한다.'
      else '그림자가 명부 위에 붓을 눕힌다.' end);
    b := b || jsonb_build_object('seq', (cur ->> 'i')::int);
  end if;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    hz := hz || jsonb_build_array(h || jsonb_build_object('left', (h ->> 'left')::int - 1));
  end loop;
  if na > 0 and ar > 0 then
    if ms ? 'erase' then
      cfg := rb -> 'erase'; v_left := (cfg ->> 'left')::int;
      if ar % (cfg ->> 'every')::int = (cfg ->> 'off')::int and not public.world_ug_mk_due_at(hz, 'mimic', v_left)
         and not exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'line' and (e ->> 'left')::int = v_left and e -> 'cells' @> '5'::jsonb) then
        hid := hid + 1;
        cand := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'erase', 'c', 5, 'left', v_left));
        if public.world_ug_mk_ok(p_fight, cand, nr, 5, nr + v_left) then hz := cand; cue := cue || '이름 지우기'::text; end if;
      end if;
    end if;
    select 5, nr + (e ->> 'left')::int into eg, egr from jsonb_array_elements(hz) e where e ->> 'k' = 'erase' limit 1;
    if ms ? 'line' then
      cfg := rb -> 'line'; v_left := (cfg ->> 'left')::int;
      if ar % (cfg ->> 'every')::int = (cfg ->> 'off')::int then
        nl := (ms ->> 'line')::int;
        <<lines>>
        while nl > 0 loop
          for try in 1 .. 24 loop
            pick := array(select l from unnest(ids) l order by random() limit nl);
            cells := array(select distinct jsonb_array_elements_text(lm -> 'lines' -> l)::int from unnest(pick) l);
            continue when 5 = any (cells) and public.world_ug_mk_due_at(hz, 'erase', v_left);
            cand := hz;
            for c in 1 .. nl loop
              hid := hid + 1;
              cand := cand || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'line', 'l', pick[c], 'cells', lm -> 'lines' -> pick[c], 'left', v_left));
            end loop;
            if public.world_ug_mk_ok(p_fight, cand, nr, eg, egr) then hz := cand; cue := cue || '먹줄'::text; exit lines; end if;
          end loop;
          nl := nl - 1;
        end loop;
      end if;
    end if;
    if ms ? 'step' then
      cfg := rb -> 'step'; v_left := (cfg ->> 'left')::int;
      if ar % (cfg ->> 'every')::int = (cfg ->> 'off')::int then
        for c, t in select distinct on (x.pos) x.pos, x.owner_id from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest
            and x.pos is not null and x.pos <> 5 order by x.pos, x.joined_at loop
          hid := hid + 1;
          cand := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'step', 'c', c, 't', t, 'left', v_left));
          if public.world_ug_mk_ok(p_fight, cand, nr, eg, egr) then hz := cand; end if;
        end loop;
        if exists (select 1 from jsonb_array_elements(hz) e where e ->> 'k' = 'step' and (e ->> 'left')::int = v_left) then cue := cue || '발자국'::text; end if;
      end if;
    end if;
    if ms ? 'mimic' then
      cfg := rb -> 'mimic'; v_left := (cfg ->> 'left')::int;
      if ar % (cfg ->> 'every')::int = (cfg ->> 'off')::int and not public.world_ug_mk_due_at(hz, 'erase', v_left) then
        t := alive[1];
        hid := hid + 1;
        hz := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'mimic', 't', t, 'left', v_left));
        cue := cue || '흉내'::text;
      end if;
    end if;
    cfg := rb -> 'mem'; v_left := (cfg ->> 'left')::int;
    if ar % (cfg ->> 'every')::int = (cfg ->> 'off')::int and not public.world_ug_mk_due_at(hz, 'erase', v_left) and not public.world_ug_mk_due_at(hz, 'mimic', v_left) then
      for c in select z from unnest(array[1, 2, 3, 4, 6, 7, 8, 9]) z where not (z = any (lit)) order by random() loop
        hid := hid + 1;
        cand := hz || jsonb_build_array(jsonb_build_object('id', hid, 'k', 'mem', 'c', c, 'left', v_left));
        if public.world_ug_mk_ok(p_fight, cand, nr, c, nr + v_left) then hz := cand; cue := cue || '기억'::text; exit; end if;
      end loop;
    end if;
  end if;
  due := exists (select 1 from jsonb_array_elements(hz) e where (e ->> 'left')::int <= 0);
  aoe := not due and ar > 0 and ar % (rb ->> 'aoe_every')::int = 0;
  b := b || jsonb_build_object('hz', hz, 'hid', hid, 'mimic_hit', '[]'::jsonb);
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, board = b,
    mech = jsonb_build_object('k', 'normal', 'aoe', aoe, 'due', due, 'cue', to_jsonb(cue),
      'tell', case when due then '그림자의 붓끝이 떨린다.' when aoe then '먹구름이 뜰 위로 낮게 내려앉는다.' else '그림자가 붓에 먹을 다시 찍는다.' end),
    round_ends_at = now() + make_interval(secs => case when due then 10 else 5 end), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
end $f$;

create or replace function public.world_ug_mk_on_attack(p_fight uuid, p_uid uuid, p_round integer)
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; lit int; nm text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if exists (select 1 from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) e where e ->> 'k' = 'mimic' and (e ->> 'left')::int <= 0 and e ->> 't' = p_uid::text) then
    select name into nm from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
    perform public.world_gw_say(p_fight, p_round, 'bad', nm || ' — 흉내 낸 그림자가 휘두른 칼끝을 그대로 되돌려 보냅니다.');
    update public.world_gw_fights set board = jsonb_set(board, '{mimic_hit}', coalesce(board -> 'mimic_hit', '[]'::jsonb) || to_jsonb(p_uid::text)) where fight_id = p_fight;
    perform public.world_ug_mk_dmg(p_fight, p_uid, (rb -> 'mimic' ->> 'raw')::numeric, p_round, '되돌아온 제 칼끝에', false);
    return 0;
  end if;
  lit := jsonb_array_length(coalesce(f.board -> 'lit', '[]'::jsonb));
  return 1 + (rb ->> 'lit_pct')::numeric / 100.0 * (lit - (rb ->> 'lit_base')::int);
end $f$;

create or replace function public.world_ug_mk_recall(p_fight uuid, p_uid uuid, p_round integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; h jsonb; st int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if f.board -> 'wm' ->> 'status' = 'on' and f.board -> 'wm' -> 'steps' @> to_jsonb(p_round) then return; end if;
  select e into h from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) e where e ->> 'k' = 'mem' and (e ->> 'left')::int <= 0 and (e ->> 'c')::int = me.pos limit 1;
  if h is null then
    perform public.world_gw_say(p_fight, p_round, 'miss', me.name || ' — 되새길 기억이 떠오르지 않은 칸입니다. 손끝이 허공만 짚었습니다.');
    return;
  end if;
  st := least(coalesce((f.board ->> 'max')::int, 9), coalesce((f.board ->> 'strokes')::int, 0) + 1);
  update public.world_gw_fights set board = board || jsonb_build_object('strokes', st,
      'lit', (select coalesce(jsonb_agg(distinct z order by z), '[]'::jsonb) from (select jsonb_array_elements_text(coalesce(board -> 'lit', '[]'::jsonb))::int z union select me.pos) q),
      'hz', (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(board -> 'hz') e where (e ->> 'id')::int <> (h ->> 'id')::int))
   where fight_id = p_fight;
  perform public.world_gw_credit(p_fight, p_uid, coalesce((me.stats ->> 'attack')::numeric, 0) * (rb ->> 'recall_credit')::numeric, 'boost');
  perform public.world_gw_say(p_fight, p_round, 'good', me.name || ' — 떠오른 기억을 제때 되새겼습니다. 칸이 다시 빛나고 이름이 한 획 또렷해집니다(이름 획 ' || st || ').');
end $f$;

create or replace function public.world_ug_mk_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; b jsonb; h jsonb; keep jsonb := '[]'; x record; k record;
  fails jsonb := '{}'; st int; lit int[]; extra numeric := 0; n int; callers int; need int; half numeric := case when p_broke then 0.5 else 1 end;
  nm text; tot int := 0; mine int; erase_due boolean := false; u text; v int; cnt int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; st := coalesce((b ->> 'strokes')::int, 0);
  lit := array(select jsonb_array_elements_text(coalesce(b -> 'lit', '[]'::jsonb))::int);
  select count(*) into n from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  for u in select jsonb_array_elements_text(coalesce(b -> 'mimic_hit', '[]'::jsonb)) loop
    fails := fails || jsonb_build_object(u, coalesce((fails ->> u)::int, 0) + 1);
  end loop;
  for h in select * from jsonb_array_elements(coalesce(b -> 'hz', '[]'::jsonb)) loop
    if (h ->> 'left')::int > 0 then keep := keep || jsonb_build_array(h); continue; end if;
    if h ->> 'k' = 'line' then
      cnt := 0;
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = any (public.world_ug_mk_cells(h)) order by y.joined_at loop
        perform public.world_ug_mk_dmg(p_fight, x.owner_id, (rb -> 'line' ->> 'raw')::numeric * half, p_round, '그어진 먹줄에', false);
        fails := fails || jsonb_build_object(x.owner_id::text, coalesce((fails ->> x.owner_id::text)::int, 0) + 1);
        cnt := cnt + 1;
      end loop;
      perform public.world_gw_say(p_fight, p_round, case when cnt = 0 then 'good' else 'bad' end, '먹줄이 ' || (public.world_mk_lines() -> 'names' ->> (h ->> 'l')) || '을 긋고 지나갑니다'
        || case when cnt = 0 then ' — 아무도 그 줄에 없었습니다.' else '.' end);
    elsif h ->> 'k' = 'step' then
      for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = (h ->> 'c')::int order by y.joined_at loop
        perform public.world_ug_mk_dmg(p_fight, x.owner_id, (rb -> 'step' ->> 'raw')::numeric * half, p_round, '발밑에 고였다 터진 먹에', false);
        fails := fails || jsonb_build_object(x.owner_id::text, coalesce((fails ->> x.owner_id::text)::int, 0) + 1);
      end loop;
    elsif h ->> 'k' = 'mimic' then
      select * into x from public.world_gw_members y where y.fight_id = p_fight and y.owner_id = (h ->> 't')::uuid;
      if x.owner_id is not null and x.out_rounds = 0 and not x.rest and not (b -> 'mimic_hit') ? x.owner_id::text then
        perform public.world_gw_say(p_fight, p_round, 'good', x.name || ' — ' || case when coalesce(x.act ->> 'a', 'guard') in ('guard', 'brace') then '몸을 웅크리자 흉내 낸 그림자도 웅크린 채 붓을 내려놓았습니다.'
          else '칼을 들지 않아 흉내 낸 그림자가 베낄 것이 없었습니다.' end);
      end if;
    elsif h ->> 'k' = 'erase' then
      erase_due := true;
      select * into k from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.pos = 5 order by y.joined_at limit 1;
      select count(*) into callers from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'call'
        and y.owner_id is distinct from k.owner_id;
      need := case when n <= 1 then 0 else ceil((n - 1) / 2.0)::int end;
      if k.owner_id is not null and callers >= need then
        extra := extra + round(f.max_hp * (rb -> 'erase' ->> 'pct')::numeric / 100.0);
        st := least(coalesce((b ->> 'max')::int, 9), st + 1);
        perform public.world_gw_say(p_fight, p_round, 'good', k.name || '이(가) 가운데 칸을 지키고 ' || case when callers > 0 then callers || '명이 이름을 불러 주자 ' else '' end
          || '붓이 꺾였습니다. 그림자가 ' || round(f.max_hp * (rb -> 'erase' ->> 'pct')::numeric / 100.0) || '의 피해를 입고 이름이 한 획 또렷해집니다(이름 획 ' || st || ').');
      else
        tot := tot + 1;
        if k.owner_id is not null then perform public.world_ug_weak_add(p_fight, k.owner_id, p_round); end if;
        perform public.world_gw_say(p_fight, p_round, 'bad', case when k.owner_id is null then '가운데 칸에 선 사람이 없었습니다. ' else '이름을 불러 준 목소리가 모자랐습니다(' || callers || '/' || need || '). ' end
          || '붓이 가운데 칸을 긋고 지나갑니다.');
        for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest loop
          perform public.world_ug_mk_dmg(p_fight, x.owner_id, (rb -> 'erase' ->> 'raw')::numeric * half, p_round, '가운데 칸에서 번져 나온 먹에', true);
        end loop;
      end if;
    elsif h ->> 'k' = 'mem' then
      perform public.world_gw_say(p_fight, p_round, 'miss', public.world_mk_cell_name((h ->> 'c')::int) || ' 칸에 떠올랐던 기억이 되새겨지지 못하고 흩어졌습니다.');
    end if;
  end loop;
  if not erase_due and not public.world_ug_wm_on(p_fight) then
    for x in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.act ->> 'a' = 'call' loop
      perform public.world_gw_say(p_fight, p_round, 'miss', x.name || ' — 이름을 불렀지만 지워지려는 이름이 없어 메아리만 돌아옵니다.');
    end loop;
  end if;
  for u, v in select kk, vv::int from jsonb_each_text(fails) e(kk, vv) loop
    tot := tot + v;
    select * into x from public.world_gw_members where fight_id = p_fight and owner_id = u::uuid;
    for i in 1 .. v loop perform public.world_ug_weak_add(p_fight, u::uuid, p_round); end loop;
    if x.pos is not null and x.pos <> 5 then lit := array_remove(lit, x.pos::int); end if;
    perform public.world_gw_say(p_fight, p_round, 'bad', x.name || ' — 수법을 놓쳐 ' || case when x.pos is not null and x.pos <> 5 then '선 칸이 먹에 덮이고 ' else '' end
      || '번진 먹이 곁의 동료에게도 튑니다.');
    for k in select * from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest and y.owner_id <> u::uuid loop
      perform public.world_ug_mk_dmg(p_fight, k.owner_id, (rb -> 'fail' ->> 'raw')::numeric * v, p_round, x.name || '의 실수로 번진 먹에', false);
    end loop;
  end loop;
  update public.world_gw_fights set board = (board - 'lit' - 'strokes' - 'hz' - 'mimic_hit')
      || jsonb_build_object('lit', to_jsonb(coalesce(lit, '{}'::int[])), 'strokes', greatest(0, st), 'hz', keep, 'mimic_hit', '[]'::jsonb,
         'fails', coalesce((board ->> 'fails')::int, 0) + tot)
   where fight_id = p_fight;
  return extra;
end $f$;

create or replace function public.world_ug_mk_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board';
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  return jsonb_build_object('ugmk', true, 'strokes', coalesce((f.board ->> 'strokes')::int, 0), 'max', coalesce((f.board ->> 'max')::int, 9),
    'lit', coalesce(f.board -> 'lit', '[]'::jsonb), 'mem', 0, 'lost', 0, 'ink', '[]'::jsonb, 'my_pos', me.pos,
    'moves', case when me.pos is not null and f.status = 'fight' then public.world_mk_lines() -> 'nb' -> me.pos::text else '[]'::jsonb end,
    'hz', (select coalesce(jsonb_agg(e || jsonb_build_object('cells', to_jsonb(public.world_ug_mk_cells(e)))), '[]'::jsonb) from jsonb_array_elements(coalesce(f.board -> 'hz', '[]'::jsonb)) e),
    'fails', coalesce((f.board ->> 'fails')::int, 0),
    'mechs', public.world_ug_mk_seq(p_fight, f.hp, f.max_hp) -> 'm');
end $f$;

revoke all on function public.world_ug_mk_cells(jsonb), public.world_ug_mk_reach(jsonb, integer, integer, integer, integer), public.world_ug_mk_ok(uuid, jsonb, integer, integer, integer),
  public.world_ug_mk_due_at(jsonb, text, integer), public.world_ug_mk_dmg(uuid, uuid, numeric, integer, text, boolean), public.world_ug_mk_seq(uuid, integer, integer),
  public.world_ug_mk_round(uuid), public.world_ug_mk_on_attack(uuid, uuid, integer), public.world_ug_mk_recall(uuid, uuid, integer),
  public.world_ug_mk_mech(uuid, integer, boolean, boolean, uuid[]), public.world_ug_mk_view(uuid, uuid) from public, anon, authenticated;
grant execute on function public.world_ug_mk_cells(jsonb), public.world_ug_mk_reach(jsonb, integer, integer, integer, integer), public.world_ug_mk_ok(uuid, jsonb, integer, integer, integer),
  public.world_ug_mk_due_at(jsonb, text, integer), public.world_ug_mk_dmg(uuid, uuid, numeric, integer, text, boolean), public.world_ug_mk_seq(uuid, integer, integer),
  public.world_ug_mk_round(uuid), public.world_ug_mk_on_attack(uuid, uuid, integer), public.world_ug_mk_recall(uuid, uuid, integer),
  public.world_ug_mk_mech(uuid, integer, boolean, boolean, uuid[]), public.world_ug_mk_view(uuid, uuid) to service_role, fn_owner_field;

select pg_temp.yh_patch('public.world_mk_round(uuid)',
  $o$  b := f.board; nr := f.round + 1;$o$,
  $n$  if f.mode = 'ultimate' then perform public.world_ug_mk_round(p_fight); return; end if;
  b := f.board; nr := f.round + 1;$n$);
select pg_temp.yh_patch('public.world_mk_mech(uuid,integer,boolean,boolean,uuid[])',
  $o$  b := f.board; k := f.mech ->> 'k';$o$,
  $n$  if f.mode = 'ultimate' then return public.world_ug_mk_mech(p_fight, p_round, p_broke, p_delayed, p_freed); end if;
  b := f.board; k := f.mech ->> 'k';$n$);
select pg_temp.yh_patch('public.world_mk_on_attack(uuid,uuid,integer)',
  $o$  lit := jsonb_array_length(coalesce(f.board -> 'lit', '[]'::jsonb));$o$,
  $n$  if f.mode = 'ultimate' then return public.world_ug_mk_on_attack(p_fight, p_uid, p_round); end if;
  lit := jsonb_array_length(coalesce(f.board -> 'lit', '[]'::jsonb));$n$);
select pg_temp.yh_patch('public.world_mk_recall(uuid,uuid,integer)',
  $o$  if me.pos is null or me.pos = 5 then$o$,
  $n$  if f.mode = 'ultimate' then perform public.world_ug_mk_recall(p_fight, p_uid, p_round); return; end if;
  if me.pos is null or me.pos = 5 then$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if p_action = 'recall' then
    dest := coalesce(p_move, me.pos);$o$,
  $n$  if p_action = 'call' and p_target is null and mk and f.mode = 'ultimate' then p_target := uid; end if;
  if p_action = 'recall' and not (mk and f.mode = 'ultimate') then
    dest := coalesce(p_move, me.pos);$n$);
