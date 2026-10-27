-- 원정 개편(2026-10-28 결정): 원정 → 탐색 → 원정으로 이어지는 순환과 원정 전용 보상, 노정패 쓸 곳.
--  · 원정 운임: 외곽 1 · 심부 2 · 핵심 3 노정패(world_expedition_start). 원정 귀환의 노정패 2개 보상은 없앤다.
--  · 노정패 얻는 확률: 탐색·채집 4번에 1번 → 6번에 1번(world_award_mount_tokens).
--  · 탈것 단련: 마구간에서 노정패 20×(단계)로 1~5단계, 단계마다 이동 속도 +4%(world_mount_train, world_travel_route).
--  · 시간당 가치: 원정의 경험치·전·기능 숙련을 탐색과 비슷하게 올리고(회차 보상 ×7·×5·×4), 회차가 드문 긴 원정은 그만큼 더 쳐 준다(분/10 ÷ 회차).
--    Lv10 이하는 원정 경험치 +30%(신입 지원). 첫 수치이며 기록을 보고 고친다.
--  · 원정 전용 물품(회차마다 한 번 굴림, 거래 가능): 길잡이 등불(탐색력 +10) · 비경 지도 · 비약 3종(철벽·맹호·청명) · 봉인된 보따리 ·
--    강화 재료(월철 주괴·정련 숯·강철 주괴·응축 영핵).
--  · 원정 장비(끝까지 다녀온 1시간 이상 원정, 심부 8%·핵심 15%): 행군 노리개·비경 호신부·야행 탈. 원정에 2번 쓰면 닳고(…_2 → _1) 부서진다(_0, 효과 없음, 값 1/10).
--  · 비경: 2시간 이상 원정을 끝까지 다녀오면 외곽 15%·심부 25%·핵심 40%로 그 지역에 3시간 동안 열린다(파티원도 함께). 비경 지도로도 연다.
--    비경에서 탐색·채집: 채집량 +50%, 희귀품 +10%, 단서 +10%(world_trail_effect를 world_status_effect_total에 더함).
--  · 원정지(장소)마다 처음 끝까지 다녀오면 길잡이 등불 1개.
--  · 일찍 불러들여도 지난 시간만큼: 회차를 내림 대신 반올림해 정산.

-- 함수 주인(fn_owner_field 등)으로 만들고 고치려면 그 역할을 잠깐 받는다(끝에서 거둔다)
grant fn_owner_field to postgres with inherit true, set true;
grant fn_owner_19205 to postgres with inherit true, set true;

