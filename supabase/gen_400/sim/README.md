# 4.0 시뮬 — 돌리는 법 (복제 DB 전용, 운영에서 돌리지 않음)

## 기준 DB
`yh_sim40` = 운영 복제 `yh`(3.8.1m) + wt381n 마이그레이션 20261127170000·180000·190000 + `world/gen.py` 출력 전체 + `speed_patch.sql` + `neol_sim.sql`(서버 보스 함수의 now()를 yh_now()로 — 가짜 시계) + `yh_sim_chars` 20줄.
다시 만들 때:
```
createdb -T yh yh_sim40
psql -d yh_sim40 -1 -v ON_ERROR_STOP=1 -f <wt381n>/supabase/migrations/20261127170000_*.sql   (180000·190000도)
python3 supabase/gen_400/world/gen.py > /tmp/40.sql && psql -d yh_sim40 -1 -v ON_ERROR_STOP=1 -f /tmp/40.sql
psql -d yh_sim40 -f speed_patch.sql && psql -d yh_sim40 -f neol_sim.sql
psql -d yh_sim40 -c "insert into yh_sim_chars select row_number() over (order by (level>=50) desc, owner_id), owner_id, 'scout' from world_characters order by (level>=50) desc, owner_id limit 20"
```
`speed_patch.sql`은 world_du_qr·world_du_cell·world_ug_nbm을 같은 값을 내는 상수판으로 바꾼다(바꾸기 전과 값이 같은지 스스로 검사). 땅울이 판에서 한 라운드 0.5초 → 0.15초.

## 돌리기
```
./run_all.sh check 4   # 봇 점검(짧은 판 ~30판, 약 5분)
./run_all.sh hard 4    # 도해수·땅울이 깊은 판
./run_all.sh ug 4      # 무용담 넷
./run_all.sh raid 4    # 엉긴 너울·사슬 벗은 그림자
./run_all.sh all 4
python3 sim_report.py out/hard.jsonl out/ug.jsonl ...   # 표로 모으기
```
일꾼 DB `yh_simrun_<n>`은 기준 DB에서 한 번 복사해 계속 쓴다(판마다 커밋 — 한 트랜잭션에 수백 라운드를 쌓으면 느려져서). 결과는 `out/<단계>.jsonl` 한 줄에 한 판.

## 표 읽기
- **봇 놓침**: 정석(perfect)·best 정책이면 0이어야 한다. 귀허류는 bad 기록에서 결과 줄(쓰러짐·약화·번진 실수·컷)·엔진 탓으로 분류한 것(머리 칸이 수법 중간에 옮겨 감 `head_phase`, 끌개 칸이 그 라운드에 구멍/산사태/판 깎기 `pull_forced`)을 뺀 수. 서버 보스는 되고임·기운 터짐·고임 심 실패·굳음·되밀린 물에 휩쓸림·혼자 받은 무게의 합.
- **약화**: 무용담의 개인 약화(놓친 사람마다 한 겹). 도해수 무용담은 수법 피해를 입으면 모두 놓침이라 이 칸으로 본다.
- **돌주먹**: 무용담 · 도해수 2막 돌주먹에 맞은 수(방어해도 놓침으로 셈 — 엔진 쪽 문제, 고치기 전엔 0이 될 수 없음).

## 정책
- 귀허류(gw_sim.sql): perfect(정석·완벽) · real(정석 + 사람마다 12% 아무 칸·공격) · ignore(수법 무시, 제자리 공격). 무용담 perfect는 서버 풀이기(world_ug_solve)에 그 판 조건과 봇이 더한 조건(소용돌이·사슬 기운·이름·기억·이름 지우기·산사태·소용돌이 기둥·구멍)을 넣어 칸·행동을 정한다.
- 서버 보스(neol_sim.sql): best · half(절반만 따름) · none. `best+late`는 다섯 명이 300초 뒤 합류.
