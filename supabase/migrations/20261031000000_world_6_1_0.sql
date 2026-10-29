-- 6.1.0 최종 콘텐츠: 합동 토벌(공유 체력·자유 행동) · 협동 기술 · 10장 최종 결전 · 서버 보스 「봉연의 그림자」
--   6.0.0(20261030000000)을 먼저 돌린 뒤 실행한다(퀘스트 표·함수를 고친다).
--   ① 협동 기술: 직업마다 4가지, 전투 숙련(combat_rank) 3·8·18·36단계(고유 기술이 없는 자리)에서 열린다.
--      합동 토벌에서만 그 턴에 골라 쓰고(영력·기력 소모·재사용 대기), 파티 원정의 합동 전투에서는 확률로 저절로 나온다.
--   ② 합동 토벌: 보스 체력 하나를 신청한 조사원들이 함께 깎는다. 행동 간격 1초, 보스는 이목에 비례해 표적을 고르고
--      체력 70%·40%에서 단계가 바뀌며 광역 강타·사슬 묶기·모으기를 쓴다. 쓰러지면 그 토벌에서만 1분 물러난다(전투불능 아님).
--      신청하지 않은 사람도 같은 화면에서 관전한다(world_raids 실시간 구독).
--   ③ 10장 최종 결전(fq_sealed_lord): 혼자 또는 같은 곳의 파티원과 4명까지. 인원에 따라 보스 체력 ×1·1.7·2.3·2.8.
--   ④ 서버 보스: 앞 회차가 끝나고 72~96시간 뒤 무작위. 24시간 전 후보 셋, 12시간 전 확정, 6·3시간 전 알림.
--      출현 뒤 30분 그 지역에서 신청, 2시간 전투. 레벨 보정은 전투에만(보스가 표적 레벨+3으로 친다), 기여도는 레벨/30을 곱한다.
--      실패하면 다음 회차까지 「봉연에 잠김」: 출현 지역 침식 +30%·조우 +10%·채집량 −25%·받는 피해 +10%,
--      바로 이웃 침식 +30%·조우 +10%, 이웃의 이웃 침식 +10%·조우 +5%.

grant fn_owner_field to postgres with inherit true, set true;

-- ① 협동 기술 ───────────────────────────────────────────────
create table if not exists public.world_coop_skills (
  skill_id text primary key, job_key text not null, unlock_rank int not null, skill_name text not null, description text not null,
  target text not null check (target in ('ally', 'all', 'boss', 'self')), effect jsonb not null, cost int not null default 0,
  cooldown_s int not null default 10, exp_win numeric not null default 0, exp_heal int not null default 0, exp_text text not null, sort int not null default 0);
alter table public.world_coop_skills enable row level security;
revoke all on public.world_coop_skills from anon, authenticated;
grant select on public.world_coop_skills to fn_owner_field;

insert into public.world_coop_skills(skill_id, job_key, unlock_rank, skill_name, description, target, effect, cost, cooldown_s, exp_win, exp_heal, exp_text, sort) values
  ('seal_ward',   'sealmaster', 3,  '호신부 나누기', '동료 한 명에게 호신부를 건넨다. 그 동료가 다음 세 번 받는 피해 −25%.', 'ally', '{"type":"ward","pct":25,"n":3}', 4, 8, 0.04, 0, '동료에게 호신부를 건넸습니다', 1),
  ('seal_might',  'sealmaster', 8,  '기세 부적', '동료 한 명의 다음 세 번 공격 피해 +20%.', 'ally', '{"type":"might","pct":20,"n":3}', 6, 12, 0.05, 0, '기세 부적을 붙여 동료의 칼끝을 북돋웠습니다', 2),
  ('seal_chain',  'sealmaster', 18, '봉인 사슬', '보스를 사슬로 묶는다. 다음 반격 한 번을 막고, 보스가 받는 피해가 여섯 번 동안 +15%.', 'boss', '{"type":"expose","pct":15,"n":6,"stagger":1}', 10, 20, 0.06, 0, '봉인 사슬로 요괴를 옭아맸습니다', 3),
  ('seal_bagua',  'sealmaster', 36, '팔괘 결계', '참가자 모두가 다음 두 번 받는 피해 −20%.', 'all', '{"type":"ward_all","pct":20,"n":2}', 14, 30, 0.07, 0, '팔괘 결계를 펼쳐 모두를 감쌌습니다', 4),
  ('med_aid',     'medic', 3,  '응급 처치', '동료 한 명의 체력을 16 회복한다(응급 처치 기술 단계만큼 더).', 'ally', '{"type":"heal","amt":16}', 4, 6, 0, 8, '다친 동료를 응급 처치했습니다', 1),
  ('med_needle',  'medic', 8,  '해독 침', '동료 한 명의 사슬 묶임을 풀고 체력을 10 회복한다.', 'ally', '{"type":"cleanse_heal","amt":10}', 6, 12, 0, 10, '침으로 동료의 기혈을 풀었습니다', 2),
  ('med_revive',  'medic', 18, '야전 소생', '물러난 동료를 곧바로 되돌린다(체력 35).', 'ally', '{"type":"revive","hp":35}', 12, 60, 0.03, 15, '쓰러질 뻔한 동료를 일으켜 세웠습니다', 3),
  ('med_pulse',   'medic', 36, '회춘 진맥', '참가자 모두의 체력을 12 회복한다.', 'all', '{"type":"heal_all","amt":12}', 14, 30, 0, 14, '모두의 맥을 짚어 기운을 돌렸습니다', 4),
  ('exo_cover',   'exorcist', 3,  '대신 막기', '12초 동안 그 동료를 노린 공격을 대신 맞는다(피해 절반).', 'ally', '{"type":"cover","secs":12}', 4, 12, 0.04, 0, '동료 앞을 막아섰습니다', 1),
  ('exo_mantra',  'exorcist', 8,  '파사 진언', '동료 한 명이 다음에 받는 광역·모으기 피해 −50%, 정신 +6.', 'ally', '{"type":"gward","pct":50,"n":1,"mind":6}', 6, 15, 0.05, 0, '파사 진언으로 동료의 마음을 붙들었습니다', 2),
  ('exo_barrier', 'exorcist', 18, '퇴마 결계', '보스의 다음 광역 강타·터뜨림 피해를 절반으로 줄인다.', 'all', '{"type":"break","pct":50}', 10, 25, 0.06, 0, '퇴마 결계로 큰 공격을 받아 냈습니다', 3),
  ('exo_guardian','exorcist', 36, '호법 신장', '세 번 동안 이목 +120으로 공격을 끌어오고 받는 피해 −30%.', 'self', '{"type":"taunt","pres":120,"pct":30,"n":3}', 12, 30, 0.07, 0, '호법 신장을 불러 앞에 섰습니다', 4),
  ('sc_mark',     'scout', 3,  '약점 표시', '참가자 모두의 다음 두 번 공격 치명타율 +15%.', 'boss', '{"type":"crit_all","pct":15,"n":2}', 4, 10, 0.04, 0, '요괴의 약점에 표식을 남겼습니다', 1),
  ('sc_path',     'scout', 8,  '길 터주기', '동료 한 명이 다음 두 번 공격을 피할 확률 +25%.', 'ally', '{"type":"evade","pct":25,"n":2}', 5, 12, 0.04, 0, '동료에게 빠질 길을 일러 주었습니다', 2),
  ('sc_smoke',    'scout', 18, '연막', '보스의 다음 두 번 단일 공격이 45% 확률로 빗나간다.', 'all', '{"type":"smoke","miss":45,"n":2}', 8, 22, 0.06, 0, '연막을 피워 요괴의 눈을 가렸습니다', 3),
  ('sc_signal',   'scout', 36, '추격 신호', '참가자 모두의 다음 공격 피해 +25%.', 'all', '{"type":"rally","pct":25,"n":1}', 10, 25, 0.06, 0, '추격 신호로 모두를 한꺼번에 몰아붙였습니다', 4),
  ('an_share',    'artificer', 3,  '패턴 공유', '보스의 다음 수를 알려 참가자 모두가 다음 한 번 받는 피해 −12%.', 'all', '{"type":"ward_all","pct":12,"n":1}', 4, 10, 0.04, 0, '요괴의 다음 수를 읽어 알렸습니다', 1),
  ('an_point',    'artificer', 8,  '급소 지시', '동료 한 명의 다음 공격을 치명타로 만든다.', 'ally', '{"type":"crit_next"}', 5, 10, 0.05, 0, '동료에게 급소를 짚어 주었습니다', 2),
  ('an_break',    'artificer', 18, '흐름 끊기', '보스의 다음 반격 두 번을 막고, 모으는 중이면 세 번 더 늦춘다.', 'boss', '{"type":"delay","n":2}', 9, 22, 0.06, 0, '요괴의 흐름을 끊었습니다', 3),
  ('an_command',  'artificer', 36, '전장 지휘', '참가자 모두의 다음 세 번 공격 피해 +15%.', 'all', '{"type":"might_all","pct":15,"n":3}', 14, 30, 0.07, 0, '전장을 지휘해 모두의 공격을 맞췄습니다', 4),
  ('art_mend',    'analyst', 3,  '현장 수선', '동료 한 명의 방어구를 손봐 다음 세 번 받는 피해 −15%.', 'ally', '{"type":"ward","pct":15,"n":3}', 3, 8, 0.03, 0, '동료의 방어구를 그 자리에서 손봤습니다', 1),
  ('art_supply',  'analyst', 8,  '영력 보급', '동료 한 명의 영력(기력)을 20 채운다. 영력이 들지 않는다.', 'ally', '{"type":"sp","amt":20}', 0, 20, 0.03, 0, '동료에게 영력을 나눠 주었습니다', 2),
  ('art_shield',  'analyst', 18, '방호 법구', '동료 한 명에게 피해 25를 먼저 받아 내는 보호막을 씌운다.', 'ally', '{"type":"shield","amt":25}', 8, 18, 0, 10, '방호 법구로 동료를 감쌌습니다', 3),
  ('art_array',   'analyst', 36, '공명 법진', '참가자 모두의 다음 세 번 공격 +10%·받는 피해 −10%.', 'all', '{"type":"resonance","pct":10,"n":3}', 14, 30, 0.07, 0, '공명 법진을 깔아 모두의 힘을 맞췄습니다', 4)
on conflict (skill_id) do update set job_key = excluded.job_key, unlock_rank = excluded.unlock_rank, skill_name = excluded.skill_name,
  description = excluded.description, target = excluded.target, effect = excluded.effect, cost = excluded.cost, cooldown_s = excluded.cooldown_s,
  exp_win = excluded.exp_win, exp_heal = excluded.exp_heal, exp_text = excluded.exp_text, sort = excluded.sort;

-- 내 직업의 협동 기술(열린 것·열리는 단계) — 캐릭터 › 기술
create or replace function public.world_coop_list()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', s.skill_id, 'name', s.skill_name, 'desc', s.description, 'target', s.target, 'cost', s.cost,
      'cooldown', s.cooldown_s, 'rank', s.unlock_rank, 'unlocked', coalesce(c.combat_rank, 1) >= s.unlock_rank) order by s.sort)
    from public.world_coop_skills s where s.job_key = c.job_key), '[]'::jsonb);
end $$;

