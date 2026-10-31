-- 서버 롤백 · 1.0.0 「두 번째 밤」 (build.py가 만든 파일, 고치려면 조각을 고치고 다시 만든다)
-- 미리 돌려 보기: do $$ begin execute (…이 파일…); raise exception 'ROLLBACK_TEST ok'; end $$; 또는 begin; + 파일 + rollback;
set local check_function_bodies = off;
lock table public.world_characters in access exclusive mode;


-- ════════ p1_legacy_mark.src.sql ════════
-- 대기 파일: 「야행(夜行)의 흔적」 레거시 세트 — 11월 초 서버 전체 롤백 때 돌린다(지금은 돌리지 않는다).
-- migrations 폴더 밖에 두어 실수로 돌지 않게 했다. 화면 그림(cosmetics.js fr_yahaeng·pt_yahaeng·sl_heun, chat.js 이름 색 1016, app.css t-legacy)은 미리 배포돼 있어도 아무도 갖지 않아 보이지 않는다.
--
-- 순서
--   ① 롤백 「직전」: 이 파일의 1단계만 돌려 지금 캐릭터가 있는 계정을 명단(world_legacy_marks)에 남긴다. 계정(owner_id)은 롤백해도 그대로다.
--   ② 롤백을 한다(캐릭터 정리 방식은 그때 정한다).
--   ③ 롤백 「직후」: 2단계를 돌린다. 세트(칭호 3·테두리·바탕 무늬·낙관·이름 색)를 만들고, 명단에 있는 계정이 새 캐릭터를 만들면 저절로 주며(트리거),
--      이미 캐릭터가 있는 명단 계정에는 바로 준다. 얻는 다른 길은 없다(칭호 rule null — 판정이 절대 주지 않음, 꾸미기 rule은 레거시 칭호를 가졌을 때).
--   SQL 편집기에 붙일 때는 다른 패치처럼 줄바꿈(CR) 정리 감싸기로 돌린다.
--
-- 세트(별도 능력치 효과 없음)
--   칭호(신품·분류 「레거시」, 가진 사람 말고는 칭호 목록에 안 보임 — 운영진 칭호와 같은 처리)
--     · 제일야(第一夜)의 증인 · 미완(未完)의 길을 연 자 · 꺼지지 않은 불씨
--   꾸미기(등급 「흔적」): 테두리 「야행(夜行)의 테」(그믐달에 든 등롱·별, 핏빛 겹테·금빛 문양) · 바탕 무늬 「흑야 운문(黑夜雲紋)」 · 낙관 「痕」
--   이름 색 「야행묵금」(1016, 금빛 이름 + 핏빛 마름모): 레거시 칭호가 하나라도 있으면

-- ── 1단계(롤백 직전) ─────────────────────────────
create table if not exists public.world_legacy_marks (
  owner_id uuid primary key,
  character_name text,
  level int,
  marked_at timestamptz not null default now()
);
alter table public.world_legacy_marks enable row level security;
revoke all on public.world_legacy_marks from anon, authenticated;
insert into public.world_legacy_marks(owner_id, character_name, level)
select c.owner_id, c.character_name, c.level from public.world_characters c
on conflict (owner_id) do nothing;

-- ════════ p2_wipe.sql ════════
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

-- ════════ p3_world.sql ════════
-- ── 3. 세계를 처음 상태로: 세력 판도·장야·예약 작업 ────────────────────────────────
-- 지역 지배는 본래 주인에게, 분쟁 없음
update public.world_map_regions r
   set control_faction_id = r.home_faction_id,
       faction_control = coalesce((select f.faction_name from public.world_major_factions f where f.faction_id = r.home_faction_id), r.faction_control),
       contested = false, control_changed_at = null
 where r.control_faction_id is distinct from r.home_faction_id or r.contested;
-- 세력 관계는 처음 값으로
update public.world_faction_relations set score = base, updated_at = now() where score is distinct from base;

-- 장야 끝: 11/2 0시부터는 늘 평상(0). 전에는 그 뒤로 영원히 4(끝나지 않는 밤)였다(효과 점검 2026-10-31)
create or replace function public.world_long_night_stage(p_ts timestamp with time zone default now())
 returns integer language sql immutable set search_path to 'pg_catalog'
as $function$
  select case when p_ts >= timestamptz '2026-11-02 00:00+09' then 0
              when p_ts >= timestamptz '2026-11-01 00:00+09' then 3
              when p_ts >= timestamptz '2026-10-31 00:00+09' then 2
              when p_ts >= timestamptz '2026-10-30 00:00+09' then 1 else 0 end
$function$;
delete from public.world_app_meta where key in ('long_night_announced', 'influence_at');

