-- 11차 편의·가방·거래(서버). SQL Editor에서 한 번에 실행한다. 하나라도 실패하면 전체가 되돌려진다.
--  1) 전투 행동 간격 2초 → 1초
--  2) 휴식 쿨타임: 잠깐 쉬기 10분, 푹 쉬기 30분(본부 무료 휴식을 반복해 탐색력·회복을 무한히 얻던 문제)
--  3) 소속 보급: 받은 품목을 응답 문구에 담고, 기록에 영문 소속 코드 대신 한글 이름
--  4) 새 캐릭터: 직업별 기본 무기 + 누비 전포 + 현장 채집도를 주고 장착해 둔다
--  5) 가방: 잠금(world_item_locks)·버리기(world_item_discard). 잠근 물품·장착 중인 마지막 한 개는 상점·거래소에 팔 수 없다
--  6) 거래소 등록 제한: 한 사람당 동시에 10건, 기준 시세의 30% 미만 가격 금지(헐값 넘기기로 재화를 옮기는 것 방지)
--  7) 조사원 간 직접 거래(world_direct_trades): 같은 안전지대에 있는 상대에게 물품·전을 주고받는 제안 → 상대가 수락하면 한 번에 교환
--
-- 다른 역할이 소유한 함수(fn_owner_18538·18878·18879·19111)는 바꾸는 동안만 postgres가 소유자 권한을 물려받게 하고 끝나면 끈다.
-- fn_owner_field 함수는 postgres가 원래 물려받으므로 그대로 바꾼다. 소유자·search_path·권한은 바뀌지 않는다.

grant fn_owner_18538, fn_owner_18878, fn_owner_18879, fn_owner_19111 to postgres with inherit true;

-- 공용 이름 함수(앞 마이그레이션에서 만듦)에 실행 권한 추가
grant execute on function public.world_faction_name(text) to fn_owner_18538;
-- 가방 칸 수 세기: 기존 world_bag_count는 다른 역할 소유라 실행 권한을 넘길 수 없어 같은 계산을 따로 둔다
create or replace function public.world_inv_count(p_inv jsonb) returns int
language sql immutable set search_path = '' as $$
  select coalesce(sum(greatest(0, case when jsonb_typeof(v) = 'number' then v::text::numeric else 0 end)), 0)::int
  from jsonb_each(coalesce(p_inv, '{}'::jsonb)) as t(k, v)
$$;
revoke all on function public.world_inv_count(jsonb) from public, anon, authenticated;
grant execute on function public.world_inv_count(jsonb) to fn_owner_field;

/* ── 1) 전투 행동 간격 1초 ───────────────────────────────── */
do $$ declare f text; def text; nd text; n int; begin
  foreach f in array array['public.world_battle_action(text,text)', 'public.world_field_battle_view(uuid)',
                           'public.world_battle_open(uuid,text,uuid,integer,integer)'] loop
    def := pg_get_functiondef(f::regprocedure);
    n := (length(def) - length(replace(def, 'interval ''2 seconds''', ''))) / length('interval ''2 seconds''');
    if n = 0 then raise exception '% 에서 2초 간격을 찾지 못했습니다.', f; end if;
    nd := replace(def, 'interval ''2 seconds''', 'interval ''1 second''');
    execute nd;
  end loop;
end $$;

