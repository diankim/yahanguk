-- 7.0.0: 만렙 40 · 귀허도(섬 5곳·반요촌) · 6단계 장비 · 외전 「요인록」 5장 · 최종 보스 「귀허의 주인」(라운드 전투) · 편의
-- 생성기: supabase/gen70/gen.py (손으로 고치지 말고 생성기를 고친 뒤 다시 만든다)
lock table public.world_characters in access exclusive mode;

-- ─────────────────────────────────────────────────────────────
-- A. 만렙 40 · 쌓아 둘 능력치 포인트 117 · 기술 30단계부터 가파르게 · 깊이별 레벨 되살림
-- ─────────────────────────────────────────────────────────────

-- 함수 본문 고치기 도우미: 고칠 자리(old)가 정확히 n번 있어야 바꾼다. 이미 바뀌어 있으면 건너뛴다.
create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

select pg_temp.yh_patch('public.world_event_char_apply()', 'nl >= 30', 'nl >= 40', 2);
select pg_temp.yh_patch('public.world_event_char_apply()', 'nl < 30', 'nl < 40', 2);
select pg_temp.yh_patch('public.world_event_char_apply()', 'level = least(30, nl)', 'level = least(40, nl)');
select pg_temp.yh_patch('public.world_event_char_apply()', 'least(87, stat_points + gained * 3)', 'least(117, stat_points + gained * 3)');
-- 탐색 한 번 추적 경험 8 → 5(기술 50단계를 늦춤)
select pg_temp.yh_patch('public.world_event_char_apply()', 'when ''craft'' then 12 when ''explore'' then 8 when', 'when ''craft'' then 12 when ''explore'' then 5 when');

select pg_temp.yh_patch('public.world_grant_xp(uuid,integer)', 'lv < 30', 'lv < 40');
select pg_temp.yh_patch('public.world_grant_xp(uuid,integer)', 'lv >= 30', 'lv >= 40');
select pg_temp.yh_patch('public.world_grant_xp(uuid,integer)', 'least(87,', 'least(117,');

