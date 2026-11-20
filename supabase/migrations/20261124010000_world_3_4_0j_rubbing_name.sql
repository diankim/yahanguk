update public.world_item_catalog set item_name = replace(item_name, '문패 잉어 어탁', '문패 잉어 탁본'), description = replace(description, '문패 잉어 어탁', '문패 잉어 탁본')
 where item_id = 'hf_rubbing_doorplate_carp';
update public.world_crafting_recipes set recipe_name = replace(recipe_name, '문패 잉어 어탁', '문패 잉어 탁본'), description = replace(description, '문패 잉어 어탁', '문패 잉어 탁본')
 where recipe_id = 'r_hf_rubbing_doorplate_carp';
select public.world_quest_label_refresh();
do $n$ begin
  if (select substring(body from '.*\n(### [^\n]*)') from public.world_patch_notes where note_id = '3.0.0') <> '### 고친 것' then raise exception '3.0.0 마지막 칸이 고친 것이 아님'; end if;
end $n$;
update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n- 별채 가구 「문패 잉어 어탁」의 이름을 다른 명어 탁본과 같게 「문패 잉어 탁본」으로 고쳤습니다.\n'
 where note_id = '3.0.0' and position('「문패 잉어 탁본」으로 고쳤습니다' in body) = 0;
update public.world_app_meta set value = '20261124010000' where key = 'db_version';
