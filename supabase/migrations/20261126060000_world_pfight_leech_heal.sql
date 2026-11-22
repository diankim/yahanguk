do $m$
declare src text; def text; fn regprocedure; o text;
begin
  fn := 'public.world_battle_action'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := 'hp := least(100, hp + extra); lines := lines || jsonb_build_array(''흘린 피를 갈무리했다. 체력 +'' || extra);';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_battle_action 피흡 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'PERFORM set_config(''yh.pf_leech'', (least(100, hp + extra) - hp)::text, true); ' || o);
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';

  fn := 'public.world_pfight_resolve'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := 'perform set_config(''yh.pf_cost'', '''', true);';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_pfight_resolve 차례 시작 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, o || ' perform set_config(''yh.pf_leech'', '''', true);');
  o := 'taken = pm.taken + greatest(0, coalesce(nullif(current_setting(''yh.pf_hb'', true), '''')::int, c.health) - c.health - coalesce(nullif(current_setting(''yh.pf_cost'', true), '''')::int, 0)),' || chr(10) ||
       '        heal = pm.heal + greatest(0, c.health - coalesce(nullif(current_setting(''yh.pf_hb'', true), '''')::int, c.health))';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_pfight_resolve 회복 셈 모양이 예상과 다릅니다'; end if;
  src := replace(src, o,
       'taken = pm.taken + greatest(0, coalesce(nullif(current_setting(''yh.pf_hb'', true), '''')::int, c.health) - (c.health - coalesce(nullif(current_setting(''yh.pf_leech'', true), '''')::int, 0)) - coalesce(nullif(current_setting(''yh.pf_cost'', true), '''')::int, 0)),' || chr(10) ||
       '        heal = pm.heal + greatest(0, c.health - coalesce(nullif(current_setting(''yh.pf_leech'', true), '''')::int, 0) - coalesce(nullif(current_setting(''yh.pf_hb'', true), '''')::int, c.health)) + coalesce(nullif(current_setting(''yh.pf_leech'', true), '''')::int, 0)');
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126060000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
