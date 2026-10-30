-- 7.4.0 바다 낚시 넓히기(사용자 요청): 흑련회·천명원·적월교·북령맹·남명회 해안에 바다 낚시터 다섯 곳, 바다 어종 13종,
-- 요리 9가지·손질·기름/먹/독낭·말린 생선포·낚싯대·수조 같은 기존 낚시 연결에 바다 어종을 잇고, 바다 낚시 칭호 넷.
-- 어종에 grounds(그 낚시터에서만 나옴, 비우면 같은 물 어디서나)를 더해 지역 고유 어종을 둔다.

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;

-- ① 어종이 나오는 낚시터 제한
alter table public.world_fish_species add column if not exists grounds text[];

-- ② 바다 낚시터 다섯 곳(모두 지도 해안에 닿은 지역)
insert into public.world_fish_grounds(region_id, habitat, ground_name, description) values
  ('hidden_bazaar', 'sea', '십삼문 밀수 부두', '암시장 뒤편 썩은 말뚝 부두. 밤배가 드나드는 먹빛 물에 낯선 물고기가 꼬입니다.'),
  ('frost_valley', 'sea', '빙혼곡 얼음 해안', '골짜기가 끝나는 곳에 얼어붙은 바다가 열립니다. 얼음 틈으로 찬 바다 물고기가 올라옵니다.'),
  ('crimson_mine', 'sea', '주혈 광산 폐선창', '광석을 실어 내던 옛 선창. 붉은 녹물이 바다로 흘러들어 가시 돋친 물고기가 모입니다.'),
  ('red_moon_fort', 'sea', '월식성 바위 해안', '성벽 아래 검은 바위 해안. 달이 가려지는 밤이면 물밑에서 넓은 그림자가 움직입니다.'),
  ('star_observatory', 'sea', '관성대 별빛 벼랑', '관성대 벼랑 아래로 별빛이 쏟아지는 바다. 맑은 밤이면 물 위에도 별자리가 비칩니다.')
on conflict (region_id) do nothing;

-- ③ 바다 어종 13종(물품과 도감)
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, equipment_traits, crafting_specialization) values
  ('filefish', '쥐치', 'material', 1, '입이 작고 껍질이 질긴 갯바위 물고기. 말려 두면 동무들이 좋아합니다.', true, true, 8, 20, 1, '{}', '{}', 'cooking'),
  ('jack_mackerel', '전갱이', 'material', 1, '물마루를 따라 떼로 몰려다니는 등 푸른 물고기.', true, true, 9, 20, 12, '{}', '{}', 'cooking'),
  ('black_rockfish', '우럭', 'material', 2, '땅거미가 지면 바위 그늘에서 나오는 검은 볼락. 매운탕감입니다.', true, true, 22, 20, 5, '{}', '{}', 'cooking'),
  ('flounder', '광어', 'material', 2, '모래 바닥에 납작 엎드려 먹이를 기다립니다. 회로 먹으면 쫄깃합니다.', true, true, 26, 20, 9, '{}', '{}', 'cooking'),
  ('red_scorpionfish', '붉은 쏨뱅이', 'material', 2, '등지느러미 가시에 독이 있습니다. 광산 녹물이 흘러드는 바다를 좋아합니다.', true, true, 28, 20, 12, '{}', '{}', 'cooking'),
  ('spanish_mackerel', '삼치', 'material', 2, '삭풍이 부는 날 먹이를 쫓아 수면을 가르는 긴 물고기.', true, true, 30, 20, 15, '{}', '{}', 'cooking'),
  ('ink_greenling', '먹빛 노래미', 'material', 3, '십삼문 부두 밑 먹물 같은 물에서만 삽니다. 몸에서 먹 냄새가 나고, 짜내면 봉인 먹이 됩니다.', true, true, 70, 10, 9, '{}', '{}', 'cooking'),
  ('cod', '대구', 'material', 3, '얼음 바다의 큰 입. 눈 오는 날 깊은 곳에서 올라옵니다.', true, true, 80, 10, 11, '{}', '{}', 'cooking'),
  ('eclipse_skate', '월식 홍어', 'material', 3, '월식성 바위 해안의 홍어. 달이 가려진 밤에 날개를 폅니다. 삭혀 먹으면 정신이 번쩍 듭니다.', true, true, 85, 10, 15, '{}', '{}', 'cooking'),
  ('yellowtail', '방어', 'material', 3, '새벽 물살을 거슬러 오르는 살진 방어.', true, true, 90, 10, 18, '{}', '{}', 'cooking'),
  ('grouper', '다금바리', 'material', 4, '안개 낀 날에만 깊은 바위굴에서 나오는 귀한 물고기. 낚싯대 장인들이 뼈를 탐냅니다.', true, true, 220, 5, 20, '{}', '{}', 'cooking'),
  ('starlit_marlin', '성하 청새치', 'material', 4, '맑은 밤 별빛을 따라 관성대 벼랑 아래로 올라오는 청새치. 주둥이 뼈가 별빛처럼 곧습니다.', true, true, 260, 5, 25, '{}', '{}', 'cooking'),
  ('sea_dotdom', '해룡 돗돔', 'material', 5, '삭풍이 몰아치는 날 단 한 번 떠오른다는 바다의 주인. 비늘마다 파도 무늬가 새겨져 있습니다.', true, true, 800, 5, 24, '{}', '{}', 'cooking')
