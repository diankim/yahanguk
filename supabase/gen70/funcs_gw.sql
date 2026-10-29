
-- ─────────────────────────────────────────────────────────────
-- B-3. 외전 최종 보스 「귀허의 주인」 — 라운드 전투
--   라운드: 보통 5초 / 기믹 10초. 라운드 안에 참가자마다 행동 하나(공격·방어·물품·정화·사슬 끊기), 안 고르면 방어.
--   마감이 지나거나 모두 고르면 서버가 한 번에 풀어낸다(누군가 상황을 읽거나 행동할 때). 실시간 감시 목록에는 넣지 않는다.
--   단계(체력): ① 100~75% 두 얼굴 ② 75~50% 사슬 넷 ③ 50~25% 이름 빼앗기 ④ 25% 아래 귀허의 소용돌이.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.world_gw_fights (
  fight_id uuid primary key default gen_random_uuid(),
  leader_id uuid not null,
  status text not null default 'wait' check (status in ('wait', 'fight', 'won', 'failed')),
  created_at timestamptz not null default now(),
  start_at timestamptz not null default now(),
  ends_at timestamptz, ended_at timestamptz,
  hp int not null default 0, max_hp int not null default 0,
  phase int not null default 1, round int not null default 0, cycle int not null default 0,
  round_ends_at timestamptz,
  mech jsonb not null default '{}'::jsonb,
  enrage int not null default 0,
  updated_at timestamptz not null default now()
);
create table if not exists public.world_gw_members (
  fight_id uuid not null references public.world_gw_fights(fight_id) on delete cascade,
  owner_id uuid not null, name text not null, job_key text, level int,
  hp int not null default 100, stats jsonb not null default '{}'::jsonb, act jsonb,
  acts int not null default 0, dmg int not null default 0, heal int not null default 0,
  out_rounds int not null default 0, nameless boolean not null default false, falls int not null default 0,
  joined_at timestamptz not null default now(),
  primary key (fight_id, owner_id)
);
create table if not exists public.world_gw_log (
  id bigserial primary key, fight_id uuid not null references public.world_gw_fights(fight_id) on delete cascade,
  round int not null default 0, at timestamptz not null default now(), kind text not null default 'info', text text not null
);
create index if not exists world_gw_log_fight on public.world_gw_log(fight_id, id);
create index if not exists world_gw_members_owner on public.world_gw_members(owner_id);
create table if not exists public.world_gw_records (
  owner_id uuid primary key, kills int not null default 0, tries int not null default 0,
  last_kill_day date, last_fail_at timestamptz, first_kill_at timestamptz
);
alter table public.world_gw_fights enable row level security;
alter table public.world_gw_members enable row level security;
alter table public.world_gw_log enable row level security;
alter table public.world_gw_records enable row level security;
revoke all on public.world_gw_fights, public.world_gw_members, public.world_gw_log, public.world_gw_records from anon, authenticated;
grant select, insert, update, delete on public.world_gw_fights, public.world_gw_members, public.world_gw_log, public.world_gw_records to fn_owner_field;
grant usage on sequence public.world_gw_log_id_seq to fn_owner_field;

create or replace function public.world_gw_say(p_fight uuid, p_round int, p_kind text, p_text text) returns void
language sql security definer set search_path to 'pg_catalog', 'public' as $$
  insert into public.world_gw_log(fight_id, round, kind, text) values (p_fight, p_round, p_kind, p_text)
$$;

-- 도전·합류 조건 확인(캐릭터 행을 돌려줌)
create or replace function public.world_gw_ready(p_uid uuid) returns public.world_characters
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype; rec public.world_gw_records%rowtype; today date := (now() at time zone 'Asia/Seoul')::date;
begin
  select * into c from public.world_characters where owner_id = p_uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 도전할 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 도전할 수 없습니다.'; end if;
  if (public.world_region_at(c.location)).region_id is distinct from 'gwiheo_core' then raise exception '귀허에서만 귀허의 주인 앞에 설 수 있습니다.'; end if;
  if not public.world_gwiheo_open(p_uid) then raise exception '귀허도에 아직 건너오지 못했습니다.'; end if;
  if c.level < 38 then raise exception 'Lv38부터 도전할 수 있습니다.'; end if;
  if not public.world_quest_done(p_uid, 'gq_4') then raise exception '외전 4장 「달 없는 장」을 마쳐야 귀허의 주인 앞에 설 수 있습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = p_uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '요괴와 싸우는 중입니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then raise exception '원정 중에는 도전할 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = 'active') then raise exception '자율 활동 중에는 도전할 수 없습니다.'; end if;
  select * into rec from public.world_gw_records where owner_id = p_uid;
  if rec.last_kill_day = today then raise exception '오늘은 이미 귀허의 주인을 쓰러뜨렸습니다. 내일(한국 시각 0시 뒤) 다시 도전할 수 있습니다.'; end if;
  if rec.last_fail_at > now() - interval '30 minutes' then
    raise exception '귀허의 소용돌이가 아직 가라앉지 않았습니다. %분 뒤 다시 도전할 수 있습니다.', ceil(extract(epoch from rec.last_fail_at + interval '30 minutes' - now()) / 60);
  end if;
  if coalesce((c.inventory ->> 'gwiheo_charm')::int, 0) < 1 then raise exception '귀허 부적이 필요합니다. 반요촌 잡화에서 팝니다.'; end if;
  if exists (select 1 from public.world_gw_members m join public.world_gw_fights f using (fight_id) where m.owner_id = p_uid and f.status in ('wait', 'fight')) then
    raise exception '이미 귀허의 주인과 싸우는 중입니다.'; end if;
  return c;
