-- 제작 세분화: 분야별 분류 · 전문화가 실제로 의미 있게 · 연금·요리 보충 · 요리 전문화와 요리 숙련
-- 1) 제작법마다 분야(world_crafting_recipes.craft_field)를 정한다.
--    단조(근접 무기·쇠 갑옷·주괴·쇠 도구) · 목공(원거리 무기·부적목 가공·낚싯대) · 법구 공예(술법 무기·호신패·나침반)
--    · 봉인 공예(부적·봉인 먹·각인판·호신부·탈) · 직조(실·도포·관모·노리개) · 가죽 공예(가죽 갑옷·신·망태·짐틀)
--    · 연금(회복약·약재·영유리) · 요리(손질·요리·노정 건량)
-- 2) 생활 전문화 효과: 지금까지는 대부분 제작법이 분야가 없어 어느 분야를 골라도 거의 모든 제작법에 품질 +8이었다.
--    → 자기 분야 제작법 품질 +12, 종합 제작은 모든 분야 +4, 다른 분야 0.
-- 3) 요리를 제작 전문화에 넣고, 요리 숙련(cooking_xp·cooking_rank, 1~20단계)을 따로 둔다.
--    요리 제작법은 요리 숙련으로 품질을 계산하고, 만들 때마다 요리 경험(10 + 난이도×5)을 얻는다.
-- 4) 보충(쓸모 있는 쪽으로): 연금 10 → 15(회춘단·대환단·응축 영핵 합성·청정수·안신탕), 요리 13 → 15(약초 생선찜·영기 국밥).
--    회춘단·대환단은 전투 중에도 쓴다. 값은 재료값 × 1.1 이상(물가 규칙).
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 결과가 같다.

alter table public.world_crafting_recipes add column if not exists craft_field text;
alter table public.world_characters add column if not exists cooking_xp int not null default 0;
alter table public.world_characters add column if not exists cooking_rank int not null default 1;

/* ── 새 물품과 제작법 ─────────────────────────────────── */
insert into public.world_item_catalog(item_id, item_name, category, tier, description, rarity, reference_price, stack_size, tradeable, minimum_level, crafting_specialization) values
 ('rejuv_pill', '회춘단', 'consumable', 3, '약초액을 졸여 빚은 환약. 상처와 독을 함께 다스린다. 전투 중에도 삼킬 수 있다.', 'rare', 370, 5, true, 8, null),
 ('grand_pill', '대환단', 'consumable', 4, '회춘단에 영핵과 영맥 수피를 더해 빚은 귀한 환약. 쓰러지기 직전의 몸도 일으킨다. 전투 중에도 쓴다.', 'epic', 980, 3, true, 16, null),
 ('purify_water', '청정수', 'consumable', 2, '갈대 즙에 영유리를 녹인 맑은 물. 몸에 스민 사기를 씻어 낸다.', 'uncommon', 260, 10, true, 5, null),
 ('calm_brew', '안신탕', 'consumable', 2, '영초 차에 약초와 약제를 달인 탕약. 흔들린 마음을 가라앉힌다.', 'uncommon', 155, 10, true, 3, null),
 ('herb_fish_steam', '약초 생선찜', 'consumable', 2, '손질한 생선을 약초와 함께 찐 요리. 독기를 빼고 기운을 북돋운다.', 'uncommon', 50, 10, true, 3, 'cooking'),
 ('spirit_gukbap', '영기 국밥', 'consumable', 2, '생선 국물에 노정 건량을 말고 영초 차를 곁들인 국밥. 몸과 마음과 영력을 고루 채운다.', 'uncommon', 100, 10, true, 5, 'cooking')
