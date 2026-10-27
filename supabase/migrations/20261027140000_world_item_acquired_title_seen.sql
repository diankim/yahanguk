-- 1) 가방 "획득순" 정렬: 물품 수량이 늘어날 때마다 마지막으로 얻은 시각을 world_item_acquired에 남긴다.
--    가방을 바꾸는 모든 경로(전리품·채집·구매·제작·거래·보급 등)를 놓치지 않도록 world_characters.inventory가 바뀔 때 트리거로 기록한다.
--    이 기능 전에 갖고 있던 물품은 기록이 없으므로 "오래전에 얻은 것"으로 본다.
-- 2) 새 칭호 표시(빨간 점): world_character_titles.seen_at이 비어 있으면 새 칭호다. 칭호 화면을 열면 world_title_mark_seen으로 확인 처리한다.
--    이미 갖고 있던 칭호는 모두 확인한 것으로 둔다.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

create table if not exists public.world_item_acquired (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  item_id text not null,
  acquired_at timestamptz not null default now(),
  primary key (owner_id, item_id)
);
alter table public.world_item_acquired enable row level security;
drop policy if exists world_item_acquired_read_own on public.world_item_acquired;
create policy world_item_acquired_read_own on public.world_item_acquired for select to authenticated using (owner_id = (select auth.uid()));
revoke all on public.world_item_acquired from anon, authenticated;
grant select on public.world_item_acquired to authenticated;

create or replace function public.world_track_item_acquired()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  insert into public.world_item_acquired(owner_id, item_id, acquired_at)
  select new.owner_id, n.key, now()
    from jsonb_each_text(coalesce(new.inventory, '{}'::jsonb)) n
   where n.value ~ '^-?[0-9]+$' and n.value::int > coalesce(nullif(coalesce(old.inventory, '{}'::jsonb) ->> n.key, '')::int, 0)
  on conflict (owner_id, item_id) do update set acquired_at = excluded.acquired_at;
  return null;
end $$;
revoke all on function public.world_track_item_acquired() from public, anon, authenticated;
drop trigger if exists trg_world_track_item_acquired on public.world_characters;
create trigger trg_world_track_item_acquired after update of inventory on public.world_characters
  for each row when (new.inventory is distinct from old.inventory) execute function public.world_track_item_acquired();

/* ── 새 칭호 ─────────────────────────────────────────── */
alter table public.world_character_titles add column if not exists seen_at timestamptz;
-- 이 기능 전에 얻은 칭호는 모두 확인한 것으로 둔다(처음 실행할 때 한 번만, 표시용 표로 기억)
do $$ begin
  if to_regclass('public.world_title_seen_migrated') is null then
    update public.world_character_titles set seen_at = coalesce(earned_at, now()) where seen_at is null;
    create table public.world_title_seen_migrated (done_at timestamptz not null default now());
    alter table public.world_title_seen_migrated enable row level security;
    revoke all on public.world_title_seen_migrated from anon, authenticated;
    insert into public.world_title_seen_migrated default values;
  end if;
end $$;

create or replace function public.world_title_mark_seen(p_keys text[] default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); n int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  update public.world_character_titles set seen_at = now()
   where owner_id = uid and seen_at is null and (p_keys is null or title_key = any (p_keys));
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'seen', n);
end $$;
alter function public.world_title_mark_seen(text[]) owner to fn_owner_field;
revoke all on function public.world_title_mark_seen(text[]) from public, anon;
grant execute on function public.world_title_mark_seen(text[]) to authenticated;
grant select, update on public.world_character_titles to fn_owner_field;

-- 칭호 목록에 새 칭호 여부(new)를 더한다
do $$ declare def text; nd text;
begin
  def := pg_get_functiondef('public.world_title_snapshot()'::regprocedure);
  if position('''new''' in def) = 0 then
    nd := replace(def, '''earned'', ct.owner_id IS NOT NULL,', '''earned'', ct.owner_id IS NOT NULL, ''new'', ct.owner_id IS NOT NULL AND ct.seen_at IS NULL,');
    if position('''new''' in nd) = 0 then raise exception 'world_title_snapshot 고칠 곳을 찾지 못했습니다.'; end if;
    execute nd;
  end if;
end $$;

select 'ok' as result,
  exists (select 1 from pg_trigger where tgname = 'trg_world_track_item_acquired') as item_trigger,
  exists (select 1 from information_schema.columns where table_name = 'world_character_titles' and column_name = 'seen_at') as seen_column,
  (select count(*) from public.world_character_titles where seen_at is null) as unseen_titles,
  position('''new''' in pg_get_functiondef('public.world_title_snapshot()'::regprocedure)) > 0 as snapshot_new;
