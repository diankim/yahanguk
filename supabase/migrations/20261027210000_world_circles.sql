-- 모임: 유저가 직접 꾸리는 채팅방(세력·지역·파티와 무관)
-- - 직위: 모임장(leader) · 총무(manager, 3명까지) · 모임원(member)
-- - 만들기: Lv.5 이상, 모임장인 모임 2개까지. 소속(만든 것 포함)은 5개까지. 정원 20명. 이름 2~12자, 대소문자·앞뒤 공백 무시 중복 금지.
-- - 초대: 모임장·총무가 보낸다. 24시간 유효, 받은 사람이 수락해야 들어온다(화면 위 팝업 · world_notifications kind = circle_invite).
--   어느 한쪽이라도 차단했으면 막는다. 수락할 때 정원·소속 수를 다시 검사한다(모임 행을 잠가 동시에 수락해도 넘치지 않음).
-- - 채팅: 모임원만 읽고 쓴다(RLS). 2초에 한 번, 1~300자. 30일 지난 말은 지운다. 들어옴·나감·내보냄·직위 변경은 안내 줄로 남긴다.
-- - 채팅 색: 모임원마다 자기 화면에서 모임별 색을 정한다(world_circle_members.color, #rrggbb).
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

/* ── 1) 표 ─────────────────────────────────────────────── */
create table if not exists public.world_circles (
  circle_id uuid primary key default gen_random_uuid(),
  name text not null,
  intro text not null default '',
  leader_id uuid not null references auth.users(id) on delete cascade,
  created_by uuid not null,
  created_at timestamptz not null default now()
);
create unique index if not exists world_circles_name_key on public.world_circles (lower(btrim(name)));

create table if not exists public.world_circle_members (
  circle_id uuid not null references public.world_circles(circle_id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('leader', 'manager', 'member')),
  color text not null default '#c8a25a' check (color ~ '^#[0-9a-f]{6}$'),
  joined_at timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  primary key (circle_id, owner_id)
);
create index if not exists world_circle_members_owner on public.world_circle_members(owner_id);

create table if not exists public.world_circle_invites (
  invite_id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.world_circles(circle_id) on delete cascade,
  inviter_id uuid not null,
  invitee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'canceled')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);
create unique index if not exists world_circle_invites_pending on public.world_circle_invites(circle_id, invitee_id) where status = 'pending';

create table if not exists public.world_circle_messages (
  id bigint generated always as identity primary key,
  circle_id uuid not null references public.world_circles(circle_id) on delete cascade,
  sender_id uuid,
  sender_name text,
  sender_title text,
  kind text not null default 'chat' check (kind in ('chat', 'notice')),
  content text not null,
  created_at timestamptz not null default now()
);
create index if not exists world_circle_messages_circle on public.world_circle_messages(circle_id, created_at desc);

alter table public.world_circles enable row level security;
alter table public.world_circle_members enable row level security;
alter table public.world_circle_invites enable row level security;
alter table public.world_circle_messages enable row level security;
revoke all on public.world_circles, public.world_circle_members, public.world_circle_invites, public.world_circle_messages from anon, authenticated;
-- 클라이언트는 자기 소속 행과, 소속 모임의 메시지만 읽는다(쓰기는 모두 함수로)
grant select on public.world_circle_members, public.world_circle_messages to authenticated;
drop policy if exists world_circle_members_read_own on public.world_circle_members;
create policy world_circle_members_read_own on public.world_circle_members for select to authenticated using (owner_id = (select auth.uid()));
drop policy if exists world_circle_messages_read_member on public.world_circle_messages;
create policy world_circle_messages_read_member on public.world_circle_messages for select to authenticated
  using (exists (select 1 from public.world_circle_members m where m.circle_id = world_circle_messages.circle_id and m.owner_id = (select auth.uid())));
grant select, insert, update, delete on public.world_circles, public.world_circle_members, public.world_circle_invites, public.world_circle_messages to fn_owner_field;
grant select, insert on public.world_notifications to fn_owner_field;
do $$ declare q text := pg_get_serial_sequence('public.world_notifications', 'id'); begin if q is not null then execute format('grant usage on sequence %s to fn_owner_field', q); end if; end $$;