-- 원정 합동 전투의 협동 기술: 함께 싸우는 사람마다 열린 기술이 10%씩, 한 싸움에 두 번까지 저절로 나온다
create or replace function public.world_coop_exp_procs(p_owner uuid, p_allies jsonb)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare r record; win numeric := 0; heal int := 0; lines jsonb := '[]'::jsonb; k int := 0;
begin
  for r in
    select ch.owner_id, ch.character_name, s.skill_name, s.exp_win, s.exp_heal, s.exp_text
      from public.world_characters ch join public.world_coop_skills s on s.job_key = ch.job_key and s.unlock_rank <= coalesce(ch.combat_rank, 1)
     where ch.owner_id = p_owner or ch.owner_id in (select (x ->> 'owner')::uuid from jsonb_array_elements(coalesce(p_allies, '[]'::jsonb)) x)
     order by random()
  loop
    exit when k >= 2;
    if random() < 0.10 then
      k := k + 1; win := win + r.exp_win; heal := heal + r.exp_heal;
      lines := lines || jsonb_build_object('who', r.character_name, 'owner', r.owner_id,
        'text', '[협동 · ' || r.skill_name || '] ' || r.exp_text || case when r.exp_heal > 0 then ' (체력 +' || r.exp_heal || ')' else '' end || '.');
    end if;
  end loop;
  return jsonb_build_object('win', win, 'heal', heal, 'lines', lines);
end $$;

-- ② 합동 토벌 ───────────────────────────────────────────────
create table if not exists public.world_raids (
  raid_id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('world', 'final')),
  boss_name text not null, region_id text not null,
  status text not null check (status in ('announced', 'signup', 'fight', 'won', 'failed')),
  hp int not null default 0, max_hp int not null default 0, turn int not null default 0, phase int not null default 1,
  intent text, fx jsonb not null default '{}'::jsonb, leader_id uuid, candidates text[] not null default '{}', notices text[] not null default '{}',
  spawn_at timestamptz, signup_until timestamptz, ends_at timestamptz, ended_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index if not exists world_raids_status on public.world_raids(kind, status);
create table if not exists public.world_raid_members (
  raid_id uuid not null references public.world_raids(raid_id) on delete cascade, owner_id uuid not null,
  name text not null, level int not null, job_key text, joined_at timestamptz not null default now(),
  dmg int not null default 0, heal int not null default 0, coop int not null default 0, guarded int not null default 0,
  falls int not null default 0, acts int not null default 0, contrib numeric not null default 0,
  last_action_at timestamptz, out_until timestamptz, fx jsonb not null default '{}'::jsonb, cd jsonb not null default '{}'::jsonb,
  stats jsonb not null default '{}'::jsonb, reward jsonb, primary key (raid_id, owner_id));
create index if not exists world_raid_members_owner on public.world_raid_members(owner_id);
create table if not exists public.world_raid_log (
  id bigserial primary key, raid_id uuid not null references public.world_raids(raid_id) on delete cascade,
  at timestamptz not null default now(), kind text not null default 'info', text text not null);
create index if not exists world_raid_log_raid on public.world_raid_log(raid_id, id desc);
create table if not exists public.world_raid_locks (region_id text primary key, raid_id uuid, until timestamptz not null);
do $$ declare t text; begin
  foreach t in array array['world_raids', 'world_raid_members', 'world_raid_log', 'world_raid_locks'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to fn_owner_field', t);
  end loop;
end $$;
grant usage on sequence public.world_raid_log_id_seq to fn_owner_field;
-- 관전·예고 화면이 바뀜을 실시간으로 알도록 토벌 줄만 읽게 한다(보스 이름·체력·상태 같은 공개 정보)
grant select on public.world_raids to authenticated;
drop policy if exists world_raids_read on public.world_raids;
create policy world_raids_read on public.world_raids for select to authenticated using (true);
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'world_raids') then
    execute 'alter publication supabase_realtime add table public.world_raids';
  end if;
end $$;
grant insert on public.world_chat_messages to fn_owner_field;
grant insert on public.world_notifications to fn_owner_field;

-- 전체 채팅 「봉연 소식」 한 줄(보내는 사람 칸은 비울 수 없어 운영진 캐릭터로 남기고, 화면은 시스템 줄로 그린다)
create or replace function public.world_raid_chat(p_text text)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare who uuid := coalesce((select owner_id from public.world_staff order by owner_id limit 1), (select owner_id from public.world_characters order by owner_id limit 1));
begin
  if who is null then return; end if;
  insert into public.world_chat_messages(channel_type, sender_id, sender_name, content) values ('global', who, '봉연 소식', p_text);
end $$;

create or replace function public.world_raid_say(p_raid uuid, p_kind text, p_text text)
returns void language sql security definer set search_path to 'pg_catalog', 'public' as $$
  insert into public.world_raid_log(raid_id, kind, text) values (p_raid, p_kind, p_text)
$$;

-- 지도 이웃(이동 길로 바로 이어진 곳)
create or replace function public.world_region_neighbors(p_region text)
returns setof text language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select x from public.world_map_regions r, unnest(r.travel_from) x where r.region_id = p_region
  union select r.region_id from public.world_map_regions r where p_region = any (r.travel_from)
$$;

-- 봉연에 잠김: 출현 지역 침식 +30%·조우 +10%·채집량 −25%·받는 피해 +10%, 바로 이웃 침식 +30%·조우 +10%, 이웃의 이웃 침식 +10%·조우 +5%
create or replace function public.world_raid_lock_effect(p_key text)
returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare here text; v numeric := 0; l record; d int;
begin
  if p_key not in ('erosion_pct', 'encounter_pct', 'gather_qty_pct', 'incoming_damage_pct') then return 0; end if;
  if not exists (select 1 from public.world_raid_locks where until > now()) then return 0; end if;
  select r.region_id into here from public.world_characters c join public.world_map_regions r on r.region_name = c.location
   where c.owner_id = public.fn_owner_auth_uid() and not coalesce(r.is_safe_zone, false) limit 1;
  if here is null then return 0; end if;
  for l in select region_id from public.world_raid_locks where until > now() loop
    d := case when here = l.region_id then 0
              when here in (select public.world_region_neighbors(l.region_id)) then 1
              when here in (select public.world_region_neighbors(n) from public.world_region_neighbors(l.region_id) n) then 2 end;
    if d is null then continue; end if;
    v := greatest(v, case p_key
      when 'erosion_pct' then case d when 2 then 10 else 30 end
      when 'encounter_pct' then case d when 2 then 5 else 10 end
      when 'gather_qty_pct' then case d when 0 then -25 else 0 end
      else case d when 0 then 10 else 0 end end);
    if p_key = 'gather_qty_pct' and d = 0 then v := -25; end if;
  end loop;
  return v;
end $$;
do $$ declare d text := pg_get_functiondef('public.world_status_effect_total(text)'::regprocedure);
  a text := '+ public.world_level_gap_effect(p_effect_key)'; b text := '+ public.world_level_gap_effect(p_effect_key) + public.world_raid_lock_effect(p_effect_key)';
begin
  if position('world_raid_lock_effect' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '상태 효과 합계 고칠 자리(6.1.0)'; end if;
  execute replace(d, a, b);
end $$;

-- 참가자 전투 능력치(행동할 때마다 다시 적어 둔다 — 보스가 그 사람을 칠 때 쓴다)
create or replace function public.world_raid_stats(p_owner uuid)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare s jsonb := public.world_combat_stats(p_owner);
begin
  return jsonb_build_object('attack', coalesce((s ->> 'attack')::numeric, 10), 'red', coalesce((s ->> 'reduction_pct')::numeric, 0),
    'inc', coalesce((s ->> 'incoming_pct')::numeric, 0), 'eva', coalesce((s ->> 'evasion_pct')::numeric, 0), 'crit', coalesce((s ->> 'crit_pct')::numeric, 5),
    'pres', coalesce((s ->> 'presence')::numeric, 30), 'style', coalesce(s ->> 'style', 'melee'));
end $$;

-- 보스가 한 사람을 친다(대신 막기·피하기·결계·방어·보호막을 거쳐 실제 체력을 깎는다). 쓰러지면 체력 1로 1분 물러난다
create or replace function public.world_raid_hit(p_raid uuid, p_target uuid, p_raw numeric, p_kind text)
returns int language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare m public.world_raid_members%rowtype; pm public.world_raid_members%rowtype; f jsonb; d numeric; hp int; who uuid := p_target; nm text; absorb int; pct numeric;
begin
  select * into m from public.world_raid_members where raid_id = p_raid and owner_id = p_target for update;
  if not found then return 0; end if;
  f := m.fx;
  -- 퇴마관의 대신 막기: 그 동료를 노린 공격을 지킨 사람이 절반만 받는다
  if f ? 'cover' and (f -> 'cover' ->> 'until')::timestamptz > now() then
    select * into pm from public.world_raid_members where raid_id = p_raid and owner_id = (f -> 'cover' ->> 'by')::uuid for update;
    if found and (pm.out_until is null or pm.out_until <= now()) then
      perform public.world_raid_say(p_raid, 'coop', pm.name || ' — ' || m.name || '을(를) 노린 공격을 대신 막았습니다.');
      m := pm; f := pm.fx; who := pm.owner_id; p_raw := p_raw * 0.5;
    end if;
  end if;
  nm := m.name;
  if p_kind = 'single' and random() * 100 < coalesce((m.stats ->> 'eva')::numeric, 0) + coalesce((f -> 'evade' ->> 'pct')::numeric, 0) then
    if f ? 'evade' then f := case when (f -> 'evade' ->> 'n')::int <= 1 then f - 'evade' else jsonb_set(f, '{evade,n}', to_jsonb((f -> 'evade' ->> 'n')::int - 1)) end; end if;
    update public.world_raid_members set fx = f where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say(p_raid, 'miss', nm || ' — 공격을 피했습니다.');
    return 0;
  end if;
  d := p_raw * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((m.stats ->> 'inc')::numeric, 0) / 100.0);
  if f ? 'ward' then
    d := d * (1 - (f -> 'ward' ->> 'pct')::numeric / 100.0);
    f := case when (f -> 'ward' ->> 'n')::int <= 1 then f - 'ward' else jsonb_set(f, '{ward,n}', to_jsonb((f -> 'ward' ->> 'n')::int - 1)) end;
  end if;
  if f ? 'taunt' then
    d := d * (1 - (f -> 'taunt' ->> 'pct')::numeric / 100.0);
    f := case when (f -> 'taunt' ->> 'n')::int <= 1 then f - 'taunt' else jsonb_set(f, '{taunt,n}', to_jsonb((f -> 'taunt' ->> 'n')::int - 1)) end;
  end if;
  if p_kind in ('slam', 'burst') and f ? 'gward' then
    d := d * (1 - (f -> 'gward' ->> 'pct')::numeric / 100.0); f := f - 'gward';
  end if;
  if coalesce((f ->> 'guard')::int, 0) > 0 then
    d := d * case when p_kind = 'burst' then 0.25 else 0.4 end; f := f - 'guard';
  end if;
  absorb := least(coalesce((f ->> 'shield')::int, 0), round(d)::int);
  if absorb > 0 then d := d - absorb; f := case when coalesce((f ->> 'shield')::int, 0) - absorb <= 0 then f - 'shield' else jsonb_set(f, '{shield}', to_jsonb((f ->> 'shield')::int - absorb)) end; end if;
  d := greatest(0, round(d));
  update public.world_characters set health = greatest(1, health - d::int), updated_at = now() where owner_id = who returning health into hp;
  if hp <= 1 and d > 0 then
    update public.world_raid_members set fx = f - 'bound', out_until = now() + interval '60 seconds', falls = falls + 1 where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say(p_raid, 'fall', nm || ' — ' || d::int || '의 피해를 입고 물러났습니다(1분 뒤 돌아옴).');
  else
    update public.world_raid_members set fx = f where raid_id = p_raid and owner_id = who;
    perform public.world_raid_say(p_raid, 'hit', nm || ' — ' || d::int || '의 피해' || case when absorb > 0 then '(보호막이 ' || absorb || ' 받아 냄)' else '' end || '.');
  end if;
  return d::int;
end $$;

