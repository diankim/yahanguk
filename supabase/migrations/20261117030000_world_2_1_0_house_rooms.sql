lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

alter table public.world_housing add column if not exists rooms jsonb not null default '{}'::jsonb;
alter table public.world_housing add column if not exists pet_room smallint not null default 0;
alter table public.world_housing add column if not exists look_room smallint not null default 0;
alter table public.world_housing drop constraint if exists world_housing_pet_room_check;
alter table public.world_housing add constraint world_housing_pet_room_check check (pet_room between 0 and 2);
alter table public.world_housing drop constraint if exists world_housing_look_room_check;
alter table public.world_housing add constraint world_housing_look_room_check check (look_room between 0 and 2);

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, equipment_traits, tradeable, reference_price, stack_size)
values ('hf_numaru_stair', '누마루 계단', 'furniture', 4,
  '별채 가구 · 계단. 안채 바닥에 놓으면 2층 누마루로 오를 수 있습니다. 2층을 열 때 곳간으로 들어옵니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.',
  false, '{"hk": "numaru_stair", "kind": "floor", "w": 1, "d": 2, "top": 0, "cat": "계단", "grade": 4}'::jsonb, false, 1200, 1)
on conflict (item_id) do nothing;

create or replace function public.world_housing_room_rules()
 returns jsonb language sql immutable set search_path to ''
as $function$
  select '{
    "names": ["안채", "옆방", "2층"],
    "cap": {"6": 15, "7": 20, "8": 26, "9": 32},
    "store": {"base": 30, "per_size": 5, "per_room": 10},
    "stair": "numaru_stair",
    "rooms": [
      {"steps": {
        "7": {"gil": 2500, "level": 15, "items": {"lumber": 10}},
        "8": {"gil": 6000, "level": 20, "items": {"reinforced_lumber": 4, "lacquer": 6}},
        "9": {"gil": 15000, "level": 25, "items": {"reinforced_lumber": 6, "spirit_bark": 4, "jade_shard": 2}}}},
      {"after": {"room": 0, "size": 9}, "steps": {
        "6": {"gil": 18000, "level": 28, "items": {"reinforced_lumber": 16, "spirit_bark": 12, "lacquer": 20}},
        "7": {"gil": 21000, "level": 28, "items": {"reinforced_lumber": 20, "spirit_bark": 16, "jade_shard": 6}},
        "8": {"gil": 24000, "level": 28, "items": {"steel_ingot": 12, "moonless_silk": 8, "jade_shard": 8}},
        "9": {"gil": 28000, "level": 28, "items": {"gwiheo_iron": 12, "moonless_silk": 12, "mz_wood": 4}}}},
      {"after": {"room": 1}, "stair": true, "steps": {
        "6": {"gil": 32000, "level": 32, "items": {"reinforced_lumber": 24, "gwiheo_iron": 12, "lacquer": 30}},
        "7": {"gil": 36000, "level": 32, "items": {"gwiheo_iron": 16, "yoin_blood": 8, "moonless_silk": 12}},
        "8": {"gil": 40000, "level": 32, "items": {"gwiheo_pearl": 6, "yoin_blood": 12, "mz_stone": 4}},
        "9": {"gil": 45000, "level": 32, "items": {"gwiheo_pearl": 10, "mz_wood": 6, "mz_stone": 6, "mz_herb": 6}}}}
    ]
  }'::jsonb
$function$;
select pg_temp.yh_share('public.world_housing_room_rules()');
grant execute on function public.world_housing_room_rules() to postgres;

create or replace function public.world_housing_cap(p_size integer)
 returns integer language sql immutable set search_path to ''
as $function$ select coalesce((public.world_housing_room_rules() -> 'cap' ->> coalesce(p_size, 6)::text)::int, 32) $function$;

create or replace function public.world_housing_store_cap(p_size integer)
 returns integer language sql immutable set search_path to ''
as $function$
  select ((public.world_housing_room_rules() -> 'store' ->> 'base')::int + (public.world_housing_room_rules() -> 'store' ->> 'per_size')::int * greatest(0, coalesce(p_size, 6) - 6))::int
$function$;

create or replace function public.world_housing_in_room(p_arr jsonb, p_room integer, p_in boolean default true)
 returns jsonb language sql immutable set search_path to ''
as $function$
  select coalesce(jsonb_agg(x order by o), '[]'::jsonb)
    from jsonb_array_elements(case when jsonb_typeof(p_arr) = 'array' then p_arr else '[]'::jsonb end) with ordinality e(x, o)
   where (case when jsonb_typeof(x -> 'm') = 'number' then (x ->> 'm')::numeric::int else 0 end = coalesce(p_room, 0)) = coalesce(p_in, true)
$function$;
select pg_temp.yh_share('public.world_housing_in_room(jsonb, integer, boolean)');
grant execute on function public.world_housing_in_room(jsonb, integer, boolean) to postgres;

create or replace function public.world_housing_counts_all(p_items jsonb, p_wall jsonb, p_paper text, p_ground text, p_rooms jsonb)
 returns jsonb language sql immutable set search_path to ''
as $function$
  select coalesce(jsonb_object_agg(k, n), '{}'::jsonb) from (
    select k, count(*) n from (
      select 'hf_' || (x ->> 'k') k from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) x
      union all select 'hf_' || (x ->> 'k') from jsonb_array_elements(coalesce(p_wall, '[]'::jsonb)) x
      union all select 'hp_' || p_paper where p_paper is not null
      union all select 'hg_' || p_ground where p_ground is not null
      union all select 'hp_' || (r.value ->> 'paper') from jsonb_each(coalesce(p_rooms, '{}'::jsonb)) r where r.value ->> 'paper' is not null
      union all select 'hg_' || (r.value ->> 'ground') from jsonb_each(coalesce(p_rooms, '{}'::jsonb)) r where r.value ->> 'ground' is not null) t group by k) u
$function$;
select pg_temp.yh_share('public.world_housing_counts_all(jsonb, jsonb, text, text, jsonb)');
grant execute on function public.world_housing_counts_all(jsonb, jsonb, text, text, jsonb) to postgres;

