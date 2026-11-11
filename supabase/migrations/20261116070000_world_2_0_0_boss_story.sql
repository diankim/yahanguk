lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_boss_rules', array[
$a$"fail": {"dur": 10, "er": 10, "cd": 30}, "falls": 10},
  "mukjeok"$a$,
$b$"fail": {"dur": 10, "er": 10, "cd": 30}, "falls": 10,
    "modes": {"story": "이야기판", "hard": "깊은 귀허"},
    "story": {"min": 30, "round_s": 60, "hp_min": 1500, "hp_atk": 22, "hp_n": [1, 1, 1, 1], "raw": [10, 2], "first": {"gil": 800},
      "phases": ["물거울", "한 줄 사슬", "흐린 이름", "잔물결"],
      "sm": {"mirror_every": 3, "mirror_mul": 0.5, "crack_pct": 30, "chain_every": 4, "chain_raw": 12, "blur_every": 4, "blur_mul": 0.5, "blur_rounds": 3,
        "tide_every": 4, "tide_raw": 12, "aoe_every": 5}}},
  "mukjeok"$b$,
$a$"story": {"min": 120, "round_s": 60, "hp_min": 3600, "hp_atk": 20, "raw": [22, 3], "first": {"gil": 1000},
      "board": {"line_strokes": 1, "erase_strokes": 2, "line_raw": 26, "erase_raw": 28, "mimic_raw": 7, "bound_raw": 6, "aoe_mul": 0.6}},$a$,
$b$"modes": {"story": "이야기판", "hard": "깊은 명부"},
    "story": {"min": 30, "round_s": 60, "hp_min": 1500, "hp_atk": 28, "hp_n": [1, 1, 1, 1], "raw": [10, 2], "first": {"gil": 1000},
      "phases": ["먹방울", "찍어 둔 칸", "먹 웅덩이", "이름 지키기"],
      "sm": {"drop_every": 3, "drop_raw": 12, "mark_every": 5, "mark_wait": 3, "pool_raw": 8, "keep_every": 4, "keep_pct": 5, "keep_raw": 10, "aoe_every": 5}},$b$]);

create or replace function public.world_boss_fight_rules(p_fight uuid)
 returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $f$
  select case when x.md = 'story' then (x.r - 'story') || ((x.r -> 'story') - 'board') || jsonb_build_object('board', coalesce(x.r -> 'board', '{}'::jsonb) || coalesce(x.r -> 'story' -> 'board', '{}'::jsonb))
    else x.r end
  from (select public.world_boss_rules() -> coalesce(f.boss_id, 'mukjeok') as r, f.mode as md
        from (select 1) o left join public.world_gw_fights f on f.fight_id = p_fight) x
$f$;
revoke all on function public.world_boss_fight_rules(uuid) from public, anon, authenticated;

create or replace function public.world_mk_rules(p_fight uuid)
 returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $f$ select public.world_boss_fight_rules(p_fight) $f$;

create or replace function public.world_mk_cell_name(p_cell int)
 returns text language sql immutable set search_path = ''
as $f$ select case p_cell when 4 then '왼쪽 위' when 9 then '맨 위 가운데' when 2 then '오른쪽 위' when 3 then '왼쪽 가운데' when 5 then '가운데'
  when 7 then '오른쪽 가운데' when 8 then '왼쪽 아래' when 1 then '맨 아래 가운데' when 6 then '오른쪽 아래' end $f$;
revoke all on function public.world_mk_cell_name(int) from public, anon, authenticated;

