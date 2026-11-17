create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
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
  "quest": "mdq_7", "quest_name": "명등기 7장", "item": "red_shrine_lacquer", "item_name": "붉은 사당 옻", "item_where": "붉은 사당 골목에서 채집해 얻습니다.",
  "min": 15, "hp_min": 8000, "hp_atk": 42, "hp_n": [1.0, 1.3, 0.8, 1.15], "raw_n": [1, 1.1, 0.8, 0.85], "raw": [40, 4], "enrage": 0.15,
  "first": {"gil": 2000, "xp": 0.5}, "again": {"gil": 150, "xp": 0.05}, "fail": {"dur": 10, "er": 10, "cd": 30}, "falls": 10, "xp_cap_lv": 50,
  "hard_quest": "mdq_8", "hard_quest_name": "명등기 8장 「끊긴 기름」",
  "modes": {"story": "이야기판", "hard": "깊은 장부"},
  "phases": ["장부 넘기기", "셈 거두기", "장부 맞추기", "가라앉는 배"],
  "story": {"min": 30, "round_s": 60, "hp_min": 2000, "hp_atk": 24, "hp_n": [1, 1, 1, 1], "raw": [12, 2], "first": {"gil": 1000},
    "board": {"tag_heal": 0.4, "judge_lead": 3, "judge_every": [0, 5, 5, 4], "judge_off": [0, 1, 2, 0], "judge_raw": 14, "judge_tag": false, "compound": false,
      "bargain_tol": 1, "bargain_show": true, "bargain_heal_pct": 3, "deal": false, "close_rounds": 0, "guide": true}},
  "board": {
    "delta": {"attack": 3, "guard": 1, "brace": -2, "item": 0, "coop": 2, "call": 0},
    "start": [0, 9],
    "tag_every": 5, "tag_heal": 0.8, "tag_brace": 2,
    "judge_every": [0, 4, 4, 2], "judge_off": [0, 1, 2, 0], "judge_lead": 2, "judge_raw": 48, "judge_tag": true, "compound": true,
    "rules": {
      "even": {"name": "짝수 섬", "v": [0, 2, 4, 6, 8]},
      "odd": {"name": "홀수 섬", "v": [1, 3, 5, 7, 9]},
      "tri": {"name": "셋으로 나누어떨어지는 섬", "v": [0, 3, 6, 9]},
      "gt5": {"name": "다섯 섬 넘는 섬", "v": [6, 7, 8, 9]},
      "lt4": {"name": "네 섬 아래인 섬", "v": [0, 1, 2, 3]}},
    "single": ["even", "odd", "tri", "gt5", "lt4"],
    "pairs": [["even", "gt5"], ["odd", "gt5"], ["even", "tri"], ["odd", "tri"], ["tri", "gt5"], ["even", "lt4"], ["odd", "lt4"], ["tri", "lt4"]],
    "bargain_every": 6, "bargain_rounds": 3, "bargain_tol": 0, "bargain_show": false, "bargain_span": 6,
    "bargain_pct": 6, "broke_rounds": 3, "broke_pct": 30, "bargain_heal_pct": 8,
    "deal": true, "deal_every": 4, "deal_off": 2, "deal_mul": 2.5, "deal_x": 3,
    "close_rounds": 6, "low_pct": 10, "guide": false},
  "solo": {"artificer": {"solo_dmg": -40, "solo_guard": -24}, "scout": {"solo_dmg": -25, "solo_guard": -46}, "exorcist": {"solo_dmg": -41, "solo_guard": -16},
    "medic": {"solo_dmg": -30, "solo_guard": -55}, "sealmaster": {"solo_dmg": -42, "solo_guard": -32}, "analyst": {"solo_dmg": -25, "solo_guard": -36},
    "tamer": {"solo_dmg": -25, "solo_guard": -46}}
}$j$::jsonb));
end $$;

create or replace function public.world_solo_aid(p_job text, p_boss text)
 returns jsonb language sql immutable set search_path = ''
as $f$ select case when public.world_boss_rules() -> p_boss ? 'solo' then coalesce(public.world_boss_rules() -> p_boss -> 'solo' -> p_job, '{}'::jsonb) else public.world_solo_aid(p_job) end $f$;

create or replace function public.world_gg_next(p_v integer, p_act text, p_rb jsonb)
 returns integer language sql immutable set search_path = ''
