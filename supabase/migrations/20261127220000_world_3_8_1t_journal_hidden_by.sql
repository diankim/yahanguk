create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_quest_journal', array[
$a$hidden int := 0; dn text[];$a$,
$a$hidden int := 0; dn text[]; hbs jsonb[] := '{}'; vis text[] := '{}'; hb jsonb;$a$,
$a$then hidden := hidden + 1; end if; continue;$a$,
$a$then hidden := hidden + 1; hbs := hbs || jsonb_build_object('a', (select x from unnest(q.after) x where not x = any (dn) limit 1), 'cat', q.cat); end if; continue;$a$,
$a$    arr := arr || jsonb_build_object('quest_id', q.quest_id,$a$,
$a$    if status <> 'done' then vis := vis || q.quest_id::text; end if;
    arr := arr || jsonb_build_object('quest_id', q.quest_id,$a$,
$a$  out := to_jsonb(arr);$a$,
$a$  out := to_jsonb(arr);
  select coalesce(jsonb_agg(jsonb_build_object('quest_id', g.a, 'title', wq.title, 'n', g.n, 'cats', to_jsonb(g.cats)) order by wq.min_level, g.a), '[]'::jsonb) into hb
    from (select h ->> 'a' a, count(*) n, array_agg(distinct coalesce(nullif(h ->> 'cat', ''), '보조')) cats
            from unnest(hbs) h where h ->> 'a' = any (vis) group by 1) g
    join public.world_quests wq on wq.quest_id = g.a;$a$,
$a$'hidden', hidden, 'here_id'$a$,
$a$'hidden', hidden, 'hidden_by', hb, 'here_id'$a$
]);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127220000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