create or replace function public.world_story_round(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; r jsonb := public.world_boss_fight_rules(p_fight); sm jsonb; b jsonb; nr int; ph int; m jsonb; tell text; aoe boolean := false;
  alive uuid[]; c int; c2 int; t uuid; tname text; mk boolean; lit int[]; at int; n int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  sm := r -> 'sm'; b := coalesce(f.board, '{}'::jsonb); nr := f.round + 1; mk := f.boss_id = 'mukjeok';
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select array_agg(owner_id order by random()) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  if ph <> f.phase then
    perform public.world_gw_say(p_fight, nr, 'phase', case when mk then case ph
      when 2 then '그림자가 붓끝으로 칸에 점을 찍기 시작한다. 「다음엔 이 칸을 지우마.」'
      when 3 then '명부 위로 먹이 흘러내려 웅덩이 두 곳이 고인다. 그 칸만 밟지 않으면 된다.'
      else '그림자가 가운데 칸 위에 선다. 「이 칸만 지우면, 아무도 아프지 않다.」' end
    else case ph
      when 2 then '귀허의 주인이 물거울을 거둔다. 바닥에서 흰 사슬 한 줄이 솟는다. 「너를 묶어 두마.」'
      when 3 then '사슬이 풀린 자리에서 물이 번진다. 「이름을 흐려 주마.」'
      else '귀허의 주인이 왕좌에서 일어선다. 발밑에서 잔물결이 일기 시작한다.' end end);
    f.cycle := 0;
    if mk and ph = 3 then
      c := (array[1, 9, 3, 7, 8, 4, 2, 6])[1 + floor(random() * 8)::int];
      select z into c2 from unnest(array[1, 9, 3, 7, 8, 4, 2, 6]) z where z <> c order by random() limit 1;
      b := b || jsonb_build_object('ink', jsonb_build_object('p1', c, 'p2', c2));
    elsif mk then
      b := b || jsonb_build_object('ink', '{}'::jsonb);
    end if;
    b := b - 'mark';
  end if;
  m := jsonb_build_object('k', 'normal');
  if mk then
    lit := array(select jsonb_array_elements_text(coalesce(b -> 'lit', '[]'::jsonb))::int);
    if ph = 1 and alive is not null and f.cycle % (sm ->> 'drop_every')::int = (sm ->> 'drop_every')::int - 1 then
      c := 1 + floor(random() * 9)::int;
      m := m || jsonb_build_object('s', 'drop', 'cells', jsonb_build_array(c));
      tell := '그림자가 붓을 턴다. 먹방울 하나가 「' || public.world_mk_cell_name(c) || '」 칸 위로 떨어질 것 같다. 그 칸에서만 비켜서면 된다.'
        || case when c = 5 then ' 가운데 칸이라면, 누구든 그 칸에 서서 이름을 덮어 주면 된다.' else '' end;
    elsif ph = 2 and b ? 'mark' then
      c := (b -> 'mark' ->> 'c')::int; at := (b -> 'mark' ->> 'at')::int;
      m := m || jsonb_build_object('s', 'mark', 'cells', jsonb_build_array(c), 'left', at - nr);
      tell := case when at = nr then '붓끝이 점 찍어 둔 「' || public.world_mk_cell_name(c) || '」 칸으로 내려온다. 이번 라운드에 그 칸에 누가 서 있으면 지우지 못한다.'
        else '점 찍어 둔 「' || public.world_mk_cell_name(c) || '」 칸을 그림자가 노려본다. ' || (at - nr + 1) || '라운드 뒤 그 칸을 지우려 한다.' end;
    elsif ph = 2 and alive is not null and f.cycle % (sm ->> 'mark_every')::int = 1 and coalesce(array_length(lit, 1), 0) > 0 then
      c := lit[1 + floor(random() * array_length(lit, 1))::int];
      at := nr + (sm ->> 'mark_wait')::int - 1;
      b := b || jsonb_build_object('mark', jsonb_build_object('c', c, 'at', at));
      m := m || jsonb_build_object('s', 'mark', 'cells', jsonb_build_array(c), 'left', at - nr);
      tell := '그림자가 붓끝으로 「' || public.world_mk_cell_name(c) || '」 칸에 점을 찍는다. ' || (sm ->> 'mark_wait') || '라운드 뒤 그 칸을 지우려 한다. 그때 그 칸에 누가 서 있으면 지우지 못한다.';
    elsif ph = 3 then
      m := m || jsonb_build_object('s', 'pool', 'cells', jsonb_build_array((b -> 'ink' ->> 'p1')::int, (b -> 'ink' ->> 'p2')::int));
      tell := '먹 웅덩이가 「' || public.world_mk_cell_name((b -> 'ink' ->> 'p1')::int) || '」·「' || public.world_mk_cell_name((b -> 'ink' ->> 'p2')::int) || '」 칸에 고여 있다. 그 칸에 서 있으면 발이 붙잡힌다.';
    elsif ph = 4 and alive is not null and f.cycle % (sm ->> 'keep_every')::int = 0 then
      m := m || jsonb_build_object('s', 'keep');
      tell := '그림자가 가운데 칸 위로 붓을 든다. 누구든 가운데 칸에 서서 방어나 버티기를 고르면 이름을 지킬 수 있다.';
    else
      tell := '그림자가 붓에 먹을 다시 찍는다.';
    end if;
  else
    if b ? 'blur' then m := m || jsonb_build_object('blur', b -> 'blur' ->> 't'); end if;
    if ph = 1 and alive is not null and f.cycle % (sm ->> 'mirror_every')::int = (sm ->> 'mirror_every')::int - 1 then
      m := m || jsonb_build_object('s', 'mirror');
      tell := '주인이 앞에 물거울을 세운다. 거울에 대고 휘두른 공격은 반만 닿는다. 방어나 버티기로 거울을 밀어내면 깨질 것 같다.';
    elsif ph = 2 and alive is not null and f.cycle % (sm ->> 'chain_every')::int = 1 then
      t := alive[1]; select name into tname from public.world_gw_members where fight_id = p_fight and owner_id = t;
      m := m || jsonb_build_object('s', 'chain1', 'target', t);
      tell := tname || '의 손목에 흰 사슬 한 줄이 감긴다. 누구든 「사슬 끊기」를 고르면 끊어진다.';
    elsif ph = 3 and alive is not null and not b ? 'blur' and f.cycle % (sm ->> 'blur_every')::int = 1 then
      t := alive[1]; select name into tname from public.world_gw_members where fight_id = p_fight and owner_id = t;
      b := b || jsonb_build_object('blur', jsonb_build_object('t', t, 'at', nr));
      m := m || jsonb_build_object('s', 'blur', 'blur', t);
      tell := tname || '의 이름이 물에 흐려진다. 누구든 「이름 부르기」로 불러 주면 또렷해진다. 그때까지는 공격이 반만 닿는다.';
    elsif ph = 4 and alive is not null and f.cycle % (sm ->> 'tide_every')::int = 0 then
      m := m || jsonb_build_object('s', 'tide');
      tell := '잔물결이 왕좌 아래에서 밀려온다. 방어나 버티기를 고르면 물결이 그냥 지나간다.';
    elsif b ? 'blur' then
      tell := (select name from public.world_gw_members where fight_id = p_fight and owner_id = (b -> 'blur' ->> 't')::uuid) || '의 이름이 아직 흐리다. 누구든 「이름 부르기」로 불러 주면 된다.';
    else
      tell := '주인이 숨을 고른다. 물살이 왕좌를 감싸 돈다.';
    end if;
  end if;
  if not m ? 's' then
    aoe := nr % (sm ->> 'aoe_every')::int = 0;
    if aoe then tell := tell || case when mk then ' — 먹구름이 낮게 내려앉는다. 먹비가 쏟아질 것 같다. 방어나 버티기로 대비하면 덜 아프다.'
      else ' — 발밑의 물이 부풀어 오른다. 물살이 쏟아질 것 같다. 방어나 버티기로 대비하면 덜 아프다.' end; end if;
  end if;
  m := m || jsonb_build_object('aoe', aoe, 'tell', tell);
  update public.world_gw_fights set phase = ph, round = nr, cycle = f.cycle + 1, mech = m, board = b,
    round_ends_at = now() + make_interval(secs => case when n = 1 then 86400 else (r ->> 'round_s')::int end), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, nr, case when aoe or m ? 's' then 'warn' else 'tell' end, tell);
