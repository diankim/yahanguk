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
  "quest": "mdq_15", "quest_name": "명등기 15장", "item": "pact_stone_dust", "item_name": "맹약 돌가루", "item_where": "맹약 마당에서 채집해 얻습니다.",
  "min": 18, "hp_min": 9000, "hp_atk": 46, "hp_n": [1.0, 1.25, 0.8, 1.15], "raw_n": [0.85, 0.95, 0.8, 0.85], "raw": [44, 4], "enrage": 0.15,
  "first": {"gil": 2500, "xp": 0.5}, "again": {"gil": 150, "xp": 0.05}, "fail": {"dur": 10, "er": 10, "cd": 30}, "falls": 10, "xp_cap_lv": 50,
  "hard_quest": "mdq_17", "hard_quest_name": "명등기 17장",
  "modes": {"story": "이야기판", "hard": "깊은 흰 밤"},
  "phases": ["거둠", "소등", "긁힌 칸", "흰 밤"],
  "story": {"min": 30, "round_s": 60, "hp_min": 2400, "hp_atk": 26, "hp_n": [1, 1, 1, 1], "raw": [12, 2], "first": {"gil": 1000},
    "board": {"mark_steps": 5, "mark_gone": false, "solo_erase": 1, "dim_lead": 3, "scratch": false, "wn_need": 4, "wn_need_solo": 4, "wn_rounds": 0}},
  "board": {
    "seats": 7, "center_pres": 0, "dmg_lo": 0.55, "dmg_k": 0.45, "hurt_hi": 1.3, "hurt_k": 0.3,
    "mark_every": 4, "mark_every_solo": 6, "mark_steps": 3, "mark_hurt_pct": 20, "mark_mute": 2, "mark_gone": true, "solo_erase": 2,
    "dim_every": [3, 2, 2, 1], "dim_lead": 2, "relight": 2,
    "scratch": true, "scratch_coop_pct": 37.5, "unblock_max": 2, "solo_unblock": 3,
    "wn_need": 7, "wn_need_solo": 5, "wn_rounds": [12, 10, 8, 8], "wn_heard": 1, "wn_fail_hp": 40, "wn_fails": 1,
    "aoe_every": 4, "low_pct": 10,
    "voices": ["남명이 부른다. 내 백성은 내가 부른다.", "북령이 부른다. 다시는, 이 아니라 이번에는.", "적월이 부른다. 값이 아니라 이름으로.",
      "수향이 부른다. 태우지 못한 아이들을, 한 이름씩.", "천명이 부른다. 별이 아니라 사람이 정한다.", "정청이 부른다. 고친 보고서 대신, 거둬 간 동료의 이름을.",
      "흑련이 부른다. 맡아 둔 이름을 돌려준다. — 아이 목소리가 들렸다. 「서율 오라버니!」"]},
  "solo": {"artificer": {"solo_dmg": -35, "solo_guard": 20}, "scout": {"solo_dmg": -15, "solo_guard": 45}, "exorcist": {"solo_dmg": -36, "solo_guard": 20},
    "medic": {"solo_dmg": -10, "solo_guard": 20}, "sealmaster": {"solo_dmg": -15, "solo_guard": 25}, "analyst": {"solo_dmg": -25, "solo_guard": 35},
    "tamer": {"solo_dmg": -25, "solo_guard": 35}}
}$j$::jsonb));
end $$;

create or replace function public.world_by_nb(p_seat integer)
 returns integer[] language sql immutable set search_path = ''
as $f$ select case when p_seat is null then '{}'::int[] else array[((p_seat + 5) % 7) + 1, (p_seat % 7) + 1] end $f$;

create or replace function public.world_by_lamps(p_board jsonb)
 returns integer language sql immutable set search_path = ''
as $f$ select coalesce(jsonb_array_length(p_board -> 'lamps'), 0) $f$;

create or replace function public.world_by_hurt_mul(p_fight uuid, p_uid uuid)
 returns numeric language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; b jsonb;
begin
  select board into b from public.world_gw_fights where fight_id = p_fight;
  return ((rb ->> 'hurt_hi')::numeric - (rb ->> 'hurt_k')::numeric * public.world_by_lamps(b) / 7.0)
    * case when coalesce(b -> 'marks', '{}'::jsonb) ? p_uid::text then 1 + (rb ->> 'mark_hurt_pct')::numeric / 100.0 else 1 end;
end $f$;

create or replace function public.world_by_on_attack(p_fight uuid, p_uid uuid, p_round integer)
 returns numeric language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; b jsonb;
begin
  select board into b from public.world_gw_fights where fight_id = p_fight;
  return (rb ->> 'dmg_lo')::numeric + (rb ->> 'dmg_k')::numeric * public.world_by_lamps(b) / 7.0;
end $f$;

