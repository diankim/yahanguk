-- ── 채집(7.5.0): 채집(약초·목재·보급품·물가·영기)·채광(광맥·유물) 두 계열, 기본 기술은 그 계열 채집터에만 ──
create or replace function public.world_field_gather(p_spot_id uuid)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_gathering_spots%rowtype;
  d public.world_gathering_discoveries%rowtype; it text; qty int; tool_bonus int := 0; inv jsonb; left_st int; prof_match boolean; nm text;
  sk text[]; line text; rg public.world_map_regions%rowtype; mult int := 1; mnote text; notes text[] := '{}'; extra jsonb := '{}'::jsonb;
  wait_s int := 300; no_wear boolean := false; free_st boolean := false; tool_ln text;
  x text; k text; v int; tool_id text; free_day int := 0; gcnt int := 0; q_pct numeric; r_pct numeric;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 채집할 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 채집할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then
    raise exception '전투 중에는 채집할 수 없습니다.'; end if;
  select * into s from public.world_gathering_spots where spot_id = p_spot_id and active and (node_id = c.current_exploration_node_id or (node_id = (select n0.node_id from public.world_exploration_nodes n0 join public.world_map_regions r0 on r0.region_id = n0.region_id where r0.region_name = c.location and n0.hierarchy_level = 1 limit 1) and not exists (select 1 from public.world_exploration_nodes n1 join public.world_map_regions r1 on r1.region_id = n1.region_id where n1.node_id = c.current_exploration_node_id and r1.region_name = c.location)));
  if not found then raise exception '지금 있는 곳의 채집터가 아닙니다.'; end if;
  select * into d from public.world_gathering_discoveries where owner_id = uid and spot_id = s.spot_id for update;
  if not found then raise exception '먼저 탐색으로 채집터를 찾으세요.'; end if;
  if d.last_gathered_at is not null and d.last_gathered_at > now() - interval '5 minutes' then
    raise exception '%', format('이 채집터는 %s초 뒤에 다시 쓸 수 있습니다.', ceil(extract(epoch from d.last_gathered_at + interval '5 minutes' - now()))::int); end if;
  if c.level < s.min_level then raise exception '%', format('레벨 %s부터 채집할 수 있습니다.', s.min_level); end if;
  sk := public.world_skill_procs(uid);
  line := case when s.category in ('ore', 'relics') then 'mining' else 'foraging' end;
  rg := public.world_field_region(c.location);
  select count(*)::int into gcnt from public.world_events e where e.actor_id = uid and e.event_type = 'gather'
     and e.created_at >= (date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul') and (e.payload ->> 'free_day') = 'true';
  if gcnt < 10 then free_st := true; free_day := gcnt + 1; notes := notes || format('오늘의 무료 채집 %s/10 · 탐색력을 쓰지 않았다', gcnt + 1); end if;
  if not free_st and line = 'foraging' and 'foraging_m50' = any (sk) and random() < 0.25 then free_st := true; notes := notes || '「산천의 은혜」 탐색력을 쓰지 않았다'::text; end if;
  left_st := public.world_stamina_change(uid, case when free_st then 0 else -1 end);
  select * into c from public.world_characters where owner_id = uid;
  select round(coalesce((i.equipment_traits ->> 'gathering_bonus_pct')::numeric, 0))::int, i.item_id into tool_bonus, tool_id from public.world_character_equipment e
    join public.world_item_catalog i on i.item_id = e.item_id where e.owner_id = uid and e.slot = 'tool';
  it := s.loot_items[1 + floor(random() * cardinality(s.loot_items))::int];
  qty := s.yield_min + floor(random() * (s.yield_max - s.yield_min + 1))::int + coalesce(c.gathering_rank, 1) / 12;
  prof_match := (c.gathering_profession = 'mining' and s.category in ('ore', 'relics')) or (c.gathering_profession = 'fishing' and s.category = 'water')
    or (c.gathering_profession = 'fieldwork' and s.category in ('herbs', 'wood', 'supplies', 'spirit'));
  if prof_match then qty := qty + 1; end if;
  if exists (select 1 from public.world_character_equipment e join public.world_item_durability dd on dd.owner_id = e.owner_id and dd.item_id = e.item_id
             where e.owner_id = uid and e.slot = 'tool' and dd.durability <= 0) then tool_bonus := 0; end if;
  -- 도구 닳기: 길목 기억(채집 30)·갱도 감각(채광 30)은 닳지 않고, 짐꾼의 요령(채광·가죽 공예 조합)은 50%
  no_wear := (line = 'foraging' and 'foraging_x30' = any (sk)) or (line = 'mining' and 'mining_x30' = any (sk))
    or ('combo_mining_leatherwork' = any (sk) and random() < 0.5);
  if not no_wear then perform public.world_durability_wear(uid, 'tool', 1); end if;
  -- 곡괭이는 광맥·유물, 채집도는 약초·목재·보급품·물가에서 +10%p(우수품 도구도 기본 도구의 줄로)
  select tl.line into tool_ln from public.world_tool_lines tl where tl.item_id = public.world_item_base(tool_id);
  if coalesce(tool_bonus, 0) > 0 and ((tool_ln = 'pick' and s.category in ('ore', 'relics')) or (tool_ln = 'knife' and s.category in ('herbs', 'wood', 'supplies', 'water'))) then
    tool_bonus := tool_bonus + 10;
  end if;
  -- 그 계열 기본 기술(채집량 ≤30·희귀품 ≤8)과 그 계열 칭호
  q_pct := least(30, public.world_line_base(c.skill_progress, line, 'gather_qty_pct')) + public.world_title_bonus('gq_' || line);
  r_pct := least(8, public.world_line_base(c.skill_progress, line, 'rare_loot_pct')) + public.world_title_bonus('gr_' || line);
  qty := greatest(1, round(qty * (1 + (coalesce(tool_bonus, 0) + q_pct + public.world_status_effect_total('gather_qty_pct') + public.world_title_bonus('gather_qty_pct')) / 100.0)));

  -- 몇 배 거두기: 굴림마다 따로, 가장 큰 배수 하나만
  if line = 'foraging' then
    if 'foraging_c24a' = any (sk) and random() < 0.15 and mult < 2 then mult := 2; mnote := '「넓게 줍기」 두 번 거뒀다'; end if;
    if 'foraging_c43a' = any (sk) and random() < 0.10 and mult < 3 then mult := 3; mnote := '「대풍」 세 배로 거뒀다'; end if;
  else
    if 'mining_c24a' = any (sk) and random() < 0.15 and mult < 2 then mult := 2; mnote := '「힘껏 캐기」 두 번 캤다'; end if;
    if 'mining_c43a' = any (sk) and random() < 0.05 and mult < 5 then mult := 5; mnote := '「노다지」 다섯 배로 캤다'; end if;
  end if;
  qty := qty * mult;
  if mnote is not null then notes := notes || mnote; end if;
  -- 영맥 세공(채광·법구 공예 조합): 유물 채집터 15% 하나 더
  if s.category = 'relics' and 'combo_mining_artifice' = any (sk) and random() < 0.15 then qty := qty + 1; notes := notes || '「영맥 세공」 하나 더'::text; end if;

  -- 덤
  if line = 'foraging' then
    if 'foraging_x13' = any (sk) and cardinality(s.loot_items) > 1 and random() < 0.10 then
      select y into x from unnest(s.loot_items) y where y <> it order by random() limit 1;
      if x is not null then extra := public.world_inv_add(extra, x, 1); notes := notes || ('「눈썰미」 덤: ' || (select item_name from public.world_item_catalog where item_id = x)); end if;
    end if;
    if 'foraging_c43b' = any (sk) and s.category = 'herbs' and random() < 0.10 then extra := public.world_inv_add(extra, 'herbal_extract', 1); notes := notes || '「본초 감별」 농축 약초액'::text; end if;
    if 'foraging_c43b' = any (sk) and s.category = 'spirit' and random() < 0.05 then extra := public.world_inv_add(extra, 'spirit_core', 1); notes := notes || '「본초 감별」 응축 영핵'::text; end if;
  else
    if 'mining_x13' = any (sk) and random() < 0.10 then extra := public.world_inv_add(extra, 'charcoal', 1); notes := notes || '「광맥 읽기」 정련 숯 덤'::text; end if;
    if 'mining_c24b' = any (sk) and random() < 0.10 then extra := public.world_inv_add(extra, 'iron_ingot', 1); notes := notes || '「옥석 가리기」 월철 주괴'::text; end if;
    if 'mining_c43b' = any (sk) and random() < 0.08 then extra := public.world_inv_add(extra, 'steel_ingot', 1); notes := notes || '「보석 눈」 강철 주괴'::text; end if;
  end if;
  -- 그 지역 희귀품: 기본 기술·칭호 희귀품 %(채집·채광 모두) + 골라 줍기(채집 24b) 10%
  if random() * 100 < r_pct + (case when line = 'foraging' and 'foraging_c24b' = any (sk) then 10 else 0 end) then
    x := null;
    select y into x from public.world_region_profiles p, unnest(p.signature_items) y join public.world_item_catalog ic on ic.item_id = y
     where p.region_id = rg.region_id and y not in ('courier_token', 'spirit_compass', 'gwiryeong_cho') order by random() limit 1;
    if x is not null then extra := public.world_inv_add(extra, x, 1); notes := notes || ('희귀품: ' || (select item_name from public.world_item_catalog where item_id = x)); end if;
  end if;
  -- 영맥 낫(약초·영기 3%) · 영등(유물 채집터나 어두운 지역 5%): 그 지역의 희귀품 하나
  if coalesce(tool_bonus, 0) > 0 and exists (select 1 from public.world_item_catalog ti where ti.item_id = tool_id
       and random() * 100 < coalesce((ti.equipment_traits ->> 'sig_pct')::numeric, 0)
       and ((ti.equipment_traits ->> 'sig_where' = 'herb' and s.category in ('herbs', 'spirit'))
         or (ti.equipment_traits ->> 'sig_where' = 'dark' and (s.category = 'relics' or rg.region_type in ('sealed_shrine', 'ruined_temple', 'burial_ground', 'underground', 'abyss', 'rift', 'lost_city', 'underwater_ruins', 'haunted_garden', 'blood_forest'))))) then
    x := null;
    select y into x from public.world_region_profiles p, unnest(p.signature_items) y
     where p.region_id = rg.region_id and y not in ('courier_token', 'spirit_compass', 'gwiryeong_cho') order by random() limit 1;
    if x is not null then extra := public.world_inv_add(extra, x, 1);
      notes := notes || ((select ti.item_name from public.world_item_catalog ti where ti.item_id = tool_id) || ' 희귀품: ' || (select item_name from public.world_item_catalog where item_id = x)); end if;
  end if;

  -- 채집터 대기
  if line = 'foraging' and 'foraging_x30' = any (sk) then wait_s := 240; end if;
  if (line = 'mining' and 'mining_m50' = any (sk)) or (s.category = 'spirit' and 'combo_analysis_spirit_gathering' = any (sk)) then wait_s := wait_s / 2; end if;

  inv := public.world_inv_add(c.inventory, it, qty);
  for k, v in select key, value::text::int from jsonb_each(extra) loop inv := public.world_inv_add(inv, k, v); end loop;
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  update public.world_gathering_discoveries set last_gathered_at = now() - make_interval(secs => 300 - wait_s), gather_count = gather_count + 1 where owner_id = uid and spot_id = s.spot_id;
  select item_name into nm from public.world_item_catalog where item_id = it;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'gather', s.spot_name || '에서 ' || nm || ' ×' || qty || ' 채집',
    jsonb_build_object('spot_id', s.spot_id, 'category', s.category, 'item_id', it, 'qty', qty, 'node_id', s.node_id, 'line', line,
      'node', case s.category when 'ore' then 'ore' when 'herbs' then 'herb' when 'spirit' then 'shrine' else 'field' end, 'profession_match', prof_match, 'extra', extra, 'free_day', free_day > 0));
  return jsonb_build_object('ok', true, 'content', s.spot_name || '에서 ' || nm || ' ×' || qty || '을(를) 얻었습니다.' || case when prof_match then ' (전문 분야 +1)' else '' end
      || case when cardinality(notes) > 0 then ' ' || array_to_string(notes, ' · ') || '.' else '' end,
    'item_id', it, 'qty', qty, 'extra', extra, 'line', line, 'stamina', left_st, 'free_left', greatest(0, 10 - gcnt - case when free_day > 0 then 1 else 0 end), 'ready_at', now() + make_interval(secs => wait_s));
end $function$;