end $f$;
revoke all on function public.world_story_round(uuid) from public, anon, authenticated;

create or replace function public.world_story_on_attack(p_fight uuid, p_uid uuid, p_round integer)
 returns numeric language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; sm jsonb := public.world_boss_fight_rules(p_fight) -> 'sm'; mul numeric := 1;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if f.mech ->> 's' = 'mirror' then mul := mul * (sm ->> 'mirror_mul')::numeric; end if;
  if (f.board ->> 'crack')::int = p_round then mul := mul * (1 + (sm ->> 'crack_pct')::numeric / 100.0); end if;
  if f.board -> 'blur' ->> 't' = p_uid::text then mul := mul * (sm ->> 'blur_mul')::numeric; end if;
  return mul;
end $f$;
revoke all on function public.world_story_on_attack(uuid, uuid, integer) from public, anon, authenticated;

create or replace function public.world_story_mech(p_fight uuid, p_round integer, p_broke boolean, p_delayed boolean, p_freed uuid[])
 returns numeric language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; sm jsonb := public.world_boss_fight_rules(p_fight) -> 'sm'; b jsonb; s text; w record; cells int[]; c int;
  half numeric := case when p_broke then 0.5 else 1 end; st int; lit int[]; extra numeric := 0; ok boolean; t uuid; tn text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  b := coalesce(f.board, '{}'::jsonb); s := f.mech ->> 's';
  cells := array(select jsonb_array_elements_text(coalesce(f.mech -> 'cells', '[]'::jsonb))::int);
  st := coalesce((b ->> 'strokes')::int, 0);
  lit := array(select jsonb_array_elements_text(coalesce(b -> 'lit', '[]'::jsonb))::int);
  if coalesce(array_length(p_freed, 1), 0) > 0 then
    update public.world_gw_members set fx = fx - 'bound' where fight_id = p_fight and owner_id = any (p_freed) and fx ? 'bound';
  end if;
  if f.boss_id = 'mukjeok' then
    if s = 'drop' then
      for w in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and pos = any (cells) order by joined_at loop
        perform public.world_gw_hit(p_fight, w.owner_id, (sm ->> 'drop_raw')::numeric * half, p_round, '떨어진 먹방울에', false);
      end loop;
      if 5 = any (cells) then
        if exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and pos = 5) then
          perform public.world_gw_say(p_fight, p_round, 'good', '가운데 칸에 선 이가 먹방울을 막아 이름을 지켰습니다.');
        else
          st := st - 1;
          b := b || jsonb_build_object('lost', coalesce((b ->> 'lost')::int, 0) + 1);
          perform public.world_gw_say(p_fight, p_round, 'bad', '먹방울이 가운데 칸에 떨어져 이름 획 하나가 번졌습니다(남은 획 ' || greatest(0, st) || ').');
        end if;
      elsif not exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and pos = any (cells)) then
        perform public.world_gw_say(p_fight, p_round, 'good', '먹방울이 빈 칸에 떨어져 흩어졌습니다.');
      end if;
    elsif s = 'mark' and coalesce((b -> 'mark' ->> 'at')::int, -1) <= p_round and b ? 'mark' then
      c := (b -> 'mark' ->> 'c')::int;
      if exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and pos = c) then
        perform public.world_gw_say(p_fight, p_round, 'good', '「' || public.world_mk_cell_name(c) || '」 칸에 선 이가 있어 그림자가 지우지 못하고 붓을 거둡니다.');
        ok := true;
      else
        lit := array(select z from unnest(lit) z where z <> c);
        perform public.world_gw_say(p_fight, p_round, 'bad', '그림자가 비어 있던 「' || public.world_mk_cell_name(c) || '」 칸을 지웠습니다. 그 칸에 서서 「되찾기」를 고르면 다시 밝힐 수 있습니다.');
      end if;
      b := b - 'mark';
    elsif s = 'pool' then
      for w in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and pos = any (cells) order by joined_at loop
        update public.world_gw_members set fx = fx || jsonb_build_object('bound', p_round) where fight_id = p_fight and owner_id = w.owner_id;
        perform public.world_gw_hit(p_fight, w.owner_id, (sm ->> 'pool_raw')::numeric * half, p_round, '먹 웅덩이에 발이 빠져', false);
      end loop;
    elsif s = 'keep' then
      select exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and pos = 5
        and coalesce(act ->> 'a', 'guard') in ('guard', 'brace')) into ok;
      if ok then
        extra := round(f.max_hp * (sm ->> 'keep_pct')::numeric / 100.0);
        st := least(coalesce((b ->> 'max')::int, 9), st + 1);
        perform public.world_gw_say(p_fight, p_round, 'good', '가운데 칸을 지켰습니다! 붓이 꺾인 그림자가 ' || extra || '의 피해를 입고, 이름이 한 획 또렷해집니다(이름 획 ' || st || ').');
      else
        st := st - 1;
        b := b || jsonb_build_object('lost', coalesce((b ->> 'lost')::int, 0) + 1);
        perform public.world_gw_say(p_fight, p_round, 'bad', '가운데 칸을 지킨 사람이 없어 이름 획 하나가 지워졌습니다(남은 획 ' || greatest(0, st) || ').');
        for w in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest loop
          perform public.world_gw_hit(p_fight, w.owner_id, (sm ->> 'keep_raw')::numeric * half, p_round, '가운데 칸에서 번진 먹에', true);
        end loop;
      end if;
    end if;
    update public.world_gw_fights set board = (b - 'lit' - 'strokes') || jsonb_build_object('lit', to_jsonb(coalesce(lit, '{}'::int[])), 'strokes', greatest(0, st)) where fight_id = p_fight;
    if s = 'mark' and ok then perform public.world_mk_memory(p_fight, p_round); end if;
    return extra;
  end if;
  if s = 'mirror' then
    if exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and coalesce(act ->> 'a', 'guard') in ('guard', 'brace')) then
      b := b || jsonb_build_object('crack', p_round + 1);
      perform public.world_gw_say(p_fight, p_round, 'good', '물거울이 밀려 깨졌습니다! 다음 라운드에는 주인이 ' || (sm ->> 'crack_pct') || '% 더 아파합니다.');
    else
      perform public.world_gw_say(p_fight, p_round, 'miss', '물거울이 공격을 반쯤 받아 냈습니다.');
    end if;
  elsif s = 'chain1' then
    t := (f.mech ->> 'target')::uuid;
    select name into tn from public.world_gw_members where fight_id = p_fight and owner_id = t;
    if t = any (p_freed) or exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'chain') then
      perform public.world_gw_say(p_fight, p_round, 'good', tn || '의 사슬을 끊었습니다.');
    elsif exists (select 1 from public.world_gw_members where fight_id = p_fight and owner_id = t and out_rounds = 0 and not rest) then
      perform public.world_gw_hit(p_fight, t, (sm ->> 'chain_raw')::numeric * half, p_round, '끊지 못한 사슬에 당겨져', false);
    end if;
  elsif s = 'tide' then
    for w in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest order by joined_at loop
      if coalesce(w.act ->> 'a', 'guard') in ('guard', 'brace') then
        perform public.world_gw_say(p_fight, p_round, 'good', w.name || ' — 몸을 낮춰 잔물결을 흘려보냅니다.');
      else
        perform public.world_gw_hit(p_fight, w.owner_id, (sm ->> 'tide_raw')::numeric * half, p_round, '밀려든 잔물결에', true);
      end if;
    end loop;
  end if;
  if b ? 'blur' then
    t := (b -> 'blur' ->> 't')::uuid;
    select name into tn from public.world_gw_members where fight_id = p_fight and owner_id = t;
    if t = any (p_freed) or exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'call' and act ->> 't' = t::text) then
      b := b - 'blur';
      perform public.world_gw_say(p_fight, p_round, 'good', '「' || tn || '!」 부르는 소리에 흐려졌던 이름이 또렷해집니다.');
    elsif p_round >= (b -> 'blur' ->> 'at')::int + (sm ->> 'blur_rounds')::int - 1 then
      b := b - 'blur';
      perform public.world_gw_say(p_fight, p_round, 'good', tn || '의 이름이 저절로 다시 또렷해집니다.');
    end if;
  end if;
  update public.world_gw_fights set board = b where fight_id = p_fight;
  return extra;