/* ── 표 ─────────────────────────────────────────────── */
create table if not exists public.world_hidden_trails (
  trail_id bigint generated always as identity primary key,
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  region_id text not null,
  source text not null default 'expedition',
  found_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index if not exists world_hidden_trails_region_idx on public.world_hidden_trails(region_id, expires_at);
alter table public.world_hidden_trails enable row level security;
revoke all on public.world_hidden_trails from public, anon, authenticated;
grant select, insert on public.world_hidden_trails to fn_owner_field;

alter table public.world_owned_mounts add column if not exists training smallint not null default 0;
grant update (training) on public.world_owned_mounts to fn_owner_field;
grant update (item_id) on public.world_character_equipment to fn_owner_field;

/* ── 물품·상태 ─────────────────────────────────────────── */
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, rarity, equipment_traits, tradeable, reference_price, stack_size) values
  ('guide_lantern', '길잡이 등불', 'consumable', 2, '원정길에서만 얻는 작은 등불. 켜 두면 길이 잘 보여 탐색력이 10 오른다.', true, '{}', 1, 'uncommon', '{}', true, 90, 10),
  ('trail_map', '비경 지도', 'consumable', 3, '원정대가 그려 온 숨은 길. 안전지대 밖에서 펼치면 그 지역의 비경이 3시간 동안 열린다(채집량 +50%·희귀품 +10%·단서 +10%).', true, '{}', 1, 'rare', '{}', true, 180, 5),
  ('exp_elixir_iron', '철벽 비약', 'consumable', 2, '원정길에서만 얻는 비약. 30분 동안 받는 피해 -15%.', true, '{}', 1, 'uncommon', '{}', true, 80, 10),
  ('exp_elixir_tiger', '맹호 비약', 'consumable', 2, '원정길에서만 얻는 비약. 30분 동안 주는 피해 +12%.', true, '{}', 1, 'uncommon', '{}', true, 80, 10),
  ('exp_elixir_clear', '청명 비약', 'consumable', 2, '원정길에서만 얻는 비약. 30분 동안 침식 -30%·정신 손실 -15%.', true, '{}', 1, 'uncommon', '{}', true, 80, 10),
  ('sealed_bundle', '봉인된 보따리', 'consumable', 3, '핵심 원정지에서 주운 봉인된 보따리. 열면 레벨에 맞는 장비·회복약·전 가운데 하나가 나온다.', true, '{}', 1, 'rare', '{}', true, 200, 5),
  ('exg_march_2', '행군 노리개', 'norigae', 2, '원정에서만 나오는 노리개. 원정 경험치 +15%·정신 손실 -10%. 원정에 2번 쓰면 부서진다(남은 횟수 2).', false, '{"vitality": 7}', 3, 'rare', '{"trait": "노리개", "expedition_xp_pct": 15, "mental_loss_pct": -10}', true, 360, 1),
  ('exg_march_1', '행군 노리개 (닳음)', 'norigae', 2, '원정에서만 나오는 노리개. 원정 경험치 +15%·정신 손실 -10%. 원정에 한 번 더 쓰면 부서진다(남은 횟수 1).', false, '{"vitality": 7}', 3, 'rare', '{"trait": "노리개", "expedition_xp_pct": 15, "mental_loss_pct": -10}', true, 240, 1),
  ('exg_march_0', '부서진 행군 노리개', 'norigae', 2, '원정에 두 번 써서 부서진 노리개. 효과가 없고 값도 얼마 받지 못한다.', false, '{}', 3, 'common', '{"trait": "노리개"}', true, 36, 1),
  ('exg_trail_2', '비경 호신부', 'amulet', 2, '원정에서만 나오는 호신부. 원정 끝에 비경을 찾을 확률 +50%·침식 -10%. 원정에 2번 쓰면 부서진다(남은 횟수 2).', false, '{"perception": 7}', 3, 'rare', '{"trait": "호신부", "trail_find_pct": 50, "erosion_pct": -10}', true, 360, 1),
  ('exg_trail_1', '비경 호신부 (닳음)', 'amulet', 2, '원정에서만 나오는 호신부. 원정 끝에 비경을 찾을 확률 +50%·침식 -10%. 원정에 한 번 더 쓰면 부서진다(남은 횟수 1).', false, '{"perception": 7}', 3, 'rare', '{"trait": "호신부", "trail_find_pct": 50, "erosion_pct": -10}', true, 240, 1),
  ('exg_trail_0', '부서진 비경 호신부', 'amulet', 2, '원정에 두 번 써서 부서진 호신부. 효과가 없고 값도 얼마 받지 못한다.', false, '{}', 3, 'common', '{"trait": "호신부"}', true, 36, 1),
  ('exg_night_2', '야행 탈', 'mask', 2, '원정에서만 나오는 탈. 원정 보급품을 25% 확률로 아낀다·회피 +4. 원정에 2번 쓰면 부서진다(남은 횟수 2).', false, '{"agility": 7}', 3, 'rare', '{"trait": "탈", "supply_save_pct": 25, "evasion_pct": 4}', true, 360, 1),
  ('exg_night_1', '야행 탈 (닳음)', 'mask', 2, '원정에서만 나오는 탈. 원정 보급품을 25% 확률로 아낀다·회피 +4. 원정에 한 번 더 쓰면 부서진다(남은 횟수 1).', false, '{"agility": 7}', 3, 'rare', '{"trait": "탈", "supply_save_pct": 25, "evasion_pct": 4}', true, 240, 1),
  ('exg_night_0', '부서진 야행 탈', 'mask', 2, '원정에 두 번 써서 부서진 탈. 효과가 없고 값도 얼마 받지 못한다.', false, '{}', 3, 'common', '{"trait": "탈"}', true, 36, 1)
on conflict (item_id) do nothing;