-- 보스 체력: 서버 보스는 참가자 공격력 합 ×110(적어도 2,500), 결전은 평균 공격력 ×100(적어도 4,716)에 인원 배율
create or replace function public.world_raid_begin_fight(p_raid uuid)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare rd public.world_raids%rowtype; n int; s numeric; a numeric; hpv int;
begin
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if rd.status <> 'signup' then return; end if;
  select count(*), coalesce(sum((stats ->> 'attack')::numeric), 0), coalesce(avg((stats ->> 'attack')::numeric), 0) into n, s, a
    from public.world_raid_members where raid_id = p_raid;
  if n = 0 and rd.kind = 'final' then
    perform public.world_raid_settle(p_raid, false); return;
  end if;
  hpv := case when rd.kind = 'world' then greatest(2500, round(s * 110))
              else round(greatest(4716, a * 100) * case least(n, 4) when 1 then 1 when 2 then 1.7 when 3 then 2.3 else 2.8 end) end;
  update public.world_raids set status = 'fight', hp = hpv, max_hp = hpv, turn = 0, phase = 1,
    ends_at = now() + case when kind = 'world' then interval '2 hours' else interval '20 minutes' end, updated_at = now() where raid_id = p_raid;
  perform public.world_raid_say(p_raid, 'phase', rd.boss_name || '이(가) 모습을 드러냈습니다. 참가자 ' || n || '명 · 체력 ' || hpv || '.');
  if rd.kind = 'world' then
    perform public.world_raid_chat('「' || rd.boss_name || '」 토벌이 시작되었습니다(참가 ' || n || '명). ' || (select region_name from public.world_map_regions where region_id = rd.region_id) || '에 가면 지금도 합류할 수 있고, 현장의 봉연 띠에서 진행을 볼 수 있습니다.');
  end if;
end $$;

-- 결전 시작(10장 마지막 퀘스트): 구중 봉연에서 시작하면 90초 동안 같은 곳의 파티원이 들어올 수 있다
create or replace function public.world_raid_final_start()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rid uuid; pid uuid; r record; here text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 결전을 시작할 수 없습니다.'; end if;
  if not exists (select 1 from public.world_quest_progress g where g.owner_id = uid and g.quest_id = 'fq_sealed_lord' and g.step >= 1) then
    raise exception '「구중 봉주」 퀘스트를 받은 뒤 시작할 수 있습니다.'; end if;
  select region_id into here from public.world_map_regions where region_name = c.location;
  if here is distinct from 'sealed_abyss' then raise exception '구중 봉연에서 시작할 수 있습니다.'; end if;
  if exists (select 1 from public.world_expeditions where owner_id = uid and status = 'active') then raise exception '원정 중에는 할 수 없습니다.'; end if;
  if exists (select 1 from public.world_raid_members m join public.world_raids x on x.raid_id = m.raid_id where m.owner_id = uid and x.status in ('signup', 'fight')) then
    raise exception '이미 진행 중인 토벌이 있습니다.'; end if;
  insert into public.world_raids(kind, boss_name, region_id, status, leader_id, signup_until, spawn_at)
  values ('final', '구중 봉주', 'sealed_abyss', 'signup', uid, now() + interval '90 seconds', now()) returning raid_id into rid;
  insert into public.world_raid_members(raid_id, owner_id, name, level, job_key, stats)
  values (rid, uid, c.character_name, c.level, c.job_key, public.world_raid_stats(uid));
  perform public.world_raid_say(rid, 'info', c.character_name || ' — 아홉 겹 사슬 앞에 섰습니다. 함께할 동료를 90초 기다립니다.');
  select party_id into pid from public.world_party_members where owner_id = uid;
  if pid is not null then
    for r in select pc.owner_id from public.world_party_members pm join public.world_characters pc on pc.owner_id = pm.owner_id
              where pm.party_id = pid and pm.owner_id <> uid and pc.location = c.location loop
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (r.owner_id, 'raid_invite', '결전 합류', c.character_name || ' 조사원이 구중 봉주와의 결전을 시작합니다. 90초 안에 합류하세요.', jsonb_build_object('raid_id', rid));
    end loop;
  end if;
  return jsonb_build_object('raid_id', rid);
end $$;

-- 참가(서버 보스: 출현 뒤 모이는 30분과 토벌 2시간 내내 그 지역에서 — 도중 합류는 남은 시간만큼 체력이 늘어난다 / 결전: 결전 시작 90초 안·같은 곳의 파티원)
create or replace function public.world_raid_join(p_raid uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rd public.world_raids%rowtype; here text; hp_add int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if not found then raise exception '알 수 없는 토벌입니다.'; end if;
  if not ((rd.status = 'signup' and rd.signup_until > now()) or (rd.kind = 'world' and rd.status = 'fight' and rd.ends_at > now())) then
    raise exception '%', case when rd.kind = 'final' then '합류 시간이 지났습니다. 진행은 관전으로 볼 수 있습니다.' else '토벌이 끝났습니다.' end; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 신청할 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions where owner_id = uid and status = 'active') then raise exception '원정 중에는 신청할 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities where owner_id = uid and status = 'active') then raise exception '자율 활동 중에는 신청할 수 없습니다.'; end if;
  select region_id into here from public.world_map_regions where region_name = c.location;
  if here is distinct from rd.region_id then
    raise exception '%에 있어야 신청할 수 있습니다.', (select region_name from public.world_map_regions where region_id = rd.region_id); end if;
  if rd.kind = 'final' and not exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id
                                        where a.owner_id = uid and b.owner_id = rd.leader_id) then
    raise exception '결전은 시작한 조사원의 파티원만 합류할 수 있습니다.'; end if;
  if rd.kind = 'final' and (select count(*) from public.world_raid_members where raid_id = p_raid) >= 4 then raise exception '결전은 4명까지입니다.'; end if;
  if exists (select 1 from public.world_raid_members where raid_id = p_raid and owner_id = uid) then raise exception '이미 신청했습니다.'; end if;
  insert into public.world_raid_members(raid_id, owner_id, name, level, job_key, stats)
  values (p_raid, uid, c.character_name, c.level, c.job_key, public.world_raid_stats(uid));
  if rd.status = 'fight' then
    -- 도중 합류: 남은 시간 비율만큼(최소 4분의 1) 요괴 체력을 늘린다. 늦게 온 만큼 기여도는 덜 쌓인다
    hp_add := round(coalesce((public.world_raid_stats(uid) ->> 'attack')::numeric, 0) * 110 * greatest(0.25, least(1, extract(epoch from rd.ends_at - now()) / 7200)));
    -- 아무도 없이 시작한 토벌(기본 체력)이면 첫 합류는 그 기본 몫을 넘는 만큼만 더한다
    if not exists (select 1 from public.world_raid_members where raid_id = p_raid and owner_id <> uid) then hp_add := greatest(0, hp_add - rd.max_hp); end if;
    update public.world_raids set hp = hp + hp_add, max_hp = max_hp + hp_add, updated_at = now() where raid_id = p_raid;
    perform public.world_raid_say(p_raid, 'join', c.character_name || '(Lv' || c.level || ') — 토벌에 뛰어들었습니다. 그림자의 체력 +' || hp_add || '.');
  else
    perform public.world_raid_say(p_raid, 'join', c.character_name || '(Lv' || c.level || ') — 참가했습니다.');
    update public.world_raids set updated_at = now() where raid_id = p_raid;
  end if;
  return public.world_raid_snapshot(p_raid);
end $$;

-- 결전을 바로 시작(시작한 조사원만)
create or replace function public.world_raid_begin(p_raid uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); rd public.world_raids%rowtype;
begin
  select * into rd from public.world_raids where raid_id = p_raid;
  if not found or rd.kind <> 'final' or rd.leader_id is distinct from uid then raise exception '결전을 시작한 조사원만 바로 시작할 수 있습니다.'; end if;
  perform public.world_raid_begin_fight(p_raid);
  return public.world_raid_snapshot(p_raid);
end $$;

