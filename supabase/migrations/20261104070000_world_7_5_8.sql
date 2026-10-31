-- 7.5.8 — 화면 묶음의 패치노트(7.5.0 본문 맨 아래에 덧붙임). 10개가 모이면 배포한다(2026-10-31 결정).
update public.world_patch_notes set body = body || $N$

## 7.5.8
- 서버 점검(롤백) 동안 대기 화면에 **도움말 보기** 단추를 두었습니다. 게임에는 들어갈 수 없지만, 기다리는 동안 도움말의 규칙·수치·세계관 글을 모두 읽고 찾아볼 수 있습니다. 점검 중에 계속 떠 있는 「첫째 밤의 끝」 화면에서는 오른쪽 위 **도움말** 단추로 엽니다.
$N$
 where note_id = '7.5.0' and position('## 7.5.8' in body) = 0;

update public.world_app_meta set value = '20261104070000' where key = 'db_version';