insert into public.world_status_catalog(status_key, status_name, description, icon, polarity, effects, triggers, cure_items, cure, max_stacks, duration_minutes, active) values
  ('st_iron_wall', '철벽', '철벽 비약 기운으로 받는 피해가 줄었습니다.', 'shield', 'positive', '{"incoming_damage_pct": -15}', '{}', '{}', '시간이 지나면 사라집니다.', 1, 30, true),
  ('st_tiger_might', '맹호', '맹호 비약 기운으로 주는 피해가 늘었습니다.', 'spark', 'positive', '{"combat_damage_pct": 12}', '{}', '{}', '시간이 지나면 사라집니다.', 1, 30, true),
  ('st_clear_mind', '청명', '청명 비약 기운으로 요기에 덜 물듭니다.', 'flame', 'positive', '{"erosion_pct": -30, "mental_loss_pct": -15}', '{}', '{}', '시간이 지나면 사라집니다.', 1, 30, true)
on conflict (status_key) do nothing;

/* ── 도우미 함수 ─────────────────────────────────────────── */
-- 원정 회차마다 한 번 굴리는 원정 전용 물품. p_mul = 태세 × 긴 원정 보정
create or replace function public.world_expedition_bonus_item(p_depth int, p_stance text, p_mul float8)
returns text language plpgsql volatile set search_path to 'pg_catalog', 'public' as $$
declare m float8 := coalesce(p_mul, 1) * case p_stance when 'bold' then 1.2 when 'cautious' then 0.85 else 1 end;
  r float8 := random(); acc float8 := 0; t record;
begin
  for t in select * from (values
      ('guide_lantern', 0.05, 1), ('iron_ingot', 0.035, 1), ('charcoal', 0.03, 1),
      ('trail_map', case p_depth when 1 then 0.01 when 2 then 0.025 else 0.04 end, 1),
      ('exp_elixir_iron', 0.01, 2), ('exp_elixir_tiger', 0.01, 2), ('exp_elixir_clear', 0.01, 2),
      ('steel_ingot', case p_depth when 2 then 0.02 else 0.03 end, 2),
      ('sealed_bundle', 0.025, 3), ('spirit_core', 0.02, 3)) v(item, p, min_depth) loop
    continue when coalesce(p_depth, 1) < t.min_depth;
    acc := acc + t.p * m;
    if r < acc then return t.item; end if;
  end loop;
  return null;
end $$;
alter function public.world_expedition_bonus_item(int, text, float8) owner to fn_owner_field;
revoke all on function public.world_expedition_bonus_item(int, text, float8) from public, anon, authenticated;

-- 비경 효과: 지금 있는 지역에 나나 파티원이 연 비경이 있으면 채집량·희귀품·단서 보정
create or replace function public.world_trail_effect(p_effect_key text)
returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid; rid text;
begin
  if p_effect_key not in ('gather_qty_pct', 'rare_loot_pct', 'clue_bonus_pct') then return 0; end if;
  uid := public.fn_owner_auth_uid();
  if uid is null then return 0; end if;
  select (public.world_field_region(c.location)).region_id into rid from public.world_characters c where c.owner_id = uid;
  if rid is null or not exists (select 1 from public.world_hidden_trails t where t.region_id = rid and t.expires_at > now()
      and (t.owner_id = uid or t.owner_id in (select pm.owner_id from public.world_party_members pm
            join public.world_party_members me on me.party_id = pm.party_id where me.owner_id = uid))) then return 0; end if;
  return case p_effect_key when 'gather_qty_pct' then 50 else 10 end;
end $$;
alter function public.world_trail_effect(text) owner to fn_owner_field;
revoke all on function public.world_trail_effect(text) from public;
do $$
declare ro text;
begin
  for ro in select r.rolname from pg_roles r where has_function_privilege(r.oid, 'public.world_title_extra(text)', 'execute') and r.rolname <> 'postgres' loop
    execute format('grant execute on function public.world_trail_effect(text) to %I', ro);
  end loop;
end $$;

