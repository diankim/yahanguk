-- 채팅 얼굴(2026-10-28): 채팅 줄 앞에 보낸 사람의 프로필 사진 또는 문장(문양·색)을 보인다.
--   캐릭터 표는 본인 행만 읽을 수 있으므로, 공개 프로필 중 얼굴에 쓰는 값(avatar·emblem·color)만 돌려준다(테두리 등 꾸미기는 채팅에 보이지 않는다).
--   화면은 처음 보는 사람만 한 번에 묻고 기억해 둔다(chat.js).
grant fn_owner_field to postgres with inherit true, set true;

create or replace function public.world_chat_faces(p_ids uuid[])
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce(jsonb_object_agg(c.owner_id::text, jsonb_strip_nulls(jsonb_build_object(
      'avatar', c.profile ->> 'avatar', 'emblem', c.profile ->> 'emblem', 'color', c.profile ->> 'color'))), '{}'::jsonb)
  from public.world_characters c
  where public.fn_owner_auth_uid() is not null
    and c.owner_id = any (p_ids[1:60]);
$$;
alter function public.world_chat_faces(uuid[]) owner to fn_owner_field;
revoke all on function public.world_chat_faces(uuid[]) from public, anon, authenticated;
grant execute on function public.world_chat_faces(uuid[]) to authenticated;

grant fn_owner_field to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028240000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
