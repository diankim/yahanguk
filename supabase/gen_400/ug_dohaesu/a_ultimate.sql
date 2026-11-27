lock table public.world_characters in access exclusive mode;

do $$
declare r jsonb := public.world_boss_rules(); ref50 jsonb := '{"analyst": 537, "spearman": 482, "exorcist": 455, "formation": 455, "medic": 453, "sealmaster": 453, "scout": 441, "tamer": 440, "bloodknight": 411, "artificer": 388}';
  k text;
begin
  foreach k in array array['sealed_lord', 'gwiheo', 'mukjeok', 'gapgwi', 'baekya'] loop
    r := jsonb_set(r, array[k, 'ultimate', 'dps'], jsonb_build_object('ref', ref50, 'hp_k', (r -> k -> 'ultimate' ->> 'hp_atk')::numeric, 'spec', 'Lv50 · 8단계 무기 +10 · 8단계 방어구 한 벌'));
  end loop;
  r := jsonb_set(r, '{dohaesu,modes,ultimate}', '"무용담"');
  r := jsonb_set(r, '{ttangul,modes,ultimate}', '"무용담"');
  r := jsonb_set(r, '{dohaesu,ultimate}', $j${
    "min": 35, "raw": [32, 3], "raw_n": [0.6, 0.7, 0.8, 0.85], "hp_n": [1, 1.3, 1, 1], "hp_min": 9000, "items": 3, "rest_hp": 30, "rest_rounds": 2,
    "tip": "역할을 나눠 둘 이상이 함께 가야 깰 수 있습니다 — 몰아칠 사람(공격)에 더해, 노림을 받아 버티거나 돕는 사람(방패·보조) 또는 돌볼 사람(치유)을 함께 꾸리세요.",
    "dps": {"ref": {"analyst": 584, "spearman": 525, "exorcist": 495, "formation": 495, "medic": 494, "sealmaster": 494, "scout": 480, "tamer": 480, "bloodknight": 447, "artificer": 422},
      "hp_k": 155, "spec": "Lv55 · 9단계 무기 +10 · 9단계 방어구 한 벌"},
    "acts": [{"boss": "dohaesu", "cuts": [25, 48, 73], "name": "도해수", "rounds": 103}, {"boss": "ttangul", "cuts": [21, 44, 66], "name": "땅울이", "rounds": 94}],
    "wm": {
      "dohaesu": {"k": "rift4", "name": "틈이 다시 찢기는 밤", "easy": ["current"], "wait": 2, "gap": 3, "tries": 16, "budget": 800, "hand": 0.6},
      "ttangul": {"k": "pulls", "name": "모든 끌개가 도는 날", "easy": ["slide"], "wait": 2, "gap": 3, "final": 3, "tries": 16, "budget": 800, "hand": 0.6}},
    "board": {"hide": true, "hand_mul": 0.6}}$j$::jsonb);
  r := jsonb_set(r, '{ttangul,ultimate}', $j${
    "raw": [34, 3], "raw_n": [0.6, 0.91, 0.8, 0.85], "hp_n": [1, 1.1, 1, 1], "hp_min": 9000,
    "dps": {"ref": {"analyst": 584, "spearman": 525, "exorcist": 495, "formation": 495, "medic": 494, "sealmaster": 494, "scout": 480, "tamer": 480, "bloodknight": 447, "artificer": 422},
      "hp_k": 75, "spec": "Lv55 · 9단계 무기 +10 · 9단계 방어구 한 벌"},
    "board": {"hide": true, "hand_mul": 0.6}}$j$::jsonb);
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
  execute format('create or replace function public.world_ultimate_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$',
    jsonb_set(public.world_ultimate_rules(), '{boards,dohaesu}', $j${"boss": "dohaesu", "name": "무용담 · 도해수", "token": "ug_tok_dohaesu", "token_name": "물때 패", "region": "pd_rift",
      "open_quest": "hwq_15", "level": 55,
      "token_desc": "무용담 「도해수」를 깨고 얻은 물때 패 하나다. 물목과 고임터의 물때가 한 장에 새겨져 있다. 무용담 교환에서 도해록의 물건으로 바꾼다."}$j$::jsonb));
