-- 7.7.7g — 휴대폰 전투 기록 최근이 위(파티 토벌·귀허의 주인, 화면만, 패치노트 한 줄)
update public.world_patch_notes set body = body || $N$
## 7.7.7g
- 휴대폰에서 파티 토벌·귀허의 주인 전투 기록도 봉연 토벌처럼 가장 최근 행동이 맨 위에 쌓입니다(귀허의 주인은 최근 라운드가 위, 끝난 뒤 되짚어 보기는 처음부터).
$N$ where note_id = '7.7.0' and position('## 7.7.7g' in body) = 0;