-- 한 번의 행동: 공격·방어·물품·협동 기술. 행동 뒤 보스가 한 번 움직인다
create or replace function public.world_raid_action(p_raid uuid, p_action text, p_skill text default null, p_target uuid default null, p_item text default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rd public.world_raids%rowtype; mb public.world_raid_members%rowtype;
  tm public.world_raid_members%rowtype; sk public.world_coop_skills%rowtype; st jsonb; f jsonb; rfx jsonb; act text := lower(coalesce(p_action, ''));
  here text; sp int; inv jsonb; ammo text; mul numeric := 1; dmg int := 0; crit boolean := false; credit numeric := 0; h0 int; h1 int; amt int;
  n_act int; pick uuid; lv int; raw numeric; ph_mul numeric; k text; v jsonb; tgt uuid; nm text; newp int; tot numeric; acc numeric; rnd numeric; m record;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if act not in ('attack', 'guard', 'item', 'coop') then raise exception '알 수 없는 행동입니다.'; end if;
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if not found then raise exception '알 수 없는 토벌입니다.'; end if;
  if rd.status <> 'fight' then raise exception '지금은 싸울 수 없습니다.'; end if;
  if rd.ends_at <= now() then perform public.world_raid_settle(p_raid, false); return public.world_raid_snapshot(p_raid); end if;
  select * into mb from public.world_raid_members where raid_id = p_raid and owner_id = uid for update;
  if not found then raise exception '참가 신청한 조사원만 싸울 수 있습니다. 진행은 관전으로 볼 수 있습니다.'; end if;
  if mb.last_action_at is not null and mb.last_action_at > now() - interval '1 second' then raise exception '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.'; end if;
  if mb.out_until is not null and mb.out_until > now() then
    raise exception '물러나 숨을 고르는 중입니다(%초 뒤 돌아옴).', ceil(extract(epoch from mb.out_until - now())); end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태입니다.'; end if;
  select region_id into here from public.world_map_regions where region_name = c.location;
  if here is distinct from rd.region_id then raise exception '토벌이 벌어진 곳에 있어야 합니다.'; end if;
  if exists (select 1 from public.world_expeditions where owner_id = uid and status = 'active') then raise exception '원정 중에는 싸울 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false) and a.mlevel is not null) then
    raise exception '진행 중인 요괴 전투를 먼저 끝내세요.'; end if;

  st := public.world_raid_stats(uid);
  f := mb.fx; rfx := rd.fx; sp := c.spiritual_power; inv := coalesce(c.inventory, '{}'::jsonb);
  if mb.out_until is not null then mb.out_until := null; end if;

  if act = 'attack' then
    -- 무기 소모: 근접 기력 2·술법 영력 3·원거리 한 발, 없으면 피해 절반
    if st ->> 'style' = 'magic' then if sp >= 3 then sp := sp - 3; else mul := mul * 0.5; end if;
    elsif st ->> 'style' = 'ranged' then
      ammo := public.world_ammo_of(uid);
      if ammo is not null and coalesce((inv ->> ammo)::int, 0) >= 1 then inv := public.world_inv_add(inv, ammo, -1); if (inv ->> ammo)::int <= 0 then inv := inv - ammo; end if;
      else mul := mul * 0.5; end if;
    else if sp >= 2 then sp := sp - 2; else mul := mul * 0.5; end if; end if;
    if f ? 'might' then mul := mul * (1 + (f -> 'might' ->> 'pct')::numeric / 100.0);
      f := case when (f -> 'might' ->> 'n')::int <= 1 then f - 'might' else jsonb_set(f, '{might,n}', to_jsonb((f -> 'might' ->> 'n')::int - 1)) end; end if;
    if f ? 'bound' then mul := mul * 0.5; f := f - 'bound'; end if;
    if rfx ? 'expose' then mul := mul * (1 + (rfx -> 'expose' ->> 'pct')::numeric / 100.0);
      rfx := case when (rfx -> 'expose' ->> 'n')::int <= 1 then rfx - 'expose' else jsonb_set(rfx, '{expose,n}', to_jsonb((rfx -> 'expose' ->> 'n')::int - 1)) end; end if;
    crit := random() * 100 < (st ->> 'crit')::numeric + coalesce((f -> 'crit' ->> 'pct')::numeric, 0);
    if f ? 'crit' then f := case when (f -> 'crit' ->> 'n')::int <= 1 then f - 'crit' else jsonb_set(f, '{crit,n}', to_jsonb((f -> 'crit' ->> 'n')::int - 1)) end; end if;
    if f ? 'crit_next' then crit := true; f := f - 'crit_next'; end if;
    if crit then mul := mul * 1.5; end if;
    dmg := greatest(1, round((st ->> 'attack')::numeric * (0.85 + random() * 0.3) * mul))::int;
    rd.hp := greatest(0, rd.hp - dmg); mb.dmg := mb.dmg + dmg; credit := dmg;
    if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,got}', to_jsonb((rfx -> 'charge' ->> 'got')::int + dmg)); end if;
    perform public.world_raid_say(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.');
  elsif act = 'guard' then
    f := f || jsonb_build_object('guard', 1); mb.guarded := mb.guarded + 1;
    perform public.world_raid_say(p_raid, 'guard', mb.name || ' — 방어 태세를 갖췄습니다.');
  elsif act = 'item' then
    -- 물품은 평소 쓰는 길(world_use_item)을 그대로 거친다
    update public.world_characters set spiritual_power = sp where owner_id = uid;
    h0 := c.health;
    perform public.world_use_item(p_item);
    select * into c from public.world_characters where owner_id = uid;
    sp := c.spiritual_power; inv := coalesce(c.inventory, '{}'::jsonb); h1 := c.health;
    mb.heal := mb.heal + greatest(0, h1 - h0); credit := greatest(0, h1 - h0) * 2;
    perform public.world_raid_say(p_raid, 'item', mb.name || ' — ' || coalesce((select item_name from public.world_item_catalog where item_id = p_item), '물품') || '을(를) 썼습니다' || case when h1 > h0 then '(체력 +' || (h1 - h0) || ')' else '' end || '.');
  else
    select * into sk from public.world_coop_skills where skill_id = p_skill;
    if not found or sk.job_key <> c.job_key then raise exception '쓸 수 없는 협동 기술입니다.'; end if;
    if coalesce(c.combat_rank, 1) < sk.unlock_rank then raise exception '전투 숙련 %단계에 열리는 기술입니다.', sk.unlock_rank; end if;
    if mb.cd ? sk.skill_id and (mb.cd ->> sk.skill_id)::timestamptz > now() then
      raise exception '%은(는) %초 뒤에 다시 쓸 수 있습니다.', sk.skill_name, ceil(extract(epoch from (mb.cd ->> sk.skill_id)::timestamptz - now())); end if;
    if sp < sk.cost then raise exception '영력이 모자랍니다(필요 %).', sk.cost; end if;
    tgt := coalesce(p_target, uid);
    if sk.target = 'ally' then
      select * into tm from public.world_raid_members where raid_id = p_raid and owner_id = tgt for update;
      if not found then raise exception '이 토벌에 참가한 동료에게만 쓸 수 있습니다.'; end if;
      if sk.effect ->> 'type' = 'revive' then
        if tm.out_until is null or tm.out_until <= now() then raise exception '물러난 동료에게만 쓸 수 있습니다.'; end if;
      elsif tm.out_until is not null and tm.out_until > now() then raise exception '물러난 동료에게는 쓸 수 없습니다.'; end if;
    end if;
    sp := sp - sk.cost;
    mb.cd := mb.cd || jsonb_build_object(sk.skill_id, now() + make_interval(secs => sk.cooldown_s));
    mb.coop := mb.coop + 1; credit := (st ->> 'attack')::numeric * 1.2;
    k := sk.effect ->> 'type'; v := sk.effect;
    -- 자신에게 거는 효과는 아래에서 mb.fx(f)에 바로 쓴다
    if sk.target = 'ally' and tgt = uid then
      if k in ('ward', 'might', 'evade') then f := f || jsonb_build_object(k, jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'));
      elsif k = 'gward' then f := f || jsonb_build_object('gward', jsonb_build_object('pct', v -> 'pct'));
      elsif k = 'crit_next' then f := f || '{"crit_next":1}'::jsonb;
      elsif k = 'shield' then f := f || jsonb_build_object('shield', coalesce((f ->> 'shield')::int, 0) + (v ->> 'amt')::int);
      elsif k = 'cleanse_heal' then f := f - 'bound';
      elsif k = 'cover' then raise exception '자기 자신은 대신 막을 수 없습니다.';
      end if;
    elsif sk.target = 'ally' then
      update public.world_raid_members set fx = case
          when k in ('ward', 'might', 'evade') then fx || jsonb_build_object(k, jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'))
          when k = 'gward' then fx || jsonb_build_object('gward', jsonb_build_object('pct', v -> 'pct'))
          when k = 'crit_next' then fx || '{"crit_next":1}'::jsonb
          when k = 'shield' then fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (v ->> 'amt')::int)
          when k = 'cleanse_heal' then fx - 'bound'
          when k = 'cover' then fx || jsonb_build_object('cover', jsonb_build_object('by', uid, 'until', now() + make_interval(secs => (v ->> 'secs')::int)))
          else fx end,
        out_until = case when k = 'revive' then null else out_until end
       where raid_id = p_raid and owner_id = tgt;
    end if;
    if k in ('heal', 'cleanse_heal', 'revive', 'sp', 'gward') then
      amt := case k when 'revive' then (v ->> 'hp')::int when 'sp' then 0 when 'gward' then 0
             else round((v ->> 'amt')::int * (1 + coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) / 100.0)) end;
      if k = 'revive' then
        update public.world_characters set health = greatest(health, amt), updated_at = now() where owner_id = tgt;
      elsif k = 'sp' then
        update public.world_characters set spiritual_power = least(100, spiritual_power + (v ->> 'amt')::int), updated_at = now() where owner_id = tgt and owner_id <> uid;
        if tgt = uid then sp := least(100, sp + (v ->> 'amt')::int); end if;
      elsif k = 'gward' then
        update public.world_characters set mental = least(100, mental + coalesce((v ->> 'mind')::int, 0)), updated_at = now() where owner_id = tgt;
      else
        if tgt = uid then
          select health into h0 from public.world_characters where owner_id = uid;
        end if;
        update public.world_characters set health = least(100, health + amt), updated_at = now() where owner_id = tgt and health > 0;
      end if;
      if amt > 0 then mb.heal := mb.heal + amt; credit := credit + amt * 2; end if;
    end if;
    if k = 'heal_all' then
      amt := round((v ->> 'amt')::int * (1 + coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) / 100.0));
      update public.world_characters ch set health = least(100, ch.health + amt), updated_at = now()
        from public.world_raid_members x where x.raid_id = p_raid and x.owner_id = ch.owner_id and (x.out_until is null or x.out_until <= now()) and ch.health > 0;
      get diagnostics n_act = row_count;
      mb.heal := mb.heal + amt * n_act; credit := credit + amt * n_act * 2;
    elsif k in ('ward_all', 'might_all', 'crit_all', 'rally', 'resonance') then
      update public.world_raid_members x set fx = case k
          when 'ward_all' then x.fx || jsonb_build_object('ward', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'))
          when 'might_all' then x.fx || jsonb_build_object('might', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'))
          when 'rally' then x.fx || jsonb_build_object('might', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'))
          when 'crit_all' then x.fx || jsonb_build_object('crit', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'))
          else x.fx || jsonb_build_object('might', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'), 'ward', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n')) end
       where x.raid_id = p_raid and x.owner_id <> uid and (x.out_until is null or x.out_until <= now());
      f := case k
          when 'ward_all' then f || jsonb_build_object('ward', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'))
          when 'crit_all' then f || jsonb_build_object('crit', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'))
          when 'resonance' then f || jsonb_build_object('might', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'), 'ward', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'))
          else f || jsonb_build_object('might', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n')) end;
    elsif k = 'taunt' then
      f := f || jsonb_build_object('taunt', jsonb_build_object('pres', v -> 'pres', 'pct', v -> 'pct', 'n', v -> 'n'));
    elsif k = 'expose' then
      rfx := rfx || jsonb_build_object('expose', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n'), 'stagger', coalesce((rfx ->> 'stagger')::int, 0) + coalesce((v ->> 'stagger')::int, 0));
    elsif k = 'delay' then
      rfx := rfx || jsonb_build_object('stagger', coalesce((rfx ->> 'stagger')::int, 0) + (v ->> 'n')::int);
      if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int + 3)); end if;
    elsif k = 'smoke' then
      rfx := rfx || jsonb_build_object('smoke', jsonb_build_object('miss', v -> 'miss', 'n', v -> 'n'));
    elsif k = 'break' then
      rfx := rfx || jsonb_build_object('break', v -> 'pct');
    end if;
    select name into nm from public.world_raid_members where raid_id = p_raid and owner_id = tgt;
    perform public.world_raid_say(p_raid, 'coop', mb.name || ' — [' || sk.skill_name || '] ' ||
      case when sk.target = 'ally' and tgt <> uid then nm || '에게 · ' else '' end || sk.exp_text || '.');
  end if;

  -- 내 행동을 먼저 적고(체력·영력·가방), 보스의 반격은 그 뒤에 실제 캐릭터에 쓴다
  update public.world_characters set spiritual_power = sp, inventory = inv, updated_at = now() where owner_id = uid;
  mb.acts := mb.acts + 1; mb.last_action_at := now();
  mb.contrib := mb.contrib + credit * case when rd.kind = 'world' then least(1, mb.level / 30.0) else 1 end;
  update public.world_raid_members set fx = f, cd = mb.cd, dmg = mb.dmg, heal = mb.heal, coop = mb.coop, guarded = mb.guarded, acts = mb.acts,
    contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = st where raid_id = p_raid and owner_id = uid;

  rd.turn := rd.turn + 1;
  if rd.hp <= 0 then
    update public.world_raids set hp = 0, turn = rd.turn, fx = rfx, updated_at = now() where raid_id = p_raid;
    perform public.world_raid_say(p_raid, 'win', mb.name || '의 일격에 ' || rd.boss_name || '이(가) 무너졌습니다.');
    perform public.world_raid_settle(p_raid, true);
    return public.world_raid_snapshot(p_raid);
  end if;
  newp := case when rd.hp * 100 <= rd.max_hp * 40 then 3 when rd.hp * 100 <= rd.max_hp * 70 then 2 else 1 end;
  if newp > rd.phase then
    rd.phase := newp;
    perform public.world_raid_say(p_raid, 'phase', case newp when 2 then rd.boss_name || '의 사슬이 풀리며 움직임이 사나워집니다(2단계).'
                                                    else rd.boss_name || '이(가) 봉연의 기운을 끌어모으기 시작합니다(3단계).' end);
  end if;
  ph_mul := case rd.phase when 1 then 1 when 2 then 1.15 else 1.3 end * case when rd.kind = 'final' then 1.1 else 1 end;
  select count(*) into n_act from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id
   where x.raid_id = p_raid and (x.out_until is null or x.out_until <= now()) and x.last_action_at > now() - interval '120 seconds' and ch.health > 1;

  if coalesce((rfx ->> 'stagger')::int, 0) > 0 then
    rfx := case when (rfx ->> 'stagger')::int <= 1 then rfx - 'stagger' else jsonb_set(rfx, '{stagger}', to_jsonb((rfx ->> 'stagger')::int - 1)) end;
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 휘청여 반격하지 못합니다.');
  elsif rfx ? 'charge' then
    rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int - 1));
    if (rfx -> 'charge' ->> 'got')::int >= (rfx -> 'charge' ->> 'need')::int then
      rfx := rfx - 'charge';
      perform public.world_raid_say(p_raid, 'boss', '몰아친 공격에 ' || rd.boss_name || '의 기운 모으기가 끊겼습니다.');
    elsif (rfx -> 'charge' ->> 'left')::int <= 0 then
      rfx := rfx - 'charge';
      perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 모은 봉연의 기운을 터뜨립니다!');
      for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and (x.out_until is null or x.out_until <= now()) and x.last_action_at > now() - interval '120 seconds' loop
        raw := (4 + 0.7 * (m.level + 3)) * ph_mul * 2.2 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
        perform public.world_raid_hit(p_raid, m.owner_id, raw, 'burst');
      end loop;
      rfx := rfx - 'break';
    end if;
  elsif rd.phase = 3 and rd.turn % 11 = 0 then
    rfx := rfx || jsonb_build_object('charge', jsonb_build_object('left', 5 + greatest(1, n_act), 'need', round(rd.max_hp * 0.04), 'got', 0));
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 기운을 모읍니다. ' || round(rd.max_hp * 0.04) || ' 넘게 몰아쳐 끊거나, 방어하세요!');
  elsif rd.turn % 7 = 0 then
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 크게 휘둘러 모두를 덮칩니다.');
    for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and (x.out_until is null or x.out_until <= now()) and x.last_action_at > now() - interval '120 seconds' loop
      raw := (4 + 0.7 * (m.level + 3)) * ph_mul * 0.8 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
      perform public.world_raid_hit(p_raid, m.owner_id, raw, 'slam');
    end loop;
    rfx := rfx - 'break';
  elsif rd.phase >= 2 and rd.turn % 5 = 0 then
    select x.owner_id, x.name into pick, nm from public.world_raid_members x where x.raid_id = p_raid and (x.out_until is null or x.out_until <= now()) order by random() limit 1;
    if pick is not null then
      update public.world_raid_members set fx = fx || '{"bound":1}'::jsonb where raid_id = p_raid and owner_id = pick;
      perform public.world_raid_say(p_raid, 'boss', '봉연의 사슬이 ' || nm || '을(를) 휘감습니다(다음 공격 절반).');
    end if;
  elsif random() < least(0.4, 0.8 / greatest(1, n_act)) then
    -- 표적: 이목^1.3에 비례(호법 신장은 이목을 더한다)
    select coalesce(sum(power(greatest(5, (x.stats ->> 'pres')::numeric + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)), 1.3)), 0) into tot
      from public.world_raid_members x where x.raid_id = p_raid and (x.out_until is null or x.out_until <= now()) and x.last_action_at > now() - interval '120 seconds';
    rnd := random() * tot; acc := 0; pick := null;
    for m in select x.owner_id, x.level, power(greatest(5, (x.stats ->> 'pres')::numeric + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)), 1.3) w
               from public.world_raid_members x where x.raid_id = p_raid and (x.out_until is null or x.out_until <= now()) and x.last_action_at > now() - interval '120 seconds' loop
      acc := acc + m.w; pick := m.owner_id; lv := m.level;
      exit when acc >= rnd;
    end loop;
    if pick is not null then
      if rfx ? 'smoke' and random() * 100 < (rfx -> 'smoke' ->> 'miss')::numeric then
        perform public.world_raid_say(p_raid, 'miss', '연막 속에서 ' || rd.boss_name || '의 공격이 빗나갔습니다.');
      else
        perform public.world_raid_hit(p_raid, pick, (4 + 0.7 * (lv + 3)) * ph_mul, 'single');
      end if;
      if rfx ? 'smoke' then rfx := case when (rfx -> 'smoke' ->> 'n')::int <= 1 then rfx - 'smoke' else jsonb_set(rfx, '{smoke,n}', to_jsonb((rfx -> 'smoke' ->> 'n')::int - 1)) end; end if;
    end if;
  end if;

  -- 결전에서 모두 물러나면 보스가 기운을 되찾는다
  if rd.kind = 'final' and not exists (select 1 from public.world_raid_members x where x.raid_id = p_raid and (x.out_until is null or x.out_until <= now())) then
    rd.hp := least(rd.max_hp, rd.hp + round(rd.max_hp * 0.08));
    perform public.world_raid_say(p_raid, 'boss', '모두 물러난 사이 ' || rd.boss_name || '이(가) 기운을 되찾습니다(체력 +8%).');
  end if;
  rd.intent := case when rfx ? 'charge' then '기운을 모으는 중 — 남은 ' || (rfx -> 'charge' ->> 'left') || '번 안에 ' || greatest(0, (rfx -> 'charge' ->> 'need')::int - (rfx -> 'charge' ->> 'got')::int) || ' 더 몰아치면 끊긴다'
                    when (rd.turn + 1) % 7 = 0 then '크게 휘두를 낌새가 보인다 — 방어하라'
                    when rd.phase >= 2 and (rd.turn + 1) % 5 = 0 then '사슬이 꿈틀거린다'
                    else null end;
  update public.world_raids set hp = rd.hp, turn = rd.turn, phase = rd.phase, fx = rfx, intent = rd.intent, updated_at = now() where raid_id = p_raid;
  return public.world_raid_snapshot(p_raid);
