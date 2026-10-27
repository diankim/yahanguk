-- 거래소 등록 제한은 "한 사람이 동시에 올려 둘 수 있는 등록 10건"만 둔다.
-- 앞 마이그레이션(20261027040000)에서 함께 넣은 "기준 시세 30% 미만 금지" 가격 하한은 뺀다.
-- (0전 금지·기준 시세 10배 상한은 world_trade_offer_create에 원래 있던 규칙이라 그대로 둔다.)
create or replace function public.world_trade_listing_guard(p_owner uuid, p_item_id text, p_unit_price bigint) returns void
language plpgsql stable security definer set search_path = '' as $$
declare open_n int;
begin
  select count(*) into open_n from public.world_trade_offers where seller_id = p_owner and status = 'open' and expires_at > now();
  if open_n >= 10 then raise exception '거래소에는 한 사람이 동시에 10건까지 올려 둘 수 있습니다. 팔리거나 취소된 뒤 다시 등록하세요. (지금 %건)', open_n; end if;
end $$;

select 'ok' as result, pg_get_userbyid(proowner) as owner from pg_proc where proname = 'world_trade_listing_guard';
