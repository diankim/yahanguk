update public.world_item_catalog set market_only = false where market_only;

update public.world_patch_notes set body = body || $N$
- 거래소 전용이던 희귀 재료 아홉(비취 파편·귀경 파편·뇌철 광석·성진사·요핵·잔화 결정·천공 깃털·각인판·강화 요수 가죽)을 풀었습니다. 직접 거래·정인 선물·서신으로도 보낼 수 있고, 거래소에서는 다른 물품과 같은 규칙(등록가·등록 수·거래세)을 따릅니다.$N$
 where note_id = '3.0.0' and position('거래소 전용이던 희귀 재료 아홉' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119040000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
