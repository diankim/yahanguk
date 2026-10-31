-- 7.5.7 — 화면만 바뀐 묶음의 패치노트(7.5.0 본문 맨 아래에 덧붙임)
update public.world_patch_notes set body = body || $N$

## 7.5.7
- 안전지대(반요촌 빼고)에 있을 때 가방의 물품 정보 창에서 바로 **창고에 넣기**를 할 수 있습니다. 수량을 정하거나 「최대」로 한꺼번에 맡깁니다(강산하 님 제보). 장착 중인 마지막 하나는 남깁니다.
$N$
 where note_id = '7.5.0' and position('## 7.5.7' in body) = 0;

update public.world_app_meta set value = '20261104060000' where key = 'db_version';