create or replace function public.world_housing_room_ok(p_home uuid, p_room integer)
 returns text language plpgsql stable security definer set search_path to ''
as $function$
declare h public.world_housing%rowtype; ru jsonb := public.world_housing_room_rules(); nm text;
begin
  if p_room is null or p_room not between 0 and 2 then return '알 수 없는 방입니다.'; end if;
  if p_room = 0 then return null; end if;
  select * into h from public.world_housing where owner_id = p_home;
  if not found then return '아직 별채가 없습니다.'; end if;
  nm := ru -> 'names' ->> p_room;
  if not h.rooms ? p_room::text then return public.world_josa(nm, '은', '는') || ' 아직 열지 않았습니다.'; end if;
  if coalesce((ru -> 'rooms' -> p_room ->> 'stair')::boolean, false)
     and not exists (select 1 from jsonb_array_elements(public.world_housing_in_room(h.items, 0)) x where x ->> 'k' = ru ->> 'stair') then
    return (ru -> 'names' ->> 0) || '에 「' || (select item_name from public.world_item_catalog where item_id = 'hf_' || (ru ->> 'stair')) || '」을(를) 놓아야 ' || nm || '에 오를 수 있습니다.';
  end if;
  return null;
end $function$;
select pg_temp.yh_share('public.world_housing_room_ok(uuid, integer)');
select pg_temp.yh_own('public.world_housing_room_ok(uuid, integer)', 'fn_owner_field');

create or replace function public.world_housing_room_eff(p_home uuid, p_room integer)
 returns integer language plpgsql stable security definer set search_path to ''
as $function$
begin
  return case when public.world_housing_room_ok(p_home, coalesce(p_room, 0)) is null then coalesce(p_room, 0) else 0 end;
end $function$;
select pg_temp.yh_share('public.world_housing_room_eff(uuid, integer)');
select pg_temp.yh_own('public.world_housing_room_eff(uuid, integer)', 'fn_owner_field');

create or replace function public.world_housing_room_cap(p_home uuid, p_room integer)
 returns integer language plpgsql stable security definer set search_path to ''
as $function$
begin
  if coalesce(p_room, 0) = 0 then return public.world_housing_cap_of(p_home); end if;
  return public.world_housing_cap((select (h.rooms -> p_room::text ->> 'size')::int from public.world_housing h where h.owner_id = p_home)) * public.world_housing_kind_mul(p_home);
end $function$;
select pg_temp.yh_share('public.world_housing_room_cap(uuid, integer)');
select pg_temp.yh_own('public.world_housing_room_cap(uuid, integer)', 'fn_owner_field');

create or replace function public.world_housing_room_next(p_home uuid, p_room integer)
 returns jsonb language plpgsql stable security definer set search_path to ''
as $function$
declare h public.world_housing%rowtype; ru jsonb := public.world_housing_room_rules(); r jsonb; af jsonb; sz int; asz int; an text; nx jsonb; why text;
begin
  if p_room is null or p_room not between 0 and 2 then return null; end if;
  select * into h from public.world_housing where owner_id = p_home;
  if not found then return null; end if;
  r := ru -> 'rooms' -> p_room;
  if p_room = 0 then sz := h.size; else sz := (h.rooms -> p_room::text ->> 'size')::int; end if;
  if sz is null then
    af := r -> 'after';
    asz := case when (af ->> 'room')::int = 0 then h.size else (h.rooms -> (af ->> 'room') ->> 'size')::int end;
    an := public.world_josa(ru -> 'names' ->> (af ->> 'room')::int, '을', '를');
    if asz is null then why := an || ' 연 뒤에 열 수 있습니다.';
    elsif af ? 'size' and asz < (af ->> 'size')::int then why := an || ' ' || (af ->> 'size') || '×' || (af ->> 'size') || '로 넓힌 뒤에 열 수 있습니다.';
    end if;
    return (r -> 'steps' -> '6') || jsonb_build_object('size', 6, 'open', true, 'why', why);
  end if;
  if sz >= 9 then return null; end if;
  nx := r -> 'steps' -> (sz + 1)::text;
  return nx || jsonb_build_object('size', sz + 1, 'open', false);
end $function$;
select pg_temp.yh_share('public.world_housing_room_next(uuid, integer)');
select pg_temp.yh_own('public.world_housing_room_next(uuid, integer)', 'fn_owner_field');

create or replace function public.world_housing_room_view(p_home uuid, p_room integer, p_next boolean)
 returns jsonb language plpgsql stable security definer set search_path to ''
as $function$
declare h public.world_housing%rowtype; ru jsonb := public.world_housing_room_rules(); o boolean; sz int;
begin
  select * into h from public.world_housing where owner_id = p_home;
  if not found then return null; end if;
  o := p_room = 0 or h.rooms ? p_room::text;
  sz := case when p_room = 0 then h.size else (h.rooms -> p_room::text ->> 'size')::int end;
  return jsonb_build_object('room', p_room, 'name', ru -> 'names' ->> p_room, 'open', o, 'size', sz,
    'cap', case when o then public.world_housing_room_cap(p_home, p_room) end,
    'paper', case when p_room = 0 then h.paper else h.rooms -> p_room::text ->> 'paper' end,
    'ground', case when p_room = 0 then h.ground else h.rooms -> p_room::text ->> 'ground' end,
    'why', case when o then public.world_housing_room_ok(p_home, p_room) end,
    'next', case when p_next then public.world_housing_room_next(p_home, p_room) end);
end $function$;
select pg_temp.yh_share('public.world_housing_room_view(uuid, integer, boolean)');
select pg_temp.yh_own('public.world_housing_room_view(uuid, integer, boolean)', 'fn_owner_field');

create or replace function public.world_housing_store_cap_of(p_home uuid)
 returns integer language plpgsql stable security definer set search_path to ''
