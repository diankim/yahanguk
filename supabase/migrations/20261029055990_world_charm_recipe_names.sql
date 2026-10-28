-- 긴급 수정(4.0.3, 운영 DB에 바로 반영함): 청동 호신패를 다른 재료로 만드는 제작법 두 개의 이름이
-- 「요핵 호신패 제작」·「주사 비취 호신패 제작」이라 다른 물건을 만드는 것처럼 보였다(제보). 실제 완성품에 맞게 이름을 바로잡는다.
update public.world_crafting_recipes set recipe_name = '청동 호신패 (요핵으로)' where recipe_id = 'recipe_monster_ward';
update public.world_crafting_recipes set recipe_name = '청동 호신패 (주사·비취로)' where recipe_id = 'make_bronze_charm_advanced';
