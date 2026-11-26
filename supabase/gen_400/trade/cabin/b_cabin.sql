create table if not exists public.world_ship_cabins (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  items jsonb not null default '[]',
  wall jsonb not null default '[]',
  paper text,
  ground text,
  updated_at timestamptz not null default now()
);
alter table public.world_ship_cabins enable row level security;
revoke all on table public.world_ship_cabins from anon, authenticated;

create or replace function public.world_cabin_fit(p_t jsonb)
 returns boolean language sql immutable set search_path to '' as $f$
  select case
    when p_t is null then false
    when coalesce((p_t ->> 'ship_only')::boolean, false) then true
    when p_t ->> 'cat' = any (array(select jsonb_array_elements_text(public.world_cabin_rules() -> 'fit' -> 'no_cat'))) then false
    when p_t ->> 'kind' in ('floor', 'rug', 'surface') then coalesce((p_t ->> 'w')::int, 1) * coalesce((p_t ->> 'd')::int, 1) <= (public.world_cabin_rules() -> 'fit' ->> 'floor_cells')::int
    when p_t ->> 'kind' = 'wall' then coalesce((p_t ->> 'ww')::numeric, 1) <= (public.world_cabin_rules() -> 'fit' ->> 'wall_w')::numeric
      and coalesce((p_t ->> 'wh')::numeric, 0) <= (public.world_cabin_rules() -> 'fit' ->> 'wall_h')::numeric
      and not (coalesce(p_t ->> 'wall', 'deco') = any (array(select jsonb_array_elements_text(public.world_cabin_rules() -> 'fit' -> 'no_wall'))))
    when p_t ->> 'kind' in ('paper', 'ground') then true
    else false end
$f$;

create or replace function public.world_cabin_traits_trg()
 returns trigger language plpgsql set search_path to '' as $f$
begin
  if new.category = 'furniture' and new.equipment_traits is not null then
    new.equipment_traits := (new.equipment_traits - 'cabin') || case when public.world_cabin_fit(new.equipment_traits) then '{"cabin": true}'::jsonb else '{}'::jsonb end;
  end if;
  return new;
end $f$;
drop trigger if exists trg_world_cabin_traits on public.world_item_catalog;
create trigger trg_world_cabin_traits before insert or update of equipment_traits, category on public.world_item_catalog
  for each row execute function public.world_cabin_traits_trg();

create or replace function public.world_cabin_size(p_uid uuid)
 returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select coalesce((select (public.world_trade_ship_rule(s.tier) ->> 'cabin')::int from public.world_ships s where s.owner_id = p_uid), 0)
$f$;

create or replace function public.world_cabin_cap(p_size int)
 returns int language sql stable set search_path to 'pg_catalog', 'public' as $f$
  select coalesce((public.world_cabin_rules() -> 'cap' ->> p_size::text)::int, 0)
$f$;