end $$;

-- 봉연 장비·재료
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, rarity, tradeable, reference_price, stack_size, minimum_level, required_stats, equipment_traits)
values
  ('seal_shard', '봉연 파편', 'material', 4, '봉연의 그림자를 물리친 자리에 남은 검은 파편. 아직 미지근하다.', true, 'rare', false, 120, 10, 1, '{}'::jsonb, '{}'::jsonb),
  ('raid_norigae', '봉연 매듭', 'norigae', 5, '봉연의 사슬 한 마디를 매듭으로 묶은 노리개. 쥐면 숨이 고르게 된다.', false, 'legendary', false, 1400, 1, 25,
    '{"willpower": 23}'::jsonb, '{"trait": "노리개", "incoming_damage_pct": -4, "erosion_pct": -6, "mental_loss_pct": -5}'::jsonb),
  ('raid_amulet', '봉연 호패', 'amulet', 5, '그림자를 걷은 이에게 내린 검은 호패. 봉인의 기운이 서려 있다.', false, 'legendary', false, 1400, 1, 25,
    '{"vitality": 23}'::jsonb, '{"trait": "호신부", "defense": 8, "incoming_damage_pct": -3, "presence": 20}'::jsonb),
  ('raid_mask', '그림자 탈', 'mask', 5, '봉연의 그림자를 본뜬 탈. 쓰면 요괴가 눈을 피한다.', false, 'legendary', false, 1400, 1, 25,
    '{"perception": 23}'::jsonb, '{"trait": "탈", "crit_pct": 4, "combat_damage_pct": 4, "encounter_pct": -4}'::jsonb)
on conflict (item_id) do nothing;

-- 결과 정산: 보상(기여도 1% 이상)·칭호·퀘스트·잠김·다음 회차
create or replace function public.world_raid_settle(p_raid uuid, p_won boolean)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare rd public.world_raids%rowtype; m record; tot numeric; share numeric; rw_gil int; xp int; items jsonb; inv jsonb; lim int; k text; v int; room int;
  got text; lost text; cleared boolean; top uuid; revenge boolean; nxt timestamptz; reg text;
begin
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if rd.status in ('won', 'failed') then return; end if;
  update public.world_raids set status = case when p_won then 'won' else 'failed' end, ended_at = now(), intent = null, updated_at = now() where raid_id = p_raid;
  select coalesce(sum(contrib), 0) into tot from public.world_raid_members where raid_id = p_raid;
  select owner_id into top from public.world_raid_members where raid_id = p_raid order by contrib desc limit 1;
  revenge := rd.kind = 'world' and p_won and exists (select 1 from public.world_raid_locks where until > now());
  for m in select x.*, ch.level clv from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id where x.raid_id = p_raid loop
    share := case when tot > 0 then m.contrib / tot else 0 end;
    rw_gil := 0; xp := 0; items := '{}'::jsonb;
    if rd.kind = 'world' then
      if share >= 0.01 and m.acts > 0 then
        if p_won then
          rw_gil := least(1800, round(300 + 1700 * share)); xp := round(public.world_xp_need(m.clv) * least(0.35, 0.10 + 0.6 * share));
          items := jsonb_build_object('seal_shard', 3 + floor(12 * share)::int);
          if random() < 0.45 then items := items || jsonb_build_object('spirit_core', 1 + (random() < 0.4)::int); end if;
          if random() < 0.25 then items := items || jsonb_build_object('heavenly_dew', 1); end if;
          if random() < 0.01 then items := items || jsonb_build_object('gwiryeong_cho', 1); end if;
          if random() < 0.04 + 0.08 * share then items := items || jsonb_build_object((array['raid_norigae', 'raid_amulet', 'raid_mask'])[1 + floor(random() * 3)::int], 1); end if;
        else
          rw_gil := round(80 + 300 * share); xp := round(public.world_xp_need(m.clv) * 0.03); items := '{"seal_shard":1}'::jsonb;
        end if;
      end if;
    else
      cleared := exists (select 1 from public.world_raid_members y join public.world_raids z on z.raid_id = y.raid_id
                          where y.owner_id = m.owner_id and z.kind = 'final' and z.status = 'won' and z.raid_id <> p_raid);
      if p_won and m.acts > 0 then
        if cleared then rw_gil := 100; items := '{"seal_shard":2}'::jsonb;
        else rw_gil := 400; xp := round(public.world_xp_need(m.clv) * 0.5); items := '{"spirit_core":3,"heavenly_dew":2,"seal_shard":5}'::jsonb; end if;
      end if;
    end if;
    got := ''; lost := '';
    if rw_gil > 0 or items <> '{}'::jsonb then
      select inventory into inv from public.world_characters where owner_id = m.owner_id for update;
      inv := coalesce(inv, '{}'::jsonb); lim := public.world_bag_limit(m.owner_id);
      for k, v in select key, value::int from jsonb_each_text(items) loop
        room := least(v, public.world_bag_room(inv, k, lim));
        if room > 0 then inv := public.world_inv_add(inv, k, room); got := got || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || room || ' · '; end if;
        if room < v then lost := lost || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || (v - room) || ' · '; end if;
      end loop;
      update public.world_characters set inventory = inv, gil = gil + rw_gil, updated_at = now() where owner_id = m.owner_id;
    end if;
    if xp > 0 then perform public.world_grant_xp(m.owner_id, xp); end if;
    update public.world_raid_members set reward = jsonb_build_object('share', round(share * 100, 1), 'gil', rw_gil, 'xp', xp, 'items', items,
      'top', m.owner_id = top, 'revenge', revenge, 'lost', nullif(lost, '')) where raid_id = p_raid and owner_id = m.owner_id;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (m.owner_id, 'raid_result', case when p_won then rd.boss_name || ' 토벌 성공' else rd.boss_name || ' 토벌 실패' end,
      '기여도 ' || round(share * 100, 1) || '%' || case when rw_gil > 0 then ' · ' || rw_gil || '전' else '' end || case when xp > 0 then ' · 경험치 ' || xp else '' end
      || case when got <> '' then ' · ' || regexp_replace(got, ' · $', '') else '' end
      || case when lost <> '' then ' (가방이 모자라 두고 옴: ' || regexp_replace(lost, ' · $', '') || ')' else '' end
      || case when share < 0.01 and rd.kind = 'world' then ' · 기여도 1% 미만이라 보상이 없습니다' else '' end,
      jsonb_build_object('raid_id', p_raid));
    perform public.world_title_award_check(m.owner_id, 'raid');
  end loop;
  if rd.kind = 'world' then
    nxt := public.world_raid_schedule_next();
    if p_won then
      delete from public.world_raid_locks;
      perform public.world_raid_chat('「' || rd.boss_name || '」을(를) 물리쳤습니다! 봉연의 기운이 걷힙니다.' || case when revenge then ' 잠겼던 땅도 풀려납니다.' else '' end);
    else
      select region_name into reg from public.world_map_regions where region_id = rd.region_id;
      insert into public.world_raid_locks(region_id, raid_id, until) values (rd.region_id, p_raid, nxt + interval '3 hours')
      on conflict (region_id) do update set raid_id = excluded.raid_id, until = excluded.until;
      perform public.world_raid_chat('「' || rd.boss_name || '」을(를) 막지 못했습니다. ' || reg || '이(가) 봉연에 잠겼습니다. 그 둘레의 침식과 요괴가 짙어집니다. 다음 그림자를 물리치면 풀립니다.');
    end if;
  end if;
