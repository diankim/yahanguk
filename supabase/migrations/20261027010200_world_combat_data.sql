-- 전투·탐색 개편용 데이터: 탐색력, 전투 상태 열, 무기 계열(근접·원거리·술법), 방어구, 지역 요괴 추가·개명, 상태이상 치료법.

ALTER TABLE public.world_characters
  ADD COLUMN IF NOT EXISTS stamina integer NOT NULL DEFAULT 20,
  ADD COLUMN IF NOT EXISTS stamina_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS life_changed_at timestamptz;
GRANT SELECT (stamina, stamina_at, life_changed_at) ON public.world_characters TO authenticated;

ALTER TABLE public.world_active_encounters
  ADD COLUMN IF NOT EXISTS node_id uuid,
  ADD COLUMN IF NOT EXISTS mlevel integer,
  ADD COLUMN IF NOT EXISTS atk integer,
  ADD COLUMN IF NOT EXISTS def integer,
  ADD COLUMN IF NOT EXISTS rank text NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS intent text,
  ADD COLUMN IF NOT EXISTS fx jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS pfx jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS log jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS last_action_at timestamptz,
  ADD COLUMN IF NOT EXISTS result jsonb;

ALTER TABLE public.world_region_monsters ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'main';

-- 상태이상 치료법
ALTER TABLE public.world_status_catalog ADD COLUMN IF NOT EXISTS cure text, ADD COLUMN IF NOT EXISTS cure_items text[] NOT NULL DEFAULT '{}';
UPDATE public.world_status_catalog s SET cure = v.cure, cure_items = v.items FROM (VALUES
 ('bleeding','농축 약초액으로 상처를 묶거나, 안전지대에서 푹 쉬면 멎습니다.', ARRAY['herbal_extract']),
 ('erosion_whisper','정화 부적을 태우면 속삭임이 걷힙니다.', ARRAY['ward_talisman']),
 ('fatigue','약제 바탕을 달여 먹거나 휴식하면 풀립니다.', ARRAY['medicine_base']),
 ('overtrained','잠시 쉬거나 약제 바탕을 먹으면 풀립니다.', ARRAY['medicine_base']),
 ('sprain','농축 약초액을 바르거나 푹 쉬면 낫습니다.', ARRAY['herbal_extract']),
 ('stomach_upset','야령초를 씹으면 가라앉습니다.', ARRAY['herb']),
 ('burned','농축 약초액을 바르거나 푹 쉬면 아뭅니다.', ARRAY['herbal_extract']),
 ('cold','약제 바탕을 달여 먹거나 푹 쉬면 몸이 데워집니다.', ARRAY['medicine_base']),
 ('disoriented','잠시 쉬면 방향 감각이 돌아옵니다.', ARRAY[]::text[]),
 ('exhausted','약제 바탕을 먹거나 푹 쉬어야 회복됩니다.', ARRAY['medicine_base']),
 ('poisoned','야령초나 정화 부적으로 독기를 뺍니다.', ARRAY['herb','ward_talisman']),
 ('shaken','정화 부적이나 청심환으로 마음을 다잡거나 잠시 쉽니다.', ARRAY['ward_talisman','tonic'])
) v(k, cure, items) WHERE s.status_key = v.k;
UPDATE public.world_status_catalog SET cure = '이로운 효과입니다. 시간이 지나면 사라집니다.' WHERE polarity = 'positive';