end $f$;
revoke all on function public.world_story_mech(uuid, integer, boolean, boolean, uuid[]) from public, anon, authenticated;

create or replace function public.world_gw_story_settle(p_fight uuid, p_won boolean)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_boss_fight_rules(p_fight); f public.world_gw_fights%rowtype; m record; today date := (now() at time zone 'Asia/Seoul')::date;
  rec public.world_gw_records%rowtype; is_first boolean; v_gil int; rid text;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status not in ('fight', 'wait') then return; end if;
  rid := f.boss_id || '_story';
  update public.world_gw_fights set status = case when p_won then 'won' else 'failed' end, ended_at = now(), updated_at = now(), hp = case when p_won then 0 else hp end where fight_id = p_fight;
  for m in select * from public.world_gw_members where fight_id = p_fight loop
    update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
    if p_won then
      insert into public.world_gw_records(owner_id, boss_id) values (m.owner_id, rid) on conflict do nothing;
      select * into rec from public.world_gw_records where owner_id = m.owner_id and boss_id = rid for update;
      is_first := coalesce(rec.kills, 0) = 0;
      update public.world_gw_records set kills = kills + 1, last_kill_day = today, first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id and boss_id = rid;
      v_gil := 0;
      if is_first then
        v_gil := (r -> 'first' ->> 'gil')::int;
        update public.world_characters set gil = gil + v_gil, updated_at = now() where owner_id = m.owner_id;
      end if;
      insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', public.world_josa(r ->> 'name', '을', '를') || ' 쓰러뜨렸습니다',
        case when is_first then public.world_josa(r ->> 'name', '을', '를') || ' 이야기판에서 쓰러뜨렸습니다. ' || to_char(v_gil, 'FM999,999') || '전을 받았습니다. 이야기를 이어 가세요.'
          else public.world_josa(r ->> 'name', '을', '를') || ' 이야기판에서 다시 한 번 쓰러뜨렸습니다.' end,
        jsonb_build_object('fight_id', p_fight, 'boss', f.boss_id, 'mode', 'story', 'first', is_first));
    else
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (m.owner_id, 'gw', (r ->> 'name') || ' 앞에서 밀려났습니다', '이야기판은 밀려나도 잃는 것이 없습니다. 숨을 고르고 다시 서세요.', jsonb_build_object('fight_id', p_fight, 'boss', f.boss_id, 'mode', 'story'));
    end if;
  end loop;
  perform public.world_gw_say(p_fight, f.round, case when p_won then 'win' else 'bad' end, case when p_won
    then '귀허의 주인이 무너진다. 「…이름을 하나만 다오.」 물이 바다로 돌아가고, 소용돌이가 있던 자리에 달빛 비슷한 것이 비친다.'
    else '도전이 끝났습니다.' end);
