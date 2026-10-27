-- 프로필 꾸미기: 테두리(frame) · 바탕 무늬(pattern) · 낙관(seal).
-- - 전투·탐사·이동·이야기·제작·채집·낚시·교류·거래·원정·성장·숨김 등 여러 활동에서 얻는다(칭호, 행동 기록, 친구·거래·도감 수).
-- - 소유는 world_character_cosmetics에 남고, 칭호 판정(world_title_award_check)이 돌 때 함께 판정한다. 같은 꾸미기는 두 번 얻지 않는다.
-- - 장착은 world_cosmetic_equip이 소유를 확인한 뒤 world_characters.profile의 frame/pattern/seal 키에 쓴다(클라이언트는 profile을 직접 고칠 수 없다).
-- - 숨김 꾸미기는 얻기 전까지 이름·조건을 서버가 감춘다. 움직임 효과는 아직 없다(정지된 그림).
-- SQL Editor에서 한 번 실행한다. 다시 실행해도 안전하다.

create table if not exists public.world_cosmetic_catalog (
  cosmetic_key text primary key,
  kind text not null check (kind in ('frame', 'pattern', 'seal')),
  tier text not null default 'common' check (tier in ('common', 'rare', 'legend')),
  cosmetic_name text not null,
  condition_text text not null default '',
  category text not null default '',
  rule jsonb not null,
  hidden boolean not null default false,
  active boolean not null default true,
  sort int not null default 0
);
alter table public.world_cosmetic_catalog enable row level security;
revoke all on public.world_cosmetic_catalog from anon, authenticated;  -- 목록은 RPC로만 본다(숨김 조건 보호)

create table if not exists public.world_character_cosmetics (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  cosmetic_key text not null references public.world_cosmetic_catalog(cosmetic_key) on delete cascade,
  unlocked_at timestamptz not null default now(),
  primary key (owner_id, cosmetic_key)
);
alter table public.world_character_cosmetics enable row level security;
drop policy if exists world_character_cosmetics_read_own on public.world_character_cosmetics;
create policy world_character_cosmetics_read_own on public.world_character_cosmetics for select to authenticated using (owner_id = (select auth.uid()));
revoke all on public.world_character_cosmetics from anon, authenticated;
grant select on public.world_character_cosmetics to authenticated;

grant select on public.world_cosmetic_catalog to fn_owner_field;
grant select, insert on public.world_character_cosmetics to fn_owner_field;
grant select on public.world_fish_log, public.world_direct_trades, public.world_friends to fn_owner_field;

