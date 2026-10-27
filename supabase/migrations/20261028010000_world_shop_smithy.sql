-- 상점 개편·대장간·일괄 수리·장비 분해·무기 강화
-- 1) 상점 재고를 없앤다. 하루 세 번(07·15·23시, 한국 시각) 품목과 값이 바뀐다. 늘 파는 기본 물품 몇 가지 외에는 그때그때 다른 품목이 나오고,
--    나온 품목은 수량 제한 없이 산다(한 번에 99개까지). world_shop_stock.stock은 이제 「이번 회차에 파는지」(1·0)만 뜻한다.
-- 2) 상점 판매: 장비도 팔 수 있다(임무 물품만 못 판다. 잠근 물품·장착 중인 마지막 한 개는 여전히 못 판다).
--    하루(24시간) 판매 수익 한도는 1,000전 또는 레벨×150전 가운데 큰 값이고, 화면에 지금까지 판 수익과 남은 한도를 보여 준다.
-- 3) 대장간(모든 안전지대): 장비 제작 재료(흔한·고급 등급)와 수리 도구를 판다(품목은 상점처럼 회차마다 바뀐다).
--    대장간에서 가진 장비를 한 번에 모두 고친다(일괄 수리, 값은 하나씩 고칠 때의 합).
-- 4) 장비 분해: 제작 숙련이 그 장비 단계에 이르면(1단계 1 · 2단계 4 · 3단계 8 · 4단계 12 · 5단계 16) 분해해 제작 재료를 돌려받는다.
--    돌려받는 재료는 그 장비(없으면 같은 종류·같은 단계 장비)의 제작법 재료의 절반(내림, 적어도 하나). 제작 경험치 6×단계.
-- 5) 무기 강화(대장간): 장착 중인 무기 +1~+10, 단계마다 위력 +5%. 자세한 규칙은 아래 6) 절.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

/* ── 1) 회차·갱신 도움 함수 ───────────────────────────── */
-- 새 함수의 주인을 바꾸려면 그 역할로 SET ROLE 할 수 있어야 한다(18876·18877은 평소 꺼져 있어 이 파일 끝에서 다시 끈다)
grant fn_owner_18876 to postgres with inherit true, set true;
grant fn_owner_18877 to postgres with inherit true, set true;
grant fn_owner_18878 to postgres with inherit true;

-- 지금 회차의 시작 시각(07·15·23시)
create or replace function public.world_shop_slot()
returns timestamptz language sql stable set search_path to 'pg_catalog', 'public' as $$
  select s - case when s > now() then interval '1 day' else interval '0' end from (
    select date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul'
      + case when extract(hour from now() at time zone 'Asia/Seoul') >= 23 then interval '23 hours'
             when extract(hour from now() at time zone 'Asia/Seoul') >= 15 then interval '15 hours'
             when extract(hour from now() at time zone 'Asia/Seoul') >= 7 then interval '7 hours'
             else interval '-1 hour' end as s) x
$$;

-- 회차가 바뀌었으면 품목과 값을 새로 고른다(늘 파는 기본 물품 + 그 밖의 절반쯤, 적어도 6가지)
create or replace function public.world_shop_refresh(p_shop text)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare slot timestamptz := public.world_shop_slot(); staples text[] := array['tonic', 'herb', 'herbal_extract', 'ward_talisman', 'travel_ration', 'repair_kit', 'spirit_tea', 'iron_ingot', 'charcoal'];
begin
  perform pg_advisory_xact_lock(hashtext('yh-shop:' || p_shop));
  if exists (select 1 from public.world_shop_stock where shop_id = p_shop and refreshed_at >= slot) then return; end if;
  insert into public.world_shop_stock(shop_id, item_id, stock, unit_price, refreshed_at)
  select sc.shop_id, sc.item_id, case when sc.item_id = any(staples) or random() < 0.55 then 1 else 0 end,
         greatest(1, round(sc.base_price * (0.85 + random() * 0.3))::bigint), slot
    from public.world_shop_catalog sc where sc.shop_id = p_shop
  on conflict (shop_id, item_id) do update set stock = excluded.stock, unit_price = excluded.unit_price, refreshed_at = excluded.refreshed_at;
  -- 너무 적게 나오면 몇 가지를 더 내놓는다
  update public.world_shop_stock s set stock = 1
   where s.shop_id = p_shop and s.stock = 0 and s.item_id in (
     select item_id from public.world_shop_stock where shop_id = p_shop and stock = 0 order by random()
      limit greatest(0, 6 - (select count(*) from public.world_shop_stock where shop_id = p_shop and stock > 0)::int));
