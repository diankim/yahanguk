-- 서버 부담 줄이기: 실시간(Realtime) 감시 목록에서 화면이 구독하지 않는 표를 뺀다.
-- 감시 목록에 든 표는 바뀔 때마다 실시간 서버가 변경 기록(WAL)을 풀어 읽는다. world_characters는 행동마다 고쳐지고
-- world_events도 행동마다 늘어나, 아무도 구독하지 않는데도 이 처리가 DB 시간을 가장 많이 썼다(2026-10-28 pg_stat_statements 1위).
-- 화면이 구독하는 표(assets/js의 postgres_changes): world_active_sessions·world_chat_messages·world_circle_messages·world_notifications — 그대로 둔다.
-- 표와 데이터는 그대로이고, 감시 목록에서만 빠진다(다시 넣으려면 alter publication supabase_realtime add table ...).
do $$
declare t text;
begin
  foreach t in array array['world_characters', 'world_events', 'world_story_progress', 'world_clock', 'room_members', 'characters', 'messages', 'activity_logs', 'character_states'] loop
    if exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime drop table public.%I', t);
    end if;
  end loop;
end $$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028180000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
