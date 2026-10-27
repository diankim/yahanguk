-- 첫 걸음·처음 안내를 기기마다가 아니라 캐릭터마다 서버에 기억한다(모바일에서 마치면 PC에서도 마친 상태).
-- - 진행(보급·바깥·탐색·채집·토벌·단서)은 서버의 행동 기록(world_events)에서 바로 센다. 화면이 보내는 값은 쓰지 않는다.
-- - 화면 표시 상태(안내를 마쳤는지 · 목록을 접었는지 · 닫았는지 · 도움말에서 다시 열었는지)만 world_tutorial_state에 둔다.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

create table if not exists public.world_tutorial_state (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  flags jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.world_tutorial_state enable row level security;
revoke all on public.world_tutorial_state from anon, authenticated;  -- RPC로만 읽고 쓴다
grant select, insert, update on public.world_tutorial_state to fn_owner_field;

create or replace function public.world_tutorial_snapshot()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); f jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_characters where owner_id = uid) then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select flags into f from public.world_tutorial_state where owner_id = uid;
  return jsonb_build_object(
    'flags', coalesce(f, '{}'::jsonb),
    'saved', f is not null,
    'progress', jsonb_build_object(
      'supply', (select count(*) from public.world_events e where e.actor_id = uid and e.event_type = 'supply'),
      'outside', (select count(*) from public.world_events e where e.actor_id = uid and (e.event_type = 'explore'
                   or (e.event_type = 'travel' and exists (select 1 from public.world_map_regions r where r.region_id = e.payload ->> 'region_id' and not coalesce(r.is_safe_zone, false))))),
      'search', (select count(*) from public.world_events e where e.actor_id = uid and e.event_type = 'explore'),
      'gather', (select count(*) from public.world_events e where e.actor_id = uid and e.event_type = 'gather'),
      'victory', (select count(*) from public.world_events e where e.actor_id = uid and e.event_type = 'combat' and e.payload ->> 'defeated' = 'true'),
      'clue', (select count(*) from public.world_events e where e.actor_id = uid and e.event_type = 'explore' and e.payload ->> 'outcome' = 'clue')));
end $$;

-- 화면 표시 상태 저장: 정해진 네 가지 참·거짓 값만 받는다
create or replace function public.world_tutorial_set(p_flags jsonb)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); clean jsonb := '{}'::jsonb; k text; out jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_characters where owner_id = uid) then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if p_flags is null or jsonb_typeof(p_flags) <> 'object' then raise exception '저장할 값이 올바르지 않습니다.'; end if;
  foreach k in array array['done', 'fold', 'closed', 'reopened'] loop
    if p_flags ? k then
      if jsonb_typeof(p_flags -> k) <> 'boolean' then raise exception '저장할 값이 올바르지 않습니다.'; end if;
      clean := clean || jsonb_build_object(k, p_flags -> k);
    end if;
  end loop;
  insert into public.world_tutorial_state(owner_id, flags) values (uid, clean)
  on conflict (owner_id) do update set flags = public.world_tutorial_state.flags || excluded.flags, updated_at = now()
  returning flags into out;
  return jsonb_build_object('ok', true, 'flags', out);
end $$;

do $$ declare f text;
begin
  foreach f in array array['world_tutorial_snapshot()', 'world_tutorial_set(jsonb)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
grant select on public.world_events, public.world_map_regions to fn_owner_field;

select 'ok' as result,
  (select count(*) from pg_proc where proname in ('world_tutorial_snapshot', 'world_tutorial_set')) as functions;
