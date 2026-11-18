create or replace function public.world_quest_first_tasks(p_quest text) returns boolean
language sql stable set search_path = '' as $$
  select exists (select 1 from public.world_quest_steps s where s.quest_id = p_quest and s.step = 1 and jsonb_array_length(coalesce(s.need -> 'tasks', '[]'::jsonb)) > 0)
$$;
revoke all on function public.world_quest_first_tasks(text) from public, anon, authenticated;
select pg_temp.yh_own('public.world_quest_first_tasks(text)', 'fn_owner_field');