as $f$ select case when p_v is null then null when p_act = 'deal' then (p_v * (p_rb ->> 'deal_x')::int) % 10
  else ((p_v + coalesce((p_rb -> 'delta' ->> coalesce(p_act, 'guard'))::int, 0)) % 10 + 10) % 10 end $f$;

create or replace function public.world_gg_hit(p_rules jsonb, p_v integer, p_rb jsonb)
 returns boolean language sql immutable set search_path = ''
as $f$ select p_v is not null and jsonb_array_length(coalesce(p_rules, '[]'::jsonb)) > 0
  and not exists (select 1 from jsonb_array_elements_text(p_rules) k where not ((p_rb -> 'rules' -> k -> 'v') @> to_jsonb(p_v))) $f$;

create or replace function public.world_gg_rule_name(p_rules jsonb, p_rb jsonb)
 returns text language sql immutable set search_path = ''
as $f$ select string_agg(p_rb -> 'rules' -> k ->> 'name', '이면서 ' order by o) from jsonb_array_elements_text(p_rules) with ordinality e(k, o) $f$;

create or replace function public.world_gg_begin(p_fight uuid, p_n integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; lo int := (rb -> 'start' ->> 0)::int; hi int := (rb -> 'start' ->> 1)::int; x record; v int;
begin
  for x in select owner_id from public.world_gw_members where fight_id = p_fight order by joined_at, owner_id loop
    v := lo + floor(random() * (hi - lo + 1))::int;
    update public.world_gw_members set gval = v where fight_id = p_fight and owner_id = x.owner_id;
  end loop;
  update public.world_gw_fights set board = jsonb_build_object('tags', '{}'::jsonb, 'broke', 0, 'low', false, 'guided', false) where fight_id = p_fight;
  perform public.world_gw_say(p_fight, 0, 'phase', '사당 마룻바닥 밑에서 젖은 장부 수천 권이 기어 나와 한데 엉긴다. 낱장이 비늘처럼 겹친 덩어리가 주판알 이빨을 딸깍인다. 「한 줄에 쌀 두 섬. 값을 치르면 도장을 찍어 주지.」');
  perform public.world_gw_say(p_fight, 0, 'phase', '저마다의 머리 위에 희미한 먹 글씨가 떠오른다. 「쌀 몇 섬」 — 값귀가 매긴 값이다. 움직일 때마다 값이 바뀐다(공격 +3 · 방어 +1 · 버티기 −2 · 협동 기술 +2 · 물품 그대로 · 부르기는 서로 맞바꿈, 열을 넘으면 일의 자리만).');
  perform public.world_gw_say(p_fight, 0, 'phase', case when p_n = 1 then '장부는 혼자 선 이의 값을 하나하나 셈해 둔다.' else '함께 선 이들의 값이 한 장부에 나란히 적힌다.' end);
end $f$;

create or replace function public.world_gg_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb; b jsonb; nr int; ph int; m jsonb; tell text := ''; aoe boolean := false;
  alive uuid[]; n int; na int; t uuid; tname text; every int; off int; rules jsonb; jat int; sm int; tgt int; span int; len int := 5; judging boolean := false; story boolean;
  ex record; ex_a text; ex_v int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  rb := br -> 'board'; b := coalesce(f.board, '{}'::jsonb); nr := f.round + 1; story := f.mode = 'story';
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select array_agg(owner_id order by random()) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  na := coalesce(array_length(alive, 1), 0);
  if ph <> f.phase then
    perform public.world_gw_say(p_fight, nr, 'phase', case ph
      when 2 then '값귀가 장부를 거두어 든다. 주판알이 딸깍딸깍 맞부딪친다. 「이제 셈을 거둔다. 내가 외치는 값은 거두어 가마.」'
      when 3 then '값귀가 낱장을 펼쳐 저울처럼 든다. 「장부를 맞춰 보자. 합이 맞으면 덮어 주마. 안 맞으면 물 밑 장부에서 값을 더 꺼내 오지.」'
      else '사당 밑 곳간에 물이 차오른다. 배 무덤의 물이 장부를 적신다. 「장이 파한다. 파하기 전에 셈을 끝내자.」' end);
    f.cycle := 0;
    if ph = 4 and coalesce((rb ->> 'close_rounds')::int, 0) > 0 and not b ? 'close_at' then
      b := b || jsonb_build_object('close_at', nr + (rb ->> 'close_rounds')::int - 1);
      perform public.world_gw_say(p_fight, nr, 'warn', '장날 마감까지 ' || (rb ->> 'close_rounds') || '라운드. 그 안에 값귀를 쓰러뜨리지 못하면 장부가 물 밑으로 가라앉습니다.');
    end if;
  end if;
  m := jsonb_build_object('k', 'normal', 'phase_name', br -> 'phases' ->> (ph - 1));
  if ph = 1 and na > 0 and f.cycle % (rb ->> 'tag_every')::int = (rb ->> 'tag_every')::int - 1 then
    select a into t from unnest(alive) a where not (coalesce(b -> 'tags', '{}'::jsonb) ? a::text) limit 1;
    if t is not null then
      select name into tname from public.world_gw_members where fight_id = p_fight and owner_id = t;
      b := b || jsonb_build_object('tags', coalesce(b -> 'tags', '{}'::jsonb) || jsonb_build_object(t::text, 0));
      tell := '값귀가 ' || tname || '의 어깨에 「쌀 두 섬」 값표를 철썩 붙인다. 값표가 붙은 채 휘두른 힘은 장부로 새어 값귀를 낫게 한다. '
        || case when n = 1 then '버티기를 두 번 하면 떨어질 것 같다.' else '누군가 그 이름을 「부르면」 값표를 떼어 낼 수 있다(값도 서로 맞바뀐다).' end;
    end if;
  end if;
  if b ? 'judge' and (b -> 'judge' ->> 'at')::int >= nr then
    jat := (b -> 'judge' ->> 'at')::int; rules := b -> 'judge' -> 'r';
    tell := tell || case when tell <> '' then ' ' else '' end || case when jat = nr
      then '값귀가 주판을 내리친다. 「' || public.world_gg_rule_name(rules, rb) || '은 거둔다!」 이번 라운드 끝의 값으로 판결한다.'
      else '「' || public.world_gg_rule_name(rules, rb) || '은 거둔다.」 판결까지 ' || (jat - nr + 1) || '라운드.' end;
  elsif ph >= 2 and na > 0 then
    every := coalesce((rb -> 'judge_every' ->> (ph - 1))::int, 0); off := coalesce((rb -> 'judge_off' ->> (ph - 1))::int, 0);
    if every > 0 and f.cycle % every = off then
      if ph = 4 and coalesce((rb ->> 'compound')::boolean, false) then
        rules := rb -> 'pairs' -> floor(random() * jsonb_array_length(rb -> 'pairs'))::int;
      else
        rules := jsonb_build_array(rb -> 'single' ->> floor(random() * jsonb_array_length(rb -> 'single'))::int);
      end if;
      jat := nr + (rb ->> 'judge_lead')::int - 1;
      b := b || jsonb_build_object('judge', jsonb_build_object('r', rules, 'at', jat));
      tell := tell || case when tell <> '' then ' ' else '' end || '값귀가 낱장을 넘기며 외친다. 「' || public.world_gg_rule_name(rules, rb) || '은 거둔다!」 '
        || (jat - nr + 1) || '라운드 뒤 그 라운드 끝의 값으로 판결한다. 값을 규칙 밖으로 옮겨 두어라.';
      if coalesce((rb ->> 'guide')::boolean, false) and not coalesce((b ->> 'guided')::boolean, false) then
        select x.name, x.gval into ex from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and x.gval is not null
          order by public.world_gg_hit(rules, x.gval, rb) desc, x.joined_at limit 1;
        select k, public.world_gg_next(ex.gval, k, rb) into ex_a, ex_v from unnest(array['guard', 'brace', 'attack', 'item']) with ordinality u(k, o)
          where not public.world_gg_hit(rules, public.world_gg_next(ex.gval, k, rb), rb) order by o limit 1;
        if ex.name is not null then
          perform public.world_gw_say(p_fight, nr, 'info', '서하람: 머리 위 값을 보세요! ' || ex.name || ' 님은 지금 ' || ex.gval || '섬이니까 '
            || case when public.world_gg_hit(rules, ex.gval, rb) then public.world_gg_rule_name(rules, rb) || '에 걸려요. ' else '아직은 괜찮아요. ' end
            || case when ex_a is not null then case ex_a when 'guard' then '방어' when 'brace' then '버티기' when 'attack' then '공격' else '물품' end || '하면 ' || ex_v || '섬!' else '' end);
          b := b || '{"guided": true}'::jsonb;
        end if;
      end if;
    end if;
  end if;
  if b ? 'judge' then
    m := m || jsonb_build_object('judge', jsonb_build_object('rules', b -> 'judge' -> 'r', 'name', public.world_gg_rule_name(b -> 'judge' -> 'r', rb), 'at', (b -> 'judge' ->> 'at')::int,
      'left', (b -> 'judge' ->> 'at')::int - nr));
    judging := (b -> 'judge' ->> 'at')::int = nr;
  end if;
  if ph >= 3 and not b ? 'bargain' and na > 0 and ph = 3 and f.cycle % (rb ->> 'bargain_every')::int = 0 then
    select coalesce(sum(gval), 0) into sm from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
    span := (rb ->> 'bargain_span')::int;
    if n = 1 then
      select z into tgt from generate_series(0, 9) z where z <> sm order by random() limit 1;
    else
      select z into tgt from generate_series(greatest(0, sm - span), least(9 * n, sm + span)) z where abs(z - sm) > coalesce((rb ->> 'bargain_tol')::int, 0) order by random() limit 1;
    end if;
    b := b || jsonb_build_object('bargain', jsonb_build_object('t', tgt, 'at', nr + (rb ->> 'bargain_rounds')::int - 1));
    tell := tell || case when tell <> '' then ' ' else '' end || '값귀가 장부를 펼쳐 든다. 「모두의 값을 더해 ' || tgt || '섬' || case when coalesce((rb ->> 'bargain_tol')::int, 0) > 0 then '(앞뒤 ' || (rb ->> 'bargain_tol') || '섬까지)' else '' end
      || '이 되면 장부를 덮어 주마.」 ' || (rb ->> 'bargain_rounds') || '라운드 안에 값의 합을 맞춰야 한다.';
  end if;
  if b ? 'bargain' then
    m := m || jsonb_build_object('bargain', jsonb_build_object('target', (b -> 'bargain' ->> 't')::int, 'tol', coalesce((rb ->> 'bargain_tol')::int, 0),
      'at', (b -> 'bargain' ->> 'at')::int, 'left', (b -> 'bargain' ->> 'at')::int - nr));
    if not tell like '%장부를 펼쳐 든다%' then
      tell := tell || case when tell <> '' then ' ' else '' end || '「합이 ' || (b -> 'bargain' ->> 't') || '섬이면 덮어 주마.」 장부 맞추기 ' || ((b -> 'bargain' ->> 'at')::int - nr + 1) || '라운드 남음.';
    end if;
  end if;
  if ph = 3 and coalesce((rb ->> 'deal')::boolean, false) and na > 0 and f.cycle % (rb ->> 'deal_every')::int = (rb ->> 'deal_off')::int then
    t := alive[1];
    select name into tname from public.world_gw_members where fight_id = p_fight and owner_id = t;
    m := m || jsonb_build_object('deal', t);
    tell := tell || case when tell <> '' then ' ' else '' end || '값귀가 ' || tname || '에게 주판을 내민다. 「네 값에 ' || (rb ->> 'deal_x') || '을 곱해 주마(일의 자리만). 받으면 이번 한 번은 힘을 크게 실어 주지.」';
  end if;
  if b ? 'close_at' then
    m := m || jsonb_build_object('close', jsonb_build_object('at', (b ->> 'close_at')::int, 'left', (b ->> 'close_at')::int - nr));
    tell := tell || case when tell <> '' then ' ' else '' end || '장날 마감까지 ' || ((b ->> 'close_at')::int - nr + 1) || '라운드.';
  end if;
  if coalesce((b ->> 'broke')::int, 0) > 0 then m := m || jsonb_build_object('broke', (b ->> 'broke')::int); end if;
  if not judging and nr % coalesce((rb ->> 'aoe_every')::int, 4) = 0 then
    aoe := true;
    tell := tell || case when tell <> '' then ' — ' else '' end || '값귀가 장부를 통째로 펼치려 한다. 낱장이 한꺼번에 휘몰아칠 것 같다. 몰려올 것에 대비하라.';
  end if;
  if tell = '' then tell := '값귀가 주판알을 딸깍인다. 「한 줄에 쌀 두 섬. 한 줄에 쌀 두 섬.」'; end if;
  m := m || jsonb_build_object('aoe', aoe, 'tell', tell);
  if judging or m ? 'deal' or b ? 'bargain' then len := 10; end if;
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when not story then len when n = 1 then 86400 else (br ->> 'round_s')::int end), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, nr, case when aoe or judging or m ? 'deal' or tell like '%장부를 펼쳐 든다%' or tell like '%값표를 철썩%' then 'warn' else 'tell' end, tell);
end $f$;