create or replace function public.world_by_begin(p_fight uuid, p_n integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare x record; k int := 0;
begin
  for x in select owner_id from public.world_gw_members where fight_id = p_fight order by joined_at, owner_id loop
    update public.world_gw_members set pos = 1 + floor(k * 7.0 / greatest(1, p_n))::int, prev = null where fight_id = p_fight and owner_id = x.owner_id;
    k := k + 1;
  end loop;
  update public.world_gw_fights set board = jsonb_build_object('lamps', '[1, 2, 3, 4, 5, 6, 7]'::jsonb, 'called', '{}'::jsonb, 'marks', '{}'::jsonb, 'dims', '[]'::jsonb,
    'kindle', '{}'::jsonb, 'block', '[]'::jsonb, 'scr', '{}'::jsonb, 'unb', 0, 'solo_calls', 0, 'wn_fail', 0, 'low', false) where fight_id = p_fight;
  perform public.world_gw_say(p_fight, 0, 'phase', '경현이 먹 도랑에 두 손을 담근다. 도랑의 먹물이 부르르 떨며 손을 타고 거꾸로 기어올라 하얗게 바래며 온몸을 덮는다. 정리관 옷 모양 그대로인 하얀 형체 위로 이름 글자가 개미 떼처럼 기어 다닌다.');
  perform public.world_gw_say(p_fight, 0, 'phase', '입을 열자 노인과 아이와 여자의 목소리가 겹쳐 나온다. 「당신 이름 하나만 거두면, 해제는 영영 없소.」 손에 든 붓끝이 붉다. 마당을 둘러싼 일곱 자리의 등롱이 아직은 모두 켜져 있다.');
  perform public.world_gw_say(p_fight, 0, 'phase', case when p_n = 1 then '불러 줄 이가 없다. 붉은 줄이 오면 제 이름을 제 입으로 외워야 한다.'
    else '서하람: 돌아가며 불러요! 아무도 오래 안 불린 채로 두면 안 돼요. 시간표처럼요!' end);
end $f$;

create or replace function public.world_by_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb; b jsonb; nr int; ph int; m jsonb; tell text := ''; aoe boolean := false;
  n int; na int; t uuid; tname text; c int; at int; lamps int[]; dims jsonb; len int := 5; story boolean; need int; rounds int; d jsonb; resolving boolean := false;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  rb := br -> 'board'; b := coalesce(f.board, '{}'::jsonb); nr := f.round + 1; story := f.mode = 'story';
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  select count(*) into na from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and not fx ? 'gone';
  if ph <> f.phase then
    perform public.world_gw_say(p_fight, nr, 'phase', case ph
      when 1 then '하얀 몸이 다시 일어선다. 붉은 붓이 이름 위를 더듬는다.'
      when 2 then '경현의 흰 소매가 길게 늘어진다. 소매 끝이 등롱 하나하나를 더듬는다. 「불이 없으면 부를 까닭도 없소.」'
      when 3 then '하얀 몸 위의 글자들이 서로 엉켜 칸을 긁는다. 무언가 손에 쥐던 것이 미끄러진다.'
      else '겹친 목소리가 비명을 지른다. 일곱 등이 한꺼번에 꺼지고 마당이 새하얗게 바랜다. 바로 옆 사람의 이름이 떠오르지 않는다. 몸에 써 둔 이름을 읽어야 한다.' end);
    f.cycle := 0;
  end if;
  if ph = 4 and not b ? 'wn' then
    need := case when n = 1 then (rb ->> 'wn_need_solo')::int else (rb ->> 'wn_need')::int end;
    rounds := case when jsonb_typeof(rb -> 'wn_rounds') = 'array' then (rb -> 'wn_rounds' ->> (least(4, greatest(1, n)) - 1))::int else (rb ->> 'wn_rounds')::int end;
    b := b || jsonb_build_object('wn', jsonb_build_object('start', nr, 'hp', f.hp, 'need', need, 'lit', 0, 'at', case when rounds > 0 then nr + rounds - 1 end),
      'lamps', '[]'::jsonb, 'dims', '[]'::jsonb, 'kindle', '{}'::jsonb);
    perform public.world_gw_say(p_fight, nr, 'warn', '흰 밤 — 이웃 자리에 선 사람만 부를 수 있습니다. 불린 사람이 제 자리에서 「등 켜기」를 하면 등이 켜지며 백야의 몸에서 이름이 하나씩 떨어집니다. 등 '
      || need || '개를 켜면 이깁니다' || case when rounds > 0 then '(' || rounds || '라운드 안에).' else '.' end);
  end if;
  if ph >= 3 then
    if not coalesce(b -> 'scr', '{}'::jsonb) ? 'item' then
      b := b || jsonb_build_object('scr', coalesce(b -> 'scr', '{}'::jsonb) || '{"item": true}'::jsonb);
      if coalesce((rb ->> 'scratch')::boolean, false) then
        b := b || jsonb_build_object('block', coalesce(b -> 'block', '[]'::jsonb) || '["item"]'::jsonb);
        perform public.world_gw_say(p_fight, nr, 'bad', '긁힌 칸 — 물품 칸이 하얗게 긁혀 막혔습니다. 모두가 같은 라운드에 서로를 부르면 풀립니다' || case when n = 1 then '(혼자면 제 이름 외기를 ' || (rb ->> 'solo_unblock') || '번).' else '.' end);
      else
        perform public.world_gw_say(p_fight, nr, 'info', '서하람: 방금 물품 칸이 긁힐 뻔했어요! 저게 막히면 서로를 한꺼번에 불러야 풀려요.');
      end if;
    end if;
    if not coalesce(b -> 'scr', '{}'::jsonb) ? 'coop' and f.hp * 100 < f.max_hp * (rb ->> 'scratch_coop_pct')::numeric then
      b := b || jsonb_build_object('scr', coalesce(b -> 'scr', '{}'::jsonb) || '{"coop": true}'::jsonb);
      if coalesce((rb ->> 'scratch')::boolean, false) then
        b := b || jsonb_build_object('block', coalesce(b -> 'block', '[]'::jsonb) || '["coop"]'::jsonb);
        perform public.world_gw_say(p_fight, nr, 'bad', '긁힌 칸 — 협동 기술 칸이 긁혀 막혔습니다.');
      else
        perform public.world_gw_say(p_fight, nr, 'info', '서하람: 이번엔 협동 기술 칸이 긁힐 뻔했어요.');
      end if;
    end if;
  end if;
  if na > 0 and nr % (case when n = 1 then coalesce((rb ->> 'mark_every_solo')::int, (rb ->> 'mark_every')::int) else (rb ->> 'mark_every')::int end) = 0 and not b ? 'wn' then
    select x.owner_id, x.name into t, tname from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest and not x.fx ? 'gone'
       and not (coalesce(b -> 'marks', '{}'::jsonb) ? x.owner_id::text)
     order by coalesce((b -> 'called' ->> x.owner_id::text)::int, -1), random() limit 1;
    if t is not null then
      b := b || jsonb_build_object('marks', coalesce(b -> 'marks', '{}'::jsonb) || jsonb_build_object(t::text, jsonb_build_object('s', 1, 'st', 0, 'at', nr)));
      tell := '붉은 붓이 ' || tname || '의 이름 위에 붉은 줄을 긋는다. 그림자가 옅어진다. ' || case when n = 1 then '버티기나 제 이름 외기를 두 라운드 잇달아 하면 지워진다.'
        else '누군가 그 이름을 불러 주어야 한다 — 둘이 함께 부르면 줄이 지워진다.' end;
    end if;
  end if;
  if coalesce(b -> 'marks', '{}'::jsonb) <> '{}'::jsonb and tell = '' then
    tell := (select string_agg(x.name || ' (' || (b -> 'marks' -> x.owner_id::text ->> 's') || '/' || (rb ->> 'mark_steps') || ')', ', ')
      from public.world_gw_members x where x.fight_id = p_fight and b -> 'marks' ? x.owner_id::text) || ' — 붉은 줄이 번지고 있다. 이름을 불러 주어라.';
  end if;
  dims := coalesce(b -> 'dims', '[]'::jsonb);
  if ph in (2, 3) and na > 0 and f.cycle % (rb -> 'dim_every' ->> (least(4, greatest(1, n)) - 1))::int = 0 then
    lamps := array(select jsonb_array_elements_text(coalesce(b -> 'lamps', '[]'::jsonb))::int);
    select z into c from unnest(lamps) z where not exists (select 1 from jsonb_array_elements(dims) e where (e ->> 'c')::int = z) order by random() limit 1;
    if c is not null then
      at := nr + (rb ->> 'dim_lead')::int - 1;
      dims := dims || jsonb_build_array(jsonb_build_object('c', c, 'at', at));
      tell := tell || case when tell <> '' then ' ' else '' end || c || '번 자리 등롱이 파르르 깜빡인다. 흰 소매가 ' || (at - nr + 1) || '라운드 뒤 그 등을 덮으려 한다 — 그 자리에 서서 막아라.';
    end if;
  end if;
  for d in select * from jsonb_array_elements(dims) loop
    if (d ->> 'at')::int = nr then
      resolving := true;
      tell := tell || case when tell <> '' then ' ' else '' end || '흰 소매가 ' || (d ->> 'c') || '번 자리 등롱 위로 내려온다!';
    end if;
  end loop;
  b := b || jsonb_build_object('dims', dims);
  if b ? 'wn' then
    tell := tell || case when tell <> '' then ' ' else '' end || '흰 밤 — 켠 등 ' || (b -> 'wn' ->> 'lit') || '/' || (b -> 'wn' ->> 'need')
      || case when b -> 'wn' ->> 'at' is not null then ' · ' || ((b -> 'wn' ->> 'at')::int - nr + 1) || '라운드 남음' else '' end || '. 이웃을 부르고 등을 켜라.';
  elsif nr % (rb ->> 'aoe_every')::int = 0 and not resolving then
    aoe := true;
    tell := tell || case when tell <> '' then ' — ' else '' end || '흰 소매가 마당 위로 크게 펼쳐진다. 한꺼번에 휩쓸 것 같다. 몰려올 것에 대비하라.';
  end if;
  if tell = '' then tell := '사르륵사르륵, 하얀 몸 위로 이름 글자들이 종이 넘기는 소리를 낸다.'; end if;
  m := jsonb_build_object('k', 'normal', 'phase_name', br -> 'phases' ->> (ph - 1), 'aoe', aoe, 'tell', tell, 'lamps', public.world_by_lamps(b),
    'marks', (select coalesce(jsonb_agg(jsonb_build_object('t', k, 's', (v ->> 's')::int, 'steps', (rb ->> 'mark_steps')::int)), '[]'::jsonb) from jsonb_each(coalesce(b -> 'marks', '{}'::jsonb)) e(k, v)),
    'dims', (select coalesce(jsonb_agg(jsonb_build_object('c', (e ->> 'c')::int, 'at', (e ->> 'at')::int, 'left', (e ->> 'at')::int - nr)), '[]'::jsonb) from jsonb_array_elements(dims) e),
    'block', coalesce(b -> 'block', '[]'::jsonb)) || case when b ? 'wn' then jsonb_build_object('wn', b -> 'wn') else '{}'::jsonb end;
  if resolving or b ? 'wn' or coalesce(b -> 'marks', '{}'::jsonb) <> '{}'::jsonb then len := 10; end if;
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when not story then len when n = 1 then 86400 else (br ->> 'round_s')::int end), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, nr, case when aoe or resolving or tell like '%붉은 줄을 긋는다%' or tell like '%깜빡인다%' then 'warn' else 'tell' end, tell);
end $f$;

