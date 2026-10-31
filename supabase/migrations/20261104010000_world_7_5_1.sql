-- 7.5.1 — 7.5.0 뒤 제보 묶음
-- 제보 45(조의신): 요리 택일 기술 「든든한 한 끼」 설명에 안쪽 함수 이름이 보이던 것
update public.world_skill_catalog
   set description = replace(description, '(world_use_item의 meal 상태 지속 시간에 곱함)', '')
 where skill_id = 'cooking_c43b';

update public.world_app_meta set value = '20261104010000' where key = 'db_version';