end $$;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size, quality_grade, market_only)
select 'ug_tok_dohaesu', '물때 패', 'material', 5, public.world_ultimate_rules() -> 'boards' -> 'dohaesu' ->> 'token_desc', true, '{}'::jsonb, 1, '{}'::jsonb, false, 0, 50, 0, false
on conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, tradeable = excluded.tradeable;

select pg_temp.yh_patch('public.world_ug_begin_act(uuid,integer)',
  $q$  select count(*), coalesce(sum(coalesce((stats ->> 'hp_atk')::numeric, (stats ->> 'attack')::numeric, 50)), 0) into n, sa from public.world_gw_members where fight_id = p_fight;
  v_hp := round(greatest((br ->> 'hp_min')::numeric, sa * (br ->> 'hp_atk')::numeric) * (br -> 'hp_n' ->> (least(4, greatest(1, n)) - 1))::numeric);$q$,
  $q$  select count(*), coalesce(sum(case when br -> 'dps' -> 'ref' is not null then coalesce((br -> 'dps' -> 'ref' ->> job_key)::numeric, 480)
      else coalesce((stats ->> 'hp_atk')::numeric, (stats ->> 'attack')::numeric, 50) end), 0) into n, sa from public.world_gw_members where fight_id = p_fight;
  v_hp := round(greatest((br ->> 'hp_min')::numeric, sa * coalesce((br -> 'dps' ->> 'hp_k')::numeric, (br ->> 'hp_atk')::numeric)) * (br -> 'hp_n' ->> (least(4, greatest(1, n)) - 1))::numeric);$q$);
select pg_temp.yh_patch('public.world_ug_begin_act(uuid,integer)',
  $q$  elsif act ->> 'boss' = 'baekya' then perform public.world_by_begin(p_fight, n);$q$,
  $q$  elsif act ->> 'boss' = 'baekya' then perform public.world_by_begin(p_fight, n);
  elsif act ->> 'boss' = 'dohaesu' then
    perform public.world_dh_begin(p_fight, n);
    perform public.world_gw_say(p_fight, f.round, 'phase', '이야기꾼의 말로는 물목이 하늘까지 거꾸로 솟았다고 한다. 틈에 낀 도해수가 바다 전체를 끌어안고 버둥댄다.');
  elsif act ->> 'boss' = 'ttangul' then
    perform public.world_du_begin(p_fight, n);
    perform public.world_gw_say(p_fight, f.round, 'phase', '이야기꾼의 말로는 고임터 바닥이 통째로 울었다고 한다. 땅울이가 돌판 한가운데서 솟아오른다.');$q$);

select pg_temp.yh_patch('public.world_ug_begin_act(uuid,integer)',
  $q$  update public.world_gw_fights set board = board || jsonb_build_object('ug', ug) where fight_id = p_fight;$q$,
  $q$  update public.world_gw_fights set board = board || jsonb_build_object('ug', ug)
    || case when act ->> 'boss' in ('dohaesu', 'ttangul') and jsonb_array_length(coalesce(f.board -> 'fell', '[]'::jsonb)) > 0 then jsonb_build_object('fell', f.board -> 'fell') else '{}'::jsonb end where fight_id = p_fight;$q$);

select pg_temp.yh_patch('public.world_ug_round(uuid)',
  $q$  elsif f.boss_id = 'baekya' then perform public.world_ug_by_round(p_fight);$q$,
  $q$  elsif f.boss_id = 'baekya' then perform public.world_ug_by_round(p_fight);
  elsif f.boss_id = 'dohaesu' then perform public.world_dh_round(p_fight);
  elsif f.boss_id = 'ttangul' then perform public.world_du_round(p_fight);$q$);

