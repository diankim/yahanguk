create or replace function public.world_reader_fac(p_uid uuid) returns jsonb
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select jsonb_build_object('fac', c.major_faction_id, 'rank', p.rank, 'rank_name', r.rank_name)
    from public.world_characters c
    left join public.world_faction_progress p on p.owner_id = c.owner_id and p.faction_id = c.major_faction_id and p.join_done_at is not null
    left join public.world_faction_ranks r on r.faction_id = p.faction_id and r.rank = p.rank
   where c.owner_id = p_uid
$$;
revoke all on function public.world_reader_fac(uuid) from public, anon, authenticated;
grant execute on function public.world_reader_fac(uuid) to fn_owner_field;

create or replace function public.world_quest_lines_for(p_lines jsonb, p_job text, p_affil text, p_reader jsonb) returns jsonb
language sql immutable set search_path to 'pg_catalog' as $$
  with t as (
    select x, o,
      (not x ? 'job' or x ->> 'job' = p_job) and (not x ? 'affil' or x ->> 'affil' = p_affil)
      and case when x ? 'fac' then p_reader ->> 'fac' = x ->> 'fac' and p_reader ? 'rank' and (p_reader ->> 'rank') is not null
                 and (not x ? 'rank' or (p_reader ->> 'rank')::int between (x -> 'rank' ->> 0)::int and (x -> 'rank' ->> 1)::int)
               when x ? 'fac_not' then p_reader ->> 'fac' is distinct from x ->> 'fac_not' or (p_reader ->> 'rank') is null
               else true end ok
      from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) with ordinality z(x, o))
  select coalesce(jsonb_agg(case when x ->> 't' like '%{등급}%' then jsonb_set(x, '{t}', to_jsonb(replace(x ->> 't', '{등급}', coalesce(p_reader ->> 'rank_name', '조사원')))) else x end
           - 'grp' - 'spec' order by o), '[]'::jsonb)
    from t
   where ok and (not x ? 'grp' or (x ->> 'spec')::int = (select min((y.x ->> 'spec')::int) from t y where y.ok and y.x ->> 'grp' = t.x ->> 'grp'))
$$;
revoke all on function public.world_quest_lines_for(jsonb, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.world_quest_lines_for(jsonb, text, text, jsonb) to fn_owner_field;

select pg_temp.yh_patch('public.world_quest_report(text)',
  'public.world_quest_lines_for(s.lines, c.job_key, c.faction_key)',
  'public.world_quest_lines_for(s.lines, c.job_key, c.faction_key, public.world_reader_fac(c.owner_id))');
select pg_temp.yh_patch('public.world_quest_scene(text,integer)',
  'public.world_quest_lines_for(s.lines, c.job_key, c.faction_key)',
  'public.world_quest_lines_for(s.lines, c.job_key, c.faction_key, public.world_reader_fac(c.owner_id))');
select pg_temp.yh_patch('public.world_quest_scene(text,integer)',
  'public.world_quest_lines_for(ln, c.job_key, c.faction_key)',
  'public.world_quest_lines_for(ln, c.job_key, c.faction_key, public.world_reader_fac(c.owner_id))');
