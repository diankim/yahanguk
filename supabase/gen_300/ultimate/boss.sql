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

alter table public.world_gw_fights drop constraint if exists world_gw_fights_mode_check;
alter table public.world_gw_fights add constraint world_gw_fights_mode_check check (mode in ('hard', 'story', 'ultimate'));

do $$
declare r jsonb := public.world_boss_rules();
begin
  r := r - 'sealed_lord' || jsonb_build_object('sealed_lord', $j${"raw": [40, 4], "name": "구중 봉주", "fight": "구중 봉인", "raw_n": [1, 1, 0.8, 0.85], "enrage": 0.15, "phases": ["봉인", "봉인", "아홉 문", "아홉 문"], "region": "gwiheo_core", "act_only": true, "ultimate": {"raw": [70, 6], "hp_n": [1, 0.56, 1.0, 1.06], "board": {"gate_n": 3, "gate_gap": 3, "gate_raw": 45, "hand_mul": 1.6, "pair_off": 1, "pair_raw": 35, "aoe_every": 5, "charge_max": 7, "charge_min": 5, "charge_pct": 6, "pair_every": 4, "center_pres": 0, "charge_rounds": 2}, "raw_n": [1, 2.2, 1.4, 1.4], "hp_atk": 12.4, "hp_min": 9000}}$j$::jsonb);
  r := jsonb_set(r, '{gwiheo,modes,ultimate}', '"무용담"');
  r := jsonb_set(r, '{mukjeok,modes,ultimate}', '"무용담"');
  r := jsonb_set(r, '{gapgwi,modes,ultimate}', '"무용담"');
  r := jsonb_set(r, '{gwiheo,ultimate}', $j${"min": 25, "raw": [66, 6], "acts": [{"boss": "sealed_lord", "cuts": [5, 10, 14], "name": "구중 봉주", "rounds": 18}, {"boss": "gwiheo", "cuts": [7, 12, 16], "name": "귀허의 주인", "rounds": 24}], "hp_n": [1, 0.57, 1.0, 1.1], "board": {"hand_mul": 1.6, "aoe_every": 4, "face_every": 4, "name_every": 6, "vortex_pct": 80, "center_pres": 0, "chain_every": 6, "vortex_every": 5}, "items": 3, "raw_n": [1, 2.2, 1.4, 1.4], "enrage": 0.15, "hp_atk": 6.8, "hp_min": 9000, "phases": ["두 얼굴", "사슬 넷", "이름 빼앗기", "귀허의 소용돌이"], "rest_hp": 30, "rest_rounds": 2, "tip": "역할을 나누지 않으면 깨기 어렵습니다 — 노림을 받아 버티거나 돕는 사람(방패·보조)이나 돌볼 사람(치유)과 함께 가세요."}$j$::jsonb);
  r := jsonb_set(r, '{mukjeok,ultimate}', $j${"min": 25, "raw": [70, 6], "acts": [{"boss": "mukjeok", "cuts": [8, 18, 28], "name": "먹그림자", "rounds": 36}], "hp_n": [1, 0.6, 0.94, 0.99], "board": {"line_n": [1, 1, 1, 1], "hand_mul": 2.4, "line_off": [1, 0, 0, 1], "line_every": [4, 4, 3, 4], "erase_every": 4, "erase_strokes": 3, "mimic_reverse": true}, "items": 3, "raw_n": [1, 2.5, 1.4, 1.4], "hp_atk": 12.5, "hp_min": 12000, "rest_hp": 30, "rest_rounds": 2, "tip": "역할을 나누지 않으면 깨기 어렵습니다 — 노림을 받아 버티거나 돕는 사람(방패·보조)이나 돌볼 사람(치유)과 함께 가세요."}$j$::jsonb);
  r := jsonb_set(r, '{gapgwi,ultimate}', $j${"min": 25, "raw": [70, 6], "acts": [{"boss": "gapgwi", "cuts": [6, 11, 16], "name": "값귀", "rounds": 20}, {"boss": "baekya", "cuts": [6, 12, 18], "name": "백야", "rounds": 26}], "hp_n": [1, 0.52, 0.95, 1.05], "board": {"hide": true, "guide": false, "hand_mul": 1.6, "tag_move": true, "judge_off": [0, 1, 1, 0], "deal_force": true, "judge_lead": 1, "bargain_tol": 0, "judge_every": [0, 3, 3, 2], "judge_fixed": true, "bargain_show": false, "close_rounds": 0, "compound_all": true}, "items": 3, "raw_n": [1, 2.0, 1.4, 1.4], "hp_atk": 12.5, "hp_min": 9000, "rest_hp": 30, "rest_rounds": 2, "tip": "역할을 나누지 않으면 깨기 어렵습니다 — 노림을 받아 버티거나 돕는 사람(방패·보조)이나 돌볼 사람(치유)과 함께 가세요."}$j$::jsonb);
  r := jsonb_set(r, '{baekya,ultimate}', $j${"raw": [74, 6], "hp_n": [1, 0.3, 0.86, 0.95], "board": {"hide": true, "dim_n": [1, 1, 2, 2], "relight": 3, "wn_need": 7, "dim_lead": 1, "hand_mul": 1.6, "wn_fails": 1, "dim_every": [3, 3, 3, 2], "wn_rounds": [8, 10, 7, 6], "mark_every": 4, "mark_steps": 3, "scratch_brace_pct": 30}, "raw_n": [1, 1.2, 1.4, 1.4], "hp_atk": 6, "hp_min": 9000}$j$::jsonb);
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
end $$;

create or replace function public.world_boss_fight_rules(p_fight uuid)
 returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $f$
  select case when x.md = 'story' then (x.r - 'story') || ((x.r -> 'story') - 'board') || jsonb_build_object('board', coalesce(x.r -> 'board', '{}'::jsonb) || coalesce(x.r -> 'story' -> 'board', '{}'::jsonb))
    when x.md = 'ultimate' and x.r ? 'ultimate' then (x.r - 'story' - 'ultimate') || ((x.r -> 'ultimate') - 'board' - 'acts') || jsonb_build_object('board', coalesce(x.r -> 'board', '{}'::jsonb) || coalesce(x.r -> 'ultimate' -> 'board', '{}'::jsonb))
    else x.r end
  from (select public.world_boss_rules() -> coalesce(f.boss_id, 'mukjeok') as r, f.mode as md
        from (select 1) o left join public.world_gw_fights f on f.fight_id = p_fight) x
$f$;

create or replace function public.world_ug_cfg(p_fight uuid)
 returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $f$ select public.world_boss_rules() -> coalesce(f.board -> 'ug' ->> 'board', f.boss_id) -> 'ultimate' from public.world_gw_fights f where f.fight_id = p_fight $f$;

create or replace function public.world_ug_say_ok(p_fight uuid, p_kind text)
 returns boolean language sql stable security definer set search_path = pg_catalog, public
as $f$ select p_kind not in ('tell', 'warn', 'info') or not exists (select 1 from public.world_gw_fights x where x.fight_id = p_fight and x.mode = 'ultimate') $f$;

