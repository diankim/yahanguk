-- 7.7.1b (2026-11-01, 사용자 요청): 휴대폰 제작 카드에서 [초기화] − n + [전부]와 「제작」이 한 줄에 나란히(화면만, 패치노트 한 줄)
update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.7.1b
- 휴대폰 제작 카드에서 횟수 칸([초기화] − 횟수 + [전부])과 「제작」 단추가 두 줄로 나뉘던 것을 한 줄에 나란히 두었습니다.
$N$
 where note_id = '7.7.0' and position('## 7.7.1b' in body) = 0;
