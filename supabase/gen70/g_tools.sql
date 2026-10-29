-- ─────────────────────────────────────────────────────────────
-- G-2. 생활 도구 정리(7.0.0): 능력치 조건 대신 숙련 단계 조건 · 도구마다 설명대로 효과
--   곡괭이 계열: 광맥·유물 채집터에서 채집량 +10%p · 채집도 계열: 약초·목재·보급·물가 채집터에서 +10%p
--   영맥 낫: 약초·영기 채집 3% 그 지역 희귀품 · 영등: 유물 채집터나 어두운 지역 5% 그 지역 희귀품
--   영맥 나침반: 장착하면 탐색할 때 숨은 길·채집터를 찾는 무게 +20% · 강화 채집도 채집량 5 → 8%
-- ─────────────────────────────────────────────────────────────

-- ① 조건: 장착할 때 능력치 대신 숙련 단계(equipment_traits.req_line·req_rank). 낚싯대는 그대로(조건 없음)
update public.world_item_catalog i set required_stats = '{}'::jsonb,
       equipment_traits = (i.equipment_traits - 'req_line' - 'req_rank') || x.t
  from (values
    ('field_knife', '{}'::jsonb), ('ore_pick', '{}'),
    ('field_knife_2', '{"req_line": "gathering_rank", "req_rank": 2}'), ('spirit_sickle', '{"req_line": "gathering_rank", "req_rank": 2}'),
    ('spirit_lantern', '{"req_line": "gathering_rank", "req_rank": 2}'), ('t2_gather', '{"req_line": "gathering_rank", "req_rank": 3}'),
    ('seal_knife', '{}'),
    ('t3_gather', '{"req_line": "gathering_rank", "req_rank": 4}'), ('spirit_compass', '{"req_line": "investigation_rank", "req_rank": 10}'),
    ('t4_gather', '{"req_line": "gathering_rank", "req_rank": 6}'), ('t5_gather', '{"req_line": "gathering_rank", "req_rank": 8}'),
    ('t6_gather', '{"req_line": "gathering_rank", "req_rank": 12}')) as x(id, t)
 where i.item_id = x.id;
update public.world_item_catalog set equipment_traits = equipment_traits || '{"gathering_bonus_pct": 8}' where item_id = 'field_knife_2';
-- 설명: 실제 효과대로
update public.world_item_catalog i set description = x.d from (values
  ('field_knife', '약초·목재·보급품·물가 채집터에서 잘 드는 기본 채집도. 장착하면 채집량 +5%, 그런 채집터에서는 +10%를 더 거둔다.'),
  ('field_knife_2', '날을 다시 벼린 채집도. 장착하면 채집량 +8%, 약초·목재·보급품·물가 채집터에서는 +10%를 더 거둔다.'),
  ('t3_gather', '청강 날 채집도. 장착하면 채집량 +12%, 약초·목재·보급품·물가 채집터에서는 +10%를 더 거둔다.'),
  ('t5_gather', '천공 깃을 단 채집도. 장착하면 채집량 +22%·귀한 것이 잘 보이고, 약초·목재·보급품·물가 채집터에서는 +10%를 더 거둔다.'),
  ('t6_gather', '물에 녹지 않는 흑철 날. 장착하면 채집량 +26%·귀한 것이 잘 보이고, 약초·목재·보급품·물가 채집터에서는 +10%를 더 거둔다.'),
  ('ore_pick', '광맥을 쪼는 기본 곡괭이. 장착하면 채집량 +5%, 광맥·유물 채집터에서는 +10%를 더 거둔다.'),
  ('t4_gather', '영맥을 따라 파고드는 곡괭이. 장착하면 채집량 +16%·귀한 것이 잘 보이고, 광맥·유물 채집터에서는 +10%를 더 거둔다.'),
  ('spirit_sickle', '영맥이 흐르는 풀을 베는 낫. 장착하면 채집량 +5%, 약초·영기 채집터에서 3% 확률로 그 지역의 희귀품을 함께 거둔다.'),
  ('spirit_lantern', '어둠 속의 영기를 비추는 등. 장착하면 채집량 +5%, 유물 채집터나 사당·지하·심연 같은 어두운 지역에서 5% 확률로 그 지역의 희귀품을 함께 거둔다.'),
  ('spirit_compass', '영맥과 숨은 자원을 가리키는 나침반. 도구 칸에 장착하면 탐색할 때 숨은 길과 채집터를 더 잘 찾는다(찾을 확률 +20%). 채집량 +5%.'),
  ('seal_knife', '부적과 결계 장비를 새기는 공구. 장착하면 채집량 +5%. 각인 제작법에 필요하다.'),
  ('t2_gather', '약초꾼이 메는 망태. 장착하면 채집량 +8%·귀한 것이 잘 보인다.')) as x(id, d)
 where i.item_id = x.id;