on conflict (item_id) do nothing;

insert into public.world_fish_species(fish_id, fish_name, habitat, rarity, min_level, phase, weather, size_min, size_max, description, sort, active, grounds) values
  ('filefish', '쥐치', 'sea', 'common', 1, null, null, 10, 25, '갯바위 어디서나 잡히는 질긴 껍질의 물고기.', 38, true, null),
  ('jack_mackerel', '전갱이', 'sea', 'common', 12, null, null, 15, 35, '물마루를 따라 떼로 몰려다닙니다.', 39, true, null),
  ('black_rockfish', '우럭', 'sea', 'uncommon', 5, 'dusk', null, 20, 50, '땅거미가 지면 바위 그늘에서 나옵니다.', 40, true, null),
  ('flounder', '광어', 'sea', 'uncommon', 9, null, null, 30, 80, '모래 바닥에 납작 엎드려 기다립니다.', 41, true, null),
  ('red_scorpionfish', '붉은 쏨뱅이', 'sea', 'uncommon', 12, null, null, 15, 35, '가시에 독이 있습니다. 녹물 흐르는 바다를 좋아합니다.', 42, true, array['crimson_mine', 'ash_coast']),
  ('spanish_mackerel', '삼치', 'sea', 'uncommon', 15, null, 'wind', 50, 110, '삭풍이 부는 날 수면을 가릅니다.', 43, true, null),
  ('ink_greenling', '먹빛 노래미', 'sea', 'rare', 9, 'night', null, 20, 45, '십삼문 부두 밑 먹빛 물에서만 삽니다.', 44, true, array['hidden_bazaar']),
  ('cod', '대구', 'sea', 'rare', 11, null, 'snow', 40, 100, '눈 오는 날 얼음 바다 깊은 곳에서 올라옵니다.', 45, true, array['frost_valley', 'tide_gate']),
  ('eclipse_skate', '월식 홍어', 'sea', 'rare', 15, 'night', null, 50, 120, '달이 가려진 밤 날개를 폅니다.', 46, true, array['red_moon_fort']),
  ('yellowtail', '방어', 'sea', 'rare', 18, 'dawn', null, 60, 120, '새벽 물살을 거슬러 오릅니다.', 47, true, null),
  ('grouper', '다금바리', 'sea', 'epic', 20, null, 'fog', 50, 110, '안개 낀 날에만 바위굴에서 나옵니다.', 48, true, null),
  ('starlit_marlin', '성하 청새치', 'sea', 'epic', 25, 'night', 'clear', 120, 260, '맑은 밤 별빛을 따라 벼랑 아래로 올라옵니다.', 49, true, array['star_observatory']),
  ('sea_dotdom', '해룡 돗돔', 'sea', 'legendary', 24, null, 'wind', 120, 220, '삭풍이 몰아치는 날 단 한 번 떠오르는 바다의 주인.', 50, true, null)