create or replace function public.world_cabin_state(p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare cb public.world_ship_cabins%rowtype; d jsonb := public.world_cabin_rules() -> 'default';
begin
  select * into cb from public.world_ship_cabins where owner_id = p_uid;
  if not found then return jsonb_build_object('items', '[]'::jsonb, 'wall', '[]'::jsonb, 'paper', d ->> 'paper', 'ground', d ->> 'ground'); end if;
  return jsonb_build_object('items', cb.items, 'wall', cb.wall, 'paper', cb.paper, 'ground', cb.ground);
end $f$;

create or replace function public.world_cabin_edit_block(p_uid uuid)
 returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare c public.world_characters%rowtype; s public.world_ships%rowtype; here text; m text;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if not found then return '캐릭터를 먼저 만드세요.'; end if;
  select * into s from public.world_ships where owner_id = p_uid;
  if not found then return '아직 배가 없습니다. 조선소가 있는 항구에서 나룻배를 받으세요.'; end if;
  if public.world_cabin_size(p_uid) <= 0 then return public.world_cabin_rules() ->> 'small'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null then return '전투불능 상태에서는 객실을 꾸밀 수 없습니다.'; end if;
  m := public.world_busy_msg(p_uid, '객실 꾸미기', false);
  if m is not null then return m; end if;
  if exists (select 1 from public.world_character_statuses x where x.owner_id = p_uid and x.status_key = 'yohwa_seal' and x.expires_at > now()) then return '봉인 해독 중에는 객실을 꾸밀 수 없습니다.'; end if;
  if s.status <> 'docked' then return '배가 물길에 나가 있어 객실을 꾸밀 수 없습니다.'; end if;
  here := public.world_trade_here(p_uid);
  if here is distinct from s.port_id then return '객실은 배가 대 있는 ' || coalesce(public.world_trade_port(s.port_id) ->> 'name', '항구') || '에서 꾸밀 수 있습니다. 바깥에서는 구경만 됩니다.'; end if;
  return null;
end $f$;

create or replace function public.world_cabin_can_view(p_viewer uuid, p_owner uuid)
 returns boolean language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare s public.world_ships%rowtype; pa uuid; pb uuid;
begin
  if p_viewer = p_owner then return true; end if;
  select party_id into pa from public.world_party_members where owner_id = p_viewer;
  select party_id into pb from public.world_party_members where owner_id = p_owner;
  if pa is null or pa is distinct from pb then return false; end if;
  select * into s from public.world_ships where owner_id = p_owner;
  if not found then return false; end if;
  if s.status = 'docked' and not public.world_trade_sailing(p_viewer) and public.world_trade_here(p_viewer) = s.port_id then return true; end if;
  return exists (select 1 from public.world_trade_aboard a join public.world_trade_voyages v on v.voyage_id = a.voyage_id
                  where a.owner_id = p_viewer and v.status in ('board', 'sail', 'raid') and s.ship_id = any (v.ships));
end $f$;

create or replace function public.world_cabin_view(p_owner uuid default null)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); own uuid; nm text; s public.world_ships%rowtype; sz int; cap int; st jsonb; me boolean; c public.world_characters%rowtype;
  bag jsonb := '{}'::jsonb; store jsonb := '{}'::jsonb; home uuid; nx jsonb; sr jsonb; keys text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  own := coalesce(p_owner, uid); me := own = uid;
  select character_name into nm from public.world_characters where owner_id = own;
  if nm is null then raise exception '알 수 없는 조사원입니다.'; end if;
  select * into s from public.world_ships where owner_id = own;
  if not found then
    if not me then raise exception '%님은 아직 배가 없습니다.', nm; end if;
    return jsonb_build_object('open', false, 'cabin', true, 'why', 'no_ship', 'owner_id', own, 'owner_name', nm);
  end if;
  if not public.world_cabin_can_view(uid, own) then
    raise exception '남의 객실은 같은 파티원이 그 배가 대 있는 항구에 함께 있거나 그 배를 함께 타고 갈 때 구경할 수 있습니다.' using hint = 'cabin_view';
  end if;
  sr := public.world_trade_ship_rule(s.tier); sz := (sr ->> 'cabin')::int; cap := public.world_cabin_cap(sz);
  select jsonb_build_object('tier', x.tier, 'name', x.name, 'size', x.cabin, 'lv', x.lv) into nx
    from jsonb_to_recordset(public.world_trade_rules() -> 'ships') x(tier int, name text, cabin int, lv int) where x.tier > s.tier and x.cabin > sz order by x.tier limit 1;
  if sz <= 0 then
    return jsonb_build_object('open', false, 'cabin', true, 'why', 'small', 'owner_id', own, 'owner_name', nm, 'ship', public.world_trade_ship_view(own), 'next', nx);
  end if;
  st := public.world_cabin_state(own);
  if me then
    select * into c from public.world_characters where owner_id = uid;
    select coalesce(jsonb_object_agg(i.item_id, (c.inventory ->> i.item_id)::int), '{}'::jsonb) into bag
      from public.world_item_catalog i where i.category = 'furniture' and coalesce((c.inventory ->> i.item_id)::int, 0) > 0;
    home := public.world_housing_home(uid);
    store := coalesce((select items from public.world_housing_store where owner_id = home), '{}'::jsonb);
  end if;
  keys := array(select x ->> 'k' from jsonb_array_elements(st -> 'items') x) || array(select key from jsonb_each(store));
  return jsonb_build_object('open', true, 'cabin', true, 'owner_id', own, 'owner_name', nm, 'role', case when me then 'owner' end,
    'edit_block', case when me then public.world_cabin_edit_block(uid) end, 'ship', public.world_trade_ship_view(own), 'next', nx,
    'size', sz, 'cap', cap, 'kind_caps', '[4, 3, 2, 1, 1]'::jsonb,
    'rooms', jsonb_build_array(jsonb_build_object('room', 0, 'name', public.world_cabin_rules() ->> 'name', 'open', true, 'size', sz, 'cap', cap, 'paper', st ->> 'paper', 'ground', st ->> 'ground')),
    'items', st -> 'items', 'wall', st -> 'wall', 'paper', st ->> 'paper', 'ground', st ->> 'ground',
    'bag', case when me then bag end, 'store', case when me then store end, 'store_cap', case when me then public.world_housing_store_cap_of(home) end,
    'furns', public.world_furn_room(own, uid, keys), 'drawings', public.world_drawing_room(uid, st -> 'wall'),
    'pets', '[]'::jsonb, 'avatars', '[]'::jsonb, 'kin', '[]'::jsonb);