end $$;
alter function public.world_shop_refresh(text) owner to fn_owner_18876;
revoke all on function public.world_shop_refresh(text) from public, anon, authenticated;

-- 판매 수익 한도: 1,000전 또는 레벨×150전 가운데 큰 값(24시간)
create or replace function public.world_shop_sell_status()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); lv int; cap bigint; sold bigint;
begin
  if uid is null then return null; end if;
  select level into lv from public.world_characters where owner_id = uid;
  cap := greatest(1000, coalesce(lv, 1) * 150);
  select coalesce(sum(currency_delta), 0) into sold from public.world_economy_ledger where owner_id = uid and action = 'shop_sell' and created_at > now() - interval '24 hours';
  return jsonb_build_object('sold', sold, 'cap', cap, 'left', greatest(0, cap - sold),
    'resets_at', (select min(created_at) + interval '24 hours' from public.world_economy_ledger where owner_id = uid and action = 'shop_sell' and created_at > now() - interval '24 hours'));
end $$;
alter function public.world_shop_sell_status() owner to fn_owner_18878;
revoke all on function public.world_shop_sell_status() from public, anon;
grant execute on function public.world_shop_sell_status() to authenticated, fn_owner_18876;

-- 상점에 팔 때 받는 값(개당, 세금 전): 상점 기준가(대장간 제외)·기준 시세·단계 순으로 정한 값의 45%
create or replace function public.world_shop_sell_unit(p_item text)
returns bigint language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select greatest(1, round(coalesce((select min(s.base_price) from public.world_shop_catalog s where s.item_id = i.item_id and s.shop_id <> 'smithy'),
                                    i.reference_price, 10 * coalesce(i.tier, 1)) * 0.45))::bigint
    from public.world_item_catalog i where i.item_id = p_item
$$;
alter function public.world_shop_sell_unit(text) owner to fn_owner_18878;
grant execute on function public.world_shop_sell_unit(text) to public;
revoke execute on function public.world_shop_sell_unit(text) from anon;

/* ── 2) 상점 보기·사기·팔기 ───────────────────────────── */
create or replace function public.world_shop_snapshot()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; sh record; payload jsonb; slot timestamptz := public.world_shop_slot();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터가 없습니다.'; end if;
  select * into sh from public.world_current_shop(uid);
  if sh.shop_id is null then
    return jsonb_build_object('available', false, 'gil', c.gil, 'location', c.location, 'stock', '[]'::jsonb, 'content', '상점은 안전지대에만 있습니다.');
  end if;
  perform public.world_shop_refresh(sh.shop_id);
  select coalesce(jsonb_agg(jsonb_build_object('item_id', ss.item_id, 'item_name', i.item_name, 'category', i.category, 'tier', i.tier, 'unit_price', ss.unit_price,
           'description', i.description, 'base_price', sc.base_price) order by i.category, i.tier, i.item_name), '[]'::jsonb) into payload
    from public.world_shop_stock ss join public.world_item_catalog i on i.item_id = ss.item_id
    join public.world_shop_catalog sc on sc.shop_id = ss.shop_id and sc.item_id = ss.item_id
   where ss.shop_id = sh.shop_id and ss.stock > 0;
  return jsonb_build_object('available', true, 'shop_id', sh.shop_id, 'shop_name', sh.shop_name, 'gil', c.gil, 'location', c.location, 'stock', payload,
    'refresh_schedule', '매일 07:00 / 15:00 / 23:00 (한국 시간)', 'next_refresh', slot + interval '8 hours', 'sell', public.world_shop_sell_status());
end $function$;