select pg_temp.yh_patch('public.world_claim_idle_activity()', 'c.level>=30', 'c.level>=40');
select pg_temp.yh_patch('public.world_claim_idle_activity()', 'v_new_level<30', 'v_new_level<40', 2);
select pg_temp.yh_patch('public.world_claim_idle_activity()', 'v_new_level>=30', 'v_new_level>=40');
select pg_temp.yh_patch('public.world_claim_idle_activity()', 'least(87,', 'least(117,');
select pg_temp.yh_patch('public.world_claim_idle_activity()', '''level_cap'',30', '''level_cap'',40');

select pg_temp.yh_patch('public.world_expedition_gear(integer)', 'least(30, p_level)', 'least(40, p_level)');

-- 기술 단계: r → r+1에 80+8r, 30단계부터 6×(r−29)²를 더한다.
-- 누적 경험(단계 R에 닿는 데) = 4R²+76R−80 + n(n+1)(2n+1) (n = R−30, 30 아래는 0) — 30단계 5,800 · 40단계 11,670 · 50단계 30,940
create or replace function public.world_skill_line_xp(p_rank integer) returns integer
language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select 4 * greatest(1, p_rank) * greatest(1, p_rank) + 76 * greatest(1, p_rank) - 80
       + greatest(0, p_rank - 30) * (greatest(0, p_rank - 30) + 1) * (2 * greatest(0, p_rank - 30) + 1)
$$;
create or replace function public.world_skill_line_rank(p_xp integer) returns integer
language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select case when coalesce(p_xp, 0) < 5800
              then least(30, greatest(1, floor((-76 + sqrt(5776 + 16 * (80 + greatest(0, coalesce(p_xp, 0))))::numeric) / 8)::int))
              else (select max(r) from generate_series(30, 50) r where public.world_skill_line_xp(r) <= p_xp) end
$$;

-- 지금 단계를 적어 두고 모두 다시 매긴 뒤 내려간 사람에게 알린다(경험은 그대로)
create temp table yh_old_ranks on commit drop as
  select c.owner_id, s.key, coalesce((s.value ->> 'rank')::int, 1) old_rank
    from public.world_characters c, jsonb_each(coalesce(c.skill_progress, '{}'::jsonb)) s where jsonb_typeof(s.value) = 'object';
select set_config('yh.rank_sync', 'all', true);
update public.world_characters set skill_progress = skill_progress where skill_progress is not null and skill_progress <> '{}'::jsonb;
select set_config('yh.rank_sync', '', true);
insert into public.world_notifications(user_id, kind, title, content, payload)
select o.owner_id, 'skill_rerank', '기술 단계가 다시 매겨졌습니다',
       '7.0에서 기술 30단계부터 필요한 경험이 늘어 단계를 다시 매겼습니다(쌓은 경험은 그대로입니다): '
       || string_agg(coalesce(nullif(k.n, ''), o.key) || ' ' || o.old_rank || '→' || n.new_rank, ' · ' order by o.key)
       || '. 다시 오르면 그 단계 기술도 곧바로 살아납니다(고른 택일 기술은 그대로).',
       jsonb_build_object('changes', jsonb_object_agg(o.key, jsonb_build_array(o.old_rank, n.new_rank)))
  from yh_old_ranks o
  join lateral (select coalesce((c.skill_progress -> o.key ->> 'rank')::int, 1) new_rank from public.world_characters c where c.owner_id = o.owner_id) n on true
  left join lateral (select case o.key when 'melee' then '근접' when 'ranged' then '원거리' when 'sealing' then '봉인술' when 'analysis' then '분석' when 'guarding' then '막기'
       when 'first_aid' then '응급 처치' when 'foraging' then '일반 채집' when 'herbalism' then '약초 채집' when 'mining' then '광맥 채집' when 'spirit_gathering' then '영기 채집'
       when 'smithing' then '단조' when 'alchemy' then '연금' when 'wardcraft' then '결계 각인' when 'tracking' then '추적' else '' end n) k on true
 where n.new_rank < o.old_rank
 group by o.owner_id;

-- 깊이별 레벨 되살림(4.0.4에서 최고 레벨 30으로 묶었던 구중 봉연·무극 관성대): 지역 레벨 + 깊이마다 2
update public.world_exploration_nodes n set min_level = least(40, r.min_level + greatest(0, n.hierarchy_level - 2) * 2)
  from public.world_map_regions r where r.region_id = n.region_id and r.region_id in ('sealed_abyss', 'star_observatory');
update public.world_gathering_spots s set min_level = n.min_level
  from public.world_exploration_nodes n where n.node_id = s.node_id and n.region_id in ('sealed_abyss', 'star_observatory') and s.spot_name not like '어귀의 %';
update public.world_expedition_grounds g set min_level = least(40, r.min_level + (g.depth - 1) * 2)
  from public.world_map_regions r where r.region_id = g.region_id and r.region_id in ('sealed_abyss', 'star_observatory');


-- ─────────────────────────────────────────────────────────────
-- B. 귀허도: 지역·답사 길·채집터·요괴·원정지·조사 지점·재료·6단계 장비·반요촌 상점
-- ─────────────────────────────────────────────────────────────
alter table public.world_shop_catalog add column if not exists daily_cap int;

insert into public.world_map_regions(region_id, territory_id, territory_name, region_name, region_type, danger_level, min_level, description, travel_from, gather_nodes, faction_control, is_starting_area, active, world_x, world_y, elevation, terrain_cost, rest_spot_type, rest_spot_name, rest_quality, rest_fee, rest_risk, is_safe_zone, shop_id, shop_name, has_stable, contested)
select x.region_id, x.territory_id, x.territory_name, x.region_name, x.region_type, x.danger_level, x.min_level, x.description, array(select jsonb_array_elements_text(x.travel_from)), '{}'::text[], x.faction_control, false, true, x.world_x, x.world_y, x.elevation, x.terrain_cost, x.rest_spot_type, x.rest_spot_name, x.rest_quality, x.rest_fee, x.rest_risk, x.is_safe_zone, x.shop_id, x.shop_name, false, false from jsonb_to_recordset($J$[{"region_id":"banyo_village","territory_id":"gwiheo","territory_name":"귀허도","region_name":"반요촌","region_type":"village","danger_level":8,"min_level":30,"description":"요기에 물든 사람들이 비늘 지붕 아래 모여 사는 마을. 문간마다 사람이던 시절의 이름이 붙어 있다.","travel_from":["sealed_abyss","ash_reeds","inverted_shrine"],"faction_control":"무주 금역","world_x":520,"world_y":860,"elevation":0,"terrain_cost":0.8,"rest_spot_type":"inn","rest_spot_name":"반요촌 객방","rest_quality":2,"rest_fee":150,"rest_risk":0,"is_safe_zone":true,"shop_id":"banyo_shop","shop_name":"반요촌 잡화","theme":"city"},{"region_id":"ash_reeds","territory_id":"gwiheo","territory_name":"귀허도","region_name":"잿빛 갈대숲","region_type":"swamp","danger_level":10,"min_level":30,"description":"재가 내려앉은 갈대가 끝없이 이어진 물가. 갈대 사이로 누군가 옛 이름을 부르는 소리가 난다.","travel_from":["banyo_village","inverted_shrine","moonless_market"],"faction_control":"무주 금역","world_x":430,"world_y":905,"elevation":-1,"terrain_cost":1,"rest_spot_type":"field_camp","rest_spot_name":"임시 야영지","rest_quality":1,"rest_fee":2,"rest_risk":30,"is_safe_zone":false,"shop_id":null,"shop_name":null,"theme":"water"},{"region_id":"inverted_shrine","territory_id":"gwiheo","territory_name":"귀허도","region_name":"거꾸로 선 사당","region_type":"sealed_shrine","danger_level":10,"min_level":33,"description":"지붕이 땅에 박히고 주춧돌이 하늘을 향한 사당. 이곳의 향은 아래로 탄다.","travel_from":["banyo_village","ash_reeds","moonless_market"],"faction_control":"무주 금역","world_x":395,"world_y":1005,"elevation":1,"terrain_cost":1,"rest_spot_type":"field_camp","rest_spot_name":"임시 야영지","rest_quality":1,"rest_fee":2,"rest_risk":30,"is_safe_zone":false,"shop_id":null,"shop_name":null,"theme":"shrine"},{"region_id":"moonless_market","territory_id":"gwiheo","territory_name":"귀허도","region_name":"달 없는 저잣거리","region_type":"ruins","danger_level":10,"min_level":36,"description":"달이 뜨지 않는 섬의 장터. 값을 치르는 것은 전이 아니라 기억이다.","travel_from":["ash_reeds","inverted_shrine","gwiheo_core"],"faction_control":"무주 금역","world_x":515,"world_y":995,"elevation":0,"terrain_cost":1,"rest_spot_type":"field_camp","rest_spot_name":"임시 야영지","rest_quality":1,"rest_fee":2,"rest_risk":30,"is_safe_zone":false,"shop_id":null,"shop_name":null,"theme":"city"},{"region_id":"gwiheo_core","territory_id":"gwiheo","territory_name":"귀허도","region_name":"귀허","region_type":"abyss","danger_level":10,"min_level":38,"description":"모든 물이 돌아가 사라지는 바다의 끝. 소용돌이 한가운데 누군가의 빈 자리가 있다.","travel_from":["moonless_market"],"faction_control":"무주 금역","world_x":615,"world_y":1060,"elevation":-4,"terrain_cost":1,"rest_spot_type":"field_camp","rest_spot_name":"임시 야영지","rest_quality":1,"rest_fee":2,"rest_risk":30,"is_safe_zone":false,"shop_id":null,"shop_name":null,"theme":"deep"}]$J$::jsonb) as x(region_id text, territory_id text, territory_name text, region_name text, region_type text, danger_level int, min_level int, description text, travel_from jsonb, gather_nodes jsonb, faction_control text, is_starting_area boolean, active boolean, world_x int, world_y int, elevation int, terrain_cost numeric, rest_spot_type text, rest_spot_name text, rest_quality int, rest_fee int, rest_risk int, is_safe_zone boolean, shop_id text, shop_name text, has_stable boolean, contested boolean)
on conflict (region_id) do update set travel_from = excluded.travel_from, description = excluded.description, min_level = excluded.min_level, danger_level = excluded.danger_level, world_x = excluded.world_x, world_y = excluded.world_y, rest_fee = excluded.rest_fee, shop_id = excluded.shop_id, shop_name = excluded.shop_name, active = excluded.active;
insert into public.world_region_theme(region_id, theme)
select x.region_id, x.theme from jsonb_to_recordset($J$[{"region_id":"banyo_village","theme":"city"},{"region_id":"ash_reeds","theme":"water"},{"region_id":"inverted_shrine","theme":"shrine"},{"region_id":"moonless_market","theme":"city"},{"region_id":"gwiheo_core","theme":"deep"}]$J$::jsonb) as x(region_id text, theme text)
on conflict (region_id) do update set theme = excluded.theme;
update public.world_map_regions set travel_from = array_append(travel_from, 'banyo_village') where region_id = 'sealed_abyss' and not ('banyo_village' = any (travel_from));
insert into public.world_region_profiles(region_id, biome_key, biome_name, faction_style, signature_clue, signature_event, signature_items, survival_hazard, visual_identity, signature_resources, investigation_reward)
select x.region_id, x.biome_key, x.biome_name, x.faction_style, x.signature_clue, x.signature_event, array(select jsonb_array_elements_text(x.signature_items)), x.survival_hazard, x.visual_identity, array(select jsonb_array_elements_text(x.signature_resources)), x.investigation_reward from jsonb_to_recordset($J$[{"region_id":"banyo_village","biome_key":"city","biome_name":"도성·마을","faction_style":"반요촌 사람들·섬의 안내인","signature_clue":"반요촌의 문패: 사람이던 시절의 이름과 지금 불리는 이름이 나란히 적혀 있다.","signature_event":"반요촌 고유 사건: 촌장 묵호가 잊어 가는 이름을 되찾아 주면 섬의 옛 기록이 열린다.","signature_items":["banyo_scale"],"survival_hazard":"비싼 물자·요기","visual_identity":"비늘 지붕, 이름 두 개 걸린 문패, 꺼지지 않는 화로","signature_resources":["herb","medicine_base","tonic","travel_ration"],"investigation_reward":"섬의 옛 기록과 이송 명부의 흔적"},{"region_id":"ash_reeds","biome_key":"water","biome_name":"물가·늪지","faction_style":"갈대숲 사공·요화된 이들","signature_clue":"잿빛 갈대숲의 말뚝: 물에 잠긴 이름을 다 읽으면 건너편이 보인다.","signature_event":"잿빛 갈대숲 고유 사건: 사공이 부르는 이름에 답하면 배가 움직인다.","signature_items":["reed_silk"],"survival_hazard":"침식·익사·환청","visual_identity":"재 덮인 갈대, 물안개, 이름 새긴 말뚝","signature_resources":["drowned_scale","herb","medicine_base","moon_moss","reed_silk","resin","river_reed","tonic","travel_ration","wood"],"investigation_reward":"섬의 옛 기록과 이송 명부의 흔적"},{"region_id":"inverted_shrine","biome_key":"shrine","biome_name":"사당·성역","faction_style":"거꾸로 기도하는 승려들","signature_clue":"거꾸로 선 사당의 이름판: 거꾸로 읽어야 바른 이름이 된다.","signature_event":"거꾸로 선 사당 고유 사건: 아래로 타는 향을 바로 세우면 사당의 기도가 뒤집힌다.","signature_items":["inverted_incense"],"survival_hazard":"침식·결계·환영","visual_identity":"땅에 박힌 지붕, 아래로 타는 향, 하늘을 향한 주춧돌","signature_resources":["ghost_ash","herb","inkstone","inverted_incense","resin","seal_paper","spirit_dust","talisman_thread","tonic","travel_ration","ward_fragment","wood"],"investigation_reward":"섬의 옛 기록과 이송 명부의 흔적"},{"region_id":"moonless_market","biome_key":"city","biome_name":"폐허 도성","faction_style":"기억 상인·얼굴 없는 손님","signature_clue":"달 없는 저잣거리의 장부: 팔린 기억의 주인 이름이 지워진 채 남아 있다.","signature_event":"달 없는 저잣거리 고유 사건: 지운 장부를 맞추면 섬으로 보낸 이들의 명단이 드러난다.","signature_items":["moonless_silk","oblivion_crystal"],"survival_hazard":"기억 상실·매복·독","visual_identity":"꺼진 청사초롱, 빈 좌판, 기울어진 저울","signature_resources":["ghost_ash","herb","inkstone","moonless_silk","oblivion_crystal","ore","raw_iron","seal_paper","spirit_dust","tonic","travel_ration"],"investigation_reward":"섬의 옛 기록과 이송 명부의 흔적"},{"region_id":"gwiheo_core","biome_key":"deep","biome_name":"심연·바다 끝","faction_style":"귀허의 주인과 문지기","signature_clue":"귀허의 물빛: 돌아오지 못한 이들의 이름이 물결에 비친다.","signature_event":"귀허 고유 사건: 빈 왕좌 앞에서 마지막 이름을 부르면 주인이 깨어난다.","signature_items":["gwiheo_iron"],"survival_hazard":"침식·소용돌이·사슬","visual_identity":"끝없는 소용돌이, 흰 사슬, 빈 왕좌","signature_resources":["drowned_scale","ghost_ash","gwiheo_iron","ore","raw_iron","river_reed","seal_paper","spirit_core","spirit_dust","ward_fragment"],"investigation_reward":"섬의 옛 기록과 이송 명부의 흔적"}]$J$::jsonb) as x(region_id text, biome_key text, biome_name text, faction_style text, signature_clue text, signature_event text, signature_items jsonb, survival_hazard text, visual_identity text, signature_resources jsonb, investigation_reward text)
on conflict (region_id) do update set biome_name = excluded.biome_name, faction_style = excluded.faction_style, signature_clue = excluded.signature_clue, signature_event = excluded.signature_event, signature_items = excluded.signature_items, survival_hazard = excluded.survival_hazard, visual_identity = excluded.visual_identity, signature_resources = excluded.signature_resources;
insert into public.world_region_lore(region_id, lines)
select x.region_id, x.lines from jsonb_to_recordset($J$[{"region_id":"banyo_village","lines":[{"s":null,"t":"반요촌. 구중 봉연 아래로 흘러 나간 물길 끝에 있는 마을입니다. 사람들은 비늘 돋은 손으로 손님에게 차를 따릅니다."},{"s":null,"t":"문간마다 이름이 두 개씩 걸려 있습니다. 하나는 사람이던 시절의 이름, 하나는 여기서 불리는 이름입니다."}]},{"region_id":"ash_reeds","lines":[{"s":null,"t":"잿빛 갈대숲. 바람이 불면 갈대가 사람 이름을 하나씩 부릅니다. 대답하지 않는 것이 이곳의 예의입니다."},{"s":null,"t":"물가에 박힌 말뚝마다 이름이 새겨져 있습니다. 대부분은 물에 잠겨 반만 읽힙니다."}]},{"region_id":"inverted_shrine","lines":[{"s":null,"t":"거꾸로 선 사당. 지붕은 땅에 박히고 주춧돌이 하늘을 받치고 있습니다. 향은 아래로 타고, 종은 거꾸로 웁니다."},{"s":null,"t":"여기서 드리는 기도는 모두 반대로 이루어진다고 합니다. 그래서 이곳 승려들은 잊히기를 빕니다."}]},{"region_id":"moonless_market","lines":[{"s":null,"t":"달 없는 저잣거리. 섬의 달은 오래전에 팔렸습니다. 장터에서는 지금도 무언가를 사고팝니다. 값은 기억으로 치릅니다."},{"s":null,"t":"좌판 하나에 야행국의 낡은 인장이 찍힌 장부가 놓여 있습니다. 누군가 서둘러 이름을 지운 흔적이 있습니다."}]},{"region_id":"gwiheo_core","lines":[{"s":null,"t":"귀허. 세상의 모든 물이 돌아와 사라지는 곳입니다. 소용돌이 한가운데에 빈 왕좌가 하나 놓여 있습니다."},{"s":null,"t":"여기까지 온 사람은 다시 돌아가지 않았다고 반요촌 사람들은 말합니다. 그래서 반요촌에는 배웅하는 노래만 있습니다."}]}]$J$::jsonb) as x(region_id text, lines jsonb)
on conflict (region_id) do update set lines = excluded.lines;
insert into public.world_exploration_nodes(node_id, region_id, parent_node_id, hierarchy_level, node_name, description, min_level, sort_order)
select md5(x.node_id)::uuid, x.region_id, md5(x.parent_node_id)::uuid, x.hierarchy_level, x.node_name, ($J${"1":"지역에 막 들어선 곳입니다. 탐색하면 안쪽으로 이어지는 길을 찾을 수 있습니다.","2":"지역의 바깥 권역입니다. 탐색을 이어가면 더 안쪽 구역을 찾을 수 있습니다.","3":"권역 안쪽의 구역입니다. 요괴의 흔적이 짙어지고 채집터가 드러납니다.","4":"깊숙한 곳입니다. 쓸 만한 채집터가 숨어 있지만 위험도 커집니다.","5":"가장 깊은 지점입니다. 희귀한 자원과 강한 요괴가 함께 있습니다."}$J$::jsonb ->> x.hierarchy_level::text), x.min_level, x.sort_order from jsonb_to_recordset($J$[{"node_id":"g70/node/banyo_village/0/0","region_id":"banyo_village","parent_node_id":null,"hierarchy_level":1,"node_name":"반요촌 어귀","min_level":30,"sort_order":0},{"node_id":"g70/node/ash_reeds/0/0","region_id":"ash_reeds","parent_node_id":null,"hierarchy_level":1,"node_name":"갈대숲 나루터","min_level":30,"sort_order":0},{"node_id":"g70/node/inverted_shrine/0/0","region_id":"inverted_shrine","parent_node_id":null,"hierarchy_level":1,"node_name":"뒤집힌 일주문","min_level":33,"sort_order":0},{"node_id":"g70/node/moonless_market/0/0","region_id":"moonless_market","parent_node_id":null,"hierarchy_level":1,"node_name":"꺼진 등롱 거리","min_level":36,"sort_order":0},{"node_id":"g70/node/gwiheo_core/0/0","region_id":"gwiheo_core","parent_node_id":null,"hierarchy_level":1,"node_name":"귀허의 물가","min_level":38,"sort_order":0},{"node_id":"g70/node/banyo_village/1/0","region_id":"banyo_village","parent_node_id":"g70/node/banyo_village/0/0","hierarchy_level":2,"node_name":"묵호의 마당","min_level":30,"sort_order":0},{"node_id":"g70/node/banyo_village/1/1","region_id":"banyo_village","parent_node_id":"g70/node/banyo_village/0/0","hierarchy_level":2,"node_name":"비늘 지붕 골목","min_level":30,"sort_order":1},{"node_id":"g70/node/ash_reeds/1/0","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/0/0","hierarchy_level":2,"node_name":"잿빛 물길","min_level":30,"sort_order":0},{"node_id":"g70/node/ash_reeds/1/1","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/0/0","hierarchy_level":2,"node_name":"쓰러진 갈대밭","min_level":30,"sort_order":1},{"node_id":"g70/node/inverted_shrine/1/0","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/0/0","hierarchy_level":2,"node_name":"거꾸로 걸린 종루","min_level":33,"sort_order":0},{"node_id":"g70/node/inverted_shrine/1/1","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/0/0","hierarchy_level":2,"node_name":"천장 밟는 회랑","min_level":33,"sort_order":1},{"node_id":"g70/node/moonless_market/1/0","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/0/0","hierarchy_level":2,"node_name":"빈 좌판 골목","min_level":36,"sort_order":0},{"node_id":"g70/node/moonless_market/1/1","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/0/0","hierarchy_level":2,"node_name":"이름 파는 객주","min_level":36,"sort_order":1},{"node_id":"g70/node/gwiheo_core/1/0","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/0/0","hierarchy_level":2,"node_name":"가라앉는 돌길","min_level":38,"sort_order":0},{"node_id":"g70/node/gwiheo_core/1/1","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/0/0","hierarchy_level":2,"node_name":"끝없는 소용돌이 가장자리","min_level":38,"sort_order":1},{"node_id":"g70/node/ash_reeds/2/0","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/1/0","hierarchy_level":3,"node_name":"젖은 발자국 둔덕","min_level":32,"sort_order":0},{"node_id":"g70/node/ash_reeds/2/1","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/1/0","hierarchy_level":3,"node_name":"뒤집힌 거룻배","min_level":32,"sort_order":1},{"node_id":"g70/node/ash_reeds/2/2","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/1/1","hierarchy_level":3,"node_name":"갈대 우는 여울","min_level":32,"sort_order":2},{"node_id":"g70/node/ash_reeds/2/3","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/1/1","hierarchy_level":3,"node_name":"백로 뼈 무덤","min_level":32,"sort_order":3},{"node_id":"g70/node/inverted_shrine/2/0","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/1/0","hierarchy_level":3,"node_name":"아래로 타는 향로","min_level":35,"sort_order":0},{"node_id":"g70/node/inverted_shrine/2/1","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/1/0","hierarchy_level":3,"node_name":"거꾸로 선 석탑","min_level":35,"sort_order":1},{"node_id":"g70/node/inverted_shrine/2/2","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/1/1","hierarchy_level":3,"node_name":"뒤집힌 연못","min_level":35,"sort_order":2},{"node_id":"g70/node/inverted_shrine/2/3","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/1/1","hierarchy_level":3,"node_name":"매달린 불단","min_level":35,"sort_order":3},{"node_id":"g70/node/moonless_market/2/0","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/1/0","hierarchy_level":3,"node_name":"얼굴 없는 포목전","min_level":38,"sort_order":0},{"node_id":"g70/node/moonless_market/2/1","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/1/0","hierarchy_level":3,"node_name":"기억 저울집","min_level":38,"sort_order":1},{"node_id":"g70/node/moonless_market/2/2","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/1/1","hierarchy_level":3,"node_name":"문 닫힌 약방","min_level":38,"sort_order":2},{"node_id":"g70/node/moonless_market/2/3","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/1/1","hierarchy_level":3,"node_name":"녹슨 대장간 터","min_level":38,"sort_order":3},{"node_id":"g70/node/gwiheo_core/2/0","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/1/0","hierarchy_level":3,"node_name":"돌아오지 못한 배 무덤","min_level":40,"sort_order":0},{"node_id":"g70/node/gwiheo_core/2/1","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/1/0","hierarchy_level":3,"node_name":"빛이 지는 해구","min_level":40,"sort_order":1},{"node_id":"g70/node/gwiheo_core/2/2","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/1/1","hierarchy_level":3,"node_name":"흰 사슬 늘어진 벼랑","min_level":40,"sort_order":2},{"node_id":"g70/node/gwiheo_core/2/3","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/1/1","hierarchy_level":3,"node_name":"이름 녹는 갯벌","min_level":40,"sort_order":3},{"node_id":"g70/node/ash_reeds/3/0","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/2/0","hierarchy_level":4,"node_name":"재 날리는 모래톱","min_level":34,"sort_order":0},{"node_id":"g70/node/ash_reeds/3/1","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/2/0","hierarchy_level":4,"node_name":"물안개 고인 웅덩이","min_level":34,"sort_order":1},{"node_id":"g70/node/ash_reeds/3/2","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/2/1","hierarchy_level":4,"node_name":"끊어진 징검다리","min_level":34,"sort_order":2},{"node_id":"g70/node/ash_reeds/3/3","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/2/2","hierarchy_level":4,"node_name":"반쯤 잠긴 초막","min_level":34,"sort_order":3},{"node_id":"g70/node/ash_reeds/3/4","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/2/2","hierarchy_level":4,"node_name":"갈대 엮은 장승","min_level":34,"sort_order":4},{"node_id":"g70/node/ash_reeds/3/5","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/2/3","hierarchy_level":4,"node_name":"썩은 그물 더미","min_level":34,"sort_order":5},{"node_id":"g70/node/inverted_shrine/3/0","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/2/0","hierarchy_level":4,"node_name":"위로 흐르는 계단","min_level":37,"sort_order":0},{"node_id":"g70/node/inverted_shrine/3/1","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/2/0","hierarchy_level":4,"node_name":"거꾸로 새긴 비석","min_level":37,"sort_order":1},{"node_id":"g70/node/inverted_shrine/3/2","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/2/1","hierarchy_level":4,"node_name":"발밑의 단청","min_level":37,"sort_order":2},{"node_id":"g70/node/inverted_shrine/3/3","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/2/2","hierarchy_level":4,"node_name":"뒤집힌 공양간","min_level":37,"sort_order":3},{"node_id":"g70/node/inverted_shrine/3/4","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/2/2","hierarchy_level":4,"node_name":"거꾸로 앉은 나한전","min_level":37,"sort_order":4},{"node_id":"g70/node/inverted_shrine/3/5","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/2/3","hierarchy_level":4,"node_name":"하늘로 떨어진 기와","min_level":37,"sort_order":5},{"node_id":"g70/node/moonless_market/3/0","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/2/0","hierarchy_level":4,"node_name":"그림자 경매터","min_level":40,"sort_order":0},{"node_id":"g70/node/moonless_market/3/1","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/2/0","hierarchy_level":4,"node_name":"값 없는 전당포","min_level":40,"sort_order":1},{"node_id":"g70/node/moonless_market/3/2","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/2/1","hierarchy_level":4,"node_name":"거꾸로 셈하는 주판방","min_level":40,"sort_order":2},{"node_id":"g70/node/moonless_market/3/3","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/2/2","hierarchy_level":4,"node_name":"혼 담는 옹기전","min_level":40,"sort_order":3},{"node_id":"g70/node/moonless_market/3/4","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/2/2","hierarchy_level":4,"node_name":"길 잃은 등짐꾼 쉼터","min_level":40,"sort_order":4},{"node_id":"g70/node/moonless_market/3/5","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/2/3","hierarchy_level":4,"node_name":"이름 쓴 부채 가게","min_level":40,"sort_order":5},{"node_id":"g70/node/gwiheo_core/3/0","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/2/0","hierarchy_level":4,"node_name":"바닥 없는 우물","min_level":40,"sort_order":0},{"node_id":"g70/node/gwiheo_core/3/1","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/2/0","hierarchy_level":4,"node_name":"거꾸로 흐르는 폭포","min_level":40,"sort_order":1},{"node_id":"g70/node/gwiheo_core/3/2","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/2/1","hierarchy_level":4,"node_name":"망자의 등대","min_level":40,"sort_order":2},{"node_id":"g70/node/gwiheo_core/3/3","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/2/2","hierarchy_level":4,"node_name":"검은 진주밭","min_level":40,"sort_order":3},{"node_id":"g70/node/gwiheo_core/3/4","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/2/2","hierarchy_level":4,"node_name":"숨 멎은 산호 숲","min_level":40,"sort_order":4},{"node_id":"g70/node/gwiheo_core/3/5","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/2/3","hierarchy_level":4,"node_name":"무너진 해신당","min_level":40,"sort_order":5},{"node_id":"g70/node/ash_reeds/4/0","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/3/0","hierarchy_level":5,"node_name":"달 비친 늪구멍","min_level":36,"sort_order":0},{"node_id":"g70/node/ash_reeds/4/1","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/3/0","hierarchy_level":5,"node_name":"이름 새긴 말뚝","min_level":36,"sort_order":1},{"node_id":"g70/node/ash_reeds/4/2","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/3/1","hierarchy_level":5,"node_name":"갈대 속 빈 무덤","min_level":36,"sort_order":2},{"node_id":"g70/node/ash_reeds/4/3","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/3/2","hierarchy_level":5,"node_name":"잿물 고인 샘","min_level":36,"sort_order":3},{"node_id":"g70/node/ash_reeds/4/4","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/3/3","hierarchy_level":5,"node_name":"버려진 물레방아","min_level":36,"sort_order":4},{"node_id":"g70/node/ash_reeds/4/5","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/3/3","hierarchy_level":5,"node_name":"갈꽃 덮인 제단","min_level":36,"sort_order":5},{"node_id":"g70/node/ash_reeds/4/6","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/3/4","hierarchy_level":5,"node_name":"흰 뼈 쌓인 둑","min_level":36,"sort_order":6},{"node_id":"g70/node/ash_reeds/4/7","region_id":"ash_reeds","parent_node_id":"g70/node/ash_reeds/3/5","hierarchy_level":5,"node_name":"물귀신 바위","min_level":36,"sort_order":7},{"node_id":"g70/node/inverted_shrine/4/0","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/3/0","hierarchy_level":5,"node_name":"거꾸로 우는 풍경","min_level":39,"sort_order":0},{"node_id":"g70/node/inverted_shrine/4/1","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/3/0","hierarchy_level":5,"node_name":"머리 위의 우물","min_level":39,"sort_order":1},{"node_id":"g70/node/inverted_shrine/4/2","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/3/1","hierarchy_level":5,"node_name":"뒤집힌 탱화","min_level":39,"sort_order":2},{"node_id":"g70/node/inverted_shrine/4/3","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/3/2","hierarchy_level":5,"node_name":"거꾸로 감긴 염주 더미","min_level":39,"sort_order":3},{"node_id":"g70/node/inverted_shrine/4/4","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/3/3","hierarchy_level":5,"node_name":"천장에 핀 연꽃","min_level":39,"sort_order":4},{"node_id":"g70/node/inverted_shrine/4/5","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/3/3","hierarchy_level":5,"node_name":"거꾸로 새긴 이름판","min_level":39,"sort_order":5},{"node_id":"g70/node/inverted_shrine/4/6","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/3/4","hierarchy_level":5,"node_name":"아래로 솟은 당간","min_level":39,"sort_order":6},{"node_id":"g70/node/inverted_shrine/4/7","region_id":"inverted_shrine","parent_node_id":"g70/node/inverted_shrine/3/5","hierarchy_level":5,"node_name":"뒤집힌 부처의 손","min_level":39,"sort_order":7},{"node_id":"g70/node/moonless_market/4/0","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/3/0","hierarchy_level":5,"node_name":"달 판 자리","min_level":40,"sort_order":0},{"node_id":"g70/node/moonless_market/4/1","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/3/0","hierarchy_level":5,"node_name":"마지막 손님의 탁자","min_level":40,"sort_order":1},{"node_id":"g70/node/moonless_market/4/2","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/3/1","hierarchy_level":5,"node_name":"빈 갓 걸린 담","min_level":40,"sort_order":2},{"node_id":"g70/node/moonless_market/4/3","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/3/2","hierarchy_level":5,"node_name":"꺼진 청사초롱 아래","min_level":40,"sort_order":3},{"node_id":"g70/node/moonless_market/4/4","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/3/3","hierarchy_level":5,"node_name":"지운 장부 창고","min_level":40,"sort_order":4},{"node_id":"g70/node/moonless_market/4/5","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/3/3","hierarchy_level":5,"node_name":"목소리 파는 노점","min_level":40,"sort_order":5},{"node_id":"g70/node/moonless_market/4/6","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/3/4","hierarchy_level":5,"node_name":"거울 덮은 방","min_level":40,"sort_order":6},{"node_id":"g70/node/moonless_market/4/7","region_id":"moonless_market","parent_node_id":"g70/node/moonless_market/3/5","hierarchy_level":5,"node_name":"셈 끝난 계산대","min_level":40,"sort_order":7},{"node_id":"g70/node/gwiheo_core/4/0","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/3/0","hierarchy_level":5,"node_name":"귀허의 눈","min_level":40,"sort_order":0},{"node_id":"g70/node/gwiheo_core/4/1","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/3/0","hierarchy_level":5,"node_name":"마지막 물빛","min_level":40,"sort_order":1},{"node_id":"g70/node/gwiheo_core/4/2","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/3/1","hierarchy_level":5,"node_name":"사라진 이들의 둥지","min_level":40,"sort_order":2},{"node_id":"g70/node/gwiheo_core/4/3","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/3/2","hierarchy_level":5,"node_name":"검은 물의 왕좌 앞","min_level":40,"sort_order":3},{"node_id":"g70/node/gwiheo_core/4/4","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/3/3","hierarchy_level":5,"node_name":"소용돌이 밑바닥","min_level":40,"sort_order":4},{"node_id":"g70/node/gwiheo_core/4/5","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/3/3","hierarchy_level":5,"node_name":"닫힌 바다 문","min_level":40,"sort_order":5},{"node_id":"g70/node/gwiheo_core/4/6","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/3/4","hierarchy_level":5,"node_name":"침묵의 해저 궁","min_level":40,"sort_order":6},{"node_id":"g70/node/gwiheo_core/4/7","region_id":"gwiheo_core","parent_node_id":"g70/node/gwiheo_core/3/5","hierarchy_level":5,"node_name":"주인의 빈 자리","min_level":40,"sort_order":7}]$J$::jsonb) as x(node_id text, region_id text, parent_node_id text, hierarchy_level smallint, node_name text, description text, min_level int, sort_order int)
on conflict (node_id) do update set node_name = excluded.node_name, parent_node_id = excluded.parent_node_id, min_level = excluded.min_level;
insert into public.world_gathering_spots(spot_id, node_id, spot_name, category, loot_items, min_level, yield_min, yield_max, difficulty, active)
select md5(x.spot_id)::uuid, md5(x.node_id)::uuid, x.spot_name, x.category, array(select jsonb_array_elements_text($J${"banyo_village":{"supplies":["herb","travel_ration","tonic"],"herbs":["herb","herb","medicine_base"]},"ash_reeds":{"water":["river_reed","river_reed","drowned_scale","reed_silk"],"herbs":["herb","medicine_base","moon_moss","reed_silk"],"wood":["wood","wood","resin","reed_silk"],"supplies":["herb","travel_ration","tonic"]},"inverted_shrine":{"relics":["seal_paper","inkstone","talisman_thread","inverted_incense"],"spirit":["spirit_dust","ghost_ash","ward_fragment","inverted_incense"],"wood":["wood","resin","inverted_incense"],"supplies":["herb","travel_ration","tonic"]},"moonless_market":{"relics":["seal_paper","inkstone","moonless_silk","oblivion_crystal"],"supplies":["herb","travel_ration","tonic","moonless_silk"],"ore":["ore","raw_iron","oblivion_crystal"],"spirit":["spirit_dust","ghost_ash","oblivion_crystal"]},"gwiheo_core":{"ore":["ore","raw_iron","gwiheo_iron"],"spirit":["spirit_dust","ghost_ash","spirit_core","gwiheo_iron"],"relics":["seal_paper","ward_fragment","gwiheo_iron"],"water":["river_reed","drowned_scale","gwiheo_iron"]}}$J$::jsonb -> x.r -> x.category)), x.min_level, x.yield_min, x.yield_max, x.difficulty, true from jsonb_to_recordset($J$[{"spot_id":"g70/spot/banyo_village/entry","node_id":"g70/node/banyo_village/0/0","spot_name":"어귀의 비늘 지붕 텃밭","category":"herbs","r":"banyo_village","min_level":30,"yield_min":1,"yield_max":2,"difficulty":1},{"spot_id":"g70/spot/banyo_village/1/0/0","node_id":"g70/node/banyo_village/1/0","spot_name":"비늘 덮인 버려진 봇짐","category":"supplies","r":"banyo_village","min_level":30,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/banyo_village/1/0/1","node_id":"g70/node/banyo_village/1/0","spot_name":"문패 걸린 이끼 낀 바위틈","category":"herbs","r":"banyo_village","min_level":30,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/banyo_village/1/1/0","node_id":"g70/node/banyo_village/1/1","spot_name":"비늘 덮인 무너진 초막","category":"supplies","r":"banyo_village","min_level":30,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/banyo_village/1/1/1","node_id":"g70/node/banyo_village/1/1","spot_name":"문패 걸린 고사리 그늘","category":"herbs","r":"banyo_village","min_level":30,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/ash_reeds/entry","node_id":"g70/node/ash_reeds/0/0","spot_name":"어귀의 잿빛 갈대 여울","category":"water","r":"ash_reeds","min_level":30,"yield_min":1,"yield_max":2,"difficulty":1},{"spot_id":"g70/spot/ash_reeds/1/0/0","node_id":"g70/node/ash_reeds/1/0","spot_name":"잿빛 갈대 여울","category":"water","r":"ash_reeds","min_level":30,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/ash_reeds/1/0/1","node_id":"g70/node/ash_reeds/1/0","spot_name":"젖은 이끼 낀 바위틈","category":"herbs","r":"ash_reeds","min_level":30,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/ash_reeds/1/1/0","node_id":"g70/node/ash_reeds/1/1","spot_name":"바스락대는 갈대 울타리","category":"wood","r":"ash_reeds","min_level":30,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/ash_reeds/1/1/1","node_id":"g70/node/ash_reeds/1/1","spot_name":"물안개 낀 빈 객주 광","category":"supplies","r":"ash_reeds","min_level":30,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/ash_reeds/2/0/0","node_id":"g70/node/ash_reeds/2/0","spot_name":"백로 우는 늪가 진흙밭","category":"water","r":"ash_reeds","min_level":32,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/ash_reeds/2/0/1","node_id":"g70/node/ash_reeds/2/0","spot_name":"갈꽃 흩날리는 약풀 둔덕","category":"herbs","r":"ash_reeds","min_level":32,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/ash_reeds/2/1/0","node_id":"g70/node/ash_reeds/2/1","spot_name":"물비린내 나는 향나무 그루터기","category":"wood","r":"ash_reeds","min_level":32,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/ash_reeds/2/1/1","node_id":"g70/node/ash_reeds/2/1","spot_name":"달빛 젖은 무너진 초막","category":"supplies","r":"ash_reeds","min_level":32,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/ash_reeds/2/2/0","node_id":"g70/node/ash_reeds/2/2","spot_name":"재 덮인 갈대 뿌리 물가","category":"water","r":"ash_reeds","min_level":32,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/ash_reeds/2/2/1","node_id":"g70/node/ash_reeds/2/2","spot_name":"늪내 나는 물가 약초밭","category":"herbs","r":"ash_reeds","min_level":32,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/ash_reeds/2/3/0","node_id":"g70/node/ash_reeds/2/3","spot_name":"갈대 부러진 쓰러진 고목","category":"wood","r":"ash_reeds","min_level":32,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/ash_reeds/2/3/1","node_id":"g70/node/ash_reeds/2/3","spot_name":"잿빛 주인 없는 짐수레","category":"supplies","r":"ash_reeds","min_level":32,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/ash_reeds/3/0/0","node_id":"g70/node/ash_reeds/3/0","spot_name":"젖은 잿물 웅덩이","category":"water","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/0/1","node_id":"g70/node/ash_reeds/3/0","spot_name":"바스락대는 고사리 그늘","category":"herbs","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/1/0","node_id":"g70/node/ash_reeds/3/1","spot_name":"물안개 낀 나룻배 판자 더미","category":"wood","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/1/1","node_id":"g70/node/ash_reeds/3/1","spot_name":"백로 우는 버려진 봇짐","category":"supplies","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/2/0","node_id":"g70/node/ash_reeds/3/2","spot_name":"갈꽃 흩날리는 물풀 엉킨 굽이","category":"water","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/2/1","node_id":"g70/node/ash_reeds/3/2","spot_name":"물비린내 나는 쑥 덤불","category":"herbs","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/3/0","node_id":"g70/node/ash_reeds/3/3","spot_name":"달빛 젖은 부러진 서까래","category":"wood","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/3/1","node_id":"g70/node/ash_reeds/3/3","spot_name":"재 덮인 떠내려온 궤짝","category":"supplies","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/4/0","node_id":"g70/node/ash_reeds/3/4","spot_name":"늪내 나는 갈대 여울","category":"water","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/4/1","node_id":"g70/node/ash_reeds/3/4","spot_name":"갈대 부러진 이끼 낀 바위틈","category":"herbs","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/5/0","node_id":"g70/node/ash_reeds/3/5","spot_name":"잿빛 갈대 울타리","category":"wood","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/3/5/1","node_id":"g70/node/ash_reeds/3/5","spot_name":"젖은 빈 객주 광","category":"supplies","r":"ash_reeds","min_level":34,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/ash_reeds/4/0/0","node_id":"g70/node/ash_reeds/4/0","spot_name":"바스락대는 늪가 진흙밭","category":"water","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/0/1","node_id":"g70/node/ash_reeds/4/0","spot_name":"물안개 낀 약풀 둔덕","category":"herbs","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/1/0","node_id":"g70/node/ash_reeds/4/1","spot_name":"백로 우는 향나무 그루터기","category":"wood","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/1/1","node_id":"g70/node/ash_reeds/4/1","spot_name":"갈꽃 흩날리는 무너진 초막","category":"supplies","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/2/0","node_id":"g70/node/ash_reeds/4/2","spot_name":"물비린내 나는 갈대 뿌리 물가","category":"water","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/2/1","node_id":"g70/node/ash_reeds/4/2","spot_name":"달빛 젖은 물가 약초밭","category":"herbs","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/3/0","node_id":"g70/node/ash_reeds/4/3","spot_name":"재 덮인 쓰러진 고목","category":"wood","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/3/1","node_id":"g70/node/ash_reeds/4/3","spot_name":"늪내 나는 주인 없는 짐수레","category":"supplies","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/4/0","node_id":"g70/node/ash_reeds/4/4","spot_name":"갈대 부러진 잿물 웅덩이","category":"water","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/4/1","node_id":"g70/node/ash_reeds/4/4","spot_name":"잿빛 고사리 그늘","category":"herbs","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/5/0","node_id":"g70/node/ash_reeds/4/5","spot_name":"젖은 나룻배 판자 더미","category":"wood","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/5/1","node_id":"g70/node/ash_reeds/4/5","spot_name":"바스락대는 버려진 봇짐","category":"supplies","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/6/0","node_id":"g70/node/ash_reeds/4/6","spot_name":"물안개 낀 물풀 엉킨 굽이","category":"water","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/6/1","node_id":"g70/node/ash_reeds/4/6","spot_name":"백로 우는 쑥 덤불","category":"herbs","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/7/0","node_id":"g70/node/ash_reeds/4/7","spot_name":"갈꽃 흩날리는 부러진 서까래","category":"wood","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/ash_reeds/4/7/1","node_id":"g70/node/ash_reeds/4/7","spot_name":"물비린내 나는 떠내려온 궤짝","category":"supplies","r":"ash_reeds","min_level":36,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/entry","node_id":"g70/node/inverted_shrine/0/0","spot_name":"어귀의 거꾸로 선 향나무","category":"wood","r":"inverted_shrine","min_level":33,"yield_min":1,"yield_max":2,"difficulty":1},{"spot_id":"g70/spot/inverted_shrine/1/0/0","node_id":"g70/node/inverted_shrine/1/0","spot_name":"거꾸로 선 깨진 위패 더미","category":"relics","r":"inverted_shrine","min_level":33,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/inverted_shrine/1/0/1","node_id":"g70/node/inverted_shrine/1/0","spot_name":"향내 스민 푸른 넋 웅덩이","category":"spirit","r":"inverted_shrine","min_level":33,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/inverted_shrine/1/1/0","node_id":"g70/node/inverted_shrine/1/1","spot_name":"뒤집힌 갈대 울타리","category":"wood","r":"inverted_shrine","min_level":33,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/inverted_shrine/1/1/1","node_id":"g70/node/inverted_shrine/1/1","spot_name":"종소리 맴도는 빈 객주 광","category":"supplies","r":"inverted_shrine","min_level":33,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/inverted_shrine/2/0/0","node_id":"g70/node/inverted_shrine/2/0","spot_name":"천장에 매달린 그을린 경판","category":"relics","r":"inverted_shrine","min_level":35,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/inverted_shrine/2/0/1","node_id":"g70/node/inverted_shrine/2/0","spot_name":"단청 벗겨진 요기 맺힌 돌","category":"spirit","r":"inverted_shrine","min_level":35,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/inverted_shrine/2/1/0","node_id":"g70/node/inverted_shrine/2/1","spot_name":"아래로 흐르는 향나무 그루터기","category":"wood","r":"inverted_shrine","min_level":35,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/inverted_shrine/2/1/1","node_id":"g70/node/inverted_shrine/2/1","spot_name":"목탁 소리 나는 무너진 초막","category":"supplies","r":"inverted_shrine","min_level":35,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/inverted_shrine/2/2/0","node_id":"g70/node/inverted_shrine/2/2","spot_name":"거꾸로 그을린 이름 지운 족자","category":"relics","r":"inverted_shrine","min_level":35,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/inverted_shrine/2/2/1","node_id":"g70/node/inverted_shrine/2/2","spot_name":"불경 적힌 귀기 서린 샘","category":"spirit","r":"inverted_shrine","min_level":35,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/inverted_shrine/2/3/0","node_id":"g70/node/inverted_shrine/2/3","spot_name":"주춧돌 들린 쓰러진 고목","category":"wood","r":"inverted_shrine","min_level":35,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/inverted_shrine/2/3/1","node_id":"g70/node/inverted_shrine/2/3","spot_name":"거꾸로 선 주인 없는 짐수레","category":"supplies","r":"inverted_shrine","min_level":35,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/inverted_shrine/3/0/0","node_id":"g70/node/inverted_shrine/3/0","spot_name":"향내 스민 거꾸로 걸린 현판","category":"relics","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/0/1","node_id":"g70/node/inverted_shrine/3/0","spot_name":"뒤집힌 흐느끼는 바위","category":"spirit","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/1/0","node_id":"g70/node/inverted_shrine/3/1","spot_name":"종소리 맴도는 나룻배 판자 더미","category":"wood","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/1/1","node_id":"g70/node/inverted_shrine/3/1","spot_name":"천장에 매달린 버려진 봇짐","category":"supplies","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/2/0","node_id":"g70/node/inverted_shrine/3/2","spot_name":"단청 벗겨진 빛바랜 부적 상자","category":"relics","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/2/1","node_id":"g70/node/inverted_shrine/3/2","spot_name":"아래로 흐르는 혼불 앉은 자리","category":"spirit","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/3/0","node_id":"g70/node/inverted_shrine/3/3","spot_name":"목탁 소리 나는 부러진 서까래","category":"wood","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/3/1","node_id":"g70/node/inverted_shrine/3/3","spot_name":"거꾸로 그을린 떠내려온 궤짝","category":"supplies","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/4/0","node_id":"g70/node/inverted_shrine/3/4","spot_name":"불경 적힌 깨진 위패 더미","category":"relics","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/4/1","node_id":"g70/node/inverted_shrine/3/4","spot_name":"주춧돌 들린 푸른 넋 웅덩이","category":"spirit","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/5/0","node_id":"g70/node/inverted_shrine/3/5","spot_name":"거꾸로 선 갈대 울타리","category":"wood","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/3/5/1","node_id":"g70/node/inverted_shrine/3/5","spot_name":"향내 스민 빈 객주 광","category":"supplies","r":"inverted_shrine","min_level":37,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/inverted_shrine/4/0/0","node_id":"g70/node/inverted_shrine/4/0","spot_name":"뒤집힌 그을린 경판","category":"relics","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/0/1","node_id":"g70/node/inverted_shrine/4/0","spot_name":"종소리 맴도는 요기 맺힌 돌","category":"spirit","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/1/0","node_id":"g70/node/inverted_shrine/4/1","spot_name":"천장에 매달린 향나무 그루터기","category":"wood","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/1/1","node_id":"g70/node/inverted_shrine/4/1","spot_name":"단청 벗겨진 무너진 초막","category":"supplies","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/2/0","node_id":"g70/node/inverted_shrine/4/2","spot_name":"아래로 흐르는 이름 지운 족자","category":"relics","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/2/1","node_id":"g70/node/inverted_shrine/4/2","spot_name":"목탁 소리 나는 귀기 서린 샘","category":"spirit","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/3/0","node_id":"g70/node/inverted_shrine/4/3","spot_name":"거꾸로 그을린 쓰러진 고목","category":"wood","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/3/1","node_id":"g70/node/inverted_shrine/4/3","spot_name":"불경 적힌 주인 없는 짐수레","category":"supplies","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/4/0","node_id":"g70/node/inverted_shrine/4/4","spot_name":"주춧돌 들린 거꾸로 걸린 현판","category":"relics","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/4/1","node_id":"g70/node/inverted_shrine/4/4","spot_name":"거꾸로 선 흐느끼는 바위","category":"spirit","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/5/0","node_id":"g70/node/inverted_shrine/4/5","spot_name":"향내 스민 나룻배 판자 더미","category":"wood","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/5/1","node_id":"g70/node/inverted_shrine/4/5","spot_name":"뒤집힌 버려진 봇짐","category":"supplies","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/6/0","node_id":"g70/node/inverted_shrine/4/6","spot_name":"종소리 맴도는 빛바랜 부적 상자","category":"relics","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/6/1","node_id":"g70/node/inverted_shrine/4/6","spot_name":"천장에 매달린 혼불 앉은 자리","category":"spirit","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/7/0","node_id":"g70/node/inverted_shrine/4/7","spot_name":"단청 벗겨진 부러진 서까래","category":"wood","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/inverted_shrine/4/7/1","node_id":"g70/node/inverted_shrine/4/7","spot_name":"아래로 흐르는 떠내려온 궤짝","category":"supplies","r":"inverted_shrine","min_level":39,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/entry","node_id":"g70/node/moonless_market/0/0","spot_name":"어귀의 꺼진 등롱 좌판","category":"supplies","r":"moonless_market","min_level":36,"yield_min":1,"yield_max":2,"difficulty":1},{"spot_id":"g70/spot/moonless_market/1/0/0","node_id":"g70/node/moonless_market/1/0","spot_name":"달빛 없는 깨진 위패 더미","category":"relics","r":"moonless_market","min_level":36,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/moonless_market/1/0/1","node_id":"g70/node/moonless_market/1/0","spot_name":"셈 끝난 주인 없는 짐수레","category":"supplies","r":"moonless_market","min_level":36,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/moonless_market/1/1/0","node_id":"g70/node/moonless_market/1/1","spot_name":"값 매겨진 검은 쇳돌 비탈","category":"ore","r":"moonless_market","min_level":36,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/moonless_market/1/1/1","node_id":"g70/node/moonless_market/1/1","spot_name":"얼굴 지운 흐느끼는 바위","category":"spirit","r":"moonless_market","min_level":36,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/moonless_market/2/0/0","node_id":"g70/node/moonless_market/2/0","spot_name":"흥정 소리 나는 그을린 경판","category":"relics","r":"moonless_market","min_level":38,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/moonless_market/2/0/1","node_id":"g70/node/moonless_market/2/0","spot_name":"등불 꺼진 버려진 봇짐","category":"supplies","r":"moonless_market","min_level":38,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/moonless_market/2/1/0","node_id":"g70/node/moonless_market/2/1","spot_name":"이름 팔린 해저 광맥","category":"ore","r":"moonless_market","min_level":38,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/moonless_market/2/1/1","node_id":"g70/node/moonless_market/2/1","spot_name":"먼지 앉은 좌판의 혼불 앉은 자리","category":"spirit","r":"moonless_market","min_level":38,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/moonless_market/2/2/0","node_id":"g70/node/moonless_market/2/2","spot_name":"저울 기운 이름 지운 족자","category":"relics","r":"moonless_market","min_level":38,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/moonless_market/2/2/1","node_id":"g70/node/moonless_market/2/2","spot_name":"목소리 갇힌 떠내려온 궤짝","category":"supplies","r":"moonless_market","min_level":38,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/moonless_market/2/3/0","node_id":"g70/node/moonless_market/2/3","spot_name":"주판알 흩어진 흑철 노두","category":"ore","r":"moonless_market","min_level":38,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/moonless_market/2/3/1","node_id":"g70/node/moonless_market/2/3","spot_name":"달빛 없는 푸른 넋 웅덩이","category":"spirit","r":"moonless_market","min_level":38,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/moonless_market/3/0/0","node_id":"g70/node/moonless_market/3/0","spot_name":"셈 끝난 거꾸로 걸린 현판","category":"relics","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/0/1","node_id":"g70/node/moonless_market/3/0","spot_name":"값 매겨진 빈 객주 광","category":"supplies","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/1/0","node_id":"g70/node/moonless_market/3/1","spot_name":"얼굴 지운 망각 수정 맥","category":"ore","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/1/1","node_id":"g70/node/moonless_market/3/1","spot_name":"흥정 소리 나는 요기 맺힌 돌","category":"spirit","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/2/0","node_id":"g70/node/moonless_market/3/2","spot_name":"등불 꺼진 빛바랜 부적 상자","category":"relics","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/2/1","node_id":"g70/node/moonless_market/3/2","spot_name":"이름 팔린 무너진 초막","category":"supplies","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/3/0","node_id":"g70/node/moonless_market/3/3","spot_name":"먼지 앉은 좌판의 조개껍질 섞인 쇳돌","category":"ore","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/3/1","node_id":"g70/node/moonless_market/3/3","spot_name":"저울 기운 귀기 서린 샘","category":"spirit","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/4/0","node_id":"g70/node/moonless_market/3/4","spot_name":"목소리 갇힌 깨진 위패 더미","category":"relics","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/4/1","node_id":"g70/node/moonless_market/3/4","spot_name":"주판알 흩어진 주인 없는 짐수레","category":"supplies","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/5/0","node_id":"g70/node/moonless_market/3/5","spot_name":"달빛 없는 검은 쇳돌 비탈","category":"ore","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/3/5/1","node_id":"g70/node/moonless_market/3/5","spot_name":"셈 끝난 흐느끼는 바위","category":"spirit","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/moonless_market/4/0/0","node_id":"g70/node/moonless_market/4/0","spot_name":"값 매겨진 그을린 경판","category":"relics","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/0/1","node_id":"g70/node/moonless_market/4/0","spot_name":"얼굴 지운 버려진 봇짐","category":"supplies","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/1/0","node_id":"g70/node/moonless_market/4/1","spot_name":"흥정 소리 나는 해저 광맥","category":"ore","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/1/1","node_id":"g70/node/moonless_market/4/1","spot_name":"등불 꺼진 혼불 앉은 자리","category":"spirit","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/2/0","node_id":"g70/node/moonless_market/4/2","spot_name":"이름 팔린 이름 지운 족자","category":"relics","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/2/1","node_id":"g70/node/moonless_market/4/2","spot_name":"먼지 앉은 좌판의 떠내려온 궤짝","category":"supplies","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/3/0","node_id":"g70/node/moonless_market/4/3","spot_name":"저울 기운 흑철 노두","category":"ore","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/3/1","node_id":"g70/node/moonless_market/4/3","spot_name":"목소리 갇힌 푸른 넋 웅덩이","category":"spirit","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/4/0","node_id":"g70/node/moonless_market/4/4","spot_name":"주판알 흩어진 거꾸로 걸린 현판","category":"relics","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/4/1","node_id":"g70/node/moonless_market/4/4","spot_name":"달빛 없는 빈 객주 광","category":"supplies","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/5/0","node_id":"g70/node/moonless_market/4/5","spot_name":"셈 끝난 망각 수정 맥","category":"ore","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/5/1","node_id":"g70/node/moonless_market/4/5","spot_name":"값 매겨진 요기 맺힌 돌","category":"spirit","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/6/0","node_id":"g70/node/moonless_market/4/6","spot_name":"얼굴 지운 빛바랜 부적 상자","category":"relics","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/6/1","node_id":"g70/node/moonless_market/4/6","spot_name":"흥정 소리 나는 무너진 초막","category":"supplies","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/7/0","node_id":"g70/node/moonless_market/4/7","spot_name":"등불 꺼진 조개껍질 섞인 쇳돌","category":"ore","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/moonless_market/4/7/1","node_id":"g70/node/moonless_market/4/7","spot_name":"이름 팔린 귀기 서린 샘","category":"spirit","r":"moonless_market","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/entry","node_id":"g70/node/gwiheo_core/0/0","spot_name":"어귀의 소용돌이 쇳돌","category":"ore","r":"gwiheo_core","min_level":38,"yield_min":1,"yield_max":2,"difficulty":1},{"spot_id":"g70/spot/gwiheo_core/1/0/0","node_id":"g70/node/gwiheo_core/1/0","spot_name":"소용돌이치는 흑철 노두","category":"ore","r":"gwiheo_core","min_level":38,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/gwiheo_core/1/0/1","node_id":"g70/node/gwiheo_core/1/0","spot_name":"빛 잃은 푸른 넋 웅덩이","category":"spirit","r":"gwiheo_core","min_level":38,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/gwiheo_core/1/1/0","node_id":"g70/node/gwiheo_core/1/1","spot_name":"바닥 모를 거꾸로 걸린 현판","category":"relics","r":"gwiheo_core","min_level":38,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/gwiheo_core/1/1/1","node_id":"g70/node/gwiheo_core/1/1","spot_name":"물살 거꾸로 도는 갈대 뿌리 물가","category":"water","r":"gwiheo_core","min_level":38,"yield_min":1,"yield_max":2,"difficulty":12},{"spot_id":"g70/spot/gwiheo_core/2/0/0","node_id":"g70/node/gwiheo_core/2/0","spot_name":"진주빛 도는 망각 수정 맥","category":"ore","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/gwiheo_core/2/0/1","node_id":"g70/node/gwiheo_core/2/0","spot_name":"물에 잠긴 요기 맺힌 돌","category":"spirit","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/gwiheo_core/2/1/0","node_id":"g70/node/gwiheo_core/2/1","spot_name":"파도 멎은 빛바랜 부적 상자","category":"relics","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/gwiheo_core/2/1/1","node_id":"g70/node/gwiheo_core/2/1","spot_name":"검은 물 고인 잿물 웅덩이","category":"water","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/gwiheo_core/2/2/0","node_id":"g70/node/gwiheo_core/2/2","spot_name":"해신 잠든 조개껍질 섞인 쇳돌","category":"ore","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/gwiheo_core/2/2/1","node_id":"g70/node/gwiheo_core/2/2","spot_name":"사라져 가는 귀기 서린 샘","category":"spirit","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/gwiheo_core/2/3/0","node_id":"g70/node/gwiheo_core/2/3","spot_name":"끝없이 가라앉는 깨진 위패 더미","category":"relics","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/gwiheo_core/2/3/1","node_id":"g70/node/gwiheo_core/2/3","spot_name":"소용돌이치는 물풀 엉킨 굽이","category":"water","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":2,"difficulty":13},{"spot_id":"g70/spot/gwiheo_core/3/0/0","node_id":"g70/node/gwiheo_core/3/0","spot_name":"빛 잃은 검은 쇳돌 비탈","category":"ore","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/0/1","node_id":"g70/node/gwiheo_core/3/0","spot_name":"바닥 모를 흐느끼는 바위","category":"spirit","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/1/0","node_id":"g70/node/gwiheo_core/3/1","spot_name":"물살 거꾸로 도는 그을린 경판","category":"relics","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/1/1","node_id":"g70/node/gwiheo_core/3/1","spot_name":"진주빛 도는 갈대 여울","category":"water","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/2/0","node_id":"g70/node/gwiheo_core/3/2","spot_name":"물에 잠긴 해저 광맥","category":"ore","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/2/1","node_id":"g70/node/gwiheo_core/3/2","spot_name":"파도 멎은 혼불 앉은 자리","category":"spirit","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/3/0","node_id":"g70/node/gwiheo_core/3/3","spot_name":"검은 물 고인 이름 지운 족자","category":"relics","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/3/1","node_id":"g70/node/gwiheo_core/3/3","spot_name":"해신 잠든 늪가 진흙밭","category":"water","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/4/0","node_id":"g70/node/gwiheo_core/3/4","spot_name":"사라져 가는 흑철 노두","category":"ore","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/4/1","node_id":"g70/node/gwiheo_core/3/4","spot_name":"끝없이 가라앉는 푸른 넋 웅덩이","category":"spirit","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/5/0","node_id":"g70/node/gwiheo_core/3/5","spot_name":"소용돌이치는 거꾸로 걸린 현판","category":"relics","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/3/5/1","node_id":"g70/node/gwiheo_core/3/5","spot_name":"빛 잃은 갈대 뿌리 물가","category":"water","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":14},{"spot_id":"g70/spot/gwiheo_core/4/0/0","node_id":"g70/node/gwiheo_core/4/0","spot_name":"바닥 모를 망각 수정 맥","category":"ore","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/0/1","node_id":"g70/node/gwiheo_core/4/0","spot_name":"물살 거꾸로 도는 요기 맺힌 돌","category":"spirit","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/1/0","node_id":"g70/node/gwiheo_core/4/1","spot_name":"진주빛 도는 빛바랜 부적 상자","category":"relics","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/1/1","node_id":"g70/node/gwiheo_core/4/1","spot_name":"물에 잠긴 잿물 웅덩이","category":"water","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/2/0","node_id":"g70/node/gwiheo_core/4/2","spot_name":"파도 멎은 조개껍질 섞인 쇳돌","category":"ore","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/2/1","node_id":"g70/node/gwiheo_core/4/2","spot_name":"검은 물 고인 귀기 서린 샘","category":"spirit","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/3/0","node_id":"g70/node/gwiheo_core/4/3","spot_name":"해신 잠든 깨진 위패 더미","category":"relics","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/3/1","node_id":"g70/node/gwiheo_core/4/3","spot_name":"사라져 가는 물풀 엉킨 굽이","category":"water","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/4/0","node_id":"g70/node/gwiheo_core/4/4","spot_name":"끝없이 가라앉는 검은 쇳돌 비탈","category":"ore","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/4/1","node_id":"g70/node/gwiheo_core/4/4","spot_name":"소용돌이치는 흐느끼는 바위","category":"spirit","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/5/0","node_id":"g70/node/gwiheo_core/4/5","spot_name":"빛 잃은 그을린 경판","category":"relics","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/5/1","node_id":"g70/node/gwiheo_core/4/5","spot_name":"바닥 모를 갈대 여울","category":"water","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/6/0","node_id":"g70/node/gwiheo_core/4/6","spot_name":"물살 거꾸로 도는 해저 광맥","category":"ore","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/6/1","node_id":"g70/node/gwiheo_core/4/6","spot_name":"진주빛 도는 혼불 앉은 자리","category":"spirit","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/7/0","node_id":"g70/node/gwiheo_core/4/7","spot_name":"물에 잠긴 이름 지운 족자","category":"relics","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15},{"spot_id":"g70/spot/gwiheo_core/4/7/1","node_id":"g70/node/gwiheo_core/4/7","spot_name":"파도 멎은 늪가 진흙밭","category":"water","r":"gwiheo_core","min_level":40,"yield_min":1,"yield_max":3,"difficulty":15}]$J$::jsonb) as x(spot_id text, node_id text, spot_name text, category text, loot_items jsonb, min_level int, yield_min int, yield_max int, difficulty int, active boolean, r text)
on conflict (spot_id) do update set spot_name = excluded.spot_name, loot_items = excluded.loot_items, min_level = excluded.min_level;
insert into public.world_region_monsters(monster_id, region_id, monster_name, monster_type, min_level, max_level, hp, attack_power, spawn_weight, description, drops, difficulty_rank, mechanic_key, mechanic_description, role, kind)
select x.monster_id, x.region_id, x.monster_name, x.monster_type, x.min_level, x.max_level, x.hp, x.attack_power, x.spawn_weight, x.description, x.drops, x.difficulty_rank, x.mechanic_key, x.mechanic_description, x.role, x.kind from jsonb_to_recordset($J$[{"monster_id":"gw_reed_1","region_id":"ash_reeds","monster_name":"갈대 물귀신","monster_type":"수귀","min_level":30,"max_level":33,"hp":490,"attack_power":41,"spawn_weight":14,"description":"갈대 뿌리에 발을 감고 사람을 물속으로 끌어당긴다.","drops":{"river_reed":1,"banyo_scale":1},"difficulty_rank":2,"mechanic_key":"tide","mechanic_description":"물살로 끌어당겨 발을 묶는다. 거리를 두고 싸우거나 묶이기 전에 끊어라.","role":"common","kind":"water"},{"monster_id":"gw_reed_2","region_id":"ash_reeds","monster_name":"잿빛 백로 떼","monster_type":"비행 요괴","min_level":30,"max_level":33,"hp":490,"attack_power":41,"spawn_weight":14,"description":"재를 뒤집어쓴 백로 떼. 한 마리가 울면 모두 내리꽂힌다.","drops":{"sky_feather":1,"banyo_scale":1},"difficulty_rank":2,"mechanic_key":"aerial","mechanic_description":"하늘에서 내리꽂는다. 원거리 사격이 잘 듣는다.","role":"common","kind":"bird"},{"monster_id":"gw_reed_3","region_id":"ash_reeds","monster_name":"이름 잃은 사공","monster_type":"원령","min_level":32,"max_level":36,"hp":4500,"attack_power":225,"spawn_weight":15,"description":"건너편에 데려다준다며 노를 젓지만 배는 늘 같은 자리를 돈다.","drops":{"ghost_ash":4,"reed_silk":2,"yoin_blood":1},"difficulty_rank":5,"mechanic_key":"spectral","mechanic_description":"몸이 반쯤 비친다. 물리 공격이 덜 듣고 술법이 잘 듣는다.","role":"main","kind":"ghost"},{"monster_id":"gw_reed_4","region_id":"ash_reeds","monster_name":"갈대 엮인 요인","monster_type":"목령","min_level":32,"max_level":36,"hp":4500,"attack_power":225,"spawn_weight":15,"description":"몸에 갈대를 엮어 사람 꼴을 지키려는 반요. 숨결에 독이 섞였다.","drops":{"reed_silk":3,"venom_gland":1,"yoin_blood":1},"difficulty_rank":5,"mechanic_key":"toxic","mechanic_description":"독을 뿜는다. 해독할 약초와 회복품을 챙겨라.","role":"main","kind":"wood"},{"monster_id":"gw_reed_5","region_id":"ash_reeds","monster_name":"잿빛 갈대 어미","monster_type":"지역 우두머리","min_level":30,"max_level":32,"hp":735,"attack_power":57,"spawn_weight":12,"description":"갈대숲 전체를 제 몸처럼 흔드는 어미 요괴.","drops":{"reed_silk":3,"yoin_blood":2,"spirit_core":1},"difficulty_rank":10,"mechanic_key":"swarm","mechanic_description":"떼로 몰려든다. 세 번째 행동마다 강하게 반격한다.","role":"guardian","kind":"swarm"},{"monster_id":"gw_shrine_1","region_id":"inverted_shrine","monster_name":"거꾸로 매달린 동자","monster_type":"원령","min_level":33,"max_level":36,"hp":532,"attack_power":44,"spawn_weight":14,"description":"천장에 거꾸로 매달려 목탁을 두드리는 아이의 혼.","drops":{"ghost_ash":1,"banyo_scale":1},"difficulty_rank":2,"mechanic_key":"spectral","mechanic_description":"몸이 반쯤 비친다. 물리 공격이 덜 듣고 술법이 잘 듣는다.","role":"common","kind":"ghost"},{"monster_id":"gw_shrine_2","region_id":"inverted_shrine","monster_name":"뒤집힌 향로귀","monster_type":"결계 요괴","min_level":33,"max_level":36,"hp":532,"attack_power":44,"spawn_weight":14,"description":"아래로 타는 향 연기를 두른 향로. 연기가 결계가 된다.","drops":{"inverted_incense":1,"banyo_scale":1},"difficulty_rank":2,"mechanic_key":"warded","mechanic_description":"결계를 두른다. 결계를 깨는 한 방을 모아 두어라.","role":"common","kind":"ward"},{"monster_id":"gw_shrine_3","region_id":"inverted_shrine","monster_name":"목 없는 나한","monster_type":"갑각 요괴","min_level":35,"max_level":39,"hp":4950,"attack_power":248,"spawn_weight":15,"description":"머리를 잃은 석상이 거꾸로 걸어 다닌다. 돌 몸이 단단하다.","drops":{"monster_core":1,"inverted_incense":2,"yoin_blood":1},"difficulty_rank":5,"mechanic_key":"armored","mechanic_description":"껍질이 단단하다. 방어를 무시하는 공격이나 술법이 낫다.","role":"main","kind":"shell"},{"monster_id":"gw_shrine_4","region_id":"inverted_shrine","monster_name":"거울 속 주지","monster_type":"거울 요괴","min_level":35,"max_level":39,"hp":4950,"attack_power":248,"spawn_weight":15,"description":"연못에 비친 주지만 남고 몸은 사라졌다. 공격을 되돌린다.","drops":{"mirror_shard":2,"inverted_incense":2,"yoin_blood":1},"difficulty_rank":5,"mechanic_key":"reflect","mechanic_description":"공격의 일부를 되돌린다. 원거리 사격이나 봉인 제압을 써라.","role":"main","kind":"mirror"},{"monster_id":"gw_shrine_5","region_id":"inverted_shrine","monster_name":"거꾸로 선 범종귀","monster_type":"지역 우두머리","min_level":33,"max_level":35,"hp":798,"attack_power":62,"spawn_weight":12,"description":"종루에서 떨어진 범종이 요괴가 되었다. 울릴 때마다 봉인이 금 간다.","drops":{"inverted_incense":3,"yoin_blood":2,"spirit_core":1},"difficulty_rank":10,"mechanic_key":"seal_breaker","mechanic_description":"봉인을 약하게 만든다. 부적과 봉인 재료를 챙겨라.","role":"guardian","kind":"breaker"},{"monster_id":"gw_market_1","region_id":"moonless_market","monster_name":"값 매기는 그림자","monster_type":"매복 요괴","min_level":36,"max_level":39,"hp":574,"attack_power":48,"spawn_weight":14,"description":"좌판 그늘에 숨어 지나는 이의 기억에 값을 매긴다.","drops":{"shadow_fang":1,"banyo_scale":1},"difficulty_rank":2,"mechanic_key":"ambush","mechanic_description":"숨어 있다 먼저 친다. 낌새를 살피고 방어를 섞어라.","role":"common","kind":"shadow"},{"monster_id":"gw_market_2","region_id":"moonless_market","monster_name":"얼굴 없는 손님 떼","monster_type":"무리 요괴","min_level":36,"max_level":39,"hp":574,"attack_power":48,"spawn_weight":14,"description":"갓만 쓴 손님들이 한꺼번에 몰려든다.","drops":{"moonless_silk":1,"banyo_scale":1},"difficulty_rank":2,"mechanic_key":"swarm","mechanic_description":"떼로 몰려든다. 세 번째 행동마다 강하게 반격한다.","role":"common","kind":"swarm"},{"monster_id":"gw_market_3","region_id":"moonless_market","monster_name":"기억 저울 장수","monster_type":"결계 요괴","min_level":38,"max_level":41,"hp":5400,"attack_power":270,"spawn_weight":15,"description":"저울 한쪽에 사람의 기억을 올린다. 기운 쪽이 그의 것이 된다.","drops":{"oblivion_crystal":2,"moonless_silk":2,"yoin_blood":1},"difficulty_rank":5,"mechanic_key":"warded","mechanic_description":"결계를 두른다. 결계를 깨는 한 방을 모아 두어라.","role":"main","kind":"ward"},{"monster_id":"gw_market_4","region_id":"moonless_market","monster_name":"전당포 거미","monster_type":"독충","min_level":38,"max_level":41,"hp":5400,"attack_power":270,"spawn_weight":15,"description":"맡긴 물건을 거미줄로 감아 두는 늙은 거미. 독니가 길다.","drops":{"venom_gland":2,"moonless_silk":2,"yoin_blood":1},"difficulty_rank":5,"mechanic_key":"toxic","mechanic_description":"독을 뿜는다. 해독할 약초와 회복품을 챙겨라.","role":"main","kind":"venom"},{"monster_id":"gw_market_5","region_id":"moonless_market","monster_name":"달을 판 상주","monster_type":"지역 우두머리","min_level":36,"max_level":38,"hp":861,"attack_power":67,"spawn_weight":12,"description":"섬의 달을 팔아 치운 장터의 우두머리. 덩치가 저잣거리만 하다.","drops":{"oblivion_crystal":3,"yoin_blood":2,"spirit_core":1},"difficulty_rank":10,"mechanic_key":"boss","mechanic_description":"보스급 위협. 세 번째 행동마다 광역급 강공격을 하므로 방어 태세를 섞어라.","role":"guardian","kind":"giant"},{"monster_id":"gw_core_1","region_id":"gwiheo_core","monster_name":"돌아오는 파도귀","monster_type":"수귀","min_level":38,"max_level":40,"hp":602,"attack_power":50,"spawn_weight":14,"description":"빠져나간 물이 사람 꼴로 다시 밀려온다.","drops":{"drowned_scale":1,"banyo_scale":1},"difficulty_rank":2,"mechanic_key":"tide","mechanic_description":"물살로 끌어당겨 발을 묶는다. 거리를 두고 싸우거나 묶이기 전에 끊어라.","role":"common","kind":"water"},{"monster_id":"gw_core_2","region_id":"gwiheo_core","monster_name":"흰 사슬 망령","monster_type":"원령","min_level":38,"max_level":40,"hp":602,"attack_power":50,"spawn_weight":14,"description":"귀허로 끌려온 이들이 차던 사슬이 혼째 떠돈다.","drops":{"ghost_ash":1,"banyo_scale":1},"difficulty_rank":2,"mechanic_key":"spectral","mechanic_description":"몸이 반쯤 비친다. 물리 공격이 덜 듣고 술법이 잘 듣는다.","role":"common","kind":"ghost"},{"monster_id":"gw_core_3","region_id":"gwiheo_core","monster_name":"진주 문 해괴","monster_type":"갑각 요괴","min_level":40,"max_level":41,"hp":5700,"attack_power":285,"spawn_weight":15,"description":"등에 검은 진주를 박은 거대한 조개 요괴.","drops":{"gwiheo_iron":2,"monster_core":1,"yoin_blood":1},"difficulty_rank":5,"mechanic_key":"armored","mechanic_description":"껍질이 단단하다. 방어를 무시하는 공격이나 술법이 낫다.","role":"main","kind":"shell"},{"monster_id":"gw_core_4","region_id":"gwiheo_core","monster_name":"소용돌이 천상귀","monster_type":"천상 요괴","min_level":40,"max_level":41,"hp":5700,"attack_power":285,"spawn_weight":15,"description":"소용돌이 위를 맴도는 별빛 요괴. 떨어지는 빛이 사람을 밀어낸다.","drops":{"star_sand":1,"gwiheo_iron":2,"yoin_blood":1},"difficulty_rank":5,"mechanic_key":"aerial","mechanic_description":"하늘에서 내리꽂는다. 원거리 사격이 잘 듣는다.","role":"main","kind":"sky"},{"monster_id":"gw_core_5","region_id":"gwiheo_core","monster_name":"귀허의 문지기","monster_type":"지역 우두머리","min_level":38,"max_level":40,"hp":903,"attack_power":70,"spawn_weight":12,"description":"빈 왕좌로 가는 길목을 지키는 거울 몸의 문지기.","drops":{"gwiheo_iron":3,"yoin_blood":2,"gwiheo_pearl":1},"difficulty_rank":10,"mechanic_key":"reflect","mechanic_description":"공격의 일부를 되돌린다. 원거리 사격이나 봉인 제압을 써라.","role":"guardian","kind":"mirror"}]$J$::jsonb) as x(monster_id text, region_id text, monster_name text, monster_type text, min_level int, max_level int, hp int, attack_power int, spawn_weight int, description text, drops jsonb, difficulty_rank int, mechanic_key text, mechanic_description text, role text, kind text)
on conflict (monster_id) do update set monster_name = excluded.monster_name, description = excluded.description, drops = excluded.drops, min_level = excluded.min_level, max_level = excluded.max_level, hp = excluded.hp, attack_power = excluded.attack_power, mechanic_key = excluded.mechanic_key, kind = excluded.kind, role = excluded.role;
insert into public.world_expedition_grounds(ground_id, region_id, ground_name, description, depth, danger, min_level, unlock_progress)
select x.ground_id, x.region_id, x.ground_name, x.description, x.depth, x.danger, x.min_level, x.unlock_progress from jsonb_to_recordset($J$[{"ground_id":"ash_reeds_1","region_id":"ash_reeds","ground_name":"잿빛 나루 언저리","description":"재가 덜 내려앉은 바깥 물가.","depth":1,"danger":10,"min_level":30,"unlock_progress":0},{"ground_id":"ash_reeds_2","region_id":"ash_reeds","ground_name":"갈대 무덤 늪","description":"쓰러진 갈대가 무덤처럼 쌓인 늪.","depth":2,"danger":11,"min_level":32,"unlock_progress":30},{"ground_id":"ash_reeds_3","region_id":"ash_reeds","ground_name":"이름 부르는 여울","description":"갈대가 옛 이름을 부르는 가장 깊은 여울.","depth":3,"danger":12,"min_level":34,"unlock_progress":70},{"ground_id":"inverted_shrine_1","region_id":"inverted_shrine","ground_name":"뒤집힌 산문 앞","description":"사당으로 들어가는 거꾸로 된 문 앞.","depth":1,"danger":10,"min_level":33,"unlock_progress":0},{"ground_id":"inverted_shrine_2","region_id":"inverted_shrine","ground_name":"아래로 타는 법당","description":"향이 바닥으로 흘러내리는 법당.","depth":2,"danger":11,"min_level":35,"unlock_progress":30},{"ground_id":"inverted_shrine_3","region_id":"inverted_shrine","ground_name":"하늘 밑 불단","description":"천장이 된 바닥에 차려진 불단.","depth":3,"danger":12,"min_level":37,"unlock_progress":70},{"ground_id":"moonless_market_1","region_id":"moonless_market","ground_name":"꺼진 좌판 거리","description":"등불이 꺼진 장터 바깥 골목.","depth":1,"danger":10,"min_level":36,"unlock_progress":0},{"ground_id":"moonless_market_2","region_id":"moonless_market","ground_name":"기억 경매장","description":"기억을 사고파는 저잣거리 한복판.","depth":2,"danger":11,"min_level":38,"unlock_progress":30},{"ground_id":"moonless_market_3","region_id":"moonless_market","ground_name":"달 판 상주의 창고","description":"팔린 달빛이 쌓여 있다는 창고.","depth":3,"danger":12,"min_level":40,"unlock_progress":70},{"ground_id":"gwiheo_core_1","region_id":"gwiheo_core","ground_name":"가라앉는 물가","description":"발밑이 천천히 가라앉는 귀허의 바깥.","depth":1,"danger":10,"min_level":38,"unlock_progress":0},{"ground_id":"gwiheo_core_2","region_id":"gwiheo_core","ground_name":"소용돌이 벼랑","description":"흰 사슬이 늘어진 소용돌이 가장자리.","depth":2,"danger":11,"min_level":40,"unlock_progress":30},{"ground_id":"gwiheo_core_3","region_id":"gwiheo_core","ground_name":"빈 왕좌의 바다","description":"귀허의 주인이 기다리는 가장 깊은 곳.","depth":3,"danger":12,"min_level":40,"unlock_progress":70}]$J$::jsonb) as x(ground_id text, region_id text, ground_name text, description text, depth int, danger int, min_level int, unlock_progress int)
on conflict (ground_id) do update set ground_name = excluded.ground_name, description = excluded.description, min_level = excluded.min_level;
insert into public.world_fish_grounds(region_id, habitat, ground_name, description)
select x.region_id, x.habitat, x.ground_name, x.description from jsonb_to_recordset($J$[{"region_id":"ash_reeds","habitat":"marsh","ground_name":"잿빛 갈대 여울","description":"재 섞인 물에 찌가 잘 보이지 않습니다. 무언가 갈대 뿌리 사이를 스칩니다."},{"region_id":"gwiheo_core","habitat":"abyss","ground_name":"귀허 물가","description":"모든 물이 돌아가는 곳. 낚싯줄이 바닥에 닿지 않습니다."}]$J$::jsonb) as x(region_id text, habitat text, ground_name text, description text)
on conflict (region_id) do update set habitat = excluded.habitat, ground_name = excluded.ground_name, description = excluded.description;
insert into public.world_region_sites(site_id, region_id, site_name, site_type, bonus_item, loot_table, rare_bonus, description, bonus_chance, loot_category, loot_categories, active)
select x.site_id, x.region_id, x.site_name, x.site_type, x.bonus_item, x.loot_table, x.rare_bonus, x.description, x.bonus_chance, x.loot_category, array(select jsonb_array_elements_text(x.loot_categories)), true from jsonb_to_recordset($J$[{"site_id":"ash_reeds_s1","region_id":"ash_reeds","site_name":"잿빛 갈대숲 · 떠내려온 짐","site_type":"supply","bonus_item":"herb","loot_table":["herb","travel_ration","tonic","river_reed","reed_silk","wood","resin"],"rare_bonus":{"items":["reed_silk","yoin_blood","banyo_scale"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"탐사와 제작에 필요한 물자가 남아 있는 곳이다.","bonus_chance":18,"loot_category":"materials","loot_categories":["supply","craft_material"]},{"site_id":"ash_reeds_s2","region_id":"ash_reeds","site_name":"잿빛 갈대숲 · 물가 약막","site_type":"medical","bonus_item":"herb","loot_table":["herb","medicine_base","tonic","moon_moss","herbal_extract"],"rare_bonus":{"items":["banyo_salve","herbal_extract","reed_silk"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"약과 고약을 찾을 수 있는 곳이다.","bonus_chance":18,"loot_category":"recovery","loot_categories":["healing","medical_material"]},{"site_id":"ash_reeds_s3","region_id":"ash_reeds","site_name":"잿빛 갈대숲 · 이름 말뚝","site_type":"relic","bonus_item":"seal_paper","loot_table":["seal_paper","ghost_ash","reed_silk","ward_fragment"],"rare_bonus":{"items":["yoin_blood","reed_silk","spirit_core"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"옛 기록과 봉인 재료가 남은 곳이다.","bonus_chance":18,"loot_category":"relics","loot_categories":["clue","seal_material","rare_material"]},{"site_id":"inverted_shrine_s1","region_id":"inverted_shrine","site_name":"거꾸로 선 사당 · 뒤집힌 장경각","site_type":"relic","bonus_item":"seal_paper","loot_table":["seal_paper","inkstone","talisman_thread","inverted_incense","ward_fragment"],"rare_bonus":{"items":["inverted_incense","rune_plate","spirit_core"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"옛 기록과 봉인 재료가 남은 곳이다.","bonus_chance":18,"loot_category":"relics","loot_categories":["clue","seal_material","rare_material"]},{"site_id":"inverted_shrine_s2","region_id":"inverted_shrine","site_name":"거꾸로 선 사당 · 약사전","site_type":"medical","bonus_item":"herb","loot_table":["herb","medicine_base","tonic","herbal_extract"],"rare_bonus":{"items":["banyo_salve","inverted_incense","medicine_base"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"약과 고약을 찾을 수 있는 곳이다.","bonus_chance":18,"loot_category":"recovery","loot_categories":["healing","medical_material"]},{"site_id":"inverted_shrine_s3","region_id":"inverted_shrine","site_name":"거꾸로 선 사당 · 공양간 광","site_type":"supply","bonus_item":"herb","loot_table":["herb","travel_ration","tonic","wood","inverted_incense"],"rare_bonus":{"items":["yoin_blood","banyo_scale","inverted_incense"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"탐사와 제작에 필요한 물자가 남아 있는 곳이다.","bonus_chance":18,"loot_category":"materials","loot_categories":["supply","craft_material"]},{"site_id":"moonless_market_s1","region_id":"moonless_market","site_name":"달 없는 저잣거리 · 빈 객주 광","site_type":"supply","bonus_item":"herb","loot_table":["herb","travel_ration","tonic","moonless_silk","silk"],"rare_bonus":{"items":["moonless_silk","yoin_blood","banyo_scale"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"탐사와 제작에 필요한 물자가 남아 있는 곳이다.","bonus_chance":18,"loot_category":"materials","loot_categories":["supply","craft_material"]},{"site_id":"moonless_market_s2","region_id":"moonless_market","site_name":"달 없는 저잣거리 · 지운 장부 창고","site_type":"relic","bonus_item":"seal_paper","loot_table":["seal_paper","inkstone","oblivion_crystal","ward_fragment"],"rare_bonus":{"items":["oblivion_crystal","spirit_core","yoin_blood"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"옛 기록과 봉인 재료가 남은 곳이다.","bonus_chance":18,"loot_category":"relics","loot_categories":["clue","seal_material","rare_material"]},{"site_id":"moonless_market_s3","region_id":"moonless_market","site_name":"달 없는 저잣거리 · 문 닫힌 약방","site_type":"medical","bonus_item":"herb","loot_table":["herb","medicine_base","tonic","herbal_extract"],"rare_bonus":{"items":["banyo_salve","oblivion_incense","herbal_extract"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"약과 고약을 찾을 수 있는 곳이다.","bonus_chance":18,"loot_category":"recovery","loot_categories":["healing","medical_material"]},{"site_id":"gwiheo_core_s1","region_id":"gwiheo_core","site_name":"귀허 · 가라앉은 배","site_type":"abyss","bonus_item":"gwiheo_iron","loot_table":["gwiheo_iron","drowned_scale","ward_fragment","spirit_dust","travel_ration"],"rare_bonus":{"items":["gwiheo_iron","yoin_blood","gwiheo_pearl"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"섬 깊은 곳의 희귀한 재료가 가라앉아 있는 곳이다.","bonus_chance":18,"loot_category":"materials","loot_categories":["rare_material","craft_material"]},{"site_id":"gwiheo_core_s2","region_id":"gwiheo_core","site_name":"귀허 · 무너진 해신당","site_type":"relic","bonus_item":"seal_paper","loot_table":["seal_paper","ward_fragment","gwiheo_iron","ghost_ash"],"rare_bonus":{"items":["gwiheo_pearl","spirit_core","yoin_blood"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"옛 기록과 봉인 재료가 남은 곳이다.","bonus_chance":18,"loot_category":"relics","loot_categories":["clue","seal_material","rare_material"]},{"site_id":"gwiheo_core_s3","region_id":"gwiheo_core","site_name":"귀허 · 마지막 배웅터","site_type":"medical","bonus_item":"herb","loot_table":["herb","medicine_base","tonic","banyo_salve"],"rare_bonus":{"items":["banyo_salve","oblivion_incense","revival_charm"],"chance":0.2,"remote_bonus":true,"distance_from_headquarters":520},"description":"약과 고약을 찾을 수 있는 곳이다.","bonus_chance":18,"loot_category":"recovery","loot_categories":["healing","medical_material"]}]$J$::jsonb) as x(site_id text, region_id text, site_name text, site_type text, bonus_item text, loot_table jsonb, rare_bonus jsonb, description text, bonus_chance int, loot_category text, loot_categories jsonb, active boolean)
on conflict (site_id) do update set site_name = excluded.site_name, loot_table = excluded.loot_table, rare_bonus = excluded.rare_bonus, active = excluded.active;
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, tradeable, reference_price, stack_size)
select x.item_id, x.item_name, x.category, x.tier, x.description, x.stackable, x.required_stats, x.minimum_level, x.rarity, x.acquisition_difficulty, x.drop_rate_modifier, x.equipment_traits, x.tradeable, x.reference_price, x.stack_size from jsonb_to_recordset($J$[{"item_id":"reed_silk","item_name":"갈대 영사","category":"material","tier":4,"description":"잿빛 갈대 속에서 뽑은 실. 요기를 머금어도 끊어지지 않는다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"epic","acquisition_difficulty":4,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":380,"stack_size":5},{"item_id":"inverted_incense","item_name":"거꾸로 향목","category":"material","tier":4,"description":"아래로 타는 향의 나무. 결이 위아래로 뒤집혀 있다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"epic","acquisition_difficulty":4,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":380,"stack_size":5},{"item_id":"oblivion_crystal","item_name":"망각 수정","category":"material","tier":4,"description":"팔린 기억이 굳은 수정. 들여다보면 낯선 얼굴이 비친다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"epic","acquisition_difficulty":4,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":420,"stack_size":5},{"item_id":"moonless_silk","item_name":"무월 비단","category":"material","tier":4,"description":"달빛 없이 짠 비단. 빛을 머금지 않아 밤에 몸을 숨기기 좋다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"epic","acquisition_difficulty":4,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":400,"stack_size":5},{"item_id":"gwiheo_iron","item_name":"귀허 흑철","category":"material","tier":4,"description":"소용돌이 밑바닥에서 건진 검은 쇠. 물에 녹지 않는다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"epic","acquisition_difficulty":4,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":480,"stack_size":5},{"item_id":"banyo_scale","item_name":"반요 비늘","category":"material","tier":3,"description":"반요가 된 요괴에게서 떨어진 비늘. 사람 살갗의 결이 남아 있다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"rare","acquisition_difficulty":3,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":300,"stack_size":10},{"item_id":"yoin_blood","item_name":"요인 혈정","category":"material","tier":4,"description":"요화된 이의 피가 굳은 붉은 결정. 6단계 장비의 심이 된다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"epic","acquisition_difficulty":4,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":520,"stack_size":5},{"item_id":"gwiheo_pearl","item_name":"귀허 진주","category":"material","tier":5,"description":"귀허의 문지기가 품은 검은 진주. 돌아오지 못한 이의 마지막 빛이 담겼다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"legendary","acquisition_difficulty":5,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":true,"reference_price":900,"stack_size":5},{"item_id":"gwiheo_charm","item_name":"귀허 부적","category":"consumable","tier":4,"description":"귀허의 주인 앞에 서려면 하나씩 지녀야 하는 부적. 반요촌에서만 판다.","stackable":true,"required_stats":{},"minimum_level":38,"rarity":"epic","acquisition_difficulty":4,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":false,"reference_price":800,"stack_size":5},{"item_id":"banyo_salve","item_name":"반요 고약","category":"consumable","tier":3,"description":"반요촌에서 비늘 상처에 바르는 고약. 체력 +70, 정신 +15, 출혈·화상·중독을 푼다.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"rare","acquisition_difficulty":3,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":false,"reference_price":120,"stack_size":5},{"item_id":"oblivion_incense","item_name":"망각 향","category":"consumable","tier":3,"description":"나쁜 기억을 잠시 잊게 하는 향. 침식 −30, 정신 +20.","stackable":true,"required_stats":{},"minimum_level":30,"rarity":"rare","acquisition_difficulty":3,"drop_rate_modifier":1,"equipment_traits":{},"tradeable":false,"reference_price":150,"stack_size":5},{"item_id":"w_melee6_base","item_name":"귀허 참월도","category":"weapon","tier":6,"description":"귀허 흑철을 두드려 벼린 달 모양 칼. 고르게 강하다.","stackable":false,"required_stats":{"strength":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"power":48,"trait":"근접","weapon_type":"melee","combat_damage_pct":18},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_melee6_heavy","item_name":"소용돌이 철퇴","category":"weapon","tier":6,"description":"휘두를 때마다 물살 소리가 난다. 위력이 높지만 노려지기 쉽다.","stackable":false,"required_stats":{"strength":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"power":57,"trait":"근접","presence":36,"weapon_type":"melee"},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_melee6_keen","item_name":"이름 베는 검","category":"weapon","tier":6,"description":"날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.","stackable":false,"required_stats":{"strength":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"power":43,"trait":"근접","crit_pct":18,"weapon_type":"melee"},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_melee6_silent","item_name":"무월 귀도","category":"weapon","tier":6,"description":"달빛 없는 밤처럼 소리가 없다. 몸놀림도 가벼워진다.","stackable":false,"required_stats":{"strength":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"power":45,"trait":"근접","presence":-36,"evasion_pct":9,"weapon_type":"melee"},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_ranged6_base","item_name":"갈대 영궁","category":"weapon","tier":6,"description":"갈대 영사로 시위를 맨 활. 고르게 강하다.","stackable":false,"required_stats":{"agility":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"ammo":"ammo_arrow","power":48,"trait":"원거리","weapon_type":"ranged","combat_damage_pct":18},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_ranged6_heavy","item_name":"해신 쇠뇌","category":"weapon","tier":6,"description":"해신당 대들보로 짠 쇠뇌. 위력이 높지만 노려지기 쉽다.","stackable":false,"required_stats":{"agility":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"ammo":"ammo_bolt","power":57,"trait":"원거리","presence":36,"weapon_type":"ranged"},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_ranged6_keen","item_name":"백로 깃 신궁","category":"weapon","tier":6,"description":"잿빛 백로 깃을 단 활. 치명타가 잘 터진다.","stackable":false,"required_stats":{"agility":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"ammo":"ammo_arrow","power":43,"trait":"원거리","crit_pct":18,"weapon_type":"ranged"},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_ranged6_silent","item_name":"숨 죽인 취관","category":"weapon","tier":6,"description":"갈대 마디로 만든 취관. 소리 없이 쏜다.","stackable":false,"required_stats":{"agility":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"ammo":"ammo_dart","power":45,"trait":"원거리","presence":-36,"evasion_pct":9,"weapon_type":"ranged"},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_magic6_base","item_name":"거꾸로 법륜","category":"weapon","tier":6,"description":"거꾸로 도는 법륜. 고르게 강하다.","stackable":false,"required_stats":{"spirit_affinity":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"power":48,"trait":"술법","weapon_type":"magic","combat_damage_pct":18},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_magic6_heavy","item_name":"귀허 범종","category":"weapon","tier":6,"description":"귀허에서 건진 작은 범종. 위력이 높지만 노려지기 쉽다.","stackable":false,"required_stats":{"spirit_affinity":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"power":57,"trait":"술법","presence":36,"weapon_type":"magic"},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_magic6_keen","item_name":"망각 수정 부채","category":"weapon","tier":6,"description":"망각 수정을 박은 부채. 치명타가 잘 터진다.","stackable":false,"required_stats":{"spirit_affinity":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"power":43,"trait":"술법","crit_pct":18,"weapon_type":"magic"},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"w_magic6_silent","item_name":"꺼진 등롱 법등","category":"weapon","tier":6,"description":"불 없이 밝히는 법등. 요괴의 눈에 덜 띈다.","stackable":false,"required_stats":{"spirit_affinity":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"power":45,"trait":"술법","presence":-36,"evasion_pct":9,"weapon_type":"magic"},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"a6_iron","item_name":"흑철 비늘갑","category":"armor","tier":6,"description":"귀허 흑철과 반요 비늘을 엮은 갑옷. 단단하지만 요괴의 이목을 끈다.","stackable":false,"required_stats":{"vitality":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"방호","defense":44,"presence":48,"evasion_pct":-6},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"a6_light","item_name":"갈대 영사 경갑","category":"armor","tier":6,"description":"갈대 영사로 누빈 가벼운 갑옷. 몸을 틀어 피하기 좋다.","stackable":false,"required_stats":{"agility":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"방호","defense":27,"evasion_pct":9},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"a6_robe","item_name":"거꾸로 법의","category":"armor","tier":6,"description":"거꾸로 수놓은 법의. 받는 피해를 덜고 요기를 막는다.","stackable":false,"required_stats":{"willpower":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"방호","defense":22,"erosion_pct":-18,"damage_reduction_pct":12},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"a6_shade","item_name":"무월 야행의","category":"armor","tier":6,"description":"달 없는 밤의 비단옷. 요괴의 눈을 피하고 빈틈을 노린다.","stackable":false,"required_stats":{"agility":38},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"방호","defense":19,"crit_pct":6,"presence":-48,"evasion_pct":6},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"h6_calm","item_name":"망각 관모","category":"hat","tier":6,"description":"나쁜 기억을 덮어 주는 관모. 요기와 두려움을 막는다.","stackable":false,"required_stats":{"willpower":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"관모","erosion_pct":-24,"mental_loss_pct":-36},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"h6_guard","item_name":"흑철 투구","category":"hat","tier":6,"description":"귀허 흑철로 두드린 투구. 앞장서는 이에게 어울린다.","stackable":false,"required_stats":{"vitality":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"관모","defense":12,"presence":30},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"h6_wise","item_name":"거꾸로 익선관","category":"hat","tier":6,"description":"거꾸로 읽어야 보이는 글이 새겨진 관. 단서가 잘 보이고 급소를 읽는다.","stackable":false,"required_stats":{"perception":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"관모","crit_pct":6,"clue_bonus_pct":24},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"s6_road","item_name":"갈대 짚신","category":"shoes","tier":6,"description":"갈대 영사로 삼은 신. 먼 길을 덜 지치게 걷는다.","stackable":false,"required_stats":{"vitality":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"신","travel_time_pct":-24},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"s6_sturdy","item_name":"흑철 장화","category":"shoes","tier":6,"description":"땅을 굳게 딛는 흑철 장화.","stackable":false,"required_stats":{"vitality":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"신","defense":9,"presence":24},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"s6_swift","item_name":"무월 비단신","category":"shoes","tier":6,"description":"발소리가 나지 않는 비단신. 피하고 달아나기 좋다.","stackable":false,"required_stats":{"agility":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"신","flee_pct":18,"evasion_pct":9},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"n6_keen","item_name":"사슬 장도 노리개","category":"norigae","tier":6,"description":"흰 사슬 한 마디를 단 장도 노리개. 급소를 노리는 눈이 밝아진다.","stackable":false,"required_stats":{"perception":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"노리개","crit_pct":12},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"n6_luck","item_name":"귀허 진주 노리개","category":"norigae","tier":6,"description":"검은 진주를 꿴 노리개. 귀한 전리품이 잘 나온다.","stackable":false,"required_stats":{"spirit_affinity":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"노리개","rare_loot_pct":18},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"n6_plenty","item_name":"반요촌 풍년 노리개","category":"norigae","tier":6,"description":"반요촌 아낙들이 엮는 노리개. 거두는 양과 솜씨가 는다.","stackable":false,"required_stats":{"vitality":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"노리개","craft_quality":6,"gather_qty_pct":18},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"m6_purify","item_name":"거꾸로 향낭","category":"amulet","tier":6,"description":"거꾸로 향목을 넣은 향낭. 침식이 덜하고 회복이 잘 된다.","stackable":false,"required_stats":{"willpower":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"호신부","erosion_pct":-18,"healing_pct":18},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"m6_spell","item_name":"망각 부적낭","category":"amulet","tier":6,"description":"망각 수정 가루로 그린 부적을 품는다. 술법이 세진다.","stackable":false,"required_stats":{"spirit_affinity":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"호신부","magic_pct":18},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"m6_ward","item_name":"귀허 문지기 호패","category":"amulet","tier":6,"description":"문지기의 거울 조각을 댄 호패. 받는 피해가 줄고 요괴가 먼저 노린다.","stackable":false,"required_stats":{"willpower":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"호신부","presence":24,"incoming_damage_pct":-12},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"k6_awe","item_name":"반요 탈","category":"mask","tier":6,"description":"비늘 돋은 얼굴을 본뜬 탈. 요괴가 먼저 덤비지만 기세가 오른다.","stackable":false,"required_stats":{"strength":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"탈","presence":60,"combat_damage_pct":9},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"k6_ghost","item_name":"사공 탈","category":"mask","tier":6,"description":"이름 잃은 사공의 얼굴. 요괴를 불러들이고 귀한 것을 끌어낸다.","stackable":false,"required_stats":{"spirit_affinity":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"탈","encounter_pct":18,"rare_loot_pct":12},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"k6_hide","item_name":"얼굴 지운 탈","category":"mask","tier":6,"description":"저잣거리 손님의 얼굴 없는 탈. 요괴의 눈에 덜 띄고 덜 마주친다.","stackable":false,"required_stats":{"agility":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"탈","presence":-60,"encounter_pct":-18},"tradeable":true,"reference_price":0,"stack_size":1},{"item_id":"t6_gather","item_name":"귀허 흑철 채집도","category":"tool","tier":6,"description":"물에 녹지 않는 흑철 날. 채집할 때 더 많이 거둔다.","stackable":false,"required_stats":{"perception":28},"minimum_level":32,"rarity":"legendary","acquisition_difficulty":6,"drop_rate_modifier":0.05,"equipment_traits":{"trait":"정밀 채집","rare_loot_pct":7,"gathering_bonus_pct":26},"tradeable":true,"reference_price":0,"stack_size":1}]$J$::jsonb) as x(item_id text, item_name text, category text, tier int, description text, stackable boolean, required_stats jsonb, minimum_level int, rarity text, acquisition_difficulty int, drop_rate_modifier numeric, equipment_traits jsonb, tradeable boolean, reference_price bigint, stack_size int)
on conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, required_stats = excluded.required_stats, equipment_traits = excluded.equipment_traits, minimum_level = excluded.minimum_level, stack_size = excluded.stack_size, tradeable = excluded.tradeable, reference_price = excluded.reference_price;
insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool_tier, required_location, description, minimum_level, recipe_difficulty, quality_bonus, required_skill_rank, craft_field)
select x.recipe_id, x.recipe_name, x.output_item, 1, x.ingredients, 1, '반요촌', x.description, 32, 6, 0, 1, x.craft_field from jsonb_to_recordset($J$[{"recipe_id":"r_w_melee6_base","recipe_name":"귀허 참월도 만들기","output_item":"w_melee6_base","ingredients":{"gwiheo_iron":5,"yoin_blood":3,"steel_ingot":4,"banyo_scale":3},"description":"귀허 참월도을(를) 만든다.","craft_field":"smithing"},{"recipe_id":"r_w_melee6_heavy","recipe_name":"소용돌이 철퇴 만들기","output_item":"w_melee6_heavy","ingredients":{"gwiheo_iron":6,"yoin_blood":3,"steel_ingot":4,"monster_core":2},"description":"소용돌이 철퇴을(를) 만든다.","craft_field":"smithing"},{"recipe_id":"r_w_melee6_keen","recipe_name":"이름 베는 검 만들기","output_item":"w_melee6_keen","ingredients":{"gwiheo_iron":5,"yoin_blood":3,"oblivion_crystal":2,"steel_ingot":3},"description":"이름 베는 검을(를) 만든다.","craft_field":"smithing"},{"recipe_id":"r_w_melee6_silent","recipe_name":"무월 귀도 만들기","output_item":"w_melee6_silent","ingredients":{"gwiheo_iron":5,"yoin_blood":3,"moonless_silk":3,"steel_ingot":3},"description":"무월 귀도을(를) 만든다.","craft_field":"smithing"},{"recipe_id":"r_w_ranged6_base","recipe_name":"갈대 영궁 만들기","output_item":"w_ranged6_base","ingredients":{"reed_silk":5,"inverted_incense":3,"yoin_blood":3,"sky_feather":4},"description":"갈대 영궁을(를) 만든다.","craft_field":"carpentry"},{"recipe_id":"r_w_ranged6_heavy","recipe_name":"해신 쇠뇌 만들기","output_item":"w_ranged6_heavy","ingredients":{"inverted_incense":4,"gwiheo_iron":3,"yoin_blood":3,"reed_silk":3},"description":"해신 쇠뇌을(를) 만든다.","craft_field":"carpentry"},{"recipe_id":"r_w_ranged6_keen","recipe_name":"백로 깃 신궁 만들기","output_item":"w_ranged6_keen","ingredients":{"reed_silk":5,"yoin_blood":3,"sky_feather":5,"oblivion_crystal":2},"description":"백로 깃 신궁을(를) 만든다.","craft_field":"carpentry"},{"recipe_id":"r_w_ranged6_silent","recipe_name":"숨 죽인 취관 만들기","output_item":"w_ranged6_silent","ingredients":{"reed_silk":5,"moonless_silk":3,"yoin_blood":3,"shadow_fang":3},"description":"숨 죽인 취관을(를) 만든다.","craft_field":"carpentry"},{"recipe_id":"r_w_magic6_base","recipe_name":"거꾸로 법륜 만들기","output_item":"w_magic6_base","ingredients":{"inverted_incense":5,"oblivion_crystal":3,"yoin_blood":3,"rune_plate":3},"description":"거꾸로 법륜을(를) 만든다.","craft_field":"artifice"},{"recipe_id":"r_w_magic6_heavy","recipe_name":"귀허 범종 만들기","output_item":"w_magic6_heavy","ingredients":{"gwiheo_iron":4,"inverted_incense":3,"yoin_blood":3,"rune_plate":3},"description":"귀허 범종을(를) 만든다.","craft_field":"artifice"},{"recipe_id":"r_w_magic6_keen","recipe_name":"망각 수정 부채 만들기","output_item":"w_magic6_keen","ingredients":{"oblivion_crystal":5,"moonless_silk":2,"yoin_blood":3,"mirror_shard":3},"description":"망각 수정 부채을(를) 만든다.","craft_field":"artifice"},{"recipe_id":"r_w_magic6_silent","recipe_name":"꺼진 등롱 법등 만들기","output_item":"w_magic6_silent","ingredients":{"oblivion_crystal":4,"moonless_silk":3,"yoin_blood":3,"spirit_core":2},"description":"꺼진 등롱 법등을(를) 만든다.","craft_field":"artifice"},{"recipe_id":"r_a6_iron","recipe_name":"흑철 비늘갑 만들기","output_item":"a6_iron","ingredients":{"gwiheo_iron":5,"banyo_scale":5,"yoin_blood":3,"steel_ingot":3},"description":"흑철 비늘갑을(를) 만든다.","craft_field":"smithing"},{"recipe_id":"r_a6_light","recipe_name":"갈대 영사 경갑 만들기","output_item":"a6_light","ingredients":{"reed_silk":5,"banyo_scale":4,"yoin_blood":3,"reinforced_leather":3},"description":"갈대 영사 경갑을(를) 만든다.","craft_field":"leatherwork"},{"recipe_id":"r_a6_robe","recipe_name":"거꾸로 법의 만들기","output_item":"a6_robe","ingredients":{"inverted_incense":4,"moonless_silk":3,"yoin_blood":3,"spirit_thread":3},"description":"거꾸로 법의을(를) 만든다.","craft_field":"weaving"},{"recipe_id":"r_a6_shade","recipe_name":"무월 야행의 만들기","output_item":"a6_shade","ingredients":{"moonless_silk":5,"banyo_scale":4,"yoin_blood":3,"shadow_fang":3},"description":"무월 야행의을(를) 만든다.","craft_field":"leatherwork"},{"recipe_id":"r_h6_calm","recipe_name":"망각 관모 만들기","output_item":"h6_calm","ingredients":{"oblivion_crystal":3,"moonless_silk":3,"yoin_blood":2},"description":"망각 관모을(를) 만든다.","craft_field":"weaving"},{"recipe_id":"r_h6_guard","recipe_name":"흑철 투구 만들기","output_item":"h6_guard","ingredients":{"gwiheo_iron":4,"banyo_scale":3,"yoin_blood":2},"description":"흑철 투구을(를) 만든다.","craft_field":"smithing"},{"recipe_id":"r_h6_wise","recipe_name":"거꾸로 익선관 만들기","output_item":"h6_wise","ingredients":{"inverted_incense":3,"reed_silk":3,"yoin_blood":2},"description":"거꾸로 익선관을(를) 만든다.","craft_field":"weaving"},{"recipe_id":"r_s6_road","recipe_name":"갈대 짚신 만들기","output_item":"s6_road","ingredients":{"reed_silk":4,"banyo_scale":3,"yoin_blood":2},"description":"갈대 짚신을(를) 만든다.","craft_field":"leatherwork"},{"recipe_id":"r_s6_sturdy","recipe_name":"흑철 장화 만들기","output_item":"s6_sturdy","ingredients":{"gwiheo_iron":3,"banyo_scale":4,"yoin_blood":2},"description":"흑철 장화을(를) 만든다.","craft_field":"leatherwork"},{"recipe_id":"r_s6_swift","recipe_name":"무월 비단신 만들기","output_item":"s6_swift","ingredients":{"moonless_silk":4,"banyo_scale":3,"yoin_blood":2},"description":"무월 비단신을(를) 만든다.","craft_field":"leatherwork"},{"recipe_id":"r_n6_keen","recipe_name":"사슬 장도 노리개 만들기","output_item":"n6_keen","ingredients":{"gwiheo_iron":2,"reed_silk":3,"yoin_blood":2},"description":"사슬 장도 노리개을(를) 만든다.","craft_field":"weaving"},{"recipe_id":"r_n6_luck","recipe_name":"귀허 진주 노리개 만들기","output_item":"n6_luck","ingredients":{"gwiheo_pearl":1,"reed_silk":3,"yoin_blood":2},"description":"귀허 진주 노리개을(를) 만든다.","craft_field":"weaving"},{"recipe_id":"r_n6_plenty","recipe_name":"반요촌 풍년 노리개 만들기","output_item":"n6_plenty","ingredients":{"reed_silk":4,"banyo_scale":3,"yoin_blood":2},"description":"반요촌 풍년 노리개을(를) 만든다.","craft_field":"weaving"},{"recipe_id":"r_m6_purify","recipe_name":"거꾸로 향낭 만들기","output_item":"m6_purify","ingredients":{"inverted_incense":4,"moonless_silk":2,"yoin_blood":2},"description":"거꾸로 향낭을(를) 만든다.","craft_field":"sealing"},{"recipe_id":"r_m6_spell","recipe_name":"망각 부적낭 만들기","output_item":"m6_spell","ingredients":{"oblivion_crystal":3,"inverted_incense":2,"yoin_blood":2},"description":"망각 부적낭을(를) 만든다.","craft_field":"sealing"},{"recipe_id":"r_m6_ward","recipe_name":"귀허 문지기 호패 만들기","output_item":"m6_ward","ingredients":{"gwiheo_iron":3,"mirror_shard":2,"yoin_blood":2},"description":"귀허 문지기 호패을(를) 만든다.","craft_field":"sealing"},{"recipe_id":"r_k6_awe","recipe_name":"반요 탈 만들기","output_item":"k6_awe","ingredients":{"banyo_scale":5,"yoin_blood":2,"inverted_incense":2},"description":"반요 탈을(를) 만든다.","craft_field":"sealing"},{"recipe_id":"r_k6_ghost","recipe_name":"사공 탈 만들기","output_item":"k6_ghost","ingredients":{"reed_silk":3,"ghost_ash":4,"yoin_blood":2},"description":"사공 탈을(를) 만든다.","craft_field":"sealing"},{"recipe_id":"r_k6_hide","recipe_name":"얼굴 지운 탈 만들기","output_item":"k6_hide","ingredients":{"moonless_silk":3,"shadow_fang":3,"yoin_blood":2},"description":"얼굴 지운 탈을(를) 만든다.","craft_field":"sealing"},{"recipe_id":"r_t6_gather","recipe_name":"귀허 흑철 채집도 만들기","output_item":"t6_gather","ingredients":{"gwiheo_iron":4,"oblivion_crystal":2,"yoin_blood":2},"description":"귀허 흑철 채집도을(를) 만든다.","craft_field":"smithing"}]$J$::jsonb) as x(recipe_id text, recipe_name text, output_item text, output_qty int, ingredients jsonb, required_tool_tier int, required_location text, description text, minimum_level int, recipe_difficulty int, quality_bonus int, required_skill_rank int, craft_field text)
on conflict (recipe_id) do update set ingredients = excluded.ingredients, craft_field = excluded.craft_field, required_location = excluded.required_location, minimum_level = excluded.minimum_level;
insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian)
select x.item_id, x.mechanic_key, 31, 40, x.chance_normal, x.chance_elite, 0.02 from jsonb_to_recordset($J$[{"item_id":"w_melee6_base","mechanic_key":"armored","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_melee6_base","mechanic_key":"swarm","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_melee6_base","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_melee6_heavy","mechanic_key":"armored","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_melee6_heavy","mechanic_key":"swarm","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_melee6_heavy","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_melee6_keen","mechanic_key":"armored","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_melee6_keen","mechanic_key":"swarm","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_melee6_keen","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_melee6_silent","mechanic_key":"armored","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_melee6_silent","mechanic_key":"swarm","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_melee6_silent","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_ranged6_base","mechanic_key":"aerial","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_ranged6_base","mechanic_key":"ambush","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_ranged6_base","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_ranged6_heavy","mechanic_key":"aerial","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_ranged6_heavy","mechanic_key":"ambush","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_ranged6_heavy","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_ranged6_keen","mechanic_key":"aerial","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_ranged6_keen","mechanic_key":"ambush","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_ranged6_keen","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_ranged6_silent","mechanic_key":"aerial","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_ranged6_silent","mechanic_key":"ambush","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_ranged6_silent","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_magic6_base","mechanic_key":"spectral","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_base","mechanic_key":"warded","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_base","mechanic_key":"seal_breaker","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_base","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_magic6_heavy","mechanic_key":"spectral","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_heavy","mechanic_key":"warded","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_heavy","mechanic_key":"seal_breaker","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_heavy","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_magic6_keen","mechanic_key":"spectral","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_keen","mechanic_key":"warded","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_keen","mechanic_key":"seal_breaker","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_keen","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"w_magic6_silent","mechanic_key":"spectral","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_silent","mechanic_key":"warded","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_silent","mechanic_key":"seal_breaker","chance_normal":0.001,"chance_elite":0.004},{"item_id":"w_magic6_silent","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"a6_iron","mechanic_key":"armored","chance_normal":0.001,"chance_elite":0.004},{"item_id":"a6_iron","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"a6_light","mechanic_key":"aerial","chance_normal":0.001,"chance_elite":0.004},{"item_id":"a6_light","mechanic_key":"swarm","chance_normal":0.001,"chance_elite":0.004},{"item_id":"a6_light","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"a6_robe","mechanic_key":"spectral","chance_normal":0.001,"chance_elite":0.004},{"item_id":"a6_robe","mechanic_key":"warded","chance_normal":0.001,"chance_elite":0.004},{"item_id":"a6_robe","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"a6_shade","mechanic_key":"ambush","chance_normal":0.001,"chance_elite":0.004},{"item_id":"a6_shade","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"h6_calm","mechanic_key":"spectral","chance_normal":0.001,"chance_elite":0.004},{"item_id":"h6_calm","mechanic_key":"seal_breaker","chance_normal":0.001,"chance_elite":0.004},{"item_id":"h6_calm","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"h6_guard","mechanic_key":"armored","chance_normal":0.001,"chance_elite":0.004},{"item_id":"h6_guard","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"h6_wise","mechanic_key":"warded","chance_normal":0.001,"chance_elite":0.004},{"item_id":"h6_wise","mechanic_key":"reflect","chance_normal":0.001,"chance_elite":0.004},{"item_id":"h6_wise","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"s6_road","mechanic_key":"swarm","chance_normal":0.001,"chance_elite":0.004},{"item_id":"s6_road","mechanic_key":"tide","chance_normal":0.001,"chance_elite":0.004},{"item_id":"s6_road","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"s6_sturdy","mechanic_key":"armored","chance_normal":0.001,"chance_elite":0.004},{"item_id":"s6_sturdy","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"s6_swift","mechanic_key":"aerial","chance_normal":0.001,"chance_elite":0.004},{"item_id":"s6_swift","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"n6_keen","mechanic_key":"ambush","chance_normal":0.001,"chance_elite":0.004},{"item_id":"n6_keen","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"n6_luck","mechanic_key":"tide","chance_normal":0.001,"chance_elite":0.004},{"item_id":"n6_luck","mechanic_key":"reflect","chance_normal":0.001,"chance_elite":0.004},{"item_id":"n6_luck","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"n6_plenty","mechanic_key":"toxic","chance_normal":0.001,"chance_elite":0.004},{"item_id":"n6_plenty","mechanic_key":"swarm","chance_normal":0.001,"chance_elite":0.004},{"item_id":"n6_plenty","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"m6_purify","mechanic_key":"toxic","chance_normal":0.001,"chance_elite":0.004},{"item_id":"m6_purify","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"m6_spell","mechanic_key":"spectral","chance_normal":0.001,"chance_elite":0.004},{"item_id":"m6_spell","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"m6_ward","mechanic_key":"seal_breaker","chance_normal":0.001,"chance_elite":0.004},{"item_id":"m6_ward","mechanic_key":"warded","chance_normal":0.001,"chance_elite":0.004},{"item_id":"m6_ward","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"k6_awe","mechanic_key":"armored","chance_normal":0.001,"chance_elite":0.004},{"item_id":"k6_awe","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"k6_ghost","mechanic_key":"spectral","chance_normal":0.001,"chance_elite":0.004},{"item_id":"k6_ghost","mechanic_key":"reflect","chance_normal":0.001,"chance_elite":0.004},{"item_id":"k6_ghost","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"k6_hide","mechanic_key":"ambush","chance_normal":0.001,"chance_elite":0.004},{"item_id":"k6_hide","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006},{"item_id":"t6_gather","mechanic_key":"toxic","chance_normal":0.001,"chance_elite":0.004},{"item_id":"t6_gather","mechanic_key":"swarm","chance_normal":0.001,"chance_elite":0.004},{"item_id":"t6_gather","mechanic_key":"boss","chance_normal":0,"chance_elite":0.006}]$J$::jsonb) as x(item_id text, mechanic_key text, level_min int, level_max int, chance_normal numeric, chance_elite numeric, chance_guardian numeric)
on conflict (item_id, mechanic_key) do nothing;
-- 6단계 기준 시세: 가장 싼 제작법 재료값 ×1.2와 같은 칸 5단계 가장 비싼 것 ×1.15 가운데 큰 값
update public.world_item_catalog i set reference_price = greatest(
    ceil(1.2 * (select sum(m.reference_price * (x.value)::int) from public.world_crafting_recipes cr, jsonb_each_text(cr.ingredients) x join public.world_item_catalog m on m.item_id = x.key where cr.output_item = i.item_id)),
    ceil(1.15 * (select max(f.reference_price) from public.world_item_catalog f where f.tier = 5 and f.category = i.category and f.item_id not like 'raid%' and f.item_id <> 'n5_lighthouse')))
 where i.tier = 6;
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select 'banyo_shop', x.item_id, case when x.price > 0 then x.price else (select i.reference_price * 3 from public.world_item_catalog i where i.item_id = x.item_id) end, 1, 1, x.cap
  from jsonb_to_recordset($J$[{"item_id":"gwiheo_charm","price":1200,"cap":4},{"item_id":"banyo_salve","price":360,"cap":6},{"item_id":"oblivion_incense","price":520,"cap":4},{"item_id":"tonic","price":210,"cap":10},{"item_id":"ward_talisman","price":260,"cap":8},{"item_id":"travel_ration","price":160,"cap":10},{"item_id":"repair_kit","price":0,"cap":3},{"item_id":"spirit_qi_pill","price":0,"cap":5},{"item_id":"revival_charm","price":1100,"cap":1},{"item_id":"ammo_arrow","price":0,"cap":200},{"item_id":"ammo_bolt","price":0,"cap":200},{"item_id":"ammo_dart","price":0,"cap":200}]$J$::jsonb) as x(item_id text, price bigint, cap int)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price, daily_cap = excluded.daily_cap;
insert into public.world_gathering_discoveries(owner_id, spot_id)
select c.owner_id, gs.spot_id from public.world_characters c
  cross join public.world_gathering_spots gs join public.world_exploration_nodes n on n.node_id = gs.node_id and n.hierarchy_level = 1 and n.region_id in
    ('banyo_village', 'ash_reeds', 'inverted_shrine', 'moonless_market', 'gwiheo_core')
on conflict do nothing;


-- ─────────────────────────────────────────────────────────────
-- B-2. 귀허도 규칙: 10장 전에는 가림 · 섬 침식 +60% · 섬에서는 요화가 다음 단계로 가지 않음 · 반요촌(빈약한 안전지대)
-- ─────────────────────────────────────────────────────────────
create or replace function pg_temp.yh_patch_re(p_fn text, p_re text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  select count(*) into k from regexp_matches(d, p_re, 'g');
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름(정규식): % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute regexp_replace(d, p_re, p_new, 'g');
end $$;

-- 섬이 열렸는가(10장 「구중 봉연」을 마침, 운영진은 시험을 위해 늘 열림)
create or replace function public.world_gwiheo_open(p_uid uuid) returns boolean
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select p_uid is not null and (public.world_quest_chapter_done(p_uid, 'nine_gates') or exists (select 1 from public.world_staff s where s.owner_id = p_uid))
$$;
-- 지금 섬에 있는가 · 반요촌에 있는가
create or replace function public.world_on_island(p_uid uuid) returns boolean
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select (public.world_region_at(c.location)).territory_id = 'gwiheo' from public.world_characters c where c.owner_id = p_uid), false)
$$;
create or replace function public.world_banyo_here(p_uid uuid) returns boolean
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select (public.world_region_at(c.location)).region_id = 'banyo_village' from public.world_characters c where c.owner_id = p_uid), false)
$$;
-- 섬 효과: 침식 보정 +60%(world_status_effect_total에 더함)
create or replace function public.world_island_effect(p_key text) returns numeric
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if p_key is distinct from 'erosion_pct' then return 0; end if;
  return case when public.world_on_island(public.fn_owner_auth_uid()) then 60 else 0 end;
end $$;
-- 반요촌 대장간 수리비 ×3
create or replace function public.world_repair_mult(p_uid uuid) returns int
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when public.world_banyo_here(p_uid) then 3 else 1 end
$$;
do $$ declare f text; begin
  foreach f in array array['world_gwiheo_open(uuid)', 'world_on_island(uuid)', 'world_banyo_here(uuid)', 'world_island_effect(text)', 'world_repair_mult(uuid)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
-- 도우미는 화면이 직접 부르지 않지만, 부른 쪽 권한으로 도는 함수(지도·상태 효과 합계)와 여러 함수 주인 역할이 쓴다
do $$ declare r text; f text; begin
  foreach f in array array['world_gwiheo_open(uuid)', 'world_on_island(uuid)', 'world_banyo_here(uuid)', 'world_island_effect(text)', 'world_repair_mult(uuid)'] loop
    for r in select rolname from pg_roles where rolname like 'fn_owner%' loop execute format('grant execute on function public.%s to %I', f, r); end loop;
  end loop;
end $$;
grant execute on function public.world_island_effect(text) to authenticated;
grant execute on function public.world_gwiheo_open(uuid) to authenticated;
grant execute on function public.world_on_island(uuid) to authenticated;
select pg_temp.yh_patch('public.world_status_effect_total(text)', '+ public.world_job_effect(p_effect_key)', '+ public.world_job_effect(p_effect_key) + public.world_island_effect(p_effect_key)');

-- 지도: 10장을 마치기 전에는 섬 지역과 그리로 가는 길을 내주지 않는다
select pg_temp.yh_patch('public.world_map_snapshot()', 'from public.world_map_regions r where r.active;',
  'from public.world_map_regions r where r.active and (r.territory_id is distinct from ''gwiheo'' or public.world_gwiheo_open(uid));');
select pg_temp.yh_patch('public.world_map_snapshot()', '''travel_from'',r.travel_from,',
  '''travel_from'',case when public.world_gwiheo_open(uid) then r.travel_from else array(select x from unnest(r.travel_from) x where x not in (''banyo_village'',''ash_reeds'',''inverted_shrine'',''moonless_market'',''gwiheo_core'')) end,');
-- 이동: 섬은 10장을 마친 조사원만
select pg_temp.yh_patch('public.world_travel_route(text)', 'IF dest.region_id IS NULL THEN RAISE EXCEPTION ''지도에 없는 지역입니다.''; END IF;',
  'IF dest.region_id IS NULL OR (dest.territory_id = ''gwiheo'' AND NOT public.world_gwiheo_open(uid)) THEN RAISE EXCEPTION ''지도에 없는 지역입니다.''; END IF;');
select pg_temp.yh_patch('public.world_travel_region(text)', 'where mr.region_id=p_region_id and mr.active; if not found then',
  'where mr.region_id=p_region_id and mr.active and (mr.territory_id is distinct from ''gwiheo'' or public.world_gwiheo_open(uid)); if not found then');
select pg_temp.yh_patch('public.world_travel_party_invite_v2(uuid,text)', 'IF c.level < r.min_level OR p.level < r.min_level THEN',
  'IF r.territory_id = ''gwiheo'' AND NOT (public.world_gwiheo_open(uid) AND public.world_gwiheo_open(p_passenger_id)) THEN
    RAISE EXCEPTION ''귀허도는 10장 「구중 봉연」을 마친 조사원만 건너갈 수 있습니다.'';
  END IF;
  IF c.level < r.min_level OR p.level < r.min_level THEN');
select pg_temp.yh_patch('public.world_travel_party_respond_v2(uuid,boolean)', ' dx:=(r.world_x-oldr.world_x)::numeric;',
  ' if r.territory_id=''gwiheo'' and not (public.world_gwiheo_open(q.leader_id) and public.world_gwiheo_open(uid))
   then raise exception ''귀허도는 10장 「구중 봉연」을 마친 조사원만 건너갈 수 있습니다.''; end if;
 dx:=(r.world_x-oldr.world_x)::numeric;');
-- 서버 보스 「봉연의 그림자」는 섬에 나오지 않는다
select pg_temp.yh_patch('public.world_raid_schedule_next()', 'where active and not coalesce(is_safe_zone, false) and coalesce(min_level, 1) between lo and hi',
  'where active and not coalesce(is_safe_zone, false) and territory_id is distinct from ''gwiheo'' and coalesce(min_level, 1) between lo and hi');
select pg_temp.yh_patch('public.world_raid_schedule_next()', 'where active and not coalesce(is_safe_zone, false) order by random() limit 3',
  'where active and not coalesce(is_safe_zone, false) and territory_id is distinct from ''gwiheo'' order by random() limit 3');

-- 요화: 섬에 있는 동안은 다음 단계로 넘어가지 않는다(10분 뒤 다시 본다)
select pg_temp.yh_patch_re('public.world_yohwa_tick()', 'n := n \+ 1;\s*if s\.potency < 3 then',
  'n := n + 1; if public.world_on_island(s.owner_id) then update public.world_character_statuses set expires_at = now() + interval ''10 minutes'' where status_id = s.status_id; continue; end if; if s.potency < 3 then');

-- 토벌 희귀 전리품: 섬에서는 반요 비늘
select pg_temp.yh_patch('public.world_event_char_apply()', 'rare := case when p ->> ''region_id'' = ''sealed_abyss'' then ''spirit_core'' else',
  'rare := case when p ->> ''region_id'' = ''sealed_abyss'' then ''spirit_core'' when p ->> ''region_id'' in (''ash_reeds'', ''inverted_shrine'', ''moonless_market'', ''gwiheo_core'') then ''banyo_scale'' else');

-- 새 소모품: 반요 고약·망각 향
select pg_temp.yh_patch('public.world_use_item(text)', '''exp_elixir_clear'') THEN RAISE EXCEPTION ''쓸 수 없는 물품입니다.''; END IF;',
  '''exp_elixir_clear'', ''banyo_salve'', ''oblivion_incense'') THEN RAISE EXCEPTION ''쓸 수 없는 물품입니다.''; END IF;');
select pg_temp.yh_patch('public.world_use_item(text)', 'THEN buffs := ARRAY[''st_clear_mind''];',
  'THEN buffs := ARRAY[''st_clear_mind'']; WHEN ''banyo_salve'' THEN hp := 70; mn := 15; cures := ARRAY[''bleeding'', ''burned'', ''poisoned'']; WHEN ''oblivion_incense'' THEN mn := 20; er := 30; cures := ARRAY[''erosion_whisper'', ''shaken''];');

-- ─── 반요촌: 거래소·창고·마구간 없음, 상점 비쌈(사람마다 하루 살 수 있는 개수), 되팔기 절반, 수리비 ×3 ───
select pg_temp.yh_patch('public.world_guard_action_context()', '  IF k = ''trade'' AND (p ? ''unit_price'' OR p ? ''gil'') AND (r.region_id IS NULL OR NOT r.is_safe_zone) THEN',
  '  IF k = ''trade'' AND p ? ''unit_price'' AND r.region_id = ''banyo_village'' THEN
    RAISE EXCEPTION ''반요촌에는 거래소가 없습니다.'';
  END IF;
  IF k = ''trade'' AND (p ? ''unit_price'' OR p ? ''gil'') AND (r.region_id IS NULL OR NOT r.is_safe_zone) THEN');
select pg_temp.yh_patch('public.world_storage_check(uuid,boolean)', '  if not exists (select 1 from public.world_current_shop(p_uid)) then raise exception ''창고는 안전지대에서만 열 수 있습니다.''; end if;',
  '  if not exists (select 1 from public.world_current_shop(p_uid)) then raise exception ''창고는 안전지대에서만 열 수 있습니다.''; end if;
  if public.world_banyo_here(p_uid) then raise exception ''반요촌에는 창고가 없습니다. 바깥 안전지대에서 맡기고 꺼내세요.''; end if;');
select pg_temp.yh_patch('public.world_craft_item(text)', 'if exists (select 1 from public.world_current_shop(uid)) then select items into st',
  'if exists (select 1 from public.world_current_shop(uid)) and not public.world_banyo_here(uid) then select items into st');

create table if not exists public.world_shop_buy_caps (owner_id uuid not null, day date not null, item_id text not null, qty int not null default 0, primary key (owner_id, day, item_id));
alter table public.world_shop_buy_caps enable row level security;
revoke all on public.world_shop_buy_caps from anon, authenticated;
grant select, insert, update on public.world_shop_buy_caps to fn_owner_18877, fn_owner_field;
grant select on public.world_shop_catalog to fn_owner_18877;

select pg_temp.yh_patch('public.world_shop_buy(text,integer)', '  if not found then raise exception ''지금은 팔지 않는 물품입니다. 품목은 하루 세 번(07·15·23시) 바뀝니다.''; end if;',
  '  if not found or (shop = ''banyo_shop'' and s.shop_id = ''smithy'' and p_item_id not in (''iron_ingot'', ''charcoal'')) then raise exception ''지금은 팔지 않는 물품입니다. 품목은 하루 세 번(07·15·23시) 바뀝니다.''; end if;
  -- 반요촌: 사람마다 품목별 하루(한국 시각) 살 수 있는 개수
  if s.shop_id = ''banyo_shop'' and (select sc.daily_cap from public.world_shop_catalog sc where sc.shop_id = ''banyo_shop'' and sc.item_id = p_item_id) is not null then
    if coalesce((select bc.qty from public.world_shop_buy_caps bc where bc.owner_id = uid and bc.day = (now() at time zone ''Asia/Seoul'')::date and bc.item_id = p_item_id), 0) + p_qty
       > (select sc.daily_cap from public.world_shop_catalog sc where sc.shop_id = ''banyo_shop'' and sc.item_id = p_item_id) then
      raise exception ''반요촌에서는 이 물품을 하루에 %개까지만 살 수 있습니다(오늘 %개 삼).'', (select sc.daily_cap from public.world_shop_catalog sc where sc.shop_id = ''banyo_shop'' and sc.item_id = p_item_id),
        coalesce((select bc.qty from public.world_shop_buy_caps bc where bc.owner_id = uid and bc.day = (now() at time zone ''Asia/Seoul'')::date and bc.item_id = p_item_id), 0);
    end if;
    insert into public.world_shop_buy_caps(owner_id, day, item_id, qty) values (uid, (now() at time zone ''Asia/Seoul'')::date, p_item_id, p_qty)
    on conflict (owner_id, day, item_id) do update set qty = world_shop_buy_caps.qty + excluded.qty;
  end if;');
-- 반요촌 품목은 회차마다 4가지 이상, 귀허 부적·화살·쇠뇌살·취관 침은 늘
select pg_temp.yh_patch('public.world_shop_refresh(text)', 'case when sc.item_id = any(staples) or random() < 0.55 then 1 else 0 end',
  'case when (sc.item_id = any(staples) and (p_shop <> ''banyo_shop'' or sc.item_id like ''ammo%'')) or sc.item_id = ''gwiheo_charm'' or random() < case when p_shop = ''banyo_shop'' then 0.3 else 0.55 end then 1 else 0 end');
select pg_temp.yh_patch('public.world_shop_refresh(text)', 'limit greatest(0, 6 - (select count(*)', 'limit greatest(0, case when p_shop = ''banyo_shop'' then 4 else 6 end - (select count(*)');
-- 반요촌 대장간: 강화 재료는 월철 주괴·정련 숯만
select pg_temp.yh_patch('public.world_smithy_snapshot()', '   where ss.shop_id = ''smithy'' and ss.stock > 0;',
  '   where ss.shop_id = ''smithy'' and ss.stock > 0 and (sh.shop_id <> ''banyo_shop'' or ss.item_id in (''iron_ingot'', ''charcoal''));');
-- 반요촌 되팔기: 받는 값 절반, 24시간 판매 수익이 한도의 절반을 넘으면 더 팔 수 없음
select pg_temp.yh_patch('public.world_shop_sell(text,integer)', '  price := public.world_shop_sell_unit(p_item_id);',
  '  price := public.world_shop_sell_unit(p_item_id);
  if public.world_banyo_here(uid) then price := greatest(1, price / 2); end if;');
select pg_temp.yh_patch('public.world_shop_sell(text,integer)', '  if earned + net > cap then',
  '  if public.world_banyo_here(uid) and earned + net > cap / 2 then
    raise exception ''반요촌에서는 24시간 판매 수익이 %전(한도의 절반)을 넘으면 더 팔 수 없습니다. 지금까지 %전을 받았습니다.'', cap / 2, earned;
  end if;
  if earned + net > cap then');
-- 반요촌 수리비 ×3
select pg_temp.yh_patch('public.world_equipment_repair(text,text)', '    IF ''smithing_c43b'' = ANY (public.world_skill_procs(uid)) THEN cost := greatest(2, cost / 2); END IF;',
  '    IF ''smithing_c43b'' = ANY (public.world_skill_procs(uid)) THEN cost := greatest(2, cost / 2); END IF;
    cost := cost * public.world_repair_mult(uid);');
select pg_temp.yh_patch('public.world_repair_quote()', '''cost'', (case when half', '''cost'', public.world_repair_mult(public.fn_owner_auth_uid()) * (case when half');
select pg_temp.yh_patch('public.world_repair_quote()', '''total'', coalesce(sum((case when half', '''total'', coalesce(sum(public.world_repair_mult(public.fn_owner_auth_uid()) * (case when half');

-- 6단계 채집도는 채집도 계열(낮은 단계 채집도가 필요한 제작법도 만든다)
insert into public.world_tool_lines(item_id, line) values ('t6_gather', 'knife') on conflict do nothing;


-- ─────────────────────────────────────────────────────────────
-- B-3. 외전 최종 보스 「귀허의 주인」 — 라운드 전투
--   라운드: 보통 5초 / 기믹 10초. 라운드 안에 참가자마다 행동 하나(공격·방어·물품·정화·사슬 끊기), 안 고르면 방어.
--   마감이 지나거나 모두 고르면 서버가 한 번에 풀어낸다(누군가 상황을 읽거나 행동할 때). 실시간 감시 목록에는 넣지 않는다.
--   단계(체력): ① 100~75% 두 얼굴 ② 75~50% 사슬 넷 ③ 50~25% 이름 빼앗기 ④ 25% 아래 귀허의 소용돌이.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.world_gw_fights (
  fight_id uuid primary key default gen_random_uuid(),
  leader_id uuid not null,
  status text not null default 'wait' check (status in ('wait', 'fight', 'won', 'failed')),
  created_at timestamptz not null default now(),
  start_at timestamptz not null default now(),
  ends_at timestamptz, ended_at timestamptz,
  hp int not null default 0, max_hp int not null default 0,
  phase int not null default 1, round int not null default 0, cycle int not null default 0,
  round_ends_at timestamptz,
  mech jsonb not null default '{}'::jsonb,
  enrage int not null default 0,
  updated_at timestamptz not null default now()
);
create table if not exists public.world_gw_members (
  fight_id uuid not null references public.world_gw_fights(fight_id) on delete cascade,
  owner_id uuid not null, name text not null, job_key text, level int,
  hp int not null default 100, stats jsonb not null default '{}'::jsonb, act jsonb,
  acts int not null default 0, dmg int not null default 0, heal int not null default 0,
  out_rounds int not null default 0, nameless boolean not null default false, falls int not null default 0,
  joined_at timestamptz not null default now(),
  primary key (fight_id, owner_id)
);
create table if not exists public.world_gw_log (
  id bigserial primary key, fight_id uuid not null references public.world_gw_fights(fight_id) on delete cascade,
  round int not null default 0, at timestamptz not null default now(), kind text not null default 'info', text text not null
);
create index if not exists world_gw_log_fight on public.world_gw_log(fight_id, id);
create index if not exists world_gw_members_owner on public.world_gw_members(owner_id);
create table if not exists public.world_gw_records (
  owner_id uuid primary key, kills int not null default 0, tries int not null default 0,
  last_kill_day date, last_fail_at timestamptz, first_kill_at timestamptz
);
alter table public.world_gw_fights enable row level security;
alter table public.world_gw_members enable row level security;
alter table public.world_gw_log enable row level security;
alter table public.world_gw_records enable row level security;
revoke all on public.world_gw_fights, public.world_gw_members, public.world_gw_log, public.world_gw_records from anon, authenticated;
grant select, insert, update, delete on public.world_gw_fights, public.world_gw_members, public.world_gw_log, public.world_gw_records to fn_owner_field;
grant usage on sequence public.world_gw_log_id_seq to fn_owner_field;

create or replace function public.world_gw_say(p_fight uuid, p_round int, p_kind text, p_text text) returns void
language sql security definer set search_path to 'pg_catalog', 'public' as $$
  insert into public.world_gw_log(fight_id, round, kind, text) values (p_fight, p_round, p_kind, p_text)
$$;

-- 도전·합류 조건 확인(캐릭터 행을 돌려줌)
create or replace function public.world_gw_ready(p_uid uuid) returns public.world_characters
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype; rec public.world_gw_records%rowtype; today date := (now() at time zone 'Asia/Seoul')::date;
begin
  select * into c from public.world_characters where owner_id = p_uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 도전할 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 도전할 수 없습니다.'; end if;
  if (public.world_region_at(c.location)).region_id is distinct from 'gwiheo_core' then raise exception '귀허에서만 귀허의 주인 앞에 설 수 있습니다.'; end if;
  if not public.world_gwiheo_open(p_uid) then raise exception '귀허도에 아직 건너오지 못했습니다.'; end if;
  if c.level < 38 then raise exception 'Lv38부터 도전할 수 있습니다.'; end if;
  if not public.world_quest_done(p_uid, 'gq_4') then raise exception '외전 4장 「달 없는 장」을 마쳐야 귀허의 주인 앞에 설 수 있습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = p_uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '요괴와 싸우는 중입니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then raise exception '원정 중에는 도전할 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = 'active') then raise exception '자율 활동 중에는 도전할 수 없습니다.'; end if;
  select * into rec from public.world_gw_records where owner_id = p_uid;
  if rec.last_kill_day = today then raise exception '오늘은 이미 귀허의 주인을 쓰러뜨렸습니다. 내일(한국 시각 0시 뒤) 다시 도전할 수 있습니다.'; end if;
  if rec.last_fail_at > now() - interval '30 minutes' then
    raise exception '귀허의 소용돌이가 아직 가라앉지 않았습니다. %분 뒤 다시 도전할 수 있습니다.', ceil(extract(epoch from rec.last_fail_at + interval '30 minutes' - now()) / 60);
  end if;
  if coalesce((c.inventory ->> 'gwiheo_charm')::int, 0) < 1 then raise exception '귀허 부적이 필요합니다. 반요촌 잡화에서 팝니다.'; end if;
  if exists (select 1 from public.world_gw_members m join public.world_gw_fights f using (fight_id) where m.owner_id = p_uid and f.status in ('wait', 'fight')) then
    raise exception '이미 귀허의 주인과 싸우는 중입니다.'; end if;
  return c;
end $$;

-- 다음 라운드 준비: 단계에 맞는 기믹과 마감 시각
create or replace function public.world_gw_next_round(p_fight uuid) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare f public.world_gw_fights%rowtype; ph int; m jsonb; len int := 5; alive uuid[]; colors text[] := array['청', '적', '황', '백']; k int; t uuid; need int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  ph := case when f.hp * 4 > f.max_hp * 3 then 1 when f.hp * 2 > f.max_hp then 2 when f.hp * 4 > f.max_hp then 3 else 4 end;
  select array_agg(owner_id order by random()) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
  if ph <> f.phase then
    perform public.world_gw_say(p_fight, f.round + 1, 'phase', case ph
      when 2 then '귀허의 주인이 두 얼굴을 거둔다. 바닥에서 흰 사슬 네 줄이 솟아 조사원들의 손목을 감는다. 「너희 이름을 묶어 두마.」'
      when 3 then '사슬이 끊긴 자리에서 물이 솟는다. 「이름을 다오. 하나씩 빼앗아 주마.」'
      else '귀허의 주인이 왕좌에서 일어선다. 바다 전체가 소용돌이친다. 「모두 함께 가라앉자.」' end);
    f.cycle := 0;
  end if;
  if ph = 1 then
    m := jsonb_build_object('k', 'face', 'face', case when random() < 0.5 then 'human' else 'yokai' end);
  elsif ph = 2 and f.cycle % 6 = 0 and alive is not null then
    m := jsonb_build_object('k', 'chain', 'colors', (select jsonb_object_agg(a::text, colors[o]) from unnest(alive) with ordinality u(a, o)));
    len := 10;
  elsif ph = 3 and f.cycle % 6 = 0 and alive is not null then
    t := alive[1];
    update public.world_gw_members set nameless = true where fight_id = p_fight and owner_id = t;
    m := jsonb_build_object('k', 'name', 'target', t);
    len := 10;
  elsif ph = 4 and f.cycle % 5 = 0 and alive is not null then
    select owner_id into t from public.world_gw_members where fight_id = p_fight and out_rounds = 0 order by (stats ->> 'pres')::numeric desc, random() limit 1;
    select greatest(1, round(coalesce(sum((stats ->> 'attack')::numeric), 0) * 0.8)) into need from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and owner_id <> t;
    m := jsonb_build_object('k', 'vortex', 'tank', t, 'need', need);
    len := 10;
  else
    m := jsonb_build_object('k', 'normal');
  end if;
  update public.world_gw_fights set phase = ph, round = f.round + 1, cycle = f.cycle + 1, mech = m, round_ends_at = now() + make_interval(secs => len), updated_at = now()
   where fight_id = p_fight;
  update public.world_gw_members set act = null where fight_id = p_fight;
  perform public.world_gw_say(p_fight, f.round + 1, 'tell', case m ->> 'k'
    when 'face' then case when m ->> 'face' = 'human' then '주인이 사람의 얼굴을 든다. 낯익은 노인의 눈이 이쪽을 본다.' else '주인이 요괴의 얼굴을 든다. 비늘 덮인 입이 귀까지 찢어진다.' end
    when 'chain' then '흰 사슬이 조여 온다. 저마다 손목의 사슬 빛깔을 확인하라. (10초)'
    when 'name' then (select name from public.world_gw_members where fight_id = p_fight and owner_id = t) || '의 이름이 물에 녹아 흘러간다. 「네 이름은 이제 내 것이다.」 (10초)'
    when 'vortex' then '귀허의 소용돌이가 일어난다. ' || (select name from public.world_gw_members where fight_id = p_fight and owner_id = t) || '이(가) 버텨야 한다. (10초)'
    else '주인이 숨을 고른다. 물살이 왕좌를 감싸 돈다.' end);
end $$;

-- 싸움 시작: 부적을 쓰고 능력치를 적어 두고 체력을 정한다
create or replace function public.world_gw_start(p_fight uuid) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare f public.world_gw_fights%rowtype; x record; s jsonb; sa numeric := 0; n int := 0;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'wait' then return; end if;
  for x in select m.owner_id, c.inventory, c.health from public.world_gw_members m join public.world_characters c using (owner_id) where m.fight_id = p_fight for update of c loop
    if coalesce((x.inventory ->> 'gwiheo_charm')::int, 0) < 1 or x.health <= 0 then
      delete from public.world_gw_members where fight_id = p_fight and owner_id = x.owner_id;
      continue;
    end if;
    update public.world_characters set inventory = public.world_inv_add(inventory, 'gwiheo_charm', -1), updated_at = now() where owner_id = x.owner_id;
    s := public.world_raid_stats(x.owner_id);
    update public.world_gw_members set stats = s, hp = greatest(30, least(100, x.health)) where fight_id = p_fight and owner_id = x.owner_id;
    insert into public.world_gw_records(owner_id, tries) values (x.owner_id, 1) on conflict (owner_id) do update set tries = world_gw_records.tries + 1;
    sa := sa + coalesce((s ->> 'attack')::numeric, 50); n := n + 1;
  end loop;
  if n = 0 then
    update public.world_gw_fights set status = 'failed', ended_at = now(), updated_at = now() where fight_id = p_fight;
    return;
  end if;
  update public.world_gw_fights set status = 'fight', max_hp = greatest(6000, round(sa * 40)), hp = greatest(6000, round(sa * 40)), phase = 1, round = 0, cycle = 0,
         ends_at = now() + interval '15 minutes', updated_at = now() where fight_id = p_fight;
  perform public.world_gw_say(p_fight, 0, 'phase', '빈 왕좌 위로 물이 솟아 사람 꼴이 된다. 귀허의 주인이 두 얼굴을 번갈아 든다. 「사람의 얼굴에는 사람의 칼을, 요괴의 얼굴에는…」 말끝이 물에 녹는다.');
  perform public.world_gw_next_round(p_fight);
end $$;

-- 체력에 피해를 주고 쓰러지면 세 라운드 물러남(돌아오면 체력 30)
create or replace function public.world_gw_hurt(p_fight uuid, p_uid uuid, p_dmg int, p_round int, p_why text) returns int
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare m public.world_gw_members%rowtype; d int := greatest(0, p_dmg);
begin
  select * into m from public.world_gw_members where fight_id = p_fight and owner_id = p_uid for update;
  if not found or m.out_rounds > 0 or d = 0 then return 0; end if;
  if m.hp - d <= 0 then
    update public.world_gw_members set hp = 0, out_rounds = 4, falls = falls + 1, nameless = false where fight_id = p_fight and owner_id = p_uid;
    perform public.world_gw_say(p_fight, p_round, 'fall', m.name || ' — ' || p_why || ' ' || d || '의 피해를 입고 물러났습니다(세 라운드 뒤 돌아옴).');
  else
    update public.world_gw_members set hp = m.hp - d where fight_id = p_fight and owner_id = p_uid;
    perform public.world_gw_say(p_fight, p_round, 'hit', m.name || ' — ' || p_why || ' ' || d || '의 피해.');
  end if;
  return d;
end $$;

-- 라운드 풀이: 마감이 지났거나 살아 있는 모두가 골랐을 때
create or replace function public.world_gw_resolve(p_fight uuid) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare f public.world_gw_fights%rowtype; m record; a jsonb; av text; d numeric; hv numeric; boss_dmg numeric := 0; boss_heal numeric := 0; physical boolean;
  k text; vsum numeric := 0; tank_ok boolean := false; freed uuid[] := '{}'; tgt uuid; inv jsonb; amt int; raw numeric; r int; alive int; cr boolean;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return; end if;
  if now() < f.round_ends_at and exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and act is null) then return; end if;
  r := f.round; k := f.mech ->> 'k';
  -- ① 조사원들의 행동
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 order by joined_at loop
    a := coalesce(m.act, '{"a":"guard"}'::jsonb); av := a ->> 'a';
    if m.act is not null then update public.world_gw_members set acts = acts + 1 where fight_id = p_fight and owner_id = m.owner_id; end if;
    if av = 'attack' then
      cr := random() * 100 < coalesce((m.stats ->> 'crit')::numeric, 5);
      d := coalesce((m.stats ->> 'attack')::numeric, 50) * (0.9 + random() * 0.2) * case when cr then 1.5 else 1 end;
      physical := coalesce(m.stats ->> 'style', 'melee') in ('melee', 'ranged');
      if m.nameless then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 이름을 잃어 칼끝이 주인에게 닿지 않습니다.');
      elsif k = 'face' and ((f.mech ->> 'face' = 'human') <> physical) then
        boss_heal := boss_heal + round(d * 0.5);
        perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — ' || case when physical then '요괴의 얼굴에 칼을 대자' else '사람의 얼굴에 술법을 쓰자' end || ' 주인이 그 힘을 삼켜 ' || round(d * 0.5) || ' 회복합니다.');
      else
        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;
        update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
        perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — ' || round(d) || case when cr then '의 치명타.' else '의 피해.' end);
      end if;
    elsif av = 'guard' then
      if k = 'vortex' and m.owner_id::text = f.mech ->> 'tank' then tank_ok := true; end if;
    elsif av = 'item' then
      tgt := coalesce(nullif(a ->> 't', '')::uuid, m.owner_id);
      select inventory into inv from public.world_characters where owner_id = m.owner_id for update;
      if coalesce((inv ->> (a ->> 'i'))::int, 0) < 1 then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 꺼낼 물품이 없습니다.');
      else
        hv := case a ->> 'i' when 'tonic' then 35 when 'herbal_extract' then 22 when 'rejuv_pill' then 60 when 'grand_pill' then 100 when 'banyo_salve' then 70 else 0 end
              * case when m.job_key = 'medic' then case when tgt <> m.owner_id then 1.4 else 1.15 end else 1 end;
        update public.world_characters set inventory = public.world_inv_add(inventory, a ->> 'i', -1), updated_at = now() where owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round(hv)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
        update public.world_gw_members set heal = heal + round(hv)::int where fight_id = p_fight and owner_id = m.owner_id;
        perform public.world_gw_say(p_fight, r, 'heal', m.name || ' — ' || (select name from public.world_gw_members where fight_id = p_fight and owner_id = tgt) || '의 체력 +' || round(hv) || '.');
      end if;
    elsif av = 'purify' then
      tgt := nullif(a ->> 't', '')::uuid;
      if k <> 'name' or tgt is distinct from (f.mech ->> 'target')::uuid then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 정화할 곳이 없습니다.');
      else
        select inventory into inv from public.world_characters where owner_id = m.owner_id for update;
        if coalesce((inv ->> 'ward_talisman')::int, 0) < 1 then
          perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 정화 부적이 없습니다.');
        else
          update public.world_characters set inventory = public.world_inv_add(inventory, 'ward_talisman', -1), updated_at = now() where owner_id = m.owner_id;
          if tgt <> m.owner_id or random() < 0.3 then
            update public.world_gw_members set nameless = false where fight_id = p_fight and owner_id = tgt;
            perform public.world_gw_say(p_fight, r, 'good', m.name || ' — 정화 부적으로 ' || (select name from public.world_gw_members where fight_id = p_fight and owner_id = tgt) || '의 이름을 되찾아 주었습니다.');
          else
            perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — 제 이름을 스스로 부르려 했지만 목소리가 물에 녹았습니다.');
          end if;
        end if;
      end if;
    elsif av = 'chain' then
      if k <> 'chain' then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 끊을 사슬이 없습니다.');
      elsif a ->> 'c' = f.mech -> 'colors' ->> m.owner_id::text then
        freed := freed || m.owner_id;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — 자기 사슬(' || (a ->> 'c') || ')을 끊었습니다.');
      else
        perform public.world_gw_hurt(p_fight, m.owner_id, 20, r, '남의 사슬(' || coalesce(a ->> 'c', '?') || ')을 쳐 되튕긴 사슬에');
      end if;
    end if;
  end loop;
  -- ② 기믹 결과
  if k = 'chain' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '끊지 못한 사슬에 끌려가');
    end loop;
    if exists (select 1 from public.world_gw_members where fight_id = p_fight and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text) then
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 loop
        perform public.world_gw_hurt(p_fight, m.owner_id, 30, r, '사슬이 끌어당긴 물살에');
      end loop;
    end if;
  elsif k = 'name' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and nameless loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '이름을 끝내 찾지 못해');
    end loop;
  elsif k = 'vortex' then
    if tank_ok and vsum >= coalesce((f.mech ->> 'need')::numeric, 0) then
      boss_dmg := boss_dmg + round(vsum * 0.5);
      perform public.world_gw_say(p_fight, r, 'good', '소용돌이를 끊었습니다! 흩어진 물살이 주인에게 되돌아가 ' || round(vsum * 0.5) || '의 피해를 더 줍니다.');
    else
      perform public.world_gw_say(p_fight, r, 'bad', case when not tank_ok then '버텨야 할 사람이 버티지 못했습니다. ' else '몰아친 힘이 모자랐습니다. ' end || '소용돌이가 모두를 삼키고 주인이 더 사나워집니다.');
      update public.world_gw_members set hp = greatest(1, hp / 2) where fight_id = p_fight and out_rounds = 0;
      update public.world_gw_fights set enrage = enrage + 1 where fight_id = p_fight;
      f.enrage := f.enrage + 1;
    end if;
  end if;
  -- ③ 보스 체력
  update public.world_gw_fights set hp = least(max_hp, greatest(0, hp - round(boss_dmg)::int + round(boss_heal)::int)), updated_at = now() where fight_id = p_fight returning * into f;
  if f.hp <= 0 then perform public.world_gw_settle(p_fight, true); return; end if;
  -- ④ 보스의 반격(기믹 라운드에는 쉰다): 이목에 비례해 하나를 노리고, 네 라운드마다 모두에게 물살
  if k in ('face', 'normal') then
    raw := (35 + 4 * f.phase) * (1 + 0.15 * f.enrage);
    if r % 4 = 0 then
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 loop
        d := raw * 0.55 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((m.stats ->> 'inc')::numeric, 0) / 100.0)
             * case when coalesce(m.act ->> 'a', 'guard') = 'guard' then 0.4 else 1 end;
        perform public.world_gw_hurt(p_fight, m.owner_id, round(d)::int, r, '쏟아지는 물살에');
      end loop;
    else
      select * into m from public.world_gw_members where fight_id = p_fight and out_rounds = 0
       order by -ln(greatest(random(), 1e-9)) / power(greatest(1, coalesce((stats ->> 'pres')::numeric, 30)), 1.3) limit 1;
      if m.owner_id is not null then
        if random() * 100 < coalesce((m.stats ->> 'eva')::numeric, 0) then
          perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 주인의 손길을 피했습니다.');
        else
          d := raw * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((m.stats ->> 'inc')::numeric, 0) / 100.0)
               * case when coalesce(m.act ->> 'a', 'guard') = 'guard' then 0.4 else 1 end;
          perform public.world_gw_hurt(p_fight, m.owner_id, round(d)::int, r, '주인의 손아귀에');
        end if;
      end if;
    end if;
  end if;
  -- ⑤ 물러난 이의 복귀, 끝 판정, 다음 라운드
  update public.world_gw_members set out_rounds = out_rounds - 1, hp = case when out_rounds = 1 then 30 else hp end where fight_id = p_fight and out_rounds > 0;
  select count(*) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
  if alive = 0 then
    perform public.world_gw_say(p_fight, r, 'bad', '모두가 물러났습니다. 소용돌이가 왕좌를 덮습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  if now() >= f.ends_at then
    perform public.world_gw_say(p_fight, r, 'bad', '시간이 다 되었습니다. 귀허의 주인이 바다 밑으로 가라앉습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  perform public.world_gw_next_round(p_fight);
end $$;

-- 끝: 체력을 캐릭터에 돌려 쓰고 보상·벌칙
create or replace function public.world_gw_settle(p_fight uuid, p_won boolean) returns void
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare f public.world_gw_fights%rowtype; m record; today date := (now() at time zone 'Asia/Seoul')::date; rec public.world_gw_records%rowtype; n int; solo boolean; flawless boolean;
  is_first boolean; xp int; msg text; lv int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status not in ('fight', 'wait') then return; end if;
  update public.world_gw_fights set status = case when p_won then 'won' else 'failed' end, ended_at = now(), updated_at = now(), hp = case when p_won then 0 else hp end where fight_id = p_fight;
  select count(*), coalesce(sum(falls), 0) = 0 into n, flawless from public.world_gw_members where fight_id = p_fight;
  solo := n = 1;
  for m in select * from public.world_gw_members where fight_id = p_fight loop
    if p_won then
      update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
      select * into rec from public.world_gw_records where owner_id = m.owner_id for update;
      if rec.last_kill_day is distinct from today then
        is_first := coalesce(rec.kills, 0) = 0;
        update public.world_gw_records set kills = kills + 1, last_kill_day = today, first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id;
        select level into lv from public.world_characters where owner_id = m.owner_id;
        xp := case when is_first then round(public.world_xp_need(lv) * 0.5) else round(public.world_xp_need(lv) * 0.05) end;
        update public.world_characters set gil = gil + case when is_first then 1500 else 120 end, updated_at = now() where owner_id = m.owner_id;
        perform public.world_grant_xp(m.owner_id, xp);
        if is_first then
          insert into public.world_owned_mounts(owner_id, mount_id) values (m.owner_id, 'moonless_boat') on conflict do nothing;
          insert into public.world_faction_unlocks(owner_id, unlock_key) values (m.owner_id, 'ns:1028') on conflict do nothing;
        end if;
        msg := case when is_first then '귀허의 주인을 처음으로 쓰러뜨렸습니다. 1,500전 · 경험치 ' || xp || ' · 탈것 「달 없는 배」 · 이름 색 「귀허청」을 얻었습니다.'
                    else '귀허의 주인을 쓰러뜨렸습니다(' || (coalesce(rec.kills, 0) + 1) || '번째). 120전 · 경험치 ' || xp || '.' end;
        insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '귀허의 주인 처치', msg, jsonb_build_object('fight_id', p_fight, 'first', is_first));
        -- 칭호·꾸미기는 기록(gw_win)으로 판정한다(world_title_rule_ok의 ev 규칙)
        insert into public.world_events(actor_id, actor_name, event_type, content, payload)
        values (m.owner_id, m.name, 'gw_win', m.name || '이(가) 귀허의 주인을 쓰러뜨렸습니다.',
                jsonb_build_object('fight_id', p_fight, 'first', is_first, 'solo', solo, 'flawless', flawless and n >= 2, 'members', n, 'kills', coalesce(rec.kills, 0) + 1));
      else
        insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '귀허의 주인 처치', '오늘은 이미 처치를 인정받아 보상은 없습니다.', jsonb_build_object('fight_id', p_fight));
      end if;
    else
      -- 실패 벌칙: 장착 장비 내구도 −10%, 침식 +10, 30분 뒤 재도전(부적은 이미 씀). 경험치·물품은 잃지 않는다
      update public.world_item_durability d set durability = greatest(0, d.durability - ceil(public.world_item_max_durability(d.item_id) * 0.1)::int), updated_at = now()
        from public.world_character_equipment e where e.owner_id = m.owner_id and d.owner_id = m.owner_id and d.item_id = e.item_id;
      update public.world_characters set health = greatest(1, m.hp), erosion = least(100, erosion + 10),
             erosion_stage = case when least(100, erosion + 10) >= 80 then 4 when least(100, erosion + 10) >= 55 then 3 when least(100, erosion + 10) >= 30 then 2 when least(100, erosion + 10) >= 10 then 1 else 0 end,
             updated_at = now() where owner_id = m.owner_id;
      insert into public.world_gw_records(owner_id, last_fail_at) values (m.owner_id, now()) on conflict (owner_id) do update set last_fail_at = now();
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (m.owner_id, 'gw', '귀허의 주인 도전 실패', '소용돌이에 밀려났습니다. 장착한 장비 내구도가 10% 닳고 침식이 10 올랐습니다. 30분 뒤 다시 도전할 수 있습니다.', jsonb_build_object('fight_id', p_fight));
    end if;
  end loop;
  perform public.world_gw_say(p_fight, f.round, case when p_won then 'win' else 'bad' end, case when p_won
    then '귀허의 주인이 무너진다. 「…이름을 하나만 다오.」 물이 바다로 돌아가고, 소용돌이가 있던 자리에 달빛 비슷한 것이 비친다.'
    else '도전이 끝났습니다.' end);
end $$;

-- 상황 읽기(늦은 시작·라운드 풀이도 여기서): p_fight가 없으면 내가 든 싸움·받은 초대·도전 조건
create or replace function public.world_gw_snapshot(p_fight uuid default null) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; rec public.world_gw_records%rowtype; c public.world_characters%rowtype;
  fid uuid := p_fight; why text; inv_f uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if fid is null then
    select m.fight_id into fid from public.world_gw_members m join public.world_gw_fights x using (fight_id) where m.owner_id = uid and x.status in ('wait', 'fight') order by x.created_at desc limit 1;
  end if;
  select * into c from public.world_characters where owner_id = uid;
  select * into rec from public.world_gw_records where owner_id = uid;
  if fid is null then
    -- 받은 초대(같은 파티·같은 곳·모이는 중)
    select x.fight_id into inv_f from public.world_gw_fights x join public.world_party_members a on a.owner_id = x.leader_id join public.world_party_members b on b.party_id = a.party_id and b.owner_id = uid
     where x.status = 'wait' and x.start_at > now() order by x.created_at desc limit 1;
    begin perform public.world_gw_ready_check(uid); exception when others then why := sqlerrm; end;
    return jsonb_build_object('none', true, 'invite', inv_f, 'can_open', why is null, 'why', why, 'charms', coalesce((c.inventory ->> 'gwiheo_charm')::int, 0),
      'kills', coalesce(rec.kills, 0), 'tips', case when coalesce(rec.kills, 0) > 0 then public.world_gw_tips() end, 'here', (public.world_region_at(c.location)).region_id = 'gwiheo_core');
  end if;
  select * into f from public.world_gw_fights where fight_id = fid;
  if not found then raise exception '싸움을 찾을 수 없습니다.'; end if;
  if not exists (select 1 from public.world_gw_members where fight_id = fid and owner_id = uid)
     and not (f.status = 'wait' and exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id where a.owner_id = f.leader_id and b.owner_id = uid)) then
    raise exception '함께 싸우는 조사원만 볼 수 있습니다.';
  end if;
  if f.status = 'wait' and f.start_at <= now() then perform public.world_gw_start(fid); end if;
  if f.status = 'fight' then perform public.world_gw_resolve(fid); end if;
  select * into f from public.world_gw_fights where fight_id = fid;
  select * into me from public.world_gw_members where fight_id = fid and owner_id = uid;
  return jsonb_build_object('fight', jsonb_build_object('id', f.fight_id, 'status', f.status, 'hp', f.hp, 'max_hp', f.max_hp, 'phase', f.phase, 'round', f.round,
      'round_ends_at', f.round_ends_at, 'ends_at', f.ends_at, 'start_at', f.start_at, 'leader', f.leader_id, 'enrage', f.enrage,
      'mech', case f.mech ->> 'k' when 'chain' then jsonb_build_object('k', 'chain', 'colors', (select jsonb_agg(v order by v) from jsonb_each_text(f.mech -> 'colors') e(kk, v)), 'mine', f.mech -> 'colors' ->> uid::text)
                              when 'vortex' then f.mech - 'need' || jsonb_build_object('need', (f.mech ->> 'need')::int)
                              else f.mech end),
    'now', now(), 'me', uid,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', m.owner_id, 'name', m.name, 'job', m.job_key, 'level', m.level, 'hp', m.hp, 'out', m.out_rounds,
        'nameless', m.nameless, 'acted', m.act is not null, 'dmg', m.dmg, 'heal', m.heal, 'falls', m.falls) order by m.joined_at), '[]'::jsonb) from public.world_gw_members m where m.fight_id = fid),
    'my_act', me.act, 'joined', me.owner_id is not null,
    'items', (select coalesce(jsonb_object_agg(i, coalesce((c.inventory ->> i)::int, 0)), '{}'::jsonb) from unnest(array['tonic', 'herbal_extract', 'rejuv_pill', 'grand_pill', 'banyo_salve', 'ward_talisman']) i),
    'log', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'round', l.round, 'kind', l.kind, 'text', l.text) order by l.id), '[]'::jsonb)
              from (select * from public.world_gw_log where fight_id = fid order by id desc limit 60) l),
    'tips', case when coalesce(rec.kills, 0) > 0 then public.world_gw_tips() end);
end $$;

-- 도전 조건만 확인(잠그지 않음, 상황 읽기용)
create or replace function public.world_gw_ready_check(p_uid uuid) returns void
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype; rec public.world_gw_records%rowtype;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if (public.world_region_at(c.location)).region_id is distinct from 'gwiheo_core' then raise exception '귀허에서만 도전할 수 있습니다.'; end if;
  if c.level < 38 then raise exception 'Lv38부터 도전할 수 있습니다.'; end if;
  if not public.world_quest_done(p_uid, 'gq_4') then raise exception '외전 4장 「달 없는 장」을 마쳐야 합니다.'; end if;
  select * into rec from public.world_gw_records where owner_id = p_uid;
  if rec.last_kill_day = (now() at time zone 'Asia/Seoul')::date then raise exception '오늘은 이미 처치했습니다. 내일 다시 도전할 수 있습니다.'; end if;
  if rec.last_fail_at > now() - interval '30 minutes' then raise exception '%분 뒤 다시 도전할 수 있습니다.', ceil(extract(epoch from rec.last_fail_at + interval '30 minutes' - now()) / 60); end if;
  if coalesce((c.inventory ->> 'gwiheo_charm')::int, 0) < 1 then raise exception '귀허 부적이 필요합니다(반요촌 잡화).'; end if;
end $$;

-- 파훼법: 처치한 조사원에게만
create or replace function public.world_gw_tips() returns jsonb
language sql immutable set search_path to 'pg_catalog' as $$
  select jsonb_build_array(
    '두 얼굴: 사람의 얼굴에는 근접·원거리(물리), 요괴의 얼굴에는 술법만 듣는다. 반대로 치면 주인이 회복하니 맞지 않는 쪽은 방어하거나 회복을 맡는다.',
    '사슬 넷: 저마다 손목 사슬의 빛깔이 다르다. 10초 안에 자기 빛깔의 사슬만 끊는다. 남의 사슬을 치면 되튕기고, 못 끊은 사람은 끌려간다.',
    '이름 빼앗기: 이름을 잃은 사람의 공격은 닿지 않는다. 동료가 10초 안에 그 사람에게 정화 부적을 써 줘야 풀린다(스스로는 잘 안 된다).',
    '귀허의 소용돌이: 이목이 가장 높은 사람이 방어로 버티고, 나머지는 모두 공격해 정해진 양을 넘겨야 끊긴다. 실패하면 모두 체력 절반·주인 분노.',
    '보통 라운드에도 주인은 이목이 높은 사람을 더 자주 노리고, 네 라운드마다 모두를 친다. 고르지 않으면 저절로 방어한다.')
$$;

-- 도전 열기: 혼자면 바로 시작, 같은 곳에 파티원이 있으면 60초 동안 모은다
create or replace function public.world_gw_open() returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; fid uuid; x record; n int := 0;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  c := public.world_gw_ready(uid);
  select count(*) into n from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id and b.owner_id <> a.owner_id
    join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null;
  insert into public.world_gw_fights(leader_id, status, start_at) values (uid, 'wait', now() + case when n > 0 then interval '60 seconds' else interval '0' end) returning fight_id into fid;
  insert into public.world_gw_members(fight_id, owner_id, name, job_key, level) values (fid, uid, c.character_name, c.job_key, c.level);
  for x in select b.owner_id from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id and b.owner_id <> a.owner_id
             join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null limit 3 loop
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (x.owner_id, 'gw_invite', '귀허의 주인 · 함께 싸우기', c.character_name || '이(가) 귀허의 주인 앞에 섰습니다. 60초 안에 합류하세요(귀허 부적 1개).', jsonb_build_object('fight_id', fid));
  end loop;
  if n = 0 then perform public.world_gw_start(fid); end if;
  return public.world_gw_snapshot(fid);
end $$;

create or replace function public.world_gw_join(p_fight uuid) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; f public.world_gw_fights%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if not found or f.status <> 'wait' or f.start_at <= now() then raise exception '합류할 수 있는 시간이 지났습니다.'; end if;
  if not exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id where a.owner_id = f.leader_id and b.owner_id = uid) then
    raise exception '도전을 연 조사원의 파티원만 합류할 수 있습니다.'; end if;
  if (select count(*) from public.world_gw_members where fight_id = p_fight) >= 4 then raise exception '귀허의 주인 앞에는 4명까지 설 수 있습니다.'; end if;
  c := public.world_gw_ready(uid);
  insert into public.world_gw_members(fight_id, owner_id, name, job_key, level) values (p_fight, uid, c.character_name, c.job_key, c.level) on conflict do nothing;
  if (select count(*) from public.world_gw_members where fight_id = p_fight) >= 4 then perform public.world_gw_start(p_fight); end if;
  return public.world_gw_snapshot(p_fight);
end $$;

create or replace function public.world_gw_begin(p_fight uuid) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_gw_fights where fight_id = p_fight and leader_id = uid and status = 'wait') then raise exception '도전을 연 조사원만 바로 시작할 수 있습니다.'; end if;
  perform public.world_gw_start(p_fight);
  return public.world_gw_snapshot(p_fight);
end $$;

-- 행동 고르기: a = attack·guard·item(i, t)·purify(t)·chain(c)
create or replace function public.world_gw_act(p_fight uuid, p_action text, p_target uuid default null, p_item text default null) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; a jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_action not in ('attack', 'guard', 'item', 'purify', 'chain') then raise exception '알 수 없는 행동입니다.'; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if not found or f.status <> 'fight' then raise exception '싸움이 끝났습니다.'; end if;
  if now() >= f.round_ends_at then perform public.world_gw_resolve(p_fight); select * into f from public.world_gw_fights where fight_id = p_fight; end if;
  if f.status <> 'fight' then return public.world_gw_snapshot(p_fight); end if;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = uid for update;
  if not found then raise exception '이 싸움에 들지 않았습니다.'; end if;
  if me.out_rounds > 0 then raise exception '물러나 있습니다. %라운드 뒤 돌아옵니다.', me.out_rounds; end if;
  if p_action = 'item' and coalesce(p_item, '') not in ('tonic', 'herbal_extract', 'rejuv_pill', 'grand_pill', 'banyo_salve') then raise exception '싸움 중에는 회복품만 쓸 수 있습니다.'; end if;
  if p_target is not null and not exists (select 1 from public.world_gw_members where fight_id = p_fight and owner_id = p_target) then raise exception '함께 싸우는 조사원이 아닙니다.'; end if;
  a := jsonb_build_object('a', p_action) || case when p_target is not null then jsonb_build_object('t', p_target) else '{}'::jsonb end
       || case when p_action = 'item' then jsonb_build_object('i', p_item) when p_action = 'chain' then jsonb_build_object('c', coalesce(p_item, '')) else '{}'::jsonb end;
  update public.world_gw_members set act = a where fight_id = p_fight and owner_id = uid;
  perform public.world_gw_resolve(p_fight);
  return public.world_gw_snapshot(p_fight);
end $$;

do $$ declare f text; begin
  foreach f in array array['world_gw_say(uuid,integer,text,text)', 'world_gw_ready(uuid)', 'world_gw_next_round(uuid)', 'world_gw_start(uuid)', 'world_gw_hurt(uuid,uuid,integer,integer,text)',
                           'world_gw_resolve(uuid)', 'world_gw_settle(uuid,boolean)', 'world_gw_snapshot(uuid)', 'world_gw_ready_check(uuid)', 'world_gw_tips()',
                           'world_gw_open()', 'world_gw_join(uuid)', 'world_gw_begin(uuid)', 'world_gw_act(uuid,text,uuid,text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
grant execute on function public.world_gw_snapshot(uuid), public.world_gw_open(), public.world_gw_join(uuid), public.world_gw_begin(uuid), public.world_gw_act(uuid,text,uuid,text) to authenticated;

-- 퀘스트 할 일 {t:'gw'}: 귀허의 주인 처치(행동을 한 번이라도 한 싸움)
select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)', '  select case when p_task ->> ''t'' = ''raid'' then',
  '  select case when p_task ->> ''t'' = ''gw'' then (select count(*)::int from public.world_gw_members m join public.world_gw_fights x on x.fight_id = m.fight_id
                where m.owner_id = p_uid and x.status = ''won'' and m.acts > 0 and x.ended_at >= p_since)
    when p_task ->> ''t'' = ''raid'' then');
grant select on public.world_gw_members, public.world_gw_fights to fn_owner_field;

-- 보상: 탈것·칭호·꾸미기(칭호·꾸미기는 gw_win 기록으로 판정)
insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method)
values ('moonless_boat', '달 없는 배', 2.4, 38, 0, 0, '귀허의 주인을 쓰러뜨린 조사원을 태우는 검은 배. 물길도 뭍도 소리 없이 미끄러진다. 운임은 구간당 노정패 1.', '영물', 2, 1, false, 'event')
on conflict (mount_id) do update set description = excluded.description, speed_multiplier = excluded.speed_multiplier;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
 ('gw_kill1', '귀허를 닫은 자', 'flag', '바다 끝의 소용돌이를 처음으로 닫았다.', '귀허의 주인을 쓰러뜨린다', '{"combat_damage_pct": 3, "erosion_pct": -6, "presence": 6}', true, false, '{"ev": "gw_win", "n": 1}', 1100, '외전', 5),
 ('gw_kill3', '빈 왕좌의 손님', 'flag', '빈 왕좌 앞에 세 번 섰다.', '귀허의 주인을 3번 쓰러뜨린다', '{"incoming_damage_pct": -3, "healing_pct": 4}', true, false, '{"ev": "gw_win", "n": 3}', 1101, '외전', 4),
 ('gw_kill10', '이송 명부를 고쳐 쓴 자', 'flag', '섬으로 보내진 이름들을 열 번 되찾았다.', '귀허의 주인을 10번 쓰러뜨린다', '{"combat_damage_pct": 2, "mental_loss_pct": -6}', true, false, '{"ev": "gw_win", "n": 10}', 1102, '외전', 5),
 ('gw_kill25', '귀허의 배웅꾼', 'flag', '반요촌의 배웅 노래가 이 이름을 부른다.', '귀허의 주인을 25번 쓰러뜨린다', '{"crit_pct": 2, "erosion_pct": -8, "rare_loot_pct": 3}', true, false, '{"ev": "gw_win", "n": 25}', 1103, '외전', 5),
 ('gw_solo', '홀로 이름을 지킨 자', 'flag', '아무도 곁에 없이 귀허의 주인을 쓰러뜨렸다.', '혼자 귀허의 주인을 쓰러뜨린다', '{"combat_damage_pct": 3, "evasion_pct": 2}', true, true, '{"ev": "gw_win", "p": {"solo": true}}', 1104, '외전', 5),
 ('gw_flawless', '한 사람도 잃지 않은 밤', 'flag', '누구 하나 물러나지 않고 귀허의 주인을 쓰러뜨렸다.', '둘 이상이 함께, 아무도 물러나지 않고 귀허의 주인을 쓰러뜨린다', '{"healing_pct": 5, "incoming_damage_pct": -3}', true, true, '{"ev": "gw_win", "p": {"flawless": true}}', 1105, '외전', 5)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade, hidden = excluded.hidden;
insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
 ('fr_gwiheo', 'frame', 'legend', '귀허 소용돌이 테', '귀허의 주인을 쓰러뜨린다', '외전', '{"ev": "gw_win"}', false, true, 1100),
 ('pt_gwiheo', 'pattern', 'legend', '달 없는 물결 무늬', '귀허의 주인을 3번 쓰러뜨린다', '외전', '{"ev": "gw_win", "n": 3}', false, true, 1101),
 ('sl_gwi', 'seal', 'legend', '낙관 「歸」', '귀허의 주인을 10번 쓰러뜨린다', '외전', '{"ev": "gw_win", "n": 10}', false, true, 1102)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, category = excluded.category;


-- ─────────────────────────────────────────────────────────────
-- 외전 「요인록」 5장(보조 퀘스트 틀, 분류 「외전·요인록」)
-- ─────────────────────────────────────────────────────────────
insert into public.world_quest_npcs(npc_key, npc_name, bio)
select x.npc_key, x.npc_name, x.bio from jsonb_to_recordset($J$[{"npc_key":"g_yeoul","npc_name":"여울","bio":"7년 전 요화해 섬으로 건너온 옛 야행국 조사원. 반요촌과 바깥을 잇는 길잡이. 왼쪽 손목부터 비늘이 돋았다."},{"npc_key":"g_mukho","npc_name":"묵호","bio":"반요촌 촌장. 사람이던 시절의 이름을 하루에 한 글자씩 잊어 간다. 문패를 고쳐 다는 것이 일과다."},{"npc_key":"g_dani","npc_name":"단이","bio":"섬에서 태어난 반요 아이. 바다 건너를 본 적이 없다. 어머니가 남긴 약 상자를 늘 메고 다닌다."},{"npc_key":"g_sagong","npc_name":"이름 잃은 사공","bio":"잿빛 갈대숲에서 노를 젓는 망령. 옛날에는 수향연맹의 뱃사공이었다."},{"npc_key":"g_juji","npc_name":"거울 속 주지","bio":"거꾸로 선 사당의 주지. 몸은 사라지고 연못에 비친 모습만 남았다."},{"npc_key":"g_lord","npc_name":"귀허의 주인","bio":"소용돌이 한가운데 빈 왕좌의 주인. 섬으로 보내진 모든 이름을 기억한다는 자."},{"npc_key":"g_memory","npc_name":"기억 조각","bio":"섬에 떠도는 누군가의 기억. 읽는 사람의 목소리로 들린다."}]$J$::jsonb) as x(npc_key text, npc_name text, bio text)
on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, sort, epilogue, active)
select x.quest_id, 'side', x.cat, x.title, x.summary, x.region_id, x.min_level, array(select jsonb_array_elements_text(x.after)), x.sort, x.epilogue, true from jsonb_to_recordset($J$[{"quest_id":"gq_1","cat":"외전·요인록","title":"반요촌의 밤","summary":"구중 봉연 아래 검은 물길 끝, 요화된 이들이 모여 사는 마을에 닿는다. 옛 조사원 여울이 기다리고 있다.","region_id":"banyo_village","min_level":30,"after":[],"sort":1000,"epilogue":[]},{"quest_id":"gq_2","cat":"외전·요인록","title":"갈대 속의 이름","summary":"잿빛 갈대숲의 사공은 사람들을 건너편에 데려다준다며 늘 같은 자리를 돈다. 물에 잠긴 말뚝마다 이름이 새겨져 있다.","region_id":"ash_reeds","min_level":32,"after":["gq_1"],"sort":1001,"epilogue":[]},{"quest_id":"gq_3","cat":"외전·요인록","title":"거꾸로 선 기도","summary":"섬에서 태어난 반요 아이 단이가 거꾸로 선 사당으로 사라졌다. 사당의 승려들은 잊히기를 빈다.","region_id":"inverted_shrine","min_level":34,"after":["gq_2"],"sort":1002,"epilogue":[]},{"quest_id":"gq_4","cat":"외전·요인록","title":"달 없는 장","summary":"달이 팔린 저잣거리에서 야행국 인장이 찍힌 장부가 나온다. 누가 섬으로 보내졌는지, 누가 그 명부를 썼는지가 적혀 있다.","region_id":"moonless_market","min_level":36,"after":["gq_3"],"sort":1003,"epilogue":[]},{"quest_id":"gq_5","cat":"외전·요인록","title":"귀허의 주인","summary":"모든 물이 돌아가는 바다 끝, 빈 왕좌에서 섬으로 보내진 이름을 모두 기억하는 자가 기다린다.","region_id":"gwiheo_core","min_level":38,"after":["gq_4"],"sort":1004,"epilogue":[{"s":null,"t":"반요촌에 새 문패가 걸린다. 이름이 두 개씩 적힌 문패 사이에 이름이 하나뿐인 문패가 있다. 「단이」."},{"s":"q:g_mukho","t":"첫 글자를 아직 기억하네. 오늘도."},{"s":"q:g_yeoul","t":"본부에 명부를 보낼 거야. 「귀허 이송 명부」 말고 「반요촌 주민 명부」. 받아 줄지는 모르겠지만."},{"s":"q:g_yeoul","t":"받아 주지 않아도 계속 보낼 거야. 반듯하게."},{"s":"q:g_dani","t":"바깥 사람, 또 와요. 다음엔 바다 냄새를 묻혀 올게요."},{"s":null,"t":"배웅 노래가 들린다. 그런데 오늘은 끝 소절이 다르다. 누군가 맞이하는 노래를 처음으로 짓고 있다."}]}]$J$::jsonb) as x(quest_id text, kind text, cat text, title text, summary text, region_id text, min_level int, after jsonb, sort int, epilogue jsonb, active boolean)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, epilogue = excluded.epilogue, active = excluded.active;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward)
select x.quest_id, x.step, x.title, x.goal, x.need, x.lines, x.reward from jsonb_to_recordset($J$[{"quest_id":"gq_1","step":1,"title":"검은 물길 끝","goal":"반요촌에 닿아 길잡이 여울을 만난다","need":{"at":["banyo_village"]},"lines":[{"s":null,"t":"나룻배가 바닥에 닿는다. 물이 아니라 재 위에 닿은 것처럼 소리가 없다."},{"s":null,"t":"비늘 지붕 아래 등불이 하나둘 켜진다. 문간에서 사람들이 이쪽을 본다. 손등에, 목덜미에, 비늘이 반짝인다."},{"s":"q:g_yeoul","t":"…야행국 인장이네. 봉연을 건너온 사람은 정말 오랜만이야."},{"s":null,"t":"여자가 소매를 걷는다. 왼쪽 손목부터 팔꿈치까지 푸른 비늘이 돋아 있다."},{"s":"q:g_yeoul","t":"놀라지 마. 여기선 다 이래. 나는 여울. 예전엔 너처럼 조사원이었지."},{"s":"me","t":"섬이 있다는 말은 들어 본 적이 없습니다."},{"s":"q:g_yeoul","t":"없지. 지도에서 지웠으니까."},{"s":null,"t":"여울이 웃는다. 웃음 끝이 조금 떨린다."},{"s":"q:g_yeoul","t":"촌장님이 보자고 하셔. 바깥 사람이 오면 늘 먼저 만나시거든. 이름을 물으실 거야. 천천히, 또박또박 말해 줘."}],"reward":{}},{"quest_id":"gq_1","step":2,"title":"두 개의 문패","goal":"잿빛 갈대숲에서 갈대 물귀신을 3번 쓰러뜨리고 반요 비늘 2개를 촌장에게 건넨다","need":{"at":["banyo_village"],"tasks":[{"t":"win","m":["gw_reed_1"],"n":3}],"give":{"banyo_scale":2}},"lines":[{"s":null,"t":"촌장 묵호는 문간에 쪼그려 앉아 문패를 고쳐 달고 있다. 문패에는 이름이 두 개씩 적혀 있다."},{"s":"q:g_mukho","t":"…손님이군. 미안하네. 자네 이름을 듣기 전에 내 이름부터 확인해야 해서."},{"s":null,"t":"노인이 문패 위쪽 이름을 손가락으로 짚는다. 먹이 번져 첫 글자가 보이지 않는다."},{"s":"q:g_mukho","t":"어제는 이 글자를 알았네. 오늘은 모르겠어. 내일은 둘째 글자를 잊겠지."},{"s":"q:g_mukho","t":"갈대숲 물귀신들이 마을 우물까지 올라와. 사람을 끌어가진 않지만… 끌려가고 싶은 사람이 생기거든."},{"s":"q:g_mukho","t":"그것들 비늘을 가져다주게. 지붕을 이을 게 모자라."},{"s":null,"t":"비늘을 받아 든 묵호가 한참 들여다본다."},{"s":"q:g_mukho","t":"이것도 누군가의 살갗이었겠지. 잘 이어 주겠네."}],"reward":{"xp":8280}},{"quest_id":"gq_1","step":3,"title":"배웅 노래","goal":"반요촌에서 여울과 이야기를 나눈다","need":{"at":["banyo_village"]},"lines":[{"s":null,"t":"밤이 깊다. 마을 끝 화로 앞에서 누군가 낮게 노래를 부른다. 떠나는 이를 배웅하는 노래다."},{"s":"q:g_yeoul","t":"여기엔 배웅 노래밖에 없어. 맞이하는 노래는 아무도 몰라."},{"s":"me","t":"여기 사람들은 왜 바깥으로 돌아가지 않습니까?"},{"s":"q:g_yeoul","t":"돌아갈 데가 없으니까. 침식이 여든을 넘으면 야행국은 「귀허 이송」을 했어. 반쯤 요괴가 된 사람을 배에 태워 이 섬으로."},{"s":null,"t":"화로 불꽃이 한 번 튄다. 여울이 손목의 비늘을 문지른다."},{"s":"q:g_yeoul","t":"나도 그 배를 탔어. 아니, 처음엔 그 배를 보내는 쪽이었지."},{"s":"q:g_yeoul","t":"…오늘은 여기까지 하자. 갈대숲에 가 봐. 이름을 부르는 소리가 들리면 대답하지 말고."}],"reward":{}},{"quest_id":"gq_1","step":4,"title":"기억 조각 · 첫 번째","goal":"기억 조각을 읽는다","need":{"at":["banyo_village"]},"lines":[{"s":null,"t":"잠자리 머리맡에 젖은 종잇조각 하나가 놓여 있다. 글씨가 읽는 사람의 목소리로 들린다."},{"s":"q:g_memory","t":"그날 침식은 아흔둘이었다. 거울을 보지 않아도 알았다. 숨을 쉴 때마다 목 안쪽이 서늘했다."},{"s":"q:g_memory","t":"동료가 정화 부적을 세 장이나 붙여 주었다. 네 번째 부적을 꺼낼 때 그의 손이 떨렸다. 나는 그 손을 잡아 내렸다."},{"s":"q:g_memory","t":"이송 명부에 내 이름을 적은 건 나였다. 내 글씨는 끝까지 반듯했다."},{"s":null,"t":"종이 아래쪽에 작은 글씨가 덧붙어 있다. 「여울」."}],"reward":{"gil":320,"items":{"banyo_salve":3,"reed_silk":2}}},{"quest_id":"gq_2","step":1,"title":"노 젓는 망령","goal":"잿빛 갈대숲에서 이름 잃은 사공을 만난다","need":{"at":["ash_reeds"]},"lines":[{"s":null,"t":"갈대가 바람도 없이 흔들린다. 바스락거리는 소리 사이로 누군가 이름을 부른다. 처음 듣는 이름이다. 그런데 대답하고 싶어진다."},{"s":null,"t":"안개 속에서 낡은 나룻배가 미끄러져 온다. 노를 쥔 손이 반쯤 비친다."},{"s":"q:g_sagong","t":"건너가시오? 건너편까지 모셔다 드리지. 값은 안 받소. 이름 하나만 주시오."},{"s":"me","t":"이름은 줄 수 없습니다."},{"s":"q:g_sagong","t":"…다들 그 말을 하더군. 그래도 결국엔 다 주고 갔소."},{"s":null,"t":"사공이 노를 멈춘다. 배는 움직이지 않는데 갈대는 뒤로 흘러간다."},{"s":"q:g_sagong","t":"내 이름은 저 말뚝 어딘가에 있소. 물에 잠겨 읽을 수가 없어. 찾아 주면… 건너편 얘기를 해 주지."}],"reward":{}},{"quest_id":"gq_2","step":2,"title":"잠긴 말뚝","goal":"잿빛 갈대숲을 4번 탐색하고 갈대 영사를 3개 거둔다","need":{"at":["ash_reeds"],"tasks":[{"t":"search","r":["ash_reeds"],"n":4},{"t":"gather","items":["reed_silk"],"r":["ash_reeds"],"n":3}]},"lines":[{"s":null,"t":"말뚝마다 이름이 새겨져 있다. 대부분 반쯤 물에 잠겼다. 물 위로 드러난 글자만 이어 읽으면 이상한 문장이 된다."},{"s":null,"t":"갈대 영사를 감아 물살을 거르자 잠긴 글자들이 조금씩 떠오른다. 「수향 나루 일번선 사공 □□」."},{"s":"q:g_sagong","t":"…수향. 그래, 수향이었지. 나는 나루에서 배를 몰았소."},{"s":"q:g_sagong","t":"야행국 사람들이 밤마다 손님을 데려왔지. 얼굴을 천으로 가린 손님들. 손목마다 비늘이 있었소."},{"s":"q:g_sagong","t":"나는 묻지 않았소. 묻지 말라고 웃돈을 받았으니까."},{"s":null,"t":"사공의 손이 떨린다. 노가 물을 친다. 처음으로 배가 앞으로 나아간다."}],"reward":{"xp":4646}},{"quest_id":"gq_2","step":3,"title":"건너편","goal":"이름 잃은 사공을 쓰러뜨려 놓아준다","need":{"at":["ash_reeds"],"tasks":[{"t":"win","m":["gw_reed_3"],"n":1}]},"lines":[{"s":"q:g_sagong","t":"마지막 손님이 내 아들이었소. 천을 벗기고서야 알았지."},{"s":"q:g_sagong","t":"그 애를 여기 내려 주고 나는 돌아가지 않았소. 돌아갈 수가 없었어."},{"s":null,"t":"흩어지는 사공의 윤곽 사이로 노 한 자루가 물에 떨어진다. 노에는 칼로 새긴 글자 두 개가 있다."},{"s":"me","t":"「한결」. 당신 이름입니까?"},{"s":null,"t":"대답 대신 갈대가 한꺼번에 숙인다. 이름을 부르던 소리가 멎는다."},{"s":"q:g_yeoul","t":"(뒤에서) …그 사공, 우리 배도 몰았어. 이제야 쉬네."}],"reward":{"xp":4646}},{"quest_id":"gq_2","step":4,"title":"기억 조각 · 두 번째","goal":"기억 조각을 읽는다","need":{"at":["ash_reeds"]},"lines":[{"s":null,"t":"물러난 물 위에 종잇조각이 떠 있다. 젖었는데도 글씨가 번지지 않는다."},{"s":"q:g_memory","t":"아들은 배에서 내리기 전에 천을 벗었다. 아버지 손은 차갑네, 하고 웃었다. 비늘이 덮인 제 손이 더 차가웠을 텐데."},{"s":"q:g_memory","t":"돌아가는 뱃길에서 나는 노를 놓았다. 배는 섬을 몇 바퀴 돌다가 갈대 사이에 멈췄다."},{"s":"q:g_memory","t":"그 뒤로 손님이 올 때마다 건너편까지 데려다주고 싶었다. 건너편이 어디인지 잊은 뒤에도."}],"reward":{"gil":340,"items":{"reed_silk":3,"yoin_blood":1,"oblivion_incense":2}}},{"quest_id":"gq_3","step":1,"title":"약 상자를 멘 아이","goal":"거꾸로 선 사당에서 단이를 찾는다","need":{"at":["inverted_shrine"]},"lines":[{"s":null,"t":"일주문이 거꾸로 박혀 있다. 기둥 끝이 하늘을 찌르고, 처마가 발밑에서 흙에 묻혀 있다."},{"s":null,"t":"향 연기가 위가 아니라 아래로 흐른다. 바닥에 닿은 연기가 천천히 고인다."},{"s":"q:g_dani","t":"쉿. 크게 걸으면 스님들이 깨요."},{"s":null,"t":"아이가 천장에서 거꾸로 매달린 채 이쪽을 내려다본다. 등에 메고 있는 약 상자가 아이 몸보다 크다."},{"s":"q:g_dani","t":"바깥 사람이죠? 냄새가 달라요. 바다 냄새가 안 나요."},{"s":"q:g_dani","t":"저는 단이예요. 여기서 태어났어요. 엄마는 의무관이었대요. 이 상자 엄마 거예요."},{"s":"me","t":"여기서 뭘 하고 있었니?"},{"s":"q:g_dani","t":"엄마 이름을 빌러 왔어요. 근데 여기 기도는 다 거꾸로 된대요. 기억해 달라고 빌면 잊힌대요."}],"reward":{}},{"quest_id":"gq_3","step":2,"title":"아래로 타는 향","goal":"거꾸로 매달린 동자를 3번 쓰러뜨리고 거꾸로 향목을 3개 거둔다","need":{"at":["inverted_shrine"],"tasks":[{"t":"win","m":["gw_shrine_1"],"n":3},{"t":"gather","items":["inverted_incense"],"r":["inverted_shrine"],"n":3}]},"lines":[{"s":null,"t":"매달린 동자들이 흩어질 때마다 목탁 소리가 하나씩 멎는다."},{"s":"q:g_juji","t":"(연못 속에서) 그 아이들도 잊히고 싶어서 여기 온 것이라오."},{"s":null,"t":"연못에 비친 늙은 승려가 합장한다. 연못 밖에는 아무도 없다."},{"s":"q:g_juji","t":"이 섬에 온 이들은 처음엔 기억되기를 빌었소. 바깥의 가족이 자기를 잊지 않기를."},{"s":"q:g_juji","t":"헌데 사당이 거꾸로 서자 기도도 거꾸로 이루어졌지. 그 뒤로는 모두 잊히기를 빌었소. 그래야 바깥 사람들이 덜 아플 테니."},{"s":"q:g_dani","t":"…저는 잊히기 싫어요. 엄마도 잊히기 싫었을 거예요."},{"s":null,"t":"단이가 거꾸로 향목 하나를 집어 바로 세운다. 연기가 처음으로 위로 오른다."}],"reward":{"xp":5181}},{"quest_id":"gq_3","step":3,"title":"종을 바로 세우다","goal":"거꾸로 선 범종귀를 쓰러뜨린다","need":{"at":["inverted_shrine"],"tasks":[{"t":"win","m":["gw_shrine_5"],"n":1}]},"lines":[{"s":null,"t":"범종이 마지막으로 거꾸로 운다. 소리가 귀가 아니라 발바닥으로 들어온다."},{"s":null,"t":"무너진 종 아래에서 녹슨 약 상자 자물쇠가 굴러 나온다. 단이의 상자와 꼭 맞는다."},{"s":"q:g_dani","t":"이거… 엄마 거예요. 엄마도 여기 왔었구나."},{"s":"q:g_juji","t":"그 의무관은 잊히기를 빌지 않았소. 아이가 자기를 기억해 주기를 빌었지. 거꾸로 선 사당에서 바로 빈 사람은 그이뿐이었소."},{"s":null,"t":"연못의 주지가 흐려진다. 처음으로 웃는 얼굴이다."},{"s":"q:g_juji","t":"종이 바로 섰으니 이제 바른 기도가 되겠구려. 아이야, 어미의 이름을 불러 보아라."},{"s":"q:g_dani","t":"…서연. 엄마 이름은 서연이에요."}],"reward":{"xp":5181}},{"quest_id":"gq_3","step":4,"title":"기억 조각 · 세 번째","goal":"기억 조각을 읽는다","need":{"at":["inverted_shrine"]},"lines":[{"s":null,"t":"약 상자 안쪽 뚜껑에 종잇조각이 붙어 있다. 아이 키 높이에 맞춰 낮게 붙여 두었다."},{"s":"q:g_memory","t":"이 섬에서 아이를 낳았다. 아이 손등에는 비늘이 없었다. 나는 그게 기뻤다가 무서웠다."},{"s":"q:g_memory","t":"여기서 비늘 없는 아이는 바깥으로도 섬으로도 갈 곳이 없다. 그래서 상자에 약을 채웠다. 어느 쪽에서든 누군가를 고칠 수 있게."},{"s":"q:g_memory","t":"단이야, 네가 이걸 읽을 때쯤 엄마는 아마 네 이름을 잊었을 거야. 대신 네가 엄마를 기억해 줘. 거꾸로 선 사당에서는 그게 바른 기도란다."}],"reward":{"gil":360,"items":{"inverted_incense":3,"yoin_blood":1,"banyo_salve":3}}},{"quest_id":"gq_4","step":1,"title":"지워진 장부","goal":"달 없는 저잣거리를 4번 탐색해 야행국 장부를 찾는다","need":{"at":["moonless_market"],"tasks":[{"t":"search","r":["moonless_market"],"n":4}]},"lines":[{"s":null,"t":"꺼진 청사초롱이 끝없이 늘어선 거리. 좌판마다 손님이 서 있지만 얼굴이 없다. 갓 아래가 비어 있다."},{"s":null,"t":"흥정하는 소리가 들린다. 값을 부르는 것은 전이 아니다. 「첫 눈 오던 날 한 번」, 「어머니 목소리 두 번」."},{"s":null,"t":"네 번째 골목 끝, 먼지 앉은 좌판 위에 장부 한 권이 놓여 있다. 표지에 야행국 본부 인장이 찍혀 있다. 「귀허 이송 명부」."},{"s":null,"t":"장을 넘긴다. 이름, 침식 수치, 이송 날짜. 이름마다 줄이 그어져 있다. 줄 옆에 같은 글씨로 「잔여 없음」."},{"s":"q:g_yeoul","t":"…찾았구나."},{"s":null,"t":"여울이 좌판 너머에 서 있다. 얼굴이 하얗다."}],"reward":{"xp":3830}},{"quest_id":"gq_4","step":2,"title":"기억 저울","goal":"기억 저울 장수를 쓰러뜨리고 망각 수정을 3개 거둔다","need":{"at":["moonless_market"],"tasks":[{"t":"win","m":["gw_market_3"],"n":1},{"t":"gather","items":["oblivion_crystal"],"r":["moonless_market"],"n":3}]},"lines":[{"s":null,"t":"저울 장수가 쓰러지자 저울 접시에 올려 두었던 기억들이 망각 수정이 되어 굴러떨어진다."},{"s":null,"t":"수정 하나를 들어 올린다. 낯선 얼굴이 비친다. 젊은 조사원이 붓을 들고 장부에 이름을 적고 있다. 글씨가 반듯하다."},{"s":"q:g_yeoul","t":"그건 내 기억이야. 팔아 치웠는데, 여기 남아 있었네."},{"s":"q:g_yeoul","t":"본부 기록감찰국 서리였어. 침식 수치가 여든을 넘은 사람 이름을 받아 적었지. 그게 내 일이었어."},{"s":"q:g_yeoul","t":"여든에서 아흔 사이는 아직 사람이었어. 잘 쉬면 돌아오는 사람도 있었고. 그래도 적었어. 위에서 「잔여 없음」으로 정리하라고 했으니까."},{"s":"me","t":"그 위가 누구였습니까?"},{"s":"q:g_yeoul","t":"…귀허에 가면 알 거야. 그 사람도 결국 여기로 왔거든."}],"reward":{"xp":3830}},{"quest_id":"gq_4","step":3,"title":"여울의 이름","goal":"반요촌으로 돌아가 묵호에게 장부를 보이고 망각 수정 1개를 건넨다","need":{"at":["banyo_village"],"give":{"oblivion_crystal":1}},"lines":[{"s":null,"t":"묵호가 장부를 한 장씩 넘긴다. 한 장에서 손이 멈춘다."},{"s":"q:g_mukho","t":"…여기 있구먼. 내 이름."},{"s":null,"t":"줄 그어진 이름 위를 노인의 손가락이 천천히 지난다. 문패에서 잊어버린 첫 글자가 장부에는 또렷하다."},{"s":"q:g_mukho","t":"자네가 적었나, 여울."},{"s":"q:g_yeoul","t":"네. 제가 적었습니다."},{"s":null,"t":"긴 침묵. 화로 불꽃이 두 번 튄다."},{"s":"q:g_mukho","t":"반듯하게도 적었군. 덕분에 오늘은 첫 글자를 읽었네. 고맙네."},{"s":null,"t":"묵호가 망각 수정을 화로에 넣는다. 수정이 녹으며 문패의 번진 먹이 다시 또렷해진다."},{"s":"q:g_mukho","t":"귀허에 가거든 주인에게 전해 주게. 이 섬 사람들은 아직 이름이 있다고."}],"reward":{"xp":3830}},{"quest_id":"gq_4","step":4,"title":"기억 조각 · 네 번째","goal":"기억 조각을 읽는다","need":{"at":["banyo_village"]},"lines":[{"s":null,"t":"장부 마지막 장 뒤에 접힌 종이가 끼어 있다."},{"s":"q:g_memory","t":"「귀허 이송」을 처음 제안한 이는 본부 국장이었다. 섬으로 보내면 바깥은 안전해진다고. 이송된 자들은 「잔여 없음」으로 기록하라고."},{"s":"q:g_memory","t":"국장의 침식이 여든을 넘던 날, 그는 자기 이름을 스스로 명부에 적었다. 그리고 첫 배를 탔다."},{"s":"q:g_memory","t":"그가 섬에 닿은 뒤로 귀허의 소용돌이가 생겼다고 반요촌 사람들은 말한다. 바깥이 잊은 이름들을 모두 끌어모으는 소용돌이가."}],"reward":{"gil":380,"items":{"gwiheo_charm":1,"oblivion_crystal":2,"moonless_silk":2}}},{"quest_id":"gq_5","step":1,"title":"바다 끝","goal":"귀허에 닿는다","need":{"at":["gwiheo_core"]},"lines":[{"s":null,"t":"발밑의 돌길이 천천히 가라앉는다. 한 걸음 멈출 때마다 물이 발목까지 차오른다."},{"s":null,"t":"소용돌이 한가운데 왕좌 하나가 떠 있다. 비어 있다. 그런데 누군가 앉아 있는 것처럼 물살이 그 둘레를 비켜 돈다."},{"s":"q:g_yeoul","t":"여기까지 와 준 바깥 사람은 처음이야."},{"s":"q:g_yeoul","t":"문지기가 있어. 거울 몸이라 때리면 되튕겨. 그걸 넘어야 왕좌 앞에 설 수 있어."},{"s":"q:g_dani","t":"(약 상자를 고쳐 메며) 저도 갈래요. 다치면 제가 고쳐 줄게요."},{"s":"q:g_yeoul","t":"…그래. 같이 가자."}],"reward":{}},{"quest_id":"gq_5","step":2,"title":"문지기","goal":"귀허의 문지기를 쓰러뜨린다","need":{"at":["gwiheo_core"],"tasks":[{"t":"win","m":["gw_core_5"],"n":1}]},"lines":[{"s":null,"t":"문지기의 거울 몸이 부서진다. 조각마다 다른 얼굴이 비친다. 모두 반요촌 문패에서 본 이름들이다."},{"s":null,"t":"마지막 조각에 늙은 남자의 얼굴이 비친다. 야행국 본부 대청에 걸린 초상화와 같은 얼굴이다."},{"s":"q:g_yeoul","t":"국장님."},{"s":null,"t":"소용돌이가 멈춘다. 빈 왕좌 위로 물이 솟아 사람 꼴이 된다."},{"s":"q:g_lord","t":"오랜만이구나, 서리. 반듯한 글씨는 여전하냐."},{"s":"q:g_lord","t":"그리고 너는… 야행국 인장이군. 아직도 그 문을 지키느냐."},{"s":"q:g_lord","t":"나는 이 섬으로 보낸 모든 이름을 기억한다. 바깥이 잊었으니 누군가는 기억해야 했다. 그 이름들을 모두 끌어모아 바깥으로 되돌려 보낼 것이다. 침식째로."},{"s":"me","t":"그러면 바깥 사람들이 모두 요화합니다."},{"s":"q:g_lord","t":"그래야 공평하지 않으냐."}],"reward":{"xp":6338}},{"quest_id":"gq_5","step":3,"title":"귀허를 닫다","goal":"귀허 부적을 지니고 귀허의 주인을 쓰러뜨린다","need":{"at":["gwiheo_core"],"tasks":[{"t":"gw","n":1}]},"lines":[{"s":null,"t":"소용돌이가 잦아든다. 왕좌 위의 물이 사람 꼴을 잃고 천천히 흘러내린다."},{"s":"q:g_lord","t":"…이름을 하나만 다오. 내가 기억하지 못한 이름이 하나라도 있느냐."},{"s":"q:g_dani","t":"단이. 저는 여기서 태어났어요. 바깥에서 보내진 적 없어요."},{"s":null,"t":"흘러내리던 물이 멈춘다. 노인의 얼굴이 아이를 내려다본다."},{"s":"q:g_lord","t":"…그렇구나. 이 섬에서 난 이름도 있었구나. 나는 보내진 이름만 세었다."},{"s":"q:g_lord","t":"서리. 명부를 다시 써라. 「잔여 없음」 말고. 남은 이들의 이름을."},{"s":"q:g_yeoul","t":"네. 반듯하게 쓰겠습니다."},{"s":null,"t":"물이 바다로 돌아간다. 소용돌이가 있던 자리에 처음으로 달빛 비슷한 것이 비친다."},{"s":null,"t":"반요촌에 새 문패가 걸린다. 이름이 두 개씩 적힌 문패 사이에 이름이 하나뿐인 문패가 있다. 「단이」."},{"s":"q:g_mukho","t":"첫 글자를 아직 기억하네. 오늘도."},{"s":"q:g_yeoul","t":"본부에 명부를 보낼 거야. 「귀허 이송 명부」 말고 「반요촌 주민 명부」. 받아 줄지는 모르겠지만."},{"s":"q:g_yeoul","t":"받아 주지 않아도 계속 보낼 거야. 반듯하게."},{"s":"q:g_dani","t":"바깥 사람, 또 와요. 다음엔 바다 냄새를 묻혀 올게요."},{"s":null,"t":"배웅 노래가 들린다. 그런데 오늘은 끝 소절이 다르다. 누군가 맞이하는 노래를 처음으로 짓고 있다."}],"reward":{"xp":6338,"gil":400,"items":{"gwiheo_pearl":1,"yoin_blood":3}}}]$J$::jsonb) as x(quest_id text, step int, title text, goal text, need jsonb, lines jsonb, reward jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;

-- ─────────────────────────────────────────────────────────────
-- G. 편의·밸런스
-- ─────────────────────────────────────────────────────────────

-- ① 귀령초: 확률을 크게 낮추고(일반 0.02%·정예 0.08%·우두머리 0.3%·구중 봉연 우두머리·합동 토벌/결전·귀허의 주인 1%·채집 0.02%·원정 완주 0.15%, 위험도 10 ×1.5),
--    한 번 얻으면 72시간 다시 안 나오며, 서버 전체 7일 몫 = 지난 7일 요화가 걸린 수의 절반(최소 1)
create table if not exists public.world_gwiryeong_log (id bigserial primary key, owner_id uuid not null, got_at timestamptz not null default now(), source text);
create index if not exists world_gwiryeong_log_at on public.world_gwiryeong_log(got_at);
alter table public.world_gwiryeong_log enable row level security;
revoke all on public.world_gwiryeong_log from anon, authenticated;
grant select, insert on public.world_gwiryeong_log to fn_owner_field;
grant usage on sequence public.world_gwiryeong_log_id_seq to fn_owner_field;

create or replace function public.world_gwiryeong_chance(p_type text, p_payload jsonb) returns numeric
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  with reg as (
    select r.danger_level from public.world_map_regions r
     where r.region_id = coalesce(p_payload ->> 'region_id',
       (select n.region_id from public.world_exploration_nodes n
         where n.node_id = case when p_payload ->> 'node_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (p_payload ->> 'node_id')::uuid end))
  )
  select case when p_type in ('gw_win', 'raid_win') then 0.01 else coalesce((select least(0.01, case when reg.danger_level < 7 then 0 else
      case p_type
        when 'gather' then 0.0002
        when 'expedition_end' then case when p_payload ->> 'ended' = 'complete' then 0.0015 else 0 end
        when 'combat' then case when not coalesce((p_payload ->> 'defeated')::boolean, false) then 0
          when p_payload ->> 'region_id' = 'sealed_abyss' and p_payload ->> 'rank' = 'guardian' then 0.01
          else case p_payload ->> 'rank' when 'guardian' then 0.003 when 'elite' then 0.0008 else 0.0002 end end
        else 0 end * case when reg.danger_level >= 10 then 1.5 else 1 end end) from reg), 0) end
$$;

-- 72시간·서버 7일 몫을 확인하고 한 몫을 적어 둔다(얻는 모든 길이 이것을 거친다: 기록 트리거·토벌 트리거·기술 「영초 감별」)
create or replace function public.world_gwiryeong_reserve(p_uid uuid, p_source text) returns boolean
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare cap int;
begin
  if p_uid is null then return false; end if;
  if exists (select 1 from public.world_gwiryeong_log l where l.owner_id = p_uid and l.got_at > now() - interval '72 hours') then return false; end if;
  perform pg_advisory_xact_lock(hashtext('yh-gwiryeong-week'));
  cap := greatest(1, (select count(*) from public.world_yohwa_log y where y.kind = 'onset' and y.at > now() - interval '7 days')::int / 2);
  if (select count(*) from public.world_gwiryeong_log l where l.got_at > now() - interval '7 days') >= cap then return false; end if;
  insert into public.world_gwiryeong_log(owner_id, source) values (p_uid, p_source);
  return true;
end $$;
create or replace function public.world_gwiryeong_give(p_uid uuid, p_chance numeric, p_source text) returns boolean
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if p_uid is null or coalesce(p_chance, 0) <= 0 or random() >= p_chance then return false; end if;
  if not exists (select 1 from public.world_characters where owner_id = p_uid) then return false; end if;
  if not public.world_gwiryeong_reserve(p_uid, p_source) then return false; end if;
  update public.world_characters set inventory = public.world_inv_add(coalesce(inventory, '{}'::jsonb), 'gwiryeong_cho', 1), updated_at = now() where owner_id = p_uid;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_uid, 'reward', '귀령초를 찾았습니다',
    '음습한 기운 사이에서 귀령초 한 포기를 찾았습니다. 요화를 다스리는 귀한 풀입니다(가방이 가득 찼다면 넘친 만큼은 버려집니다).',
    jsonb_build_object('item_id', 'gwiryeong_cho', 'qty', 1, 'source', p_source));
  return true;
end $$;
create or replace function public.world_gwiryeong_roll() returns trigger
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if new.actor_id is null then return new; end if;
  perform public.world_gwiryeong_give(new.actor_id, public.world_gwiryeong_chance(new.event_type, coalesce(new.payload, '{}'::jsonb)), new.event_type);
  return new;
end $$;
drop trigger if exists trg_world_gwiryeong_roll on public.world_events;
create trigger trg_world_gwiryeong_roll after insert on public.world_events for each row
  when (new.event_type = any (array['gather', 'combat', 'expedition_end', 'gw_win'])) execute function public.world_gwiryeong_roll();
-- 합동 토벌·10장 결전 승리: 싸운 사람마다 1%
create or replace function public.world_gwiryeong_raid_trg() returns trigger
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare m record;
begin
  for m in select owner_id from public.world_raid_members where raid_id = new.raid_id and acts > 0 loop
    perform public.world_gwiryeong_give(m.owner_id, public.world_gwiryeong_chance('raid_win', '{}'::jsonb), 'raid_' || new.kind);
  end loop;
  return new;
end $$;
drop trigger if exists trg_world_gwiryeong_raid on public.world_raids;
create trigger trg_world_gwiryeong_raid after update of status on public.world_raids for each row
  when (new.status = 'won' and old.status is distinct from 'won') execute function public.world_gwiryeong_raid_trg();
do $$ declare f text; begin
  foreach f in array array['world_gwiryeong_chance(text,jsonb)', 'world_gwiryeong_reserve(uuid,text)', 'world_gwiryeong_give(uuid,numeric,text)', 'world_gwiryeong_roll()', 'world_gwiryeong_raid_trg()'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn_owner%' loop execute format('grant execute on function public.world_gwiryeong_reserve(uuid,text) to %I', r); end loop;
end $$;
-- 기술 「영초 감별」도 같은 몫을 거친다(0.6% → 0.2%), 봉연의 그림자 정산의 따로 굴리던 1%는 빼고 위 토벌 트리거 하나로
select pg_temp.yh_patch('public.world_field_gather(uuid)', 'AND random() < 0.006 THEN extra := public.world_inv_add(extra, ''gwiryeong_cho'', 1);',
  'AND random() < 0.002 AND public.world_gwiryeong_reserve(uid, ''skill_herbalism'') THEN extra := public.world_inv_add(extra, ''gwiryeong_cho'', 1);');
select pg_temp.yh_patch('public.world_raid_settle(uuid,boolean)', '          if random() < 0.01 then items := items || jsonb_build_object(''gwiryeong_cho'', 1); end if;
', '');
update public.world_skill_catalog set description = '택일 기술 · 위험도 7 이상 지역에서 약초를 거둘 때 0.2% 확률로 귀령초(한 번 얻으면 72시간 다시 나오지 않음)' where skill_id = 'herbalism_c43b';
-- 조사 지점의 희귀 보너스에 섞여 있던 귀령초를 뺀다(위 판정 밖에서 나오던 길)
update public.world_region_sites set rare_bonus = jsonb_set(rare_bonus, '{items}', (select coalesce(jsonb_agg(x), '[]'::jsonb) from jsonb_array_elements(rare_bonus -> 'items') x where x #>> '{}' <> 'gwiryeong_cho'))
 where rare_bonus -> 'items' @> '["gwiryeong_cho"]'::jsonb;
-- 화면이 쓰지 않는 옛 조사 지점 함수(world_region_explore)는 실행 권한을 거둔다(함수는 남김)
do $$ declare o text; begin
  o := pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_region_explore(text,text)'::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute format('set role %I', o);
  revoke execute on function public.world_region_explore(text,text) from public, anon, authenticated;
  reset role;
end $$;
update public.world_item_catalog set description = '위험도 7 이상 지역에서 아주 드물게 찾는 음습한 풀. 요화를 풀고 침식을 20 낮춘다.' where item_id = 'gwiryeong_cho';

-- ② 수향연맹 뱃길: 동승해서 갈 때도 배 속도(등급 보정)를 쓴다
select pg_temp.yh_patch('public.world_travel_party_respond_v2(uuid,boolean)', '   /coalesce(speed,1))::int));', '   /(coalesce(speed,1)*public.world_river_boat_speed(q.leader_id, c.mount_id)))::int));');
select pg_temp.yh_patch('public.world_travel_party_respond_v2(uuid,boolean)', ' select case when coalesce(m.fare_free,false) then 0',
  ' select case when coalesce(m.fare_free,false) or public.world_river_boat_member(q.leader_id, m.mount_id) then 0');

-- ③ 외래어: 퀘스트 제목 · 서버 안내문의 「아이템」
update public.world_quests set title = '얼음 밑의 두드림' where title = '얼음 밑의 노크';
do $$ declare f record; n int; begin
  for f in select p.oid::regprocedure::text sig, (length(pg_get_functiondef(p.oid)) - length(replace(pg_get_functiondef(p.oid), '아이템', ''))) / length('아이템') k
             from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and pg_get_functiondef(p.oid) like '%아이템%' loop
    perform pg_temp.yh_patch(f.sig, '아이템', '물품', f.k);
  end loop;
end $$;

-- ④ 모임 순서: 내 화면의 모임 순서를 서버에 저장한다(채팅의 모임 단추 줄·동료 화면 모임 목록)
alter table public.world_circle_members add column if not exists sort int;
select pg_temp.yh_patch('public.world_circle_snapshot()', ') order by m.joined_at)', ') order by m.sort nulls last, m.joined_at)');
create or replace function public.world_circle_reorder(p_ids uuid[]) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if coalesce(cardinality(p_ids), 0) > 10 then raise exception '모임이 너무 많습니다.'; end if;
  update public.world_circle_members m set sort = x.o from unnest(p_ids) with ordinality x(id, o) where m.owner_id = uid and m.circle_id = x.id;
  return jsonb_build_object('ok', true);
end $$;
alter function public.world_circle_reorder(uuid[]) owner to fn_owner_field;
revoke all on function public.world_circle_reorder(uuid[]) from public, anon, authenticated;
grant execute on function public.world_circle_reorder(uuid[]) to authenticated;
grant update (sort) on public.world_circle_members to fn_owner_field;

-- ⑤ 알림 종류별 켜고 끄기: 꺼 둔 갈래의 알림은 들어올 때 읽음으로 두어 화면에 띄우지 않는다(지난 알림에는 남음)
create table if not exists public.world_notify_prefs (owner_id uuid primary key, off text[] not null default '{}', updated_at timestamptz not null default now());
alter table public.world_notify_prefs enable row level security;
revoke all on public.world_notify_prefs from anon, authenticated;
grant select, insert, update on public.world_notify_prefs to fn_owner_field;
create or replace function public.world_notify_group(p_kind text) returns text
language sql immutable set search_path to 'pg_catalog' as $$
  select case
    when p_kind in ('title', 'cosmetic') then 'title'
    when p_kind in ('reward', 'skill_rerank') then 'reward'
    when p_kind in ('bag_full', 'bag_overflow') then 'bag'
    when p_kind in ('rescue_request') then 'rescue'
    when p_kind in ('friend_down') then 'friend_rescue'
    when p_kind in ('trade_offer', 'trade_result') then 'trade'
    when p_kind in ('friend_request', 'friend_accepted') then 'friend'
    when p_kind in ('party_invite', 'party_expedition', 'party_exp_offer', 'party_leave', 'party_aid') then 'party'
    when p_kind in ('circle_invite') then 'circle'
    when p_kind in ('spar_request', 'spar_result') then 'spar'
    when p_kind like 'bond%' then 'bond'
    when p_kind in ('faction') then 'faction'
    when p_kind in ('raid_invite', 'raid', 'gw', 'gw_invite') then 'raid'
    else null end   -- 운영 공지·제보 답장·요화·원정 같은 것은 끌 수 없다
$$;
create or replace function public.world_notify_prefs_trg() returns trigger
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare g text := public.world_notify_group(new.kind);
begin
  if g is not null and new.read_at is null and exists (select 1 from public.world_notify_prefs p where p.owner_id = new.user_id and g = any (p.off)) then
    new.read_at := now();
  end if;
  return new;
end $$;
drop trigger if exists trg_world_notify_prefs on public.world_notifications;
create trigger trg_world_notify_prefs before insert on public.world_notifications for each row execute function public.world_notify_prefs_trg();
create or replace function public.world_notify_prefs_get() returns jsonb
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select jsonb_build_object('off', coalesce((select to_jsonb(off) from public.world_notify_prefs where owner_id = public.fn_owner_auth_uid()), '[]'::jsonb))
$$;
create or replace function public.world_notify_prefs_set(p_off text[]) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); v text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select coalesce(array_agg(distinct x), '{}') into v from unnest(coalesce(p_off, '{}')) x
   where x in ('title', 'reward', 'bag', 'rescue', 'friend_rescue', 'trade', 'friend', 'party', 'circle', 'spar', 'bond', 'faction', 'raid');
  insert into public.world_notify_prefs(owner_id, off, updated_at) values (uid, v, now())
  on conflict (owner_id) do update set off = excluded.off, updated_at = now();
  return jsonb_build_object('ok', true, 'off', to_jsonb(v));
end $$;
do $$ declare f text; begin
  foreach f in array array['world_notify_group(text)', 'world_notify_prefs_trg()', 'world_notify_prefs_get()', 'world_notify_prefs_set(text[])'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
grant execute on function public.world_notify_prefs_get(), public.world_notify_prefs_set(text[]) to authenticated;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn_owner%' loop execute format('grant execute on function public.world_notify_group(text) to %I', r); end loop;
end $$;

-- ⑥ 친구가 쓰러지면 다른 곳에 있는 친구에게도 알림(friend_down, 알림 설정 「친구 구조」로 끔). 같은 곳의 조사원은 지금처럼 긴급 구조 요청을 받는다
grant select on public.world_friends to fn_owner_18987;
select pg_temp.yh_patch('public.world_notify_downed()', '  insert into public.world_chat_messages(channel_type,sender_id,sender_name,content) values(''global'',new.owner_id,''구조 알림'',
    new.character_name||'' 조사원이 ''||coalesce(new.location,''어딘가'')||''에서 쓰러졌습니다.',
  '  for rec in select distinct c.owner_id from public.world_friends f
                 join public.world_characters c on c.owner_id = case when f.owner_id = new.owner_id then f.friend_id else f.owner_id end
                where f.status = ''accepted'' and new.owner_id in (f.owner_id, f.friend_id)
                  and not (c.location = new.location and c.health > 0 and c.downed_at is null) loop
   insert into public.world_notifications(user_id,kind,title,content,payload) values(rec.owner_id,''friend_down'',''친구 구조 요청'',new.character_name||'' 조사원이 ''||coalesce(new.location,''어딘가'')||''에서 쓰러졌습니다. 가서 구조할 수 있습니다.'',jsonb_build_object(''target_id'',new.owner_id,''target_name'',new.character_name,''location'',new.location,''created_at'',now()));
  end loop;
  insert into public.world_chat_messages(channel_type,sender_id,sender_name,content) values(''global'',new.owner_id,''구조 알림'',
    new.character_name||'' 조사원이 ''||coalesce(new.location,''어딘가'')||''에서 쓰러졌습니다.');

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


-- ─── 패치노트 7.0.0 ───
insert into public.world_patch_notes(note_id, title, body)
select '7.0.0', '7.0.0 · 귀허도와 요인록', $N$
## 최고 레벨 40
- 최고 레벨이 **30 → 40**이 되었습니다. 다음 레벨까지 필요한 경험치 식은 그대로입니다(Lv30 13,800 · Lv39 22,152).
- 쌓아 둘 수 있는 능력치 포인트도 레벨에 맞춰 늘었습니다.
- **기술 30단계부터는 다음 단계까지 필요한 경험이 더 늘어납니다**(누적 40단계 11,670 · 50단계 30,940). 50단계는 최고 레벨 무렵에 닿습니다. 탐색 한 번에 오르는 추적 경험은 8에서 5로 줄었습니다.
- 이미 높은 단계였던 분은 쌓은 경험은 그대로 두고 단계만 새 기준으로 다시 매겼습니다. 바뀐 분께는 알림을 드렸고, 다시 오르면 그 단계 기술도 바로 살아납니다(고른 택일 기술은 그대로).
- 구중 봉연·무극 관성대의 깊은 곳은 원래대로 깊이마다 레벨이 2씩 올라갑니다.

## 귀허도(歸墟島)
- 10장 「구중 봉연」을 마치면 구중 봉연 아래 검은 물길 너머로 **귀허도**가 지도에 나타납니다. 그 전에는 보이지 않습니다.
- 반요촌(안전지대) · 잿빛 갈대숲(Lv30) · 거꾸로 선 사당(Lv33) · 달 없는 저잣거리(Lv36) · 귀허(Lv38). 지역마다 답사 길·채집터·요괴·원정지·조사 지점이 있고, 갈대숲과 귀허에는 낚시터도 있습니다.
- 섬에서는 **침식이 바깥보다 빨리 쌓입니다**. 대신 섬에 있는 동안은 요화가 다음 단계로 넘어가지 않습니다.
- **반요촌**은 빈약한 안전지대입니다: 상점 품목이 적고 값이 비싸며 사람마다 하루에 살 수 있는 개수가 정해져 있습니다. 되팔면 절반 값이고, 대장간 수리비가 세 배입니다. 거래소·창고·마구간은 없습니다. 귀허 부적·반요 고약·망각 향은 여기서만 팝니다. 화살·쇠뇌살·취관 침은 늘 팝니다.
- 섬 재료 8가지(갈대 영사·거꾸로 향목·망각 수정·무월 비단·귀허 흑철·반요 비늘·요인 혈정·귀허 진주)로 **6단계 장비 33가지**(Lv32)를 만듭니다. 섬 요괴에게서도 드물게 떨어집니다.

## 외전 「요인록(妖人錄)」
- 섬으로 보내진 사람들의 이야기 5장입니다(일지 › 보조 퀘스트 › 외전). 1장 「반요촌의 밤」은 반요촌에서 시작합니다.
- 장마다 끝에 누군가의 기억 조각이 남아 있습니다.

## 최종 보스 「귀허의 주인」
- 외전 4장을 마치고 Lv38이 되면 귀허에서 도전할 수 있습니다. 혼자 또는 같은 곳의 파티원 4명까지, 모두 귀허 부적을 하나씩 씁니다. **4명을 권하고, 둘이면 매우 어렵고, 혼자서는 거의 불가능합니다.**
- **라운드 전투**입니다. 라운드마다 행동 하나를 고르고(고르지 않으면 방어), 마감이 되거나 모두 고르면 한꺼번에 풀립니다. 주인이 기술을 쓰면 화면에 남은 시간이 보입니다.
- 어떻게 막는지는 알려 드리지 않습니다. 기술 이름과 낌새만 보이고, 쓰러뜨린 분만 파훼법을 볼 수 있습니다.
- 실패하면 장착한 장비가 조금 닳고 침식이 오르며, 30분 뒤에 다시 도전할 수 있습니다. 경험치·물품은 잃지 않습니다.
- 처치는 하루 한 번 인정합니다. 처음 쓰러뜨리면 칭호·테두리·이름 색·탈것 「달 없는 배」를 받고, 그 뒤에는 처치 횟수에 따라 칭호와 꾸미기가 더해집니다.

## 생활 도구
- 채집 도구는 능력치 대신 **숙련 단계**로 장착합니다: 강화 채집도·영맥 낫·영등 채집 숙련 2단계, 약초꾼 망태 3, 청강 채집도 4, 영맥 곡괭이 6, 천공 채집도 8, 귀허 흑철 채집도 12, 영맥 나침반은 조사 숙련 10단계(레벨 조건은 그대로). 각인 공구는 조건이 없습니다.
- **곡괭이**는 광맥·유물 채집터에서, **채집도**는 약초·목재·보급품·물가 채집터에서 채집량이 10% 더 붙습니다.
- **영맥 낫**: 약초·영기 채집터에서 3% 확률로 그 지역 희귀품을 함께 거둡니다. **영등**: 유물 채집터나 사당·지하·심연 같은 어두운 지역에서 5%.
- **영맥 나침반**: 도구 칸에 장착하면 탐색할 때 숨은 길·채집터를 찾을 확률이 20% 오릅니다.
- 강화 채집도의 채집량이 +5%에서 +8%로 올랐습니다. 도구 설명을 실제 효과대로 고쳤습니다.

## 편의
- 귀령초가 나오는 확률을 낮추고, 한 번 얻으면 72시간 동안 다시 나오지 않게 했습니다. 서버 전체로도 일주일에 나오는 수가 정해져 있습니다. 택일 기술 「영초 감별」은 0.6%에서 0.2%로 바뀌고 같은 제한을 받습니다.
- 설정 › 알림에서 **알림 종류별로 켜고 끌 수 있습니다**(끈 알림은 지난 알림에만 남습니다).
- 친구가 쓰러지면 다른 곳에 있어도 「친구 구조 요청」 알림이 옵니다. 설정 › 알림의 「친구 구조」에서 끌 수 있습니다.
- 채팅의 지역·파티·세력 칸에도 새 말이 오면 빨간 점이 찍힙니다(전체·모임처럼). 새로 서버에 묻지 않고 이미 받고 있는 실시간 소식으로만 셉니다.
- 동료 화면의 모임 칸에서 위·아래 단추로 **모임 순서를 바꿀 수 있습니다**(채팅의 모임 단추 줄도 같은 순서).
- 수향연맹 배를 타고 동승해 갈 때도 뱃길 속도가 붙습니다.
- 창고에서도 장비·소모품·재료 분류로 거르고 이름으로 찾을 수 있습니다(제보 18, 장아찌 님 감사합니다).
- 로그인 화면에 놓치기 쉬운 것을 한 줄씩 알려 드립니다.
- 퀘스트 「얼음 밑의 노크」를 「얼음 밑의 두드림」으로, 안내문의 「아이템」을 「물품」으로 바꿨습니다.
$N$
 where not exists (select 1 from public.world_patch_notes where note_id = '7.0.0');

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261101000000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
