create or replace function public.world_weak_lift(p_uid uuid, p_region text, p_key text)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare k text; p jsonb; need int := (public.world_project_rules() -> 'lift' ->> p_key)::int;
begin
  if p_uid is null or p_region is null or need is null or not public.world_weak_safe(p_region) then return false; end if;
  for k, p in select key, value from jsonb_each(public.world_project_rules() -> 'projects') loop
    if p ->> 'kind' = 'common' and p -> 'hubs' ? p_region then
      return public.world_project_stage(k) >= need and public.world_project_story(p_uid, k);
    end if;
  end loop;
  return false;
end $f$;

create or replace function public.world_weak_here(p_uid uuid, p_key text)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rid text;
begin
  select (public.world_region_at(c.location)).region_id into rid from public.world_characters c where c.owner_id = p_uid;
  return coalesce(public.world_weak_safe(rid), false) and not public.world_weak_lift(p_uid, rid, p_key);
end $f$;

create or replace function public.world_weak_view(p_uid uuid, p_region text)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare k text; o jsonb := '{}'::jsonb;
begin
  if p_region is null or not public.world_weak_safe(p_region) then return null; end if;
  for k in select jsonb_object_keys(public.world_project_rules() -> 'lift') loop
    o := o || jsonb_build_object(k, not public.world_weak_lift(p_uid, p_region, k));
  end loop;
  return o;
end $f$;

create or replace function public.world_project_shop_item(p_shop text, p_item text)
 returns text language sql immutable set search_path = pg_catalog, public
as $f$
  select k from jsonb_each(public.world_project_rules() -> 'projects') x(k, p)
   where p -> 'shops' ? p_shop and p -> 'shop' ? p_item limit 1
$f$;

create or replace function public.world_project_shop_stage(p_shop text)
 returns int language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare k text;
begin
  select x.k into k from jsonb_each(public.world_project_rules() -> 'projects') x(k, p) where p ->> 'kind' = 'common' and p -> 'shops' ? p_shop limit 1;
  return case when k is null then 0 else public.world_project_stage(k) end;
end $f$;

create or replace function public.world_project_shop_ok(p_uid uuid, p_shop text, p_item text)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare k text := public.world_project_shop_item(p_shop, p_item);
begin
  if k is null then return true; end if;
  return public.world_project_stage(k) >= 1 and public.world_project_story(p_uid, k);
end $f$;

create or replace function public.world_project_cap_mul(p_uid uuid, p_shop text)
 returns int language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare k text;
begin
  select x.k into k from jsonb_each(public.world_project_rules() -> 'projects') x(k, p) where p ->> 'kind' = 'common' and p -> 'shops' ? p_shop limit 1;
  if k is null or public.world_project_stage(k) < (public.world_project_rules() -> 'lift' ->> 'shop')::int or not public.world_project_story(p_uid, k) then return 1; end if;
  return (public.world_project_rules() -> 'c_shop' ->> 'cap_mul')::int;
end $f$;

do $g$
declare f text;
begin
  foreach f in array array['world_weak_lift(uuid, text, text)', 'world_weak_here(uuid, text)', 'world_weak_view(uuid, text)', 'world_project_shop_stage(text)',
    'world_project_shop_ok(uuid, text, text)', 'world_project_cap_mul(uuid, text)', 'world_project_shop_item(text, text)'] loop
    perform pg_temp.pj_share('public.' || f);
    if f not like 'world_project_shop_item%' then perform pg_temp.pj_own('public.' || f, 'fn_owner_field'); end if;
  end loop;
end $g$;

