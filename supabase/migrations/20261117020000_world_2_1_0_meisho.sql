lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

select pg_temp.yh_fix('world_item_hq_traits', array[
$q$k not in ('req_rank', 'w', 'd', 'ww', 'wh', 'top', 'grade', 'z', 't')$q$,
$q$k not in ('req_rank', 'w', 'd', 'ww', 'wh', 'top', 'grade', 'z', 't', 'mz_extra', 'mz_sense')$q$]);

create or replace function public.world_meisho_rules()
 returns jsonb
 language sql
 immutable
as $function$ select $J${"open_min":60,"phase_h":6,"look_days":21,"phase_start":{"night":0,"dawn":6,"noon":12,"dusk":18},"find_w":30,"find_xp":10,"rank":{"base":30,"j":40,"n":50},"qty":{"base":2,"r40":1,"r50":1},"extra_cap":2,"j_pct":{"base":50,"per_rank":3,"cap":95},"n_pct":{"base":4,"cap":15},"stamina":1,"soil":{"pct":{"1":12,"2":9,"3":6},"cap":30,"grade_lv":[[44,3],[38,2],[30,1]]},"incense":"mz_incense","next_n":3,"kinds":{"herb":{"name":"명초","line":"foraging","cat":"herbs","items":["mz_herb","mz_herb_j","mz_herb_n"]},"wood":{"name":"명목","line":"foraging","cat":"wood","items":["mz_wood","mz_wood_j","mz_wood_n"]},"stone":{"name":"명석","line":"mining","cat":"ore","items":["mz_stone","mz_stone_j","mz_stone_n"]}},"fx":{"mz_j_herb":"명소 「명초의 정」","mz_j_wood":"명소 「명목의 정」","mz_j_stone":"명소 「명석의 정」","mz_j_all":"명소 「…의 정」","mz_n_pct":"명소 「이름 서린」","mz_extra":"명소 재료 덤","mz_soil_pct":"흙 살피기 비장도","mz_sense":"열린 명소 기척","mz_next":"다음 명소 보기"},"flags":["mz_sense","mz_next"],"flat":["mz_extra"]}$J$::jsonb $function$;
grant execute on function public.world_meisho_rules() to public;

do $c$ begin
  if exists (select 1 from jsonb_array_elements_text($J$["물안개 새벽 약초 섶","천장에 뿌리 내린 약초밭","먹비 머금은 영초 덤불","아홉 칸 뜰 이름풀 자리","거꾸로 자란 향나무","천 년 묵은 객주 대들보","벌판의 외톨이 회화나무","먹비 숲 흑단 고목","봉인 계단 밑 영석 맥","녹슨 대장간 숫돌 바닥","가라앉는 돌길 검은 반석","명부 탑 주춧돌 틈","명초","명초의 정","이름 서린 명초","명목","명목의 정","이름 서린 명목","명석","명석의 정","이름 서린 명석","명장 곡괭이","명장 낫","명석 쇠고리 노리개","명장 채집도","명목 낚싯대","명목 탈","명장 나침반","명장 등","명석 영패","명초 관모","명초 미투리","명초 향낭 노리개","이름 서린 도포","명석 징 장화","명목 가죽 부적낭","명소 야행의","명소 향","명소 지킴 부적","명초 정기환","명초 정 영단","이름 서린 환","명초 산채 정식","명목 훈연 한 상","이름 서린 잔칫상"]$J$::jsonb) n(v)
     where n.v in (select region_name from public.world_map_regions) or n.v in (select node_name from public.world_exploration_nodes)
        or n.v in (select spot_name from public.world_gathering_spots) or n.v in (select ground_name from public.world_fish_grounds)
        or n.v in (select ground_name from public.world_expedition_grounds) or n.v in (select site_name from public.world_region_sites)
        or n.v in (select item_name from public.world_item_catalog where public.world_item_base(item_id) <> all (array(select jsonb_array_elements_text($J$["mz_herb","mz_herb_j","mz_herb_n","mz_wood","mz_wood_j","mz_wood_n","mz_stone","mz_stone_j","mz_stone_n","lt_pick_mz","lt_sickle_mz","n_mz_iron","lt_knife_mz","lt_rod_mz","k_mz_wood","lt_compass_mz","lt_lantern_mz","m_mz_stone","h_mz_herb","s_mz_herb","n_mz_herb","a_mz_robe","s_mz_stone","m_mz_wood","a_mz_shade","mz_incense","mz_ward","mz_pill","mz_elixir","mz_clear","mz_meal_herb","mz_meal_wood","mz_meal_feast"]$J$::jsonb))))) then
    raise exception '명소·명소 물품 이름이 이미 있는 이름과 겹칩니다';
  end if;
end $c$;
create table if not exists public.world_meisho (
  meisho_id text primary key,
  meisho_name text not null unique,
  region_id text not null references public.world_map_regions(region_id),
  node_id uuid not null references public.world_exploration_nodes(node_id) on delete cascade,
  kind text not null check (kind in ('herb', 'wood', 'stone')),
  phase text not null check (phase in ('dawn', 'noon', 'dusk', 'night')),
  weather text not null,
  min_level integer not null,
  description text not null default '',
  sort integer not null default 0,
  active boolean not null default true);
create index if not exists idx_world_meisho_node on public.world_meisho(node_id);
create index if not exists idx_world_meisho_region on public.world_meisho(region_id);

create table if not exists public.world_meisho_finds (
  owner_id uuid not null,
  meisho_id text not null references public.world_meisho(meisho_id) on delete cascade,
  found_at timestamptz not null default now(),
  dug_at timestamptz,
  dig_count integer not null default 0,
  soil_day date,
  soil_count integer not null default 0,
  primary key (owner_id, meisho_id));
create index if not exists idx_world_meisho_finds_meisho on public.world_meisho_finds(meisho_id);

alter table public.world_meisho enable row level security;
alter table public.world_meisho_finds enable row level security;
revoke all on public.world_meisho, public.world_meisho_finds from anon, authenticated;
do $g$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' loop
    execute format('grant select on public.world_meisho to %I', x);
    execute format('grant select, insert, update, delete on public.world_meisho_finds to %I', x);
  end loop;
end $g$;

insert into public.world_status_catalog(status_key, status_name, polarity, description, duration_minutes, effects, max_stacks, active, icon, cure)
select x.status_key, x.status_name, 'positive', x.description, x.duration_minutes, x.effects, 1, true, x.icon, '시간이 지나면 사라집니다.'
  from jsonb_to_recordset($J$[{"status_key":"mz_incense","status_name":"명소 향","duration_minutes":1440,"effects":{"mz_next":1},"icon":"eye","description":"명소 향의 연기가 다음에 열릴 명소를 짚어 줍니다. 현장 채집터 칸에 다음 명소가 언제·어디서 열리는지 보입니다."},{"status_key":"mz_ward","status_name":"명소 지킴","duration_minutes":360,"effects":{"erosion_pct":-20,"mental_loss_pct":-20,"rare_loot_pct":8},"icon":"shield","description":"명소의 기운을 접은 부적이 몸을 지킵니다."},{"status_key":"mz_vigor","status_name":"명초 정기","duration_minutes":360,"effects":{"healing_pct":15,"gather_qty_pct":10},"icon":"leaf","description":"명초의 정이 기운을 북돋아 회복이 잘 되고 손이 바빠집니다."},{"status_key":"mz_clear","status_name":"이름 서린 맑음","duration_minutes":360,"effects":{"mental_loss_pct":-25,"erosion_pct":-20},"icon":"spark","description":"이름 서린 명초가 마음을 맑게 붙잡아 줍니다."},{"status_key":"mz_full","status_name":"명초 산채의 든든함","duration_minutes":480,"effects":{"healing_pct":10,"gather_qty_pct":8},"icon":"leaf","description":"명초 산채 정식으로 배를 채워 오래 든든합니다."},{"status_key":"mz_smoke","status_name":"명목 훈연의 기운","duration_minutes":480,"effects":{"incoming_damage_pct":-6,"combat_damage_pct":4},"icon":"flame","description":"명목 연기에 익힌 한 상이 몸을 단단히 데워 줍니다."},{"status_key":"mz_feast","status_name":"이름 서린 잔치","duration_minutes":720,"effects":{"healing_pct":10,"gather_qty_pct":10,"craft_quality":5,"mental_loss_pct":-10},"icon":"spark","description":"이름 서린 재료로 차린 잔칫상의 기운이 반나절 갑니다."}]$J$::jsonb) as x(status_key text, status_name text, description text, duration_minutes int, effects jsonb, icon text)