create or replace function public.world_ug_begin_act(p_fight uuid, p_act integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; cfg jsonb; act jsonb; ug jsonb; br jsonb; n int; sa numeric; v_hp int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  cfg := public.world_ug_cfg(p_fight); act := cfg -> 'acts' -> (p_act - 1);
  ug := coalesce(f.board -> 'ug', '{}'::jsonb) || jsonb_build_object('act', p_act, 'acts', jsonb_array_length(cfg -> 'acts'), 'act_start', f.round, 'name', act ->> 'name',
    'rounds', (act ->> 'rounds')::int, 'cuts', act -> 'cuts', 'double', false);
  update public.world_gw_fights set boss_id = act ->> 'boss', board = jsonb_build_object('ug', ug), phase = 1, cycle = 0, enrage = 0, mech = '{}'::jsonb, bfx = '{}'::jsonb where fight_id = p_fight;
  update public.world_gw_members set pos = null, prev = null, gval = null, nameless = false, fx = fx - 'gone' - 'bound' where fight_id = p_fight;
  br := public.world_boss_fight_rules(p_fight);
  select count(*), coalesce(sum(coalesce((stats ->> 'hp_atk')::numeric, (stats ->> 'attack')::numeric, 50)), 0) into n, sa from public.world_gw_members where fight_id = p_fight;
  v_hp := round(greatest((br ->> 'hp_min')::numeric, sa * (br ->> 'hp_atk')::numeric) * (br -> 'hp_n' ->> (least(4, greatest(1, n)) - 1))::numeric);
  update public.world_gw_fights set max_hp = v_hp, hp = v_hp where fight_id = p_fight;
  if act ->> 'boss' = 'mukjeok' then perform public.world_mk_begin(p_fight, n);
  elsif act ->> 'boss' = 'gapgwi' then perform public.world_gg_begin(p_fight, n);
  elsif act ->> 'boss' = 'baekya' then perform public.world_by_begin(p_fight, n);
  elsif act ->> 'boss' = 'sealed_lord' then
    perform public.world_gw_say(p_fight, f.round, 'phase', '귀허 바닥 아래에서 아홉 겹으로 묶인 봉인이 울린다. 구중 봉주가 사슬을 끌며 일어선다.');
  else
    perform public.world_gw_say(p_fight, f.round, 'phase', '빈 왕좌 위로 물이 솟아 사람 꼴이 된다. 귀허의 주인이 두 얼굴을 번갈아 든다.');
  end if;
  update public.world_gw_fights set board = board || jsonb_build_object('ug', ug) where fight_id = p_fight;
  perform public.world_gw_say(p_fight, f.round, 'act', p_act || '막 — ' || (act ->> 'name') || ' · ' || (act ->> 'rounds') || '라운드 안에.');
end $f$;

create or replace function public.world_ug_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; ug jsonb; nr int; st text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  ug := f.board -> 'ug'; nr := f.round + 1;
  if coalesce((ug ->> 'rest')::int, 0) > 0 then
    update public.world_gw_fights set round = nr, mech = '{"k": "rest"}'::jsonb, round_ends_at = now() + interval '5 seconds', updated_at = now(),
      board = jsonb_set(board, '{ug,rest}', to_jsonb((ug ->> 'rest')::int - 1)) where fight_id = p_fight;
    update public.world_gw_members set act = null where fight_id = p_fight;
    perform public.world_gw_say(p_fight, nr, 'act', '막 사이 — 숨을 고른다(' || (ug ->> 'rest') || ').');
    if (ug ->> 'rest')::int = 1 then
      update public.world_gw_fights set board = jsonb_set(board, '{ug,act_start}', to_jsonb(nr)) where fight_id = p_fight;
    end if;
    return;
  end if;
  if f.boss_id = 'sealed_lord' then perform public.world_ug_lord_round(p_fight);
  elsif f.boss_id = 'gwiheo' then perform public.world_ug_gw_round(p_fight);
  elsif f.boss_id = 'mukjeok' then perform public.world_mk_round(p_fight);
  elsif f.boss_id = 'gapgwi' then perform public.world_gg_round(p_fight);
  elsif f.boss_id = 'baekya' then perform public.world_by_round(p_fight);
  end if;
  update public.world_gw_fights set round_ends_at = least(round_ends_at, now() + interval '10 seconds') where fight_id = p_fight;
  select string_agg(x.name || case when x.out_rounds > 0 then '(물러남)' else '' end || case when x.pos is not null then ' ' || x.pos || '번' else '' end
      || case when x.gval is not null then ' ' || x.gval || '섬' else '' end, ' · ' order by x.joined_at) into st
    from public.world_gw_members x where x.fight_id = p_fight;
  perform public.world_gw_say(p_fight, nr, 'state', nr - coalesce((ug ->> 'act_start')::int, 0) || '라운드 — ' || coalesce(st, ''));
end $f$;

create or replace function public.world_ug_lord_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; b jsonb; lord jsonb; nr int; ar int; ph int; a uuid[]; aoe boolean := false; g int[]; i int; k int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; lord := coalesce(b -> 'lord', '{}'::jsonb); nr := f.round + 1; ar := nr - coalesce((b -> 'ug' ->> 'act_start')::int, 0);
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  if ph <> f.phase then perform public.world_gw_say(p_fight, nr, 'phase', '봉인 하나가 더 풀린다. 봉주의 사슬이 무겁게 끌린다.'); end if;
  lord := lord - 'pair';
  select array_agg(owner_id order by random()) into a from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  if coalesce(array_length(a, 1), 0) >= 2 and ar % (rb ->> 'pair_every')::int = (rb ->> 'pair_off')::int then
    lord := lord || jsonb_build_object('pair', jsonb_build_array(a[1], a[2]));
    perform public.world_gw_say(p_fight, nr, 'seal', '봉인이 깨어나 ' || (select name from public.world_gw_members where fight_id = p_fight and owner_id = a[1]) || '·'
      || (select name from public.world_gw_members where fight_id = p_fight and owner_id = a[2]) || '을(를) 한 사슬로 묶었다.');
  end if;
  if not lord ? 'charge' and not lord ? 'next_charge' then
    lord := lord || jsonb_build_object('next_charge', ar + (rb ->> 'charge_min')::int + floor(random() * ((rb ->> 'charge_max')::int - (rb ->> 'charge_min')::int + 1))::int);
  end if;
  if lord ? 'next_charge' and ar >= (lord ->> 'next_charge')::int then
    lord := (lord - 'next_charge') || jsonb_build_object('charge', jsonb_build_object('end', ar + (rb ->> 'charge_rounds')::int - 1, 'need', round(f.max_hp * (rb ->> 'charge_pct')::numeric / 100.0), 'dmg', 0));
  end if;
  if ph >= 3 and not lord ? 'gates' then
    g := array[ar];
    i := (rb ->> 'gate_gap')::int + floor(random() * 2)::int;
    for k in 2 .. (rb ->> 'gate_n')::int loop g := g || (g[k - 1] + i); end loop;
    lord := lord || jsonb_build_object('gates', to_jsonb(g));
  end if;
  aoe := ar % (rb ->> 'aoe_every')::int = 0 and not lord ? 'charge';
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, board = b || jsonb_build_object('lord', lord),
    mech = jsonb_build_object('k', 'normal', 'aoe', aoe), round_ends_at = now() + interval '5 seconds', updated_at = now() where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
end $f$;

create or replace function public.world_ug_gw_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; b jsonb; m jsonb; nr int; ar int; ph int; alive uuid[];
  colors text[] := array['청', '적', '황', '백']; t uuid; need int; aoe boolean := false; face text; nn int; lastt text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; nr := f.round + 1; ar := nr - coalesce((b -> 'ug' ->> 'act_start')::int, 0);
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select array_agg(owner_id order by random()) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  if ph <> f.phase then
    perform public.world_gw_say(p_fight, nr, 'phase', case ph when 2 then '흰 사슬이 솟는다.' when 3 then '물이 이름을 핥는다.' else '바다 전체가 소용돌이친다.' end);
    f.cycle := 0;
  end if;
  face := coalesce(b ->> 'face', case when random() < 0.5 then 'human' else 'yokai' end);
  if ar % (rb ->> 'face_every')::int = 1 and ar > 1 then face := case when random() < 0.5 then 'human' else 'yokai' end; end if;
  b := b || jsonb_build_object('face', face);
  if ph = 1 then
    m := jsonb_build_object('k', 'face', 'face', face);
    aoe := ar % (rb ->> 'aoe_every')::int = 0;
  elsif ph = 2 and f.cycle % (rb ->> 'chain_every')::int = 0 and alive is not null then
    m := jsonb_build_object('k', 'chain', 'colors', (select jsonb_object_agg(a::text, colors[o]) from unnest(alive) with ordinality u(a, o)));
    perform public.world_gw_say(p_fight, nr, 'seal', '사슬이 손목을 감았다.');
  elsif ph = 3 and f.cycle % (rb ->> 'name_every')::int = 0 and alive is not null then
    nn := case when array_length(alive, 1) >= 3 then 2 else 1 end;
    update public.world_gw_members set nameless = true where fight_id = p_fight and owner_id = any (alive[1:nn]);
    m := jsonb_build_object('k', 'name', 'targets', to_jsonb(alive[1:nn]));
    perform public.world_gw_say(p_fight, nr, 'seal', (select string_agg(name, '·') from public.world_gw_members where fight_id = p_fight and owner_id = any (alive[1:nn])) || '의 이름이 물에 녹았다.');
  elsif ph = 4 and f.cycle % (rb ->> 'vortex_every')::int = 0 and alive is not null then
    lastt := b ->> 'last_tank';
    select owner_id into t from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and owner_id::text is distinct from lastt
     order by (stats ->> 'pres')::numeric desc, random() limit 1;
    if t is null then t := alive[1]; end if;
    select greatest(1, round(coalesce(sum((stats ->> 'attack')::numeric), 0) * (rb ->> 'vortex_pct')::numeric / 100.0)) into need from public.world_gw_members
     where fight_id = p_fight and out_rounds = 0 and not rest and owner_id <> t;
    m := jsonb_build_object('k', 'vortex', 'tank', t, 'need', need);
    b := b || jsonb_build_object('last_tank', t);
    perform public.world_gw_say(p_fight, nr, 'seal', '소용돌이가 일어났다.');
  else
    m := jsonb_build_object('k', 'normal');
    aoe := ar % (rb ->> 'aoe_every')::int = 0;
  end if;
  m := m || jsonb_build_object('aoe', aoe);
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when m ->> 'k' in ('chain', 'name', 'vortex') then 10 else 5 end), updated_at = now() where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
end $f$;

