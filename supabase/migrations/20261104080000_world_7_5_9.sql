-- 7.5.9 — 화면 묶음의 패치노트(7.5.0 본문 맨 아래에 덧붙임). 10개가 모이면 배포한다(2026-10-31 결정).
update public.world_patch_notes set body = body || $N$

## 7.5.9
- 가방에서 같은 물품을 **묶음 크기만큼 한 칸씩 나눠** 보입니다. 청심환 45개라면 20·20·5 세 줄로 보여, 몇 칸을 차지하는지 따로 셈하지 않아도 됩니다(강산하 님 제보). 장착 중인 하나는 칸을 쓰지 않으므로 따로 한 줄로 보입니다. 정렬 옆 「칸대로 나눠 보기」를 끄면 예전처럼 한 줄에 모아 보입니다.
$N$
 where note_id = '7.5.0' and position('## 7.5.9' in body) = 0;

update public.world_app_meta set value = '20261104080000' where key = 'db_version';