on conflict (status_key) do update set status_name = excluded.status_name, description = excluded.description, duration_minutes = excluded.duration_minutes, effects = excluded.effects, icon = excluded.icon;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, tradeable, reference_price, stack_size, use_fx)
select x.item_id, x.item_name, x.category, x.tier, x.description, x.stackable, x.required_stats, x.minimum_level, x.rarity, x.acquisition_difficulty, x.drop_rate_modifier, x.equipment_traits, x.tradeable, x.reference_price, x.stack_size, x.use_fx
  from jsonb_to_recordset($J$[{"item_id":"mz_herb","item_name":"명초","category":"material","tier":5,"description":"이름난 자리에서만 자라는 약초. 한 철을 한 시간에 몰아 산다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":600,"stack_size":40,"use_fx":null},{"item_id":"mz_herb_j","item_name":"명초의 정","category":"material","tier":6,"description":"명초에서 가장 맑은 기운만 모인 잎. 손끝에 닿으면 시든 풀도 고개를 든다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":1500,"stack_size":20,"use_fx":null},{"item_id":"mz_herb_n","item_name":"이름 서린 명초","category":"material","tier":7,"description":"잎맥마다 옛사람의 이름이 서린 명초. 명부 정리 전에 누군가 지키려 심어 둔 것이라 한다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":4000,"stack_size":20,"use_fx":null},{"item_id":"mz_wood","item_name":"명목","category":"material","tier":5,"description":"이름난 자리의 나무에서 얻은 목재. 결이 곧고 썩지 않는다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":600,"stack_size":40,"use_fx":null},{"item_id":"mz_wood_j","item_name":"명목의 정","category":"material","tier":6,"description":"명목 한가운데의 단단한 속심. 두드리면 맑은 소리가 오래 남는다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":1500,"stack_size":20,"use_fx":null},{"item_id":"mz_wood_n","item_name":"이름 서린 명목","category":"material","tier":7,"description":"나이테마다 이름이 새겨진 명목. 깎는 칼끝이 저절로 결을 따라간다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":4000,"stack_size":20,"use_fx":null},{"item_id":"mz_stone","item_name":"명석","category":"material","tier":5,"description":"이름난 자리의 돌에서 떼어 낸 조각. 차갑고 무겁다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":600,"stack_size":40,"use_fx":null},{"item_id":"mz_stone_j","item_name":"명석의 정","category":"material","tier":6,"description":"명석 안에 맺힌 맑은 결정. 불에 달궈도 결이 흐트러지지 않는다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":1500,"stack_size":20,"use_fx":null},{"item_id":"mz_stone_n","item_name":"이름 서린 명석","category":"material","tier":7,"description":"이름이 결 따라 새겨진 명석. 쥐고 있으면 낯선 이름이 귀에 맴돈다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":4000,"stack_size":20,"use_fx":null},{"item_id":"lt_pick_mz","item_name":"명장 곡괭이","category":"tool","tier":7,"description":"명장이 명석으로 날을 세운 곡괭이. 명소에서 「명석의 정」을 더 잘 가려낸다.","stackable":false,"required_stats":{},"minimum_level":40,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"정밀 채집","req_line":"gathering_rank","req_rank":30,"gathering_bonus_pct":32,"rare_loot_pct":9,"mz_j_stone":15},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"lt_sickle_mz","item_name":"명장 낫","category":"tool","tier":7,"description":"명장이 명초 줄기를 베어 날을 길들인 낫. 명소에서 「명초의 정」을 더 잘 가려낸다.","stackable":false,"required_stats":{},"minimum_level":40,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"정밀 채집","req_line":"gathering_rank","req_rank":30,"gathering_bonus_pct":28,"sig_pct":10,"sig_where":"herb","mz_j_herb":15},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"n_mz_iron","item_name":"명석 쇠고리 노리개","category":"norigae","tier":7,"description":"명석 쇠고리를 꿴 노리개. 명소에서 캘 때 명소 재료를 하나 더 거둔다.","stackable":false,"required_stats":{"perception":36},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"노리개","gather_qty_pct":22,"mz_extra":1},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"lt_knife_mz","item_name":"명장 채집도","category":"tool","tier":7,"description":"명목 자루에 맑은 날을 박은 채집도. 명소에서 「명목의 정」을 더 잘 가려낸다.","stackable":false,"required_stats":{},"minimum_level":40,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"정밀 채집","req_line":"gathering_rank","req_rank":30,"gathering_bonus_pct":34,"rare_loot_pct":10,"mz_j_wood":15},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"lt_rod_mz","item_name":"명목 낚싯대","category":"tool","tier":7,"description":"명목 한 가지를 통째로 깎은 낚싯대. 명어가 조금 더 잘 문다.","stackable":false,"required_stats":{},"minimum_level":40,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"낚시","life_slot":"fishing","fish_bite_pct":23,"fish_rare_pct":18,"fish_size_pct":12,"named_wt":0.12},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"k_mz_wood","item_name":"명목 탈","category":"mask","tier":7,"description":"명목으로 깎은 탈. 쓰고 흙을 살피면 묻힌 것이 더 잘 보인다.","stackable":false,"required_stats":{"agility":36},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"탈","presence":-70,"encounter_pct":-22,"mz_soil_pct":50},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"lt_compass_mz","item_name":"명장 나침반","category":"tool","tier":7,"description":"명석 바늘을 띄운 나침반. 지금 있는 지역에 열린 명소가 있으면 바늘이 그쪽을 가리킨다.","stackable":false,"required_stats":{},"minimum_level":40,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"탐사","req_line":"investigation_rank","req_rank":30,"life_slot":"explore","search_find_pct":48,"clue_bonus_pct":9,"mz_sense":1},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"lt_lantern_mz","item_name":"명장 등","category":"tool","tier":7,"description":"명석의 정을 심지 삼은 등. 명소에서 「이름 서린」 재료가 더 잘 보인다.","stackable":false,"required_stats":{},"minimum_level":40,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"정밀 채집","req_line":"gathering_rank","req_rank":30,"gathering_bonus_pct":26,"sig_pct":12,"sig_where":"dark","mz_n_pct":3},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"m_mz_stone","item_name":"명석 영패","category":"amulet","tier":7,"description":"이름 서린 명석을 깎은 영패. 지니면 명소에서 「이름 서린」 재료가 더 잘 보인다.","stackable":false,"required_stats":{"willpower":36},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"호신부","presence":28,"incoming_damage_pct":-14,"mz_n_pct":2},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"h_mz_herb","item_name":"명초 관모","category":"hat","tier":7,"description":"명초의 정으로 물들인 관모. 흙을 살필 때 눈이 밝아진다.","stackable":false,"required_stats":{"willpower":36},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"관모","erosion_pct":-28,"mental_loss_pct":-42,"mz_soil_pct":30},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"s_mz_herb","item_name":"명초 미투리","category":"shoes","tier":7,"description":"명초 줄기를 꼬아 삼은 미투리. 발끝으로 흙의 결을 느낀다.","stackable":false,"required_stats":{"vitality":36},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"신","travel_time_pct":-28,"mz_soil_pct":30},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"n_mz_herb","item_name":"명초 향낭 노리개","category":"norigae","tier":7,"description":"명초의 정을 넣은 향낭 노리개. 어느 명소에서든 「…의 정」을 더 잘 가려낸다.","stackable":false,"required_stats":{"spirit_affinity":36},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"노리개","rare_loot_pct":22,"mz_j_all":10},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"a_mz_robe","item_name":"이름 서린 도포","category":"armor","tier":7,"description":"이름 서린 명초로 물들인 도포. 명소에서 「이름 서린」 재료가 더 잘 보인다.","stackable":false,"required_stats":{"willpower":48},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"방호","defense":26,"erosion_pct":-22,"damage_reduction_pct":14,"mz_n_pct":2},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"s_mz_stone","item_name":"명석 징 장화","category":"shoes","tier":7,"description":"바닥에 명석 징을 박은 장화. 명소에서 캘 때 명소 재료를 하나 더 거둔다.","stackable":false,"required_stats":{"vitality":36},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"신","defense":11,"presence":28,"mz_extra":1},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"m_mz_wood","item_name":"명목 가죽 부적낭","category":"amulet","tier":7,"description":"명목의 정을 넣어 꿰맨 가죽 부적낭. 어느 명소에서든 「…의 정」을 더 잘 가려낸다.","stackable":false,"required_stats":{"spirit_affinity":36},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"호신부","magic_pct":22,"mz_j_all":10},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"a_mz_shade","item_name":"명소 야행의","category":"armor","tier":7,"description":"이름 서린 명목 물을 들인 야행의. 흙을 살필 때 묻힌 것의 기척을 잡는다.","stackable":false,"required_stats":{"agility":48},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{"trait":"방호","defense":23,"crit_pct":7,"presence":-56,"evasion_pct":7,"mz_soil_pct":30},"tradeable":true,"reference_price":100,"stack_size":1,"use_fx":null},{"item_id":"mz_incense","item_name":"명소 향","category":"consumable","tier":6,"description":"명초와 명목을 함께 사른 향. 피우면 하루 동안 다음에 열릴 명소가 언제·어디서 열리는지 보인다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":100,"stack_size":20,"use_fx":{"er":0,"hp":0,"mn":0,"sp":0,"stam":0,"buffs":["mz_incense"],"cures":[]}},{"item_id":"mz_ward","item_name":"명소 지킴 부적","category":"consumable","tier":7,"description":"이름 서린 명초를 넣어 접은 부적. 여섯 시간 침식과 정신 손실을 덜고 귀한 것이 잘 보인다.","stackable":true,"required_stats":{},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":100,"stack_size":20,"use_fx":{"er":0,"hp":0,"mn":0,"sp":0,"stam":0,"buffs":["mz_ward"],"cures":[]}},{"item_id":"mz_pill","item_name":"명초 정기환","category":"consumable","tier":6,"description":"명초를 달여 빚은 환약. 체력·정신·영력을 한꺼번에 채운다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":100,"stack_size":20,"use_fx":{"er":0,"hp":60,"mn":30,"sp":40,"stam":0,"buffs":[],"cures":[]}},{"item_id":"mz_elixir","item_name":"명초 정 영단","category":"consumable","tier":6,"description":"명초의 정을 굳힌 영단. 여섯 시간 회복이 잘 되고 채집량이 늘어난다.","stackable":true,"required_stats":{},"minimum_level":36,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":100,"stack_size":20,"use_fx":{"er":0,"hp":0,"mn":20,"sp":0,"stam":0,"buffs":["mz_vigor"],"cures":[]}},{"item_id":"mz_clear","item_name":"이름 서린 환","category":"consumable","tier":7,"description":"이름 서린 명초로 빚은 환. 침식을 크게 덜고 여섯 시간 마음을 맑게 붙잡는다.","stackable":true,"required_stats":{},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":100,"stack_size":20,"use_fx":{"er":-40,"hp":0,"mn":40,"sp":0,"stam":0,"buffs":["mz_clear"],"cures":[]}},{"item_id":"mz_meal_herb","item_name":"명초 산채 정식","category":"consumable","tier":6,"description":"명초를 데쳐 차린 산채 정식. 여덟 시간 든든하다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":100,"stack_size":20,"use_fx":{"er":0,"hp":50,"mn":15,"sp":0,"stam":0,"buffs":["mz_full"],"cures":[]}},{"item_id":"mz_meal_wood","item_name":"명목 훈연 한 상","category":"consumable","tier":6,"description":"명목 연기에 생선을 익힌 한 상. 여덟 시간 몸이 단단하다.","stackable":true,"required_stats":{},"minimum_level":36,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":100,"stack_size":20,"use_fx":{"er":0,"hp":70,"mn":0,"sp":0,"stam":0,"buffs":["mz_smoke"],"cures":[]}},{"item_id":"mz_meal_feast","item_name":"이름 서린 잔칫상","category":"consumable","tier":7,"description":"이름 서린 재료로 차린 잔칫상. 기운이 반나절 이어진다.","stackable":true,"required_stats":{},"minimum_level":42,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":100,"stack_size":20,"use_fx":{"er":0,"hp":100,"mn":40,"sp":0,"stam":0,"buffs":["mz_feast"],"cures":[]}}]$J$::jsonb) as x(item_id text, item_name text, category text, tier int, description text, stackable boolean, required_stats jsonb, minimum_level int, rarity text,
    acquisition_difficulty int, drop_rate_modifier numeric, equipment_traits jsonb, tradeable boolean, reference_price bigint, stack_size int, use_fx jsonb)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description, required_stats = excluded.required_stats,
  equipment_traits = excluded.equipment_traits, minimum_level = excluded.minimum_level, stack_size = excluded.stack_size, tradeable = excluded.tradeable, use_fx = excluded.use_fx;