end $$;

-- 다음 라운드 준비: 단계에 맞는 기믹과 마감 시각
create or replace function public.world_gw_next_round(p_fight uuid) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare f public.world_gw_fights%rowtype; ph int; m jsonb; len int := 5; alive uuid[]; colors text[] := array['청', '적', '황', '백']; k int; t uuid; need int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select array_agg(owner_id order by random()) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
  if ph <> f.phase then
    perform public.world_gw_say(p_fight, f.round + 1, 'phase', case ph
      when 2 then '귀허의 주인이 두 얼굴을 거둔다. 바닥에서 흰 사슬 네 줄이 솟아 조사원들의 손목을 감는다. 「너희 이름을 묶어 두마.」'
      when 3 then '사슬이 끊긴 자리에서 물이 솟는다. 「이름을 다오. 하나씩 빼앗아 주마.」'
      else '귀허의 주인이 왕좌에서 일어선다. 바다 전체가 소용돌이친다. 「모두 함께 가라앉자.」' end);
    f.cycle := 0;
  end if;
  if ph = 1 then
    m := jsonb_build_object('k', 'face', 'face', case when random() < 0.5 then 'human' else 'yokai' end);
  elsif ph = 2 and f.cycle % 6 = 0 and alive is not null then
    m := jsonb_build_object('k', 'chain', 'colors', (select jsonb_object_agg(a::text, colors[o]) from unnest(alive) with ordinality u(a, o)));
    len := 10;
  elsif ph = 3 and f.cycle % 6 = 0 and alive is not null then
    t := alive[1];
    update public.world_gw_members set nameless = true where fight_id = p_fight and owner_id = t;
    m := jsonb_build_object('k', 'name', 'target', t);
    len := 10;
  elsif ph = 4 and f.cycle % 5 = 0 and alive is not null then
    select owner_id into t from public.world_gw_members where fight_id = p_fight and out_rounds = 0 order by (stats ->> 'pres')::numeric desc, random() limit 1;
    select greatest(1, round(coalesce(sum((stats ->> 'attack')::numeric), 0) * 0.8)) into need from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and owner_id <> t;
    m := jsonb_build_object('k', 'vortex', 'tank', t, 'need', need);
    len := 10;
  else
    m := jsonb_build_object('k', 'normal');
  end if;
  update public.world_gw_fights set phase = ph, round = f.round + 1, cycle = f.cycle + 1, mech = m, round_ends_at = now() + make_interval(secs => len), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, f.round + 1, 'tell', case m ->> 'k'
    when 'face' then case when m ->> 'face' = 'human' then '주인이 사람의 얼굴을 든다. 낯익은 노인의 눈이 이쪽을 본다.' else '주인이 요괴의 얼굴을 든다. 비늘 덮인 입이 귀까지 찢어진다.' end
    when 'chain' then '흰 사슬이 조여 온다. 저마다 손목의 사슬 빛깔을 확인하라. (10초)'
    when 'name' then (select name from public.world_gw_members where fight_id = p_fight and owner_id = t) || '의 이름이 물에 녹아 흘러간다. 「네 이름은 이제 내 것이다.」 (10초)'
    when 'vortex' then '귀허의 소용돌이가 일어난다. ' || (select name from public.world_gw_members where fight_id = p_fight and owner_id = t) || '이(가) 버텨야 한다. (10초)'
    else '주인이 숨을 고른다. 물살이 왕좌를 감싸 돈다.' end);
end $$;

-- 싸움 시작: 부적을 쓰고 능력치를 적어 두고 체력을 정한다
create or replace function public.world_gw_start(p_fight uuid) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare f public.world_gw_fights%rowtype; x record; s jsonb; sa numeric := 0; n int := 0;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'wait' then return; end if;
  for x in select m.owner_id, c.inventory, c.health from public.world_gw_members m join public.world_characters c using (owner_id) where m.fight_id = p_fight for update of c loop
    if coalesce((x.inventory ->> 'gwiheo_charm')::int, 0) < 1 or x.health <= 0 then
      delete from public.world_gw_members where fight_id = p_fight and owner_id = x.owner_id;
      continue;
    end if;
    update public.world_characters set inventory = public.world_inv_add(inventory, 'gwiheo_charm', -1), updated_at = now() where owner_id = x.owner_id;
    s := public.world_raid_stats(x.owner_id);
    update public.world_gw_members set stats = s, hp = greatest(30, least(100, x.health)) where fight_id = p_fight and owner_id = x.owner_id;
    insert into public.world_gw_records(owner_id, tries) values (x.owner_id, 1) on conflict (owner_id) do update set tries = world_gw_records.tries + 1;
    sa := sa + coalesce((s ->> 'attack')::numeric, 50); n := n + 1;
  end loop;
  if n = 0 then
    update public.world_gw_fights set status = 'failed', ended_at = now(), updated_at = now() where fight_id = p_fight;
    return;
  end if;
  update public.world_gw_fights set status = 'fight', max_hp = greatest(6000, round(sa * 40)), hp = greatest(6000, round(sa * 40)), phase = 1, round = 0, cycle = 0,
         ends_at = now() + interval '15 minutes', updated_at = now() where fight_id = p_fight;
  perform public.world_gw_say(p_fight, 0, 'phase', '빈 왕좌 위로 물이 솟아 사람 꼴이 된다. 귀허의 주인이 두 얼굴을 번갈아 든다. 「사람의 얼굴에는 사람의 칼을, 요괴의 얼굴에는…」 말끝이 물에 녹는다.');
  perform public.world_gw_next_round(p_fight);
