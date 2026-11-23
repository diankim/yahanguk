do $$ begin
  if (select count(*) from public.world_patch_notes where note_id = '3.8.0' and position(' 기기의 「동작 줄이기」를 켜면 나오지 않습니다.' in body) > 0) <> 1 then raise exception '패치노트 문장 없음'; end if;
  update public.world_patch_notes set body = replace(body, ' 기기의 「동작 줄이기」를 켜면 나오지 않습니다.', '') where note_id = '3.8.0';
end $$;
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127020000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