end $f$;

create or replace function public.world_cabin_save(p_state jsonb)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); why text; c public.world_characters%rowtype; s public.world_ships%rowtype; sz int; home uuid; old jsonb; lay jsonb; sw jsonb;
  v_items jsonb := coalesce(p_state -> 'items', '[]'::jsonb); v_wall jsonb := coalesce(p_state -> 'wall', '[]'::jsonb);
  v_paper text := nullif(p_state ->> 'paper', ''); v_ground text := nullif(p_state ->> 'ground', '');
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  why := public.world_cabin_edit_block(uid);
  if why is not null then raise exception '%', why using hint = 'cabin_block'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  select * into s from public.world_ships where owner_id = uid for update;
  sz := public.world_cabin_size(uid);
  if jsonb_typeof(v_items) <> 'array' or jsonb_typeof(v_wall) <> 'array' then raise exception '배치 형식이 올바르지 않습니다.'; end if;
  v_wall := public.world_drawing_wall_clean(uid, uid, (select coalesce(jsonb_agg(x - 'm'), '[]'::jsonb) from jsonb_array_elements(v_wall) x));
  old := public.world_cabin_state(uid);
  perform 1 from public.world_ship_cabins where owner_id = uid for update;
  lay := public.world_furn_layout(v_items, v_wall, v_paper, v_ground, sz, public.world_cabin_cap(sz), 'cabin', 1, 0);
  home := public.world_housing_home(uid);
  sw := public.world_furn_swap(uid, home, c.inventory,
    public.world_housing_counts(old -> 'items', old -> 'wall', old ->> 'paper', old ->> 'ground'), lay -> 'counts', case when home <> uid then 'cabin' end);
  insert into public.world_ship_cabins(owner_id, items, wall, paper, ground, updated_at) values (uid, lay -> 'items', lay -> 'wall', v_paper, v_ground, now())
  on conflict (owner_id) do update set items = excluded.items, wall = excluded.wall, paper = excluded.paper, ground = excluded.ground, updated_at = now();
  update public.world_housing_store set items = sw -> 'st', updated_at = now() where owner_id = home;
  if (sw ->> 'bag')::boolean then update public.world_characters set inventory = sw -> 'inv', updated_at = now() where owner_id = uid; end if;
  return public.world_cabin_view(null);
end $f$;

create or replace function public.world_cabin_fit_size(p_uid uuid)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare cb public.world_ship_cabins%rowtype; sz int := public.world_cabin_size(p_uid); keep_i jsonb := '[]'::jsonb; keep_w jsonb := '[]'::jsonb; out_i jsonb := '[]'::jsonb; out_w jsonb := '[]'::jsonb;
  x jsonb; t jsonb; w int; d int; home uuid; k text; n int;
begin
  select * into cb from public.world_ship_cabins where owner_id = p_uid for update;
  if not found then return; end if;
  for x in select value from jsonb_array_elements(cb.items) loop
    select equipment_traits into t from public.world_item_catalog where item_id = 'hf_' || (x ->> 'k');
    w := coalesce((t ->> 'w')::int, 1); d := coalesce((t ->> 'd')::int, 1);
    if coalesce((x ->> 'r')::int, 0) % 2 = 1 then n := w; w := d; d := n; end if;
    if (x ->> 'x')::int + w > sz or (x ->> 'y')::int + d > sz then out_i := out_i || jsonb_build_array(x); else keep_i := keep_i || jsonb_build_array(x); end if;
  end loop;
  for x in select value from jsonb_array_elements(cb.wall) loop
    select equipment_traits into t from public.world_item_catalog where item_id = 'hf_' || (x ->> 'k');
    if (x ->> 't')::numeric + coalesce((t ->> 'ww')::numeric, 1) > sz then out_w := out_w || jsonb_build_array(x); else keep_w := keep_w || jsonb_build_array(x); end if;
  end loop;
  if sz <= 0 then out_i := cb.items; out_w := cb.wall; keep_i := '[]'::jsonb; keep_w := '[]'::jsonb; end if;
  if out_i = '[]'::jsonb and out_w = '[]'::jsonb then return; end if;
  home := public.world_housing_home(p_uid);
  insert into public.world_housing_store(owner_id) values (home) on conflict (owner_id) do nothing;
  for k, n in select key, value::int from jsonb_each_text(public.world_housing_counts(out_i, out_w, null, null)) loop
    update public.world_housing_store set items = public.world_inv_add(items, k, n), updated_at = now() where owner_id = home;
    if home <> p_uid then perform public.world_housing_contrib(home, k, n); end if;
  end loop;
  update public.world_ship_cabins set items = keep_i, wall = keep_w, updated_at = now() where owner_id = p_uid;
