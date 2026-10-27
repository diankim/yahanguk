-- 연리(連理): 조사원끼리 맺는 연인 관계. 상대는 「정인(情人)」이라 부른다.
-- - 정표: 가방과 별개(world_bonds.token_key). 맺을 때 마음을 전하는 쪽이 정표를 고르고 짓는 값 300전을 낸다(거절·취소·기한 지남이면 돌려준다).
--   맺으면 둘 다 같은 정표를 받아 「정표 칸」에 착용하거나 벗을 수 있다. 둘 다 착용하고 같은 곳·같은 파티이면 「연리의 기운」(회복량 +5%, 침식 -5%).
-- - 맺는 조건: 서로 친구, 둘 다 Lv.5 이상, 둘 다 정인이 없고, 헤어진 지 3일이 지났고, 차단 관계가 아니다. 요청은 24시간 유효, 한 번에 하나만 보낸다.
-- - 파기: 한쪽이 언제든 정표를 파기하면 연리가 끝난다. 다른 쪽에는 「상대가 파기한 정표」가 남고(직접 정리할 때까지) 알림이 간다.
--   차단하면 자동으로 파기된다. 끝난 뒤 둘 다 3일 동안 새 연리를 맺을 수 없다.
-- - 인연도: 정인과 같은 파티로 함께 토벌(+1)·안부 귓속말(하루 1번 +3)·선물(+5)·정인 구조(+10). 하루 30까지.
--   단계: 정을 나눔(0) · 마음이 이어짐(100) · 연리(300) · 백년해로(700). 단계마다 꾸미기(연리 무늬·연리 테두리·낙관 「緣」)를 둘 다 받는다.
-- - 선물: 하루 1번, 거래 가능한 물품(잠그지 않은 것, 장착 중인 마지막 한 개 제외)이나 전을 정인에게 보낸다. 받는 쪽 가방이 넘치면 보내지 않는다.
-- - 구조: 정인을 구조하면 체력 50으로 일으킨다(보통 30).
-- - 기념일(7·30·100·365일)에 둘 다 알림을 받는다.
-- - 함께: 토벌 기록 사이 간격 검사(world_guard_repeat_farming)를 2초에서 1초로(전투 행동 간격과 같게).
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

/* ── 1) 표 ─────────────────────────────────────────────── */
create table if not exists public.world_bonds (
  bond_id uuid primary key default gen_random_uuid(),
  a_id uuid not null references auth.users(id) on delete cascade,
  b_id uuid not null references auth.users(id) on delete cascade,
  token_key text not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  ended_by uuid,
  affinity int not null default 0,
  gain_day date,
  gain_today int not null default 0,
  a_wear boolean not null default true,
  b_wear boolean not null default true,
  a_hide boolean not null default false,
  b_hide boolean not null default false,
  a_greet_day date,
  b_greet_day date,
  a_gift_day date,
  b_gift_day date,
  a_cleared boolean not null default false,
  b_cleared boolean not null default false,
  marks jsonb not null default '{}'::jsonb,
  check (a_id <> b_id)
);
create index if not exists world_bonds_a on public.world_bonds(a_id) where ended_at is null;
create index if not exists world_bonds_b on public.world_bonds(b_id) where ended_at is null;

