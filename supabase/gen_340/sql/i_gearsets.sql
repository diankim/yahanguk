create table if not exists public.world_gear_sets (
  owner_id uuid not null,
  n integer not null check (n between 1 and 20),
  name text not null,
  items jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (owner_id, n)
);
alter table public.world_gear_sets enable row level security;
revoke all on public.world_gear_sets from anon, authenticated;
grant select, insert, update, delete on public.world_gear_sets to fn_owner_field;

create or replace function public.world_gear_set_rules() returns jsonb language sql immutable as $$
  select jsonb_build_object('base', 4, 'max', 10, 'rank', 15, 'name_max', 12)
$$;

create or replace function public.world_gear_set_cap(p_uid uuid) returns integer language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare r jsonb := public.world_gear_set_rules(); n int;
begin
  select count(*) into n from public.world_characters c, unnest(public.world_combat_lines()) l
   where c.owner_id = p_uid and coalesce((c.skill_progress -> l ->> 'rank')::int, 1) >= (r ->> 'rank')::int;
  return least((r ->> 'max')::int, (r ->> 'base')::int + coalesce(n, 0));
end $$;

create or replace function public.world_gear_set_list() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object('cap', public.world_gear_set_cap(uid), 'rules', public.world_gear_set_rules(),
    'sets', coalesce((select jsonb_agg(jsonb_build_object('n', s.n, 'name', s.name, 'items', s.items, 'at', s.updated_at) order by s.n) from public.world_gear_sets s where s.owner_id = uid), '[]'::jsonb));
end $$;

create or replace function public.world_gear_set_save(p_n integer, p_name text) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); nm text := btrim(coalesce(p_name, '')); its jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_n is null or p_n < 1 or p_n > public.world_gear_set_cap(uid) then raise exception '쓸 수 없는 세트 칸입니다.'; end if;
  if nm = '' then nm := coalesce((select s.name from public.world_gear_sets s where s.owner_id = uid and s.n = p_n), '세트 ' || p_n); end if;
  if char_length(nm) > (public.world_gear_set_rules() ->> 'name_max')::int then raise exception '세트 이름은 %자까지입니다.', public.world_gear_set_rules() ->> 'name_max'; end if;
  select coalesce(jsonb_object_agg(e.slot, e.item_id), '{}'::jsonb) into its from public.world_character_equipment e where e.owner_id = uid;
  insert into public.world_gear_sets(owner_id, n, name, items, updated_at) values (uid, p_n, nm, its, now())
  on conflict (owner_id, n) do update set name = excluded.name, items = excluded.items, updated_at = now();
  return jsonb_build_object('ok', true, 'n', p_n, 'name', nm, 'items', its);
end $$;

create or replace function public.world_gear_set_rename(p_n integer, p_name text) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); nm text := btrim(coalesce(p_name, ''));
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if nm = '' or char_length(nm) > (public.world_gear_set_rules() ->> 'name_max')::int then raise exception '세트 이름은 1~%자입니다.', public.world_gear_set_rules() ->> 'name_max'; end if;
  update public.world_gear_sets set name = nm, updated_at = now() where owner_id = uid and n = p_n;
  if not found then raise exception '저장한 세트가 없습니다.'; end if;
  return jsonb_build_object('ok', true, 'n', p_n, 'name', nm);
end $$;

create or replace function public.world_gear_set_clear(p_n integer) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  delete from public.world_gear_sets where owner_id = uid and n = p_n;
  return jsonb_build_object('ok', true, 'n', p_n);
end $$;

create or replace function public.world_gear_set_apply(p_n integer) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); s public.world_gear_sets%rowtype; inv jsonb; k text; v text; pick text; done jsonb := '[]'::jsonb; skip jsonb := '[]'::jsonb; msg text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into s from public.world_gear_sets where owner_id = uid and n = p_n;
  if not found then raise exception '저장한 세트가 없습니다.'; end if;
  for k, v in select key, value #>> '{}' from jsonb_each(s.items) loop
    if exists (select 1 from public.world_character_equipment e where e.owner_id = uid and e.slot = k and e.item_id = v) then continue; end if;
    select inventory into inv from public.world_characters where owner_id = uid;
    pick := case when coalesce((inv ->> v)::int, 0) > 0 then v
                 when v like '%\_hq' and coalesce((inv ->> public.world_item_base(v))::int, 0) > 0 then public.world_item_base(v)
                 when v not like '%\_hq' and coalesce((inv ->> (v || '_hq'))::int, 0) > 0 then v || '_hq' end;
    if pick is null then
      skip := skip || jsonb_build_object('slot', k, 'item', v, 'why', '가진 물품이 없습니다.'); continue;
    end if;
    begin
      perform public.world_equip_item(pick);
      done := done || jsonb_build_object('slot', k, 'item', pick);
    exception when others then
      get stacked diagnostics msg = message_text;
      skip := skip || jsonb_build_object('slot', k, 'item', pick, 'why', msg);
    end;
  end loop;
  return jsonb_build_object('ok', true, 'n', p_n, 'name', s.name, 'equipped', done, 'skipped', skip);
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.world_gear_set_cap(uuid)', 'public.world_gear_set_list()', 'public.world_gear_set_save(integer, text)', 'public.world_gear_set_rename(integer, text)',
                           'public.world_gear_set_clear(integer)', 'public.world_gear_set_apply(integer)'] loop
    perform pg_temp.yh_own(f, 'fn_owner_field');
    perform pg_temp.yh_share(f);
  end loop;
end $$;
grant execute on function public.world_gear_set_list(), public.world_gear_set_save(integer, text), public.world_gear_set_rename(integer, text),
  public.world_gear_set_clear(integer), public.world_gear_set_apply(integer) to authenticated;
grant execute on function public.world_gear_set_rules() to authenticated;

select pg_temp.yh_fix('world_character_purge', array[$q$delete from public.world_title_presets where owner_id = p_uid;$q$,
  $q$delete from public.world_title_presets where owner_id = p_uid;
  delete from public.world_gear_sets where owner_id = p_uid;$q$]);