create or replace function public.world_ug_mech(p_fight uuid, p_round integer, p_dmg numeric, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; b jsonb; lord jsonb; ar int; w record; c1 text; c2 text; p uuid[];
  names text; safe text; hit text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.boss_id <> 'sealed_lord' then return 0; end if;
  b := f.board; lord := coalesce(b -> 'lord', '{}'::jsonb); ar := p_round - coalesce((b -> 'ug' ->> 'act_start')::int, 0);
  if lord ? 'pair' then
    p := array(select jsonb_array_elements_text(lord -> 'pair')::uuid);
    select case when act ->> 'a' in ('attack', 'deal') or (act ->> 'a' = 'coop' and coalesce((select (s.effect ->> 'strike')::boolean from public.world_coop_skills s where s.skill_id = act ->> 's'), false)) then 'attack'
      when act is null or act ->> 'a' in ('guard', 'brace') then 'guard' else coalesce(act ->> 'a', 'guard') end into c1 from public.world_gw_members where fight_id = p_fight and owner_id = p[1];
    select case when act ->> 'a' in ('attack', 'deal') or (act ->> 'a' = 'coop' and coalesce((select (s.effect ->> 'strike')::boolean from public.world_coop_skills s where s.skill_id = act ->> 's'), false)) then 'attack'
      when act is null or act ->> 'a' in ('guard', 'brace') then 'guard' else coalesce(act ->> 'a', 'guard') end into c2 from public.world_gw_members where fight_id = p_fight and owner_id = p[2];
    select string_agg(name, '·') into names from public.world_gw_members where fight_id = p_fight and owner_id = any (p);
    if c1 = c2 then
      perform public.world_gw_say(p_fight, p_round, 'good', names || ' — 사슬이 풀렸다.');
    else
      perform public.world_gw_say(p_fight, p_round, 'bad', names || ' — 사슬이 조여들었다.');
      perform public.world_gw_hurt(p_fight, p[1], (rb ->> 'pair_raw')::int, p_round, '조여든 사슬에');
      perform public.world_gw_hurt(p_fight, p[2], (rb ->> 'pair_raw')::int, p_round, '조여든 사슬에');
    end if;
  end if;
  if lord ? 'charge' then
    lord := jsonb_set(lord, '{charge,dmg}', to_jsonb(coalesce((lord -> 'charge' ->> 'dmg')::numeric, 0) + p_dmg));
    if (lord -> 'charge' ->> 'dmg')::numeric >= (lord -> 'charge' ->> 'need')::numeric then
      perform public.world_gw_say(p_fight, p_round, 'good', '봉주가 모으던 기운이 흩어졌다(' || round((lord -> 'charge' ->> 'dmg')::numeric) || ').');
      lord := lord - 'charge';
    elsif ar >= (lord -> 'charge' ->> 'end')::int then
      perform public.world_gw_say(p_fight, p_round, 'bad', '봉주가 모은 기운이 터졌다(' || round((lord -> 'charge' ->> 'dmg')::numeric) || '). 모두가 겨우 숨만 붙어 있다.');
      update public.world_gw_members set hp = least(hp, 1) where fight_id = p_fight and out_rounds = 0 and not rest;
      lord := lord - 'charge';
    end if;
  end if;
  if lord -> 'gates' @> to_jsonb(ar) then
    safe := (select string_agg(name, '·') from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'coop');
    perform public.world_gw_say(p_fight, p_round, 'seal', '문 하나가 열렸다. 다치지 않은 사람: ' || coalesce(safe, '없음') || '.');
    for w in select owner_id from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' is distinct from 'coop' loop
      perform public.world_gw_hurt(p_fight, w.owner_id, (rb ->> 'gate_raw')::int, p_round, '열린 문에서 쏟아진 물에');
    end loop;
  end if;
  update public.world_gw_fights set board = board || jsonb_build_object('lord', lord) where fight_id = p_fight;
  return 0;
end $f$;

create or replace function public.world_ug_raw(p_fight uuid)
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare d boolean;
begin
  select coalesce((board -> 'ug' ->> 'double')::boolean, false) into d from public.world_gw_fights where fight_id = p_fight;
  if d then update public.world_gw_fights set board = jsonb_set(board, '{ug,double}', 'false') where fight_id = p_fight; end if;
  return public.world_mk_raw(p_fight) * case when d then 2 else 1 end;
end $f$;

create or replace function public.world_ug_wipe(p_fight uuid, p_round integer, p_why text)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
begin
  perform public.world_gw_say(p_fight, p_round, 'bad', p_why || ' 모두가 쓰러졌다.');
  update public.world_gw_members set hp = 0, falls = falls + case when out_rounds = 0 then 1 else 0 end where fight_id = p_fight;
  perform public.world_gw_settle(p_fight, false);
end $f$;

create or replace function public.world_ug_after(p_fight uuid, p_round integer)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; ug jsonb; ar int; i int; cut int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if f.status <> 'fight' then return true; end if;
  ug := f.board -> 'ug';
  if coalesce((ug ->> 'rest')::int, 0) > 0 then return false; end if;
  ar := p_round - coalesce((ug ->> 'act_start')::int, 0);
  if ar >= (ug ->> 'rounds')::int then
    perform public.world_ug_wipe(p_fight, p_round, '이야기꾼의 말로는 ' || (ug ->> 'name') || '이(가) 그 자리를 통째로 삼켰다고 한다 — ' || (ug ->> 'rounds') || '라운드가 다 지났다.');
    return true;
  end if;
  for i in 0 .. coalesce(jsonb_array_length(ug -> 'cuts'), 0) - 1 loop
    cut := (ug -> 'cuts' ->> i)::int;
    if ar >= cut and f.hp * 4 > f.max_hp * (3 - i) then
      perform public.world_ug_wipe(p_fight, p_round, '이야기꾼의 말로는 ' || (ug ->> 'name') || '의 기세가 하늘을 찔렀다고 한다 — 기세를 꺾지 못했다(' || ar || '라운드, ' || (100 - 25 * (i + 1)) || '% 아래로 못 내림).');
      return true;
    end if;
  end loop;
  return false;
end $f$;

create or replace function public.world_ug_cleared(p_fight uuid, p_round integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; ug jsonb; cfg jsonb; nxt int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  ug := f.board -> 'ug'; cfg := public.world_ug_cfg(p_fight); nxt := (ug ->> 'act')::int + 1;
  if nxt > jsonb_array_length(cfg -> 'acts') then
    perform public.world_gw_settle(p_fight, true);
    return;
  end if;
  perform public.world_gw_say(p_fight, p_round, 'act', (ug ->> 'name') || '이(가) 무너졌다(' || (p_round - (ug ->> 'act_start')::int) || '라운드). 이야기꾼이 숨도 쉬지 않고 다음 대목을 잇는다.');
  update public.world_gw_members set hp = least(100, hp + (cfg ->> 'rest_hp')::int) where fight_id = p_fight and out_rounds = 0;
  perform public.world_ug_begin_act(p_fight, nxt);
  update public.world_gw_fights set board = jsonb_set(board, '{ug,rest}', to_jsonb((cfg ->> 'rest_rounds')::int)) where fight_id = p_fight;
  perform public.world_gw_next_round(p_fight);
end $f$;

create or replace function public.world_ug_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; ug jsonb; v jsonb := '{}'::jsonb; ar int; rest int; br jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  ug := coalesce(f.board -> 'ug', '{}'::jsonb); rest := greatest(coalesce((ug ->> 'rest')::int, 0), case when f.mech ->> 'k' = 'rest' then 1 else 0 end); br := public.world_boss_fight_rules(p_fight);
  ar := f.round - coalesce((ug ->> 'act_start')::int, 0);
  if f.boss_id = 'mukjeok' then
    v := jsonb_build_object('strokes', coalesce((f.board ->> 'strokes')::int, 0), 'max', coalesce((f.board ->> 'max')::int, 9),
      'lit', coalesce(f.board -> 'lit', '[]'::jsonb), 'mem', coalesce((f.board ->> 'mem')::int, 0), 'lost', coalesce((f.board ->> 'lost')::int, 0),
      'ink', (select coalesce(jsonb_agg(distinct vv::int), '[]'::jsonb) from jsonb_each_text(coalesce(f.board -> 'ink', '{}'::jsonb)) e(kk, vv)),
      'moves', case when me.pos is not null and not public.world_mk_held(p_fight, p_uid) and f.status = 'fight' then public.world_mk_lines() -> 'nb' -> me.pos::text else '[]'::jsonb end,
      'my_pos', me.pos);
  elsif f.boss_id = 'gapgwi' then
    v := public.world_gg_view(p_fight, p_uid) - 'preview' - 'judge' - 'bargain' - 'close'
      || case when f.board ? 'judge' then jsonb_build_object('judge', jsonb_build_object('left', (f.board -> 'judge' ->> 'at')::int - f.round)) else '{}'::jsonb end
      || case when f.board ? 'bargain' then jsonb_build_object('bargain', jsonb_build_object('left', (f.board -> 'bargain' ->> 'at')::int - f.round)) else '{}'::jsonb end;
  elsif f.boss_id = 'baekya' then
    v := public.world_by_view(p_fight, p_uid) - 'dims' - 'unheard' - 'dmg_mul' - 'hurt_mul' - 'heard' - 'marks' - 'my_mark' - 'mute' - 'called';
  elsif f.boss_id = 'sealed_lord' then
    v := jsonb_build_object('pair', coalesce(f.board -> 'lord' -> 'pair', '[]'::jsonb), 'charging', coalesce(f.board -> 'lord' ? 'charge', false));
  elsif f.boss_id = 'gwiheo' and f.mech ->> 'k' = 'chain' then
    v := jsonb_build_object('mine', f.mech -> 'colors' ->> p_uid::text);
  end if;
  return v || jsonb_build_object('phase_name', br -> 'phases' ->> (f.phase - 1), 'phases', br -> 'phases',
    'ug', jsonb_build_object('board', ug ->> 'board', 'board_name', public.world_ultimate_rules() -> 'boards' -> (ug ->> 'board') ->> 'name',
    'act', (ug ->> 'act')::int, 'acts', (ug ->> 'acts')::int, 'act_boss', f.boss_id, 'act_name', ug ->> 'name', 'act_round', case when rest > 0 then 0 else ar end,
    'rounds', (ug ->> 'rounds')::int, 'wipe_left', case when rest > 0 then (ug ->> 'rounds')::int else greatest(0, (ug ->> 'rounds')::int - ar) end, 'rest', rest,
    'next_cut', case when rest > 0 then null else (select jsonb_build_object('at', (c.v)::int, 'left', (c.v)::int - ar, 'pct', 100 - 25 * c.o::int)
       from jsonb_array_elements_text(ug -> 'cuts') with ordinality c(v, o) where (c.v)::int > ar order by c.o limit 1) end));
end $f$;

create or replace function public.world_ug_settle(p_fight uuid, p_won boolean)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; ur jsonb := public.world_ultimate_rules(); bd text; m record; n int; flawless boolean; rec public.world_gw_records%rowtype;
  first boolean; q int; tk text; room int; inv jsonb; bag int; give int; tok_name text; bname text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status not in ('fight', 'wait') then return; end if;
  bd := coalesce(f.board -> 'ug' ->> 'board', f.boss_id);
  update public.world_gw_fights set status = case when p_won then 'won' else 'failed' end, boss_id = bd, ended_at = now(), updated_at = now(), hp = case when p_won then 0 else hp end where fight_id = p_fight;
  select count(*), coalesce(sum(falls), 0) = 0 into n, flawless from public.world_gw_members where fight_id = p_fight;
  tk := ur -> 'boards' -> bd ->> 'token'; tok_name := ur -> 'boards' -> bd ->> 'token_name'; bname := ur -> 'boards' -> bd ->> 'name';
  for m in select * from public.world_gw_members where fight_id = p_fight loop
    update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
    if p_won then
      insert into public.world_gw_records(owner_id, boss_id) values (m.owner_id, 'ug_' || bd) on conflict do nothing;
      select * into rec from public.world_gw_records where owner_id = m.owner_id and boss_id = 'ug_' || bd for update;
      first := coalesce(rec.kills, 0) = 0;
      update public.world_gw_records set kills = kills + 1, last_kill_day = (now() at time zone 'Asia/Seoul')::date, first_kill_at = coalesce(first_kill_at, now())
       where owner_id = m.owner_id and boss_id = 'ug_' || bd;
      q := (ur -> 'tokens' ->> 'clear')::int + case when first then (ur -> 'tokens' ->> 'first')::int else 0 end;
      select inventory into inv from public.world_characters where owner_id = m.owner_id for update;
      bag := public.world_bag_limit(m.owner_id);
      give := greatest(0, least(q, public.world_bag_room(inv, tk, bag)));
      if give > 0 then update public.world_characters set inventory = public.world_inv_add(inventory, tk, give), updated_at = now() where owner_id = m.owner_id; end if;
      if q - give > 0 then perform public.world_letter_spill(m.owner_id, jsonb_build_object(tk, q - give)); end if;
      insert into public.world_events(actor_id, actor_name, event_type, content, payload)
      values (m.owner_id, m.name, 'ug_win', m.name || '이(가) ' || bname || '을(를) 깼습니다.',
              jsonb_build_object('fight_id', p_fight, 'board', bd, 'duo', n = 2, 'flawless', flawless, 'members', n, 'first', first, 'kills', coalesce(rec.kills, 0) + 1));
      insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', bname || '을(를) 깼습니다',
        tok_name || ' ' || q || '개를 받았습니다' || case when first then '(처음 깸 ' || (ur -> 'tokens' ->> 'first') || '개 포함)' else '' end
          || case when q - give > 0 then ' — 가방이 차 ' || (q - give) || '개는 창고에 넣었습니다.' else '.' end,
        jsonb_build_object('fight_id', p_fight, 'boss', bd, 'mode', 'ultimate', 'first', first, 'tokens', q));
    else
      insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'gw', bname || ' — 다시 처음부터',
        '전멸했습니다. 이야기꾼은 벌써 다음 판 이야기를 부풀리는 중입니다. 잃는 것은 없고, 다시 열면 1막부터입니다.', jsonb_build_object('fight_id', p_fight, 'boss', bd, 'mode', 'ultimate'));
    end if;
  end loop;
  perform public.world_gw_say(p_fight, f.round, case when p_won then 'win' else 'bad' end, case when p_won then bname || ' — 이야기꾼도 더 부풀릴 말이 없는 끝을 보았다.' else '도전이 끝났습니다.' end);
