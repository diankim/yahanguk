update public.world_quest_steps
   set lines = replace(replace(lines::text, '희수 언니 편지 받았어요', '희수 누님 편지 받았어요'), '희수 언니가 그런 걸 잘 알아요', '희수 서리님이 그런 걸 잘 알아요')::jsonb
 where quest_id = 'mke_hisu_2' and lines::text like '%희수 언니%';

update public.world_patch_notes set body = body || E'\n- [대사] 묵적록 일부 장면의 대사를 다듬었습니다.'
where note_id = '3.8.0' and position('[대사] 묵적록 일부 장면의 대사를 다듬었습니다.' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127150000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
