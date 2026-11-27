lock table public.world_quest_steps in share row exclusive mode;

update public.world_quest_steps s
   set need = jsonb_set(s.need, '{tasks}', (select jsonb_agg(case when t ->> 't' = 'idle' and (t ->> 'min')::int = 60 then jsonb_set(t, '{min}', '30'::jsonb) else t end order by o)
                                             from jsonb_array_elements(s.need -> 'tasks') with ordinality x(t, o))),
       goal = replace(s.goal, '1시간 넘게', '30분 이상')
 where exists (select 1 from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t where t ->> 't' = 'idle' and (t ->> 'min')::int = 60);

do $$ begin
  if exists (select 1 from public.world_quest_steps s, jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t where t ->> 't' = 'idle' and (t ->> 'min')::int > 30) then
    raise exception '1시간 자율 활동 할 일이 남았습니다';
  end if;
end $$;

select public.world_quest_label_refresh();

update public.world_patch_notes set body = body || E'\n- [퀘스트] 명등기의 「자율 활동을 끝까지 하기」 할 일이 1시간 이상에서 30분 이상으로 줄었습니다.'
where note_id = '3.8.0' and position('30분 이상으로 줄었습니다' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127230000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