end $$;

-- 체력에 피해를 주고 쓰러지면 세 라운드 물러남(돌아오면 체력 30)
create or replace function public.world_gw_hurt(p_fight uuid, p_uid uuid, p_dmg int, p_round int, p_why text) returns int
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare m public.world_gw_members%rowtype; d int := greatest(0, p_dmg);
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid for update;
  if not found or m.out_rounds > 0 or d = 0 then return 0; end if;
  if m.hp - d <= 0 then
    update public.world_gw_members set hp = 0, out_rounds = 4, falls = falls + 1, nameless = false where fight_id = p_fight and owner_id = p_uid;
    perform public.world_gw_say(p_fight, p_round, 'fall', m.name || ' — ' || p_why || ' ' || d || '의 피해를 입고 물러났습니다(세 라운드 뒤 돌아옴).');
  else
    update public.world_gw_members set hp = m.hp - d where fight_id = p_fight and owner_id = p_uid;
    perform public.world_gw_say(p_fight, p_round, 'hit', m.name || ' — ' || p_why || ' ' || d || '의 피해.');
  end if;
  return d;
end $$;

-- 라운드 풀이: 마감이 지났거나 살아 있는 모두가 골랐을 때
create or replace function public.world_gw_resolve(p_fight uuid) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare f public.world_gw_fights%rowtype; m record; a jsonb; av text; d numeric; hv numeric; boss_dmg numeric := 0; boss_heal numeric := 0; physical boolean;
  k text; vsum numeric := 0; tank_ok boolean := false; freed uuid[] := '{}'; tgt uuid; inv jsonb; amt int; raw numeric; r int; alive int; cr boolean;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return; end if;
  if now() < f.round_ends_at and exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and act is null) then return; end if;
  r := f.round; k := f.mech ->> 'k';
  -- ① 조사원들의 행동
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 order by joined_at loop
    a := coalesce(m.act, '{"a":"guard"}'::jsonb); av := a ->> 'a';
    if m.act is not null then update public.world_gw_members set acts = acts + 1 where fight_id = p_fight and owner_id = m.owner_id; end if;
    if av = 'attack' then
      cr := random() * 100 < coalesce((m.stats ->> 'crit')::numeric, 5);
      d := coalesce((m.stats ->> 'attack')::numeric, 50) * (0.9 + random() * 0.2) * case when cr then 1.5 else 1 end;
      physical := coalesce(m.stats ->> 'style', 'melee') in ('melee', 'ranged');
      if m.nameless then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 이름을 잃어 칼끝이 주인에게 닿지 않습니다.');
      elsif k = 'face' and ((f.mech ->> 'face' = 'human') <> physical) then
        boss_heal := boss_heal + round(d * 0.5);
        perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — ' || case when physical then '요괴의 얼굴에 칼을 대자' else '사람의 얼굴에 술법을 쓰자' end || ' 주인이 그 힘을 삼켜 ' || round(d * 0.5) || ' 회복합니다.');
      else
        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;
        update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
        perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — ' || round(d) || case when cr then '의 치명타.' else '의 피해.' end);
      end if;
    elsif av = 'guard' then
      if k = 'vortex' and m.owner_id::text = f.mech ->> 'tank' then tank_ok := true; end if;
    elsif av = 'item' then
      tgt := coalesce(nullif(a ->> 't', '')::uuid, m.owner_id);
      select inventory into inv from public.world_characters where owner_id = m.owner_id for update;
      if coalesce((inv ->> (a ->> 'i'))::int, 0) < 1 then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 꺼낼 물품이 없습니다.');
      else
        hv := case a ->> 'i' when 'tonic' then 35 when 'herbal_extract' then 22 when 'rejuv_pill' then 60 when 'grand_pill' then 100 when 'banyo_salve' then 70 else 0 end
              * case when m.job_key = 'medic' then case when tgt <> m.owner_id then 1.4 else 1.15 end else 1 end;
        update public.world_characters set inventory = public.world_inv_add(inventory, a ->> 'i', -1), updated_at = now() where owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round(hv)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
        update public.world_gw_members set heal = heal + round(hv)::int where fight_id = p_fight and owner_id = m.owner_id;
        perform public.world_gw_say(p_fight, r, 'heal', m.name || ' — ' || (select name from public.world_gw_members where fight_id = p_fight and owner_id = tgt) || '의 체력 +' || round(hv) || '.');
      end if;
    elsif av = 'purify' then
      tgt := nullif(a ->> 't', '')::uuid;
      if k <> 'name' or tgt is distinct from (f.mech ->> 'target')::uuid then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 정화할 곳이 없습니다.');
      else
        select inventory into inv from public.world_characters where owner_id = m.owner_id for update;
        if coalesce((inv ->> 'ward_talisman')::int, 0) < 1 then
          perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 정화 부적이 없습니다.');
        else
          update public.world_characters set inventory = public.world_inv_add(inventory, 'ward_talisman', -1), updated_at = now() where owner_id = m.owner_id;
          if tgt <> m.owner_id or random() < 0.3 then
            update public.world_gw_members set nameless = false where fight_id = p_fight and owner_id = tgt;
            perform public.world_gw_say(p_fight, r, 'good', m.name || ' — 정화 부적으로 ' || (select name from public.world_gw_members where fight_id = p_fight and owner_id = tgt) || '의 이름을 되찾아 주었습니다.');
          else
            perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — 제 이름을 스스로 부르려 했지만 목소리가 물에 녹았습니다.');
          end if;
        end if;
      end if;
    elsif av = 'chain' then
      if k <> 'chain' then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 끊을 사슬이 없습니다.');
      elsif a ->> 'c' = f.mech -> 'colors' ->> m.owner_id::text then
        freed := freed || m.owner_id;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — 자기 사슬(' || (a ->> 'c') || ')을 끊었습니다.');
      else
        perform public.world_gw_hurt(p_fight, m.owner_id, 20, r, '남의 사슬(' || coalesce(a ->> 'c', '?') || ')을 쳐 되튕긴 사슬에');
      end if;
    end if;
  end loop;
  -- ② 기믹 결과
  if k = 'chain' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '끊지 못한 사슬에 끌려가');
    end loop;
    if exists (select 1 from public.world_gw_members where fight_id = p_fight and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text) then
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 loop
        perform public.world_gw_hurt(p_fight, m.owner_id, 30, r, '사슬이 끌어당긴 물살에');
      end loop;
    end if;
  elsif k = 'name' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and nameless loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '이름을 끝내 찾지 못해');
    end loop;
  elsif k = 'vortex' then
    if tank_ok and vsum >= coalesce((f.mech ->> 'need')::numeric, 0) then
      boss_dmg := boss_dmg + round(vsum * 0.5);
      perform public.world_gw_say(p_fight, r, 'good', '소용돌이를 끊었습니다! 흩어진 물살이 주인에게 되돌아가 ' || round(vsum * 0.5) || '의 피해를 더 줍니다.');
    else
      perform public.world_gw_say(p_fight, r, 'bad', case when not tank_ok then '버텨야 할 사람이 버티지 못했습니다. ' else '몰아친 힘이 모자랐습니다. ' end || '소용돌이가 모두를 삼키고 주인이 더 사나워집니다.');
      update public.world_gw_members set hp = greatest(1, hp / 2) where fight_id = p_fight and out_rounds = 0;
      update public.world_gw_fights set enrage = enrage + 1 where fight_id = p_fight;
      f.enrage := f.enrage + 1;
    end if;
  end if;
  -- ③ 보스 체력
  update public.world_gw_fights set hp = least(max_hp, greatest(0, hp - round(boss_dmg)::int + round(boss_heal)::int)), updated_at = now() where fight_id = p_fight returning * into f;
  if f.hp <= 0 then perform public.world_gw_settle(p_fight, true); return; end if;
  -- ④ 보스의 반격(기믹 라운드에는 쉰다): 이목에 비례해 하나를 노리고, 네 라운드마다 모두에게 물살
  if k in ('face', 'normal') then
    raw := (35 + 4 * f.phase) * (1 + 0.15 * f.enrage);
    if r % 4 = 0 then
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 loop
        d := raw * 0.55 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((m.stats ->> 'inc')::numeric, 0) / 100.0)
             * case when coalesce(m.act ->> 'a', 'guard') = 'guard' then 0.4 else 1 end;
        perform public.world_gw_hurt(p_fight, m.owner_id, round(d)::int, r, '쏟아지는 물살에');
      end loop;
    else
      select * into m from public.world_gw_members where fight_id = p_fight and out_rounds = 0
       order by -ln(greatest(random(), 1e-9)) / power(greatest(1, coalesce((stats ->> 'pres')::numeric, 30)), 1.3) limit 1;
      if m.owner_id is not null then
        if random() * 100 < coalesce((m.stats ->> 'eva')::numeric, 0) then
          perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 주인의 손길을 피했습니다.');
        else
          d := raw * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((m.stats ->> 'inc')::numeric, 0) / 100.0)
               * case when coalesce(m.act ->> 'a', 'guard') = 'guard' then 0.4 else 1 end;
          perform public.world_gw_hurt(p_fight, m.owner_id, round(d)::int, r, '주인의 손아귀에');
        end if;
      end if;
    end if;
  end if;
  -- ⑤ 물러난 이의 복귀, 끝 판정, 다음 라운드
  update public.world_gw_members set out_rounds = out_rounds - 1, hp = case when out_rounds = 1 then 30 else hp end where fight_id = p_fight and out_rounds > 0;
  select count(*) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
  if alive = 0 then
    perform public.world_gw_say(p_fight, r, 'bad', '모두가 물러났습니다. 소용돌이가 왕좌를 덮습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  if now() >= f.ends_at then
    perform public.world_gw_say(p_fight, r, 'bad', '시간이 다 되었습니다. 귀허의 주인이 바다 밑으로 가라앉습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  perform public.world_gw_next_round(p_fight);
end $$;

-- 끝: 체력을 캐릭터에 돌려 쓰고 보상·벌칙
create or replace function public.world_gw_settle(p_fight uuid, p_won boolean) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare f public.world_gw_fights%rowtype; m record; today date := (now() at time zone 'Asia/Seoul')::date; rec public.world_gw_records%rowtype; n int; solo boolean; flawless boolean;
  is_first boolean; xp int; msg text; lv int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status not in ('fight', 'wait') then return; end if;
  update public.world_gw_fights set status = case when p_won then 'won' else 'failed' end, ended_at = now(), updated_at = now(), hp = case when p_won then 0 else hp end where fight_id = p_fight;
  select count(*), coalesce(sum(falls), 0) = 0 into n, flawless from public.world_gw_members where fight_id = p_fight;
  solo := n = 1;
  for m in select * from public.world_gw_members where fight_id = p_fight loop
    if p_won then
      update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
      select * into rec from public.world_gw_records where owner_id = m.owner_id for update;
      if rec.last_kill_day is distinct from today then
        is_first := coalesce(rec.kills, 0) = 0;
        update public.world_gw_records set kills = kills + 1, last_kill_day = today, first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id;
        select level into lv from public.world_characters where owner_id = m.owner_id;
        xp := case when is_first then round(public.world_xp_need(lv) * 0.5) else round(public.world_xp_need(lv) * 0.05) end;
        update public.world_characters set gil = gil + case when is_first then 1500 else 120 end, updated_at = now() where owner_id = m.owner_id;
        perform public.world_grant_xp(m.owner_id, xp);
        if is_first then
          insert into public.world_owned_mounts(owner_id, mount_id) values (m.owner_id, 'moonless_boat') on conflict do nothing;
          insert into public.world_faction_unlocks(owner_id, unlock_key) values (m.owner_id, 'ns:1028') on conflict do nothing;
        end if;
        msg := case when is_first then '귀허의 주인을 처음으로 쓰러뜨렸습니다. 1,500전 · 경험치 ' || xp || ' · 탈것 「달 없는 배」 · 이름 색 「귀허청」을 얻었습니다.'
                    else '귀허의 주인을 쓰러뜨렸습니다(' || (coalesce(rec.kills, 0) + 1) || '번째). 120전 · 경험치 ' || xp || '.' end;
        insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '귀허의 주인 처치', msg, jsonb_build_object('fight_id', p_fight, 'first', is_first));
        -- 칭호·꾸미기는 기록(gw_win)으로 판정한다(world_title_rule_ok의 ev 규칙)
        insert into public.world_events(actor_id, actor_name, event_type, content, payload)
        values (m.owner_id, m.name, 'gw_win', m.name || '이(가) 귀허의 주인을 쓰러뜨렸습니다.',
                jsonb_build_object('fight_id', p_fight, 'first', is_first, 'solo', solo, 'flawless', flawless and n >= 2, 'members', n, 'kills', coalesce(rec.kills, 0) + 1));
      else
        insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '귀허의 주인 처치', '오늘은 이미 처치를 인정받아 보상은 없습니다.', jsonb_build_object('fight_id', p_fight));
      end if;
    else
      -- 실패 벌칙: 장착 장비 내구도 −10%, 침식 +10, 30분 뒤 재도전(부적은 이미 씀). 경험치·물품은 잃지 않는다
      update public.world_item_durability d set durability = greatest(0, d.durability - ceil(public.world_item_max_durability(d.item_id) * 0.1)::int), updated_at = now()
        from public.world_character_equipment e where e.owner_id = m.owner_id and d.owner_id = m.owner_id and d.item_id = e.item_id;
      update public.world_characters set health = greatest(1, m.hp), erosion = least(100, erosion + 10),
             erosion_stage = case when least(100, erosion + 10) >= 80 then 4 when least(100, erosion + 10) >= 55 then 3 when least(100, erosion + 10) >= 30 then 2 when least(100, erosion + 10) >= 10 then 1 else 0 end,
             updated_at = now() where owner_id = m.owner_id;
      insert into public.world_gw_records(owner_id, last_fail_at) values (m.owner_id, now()) on conflict (owner_id) do update set last_fail_at = now();
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (m.owner_id, 'gw', '귀허의 주인 도전 실패', '소용돌이에 밀려났습니다. 장착한 장비 내구도가 10% 닳고 침식이 10 올랐습니다. 30분 뒤 다시 도전할 수 있습니다.', jsonb_build_object('fight_id', p_fight));
    end if;
  end loop;
  perform public.world_gw_say(p_fight, f.round, case when p_won then 'win' else 'bad' end, case when p_won
    then '귀허의 주인이 무너진다. 「…이름을 하나만 다오.」 물이 바다로 돌아가고, 소용돌이가 있던 자리에 달빛 비슷한 것이 비친다.'
    else '도전이 끝났습니다.' end);
