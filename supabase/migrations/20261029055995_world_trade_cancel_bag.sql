-- 긴급 수정(4.0.6, 2026-10-29 제보): 가방이 가득 찬 채 거래소 등록을 취소하면 world_trade_offer_cancel이 자리를 보지 않고 가방에 넣고,
-- 가방 넘침 정리(world_enforce_bag_capacity)가 「얻기만 하는 행동」처럼 넘친 만큼 버려 물품이 사라졌다.
-- 돌려받을 자리가 모자라면 취소를 거절한다(물품은 거래소에 그대로 남는다). 사라진 물품은 개인 창고로 돌려준다.
grant fn_owner_18903 to postgres with inherit true, set true;
grant fn_owner_expedition to postgres with inherit true, set true;
-- world_bag_limit은 fn_owner_expedition 소유(security definer)라 그 역할로 실행 권한을 준다.
set role fn_owner_expedition;
grant execute on function public.world_bag_limit(uuid) to fn_owner_18903;
reset role;
-- world_bag_room(부른 쪽 권한)이 묶음 크기를 읽으므로 다른 함수 주인 역할처럼 물품 목록 읽기만 준다.
grant select on public.world_item_catalog to fn_owner_18903;

do $$
declare d text := pg_get_functiondef('public.world_trade_offer_cancel(uuid)'::regprocedure);
  a text := $a$inv:=coalesce(c.inventory,'{}'::jsonb); inv:=jsonb_set(inv,array[o.item_id]$a$;
  b text := $a$inv:=coalesce(c.inventory,'{}'::jsonb);
 if public.world_bag_room(inv, o.item_id, public.world_bag_limit(uid)) < o.quantity then
   raise exception '가방 자리가 모자라 돌려받을 수 없습니다. 빈 자리를 만든 뒤 다시 취소하세요(물품은 거래소에 그대로 있습니다).';
 end if;
 inv:=jsonb_set(inv,array[o.item_id]$a$;
begin
  if position('world_bag_room' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '거래소 등록 취소 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- 이 문제로 사라진 물품 돌려주기(거래소 등록 취소와 같은 순간에 「가방이 가득 찼습니다」로 버려진 것: 연주 옥 부적낭 ×2·팔괘 나경 ×1). 한 번만.
do $$
declare r record; got jsonb; names text;
begin
  for r in
    select x.actor_id uid, jsonb_object_agg(x.item, x.qty) items
      from (select e.actor_id, e.payload ->> 'item' item, sum((n.payload -> 'dropped' ->> (e.payload ->> 'item'))::int) qty
              from public.world_events e
              join public.world_notifications n on n.user_id = e.actor_id and n.kind = 'bag_full'
               and abs(extract(epoch from n.created_at - e.created_at)) < 1 and n.payload -> 'dropped' ? (e.payload ->> 'item')
             where e.event_type = 'trade' and e.content like '거래 등록 취소%' and e.created_at < '2026-10-29 03:00+00'
             group by 1, 2) x
     group by 1
  loop
    if exists (select 1 from public.world_notifications where user_id = r.uid and payload ->> 'refund' = 'trade_cancel_drop') then continue; end if;
    insert into public.world_storage(owner_id, items, updated_at) values (r.uid, r.items, now())
    on conflict (owner_id) do update set items = (select coalesce(jsonb_object_agg(k, v), '{}'::jsonb) from (
        select k, sum(v::numeric)::int v from (select key k, value v from jsonb_each(coalesce(public.world_storage.items, '{}'::jsonb))
                                              union all select key, value from jsonb_each(excluded.items)) u group by k) s),
      updated_at = now();
    select string_agg(coalesce(i.item_name, k) || ' ×' || v, ', ') into names from jsonb_each_text(r.items) t(k, v) left join public.world_item_catalog i on i.item_id = t.k;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.uid, 'reward', '사라진 물품을 돌려드렸습니다',
      '가방이 가득 찬 채 거래소 등록을 취소해 사라졌던 ' || names || '을(를) 개인 창고에 넣어 드렸습니다. 안전지대에서 꺼낼 수 있습니다. 제보 고맙습니다.',
      jsonb_build_object('refund', 'trade_cancel_drop', 'items', r.items));
  end loop;
end $$;

update public.world_patch_notes set body = body || E'\n\n### 4.0.6\n- 가방이 가득 찬 채 거래소 등록을 취소하면 물품이 사라지던 문제를 고쳤습니다. 이제 돌려받을 자리가 모자라면 취소되지 않고 물품은 거래소에 그대로 남습니다. 이 문제로 사라진 물품은 개인 창고로 돌려드렸습니다.'
 where note_id = '4.0.0' and position('### 4.0.6' in body) = 0;

grant fn_owner_18903 to postgres with inherit false, set false;
grant fn_owner_expedition to postgres with inherit false, set false;