select pg_temp.yh_patch('public.world_ug_view(uuid,uuid)',
  $q$  elsif f.boss_id = 'baekya' then
    v := public.world_by_view(p_fight, p_uid) - 'dmg_mul' - 'hurt_mul';$q$,
  $q$  elsif f.boss_id = 'baekya' then
    v := public.world_by_view(p_fight, p_uid) - 'dmg_mul' - 'hurt_mul';
  elsif f.boss_id = 'dohaesu' then
    v := public.world_dh_view(p_fight, p_uid) - 'cut';
  elsif f.boss_id = 'ttangul' then
    v := public.world_du_view(p_fight, p_uid) - 'cut';$q$);

create or replace function public.world_ug_wm_kind(p_boss text)
 returns text language sql immutable set search_path = ''
as $f$ select case p_boss when 'sealed_lord' then 'ux' when 'gwiheo' then 'ux' when 'mukjeok' then 'mk' when 'gapgwi' then 'gg' when 'baekya' then 'by' when 'dohaesu' then 'dh' when 'ttangul' then 'du' end $f$;

create or replace function public.world_ug_nbm(p_kind text)
 returns int[] language plpgsql immutable set search_path = pg_catalog, public
as $f$
declare r int[] := '{}'; c int; m int; z int;
begin
  for c in 1 .. case p_kind when 'gg' then 15 when 'ux' then 18 when 'mk' then 9 when 'dh' then 16 when 'du' then 19 else 14 end loop
    m := 1 << (c - 1);
    foreach z in array case p_kind when 'gg' then public.world_gg_nb(c) when 'ux' then public.world_ux_nb(c)
        when 'mk' then array(select jsonb_array_elements_text(public.world_mk_lines() -> 'nb' -> c::text)::int)
        when 'dh' then public.world_dh_nb(c) when 'du' then public.world_du_nb(c) else public.world_by_nb(c) end loop m := m | (1 << (z - 1)); end loop;
    r := r || m;
  end loop;
  return r;
end $f$;

select pg_temp.yh_patch('public.world_ug_hz_cons(uuid,jsonb,integer)',
  $q$    elsif kd = 'mk' and h ->> 'k' = 'mimic' then$q$,
  $q$    elsif kd in ('dh', 'du') and h ->> 'k' in ('spray', 'weight', 'boulder') then
      out := out || jsonb_build_array(jsonb_build_object('t', 'avoid', 'r', r, 'cells', coalesce(h -> 'cells', '[]'::jsonb)));
    elsif kd = 'mk' and h ->> 'k' = 'mimic' then$q$);

