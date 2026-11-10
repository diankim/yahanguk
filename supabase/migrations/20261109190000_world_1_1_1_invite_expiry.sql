alter table public.world_invites add column if not exists expires_at timestamptz;

create or replace function public.world_invite_rules()
 returns jsonb language sql immutable
as $function$
  select '{"cap":60,"days":7}'::jsonb
$function$;
revoke all on function public.world_invite_rules() from public, anon, authenticated;
grant execute on function public.world_invite_rules() to service_role;

create or replace function public.world_invite_close(p_expires timestamptz)
 returns timestamptz
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select coalesce(p_expires, (select close_at from public.world_invite_window()))
$function$;
revoke all on function public.world_invite_close(timestamptz) from public, anon, authenticated;
grant execute on function public.world_invite_close(timestamptz) to service_role;

create or replace function public.world_invite_room()
 returns integer
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select greatest(0, (public.world_invite_rules() ->> 'cap')::int - (select count(*)::int from auth.users)
    - (select count(*)::int from public.world_invites i where i.used_by is null and now() < public.world_invite_close(i.expires_at)))
$function$;
revoke all on function public.world_invite_room() from public, anon, authenticated;
grant execute on function public.world_invite_room() to service_role;

create or replace function public.world_invite_code()
 returns text
 language plpgsql
 volatile
 set search_path to 'pg_catalog', 'public'
as $function$
declare abc text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; c text;
begin
  loop
    c := '';
    for i in 1..8 loop c := c || substr(abc, 1 + floor(random() * length(abc))::int, 1); end loop;
    exit when c ~ '[A-Z]' and c ~ '[0-9]' and not exists (select 1 from public.world_invites where code = c);
  end loop;
  return c;
end $function$;
revoke all on function public.world_invite_code() from public, anon, authenticated;
grant execute on function public.world_invite_code() to service_role;

create or replace function public.world_invite_make(p_n integer)
 returns integer
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare made int := 0;
begin
  while made < greatest(0, p_n) loop
    insert into public.world_invites(code) values (public.world_invite_code()) on conflict do nothing;
    if found then made := made + 1; end if;
  end loop;
  return made;
end $function$;

create or replace function public.world_invite_admin(p_make integer default 0)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := auth.uid();
begin
  if uid is null or not exists (select 1 from public.world_staff where owner_id = uid) then raise exception '운영진만 쓸 수 있습니다.'; end if;
  if coalesce(p_make, 0) > 0 then
    perform public.world_invite_make(least(p_make, public.world_invite_room()));
  end if;
  return jsonb_build_object('accounts', (select count(*) from auth.users), 'room', public.world_invite_room(),
    'reserve', coalesce((select jsonb_agg(code order by created_at, code) from public.world_invites i
      where i.issued_to is null and i.used_by is null and now() < public.world_invite_close(i.expires_at)), '[]'::jsonb),
    'issued', (select count(*) from public.world_invites where issued_to is not null),
    'used', (select count(*) from public.world_invites where used_by is not null),
    'expired', (select count(*) from public.world_invites i where i.used_by is null and now() >= public.world_invite_close(i.expires_at)));
end $function$;

create or replace function public.world_invite_grant(p_to uuid, p_n integer default 1)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := auth.uid(); n int; cds text[] := '{}'; c text; ends timestamptz := now() + make_interval(days => (public.world_invite_rules() ->> 'days')::int);
  stamp text := to_char(ends at time zone 'Asia/Seoul', 'FMMM"월" FMDD"일" HH24:MI');
begin
  if uid is null or not exists (select 1 from public.world_staff where owner_id = uid) then raise exception '운영진만 쓸 수 있습니다.'; end if;
  if not exists (select 1 from auth.users where id = p_to) then raise exception '그런 계정이 없습니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('world_invite_grant'));
  n := least(greatest(0, coalesce(p_n, 1)), public.world_invite_room());
  if n < 1 then raise exception '남은 자리가 없습니다.'; end if;
  for i in 1..n loop
    c := public.world_invite_code();
    insert into public.world_invites(code, issued_to, issued_at, expires_at) values (c, p_to, now(), ends);
    cds := cds || c;
  end loop;
  insert into public.world_letters(recipient_id, sender_id, sender_name, title, body, pinned)
  values (p_to, uid, '정청', '초대권 ' || n || '장',
    '요청하신 초대권을 보냅니다.' || E'\n\n' || '초대권 번호: ' || array_to_string(cds, ', ') || E'\n\n' ||
    '· ' || stamp || '까지(받은 때부터 ' || (public.world_invite_rules() ->> 'days') || '일) 새로 가입하는 사람이 회원가입 화면에 적어 씁니다.' || E'\n' ||
    '· 한 장으로 한 사람만 가입할 수 있습니다. 설정 › 계정의 「내 초대권」에서도 다시 볼 수 있습니다.', true);
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_to, 'letter', '초대권이 왔습니다', '정청에서 초대권 ' || n || '장을 서신으로 보냈습니다. ' || stamp || '까지 쓸 수 있습니다.', jsonb_build_object('invite', true));
  return jsonb_build_object('ok', true, 'codes', to_jsonb(cds), 'expires_at', ends, 'room', public.world_invite_room());
end $function$;
revoke all on function public.world_invite_grant(uuid, integer) from public, anon, authenticated;
grant execute on function public.world_invite_grant(uuid, integer) to service_role;

create or replace function public.world_invite_mine()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := auth.uid(); w record;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into w from public.world_invite_window();
  return jsonb_build_object('open_at', w.open_at, 'close_at', w.close_at,
    'codes', coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'used', i.used_by is not null,
        'until', public.world_invite_close(i.expires_at),
        'expired', i.used_by is null and now() >= public.world_invite_close(i.expires_at)) order by i.issued_at, i.code)
      from public.world_invites i where i.issued_to = uid), '[]'::jsonb));
end $function$;

do $$
declare d text := pg_get_functiondef('public.world_hook_before_user_created(jsonb)'::regprocedure);
  a text := $q$    if now() >= v_open + interval '7 days' then
      return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '초대권 기한(서버를 다시 연 때부터 7일)이 지났습니다.'));$q$;
  b text := $q$    if now() >= public.world_invite_close(i.expires_at) then
      return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '기한이 지난 초대권입니다. 초대권을 건넨 사람에게 새 초대권을 부탁하세요.'));$q$;
begin
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '가입 확인 함수 모양이 예상과 다릅니다'; end if;
  execute replace(d, a, b);
end $$;

update public.world_app_meta set value = '20261109190000' where key = 'db_version';