create table if not exists public.world_bond_requests (
  request_id uuid primary key default gen_random_uuid(),
  from_id uuid not null references auth.users(id) on delete cascade,
  to_id uuid not null references auth.users(id) on delete cascade,
  token_key text not null,
  message text not null default '',
  cost int not null default 300,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'canceled', 'expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);
create index if not exists world_bond_requests_to on public.world_bond_requests(to_id) where status = 'pending';
create index if not exists world_bond_requests_from on public.world_bond_requests(from_id) where status = 'pending';

alter table public.world_bonds enable row level security;
alter table public.world_bond_requests enable row level security;
revoke all on public.world_bonds, public.world_bond_requests from anon, authenticated;
grant select, insert, update on public.world_bonds, public.world_bond_requests to fn_owner_field;
grant select, insert on public.world_notifications to fn_owner_field;
grant select on public.world_friends, public.world_blocks, public.world_party_members, public.world_item_locks, public.world_character_equipment to fn_owner_field;
grant select, insert on public.world_character_cosmetics to fn_owner_field;
do $$ declare q text := pg_get_serial_sequence('public.world_notifications', 'id'); begin if q is not null then execute format('grant usage on sequence %s to fn_owner_field', q); end if; end $$;

/* ── 2) 도움 함수 ─────────────────────────────────────── */
-- 정표 종류(이름은 화면과 같게)
create or replace function public.world_bond_token_name(p_key text)
returns text language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select case p_key when 'knot' then '연리 매듭' when 'jade' then '반쪽 옥패' when 'heart' then '동심결' when 'ring' then '쌍가락지'
    when 'duck' then '원앙 노리개' when 'mirror' then '달 거울 조각' end
$$;
create or replace function public.world_bond_day() returns date language sql stable set search_path to 'pg_catalog', 'public' as $$ select (now() at time zone 'Asia/Seoul')::date $$;
create or replace function public.world_bond_stage(p_aff int) returns int language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select case when p_aff >= 700 then 4 when p_aff >= 300 then 3 when p_aff >= 100 then 2 else 1 end
$$;
create or replace function public.world_bond_stage_name(p_stage int) returns text language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select case p_stage when 4 then '백년해로' when 3 then '연리' when 2 then '마음이 이어짐' else '정을 나눔' end
$$;
-- 지금 맺은 연리(없으면 null)
create or replace function public.world_bond_active(p_owner uuid)
returns public.world_bonds language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select * from public.world_bonds where ended_at is null and (a_id = p_owner or b_id = p_owner) limit 1
$$;
create or replace function public.world_bond_partner(p_owner uuid)
returns uuid language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when a_id = p_owner then b_id else a_id end from public.world_bonds where ended_at is null and (a_id = p_owner or b_id = p_owner) limit 1
$$;
-- 연리의 기운: 둘 다 정표를 착용하고, 같은 곳·같은 파티에 있을 때
create or replace function public.world_bond_together(p_owner uuid)
returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select exists (
    select 1 from public.world_bonds b
      join public.world_characters me on me.owner_id = p_owner
      join public.world_characters pc on pc.owner_id = case when b.a_id = p_owner then b.b_id else b.a_id end
      join public.world_party_members pm on pm.owner_id = me.owner_id
      join public.world_party_members pp on pp.owner_id = pc.owner_id and pp.party_id = pm.party_id
     where b.ended_at is null and (b.a_id = p_owner or b.b_id = p_owner) and b.a_wear and b.b_wear
       and me.location = pc.location and coalesce(pc.health, 0) > 0 and pc.downed_at is null)
$$;
create or replace function public.world_bond_bonus(p_owner uuid, p_key text)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when p_owner is null or p_key not in ('healing_pct', 'erosion_pct') then 0
              when not public.world_bond_together(p_owner) then 0
              when p_key = 'healing_pct' then 5 else -5 end::numeric
$$;
create or replace function public.world_bond_self(p_key text)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select public.world_bond_bonus(public.fn_owner_auth_uid(), p_key)
$$;
-- 상태 효과 합계에 연리의 기운을 더한다(상태이상 + 날씨·시간대 + 장비 + 연리)
create or replace function public.world_status_effect_total(p_effect_key text)
returns numeric language sql stable set search_path to 'pg_catalog', 'public' as $$
 select coalesce(sum(
   case when (cat.effects->>p_effect_key) ~ '^-?[0-9]+(\.[0-9]+)?$'
     then (cat.effects->>p_effect_key)::numeric * cs.potency
     else 0 end
 ),0) + public.world_env_total(public.fn_owner_auth_uid(), p_effect_key) + public.world_gear_self(p_effect_key) + public.world_bond_self(p_effect_key)
 from public.world_character_statuses cs
 join public.world_status_catalog cat using(status_key)
 where cs.owner_id=public.fn_owner_auth_uid() and cs.expires_at>now()
$$;

-- 알림 하나
create or replace function public.world_bond_note(p_user uuid, p_kind text, p_title text, p_content text, p_payload jsonb default '{}'::jsonb)
returns void language sql security definer set search_path to 'pg_catalog', 'public' as $$
  insert into public.world_notifications(user_id, kind, title, content, payload) values (p_user, p_kind, p_title, p_content, coalesce(p_payload, '{}'::jsonb))
$$;

-- 인연도 올리기(하루 30까지). 단계가 오르면 둘 다 꾸미기를 받고 알림을 받는다.
create or replace function public.world_bond_gain(p_bond uuid, p_amount int, p_reason text)
returns int language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare b public.world_bonds%rowtype; today date := public.world_bond_day(); room int; add int; s0 int; s1 int; ck text;
begin
  select * into b from public.world_bonds where bond_id = p_bond and ended_at is null for update;
  if not found or p_amount <= 0 then return 0; end if;
  if b.gain_day is distinct from today then b.gain_today := 0; end if;
  room := greatest(0, 30 - b.gain_today); add := least(room, p_amount);
  if add <= 0 then return 0; end if;
  s0 := public.world_bond_stage(b.affinity); s1 := public.world_bond_stage(b.affinity + add);
  update public.world_bonds set affinity = affinity + add, gain_day = today, gain_today = b.gain_today + add where bond_id = p_bond;
  if s1 > s0 then
    ck := case s1 when 2 then 'pt_yeonri' when 3 then 'fr_yeonri' when 4 then 'sl_yeon' end;
    insert into public.world_character_cosmetics(owner_id, cosmetic_key) values (b.a_id, ck), (b.b_id, ck) on conflict do nothing;
    perform public.world_bond_note(b.a_id, 'bond_stage', '연리 · ' || public.world_bond_stage_name(s1), '정인과의 인연이 「' || public.world_bond_stage_name(s1) || '」에 이르렀습니다. 새 꾸미기를 받았습니다.', jsonb_build_object('stage', s1, 'cosmetic', ck));
    perform public.world_bond_note(b.b_id, 'bond_stage', '연리 · ' || public.world_bond_stage_name(s1), '정인과의 인연이 「' || public.world_bond_stage_name(s1) || '」에 이르렀습니다. 새 꾸미기를 받았습니다.', jsonb_build_object('stage', s1, 'cosmetic', ck));
  end if;
  return add;
end $$;

-- 기한이 지난 요청 정리(짓는 값 돌려주기)
create or replace function public.world_bond_expire()
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare r record;
begin
  for r in select * from public.world_bond_requests where status = 'pending' and expires_at <= now() for update skip locked loop
    update public.world_bond_requests set status = 'expired' where request_id = r.request_id;
    update public.world_characters set gil = gil + r.cost, updated_at = now() where owner_id = r.from_id;
  end loop;
end $$;

-- 맺을 수 있는지(못 하면 까닭)
create or replace function public.world_bond_block_reason(p_owner uuid, p_label text)
returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype; last_end timestamptz;
begin
  select * into c from public.world_characters where owner_id = p_owner;
  if not found then return p_label || '의 캐릭터가 없습니다.'; end if;
  if coalesce(c.is_dead, false) then return p_label || '은(는) 숨을 거두었습니다.'; end if;
  if coalesce(c.level, 1) < 5 then return p_label || '은(는) 아직 Lv.5가 되지 않았습니다.'; end if;
  if (public.world_bond_active(p_owner)).bond_id is not null then return p_label || '에게는 이미 정인이 있습니다.'; end if;
  select max(ended_at) into last_end from public.world_bonds where (a_id = p_owner or b_id = p_owner) and ended_at is not null;
  if last_end is not null and last_end > now() - interval '3 days' then
    return p_label || '은(는) 연리가 끝난 지 3일이 지나지 않았습니다(' || to_char((last_end + interval '3 days') at time zone 'Asia/Seoul', 'MM월 DD일 HH24시') || ' 이후).';
  end if;
  return null;
end $$;

/* ── 3) 조회 ───────────────────────────────────────────── */
create or replace function public.world_bond_snapshot()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); b public.world_bonds%rowtype; broken public.world_bonds%rowtype; side text; pid uuid; pc public.world_characters%rowtype;
  days int; d int; today date := public.world_bond_day(); res jsonb; last_end timestamptz;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_bond_expire();
  select * into b from public.world_bonds where ended_at is null and (a_id = uid or b_id = uid) limit 1;
  if b.bond_id is not null then
    side := case when b.a_id = uid then 'a' else 'b' end;
    pid := case when side = 'a' then b.b_id else b.a_id end;
    select * into pc from public.world_characters where owner_id = pid;
    days := greatest(0, (today - (b.started_at at time zone 'Asia/Seoul')::date))::int;
    -- 기념일 알림(한 번씩)
    foreach d in array array[7, 30, 100, 365] loop
      if days >= d and not (b.marks ? d::text) then
        update public.world_bonds set marks = marks || jsonb_build_object(d::text, now()) where bond_id = b.bond_id;
        perform public.world_bond_note(b.a_id, 'bond_anniv', '연리 ' || d || '일', '정인과 연리를 맺은 지 ' || d || '일이 되었습니다.', jsonb_build_object('days', d));
        perform public.world_bond_note(b.b_id, 'bond_anniv', '연리 ' || d || '일', '정인과 연리를 맺은 지 ' || d || '일이 되었습니다.', jsonb_build_object('days', d));
        b.marks := b.marks || jsonb_build_object(d::text, now());
      end if;
    end loop;
    res := jsonb_build_object('bond_id', b.bond_id, 'partner_id', pid, 'partner_name', pc.character_name, 'partner_level', pc.level, 'partner_location', pc.location,
      'token_key', b.token_key, 'token_name', public.world_bond_token_name(b.token_key), 'started_at', b.started_at, 'days', days,
      'affinity', b.affinity, 'stage', public.world_bond_stage(b.affinity), 'stage_name', public.world_bond_stage_name(public.world_bond_stage(b.affinity)),
      'next_at', case public.world_bond_stage(b.affinity) when 1 then 100 when 2 then 300 when 3 then 700 end,
      'gain_today', case when b.gain_day = today then b.gain_today else 0 end,
      'my_wear', case when side = 'a' then b.a_wear else b.b_wear end, 'partner_wear', case when side = 'a' then b.b_wear else b.a_wear end,
      'my_hide', case when side = 'a' then b.a_hide else b.b_hide end, 'partner_hide', case when side = 'a' then b.b_hide else b.a_hide end,
      'greeted_today', (case when side = 'a' then b.a_greet_day else b.b_greet_day end) = today,
      'gifted_today', (case when side = 'a' then b.a_gift_day else b.b_gift_day end) = today,
      'together', public.world_bond_together(uid));
  end if;
  -- 상대가 파기한 정표(직접 정리하기 전까지)
  select * into broken from public.world_bonds
   where ended_at is not null and ended_by is not null and ended_by <> uid and (a_id = uid or b_id = uid)
     and not (case when a_id = uid then a_cleared else b_cleared end)
   order by ended_at desc limit 1;
  select max(ended_at) into last_end from public.world_bonds where (a_id = uid or b_id = uid) and ended_at is not null;
  return jsonb_build_object(
    'bond', res,
    'broken', case when broken.bond_id is null then null else jsonb_build_object('bond_id', broken.bond_id, 'token_key', broken.token_key, 'token_name', public.world_bond_token_name(broken.token_key),
      'partner_name', (select character_name from public.world_characters where owner_id = broken.ended_by), 'ended_at', broken.ended_at,
      'days', greatest(0, ((broken.ended_at at time zone 'Asia/Seoul')::date - (broken.started_at at time zone 'Asia/Seoul')::date))::int) end,
    'cooldown_until', case when last_end > now() - interval '3 days' then last_end + interval '3 days' end,
    'incoming', coalesce((select jsonb_agg(jsonb_build_object('request_id', r.request_id, 'from_id', r.from_id, 'from_name', c.character_name, 'token_key', r.token_key,
        'token_name', public.world_bond_token_name(r.token_key), 'message', r.message, 'expires_at', r.expires_at) order by r.created_at desc)
      from public.world_bond_requests r left join public.world_characters c on c.owner_id = r.from_id where r.to_id = uid and r.status = 'pending'), '[]'::jsonb),
    'outgoing', (select jsonb_build_object('request_id', r.request_id, 'to_id', r.to_id, 'to_name', c.character_name, 'token_key', r.token_key, 'token_name', public.world_bond_token_name(r.token_key), 'expires_at', r.expires_at)
      from public.world_bond_requests r left join public.world_characters c on c.owner_id = r.to_id where r.from_id = uid and r.status = 'pending' limit 1));
