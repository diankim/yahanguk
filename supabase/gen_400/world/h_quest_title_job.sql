create or replace function public.world_quest_title_trg()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare t record; v_job text;
begin
  if new.done_at is null or (tg_op = 'UPDATE' and old.done_at is not null) then return new; end if;
  select c.job_key into v_job from public.world_characters c where c.owner_id = new.owner_id;
  for t in select c.title_key, c.title_name from public.world_quest_steps s
             join public.world_title_catalog c on c.title_key = coalesce(s.reward ->> 'title', s.reward -> 'title_job' ->> v_job)
            where s.quest_id = new.quest_id and (s.reward ? 'title' or s.reward -> 'title_job' ? v_job) and c.active loop
    insert into public.world_character_titles(owner_id, title_key) values (new.owner_id, t.title_key) on conflict do nothing;
    if found then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (new.owner_id, 'title', '칭호를 얻었습니다', '「' || t.title_name || '」 · 캐릭터 › 칭호에서 장착할 수 있습니다.', jsonb_build_object('title_key', t.title_key));
    end if;
  end loop;
  return new;
end $function$;
revoke all on function public.world_quest_title_trg() from public, anon, authenticated;
