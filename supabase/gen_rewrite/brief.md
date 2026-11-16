# 홍인사·귀허도 대본 다듬기 지시(11/16 사용자 요청)

사용자: 「본편이랑 귀허도 대본도 지금 내가 컨펌한 내용 바탕으로 수정좀 하자.」 — 명등기 5판을 쓰며 사용자가 정한 대본 규칙을 이미 들어간 두 이야기에도 적용한다. 한국어.

## 기준(모두 읽는다)
- /home/user/yahanguk/supabase/gen_300/brief_v5.md 「사용자의 말」 전부, /home/user/yahanguk/supabase/gen_300/outline_v5.md 0절 1~14번(유대 장면·병풍 금지·위급 장면 감정·서술이 설명하지 않음·문장 길이·서술 첫머리 접속사 금지·할 일 앞 까닭·대화 주고받기·비현실적인 일 충분히 그리기·목적 상기·우리식 호칭·주인공 성별 안 드러냄·조사 빠짐 금지).
- /home/user/yahanguk/CLAUDE.md §10 「대본 규칙」(검토 기준 다섯, 주인공은 말하는 이가 아니고 「나는 ~라고 했다」, {이름}·{직업:…}·조사 「이(가)」, 'me' 금지, LORE_NAME 설정).
- /home/user/yahanguk/supabase/gen744/LORE_NAME.md, /home/user/yahanguk/supabase/gen_side110/canon.md(인물 내력), 명등기 설정 /home/user/yahanguk/supabase/gen_300/canon.md와 어긋나지 않게(명등기가 이 장면들을 기억으로 쓰므로 사건·인물·물건·대사의 사실은 바꾸지 않는다 — 특히 명등기 script5_all.md가 인용한 대사 「붉은 인장은 제자리에 있을 때 빛난다」「올해 먹 거두기는 하지 않는다」 등은 그대로).

## 원본은 운영 DB(읽기만)
Supabase 운영 프로젝트 wphhqfkxrqjxxmfyozff에서 execute_sql로 **SELECT만** 한다(쓰기·DDL 절대 금지). 표: world_quests(quest_id·title·min_level·region_id·epilogue·cat·kind), world_quest_steps(quest_id·step·need·lines jsonb 배열 {s 말하는이 키 또는 null, t 글, job/affil 같은 갈래 키}·reward), world_quest_npcs(말하는이 키 → 이름). 지금 들어가 있는 줄이 원본이다(옛 생성기 파일보다 앞섬).

## 지킬 틀(진행 중인 사람이 있으므로)
- 장면(step) 수·순서·할 일(need)·보상(reward)·quest_id는 바꾸지 않는다. 바꾸는 것은 lines(대사·서술)와 epilogue뿐.
- 줄의 갈래 키(job·affil 등)와 말하는이 키는 살린다(새 말하는이를 만들지 않는다 — 이미 있는 키만). 줄은 더하거나 빼거나 고쳐도 된다. 장면당 줄 수는 늘려도 좋다(유대·반응·까닭).
- 할 일은 그대로이므로, 「할 일 앞 까닭」은 그 장면 끝 대사로 다음 장면 할 일(need를 보고 확인)을 왜 하는지 인물이 말하게 한다.
- 이 단계는 **검토용 문서만** 만든다. 마이그레이션·DB 쓰기는 하지 않는다. git 커밋도 하지 않는다.

## 결과 형식
- 원본 덤프: 네 몫의 원본 lines·epilogue·need를 그대로 JSON으로 /home/user/yahanguk/supabase/gen_rewrite/<몫>_orig.json에 저장(나중에 마이그레이션의 기준).
- 고친 대본: /home/user/yahanguk/supabase/gen_rewrite/<몫>.md — `# n장 「제목」 · Lv` / `### 장면 k (받기·보고: 곳)` / 할 일 요약 한 줄(need를 읽기 쉽게) / 줄은 `- 서술: …`, `- 이름표(키): …`, 갈래 줄은 `- [job=scout] 이름표(키): …` 꼴 / 장 끝 `- 결말:` 줄들. 장마다 머리에 「고친 까닭」 한두 줄.
- 다 쓴 뒤 줄마다 위 기준으로 다시 보고, grep(서술 첫머리 접속사·「라는 것이었다」·「형님/누님」으로 주인공 부르기·명사 끝 서술)을 0으로. 끝나면 짧게 보고: 장면 수, 크게 바꾼 장면, 원본 사실을 바꿀 뻔했지만 둔 곳, 사용자에게 물을 것.
