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
- 도움말·직업 소개·기술 설명에 남아 있던 다른 게임 말을 야행국 말로 바꿨습니다: 기믹 → 요괴의 **수법**(대처법), 탱커·딜러 → **방패·공격**, 버프·디버프 → **북돋기·약화**.
$N$
 where note_id = '7.5.0' and position('## 7.5.4' in body) = 0;

update public.world_app_meta set value = '20261104030000' where key = 'db_version';
