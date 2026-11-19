create or replace function pg_temp.yh_rekey_map(m jsonb, a text, b text) returns jsonb language sql immutable as $$
  select case when m ? a then (m - a) || jsonb_build_object(b, coalesce((m ->> b)::int, 0) + (m ->> a)::int) else m end
$$;

update public.world_characters set inventory = pg_temp.yh_rekey_map(inventory, 'ammo_bolt', 'ammo_dart') where inventory ? 'ammo_bolt';
update public.world_storage set items = pg_temp.yh_rekey_map(items, 'ammo_bolt', 'ammo_dart') where items ? 'ammo_bolt';
update public.world_letters set items = pg_temp.yh_rekey_map(items, 'ammo_bolt', 'ammo_dart') where jsonb_typeof(items) = 'object' and items ? 'ammo_bolt';
insert into public.world_overflow_items(owner_id, item_id, qty, source, created_at)
select owner_id, 'ammo_dart', qty, source, created_at from public.world_overflow_items where item_id = 'ammo_bolt'
on conflict (owner_id, item_id) do update set qty = public.world_overflow_items.qty + excluded.qty;
delete from public.world_overflow_items where item_id = 'ammo_bolt';
update public.world_trade_offers set item_id = 'ammo_dart' where item_id = 'ammo_bolt';
update public.world_user_commissions set item_id = 'ammo_dart' where item_id = 'ammo_bolt';
update public.world_party_loot_pool set item_id = 'ammo_dart' where item_id = 'ammo_bolt';
delete from public.world_shop_stock s where s.item_id = 'ammo_bolt' and exists (select 1 from public.world_shop_stock d where d.shop_id = s.shop_id and d.item_id = 'ammo_dart');
update public.world_shop_stock set item_id = 'ammo_dart' where item_id = 'ammo_bolt';
delete from public.world_crafting_recipes where output_item = 'ammo_bolt';
update public.world_item_catalog set description = '이제 쓰지 않는 쇠뇌살. 3.4.0부터 쇠뇌는 편전을 쓴다.', tradeable = false where item_id = 'ammo_bolt';

do $$
declare r record; give int;
begin
  for r in
    select c.owner_id, coalesce((c.inventory ->> 'ammo_arrow')::int, 0) arrows
      from public.world_characters c join public.world_character_equipment e on e.owner_id = c.owner_id and e.slot = 'weapon'
     where coalesce((select i.base_item_id from public.world_item_catalog i where i.item_id = e.item_id), e.item_id)
           in ('w_ranged1_heavy', 'w_ranged1_silent', 'w_ranged3_silent', 'w_ranged4_silent', 'w_ranged5_silent')
  loop
    give := least(100, r.arrows);
    if give > 0 then
      update public.world_characters set inventory = jsonb_strip_nulls(
          (inventory - 'ammo_arrow')
          || case when r.arrows - give > 0 then jsonb_build_object('ammo_arrow', r.arrows - give) else '{}'::jsonb end
          || jsonb_build_object('ammo_dart', coalesce((inventory ->> 'ammo_dart')::int, 0) + give))
       where owner_id = r.owner_id;
    end if;
  end loop;
end $$;

do $$
declare r record; tgt text; tgt_hq text; inv jsonb;
begin
  for r in
    select c.owner_id, c.job_key, e.item_id, i.tier, i.base_item_id is not null as hq, coalesce(i.base_item_id, i.item_id) base_id,
           case when i.equipment_traits ? 'crit_pct' then 'keen' when i.equipment_traits ? 'evasion_pct' then 'silent'
                when i.equipment_traits ? 'incoming_damage_pct' then 'heavy' else 'base' end as line
      from public.world_characters c
      join public.world_character_equipment e on e.owner_id = c.owner_id and e.slot = 'weapon'
      join public.world_item_catalog i on i.item_id = e.item_id
     where not (coalesce(i.equipment_traits -> 'jobs', '[]'::jsonb) ? c.job_key)
  loop
    select x.item_id into tgt from public.world_item_catalog x
     where x.category = 'weapon' and x.base_item_id is null and x.tier = r.tier and x.equipment_traits -> 'jobs' ? r.job_key
       and jsonb_array_length(x.equipment_traits -> 'jobs') = 1
     order by (case when x.equipment_traits ? 'crit_pct' then 'keen' when x.equipment_traits ? 'evasion_pct' then 'silent'
                    when x.equipment_traits ? 'incoming_damage_pct' then 'heavy' else 'base' end) = r.line desc, x.item_id
     limit 1;
    if tgt is null then continue; end if;
    tgt_hq := case when r.hq and exists (select 1 from public.world_item_catalog h where h.item_id = tgt || '_hq') then tgt || '_hq' else tgt end;
    select inventory into inv from public.world_characters where owner_id = r.owner_id for update;
    inv := case when coalesce((inv ->> r.item_id)::int, 0) > 1 then jsonb_set(inv, array[r.item_id], to_jsonb((inv ->> r.item_id)::int - 1)) else inv - r.item_id end;
    inv := jsonb_set(inv, array[tgt_hq], to_jsonb(coalesce((inv ->> tgt_hq)::int, 0) + 1));
    update public.world_characters set inventory = inv where owner_id = r.owner_id;
    update public.world_character_equipment set item_id = tgt_hq where owner_id = r.owner_id and slot = 'weapon';
    if not exists (select 1 from public.world_item_durability where owner_id = r.owner_id and item_id = tgt_hq) then
      update public.world_item_durability set item_id = tgt_hq where owner_id = r.owner_id and item_id = r.item_id;
    end if;
    if not exists (select 1 from public.world_gear_enhance where owner_id = r.owner_id and item_id = tgt_hq) then
      update public.world_gear_enhance set item_id = tgt_hq where owner_id = r.owner_id and item_id = r.item_id;
    end if;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.owner_id, 'guide', '무기를 바꿔 드렸습니다',
            '무기 개편으로 끼고 있던 ' || (select item_name from public.world_item_catalog where item_id = r.item_id) || '을(를) 같은 단계의 직업 무기 '
              || (select item_name from public.world_item_catalog where item_id = tgt_hq) || '(으)로 바꿔 끼워 드렸습니다. 강화와 내구도는 그대로입니다.',
            jsonb_build_object('tip', 'weapon_swap', 'from', r.item_id, 'to', tgt_hq));
  end loop;
end $$;