-- 무기는 종류가 공격 방식을 정한다: melee 근접 · ranged 원거리 · magic 술법
INSERT INTO public.world_item_catalog(item_id, item_name, category, tier, description, stackable, minimum_level, equipment_traits, tradeable, reference_price, acquisition_difficulty)
VALUES
 ('iron_sword','월철 환도','weapon',1,'담금질한 월철 환도. 근접 공격을 한다. 갑각과 무리에 강하고 날거나 형체 없는 적에게 약하다.',false,1,'{"weapon_type":"melee","power":6,"trait":"근접"}',true,90,1),
 ('short_bow','대나무 단궁','weapon',1,'가벼운 대나무 활. 원거리 공격을 한다. 나는 적에게 강하고 치명타가 잘 난다.',false,1,'{"weapon_type":"ranged","power":5,"trait":"원거리"}',true,90,1),
 ('spirit_bell','영령 방울','weapon',1,'흔들면 영력이 울리는 방울. 술법 공격을 하며 영력을 조금 쓴다. 원령과 갑각에 강하다.',false,1,'{"weapon_type":"magic","power":5,"trait":"술법"}',true,90,1),
 ('guard_spear','순찰 장창','weapon',2,'순찰대가 쓰는 긴 창. 근접 공격.',false,5,'{"weapon_type":"melee","power":11,"trait":"근접"}',true,240,2),
 ('reed_crossbow','수향 쇠뇌','weapon',2,'수향연맹의 갈대 쇠뇌. 원거리 공격.',false,5,'{"weapon_type":"ranged","power":11,"trait":"원거리"}',true,240,2),
 ('ward_fan','결계 부채','weapon',2,'부적을 엮은 부채. 술법 공격.',false,5,'{"weapon_type":"magic","power":11,"trait":"술법"}',true,240,2),
 ('thunder_glaive','뇌철 언월도','weapon',3,'뇌철을 벼린 언월도. 근접 공격.',false,14,'{"weapon_type":"melee","power":20,"trait":"근접","combat_damage_pct":5}',true,900,4),
 ('star_bow','성진 장궁','weapon',3,'성진사를 먹인 장궁. 원거리 공격.',false,14,'{"weapon_type":"ranged","power":19,"trait":"원거리","combat_damage_pct":5}',true,900,4),
 ('star_mirror','천문 법경','weapon',3,'별빛을 담는 거울. 술법 공격.',false,14,'{"weapon_type":"magic","power":19,"trait":"술법","combat_damage_pct":5}',true,900,4),
 ('padded_coat','누비 전포','armor',1,'솜을 누빈 겉옷. 방어 3.',false,1,'{"defense":3,"trait":"방호"}',true,70,1),
 ('scale_vest','비늘 흉갑','armor',2,'수귀 비늘을 엮은 흉갑. 방어 7.',false,6,'{"defense":7,"trait":"방호"}',true,260,2),
 ('spirit_mail','영사 법의','armor',3,'영사로 짠 법의. 방어 12.',false,14,'{"defense":12,"trait":"방호","damage_reduction_pct":4}',true,950,4)
ON CONFLICT (item_id) DO NOTHING;
UPDATE public.world_item_catalog SET equipment_traits = '{"weapon_type":"melee","power":12,"trait":"근접","combat_damage_pct":5}',
  description = '요기를 벼려 만든 칼. 근접 공격.' WHERE item_id = 'moon_blade';
UPDATE public.world_item_catalog SET equipment_traits = '{"defense":5,"trait":"방호","damage_reduction_pct":4}' WHERE item_id = 'ward_robe';

-- 안전지대 상점: 1단계 무기·방어구는 어디서나, 2단계는 영역 거점 상점에서
INSERT INTO public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
SELECT s.shop_id, i.item_id, i.reference_price, 1, 3
FROM (SELECT DISTINCT shop_id FROM public.world_map_regions WHERE shop_id IS NOT NULL) s
CROSS JOIN (VALUES ('iron_sword'),('short_bow'),('spirit_bell'),('padded_coat')) x(item_id)
JOIN public.world_item_catalog i ON i.item_id = x.item_id
ON CONFLICT DO NOTHING;
INSERT INTO public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
SELECT s.shop_id, i.item_id, i.reference_price, 0, 2
FROM (VALUES ('frontier_market'),('river_market'),('south_market'),('north_market'),('underworld_market'),('astral_market')) s(shop_id)
CROSS JOIN (VALUES ('guard_spear'),('reed_crossbow'),('ward_fan'),('scale_vest')) x(item_id)
JOIN public.world_item_catalog i ON i.item_id = x.item_id
ON CONFLICT DO NOTHING;

