-- 아이디 가입(Supabase Auth "Before User Created" 훅)
--
-- 화면에서 아이디(영문 소문자·숫자 4~16자)를 받아 내부 주소 "<아이디>@yahanguk.invalid"로 바꿔 가입·로그인한다.
--   · 이 주소로는 메일을 보내지 않는다(이메일 확인 끔). 사용자에게는 아이디만 보인다.
--   · 훅이 이 형식이 아닌 가입(실제 이메일 등)을 거절해, 모든 계정이 아이디 형식이 되게 한다.
-- 같은 IP 가입 제한은 두지 않는다(운영 결정). 이 파일의 앞선 판에서 만든 IP 기록 표·함수가 있으면 지운다.
--
-- 실행 뒤 대시보드에서 직접 켜야 한다: Authentication → Hooks → Before User Created → Postgres → public.world_hook_before_user_created
-- (Authentication → Sign In / Providers → Email 은 켜 두고, "Confirm email"만 끈다. Email 공급자를 끄면 비밀번호 로그인 자체가 막힌다.)

drop function if exists public.world_signup_allow_ip(text, text);
drop function if exists public.world_signup_ip_release(uuid);
drop function if exists public.world_ip_hash(text);
drop table if exists public.world_signup_ips;
drop table if exists public.world_signup_ip_allow;
drop table if exists public.world_private_settings; -- IP 비밀값만 담던 표

create or replace function public.world_hook_before_user_created(event jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(coalesce(event -> 'user' ->> 'email', '')); v_local text; v_dom text;
begin
  if coalesce(event -> 'user' -> 'app_metadata' ->> 'provider', 'email') <> 'email' then
    return jsonb_build_object('error', jsonb_build_object('http_code', 403, 'message', '아이디로만 가입할 수 있습니다.'));
  end if;
  v_local := split_part(v_email, '@', 1); v_dom := split_part(v_email, '@', 2);
  if v_dom <> 'yahanguk.invalid' or v_local !~ '^[a-z0-9]{4,16}$' then
    return jsonb_build_object('error', jsonb_build_object('http_code', 400, 'message', '아이디는 영문 소문자와 숫자 4~16자로 정하세요.'));
  end if;
  return '{}'::jsonb;
end $$;
revoke all on function public.world_hook_before_user_created(jsonb) from public, anon, authenticated;
grant execute on function public.world_hook_before_user_created(jsonb) to supabase_auth_admin;

select 'ok' as result, has_function_privilege('supabase_auth_admin', 'public.world_hook_before_user_created(jsonb)', 'execute') as auth_can_call,
  has_function_privilege('anon', 'public.world_hook_before_user_created(jsonb)', 'execute') as anon_can_call;
