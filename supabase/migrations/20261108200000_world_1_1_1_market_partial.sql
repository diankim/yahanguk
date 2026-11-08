create or replace function public.world_trade_offer_buy(p_offer_id uuid, p_qty integer)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid:=public.fn_owner_auth_uid(); b public.world_characters%rowtype; s public.world_trade_offers%rowtype; seller public.world_characters%rowtype; inv jsonb; q int; total bigint; tax bigint; net bigint; msg text; item public.world_item_catalog%rowtype;
begin perform public.world_travel_guard('거래소 구매');
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select * into b from public.world_characters where owner_id=uid for update;
 if not found then raise exception '캐릭터를 먼저 등록하세요.'; end if;
 select * into s from public.world_trade_offers where offer_id=p_offer_id for update;
 if not found or s.status<>'open' or s.expires_at<=now() or s.seller_id=uid then raise exception '거래 등록이 만료되었거나 구매할 수 없습니다.'; end if;
 q:=coalesce(p_qty, s.quantity);
 if q<1 or q>s.quantity then raise exception '살 수 있는 개수는 1~%개입니다.', s.quantity; end if;
 select * into item from public.world_item_catalog where item_id=s.item_id;
 if item.item_id is null or not item.tradeable then raise exception '귀속 처리된 물품은 거래할 수 없습니다.'; end if;
 if item.reference_price is not null and s.unit_price>item.reference_price*10 then raise exception '기준 시세를 크게 초과한 거래입니다.'; end if;
 total:=q*s.unit_price; tax:=case when public.world_trade_tax_mult(s.seller_id)<=0 then 0 else greatest(1,round(total*(case when public.world_market_only(s.item_id) then 0.10 else 0.05 end)*public.world_trade_tax_mult(s.seller_id))::bigint) end; net:=total-tax;
 if b.gil<total then raise exception '재화가 부족합니다.'; end if;
 select * into seller from public.world_characters where owner_id=s.seller_id for update;
 if not found then raise exception '판매자 캐릭터를 찾을 수 없습니다. 거래를 진행할 수 없습니다.'; end if;
 inv:=coalesce(b.inventory,'{}'::jsonb); inv:=jsonb_set(inv,array[s.item_id],to_jsonb(coalesce((inv->>s.item_id)::int,0)+q),true);
 update public.world_characters set inventory=inv,gil=gil-total,updated_at=now() where owner_id=uid;
 update public.world_characters set gil=gil+net,updated_at=now() where owner_id=s.seller_id;
 update public.world_trade_offers set status='completed',buyer_id=uid,quantity=q where offer_id=s.offer_id and status='open';
 if not found then raise exception '거래 상태가 변경되었습니다. 다시 확인해 주세요.'; end if;
 if q<s.quantity then
   insert into public.world_trade_offers(seller_id,item_id,quantity,unit_price,status,created_at,expires_at)
   values(s.seller_id,s.item_id,s.quantity-q,s.unit_price,'open',s.created_at,s.expires_at);
 end if;
 insert into public.world_economy_ledger(owner_id,action,currency_delta,sink,details) values(uid,'trade_buy',-total,true,jsonb_build_object('offer_id',s.offer_id,'item',s.item_id,'qty',q)),(s.seller_id,'trade_sale',net,false,jsonb_build_object('offer_id',s.offer_id,'item',s.item_id,'qty',q)),(uid,'trade_tax',-tax,true,jsonb_build_object('offer_id',s.offer_id));
 msg:='거래 완료: '||item.item_name||' ×'||q||' · 거래세 '||tax||'전';
 insert into public.world_events(actor_id,actor_name,event_type,content,payload) values(uid,b.character_name,'trade',msg,jsonb_build_object('offer_id',s.offer_id,'item',s.item_id,'qty',q,'gil',total));
 return jsonb_build_object('content',msg,'inventory',inv,'gil',b.gil-total,'tax',tax,'left',s.quantity-q);
end $function$;

do $o$ declare own text := pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_trade_offer_buy(uuid)'::regprocedure));
begin
  execute format('grant create on schema public to %I', own);
  execute format('alter function public.world_trade_offer_buy(uuid, integer) owner to %I', own);
  execute format('revoke create on schema public from %I', own);
end $o$;
do $g$ begin execute format('grant insert on public.world_trade_offers to %I', pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_trade_offer_buy(uuid)'::regprocedure))); end $g$;
revoke all on function public.world_trade_offer_buy(uuid, integer) from public, anon;
grant execute on function public.world_trade_offer_buy(uuid, integer) to authenticated, service_role;

create or replace function public.world_trade_offer_buy(p_offer_id uuid)
 returns jsonb
 language sql
 security invoker
 set search_path to 'pg_catalog', 'public'
as $function$ select public.world_trade_offer_buy(p_offer_id, null::integer) $function$;
