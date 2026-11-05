create or replace function public.world_character_purge(p_uid uuid) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  if p_uid is null then return; end if;
  delete from public.world_quest_progress where owner_id = p_uid;
  delete from public.world_quest_abandons where owner_id = p_uid;
  delete from public.world_faction_progress where owner_id = p_uid;
  delete from public.world_faction_unlocks where owner_id = p_uid;
  delete from public.world_tutorial_state where owner_id = p_uid;
  delete from public.world_storage where owner_id = p_uid;
  delete from public.world_title_presets where owner_id = p_uid;
  delete from public.world_quickslots where owner_id = p_uid;
  delete from public.world_skill_picks where owner_id = p_uid;
  delete from public.world_item_locks where owner_id = p_uid;
  delete from public.world_item_durability where owner_id = p_uid;
  delete from public.world_item_acquired where owner_id = p_uid;
  delete from public.world_gear_enhance where owner_id = p_uid;
  delete from public.world_overflow_items where owner_id = p_uid;
  delete from public.world_monster_codex where owner_id = p_uid;
  delete from public.world_fish_log where owner_id = p_uid;
  delete from public.world_region_visits where owner_id = p_uid;
  delete from public.world_hidden_trails where owner_id = p_uid;
  delete from public.world_character_cosmetics where owner_id = p_uid;
  delete from public.world_craft_favorites where owner_id = p_uid;
  delete from public.world_pet_profile where owner_id = p_uid;
  delete from public.world_pet_streak where owner_id = p_uid;
  delete from public.world_pet_gifts where owner_id = p_uid;
  delete from public.world_pet_guest where owner_id = p_uid;
  delete from public.world_pets where owner_id = p_uid;
  if not exists (select 1 from public.world_housing_shared s where p_uid in (s.home_id, s.mate_id)) then
    delete from public.world_housing_store where owner_id = p_uid;
    delete from public.world_housing_rewards where owner_id = p_uid;
    delete from public.world_housing_guestbook where owner_id = p_uid;
    delete from public.world_housing_visits where owner_id = p_uid;
    delete from public.world_housing where owner_id = p_uid;
  end if;
end $f$;
revoke all on function public.world_character_purge(uuid) from public, anon, authenticated;
grant execute on function public.world_character_purge(uuid) to fn_owner_field;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_character_delete(text)'::regprocedure), E'\r\n', E'\n');
  if position('world_character_purge' in d) > 0 then return; end if;
  a := '  DELETE FROM public.world_characters WHERE owner_id = uid;';
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.4j world_character_delete 기준 문구가 없습니다'; end if;
  execute replace(d, a, '  PERFORM public.world_character_purge(uid);' || E'\n' || a);
end $w$;

update public.world_app_meta set value = '20261106020000' where key = 'db_version';
