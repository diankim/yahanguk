create or replace function public.world_level_rules()
 returns jsonb language sql immutable
as $function$ select '{"cap": 55, "per_level": 3, "stat_points_cap": 162}'::jsonb $function$;

do $$
declare x record; d text; n int;
begin
  for x in select * from (values
      ('public.world_gw_ready_check(uuid,text,text)'::regprocedure,
       $a$    if c.level < public.world_level_cap() then raise exception '무용담은 Lv%만 들어갈 수 있습니다.', public.world_level_cap(); end if;$a$,
       $b$    if c.level < (public.world_ultimate_rules() ->> 'level')::int then raise exception '무용담은 Lv% 이상만 들어갈 수 있습니다.', (public.world_ultimate_rules() ->> 'level')::int; end if;$b$)
  ) v(f, o, nw) loop
    d := pg_get_functiondef(x.f);
    n := (length(d) - length(replace(d, x.o, ''))) / length(x.o);
    if n <> 1 then raise exception '% 조각 % 개', x.f, n; end if;
    execute replace(d, x.o, x.nw);
  end loop;
end $$;