-- 제작법: 2·3단계 무기와 방어구
UPDATE public.world_crafting_recipes SET required_location = '잿빛 들녘' WHERE required_location = '제4구역 · 야외 현장';
UPDATE public.world_crafting_recipes SET required_location = '폐쇄 사당' WHERE required_location = '제4구역 · 폐쇄 사당';
INSERT INTO public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill_rank)
VALUES
 ('guard_spear_recipe','순찰 장창 벼리기','guard_spear',1,'{"raw_iron":3,"lumber":2,"beast_bone":1}',NULL,1,'연무장·팔괘진','월철 촉을 부적목 자루에 박는다.',5,NULL,2,0,1),
 ('reed_crossbow_recipe','수향 쇠뇌 짜기','reed_crossbow',1,'{"river_reed":4,"lumber":2,"talisman_thread":2}',NULL,1,'구름나루','갈대 활대에 부적실 시위를 건다.',5,NULL,2,0,1),
 ('ward_fan_recipe','결계 부채 접기','ward_fan',1,'{"fine_paper":3,"ward_fragment":2,"talisman_thread":2}',NULL,1,'장서각 지하서고','결계 파편을 정제 황지에 눌러 붙인다.',5,NULL,2,0,1),
 ('thunder_glaive_recipe','뇌철 언월도 단조','thunder_glaive',1,'{"thunder_ore":3,"steel_ingot":2,"reinforced_lumber":2,"monster_core":1}',NULL,1,'철벽 고찰','뇌철을 벼락처럼 두드려 날을 세운다.',14,NULL,4,0,1),
 ('star_bow_recipe','성진 장궁 제작','star_bow',1,'{"star_sand":2,"spirit_bark":3,"spirit_thread":2,"sky_feather":1}',NULL,1,'무극 관성대','성진사를 먹인 활대를 영사로 감는다.',14,NULL,4,0,1),
 ('star_mirror_recipe','천문 법경 연마','star_mirror',1,'{"mirror_shard":2,"star_sand":2,"spirit_core":1,"sealing_ink":2}',NULL,1,'무극 관성대','귀경 파편을 갈아 별빛을 가둔다.',14,NULL,4,0,1),
 ('scale_vest_recipe','비늘 흉갑 엮기','scale_vest',1,'{"drowned_scale":4,"beast_hide":2,"talisman_thread":1}',NULL,1,'구름나루','수귀 비늘을 가죽에 겹쳐 꿰맨다.',6,NULL,2,0,1),
 ('spirit_mail_recipe','영사 법의 짓기','spirit_mail',1,'{"spirit_thread":4,"reinforced_leather":2,"ward_fragment":3}',NULL,1,'십삼문 암시장','영사를 겹겹이 짜 결계를 먹인다.',14,NULL,4,0,1)
ON CONFLICT (recipe_id) DO NOTHING;

-- 수호 변이체 → 지역마다 고유한 우두머리
UPDATE public.world_region_monsters m SET monster_name = v.nm, role = 'guardian', monster_type = '지역 우두머리',
  description = v.nm || '. 지역 깊은 곳을 지키는 우두머리입니다. 쓰러뜨리면 귀한 전리품을 남깁니다.'