create or replace function public.world_smithy_snapshot()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; sh record; payload jsonb; slot timestamptz := public.world_shop_slot();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터가 없습니다.'; end if;
  select * into sh from public.world_current_shop(uid);
  if sh.shop_id is null then return jsonb_build_object('available', false, 'content', '대장간은 안전지대에만 있습니다.'); end if;
  perform public.world_shop_refresh('smithy');
  select coalesce(jsonb_agg(jsonb_build_object('item_id', ss.item_id, 'item_name', i.item_name, 'category', i.category, 'tier', i.tier, 'unit_price', ss.unit_price,
           'description', i.description) order by i.tier, i.item_name), '[]'::jsonb) into payload
    from public.world_shop_stock ss join public.world_item_catalog i on i.item_id = ss.item_id
   where ss.shop_id = 'smithy' and ss.stock > 0;
  return jsonb_build_object('available', true, 'shop_id', 'smithy', 'shop_name', '대장간', 'gil', c.gil, 'location', c.location, 'stock', payload,
    'next_refresh', slot + interval '8 hours');
end $function$;
alter function public.world_smithy_snapshot() owner to fn_owner_18876;
revoke all on function public.world_smithy_snapshot() from public, anon;
grant execute on function public.world_smithy_snapshot() to authenticated;

-- 사기: 이번 회차에 이 안전지대 상점이나 대장간이 파는 물품만, 수량 제한 없이(한 번에 99개)
create or replace function public.world_shop_buy(p_item_id text, p_qty integer default 1)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; shop text; s public.world_shop_stock%rowtype; inv jsonb; total bigint; msg text; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_qty is null or p_qty < 1 or p_qty > 99 then raise exception '구매 수량은 1~99개입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 등록하세요.'; end if;
  if c.is_dead or c.health <= 0 or c.downed_at is not null then raise exception '현재 상태에서는 구매할 수 없습니다.'; end if;
  select cs.shop_id into shop from public.world_current_shop(uid) cs;
  if shop is null then raise exception '상점은 안전지대에만 있습니다.'; end if;
  perform public.world_shop_refresh(shop); perform public.world_shop_refresh('smithy');
  select * into s from public.world_shop_stock where shop_id in (shop, 'smithy') and item_id = p_item_id and stock > 0
   order by (shop_id = shop) desc limit 1;
  if not found then raise exception '지금은 팔지 않는 물품입니다. 품목은 하루 세 번(07·15·23시) 바뀝니다.'; end if;
  total := s.unit_price * p_qty;
  if c.gil < total then raise exception '재화가 부족합니다.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  inv := jsonb_set(inv, array[p_item_id], to_jsonb(coalesce((inv ->> p_item_id)::int, 0) + p_qty), true);
  update public.world_characters set gil = gil - total, inventory = inv, updated_at = now() where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'shop_buy', -total, true, jsonb_build_object('shop', s.shop_id, 'item', p_item_id, 'qty', p_qty));
  select item_name into nm from public.world_item_catalog where item_id = p_item_id;
  msg := '구매 완료: ' || coalesce(nm, p_item_id) || ' ×' || p_qty || ' · ' || total || '전';
  insert into public.world_events(actor_id, actor_name, event_type, content, payload) values (uid, c.character_name, 'shop_buy', msg, jsonb_build_object('shop', s.shop_id, 'item', p_item_id, 'qty', p_qty, 'gil', total));
  return jsonb_build_object('content', msg, 'gil', c.gil - total, 'inventory', inv);
end $function$;