-- ② 장착 검사: 도구는 숙련 단계
select pg_temp.yh_patch('public.world_equip_item(text)', ' slot_name:=it.category;',
  ' if it.category = ''tool'' and coalesce((it.equipment_traits->>''req_rank'')::int, 0) > 1
    and coalesce((to_jsonb(c)->>(it.equipment_traits->>''req_line''))::int, 1) < (it.equipment_traits->>''req_rank'')::int then
   raise exception ''숙련 조건 미달: % %단계 필요(지금 %단계)'',
     case it.equipment_traits->>''req_line'' when ''crafting_rank'' then ''제작 숙련'' when ''investigation_rank'' then ''조사 숙련'' else ''채집 숙련'' end,
     (it.equipment_traits->>''req_rank'')::int, coalesce((to_jsonb(c)->>(it.equipment_traits->>''req_line''))::int, 1);
 end if;
 slot_name:=it.category;');

-- ③ 채집: 도구 계열·종류에 맞는 덤
select pg_temp.yh_patch('public.world_field_gather(uuid)', '  x text; k text; v int;', '  x text; k text; v int; tool_id text;');
select pg_temp.yh_patch('public.world_field_gather(uuid)', '  SELECT round(coalesce((i.equipment_traits ->> ''gathering_bonus_pct'')::numeric, 0))::int INTO tool_bonus FROM',
  '  SELECT round(coalesce((i.equipment_traits ->> ''gathering_bonus_pct'')::numeric, 0))::int, i.item_id INTO tool_bonus, tool_id FROM');
select pg_temp.yh_patch('public.world_field_gather(uuid)', '  qty := greatest(1, round(qty * (1 + (coalesce(tool_bonus, 0) +',
  '  -- 곡괭이는 광맥·유물, 채집도는 약초·목재·보급품·물가에서 +10%p(부서진 도구는 tool_bonus가 0이라 붙지 않음)
  IF coalesce(tool_bonus, 0) > 0 AND EXISTS (SELECT 1 FROM public.world_tool_lines tl WHERE tl.item_id = tool_id
       AND ((tl.line = ''pick'' AND s.category IN (''ore'', ''relics'')) OR (tl.line = ''knife'' AND s.category IN (''herbs'', ''wood'', ''supplies'', ''water'')))) THEN
    tool_bonus := tool_bonus + 10;
  END IF;
  qty := greatest(1, round(qty * (1 + (coalesce(tool_bonus, 0) +');
select pg_temp.yh_patch('public.world_field_gather(uuid)', '  IF ''foraging_c43b'' = ANY (sk) AND random() < 0.10 THEN',
  '  -- 영맥 낫(약초·영기 3%) · 영등(유물 채집터나 어두운 지역 5%): 그 지역의 희귀품 하나
  IF coalesce(tool_bonus, 0) > 0 AND ((tool_id = ''spirit_sickle'' AND s.category IN (''herbs'', ''spirit'') AND random() < 0.03)
     OR (tool_id = ''spirit_lantern'' AND (s.category = ''relics'' OR rg.region_type IN (''sealed_shrine'', ''ruined_temple'', ''burial_ground'', ''underground'', ''abyss'', ''rift'', ''lost_city'', ''underwater_ruins'', ''haunted_garden'', ''blood_forest'')) AND random() < 0.05)) THEN
    x := NULL;
    SELECT y INTO x FROM public.world_region_profiles p, unnest(p.signature_items) y
     WHERE p.region_id = rg.region_id AND y NOT IN (''courier_token'', ''spirit_compass'', ''gwiryeong_cho'') ORDER BY random() LIMIT 1;
    IF x IS NOT NULL THEN extra := public.world_inv_add(extra, x, 1);
      notes := notes || ((CASE WHEN tool_id = ''spirit_sickle'' THEN ''영맥 낫'' ELSE ''영등'' END) || '' 희귀품: '' || (SELECT item_name FROM public.world_item_catalog WHERE item_id = x)); END IF;
  END IF;
  IF ''foraging_c43b'' = ANY (sk) AND random() < 0.10 THEN');

-- ④ 탐색: 영맥 나침반을 장착하면(부서지지 않았을 때) 숨은 길·채집터 무게 +20%
select pg_temp.yh_patch('public.world_field_search()', '  tot := w_path + w_spot + w_enc',
  '  IF EXISTS (SELECT 1 FROM public.world_character_equipment e LEFT JOIN public.world_item_durability dd ON dd.owner_id = e.owner_id AND dd.item_id = e.item_id
             WHERE e.owner_id = uid AND e.slot = ''tool'' AND e.item_id = ''spirit_compass'' AND coalesce(dd.durability, 1) > 0) THEN
    w_path := w_path * 1.2; w_spot := w_spot * 1.2;
  END IF;
  tot := w_path + w_spot + w_enc');
grant select on public.world_tool_lines to fn_owner_field;
do $$ declare o text; begin
  select pg_get_userbyid(proowner) into o from pg_proc where oid = 'public.world_field_gather(uuid)'::regprocedure;
  execute format('grant select on public.world_tool_lines, public.world_region_profiles to %I', o);
  select pg_get_userbyid(proowner) into o from pg_proc where oid = 'public.world_field_search()'::regprocedure;
  execute format('grant select on public.world_character_equipment, public.world_item_durability to %I', o);
end $$;
