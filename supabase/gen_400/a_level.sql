create or replace function public.world_level_rules()
 returns jsonb language sql immutable
as $function$ select '{"cap": 55, "per_level": 3, "mon_cap": 50, "stat_points_cap": 162}'::jsonb $function$;

create or replace function public.world_monster_cap(p_region text)
 returns integer language sql stable set search_path = public
as $function$
  select coalesce((public.world_domain_rules() -> (select r.territory_id from public.world_map_regions r where r.region_id = p_region) ->> 'mon_cap')::int,
                  (public.world_level_rules() ->> 'mon_cap')::int, public.world_level_cap())
$function$;
revoke all on function public.world_monster_cap(text) from public, anon, authenticated;
grant execute on function public.world_monster_cap(text) to fn_owner_field;

do $$
declare x record; d text; n int;
begin
  for x in select * from (values
      ('public.world_gw_ready_check(uuid,text,text)'::regprocedure,
       $a$    if c.level < public.world_level_cap() then raise exception '무용담은 Lv%만 들어갈 수 있습니다.', public.world_level_cap(); end if;$a$,
       $b$    if c.level < (public.world_ultimate_rules() ->> 'level')::int then raise exception '무용담은 Lv% 이상만 들어갈 수 있습니다.', (public.world_ultimate_rules() ->> 'level')::int; end if;$b$)
,
      ('public.world_battle_open(uuid,text,uuid,integer,integer)'::regprocedure,
       $a$public.world_level_cap() + CASE rk WHEN 'normal' THEN 0 ELSE 1 END$a$,
       $b$public.world_monster_cap(p_region) + CASE rk WHEN 'normal' THEN 0 ELSE 1 END$b$),
      ('public.world_battle_open(uuid,text,uuid,integer,integer)'::regprocedure,
       E'  lv := greatest(1, lv);\n',
       E'  lv := greatest(1, lv);\n  IF m.region_id <> p_region THEN lv := least(p_level + floor(random() * 3)::int, public.world_level_cap() + CASE rk WHEN ''normal'' THEN 0 ELSE 1 END); END IF;\n')
  ) v(f, o, nw) loop
    d := pg_get_functiondef(x.f);
    n := (length(d) - length(replace(d, x.o, ''))) / length(x.o);
    if n <> 1 then raise exception '% 조각 % 개', x.f, n; end if;
    execute replace(d, x.o, x.nw);
  end loop;
end $$;
