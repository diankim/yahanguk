-- 11차 콘텐츠(서버). SQL Editor에서 한 번에 실행한다. 하나라도 실패하면 전체가 되돌려진다.
--  1) 낚시: 물가 7곳의 낚시터(world_fish_grounds), 어종 20종(world_fish_species), 잡은 기록(world_fish_log), 낚싯대 2종
--     · 낚싯대를 가방에 두고 물가에서 낚는다(탐색력 1, 20초 간격). 시간대·날씨에 따라 잘 무는 어종이 다르다.
--     · 어종 도감(world_fish_codex)과 낚시 칭호 7개(효과: 입질·희귀 어종·크기)
--  2) 요리: 생선을 손질(손질한 생선)해 요리 6종을 만든다. 먹으면 회복과 이로운 상태(든든함·속이 따뜻함·기운 충천·바다의 복)
--  3) 원정 직업 기술: 퇴마관 파사 부적 · 현장 조사원 흔적 추적 · 의무관 야전 처치 · 봉인술사 결계 야영 · 기록 분석관 약점 간파 · 법구 제작사 현장 가공
--  4) 원정 진행 기록(world_expedition_progress): 수색 회차·건량·날씨/시간대 변화·요괴의 기척·같은 파티원의 원정. 승패와 전리품은 귀환할 때 공개한다.
--  5) 직접 거래: 원정 중인 조사원은 제안·수락할 수 없다(누락 보완). 거래 기록에 전 액수를 남겨 안전지대 검사를 받게 한다.
--
-- 새 함수는 fn_owner_field 소유(postgres가 원래 그 권한을 물려받는다). 기존 함수 중 fn_owner_field 소유만 고친다.

/* ── 1) 낚시 ─────────────────────────────────────────────── */
create table if not exists public.world_fish_grounds (
  region_id text primary key references public.world_map_regions(region_id) on delete cascade,
  habitat text not null check (habitat in ('river', 'marsh', 'sea', 'lake', 'deep')),
  ground_name text not null,
  description text not null default ''
);
create table if not exists public.world_fish_species (
  fish_id text primary key references public.world_item_catalog(item_id),
  fish_name text not null,
  habitat text not null check (habitat in ('river', 'marsh', 'sea', 'lake', 'deep')),
  rarity text not null check (rarity in ('common', 'uncommon', 'rare', 'epic', 'legendary')),
  min_level int not null default 1,
  phase text check (phase in ('dawn', 'noon', 'dusk', 'night')),
  weather text check (weather in ('clear', 'cloudy', 'rain', 'fog', 'wind', 'snow', 'bloodmist')),
  size_min numeric not null, size_max numeric not null,
  description text not null default '',
  sort int not null default 0,
  active boolean not null default true
);
create table if not exists public.world_fish_log (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  fish_id text not null references public.world_fish_species(fish_id),
  caught int not null default 1,
  best_size numeric not null default 0,
  first_at timestamptz not null default now(),
  last_at timestamptz not null default now(),
  primary key (owner_id, fish_id)
);
alter table public.world_fish_grounds enable row level security;
alter table public.world_fish_species enable row level security;
alter table public.world_fish_log enable row level security;
drop policy if exists world_fish_log_own on public.world_fish_log;
create policy world_fish_log_own on public.world_fish_log for select to authenticated using (owner_id = (select auth.uid()));
revoke all on public.world_fish_grounds, public.world_fish_species, public.world_fish_log from anon, authenticated;
grant select on public.world_fish_log to authenticated;
grant select on public.world_fish_grounds, public.world_fish_species to fn_owner_field;
grant select, insert, update on public.world_fish_log to fn_owner_field;