FROM (VALUES
 ('ash_coast','잿비늘 해왕'),('ash_mountain','화구의 철갑귀'),('black_sand_temple','흑사 대법사'),('black_tide_rift','균열을 삼킨 자'),
 ('bone_market','해골 장주'),('burial_steps','만장 묘지기'),('crimson_mine','주혈 광맥왕'),('ember_village','숯불 속 그림자'),
 ('field_outskirts','들녘 잠복왕'),('forgotten_city','망국 근위장'),('frost_valley','서리 굴의 설귀'),('ghost_bamboo','대숲 독사녀'),
 ('glass_canyon','유리 갑각수'),('hidden_bazaar','숨은 문지기'),('hq_archive','서가 그림자'),('hq_dorm','객사 가위귀'),
 ('hq_training','팔괘진 목인장'),('hq_yard','정청 먹귀신'),('iron_monastery','종루 파계승'),('jade_pass','비취 수문장'),
 ('lantern_market','꺼진 등롱 노파'),('lotus_marsh','연못 독두꺼비'),('mirror_pavilion','거울 속 무희장'),('nine_lighthouse','꺼진 등대지기'),
 ('old_canal','수문 거머리왕'),('paper_bridge','백지 탈 무리'),('red_forest','단풍 독거미'),('red_moon_fort','월식 파계장'),
 ('red_plain','모래 매복귀'),('river_ferry','나루 물귀신'),('salt_village','염전 매복귀'),('sealed_abyss','사슬 끊는 자'),
 ('sealed_garden','연화원 봉인파쇄귀'),('shrine_ruins','산문 파쇄귀'),('sky_lake','호수 거울귀'),('star_observatory','별 먹는 망령'),
 ('sunken_district','잠긴 장터 수귀'),('sunken_palace','수궁 해일장'),('thunder_peak','벼락 산령'),('under_root','뿌리 속 매복자'),
 ('west_gate','성루 매복병'),('white_tower','탑 꼭대기 원령')
) v(rid, nm) WHERE m.monster_id = 'regional_' || v.rid || '_guardian';
UPDATE public.world_region_monsters SET mechanic_key = 'toxic' WHERE mechanic_key = 'venom';

-- 지역마다 흔히 마주치는 요괴 하나씩 추가
INSERT INTO public.world_region_monsters(monster_id, region_id, monster_name, monster_type, min_level, max_level, hp, attack_power, spawn_weight, description, drops, difficulty_rank, mechanic_key, role)
SELECT 'g_' || r.region_id, r.region_id, v.nm,
  CASE v.mech WHEN 'aerial' THEN '비행 요괴' WHEN 'swarm' THEN '무리 요괴' WHEN 'toxic' THEN '독충' WHEN 'armored' THEN '갑각 요괴'
    WHEN 'ambush' THEN '매복 요괴' WHEN 'reflect' THEN '거울 요괴' WHEN 'tide' THEN '수계 요괴' WHEN 'warded' THEN '결계 요괴' ELSE '원령' END,
  r.min_level, r.min_level + 6, 70 + r.min_level * 14, 8 + round(r.min_level * 1.1)::int, 14, v.nm || '. ' || v.d,
  CASE v.mech WHEN 'aerial' THEN '{"beast_bone":1,"spirit_dust":1}' WHEN 'swarm' THEN '{"beast_hide":1,"herb":1}' WHEN 'toxic' THEN '{"venom_gland":1,"herb":1}'
    WHEN 'armored' THEN '{"ore":2,"beast_bone":1}' WHEN 'ambush' THEN '{"shadow_fang":1,"beast_hide":1}' WHEN 'reflect' THEN '{"spirit_glass":1,"spirit_dust":1}'
    WHEN 'tide' THEN '{"drowned_scale":1,"river_reed":1}' WHEN 'warded' THEN '{"ward_fragment":1,"seal_paper":1}' ELSE '{"ghost_ash":1,"spirit_dust":1}' END::jsonb,
  2, v.mech, 'common'