end $$;

-- 다음 서버 보스 예정: 낮은·중간·높은 지역을 돌아가며, 앞 회차가 끝나고 72~96시간 뒤(첫 회는 30~42시간 뒤)
create or replace function public.world_raid_schedule_next()
returns timestamptz language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare cnt int; lo int; hi int; pick text; cands text[]; at timestamptz;
begin
  if exists (select 1 from public.world_raids where kind = 'world' and status in ('announced', 'signup', 'fight')) then
    return (select spawn_at from public.world_raids where kind = 'world' and status in ('announced', 'signup', 'fight') order by spawn_at limit 1);
  end if;
  select count(*) into cnt from public.world_raids where kind = 'world';
  lo := case cnt % 3 when 0 then 1 when 1 then 11 else 21 end; hi := case cnt % 3 when 0 then 10 when 1 then 20 else 30 end;
  select array_agg(region_id order by random()) into cands from (
    select region_id from public.world_map_regions where active and not coalesce(is_safe_zone, false) and coalesce(min_level, 1) between lo and hi
     order by random() limit 3) z;
  if cands is null or array_length(cands, 1) = 0 then
    select array_agg(region_id) into cands from (select region_id from public.world_map_regions where active and not coalesce(is_safe_zone, false) order by random() limit 3) z;
  end if;
  pick := cands[1];
  at := now() + case when cnt = 0 then interval '30 hours' + random() * interval '12 hours' else interval '72 hours' + random() * interval '24 hours' end;
  insert into public.world_raids(kind, boss_name, region_id, status, candidates, spawn_at)
  values ('world', '봉연의 그림자', pick, 'announced', (select array_agg(x order by random()) from unnest(cands) x), at);
  return at;
end $$;

-- 모두에게 알리기(전체 채팅 「봉연 소식」 + 알림)
create or replace function public.world_raid_broadcast(p_raid uuid, p_title text, p_text text)
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  perform public.world_raid_chat(p_text);
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select owner_id, 'raid_notice', p_title, p_text, jsonb_build_object('raid_id', p_raid) from public.world_characters where not coalesce(is_dead, false);
end $$;

-- 5분마다(그리고 누군가 토벌 화면을 볼 때): 예고·출현·신청 마감·시간 초과 정리
create or replace function public.world_raid_tick()
returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare rd public.world_raids%rowtype; reg text; names text; hm text;
begin
  perform public.world_raid_schedule_next();
  for rd in select * from public.world_raids where kind = 'world' and status = 'announced' and spawn_at - interval '24 hours' <= now() for update skip locked loop
    select region_name into reg from public.world_map_regions where region_id = rd.region_id;
    hm := to_char(rd.spawn_at at time zone 'Asia/Seoul', 'MM"월" DD"일" HH24"시" MI"분"');
    if rd.spawn_at <= now() then
      update public.world_raids set status = 'signup', signup_until = now() + interval '30 minutes', notices = notices || '{spawn}', updated_at = now() where raid_id = rd.raid_id;
      perform public.world_raid_say(rd.raid_id, 'phase', '봉연의 그림자가 ' || reg || '에 드러났습니다. 30분 동안 모인 뒤 토벌이 시작되고, 토벌 중에도 그곳에서 합류할 수 있습니다.');
      perform public.world_raid_broadcast(rd.raid_id, '봉연의 그림자 출현', '봉연의 그림자가 ' || reg || '에 드러났습니다! 30분 뒤 토벌이 시작되고, 끝나기 전까지 언제든 그곳에서 합류할 수 있습니다.');
    elsif rd.spawn_at - interval '3 hours' <= now() and not ('3h' = any (rd.notices)) then
      update public.world_raids set notices = notices || '{3h,6h,12h,24h}' where raid_id = rd.raid_id;
      perform public.world_raid_broadcast(rd.raid_id, '봉연 · 세 시간 전', '세 시간 뒤(' || hm || ') ' || reg || '에 봉연의 그림자가 드러납니다.');
    elsif rd.spawn_at - interval '6 hours' <= now() and not ('6h' = any (rd.notices)) then
      update public.world_raids set notices = notices || '{6h,12h,24h}' where raid_id = rd.raid_id;
      perform public.world_raid_broadcast(rd.raid_id, '봉연 · 여섯 시간 전', '여섯 시간 뒤(' || hm || ') ' || reg || '에 봉연의 그림자가 드러납니다. 준비하세요.');
    elsif rd.spawn_at - interval '12 hours' <= now() and not ('12h' = any (rd.notices)) then
      update public.world_raids set notices = notices || '{12h,24h}' where raid_id = rd.raid_id;
      perform public.world_raid_broadcast(rd.raid_id, '봉연 · 출현지 확정', '봉연의 기운이 한곳으로 모였습니다. ' || hm || '쯤 ' || reg || '에 봉연의 그림자가 드러납니다.');
    elsif not ('24h' = any (rd.notices)) then
      select string_agg(x.region_name, ', ') into names from unnest(rd.candidates) c join public.world_map_regions x on x.region_id = c;
      update public.world_raids set notices = notices || '{24h}' where raid_id = rd.raid_id;
      perform public.world_raid_broadcast(rd.raid_id, '봉연의 기운이 짙어집니다', '봉연의 기운이 짙어집니다. 하루 안에 「봉연의 그림자」가 ' || names || ' 가운데 한 곳에 드러날 듯합니다.');
    end if;
  end loop;
  for rd in select * from public.world_raids where status = 'signup' and signup_until <= now() for update skip locked loop
    perform public.world_raid_begin_fight(rd.raid_id);
  end loop;
  for rd in select * from public.world_raids where status = 'fight' and ends_at <= now() for update skip locked loop
    perform public.world_raid_say(rd.raid_id, 'phase', '시간이 다 되었습니다. ' || rd.boss_name || '이(가) 봉연 속으로 물러납니다.');
    perform public.world_raid_settle(rd.raid_id, false);
  end loop;
  delete from public.world_raid_locks where until <= now();
  delete from public.world_raid_log l using public.world_raids r where r.raid_id = l.raid_id and r.ended_at < now() - interval '7 days';
end $$;

-- 토벌 화면(참가자·관전 같은 화면): 보스·참가자·기록·내 행동
create or replace function public.world_raid_snapshot(p_raid uuid default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rd public.world_raids%rowtype; rid uuid := p_raid; me public.world_raid_members%rowtype;
  here text; mem jsonb; logs jsonb; tot numeric; can_join boolean := false; why text; coop jsonb := '[]'::jsonb; reveal_region boolean; reveal_c boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if exists (select 1 from public.world_raids where status in ('announced', 'signup', 'fight')
              and ((status = 'announced' and spawn_at <= now()) or (status = 'signup' and signup_until <= now()) or (status = 'fight' and ends_at <= now()))) then
    perform public.world_raid_tick();
  end if;
  if rid is null then
    select x.raid_id into rid from public.world_raid_members m join public.world_raids x on x.raid_id = m.raid_id
     where m.owner_id = uid and x.status in ('signup', 'fight') order by x.created_at desc limit 1;
  end if;
  if rid is null then
    select raid_id into rid from public.world_raids where kind = 'world' and status in ('signup', 'fight') order by created_at desc limit 1;
  end if;
  if rid is null then
    select raid_id into rid from public.world_raids where kind = 'world' order by coalesce(ended_at, spawn_at) desc nulls last limit 1;
  end if;
  select * into rd from public.world_raids where raid_id = rid;
  if not found then return jsonb_build_object('raid', null); end if;
  select * into me from public.world_raid_members where raid_id = rid and owner_id = uid;
  select region_id into here from public.world_map_regions where region_name = c.location;
  reveal_region := rd.status <> 'announced' or '12h' = any (rd.notices);
  reveal_c := rd.status <> 'announced' or '24h' = any (rd.notices);
  if rd.status = 'announced' and not reveal_c then return jsonb_build_object('raid', null); end if;
  select coalesce(sum(contrib), 0) into tot from public.world_raid_members where raid_id = rid;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.owner_id, 'name', x.name, 'level', x.level, 'job', x.job_key, 'hp', ch.health, 'sp', ch.spiritual_power,
      'out', case when x.out_until > now() then ceil(extract(epoch from x.out_until - now())) end, 'dmg', x.dmg, 'heal', x.heal, 'coop', x.coop, 'acts', x.acts,
      'share', case when tot > 0 then round(x.contrib / tot * 100, 1) else 0 end, 'me', x.owner_id = uid,
      'buffs', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(x.fx) k), 'reward', case when x.owner_id = uid then x.reward end)
      order by x.contrib desc, x.joined_at), '[]'::jsonb)
    into mem from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id where x.raid_id = rid;
  select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'at', l.at, 'kind', l.kind, 'text', l.text) order by l.id), '[]'::jsonb) into logs
    from (select * from public.world_raid_log where raid_id = rid order by id desc limit 40) l;
  if me.owner_id is null and (rd.status = 'signup' or (rd.kind = 'world' and rd.status = 'fight')) then
    if rd.status = 'signup' and rd.signup_until <= now() then why := '신청 시간이 지났습니다.';
    elsif rd.status = 'fight' and rd.ends_at <= now() then why := '토벌이 끝났습니다.';
    elsif c.health <= 0 or c.downed_at is not null then why := '전투불능 상태에서는 합류할 수 없습니다.';
    elsif here is distinct from rd.region_id then why := (select region_name from public.world_map_regions where region_id = rd.region_id) || case when rd.status = 'fight' then '에 가면 토벌에 합류할 수 있습니다.' else '에 있어야 신청할 수 있습니다.' end;
    elsif rd.kind = 'final' and not exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id where a.owner_id = uid and b.owner_id = rd.leader_id) then why := '시작한 조사원의 파티원만 합류할 수 있습니다.';
    else can_join := true; end if;
  end if;
  if me.owner_id is not null then
    select coalesce(jsonb_agg(jsonb_build_object('id', s.skill_id, 'name', s.skill_name, 'desc', s.description, 'target', s.target, 'cost', s.cost, 'rank', s.unlock_rank,
        'unlocked', coalesce(c.combat_rank, 1) >= s.unlock_rank, 'type', s.effect ->> 'type',
        'cd', case when me.cd ? s.skill_id and (me.cd ->> s.skill_id)::timestamptz > now() then ceil(extract(epoch from (me.cd ->> s.skill_id)::timestamptz - now())) else 0 end) order by s.sort), '[]'::jsonb)
      into coop from public.world_coop_skills s where s.job_key = c.job_key;
  end if;
  return jsonb_build_object('raid', jsonb_build_object('id', rd.raid_id, 'kind', rd.kind, 'boss', rd.boss_name, 'status', rd.status,
      'region_id', case when reveal_region then rd.region_id end, 'region', case when reveal_region then (select region_name from public.world_map_regions where region_id = rd.region_id) end,
      'candidates', case when reveal_c and not reveal_region then (select jsonb_agg(x.region_name) from unnest(rd.candidates) cc join public.world_map_regions x on x.region_id = cc) end,
      'spawn_at', case when reveal_region then rd.spawn_at end, 'signup_until', rd.signup_until, 'ends_at', rd.ends_at, 'ended_at', rd.ended_at,
      'hp', rd.hp, 'max_hp', rd.max_hp, 'phase', rd.phase, 'intent', rd.intent, 'leader', rd.leader_id = uid,
      'charge', rd.fx -> 'charge', 'boss_fx', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(rd.fx) k where k <> 'charge')),
    'members', mem, 'log', logs,
    'me', jsonb_build_object('joined', me.owner_id is not null, 'can_join', can_join, 'why', why, 'here', here = rd.region_id,
      'hp', c.health, 'sp', c.spiritual_power, 'out', case when me.out_until > now() then ceil(extract(epoch from me.out_until - now())) end,
      'fx', me.fx, 'coop', coop, 'job', c.job_key, 'combat_rank', coalesce(c.combat_rank, 1)),
    'locks', (select coalesce(jsonb_agg(jsonb_build_object('region_id', l.region_id, 'region', x.region_name, 'until', l.until)), '[]'::jsonb)
                from public.world_raid_locks l join public.world_map_regions x on x.region_id = l.region_id where l.until > now()));