on conflict (fish_id) do nothing;

-- ④ 요리 9가지(먹는 효과는 아래 world_use_item에 같은 값)
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, minimum_level, required_stats, equipment_traits, crafting_specialization) values
  ('rockfish_stew', '우럭 매운탕', 'consumable', 2, '우럭을 약초와 숯불에 얼큰하게 끓였습니다. 체력 +45·정신 +10·한기 치료, 속이 따뜻함.', true, true, 110, 10, 5, '{}', '{}', 'cooking'),
  ('flounder_sashimi', '광어회', 'consumable', 2, '광어를 얇게 떠낸 회. 체력 +35·정신 +15, 기운 충천.', true, true, 90, 10, 9, '{}', '{}', 'cooking'),
  ('mackerel_grill', '삼치구이', 'consumable', 2, '삼치를 숯불에 구웠습니다. 체력 +45·영력 +15, 든든함.', true, true, 120, 10, 15, '{}', '{}', 'cooking'),
  ('cod_soup', '대구탕', 'consumable', 3, '대구를 약제와 맑게 끓인 탕. 체력 +60·정신 +15·한기 치료, 속이 따뜻함·기운 충천.', true, true, 220, 5, 11, '{}', '{}', 'cooking'),
  ('skate_ferment', '삭힌 홍어', 'consumable', 3, '월식 홍어를 약초에 묻어 삭혔습니다. 코를 찌르는 냄새에 정신이 번쩍 듭니다. 정신 +30·침식 -10·심신 동요 치료, 기운 충천.', true, true, 160, 5, 15, '{}', '{}', 'cooking'),
  ('yellowtail_sashimi', '방어회', 'consumable', 3, '기름진 방어를 두껍게 썬 회. 체력 +50·정신 +15, 바다의 복·기운 충천.', true, true, 150, 5, 18, '{}', '{}', 'cooking'),
  ('grouper_steam', '다금바리 찜', 'consumable', 4, '다금바리를 영초 차와 약제로 쪄 냈습니다. 체력 +80·정신 +30·침식 -10, 속이 따뜻함·기운 충천.', true, true, 400, 3, 20, '{}', '{}', 'cooking'),
  ('marlin_grill', '청새치 별빛구이', 'consumable', 4, '성하 청새치를 영초 차를 끼얹어 구웠습니다. 체력 +80·정신 +30·영력 +40, 바다의 복·기운 충천.', true, true, 380, 3, 25, '{}', '{}', 'cooking'),
  ('haeryong_feast', '해룡 어보찜', 'consumable', 5, '해룡 돗돔을 응축 영핵과 약제로 찐 잔칫상. 체력 +100·정신 +50·영력 +50·침식 -20, 기운 충천·바다의 복·속이 따뜻함·든든함.', true, true, 1300, 3, 24, '{}', '{}', 'cooking')