-- 팔기: 임무 물품 외에는 장비도 판다. 한도는 world_shop_sell_status와 같다.
create or replace function public.world_shop_sell(p_item_id text, p_qty integer default 1)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; inv jsonb; item public.world_item_catalog%rowtype; price bigint; tax bigint; net bigint; earned bigint; cap bigint; msg text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_qty is null or p_qty < 1 or p_qty > 999 then raise exception '판매 수량이 올바르지 않습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 등록하세요.'; end if;
  if c.is_dead or c.health <= 0 or c.downed_at is not null then raise exception '현재 상태에서는 판매할 수 없습니다.'; end if;
  select * into item from public.world_item_catalog where item_id = p_item_id;
  if not found or item.category = 'quest' then raise exception '상점에 판매할 수 없는 품목입니다.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  if coalesce((inv ->> p_item_id)::int, 0) < p_qty then raise exception '보유 수량이 부족합니다.'; end if;
  perform public.world_item_give_guard(uid, p_item_id, coalesce((inv ->> p_item_id)::int, 0), p_qty);
  price := public.world_shop_sell_unit(p_item_id);
  tax := greatest(1, round(price * p_qty * 0.05)::bigint); net := greatest(0, price * p_qty - tax);
  cap := greatest(1000, coalesce(c.level, 1) * 150);
  select coalesce(sum(currency_delta), 0) into earned from public.world_economy_ledger where owner_id = uid and action = 'shop_sell' and created_at > now() - interval '24 hours';
  if earned + net > cap then
    raise exception '상점 판매 수익은 24시간에 %전까지입니다. 지금까지 %전을 받아 남은 한도는 %전입니다.', cap, earned, greatest(0, cap - earned);
  end if;
  inv := case when coalesce((inv ->> p_item_id)::int, 0) - p_qty <= 0 then inv - p_item_id else jsonb_set(inv, array[p_item_id], to_jsonb((inv ->> p_item_id)::int - p_qty), true) end;
  update public.world_characters set inventory = inv, gil = gil + net, updated_at = now() where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  values (uid, 'shop_sell', net, false, jsonb_build_object('item', p_item_id, 'qty', p_qty, 'tax', tax)), (uid, 'sale_tax', -tax, true, jsonb_build_object('item', p_item_id, 'qty', p_qty));
  msg := '판매 완료: ' || item.item_name || ' ×' || p_qty || ' · 세금 빼고 ' || net || '전 · 오늘 판매 ' || (earned + net) || '/' || cap || '전';
  insert into public.world_events(actor_id, actor_name, event_type, content, payload) values (uid, c.character_name, 'shop_sell', msg, jsonb_build_object('item', p_item_id, 'qty', p_qty, 'gil', net, 'tax', tax));
  return jsonb_build_object('content', msg, 'gil', c.gil + net, 'inventory', inv, 'tax', tax, 'sold', earned + net, 'cap', cap, 'left', greatest(0, cap - earned - net));
end $function$;

-- 화면이 쓰는 매입값을 같은 규칙으로
create or replace function public.world_economy_price_snapshot()
returns jsonb language plpgsql set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('item_id', i.item_id, 'item_name', i.item_name, 'category', i.category, 'tier', i.tier, 'rarity', i.rarity,
    'acquisition_difficulty', i.acquisition_difficulty, 'tradeable', i.tradeable, 'reference_price', i.reference_price,
    'npc_buy_price', coalesce((select min(s.base_price) from public.world_shop_catalog s where s.item_id = i.item_id), i.reference_price),
    'npc_sell_price', case when i.category = 'quest' then 0 else greatest(1, round(public.world_shop_sell_unit(i.item_id) * 0.95))::bigint end)
    order by i.category, i.tier, i.item_name) from public.world_item_catalog i), '[]'::jsonb);
end $function$;

grant fn_owner_18876 to postgres with inherit false, set false;
grant fn_owner_18877 to postgres with inherit false, set false;
grant fn_owner_18878 to postgres with inherit false;