/* ── 꾸미기 목록(36종) ───────────────────────────────── */
insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, sort) values
  -- 테두리 22
  ('fr_lantern', 'frame', 'common', '초롱 테두리', '처음으로 밤길을 탐색한다', '탐사', '{"ev": "explore"}', false, 10),
  ('fr_path', 'frame', 'common', '오솔길 테두리', '새 갈림길·장소 20곳을 찾는다', '탐사', '{"nodes": 20}', false, 11),
  ('fr_compass', 'frame', 'legend', '팔방 나침 테두리', '지역 세 곳을 완전 답사한다', '탐사', '{"survey_full": 3}', false, 12),
  ('fr_blade', 'frame', 'common', '칼날 테두리', '요괴를 50번 물리친다', '전투', '{"n": 50, "ev": "combat"}', false, 20),
  ('fr_gatekeeper', 'frame', 'rare', '수문장 테두리', '우두머리 요괴를 5번 쓰러뜨린다', '전투', '{"n": 5, "p": {"rank": "guardian"}, "ev": "combat"}', false, 21),
  ('fr_hundred_ghosts', 'frame', 'legend', '백귀 문양 테두리', '칭호 「천귀 퇴치」를 얻는다', '전투', '{"title": "slayer_500"}', false, 22),
  ('fr_hoof', 'frame', 'common', '말굽 테두리', '탈것을 둘 들인다', '이동', '{"mounts": 2}', false, 30),
  ('fr_wind', 'frame', 'rare', '바람결 테두리', '서로 다른 지역 20곳에 가 본다', '이동', '{"n": 20, "key": "region_id", "distinct": "travel"}', false, 31),
  ('fr_red_seal', 'frame', 'common', '붉은 인장 테두리', '이야기 「붉은 인장」을 끝낸다', '이야기', '{"p": {"chapter_id": "red_seal"}, "ev": "story"}', false, 40),
  ('fr_talisman', 'frame', 'legend', '봉인 부적 테두리', '이야기 「구문 돌파」를 끝낸다', '이야기', '{"p": {"chapter_id": "nine_gates"}, "ev": "story"}', false, 41),
  ('fr_hammer', 'frame', 'common', '망치 테두리', '물건을 30번 만든다', '제작', '{"n": 30, "ev": "craft"}', false, 50),
  ('fr_workshop', 'frame', 'rare', '공방 테두리', '품질 80 이상의 물건을 5번 만든다', '제작', '{"n": 5, "ev": "craft", "gte": {"quality": 80}}', false, 51),
  ('fr_leaf', 'frame', 'common', '풀잎 테두리', '채집을 80번 한다', '채집', '{"n": 80, "ev": "gather"}', false, 60),
  ('fr_earth', 'frame', 'legend', '대지 테두리', '칭호 「대지의 손」을 얻는다', '채집', '{"title": "gather_500"}', false, 61),
  ('fr_wave', 'frame', 'common', '물결 테두리', '물고기를 20마리 낚는다', '낚시', '{"n": 20, "p": {"caught": true}, "ev": "fish"}', false, 70),
  ('fr_dragon_scale', 'frame', 'legend', '용비늘 테두리', '전설의 물고기를 낚는다', '낚시', '{"title": "dragon_koi"}', true, 71),
  ('fr_knot', 'frame', 'common', '매듭 테두리', '친구를 세 명 맺는다', '교류', '{"friends": 3}', false, 80),
  ('fr_twin_tree', 'frame', 'rare', '연리지 테두리', '쓰러진 조사원을 5번 구조한다', '교류', '{"n": 5, "ev": "rescue", "has": "target_id"}', false, 81),
  ('fr_coin', 'frame', 'common', '엽전 테두리', '다른 조사원과 직접 거래를 5번 성사시킨다', '거래', '{"trades": 5}', false, 90),
  ('fr_moon', 'frame', 'rare', '월하 테두리', '원정을 10번 다녀온다', '원정', '{"n": 10, "ev": "expedition_end"}', false, 100),
  ('fr_night_lamp', 'frame', 'legend', '야행 등불 테두리', '25레벨에 이른다', '성장', '{"n": 25, "char": "level"}', false, 110),
  ('fr_bloodmist', 'frame', 'rare', '혈무 테두리', '혈무 속에서 요괴를 10번 물리친다', '숨김', '{"n": 10, "p": {"env_weather": "bloodmist"}, "ev": "combat"}', true, 120),
  -- 바탕 무늬 6
  ('pt_mapline', 'pattern', 'rare', '지도선 무늬', '지역 한 곳을 완전 답사한다', '탐사', '{"survey_full": 1}', false, 200),
  ('pt_ripple', 'pattern', 'common', '물비늘 무늬', '어종 8가지를 낚는다', '낚시', '{"fish_species": 8}', false, 210),
  ('pt_cloud', 'pattern', 'common', '구름 무늬', '안개 낀 날 30번 탐색한다', '탐사', '{"n": 30, "p": {"env_weather": "fog"}, "ev": "explore"}', false, 220),
  ('pt_lattice', 'pattern', 'common', '꽃살 무늬', '의뢰를 20번 해결한다', '이야기', '{"n": 20, "ev": "commission"}', false, 230),
  ('pt_stars', 'pattern', 'rare', '별자리 무늬', '삼경(밤 0~6시)에 50번 탐색한다', '탐사', '{"n": 50, "ev": "explore", "phase": "night"}', false, 240),
  ('pt_bamboo', 'pattern', 'common', '대숲 무늬', '세력 보급을 15번 받는다', '세력', '{"n": 15, "ev": "supply"}', false, 250),
  -- 낙관 8
  ('sl_tao', 'seal', 'rare', '낙관 「討」', '칭호 「우두머리 격파」를 얻는다', '전투', '{"title": "guardian_breaker"}', false, 300),
  ('sl_tam', 'seal', 'common', '낙관 「探」', '탐색 중 단서를 15번 찾는다', '이야기', '{"n": 15, "p": {"outcome": "clue"}, "ev": "explore"}', false, 310),
  ('sl_jang', 'seal', 'rare', '낙관 「匠」', '물건을 100번 만든다', '제작', '{"n": 100, "ev": "craft"}', false, 320),
  ('sl_hae', 'seal', 'common', '낙관 「解」', '단서를 5번 조합한다', '이야기', '{"n": 5, "ev": "case_combine"}', false, 330),
  ('sl_yu', 'seal', 'common', '낙관 「遊」', '60번 길을 떠난다', '이동', '{"n": 60, "ev": "travel"}', false, 340),
  ('sl_eo', 'seal', 'rare', '낙관 「漁」', '어종 15가지를 낚는다', '낚시', '{"fish_species": 15}', false, 350),
  ('sl_woo', 'seal', 'rare', '낙관 「友」', '친구를 열 명 맺는다', '교류', '{"friends": 10}', false, 360),
  ('sl_ya', 'seal', 'legend', '낙관 「夜」', '칭호 30개를 모은다', '성장', '{"titles": 30}', true, 370)