end $$;

-- 현장 띠·지도용 가벼운 요약(봉연 소식·잠긴 곳·내 진행 중 결전)
create or replace function public.world_raid_brief()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); rd public.world_raids%rowtype; w jsonb; mine uuid;
begin
  select * into rd from public.world_raids where kind = 'world' and status in ('announced', 'signup', 'fight') order by created_at desc limit 1;
  if found and (rd.status <> 'announced' or '24h' = any (rd.notices)) then
    w := jsonb_build_object('id', rd.raid_id, 'status', rd.status, 'boss', rd.boss_name,
      'region', case when rd.status <> 'announced' or '12h' = any (rd.notices) then (select region_name from public.world_map_regions where region_id = rd.region_id) end,
      'candidates', case when rd.status = 'announced' and not ('12h' = any (rd.notices)) then (select jsonb_agg(x.region_name) from unnest(rd.candidates) cc join public.world_map_regions x on x.region_id = cc) end,
      'spawn_at', case when rd.status <> 'announced' or '12h' = any (rd.notices) then rd.spawn_at end,
      'signup_until', rd.signup_until, 'ends_at', rd.ends_at, 'hp', rd.hp, 'max_hp', rd.max_hp,
      'joined', exists (select 1 from public.world_raid_members m where m.raid_id = rd.raid_id and m.owner_id = uid));
  end if;
  select x.raid_id into mine from public.world_raid_members m join public.world_raids x on x.raid_id = m.raid_id
   where m.owner_id = uid and x.kind = 'final' and x.status in ('signup', 'fight') limit 1;
  return jsonb_build_object('world', w, 'final', mine,
    'locks', (select coalesce(jsonb_agg(jsonb_build_object('region_id', l.region_id, 'region', x.region_name)), '[]'::jsonb)
                from public.world_raid_locks l join public.world_map_regions x on x.region_id = l.region_id where l.until > now()));
end $$;

do $$ declare f text; begin
  foreach f in array array['world_coop_list()', 'world_coop_exp_procs(uuid,jsonb)', 'world_raid_chat(text)', 'world_raid_say(uuid,text,text)', 'world_region_neighbors(text)', 'world_raid_lock_effect(text)',
                           'world_raid_stats(uuid)', 'world_raid_hit(uuid,uuid,numeric,text)', 'world_raid_begin_fight(uuid)', 'world_raid_final_start()', 'world_raid_join(uuid)',
                           'world_raid_begin(uuid)', 'world_raid_action(uuid,text,text,uuid,text)', 'world_raid_settle(uuid,boolean)', 'world_raid_schedule_next()',
                           'world_raid_broadcast(uuid,text,text)', 'world_raid_tick()', 'world_raid_snapshot(uuid)', 'world_raid_brief()'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['world_coop_list()', 'world_raid_final_start()', 'world_raid_join(uuid)', 'world_raid_begin(uuid)', 'world_raid_action(uuid,text,text,uuid,text)',
                           'world_raid_snapshot(uuid)', 'world_raid_brief()'] loop
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- 상태 효과 합계는 모두가 부르므로 잠김 효과도 누구나 부를 수 있어야 한다
  execute 'grant execute on function public.world_raid_lock_effect(text) to public';
  execute 'grant execute on function public.world_region_neighbors(text) to public';
end $$;

do $$ begin
  if exists (select 1 from cron.job where jobname = 'yh-raid') then perform cron.unschedule('yh-raid'); end if;
  perform cron.schedule('yh-raid', '*/5 * * * *', 'select public.world_raid_tick()');
end $$;

-- 원정 합동 전투에 협동 기술 발동을 끼워 넣는다
do $$ declare d text := pg_get_functiondef('public.world_expedition_settle(uuid,integer)'::regprocedure);
  a1 text := 'ammo_used int := 0;'; b1 text := 'ammo_used int := 0; cfx jsonb; cl jsonb;';
  a2 text := 'win_p := (power + sum_ally * 0.6) / (power + sum_ally * 0.6 + threat);';
  b2 text := 'win_p := (power + sum_ally * 0.6) / (power + sum_ally * 0.6 + threat);
    -- 협동 기술(6.1.0): 함께 싸우는 사람들의 열린 협동 기술이 확률로 저절로 나온다
    if nal > 0 then
      cfx := public.world_coop_exp_procs(e.owner_id, act);
      win_p := win_p + coalesce((cfx ->> ''win'')::float8, 0);
      hp := least(100, hp + coalesce((cfx ->> ''heal'')::int, 0));
      for cl in select value from jsonb_array_elements(coalesce(cfx -> ''lines'', ''[]''::jsonb)) loop
        seq := seq + 1; jr := jr || jsonb_build_object(''at'', base_t + make_interval(secs => seq * 2), ''kind'', ''skill'', ''who'', cl ->> ''who'', ''owner'', cl ->> ''owner'', ''text'', cl ->> ''text'');
      end loop;
    end if;';
begin
  if position('world_coop_exp_procs' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1 then raise exception '원정 정산 고칠 자리 1(6.1.0)'; end if;
  if (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 then raise exception '원정 정산 고칠 자리 2(6.1.0)'; end if;
  execute replace(replace(d, a1, b1), a2, b2);
end $$;

-- ③ 칭호(업적): 규칙 'raid'를 world_raid_rule_count가 센다 ─────────────
create or replace function public.world_raid_rule_count(p_owner uuid, p_rule jsonb)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce(case p_rule ->> 'raid'
    when 'join' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'world' and m.acts > 0)
    when 'win' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'world' and r.status = 'won' and m.acts > 0)
    when 'top' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.status = 'won' and r.kind = 'world' and coalesce((m.reward ->> 'top')::boolean, false))
    when 'heal' then (select sum(m.heal) from public.world_raid_members m where m.owner_id = p_owner)
    when 'coop' then (select sum(m.coop) from public.world_raid_members m where m.owner_id = p_owner)
    when 'final' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'final' and r.status = 'won' and m.acts > 0)
    when 'final_solo' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'final' and r.status = 'won'
                             and (select count(*) from public.world_raid_members y where y.raid_id = r.raid_id) = 1)
    when 'final_full' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'final' and r.status = 'won'
                             and (select count(*) from public.world_raid_members y where y.raid_id = r.raid_id) >= 4)
    when 'low' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'world' and r.status = 'won' and m.level <= 15 and m.acts > 0)
    when 'revenge' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.status = 'won' and coalesce((m.reward ->> 'revenge')::boolean, false))
    when 'fall' then (select sum(m.falls) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.status = 'won')
  end, 0)
$$;
alter function public.world_raid_rule_count(uuid, jsonb) owner to fn_owner_field;
revoke all on function public.world_raid_rule_count(uuid, jsonb) from public, anon, authenticated;
do $$ declare d text := pg_get_functiondef('public.world_title_rule_progress(uuid,jsonb)'::regprocedure);
  a text := 'elsif p_rule ? ''codex'' then'; b text := 'elsif p_rule ? ''raid'' then
    v := public.world_raid_rule_count(p_owner, p_rule);
  elsif p_rule ? ''codex'' then';
