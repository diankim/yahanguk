
-- 낫·등: 도구마다 sig_pct(확률 %)·sig_where(herb 약초·영기 채집터 / dark 유물 채집터나 어두운 지역)로 그 지역 희귀품을 함께 거둔다(7.0의 영맥 낫·영등 하드코딩을 일반화)
select pg_temp.yh_patch('public.world_field_gather(uuid)', '  IF coalesce(tool_bonus, 0) > 0 AND ((tool_id = ''spirit_sickle'' AND s.category IN (''herbs'', ''spirit'') AND random() < 0.03)
     OR (tool_id = ''spirit_lantern'' AND (s.category = ''relics'' OR rg.region_type IN (''sealed_shrine'', ''ruined_temple'', ''burial_ground'', ''underground'', ''abyss'', ''rift'', ''lost_city'', ''underwater_ruins'', ''haunted_garden'', ''blood_forest'')) AND random() < 0.05)) THEN',
  '  IF coalesce(tool_bonus, 0) > 0 AND EXISTS (SELECT 1 FROM public.world_item_catalog ti WHERE ti.item_id = tool_id
       AND random() * 100 < coalesce((ti.equipment_traits ->> ''sig_pct'')::numeric, 0)
       AND ((ti.equipment_traits ->> ''sig_where'' = ''herb'' AND s.category IN (''herbs'', ''spirit''))
         OR (ti.equipment_traits ->> ''sig_where'' = ''dark'' AND (s.category = ''relics'' OR rg.region_type IN (''sealed_shrine'', ''ruined_temple'', ''burial_ground'', ''underground'', ''abyss'', ''rift'', ''lost_city'', ''underwater_ruins'', ''haunted_garden'', ''blood_forest''))))) THEN');
select pg_temp.yh_patch('public.world_field_gather(uuid)', '(CASE WHEN tool_id = ''spirit_sickle'' THEN ''영맥 낫'' ELSE ''영등'' END)',
  '(SELECT ti.item_name FROM public.world_item_catalog ti WHERE ti.item_id = tool_id)');

-- 낚싯대: 단계로 붙던 덤(입질 +6%·희귀 +3 단계마다)은 영사 낚싯대(2단계)까지만 두고, 그 위는 낚싯대의 fish_bite_pct·fish_rare_pct·fish_size_pct로 오른다
select pg_temp.yh_patch('public.world_fish()', 'bite := 0.62 + rod * 0.06', 'bite := 0.62 + least(rod, 2) * 0.06');
select pg_temp.yh_patch('public.world_fish()', '+ public.world_status_effect_total(''rare_loot_pct'') + rod * 3', '+ public.world_status_effect_total(''rare_loot_pct'') + least(rod, 2) * 3');

-- 제작 공구: 가방에 있으면(레벨·제작 숙련 조건을 채웠을 때) 그 분야 제작 품질 +craft_quality(가장 큰 것 하나)
create or replace function public.world_craft_tool_bonus(p_uid uuid, p_field text) returns int
language sql stable security definer set search_path = '' as $$
  select coalesce(max((i.equipment_traits ->> 'craft_quality')::int), 0)
    from public.world_characters c join public.world_item_catalog i
      on i.equipment_traits ->> 'life_slot' = 'craft' and coalesce((c.inventory ->> i.item_id)::int, 0) > 0
     and coalesce(i.equipment_traits -> 'craft_fields', '[]'::jsonb) ? p_field
     and coalesce(c.level, 1) >= coalesce(i.minimum_level, 1)
     and coalesce((to_jsonb(c) ->> coalesce(i.equipment_traits ->> 'req_line', 'crafting_rank'))::int, 1) >= coalesce((i.equipment_traits ->> 'req_rank')::int, 0)
   where c.owner_id = p_uid
$$;
revoke all on function public.world_craft_tool_bonus(uuid, text) from public, anon, authenticated;
do $$ declare o text; begin
  select pg_get_userbyid(proowner) into o from pg_proc where oid = 'public.world_craft_item(text)'::regprocedure;
  execute format('grant execute on function public.world_craft_tool_bonus(uuid, text) to %I', o);
end $$;
select pg_temp.yh_patch('public.world_craft_item(text)', '-r.recipe_difficulty*8+rq+', '+public.world_craft_tool_bonus(uid, r.craft_field)-r.recipe_difficulty*8+rq+');