-- 탈것 단련(마구간)
create or replace function public.world_mount_train(p_mount_id text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; lv int; cost int; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  r := public.world_field_region(c.location);
  if not coalesce(r.has_stable, false) then raise exception '마구간이 있는 안전지대에서 단련할 수 있습니다.'; end if;
  select o.training into lv from public.world_owned_mounts o where o.owner_id = uid and o.mount_id = p_mount_id for update;
  if not found then raise exception '가진 탈것만 단련할 수 있습니다.'; end if;
  if lv >= 5 then raise exception '이미 끝까지(5단계) 단련한 탈것입니다.'; end if;
  cost := 20 * (lv + 1);
  if c.mount_tokens < cost then raise exception '%', format('노정패 %s개가 필요합니다. (지금 %s개)', cost, c.mount_tokens); end if;
  select mount_name into nm from public.world_mount_catalog where mount_id = p_mount_id;
  update public.world_owned_mounts set training = lv + 1 where owner_id = uid and mount_id = p_mount_id;
  update public.world_characters set mount_tokens = mount_tokens - cost, updated_at = now() where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  values (uid, 'mount_train', -cost, true, jsonb_build_object('mount_id', p_mount_id, 'level', lv + 1));
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'mount', nm || ' 단련 ' || (lv + 1) || '단계', jsonb_build_object('mount_id', p_mount_id, 'training', lv + 1, 'tokens', cost));
  return jsonb_build_object('ok', true, 'training', lv + 1,
    'content', nm || '을(를) ' || (lv + 1) || '단계로 단련했습니다. 이동 속도 +' || (4 * (lv + 1)) || '% · 노정패 ' || cost || '개');
end $$;
alter function public.world_mount_train(text) owner to fn_owner_field;
revoke all on function public.world_mount_train(text) from public, anon;
grant execute on function public.world_mount_train(text) to authenticated;

/* ── 기존 함수 고치기 ──────────────────────────────────── */

