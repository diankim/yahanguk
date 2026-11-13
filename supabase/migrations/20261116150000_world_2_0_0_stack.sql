update public.world_item_catalog set stack_size = 40, stackable = true where category = 'material' and stack_size < 40;
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116150000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