-- 낚싯대·물고기·손질한 생선·요리
insert into public.world_item_catalog(item_id, item_name, category, tier, description, rarity, minimum_level, equipment_traits, crafting_specialization, tradeable, reference_price, acquisition_difficulty) values
  ('fishing_rod', '대나무 낚싯대', 'tool', 1, '물가에서 낚시할 때 쓰는 낚싯대. 가방에 있으면 됩니다.', 'common', 1, '{"trait":"낚시","fish_bite_pct":0}', 'fishing', true, 60, 1),
  ('spirit_rod', '영사 낚싯대', 'tool', 2, '영사 실을 감은 낚싯대. 입질이 잦고 희귀한 어종이 잘 걸립니다.', 'uncommon', 6, '{"trait":"낚시","fish_bite_pct":6,"fish_rare_pct":4}', 'fishing', true, 220, 2),
  ('minnow', '버들치', 'material', 1, '맑은 여울에 떼 지어 사는 작은 물고기.', 'common', 1, '{}', 'cooking', true, 6, 1),
  ('mandarin_fish', '쏘가리', 'material', 2, '바위 틈에 숨는 얼룩무늬 물고기. 살이 단단합니다.', 'uncommon', 1, '{}', 'cooking', true, 18, 2),
  ('sweetfish', '은어', 'material', 2, '해 뜰 무렵 여울을 거슬러 오르는 향긋한 물고기.', 'uncommon', 1, '{}', 'cooking', true, 20, 2),
  ('golden_carp', '금빛 잉어', 'material', 3, '맑은 날 물비늘처럼 반짝이는 잉어. 약재로 귀하게 쓰입니다.', 'rare', 3, '{}', 'cooking', true, 55, 3),
  ('ink_catfish', '먹물 메기', 'material', 3, '깊은 밤 바닥을 훑는 검은 메기. 먹물 같은 진액을 품습니다.', 'rare', 3, '{}', 'cooking', true, 50, 3),
  ('loach', '미꾸라지', 'material', 1, '늪 바닥 진흙 속에 사는 물고기.', 'common', 1, '{}', 'cooking', true, 6, 1),
  ('snakehead', '가물치', 'material', 2, '늪의 폭군. 힘이 세 낚싯줄을 끊기도 합니다.', 'uncommon', 5, '{}', 'cooking', true, 22, 2),
  ('lantern_crucian', '연등 붕어', 'material', 3, '땅거미가 지면 비늘에 등불 같은 빛이 도는 붕어.', 'rare', 5, '{}', 'cooking', true, 60, 3),
  ('marsh_wraithfish', '늪 귀어', 'material', 4, '안개 낀 늪에서만 떠오르는 창백한 물고기. 요기가 서려 있습니다.', 'epic', 7, '{}', 'cooking', true, 160, 4),
  ('gizzard_shad', '전어', 'material', 1, '바닷가 어디서나 잡히는 고소한 물고기.', 'common', 1, '{}', 'cooking', true, 7, 1),
  ('rockfish', '볼락', 'material', 1, '밤이면 갯바위 근처로 몰려드는 눈 큰 물고기.', 'common', 1, '{}', 'cooking', true, 8, 1),
  ('sea_eel', '갯장어', 'material', 2, '이빨이 날카로운 바다 장어. 기운을 북돋는 보양 재료입니다.', 'uncommon', 8, '{}', 'cooking', true, 26, 2),
  ('lamp_hairtail', '백등 갈치', 'material', 3, '달 없는 밤 수면 가까이 은빛 띠처럼 떠오르는 갈치.', 'rare', 10, '{}', 'cooking', true, 70, 3),
  ('dragon_bream', '용왕 참돔', 'material', 4, '비 오는 바다에서만 낚인다는 붉은 참돔. 용왕의 상에 올린다고 합니다.', 'epic', 12, '{}', 'cooking', true, 180, 4),
  ('pond_smelt', '빙어', 'material', 1, '찬 호수에 사는 투명한 물고기.', 'common', 1, '{}', 'cooking', true, 6, 1),
  ('lake_trout', '송어', 'material', 2, '천경호의 맑은 물을 좋아하는 송어.', 'uncommon', 10, '{}', 'cooking', true, 24, 2),
  ('cherry_salmon', '산천어', 'material', 3, '새벽 호수 가장자리에서만 모습을 보이는 귀한 물고기.', 'rare', 12, '{}', 'cooking', true, 65, 3),
  ('mirror_whitefish', '천경 백어', 'material', 4, '맑은 밤하늘을 비춘 호수에서만 떠오르는 흰 물고기. 별빛을 머금었다고 합니다.', 'epic', 13, '{}', 'cooking', true, 190, 4),
  ('palace_lanternfish', '수궁 등롱어', 'material', 3, '용잠 수궁의 어둠 속에서 등불을 켜고 다니는 물고기.', 'rare', 14, '{}', 'cooking', true, 90, 3),
  ('dragon_scale_koi', '용잠 비늘잉어', 'material', 5, '피안개가 짙게 낀 날, 수궁 깊은 곳에서 단 한 번 떠오른다는 전설의 잉어.', 'legendary', 14, '{}', 'cooking', true, 600, 5),
  ('fish_fillet', '손질한 생선', 'material', 1, '비늘과 뼈를 발라낸 생선살. 여러 요리의 바탕입니다.', 'common', 1, '{}', 'cooking', true, 10, 1),
  ('grilled_fish', '생선구이', 'consumable', 1, '부적목 숯불에 구운 생선. 먹으면 체력이 돌고 든든해집니다.', 'common', 1, '{}', 'cooking', true, 24, 1),
  ('spicy_stew', '매운탕', 'consumable', 2, '약초를 넣고 끓인 얼큰한 탕. 속이 따뜻해져 요기를 덜 탑니다.', 'uncommon', 1, '{}', 'cooking', true, 45, 2),
  ('fish_porridge', '어죽', 'consumable', 1, '건량에 생선살을 넣고 쑨 죽. 기력을 되찾게 합니다.', 'common', 1, '{}', 'cooking', true, 30, 1),
  ('eel_tonic', '장어 보양탕', 'consumable', 2, '갯장어와 약초액으로 끓인 보양탕. 기운이 충천합니다.', 'uncommon', 1, '{}', 'cooking', true, 80, 2),
  ('carp_broth', '잉어 고음', 'consumable', 3, '금빛 잉어를 오래 고아 낸 국물. 몸과 마음을 함께 다스립니다.', 'rare', 1, '{}', 'cooking', true, 120, 3),
  ('bream_sashimi', '용왕 참돔 회', 'consumable', 4, '용왕 참돔을 얇게 저민 회. 먹으면 바다의 복이 따른다고 합니다.', 'epic', 1, '{}', 'cooking', true, 260, 4)
on conflict (item_id) do nothing;

insert into public.world_fish_grounds(region_id, habitat, ground_name, description) values
  ('paper_bridge', 'river', '백지교 아래 여울', '다리 그늘 아래로 맑은 여울이 흐릅니다.'),
  ('river_ferry', 'river', '구름나루 선착장', '배가 드나드는 너른 강가. 안전지대라 마음 놓고 낚을 수 있습니다.'),
  ('lotus_marsh', 'marsh', '연화늪 가장자리', '연잎 사이로 물안개가 피어오르는 늪.'),
  ('ash_coast', 'sea', '재의 해안 갯바위', '잿빛 모래와 검은 갯바위가 이어진 바닷가.'),
  ('nine_lighthouse', 'sea', '구등대 방파제', '아홉 등대 아래 깊은 물이 출렁입니다.'),
  ('sky_lake', 'lake', '천경호 얼음 구멍', '하늘을 비추는 차가운 호수.'),
  ('sunken_palace', 'deep', '수궁 잠긴 회랑', '물에 잠긴 궁궐의 회랑. 빛이 닿지 않는 깊은 물입니다.')
on conflict (region_id) do nothing;