end $$;

-- 상황 읽기(늦은 시작·라운드 풀이도 여기서): p_fight가 없으면 내가 든 싸움·받은 초대·도전 조건
create or replace function public.world_gw_snapshot(p_fight uuid default null) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; rec public.world_gw_records%rowtype; c public.world_characters%rowtype;
  fid uuid := p_fight; why text; inv_f uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if fid is null then
    select m.fight_id into fid from public.world_gw_members m join public.world_gw_fights x using (fight_id) where m.owner_id = uid and x.status in ('wait', 'fight') order by x.created_at desc limit 1;
  end if;
  select * into c from public.world_characters where owner_id = uid;
  select * into rec from public.world_gw_records where owner_id = uid;
  if fid is null then
    -- 받은 초대(같은 파티·같은 곳·모이는 중)
    select x.fight_id into inv_f from public.world_gw_fights x join public.world_party_members a on a.owner_id = x.leader_id join public.world_party_members b on b.party_id = a.party_id and b.owner_id = uid
     where x.status = 'wait' and x.start_at > now() order by x.created_at desc limit 1;
    begin perform public.world_gw_ready_check(uid); exception when others then why := sqlerrm; end;
    return jsonb_build_object('none', true, 'invite', inv_f, 'can_open', why is null, 'why', why, 'charms', coalesce((c.inventory ->> 'gwiheo_charm')::int, 0),
      'kills', coalesce(rec.kills, 0), 'tips', case when coalesce(rec.kills, 0) > 0 then public.world_gw_tips() end, 'here', (public.world_region_at(c.location)).region_id = 'gwiheo_core');
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
  return jsonb_build_object('fight', jsonb_build_object('id', f.fight_id, 'status', f.status, 'hp', f.hp, 'max_hp', f.max_hp, 'phase', f.phase, 'round', f.round,
      'round_ends_at', f.round_ends_at, 'ends_at', f.ends_at, 'start_at', f.start_at, 'leader', f.leader_id, 'enrage', f.enrage,
      'mech', case f.mech ->> 'k' when 'chain' then jsonb_build_object('k', 'chain', 'colors', (select jsonb_agg(v order by v) from jsonb_each_text(f.mech -> 'colors') e(kk, v)), 'mine', f.mech -> 'colors' ->> uid::text)
                              when 'vortex' then f.mech - 'need' || jsonb_build_object('need', (f.mech ->> 'need')::int)
                              else f.mech end),
    'now', now(), 'me', uid,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', m.owner_id, 'name', m.name, 'job', m.job_key, 'level', m.level, 'hp', m.hp, 'out', m.out_rounds,
        'nameless', m.nameless, 'acted', m.act is not null, 'dmg', m.dmg, 'heal', m.heal, 'falls', m.falls) order by m.joined_at), '[]'::jsonb) from public.world_gw_members m where m.fight_id = fid),
    'my_act', me.act, 'joined', me.owner_id is not null,
    'items', (select coalesce(jsonb_object_agg(i, coalesce((c.inventory ->> i)::int, 0)), '{}'::jsonb) from unnest(array['tonic', 'herbal_extract', 'rejuv_pill', 'grand_pill', 'banyo_salve', 'ward_talisman']) i),
    'log', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'round', l.round, 'kind', l.kind, 'text', l.text) order by l.id), '[]'::jsonb)
              from (select * from public.world_gw_log where fight_id = fid order by id desc limit 60) l),
    'tips', case when coalesce(rec.kills, 0) > 0 then public.world_gw_tips() end);