end $$;

-- 다른 조사원 카드에 보일 연리(둘 중 하나라도 숨기면 보이지 않는다. 본인과 정인에게는 늘 보인다)
create or replace function public.world_bond_public(p_owner uuid)
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when b.bond_id is null then null
              when (b.a_hide or b.b_hide) and public.fn_owner_auth_uid() not in (b.a_id, b.b_id) then null
              else jsonb_build_object('partner_id', case when b.a_id = p_owner then b.b_id else b.a_id end,
                'partner_name', (select character_name from public.world_characters where owner_id = case when b.a_id = p_owner then b.b_id else b.a_id end),
                'token_key', b.token_key, 'token_name', public.world_bond_token_name(b.token_key),
                'wear', case when b.a_id = p_owner then b.a_wear else b.b_wear end,
                'stage_name', public.world_bond_stage_name(public.world_bond_stage(b.affinity)),
                'mine', public.fn_owner_auth_uid() in (b.a_id, b.b_id)) end
  from (select (public.world_bond_active(p_owner)).*) b
$$;

/* ── 4) 맺기 ───────────────────────────────────────────── */
create or replace function public.world_bond_propose(p_target uuid, p_token text, p_message text default '')
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); me public.world_characters%rowtype; t public.world_characters%rowtype; why text; rid uuid; msg text := left(btrim(coalesce(p_message, '')), 100);
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_target is null or p_target = uid then raise exception '연리를 맺을 수 없는 상대입니다.'; end if;
  if public.world_bond_token_name(p_token) is null then raise exception '정표를 골라 주세요.'; end if;
  -- 두 사람을 정해진 순서로 잠가 동시에 맺어지는 것을 막는다
  perform pg_advisory_xact_lock(hashtextextended(least(uid, p_target)::text, 7)); perform pg_advisory_xact_lock(hashtextextended(greatest(uid, p_target)::text, 7));
  perform public.world_bond_expire();
  select * into me from public.world_characters where owner_id = uid for update;
  select * into t from public.world_characters where owner_id = p_target;
  if t.owner_id is null then raise exception '연리를 맺을 수 없는 상대입니다.'; end if;
  if not exists (select 1 from public.world_friends f where f.status = 'accepted' and ((f.owner_id = uid and f.friend_id = p_target) or (f.owner_id = p_target and f.friend_id = uid))) then
    raise exception '친구인 조사원과만 연리를 맺을 수 있습니다.'; end if;
  if exists (select 1 from public.world_blocks b where (b.owner_id = uid and b.blocked_id = p_target) or (b.owner_id = p_target and b.blocked_id = uid)) then raise exception '연리를 맺을 수 없는 상대입니다.'; end if;
  why := public.world_bond_block_reason(uid, '나'); if why is not null then raise exception '%', why; end if;
  why := public.world_bond_block_reason(p_target, t.character_name); if why is not null then raise exception '%', why; end if;
  if exists (select 1 from public.world_bond_requests where from_id = uid and status = 'pending') then raise exception '이미 마음을 전한 사람이 있습니다. 답을 기다리거나 거두어 주세요.'; end if;
  if me.gil < 300 then raise exception '정표를 짓는 값 300전이 필요합니다.'; end if;
  update public.world_characters set gil = gil - 300, updated_at = now() where owner_id = uid;
  insert into public.world_bond_requests(from_id, to_id, token_key, message, cost) values (uid, p_target, p_token, msg, 300) returning request_id into rid;
  perform public.world_bond_note(p_target, 'bond_request', '연리 · 마음을 전해 왔습니다',
    me.character_name || '님이 「' || public.world_bond_token_name(p_token) || '」을(를) 건네며 연리를 청합니다.' || case when msg <> '' then ' “' || msg || '”' else '' end,
    jsonb_build_object('request_id', rid, 'from_id', uid, 'token_key', p_token));
  return jsonb_build_object('ok', true, 'content', t.character_name || '님에게 마음을 전했습니다. 24시간 안에 답이 없으면 정표 값 300전을 돌려받습니다.');
