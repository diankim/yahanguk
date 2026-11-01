-- 7.6.3b — 화면만: 소모품 제작법 효과도 설명 안 「(효과: …)」로. DB는 패치노트만(db_version 그대로).
update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.6.3b
- 가방 › 제작: 소모품 제작법도 장비처럼 설명 안에 「(효과: …)」로 효과를 적습니다(예: 「등롱 어유를 황지 심지에 먹여 등잔 둘을 만듭니다. (효과: 등잔빛 40분 …)」). 따로 떨어져 있던 효과 줄은 뺐습니다.
$N$
 where note_id = '7.5.0' and position('## 7.6.3b' in body) = 0;