end $$;

-- 도전 조건만 확인(잠그지 않음, 상황 읽기용)
create or replace function public.world_gw_ready_check(p_uid uuid) returns void
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype; rec public.world_gw_records%rowtype;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if (public.world_region_at(c.location)).region_id is distinct from 'gwiheo_core' then raise exception '귀허에서만 도전할 수 있습니다.'; end if;
  if c.level < 38 then raise exception 'Lv38부터 도전할 수 있습니다.'; end if;
  if not public.world_quest_done(p_uid, 'gq_4') then raise exception '외전 4장 「달 없는 장」을 마쳐야 합니다.'; end if;
  select * into rec from public.world_gw_records where owner_id = p_uid;
  if rec.last_kill_day = (now() at time zone 'Asia/Seoul')::date then raise exception '오늘은 이미 처치했습니다. 내일 다시 도전할 수 있습니다.'; end if;
  if rec.last_fail_at > now() - interval '30 minutes' then raise exception '%분 뒤 다시 도전할 수 있습니다.', ceil(extract(epoch from rec.last_fail_at + interval '30 minutes' - now()) / 60); end if;
  if coalesce((c.inventory ->> 'gwiheo_charm')::int, 0) < 1 then raise exception '귀허 부적이 필요합니다(반요촌 잡화).'; end if;
