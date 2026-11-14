update public.world_patch_notes set body = body || E'\n- PC 봉연의 그림자·10장 결전·파티 토벌 싸움 화면도 같은 틀로 화면 한 장에 모두 들어옵니다(참가자가 많으면 참가자 칸 안에서 굴려 봄).'
 where note_id = '1.1.0' and position('파티 토벌 싸움 화면도 같은 틀로' in body) = 0;
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261114050000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