end $$;

create or replace function public.world_bond_respond(p_request uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); r public.world_bond_requests%rowtype; why text; fromname text; myname text; bid uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into r from public.world_bond_requests where request_id = p_request and to_id = uid;
  if not found then raise exception '사라진 요청입니다.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(least(r.from_id, uid)::text, 7)); perform pg_advisory_xact_lock(hashtextextended(greatest(r.from_id, uid)::text, 7));
  select * into r from public.world_bond_requests where request_id = p_request for update;
  if r.status <> 'pending' then raise exception '이미 답했거나 거두어진 요청입니다.'; end if;
  select character_name into fromname from public.world_characters where owner_id = r.from_id;
  select character_name into myname from public.world_characters where owner_id = uid;
  if r.expires_at <= now() or not p_accept then
    update public.world_bond_requests set status = case when r.expires_at <= now() then 'expired' else 'declined' end where request_id = p_request;
    update public.world_characters set gil = gil + r.cost, updated_at = now() where owner_id = r.from_id;
    if p_accept then raise exception '요청 기한(24시간)이 지났습니다.'; end if;
    perform public.world_bond_note(r.from_id, 'bond_declined', '연리 · 답', coalesce(myname, '상대') || '님이 정중히 마음을 돌려보냈습니다. 정표 값 300전을 돌려받았습니다.');
    return jsonb_build_object('ok', true, 'content', '마음을 돌려보냈습니다.');
  end if;
  if not exists (select 1 from public.world_friends f where f.status = 'accepted' and ((f.owner_id = uid and f.friend_id = r.from_id) or (f.owner_id = r.from_id and f.friend_id = uid))) then
    raise exception '친구인 조사원과만 연리를 맺을 수 있습니다.'; end if;
  if exists (select 1 from public.world_blocks b where (b.owner_id = uid and b.blocked_id = r.from_id) or (b.owner_id = r.from_id and b.blocked_id = uid)) then raise exception '연리를 맺을 수 없는 상대입니다.'; end if;
  why := public.world_bond_block_reason(uid, '나'); if why is not null then raise exception '%', why; end if;
  why := public.world_bond_block_reason(r.from_id, coalesce(fromname, '상대')); if why is not null then raise exception '%', why; end if;
  insert into public.world_bonds(a_id, b_id, token_key) values (least(uid, r.from_id), greatest(uid, r.from_id), r.token_key) returning bond_id into bid;
  update public.world_bond_requests set status = 'accepted' where request_id = p_request;
  -- 두 사람에게 온 다른 요청은 정리하고 값을 돌려준다
  with x as (update public.world_bond_requests set status = 'canceled' where status = 'pending' and (from_id in (uid, r.from_id) or to_id in (uid, r.from_id)) returning from_id, cost)
  update public.world_characters c set gil = c.gil + s.total from (select from_id, sum(cost) total from x group by from_id) s where c.owner_id = s.from_id;
  perform public.world_bond_note(r.from_id, 'bond_accepted', '연리를 맺었습니다', coalesce(myname, '상대') || '님이 마음을 받아 주었습니다. 이제 서로의 정인입니다.', jsonb_build_object('bond_id', bid));
  return jsonb_build_object('ok', true, 'bond_id', bid, 'content', coalesce(fromname, '상대') || '님과 연리를 맺었습니다. 이제 서로의 정인입니다.');