select pg_temp.yh_patch('public.world_ug_wm_start(uuid,integer)',
  $q$        return wm || jsonb_build_object('cons', cons, 'end', (wm ->> 'dl')::int + coalesce((cfg ->> 'arrow_left')::int, 2));
      end if;
    end if;$q$,
  $q$        return wm || jsonb_build_object('cons', cons, 'end', (wm ->> 'dl')::int + coalesce((cfg ->> 'arrow_left')::int, 2));
      end if;
    elsif cfg ->> 'k' = 'rift4' then
      ord := array(select z from unnest(array[1, 4, 13, 16]) z order by random());
      rk := '{}';
      for i in 1 .. 4 loop
        k := p_nr + coalesce((cfg ->> 'wait')::int, 2) + (i - 1) * coalesce((cfg ->> 'gap')::int, 3); rk := rk || k;
        cons := cons || jsonb_build_array(jsonb_build_object('t', 'need', 'r', k, 'cells', jsonb_build_array(ord[i]), 'n', 1, 'a', 'guide'));
      end loop;
      ok := public.world_ug_wm_solve(p_fight, public.world_ug_mem(p_fight), p_nr, '[]'::jsonb, cons);
      if ok is not null then
        return jsonb_build_object('k', 'rift4', 'status', 'on', 'start', p_nr, 'ord', to_jsonb(ord), 'steps', to_jsonb(rk), 'cons', cons, 'end', rk[4]);
      end if;
    elsif cfg ->> 'k' = 'pulls' then
      ord := array(select z from unnest(array(select (jsonb_array_elements_text(public.world_boss_fight_rules(p_fight) -> 'board' -> 'pulls'))::int)) z order by random());
      rk := '{}'; own := '{}';
      for i in 1 .. cardinality(ord) loop
        k := p_nr + coalesce((cfg ->> 'wait')::int, 2) + (i - 1) * coalesce((cfg ->> 'gap')::int, 3); rk := rk || k;
        own := own || jsonb_build_object(ord[i]::text, alive[1 + (i - 1) % na]::text);
        cons := cons || jsonb_build_array(jsonb_build_object('t', 'goal', 'r', k, 'who', alive[1 + (i - 1) % na]::text, 'cells', jsonb_build_array(ord[i])),
          jsonb_build_object('t', 'act', 'r', k, 'who', alive[1 + (i - 1) % na]::text, 'a', 'stop'));
      end loop;
      for i in 1 .. coalesce((cfg ->> 'final')::int, 3) loop
        for c in 1 .. na loop
          cons := cons || jsonb_build_array(jsonb_build_object('t', 'act', 'r', rk[cardinality(rk)] + i, 'who', alive[c]::text, 'a', 'brace'));
        end loop;
      end loop;
      ok := public.world_ug_wm_solve(p_fight, public.world_ug_mem(p_fight), p_nr, '[]'::jsonb, cons);
      if ok is not null then
        return jsonb_build_object('k', 'pulls', 'status', 'on', 'start', p_nr, 'ord', to_jsonb(ord), 'own', own, 'steps', to_jsonb(rk), 'cons', cons,
          'final', coalesce((cfg ->> 'final')::int, 3), 'end', rk[cardinality(rk)] + coalesce((cfg ->> 'final')::int, 3));
      end if;
    end if;$q$);

select pg_temp.yh_patch('public.world_ug_wm_pre(uuid,integer)',
  $q$  elsif wm ->> 'k' = 'dongji' then
    b := b || jsonb_build_object('lamps', '[]'::jsonb);
  end if;$q$,
  $q$  elsif wm ->> 'k' = 'dongji' then
    b := b || jsonb_build_object('lamps', '[]'::jsonb);
  elsif wm ->> 'k' = 'pulls' then
    update public.world_gw_members set gval = 1 where fight_id = p_fight and out_rounds = 0 and not rest;
    b := b || jsonb_build_object('wedges', '[]'::jsonb, 'final', 0, 'hid', coalesce((b ->> 'hid')::int, 0) + jsonb_array_length(wm -> 'ord'),
      'pulls', (select jsonb_object_agg(z, 0) from jsonb_array_elements_text(wm -> 'ord') z),
      'hz', (select jsonb_agg(jsonb_build_object('id', coalesce((b ->> 'hid')::int, 0) + o, 'k', 'pull', 'c', (z)::int, 'left', (wm -> 'steps' ->> (o - 1)::int)::int - p_nr + 1, 'wm', true))
        from jsonb_array_elements_text(wm -> 'ord') with ordinality q(z, o)));
  end if;$q$);
select pg_temp.yh_patch('public.world_ug_wm_pre(uuid,integer)',
  $q$    when 'close' then '장 마감 종이 울린다. 모두의 값이 새로 매겨지고, 흰 좌판 위에 맞춰야 할 값이 적힌다.'$q$,
  $q$    when 'close' then '장 마감 종이 울린다. 모두의 값이 새로 매겨지고, 흰 좌판 위에 맞춰야 할 값이 적힌다.'
    when 'rift4' then '틈이 다시 찢긴다. 도해수가 바다 전체를 틈으로 끌어당기고, 모서리 네 칸에 번호가 잠깐 떠올랐다 꺼진다.'
    when 'pulls' then '고임터의 끌개 넷이 한꺼번에 돌기 시작한다. 땅울이가 쐐기돌을 흩뿌리고, 저마다 멈출 끌개가 정해진다.'$q$);

