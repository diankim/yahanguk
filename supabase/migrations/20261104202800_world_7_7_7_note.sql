-- 7.7.7 — 봉연 토벌 휴대폰 화면 다듬기(화면만, 패치노트 한 줄)
update public.world_patch_notes set body = body || $N$
## 7.7.7
- 봉연 토벌 휴대폰 화면: 협동 기술 넷을 늘 펼쳐 한 줄로 놓았고(「기술」 단추를 누를 필요 없음), 위쪽 요괴 낌새 칸을 두 줄로 좁혔습니다.
$N$ where note_id = '7.7.0' and position('## 7.7.7' in body) = 0;
