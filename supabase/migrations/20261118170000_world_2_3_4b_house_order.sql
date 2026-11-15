update public.world_patch_notes set body = body || '
- 별채에서 깔개가 앞쪽에 깔려 있으면 꼬마 동무와 내 모습이 가구·깔개 밑으로 들어가 가려지던 것을 고쳤습니다.
' where note_id = '2.3.0' and body not like '%가구·깔개 밑으로%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118170000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
