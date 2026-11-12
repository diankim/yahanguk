lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function public.world_shop_sellable(p_item text) returns boolean
 language sql stable
 set search_path to 'pg_catalog', 'public'
as $function$
  select exists (select 1 from public.world_item_catalog i where i.item_id = p_item
                  and i.category <> 'quest' and not (i.category = 'furniture' and not coalesce(i.tradeable, false)))
$function$;

select pg_temp.yh_fix('world_shop_sell(text,integer,boolean)', array[
$q$if not found or item.category = 'quest' or (item.category = 'furniture' and not coalesce(item.tradeable, false)) then$q$,
$q$if not found or not public.world_shop_sellable(item.item_id) then$q$]);

select pg_temp.yh_fix('world_economy_price_snapshot()', array[
$q$case when i.category = 'quest' then 0 else$q$,
$q$case when not public.world_shop_sellable(i.item_id) then 0 else$q$]);

grant select on public.world_shop_buy_caps to fn_owner_18876;

select pg_temp.yh_fix('world_shop_snapshot()', array[
$q$'description', i.description, 'base_price', sc.base_price)$q$,
$q$'description', i.description, 'base_price', sc.base_price, 'daily_cap', sc.daily_cap,
           'bought', case when sc.daily_cap is null then null else coalesce((select bc.qty from public.world_shop_buy_caps bc
             where bc.owner_id = uid and bc.day = (now() at time zone 'Asia/Seoul')::date and bc.item_id = ss.item_id), 0) end)$q$]);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116100000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