as $function$
declare m uuid := public.world_housing_mate(p_home); per int := (public.world_housing_room_rules() -> 'store' ->> 'per_room')::int;
begin
  return coalesce((select public.world_housing_store_cap(h.size) + per * (select count(*) from jsonb_object_keys(h.rooms))::int from public.world_housing h where h.owner_id = p_home), public.world_housing_store_cap(6))
    + case when m is null then 0 else coalesce((select public.world_housing_store_cap(h.size) + per * (select count(*) from jsonb_object_keys(h.rooms))::int from public.world_housing h where h.owner_id = m), public.world_housing_store_cap(6)) end;
end $function$;

create or replace function public.world_housing_stair_keep(p_home uuid)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare ru jsonb := public.world_housing_room_rules(); h public.world_housing%rowtype; k text; m uuid := public.world_housing_mate(p_home); n int;
begin
  select * into h from public.world_housing where owner_id = p_home;
  if not found then return; end if;
  if not exists (select 1 from jsonb_object_keys(h.rooms) r(x) where coalesce((ru -> 'rooms' -> x::int ->> 'stair')::boolean, false)) then return; end if;
  k := 'hf_' || (ru ->> 'stair');
  n := coalesce((public.world_housing_counts_all(h.items, h.wall, h.paper, h.ground, h.rooms) ->> k)::int, 0)
     + coalesce((select (s.items ->> k)::int from public.world_housing_store s where s.owner_id = p_home), 0)
     + coalesce((select sum((c.inventory ->> k)::int) from public.world_characters c where c.owner_id in (p_home, m)), 0)
     + coalesce((select sum((s.items ->> k)::int) from public.world_storage s where s.owner_id in (p_home, m)), 0);
  if n > 0 then return; end if;
  insert into public.world_housing_store(owner_id) values (p_home) on conflict (owner_id) do nothing;
  update public.world_housing_store set items = public.world_inv_add(items, k, 1), updated_at = now() where owner_id = p_home;
end $function$;
select pg_temp.yh_share('public.world_housing_stair_keep(uuid)');
select pg_temp.yh_own('public.world_housing_stair_keep(uuid)', 'fn_owner_field');

create or replace function public.world_drawing_wall_clean(p_uid uuid, p_home uuid, p_wall jsonb)
 returns jsonb language plpgsql stable security definer set search_path to ''
as $function$
declare x jsonb; out jsonb := '[]'::jsonb; e jsonb; fr text; d public.world_drawings%rowtype; mate uuid := public.world_housing_mate(p_home);
begin
  if jsonb_typeof(p_wall) <> 'array' then return p_wall; end if;
  for x in select value from jsonb_array_elements(p_wall) loop
    if jsonb_typeof(x) <> 'object' then raise exception '벽 자리가 올바르지 않습니다.'; end if;
    e := jsonb_build_object('k', x -> 'k', 'side', x -> 'side', 't', x -> 't', 'z', x -> 'z');
    if jsonb_typeof(x -> 'm') = 'number' and (x ->> 'm')::numeric in (1, 2) then e := e || jsonb_build_object('m', (x ->> 'm')::numeric::int); end if;
    if jsonb_typeof(x -> 'd') = 'number' then
      fr := (select equipment_traits ->> 'frame' from public.world_item_catalog where item_id = 'hf_' || (x ->> 'k') and category = 'furniture');
      if fr is null then raise exception '그림은 그림 액자에만 걸 수 있습니다.'; end if;
      select * into d from public.world_drawings where id = (x ->> 'd')::numeric::bigint;
      if found and d.removed_at is null then
        if d.owner_id not in (p_uid, p_home) and d.owner_id is distinct from mate then raise exception '내 그림첩의 그림만 걸 수 있습니다.'; end if;
        if d.size <> fr then raise exception '그림 크기가 액자와 맞지 않습니다.'; end if;
        e := e || jsonb_build_object('d', d.id);
      end if;
    end if;
    out := out || e;
  end loop;
  return out;
end $function$;