end $$;

-- 파훼법: 처치한 조사원에게만
create or replace function public.world_gw_tips() returns jsonb
language sql immutable set search_path to 'pg_catalog' as $$
  select jsonb_build_array(
    '두 얼굴: 사람의 얼굴에는 근접·원거리(물리), 요괴의 얼굴에는 술법만 듣는다. 반대로 치면 주인이 회복하니 맞지 않는 쪽은 방어하거나 회복을 맡는다.',
    '사슬 넷: 저마다 손목 사슬의 빛깔이 다르다. 10초 안에 자기 빛깔의 사슬만 끊는다. 남의 사슬을 치면 되튕기고, 못 끊은 사람은 끌려간다.',
    '이름 빼앗기: 이름을 잃은 사람의 공격은 닿지 않는다. 동료가 10초 안에 그 사람에게 정화 부적을 써 줘야 풀린다(스스로는 잘 안 된다).',
    '귀허의 소용돌이: 이목이 가장 높은 사람이 방어로 버티고, 나머지는 모두 공격해 정해진 양을 넘겨야 끊긴다. 실패하면 모두 체력 절반·주인 분노.',
    '보통 라운드에도 주인은 이목이 높은 사람을 더 자주 노리고, 네 라운드마다 모두를 친다. 고르지 않으면 저절로 방어한다.')