create or replace function public.world_by_steps(p_fight uuid, p_round integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare x record; t int;
begin
  for x in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and not fx ? 'gone' and act ? 'm' order by joined_at, owner_id loop
    t := (x.act ->> 'm')::int;
    if t = any (public.world_by_nb(x.pos)) then
      update public.world_gw_members set pos = t where fight_id = p_fight and owner_id = x.owner_id;
    end if;
  end loop;
end $f$;

create or replace function public.world_by_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; b jsonb; n int; solo boolean; w record; tg record;
  calls jsonb := '{}'; callers uuid[] := '{}'; marks jsonb; mk jsonb; k int; s int; st int; extra numeric := 0; lamps int[]; dims jsonb; keep jsonb := '[]'; d jsonb;
  prot text; kindle jsonb; lit_n int; wn jsonb; heard boolean; cnt int; alive uuid[]; seat int; self_calls int := 0; nm text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  solo := n = 1;
  marks := coalesce(b -> 'marks', '{}'::jsonb);
  lamps := array(select jsonb_array_elements_text(coalesce(b -> 'lamps', '[]'::jsonb))::int);
  kindle := coalesce(b -> 'kindle', '{}'::jsonb);
  wn := b -> 'wn';
  select coalesce(array_agg(owner_id), '{}') into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and not fx ? 'gone';
  solo := solo or (select count(*) from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not fx ? 'gone') <= 1;
  for w in select x.* from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = any (alive) and x.act ->> 'a' = 'call' order by x.joined_at, x.owner_id loop
    select * into tg from public.world_gw_members where fight_id = p_fight and owner_id = nullif(w.act ->> 't', '')::uuid;
    if tg.owner_id is null or tg.fx ? 'gone' then continue; end if;
    if solo and tg.owner_id <> w.owner_id then continue; end if;
    if not solo and tg.owner_id = w.owner_id then continue; end if;
    if not solo and coalesce((marks -> w.owner_id::text ->> 's')::int, 0) >= (rb ->> 'mark_mute')::int then
      perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — 붉은 줄에 목소리가 끊겨 이름이 나오지 않습니다.'); continue;
    end if;
    if wn is not null and not solo and not (tg.pos = any (public.world_by_nb(w.pos))) then
      perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — 흰 밤이라 소리가 ' || tg.name || '에게 닿지 않습니다(바로 옆자리만).'); continue;
    end if;
    calls := calls || jsonb_build_object(tg.owner_id::text, coalesce((calls ->> tg.owner_id::text)::int, 0) + 1);
    callers := callers || w.owner_id;
    if solo then self_calls := self_calls + 1; end if;
    b := b || jsonb_build_object('called', coalesce(b -> 'called', '{}'::jsonb) || jsonb_build_object(tg.owner_id::text, p_round));
    perform public.world_gw_say(p_fight, p_round, 'good', case when solo then w.name || ' — 제 이름을 제 입으로 또박또박 외웁니다.'
      else w.name || ' — 「' || tg.name || '!」 이름을 불러 줍니다.' end);
  end loop;
  for mk in select jsonb_build_object('k', key, 'v', value) from jsonb_each(marks) loop
    k := coalesce((calls ->> (mk ->> 'k'))::int, 0); s := (mk -> 'v' ->> 's')::int; st := coalesce((mk -> 'v' ->> 'st')::int, 0);
    select name into nm from public.world_gw_members where fight_id = p_fight and owner_id = (mk ->> 'k')::uuid;
    if solo then
      if k > 0 or exists (select 1 from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = (mk ->> 'k')::uuid and x.act ->> 'a' = 'brace') then st := st + 1; else st := 0; s := s + 1; end if;
      if st >= (rb ->> 'solo_erase')::int then
        marks := marks - (mk ->> 'k');
        perform public.world_gw_say(p_fight, p_round, 'good', nm || ' — 제 이름을 끝까지 외워 붉은 줄을 지웠습니다.'); continue;
      end if;
    else
      if k >= 2 then s := 0; elsif k = 1 then s := s - 1; else s := s + 1; end if;
      if s <= 0 then
        marks := marks - (mk ->> 'k');
        perform public.world_gw_say(p_fight, p_round, 'good', '부르는 소리에 ' || nm || '의 붉은 줄이 지워졌습니다.'); continue;
      end if;
    end if;
    if s > (rb ->> 'mark_steps')::int then
      marks := marks - (mk ->> 'k');
      if coalesce((rb ->> 'mark_gone')::boolean, false) then
        update public.world_gw_members set fx = fx || '{"gone": true}'::jsonb, out_rounds = 999, rest = false, hp = 0, falls = falls + 1 where fight_id = p_fight and owner_id = (mk ->> 'k')::uuid;
        perform public.world_gw_say(p_fight, p_round, 'fall', nm || ' — 아무도 이름을 불러 주지 않아 먹으로 풀렸습니다. 이 싸움에서 빠집니다.');
      else
        perform public.world_gw_hurt(p_fight, (mk ->> 'k')::uuid, 999, p_round, '붉은 줄이 끝까지 번져');
      end if;
    else
      marks := marks || jsonb_build_object(mk ->> 'k', (mk -> 'v') || jsonb_build_object('s', s, 'st', st));
      if s >= (rb ->> 'mark_mute')::int and not solo then
        perform public.world_gw_say(p_fight, p_round, 'bad', nm || '의 목소리가 끊겼습니다(붉은 줄 ' || s || '/' || (rb ->> 'mark_steps') || '). 협동 기술·부르기를 쓸 수 없습니다.');
      end if;
    end if;
  end loop;
  dims := coalesce(b -> 'dims', '[]'::jsonb);
  for d in select * from jsonb_array_elements(dims) loop
    if (d ->> 'at')::int <= p_round then
      select string_agg(x.name, ', ') into prot from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = any (alive) and x.pos = (d ->> 'c')::int
         and coalesce(x.act ->> 'a', 'guard') in ('guard', 'brace');
      if prot is not null then
        perform public.world_gw_say(p_fight, p_round, 'good', prot || ' — ' || (d ->> 'c') || '번 자리에서 흰 소매를 몸으로 받아 등을 지켰습니다.');
      elsif (d ->> 'c')::int = any (lamps) then
        lamps := array_remove(lamps, (d ->> 'c')::int);
        perform public.world_gw_say(p_fight, p_round, 'bad', '흰 소매가 ' || (d ->> 'c') || '번 자리 등을 덮었습니다. 등이 꺼집니다(켜진 등 ' || coalesce(array_length(lamps, 1), 0) || ').');
      end if;
    else
      keep := keep || jsonb_build_array(d);
    end if;
  end loop;
  for seat in select distinct x.pos from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = any (alive) and x.act ->> 'a' = 'light' and x.pos is not null loop
    if seat = any (lamps) then
      perform public.world_gw_say(p_fight, p_round, 'miss', seat || '번 자리 등은 이미 켜져 있습니다.'); continue;
    end if;
    if wn is not null then
      for w in select x.* from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = any (alive) and x.act ->> 'a' = 'light' and x.pos = seat order by x.joined_at loop
        heard := coalesce((b -> 'called' ->> w.owner_id::text)::int, -99) >= p_round - (rb ->> 'wn_heard')::int;
        if seat = any (lamps) then exit; end if;
        if not heard then
          perform public.world_gw_say(p_fight, p_round, 'miss', w.name || ' — 아무도 이름을 불러 주지 않아 손이 등롱에 닿지 않습니다.'); continue;
        end if;
        lamps := lamps || seat;
        lit_n := (wn ->> 'lit')::int + 1;
        wn := wn || jsonb_build_object('lit', lit_n);
        perform public.world_gw_say(p_fight, p_round, 'good', w.name || ' — ' || seat || '번 자리 등롱에 손을 얹자 등이 켜집니다. 하얀 몸에서 이름 하나가 떨어져 금빛 가루로 흩어집니다.');
        perform public.world_gw_say(p_fight, p_round, 'voice', coalesce(rb -> 'voices' ->> (lit_n - 1), '누군가 부른다.'));
        if lit_n >= (wn ->> 'need')::int then
          extra := f.hp;
          perform public.world_gw_say(p_fight, p_round, 'good', '등이 모두 켜졌다. 하얀 몸에서 이름이 우수수 떨어진다.');
        else
          extra := extra + round((wn ->> 'hp')::numeric / (wn ->> 'need')::int);
        end if;
      end loop;
    else
      select count(*) into cnt from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = any (alive) and x.act ->> 'a' = 'light' and x.pos = seat;
      k := coalesce((kindle ->> seat::text)::int, 0) + cnt;
      if cnt >= 2 or k >= (rb ->> 'relight')::int then
        lamps := lamps || seat; kindle := kindle - seat::text;
        perform public.world_gw_say(p_fight, p_round, 'good', seat || '번 자리 등에 다시 불이 붙었습니다(켜진 등 ' || array_length(lamps, 1) || ').');
      else
        kindle := kindle || jsonb_build_object(seat::text, k);
        perform public.world_gw_say(p_fight, p_round, 'guard', seat || '번 자리 등에 불씨를 붙이는 중입니다(' || k || '/' || (rb ->> 'relight') || ').');
      end if;
    end if;
  end loop;
  if jsonb_array_length(coalesce(b -> 'block', '[]'::jsonb)) > 0 and coalesce((b ->> 'unb')::int, 0) < (rb ->> 'unblock_max')::int then
    if solo then
      b := b || jsonb_build_object('solo_calls', coalesce((b ->> 'solo_calls')::int, 0) + self_calls);
      if (b ->> 'solo_calls')::int >= (rb ->> 'solo_unblock')::int then
        perform public.world_gw_say(p_fight, p_round, 'good', '제 이름을 거듭 외우자 긁힌 칸 하나가 풀렸습니다(' || case b -> 'block' ->> 0 when 'item' then '물품' else '협동 기술' end || ').');
        b := b || jsonb_build_object('block', (b -> 'block') - 0, 'unb', coalesce((b ->> 'unb')::int, 0) + 1, 'solo_calls', 0);
      end if;
    elsif cardinality(alive) >= 2 and alive <@ callers and not exists (select 1 from unnest(alive) a where not calls ? a::text) then
      perform public.world_gw_say(p_fight, p_round, 'good', '모두가 서로를 부르자 긁힌 칸 하나가 풀렸습니다(' || case b -> 'block' ->> 0 when 'item' then '물품' else '협동 기술' end || ').');
      b := b || jsonb_build_object('block', (b -> 'block') - 0, 'unb', coalesce((b ->> 'unb')::int, 0) + 1);
    end if;
  end if;
  update public.world_gw_members set out_rounds = 999, rest = false, hp = 0 where fight_id = p_fight and fx ? 'gone';
  b := b || jsonb_build_object('marks', marks, 'lamps', to_jsonb(coalesce(lamps, '{}'::int[])), 'dims', keep, 'kindle', kindle);
  if wn is not null then b := b || jsonb_build_object('wn', wn); end if;
  update public.world_gw_fights set board = b where fight_id = p_fight;
  return extra;
end $f$;

create or replace function public.world_by_after(p_fight uuid, p_round integer)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; n int; ng int; nh int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return true; end if;
  select count(*), count(*) filter (where fx ? 'gone') into n, ng from public.world_gw_members where fight_id = p_fight;
  if ng >= n then
    perform public.world_gw_say(p_fight, p_round, 'bad', '마지막 이름까지 먹으로 풀렸습니다. 마당이 흰 밤에 잠깁니다.');
    perform public.world_gw_settle(p_fight, false);
    return true;
  end if;
  if not coalesce((f.board ->> 'low')::boolean, false) and f.hp > 0 and f.hp * 100 < f.max_hp * (rb ->> 'low_pct')::numeric then
    perform public.world_gw_say(p_fight, p_round, 'boss', '겹친 목소리가 하나둘 빠져나간다. 「이것만은… 못 내주오.」');
    update public.world_gw_fights set board = board || '{"low": true}'::jsonb where fight_id = p_fight;
  end if;
  if f.board -> 'wn' ->> 'at' is not null and p_round >= (f.board -> 'wn' ->> 'at')::int and f.hp > 0 then
    if coalesce((f.board ->> 'wn_fail')::int, 0) >= (rb ->> 'wn_fails')::int then
      perform public.world_gw_say(p_fight, p_round, 'bad', '흰 밤이 다시 걷히지 않았습니다. 마당이 하얗게 바랜 채 굳어 갑니다.');
      perform public.world_gw_settle(p_fight, false);
      return true;
    end if;
    nh := round(f.max_hp * (rb ->> 'wn_fail_hp')::numeric / 100.0);
    update public.world_gw_fights set hp = greatest(hp, nh), enrage = enrage + 1, updated_at = now(),
      board = (board - 'wn') || jsonb_build_object('wn_fail', coalesce((board ->> 'wn_fail')::int, 0) + 1) where fight_id = p_fight;
    perform public.world_gw_say(p_fight, p_round, 'bad', '흰 밤 안에 등을 다 켜지 못했습니다. 떨어졌던 이름들이 하얀 몸으로 되돌아 붙습니다. 백야가 기운을 되찾습니다 — 한 번 더 밀려나면 끝입니다.');
  end if;
  return false;
end $f$;

create or replace function public.world_by_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb := br -> 'board'; f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; b jsonb; n int; L int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  b := coalesce(f.board, '{}'::jsonb); L := public.world_by_lamps(b);
  return jsonb_build_object(
    'phase_name', br -> 'phases' ->> (f.phase - 1), 'phases', br -> 'phases', 'seats', (rb ->> 'seats')::int,
    'lamps', coalesce(b -> 'lamps', '[]'::jsonb), 'lit', L,
    'dmg_mul', round((rb ->> 'dmg_lo')::numeric + (rb ->> 'dmg_k')::numeric * L / 7.0, 3),
    'hurt_mul', round((rb ->> 'hurt_hi')::numeric - (rb ->> 'hurt_k')::numeric * L / 7.0, 3),
    'my_pos', me.pos,
    'moves', case when me.pos is not null and not coalesce(me.fx ? 'gone', false) and f.status = 'fight' then to_jsonb(public.world_by_nb(me.pos)) else '[]'::jsonb end,
    'marks', (select coalesce(jsonb_agg(jsonb_build_object('id', k, 's', (v ->> 's')::int, 'st', coalesce((v ->> 'st')::int, 0), 'steps', (rb ->> 'mark_steps')::int,
      'mute', (v ->> 's')::int >= (rb ->> 'mark_mute')::int)), '[]'::jsonb) from jsonb_each(coalesce(b -> 'marks', '{}'::jsonb)) e(k, v)),
    'my_mark', b -> 'marks' -> p_uid::text,
    'mute', n > 1 and coalesce((b -> 'marks' -> p_uid::text ->> 's')::int, 0) >= (rb ->> 'mark_mute')::int,
    'called', coalesce(b -> 'called', '{}'::jsonb),
    'unheard', (select coalesce(jsonb_agg(x.owner_id order by coalesce((b -> 'called' ->> x.owner_id::text)::int, -1), x.joined_at), '[]'::jsonb) from public.world_gw_members x
      where x.fight_id = p_fight and not x.fx ? 'gone' and f.round - coalesce((b -> 'called' ->> x.owner_id::text)::int, 0) >= (rb ->> 'mark_every')::int),
    'can_call', case when (select count(*) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.fx ? 'gone') <= 1 then to_jsonb(array[p_uid]) else (select coalesce(jsonb_agg(x.owner_id), '[]'::jsonb) from public.world_gw_members x
      where x.fight_id = p_fight and x.owner_id <> p_uid and not x.fx ? 'gone' and (not b ? 'wn' or x.pos = any (public.world_by_nb(me.pos)))) end,
    'dims', (select coalesce(jsonb_agg(jsonb_build_object('c', (e ->> 'c')::int, 'at', (e ->> 'at')::int, 'left', (e ->> 'at')::int - f.round)), '[]'::jsonb) from jsonb_array_elements(coalesce(b -> 'dims', '[]'::jsonb)) e),
    'kindle', coalesce(b -> 'kindle', '{}'::jsonb), 'relight', (rb ->> 'relight')::int,
    'block', coalesce(b -> 'block', '[]'::jsonb), 'unblock_left', greatest(0, (rb ->> 'unblock_max')::int - coalesce((b ->> 'unb')::int, 0)),
    'solo_calls', case when n = 1 then coalesce((b ->> 'solo_calls')::int, 0) end, 'solo_unblock', (rb ->> 'solo_unblock')::int,
    'wn', case when b ? 'wn' then (b -> 'wn') || jsonb_build_object('left', case when b -> 'wn' ->> 'at' is not null then (b -> 'wn' ->> 'at')::int - f.round end) end,
    'heard', b ? 'wn' and coalesce((b -> 'called' ->> p_uid::text)::int, -99) >= f.round - (rb ->> 'wn_heard')::int,
    'wn_fail', coalesce((b ->> 'wn_fail')::int, 0), 'wn_fails', (rb ->> 'wn_fails')::int,
    'gone', (select coalesce(jsonb_agg(x.owner_id), '[]'::jsonb) from public.world_gw_members x where x.fight_id = p_fight and x.fx ? 'gone'));
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
          msg := case when is_first then '백야를 처음으로 이겼습니다. ' || to_char(v_gil, 'FM999,999') || '전' || case when xp > 0 then ' · 경험치 ' || xp else '' end || '을 받았습니다.'
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
  public.world_by_begin(uuid, integer), public.world_by_round(uuid), public.world_by_steps(uuid, integer), public.world_by_mech(uuid, integer, boolean, boolean, uuid[]),
  public.world_by_after(uuid, integer), public.world_by_view(uuid, uuid), public.world_by_settle(uuid, boolean) from public, anon, authenticated;
grant execute on function public.world_by_nb(integer), public.world_by_lamps(jsonb), public.world_by_hurt_mul(uuid, uuid), public.world_by_on_attack(uuid, uuid, integer),
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
  $n$    elsif av in ('call', 'move', 'light') and f.boss_id = 'baekya' then
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
  $n$'recall', 'deal', 'move', 'light') then raise exception$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if me.out_rounds > 0 then raise exception$o$,
  $n$  if coalesce(me.fx ? 'gone', false) then raise exception '붉은 줄에 이름이 먹으로 풀려 이 싸움에서 빠졌습니다.'; end if;
  if me.out_rounds > 0 then raise exception$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if not mk and (p_action = 'recall' or p_move is not null) then$o$,
  $n$  if f.boss_id <> 'baekya' and p_action in ('move', 'light') then raise exception '알 수 없는 행동입니다.'; end if;
  if f.boss_id = 'baekya' then
    if p_action in ('chain', 'recall', 'deal') then raise exception '알 수 없는 행동입니다.'; end if;
    if p_move is not null and not (p_move::int = any (public.world_by_nb(me.pos))) then raise exception '바로 옆 자리로만 옮겨 설 수 있습니다.'; end if;
    if p_action = 'move' and p_move is null then raise exception '옮겨 설 자리를 고르세요.'; end if;
    if p_action = 'attack' and f.board ? 'wn' then raise exception '흰 밤에는 칼끝이 닿지 않습니다. 이웃을 부르고 등을 켜세요.'; end if;
    if p_action = 'coop' and f.board ? 'wn' and coalesce((select (s.effect ->> 'strike')::boolean from public.world_coop_skills s where s.skill_id = p_item), false) then
      raise exception '흰 밤에는 칼끝이 닿지 않습니다. 이웃을 부르고 등을 켜세요.'; end if;
    if p_action in ('item', 'coop') and coalesce(f.board -> 'block', '[]'::jsonb) ? p_action then
      raise exception '긁힌 칸 — 지금은 %을(를) 쓸 수 없습니다. 모두가 서로를 부르면 풀립니다.', case p_action when 'item' then '물품' else '협동 기술' end; end if;
    if p_action in ('call', 'coop') and (select count(*) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.fx ? 'gone') > 1
       and coalesce((f.board -> 'marks' -> uid::text ->> 's')::int, 0) >= (public.world_boss_fight_rules(p_fight) -> 'board' ->> 'mark_mute')::int then
      raise exception '붉은 줄에 목소리가 끊겨 지금은 부르기·협동 기술을 쓸 수 없습니다.'; end if;
    if p_action = 'call' then
      if p_target is null then raise exception '이름을 부를 사람을 고르세요.'; end if;
      if (select count(*) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.fx ? 'gone') <= 1 then
        if p_target <> uid then raise exception '혼자 남았을 때는 제 이름을 외웁니다.'; end if;
      else
        if p_target = uid then raise exception '제 이름은 혼자 남았을 때만 외울 수 있습니다. 동료의 이름을 불러 주세요.'; end if;
        if exists (select 1 from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = p_target and x.fx ? 'gone') then raise exception '이미 먹으로 풀린 사람입니다.'; end if;
      end if;
    end if;
    if p_action = 'light' and coalesce(f.board -> 'lamps', '[]'::jsonb) @> to_jsonb(coalesce(p_move::int, me.pos)) then raise exception '그 자리 등은 이미 켜져 있습니다.'; end if;
  end if;
  if not mk and f.boss_id <> 'baekya' and (p_action = 'recall' or p_move is not null) then$n$);

