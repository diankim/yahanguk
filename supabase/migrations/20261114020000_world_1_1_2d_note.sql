update public.world_patch_notes set body = body || E'\n\n## 1.1.2d\n- PC에서 귀허의 주인과 싸우는 동안 전투 기록이 쌓이면 기록 칸이 화면 아래로 길게 늘어나던 것을 고쳤습니다. 기록 칸은 이제 화면 높이에 맞춰 화면 안에 들어오고, 넘치는 기록은 칸 안에서 굴려 봅니다. 창 크기를 바꿔도 다시 맞춰집니다.'
 where note_id = '1.1.0' and position('## 1.1.2d' in body) = 0;
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261114020000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
