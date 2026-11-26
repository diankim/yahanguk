# 권역 인연 비고 — 옷 밖 물품 시안 (가안, 사용자 확인 전)

서버 id는 gen_rb.py VAULT 그대로. 그림 원본은 이 폴더 두 파일 — 확인 뒤 게임 자산으로 옮긴다.
- vault_furn.js — RB_FUR(바닥)·RB_WALL(벽)·RB_VAULT(권역 → 키). furniture.js 끝의 CABIN 합치기 줄처럼 `for (const [T, S] of [[FUR, RB_FUR], [WALL, RB_WALL]]) Object.assign(T, S)`로 붙이거나 파일을 assets/js/housing/로 옮겨 import. 가구 키 = 물품 id에서 hf_ 뺀 것(hf_rb_pado_1 → rb_pado_1). 색은 파일 안 K 한 벌(cabin_furn.js처럼).
- vault_cosmetics.js — RB_SCENE(바탕 무늬, cosmetics.js SCENE에 그대로)·RB_SEALS·RB_SEAL_TIER(SEALS·SEAL_TIER에)·RB_NAME_STYLES(chat.js NAME_STYLES에)·RB_NAME_CSS(app.css 「세력 비고 이름 색」 아래에 붙일 줄)·RB_NAME_KEYS(권역 → 번호, gen_rb.py VAULT의 ns:rb_<권역>을 ns:<번호>로 바꿀 때).
- 미리보기: supabase/gen_part2/ports/realm_furn.png · realm_cosmetics.png · realm_names.png(왼쪽 야행 어둠·오른쪽 한지 밝음).

## 1. 가구 12 (등급 3 진품, 거래 불가 — 다른 비고 가구와 같게)

| 물품 id | 이름 | 권역 | 놓임·크기 | 분류 | 모양 | 이야기 연결 |
|---|---|---|---|---|---|---|
| hf_rb_pado_1 | 쪽배 좌판 | 파도너울성 | 바닥 2×1, 윗면 .36 | 수납 | 청록 테 두른 작은 쪽배에 바나나잎·은빛 생선·라임 바구니·야자, 뱃머리 장대에 청록 깃 | 쪽배 장터 |
| hf_rb_pado_2 | 노깃 걸이 | 파도너울성 | 벽 1.6칸·28 | 장식 | 놋쇠 못에 노 두 자루를 엇갈려 걸고 청록 노깃 끝에 이름 쓴 흰 자리, 아래 밧줄 고리 | rb_pado_5 「노깃에 쓴 이름」 |
| hf_rb_bulssi_1 | 모루 받침 | 불씨들녘 | 바닥 1×1 | 장식 | 나무 그루터기 위 무쇠 모루, 달군 쇳조각과 망치 | 화덕골 작업장 |
| hf_rb_bulssi_2 | 망치 걸이 | 불씨들녘 | 벽 1.4칸·28 | 장식 | 쇠 막대 걸이 셋 — 망치 둘이 걸리고 가운데 하나는 빈 걸이, 걸이마다 밑에 놋쇠 이름패 | rb_bulssi_5 「망치 걸이」(빈 걸이는 뽑지 않음) |
| hf_rb_jaebit_1 | 기름종이 우산꽂이 | 잿빛그늘숲 | 바닥 1×1 | 장식 | 마디진 대통에 접은 기름종이 우산 둘(주홍·먹청록), 발치에 잎 | 문화색 「기름 먹인 종이우산·대나무 집」 |
| hf_rb_jaebit_2 | 가족패 | 잿빛그늘숲 | 벽 1.2칸·34 | 장식 | 흑단 들보에 끈으로 단 나무 패 넷, 셋은 이름 새김·넷째는 잎 하나만 새긴 새 패 | rb_jaebit_5 「가족패」(넷째 패) |
| hf_rb_nunmaru_1 | 수유차 통 | 눈마루 | 바닥 1×1 | 장식 | 놋쇠 테 두른 긴 나무 통에 젓는 막대, 붉은 털끈 한 줄, 옆에 보릿가루 자루·찻사발 | 수유차·볶은 보릿가루, rb_nunmaru 「털끈 하나」 |
| hf_rb_nunmaru_2 | 오색 깃발 줄 | 눈마루 | 벽 2칸·18 | 장식 | 줄에 파랑·하양·빨강·초록·노랑 깃발 다섯 | 돌마을 어귀 깃발 문 |
| hf_rb_dalmaji_1 | 향신료 단지 상 | 달맞이성 | 바닥 2×1, 윗면 .32 | 좌석·탁자 | 남색 칠 낮은 상에 놋쇠 종지 다섯(고추·강황·카다멈 결 초록·번홍화·계피), 납작빵 더미, 놋쇠 찻잔 | 향신료 시장·커리 한 상 |
| hf_rb_dalmaji_2 | 표시 새긴 문설주 | 달맞이성 | 벽 0.7칸·40 | 장식 | 남색·금 머리를 얹은 문설주 토막에 물고기·바퀴·깃털·열쇠 금빛 표시, 맨 아래 분홍 새 표시 | rb_dalmaji 「문설주의 빈자리」 |
| hf_rb_haeoreum_1 | 연꽃 물그릇 | 해오름성 | 바닥 1×1 | 장식 | 붉은 띠 두른 사암 물그릇에 연잎 둘과 분홍 연꽃 | 탑 사원 연못, 또박의 물그릇 |
| hf_rb_haeoreum_2 | 이름 잎 처마발 | 해오름성 | 벽 1.6칸·30 | 발 | 붉은 처마 들보에 끈마다 마른 잎(금빛 새김) 다섯, 하나는 아직 하얀 새 잎 | rb_haeoreum 「잎 새김방」(손님 이름을 잎에 새겨 처마에 검) |

