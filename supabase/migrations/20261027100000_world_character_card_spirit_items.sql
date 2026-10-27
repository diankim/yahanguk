-- 1) 캐릭터 정보 카드: 채팅·여기 있는 이들·동료에서 이름을 누르면 보이는 공개 정보.
--    가진 전·가방·능력치 같은 개인 정보는 내보내지 않는다. 숨김 칭호는 보는 사람이 얻지 못했으면 이름을 가린다.
-- 2) 영력 회복약 5단계(영초 차 → 청령단 → 영기환 → 월광 정수 → 천령 감로): 물품·제작법·상점(낮은 단계)·사용·전투 중 사용.

grant select on public.world_staff, public.world_title_catalog, public.world_character_titles,
  public.world_expeditions, public.world_active_encounters to fn_owner_field;

create or replace function public.world_character_card(p_owner uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'pg_catalog', 'public'
as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = p_owner;
  if not found then raise exception '그 조사원을 찾을 수 없습니다.'; end if;
  return jsonb_build_object(
    'owner_id', c.owner_id, 'character_name', c.character_name, 'level', c.level,
    'job_key', c.job_key, 'faction_key', c.faction_key, 'major_faction_id', c.major_faction_id,
    'location', c.location, 'profile', coalesce(c.profile, '{}'::jsonb),
    'mine', c.owner_id = uid,
    'gm', exists (select 1 from public.world_staff s where s.owner_id = c.owner_id),
    'downed', c.downed_at is not null or c.health <= 0, 'is_dead', coalesce(c.is_dead, false),
    'away', exists (select 1 from public.world_expeditions e where e.owner_id = c.owner_id and e.status = 'active'),
    'in_combat', exists (select 1 from public.world_active_encounters a where a.owner_id = c.owner_id and not a.defeated and not coalesce(a.fled, false)),
    'traveling', c.travel_arrives_at is not null and c.travel_arrives_at > now(),
    'ranks', jsonb_build_object('combat', c.combat_rank, 'gathering', c.gathering_rank, 'crafting', c.crafting_rank, 'investigation', c.investigation_rank),
    'title_count', (select count(*) from public.world_character_titles t where t.owner_id = c.owner_id),
    'display_title', (select case when tc.hidden and c.owner_id <> uid and not exists (select 1 from public.world_character_titles m where m.owner_id = uid and m.title_key = tc.title_key)
                        then '숨김 칭호' else tc.title_name end
                      from public.world_title_catalog tc where tc.title_key = c.profile ->> 'title'),
    'titles', (select coalesce(jsonb_agg(case when tc.hidden and c.owner_id <> uid and not exists (select 1 from public.world_character_titles m where m.owner_id = uid and m.title_key = tc.title_key)
                        then jsonb_build_object('name', '숨김 칭호', 'hidden', true)
                        else jsonb_build_object('name', tc.title_name, 'description', tc.description) end order by tc.sort), '[]'::jsonb)
               from public.world_character_titles t join public.world_title_catalog tc using (title_key)
               where t.owner_id = c.owner_id and t.is_equipped));
end $$;
alter function public.world_character_card(uuid) owner to fn_owner_field;
revoke all on function public.world_character_card(uuid) from public, anon;
grant execute on function public.world_character_card(uuid) to authenticated;

/* ── 영력 회복약 ─────────────────────────────────────────── */
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, rarity, minimum_level, acquisition_difficulty, tradeable, reference_price)
values
  ('spirit_tea', '영초 차', 'consumable', 1, '야령초를 우려 갈대 향을 더한 차. 마시면 영력이 조금 돌아온다. 영력 +10', true, 'common', 1, 1, true, 30),
  ('clear_spirit_pill', '청령단', 'consumable', 2, '월광 이끼를 약제 바탕에 버무려 빚은 환약. 영력 +20', true, 'uncommon', 1, 2, true, 75),
  ('spirit_qi_pill', '영기환', 'consumable', 3, '요기 결정을 약초액으로 다스려 굳힌 환약. 영력 +35', true, 'rare', 4, 3, true, 180),
  ('moonlight_essence', '월광 정수', 'consumable', 4, '달빛을 머금은 이끼와 영핵을 영유리 병에 가라앉힌 정수. 영력 +55', true, 'epic', 8, 4, true, 420),
  ('heavenly_dew', '천령 감로', 'consumable', 5, '성진사와 영맥 수피로 받아 낸 하늘의 이슬. 영력 +80', true, 'legendary', 12, 5, true, 900)
