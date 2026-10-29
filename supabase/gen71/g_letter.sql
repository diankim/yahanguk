
-- ─────────────────────────────────────────────────────────────
-- G. 의뢰 보상 상향 · 서신(친구 우편) · 원정 일지의 현대풍 문구
-- ─────────────────────────────────────────────────────────────

-- G-1. 상시 의뢰 전 보상: 6.0.0의 ×0.4를 거두고 기본값을 올린다(하루 세 가지 합 Lv10 약 900전·Lv30 약 2,000전)
create or replace function public.world_commission_gil_v6() returns trigger
language plpgsql set search_path to 'pg_catalog', 'public' as $$
begin
  new.reward_gil := round(coalesce(new.reward_gil, 0));   -- 7.1.0: 깎지 않는다(이름은 트리거가 걸려 있어 그대로 둔다)
  return new;
end $$;
select pg_temp.yh_patch('public.world_commission_board()', '3, 50 + c.level * 8, 30 + c.level * 5);', '3, 150 + c.level * 24, 30 + c.level * 5);');
select pg_temp.yh_patch('public.world_commission_board()', 'n, 38 + c.level * 5, 25 + c.level * 4', 'n, 110 + c.level * 18, 25 + c.level * 4');
select pg_temp.yh_patch('public.world_commission_board()', 'it, q, round(price * q * 1.75)::int, 20 + c.level * 3);', 'it, q, round(price * q * 1.6)::int + 60 + c.level * 10, 20 + c.level * 3);');
-- 오늘 이미 받은 게시판(아직 보상을 안 받은 것)도 새 값으로: 경험치에서 그날 레벨을 되짚는다
update public.world_commissions m set reward_gil = case m.kind
    when 'hunt' then 150 + ((m.reward_xp - 30) / 5) * 24
    when 'deliver' then round(coalesce((select reference_price from public.world_item_catalog i where i.item_id = m.target_item), 20) * m.need * 1.6)::int + 60 + ((m.reward_xp - 20) / 3) * 10
    else 110 + ((m.reward_xp - 25) / 4) * 18 end
 where m.day = (now() at time zone 'Asia/Seoul')::date and m.claimed_at is null;

-- G-2. 원정 일지에서 무협·퇴마 세계에 어울리지 않는 현대풍 문구
select pg_temp.yh_patch('public.world_expedition_walk_lines(uuid)', '신발 끈을 고쳐 묶고 다시 걷습니다.', '짚신 감발을 고쳐 매고 다시 걷습니다.');
select pg_temp.yh_patch('public.world_expedition_walk_lines(uuid)', '가방 속 보급품을 하나하나 세어 봅니다.', '봇짐 속 보급품을 하나하나 세어 봅니다.');
select pg_temp.yh_patch('public.world_expedition_walk_lines(uuid)', '갈림길마다 분필로 표시를 남깁니다.', '갈림길마다 숯으로 표시를 남깁니다.');
select pg_temp.yh_patch('public.world_expedition_walk_lines(uuid)', '작은 상처를 소독하고 붕대를 고쳐 맵니다.', '작은 상처를 술로 씻고 무명 천을 고쳐 맵니다.');
select pg_temp.yh_patch('public.world_expedition_walk_lines(uuid)', '쓸 만한 부품을 주워 주머니에 넣습니다.', '쓸 만한 쇳조각을 주워 쌈지에 넣습니다.');
select pg_temp.yh_patch('public.world_expedition_walk_lines(uuid)', '이상한 광택의 금속 조각을 수첩에 그려 둡니다.', '이상한 광택의 금속 조각을 기록첩에 그려 둡니다.');

-- G-3. 서신: 친구에게 보내는 우편
--   하루 10통 보냄 · 물품 5가지(가지마다 999개까지, 거래 가능한 것만) · 받은 서신함 10통(고정 5통까지)
--   새로 받아 10통을 넘으면 고정하지 않은 가장 오래된 서신부터 지운다 · 고정하지 않은 서신은 받은 지 3일 뒤 지운다
--   지워지는 서신에 아직 안 받은 물품이 있으면 받는 사람의 개인 창고로 넣는다(창고 칸을 넘어도 넣는다 — 물품을 잃지 않게)
--   물품을 붙여 보내기·받기는 안전지대에서(반요촌 제외), 글만 보내기는 어디서나
create table if not exists public.world_letters (
  id bigserial primary key,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete set null,
  sender_name text not null,
  title text not null,
  body text not null default '',
  items jsonb not null default '{}'::jsonb,
  pinned boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  claimed_at timestamptz
);
create index if not exists world_letters_box on public.world_letters(recipient_id, created_at);
create index if not exists world_letters_old on public.world_letters(created_at) where not pinned;
create table if not exists public.world_letter_sends (
  owner_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  n int not null default 0,
  primary key (owner_id, day)
);
alter table public.world_letters enable row level security;
alter table public.world_letter_sends enable row level security;
revoke all on public.world_letters, public.world_letter_sends from anon, authenticated;
revoke all on sequence public.world_letters_id_seq from anon, authenticated;

