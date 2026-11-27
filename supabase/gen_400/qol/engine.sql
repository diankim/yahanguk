create table if not exists public.world_mount_favorites (
  owner_id uuid not null references auth.users(id) on delete cascade,
  mount_id text not null references public.world_mount_catalog(mount_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, mount_id)
);
alter table public.world_mount_favorites enable row level security;
revoke all on public.world_mount_favorites from public, anon, authenticated;
create index if not exists idx_world_mount_favorites_mount on public.world_mount_favorites(mount_id);

create or replace function public.world_mount_favs() returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  if public.fn_owner_auth_uid() is null then raise exception '로그인이 필요합니다.'; end if;
  return coalesce((select jsonb_agg(mount_id order by created_at) from public.world_mount_favorites where owner_id = public.fn_owner_auth_uid()), '[]'::jsonb);
end $f$;
revoke all on function public.world_mount_favs() from public, anon;
grant execute on function public.world_mount_favs() to authenticated;

create or replace function public.world_mount_fav_toggle(p_mount text) returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); added boolean := false;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh-mount-fav'), hashtext(uid::text));
  if exists (select 1 from public.world_mount_favorites where owner_id = uid and mount_id = p_mount) then
    delete from public.world_mount_favorites where owner_id = uid and mount_id = p_mount;
  else
    if not exists (select 1 from public.world_owned_mounts where owner_id = uid and mount_id = p_mount) then raise exception '가진 탈것만 즐겨찾기에 넣을 수 있습니다.'; end if;
    insert into public.world_mount_favorites(owner_id, mount_id) values (uid, p_mount);
    added := true;
  end if;
  return jsonb_build_object('on', added, 'favs', public.world_mount_favs());
end $f$;
revoke all on function public.world_mount_fav_toggle(text) from public, anon;
grant execute on function public.world_mount_fav_toggle(text) to authenticated;

select pg_temp.yh_fix('world_mount_snapshot()', array[
$a$'terr_realm',public.world_terr_realms());$a$,
$a$'terr_realm',public.world_terr_realms(),'favs',public.world_mount_favs());$a$
]);

select pg_temp.yh_fix('world_character_purge(uuid)', array[
$a$  delete from public.world_craft_favorites where owner_id = p_uid;$a$,
$a$  delete from public.world_craft_favorites where owner_id = p_uid;
  delete from public.world_mount_favorites where owner_id = p_uid;$a$
]);

create or replace function public.world_dismantle_batch(p_item_id text, p_times integer) returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); n int; i int; r jsonb; last jsonb; done int := 0; why text; sxp int := 0;
  got jsonb := '{}'::jsonb; k text; v int; parts text[] := '{}'; nm text; no_y int := 0;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  n := least(greatest(coalesce(p_times, 1), 1), 999);
  if n = 1 then return public.world_dismantle_item(p_item_id); end if;
  for i in 1 .. n loop
    begin
      r := public.world_dismantle_item(p_item_id);
    exception when others then
      why := sqlerrm; exit;
    end;
    done := done + 1; last := r;
    sxp := sxp + coalesce((r ->> 'skill_xp')::int, 0);
    if coalesce((r ->> 'no_yield')::boolean, false) then no_y := no_y + 1; end if;
    for k, v in select key, value::text::int from jsonb_each(coalesce(r -> 'yield', '{}'::jsonb)) loop
      got := got || jsonb_build_object(k, coalesce((got ->> k)::int, 0) + v);
    end loop;
  end loop;
  if done = 0 then raise exception '%', coalesce(why, '분해하지 못했습니다.'); end if;
  for k, v in select key, value::text::int from jsonb_each(got) loop
    select item_name into nm from public.world_item_catalog where item_id = k;
    parts := parts || (coalesce(nm, k) || ' ×' || v);
  end loop;
  select item_name into nm from public.world_item_catalog where item_id = p_item_id;
  return (last - 'content') || jsonb_build_object(
    'content', nm || ' ' || done || '개를 분해했습니다'
      || case when parts <> '{}' then ' · ' || array_to_string(parts, ' · ') || '을(를) 얻었습니다' else ' · 재료는 돌려받지 못했습니다' end
      || ' · ' || (last ->> 'line_name') || ' 경험 +' || sxp
      || case when done < n then ' · ' || n || '개 가운데 ' || done || '개에서 멈춤(' || coalesce(why, '') || ')' else '' end,
    'done', done, 'asked', n, 'yield', got, 'skill_xp', sxp, 'stopped', why);
end $f$;
revoke all on function public.world_dismantle_batch(text, integer) from public, anon;
grant execute on function public.world_dismantle_batch(text, integer) to authenticated;

create or replace function public.world_equipment_repair_kit_all() returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); q jsonb; x jsonb; r jsonb; done int := 0; used int := 0; why text; nm text[] := '{}'; left_n int := 0;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  q := public.world_repair_quote();
  if jsonb_array_length(coalesce(q -> 'items', '[]'::jsonb)) = 0 then raise exception '고칠 장비가 없습니다.'; end if;
  for x in select value from jsonb_array_elements(q -> 'items')
    order by coalesce((value ->> 'equipped')::boolean, false) desc, (value ->> 'durability')::numeric / greatest(1, (value ->> 'max')::numeric) loop
    begin
      r := public.world_equipment_repair(x ->> 'item_id', 'kit');
    exception when others then
      why := sqlerrm; exit;
    end;
    done := done + 1; nm := nm || (coalesce(x ->> 'name', x ->> 'item_id') || ' ' || (r ->> 'durability') || '/' || (r ->> 'max'));
  end loop;
  if done = 0 then raise exception '%', coalesce(why, '수리하지 못했습니다.'); end if;
  left_n := jsonb_array_length(q -> 'items') - done;
  return jsonb_build_object('ok', true, 'done', done, 'left', left_n, 'stopped', why,
    'content', '수리 도구 ' || done || '개로 장비를 손봤습니다 · ' || array_to_string(nm, ' · ')
      || case when left_n > 0 then ' · ' || left_n || '개는 손보지 못함(' || coalesce(why, '') || ')' else '' end);
end $f$;
revoke all on function public.world_equipment_repair_kit_all() from public, anon;
grant execute on function public.world_equipment_repair_kit_all() to authenticated;