/* ── 3) 대장간 품목: 장비 제작 재료(흔한·고급)와 수리 도구 ── */
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
select 'smithy', i.item_id, greatest(5, round(coalesce(i.reference_price, 20 * coalesce(i.tier, 1)) * 1.25))::bigint, 1, 1
  from public.world_item_catalog i
 where i.item_id in (
     select distinct k from public.world_crafting_recipes r
       join public.world_item_catalog o on o.item_id = r.output_item
       cross join lateral jsonb_object_keys(coalesce(r.ingredients, '{}'::jsonb)) k
      where o.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool'))
   and coalesce(i.rarity, 'common') in ('common', 'uncommon') and i.category <> 'quest'
on conflict do nothing;
-- 강화 재료(월철 주괴·정련 숯은 늘 판다, 강철 주괴·응축 영핵은 회차에 따라)
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
select 'smithy', i.item_id, greatest(5, round(coalesce(i.reference_price, 20) * 1.25))::bigint, 1, 1
  from public.world_item_catalog i where i.item_id in ('iron_ingot', 'charcoal', 'steel_ingot', 'spirit_core')
on conflict do nothing;
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
select 'smithy', 'repair_kit', greatest(5, round(coalesce(reference_price, 40) * 1.1))::bigint, 1, 1 from public.world_item_catalog where item_id = 'repair_kit'
on conflict do nothing;

/* ── 4) 일괄 수리(대장간) ─────────────────────────────── */
grant select on public.world_crafting_recipes to fn_owner_field;
grant update (crafting_xp, crafting_rank) on public.world_characters to fn_owner_field;

create or replace function public.world_repair_quote()
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  with me as (select public.fn_owner_auth_uid() as uid),
  g as (
    select i.item_id, i.item_name, i.tier, public.world_item_max_durability(i.item_id) mx, d.durability cur,
           exists (select 1 from public.world_character_equipment e, me where e.owner_id = me.uid and e.item_id = i.item_id) equipped
      from public.world_item_durability d join public.world_item_catalog i on i.item_id = d.item_id, me
     where d.owner_id = me.uid and coalesce((select (c.inventory ->> d.item_id)::int from public.world_characters c where c.owner_id = me.uid), 0) > 0
  )
  select jsonb_build_object('items', coalesce(jsonb_agg(jsonb_build_object('item_id', item_id, 'name', item_name, 'durability', cur, 'max', mx, 'equipped', equipped,
      'cost', greatest(5, ceil((mx - cur) * (coalesce(tier, 1) + 1) / 2.0)::int)) order by equipped desc, item_name), '[]'::jsonb),
    'total', coalesce(sum(greatest(5, ceil((mx - cur) * (coalesce(tier, 1) + 1) / 2.0)::int)), 0))
  from g where mx is not null and cur < mx
$$;

create or replace function public.world_equipment_repair_all()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; q jsonb; total int; n int; x jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 수리할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '전투 중에는 수리할 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then raise exception '원정 중에는 수리할 수 없습니다.'; end if;
  r := public.world_field_region(c.location);
  if not coalesce(r.is_safe_zone, false) then raise exception '일괄 수리는 안전지대의 대장간에서 할 수 있습니다.'; end if;
  q := public.world_repair_quote(); total := coalesce((q ->> 'total')::int, 0); n := jsonb_array_length(q -> 'items');
  if n = 0 then raise exception '고칠 장비가 없습니다.'; end if;
  if c.gil < total then raise exception '%', format('일괄 수리비 %s전이 모자랍니다.', total); end if;
  for x in select value from jsonb_array_elements(q -> 'items') loop
    update public.world_item_durability set durability = (x ->> 'max')::int, max_durability = (x ->> 'max')::int, updated_at = now() where owner_id = uid and item_id = x ->> 'item_id';
  end loop;
  update public.world_characters set gil = gil - total, updated_at = now() where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'repair', -total, true, jsonb_build_object('method', 'smithy_all', 'count', n));
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'repair', '대장간에서 장비 ' || n || '개를 모두 고쳤습니다 · ' || total || '전', jsonb_build_object('method', 'gil_all', 'count', n, 'cost', total));
  return jsonb_build_object('ok', true, 'content', '장비 ' || n || '개를 모두 고쳤습니다 · ' || total || '전', 'cost', total, 'count', n);
end $$;

/* ── 5) 장비 분해 ─────────────────────────────────────── */
create or replace function public.world_dismantle_need(p_tier int)
returns int language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select case coalesce(p_tier, 1) when 1 then 1 when 2 then 4 when 3 then 8 when 4 then 12 else 16 end
$$;
-- 분해하면 돌려받는 재료: 그 장비의 제작법 → 같은 종류·같은 단계의 제작법 → 한 단계 아래 → 영기 가루
create or replace function public.world_dismantle_yield(p_item text)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare it public.world_item_catalog%rowtype; ing jsonb; out jsonb := '{}'::jsonb; k text; v int;
begin
  select * into it from public.world_item_catalog where item_id = p_item;
  if not found then return '{}'::jsonb; end if;
  select r.ingredients into ing from public.world_crafting_recipes r where r.output_item = p_item order by r.recipe_id limit 1;
  if ing is null then
    select r.ingredients into ing from public.world_crafting_recipes r join public.world_item_catalog o on o.item_id = r.output_item
     where o.category = it.category and o.tier between greatest(1, it.tier - 1) and it.tier and r.ingredients <> '{}'::jsonb
     order by o.tier desc, r.recipe_id limit 1;
  end if;
  if ing is null or ing = '{}'::jsonb then return jsonb_build_object('spirit_dust', greatest(1, coalesce(it.tier, 1))); end if;
  for k, v in select key, (value)::text::int from jsonb_each(ing) loop
    if floor(v * 0.5) >= 1 then out := out || jsonb_build_object(k, floor(v * 0.5)::int); end if;
  end loop;
  if out = '{}'::jsonb then
    select key into k from jsonb_each(ing) order by (value)::text::int desc, key limit 1;
    out := jsonb_build_object(k, 1);
  end if;
  return out;
