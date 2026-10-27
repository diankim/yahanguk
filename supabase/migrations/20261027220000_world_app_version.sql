-- 앱 버전: SQL 변경을 적용할 때마다 db_version 값을 올리면, 접속 중인 화면(version.js)이 알아채고 새로고침을 안내한다.
-- (이 파일은 이미 적용했다. 앞으로의 마이그레이션은 끝에 아래 「버전 올리기」 한 줄을 넣는다.)
create table if not exists public.world_app_meta (
  key text primary key,
  value text not null,
  changed_at timestamptz not null default now()
);
alter table public.world_app_meta enable row level security;
revoke all on public.world_app_meta from anon, authenticated;
insert into public.world_app_meta(key, value) values ('db_version', '20261027210000') on conflict (key) do nothing;

create or replace function public.world_app_version()
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select jsonb_build_object('db_version', (select value from public.world_app_meta where key = 'db_version'),
                            'changed_at', (select changed_at from public.world_app_meta where key = 'db_version'))
$$;
alter function public.world_app_version() owner to fn_owner_field;
grant select on public.world_app_meta to fn_owner_field;
revoke all on function public.world_app_version() from public;
grant execute on function public.world_app_version() to anon, authenticated;

-- 버전 올리기(앞으로 각 마이그레이션 끝에 파일 이름의 시각으로):
-- insert into public.world_app_meta(key, value, changed_at) values ('db_version', 'YYYYMMDDHHMMSS', now())
--   on conflict (key) do update set value = excluded.value, changed_at = now();
