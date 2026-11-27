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

do $$
declare r jsonb := public.world_bijang_rules() || '{"lucky_pct": 20}'::jsonb;
begin
  execute format('create or replace function public.world_bijang_rules() returns jsonb language sql immutable as $f$ select %L::jsonb $f$', r);
end $$;

select pg_temp.yh_fix('world_bijang_pick', array[
$a$mates uuid[]; lead uuid; fid uuid;$a$,
$a$mates uuid[]; lead uuid; fid uuid; lucky boolean := false;$a$,
$a$  update public.world_bijang_runs set picks = picks || jsonb_build_array(jsonb_build_object('room', r.room, 'door', p_door, 'ok', p_door = r.door)), updated_at = now() where run_id = p_run;
  if p_door <> r.door then$a$,
$a$  lucky := p_door <> r.door and random() * 100 < coalesce((ru ->> 'lucky_pct')::numeric, 0);
  update public.world_bijang_runs set picks = picks || jsonb_build_array(jsonb_build_object('room', r.room, 'door', p_door, 'ok', p_door = r.door, 'lucky', lucky)), updated_at = now() where run_id = p_run;
  if p_door <> r.door and not lucky then$a$,
$a$  perform public.world_bijang_say(p_run, jsonb_build_array(r.room || '번 방 · ' || p_door || '번 문이 열렸다.'));$a$,
$a$  perform public.world_bijang_say(p_run, jsonb_build_array(case when lucky then r.room || '번 방 · ' || p_door || '번 문은 틀린 문이었다. 흙이 무너져 내리다 멈추더니, 문이 다시 열렸다.' else r.room || '번 방 · ' || p_door || '번 문이 열렸다.' end));$a$
]);

update public.world_patch_notes set body = body || E'\n- [비장고] 틀린 문을 골라도 드물게 문이 다시 열려 다음 방으로 갈 수 있습니다(그 뒤는 맞는 문과 같이 파수꾼과 상자). 문을 고르면 문이 떨리다가 열리거나 무너지는 연출이 나옵니다.'
where note_id = '3.8.0' and position('[비장고] 틀린 문을 골라도' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261128010000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
