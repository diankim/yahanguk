create or replace function pg_temp.yh_line_fix(p_kind text, p_key text, p_step int, p_old text, p_new text) returns void language plpgsql as $f$
declare n int;
begin
  if p_kind = 'quest' then
    update public.world_quest_steps s set lines = (select jsonb_agg(case when position(p_old in e->>'t') > 0 then jsonb_set(e, '{t}', to_jsonb(replace(e->>'t', p_old, p_new))) else e end order by o)
      from jsonb_array_elements(s.lines) with ordinality t(e, o)) where s.quest_id = p_key and s.step = p_step and position(p_old in s.lines::text) > 0;
  end if;
  get diagnostics n = row_count;
  if n <> 1 then raise exception '고칠 줄을 못 찾음: % % %', p_key, p_step, p_old; end if;
end $f$;
