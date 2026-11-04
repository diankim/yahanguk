do $gm$
declare
  v uuid := 'd3ce7dbb-9d58-4fa5-ade7-33d4e75bb1fe';
  gear text[] := array['w_ranged6_base_hq','a6_light_hq','h6_wise_hq','s6_swift_hq','n6_keen_hq','m6_ward_hq','k6_awe_hq','t6_gather_hq','lt_compass_6_hq','lt_rod_6_hq'];
  slots text[] := array['weapon','armor','hat','shoes','norigae','amulet','mask','tool','explore','fishing'];
  sp jsonb := '{}'::jsonb; k text; i int;
begin
  lock table public.world_characters in access exclusive mode;
  if not exists (select 1 from public.world_staff where owner_id = v) then raise exception 'GM 명단에 없는 캐릭터입니다'; end if;
  foreach k in array array['melee','ranged','sealing','dagger','exorcism','medicine','analysis','guarding','first_aid','tracking','foraging','mining','fishing',
                           'smithing','carpentry','artifice','wardcraft','weaving','leatherwork','alchemy','cooking'] loop
    sp := sp || jsonb_build_object(k, jsonb_build_object('rank', 50, 'xp', 30940));
  end loop;
  update public.world_characters c set
    level = 40, experience = 0, stat_points = 0,
    agility = 68,
    perception = 65,
    skill_progress = coalesce(c.skill_progress, '{}'::jsonb) || sp,
    inventory = coalesce(c.inventory, '{}'::jsonb)
      || (select jsonb_object_agg(g, 1) from unnest(gear) g)
      || jsonb_build_object('ammo_arrow', greatest(coalesce((c.inventory ->> 'ammo_arrow')::int, 0), 300)),
    health = 100, mental = 100
  where c.owner_id = v;
  for i in 1 .. cardinality(gear) loop
    insert into public.world_character_equipment(owner_id, slot, item_id, equipped_at) values (v, slots[i], gear[i], now())
    on conflict (owner_id, slot) do update set item_id = excluded.item_id, equipped_at = now();
    insert into public.world_item_locks(owner_id, item_id, locked_at) values (v, gear[i], now()) on conflict do nothing;
    delete from public.world_item_durability where owner_id = v and item_id = gear[i];
  end loop;
  insert into public.world_gear_enhance(owner_id, item_id, level, updated_at) values (v, 'w_ranged6_base_hq', 10, now())
  on conflict (owner_id, item_id) do update set level = 10, updated_at = now();
end $gm$;