FROM public.world_map_regions r JOIN (VALUES
 ('ash_coast','재갈매기 떼','aerial','잿빛 날개로 하늘을 덮는다.'),('ash_mountain','화산 박쥐','aerial','뜨거운 바위틈에서 날아든다.'),
 ('black_sand_temple','흑사 전갈','toxic','검은 모래 속에 숨어 꼬리를 세운다.'),('black_tide_rift','검은 물결 촉수','tide','균열 너머에서 촉수가 뻗어 온다.'),
 ('bone_market','뼈 수레꾼','armored','뼈로 짠 수레를 끌고 다닌다.'),('burial_steps','비석 까마귀','aerial','무덤 위를 맴돌며 운다.'),
 ('crimson_mine','갱도 박쥐 떼','swarm','어둠 속에서 떼로 몰려든다.'),('ember_village','잿불 여우','ambush','불씨를 꼬리에 달고 숨어 있다.'),
 ('field_outskirts','들쥐 요괴 떼','swarm','갈대 사이로 우르르 몰려온다.'),('forgotten_city','석상 수문병','armored','움직이는 돌 병사.'),
 ('frost_valley','설원 늑대','swarm','눈보라 속에서 무리 지어 사냥한다.'),('ghost_bamboo','대나무 원숭이','ambush','대나무 위에서 뛰어내린다.'),
 ('glass_canyon','유리 매','aerial','햇빛을 반사하며 내리꽂힌다.'),('hidden_bazaar','그림자 소매치기','ambush','인파 사이에서 칼을 숨긴다.'),
 ('hq_archive','책벌레 요괴','swarm','오래된 책장을 갉아 먹는다.'),('hq_dorm','베갯속 좀벌레','swarm','잠든 이의 꿈을 갉아 먹는다.'),
 ('hq_training','허수아비 귀','armored','짚 속에 쇠붙이가 박혀 있다.'),('hq_yard','지붕 까치귀','aerial','기와 위에서 부적을 훔친다.'),
 ('iron_monastery','쇠종 동자','reflect','종소리로 술법을 튕겨 낸다.'),('jade_pass','잔도 바람귀','aerial','절벽 바람을 타고 덮친다.'),
 ('lantern_market','등롱 나방 떼','aerial','불빛에 몰려드는 나방 요괴.'),('lotus_marsh','늪 거머리','toxic','진흙 속에서 피를 노린다.'),
 ('mirror_pavilion','물거울 요정','reflect','수면에 비친 모습을 훔친다.'),('nine_lighthouse','안개 갈매기','aerial','안개 속에서 울며 덮친다.'),
 ('old_canal','하수 쥐왕','swarm','쥐 떼를 거느린 늙은 쥐.'),('paper_bridge','종이학 무리','aerial','접힌 종이가 날카롭게 날아든다.'),
 ('red_forest','핏빛 사슴귀','ambush','단풍 사이에서 뿔을 겨눈다.'),('red_moon_fort','월식 교도','warded','결계를 두른 적월교 신도.'),
 ('red_plain','붉은 전갈','toxic','달아오른 모래 속의 독충.'),('river_ferry','나루 물뱀','toxic','뱃전을 타고 기어오른다.'),
 ('salt_village','소금 게','armored','소금 껍데기가 단단하다.'),('sealed_abyss','심연 사슬귀','warded','끊어진 봉인 사슬을 휘감고 있다.'),
 ('sealed_garden','덩굴 손','ambush','연못가 덩굴이 발목을 낚아챈다.'),('shrine_ruins','금줄 까마귀','aerial','끊어진 금줄을 물고 다닌다.'),
 ('sky_lake','얼음 학','aerial','얼음 깃털을 흩뿌린다.'),('star_observatory','유성 파편귀','armored','떨어진 별 조각이 굳어 생겼다.'),
 ('sunken_district','기와 두꺼비','toxic','잠긴 지붕 위에서 독을 뿜는다.'),('sunken_palace','산호 갑각병','armored','산호 갑옷을 두른 수궁 병사.'),
 ('thunder_peak','뇌조','aerial','벼락을 몰고 다니는 새.'),('under_root','뿌리 지네','toxic','지맥 뿌리를 타고 기어 다닌다.'),
 ('west_gate','해자 악어귀','armored','성벽 해자의 늙은 악어.'),('white_tower','별빛 나비 떼','swarm','빛가루를 흩뿌리며 몰려든다.')
) v(rid, nm, mech, d) ON v.rid = r.region_id
ON CONFLICT (monster_id) DO NOTHING;