insert into public.world_meisho(meisho_id, meisho_name, region_id, node_id, kind, phase, weather, min_level, description, sort)
select x.id, x.name, x.region, n.node_id, x.kind, x.phase, x.weather, n.min_level, x."desc", x.sort
  from jsonb_to_recordset($J$[{"id":"mz_reed_dawn","name":"물안개 새벽 약초 섶","region":"ash_reeds","node":"잿빛 물길","kind":"herb","phase":"dawn","weather":"fog","desc":"잿빛 물길 가장자리, 새벽 물안개가 고일 때만 뿌리 끝이 젖어 드러나는 약초 섶이다.","sort":1},{"id":"mz_shrine_ceiling","name":"천장에 뿌리 내린 약초밭","region":"inverted_shrine","node":"천장 밟는 회랑","kind":"herb","phase":"night","weather":"clear","desc":"거꾸로 선 사당 회랑 천장에 거꾸로 뿌리 내린 약초밭이다. 맑은 삼경에만 잎이 아래로 늘어진다.","sort":2},{"id":"mz_meokbi_herb","name":"먹비 머금은 영초 덤불","region":"meokbi_forest","node":"빗물 고인 덤불","kind":"herb","phase":"noon","weather":"drizzle","desc":"가는 비가 내리는 한낮에만 먹빛을 벗고 푸른 잎을 내미는 영초 덤불이다.","sort":3},{"id":"mz_court_grass","name":"아홉 칸 뜰 이름풀 자리","region":"nine_court","node":"첫째 칸","kind":"herb","phase":"dusk","weather":"cloudy","desc":"흐린 땅거미에만 돋는 풀이다. 잎맥이 누군가의 이름 획을 닮았다.","sort":4},{"id":"mz_shrine_juniper","name":"거꾸로 자란 향나무","region":"inverted_shrine","node":"거꾸로 걸린 종루","kind":"wood","phase":"dusk","weather":"cloudy","desc":"종루 들보에서 땅을 향해 자란 향나무다. 흐린 땅거미에 결이 풀려 깎아 낼 수 있다.","sort":5},{"id":"mz_market_beam","name":"천 년 묵은 객주 대들보","region":"moonless_market","node":"빈 좌판 골목","kind":"wood","phase":"night","weather":"fog","desc":"달 없는 저잣거리가 생기기 전부터 서 있던 객주의 대들보다. 짙은 안개가 낀 삼경에만 나뭇결이 살아난다.","sort":6},{"id":"mz_field_locust","name":"벌판의 외톨이 회화나무","region":"blank_field","node":"흰 억새 들","kind":"wood","phase":"dawn","weather":"wind","desc":"빈칸 벌판에 홀로 선 회화나무다. 삭풍이 부는 새벽에만 마른 가지가 저절로 떨어진다.","sort":7},{"id":"mz_meokbi_ebony","name":"먹비 숲 흑단 고목","region":"meokbi_forest","node":"검은 잎 오솔길","kind":"wood","phase":"night","weather":"rain","desc":"먹비를 가장 오래 맞은 흑단 고목이다. 장대비가 쏟아지는 삼경에만 속살이 비친다.","sort":8},{"id":"mz_abyss_vein","name":"봉인 계단 밑 영석 맥","region":"sealed_abyss","node":"봉인 계단","kind":"stone","phase":"noon","weather":"cloudy","desc":"봉인 계단 아래로 흐르는 영석 맥이다. 흐린 한낮에만 맥이 떨며 틈을 연다.","sort":9},{"id":"mz_market_whetstone","name":"녹슨 대장간 숫돌 바닥","region":"moonless_market","node":"녹슨 대장간 터","kind":"stone","phase":"dusk","weather":"clear","desc":"수많은 칼을 갈아 낸 숫돌 바닥이다. 맑은 땅거미에 바닥 아래 단단한 돌이 드러난다.","sort":10},{"id":"mz_core_slab","name":"가라앉는 돌길 검은 반석","region":"gwiheo_core","node":"가라앉는 돌길","kind":"stone","phase":"dawn","weather":"cloudy","desc":"귀허로 가라앉아 가는 돌길 끝의 검은 반석이다. 흐린 새벽에만 물 위로 한 뼘 떠오른다.","sort":11},{"id":"mz_tower_plinth","name":"명부 탑 주춧돌 틈","region":"myeongbu_tower","node":"무너진 회랑","kind":"stone","phase":"night","weather":"fog","desc":"명부 탑을 떠받친 주춧돌 사이 틈이다. 안개 낀 삼경에만 틈 안쪽 돌이 빛을 낸다.","sort":12}]$J$::jsonb) as x(id text, name text, region text, node text, kind text, phase text, weather text, "desc" text, sort int)
  join lateral (select z.node_id, z.min_level from public.world_exploration_nodes z where z.region_id = x.region and z.node_name = x.node order by z.hierarchy_level limit 1) n on true