$$;

-- 도전 열기: 혼자면 바로 시작, 같은 곳에 파티원이 있으면 60초 동안 모은다
create or replace function public.world_gw_open() returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; fid uuid; x record; n int := 0;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  c := public.world_gw_ready(uid);
  select count(*) into n from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id and b.owner_id <> a.owner_id
    join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null;
  insert into public.world_gw_fights(leader_id, status, start_at) values (uid, 'wait', now() + case when n > 0 then interval '60 seconds' else interval '0' end) returning fight_id into fid;
  insert into public.world_gw_members(fight_id, owner_id, name, job_key, level) values (fid, uid, c.character_name, c.job_key, c.level);
  for x in select b.owner_id from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id and b.owner_id <> a.owner_id
             join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null limit 3 loop
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (x.owner_id, 'gw_invite', '귀허의 주인 · 함께 싸우기', c.character_name || '이(가) 귀허의 주인 앞에 섰습니다. 60초 안에 합류하세요(귀허 부적 1개).', jsonb_build_object('fight_id', fid));
  end loop;
  if n = 0 then perform public.world_gw_start(fid); end if;
  return public.world_gw_snapshot(fid);
end $$;

create or replace function public.world_gw_join(p_fight uuid) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; f public.world_gw_fights%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if not found or f.status <> 'wait' or f.start_at <= now() then raise exception '합류할 수 있는 시간이 지났습니다.'; end if;
  if not exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id where a.owner_id = f.leader_id and b.owner_id = uid) then
    raise exception '도전을 연 조사원의 파티원만 합류할 수 있습니다.'; end if;
  if (select count(*) from public.world_gw_members where fight_id = p_fight) >= 4 then raise exception '귀허의 주인 앞에는 4명까지 설 수 있습니다.'; end if;
  c := public.world_gw_ready(uid);
  insert into public.world_gw_members(fight_id, owner_id, name, job_key, level) values (p_fight, uid, c.character_name, c.job_key, c.level) on conflict do nothing;
  if (select count(*) from public.world_gw_members where fight_id = p_fight) >= 4 then perform public.world_gw_start(p_fight); end if;
  return public.world_gw_snapshot(p_fight);
end $$;

create or replace function public.world_gw_begin(p_fight uuid) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_gw_fights where fight_id = p_fight and leader_id = uid and status = 'wait') then raise exception '도전을 연 조사원만 바로 시작할 수 있습니다.'; end if;
  perform public.world_gw_start(p_fight);
  return public.world_gw_snapshot(p_fight);
end $$;

-- 행동 고르기: a = attack·guard·item(i, t)·purify(t)·chain(c)
create or replace function public.world_gw_act(p_fight uuid, p_action text, p_target uuid default null, p_item text default null) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; a jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_action not in ('attack', 'guard', 'item', 'purify', 'chain') then raise exception '알 수 없는 행동입니다.'; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if not found or f.status <> 'fight' then raise exception '싸움이 끝났습니다.'; end if;
  if now() >= f.round_ends_at then perform public.world_gw_resolve(p_fight); select * into f from public.world_gw_fights where fight_id = p_fight; end if;
  if f.status <> 'fight' then return public.world_gw_snapshot(p_fight); end if;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = uid for update;
  if not found then raise exception '이 싸움에 들지 않았습니다.'; end if;
  if me.out_rounds > 0 then raise exception '물러나 있습니다. %라운드 뒤 돌아옵니다.', me.out_rounds; end if;
  if p_action = 'item' and coalesce(p_item, '') not in ('tonic', 'herbal_extract', 'rejuv_pill', 'grand_pill', 'banyo_salve') then raise exception '싸움 중에는 회복품만 쓸 수 있습니다.'; end if;
  if p_target is not null and not exists (select 1 from public.world_gw_members where fight_id = p_fight and owner_id = p_target) then raise exception '함께 싸우는 조사원이 아닙니다.'; end if;
  a := jsonb_build_object('a', p_action) || case when p_target is not null then jsonb_build_object('t', p_target) else '{}'::jsonb end
       || case when p_action = 'item' then jsonb_build_object('i', p_item) when p_action = 'chain' then jsonb_build_object('c', coalesce(p_item, '')) else '{}'::jsonb end;
  update public.world_gw_members set act = a where fight_id = p_fight and owner_id = uid;
  perform public.world_gw_resolve(p_fight);
  return public.world_gw_snapshot(p_fight);
