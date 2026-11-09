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

select pg_temp.yh_fix('world_battle_open', array[
$q$AND t ->> 't' = 'win' AND t ->> 'rank' = 'guardian'$q$,
$q$AND t ->> 't' = 'win' AND (t ->> 'rank' = 'guardian' OR (jsonb_typeof(t -> 'm') = 'array' AND EXISTS (SELECT 1 FROM public.world_region_monsters gm WHERE gm.region_id = p_region AND gm.role = 'guardian' AND t -> 'm' ? gm.monster_id)))$q$,
$q$WHERE region_id = p_region AND role = 'guardian' ORDER BY random() LIMIT 1;$q$,
$q$WHERE region_id = p_region AND role = 'guardian' ORDER BY (v_gq AND EXISTS (SELECT 1 FROM public.world_quest_progress qp JOIN public.world_quest_steps qs ON qs.quest_id = qp.quest_id AND qs.step = qp.step + 1 CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(qs.need -> 'tasks') = 'array' THEN qs.need -> 'tasks' ELSE '[]' END) t WHERE qp.owner_id = p_owner AND qp.done_at IS NULL AND t ->> 't' = 'win' AND jsonb_typeof(t -> 'm') = 'array' AND t -> 'm' ? world_region_monsters.monster_id)) DESC, random() LIMIT 1;$q$], 1);

update public.world_app_meta set value = '20261109160000' where key = 'db_version';