create or replace function public.world_letter_limits() returns jsonb
language sql immutable set search_path to 'pg_catalog' as $$
  select '{"per_day": 10, "kinds": 5, "box": 10, "pins": 5, "days": 3, "title": 24, "body": 400}'::jsonb
$$;

-- 물품을 오가게 할 때의 자리 조건(창고와 같은 조건, 서신 문구)
create or replace function public.world_letter_place_check(p_uid uuid) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if coalesce(c.is_dead, false) then raise exception '사망한 캐릭터는 서신 물품을 주고받을 수 없습니다.'; end if;
  if c.downed_at is not null then raise exception '전투불능 상태에서는 서신 물품을 주고받을 수 없습니다.'; end if;
  if c.travel_arrives_at is not null then raise exception '이동 중에는 서신 물품을 주고받을 수 없습니다.'; end if;
  if not exists (select 1 from public.world_current_shop(p_uid)) then raise exception '물품이 든 서신은 안전지대의 역참에서 부치고 받습니다.'; end if;
  if public.world_banyo_here(p_uid) then raise exception '반요촌에는 역참이 없습니다. 바깥 안전지대에서 부치고 받으세요.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then raise exception '원정 중에는 서신 물품을 주고받을 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities a where a.owner_id = p_uid and a.status = 'active') then raise exception '자율 활동 중에는 서신 물품을 주고받을 수 없습니다.'; end if;
end $$;

-- 지워질 서신의 안 받은 물품을 개인 창고로
create or replace function public.world_letter_spill(p_uid uuid, p_items jsonb) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if p_items is null or p_items = '{}'::jsonb then return; end if;
  insert into public.world_storage(owner_id, items) values (p_uid, p_items)
  on conflict (owner_id) do update set items = (select coalesce(jsonb_object_agg(x.key, x.v), '{}'::jsonb) from (
      select key, sum(value::int) v from (select * from jsonb_each_text(public.world_storage.items) union all select * from jsonb_each_text(excluded.items)) u group by key) x),
    updated_at = now();
end $$;

-- 한 사람의 서신함 정리: 기한 지난 것·10통 넘친 것(고정 빼고, 오래된 것부터)
create or replace function public.world_letter_prune(p_uid uuid) returns int
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare r record; n int := 0; spilled jsonb := '{}'::jsonb;
begin
  for r in
    select l.id, l.items, l.claimed_at from public.world_letters l
     where l.recipient_id = p_uid and not l.pinned
       and (l.created_at < now() - interval '3 days'
            or l.id in (select x.id from public.world_letters x where x.recipient_id = p_uid and not x.pinned
                         order by x.created_at desc, x.id desc
                         offset greatest(0, 10 - (select count(*) from public.world_letters y where y.recipient_id = p_uid and y.pinned))))
  loop
    if r.claimed_at is null and r.items <> '{}'::jsonb then
      perform public.world_letter_spill(p_uid, r.items);
      spilled := spilled || r.items;
    end if;
    delete from public.world_letters where id = r.id;
    n := n + 1;
  end loop;
  if spilled <> '{}'::jsonb then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_uid, 'letter', '서신 물품을 창고로', '지워진 서신에 받지 않은 물품이 있어 개인 창고에 넣었습니다.', jsonb_build_object('storage', spilled));
  end if;
  return n;
end $$;