end $$;

create or replace function public.world_dismantle_item(p_item_id text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; have int; y jsonb; inv jsonb; k text; v int; need int; gain int; nm text := '';
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 분해할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '전투 중에는 분해할 수 없습니다.'; end if;
  select * into it from public.world_item_catalog where item_id = p_item_id;
  if not found or it.category not in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then raise exception '분해할 수 있는 장비가 아닙니다.'; end if;
  need := public.world_dismantle_need(it.tier);
  if coalesce(c.crafting_rank, 1) < need then raise exception '%', format('%s단계 장비는 제작 숙련 %s단계부터 분해할 수 있습니다(지금 %s단계).', it.tier, need, coalesce(c.crafting_rank, 1)); end if;
  inv := coalesce(c.inventory, '{}'::jsonb); have := coalesce((inv ->> p_item_id)::int, 0);
  if have < 1 then raise exception '가방에 그 장비가 없습니다.'; end if;
  perform public.world_item_give_guard(uid, p_item_id, have, 1);
  y := public.world_dismantle_yield(p_item_id);
  inv := case when have - 1 <= 0 then inv - p_item_id else jsonb_set(inv, array[p_item_id], to_jsonb(have - 1)) end;
  for k, v in select key, (value)::text::int from jsonb_each(y) loop
    inv := jsonb_set(inv, array[k], to_jsonb(coalesce((inv ->> k)::int, 0) + v), true);
    nm := nm || case when nm = '' then '' else ', ' end || coalesce((select item_name from public.world_item_catalog where item_id = k), k) || ' ×' || v;
  end loop;
  gain := 6 * coalesce(it.tier, 1);
  update public.world_characters set inventory = inv, crafting_xp = coalesce(crafting_xp, 0) + gain,
    crafting_rank = greatest(coalesce(crafting_rank, 1), public.world_skill_rank(coalesce(crafting_xp, 0) + gain, 'crafting')), updated_at = now()
   where owner_id = uid;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'dismantle', it.item_name || ' 분해 → ' || nm, jsonb_build_object('item', p_item_id, 'yield', y, 'xp', gain));
  return jsonb_build_object('ok', true, 'content', it.item_name || '을(를) 분해해 ' || nm || '을(를) 얻었습니다 · 제작 경험 +' || gain, 'yield', y);
end $$;

do $$
declare f text;
begin
  foreach f in array array['world_repair_quote()', 'world_equipment_repair_all()', 'world_dismantle_need(integer)', 'world_dismantle_yield(text)', 'world_dismantle_item(text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
grant execute on function public.world_shop_slot() to public;
-- 다른 함수 주인이 부르는 함수(사기 → 품목 갱신, 수리·분해 → 내구도·숙련 계산)
grant execute on function public.world_shop_refresh(text) to fn_owner_18877;
grant select on public.world_item_catalog to fn_owner_18877; -- 구매 문구에 물품 이름(누구나 읽는 목록)
grant execute on function public.world_item_max_durability(text) to fn_owner_field;
grant execute on function public.world_skill_rank(integer, text) to fn_owner_field;

/* ── 6) 무기 강화(대장간) ─────────────────────────────── */
-- 장착 중인 무기를 +1씩 +10까지 강화한다. 단계마다 무기 위력 +5%(+10이면 +50%).
-- 비용(지금 +n → +n+1): 전 30×무기 단계×(n+1), 월철 주괴 2+n · 정련 숯 1+n/2, +4부터 강철 주괴 n−3, +7부터 응축 영핵 n−6.
-- 성공 확률: +3까지 100%, 그 뒤 90·80·70·60·50·40·30%(법구 제작사 +10%p). 실패하면 재료와 전만 들고 단계는 그대로다.
-- 강화는 그 무기 종류에 붙는다(world_gear_enhance). 그 무기를 모두 내주면(팔기·거래·분해·버리기) 강화도 사라진다.
create table if not exists public.world_gear_enhance (
  owner_id uuid not null,
  item_id text not null,
  level int not null default 0 check (level between 0 and 10),
  updated_at timestamptz not null default now(),
  primary key (owner_id, item_id)
);
alter table public.world_gear_enhance enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'world_gear_enhance' and policyname = 'world_gear_enhance_read_own') then
    create policy world_gear_enhance_read_own on public.world_gear_enhance for select to authenticated using (owner_id = auth.uid());
  end if;
