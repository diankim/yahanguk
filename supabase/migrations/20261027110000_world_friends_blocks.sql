-- 교류 보강: 친구(신청·수락·거절·끊기)와 차단.
-- - 친구 목록은 서로 수락한 사이에서만 보이고, 친구의 위치·상황·최근 활동을 볼 수 있다.
-- - 차단하면 친구 관계가 끊기고, 상대의 귓속말·친구 신청·파티 초대·직접 거래 제안을 서버가 막는다(채팅 화면에서도 숨긴다).
-- - 쓰기는 모두 RPC로만 한다(테이블에는 로그인 사용자 읽기 정책만 둔다).
-- SQL Editor에서 한 번 실행한다. 다시 실행해도 안전하다.

create table if not exists public.world_friends (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,   -- 신청한 사람
  friend_id uuid not null references public.world_characters(owner_id) on delete cascade,  -- 신청 받은 사람
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  primary key (owner_id, friend_id),
  check (owner_id <> friend_id)
);
create index if not exists world_friends_friend_idx on public.world_friends(friend_id);
alter table public.world_friends enable row level security;
drop policy if exists world_friends_read_own on public.world_friends;
create policy world_friends_read_own on public.world_friends for select to authenticated
  using (owner_id = (select auth.uid()) or friend_id = (select auth.uid()));
revoke all on public.world_friends from anon, authenticated;
grant select on public.world_friends to authenticated;

create table if not exists public.world_blocks (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  blocked_id uuid not null references public.world_characters(owner_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, blocked_id),
  check (owner_id <> blocked_id)
);
alter table public.world_blocks enable row level security;
drop policy if exists world_blocks_read_own on public.world_blocks;
create policy world_blocks_read_own on public.world_blocks for select to authenticated using (owner_id = (select auth.uid()));
revoke all on public.world_blocks from anon, authenticated;
grant select on public.world_blocks to authenticated;

grant select, insert, update, delete on public.world_friends, public.world_blocks to fn_owner_field;
grant select, insert, update on public.world_notifications to fn_owner_field;
grant select on public.world_blocks to fn_owner_19141, fn_owner_19386;

/* ── 친구 신청: 상대가 먼저 보낸 신청이 있으면 바로 친구가 된다 ── */
create or replace function public.world_friend_request(p_target uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); me text; them text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_target is null or p_target = uid then raise exception '친구로 삼을 조사원을 고르세요.'; end if;
  select character_name into me from public.world_characters where owner_id = uid;
  select character_name into them from public.world_characters where owner_id = p_target;
  if me is null or them is null then raise exception '그 조사원을 찾을 수 없습니다.'; end if;
  if exists (select 1 from public.world_blocks where owner_id = uid and blocked_id = p_target) then raise exception '차단한 조사원입니다. 차단을 먼저 풀어 주세요.'; end if;
  if exists (select 1 from public.world_blocks where owner_id = p_target and blocked_id = uid) then raise exception '상대가 친구 신청을 받지 않습니다.'; end if;
  if exists (select 1 from public.world_friends where status = 'accepted' and ((owner_id = uid and friend_id = p_target) or (owner_id = p_target and friend_id = uid))) then
    raise exception '이미 친구입니다.'; end if;
  -- 상대가 먼저 신청했으면 수락으로 처리한다
  if exists (select 1 from public.world_friends where owner_id = p_target and friend_id = uid and status = 'pending') then
    update public.world_friends set status = 'accepted', accepted_at = now() where owner_id = p_target and friend_id = uid;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_target, 'friend_accepted', '친구 맺음', me || '님과 친구가 되었습니다.', jsonb_build_object('friend_id', uid, 'friend_name', me));
    return jsonb_build_object('ok', true, 'status', 'accepted', 'content', them || '님과 친구가 되었습니다.');
  end if;
  if exists (select 1 from public.world_friends where owner_id = uid and friend_id = p_target) then raise exception '이미 친구 신청을 보냈습니다.'; end if;
  if (select count(*) from public.world_friends where owner_id = uid and status = 'pending') >= 20 then raise exception '응답을 기다리는 친구 신청이 너무 많습니다(20건).'; end if;
  if (select count(*) from public.world_friends where status = 'accepted' and (owner_id = uid or friend_id = uid)) >= 50 then raise exception '친구는 50명까지 맺을 수 있습니다.'; end if;
  insert into public.world_friends(owner_id, friend_id) values (uid, p_target);
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_target, 'friend_request', '친구 신청', me || '님이 친구가 되고 싶어 합니다.', jsonb_build_object('from_id', uid, 'from_name', me));
  return jsonb_build_object('ok', true, 'status', 'pending', 'content', them || '님에게 친구 신청을 보냈습니다.');
