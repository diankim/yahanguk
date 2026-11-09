alter table public.world_item_catalog drop constraint if exists world_item_catalog_tier_check;
alter table public.world_item_catalog add constraint world_item_catalog_tier_check check (tier >= 1 and tier <= 7);
select pg_temp.yh_patch('public.world_normalize_item_rarity()', 'new.tier:=least(6,', 'new.tier:=least(7,');
select pg_temp.yh_patch('public.world_normalize_item_rarity()', 'when 5 then 0.08 else 0.05 end', 'when 5 then 0.08 when 6 then 0.05 else 0.03 end');

alter table public.world_fish_species drop constraint if exists world_fish_species_weather_check;
alter table public.world_fish_species add constraint world_fish_species_weather_check check (weather = any (array['clear', 'cloudy', 'rain', 'drizzle', 'fog', 'wind', 'snow', 'bloodmist']));
alter table public.world_fish_species add column if not exists named boolean not null default false;

alter table public.world_fish_grounds drop constraint if exists world_fish_grounds_pkey;
alter table public.world_fish_grounds add constraint world_fish_grounds_pkey primary key (region_id, habitat);

create or replace function public.world_domain_rules() returns jsonb
language sql immutable as $$ select '{"gwiheo": {"name": "귀허도", "open_chapter": "nine_gates", "acclimate": true, "no_shadow": true, "rare": "banyo_scale", "fx": {"effects": {"erosion_pct": 60}}}, "mukjeok": {"name": "묵적록", "open_quest": "gq_5", "no_shadow": true, "rare": "meokgwi_lump", "fx": {"name": "이름 흐림", "effects": {"mental_loss_pct": 15, "incoming_damage_pct": 5, "encounter_pct": 5}, "guard": ["clear_name", "name_ward"]}}}'::jsonb $$;

create or replace function public.world_domain_fx(p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
#variable_conflict use_column
declare t text; d jsonb; g timestamptz;
begin
  select (public.world_region_at(c.location)).territory_id into t from public.world_characters c where c.owner_id = p_uid;
  d := public.world_domain_rules() -> t -> 'fx';
  if d is null then return null; end if;
  select max(s.expires_at) into g from public.world_character_statuses s
   where s.owner_id = p_uid and s.expires_at > now() and s.status_key in (select jsonb_array_elements_text(coalesce(d -> 'guard', '[]'::jsonb)));
  return d || jsonb_build_object('territory', t, 'guard_until', g);
end $$;
revoke all on function public.world_domain_fx(uuid) from public, anon, authenticated;

create or replace function public.world_domain_effect(p_key text) returns numeric
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare fx jsonb := public.world_domain_fx(public.fn_owner_auth_uid());
begin
  if fx is null or fx ->> 'guard_until' is not null then return 0; end if;
  return coalesce((fx -> 'effects' ->> p_key)::numeric, 0);
end $$;
revoke all on function public.world_domain_effect(text) from public, anon, authenticated;

do $d$
declare o text := pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_island_effect(text)'::regprocedure));
begin
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute $f$create or replace function public.world_island_effect(p_key text) returns numeric
  language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $b$
  begin
    return public.world_domain_effect(p_key);
  end $b$$f$;
  if o like 'fn_owner%' then
    execute format('grant execute on function public.world_domain_effect(text) to %I', o);
    execute format('grant execute on function public.world_domain_fx(uuid) to %I', o);
  end if;
end $d$;

select pg_temp.yh_patch('public.world_hud_snapshot()', '''xp_pct'', public.world_xp_damp_pct(uid, c.level),', '''xp_pct'', public.world_xp_damp_pct(uid, c.level), ''domain'', public.world_domain_fx(uid),');
do $d$
declare o text := pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_hud_snapshot()'::regprocedure));
begin
  if o like 'fn_owner%' then execute format('grant execute on function public.world_domain_fx(uuid) to %I', o); end if;
end $d$;

create or replace function public.world_weak_safe_rules() returns jsonb
language sql immutable as $$ select '["banyo_village", "mukchang_ferry"]'::jsonb $$;

create or replace function public.world_weak_shop(p_shop text) returns boolean
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select exists (select 1 from public.world_map_regions r where r.shop_id = p_shop and public.world_weak_safe(r.region_id))
$$;
revoke all on function public.world_weak_shop(text) from public, anon, authenticated;

create or replace function public.world_weak_name(p_uid uuid) returns text
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select (public.world_region_at(c.location)).region_name from public.world_characters c where c.owner_id = p_uid), '이곳')
$$;
revoke all on function public.world_weak_name(uuid) from public, anon, authenticated;