end $$;

create or replace function public.world_bond_cancel()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); r public.world_bond_requests%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into r from public.world_bond_requests where from_id = uid and status = 'pending' for update;
  if not found then raise exception '거둘 요청이 없습니다.'; end if;
  update public.world_bond_requests set status = 'canceled' where request_id = r.request_id;
  update public.world_characters set gil = gil + r.cost, updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'content', '마음을 거두었습니다. 정표 값 300전을 돌려받았습니다.');
end $$;

/* ── 5) 정표 다루기·파기 ─────────────────────────────── */
create or replace function public.world_bond_set(p_wear boolean default null, p_hide boolean default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); b public.world_bonds%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into b from public.world_bonds where ended_at is null and (a_id = uid or b_id = uid) for update;
  if not found then raise exception '맺은 연리가 없습니다.'; end if;
  if b.a_id = uid then
    update public.world_bonds set a_wear = coalesce(p_wear, a_wear), a_hide = coalesce(p_hide, a_hide) where bond_id = b.bond_id;
  else
    update public.world_bonds set b_wear = coalesce(p_wear, b_wear), b_hide = coalesce(p_hide, b_hide) where bond_id = b.bond_id;
  end if;
  return jsonb_build_object('ok', true, 'content', case when p_wear is not null then case when p_wear then '정표를 착용했습니다.' else '정표를 벗었습니다.' end
    else case when p_hide then '연리를 다른 조사원에게 숨겼습니다.' else '연리를 다른 조사원에게 보입니다.' end end);