end $f$;
revoke all on function public.world_gw_story_settle(uuid, boolean) from public, anon, authenticated;

select pg_temp.yh_fix('world_gw_next_round', array[
$a$  if f.boss_id = 'mukjeok' then perform public.world_mk_round(p_fight); return; end if;$a$,
$b$  if f.mode = 'story' then perform public.world_story_round(p_fight); return; end if;
  if f.boss_id = 'mukjeok' then perform public.world_mk_round(p_fight); return; end if;$b$]);

select pg_temp.yh_fix('world_gw_settle', array[
$a$  if f.boss_id = 'mukjeok' then perform public.world_mk_settle(p_fight, p_won); return; end if;$a$,
$b$  if f.boss_id = 'mukjeok' then perform public.world_mk_settle(p_fight, p_won); return; end if;
  if f.mode = 'story' then perform public.world_gw_story_settle(p_fight, p_won); return; end if;$b$]);

select pg_temp.yh_fix('world_gw_start', array[
$a$  if f.boss_id = 'mukjeok' then
    br := public.world_mk_rules(p_fight);$a$,
$b$  if f.mode = 'story' then
    br := public.world_boss_fight_rules(p_fight);
    update public.world_gw_fights set status = 'fight',
           max_hp = round(greatest((br ->> 'hp_min')::numeric, sa * (br ->> 'hp_atk')::numeric) * (br -> 'hp_n' ->> (least(4, n) - 1))::numeric),
           hp = round(greatest((br ->> 'hp_min')::numeric, sa * (br ->> 'hp_atk')::numeric) * (br -> 'hp_n' ->> (least(4, n) - 1))::numeric), phase = 1, round = 0, cycle = 0,
           ends_at = now() + make_interval(mins => (br ->> 'min')::int), updated_at = now() where fight_id = p_fight;
    if f.boss_id = 'mukjeok' then
      perform public.world_mk_begin(p_fight, n);
    else
      perform public.world_gw_say(p_fight, 0, 'phase', '빈 왕좌 위로 물이 솟아 사람 꼴이 된다. 귀허의 주인이 물거울을 세운다. 「먼저 나를 보아라. 그다음에 칼을 들어라.」');
    end if;
    perform public.world_gw_next_round(p_fight);
    return;
  end if;
  if f.boss_id = 'mukjeok' then
    br := public.world_mk_rules(p_fight);$b$]);

