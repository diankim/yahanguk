create table if not exists public.world_realm_bonds (
  owner_id uuid not null references auth.users(id) on delete cascade,
  realm text not null,
  pts numeric(10,2) not null default 0,
  tokens numeric(10,2) not null default 0,
  stage smallint not null default 1,
  story smallint not null default 1,
  day date,
  day_pts numeric(8,2) not null default 0,
  opened_at timestamptz not null default now(),
  primary key (owner_id, realm)
);

create table if not exists public.world_realm_bond_claims (
  owner_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  realm text not null,
  req_key text not null,
  primary key (owner_id, day, realm, req_key)
);

alter table public.world_realm_bonds enable row level security;
alter table public.world_realm_bond_claims enable row level security;
revoke all on public.world_realm_bonds, public.world_realm_bond_claims from public, anon, authenticated;
grant select, insert, update, delete on public.world_realm_bonds, public.world_realm_bond_claims to fn_owner_field, service_role;

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade)
select t ->> 'key', t ->> 'name', 'flag', t ->> 'desc', t ->> 'cond', '{}'::jsonb, true, false, t -> 'rule', 3600 + o::int,
  public.world_realm_bond_rules() ->> 'title_cat', (t ->> 'grade')::int
from jsonb_array_elements(public.world_realm_bond_rules() -> 'titles') with ordinality z(t, o)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text,
  hidden = excluded.hidden, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade)
select t ->> 'key', t ->> 'name', 'flag', (public.world_realm_bond_rules() -> 'realms' -> (t ->> 'realm') ->> 'name') || ' 사람들이 이름을 기억해 주는 손님이 되었습니다.',
  (public.world_realm_bond_rules() -> 'realms' -> (t ->> 'realm') ->> 'name') || ' 권역 비고에서 인연 표로 받는다(권역 인연 2단계)', '{}'::jsonb, true, false, null, 3620 + o::int,
  public.world_realm_bond_rules() ->> 'title_cat', 2
from jsonb_array_elements(public.world_realm_bond_rules() -> 'vault_titles') with ordinality z(t, o)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text,
  hidden = excluded.hidden, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;
