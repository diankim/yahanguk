create or replace function pg_temp.yh_cb_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname in ('service_role', 'postgres') loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function public.world_furn_place_check(p_id text, p_traits jsonb, p_place text)
 returns void language plpgsql stable security definer set search_path to '' as $f$
begin
  if p_place = 'cabin' and not coalesce((p_traits ->> 'cabin')::boolean, false) then
    raise exception '「%」은(는) 배 객실에 놓을 수 없습니다.', (select item_name from public.world_item_catalog where item_id = p_id) using hint = 'not_cabin';
  end if;
  if p_place <> 'cabin' and coalesce((p_traits ->> 'ship_only')::boolean, false) then
    raise exception '「%」은(는) 배 객실에만 놓을 수 있습니다.', (select item_name from public.world_item_catalog where item_id = p_id) using hint = 'ship_only';
  end if;
end $f$;

create or replace function public.world_furn_layout(p_items jsonb, p_wall jsonb, p_paper text, p_ground text, p_sz int, p_cap int, p_place text, p_kmul int, p_room int)
 returns jsonb language plpgsql stable security definer set search_path to '' as $f$
declare x jsonb; t jsonb; k text; n int; gx int; gy int; r int; w int; dd int; i int; j int; cell text; occ text[] := '{}'; tops text[] := '{}'; surf text[] := '{}';
  wl jsonb := '[]'::jsonb; a jsonb; b jsonb; placed int; newc jsonb; n_items jsonb := '[]'::jsonb; n_wall jsonb := '[]'::jsonb;
  mk jsonb := case when coalesce(p_room, 0) = 0 then '{}'::jsonb else jsonb_build_object('m', p_room) end; stair text := public.world_housing_room_rules() ->> 'stair';
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_typeof(p_wall) <> 'array' then raise exception '배치 형식이 올바르지 않습니다.'; end if;
  placed := jsonb_array_length(p_items) + jsonb_array_length(p_wall);
  if placed > p_cap then raise exception '이 방에는 가구를 %개까지 놓을 수 있습니다. (지금 %개)', p_cap, placed; end if;

  for x in select value from jsonb_array_elements(p_items) loop
    k := x ->> 'k';
    select equipment_traits into t from public.world_item_catalog where item_id = 'hf_' || k and category = 'furniture';
    if t is null or t ->> 'kind' not in ('floor', 'rug', 'surface') then raise exception '바닥에 놓을 수 없는 물건이 섞여 있습니다.'; end if;
    perform public.world_furn_place_check('hf_' || k, t, p_place);
    if k = stair and coalesce(p_room, 0) <> 0 then raise exception '「%」은(는) %에만 놓을 수 있습니다.', (select item_name from public.world_item_catalog where item_id = 'hf_' || k), public.world_housing_room_rules() -> 'names' ->> 0; end if;
    if jsonb_typeof(x -> 'x') <> 'number' or jsonb_typeof(x -> 'y') <> 'number' then raise exception '자리가 올바르지 않습니다.'; end if;
    gx := (x ->> 'x')::numeric::int; gy := (x ->> 'y')::numeric::int; r := coalesce((x ->> 'r')::numeric::int, 0);
    if (x ->> 'x')::numeric <> gx or (x ->> 'y')::numeric <> gy or r not between 0 and 3 then raise exception '자리가 올바르지 않습니다.'; end if;
    w := (t ->> 'w')::int; dd := (t ->> 'd')::int;
    if r % 2 = 1 then i := w; w := dd; dd := i; end if;
    if gx < 0 or gy < 0 or gx + w > p_sz or gy + dd > p_sz then raise exception '방 밖으로 나간 가구가 있습니다.'; end if;
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
  for x in select value from jsonb_array_elements(p_items) loop
    if (select equipment_traits ->> 'kind' from public.world_item_catalog where item_id = 'hf_' || (x ->> 'k')) = 'surface'
       and not ((x ->> 'x')::numeric::int || ':' || (x ->> 'y')::numeric::int) = any (tops) then
      raise exception '소품은 탁자·서안·서가처럼 윗면이 있는 가구 위에만 올릴 수 있습니다.';
    end if;
  end loop;
  for x in select value from jsonb_array_elements(p_wall) loop
    k := x ->> 'k';
    select equipment_traits into t from public.world_item_catalog where item_id = 'hf_' || k and category = 'furniture';
    if t is null or t ->> 'kind' <> 'wall' then raise exception '벽에 걸 수 없는 물건이 섞여 있습니다.'; end if;
    perform public.world_furn_place_check('hf_' || k, t, p_place);
    if x ->> 'side' not in ('L', 'R') or jsonb_typeof(x -> 't') <> 'number' or jsonb_typeof(x -> 'z') <> 'number' then raise exception '벽 자리가 올바르지 않습니다.'; end if;
    if ((x ->> 't')::numeric * 10) % 1 <> 0 or (x ->> 'z')::numeric % 1 <> 0 then raise exception '벽 자리가 올바르지 않습니다.'; end if;
    if (x ->> 't')::numeric < 0 or (x ->> 't')::numeric + (t ->> 'ww')::numeric > p_sz or (x ->> 'z')::numeric < 4 or (x ->> 'z')::numeric + (t ->> 'wh')::numeric > 75 then
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
  if p_paper is not null then
    select equipment_traits into t from public.world_item_catalog where item_id = 'hp_' || p_paper and category = 'furniture';
    if t is null then raise exception '알 수 없는 벽지입니다.'; end if;
    perform public.world_furn_place_check('hp_' || p_paper, t, p_place);
  end if;
  if p_ground is not null then
    select equipment_traits into t from public.world_item_catalog where item_id = 'hg_' || p_ground and category = 'furniture';
    if t is null then raise exception '알 수 없는 바닥재입니다.'; end if;
    perform public.world_furn_place_check('hg_' || p_ground, t, p_place);
  end if;

  newc := public.world_housing_counts(n_items, n_wall, p_paper, p_ground);
  for k, n in select key, value::int from jsonb_each_text(newc) loop
    if k like 'hf\_%' and n > public.world_housing_kind_cap((select tier from public.world_item_catalog where item_id = k)) * p_kmul then
      raise exception '%은(는) 한 방에 %개까지 놓을 수 있습니다.', (select item_name from public.world_item_catalog where item_id = k), public.world_housing_kind_cap((select tier from public.world_item_catalog where item_id = k)) * p_kmul;
    end if;
  end loop;

  return jsonb_build_object('items', n_items, 'wall', n_wall, 'counts', newc);
