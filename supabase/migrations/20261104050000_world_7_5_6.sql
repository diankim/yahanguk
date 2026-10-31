-- 7.5.6 — 화면만 바뀐 묶음의 패치노트(7.5.0 본문 맨 아래에 덧붙임)
update public.world_patch_notes set body = body || $N$

## 7.5.6
- 거래소 사기 목록·내 등록에 물품 **등급**(범품·양품·진품·명품·신품)을 색 글자로 붙이고, 줄 왼쪽 띠도 등급 색으로 칠했습니다. 올릴 물품을 고르는 칸에도 등급을 적었습니다.
$N$
 where note_id = '7.5.0' and position('## 7.5.6' in body) = 0;

update public.world_app_meta set value = '20261104050000' where key = 'db_version';
