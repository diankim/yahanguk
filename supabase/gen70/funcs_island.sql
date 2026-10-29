
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