/* ── 2) 휴식 쿨타임 ──────────────────────────────────────── */
do $$ declare def text; nd text; begin
  def := pg_get_functiondef('public.world_field_rest(text)'::regprocedure);
  nd := replace(def, 'ambush jsonb;', 'ambush jsonb; last_rest timestamptz; rest_wait interval;');
  nd := replace(nd, 'IF EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = uid AND e.status = ''active'') THEN RAISE EXCEPTION ''원정 중입니다.''; END IF;',
    'IF EXISTS (SELECT 1 FROM public.world_expeditions e WHERE e.owner_id = uid AND e.status = ''active'') THEN RAISE EXCEPTION ''원정 중입니다.''; END IF;
  -- 같은 방식의 휴식은 잠깐 쉬기 10분, 푹 쉬기 30분이 지나야 다시 할 수 있다
  rest_wait := CASE WHEN p_style = ''full'' THEN interval ''30 minutes'' ELSE interval ''10 minutes'' END;
  SELECT max(e.created_at) INTO last_rest FROM public.world_events e
   WHERE e.actor_id = uid AND e.event_type = ''rest'' AND e.payload ->> ''style'' = p_style AND e.created_at > now() - rest_wait;
  IF last_rest IS NOT NULL THEN
    RAISE EXCEPTION ''%'', format(''막 쉬었습니다. %s분 뒤에 다시 %s 수 있습니다.'', ceil(extract(epoch FROM (last_rest + rest_wait - now())) / 60)::int,
      CASE WHEN p_style = ''full'' THEN ''푹 쉴'' ELSE ''쉴'' END);
  END IF;');
  if nd = def or position('rest_wait' in nd) = 0 or position('막 쉬었습니다' in nd) = 0 then raise exception 'world_field_rest 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
end $$;

/* ── 3) 소속 보급 문구 ───────────────────────────────────── */
grant select (item_id, item_name) on public.world_item_catalog to fn_owner_18538;
do $$ declare def text; nd text; begin
  def := pg_get_functiondef('public.world_claim_faction_supply()'::regprocedure);
  nd := replace(def, '''소속 보급 수령: ''||c.faction_key', '''소속 보급 수령: ''||public.world_faction_name(c.faction_key)');
  nd := replace(nd, '''content'',''소속 보급을 수령했습니다.''',
    '''content'',''소속 보급을 수령했습니다: ''||(select string_agg(coalesce(i.item_name,s.key)||'' ×''||s.value, '', '' order by s.key) from jsonb_each_text(supplies) s left join public.world_item_catalog i on i.item_id=s.key)');
  if nd = def or position('world_faction_name' in nd) = 0 or position('jsonb_each_text(supplies)' in nd) = 0 then raise exception 'world_claim_faction_supply 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
end $$;

/* ── 4) 직업별 기본 장비 ─────────────────────────────────── */
grant select (owner_id, slot), insert on public.world_character_equipment to fn_owner_19111;
do $$ declare def text; nd text; begin
  def := pg_get_functiondef('public.world_create_character_v2(text,text,text)'::regprocedure);
  nd := replace(def, 'job_label text;', 'job_label text; wpn text;');
  nd := replace(nd, 'IF job_label IS NULL THEN RAISE EXCEPTION ''직업을 선택하세요.''; END IF;',
    'IF job_label IS NULL THEN RAISE EXCEPTION ''직업을 선택하세요.''; END IF;
  -- 직업별 기본 무기: 술법(퇴마관·봉인술사) · 원거리(현장 조사원·기록 분석관) · 근접(의무관·법구 제작사)
  wpn := CASE p_job WHEN ''exorcist'' THEN ''spirit_bell'' WHEN ''sealmaster'' THEN ''spirit_bell''
                    WHEN ''scout'' THEN ''short_bow'' WHEN ''analyst'' THEN ''short_bow'' ELSE ''iron_sword'' END;');
  nd := replace(nd, '''{"herb":2,"ward_talisman":1,"field_knife":1,"ore_pick":1,"seal_paper":1,"wood":0,"ore":0}''::jsonb',
    '(''{"herb":2,"ward_talisman":1,"field_knife":1,"ore_pick":1,"seal_paper":1,"wood":0,"ore":0,"padded_coat":1}''::jsonb || jsonb_build_object(wpn, 1))');
  nd := replace(nd, 'RETURN jsonb_build_object(''ok'', true, ''character_name''',
    'INSERT INTO public.world_character_equipment(owner_id, slot, item_id)
  VALUES (uid, ''weapon'', wpn), (uid, ''armor'', ''padded_coat''), (uid, ''tool'', ''field_knife'')
  ON CONFLICT (owner_id, slot) DO NOTHING;
  RETURN jsonb_build_object(''ok'', true, ''character_name''');
  if position('wpn := CASE' in nd) = 0 or position('"padded_coat":1' in nd) = 0 or position('world_character_equipment' in nd) = 0 then
    raise exception 'world_create_character_v2 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
end $$;

/* ── 5) 가방 잠금·버리기 ─────────────────────────────────── */
create table if not exists public.world_item_locks (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  item_id text not null,
  locked_at timestamptz not null default now(),
  primary key (owner_id, item_id)
);
alter table public.world_item_locks enable row level security;
drop policy if exists world_item_locks_own on public.world_item_locks;
create policy world_item_locks_own on public.world_item_locks for select to authenticated using (owner_id = (select auth.uid()));
revoke all on public.world_item_locks from anon, authenticated;
grant select on public.world_item_locks to authenticated;
grant select, insert, delete on public.world_item_locks to fn_owner_field;

-- 내주는 행동(판매·거래 등록·직접 거래·버리기) 전에 부른다: 잠근 물품, 장착 중인 마지막 한 개는 내줄 수 없다.
create or replace function public.world_item_give_guard(p_owner uuid, p_item_id text, p_have int, p_qty int) returns void
language plpgsql stable security definer set search_path = '' as $$
declare nm text;
begin
  select item_name into nm from public.world_item_catalog where item_id = p_item_id;
  if exists (select 1 from public.world_item_locks where owner_id = p_owner and item_id = p_item_id) then
    raise exception '잠근 물품입니다: %. 가방에서 잠금을 풀어야 내줄 수 있습니다.', coalesce(nm, '물품');
  end if;
  if exists (select 1 from public.world_character_equipment where owner_id = p_owner and item_id = p_item_id) and coalesce(p_have, 0) - p_qty < 1 then
    raise exception '장착 중인 장비입니다: %. 다른 장비로 바꾼 뒤 내줄 수 있습니다.', coalesce(nm, '장비');
  end if;
end $$;
alter function public.world_item_give_guard(uuid, text, int, int) owner to fn_owner_field;
revoke all on function public.world_item_give_guard(uuid, text, int, int) from public, anon, authenticated;
grant execute on function public.world_item_give_guard(uuid, text, int, int) to fn_owner_18878, fn_owner_18879;

create or replace function public.world_item_lock(p_item_id text, p_locked boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); inv jsonb; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select inventory into inv from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select item_name into nm from public.world_item_catalog where item_id = p_item_id;
  if nm is null then raise exception '알 수 없는 물품입니다.'; end if;
  if p_locked then
    if coalesce((inv ->> p_item_id)::int, 0) < 1 then raise exception '가지고 있지 않은 물품입니다.'; end if;
    insert into public.world_item_locks(owner_id, item_id) values (uid, p_item_id) on conflict do nothing;
  else
    delete from public.world_item_locks where owner_id = uid and item_id = p_item_id;
  end if;
  return jsonb_build_object('ok', true, 'locked', p_locked, 'content', nm || case when p_locked then '을(를) 잠갔습니다. 팔거나 버릴 수 없습니다.' else '의 잠금을 풀었습니다.' end);
end $$;

create or replace function public.world_item_discard(p_item_id text, p_qty integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; have int; inv jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_qty is null or p_qty < 1 or p_qty > 9999 then raise exception '버릴 수량이 올바르지 않습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) then raise exception '현재 상태에서는 버릴 수 없습니다.'; end if;
  select * into it from public.world_item_catalog where item_id = p_item_id;
  if it.item_id is null then raise exception '알 수 없는 물품입니다.'; end if;
  if it.category = 'quest' then raise exception '임무 물품은 버릴 수 없습니다.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb); have := coalesce((inv ->> p_item_id)::int, 0);
  if have < p_qty then raise exception '가진 수량보다 많이 버릴 수 없습니다.'; end if;
  perform public.world_item_give_guard(uid, p_item_id, have, p_qty);
  inv := case when have = p_qty then inv - p_item_id else jsonb_set(inv, array[p_item_id], to_jsonb(have - p_qty)) end;
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'discard', it.item_name || ' ×' || p_qty || '을(를) 버렸습니다.', jsonb_build_object('item', p_item_id, 'qty', p_qty));
  return jsonb_build_object('ok', true, 'content', it.item_name || ' ×' || p_qty || '을(를) 버렸습니다.', 'inventory', inv);
end $$;

/* ── 5') 판매·거래 등록에 잠금·장착 검사, 등록 제한 ──────────── */
create or replace function public.world_trade_listing_guard(p_owner uuid, p_item_id text, p_unit_price bigint) returns void
language plpgsql stable security definer set search_path = '' as $$
declare ref bigint; open_n int;
begin
  select count(*) into open_n from public.world_trade_offers where seller_id = p_owner and status = 'open' and expires_at > now();
  if open_n >= 10 then raise exception '거래소에는 한 사람이 동시에 10건까지 등록할 수 있습니다. 팔리거나 취소된 뒤 다시 등록하세요.'; end if;
  select reference_price into ref from public.world_item_catalog where item_id = p_item_id;
  if ref is not null and ref > 0 and p_unit_price < ceil(ref * 0.3) then
    raise exception '기준 시세(%전)의 30%%보다 싸게 등록할 수 없습니다. 최저 %전', ref, ceil(ref * 0.3)::bigint;
  end if;
end $$;
alter function public.world_trade_listing_guard(uuid, text, bigint) owner to fn_owner_field;
revoke all on function public.world_trade_listing_guard(uuid, text, bigint) from public, anon, authenticated;
grant execute on function public.world_trade_listing_guard(uuid, text, bigint) to fn_owner_18879;

do $$ declare def text; nd text; begin
  def := pg_get_functiondef('public.world_shop_sell(text,integer)'::regprocedure);
  nd := replace(def, ' if coalesce((inv->>p_item_id)::int,0)<p_qty then raise exception ''보유 수량이 부족합니다.''; end if;',
    ' if coalesce((inv->>p_item_id)::int,0)<p_qty then raise exception ''보유 수량이 부족합니다.''; end if;
 perform public.world_item_give_guard(uid,p_item_id,coalesce((inv->>p_item_id)::int,0),p_qty);');
  if nd = def then raise exception 'world_shop_sell 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
  def := pg_get_functiondef('public.world_trade_offer_create(text,integer,bigint)'::regprocedure);
  nd := replace(def, 'IF coalesce((inv->>p_item_id)::int,0)<p_qty THEN RAISE EXCEPTION ''판매할 재료가 부족합니다.''; END IF;',
    'IF coalesce((inv->>p_item_id)::int,0)<p_qty THEN RAISE EXCEPTION ''판매할 재료가 부족합니다.''; END IF; PERFORM public.world_item_give_guard(uid,p_item_id,coalesce((inv->>p_item_id)::int,0),p_qty); PERFORM public.world_trade_listing_guard(uid,p_item_id,p_unit_price);');
  if nd = def then raise exception 'world_trade_offer_create 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
end $$;

/* ── 7) 조사원 간 직접 거래 ──────────────────────────────── */
create table if not exists public.world_direct_trades (
  trade_id uuid primary key default gen_random_uuid(),
  from_id uuid not null references public.world_characters(owner_id) on delete cascade,
  to_id uuid not null references public.world_characters(owner_id) on delete cascade,
  give_items jsonb not null default '{}'::jsonb,
  give_gil bigint not null default 0 check (give_gil >= 0),
  want_items jsonb not null default '{}'::jsonb,
  want_gil bigint not null default 0 check (want_gil >= 0),
  location text not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 minutes',
  responded_at timestamptz,
  check (from_id <> to_id)
);
create index if not exists world_direct_trades_to_idx on public.world_direct_trades (to_id, status);
create index if not exists world_direct_trades_from_idx on public.world_direct_trades (from_id, status);
alter table public.world_direct_trades enable row level security;
drop policy if exists world_direct_trades_party on public.world_direct_trades;
create policy world_direct_trades_party on public.world_direct_trades for select to authenticated
  using ((select auth.uid()) in (from_id, to_id));
revoke all on public.world_direct_trades from anon, authenticated;
grant select on public.world_direct_trades to authenticated;
grant select, insert, update on public.world_direct_trades to fn_owner_field;

-- 물품 묶음 검사: 알맞은 수량, 거래 가능, 가진 만큼, 잠금·장착 검사
create or replace function public.world_trade_bundle_check(p_owner uuid, p_inv jsonb, p_items jsonb) returns void
language plpgsql stable security definer set search_path = '' as $$
declare k text; v jsonb; q int; it public.world_item_catalog%rowtype; have int;
begin
  if jsonb_typeof(coalesce(p_items, '{}'::jsonb)) <> 'object' then raise exception '거래 물품 형식이 올바르지 않습니다.'; end if;
  if (select count(*) from jsonb_object_keys(coalesce(p_items, '{}'::jsonb))) > 8 then raise exception '한 번에 8가지 물품까지 거래할 수 있습니다.'; end if;
  for k, v in select * from jsonb_each(coalesce(p_items, '{}'::jsonb)) loop
    if jsonb_typeof(v) <> 'number' then raise exception '거래 수량이 올바르지 않습니다.'; end if;
    q := v::text::numeric::int;
    if q < 1 or q > 999 or v::text::numeric <> q then raise exception '거래 수량은 1~999개입니다.'; end if;
    select * into it from public.world_item_catalog where item_id = k;
    if it.item_id is null then raise exception '알 수 없는 물품이 있습니다.'; end if;
    if not coalesce(it.tradeable, false) then raise exception '%은(는) 거래할 수 없는 물품입니다.', it.item_name; end if;
    have := coalesce((p_inv ->> k)::int, 0);
    if have < q then raise exception '%이(가) 모자랍니다. (가진 수량 %)', it.item_name, have; end if;
    perform public.world_item_give_guard(p_owner, k, have, q);
  end loop;
end $$;
alter function public.world_trade_bundle_check(uuid, jsonb, jsonb) owner to fn_owner_field;
revoke all on function public.world_trade_bundle_check(uuid, jsonb, jsonb) from public, anon, authenticated;

create or replace function public.world_trade_bundle_text(p_items jsonb, p_gil bigint) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(nullif(concat_ws(', ',
    (select string_agg(coalesce(i.item_name, s.key) || ' ×' || s.value, ', ' order by s.key) from jsonb_each_text(coalesce(p_items, '{}'::jsonb)) s
      left join public.world_item_catalog i on i.item_id = s.key),
    case when coalesce(p_gil, 0) > 0 then p_gil || '전' end), ''), '없음')
$$;
alter function public.world_trade_bundle_text(jsonb, bigint) owner to fn_owner_field;
revoke all on function public.world_trade_bundle_text(jsonb, bigint) from public, anon, authenticated;

-- 묶음을 더하거나 빼 새 가방 내용을 만든다(0개가 되면 칸을 지운다)
create or replace function public.world_inv_apply(p_inv jsonb, p_items jsonb, p_sign int) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare k text; v text; inv jsonb := coalesce(p_inv, '{}'::jsonb); n int;
begin
  for k, v in select * from jsonb_each_text(coalesce(p_items, '{}'::jsonb)) loop
    n := coalesce((inv ->> k)::int, 0) + p_sign * v::int;
    inv := case when n <= 0 then inv - k else jsonb_set(inv, array[k], to_jsonb(n), true) end;
  end loop;
  return inv;
end $$;
revoke all on function public.world_inv_apply(jsonb, jsonb, int) from public, anon, authenticated;
grant execute on function public.world_inv_apply(jsonb, jsonb, int) to fn_owner_field;

create or replace function public.world_trade_direct_offer(p_to uuid, p_give jsonb, p_give_gil bigint, p_want jsonb, p_want_gil bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); a public.world_characters%rowtype; b public.world_characters%rowtype; r public.world_map_regions%rowtype; tid uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_to is null or p_to = uid then raise exception '거래할 상대를 고르세요.'; end if;
  p_give := coalesce(p_give, '{}'::jsonb); p_want := coalesce(p_want, '{}'::jsonb);
  p_give_gil := coalesce(p_give_gil, 0); p_want_gil := coalesce(p_want_gil, 0);
  if p_give_gil < 0 or p_want_gil < 0 or p_give_gil > 100000000 or p_want_gil > 100000000 then raise exception '전 액수가 올바르지 않습니다.'; end if;
  if p_give = '{}'::jsonb and p_give_gil = 0 and p_want = '{}'::jsonb and p_want_gil = 0 then raise exception '주거나 받을 것을 하나 이상 정하세요.'; end if;
  select * into a from public.world_characters where owner_id = uid;
  select * into b from public.world_characters where owner_id = p_to;
  if a.owner_id is null or b.owner_id is null or coalesce(b.is_dead, false) then raise exception '거래할 상대를 찾을 수 없습니다.'; end if;
  if coalesce(a.is_dead, false) or a.downed_at is not null or a.health <= 0 then raise exception '현재 상태에서는 거래할 수 없습니다.'; end if;
  if a.location is distinct from b.location then raise exception '같은 곳에 있는 조사원과만 거래할 수 있습니다.'; end if;
  r := public.world_field_region(a.location);
  if not coalesce(r.is_safe_zone, false) then raise exception '거래는 안전지대에서만 할 수 있습니다.'; end if;
  if (select count(*) from public.world_direct_trades where from_id = uid and status = 'pending' and expires_at > now()) >= 3 then
    raise exception '응답을 기다리는 거래 제안은 3건까지입니다.'; end if;
  perform public.world_trade_bundle_check(uid, a.inventory, p_give);
  if a.gil < p_give_gil then raise exception '전이 부족합니다.'; end if;
  insert into public.world_direct_trades(from_id, to_id, give_items, give_gil, want_items, want_gil, location)
  values (uid, p_to, p_give, p_give_gil, p_want, p_want_gil, a.location) returning trade_id into tid;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_to, 'trade_offer', '거래 제안', a.character_name || '님의 거래 제안 · 받을 것: ' || public.world_trade_bundle_text(p_give, p_give_gil)
      || ' · 줄 것: ' || public.world_trade_bundle_text(p_want, p_want_gil),
    jsonb_build_object('trade_id', tid, 'from_id', uid, 'from_name', a.character_name));
  return jsonb_build_object('ok', true, 'trade_id', tid, 'content', b.character_name || '님에게 거래를 제안했습니다. 30분 안에 응답이 없으면 사라집니다.');
end $$;

create or replace function public.world_trade_direct_respond(p_trade_id uuid, p_accept boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); t public.world_direct_trades%rowtype; a public.world_characters%rowtype; b public.world_characters%rowtype;
  r public.world_map_regions%rowtype; ainv jsonb; binv jsonb; tax_a bigint; tax_b bigint; msg text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into t from public.world_direct_trades where trade_id = p_trade_id for update;
  if t.trade_id is null or t.to_id <> uid then raise exception '거래 제안을 찾을 수 없습니다.'; end if;
  if t.status <> 'pending' or t.expires_at <= now() then raise exception '이미 끝났거나 시간이 지난 거래 제안입니다.'; end if;
  update public.world_notifications set read_at = coalesce(read_at, now()) where user_id = uid and kind = 'trade_offer' and payload ->> 'trade_id' = t.trade_id::text;
  if not p_accept then
    update public.world_direct_trades set status = 'declined', responded_at = now() where trade_id = t.trade_id;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    select t.from_id, 'trade_result', '거래 거절', c.character_name || '님이 거래 제안을 거절했습니다.', jsonb_build_object('trade_id', t.trade_id)
      from public.world_characters c where c.owner_id = uid;
    return jsonb_build_object('ok', true, 'content', '거래 제안을 거절했습니다.');
  end if;
  -- 두 캐릭터를 언제나 같은 순서로 잠가 교착을 피한다
  if t.from_id < t.to_id then
    select * into a from public.world_characters where owner_id = t.from_id for update;
    select * into b from public.world_characters where owner_id = t.to_id for update;
  else
    select * into b from public.world_characters where owner_id = t.to_id for update;
    select * into a from public.world_characters where owner_id = t.from_id for update;
  end if;
  if a.owner_id is null or b.owner_id is null or coalesce(a.is_dead, false) or coalesce(b.is_dead, false) then raise exception '거래할 수 없는 상대입니다.'; end if;
  if b.downed_at is not null or b.health <= 0 then raise exception '현재 상태에서는 거래할 수 없습니다.'; end if;
  if a.location is distinct from b.location or a.location is distinct from t.location then raise exception '두 사람이 제안한 곳에 함께 있어야 거래할 수 있습니다.'; end if;
  r := public.world_field_region(a.location);
  if not coalesce(r.is_safe_zone, false) then raise exception '거래는 안전지대에서만 할 수 있습니다.'; end if;
  perform public.world_trade_bundle_check(a.owner_id, a.inventory, t.give_items);
  perform public.world_trade_bundle_check(b.owner_id, b.inventory, t.want_items);
  if a.gil < t.give_gil then raise exception '제안한 사람의 전이 부족해 거래할 수 없습니다.'; end if;
  if b.gil < t.want_gil then raise exception '전이 부족합니다.'; end if;
  ainv := public.world_inv_apply(public.world_inv_apply(a.inventory, t.give_items, -1), t.want_items, 1);
  binv := public.world_inv_apply(public.world_inv_apply(b.inventory, t.want_items, -1), t.give_items, 1);
  -- 가방 한도(world_bag_limit와 같은 계산: 기본 칸 + 수향연맹 20)
  if public.world_inv_count(ainv) > greatest(a.bag_capacity + case when a.major_faction_id = 'river_alliance' then 20 else 0 end, public.world_inv_count(a.inventory)) then
    raise exception '제안한 사람의 가방이 가득 차 거래할 수 없습니다.'; end if;
  if public.world_inv_count(binv) > greatest(b.bag_capacity + case when b.major_faction_id = 'river_alliance' then 20 else 0 end, public.world_inv_count(b.inventory)) then
    raise exception '가방이 가득 차 거래할 수 없습니다. 물품을 정리한 뒤 다시 시도하세요.'; end if;
  -- 전을 건네면 거래소와 같은 5% 거래세를 받는 쪽에서 뗀다
  tax_a := case when t.want_gil > 0 then greatest(1, round(t.want_gil * 0.05)::bigint) else 0 end;
  tax_b := case when t.give_gil > 0 then greatest(1, round(t.give_gil * 0.05)::bigint) else 0 end;
  update public.world_characters set inventory = ainv, gil = gil - t.give_gil + t.want_gil - tax_a, updated_at = now() where owner_id = a.owner_id;
  update public.world_characters set inventory = binv, gil = gil - t.want_gil + t.give_gil - tax_b, updated_at = now() where owner_id = b.owner_id;
  update public.world_direct_trades set status = 'accepted', responded_at = now() where trade_id = t.trade_id;
  if tax_a + tax_b > 0 then
    insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
    select x.o, 'direct_trade_tax', -x.tax, true, jsonb_build_object('trade_id', t.trade_id)
      from (values (a.owner_id, tax_a), (b.owner_id, tax_b)) x(o, tax) where x.tax > 0;
  end if;
  msg := a.character_name || '·' || b.character_name || ' 거래 성사';
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (b.owner_id, b.character_name, 'trade', msg, jsonb_build_object('trade_id', t.trade_id, 'with', a.owner_id));
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (a.owner_id, 'trade_result', '거래 성사', b.character_name || '님이 거래를 받아들였습니다. 받은 것: ' || public.world_trade_bundle_text(t.want_items, t.want_gil - tax_a),
    jsonb_build_object('trade_id', t.trade_id));
  return jsonb_build_object('ok', true, 'content', '거래했습니다. 받은 것: ' || public.world_trade_bundle_text(t.give_items, t.give_gil - tax_b));
end $$;

create or replace function public.world_trade_direct_cancel(p_trade_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); t public.world_direct_trades%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into t from public.world_direct_trades where trade_id = p_trade_id for update;
  if t.trade_id is null or t.from_id <> uid or t.status <> 'pending' then raise exception '취소할 수 있는 거래 제안이 없습니다.'; end if;
  update public.world_direct_trades set status = 'cancelled', responded_at = now() where trade_id = t.trade_id;
  update public.world_notifications set read_at = coalesce(read_at, now()) where user_id = t.to_id and kind = 'trade_offer' and payload ->> 'trade_id' = t.trade_id::text;
  return jsonb_build_object('ok', true, 'content', '거래 제안을 거두었습니다.');
end $$;

-- 화면용: 나와 관련된 응답 대기 거래 제안(이름 포함)
create or replace function public.world_trade_direct_snapshot() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('trade_id', t.trade_id, 'incoming', t.to_id = uid,
      'other_id', case when t.to_id = uid then t.from_id else t.to_id end,
      'other_name', case when t.to_id = uid then fa.character_name else ta.character_name end,
      'give_items', t.give_items, 'give_gil', t.give_gil, 'want_items', t.want_items, 'want_gil', t.want_gil,
      'location', t.location, 'created_at', t.created_at, 'expires_at', t.expires_at) order by t.created_at desc)
    from public.world_direct_trades t
    join public.world_characters fa on fa.owner_id = t.from_id join public.world_characters ta on ta.owner_id = t.to_id
    where uid in (t.from_id, t.to_id) and t.status = 'pending' and t.expires_at > now()), '[]'::jsonb);
end $$;

-- 새 RPC: 소유자 fn_owner_field, 로그인 사용자만 실행
do $$ declare f text; begin
  foreach f in array array['public.world_item_lock(text,boolean)', 'public.world_item_discard(text,integer)',
    'public.world_trade_direct_offer(uuid,jsonb,bigint,jsonb,bigint)', 'public.world_trade_direct_respond(uuid,boolean)',
    'public.world_trade_direct_cancel(uuid)', 'public.world_trade_direct_snapshot()'] loop
    execute format('alter function %s owner to fn_owner_field', f);
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
grant select (id, user_id, kind, payload, read_at), update (read_at) on public.world_notifications to fn_owner_field;

-- 소유자 권한 물려받기를 원래대로 끈다
grant fn_owner_18538, fn_owner_18878, fn_owner_18879, fn_owner_19111 to postgres with inherit false;

select 'ok' as result,
  (select string_agg(x || '=' || pg_has_role('postgres', x, 'usage')::text, ',') from unnest(array['fn_owner_18538','fn_owner_18878','fn_owner_18879','fn_owner_19111']) x) as inherit_should_be_false;
