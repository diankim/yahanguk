-- 7.0.1: 6단계 장비가 5단계·기준 시세 0전으로 들어간 것 바로잡기
--   물품 표의 희귀도 맞추기 트리거(world_normalize_item_rarity)가 단계를 1~5로 줄이고 있었다. 단계는 1~6, 희귀도 이름은 5가지 그대로(6단계도 신품).
lock table public.world_characters in access exclusive mode;
alter table public.world_item_catalog drop constraint if exists world_item_catalog_tier_check;
alter table public.world_item_catalog add constraint world_item_catalog_tier_check check (tier >= 1 and tier <= 6);
create or replace function public.world_normalize_item_rarity() returns trigger
language plpgsql set search_path to 'public' as $$
begin
 new.tier:=least(6,greatest(1,coalesce(new.tier,1)));
 new.rarity:=case new.tier when 1 then 'common' when 2 then 'uncommon' when 3 then 'rare' when 4 then 'epic' else 'legendary' end;
 new.acquisition_difficulty:=least(5,new.tier);
 new.drop_rate_modifier:=case new.tier when 1 then 1.0 when 2 then 0.72 when 3 then 0.42 when 4 then 0.20 when 5 then 0.08 else 0.05 end;
 return new;
end $$;
update public.world_item_catalog set tier = 6 where item_id ~ '^(w_(melee|ranged|magic)6|a6|h6|s6|n6|m6|k6|t6)_' and tier <> 6;
-- 기준 시세: 가장 싼 제작법 재료값 ×1.2와 같은 칸 5단계 가장 비싼 것 ×1.15 가운데 큰 값(7.0.0에 적은 식 그대로)
update public.world_item_catalog i set reference_price = greatest(
    ceil(1.2 * (select sum(m.reference_price * (x.value)::int) from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id)),
    ceil(1.15 * (select max(f.reference_price) from public.world_item_catalog f where f.tier = 5 and f.category = i.category and f.item_id not like 'raid%' and f.item_id <> 'n5_lighthouse')))
 where i.tier = 6;
update public.world_patch_notes set body = body || E'\n## 7.0.1\n- 6단계 장비가 5단계·기준 시세 0전으로 들어가 있던 것을 고쳤습니다(되팔기 값·거래소 등록가 상한이 정상으로 돌아옵니다).\n'
 where note_id = '7.0.0' and body not like '%## 7.0.1%';
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261101010000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
