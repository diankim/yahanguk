-- 7.7.7b — 봉연 토벌 휴대폰 요괴 칸 좁히기(화면만, 패치노트 한 줄)
update public.world_patch_notes set body = body || $N$
## 7.7.7b
- 봉연 토벌 휴대폰 화면: 요괴 칸(남은 시간·체력·낌새)을 빠듯하게 좁혔습니다. 낌새는 한 줄로, 기운을 모을 때만 그 자리에 기운 막대가 뜹니다.
$N$ where note_id = '7.7.0' and position('## 7.7.7b' in body) = 0;