end $f$;

create or replace function public.world_furn_swap(p_uid uuid, p_home uuid, p_inv jsonb, p_old jsonb, p_new jsonb, p_mate text)
 returns jsonb language plpgsql security definer set search_path to '' as $f$
declare s public.world_housing_store%rowtype; inv jsonb := coalesce(p_inv, '{}'::jsonb); st jsonb; k text; d int; take int; bag boolean := false;
begin
  insert into public.world_housing_store(owner_id) values (p_home) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = p_home for update;
  st := coalesce(s.items, '{}'::jsonb);
  for k in select key from jsonb_each(p_new) union select key from jsonb_each(p_old) loop
    d := coalesce((p_new ->> k)::int, 0) - coalesce((p_old ->> k)::int, 0);
    if d > 0 then
      take := least(d, coalesce((st ->> k)::int, 0));
      if take > 0 then
        st := public.world_inv_add(st, k, -take); if coalesce((st ->> k)::int, 0) <= 0 then st := st - k; end if; d := d - take;
        if p_mate = 'cabin' then perform public.world_housing_contrib(p_home, k, -take); end if;
      end if;
      if d > 0 then
        if coalesce((inv ->> k)::int, 0) < d then raise exception '%이(가) 모자랍니다. 가방이나 곳간에 있어야 놓을 수 있습니다.', (select item_name from public.world_item_catalog where item_id = k); end if;
        inv := public.world_inv_add(inv, k, -d); if coalesce((inv ->> k)::int, 0) <= 0 then inv := inv - k; end if; bag := true;
        if p_mate = 'house' then perform public.world_housing_contrib(p_home, k, d); end if;
      end if;
    elsif d < 0 then
      st := public.world_inv_add(st, k, -d);
      if p_mate = 'cabin' then perform public.world_housing_contrib(p_home, k, -d); end if;
    end if;
  end loop;
  if public.world_housing_store_count(st) > public.world_housing_store_cap_of(p_home) and public.world_housing_store_count(st) > public.world_housing_store_count(s.items) then
    raise exception '곳간이 가득 차 거둘 수 없습니다. (곳간 %칸) 곳간을 비운 뒤 다시 저장하세요.', public.world_housing_store_cap_of(p_home);
  end if;
  return jsonb_build_object('inv', inv, 'st', st, 'bag', bag);
end $f$;

select pg_temp.yh_cb_share('public.world_furn_place_check(text, jsonb, text)');
select pg_temp.yh_cb_share('public.world_furn_layout(jsonb, jsonb, text, text, int, int, text, int, int)');
select pg_temp.yh_cb_share('public.world_furn_swap(uuid, uuid, jsonb, jsonb, jsonb, text)');

select pg_temp.yh_fix('world_housing_save(uuid,jsonb)', array[
  $q$rm int := 0;$q$, $q$rm int := 0; sw jsonb;$q$,
  $q$  placed := jsonb_array_length(v_items) + jsonb_array_length(v_wall);
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

$q$,
  $q$  newc := public.world_furn_layout(v_items, v_wall, v_paper, v_ground, sz, cap, 'house', public.world_housing_kind_mul(own), rm);
  n_items := newc -> 'items'; n_wall := newc -> 'wall'; newc := newc -> 'counts';

$q$,
  $q$  insert into public.world_housing_store(owner_id) values (own) on conflict (owner_id) do nothing;
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
$q$,
  $q$  sw := public.world_furn_swap(uid, own, c.inventory, oldc, newc, case when own <> uid and uid = public.world_housing_mate(own) then 'house' end);
  inv := sw -> 'inv'; st := sw -> 'st'; bag_changed := (sw ->> 'bag')::boolean;
$q$]);
