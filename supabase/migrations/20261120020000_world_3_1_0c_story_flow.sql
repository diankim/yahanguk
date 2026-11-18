lock table public.world_characters in access exclusive mode;

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

create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;


create or replace function public.world_quest_first_tasks(p_quest text) returns boolean
language sql stable set search_path = '' as $$
  select exists (select 1 from public.world_quest_steps s where s.quest_id = p_quest and s.step = 1 and jsonb_array_length(coalesce(s.need -> 'tasks', '[]'::jsonb)) > 0)
$$;
revoke all on function public.world_quest_first_tasks(text) from public, anon, authenticated;
select pg_temp.yh_own('public.world_quest_first_tasks(text)', 'fn_owner_field');


select pg_temp.yh_fix('world_quest_board()', array[
  E'  select coalesce(jsonb_agg(\n    case when jsonb_typeof(a.a1)',
  E'  for q in select x.quest_id, x.kind, x.cat, x.title, x.summary from public.world_quests x
            where x.active and (x.job_key is null or x.job_key = c.job_key) and (x.faction_key is null or x.faction_key = c.faction_key)
              and not (x.quest_id = any(dn)) and c.level >= x.min_level and x.after <@ dn and public.world_quest_gate_ok(x.open_req)
              and not exists (select 1 from public.world_quest_progress g where g.owner_id = uid and g.quest_id = x.quest_id and coalesce(g.step, 0) >= 1)
              and not exists (select 1 from public.world_quest_replays r where r.owner_id = uid and r.quest_id = x.quest_id)
              and public.world_quest_first_tasks(x.quest_id)
            order by (x.kind = ''main'') desc, x.min_level, x.sort, x.quest_id loop
    st := public.world_quest_step_state(uid, q.quest_id);
    acts := acts || (jsonb_build_object(''quest_id'', q.quest_id, ''kind'', q.kind, ''cat'', q.cat, ''title'', q.title, ''summary'', q.summary, ''phase'', ''step'', ''auto'', true)
      || coalesce(st, ''{}''::jsonb) || jsonb_build_object(''title'', q.title, ''step_title'', st ->> ''title''));
  end loop;
  select coalesce(jsonb_agg(
    case when jsonb_typeof(a.a1)',
  E'  where a.ok or (a.kind = ''main'' and a.after <@ dn);',
  E'  where (a.ok or (a.kind = ''main'' and a.after <@ dn)) and not (a.ok and public.world_quest_first_tasks(a.quest_id));'
]);


update public.world_patch_notes set body = body || $N$
- 명등기 2장부터는 앞 장을 마치면 다음 장이 곧바로 「진행 중」으로 이어지고, 첫 장면의 할 일이 퀘스트 칸에 보입니다. 할 일을 마치고 보고하면 그 장을 받으며 이야기가 이어집니다(전에는 받기 전이라 할 일이 안 보이고 「아직 할 일이 남았습니다」로 막혔습니다).
- 퀘스트 칸의 귀허도·묵적록·명등기 이야기는 「본편」으로 표시합니다.$N$
 where note_id = '3.0.0' and position('곧바로 「진행 중」으로 이어지고' in body) = 0;


insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261120020000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
