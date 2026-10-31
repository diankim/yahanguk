-- 7.5.5 — 화면만 바뀐 패치(PC 가방 › 장비 좌우 배치). 패치노트 줄만 덧붙인다
update public.world_patch_notes set body = body || $N$

## 7.5.5
- PC 가방 › 장비를 왼쪽 「장착 중인 장비」 칸과 오른쪽 「고른 부위」(지금 장비·수리·벗기·바꿔 낄 장비)로 나란히 보이게 바꿨습니다. 왼쪽 칸을 누르면 오른쪽이 그 부위로 바뀝니다.
$N$
 where note_id = '7.5.0' and position('## 7.5.5' in body) = 0;
