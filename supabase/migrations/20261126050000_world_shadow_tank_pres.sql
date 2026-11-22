do $m$
declare v jsonb := public.world_shadow_rules() || '{"tank_pres": {"mul": 2, "jobs": ["artificer", "bloodknight"]}}'::jsonb;
  src text; def text; fn regprocedure := 'public.world_raid_action'::regproc::regprocedure; o text;
begin
  execute format('create or replace function public.world_shadow_rules() returns jsonb language sql immutable set search_path = pg_catalog as %L', ' select ' || quote_literal(v::text) || '::jsonb ');
  select prosrc into src from pg_proc where oid = fn;
  o := 'order by public.world_cb_pick_key((x.stats ->> ''pres'')::numeric + coalesce((x.fx -> ''taunt'' ->> ''pres'')::numeric, 0)) limit 1;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 표적 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'order by public.world_cb_pick_key((x.stats ->> ''pres'')::numeric * case when rd.kind = ''world'' and public.world_shadow_rules() -> ''tank_pres'' -> ''jobs'' ? x.job_key then (public.world_shadow_rules() -> ''tank_pres'' ->> ''mul'')::numeric else 1 end + coalesce((x.fx -> ''taunt'' ->> ''pres'')::numeric, 0)) limit 1;');
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

update public.world_patch_notes set body = body || E'\n- 사슬 벗은 그림자는 호위 무사·혈기사를 다른 조사원보다 훨씬 자주 노립니다.'
 where note_id = '3.7.0' and body not like '%호위 무사·혈기사를 다른 조사원보다 훨씬 자주%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126050000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
