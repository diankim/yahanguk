create or replace function public.world_session_broadcast() returns trigger
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  perform realtime.send(jsonb_build_object('at', now()), 'claim', 'session:' || new.owner_id::text, true);
  return new;
end $f$;
revoke all on function public.world_session_broadcast() from public, anon, authenticated;

drop trigger if exists trg_world_session_broadcast on public.world_active_sessions;
create trigger trg_world_session_broadcast after insert or update on public.world_active_sessions
  for each row execute function public.world_session_broadcast();

drop policy if exists yh_session_topic_read on realtime.messages;
create policy yh_session_topic_read on realtime.messages for select to authenticated
  using (realtime.messages.extension = 'broadcast' and realtime.topic() = 'session:' || auth.uid()::text);

update public.world_app_meta set value = '20261106030000' where key = 'db_version';