-- 예약 작업: 장야 알림은 끝, 롤백용 일회성 둘은 이미 스스로 지웠어야 한다(남아 있으면 지움)
do $c$
declare j text;
begin
  foreach j in array array['yh-long-night', 'yh-last-night-wipe', 'yh-rollback-close', 'yh-invite-day'] loop
    begin perform cron.unschedule(j); exception when others then null; end;
  end loop;
end $c$;

-- 봉연의 그림자 다음 회차를 새로 잡는다(지난 회차는 2에서 비웠다)
select public.world_raid_schedule_next();

-- ════════ p4_legacy_grant.src.sql ════════
-- ── 2단계(롤백 직후) ─────────────────────────────

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('legacy_first_night', '제일야(第一夜)의 증인', 'moon',
   '아직 지도가 다 그려지지 않았던 밤, 야행국의 첫 번째 시대를 끝까지 지켜본 자. 그 밤은 지워졌으나 증인은 지워지지 않는다.',
   '야행국의 첫 번째 시대를 함께한 이에게만 주어졌다', '{}'::jsonb, true, false, null, 901, '레거시', 5),
  ('legacy_unfinished_road', '미완(未完)의 길을 연 자', 'map',
   '길이 이름을 얻기도 전에 먼저 걸었다. 지금 이 세계의 모든 길은 그 발자국 위에 다시 놓였다.',
   '야행국의 첫 번째 시대를 함께한 이에게만 주어졌다', '{}'::jsonb, true, false, null, 902, '레거시', 5),
  ('legacy_ember', '꺼지지 않은 불씨', 'spark',
   '세계가 한 번 꺼졌다 다시 켜지던 밤에도 홀로 꺼지지 않고 남은 불씨. 다음 밤을 여는 것은 언제나 이런 불씨다.',
   '야행국의 첫 번째 시대를 함께한 이에게만 주어졌다', '{}'::jsonb, true, false, null, 903, '레거시', 5)
on conflict (title_key) do nothing;

-- 꾸미기 등급에 「흔적(legacy)」을 더한다(화면 이름: 설정 TIER legacy '흔적', 그림 cosmetics.js t-legacy)
alter table public.world_cosmetic_catalog drop constraint if exists world_cosmetic_catalog_tier_check;
alter table public.world_cosmetic_catalog add constraint world_cosmetic_catalog_tier_check check (tier = any (array['common', 'rare', 'legend', 'legacy']));

insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
  ('fr_yahaeng', 'frame', 'legacy', '야행(夜行)의 테', '롤백 전, 야행국의 첫 번째 시대를 함께한 이의 증표 · 이제 얻을 수 없다', '레거시', '{"title": "legacy_first_night"}'::jsonb, false, true, 901),
  ('pt_yahaeng', 'pattern', 'legacy', '흑야 운문(黑夜雲紋)', '롤백 전, 야행국의 첫 번째 시대를 함께한 이의 증표 · 이제 얻을 수 없다', '레거시', '{"title": "legacy_first_night"}'::jsonb, false, true, 902),
  ('sl_heun', 'seal', 'legacy', '낙관 「痕」', '롤백 전, 야행국의 첫 번째 시대를 함께한 이의 증표 · 이제 얻을 수 없다', '레거시', '{"title": "legacy_first_night"}'::jsonb, false, true, 903)
on conflict (cosmetic_key) do nothing;

-- 레거시 칭호는 운영진 칭호처럼 가진 사람만 칭호 목록에서 본다(얻을 길이 없는 칸이 다른 이의 목록·진행률을 막지 않게)
do $$ declare d text := pg_get_functiondef('public.world_title_snapshot()'::regprocedure);
  a text := $a$(tc.category is distinct from '운영' or ct.owner_id is not null)$a$;
  b text := $a$(coalesce(tc.category, '') not in ('운영', '레거시') or ct.owner_id is not null)$a$;
begin
  if position($a$'레거시'$a$ in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '칭호 목록 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- 이름 색 1016 「야행묵금」: 레거시 칭호가 하나라도 있으면
do $$ declare d text := pg_get_functiondef('public.world_name_styles()'::regprocedure);
  a text := $a$(1013, 'cat', '교류', 2), (1014, 'cat', '이동', 4), (1015, 'cat', '성장', 4))$a$;
  b text := $a$(1013, 'cat', '교류', 2), (1014, 'cat', '이동', 4), (1015, 'cat', '성장', 4), (1016, 'cat', '레거시', 1))$a$;
