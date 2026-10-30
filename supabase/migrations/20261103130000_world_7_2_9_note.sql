-- 7.2.9 패치노트(7.2.0 본문 끝에 덧붙임, 공지 없이). 장야·롤백 연출은 적지 않는다.
update public.world_patch_notes set body = body || $n$
## 7.2.9
- 알림의 「지도에서 보기」(친구 쓰러짐)가 눌리지 않던 것을 고쳤습니다. 같은 까닭으로 눌리지 않던 토벌·결전 「합류」·「보기」, 파티 토벌, 「비무 방」, 「혼례 보기」, 「서신함」, 「별채 보기」 단추도 함께 고쳤습니다.
$n$ where note_id = '7.2.0' and position('## 7.2.9' in body) = 0;
update public.world_app_meta set value = '20261103130000' where key = 'db_version';