end $$;

create or replace function public.world_bond_break(p_reason text default 'break')
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); b public.world_bonds%rowtype; pid uuid; myname text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into b from public.world_bonds where ended_at is null and (a_id = uid or b_id = uid) for update;
  if not found then raise exception '맺은 연리가 없습니다.'; end if;
  pid := case when b.a_id = uid then b.b_id else b.a_id end;
  select character_name into myname from public.world_characters where owner_id = uid;
  -- 파기한 쪽의 정표는 사라지고, 상대에게는 「상대가 파기한 정표」가 남는다
  update public.world_bonds set ended_at = now(), ended_by = uid,
    a_cleared = (a_id = uid), b_cleared = (b_id = uid) where bond_id = b.bond_id;
  perform public.world_bond_note(pid, 'bond_broken', '정표가 파기되었습니다', coalesce(myname, '정인') || '님이 「' || public.world_bond_token_name(b.token_key) || '」을(를) 파기해 연리가 끝났습니다.', jsonb_build_object('bond_id', b.bond_id));
  return jsonb_build_object('ok', true, 'content', '정표를 파기해 연리가 끝났습니다. 3일 동안은 새 연리를 맺을 수 없습니다.');
end $$;

create or replace function public.world_bond_clear()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  update public.world_bonds set a_cleared = case when a_id = uid then true else a_cleared end, b_cleared = case when b_id = uid then true else b_cleared end
   where ended_at is not null and (a_id = uid or b_id = uid);
  return jsonb_build_object('ok', true, 'content', '깨진 정표를 정리했습니다.');
end $$;

-- 차단하면 연리가 자동으로 파기된다(차단한 사람이 파기한 것으로 본다)
create or replace function public.world_bond_on_block()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare b public.world_bonds%rowtype; nm text;
begin
  select * into b from public.world_bonds where ended_at is null and ((a_id = new.owner_id and b_id = new.blocked_id) or (b_id = new.owner_id and a_id = new.blocked_id)) for update;
  if found then
    update public.world_bonds set ended_at = now(), ended_by = new.owner_id, a_cleared = (a_id = new.owner_id), b_cleared = (b_id = new.owner_id) where bond_id = b.bond_id;
    select character_name into nm from public.world_characters where owner_id = new.owner_id;
    perform public.world_bond_note(new.blocked_id, 'bond_broken', '정표가 파기되었습니다', coalesce(nm, '정인') || '님이 연리를 끝냈습니다.', jsonb_build_object('bond_id', b.bond_id));
  end if;
  update public.world_bond_requests r set status = 'canceled' where r.status = 'pending' and ((r.from_id = new.owner_id and r.to_id = new.blocked_id) or (r.to_id = new.owner_id and r.from_id = new.blocked_id));
  return new;
end $$;
drop trigger if exists world_bond_on_block on public.world_blocks;
create trigger world_bond_on_block after insert on public.world_blocks for each row execute function public.world_bond_on_block();

/* ── 6) 선물 ───────────────────────────────────────────── */
create or replace function public.world_bond_gift(p_item text default null, p_qty int default 1, p_gil int default 0)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); b public.world_bonds%rowtype; pid uuid; side text; today date := public.world_bond_day();
  me public.world_characters%rowtype; pc public.world_characters%rowtype; it public.world_item_catalog%rowtype; q int := greatest(1, coalesce(p_qty, 1)); g int := greatest(0, coalesce(p_gil, 0));
  have int; equipped int; what text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into b from public.world_bonds where ended_at is null and (a_id = uid or b_id = uid) for update;
  if not found then raise exception '맺은 연리가 없습니다.'; end if;
  side := case when b.a_id = uid then 'a' else 'b' end; pid := case when side = 'a' then b.b_id else b.a_id end;
  if (case when side = 'a' then b.a_gift_day else b.b_gift_day end) = today then raise exception '선물은 하루에 한 번 보낼 수 있습니다. 내일 다시 보내 주세요.'; end if;
  if p_item is null and g <= 0 then raise exception '보낼 물품이나 전을 골라 주세요.'; end if;
  if p_item is not null and g > 0 then raise exception '선물은 물품이나 전 가운데 하나만 보낼 수 있습니다.'; end if;
  -- 두 캐릭터를 정해진 순서로 잠근다
  if uid < pid then select * into me from public.world_characters where owner_id = uid for update; select * into pc from public.world_characters where owner_id = pid for update;
  else select * into pc from public.world_characters where owner_id = pid for update; select * into me from public.world_characters where owner_id = uid for update; end if;
  if p_item is not null then
    select * into it from public.world_item_catalog where item_id = p_item;
    if not found or not coalesce(it.tradeable, true) then raise exception '이 물품은 주고받을 수 없습니다.'; end if;
    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = p_item) then raise exception '잠근 물품은 보낼 수 없습니다. 잠금을 풀고 보내 주세요.'; end if;
    have := coalesce((me.inventory ->> p_item)::int, 0);
    equipped := (select count(*) from public.world_character_equipment e where e.owner_id = uid and e.item_id = p_item);
    if have - equipped < q then raise exception '보낼 만큼 가지고 있지 않습니다(장착 중인 것은 보낼 수 없습니다).'; end if;
    -- 가방 칸 계산은 world_bag_count·world_bag_limit와 같다(수량 합 ≤ 가방 칸 + 수향연맹 20)
    if (select coalesce(sum(greatest(0, case when jsonb_typeof(v) = 'number' then v::text::numeric else 0 end)), 0) from jsonb_each(coalesce(pc.inventory, '{}'::jsonb)) t(k, v)) + q
       > (pc.bag_capacity + (case when pc.major_faction_id = 'river_alliance' then 20 else 0 end)) then raise exception '정인의 가방에 자리가 없습니다.'; end if;
    update public.world_characters set inventory = case when have - q <= 0 then inventory - p_item else jsonb_set(inventory, array[p_item], to_jsonb(have - q)) end, updated_at = now() where owner_id = uid;
    update public.world_characters set inventory = jsonb_set(coalesce(inventory, '{}'::jsonb), array[p_item], to_jsonb(coalesce((inventory ->> p_item)::int, 0) + q)), updated_at = now() where owner_id = pid;
    what := it.item_name || ' ×' || q;
  else
    if me.gil < g then raise exception '전이 모자랍니다.'; end if;
    update public.world_characters set gil = gil - g, updated_at = now() where owner_id = uid;
    update public.world_characters set gil = gil + g, updated_at = now() where owner_id = pid;
    what := g || '전';
  end if;
  if side = 'a' then update public.world_bonds set a_gift_day = today where bond_id = b.bond_id; else update public.world_bonds set b_gift_day = today where bond_id = b.bond_id; end if;
  perform public.world_bond_note(pid, 'bond_gift', '정인의 선물', me.character_name || '님이 ' || what || '을(를) 보냈습니다.', jsonb_build_object('item', p_item, 'qty', q, 'gil', g));
  perform public.world_bond_gain(b.bond_id, 5, 'gift');
  return jsonb_build_object('ok', true, 'content', pc.character_name || '님에게 ' || what || '을(를) 보냈습니다.');
