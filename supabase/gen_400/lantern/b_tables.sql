create table if not exists public.world_lanterns (
  id bigint generated always as identity primary key,
  author_id uuid,
  port text not null,
  shape text not null,
  color text not null,
  body text not null,
  reply_to bigint references public.world_lanterns(id) on delete cascade,
  to_id uuid,
  created_at timestamptz not null default now(),
  catcher_id uuid,
  caught_at timestamptz,
  caught_port text,
  removed_at timestamptz,
  removed_by uuid
);
create index if not exists idx_world_lanterns_author on public.world_lanterns(author_id, created_at desc);
create index if not exists idx_world_lanterns_catcher on public.world_lanterns(catcher_id, caught_at desc) where catcher_id is not null;
create index if not exists idx_world_lanterns_to on public.world_lanterns(to_id, created_at desc) where to_id is not null;
create unique index if not exists idx_world_lanterns_reply on public.world_lanterns(reply_to) where reply_to is not null;
create index if not exists idx_world_lanterns_pool on public.world_lanterns(created_at) where reply_to is null and caught_at is null and removed_at is null;

create table if not exists public.world_lantern_book (
  owner_id uuid primary key,
  open text[] not null default '{}',
  last_at timestamptz
);

create table if not exists public.world_lantern_hides (
  viewer_id uuid not null,
  lantern_id bigint not null references public.world_lanterns(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (viewer_id, lantern_id)
);
create index if not exists idx_world_lantern_hides_lantern on public.world_lantern_hides(lantern_id);

alter table public.world_lanterns enable row level security;
alter table public.world_lantern_book enable row level security;
alter table public.world_lantern_hides enable row level security;
revoke all on public.world_lanterns, public.world_lantern_book, public.world_lantern_hides from public, anon, authenticated;
grant select, insert, update, delete on public.world_lanterns, public.world_lantern_book, public.world_lantern_hides to fn_owner_field, service_role;

do $$ declare d text; c text[];
begin
  select pg_get_constraintdef(oid) into d from pg_constraint where conrelid = 'public.world_bug_reports'::regclass and conname = 'world_bug_reports_category_check';
  if d is null or position('''lantern''' in d) > 0 then return; end if;
  select array_agg(m[1]) into c from regexp_matches(d, '''([a-z_]+)''', 'g') m;
  execute 'alter table public.world_bug_reports drop constraint world_bug_reports_category_check';
  execute format('alter table public.world_bug_reports add constraint world_bug_reports_category_check check (category = any (%L::text[]))', c || array['lantern']);
end $$;