end $f$;

create or replace function public.world_cabin_roll(p_uid uuid, p_note text)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare got text; p numeric := (public.world_cabin_rules() -> 'sources' -> 'raid' ->> 'p')::numeric;
begin
  if p is null or p <= 0 or random() >= p then return; end if;
  select item_id into got from public.world_furniture_sources where source = public.world_cabin_rules() -> 'sources' -> 'raid' ->> 'key' and chance > 0
   order by -ln(greatest(random(), 1e-9)) / chance limit 1;
  if got is not null then perform public.world_housing_grant(p_uid, got, 1, p_note, false); end if;
end $f$;

create or replace function public.world_cabin_voyage(p_uid uuid, p_from text, p_to text)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  if exists (select 1 from jsonb_array_elements(public.world_trade_rules() -> 'cross') x
              where (x ->> 0 = p_from and x ->> 1 = p_to) or (x ->> 0 = p_to and x ->> 1 = p_from)) then
    perform public.world_housing_grant_once(p_uid, public.world_cabin_rules() -> 'sources' -> 'cross' ->> 'key', public.world_cabin_rules() -> 'sources' -> 'cross' ->> 'note');
  end if;
end $f$;

select pg_temp.yh_cb_share('public.world_cabin_fit(jsonb)');
select pg_temp.yh_cb_share('public.world_cabin_size(uuid)');
select pg_temp.yh_cb_share('public.world_cabin_cap(int)');
select pg_temp.yh_cb_share('public.world_cabin_state(uuid)');
select pg_temp.yh_cb_share('public.world_cabin_edit_block(uuid)');
select pg_temp.yh_cb_share('public.world_cabin_can_view(uuid, uuid)');
select pg_temp.yh_cb_share('public.world_cabin_fit_size(uuid)');
select pg_temp.yh_cb_share('public.world_cabin_roll(uuid, text)');
select pg_temp.yh_cb_share('public.world_cabin_voyage(uuid, text, text)');
revoke all on function public.world_cabin_traits_trg() from public, anon, authenticated;
revoke all on function public.world_cabin_view(uuid) from public, anon;
grant execute on function public.world_cabin_view(uuid) to authenticated, service_role;
revoke all on function public.world_cabin_save(jsonb) from public, anon;
grant execute on function public.world_cabin_save(jsonb) to authenticated, service_role;

select pg_temp.yh_fix('world_trade_raid_end(uuid)', array[
  $q$  won := st = 'won';$q$,
  $q$  won := st = 'won';
  if won then
    for u in select a.owner_id from public.world_trade_aboard a where a.voyage_id = v.voyage_id order by a.owner_id loop
      perform public.world_cabin_roll(u, public.world_cabin_rules() -> 'sources' -> 'raid' ->> 'note');
    end loop;
  end if;$q$]);
select pg_temp.yh_fix('world_trade_finish(uuid)', array[
  $q$      perform public.world_trade_note(u, 'trade_arrive', '배가 닿음',$q$,
  $q$      perform public.world_cabin_voyage(u, v.from_port, v.to_port);
      perform public.world_trade_note(u, 'trade_arrive', '배가 닿음',$q$]);
select pg_temp.yh_fix('world_trade_ship_upgrade()', array[
  $q$  delete from public.world_ship_parts where owner_id = uid;$q$,
  $q$  delete from public.world_ship_parts where owner_id = uid;
  perform public.world_cabin_fit_size(uid);$q$]);
select pg_temp.yh_fix('world_character_purge(uuid)', array[
  $q$  delete from public.world_ships where owner_id = p_uid;$q$,
  $q$  delete from public.world_ship_cabins where owner_id = p_uid;
  delete from public.world_ships where owner_id = p_uid;$q$]);
