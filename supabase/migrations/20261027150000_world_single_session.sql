-- 한 계정은 한 곳에서만 접속한다: 새로 로그인한 브라우저가 "현재 접속"이 되고, 다른 브라우저는 자동으로 로그아웃된다.
-- - 로그인할 때 world_session_claim이 지금 로그인의 session_id(JWT의 session_id)를 기록한다.
-- - 각 화면은 world_session_check로 자기가 현재 접속인지 확인하고, 아니면 스스로 로그아웃한다.
--   기록이 바뀌면 실시간으로 알 수 있도록 world_active_sessions를 실시간 발행 목록에 넣는다.
-- - 로그인할 때 다른 세션의 갱신 토큰도 끊는다(화면 쪽 signOut scope 'others').
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

create table if not exists public.world_active_sessions (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  session_id text not null,
  claimed_at timestamptz not null default now()
);
alter table public.world_active_sessions enable row level security;
drop policy if exists world_active_sessions_read_own on public.world_active_sessions;
create policy world_active_sessions_read_own on public.world_active_sessions for select to authenticated using (owner_id = (select auth.uid()));
revoke all on public.world_active_sessions from anon, authenticated;
grant select on public.world_active_sessions to authenticated;
grant select, insert, update on public.world_active_sessions to fn_owner_field;

-- 방금 로그인한 브라우저를 현재 접속으로 정한다
create or replace function public.world_session_claim()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); sid text := nullif(auth.jwt() ->> 'session_id', '');
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if sid is null then return jsonb_build_object('ok', false); end if;
  insert into public.world_active_sessions(owner_id, session_id, claimed_at) values (uid, sid, now())
  on conflict (owner_id) do update set session_id = excluded.session_id, claimed_at = now();
  return jsonb_build_object('ok', true);
end $$;

-- 이 브라우저가 현재 접속인지 확인한다. 아직 기록이 없으면 이 브라우저를 현재 접속으로 정한다.
create or replace function public.world_session_check()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); sid text := nullif(auth.jwt() ->> 'session_id', ''); cur text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if sid is null then return jsonb_build_object('active', true); end if;
  select session_id into cur from public.world_active_sessions where owner_id = uid;
  if cur is null then
    insert into public.world_active_sessions(owner_id, session_id) values (uid, sid) on conflict (owner_id) do nothing;
    return jsonb_build_object('active', true);
  end if;
  return jsonb_build_object('active', cur = sid);
end $$;

do $$ declare f text;
begin
  foreach f in array array['world_session_claim()', 'world_session_check()'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'world_active_sessions') then
    execute 'alter publication supabase_realtime add table public.world_active_sessions';
  end if;
end $$;

select 'ok' as result,
  (select count(*) from pg_proc where proname in ('world_session_claim', 'world_session_check')) as functions,
  exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'world_active_sessions') as realtime;
