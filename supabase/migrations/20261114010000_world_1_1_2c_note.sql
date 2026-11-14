update public.world_patch_notes set body = body || E'\n\n## 1.1.2c\n- 글자 크기를 「크게」·「아주 크게」로 했을 때 휴대폰 현장 화면이 깨지던 것을 고쳤습니다. 탐색·원정·야영·자율 휴식·지도 칸의 글자와 쉬기 남은 시간이 칸 밖으로 넘치지 않고, 무기 줄의 아이콘이 혼자 한 줄에 남지 않습니다. 이어진 길·채집터는 두 칸 그대로 두고, 큰 글자일 때는 「채집」 단추가 이름 아래로 내려갑니다.'
 where note_id = '1.1.0' and position('## 1.1.2c' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261114010000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
