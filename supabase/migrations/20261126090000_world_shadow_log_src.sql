do $m$
declare src text; def text; fn regprocedure; o text;
begin
  fn := 'public.world_raid_hit'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := 'perform public.world_raid_say_n(p_raid, ''hit'', nm || '' — '' || case p_kind when ''grip''';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_hit 맞음 기록 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'perform public.world_raid_say_n(p_raid, case p_kind when ''grip'' then ''hit_grip'' when ''ink'' then ''hit_ink'' when ''buster'' then ''hit_brand'' else ''hit'' end, nm || '' — '' || case p_kind when ''grip''');
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126090000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