create or replace function public.world_housing_save(p_owner uuid, p_state jsonb)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); own uuid := public.world_housing_home(coalesce(p_owner, uid)); c public.world_characters%rowtype; h public.world_housing%rowtype; s public.world_housing_store%rowtype;
  why text; v_items jsonb := coalesce(p_state -> 'items', '[]'::jsonb); v_wall jsonb := coalesce(p_state -> 'wall', '[]'::jsonb); v_paper text := nullif(p_state ->> 'paper', ''); v_ground text := nullif(p_state ->> 'ground', '');
  x jsonb; t jsonb; k text; n int; oldc jsonb; newc jsonb; d int; inv jsonb; st jsonb; take int; occ text[] := '{}'; tops text[] := '{}'; surf text[] := '{}';
  gx int; gy int; r int; w int; dd int; i int; j int; cell text; wl jsonb := '[]'::jsonb; a jsonb; b jsonb; bag_changed boolean := false; placed int;
  rm int := 0; sz int; cap int; mk jsonb; n_items jsonb := '[]'::jsonb; n_wall jsonb := '[]'::jsonb; o_paper text; o_ground text; stair text := public.world_housing_room_rules() ->> 'stair';
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if own <> uid and not public.world_housing_married(uid, own) then raise exception '내 별채나 혼례를 올린 정인의 별채만 고칠 수 있습니다.'; end if;
  why := public.world_housing_edit_block(uid);
  if why is not null then raise exception '%', why; end if;
  if jsonb_typeof(v_items) <> 'array' or jsonb_typeof(v_wall) <> 'array' then raise exception '배치 형식이 올바르지 않습니다.'; end if;
  if p_state ? 'room' then
    if jsonb_typeof(p_state -> 'room') <> 'number' or (p_state ->> 'room')::numeric not in (0, 1, 2) then raise exception '알 수 없는 방입니다.'; end if;
    rm := (p_state ->> 'room')::numeric::int;
  end if;
  mk := case when rm = 0 then '{}'::jsonb else jsonb_build_object('m', rm) end;
  v_wall := public.world_drawing_wall_clean(uid, own, v_wall);
  select * into c from public.world_characters where owner_id = uid for update;
  select * into h from public.world_housing where owner_id = own for update;
  if not found then raise exception '아직 별채가 없습니다.'; end if;
  why := public.world_housing_room_ok(own, rm);
  if why is not null then raise exception '%', why; end if;
  sz := case when rm = 0 then h.size else (h.rooms -> rm::text ->> 'size')::int end;
  cap := public.world_housing_room_cap(own, rm);
  placed := jsonb_array_length(v_items) + jsonb_array_length(v_wall);
  if placed > cap then raise exception '이 방에는 가구를 %개까지 놓을 수 있습니다. (지금 %개)', cap, placed; end if;

  for x in select value from jsonb_array_elements(v_items) loop
    k := x ->> 'k';
    select equipment_traits into t from public.world_item_catalog where item_id = 'hf_' || k and category = 'furniture';
    if t is null or t ->> 'kind' not in ('floor', 'rug', 'surface') then raise exception '바닥에 놓을 수 없는 물건이 섞여 있습니다.'; end if;
    if k = stair and rm <> 0 then raise exception '「%」은(는) %에만 놓을 수 있습니다.', (select item_name from public.world_item_catalog where item_id = 'hf_' || k), public.world_housing_room_rules() -> 'names' ->> 0; end if;
    if jsonb_typeof(x -> 'x') <> 'number' or jsonb_typeof(x -> 'y') <> 'number' then raise exception '자리가 올바르지 않습니다.'; end if;
    gx := (x ->> 'x')::numeric::int; gy := (x ->> 'y')::numeric::int; r := coalesce((x ->> 'r')::numeric::int, 0);
    if (x ->> 'x')::numeric <> gx or (x ->> 'y')::numeric <> gy or r not between 0 and 3 then raise exception '자리가 올바르지 않습니다.'; end if;
    w := (t ->> 'w')::int; dd := (t ->> 'd')::int;
    if r % 2 = 1 then i := w; w := dd; dd := i; end if;
    if gx < 0 or gy < 0 or gx + w > sz or gy + dd > sz then raise exception '방 밖으로 나간 가구가 있습니다.'; end if;
    for i in gx .. gx + w - 1 loop for j in gy .. gy + dd - 1 loop
      cell := (t ->> 'kind') || ':' || i || ':' || j;
      if t ->> 'kind' = 'surface' then
        if cell = any (surf) then raise exception '한 자리에 소품을 둘 올릴 수 없습니다.'; end if;
        surf := surf || cell;
      else
        if cell = any (occ) then raise exception '겹쳐 놓인 가구가 있습니다.'; end if;
        occ := occ || cell;
        if t ->> 'kind' = 'floor' and coalesce((t ->> 'top')::numeric, 0) > 0 then tops := tops || (i || ':' || j); end if;
      end if;
    end loop; end loop;
    n_items := n_items || jsonb_build_array(jsonb_build_object('k', k, 'x', gx, 'y', gy, 'r', r) || mk);
  end loop;
  for x in select value from jsonb_array_elements(v_items) loop
    if (select equipment_traits ->> 'kind' from public.world_item_catalog where item_id = 'hf_' || (x ->> 'k')) = 'surface'
       and not ((x ->> 'x')::numeric::int || ':' || (x ->> 'y')::numeric::int) = any (tops) then
      raise exception '소품은 탁자·서안·서가처럼 윗면이 있는 가구 위에만 올릴 수 있습니다.';
    end if;
  end loop;
  for x in select value from jsonb_array_elements(v_wall) loop
    k := x ->> 'k';
    select equipment_traits into t from public.world_item_catalog where item_id = 'hf_' || k and category = 'furniture';
    if t is null or t ->> 'kind' <> 'wall' then raise exception '벽에 걸 수 없는 물건이 섞여 있습니다.'; end if;
    if x ->> 'side' not in ('L', 'R') or jsonb_typeof(x -> 't') <> 'number' or jsonb_typeof(x -> 'z') <> 'number' then raise exception '벽 자리가 올바르지 않습니다.'; end if;
    if ((x ->> 't')::numeric * 10) % 1 <> 0 or (x ->> 'z')::numeric % 1 <> 0 then raise exception '벽 자리가 올바르지 않습니다.'; end if;
    if (x ->> 't')::numeric < 0 or (x ->> 't')::numeric + (t ->> 'ww')::numeric > sz or (x ->> 'z')::numeric < 4 or (x ->> 'z')::numeric + (t ->> 'wh')::numeric > 75 then
      raise exception '벽 밖으로 나간 장식이 있습니다.';
    end if;
    wl := wl || jsonb_build_object('side', x ->> 'side', 't0', (x ->> 't')::numeric, 't1', (x ->> 't')::numeric + (t ->> 'ww')::numeric, 'z0', (x ->> 'z')::numeric, 'z1', (x ->> 'z')::numeric + (t ->> 'wh')::numeric);
    n_wall := n_wall || jsonb_build_array((x - 'm') || mk);
  end loop;
  for i in 0 .. jsonb_array_length(wl) - 1 loop for j in i + 1 .. jsonb_array_length(wl) - 1 loop
    a := wl -> i; b := wl -> j;
    if a ->> 'side' = b ->> 'side' and (a ->> 't0')::numeric < (b ->> 't1')::numeric and (b ->> 't0')::numeric < (a ->> 't1')::numeric
       and (a ->> 'z0')::numeric < (b ->> 'z1')::numeric and (b ->> 'z0')::numeric < (a ->> 'z1')::numeric then raise exception '벽 장식이 서로 겹칩니다.'; end if;
  end loop; end loop;
  if v_paper is not null and not exists (select 1 from public.world_item_catalog where item_id = 'hp_' || v_paper and category = 'furniture') then raise exception '알 수 없는 벽지입니다.'; end if;
  if v_ground is not null and not exists (select 1 from public.world_item_catalog where item_id = 'hg_' || v_ground and category = 'furniture') then raise exception '알 수 없는 바닥재입니다.'; end if;

  newc := public.world_housing_counts(n_items, n_wall, v_paper, v_ground);
  for k, n in select key, value::int from jsonb_each_text(newc) loop
    if k like 'hf\_%' and n > public.world_housing_kind_cap((select tier from public.world_item_catalog where item_id = k)) * public.world_housing_kind_mul(own) then
      raise exception '%은(는) 한 방에 %개까지 놓을 수 있습니다.', (select item_name from public.world_item_catalog where item_id = k), public.world_housing_kind_cap((select tier from public.world_item_catalog where item_id = k)) * public.world_housing_kind_mul(own);
    end if;
  end loop;

  o_paper := case when rm = 0 then h.paper else h.rooms -> rm::text ->> 'paper' end;
  o_ground := case when rm = 0 then h.ground else h.rooms -> rm::text ->> 'ground' end;
  oldc := public.world_housing_counts(public.world_housing_in_room(h.items, rm), public.world_housing_in_room(h.wall, rm), o_paper, o_ground);
  insert into public.world_housing_store(owner_id) values (own) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = own for update;
  inv := coalesce(c.inventory, '{}'::jsonb); st := coalesce(s.items, '{}'::jsonb);
  for k in select key from jsonb_each(newc) union select key from jsonb_each(oldc) loop
    d := coalesce((newc ->> k)::int, 0) - coalesce((oldc ->> k)::int, 0);
    if d > 0 then
      take := least(d, coalesce((st ->> k)::int, 0));
      if take > 0 then st := public.world_inv_add(st, k, -take); if coalesce((st ->> k)::int, 0) <= 0 then st := st - k; end if; d := d - take; end if;
      if d > 0 then
        if coalesce((inv ->> k)::int, 0) < d then raise exception '%이(가) 모자랍니다. 가방이나 곳간에 있어야 놓을 수 있습니다.', (select item_name from public.world_item_catalog where item_id = k); end if;
        inv := public.world_inv_add(inv, k, -d); if coalesce((inv ->> k)::int, 0) <= 0 then inv := inv - k; end if; bag_changed := true;
        if own <> uid and uid = public.world_housing_mate(own) then perform public.world_housing_contrib(own, k, d); end if;
      end if;
    elsif d < 0 then
      st := public.world_inv_add(st, k, -d);
    end if;
  end loop;
  if public.world_housing_store_count(st) > public.world_housing_store_cap_of(own) and public.world_housing_store_count(st) > public.world_housing_store_count(s.items) then
    raise exception '곳간이 가득 차 거둘 수 없습니다. (곳간 %칸) 곳간을 비운 뒤 다시 저장하세요.', public.world_housing_store_cap_of(own);
  end if;
  update public.world_housing set
    items = public.world_housing_in_room(items, rm, false) || n_items,
    wall = public.world_housing_in_room(wall, rm, false) || n_wall,
    paper = case when rm = 0 then v_paper else paper end,
    ground = case when rm = 0 then v_ground else ground end,
    rooms = case when rm = 0 then rooms else jsonb_set(rooms, array[rm::text], jsonb_strip_nulls(((rooms -> rm::text) - 'paper' - 'ground') || jsonb_build_object('paper', v_paper, 'ground', v_ground))) end,
    updated_at = now()
  where owner_id = own;
  update public.world_housing_store set items = st, updated_at = now() where owner_id = own;
  if bag_changed then update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid; end if;
  perform public.world_title_award_check(own, 'home');
  return public.world_housing_snapshot(own);