insert into public.world_fish_species(fish_id, fish_name, habitat, rarity, min_level, phase, weather, size_min, size_max, description, sort) values
  ('minnow', '버들치', 'river', 'common', 1, null, null, 6, 15, '맑은 여울에 떼 지어 삽니다.', 1),
  ('mandarin_fish', '쏘가리', 'river', 'uncommon', 1, null, null, 18, 45, '바위 틈에 숨어 지냅니다.', 2),
  ('sweetfish', '은어', 'river', 'uncommon', 1, 'dawn', null, 12, 28, '해 뜰 무렵 여울을 거슬러 오릅니다.', 3),
  ('golden_carp', '금빛 잉어', 'river', 'rare', 3, null, 'clear', 30, 80, '맑은 날 물비늘처럼 반짝입니다.', 4),
  ('ink_catfish', '먹물 메기', 'river', 'rare', 3, 'night', null, 35, 95, '깊은 밤 바닥을 훑습니다.', 5),
  ('loach', '미꾸라지', 'marsh', 'common', 1, null, null, 8, 18, '진흙 속에 삽니다.', 6),
  ('snakehead', '가물치', 'marsh', 'uncommon', 5, null, 'rain', 35, 90, '비 오는 날 사납게 뭅니다.', 7),
  ('lantern_crucian', '연등 붕어', 'marsh', 'rare', 5, 'dusk', null, 15, 35, '땅거미가 지면 빛이 돕니다.', 8),
  ('marsh_wraithfish', '늪 귀어', 'marsh', 'epic', 7, null, 'fog', 40, 110, '안개 낀 늪에서만 떠오릅니다.', 9),
  ('gizzard_shad', '전어', 'sea', 'common', 1, null, null, 12, 26, '어느 바닷가에서나 잡힙니다.', 10),
  ('rockfish', '볼락', 'sea', 'common', 1, 'night', null, 12, 30, '밤이면 갯바위로 몰려듭니다.', 11),
  ('sea_eel', '갯장어', 'sea', 'uncommon', 8, null, null, 50, 140, '이빨이 날카롭습니다.', 12),
  ('lamp_hairtail', '백등 갈치', 'sea', 'rare', 10, 'night', null, 60, 150, '달 없는 밤 수면 가까이 떠오릅니다.', 13),
  ('dragon_bream', '용왕 참돔', 'sea', 'epic', 12, null, 'rain', 40, 100, '비 오는 바다에서만 낚입니다.', 14),
  ('pond_smelt', '빙어', 'lake', 'common', 1, null, null, 6, 15, '찬 물에 삽니다.', 15),
  ('lake_trout', '송어', 'lake', 'uncommon', 10, null, 'snow', 30, 70, '눈 오는 날 활발합니다.', 16),
  ('cherry_salmon', '산천어', 'lake', 'rare', 12, 'dawn', null, 20, 45, '새벽 호숫가에서만 보입니다.', 17),
  ('mirror_whitefish', '천경 백어', 'lake', 'epic', 13, 'night', 'clear', 30, 75, '맑은 밤에만 떠오릅니다.', 18),
  ('palace_lanternfish', '수궁 등롱어', 'deep', 'rare', 14, null, null, 20, 50, '어둠 속에서 등불을 켭니다.', 19),
  ('dragon_scale_koi', '용잠 비늘잉어', 'deep', 'legendary', 14, null, 'bloodmist', 80, 180, '피안개 짙은 날 단 한 번 떠오릅니다.', 20)
on conflict (fish_id) do nothing;

-- 낚싯대 판매(물가·시장 상점)
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max) values
  ('river_market', 'fishing_rod', 55, 2, 5), ('capital_market', 'fishing_rod', 65, 1, 3), ('south_market', 'fishing_rod', 65, 1, 3)
on conflict do nothing;

-- 낚시 칭호(효과는 낚시에만 붙는다)
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, hidden, rule, sort, category) values
  ('first_bite', '첫 입질', 'leaf', '처음으로 물고기를 낚았습니다.', '물고기 1마리 낚기', '{"fish_bite_pct":5}', false, '{"ev":"fish","p":{"caught":true},"n":1}', 101, '낚시'),
  ('river_angler', '강태공', 'leaf', '서로 다른 어종 10가지를 도감에 올렸습니다.', '어종 10가지 낚기', '{"fish_rare_pct":5}', false, '{"distinct":"fish","key":"fish","n":10}', 102, '낚시'),
  ('night_angler', '삼경의 낚시꾼', 'moon', '깊은 밤 물가에 앉아 고기를 낚았습니다.', '삼경에 물고기 10마리 낚기', '{"fish_bite_pct":8}', false, '{"ev":"fish","p":{"caught":true},"phase":"night","n":10}', 103, '낚시'),
  ('big_catch', '대어 낚기', 'leaf', '팔뚝보다 큰 물고기를 끌어올렸습니다.', '크기 100cm 이상 낚기', '{"fish_size_pct":10}', false, '{"ev":"fish","p":{"caught":true},"gte":{"size":100},"n":1}', 104, '낚시'),
  ('waterside_soul', '물가의 사람', 'leaf', '물가에서 보낸 시간이 길어 물때를 읽습니다.', '물고기 100마리 낚기', '{"fish_bite_pct":5,"fish_rare_pct":3}', false, '{"ev":"fish","p":{"caught":true},"n":100}', 105, '낚시'),
  ('fish_codex_master', '어보 편찬자', 'scroll', '세상의 어종을 빠짐없이 기록했습니다.', '숨겨진 조건', '{"fish_rare_pct":10,"gather_qty_pct":5}', true, '{"distinct":"fish","key":"fish","n":20}', 106, '낚시'),
  ('dragon_koi', '용잠의 비늘', 'spark', '전설의 비늘잉어를 손에 넣었습니다.', '숨겨진 조건', '{"fish_rare_pct":8,"fish_size_pct":8}', true, '{"ev":"fish","p":{"rarity":"legendary"},"n":1}', 107, '낚시')
on conflict (title_key) do nothing;

