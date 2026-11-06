drop function if exists public.world_shop_sell(text, integer);
create function public.world_shop_sell(p_item_id text, p_qty integer default 1, p_overflow boolean default false)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; inv jsonb; item public.world_item_catalog%rowtype; price bigint; tax bigint; net bigint; earned bigint; cap bigint; lim bigint; room bigint; paid bigint; dropped int := 0; msg text;
begin perform public.world_travel_guard('상점 거래');
  if uid is null then raise exception '로그인이 필요합니다.'; end if; perform set_config('yh.wear_leaves', 'on', true);
  if p_qty is null or p_qty < 1 or p_qty > 999 then raise exception '판매 수량이 올바르지 않습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 등록하세요.'; end if;
  if c.is_dead or c.health <= 0 or c.downed_at is not null then raise exception '현재 상태에서는 판매할 수 없습니다.'; end if;
  select * into item from public.world_item_catalog where item_id = p_item_id;
  if not found or item.category = 'quest' or (item.category = 'furniture' and not coalesce(item.tradeable, false)) then raise exception '상점에 판매할 수 없는 품목입니다.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  if coalesce((inv ->> p_item_id)::int, 0) < p_qty then raise exception '보유 수량이 부족합니다.'; end if;
  perform public.world_item_give_guard(uid, p_item_id, coalesce((inv ->> p_item_id)::int, 0), p_qty);
  price := public.world_shop_sell_unit(p_item_id);
  if public.world_banyo_here(uid) then price := greatest(1, price / 2); end if;
  tax := case when public.world_trade_tax_mult(uid) <= 0 then 0 else greatest(1, round(price * p_qty * public.world_affil_tax() * public.world_trade_tax_mult(uid))::bigint) end; net := greatest(0, price * p_qty - tax);
  cap := 2000 + public.world_affil_cap();
  lim := case when public.world_banyo_here(uid) then cap / 2 else cap end;
  select coalesce(sum(currency_delta), 0) into earned from public.world_economy_ledger where owner_id = uid and action = 'shop_sell' and created_at > now() - interval '24 hours';
  room := greatest(0, lim - earned);
  paid := net;
  if earned + net > lim then
    if not coalesce(p_overflow, false) or room <= 0 then
      if public.world_banyo_here(uid) then
        raise exception '반요촌에서는 24시간 판매 수익이 %전(한도의 절반)을 넘으면 더 팔 수 없습니다. 지금까지 %전을 받았습니다.', lim, earned;
      end if;
      raise exception '상점 판매 수익은 24시간에 %전까지입니다. 지금까지 %전을 받아 남은 한도는 %전입니다.', cap, earned, room;
    end if;
    paid := room;
    dropped := greatest(1, p_qty - floor(room::numeric * p_qty / greatest(net, 1))::int);
  end if;
  inv := case when coalesce((inv ->> p_item_id)::int, 0) - p_qty <= 0 then inv - p_item_id else jsonb_set(inv, array[p_item_id], to_jsonb((inv ->> p_item_id)::int - p_qty), true) end;
  update public.world_characters set inventory = inv, gil = gil + paid, updated_at = now() where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  values (uid, 'shop_sell', paid, false, jsonb_build_object('item', p_item_id, 'qty', p_qty, 'tax', tax, 'dropped', dropped)), (uid, 'sale_tax', -tax, true, jsonb_build_object('item', p_item_id, 'qty', p_qty));
  msg := '판매 완료: ' || item.item_name || ' ×' || p_qty || ' · ' || case when dropped > 0 then '한도에 맞춰 ' || paid || '전만 받았습니다(' || dropped || '개는 값을 받지 못하고 버려짐)' else '세금 빼고 ' || paid || '전' end || ' · 오늘 판매 ' || (earned + paid) || '/' || lim || '전';
  insert into public.world_events(actor_id, actor_name, event_type, content, payload) values (uid, c.character_name, 'shop_sell', msg, jsonb_build_object('item', p_item_id, 'qty', p_qty, 'gil', paid, 'tax', tax, 'dropped', dropped));
  return jsonb_build_object('content', msg, 'gil', c.gil + paid, 'inventory', inv, 'tax', tax, 'paid', paid, 'dropped', dropped, 'sold', earned + paid, 'cap', lim, 'left', greatest(0, lim - earned - paid));
end $function$;
alter function public.world_shop_sell(text, integer, boolean) owner to fn_owner_18878;
revoke all on function public.world_shop_sell(text, integer, boolean) from public, anon;
grant execute on function public.world_shop_sell(text, integer, boolean) to authenticated, service_role;

update public.world_patch_notes set body = body || $n$- 레벨 차이에 따른 경험치 조정: 11/3 다시 연 뒤부터 계속 적용되고 있습니다. 최근 활동한 조사원들보다 크게 앞서 있으면 얻는 경험치가 줄고, 다른 조사원들이 따라오면 저절로 원래대로 돌아갑니다. 레벨이 내려가거나 막히지 않으며, 전리품·전·기술 숙련·칭호에는 걸리지 않습니다. 지금 받는 비율은 상태판 경험치 칸의 「조절」 표시로 볼 수 있습니다.
- 상점 판매 한도를 넘는 물건도 팔 수 있습니다. 한도를 넘는 몫은 값을 받지 못하고 버려진다는 안내를 한 번 보고 고를 수 있습니다.
- 상태이상 창의 치료 단추에 우수품도 함께 뜹니다.
$n$
where note_id = '1.0.0' and position('레벨 차이에 따른 경험치 조정' in body) = 0;

update public.world_app_meta set value = '20261106060000' where key = 'db_version';