end $$;

/* ── 7) 인연도가 오르는 때(행동 기록·귓속말) ─────────── */
create or replace function public.world_bond_on_event()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare pid uuid; bid uuid;
begin
  pid := public.world_bond_partner(new.actor_id);
  if pid is null then return new; end if;
  select bond_id into bid from public.world_bonds where ended_at is null and (a_id = new.actor_id or b_id = new.actor_id) limit 1;
  if new.event_type = 'rescue' and (new.payload ->> 'target_id')::uuid = pid then
    perform public.world_bond_gain(bid, 10, 'rescue');
  elsif new.event_type = 'combat' and coalesce((new.payload ->> 'defeated')::boolean, false) and public.world_bond_together(new.actor_id) then
    perform public.world_bond_gain(bid, 1, 'fight');
  end if;
  return new;
exception when others then return new; -- 인연도 때문에 행동이 실패하지 않게 한다
end $$;
drop trigger if exists world_bond_on_event on public.world_events;
create trigger world_bond_on_event after insert on public.world_events for each row
  when (new.event_type in ('rescue', 'combat')) execute function public.world_bond_on_event();

create or replace function public.world_bond_on_whisper()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare b public.world_bonds%rowtype; today date := public.world_bond_day();
begin
  select * into b from public.world_bonds where ended_at is null
     and ((a_id = new.sender_id and b_id = new.recipient_id) or (b_id = new.sender_id and a_id = new.recipient_id)) for update;
  if not found then return new; end if;
  if b.a_id = new.sender_id and b.a_greet_day is distinct from today then
    update public.world_bonds set a_greet_day = today where bond_id = b.bond_id; perform public.world_bond_gain(b.bond_id, 3, 'greet');
  elsif b.b_id = new.sender_id and b.b_greet_day is distinct from today then
    update public.world_bonds set b_greet_day = today where bond_id = b.bond_id; perform public.world_bond_gain(b.bond_id, 3, 'greet');
  end if;
  return new;
exception when others then return new;
end $$;
drop trigger if exists world_bond_on_whisper on public.world_chat_messages;
create trigger world_bond_on_whisper after insert on public.world_chat_messages for each row
  when (new.channel_type = 'whisper') execute function public.world_bond_on_whisper();

/* ── 8) 꾸미기 3종과 판정 ─────────────────────────────── */
insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
  ('pt_yeonri', 'pattern', 'rare', '연리 무늬', '정인과의 인연이 「마음이 이어짐」에 이른다', '교류', '{"bond_stage": 2}'::jsonb, false, true, 236),
  ('fr_yeonri', 'frame', 'legend', '연리 테두리', '정인과의 인연이 「연리」에 이른다', '교류', '{"bond_stage": 3}'::jsonb, false, true, 82),
  ('sl_yeon', 'seal', 'legend', '낙관 「緣」', '정인과의 인연이 「백년해로」에 이른다', '교류', '{"bond_stage": 4}'::jsonb, false, true, 362)
on conflict (cosmetic_key) do nothing;

