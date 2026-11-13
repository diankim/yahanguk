update public.world_item_catalog set tradeable = true
where category = 'material' and base_item_id is null and not tradeable
  and item_id in ('spirit_core', 'seal_shard', 'pet_token');

with nf as (select fish_id from public.world_fish_species where named),
made as (select distinct r.output_item from public.world_crafting_recipes r, jsonb_object_keys(r.ingredients) k where k in (select fish_id from nf)),
made2 as (select distinct r.output_item from public.world_crafting_recipes r, jsonb_object_keys(r.ingredients) k where k in (select output_item from made))
update public.world_item_catalog set tradeable = true
where base_item_id is null and not tradeable
  and (item_id in (select fish_id from nf) or item_id in (select output_item from made) or item_id in (select output_item from made2));

update public.world_app_meta set value = '20261117000000' where key = 'db_version';
