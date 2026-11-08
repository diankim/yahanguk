do $c$ begin
  if (select count(*) from public.world_quests where quest_id in ('gq_1','gq_2','gq_3','gq_4','gq_5','sq110_e_mark','sq110_e_ink','sq110_e_doorplate') and kind = 'side' and cat like '외전·%') <> 8 then
    raise exception '외전 퀘스트 분류: 없는 퀘스트가 있습니다';
  end if;
end $c$;

update public.world_quests set cat = '외전·귀허도' where quest_id in ('gq_1','gq_2','gq_3','gq_4','gq_5','sq110_e_mark');
update public.world_quests set cat = '외전·묵적록' where quest_id in ('sq110_e_ink','sq110_e_doorplate');

update public.world_patch_notes set body = body || E'\n- 외전 이야기를 일지 › 주 이야기로 옮겼습니다. 「본편 · 귀허도 · 묵적록」 단추로 이야기를 골라 봅니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109030000' where key = 'db_version';
