create or replace function pg_temp.rf(p_fn regprocedure, p_pairs text[]) returns void language plpgsql as $g$
declare src text := pg_get_functiondef(p_fn); i int; n int;
begin
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(src) - length(replace(src, p_pairs[2 * i - 1], ''))) / greatest(length(p_pairs[2 * i - 1]), 1);
    if n <> 1 then raise exception '% 조각 %: % 번 나옴', p_fn, i, n; end if;
    src := replace(src, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute src;
end $g$;

select pg_temp.rf('public.world_spear_rules()'::regprocedure, array[
$o$'boss_keep', 0.5,$o$, $n$'drop', 1,$n$]);

select pg_temp.rf((select oid from pg_proc where proname = 'world_battle_action' and pronamespace = 'public'::regnamespace)::regprocedure, array[
$o$  IF act NOT IN ('attack', 'skill') THEN v_pfx := v_pfx - 'chain'; END IF;$o$,
$n$  IF act NOT IN ('attack', 'skill') AND v_pfx ? 'chain' THEN v_pfx := v_pfx || jsonb_build_object('chain', greatest(0, coalesce((v_pfx ->> 'chain')::int, 0) - (public.world_spear_rules() ->> 'drop')::int)); END IF;$n$]);

select pg_temp.rf((select oid from pg_proc where proname = 'world_raid_action' and pronamespace = 'public'::regnamespace)::regprocedure, array[
$o$f := f || jsonb_build_object('spch', floor(coalesce((f ->> 'spch')::int, 0) * (public.world_spear_rules() ->> 'boss_keep')::numeric)::int);$o$,
$n$f := f || jsonb_build_object('spch', greatest(0, coalesce((f ->> 'spch')::int, 0) - (public.world_spear_rules() ->> 'drop')::int));$n$]);

select pg_temp.rf((select oid from pg_proc where proname = 'world_gw_resolve' and pronamespace = 'public'::regnamespace)::regprocedure, array[
$o$coalesce(m.act ->> 'a', 'guard') not in ('attack', 'coop') and vfx ? 'spch' then$o$,
$n$coalesce(m.act ->> 'a', 'guard') not in ('attack', 'coop', 'move') and vfx ? 'spch' then$n$,
$o$vfx := vfx || jsonb_build_object('spch', floor(coalesce((vfx ->> 'spch')::int, 0) * (public.world_spear_rules() ->> 'boss_keep')::numeric)::int);$o$,
$n$vfx := vfx || jsonb_build_object('spch', greatest(0, coalesce((vfx ->> 'spch')::int, 0) - (public.world_spear_rules() ->> 'drop')::int));$n$]);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124090000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
