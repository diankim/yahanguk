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

select pg_temp.rf('public.world_outfit_design_save(text,text,text,text,text,text)'::regprocedure, array[
$o$x.deleted_at is null and x.removed_at is null) >= (r -> p_slot ->> 'keep')::int then$o$,
$n$x.deleted_at is null and x.removed_at is null) >= (r -> p_slot ->> 'keep')::int and not exists (select 1 from public.world_staff s where s.owner_id = uid) then$n$,
$o$x.created_at >= public.world_drawing_day_start()) >= (r ->> 'per_day')::int then$o$,
$n$x.created_at >= public.world_drawing_day_start()) >= (r ->> 'per_day')::int and not exists (select 1 from public.world_staff s where s.owner_id = uid) then$n$,
$o$x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int then$o$,
$n$x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int and not exists (select 1 from public.world_staff s where s.owner_id = uid) then$n$]);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124140000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
