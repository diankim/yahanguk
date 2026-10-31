-- ── 2. 캐릭터와 지난 세계를 비운다(사용자 결정 2026-10-31) ─────────────────────────
-- 남기는 것: 계정(auth.users·profiles)·접속(world_active_sessions)·운영진 명단(world_staff)·초대권(world_invites)
--            ·레거시 명단(world_legacy_marks)·앱 설정(world_app_meta)·패치노트·게임 자료(카탈로그·지도·퀘스트 등)
-- 지우는 것: 캐릭터와 캐릭터에 딸린 모든 것, 친구·차단·모임·서신·채팅·제보·첫 의견 보상, 세력 판도·토벌·비무회 기록
--
-- 운영진 명단은 캐릭터 표를 가리키는 외래 키(지우면 같이 지워짐)라, 계정(auth.users)을 가리키게 바꾼다.
do $s$
declare k text;
begin
  for k in select conname from pg_constraint where conrelid = 'public.world_staff'::regclass and contype = 'f' and confrelid = 'public.world_characters'::regclass loop
    execute format('alter table public.world_staff drop constraint %I', k);
  end loop;
  if not exists (select 1 from pg_constraint where conrelid = 'public.world_staff'::regclass and contype = 'f' and confrelid = 'auth.users'::regclass) then
    alter table public.world_staff add constraint world_staff_owner_user_fkey foreign key (owner_id) references auth.users(id) on delete cascade;
  end if;
end $s$;

do $w$
declare
  wipe text[] := array[
    'world_active_encounters', 'world_blocks', 'world_bond_requests', 'world_bonds', 'world_bug_reports', 'world_case_progress', 'world_case_state',
    'world_character_cosmetics', 'world_character_equipment', 'world_character_statuses', 'world_character_titles', 'world_characters',
    'world_chat_messages', 'world_circle_invites', 'world_circle_members', 'world_circle_messages', 'world_circles', 'world_combat_state',
    'world_commissions', 'world_corpses', 'world_craft_favorites', 'world_direct_trades', 'world_economy_ledger', 'world_events',
    'world_expedition_hits', 'world_expedition_state', 'world_expeditions', 'world_exploration_discoveries', 'world_faction_base_activity_log',
    'world_faction_donations', 'world_faction_log', 'world_faction_mission_progress', 'world_faction_progress', 'world_faction_request_claims',
    'world_faction_supply_claims', 'world_faction_unlocks', 'world_fish_log', 'world_friends', 'world_gathering_discoveries', 'world_gear_enhance',
    'world_gw_fights', 'world_gw_log', 'world_gw_members', 'world_gw_records', 'world_gwiryeong_log', 'world_hidden_trails',
    'world_housing', 'world_housing_guestbook', 'world_housing_merge_asks', 'world_housing_rewards', 'world_housing_shared', 'world_housing_store',
    'world_housing_visits', 'world_idle_activities', 'world_item_acquired', 'world_item_durability', 'world_item_locks', 'world_letter_sends',
    'world_letters', 'world_monster_codex', 'world_notifications', 'world_notify_prefs', 'world_overflow_items', 'world_owned_mounts',
    'world_parties', 'world_party_exp_offers', 'world_party_invites', 'world_party_loot_allocations', 'world_party_loot_pool', 'world_party_members',
    'world_party_messages', 'world_pet_guest', 'world_pets', 'world_pfight_members', 'world_pfights', 'world_quest_abandons', 'world_quest_progress',
    'world_quickslots', 'world_raid_locks', 'world_raid_log', 'world_raid_members', 'world_raid_votes', 'world_raids', 'world_region_event_progress',
    'world_region_influence', 'world_region_intel', 'world_region_progress', 'world_region_site_discoveries', 'world_region_visits',
    'world_regional_case_claims', 'world_report_rewards', 'world_ride_requests', 'world_shop_buy_caps', 'world_skill_picks', 'world_spars',
    'world_storage', 'world_story_progress', 'world_title_presets', 'world_title_seen_migrated', 'world_tourney_entrants', 'world_tourney_entries',
    'world_tourney_matches', 'world_tourneys', 'world_trade_offers', 'world_trade_requests', 'world_travel_history', 'world_travel_party_requests',
    'world_tutorial_state', 'world_wedding_guests', 'world_wedding_lines', 'world_weddings', 'world_whisper_reads', 'world_yohwa_log',
    'world_pet_profile', 'world_pet_gifts'];
  have text;
begin
  -- 있는 표만(운영과 복제 DB의 표 차이), CASCADE 없이 — 남길 표가 지울 표를 가리키고 있으면 여기서 멈춘다
  select string_agg(format('public.%I', t), ', ') into have from unnest(wipe) t where to_regclass('public.' || t) is not null;
  execute 'truncate ' || have || ' restart identity';
  -- 빠뜨린 표 검사: 캐릭터 주인 열(owner_id·user_id·actor_id·sender_id)이 있는데 남긴 표는 이 목록뿐이어야 한다
  if exists (
    select 1 from information_schema.columns k
     where k.table_schema = 'public' and k.column_name in ('owner_id', 'user_id', 'actor_id', 'sender_id', 'character_id', 'member_id', 'seller_id', 'buyer_id')
       and k.table_name not in (select unnest(wipe))
       and k.table_name not in ('world_active_sessions', 'world_staff', 'world_legacy_marks', 'world_invites', 'profiles')
       and exists (select 1 from information_schema.tables t where t.table_schema = 'public' and t.table_name = k.table_name and t.table_type = 'BASE TABLE')) then
    raise exception 'ROLLBACK: 목록에 없는 캐릭터 표가 있다: %', (
      select string_agg(distinct k.table_name, ', ') from information_schema.columns k
       where k.table_schema = 'public' and k.column_name in ('owner_id', 'user_id', 'actor_id', 'sender_id', 'character_id', 'member_id', 'seller_id', 'buyer_id')
         and k.table_name not in (select unnest(wipe))
         and k.table_name not in ('world_active_sessions', 'world_staff', 'world_legacy_marks', 'world_invites', 'profiles')
         and exists (select 1 from information_schema.tables t where t.table_schema = 'public' and t.table_name = k.table_name and t.table_type = 'BASE TABLE'));
  end if;
end $w$;
