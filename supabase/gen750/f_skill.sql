-- ── 기술(7.5.0): 계열 열넷 → 제작 여덟·채집 셋·전투 여섯·탐사 ──
-- 기본 기술 효과 합: 제작 품질은 world_craft_item이, 채집 계열 채집량·희귀품은 world_field_gather·world_fish가 그 계열에서만 직접 더한다.
create or replace function public.world_skill_effect(p_effect_key text)
 returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid; v numeric;
begin
  if p_effect_key not in ('gather_qty_pct', 'rare_loot_pct', 'clue_bonus_pct', 'healing_pct', 'incoming_damage_pct', 'mental_loss_pct', 'erosion_pct', 'travel_time_pct', 'combat_damage_pct', 'encounter_pct') then return 0; end if;
  uid := public.fn_owner_auth_uid(); if uid is null then return 0; end if;
  select coalesce(sum((sk.passive_effect ->> p_effect_key)::numeric), 0) into v
    from public.world_skill_catalog sk join public.world_characters c on c.owner_id = uid left join public.world_skill_picks pk on pk.owner_id = uid
   where sk.passive_effect ? p_effect_key
     and not (p_effect_key in ('gather_qty_pct', 'rare_loot_pct') and sk.category in ('foraging', 'mining', 'fishing'))
     and sk.category not in ('smithing', 'carpentry', 'artifice', 'wardcraft', 'weaving', 'leatherwork', 'alchemy', 'cooking')
     and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires);
  return case p_effect_key
    when 'gather_qty_pct' then least(v, 40) when 'rare_loot_pct' then least(v, 22) when 'clue_bonus_pct' then least(v, 28)
    when 'healing_pct' then least(v, 45) when 'combat_damage_pct' then least(v, 15)
    when 'incoming_damage_pct' then greatest(v, -28) when 'mental_loss_pct' then greatest(v, -32)
    when 'erosion_pct' then greatest(v, -28) when 'travel_time_pct' then greatest(v, -20) when 'encounter_pct' then greatest(v, -15) else v end;
end $function$;

-- 숙련 4갈래 = 그 갈래 기술 가운데 가장 높은 단계(제작 = 제작 여덟 계열, 채집 = 채집·채광·낚시)
create or replace function public.world_skill_sync()
 returns trigger language plpgsql set search_path to 'pg_catalog', 'public'
as $function$
declare k text; v jsonb; outp jsonb := '{}'::jsonb; r int; cb int := 1; ga int := 1; cr int := 1; iv int := 1;
begin
  if tg_op = 'UPDATE' and coalesce(current_setting('yh.rank_sync', true), '') <> 'all'
     and new.skill_progress is not distinct from old.skill_progress
     and new.combat_rank is not distinct from old.combat_rank and new.gathering_rank is not distinct from old.gathering_rank
     and new.crafting_rank is not distinct from old.crafting_rank and new.investigation_rank is not distinct from old.investigation_rank then
    return new;
  end if;
  for k, v in select e.key, e.value from jsonb_each(coalesce(new.skill_progress, '{}'::jsonb)) e loop
    if jsonb_typeof(v) = 'object' then
      r := public.world_skill_line_rank(coalesce((v ->> 'xp')::numeric, 0)::int);
      outp := outp || jsonb_build_object(k, v || jsonb_build_object('rank', r));
    else outp := outp || jsonb_build_object(k, v); r := 1; end if;
    if k in ('melee', 'ranged', 'sealing', 'analysis', 'guarding', 'first_aid') then cb := greatest(cb, r);
    elsif k in ('foraging', 'mining', 'fishing') then ga := greatest(ga, r);
    elsif k in ('smithing', 'carpentry', 'artifice', 'wardcraft', 'weaving', 'leatherwork', 'alchemy', 'cooking') then cr := greatest(cr, r);
    elsif k = 'tracking' then iv := greatest(iv, r); end if;
  end loop;
  new.skill_progress := outp;
  new.combat_rank := cb; new.gathering_rank := ga; new.crafting_rank := cr; new.investigation_rank := iv;
  return new;
end $function$;

