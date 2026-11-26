create table if not exists public.world_hfeast_tables (
  table_id uuid primary key default gen_random_uuid(),
  port_id text not null,
  slot_at timestamptz not null,
  status text not null default 'fill' check (status in ('fill', 'open')),
  n int not null default 0,
  kind text check (kind in ('meat', 'soban', 'sea')),
  opened_at timestamptz,
  eat_until timestamptz,
  created_at timestamptz not null default now(),
  unique (port_id, slot_at)
);
create index if not exists idx_world_hfeast_tables_open on public.world_hfeast_tables(port_id, eat_until) where status = 'open';

create table if not exists public.world_hfeast_bowls (
  table_id uuid not null references public.world_hfeast_tables(table_id) on delete cascade,
  n smallint not null check (n between 1 and 50),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  item_id text not null,
  hq boolean not null default false,
  kind text not null check (kind in ('meat', 'soban', 'sea')),
  at timestamptz not null default now(),
  primary key (table_id, n)
);
create index if not exists idx_world_hfeast_bowls_owner on public.world_hfeast_bowls(owner_id);
create index if not exists idx_world_hfeast_bowls_table_owner on public.world_hfeast_bowls(table_id, owner_id);

create table if not exists public.world_hfeast_eats (
  table_id uuid not null references public.world_hfeast_tables(table_id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  giver boolean not null default false,
  at timestamptz not null default now(),
  primary key (table_id, owner_id)
);
create index if not exists idx_world_hfeast_eats_owner on public.world_hfeast_eats(owner_id);

alter table public.world_hfeast_tables enable row level security;
alter table public.world_hfeast_bowls enable row level security;
alter table public.world_hfeast_eats enable row level security;
revoke all on public.world_hfeast_tables, public.world_hfeast_bowls, public.world_hfeast_eats from anon, authenticated;
grant select, insert, update, delete on public.world_hfeast_tables, public.world_hfeast_bowls, public.world_hfeast_eats to fn_owner_field, service_role;