end $function$;

drop function if exists public.world_housing_expand();
create function public.world_housing_expand(p_room integer default 0)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; h public.world_housing%rowtype; why text; ru jsonb := public.world_housing_room_rules();
  nx jsonb; v_gil int; lv int; need jsonb; st jsonb; mt jsonb; nm text; rm int := coalesce(p_room, 0); sz int; opening boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  why := public.world_housing_edit_block(uid);
  if why is not null then raise exception '%', why; end if;
  if rm not between 0 and 2 then raise exception '알 수 없는 방입니다.'; end if;
  nm := ru -> 'names' ->> rm;
  select * into c from public.world_characters where owner_id = uid for update;
  select * into h from public.world_housing where owner_id = public.world_housing_home(uid) for update;
  if not found then raise exception '아직 별채가 없습니다.'; end if;
  nx := public.world_housing_room_next(h.owner_id, rm);
  if nx is null then raise exception '%', case when rm = 0 then '별채를 더 넓힐 수 없습니다(9×9가 가장 넓습니다).' else public.world_josa(nm, '은', '는') || ' 9×9가 가장 넓습니다.' end; end if;
  if nx ->> 'why' is not null then raise exception '%', nx ->> 'why'; end if;
  opening := coalesce((nx ->> 'open')::boolean, false);
  sz := (nx ->> 'size')::int; v_gil := (nx ->> 'gil')::int; lv := (nx ->> 'level')::int; need := coalesce(nx -> 'items', '{}'::jsonb);
  if c.level < lv then raise exception 'Lv%부터 %.', lv, case when opening then public.world_josa(nm, '을', '를') || ' 열 수 있습니다' else '넓힐 수 있습니다' end; end if;
  if c.gil < v_gil then raise exception '%전이 필요합니다. (가진 전 %)', v_gil, c.gil; end if;
  select items into st from public.world_storage where owner_id = uid for update;
  mt := public.world_materials_take(coalesce(c.inventory, '{}'::jsonb), coalesce(st, '{}'::jsonb), need);
  update public.world_characters set inventory = mt -> 'inv', gil = gil - v_gil, updated_at = now() where owner_id = uid;
  if mt -> 'from_st' <> '{}'::jsonb then
    update public.world_storage set items = (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(mt -> 'st') where jsonb_typeof(value) = 'number' and value::text::int > 0), updated_at = now() where owner_id = uid;
  end if;
  if rm = 0 then
    update public.world_housing set size = sz, updated_at = now() where owner_id = h.owner_id;
  else
    update public.world_housing set rooms = jsonb_set(rooms, array[rm::text], coalesce(rooms -> rm::text, '{}'::jsonb) || jsonb_build_object('size', sz)), updated_at = now() where owner_id = h.owner_id;
  end if;
  if opening and coalesce((ru -> 'rooms' -> rm ->> 'stair')::boolean, false) then
    perform public.world_housing_grant(h.owner_id, 'hf_' || (ru ->> 'stair'), 1, nm || '을 열었습니다', true);
  end if;
  perform public.world_title_award_check(uid, 'home');
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'housing_expand', -v_gil, true, jsonb_build_object('room', rm, 'size', sz, 'open', opening));
  return jsonb_build_object('ok', true, 'room', rm, 'size', sz, 'opened', opening, 'from_storage', mt -> 'from_st',
    'content', case when opening then public.world_josa(nm, '을', '를') || ' 열었습니다(' || sz || '×' || sz || ').' || case when coalesce((ru -> 'rooms' -> rm ->> 'stair')::boolean, false) then ' 곳간에 든 「' || (select item_name from public.world_item_catalog where item_id = 'hf_' || (ru ->> 'stair')) || '」을(를) ' || (ru -> 'names' ->> 0) || '에 놓으면 오를 수 있습니다.' else '' end
      when rm = 0 then '별채를 ' || sz || '×' || sz || '로 넓혔습니다.' else public.world_josa(nm, '을', '를') || ' ' || sz || '×' || sz || '로 넓혔습니다.' end);
