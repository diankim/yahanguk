update public.world_quests set after = array['mq_nine_gates'] where quest_id = 'gq_1' and coalesce(array_length(after, 1), 0) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124120000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