-- 새 메시지를 실시간으로 받는다(RLS가 소속 모임 것만 보낸다)
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'world_circle_messages') then
    alter publication supabase_realtime add table public.world_circle_messages;
  end if;
end $$;

/* ── 2) 도움 함수 ─────────────────────────────────────── */
create or replace function public.world_circle_role(p_circle uuid, p_owner uuid)
returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select role from public.world_circle_members where circle_id = p_circle and owner_id = p_owner
$$;
create or replace function public.world_circle_notice(p_circle uuid, p_text text)
returns void language sql security definer set search_path to 'pg_catalog', 'public' as $$
  insert into public.world_circle_messages(circle_id, kind, content) values (p_circle, 'notice', p_text)
$$;
create or replace function public.world_circle_pick_color(p_seed text)
returns text language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select (array['#c8a25a', '#6fa8dc', '#8fbf7f', '#d78a8a', '#b08fd8', '#5fb3a8', '#d9a15f', '#9aa8b8'])[1 + abs(hashtext(p_seed)) % 8]
$$;

/* ── 3) 조회 ───────────────────────────────────────────── */
create or replace function public.world_circle_snapshot()
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  with me as (select public.fn_owner_auth_uid() as uid)
  select jsonb_build_object(
    'circles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'circle_id', c.circle_id, 'name', c.name, 'intro', c.intro, 'role', m.role, 'color', m.color, 'leader_id', c.leader_id,
        'member_count', (select count(*) from public.world_circle_members x where x.circle_id = c.circle_id),
        'unread', (select count(*) from public.world_circle_messages g where g.circle_id = c.circle_id and g.created_at > m.last_read_at and g.sender_id is distinct from m.owner_id and g.kind = 'chat'),
        'last_at', (select max(g.created_at) from public.world_circle_messages g where g.circle_id = c.circle_id),
        'members', (select coalesce(jsonb_agg(jsonb_build_object('owner_id', x.owner_id, 'name', wc.character_name, 'role', x.role, 'level', wc.level, 'job_key', wc.job_key,
                       'location', wc.location, 'joined_at', x.joined_at) order by case x.role when 'leader' then 0 when 'manager' then 1 else 2 end, wc.character_name), '[]'::jsonb)
                    from public.world_circle_members x left join public.world_characters wc on wc.owner_id = x.owner_id where x.circle_id = c.circle_id),
        'invites', case when m.role in ('leader', 'manager') then (select coalesce(jsonb_agg(jsonb_build_object('invite_id', i.invite_id, 'name', wc.character_name, 'expires_at', i.expires_at)), '[]'::jsonb)
                    from public.world_circle_invites i left join public.world_characters wc on wc.owner_id = i.invitee_id
                    where i.circle_id = c.circle_id and i.status = 'pending' and i.expires_at > now()) else '[]'::jsonb end
      ) order by m.joined_at)
      from public.world_circle_members m join public.world_circles c on c.circle_id = m.circle_id, me where m.owner_id = me.uid), '[]'::jsonb),
    'received', coalesce((
      select jsonb_agg(jsonb_build_object('invite_id', i.invite_id, 'circle_name', c.name, 'from', wc.character_name, 'expires_at', i.expires_at,
        'member_count', (select count(*) from public.world_circle_members x where x.circle_id = c.circle_id)) order by i.created_at desc)
      from public.world_circle_invites i join public.world_circles c on c.circle_id = i.circle_id left join public.world_characters wc on wc.owner_id = i.inviter_id, me
      where i.invitee_id = me.uid and i.status = 'pending' and i.expires_at > now()), '[]'::jsonb),
    'limits', jsonb_build_object('lead', 2, 'join', 5, 'size', 20, 'managers', 3, 'level', 5),
    'leading', (select count(*) from public.world_circles c, me where c.leader_id = me.uid),
    'joined', (select count(*) from public.world_circle_members m, me where m.owner_id = me.uid)
  )
  from me where me.uid is not null
