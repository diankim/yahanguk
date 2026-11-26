update public.world_item_catalog i set tier = x.t, reference_price = x.p
  from (values
    ('gwiheo_iron', 1, 40), ('reed_silk', 1, 40), ('inverted_incense', 2, 90), ('oblivion_crystal', 2, 90), ('moonless_silk', 3, 180),
    ('register_slip', 1, 40), ('erased_plate', 1, 40), ('meokbi_moss', 2, 90), ('blank_hanji', 2, 90), ('mukchang_ink', 3, 180), ('meokbi_ebony', 3, 180),
    ('white_night_frost', 1, 40), ('severed_lamp_oil', 1, 40), ('pact_stone_dust', 1, 40), ('king_ember_ash', 1, 40),
    ('faded_star_glass', 2, 90), ('bleached_lantern_paper', 2, 90), ('ledger_tab', 2, 90), ('century_form_scrap', 2, 90), ('waterlogged_plank', 2, 90),
    ('frozen_arrow_shaft', 3, 180), ('frost_bell_iron', 3, 180), ('red_shrine_lacquer', 3, 180), ('star_record_plate', 3, 180), ('balance_weight', 3, 180)
  ) as x(id, t, p)
 where i.item_id = x.id;
update public.world_item_catalog set tier = 3 where item_id in ('fd_white_rice', 'fd_meokbi_fern');
do $d$
declare j jsonb := public.world_project_rules(); vv jsonb := '{}'; id text;
begin
  for id in select jsonb_object_keys(j -> 'v') loop
    vv := vv || jsonb_build_object(id, (select greatest(1, round(least(i.reference_price::numeric, coalesce((select min((select sum(coalesce(ic.reference_price, 0) * (e.value)::text::int)
        from jsonb_each(rc.ingredients) e join public.world_item_catalog ic on ic.item_id = e.key) / greatest(rc.output_qty, 1)::numeric * 1.2) from public.world_crafting_recipes rc where rc.output_item = id), i.reference_price::numeric))))::int
      from public.world_item_catalog i where i.item_id = id));
  end loop;
  j := j || jsonb_build_object('v', vv);
  execute format('create or replace function public.world_project_rules() returns jsonb language sql immutable set search_path = '''' as %L', format('select %L::jsonb', j::text));
end $d$;
