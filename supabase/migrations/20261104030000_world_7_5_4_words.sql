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

update public.world_app_meta set value = '20261104030000' where key = 'db_version';
