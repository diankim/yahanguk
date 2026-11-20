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

select pg_temp.rf((select oid from pg_proc where proname = 'world_gw_snapshot' and pronamespace = 'public'::regnamespace)::regprocedure, array[
$o$'my_act', me.act,$o$, $n$'my_act', me.act, 'spch', coalesce((me.fx ->> 'spch')::numeric, 0),$n$]);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124080000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