end $$;
revoke all on public.world_gear_enhance from anon, authenticated;
grant select on public.world_gear_enhance to authenticated;
grant select, insert, update, delete on public.world_gear_enhance to fn_owner_field;

create or replace function public.world_enhance_level(p_owner uuid, p_item text)
returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select level from public.world_gear_enhance where owner_id = p_owner and item_id = p_item), 0)
$$;

-- 다음 단계 비용
create or replace function public.world_enhance_cost(p_level int, p_tier int)
returns jsonb language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select jsonb_build_object('gil', 30 * greatest(1, coalesce(p_tier, 1)) * (p_level + 1),
    'items', jsonb_strip_nulls(jsonb_build_object('iron_ingot', 2 + p_level, 'charcoal', 1 + p_level / 2,
      'steel_ingot', case when p_level >= 4 then p_level - 3 end, 'spirit_core', case when p_level >= 7 then p_level - 6 end)))
$$;

create or replace function public.world_enhance_quote()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; w text; it public.world_item_catalog%rowtype; lv int; cost jsonb; chance int; pw numeric;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  select item_id into w from public.world_character_equipment where owner_id = uid and slot = 'weapon';
  if w is null then return jsonb_build_object('weapon', null); end if;
  select * into it from public.world_item_catalog where item_id = w;
  lv := public.world_enhance_level(uid, w);
  pw := coalesce((it.equipment_traits ->> 'power')::numeric, 2);
  if lv >= 10 then
    return jsonb_build_object('weapon', w, 'name', it.item_name, 'tier', it.tier, 'level', lv, 'max', 10, 'power', round(pw * (1 + 0.05 * lv), 1));
  end if;
  cost := public.world_enhance_cost(lv, it.tier);
  chance := least(100, case when lv < 3 then 100 else 100 - 10 * (lv - 2) end + case when c.job_key = 'artificer' then 10 else 0 end);
  return jsonb_build_object('weapon', w, 'name', it.item_name, 'tier', it.tier, 'level', lv, 'max', 10, 'chance', chance,
    'power', round(pw * (1 + 0.05 * lv), 1), 'next_power', round(pw * (1 + 0.05 * (lv + 1)), 1),
    'gil', (cost ->> 'gil')::int, 'items', cost -> 'items', 'have_gil', c.gil,
    'names', (select coalesce(jsonb_object_agg(i.item_id, i.item_name), '{}'::jsonb) from public.world_item_catalog i where i.item_id in (select jsonb_object_keys(cost -> 'items'))),
    'have', (select coalesce(jsonb_object_agg(k, coalesce((c.inventory ->> k)::int, 0)), '{}'::jsonb) from jsonb_object_keys(cost -> 'items') k));
end $$;

