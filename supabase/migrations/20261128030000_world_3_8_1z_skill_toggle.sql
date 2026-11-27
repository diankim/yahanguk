create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create table if not exists public.world_skill_toggles (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  off text[] not null default '{}',
  changed_at timestamptz not null default now()
);
alter table public.world_skill_toggles enable row level security;
revoke all on public.world_skill_toggles from public, anon, authenticated;

create or replace function public.world_skill_toggle(p_skill text, p_on boolean) returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); t public.world_skill_toggles%rowtype; nx text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_skill_catalog where skill_id = p_skill and slot = 'combo') then raise exception '조합 기술만 켜고 끌 수 있습니다.'; end if;
  insert into public.world_skill_toggles(owner_id, changed_at) values (uid, now() - interval '1 minute') on conflict (owner_id) do nothing;
  select * into t from public.world_skill_toggles where owner_id = uid for update;
  if t.changed_at > now() - interval '1 second' then raise exception '조금 뒤에 다시 바꿔 주세요.' using hint = 'rate'; end if;
  nx := array_remove(t.off, p_skill);
  if not coalesce(p_on, true) then nx := nx || p_skill; end if;
  update public.world_skill_toggles set off = nx, changed_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'on', coalesce(p_on, true), 'off', to_jsonb(nx));
end $f$;
revoke all on function public.world_skill_toggle(text, boolean) from public, anon;
grant execute on function public.world_skill_toggle(text, boolean) to authenticated;

create or replace function public.world_skill_off_mine() returns text[] language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  return coalesce((select off from public.world_skill_toggles where owner_id = public.fn_owner_auth_uid()), '{}');
end $f$;
revoke all on function public.world_skill_off_mine() from public, anon;
grant execute on function public.world_skill_off_mine() to authenticated;

select pg_temp.yh_fix('world_skill_procs(uuid)', array[
$a$         and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires)) q$a$,
$a$         and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires)
         and not exists (select 1 from public.world_skill_toggles tg where tg.owner_id = c.owner_id and sk.skill_id = any (tg.off))) q$a$
]);

select pg_temp.yh_fix('world_skill_owned(uuid)', array[
$a$     and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires)
  ) yhq limit 1);$a$,
$a$     and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires)
     and not exists (select 1 from public.world_skill_toggles tg where tg.owner_id = c.owner_id and sk.skill_id = any (tg.off))
  ) yhq limit 1);$a$
]);

select pg_temp.yh_fix('world_skill_snapshot', array[
$a$declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; out jsonb; pk jsonb; fr text[];$a$,
$a$declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; out jsonb; pk jsonb; fr text[]; offs text[];$a$,
$a$  pk := coalesce(pk, '{}'::jsonb); fr := coalesce(fr, '{}');$a$,
$a$  pk := coalesce(pk, '{}'::jsonb); fr := coalesce(fr, '{}');
  offs := public.world_skill_off_mine();$a$,
$a$      'unlocked', public.world_skill_has(c.skill_progress, pk, s.category, s.unlock_rank, s.slot, s.requires))$a$,
$a$      'unlocked', public.world_skill_has(c.skill_progress, pk, s.category, s.unlock_rank, s.slot, s.requires),
      'off', case when s.slot = 'combo' then s.skill_id = any (offs) end)$a$
]);

select pg_temp.yh_fix('world_character_purge(uuid)', array[
$a$  delete from public.world_skill_picks where owner_id = p_uid;$a$,
$a$  delete from public.world_skill_picks where owner_id = p_uid;
  delete from public.world_skill_toggles where owner_id = p_uid;$a$
]);

update public.world_patch_notes set body = body || E'\n- [기술] 익힌 조합 기술을 하나씩 끄고 켤 수 있습니다(캐릭터 › 기술 › 조합 기술). 끈 조합 기술은 다시 켤 때까지 저절로 걸리지 않습니다.\n- [상태] 상태이상 설명에 행동마다 체력·정신이 깎이는 행동을 적었습니다(예: 출혈은 토벌·탐색 때). 상태마다 걸리는 행동은 원래대로입니다.\n- [싸움 화면] 휴대폰에서도 합동 토벌의 요괴에게 걸린 효과가 낌새 줄 오른쪽에 아이콘으로 보입니다. 아이콘을 누르면 이름과 설명이 나옵니다.\n- [캐릭터] 신원 칸 안내 문구를 지금 규칙(직업만 환골탈태 서첩으로 바꿈)에 맞게 고쳤습니다.'
where note_id = '3.8.0' and position('[기술] 익힌 조합 기술을' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261128030000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
