alter table public.world_item_catalog drop constraint world_item_catalog_category_check;
alter table public.world_item_catalog add constraint world_item_catalog_category_check check (category = any (array['material', 'consumable', 'equipment', 'tool', 'weapon', 'armor', 'quest', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'furniture', 'pet', 'outfit', 'trade']));

create table if not exists public.world_trade_voyages (
  voyage_id uuid primary key default gen_random_uuid(),
  captain_id uuid not null references auth.users(id) on delete cascade,
  mode text not null check (mode in ('direct', 'send')),
  from_port text not null,
  to_port text not null,
  status text not null check (status in ('board', 'sail', 'raid', 'done', 'cancelled')),
  bonus text check (bonus in ('time', 'guard', 'haggle')),
  mates int not null default 0,
  ships uuid[] not null default '{}',
  board_ends timestamptz,
  started_at timestamptz,
  arrives_at timestamptz,
  raid_at timestamptz,
  raid_roll boolean not null default false,
  raid_done boolean not null default false,
  fight_id uuid,
  prices jsonb not null default '{}',
  result jsonb not null default '{}',
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
create index if not exists idx_world_trade_voyages_captain on public.world_trade_voyages(captain_id) where status in ('board', 'sail', 'raid');
create index if not exists idx_world_trade_voyages_fight on public.world_trade_voyages(fight_id) where fight_id is not null;

create table if not exists public.world_trade_board (
  voyage_id uuid not null references public.world_trade_voyages(voyage_id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  primary key (voyage_id, owner_id)
);
create index if not exists idx_world_trade_board_owner on public.world_trade_board(owner_id) where status in ('pending', 'accepted');

create table if not exists public.world_trade_aboard (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  voyage_id uuid not null references public.world_trade_voyages(voyage_id) on delete cascade,
  joined_at timestamptz not null default now()
);
create index if not exists idx_world_trade_aboard_voyage on public.world_trade_aboard(voyage_id);

create table if not exists public.world_ships (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  ship_id uuid not null default gen_random_uuid() unique,
  tier smallint not null default 1 check (tier between 1 and 5),
  durability int not null,
  name text,
  port_id text not null,
  status text not null default 'docked' check (status in ('docked', 'sailing')),
  voyage_id uuid references public.world_trade_voyages(voyage_id) on delete set null,
  sell_port text,
  sell_pct int not null default 0,
  got_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_world_ships_voyage on public.world_ships(voyage_id) where voyage_id is not null;

create table if not exists public.world_ship_parts (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  next_tier smallint not null,
  parts jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

create table if not exists public.world_ship_hold (
  owner_id uuid not null references auth.users(id) on delete cascade,
  good_id text not null references public.world_item_catalog(item_id),
  qty int not null check (qty > 0),
  cost bigint not null default 0,
  primary key (owner_id, good_id)
);
create index if not exists idx_world_ship_hold_good on public.world_ship_hold(good_id);

create table if not exists public.world_trade_seen (
  owner_id uuid not null references auth.users(id) on delete cascade,
  port_id text not null,
  vals jsonb not null default '{}',
  at timestamptz not null default now(),
  primary key (owner_id, port_id)
);

create table if not exists public.world_trade_flow (
  port_id text not null,
  good_id text not null,
  sold numeric not null default 0,
  at timestamptz not null default now(),
  primary key (port_id, good_id)
);

create table if not exists public.world_trade_demand (
  day date primary key,
  port_id text not null,
  name text not null,
  at timestamptz not null default now()
);

create table if not exists public.world_trade_sales (
  owner_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  base_sum int not null default 0,
  gil_sum bigint not null default 0,
  primary key (owner_id, day)
);

do $$
declare t text;
begin
  foreach t in array array['world_trade_voyages', 'world_trade_board', 'world_trade_aboard', 'world_ships', 'world_ship_parts', 'world_ship_hold', 'world_trade_seen',
                           'world_trade_flow', 'world_trade_demand', 'world_trade_sales'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated', t);
  end loop;
end $$;