create or replace function public.world_letter_send(p_to uuid, p_title text, p_body text, p_items jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; tnm text; today date := (now() at time zone 'Asia/Seoul')::date;
  t text := btrim(coalesce(p_title, '')); b text := btrim(coalesce(p_body, '')); items jsonb := coalesce(p_items, '{}'::jsonb);
  inv jsonb; k text; q int; sent int; lid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_to is null or p_to = uid then raise exception '받을 사람을 고르세요.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select character_name into tnm from public.world_characters where owner_id = p_to;
  if tnm is null then raise exception '받을 조사원을 찾을 수 없습니다.'; end if;
  if not exists (select 1 from public.world_friends f where f.status = 'accepted' and ((f.owner_id = uid and f.friend_id = p_to) or (f.owner_id = p_to and f.friend_id = uid))) then
    raise exception '서신은 친구에게만 보낼 수 있습니다.'; end if;
  if exists (select 1 from public.world_blocks k2 where (k2.owner_id = uid and k2.blocked_id = p_to) or (k2.owner_id = p_to and k2.blocked_id = uid)) then
    raise exception '서신을 보낼 수 없는 상대입니다.'; end if;
  if t = '' then raise exception '제목을 적으세요.'; end if;
  if char_length(t) > 24 then raise exception '제목은 24자까지입니다.'; end if;
  if char_length(b) > 400 then raise exception '본문은 400자까지입니다.'; end if;
  if jsonb_typeof(items) <> 'object' then raise exception '물품 형식이 올바르지 않습니다.'; end if;
  if (select count(*) from jsonb_object_keys(items)) > 5 then raise exception '물품은 다섯 가지까지 붙일 수 있습니다.'; end if;
  select coalesce(max(n), 0) into sent from public.world_letter_sends where owner_id = uid and day = today;
  if sent >= 10 then raise exception '서신은 하루 10통까지 보낼 수 있습니다. 내일 다시 보내세요.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  if items <> '{}'::jsonb then
    perform public.world_letter_place_check(uid);
    perform public.world_trade_bundle_check(uid, inv, items);
    for k, q in select key, value::text::numeric::int from jsonb_each(items) loop
      if (select category from public.world_item_catalog where item_id = k) = 'quest' then raise exception '임무 물품은 서신에 붙일 수 없습니다.'; end if;
      if exists (select 1 from public.world_gear_enhance g where g.owner_id = uid and g.item_id = k) and coalesce((inv ->> k)::int, 0) - q < 1 then
        raise exception '강화한 장비의 마지막 하나는 서신에 붙일 수 없습니다.'; end if;
      inv := public.world_inv_add(inv, k, -q);
    end loop;
    update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  end if;
  insert into public.world_letter_sends(owner_id, day, n) values (uid, today, 1)
  on conflict (owner_id, day) do update set n = public.world_letter_sends.n + 1;
  insert into public.world_letters(recipient_id, sender_id, sender_name, title, body, items)
  values (p_to, uid, c.character_name, t, b, items) returning id into lid;
  perform public.world_letter_prune(p_to);
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_to, 'letter', '서신이 왔습니다', public.world_josa(c.character_name, '이', '가') || ' 서신 「' || t || '」' || substr(public.world_josa(t, '을', '를'), char_length(t) + 1) || ' 보냈습니다.' ||
            case when items <> '{}'::jsonb then ' 물품이 함께 왔습니다.' else '' end,
          jsonb_build_object('letter_id', lid, 'from', uid));
  return jsonb_build_object('ok', true, 'sent_today', sent + 1,
    'content', public.world_josa(tnm, '에게', '에게') || ' 서신을 부쳤습니다. (오늘 ' || (sent + 1) || '/10통)');
end $$;

create or replace function public.world_letter_box() returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); today date := (now() at time zone 'Asia/Seoul')::date;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if exists (select 1 from public.world_letters where recipient_id = uid and not pinned and created_at < now() - interval '3 days') then
    perform public.world_letter_prune(uid);
  end if;
  return jsonb_build_object('limits', public.world_letter_limits(),
    'sent_today', coalesce((select n from public.world_letter_sends where owner_id = uid and day = today), 0),
    'letters', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'from', l.sender_id, 'from_name', l.sender_name, 'title', l.title, 'body', l.body,
        'items', l.items, 'pinned', l.pinned, 'created_at', l.created_at, 'expires_at', case when l.pinned then null else l.created_at + interval '3 days' end,
        'read', l.read_at is not null, 'claimed', l.claimed_at is not null) order by l.pinned desc, l.created_at desc, l.id desc), '[]'::jsonb)
      from public.world_letters l where l.recipient_id = uid));
end $$;

create or replace function public.world_letter_unread() returns int
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select count(*)::int from public.world_letters where recipient_id = public.fn_owner_auth_uid() and read_at is null
$$;

