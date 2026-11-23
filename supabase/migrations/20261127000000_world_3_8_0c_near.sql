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

select pg_temp.yh_patch('public.world_gather_codex_snapshot()'::regprocedure, 'declare uid uuid := public.fn_owner_auth_uid();', 'declare uid uuid := public.fn_owner_auth_uid(); dm jsonb := coalesce(public.world_region_dist(public.fn_owner_auth_uid()) -> ''d'', ''{}''::jsonb);');
select pg_temp.yh_patch('public.world_gather_codex_snapshot()'::regprocedure, ' order by 2 limit 6) z) as regions', ' order by 2 limit 6) z) as regions,
          (select z.n from (select distinct r2.region_name as n, coalesce(r2.min_level, 1) as l from public.world_gathering_spots s2
             join public.world_exploration_nodes n2 on n2.node_id = s2.node_id join public.world_map_regions r2 on r2.region_id = n2.region_id
            where s2.active and x = any (s2.loot_items) and public.world_source_region_ok(''gather'', r2.is_safe_zone, r2.active) and dm ? r2.region_name) z
            order by (dm -> z.n ->> 1)::float8, z.l, z.n limit 1) as nr');
select pg_temp.yh_patch('public.world_gather_codex_snapshot()'::regprocedure, 'order by rr.l, rr.n) from (', 'order by coalesce(rr.n = it.nr, false) desc, rr.l, rr.n) from (');
select pg_temp.yh_patch('public.world_gather_codex_snapshot()'::regprocedure, 'group by q.n order by 2, 1 limit 8) rr)', 'group by q.n order by coalesce(q.n = it.nr, false) desc, 2, 1 limit 8) rr), ''near'', case when it.nr is not null then jsonb_build_object(''r'', it.nr, ''h'', (dm -> it.nr ->> 0)::int) end');

update public.world_patch_notes set body = body || $pn$
- [얻는 곳] 물품 정보·퀘스트 칸·채집 도감·「외 n곳」 목록에서 지금 있는 곳에서 가장 가까운 곳을 맨 앞에 두고 「지금 여기」·「가까움 · n구간」으로 알려 줍니다. 내 레벨로 지날 수 없거나 아직 열리지 않은 지역은 셈하지 않습니다.$pn$ where note_id = '3.8.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127000000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