-- 상태 효과 합계에 비경 효과를 더한다
do $$
declare d text; a text := '+ public.world_erosion_effect(p_effect_key)';
begin
  d := pg_get_functiondef('public.world_status_effect_total(text)'::regprocedure);
  if position('world_trail_effect' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '상태 효과 합계에서 더할 자리를 찾지 못했습니다'; end if;
  execute replace(d, a, a || ' + public.world_trail_effect(p_effect_key)');
end $$;

-- 노정패: 탐색·채집 6번에 1번, 원정 귀환 보상 없음
do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_award_mount_tokens()'::regprocedure);
  if position('1.0 / 6' in d) > 0 then return; end if;
  if position('random() < 0.25' in d) = 0 or position($q$('commission', 'mission', 'expedition_end')$q$ in d) = 0 then raise exception '노정패 함수에서 고칠 줄을 찾지 못했습니다'; end if;
  d := replace(d, 'random() < 0.25', 'random() < 1.0 / 6');
  d := replace(d, $q$('commission', 'mission', 'expedition_end')$q$, $q$('commission', 'mission')$q$);
  execute d;
end $$;

-- 이동: 단련한 탈것은 단계마다 +4%
do $$
declare d text; a text := 'speed := coalesce(speed, 1);';
begin
  d := pg_get_functiondef('public.world_travel_route(text)'::regprocedure);
  if position('o.training' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '이동 함수에서 속도 줄을 찾지 못했습니다'; end if;
  execute replace(d, a, 'speed := coalesce(speed, 1) * (1 + 0.04 * coalesce((SELECT o.training FROM public.world_owned_mounts o WHERE o.owner_id = uid AND o.mount_id = c.mount_id), 0));');
end $$;

-- 마구간 목록: 단련 단계와 다음 단련 값
do $$
declare d text; a text := $q$'equipped',c.mount_id=m.mount_id)$q$;
begin
  d := pg_get_functiondef('public.world_mount_snapshot()'::regprocedure);
  if position('''training''' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '마구간 목록 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  execute replace(d, a, $q$'equipped',c.mount_id=m.mount_id,'training',coalesce((select o.training from public.world_owned_mounts o where o.owner_id=uid and o.mount_id=m.mount_id),0))$q$);
end $$;

-- 원정 출발: 운임
do $$
declare d text;
  a1 text := $q$inv jsonb; sup jsonb := '{}'::jsonb; k text; q int; ends timestamptz;$q$;
  a2 text := $q$IF c.level < n.min_level THEN RAISE EXCEPTION '%', format('레벨 %s부터 갈 수 있는 곳입니다.', n.min_level); END IF;$q$;
  a3 text := $q$UPDATE public.world_characters SET inventory = inv, current_exploration_node_id = n.node_id, updated_at = now() WHERE owner_id = uid;$q$;
  a4 text := $q$RETURN jsonb_build_object('ok', true, 'ends_at', ends, 'content', n.node_name || '(으)로 원정을 떠났습니다. 보급품을 챙겨 ' || p_minutes || '분 뒤에 돌아옵니다.');$q$;
begin
  d := pg_get_functiondef('public.world_expedition_start(uuid,integer,text)'::regprocedure);
  if position('원정 운임' in d) > 0 then return; end if;
  if position(a1 in d) = 0 or position(a2 in d) = 0 or position(a3 in d) = 0 or position(a4 in d) = 0 then raise exception '원정 출발 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  d := replace(d, a1, a1 || ' fare int;');
  d := replace(d, a2, a2 || $q$
  -- 원정 운임(20261028200000): 외곽 1 · 심부 2 · 핵심 3 노정패
  fare := greatest(1, least(3, n.hierarchy_level - 1));
  IF c.mount_tokens < fare THEN RAISE EXCEPTION '%', format('원정 운임으로 노정패 %s개가 필요합니다. (지금 %s개)', fare, c.mount_tokens); END IF;$q$);
  d := replace(d, a3, $q$UPDATE public.world_characters SET inventory = inv, current_exploration_node_id = n.node_id, mount_tokens = mount_tokens - fare, updated_at = now() WHERE owner_id = uid;
  INSERT INTO public.world_economy_ledger(owner_id, action, currency_delta, sink, details) VALUES (uid, 'expedition_fare', -fare, true, jsonb_build_object('node_id', n.node_id));$q$);
  d := replace(d, a4, $q$RETURN jsonb_build_object('ok', true, 'ends_at', ends, 'fare', fare, 'content', n.node_name || '(으)로 원정을 떠났습니다. 노정패 ' || fare || '개를 운임으로 냈습니다. 보급품을 챙겨 ' || p_minutes || '분 뒤에 돌아옵니다.');$q$);
  execute d;
end $$;

-- 원정 화면: 갈 곳마다 운임, 가진 노정패
do $$
declare d text; a1 text := $q$'locked', c.level < n.min_level)$q$; a2 text := $q$'region_id', r.region_id, 'region_name', r.region_name, 'safe', r.is_safe_zone,$q$;
begin
  d := pg_get_functiondef('public.world_expedition_overview()'::regprocedure);
  if position('''fare''' in d) > 0 then return; end if;
  if position(a1 in d) = 0 or position(a2 in d) = 0 then raise exception '원정 화면 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  d := replace(d, a1, $q$'locked', c.level < n.min_level, 'fare', greatest(1, least(3, n.hierarchy_level - 1)))$q$);
  d := replace(d, a2, a2 || $q$ 'tokens', c.mount_tokens,$q$);
  execute d;
end $$;

-- 원정 회차 정산: 긴 원정 채집 보정, 회차마다 원정 전용 물품
do $$
declare d text;
  a1 text := $q$loot_mul := case e.stance when 'cautious' then 0.8 when 'bold' then 1.3 else 1.0 end * (1 + (depth - 1) * 0.15);$q$;
  a2 text := $q$if er >= 50 and coalesce((sup ->> 'ward_talisman')::int, 0) > 0 then$q$;
begin
  d := pg_get_functiondef('public.world_expedition_settle(uuid,integer)'::regprocedure);
  if position('world_expedition_bonus_item' in d) > 0 then return; end if;
  if position(a1 in d) = 0 or position(a2 in d) = 0 then raise exception '원정 정산 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  d := replace(d, a1, a1 || ' loot_mul := loot_mul * ((e.minutes / 10.0) / total);');
  d := replace(d, a2, $q$-- 원정 전용 물품(20261028200000)
    item := public.world_expedition_bonus_item(depth, e.stance, (e.minutes / 10.0) / total);
    if item is not null then
      loot := public.world_inv_add(loot, item, 1);
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', '원정길에서만 얻는 것을 챙겼습니다. (귀환 후 정리)');
    end if;
    $q$ || a2);
  execute d;
end $$;

-- 원정 귀환: 반올림 정산·시간당 가치·신입 지원·보급 절약·원정 장비·첫 귀환 등불·장비 닳기·비경
do $$
declare d text; n0 int;
  a1 text := $q$xp int; cxp int; gxp int; ixp int; gil_gain int;$q$;
  a2 text := $q$else floor(total_rounds * extract(epoch from now() - e.started_at) / (e.minutes * 60.0))::int end;$q$;
  a3 text := $q$gil_gain := (st ->> 'gil')::int;$q$;
  a4 text := $q$inv := coalesce(c.inventory, '{}'::jsonb);$q$;
  a5 text := $q$for k, q in select key, value::text::int from jsonb_each(sup) where value::text::int > 0 loop inv := public.world_inv_add(inv, k, q); end loop;$q$;
  a6 text := $q$update public.world_expeditions set status = 'done', finished_at = now(), result = jsonb_build_object($q$;
  a7 text := $q$'mount', mount_gift, 'log', lg,$q$;
begin
  d := pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure);
  if position('vmul' in d) > 0 then return; end if;
  if position(a1 in d) = 0 or position(a2 in d) = 0 or position(a3 in d) = 0 or position(a4 in d) = 0 or position(a5 in d) = 0
     or position(a6 in d) = 0 or position(a7 in d) = 0 then raise exception '원정 귀환 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  d := replace(d, a1, a1 || ' vmul float8; ss numeric; n2 int; saved int := 0; gear_drop text; depth_ int; eqr record; nxt text; trail_found boolean := false;');
  d := replace(d, a2, replace(a2, 'else floor(', 'else round('));
  d := replace(d, a3, a3 || $q$
  -- 시간당 가치를 탐색과 맞춘다(20261028200000): 회차 보상 ×7(경험)·×5(전)·×4(숙련), 회차가 드문 긴 원정은 그만큼 더(분/10 ÷ 회차).
  -- Lv10 이하 신입 지원 +30%, 원정 장비의 원정 경험치 보정.
  vmul := (e.minutes / 10.0) / total_rounds;
  xp := round(xp * 7 * vmul * (case when c.level <= 10 then 1.3 else 1 end) * (1 + public.world_gear_total(uid, 'expedition_xp_pct') / 100.0));
  cxp := round(cxp * 4 * vmul); gxp := round(gxp * 4 * vmul); ixp := round(ixp * 4 * vmul); gil_gain := round(gil_gain * 5 * vmul);
  depth_ := greatest(1, least(3, coalesce(n.hierarchy_level, 2) - 1));
  -- 원정 장비: 끝까지 다녀온 1시간 이상 원정, 심부 8% · 핵심 15%
  if e.settled_rounds >= total_rounds and ended = 'complete' and e.minutes >= 60 and depth_ >= 2 and random() < (case depth_ when 2 then 0.08 else 0.15 end) then
    gear_drop := (array['exg_march_2', 'exg_trail_2', 'exg_night_2'])[1 + floor(random() * 3)::int];
    loot := public.world_inv_add(loot, gear_drop, 1);
    lg := lg || jsonb_build_array('원정길에서 ' || (select item_name from public.world_item_catalog where item_id = gear_drop) || '을(를) 얻었습니다.');
  end if;
  -- 이 원정지에 처음 끝까지 다녀오면 길잡이 등불
  if e.settled_rounds >= total_rounds and ended = 'complete' and e.node_id is not null
     and not exists (select 1 from public.world_expeditions x where x.owner_id = uid and x.node_id = e.node_id and x.status = 'done' and x.expedition_id <> e.expedition_id) then
    loot := public.world_inv_add(loot, 'guide_lantern', 1);
    lg := lg || jsonb_build_array('이 원정지에 처음 다녀온 기념으로 길잡이 등불을 받았습니다.');
  end if;$q$);
  d := replace(d, a5, a5 || $q$
  -- 야행 탈: 쓴 보급품을 확률로 아낀다
  ss := public.world_gear_total(uid, 'supply_save_pct');
  if ss > 0 then
    for k, q in select s.key, s.value::text::int - coalesce((sup ->> s.key)::int, 0) from jsonb_each(e.supplies) s loop
      if q > 0 then
        select count(*) into n2 from generate_series(1, q) g where random() < ss / 100.0;
        if n2 > 0 then inv := public.world_inv_add(inv, k, n2); saved := saved + n2; end if;
      end if;
    end loop;
    if saved > 0 then lg := lg || jsonb_build_array('야행 탈 덕에 보급품 ' || saved || '개를 아꼈습니다.'); end if;
  end if;
  -- 원정 장비는 원정 한 번마다 한 단계씩 닳는다(새것 → 닳음 → 부서짐)
  if e.settled_rounds > 0 then
    for eqr in select q2.slot, q2.item_id from public.world_character_equipment q2 where q2.owner_id = uid and q2.item_id ~ '^exg_[a-z]+_[12]$' loop
      nxt := left(eqr.item_id, length(eqr.item_id) - 1) || (right(eqr.item_id, 1)::int - 1)::text;
      inv := public.world_inv_add(public.world_inv_add(inv, eqr.item_id, -1), nxt, 1);
      update public.world_character_equipment set item_id = nxt where owner_id = uid and slot = eqr.slot;
      lg := lg || jsonb_build_array((select item_name from public.world_item_catalog where item_id = eqr.item_id)
        || case when right(nxt, 1) = '0' then '이(가) 부서졌습니다.' else '이(가) 닳았습니다. 원정에 한 번 더 쓸 수 있습니다.' end);
    end loop;
  end if;$q$);
  d := replace(d, a6, $q$-- 비경: 2시간 이상 원정을 끝까지 다녀오면 외곽 15% · 심부 25% · 핵심 40%(비경 호신부 보정)로 3시간 동안 열린다
  if e.minutes >= 120 and ended = 'complete' and e.settled_rounds >= total_rounds
     and random() < (case depth_ when 1 then 0.15 when 2 then 0.25 else 0.40 end) * (1 + public.world_gear_total(uid, 'trail_find_pct') / 100.0) then
    insert into public.world_hidden_trails(owner_id, region_id, expires_at, source) values (uid, r.region_id, now() + interval '3 hours', 'expedition');
    trail_found := true;
    lg := lg || jsonb_build_array(r.region_name || '에서 비경을 찾았습니다. 3시간 동안 이 지역을 탐색하면 채집량이 늘고 귀한 것이 더 잘 나옵니다.');
  end if;
  $q$ || a6);
  d := replace(d, a7, $q$'mount', mount_gift, 'trail', trail_found, 'log', lg,$q$);
  execute d;
end $$;

-- 현장: 이 지역에 열린 비경
do $$
declare d text; a text := $q$'survey', public.world_field_survey(uid, r.region_id),$q$;
begin
  d := pg_get_functiondef('public.world_field_snapshot()'::regprocedure);
  if position('world_hidden_trails' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '현장 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  execute replace(d, a, $q$'trail', (SELECT jsonb_build_object('expires_at', max(t.expires_at)) FROM public.world_hidden_trails t
      WHERE t.region_id = r.region_id AND t.expires_at > now() AND (t.owner_id = uid OR t.owner_id IN (SELECT pm.owner_id FROM public.world_party_members pm
        JOIN public.world_party_members me ON me.party_id = pm.party_id WHERE me.owner_id = uid)) HAVING max(t.expires_at) IS NOT NULL),
    $q$ || a);
