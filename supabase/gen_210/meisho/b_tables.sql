create table if not exists public.world_meisho (
  meisho_id text primary key,
  meisho_name text not null unique,
  region_id text not null references public.world_map_regions(region_id),
  node_id uuid not null references public.world_exploration_nodes(node_id) on delete cascade,
  kind text not null check (kind in ('herb', 'wood', 'stone')),
  phase text not null check (phase in ('dawn', 'noon', 'dusk', 'night')),
  weather text not null,
  min_level integer not null,
  description text not null default '',
  sort integer not null default 0,
  active boolean not null default true);
create index if not exists idx_world_meisho_node on public.world_meisho(node_id);
create index if not exists idx_world_meisho_region on public.world_meisho(region_id);

create table if not exists public.world_meisho_finds (
  owner_id uuid not null,
  meisho_id text not null references public.world_meisho(meisho_id) on delete cascade,
  found_at timestamptz not null default now(),
  dug_at timestamptz,
  dig_count integer not null default 0,
  soil_day date,
  soil_count integer not null default 0,
  primary key (owner_id, meisho_id));
create index if not exists idx_world_meisho_finds_meisho on public.world_meisho_finds(meisho_id);

alter table public.world_meisho enable row level security;
alter table public.world_meisho_finds enable row level security;
revoke all on public.world_meisho, public.world_meisho_finds from anon, authenticated;
do $g$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' loop
    execute format('grant select on public.world_meisho to %I', x);
    execute format('grant select, insert, update, delete on public.world_meisho_finds to %I', x);
  end loop;
end $g$;