begin
  if position('1016' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '이름 색 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- 세트 주기: 명단에 있는 계정에만, 한 번만(이미 가졌으면 건너뜀)
create or replace function public.world_legacy_grant(p_owner uuid)
returns boolean language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if not exists (select 1 from public.world_legacy_marks where owner_id = p_owner) then return false; end if;
  if not exists (select 1 from public.world_characters where owner_id = p_owner) then return false; end if;
  if exists (select 1 from public.world_character_titles where owner_id = p_owner and title_key = 'legacy_first_night') then return false; end if;
  insert into public.world_character_titles(owner_id, title_key, earned_at)
  select p_owner, k, now() from unnest(array['legacy_first_night', 'legacy_unfinished_road', 'legacy_ember']) k
  on conflict do nothing;
  insert into public.world_character_cosmetics(owner_id, cosmetic_key, unlocked_at)
  select p_owner, k, now() from unnest(array['fr_yahaeng', 'pt_yahaeng', 'sl_heun']) k
  on conflict do nothing;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_owner, 'reward', '야행(夜行)의 흔적',
    '혼돈의 시절, 야행국이 미완이던 그때 이 세계를 함께 걸어 주셔서 고맙습니다. 첫 번째 시대를 함께한 이에게만 주어지는 「야행(夜行)의 흔적」 세트를 드립니다. '
    || '칭호 「제일야(第一夜)의 증인」·「미완(未完)의 길을 연 자」·「꺼지지 않은 불씨」, 테두리 「야행(夜行)의 테」, 바탕 무늬 「흑야 운문」, 낙관 「痕」, 이름 색 「야행묵금」. '
    || '칭호 화면과 게임 설정 › 꾸미기에서 쓸 수 있습니다(능력치 효과는 없습니다).',
    jsonb_build_object('legacy', true));
  return true;
end $$;
revoke all on function public.world_legacy_grant(uuid) from public, anon, authenticated;

-- 명단 계정이 롤백 뒤 새 캐릭터를 만들면 저절로
create or replace function public.trg_world_legacy_on_create()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  perform public.world_legacy_grant(new.owner_id);
  return new;
end $$;
revoke all on function public.trg_world_legacy_on_create() from public, anon, authenticated;
drop trigger if exists trg_world_legacy_on_create on public.world_characters;
create trigger trg_world_legacy_on_create after insert on public.world_characters
  for each row execute function public.trg_world_legacy_on_create();

-- 이미 캐릭터가 있는 명단 계정에는 바로
select count(*) filter (where public.world_legacy_grant(m.owner_id)) as granted_now from public.world_legacy_marks m;

-- ════════ p5_intro.src.sql ════════
-- 롤백 뒤 주 이야기 1장 첫 장면(mq_red_seal 1 「빈 칸 난 장부」)에 장야를 가볍게 짚는 대사를 넣는다.
-- 조사원이 해가 뜨지 않던 밤을 꿈처럼 떠올리고, 연서희는 모른다는 듯 넘긴다(손끝의 붉은 인주만 남김).
-- 롤백 SQL과 함께 점검 중에 돌린다. 이미 들어 있으면 다시 넣지 않는다.
update public.world_quest_steps s
   set lines = (
     select jsonb_agg(x order by ord) from (
       select e as x, (i * 10)::numeric as ord from jsonb_array_elements(s.lines) with ordinality t(e, i)
       union all
       select v, (pos * 10 - 5 + k * 0.1)::numeric
         from (select min(i) pos from jsonb_array_elements(s.lines) with ordinality t(e, i) where e ->> 't' like '인사는 짧게 할게요.%') p,
              jsonb_array_elements($j$[
                {"s": null, "t": "나는 오는 길에 이상한 꿈을 꿨다고 말했다. 해가 뜨지 않는 밤이었고, 등불이 하나씩 꺼지다가 마지막엔 정청 등불 하나만 남았다고."},
                {"s": null, "t": "연서희가 붓을 멈춘다. 잠깐, 아주 잠깐 당신을 바라본다."},
                {"s": "q:m_yeon", "t": "해가 뜨지 않는 밤이요? …글쎄요. 어젯밤은 별일 없이 조용했어요. 정청에 처음 오는 사람들은 다들 그런 꿈을 꾼다더라고요."},
                {"s": null, "t": "서가 뒤에서 누군가 중얼거린다. 「간밤에 정청 등불 하나가 새벽까지 꺼지지 않았다더군. 누가 밤새 장부를 붙들고 있었는지.」"},
                {"s": null, "t": "연서희의 손끝에 붉은 인주가 희미하게 묻어 있다. 그녀는 아무렇지 않게 소매로 그것을 덮는다."},
                {"s": "q:m_yeon", "t": "꿈 얘기는 나중에 해요. 이름이 장부에 남아 있으면, 아침은 다시 와요."}
              ]$j$::jsonb) with ordinality n(v, k)
     ) z)
 where s.quest_id = 'mq_red_seal' and s.step = 1
   and not exists (select 1 from jsonb_array_elements(s.lines) e where e ->> 't' like '해가 뜨지 않는 밤이요?%');