create or replace function public.world_gg_on_attack(p_fight uuid, p_uid uuid, p_round integer, p_d numeric)
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; d numeric := p_d; h int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  if coalesce((f.board ->> 'broke')::int, 0) > 0 then d := d * (1 + (rb ->> 'broke_pct')::numeric / 100.0); end if;
  if me.act ->> 'a' = 'deal' then
    d := d * (rb ->> 'deal_mul')::numeric;
    perform public.world_gw_say(p_fight, p_round, 'good', me.name || ' — 값귀의 흥정을 받아 값에 ' || (rb ->> 'deal_x') || '을 곱한 힘을 싣습니다.');
  end if;
  if coalesce(f.board -> 'tags', '{}'::jsonb) ? p_uid::text then
    h := round(d * (rb ->> 'tag_heal')::numeric);
    if h > 0 then
      update public.world_gw_fights set hp = least(max_hp, hp + h), updated_at = now() where fight_id = p_fight;
      perform public.world_gw_say(p_fight, p_round, 'bad', me.name || ' — 붙은 값표로 힘이 장부에 새어 값귀가 ' || h || ' 낫습니다.');
    end if;
  end if;
  return d;
end $f$;

create or replace function public.world_gg_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype; b jsonb; tags jsonb; w record; tv int; tn text; n int; sm int; tol int;
  hits text[] := '{}'; safe text[] := '{}'; extra numeric := 0; h int; raw numeric;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := f.board; tags := coalesce(b -> 'tags', '{}'::jsonb);
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  if coalesce((b ->> 'broke')::int, 0) > 0 then b := b || jsonb_build_object('broke', (b ->> 'broke')::int - 1); end if;
  update public.world_gw_members x set gval = public.world_gg_next(x.gval, coalesce(x.act ->> 'a', 'guard'), rb)
   where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest;
  for w in select x.* from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest and x.act ->> 'a' = 'deal' order by x.joined_at, x.owner_id loop
    perform public.world_gw_say(p_fight, p_round, 'info', w.name || ' — 값에 ' || (rb ->> 'deal_x') || '을 곱해 ' || w.gval || '섬이 되었습니다.');
  end loop;
  for w in select x.owner_id, x.name, (x.act ->> 't')::uuid t from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest and x.act ->> 'a' = 'call'
            and nullif(x.act ->> 't', '') is not null and (x.act ->> 't')::uuid <> x.owner_id order by x.joined_at, x.owner_id loop
    select gval, name into tv, tn from public.world_gw_members where fight_id = p_fight and owner_id = w.t;
    if tn is null then continue; end if;
    select gval into h from public.world_gw_members where fight_id = p_fight and owner_id = w.owner_id;
    update public.world_gw_members set gval = tv where fight_id = p_fight and owner_id = w.owner_id;
    update public.world_gw_members set gval = h where fight_id = p_fight and owner_id = w.t;
    perform public.world_gw_say(p_fight, p_round, 'good', w.name || ' — 「' || tn || '!」 이름을 불러 값을 맞바꿉니다(' || w.name || ' ' || tv || '섬 · ' || tn || ' ' || h || '섬).'
      || case when tags ? w.t::text then ' ' || tn || '의 값표가 떨어졌습니다.' else '' end);
    tags := tags - w.t::text;
  end loop;
  for w in select x.owner_id, x.name, x.act ->> 'a' a from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest and tags ? x.owner_id::text loop
    if n = 1 and w.a = 'brace' then
      if (tags ->> w.owner_id::text)::int + 1 >= (rb ->> 'tag_brace')::int then
        tags := tags - w.owner_id::text;
        perform public.world_gw_say(p_fight, p_round, 'good', w.name || ' — 몸을 낮춰 버티는 사이 값표가 젖어 떨어졌습니다.');
      else
        tags := tags || jsonb_build_object(w.owner_id::text, (tags ->> w.owner_id::text)::int + 1);
        perform public.world_gw_say(p_fight, p_round, 'guard', w.name || ' — 버티는 사이 값표 한 귀퉁이가 들렸습니다. 한 번 더 버티면 떨어질 것 같습니다.');
      end if;
    end if;
  end loop;
  if b ? 'judge' and (b -> 'judge' ->> 'at')::int <= p_round then
    raw := (rb ->> 'judge_raw')::numeric * case when p_broke then 0.5 else 1 end * case when p_delayed then 0.5 else 1 end
      * (1 + (public.world_boss_fight_rules(p_fight) ->> 'enrage')::numeric * f.enrage);
    for w in select x.owner_id, x.name, x.gval from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not x.rest order by x.joined_at, x.owner_id loop
      if public.world_gg_hit(b -> 'judge' -> 'r', w.gval, rb) then
        hits := hits || (w.name || ' ' || w.gval || '섬');
        perform public.world_gw_hit(p_fight, w.owner_id, raw, p_round, '값귀의 판결에 값을 거두어져', true);
        if coalesce((rb ->> 'judge_tag')::boolean, false) and not tags ? w.owner_id::text then tags := tags || jsonb_build_object(w.owner_id::text, 0); end if;
      else
        safe := safe || (w.name || ' ' || w.gval || '섬');
      end if;
    end loop;
    perform public.world_gw_say(p_fight, p_round, case when cardinality(hits) = 0 then 'good' else 'bad' end,
      '판결 — 「' || public.world_gg_rule_name(b -> 'judge' -> 'r', rb) || '은 거둔다」: '
      || case when cardinality(hits) > 0 then '거둠 ' || array_to_string(hits, ', ') || case when coalesce((rb ->> 'judge_tag')::boolean, false) then '(값표가 붙음)' else '' end else '' end
      || case when cardinality(hits) > 0 and cardinality(safe) > 0 then ' · ' else '' end
      || case when cardinality(safe) > 0 then '무사 ' || array_to_string(safe, ', ') else '' end || '.'
      || case when p_broke then ' (퇴마 결계가 판결을 절반으로 꺾었습니다)' else '' end || case when p_delayed then ' (흐름이 끊긴 주판이 덜 거둡니다)' else '' end);
    b := b - 'judge';
  end if;
  if b ? 'bargain' then
    select coalesce(sum(gval), 0) into sm from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
    tol := coalesce((rb ->> 'bargain_tol')::int, 0);
    if abs(sm - (b -> 'bargain' ->> 't')::int) <= tol then
      extra := round(f.max_hp * (rb ->> 'bargain_pct')::numeric / 100.0);
      b := (b - 'bargain') || jsonb_build_object('broke', (rb ->> 'broke_rounds')::int);
      perform public.world_gw_say(p_fight, p_round, 'good', '값의 합이 ' || sm || '섬 — 장부가 맞았습니다! 값귀가 제 장부를 덮으며 무너져 ' || extra || '의 피해를 입고, '
        || (rb ->> 'broke_rounds') || '라운드 동안 받는 피해가 ' || (rb ->> 'broke_pct') || '% 늘어납니다.');
    elsif (b -> 'bargain' ->> 'at')::int <= p_round then
      h := round(f.max_hp * (rb ->> 'bargain_heal_pct')::numeric / 100.0);
      update public.world_gw_fights set hp = least(max_hp, hp + h), enrage = enrage + case when f.mode = 'story' then 0 else 1 end, updated_at = now() where fight_id = p_fight;
      b := b - 'bargain';
      perform public.world_gw_say(p_fight, p_round, 'bad', '값의 합이 ' || sm || '섬 — 장부가 맞지 않았습니다. 값귀가 물 밑 장부에서 값을 꺼내 ' || h || ' 회복합니다'
        || case when f.mode = 'story' then '.' else '. 주판알이 더 사납게 딸깍입니다.' end);
    end if;
  end if;
  update public.world_gw_fights set board = b || jsonb_build_object('tags', tags) where fight_id = p_fight;
  return extra;