on conflict (cosmetic_key) do nothing;

/* ── 판정 ─────────────────────────────────────────────── */
create or replace function public.world_cosmetic_rule_ok(p_owner uuid, p_rule jsonb)
returns boolean language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare v numeric; x jsonb;
begin
  if p_rule is null then return false; end if;
  if p_rule ? 'all' then
    for x in select value from jsonb_array_elements(p_rule -> 'all') loop
      if not public.world_cosmetic_rule_ok(p_owner, x) then return false; end if;
    end loop;
    return true;
  elsif p_rule ? 'title' then
    return exists (select 1 from public.world_character_titles t where t.owner_id = p_owner and t.title_key = p_rule ->> 'title');
  elsif p_rule ? 'friends' then
    select count(*) into v from public.world_friends f where f.status = 'accepted' and (f.owner_id = p_owner or f.friend_id = p_owner);
    return v >= (p_rule ->> 'friends')::numeric;
  elsif p_rule ? 'trades' then
    select count(*) into v from public.world_direct_trades d where d.status = 'accepted' and (d.from_id = p_owner or d.to_id = p_owner);
    return v >= (p_rule ->> 'trades')::numeric;
  elsif p_rule ? 'fish_species' then
    select count(*) into v from public.world_fish_log l where l.owner_id = p_owner and coalesce(l.caught, 0) > 0;
    return v >= (p_rule ->> 'fish_species')::numeric;
  end if;
  return public.world_title_rule_ok(p_owner, p_rule);
end $$;

create or replace function public.world_cosmetic_award_check(p_owner uuid, p_event_type text default null)
returns integer language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare t record; got int := 0; r jsonb; kname text;
begin
  if p_owner is null or not exists (select 1 from public.world_characters where owner_id = p_owner) then return 0; end if;
  for t in select cc.* from public.world_cosmetic_catalog cc
           where cc.active and not exists (select 1 from public.world_character_cosmetics o where o.owner_id = p_owner and o.cosmetic_key = cc.cosmetic_key)
           order by cc.sort loop
    r := t.rule;
    -- 행동 하나가 끝날 때는 그 행동과 관계있는 조건만 본다(무거운 답사 판정은 탐색·원정 뒤에만)
    if p_event_type is not null then
      if r ? 'ev' and r ->> 'ev' <> p_event_type then continue; end if;
      if r ? 'distinct' and r ->> 'distinct' <> p_event_type then continue; end if;
      if (r ? 'survey_full' or r ? 'nodes' or r ? 'spots') and p_event_type not in ('explore', 'expedition_end') then continue; end if;
      if r ? 'mounts' and p_event_type not in ('mount', 'story', 'expedition_end', 'case_resolved') then continue; end if;
    end if;
    if public.world_cosmetic_rule_ok(p_owner, r) then
      insert into public.world_character_cosmetics(owner_id, cosmetic_key) values (p_owner, t.cosmetic_key) on conflict do nothing;
      if found then
        got := got + 1;
        kname := case t.kind when 'frame' then '테두리' when 'pattern' then '바탕 무늬' else '낙관' end;
        insert into public.world_notifications(user_id, kind, title, content, payload)
        values (p_owner, 'cosmetic', '새 프로필 ' || kname, '「' || t.cosmetic_name || '」을 얻었습니다 · 게임 설정 › 프로필 › 꾸미기에서 고를 수 있습니다.',
                jsonb_build_object('cosmetic_key', t.cosmetic_key, 'kind', t.kind));
      end if;
    end if;
  end loop;
  return got;