-- 손질·요리 제작법(현장 채집도로 손질한다. 백등 야시장·구름나루에서 만들면 품질 보너스)
insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, recipe_difficulty) values
  ('fillet_minnow', '버들치 손질', 'fish_fillet', 1, '{"minnow":2}', 'field_knife', 1, '구름나루', '작은 물고기 둘을 손질해 생선살 하나를 얻습니다.', 1, 1),
  ('fillet_loach', '미꾸라지 손질', 'fish_fillet', 1, '{"loach":2}', 'field_knife', 1, '구름나루', '진흙을 빼고 생선살을 얻습니다.', 1, 1),
  ('fillet_smelt', '빙어 손질', 'fish_fillet', 1, '{"pond_smelt":2}', 'field_knife', 1, '구름나루', '빙어 둘로 생선살 하나.', 1, 1),
  ('fillet_shad', '전어 손질', 'fish_fillet', 1, '{"gizzard_shad":1}', 'field_knife', 1, '구름나루', '전어 한 마리로 생선살 하나.', 1, 1),
  ('fillet_rockfish', '볼락 손질', 'fish_fillet', 1, '{"rockfish":1}', 'field_knife', 1, '구름나루', '볼락 한 마리로 생선살 하나.', 1, 1),
  ('fillet_mandarin', '쏘가리 손질', 'fish_fillet', 2, '{"mandarin_fish":1}', 'field_knife', 1, '구름나루', '살이 많은 쏘가리로 생선살 둘.', 1, 1),
  ('cook_grilled_fish', '생선구이', 'grilled_fish', 1, '{"fish_fillet":1,"charcoal":1}', 'field_knife', 1, '백등 야시장', '숯불에 구워 든든한 한 끼를 만듭니다.', 1, 1),
  ('cook_spicy_stew', '매운탕', 'spicy_stew', 1, '{"fish_fillet":2,"herb":2}', 'field_knife', 1, '백등 야시장', '약초를 넣어 얼큰하게 끓입니다.', 1, 2),
  ('cook_fish_porridge', '어죽', 'fish_porridge', 1, '{"fish_fillet":1,"travel_ration":1}', 'field_knife', 1, '구름나루', '건량에 생선살을 넣어 죽을 쑵니다.', 1, 1),
  ('cook_eel_tonic', '장어 보양탕', 'eel_tonic', 1, '{"sea_eel":1,"herbal_extract":1}', 'field_knife', 1, '백등 야시장', '갯장어를 약초액과 함께 끓입니다.', 5, 2),
  ('cook_carp_broth', '잉어 고음', 'carp_broth', 1, '{"golden_carp":1,"medicine_base":1}', 'field_knife', 1, '백등 야시장', '금빛 잉어를 오래 고아 냅니다.', 5, 3),
  ('cook_bream_sashimi', '용왕 참돔 회', 'bream_sashimi', 1, '{"dragon_bream":1}', 'field_knife', 1, '구름나루', '용왕 참돔을 얇게 저밉니다.', 10, 4),
  ('make_fishing_rod', '대나무 낚싯대 만들기', 'fishing_rod', 1, '{"wood":2,"river_reed":2,"talisman_thread":1}', 'field_knife', 1, '구름나루', '갈대와 부적실로 낚싯대를 엮습니다.', 1, 1),
  ('make_spirit_rod', '영사 낚싯대 만들기', 'spirit_rod', 1, '{"reinforced_lumber":1,"spirit_thread":1,"river_reed":2}', 'field_knife', 1, '구름나루', '영사 실을 감아 잘 무는 낚싯대를 만듭니다.', 6, 3)
on conflict (recipe_id) do nothing;

-- 요리를 먹으면 붙는 이로운 상태(무작위로는 걸리지 않는다)
insert into public.world_status_catalog(status_key, status_name, polarity, description, duration_minutes, triggers, effects, max_stacks, icon, cure) values
  ('well_fed', '든든함', 'positive', '배가 든든해 손이 부지런합니다.', 40, '{}', '{"gather_qty_pct":6,"healing_pct":5}', 1, 'leaf', '시간이 지나면 사라집니다.'),
  ('warm_belly', '속이 따뜻함', 'positive', '뜨끈한 국물에 속이 데워져 요기를 덜 탑니다.', 40, '{}', '{"erosion_pct":-10,"incoming_damage_pct":-5}', 1, 'flame', '시간이 지나면 사라집니다.'),
  ('vigor', '기운 충천', 'positive', '보양식 덕에 몸에 힘이 넘칩니다.', 30, '{}', '{"combat_damage_pct":8,"travel_time_pct":-5}', 1, 'spark', '시간이 지나면 사라집니다.'),
  ('sea_luck', '바다의 복', 'positive', '용왕의 복이 따라 귀한 것이 잘 눈에 띕니다.', 30, '{}', '{"rare_loot_pct":6,"fish_rare_pct":10}', 1, 'spark', '시간이 지나면 사라집니다.')
on conflict (status_key) do nothing;

-- 낚시: 지금 있는 곳의 낚시터 정보
create or replace function public.world_fish_spot() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; g public.world_fish_grounds%rowtype;
  last timestamptz; rod int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then return null; end if;
  r := public.world_field_region(c.location);
  select * into g from public.world_fish_grounds where region_id = r.region_id;
  if g.region_id is null then return null; end if;
  rod := case when coalesce((c.inventory ->> 'spirit_rod')::int, 0) > 0 then 2 when coalesce((c.inventory ->> 'fishing_rod')::int, 0) > 0 then 1 else 0 end;
  select max(created_at) into last from public.world_events where actor_id = uid and event_type = 'fish' and created_at > now() - interval '20 seconds';
  return jsonb_build_object('region_id', r.region_id, 'ground_name', g.ground_name, 'description', g.description, 'habitat', g.habitat,
    'rod', rod, 'rod_name', case rod when 2 then '영사 낚싯대' when 1 then '대나무 낚싯대' end,
    'ready_at', case when last is not null then last + interval '20 seconds' end,
    'species_total', (select count(*) from public.world_fish_species s where s.habitat = g.habitat and s.active),
    'species_caught', (select count(*) from public.world_fish_log l join public.world_fish_species s using (fish_id) where l.owner_id = uid and s.habitat = g.habitat),
    'recent', coalesce((select jsonb_agg(x) from (select e.content as text, e.created_at as at from public.world_events e
       where e.actor_id = uid and e.event_type = 'fish' order by e.created_at desc limit 5) x), '[]'::jsonb));
end $$;

