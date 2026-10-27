-- 채팅 이름 색(2026-10-28): 조사원이 자기 이름 색을 고른다(색상환 각도 0~359, 비우면 이름에 따라 정해지는 자동 색).
--   profile.chat_hue에 두고, 보낼 때 서버가 메시지에 찍는다(world_chat_messages·world_circle_messages.sender_color).
--   파티 채팅은 world_party_chat_snapshot이 캐릭터에서 함께 읽는다. 화면 색은 테마에 맞춰 밝기만 바꾼다(chat.js msgRow).
-- 대화 기록 보관은 5일 → 3일(채팅·귓속말·모임·파티 채팅).
grant fn_owner_field to postgres with inherit true, set true;

alter table public.world_chat_messages add column if not exists sender_color smallint;
alter table public.world_circle_messages add column if not exists sender_color smallint;
revoke all (sender_color) on public.world_chat_messages from anon;
revoke all (sender_color) on public.world_circle_messages from anon;
grant select (sender_color) on public.world_chat_messages to authenticated, fn_owner_field;
grant select (sender_color) on public.world_circle_messages to authenticated;
grant select, insert (sender_color) on public.world_circle_messages to fn_owner_field;

create or replace function public.world_set_chat_hue(p_hue integer)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_hue is not null and (p_hue < 0 or p_hue > 359) then raise exception '고를 수 없는 색입니다.'; end if;
  update public.world_characters
     set profile = case when p_hue is null then coalesce(profile, '{}'::jsonb) - 'chat_hue'
                        else jsonb_set(coalesce(profile, '{}'::jsonb), '{chat_hue}', to_jsonb(p_hue)) end
   where owner_id = uid;
  if not found then raise exception '캐릭터가 없습니다.'; end if;
  return jsonb_build_object('ok', true, 'hue', p_hue);
end $$;
alter function public.world_set_chat_hue(integer) owner to fn_owner_field;
revoke all on function public.world_set_chat_hue(integer) from public, anon, authenticated;
grant execute on function public.world_set_chat_hue(integer) to authenticated;

-- 전체·지역·세력 채팅과 귓속말: 칭호와 함께 이름 색을 찍는다
create or replace function public.world_chat_stamp_title()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
BEGIN
  new.sender_title := (SELECT tc.title_name FROM public.world_characters c
    JOIN public.world_character_titles ct ON ct.owner_id = c.owner_id AND ct.title_key = c.profile ->> 'title'
    JOIN public.world_title_catalog tc ON tc.title_key = ct.title_key
    WHERE c.owner_id = new.sender_id);
  new.sender_color := (SELECT CASE WHEN jsonb_typeof(c.profile -> 'chat_hue') = 'number' THEN (c.profile ->> 'chat_hue')::numeric::smallint END
    FROM public.world_characters c WHERE c.owner_id = new.sender_id);
  RETURN new;
END $function$;

create or replace function public.world_circle_send(p_circle uuid, p_content text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; clean text := btrim(coalesce(p_content, '')); mid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if char_length(clean) < 1 or char_length(clean) > 300 then raise exception '메시지는 1~300자로 입력해 주세요.'; end if;
  if public.world_circle_role(p_circle, uid) is null then raise exception '이 모임에 들어 있지 않습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if exists (select 1 from public.world_circle_messages where sender_id = uid and created_at > now() - interval '2 seconds') then raise exception '메시지를 너무 빠르게 보내고 있어요. 잠시 기다려 주세요.'; end if;
  insert into public.world_circle_messages(circle_id, sender_id, sender_name, sender_title, sender_color, content)
  values (p_circle, uid, c.character_name, c.profile ->> 'title_name',
          case when jsonb_typeof(c.profile -> 'chat_hue') = 'number' then (c.profile ->> 'chat_hue')::numeric::smallint end, clean) returning id into mid;
  update public.world_circle_members set last_read_at = now() where circle_id = p_circle and owner_id = uid;
  -- 오래된 말은 매일 world_housekeeping이 지운다(3일)
  return jsonb_build_object('ok', true, 'id', mid);
end $function$;

create or replace function public.world_party_chat_snapshot()
returns jsonb language plpgsql set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid:=public.fn_owner_auth_uid(); pid uuid;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select party_id into pid from public.world_party_members where owner_id=uid;
 if pid is null then return jsonb_build_object('party_id',null,'messages','[]'::jsonb); end if;
 return jsonb_build_object('party_id',pid,'messages',(select coalesce(jsonb_agg(jsonb_build_object('message_id',m.message_id,'sender_id',m.sender_id,'sender_name',c.character_name,
   'sender_color',case when jsonb_typeof(c.profile -> 'chat_hue') = 'number' then (c.profile ->> 'chat_hue')::numeric::int end,
   'content',m.content,'created_at',m.created_at) order by m.created_at),'[]'::jsonb) from (select * from public.world_party_messages where party_id=pid order by created_at desc limit 80) m left join public.world_characters c on c.owner_id=m.sender_id));
end $function$;

-- 대화 기록 3일
create or replace function public.world_housekeeping()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare a int; b int; c int; t int; m int; p int;
begin
  delete from public.world_notifications where read_at is not null and read_at < now() - interval '14 days';
  get diagnostics a = row_count;
  delete from public.world_chat_messages where created_at < now() - interval '3 days';
  get diagnostics b = row_count;
  delete from public.world_circle_messages where created_at < now() - interval '3 days';
  get diagnostics m = row_count;
  delete from public.world_party_messages where created_at < now() - interval '3 days';
  get diagnostics p = row_count;
  delete from public.world_economy_ledger where created_at < now() - interval '60 days';
  get diagnostics c = row_count;
  delete from public.world_hidden_trails where expires_at < now() - interval '1 day';
  get diagnostics t = row_count;
  return jsonb_build_object('notifications', a, 'chat', b, 'circle', m, 'party', p, 'ledger', c, 'trails', t);
end $$;
revoke all on function public.world_housekeeping() from public, anon, authenticated;

-- 지금 한 번 정리한다(3일 지난 대화가 바로 사라진다)
select public.world_housekeeping();

grant fn_owner_field to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028220000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