on conflict (item_id) do nothing;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field) values
  -- 손질(손질한 생선은 생선구이·생선죽·말린 생선포의 바탕)
  ('fillet_filefish', '쥐치 손질', 'fish_fillet', 1, '{"filefish": 1}', 'field_knife', 1, '십삼문 암시장', '쥐치를 손질해 생선살을 얻습니다.', 1, null, 1, 0, null, 1, 'cooking'),
  ('fillet_jack', '전갱이 손질', 'fish_fillet', 1, '{"jack_mackerel": 1}', 'field_knife', 1, '잔불촌', '전갱이를 손질해 생선살을 얻습니다.', 1, null, 1, 0, null, 1, 'cooking'),
  ('fillet_black_rockfish', '우럭 손질', 'fish_fillet', 2, '{"black_rockfish": 1}', 'field_knife', 1, '구름나루', '우럭 한 마리에서 생선살 둘이 나옵니다.', 1, null, 1, 0, null, 1, 'cooking'),
  ('fillet_flounder', '광어 손질', 'fish_fillet', 2, '{"flounder": 1}', 'field_knife', 1, '십삼문 암시장', '광어 한 마리에서 생선살 둘이 나옵니다.', 1, null, 1, 0, null, 1, 'cooking'),
  -- 요리
  ('cook_rockfish_stew', '우럭 매운탕', 'rockfish_stew', 1, '{"black_rockfish": 1, "herb": 1, "charcoal": 1}', 'field_knife', 1, '구름나루', '우럭을 약초·숯불로 얼큰하게 끓입니다.', 5, null, 2, 0, null, 1, 'cooking'),
  ('cook_flounder_sashimi', '광어회', 'flounder_sashimi', 1, '{"flounder": 1}', 'field_knife', 1, '십삼문 암시장', '광어를 얇게 떠냅니다.', 9, null, 3, 0, null, 1, 'cooking'),
  ('cook_mackerel_grill', '삼치구이', 'mackerel_grill', 1, '{"spanish_mackerel": 1, "charcoal": 1}', 'field_knife', 1, '잔불촌', '삼치를 숯불에 굽습니다.', 15, null, 2, 0, null, 1, 'cooking'),
  ('cook_cod_soup', '대구탕', 'cod_soup', 1, '{"cod": 1, "medicine_base": 1, "herb": 1}', 'field_knife', 1, '철벽 고찰', '대구를 약제와 맑게 끓입니다.', 11, null, 3, 0, null, 1, 'cooking'),
  ('cook_skate_ferment', '홍어 삭히기', 'skate_ferment', 1, '{"eclipse_skate": 1, "herb": 1}', 'field_knife', 1, '백골 장터', '월식 홍어를 약초에 묻어 삭힙니다.', 15, null, 3, 0, null, 1, 'cooking'),
  ('cook_yellowtail_sashimi', '방어회', 'yellowtail_sashimi', 1, '{"yellowtail": 1}', 'field_knife', 1, '구름나루', '방어를 두껍게 썹니다.', 18, null, 3, 0, null, 1, 'cooking'),
  ('cook_grouper_steam', '다금바리 찜', 'grouper_steam', 1, '{"grouper": 1, "spirit_tea": 1, "medicine_base": 1}', 'field_knife', 1, '잔불촌', '다금바리를 영초 차와 약제로 찝니다.', 20, null, 4, 0, null, 1, 'cooking'),
  ('cook_marlin_grill', '청새치 별빛구이', 'marlin_grill', 1, '{"starlit_marlin": 1, "charcoal": 1, "spirit_tea": 1}', 'field_knife', 1, '무극 관성대', '성하 청새치에 영초 차를 끼얹어 굽습니다.', 25, null, 4, 0, null, 1, 'cooking'),
  ('cook_haeryong_feast', '해룡 어보찜', 'haeryong_feast', 1, '{"sea_dotdom": 1, "spirit_core": 1, "medicine_base": 1}', 'field_knife', 1, '구등대 군도', '해룡 돗돔을 응축 영핵·약제와 찝니다.', 24, null, 5, 0, null, 1, 'cooking'),
  -- 기존 낚시 연결: 봉인 먹·독낭·말린 생선포·낚싯대·수조
  ('ink_greenling_ink', '노래미 먹 짜기', 'sealing_ink', 2, '{"ink_greenling": 1}', null, 1, '십삼문 암시장', '먹빛 노래미의 먹물로 봉인 먹을 만듭니다.', 9, null, 2, 0, null, 1, 'sealing'),
  ('scorpion_venom', '쏨뱅이 독낭 떼기', 'venom_gland', 1, '{"red_scorpionfish": 2}', 'field_knife', 1, '잔불촌', '붉은 쏨뱅이 가시에서 독낭을 떼어 냅니다.', 12, null, 2, 0, null, 1, 'alchemy'),
  ('r_treat_filefish', '쥐치포 말리기', 'treat_fish', 3, '{"filefish": 2}', null, 1, null, '쥐치를 말려 동무 별미(말린 생선포)를 만듭니다.', 1, null, 1, 0, null, 1, 'cooking'),
  ('r_lt_rod_4_sea', '바다 낚싯대(다금바리 뼈)', 'lt_rod_4', 1, '{"spirit_bark": 1, "grouper": 2, "spirit_thread": 2}', null, 1, '잔불촌', '다금바리 뼈로 낚싯대 허리를 받칩니다. 은린어 대신 쓰는 바다 제작법.', 17, null, 4, 0, null, 1, 'carpentry'),
  ('r_lt_rod_5_sea', '바다 낚싯대(청새치 주둥이)', 'lt_rod_5', 1, '{"sky_feather": 1, "starlit_marlin": 2, "reinforced_lumber": 2}', null, 1, '무극 관성대', '청새치 주둥이 뼈로 낚싯대 끝을 곧게 세웁니다. 비늘잉어 대신 쓰는 바다 제작법.', 24, null, 5, 0, null, 1, 'carpentry'),
  ('r_lt_rod_6_sea', '바다 낚싯대(해룡 비늘)', 'lt_rod_6', 1, '{"reed_silk": 3, "gwiheo_pearl": 1, "sea_dotdom": 1}', null, 1, '반요촌', '해룡 돗돔 비늘을 감아 귀허의 물살도 버티게 합니다. 흑룡어 대신 쓰는 바다 제작법.', 34, null, 6, 0, null, 1, 'carpentry'),
  ('r_hf_aquarium_sea', '물고기 수조(광어)', 'hf_aquarium', 1, '{"ore": 2, "flounder": 1, "spirit_glass": 1, "reinforced_lumber": 1}', null, 1, null, '광어를 넣은 수조. 금빛 잉어 대신 바다 물고기로 꾸밉니다.', 15, null, 3, 0, null, 1, '목공')
