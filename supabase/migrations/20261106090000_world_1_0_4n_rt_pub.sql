do $$
declare t text;
begin
  foreach t in array array['world_active_sessions','world_chat_messages','world_circle_messages','world_notifications','world_raids','world_party_messages'] loop
    if exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime drop table public.%I', t);
    end if;
  end loop;
end $$;

update public.world_app_meta set value = '20261106090000' where key = 'db_version';