-- ════════ p6_pets.src.sql ════════
-- 대기 파일: 꼬마 동무 1.0.0(롤백 패치) — 새 동무 8종(조사원 제보) · 동무 두 자리(프로필 동무 / 별채 동무)
-- 1.0.0 묶음에 합칠 것(db_version 줄은 넣지 않았다 — 묶음 마지막에 한 번). migrations 폴더 밖에 두어 실수로 돌지 않게 했다.
-- 화면: assets/js/housing/pets.js(38종, tools/pet_art/art4.py → gen.py) · views/housing.js(동무 창·별채 없을 때 동무 칸) · views/guide.js.
-- 그림(pets.js)이 먼저 배포돼 있어도 world_pet_species에 없으면 도감에 나오지 않는다.
--
-- ① 새 동무 8종(제보한 조사원 → 동무)
--   네눈박이 강아지(박시현) 범품 · 바구니 / 흰둥이 강아지(조의신) 범품 · 바구니
--   잿빛 장모 고양이(여보) · 점박이 하늘다람쥐(윤아람) · 꼬마 족제비(강산하) 양품 · 얼룩무늬 알
--   금빛 날개늑대(나락) 진품 · 퀘스트 「벼락을 부르는 문」 + 빛나는 알
--   외뿔 팔족염소(아도니스) 명품 · 외전 「거꾸로 선 기도」(gq_3) / 꼬마 홍룡(조의신) 명품 · 8장 「재의 바다」(mq_ash_sea)
-- ② 제보한 조사원에게 주기(결정 필요): world_pet_gifts(계정 id = world_characters.owner_id, 롤백해도 그대로) + 스위치 world_app_meta 'pet_gift'
--   'on'이면 그 계정이 새 캐릭터를 만들 때 저절로 도감에 넣고, 켤 때 이미 캐릭터가 있으면 world_pet_gift_apply_all()로 한 번에 준다.
--   이 파일은 'off'로 넣는다. 켜기: update public.world_app_meta set value = 'on' where key = 'pet_gift'; select public.world_pet_gift_apply_all();
--   아예 주지 않기: 'off' 그대로 두거나 delete from public.world_pet_gifts;
-- ③ 동무 두 자리: 프로필 동무(world_pet_profile, 조사원 카드에 보이고 데리고 다님, 별채 없어도 됨) · 별채 동무(world_housing.pet_id, 지금처럼).
--   같은 동무는 한 자리에만(다른 자리로 고르면 앞 자리에서 빠짐). world_housing.pet_out은 더 쓰지 않는다(열은 남기고 늘 false).
--   한 지붕에 들어온 정인도 프로필 동무는 따로 정한다(별채 동무는 지금처럼 집주인 것).
--
-- 미리 돌려 보기: begin; + 이 파일 + rollback;
-- ─────────────────────────────────────────────────────────────

-- 함수 본문 고치기 도우미(gen71/_patch_fn.sql과 같다)
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


-- ── ① 새 동무 8종 ─────────────────────────────
insert into public.world_pet_species(pet_id, pet_name, grade, kind, likes, how, sort, egg)
select x.pet_id, x.pet_name, x.grade, x.kind, x.likes, x.how, x.sort, x.egg
  from (values
    ('neun_puppy',       '네눈박이 강아지',   1, 'ward',    'treat_meat',  '안전지대 상점의 바구니', 30, false),
    ('white_puppy',      '흰둥이 강아지',     1, 'ward',    'treat_rice',  '안전지대 상점의 바구니', 31, false),
    ('ash_longhair',     '잿빛 장모 고양이',  2, 'shadow',  'treat_fish',  '탐색 중 「얼룩무늬 알」', 32, true),
    ('spotted_glider',   '점박이 하늘다람쥐', 2, 'sky',     'treat_rice',  '탐색 중 「얼룩무늬 알」', 33, true),
    ('golden_wingwolf',  '금빛 날개늑대',     3, 'sky',     'treat_meat',  '퀘스트 「벼락을 부르는 문」을(를) 마친다 · 빛나는 알', 34, true),
    ('little_ferret',    '꼬마 족제비',       2, 'shadow',  'treat_meat',  '탐색 중 「얼룩무늬 알」', 35, true),
    ('onehorn_goat',     '외뿔 팔족염소',     4, 'giant',   'treat_herb',  '외전 「거꾸로 선 기도」를 마친다', 36, false),
    ('little_hongryong', '꼬마 홍룡',         4, 'breaker', 'treat_meat',  '이야기 8장 「재의 바다」를 마친다', 37, false)
  ) as x(pet_id, pet_name, grade, kind, likes, how, sort, egg)
