lock table public.world_characters in access exclusive mode;

create table if not exists public.world_avatars (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  look jsonb not null default '{}'::jsonb,
  home_on boolean not null default true,
  updated_at timestamptz not null default now()
);
create table if not exists public.world_wardrobe (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  look_key text not null,
  got_at timestamptz not null default now(),
  primary key (owner_id, look_key)
);
alter table public.world_avatars enable row level security;
alter table public.world_wardrobe enable row level security;
revoke all on public.world_avatars from public, anon, authenticated;
revoke all on public.world_wardrobe from public, anon, authenticated;

create or replace function public.world_avatar_parts()
 returns jsonb language sql immutable
as $f$ select '@PARTS@'::jsonb $f$;

create or replace function public.world_avatar_get(p_owner uuid default null)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); who uuid; jk text; a public.world_avatars%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  who := coalesce(p_owner, uid);
  select c.job_key into jk from public.world_characters c where c.owner_id = who;
  if not found then raise exception '조사원을 찾을 수 없습니다.'; end if;
  select * into a from public.world_avatars where owner_id = who;
  if who <> uid then
    return jsonb_build_object('look', a.look, 'job', jk, 'home_on', coalesce(a.home_on, true));
  end if;
  return jsonb_build_object('look', a.look, 'job', jk, 'home_on', coalesce(a.home_on, true),
    'owned', coalesce((select jsonb_agg(w.look_key order by w.look_key) from public.world_wardrobe w where w.owner_id = uid), '[]'::jsonb));
end $f$;

create or replace function public.world_avatar_set(p_look jsonb, p_home_on boolean default null)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); jk text; r jsonb := public.world_avatar_parts(); k text; t text; v text; look jsonb := '{}'::jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select c.job_key into jk from public.world_characters c where c.owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if jsonb_typeof(p_look) is distinct from 'object' then raise exception '모습을 고르세요.'; end if;
  for k, t in select * from (values ('skin', 'skins'), ('hair', 'hair'), ('hair_color', 'hairColors'), ('eyes', 'eyes'), ('eye_color', 'eyeColors'), ('mouth', 'mouth')) x(k, t) loop
    v := p_look ->> k;
    if v is null or not (r -> 'free' -> t ? v) then raise exception '고를 수 없는 모습이 있습니다.'; end if;
    look := look || jsonb_build_object(k, v);
  end loop;
  foreach k in array array['top', 'bottom'] loop
    v := p_look ->> k;
    if v is null or not (r -> 'outfits' ? (k || ':' || v)) then raise exception '고를 수 없는 옷이 있습니다.'; end if;
    if v is distinct from (r -> 'job' -> jk ->> k) and not exists (select 1 from public.world_wardrobe w where w.owner_id = uid and w.look_key = k || ':' || v) then
      raise exception '아직 가지지 않은 옷입니다.'; end if;
    look := look || jsonb_build_object(k, v);
  end loop;
  v := coalesce(p_look ->> 'acc', '');
  if v <> '' and not exists (select 1 from public.world_wardrobe w where w.owner_id = uid and w.look_key = 'acc:' || v) then
    raise exception '아직 가지지 않은 장식입니다.'; end if;
  look := look || jsonb_build_object('acc', v);
  insert into public.world_avatars(owner_id, look, home_on) values (uid, look, coalesce(p_home_on, true))
  on conflict (owner_id) do update set look = excluded.look, home_on = coalesce(p_home_on, public.world_avatars.home_on), updated_at = now();
  return jsonb_build_object('ok', true, 'look', look, 'home_on', (select home_on from public.world_avatars where owner_id = uid));
end $f$;

revoke all on function public.world_avatar_parts() from public, anon, authenticated;
revoke all on function public.world_avatar_get(uuid) from public, anon;
revoke all on function public.world_avatar_set(jsonb, boolean) from public, anon;
grant execute on function public.world_avatar_get(uuid) to authenticated;
grant execute on function public.world_avatar_set(jsonb, boolean) to authenticated;

do $p$
declare d text := pg_get_functiondef('public.world_character_purge(uuid)'::regprocedure);
  a text := 'delete from public.world_quickslots where owner_id = p_uid;';
begin
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '캐릭터 정리 함수 모양이 예상과 다릅니다'; end if;
  if position('world_avatars' in d) = 0 then
    execute replace(d, a, a || E'\n  delete from public.world_avatars where owner_id = p_uid;\n  delete from public.world_wardrobe where owner_id = p_uid;');
  end if;
end $p$;

update public.world_app_meta set value = '20261110000000' where key = 'db_version';