create or replace function public.world_fish() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; g public.world_fish_grounds%rowtype;
  sp public.world_fish_species%rowtype; rod int; last timestamptz; ph text; wk text; bite numeric; boost numeric; size numeric; first boolean;
  xp int; left_st int; inv jsonb; msg text; rname text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 낚시할 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 낚시할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '전투 중에는 낚시할 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then raise exception '원정 중에는 낚시할 수 없습니다.'; end if;
  r := public.world_field_region(c.location);
  select * into g from public.world_fish_grounds where region_id = r.region_id;
  if g.region_id is null then raise exception '이곳에는 낚시터가 없습니다. 강·늪·바다·호수가 있는 지역에서 낚을 수 있습니다.'; end if;
  rod := case when coalesce((c.inventory ->> 'spirit_rod')::int, 0) > 0 then 2 when coalesce((c.inventory ->> 'fishing_rod')::int, 0) > 0 then 1 else 0 end;
  if rod = 0 then raise exception '낚싯대가 있어야 낚시할 수 있습니다. 구름나루·백등 야시장·잔불촌 상점에서 사거나 직접 만들 수 있습니다.'; end if;
  select max(created_at) into last from public.world_events where actor_id = uid and event_type = 'fish' and created_at > now() - interval '20 seconds';
  if last is not null then raise exception '%', format('찌를 다시 던지려면 %s초 기다리세요.', ceil(extract(epoch from (last + interval '20 seconds' - now())))::int); end if;
  left_st := public.world_stamina_change(uid, -1);
  ph := public.world_time_phase(now()); wk := public.world_weather_key(r.territory_id, now());
  bite := 0.62 + rod * 0.06 + case when c.gathering_profession = 'fishing' then 0.08 else 0 end + case when wk in ('rain', 'fog', 'cloudy') then 0.05 else 0 end
    + (public.world_title_bonus('fish_bite_pct') + public.world_status_effect_total('fish_bite_pct')) / 100.0
    + coalesce((select (i.equipment_traits ->> 'fish_bite_pct')::numeric from public.world_item_catalog i where i.item_id = case rod when 2 then 'spirit_rod' else 'fishing_rod' end), 0) / 100.0;
  bite := least(0.95, greatest(0.3, bite));
  if random() > bite then
    msg := g.ground_name || '에서 찌가 흔들렸지만 놓쳤습니다.';
    insert into public.world_events(actor_id, actor_name, event_type, content, payload)
    values (uid, c.character_name, 'fish', msg, jsonb_build_object('caught', false, 'region_id', r.region_id, 'habitat', g.habitat));
    return jsonb_build_object('ok', true, 'caught', false, 'content', msg, 'stamina', left_st, 'ready_at', now() + interval '20 seconds');
  end if;
  boost := public.world_title_bonus('fish_rare_pct') + public.world_status_effect_total('fish_rare_pct') + public.world_status_effect_total('rare_loot_pct') + rod * 3
    + coalesce((select (i.equipment_traits ->> 'fish_rare_pct')::numeric from public.world_item_catalog i where i.item_id = 'spirit_rod' and rod = 2), 0);
  select * into sp from public.world_fish_species s
   where s.habitat = g.habitat and s.active and s.min_level <= c.level + 2
   order by -ln(greatest(random(), 1e-9)) / (
       (case s.rarity when 'common' then 60 when 'uncommon' then 25 when 'rare' then 9 * (1 + boost / 100.0) when 'epic' then 3 * (1 + boost / 100.0) else 0.6 * (1 + boost / 100.0) end)
     * (case when s.phase is null then 1 when s.phase = ph then 3 else 0.3 end)
     * (case when s.weather is null then 1 when s.weather = wk then 3 else 0.3 end)) limit 1;
  if sp.fish_id is null then raise exception '물고기가 보이지 않습니다.'; end if;
  size := round(least(sp.size_max * 1.1, (sp.size_min + (sp.size_max - sp.size_min) * power(random(), 1.6)) * (1 + public.world_title_bonus('fish_size_pct') / 100.0)), 1);
  first := not exists (select 1 from public.world_fish_log where owner_id = uid and fish_id = sp.fish_id);
  insert into public.world_fish_log(owner_id, fish_id, caught, best_size) values (uid, sp.fish_id, 1, size)
  on conflict (owner_id, fish_id) do update set caught = public.world_fish_log.caught + 1, best_size = greatest(public.world_fish_log.best_size, excluded.best_size), last_at = now();
  xp := case sp.rarity when 'common' then 6 when 'uncommon' then 10 when 'rare' then 18 when 'epic' then 30 else 50 end;
  inv := public.world_inv_add(c.inventory, sp.fish_id, 1);
  update public.world_characters set inventory = inv, gathering_xp = gathering_xp + xp,
    gathering_rank = public.world_skill_rank(gathering_xp + xp, 'gathering'), updated_at = now() where owner_id = uid;
  rname := case sp.rarity when 'uncommon' then '고급' when 'rare' then '희귀' when 'epic' then '영웅' when 'legendary' then '전설' else '' end;
  msg := g.ground_name || '에서 ' || sp.fish_name || '을(를) 낚았습니다. ' || size || 'cm' || case when rname <> '' then ' · ' || rname else '' end
    || case when first then ' · 도감에 새로 올랐습니다' else '' end;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'fish', msg, jsonb_build_object('caught', true, 'fish', sp.fish_id, 'rarity', sp.rarity, 'size', size,
    'region_id', r.region_id, 'habitat', g.habitat, 'first', first));
  perform public.world_title_award_check(uid, 'fish');
  return jsonb_build_object('ok', true, 'caught', true, 'content', msg, 'fish', sp.fish_id, 'fish_name', sp.fish_name, 'rarity', sp.rarity,
    'size', size, 'first', first, 'xp', xp, 'stamina', left_st, 'ready_at', now() + interval '20 seconds');
end $$;

-- 어종 도감: 잡지 못한 어종은 이름을 감추고 사는 곳·잘 무는 때만 알려 준다
create or replace function public.world_fish_codex() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object(
    'species', coalesce((select jsonb_agg(jsonb_build_object('fish_id', case when l.fish_id is not null then s.fish_id end,
        'name', case when l.fish_id is not null then s.fish_name else '???' end, 'habitat', s.habitat, 'rarity', s.rarity,
        'caught', l.fish_id is not null, 'count', coalesce(l.caught, 0), 'best_size', l.best_size, 'size_max', case when l.fish_id is not null then s.size_max end,
        'description', case when l.fish_id is not null then s.description end, 'min_level', s.min_level,
        'phase', s.phase, 'weather', s.weather, 'first_at', l.first_at) order by s.sort)
      from public.world_fish_species s left join public.world_fish_log l on l.fish_id = s.fish_id and l.owner_id = uid where s.active), '[]'::jsonb),
    'grounds', coalesce((select jsonb_agg(jsonb_build_object('region_id', g.region_id, 'region_name', r.region_name, 'ground_name', g.ground_name,
        'habitat', g.habitat, 'safe', coalesce(r.is_safe_zone, false), 'min_level', r.min_level) order by r.min_level)
      from public.world_fish_grounds g join public.world_map_regions r on r.region_id = g.region_id), '[]'::jsonb),
    'total_caught', coalesce((select sum(caught) from public.world_fish_log where owner_id = uid), 0),
    'titles', coalesce((select jsonb_agg(jsonb_build_object('key', t.title_key,
        'name', case when t.hidden and ct.title_key is null then '숨겨진 칭호' else t.title_name end,
        'condition', case when t.hidden and ct.title_key is null then '조건이 가려져 있습니다' else t.condition_text end,
        'earned', ct.title_key is not null) order by t.sort)
      from public.world_title_catalog t left join public.world_character_titles ct on ct.title_key = t.title_key and ct.owner_id = uid
      where t.active and t.category = '낚시'), '[]'::jsonb));