end $function$;
select pg_temp.yh_share('public.world_housing_expand(integer)');
grant execute on function public.world_housing_expand(integer) to authenticated;
select pg_temp.yh_own('public.world_housing_expand(integer)', 'fn_owner_field');

create or replace function public.world_housing_room_set(p_what text, p_room integer)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); own uuid; why text; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_what not in ('pet', 'look') then raise exception '알 수 없는 일입니다.'; end if;
  own := public.world_housing_home(uid);
  if not exists (select 1 from public.world_housing where owner_id = own) then raise exception '아직 별채가 없습니다.'; end if;
  perform 1 from public.world_housing where owner_id = own for update;
  why := public.world_housing_room_ok(own, p_room);
  if why is not null then raise exception '%', why; end if;
  nm := public.world_housing_room_rules() -> 'names' ->> p_room;
  if p_what = 'pet' then update public.world_housing set pet_room = p_room, updated_at = now() where owner_id = own;
  else update public.world_housing set look_room = p_room, updated_at = now() where owner_id = own; end if;
  return jsonb_build_object('ok', true, 'what', p_what, 'room', p_room,
    'content', case when p_what = 'look' then '내 모습이 ' || nm || '에 머뭅니다.' when (select pet_id from public.world_housing where owner_id = own) is null then '별채 동무를 두면 ' || nm || '에 머뭅니다.' else '별채 동무가 ' || nm || '에 머뭅니다.' end);
end $function$;
select pg_temp.yh_share('public.world_housing_room_set(text, integer)');
grant execute on function public.world_housing_room_set(text, integer) to authenticated;
select pg_temp.yh_own('public.world_housing_room_set(text, integer)', 'fn_owner_field');

create or replace function public.world_housing_store_move(p_item text, p_qty integer, p_dir text)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_housing_store%rowtype; why text; nm text; have int; n int; room int; sz int; hm uuid;
begin perform public.world_travel_guard('곳간 정리');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_dir not in ('put', 'take', 'discard') then raise exception '알 수 없는 일입니다.'; end if;
  if p_dir = 'discard' then
    if exists (select 1 from public.world_characters x where x.owner_id = uid and (coalesce(x.is_dead, false) or x.downed_at is not null)) then raise exception '전투불능 상태에서는 곳간을 정리할 수 없습니다.'; end if;
    if p_item = 'hf_' || (public.world_housing_room_rules() ->> 'stair') then raise exception '「%」은(는) 버릴 수 없습니다. %에 오르는 데 씁니다.', (select item_name from public.world_item_catalog where item_id = p_item), public.world_housing_room_rules() -> 'names' ->> 2; end if;
  else
    why := public.world_housing_edit_block(uid);
    if why is not null then raise exception '%', replace(why, '별채를 고칠', '곳간을 쓸'); end if;
  end if;
  if p_qty is null or p_qty < 1 or p_qty > 99 then raise exception '수량이 올바르지 않습니다.'; end if;
  select item_name into nm from public.world_item_catalog where item_id = p_item and category = 'furniture';
  if nm is null then raise exception '곳간에는 별채 가구만 둘 수 있습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  hm := public.world_housing_home(uid); select size into sz from public.world_housing where owner_id = hm;
  insert into public.world_housing_store(owner_id) values (hm) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = hm for update;
  if p_dir = 'put' then
    if sz is null then raise exception '별채를 얻은 뒤에 곳간을 쓸 수 있습니다.'; end if;
    have := coalesce((c.inventory ->> p_item)::int, 0);
    if have < p_qty then raise exception '가방에 %이(가) 모자랍니다.', nm; end if;
    if public.world_housing_store_count(s.items) + p_qty > public.world_housing_store_cap_of(hm) then raise exception '곳간이 가득 찼습니다. (곳간 %칸)', public.world_housing_store_cap_of(hm); end if;
    update public.world_characters set inventory = case when have - p_qty <= 0 then inventory - p_item else jsonb_set(inventory, array[p_item], to_jsonb(have - p_qty)) end, updated_at = now() where owner_id = uid;
    update public.world_housing_store set items = public.world_inv_add(items, p_item, p_qty), updated_at = now() where owner_id = hm;
    if hm <> uid then perform public.world_housing_contrib(hm, p_item, p_qty); end if;
    return jsonb_build_object('ok', true, 'content', nm || ' ×' || p_qty || '을(를) 곳간에 넣었습니다.');
  end if;
  have := coalesce((s.items ->> p_item)::int, 0);
  if have < p_qty then raise exception '곳간에 %이(가) 모자랍니다.', nm; end if;
  if p_dir = 'take' then
    room := public.world_bag_room(c.inventory, p_item, public.world_bag_limit(uid));
    n := least(p_qty, room);
    if n <= 0 then raise exception '가방에 자리가 없습니다.'; end if;
    update public.world_characters set inventory = public.world_inv_add(inventory, p_item, n), updated_at = now() where owner_id = uid;
  else
    n := p_qty;
  end if;
  update public.world_housing_store set items = case when have - n <= 0 then items - p_item else jsonb_set(items, array[p_item], to_jsonb(have - n)) end, updated_at = now() where owner_id = hm;
  if hm <> uid then perform public.world_housing_contrib(hm, p_item, -n); end if;
  return jsonb_build_object('ok', true, 'moved', n, 'content', nm || ' ×' || n || case when p_dir = 'take' then '을(를) 가방으로 꺼냈습니다.' else '을(를) 버렸습니다.' end);
