-- 초대권(롤백 뒤 가입): 서버 정원 60명 = 지금 계정 + 초대권. 토요일(10/31 00:00 KST)에 계정마다 하나씩 서신으로 나눠 주고 남은 것은 비축분.
-- 나눠 준 뒤에는 새 가입에 초대권이 필요하고, 초대권은 롤백이 끝난 때(world_app_meta invite_open_at)부터 7일 동안만 쓸 수 있다.
-- 기존 계정은 초대권 없이 그대로 로그인한다. 초대권 표는 함수로만 읽는다(RLS, 정책 없음).

create table if not exists public.world_invites (
  code text primary key check (code ~ '^[A-Z0-9]{8}$'),
  issued_to uuid,                 -- 받은 계정(없으면 비축분)
  issued_at timestamptz,
  used_by uuid,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists world_invites_used_by on public.world_invites(used_by) where used_by is not null;
create index if not exists world_invites_issued_to on public.world_invites(issued_to);
alter table public.world_invites enable row level security;
revoke all on public.world_invites from public, anon, authenticated;

-- 헷갈리는 글자(0·O·1·I·L)를 뺀 대문자·숫자 8자, 글자와 숫자가 하나씩은 들어간다
create or replace function public.world_invite_make(p_n int)
returns int language plpgsql security definer set search_path = pg_catalog, public as $f$
declare abc text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; c text; made int := 0; tries int := 0;
begin
  while made < greatest(0, p_n) and tries < p_n * 50 loop
    tries := tries + 1;
    c := '';
    for i in 1..8 loop c := c || substr(abc, 1 + floor(random() * length(abc))::int, 1); end loop;
    continue when c !~ '[A-Z]' or c !~ '[0-9]';
    insert into public.world_invites(code) values (c) on conflict do nothing;
    if found then made := made + 1; end if;
  end loop;
  return made;
end $f$;

-- 초대권을 쓸 수 있는 때: 롤백이 끝난 때부터 7일
create or replace function public.world_invite_window()
returns table(open_at timestamptz, close_at timestamptz) language sql stable security definer set search_path = pg_catalog, public as $f$
  select v, v + interval '7 days' from (select (select value from public.world_app_meta where key = 'invite_open_at')::timestamptz v) x
$f$;

-- 나눠 주기(한 번만): 60 − 계정 수만큼 만들고, 계정마다 하나씩(가입 순) 서신·알림으로 보낸다. 남은 것은 비축분.
create or replace function public.world_invite_distribute()
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare total int; accts int; made int; gm uuid; r record; given int := 0; cd text;
begin
  if exists (select 1 from public.world_app_meta where key = 'invite_required') then
    return jsonb_build_object('ok', false, 'reason', 'already');
  end if;
  select count(*) into accts from auth.users;
  total := greatest(0, 60 - accts);
  made := public.world_invite_make(total - (select count(*)::int from public.world_invites));
  gm := (select owner_id from public.world_staff limit 1);
  for r in select u.id from auth.users u order by u.created_at loop
    select code into cd from public.world_invites where issued_to is null and used_by is null order by created_at, code limit 1 for update skip locked;
    exit when cd is null;
    update public.world_invites set issued_to = r.id, issued_at = now() where code = cd;
    given := given + 1;
    insert into public.world_letters(recipient_id, sender_id, sender_name, title, body, pinned)
    values (r.id, coalesce(gm, r.id), '정청', '초대권 한 장',
      '정청에서 초대권 한 장을 보냅니다.' || E'\n\n' ||
      '초대권 번호: ' || cd || E'\n\n' ||
      '이 번호를 꼭 따로 적어 두세요. 11월 2일(월) 0시부터 점검하는 동안에는 게임에 들어올 수 없어 이 서신을 볼 수 없습니다.' || E'\n' ||
      '· 초대권은 서버를 다시 연 때부터 7일 동안, 새로 가입하는 사람이 회원가입 화면에 적어 씁니다. 함께할 사람에게 건네세요.' || E'\n' ||
      '· 이미 계정이 있는 분은 초대권 없이 그대로 로그인합니다.' || E'\n' ||
      '· 한 장으로 한 사람만 가입할 수 있습니다. 다시 연 뒤에는 설정 › 계정에서 다시 볼 수 있습니다.', true);
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.id, 'letter', '초대권이 왔습니다', '정청에서 초대권 한 장을 서신으로 보냈습니다. 번호를 따로 적어 두세요.', jsonb_build_object('invite', true));
  end loop;
  insert into public.world_app_meta(key, value, changed_at) values ('invite_required', '1', now())
    on conflict (key) do update set value = '1', changed_at = now();
  begin perform cron.unschedule('yh-invite-day'); exception when others then null; end;
  return jsonb_build_object('ok', true, 'accounts', accts, 'made', made, 'given', given,
    'reserve', (select count(*) from public.world_invites where issued_to is null and used_by is null));
end $f$;