select pg_temp.yh_fix('world_gw_resolve', array[
$a$      if f.boss_id = 'mukjeok' then d := d * public.world_mk_on_attack(p_fight, m.owner_id, r); end if;$a$,
$b$      if f.boss_id = 'mukjeok' then d := d * public.world_mk_on_attack(p_fight, m.owner_id, r);
      elsif f.mode = 'story' then d := d * public.world_story_on_attack(p_fight, m.owner_id, r); end if;$b$,
$a$      if coalesce(m.items_used, 0) >= 2 then$a$,
$b$      if f.mode <> 'story' and coalesce(m.items_used, 0) >= 2 then$b$,
$a$        || ' (회복품 ' || (coalesce(m.items_used, 0) + 1) || '/2).');$a$,
$b$        || case when f.mode = 'story' then '.' else ' (회복품 ' || (coalesce(m.items_used, 0) + 1) || '/2).' end);$b$,
$a$    elsif av = 'call' and f.boss_id = 'mukjeok' then$a$,
$b$    elsif av = 'call' and (f.boss_id = 'mukjeok' or f.mode = 'story') then$b$,
$a$    elsif av = 'chain' then
      if k <> 'chain' then$a$,
$b$    elsif av = 'chain' and f.mode = 'story' then
      null;
    elsif av = 'chain' then
      if k <> 'chain' then$b$,
