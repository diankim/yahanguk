-- ── 퀵슬롯(7.5.0): 캐릭터 › 상태 아래 칸에 등록한 회복 물품(8칸). 기기가 달라도 같게 서버에 둔다 ──
create table if not exists public.world_quickslots (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  slots text[] not null default '{}',
  updated_at timestamptz not null default now()
);
alter table public.world_quickslots enable row level security;
revoke all on public.world_quickslots from public, anon, authenticated;

-- 등록한 칸(없으면 null — 화면이 기본 칸을 보인다)
create or replace function public.world_quickslots_get()
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); s text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select q.slots into s from public.world_quickslots q where q.owner_id = uid;
  return jsonb_build_object('slots', case when s is null then null else to_jsonb(s) end);
end $function$;

-- 칸 바꾸기: 8칸까지, 빈칸은 ''. 소모품·재료만(쓸 수 있는지는 world_use_item이 판정). 행동 기록을 남기지 않는다.
create or replace function public.world_quickslots_set(p_slots text[])
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); x text; out text[] := '{}';
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_characters where owner_id = uid) then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(cardinality(p_slots), 0) > 8 then raise exception '퀵슬롯은 8칸까지입니다.'; end if;
  foreach x in array coalesce(p_slots, '{}') loop
    x := coalesce(x, '');
    if x <> '' and not exists (select 1 from public.world_item_catalog i where i.item_id = x and i.category in ('consumable', 'material')) then
      raise exception '퀵슬롯에는 회복 물품만 등록할 수 있습니다.'; end if;
    out := out || x;
  end loop;
  insert into public.world_quickslots(owner_id, slots) values (uid, out)
  on conflict (owner_id) do update set slots = excluded.slots, updated_at = now();
  return jsonb_build_object('ok', true, 'slots', to_jsonb(out));
end $function$;
revoke all on function public.world_quickslots_get() from public, anon;
revoke all on function public.world_quickslots_set(text[]) from public, anon;
grant execute on function public.world_quickslots_get() to authenticated;
grant execute on function public.world_quickslots_set(text[]) to authenticated;
