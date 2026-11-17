update public.world_item_catalog set market_only = false where market_only;

update public.world_patch_notes set body = body || $N$

## 3.0.1
- 일지 › 주 이야기의 「요인록」·「묵적록」·「명등기」 칸 위쪽에도 마친 장 수와 장 단추 줄이 생겼습니다. 장을 누르면 그 장이 아래에 펼쳐지고, 장이 아닌 이야기는 「이어지는 이야기」에 모였습니다. 이야기를 다 마치면 「○○의 이야기를 모두 마쳤습니다」가 뜹니다.
- 「요인록」·「묵적록」·「명등기」를 「외전」이 아니라 「홍인사」와 이어지는 본편으로 적습니다(도움말·싸움 화면·입장 안내).
- 도움말 「사건과 일지」를 본편 네 이야기가 같은 틀(소개 → 장 표 → 열림·우두머리·장 보상)로 보이게 고쳤고, 「홍인사」 소개를 넣었습니다.
- 도움말 귀령초 확률표가 「NaN%」로 나오던 것을 고쳤습니다.
- 도움말에서 빈약한 안전지대 이름 뒤 조사가 어색하던 줄을 고쳤고, 얻을 길이 없는 「세심단」 설명을 뺐습니다. 거래할 수 없는 물품이 무엇인지도 실제대로 적었습니다.
- 「빛나는 알」·「얼룩무늬 알」 물품 정보의 얻는 곳에 탐색·채집·낚시에서 드물게 나오는 것과 동무 정표로 바꾸는 것이 함께 적힙니다.
- 거래소 전용이던 희귀 재료 아홉(비취 파편·귀경 파편·뇌철 광석·성진사·요핵·잔화 결정·천공 깃털·각인판·강화 요수 가죽)을 풀었습니다. 직접 거래·정인 선물·서신으로도 보낼 수 있고, 거래소에서는 다른 물품과 같은 규칙(등록가·등록 수·거래세)을 따릅니다.$N$
 where note_id = '3.0.0' and position('## 3.0.1' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119040000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