end $f$;

revoke all on function public.world_ug_cfg(uuid), public.world_ug_say_ok(uuid, text), public.world_ug_begin_act(uuid, integer), public.world_ug_round(uuid),
  public.world_ug_lord_round(uuid), public.world_ug_gw_round(uuid), public.world_ug_mech(uuid, integer, numeric, boolean, boolean, uuid[]), public.world_ug_raw(uuid),
  public.world_ug_wipe(uuid, integer, text), public.world_ug_after(uuid, integer), public.world_ug_cleared(uuid, integer), public.world_ug_view(uuid, uuid),
  public.world_ug_settle(uuid, boolean) from public, anon, authenticated;
grant execute on function public.world_ug_cfg(uuid), public.world_ug_say_ok(uuid, text), public.world_ug_begin_act(uuid, integer), public.world_ug_round(uuid),
  public.world_ug_lord_round(uuid), public.world_ug_gw_round(uuid), public.world_ug_mech(uuid, integer, numeric, boolean, boolean, uuid[]), public.world_ug_raw(uuid),
  public.world_ug_wipe(uuid, integer, text), public.world_ug_after(uuid, integer), public.world_ug_cleared(uuid, integer), public.world_ug_view(uuid, uuid),
  public.world_ug_settle(uuid, boolean) to service_role, fn_owner_field;