on conflict (pet_id) do update set pet_name = excluded.pet_name, grade = excluded.grade, kind = excluded.kind, likes = excluded.likes, how = excluded.how, sort = excluded.sort, egg = excluded.egg;

insert into public.world_pet_sources(source, pet_id) values
  ('quest:sq_thunder_peak_2', 'golden_wingwolf'),
  ('quest:gq_3', 'onehorn_goat'),
  ('quest:mq_ash_sea', 'little_hongryong')
on conflict do nothing;

-- 범품 바구니 둘(기존 바구니와 같은 값·같은 꼴). 상점 목록에는 모든 안전지대 상점(대장간·반요촌 제외)에 넣고, 회차마다 절반쯤 나온다(world_shop_refresh).
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
values
  ('pt_neun_puppy', '네눈박이 강아지 바구니', 'pet', 1, '눈 위의 갈색 점이 눈이 넷인 것처럼 보이는 검둥이 강아지입니다. 공을 던져 주면 지칠 때까지 물어 옵니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).',
   false, '{}'::jsonb, 1, '{"pet": "neun_puppy"}'::jsonb, true, 300, 1),
  ('pt_white_puppy', '흰둥이 강아지 바구니', 'pet', 1, '눈처럼 하얀 털이 보송보송한 강아지입니다. 반가우면 말린 꼬리를 쉬지 않고 흔듭니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).',
   false, '{}'::jsonb, 1, '{"pet": "white_puppy"}'::jsonb, true, 300, 1)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, x.item_id, 300, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join (values ('pt_neun_puppy'), ('pt_white_puppy')) as x(item_id)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;

-- 「모든 동무의 벗」 칭호 글: 서른 → 지금 종 수(판정 n은 30 그대로 — 이미 받은 사람을 지키고, 새 종은 덤)
update public.world_title_catalog set description = '야행국의 꼬마 동무 서른을 만났다.', condition_text = '꼬마 동무 30마리를 모은다'
 where title_key = 'pet_30';

-- ── ② 제보한 조사원에게 주기(스위치 'pet_gift', 처음은 off) ─────────────
create table if not exists public.world_pet_gifts (
  owner_id uuid not null,          -- 계정(auth) id = world_characters.owner_id. 롤백 뒤에도 같다.
  pet_id text not null,
  reporter text,                   -- 제보할 때의 캐릭터 이름(기록용)
  granted_at timestamptz,
  primary key (owner_id, pet_id)
);
alter table public.world_pet_gifts enable row level security;
revoke all on public.world_pet_gifts from anon, authenticated;
grant select, update on public.world_pet_gifts to fn_owner_field;
insert into public.world_pet_gifts(owner_id, pet_id, reporter) values
  ('a6608aa3-c889-4abb-9dab-2be00a9e85b3', 'onehorn_goat', '아도니스'),
  ('fdde20a1-0b69-465b-8113-c5c3e29fba74', 'ash_longhair', '여보'),
  ('f8edc79d-423e-499f-9232-2e67f7e0b6a6', 'spotted_glider', '윤아람'),
  ('71f09a4e-be3f-402b-a241-f3e678f9fc22', 'neun_puppy', '박시현'),
  ('01375cc5-0c6d-493e-b59b-43d0740eb08a', 'golden_wingwolf', '나락'),
  ('eb400e69-ecd9-463e-8c3a-9c072968d778', 'little_ferret', '강산하'),
  ('ea4e4e6b-3a21-4709-95d5-ac33afde971d', 'white_puppy', '조의신'),
  ('ea4e4e6b-3a21-4709-95d5-ac33afde971d', 'little_hongryong', '조의신')
on conflict do nothing;
insert into public.world_app_meta(key, value) values ('pet_gift', 'off') on conflict (key) do nothing;

-- 한 계정에 제보 동무를 준다(스위치가 켜져 있고 캐릭터가 있을 때만, 이미 있으면 world_pet_grant가 건너뜀 — 주먹밥도 주지 않음)
create or replace function public.world_pet_gift_give(p_owner uuid) returns int
language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  if coalesce((select value from public.world_app_meta where key = 'pet_gift'), 'off') <> 'on' then return 0; end if;
  if not exists (select 1 from public.world_characters where owner_id = p_owner) then return 0; end if;
  for r in select g.pet_id, s.pet_name from public.world_pet_gifts g join public.world_pet_species s using (pet_id) where g.owner_id = p_owner loop
    if public.world_pet_grant(p_owner, r.pet_id, 'gift', false) then
      n := n + 1;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (p_owner, 'pet_new', '꼬마 동무 · ' || r.pet_name,
        '제보해 주신 동무 ' || public.world_josa(r.pet_name, '이', '가') || ' 야행국에 왔습니다. 고맙습니다. 별채 화면의 「동무」에서 데리고 다니거나 별채에 둘 수 있습니다.',
        jsonb_build_object('pet_id', r.pet_id, 'gift', true));
    end if;
    update public.world_pet_gifts set granted_at = coalesce(granted_at, now()) where owner_id = p_owner and pet_id = r.pet_id;
  end loop;
  return n;