do $patch$
declare d text; n text;
begin
  d := pg_get_functiondef('public.world_cosmetic_rule_ok(uuid, jsonb)'::regprocedure); n := d;
  if position('bond_stage' in n) = 0 then
    n := replace(n, 'elsif p_rule ? ''friends'' then',
      'elsif p_rule ? ''bond_stage'' then
    return coalesce((select max(public.world_bond_stage(affinity)) from public.world_bonds where a_id = p_owner or b_id = p_owner), 0) >= (p_rule ->> ''bond_stage'')::int;
  elsif p_rule ? ''friends'' then');
    if n = d then raise exception 'world_cosmetic_rule_ok 고칠 곳을 찾지 못했습니다.'; end if;
    execute n;
  end if;
end $patch$;

/* ── 9) 정인 구조: 체력 50으로 일으킨다 ───────────────── */
grant fn_owner_18956 to postgres with inherit true;
do $patch$
declare d text; n text;
begin
  d := pg_get_functiondef('public.world_rescue_character(uuid)'::regprocedure); n := d;
  if position('world_bond_partner' in n) = 0 then
    n := replace(n, 'set health=30,mental=greatest(1,mental)', 'set health=case when public.world_bond_partner(uid)=p_target then 50 else 30 end,mental=greatest(1,mental)');
    n := replace(n, '조사원을 구조했다. 체력 30으로 복귀.''', '조사원을 구조했다. 체력 ''||target.health||''(으)로 복귀.''');
    if position('world_bond_partner' in n) = 0 or position('target.health||' in n) = 0 then raise exception 'world_rescue_character 고칠 곳을 찾지 못했습니다.'; end if;
    execute n;
  end if;
end $patch$;
grant fn_owner_18956 to postgres with inherit false;

/* ── 10) 토벌 간격 2초 → 1초 ────────────────────────────── */
-- 행동 기록 트리거가 토벌(전투 승리) 기록 사이를 2초로 막아, 한 번에 쓰러뜨리고 바로 다음 요괴를 잡으면
-- 「전투 행동 간격이 너무 짧습니다」로 막혔다. 전투 행동 간격(1초, world_battle_action)과 같게 1초로 맞춘다.
grant fn_owner_19149 to postgres with inherit true;
do $patch$
declare d text; n text;
begin
  d := pg_get_functiondef('public.world_guard_repeat_farming()'::regprocedure); n := d;
  if position('(''combat'',''encounter'') THEN 2' in n) > 0 then
    n := replace(n, '(''combat'',''encounter'') THEN 2', '(''combat'',''encounter'') THEN 1');
    execute n;
  elsif position('(''combat'',''encounter'') THEN 1' in n) = 0 then
    raise exception 'world_guard_repeat_farming 고칠 곳을 찾지 못했습니다.';
  end if;
end $patch$;
grant fn_owner_19149 to postgres with inherit false;

/* ── 11) 소유자·권한 ──────────────────────────────────── */
do $$
declare f text;
begin
  foreach f in array array['world_bond_token_name(text)', 'world_bond_day()', 'world_bond_stage(integer)', 'world_bond_stage_name(integer)', 'world_bond_active(uuid)',
    'world_bond_partner(uuid)', 'world_bond_together(uuid)', 'world_bond_bonus(uuid, text)', 'world_bond_self(text)', 'world_bond_note(uuid, text, text, text, jsonb)',
    'world_bond_gain(uuid, integer, text)', 'world_bond_expire()', 'world_bond_block_reason(uuid, text)', 'world_bond_snapshot()', 'world_bond_public(uuid)',
    'world_bond_propose(uuid, text, text)', 'world_bond_respond(uuid, boolean)', 'world_bond_cancel()', 'world_bond_set(boolean, boolean)', 'world_bond_break(text)',
    'world_bond_clear()', 'world_bond_gift(text, integer, integer)', 'world_bond_on_event()', 'world_bond_on_whisper()', 'world_bond_on_block()'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon', f);
  end loop;
  -- 화면이 부르는 함수
  foreach f in array array['world_bond_snapshot()', 'world_bond_public(uuid)', 'world_bond_propose(uuid, text, text)', 'world_bond_respond(uuid, boolean)', 'world_bond_cancel()',
    'world_bond_set(boolean, boolean)', 'world_bond_break(text)', 'world_bond_clear()', 'world_bond_gift(text, integer, integer)', 'world_bond_self(text)'] loop
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
-- 다른 소유자의 함수(구조)가 정인 여부를 묻는다
grant execute on function public.world_bond_partner(uuid) to fn_owner_18956;
-- 상태 효과 합계는 호출한 쪽 권한으로 돈다(여러 함수 소유자가 부른다)
grant execute on function public.world_bond_self(text) to public;
revoke execute on function public.world_bond_self(text) from anon;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028000000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select (select count(*) from pg_proc where proname like 'world_bond_%') as functions,
       (select count(*) from pg_tables where schemaname = 'public' and tablename like 'world_bond%') as tables,
       (select count(*) from public.world_cosmetic_catalog where cosmetic_key in ('pt_yeonri', 'fr_yeonri', 'sl_yeon')) as cosmetics,
       position('world_bond_self' in pg_get_functiondef('public.world_status_effect_total(text)'::regprocedure)) > 0 as bonus_on;
