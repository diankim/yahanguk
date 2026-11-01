-- 7.7.7i — 귀허의 주인: 물러난 뒤·소생 뒤 저절로 돌아가지 않고 「쉬는 중」(봉연과 같게, 사용자 결정 2026-11-01).
-- 물러남 라운드가 끝나면(또는 [야전 소생]을 받으면) 체력 30(소생은 기술 회복량)으로 쉬는 중이 된다.
-- 쉬는 동안은 주인이 노리지 않고, 모두에게 거는 효과·수법(사슬·이름·물살)에서 빠지고, 라운드는 쉬는 사람을 기다리지 않는다.
-- 공격·방어·버티기·기술·회복품·이름 부르기·사슬 끊기 가운데 하나를 고르면 그 라운드부터 다시 싸운다.
-- 한 사람을 고르는 회복(약·기술)은 쉬는 사람도 받는다. 「모두 물러남」(실패)은 물러나 있는 사람만 센다(쉬는 사람은 돌아올 수 있으므로).
alter table public.world_gw_members add column if not exists rest boolean not null default false;

do $p$
declare d text; o text; own text; fn regprocedure;
begin
  -- 1) world_gw_resolve: 「싸우는 사람」(out_rounds = 0)에서 쉬는 사람을 뺀다 — 한 사람 회복(tgt)과 「모두 물러남」 셈은 그대로
  fn := 'public.world_gw_resolve(uuid)'::regprocedure;
  d := replace(pg_get_functiondef(fn), E'\r\n', E'\n');
  if position('not rest' in d) = 0 then
    o := d;
    -- 야전 소생: 곧바로 복귀하지 않고 쉬는 중으로
    if position('set out_rounds = 0, hp = (e ->> ''hp'')::int where' in d) = 0 then raise exception '7.7.7i anchor: revive'; end if;
    d := replace(d, 'set out_rounds = 0, hp = (e ->> ''hp'')::int where', 'set @@OUT0@@, rest = true, hp = (e ->> ''hp'')::int where');
    d := replace(d, 'x.owner_id = tgt and x.out_rounds = 0', '@@T1@@');
    d := replace(d, 'owner_id = tgt and out_rounds = 0', '@@T2@@');
    d := replace(d, 'out_rounds = 0', 'out_rounds = 0 and not rest');
    d := replace(d, '@@T1@@', 'x.owner_id = tgt and x.out_rounds = 0');
    d := replace(d, '@@T2@@', 'owner_id = tgt and out_rounds = 0');
    d := replace(d, '@@OUT0@@', 'out_rounds = 0');
    d := replace(d, 'into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest;',
                    'into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0;');
    -- 물러남이 끝나면 쉬는 중으로
    if position('set out_rounds = out_rounds - 1, hp = case when out_rounds = 1 then 30 else hp end where' in d) <> 0 then null; else raise exception '7.7.7i anchor: out countdown'; end if;
    d := replace(d, 'set out_rounds = out_rounds - 1, hp = case when out_rounds = 1 then 30 else hp end where',
                    'set out_rounds = out_rounds - 1, rest = rest or out_rounds = 1, hp = case when out_rounds = 1 then 30 else hp end where');
    if d = o then raise exception '7.7.7i resolve unchanged'; end if;
    if position('set out_rounds = 0 and not rest' in d) > 0 or position('out_rounds = 0 and not rest,' in d) > 0 then raise exception '7.7.7i: set 절에 걸림'; end if;
    execute d;
  end if;

  -- 2) world_gw_next_round: 표적·사슬·소용돌이 담당에서 쉬는 사람을 뺀다
  fn := 'public.world_gw_next_round(uuid)'::regprocedure;
  d := replace(pg_get_functiondef(fn), E'\r\n', E'\n');
  if position('not rest' in d) = 0 then
    if (length(d) - length(replace(d, 'out_rounds = 0', ''))) / length('out_rounds = 0') <> 3 then raise exception '7.7.7i anchor: next_round'; end if;
    execute replace(d, 'out_rounds = 0', 'out_rounds = 0 and not rest');
  end if;

  -- 3) world_gw_hit · world_gw_hurt: 쉬는 사람은 맞지 않는다
  fn := 'public.world_gw_hit(uuid,uuid,numeric,integer,text,boolean)'::regprocedure;
  d := replace(pg_get_functiondef(fn), E'\r\n', E'\n');
  if position('m.rest' in d) = 0 then
    if position('if not found or m.out_rounds > 0 then return 0; end if;' in d) = 0 then raise exception '7.7.7i anchor: hit'; end if;
    execute replace(d, 'if not found or m.out_rounds > 0 then return 0; end if;', 'if not found or m.out_rounds > 0 or m.rest then return 0; end if;');
  end if;
  fn := 'public.world_gw_hurt(uuid,uuid,integer,integer,text)'::regprocedure;
  d := replace(pg_get_functiondef(fn), E'\r\n', E'\n');
  if position('m.rest' in d) = 0 then
    if position('if not found or m.out_rounds > 0 or d = 0 then return 0; end if;' in d) = 0 then raise exception '7.7.7i anchor: hurt'; end if;
    d := replace(d, 'if not found or m.out_rounds > 0 or d = 0 then return 0; end if;', 'if not found or m.out_rounds > 0 or m.rest or d = 0 then return 0; end if;');
    d := replace(d, '''라운드 뒤 돌아옴''', '''라운드 쉰 뒤 행동하면 돌아옴''');
    execute d;
  end if;

  -- 4) world_gw_act: 행동을 고르면 쉬는 중이 풀린다
  fn := 'public.world_gw_act(uuid,text,uuid,text)'::regprocedure;
  d := replace(pg_get_functiondef(fn), E'\r\n', E'\n');
  if position('rest = false' in d) = 0 then
    if position('update public.world_gw_members set act = a where fight_id = p_fight and owner_id = uid;' in d) = 0 then raise exception '7.7.7i anchor: act'; end if;
    d := replace(d, 'update public.world_gw_members set act = a where fight_id = p_fight and owner_id = uid;',
      'if me.rest then perform public.world_gw_say(p_fight, f.round, ''good'', me.name || '' — 숨을 고르고 다시 싸움에 나섭니다.''); end if;
  update public.world_gw_members set act = a, rest = false where fight_id = p_fight and owner_id = uid;');
    execute d;
  end if;

  -- 5) world_gw_snapshot: 참가자마다 resting
  fn := 'public.world_gw_snapshot(uuid)'::regprocedure;
  d := replace(pg_get_functiondef(fn), E'\r\n', E'\n');
  if position('''resting''' in d) = 0 then
    if position('''out'', m.out_rounds,' in d) = 0 then raise exception '7.7.7i anchor: snapshot'; end if;
    execute replace(d, '''out'', m.out_rounds,', '''out'', m.out_rounds, ''resting'', m.rest,');
  end if;
end $p$;

update public.world_patch_notes set body = body || $N$
## 7.7.7i
- 귀허의 주인: 물러났다 돌아올 때와 [야전 소생]을 받았을 때 저절로 싸움에 들어가지 않고 「쉬는 중」이 됩니다(봉연과 같게). 쉬는 동안은 주인이 노리지 않고 수법에서도 빠지며, 공격·방어·버티기·기술·회복품 가운데 하나를 고르면 그 라운드부터 다시 싸웁니다.
- 파티 토벌·귀허의 주인 화면을 봉연 토벌 화면과 같게 맞췄습니다: 직업 색 참가자 칸(체력 숫자는 막대 안, 누르면 자세히), 북돋기·약화 아이콘과 짧은 설명, 물품 창(이름·회복 수치만, 작은 칸 서너 개씩 — 제보 86).
$N$ where note_id = '7.7.0' and position('## 7.7.7i' in body) = 0;

update public.world_app_meta set value = '20261104203600' where key = 'db_version';
