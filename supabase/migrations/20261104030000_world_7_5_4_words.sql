-- 7.5.4 — 남의 게임에서 온 말 정리(사용자 요청): 돌발 임무·던전·탱커·딜러·폭딜·버프·디버프·기믹을 야행국 말로
--   기믹 → 수법(요괴의 수법, 수법 대처법) · 탱커 → 방패 · 딜러 → 공격 · 폭딜 → 몰아치기 · 버프·디버프 → 북돋기·약화
update public.world_skill_catalog
   set description = replace(replace(replace(replace(replace(replace(description,
       '(탱커)', '(방패)'), '(딜러)', '(공격)'), '(폭딜)', '(몰아치기)'), '(버프·디버프)', '(북돋기·약화)'), '기믹', '수법'), '수법을 버리고', '수법을 거두고')
 where description ~ '(탱커|딜러|폭딜|버프|기믹)';

update public.world_patch_notes
   set body = replace(replace(replace(replace(replace(replace(replace(replace(replace(body,
       '돌발 임무처럼 ', ''), 'A 딜러(', 'A 공격(') , 'B 탱커(', 'B 방패('), 'A 폭딜(', 'A 몰아치기('),
       '버프·디버프', '북돋기·약화'), '같은 버프,', '같은 북돋기,'), '디버프가 생기던', '나쁜 상태가 생기던'), '기믹 파훼법', '수법 대처법'), '기믹', '수법')
 where body ~ '(돌발 임무|딜러|탱커|폭딜|버프|기믹)';

do $v$
begin
  if exists (select 1 from public.world_skill_catalog where description ~ '(탱커|딜러|폭딜|버프|기믹)')
     or exists (select 1 from public.world_patch_notes where body ~ '(돌발 임무|딜러|탱커|폭딜|버프|기믹)') then
    raise exception '7.5.4: 바꾸지 못한 말이 남았다';
  end if;
end $v$;

-- 제보 51(강산하): 같은 물품 기운을 다시 쓰면 지금부터 다시 세던 것을, 남은 시간에 더하고 두 번 몫까지 쌓이게
do $p$
declare d text; a text; n int;
begin
  d := replace(pg_get_functiondef('public.world_use_item(text)'::regprocedure), E'\r\n', E'\n');
  a := $o$UPDATE public.world_character_statuses SET expires_at = now() + make_interval(mins => ceil((SELECT duration_minutes FROM public.world_status_catalog WHERE status_key = buff) * v_dur * (CASE WHEN buff IN ('well_fed', 'warm_belly', 'vigor', 'sea_luck') THEN v_meal ELSE 1 END))::int)
       WHERE owner_id = uid AND status_key = buff AND expires_at > now();$o$;
  if position('now() + make_interval(mins => ceil((SELECT duration_minutes FROM public.world_status_catalog WHERE status_key = buff) * v_dur * (CASE WHEN buff IN ('well_fed', 'warm_belly', 'vigor', 'sea_luck') THEN v_meal ELSE 1 END))::int) * 2' in d) > 0 then return; end if;
  n := (length(d) - length(replace(d, a, ''))) / length(a);
  if n <> 1 then raise exception '7.5.4 use_item anchor %', n; end if;
  execute replace(d, a, $n$UPDATE public.world_character_statuses SET expires_at = least(expires_at + make_interval(mins => ceil((SELECT duration_minutes FROM public.world_status_catalog WHERE status_key = buff) * v_dur * (CASE WHEN buff IN ('well_fed', 'warm_belly', 'vigor', 'sea_luck') THEN v_meal ELSE 1 END))::int), now() + make_interval(mins => ceil((SELECT duration_minutes FROM public.world_status_catalog WHERE status_key = buff) * v_dur * (CASE WHEN buff IN ('well_fed', 'warm_belly', 'vigor', 'sea_luck') THEN v_meal ELSE 1 END))::int) * 2)
       WHERE owner_id = uid AND status_key = buff AND expires_at > now();$n$);
end $p$;

-- 패치노트: 7.5.0 본문 맨 아래에 덧붙임
update public.world_patch_notes set body = body || $N$

## 7.5.4
- 등잔빛·비약·음식 기운처럼 시간이 정해진 물품 효과는 다시 쓰면 **남은 시간에 더해집니다**(두 번 몫까지 — 어유 등잔이면 최대 80분). 물품 정보 창에도 적었습니다(강산하 님 제보). 전에는 다시 써도 지금부터 다시 세어 늘지 않았습니다.
- 방어구의 「어울리는 직업」 안내가 짝 능력치를 보지 않아 법의(의지)에 퇴마관이 빠져 있던 것을 고쳤습니다. 방어구는 적힌 능력치와 짝 능력치(체질↔힘·민첩↔감각·의지↔영기) 가운데 높은 것으로 입습니다(강산하 님 제보). 입는 조건은 전과 같습니다.
- 모바일 가방 › 장비를 퀵슬롯처럼 작은 칸으로 바꿨습니다. 칸을 누르면 그 부위 창에서 지금 낀 장비의 수리·벗기와 바꿔 낄 장비를 한 번에 봅니다(여보 님 제보). PC 화면은 그대로입니다.
- 채팅과 귓속말을 **새 창으로** 따로 띄울 수 있습니다(PC 브라우저). 채팅 머리의 「새 창」 단추, 귓속말 창 위의 「새 창」 단추를 누르세요. 새 창의 링크(#패치노트 등)는 본 창에서 열립니다(디디 님 제보).
- 모바일 칭호 화면을 두 칸 작은 카드(이름·등급·상태·진행)로 줄였습니다. 카드를 누르면 그 칭호만 펼쳐 설명·조건·효과·장착 단추를 보입니다.
- 칭호 묶음 칸도 모바일에서 두 칸으로 줄였습니다.
- 「야행국은 어떤 곳인가」(캐릭터 만들기·도움말)에 이 땅의 「이름(名)」 이야기를 짧게 더했습니다 — 명줄, 영(靈), 요화와 갈래.
- 칭호·꾸미기 알림의 「보러 가기」를 누르면 얻은 그 칭호(꾸미기) 칸으로 바로 데려갑니다.
- 도움말·직업 소개·기술 설명에 남아 있던 다른 게임 말을 야행국 말로 바꿨습니다: 기믹 → 요괴의 **수법**(대처법), 탱커·딜러 → **방패·공격**, 버프·디버프 → **북돋기·약화**.
$N$
 where note_id = '7.5.0' and position('## 7.5.4' in body) = 0;

update public.world_app_meta set value = '20261104030000' where key = 'db_version';
