delete from public.world_quest_progress
 where owner_id = '4cbe549b-c62d-4ae4-9257-55aff5cccc69' and started_at < '2026-11-05 08:50:00+00'
returning quest_id, step, started_at;