on conflict (item_id) do nothing;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, description, minimum_level, recipe_difficulty, craft_field) values
 ('brew_rejuv_pill', '회춘단 빚기', 'rejuv_pill', 1, '{"herbal_extract": 2, "medicine_base": 1, "moon_moss": 1}', '약초액을 졸여 회춘단을 빚는다.', 8, 3, 'alchemy'),
 ('brew_grand_pill', '대환단 빚기', 'grand_pill', 1, '{"rejuv_pill": 1, "spirit_core": 1, "spirit_bark": 1}', '회춘단에 영핵과 영맥 수피를 더해 대환단을 빚는다.', 16, 5, 'alchemy'),
 ('synth_spirit_core', '응축 영핵 합성', 'spirit_core', 2, '{"spirit_dust": 4, "spirit_glass": 1}', '요기 결정을 영유리에 가두어 응축 영핵 두 개를 만든다.', 12, 4, 'alchemy'),
 ('brew_purify_water', '청정수 달이기', 'purify_water', 1, '{"river_reed": 2, "spirit_glass": 1}', '갈대 즙에 영유리를 녹여 청정수를 만든다.', 5, 2, 'alchemy'),
 ('brew_calm', '안신탕 달이기', 'calm_brew', 1, '{"spirit_tea": 1, "herb": 2, "medicine_base": 1}', '영초 차에 약초와 약제를 넣고 달인다.', 3, 2, 'alchemy'),
 ('cook_herb_fish', '약초 생선찜 찌기', 'herb_fish_steam', 1, '{"fish_fillet": 2, "herb": 2}', '손질한 생선을 약초와 함께 찐다.', 3, 1, 'cooking'),
 ('cook_gukbap', '영기 국밥 말기', 'spirit_gukbap', 1, '{"fish_fillet": 1, "travel_ration": 1, "spirit_tea": 1}', '생선 국물에 노정 건량을 말고 영초 차를 곁들인다.', 5, 2, 'cooking')
on conflict (recipe_id) do nothing;

/* ── 분야 정하기 ─────────────────────────────────────── */
update public.world_crafting_recipes set craft_field = 'alchemy' where craft_field is null and recipe_id in ('clear_spirit_pill_recipe', 'extract_herb', 'heavenly_dew_recipe', 'make_medicine_base', 'melt_spirit_glass', 'moonlight_essence_recipe', 'recipe_field_tonic', 'spirit_qi_pill_recipe', 'spirit_tea_recipe', 'tonic_recipe');
update public.world_crafting_recipes set craft_field = 'artifice' where craft_field is null and recipe_id in ('make_bronze_charm_advanced', 'make_charm', 'make_spirit_compass', 'r_w_magic2_heavy', 'r_w_magic2_keen', 'r_w_magic2_silent', 'r_w_magic3_heavy', 'r_w_magic3_keen', 'r_w_magic3_silent', 'r_w_magic4_base', 'r_w_magic4_heavy', 'r_w_magic4_keen', 'r_w_magic4_silent', 'r_w_magic5_base', 'r_w_magic5_keen', 'recipe_monster_ward', 'recipe_spirit_compass', 'star_mirror_recipe', 'ward_fan_recipe');
update public.world_crafting_recipes set craft_field = 'carpentry' where craft_field is null and recipe_id in ('make_fishing_rod', 'make_lacquer', 'make_lumber', 'make_resin', 'make_spirit_rod', 'r_w_ranged2_heavy', 'r_w_ranged2_keen', 'r_w_ranged2_silent', 'r_w_ranged3_heavy', 'r_w_ranged3_keen', 'r_w_ranged3_silent', 'r_w_ranged4_base', 'r_w_ranged4_heavy', 'r_w_ranged4_keen', 'r_w_ranged4_silent', 'r_w_ranged5_base', 'r_w_ranged5_keen', 'reed_crossbow_recipe', 'reinforce_lumber', 'star_bow_recipe');
update public.world_crafting_recipes set craft_field = 'cooking' where craft_field is null and recipe_id in ('cook_bream_sashimi', 'cook_carp_broth', 'cook_eel_tonic', 'cook_fish_porridge', 'cook_grilled_fish', 'cook_spicy_stew', 'fillet_loach', 'fillet_mandarin', 'fillet_minnow', 'fillet_rockfish', 'fillet_shad', 'fillet_smelt', 'make_travel_ration');
update public.world_crafting_recipes set craft_field = 'leatherwork' where craft_field is null and recipe_id in ('make_reinforced_leather', 'make_wayfarer_pack', 'r_a2_light', 'r_a2_shade', 'r_a3_light', 'r_a3_shade', 'r_a4_light', 'r_a4_shade', 'r_a5_light', 'r_s2_road', 'r_s2_sturdy', 'r_s2_swift', 'r_s3_road', 'r_s3_sturdy', 'r_s3_swift', 'r_s4_road', 'r_s4_sturdy', 'r_s4_swift', 'r_s5_swift', 'r_t2_gather', 'scale_vest_recipe');
update public.world_crafting_recipes set craft_field = 'sealing' where craft_field is null and recipe_id in ('make_fine_paper', 'make_rune_plate', 'make_sealing_ink', 'r_k2_awe', 'r_k2_ghost', 'r_k2_hide', 'r_k3_awe', 'r_k3_ghost', 'r_k3_hide', 'r_k4_awe', 'r_k4_ghost', 'r_k4_hide', 'r_k5_hide', 'r_m2_purify', 'r_m2_spell', 'r_m2_ward', 'r_m3_purify', 'r_m3_spell', 'r_m3_ward', 'r_m4_purify', 'r_m4_spell', 'r_m4_ward', 'r_m5_spell', 'recipe_revival_charm', 'seal_knife_recipe', 'ward_recipe');
update public.world_crafting_recipes set craft_field = 'smithing' where craft_field is null and recipe_id in ('guard_spear_recipe', 'make_steel', 'moon_blade_recipe', 'pick_upgrade', 'r_a2_iron', 'r_a3_iron', 'r_a4_iron', 'r_t3_gather', 'r_t4_gather', 'r_t5_gather', 'r_w_melee2_heavy', 'r_w_melee2_keen', 'r_w_melee2_silent', 'r_w_melee3_heavy', 'r_w_melee3_keen', 'r_w_melee3_silent', 'r_w_melee4_base', 'r_w_melee4_heavy', 'r_w_melee4_keen', 'r_w_melee4_silent', 'r_w_melee5_base', 'r_w_melee5_keen', 'refine_iron', 'repair_kit_recipe', 'spirit_sickle_recipe', 'thunder_glaive_recipe');
update public.world_crafting_recipes set craft_field = 'weaving' where craft_field is null and recipe_id in ('make_talisman_thread', 'r_a2_robe', 'r_a3_robe', 'r_a4_robe', 'r_h2_calm', 'r_h2_guard', 'r_h2_wise', 'r_h3_calm', 'r_h3_guard', 'r_h3_wise', 'r_h4_calm', 'r_h4_guard', 'r_h4_wise', 'r_h5_calm', 'r_n2_keen', 'r_n2_luck', 'r_n2_plenty', 'r_n3_keen', 'r_n3_luck', 'r_n3_plenty', 'r_n4_keen', 'r_n4_luck', 'r_n4_plenty', 'r_n5_keen', 'r_n5_luck', 'robe_recipe', 'spin_spirit_thread', 'spirit_mail_recipe');

