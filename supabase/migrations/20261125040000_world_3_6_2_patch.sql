update public.world_patch_notes set body = body || $n$

## 3.6.2
- 물품 묶음 크기를 하나로 맞췄습니다. 장비·가구·옷·동무 바구니·비장도는 1개, 화살·편전은 100개, 그 밖의 재료·소모품·임무 물품은 모두 한 칸에 50개까지 들어갑니다(가방·창고 모두).
- 제작 창의 제작법마다 완성품을 지금 몇 개 가졌는지(가방·창고) 보입니다. 가구·옷은 보유 여부가 보입니다.
- 퀘스트 칸의 「다른 곳에서 받을 수 있는 퀘스트」를 한 번에 접을 수 있습니다.
- 연담 주문에 명어나 명소 재료가 드는 물품은 더 나오지 않습니다.
- 세력 기부로 하루에 받는 공훈이 30에서 60으로 늘었습니다.
- 3.0 전에 나온 보조 퀘스트 262편의 서술과 대사를 다듬었습니다. 할 일과 줄거리는 그대로입니다.
- 수향연맹 잠수꾼이 나오는 보조 퀘스트 세 편(용잠 수궁·연맹 뱃길 두 편)의 잠수꾼은 청파가 아니라 그의 삼촌 청석입니다.
- 천년 빙하의 빙하지기 이름이 한서리로 바뀌었습니다.
$n$
 where note_id = '3.5.0' and body not like '%## 3.6.2%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261125040000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