end $$;
revoke all on function public.world_pet_gift_give(uuid) from public, anon, authenticated;
alter function public.world_pet_gift_give(uuid) owner to fn_owner_field;

-- 켤 때 이미 캐릭터가 있는 계정에 한 번에(운영진이 SQL 편집기에서만 부름)
create or replace function public.world_pet_gift_apply_all() returns int
language plpgsql security definer set search_path = '' as $$
declare n int := 0; o uuid;
begin
  for o in select distinct owner_id from public.world_pet_gifts loop n := n + public.world_pet_gift_give(o); end loop;
  return n;
end $$;
revoke all on function public.world_pet_gift_apply_all() from public, anon, authenticated;
alter function public.world_pet_gift_apply_all() owner to fn_owner_field;

-- 새 캐릭터를 만들면 저절로(스위치 off면 아무것도 안 함, 캐릭터 행은 고치지 않는다)
create or replace function public.trg_world_pet_gift_on_create() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.world_pet_gifts where owner_id = new.owner_id) then
    perform public.world_pet_gift_give(new.owner_id);
  end if;
  return new;
end $$;
revoke all on function public.trg_world_pet_gift_on_create() from public, anon, authenticated;
alter function public.trg_world_pet_gift_on_create() owner to fn_owner_field;
drop trigger if exists trg_world_pet_gift_on_create on public.world_characters;
create trigger trg_world_pet_gift_on_create after insert on public.world_characters
  for each row execute function public.trg_world_pet_gift_on_create();

-- ── ③ 동무 두 자리 ─────────────────────────────
create table if not exists public.world_pet_profile (
  owner_id uuid primary key,
  pet_id text not null,
  set_at timestamptz not null default now()
);
alter table public.world_pet_profile enable row level security;
revoke all on public.world_pet_profile from anon, authenticated;
grant select, insert, update, delete on public.world_pet_profile to fn_owner_field;

-- 옮기기: 데리고 다니던(pet_out) 동무는 프로필 동무로, 그 별채는 빈다(같은 동무는 한 자리에만)
insert into public.world_pet_profile(owner_id, pet_id)
select h.owner_id, h.pet_id from public.world_housing h
 where h.pet_out and h.pet_id is not null and exists (select 1 from public.world_pets p where p.owner_id = h.owner_id and p.pet_id = h.pet_id)
on conflict (owner_id) do nothing;
update public.world_housing set pet_id = null, pet_out = false where pet_out;