end $f$;

create or replace function public.world_gg_after(p_fight uuid, p_round integer)
 returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare rb jsonb := public.world_boss_fight_rules(p_fight) -> 'board'; f public.world_gw_fights%rowtype;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return true; end if;
  if not coalesce((f.board ->> 'low')::boolean, false) and f.hp > 0 and f.hp * 100 < f.max_hp * (rb ->> 'low_pct')::numeric then
    perform public.world_gw_say(p_fight, p_round, 'boss', '값귀의 낱장이 하나둘 하얗게 바랜다. 주판알이 헛돈다. 「한 줄에 쌀 두… 두…」');
    update public.world_gw_fights set board = board || '{"low": true}'::jsonb where fight_id = p_fight;
  end if;
  if f.board ? 'close_at' and p_round >= (f.board ->> 'close_at')::int and f.hp > 0 then
    perform public.world_gw_say(p_fight, p_round, 'bad', '장날이 파했습니다. 물이 곳간을 채우고 값귀가 장부를 안은 채 물 밑으로 가라앉습니다.');
    perform public.world_gw_settle(p_fight, false);
    return true;
  end if;
  return false;
end $f$;

create or replace function public.world_gg_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare br jsonb := public.world_boss_fight_rules(p_fight); rb jsonb := br -> 'board'; f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; sm int; b jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  b := coalesce(f.board, '{}'::jsonb);
  select coalesce(sum(gval), 0) into sm from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
  return jsonb_build_object(
    'phase_name', br -> 'phases' ->> (f.phase - 1), 'phases', br -> 'phases',
    'vals', (select coalesce(jsonb_object_agg(x.owner_id::text, x.gval), '{}'::jsonb) from public.world_gw_members x where x.fight_id = p_fight),
    'mine', me.gval,
    'preview', case when me.gval is not null then jsonb_build_object('attack', public.world_gg_next(me.gval, 'attack', rb), 'guard', public.world_gg_next(me.gval, 'guard', rb),
      'brace', public.world_gg_next(me.gval, 'brace', rb), 'item', public.world_gg_next(me.gval, 'item', rb), 'coop', public.world_gg_next(me.gval, 'coop', rb))
      || case when f.mech ->> 'deal' = p_uid::text then jsonb_build_object('deal', public.world_gg_next(me.gval, 'deal', rb)) else '{}'::jsonb end end,
    'call', (select coalesce(jsonb_object_agg(x.owner_id::text, x.gval), '{}'::jsonb) from public.world_gw_members x where x.fight_id = p_fight and x.owner_id <> p_uid),
    'delta', rb -> 'delta', 'deal_x', (rb ->> 'deal_x')::int,
    'judge', case when b ? 'judge' then jsonb_build_object('rules', b -> 'judge' -> 'r', 'name', public.world_gg_rule_name(b -> 'judge' -> 'r', rb),
      'at', (b -> 'judge' ->> 'at')::int, 'left', (b -> 'judge' ->> 'at')::int - f.round,
      'vals', (select jsonb_agg(z order by z) from generate_series(0, 9) z where public.world_gg_hit(b -> 'judge' -> 'r', z, rb))) end,
    'bargain', case when b ? 'bargain' then jsonb_build_object('target', (b -> 'bargain' ->> 't')::int, 'tol', coalesce((rb ->> 'bargain_tol')::int, 0),
      'at', (b -> 'bargain' ->> 'at')::int, 'left', (b -> 'bargain' ->> 'at')::int - f.round)
      || case when coalesce((rb ->> 'bargain_show')::boolean, false) then jsonb_build_object('sum', sm) else '{}'::jsonb end end,
    'tags', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(coalesce(b -> 'tags', '{}'::jsonb)) k),
    'tag_brace', case when b -> 'tags' ? p_uid::text then jsonb_build_object('done', (b -> 'tags' ->> p_uid::text)::int, 'need', (rb ->> 'tag_brace')::int) end,
    'deal', f.mech ->> 'deal', 'deal_mine', f.mech ->> 'deal' = p_uid::text,
    'close', case when b ? 'close_at' then jsonb_build_object('at', (b ->> 'close_at')::int, 'left', (b ->> 'close_at')::int - f.round) end,
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

