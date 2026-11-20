create or replace function public.world_enhance_cleanup()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
begin
  delete from public.world_gear_enhance g
   where g.owner_id = new.owner_id and coalesce((new.inventory ->> g.item_id)::int, 0) <= 0
     and coalesce((select (s.items ->> g.item_id)::int from public.world_storage s where s.owner_id = g.owner_id), 0) <= 0;
  return new;
end $function$;

create or replace function public.world_enhance_cleanup_store()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
begin
  delete from public.world_gear_enhance g
   where g.owner_id = new.owner_id and coalesce((new.items ->> g.item_id)::int, 0) <= 0
     and coalesce((select (c.inventory ->> g.item_id)::int from public.world_characters c where c.owner_id = g.owner_id), 0) <= 0;
  return new;
end $function$;
revoke all on function public.world_enhance_cleanup_store() from public, anon, authenticated;

drop trigger if exists trg_world_enhance_cleanup_store on public.world_storage;
create trigger trg_world_enhance_cleanup_store after update of items on public.world_storage
 for each row when (new.items is distinct from old.items) execute function public.world_enhance_cleanup_store();

do $p$
declare d text := pg_get_functiondef('public.world_storage_put(text,integer)'::regprocedure);
  a text := E'  if exists (select 1 from public.world_gear_enhance g where g.owner_id = uid and g.item_id = p_item) then keep := greatest(keep, 1); end if;\r\n';
  m1 text := '장착 중이거나 강화한 장비의 마지막 하나는 맡길 수 없습니다.';
  u1 text := E'  update public.world_characters\r\n     set inventory = case when have - n <= 0 then inventory - p_item else jsonb_set(inventory, array[p_item], to_jsonb(have - n)) end,\r\n         updated_at = now()\r\n   where owner_id = uid;\r\n';
  u2 text := E'  update public.world_storage set items = public.world_inv_add(items, p_item, n), updated_at = now() where owner_id = uid;\r\n';
begin
  if position(a in d) = 0 or position(m1 in d) = 0 or position(u1 || u2 in d) = 0 then raise exception '창고 맡기기 고칠 자리를 못 찾음'; end if;
  d := replace(d, a, '');
  d := replace(d, m1, '장착 중인 장비의 마지막 하나는 맡길 수 없습니다.');
  d := replace(d, u1 || u2, u2 || u1);
  execute d;
end $p$;

do $t$
declare d text := pg_get_functiondef('public.world_storage_take(text,integer)'::regprocedure);
  u1 text := E'  update public.world_storage\r\n     set items = case when have - n <= 0 then items - p_item else jsonb_set(items, array[p_item], to_jsonb(have - n)) end, updated_at = now()\r\n   where owner_id = uid;\r\n';
  u2 text := E'  update public.world_characters set inventory = public.world_inv_add(coalesce(inventory, \'{}\'::jsonb), p_item, n), updated_at = now() where owner_id = uid;\r\n';
begin
  if position(u1 || u2 in d) = 0 then raise exception '창고 꺼내기 고칠 자리를 못 찾음'; end if;
  execute replace(d, u1 || u2, u2 || u1);
end $t$;

do $n$ begin
  if (select substring(body from '.*\n(### [^\n]*)') from public.world_patch_notes where note_id = '3.0.0') <> '### 고친 것' then raise exception '3.0.0 마지막 칸이 고친 것이 아님'; end if;
end $n$;
update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n- 강화한 장비도 창고에 맡길 수 있습니다. 창고에 맡겨도 강화 단계는 그대로 남습니다.\n'
 where note_id = '3.0.0' and position('강화한 장비도 창고에 맡길 수 있습니다' in body) = 0;
update public.world_app_meta set value = '20261124030000' where key = 'db_version';
