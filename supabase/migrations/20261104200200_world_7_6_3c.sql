-- 7.6.3c — 화면만: 휴대폰 채팅 시트가 키패드와 함께 뒤 화면을 밀어 올리던 것. DB는 패치노트만(db_version 그대로).
update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.6.3c
- 휴대폰 채팅: 입력칸을 누르면 키패드와 함께 뒤쪽 게임 화면까지 밀려 올라가던 것을 고쳤습니다. 채팅을 연 동안에는 뒤 화면이 그 자리에 고정되고, 채팅 창만 키패드 바로 위로 올라갑니다. 닫으면 보던 자리 그대로 돌아옵니다.
$N$
 where note_id = '7.5.0' and position('## 7.6.3c' in body) = 0;
