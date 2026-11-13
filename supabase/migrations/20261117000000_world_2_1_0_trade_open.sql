update public.world_item_catalog set tradeable = true
where category = 'material' and base_item_id is null and not tradeable
  and item_id in ('spirit_core', 'seal_shard', 'pet_token');

update public.world_app_meta set value = '20261117000000' where key = 'db_version';