-- 읽음·고정·지우기 (p_op: read | pin | unpin | delete)
create or replace function public.world_letter_mark(p_id bigint, p_op text) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); l public.world_letters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into l from public.world_letters where id = p_id and recipient_id = uid for update;
  if not found then raise exception '서신을 찾을 수 없습니다. 기한이 지나 지워졌을 수 있습니다.'; end if;
  if p_op = 'read' then
    update public.world_letters set read_at = coalesce(read_at, now()) where id = p_id;
    return jsonb_build_object('ok', true);
  elsif p_op = 'pin' then
    if not l.pinned and (select count(*) from public.world_letters where recipient_id = uid and pinned) >= 5 then
      raise exception '서신은 다섯 통까지 고정할 수 있습니다.'; end if;
    update public.world_letters set pinned = true, read_at = coalesce(read_at, now()) where id = p_id;
    return jsonb_build_object('ok', true, 'content', '서신을 고정했습니다. 기한이 지나도 지워지지 않습니다.');
  elsif p_op = 'unpin' then
    update public.world_letters set pinned = false where id = p_id;
    perform public.world_letter_prune(uid);
    return jsonb_build_object('ok', true, 'content', '고정을 풀었습니다. 받은 지 3일이 지나면 지워집니다.');
  elsif p_op = 'delete' then
    if l.claimed_at is null and l.items <> '{}'::jsonb then raise exception '물품을 먼저 받으세요.'; end if;
    delete from public.world_letters where id = p_id;
    return jsonb_build_object('ok', true, 'content', '서신을 지웠습니다.');
  end if;
  raise exception '알 수 없는 요청입니다.';
end $$;

create or replace function public.world_letter_claim(p_id bigint) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; l public.world_letters%rowtype; inv jsonb; k text; q int; lim int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select * into l from public.world_letters where id = p_id and recipient_id = uid for update;
  if not found then raise exception '서신을 찾을 수 없습니다.'; end if;
  if l.claimed_at is not null or l.items = '{}'::jsonb then raise exception '받을 물품이 없습니다.'; end if;
  perform public.world_letter_place_check(uid);
  inv := coalesce(c.inventory, '{}'::jsonb);
  for k, q in select key, value::text::numeric::int from jsonb_each(l.items) loop
    inv := public.world_inv_add(inv, k, q);
  end loop;
  lim := public.world_bag_limit(uid);
  if public.world_bag_count(inv) > lim then
    raise exception '가방 자리가 모자랍니다. (% / %칸) 자리를 비우고 받으세요.', public.world_bag_count(inv), lim; end if;
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  update public.world_letters set claimed_at = now(), read_at = coalesce(read_at, now()) where id = p_id;
  return jsonb_build_object('ok', true, 'changed', true, 'content', '서신의 물품을 받았습니다.');
end $$;

-- 매일 정리: 기한 지난 서신(물품은 창고로)과 지난 보낸 수
select pg_temp.yh_patch('public.world_housekeeping()', 'get diagnostics t = row_count;',
  'get diagnostics t = row_count;
  perform public.world_letter_prune(x.recipient_id) from (select distinct recipient_id from public.world_letters where not pinned and created_at < now() - interval ''3 days'') x;
  delete from public.world_letter_sends where day < (now() at time zone ''Asia/Seoul'')::date - 2;');

-- 알림 갈래 「서신」
select pg_temp.yh_patch('public.world_notify_group(text)', 'when p_kind in (''circle_invite'') then ''circle''',
  'when p_kind in (''circle_invite'') then ''circle''
    when p_kind in (''letter'') then ''letter''');
select pg_temp.yh_patch('public.world_notify_prefs_set(text[])', '''bond'', ''faction''', '''bond'', ''letter'', ''faction''');

do $$ declare fn text; begin
  foreach fn in array array['world_letter_place_check(uuid)', 'world_letter_spill(uuid,jsonb)', 'world_letter_prune(uuid)', 'world_letter_send(uuid,text,text,jsonb)',
    'world_letter_box()', 'world_letter_unread()', 'world_letter_mark(bigint,text)', 'world_letter_claim(bigint)'] loop
    execute format('alter function public.%s owner to fn_owner_field', fn);
  end loop;
end $$;
grant select, insert, update, delete on public.world_letters, public.world_letter_sends to fn_owner_field;
grant usage on sequence public.world_letters_id_seq to fn_owner_field;
revoke all on function public.world_letter_limits() from public, anon;
grant execute on function public.world_letter_limits() to fn_owner_field, authenticated;
do $$ begin
  set role fn_owner_field;
  revoke all on function public.world_letter_place_check(uuid), public.world_letter_spill(uuid, jsonb), public.world_letter_prune(uuid) from public, anon, authenticated;
  grant execute on function public.world_letter_prune(uuid) to postgres;   -- world_housekeeping(주인 postgres)이 부른다
  revoke all on function public.world_letter_send(uuid, text, text, jsonb), public.world_letter_box(), public.world_letter_unread(),
    public.world_letter_mark(bigint, text), public.world_letter_claim(bigint) from public, anon;
  grant execute on function public.world_letter_send(uuid, text, text, jsonb), public.world_letter_box(), public.world_letter_unread(),
    public.world_letter_mark(bigint, text), public.world_letter_claim(bigint) to authenticated;
  reset role;
end $$;