end $$;

/* ── 받은 신청에 답하기 ── */
create or replace function public.world_friend_respond(p_from uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); me text; them text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform 1 from public.world_friends where owner_id = p_from and friend_id = uid and status = 'pending' for update;
  if not found then raise exception '이미 처리했거나 취소된 친구 신청입니다.'; end if;
  select character_name into me from public.world_characters where owner_id = uid;
  select character_name into them from public.world_characters where owner_id = p_from;
  -- 신청 알림은 답하면 읽음 처리한다
  update public.world_notifications set read_at = now()
   where user_id = uid and kind = 'friend_request' and read_at is null and payload ->> 'from_id' = p_from::text;
  if coalesce(p_accept, false) then
    update public.world_friends set status = 'accepted', accepted_at = now() where owner_id = p_from and friend_id = uid;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_from, 'friend_accepted', '친구 맺음', me || '님이 친구 신청을 받아들였습니다.', jsonb_build_object('friend_id', uid, 'friend_name', me));
    return jsonb_build_object('ok', true, 'content', coalesce(them, '조사원') || '님과 친구가 되었습니다.');
  end if;
  delete from public.world_friends where owner_id = p_from and friend_id = uid;
  return jsonb_build_object('ok', true, 'content', '친구 신청을 거절했습니다.');
end $$;

/* ── 친구 끊기·보낸 신청 취소(어느 쪽이 신청했든) ── */
create or replace function public.world_friend_remove(p_target uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); n int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  delete from public.world_friends where (owner_id = uid and friend_id = p_target) or (owner_id = p_target and friend_id = uid);
  get diagnostics n = row_count;
  if n = 0 then raise exception '친구 관계가 없습니다.'; end if;
  return jsonb_build_object('ok', true, 'content', '친구 관계를 정리했습니다.');
end $$;

/* ── 차단·차단 풀기 ── */
create or replace function public.world_block_set(p_target uuid, p_blocked boolean)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_target is null or p_target = uid then raise exception '차단할 조사원을 고르세요.'; end if;
  if not exists (select 1 from public.world_characters where owner_id = p_target) then raise exception '그 조사원을 찾을 수 없습니다.'; end if;
  if coalesce(p_blocked, true) then
    if (select count(*) from public.world_blocks where owner_id = uid) >= 100 then raise exception '차단은 100명까지 할 수 있습니다.'; end if;
    insert into public.world_blocks(owner_id, blocked_id) values (uid, p_target) on conflict do nothing;
    delete from public.world_friends where (owner_id = uid and friend_id = p_target) or (owner_id = p_target and friend_id = uid);
    return jsonb_build_object('ok', true, 'content', '차단했습니다. 이 조사원의 귓속말·신청·초대·거래 제안을 받지 않습니다.');
  end if;
  delete from public.world_blocks where owner_id = uid and blocked_id = p_target;
  return jsonb_build_object('ok', true, 'content', '차단을 풀었습니다.');
end $$;