on conflict (meisho_id) do update set meisho_name = excluded.meisho_name, region_id = excluded.region_id, node_id = excluded.node_id, kind = excluded.kind, phase = excluded.phase,
  weather = excluded.weather, min_level = excluded.min_level, description = excluded.description, sort = excluded.sort;
do $c$ begin
  if (select count(*) from public.world_meisho) <> 12 then raise exception '명소 답사 지점을 찾지 못했습니다'; end if;
  if exists (select 1 from public.world_meisho m join public.world_map_regions r using (region_id) where r.is_safe_zone or not r.active) then raise exception '명소는 바깥 지역에만'; end if;
  if exists (select 1 from public.world_meisho m join public.world_map_regions r using (region_id) join public.world_weather_climate cl on cl.territory_id = coalesce((select territory_id from public.world_weather_climate where territory_id = r.territory_id), 'capital')
      where not cl.weights ? m.weather) then raise exception '그 땅에 오지 않는 날씨를 고른 명소가 있습니다'; end if;
end $c$;

insert into public.world_tool_lines(item_id, line) select x.key, x.value from jsonb_each_text($J${"lt_pick_mz":"pick","lt_sickle_mz":"sickle","lt_knife_mz":"knife","lt_rod_mz":"rod","lt_compass_mz":"explore","lt_lantern_mz":"lantern"}$J$::jsonb) x
 where not exists (select 1 from public.world_tool_lines t where t.item_id = x.key);

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool_tier, required_location, description, minimum_level, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field)
select x.recipe_id, x.recipe_name, x.output_item, x.output_qty, x.ingredients, 1, x.required_location, x.description, x.minimum_level, x.recipe_difficulty, 0, x.required_skill, x.required_skill_rank, x.craft_field
  from jsonb_to_recordset($J$[{"recipe_id":"r_lt_pick_mz","recipe_name":"명장 곡괭이 만들기","output_item":"lt_pick_mz","output_qty":1,"ingredients":{"mz_stone":4,"erased_plate":2,"bronze_scale_plate":2,"drifting_name_thread":1},"required_location":"묵창 나루","description":"명장의 솜씨로 명장 곡괭이을(를) 만든다.","minimum_level":40,"recipe_difficulty":7,"required_skill":"smithing","required_skill_rank":30,"craft_field":"smithing"},{"recipe_id":"r_lt_sickle_mz","recipe_name":"명장 낫 만들기","output_item":"lt_sickle_mz","output_qty":1,"ingredients":{"mz_herb_j":2,"mz_herb":3,"steel_ingot":2,"drifting_name_thread":2},"required_location":"묵창 나루","description":"명장의 솜씨로 명장 낫을(를) 만든다.","minimum_level":40,"recipe_difficulty":7,"required_skill":"smithing","required_skill_rank":40,"craft_field":"smithing"},{"recipe_id":"r_n_mz_iron","recipe_name":"명석 쇠고리 노리개 만들기","output_item":"n_mz_iron","output_qty":1,"ingredients":{"mz_stone_n":1,"mz_stone_j":2,"gwiheo_iron":4,"drifting_name_thread":2},"required_location":"묵창 나루","description":"명장의 솜씨로 명석 쇠고리 노리개을(를) 만든다.","minimum_level":42,"recipe_difficulty":7,"required_skill":"smithing","required_skill_rank":50,"craft_field":"smithing"},{"recipe_id":"r_lt_knife_mz","recipe_name":"명장 채집도 만들기","output_item":"lt_knife_mz","output_qty":1,"ingredients":{"mz_wood":4,"meokbi_ebony":2,"bronze_scale_plate":2,"drifting_name_thread":1},"required_location":"묵창 나루","description":"명장의 솜씨로 명장 채집도을(를) 만든다.","minimum_level":40,"recipe_difficulty":7,"required_skill":"carpentry","required_skill_rank":30,"craft_field":"carpentry"},{"recipe_id":"r_lt_rod_mz","recipe_name":"명목 낚싯대 만들기","output_item":"lt_rod_mz","output_qty":1,"ingredients":{"mz_wood_j":2,"mz_wood":3,"carp_glue":2,"mukchang_ink":1},"required_location":"묵창 나루","description":"명장의 솜씨로 명목 낚싯대을(를) 만든다.","minimum_level":40,"recipe_difficulty":7,"required_skill":"carpentry","required_skill_rank":40,"craft_field":"carpentry"},{"recipe_id":"r_k_mz_wood","recipe_name":"명목 탈 만들기","output_item":"k_mz_wood","output_qty":1,"ingredients":{"mz_wood_n":1,"mz_wood_j":2,"shadow_fang":3,"drifting_name_thread":2},"required_location":"묵창 나루","description":"명장의 솜씨로 명목 탈을(를) 만든다.","minimum_level":42,"recipe_difficulty":7,"required_skill":"carpentry","required_skill_rank":50,"craft_field":"carpentry"},{"recipe_id":"r_lt_compass_mz","recipe_name":"명장 나침반 만들기","output_item":"lt_compass_mz","output_qty":1,"ingredients":{"mz_stone":3,"spirit_glass":1,"register_slip":2,"erased_plate":1},"required_location":"묵창 나루","description":"명장의 솜씨로 명장 나침반을(를) 만든다.","minimum_level":40,"recipe_difficulty":7,"required_skill":"artifice","required_skill_rank":30,"craft_field":"artifice"},{"recipe_id":"r_lt_lantern_mz","recipe_name":"명장 등 만들기","output_item":"lt_lantern_mz","output_qty":1,"ingredients":{"mz_stone_j":2,"mz_wood":2,"shad_oil":2,"meokgwi_lump":2},"required_location":"묵창 나루","description":"명장의 솜씨로 명장 등을(를) 만든다.","minimum_level":40,"recipe_difficulty":7,"required_skill":"artifice","required_skill_rank":40,"craft_field":"artifice"},{"recipe_id":"r_m_mz_stone","recipe_name":"명석 영패 만들기","output_item":"m_mz_stone","output_qty":1,"ingredients":{"mz_stone_n":1,"mz_stone_j":2,"mirror_shard":2,"drifting_name_thread":2},"required_location":"묵창 나루","description":"명장의 솜씨로 명석 영패을(를) 만든다.","minimum_level":42,"recipe_difficulty":7,"required_skill":"artifice","required_skill_rank":50,"craft_field":"artifice"},{"recipe_id":"r_mz_incense","recipe_name":"명소 향 만들기","output_item":"mz_incense","output_qty":2,"ingredients":{"mz_herb":2,"mz_wood":1,"ghost_ash":1,"mukchang_ink":1},"required_location":null,"description":"명장의 솜씨로 명소 향을(를) 만든다.","minimum_level":30,"recipe_difficulty":4,"required_skill":"wardcraft","required_skill_rank":30,"craft_field":"sealing"},{"recipe_id":"r_h_mz_herb","recipe_name":"명초 관모 만들기","output_item":"h_mz_herb","output_qty":1,"ingredients":{"mz_herb_j":2,"blank_hanji":3,"mukchang_ink":2,"drifting_name_thread":2},"required_location":"묵창 나루","description":"명장의 솜씨로 명초 관모을(를) 만든다.","minimum_level":42,"recipe_difficulty":7,"required_skill":"wardcraft","required_skill_rank":40,"craft_field":"sealing"},{"recipe_id":"r_mz_ward","recipe_name":"명소 지킴 부적 만들기","output_item":"mz_ward","output_qty":2,"ingredients":{"mz_herb_n":1,"mz_stone_j":1,"blank_hanji":2,"mukchang_ink":2},"required_location":null,"description":"명장의 솜씨로 명소 지킴 부적을(를) 만든다.","minimum_level":42,"recipe_difficulty":4,"required_skill":"wardcraft","required_skill_rank":50,"craft_field":"sealing"},{"recipe_id":"r_s_mz_herb","recipe_name":"명초 미투리 만들기","output_item":"s_mz_herb","output_qty":1,"ingredients":{"mz_herb":4,"reed_silk":3,"moonless_silk":2,"drifting_name_thread":1},"required_location":"묵창 나루","description":"명장의 솜씨로 명초 미투리을(를) 만든다.","minimum_level":42,"recipe_difficulty":7,"required_skill":"weaving","required_skill_rank":30,"craft_field":"weaving"},{"recipe_id":"r_n_mz_herb","recipe_name":"명초 향낭 노리개 만들기","output_item":"n_mz_herb","output_qty":1,"ingredients":{"mz_herb_j":2,"mz_wood_j":1,"moonless_silk":3,"drifting_name_thread":2},"required_location":"묵창 나루","description":"명장의 솜씨로 명초 향낭 노리개을(를) 만든다.","minimum_level":42,"recipe_difficulty":7,"required_skill":"weaving","required_skill_rank":40,"craft_field":"weaving"},{"recipe_id":"r_a_mz_robe","recipe_name":"이름 서린 도포 만들기","output_item":"a_mz_robe","output_qty":1,"ingredients":{"mz_herb_n":1,"mz_herb_j":2,"moonless_silk":4,"meokbi_moss":3,"drifting_name_thread":3},"required_location":"묵창 나루","description":"명장의 솜씨로 이름 서린 도포을(를) 만든다.","minimum_level":42,"recipe_difficulty":7,"required_skill":"weaving","required_skill_rank":50,"craft_field":"weaving"},{"recipe_id":"r_s_mz_stone","recipe_name":"명석 징 장화 만들기","output_item":"s_mz_stone","output_qty":1,"ingredients":{"mz_stone":4,"meokgwi_lump":3,"bronze_scale_plate":2,"drifting_name_thread":1},"required_location":"묵창 나루","description":"명장의 솜씨로 명석 징 장화을(를) 만든다.","minimum_level":42,"recipe_difficulty":7,"required_skill":"leatherwork","required_skill_rank":30,"craft_field":"leatherwork"},{"recipe_id":"r_m_mz_wood","recipe_name":"명목 가죽 부적낭 만들기","output_item":"m_mz_wood","output_qty":1,"ingredients":{"mz_wood_j":2,"mz_herb":2,"shadow_fang":2,"drifting_name_thread":2},"required_location":"묵창 나루","description":"명장의 솜씨로 명목 가죽 부적낭을(를) 만든다.","minimum_level":42,"recipe_difficulty":7,"required_skill":"leatherwork","required_skill_rank":40,"craft_field":"leatherwork"},{"recipe_id":"r_a_mz_shade","recipe_name":"명소 야행의 만들기","output_item":"a_mz_shade","output_qty":1,"ingredients":{"mz_wood_n":1,"mz_stone_j":2,"shadow_fang":3,"meokgwi_lump":3,"drifting_name_thread":3},"required_location":"묵창 나루","description":"명장의 솜씨로 명소 야행의을(를) 만든다.","minimum_level":42,"recipe_difficulty":7,"required_skill":"leatherwork","required_skill_rank":50,"craft_field":"leatherwork"},{"recipe_id":"r_mz_pill","recipe_name":"명초 정기환 만들기","output_item":"mz_pill","output_qty":2,"ingredients":{"mz_herb":2,"herbal_extract":1,"medicine_base":1},"required_location":null,"description":"명장의 솜씨로 명초 정기환을(를) 만든다.","minimum_level":30,"recipe_difficulty":4,"required_skill":"alchemy","required_skill_rank":30,"craft_field":"alchemy"},{"recipe_id":"r_mz_elixir","recipe_name":"명초 정 영단 만들기","output_item":"mz_elixir","output_qty":2,"ingredients":{"mz_herb_j":1,"mz_herb":1,"spirit_core":1},"required_location":null,"description":"명장의 솜씨로 명초 정 영단을(를) 만든다.","minimum_level":36,"recipe_difficulty":4,"required_skill":"alchemy","required_skill_rank":40,"craft_field":"alchemy"},{"recipe_id":"r_mz_clear","recipe_name":"이름 서린 환 만들기","output_item":"mz_clear","output_qty":2,"ingredients":{"mz_herb_n":1,"mz_herb_j":1,"spirit_core":1,"oblivion_crystal":1},"required_location":null,"description":"명장의 솜씨로 이름 서린 환을(를) 만든다.","minimum_level":42,"recipe_difficulty":4,"required_skill":"alchemy","required_skill_rank":50,"craft_field":"alchemy"},{"recipe_id":"r_mz_meal_herb","recipe_name":"명초 산채 정식 만들기","output_item":"mz_meal_herb","output_qty":2,"ingredients":{"mz_herb":2,"herb":2,"fish_fillet":1},"required_location":null,"description":"명장의 솜씨로 명초 산채 정식을(를) 만든다.","minimum_level":30,"recipe_difficulty":4,"required_skill":"cooking","required_skill_rank":30,"craft_field":"cooking"},{"recipe_id":"r_mz_meal_wood","recipe_name":"명목 훈연 한 상 만들기","output_item":"mz_meal_wood","output_qty":2,"ingredients":{"mz_wood_j":1,"mz_wood":1,"fish_fillet":2},"required_location":null,"description":"명장의 솜씨로 명목 훈연 한 상을(를) 만든다.","minimum_level":36,"recipe_difficulty":4,"required_skill":"cooking","required_skill_rank":40,"craft_field":"cooking"},{"recipe_id":"r_mz_meal_feast","recipe_name":"이름 서린 잔칫상 만들기","output_item":"mz_meal_feast","output_qty":2,"ingredients":{"mz_herb_n":1,"mz_wood_j":1,"mz_stone_j":1,"fish_fillet":3},"required_location":null,"description":"명장의 솜씨로 이름 서린 잔칫상을(를) 만든다.","minimum_level":42,"recipe_difficulty":4,"required_skill":"cooking","required_skill_rank":50,"craft_field":"cooking"}]$J$::jsonb) as x(recipe_id text, recipe_name text, output_item text, output_qty int, ingredients jsonb, required_location text, description text, minimum_level int,
    recipe_difficulty int, required_skill text, required_skill_rank int, craft_field text)