$a$  if f.boss_id = 'mukjeok' then boss_dmg := boss_dmg + public.world_mk_mech(p_fight, r, broke, delayed, freed); end if;$a$,
$b$  if f.mode = 'story' then boss_dmg := boss_dmg + public.world_story_mech(p_fight, r, broke, delayed, freed);
  elsif f.boss_id = 'mukjeok' then boss_dmg := boss_dmg + public.world_mk_mech(p_fight, r, broke, delayed, freed); end if;$b$,
$a$    if f.boss_id = 'mukjeok' then raw := public.world_mk_raw(p_fight); else$a$,
$b$    if f.boss_id = 'mukjeok' or f.mode = 'story' then raw := public.world_mk_raw(p_fight); else$b$,
$a$  if (select count(*) from public.world_gw_members where fight_id = p_fight) = 1 and (select max(falls)$a$,
$b$  if f.mode <> 'story' and (select count(*) from public.world_gw_members where fight_id = p_fight) = 1 and (select max(falls)$b$]);

select pg_temp.yh_fix('world_gw_act', array[
$a$    if coalesce(me.items_used, 0) >= 2 then raise exception$a$,
$b$    if f.mode <> 'story' and coalesce(me.items_used, 0) >= 2 then raise exception$b$]);

select pg_temp.yh_fix('world_gw_ready', array[
$a$  if p_boss = 'mukjeok' and p_mode = 'story' then
    null;$a$,
$b$  if p_mode = 'story' then
    null;$b$]);

select pg_temp.yh_fix('world_gw_open', array[
$a$  md text := case when coalesce(p_boss, 'gwiheo') = 'mukjeok' and p_mode = 'story' then 'story' else 'hard' end;$a$,
$b$  md text := case when p_mode = 'story' then 'story' else 'hard' end;$b$,
$a$c.character_name || '이(가) 귀허의 주인 앞에 섰습니다. 60초 안에 합류하세요(귀허 부적 1개).', jsonb_build_object('fight_id', fid));$a$,
$b$c.character_name || '이(가) 귀허의 주인 앞에 섰습니다. 60초 안에 합류하세요' || case when md = 'story' then '.' else '(귀허 부적 1개).' end, jsonb_build_object('fight_id', fid, 'boss', boss, 'mode', md));$b$]);