select pg_temp.yh_patch('public.world_ug_wm_check(uuid,integer)',
  $q$    update public.world_gw_fights set board = jsonb_set(board, '{wm}', wm) where fight_id = p_fight;
  end if;
  return false;$q$,
  $q$    update public.world_gw_fights set board = jsonb_set(board, '{wm}', wm) where fight_id = p_fight;
  elsif wm ->> 'k' = 'rift4' and wm -> 'steps' @> to_jsonb(p_round) then
    k := (select o from jsonb_array_elements_text(wm -> 'steps') with ordinality s(z, o) where z::int = p_round limit 1)::int;
    c := (wm -> 'ord' ->> (k - 1))::int;
    if exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'guide' and (case when public.world_gw_pushed_at(p_fight, owner_id) = p_round and prev is not null then prev::int else pos end) in (1, 4, 13, 16) and (case when public.world_gw_pushed_at(p_fight, owner_id) = p_round and prev is not null then prev::int else pos end) <> c) then
      return public.world_ug_wm_fail(p_fight, p_round, '차례가 아닌 모서리에서 길을 알려 주었다고 한다'); end if;
    if not exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'guide' and (case when public.world_gw_pushed_at(p_fight, owner_id) = p_round and prev is not null then prev::int else pos end) = c) then
      return public.world_ug_wm_fail(p_fight, p_round, k || '번째 모서리에서 제때 길을 알려 주지 못했다고 한다'); end if;
    perform public.world_gw_say(p_fight, p_round, 'good', c || '번 모서리에서 길을 알려 주었습니다(' || k || '/4).');
    if k = jsonb_array_length(wm -> 'steps') then
      perform public.world_gw_say(p_fight, p_round, 'good', '찢기던 틈이 다시 닫힙니다. 도해수가 바다 쪽으로 몸을 돌립니다.');
      update public.world_gw_fights set board = jsonb_set(board, '{wm,status}', '"done"') where fight_id = p_fight;
    end if;
  elsif wm ->> 'k' = 'pulls' and wm -> 'steps' @> to_jsonb(p_round) then
    k := (select o from jsonb_array_elements_text(wm -> 'steps') with ordinality s(z, o) where z::int = p_round limit 1)::int;
    c := (wm -> 'ord' ->> (k - 1))::int;
    own := (wm -> 'own' ->> c::text)::uuid;
    if coalesce((f.board -> 'pulls' ->> c::text)::int, 0) <= p_round or not exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.out_rounds = 0 and not y.rest
        and y.act ->> 'a' = 'stop' and (case when public.world_gw_pushed_at(p_fight, y.owner_id) = p_round and y.prev is not null then y.prev::int else y.pos end) = c
        and (y.owner_id = own or not exists (select 1 from public.world_gw_members z where z.fight_id = p_fight and z.owner_id = own and z.out_rounds = 0 and not z.rest))) then
      return public.world_ug_wm_fail(p_fight, p_round, k || '번째 끌개를 맡은 이가 제때 멈추지 못했다고 한다'); end if;
    perform public.world_gw_say(p_fight, p_round, 'good', c || '번 끌개를 멈췄습니다(' || k || '/' || jsonb_array_length(wm -> 'steps') || ').');
    update public.world_gw_members set gval = 1 where fight_id = p_fight and out_rounds = 0 and not rest;
    if k = jsonb_array_length(wm -> 'steps') then
      perform public.world_gw_say(p_fight, p_round, 'boss', '끌개가 모두 멈추자 땅울이가 마지막으로 몸부림친다. 돌판이 크게 기운다!');
      update public.world_gw_fights set board = board || jsonb_build_object('final', (wm ->> 'final')::int) where fight_id = p_fight;
    end if;
  elsif wm ->> 'k' = 'pulls' and p_round > (wm -> 'steps' ->> (jsonb_array_length(wm -> 'steps') - 1))::int and p_round <= (wm ->> 'end')::int then
    if exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and coalesce(act ->> 'a', 'guard') <> 'brace') then
      return public.world_ug_wm_fail(p_fight, p_round, '마지막 몸부림에 버티지 않은 이가 있었다고 한다'); end if;
    perform public.world_gw_say(p_fight, p_round, 'good', '모두 버텨 냈습니다(' || (p_round - (wm -> 'steps' ->> (jsonb_array_length(wm -> 'steps') - 1))::int) || '/' || (wm ->> 'final') || ').');
    if p_round = (wm ->> 'end')::int then
      perform public.world_gw_say(p_fight, p_round, 'good', '고임터의 울음이 잦아듭니다. 끌개가 모두 제자리에 멈췄습니다.');
      update public.world_gw_fights set board = jsonb_set(board, '{wm,status}', '"done"') where fight_id = p_fight;
    end if;
  end if;
  return false;$q$);

