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
$a$'travel_arrives_at',c.travel_arrives_at);$a$,
$a$'travel_arrives_at',c.travel_arrives_at,'favs',public.world_mount_favs());$a$
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

update public.world_patch_notes set body = body || E'\n- [탈것] 가진 탈것에 별(즐겨찾기)을 달 수 있습니다. 별을 단 탈것은 이동 화면과 마구간의 탈것 목록에서 타는 탈것 바로 아래, 맨 위쪽에 먼저 보입니다.\n- [대장간] 같은 장비를 여러 개 한 번에 분해할 수 있습니다(대장간 「분해」·물품 정보 창에서 수량을 정함). 장착 중인 것과 잠가 지키는 몫은 빼고, 가진 만큼까지 고를 수 있습니다.\n- [수리] 「수리 도구로 모두 고치기」가 생겼습니다(가방 › 장비·대장간 › 수리). 장착 중인 것부터, 많이 닳은 것부터 장비 하나에 수리 도구 하나씩 쓰며 어디서나 쓸 수 있습니다.\n- [노정패] 상태판·이동 화면·마구간에 노정패가 「지금 수 / 1,000」으로 보입니다. 다 차면 숫자가 노란색으로 바뀝니다.\n- [거래] 바깥에서 직접 거래 제안 알림을 닫으면 다시 받을 길이 없던 것을 고쳤습니다. 지난 알림의 「받은 거래 보기」로 언제든 다시 열어 수락·거절할 수 있습니다.'
where note_id = '3.8.0' and position('[탈것] 가진 탈것에 별' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261128050000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