/* ── 친구 화면 ── */
create or replace function public.world_friend_overview()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object(
    'friends', (select coalesce(jsonb_agg(jsonb_build_object('owner_id', c.owner_id, 'character_name', c.character_name, 'level', c.level, 'job_key', c.job_key,
        'location', c.location, 'profile', c.profile, 'last_active', c.updated_at, 'since', f.accepted_at,
        'downed', c.downed_at is not null or c.health <= 0, 'is_dead', coalesce(c.is_dead, false),
        'away', exists (select 1 from public.world_expeditions e where e.owner_id = c.owner_id and e.status = 'active'),
        'in_combat', exists (select 1 from public.world_active_encounters a where a.owner_id = c.owner_id and not a.defeated and not coalesce(a.fled, false)),
        'traveling', c.travel_arrives_at is not null and c.travel_arrives_at > now()) order by c.updated_at desc), '[]'::jsonb)
      from public.world_friends f join public.world_characters c on c.owner_id = case when f.owner_id = uid then f.friend_id else f.owner_id end
      where f.status = 'accepted' and (f.owner_id = uid or f.friend_id = uid)),
    'incoming', (select coalesce(jsonb_agg(jsonb_build_object('owner_id', c.owner_id, 'character_name', c.character_name, 'level', c.level, 'job_key', c.job_key, 'profile', c.profile, 'at', f.created_at) order by f.created_at desc), '[]'::jsonb)
      from public.world_friends f join public.world_characters c on c.owner_id = f.owner_id where f.friend_id = uid and f.status = 'pending'),
    'outgoing', (select coalesce(jsonb_agg(jsonb_build_object('owner_id', c.owner_id, 'character_name', c.character_name, 'level', c.level, 'at', f.created_at) order by f.created_at desc), '[]'::jsonb)
      from public.world_friends f join public.world_characters c on c.owner_id = f.friend_id where f.owner_id = uid and f.status = 'pending'),
    'blocked', (select coalesce(jsonb_agg(jsonb_build_object('owner_id', c.owner_id, 'character_name', c.character_name) order by b.created_at desc), '[]'::jsonb)
      from public.world_blocks b join public.world_characters c on c.owner_id = b.blocked_id where b.owner_id = uid));
end $$;