select pg_temp.pj_fix('world_craft_item', array[
$q$and not public.world_banyo_here(uid) then select items into st$q$, $q$and not public.world_weak_here(uid, 'storage') then select items into st$q$]);
select pg_temp.pj_fix('world_outfit_design_weave', array[
$q$and not public.world_banyo_here(uid) then select items into st$q$, $q$and not public.world_weak_here(uid, 'storage') then select items into st$q$]);
select pg_temp.pj_fix('world_enhance_quote', array[
$q$and not public.world_banyo_here(uid) then$q$, $q$and not public.world_weak_here(uid, 'storage') then$q$]);
select pg_temp.pj_fix('world_weapon_enhance', array[
$q$if not public.world_banyo_here(uid) then select items into st$q$, $q$if not public.world_weak_here(uid, 'storage') then select items into st$q$]);
select pg_temp.pj_fix('world_storage_snapshot', array[
$q$and not public.world_banyo_here(uid),$q$, $q$and not public.world_weak_here(uid, 'storage'),$q$]);
select pg_temp.pj_fix('world_storage_check', array[
$q$if public.world_banyo_here(p_uid) then raise exception '%에는 창고가 없습니다.$q$, $q$if public.world_weak_here(p_uid, 'storage') then raise exception '%에는 창고가 없습니다.$q$]);
select pg_temp.pj_fix('world_letter_place_check', array[
$q$if public.world_banyo_here(p_uid) then$q$, $q$if public.world_weak_here(p_uid, 'letter') then$q$]);
select pg_temp.pj_fix('world_ucomm_place_check', array[
$q$if public.world_banyo_here(p_uid) then$q$, $q$if public.world_weak_here(p_uid, 'ucomm') then$q$]);
select pg_temp.pj_fix('world_housing_edit_block', array[
$q$if public.world_banyo_here(p_uid) then$q$, $q$if public.world_weak_here(p_uid, 'house') then$q$]);
select pg_temp.pj_fix('world_repair_mult', array[
$q$public.world_banyo_here(p_uid)$q$, $q$public.world_weak_here(p_uid, 'repair')$q$]);
select pg_temp.pj_fix('world_shop_sell', array[
$q$#3#public.world_banyo_here(uid)$q$, $q$public.world_weak_here(uid, 'sell')$q$]);
select pg_temp.pj_fix('world_shop_sell_status', array[
$q$public.world_banyo_here(uid)$q$, $q$public.world_weak_here(uid, 'sell')$q$]);
select pg_temp.pj_fix('world_smithy_snapshot', array[
$q$(not public.world_weak_shop(sh.shop_id) or ss.item_id in ('iron_ingot', 'charcoal'))$q$,
$q$(not (public.world_weak_shop(sh.shop_id) and public.world_weak_here(uid, 'smithy')) or ss.item_id in ('iron_ingot', 'charcoal'))$q$]);
select pg_temp.pj_fix('world_guard_action_context', array[
$q$IF k = 'trade' AND p ? 'unit_price' AND public.world_weak_safe(r.region_id) THEN$q$,
$q$IF k = 'trade' AND p ? 'unit_price' AND public.world_weak_safe(r.region_id) AND NOT public.world_weak_lift(new.actor_id, r.region_id, 'market') THEN$q$,
$q$IF r.region_id IS NULL OR NOT r.has_stable THEN$q$,
$q$IF r.region_id IS NULL OR NOT (r.has_stable OR public.world_weak_lift(new.actor_id, r.region_id, 'stable')) THEN$q$]);
select pg_temp.pj_fix('world_mount_acquire', array[
$q$IF NOT coalesce(r.has_stable,false) OR$q$, $q$IF NOT (coalesce(r.has_stable,false) OR public.world_weak_lift(uid, r.region_id, 'stable')) OR$q$]);
select pg_temp.pj_fix('world_mount_train', array[
$q$if not coalesce(r.has_stable, false) then$q$, $q$if not (coalesce(r.has_stable, false) or public.world_weak_lift(uid, r.region_id, 'stable')) then$q$]);

select pg_temp.pj_fix('world_shop_refresh', array[
$q$or sc.item_id in ('gwiheo_charm', 'seal_inkline') or random()$q$,
$q$or sc.item_id in ('gwiheo_charm', 'seal_inkline') or public.world_project_shop_item(p_shop, sc.item_id) is not null or random()$q$,
$q$   where s.shop_id = p_shop and s.stock = 0 and s.item_id in ($q$,
$q$   where s.shop_id = p_shop and s.stock = 0 and public.world_project_shop_item(p_shop, s.item_id) is null and s.item_id in ($q$,
$q$limit greatest(0, case when public.world_weak_shop(p_shop) then 4 else 6 end - (select count(*) from public.world_shop_stock where shop_id = p_shop and stock > 0)::int));$q$,
$q$limit greatest(0, case when public.world_weak_shop(p_shop) and public.world_project_shop_stage(p_shop) < 1 then 4 else 6 end - (select count(*) from public.world_shop_stock where shop_id = p_shop and stock > 0 and public.world_project_shop_item(p_shop, item_id) is null)::int));$q$]);
select pg_temp.pj_fix('world_shop_snapshot', array[
$q$'daily_cap', sc.daily_cap,$q$, $q$'daily_cap', sc.daily_cap * public.world_project_cap_mul(uid, sh.shop_id),$q$,
$q$   where ss.shop_id = sh.shop_id and ss.stock > 0;$q$, $q$   where ss.shop_id = sh.shop_id and ss.stock > 0 and public.world_project_shop_ok(uid, sh.shop_id, ss.item_id);$q$]);
select pg_temp.pj_fix('world_shop_buy', array[
$q$if not found or (public.world_weak_shop(shop) and s.shop_id = 'smithy' and p_item_id not in ('iron_ingot', 'charcoal')) then$q$,
$q$if not found or (public.world_weak_shop(shop) and public.world_weak_here(uid, 'smithy') and s.shop_id = 'smithy' and p_item_id not in ('iron_ingot', 'charcoal'))
     or not public.world_project_shop_ok(uid, s.shop_id, p_item_id) then$q$,
$q$       > (select sc.daily_cap from public.world_shop_catalog sc where sc.shop_id = s.shop_id and sc.item_id = p_item_id) then
      raise exception '이곳에서는 이 물품을 하루에 %개까지만 살 수 있습니다(오늘 %개 삼).', (select sc.daily_cap from public.world_shop_catalog sc where sc.shop_id = s.shop_id and sc.item_id = p_item_id),$q$,
$q$       > (select sc.daily_cap from public.world_shop_catalog sc where sc.shop_id = s.shop_id and sc.item_id = p_item_id) * public.world_project_cap_mul(uid, s.shop_id) then
      raise exception '이곳에서는 이 물품을 하루에 %개까지만 살 수 있습니다(오늘 %개 삼).', (select sc.daily_cap from public.world_shop_catalog sc where sc.shop_id = s.shop_id and sc.item_id = p_item_id) * public.world_project_cap_mul(uid, s.shop_id),$q$]);
