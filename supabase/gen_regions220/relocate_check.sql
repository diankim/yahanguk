do $c$ begin
  if exists (select 1 from public.world_quest_steps where quest_id in ('cq110_bat_2', 'cq110_bat_3', 'cq110_bat_4') and (lines::text || need::text) ~ '(혈엽림|red_forest|사슴)')
     or exists (select 1 from public.world_quest_steps where quest_id = 'mq_nameless_bell' and (lines::text || need::text) ~ '(혈엽림|혈엽수인|red_forest|"m_21")')
     or exists (select 1 from public.world_story_chapters where chapter_id = 'nameless_bell' and (coalesce(summary, '') || coalesce(intro, '') || coalesce(outro, '')) ~ '혈엽림')
     or exists (select 1 from public.world_story_clues where clue_id = 'bell_chain' and (region_id = 'red_forest' or name ~ '단풍'))
     or exists (select 1 from public.world_quests where quest_id = 'cq110_bat_3' and (region_id || title || summary) ~ '(혈엽림|red_forest)')
     or exists (select 1 from public.world_faction_scenes where scene_key in ('southern_remnant:rank:2', 'southern_remnant:rank:3') and (lines::text || title || goal || need::text) ~ '(혈엽림|red_forest)') then
    raise exception '옮긴 퀘스트에 혈엽림이 남음';
  end if;
end $c$;