do $d$
declare f text; o text;
begin
  foreach f in array array['public.world_shop_refresh(text)', 'public.world_shop_buy(text,integer)', 'public.world_smithy_snapshot()', 'public.world_storage_check(uuid,boolean)',
    'public.world_letter_place_check(uuid)', 'public.world_housing_edit_block(uuid)', 'public.world_ucomm_place_check(uuid)', 'public.world_guard_action_context()', 'public.world_shop_sell(text,integer,boolean)'] loop
    if to_regprocedure(f) is null then continue; end if;
    o := pg_get_userbyid((select proowner from pg_proc where oid = to_regprocedure(f)));
    if o like 'fn_owner%' then
      execute format('grant execute on function public.world_weak_shop(text) to %I', o);
      execute format('grant execute on function public.world_weak_name(uuid) to %I', o);
    end if;
  end loop;
end $d$;

select pg_temp.yh_patch('public.world_shop_refresh(text)', '(p_shop <> ''banyo_shop'' or sc.item_id like ''ammo%'')', '(not public.world_weak_shop(p_shop) or sc.item_id like ''ammo%'')');
select pg_temp.yh_patch('public.world_shop_refresh(text)', 'case when p_shop = ''banyo_shop'' then 0.3', 'case when public.world_weak_shop(p_shop) then 0.3');
select pg_temp.yh_patch('public.world_shop_refresh(text)', 'case when p_shop = ''banyo_shop'' then 4', 'case when public.world_weak_shop(p_shop) then 4');
select pg_temp.yh_patch('public.world_shop_buy(text,integer)', '(shop = ''banyo_shop'' and s.shop_id = ''smithy''', '(public.world_weak_shop(shop) and s.shop_id = ''smithy''');
select pg_temp.yh_patch('public.world_shop_buy(text,integer)', 'if s.shop_id = ''banyo_shop'' and', 'if s.shop_id <> ''smithy'' and');
select pg_temp.yh_patch('public.world_shop_buy(text,integer)', 'sc.shop_id = ''banyo_shop'' and sc.item_id = p_item_id', 'sc.shop_id = s.shop_id and sc.item_id = p_item_id', 3);
select pg_temp.yh_patch('public.world_shop_buy(text,integer)', '''반요촌에서는 이 물품을 하루에', '''이곳에서는 이 물품을 하루에');
select pg_temp.yh_patch('public.world_smithy_snapshot()', '(sh.shop_id <> ''banyo_shop'' or', '(not public.world_weak_shop(sh.shop_id) or');
select pg_temp.yh_patch('public.world_storage_check(uuid,boolean)', 'raise exception ''반요촌에는 창고가 없습니다. 바깥 안전지대에서 맡기고 꺼내세요.'';', 'raise exception ''%에는 창고가 없습니다. 바깥 안전지대에서 맡기고 꺼내세요.'', public.world_weak_name(p_uid);');
select pg_temp.yh_patch('public.world_letter_place_check(uuid)', 'raise exception ''반요촌에는 역참이 없습니다. 바깥 안전지대에서 부치고 받으세요.'';', 'raise exception ''%에는 역참이 없습니다. 바깥 안전지대에서 부치고 받으세요.'', public.world_weak_name(p_uid);');
select pg_temp.yh_patch('public.world_ucomm_place_check(uuid)', 'raise exception ''반요촌에는 의뢰 게시판이 없습니다. 바깥 안전지대에서 하세요.'';', 'raise exception ''%에는 의뢰 게시판이 없습니다. 바깥 안전지대에서 하세요.'', public.world_weak_name(p_uid);');
select pg_temp.yh_patch('public.world_housing_edit_block(uuid)', 'return ''반요촌에서는 별채를 고칠 수 없습니다.'';', 'return public.world_weak_name(p_uid) || ''에서는 별채를 고칠 수 없습니다.'';');
select pg_temp.yh_patch('public.world_guard_action_context()', 'RAISE EXCEPTION ''반요촌에는 거래소가 없습니다.'';', 'RAISE EXCEPTION ''%에는 거래소가 없습니다.'', r.region_name;');

create or replace function public.world_fish_rules() returns jsonb
language sql immutable as $$ select '{"weight": {"common": 60, "uncommon": 25, "rare": 9, "epic": 3, "legendary": 0.6}, "boosted": ["rare", "epic", "legendary"], "match": 3, "miss": 0.3, "miss_skill": 0.6, "named": {"weight": 0.3, "boost": 0.5, "bait": 1}}'::jsonb $$;

select pg_temp.yh_patch('public.world_fish()', 'cost int := 1; caught boolean;',
  'cost int := 1; bait text := nullif(current_setting(''yh.fish_bait'', true), ''''); hab text := nullif(current_setting(''yh.fish_habitat'', true), ''''); bsp public.world_fish_species%rowtype; nwt numeric := 0; caught boolean;');
select pg_temp.yh_patch('public.world_fish()', 'select * into g from public.world_fish_grounds where region_id = r.region_id;',
  'select * into g from public.world_fish_grounds fg where fg.region_id = r.region_id order by (fg.habitat is not distinct from hab) desc, fg.habitat limit 1;');
select pg_temp.yh_patch('public.world_fish()', '  sk := public.world_skill_procs(uid);',
  '  sk := public.world_skill_procs(uid);
  nwt := coalesce((select (i.equipment_traits ->> ''named_wt'')::numeric * rod_m from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0);
  if bait is not null then
    select * into bsp from public.world_fish_species s where s.fish_id = bait;
    if bsp.fish_id is null or not exists (select 1 from public.world_fish_species n where n.named and n.active and n.fish_id = any (bsp.bait_for) and n.habitat = g.habitat
        and (n.grounds is null or r.region_id = any (n.grounds))) then raise exception ''이 낚시터에서는 그 물고기를 미끼로 쓸 수 없습니다.''; end if;
    if coalesce((c.inventory ->> bait)::int, 0) < (public.world_fish_rules() -> ''named'' ->> ''bait'')::int then raise exception ''미끼로 쓸 %이(가) 가방에 없습니다.'', bsp.fish_name; end if;
    notes := notes || (''미끼 '' || bsp.fish_name || '' 하나를 썼습니다'')::text;
  end if;');
select pg_temp.yh_patch('public.world_fish()', 'update public.world_characters set stamina = left_st, stamina_at = base_at, skill_progress = prog, updated_at = now() where owner_id = uid;',
  'update public.world_characters set stamina = left_st, stamina_at = base_at, skill_progress = prog, updated_at = now(),
      inventory = case when bait is not null then public.world_inv_apply(inventory, jsonb_build_object(bait, (public.world_fish_rules() -> ''named'' ->> ''bait'')::int), -1) else inventory end where owner_id = uid;');
select pg_temp.yh_patch('public.world_fish()', 'and s.min_level <= c.level + 2 and (s.grounds is null or r.region_id = any(s.grounds))',
  'and s.min_level <= c.level + 2 and (s.grounds is null or r.region_id = any(s.grounds))
     and (not s.named or (bait is not null and s.fish_id = any (bsp.bait_for) and s.phase = ph and s.weather = wk))');
select pg_temp.yh_patch('public.world_fish()', '(coalesce((public.world_fish_rules() -> ''weight'' ->> s.rarity)::numeric, (public.world_fish_rules() -> ''weight'' ->> ''legendary'')::numeric) * case when (public.world_fish_rules() -> ''boosted'') ? s.rarity then 1 + boost / 100.0 else 1 end)',
  '(case when s.named then ((public.world_fish_rules() -> ''named'' ->> ''weight'')::numeric + nwt) * (1 + boost * (public.world_fish_rules() -> ''named'' ->> ''boost'')::numeric / 100.0)
        else coalesce((public.world_fish_rules() -> ''weight'' ->> s.rarity)::numeric, (public.world_fish_rules() -> ''weight'' ->> ''legendary'')::numeric) * case when (public.world_fish_rules() -> ''boosted'') ? s.rarity then 1 + boost / 100.0 else 1 end end)');
select pg_temp.yh_patch('public.world_fish()', '(case when s.phase is null then 1', '(case when s.phase is null or s.named then 1');
select pg_temp.yh_patch('public.world_fish()', '(case when s.weather is null then 1', '(case when s.weather is null or s.named then 1');
select pg_temp.yh_patch('public.world_fish()', 'inv := public.world_inv_add(c.inventory, sp.fish_id, 1 + more);',
  'inv := public.world_inv_add(case when bait is not null then public.world_inv_apply(c.inventory, jsonb_build_object(bait, (public.world_fish_rules() -> ''named'' ->> ''bait'')::int), -1) else c.inventory end, sp.fish_id, 1 + more);');
select pg_temp.yh_patch('public.world_fish()', 'jsonb_build_object(''caught'', true, ''fish'', sp.fish_id, ''rarity'', sp.rarity,',
  'jsonb_build_object(''caught'', true, ''fish'', sp.fish_id, ''rarity'', sp.rarity, ''named'', sp.named, ''bait'', bait,');

select pg_temp.yh_patch('public.world_fish_spot()', 'select * into g from public.world_fish_grounds where region_id = r.region_id;',
  'select * into g from public.world_fish_grounds fg where fg.region_id = r.region_id order by fg.habitat limit 1;');
select pg_temp.yh_patch('public.world_fish_spot()', 'return jsonb_build_object(''region_id'', r.region_id,',
  'return jsonb_build_object(''grounds'', public.world_fish_ground_list(uid, r.region_id), ''region_id'', r.region_id,');

create or replace function public.world_fish_ground_list(p_uid uuid, p_region text) returns jsonb
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce(jsonb_agg(jsonb_build_object('habitat', g.habitat, 'ground_name', g.ground_name, 'description', g.description,
      'species_total', (select count(*) from public.world_fish_species s where s.habitat = g.habitat and s.active and (s.grounds is null or p_region = any (s.grounds))),
      'species_caught', (select count(*) from public.world_fish_log l join public.world_fish_species s using (fish_id) where l.owner_id = p_uid and s.habitat = g.habitat and (s.grounds is null or p_region = any (s.grounds))),
      'named', (select coalesce(jsonb_agg(jsonb_build_object('fish_id', n.fish_id, 'caught', exists (select 1 from public.world_fish_log l where l.owner_id = p_uid and l.fish_id = n.fish_id),
          'name', case when exists (select 1 from public.world_fish_log l where l.owner_id = p_uid and l.fish_id = n.fish_id) then n.fish_name end,
          'hint', n.description) order by n.sort), '[]'::jsonb)
        from public.world_fish_species n where n.named and n.active and n.habitat = g.habitat and (n.grounds is null or p_region = any (n.grounds))),
      'baits', (select coalesce(jsonb_agg(jsonb_build_object('fish_id', b.fish_id, 'name', b.fish_name, 'n', (c.inventory ->> b.fish_id)::int) order by b.sort), '[]'::jsonb)
        from public.world_fish_species b, public.world_characters c
       where c.owner_id = p_uid and coalesce((c.inventory ->> b.fish_id)::int, 0) > 0
         and exists (select 1 from public.world_fish_species n where n.named and n.active and n.fish_id = any (b.bait_for) and n.habitat = g.habitat
                       and (n.grounds is null or p_region = any (n.grounds)))))
    order by g.habitat), '[]'::jsonb)
  from public.world_fish_grounds g where g.region_id = p_region
$$;
revoke all on function public.world_fish_ground_list(uuid, text) from public, anon, authenticated;
do $d$
declare o text := pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_fish_spot()'::regprocedure));
begin
  if o like 'fn_owner%' then execute format('grant execute on function public.world_fish_ground_list(uuid, text) to %I', o); end if;
end $d$;

create or replace function public.world_fish_at(p_habitat text default null, p_bait text default null) returns jsonb
language plpgsql security invoker set search_path to 'pg_catalog', 'public' as $$
begin
  perform set_config('yh.fish_habitat', coalesce(p_habitat, ''), true);
  perform set_config('yh.fish_bait', coalesce(p_bait, ''), true);
  return public.world_fish();
end $$;
revoke all on function public.world_fish_at(text, text) from public, anon;
grant execute on function public.world_fish_at(text, text) to authenticated;