select pg_temp.yh_fix('world_gw_snapshot', array[
$a$    if boss = 'mukjeok' then
      begin perform public.world_gw_ready_check(uid, boss, 'story'); exception when others then swhy := sqlerrm; end;
      select * into srec from public.world_gw_records where owner_id = uid and boss_id = 'mukjeok_story';$a$,
$b$    if br ? 'story' then
      begin perform public.world_gw_ready_check(uid, boss, 'story'); exception when others then swhy := sqlerrm; end;
      select * into srec from public.world_gw_records where owner_id = uid and boss_id = boss || '_story';$b$,
$a$'story', case when boss = 'mukjeok' then jsonb_build_object($a$,
$b$'story', case when br ? 'story' then jsonb_build_object($b$,
$a$    'items_left', greatest(0, 2 - coalesce(me.items_used, 0)),$a$,
$b$    'items_left', case when f.mode = 'story' then null else greatest(0, 2 - coalesce(me.items_used, 0)) end,$b$,
$a$    'falls_cap', 10 + $a$,
$b$    'falls_cap', case when f.mode = 'story' then null else 10 end + $b$]);

select pg_temp.yh_fix('world_quest_task_count', array[
$a$                  and x.mode = coalesce(p_task ->> 'mode', 'hard'))$a$,
$b$                  and (p_task ->> 'mode' = 'any' or x.mode = coalesce(p_task ->> 'mode', 'hard')))$b$]);

select pg_temp.yh_fix('world_quest_task_label', array[
$a$    when p_task ->> 't' = 'mj' then$a$,
$b$    when p_task ->> 't' = 'gw' then '귀허에서 귀허의 주인 쓰러뜨리기(이야기판도 됩니다)'
    when p_task ->> 't' = 'mj' then$b$]);

update public.world_quest_steps set need = jsonb_set(need, '{tasks}', '[{"n": 1, "t": "gw", "mode": "any"}]'::jsonb)
 where quest_id = 'gq_5' and need -> 'tasks' = '[{"n": 1, "t": "gw"}]'::jsonb;

select public.world_quest_label_refresh();

do $o$ declare o text := (select pg_get_userbyid(proowner) from pg_proc where proname = 'world_gw_resolve' and pronamespace = 'public'::regnamespace); begin
  if o <> 'postgres' then
    execute format('alter function public.world_story_round(uuid) owner to %I', o);
    execute format('alter function public.world_story_on_attack(uuid, uuid, integer) owner to %I', o);
    execute format('alter function public.world_story_mech(uuid, integer, boolean, boolean, uuid[]) owner to %I', o);
    execute format('alter function public.world_gw_story_settle(uuid, boolean) owner to %I', o);
  end if;
  execute format('grant execute on function public.world_mk_cell_name(int) to %I', o);
  execute format('grant execute on function public.world_boss_fight_rules(uuid) to %I', o);
end $o$;

update public.world_patch_notes set body = replace(body, E'\n## 그 밖\n', $N$

## 우두머리 두 판(이야기판)
- 귀허의 주인과 먹그림자를 「이야기판」과 어려운 판으로 나눴습니다. 지금까지의 귀허의 주인은 「깊은 귀허」, 먹그림자의 어려운 판은 「깊은 명부」입니다.
- 이야기판은 누구든 깰 수 있는 쉬운 판입니다. 혼자면 마감이 없고(여럿이면 1분), 입장 물품이 필요 없고, 회복품을 마음껏 쓰며, 밀려나도 잃는 것이 없습니다. 혼자서 몇 분이면 끝납니다.
- 같은 판이지만 수법은 따로입니다. 귀허의 주인 이야기판: 물거울 · 한 줄 사슬 · 흐린 이름 · 잔물결. 먹그림자 이야기판: 먹방울 · 찍어 둔 칸 · 먹 웅덩이 · 이름 지키기. 낌새 문구가 할 일을 그대로 알려 줍니다. 어려운 판에서는 처음 보는 수법이 나옵니다.
- 외전 「요인록」 5장은 귀허의 주인 이야기판으로도 이어집니다. 처음 쓰러뜨리면 전을 받고, 처치 보상·칭호·꾸미기·하루 처치는 어려운 판에만 있습니다.

## 그 밖
$N$) where note_id = '2.0.0' and position('## 우두머리 두 판' in body) = 0;

update public.world_app_meta set value = '20261116070000' where key = 'db_version';