end $$;

-- 물품 쓰기: 길잡이 등불·비약·비경 지도·봉인된 보따리
do $$
declare d text;
  a1 text := $q$c public.world_characters%rowtype; inv jsonb; hp int := 0;$q$;
  a2 text := $q$IF p_item_id = 'revival_charm' THEN RAISE EXCEPTION '회생 부적은 쓰러졌을 때 씁니다.'; END IF;$q$;
  a3 text := $q$'wraith_soul_pill', 'fish_oil_lamp')$q$;
  a4 text := $q$WHEN 'fish_oil_lamp' THEN buffs := ARRAY['lamp_glow'];$q$;
begin
  d := pg_get_functiondef('public.world_use_item(text)'::regprocedure);
  if position('guide_lantern' in d) > 0 then return; end if;
  if position(a1 in d) = 0 or position(a2 in d) = 0 or position(a3 in d) = 0 or position(a4 in d) = 0 then raise exception '물품 쓰기 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  d := replace(d, a1, $q$c public.world_characters%rowtype; rr public.world_map_regions%rowtype; got text; qty2 int := 1; gil2 int := 0; roll float8; inv jsonb; hp int := 0;$q$);
  d := replace(d, a2, a2 || $q$
  -- 원정 전용 물품(20261028200000)
  IF p_item_id = 'trail_map' THEN
    rr := public.world_field_region(c.location);
    IF rr.region_id IS NULL OR coalesce(rr.is_safe_zone, false) THEN RAISE EXCEPTION '비경 지도는 안전지대 밖의 지역에서 펼칠 수 있습니다.'; END IF;
    inv := public.world_inv_add(inv, p_item_id, -1);
    UPDATE public.world_characters SET inventory = inv, updated_at = now() WHERE owner_id = uid;
    INSERT INTO public.world_hidden_trails(owner_id, region_id, expires_at, source) VALUES (uid, rr.region_id, now() + interval '3 hours', 'map');
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'use_item', c.character_name || '이(가) ' || rr.region_name || '에서 비경 지도를 펼쳤습니다.', jsonb_build_object('v2', true, 'item_id', p_item_id, 'region_id', rr.region_id));
    RETURN jsonb_build_object('ok', true, 'content', rr.region_name || '의 비경을 찾았습니다. 3시간 동안 이 지역에서 탐색하면 채집량이 늘고 귀한 것이 더 잘 나옵니다.');
  END IF;
  IF p_item_id = 'sealed_bundle' THEN
    roll := random();
    IF roll < 0.4 THEN
      SELECT i.item_id INTO got FROM public.world_item_catalog i
       WHERE i.category IN ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask') AND i.tradeable AND i.item_id !~ '^exg_'
         AND coalesce(i.minimum_level, 1) BETWEEN greatest(1, c.level - 6) AND c.level ORDER BY random() LIMIT 1;
    END IF;
    IF got IS NULL AND roll < 0.75 THEN got := CASE WHEN c.level >= 8 THEN 'spirit_qi_pill' ELSE 'clear_spirit_pill' END; qty2 := 2; END IF;
    inv := public.world_inv_add(inv, p_item_id, -1);
    IF got IS NOT NULL THEN
      IF public.world_bag_room(inv, got, public.world_bag_limit(uid)) < qty2 THEN RAISE EXCEPTION '가방에 자리가 없습니다. 한 칸 비우고 여세요.'; END IF;
      inv := public.world_inv_add(inv, got, qty2);
    ELSE gil2 := 80 + floor(random() * 121)::int; END IF;
    UPDATE public.world_characters SET inventory = inv, gil = gil + gil2, updated_at = now() WHERE owner_id = uid;
    msg := '봉인된 보따리를 열었습니다. ' || CASE WHEN got IS NOT NULL THEN (SELECT item_name FROM public.world_item_catalog WHERE item_id = got) || ' ×' || qty2 ELSE gil2 || '전' END || '이(가) 나왔습니다.';
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'use_item', msg, jsonb_build_object('v2', true, 'item_id', p_item_id, 'got', got, 'qty', qty2, 'gil', gil2));
    RETURN jsonb_build_object('ok', true, 'content', msg);
  END IF;$q$);
  d := replace(d, a3, $q$'wraith_soul_pill', 'fish_oil_lamp', 'guide_lantern', 'exp_elixir_iron', 'exp_elixir_tiger', 'exp_elixir_clear')$q$);
  d := replace(d, a4, a4 || $q$
    WHEN 'guide_lantern' THEN stam := 10;
    WHEN 'exp_elixir_iron' THEN buffs := ARRAY['st_iron_wall'];
    WHEN 'exp_elixir_tiger' THEN buffs := ARRAY['st_tiger_might'];
    WHEN 'exp_elixir_clear' THEN buffs := ARRAY['st_clear_mind'];$q$);
  execute d;
end $$;

grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_19205 to postgres with inherit false, set false;

-- 기록 정리에 끝난 비경(하루 지난 것)을 더한다
create or replace function public.world_housekeeping()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare a int; b int; c int; t int;
begin
  delete from public.world_notifications where read_at is not null and read_at < now() - interval '14 days';
  get diagnostics a = row_count;
  delete from public.world_chat_messages where created_at < now() - interval '30 days';
  get diagnostics b = row_count;
  delete from public.world_economy_ledger where created_at < now() - interval '60 days';
  get diagnostics c = row_count;
  delete from public.world_hidden_trails where expires_at < now() - interval '1 day';
  get diagnostics t = row_count;
  return jsonb_build_object('notifications', a, 'chat', b, 'ledger', c, 'trails', t);
end $$;
revoke all on function public.world_housekeeping() from public, anon, authenticated;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028200000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