on conflict (item_id) do nothing;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, recipe_difficulty)
values
  ('spirit_tea_recipe', '영초 차 우리기', 'spirit_tea', 2, '{"herb": 2, "river_reed": 1}', 'field_knife', 1, '야행국 본부 정청', '야령초 2와 수향 갈대 1로 영초 차 두 잔을 우린다.', 1, 1),
  ('clear_spirit_pill_recipe', '청령단 빚기', 'clear_spirit_pill', 1, '{"herb": 2, "moon_moss": 1, "medicine_base": 1}', 'field_knife', 1, '야행국 본부 정청', '월광 이끼와 약제 바탕으로 환약을 빚는다.', 2, 2),
  ('spirit_qi_pill_recipe', '영기환 굳히기', 'spirit_qi_pill', 1, '{"herbal_extract": 1, "spirit_dust": 2, "moon_moss": 1}', 'field_knife', 1, '장서각 지하서고', '요기 결정을 약초액으로 다스려 굳힌다.', 4, 3),
  ('moonlight_essence_recipe', '월광 정수 가라앉히기', 'moonlight_essence', 1, '{"spirit_glass": 1, "moon_moss": 2, "spirit_core": 1}', 'field_knife', 1, '장서각 지하서고', '영유리 병에 이끼와 영핵을 넣고 달빛 아래 가라앉힌다.', 8, 4),
  ('heavenly_dew_recipe', '천령 감로 받기', 'heavenly_dew', 1, '{"star_sand": 1, "spirit_bark": 1, "spirit_core": 1, "herbal_extract": 2}', 'field_knife', 1, '장서각 지하서고', '성진사와 영맥 수피로 하늘의 이슬을 받아 낸다.', 12, 5)
on conflict (recipe_id) do nothing;

-- 상점: 낮은 두 단계만 판다(높은 단계는 제작으로만)
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
values ('night_office_store', 'spirit_tea', 30, 2, 10), ('capital_market', 'spirit_tea', 30, 2, 10), ('south_market', 'spirit_tea', 32, 2, 8),
       ('north_market', 'spirit_tea', 32, 2, 8), ('astral_market', 'spirit_tea', 30, 2, 8),
       ('night_office_store', 'clear_spirit_pill', 75, 1, 5), ('astral_market', 'clear_spirit_pill', 72, 1, 5)
on conflict do nothing;