create or replace function public.world_gw_say(p_fight uuid, p_round integer, p_kind text, p_text text)
 returns void language sql security definer set search_path = pg_catalog, public
as $f$
  insert into public.world_gw_log(fight_id, round, kind, text) select p_fight, p_round, p_kind, p_text where public.world_ug_say_ok(p_fight, p_kind)
$f$;

select pg_temp.yh_patch('public.world_gw_next_round(uuid)',
  $o$  if f.boss_id = 'baekya' then perform public.world_by_round(p_fight); return; end if;$o$,
  $n$  if f.mode = 'ultimate' then perform public.world_ug_round(p_fight); return; end if;
  if f.boss_id = 'baekya' then perform public.world_by_round(p_fight); return; end if;$n$);

select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$    if (f.mode <> 'story' and coalesce((x.inventory ->> v_item)::int, 0) < 1) or x.health <= 0 then$o$,
  $n$    if (f.mode = 'hard' and coalesce((x.inventory ->> v_item)::int, 0) < 1) or x.health <= 0 then$n$);
select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$    if f.mode <> 'story' then
      update public.world_characters set inventory = public.world_inv_add(inventory, v_item, -1), updated_at = now() where owner_id = x.owner_id;$o$,
  $n$    if f.mode = 'hard' then
      update public.world_characters set inventory = public.world_inv_add(inventory, v_item, -1), updated_at = now() where owner_id = x.owner_id;$n$);
select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$values (x.owner_id, f.boss_id || case when f.mode = 'story' then '_story' else '' end, 1)$o$,
  $n$values (x.owner_id, case when f.mode = 'ultimate' then 'ug_' else '' end || f.boss_id || case when f.mode = 'story' then '_story' else '' end, 1)$n$);
select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$  if f.boss_id = 'baekya' then
    br := public.world_boss_fight_rules(p_fight);$o$,
  $n$  if f.mode = 'ultimate' then
    if n < 2 then
      update public.world_gw_fights set status = 'failed', ended_at = now(), updated_at = now() where fight_id = p_fight;
      perform public.world_gw_say(p_fight, 0, 'bad', '무용담은 둘 이상이 함께여야 합니다. 모이지 않아 흩어졌습니다.');
      return;
    end if;
    update public.world_gw_fights set status = 'fight', board = jsonb_build_object('ug', jsonb_build_object('board', f.boss_id)),
      ends_at = now() + make_interval(mins => (public.world_boss_rules() -> f.boss_id -> 'ultimate' ->> 'min')::int), round = 0, updated_at = now() where fight_id = p_fight;
    perform public.world_ug_begin_act(p_fight, 1);
    perform public.world_gw_next_round(p_fight);
    return;
  end if;
  if f.boss_id = 'baekya' then
    br := public.world_boss_fight_rules(p_fight);$n$);