-- 조사원 카드·남에게 보이는 프로필 동무(이름·자람)
create or replace function public.world_pet_profile_of(p_owner uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return (select jsonb_build_object('id', f.pet_id, 'nick', p.nickname, 'name', s.pet_name, 'adult', p.affinity >= 100, 'affinity', p.affinity)
            from public.world_pet_profile f
            join public.world_pets p on p.owner_id = f.owner_id and p.pet_id = f.pet_id
            join public.world_pet_species s on s.pet_id = f.pet_id
           where f.owner_id = p_owner);
end $$;
revoke all on function public.world_pet_profile_of(uuid) from public, anon, authenticated;
alter function public.world_pet_profile_of(uuid) owner to fn_owner_field;

-- 프로필 동무 정하기(null이면 비움). 그 동무가 내 별채에 있으면 별채에서 빠진다.
create or replace function public.world_pet_profile_set(p_pet text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); moved boolean := false; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh_pet_slot:' || uid::text));
  if p_pet is null then
    delete from public.world_pet_profile where owner_id = uid;
    return jsonb_build_object('ok', true, 'profile', null, 'content', '데리고 다니던 동무를 쉬게 했습니다.');
  end if;
  select coalesce(p.nickname, s.pet_name) into nm from public.world_pets p join public.world_pet_species s using (pet_id) where p.owner_id = uid and p.pet_id = p_pet;
  if nm is null then raise exception '함께하는 동무가 아닙니다.'; end if;
  update public.world_housing set pet_id = null, pet_out = false, updated_at = now() where owner_id = uid and pet_id = p_pet;
  moved := found;
  insert into public.world_pet_profile(owner_id, pet_id) values (uid, p_pet)
  on conflict (owner_id) do update set pet_id = excluded.pet_id, set_at = now();
  return jsonb_build_object('ok', true, 'profile', p_pet, 'from_house', moved,
    'content', public.world_josa(nm, '과', '와') || ' 함께 다닙니다.' || case when moved then ' 별채는 비었습니다.' else '' end);
end $$;
revoke all on function public.world_pet_profile_set(text) from public, anon;
grant execute on function public.world_pet_profile_set(text) to authenticated;
alter function public.world_pet_profile_set(text) owner to fn_owner_field;

-- 별채 동무 정하기: 프로필 동무였으면 프로필에서 빠진다
create or replace function public.world_pet_place(p_pet text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); moved boolean := false;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh_pet_slot:' || uid::text));
  if p_pet is not null and not exists (select 1 from public.world_pets where owner_id = uid and pet_id = p_pet) then raise exception '함께하는 동무가 아닙니다.'; end if;
  if public.world_housing_home(uid) <> uid then raise exception '함께 쓰는 별채에는 집주인의 동무가 머뭅니다. 내 동무는 데리고 다닐 수 있습니다.'; end if;
  update public.world_housing set pet_id = p_pet, pet_out = false, updated_at = now() where owner_id = uid;
  if not found then raise exception '별채를 얻은 뒤에 동무를 들일 수 있습니다.'; end if;
  if p_pet is not null then
    delete from public.world_pet_profile where owner_id = uid and pet_id = p_pet;
    moved := found;
  end if;
  return jsonb_build_object('ok', true, 'pet_id', p_pet, 'from_profile', moved,
    'content', case when p_pet is null then '별채의 동무를 쉬게 했습니다.' when moved then '데리고 다니던 동무를 별채에 두었습니다.' else '별채에 동무를 두었습니다.' end);
end $$;

-- 옛 「데리고 다니기」(화면이 새로 받기 전 호환): true = 별채 동무를 프로필로, false = 프로필 동무를 빈 별채로 돌려놓기
create or replace function public.world_pet_walk(p_out boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); h public.world_housing%rowtype; f text; has_h boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh_pet_slot:' || uid::text));
  select * into h from public.world_housing where owner_id = uid for update;
  has_h := found;
  if coalesce(p_out, false) then
    if not has_h or h.pet_id is null then raise exception '먼저 별채에 동무를 들이세요. 동무 창에서 바로 데리고 다닐 수도 있습니다.'; end if;
    insert into public.world_pet_profile(owner_id, pet_id) values (uid, h.pet_id) on conflict (owner_id) do update set pet_id = excluded.pet_id, set_at = now();
    update public.world_housing set pet_id = null, pet_out = false, updated_at = now() where owner_id = uid;
  else
    select pet_id into f from public.world_pet_profile where owner_id = uid;
    if f is null then raise exception '데리고 다니는 동무가 없습니다.'; end if;
    if has_h and h.pet_id is null and public.world_housing_home(uid) = uid then
      update public.world_housing set pet_id = f, pet_out = false, updated_at = now() where owner_id = uid;
    end if;
    delete from public.world_pet_profile where owner_id = uid;
  end if;
  return jsonb_build_object('ok', true, 'pet_out', coalesce(p_out, false));
end $$;

-- 동무 창: profile(프로필 동무) · room(내가 사는 별채가 내 것일 때만 별채 동무) · house(별채 있음) · shared(정인의 별채에 들어가 삶)
create or replace function public.world_pet_snapshot() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); today date := public.world_housing_today(); home uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  home := public.world_housing_home(uid);
  return jsonb_build_object(
    'species', (select coalesce(jsonb_agg(jsonb_build_object('id', s.pet_id, 'name', s.pet_name, 'grade', s.grade, 'kind', s.kind, 'likes', s.likes, 'how', s.how) order by s.sort), '[]'::jsonb) from public.world_pet_species s),
    'mine', (select coalesce(jsonb_agg(jsonb_build_object('id', p.pet_id, 'nick', p.nickname, 'affinity', p.affinity, 'adult', p.affinity >= 100, 'got_at', p.got_at,
        'pat', case when p.pat_day = today then p.pat_n else 0 end, 'play', case when p.play_day = today then p.play_n else 0 end, 'feed', case when p.feed_day = today then p.feed_n else 0 end) order by p.got_at), '[]'::jsonb)
      from public.world_pets p where p.owner_id = uid),
    'profile', (select f.pet_id from public.world_pet_profile f where f.owner_id = uid),
    'house', exists (select 1 from public.world_housing h where h.owner_id = home),
    'shared', home <> uid,
    'room', case when home = uid then (select jsonb_build_object('pet_id', h.pet_id, 'pet_out', false) from public.world_housing h where h.owner_id = uid) end);
end $$;