end $function$;

create or replace function public.world_housing_unshare(p_home uuid, p_why text)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare sh public.world_housing_shared%rowtype; h public.world_housing%rowtype; st jsonb; placed jsonb; give jsonb := '{}'::jsonb;
  k text; want int; n int; t1 int; rest int; arr jsonb; out jsonb; x jsonb; i int; j int; total int := 0; v_paper text; v_ground text; v_rooms jsonb; rm int;
begin
  select * into sh from public.world_housing_shared where home_id = p_home for update;
  if not found then return; end if;
  select * into h from public.world_housing where owner_id = p_home for update;
  insert into public.world_housing_store(owner_id) values (p_home) on conflict (owner_id) do nothing;
  select coalesce(items, '{}'::jsonb) into st from public.world_housing_store where owner_id = p_home for update;
  placed := public.world_housing_counts_all(h.items, h.wall, h.paper, h.ground, h.rooms);
  v_paper := h.paper; v_ground := h.ground; v_rooms := coalesce(h.rooms, '{}'::jsonb);
  for k, want in select key, value::int from jsonb_each_text(sh.contrib) loop
    n := least(want, coalesce((st ->> k)::int, 0) + coalesce((placed ->> k)::int, 0));
    if n <= 0 then continue; end if;
    t1 := least(n, coalesce((st ->> k)::int, 0));
    if t1 > 0 then st := public.world_inv_add(st, k, -t1); if coalesce((st ->> k)::int, 0) <= 0 then st := st - k; end if; end if;
    rest := n - t1;
    foreach rm in array array[1, 2, 0] loop
      exit when rest <= 0;
      for j in 1 .. 2 loop
        exit when rest <= 0;
        arr := case j when 1 then coalesce(h.items, '[]'::jsonb) else coalesce(h.wall, '[]'::jsonb) end;
        out := '[]'::jsonb;
        for i in reverse jsonb_array_length(arr) - 1 .. 0 loop
          x := arr -> i;
          if rest > 0 and 'hf_' || (x ->> 'k') = k and public.world_housing_in_room(jsonb_build_array(x), rm) <> '[]'::jsonb then rest := rest - 1; else out := jsonb_build_array(x) || out; end if;
        end loop;
        if j = 1 then h.items := out; else h.wall := out; end if;
      end loop;
      if rm = 0 then
        if rest > 0 and v_paper is not null and 'hp_' || v_paper = k then v_paper := null; rest := rest - 1; end if;
        if rest > 0 and v_ground is not null and 'hg_' || v_ground = k then v_ground := null; rest := rest - 1; end if;
      elsif v_rooms ? rm::text then
        if rest > 0 and v_rooms -> rm::text ->> 'paper' is not null and 'hp_' || (v_rooms -> rm::text ->> 'paper') = k then v_rooms := jsonb_set(v_rooms, array[rm::text], (v_rooms -> rm::text) - 'paper'); rest := rest - 1; end if;
        if rest > 0 and v_rooms -> rm::text ->> 'ground' is not null and 'hg_' || (v_rooms -> rm::text ->> 'ground') = k then v_rooms := jsonb_set(v_rooms, array[rm::text], (v_rooms -> rm::text) - 'ground'); rest := rest - 1; end if;
      end if;
    end loop;
    give := jsonb_set(give, array[k], to_jsonb(n - rest)); total := total + n - rest;
  end loop;
  update public.world_housing set items = h.items, wall = h.wall, paper = v_paper, ground = v_ground, rooms = v_rooms, updated_at = now() where owner_id = p_home;
  update public.world_housing_store set items = st, updated_at = now() where owner_id = p_home;
  insert into public.world_housing_store(owner_id) values (sh.mate_id) on conflict (owner_id) do nothing;
  for k, n in select key, value::int from jsonb_each_text(give) loop
    if n > 0 then update public.world_housing_store set items = public.world_inv_add(items, k, n), updated_at = now() where owner_id = sh.mate_id; end if;
  end loop;
  delete from public.world_housing_shared where home_id = p_home;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select u, 'housing_merge', '각자 별채로 돌아갔습니다', coalesce(p_why || ' ', '') ||
    case when u = sh.mate_id then case when total > 0 then '들여온 가구 ' || total || '점이 내 별채 곳간으로 돌아왔습니다.' else '내 별채로 돌아왔습니다.' end
         else case when total > 0 then '정인이 들여온 가구 ' || total || '점은 정인에게 돌아갔습니다.' else '별채는 그대로입니다.' end end,
    jsonb_build_object('home', p_home)
  from unnest(array[sh.home_id, sh.mate_id]) u;
end $function$;

create or replace function public.world_housing_owned_kinds(p_uid uuid)
 returns integer language plpgsql stable security definer set search_path to ''
as $function$
#variable_conflict use_column
begin
  return (select * from (select count(distinct k)::int from (
    select key k from public.world_housing_store s, jsonb_each(s.items) where s.owner_id = p_uid
    union select key from public.world_housing h, jsonb_each(public.world_housing_counts_all(h.items, h.wall, h.paper, h.ground, h.rooms)) where h.owner_id = p_uid
    union select i.item_id from public.world_characters c join public.world_item_catalog i on i.category = 'furniture' and coalesce((c.inventory ->> i.item_id)::int, 0) > 0 where c.owner_id = p_uid) t
) yhq limit 1);
end
$function$;

create or replace function public.world_pet_room(p_owner uuid)
 returns jsonb language sql stable security definer set search_path to ''
