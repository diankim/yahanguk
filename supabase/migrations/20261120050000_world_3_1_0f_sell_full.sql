update public.world_patch_notes set body = body || $N$
- 판매 한도가 다 찬 뒤에도 상점 「판매하기」 단추가 꺼지지 않고 확인 창을 거쳐 팔 수 있습니다(서버는 이미 받았는데 화면 단추가 꺼져 있었습니다).$N$
 where note_id = '3.0.0' and position('「판매하기」 단추가 꺼지지 않고' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261120050000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
