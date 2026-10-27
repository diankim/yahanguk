-- 운영진(GM) 표시: 화면이 이 명단을 읽어 이름 옆에 GM 표식을 붙인다. 명단은 로그인 사용자가 읽기만 할 수 있다(쓰기는 SQL Editor에서만).
-- 캐릭터 이름에 "GM"을 넣어도 이 명단에 없으면 표식이 붙지 않아 사칭과 구분된다.
create table if not exists public.world_staff (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  role text not null default 'gm' check (role in ('gm')),
  note text not null default '',
  created_at timestamptz not null default now()
);
alter table public.world_staff enable row level security;
drop policy if exists world_staff_read on public.world_staff;
create policy world_staff_read on public.world_staff for select to authenticated using (true);
revoke all on public.world_staff from anon, authenticated;
grant select on public.world_staff to authenticated;

-- 테스트·운영용 GM 캐릭터(아이디 mu5ician)
insert into public.world_staff(owner_id, role, note)
select c.owner_id, 'gm', '운영 시험용 GM' from public.world_characters c join auth.users u on u.id = c.owner_id
where lower(u.email) = 'mu5ician@yahanguk.invalid'
on conflict (owner_id) do nothing;

select 'ok' as result, (select count(*) from public.world_staff) as staff;
