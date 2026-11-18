update public.world_patch_notes set body = body || $N$
- 일지의 본편·보조 퀘스트 카드가 받기 전 첫 장면에 할 일이 있는 장(명등기 2장부터)을 「진행 중」으로 펼쳐 할 일을 보여 줍니다. 장소도 첫 장면을 하는 곳으로 적고 그곳으로 가는 단추를 냅니다(전에는 장의 무대 지역만 적고 그리로 가는 단추만 보였습니다).$N$
 where note_id = '3.0.0' and position('받기 전 첫 장면에 할 일이 있는 장' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261120040000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
