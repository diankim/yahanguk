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

select pg_temp.rf('public.world_bijang_rules()'::regprocedure, array[
$o$"open": {"cap": 70, "pct": 40, "gear": "mz_soil_pct"}$o$, $n$"open": {"cap": 60, "pct": 40, "gear": "mz_soil_pct"}$n$]);

update public.world_patch_notes set body = replace(body, E'- 비장도를 펼쳤을 때 비장고가 열릴 확률을 30%에서 40%로 올렸습니다. 명장 장비로 올릴 수 있는 상한도 60%에서 70%로 올렸습니다.\n', '')
 where note_id = '3.5.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124070000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
