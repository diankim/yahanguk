update public.world_patch_notes set body = body || E'\n- 현장 퀘스트 칸에서 진행 중인 본편(홍인사·요인록·묵적록·명등기의 장)이 지역과 상관없이 맨 위에 옵니다. 본편 이야기에 딸렸지만 장이 아닌 퀘스트에는 「보조」 꼬리표가 붙습니다.\n- 「내 모습」의 머리 열세 가지를 새로 그렸습니다. 결이 살고 앞머리 위에 빛이 듭니다.\n- 「내 모습」의 눈을 다듬었습니다. 눈매는 그대로 두고 눈동자 명암과 반짝임을 더했으며, 두 눈의 반짝임이 같은 자리에 오도록 맞췄습니다.'
where note_id = '3.0.0' and position('본편(홍인사·요인록·묵적록·명등기의 장)이 지역과 상관없이' in body) = 0;
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261122020000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