$$;

/* ── 4) 만들기·초대·수락 ──────────────────────────────── */
create or replace function public.world_circle_create(p_name text, p_intro text default '')
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; nm text := btrim(coalesce(p_name, '')); cid uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.level, 1) < 5 then raise exception '모임은 Lv.5부터 만들 수 있습니다.'; end if;
  if char_length(nm) < 2 or char_length(nm) > 12 then raise exception '모임 이름은 2~12자로 정하세요.'; end if;
  if nm !~ '^[가-힣A-Za-z0-9 ·]+$' then raise exception '모임 이름에는 한글·영문·숫자·공백·가운뎃점만 쓸 수 있습니다.'; end if;
  if (select count(*) from public.world_circles where leader_id = uid) >= 2 then raise exception '모임장인 모임은 2개까지입니다.'; end if;
  if (select count(*) from public.world_circle_members where owner_id = uid) >= 5 then raise exception '모임은 5개까지 들 수 있습니다. 다른 모임에서 나온 뒤 만드세요.'; end if;
  if exists (select 1 from public.world_circles where lower(btrim(name)) = lower(nm)) then raise exception '이미 있는 모임 이름입니다.'; end if;
  insert into public.world_circles(name, intro, leader_id, created_by) values (nm, left(btrim(coalesce(p_intro, '')), 60), uid, uid) returning circle_id into cid;
  insert into public.world_circle_members(circle_id, owner_id, role, color) values (cid, uid, 'leader', public.world_circle_pick_color(cid::text));
  perform public.world_circle_notice(cid, c.character_name || '님이 모임 「' || nm || '」을(를) 열었습니다.');
  return jsonb_build_object('ok', true, 'circle_id', cid, 'content', '모임 「' || nm || '」을(를) 만들었습니다.');
end $$;

create or replace function public.world_circle_invite(p_circle uuid, p_target uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); me public.world_characters%rowtype; t public.world_characters%rowtype; cc public.world_circles%rowtype; iid uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into cc from public.world_circles where circle_id = p_circle for update;
  if not found then raise exception '없는 모임입니다.'; end if;
  if coalesce(public.world_circle_role(p_circle, uid), '') not in ('leader', 'manager') then raise exception '모임장·총무만 초대할 수 있습니다.'; end if;
  select * into me from public.world_characters where owner_id = uid;
  select * into t from public.world_characters where owner_id = p_target;
  if t.owner_id is null or t.owner_id = uid then raise exception '초대할 수 없는 조사원입니다.'; end if;
  if exists (select 1 from public.world_blocks b where (b.owner_id = uid and b.blocked_id = p_target) or (b.owner_id = p_target and b.blocked_id = uid)) then raise exception '이 조사원은 초대할 수 없습니다.'; end if;
  if exists (select 1 from public.world_circle_members where circle_id = p_circle and owner_id = p_target) then raise exception '이미 이 모임에 있는 조사원입니다.'; end if;
  if (select count(*) from public.world_circle_members where circle_id = p_circle) >= 20 then raise exception '모임 정원(20명)이 찼습니다.'; end if;
  if (select count(*) from public.world_circle_members where owner_id = p_target) >= 5 then raise exception '상대가 이미 모임 5개에 들어 있습니다.'; end if;
  -- 지난 초대는 정리하고, 아직 유효한 초대가 있으면 다시 보내지 않는다
  update public.world_circle_invites set status = 'canceled' where circle_id = p_circle and invitee_id = p_target and status = 'pending' and expires_at <= now();
  if exists (select 1 from public.world_circle_invites where circle_id = p_circle and invitee_id = p_target and status = 'pending') then raise exception '이미 초대를 보냈습니다. 상대의 답을 기다리세요.'; end if;
  insert into public.world_circle_invites(circle_id, inviter_id, invitee_id) values (p_circle, uid, p_target) returning invite_id into iid;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_target, 'circle_invite', '모임 초대', me.character_name || '님이 모임 「' || cc.name || '」에 초대했습니다.', jsonb_build_object('invite_id', iid, 'circle_id', p_circle, 'circle_name', cc.name));
  return jsonb_build_object('ok', true, 'content', t.character_name || '님에게 모임 초대를 보냈습니다.');
