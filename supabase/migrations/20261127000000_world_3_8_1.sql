create or replace function pg_temp.yh_patch(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text; n int;
begin
  select prosrc into src from pg_proc where oid = p_fn;
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'patch % : % 번 나옴 — %', p_fn, n, left(p_old, 60); end if;
  src := replace(src, p_old, p_new);
  execute regexp_replace(pg_get_functiondef(p_fn), 'AS \$function\$.*\$function\$', '', 's') || ' AS $yhfn$' || src || '$yhfn$';
end $f$;

create or replace function public.world_region_dist(p_uid uuid) returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $f$
declare c record; here text; ids text[]; nm text[]; xs float8[]; ys float8[]; el float8[]; tc float8[]; terr text[]; lv int[]; lk jsonb[]; ok boolean[];
  d float8[]; hp int[]; done boolean[]; nn int; i int; u int; v int; best float8; si int; w float8; nb text; ks text[] := '{}'; vs jsonb[] := '{}';
begin
  if p_uid is null then return null; end if;
  select x.level, x.location into c from public.world_characters x where x.owner_id = p_uid;
  if not found then return null; end if;
  here := (public.world_field_region(c.location)).region_id;
  if here is null then return null; end if;
  select array_agg(r.region_id order by r.region_id), array_agg(r.region_name order by r.region_id), array_agg(r.world_x::float8 order by r.region_id), array_agg(r.world_y::float8 order by r.region_id),
         array_agg(coalesce(r.elevation, 0)::float8 order by r.region_id), array_agg(coalesce(r.terrain_cost, 1)::float8 order by r.region_id),
         array_agg(r.territory_id order by r.region_id), array_agg(r.min_level order by r.region_id), array_agg(to_jsonb(coalesce(r.travel_from, '{}')) order by r.region_id),
         array_agg(public.world_region_open(p_uid, r.region_id) order by r.region_id)
    into ids, nm, xs, ys, el, tc, terr, lv, lk, ok from public.world_map_regions r where r.active;
  nn := cardinality(ids); si := array_position(ids, here);
  if si is null then return null; end if;
  d := array_fill(1e18::float8, array[nn]); hp := array_fill(0, array[nn]); done := array_fill(false, array[nn]);
  d[si] := 0;
  loop
    u := null; best := 1e18;
    for i in 1..nn loop if not done[i] and d[i] < best then best := d[i]; u := i; end if; end loop;
    exit when u is null;
    done[u] := true;
    for nb in select jsonb_array_elements_text(lk[u]) loop
      v := array_position(ids, nb);
      continue when v is null or done[v] or lv[v] > c.level or not ok[v];
      w := (sqrt((xs[u] - xs[v]) ^ 2 + (ys[u] - ys[v]) ^ 2) * 1.4 + abs(el[u] - el[v]) * 6 + 12) * greatest(tc[u], tc[v])
           * case when terr[u] is distinct from terr[v] then 1.2 else 1 end;
      if d[u] + w < d[v] then d[v] := d[u] + w; hp[v] := hp[u] + 1; end if;
    end loop;
  end loop;
  for i in 1..nn loop
    if d[i] < 1e17 then ks := ks || nm[i]; vs := vs || jsonb_build_array(hp[i], round(d[i]::numeric)); end if;
  end loop;
  return jsonb_build_object('here', nm[si], 'd', (select coalesce(jsonb_object_agg(x.kk, x.vv), '{}'::jsonb) from unnest(ks, vs) x(kk, vv)));
end $f$;
alter function public.world_region_dist(uuid) owner to postgres;
revoke all on function public.world_region_dist(uuid) from public, anon, authenticated;
grant execute on function public.world_region_dist(uuid) to fn_owner_field;

CREATE OR REPLACE FUNCTION public.world_item_sources_all(p_item text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  with hp as materialized (select coalesce(public.world_region_dist(public.fn_owner_auth_uid()) -> 'd', '{}'::jsonb) as d),
       g as (select distinct r.region_name, r.min_level from public.world_gathering_spots s join public.world_exploration_nodes n on n.node_id = s.node_id
               join public.world_map_regions r on r.region_id = n.region_id where s.active and p_item = any (s.loot_items) and public.world_source_region_ok('gather', r.is_safe_zone, r.active)),
       t as (select distinct r.region_name, r.min_level from public.world_region_sites s join public.world_map_regions r using (region_id)
               where s.active and (s.loot_table ? p_item or s.bonus_item = p_item) and public.world_source_region_ok('sites', r.is_safe_zone, r.active)),
       m as (select distinct r.region_name, r.min_level from public.world_region_monsters x join public.world_map_regions r using (region_id) where x.drops ? p_item and public.world_source_region_ok('monsters', r.is_safe_zone, r.active)),
       f as (select distinct r.region_name, r.min_level from public.world_fish_species sp join public.world_fish_grounds fg on fg.habitat = sp.habitat
               join public.world_map_regions r on r.region_id = fg.region_id where sp.fish_id = p_item and sp.active and (sp.grounds is null or fg.region_id = any(sp.grounds)) and public.world_source_region_ok('fish', r.is_safe_zone, r.active)),
       z as (select distinct r.region_name, r.min_level from public.world_meisho x join public.world_map_regions r using (region_id)
               where x.active and (public.world_item_base(p_item) in (select jsonb_array_elements_text(public.world_meisho_rules() -> 'kinds' -> x.kind -> 'items'))
                 or (public.world_item_base(p_item) = public.world_meisho_rules() -> 'lamp' -> 'items' ->> x.kind and r.territory_id in (select jsonb_array_elements_text(public.world_meisho_rules() -> 'lamp' -> 'territory')))
                 or public.world_bijang_tier_of(public.world_item_base(p_item)) = public.world_meisho_grade(x.min_level))),
       ng as (select x.region_name, (hp.d -> x.region_name ->> 0)::int as h, (hp.d -> x.region_name ->> 1)::float8 as c from g x, hp where hp.d ? x.region_name order by 3, x.min_level, x.region_name limit 1),
       nz as (select x.region_name, (hp.d -> x.region_name ->> 0)::int as h, (hp.d -> x.region_name ->> 1)::float8 as c from z x, hp where hp.d ? x.region_name order by 3, x.min_level, x.region_name limit 1),
       nm as (select x.region_name, (hp.d -> x.region_name ->> 0)::int as h, (hp.d -> x.region_name ->> 1)::float8 as c from m x, hp where hp.d ? x.region_name order by 3, x.min_level, x.region_name limit 1),
       nt as (select x.region_name, (hp.d -> x.region_name ->> 0)::int as h, (hp.d -> x.region_name ->> 1)::float8 as c from t x, hp where hp.d ? x.region_name order by 3, x.min_level, x.region_name limit 1),
       nf as (select x.region_name, (hp.d -> x.region_name ->> 0)::int as h, (hp.d -> x.region_name ->> 1)::float8 as c from f x, hp where hp.d ? x.region_name order by 3, x.min_level, x.region_name limit 1)
  select jsonb_build_object(
    'meisho', (select coalesce(jsonb_agg(region_name order by coalesce(region_name = (select region_name from nz), false) desc, min_level, region_name), '[]') from z), 'meisho_n', (select count(*) from z),
    'gather', (select coalesce(jsonb_agg(region_name order by coalesce(region_name = (select region_name from ng), false) desc, min_level, region_name), '[]') from g), 'gather_n', (select count(*) from g),
    'sites', (select coalesce(jsonb_agg(region_name order by coalesce(region_name = (select region_name from nt), false) desc, min_level, region_name), '[]') from t), 'sites_n', (select count(*) from t),
    'monsters', (select coalesce(jsonb_agg(region_name order by coalesce(region_name = (select region_name from nm), false) desc, min_level, region_name), '[]') from m), 'monsters_n', (select count(*) from m),
    'fish', (select coalesce(jsonb_agg(region_name order by coalesce(region_name = (select region_name from nf), false) desc, min_level, region_name), '[]') from f), 'fish_n', (select count(*) from f),
    'near', jsonb_strip_nulls(jsonb_build_object('meisho', (select jsonb_build_object('r', region_name, 'h', h, 'c', round(c::numeric)) from nz), 'gather', (select jsonb_build_object('r', region_name, 'h', h, 'c', round(c::numeric)) from ng), 'sites', (select jsonb_build_object('r', region_name, 'h', h, 'c', round(c::numeric)) from nt), 'monsters', (select jsonb_build_object('r', region_name, 'h', h, 'c', round(c::numeric)) from nm), 'fish', (select jsonb_build_object('r', region_name, 'h', h, 'c', round(c::numeric)) from nf))),
    'craft', exists (select 1 from public.world_crafting_recipes where output_item = public.world_item_base(p_item)), 'hq', p_item like '%\_hq',
    'shop', exists (select 1 from public.world_shop_catalog where item_id = p_item and shop_id <> 'smithy'),
    'smithy', exists (select 1 from public.world_shop_catalog where item_id = p_item and shop_id = 'smithy'),
    'vault', exists (select 1 from public.world_faction_vault where item_id = p_item),
    'luck', public.world_pet_egg_rules() -> 'eggs' ? p_item,
    'token', case when public.world_pet_egg_rules() #>> '{token,egg}' = p_item then (public.world_pet_egg_rules() #>> '{token,n}')::int end,
    'luck', public.world_pet_egg_rules() -> 'eggs' ? p_item,
    'token', case when public.world_pet_egg_rules() #>> '{token,egg}' = p_item then (public.world_pet_egg_rules() #>> '{token,n}')::int end,
    'bijang', case when exists (select 1 from jsonb_each(public.world_bijang_rules() -> 'final' -> 'tiers') ft, jsonb_array_elements(ft.value) v where v ->> 'id' = public.world_item_base(p_item)) then 'final'
      when exists (select 1 from jsonb_each(public.world_bijang_rules() -> 'chest') c, jsonb_array_elements(c.value -> 'items') v where v ->> 'id' = public.world_item_base(p_item)) then 'chest' end)
$function$;

create or replace function public.world_item_sources(p_item text) returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $f$
declare s jsonb := public.world_item_sources_all(p_item); k text;
begin
  foreach k in array array['gather', 'sites', 'monsters', 'fish', 'meisho'] loop
    s := jsonb_set(s, array[k], coalesce((select jsonb_agg(v order by o) from jsonb_array_elements(s -> k) with ordinality a(v, o) where o <= 6), '[]'::jsonb));
  end loop;
  return s;
end $f$;

select pg_temp.yh_patch('public.world_gather_codex_snapshot()'::regprocedure, 'declare uid uuid := public.fn_owner_auth_uid();', 'declare uid uuid := public.fn_owner_auth_uid(); dm jsonb := coalesce(public.world_region_dist(public.fn_owner_auth_uid()) -> ''d'', ''{}''::jsonb);');
select pg_temp.yh_patch('public.world_gather_codex_snapshot()'::regprocedure, ' order by 2 limit 6) z) as regions', ' order by 2 limit 6) z) as regions,
          (select z.n from (select distinct r2.region_name as n, coalesce(r2.min_level, 1) as l from public.world_gathering_spots s2
             join public.world_exploration_nodes n2 on n2.node_id = s2.node_id join public.world_map_regions r2 on r2.region_id = n2.region_id
            where s2.active and x = any (s2.loot_items) and public.world_source_region_ok(''gather'', r2.is_safe_zone, r2.active) and dm ? r2.region_name) z
            order by (dm -> z.n ->> 1)::float8, z.l, z.n limit 1) as nr');
select pg_temp.yh_patch('public.world_gather_codex_snapshot()'::regprocedure, 'order by rr.l, rr.n) from (', 'order by coalesce(rr.n = it.nr, false) desc, rr.l, rr.n) from (');
select pg_temp.yh_patch('public.world_gather_codex_snapshot()'::regprocedure, 'group by q.n order by 2, 1 limit 8) rr)', 'group by q.n order by coalesce(q.n = it.nr, false) desc, 2, 1 limit 8) rr), ''near'', case when it.nr is not null then jsonb_build_object(''r'', it.nr, ''h'', (dm -> it.nr ->> 0)::int) end');

create or replace function public.world_garden_rules() returns jsonb language sql immutable as $f$ select '{
  "start": 2, "max": 4,
  "expand": [{"size": 3, "gil": 5000, "items": {"ward_fragment": 15, "beast_hide": 10}}, {"size": 4, "gil": 15000, "items": {"ember_crystal": 8, "lantern_oil": 8}}],
  "hours": {"1": 12, "2": 16, "3": 20, "4": 24},
  "water_h": 24, "yield": [3, 5], "rot_h": 48,
  "crow": {"every_h": 3, "p": 0.15, "bite": 1, "max_ticks": 24},
  "scare": {"item": "garden_scarecrow", "days": 7, "price": 300},
  "fert": {"ghost_ash": {"kind": "speed", "pct": 30}, "drowned_scale": {"kind": "speed", "pct": 50}, "beast_bone": {"kind": "more", "n": 2}, "venom_gland": {"kind": "more", "n": 4}},
  "fert_n": {"1": 1, "2": 1, "3": 2, "4": 2},
  "crops": ["fd_potato", "fd_greens", "fd_mushroom", "fd_rice", "fd_minari", "fd_sweet_potato", "fd_garlic", "fd_ginger", "fd_jujube", "fd_buckwheat", "fd_chestnut", "fd_lotus_root", "fd_deodeok", "fd_chili", "fd_spice_seed", "fd_meokbi_fern", "fd_white_rice"]
}'::jsonb $f$;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, use_fx, crafting_specialization) values
  ('garden_scarecrow', '허수아비', 'consumable', 2, '별채 뒤뜰 밭 한 칸에 세우면 이레 동안 까마귀가 내려앉지 않는다. 날이 지나면 낡아 쓰러진다.', true, true, 300, 50, null, 'carpentry')
on conflict (item_id) do nothing;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field) values
  ('r_garden_scarecrow', '허수아비 만들기', 'garden_scarecrow', 1, '{"resin": 3, "beast_fang": 2}'::jsonb, null, 1, null, '부적목 수지로 굳힌 짚단에 요수 송곳니를 눈알처럼 박아 까마귀를 겁준다.', 5, null, 1, 0, null, 1, 'carpentry')
on conflict (recipe_id) do nothing;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, 'garden_scarecrow', 300, s.stock_min, s.stock_max, null from public.world_shop_catalog s where s.item_id = 'pet_medicine'
on conflict do nothing;

select pg_temp.yh_patch('public.world_shop_refresh(text)'::regprocedure, '''pet_food'',', '''pet_food'', ''garden_scarecrow'',');

create table if not exists public.world_gardens (
  owner_id uuid primary key references public.world_housing(owner_id) on delete cascade,
  size int not null default 2,
  scare_cell int, scare_until timestamptz,
  crow_cell int, crow_at timestamptz,
  tick_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create table if not exists public.world_garden_plots (
  owner_id uuid not null references public.world_gardens(owner_id) on delete cascade,
  cell int not null,
  item_id text not null,
  planted_at timestamptz not null default now(),
  grow_s int not null,
  grown_s numeric not null default 0,
  calc_at timestamptz not null default now(),
  water_until timestamptz,
  fert text,
  yield int not null,
  eaten int not null default 0,
  primary key (owner_id, cell)
);
alter table public.world_gardens enable row level security;
alter table public.world_garden_plots enable row level security;
revoke all on public.world_gardens, public.world_garden_plots from anon, authenticated;
grant select, insert, update, delete on public.world_gardens, public.world_garden_plots to fn_owner_field;

create or replace function public.world_garden_grown(p public.world_garden_plots, t timestamptz) returns numeric language sql immutable as $f$
  select p.grown_s + case when p.water_until is null or p.water_until <= p.calc_at or t <= p.calc_at then 0
    else extract(epoch from least(t, p.water_until) - p.calc_at) end
$f$;

create or replace function public.world_garden_ripe_at(p public.world_garden_plots) returns timestamptz language sql immutable as $f$
  select case when p.grown_s >= p.grow_s then p.calc_at
    when p.water_until is not null and p.calc_at + make_interval(secs => (p.grow_s - p.grown_s)::float8) <= p.water_until
      then p.calc_at + make_interval(secs => (p.grow_s - p.grown_s)::float8) end
$f$;

create or replace function public.world_garden_settle(p_home uuid, p_cell int) returns void language sql as $f$
  update public.world_garden_plots p set grown_s = least(p.grow_s, public.world_garden_grown(p, now())), calc_at = now()
   where p.owner_id = p_home and p.cell = p_cell
$f$;

create or replace function public.world_garden_sync(p_home uuid) returns public.world_gardens language plpgsql security definer set search_path = pg_catalog, public as $f$
declare g public.world_gardens%rowtype; r jsonb := public.world_garden_rules(); ev interval; t timestamptz; n int := 0; p public.world_garden_plots%rowtype; rot interval;
  mx int; target int;
begin
  insert into public.world_gardens(owner_id, size) values (p_home, (r ->> 'start')::int) on conflict do nothing;
  select * into g from public.world_gardens where owner_id = p_home for update;
  ev := make_interval(hours => (r -> 'crow' ->> 'every_h')::int);
  rot := make_interval(hours => (r ->> 'rot_h')::int);
  mx := (r -> 'crow' ->> 'max_ticks')::int;
  if g.tick_at + ev * mx < now() then g.tick_at := now() - ev * mx; end if;
  while g.tick_at + ev <= now() loop
    t := g.tick_at + ev;
    if g.crow_cell is not null then
      select * into p from public.world_garden_plots x where x.owner_id = p_home and x.cell = g.crow_cell and x.planted_at <= t;
      if not found or (public.world_garden_ripe_at(p) is not null and public.world_garden_ripe_at(p) + rot <= t) then
        g.crow_cell := null; g.crow_at := null;
      elsif t >= g.crow_at + ev then
        update public.world_garden_plots set eaten = eaten + (r -> 'crow' ->> 'bite')::int where owner_id = p_home and cell = g.crow_cell returning * into p;
        g.crow_at := t;
        if p.yield - p.eaten <= 0 then
          delete from public.world_garden_plots where owner_id = p_home and cell = g.crow_cell;
          g.crow_cell := null; g.crow_at := null;
        end if;
      end if;
    elsif (g.scare_until is null or g.scare_until <= t) and random() < (r -> 'crow' ->> 'p')::numeric then
      select x.cell into target from public.world_garden_plots x where x.owner_id = p_home and x.planted_at <= t
         and (public.world_garden_ripe_at(x) is null or public.world_garden_ripe_at(x) + rot > t)
       order by random() limit 1;
      if target is not null then
        update public.world_garden_plots set eaten = eaten + (r -> 'crow' ->> 'bite')::int where owner_id = p_home and cell = target returning * into p;
        if p.yield - p.eaten <= 0 then
          delete from public.world_garden_plots where owner_id = p_home and cell = target;
        else
          g.crow_cell := target; g.crow_at := t;
        end if;
      end if;
    end if;
    g.tick_at := t; n := n + 1;
  end loop;
  if g.scare_until is not null and g.scare_until <= now() then g.scare_cell := null; g.scare_until := null; end if;
  if n > 0 or (g.scare_until is null and g.scare_cell is not null) then
    update public.world_gardens set tick_at = g.tick_at, crow_cell = g.crow_cell, crow_at = g.crow_at, scare_cell = g.scare_cell, scare_until = g.scare_until where owner_id = p_home;
  elsif g.scare_cell is not null and g.scare_until is null then
    update public.world_gardens set scare_cell = null where owner_id = p_home;
  end if;
  select * into g from public.world_gardens where owner_id = p_home;
  return g;
end $f$;

create or replace function public.world_garden_who(p_uid uuid, p_owner uuid, p_tend boolean) returns uuid language plpgsql security definer set search_path = pg_catalog, public as $f$
declare h public.world_housing%rowtype; why text;
begin
  if p_uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into h from public.world_housing where owner_id = public.world_housing_home(coalesce(p_owner, p_uid));
  if not found then raise exception '%', case when p_owner is null or p_owner = p_uid then '별채를 얻은 뒤에 뒤뜰 밭을 쓸 수 있습니다.' else '별채가 없는 조사원입니다.' end; end if;
  if p_tend then
    if not (p_uid = h.owner_id or p_uid = public.world_housing_mate(h.owner_id)) then raise exception '밭은 별채 주인만 가꿀 수 있습니다.'; end if;
  else
    why := public.world_housing_can_view(p_uid, h.owner_id, h.gate);
    if why is not null then raise exception '%', why; end if;
  end if;
  return h.owner_id;
end $f$;

create or replace function public.world_garden_cell_ok(p_size int, p_cell int) returns boolean language sql immutable as $f$
  select p_cell between 0 and 15 and p_cell % 4 < p_size and p_cell / 4 < p_size
$f$;

create or replace function public.world_garden_place(p_uid uuid) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare loc text; safe boolean;
begin
  select location into loc from public.world_characters where owner_id = p_uid;
  safe := coalesce((public.world_field_region(loc)).is_safe_zone, false);
  return jsonb_build_object('safe', safe, 'storage', safe and not public.world_weak_here(p_uid, 'storage'),
    'why', case when not safe then '심기와 거두기는 안전지대에서만 할 수 있습니다. 물 주기와 까마귀 쫓기는 어디서나 됩니다.' end);
end $f$;

create or replace function public.world_garden_view(p_owner uuid default null) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid(); home uuid; g public.world_gardens%rowtype; r jsonb := public.world_garden_rules(); own boolean; inv jsonb; st jsonb; nx jsonb; rot interval; pl jsonb;
begin
  home := public.world_garden_who(uid, p_owner, false);
  own := uid = home or uid = public.world_housing_mate(home);
  g := public.world_garden_sync(home);
  rot := make_interval(hours => (r ->> 'rot_h')::int);
  pl := public.world_garden_place(uid);
  select inventory into inv from public.world_characters where owner_id = uid;
  inv := coalesce(inv, '{}'::jsonb);
  select items into st from public.world_storage where owner_id = uid;
  st := case when (pl ->> 'storage')::boolean then coalesce(st, '{}'::jsonb) else '{}'::jsonb end;
  nx := (select e from jsonb_array_elements(r -> 'expand') e where (e ->> 'size')::int = g.size + 1);
  return jsonb_build_object(
    'owner', home, 'owner_name', (select character_name from public.world_characters where owner_id = home), 'own', own, 'now', now(),
    'size', g.size, 'max', (r ->> 'max')::int, 'place', pl,
    'next', case when own and nx is not null then nx || jsonb_build_object('names', (select jsonb_object_agg(k, ic.item_name) from jsonb_object_keys(nx -> 'items') k join public.world_item_catalog ic on ic.item_id = k)) end,
    'scare', case when g.scare_cell is not null then jsonb_build_object('cell', g.scare_cell, 'until', g.scare_until) end,
    'crow', case when g.crow_cell is not null then jsonb_build_object('cell', g.crow_cell, 'at', g.crow_at, 'next', g.crow_at + make_interval(hours => (r -> 'crow' ->> 'every_h')::int)) end,
    'plots', (select coalesce(jsonb_agg(jsonb_build_object('cell', p.cell, 'item', p.item_id, 'name', ic.item_name, 'tier', ic.tier,
        'grow_s', p.grow_s, 'grown_s', round(least(p.grow_s, public.world_garden_grown(p, now()))), 'water_until', p.water_until,
        'ripe_at', public.world_garden_ripe_at(p), 'rot_at', public.world_garden_ripe_at(p) + rot, 'planted_at', p.planted_at,
        'fert', p.fert, 'fert_name', fc.item_name, 'yield', case when own then greatest(0, p.yield - p.eaten) end, 'eaten', p.eaten) order by p.cell), '[]'::jsonb)
      from public.world_garden_plots p join public.world_item_catalog ic on ic.item_id = p.item_id left join public.world_item_catalog fc on fc.item_id = p.fert where p.owner_id = home),
    'crops', case when own then (select jsonb_agg(jsonb_build_object('id', c, 'name', ic.item_name, 'tier', ic.tier, 'hours', (r -> 'hours' ->> ic.tier::text)::int,
        'have', coalesce((inv ->> c)::int, 0) + coalesce((st ->> c)::int, 0), 'stored', coalesce((st ->> c)::int, 0)) order by ic.tier, o)
      from jsonb_array_elements_text(r -> 'crops') with ordinality x(c, o) join public.world_item_catalog ic on ic.item_id = x.c) end,
    'ferts', case when own then (select jsonb_agg(jsonb_build_object('id', f.key, 'name', ic.item_name, 'kind', f.value ->> 'kind', 'pct', (f.value ->> 'pct')::int, 'n', (f.value ->> 'n')::int,
        'have', coalesce((inv ->> f.key)::int, 0) + coalesce((st ->> f.key)::int, 0), 'stored', coalesce((st ->> f.key)::int, 0)) order by f.value ->> 'kind' desc, f.key)
      from jsonb_each(r -> 'fert') f join public.world_item_catalog ic on ic.item_id = f.key) end,
    'scare_have', case when own then coalesce((inv ->> (r -> 'scare' ->> 'item'))::int, 0) + coalesce((st ->> (r -> 'scare' ->> 'item'))::int, 0) end,
    'rules', jsonb_build_object('hours', r -> 'hours', 'water_h', r -> 'water_h', 'yield', r -> 'yield', 'rot_h', r -> 'rot_h', 'crow', r -> 'crow', 'scare', r -> 'scare', 'fert_n', r -> 'fert_n'));
end $f$;

create or replace function public.world_garden_take(p_uid uuid, p_need jsonb) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare c public.world_characters%rowtype; st jsonb; mt jsonb; ok boolean := (public.world_garden_place(p_uid) ->> 'storage')::boolean;
begin
  select * into c from public.world_characters where owner_id = p_uid for update;
  if ok then select items into st from public.world_storage where owner_id = p_uid for update; end if;
  mt := public.world_materials_take(coalesce(c.inventory, '{}'::jsonb), case when ok then coalesce(st, '{}'::jsonb) else '{}'::jsonb end, p_need);
  update public.world_characters set inventory = mt -> 'inv', updated_at = now() where owner_id = p_uid;
  if ok and mt -> 'from_st' <> '{}'::jsonb then
    update public.world_storage set items = (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(mt -> 'st') where jsonb_typeof(value) = 'number' and value::text::int > 0), updated_at = now() where owner_id = p_uid;
  end if;
  return mt -> 'from_st';
end $f$;

create or replace function public.world_garden_act(p_act text, p_cell int default null, p_item text default null, p_owner uuid default null, p_fert text default null) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid(); home uuid; g public.world_gardens%rowtype; r jsonb := public.world_garden_rules(); p public.world_garden_plots%rowtype;
  tr int; nm text; f jsonb; n int; got jsonb := '{}'::jsonb; inv jsonb; k text; v int; cnt int := 0; left_n int := 0; why text; nx jsonb; c public.world_characters%rowtype;
  rot interval := make_interval(hours => (r ->> 'rot_h')::int); vn text; msg text; fs jsonb := '{}'::jsonb; need jsonb; pl jsonb; lim int;
begin
  perform public.world_seal_guard();
  if p_act = 'shoo' then
    home := public.world_garden_who(uid, p_owner, false);
    g := public.world_garden_sync(home);
    if g.crow_cell is null then raise exception '밭에 앉은 까마귀가 없습니다.'; end if;
    update public.world_gardens set crow_cell = null, crow_at = null where owner_id = home;
    if uid <> home and uid is distinct from public.world_housing_mate(home) then
      select character_name into vn from public.world_characters where owner_id = uid;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (home, 'garden_shoo', '뒤뜰 밭', vn || '님이 밭에 앉은 까마귀를 쫓아 주었습니다.', jsonb_build_object('visitor', uid));
    end if;
    return jsonb_build_object('ok', true, 'content', '훠이! 까마귀가 날아갔습니다.');
  end if;
  home := public.world_garden_who(uid, p_owner, true);
  if p_act = 'expand' then
    why := public.world_housing_edit_block(uid);
    if why is not null then raise exception '%', replace(replace(why, '별채는 안전지대에서만 고칠 수 있습니다. 바깥에서는 구경만 됩니다.', '밭은 안전지대에서만 넓힐 수 있습니다.'), '별채를 고칠', '밭을 넓힐'); end if;
  else
    perform public.world_travel_guard('밭 가꾸기');
  end if;
  if p_act in ('plant', 'harvest', 'scare') then
    pl := public.world_garden_place(uid);
    if not (pl ->> 'safe')::boolean then raise exception '%', pl ->> 'why'; end if;
  end if;
  g := public.world_garden_sync(home);
  if p_cell is not null and p_act in ('plant', 'water', 'harvest', 'clear', 'scare') and not public.world_garden_cell_ok(g.size, p_cell) then raise exception '밭에 없는 칸입니다.'; end if;
  if p_act = 'plant' then
    if p_cell is null or p_item is null then raise exception '심을 칸과 작물을 고르세요.'; end if;
    if not (r -> 'crops' ? p_item) then raise exception '밭에 심을 수 없는 물품입니다.'; end if;
    if g.scare_cell = p_cell then raise exception '허수아비가 서 있는 칸입니다.'; end if;
    if exists (select 1 from public.world_garden_plots where owner_id = home and cell = p_cell) then raise exception '이미 작물이 있는 칸입니다.'; end if;
    select ic.tier, ic.item_name into tr, nm from public.world_item_catalog ic where ic.item_id = p_item;
    need := jsonb_build_object(p_item, 1);
    if p_fert is not null then
      f := r -> 'fert' -> p_fert;
      if f is null then raise exception '비료로 쓸 수 없는 물품입니다.'; end if;
      n := (r -> 'fert_n' ->> tr::text)::int;
      need := need || jsonb_build_object(p_fert, n);
    end if;
    fs := public.world_garden_take(uid, need);
    insert into public.world_garden_plots(owner_id, cell, item_id, grow_s, yield, fert)
    values (home, p_cell, p_item,
      ceil((r -> 'hours' ->> tr::text)::int * 3600 * case when f ->> 'kind' = 'speed' then 1 - (f ->> 'pct')::numeric / 100 else 1 end)::int,
      (r -> 'yield' ->> 0)::int + floor(random() * ((r -> 'yield' ->> 1)::int - (r -> 'yield' ->> 0)::int + 1))::int + case when f ->> 'kind' = 'more' then (f ->> 'n')::int else 0 end,
      p_fert);
    msg := public.world_josa(nm, '을', '를') || ' 심었습니다' || case when p_fert is not null then '(' || (select item_name from public.world_item_catalog where item_id = p_fert) || ' ' || n || '개)' else '' end || '. 물을 주어야 자랍니다.';
  elsif p_act = 'water' then
    for p in select * from public.world_garden_plots x where x.owner_id = home and (p_cell is null or x.cell = p_cell) and coalesce(public.world_garden_ripe_at(x) > now(), true) loop
      perform public.world_garden_settle(home, p.cell);
      update public.world_garden_plots set water_until = now() + make_interval(hours => (r ->> 'water_h')::int) where owner_id = home and cell = p.cell;
      cnt := cnt + 1;
    end loop;
    if cnt = 0 then raise exception '물을 줄 작물이 없습니다. 다 자란 작물에는 물을 주지 않아도 됩니다.'; end if;
    msg := case when cnt = 1 then '물을 주었습니다.' else cnt || '칸에 물을 주었습니다.' end;
  elsif p_act = 'harvest' then
    select * into c from public.world_characters where owner_id = uid for update;
    inv := coalesce(c.inventory, '{}'::jsonb);
    lim := public.world_bag_limit(uid);
    for p in select * from public.world_garden_plots x where x.owner_id = home and (p_cell is null or x.cell = p_cell)
        and public.world_garden_ripe_at(x) <= now() and public.world_garden_ripe_at(x) + rot > now() order by x.cell for update loop
      v := greatest(0, p.yield - p.eaten);
      if v > 0 and public.world_bag_room(inv, p.item_id, lim) < v then left_n := left_n + 1; continue; end if;
      if v > 0 then inv := public.world_inv_add(inv, p.item_id, v); got := jsonb_set(got, array[p.item_id], to_jsonb(coalesce((got ->> p.item_id)::int, 0) + v)); end if;
      delete from public.world_garden_plots where owner_id = home and cell = p.cell;
      if g.crow_cell = p.cell then update public.world_gardens set crow_cell = null, crow_at = null where owner_id = home; end if;
      cnt := cnt + 1;
    end loop;
    if cnt = 0 and left_n > 0 then raise exception '가방에 자리가 없어 거둘 수 없습니다. 가방을 비운 뒤 거두세요.'; end if;
    if cnt = 0 then raise exception '%', case when p_cell is not null and exists (select 1 from public.world_garden_plots x where x.owner_id = home and x.cell = p_cell and public.world_garden_ripe_at(x) + rot <= now()) then '썩은 작물은 거둘 수 없습니다. 치워 주세요.' else '거둘 작물이 없습니다. 다 자란 작물만 거둡니다.' end; end if;
    update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
    msg := (select string_agg(ic.item_name || ' ' || x.value || '개', ', ') from jsonb_each_text(got) x join public.world_item_catalog ic on ic.item_id = x.key where x.value::int > 0);
    msg := coalesce(msg || '를 가방에 거두었습니다.', '까마귀가 다 먹어 거둘 것이 없었습니다.') || case when left_n > 0 then ' 가방에 자리가 모자라 ' || left_n || '칸은 남겨 두었습니다.' else '' end;
  elsif p_act = 'clear' then
    delete from public.world_garden_plots where owner_id = home and cell = p_cell returning item_id into k;
    if k is null then raise exception '치울 작물이 없습니다.'; end if;
    if g.crow_cell = p_cell then update public.world_gardens set crow_cell = null, crow_at = null where owner_id = home; end if;
    msg := '칸을 비웠습니다.';
  elsif p_act = 'scare' then
    if p_cell is null then raise exception '허수아비를 세울 칸을 고르세요.'; end if;
    if g.scare_until is not null and g.scare_until > now() then raise exception '허수아비가 이미 서 있습니다. 낡아 쓰러진 뒤에 새로 세울 수 있습니다.'; end if;
    if exists (select 1 from public.world_garden_plots where owner_id = home and cell = p_cell) then raise exception '작물이 있는 칸에는 세울 수 없습니다.'; end if;
    fs := public.world_garden_take(uid, jsonb_build_object(r -> 'scare' ->> 'item', 1));
    update public.world_gardens set scare_cell = p_cell, scare_until = now() + make_interval(days => (r -> 'scare' ->> 'days')::int) where owner_id = home;
    msg := '허수아비를 세웠습니다. ' || (r -> 'scare' ->> 'days') || '일 동안 까마귀가 내려앉지 않습니다.';
  elsif p_act = 'expand' then
    nx := (select e from jsonb_array_elements(r -> 'expand') e where (e ->> 'size')::int = g.size + 1);
    if nx is null then raise exception '밭은 %×%가 가장 넓습니다.', r ->> 'max', r ->> 'max'; end if;
    select * into c from public.world_characters where owner_id = uid for update;
    if c.gil < (nx ->> 'gil')::int then raise exception '%전이 필요합니다. (가진 전 %)', nx ->> 'gil', c.gil; end if;
    fs := public.world_garden_take(uid, nx -> 'items');
    update public.world_characters set gil = gil - (nx ->> 'gil')::int, updated_at = now() where owner_id = uid;
    update public.world_gardens set size = (nx ->> 'size')::int where owner_id = home;
    insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'garden_expand', -(nx ->> 'gil')::int, true, jsonb_build_object('size', nx -> 'size'));
    msg := '밭을 ' || (nx ->> 'size') || '×' || (nx ->> 'size') || '로 넓혔습니다.';
  else
    raise exception '알 수 없는 밭 일입니다.';
  end if;
  return jsonb_build_object('ok', true, 'content', msg, 'got', case when p_act = 'harvest' then got end, 'from_storage', fs);
end $f$;

do $o$ declare f text; x text; g boolean := not has_schema_privilege('fn_owner_field', 'public', 'CREATE'); begin
  foreach f in array array['world_garden_rules()', 'world_garden_grown(world_garden_plots, timestamptz)', 'world_garden_ripe_at(world_garden_plots)', 'world_garden_settle(uuid, integer)', 'world_garden_sync(uuid)', 'world_garden_who(uuid, uuid, boolean)', 'world_garden_cell_ok(integer, integer)', 'world_garden_view(uuid)', 'world_garden_take(uuid, jsonb)', 'world_garden_place(uuid)', 'world_garden_act(text, integer, text, uuid, text)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
      execute format('grant execute on function public.%s to %I', f, x);
    end loop;
  end loop;
  grant execute on function public.world_garden_view(uuid), public.world_garden_act(text, integer, text, uuid, text) to authenticated;
  if g then grant create on schema public to fn_owner_field; end if;
  foreach f in array array['world_garden_settle(uuid, integer)', 'world_garden_sync(uuid)', 'world_garden_who(uuid, uuid, boolean)', 'world_garden_view(uuid)', 'world_garden_take(uuid, jsonb)', 'world_garden_place(uuid)', 'world_garden_act(text, integer, text, uuid, text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
  end loop;
  if g then revoke create on schema public from fn_owner_field; end if;
end $o$;

select pg_temp.yh_patch('public.world_character_purge(uuid)'::regprocedure, '    delete from public.world_housing_store where owner_id = p_uid;', '    delete from public.world_garden_plots where owner_id = p_uid;
    delete from public.world_gardens where owner_id = p_uid;
    delete from public.world_housing_store where owner_id = p_uid;');

select pg_temp.yh_patch('public.world_notify_group(text)'::regprocedure, '''pet_clean'', ''pet_new''', '''pet_clean'', ''garden_shoo'', ''pet_new''');

create or replace function public.world_bond_emote_rules() returns jsonb language sql immutable as $f$ select '{
  "emotes": [{"k": "hug", "name": "포옹하기", "icon": "heart"}, {"k": "hand", "name": "손 잡기", "icon": "heart"}, {"k": "pat", "name": "머리 쓰다듬기", "icon": "spark"},
    {"k": "tease", "name": "장난치기", "icon": "sweat"}, {"k": "praise", "name": "칭찬하기", "icon": "spark"}, {"k": "comfort", "name": "위로하기", "icon": "heart"},
    {"k": "five", "name": "하이파이브", "icon": "spark"}, {"k": "dance", "name": "함께 춤추기", "icon": "note"}],
  "tiers": [{"min": 0, "key": "t1", "name": "설렘"}, {"min": 300, "key": "t2", "name": "편안함"}, {"min": 1000, "key": "t3", "name": "애틋함"}, {"min": 2500, "key": "t4", "name": "오랜 사이"}],
  "day": 10, "gap_s": 3, "gain": 2, "state_p": 0.5, "weather_p": 0.25, "erosion": 55, "hp": 35, "exp_h": 1,
  "weather": {"rain": "rain", "drizzle": "rain", "snow": "snow", "fog": "fog", "wind": "wind", "bloodmist": "bloodmist"}
}'::jsonb $f$;

create table if not exists public.world_bond_emote_lines (
  id serial primary key, emote text not null, ctx text not null, tier text not null, line text not null
);
create index if not exists idx_world_bond_emote_lines_k on public.world_bond_emote_lines(ctx, emote, tier);
create table if not exists public.world_bond_emotes (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  day date, n int not null default 0, last_at timestamptz, gain_day date, phase_seen text, last_line int
);
alter table public.world_bond_emote_lines enable row level security;
alter table public.world_bond_emotes enable row level security;
revoke all on public.world_bond_emote_lines, public.world_bond_emotes from anon, authenticated;
grant select on public.world_bond_emote_lines to fn_owner_field;
grant select, insert, update, delete on public.world_bond_emotes to fn_owner_field;

create or replace function public.world_bond_emote_left(p_uid uuid) returns int language sql stable security definer set search_path = pg_catalog, public as $f$
  select greatest(0, (public.world_bond_emote_rules() ->> 'day')::int - coalesce((select e.n from public.world_bond_emotes e where e.owner_id = p_uid and e.day = public.world_bond_day()), 0))
$f$;

create or replace function public.world_bond_emote(p_emote text) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_bond_emote_rules(); b public.world_bonds%rowtype; pid uuid; e public.world_bond_emotes%rowtype;
  c public.world_characters%rowtype; today date := public.world_bond_day(); v_tier text; tname text; em jsonb; v_ctx text := null; ph text; wk text; reg public.world_map_regions%rowtype;
  ln public.world_bond_emote_lines%rowtype; gained int := 0; pname text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  em := (select x from jsonb_array_elements(r -> 'emotes') x where x ->> 'k' = p_emote);
  if em is null then raise exception '알 수 없는 상호작용입니다.'; end if;
  b := public.world_bond_active(uid);
  if b.bond_id is null then raise exception '연리를 맺은 정인이 없습니다.'; end if;
  pid := case when b.a_id = uid then b.b_id else b.a_id end;
  insert into public.world_bond_emotes(owner_id) values (uid) on conflict do nothing;
  select * into e from public.world_bond_emotes where owner_id = uid for update;
  if e.last_at is not null and e.last_at + make_interval(secs => (r ->> 'gap_s')::int) > now() then
    raise exception '조금 천천히 해 주세요.' using hint = 'rate';
  end if;
  if e.day is distinct from today then e.n := 0; end if;
  if e.n >= (r ->> 'day')::int then raise exception '오늘은 상호작용을 다 했습니다. 하루 %번까지입니다.', r ->> 'day'; end if;
  select x ->> 'key', x ->> 'name' into v_tier, tname from jsonb_array_elements(r -> 'tiers') x where (x ->> 'min')::int <= b.affinity order by (x ->> 'min')::int desc limit 1;
  select * into c from public.world_characters where owner_id = uid;
  select character_name into pname from public.world_characters where owner_id = pid;
  if random() < (r ->> 'state_p')::numeric then
    v_ctx := case
      when exists (select 1 from public.world_character_statuses s where s.owner_id = uid and s.status_key = 'yohwa') then 'st:yohwa'
      when coalesce(c.erosion, 0) >= (r ->> 'erosion')::int then 'st:erosion'
      when coalesce(c.health, 100) <= (r ->> 'hp')::int then 'st:hp'
      when exists (select 1 from public.world_events v where v.actor_id = uid and v.event_type = 'expedition_end' and v.created_at > now() - make_interval(hours => (r ->> 'exp_h')::int)) then 'st:exp'
    end;
  end if;
  ph := public.world_time_phase(now());
  if v_ctx is null and e.phase_seen is distinct from (today::text || ph) then v_ctx := 'time:' || ph; end if;
  if v_ctx is null and random() < (r ->> 'weather_p')::numeric then
    reg := public.world_field_region(c.location);
    wk := r -> 'weather' ->> public.world_weather_key(reg.territory_id, now());
    if wk is not null then v_ctx := 'w:' || wk; end if;
  end if;
  if v_ctx is not null then
    select * into ln from public.world_bond_emote_lines l where l.ctx = v_ctx and l.tier in (v_tier, 'all') and l.id is distinct from e.last_line order by random() limit 1;
  end if;
  if ln.id is null then
    select * into ln from public.world_bond_emote_lines l where l.ctx = 'base' and l.emote = p_emote and l.tier in (v_tier, 'all') and l.id is distinct from e.last_line order by random() limit 1;
  end if;
  if e.gain_day is distinct from today then
    gained := public.world_bond_gain(b.bond_id, (r ->> 'gain')::int, 'emote');
  end if;
  update public.world_bond_emotes set day = today, n = e.n + 1, last_at = now(), last_line = ln.id, phase_seen = today::text || ph,
    gain_day = case when e.gain_day is distinct from today then today else e.gain_day end where owner_id = uid;
  perform public.world_bond_note(pid, 'bond_emote', '연리', c.character_name || '님이 별채에서 「' || (em ->> 'name') || '」 상호작용을 보냈습니다. (설정 › 알림 「연리」에서 끌 수 있습니다)',
    jsonb_build_object('from', uid, 'emote', p_emote));
  return jsonb_build_object('ok', true, 'emote', p_emote, 'name', em ->> 'name', 'icon', em ->> 'icon', 'tier', tname,
    'line', replace(replace(ln.line, '{정인}', coalesce(pname, '정인')), '{이름}', c.character_name),
    'partner', pid, 'left', (r ->> 'day')::int - e.n - 1, 'gained', gained);
end $f$;

do $o$ declare f text; x text; g boolean := not has_schema_privilege('fn_owner_field', 'public', 'CREATE'); begin
  foreach f in array array['world_bond_emote_rules()', 'world_bond_emote_left(uuid)', 'world_bond_emote(text)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
      execute format('grant execute on function public.%s to %I', f, x);
    end loop;
  end loop;
  grant execute on function public.world_bond_emote(text) to authenticated;
  if g then grant create on schema public to fn_owner_field; end if;
  execute 'alter function public.world_bond_emote(text) owner to fn_owner_field';
  execute 'alter function public.world_bond_emote_left(uuid) owner to fn_owner_field';
  if g then revoke create on schema public from fn_owner_field; end if;
end $o$;
grant usage, select on sequence public.world_bond_emote_lines_id_seq to fn_owner_field;

select pg_temp.yh_patch('public.world_bond_snapshot()'::regprocedure, '''married'', coalesce((b.marks ->> ''married'')::boolean, false),', '''married'', coalesce((b.marks ->> ''married'')::boolean, false), ''emote_left'', public.world_bond_emote_left(uid),');
select pg_temp.yh_patch('public.world_character_purge(uuid)'::regprocedure, '    delete from public.world_garden_plots where owner_id = p_uid;', '    delete from public.world_garden_plots where owner_id = p_uid;
    delete from public.world_bond_emotes where owner_id = p_uid;');

delete from public.world_bond_emote_lines;
insert into public.world_bond_emote_lines(emote, ctx, tier, line) values
  ('hug', 'base', 'all', '{정인}이(가) 잠깐 놀란 듯하더니 곧 팔을 둘러 마주 안아 줍니다.'),
  ('hug', 'base', 'all', '{정인}이(가) 안긴 채로 {이름}의 등을 두어 번 가볍게 두드립니다.'),
  ('hug', 'base', 'all', '{정인}이(가) 숨을 한 번 크게 들이쉬고 천천히 몸에 힘을 뺍니다.'),
  ('hug', 'base', 'all', '{정인}이(가) 품 안에서 고개를 들어 {이름}을(를) 올려다봅니다. 표정이 한결 부드러워진 것 같습니다.'),
  ('hug', 'base', 'all', '{정인}이(가) 빨래를 개던 손을 멈추고 그대로 안아 줍니다. 개다 만 옷가지가 무릎에서 흘러내립니다.'),
  ('hug', 'base', 'all', '{정인}이(가) 부엌에서 나오다 말고 앞치마 차림으로 안깁니다. 밀가루가 묻은 손은 허공에 든 채입니다.'),
  ('hug', 'base', 't1', '{정인}이(가) 굳은 채로 안겼다가 이내 마주 안아 줍니다. 귀 끝이 조금 빨개진 것 같습니다.'),
  ('hug', 'base', 't1', '{정인}이(가) 두 팔을 어디 둘지 몰라 잠깐 머뭇거리다가 등을 가만히 토닥여 줍니다.'),
  ('hug', 'base', 't1', '{정인}이(가) 안기자마자 숨을 멈춘 것처럼 가만히 있습니다. 심장 소리가 크게 들리는 것 같습니다.'),
  ('hug', 'base', 't2', '{정인}이(가) 기다렸다는 듯 꼭 끌어안아 줍니다. 한동안 놓아줄 생각이 없어 보입니다.'),
  ('hug', 'base', 't2', '{정인}이(가) 품에 얼굴을 묻고 가만히 있다가 천천히 숨을 내쉽니다.'),
  ('hug', 'base', 't2', '{정인}이(가) 안긴 채로 몸을 좌우로 살랑살랑 흔듭니다.'),
  ('hug', 'base', 't2', '{정인}이(가) 품을 빠져나가려다 말고 다시 파고듭니다.'),
  ('hug', 'base', 't3', '{정인}이(가) 등을 천천히 쓸어내리며 오래 안아 줍니다. 무사히 돌아온 것을 확인하는 듯합니다.'),
  ('hug', 'base', 't3', '{정인}이(가) 한참을 놓지 않습니다. 팔에 힘이 조금 더 들어간 것 같습니다.'),
  ('hug', 'base', 't3', '{정인}이(가) {이름}의 어깨에 얼굴을 묻고 한동안 움직이지 않습니다.'),
  ('hug', 'base', 't3', '{정인}이(가) 놓아줄 듯하다가 다시 한 번 꼭 끌어안습니다.'),
  ('hug', 'base', 't4', '{정인}이(가) 익숙하게 어깨에 턱을 얹습니다. 그 자리가 제 자리인 듯 편안해 보입니다.'),
  ('hug', 'base', 't4', '{정인}이(가) 안긴 채로 작게 하품을 합니다. {이름}의 품이 꽤 졸린 모양입니다.'),
  ('hug', 'base', 't4', '{정인}이(가) 안긴 채로 {이름}의 옷깃에 묻은 먼지를 무심하게 털어 줍니다.'),
  ('hug', 'base', 't4', '{정인}이(가) 등을 두어 번 두드리고는 하던 일로 자연스럽게 돌아갑니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 내민 손을 마주 잡고 살며시 힘을 줍니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 맞잡은 손을 잠시 들여다보다가 손가락을 하나씩 엮어 깍지를 낍니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 손을 잡은 채 {이름} 쪽으로 반 걸음 다가섭니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 맞잡은 손을 제 쪽으로 가볍게 당깁니다. 어디든 같이 가자는 뜻인 것 같습니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 장 보러 가는 길인 듯 장바구니를 다른 손으로 옮겨 들고 손을 잡아 줍니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 마당을 쓸던 빗자루를 벽에 기대 세워 두고 손을 내밉니다.'),
  ('hand', 'base', 't1', '{정인}이(가) 손끝이 닿자 움찔했다가 슬그머니 다시 손을 내밉니다.'),
  ('hand', 'base', 't1', '{정인}이(가) 맞잡은 손을 한참 내려다봅니다. 손에 살짝 땀이 밴 것 같습니다.'),
  ('hand', 'base', 't1', '{정인}이(가) 손을 잡히자 시선을 어디 둘지 몰라 하늘만 올려다봅니다.'),
  ('hand', 'base', 't2', '{정인}이(가) 깍지를 끼고 맞잡은 손을 앞뒤로 크게 흔듭니다.'),
  ('hand', 'base', 't2', '{정인}이(가) 엄지로 손바닥의 굳은살을 문질러 봅니다. 요즘 무슨 일을 했는지 알아챈 듯합니다.'),
  ('hand', 'base', 't2', '{정인}이(가) 잡은 손을 크게 휘저으며 앞장서 걷습니다.'),
  ('hand', 'base', 't2', '{정인}이(가) 손가락으로 {이름}의 손등을 톡톡 두드립니다. 장난을 치고 싶은 모양입니다.'),
  ('hand', 'base', 't3', '{정인}이(가) 손을 꼭 쥐고 쉽게 놓지 않습니다.'),
  ('hand', 'base', 't3', '{정인}이(가) 맞잡은 손등에 이마를 살며시 기댑니다.'),
  ('hand', 'base', 't3', '{정인}이(가) 손의 온기를 오래 확인하듯 천천히 쓸어 봅니다.'),
  ('hand', 'base', 't3', '{정인}이(가) 맞잡은 손을 제 가슴께로 가져가 잠시 머뭅니다.'),
  ('hand', 'base', 't4', '{정인}이(가) 쳐다보지도 않고 손을 찾아 잡습니다. 손이 먼저 길을 아는 것 같습니다.'),
  ('hand', 'base', 't4', '{정인}이(가) 잡은 손을 그대로 제 소매 속에 같이 넣어 둡니다.'),
  ('hand', 'base', 't4', '{정인}이(가) 손을 잡은 채로 다른 손으로는 하던 일을 계속합니다.'),
  ('hand', 'base', 't4', '{정인}이(가) 손을 잡자마자 익숙하게 걸음을 맞춥니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 쓰다듬는 손길에 눈을 가늘게 뜹니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 고개를 살짝 기울여 손이 닿기 좋게 해 줍니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 손이 떠나자 아쉬운 듯 {이름}을(를) 흘끔 봅니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 쓰다듬어지는 동안 얌전히 서 있습니다. 기분이 좋아 보입니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 마루 끝에 앉아 콩을 고르다가 고개만 내밀어 줍니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 막 감은 머리를 수건으로 말리던 참이라 손에 물기가 조금 묻어납니다.'),
  ('pat', 'base', 't1', '{정인}이(가) 눈을 질끈 감고 가만히 있습니다. 싫지는 않은 것 같습니다.'),
  ('pat', 'base', 't1', '{정인}이(가) 손길을 피하지 못하고 고개를 살짝 숙입니다. 머리 모양이 신경 쓰이는 듯합니다.'),
  ('pat', 'base', 't1', '{정인}이(가) 손이 닿는 순간 어깨를 움찔 떨었다가 천천히 긴장을 풉니다.'),
  ('pat', 'base', 't2', '{정인}이(가) 머리를 손바닥 쪽으로 꾹 밀어붙입니다. 한 번 더 해 달라는 뜻인 것 같습니다.'),
  ('pat', 'base', 't2', '{정인}이(가) 헝클어진 머리를 손가락으로 대충 넘기고 피식 웃습니다.'),
  ('pat', 'base', 't2', '{정인}이(가) 손을 붙잡아 제 머리를 대신 마구 헝클어뜨립니다.'),
  ('pat', 'base', 't2', '{정인}이(가) 이번에는 {이름}의 머리를 쓰다듬어 되갚아 줍니다.'),
  ('pat', 'base', 't3', '{정인}이(가) 손길에 기대어 천천히 숨을 내쉽니다. 어깨에서 힘이 빠진 것 같습니다.'),
  ('pat', 'base', 't3', '{정인}이(가) 쓰다듬던 손을 붙잡아 제 뺨에 가져다 댑니다.'),
  ('pat', 'base', 't3', '{정인}이(가) 손길이 멈추지 않도록 그대로 가만히 기대 있습니다.'),
  ('pat', 'base', 't3', '{정인}이(가) 쓰다듬는 손 아래에서 아주 작게 웃습니다.'),
  ('pat', 'base', 't4', '{정인}이(가) 하던 일을 멈추지 않은 채 머리만 손 쪽으로 기울여 줍니다.'),
  ('pat', 'base', 't4', '{정인}이(가) 눈도 뜨지 않고 고개를 조금씩 움직여 쓰다듬을 자리를 알려 줍니다.'),
  ('pat', 'base', 't4', '{정인}이(가) 쓰다듬는 손을 한 손으로 붙잡아 머리 위에 얹어 둔 채 책장을 넘깁니다.'),
  ('pat', 'base', 't4', '{정인}이(가) 쓰다듬어지는 데 익숙한 듯 꾸벅 졸기 시작합니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 장난을 알아채고 눈을 가늘게 뜹니다. 반격을 궁리하는 것 같습니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 화들짝 놀랐다가 웃음을 터뜨립니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 어깨로 {이름}을(를) 가볍게 밀어냅니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 모르는 척 고개를 돌렸다가 갑자기 돌아서서 똑같이 장난을 칩니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 찻잔을 든 채로 장난을 피하느라 차를 흘리지 않으려 애씁니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 신발을 짝짝이로 신고 나가려던 참에 장난을 당하고 그제야 발밑을 내려다봅니다.'),
  ('tease', 'base', 't1', '{정인}이(가) 옆구리를 찔리자 펄쩍 뛰어오릅니다. 얼굴이 금세 붉어진 것 같습니다.'),
  ('tease', 'base', 't1', '{정인}이(가) 머리에 꽂힌 풀잎을 뒤늦게 발견하고 {이름}을(를) 빤히 쳐다봅니다.'),
  ('tease', 'base', 't1', '{정인}이(가) 어쩔 줄 몰라 하며 두 손으로 얼굴을 가립니다. 손가락 틈으로 웃고 있는 것 같습니다.'),
  ('tease', 'base', 't2', '{정인}이(가) 지지 않고 똑같이 볼을 쭉 늘려 돌려줍니다.'),
  ('tease', 'base', 't2', '{정인}이(가) 차가운 손을 {이름}의 목덜미에 슬쩍 갖다 댑니다. 반격할 때를 기다린 듯합니다.'),
  ('tease', 'base', 't2', '{정인}이(가) 소매를 걷어붙이고 본격적으로 반격할 자세를 잡습니다.'),
  ('tease', 'base', 't2', '{정인}이(가) 잡히지 않으려고 마당을 한 바퀴 돌아 달아납니다.'),
  ('tease', 'base', 't3', '{정인}이(가) 장난을 받아 주다가 결국 웃음을 터뜨립니다.'),
  ('tease', 'base', 't3', '{정인}이(가) 입을 삐죽 내밀었다가 금세 풀고 어깨를 툭 부딪쳐 옵니다.'),
  ('tease', 'base', 't3', '{정인}이(가) 장난에 넘어가 주고는 {이름}이(가) 웃는 얼굴을 한참 바라봅니다.'),
  ('tease', 'base', 't3', '{정인}이(가) 토라진 척 등을 돌렸다가 금세 돌아봅니다.'),
  ('tease', 'base', 't4', '{정인}이(가) 피하지도 않고 담담한 얼굴로 서 있습니다. 이미 다 읽힌 수법인 것 같습니다.'),
  ('tease', 'base', 't4', '{정인}이(가) 모르는 척하다가 다리를 슬쩍 걸어 함께 넘어집니다.'),
  ('tease', 'base', 't4', '{정인}이(가) 하품을 하며 장난을 흘려보냅니다. 오늘은 넘어가 주는 모양입니다.'),
  ('tease', 'base', 't4', '{정인}이(가) 미리 준비해 둔 듯 품에서 장난감 거미를 꺼내 보입니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 쑥스러운 듯 뒷머리를 긁적입니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 칭찬을 듣고 어깨를 으쓱합니다. 기분이 좋아진 것 같습니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 고개를 끄덕이며 {이름}에게 엄지를 세워 보입니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 입꼬리를 감추지 못하고 시선을 피합니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 방금 개어 둔 이부자리를 가리키며 그것도 칭찬해 달라는 얼굴을 합니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 밥상을 차리다 말고 수저를 든 채 웃습니다.'),
  ('praise', 'base', 't1', '{정인}이(가) 손사래를 치다가 소매로 입가를 가립니다. 입꼬리가 올라간 것 같습니다.'),
  ('praise', 'base', 't1', '{정인}이(가) 눈을 동그랗게 뜨고 {이름}을(를) 쳐다봅니다. 방금 들은 말을 곱씹는 듯합니다.'),
  ('praise', 'base', 't1', '{정인}이(가) 손부채질을 하며 얼굴의 열기를 식힙니다.'),
  ('praise', 'base', 't2', '{정인}이(가) 허리에 손을 얹고 턱을 살짝 치켜듭니다. 꽤 뿌듯해 보입니다.'),
  ('praise', 'base', 't2', '{정인}이(가) 칭찬을 그대로 돌려주려는 듯 {이름}을(를) 손가락으로 가리킵니다.'),
  ('praise', 'base', 't2', '{정인}이(가) 한 바퀴 빙그르르 돌며 자랑하듯 몸짓을 해 보입니다.'),
  ('praise', 'base', 't2', '{정인}이(가) 칭찬받은 김에 {이름}의 어깨를 툭툭 두드려 줍니다.'),
  ('praise', 'base', 't3', '{정인}이(가) 잠깐 말을 잃고 {이름}을(를) 바라봅니다. 눈가가 조금 붉어진 것 같습니다.'),
  ('praise', 'base', 't3', '{정인}이(가) 고개를 숙이고 한참 웃습니다. 오늘 들은 말 중에 제일 좋았던 모양입니다.'),
  ('praise', 'base', 't3', '{정인}이(가) {이름}의 손을 꼭 쥐고 고맙다는 듯 고개를 숙입니다.'),
  ('praise', 'base', 't3', '{정인}이(가) 웃음 끝에 조용히 {이름}의 곁에 기대섭니다.'),
  ('praise', 'base', 't4', '{정인}이(가) 귀에 손을 대고 한 번 더 말해 보라는 시늉을 합니다.'),
  ('praise', 'base', 't4', '{정인}이(가) 헛기침을 하며 딴청을 피웁니다. 귀가 빨개진 것은 감추지 못한 것 같습니다.'),
  ('praise', 'base', 't4', '{정인}이(가) 들은 척 만 척하다가 슬그머니 콧노래를 흥얼거립니다.'),
  ('praise', 'base', 't4', '{정인}이(가) 칭찬을 받아 적는 시늉을 합니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 가만히 고개를 끄덕이며 곁에 앉습니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 어깨를 토닥이는 손에 천천히 숨을 고릅니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 한숨을 길게 내쉬고 {이름} 쪽으로 몸을 기울입니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 말없이 {이름}의 손을 찾아 쥡니다. 조금 나아진 것 같습니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 끓던 찻물을 불에서 내려놓고 곁으로 와 앉습니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 바느질하던 옷을 무릎에 내려놓고 {이름}의 손을 잡습니다.'),
  ('comfort', 'base', 't1', '{정인}이(가) 조심스럽게 고개를 끄덕입니다. 티를 내지 않으려 했던 것 같습니다.'),
  ('comfort', 'base', 't1', '{정인}이(가) 어깨에 얹힌 손을 가만히 내려다보다가 그 위에 자기 손을 포갭니다.'),
  ('comfort', 'base', 't1', '{정인}이(가) 괜찮다는 듯 웃어 보이지만 눈가가 촉촉해 보입니다.'),
  ('comfort', 'base', 't2', '{정인}이(가) 털썩 기대 앉아 한동안 말없이 있습니다. 조금 나아진 듯합니다.'),
  ('comfort', 'base', 't2', '{정인}이(가) 코를 훌쩍이다가 고개를 돌립니다. 우는 얼굴은 보이고 싶지 않은 것 같습니다.'),
  ('comfort', 'base', 't2', '{정인}이(가) 무릎을 끌어안고 앉아 {이름} 쪽으로 머리를 기울입니다.'),
  ('comfort', 'base', 't2', '{정인}이(가) 따뜻한 차를 두 잔 따라 하나를 {이름}에게 내밉니다.'),
  ('comfort', 'base', 't3', '{정인}이(가) 등을 맡긴 채 천천히 숨을 고릅니다.'),
  ('comfort', 'base', 't3', '{정인}이(가) {이름}의 소매 끝을 꼭 붙잡고 놓지 않습니다.'),
  ('comfort', 'base', 't3', '{정인}이(가) {이름}의 품에 기대어 눈을 감습니다. 마음이 놓인 것 같습니다.'),
  ('comfort', 'base', 't3', '{정인}이(가) 떨리는 손을 감추지 않고 {이름}에게 맡깁니다.'),
  ('comfort', 'base', 't4', '{정인}이(가) 말없이 머리를 어깨에 기댑니다. 이 정도면 충분하다는 듯합니다.'),
  ('comfort', 'base', 't4', '{정인}이(가) 눈을 감은 채 옅게 웃습니다. 무엇을 해 줄지 이미 알고 있었던 것 같습니다.'),
  ('comfort', 'base', 't4', '{정인}이(가) 담요를 둘러쓰고 {이름}의 옆자리를 툭툭 칩니다.'),
  ('comfort', 'base', 't4', '{정인}이(가) {이름}의 어깨에 기댄 채 금세 잠이 듭니다.'),
  ('five', 'base', 'all', '{정인}이(가) 손바닥을 마주 맞추고 활짝 웃습니다.'),
  ('five', 'base', 'all', '{정인}이(가) 손을 높이 들어 힘차게 맞받아 줍니다.'),
  ('five', 'base', 'all', '{정인}이(가) 맞춘 손바닥을 털며 신난 듯 발을 구릅니다.'),
  ('five', 'base', 'all', '{정인}이(가) 손을 맞춘 뒤 주먹을 쥐어 보입니다. 다음 일도 해낼 기세입니다.'),
  ('five', 'base', 'all', '{정인}이(가) 장작을 다 패고 난 참이라 손바닥이 조금 거칩니다.'),
  ('five', 'base', 'all', '{정인}이(가) 밭에서 막 돌아와 흙 묻은 손을 털고는 힘차게 손뼉을 맞춥니다.'),
  ('five', 'base', 't1', '{정인}이(가) 손바닥을 맞추고는 그 손을 한참 내려다봅니다.'),
  ('five', 'base', 't1', '{정인}이(가) 한 박자 늦게 손을 들어 허공을 치고는 얼굴을 감쌉니다.'),
  ('five', 'base', 't1', '{정인}이(가) 손바닥이 닿자 깜짝 놀라 손을 털다가 쑥스럽게 웃습니다.'),
  ('five', 'base', 't2', '{정인}이(가) 손바닥이 얼얼할 만큼 힘차게 맞받아 줍니다.'),
  ('five', 'base', 't2', '{정인}이(가) 맞춘 손을 그대로 깍지 껴 버립니다.'),
  ('five', 'base', 't2', '{정인}이(가) 하이파이브 끝에 팔꿈치까지 부딪쳐 옵니다.'),
  ('five', 'base', 't2', '{정인}이(가) 손바닥을 맞추고 한쪽 발로 깡충 뜁니다.'),
  ('five', 'base', 't3', '{정인}이(가) 손을 맞댄 채 {이름}과(와) 눈을 맞추고 고개를 끄덕입니다.'),
  ('five', 'base', 't3', '{정인}이(가) 맞댄 손을 쉽게 떼지 못합니다.'),
  ('five', 'base', 't3', '{정인}이(가) 맞댄 손을 그대로 내려 {이름}의 손을 잡습니다.'),
  ('five', 'base', 't3', '{정인}이(가) 손을 맞춘 뒤 조용히 웃으며 이마를 톡 맞댑니다.'),
  ('five', 'base', 't4', '{정인}이(가) 위로, 아래로, 옆으로 둘만 아는 순서대로 손을 맞춥니다. 한 번도 틀리지 않습니다.'),
  ('five', 'base', 't4', '{정인}이(가) 손바닥을 내밀었다가 맞추기 직전에 쓱 뺍니다. 장난기가 가득한 얼굴입니다.'),
  ('five', 'base', 't4', '{정인}이(가) 보지도 않고 손을 뻗어 정확히 맞춥니다.'),
  ('five', 'base', 't4', '{정인}이(가) 하이파이브를 받아 주는 척하다가 손바닥에 콩알 하나를 쥐여 줍니다.'),
  ('dance', 'base', 'all', '{정인}이(가) 손을 맞잡고 박자에 맞춰 천천히 몸을 흔듭니다.'),
  ('dance', 'base', 'all', '{정인}이(가) {이름}의 이끄는 대로 한 바퀴 빙그르르 돕니다.'),
  ('dance', 'base', 'all', '{정인}이(가) 발끝을 맞춰 보려 애쓰다가 함께 웃음을 터뜨립니다.'),
  ('dance', 'base', 'all', '{정인}이(가) 춤을 마치고 가볍게 고개 숙여 인사를 합니다.'),
  ('dance', 'base', 'all', '{정인}이(가) 설거지를 하다 말고 젖은 손을 앞치마에 닦으며 따라 돕니다.'),
  ('dance', 'base', 'all', '{정인}이(가) 마당에 널어 둔 빨래 사이를 빙글빙글 돌며 춤을 춥니다.'),
  ('dance', 'base', 't1', '{정인}이(가) 발을 밟고 깜짝 놀라 펄쩍 물러섭니다. 춤이 영 서툰 것 같습니다.'),
  ('dance', 'base', 't1', '{정인}이(가) 서툴게 한 바퀴 돌다가 웃음을 참지 못합니다. 누가 볼까 봐 문 쪽을 흘끔거립니다.'),
  ('dance', 'base', 't1', '{정인}이(가) 손을 어디 둘지 몰라 허둥대다가 결국 {이름}의 소매를 잡습니다.'),
  ('dance', 'base', 't2', '{정인}이(가) 엉터리 박자로 몸을 흔듭니다. 박자는 상관없는 듯합니다.'),
  ('dance', 'base', 't2', '{정인}이(가) 손을 잡고 빙글 돌며 신나게 따라옵니다.'),
  ('dance', 'base', 't2', '{정인}이(가) 마당을 무대 삼아 과장된 몸짓으로 빙글빙글 돕니다.'),
  ('dance', 'base', 't2', '{정인}이(가) 손뼉으로 장단을 치며 {이름}의 춤을 거듭니다.'),
  ('dance', 'base', 't3', '{정인}이(가) 느리게 몸을 흔들다가 이마를 맞댑니다.'),
  ('dance', 'base', 't3', '{정인}이(가) 춤을 멈추고 가만히 끌어안습니다. 음악이 없어도 괜찮은 것 같습니다.'),
  ('dance', 'base', 't3', '{정인}이(가) 춤추는 동안 한순간도 {이름}에게서 눈을 떼지 않습니다.'),
  ('dance', 'base', 't3', '{정인}이(가) 천천히 돌다가 {이름}의 어깨에 살며시 머리를 기댑니다.'),
  ('dance', 'base', 't4', '{정인}이(가) 일부러 엉망으로 추며 {이름}을(를) 웃깁니다.'),
  ('dance', 'base', 't4', '{정인}이(가) 발을 밟히고도 태연하게 다음 동작을 이어 갑니다.'),
  ('dance', 'base', 't4', '{정인}이(가) 둘만 아는 엉터리 춤을 정확한 순서대로 춥니다.'),
  ('dance', 'base', 't4', '{정인}이(가) 춤추다 말고 부엌으로 가서 국을 한 번 젓고 돌아옵니다.'),
  ('any', 'time:dawn', 'all', '{정인}이(가) 기지개를 켜다가 {이름}을(를) 보고 팔을 내리지도 않은 채 웃습니다.'),
  ('any', 'time:dawn', 'all', '{정인}이(가) 세숫물을 떠 오다가 걸음을 멈추고 돌아봅니다.'),
  ('any', 'time:dawn', 'all', '{정인}이(가) 아궁이에 불을 지피다 말고 재 묻은 얼굴로 돌아봅니다.'),
  ('any', 'time:dawn', 'all', '{정인}이(가) 이불을 개다 말고 그 위에 털썩 주저앉습니다.'),
  ('any', 'time:dawn', 't1', '{정인}이(가) 덜 뜬 눈을 비비다가 {이름}을(를) 보고 허둥지둥 머리를 매만집니다.'),
  ('any', 'time:dawn', 't2', '{정인}이(가) 까치집 머리 그대로 느릿느릿 다가옵니다. 아직 잠이 덜 깬 것 같습니다.'),
  ('any', 'time:dawn', 't3', '{정인}이(가) 창으로 드는 햇살 속에서 {이름}을(를) 한참 바라봅니다.'),
  ('any', 'time:dawn', 't4', '{정인}이(가) 길게 하품을 하며 아침상 쪽을 턱으로 가리킵니다.'),
  ('any', 'time:noon', 'all', '{정인}이(가) 볕을 피해 처마 그늘로 {이름}을(를) 끌어당깁니다.'),
  ('any', 'time:noon', 'all', '{정인}이(가) 점심을 먹다 말고 숟가락을 든 채 돌아봅니다.'),
  ('any', 'time:noon', 'all', '{정인}이(가) 마당에 고추를 널다가 손을 털고 다가옵니다.'),
  ('any', 'time:noon', 'all', '{정인}이(가) 툇마루에서 꾸벅꾸벅 졸다가 화들짝 깹니다.'),
  ('any', 'time:noon', 't1', '{정인}이(가) 볕에 달아오른 뺨을 손등으로 식힙니다. 더위 때문만은 아닌 것 같습니다.'),
  ('any', 'time:noon', 't2', '{정인}이(가) 마루에 대자로 누운 채 옆자리를 손바닥으로 툭툭 칩니다.'),
  ('any', 'time:noon', 't3', '{정인}이(가) 바쁜 한낮에 일부러 들른 듯 숨이 조금 차 있습니다.'),
  ('any', 'time:noon', 't4', '{정인}이(가) 부채를 부치다가 바람을 {이름} 쪽으로 돌려 줍니다.'),
  ('any', 'time:dusk', 'all', '{정인}이(가) 마당의 빨래를 걷다 말고 돌아섭니다.'),
  ('any', 'time:dusk', 'all', '{정인}이(가) 노을을 등지고 서서 {이름}이(가) 오기를 기다립니다.'),
  ('any', 'time:dusk', 'all', '{정인}이(가) 저녁 쌀을 씻다가 젖은 손을 털며 돌아봅니다.'),
  ('any', 'time:dusk', 'all', '{정인}이(가) 하루 장부를 정리하던 붓을 내려놓습니다.'),
  ('any', 'time:dusk', 't1', '{정인}이(가) 노을빛에 물든 얼굴로 창밖과 {이름}을(를) 번갈아 봅니다.'),
  ('any', 'time:dusk', 't2', '{정인}이(가) 등롱에 불을 붙이다 말고 돌아봅니다. 저녁거리를 고민하는 듯합니다.'),
  ('any', 'time:dusk', 't3', '{정인}이(가) 하루를 마친 얼굴로 조용히 어깨에 기댑니다.'),
  ('any', 'time:dusk', 't4', '{정인}이(가) 벌써 이부자리를 펴 두고 그 옆에 앉아 있습니다.'),
  ('any', 'time:night', 'all', '{정인}이(가) 등잔 심지를 낮추고 소리 죽여 다가옵니다.'),
  ('any', 'time:night', 'all', '{정인}이(가) 잠든 척하다가 한쪽 눈을 살며시 뜹니다.'),
  ('any', 'time:night', 'all', '{정인}이(가) 등잔 아래 읽던 책을 덮고 하품을 삼킵니다.'),
  ('any', 'time:night', 'all', '{정인}이(가) 물 한 모금 마시러 나왔다가 마주칩니다.'),
  ('any', 'time:night', 't1', '{정인}이(가) 깜짝 놀라 소리를 삼킵니다. 이 밤에 잠이 다 달아난 것 같습니다.'),
  ('any', 'time:night', 't2', '{정인}이(가) 이불을 들어 올려 들어오라는 시늉을 합니다.'),
  ('any', 'time:night', 't3', '{정인}이(가) 잠결에 손을 더듬어 {이름}의 손을 찾아 쥡니다.'),
  ('any', 'time:night', 't4', '{정인}이(가) 눈을 감은 채 돌아누우며 이불 한쪽을 내어 줍니다.'),
  ('any', 'w:rain', 'all', '{정인}이(가) 빗방울이 맺힌 {이름}의 머리를 손바닥으로 훔쳐 줍니다.'),
  ('any', 'w:rain', 'all', '{정인}이(가) 우산 하나를 펴 들고 {이름} 쪽으로 기울입니다.'),
  ('any', 'w:rain', 'all', '{정인}이(가) 처마 밑에 장독 뚜껑을 덮고 들어옵니다.'),
  ('any', 'w:rain', 'all', '{정인}이(가) 젖은 신발을 문간에 나란히 세워 둡니다.'),
  ('any', 'w:rain', 't1', '{정인}이(가) 처마 끝 빗줄기와 {이름}을(를) 번갈아 봅니다. 비 오는 날이 싫지 않은 것 같습니다.'),
  ('any', 'w:rain', 't2', '{정인}이(가) 젖은 머리를 털며 마른 수건부터 내밉니다.'),
  ('any', 'w:rain', 't3', '{정인}이(가) 빗소리에 귀를 기울이다가 {이름} 곁으로 바짝 다가앉습니다.'),
  ('any', 'w:rain', 't4', '{정인}이(가) 마당의 빗물받이 통을 보고 흡족한 듯 고개를 끄덕입니다.'),
  ('any', 'w:snow', 'all', '{정인}이(가) 하얀 입김을 불며 손을 비빕니다.'),
  ('any', 'w:snow', 'all', '{정인}이(가) 눈송이를 손바닥에 받아 {이름}에게 보여 줍니다.'),
  ('any', 'w:snow', 'all', '{정인}이(가) 마당에 쌓인 눈을 쓸다 말고 빗자루에 기대섭니다.'),
  ('any', 'w:snow', 'all', '{정인}이(가) 화롯불에 군밤을 굽다가 하나를 건넵니다.'),
  ('any', 'w:snow', 't1', '{정인}이(가) {이름}의 어깨에 쌓인 눈을 털어 주다가 손이 닿자 움찔합니다.'),
  ('any', 'w:snow', 't2', '{정인}이(가) 등 뒤에 무언가를 숨긴 채 다가옵니다. 손이 차갑게 젖어 있는 것 같습니다.'),
  ('any', 'w:snow', 't3', '{정인}이(가) 언 손을 제 두 손으로 감싸 녹여 줍니다.'),
  ('any', 'w:snow', 't4', '{정인}이(가) 화로 옆자리를 말없이 내어 줍니다.'),
  ('any', 'w:fog', 'all', '{정인}이(가) 안개 속에서 손을 휘저어 {이름}을(를) 찾습니다.'),
  ('any', 'w:fog', 'all', '{정인}이(가) 등롱을 들어 둘 사이의 안개를 비춥니다.'),
  ('any', 'w:fog', 'all', '{정인}이(가) 눅눅해진 이불을 걷어 들이며 고개를 갸웃합니다.'),
  ('any', 'w:fog', 'all', '{정인}이(가) 등잔 심지를 돋우어 방 안을 조금 더 밝힙니다.'),
  ('any', 'w:fog', 't1', '{정인}이(가) 안개 너머에서 {이름}을(를) 찾아내고 안도하는 얼굴이 됩니다.'),
  ('any', 'w:fog', 't2', '{정인}이(가) 안개 속에서 길을 잃지 않으려는 듯 소매를 꼭 붙잡습니다.'),
  ('any', 'w:fog', 't3', '{정인}이(가) 뿌연 마당을 내다보다가 {이름} 쪽으로 몸을 돌립니다.'),
  ('any', 'w:fog', 't4', '{정인}이(가) 코끝을 찡그리며 부엌 쪽을 흘끔거립니다. 따뜻한 국물이 당기는 듯합니다.'),
  ('any', 'w:wind', 'all', '{정인}이(가) 바람에 펄럭이는 옷자락을 붙잡느라 정신이 없습니다.'),
  ('any', 'w:wind', 'all', '{정인}이(가) 바람을 등지고 {이름}의 앞을 막아 섭니다.'),
  ('any', 'w:wind', 'all', '{정인}이(가) 날아간 빨래를 주워 들고 돌아옵니다.'),
  ('any', 'w:wind', 'all', '{정인}이(가) 덜컹이는 문고리를 끈으로 묶어 둡니다.'),
  ('any', 'w:wind', 't1', '{정인}이(가) 바람에 날린 머리카락을 급히 정리합니다. 신경이 쓰이는 것 같습니다.'),
  ('any', 'w:wind', 't2', '{정인}이(가) 문풍지 떠는 소리에 어깨를 움츠리며 바짝 붙어 앉습니다.'),
  ('any', 'w:wind', 't3', '{정인}이(가) 겉옷을 벗어 {이름}의 어깨에 둘러 줍니다.'),
  ('any', 'w:wind', 't4', '{정인}이(가) 덜컹이는 창을 쳐다보다가 {이름}과(와) 눈이 마주치자 어깨를 으쓱합니다.'),
  ('any', 'w:bloodmist', 'all', '{정인}이(가) 붉은 안개를 헤치고 와서 {이름}의 얼굴부터 살핍니다.'),
  ('any', 'w:bloodmist', 'all', '{정인}이(가) 등잔을 하나 더 켜 둡니다. 어둠이 싫은 것 같습니다.'),
  ('any', 'w:bloodmist', 'all', '{정인}이(가) 마당의 화분을 하나씩 안으로 들여놓습니다.'),
  ('any', 'w:bloodmist', 'all', '{정인}이(가) 문단속을 마치고 빗장을 한 번 더 확인합니다.'),
  ('any', 'w:bloodmist', 't1', '{정인}이(가) 붉은 안개를 불안하게 내다보다가 곁으로 다가섭니다.'),
  ('any', 'w:bloodmist', 't2', '{정인}이(가) 창호지를 한 겹 더 덧대고 문단속을 합니다.'),
  ('any', 'w:bloodmist', 't3', '{정인}이(가) {이름}의 손을 꼭 잡고 놓지 않습니다.'),
  ('any', 'w:bloodmist', 't4', '{정인}이(가) 익숙한 손놀림으로 정화 부적을 문설주에 붙입니다.'),
  ('any', 'st:erosion', 'all', '{정인}이(가) {이름}의 이마에 손을 얹어 열이 있는지 살핍니다.'),
  ('any', 'st:erosion', 'all', '{정인}이(가) 마음 다잡기 하러 가자는 듯 {이름}의 손을 끕니다.'),
  ('any', 'st:erosion', 'all', '{정인}이(가) 따뜻한 국을 한 그릇 떠서 말없이 내밉니다.'),
  ('any', 'st:erosion', 'all', '{정인}이(가) 이부자리를 펴 두고 좀 누우라는 듯 손짓합니다.'),
  ('any', 'st:erosion', 't1', '{정인}이(가) {이름}의 눈가에 번진 검은 기운을 보고 놀란 얼굴이 됩니다.'),
  ('any', 'st:erosion', 't2', '{정인}이(가) 정화 부적을 {이름}의 손에 꼭 쥐여 줍니다.'),
  ('any', 'st:erosion', 't3', '{정인}이(가) 서늘해진 손끝을 두 손으로 감싸 쥡니다. 걱정이 가득한 눈빛입니다.'),
  ('any', 'st:erosion', 't4', '{정인}이(가) 뭔가 말하려다 꾹 참는 얼굴로 {이름}을(를) 바라봅니다.'),
  ('any', 'st:hp', 'all', '{정인}이(가) {이름}의 팔을 조심스럽게 붙잡고 다친 곳을 살핍니다.'),
  ('any', 'st:hp', 'all', '{정인}이(가) 상처를 보고 미간을 찌푸리며 약상자를 꺼내 옵니다.'),
  ('any', 'st:hp', 'all', '{정인}이(가) 미지근한 물수건을 짜서 {이름}의 이마에 얹어 줍니다.'),
  ('any', 'st:hp', 'all', '{정인}이(가) 죽을 쑤려는 듯 쌀자루를 꺼내 옵니다.'),
  ('any', 'st:hp', 't1', '{정인}이(가) 상처를 보고 얼굴이 하얘집니다. 서둘러 약을 찾는 것 같습니다.'),
  ('any', 'st:hp', 't2', '{정인}이(가) {이름}의 팔을 붙잡아 자리에 앉힙니다.'),
  ('any', 'st:hp', 't3', '{정인}이(가) 붕대를 감다가 손을 멈추고 한동안 말이 없습니다.'),
  ('any', 'st:hp', 't4', '{정인}이(가) 익숙한 손놀림으로 상처에 약을 발라 줍니다.'),
  ('any', 'st:yohwa', 'all', '{정인}이(가) 요문이 떠오른 손을 피하지 않고 꼭 잡아 줍니다.'),
  ('any', 'st:yohwa', 'all', '{정인}이(가) {이름}의 곁을 한 발짝도 떠나지 않으려는 듯 바짝 붙어 섭니다.'),
  ('any', 'st:yohwa', 'all', '{정인}이(가) 평소처럼 밥상을 차려 {이름}의 자리에 수저를 놓습니다.'),
  ('any', 'st:yohwa', 'all', '{정인}이(가) 아무렇지 않은 척 {이름}의 옷을 개어 머리맡에 둡니다.'),
  ('any', 'st:yohwa', 't1', '{정인}이(가) {이름}의 살갗에 떠오른 요문을 보고 숨을 삼킵니다.'),
  ('any', 'st:yohwa', 't2', '{정인}이(가) 요문 위에 가만히 손을 얹습니다. 혼자 두지 않겠다는 뜻인 것 같습니다.'),
  ('any', 'st:yohwa', 't3', '{정인}이(가) {이름}의 눈을 똑바로 바라보며 이름을 또박또박 불러 줍니다.'),
  ('any', 'st:yohwa', 't4', '{정인}이(가) 아무렇지 않은 얼굴로 늘 앉던 자리를 {이름}에게 내어 줍니다.'),
  ('any', 'st:exp', 'all', '{정인}이(가) 원정에서 돌아온 {이름}을(를) 위아래로 훑어보며 다친 데를 찾습니다.'),
  ('any', 'st:exp', 'all', '{정인}이(가) 무거운 짐을 받아 들고 마루에 내려놓습니다.'),
  ('any', 'st:exp', 'all', '{정인}이(가) 물을 데워 두었는지 김이 오르는 대야를 가리킵니다.'),
  ('any', 'st:exp', 'all', '{정인}이(가) 흙 묻은 신발을 받아 들고 털어 줍니다.'),
  ('any', 'st:exp', 't1', '{정인}이(가) 먼지 묻은 옷을 털어 주며 다친 데가 없는지 살핍니다.'),
  ('any', 'st:exp', 't2', '{정인}이(가) 반가운 얼굴로 다가오다가 짐 보따리부터 흘끔 봅니다.'),
  ('any', 'st:exp', 't3', '{정인}이(가) 달려와 와락 끌어안습니다. 기다림이 길었던 것 같습니다.'),
  ('any', 'st:exp', 't4', '{정인}이(가) 문간에 기대 서서 고개를 끄덕여 맞아 줍니다. 언제 올지 알고 있었던 듯합니다.');

update public.world_patch_notes set body = body || $pn$

## 3.8.1
- [뒤뜰 밭] 별채 뒤뜰에 밭이 생겼습니다. 가진 식재료를 한 칸에 하나씩 심고 물을 주면 자라고, 다 자라면 거둡니다. 2×2에서 시작해 4×4까지 넓힐 수 있습니다.
- [뒤뜰 밭] 심기·거두기는 안전지대에서, 물 주기는 어디서나 합니다. 심을 식재료와 비료는 가방과 개인 창고에서 꺼내 쓰고, 거둔 작물은 가방에 들어갑니다.
- [뒤뜰 밭] 작물은 단계마다 자라는 시간이 다르고, 물 한 번이 하루 갑니다. 심을 때 비료(원령재·수귀 비늘은 빨리 자라게, 요수 뼈·독낭은 더 많이 거두게)를 함께 고를 수 있습니다.
- [뒤뜰 밭] 다 자란 뒤 이틀 동안 거두지 않으면 썩습니다. 썩은 칸은 치워야 다시 심을 수 있습니다.
- [뒤뜰 밭] 이따금 까마귀가 날아와 작물을 쪼아 먹습니다. 앉은 까마귀는 눌러 쫓을 수 있고, 별채 손님도 쫓아 줄 수 있습니다. 허수아비(상점·목공 제작)를 세우면 이레 동안 까마귀가 내려앉지 않습니다.
- [연리] 별채에서 정인의 모습을 누르면 포옹하기·손 잡기·머리 쓰다듬기·장난치기·칭찬하기·위로하기·하이파이브·함께 춤추기 가운데 하나를 고를 수 있습니다. 정인 곁으로 다가가면 정인이 반응하고, 인연도와 시간대·날씨·내 처지에 따라 반응이 달라집니다.
- [연리] 상호작용은 하루 10번까지이고, 하루 처음 한 번은 인연도가 2 오릅니다. 정인에게 알림이 가며, 설정 › 알림 「연리」에서 끌 수 있습니다.
- [얻는 곳] 물품 정보·퀘스트 칸·채집 도감·「외 n곳」 목록에서 지금 있는 곳에서 가장 가까운 곳을 맨 앞에 두고 「지금 여기」·「가까움 · n구간」으로 알려 줍니다. 내 레벨로 지날 수 없거나 아직 열리지 않은 지역은 셈하지 않습니다.$pn$ where note_id = '3.8.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127000000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
