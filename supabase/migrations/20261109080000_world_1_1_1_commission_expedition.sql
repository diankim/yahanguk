create or replace function pg_temp.yh_fix(p_name text, p_pairs text[], p_n int) returns void language plpgsql as $f$
declare d text; i int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> p_n then raise exception '함수 % 모양이 예상과 다릅니다', p_name; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_track_commissions', array[
$q$ELSIF new.event_type = 'gather' THEN$q$,
$q$ELSIF new.event_type = 'expedition_end' AND jsonb_typeof(p -> 'wins') = 'number' AND (p ->> 'wins')::int > 0 THEN
    UPDATE public.world_commissions SET progress = least(need, progress + (p ->> 'wins')::int)
    WHERE owner_id = new.actor_id AND day = today AND kind = 'hunt' AND claimed_at IS NULL AND progress < need AND (target_region IS NULL OR target_region = p ->> 'region_id');
  ELSIF new.event_type = 'gather' THEN$q$], 1);

update public.world_patch_notes set body = body || E'\n- 원정에서 이긴 싸움도 상시 의뢰 「토벌」에 셉니다(돌아온 뒤 한 번에, 의뢰 지역이 정해져 있으면 그 지역 원정만).'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109080000' where key = 'db_version';