end $$;

/* ── 2) 요리: 먹기 ───────────────────────────────────────── */
do $$ declare def text; nd text; begin
  def := pg_get_functiondef('public.world_use_item(text)'::regprocedure);
  nd := replace(def, 'cures text[] := ''{}''; cleared int := 0; nm text; mul float8 := 1; msg text;',
    'cures text[] := ''{}''; cleared int := 0; nm text; mul float8 := 1; msg text; buff text; buffs text[] := ''{}''; bname text;');
  nd := replace(nd, 'IF p_item_id NOT IN (''tonic'', ''herbal_extract'', ''herb'', ''medicine_base'', ''ward_talisman'', ''travel_ration'') THEN',
    'IF p_item_id NOT IN (''tonic'', ''herbal_extract'', ''herb'', ''medicine_base'', ''ward_talisman'', ''travel_ration'',
      ''grilled_fish'', ''spicy_stew'', ''fish_porridge'', ''eel_tonic'', ''carp_broth'', ''bream_sashimi'') THEN');
  nd := replace(nd, 'WHEN ''travel_ration'' THEN stam := 5;',
    'WHEN ''travel_ration'' THEN stam := 5;
    WHEN ''grilled_fish'' THEN hp := 25; buffs := ARRAY[''well_fed''];
    WHEN ''spicy_stew'' THEN hp := 30; mn := 10; cures := ARRAY[''cold'']; buffs := ARRAY[''warm_belly''];
    WHEN ''fish_porridge'' THEN mn := 15; stam := 4; cures := ARRAY[''fatigue''];
    WHEN ''eel_tonic'' THEN hp := 45; cures := ARRAY[''exhausted'']; buffs := ARRAY[''vigor''];
    WHEN ''carp_broth'' THEN hp := 60; mn := 20; buffs := ARRAY[''well_fed'', ''warm_belly''];
    WHEN ''bream_sashimi'' THEN hp := 40; mn := 10; buffs := ARRAY[''sea_luck'', ''vigor''];');
  -- 이로운 상태가 붙는 요리는 체력이 가득해도 먹을 수 있다
  nd := replace(nd, 'IF stam = 0 AND cleared = 0 AND (hp = 0 OR c.health >= 100)',
    'IF cardinality(buffs) = 0 AND stam = 0 AND cleared = 0 AND (hp = 0 OR c.health >= 100)');
  nd := replace(nd, 'IF stam > 0 AND public.world_stamina_now(c.stamina, c.stamina_at, c.level) >= public.world_stamina_max(c.level) THEN',
    'IF stam > 0 AND cardinality(buffs) = 0 AND mn = 0 AND public.world_stamina_now(c.stamina, c.stamina_at, c.level) >= public.world_stamina_max(c.level) THEN');
  nd := replace(nd, 'IF stam > 0 THEN PERFORM public.world_stamina_change(uid, stam); END IF;',
    'IF stam > 0 AND public.world_stamina_now(c.stamina, c.stamina_at, c.level) < public.world_stamina_max(c.level) THEN PERFORM public.world_stamina_change(uid, stam); END IF;
  FOREACH buff IN ARRAY buffs LOOP
    SELECT status_name INTO bname FROM public.world_status_catalog WHERE status_key = buff;
    IF EXISTS (SELECT 1 FROM public.world_character_statuses WHERE owner_id = uid AND status_key = buff AND expires_at > now()) THEN
      UPDATE public.world_character_statuses SET expires_at = now() + make_interval(mins => (SELECT duration_minutes FROM public.world_status_catalog WHERE status_key = buff))
       WHERE owner_id = uid AND status_key = buff AND expires_at > now();
    ELSE
      INSERT INTO public.world_character_statuses(owner_id, status_key, source_activity, expires_at, metadata)
      VALUES (uid, buff, ''meal'', now() + make_interval(mins => (SELECT duration_minutes FROM public.world_status_catalog WHERE status_key = buff)), jsonb_build_object(''item'', p_item_id));
    END IF;
  END LOOP;');
  nd := replace(nd, '|| CASE WHEN cleared > 0 THEN '' · 상태 '' || cleared || ''개 치료'' ELSE '''' END;',
    '|| CASE WHEN cleared > 0 THEN '' · 상태 '' || cleared || ''개 치료'' ELSE '''' END
    || CASE WHEN cardinality(buffs) > 0 THEN '' · '' || (SELECT string_agg(status_name, ''·'') FROM public.world_status_catalog WHERE status_key = ANY (buffs)) ELSE '''' END;');
  if position('bream_sashimi' in nd) = 0 or position('FOREACH buff' in nd) = 0 or position('cardinality(buffs) = 0 AND stam = 0' in nd) = 0
     or position('string_agg(status_name' in nd) = 0 then
    raise exception 'world_use_item 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
end $$;

/* ── 3) 원정 직업 기술 ───────────────────────────────────── */
do $$ declare def text; nd text;
begin
  def := pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure);
  nd := def;
  nd := replace(nd, 'found_spot uuid; nm text;', 'found_spot uuid; nm text; jobn int := 0; job_once boolean := false; weak_bonus float8 := 0; job_name text;');
  nd := replace(nd, 'nm := n.node_name;', 'nm := n.node_name;
  job_name := CASE c.job_key WHEN ''exorcist'' THEN ''파사 부적'' WHEN ''scout'' THEN ''흔적 추적'' WHEN ''medic'' THEN ''야전 처치''
    WHEN ''sealmaster'' THEN ''결계 야영'' WHEN ''analyst'' THEN ''약점 간파'' WHEN ''artificer'' THEN ''현장 가공'' END;');
  -- 현장 조사원: 마주칠 요괴의 흔적을 먼저 읽고 피해 간다(30%) → 발견으로 바뀐다
  nd := replace(nd, 'roll := random();', 'roll := random();
    IF c.job_key = ''scout'' AND roll < p_fight AND random() < 0.3 THEN
      roll := p_fight + 0.36;
      IF jobn = 0 THEN log := log || jsonb_build_array(''[흔적 추적] 요괴의 흔적을 먼저 읽고 길을 돌아 피했습니다.''); END IF;
      jobn := jobn + 1;
    END IF;');
  -- 기록 분석관: 밀린 다음 싸움은 약점을 노린다(+15%) / 퇴마관: 원정마다 한 번, 영체·결계 요괴를 부적으로 단번에 퇴치
  nd := replace(nd, 'win_p := greatest(0.08, least(0.95, win_p));', 'IF weak_bonus > 0 THEN
        win_p := win_p + weak_bonus; weak_bonus := 0;
        IF jobn = 0 THEN log := log || jsonb_build_array(''[약점 간파] 앞서 밀렸던 싸움에서 읽어 낸 약점을 노렸습니다.''); END IF;
        jobn := jobn + 1;
      END IF;
      win_p := greatest(0.08, least(0.95, win_p));
      IF c.job_key = ''exorcist'' AND spirit_mech AND NOT job_once THEN
        win_p := 1; job_once := true; jobn := jobn + 1;
        log := log || jsonb_build_array(''[파사 부적] '' || m.monster_name || ''의 요기를 부적으로 단번에 꿰뚫었습니다.'');
      END IF;');
  nd := replace(nd, 'losses := losses + 1;', 'losses := losses + 1;
        IF c.job_key = ''analyst'' THEN weak_bonus := 0.15; END IF;');
  -- 법구 제작사: 캔 재료를 손질해 하나 더(25%)
  nd := replace(nd, 'IF qty > 0 THEN gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty); END IF;',
    'IF qty > 0 THEN gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty); END IF;
        IF c.job_key = ''artificer'' AND qty > 0 AND random() < 0.25 THEN
          loot := public.world_inv_add(loot, item, 1);
          IF jobn = 0 THEN log := log || jsonb_build_array(''[현장 가공] 캔 재료를 손질해 쓸 만한 것을 하나 더 건졌습니다.''); END IF;
          jobn := jobn + 1;
        END IF;');
  -- 봉인술사: 위험한 기운을 결계로 막는다(50%)
  nd := replace(nd, 'hazards := hazards + 1;', 'hazards := hazards + 1;
        IF c.job_key = ''sealmaster'' AND random() < 0.5 THEN
          IF jobn = 0 THEN log := log || jsonb_build_array(''[결계 야영] 스며드는 요기를 결계로 막아 냈습니다.''); END IF;
          jobn := jobn + 1;
        ELSE');
  nd := replace(nd, 'mn := mn - (2 + floor(random() * 4))::int;', 'mn := mn - (2 + floor(random() * 4))::int;
        END IF;');
  -- 의무관: 보급품이 떨어지면 원정마다 한 번 주변 약초로 응급 처치(체력 +30)
  nd := replace(nd, 'EXIT WHEN item IS NULL;', 'IF item IS NULL THEN
        IF c.job_key = ''medic'' AND NOT job_once THEN
          hp := least(100, hp + 30); job_once := true; jobn := jobn + 1;
          log := log || jsonb_build_array(''[야전 처치] 보급품이 떨어지자 주변 약초로 상처를 동여맸습니다. 체력 +30'');
        END IF;
        EXIT;
      END IF;');
  nd := replace(nd, '''mount'', mount_gift, ''log'', log)', '''mount'', mount_gift, ''log'', log, ''job_skill'', jsonb_build_object(''name'', job_name, ''count'', jobn))');
  -- 모든 고칠 곳이 바뀌었는지 확인한다
  if position('job_name := CASE' in nd) = 0 or position('[흔적 추적]' in nd) = 0 or position('[약점 간파]' in nd) = 0 or position('[파사 부적]' in nd) = 0
     or position('weak_bonus := 0.15' in nd) = 0 or position('[현장 가공]' in nd) = 0 or position('[결계 야영]' in nd) = 0
     or position('[야전 처치]' in nd) = 0 or position('''job_skill''' in nd) = 0 or position('EXIT WHEN item IS NULL' in nd) > 0 then
    raise exception 'world_expedition_complete 고칠 곳을 모두 찾지 못했습니다.'; end if;
  execute nd;
end $$;

/* ── 4) 원정 진행 기록 ───────────────────────────────────── */
create or replace function public.world_expedition_progress() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); e public.world_expeditions%rowtype; r public.world_map_regions%rowtype; c public.world_characters%rowtype;
  total int; done int; i int; t timestamptz; ph text; wk text; pph text; pwk text; lines jsonb := '[]'::jsonb; nm text; mons text[]; h0 int; h1 int;
  rations int; eaten int := 0; pool text[]; line text; party jsonb; pid uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into e from public.world_expeditions where owner_id = uid and status = 'active';
  if not found then return jsonb_build_object('active', false); end if;
  select * into c from public.world_characters where owner_id = uid;
  select * into r from public.world_map_regions where region_id = e.region_id;
  select node_name into nm from public.world_exploration_nodes where node_id = e.node_id;
  total := case e.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end;
  done := greatest(0, least(total, floor(total * extract(epoch from least(now(), e.ends_at) - e.started_at) / (e.minutes * 60.0))::int));
  mons := array(select monster_name from public.world_region_monsters where region_id = e.region_id order by monster_name);
  rations := coalesce((e.supplies ->> 'travel_ration')::int, 0);
  lines := lines || jsonb_build_object('at', e.started_at, 'kind', 'start', 'text', coalesce(nm, '원정지') || '(으)로 들어섰습니다. 태세: '
    || case e.stance when 'cautious' then '신중' when 'bold' then '강행' else '균형' end || ' · 예정 수색 ' || total || '회');
  pph := public.world_time_phase(e.started_at); pwk := public.world_weather_key(r.territory_id, e.started_at);
  pool := array['%s번째 수색을 마치고 다음 갈래로 나아갑니다.', '바람결에 %m의 기척이 스칩니다.', '%m이(가) 남긴 흔적을 따라 걸음을 옮깁니다.',
    '잠시 멈춰 지도를 고쳐 그립니다.', '물을 긷고 짐을 다시 꾸립니다.', '멀리서 낯선 소리가 들려 걸음을 늦춥니다.', '쓰러진 나무 아래에서 잠시 숨을 고릅니다.',
    '오래된 표식을 발견하고 기록해 둡니다.'];
  for i in 1..done loop
    t := e.started_at + (e.ends_at - e.started_at) * i / total;
    ph := public.world_time_phase(t); wk := public.world_weather_key(r.territory_id, t);
    if ph is distinct from pph then
      lines := lines || jsonb_build_object('at', t, 'kind', 'env', 'text', '시간이 흘러 ' || case ph when 'dawn' then '해돋이' when 'noon' then '한낮' when 'dusk' then '땅거미' else '삼경' end || '이 되었습니다.');
    end if;
    if wk is distinct from pwk then
      lines := lines || jsonb_build_object('at', t, 'kind', 'env', 'text', '날씨가 ' || case wk when 'clear' then '청명' when 'cloudy' then '담운' when 'rain' then '장우'
        when 'fog' then '농무' when 'wind' then '삭풍' when 'snow' then '설한' when 'bloodmist' then '혈무' else wk end || '(으)로 바뀌었습니다.');
    end if;
    pph := ph; pwk := wk;
    h0 := floor(e.minutes * (i - 1) / total / 60.0)::int; h1 := floor(e.minutes * i / total / 60.0)::int;
    if h1 > h0 then
      if eaten < rations then eaten := eaten + 1; lines := lines || jsonb_build_object('at', t, 'kind', 'supply', 'text', '노정 건량을 하나 꺼내 먹었습니다. (남은 건량 ' || (rations - eaten) || ')');
      else lines := lines || jsonb_build_object('at', t, 'kind', 'warn', 'text', '건량이 떨어져 허기진 채로 걷습니다.'); end if;
    end if;
    line := pool[1 + abs(hashtext(e.expedition_id::text || ':' || i)::bigint) % cardinality(pool)];
    line := replace(line, '%s', i::text);
    line := replace(line, '%m', coalesce(mons[1 + abs(hashtext(e.expedition_id::text || '#' || i)::bigint) % greatest(1, cardinality(mons))], '요괴'));
    lines := lines || jsonb_build_object('at', t, 'kind', 'round', 'round', i, 'text', line);
  end loop;
  if now() >= e.ends_at then lines := lines || jsonb_build_object('at', e.ends_at, 'kind', 'end', 'text', '원정을 마치고 돌아왔습니다. 결과를 받으세요.'); end if;
  -- 같은 파티원의 원정
  select party_id into pid from public.world_party_members where owner_id = uid;
  party := coalesce((select jsonb_agg(jsonb_build_object('name', pc.character_name, 'place', pn.node_name, 'region', pr.region_name, 'same_region', x.region_id = e.region_id,
      'rounds_done', greatest(0, least(xt.tot, floor(xt.tot * extract(epoch from least(now(), x.ends_at) - x.started_at) / (x.minutes * 60.0))::int)), 'total_rounds', xt.tot,
      'ends_at', x.ends_at) order by pc.character_name)
    from public.world_party_members pm join public.world_expeditions x on x.owner_id = pm.owner_id and x.status = 'active'
    join public.world_characters pc on pc.owner_id = pm.owner_id left join public.world_exploration_nodes pn on pn.node_id = x.node_id
    left join public.world_map_regions pr on pr.region_id = x.region_id
    cross join lateral (select case x.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end as tot) xt
    where pid is not null and pm.party_id = pid and pm.owner_id <> uid), '[]'::jsonb);
  return jsonb_build_object('active', true, 'place', nm, 'region', r.region_name, 'stance', e.stance, 'rounds_done', done, 'total_rounds', total,
    'started_at', e.started_at, 'ends_at', e.ends_at,
    'next_at', case when done < total then e.started_at + (e.ends_at - e.started_at) * (done + 1) / total end,
    'lines', lines, 'party', party,
    'job_skill', case c.job_key when 'exorcist' then '파사 부적' when 'scout' then '흔적 추적' when 'medic' then '야전 처치'
      when 'sealmaster' then '결계 야영' when 'analyst' then '약점 간파' when 'artificer' then '현장 가공' end);
