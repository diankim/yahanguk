-- 아이디 가입 + 같은 IP에서 한 번만 가입(Supabase Auth "Before User Created" 훅)
--
-- 아이디 가입 방식: 화면에서 아이디(영문 소문자·숫자 4~16자)를 받아 내부 주소 "<아이디>@yahanguk.invalid"로 바꿔 가입·로그인한다.
--   · 이 주소로는 메일을 보내지 않는다(이메일 확인 끔). 사용자에게는 아이디만 보인다.
--   · 훅이 이 형식이 아닌 가입(실제 이메일 등)을 거절해, 모든 계정이 아이디 형식이 되게 한다.
-- 같은 IP 제한: 가입 요청의 IP를 비밀값과 섞은 해시로만 저장하고(원래 IP는 남기지 않는다), 같은 해시로 두 번째 가입을 거절한다.
--   · 운영자가 여러 계정을 만들어야 하면 SQL Editor에서 select public.world_signup_allow_ip('IP 주소', '메모'); 로 예외를 둔다.
--   · 계정을 지운 뒤 그 IP로 다시 가입하게 하려면 select public.world_signup_ip_release('사용자 uuid'); 를 실행한다.
--
-- 실행 뒤 대시보드에서 직접 켜야 한다: Authentication → Hooks → Before User Created → Postgres → public.world_hook_before_user_created
-- (Authentication → Sign In / Providers → Email 은 켜 두고, "Confirm email"만 끈다. Email 공급자를 끄면 비밀번호 로그인 자체가 막힌다.)

create table if not exists public.world_private_settings (key text primary key, value text not null);
alter table public.world_private_settings enable row level security;
revoke all on public.world_private_settings from public, anon, authenticated;
insert into public.world_private_settings(key, value) values ('signup_ip_salt', encode(extensions.gen_random_bytes(32), 'hex')) on conflict (key) do nothing;

create table if not exists public.world_signup_ips (
  ip_hash text primary key,
  user_id uuid,
  created_at timestamptz not null default now()
);
create table if not exists public.world_signup_ip_allow (
  ip_hash text primary key,
  note text not null default '',
  created_at timestamptz not null default now()
);
alter table public.world_signup_ips enable row level security;
alter table public.world_signup_ip_allow enable row level security;
revoke all on public.world_signup_ips, public.world_signup_ip_allow from public, anon, authenticated;

create or replace function public.world_ip_hash(p_ip text) returns text
language sql stable security definer set search_path = '' as $$
  select encode(extensions.digest(coalesce(p_ip, '') || ':' || (select value from public.world_private_settings where key = 'signup_ip_salt'), 'sha256'), 'hex')
$$;
revoke all on function public.world_ip_hash(text) from public, anon, authenticated;

-- 가입 직전 검사(Supabase Auth가 supabase_auth_admin으로 부른다)
create or replace function public.world_hook_before_user_created(event jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(coalesce(event -> 'user' ->> 'email', '')); v_local text; v_dom text;
  v_ip text := event -> 'metadata' ->> 'ip_address'; v_hash text;
begin
  if coalesce(event -> 'user' -> 'app_metadata' ->> 'provider', 'email') <> 'email' then
    return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '아이디로만 가입할 수 있습니다.'));
  end if;
  v_local := split_part(v_email, '@', 1); v_dom := split_part(v_email, '@', 2);
  if v_dom <> 'yahanguk.invalid' or v_local !~ '^[a-z0-9]{4,16}$' then
    return jsonb_build_object('error', jsonb_build_object('http_code', 400, 'message', '아이디는 영문 소문자와 숫자 4~16자로 정하세요.'));
  end if;
  -- 이미 있는 아이디면 IP를 쓰지 않고 그대로 넘겨 "이미 쓰이는 아이디" 오류가 나게 한다
  if exists (select 1 from auth.users u where lower(u.email) = v_email) then return '{}'::jsonb; end if;
  if v_ip is null or v_ip = '' then return '{}'::jsonb; end if;
  v_hash := public.world_ip_hash(v_ip);
  if exists (select 1 from public.world_signup_ip_allow a where a.ip_hash = v_hash) then return '{}'::jsonb; end if;
  insert into public.world_signup_ips(ip_hash, user_id) values (v_hash, nullif(event -> 'user' ->> 'id', '')::uuid) on conflict (ip_hash) do nothing;
  if not found then
    return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '이 네트워크(IP)에서는 이미 계정을 만들었습니다. 한 곳에서 한 계정만 만들 수 있습니다.'));
  end if;
  return '{}'::jsonb;
end $$;
revoke all on function public.world_hook_before_user_created(jsonb) from public, anon, authenticated;
grant execute on function public.world_hook_before_user_created(jsonb) to supabase_auth_admin;

-- 운영자용(SQL Editor에서만): IP 예외 두기 / 지운 계정의 IP 기록 풀기
create or replace function public.world_signup_allow_ip(p_ip text, p_note text default '') returns text
language sql security definer set search_path = '' as $$
  insert into public.world_signup_ip_allow(ip_hash, note) values (public.world_ip_hash(p_ip), coalesce(p_note, ''))
  on conflict (ip_hash) do update set note = excluded.note
  returning '예외로 두었습니다: ' || note
$$;
create or replace function public.world_signup_ip_release(p_user uuid) returns int
language sql security definer set search_path = '' as $$
  with d as (delete from public.world_signup_ips where user_id = p_user returning 1) select count(*)::int from d
$$;
revoke all on function public.world_signup_allow_ip(text, text), public.world_signup_ip_release(uuid) from public, anon, authenticated;

select 'ok' as result, has_function_privilege('supabase_auth_admin', 'public.world_hook_before_user_created(jsonb)', 'execute') as auth_can_call,
  has_function_privilege('anon', 'public.world_hook_before_user_created(jsonb)', 'execute') as anon_can_call;