select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'board', case when f.boss_id = 'gapgwi' then$o$,
  $n$'board', case when f.boss_id = 'baekya' then public.world_by_view(fid, uid) when f.boss_id = 'gapgwi' then$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'pos', m.pos, 'val', m.gval,$o$,
  $n$'pos', m.pos, 'gone', coalesce(m.fx ? 'gone', false), 'marked', f.boss_id = 'baekya' and coalesce(f.board -> 'marks', '{}'::jsonb) ? m.owner_id::text, 'val', m.gval,$n$);

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
    '등: 마당을 둘러싼 일곱 자리마다 등이 하나씩 있다. 켜진 등이 많을수록 우리 공격이 세지고(모두 켜면 그대로, 다 꺼지면 55%) 백야에게 받는 피해가 줄어든다(다 꺼지면 1.3배).',
    '거두기: 4라운드마다(흰 밤에는 쉼) 붉은 붓이 한동안 아무도 부르지 않은 사람에게 붉은 줄을 긋는다. 3라운드 안에 동료가 「부르기」를 해 주지 않으면 그 사람은 싸움에서 빠진다 — 한 번 부르면 한 칸 되돌아가고, 둘이 함께 부르면 지워진다. 돌아가며 고르게 불러 두면 줄이 흩어진다. 혼자면 버티기나 「제 이름 외기」(나를 부르기)를 두 라운드 잇달아(혼자일 때 붉은 줄은 6라운드마다).',
    '소등(2단계부터): 깜빡이는 등이 예고되면 그 자리에 서서 방어나 버티기를 하면 등을 지킨다. 꺼진 등은 그 자리에서 「등 켜기」를 두 라운드(둘이 함께면 한 라운드) 하면 다시 켜진다. 자리는 행동과 함께 바로 옆으로 한 칸씩 옮길 수 있다.',
    '긁힌 칸(3단계): 물품, 조금 뒤 협동 기술이 막힌다. 살아 있는 모두가 같은 라운드에 서로를 부르면(누구나 한 번은 불려야 함) 하나씩 풀린다(두 번까지). 혼자면 제 이름 외기 세 번.',
    '흰 밤(체력 25% 아래): 등이 모두 꺼지고 공격이 닿지 않는다. 바로 옆자리의 동료만 부를 수 있고, 불린 사람(그 라운드나 바로 앞 라운드)이 제 자리에서 「등 켜기」를 하면 등이 켜지며 백야의 체력이 깎인다. 정해진 라운드(넷·셋 8, 둘 10) 안에 일곱 등을 다 켜면 이긴다(혼자는 제 이름 외기 → 등 켜기로 다섯, 12라운드). 못 켜면 백야가 체력 40%로 되돌아가고, 두 번째면 진다. 서로 이웃해 서 두고 빈 자리를 나눠 맡는다.')
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
