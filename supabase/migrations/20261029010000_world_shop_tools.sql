-- 안전지대 상점에 현장 채집도·월철 곡괭이(2026-10-29): 시작 도구를 분해하거나 잃어도 다시 살 수 있게 한다.
--   모든 안전지대 상점(정청·객사 포함 8곳)의 늘 파는 품목. 기준가 50전(값은 회차마다 ×0.85~1.15 → 43~58전).
--   되팔기 22전(50×45%, 거래세 5% 빼면 21전)·분해 결과(부적목 1 + 수향 갈대 1, 상점가 최대 40전)보다 비싸 사고팔거나 분해해서 이득을 볼 수 없다.
grant fn_owner_field to postgres with inherit true, set true;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
select s.shop_id, t.item_id, 50, 1, 1
  from (values ('night_office_store'), ('capital_market'), ('river_market'), ('south_market'), ('north_market'),
               ('frontier_market'), ('underworld_market'), ('astral_market')) s(shop_id)
 cross join (values ('field_knife'), ('ore_pick')) t(item_id)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;

-- 늘 파는 품목에 넣는다
do $$
declare d text := pg_get_functiondef('public.world_shop_refresh(text)'::regprocedure);
  a text := '''iron_ingot'', ''charcoal''];';
begin
  if position('field_knife' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '상점 늘 파는 품목 자리를 찾지 못했습니다'; end if;
  execute replace(d, a, '''iron_ingot'', ''charcoal'', ''field_knife'', ''ore_pick''];');
end $$;

-- 지금 회차 진열에도 바로 올린다(다음 07·15·23시를 기다리지 않게)
insert into public.world_shop_stock(shop_id, item_id, stock, unit_price, refreshed_at)
select sc.shop_id, sc.item_id, 1, greatest(1, round(sc.base_price * (0.85 + random() * 0.3))::bigint),
       coalesce((select max(x.refreshed_at) from public.world_shop_stock x where x.shop_id = sc.shop_id), public.world_shop_slot())
  from public.world_shop_catalog sc
 where sc.item_id in ('field_knife', 'ore_pick') and sc.shop_id <> 'smithy'
on conflict (shop_id, item_id) do update set stock = 1, unit_price = excluded.unit_price;

grant fn_owner_field to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029010000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