as $function$
  select case when h.pet_id is null then null else jsonb_build_object('id', h.pet_id, 'out', h.pet_out, 'nick', p.nickname, 'name', s.pet_name, 'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'grown', coalesce(p.affinity, 0) >= 100, 'affinity', p.affinity, 'mess', public.world_pet_mess_of(h.owner_id, h.pet_id), 'room', public.world_housing_room_eff(h.owner_id, h.pet_room)) end
    from public.world_housing h left join public.world_pets p on p.owner_id = h.owner_id and p.pet_id = h.pet_id left join public.world_pet_species s on s.pet_id = h.pet_id
   where h.owner_id = p_owner
$function$;

create or replace function public.world_avatar_room(p_owner uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
declare rm int := coalesce((select public.world_housing_room_eff(h.owner_id, h.look_room) from public.world_housing h where h.owner_id = p_owner), 0);
begin
  return (select coalesce(jsonb_agg(jsonb_build_object('id', c.owner_id, 'name', c.character_name, 'job', c.job_key, 'look', public.world_avatar_look_clean(c.owner_id, a.look), 'room', rm) order by c.owner_id = p_owner desc), '[]'::jsonb)
    from public.world_characters c left join public.world_avatars a on a.owner_id = c.owner_id
   where c.owner_id in (p_owner, public.world_housing_mate(p_owner)) and coalesce(a.home_on, true));
end $function$;

create or replace function public.world_housing_snapshot(p_owner uuid default null::uuid)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); own uuid := public.world_housing_home(coalesce(p_owner, uid)); h public.world_housing%rowtype; nm text; why text; today date := public.world_housing_today();
  role text; edit text; c public.world_characters%rowtype; bag jsonb := '{}'::jsonb; store jsonb := '{}'::jsonb; nxt jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select character_name into nm from public.world_characters where owner_id = own;
  if nm is null then raise exception '알 수 없는 조사원입니다.'; end if;
  select * into h from public.world_housing where owner_id = own;
  if not found then
    if own <> uid then raise exception '%님은 아직 별채가 없습니다.', nm; end if;
    return jsonb_build_object('open', false, 'quest', (select jsonb_build_object('step', coalesce(g.step, 0), 'done', g.done_at is not null) from (select 1) z
      left join public.world_quest_progress g on g.owner_id = uid and g.quest_id = 'hs_byeolchae'),
      'store', (select items from public.world_housing_store where owner_id = uid), 'merge', public.world_housing_merge_info(uid));
  end if;
  why := public.world_housing_can_view(uid, own, h.gate);
  if why is not null then raise exception '%', why; end if;
  role := case when uid = own or uid = public.world_housing_mate(own) then 'owner' when public.world_housing_married(uid, own) then 'partner' end;
  if role is null then
    insert into public.world_housing_visits(owner_id, visitor_id, day) values (own, uid, today) on conflict do nothing;
    if found then
      update public.world_housing set visits_total = visits_total + 1, visits_today = case when visits_day = today then visits_today + 1 else 1 end, visits_day = today
       where owner_id = own returning * into h;
      if h.visits_total in (10, 50, 100, 300) then perform public.world_title_award_check(own, 'home'); end if;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      select own, 'housing_visit', '별채 발걸음', character_name || '님이 별채에 다녀갔습니다.', jsonb_build_object('visitor', uid) from public.world_characters where owner_id = uid;
    end if;
  else
    if role = 'owner' then perform public.world_housing_stair_keep(own); end if;
    edit := public.world_housing_edit_block(uid);
    select * into c from public.world_characters where owner_id = uid;
    select coalesce(jsonb_object_agg(i.item_id, (c.inventory ->> i.item_id)::int), '{}'::jsonb) into bag
      from public.world_item_catalog i where i.category = 'furniture' and coalesce((c.inventory ->> i.item_id)::int, 0) > 0;
    store := coalesce((select items from public.world_housing_store where owner_id = own), '{}'::jsonb);
    nxt := public.world_housing_room_next(own, 0);
  end if;
  return jsonb_build_object('open', true, 'owner_id', own, 'owner_name', nm, 'role', role, 'edit_block', case when role is null then null else edit end,
    'size', h.size, 'cap', public.world_housing_cap_of(own), 'store_cap', public.world_housing_store_cap_of(own),
    'kind_caps', (select jsonb_agg(x * public.world_housing_kind_mul(own) order by o) from unnest(array[4, 3, 2, 1, 1]) with ordinality u(x, o)),
    'rooms', (select jsonb_agg(public.world_housing_room_view(own, i, role is not null) order by i) from generate_series(0, 2) i),
    'pet_room', public.world_housing_room_eff(own, h.pet_room), 'look_room', public.world_housing_room_eff(own, h.look_room),
    'merge', case when role = 'owner' then public.world_housing_merge_info(uid) end,
    'mate_name', (select c2.character_name from public.world_characters c2 where c2.owner_id = public.world_housing_mate(own)),
    'items', h.items, 'wall', h.wall, 'paper', h.paper, 'ground', h.ground, 'gate', h.gate,
    'visits_today', case when h.visits_day = today then h.visits_today else 0 end, 'visits_total', h.visits_total,
    'pet_id', h.pet_id, 'pet_out', h.pet_out, 'pet', public.world_pet_room(own), 'drawings', public.world_drawing_room(uid, h.wall), 'avatars', public.world_avatar_room(own), 'avatar_designs', public.world_outfit_design_map(public.fn_owner_auth_uid(), public.world_avatar_room_ids(own)),
    'pet_today', case when h.pet_id is not null and role is null then (select jsonb_build_object('pat', g.pat, 'play', g.play) from public.world_pet_guest g where g.owner_id = own and g.visitor_id = uid and g.day = today) end,
    'bag', case when role is not null then bag end, 'store', case when role is not null then store end, 'next', nxt,
    'guestbook', (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'writer_id', g.writer_id, 'writer', g.writer_name, 'body', g.body, 'at', g.created_at,
        'mine', g.writer_id = uid, 'can_delete', g.writer_id = uid or uid = own) order by g.created_at desc), '[]'::jsonb)
      from (select * from public.world_housing_guestbook where owner_id = own order by created_at desc limit 20) g),
    'wrote_today', (select count(*) from public.world_housing_guestbook where owner_id = own and writer_id = uid and created_at >= (today::timestamp at time zone 'Asia/Seoul')));
end $function$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261117030000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
