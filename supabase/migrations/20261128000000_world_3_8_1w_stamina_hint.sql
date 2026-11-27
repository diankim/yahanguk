create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_stamina_change', array[
$a$60)::int));$a$,
$a$60)::int)) USING HINT = 'stamina';$a$
]);

update public.world_patch_notes set body = body || E'\n- [편의] 탐색력이 모자라 토벌 합류(비장고 파수꾼·파티 토벌)가 안 될 때, 가진 탐색력 회복품을 하나 써서 바로 합류할지 묻습니다.'
where note_id = '3.8.0' and position('바로 합류할지 묻습니다' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261128000000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
