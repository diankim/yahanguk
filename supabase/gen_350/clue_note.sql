update public.world_patch_notes set body = replace(body, $o$## 고친 것
$o$, $n$## 본편 단서 안내
- 본편 장의 장면을 모두 마치면 현장 퀘스트 칸에 남은 단서와 찾을 곳(지도 바로 가기)이 보입니다.
- 모인 단서로 세울 수 있는 가설은 퀘스트 칸에서 바로 「가설 확정」을 누를 수 있습니다. 일지에 들어가지 않아도 장을 마칠 수 있습니다.

## 고친 것
$n$)
 where note_id = '3.5.0' and position('## 본편 단서 안내' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124050000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
