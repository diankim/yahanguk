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

create or replace function public.world_avatar_room(p_owner uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return (select coalesce(jsonb_agg(jsonb_build_object('id', c.owner_id, 'name', c.character_name, 'job', c.job_key, 'look', a.look) order by c.owner_id = p_owner desc), '[]'::jsonb)
    from public.world_characters c left join public.world_avatars a on a.owner_id = c.owner_id
   where c.owner_id in (p_owner, public.world_housing_mate(p_owner)) and coalesce(a.home_on, true));
end $f$;
revoke all on function public.world_avatar_room(uuid) from public, anon, authenticated;
grant execute on function public.world_avatar_room(uuid) to fn_owner_field;

do $p$
declare d text := pg_get_functiondef((select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'world_housing_snapshot'));
  a text := $q$'drawings', public.world_drawing_room(uid, h.wall),$q$;
begin
  if position('world_avatar_room' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '별채 정보 함수 모양이 예상과 다릅니다'; end if;
  execute replace(d, a, a || $q$ 'avatars', public.world_avatar_room(own),$q$);
end $p$;

create or replace function public.world_avatar_look_of(p_owner uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return (select a.look from public.world_avatars a where a.owner_id = p_owner);
end $f$;
revoke all on function public.world_avatar_look_of(uuid) from public, anon, authenticated;
grant execute on function public.world_avatar_look_of(uuid) to fn_owner_field;

do $p$
declare d text := pg_get_functiondef((select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'world_character_card'));
  a text := $q$'pet', public.world_pet_profile_of(c.owner_id),$q$;
begin
  if position('world_avatar_look_of' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '조사원 카드 함수 모양이 예상과 다릅니다'; end if;
  execute replace(d, a, a || $q$ 'look', public.world_avatar_look_of(c.owner_id),$q$);
end $p$;

create or replace function public.world_set_avatar_px(p_image text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_image is null or length(p_image) > 40000 or p_image !~ '^data:image/png;base64,[A-Za-z0-9+/]+={0,2}$' then raise exception '얼굴 그림 형식이 올바르지 않습니다.'; end if;
  update public.world_characters set profile = coalesce(profile, '{}'::jsonb) || jsonb_build_object('avatar', p_image, 'avatar_px', true), updated_at = now() where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  return jsonb_build_object('ok', true, 'content', '내 모습을 얼굴로 씁니다.');
end $f$;
revoke all on function public.world_set_avatar_px(text) from public, anon;
grant execute on function public.world_set_avatar_px(text) to authenticated;

do $p$
declare d text := pg_get_functiondef((select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'world_set_avatar'));
  a text := $q$coalesce(profile, '{}'::jsonb) - 'avatar'$q$;
  b text := $q$ELSE coalesce(profile, '{}'::jsonb) || jsonb_build_object('avatar', p_image)$q$;
begin
  if position('avatar_px' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 or (length(d) - length(replace(d, b, ''))) / length(b) <> 1 then raise exception '프로필 사진 함수 모양이 예상과 다릅니다'; end if;
  execute replace(replace(d, a, a || $q$ - 'avatar_px'$q$), b, $q$ELSE (coalesce(profile, '{}'::jsonb) - 'avatar_px') || jsonb_build_object('avatar', p_image)$q$);
end $p$;

update public.world_app_meta set value = '20261110000000' where key = 'db_version';