end $$;

create or replace function public.world_circle_respond(p_invite uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); i public.world_circle_invites%rowtype; cc public.world_circles%rowtype; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into i from public.world_circle_invites where invite_id = p_invite and invitee_id = uid for update;
  if not found or i.status <> 'pending' then raise exception '이미 답했거나 사라진 초대입니다.'; end if;
  if i.expires_at <= now() then update public.world_circle_invites set status = 'canceled' where invite_id = p_invite; raise exception '초대 기한(24시간)이 지났습니다.'; end if;
  select * into cc from public.world_circles where circle_id = i.circle_id for update;
  if not found then raise exception '사라진 모임입니다.'; end if;
  if not p_accept then
    update public.world_circle_invites set status = 'declined' where invite_id = p_invite;
    return jsonb_build_object('ok', true, 'content', '모임 초대를 거절했습니다.');
  end if;
  if (select count(*) from public.world_circle_members where circle_id = cc.circle_id) >= 20 then raise exception '모임 정원(20명)이 찼습니다.'; end if;
  if (select count(*) from public.world_circle_members where owner_id = uid) >= 5 then raise exception '모임은 5개까지 들 수 있습니다. 다른 모임에서 나온 뒤 수락하세요.'; end if;
  if exists (select 1 from public.world_blocks b where (b.owner_id = uid and b.blocked_id = i.inviter_id) or (b.owner_id = i.inviter_id and b.blocked_id = uid)) then raise exception '이 초대는 받을 수 없습니다.'; end if;
  insert into public.world_circle_members(circle_id, owner_id, role, color) values (cc.circle_id, uid, 'member', public.world_circle_pick_color(cc.circle_id::text)) on conflict do nothing;
  update public.world_circle_invites set status = 'accepted' where invite_id = p_invite;
  select character_name into nm from public.world_characters where owner_id = uid;
  perform public.world_circle_notice(cc.circle_id, coalesce(nm, '조사원') || '님이 모임에 들어왔습니다.');
  return jsonb_build_object('ok', true, 'circle_id', cc.circle_id, 'content', '모임 「' || cc.name || '」에 들어갔습니다.');
end $$;

