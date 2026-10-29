-- 6.1.7 서버 부담 정리: 가방 정보(world_inventory_snapshot)는 한 번에 약 220KB인데 그 가운데 물품 목록(약 131KB)·제작법(약 87KB)은
-- 배포 전까지 바뀌지 않는다. 화면은 접속할 때 한 번만 전체를 받고, 그 뒤 행동마다는 캐릭터마다 바뀌는 몫(약 1.4KB)만 받는다.
-- world_inventory_state = world_inventory_snapshot에서 catalog·recipes를 뺀 것(같은 권한: 부른 사람 권한, RLS 그대로).
create or replace function public.world_inventory_state()
returns jsonb language plpgsql set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; eq jsonb; exp jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터가 없습니다.'; end if;
  select coalesce(jsonb_object_agg(slot, item_id), '{}'::jsonb) into eq from public.world_character_equipment where owner_id = uid;
  select jsonb_build_object('in_progress', in_progress, 'supplies', supplies, 'started_at', started_at) into exp from public.world_expedition_state where owner_id = uid;
  return jsonb_build_object('inventory', coalesce(c.inventory, '{}'::jsonb), 'equipment', eq, 'location', c.location, 'level', c.level, 'job_key', c.job_key,
    'crafting_profession', c.crafting_profession, 'gathering_profession', c.gathering_profession, 'crafting_rank', c.crafting_rank, 'gathering_rank', c.gathering_rank,
    'crafting_xp', c.crafting_xp, 'gathering_xp', c.gathering_xp, 'crafting_quality', c.crafting_quality,
    'expedition_state', coalesce(exp, jsonb_build_object('in_progress', false, 'supplies', jsonb_build_object())));
end $function$;
revoke all on function public.world_inventory_state() from public, anon;
grant execute on function public.world_inventory_state() to authenticated;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261031040000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