객실(supabase/gen_400/trade/cabin fit — 바닥 4칸·벽 폭 2/높이 40 이하·막힌 분류 없음): 12개 모두 들어감(분류에 화로·정원·현판 등 막힌 것 없음). 미리보기 아래 4×4 방에 쪽배 좌판·수유차 통·연꽃 물그릇·노깃 걸이·가족패·깃발 줄을 놓아 봄.

서버 물품 행(확인 뒤): category furniture, 등급 3, 묶음 1, 거래 불가, equipment_traits {hk, kind floor|wall, w, d, top / ww, wh, cat} — gen_cabin.py가 FUR/WALL에서 뽑는 방식과 같게 furniture.js 정의에서 뽑는다.

## 2. 바탕 무늬 6 (등급 legend 결, 한 폭 장면 SCENE — 기존 pt-scene 선 스타일만 써서 새 CSS 없음)

| id | 이름 | 모양 |
|---|---|---|
| pt_rb_pado | 장대 다리 무늬 | 물결 위 장대 수상 가옥 셋을 다리로 잇고 앞에 돛 단 쪽배, 둥근 달 |
| pt_rb_bulssi | 불티 무늬 | 연기 피우는 화산 능선과 그 앞 모루·망치, 주황 불티(sc-ember) |
| pt_rb_jaebit | 먹비 숲 무늬 | 양옆 큰 나무 사이로 비스듬한 먹비 줄, 아래 펼친 우산 둘과 새싹 |
| pt_rb_nunmaru | 깃발 등성이 무늬 | 눈 덮인 봉우리 위로 가로지른 깃발 줄, 아래 돌집 둘, 작은 달 |
| pt_rb_dalmaji | 돔 지붕 무늬 | 둥근 보름달 아래 돔 지붕 셋과 계단 우물 층계 |
| pt_rb_haeoreum | 탑 사원 무늬 | 수평선에 반쯤 뜬 해와 햇살, 양옆 탑 사원, 물결과 연꽃 |

장면은 프로필 카드의 가운데 띠에 주로 보이도록 세로를 눌러 그림(`translate(0 42) scale(1 .58)` + 선 굵기 유지 vector-effect). 해·달은 눌리지 않게 따로 얹음.

## 3. 낙관 6 (등급 legend — 세력 낙관과 같음)

| id | 글자 | 뜻 |
|---|---|---|
| sl_rb_pado | 濤 | 큰 물결 — 파도너울 (4.0 sl_hanul 「潮」·sl_bak 「舶」과 다름) |
| sl_rb_bulssi | 鍛 | 쇠를 두드려 벼림 — 화덕골 장인 |
| sl_rb_jaebit | 蔭 | 그늘 — 잿빛그늘숲, 나무가 품어 기름 |
| sl_rb_nunmaru | 雪 | 눈 — 눈마루 |
| sl_rb_dalmaji | 望 | 보름(望月) — 달맞이 |
| sl_rb_haeoreum | 旭 | 돋는 해 — 해오름 |

기존 낙관 글자(SEALS 33자·4.0 潮·舶)와 겹치지 않음을 grep으로 확인.

## 4. 이름 색 6 (빈 번호 1038~1043 — assets·supabase에서 ns:1038~1043 쓰임 없음 확인, 1036·1037은 값귀·백야)