-- 택일 고르기: 7.5.0에서 효과가 바뀐 칸은 한 번 무료로 다시 고른다(world_skill_picks.free_repick)
create or replace function public.world_skill_choose(p_line text, p_tier integer, p_pick text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; cur text; fee int := 0; nm text; free boolean := false; key text := p_line || ':' || p_tier;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_tier not in (13, 24, 30, 43) or p_pick not in ('a', 'b') then raise exception '고를 수 없는 기술입니다.'; end if;
  select skill_name into nm from public.world_skill_catalog where category = p_line and unlock_rank = p_tier and slot = p_pick;
  if nm is null then raise exception '고를 수 없는 기술입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce((c.skill_progress -> p_line ->> 'rank')::int, 1) < p_tier then raise exception '%단계에 닿아야 고를 수 있습니다.', p_tier; end if;
  select picks ->> key, key = any (free_repick) into cur, free from public.world_skill_picks where owner_id = uid for update;
  if cur = p_pick then raise exception '이미 고른 기술입니다.'; end if;
  if cur is not null and not coalesce(free, false) then
    fee := case p_tier when 13 then 1000 when 24 then 2000 when 30 then 3000 else 5000 end;
    if c.gil < fee then raise exception '기술을 바꾸려면 %전이 필요합니다.', fee; end if;
  end if;
  insert into public.world_skill_picks(owner_id, picks) values (uid, jsonb_build_object(key, p_pick))
  on conflict (owner_id) do update set picks = public.world_skill_picks.picks || excluded.picks,
    free_repick = case when public.world_skill_picks.picks ? key then array_remove(public.world_skill_picks.free_repick, key) else public.world_skill_picks.free_repick end, updated_at = now();
  if fee > 0 then update public.world_characters set gil = gil - fee, updated_at = now() where owner_id = uid; end if;
  return jsonb_build_object('ok', true, 'fee', fee, 'free', cur is not null and coalesce(free, false),
    'content', '「' || nm || '」을(를) 익혔습니다.' || case when fee > 0 then ' 바꾸는 값 ' || fee || '전을 냈습니다.' when cur is not null and coalesce(free, false) then ' 이번 한 번은 무료로 바꿨습니다.' else '' end);
end $function$;

create or replace function public.world_skill_snapshot()
 returns jsonb language plpgsql set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; out jsonb; pk jsonb; fr text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 생성하세요.'; end if;
  select picks, free_repick into pk, fr from public.world_skill_picks where owner_id = uid;
  pk := coalesce(pk, '{}'::jsonb); fr := coalesce(fr, '{}');
  select jsonb_agg(jsonb_build_object('skill_id', s.skill_id, 'skill_name', s.skill_name, 'category', s.category, 'description', s.description,
      'rank', coalesce((c.skill_progress -> s.category ->> 'rank')::int, 1), 'xp', coalesce((c.skill_progress -> s.category ->> 'xp')::int, 0),
      'unlock_rank', s.unlock_rank, 'active_skill', s.active_skill, 'passive_effect', s.passive_effect, 'slot', s.slot, 'requires', s.requires,
      'reached', case when s.category = 'combo' then public.world_skill_has(c.skill_progress, pk, s.category, s.unlock_rank, s.slot, s.requires)
                      else coalesce((c.skill_progress -> s.category ->> 'rank')::int, 1) >= s.unlock_rank end,
      'picked', case when s.slot in ('a', 'b') then coalesce(pk ->> (s.category || ':' || s.unlock_rank), '') = s.slot end,
      'free_repick', case when s.slot in ('a', 'b') then (s.category || ':' || s.unlock_rank) = any (fr) end,
      'req_ranks', case when s.category = 'combo' then (select jsonb_object_agg(r.k, coalesce((c.skill_progress -> r.k ->> 'rank')::int, 1)) from jsonb_each(s.requires) r(k, v)) end,
      'unlocked', public.world_skill_has(c.skill_progress, pk, s.category, s.unlock_rank, s.slot, s.requires))
    order by s.category, s.unlock_rank, case s.slot when 'base' then 0 when 'extra' then 1 when 'a' then 2 when 'b' then 3 else 4 end) into out
  from public.world_skill_catalog s;
  return coalesce(out, '[]'::jsonb);
end $function$;

-- 자율 정비 경험은 고른 제작 분야의 계열로
create or replace function public.world_idle_skill_for(p_owner uuid, p_activity text)
 returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
begin
  return (select * from (select case p_activity
    when 'training' then coalesce((
      select case i.equipment_traits ->> 'weapon_type' when 'ranged' then 'ranged' when 'magic' then 'sealing' else 'melee' end
        from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
       where e.owner_id = p_owner and e.slot = 'weapon' limit 1), 'melee')
    when 'research' then 'tracking'
    when 'maintenance' then coalesce((select public.world_craft_line_of(c.crafting_profession) from public.world_characters c where c.owner_id = p_owner), 'smithing')
    else null end) yhq limit 1);
end $function$;

-- 생활 전문화: 제작 분야 여덟 가운데 하나(종합 제작 없음), 채집 분야 셋
create or replace function public.world_set_life_profession_v2(p_gathering text, p_crafting text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_gathering not in ('fieldwork', 'mining', 'fishing') then raise exception '없는 채집 분야입니다.'; end if;
  if p_crafting not in ('smithing', 'carpentry', 'alchemy', 'sealing', 'weaving', 'leatherwork', 'artifice', 'cooking') then raise exception '없는 제작 분야입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if c.gathering_profession = p_gathering and c.crafting_profession = p_crafting then raise exception '이미 그 분야입니다.'; end if;
  if c.life_changed_at is not null and c.life_changed_at > now() - interval '72 hours' then
    raise exception '%', format('전문화는 %s 이후에 다시 바꿀 수 있습니다.', to_char((c.life_changed_at + interval '72 hours') at time zone 'Asia/Seoul', 'MM월 DD일 HH24:MI'));
  end if;
  update public.world_characters set gathering_profession = p_gathering, crafting_profession = p_crafting, life_changed_at = now(), updated_at = now() where owner_id = uid;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'mission', '생활 전문 분야 변경', jsonb_build_object('v2', true, 'gathering_profession', p_gathering, 'crafting_profession', p_crafting));
  return jsonb_build_object('ok', true, 'content', '전문화를 정했습니다. 3일 뒤에 다시 바꿀 수 있습니다.');
end $function$;

-- 제작 공구: 그 공구가 맡는 분야 계열 가운데 가장 높은 단계로 조건을 본다
create or replace function public.world_craft_tool_bonus(p_uid uuid, p_field text)
 returns integer language plpgsql stable security definer set search_path to ''
as $function$
#variable_conflict use_column
begin
  return (select * from (
  select coalesce(max((i.equipment_traits ->> 'craft_quality')::int), 0)
    from public.world_characters c join public.world_item_catalog i
      on i.equipment_traits ->> 'life_slot' = 'craft' and coalesce((c.inventory ->> i.item_id)::int, 0) > 0
     and coalesce(i.equipment_traits -> 'craft_fields', '[]'::jsonb) ? p_field
     and coalesce(c.level, 1) >= coalesce(i.minimum_level, 1)
     and (case when coalesce(i.equipment_traits ->> 'req_line', 'crafting_rank') = 'crafting_rank'
            then (select coalesce(max(coalesce((c.skill_progress -> public.world_craft_line_of(f) ->> 'rank')::int, 1)), 1) from jsonb_array_elements_text(coalesce(i.equipment_traits -> 'craft_fields', '[]'::jsonb)) f)
            else coalesce((to_jsonb(c) ->> (i.equipment_traits ->> 'req_line'))::int, 1) end) >= coalesce((i.equipment_traits ->> 'req_rank')::int, 0)
   where c.owner_id = p_uid) yhq limit 1);
end $function$;

-- 상위 도구가 하위 도구를 덮는다(우수품 도구도 기본 도구의 줄로)
create or replace function public.world_tool_covers(p_have text, p_need text)
 returns boolean language sql stable set search_path to 'pg_catalog', 'public'
as $function$
  select p_have = p_need or public.world_item_base(p_have) = p_need or exists (
    select 1 from public.world_tool_lines a join public.world_tool_lines b on b.line = a.line
      join public.world_item_catalog ia on ia.item_id = a.item_id join public.world_item_catalog ib on ib.item_id = b.item_id
     where a.item_id = public.world_item_base(p_have) and b.item_id = p_need and ia.tier >= ib.tier)
$function$;

-- 최대 내구도: 우수품은 기본 ×1.1
create or replace function public.world_item_max_durability(p_item text)
 returns integer language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
begin
  return (select * from (
  select case when category in ('weapon', 'armor') then 50 + coalesce(tier, 1) * 30
              when category in ('tool', 'hat', 'shoes') then 40 + coalesce(tier, 1) * 20 else null end
         * case when base_item_id is not null then 1.1 else 1 end
  from public.world_item_catalog where item_id = p_item
) yhq limit 1)::int;
end $function$;