/* ── 5) 관리 ───────────────────────────────────────────── */
create or replace function public.world_circle_manage(p_circle uuid, p_action text, p_target uuid default null, p_text text default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); cc public.world_circles%rowtype; my text; their text; tn text; mn text; nm text; left_count int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into cc from public.world_circles where circle_id = p_circle for update;
  if not found then raise exception '없는 모임입니다.'; end if;
  my := public.world_circle_role(p_circle, uid);
  if my is null then raise exception '이 모임에 들어 있지 않습니다.'; end if;
  select character_name into mn from public.world_characters where owner_id = uid;
  if p_target is not null then their := public.world_circle_role(p_circle, p_target); select character_name into tn from public.world_characters where owner_id = p_target; end if;

  if p_action = 'leave' then
    if my = 'leader' then
      select count(*) into left_count from public.world_circle_members where circle_id = p_circle;
      if left_count > 1 then raise exception '모임장은 다른 모임원에게 모임장을 넘긴 뒤 나갈 수 있습니다. 혼자 남았으면 해산하세요.'; end if;
      delete from public.world_circles where circle_id = p_circle;
      return jsonb_build_object('ok', true, 'content', '모임 「' || cc.name || '」을(를) 닫았습니다.');
    end if;
    delete from public.world_circle_members where circle_id = p_circle and owner_id = uid;
    perform public.world_circle_notice(p_circle, coalesce(mn, '조사원') || '님이 모임을 나갔습니다.');
    return jsonb_build_object('ok', true, 'content', '모임 「' || cc.name || '」에서 나왔습니다.');

  elsif p_action = 'kick' then
    if their is null then raise exception '이 모임에 없는 조사원입니다.'; end if;
    if p_target = uid then raise exception '자신은 내보낼 수 없습니다. 나가기를 쓰세요.'; end if;
    if not (my = 'leader' or (my = 'manager' and their = 'member')) then raise exception '모임장은 누구든, 총무는 모임원만 내보낼 수 있습니다.'; end if;
    delete from public.world_circle_members where circle_id = p_circle and owner_id = p_target;
    perform public.world_circle_notice(p_circle, coalesce(tn, '조사원') || '님이 모임에서 내보내졌습니다.');
    return jsonb_build_object('ok', true, 'content', coalesce(tn, '조사원') || '님을 내보냈습니다.');

  elsif p_action in ('manager', 'member') then
    if my <> 'leader' then raise exception '직위는 모임장만 바꿀 수 있습니다.'; end if;
    if their is null or their = 'leader' then raise exception '바꿀 수 없는 대상입니다.'; end if;
    if p_action = 'manager' and their <> 'manager' and (select count(*) from public.world_circle_members where circle_id = p_circle and role = 'manager') >= 3 then raise exception '총무는 3명까지 둘 수 있습니다.'; end if;
    update public.world_circle_members set role = p_action where circle_id = p_circle and owner_id = p_target;
    perform public.world_circle_notice(p_circle, coalesce(tn, '조사원') || '님이 ' || case p_action when 'manager' then '총무' else '모임원' end || '(으)로 바뀌었습니다.');
    return jsonb_build_object('ok', true, 'content', '직위를 바꿨습니다.');

  elsif p_action = 'transfer' then
    if my <> 'leader' then raise exception '모임장만 넘길 수 있습니다.'; end if;
    if their is null or p_target = uid then raise exception '모임원에게만 넘길 수 있습니다.'; end if;
    if (select count(*) from public.world_circles where leader_id = p_target) >= 2 then raise exception '상대가 이미 모임 2개의 모임장입니다.'; end if;
    update public.world_circle_members set role = 'manager' where circle_id = p_circle and owner_id = uid;
    update public.world_circle_members set role = 'leader' where circle_id = p_circle and owner_id = p_target;
    update public.world_circles set leader_id = p_target where circle_id = p_circle;
    perform public.world_circle_notice(p_circle, coalesce(tn, '조사원') || '님이 새 모임장이 되었습니다.');
    return jsonb_build_object('ok', true, 'content', coalesce(tn, '조사원') || '님에게 모임장을 넘겼습니다.');

  elsif p_action = 'intro' then
    if my not in ('leader', 'manager') then raise exception '모임장·총무만 소개를 고칠 수 있습니다.'; end if;
    update public.world_circles set intro = left(btrim(coalesce(p_text, '')), 60) where circle_id = p_circle;
    return jsonb_build_object('ok', true, 'content', '모임 소개를 고쳤습니다.');

  elsif p_action = 'rename' then
    if my <> 'leader' then raise exception '이름은 모임장만 바꿀 수 있습니다.'; end if;
    nm := btrim(coalesce(p_text, ''));
    if char_length(nm) < 2 or char_length(nm) > 12 or nm !~ '^[가-힣A-Za-z0-9 ·]+$' then raise exception '모임 이름은 한글·영문·숫자 2~12자로 정하세요.'; end if;
    if exists (select 1 from public.world_circles where lower(btrim(name)) = lower(nm) and circle_id <> p_circle) then raise exception '이미 있는 모임 이름입니다.'; end if;
    update public.world_circles set name = nm where circle_id = p_circle;
    perform public.world_circle_notice(p_circle, '모임 이름이 「' || nm || '」(으)로 바뀌었습니다.');
    return jsonb_build_object('ok', true, 'content', '모임 이름을 바꿨습니다.');

  elsif p_action = 'cancel_invite' then
    if my not in ('leader', 'manager') then raise exception '모임장·총무만 초대를 거둘 수 있습니다.'; end if;
    update public.world_circle_invites set status = 'canceled' where circle_id = p_circle and invite_id::text = p_text and status = 'pending';
    return jsonb_build_object('ok', true, 'content', '초대를 거두었습니다.');

  elsif p_action = 'disband' then
    if my <> 'leader' then raise exception '모임장만 해산할 수 있습니다.'; end if;
    delete from public.world_circles where circle_id = p_circle;
    return jsonb_build_object('ok', true, 'content', '모임 「' || cc.name || '」을(를) 해산했습니다.');
  end if;
  raise exception '알 수 없는 모임 관리입니다.';