end $$;

do $$ declare f text; begin
  foreach f in array array['world_gw_say(uuid,integer,text,text)', 'world_gw_ready(uuid)', 'world_gw_next_round(uuid)', 'world_gw_start(uuid)', 'world_gw_hurt(uuid,uuid,integer,integer,text)',
                           'world_gw_resolve(uuid)', 'world_gw_settle(uuid,boolean)', 'world_gw_snapshot(uuid)', 'world_gw_ready_check(uuid)', 'world_gw_tips()',
                           'world_gw_open()', 'world_gw_join(uuid)', 'world_gw_begin(uuid)', 'world_gw_act(uuid,text,uuid,text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
grant execute on function public.world_gw_snapshot(uuid), public.world_gw_open(), public.world_gw_join(uuid), public.world_gw_begin(uuid), public.world_gw_act(uuid,text,uuid,text) to authenticated;

-- 퀘스트 할 일 {t:'gw'}: 귀허의 주인 처치(행동을 한 번이라도 한 싸움)
select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)', '  select case when p_task ->> ''t'' = ''raid'' then',
  '  select case when p_task ->> ''t'' = ''gw'' then (select count(*)::int from public.world_gw_members m join public.world_gw_fights x on x.fight_id = m.fight_id
                where m.owner_id = p_uid and x.status = ''won'' and m.acts > 0 and x.ended_at >= p_since)
    when p_task ->> ''t'' = ''raid'' then');
grant select on public.world_gw_members, public.world_gw_fights to fn_owner_field;

-- 보상: 탈것·칭호·꾸미기(칭호·꾸미기는 gw_win 기록으로 판정)
insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method)
values ('moonless_boat', '달 없는 배', 2.4, 38, 0, 0, '귀허의 주인을 쓰러뜨린 조사원을 태우는 검은 배. 물길도 뭍도 소리 없이 미끄러진다. 운임은 구간당 노정패 1.', '영물', 2, 1, false, 'event')
on conflict (mount_id) do update set description = excluded.description, speed_multiplier = excluded.speed_multiplier;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
 ('gw_kill1', '귀허를 닫은 자', 'flag', '바다 끝의 소용돌이를 처음으로 닫았다.', '귀허의 주인을 쓰러뜨린다', '{"combat_damage_pct": 3, "erosion_pct": -6, "presence": 6}', true, false, '{"ev": "gw_win", "n": 1}', 1100, '외전', 5),
 ('gw_kill3', '빈 왕좌의 손님', 'flag', '빈 왕좌 앞에 세 번 섰다.', '귀허의 주인을 3번 쓰러뜨린다', '{"incoming_damage_pct": -3, "healing_pct": 4}', true, false, '{"ev": "gw_win", "n": 3}', 1101, '외전', 4),
 ('gw_kill10', '이송 명부를 고쳐 쓴 자', 'flag', '섬으로 보내진 이름들을 열 번 되찾았다.', '귀허의 주인을 10번 쓰러뜨린다', '{"combat_damage_pct": 2, "mental_loss_pct": -6}', true, false, '{"ev": "gw_win", "n": 10}', 1102, '외전', 5),
 ('gw_kill25', '귀허의 배웅꾼', 'flag', '반요촌의 배웅 노래가 이 이름을 부른다.', '귀허의 주인을 25번 쓰러뜨린다', '{"crit_pct": 2, "erosion_pct": -8, "rare_loot_pct": 3}', true, false, '{"ev": "gw_win", "n": 25}', 1103, '외전', 5),
 ('gw_solo', '홀로 이름을 지킨 자', 'flag', '아무도 곁에 없이 귀허의 주인을 쓰러뜨렸다.', '혼자 귀허의 주인을 쓰러뜨린다', '{"combat_damage_pct": 3, "evasion_pct": 2}', true, true, '{"ev": "gw_win", "p": {"solo": true}}', 1104, '외전', 5),
 ('gw_flawless', '한 사람도 잃지 않은 밤', 'flag', '누구 하나 물러나지 않고 귀허의 주인을 쓰러뜨렸다.', '둘 이상이 함께, 아무도 물러나지 않고 귀허의 주인을 쓰러뜨린다', '{"healing_pct": 5, "incoming_damage_pct": -3}', true, true, '{"ev": "gw_win", "p": {"flawless": true}}', 1105, '외전', 5)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade, hidden = excluded.hidden;
insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
 ('fr_gwiheo', 'frame', 'legend', '귀허 소용돌이 테', '귀허의 주인을 쓰러뜨린다', '외전', '{"ev": "gw_win"}', false, true, 1100),
 ('pt_gwiheo', 'pattern', 'legend', '달 없는 물결 무늬', '귀허의 주인을 3번 쓰러뜨린다', '외전', '{"ev": "gw_win", "n": 3}', false, true, 1101),
 ('sl_gwi', 'seal', 'legend', '낙관 「歸」', '귀허의 주인을 10번 쓰러뜨린다', '외전', '{"ev": "gw_win", "n": 10}', false, true, 1102)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, category = excluded.category;
