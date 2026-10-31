-- 7.6.3d — 화면만: 휴대폰 채팅 시트가 키패드가 내려갈 때 작게 잘린 채 남던 것. DB는 패치노트만(db_version 그대로).
update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.6.3d
- 휴대폰 채팅: 글을 보내고 키패드를 내리면 채팅 창이 작아진 채로 내려오던 것을 고쳤습니다. 키패드가 내려가면 본래 크기로 돌아옵니다.
$N$
 where note_id = '7.5.0' and position('## 7.6.3d' in body) = 0;