end $$;

/* ── 5) 직접 거래: 원정 중 금지 + 거래 기록에 전 액수 ─────────── */
do $$ declare def text; nd text; begin
  def := pg_get_functiondef('public.world_trade_direct_offer(uuid,jsonb,bigint,jsonb,bigint)'::regprocedure);
  nd := replace(def, '  r := public.world_field_region(a.location);', '  IF EXISTS (SELECT 1 FROM public.world_expeditions x WHERE x.owner_id IN (uid, p_to) AND x.status = ''active'') THEN
    RAISE EXCEPTION ''원정 중에는 거래할 수 없습니다. 두 사람 모두 원정에서 돌아와야 합니다.'';
  END IF;
  r := public.world_field_region(a.location);');
  if nd = def then raise exception 'world_trade_direct_offer 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
  def := pg_get_functiondef('public.world_trade_direct_respond(uuid,boolean)'::regprocedure);
  nd := replace(def, '  r := public.world_field_region(a.location);', '  IF EXISTS (SELECT 1 FROM public.world_expeditions x WHERE x.owner_id IN (a.owner_id, b.owner_id) AND x.status = ''active'') THEN
    RAISE EXCEPTION ''원정 중에는 거래할 수 없습니다. 두 사람 모두 원정에서 돌아와야 합니다.'';
  END IF;
  r := public.world_field_region(a.location);');
  nd := replace(nd, 'jsonb_build_object(''trade_id'', t.trade_id, ''with'', a.owner_id)', 'jsonb_build_object(''trade_id'', t.trade_id, ''with'', a.owner_id, ''gil'', t.give_gil + t.want_gil)');
  if position('원정 중에는 거래할 수 없습니다' in nd) = 0 or position('''gil'', t.give_gil + t.want_gil' in nd) = 0 then
    raise exception 'world_trade_direct_respond 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
end $$;

-- 새 RPC: 소유자 fn_owner_field, 로그인 사용자만 실행
do $$ declare f text; begin
  foreach f in array array['public.world_fish_spot()', 'public.world_fish()', 'public.world_fish_codex()', 'public.world_expedition_progress()'] loop
    execute format('alter function %s owner to fn_owner_field', f);
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

select 'ok' as result,
  (select count(*) from public.world_fish_species) as species, (select count(*) from public.world_fish_grounds) as grounds,
  (select count(*) from public.world_title_catalog where category = '낚시') as fishing_titles,
  (select count(*) from public.world_crafting_recipes where recipe_id like 'cook_%' or recipe_id like 'fillet_%') as cooking_recipes;
