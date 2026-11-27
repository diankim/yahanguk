create or replace function public.world_item_downgrade(p_item_id text, p_qty integer) returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; bnm text; have int; bhave int; st int; inv jsonb; d public.world_item_durability%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_qty is null or p_qty < 1 or p_qty > 9999 then raise exception '바꿀 수량이 올바르지 않습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  perform public.world_travel_guard('보통 물품으로 바꾸기');
  if coalesce(c.is_dead, false) then raise exception '현재 상태에서는 바꿀 수 없습니다.'; end if;
  select * into it from public.world_item_catalog where item_id = p_item_id;
  if it.item_id is null then raise exception '알 수 없는 물품입니다.'; end if;
  if it.base_item_id is null or coalesce(it.quality_grade, 0) < 1 then raise exception '우수품만 보통 물품으로 바꿀 수 있습니다.'; end if;
  select item_name into bnm from public.world_item_catalog where item_id = it.base_item_id;
  if bnm is null then raise exception '바꿀 보통 물품이 없습니다.'; end if;
  if it.category = 'quest' then raise exception '임무 물품은 바꿀 수 없습니다.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb); have := coalesce((inv ->> p_item_id)::int, 0); bhave := coalesce((inv ->> it.base_item_id)::int, 0);
  if have < 1 then raise exception '가방에 없는 물품입니다. 창고에 있으면 꺼낸 뒤 바꾸세요.'; end if;
  if have < p_qty then raise exception '가진 수량보다 많이 바꿀 수 없습니다.'; end if;
  if exists (select 1 from public.world_gear_enhance g where g.owner_id = uid and g.item_id = p_item_id and g.level > 0) then
    raise exception '강화한 장비는 보통 물품으로 바꿀 수 없습니다: %.', it.item_name;
  end if;
  perform public.world_item_give_guard(uid, p_item_id, have, p_qty);
  st := coalesce((select (s.items ->> p_item_id)::int from public.world_storage s where s.owner_id = uid), 0);
  if have - p_qty < 1 and st < 1 then
    select * into d from public.world_item_durability where owner_id = uid and item_id = p_item_id;
    if d.item_id is not null and d.durability < d.max_durability then
      raise exception '닳은 장비는 보통 물품으로 바꿀 수 없습니다: %. 수리한 뒤 바꾸세요.', it.item_name;
    end if;
  end if;
  inv := case when have = p_qty then inv - p_item_id else jsonb_set(inv, array[p_item_id], to_jsonb(have - p_qty)) end;
  inv := jsonb_set(inv, array[it.base_item_id], to_jsonb(bhave + p_qty));
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'item', p_item_id, 'base', it.base_item_id, 'qty', p_qty,
    'content', it.item_name || ' ×' || p_qty || '을(를) ' || bnm || '(으)로 바꿨습니다.', 'inventory', inv);
end $$;
revoke all on function public.world_item_downgrade(text, integer) from public, anon, authenticated;
grant execute on function public.world_item_downgrade(text, integer) to authenticated, service_role;
alter function public.world_item_downgrade(text, integer) owner to fn_owner_field;

update public.world_patch_notes set body = body || E'\n- [가방] 우수품을 보통 물품으로 바꿀 수 있습니다. 물품 정보 창에서 수량을 골라 「품질 하향」을 누르면 됩니다(값 없음, 되돌릴 수 없음). 가방에 있는 것만 바뀌고, 잠가 지키는 몫·장착 중인 마지막 하나·강화한 장비·닳은 마지막 장비는 바꿀 수 없습니다.'
where note_id = '3.8.0' and position('[가방] 우수품을 보통 물품으로 바꿀 수 있습니다' in body) = 0;

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
select pg_temp.yh_fix('world_project_rules', array[$a$"day_cap": 8000,$a$, $a$"day_cap": 16000,$a$]);

update public.world_patch_notes set body = body || E'\n- [사업] 한 사람이 하루에 넘길 수 있는 몫을 늘렸습니다(모든 사업 합쳐 8,000 → 16,000).'
where note_id = '3.8.0' and position('[사업] 한 사람이 하루에 넘길 수 있는 몫을 늘렸습니다' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127190000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