create or replace function public.world_weapon_enhance()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; w text; it public.world_item_catalog%rowtype;
  lv int; cost jsonb; chance int; inv jsonb; k text; v int; ok boolean; msg text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 강화할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '전투 중에는 강화할 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then raise exception '원정 중에는 강화할 수 없습니다.'; end if;
  r := public.world_field_region(c.location);
  if not coalesce(r.is_safe_zone, false) then raise exception '무기 강화는 안전지대의 대장간에서 할 수 있습니다.'; end if;
  select item_id into w from public.world_character_equipment where owner_id = uid and slot = 'weapon';
  if w is null then raise exception '장착 중인 무기가 없습니다.'; end if;
  select * into it from public.world_item_catalog where item_id = w;
  lv := public.world_enhance_level(uid, w);
  if lv >= 10 then raise exception '이미 +10까지 강화한 무기입니다.'; end if;
  cost := public.world_enhance_cost(lv, it.tier);
  chance := least(100, case when lv < 3 then 100 else 100 - 10 * (lv - 2) end + case when c.job_key = 'artificer' then 10 else 0 end);
  if c.gil < (cost ->> 'gil')::int then raise exception '%', format('강화 비용 %s전이 모자랍니다.', cost ->> 'gil'); end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  for k, v in select key, value::text::int from jsonb_each(cost -> 'items') loop
    if coalesce((inv ->> k)::int, 0) < v then
      raise exception '%', format('재료가 모자랍니다: %s %s개 필요(가진 것 %s개). 대장간에서 살 수 있습니다.',
        coalesce((select item_name from public.world_item_catalog where item_id = k), '재료'), v, coalesce((inv ->> k)::int, 0));
    end if;
    inv := case when (inv ->> k)::int - v <= 0 then inv - k else jsonb_set(inv, array[k], to_jsonb((inv ->> k)::int - v)) end;
  end loop;
  ok := random() * 100 < chance;
  update public.world_characters set inventory = inv, gil = gil - (cost ->> 'gil')::int, updated_at = now() where owner_id = uid;
  if ok then
    insert into public.world_gear_enhance(owner_id, item_id, level, updated_at) values (uid, w, lv + 1, now())
      on conflict (owner_id, item_id) do update set level = excluded.level, updated_at = now();
    msg := it.item_name || ' +' || (lv + 1) || ' 강화에 성공했습니다. 위력 +' || (5 * (lv + 1)) || '%';
  else
    msg := it.item_name || ' +' || (lv + 1) || ' 강화에 실패했습니다. 재료와 전만 들고 +' || lv || '에 머뭅니다.';
  end if;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  values (uid, 'enhance', -(cost ->> 'gil')::int, true, jsonb_build_object('item', w, 'from', lv, 'ok', ok, 'items', cost -> 'items'));
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'enhance', msg, jsonb_build_object('item', w, 'from', lv, 'to', case when ok then lv + 1 else lv end, 'ok', ok, 'chance', chance));
  return jsonb_build_object('ok', true, 'success', ok, 'level', case when ok then lv + 1 else lv end, 'content', msg);
end $$;

-- 그 무기를 하나도 갖고 있지 않게 되면 강화를 지운다
create or replace function public.world_enhance_cleanup()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  delete from public.world_gear_enhance g
   where g.owner_id = new.owner_id and coalesce((new.inventory ->> g.item_id)::int, 0) <= 0;
  return new;
end $$;
drop trigger if exists trg_world_enhance_cleanup on public.world_characters;
create trigger trg_world_enhance_cleanup after update of inventory on public.world_characters
  for each row when (new.inventory is distinct from old.inventory) execute function public.world_enhance_cleanup();

do $$
declare f text;
begin
  foreach f in array array['world_enhance_level(uuid,text)', 'world_enhance_cost(integer,integer)', 'world_enhance_quote()', 'world_weapon_enhance()', 'world_enhance_cleanup()'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon', f);
  end loop;
  execute 'grant execute on function public.world_enhance_quote() to authenticated';
  execute 'grant execute on function public.world_weapon_enhance() to authenticated';
  execute 'grant execute on function public.world_enhance_cost(integer,integer) to authenticated';
end $$;

-- 전투 능력치에 강화 반영(전투·원정·화면이 모두 이 함수를 쓴다)
do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_combat_stats'::regproc);
  if position('world_enhance_level' in d) > 0 then return; end if;
  d := replace(d, $q$IF w_dur * 4 < w_max THEN wpow := wpow * 0.8; w_state := 'worn'; END IF;$q$,
    $q$IF w_dur * 4 < w_max THEN wpow := wpow * 0.8; w_state := 'worn'; END IF;
      wpow := wpow * (1 + 0.05 * public.world_enhance_level(p_owner, w_id));$q$);
  d := replace(d, $q$jsonb_build_object('item_id', w_id, 'name', w_name,$q$, $q$jsonb_build_object('item_id', w_id, 'name', w_name, 'enhance', public.world_enhance_level(p_owner, w_id),$q$);
  if position('wpow * (1 + 0.05' in d) = 0 or position('''enhance''' in d) = 0 then raise exception '전투 능력치 함수에서 바꿀 줄을 찾지 못했습니다'; end if;
  execute d;
end $$;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028010000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select (select count(*) from public.world_shop_catalog where shop_id = 'smithy') as smithy_items,
       (select count(*) from pg_proc where proname in ('world_shop_refresh', 'world_smithy_snapshot', 'world_shop_sell_status', 'world_shop_sell_unit',
          'world_repair_quote', 'world_equipment_repair_all', 'world_dismantle_item', 'world_dismantle_yield')) as functions;