| 서버 키(가안) | 번호 | 이름 | 어둠 / 밝음 | 이름 앞 표식 |
|---|---|---|---|---|
| ns:rb_pado | 1038 | 너울 비취 | #43d1b0 / #0e6f5a | 물방울 |
| ns:rb_bulssi | 1039 | 쇳물빛 | #ffae3a / #a24f00 | 불꽃 |
| ns:rb_jaebit | 1040 | 먹이끼 | #a3c48c / #3c6530 | 잎 |
| ns:rb_nunmaru | 1041 | 서릿마루 | #c2e4f4 / #2a6580 | 산(세모) |
| ns:rb_dalmaji | 1042 | 보름 분홍 | #eab2dc / #933e7c | 초승달 |
| ns:rb_haeoreum | 1043 | 해오름빛 | #ff9468 / #b0421a | 반쪽 해 |

색이 가까운 기존 색(1025 물길 청록·1033 등롱빛·1024 설한 은청·1013 도화)과는 표식 모양으로 갈림(1036·1037처럼 ::before 모양만 바꿈). 붙일 때 gen_rb.py VAULT의 `ns:rb_{k}`를 RB_NAME_KEYS 번호로 바꾸고 chat.js 설명 문구 「○○ 비고에서 받으면」은 「○○ 권역 인연 비고에서 받으면」으로 다듬어도 됨.

## 5. 탈것 6 (world_mount_catalog — 세력 5등급 탈것과 같은 급: 속도 ×2.4·넷이 탐·운임 노정패 2)

기준: 세력 비고 탈것 fm_* 1.1.0d 이후 ×2.4(수향 화방선만 ×2.5)·passenger 4·fare 2, 마구간 월광록 ×2.3. 마구간에서 못 들이게 acquire_method 'event'(등롱 나귀와 같은 길 — 'faction'은 세력 비고 문구가 나와 맞지 않음).

| mount_id | 이름 | 속도 | 탐 | 운임 | unlock_level | unlock_region | 설명(가안) |
|---|---|---|---|---|---|---|---|
| rb_mount_pado | 야자 돛배 | 2.4 | 4 | 2 | 50 | pd_city | 야자 잎을 엮어 돛을 단 파도너울성의 쪽배. 장대 다리 밑을 미끄러져 넷을 태우고 물길을 따라간다. |
| rb_mount_bulssi | 흑요 들소 | 2.4 | 4 | 2 | 50 | bs_town | 화산 유리처럼 검게 번들거리는 뿔의 들소. 재 깔린 비탈도 발굽 한 번 미끄러지지 않는다. |
| rb_mount_jaebit | 흑단 뿔 사슴 | 2.4 | 4 | 2 | 50 | jb_village | 흑단 고목에서 깨어났다는 큰 사슴. 먹비 속에서도 뿔 끝이 은회색으로 빛나 길을 밝힌다. |
| rb_mount_nunmaru | 방울 털소 | 2.4 | 4 | 2 | 50 | nm_village | 목에 방울을 단 눈마루의 털소. 털끈으로 짐을 묶으면 눈보라 속 등성이도 넷을 싣고 넘는다. |
| rb_mount_dalmaji | 공작 수레 | 2.4 | 4 | 2 | 50 | dm_city | 금빛 꼬리깃을 편 공작 한 쌍이 끄는 달맞이성의 남색 수레. 보름 장날이면 수로 다리를 줄지어 건넌다. |
| rb_mount_haeoreum | 해돋이 코끼리 | 2.4 | 4 | 2 | 50 | ho_city | 등에 연꽃 무늬 가마를 얹은 해오름성의 코끼리. 해가 뜰 때 밤 등불을 끄고 다니던 옛 길을 그대로 걷는다. |

행 초안(나머지 칸은 세력 탈것과 같게):
```sql
insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, unlock_faction, unlock_region, unlock_item, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method) values
  ('rb_mount_pado', '야자 돛배', 2.4, 50, 0, null, 'pd_city', null, 0, '…', '권역', 4, 2, false, 'event'), …
on conflict (mount_id) do nothing;
```
tier 칸 값(세력 탈것은 '세력')은 '권역'으로 가안 — 화면에서 tier를 어떻게 쓰는지 붙일 때 확인.

## 확인할 것
- 가구·무늬·낙관·이름 색·탈것 이름 모두 가안. 이름 겹침은 world/ref/existing_names.json·migrations·assets grep으로 검사(겹침 없음 — 바탕 무늬 첫 안 「먹비 우산」은 기존 이름과 겹쳐 「먹비 숲 무늬」로 바꿈).
- 탈것 속도 ×2.4·넷·운임 2는 세력 5등급과 같은 급으로 맞춘 제안값.