-- 내 초대권(계정 화면·캐릭터 만들기 화면). 캐릭터가 없어도 된다.
create or replace function public.world_invite_mine()
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $f$
declare uid uuid := auth.uid(); w record;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into w from public.world_invite_window();
  return jsonb_build_object('open_at', w.open_at, 'close_at', w.close_at,
    'codes', coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'used', i.used_by is not null,
        'expired', i.used_by is null and w.close_at is not null and now() >= w.close_at) order by i.issued_at, i.code)
      from public.world_invites i where i.issued_to = uid), '[]'::jsonb));
end $f$;

-- 운영진용: 비축분 보기·더 만들기(정원 60을 넘기지 않음)
create or replace function public.world_invite_admin(p_make int default 0)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare uid uuid := auth.uid(); room int;
begin
  if uid is null or not exists (select 1 from public.world_staff where owner_id = uid) then raise exception '운영진만 쓸 수 있습니다.'; end if;
  if coalesce(p_make, 0) > 0 then
    room := 60 - (select count(*)::int from auth.users) - (select count(*)::int from public.world_invites where used_by is null);
    perform public.world_invite_make(least(p_make, greatest(0, room)));
  end if;
  return jsonb_build_object('accounts', (select count(*) from auth.users),
    'reserve', coalesce((select jsonb_agg(code order by created_at, code) from public.world_invites where issued_to is null and used_by is null), '[]'::jsonb),
    'issued', (select count(*) from public.world_invites where issued_to is not null),
    'used', (select count(*) from public.world_invites where used_by is not null));
end $f$;

revoke all on function public.world_invite_make(int) from public, anon, authenticated;
revoke all on function public.world_invite_window() from public, anon, authenticated;
revoke all on function public.world_invite_distribute() from public, anon, authenticated;
revoke all on function public.world_invite_mine() from public, anon;
revoke all on function public.world_invite_admin(int) from public, anon;
grant execute on function public.world_invite_mine() to authenticated;
grant execute on function public.world_invite_admin(int) to authenticated;

-- 가입 훅: 나눠 준 뒤(invite_required)에는 초대권이 있어야 가입한다(쓰였는지·기한은 여기서 보고, 실제로 쓰는 것은 아래 트리거)
create or replace function public.world_hook_before_user_created(event jsonb)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare v_email text := lower(coalesce(event -> 'user' ->> 'email', '')); v_local text; v_dom text;
  v_code text := upper(regexp_replace(coalesce(event -> 'user' -> 'user_metadata' ->> 'invite', ''), '[^A-Za-z0-9]', '', 'g'));
  v_open timestamptz; i record;
begin
  if coalesce(event -> 'user' -> 'app_metadata' ->> 'provider', 'email') <> 'email' then
    return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '아이디로만 가입할 수 있습니다.'));
  end if;
  v_local := split_part(v_email, '@', 1); v_dom := split_part(v_email, '@', 2);
  if v_dom <> 'yahanguk.invalid' or v_local !~ '^[a-z0-9]{4,16}$' then
    return jsonb_build_object('error', jsonb_build_object('http_code', 400, 'message', '아이디는 영문 소문자와 숫자 4~16자로 정하세요.'));
  end if;
  if exists (select 1 from public.world_app_meta where key = 'invite_required') then
    v_open := (select value from public.world_app_meta where key = 'invite_open_at')::timestamptz;
    if v_open is null or now() < v_open then
      return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '지금은 새로 가입할 수 없습니다. 서버를 다시 연 뒤 초대권으로 가입하세요.'));
    end if;
    if v_code = '' then
      return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '초대권 번호를 적어 주세요.'));
    end if;
    select * into i from public.world_invites where code = v_code;
    if not found then
      return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '없는 초대권 번호입니다. 다시 확인해 주세요.'));
    end if;
    if i.used_by is not null then
      return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '이미 쓰인 초대권입니다.'));
    end if;
    if now() >= v_open + interval '7 days' then
      return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '초대권 기한(서버를 다시 연 때부터 7일)이 지났습니다.'));
    end if;
  end if;
  return '{}'::jsonb;
end $function$;

-- 계정이 만들어질 때 초대권을 쓴 것으로 남긴다(동시에 같은 번호로 가입하면 뒤의 것은 실패)
create or replace function public.world_invite_on_user()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $f$
declare v_code text;
begin
  if not exists (select 1 from public.world_app_meta where key = 'invite_required') then return new; end if;
  v_code := upper(regexp_replace(coalesce(new.raw_user_meta_data ->> 'invite', ''), '[^A-Za-z0-9]', '', 'g'));
  update public.world_invites set used_by = new.id, used_at = now() where code = v_code and used_by is null;
  if not found then raise exception '초대권을 쓸 수 없습니다. 번호를 다시 확인해 주세요.'; end if;
  return new;
end $f$;
revoke all on function public.world_invite_on_user() from public, anon, authenticated;
drop trigger if exists on_auth_user_invite on auth.users;
create trigger on_auth_user_invite after insert on auth.users for each row execute function public.world_invite_on_user();

-- 토요일 0시(한국 시각)에 한 번 나눠 준다(함수가 끝나면 이 예약을 지운다)
select cron.schedule('yh-invite-day', '0 15 30 10 *', 'select public.world_invite_distribute()');

update public.world_app_meta set value = '20261103090000' where key = 'db_version';