on conflict (recipe_id) do nothing;

-- ⑤ 낚시: 어종의 낚시터 제한
select pg_temp.yh_patch('public.world_fish()',
  'where s.habitat = g.habitat and s.active and s.min_level <= c.level + 2',
  'where s.habitat = g.habitat and s.active and s.min_level <= c.level + 2 and (s.grounds is null or r.region_id = any(s.grounds))');
select pg_temp.yh_patch('public.world_fish_spot()',
  '(select count(*) from public.world_fish_species s where s.habitat = g.habitat and s.active)',
  '(select count(*) from public.world_fish_species s where s.habitat = g.habitat and s.active and (s.grounds is null or r.region_id = any(s.grounds)))');
select pg_temp.yh_patch('public.world_fish_spot()',
  'where l.owner_id = uid and s.habitat = g.habitat)',
  'where l.owner_id = uid and s.habitat = g.habitat and (s.grounds is null or r.region_id = any(s.grounds)))');
select pg_temp.yh_patch('public.world_fish_codex()',
  '''phase'', s.phase, ''weather''',
  '''phase'', s.phase, ''where'', (select jsonb_agg(r2.region_name order by r2.min_level) from public.world_map_regions r2 where r2.region_id = any(s.grounds)), ''weather''');
select pg_temp.yh_patch('public.world_item_sources(text)',
  'where sp.fish_id = p_item and sp.active)',
  'where sp.fish_id = p_item and sp.active and (sp.grounds is null or fg.region_id = any(sp.grounds)))');

-- ⑥ 먹는 효과
select pg_temp.yh_patch('public.world_use_item(text)',
  '''moss_porridge'', ''bark_stew'')',
  '''moss_porridge'', ''bark_stew'', ''rockfish_stew'', ''flounder_sashimi'', ''mackerel_grill'', ''cod_soup'', ''skate_ferment'', ''yellowtail_sashimi'', ''grouper_steam'', ''marlin_grill'', ''haeryong_feast'')');