revoke all on function public.world_gg_next(integer, text, jsonb), public.world_gg_hit(jsonb, integer, jsonb), public.world_gg_rule_name(jsonb, jsonb),
  public.world_gg_begin(uuid, integer), public.world_gg_round(uuid), public.world_gg_on_attack(uuid, uuid, integer, numeric),
  public.world_gg_mech(uuid, integer, boolean, boolean, uuid[]), public.world_gg_after(uuid, integer), public.world_gg_view(uuid, uuid),
  public.world_gg_settle(uuid, boolean) from public, anon, authenticated;
grant execute on function public.world_gg_next(integer, text, jsonb), public.world_gg_hit(jsonb, integer, jsonb), public.world_gg_rule_name(jsonb, jsonb),
  public.world_gg_begin(uuid, integer), public.world_gg_round(uuid), public.world_gg_on_attack(uuid, uuid, integer, numeric),
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
  $o$a := coalesce(m.act, '{"a":"guard"}'::jsonb); av := a ->> 'a';$o$,
  $n$a := coalesce(m.act, '{"a":"guard"}'::jsonb); av := a ->> 'a';
    if av = 'deal' then av := 'attack'; end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$      if f.boss_id = 'mukjeok' then d := d * public.world_mk_on_attack(p_fight, m.owner_id, r);$o$,
  $n$      if f.boss_id = 'gapgwi' then d := public.world_gg_on_attack(p_fight, m.owner_id, r, d);
      elsif f.boss_id = 'mukjeok' then d := d * public.world_mk_on_attack(p_fight, m.owner_id, r);$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$elsif av = 'call' and (f.boss_id = 'mukjeok' or f.mode = 'story') then$o$,
  $n$elsif av = 'call' and (f.boss_id in ('mukjeok', 'gapgwi') or f.mode = 'story') then$n$);
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
    if p_action = 'call' and (p_target is null or p_target = uid) then raise exception '값을 맞바꿀 동료를 고르세요.'; end if;
    if p_action = 'deal' and f.mech ->> 'deal' is distinct from uid::text then raise exception '값귀가 흥정을 걸어 온 사람만 받을 수 있습니다.'; end if;
  end if;$n$);