select pg_temp.yh_patch('public.world_gw_begin(uuid)',
  $o$  perform public.world_gw_start(p_fight);$o$,
  $n$  if exists (select 1 from public.world_gw_fights where fight_id = p_fight and mode = 'ultimate') and (select count(*) from public.world_gw_members where fight_id = p_fight) < 2 then
    raise exception '무용담은 둘 이상이 모여야 시작할 수 있습니다.'; end if;
  perform public.world_gw_start(p_fight);$n$);

select pg_temp.yh_patch('public.world_gw_open(text,text)',
  $o$  md text := case when p_mode = 'story' then 'story' else 'hard' end;$o$,
  $n$  md text := case when p_mode in ('story', 'ultimate') then p_mode else 'hard' end;$n$);
select pg_temp.yh_patch('public.world_gw_open(text,text)',
  $o$  insert into public.world_gw_fights(leader_id, status, start_at, boss_id, mode)$o$,
  $n$  if md = 'ultimate' and n = 0 then raise exception '무용담은 같은 곳에 함께 설 파티원이 있어야 열 수 있습니다(2~4명).'; end if;
  insert into public.world_gw_fights(leader_id, status, start_at, boss_id, mode)$n$);
select pg_temp.yh_patch('public.world_gw_open(text,text)',
  $o$    if boss = 'baekya' then$o$,
  $n$    if md = 'ultimate' then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (x.owner_id, 'gw_invite', (public.world_ultimate_rules() -> 'boards' -> boss ->> 'name') || ' · 함께 싸우기', c.character_name || '이(가) ' || (public.world_ultimate_rules() -> 'boards' -> boss ->> 'name') || '을(를) 열었습니다. 60초 안에 합류하세요.',
        jsonb_build_object('fight_id', fid, 'boss', boss, 'mode', md));
    elsif boss = 'baekya' then$n$);

select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$  if br is null then raise exception '알 수 없는 우두머리입니다.'; end if;$o$,
  $n$  if br is null or br ? 'act_only' then raise exception '알 수 없는 우두머리입니다.'; end if;
  if p_mode = 'ultimate' then
    if not br ? 'ultimate' or br -> 'ultimate' ? 'acts' is not true then raise exception '이 우두머리에는 무용담이 없습니다.'; end if;
    select * into c from public.world_characters where owner_id = p_uid;
    if (public.world_region_at(c.location)).region_id is distinct from br ->> 'region' then raise exception '%에서만 %을(를) 열 수 있습니다.', br ->> 'place', br -> 'modes' ->> 'ultimate'; end if;
    if c.level < public.world_level_cap() then raise exception '무용담은 Lv%만 들어갈 수 있습니다.', public.world_level_cap(); end if;
    if not public.world_quest_done(p_uid, public.world_ultimate_rules() ->> 'open_quest') then raise exception '「%」을(를) 마쳐야 무용담이 열립니다.', (select q.title from public.world_quests q where q.quest_id = public.world_ultimate_rules() ->> 'open_quest'); end if;
    if not exists (select 1 from public.world_gw_records r where r.owner_id = p_uid and r.boss_id = p_boss and r.kills > 0) then
      raise exception '%을(를) 한 번 이상 깨야 무용담에 들어갈 수 있습니다.', br -> 'modes' ->> 'hard'; end if;
    if p_boss = 'gapgwi' and not exists (select 1 from public.world_gw_records r where r.owner_id = p_uid and r.boss_id = 'baekya' and r.kills > 0) then
      raise exception '%도 한 번 이상 깨야 %에 들어갈 수 있습니다.', public.world_boss_rules() -> 'baekya' -> 'modes' ->> 'hard', public.world_ultimate_rules() -> 'boards' -> 'gapgwi' ->> 'name'; end if;
    return;
  end if;$n$);

select pg_temp.yh_patch('public.world_gw_settle(uuid,boolean)',
  $o$  if f.boss_id = 'baekya' then perform public.world_by_settle(p_fight, p_won); return; end if;$o$,
  $n$  if f.mode = 'ultimate' then perform public.world_ug_settle(p_fight, p_won); return; end if;
  if f.boss_id = 'baekya' then perform public.world_by_settle(p_fight, p_won); return; end if;$n$);

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$      if f.mode <> 'story' and coalesce(m.items_used, 0) >= 2 then$o$,
  $n$      if f.mode <> 'story' and coalesce(m.items_used, 0) >= (case when f.mode = 'ultimate' then coalesce((public.world_ug_cfg(p_fight) ->> 'items')::int, 3) else 2 end) then$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$        boss_heal := boss_heal + round(d * 0.5);$o$,
  $n$        boss_heal := boss_heal + round(d * 0.5);
        if f.mode = 'ultimate' then update public.world_gw_fights set board = jsonb_set(board, '{ug,double}', 'true') where fight_id = p_fight; end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'baekya' then boss_dmg := boss_dmg + public.world_by_mech(p_fight, r, broke, delayed, freed); end if;$o$,
  $n$  if f.mode = 'ultimate' then boss_dmg := boss_dmg + public.world_ug_mech(p_fight, r, boss_dmg, broke, delayed, freed); end if;
  if f.boss_id = 'baekya' then boss_dmg := boss_dmg + public.world_by_mech(p_fight, r, broke, delayed, freed); end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.hp <= 0 then update public.world_gw_fights set bfx = vbfx where fight_id = p_fight; perform public.world_gw_settle(p_fight, true); return; end if;$o$,
  $n$  if f.hp <= 0 and f.mode = 'ultimate' then update public.world_gw_fights set bfx = vbfx where fight_id = p_fight; perform public.world_ug_cleared(p_fight, r); return; end if;
  if f.hp <= 0 then update public.world_gw_fights set bfx = vbfx where fight_id = p_fight; perform public.world_gw_settle(p_fight, true); return; end if;
  if f.mode = 'ultimate' then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if public.world_ug_after(p_fight, r) then return; end if;
    select * into f from public.world_gw_fights where fight_id = p_fight;
  end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$    if f.boss_id = 'baekya' then raw := public.world_mk_raw(p_fight); end if;$o$,
  $n$    if f.boss_id = 'baekya' then raw := public.world_mk_raw(p_fight); end if;
    if f.mode = 'ultimate' then raw := public.world_ug_raw(p_fight); end if;$n$);

select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$    if f.mode <> 'story' and coalesce(me.items_used, 0) >= 2 then raise exception '이 싸움에서는 회복품을 두 개까지만 쓸 수 있습니다.'; end if;$o$,
  $n$    if f.mode = 'hard' and coalesce(me.items_used, 0) >= 2 then raise exception '이 싸움에서는 회복품을 두 개까지만 쓸 수 있습니다.'; end if;
    if f.mode = 'ultimate' and coalesce(me.items_used, 0) >= coalesce((public.world_ug_cfg(p_fight) ->> 'items')::int, 3) then
      raise exception '이 싸움에서는 회복품을 %개까지만 쓸 수 있습니다.', coalesce((public.world_ug_cfg(p_fight) ->> 'items')::int, 3); end if;$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if mk and p_action = 'call' and f.mech ->> 'k' is distinct from 'erase' then$o$,
  $n$  if mk and p_action = 'call' and f.mech ->> 'k' is distinct from 'erase' and f.mode <> 'ultimate' then$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$    if p_action = 'deal' and f.mech ->> 'deal' is distinct from uid::text then raise exception$o$,
  $n$    if p_action = 'deal' and f.mode = 'ultimate' and f.mech ->> 'deal' is distinct from uid::text then p_action := 'attack'; end if;
    if p_action = 'deal' and f.mech ->> 'deal' is distinct from uid::text then raise exception$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$    if p_action in ('item', 'coop') and coalesce(f.board -> 'block', '[]'::jsonb) ? p_action then$o$,
  $n$    if p_action in ('item', 'coop', 'brace') and coalesce(f.board -> 'block', '[]'::jsonb) ? p_action then$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if f.status <> 'fight' then return public.world_gw_snapshot(p_fight); end if;$o$,
  $n$  if f.status <> 'fight' then return public.world_gw_snapshot(p_fight); end if;
  if f.mech ->> 'k' = 'rest' then raise exception '막 사이에 숨을 고르는 중입니다. 다음 라운드에 고르세요.'; end if;$n$);

