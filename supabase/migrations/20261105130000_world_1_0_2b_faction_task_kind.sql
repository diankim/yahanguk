do $w$
declare d text; a text; b text;
begin
  d := replace(pg_get_functiondef('public.world_faction_current(uuid,boolean)'::regprocedure), E'\r\n', E'\n');
  a := $a$tasks := tasks || jsonb_build_object('label', public.world_faction_task_label(t), 'cur', n, 'n', (t ->> 'n')::int);$a$;
  b := $a$tasks := tasks || jsonb_build_object('label', public.world_faction_task_label(t), 'cur', n, 'n', (t ->> 'n')::int, 't', t ->> 't', 'regions', coalesce(t -> 'r', '[]'::jsonb));$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.2b world_faction_current 할 일 문구가 없습니다'; end if;
  execute replace(d, a, b);
end $w$;

update public.world_app_meta set value = '20261105130000' where key = 'db_version';