select pg_temp.yh_patch('public.world_use_item(text)',
  'WHEN ''bark_stew'' THEN hp := 50; mn := 10; buffs := ARRAY[''vigor''];',
  'WHEN ''bark_stew'' THEN hp := 50; mn := 10; buffs := ARRAY[''vigor''];
    WHEN ''rockfish_stew'' THEN hp := 45; mn := 10; cures := ARRAY[''cold'']; buffs := ARRAY[''warm_belly''];
    WHEN ''flounder_sashimi'' THEN hp := 35; mn := 15; buffs := ARRAY[''vigor''];
    WHEN ''mackerel_grill'' THEN hp := 45; spg := 15; buffs := ARRAY[''well_fed''];
    WHEN ''cod_soup'' THEN hp := 60; mn := 15; cures := ARRAY[''cold'']; buffs := ARRAY[''warm_belly'', ''vigor''];
    WHEN ''skate_ferment'' THEN mn := 30; er := 10; cures := ARRAY[''shaken'']; buffs := ARRAY[''vigor''];
    WHEN ''yellowtail_sashimi'' THEN hp := 50; mn := 15; buffs := ARRAY[''sea_luck'', ''vigor''];
    WHEN ''grouper_steam'' THEN hp := 80; mn := 30; er := 10; buffs := ARRAY[''warm_belly'', ''vigor''];
    WHEN ''marlin_grill'' THEN hp := 80; mn := 30; spg := 40; buffs := ARRAY[''sea_luck'', ''vigor''];
    WHEN ''haeryong_feast'' THEN hp := 100; mn := 50; spg := 50; er := 20; buffs := ARRAY[''vigor'', ''sea_luck'', ''warm_belly'', ''well_fed''];');

-- ⑦ 바다 낚시 칭호 넷(분류 낚시)
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('sea_angler', '갯바위 낚시꾼', 'leaf', '파도 소리를 들으며 찌를 기다리는 데 익숙해졌습니다.', '바다에서 물고기 30마리 낚기',
   '{"fish_bite_pct": 5}', true, false, '{"ev": "fish", "p": {"caught": true, "habitat": "sea"}, "n": 30}', 108, '낚시', 2),
  ('tide_reader', '물마루를 읽는 자', 'leaf', '물마루의 결만 보고도 큰 물고기가 어디 있는지 압니다.', '바다에서 명품 물고기 3마리 낚기',
   '{"fish_rare_pct": 6, "fish_size_pct": 4}', true, false, '{"ev": "fish", "p": {"habitat": "sea", "rarity": "epic"}, "n": 3}', 109, '낚시', 3),
  ('nine_harbors', '아홉 포구 나그네', 'route', '바다를 낀 아홉 포구에서 모두 찌를 드리웠습니다.', '바다 낚시터 아홉 곳에서 모두 한 마리 이상 낚기',
   '{"fish_rare_pct": 8, "fish_bite_pct": 5, "gather_qty_pct": 4}', true, false,
   '{"all": [{"ev": "fish", "p": {"caught": true, "region_id": "salt_village"}}, {"ev": "fish", "p": {"caught": true, "region_id": "hidden_bazaar"}}, {"ev": "fish", "p": {"caught": true, "region_id": "ash_coast"}}, {"ev": "fish", "p": {"caught": true, "region_id": "frost_valley"}}, {"ev": "fish", "p": {"caught": true, "region_id": "crimson_mine"}}, {"ev": "fish", "p": {"caught": true, "region_id": "nine_lighthouse"}}, {"ev": "fish", "p": {"caught": true, "region_id": "red_moon_fort"}}, {"ev": "fish", "p": {"caught": true, "region_id": "tide_gate"}}, {"ev": "fish", "p": {"caught": true, "region_id": "star_observatory"}}]}',
   110, '낚시', 4),
  ('sea_dragon', '해룡을 낚은 자', 'spark', '바다의 주인을 낚싯줄로 끌어올렸습니다.', '숨겨진 조건',
   '{"fish_rare_pct": 10, "fish_size_pct": 10, "fish_bite_pct": 5}', true, true, '{"ev": "fish", "p": {"fish": "sea_dotdom"}, "n": 1}', 111, '낚시', 5)
on conflict (title_key) do nothing;

update public.world_app_meta set value = '20261103223000' where key = 'db_version';