on conflict (recipe_id) do update set recipe_name = excluded.recipe_name, output_item = excluded.output_item, output_qty = excluded.output_qty, ingredients = excluded.ingredients, craft_field = excluded.craft_field,
  required_location = excluded.required_location, minimum_level = excluded.minimum_level, description = excluded.description, recipe_difficulty = excluded.recipe_difficulty,
  required_skill = excluded.required_skill, required_skill_rank = excluded.required_skill_rank;

update public.world_item_catalog i set reference_price = greatest(
    ceil(1.2 * (select min(t.v) from (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) v from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id group by cr.recipe_id) t)),
    coalesce(ceil(1.15 * (select max(f.reference_price) from public.world_item_catalog f where f.tier = 6 and f.category = i.category and f.base_item_id is null
      and f.item_id not like 'raid%' and coalesce((f.equipment_traits ->> 'life_slot'), '') = coalesce((i.equipment_traits ->> 'life_slot'), ''))), 0))
 where i.item_id in (select jsonb_array_elements_text($J$["lt_pick_mz","lt_sickle_mz","n_mz_iron","lt_knife_mz","lt_rod_mz","k_mz_wood","lt_compass_mz","lt_lantern_mz","m_mz_stone","h_mz_herb","s_mz_herb","n_mz_herb","a_mz_robe","s_mz_stone","m_mz_wood","a_mz_shade"]$J$::jsonb));