/* ── 제작: 전문화 품질·요리 숙련 ─────────────────────── */
grant fn_owner_18452 to postgres with inherit true;
grant update (cooking_xp, cooking_rank) on public.world_characters to fn_owner_18452;
do $$
declare d text; a text;
begin
  d := pg_get_functiondef('public.world_craft_item'::regproc);
  if position('craft_field' in d) > 0 then return; end if;
  a := 'case when c.crafting_profession is not null and (r.required_skill is null or c.crafting_profession=r.required_skill) then 8 else 0 end';
  if position(a in d) = 0 then raise exception '제작 품질 줄(전문화)을 찾지 못했습니다'; end if;
  d := replace(d, a, 'case when c.crafting_profession = r.craft_field then 12 when c.crafting_profession = ''general'' then 4 else 0 end');
  a := '+c.crafting_rank*3+';
  if position(a in d) = 0 then raise exception '제작 품질 줄(숙련)을 찾지 못했습니다'; end if;
  d := replace(d, a, '+(case when r.craft_field = ''cooking'' then coalesce(c.cooking_rank, 1) else c.crafting_rank end)*3+');
  a := 'update public.world_characters set inventory=inv,crafting_successes=crafting_successes+1,crafting_quality=crafting_quality+quality,updated_at=now() where owner_id=uid;';
  if position(a in d) = 0 then raise exception '제작 결과 줄을 찾지 못했습니다'; end if;
  d := replace(d, a, a || chr(10) ||
    ' if r.craft_field = ''cooking'' then update public.world_characters set cooking_xp = cooking_xp + 10 + r.recipe_difficulty * 5,' ||
    ' cooking_rank = least(20, 1 + (cooking_xp + 10 + r.recipe_difficulty * 5) / 120) where owner_id = uid; end if;');
  execute d;