do $$ declare f text;
begin
  foreach f in array array['world_friend_request(uuid)', 'world_friend_respond(uuid, boolean)', 'world_friend_remove(uuid)', 'world_block_set(uuid, boolean)', 'world_friend_overview()'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

/* ── 조사원 카드에 관계 정보를 더한다(친구·차단·같은 파티·같은 곳) ── */
create or replace function public.world_character_card(p_owner uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'pg_catalog', 'public'
as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; my_loc text; my_party uuid; my_role text; their_party uuid; rel text := 'none';
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = p_owner;
  if not found then raise exception '그 조사원을 찾을 수 없습니다.'; end if;
  select location into my_loc from public.world_characters where owner_id = uid;
  select party_id, role into my_party, my_role from public.world_party_members where owner_id = uid;
  select party_id into their_party from public.world_party_members where owner_id = p_owner;
  select case when f.status = 'accepted' then 'friends' when f.owner_id = uid then 'outgoing' else 'incoming' end into rel
    from public.world_friends f where (f.owner_id = uid and f.friend_id = p_owner) or (f.owner_id = p_owner and f.friend_id = uid) limit 1;
  return jsonb_build_object(
    'owner_id', c.owner_id, 'character_name', c.character_name, 'level', c.level,
    'job_key', c.job_key, 'faction_key', c.faction_key, 'major_faction_id', c.major_faction_id,
    'location', c.location, 'profile', coalesce(c.profile, '{}'::jsonb),
    'mine', c.owner_id = uid,
    'gm', exists (select 1 from public.world_staff s where s.owner_id = c.owner_id),
    'downed', c.downed_at is not null or c.health <= 0, 'is_dead', coalesce(c.is_dead, false),
    'away', exists (select 1 from public.world_expeditions e where e.owner_id = c.owner_id and e.status = 'active'),
    'in_combat', exists (select 1 from public.world_active_encounters a where a.owner_id = c.owner_id and not a.defeated and not coalesce(a.fled, false)),
    'traveling', c.travel_arrives_at is not null and c.travel_arrives_at > now(),
    'last_active', case when rel = 'friends' or c.owner_id = uid then c.updated_at end,
    'ranks', jsonb_build_object('combat', c.combat_rank, 'gathering', c.gathering_rank, 'crafting', c.crafting_rank, 'investigation', c.investigation_rank),
    'title_count', (select count(*) from public.world_character_titles t where t.owner_id = c.owner_id),
    'display_title', (select case when tc.hidden and c.owner_id <> uid and not exists (select 1 from public.world_character_titles m where m.owner_id = uid and m.title_key = tc.title_key)
                        then '숨김 칭호' else tc.title_name end
                      from public.world_title_catalog tc where tc.title_key = c.profile ->> 'title'),
    'titles', (select coalesce(jsonb_agg(case when tc.hidden and c.owner_id <> uid and not exists (select 1 from public.world_character_titles m where m.owner_id = uid and m.title_key = tc.title_key)
                        then jsonb_build_object('name', '숨김 칭호', 'hidden', true)
                        else jsonb_build_object('name', tc.title_name, 'description', tc.description) end order by tc.sort), '[]'::jsonb)
               from public.world_character_titles t join public.world_title_catalog tc using (title_key)
               where t.owner_id = c.owner_id and t.is_equipped),
    'relation', coalesce(rel, 'none'),
    'blocked', exists (select 1 from public.world_blocks b where b.owner_id = uid and b.blocked_id = p_owner),
    'same_place', my_loc is not distinct from c.location,
    'same_party', my_party is not null and my_party = their_party,
    'in_party', their_party is not null,
    'my_party_role', my_role);
end $$;
alter function public.world_character_card(uuid) owner to fn_owner_field;
grant select on public.world_party_members to fn_owner_field;

/* ── 차단한 상대의 귓속말·파티 초대·거래 제안 막기 ── */
grant fn_owner_19141 to postgres with inherit true;
grant fn_owner_19386 to postgres with inherit true;
do $$ declare def text; nd text;
begin
  def := pg_get_functiondef('public.world_chat_send(text, text, text)'::regprocedure);
  if position('world_blocks' in def) = 0 then
    nd := replace(def, 'if target.owner_id is null then raise exception ''해당 캐릭터를 찾을 수 없습니다.''; end if;',
      'if target.owner_id is null then raise exception ''해당 캐릭터를 찾을 수 없습니다.''; end if;
  if exists(select 1 from public.world_blocks b where b.owner_id=target.owner_id and b.blocked_id=uid) then raise exception ''상대가 귓속말을 받지 않습니다.''; end if;');
    if position('world_blocks' in nd) = 0 then raise exception 'world_chat_send 고칠 곳을 찾지 못했습니다.'; end if;
    execute nd;
  end if;

  def := pg_get_functiondef('public.world_party_invite(uuid)'::regprocedure);
  if position('world_blocks' in def) = 0 then
    nd := replace(def, 'if not exists(select 1 from public.world_characters where owner_id=p_invitee_id) then raise exception ''대상 조사원을 찾을 수 없습니다.''; end if;',
      'if not exists(select 1 from public.world_characters where owner_id=p_invitee_id) then raise exception ''대상 조사원을 찾을 수 없습니다.''; end if;
 if exists(select 1 from public.world_blocks b where b.owner_id=p_invitee_id and b.blocked_id=uid) then raise exception ''상대가 초대를 받지 않습니다.''; end if;');
    if position('world_blocks' in nd) = 0 then raise exception 'world_party_invite 고칠 곳을 찾지 못했습니다.'; end if;
    execute nd;
  end if;

  def := pg_get_functiondef('public.world_trade_direct_offer(uuid, jsonb, bigint, jsonb, bigint)'::regprocedure);
  if position('world_blocks' in def) = 0 then
    nd := replace(def, 'if a.location is distinct from b.location then raise exception ''같은 곳에 있는 조사원과만 거래할 수 있습니다.''; end if;',
      'if a.location is distinct from b.location then raise exception ''같은 곳에 있는 조사원과만 거래할 수 있습니다.''; end if;
  if exists (select 1 from public.world_blocks x where x.owner_id = p_to and x.blocked_id = uid) then raise exception ''상대가 거래 제안을 받지 않습니다.''; end if;');
    if position('world_blocks' in nd) = 0 then raise exception 'world_trade_direct_offer 고칠 곳을 찾지 못했습니다.'; end if;
    execute nd;
  end if;
end $$;
grant fn_owner_19141 to postgres with inherit false;
grant fn_owner_19386 to postgres with inherit false;

select 'ok' as result,
  (select count(*) from pg_proc where proname in ('world_friend_request', 'world_friend_respond', 'world_friend_remove', 'world_block_set', 'world_friend_overview')) as functions,
  position('world_blocks' in pg_get_functiondef('public.world_chat_send(text, text, text)'::regprocedure)) > 0 as chat_guard,
  position('world_blocks' in pg_get_functiondef('public.world_party_invite(uuid)'::regprocedure)) > 0 as invite_guard,
  position('world_blocks' in pg_get_functiondef('public.world_trade_direct_offer(uuid, jsonb, bigint, jsonb, bigint)'::regprocedure)) > 0 as trade_guard;