end $$;

create or replace function public.world_circle_set_color(p_circle uuid, p_color text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); col text := lower(btrim(coalesce(p_color, '')));
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if col !~ '^#[0-9a-f]{6}$' then raise exception '색을 다시 골라 주세요.'; end if;
  update public.world_circle_members set color = col where circle_id = p_circle and owner_id = uid;
  if not found then raise exception '이 모임에 들어 있지 않습니다.'; end if;
  return jsonb_build_object('ok', true, 'color', col);
end $$;

create or replace function public.world_circle_mark_read(p_circle uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  update public.world_circle_members set last_read_at = now() where circle_id = p_circle and owner_id = uid;
  return jsonb_build_object('ok', true);
end $$;

/* ── 6) 말하기 ─────────────────────────────────────────── */
create or replace function public.world_circle_send(p_circle uuid, p_content text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; clean text := btrim(coalesce(p_content, '')); mid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if char_length(clean) < 1 or char_length(clean) > 300 then raise exception '메시지는 1~300자로 입력해 주세요.'; end if;
  if public.world_circle_role(p_circle, uid) is null then raise exception '이 모임에 들어 있지 않습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if exists (select 1 from public.world_circle_messages where sender_id = uid and created_at > now() - interval '2 seconds') then raise exception '메시지를 너무 빠르게 보내고 있어요. 잠시 기다려 주세요.'; end if;
  insert into public.world_circle_messages(circle_id, sender_id, sender_name, sender_title, content)
  values (p_circle, uid, c.character_name, c.profile ->> 'title_name', clean) returning id into mid;
  update public.world_circle_members set last_read_at = now() where circle_id = p_circle and owner_id = uid;
  -- 30일 지난 말은 정리한다
  delete from public.world_circle_messages where circle_id = p_circle and created_at < now() - interval '30 days';
  return jsonb_build_object('ok', true, 'id', mid);
end $$;

/* ── 7) 소유자·권한 ───────────────────────────────────── */
do $$
declare f text;
begin
  foreach f in array array['world_circle_role(uuid, uuid)', 'world_circle_notice(uuid, text)', 'world_circle_pick_color(text)', 'world_circle_snapshot()',
    'world_circle_create(text, text)', 'world_circle_invite(uuid, uuid)', 'world_circle_respond(uuid, boolean)', 'world_circle_manage(uuid, text, uuid, text)',
    'world_circle_set_color(uuid, text)', 'world_circle_mark_read(uuid)', 'world_circle_send(uuid, text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon', f);
  end loop;
  foreach f in array array['world_circle_role(uuid, uuid)', 'world_circle_notice(uuid, text)', 'world_circle_pick_color(text)'] loop
    execute format('revoke all on function public.%s from authenticated', f);
  end loop;
  foreach f in array array['world_circle_snapshot()', 'world_circle_create(text, text)', 'world_circle_invite(uuid, uuid)', 'world_circle_respond(uuid, boolean)',
    'world_circle_manage(uuid, text, uuid, text)', 'world_circle_set_color(uuid, text)', 'world_circle_mark_read(uuid)', 'world_circle_send(uuid, text)'] loop
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

select (select count(*) from pg_proc where proname like 'world_circle_%') as functions,
       (select count(*) from pg_tables where schemaname = 'public' and tablename like 'world_circle%') as tables,
       exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'world_circle_messages') as realtime;