begin
  if position('world_raid_rule_count' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '칭호 진행 고칠 자리(6.1.0)'; end if;
  execute replace(d, a, b);
end $$;
do $$ declare d text := pg_get_functiondef('public.world_title_rule_ok(uuid,jsonb)'::regprocedure);
  a text := 'ELSIF p_rule ? ''codex'' THEN'; b text := 'ELSIF p_rule ? ''raid'' THEN RETURN public.world_raid_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? ''codex'' THEN';
begin
  if position('world_raid_rule_count' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '칭호 판정 고칠 자리(6.1.0)'; end if;
  execute replace(d, a, b);
end $$;
do $$ declare d text := pg_get_functiondef('public.world_title_award_check(uuid,text)'::regprocedure);
  a text := 'IF r ? ''yohwa'' AND'; b text := 'IF r ? ''raid'' AND p_event_type IS NOT NULL AND p_event_type <> ''raid'' THEN CONTINUE; END IF; IF r ? ''yohwa'' AND';
begin
  if position('''raid''' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '칭호 수여 고칠 자리(6.1.0)'; end if;
  execute replace(d, a, b);
end $$;

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('raid_join1', '봉연을 마주한 자', 'flag', '봉연의 그림자 앞에 처음 섰다.', '봉연의 그림자 토벌에 참가해 싸우기', '{"presence":4}', true, false, '{"raid":"join","n":1}', 400, '토벌', 2),
  ('raid_win1', '그림자를 걷은 자', 'flag', '처음으로 봉연의 그림자를 물리쳤다.', '봉연의 그림자 토벌 성공 1번', '{"combat_damage_pct":1,"defense":2}', true, false, '{"raid":"win","n":1}', 401, '토벌', 3),
  ('raid_win5', '봉연 사냥꾼', 'flag', '그림자가 드러나면 사람들이 먼저 이 이름을 찾는다.', '봉연의 그림자 토벌 성공 5번', '{"combat_damage_pct":2,"erosion_pct":-3,"crit_pct":1}', true, false, '{"raid":"win","n":5}', 402, '토벌', 4),
  ('raid_win15', '봉연을 지키는 등불', 'flag', '열다섯 번의 밤, 그림자는 이 등불을 넘지 못했다.', '봉연의 그림자 토벌 성공 15번', '{"combat_damage_pct":3,"incoming_damage_pct":-2,"erosion_pct":-4}', true, false, '{"raid":"win","n":15}', 403, '토벌', 5),
  ('raid_top', '선봉', 'sword', '가장 앞에서 가장 많이 베었다.', '봉연의 그림자 토벌에서 기여도 1위로 성공', '{"crit_pct":2,"presence":6}', true, false, '{"raid":"top","n":1}', 404, '토벌', 4),
  ('raid_heal', '야전의 손', 'heart', '그 싸움에서 쓰러지지 않은 사람들이 이 손을 기억한다.', '합동 토벌에서 동료와 나를 합해 500 회복', '{"healing_pct":4,"mental_loss_pct":-2}', true, false, '{"raid":"heal","n":500}', 405, '토벌', 3),
  ('raid_coop', '함께 싸우는 법', 'users', '혼자 강한 것과 함께 강한 것은 다르다.', '합동 토벌에서 협동 기술 100번', '{"healing_pct":2,"defense":2,"evasion_pct":1}', true, false, '{"raid":"coop","n":100}', 406, '토벌', 3),
  ('raid_low', '작은 불씨', 'spark', '작은 불씨도 그림자를 태울 수 있다.', 'Lv15 이하로 봉연의 그림자 토벌 성공', '{"evasion_pct":2,"healing_pct":2}', true, true, '{"raid":"low","n":1}', 407, '토벌', 3),
  ('raid_revenge', '봉연을 되돌린 자', 'flag', '잠겼던 땅을 되찾았다.', '봉연에 잠긴 땅이 있을 때 다음 그림자를 물리치기', '{"erosion_pct":-5,"rare_loot_pct":2}', true, false, '{"raid":"revenge","n":1}', 408, '토벌', 4),
  ('raid_fallen', '일곱 번 넘어져도', 'heart', '넘어진 수만큼 다시 일어섰다.', '이긴 토벌에서 모두 합해 일곱 번 물러나기', '{"incoming_damage_pct":-2,"mental_loss_pct":-3}', true, true, '{"raid":"fall","n":7}', 409, '토벌', 3),
  ('final_clear', '구중을 닫은 자', 'flag', '아홉 겹 사슬 너머의 숨을 다시 재웠다.', '구중 봉주와의 결전에서 이기기', '{"combat_damage_pct":3,"incoming_damage_pct":-3,"erosion_pct":-5}', true, false, '{"raid":"final","n":1}', 410, '토벌', 5),
  ('final_solo', '홀로 선 등불', 'flag', '아무도 곁에 없었지만 등불은 꺼지지 않았다.', '혼자서 구중 봉주를 물리치기', '{"crit_pct":3,"combat_damage_pct":2,"defense":3}', true, true, '{"raid":"final_solo","n":1}', 411, '토벌', 5),
  ('final_full', '네 개의 등불', 'users', '넷이 함께 들었기에 그 밤이 밝았다.', '네 명이 함께 구중 봉주를 물리치기', '{"healing_pct":4,"presence":8,"defense":2}', true, false, '{"raid":"final_full","n":1}', 412, '토벌', 4)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text,
  bonus = excluded.bonus, hidden = excluded.hidden, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;

-- ④ 10장 최종 결전 퀘스트 ────────────────────────────────────
-- 할 일 't':'raid' — 결전(또는 서버 보스)에서 이긴 수를 센다
do $$ declare d text := pg_get_functiondef('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)'::regprocedure);
  a text := 'select case when p_task ->> ''t'' in (''win'', ''gather'', ''craft'', ''fish'') then (';
  b text := 'select case when p_task ->> ''t'' = ''raid'' then (select count(*)::int from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id
                where m.owner_id = p_uid and r.kind = coalesce(p_task ->> ''kind'', ''final'') and r.status = ''won'' and m.acts > 0 and r.ended_at >= p_since)
    when p_task ->> ''t'' in (''win'', ''gather'', ''craft'', ''fish'') then (';
begin
  if position('world_raid_members' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '퀘스트 할 일 고칠 자리(6.1.0)'; end if;
  execute replace(d, a, b);
end $$;
do $$ declare d text := pg_get_functiondef('public.world_quest_task_label(jsonb)'::regprocedure);
  a text := 'when p_task ->> ''t'' = ''win'' and p_task ? ''m'' then';
  b text := 'when p_task ->> ''t'' = ''raid'' then case when p_task ->> ''kind'' = ''world'' then ''봉연의 그림자 토벌 성공'' else ''구중 봉주와의 결전에서 이기기'' end
    when p_task ->> ''t'' = ''win'' and p_task ? ''m'' then';
begin
  if position('''raid''' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '퀘스트 할 일 문구 고칠 자리(6.1.0)'; end if;
  execute replace(d, a, b);
end $$;

insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active)
values ('fq_sealed_lord', 'side', '결전', '구중 봉주', '아홉 겹 사슬 너머에서 잠든 것이 눈을 뜬다. 혼자, 또는 동료와 함께 맞선다.', 'sealed_abyss', 30, array['mq_nine_gates'], null, 999, '[]'::jsonb, true)
on conflict (quest_id) do update set title = excluded.title, summary = excluded.summary, cat = excluded.cat, min_level = excluded.min_level, after = excluded.after, region_id = excluded.region_id;
delete from public.world_quest_steps where quest_id = 'fq_sealed_lord';
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values
  ('fq_sealed_lord', 1, '숨과 숨 사이', '구중 봉연에서 파수꾼 윤재음을 만난다', '{"at": ["sealed_abyss"]}'::jsonb,
   '[{"s": null, "t": "닫힌 문 너머에서 사슬이 한꺼번에 울린다. 이번에는 다시 감기는 소리가 들리지 않는다."},
     {"s": "q:bl_jaeum", "t": "숨과 숨 사이가 다 줄었습니다. 이제는 들이쉬기만 합니다."},
     {"s": "night_office:han", "t": "규정에는 이런 경우가 없습니다. 그러니 제가 새로 적겠습니다. 「문 앞에 선 자가 결정한다.」"},
     {"s": "mandate_court:seo", "t": "별 하나 남았어요. 그게 떨어지면 깨어나요. 그 전에 누가 먼저 문을 두드려야 해요."},
     {"s": "q:bl_jaeum", "t": "혼자 가셔도, 동료와 함께 가셔도 됩니다. 다만 넷을 넘으면 사슬이 버티지 못합니다."},
     {"s": "me", "t": "문 앞에서 기다리지 않겠습니다. 들어가서 재우겠습니다."}]'::jsonb, '{}'::jsonb),
  ('fq_sealed_lord', 2, '구중 봉주', '구중 봉주와의 결전에서 이긴다(혼자 또는 파티원 4명까지)', '{"tasks": [{"t": "raid", "kind": "final", "n": 1}], "at": ["sealed_abyss"]}'::jsonb,
   '[{"s": null, "t": "아홉 겹 사슬이 마지막으로 팽팽해졌다가, 천천히 늘어진다. 들이쉬던 숨이 길게 내쉬어진다."},
     {"s": "q:bl_jaeum", "t": "……잠들었습니다. 이번에는 꿈도 꾸지 않습니다."},
     {"s": "mandate_court:seo", "t": "별이 멈췄어요. 셈이 처음으로 돌아갔어요. 아홉, 그리고 또 아홉."},
     {"s": "night_office:han", "t": "끝났다고 적지는 않겠습니다. 그건 거짓이니까요. 「이번 밤은 지켜졌다.」 이렇게 적겠습니다."},
     {"s": null, "t": "그래도 봉연 바깥, 세상 곳곳으로 새어 나간 그림자들은 아직 돌아다닌다. 사흘이나 나흘에 한 번, 그것들이 한곳에 모일 것이다."},
     {"s": "me", "t": "그때마다 모이겠습니다. 혼자가 아니라."}]'::jsonb,
   '{"xp": 4140, "gil": 125, "items": {"heavenly_dew": 1}}'::jsonb);

-- 처음 회차 예정(배포 직후 30~42시간 뒤)
select public.world_raid_schedule_next();

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261031000000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

-- 패치노트 6.1.0
insert into public.world_patch_notes(note_id, title, body, created_at) values
  ('6.1.0', '합동 토벌 · 10장 결전 · 봉연의 그림자 · 협동 기술', $PN$## 6.1.0 · 합동 토벌 · 10장 결전 · 봉연의 그림자 · 협동 기술

### 합동 토벌
- 여러 조사원이 **체력 하나를 함께 깎는** 큰 싸움이 생겼습니다. 1초마다 공격·방어·물품·협동 기술 가운데 하나를 고릅니다. 요괴는 행동한 사람에게 반격하고, 몇 턴마다 모두를 치거나 사슬로 묶거나 기운을 모읍니다. 기운을 모을 때는 정해진 만큼 몰아쳐야 끊깁니다. 체력이 70%·40% 아래로 내려가면 더 거세집니다.
- 토벌에서 쓰러지면 전투불능이 아니라 체력 1로 **60초 동안 물러났다가** 돌아옵니다.
- 참가자의 체력·기여도·걸린 효과가 한 화면에 보입니다. 참가하지 않은 사람도 같은 화면에서 **실시간으로 지켜볼 수** 있습니다.

### 10장 최종 결전 「구중 봉주」
- 10장을 마치면 구중 봉연에서 퀘스트 「구중 봉주」가 열립니다. **혼자, 또는 같은 곳의 파티원과(4명까지)** 결전에 들어갑니다. 요괴 체력은 인원에 따라 늘어나고, 20분 안에 이겨야 합니다.

### 서버 보스 「봉연의 그림자」
- **사흘~나흘마다** 세상 어딘가에 나타납니다. 24시간 전에 후보 지역 셋, 12시간 전에 확정 지역을 알리고, 6시간·3시간 전에 한 번 더 알립니다(전체 채팅 「봉연 소식」·알림·현장 띠).
- 나타나면 그 지역에 **30분 동안 모인 뒤 2시간 동안 토벌**합니다. 돌발 임무처럼 **토벌 도중에도 그 지역에 가면 바로 합류**할 수 있습니다(늦게 합류하면 남은 시간만큼 그림자의 체력이 늘고, 기여도는 그만큼 덜 쌓입니다). 합류하지 않은 사람은 같은 화면에서 지켜봅니다. 레벨과 상관없이 누구나 들 수 있습니다. 다만 요괴는 지역 레벨보다 3 높게 치고, 낮은 레벨은 기여도가 적게 잡힙니다.
- 기여도 1% 이상이면 보상을 받습니다. 전·경험치·봉연 조각은 기여도에 따라 나오고, 회복약·강화 재료·**토벌 전용 장비**(노리개·호신부·탈, 5단계·거래 불가)는 확률로 나옵니다.
- 막지 못하면 다음 회차까지 그 지역이 **봉연에 잠깁니다**. 그곳은 침식 +30%·요괴 조우 +10%·채집량 −25%·받는 피해 +10%이고(채집·원정은 할 수 있음), 바로 이웃한 지역은 침식 +30%·조우 +10%, 그 이웃은 침식 +10%·조우 +5%입니다. 지도와 현장에 「봉연에 잠김」이 보입니다.

### 협동 기술
- 직업마다 **협동 기술 네 가지**가 전투 숙련 3·8·18·36단계에서 열립니다(캐릭터 › 기술 아래). 봉인술사는 호신부·기세 부적 같은 버프, 의무관은 응급 처치·야전 소생 같은 치료, 퇴마관은 대신 막기·퇴마 결계 같은 보호를 합니다. 현장 조사원은 표시·연막, 호위 무사는 급소 지시·전장 지휘, 백공 기술관은 수선·보급을 맡습니다.
- 합동 토벌에서만 **그 턴의 행동으로 골라** 씁니다(영력·다시 쓰기 시간). 동료에게 거는 기술은 참가자 이름을 눌러 대상을 고릅니다.
- 같은 지역 **파티 원정의 합동 전투**에서는 열린 협동 기술이 확률로 저절로 나옵니다.

### 칭호
- 분류 「토벌」 칭호 **13가지**가 생겼습니다. 참가·승리 횟수, 최다 기여, 치료·협동, 결전 등으로 얻고, 일부는 숨겨져 있습니다.

### 고친 것
- 파티 채팅에 새 말이 와도 아무 표시가 없던 문제를 고쳤습니다(제보 감사합니다). 이제 다른 탭을 보고 있으면 「파티」 탭에 빨간 점과 알림음이, 모바일에서 채팅을 닫아 두었으면 채팅 단추에 안 읽은 수가 뜹니다.
$PN$, now())
on conflict (note_id) do update set title = excluded.title, body = excluded.body;

-- 파티 채팅 알림(제보 8): 파티 말을 실시간으로 받아 탭에 표시한다. 읽기는 기존 RLS(world_party_messages_member_read, 그 파티원만)가 막는다
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'world_party_messages') then
    alter publication supabase_realtime add table public.world_party_messages;
  end if;
end $$;