select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'board', case when f.boss_id = 'baekya' then$o$,
  $n$'board', case when f.mode = 'ultimate' then public.world_ug_view(fid, uid) when f.boss_id = 'baekya' then$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$      'mech', case f.mech ->> 'k' when 'chain' then jsonb_build_object('k', 'chain', 'colors', (select jsonb_agg(v order by v) from jsonb_each_text(f.mech -> 'colors') e(kk, v)), 'mine', f.mech -> 'colors' ->> uid::text,
        'aoe', f.mech -> 'aoe', 'tell', f.mech -> 'tell')
        when 'vortex' then f.mech - 'need' || jsonb_build_object('need', (f.mech ->> 'need')::int)
        else f.mech end,$o$,
  $n$      'mech', case when f.mode = 'ultimate' then jsonb_build_object('k', case when f.mech ->> 'k' in ('chain', 'rest') then f.mech ->> 'k' else 'normal' end)
        || case when f.mech ->> 'k' = 'chain' then jsonb_build_object('colors', (select jsonb_agg(v order by v) from jsonb_each_text(f.mech -> 'colors') e(kk, v)), 'mine', f.mech -> 'colors' ->> uid::text) else '{}'::jsonb end
        else case f.mech ->> 'k' when 'chain' then jsonb_build_object('k', 'chain', 'colors', (select jsonb_agg(v order by v) from jsonb_each_text(f.mech -> 'colors') e(kk, v)), 'mine', f.mech -> 'colors' ->> uid::text,
        'aoe', f.mech -> 'aoe', 'tell', f.mech -> 'tell')
        when 'vortex' then f.mech - 'need' || jsonb_build_object('need', (f.mech ->> 'need')::int)
        else f.mech end end,$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'tagged', f.boss_id = 'gapgwi' and$o$,
  $n$'tagged', f.mode <> 'ultimate' and f.boss_id = 'gapgwi' and$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'marked', f.boss_id = 'baekya' and$o$,
  $n$'marked', f.mode <> 'ultimate' and f.boss_id = 'baekya' and$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$    'items_left', case when f.mode = 'story' then null else greatest(0, 2 - coalesce(me.items_used, 0)) end,$o$,
  $n$    'items_left', case when f.mode = 'story' then null when f.mode = 'ultimate' then greatest(0, coalesce((public.world_ug_cfg(fid) ->> 'items')::int, 3) - coalesce(me.items_used, 0)) else greatest(0, 2 - coalesce(me.items_used, 0)) end,$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$    'falls_cap', case when f.mode = 'story' then null else 10 end$o$,
  $n$    'falls_cap', case when f.mode in ('story', 'ultimate') then null else 10 end$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$    'tips', case when coalesce(rec.kills, 0) > 0 then public.world_gw_tips(f.boss_id) end);$o$,
  $n$    'tips', case when f.mode <> 'ultimate' and coalesce(rec.kills, 0) > 0 then public.world_gw_tips(f.boss_id) end);$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$gsh jsonb; boss text := coalesce(p_boss, 'gwiheo'); br jsonb;$o$,
  $n$gsh jsonb; boss text := coalesce(p_boss, 'gwiheo'); br jsonb; ug_l jsonb; uwhy text;$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$      and (p_boss is null or x.boss_id = p_boss) order by x.created_at desc limit 1;$o$,
  $n$      and (p_boss is null or x.boss_id = p_boss or x.board -> 'ug' ->> 'board' = p_boss) order by x.created_at desc limit 1;$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$    return jsonb_build_object('none', true, 'boss', boss, 'story',$o$,
  $n$    if br -> 'ultimate' ? 'acts' then
      begin perform public.world_gw_ready_check(uid, boss, 'ultimate'); exception when others then uwhy := sqlerrm; end;
      ug_l := jsonb_build_object('name', public.world_ultimate_rules() -> 'boards' -> boss ->> 'name', 'tip', br -> 'ultimate' ->> 'tip', 'can_open', uwhy is null, 'why', uwhy,
        'kills', coalesce((select r.kills from public.world_gw_records r where r.owner_id = uid and r.boss_id = 'ug_' || boss), 0),
        'acts', (select jsonb_agg(a ->> 'name') from jsonb_array_elements(br -> 'ultimate' -> 'acts') a), 'party', public.world_ultimate_rules() -> 'party',
        'last', (select x.fight_id from public.world_gw_members m2 join public.world_gw_fights x using (fight_id)
            where m2.owner_id = uid and x.mode = 'ultimate' and x.boss_id = boss and x.status in ('won', 'failed') and x.created_at > now() - interval '1 day' order by x.created_at desc limit 1));
    end if;
    return coalesce(jsonb_build_object('ultimate', ug_l), '{}'::jsonb) || jsonb_build_object('none', true, 'boss', boss, 'story',$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'baekya' then v_who := '백야'; end if;$o$,
  $n$  if f.boss_id = 'baekya' then v_who := '백야'; end if;
  if f.boss_id = 'sealed_lord' then v_who := '봉주'; end if;$n$);

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$        perform public.world_gw_hit(p_fight, hit_who, raw, r, case when v_h > 1 then v_who || '의 다른 손아귀에' else v_who || '의 손아귀에' end, false);$o$,
  $n$        perform public.world_gw_hit(p_fight, hit_who, raw * case when f.mode = 'ultimate' then coalesce((public.world_boss_fight_rules(p_fight) -> 'board' ->> 'hand_mul')::numeric, 1) else 1 end, r, case when v_h > 1 then v_who || '의 다른 손아귀에' else v_who || '의 손아귀에' end, false);$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$        perform public.world_gw_hit(p_fight, cover_by, raw * 0.5, r,$o$,
  $n$        perform public.world_gw_hit(p_fight, cover_by, raw * 0.5 * case when f.mode = 'ultimate' then coalesce((public.world_boss_fight_rules(p_fight) -> 'board' ->> 'hand_mul')::numeric, 1) else 1 end, r,$n$);

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$      elsif tgt <> m.owner_id or random() < 0.3 then$o$,
  $n$      elsif tgt <> m.owner_id or (f.mode <> 'ultimate' and random() < 0.3) then$n$);

select pg_temp.yh_patch('public.world_gg_round(uuid)',
  $o$      if ph = 4 and coalesce((rb ->> 'compound')::boolean, false) then$o$,
  $n$      if (ph = 4 or coalesce((rb ->> 'compound_all')::boolean, false)) and coalesce((rb ->> 'compound')::boolean, false) then$n$);
select pg_temp.yh_patch('public.world_gg_round(uuid)',
  $o$      jat := nr + (rb ->> 'judge_lead')::int - 1;$o$,
  $n$      if coalesce((rb ->> 'judge_fixed')::boolean, false) then
        if b ? 'ug_rule' then rules := b -> 'ug_rule'; else b := b || jsonb_build_object('ug_rule', rules); end if;
      end if;
      jat := nr + (rb ->> 'judge_lead')::int - 1;$n$);

select pg_temp.yh_patch('public.world_gg_round(uuid)',
  $o$    b := b || jsonb_build_object('bargain', jsonb_build_object('t', tgt,$o$,
  $n$    if coalesce((rb ->> 'judge_fixed')::boolean, false) then
      if b ? 'ug_bt' then tgt := (b ->> 'ug_bt')::int; else b := b || jsonb_build_object('ug_bt', tgt); end if;
    end if;
    b := b || jsonb_build_object('bargain', jsonb_build_object('t', tgt,$n$);

select pg_temp.yh_patch('public.world_gg_mech(uuid,integer,boolean,boolean,uuid[])',
  $o$   where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest;
  for w in select x.* from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest and x.act ->> 'a' = 'deal' order by x.joined_at, x.owner_id loop$o$,
  $n$   where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest;
  if coalesce((rb ->> 'deal_force')::boolean, false) and f.mech ->> 'deal' is not null then
    update public.world_gw_members x set gval = (x.gval * (rb ->> 'deal_x')::int) % 10 where x.fight_id = p_fight and x.owner_id::text = f.mech ->> 'deal' and x.out_rounds = 0
       and x.act ->> 'a' is distinct from 'deal' returning x.name, x.gval into tn, tv;
    if tn is not null then perform public.world_gw_say(p_fight, p_round, 'seal', tn || ' — 값에 ' || (rb ->> 'deal_x') || '이 곱해져 ' || tv || '섬.'); tn := null; end if;
  end if;
  for w in select x.* from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest and x.act ->> 'a' = 'deal' order by x.joined_at, x.owner_id loop$n$);
select pg_temp.yh_patch('public.world_gg_mech(uuid,integer,boolean,boolean,uuid[])',
  $o$    tags := tags - w.t::text;$o$,
  $n$    if coalesce((rb ->> 'tag_move')::boolean, false) and tags ? w.t::text
       and not exists (select 1 from public.world_gw_members y where y.fight_id = p_fight and y.owner_id = w.t and y.act ->> 'a' = 'call' and y.act ->> 't' = w.owner_id::text) then
      tags := (tags - w.t::text) || jsonb_build_object(w.owner_id::text, 0);
      perform public.world_gw_say(p_fight, p_round, 'seal', '값표가 ' || w.name || '에게 옮겨 붙었다.');
    else
      tags := tags - w.t::text;
    end if;$n$);
select pg_temp.yh_patch('public.world_gg_mech(uuid,integer,boolean,boolean,uuid[])',
  $o$      '판결 — 「' || public.world_gg_rule_name(b -> 'judge' -> 'r', rb) || '은 거둔다」: '$o$,
  $n$      '판결 — ' || case when coalesce((rb ->> 'hide')::boolean, false) then '' else '「' || public.world_gg_rule_name(b -> 'judge' -> 'r', rb) || '은 거둔다」: ' end$n$);

select pg_temp.yh_patch('public.world_by_round(uuid)',
  $o$    select z into c from unnest(lamps) z where not exists (select 1 from jsonb_array_elements(dims) e where (e ->> 'c')::int = z) order by random() limit 1;
    if c is not null then
      at := nr + (rb ->> 'dim_lead')::int - 1;
      dims := dims || jsonb_build_array(jsonb_build_object('c', c, 'at', at));
      tell := tell || case when tell <> '' then ' ' else '' end || c || '번 자리 등롱이 파르르 깜빡인다. 흰 소매가 ' || (at - nr + 1) || '라운드 뒤 그 등을 덮으려 한다 — 그 자리에 서서 막아라.';
    end if;$o$,
  $n$    for c in select z from unnest(lamps) z where not exists (select 1 from jsonb_array_elements(dims) e where (e ->> 'c')::int = z) order by random() limit coalesce((rb -> 'dim_n' ->> (least(4, greatest(1, n)) - 1))::int, 1) loop
      at := nr + (rb ->> 'dim_lead')::int - 1;
      dims := dims || jsonb_build_array(jsonb_build_object('c', c, 'at', at));
      tell := tell || case when tell <> '' then ' ' else '' end || c || '번 자리 등롱이 파르르 깜빡인다. 흰 소매가 ' || (at - nr + 1) || '라운드 뒤 그 등을 덮으려 한다 — 그 자리에 서서 막아라.';
    end loop;$n$);
select pg_temp.yh_patch('public.world_by_round(uuid)',
  $o$        perform public.world_gw_say(p_fight, nr, 'info', '서하람: 이번엔 협동 기술 칸이 긁힐 뻔했어요.');
      end if;
    end if;$o$,
  $n$        perform public.world_gw_say(p_fight, nr, 'info', '서하람: 이번엔 협동 기술 칸이 긁힐 뻔했어요.');
      end if;
    end if;
    if rb ? 'scratch_brace_pct' and not coalesce(b -> 'scr', '{}'::jsonb) ? 'brace' and f.hp * 100 < f.max_hp * (rb ->> 'scratch_brace_pct')::numeric then
      b := b || jsonb_build_object('scr', coalesce(b -> 'scr', '{}'::jsonb) || '{"brace": true}'::jsonb, 'block', coalesce(b -> 'block', '[]'::jsonb) || '["brace"]'::jsonb);
      perform public.world_gw_say(p_fight, nr, 'bad', '긁힌 칸 — 버티기 칸이 긁혀 막혔습니다.');
    end if;$n$);
select pg_temp.yh_patch('public.world_by_mech(uuid,integer,boolean,boolean,uuid[])',
  $o$'제 이름을 거듭 외우자 긁힌 칸 하나가 풀렸습니다(' || case b -> 'block' ->> 0 when 'item' then '물품' else '협동 기술' end$o$,
  $n$'제 이름을 거듭 외우자 긁힌 칸 하나가 풀렸습니다(' || case b -> 'block' ->> 0 when 'item' then '물품' when 'brace' then '버티기' else '협동 기술' end$n$);
select pg_temp.yh_patch('public.world_by_mech(uuid,integer,boolean,boolean,uuid[])',
  $o$'모두가 서로를 부르자 긁힌 칸 하나가 풀렸습니다(' || case b -> 'block' ->> 0 when 'item' then '물품' else '협동 기술' end$o$,
  $n$'모두가 서로를 부르자 긁힌 칸 하나가 풀렸습니다(' || case b -> 'block' ->> 0 when 'item' then '물품' when 'brace' then '버티기' else '협동 기술' end$n$);

select pg_temp.yh_patch('public.world_mk_round(uuid)',
  $o$      mm := case when na > ng then 'attack' when ng > na then 'guard' else 'hesit' end;$o$,
  $n$      mm := case when na > ng then 'attack' when ng > na then 'guard' else 'hesit' end;
      if coalesce((rb ->> 'mimic_reverse')::boolean, false) and mm in ('attack', 'guard') then mm := case mm when 'attack' then 'guard' else 'attack' end; end if;$n$);
