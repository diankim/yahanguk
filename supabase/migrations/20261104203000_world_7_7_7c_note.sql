-- 7.7.7c — 토벌 협동 기술·북돋기 아이콘(화면만, 패치노트 한 줄)
update public.world_patch_notes set body = body || $N$
## 7.7.7c
- 봉연 토벌: 협동 기술 단추마다 아이콘을 붙였고, 약점·피할 길·결계·기세 같은 북돋기와 사슬이 걸린 조사원은 참가자 칸 이름 바로 옆에 그 아이콘이 뜹니다.
$N$ where note_id = '7.7.0' and position('## 7.7.7c' in body) = 0;