end $$;
grant fn_owner_18452 to postgres with inherit false;

-- 생활 전문화에 요리
do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_set_life_profession_v2'::regproc);
  if position('''cooking''' in d) = 0 then
    if position($q$'leatherwork', 'artifice')$q$ in d) = 0 then raise exception '전문화 목록 줄을 찾지 못했습니다'; end if;
    execute replace(d, $q$'leatherwork', 'artifice')$q$, $q$'leatherwork', 'artifice', 'cooking')$q$);
  end if;
end $$;

-- 가방 › 제작 화면에 분야를 넘긴다
do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_inventory_snapshot'::regproc);
  if position('craft_field' in d) = 0 then
    if position($q$'required_skill_rank',r.required_skill_rank)$q$ in d) = 0 then raise exception '가방 정보의 제작법 줄을 찾지 못했습니다'; end if;
    execute replace(d, $q$'required_skill_rank',r.required_skill_rank)$q$, $q$'required_skill_rank',r.required_skill_rank,'field',r.craft_field)$q$);
  end if;
end $$;

/* ── 새 약·요리 쓰기(가방·전투) ──────────────────────── */
do $$
declare d text; a text;
begin
  d := pg_get_functiondef('public.world_use_item'::regproc);
  if position('rejuv_pill' in d) = 0 then
    a := $q$'moonlight_essence', 'heavenly_dew') THEN RAISE EXCEPTION '쓸 수 없는 물품입니다.'; END IF;$q$;
    if position(a in d) = 0 then raise exception '물품 쓰기 목록 줄을 찾지 못했습니다'; end if;
    d := replace(d, a, $q$'moonlight_essence', 'heavenly_dew', 'rejuv_pill', 'grand_pill', 'purify_water', 'calm_brew', 'herb_fish_steam', 'spirit_gukbap') THEN RAISE EXCEPTION '쓸 수 없는 물품입니다.'; END IF;$q$);
    a := $q$WHEN 'grilled_fish' THEN hp := 25; buffs := ARRAY['well_fed'];$q$;
    if position(a in d) = 0 then raise exception '물품 효과 줄을 찾지 못했습니다'; end if;
    d := replace(d, a, $q$WHEN 'rejuv_pill' THEN hp := 60; cures := ARRAY['bleeding', 'burned', 'sprain', 'poisoned'];
    WHEN 'grand_pill' THEN hp := 100; mn := 20; cures := ARRAY['shaken', 'exhausted'];
    WHEN 'purify_water' THEN mn := 5; er := 20; cures := ARRAY['erosion_whisper'];
    WHEN 'calm_brew' THEN mn := 30; cures := ARRAY['shaken', 'fatigue'];
    WHEN 'herb_fish_steam' THEN hp := 40; cures := ARRAY['poisoned']; buffs := ARRAY['vigor'];
    WHEN 'spirit_gukbap' THEN hp := 30; mn := 15; spg := 15; stam := 3; buffs := ARRAY['warm_belly'];
    $q$ || a);
    execute d;
  end if;
  d := pg_get_functiondef('public.world_battle_action'::regproc);
  if position('rejuv_pill' in d) = 0 then
    a := $q$IF it NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman', 'spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew') THEN$q$;
    if position(a in d) = 0 then raise exception '전투 물품 목록 줄을 찾지 못했습니다'; end if;
    d := replace(d, a, $q$IF it NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman', 'spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew', 'rejuv_pill', 'grand_pill') THEN$q$);
    a := $q$heal := CASE it WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 ELSE 12 END;$q$;
    if position(a in d) = 0 then raise exception '전투 회복량 줄을 찾지 못했습니다'; end if;
    d := replace(d, a, $q$heal := CASE it WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 WHEN 'rejuv_pill' THEN 60 WHEN 'grand_pill' THEN 100 ELSE 12 END;$q$);
    execute d;
  end if;
end $$;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028080000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select coalesce(craft_field, '(없음)') as field, count(*) from public.world_crafting_recipes group by 1 order by 2 desc;