update public.world_item_catalog i set reference_price = greatest(100,
    ceil(1.1 * (select min(t.v) from (select sum(m.reference_price * (x.value)::int * 1.0 / greatest(1, cr.output_qty)) v from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x
      join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id group by cr.recipe_id) t)))
 where i.item_id in (select jsonb_array_elements_text($J$["mz_incense","mz_ward","mz_pill","mz_elixir","mz_clear","mz_meal_herb","mz_meal_wood","mz_meal_feast"]$J$::jsonb));

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
  rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade, use_fx)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable,
  i.required_stats, i.required_job, i.required_faction, i.minimum_level, i.rarity, i.acquisition_difficulty, i.drop_rate_modifier,
  case when i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then public.world_item_hq_traits(i.equipment_traits) else i.equipment_traits end,
  i.crafting_specialization, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.item_id, 1, null
  from public.world_item_catalog i
 where i.item_id in (select jsonb_array_elements_text($J$["lt_pick_mz","lt_sickle_mz","n_mz_iron","lt_knife_mz","lt_rod_mz","k_mz_wood","lt_compass_mz","lt_lantern_mz","m_mz_stone","h_mz_herb","s_mz_herb","n_mz_herb","a_mz_robe","s_mz_stone","m_mz_wood","a_mz_shade","mz_pill","mz_elixir","mz_clear","mz_meal_herb","mz_meal_wood","mz_meal_feast"]$J$::jsonb))
on conflict (item_id) do nothing;
create or replace function public.world_meisho_start(p_id text, p_phase text, p_day date)
 returns timestamptz
 language sql
 stable
 set search_path to 'pg_catalog'
as $function$
  select (p_day::timestamp + make_interval(mins => (r -> 'phase_start' ->> p_phase)::int * 60
    + (abs(hashtext(p_id || ':' || p_day::text)::bigint) % ((r ->> 'phase_h')::int * 60 / (r ->> 'open_min')::int))::int * (r ->> 'open_min')::int)) at time zone 'Asia/Seoul'
    from (select public.world_meisho_rules() r) x
$function$;
select pg_temp.yh_share('public.world_meisho_start(text, text, date)');

create or replace function public.world_meisho_when(p_id text, p_at timestamptz default now())
 returns jsonb
 language plpgsql
 stable
 set search_path to 'pg_catalog', 'public'
as $function$
declare m public.world_meisho%rowtype; ru jsonb := public.world_meisho_rules(); terr text; d date := (p_at at time zone 'Asia/Seoul')::date;
  s timestamptz; mins int := (ru ->> 'open_min')::int; o timestamptz; nx timestamptz;
begin
  select * into m from public.world_meisho where meisho_id = p_id;
  if not found then return null; end if;
  select territory_id into terr from public.world_map_regions where region_id = m.region_id;
  for i in 0 .. (ru ->> 'look_days')::int loop
    s := public.world_meisho_start(m.meisho_id, m.phase, d + i);
    if s + make_interval(mins => mins) <= p_at then continue; end if;
    if public.world_time_phase(s) <> m.phase or public.world_weather_key(terr, s) <> m.weather then continue; end if;
    if s <= p_at then o := s; else nx := s; exit; end if;
  end loop;
  return jsonb_build_object('open', o is not null, 'open_at', o, 'close_at', o + make_interval(mins => mins),
    'next_at', nx, 'next_end', nx + make_interval(mins => mins));
end $function$;
select pg_temp.yh_share('public.world_meisho_when(text, timestamptz)');

create or replace function public.world_meisho_grade(p_level integer)
 returns integer
 language sql
 immutable
 set search_path to 'pg_catalog'