select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'board', case when f.boss_id = 'mukjeok' then$o$,
  $n$'board', case when f.boss_id = 'gapgwi' then public.world_gg_view(fid, uid) when f.boss_id = 'mukjeok' then$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$'pos', m.pos, 'bound',$o$,
  $n$'pos', m.pos, 'val', m.gval, 'tagged', f.boss_id = 'gapgwi' and coalesce(f.board -> 'tags', '{}'::jsonb) ? m.owner_id::text, 'bound',$n$);

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
    '값(섬): 저마다 머리 위에 0~9섬의 값이 붙는다. 공격 +3 · 방어 +1 · 버티기 −2 · 협동 기술 +2 · 물품 그대로, 열을 넘으면 일의 자리만 남는다. 「부르기」는 고른 동료와 값을 맞바꾼다. 행동 단추에 고른 뒤의 값이 미리 적힌다.',
    '값표(1단계): 「쌀 두 섬」 값표가 붙은 사람이 휘두른 힘은 일부가 값귀를 낫게 한다. 다른 사람이 그 이름을 부르면 떨어진다(값도 맞바뀐다). 혼자라면 버티기를 두 번.',
    '판결(2단계부터): 값귀가 「짝수 섬」·「셋으로 나누어떨어지는 섬」·「다섯 섬 넘는 섬」 같은 규칙을 미리 외친다. 판결 라운드 끝의 값이 규칙에 맞으면 큰 피해를 입고 값표가 붙는다. 남은 라운드 동안 행동을 골라 값을 규칙 밖으로 옮긴다.',
    '장부 맞추기(3단계): 정해진 라운드 안에 모두의 값을 더한 합을 목표에 맞추면 값귀가 크게 무너지고 잠시 더 아파한다. 못 맞추면 값귀가 체력을 되찾는다. 누가 공격하고 누가 버틸지 나눠 맡고, 부르기로 값을 맞바꿔 맞춘다.',
    '곱셈 흥정: 값귀가 한 사람에게 「값에 셋을 곱해 주마」를 건다. 받으면 그 라운드 공격이 크게 세지지만 값이 ×3(일의 자리)으로 바뀐다 — 받기 전에 다음 판결과 합에 맞는지 셈해 본다.',
    '가라앉는 배(4단계): 장날 마감까지 정해진 라운드 안에 쓰러뜨려야 한다. 판결이 두 규칙을 겹쳐(「짝수이면서 다섯 넘는」) 더 자주 온다.')
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