select pg_temp.yh_patch('public.world_ug_wm_view(uuid,uuid)',
  $q$  elsif wm ->> 'k' = 'dongji' then$q$,
  $q$  elsif wm ->> 'k' = 'rift4' then
    k := (select o from jsonb_array_elements_text(wm -> 'steps') with ordinality s(z, o) where z::int = f.round limit 1)::int;
    v := v || jsonb_build_object('due', k is not null, 'step', coalesce(k, (select count(*) from jsonb_array_elements_text(wm -> 'steps') z where z::int < f.round)::int),
      'steps', jsonb_array_length(wm -> 'steps'), 'left', greatest(0, (wm -> 'steps' ->> 0)::int - f.round))
      || case when i = 0 then jsonb_build_object('order', (select jsonb_object_agg(z, o) from jsonb_array_elements_text(wm -> 'ord') with ordinality q(z, o))) else '{}'::jsonb end;
  elsif wm ->> 'k' = 'pulls' then
    k := (select o from jsonb_array_elements_text(wm -> 'steps') with ordinality s(z, o) where z::int = f.round limit 1)::int;
    v := v || jsonb_build_object('mine', (select coalesce(jsonb_agg(jsonb_build_object('c', z::int, 'n', o)), '[]'::jsonb) from jsonb_array_elements_text(wm -> 'ord') with ordinality q(z, o)
        where wm -> 'own' ->> z = p_uid::text), 'due', k is not null or f.round > (wm -> 'steps' ->> (jsonb_array_length(wm -> 'steps') - 1))::int,
      'final', greatest(0, (wm ->> 'end')::int - greatest(f.round - 1, (wm -> 'steps' ->> (jsonb_array_length(wm -> 'steps') - 1))::int)),
      'brace', f.round > (wm -> 'steps' ->> (jsonb_array_length(wm -> 'steps') - 1))::int);
  elsif wm ->> 'k' = 'dongji' then$q$);

select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $q$    if c.level < (public.world_ultimate_rules() ->> 'level')::int then raise exception '무용담은 Lv% 이상만 들어갈 수 있습니다.', (public.world_ultimate_rules() ->> 'level')::int; end if;$q$,
  $q$    if c.level < coalesce((public.world_ultimate_rules() -> 'boards' -> p_boss ->> 'level')::int, (public.world_ultimate_rules() ->> 'level')::int) then
      raise exception '무용담은 Lv% 이상만 들어갈 수 있습니다.', coalesce((public.world_ultimate_rules() -> 'boards' -> p_boss ->> 'level')::int, (public.world_ultimate_rules() ->> 'level')::int); end if;$q$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $q$    if p_boss = 'gapgwi' and not exists$q$,
  $q$    if p_boss = 'dohaesu' and not exists (select 1 from public.world_gw_records r where r.owner_id = p_uid and r.boss_id = 'ttangul' and r.kills > 0) then
      raise exception '땅울이 「%」도 한 번 이상 깨야 %에 들어갈 수 있습니다.', public.world_boss_rules() -> 'ttangul' -> 'modes' ->> 'hard', public.world_ultimate_rules() -> 'boards' -> 'dohaesu' ->> 'name'; end if;
    if p_boss = 'gapgwi' and not exists$q$);