as $function$
  select coalesce((select (g ->> 1)::int from jsonb_array_elements(public.world_meisho_rules() #> '{soil,grade_lv}') g
                    where p_level >= (g ->> 0)::int order by (g ->> 0)::int desc limit 1), 1)
$function$;
select pg_temp.yh_share('public.world_meisho_grade(integer)');

create or replace function public.world_meisho_gear(p_uid uuid, p_key text)
 returns numeric
 language sql
 stable
 set search_path to 'pg_catalog'
as $function$
  select coalesce(public.world_gear_total(p_uid, p_key), 0) + coalesce(public.world_status_self(p_uid, p_key), 0)
$function$;
select pg_temp.yh_share('public.world_meisho_gear(uuid, text)');

create or replace function public.world_meisho_card(p_uid uuid, p_id text, p_skill jsonb)
 returns jsonb
 language plpgsql
 stable
 set search_path to 'pg_catalog', 'public'
as $function$
declare m public.world_meisho%rowtype; f public.world_meisho_finds%rowtype; ru jsonb := public.world_meisho_rules(); k jsonb; w jsonb;
  today date := (now() at time zone 'Asia/Seoul')::date;
begin
  select * into m from public.world_meisho where meisho_id = p_id;
  if not found then return null; end if;
  select * into f from public.world_meisho_finds where owner_id = p_uid and meisho_id = p_id;
  k := ru -> 'kinds' -> m.kind; w := public.world_meisho_when(m.meisho_id);
  return jsonb_build_object('id', m.meisho_id, 'name', m.meisho_name, 'kind', m.kind, 'kind_name', k ->> 'name', 'line', k ->> 'line',
    'items', k -> 'items', 'phase', m.phase, 'weather', m.weather, 'level', m.min_level, 'desc', m.description, 'node_id', m.node_id,
    'node_name', (select n.node_name from public.world_exploration_nodes n where n.node_id = m.node_id), 'found', f.owner_id is not null,
    'rank', coalesce((p_skill -> (k ->> 'line') ->> 'rank')::int, 1), 'rank_need', (ru #>> '{rank,base}')::int,
    'grade', public.world_meisho_grade(m.min_level),
    'dug', f.dug_at is not null and f.dug_at = (w ->> 'open_at')::timestamptz, 'soil_done', f.soil_day is not distinct from today)
    || w;
end $function$;
select pg_temp.yh_share('public.world_meisho_card(uuid, text, jsonb)');

create or replace function public.world_meisho_field(p_uid uuid, p_region text, p_node uuid)
 returns jsonb
 language plpgsql
 stable
 set search_path to 'pg_catalog', 'public'
as $function$
declare ru jsonb := public.world_meisho_rules(); sp jsonb; lv int; here jsonb := '[]'::jsonb; near boolean := false; sense jsonb; nxt jsonb; m record; w jsonb; arr jsonb := '[]'::jsonb;
begin
  if p_uid is null then return null; end if;
  select skill_progress, level into sp, lv from public.world_characters where owner_id = p_uid;
  if exists (select 1 from public.world_meisho x where x.region_id = p_region and x.active) then
    for m in select x.meisho_id from public.world_meisho x join public.world_meisho_finds f on f.meisho_id = x.meisho_id and f.owner_id = p_uid
              where x.node_id = p_node and x.active order by x.sort loop
      here := here || jsonb_build_array(public.world_meisho_card(p_uid, m.meisho_id, sp));
    end loop;
    near := exists (select 1 from public.world_meisho x where x.node_id = p_node and x.active and lv >= x.min_level
      and not exists (select 1 from public.world_meisho_finds f where f.owner_id = p_uid and f.meisho_id = x.meisho_id)
      and coalesce((public.world_meisho_when(x.meisho_id) ->> 'open')::boolean, false));
    if public.world_meisho_gear(p_uid, 'mz_sense') > 0 then
      select coalesce(jsonb_agg(jsonb_build_object('name', case when f.owner_id is not null then x.meisho_name end, 'kind_name', ru -> 'kinds' -> x.kind ->> 'name',
          'node_name', n.node_name, 'node_id', x.node_id, 'close_at', (w2.w ->> 'close_at')::timestamptz) order by x.sort), '[]'::jsonb) into sense
        from public.world_meisho x join public.world_exploration_nodes n on n.node_id = x.node_id
        left join public.world_meisho_finds f on f.owner_id = p_uid and f.meisho_id = x.meisho_id
        cross join lateral (select public.world_meisho_when(x.meisho_id) as w) w2
       where x.region_id = p_region and x.active and coalesce((w2.w ->> 'open')::boolean, false);
    end if;
  end if;
  if public.world_meisho_gear(p_uid, 'mz_next') > 0 then
    for m in select x.meisho_id, x.meisho_name, x.kind, r.region_name, r.territory_id, f.owner_id is not null as found
               from public.world_meisho x join public.world_map_regions r on r.region_id = x.region_id
               left join public.world_meisho_finds f on f.owner_id = p_uid and f.meisho_id = x.meisho_id
              where x.active loop
      if not public.world_domain_open(p_uid, m.territory_id) then continue; end if;
      w := public.world_meisho_when(m.meisho_id);
      if w is null or (not (w ->> 'open')::boolean and w ->> 'next_at' is null) then continue; end if;
      arr := arr || jsonb_build_array(jsonb_build_object('name', case when m.found then m.meisho_name end, 'kind_name', ru -> 'kinds' -> m.kind ->> 'name',
        'region_name', m.region_name, 'open', (w ->> 'open')::boolean,
        'at', case when (w ->> 'open')::boolean then w ->> 'open_at' else w ->> 'next_at' end,
        'end', case when (w ->> 'open')::boolean then w ->> 'close_at' else w ->> 'next_end' end));
    end loop;
    select coalesce(jsonb_agg(v order by (v ->> 'at')::timestamptz), '[]'::jsonb) into nxt
      from (select v from jsonb_array_elements(arr) v order by (v ->> 'at')::timestamptz limit (ru ->> 'next_n')::int) z;
  end if;
  if jsonb_array_length(here) = 0 and not near and sense is null and nxt is null then return null; end if;
  return jsonb_build_object('here', here, 'near', near, 'sense', sense, 'next', nxt);
end $function$;
select pg_temp.yh_share('public.world_meisho_field(uuid, text, uuid)');

create or replace function public.world_meisho_dig(p_meisho text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); ru jsonb := public.world_meisho_rules(); c public.world_characters%rowtype; m public.world_meisho%rowtype;
  f public.world_meisho_finds%rowtype; w jsonb; k jsonb; line text; rank int; base text; qty int; jp numeric; np numeric; ex int;
  extra jsonb := '{}'::jsonb; inv jsonb; lim int; left_st int; notes text[] := '{}'; sk text[]; it text; v int; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_rate_check('gather', uid);
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 캘 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 캘 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then
    raise exception '전투 중에는 캘 수 없습니다.'; end if;
  select * into m from public.world_meisho where meisho_id = p_meisho and active;
  if not found then raise exception '없는 명소입니다.'; end if;
  if c.current_exploration_node_id is distinct from m.node_id then
    raise exception '%에 가야 캘 수 있습니다.', (select n.node_name from public.world_exploration_nodes n where n.node_id = m.node_id); end if;
  select * into f from public.world_meisho_finds where owner_id = uid and meisho_id = m.meisho_id for update;
  if not found then raise exception '먼저 탐색으로 명소를 찾으세요.'; end if;
  if c.level < m.min_level then raise exception '레벨 %부터 캘 수 있습니다.', m.min_level; end if;
  w := public.world_meisho_when(m.meisho_id);
  if not coalesce((w ->> 'open')::boolean, false) then
    raise exception '%은(는) 지금 닫혀 있습니다. %·% 때 한 시간만 열립니다.', m.meisho_name,
      (select env_name from public.world_environment_catalog where env_key = m.phase), (select env_name from public.world_environment_catalog where env_key = m.weather)
      using hint = 'mz_closed';
  end if;
  if f.dug_at is not null and f.dug_at = (w ->> 'open_at')::timestamptz then
    raise exception '이번에 열린 동안은 이미 캤습니다. 다음에 열릴 때 다시 오세요.' using hint = 'mz_done'; end if;
  k := ru -> 'kinds' -> m.kind; line := k ->> 'line';
  rank := coalesce((c.skill_progress -> line ->> 'rank')::int, 1);
  if rank < (ru #>> '{rank,base}')::int then
    raise exception '% 기술 %단계부터 명소를 캘 수 있습니다(지금 %단계). 흙 살피기는 단계와 무관합니다.', public.world_line_name(line), ru #>> '{rank,base}', rank;
  end if;
  base := k -> 'items' ->> 0;
  qty := (ru #>> '{qty,base}')::int + case when rank >= (ru #>> '{rank,j}')::int then (ru #>> '{qty,r40}')::int else 0 end
    + case when rank >= (ru #>> '{rank,n}')::int then (ru #>> '{qty,r50}')::int else 0 end;
  ex := least((ru ->> 'extra_cap')::int, floor(public.world_meisho_gear(uid, 'mz_extra'))::int);
  if ex > 0 then qty := qty + ex; notes := notes || format('장비 덤 +%s', ex); end if;
  if rank >= (ru #>> '{rank,j}')::int then
    jp := least((ru #>> '{j_pct,cap}')::numeric, (ru #>> '{j_pct,base}')::numeric + (rank - (ru #>> '{rank,j}')::int) * (ru #>> '{j_pct,per_rank}')::numeric
      + public.world_meisho_gear(uid, 'mz_j_' || m.kind) + public.world_meisho_gear(uid, 'mz_j_all'));
    if random() * 100 < jp then extra := extra || jsonb_build_object(k -> 'items' ->> 1, 1); end if;
  end if;
  if rank >= (ru #>> '{rank,n}')::int then
    np := least((ru #>> '{n_pct,cap}')::numeric, (ru #>> '{n_pct,base}')::numeric + public.world_meisho_gear(uid, 'mz_n_pct'));
    if random() * 100 < np then extra := extra || jsonb_build_object(k -> 'items' ->> 2, 1); end if;
  end if;
  lim := public.world_bag_limit(uid);
  inv := public.world_inv_add(coalesce(c.inventory, '{}'::jsonb), base, qty);
  for it, v in select key, value::text::int from jsonb_each(extra) loop inv := public.world_inv_add(inv, it, v); end loop;
  if public.world_bag_count(inv) > lim then
    raise exception '가방에 자리가 없습니다. 칸을 비운 뒤 다시 캐세요. 명소가 닫히기 전이면 다시 캘 수 있습니다.' using hint = 'bag'; end if;
  left_st := public.world_stamina_change(uid, -(ru ->> 'stamina')::int);
  select * into c from public.world_characters where owner_id = uid;
  inv := public.world_inv_add(coalesce(c.inventory, '{}'::jsonb), base, qty);
  for it, v in select key, value::text::int from jsonb_each(extra) loop inv := public.world_inv_add(inv, it, v); end loop;
  sk := public.world_skill_procs(uid);
  if not ((line = 'foraging' and 'foraging_x30' = any (sk)) or (line = 'mining' and 'mining_x30' = any (sk))) then perform public.world_durability_wear(uid, 'tool', 1); end if;
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  update public.world_meisho_finds set dug_at = (w ->> 'open_at')::timestamptz, dig_count = dig_count + 1 where owner_id = uid and meisho_id = m.meisho_id;
  select item_name into nm from public.world_item_catalog where item_id = base;
  for it in select key from jsonb_each(extra) loop notes := notes || (select item_name from public.world_item_catalog where item_id = it); end loop;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'gather', m.meisho_name || '에서 ' || nm || ' ×' || qty || ' 캠',
    jsonb_build_object('meisho_id', m.meisho_id, 'meisho', m.meisho_name, 'category', k ->> 'cat', 'item_id', base, 'qty', qty, 'node_id', m.node_id,
      'region_id', m.region_id, 'line', line, 'node', case when line = 'mining' then 'ore' else 'herb' end, 'extra', extra, 'free_day', false, 'profession_match', false));
  return jsonb_build_object('ok', true, 'content', m.meisho_name || '에서 ' || nm || ' ×' || qty || '을(를) 캤습니다.'
      || case when cardinality(notes) > 0 then ' ' || array_to_string(notes, ' · ') || '.' else '' end,
    'item_id', base, 'qty', qty, 'extra', extra, 'line', line, 'stamina', left_st, 'meisho_id', m.meisho_id, 'close_at', w ->> 'close_at');
end $function$;
revoke all on function public.world_meisho_dig(text) from public, anon;
grant execute on function public.world_meisho_dig(text) to authenticated, service_role;
select pg_temp.yh_own('public.world_meisho_dig(text)', 'fn_owner_field');

create or replace function public.world_meisho_soil(p_meisho text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); ru jsonb := public.world_meisho_rules(); c public.world_characters%rowtype; m public.world_meisho%rowtype;
  f public.world_meisho_finds%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; g int; pct numeric; rolled boolean := false; got boolean := false; txt text;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_travel_guard('흙 살피기');
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 흙을 살필 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then
    raise exception '전투 중에는 흙을 살필 수 없습니다.'; end if;
  select * into m from public.world_meisho where meisho_id = p_meisho and active;
  if not found then raise exception '없는 명소입니다.'; end if;
  if c.current_exploration_node_id is distinct from m.node_id then
    raise exception '%에 가야 흙을 살필 수 있습니다.', (select n.node_name from public.world_exploration_nodes n where n.node_id = m.node_id); end if;
  select * into f from public.world_meisho_finds where owner_id = uid and meisho_id = m.meisho_id for update;
  if not found then raise exception '먼저 탐색으로 명소를 찾으세요.'; end if;
  if c.level < m.min_level then raise exception '레벨 %부터 흙을 살필 수 있습니다.', m.min_level; end if;
  if f.soil_day is not distinct from today then
    raise exception '이 명소의 흙은 오늘 이미 살폈습니다. 한국 시각 자정이 지나면 다시 살필 수 있습니다.' using hint = 'mz_soil_done'; end if;
  g := public.world_meisho_grade(m.min_level);
  pct := least((ru #>> '{soil,cap}')::numeric, (ru -> 'soil' -> 'pct' ->> g::text)::numeric * greatest(0, 1 + public.world_meisho_gear(uid, 'mz_soil_pct') / 100.0));
  rolled := random() * 100 < pct;
  if rolled then got := coalesce(public.world_bijang_grant(uid, g), false); end if;
  update public.world_meisho_finds set soil_day = today, soil_count = soil_count + 1 where owner_id = uid and meisho_id = m.meisho_id;
  txt := case when got then m.meisho_name || '의 흙을 살피다 묻혀 있던 비장도를 찾았습니다.'
    when rolled then m.meisho_name || '의 흙 속에 비장도의 흔적이 있었지만, 같은 등급의 비장도를 이미 지니고 있어 덮어 두었습니다.'
    else m.meisho_name || '의 흙을 살폈지만 묻힌 것은 없었습니다.' end;
  return jsonb_build_object('ok', true, 'content', txt, 'got', got, 'had', rolled and not got, 'grade', g, 'meisho_id', m.meisho_id);
end $function$;
revoke all on function public.world_meisho_soil(text) from public, anon;
grant execute on function public.world_meisho_soil(text) to authenticated, service_role;
select pg_temp.yh_own('public.world_meisho_soil(text)', 'fn_owner_field');

select pg_temp.yh_fix('world_field_search', array[
$q$d_ixp int := 0; d_mn int := 0; d_sp int := 0; e_add int := 0;$q$,
$q$d_ixp int := 0; d_mn int := 0; d_sp int := 0; e_add int := 0; mz public.world_meisho%rowtype; w_mz float8 := 0;$q$,

$q$  IF spot.spot_id IS NOT NULL THEN w_spot := 18; END IF;$q$,
$q$  IF spot.spot_id IS NOT NULL THEN w_spot := 18; END IF;
  SELECT * INTO mz FROM public.world_meisho x WHERE x.node_id = n.node_id AND x.active AND c.level >= x.min_level
    AND NOT EXISTS (SELECT 1 FROM public.world_meisho_finds f WHERE f.owner_id = uid AND f.meisho_id = x.meisho_id)
    AND coalesce((public.world_meisho_when(x.meisho_id) ->> 'open')::boolean, false) ORDER BY x.sort LIMIT 1;
  IF mz.meisho_id IS NOT NULL THEN w_mz := (public.world_meisho_rules() ->> 'find_w')::numeric * (1 + public.world_explore_find_pct(uid) / 100.0); END IF;$q$,

$q$  outcome := CASE
    WHEN roll < w_path THEN 'path'$q$,
$q$  outcome := CASE
    WHEN w_mz > 0 AND random() * (tot + w_mz) < w_mz THEN 'meisho'
    WHEN roll < w_path THEN 'path'$q$,

$q$  IF outcome = 'path' THEN
    INSERT INTO public.world_exploration_discoveries$q$,
$q$  IF outcome = 'meisho' THEN
    INSERT INTO public.world_meisho_finds(owner_id, meisho_id) VALUES (uid, mz.meisho_id) ON CONFLICT DO NOTHING;
    txt := '이름난 자리를 찾았다 — 명소 「' || mz.meisho_name || '」. ' || mz.description;
    xp := (public.world_meisho_rules() ->> 'find_xp')::int; payload := jsonb_build_object('meisho_id', mz.meisho_id, 'meisho', mz.meisho_name, 'kind', mz.kind);
  ELSIF outcome = 'path' THEN
    INSERT INTO public.world_exploration_discoveries$q$]);

select pg_temp.yh_fix('world_field_snapshot', array[
$q$    'hidden_spots', (SELECT count(*) FROM public.world_gathering_spots s WHERE s.node_id = n.node_id AND s.active$q$,
$q$    'meisho', public.world_meisho_field(uid, r.region_id, n.node_id),
    'hidden_spots', (SELECT count(*) FROM public.world_gathering_spots s WHERE s.node_id = n.node_id AND s.active$q$]);

select pg_temp.yh_fix('world_item_sources_all', array[
$q$public.world_source_region_ok('fish', r.is_safe_zone, r.active))
  select jsonb_build_object($q$,
$q$public.world_source_region_ok('fish', r.is_safe_zone, r.active)),
       z as (select distinct r.region_name, r.min_level from public.world_meisho x join public.world_map_regions r using (region_id)
               where x.active and public.world_item_base(p_item) in (select jsonb_array_elements_text(public.world_meisho_rules() -> 'kinds' -> x.kind -> 'items')))
  select jsonb_build_object(
    'meisho', (select coalesce(jsonb_agg(region_name order by min_level, region_name), '[]') from (select * from z order by min_level, region_name) x), 'meisho_n', (select count(*) from z),$q$]);

select pg_temp.yh_fix('world_item_sources', array[
$q$    'fish',     (select coalesce(jsonb_agg(v order by o), '[]') from jsonb_array_elements(s -> 'fish') with ordinality a(v, o) where o <= 6))$q$,
$q$    'fish',     (select coalesce(jsonb_agg(v order by o), '[]') from jsonb_array_elements(s -> 'fish') with ordinality a(v, o) where o <= 6),
    'meisho',   (select coalesce(jsonb_agg(v order by o), '[]') from jsonb_array_elements(s -> 'meisho') with ordinality a(v, o) where o <= 6))$q$]);

select pg_temp.yh_fix('world_gather_codex_snapshot', array[
$q$  return jsonb_build_object(
    'items', (with it as ($q$,
$q$  return jsonb_build_object(
    'meisho', (select coalesce(jsonb_agg(case when f.owner_id is null
        then jsonb_build_object('found', false, 'kind_name', public.world_meisho_rules() -> 'kinds' -> x.kind ->> 'name', 'region', r.region_name, 'level', x.min_level)
        else jsonb_build_object('found', true, 'id', x.meisho_id, 'name', x.meisho_name, 'kind_name', public.world_meisho_rules() -> 'kinds' -> x.kind ->> 'name', 'region', r.region_name,
          'level', x.min_level, 'phase', x.phase, 'weather', x.weather, 'digs', f.dig_count) end order by x.min_level, x.sort), '[]'::jsonb)
      from public.world_meisho x join public.world_map_regions r on r.region_id = x.region_id
      left join public.world_meisho_finds f on f.owner_id = uid and f.meisho_id = x.meisho_id where x.active),
    'meisho_items', (select coalesce(jsonb_agg(jsonb_build_object('id', i.v, 'name', ic.item_name, 'got', exists (select 1 from public.world_events e
        where e.actor_id = uid and e.event_type = 'gather' and e.payload ? 'meisho_id' and (e.payload ->> 'item_id' = i.v or coalesce(e.payload -> 'extra', '{}'::jsonb) ? i.v))) order by kk.k, i.o), '[]'::jsonb)
      from jsonb_each(public.world_meisho_rules() -> 'kinds') kk(k, kv), jsonb_array_elements_text(kk.kv -> 'items') with ordinality i(v, o)
      join public.world_item_catalog ic on ic.item_id = i.v),
    'items', (with it as ($q$]);

select pg_temp.yh_fix('world_character_purge', array[
$q$  delete from public.world_fish_log where owner_id = p_uid;$q$,
$q$  delete from public.world_fish_log where owner_id = p_uid;
  delete from public.world_meisho_finds where owner_id = p_uid;$q$]);

update public.world_app_meta set value = '20261117020000' where key = 'db_version';
