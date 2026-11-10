do $c$ declare bad text; begin
  select string_agg(distinct x.k, ', ') into bad from (
    select 'quest ' || q.quest_id k from public.world_quests q join public.world_quest_steps s using (quest_id)
      join public.world_map_regions r on r.region_id in (select jsonb_array_elements_text(@UP@))
     where (q.kind = 'main' or q.quest_id ~ '^(jq|aq)') and q.min_level < r.min_level
       and (s.need::text like '%"' || r.region_id || '"%'
            or exists (select 1 from public.world_region_monsters m where m.region_id = r.region_id and s.need::text like '%"' || m.monster_id || '"%'))
    union all
    select 'scene ' || f.scene_key from public.world_faction_scenes f
      join public.world_map_regions r on r.region_id in (select jsonb_array_elements_text(@UP@))
     where f.min_level < r.min_level
       and (f.need::text like '%"' || r.region_id || '"%'
            or exists (select 1 from public.world_region_monsters m where m.region_id = r.region_id and f.need::text like '%"' || m.monster_id || '"%'))
    union all
    select 'clue ' || c.clue_id from public.world_story_clues c join public.world_story_chapters ch on ch.chapter_id = c.chapter_id
     where c.region_id in (select jsonb_array_elements_text(@UP@)) and ch.min_level < (select r.min_level from public.world_map_regions r where r.region_id = c.region_id)) x;
  if bad is not null then raise exception '레벨을 올린 지역을 더 낮은 레벨의 주 이야기·직업·세력 장면이 씀: %', bad; end if;
end $c$;