end $$;

/* ── 내 꾸미기 목록(들어올 때 밀린 판정을 한 번 돌린다) ── */
create or replace function public.world_cosmetic_snapshot()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); prof jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select profile into prof from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  perform public.world_cosmetic_award_check(uid, null);
  return jsonb_build_object(
    'equipped', jsonb_build_object('frame', prof ->> 'frame', 'pattern', prof ->> 'pattern', 'seal', prof ->> 'seal'),
    'items', (select coalesce(jsonb_agg(jsonb_build_object(
        'key', case when cc.hidden and o.owner_id is null then null else cc.cosmetic_key end,
        'kind', cc.kind, 'tier', cc.tier, 'hidden', cc.hidden, 'category', cc.category,
        'owned', o.owner_id is not null, 'unlocked_at', o.unlocked_at,
        'name', case when cc.hidden and o.owner_id is null then '숨겨진 꾸미기' else cc.cosmetic_name end,
        'hint', case when cc.hidden and o.owner_id is null then '어떻게 얻는지 알려지지 않았습니다.' else cc.condition_text end)
        order by cc.kind, cc.sort), '[]'::jsonb)
      from public.world_cosmetic_catalog cc
      left join public.world_character_cosmetics o on o.cosmetic_key = cc.cosmetic_key and o.owner_id = uid
      where cc.active));
end $$;

/* ── 장착·해제 ───────────────────────────────────────── */
create or replace function public.world_cosmetic_equip(p_kind text, p_key text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_kind is null or p_kind not in ('frame', 'pattern', 'seal') then raise exception '꾸미기 종류가 올바르지 않습니다.'; end if;
  perform 1 from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if p_key is null or p_key = '' then
    update public.world_characters set profile = coalesce(profile, '{}'::jsonb) - p_kind, updated_at = now() where owner_id = uid;
    return jsonb_build_object('ok', true, 'content', '꾸미기를 내렸습니다.');
  end if;
  select cc.cosmetic_name into nm from public.world_character_cosmetics o join public.world_cosmetic_catalog cc using (cosmetic_key)
   where o.owner_id = uid and o.cosmetic_key = p_key and cc.kind = p_kind and cc.active;
  if nm is null then raise exception '얻은 꾸미기만 고를 수 있습니다.'; end if;
  update public.world_characters set profile = coalesce(profile, '{}'::jsonb) || jsonb_build_object(p_kind, p_key), updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'content', '「' || nm || '」을 달았습니다.');
end $$;

do $$ declare f text;
begin
  foreach f in array array['world_cosmetic_rule_ok(uuid, jsonb)', 'world_cosmetic_award_check(uuid, text)', 'world_cosmetic_snapshot()', 'world_cosmetic_equip(text, text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
  execute 'grant execute on function public.world_cosmetic_snapshot() to authenticated';
  execute 'grant execute on function public.world_cosmetic_equip(text, text) to authenticated';
end $$;

/* ── 칭호 판정이 돌 때 꾸미기도 함께 판정한다(꾸미기 판정이 실패해도 원래 행동은 막지 않는다) ── */
do $$ declare def text; nd text;
begin
  def := pg_get_functiondef('public.world_title_award_check(uuid, text)'::regprocedure);
  if position('world_cosmetic_award_check' in def) = 0 then
    nd := replace(def, '  RETURN got;
END', '  BEGIN PERFORM public.world_cosmetic_award_check(p_owner_id, p_event_type); EXCEPTION WHEN others THEN NULL; END;
  RETURN got;
END');
    if position('world_cosmetic_award_check' in nd) = 0 then raise exception 'world_title_award_check 고칠 곳을 찾지 못했습니다.'; end if;
    execute nd;
  end if;
end $$;

select 'ok' as result,
  (select count(*) from public.world_cosmetic_catalog) as cosmetics,
  (select count(*) filter (where kind = 'frame') from public.world_cosmetic_catalog) as frames,
  (select count(*) filter (where kind = 'pattern') from public.world_cosmetic_catalog) as patterns,
  (select count(*) filter (where kind = 'seal') from public.world_cosmetic_catalog) as seals,
  position('world_cosmetic_award_check' in pg_get_functiondef('public.world_title_award_check(uuid, text)'::regprocedure)) > 0 as hooked;
