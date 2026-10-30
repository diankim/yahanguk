-- 7.2.7 덧붙임: 채팅에서 봉연 소식 줄 바로 뒤 운영진의 말이 이어 붙어 얼굴·이름이 빠지던 것(화면 chat.js) — 패치노트만
update public.world_patch_notes set body = body || $n$- 채팅에서 「봉연 소식」 알림 바로 뒤에 운영진이 쓴 글의 얼굴(프로필 사진)과 이름이 빠지던 것을 고쳤습니다.
$n$ where note_id = '7.2.0' and position('「봉연 소식」 알림 바로 뒤' in body) = 0;