-- 조사원 카드: 별채가 없어도 프로필 동무를 보인다
select pg_temp.yh_patch('public.world_character_card(uuid)',
  $o$'pet', (select public.world_pet_room(c.owner_id) from public.world_housing hh where hh.owner_id = c.owner_id and hh.pet_out),$o$,
  $n$'pet', public.world_pet_profile_of(c.owner_id),$n$);

-- ════════ p7_notes.sql ════════
-- ── 7. 패치노트: 지난 기록은 「시험 기간 기록」으로, 새 번호는 1.0.0부터(CLAUDE.md 12-1) ─────────
-- 지난 노트 번호 앞에 「0-」를 붙여 새 1.0.0과 겹치지 않게 한다(note_id 검사 ^[0-9][0-9.-]{2,11}$ 통과, 공지 0.0.0은 그대로).
-- 화면(patch.js)은 0-로 시작하는 노트를 맨 아래 접힌 「시험 기간 기록」에 모아 보인다.
update public.world_patch_notes
   set note_id = '0-' || note_id,
       title = case when title like '[시험 기간]%' then title else '[시험 기간] ' || title end
 where note_id <> '0.0.0' and note_id not like '0-%';

insert into public.world_patch_notes(note_id, title, body) values ('1.0.0', '1.0.0 · 두 번째 밤', $N$
## 다시 문을 엽니다
첫째 밤(시험 기간)이 끝나고 서버를 처음 상태로 되돌렸습니다. 계정은 그대로이고, 새 조사원을 만들어 두 번째 밤을 시작합니다.
- 캐릭터·가방·진행도·칭호·별채·동무·친구·모임·서신·제보 기록을 모두 비웠습니다. 세력 판도도 처음으로 돌아갔습니다.
- 시험 기간에 바뀐 규칙(생산 기술 개편·우수품·효과 정리 등)은 그대로 남습니다. 지난 기록은 이 화면 맨 아래 「시험 기간 기록」에서 볼 수 있습니다.

## 야행(夜行)의 흔적
첫째 밤을 함께한 조사원에게는 새 캐릭터를 만들면 「야행의 흔적」 세트가 남습니다(능력치 효과 없음, 얻는 다른 길 없음).
- 칭호 「제일야(第一夜)의 증인」·「미완(未完)의 길을 연 자」·「꺼지지 않은 불씨」
- 테두리 「야행(夜行)의 테」 · 바탕 무늬 「흑야 운문」 · 낙관 「痕」 · 이름 색 「야행묵금」

## 꼬마 동무
- 새 동무 8종: 네눈박이 강아지·흰둥이 강아지·잿빛 장모 고양이·점박이 하늘다람쥐·꼬마 족제비·금빛 날개늑대·외뿔 팔족염소·꼬마 홍룡(조사원 제보로 태어났습니다).
- **동무 두 자리**: 데리고 다니는 동무(조사원 카드에 보임, 별채가 없어도 됨)와 별채에 머무는 동무를 따로 정합니다.

## 초대권
- 받은 초대권 번호는 설정 › 계정에서 볼 수 있고, 오늘부터 7일 동안 쓸 수 있습니다.
$N$)
on conflict (note_id) do update set title = excluded.title, body = excluded.body;

-- ════════ p8_reopen.sql ════════
-- ── 8. 다시 열 준비 ───────────────────────────────────────────────────────────────
-- 동무 선물은 하지 않는다(사용자 결정 2026-10-31): 스위치 off, 선물 명단도 비움
update public.world_app_meta set value = 'off' where key = 'pet_gift';
do $g$ begin if to_regclass('public.world_pet_gifts') is not null then delete from public.world_pet_gifts; end if; end $g$;

-- 초대권: 이 순간부터 7일(world_invite_* 함수가 invite_open_at을 본다)
insert into public.world_app_meta(key, value, changed_at) values ('invite_open_at', now()::text, now())
on conflict (key) do update set value = excluded.value, changed_at = now();

-- 확인: 남은 캐릭터 0, 운영진 명단·초대권·레거시 명단은 그대로
do $v$
declare n int;
begin
  select count(*) into n from public.world_characters;
  if n <> 0 then raise exception 'ROLLBACK: 캐릭터가 % 남았다', n; end if;
  if not exists (select 1 from public.world_staff) then raise exception 'ROLLBACK: 운영진 명단이 비었다'; end if;
  if not exists (select 1 from public.world_legacy_marks) then raise exception 'ROLLBACK: 레거시 명단이 비었다'; end if;
  if public.world_long_night_stage(timestamptz '2026-11-05 12:00+09') <> 0 then raise exception 'ROLLBACK: 장야가 끝나지 않았다'; end if;
end $v$;

update public.world_app_meta set value = '20261105000000' where key = 'db_version';

set local check_function_bodies = on;