-- 사용: world_use_item에 영력 회복을 더한다(의무관·회복 보정은 체력·정신과 같이 받는다)
do $$ declare def text; nd text;
begin
  def := pg_get_functiondef('public.world_use_item(text)'::regprocedure);
  if position('spirit_tea' in def) > 0 then return; end if;
  nd := replace(def, 'er int := 0; stam int := 0;', 'er int := 0; stam int := 0; spg int := 0;');
  nd := replace(nd, '''carp_broth'', ''bream_sashimi'') THEN RAISE EXCEPTION',
    '''carp_broth'', ''bream_sashimi'', ''spirit_tea'', ''clear_spirit_pill'', ''spirit_qi_pill'', ''moonlight_essence'', ''heavenly_dew'') THEN RAISE EXCEPTION');
  nd := replace(nd, 'WHEN ''travel_ration'' THEN stam := 5;',
    'WHEN ''travel_ration'' THEN stam := 5;
    WHEN ''spirit_tea'' THEN spg := 10;
    WHEN ''clear_spirit_pill'' THEN spg := 20;
    WHEN ''spirit_qi_pill'' THEN spg := 35;
    WHEN ''moonlight_essence'' THEN spg := 55; cures := ARRAY[''shaken''];
    WHEN ''heavenly_dew'' THEN spg := 80; cures := ARRAY[''shaken'', ''erosion_whisper''];');
  nd := replace(nd, 'hp := round(hp * mul); mn := round(mn * mul);', 'hp := round(hp * mul); mn := round(mn * mul); spg := round(spg * mul);');
  nd := replace(nd, 'AND (er = 0 OR c.erosion <= 0) THEN', 'AND (er = 0 OR c.erosion <= 0) AND (spg = 0 OR c.spiritual_power >= 100) THEN');
  nd := replace(nd, 'mental = least(100, mental + mn),', 'mental = least(100, mental + mn), spiritual_power = least(100, spiritual_power + spg),');
  nd := replace(nd, 'CASE WHEN mn > 0 THEN '' 정신 +'' || mn ELSE '''' END', 'CASE WHEN mn > 0 THEN '' 정신 +'' || mn ELSE '''' END || CASE WHEN spg > 0 THEN '' 영력 +'' || spg ELSE '''' END');
  if position('spiritual_power = least(100, spiritual_power + spg)' in nd) = 0 or position('WHEN ''heavenly_dew'' THEN spg := 80' in nd) = 0
     or position('''heavenly_dew'') THEN RAISE EXCEPTION' in nd) = 0 or position('spg := round(spg * mul)' in nd) = 0
     or position('(spg = 0 OR c.spiritual_power >= 100)' in nd) = 0 or position(''' 영력 +'' || spg' in nd) = 0 then
    raise exception 'world_use_item 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
end $$;

-- 전투 중 사용: 영력을 채워 직업 기술·술법을 이어 쓸 수 있게 한다
do $$ declare def text; nd text;
begin
  def := pg_get_functiondef('public.world_battle_action(text, text)'::regprocedure);
  if position('spirit_tea' in def) > 0 then return; end if;
  nd := replace(def, 'IF it NOT IN (''tonic'', ''herbal_extract'', ''herb'', ''ward_talisman'') THEN',
    'IF it NOT IN (''tonic'', ''herbal_extract'', ''herb'', ''ward_talisman'', ''spirit_tea'', ''clear_spirit_pill'', ''spirit_qi_pill'', ''moonlight_essence'', ''heavenly_dew'') THEN');
  nd := replace(nd, 'IF it = ''ward_talisman'' THEN',
    'IF it IN (''spirit_tea'', ''clear_spirit_pill'', ''spirit_qi_pill'', ''moonlight_essence'', ''heavenly_dew'') THEN
      heal := CASE it WHEN ''spirit_tea'' THEN 10 WHEN ''clear_spirit_pill'' THEN 20 WHEN ''spirit_qi_pill'' THEN 35 WHEN ''moonlight_essence'' THEN 55 ELSE 80 END;
      IF c.job_key = ''medic'' THEN heal := round(heal * 1.4); END IF;
      heal := round(heal * (1 + public.world_status_effect_total(''healing_pct'') / 100.0));
      sp := least(100, sp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || ''을(를) 써 영력 '' || heal || '' 회복'');
    ELSIF it = ''ward_talisman'' THEN');
  if position('''heavenly_dew'') THEN' in nd) = 0 or position('sp := least(100, sp + heal);' in nd) = 0 or position('ELSIF it = ''ward_talisman'' THEN' in nd) = 0 then
    raise exception 'world_battle_action 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
end $$;

select 'ok' as result,
  (select count(*) from public.world_item_catalog where item_id in ('spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew')) as items,
  (select count(*) from public.world_crafting_recipes where output_item in ('spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew')) as recipes;
