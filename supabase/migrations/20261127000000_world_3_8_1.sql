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

update public.world_patch_notes set body = body || $pn$

## 3.8.1
- [뒤뜰 밭] 별채 뒤뜰에 밭이 생겼습니다. 가진 식재료를 한 칸에 하나씩 심고 물을 주면 자라고, 다 자라면 거둡니다. 2×2에서 시작해 4×4까지 넓힐 수 있습니다.
- [뒤뜰 밭] 심기·거두기는 안전지대에서, 물 주기는 어디서나 합니다. 심을 식재료와 비료는 가방과 개인 창고에서 꺼내 쓰고, 거둔 작물은 가방에 들어갑니다.
- [뒤뜰 밭] 작물은 단계마다 자라는 시간이 다르고, 물 한 번이 하루 갑니다. 심을 때 비료(원령재·수귀 비늘은 빨리 자라게, 요수 뼈·독낭은 더 많이 거두게)를 함께 고를 수 있습니다.
- [뒤뜰 밭] 다 자란 뒤 이틀 동안 거두지 않으면 썩습니다. 썩은 칸은 치워야 다시 심을 수 있습니다.
- [뒤뜰 밭] 이따금 까마귀가 날아와 작물을 쪼아 먹습니다. 앉은 까마귀는 눌러 쫓을 수 있고, 별채 손님도 쫓아 줄 수 있습니다. 허수아비(상점·목공 제작)를 세우면 이레 동안 까마귀가 내려앉지 않습니다.
- [얻는 곳] 물품 정보·퀘스트 칸·채집 도감·「외 n곳」 목록에서 지금 있는 곳에서 가장 가까운 곳을 맨 앞에 두고 「지금 여기」·「가까움 · n구간」으로 알려 줍니다. 내 레벨로 지날 수 없거나 아직 열리지 않은 지역은 셈하지 않습니다.$pn$ where note_id = '3.8.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127000000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
