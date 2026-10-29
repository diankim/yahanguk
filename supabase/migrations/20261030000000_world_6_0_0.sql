-- 6.0.0 대규모 패치 묶음: 그 패치 때 한 번에 실행하는 파일이다(작은 SQL을 따로따로 돌리지 않는다).
--   ① 밸런스(2026-10-29 결정, 제안대로)
--      · 탐색력 1 회복 6분 → 15분, 노정 건량 탐색력 +5 → +2
--      · 퀘스트 보상 전 ×0.4(주 이야기 장 보상·상시 의뢰)
--      · 피해: 주 능력치 계수 낮춤(근접 힘 1.5→1.0 / 술법 영기 1.1→0.75·의지 0.6→0.4 / 원거리 민첩 0.9→0.6·감각 0.7→0.45),
--        피해 % 합 상한 +35%, 칭호의 피해 % 값 절반, 치명타 배율 160% → 150%
--      · 능력치 하나의 상한 = 5 + 레벨×1.5(내림). 넘은 몫은 포인트로 돌려준다
--      · 장비 드롭: 일반 5→1%·정예 12→5%·우두머리 30→15%, 3단계 이상은 우두머리만. 원정 완주 장비 1시간 50%·2시간 보장 → 2시간 50%·4시간 보장, 심부·핵심 덤 8·15% → 4·8%
--      · 사냥 경험치 절반((12+요괴Lv×6) → (6+요괴Lv×3), 토벌 기록 경험치 24 → 12)과 레벨 차 배율(요괴Lv−내Lv: −6↓ ×0.2 · −3~−5 ×0.5 · −1~−2 ×0.85 · +1~+2 ×1.15 · +3~+4 ×1.3 · +5↑ ×1.5)
--      · 내 레벨보다 3 높은 지역에서는 침식이 ×1.5, 5 높으면 ×2로 오른다(지금 있는 지역 기준, 탐색·토벌)
--      · 원정 경험치: 회차마다 쌓던 경험치를 없애고, 끝까지 다녀오면 완주 경험치 하나(던전 클리어처럼)
--        (60 + 지역Lv×15) × 시간^0.8 × 깊이(외곽 1·심부 1.2·핵심 1.4) × 레벨 차 배율. 조기 귀환·쓰러짐은 없음. 숙련 경험은 그대로

grant fn_owner_field to postgres with inherit true, set true;
grant fn_owner_18473 to postgres with inherit true, set true; -- world_award_progression_from_event
grant fn_owner_18475 to postgres with inherit true, set true; -- world_allocate_stat

-- 레벨 차 경험치 배율(요괴·지역 레벨 − 내 레벨)
create or replace function public.world_xp_gap_mul(p_gap int)
returns numeric language sql immutable set search_path to 'pg_catalog' as $$
  select case when p_gap <= -6 then 0.2 when p_gap <= -3 then 0.5 when p_gap <= -1 then 0.85 when p_gap = 0 then 1
              when p_gap <= 2 then 1.15 when p_gap <= 4 then 1.3 else 1.5 end::numeric
$$;
alter function public.world_xp_gap_mul(int) owner to fn_owner_field;
grant execute on function public.world_xp_gap_mul(int) to public;

-- 능력치 하나의 상한
create or replace function public.world_stat_cap(p_level int)
returns int language sql immutable set search_path to 'pg_catalog' as $$ select 5 + floor(greatest(1, coalesce(p_level, 1)) * 1.5)::int $$;
alter function public.world_stat_cap(int) owner to fn_owner_field;
grant execute on function public.world_stat_cap(int) to public;

-- 높은 지역의 침식: 지금 있는 바깥 지역이 내 레벨보다 3 이상 높으면 +50%, 5 이상이면 +100%
create or replace function public.world_level_gap_effect(p_key text)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when p_key <> 'erosion_pct' then 0 else coalesce((
    select case when r.min_level - c.level >= 5 then 100 when r.min_level - c.level >= 3 then 50 else 0 end
      from public.world_characters c join public.world_map_regions r on r.region_name = c.location
     where c.owner_id = public.fn_owner_auth_uid() and not coalesce(r.is_safe_zone, false) limit 1), 0) end::numeric
$$;
alter function public.world_level_gap_effect(text) owner to fn_owner_field;
revoke all on function public.world_level_gap_effect(text) from public, anon, authenticated;
grant execute on function public.world_level_gap_effect(text) to public;
do $$ declare d text := pg_get_functiondef('public.world_status_effect_total(text)'::regprocedure);
  a text := '+ public.world_faction_rank_effect(p_effect_key)'; b text := '+ public.world_faction_rank_effect(p_effect_key) + public.world_level_gap_effect(p_effect_key)';
begin
  if position('world_level_gap_effect' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '상태 효과 합계 고칠 자리(6.0.0)'; end if;
  execute replace(d, a, b);
end $$;

-- 탐색력: 15분에 1. 바꾸기 전에 지금까지 찬 몫을 굳혀 둔다(나눗수가 바뀌어 이미 찬 탐색력이 줄지 않게)
update public.world_characters
   set stamina = public.world_stamina_now(stamina, stamina_at, level), stamina_at = now()
 where stamina_at is not null and public.world_stamina_now(stamina, stamina_at, level) <> stamina;
do $$ declare d text := pg_get_functiondef('public.world_stamina_now(integer,timestamp with time zone,integer)'::regprocedure);
begin
  if position('/ 900)' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, '/ 360)', ''))) / 6 <> 1 then raise exception '탐색력 회복 고칠 자리'; end if;
  execute replace(d, '/ 360)', '/ 900)');
end $$;

-- 노정 건량 탐색력 +2
do $$ declare d text := pg_get_functiondef('public.world_use_item(text)'::regprocedure);
  a text := 'WHEN ''travel_ration'' THEN stam := 5;'; b text := 'WHEN ''travel_ration'' THEN stam := 2;';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '노정 건량 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;
update public.world_item_catalog set description = replace(description, '탐색력 +5', '탐색력 +2') where item_id = 'travel_ration' and description like '%탐색력 +5%';

-- 주 이야기 장 보상 전 ×0.4(문구의 금액도 함께)
update public.world_story_chapters ch
   set rewards = jsonb_set(jsonb_set(ch.rewards, '{gil}', to_jsonb(round((ch.rewards ->> 'gil')::numeric * 0.4)::int)),
                           '{text}', to_jsonb(replace(ch.rewards ->> 'text', to_char((ch.rewards ->> 'gil')::int, 'FM999,999') || '전',
                                                      to_char(round((ch.rewards ->> 'gil')::numeric * 0.4)::int, 'FM999,999') || '전')))
 where ch.rewards ? 'gil' and not coalesce((ch.rewards ->> 'gil_v6')::boolean, false);
update public.world_story_chapters set rewards = rewards || '{"gil_v6": true}'::jsonb where rewards ? 'gil' and not rewards ? 'gil_v6';

-- 상시 의뢰 전 ×0.4: 새로 뽑히는 의뢰에 붙이고, 아직 받지 않은 오늘 의뢰도 맞춘다
create or replace function public.world_commission_gil_v6()
returns trigger language plpgsql set search_path to 'pg_catalog', 'public' as $$
begin
  new.reward_gil := round(coalesce(new.reward_gil, 0) * 0.4);
  return new;
end $$;
alter function public.world_commission_gil_v6() owner to fn_owner_field;
revoke all on function public.world_commission_gil_v6() from public, anon, authenticated;
drop trigger if exists trg_world_commission_gil_v6 on public.world_commissions;
create trigger trg_world_commission_gil_v6 before insert on public.world_commissions for each row execute function public.world_commission_gil_v6();
update public.world_commissions set reward_gil = round(reward_gil * 0.4) where claimed_at is null and day >= (now() at time zone 'Asia/Seoul')::date - 1;

-- 피해 공식(world_combat_stats): 주 능력치 계수·피해 % 상한·치명타 배율
do $$ declare d text := pg_get_functiondef('public.world_combat_stats(uuid,jsonb)'::regprocedure);
  r text[][] := array[
    array['WHEN ''ranged'' THEN 6 + s_agi * 0.9 + s_per * 0.7 + wpow * 1.5 + c.level * 0.8', 'WHEN ''ranged'' THEN 6 + s_agi * 0.6 + s_per * 0.45 + wpow * 1.5 + c.level * 0.8'],
    array['WHEN ''magic'' THEN 6 + s_spi * 1.1 + s_wil * 0.6 + wpow * 1.5 + c.level * 0.8', 'WHEN ''magic'' THEN 6 + s_spi * 0.75 + s_wil * 0.4 + wpow * 1.5 + c.level * 0.8'],
    array['ELSE 8 + s_str * 1.5 + wpow * 1.6 + c.level * 0.8 END;', 'ELSE 8 + s_str * 1.0 + wpow * 1.6 + c.level * 0.8 END;'],
    array['+ wbonus + style_pct + skill_pct;', '+ wbonus + style_pct + skill_pct; pct := least(35, pct);'],
    array['''crit_mult'', 160,', '''crit_mult'', 150, ''damage_cap'', 35,']];
  i int;
begin
  if position('damage_cap' in d) > 0 then return; end if;
  for i in 1 .. array_length(r, 1) loop
    if (length(d) - length(replace(d, r[i][1], ''))) / length(r[i][1]) <> 1 then raise exception '전투 능력치 고칠 자리 %', i; end if;
    d := replace(d, r[i][1], r[i][2]);
  end loop;
  execute d;
end $$;

-- 현장 토벌: 치명타 배율 150%, 사냥 경험치 절반 + 레벨 차 배율
do $$ declare d text := pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure);
  a1 text := 'crit_x numeric := 1.6;'; b1 text := 'crit_x numeric := 1.5;';
  a2 text := 'xp := round((12 + a.mlevel * 6) * rk_mul * (CASE WHEN a.mlevel < c.level - 5 THEN 0.3 ELSE 1 END));';
  b2 text := 'xp := round((6 + a.mlevel * 3) * rk_mul * public.world_xp_gap_mul(a.mlevel - c.level));';
begin
  if position('world_xp_gap_mul' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1 then raise exception '토벌 치명타 고칠 자리'; end if;
  if (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 then raise exception '토벌 경험치 고칠 자리'; end if;
  execute replace(replace(d, a1, b1), a2, b2);
end $$;

-- 토벌 기록 경험치 24 → 12
do $$ declare d text := pg_get_functiondef('public.world_award_progression_from_event()'::regprocedure);
  a text := 'when coalesce((new.payload->>''defeated'')::boolean,false) then 24 else 0 end';
  b text := 'when coalesce((new.payload->>''defeated'')::boolean,false) then 12 else 0 end';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '토벌 기록 경험치 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- 칭호의 피해 % 값 절반(최소 1)
update public.world_title_catalog t
   set bonus = (select jsonb_object_agg(e.key, case when e.key in ('combat_damage_pct', 'melee_pct', 'ranged_pct', 'magic_pct') and e.value::text ~ '^[0-9.]+$'
                                                     then to_jsonb(greatest(1, round(e.value::text::numeric / 2))) else e.value end)
                  from jsonb_each(t.bonus) e)
 where t.bonus ?| array['combat_damage_pct', 'melee_pct', 'ranged_pct', 'magic_pct']
   and not exists (select 1 from public.world_app_meta m where m.key = 'v6_title_dmg_halved');
insert into public.world_app_meta(key, value) values ('v6_title_dmg_halved', '1') on conflict (key) do nothing;

-- 능력치 하나의 상한: 올릴 때 막고, 지금 넘은 몫은 포인트로 돌려준다
do $$ declare d text := pg_get_functiondef('public.world_allocate_stat(text)'::regprocedure);
  a text := ' execute format(''update public.world_characters set %I = %I + 1';
  b text := E' if (case p_stat when ''strength'' then c.strength when ''agility'' then c.agility when ''vitality'' then c.vitality when ''perception'' then c.perception when ''willpower'' then c.willpower else c.spirit_affinity end) >= public.world_stat_cap(c.level) then raise exception ''지금 레벨에서는 한 능력치를 %까지 올릴 수 있습니다(레벨이 오르면 늘어납니다).'', public.world_stat_cap(c.level); end if;\n';
begin
  if position('world_stat_cap' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '능력치 올리기 고칠 자리'; end if;
  execute replace(d, a, b || a);
end $$;
with x as (
  select owner_id, public.world_stat_cap(level) cap,
         greatest(0, strength - public.world_stat_cap(level)) + greatest(0, agility - public.world_stat_cap(level)) + greatest(0, vitality - public.world_stat_cap(level))
         + greatest(0, perception - public.world_stat_cap(level)) + greatest(0, willpower - public.world_stat_cap(level)) + greatest(0, spirit_affinity - public.world_stat_cap(level)) over_n
    from public.world_characters)
update public.world_characters c
   set strength = least(c.strength, x.cap), agility = least(c.agility, x.cap), vitality = least(c.vitality, x.cap),
       perception = least(c.perception, x.cap), willpower = least(c.willpower, x.cap), spirit_affinity = least(c.spirit_affinity, x.cap),
       stat_points = c.stat_points + x.over_n, updated_at = now()
  from x where x.owner_id = c.owner_id and x.over_n > 0;

-- 장비 드롭: 상한을 낮추고, 3단계 이상은 우두머리만
create or replace function public.world_gear_roll(p_mech text, p_level integer, p_rank text, p_rare numeric default 0)
returns text language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare total numeric; cap numeric; got text;
begin
  select coalesce(sum(case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end), 0)
    into total from public.world_gear_drops g join public.world_item_catalog i on i.item_id = g.item_id
   where g.mechanic_key = p_mech and p_level between g.level_min and g.level_max and (p_rank = 'guardian' or coalesce(i.tier, 1) <= 2);
  if total <= 0 then return null; end if;
  cap := case p_rank when 'guardian' then 0.15 when 'elite' then 0.05 else 0.01 end;
  if random() >= least(cap, total) * greatest(0, 1 + coalesce(p_rare, 0) / 100.0) then return null; end if;
  select g.item_id into got from public.world_gear_drops g join public.world_item_catalog i on i.item_id = g.item_id
   where g.mechanic_key = p_mech and p_level between g.level_min and g.level_max and (p_rank = 'guardian' or coalesce(i.tier, 1) <= 2)
     and (case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end) > 0
   order by -ln(greatest(random(), 1e-9)) / (case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end)
   limit 1;
  return got;
end $$;

-- 원정: 완주 경험치 · 완주 장비 2시간 50%·4시간 보장 · 심부·핵심 덤 4·8%
do $$ declare d text := pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure);
  r text[][] := array[
    array['xp := round(xp * 7 * vmul * (case when c.level <= 10 then 1.3 else 1 end) * (1 + public.world_gear_total(uid, ''expedition_xp_pct'') / 100.0));',
          'xp := case when ended = ''complete'' and e.settled_rounds >= total_rounds then round((60 + coalesce(n.min_level, r.min_level, c.level) * 15) * power(e.minutes / 60.0, 0.8)'
          || ' * (case greatest(1, least(3, coalesce(n.hierarchy_level, 2) - 1)) when 1 then 1 when 2 then 1.2 else 1.4 end) * public.world_xp_gap_mul(coalesce(n.min_level, r.min_level, c.level) - c.level)'
          || ' * (case when c.level <= 10 then 1.3 else 1 end) * (1 + public.world_gear_total(uid, ''expedition_xp_pct'') / 100.0)) else 0 end;'],
    array['and e.minutes >= 60 and (e.minutes >= 120 or random() < 0.5) then', 'and e.minutes >= 120 and (e.minutes >= 240 or random() < 0.5) then'],
    array['random() < (case depth_ when 2 then 0.08 else 0.15 end)', 'random() < (case depth_ when 2 then 0.04 else 0.08 end)']];
  i int;
begin
  if position('world_xp_gap_mul' in d) > 0 then return; end if;
  for i in 1 .. array_length(r, 1) loop
    if (length(d) - length(replace(d, r[i][1], ''))) / length(r[i][1]) <> 1 then raise exception '원정 귀환 고칠 자리 %', i; end if;
    d := replace(d, r[i][1], r[i][2]);
  end loop;
  execute d;
end $$;

-- ② 퀘스트(주 이야기 장면·보조 퀘스트)
--   · 대본은 표(world_quests·world_quest_steps·world_quest_npcs)에, 진행은 world_quest_progress(캐릭터×퀘스트)에 둔다. world_characters에는 열을 더하지 않는다.
--   · 장면마다 할 일(tasks)은 앞 장면을 보고한 뒤부터 world_events를 센다(world_quest_task_count). 행동 한 번의 쓰기를 늘리지 않는다.
--   · 보고(world_quest_report)할 때 할 일·장소(at)·넘길 물품(give)을 확인하고, 대사(lines)·보상을 한 번에 처리한다.
--   · 주 이야기(kind main, quest_id = 'mq_' || 장 id)는 장면을 다 보고해야 그 장 단서가 탐색에서 나온다(world_quest_main_open). 장은 지금처럼 가설 확정으로 끝나고, 그때 장 결말(epilogue)을 대화창으로 보인다.
create table if not exists public.world_quests (
  quest_id text primary key, kind text not null check (kind in ('main', 'side')), cat text not null, title text not null, summary text not null default '',
  region_id text not null, min_level int not null default 1, after text[] not null default '{}', chapter_id text, sort int not null default 0,
  epilogue jsonb not null default '[]'::jsonb, active boolean not null default true);
create table if not exists public.world_quest_steps (
  quest_id text not null references public.world_quests(quest_id) on delete cascade, step int not null check (step >= 1),
  title text not null, goal text not null default '', need jsonb not null default '{}'::jsonb, lines jsonb not null default '[]'::jsonb,
  reward jsonb not null default '{}'::jsonb, primary key (quest_id, step));
create table if not exists public.world_quest_npcs (npc_key text primary key, npc_name text not null, bio text not null default '');
create table if not exists public.world_quest_progress (
  owner_id uuid not null, quest_id text not null, step int not null default 0, started_at timestamptz not null default now(),
  step_started_at timestamptz not null default now(), done_at timestamptz, primary key (owner_id, quest_id));
do $$ declare t text; begin
  foreach t in array array['world_quests', 'world_quest_steps', 'world_quest_npcs', 'world_quest_progress'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select on public.%I to fn_owner_field', t);
  end loop;
end $$;
grant insert, update on public.world_quest_progress to fn_owner_field;

-- 주 이야기 장을 마쳤는가(가설을 모두 확정했는가)
create or replace function public.world_quest_chapter_done(p_uid uuid, p_chapter text)
returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select exists (select 1 from public.world_case_progress p where p.owner_id = p_uid and p.case_id = p_chapter
                  and (p.combined ? (p_chapter || '_completed') or (p_chapter = 'red_seal' and p.combined ? 'redseal_case_completed')))
$$;
-- 퀘스트를 마쳤는가(주 이야기는 장을 마쳤는가)
create or replace function public.world_quest_done(p_uid uuid, p_quest text)
returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when p_quest like 'mq\_%' then public.world_quest_chapter_done(p_uid, substr(p_quest, 4))
              else exists (select 1 from public.world_quest_progress g where g.owner_id = p_uid and g.quest_id = p_quest and g.done_at is not null) end
$$;
-- 주 이야기 장면을 다 보고해 그 장 단서가 열렸는가(장면이 없는 장은 늘 열림)
create or replace function public.world_quest_main_open(p_uid uuid, p_chapter text)
returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select coalesce(g.step, 0) >= (select count(*) from public.world_quest_steps s where s.quest_id = q.quest_id)
                     from public.world_quests q left join public.world_quest_progress g on g.quest_id = q.quest_id and g.owner_id = p_uid
                    where q.quest_id = 'mq_' || p_chapter and q.active), true)
$$;

-- 할 일 한 줄을 센다(세력 퀘스트 할 일에 특정 요괴·재료·제작품·제작 분야·낚시를 더함)
create or replace function public.world_quest_task_count(p_uid uuid, p_task jsonb, p_since timestamptz)
returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when p_task ->> 't' in ('win', 'gather', 'craft', 'fish') then (
    select count(*)::int from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since
       and e.event_type = case p_task ->> 't' when 'win' then 'combat' when 'gather' then 'gather' when 'craft' then 'craft' else 'fish' end
       and case p_task ->> 't'
             when 'win' then coalesce((e.payload ->> 'defeated')::boolean, false)
               and (not p_task ? 'm' or e.payload ->> 'monster_id' in (select jsonb_array_elements_text(p_task -> 'm')))
               and (not p_task ? 'r' or e.payload ->> 'region_id' in (select jsonb_array_elements_text(p_task -> 'r')))
               and (not p_task ? 'rank' or e.payload ->> 'rank' = p_task ->> 'rank')
             when 'gather' then (not p_task ? 'items' or e.payload ->> 'item_id' in (select jsonb_array_elements_text(p_task -> 'items')))
               and (not p_task ? 'r' or (select n.region_id from public.world_exploration_nodes n
                                          where n.node_id = case when e.payload ->> 'node_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (e.payload ->> 'node_id')::uuid end)
                                        in (select jsonb_array_elements_text(p_task -> 'r')))
             when 'craft' then (not p_task ? 'items' or e.payload ->> 'output' in (select jsonb_array_elements_text(p_task -> 'items')))
               and (not p_task ? 'field' or exists (select 1 from public.world_crafting_recipes cr where cr.recipe_id = e.payload ->> 'recipe' and cr.craft_field = p_task ->> 'field'))
             else coalesce((e.payload ->> 'caught')::boolean, false)
               and (not p_task ? 'r' or e.payload ->> 'region_id' in (select jsonb_array_elements_text(p_task -> 'r'))) end)
    else public.world_faction_task_count(p_uid, p_task, p_since) end
$$;

-- 할 일 한 줄의 화면 문구
create or replace function public.world_quest_task_label(p_task jsonb)
returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case
    when p_task ->> 't' = 'win' and p_task ? 'm' then
      (select string_agg(distinct m.monster_name, '·') from public.world_region_monsters m where m.monster_id in (select jsonb_array_elements_text(p_task -> 'm'))) || ' 쓰러뜨리기'
    when p_task ->> 't' = 'gather' then
      coalesce((select string_agg(x.region_name, '·') || '에서 ' from public.world_map_regions x where x.region_id in (select jsonb_array_elements_text(p_task -> 'r'))), '')
      || coalesce((select string_agg(i.item_name, '·') from public.world_item_catalog i where i.item_id in (select jsonb_array_elements_text(p_task -> 'items'))) || ' ', '') || '채집'
    when p_task ->> 't' = 'craft' then
      coalesce((select string_agg(i.item_name, '·') from public.world_item_catalog i where i.item_id in (select jsonb_array_elements_text(p_task -> 'items'))) || ' 만들기',
               case p_task ->> 'field' when 'smithing' then '단조' when 'carpentry' then '목공' when 'artifice' then '법구 공예' when 'sealing' then '봉인 공예'
                 when 'weaving' then '직조' when 'leatherwork' then '가죽 공예' when 'alchemy' then '연금' when 'cooking' then '요리' else '' end || ' 제작')
    when p_task ->> 't' = 'fish' then
      coalesce((select string_agg(x.region_name, '·') || '에서 ' from public.world_map_regions x where x.region_id in (select jsonb_array_elements_text(p_task -> 'r'))), '') || '물고기 낚아 올리기'
    else public.world_faction_task_label(p_task) end
$$;

-- 지금 할 장면의 상태(할 일 진행·넘길 물품·보고 장소)
create or replace function public.world_quest_step_state(p_uid uuid, p_quest text)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype; q public.world_quests%rowtype; g public.world_quest_progress%rowtype; s public.world_quest_steps%rowtype;
  t jsonb; tasks jsonb := '[]'::jsonb; gives jsonb := '[]'::jsonb; ready boolean := true; here_ok boolean := true; n int; k text; v int; have int; nsteps int; since timestamptz;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  select * into q from public.world_quests where quest_id = p_quest;
  select * into g from public.world_quest_progress where owner_id = p_uid and quest_id = p_quest;
  select count(*) into nsteps from public.world_quest_steps where quest_id = p_quest;
  select * into s from public.world_quest_steps where quest_id = p_quest and step = coalesce(g.step, 0) + 1;
  if s.quest_id is null then return null; end if;
  since := coalesce(g.step_started_at, now());
  for t in select * from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) loop
    -- 도착은 지금 그곳에 있으면 마친 것으로 본다(이미 와 있는데 다시 나갔다 오지 않게)
    n := case when g.owner_id is null then 0
              when t ->> 't' = 'travel' and exists (select 1 from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(t -> 'r')) and m.region_name = c.location) then (t ->> 'n')::int
              else least((t ->> 'n')::int, public.world_quest_task_count(p_uid, t, since)) end;
    if n < (t ->> 'n')::int then ready := false; end if;
    tasks := tasks || jsonb_build_object('label', public.world_quest_task_label(t), 'cur', n, 'n', (t ->> 'n')::int,
      'regions', coalesce(t -> 'r', '[]'::jsonb));
  end loop;
  for k, v in select key, value::int from jsonb_each_text(coalesce(s.need -> 'give', '{}'::jsonb)) loop
    have := coalesce((c.inventory ->> k)::int, 0);
    if have < v then ready := false; end if;
    gives := gives || jsonb_build_object('item_id', k, 'name', (select item_name from public.world_item_catalog where item_id = k), 'have', least(have, v), 'n', v);
  end loop;
  if s.need ? 'at' then
    here_ok := exists (select 1 from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(s.need -> 'at')) and m.region_name = c.location);
  end if;
  return jsonb_build_object('step', s.step, 'steps', nsteps, 'title', s.title, 'goal', s.goal, 'tasks', tasks, 'give', gives,
    'at', coalesce(s.need -> 'at', '[]'::jsonb),
    'at_names', (select jsonb_agg(m.region_name order by m.region_name) from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(coalesce(s.need -> 'at', '[]'::jsonb)))),
    'here_ok', here_ok, 'ready', ready and here_ok);
end $$;

-- 퀘스트 화면 한 번에: 진행 중(장면 상태)·받을 수 있는 것·여기서 할 수 있는 것
create or replace function public.world_quest_board()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; q record; st jsonb; act jsonb := '[]'::jsonb; avail jsonb := '[]'::jsonb;
  here_id text; ok boolean; a text; nsteps int; clues jsonb; ndone int := 0; ntotal int := 0; fac jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select region_id into here_id from public.world_map_regions where region_name = c.location limit 1;
  for q in select x.*, g.step gstep, g.done_at, g.owner_id has_prog, m.region_name
             from public.world_quests x left join public.world_quest_progress g on g.quest_id = x.quest_id and g.owner_id = uid
             left join public.world_map_regions m on m.region_id = x.region_id
            where x.active order by (x.kind = 'main') desc, x.min_level, x.sort, x.quest_id loop
    ntotal := ntotal + 1;
    if public.world_quest_done(uid, q.quest_id) then ndone := ndone + 1; continue; end if;
    select count(*) into nsteps from public.world_quest_steps where quest_id = q.quest_id;
    if q.has_prog is not null and coalesce(q.gstep, 0) >= 1 then
      if q.kind = 'main' and coalesce(q.gstep, 0) >= nsteps then
        -- 장면을 다 마친 주 이야기: 단서 찾기·가설 확정 단계
        select jsonb_build_object('found', count(*) filter (where exists (select 1 from public.world_case_progress p where p.owner_id = uid and p.case_id = k.chapter_id
                                     and p.clues @> jsonb_build_array(jsonb_build_object('id', k.clue_id)))), 'total', count(*),
                 'regions', jsonb_agg(distinct k.region_id), 'region_names', jsonb_agg(distinct (select region_name from public.world_map_regions where region_id = k.region_id)))
          into clues from public.world_story_clues k where k.chapter_id = q.chapter_id;
        act := act || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'clues', 'clues', clues,
          'step', nsteps, 'steps', nsteps);
      else
        st := public.world_quest_step_state(uid, q.quest_id);
        act := act || (jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'step') || coalesce(st, '{}'::jsonb) || jsonb_build_object('title', q.title, 'step_title', st ->> 'title'));
      end if;
    else
      ok := c.level >= q.min_level;
      foreach a in array q.after loop
        if not public.world_quest_done(uid, a) then ok := false; end if;
      end loop;
      -- 주 이야기는 앞 장을 마쳤으면 레벨이 모자라도 보인다(언제 열리는지 알려 준다)
      if ok or (q.kind = 'main' and not exists (select 1 from unnest(q.after) z where not public.world_quest_done(uid, z))) then
        st := public.world_quest_step_state(uid, q.quest_id);
        avail := avail || (jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary,
          'region_id', q.region_id, 'region_name', q.region_name, 'min_level', q.min_level, 'locked', not ok, 'here', q.region_id = here_id) || coalesce(st, '{}'::jsonb) || jsonb_build_object('title', q.title, 'step_title', st ->> 'title'));
      end if;
    end if;
  end loop;
  -- 세력 퀘스트(가입·등급)도 현장 퀘스트 칸에 함께 보인다. 열람만 하므로 등급 장면을 열지(쓰지) 않는다
  if c.major_faction_id is not null and exists (select 1 from public.world_faction_progress p where p.owner_id = uid and p.faction_id = c.major_faction_id and not p.rejoin_pending) then
    fac := public.world_faction_current(uid, false);
    if fac is not null then
      fac := fac || jsonb_build_object('faction_id', c.major_faction_id,
        'regions', (select coalesce(jsonb_agg(distinct x), '[]'::jsonb) from public.world_faction_scenes s,
                      lateral (select jsonb_array_elements_text(t -> 'r') x from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t
                               union select jsonb_array_elements_text(coalesce(s.need -> 'at', '[]'::jsonb))) z
                     where s.scene_key = fac ->> 'scene_key'));
    end if;
  end if;
  return jsonb_build_object('active', act, 'available', avail, 'faction', fac, 'done', ndone, 'total', ntotal, 'here_id', here_id, 'level', c.level);
end $$;

-- 보고: 할 일·장소·넘길 물품을 확인하고 대사와 보상을 돌려준다(첫 장면 보고 = 퀘스트 받기)
create or replace function public.world_quest_report(p_quest text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; q public.world_quests%rowtype; g public.world_quest_progress%rowtype;
  s public.world_quest_steps%rowtype; st jsonb; inv jsonb; lim int; k text; v int; msg text := ''; a text; nsteps int; spk text[]; is_done boolean := false;
  rw_gil int; rw_xp int; gained int := 0;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 보고할 수 없습니다.'; end if;
  select * into q from public.world_quests where quest_id = p_quest and active;
  if not found then raise exception '알 수 없는 퀘스트입니다.'; end if;
  if public.world_quest_done(uid, p_quest) then raise exception '이미 마친 퀘스트입니다.'; end if;
  select count(*) into nsteps from public.world_quest_steps where quest_id = p_quest;
  select * into g from public.world_quest_progress where owner_id = uid and quest_id = p_quest for update;
  if coalesce(g.step, 0) = 0 then
    if c.level < q.min_level then raise exception 'Lv%부터 받을 수 있습니다.', q.min_level; end if;
    foreach a in array q.after loop
      if not public.world_quest_done(uid, a) then raise exception '먼저 마쳐야 하는 퀘스트가 있습니다.'; end if;
    end loop;
  end if;
  if coalesce(g.step, 0) >= nsteps then raise exception '장면을 모두 마쳤습니다. 단서를 찾아 일지 › 사건에서 가설을 확정하세요.'; end if;
  st := public.world_quest_step_state(uid, p_quest);
  if not (st ->> 'here_ok')::boolean then raise exception '%에서 보고할 수 있습니다.', array_to_string(array(select jsonb_array_elements_text(st -> 'at_names')), '·'); end if;
  if not (st ->> 'ready')::boolean then raise exception '아직 할 일이 남았습니다.'; end if;
  select * into s from public.world_quest_steps where quest_id = p_quest and step = coalesce(g.step, 0) + 1;
  inv := coalesce(c.inventory, '{}'::jsonb);
  -- 넘길 물품: 잠근 물품·장착 중인 마지막 하나는 넘기지 않는다
  for k, v in select key, value::int from jsonb_each_text(coalesce(s.need -> 'give', '{}'::jsonb)) loop
    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = k) then raise exception '잠근 물품은 넘길 수 없습니다. 잠금을 푼 뒤 다시 보고하세요.'; end if;
    if coalesce((inv ->> k)::int, 0) - v < (select count(*) from public.world_character_equipment e where e.owner_id = uid and e.item_id = k) then
      raise exception '장착 중인 물품은 넘길 수 없습니다.'; end if;
    inv := public.world_inv_add(inv, k, -v);
    if (inv ->> k)::int <= 0 then inv := inv - k; end if;
    msg := msg || '넘김: ' || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || v || ' · ';
  end loop;
  -- 보상 물품: 가방에 들어가지 않으면 보고를 받지 않는다
  lim := public.world_bag_limit(uid);
  for k, v in select key, value::int from jsonb_each_text(coalesce(s.reward -> 'items', '{}'::jsonb)) loop
    if public.world_bag_room(inv, k, lim) < v then raise exception '가방 자리가 모자랍니다. 보상을 받을 자리를 비운 뒤 다시 보고하세요.'; end if;
    inv := public.world_inv_add(inv, k, v);
    msg := msg || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || v || ' · ';
  end loop;
  rw_gil := coalesce((s.reward ->> 'gil')::int, 0); rw_xp := coalesce((s.reward ->> 'xp')::int, 0);
  update public.world_characters set inventory = inv, gil = gil + rw_gil, updated_at = now() where owner_id = uid;
  if rw_gil > 0 then msg := msg || rw_gil || '전 · '; end if;
  if rw_xp > 0 then gained := public.world_grant_xp(uid, rw_xp); msg := msg || '경험치 ' || rw_xp || ' · '; end if;
  is_done := q.kind = 'side' and s.step >= nsteps;
  insert into public.world_quest_progress(owner_id, quest_id, step, started_at, step_started_at, done_at)
  values (uid, p_quest, s.step, now(), now(), case when is_done then now() end)
  on conflict (owner_id, quest_id) do update set step = excluded.step, step_started_at = now(), done_at = excluded.done_at;
  if is_done then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (uid, 'reward', '퀘스트 완료 · ' || q.title, '「' || q.title || '」' || public.world_josa(q.title, '을', '를') || ' 마쳤습니다.', jsonb_build_object('quest_id', p_quest));
  end if;
  select array_agg(distinct x ->> 's') into spk from jsonb_array_elements(s.lines) x where x ->> 's' is not null;
  return jsonb_build_object('quest_id', p_quest, 'quest_title', q.title, 'cat', q.cat, 'title', s.title, 'step', s.step, 'steps', nsteps, 'lines', s.lines,
    'done', is_done, 'clues_open', q.kind = 'main' and s.step >= nsteps, 'levels', gained,
    'reward', nullif(regexp_replace(msg, ' · $', ''), ''),
    'next', case when s.step < nsteps then (select jsonb_build_object('title', n.title, 'goal', n.goal) from public.world_quest_steps n where n.quest_id = p_quest and n.step = s.step + 1) end,
    'cast', public.world_quest_cast(spk, c.character_name));
end $$;

-- 대화창의 화자 이름(퀘스트 인물·세력 인물·조사원 본인)
create or replace function public.world_quest_cast(p_keys text[], p_me text)
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select jsonb_object_agg(z.k, z.j) from (
      select n.npc_key k, jsonb_build_object('name', n.npc_name, 'bio', n.bio) j from public.world_quest_npcs n where n.npc_key = any (p_keys)
      union all
      select f.npc_key, jsonb_build_object('name', f.npc_name, 'bio', f.bio) from public.world_faction_npcs f where f.npc_key = any (p_keys)) z), '{}'::jsonb)
    || case when 'me' = any (p_keys) then jsonb_build_object('me', jsonb_build_object('name', p_me, 'bio', '')) else '{}'::jsonb end
$$;

do $$ declare f text; begin
  foreach f in array array['world_quest_chapter_done(uuid,text)', 'world_quest_done(uuid,text)', 'world_quest_main_open(uuid,text)', 'world_quest_task_count(uuid,jsonb,timestamptz)',
                           'world_quest_task_label(jsonb)', 'world_quest_step_state(uuid,text)', 'world_quest_board()', 'world_quest_report(text)', 'world_quest_cast(text[],text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
  execute 'grant execute on function public.world_quest_board() to authenticated';
  execute 'grant execute on function public.world_quest_report(text) to authenticated';
end $$;

-- 탐색의 단서: 그 장 주 이야기 장면을 다 마쳐야 나온다
do $$ declare d text := pg_get_functiondef('public.world_field_search()'::regprocedure);
  a text := 'WHERE k.chapter_id = chap AND k.region_id = r.region_id AND c.level >= ch.min_level';
  b text := 'WHERE k.chapter_id = chap AND k.region_id = r.region_id AND c.level >= ch.min_level AND public.world_quest_main_open(uid, k.chapter_id)';
begin
  if position('world_quest_main_open' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '탐색 단서 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;
-- 사건 일지: 장마다 장면을 마쳤는지(단서가 열렸는지)
do $$ declare d text := pg_get_functiondef('public.world_story_board()'::regprocedure);
  a text := '''intro'', ch.intro, ''outro'', ch.outro,'; b text := '''intro'', ch.intro, ''outro'', ch.outro, ''scenes_open'', public.world_quest_main_open(uid, ch.chapter_id),';
begin
  if position('scenes_open' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '사건 일지 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;
-- 장을 마치면 주 이야기 퀘스트도 마침으로 적고, 장 결말 대사를 돌려준다
do $$ declare d text := pg_get_functiondef('public.world_story_combine(text)'::regprocedure);
  a1 text := 'msg := msg || '' — '' || ch.seq || ''장을 마쳤습니다! '' || coalesce(rw ->> ''text'', '''');';
  b1 text := 'msg := msg || '' — '' || ch.seq || ''장을 마쳤습니다! '' || coalesce(rw ->> ''text'', '''');'
    || E'\n    UPDATE public.world_quest_progress SET done_at = now() WHERE owner_id = uid AND quest_id = ''mq_'' || ch.chapter_id AND done_at IS NULL;';
  a2 text := 'RETURN jsonb_build_object(''ok'', true, ''content'', msg, ''chapter_done'', done_all);';
  b2 text := 'RETURN jsonb_build_object(''ok'', true, ''content'', msg, ''chapter_done'', done_all, ''epilogue'', CASE WHEN done_all THEN (SELECT jsonb_build_object(''title'', q.title, ''lines'', q.epilogue,'
    || ' ''cast'', public.world_quest_cast(ARRAY(SELECT DISTINCT x ->> ''s'' FROM jsonb_array_elements(q.epilogue) x WHERE x ->> ''s'' IS NOT NULL), c.character_name))'
    || ' FROM public.world_quests q WHERE q.quest_id = ''mq_'' || ch.chapter_id AND jsonb_array_length(q.epilogue) > 0) END);';
begin
  if position('world_quest_progress' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1 then raise exception '가설 확정 고칠 자리 1'; end if;
  if (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 then raise exception '가설 확정 고칠 자리 2'; end if;
  execute replace(replace(d, a1, b1), a2, b2);
end $$;

-- ③-1 지역 완전 답사: 답사도(찾은 장소·채집터)가 100%가 되어도 완전 답사 보상(가방 +1칸·창고 넓히기·다섯 곳이면 안개 사슴)은
--      원정에서 돌아올 때만 판정해서, 탐색으로 다 찾은 조사원은 받지 못했다. 장소·채집터를 찾을 때마다 판정한다(완전 답사일 때만 쓴다).
create or replace function public.world_survey_award(p_uid uuid, p_region text)
returns boolean language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare nm text; fully int;
begin
  if p_region is null or coalesce((public.world_field_survey(p_uid, p_region) ->> 'pct')::int, 0) < 100 then return false; end if;
  if exists (select 1 from public.world_region_progress g where g.owner_id = p_uid and g.region_id = p_region and 'complete' = any (g.milestones)) then return false; end if;
  insert into public.world_region_progress(owner_id, region_id, progress, milestones) values (p_uid, p_region, 100, array['complete'])
  on conflict (owner_id, region_id) do update set milestones = world_region_progress.milestones || array['complete'], progress = greatest(world_region_progress.progress, 100), updated_at = now();
  update public.world_characters set bag_capacity = least(400, bag_capacity + 1), updated_at = now() where owner_id = p_uid;
  select region_name into nm from public.world_map_regions where region_id = p_region;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_uid, 'reward', '완전 답사 · ' || nm, nm || '의 길과 채집터를 모두 찾았습니다. 가방 +1칸.', jsonb_build_object('region_id', p_region));
  select count(*) into fully from public.world_region_progress where owner_id = p_uid and 'complete' = any (milestones);
  if fully >= 5 then
    insert into public.world_owned_mounts(owner_id, mount_id) values (p_uid, 'mist_deer') on conflict do nothing;
    if found then
      insert into public.world_notifications(user_id, kind, title, content) values (p_uid, 'reward', '안개 사슴', '다섯 지역을 완전히 답사하자 안개 사슴이 따라왔습니다.');
    end if;
  end if;
  return true;
end $$;
create or replace function public.world_survey_award_trg()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  -- 두 표의 열이 달라 new의 열을 갈래마다 따로 읽는다
  if tg_table_name = 'world_gathering_discoveries' then
    perform public.world_survey_award(new.owner_id, (select n.region_id from public.world_gathering_spots s join public.world_exploration_nodes n on n.node_id = s.node_id where s.spot_id = new.spot_id));
  else
    perform public.world_survey_award(new.owner_id, (select n.region_id from public.world_exploration_nodes n where n.node_id = new.node_id));
  end if;
  return new;
end $$;
do $$ declare f text; begin
  foreach f in array array['world_survey_award(uuid,text)', 'world_survey_award_trg()'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
grant insert, update on public.world_region_progress to fn_owner_field;
grant insert on public.world_owned_mounts to fn_owner_field;
drop trigger if exists trg_world_survey_award on public.world_gathering_discoveries;
create trigger trg_world_survey_award after insert on public.world_gathering_discoveries for each row execute function public.world_survey_award_trg();
drop trigger if exists trg_world_survey_award on public.world_exploration_discoveries;
create trigger trg_world_survey_award after insert on public.world_exploration_discoveries for each row execute function public.world_survey_award_trg();

-- ③ 어귀 채집터: 지역 들머리(답사 첫 칸)에는 채집터가 하나도 없어, 길을 찾고 채집터를 발견하기 전에는 그 지역에서 채집할 수 없었다
--    (세력·퀘스트의 「○○에서 채집」이 0에서 멈춤). 바깥 지역마다 들머리에 채집터 하나를 두고 처음부터 찾은 것으로 한다.
insert into public.world_gathering_spots(node_id, spot_name, category, loot_items, min_level, yield_min, yield_max, difficulty, active)
select root.node_id, '어귀의 ' || src.spot_name, src.category, src.loot_items, r.min_level, 1, 2, 1, true
  from public.world_map_regions r
  join public.world_exploration_nodes root on root.region_id = r.region_id and root.hierarchy_level = 1
  cross join lateral (select gs.* from public.world_gathering_spots gs join public.world_exploration_nodes n on n.node_id = gs.node_id
                       where n.region_id = r.region_id and n.hierarchy_level = 2 and gs.active
                       order by gs.min_level, (gs.category in ('ore', 'herbs')) desc, gs.spot_name limit 1) src
 where not coalesce(r.is_safe_zone, false)
   and not exists (select 1 from public.world_gathering_spots x where x.node_id = root.node_id);
insert into public.world_gathering_discoveries(owner_id, spot_id)
select c.owner_id, gs.spot_id from public.world_characters c
  cross join public.world_gathering_spots gs join public.world_exploration_nodes n on n.node_id = gs.node_id and n.hierarchy_level = 1
on conflict do nothing;
do $$ declare x record; begin
  for x in select c.owner_id, r.region_id from public.world_characters c cross join public.world_map_regions r where not coalesce(r.is_safe_zone, false) loop
    perform public.world_survey_award(x.owner_id, x.region_id);
  end loop;
end $$;
create or replace function public.world_entry_spots_for_new()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  insert into public.world_gathering_discoveries(owner_id, spot_id)
  select new.owner_id, gs.spot_id from public.world_gathering_spots gs join public.world_exploration_nodes n on n.node_id = gs.node_id and n.hierarchy_level = 1
  on conflict do nothing;
  return new;
end $$;
alter function public.world_entry_spots_for_new() owner to fn_owner_field;
revoke all on function public.world_entry_spots_for_new() from public, anon, authenticated;
grant insert on public.world_gathering_discoveries to fn_owner_field;
drop trigger if exists trg_world_entry_spots on public.world_characters;
create trigger trg_world_entry_spots after insert on public.world_characters for each row execute function public.world_entry_spots_for_new();

-- ④ 퀘스트 대본
-- 퀘스트 대본(생성: scratchpad quest/gen/build.py)
insert into public.world_quest_npcs(npc_key, npc_name, bio) values
  ($q$q:bl_banseok$q$, $q$흑련회 채굴 감독 반석$q$, $q$지맥의 뿌리 갱을 맡은 흑련회 감독. 흙냄새로 영핵의 결을 맞힌다.$q$),
  ($q$q:bl_chaeun$q$, $q$밀수선 선장 채운$q$, $q$흑련회 물건을 나르던 밀수선의 선장. 배와 선원을 균열에 잃고 홀로 살아 나왔다.$q$),
  ($q$q:bl_damu$q$, $q$늙은 내관 담무$q$, $q$망국이 무너진 뒤에도 고도를 떠나지 않은 내관. 허리가 굽었으나 예법은 그대로다.$q$),
  ($q$q:bl_eodu$q$, $q$심연 낚시꾼 어두$q$, $q$흑조 균열 끝에서 날마다 낚싯줄을 드리우는 늙은이. 물고기는 거의 놓아준다.$q$),
  ($q$q:bl_eungyeol$q$, $q$수맥 지기 은결$q$, $q$지하 물길을 돌보는 흑련회 사람. 물소리만 듣고 길을 찾는다.$q$),
  ($q$q:bl_galhyeon$q$, $q$늙은 관측생 갈현$q$, $q$백옥 천문탑 맨 아래층에서 마흔 해 동안 한 번도 자지 않고 별을 기록한 노인.$q$),
  ($q$q:bl_hwagang$q$, $q$상여꾼 화강$q$, $q$만인장에서 서른 해 상여를 멘 사내. 상엿소리를 낮게 흥얼거린다.$q$),
  ($q$q:bl_jaeum$q$, $q$봉연 파수꾼 윤재음$q$, $q$마지막 문이 닫힌 뒤 봉연에 남겨진 본부 파수꾼. 사슬 소리로 밤을 센다.$q$),
  ($q$q:bl_unhae$q$, $q$관상감 수직 운해$q$, $q$무극 관성대의 문을 지키는 젊은 수직. 옛 태사령의 이야기를 외워 두었다.$q$),
  ($q$q:bl_yeohwi$q$, $q$망국 사관 여휘$q$, $q$무명 고도에 남아 사라진 이름을 받아 적는 사관. 붓끝이 늘 떨린다.$q$),
  ($q$q:bl_yeonok$q$, $q$비석 닦는 아이 연옥$q$, $q$만인장의 비석을 날마다 닦는 작은 아이. 누구의 아이인지 아무도 모른다.$q$),
  ($q$q:dh_bokrye$q$, $q$객사 찬모 복례$q$, $q$객사 부엌을 삼십 년 지킨 찬모. 잔소리가 곧 정이다.$q$),
  ($q$q:dh_bomi$q$, $q$학 접는 아이 보미$q$, $q$백지교 난간에 앉아 종이학을 접는 아이. 어디서 왔는지 말하지 않는다.$q$),
  ($q$q:dh_cheol$q$, $q$객사지기 노철$q$, $q$객사 장부를 맡은 늙은 지기. 손님 얼굴은 잊어도 신발은 기억한다.$q$),
  ($q$q:dh_cheongun$q$, $q$나무꾼 하청운$q$, $q$귀죽림에서 대나무를 베는 젊은 나무꾼. 동생을 숲에서 잃었다.$q$),
  ($q$q:dh_daegeun$q$, $q$성문 노병 탁대근$q$, $q$서문 수비대의 마지막 생존자. 한쪽 다리를 절며 매일 성벽에 오른다.$q$),
  ($q$q:dh_gaetong$q$, $q$물길잡이 개똥이$q$, $q$구시가지 물길을 손바닥처럼 아는 소년. 배 대신 대야를 탄다.$q$),
  ($q$q:dh_gaeul$q$, $q$사당지기 혼백 가을$q$, $q$폐쇄 사당을 떠나지 못한 어린 무녀의 혼백. 방울 소리를 그리워한다.$q$),
  ($q$q:dh_gopun$q$, $q$약방 할멈 고분$q$, $q$백등 야시장 구석에서 차와 환약을 파는 노파. 외상을 잘 준다.$q$),
  ($q$q:dh_gwak$q$, $q$농부 곽만석$q$, $q$잿빛 들녘에서 삼대째 농사를 짓는 무뚝뚝한 농부.$q$),
  ($q$q:dh_ilsu$q$, $q$등롱 장인 마일수$q$, $q$백등 야시장의 등을 모두 만든 장인. 등 하나마다 이름을 붙인다.$q$),
  ($q$q:dh_munsu$q$, $q$정청 서리 문수$q$, $q$정청의 잔심부름을 도맡는 서리. 늘 무언가를 들고 뛴다.$q$),
  ($q$q:dh_seonhwa$q$, $q$약초꾼 남선화$q$, $q$연화원이 봉인되기 전 정원 약초밭을 돌보던 여인. 지금은 담 밖에서만 산다.$q$),
  ($q$q:dh_sora$q$, $q$궁수 위소라$q$, $q$연무장 활터를 맡은 여궁수. 말수가 적고 과녁만 본다.$q$),
  ($q$q:dh_suchil$q$, $q$수문지기 염수칠$q$, $q$구룡 폐수로의 녹슨 수문을 혼자 지키는 노인. 수문이 닫힌 걸 모른다.$q$),
  ($q$q:dh_wolsun$q$, $q$옛 관아 아전 홍월순$q$, $q$구시가지가 잠기기 전 관아 장부를 맡았던 아전. 물이 빠지길 기다린다.$q$),
  ($q$q:dh_yeonok$q$, $q$순찰 의원 연옥이$q$, $q$들녘 순찰조를 따라다니는 젊은 의원. 손이 빠르고 걱정이 많다.$q$),
  ($q$q:dh_yunpal$q$, $q$떠돌이 약사 육윤팔$q$, $q$독이라면 모르는 게 없다고 큰소리치는 떠돌이 약사. 실제로 꽤 안다.$q$),
  ($q$q:m_baekmu$q$, $q$말뚝지기 백무$q$, $q$옥문 협로 잔도의 쇠말뚝을 예순 해 지켜 온 늙은 맹약자.$q$),
  ($q$q:m_dohwa$q$, $q$등대지기 도화$q$, $q$구등대 군도에 홀로 남아 불을 지키는 마지막 등대지기$q$),
  ($q$q:m_gaon$q$, $q$늙은 거북 가온$q$, $q$용잠 수궁의 문을 천 년 지켜 온, 말을 하는 늙은 거북$q$),
  ($q$q:m_sawol$q$, $q$무녀 사월$q$, $q$적월교를 떠난 젊은 무녀. 서약의 실상을 알고 있다.$q$),
  ($q$q:m_yeon$q$, $q$사건 서기관 연서희$q$, $q$정청에서 조사원을 맡는 담당 서기관. 침착하고 다정하지만 일에는 단호하다.$q$),
  ($q$q:m_yun$q$, $q$출납관 윤도한$q$, $q$정청 장부를 맡은 성실하고 친절한 출납관. 장부와 물길, 뱃삯을 이상하리만치 잘 안다.$q$),
  ($q$q:rn_beongae$q$, $q$벼락 줍는 이 번개$q$, $q$벼락이 떨어진 자리를 쫓아다니는 수집꾼. 세 번 맞고도 살아서 이름이 바뀌었다$q$),
  ($q$q:rn_chadol$q$, $q$주사 광부 차돌$q$, $q$황무지에서 주사를 캐 교령에 대던 광부. 지금은 손을 씻으려 한다$q$),
  ($q$q:rn_cheolbu$q$, $q$관문 대장장이 철부$q$, $q$회산 관문에서 북령맹 무구를 두드리는 대장장이. 말보다 망치가 빠르다$q$),
  ($q$q:rn_chorong$q$, $q$호송대 막내 초롱$q$, $q$여운비 호송대의 막내. 등불을 드는 일을 맡았지만 어둠을 무서워한다$q$),
  ($q$q:rn_dalgu$q$, $q$상단 호위 달구$q$, $q$백골 장터를 드나드는 상단의 호위. 활 솜씨는 좋은데 셈이 어둡다$q$),
  ($q$q:rn_doyun$q$, $q$어린 행자 도윤$q$, $q$철벽 고찰의 막내 행자. 수좌의 심부름으로 잔도를 오가다 길을 잃었다$q$),
  ($q$q:rn_eunsil$q$, $q$월식성 약방 노파 은실$q$, $q$월식성 뒤뜰 약방을 지키는 노파. 교리보다 탕약을 믿는다$q$),
  ($q$q:rn_gangpa$q$, $q$북령 척후 강파$q$, $q$뇌명봉을 오르내리는 북령맹 척후. 바위처럼 말이 없고 발이 빠르다$q$),
  ($q$q:rn_gobun$q$, $q$뼈 감정사 고분$q$, $q$백골 장터에서 뼈의 나이와 주인을 읽는 노파. 눈이 어둡지만 손끝은 밝다$q$),
  ($q$q:rn_haerang$q$, $q$유리장이 해랑$q$, $q$유리협곡 바람 소리를 들으며 유리를 굽는 여인. 쌍둥이 동생을 협곡에서 잃었다$q$),
  ($q$q:rn_jeongsim$q$, $q$깃발지기 정심$q$, $q$철벽 고찰 산문의 기도 깃발을 지키는 비구니. 바람의 방향으로 손님을 맞는다$q$),
  ($q$q:rn_mukhyang$q$, $q$순찰 교도 묵향$q$, $q$폐단 둘레를 도는 적월교 하급 교도. 기도 소리가 무서워 밤마다 귀를 막는다$q$),
  ($q$q:rn_sahwan$q$, $q$이름 없는 사환$q$, $q$흑사단 폐단에서 심부름하던 아이. 바쳐진 명부에서 혼자 빠졌다$q$),
  ($q$q:rn_sapyeong$q$, $q$사막 길잡이 사평$q$, $q$적사 황무지에서 삼십 년 길을 잡은 사내. 모래 소리로 날씨를 안다$q$),
  ($q$q:rn_seolbaek$q$, $q$인장 파수 설백$q$, $q$빙혼곡 얼음 인장 아래를 지키는 북령맹 파수. 종소리를 들은 뒤로 말을 아낀다$q$),
  ($q$q:rn_takmu$q$, $q$월식성 문지기 탁무$q$, $q$월식성 바깥 문을 지키는 무사. 대호법의 명이 아니면 입을 열지 않는다$q$),
  ($q$q:rn_yunga$q$, $q$낚시꾼 윤가$q$, $q$천경호에서 사십 년 낚싯대를 드리운 노인. 하늘이 물에 비칠 때만 줄을 던진다$q$),
  ($q$q:sn_bokrye$q$, $q$부엌 어멈 복례$q$, $q$잔불촌 공동 부엌을 맡은 어멈. 망국 때부터 지킨 불씨를 꺼뜨린 적이 없다.$q$),
  ($q$q:sn_bonggu$q$, $q$연밭지기 봉구$q$, $q$연수의 아버지. 삼십 년 연밭을 지켰고, 흉년을 한 번도 겪지 않았다.$q$),
  ($q$q:sn_byeolsun$q$, $q$등대지기의 딸 별순$q$, $q$구등대 군도 끝섬에 사는 소녀. 사라진 아버지 대신 등대 계단을 오른다.$q$),
  ($q$q:sn_cheongpa$q$, $q$연맹 잠수꾼 청파$q$, $q$수향연맹에서 가장 숨이 긴 잠수꾼. 동생 흑파와 늘 짝을 지어 잠수했다.$q$),
  ($q$q:sn_dalrae$q$, $q$나루 주모 달래$q$, $q$구름나루 주막을 홀로 꾸리는 주모. 웃음이 헤프고 눈치가 빠르다.$q$),
  ($q$q:sn_deokman$q$, $q$갯마을 어부 덕만$q$, $q$재의 해안에 남은 마지막 어부. 말수가 적고 손이 빠르다.$q$),
  ($q$q:sn_eungyeol$q$, $q$누각 화공 은결$q$, $q$수경루에 머무는 늙은 화공. 붓을 쥐면 손떨림이 멎는다.$q$),
  ($q$q:sn_hwaok$q$, $q$혈엽림 약초꾼 화옥$q$, $q$혈엽림 깊은 곳까지 다니는 여인 약초꾼. 제 사정은 늘 남의 이야기처럼 한다.$q$),
  ($q$q:sn_maenggu$q$, $q$광부 반장 맹구$q$, $q$주혈 광산 붕괴에서 살아남은 광부 반장. 그날 이야기를 꺼내지 않는다.$q$),
  ($q$q:sn_manseok$q$, $q$약방 영감 만석$q$, $q$염등촌 하나뿐인 약방을 지키는 노인. 남의 손은 살피고 제 손은 감춘다.$q$),
  ($q$q:sn_okbun$q$, $q$염전 일꾼 옥분$q$, $q$염등촌 염전에서 소금을 긁는 처녀. 말끝을 흐리는 버릇이 있다.$q$),
  ($q$q:sn_soebul$q$, $q$잔불촌 대장장이 쇠불$q$, $q$잔불촌 대장간의 젊은 대장장이. 장무현을 아버지처럼 따른다.$q$),
  ($q$q:sn_yeonsu$q$, $q$연밭 처녀 연수$q$, $q$천엽 연화늪 가에서 연밥을 따는 처녀. 겁이 많지만 물러서지 않는다.$q$)
on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue) values
  ($q$mq_red_seal$q$, $q$main$q$, $q$이야기$q$, $q$붉은 인장의 실종$q$, $q$장부의 부적 기록과 정청 금고의 붉은 인장이 사라졌다$q$, $q$hq_yard$q$, 1, array[]::text[], $q$red_seal$q$, 0, $q$[{"s": null, "t": "단서를 맞춘 일지를 연서희가 한참 들여다본다."}, {"s": "q:m_yeon", "t": "정리할게요. 누군가 붉은 인장을 들고 사당에서 봉인식을 거꾸로 돌렸어요. 봉인을 건 게 아니라 푼 거예요."}, {"s": "q:m_yeon", "t": "그리고 그 사람이 쓴 먹물에서 물비린내가 나요. 서고에서도, 사당에서도."}, {"s": "night_office:mo", "t": "먹에 물 섞는 데야 많죠. 그런데 이건 고인 물 냄새예요. 오래된 수로 바닥 같은."}, {"s": "q:m_yun", "t": "구룡 폐수로겠지요. 그 물은 녹이 섞여서 먹이 푸르스름하게 번집니다."}, {"s": "q:m_yeon", "t": "그런 것까지 알아요?"}, {"s": "q:m_yun", "t": "출납을 오래 하다 보면 이것저것 주워듣게 됩니다."}, {"s": "night_office:han", "t": "사라진 쪽은 아직 어딘가에 있습니다. 젖은 채로."}, {"s": "q:m_yeon", "t": "좋아요. 다음은 물길이에요. 조금 더 단련하고 오면, 그때 함께 따라가 봐요."}]$q$::jsonb),
  ($q$mq_drowned_ledger$q$, $q$main$q$, $q$이야기$q$, $q$물 밑의 장부$q$, $q$젖은 장부 쪽이 물길을 거슬러 서쪽으로 흘러간다$q$, $q$hq_yard$q$, 5, array[$q$mq_red_seal$q$]::text[], $q$drowned_ledger$q$, 1, $q$[{"s": null, "t": "단서 넷이 하나의 물길로 이어진다. 폐수로에서 강으로, 소금 마을을 지나 서쪽 성벽까지."}, {"s": "q:m_yeon", "t": "장부는 팔려 간 거예요. 산 사람은 붉은 달 인장을 쓰는 자들, 적월교."}, {"s": "q:m_yeon", "t": "그들이 원한 건 부적 수량이 아니었어요. 지워진 칸 옆에 적힌 이름들이었죠."}, {"s": "q:m_yun", "t": "봉인 부적을 받아 간 사람들 이름입니다. 대개 오래전에 죽었거나 행방이 끊긴 이들이지요."}, {"s": "q:m_yeon", "t": "죽은 사람 이름을 왜 사 가요?"}, {"s": "q:m_yun", "t": "값이 있으니 사 갔겠지요. 장부에서는 모든 게 값이 있습니다."}, {"s": null, "t": "윤도한이 웃는다. 연서희는 웃지 않는다."}, {"s": "q:m_yeon", "t": "적월 교령으로 가야겠어요. 백골 장터라면 정청 사람도 드나들 수 있어요. 준비되면 말해요."}]$q$::jsonb),
  ($q$mq_red_moon_oath$q$, $q$main$q$, $q$이야기$q$, $q$적월의 서약$q$, $q$적월교가 사들인 이름들이 어디에 쓰이는지 쫓는다$q$, $q$hq_yard$q$, 8, array[$q$mq_drowned_ledger$q$]::text[], $q$red_moon_oath$q$, 2, $q$[{"s": null, "t": "정청 뒷방. 사월이 이불을 두른 채 단서를 맞춘 일지를 들여다본다."}, {"s": "q:m_yeon", "t": "서약은 황무지에서 시작해 유리협곡을 지나 회산 관문으로 올라가요. 끝은 북쪽 설산이고요."}, {"s": "q:m_sawol", "t": "마지막 축문이 기억나요. 「빙인을 녹여라.」 얼음 인장을 녹이라는 뜻이에요."}, {"s": "night_office:han", "t": "북령맹이 지키는 얼음 인장입니다. 그것이 녹으면 맹약 자체가 깨집니다."}, {"s": "q:m_sawol", "t": "그 아래 뭐가 있는지는 저도 몰라요. 아는 사람은 교주님뿐이에요."}, {"s": "q:m_yun", "t": "북령맹이라면 호송대장 여운비가 길을 잘 압니다. 철벽 고찰로 전갈을 넣어 두지요."}, {"s": "q:m_yeon", "t": "고마워요, 윤 출납관. 사월, 당분간 객사에 있어요. 여긴 안전해요."}, {"s": "q:m_sawol", "t": "정청은 이름을 지키는 법을 알아요?"}, {"s": null, "t": "아무도 대답하지 않는다."}]$q$::jsonb),
  ($q$mq_frost_seal$q$, $q$main$q$, $q$이야기$q$, $q$북령의 얼음 인장$q$, $q$녹아 가는 얼음 인장 아래에서 무언가 숨을 쉰다$q$, $q$hq_yard$q$, 12, array[$q$mq_red_moon_oath$q$]::text[], $q$frost_seal$q$, 3, $q$[{"s": null, "t": "철벽 고찰 화롯가. 연서희가 직접 북쪽까지 올라왔다. 단서를 맞추자 얼음 인장의 생김새가 드러난다. 인장이 아니었다. 엎어 둔 종의 뚜껑이었다."}, {"s": "q:m_yeon", "t": "얼음 아래 잠든 건 종이에요. 이름 없는 종. 그런데 숨을 쉬어요. 살아 있는 것처럼."}, {"s": "north_league:seok", "t": "그딴 걸 우리 조상들이 깔고 앉아 있었단 말이냐."}, {"s": "q:m_baekmu", "t": "깔고 앉은 게 아니라 눌러 둔 거다, 맹주. 맹약 첫 줄에 있어. 「종을 울리지 마라. 짝이 깬다.」"}, {"s": "me", "t": "짝이라니요."}, {"s": "q:m_baekmu", "t": "북쪽 종이 있으면 남쪽 종도 있지. 한 쌍이니까."}, {"s": "q:m_yun", "t": "남쪽이라면 남명 망국령이겠군요. 잔불촌의 소이 무녀가 옛 노래를 많이 압니다."}, {"s": null, "t": "휴가 중이라던 윤도한이 어느새 고찰 문간에 서 있다. 지나는 길에 들렀다고 했다. 언제 왔는지 본 사람은 없다."}, {"s": "q:m_yeon", "t": "언제 왔어요? 좋아요. 남쪽으로 가요."}]$q$::jsonb),
  ($q$mq_nameless_bell$q$, $q$main$q$, $q$이야기$q$, $q$이름 없는 종$q$, $q$울린 자의 이름을 앗아 가는 종이 땅 밑으로 끌려갔다$q$, $q$hq_yard$q$, 15, array[$q$mq_frost_seal$q$]::text[], $q$nameless_bell$q$, 4, $q$[{"s": null, "t": "정청 뒷방. 맞춰 놓은 단서 위로 등잔 그림자가 흔들린다."}, {"s": "q:m_yeon", "t": "종을 울린 자는 이름을 잃어요. 들은 것들도 이름이 흐려지고요. 그 종이 지금 구중 봉연 첫 문 앞에 있어요."}, {"s": "night_office:han", "t": "적월교는 지워진 이름을 바쳐 문을 열려 하고, 흑련회는 종 자체를 노립니다. 둘이 같은 곳을 보고 있습니다."}, {"s": "night_office:mo", "t": "구중 봉연이라니. 기록에서도 그 이름은 함부로 안 써요. 아홉 겹으로 봉한 연못이라던데."}, {"s": "q:m_yeon", "t": "윤 출납관, 흑련회 회주에 대한 기록 있어요?"}, {"s": null, "t": "대답이 없다. 한 번 더 부르자 그제야 고개를 든다."}, {"s": "q:m_yun", "t": "없습니다. 이름 없는 사람의 기록은 남지 않으니까요."}, {"s": "q:m_yeon", "t": "그렇겠죠. 적월교가 먼저 움직일 거예요. 다음 월식이 오기 전에 준비해 둬요."}, {"s": null, "t": "창밖 아주 먼 곳에서 종소리 같은 것이 한 번 울렸다. 누구의 이름이 지워졌는지는 아무도 몰랐다."}]$q$::jsonb),
  ($q$mq_eclipse_gate$q$, $q$main$q$, $q$이야기$q$, $q$월식의 문$q$, $q$적월교가 흑사단의 이름을 바쳐 두 번째 문을 열려 한다.$q$, $q$bone_market$q$, 18, array[$q$mq_nameless_bell$q$]::text[], $q$eclipse_gate$q$, 5, $q$[{"s": null, "t": "맞춘 단서들이 한 줄로 이어진다. 흑사단의 이름, 월식의 실, 벼락의 메아리."}, {"s": "q:m_yeon", "t": "두 번째 문은 이미 열렸어요. 막지는 못했지만, 어디로 가는지는 알았습니다."}, {"s": "q:m_sawol", "t": "메아리가 아래로, 물 쪽으로 흘렀어요. 다음 문은 물 밑이에요."}, {"s": "q:m_yeon", "t": "수향 뱃길이군요. 젖은 장부가 흘러갔던 바로 그 물길이요."}, {"s": "q:m_yun", "t": "수향 연맹 쪽 장부라면 제가 먼저 맞춰 보겠습니다. 뱃삯 기록에 뭔가 남아 있을지도 모르죠."}, {"s": "q:m_sawol", "t": "저는 여기 남을게요. 성에 남은 아이들 중에 아직 제 이름을 지킬 수 있는 아이들이 있어요."}, {"s": null, "t": "사월이 붉은 실 한 가닥을 조사원의 손목에 감아 준다. 일곱 번."}, {"s": "q:m_yeon", "t": "구름나루로 가요. 물이 무언가를 기억하고 있을 거예요."}]$q$::jsonb),
  ($q$mq_sunken_lantern$q$, $q$main$q$, $q$이야기$q$, $q$물 밑의 등불$q$, $q$세 번째 문은 용왕의 역린으로 잠겼다. 열쇠는 노래다.$q$, $q$river_ferry$q$, 21, array[$q$mq_eclipse_gate$q$]::text[], $q$sunken_lantern$q$, 6, $q$[{"s": null, "t": "단서가 맞물린다. 노래는 남쪽 바다의 등대 불빛을 타고 물길로 흘러들었다."}, {"s": "q:m_gaon", "t": "세 번째 문은 결국 열리겠지. 나 혼자서는 비늘을 붙잡아 둘 수 없다."}, {"s": "q:m_yeon", "t": "그럼 같이 가요. 문 앞에서 기다리는 것보다, 문을 연 사람을 찾는 게 빨라요."}, {"s": "q:m_gaon", "t": "…천 년을 한자리에 있었다. 등딱지가 굳어서 걸을 수나 있을지."}, {"s": "me", "t": "길은 내가 안다."}, {"s": "q:m_gaon", "t": "허허. 불을 들고 온 사람이니 따라가 볼 만하겠지. 내 등에 타게. 물길이라면 아직 누구보다 빠르다."}, {"s": null, "t": "가온의 등딱지에 연꽃 무늬가 피어난다. 늙은 거북이 천 년 만에 수궁 밖으로 헤엄쳐 나온다."}, {"s": "river_alliance:nodeul", "t": "살다 보니 용궁 거북 등에 탄 사람을 다 보네. 남쪽 바다까지 몸조심하게."}, {"s": "q:m_yun", "t": "남쪽이면 남명 망국령이군요. 잔불촌 쪽 보급은 제가 미리 장부를 잡아 두겠습니다."}, {"s": "q:m_yeon", "t": "아홉 등대가 서 있는 바다로 가요."}]$q$::jsonb),
  ($q$mq_ash_sea$q$, $q$main$q$, $q$이야기$q$, $q$재의 바다$q$, $q$아홉 등대가 하나씩 꺼진다. 명령서에는 정청의 인장이 있다.$q$, $q$ember_village$q$, 24, array[$q$mq_sunken_lantern$q$]::text[], $q$ash_sea$q$, 7, $q$[{"s": null, "t": "단서가 이어진다. 등대 기름을 빼돌린 배, 망국 백성의 이름, 그리고 명령서가 지나온 길."}, {"s": "q:m_yeon", "t": "명령서는 정청 문서함을 거쳐 나갔어요. 위조든 아니든, 정청 안에서 찍혔어요."}, {"s": "southern_remnant:jang", "t": "등잔 밑이 어둡다는 말이 있소. 바깥만 보지 마시오."}, {"s": "q:m_dohwa", "t": "꺼진 등대 여섯은 다시 켤 수 없어요. 문이 이미 열렸으니까. 하지만 이 불은 안 꺼져요."}, {"s": null, "t": "도화가 등대 불씨를 작은 등롱 노리개에 옮겨 담아 조사원의 손에 쥐여 준다."}, {"s": "q:m_dohwa", "t": "할머니가 물려준 불이에요. 어두운 데 가실 거잖아요. 가장 어두운 데로요."}, {"s": "q:m_yun", "t": "정청으로 돌아가시지요. 문서함 기록은 제가 미리 정리해 두겠습니다. 다들 고생 많으셨습니다."}, {"s": "q:m_yeon", "t": "…네. 돌아가요. 본부로."}, {"s": null, "t": "돌아가는 배 위에서, 윤도한은 한 번도 바다를 돌아보지 않았다."}]$q$::jsonb),
  ($q$mq_lamp_shadow$q$, $q$main$q$, $q$이야기$q$, $q$등잔 밑$q$, $q$흑련회의 뿌리는 본부 안에 있었다. 등잔 밑을 비춘다.$q$, $q$hq_yard$q$, 27, array[$q$mq_ash_sea$q$]::text[], $q$lamp_shadow$q$, 8, $q$[{"s": null, "t": "네 곳의 단서가 하나로 모인다. 장부를 적신 들녘의 물, 백지교에 띄운 명부, 연화원의 돌계단, 귀죽림에 묻어 둔 등."}, {"s": "night_office:mo", "t": "연화원 계단은 지맥의 뿌리로 이어져요. 그 아래는 흑조 균열, 그리고… 구중 봉연."}, {"s": "night_office:han", "t": "그는 정청 인장을 쓰고 붉은 인장을 가져갔다. 봉연의 마지막 문은 붉은 인장으로만 잠긴다. 그것으로 문을 열 수도, 닫을 수도 있다는 뜻이다."}, {"s": "night_office:baek", "t": "길은 별이 안다. 무극 관성대로 가라. 천명원에 서신을 보내 두었다."}, {"s": "q:m_yeon", "t": "출납 장부 맨 뒷장에 한 줄이 더 있었어요. 「구중 봉연, 아홉째 문 앞에서 기다리겠습니다.」"}, {"s": "q:m_yeon", "t": "기다린다면 가 줘야죠. 그리고 데려와야죠. 인장이든, 사람이든."}, {"s": null, "t": "연서희가 장부를 덮는다. 손은 더 이상 떨리지 않는다."}]$q$::jsonb),
  ($q$mq_nine_gates$q$, $q$main$q$, $q$이야기$q$, $q$구중 봉연$q$, $q$붉은 인장을 되찾아 구중 봉연의 마지막 문을 닫는다.$q$, $q$star_observatory$q$, 30, array[$q$mq_lamp_shadow$q$]::text[], $q$nine_gates$q$, 9, $q$[{"s": null, "t": "네 곳의 단서가 맞물리자 문 앞 바닥에 아홉 겹 봉인식이 떠오른다. 처음 그 밤, 누군가 거꾸로 돌렸던 바로 그 식이다."}, {"s": "q:m_yun", "t": "맞습니다. 그게 닫는 법이에요. 열 때와 똑같이, 반대로."}, {"s": null, "t": "윤도한이 품에서 붉은 인장을 꺼낸다. 인장은 그의 손에서 빛나지 않는다."}, {"s": "q:m_yun", "t": "인장은 서희 씨가 찍으세요. 저는 문 안쪽에서 빗장을 잡겠습니다. 바깥에서만 잠그면 저것들이 다시 밀고 나올 테니까요."}, {"s": "q:m_yeon", "t": "안 돼요. 같이 나가요. 장부에 출납관님 이름 다시 적을게요. 제 손으로요."}, {"s": "q:m_yun", "t": "그럼 적어 주세요. 윤도한. 그 이름이면 충분합니다. 무명은 여기 두고 가지요."}, {"s": null, "t": "연서희가 울면서 인장을 찍는다. 붉은 빛이 아홉 문을 차례로 건너가고, 마지막 문이 소리 없이 닫힌다. 문 안쪽에서 등불 하나가 끝까지 흔들린다."}, {"s": null, "t": "정청. 붉은 인장이 제자리에 돌아오자 비로소 빛난다. 도제조 백운서가 장부에 붓을 든다."}, {"s": "night_office:baek", "t": "출납관 윤도한. 구중 봉연, 아홉째 문 안쪽 근무. …지운 자리 없이 적어라."}, {"s": "q:m_yeon", "t": "네. 또박또박, 끝까지 눌러서요."}, {"s": null, "t": "그 시각, 봉연 가장 깊은 곳. 닫힌 문 아래 어둠 속에서 구중 봉주가 천천히 숨을 고르고 있다."}, {"s": null, "t": "숨을 들이쉴 때마다 사슬이 한 번씩 운다. 사흘에 한 번, 혹은 나흘에 한 번. 문은 다시 흔들릴 것이다."}]$q$::jsonb),
  ($q$sq_field_outskirts_1$q$, $q$side$q$, $q$전투$q$, $q$이삭 도깨비의 품삯$q$, $q$볏단을 훔쳐 가는 도깨비들, 그 끝에 놓인 작은 무덤.$q$, $q$field_outskirts$q$, 1, array[]::text[], null, 10, $q$[]$q$::jsonb),
  ($q$sq_field_outskirts_2$q$, $q$side$q$, $q$채집·약초$q$, $q$순찰길 구급 바구니$q$, $q$들녘을 도는 순찰 의원의 빈 약바구니를 채운다.$q$, $q$field_outskirts$q$, 1, array[]::text[], null, 11, $q$[]$q$::jsonb),
  ($q$sq_hq_dorm_1$q$, $q$side$q$, $q$제작·요리$q$, $q$야간 당번의 도시락$q$, $q$객사 숙직자들을 위해 노정 건량을 마련한다.$q$, $q$hq_dorm$q$, 1, array[]::text[], null, 12, $q$[]$q$::jsonb),
  ($q$sq_hq_dorm_2$q$, $q$side$q$, $q$조사$q$, $q$열두 번째 방의 손님$q$, $q$붉은 인장이 사라진 밤, 객사를 먼저 떠난 손님의 흔적.$q$, $q$hq_dorm$q$, 2, array[$q$mq_red_seal$q$]::text[], null, 13, $q$[]$q$::jsonb),
  ($q$sq_hq_training_1$q$, $q$side$q$, $q$전투$q$, $q$목인을 다시 세워라$q$, $q$밤마다 제멋대로 움직이는 목인들, 교관의 숙제.$q$, $q$hq_training$q$, 1, array[]::text[], null, 14, $q$[]$q$::jsonb),
  ($q$sq_hq_training_2$q$, $q$side$q$, $q$제작·목공$q$, $q$과녁 앞의 화살 묶음$q$, $q$활터 담당 궁수에게 연습용 화살을 깎아 준다.$q$, $q$hq_training$q$, 1, array[]::text[], null, 15, $q$[]$q$::jsonb),
  ($q$sq_hq_yard_1$q$, $q$side$q$, $q$제작·봉인 공예$q$, $q$처마 밑 정화 부적$q$, $q$정청 처마에 새로 붙일 정화 부적을 마련한다.$q$, $q$hq_yard$q$, 3, array[]::text[], null, 16, $q$[]$q$::jsonb),
  ($q$sq_hq_yard_2$q$, $q$side$q$, $q$전투$q$, $q$거꾸로 감긴 금줄$q$, $q$인장이 사라진 밤의 역봉인 흔적이 폐쇄 사당에서 발견된다.$q$, $q$hq_yard$q$, 2, array[$q$mq_red_seal$q$]::text[], null, 17, $q$[]$q$::jsonb),
  ($q$sq_lantern_market_1$q$, $q$side$q$, $q$제작·연금$q$, $q$약방 할멈의 외상 장부$q$, $q$야시장 약방의 차를 대신 달여 주고 외상 장부의 사연을 듣는다.$q$, $q$lantern_market$q$, 1, array[]::text[], null, 18, $q$[]$q$::jsonb),
  ($q$sq_lantern_market_2$q$, $q$side$q$, $q$채집·광맥$q$, $q$등롱 장인의 쇠살$q$, $q$야시장 등롱 장인이 새 등롱 뼈대에 쓸 월철을 구한다.$q$, $q$lantern_market$q$, 1, array[]::text[], null, 19, $q$[]$q$::jsonb),
  ($q$sq_hq_archive_1$q$, $q$side$q$, $q$채집·일반$q$, $q$곰팡 핀 서가 수선$q$, $q$책벌레에 갉힌 장서를 고칠 종이와 먹을 모은다.$q$, $q$hq_archive$q$, 2, array[]::text[], null, 20, $q$[]$q$::jsonb),
  ($q$sq_hq_archive_2$q$, $q$side$q$, $q$조사$q$, $q$빈 서가 한 칸$q$, $q$인장 기록이 사라진 서가에 남은 것을 찾는다.$q$, $q$hq_archive$q$, 2, array[$q$mq_red_seal$q$]::text[], null, 21, $q$[]$q$::jsonb),
  ($q$sq_shrine_ruins_1$q$, $q$side$q$, $q$채집·영기$q$, $q$깨진 방울의 조각$q$, $q$사당 무녀의 혼백이 잃어버린 결계 조각을 모아 달라 한다.$q$, $q$shrine_ruins$q$, 2, array[]::text[], null, 22, $q$[]$q$::jsonb),
  ($q$sq_shrine_ruins_2$q$, $q$side$q$, $q$전투$q$, $q$방울 먹은 언니$q$, $q$방울 구슬을 삼킨 무녀귀를 쓰러뜨리고 사당에 소리를 돌려준다.$q$, $q$shrine_ruins$q$, 3, array[$q$sq_shrine_ruins_1$q$]::text[], null, 23, $q$[]$q$::jsonb),
  ($q$sq_old_canal_1$q$, $q$side$q$, $q$낚시$q$, $q$수문지기의 저녁상$q$, $q$폐수로 수문지기 노인에게 흑잉어 저녁을 차려 준다.$q$, $q$old_canal$q$, 3, array[]::text[], null, 24, $q$[]$q$::jsonb),
  ($q$sq_old_canal_2$q$, $q$side$q$, $q$전투$q$, $q$수문아귀의 배 속$q$, $q$폐수로 수문아귀가 삼킨 장부 조각을 되찾는다.$q$, $q$old_canal$q$, 5, array[$q$mq_drowned_ledger$q$]::text[], null, 25, $q$[]$q$::jsonb),
  ($q$sq_paper_bridge_1$q$, $q$side$q$, $q$채집·일반$q$, $q$천 마리 종이학$q$, $q$다리 위에서 종이학을 접는 아이에게 종이를 모아 준다.$q$, $q$paper_bridge$q$, 3, array[]::text[], null, 26, $q$[]$q$::jsonb),
  ($q$sq_paper_bridge_2$q$, $q$side$q$, $q$낚시$q$, $q$먹물을 삼킨 메기$q$, $q$장부 먹물을 먹고 자란 메기를 낚아 그 먹을 살핀다.$q$, $q$paper_bridge$q$, 5, array[$q$mq_drowned_ledger$q$]::text[], null, 27, $q$[]$q$::jsonb),
  ($q$sq_sealed_garden_1$q$, $q$side$q$, $q$채집·약초$q$, $q$연화원 약초밭$q$, $q$봉인된 정원에 남은 옛 약초밭에서 귀한 약초를 거둔다.$q$, $q$sealed_garden$q$, 3, array[]::text[], null, 28, $q$[]$q$::jsonb),
  ($q$sq_sealed_garden_2$q$, $q$side$q$, $q$제작·연금$q$, $q$물 주는 손$q$, $q$약초꾼의 안신탕을 지어, 닫힌 정원에서 밭을 돌본 것을 찾는다.$q$, $q$sealed_garden$q$, 3, array[$q$sq_sealed_garden_1$q$]::text[], null, 29, $q$[]$q$::jsonb),
  ($q$sq_west_gate_1$q$, $q$side$q$, $q$전투$q$, $q$끝나지 않는 순찰$q$, $q$폐성벽을 아직도 도는 옛 파수꾼들을 쉬게 한다.$q$, $q$west_gate$q$, 3, array[]::text[], null, 30, $q$[]$q$::jsonb),
  ($q$sq_west_gate_2$q$, $q$side$q$, $q$제작·단조$q$, $q$노병의 창날$q$, $q$노병의 녹슨 창을 다시 벼릴 쇠와 수리 도구를 마련한다.$q$, $q$west_gate$q$, 3, array[$q$sq_west_gate_1$q$]::text[], null, 31, $q$[]$q$::jsonb),
  ($q$sq_ghost_bamboo_1$q$, $q$side$q$, $q$전투$q$, $q$대숲 독사녀의 노래$q$, $q$귀죽림에서 사람을 홀리는 노래의 주인을 찾아 쓰러뜨린다.$q$, $q$ghost_bamboo$q$, 4, array[]::text[], null, 32, $q$[]$q$::jsonb),
  ($q$sq_ghost_bamboo_2$q$, $q$side$q$, $q$채집·약초$q$, $q$독 푸는 처방$q$, $q$독에 물린 나무꾼들을 위해 해독약 재료를 모으고 환약을 짓는다.$q$, $q$ghost_bamboo$q$, 4, array[]::text[], null, 33, $q$[]$q$::jsonb),
  ($q$sq_sunken_district_1$q$, $q$side$q$, $q$전투$q$, $q$침수 장군의 장부함$q$, $q$물에 잠긴 관아에서 장군 망령이 지키는 장부함을 연다.$q$, $q$sunken_district$q$, 5, array[$q$mq_drowned_ledger$q$]::text[], null, 34, $q$[]$q$::jsonb),
  ($q$sq_sunken_district_2$q$, $q$side$q$, $q$제작·법구 공예$q$, $q$물 밑을 비추는 등잔$q$, $q$잠긴 거리를 밝힐 어유 등잔을 만들어 길 잃은 혼을 이끈다.$q$, $q$sunken_district$q$, 5, array[]::text[], null, 35, $q$[]$q$::jsonb),
  ($q$sq_river_ferry_1$q$, $q$side$q$, $q$낚시$q$, $q$나루 주막의 빈 솥$q$, $q$강 고기가 끊긴 나루 주막에 다시 불을 지핀다$q$, $q$river_ferry$q$, 3, array[]::text[], null, 36, $q$[]$q$::jsonb),
  ($q$sq_river_ferry_2$q$, $q$side$q$, $q$조사$q$, $q$지워진 뱃길 한 줄$q$, $q$젖은 장부를 실어 나른 배가 연맹 배였다는 소문을 쫓는다$q$, $q$river_ferry$q$, 5, array[$q$mq_drowned_ledger$q$]::text[], null, 37, $q$[]$q$::jsonb),
  ($q$sq_salt_village_1$q$, $q$side$q$, $q$전투$q$, $q$소금각시의 혼삿날$q$, $q$밤마다 사내를 끌고 가는 소금각시의 정체를 밝힌다$q$, $q$salt_village$q$, 5, array[]::text[], null, 38, $q$[]$q$::jsonb),
  ($q$sq_salt_village_2$q$, $q$side$q$, $q$제작·연금$q$, $q$짠 바람 약방$q$, $q$소금에 손이 터진 일꾼들을 위해 청정수를 달인다$q$, $q$salt_village$q$, 6, array[]::text[], null, 39, $q$[]$q$::jsonb),
  ($q$sq_lotus_marsh_1$q$, $q$side$q$, $q$채집·약초$q$, $q$연밥 따는 손$q$, $q$늪 독에 쓰러진 연밭지기를 위해 약초를 모은다$q$, $q$lotus_marsh$q$, 7, array[]::text[], null, 40, $q$[]$q$::jsonb),
  ($q$sq_lotus_marsh_2$q$, $q$side$q$, $q$전투$q$, $q$연밭을 갉는 것$q$, $q$연근식귀가 먹어 치운 것은 연근만이 아니었다$q$, $q$lotus_marsh$q$, 8, array[$q$sq_lotus_marsh_1$q$]::text[], null, 41, $q$[]$q$::jsonb),
  ($q$sq_mirror_pavilion_1$q$, $q$side$q$, $q$채집·영기$q$, $q$물거울에만 비치는 얼굴$q$, $q$그리다 만 무희 초상의 얼굴을 거울 조각으로 되찾는다$q$, $q$mirror_pavilion$q$, 9, array[]::text[], null, 42, $q$[]$q$::jsonb),
  ($q$sq_mirror_pavilion_2$q$, $q$side$q$, $q$제작·봉인 공예$q$, $q$그림 속 무희를 재우는 부적$q$, $q$완성된 초상 속에서 밤마다 춤추는 무희를 놓아준다$q$, $q$mirror_pavilion$q$, 10, array[$q$sq_mirror_pavilion_1$q$]::text[], null, 43, $q$[]$q$::jsonb),
  ($q$sq_sunken_palace_1$q$, $q$side$q$, $q$전투$q$, $q$수궁 문지기 교대$q$, $q$수궁에 들어가 돌아오지 않은 잠수꾼 동생을 찾는다$q$, $q$sunken_palace$q$, 14, array[]::text[], null, 44, $q$[]$q$::jsonb),
  ($q$sq_sunken_palace_2$q$, $q$side$q$, $q$낚시$q$, $q$등롱어가 무는 밤$q$, $q$노래에 빛을 내는 수궁 등롱어로 지워진 이름을 받아 적는다$q$, $q$river_ferry$q$, 16, array[$q$mq_sunken_lantern$q$]::text[], null, 45, $q$[]$q$::jsonb),
  ($q$sq_ember_village_1$q$, $q$side$q$, $q$제작·요리$q$, $q$꺼지지 않은 부뚜막$q$, $q$정찰대가 들고 갈 노정 건량을 잔불촌 불로 짓는다$q$, $q$ember_village$q$, 5, array[]::text[], null, 46, $q$[]$q$::jsonb),
  ($q$sq_ember_village_2$q$, $q$side$q$, $q$채집·광맥$q$, $q$한팔 장군의 칼$q$, $q$부러진 장군의 칼을 다시 벼릴 쇠를 모은다$q$, $q$ember_village$q$, 6, array[]::text[], null, 47, $q$[]$q$::jsonb),
  ($q$sq_ash_coast_1$q$, $q$side$q$, $q$채집·일반$q$, $q$이름을 엮은 그물$q$, $q$재에 삭은 그물을 갈대와 비늘로 새로 엮는다$q$, $q$ash_coast$q$, 10, array[]::text[], null, 48, $q$[]$q$::jsonb),
  ($q$sq_ash_coast_2$q$, $q$side$q$, $q$조사$q$, $q$난파한 관선의 항해일지$q$, $q$해안에 떠오른 본부 관선이 실어 나르던 것을 밝힌다$q$, $q$ash_coast$q$, 12, array[$q$mq_ash_sea$q$]::text[], null, 49, $q$[]$q$::jsonb),
  ($q$sq_crimson_mine_1$q$, $q$side$q$, $q$전투$q$, $q$막장의 곡괭이 소리$q$, $q$무너진 막장에서 밤마다 들리는 곡괭이 소리를 멈춘다$q$, $q$crimson_mine$q$, 12, array[]::text[], null, 50, $q$[]$q$::jsonb),
  ($q$sq_crimson_mine_2$q$, $q$side$q$, $q$채집·광맥$q$, $q$광부들의 마지막 몫$q$, $q$막장에서 캐다 만 광석을 광부 가족에게 전한다$q$, $q$crimson_mine$q$, 13, array[$q$sq_crimson_mine_1$q$]::text[], null, 51, $q$[]$q$::jsonb),
  ($q$sq_red_forest_1$q$, $q$side$q$, $q$제작·연금$q$, $q$핏잎 아래 약초꾼$q$, $q$독거미에 물린 동료를 살릴 회춘단을 빚는다$q$, $q$red_forest$q$, 12, array[]::text[], null, 52, $q$[]$q$::jsonb),
  ($q$sq_red_forest_2$q$, $q$side$q$, $q$전투$q$, $q$지지 않는 단풍$q$, $q$올해 지지 않는 핏잎의 까닭을 찾아 숲을 잠재운다$q$, $q$red_forest$q$, 13, array[]::text[], null, 53, $q$[]$q$::jsonb),
  ($q$sq_nine_lighthouse_1$q$, $q$side$q$, $q$제작·법구 공예$q$, $q$꺼진 등대에 다시 불을$q$, $q$등대지기의 딸과 함께 꺼진 등대에 어유 등잔을 건다$q$, $q$nine_lighthouse$q$, 14, array[]::text[], null, 54, $q$[]$q$::jsonb),
  ($q$sq_nine_lighthouse_2$q$, $q$side$q$, $q$조사$q$, $q$아홉 불 아래 잠든 종$q$, $q$옛 노래 속 남쪽 종이 걸려 있던 자리를 찾아낸다$q$, $q$nine_lighthouse$q$, 15, array[$q$mq_nameless_bell$q$]::text[], null, 55, $q$[]$q$::jsonb),
  ($q$sq_bone_market_1$q$, $q$side$q$, $q$조사$q$, $q$뼈에 새긴 빚$q$, $q$붉은 달 인장이 찍힌 뼈 어음이 황무지에서 돌아왔다$q$, $q$bone_market$q$, 6, array[$q$mq_red_moon_oath$q$]::text[], null, 56, $q$[]$q$::jsonb),
  ($q$sq_bone_market_2$q$, $q$side$q$, $q$제작·목공$q$, $q$화살 없는 호위$q$, $q$장터 상단 호위대의 화살통이 비었다$q$, $q$bone_market$q$, 5, array[]::text[], null, 57, $q$[]$q$::jsonb),
  ($q$sq_red_plain_1$q$, $q$side$q$, $q$전투$q$, $q$모래가 삼킨 발자국$q$, $q$길잡이의 발자국을 따라가던 순례자들이 사라졌다$q$, $q$red_plain$q$, 6, array[]::text[], null, 58, $q$[]$q$::jsonb),
  ($q$sq_red_plain_2$q$, $q$side$q$, $q$채집·광맥$q$, $q$주사로 쓴 서약$q$, $q$적월교의 서약 먹은 황무지 주사로 만든다$q$, $q$red_plain$q$, 7, array[$q$mq_red_moon_oath$q$]::text[], null, 59, $q$[]$q$::jsonb),
  ($q$sq_glass_canyon_1$q$, $q$side$q$, $q$채집·영기$q$, $q$깨진 거울의 값$q$, $q$유리장이가 영유리로 무언가를 비추려 한다$q$, $q$glass_canyon$q$, 8, array[]::text[], null, 60, $q$[]$q$::jsonb),
  ($q$sq_glass_canyon_2$q$, $q$side$q$, $q$전투$q$, $q$같은 얼굴 둘$q$, $q$거울에 비친 또 하나의 얼굴을 쫓는다$q$, $q$glass_canyon$q$, 9, array[$q$sq_glass_canyon_1$q$]::text[], null, 61, $q$[]$q$::jsonb),
  ($q$sq_black_sand_temple_1$q$, $q$side$q$, $q$제작·봉인 공예$q$, $q$새어 나오는 기도$q$, $q$폐단 틈으로 저주 기도가 새어 나온다$q$, $q$black_sand_temple$q$, 10, array[]::text[], null, 62, $q$[]$q$::jsonb),
  ($q$sq_black_sand_temple_2$q$, $q$side$q$, $q$조사$q$, $q$빈 명부의 마지막 줄$q$, $q$이름을 모두 바친 흑사단에 남은 한 사람$q$, $q$black_sand_temple$q$, 12, array[$q$mq_eclipse_gate$q$]::text[], null, 63, $q$[]$q$::jsonb),
  ($q$sq_red_moon_fort_1$q$, $q$side$q$, $q$전투$q$, $q$성벽 위의 시험$q$, $q$대호법이 야행국 조사원의 실력을 보자 한다$q$, $q$red_moon_fort$q$, 15, array[]::text[], null, 64, $q$[]$q$::jsonb),
  ($q$sq_red_moon_fort_2$q$, $q$side$q$, $q$제작·연금$q$, $q$달빛 끓이는 밤$q$, $q$월식에 눈이 먼 무사들을 위한 약을 달인다$q$, $q$red_moon_fort$q$, 16, array[$q$sq_red_moon_fort_1$q$]::text[], null, 65, $q$[]$q$::jsonb),
  ($q$sq_ash_mountain_1$q$, $q$side$q$, $q$채집·광맥$q$, $q$화구 아래 쇠$q$, $q$북령 대장간의 쇠가 바닥났다$q$, $q$ash_mountain$q$, 7, array[]::text[], null, 66, $q$[]$q$::jsonb),
  ($q$sq_ash_mountain_2$q$, $q$side$q$, $q$제작·단조$q$, $q$관문의 망치$q$, $q$대장장이와 함께 호송대 장비를 손본다$q$, $q$ash_mountain$q$, 8, array[$q$sq_ash_mountain_1$q$]::text[], null, 67, $q$[]$q$::jsonb),
  ($q$sq_iron_monastery_1$q$, $q$side$q$, $q$전투$q$, $q$잔도 위의 목탁$q$, $q$어린 행자의 목탁이 잔도에서 울린다$q$, $q$iron_monastery$q$, 10, array[]::text[], null, 68, $q$[]$q$::jsonb),
  ($q$sq_iron_monastery_2$q$, $q$side$q$, $q$제작·직조$q$, $q$찢어진 기도 깃발$q$, $q$고찰 산문 깃발을 영사로 다시 짠다$q$, $q$iron_monastery$q$, 9, array[]::text[], null, 69, $q$[]$q$::jsonb),
  ($q$sq_jade_pass_1$q$, $q$side$q$, $q$채집·약초$q$, $q$호송대의 약 보따리$q$, $q$눈길 호송대가 쓸 약초와 수지를 마련한다$q$, $q$jade_pass$q$, 10, array[]::text[], null, 70, $q$[]$q$::jsonb),
  ($q$sq_jade_pass_2$q$, $q$side$q$, $q$전투$q$, $q$청등 호송대의 마지막 길$q$, $q$이십 년 전 눈사태에 묻힌 호송대의 등불$q$, $q$jade_pass$q$, 11, array[$q$sq_jade_pass_1$q$]::text[], null, 71, $q$[]$q$::jsonb),
  ($q$sq_frost_valley_1$q$, $q$side$q$, $q$채집·광맥$q$, $q$녹지 않는 소금$q$, $q$얼음 인장 둘레를 빙정염으로 다시 다진다$q$, $q$frost_valley$q$, 12, array[$q$mq_frost_seal$q$]::text[], null, 72, $q$[]$q$::jsonb),
  ($q$sq_frost_valley_2$q$, $q$side$q$, $q$전투$q$, $q$얼음 밑의 노크$q$, $q$얼음 밑에서 문을 두드리는 것은 사람이었다$q$, $q$frost_valley$q$, 13, array[$q$sq_frost_valley_1$q$]::text[], null, 73, $q$[]$q$::jsonb),
  ($q$sq_sky_lake_1$q$, $q$side$q$, $q$낚시$q$, $q$하늘을 낚는 노인$q$, $q$천경호 노인이 하늘 비친 물고기를 기다린다$q$, $q$sky_lake$q$, 13, array[]::text[], null, 74, $q$[]$q$::jsonb),
  ($q$sq_sky_lake_2$q$, $q$side$q$, $q$제작·요리$q$, $q$호숫가의 죽 한 그릇$q$, $q$노인의 딸을 위해 생선 요리를 만든다$q$, $q$sky_lake$q$, 14, array[$q$sq_sky_lake_1$q$]::text[], null, 75, $q$[]$q$::jsonb),
  ($q$sq_thunder_peak_1$q$, $q$side$q$, $q$채집·영기$q$, $q$벼락이 굳힌 핵$q$, $q$벼락 맞은 자리에 굳은 영핵을 줍는다$q$, $q$thunder_peak$q$, 16, array[]::text[], null, 76, $q$[]$q$::jsonb),
  ($q$sq_thunder_peak_2$q$, $q$side$q$, $q$전투$q$, $q$벼락을 부르는 문$q$, $q$월식의 문 뒤, 뇌명봉 꼭대기에 남은 의식$q$, $q$thunder_peak$q$, 18, array[$q$mq_eclipse_gate$q$]::text[], null, 77, $q$[]$q$::jsonb),
  ($q$sq_hidden_bazaar_1$q$, $q$side$q$, $q$조사$q$, $q$빚진 이름의 행방$q$, $q$이름을 팔고 달아난 석수장이를 만인장에서 찾는다$q$, $q$hidden_bazaar$q$, 10, array[]::text[], null, 78, $q$[]$q$::jsonb),
  ($q$sq_hidden_bazaar_2$q$, $q$side$q$, $q$제작·연금$q$, $q$잠 못 드는 주판$q$, $q$모든 빚을 외우는 장부지기에게 잊는 약을 지어 준다$q$, $q$hidden_bazaar$q$, 11, array[]::text[], null, 79, $q$[]$q$::jsonb),
  ($q$sq_burial_steps_1$q$, $q$side$q$, $q$전투$q$, $q$빈 관을 멘 행렬$q$, $q$밤마다 빈 관을 메고 도는 만인행군을 멈춘다$q$, $q$burial_steps$q$, 11, array[]::text[], null, 80, $q$[]$q$::jsonb),
  ($q$sq_burial_steps_2$q$, $q$side$q$, $q$채집·영기$q$, $q$비석에 앉은 재$q$, $q$비석을 닦는 아이를 도와 원령재를 걷어 낸다$q$, $q$burial_steps$q$, 10, array[]::text[], null, 81, $q$[]$q$::jsonb),
  ($q$sq_forgotten_city_1$q$, $q$side$q$, $q$조사$q$, $q$종이 지나간 길$q$, $q$이름 없는 종이 끌려간 자리에 남은 명부를 읽는다$q$, $q$forgotten_city$q$, 16, array[$q$mq_nameless_bell$q$]::text[], null, 82, $q$[]$q$::jsonb),
  ($q$sq_forgotten_city_2$q$, $q$side$q$, $q$전투$q$, $q$무명 황제의 마지막 조회$q$, $q$밤마다 빈 조정을 여는 무명 황제를 쉬게 한다$q$, $q$forgotten_city$q$, 16, array[]::text[], null, 83, $q$[]$q$::jsonb),
  ($q$sq_under_root_1$q$, $q$side$q$, $q$채집·영기$q$, $q$뿌리가 마시는 숨$q$, $q$지맥의 뿌리에서 응축 영핵을 캐며 뿌리의 갈증을 살핀다$q$, $q$under_root$q$, 17, array[]::text[], null, 84, $q$[]$q$::jsonb),
  ($q$sq_under_root_2$q$, $q$side$q$, $q$제작·봉인 공예$q$, $q$종이 쉬어 간 자리$q$, $q$이름 없는 종이 머문 수맥을 봉인 부적으로 다독인다$q$, $q$under_root$q$, 18, array[$q$mq_nameless_bell$q$]::text[], null, 85, $q$[]$q$::jsonb),
  ($q$sq_black_tide_rift_1$q$, $q$side$q$, $q$낚시$q$, $q$검은 물에 드리운 낚싯줄$q$, $q$균열 끝에서 아들을 기다리는 늙은 낚시꾼을 돕는다$q$, $q$black_tide_rift$q$, 21, array[]::text[], null, 86, $q$[]$q$::jsonb),
  ($q$sq_black_tide_rift_2$q$, $q$side$q$, $q$전투$q$, $q$거꾸로 떠도는 선원들$q$, $q$균열에 빠진 밀수선 선원들을 표류에서 풀어 준다$q$, $q$black_tide_rift$q$, 22, array[]::text[], null, 87, $q$[]$q$::jsonb),
  ($q$sq_white_tower_1$q$, $q$side$q$, $q$채집·영기$q$, $q$하나 모자란 별모래$q$, $q$천문탑의 성진사를 모아 사라진 별 하나를 센다$q$, $q$white_tower$q$, 20, array[]::text[], null, 88, $q$[]$q$::jsonb),
  ($q$sq_white_tower_2$q$, $q$side$q$, $q$제작·연금$q$, $q$마흔 해 깨어 있던 눈$q$, $q$잠들지 못하는 늙은 관측생에게 천령 감로를 지어 준다$q$, $q$white_tower$q$, 21, array[]::text[], null, 89, $q$[]$q$::jsonb),
  ($q$sq_star_observatory_1$q$, $q$side$q$, $q$제작·법구 공예$q$, $q$관성대의 등잔 밑$q$, $q$어유 등잔으로 천명원이 감춘 옛 관측 기록을 비춘다$q$, $q$star_observatory$q$, 27, array[$q$mq_lamp_shadow$q$]::text[], null, 90, $q$[]$q$::jsonb),
  ($q$sq_star_observatory_2$q$, $q$side$q$, $q$전투$q$, $q$내려오지 않은 별지기$q$, $q$탑 꼭대기에 남은 옛 태사령의 원령에게 마지막 예언을 듣는다$q$, $q$star_observatory$q$, 25, array[]::text[], null, 91, $q$[]$q$::jsonb),
  ($q$sq_sealed_abyss_1$q$, $q$side$q$, $q$전투$q$, $q$다시 감기는 사슬$q$, $q$마지막 문 뒤에서 사슬을 끊는 것들을 막고 그 소리를 센다$q$, $q$sealed_abyss$q$, 30, array[$q$mq_nine_gates$q$]::text[], null, 92, $q$[]$q$::jsonb),
  ($q$sq_sealed_abyss_2$q$, $q$side$q$, $q$채집·영기$q$, $q$봉연의 숨결$q$, $q$구중 봉연의 영핵을 캐어 잠든 것의 숨 간격을 잰다$q$, $q$star_observatory$q$, 30, array[$q$mq_nine_gates$q$]::text[], null, 93, $q$[]$q$::jsonb)
on conflict (quest_id) do update set kind = excluded.kind, cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, chapter_id = excluded.chapter_id, sort = excluded.sort, epilogue = excluded.epilogue;
delete from public.world_quest_steps where quest_id in ($q$mq_red_seal$q$, $q$mq_drowned_ledger$q$, $q$mq_red_moon_oath$q$, $q$mq_frost_seal$q$, $q$mq_nameless_bell$q$, $q$mq_eclipse_gate$q$, $q$mq_sunken_lantern$q$, $q$mq_ash_sea$q$, $q$mq_lamp_shadow$q$, $q$mq_nine_gates$q$, $q$sq_field_outskirts_1$q$, $q$sq_field_outskirts_2$q$, $q$sq_hq_dorm_1$q$, $q$sq_hq_dorm_2$q$, $q$sq_hq_training_1$q$, $q$sq_hq_training_2$q$, $q$sq_hq_yard_1$q$, $q$sq_hq_yard_2$q$, $q$sq_lantern_market_1$q$, $q$sq_lantern_market_2$q$, $q$sq_hq_archive_1$q$, $q$sq_hq_archive_2$q$, $q$sq_shrine_ruins_1$q$, $q$sq_shrine_ruins_2$q$, $q$sq_old_canal_1$q$, $q$sq_old_canal_2$q$, $q$sq_paper_bridge_1$q$, $q$sq_paper_bridge_2$q$, $q$sq_sealed_garden_1$q$, $q$sq_sealed_garden_2$q$, $q$sq_west_gate_1$q$, $q$sq_west_gate_2$q$, $q$sq_ghost_bamboo_1$q$, $q$sq_ghost_bamboo_2$q$, $q$sq_sunken_district_1$q$, $q$sq_sunken_district_2$q$, $q$sq_river_ferry_1$q$, $q$sq_river_ferry_2$q$, $q$sq_salt_village_1$q$, $q$sq_salt_village_2$q$, $q$sq_lotus_marsh_1$q$, $q$sq_lotus_marsh_2$q$, $q$sq_mirror_pavilion_1$q$, $q$sq_mirror_pavilion_2$q$, $q$sq_sunken_palace_1$q$, $q$sq_sunken_palace_2$q$, $q$sq_ember_village_1$q$, $q$sq_ember_village_2$q$, $q$sq_ash_coast_1$q$, $q$sq_ash_coast_2$q$, $q$sq_crimson_mine_1$q$, $q$sq_crimson_mine_2$q$, $q$sq_red_forest_1$q$, $q$sq_red_forest_2$q$, $q$sq_nine_lighthouse_1$q$, $q$sq_nine_lighthouse_2$q$, $q$sq_bone_market_1$q$, $q$sq_bone_market_2$q$, $q$sq_red_plain_1$q$, $q$sq_red_plain_2$q$, $q$sq_glass_canyon_1$q$, $q$sq_glass_canyon_2$q$, $q$sq_black_sand_temple_1$q$, $q$sq_black_sand_temple_2$q$, $q$sq_red_moon_fort_1$q$, $q$sq_red_moon_fort_2$q$, $q$sq_ash_mountain_1$q$, $q$sq_ash_mountain_2$q$, $q$sq_iron_monastery_1$q$, $q$sq_iron_monastery_2$q$, $q$sq_jade_pass_1$q$, $q$sq_jade_pass_2$q$, $q$sq_frost_valley_1$q$, $q$sq_frost_valley_2$q$, $q$sq_sky_lake_1$q$, $q$sq_sky_lake_2$q$, $q$sq_thunder_peak_1$q$, $q$sq_thunder_peak_2$q$, $q$sq_hidden_bazaar_1$q$, $q$sq_hidden_bazaar_2$q$, $q$sq_burial_steps_1$q$, $q$sq_burial_steps_2$q$, $q$sq_forgotten_city_1$q$, $q$sq_forgotten_city_2$q$, $q$sq_under_root_1$q$, $q$sq_under_root_2$q$, $q$sq_black_tide_rift_1$q$, $q$sq_black_tide_rift_2$q$, $q$sq_white_tower_1$q$, $q$sq_white_tower_2$q$, $q$sq_star_observatory_1$q$, $q$sq_star_observatory_2$q$, $q$sq_sealed_abyss_1$q$, $q$sq_sealed_abyss_2$q$);
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values
  ($q$mq_red_seal$q$, 1, $q$빈 칸 난 장부$q$, $q$정청에서 연서희의 이야기를 듣는다$q$, $q${"at": ["hq_yard"]}$q$::jsonb, $q$[{"s": null, "t": "새벽 정청. 등잔 기름 냄새 사이로 장부 넘기는 소리만 들린다."}, {"s": "q:m_yeon", "t": "왔군요. 오늘부터 당신 일을 맡게 된 사건 서기관 연서희예요. 반가워요."}, {"s": "q:m_yeon", "t": "인사는 짧게 할게요. 어젯밤 부적 출납 장부에서 몇 쪽이 통째로 비었어요. 그리고 금고에 있어야 할 붉은 인장이 없어졌고요."}, {"s": "q:m_yun", "t": "정확히는 쉰두 쪽부터 쉰일곱 쪽까지입니다. 청명 부적 서른 장, 봉인 부적 열두 장이 적힌 자리였지요."}, {"s": null, "t": "장부를 펴 보지도 않고 말한 사내가 고개를 숙인다. 소매 끝에 먹물이 배어 있다."}, {"s": "q:m_yeon", "t": "출납관 윤도한이에요. 장부라면 이 사람만 한 사람이 없죠."}, {"s": "q:m_yeon", "t": "먼저 장서각 지하서고로 가 보세요. 기록관 모가람이 기다려요. 갈 곳은 지도에서 고르면 돼요."}, {"s": "me", "t": "다녀오겠습니다."}]$q$::jsonb, $q${"items": {"spirit_tea": 2}}$q$::jsonb),
  ($q$mq_red_seal$q$, 2, $q$지하서고의 기록관$q$, $q$지도에서 장서각 지하서고로 이동한다$q$, $q${"tasks": [{"t": "travel", "r": ["hq_archive"], "n": 1}], "at": ["hq_archive"]}$q$::jsonb, $q$[{"s": null, "t": "계단을 내려가자 공기가 차가워진다. 서가 사이로 촛불 하나가 흔들린다."}, {"s": "night_office:mo", "t": "아, 연 서기관이 보낸 분이죠? 어서 와요, 어서. 먼지는 신경 쓰지 말고요."}, {"s": "night_office:mo", "t": "사라진 쪽이요? 찢긴 게 아니에요. 칼로 반듯하게 도려냈어요. 손에 익은 사람 솜씨죠."}, {"s": "night_office:mo", "t": "그런데 요 며칠 책벌레 요괴가 들끓어서 남은 쪽까지 갉아 먹고 있어요."}, {"s": "night_office:mo", "t": "서고를 탐색하다 보면 놈들이 튀어나올 거예요. 두 마리만 잡아 주면 남은 장부를 꺼내 올 수 있어요."}, {"s": "night_office:han", "t": "모 기록관. 외부 출입 기록부터 남기십시오. 조사원도 예외는 없습니다."}, {"s": "night_office:mo", "t": "네, 네, 감찰관님. 저분이 감찰관 한설이에요. 무서워 보여도 공정한 분이랍니다."}]$q$::jsonb, $q${"xp": 17, "gil": 7}$q$::jsonb),
  ($q$mq_red_seal$q$, 3, $q$책벌레 소탕$q$, $q$지하서고의 책벌레 요괴를 두 마리 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["g_hq_archive"], "n": 2}], "at": ["hq_archive"]}$q$::jsonb, $q$[{"s": null, "t": "쓰러진 책벌레의 배 속에서 젖은 종잇조각이 흘러나온다."}, {"s": "night_office:mo", "t": "어머, 장부 종이예요. 그런데 왜 젖어 있지? 서고엔 물기가 없는데."}, {"s": "me", "t": "비린내가 납니다."}, {"s": "night_office:mo", "t": "물비린내네요. 고인 물, 오래된 수로 바닥 같은. 이상하다."}, {"s": "night_office:han", "t": "누군가 물 묻은 손으로 서고에 들어왔다는 뜻입니다. 기록해 두지요."}, {"s": "night_office:mo", "t": "지워진 자리를 읽으려면 야령초가 필요해요. 태운 연기를 쐬면 지운 먹 자국이 떠오르거든요."}, {"s": "night_office:mo", "t": "잿빛 들녘 채집터에 많이 나요. 세 번쯤 캐 오면 충분할 거예요."}]$q$::jsonb, $q${"xp": 17, "gil": 7, "items": {"clear_spirit_pill": 1}}$q$::jsonb),
  ($q$mq_red_seal$q$, 4, $q$야령초 연기$q$, $q$잿빛 들녘에서 야령초를 세 번 채집해 모가람에게 건넨다$q$, $q${"tasks": [{"t": "gather", "items": ["herb"], "r": ["field_outskirts"], "n": 3}], "at": ["hq_archive"], "give": {"herb": 3}}$q$::jsonb, $q$[{"s": null, "t": "모가람이 야령초를 화로에 얹는다. 푸른 연기가 빈 쪽 위로 천천히 내려앉는다."}, {"s": null, "t": "지워진 자리에 붉은 자국이 떠오른다. 인장을 찍은 자국이다. 그런데 글자가 모두 거꾸로 돌아가 있다."}, {"s": "night_office:mo", "t": "이건 봉인식을 반대로 읊으면서 찍은 자국이에요. 봉인을 거는 게 아니라 푸는 쪽으로."}, {"s": "night_office:han", "t": "붉은 인장은 정청 금고에만 있습니다. 그 인장으로 봉인을 거꾸로 돌렸다면."}, {"s": "night_office:mo", "t": "안에 있는 사람이라는 얘기죠. 아이고, 머리야."}, {"s": "night_office:han", "t": "섣부른 말은 하지 마십시오. 조사원, 폐쇄 사당을 둘러보고 연 서기관에게 보고하십시오. 봉인식은 원래 그곳에서 지냈습니다."}]$q$::jsonb, $q${"xp": 17, "gil": 7, "items": {"spirit_tea": 1}}$q$::jsonb),
  ($q$mq_red_seal$q$, 5, $q$닫힌 산문$q$, $q$폐쇄 사당을 두 번 탐색하고 정청에 보고한다$q$, $q${"tasks": [{"t": "search", "r": ["shrine_ruins"], "n": 2}], "at": ["hq_yard"]}$q$::jsonb, $q$[{"s": null, "t": "사당 마당의 금줄은 끊겨 있었고, 제단의 촛농은 아직 굳지 않았다. 누군가 최근에 다녀갔다."}, {"s": "q:m_yeon", "t": "수고했어요. 처음치고 아주 잘했어요. 다친 데는 없죠?"}, {"s": "q:m_yeon", "t": "거꾸로 찍힌 인장, 젖은 종이, 사당의 촛농이라. 하나로 이어질 것 같은데 아직 근거가 없어요."}, {"s": "q:m_yeon", "t": "윤 출납관, 금고 열쇠 기록 좀 뽑아 줄래요? 윤 출납관?"}, {"s": null, "t": "한 박자 늦게 윤도한이 고개를 든다."}, {"s": "q:m_yun", "t": "아, 예. 곧 가져다 드리지요. 잠시 딴생각을 했습니다."}, {"s": "q:m_yeon", "t": "이제 장서각 지하서고와 폐쇄 사당에서 단서를 찾아요. 탐색하다 보면 단서가 보일 거예요. 찾은 단서는 일지에서 짝을 맞춰 보면 돼요."}]$q$::jsonb, $q${"xp": 17, "gil": 7, "items": {"ward_talisman": 1}}$q$::jsonb),
  ($q$mq_drowned_ledger$q$, 1, $q$물에서 건진 쪽$q$, $q$정청에서 연서희의 이야기를 듣는다$q$, $q${"at": ["hq_yard"]}$q$::jsonb, $q$[{"s": null, "t": "정청 마당 물통 옆에 젖은 종이 한 장이 널려 있다. 먹이 푸르스름하게 번졌다."}, {"s": "q:m_yeon", "t": "구름나루 뱃사공이 강에서 건져 보냈어요. 사라졌던 쉰세 쪽이에요."}, {"s": "q:m_yeon", "t": "한 장만이 아니래요. 여러 장이 물길을 따라 떠가는 걸 본 사람이 있대요."}, {"s": "q:m_yun", "t": "구룡 폐수로에서 빠지는 물은 구름나루를 지나 염등촌으로 흐릅니다. 썰물 때면 반나절이면 닿지요."}, {"s": "q:m_yeon", "t": "역시 잘 아네요."}, {"s": "q:m_yun", "t": "뱃삯 장부도 제 일이라서요."}, {"s": "q:m_yeon", "t": "구름나루의 노들 영감을 찾아가 보세요. 물길 소문이라면 그분이 제일이에요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$mq_drowned_ledger$q$, 2, $q$구름나루의 노인$q$, $q$구름나루로 가서 노들 영감을 만난다$q$, $q${"tasks": [{"t": "travel", "r": ["river_ferry"], "n": 1}], "at": ["river_ferry"]}$q$::jsonb, $q$[{"s": null, "t": "나루터에 안개가 낮게 깔렸다. 노를 손질하던 노인이 고개를 든다."}, {"s": "river_alliance:nodeul", "t": "정청에서 왔구먼. 그 젖은 종이 건진 게 나여."}, {"s": "river_alliance:nodeul", "t": "오십 년 노를 저었어도 종이가 물을 거슬러 가는 건 처음 봤어. 바람 한 점 없는데 말이여."}, {"s": "me", "t": "거슬러 갔다고요?"}, {"s": "river_alliance:nodeul", "t": "그려. 누가 끌고 간 거지. 물 밑에서."}, {"s": "river_alliance:nodeul", "t": "폐수로 수문께에 수문아귀 놈들이 자리를 틀었어. 그놈들이 뭘 물고 다니는지 한번 보고 오게."}]$q$::jsonb, $q${"xp": 120, "gil": 15}$q$::jsonb),
  ($q$mq_drowned_ledger$q$, 3, $q$수문 밑의 아귀$q$, $q$구룡 폐수로의 수문아귀를 두 마리 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_04"], "n": 2}], "at": ["river_ferry"]}$q$::jsonb, $q$[{"s": null, "t": "수문아귀의 아가리 속에 젖은 종이 뭉치와 녹슨 엽전 몇 닢이 엉겨 있었다."}, {"s": "river_alliance:nodeul", "t": "이게 뭔가 하면, 뱃삯이여. 옛 정청 엽전이지. 지금은 안 쓰는 거."}, {"s": "river_alliance:nodeul", "t": "귀신 물길엔 귀신 뱃삯이 있어. 누가 이걸 치르고 장부를 실어 보낸 게야."}, {"s": "me", "t": "정청 엽전을 쓰는 사람이라면."}, {"s": "river_alliance:nodeul", "t": "그건 자네들 사정이고. 나는 물길만 알아."}, {"s": "river_alliance:nodeul", "t": "염등촌 물귀신들은 비늘에 물길을 새긴다는 말이 있어. 비늘 몇 장 구해 오면 어디로 갔는지 읽어 주지."}]$q$::jsonb, $q${"xp": 120, "gil": 15, "items": {"clear_spirit_pill": 2}}$q$::jsonb),
  ($q$mq_drowned_ledger$q$, 4, $q$비늘에 새긴 물길$q$, $q$염등촌에서 수귀 비늘을 세 번 채집해 노들에게 건넨다$q$, $q${"tasks": [{"t": "gather", "items": ["drowned_scale"], "r": ["salt_village"], "n": 3}], "at": ["river_ferry"], "give": {"drowned_scale": 3}}$q$::jsonb, $q$[{"s": null, "t": "노들 영감이 비늘을 등불에 비춘다. 가는 금이 물결처럼 이어져 있다."}, {"s": "river_alliance:nodeul", "t": "염등촌을 지나, 뱃길을 타고, 서쪽이여. 서문 폐성벽 해자까지 갔구먼."}, {"s": "river_alliance:nodeul", "t": "근데 이상하네. 중간에 한 번 멈췄어. 침수된 구시가지에서."}, {"s": "river_alliance:nodeul", "t": "물에 잠긴 장터 말이여. 누가 거기서 장부를 받아 보고 다시 띄워 보낸 거지."}, {"s": "me", "t": "받아 본 사람이 있었다는 말씀이군요."}, {"s": "river_alliance:nodeul", "t": "그려. 사는 쪽이 물건을 펼쳐 보고 값을 매긴 게지. 장사꾼들이 다 그래."}]$q$::jsonb, $q${"xp": 120, "gil": 15, "items": {"ward_talisman": 1}}$q$::jsonb),
  ($q$mq_drowned_ledger$q$, 5, $q$잠긴 장터의 표식$q$, $q$침수된 구시가지를 두 번 탐색하고 구름나루로 돌아온다$q$, $q${"tasks": [{"t": "search", "r": ["sunken_district"], "n": 2}], "at": ["river_ferry"]}$q$::jsonb, $q$[{"s": null, "t": "물에 잠긴 장터 기둥에 붉은 칠이 남아 있었다. 둥근 달, 그 안에 눈 하나."}, {"s": null, "t": "나루로 돌아오니 전서구 한 마리가 기다리고 있다. 연서희의 글씨다."}, {"s": "q:m_yeon", "t": "「붉은 달 문양이라면 적월교예요. 조심해요. 그쪽 사람들은 웃으면서 칼을 꺼내요.」"}, {"s": "q:m_yeon", "t": "「윤 출납관에게 옛 정청 엽전을 물어보려 했는데, 오늘따라 자리에 없네요. 내일 다시 물어볼게요.」"}, {"s": "river_alliance:nodeul", "t": "붉은 달이라. 요새 서쪽 가는 배들이 그 표식 단 짐을 많이 싣더구먼."}, {"s": "q:m_yeon", "t": "「이제 구룡 폐수로와 침수된 구시가지, 염등촌과 서문 폐성벽에서 단서를 찾아요. 장부가 지나간 자리마다 흔적이 남았을 거예요.」"}]$q$::jsonb, $q${"xp": 120, "gil": 15, "items": {"spirit_qi_pill": 1}}$q$::jsonb),
  ($q$mq_red_moon_oath$q$, 1, $q$붉은 초대장$q$, $q$정청에서 연서희의 이야기를 듣는다$q$, $q${"at": ["hq_yard"]}$q$::jsonb, $q$[{"s": null, "t": "정청 문 앞에 붉은 봉투가 꽂혀 있었다. 달 모양 밀랍이 찍혀 있다."}, {"s": "q:m_yeon", "t": "적월교에서 온 거예요. 「장부를 쫓는 손님을 백골 장터로 모신다.」 우리가 쫓는 걸 다 알고 있어요."}, {"s": "night_office:han", "t": "함정일 가능성이 높습니다. 다만 거절하면 길이 끊깁니다."}, {"s": "q:m_yeon", "t": "가 보세요. 대신 혼자 깊이 들어가지는 마요. 이상하면 바로 돌아오고요."}, {"s": "q:m_yeon", "t": "그리고 이거. 정화 부적이에요. 그쪽 땅은 공기부터 달라요."}, {"s": "me", "t": "다녀오겠습니다."}]$q$::jsonb, $q${"items": {"ward_talisman": 2}}$q$::jsonb),
  ($q$mq_red_moon_oath$q$, 2, $q$백골 장터의 손님$q$, $q$백골 장터로 가서 초대한 이를 만난다$q$, $q${"tasks": [{"t": "travel", "r": ["bone_market"], "n": 1}], "at": ["bone_market"]}$q$::jsonb, $q$[{"s": null, "t": "뼈로 엮은 차양 아래 붉은 등이 줄지어 걸렸다. 장사꾼들이 웃으며 길을 비킨다."}, {"s": "red_moon_cult:danbi", "t": "왔네요, 장부 손님. 생각보다 어려 보이시네."}, {"s": "red_moon_cult:danbi", "t": "걱정 마세요. 오늘은 안 잡아먹어요. 교주님께서 손님 대접하라 하셨거든요."}, {"s": "red_moon_cult:danbi", "t": "그 이름들이요? 저희가 산 건 맞아요. 쓸 데가 있어서요."}, {"s": "me", "t": "어디에 씁니까."}, {"s": "red_moon_cult:danbi", "t": "그건 말 못 해요. 대신 하나 알려 드릴게요. 우리 교에서 도망친 계집애가 하나 있어요. 적사 황무지 어딘가에서 전갈 밥이 되고 있을걸요?"}, {"s": "red_moon_cult:danbi", "t": "그 애를 먼저 찾으면 손님이 이기는 거고, 우리가 먼저 찾으면, 후후."}]$q$::jsonb, $q${"xp": 235, "gil": 21}$q$::jsonb),
  ($q$mq_red_moon_oath$q$, 3, $q$모래 속 무녀$q$, $q$적사 황무지의 붉은 전갈을 세 마리 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["g_red_plain"], "n": 3}], "at": ["red_plain"]}$q$::jsonb, $q$[{"s": null, "t": "마지막 전갈이 모래 속으로 고꾸라진다. 바위 틈에서 흰 옷의 소녀가 기어 나온다. 입술이 갈라져 있다."}, {"s": "q:m_sawol", "t": "정청 사람이에요? 단비 언니가 보낸 사람은 아니죠?"}, {"s": "me", "t": "정청 조사원입니다."}, {"s": "q:m_sawol", "t": "다행이다. 저는 사월이에요. 적월교 무녀였어요. 였어요."}, {"s": null, "t": "사월은 말을 잇지 못하고 떨기만 한다. 손끝이 얼음처럼 차다."}, {"s": "q:m_sawol", "t": "미안해요. 사흘을 못 잤어요. 눈을 감으면 누가 이름을 불러서."}, {"s": "q:m_sawol", "t": "안신탕 한 그릇만 있으면 말할 수 있을 것 같아요."}]$q$::jsonb, $q${"xp": 235, "gil": 21}$q$::jsonb),
  ($q$mq_red_moon_oath$q$, 4, $q$안신탕 한 그릇$q$, $q$안신탕을 하나 만들어 사월에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["calm_brew"], "n": 1}], "at": ["red_plain"], "give": {"calm_brew": 1}}$q$::jsonb, $q$[{"s": null, "t": "사월이 안신탕을 두 손으로 감싸 쥐고 천천히 마신다. 떨림이 조금씩 가라앉는다."}, {"s": "q:m_sawol", "t": "교에서는 그걸 서약이라고 불러요. 지워진 이름들을 제물로 바치는 의식이에요."}, {"s": "q:m_sawol", "t": "이름이 지워진 사람은 아무도 찾지 않잖아요. 그래서 그 이름은 누구에게도 묶여 있지 않대요. 제물로 쓰기 가장 좋은 거죠."}, {"s": "me", "t": "무엇에 바칩니까."}, {"s": "q:m_sawol", "t": "북쪽이요. 얼음 아래 무언가가 있대요. 교주님은 그걸 깨운다고만 하셨어요."}, {"s": null, "t": "사월이 품에서 꼬깃한 종이 한 장을 꺼낸다. 서약에 올릴 이름 명단이다. 맨 끝 줄에 먹이 채 마르지 않은 이름이 있다. 「사월」."}, {"s": "q:m_sawol", "t": "그래서 도망쳤어요. 제 이름도 지우려고 했거든요."}]$q$::jsonb, $q${"xp": 235, "gil": 21, "items": {"tonic": 1}}$q$::jsonb),
  ($q$mq_red_moon_oath$q$, 5, $q$유리에 비친 이름$q$, $q$유리협곡을 두 번 탐색하고 백골 장터로 돌아온다$q$, $q${"tasks": [{"t": "search", "r": ["glass_canyon"], "n": 2}], "at": ["bone_market"]}$q$::jsonb, $q$[{"s": null, "t": "유리협곡의 벽마다 붉은 글자가 비쳤다. 사람 이름들이다. 유리 안쪽에서 누군가 한 자씩 새긴 듯했다."}, {"s": null, "t": "백골 장터로 돌아오자 단비가 등불 아래에서 기다리고 있다. 사월은 정청으로 가는 짐수레에 숨겨 보냈다."}, {"s": "red_moon_cult:danbi", "t": "먼저 찾으셨나 봐요. 얼굴에 다 쓰여 있네."}, {"s": "red_moon_cult:danbi", "t": "괜찮아요. 그 애 이름 하나 빠진다고 서약이 무너지진 않거든요. 이름은 많으니까요. 정청 장부에 아주 많았죠."}, {"s": null, "t": "전서구가 등불 옆에 내려앉는다. 연서희의 글씨다."}, {"s": "q:m_yeon", "t": "「사월은 무사히 도착했어요. 이제 적사 황무지와 유리협곡, 회산 관문에서 단서를 찾아요. 서약이 어디로 향하는지 알아내야 해요.」"}]$q$::jsonb, $q${"xp": 235, "gil": 21, "items": {"spirit_qi_pill": 1}}$q$::jsonb),
  ($q$mq_frost_seal$q$, 1, $q$때 이른 서리$q$, $q$정청에서 연서희의 이야기를 듣는다$q$, $q${"at": ["hq_yard"]}$q$::jsonb, $q$[{"s": null, "t": "정청 마당에 서리가 내렸다. 계절보다 이르다."}, {"s": "q:m_yeon", "t": "북령맹에서 답이 왔어요. 얼음 인장 둘레가 녹고 있대요. 하룻밤에 한 뼘씩."}, {"s": "q:m_yeon", "t": "맹주 석진악이 직접 보자고 해요. 철벽 고찰로 가 주세요."}, {"s": "me", "t": "윤 출납관은요? 북쪽 길을 안다고 했는데."}, {"s": "q:m_yeon", "t": "사흘째 휴가예요. 고향에 다녀온대요. 그런데 그 사람 고향이 어딘지 아는 사람이 없더라고요. 이상하죠."}, {"s": "q:m_yeon", "t": "북쪽은 추워요. 노정 건량 챙겨 가요. 거기서 쓰러지면 구하러 가기도 힘들어요."}]$q$::jsonb, $q${"items": {"travel_ration": 3}}$q$::jsonb),
  ($q$mq_frost_seal$q$, 2, $q$철벽 고찰의 맹주$q$, $q$철벽 고찰로 가서 석진악을 만난다$q$, $q${"tasks": [{"t": "travel", "r": ["iron_monastery"], "n": 1}], "at": ["iron_monastery"]}$q$::jsonb, $q$[{"s": null, "t": "쇠로 덧댄 산문 앞에 거구의 사내가 팔짱을 끼고 서 있다. 옆의 여장수는 지도를 말아 쥐었다."}, {"s": "north_league:seok", "t": "네가 정청 조사원이냐. 짧게 말하지. 얼음 인장이 녹는다. 우리는 이유를 모른다."}, {"s": "north_league:seok", "t": "적월교 놈들 짓이라면 내 손으로 끝낸다. 하지만 증거가 먼저다. 그게 너희 일이지."}, {"s": "north_league:yeo", "t": "호송대장 여운비예요. 인장까지 가려면 옥문 협로를 지나야 해요. 잔도가 요즘 성치 않아요."}, {"s": "north_league:yeo", "t": "잔도 쇠말뚝을 지키는 백무 영감한테 먼저 들러요. 그 영감 허락 없인 아무도 못 지나가요."}, {"s": "north_league:yeo", "t": "그런데 협로를 비취 수문장이 막아섰다는 소식이 있어요. 영감이 안쪽에 갇혔을지도 몰라요."}]$q$::jsonb, $q${"xp": 439, "gil": 29}$q$::jsonb),
  ($q$mq_frost_seal$q$, 3, $q$잔도를 막은 수문장$q$, $q$옥문 협로의 우두머리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["jade_pass"], "rank": "guardian", "n": 1}], "at": ["jade_pass"]}$q$::jsonb, $q$[{"s": null, "t": "비취 수문장이 무너지자 잔도 끝에서 쇠망치 소리가 들린다. 늙은이 하나가 말뚝을 두드리고 있다."}, {"s": "q:m_baekmu", "t": "시끄럽게도 싸우는군. 덕분에 말뚝 두 개가 흔들렸어."}, {"s": "q:m_baekmu", "t": "백무다. 이 잔도 말뚝을 예순 해 지켰지. 맹약자라 부르는 놈도 있고, 말뚝지기라 부르는 놈도 있고."}, {"s": "me", "t": "얼음 인장까지 가야 합니다."}, {"s": "q:m_baekmu", "t": "알아. 다들 그리로 가려고 하지. 근데 말뚝이 풀리면 너도 못 가."}, {"s": "q:m_baekmu", "t": "빙혼곡 빙정염이 있어야 말뚝을 다시 박는다. 세 번만 캐 와. 얼음 틈 아래서 캔 게 진짜다."}]$q$::jsonb, $q${"xp": 439, "gil": 29}$q$::jsonb),
  ($q$mq_frost_seal$q$, 4, $q$다시 박은 말뚝$q$, $q$빙혼곡에서 빙정염을 세 번 채집해 백무에게 건넨다$q$, $q${"tasks": [{"t": "gather", "items": ["frost_salt"], "r": ["frost_valley"], "n": 3}], "at": ["jade_pass"], "give": {"frost_salt": 3}}$q$::jsonb, $q$[{"s": null, "t": "백무가 빙정염을 말뚝 구멍에 붓고 망치를 내리친다. 땅 밑에서 무언가 낮게 울린다. 숨소리 같다."}, {"s": "q:m_baekmu", "t": "들었냐."}, {"s": "me", "t": "방금 그건."}, {"s": "q:m_baekmu", "t": "이 말뚝들 말이다. 바깥에서 들어오는 놈 막으려고 박은 게 아니야. 안에 있는 걸 못 나오게 박은 거지."}, {"s": "q:m_baekmu", "t": "예순 해 동안 한 번도 안 깼는데, 요 보름 사이 세 번이나 뒤척였어."}, {"s": "q:m_baekmu", "t": "맹주는 몰라. 맹약은 말뚝지기한테만 전해지거든. 이제 너도 들었으니 너도 말뚝지기다. 허허."}, {"s": null, "t": "웃는 얼굴인데 망치 쥔 손이 떨린다."}]$q$::jsonb, $q${"xp": 439, "gil": 29, "items": {"spirit_qi_pill": 2}}$q$::jsonb),
  ($q$mq_frost_seal$q$, 5, $q$얼음 아래의 숨$q$, $q$원정을 한 번 끝까지 다녀와 철벽 고찰에 보고한다$q$, $q${"tasks": [{"t": "expedition", "n": 1}], "at": ["iron_monastery"]}$q$::jsonb, $q$[{"s": null, "t": "원정에서 돌아오는 길, 얼어붙은 천경호 아래로 크고 둥근 그림자가 비쳤다. 얼음 위로 물결이 번졌다."}, {"s": "north_league:yeo", "t": "다녀왔어요? 얼굴이 하얘요. 뭘 봤어요?"}, {"s": "me", "t": "얼음 아래에서 무언가 숨을 쉬고 있습니다."}, {"s": "north_league:seok", "t": "백무 영감이 그러더냐. 그 늙은이, 나한테는 한 번도 말 안 했지."}, {"s": "north_league:seok", "t": "좋다. 증거를 가져와라. 그럼 내가 움직인다."}, {"s": null, "t": "고찰 처마에 앉은 전서구가 연서희의 글을 내민다."}, {"s": "q:m_yeon", "t": "「이제 빙혼곡과 옥문 협로, 천경호에서 단서를 찾아요. 무엇이 숨 쉬는지 알아내야 해요.」"}]$q$::jsonb, $q${"xp": 439, "gil": 29, "items": {"ward_talisman": 2}}$q$::jsonb),
  ($q$mq_nameless_bell$q$, 1, $q$짝이 깬다$q$, $q$정청에서 연서희의 이야기를 듣는다$q$, $q${"at": ["hq_yard"]}$q$::jsonb, $q$[{"s": null, "t": "장서각에서 옛 맹약문을 베껴 온 모가람이 탁자에 종이를 펼친다."}, {"s": "night_office:mo", "t": "북쪽 종이 깨면 짝도 깬대요. 남쪽 종이요. 그런데 남쪽 기록이 하나도 없어요. 전부 지워졌어요."}, {"s": "q:m_yeon", "t": "지워진 기록, 지워진 이름. 계속 같은 얘기예요."}, {"s": "q:m_yun", "t": "남명 망국령은 글 대신 노래로 남깁니다. 잔불촌의 소이 무녀를 찾으시지요."}, {"s": "q:m_yeon", "t": "윤 출납관, 같이 가 줄 수 있어요? 남쪽 길이라면."}, {"s": "q:m_yun", "t": "송구합니다. 이번 달 결산이 밀려서요. 대신 잔불촌까지 운임은 장부에 미리 달아 두었습니다."}, {"s": "q:m_yeon", "t": "조심해요. 이번엔 당신 이름이 걸려 있다고 생각하고 움직여요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$mq_nameless_bell$q$, 2, $q$잔불촌의 노래$q$, $q$잔불촌으로 가서 무녀 소이를 만난다$q$, $q${"tasks": [{"t": "travel", "r": ["ember_village"], "n": 1}], "at": ["ember_village"]}$q$::jsonb, $q$[{"s": null, "t": "꺼질 듯 꺼지지 않는 화톳불이 마을 곳곳에 피어 있다. 그 가운데서 젊은 무녀가 낮게 노래한다."}, {"s": "southern_remnant:soi", "t": "「북녘 종은 숨을 쉬고, 남녘 종은 이름을 먹네. 한 번 울면 너를 잊고, 두 번 울면 나를 잊네.」"}, {"s": "southern_remnant:soi", "t": "정청 분이시죠? 노래 들으러 오셨으면 잘 오셨어요. 들려 드릴 게 노래밖에 없거든요."}, {"s": "southern_remnant:soi", "t": "남녘 종은 혈엽림 너머에 있었어요. 있었다고 하는 건, 지금은 없어서예요."}, {"s": "me", "t": "누가 가져갔습니까."}, {"s": "southern_remnant:soi", "t": "끌고 갔어요. 땅 밑으로. 혈엽림에 끌린 자국이 남았대요. 그 숲 귀신들이 종소리를 듣고 미쳐 버렸다고 해요."}]$q$::jsonb, $q${"xp": 630, "gil": 35}$q$::jsonb),
  ($q$mq_nameless_bell$q$, 3, $q$미쳐 버린 숲$q$, $q$혈엽림의 혈엽수인을 세 마리 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_21"], "n": 3}], "at": ["ember_village"]}$q$::jsonb, $q$[{"s": null, "t": "쓰러진 혈엽수인의 껍질 속은 텅 비어 있었다. 나뭇결에 새겨져 있던 이름자가 모두 긁혀 나갔다."}, {"s": "southern_remnant:soi", "t": "그 나무들은 저희 조상 이름을 하나씩 달고 있던 나무예요. 종소리를 듣고 이름을 잃은 거예요."}, {"s": "southern_remnant:soi", "t": "울린 자만 이름을 잃는 줄 알았는데. 들은 것들까지."}, {"s": "me", "t": "끌린 자국은 어디로 이어집니까."}, {"s": "southern_remnant:soi", "t": "만인장으로요. 흑련회 땅이에요. 들어가려면 몸부터 지켜야 해요."}, {"s": "southern_remnant:soi", "t": "청정수 두 병만 만들어 주세요. 이름 지우는 기운을 씻어 낼 수 있어요. 노래로 축을 걸어 드릴게요."}]$q$::jsonb, $q${"xp": 630, "gil": 35}$q$::jsonb),
  ($q$mq_nameless_bell$q$, 4, $q$청정수 두 병$q$, $q$청정수를 두 번 만들어 소이에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["purify_water"], "n": 2}], "at": ["ember_village"], "give": {"purify_water": 2}}$q$::jsonb, $q$[{"s": null, "t": "소이가 청정수를 손바닥에 덜어 조사원의 이마에 바른다. 차갑다가, 이내 따뜻해진다."}, {"s": "southern_remnant:soi", "t": "「잊지 마라, 네 이름. 누가 불러도 돌아보지 마라, 네 이름이 아니거든.」"}, {"s": "southern_remnant:soi", "t": "이 노래를 기억해요. 땅 밑에서 누가 이름을 부르면 대답하지 말아요."}, {"s": "southern_remnant:soi", "t": "하나 더. 할머니가 그러셨어요. 종을 처음 울린 자는 남명 사람이 아니었대요. 북쪽에서 내려온 관리였대요."}, {"s": "me", "t": "관리라고요."}, {"s": "southern_remnant:soi", "t": "이름은 몰라요. 그 사람이 종을 울린 뒤로 아무도 그 이름을 기억하지 못했거든요."}]$q$::jsonb, $q${"xp": 630, "gil": 35, "items": {"rejuv_pill": 1}}$q$::jsonb),
  ($q$mq_nameless_bell$q$, 5, $q$만인장의 빈 비석$q$, $q$만인장을 세 번 탐색하고 십삼문 암시장으로 간다$q$, $q${"tasks": [{"t": "search", "r": ["burial_steps"], "n": 3}], "at": ["hidden_bazaar"]}$q$::jsonb, $q$[{"s": null, "t": "만인장의 비석들은 줄지어 서 있지만 이름 새긴 것은 하나도 없었다. 땅에는 무거운 것을 끈 자국이 깊게 패어 무명 고도 쪽으로 이어졌다."}, {"s": null, "t": "십삼문 암시장. 주판 소리가 먼저 들린다."}, {"s": "black_lotus:guseul", "t": "종을 쫓는 분이구나. 걸음이 빠르시네. 적월교 쪽도 어제 다녀갔어요."}, {"s": "black_lotus:guseul", "t": "종은 지금 무명 고도 밑, 구중 봉연 첫 문 앞에 있어요. 누가 끌고 갔냐고요? 셈은 공짜가 아니라서."}, {"s": "black_lotus:guseul", "t": "하나만 덤으로 드리죠. 우리 회주님은 그 종소리를 들어 본 분이에요. 그래서 이름이 없으시죠."}, {"s": "me", "t": "무명이라는 이름은."}, {"s": "black_lotus:guseul", "t": "이름이 아니라 빈칸이에요. 장부에 비워 둔 칸."}, {"s": null, "t": "전서구가 주판 위에 내려앉는다. 연서희의 글씨다."}, {"s": "q:m_yeon", "t": "「이제 만인장과 혈엽림, 무명 고도에서 단서를 찾아요. 종이 어디로 갔는지, 누가 노리는지 밝혀야 해요.」"}]$q$::jsonb, $q${"xp": 630, "gil": 35, "items": {"ward_talisman": 2}}$q$::jsonb),
  ($q$mq_eclipse_gate$q$, 1, $q$붉은 장터의 밀담$q$, $q$백골 장터에서 연서희와 사월을 만난다$q$, $q${"at": ["bone_market"]}$q$::jsonb, $q$[{"s": null, "t": "백골 장터의 천막 사이로 붉은 등이 흔들린다. 뼈 깎는 소리가 그치지 않는다."}, {"s": "q:m_yeon", "t": "먼 길 오셨어요. 종이 지하로 끌려간 뒤로 적월교가 갑자기 조용해졌습니다. 조용한 건 늘 나쁜 징조죠."}, {"s": "q:m_sawol", "t": "월식이 사흘 남았어요. 교주님은… 월화는 그날 흑사단의 남은 이름을 모두 바칠 거예요."}, {"s": "q:m_yeon", "t": "흑사단은 이미 무너진 교단이에요. 남은 이름이라니요?"}, {"s": "q:m_sawol", "t": "무너졌어도 명부는 남아요. 이름이 적혀 있는 한, 바칠 수 있죠."}, {"s": "q:m_yun", "t": "노자와 보급은 제가 챙겨 왔습니다. 그런데 사월 무녀, 그 명부에 이름이 몇이나 적혀 있습니까? 장부쟁이 버릇이라 숫자가 궁금해서요."}, {"s": "q:m_sawol", "t": "…이백하고도 셋. 왜 그렇게 정확히 물으시죠?"}, {"s": "q:m_yun", "t": "하하, 셈이 맞아야 마음이 놓이는 사람이라서요. 조심히 다녀오십시오."}, {"s": "q:m_yeon", "t": "먼저 흑사단 폐단으로 가 주세요. 명부가 아직 거기 있는지 확인해야 합니다."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$mq_eclipse_gate$q$, 2, $q$빈 명부$q$, $q$흑사단 폐단에 가서 흑사 주술승 둘을 쓰러뜨린다$q$, $q${"tasks": [{"t": "travel", "r": ["black_sand_temple"], "n": 1}, {"t": "win", "m": ["m_11"], "n": 2}], "at": ["black_sand_temple"]}$q$::jsonb, $q$[{"s": null, "t": "검은 모래가 제단을 반쯤 묻었다. 주술승들이 쓰러진 자리에서 찢어진 경문이 바람에 날린다."}, {"s": null, "t": "제단 아래 돌함이 열려 있다. 명부는 그대로인데, 종이마다 이름이 있던 자리만 하얗게 비었다."}, {"s": "q:m_sawol", "t": "늦었어요. 벌써 이름을 걷어 갔어요. 먹은 남고 이름만 사라졌어요."}, {"s": "me", "t": "이름은 어디로 갔지?"}, {"s": "q:m_sawol", "t": "월식성 제단으로요. 이름은 달이 가려질 때 문 앞에 놓여야 해요. 그때까지는 붉은 실에 묶어 두죠."}, {"s": "q:m_sawol", "t": "성에 들어가려면 교도처럼 보여야 해요. 교도들은 정화 부적을 붉은 실로 감아 허리에 차요. 부적 두 장만 만들어 주세요. 실은 제가 감을게요."}, {"s": null, "t": "모래 속에서 무언가가 아직 웅얼거린다. 이백세 개의 빈칸이 바람에 넘어간다."}]$q$::jsonb, $q${"xp": 853, "gil": 41, "items": {"spirit_qi_pill": 2}}$q$::jsonb),
  ($q$mq_eclipse_gate$q$, 3, $q$붉은 실 일곱 번$q$, $q$부적실을 모아 정화 부적 두 장을 만들어 사월에게 건넨다$q$, $q${"tasks": [{"t": "gather", "items": ["talisman_thread"], "r": ["black_sand_temple"], "n": 3}, {"t": "craft", "items": ["ward_talisman"], "n": 2}], "at": ["bone_market"], "give": {"ward_talisman": 2}}$q$::jsonb, $q$[{"s": null, "t": "사월이 부적에 붉은 실을 감는다. 손끝이 익숙하다. 한때 매일 하던 일이었을 것이다."}, {"s": "q:m_sawol", "t": "이렇게 일곱 번. 월식의 일곱 날을 뜻해요. 저도 열두 살 때 처음 감았어요."}, {"s": "q:m_yeon", "t": "사월 씨, 성 안에서 누가 알아보면 어떡하죠?"}, {"s": "q:m_sawol", "t": "알아보겠죠. 대호법 사마겸은 저를 길렀으니까요. 하지만 그분은 강한 사람을 먼저 봐요. 조사원님이 강하면, 저는 뒤에 숨어 있을 수 있어요."}, {"s": "q:m_yun", "t": "월식성 지도는 옛 진상 장부에서 베껴 왔습니다. 동쪽 수문이 가장 허술하다고 적혀 있더군요."}, {"s": "q:m_yeon", "t": "출납관님은 그런 것까지 다 갖고 계시네요."}, {"s": "q:m_yun", "t": "장부는 다 기억합니다. 잊히는 건… 늘 사람이 먼저지요."}, {"s": "q:m_yeon", "t": "월식은 오늘 밤이에요. 성문을 지키는 파계장을 쓰러뜨려야 제단까지 길이 열립니다."}]$q$::jsonb, $q${"xp": 853, "gil": 41, "items": {"purify_water": 1}}$q$::jsonb),
  ($q$mq_eclipse_gate$q$, 4, $q$달이 먹히는 밤$q$, $q$적월교 월식성의 우두머리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["red_moon_fort"], "rank": "guardian", "n": 1}], "at": ["red_moon_fort"]}$q$::jsonb, $q$[{"s": null, "t": "달이 붉게 먹혀 들어간다. 성벽 위 횃불이 일제히 꺼지고, 제단 위로 붉은 실 이백세 가닥이 떠오른다."}, {"s": "red_moon_cult:wolhwa", "t": "왔구나, 사월아. 네가 데려온 이가 파계장을 눕혔다니. 손님 대접을 해야겠네."}, {"s": "q:m_sawol", "t": "그만두세요, 교주님! 그 이름들은 다 사람이었어요. 우리한테 밥을 지어 주던 사람도 있었어요!"}, {"s": "red_moon_cult:wolhwa", "t": "그래서 바치는 거란다. 아무도 부르지 않는 이름은 문 앞에서나 쓸모가 있지."}, {"s": null, "t": "월화가 면사포를 걷는다. 실이 한꺼번에 끊어지고, 제단 아래 돌바닥이 숨을 쉬듯 갈라진다. 두 번째 문이 열렸다."}, {"s": "red_moon_cult:sama", "t": "교주. 문은 열렸소. 이 아이와 조사원은 내가 내보내겠소. 강한 자는 이런 데서 죽기 아깝지."}, {"s": "red_moon_cult:wolhwa", "t": "마음대로 하렴, 겸. 다음 문은 물 밑에 있으니, 어차피 우리 길은 또 만나."}, {"s": "red_moon_cult:sama", "t": "뇌명봉으로 가라. 벼락 맞은 바위에 문의 메아리가 새겨진다. 내가 줄 수 있는 건 거기까지다."}, {"s": "q:m_sawol", "t": "…고마워요, 사부님."}]$q$::jsonb, $q${"xp": 853, "gil": 41, "items": {"revival_charm": 1}}$q$::jsonb),
  ($q$mq_eclipse_gate$q$, 5, $q$벼락이 남긴 메아리$q$, $q$뇌명봉을 탐색해 문의 메아리를 찾는다$q$, $q${"tasks": [{"t": "search", "r": ["thunder_peak"], "n": 3}], "at": ["thunder_peak"]}$q$::jsonb, $q$[{"s": null, "t": "뇌명봉 꼭대기에 벼락이 내려칠 때마다 바위에 글자가 잠깐 떠올랐다 사라진다."}, {"s": "q:m_sawol", "t": "이건 문이 열릴 때 울린 소리가 남긴 자국이에요. 이름 대신 소리만 남은 거죠."}, {"s": "me", "t": "이백세 개다."}, {"s": "q:m_sawol", "t": "…다 세셨군요. 잊지 않아 주셔서 고마워요."}, {"s": null, "t": "연서희의 전서가 바람을 타고 날아든다."}, {"s": "q:m_yeon", "t": "문이 열렸다면 그 길을 거꾸로 따라가야 합니다. 세 곳에 남은 흔적을 맞추면 다음 문이 어디인지 알 수 있을 거예요."}, {"s": "q:m_yeon", "t": "이제 흑사단 폐단과 적월교 월식성, 뇌명봉에서 단서를 찾아 주세요."}]$q$::jsonb, $q${"xp": 853, "gil": 41, "items": {"thunder_ore": 2}}$q$::jsonb),
  ($q$mq_sunken_lantern$q$, 1, $q$물 밑에 뜬 등$q$, $q$구름나루에서 연서희와 뱃사람들을 만난다$q$, $q${"at": ["river_ferry"]}$q$::jsonb, $q$[{"s": null, "t": "구름나루의 물빛이 이상하다. 밤인데 물 밑에서 희미한 등불이 떠다닌다."}, {"s": "river_alliance:nodeul", "t": "오십 년 노를 저었지만 물 밑에 등이 켜진 건 처음 보네. 저건 산 사람이 든 등이 아니여."}, {"s": "river_alliance:jin", "t": "손님들이 무서워서 배를 안 타요. 장사가 반토막이랍니다. 천엽 연화늪 쪽에서는 밤마다 노래가 들린대요. 가사가 없는 노래요."}, {"s": "q:m_yeon", "t": "가사 없는 노래… 이름이 지워진 노래일지도 몰라요."}, {"s": "q:m_yun", "t": "뱃삯 장부를 맞춰 봤습니다. 지난 석 달, 용잠 수궁 쪽으로 나간 배는 장부에 있는데 돌아온 기록이 없습니다. 열한 척이에요."}, {"s": "q:m_yun", "t": "역린이 닫혔다는 뱃사람 소문이 헛말은 아니었나 봅니다."}, {"s": "river_alliance:nodeul", "t": "역린? 자네, 그 말을 어디서 들었나. 그건 우리 뱃사람끼리도 입에 안 올리는 말인데."}, {"s": "q:m_yun", "t": "장부 귀퉁이에 적혀 있더군요. 장부는 뭐든 다 압니다."}, {"s": "river_alliance:nodeul", "t": "…천엽 연화늪에 가서 갈대를 꺾어 오게. 갈대 피리는 물이 부르는 노래를 따라 부르지."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$mq_sunken_lantern$q$, 2, $q$갈대 피리$q$, $q$천엽 연화늪에서 수향 갈대를 모아 노들 영감에게 건넨다$q$, $q${"tasks": [{"t": "gather", "items": ["river_reed"], "r": ["lotus_marsh"], "n": 3}], "at": ["river_ferry"], "give": {"river_reed": 3}}$q$::jsonb, $q$[{"s": null, "t": "노들 영감이 갈대 마디를 칼끝으로 뚫는다. 구멍은 일곱. 사월이 감아 준 실의 수와 같다."}, {"s": "river_alliance:nodeul", "t": "물에 대고 불지 말고, 물이 불게 두게. 피리는 듣는 거여."}, {"s": null, "t": "피리를 물가에 대자 바람도 없는데 소리가 난다. 낮고 길게, 여러 사람이 한꺼번에 흥얼거리는 소리."}, {"s": "q:m_yeon", "t": "사람 목소리예요. 여럿이…. 이름을 부르려다 끝내 못 부르는 목소리."}, {"s": "river_alliance:nodeul", "t": "돌아오지 못한 열한 척 뱃사람들도 저 안에 있겠지. 노래는 수경루 쪽으로 흐르네. 거울 누각이 물 노래를 비춰 보여 줄 걸세."}, {"s": "river_alliance:jin", "t": "수경루엔 무희 귀신들이 춤을 춘다던데요. 춤이 멈춰야 거울이 맑아진대요. 뱃삯은 깎아 드릴 테니 꼭 멈춰 주세요."}]$q$::jsonb, $q${"xp": 1109, "gil": 47, "items": {"spirit_tea": 2}}$q$::jsonb),
  ($q$mq_sunken_lantern$q$, 3, $q$거울 속 행렬$q$, $q$수경루의 수경무희 둘을 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_18"], "n": 2}], "at": ["mirror_pavilion"]}$q$::jsonb, $q$[{"s": null, "t": "수경무희들이 쓰러지자 물 위 누각이 고요해진다. 호수에 비친 달 아래로, 거울처럼 맑은 물속이 들여다보인다."}, {"s": null, "t": "물 밑에 사람들이 줄지어 서 있다. 얼굴은 흐릿하고 입만 움직인다. 모두 같은 노래를 부르고 있다."}, {"s": "q:m_yeon", "t": "저 사람들… 장부에서 지워진 이름들이에요. 붉은 인장과 함께 사라진 부적 기록에 있던 사람도 보여요."}, {"s": "me", "t": "무엇을 향해 부르고 있지?"}, {"s": null, "t": "행렬은 아래로, 더 아래로 이어진다. 끝에 거대한 비늘 하나가 문처럼 서 있다. 노래가 닿을 때마다 비늘이 조금씩 돌아간다."}, {"s": "q:m_yeon", "t": "노래가 열쇠를 돌리고 있어요. 다 돌아가면 세 번째 문이 열려요."}, {"s": "q:m_yeon", "t": "수궁은 깊어요. 빛이 없으면 길을 잃어요. 어유 등잔을 하나 만들어 가요. 물 밑에서도 꺼지지 않는 불이 필요해요."}]$q$::jsonb, $q${"xp": 1109, "gil": 47, "items": {"mirror_shard": 2}}$q$::jsonb),
  ($q$mq_sunken_lantern$q$, 4, $q$불을 들고 온 사람$q$, $q$어유 등잔을 만들어 용잠 수궁으로 가져간다$q$, $q${"tasks": [{"t": "travel", "r": ["sunken_palace"], "n": 1}, {"t": "craft", "items": ["fish_oil_lamp"], "n": 1}], "at": ["sunken_palace"], "give": {"fish_oil_lamp": 1}}$q$::jsonb, $q$[{"s": null, "t": "등잔을 켜자 수궁의 산호 기둥이 하나씩 모습을 드러낸다. 기둥 사이에서 집채만 한 등딱지가 천천히 움직인다."}, {"s": "q:m_gaon", "t": "불을 들고 온 사람은… 백 년 만이구나. 대부분은 불 없이 와서, 불 없이 남았지."}, {"s": "me", "t": "누구냐."}, {"s": "q:m_gaon", "t": "가온이라 한다. 이 수궁의 문을 지켜 왔지. 이제는 지켰다고 말하기 부끄럽다만."}, {"s": "q:m_gaon", "t": "역린은 본디 용왕이 스스로 잠근 것이다. 그 아래 있는 것을 다시는 내보내지 않으려고. 그런데 누군가 이름들을 물에 풀었어. 이름의 노래는 역린을 돌린다."}, {"s": "q:m_yeon", "t": "누가 풀었는지 보셨나요?"}, {"s": "q:m_gaon", "t": "얼굴은 못 봤다. 장부 냄새가 났지. 먹물과 젖은 종이 냄새. 손끝이 아주 정갈한 자였다."}, {"s": "q:m_gaon", "t": "해일장이 문 앞을 막고 있다. 저것이 깨어 있는 한 나는 등딱지를 들 수가 없다. 그대가 눕혀 주게."}]$q$::jsonb, $q${"xp": 1109, "gil": 47, "items": {"lantern_oil": 1}}$q$::jsonb),
  ($q$mq_sunken_lantern$q$, 5, $q$역린 앞에서$q$, $q$용잠 수궁의 우두머리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["sunken_palace"], "rank": "guardian", "n": 1}], "at": ["sunken_palace"]}$q$::jsonb, $q$[{"s": null, "t": "해일장이 무너지며 수궁 전체가 한 번 크게 출렁인다. 물이 빠져나가듯 노래가 잠깐 멎는다."}, {"s": "q:m_gaon", "t": "이제 보이는가. 역린이다."}, {"s": null, "t": "문만 한 비늘이 반쯤 돌아가 있다. 그 틈으로 차가운 숨이 새어 나온다. 이름 없는 얼굴들이 비늘 앞에 모여, 소리 없이 입을 벌린다."}, {"s": "q:m_yeon", "t": "다 막지는 못해도… 저 사람들이라도 노래를 그치게 할 수는 없을까요?"}, {"s": "q:m_gaon", "t": "노래는 누가 시작했는지 알아야 끝낼 수 있다. 노래는 남쪽에서 왔다. 바다 끝, 등대들이 서 있는 곳에서."}, {"s": "q:m_gaon", "t": "연화늪의 갈대, 수경루의 거울, 이 수궁의 비늘. 노래가 지나간 자리를 맞춰 보면 누가 불을 붙였는지 보일 게다."}, {"s": "q:m_yeon", "t": "이제 천엽 연화늪과 수경루, 용잠 수궁에서 단서를 찾아 주세요."}]$q$::jsonb, $q${"xp": 1109, "gil": 47, "items": {"drowned_scale": 3}}$q$::jsonb),
  ($q$mq_ash_sea$q$, 1, $q$꺼져 가는 남쪽 바다$q$, $q$잔불촌에서 연서희와 남명회 사람들을 만난다$q$, $q${"at": ["ember_village"]}$q$::jsonb, $q$[{"s": null, "t": "잔불촌 언덕에서 바다를 내려다본다. 군도 위 아홉 등대 가운데 불이 켜진 것은 셋뿐이다."}, {"s": "southern_remnant:jang", "t": "나라가 망하던 밤에도 등대는 꺼지지 않았소. 그런데 지난달부터 하룻밤에 하나씩 꺼지고 있소."}, {"s": "q:m_yeon", "t": "아홉 등대가 아홉 문과 짝이라는 기록이 있어요. 등대가 꺼질 때마다 문이 하나씩 열린 거라면…."}, {"s": "southern_remnant:jang", "t": "이미 여섯이 꺼졌소. 남은 셋이 마지막 문들이겠지."}, {"s": "southern_remnant:galmae", "t": "꺼진 등대 밑마다 검은 연꽃 표식이 있었어. 흑련회 놈들이야. 배를 타고 재의 해안 쪽으로 드나들더라."}, {"s": "q:m_yeon", "t": "해안에 그 배가 남아 있을지도 몰라요. 갈매 대장과 함께 재의 해안을 뒤져 주세요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$mq_ash_sea$q$, 2, $q$난파선의 짐$q$, $q$재의 해안을 탐색해 흑련회의 배를 찾는다$q$, $q${"tasks": [{"t": "search", "r": ["ash_coast"], "n": 3}], "at": ["ash_coast"]}$q$::jsonb, $q$[{"s": null, "t": "잿빛 파도가 난파선 옆구리를 때린다. 선창 안에 젖은 상자들이 쌓여 있다. 상자마다 검은 연꽃이 찍혀 있다."}, {"s": "southern_remnant:galmae", "t": "기름이네. 등대 기름을 빼돌려서 바다에 버렸어. 불을 끄려고 일부러."}, {"s": null, "t": "상자 밑바닥에 기름 먹은 장부 한 권이 붙어 있다. 글씨가 아주 정갈하다."}, {"s": "q:m_yeon", "t": "이 글씨… 어디서 본 것 같은데. 정청 서식이에요. 칸 나누는 법까지 똑같아요."}, {"s": "southern_remnant:galmae", "t": "너네 본부 사람이 흑련회 짐을 셈해 줬다는 거야?"}, {"s": "q:m_yeon", "t": "정청 서식은 누구나 베낄 수 있어요. 아직 단정하긴 일러요."}, {"s": "southern_remnant:galmae", "t": "장 장군이 등대를 다시 켤 쇠틀을 만든대. 주혈 광산에서 쇠를 캐 와. 갱도 원령들이 날뛰니 조심하고."}]$q$::jsonb, $q${"xp": 1397, "gil": 53, "items": {"spirit_glass": 2}}$q$::jsonb),
  ($q$mq_ash_sea$q$, 3, $q$주혈 광산의 쇠$q$, $q$주혈 광산에서 생 월철을 캐고 갱도 원령을 쓰러뜨린 뒤 장무현에게 건넨다$q$, $q${"tasks": [{"t": "gather", "items": ["raw_iron"], "r": ["crimson_mine"], "n": 4}, {"t": "win", "m": ["x_crimson_mine_2"], "n": 2}], "at": ["ember_village"], "give": {"raw_iron": 4}}$q$::jsonb, $q$[{"s": null, "t": "장무현이 한 팔로 망치를 든다. 생 월철이 불 속에서 붉게 달아오른다."}, {"s": "southern_remnant:jang", "t": "등대 불은 쇠틀에 담아야 바람에 안 꺼지오. 나라가 망한 뒤로 망치를 든 적이 없는데."}, {"s": "q:m_yeon", "t": "장군님, 광산 원령들이 이상한 말을 했어요. 「돌려 달라」고요. 무엇을 돌려 달라는 걸까요."}, {"s": "southern_remnant:jang", "t": "이름이오. 저 광산에서 죽은 우리 백성들은 장부에 이름 한 줄 못 남겼소. 망국의 백성은 장부에서 먼저 지워지지."}, {"s": "q:m_yeon", "t": "…그래서 흑련회가 그 이름을 쓸 수 있었군요. 아무도 찾지 않는 이름이니까."}, {"s": "southern_remnant:jang", "t": "쇠틀은 다 됐소. 그러나 군도까지는 배가 못 가오. 물살이 사나워. 원정을 꾸려 섬을 건너가야 하오. 마지막 등대에 아직 사람이 하나 남아 있다 들었소."}]$q$::jsonb, $q${"xp": 1397, "gil": 53, "items": {"iron_ingot": 2}}$q$::jsonb),
  ($q$mq_ash_sea$q$, 4, $q$마지막 등대지기$q$, $q$원정을 끝까지 다녀와 구등대 군도에 닿는다$q$, $q${"tasks": [{"t": "expedition", "n": 1}], "at": ["nine_lighthouse"]}$q$::jsonb, $q$[{"s": null, "t": "안개를 헤치고 군도의 가장 바깥 섬에 닿는다. 등대 꼭대기에서 작은 불씨 하나가 흔들린다."}, {"s": "q:m_dohwa", "t": "오지 마세요! …아, 흑련회가 아니군요. 미안해요. 요즘은 발소리만 들려도 무서워서."}, {"s": "q:m_dohwa", "t": "저는 도화예요. 아홉 등대지기 가운데 마지막으로 남았어요. 나머지는… 명령서를 받고 스스로 불을 껐어요."}, {"s": "me", "t": "명령서?"}, {"s": "q:m_dohwa", "t": "이거요. 본부에서 왔대요. 「구등대의 불을 거두고 등대지기는 철수하라」. 저만 따르지 않았어요. 할머니가 그러셨거든요. 등대는 누가 시켜서 켜는 게 아니라고."}, {"s": null, "t": "젖은 종이 아래 붉은 인장이 선명하다. 야행국 본부 정청의 인장이다."}, {"s": "q:m_dohwa", "t": "이 불도 곧 꺼져요. 기름이 다 됐어요. 등대 불은 영기가 뭉친 핵이 있어야 다시 커져요."}]$q$::jsonb, $q${"xp": 1397, "gil": 53, "items": {"lantern_oil": 2}}$q$::jsonb),
  ($q$mq_ash_sea$q$, 5, $q$정청의 인장$q$, $q$응축 영핵을 만들어 도화에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["spirit_core"], "n": 1}], "at": ["nine_lighthouse"], "give": {"spirit_core": 1}}$q$::jsonb, $q$[{"s": null, "t": "응축 영핵을 쇠틀에 얹자 불씨가 단숨에 기둥처럼 솟는다. 안개가 갈라지고, 꺼졌던 여섯 등대의 윤곽이 바다 위에 드러난다."}, {"s": "q:m_dohwa", "t": "켜졌어요… 할머니, 보세요. 켜졌어요."}, {"s": null, "t": "보급선이 섬에 닿고 연서희와 윤도한이 내린다. 윤도한은 명령서를 받아 들자마자 입을 연다."}, {"s": "q:m_yun", "t": "위조입니다. 인장 테두리가 반 푼 굵어요. 정청 인장은 이렇게 찍히지 않습니다."}, {"s": "q:m_yeon", "t": "…한눈에 아시네요. 저는 몇 번을 봐도 진짜 같은데."}, {"s": "q:m_yun", "t": "장부만 십오 년을 봤으니까요. 이건 제가 정청에 가져가 감찰관님께 넘기겠습니다. 걱정 마세요."}, {"s": "q:m_dohwa", "t": "안 돼요. 이건 제가 가지고 있을래요. …죄송해요. 지금은 아무도 못 믿겠어요."}, {"s": "q:m_yeon", "t": "이제 재의 해안과 주혈 광산, 구등대 군도에서 단서를 찾아 주세요. 명령서가 어디서 왔는지, 이 바다가 먼저 말해 줄 거예요."}]$q$::jsonb, $q${"xp": 1397, "gil": 53, "items": {"moonlight_essence": 1}}$q$::jsonb),
  ($q$mq_lamp_shadow$q$, 1, $q$정청의 문서함$q$, $q$정청에서 감찰관 한설과 도제조를 만난다$q$, $q${"at": ["hq_yard"]}$q$::jsonb, $q$[{"s": null, "t": "정청 대청에 등이 낮게 걸려 있다. 감찰관 한설이 도화에게서 빌려 온 명령서를 상 위에 펼친다."}, {"s": "night_office:han", "t": "인장은 진짜다. 정청 문서함 안에서, 정청 인장으로 찍혔다."}, {"s": "q:m_yeon", "t": "하지만 출납관님은 테두리가 굵다고…."}, {"s": "night_office:han", "t": "습기를 먹으면 테두리는 번진다. 그 정도는 장부를 십오 년 본 사람이면 안다."}, {"s": "q:m_yun", "t": "제가 성급했군요. 바닷바람에 젖은 걸 미처 생각하지 못했습니다. 부끄럽습니다."}, {"s": "night_office:baek", "t": "…문서함 열쇠를 가진 자는 셋이다. 나, 감찰관, 출납관."}, {"s": "night_office:han", "t": "그리고 명령서 서식은 연화원 시절 것이다. 연화원이 봉인되기 전, 그곳 관리들이 쓰던 칸 나눔이다."}, {"s": "q:m_yeon", "t": "연화원 관리 명부는 장서각에 있어요. 모가람 기록관님께 가 봐요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$mq_lamp_shadow$q$, 2, $q$떠내려간 명부$q$, $q$백지교를 탐색해 떠내려간 명부 낱장을 건진다$q$, $q${"tasks": [{"t": "search", "r": ["paper_bridge"], "n": 3}], "at": ["hq_yard"]}$q$::jsonb, $q$[{"s": null, "t": "백지교 아래 강물에서 건져 온 종이학들을 펴 놓는다. 하나같이 연화원 관리 명부의 낱장이다."}, {"s": "night_office:mo", "t": "아이고, 이걸 다 건져 왔어요? 장서각 명부가 몇 해 전에 통째로 젖었다더니, 누가 백지교에 띄워 버렸던 거군요."}, {"s": "night_office:mo", "t": "가만있자… 연화원 관리 스물둘. 그런데 한 사람 자리만 이름이 비었어요. 긁어낸 게 아니라 먹을 다시 거둬 낸 자국이에요."}, {"s": "q:m_yeon", "t": "먹을 거둬 냈다면… 이름을 쓴 사람만 할 수 있는 방법이죠?"}, {"s": "night_office:mo", "t": "그렇죠. 제 손으로 쓴 이름을 제 손으로 거둔 거예요. 스스로 장부에서 사라진 사람이에요."}, {"s": "night_office:mo", "t": "거둔 먹은 영맥 수피 즙에 담그면 다시 떠올라요. 귀죽림 수피가 가장 진하니, 벗겨 와 주세요."}]$q$::jsonb, $q${"xp": 1717, "gil": 59, "items": {"fine_paper": 2}}$q$::jsonb),
  ($q$mq_lamp_shadow$q$, 3, $q$되살아난 글씨$q$, $q$귀죽림에서 영맥 수피를 모아 모가람에게 건넨다$q$, $q${"tasks": [{"t": "gather", "items": ["spirit_bark"], "r": ["ghost_bamboo"], "n": 3}], "at": ["hq_yard"], "give": {"spirit_bark": 3}}$q$::jsonb, $q$[{"s": null, "t": "모가람이 수피 즙에 낱장을 담근다. 빈칸에서 먹이 천천히 배어 나온다. 이름은 아직 흐리지만, 글씨체는 또렷하다."}, {"s": "night_office:mo", "t": "어… 이 글씨는."}, {"s": "q:m_yeon", "t": "정청 출납 장부 글씨예요. 칸마다 획을 끝까지 눌러 쓰는 버릇. 제가 매일 보는…."}, {"s": "night_office:mo", "t": "서희야, 아직 단정하지 마. 글씨는 닮을 수 있어."}, {"s": "q:m_yeon", "t": "출납관님은 오늘 아침 연화원 봉인 점검을 나가셨어요. 혼자서요."}, {"s": "night_office:han", "t": "서류에 없는 점검이다. 조사원, 지금 연화원으로 가라. 나는 정청 문을 닫는다."}, {"s": "q:m_yeon", "t": "저도 갈게요. …제 눈으로 직접 봐야겠어요."}]$q$::jsonb, $q${"xp": 1717, "gil": 59, "items": {"herbal_extract": 2}}$q$::jsonb),
  ($q$mq_lamp_shadow$q$, 4, $q$등잔 밑$q$, $q$폐쇄된 연화원에 가서 우두머리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "travel", "r": ["sealed_garden"], "n": 1}, {"t": "win", "r": ["sealed_garden"], "rank": "guardian", "n": 1}], "at": ["sealed_garden"]}$q$::jsonb, $q$[{"s": null, "t": "봉인파쇄귀가 쓰러지자 연못의 연잎이 일제히 뒤집힌다. 물 위에 등 하나가 떠 있고, 그 곁에 윤도한이 서 있다. 품에서 붉은 빛이 샌다."}, {"s": "q:m_yeon", "t": "출납관님. …그 품에 든 거, 붉은 인장이죠. 장부에서 사라졌던."}, {"s": "q:m_yun", "t": "서희 씨는 늘 정확했지요. 그래서 이 일을 맡기면 끝까지 올 줄 알았습니다. 여기까지 와 줘서 고맙습니다."}, {"s": "q:m_yun", "t": "연화원의 스물두 번째 관리. 제 이름은 제가 지웠습니다. 흑련회에서는 저를 무명이라 부르더군요. 이름을 팔았다고들 하지요. 판 게 아닙니다. 맡겨 둔 겁니다."}, {"s": "q:m_yeon", "t": "왜요. 등대를 끄고, 장부를 적시고, 그 사람들 이름을 문에 바치고. 왜요!"}, {"s": "q:m_yun", "t": "바친 게 아닙니다. 돌려보낸 거예요. 망국의 백성, 흑사단, 장부 밖으로 밀려난 사람들. 이 세상 어느 장부도 그들을 다시 적어 주지 않아요. 문 너머에는 지워진 이름이 전부 모여 있습니다. 마지막 문을 열면 데려올 수 있어요."}, {"s": "me", "t": "문 너머에 있는 건 사람이 아니다."}, {"s": "q:m_yun", "t": "그럴지도 모르지요. 그래도 아무도 부르지 않는 것보다는 낫습니다. …서희 씨, 출납 장부는 당신이 맡아 주세요. 셈은 다 맞춰 두었습니다."}, {"s": null, "t": "윤도한이 등을 들고 연못 아래 돌계단으로 내려간다. 물이 그의 발목과 무릎과 어깨를 차례로 삼킨다. 등불만 한참 물 밑에서 흔들리다 꺼진다."}]$q$::jsonb, $q${"xp": 1717, "gil": 59}$q$::jsonb),
  ($q$mq_lamp_shadow$q$, 5, $q$남은 사람$q$, $q$안신탕을 만들어 연서희에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["calm_brew"], "n": 1}], "at": ["hq_yard"], "give": {"calm_brew": 1}}$q$::jsonb, $q$[{"s": null, "t": "정청 뒤뜰. 연서희가 출납 장부를 무릎에 얹고 앉아 있다. 마지막 장까지 셈이 정확히 맞는다."}, {"s": "me", "t": "마셔라."}, {"s": "q:m_yeon", "t": "…안신탕이네요. 고마워요. 손이 계속 떨려서 붓을 못 들겠더라고요."}, {"s": "q:m_yeon", "t": "십 년을 같이 일했어요. 제가 처음 정청에 온 날, 장부 칸 나누는 법을 가르쳐 준 사람이에요."}, {"s": "night_office:baek", "t": "서희. 그를 쫓을 사람은 이 사람이다. 너는 이 사람을 맡아라. 그게 네 일이다."}, {"s": "q:m_yeon", "t": "…네, 도제조님. 저 아직 담당 서기관이에요. 조사원님 곁을 떠나지 않아요."}, {"s": "q:m_yeon", "t": "그가 남긴 흔적을 거꾸로 따라가요. 처음 장부가 젖은 곳부터요."}, {"s": "q:m_yeon", "t": "이제 잿빛 들녘과 백지교, 폐쇄된 연화원, 귀죽림에서 단서를 찾아 주세요."}]$q$::jsonb, $q${"xp": 1717, "gil": 59, "items": {"revival_charm": 1}}$q$::jsonb),
  ($q$mq_nine_gates$q$, 1, $q$꺼져 가는 아홉 별$q$, $q$무극 관성대에서 천명원 사람들을 만난다$q$, $q${"at": ["star_observatory"]}$q$::jsonb, $q$[{"s": null, "t": "무극 관성대 꼭대기에서 혼천의가 저절로 돈다. 북쪽 하늘의 아홉 별이 하나씩 빛을 잃는 중이다."}, {"s": "mandate_court:seo", "t": "아, 오셨군요. 졸려 보여도 사흘째 못 잤어요. 별이 꺼지는 순서가 등대가 꺼진 순서랑 똑같아요. 남은 별은 하나."}, {"s": null, "t": "태사령 하후정이 말없이 별 지도 한 장을 상 위에 편다."}, {"s": "night_office:baek", "t": "태사령은 예언을 입에 담지 않는다. 대신 지도를 그린다. 그거면 충분하다."}, {"s": "q:m_yeon", "t": "지도 끝이 구중 봉연이네요. 그런데 길 가운데가 비어 있어요."}, {"s": "mandate_court:seo", "t": "백옥 천문탑의 별모래가 더 있어야 해요. 탑 별빛을 먹은 모래가 나머지 길을 그려 줄 거예요. 직접 가서 담아 와 주세요."}, {"s": "night_office:baek", "t": "다녀오너라. 이번이 마지막 장부다."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$mq_nine_gates$q$, 2, $q$별모래로 그린 길$q$, $q$백옥 천문탑에서 성진사를 모아 서이연에게 건넨다$q$, $q${"tasks": [{"t": "travel", "r": ["white_tower"], "n": 1}, {"t": "gather", "items": ["star_sand"], "r": ["white_tower"], "n": 3}], "at": ["star_observatory"], "give": {"star_sand": 3}}$q$::jsonb, $q$[{"s": null, "t": "서이연이 별모래를 지도 위에 흩뿌린다. 모래알이 스스로 굴러가 빈 길을 채운다."}, {"s": "mandate_court:seo", "t": "지맥의 뿌리, 흑조 균열, 그리고 봉연. 길은 하나뿐이에요. 돌아오는 길은… 안 그려지네요."}, {"s": "q:m_yeon", "t": "돌아오는 길은 우리가 그리면 돼요."}, {"s": "mandate_court:hahu", "t": "붉은 인장은 제자리에 있을 때 빛난다. 손에 쥔 자에게서는 빛나지 않는다."}, {"s": "mandate_court:seo", "t": "…태사령께서 입을 여셨네. 십 년 만에 처음이에요."}, {"s": "mandate_court:seo", "t": "흑조 균열에 역천 표류체가 모여들고 있어요. 문이 열리며 밀려 나온 것들이에요. 그걸 치워야 아래로 내려갈 수 있어요."}]$q$::jsonb, $q${"xp": 2070, "gil": 65, "items": {"spirit_core": 1}}$q$::jsonb),
  ($q$mq_nine_gates$q$, 3, $q$균열 바닥의 셈$q$, $q$흑조 균열의 역천 표류체 둘을 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_rift"], "n": 2}], "at": ["black_tide_rift"]}$q$::jsonb, $q$[{"s": null, "t": "검은 물이 거꾸로 하늘을 향해 흐른다. 표류체들이 흩어지자 균열 바닥에 무언가 반짝인다. 정청 출납 장부의 낱장이다."}, {"s": "q:m_yeon", "t": "그가 떨어뜨린 거예요. 일부러요. 길을 알려 주려고."}, {"s": null, "t": "낱장에는 숫자만 적혀 있다. 망국 백성 사천, 흑사단 이백셋, 수향 뱃사람 열하나, 등대지기 여덟."}, {"s": "q:m_yeon", "t": "다 셌어요. 한 사람도 빠짐없이. …이렇게까지 셀 줄 아는 사람이, 왜."}, {"s": "me", "t": "셀 줄 알아서다."}, {"s": "q:m_yeon", "t": "…그렇네요. 아무도 세지 않으니까, 혼자 세다가 여기까지 온 거네요."}, {"s": "q:m_yeon", "t": "봉연은 오래 내려가야 해요. 회생 부적 한 장 품고, 원정을 꾸려 끝까지 내려가요."}]$q$::jsonb, $q${"xp": 2070, "gil": 65, "items": {"revival_charm": 1}}$q$::jsonb),
  ($q$mq_nine_gates$q$, 4, $q$아홉째 문으로$q$, $q$회생 부적을 만들어 품고 원정을 끝까지 다녀온다$q$, $q${"tasks": [{"t": "craft", "items": ["revival_charm"], "n": 1}, {"t": "expedition", "n": 1}], "at": ["sealed_abyss"]}$q$::jsonb, $q$[{"s": null, "t": "사슬이 천장에서 바닥까지 늘어져 있다. 내려갈수록 소리가 사라진다. 발소리도, 숨소리도."}, {"s": null, "t": "지나온 문들이 차례로 보인다. 종이 걸린 첫 문, 붉은 실이 끊어진 둘째 문, 비늘이 돌아간 셋째 문, 꺼진 등대들이 비친 문들."}, {"s": "q:m_yeon", "t": "여덟 개가 열렸어요. 남은 건 하나."}, {"s": null, "t": "아홉째 문 앞, 사슬을 끊어 내는 거대한 그림자가 길을 막고 서 있다. 그 너머 문턱에 등 하나가 놓여 있다."}, {"s": "q:m_yun", "t": "와 주셨군요. 서희 씨도."}, {"s": "q:m_yun", "t": "사슬 끊는 자가 문을 붙들고 있습니다. 저것이 사슬을 다 끊으면 문은 스스로 열려요. 제가 인장을 쓸 필요도 없이요. …막고 싶으시면 막아 보세요."}]$q$::jsonb, $q${"xp": 2070, "gil": 65, "items": {"spirit_qi_pill": 3}}$q$::jsonb),
  ($q$mq_nine_gates$q$, 5, $q$문턱의 셈$q$, $q$구중 봉연의 우두머리 사슬 끊는 자를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["sealed_abyss"], "rank": "guardian", "n": 1}], "at": ["sealed_abyss"]}$q$::jsonb, $q$[{"s": null, "t": "사슬 끊는 자가 무너지며 끊긴 사슬들이 한꺼번에 바닥에 쏟아진다. 문이 멈춘다. 반쯤 열린 채로."}, {"s": null, "t": "문틈 너머에서 수많은 목소리가 이름을 부른다. 누구의 이름도 아니고, 누구의 이름이기도 한 소리."}, {"s": "q:m_yun", "t": "들리지요. 저들이 지워진 사람들입니다. 저 안에서 기다리고 있어요."}, {"s": "me", "t": "저건 이름을 먹는 소리다."}, {"s": "q:m_yun", "t": "…압니다. 처음부터 알았는지도 모르지요. 그래도 문을 닫으면, 저들은 영영 아무도 아닌 채로 남습니다."}, {"s": "q:m_yeon", "t": "출납관님이 셌잖아요. 사천, 이백셋, 열하나, 여덟. 장부에 남았어요. 아무도 아닌 게 아니에요."}, {"s": "q:m_yun", "t": "…서희 씨는 정말 끝까지 정확하네요. 인장은 아직 못 드립니다. 문을 닫는 법을 모르시잖아요. 문이 열린 길을 거꾸로 맞춰 오세요. 그러면 드리지요."}, {"s": "q:m_yeon", "t": "이제 지맥의 뿌리와 흑조 균열, 백옥 천문탑, 구중 봉연에서 단서를 찾아 주세요. 기다려요, 출납관님. 금방 와요."}]$q$::jsonb, $q${"xp": 2070, "gil": 65, "items": {"heavenly_dew": 1}}$q$::jsonb),
  ($q$sq_field_outskirts_1$q$, 1, $q$털린 볏가리$q$, $q$잿빛 들녘의 농부 곽만석을 만난다$q$, $q${"at": ["field_outskirts"]}$q$::jsonb, $q$[{"s": null, "t": "쓰러진 볏가리 옆에서 사내 하나가 낫을 쥔 채 서 있다."}, {"s": "q:dh_gwak", "t": "야행국 사람이오? 마침 잘 왔소. 밤마다 이삭 도깨비들이 볏단을 물어 가오."}, {"s": "q:dh_gwak", "t": "한두 단이면 눈감겠는데, 올해는 벌써 열 단이 넘소. 겨울을 못 나겠소."}, {"s": "me", "t": "어디로 가져가는지 보셨습니까?"}, {"s": "q:dh_gwak", "t": "그걸 알면 내가 쫓아갔지. 일단 놈들부터 좀 혼내 주시오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_field_outskirts_1$q$, 2, $q$도깨비 쫓기$q$, $q$이삭 도깨비 3마리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_field_outskirts_2"], "n": 3}], "at": ["field_outskirts"]}$q$::jsonb, $q$[{"s": null, "t": "쓰러진 도깨비들 품에서 볏짚 끈으로 곱게 묶은 이삭 다발이 굴러 나온다."}, {"s": "q:dh_gwak", "t": "이상하구려. 훔친 놈들이 이삭을 이렇게 정성껏 묶소?"}, {"s": "q:dh_gwak", "t": "이 매듭은 우리 집 머슴 덕삼이가 쓰던 매듭이오. 삼 년 전에 죽은 놈이오."}, {"s": "me", "t": "다발이 가던 쪽을 따라가 보겠습니다."}]$q$::jsonb, $q${"xp": 22}$q$::jsonb),
  ($q$sq_field_outskirts_1$q$, 3, $q$들녘 끝의 봉분$q$, $q$잿빛 들녘을 2번 탐색해 이삭이 가던 곳을 찾는다$q$, $q${"tasks": [{"t": "search", "r": ["field_outskirts"], "n": 2}], "at": ["field_outskirts"]}$q$::jsonb, $q$[{"s": null, "t": "들녘 끝, 잡초에 덮인 작은 봉분 앞에 이삭 다발이 수북이 쌓여 있다."}, {"s": "q:dh_gwak", "t": "덕삼이 무덤이로군. 품삯을 다 못 주고 보냈지. 흉년이라고 핑계를 댔소."}, {"s": "q:dh_gwak", "t": "도깨비들이 그 녀석 대신 제 몫을 챙겨 온 모양이오."}, {"s": "q:dh_gwak", "t": "올해 첫 쌀은 여기 먼저 놓겠소. 그러면 놈들도 더는 안 오겠지."}, {"s": null, "t": "바람이 지나가자 봉분 위 이삭들이 고개를 숙이듯 흔들린다."}]$q$::jsonb, $q${"xp": 22, "gil": 9, "items": {"travel_ration": 2}}$q$::jsonb),
  ($q$sq_field_outskirts_2$q$, 1, $q$빈 바구니$q$, $q$순찰 의원 연옥이에게 사정을 듣는다$q$, $q${"at": ["field_outskirts"]}$q$::jsonb, $q$[{"s": "q:dh_yeonok", "t": "아, 조사원님! 잠깐만요. 바구니가 텅 비어서요."}, {"s": "q:dh_yeonok", "t": "어젯밤 들쥐 요괴 떼에 물린 순찰대원이 셋이에요. 약을 다 써 버렸어요."}, {"s": "q:dh_yeonok", "t": "야령초랑 약제 바탕만 있으면 제가 바로 달일 수 있어요."}, {"s": "me", "t": "어디서 캐면 됩니까?"}, {"s": "q:dh_yeonok", "t": "들녘 둑길 아래요. 쥐떼가 다니는 길이니까 조심하세요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_field_outskirts_2$q$, 2, $q$둑길 약초$q$, $q$잿빛 들녘에서 야령초와 약제 바탕을 캐 온다$q$, $q${"tasks": [{"t": "gather", "items": ["herb"], "r": ["field_outskirts"], "n": 3}, {"t": "gather", "items": ["medicine_base"], "r": ["field_outskirts"], "n": 2}], "at": ["field_outskirts"], "give": {"herb": 3, "medicine_base": 2}}$q$::jsonb, $q$[{"s": "q:dh_yeonok", "t": "와, 잎이 싱싱해요. 이슬 맞은 걸로만 골라 오셨네요."}, {"s": "q:dh_yeonok", "t": "그런데 제가 손이 두 개뿐이라서요. 영초 차 한 주전자만 같이 달여 주실래요?"}, {"s": "me", "t": "어렵지 않습니다."}]$q$::jsonb, $q${"xp": 22}$q$::jsonb),
  ($q$sq_field_outskirts_2$q$, 3, $q$한 주전자$q$, $q$영초 차를 1번 만들어 연옥이에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["spirit_tea"], "n": 1}], "at": ["field_outskirts"], "give": {"spirit_tea": 1}}$q$::jsonb, $q$[{"s": null, "t": "연옥이가 차를 받아 들고 김을 한 번 맡아 본다."}, {"s": "q:dh_yeonok", "t": "향이 좋아요. 다친 분들이 이거 마시면 오늘 밤은 푹 주무실 거예요."}, {"s": "q:dh_yeonok", "t": "사실 저도 순찰대원이었어요. 칼을 못 쥐어서 바구니를 쥔 거예요."}, {"s": "q:dh_yeonok", "t": "그래도 이쪽이 더 많이 살린다고, 요즘은 그렇게 생각해요."}]$q$::jsonb, $q${"xp": 22, "gil": 9, "items": {"spirit_tea": 2}}$q$::jsonb),
  ($q$sq_hq_dorm_1$q$, 1, $q$식은 부뚜막$q$, $q$본부 객사의 찬모 복례를 만난다$q$, $q${"at": ["hq_dorm"]}$q$::jsonb, $q$[{"s": "q:dh_bokrye", "t": "거기 젊은이, 밥은 먹고 다니우? 얼굴이 반쪽이네."}, {"s": "q:dh_bokrye", "t": "오늘 밤 들녘 숙직 나가는 아이들 먹일 건량을 싸야 하는데, 재료가 떨어졌수."}, {"s": "q:dh_bokrye", "t": "들녘에 나가서 야령초 좀 뜯어 오구려. 나물로 섞으면 속이 든든해."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_hq_dorm_1$q$, 2, $q$들녘 나물$q$, $q$잿빛 들녘에서 야령초를 3번 캐 온다$q$, $q${"tasks": [{"t": "gather", "items": ["herb"], "r": ["field_outskirts"], "n": 3}], "at": ["hq_dorm"], "give": {"herb": 3}}$q$::jsonb, $q$[{"s": "q:dh_bokrye", "t": "옳지, 이 정도면 됐네. 손도 깨끗하고."}, {"s": "q:dh_bokrye", "t": "이번엔 직접 싸 보우. 건량 싸는 법은 조사원이면 다 알아야 해."}, {"s": "q:dh_bokrye", "t": "길에서 굶으면 칼도 부적도 소용없어."}]$q$::jsonb, $q${"xp": 22}$q$::jsonb),
  ($q$sq_hq_dorm_1$q$, 3, $q$손수 싼 건량$q$, $q$노정 건량을 2번 만들어 복례에게 맡긴다$q$, $q${"tasks": [{"t": "craft", "items": ["travel_ration"], "n": 2}], "at": ["hq_dorm"], "give": {"travel_ration": 2}}$q$::jsonb, $q$[{"s": null, "t": "복례가 건량 꾸러미를 하나하나 풀어 보고 다시 묶는다."}, {"s": "q:dh_bokrye", "t": "모양은 좀 엉성해도 꽉 찼네. 됐수."}, {"s": "q:dh_bokrye", "t": "옛날엔 이걸 싸 들고 나갔다가 안 돌아온 아이들도 많았지."}, {"s": "q:dh_bokrye", "t": "그러니 젊은이는 꼭 빈 꾸러미 들고 돌아와요. 그게 내 품삯이우."}]$q$::jsonb, $q${"xp": 22, "gil": 9, "items": {"travel_ration": 3}}$q$::jsonb),
  ($q$sq_hq_dorm_2$q$, 1, $q$비어 있던 방$q$, $q$객사지기 노철에게 그날 밤 이야기를 듣는다$q$, $q${"at": ["hq_dorm"]}$q$::jsonb, $q$[{"s": "q:dh_cheol", "t": "인장 일로 오셨소? 그날 밤 열두 번째 방 손님이 해 뜨기 전에 나갔소."}, {"s": "q:dh_cheol", "t": "숙박부에 이름을 적었는데, 아침에 보니 그 칸만 젖어서 번졌더군."}, {"s": "q:dh_cheol", "t": "신발 바닥에 들녘 흙이 붙어 있었소. 잿빛이 도는 흙 말이오."}, {"s": "me", "t": "들녘으로 나갔다는 말씀이군요."}, {"s": "q:dh_cheol", "t": "내 눈엔 그렇게 보였소. 한 감찰관께는 아직 말씀 못 드렸소."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_hq_dorm_2$q$, 2, $q$잿빛 발자국$q$, $q$잿빛 들녘을 3번 탐색하고 단서 하나를 찾는다$q$, $q${"tasks": [{"t": "search", "r": ["field_outskirts"], "n": 3}, {"t": "clue", "n": 1}], "at": ["hq_dorm"]}$q$::jsonb, $q$[{"s": null, "t": "들녘 둑길에서 찾은 것은 물에 불은 숙박부 한 장이다. 먹물에서 물비린내가 난다."}, {"s": "q:dh_cheol", "t": "이건 우리 객사 종이요. 누가 찢어 갔구려."}, {"s": "q:dh_cheol", "t": "이름 칸이… 지워진 게 아니라 처음부터 비어 있었던 것 같소."}, {"s": "q:dh_cheol", "t": "이름 없는 손님이라. 내가 사십 년 지기 노릇에 처음 보는 일이오."}]$q$::jsonb, $q${"xp": 99}$q$::jsonb),
  ($q$sq_hq_dorm_2$q$, 3, $q$감찰관에게$q$, $q$본부 정청의 감찰관 한설에게 숙박부를 넘긴다$q$, $q${"at": ["hq_yard"]}$q$::jsonb, $q$[{"s": "night_office:han", "t": "숙박부의 빈 칸이라. 규정대로라면 이름 없는 자는 객사에 들 수 없습니다."}, {"s": "night_office:han", "t": "그런데 들었다. 누군가 문을 열어 주었다는 뜻이지요."}, {"s": "night_office:han", "t": "이 종이는 제가 맡겠습니다. 객사지기에게는 입을 닫으라 전하십시오."}, {"s": null, "t": "한설은 종이를 접어 품에 넣는다. 그 손끝이 잠깐 멈칫한다."}]$q$::jsonb, $q${"gil": 13, "items": {"ward_talisman": 1}}$q$::jsonb),
  ($q$sq_hq_training_1$q$, 1, $q$떠드는 교관$q$, $q$연무장의 교관 강두철을 만난다$q$, $q${"at": ["hq_training"]}$q$::jsonb, $q$[{"s": "night_office:kang", "t": "하하! 신참이로군! 마침 잘 왔다!"}, {"s": "night_office:kang", "t": "연무장 목인들이 밤마다 혼자 칼을 휘두른다. 내가 너무 잘 가르쳤나 봐!"}, {"s": "night_office:kang", "t": "농담이고, 목인귀가 씌었다. 두어 놈 부수고 오너라. 훈련 삼아서!"}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_hq_training_1$q$, 2, $q$목인 부수기$q$, $q$목인귀 2마리와 허수아비 귀 2마리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_01"], "n": 2}, {"t": "win", "m": ["g_hq_training"], "n": 2}], "at": ["hq_training"]}$q$::jsonb, $q$[{"s": "night_office:kang", "t": "오, 손이 맵구나! 그런데 이상하지 않더냐?"}, {"s": "me", "t": "목인들이 하나같이 팔괘진 한가운데를 향해 서 있었습니다."}, {"s": "night_office:kang", "t": "그렇지. 대장이 있다는 뜻이다. 팔괘진 목인장, 그놈이 졸개들을 깨운다."}, {"s": "night_office:kang", "t": "그놈까지 눕히면 오늘 훈련은 끝이다!"}]$q$::jsonb, $q${"xp": 22}$q$::jsonb),
  ($q$sq_hq_training_1$q$, 3, $q$팔괘진의 장수$q$, $q$팔괘진 목인장을 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["hq_training"], "rank": "guardian", "n": 1}], "at": ["hq_training"]}$q$::jsonb, $q$[{"s": null, "t": "부서진 목인장의 가슴께에 낡은 이름표가 새겨져 있다. 오래전 교관의 이름이다."}, {"s": "night_office:kang", "t": "…내 스승님 이름이로군. 저 목인은 스승님이 손수 깎으셨지."}, {"s": "night_office:kang", "t": "가르치던 버릇이 나무에 배었나 보다. 아직 덜 가르치셨던 게지."}, {"s": "night_office:kang", "t": "하하, 잘했다. 스승님도 이제 좀 쉬시겠지."}]$q$::jsonb, $q${"xp": 22, "gil": 9, "items": {"clear_spirit_pill": 2}}$q$::jsonb),
  ($q$sq_hq_training_2$q$, 1, $q$빈 화살통$q$, $q$활터의 궁수 위소라를 만난다$q$, $q${"at": ["hq_training"]}$q$::jsonb, $q$[{"s": null, "t": "과녁 앞에 빈 화살통이 엎어져 있다. 과녁에는 쥐 이빨 자국이 가득하다."}, {"s": "q:dh_sora", "t": "과녁 쥐떼가 화살대를 갉아 먹었어요. 남은 게 없어요."}, {"s": "q:dh_sora", "t": "부적목을 좀 베어다 주세요. 깎는 건 직접 해 보시고요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_hq_training_2$q$, 2, $q$부적목 베기$q$, $q$연무장에서 부적목을 3번 베어 온다$q$, $q${"tasks": [{"t": "gather", "items": ["wood"], "r": ["hq_training"], "n": 3}], "at": ["hq_training"]}$q$::jsonb, $q$[{"s": "q:dh_sora", "t": "결이 곧네요. 좋아요."}, {"s": null, "t": "소라가 칼끝으로 나뭇결을 한 번 쓸어 보고 고개를 끄덕인다."}, {"s": "q:dh_sora", "t": "쥐떼가 또 오기 전에 깎아야 해요. 화살 두 묶음이면 돼요."}]$q$::jsonb, $q${"xp": 22}$q$::jsonb),
  ($q$sq_hq_training_2$q$, 3, $q$깎은 화살$q$, $q$화살을 2번 만들고 과녁 쥐떼 2마리를 쫓는다$q$, $q${"tasks": [{"t": "craft", "items": ["ammo_arrow"], "n": 2}, {"t": "win", "m": ["x_hq_training_1"], "n": 2}], "at": ["hq_training"]}$q$::jsonb, $q$[{"s": "q:dh_sora", "t": "직접 깎은 화살로 쏘면 손에 감이 오죠?"}, {"s": "q:dh_sora", "t": "전 원래 사냥꾼 딸이었어요. 아버지가 그랬어요. 화살은 깎은 사람을 닮는다고."}, {"s": "q:dh_sora", "t": "조사원님 화살은… 조금 삐뚤어도 끝까지 날아가네요."}, {"s": null, "t": "소라가 처음으로 입꼬리를 올린다."}]$q$::jsonb, $q${"xp": 22, "gil": 9, "items": {"ammo_arrow": 1}}$q$::jsonb),
  ($q$sq_hq_yard_1$q$, 1, $q$빛바랜 부적$q$, $q$정청 서리 문수에게 일을 받는다$q$, $q${"at": ["hq_yard"]}$q$::jsonb, $q$[{"s": "q:dh_munsu", "t": "조사원님! 정청 처마 부적이 다 바랬어요. 감찰관님이 오늘 안에 바꾸라세요."}, {"s": "q:dh_munsu", "t": "황지랑 부적실은 폐쇄 사당 쪽에서 나는 게 질이 좋아요."}, {"s": "q:dh_munsu", "t": "저는 못 가요. 거긴 까마귀가 무서워서요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_hq_yard_1$q$, 2, $q$사당의 종이와 실$q$, $q$폐쇄 사당에서 황지와 부적실을 모아 온다$q$, $q${"tasks": [{"t": "gather", "items": ["seal_paper"], "r": ["shrine_ruins"], "n": 3}, {"t": "gather", "items": ["talisman_thread"], "r": ["shrine_ruins"], "n": 2}], "at": ["hq_yard"]}$q$::jsonb, $q$[{"s": "q:dh_munsu", "t": "우와, 금줄 까마귀한테 안 쪼이셨어요?"}, {"s": null, "t": "문수가 황지를 햇빛에 비춰 보더니 조심스레 품에 안는다."}, {"s": "q:dh_munsu", "t": "이제 부적을 써 주셔야 해요. 저는 붓을 쥐면 손이 떨려서요."}]$q$::jsonb, $q${"xp": 82}$q$::jsonb),
  ($q$sq_hq_yard_1$q$, 3, $q$새 부적$q$, $q$정화 부적을 2번 만들어 문수에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["ward_talisman"], "n": 2}], "at": ["hq_yard"], "give": {"ward_talisman": 2}}$q$::jsonb, $q$[{"s": null, "t": "문수가 사다리를 놓고 처마에 부적을 붙인다. 낡은 부적을 떼어 내자 뒷면에 작은 글씨가 보인다."}, {"s": "q:dh_munsu", "t": "어, 이거 보세요. 옛날 서리들이 이름을 적어 놨어요. 붙인 날짜랑요."}, {"s": "q:dh_munsu", "t": "그럼 저도 적어도 되겠죠? 조사원님 이름도 같이요."}, {"s": "q:dh_munsu", "t": "백 년 뒤에 누가 떼어 보면 알겠죠. 우리가 여기 있었다는 거."}]$q$::jsonb, $q${"xp": 82, "gil": 17, "items": {"ward_talisman": 1}}$q$::jsonb),
  ($q$sq_hq_yard_2$q$, 1, $q$감찰관의 지시$q$, $q$본부 정청의 감찰관 한설을 만난다$q$, $q${"at": ["hq_yard"]}$q$::jsonb, $q$[{"s": "night_office:han", "t": "붉은 인장 건의 후속 조사입니다. 보고는 짧게, 사실만."}, {"s": "night_office:han", "t": "폐쇄 사당의 금줄이 거꾸로 감겨 있다는 신고가 들어왔습니다. 봉인식을 뒤집은 흔적과 같은 방향입니다."}, {"s": "night_office:han", "t": "금줄식귀가 그 줄을 먹고 불어나고 있습니다. 정리하고, 남은 줄을 확인하십시오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_hq_yard_2$q$, 2, $q$금줄 먹는 귀신$q$, $q$금줄식귀 2마리와 금줄 까마귀 2마리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_shrine_1"], "n": 2}, {"t": "win", "m": ["g_shrine_ruins"], "n": 2}], "at": ["shrine_ruins"]}$q$::jsonb, $q$[{"s": null, "t": "금줄식귀가 흩어진 자리에 반쯤 먹힌 금줄이 남아 있다. 매듭이 모두 왼쪽으로 꼬였다."}, {"s": "me", "t": "매듭을 꼰 손이 하나입니다. 같은 버릇이 일곱 번 반복됩니다."}, {"s": null, "t": "매듭 사이에 젖은 먹물 자국이 묻어 있다. 물비린내가 아직 가시지 않았다."}]$q$::jsonb, $q${"xp": 99}$q$::jsonb),
  ($q$sq_hq_yard_2$q$, 3, $q$사실만$q$, $q$본부 정청에 돌아가 한설에게 보고한다$q$, $q${"at": ["hq_yard"]}$q$::jsonb, $q$[{"s": "night_office:han", "t": "왼쪽으로 일곱 번. 야행국 봉인사들이 배우는 매듭입니다."}, {"s": "night_office:han", "t": "외부인 짓이라는 가정은 이제 지웁니다."}, {"s": "night_office:han", "t": "이 보고는 도제조께만 올리겠습니다. 수고했습니다. 그리고, 아무에게도 말하지 마십시오."}]$q$::jsonb, $q${"gil": 13, "items": {"ward_talisman": 1, "clear_spirit_pill": 1}}$q$::jsonb),
  ($q$sq_lantern_market_1$q$, 1, $q$기운 없는 약방$q$, $q$백등 야시장의 약방 할멈 고분을 만난다$q$, $q${"at": ["lantern_market"]}$q$::jsonb, $q$[{"s": "q:dh_gopun", "t": "어이구, 손님이 아니라 조사원이로구먼. 차 한 잔 하겠수? 미안하우, 물밖에 없네."}, {"s": "q:dh_gopun", "t": "허리가 결려서 들녘에 못 나갔더니 약초가 떨어졌수."}, {"s": "q:dh_gopun", "t": "야령초 좀 뜯어다 주면 내가 영초 차 달이는 법을 가르쳐 주리다."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_lantern_market_1$q$, 2, $q$들녘 야령초$q$, $q$잿빛 들녘에서 야령초를 4번 캐 온다$q$, $q${"tasks": [{"t": "gather", "items": ["herb"], "r": ["field_outskirts"], "n": 4}], "at": ["lantern_market"]}$q$::jsonb, $q$[{"s": "q:dh_gopun", "t": "잎 뒤가 하얀 것만 골라 왔구먼. 눈썰미가 있수."}, {"s": null, "t": "고분이 화로에 숯을 넣고 작은 약탕기를 올린다."}, {"s": "q:dh_gopun", "t": "자, 불은 약하게, 물은 넉넉히. 끓기 직전에 내리는 거유."}]$q$::jsonb, $q${"xp": 22}$q$::jsonb),
  ($q$sq_lantern_market_1$q$, 3, $q$달인 차$q$, $q$영초 차를 2번 만들어 고분에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["spirit_tea"], "n": 2}], "at": ["lantern_market"], "give": {"spirit_tea": 2}}$q$::jsonb, $q$[{"s": null, "t": "고분이 차를 병에 나눠 담다가 낡은 장부 하나를 펼친다. 외상 이름이 빼곡하다."}, {"s": "q:dh_gopun", "t": "이 사람들 반은 갚으러 못 왔수. 야행국 사람들이었거든."}, {"s": "q:dh_gopun", "t": "그래도 장부는 안 지워. 지우면 정말 없던 사람이 되잖수."}, {"s": "q:dh_gopun", "t": "자네 이름은 외상 칸 말고 손님 칸에 적어 둘게. 또 오우."}]$q$::jsonb, $q${"xp": 22, "gil": 9, "items": {"spirit_tea": 2, "clear_spirit_pill": 1}}$q$::jsonb),
  ($q$sq_lantern_market_2$q$, 1, $q$꺼진 등 하나$q$, $q$등롱 장인 마일수를 만난다$q$, $q${"at": ["lantern_market"]}$q$::jsonb, $q$[{"s": null, "t": "줄지어 걸린 흰 등 가운데 하나만 불이 꺼져 있다."}, {"s": "q:dh_ilsu", "t": "저 등은 뼈대가 녹슬어 주저앉았소. 쉰 해를 버텼으니 할 만큼 했지."}, {"s": "q:dh_ilsu", "t": "새로 짜려면 월철이 필요하오. 들녘 바위틈에 광석이 드러난 데가 있소."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_lantern_market_2$q$, 2, $q$들녘 바위틈$q$, $q$잿빛 들녘에서 월철 광석과 생 월철을 캔다$q$, $q${"tasks": [{"t": "gather", "items": ["ore"], "r": ["field_outskirts"], "n": 3}, {"t": "gather", "items": ["raw_iron"], "r": ["field_outskirts"], "n": 2}], "at": ["lantern_market"], "give": {"ore": 3, "raw_iron": 2}}$q$::jsonb, $q$[{"s": "q:dh_ilsu", "t": "좋은 쇠요. 이걸로 뼈대를 짜면 또 쉰 해는 가겠소."}, {"s": "q:dh_ilsu", "t": "등에는 다 이름이 있소. 저 꺼진 등은 '순덕'이오. 내 처 이름이지."}, {"s": "q:dh_ilsu", "t": "오늘 밤 다시 켜면 첫 불은 자네가 붙여 주시오."}]$q$::jsonb, $q${"xp": 45}$q$::jsonb),
  ($q$sq_lantern_market_2$q$, 3, $q$다시 켠 등$q$, $q$등롱 장인 마일수에게 돌아가 등을 켠다$q$, $q${"at": ["lantern_market"]}$q$::jsonb, $q$[{"s": null, "t": "새 뼈대에 한지를 바른 등에 불이 들어온다. 야시장 한 줄이 다시 고르게 빛난다."}, {"s": "q:dh_ilsu", "t": "됐소. 순덕이가 웃는구려."}, {"s": "q:dh_ilsu", "t": "등은 사람을 오래 기억하오. 그래서 내가 이 일을 놓질 못하오."}]$q$::jsonb, $q${"gil": 9, "items": {"repair_kit": 1}}$q$::jsonb),
  ($q$sq_hq_archive_1$q$, 1, $q$구멍 난 책$q$, $q$장서각 지하서고의 기록관 모가람을 만난다$q$, $q${"at": ["hq_archive"]}$q$::jsonb, $q$[{"s": "night_office:mo", "t": "아이고, 와 줘서 고마워요! 이것 좀 봐요, 이것 좀!"}, {"s": "night_office:mo", "t": "책벌레 요괴가 백 년 치 순찰 일지를 갉아 먹었어요. 구멍이 숭숭해요."}, {"s": "night_office:mo", "t": "정제 황지랑 먹정이 있으면 메울 수 있어요. 서고 안쪽 습한 데 많아요. 벌레도 많고요."}, {"s": "night_office:mo", "t": "아, 벌레는 보이는 대로 좀 잡아 주시고요!"}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_hq_archive_1$q$, 2, $q$종이와 먹$q$, $q$지하서고에서 정제 황지와 먹정을 모으고 책벌레 요괴를 잡는다$q$, $q${"tasks": [{"t": "gather", "items": ["fine_paper"], "r": ["hq_archive"], "n": 3}, {"t": "gather", "items": ["inkstone"], "r": ["hq_archive"], "n": 2}, {"t": "win", "m": ["g_hq_archive"], "n": 2}], "at": ["hq_archive"], "give": {"fine_paper": 3, "inkstone": 2}}$q$::jsonb, $q$[{"s": "night_office:mo", "t": "이 정도면 충분해요! 어디 보자, 이 일지는 누구 거였더라…"}, {"s": null, "t": "모가람이 메운 종이 위에 원래 글자를 한 자씩 옮겨 적는다."}, {"s": "night_office:mo", "t": "기록은 고치는 게 아니라 이어 붙이는 거예요. 원래 쓴 사람 글씨 옆에 내 글씨를요."}, {"s": "night_office:mo", "t": "언젠가 누가 내 글씨 옆에도 이어 써 주겠죠. 그럼 된 거예요."}]$q$::jsonb, $q${"xp": 99, "gil": 13, "items": {"fine_paper": 2}}$q$::jsonb),
  ($q$sq_hq_archive_2$q$, 1, $q$지워진 칸$q$, $q$기록관 모가람에게 빈 서가 이야기를 듣는다$q$, $q${"at": ["hq_archive"]}$q$::jsonb, $q$[{"s": "night_office:mo", "t": "붉은 인장 장부가 빠진 서가 있잖아요. 그 칸, 제가 매일 닦았거든요."}, {"s": "night_office:mo", "t": "그런데 오늘 보니 먼지 위에 손자국이 있었어요. 장부가 사라진 다음에요."}, {"s": "night_office:mo", "t": "누가 또 왔다는 거죠. 뭘 찾으러 왔을까요?"}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_hq_archive_2$q$, 2, $q$서고 뒤지기$q$, $q$지하서고를 3번 탐색하고 단서 하나를 찾는다$q$, $q${"tasks": [{"t": "search", "r": ["hq_archive"], "n": 3}, {"t": "clue", "n": 1}], "at": ["hq_archive"]}$q$::jsonb, $q$[{"s": null, "t": "서가 아래 틈에서 죽간 한 조각이 나온다. 글자가 스스로 꿈틀거리며 흐려진다."}, {"s": "night_office:mo", "t": "탈명 죽간이에요! 이름을 빨아 먹는 죽간. 이게 왜 여기…"}, {"s": "night_office:mo", "t": "누가 일부러 두고 간 거예요. 장부에 남은 이름들을 지우라고요."}]$q$::jsonb, $q${"xp": 50}$q$::jsonb),
  ($q$sq_hq_archive_2$q$, 3, $q$이름 먹는 죽간$q$, $q$탈명 죽간 2마리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_archive"], "n": 2}], "at": ["hq_archive"]}$q$::jsonb, $q$[{"s": null, "t": "죽간이 부서지자 빨려 들어갔던 글자들이 먹물처럼 흘러나와 서가에 스민다."}, {"s": "night_office:mo", "t": "돌아왔어요. 다는 아니지만… 이 이름은 읽혀요."}, {"s": "night_office:mo", "t": "그런데 이상해요. 맨 끝에 적힌 이름 하나는 처음부터 빈칸이었어요. 이름 없이 서명만 있어요."}, {"s": "night_office:mo", "t": "이건 한설 감찰관님께 가져가요. 저는… 오늘부터 서고에서 잘래요."}]$q$::jsonb, $q${"xp": 50, "gil": 13, "items": {"fine_paper": 2, "ward_talisman": 1}}$q$::jsonb),
  ($q$sq_shrine_ruins_1$q$, 1, $q$방울 없는 무녀$q$, $q$폐쇄 사당의 혼백 가을을 만난다$q$, $q${"at": ["shrine_ruins"]}$q$::jsonb, $q$[{"s": null, "t": "무너진 신당 앞, 희미한 소녀의 모습이 맨손으로 방울을 흔드는 시늉을 한다."}, {"s": "q:dh_gaeul", "t": "언니, 제 방울 못 보셨어요? 산문이 무너질 때 깨졌어요."}, {"s": "q:dh_gaeul", "t": "조각이 사당 곳곳에 흩어졌어요. 결계 파편이 된 거예요."}, {"s": "q:dh_gaeul", "t": "모아 주시면 다시 울릴 수 있을지도 몰라요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_shrine_ruins_1$q$, 2, $q$흩어진 조각$q$, $q$폐쇄 사당에서 결계 파편과 요기 결정을 모은다$q$, $q${"tasks": [{"t": "gather", "items": ["ward_fragment"], "r": ["shrine_ruins"], "n": 3}, {"t": "gather", "items": ["spirit_dust"], "r": ["shrine_ruins"], "n": 2}], "at": ["shrine_ruins"], "give": {"ward_fragment": 3, "spirit_dust": 2}}$q$::jsonb, $q$[{"s": null, "t": "가을이 조각을 손바닥에 받는다. 조각들이 서로 붙으려다 다시 떨어진다."}, {"s": "q:dh_gaeul", "t": "모자라요. 방울 속 구슬이 없어요."}, {"s": "q:dh_gaeul", "t": "방울먹는 무녀귀가 가져갔어요. 저랑 같이 일하던 언니였는데… 이젠 아니에요."}]$q$::jsonb, $q${"xp": 99, "gil": 13, "items": {"spirit_dust": 2}}$q$::jsonb),
  ($q$sq_shrine_ruins_2$q$, 1, $q$언니였던 것$q$, $q$혼백 가을에게 무녀귀 이야기를 듣는다$q$, $q${"at": ["shrine_ruins"]}$q$::jsonb, $q$[{"s": "q:dh_gaeul", "t": "언니는 방울 소리가 무섭다고 했어요. 소리가 나면 뭔가 온다고요."}, {"s": "q:dh_gaeul", "t": "그래서 사당 방울을 다 삼켜 버렸어요. 그러다 저렇게 됐어요."}, {"s": "q:dh_gaeul", "t": "언니를 아프게 하지 말라고는 못 하겠어요. 그냥… 쉬게 해 주세요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_shrine_ruins_2$q$, 2, $q$무녀귀$q$, $q$방울먹는 무녀귀 2마리와 촛농 도깨비불 2마리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_shrine_2"], "n": 2}, {"t": "win", "m": ["x_shrine_ruins_1"], "n": 2}], "at": ["shrine_ruins"]}$q$::jsonb, $q$[{"s": null, "t": "쓰러진 무녀귀의 목에서 작은 구슬이 굴러 나온다. 굴러가며 맑은 소리를 낸다."}, {"s": "me", "t": "구슬을 찾았습니다. 그런데 산문 쪽에서 무언가 움직입니다."}, {"s": "q:dh_gaeul", "t": "산문 파쇄귀예요. 방울 소리가 나면 오는 게 바로 저거예요. 언니 말이 맞았어요."}]$q$::jsonb, $q${"xp": 82}$q$::jsonb),
  ($q$sq_shrine_ruins_2$q$, 3, $q$산문을 지킨다$q$, $q$산문 파쇄귀를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["shrine_ruins"], "rank": "guardian", "n": 1}], "at": ["shrine_ruins"]}$q$::jsonb, $q$[{"s": null, "t": "가을이 붙여 놓은 방울을 흔든다. 오래 멈췄던 소리가 사당 마당에 번진다."}, {"s": "q:dh_gaeul", "t": "언니는 무서워서 방울을 삼켰고, 저는 무서워서 방울만 찾았어요."}, {"s": "q:dh_gaeul", "t": "언니가 이제 대신 들어 줬으면 좋겠어요. 이 소리요."}, {"s": null, "t": "소리가 잦아들 무렵, 소녀의 모습도 함께 옅어진다."}]$q$::jsonb, $q${"xp": 82, "gil": 17, "items": {"ward_talisman": 2}}$q$::jsonb),
  ($q$sq_old_canal_1$q$, 1, $q$열지 않는 수문$q$, $q$수문지기 염수칠을 만난다$q$, $q${"at": ["old_canal"]}$q$::jsonb, $q$[{"s": "q:dh_suchil", "t": "배가 안 들어오는구먼. 오늘도 안 들어와."}, {"s": "q:dh_suchil", "t": "수문 열 시간까지 기다려야 하는데 배가 고파서 원. 고기 좀 낚아 주겠나?"}, {"s": "q:dh_suchil", "t": "흑잉어가 잘 물어. 수문 아래 그늘에서."}, {"s": null, "t": "수문은 이십 년 전에 용접되어 닫혔다. 노인은 그 말을 듣지 않은 얼굴이다."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_old_canal_1$q$, 2, $q$수문 아래$q$, $q$구룡 폐수로에서 물고기를 3번 낚는다$q$, $q${"tasks": [{"t": "fish", "r": ["old_canal"], "n": 3}], "at": ["old_canal"]}$q$::jsonb, $q$[{"s": "q:dh_suchil", "t": "허허, 손맛 좋지? 옛날엔 뱃사공들이 줄 서서 낚았다네."}, {"s": null, "t": "노인이 비늘 젖은 흑잉어를 들어 수문 쪽에 한 번 보여 준다. 누구에게 보여 주는지는 말하지 않는다."}, {"s": "q:dh_suchil", "t": "손질 좀 해 주게. 내 손은 요즘 칼을 못 쥐어."}]$q$::jsonb, $q${"xp": 82}$q$::jsonb),
  ($q$sq_old_canal_1$q$, 3, $q$저녁상$q$, $q$손질한 생선을 2번 만들어 수칠에게 차린다$q$, $q${"tasks": [{"t": "craft", "items": ["fish_fillet"], "n": 2}], "at": ["old_canal"], "give": {"fish_fillet": 2}}$q$::jsonb, $q$[{"s": null, "t": "노인이 생선을 한 점 먹고 오래 수문을 바라본다."}, {"s": "q:dh_suchil", "t": "…닫혔지. 알아. 이십 년 전에."}, {"s": "q:dh_suchil", "t": "그래도 누가 지키고 있어야 혹시 배가 와도 헤매지 않지 않겠나."}, {"s": "q:dh_suchil", "t": "잘 먹었네. 내일도 배는 안 오겠지만, 내일도 기다릴 거라네."}]$q$::jsonb, $q${"xp": 82, "gil": 17, "items": {"grilled_fish": 2}}$q$::jsonb),
  ($q$sq_old_canal_2$q$, 1, $q$소문 하나$q$, $q$뱃사공 노들 영감에게 이야기를 듣는다$q$, $q${"at": ["old_canal"]}$q$::jsonb, $q$[{"s": "river_alliance:nodeul", "t": "젖은 장부 뒤를 쫓는다며? 그 장부, 폐수로를 지날 때 한 장이 떨어졌다네."}, {"s": "river_alliance:nodeul", "t": "수문아귀 놈이 냉큼 삼켰지. 놈은 종이든 사람이든 가리지 않거든."}, {"s": "river_alliance:nodeul", "t": "배를 갈라 보면 아직 남아 있을 걸세. 놈 위장은 느려."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_old_canal_2$q$, 2, $q$아귀 사냥$q$, $q$수문아귀 3마리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_04"], "n": 3}], "at": ["old_canal"]}$q$::jsonb, $q$[{"s": null, "t": "세 번째 수문아귀의 배 속에서 반쯤 녹은 종이 한 장이 나온다. 붉은 먹으로 찍힌 반달 모양 자국."}, {"s": "me", "t": "붉은 달 인장의 반쪽입니다."}, {"s": "river_alliance:nodeul", "t": "허, 반쪽이라. 나머지 반은 물살 따라 내려갔겠구먼."}]$q$::jsonb, $q${"xp": 160}$q$::jsonb),
  ($q$sq_old_canal_2$q$, 3, $q$물살의 끝$q$, $q$구룡 폐수로를 2번 탐색하고 수문 거머리왕을 쓰러뜨린다$q$, $q${"tasks": [{"t": "search", "r": ["old_canal"], "n": 2}, {"t": "win", "r": ["old_canal"], "rank": "guardian", "n": 1}], "at": ["old_canal"]}$q$::jsonb, $q$[{"s": null, "t": "수문 거머리왕이 쓰러진 자리에는 종이 대신 뱃삯 표 한 장이 붙어 있다. 수향 뱃길 표다."}, {"s": "river_alliance:nodeul", "t": "이 표는 염등촌 나루에서 끊는 거라네. 누가 장부를 들고 배를 탔다는 얘기지."}, {"s": "river_alliance:nodeul", "t": "오십 년 노를 저었지만 장부 들고 도망치는 손님은 늘 같은 얼굴이야. 뒤를 자꾸 돌아보는 얼굴."}]$q$::jsonb, $q${"xp": 160, "gil": 25, "items": {"clear_spirit_pill": 2, "travel_ration": 1}}$q$::jsonb),
  ($q$sq_paper_bridge_1$q$, 1, $q$난간의 아이$q$, $q$백지교의 아이 보미를 만난다$q$, $q${"at": ["paper_bridge"]}$q$::jsonb, $q$[{"s": null, "t": "다리 난간에 아이 하나가 앉아 종이학을 접는다. 발밑 강물에 종이학이 잔뜩 떠내려간다."}, {"s": "q:dh_bomi", "t": "천 마리를 접으면 소원이 이뤄진대요. 구백일흔 마리째예요."}, {"s": "q:dh_bomi", "t": "그런데 종이가 떨어졌어요. 황지랑 고운 종이 좀 구해 주실래요?"}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_paper_bridge_1$q$, 2, $q$다리 밑 종이$q$, $q$백지교에서 정제 황지와 황지를 모은다$q$, $q${"tasks": [{"t": "gather", "items": ["fine_paper"], "r": ["paper_bridge"], "n": 3}, {"t": "gather", "items": ["seal_paper"], "r": ["paper_bridge"], "n": 2}], "at": ["paper_bridge"], "give": {"fine_paper": 3, "seal_paper": 2}}$q$::jsonb, $q$[{"s": "q:dh_bomi", "t": "고마워요. 이제 서른 마리만 더 접으면 돼요."}, {"s": null, "t": "아이의 종이학이 날개를 펴자 다리 위 종이학 무리가 일제히 고개를 돌린다."}, {"s": "q:dh_bomi", "t": "쟤들이 제 학을 먹어요. 다 접기 전에 좀 쫓아 주세요."}]$q$::jsonb, $q${"xp": 82}$q$::jsonb),
  ($q$sq_paper_bridge_1$q$, 3, $q$천 번째 학$q$, $q$종이학 무리 3마리를 쫓는다$q$, $q${"tasks": [{"t": "win", "m": ["g_paper_bridge"], "n": 3}], "at": ["paper_bridge"]}$q$::jsonb, $q$[{"s": null, "t": "천 번째 종이학이 아이 손을 떠나 강물 위로 날아오른다."}, {"s": "me", "t": "무슨 소원을 빌었니?"}, {"s": "q:dh_bomi", "t": "엄마가 저를 찾게 해 달라고요. 엄마는 이 다리를 건너다 길을 잃었대요."}, {"s": "q:dh_bomi", "t": "아니다, 제가 길을 잃은 거였나…"}, {"s": null, "t": "다시 돌아보니 난간에는 접다 만 종이 한 장만 남아 있다."}]$q$::jsonb, $q${"xp": 82, "gil": 17, "items": {"fine_paper": 2, "spirit_tea": 1}}$q$::jsonb),
  ($q$sq_paper_bridge_2$q$, 1, $q$검게 물든 강$q$, $q$기록관 모가람의 부탁을 듣는다$q$, $q${"at": ["paper_bridge"]}$q$::jsonb, $q$[{"s": "night_office:mo", "t": "백지교 아래 물이 유난히 검어졌대요. 장부가 물에 젖은 그 무렵부터요."}, {"s": "night_office:mo", "t": "먹물 메기들이 그 먹을 먹고 컸을 거예요. 배 속 먹을 보면 어떤 먹인지 알 수 있어요!"}, {"s": "night_office:mo", "t": "낚아서 손질해 오시면 제가 먹을 걸러 볼게요. 비린 건… 참을게요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_paper_bridge_2$q$, 2, $q$검은 물$q$, $q$백지교에서 물고기를 4번 낚는다$q$, $q${"tasks": [{"t": "fish", "r": ["paper_bridge"], "n": 4}], "at": ["paper_bridge"]}$q$::jsonb, $q$[{"s": null, "t": "낚아 올린 고기 비늘마다 먹물이 번져 있다. 손에 묻은 먹이 쉽게 지워지지 않는다."}, {"s": "me", "t": "보통 먹이 아닙니다. 물에 풀려도 글자 모양으로 엉깁니다."}, {"s": null, "t": "엉긴 먹 사이로 숫자 몇 개가 언뜻 비쳤다가 물살에 흩어진다."}]$q$::jsonb, $q${"xp": 160}$q$::jsonb),
  ($q$sq_paper_bridge_2$q$, 3, $q$먹 거르기$q$, $q$손질한 생선을 2번 만들어 모가람에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["fish_fillet"], "n": 2}], "at": ["paper_bridge"], "give": {"fish_fillet": 2}}$q$::jsonb, $q$[{"s": "night_office:mo", "t": "이건… 야행국 장부 먹이 아니에요. 바닷소금이 섞인 먹이에요."}, {"s": "night_office:mo", "t": "염등촌 쪽 먹이요. 장부를 고쳐 쓴 사람이 거기서 먹을 샀다는 뜻이에요."}, {"s": "night_office:mo", "t": "생선은 제가 구워 먹을게요. 증거물이지만 아까우니까요."}]$q$::jsonb, $q${"xp": 160, "gil": 25, "items": {"grilled_fish": 1, "fine_paper": 2}}$q$::jsonb),
  ($q$sq_sealed_garden_1$q$, 1, $q$담 밖의 약초꾼$q$, $q$약초꾼 남선화를 만난다$q$, $q${"at": ["sealed_garden"]}$q$::jsonb, $q$[{"s": "q:dh_seonhwa", "t": "안으로 들어가실 거죠? 부탁이 있어요."}, {"s": "q:dh_seonhwa", "t": "정원이 닫히기 전에 제가 가꾸던 밭이 있어요. 월광 이끼랑 영맥 수피가 아직 자랄 거예요."}, {"s": "q:dh_seonhwa", "t": "저는 들어갈 수 없어요. 봉인 명단에 제 이름이 올라 있거든요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_sealed_garden_1$q$, 2, $q$닫힌 정원의 밭$q$, $q$폐쇄된 연화원에서 월광 이끼와 영맥 수피를 거둔다$q$, $q${"tasks": [{"t": "gather", "items": ["moon_moss"], "r": ["sealed_garden"], "n": 3}, {"t": "gather", "items": ["spirit_bark"], "r": ["sealed_garden"], "n": 2}], "at": ["sealed_garden"], "give": {"moon_moss": 3, "spirit_bark": 2}}$q$::jsonb, $q$[{"s": "q:dh_seonhwa", "t": "그대로네요. 이끼 결이 제가 깔아 둔 돌 모양 그대로예요."}, {"s": "q:dh_seonhwa", "t": "누가 저 대신 계속 물을 준 것 같아요. 정원이 닫힌 지 십 년인데."}, {"s": "q:dh_seonhwa", "t": "고맙습니다. 이걸로 약을 하나 지어야 해요. 도와주시겠어요?"}]$q$::jsonb, $q${"xp": 163, "gil": 17, "items": {"moon_moss": 1}}$q$::jsonb),
  ($q$sq_sealed_garden_2$q$, 1, $q$잠 못 드는 밤$q$, $q$약초꾼 남선화의 이야기를 듣는다$q$, $q${"at": ["sealed_garden"]}$q$::jsonb, $q$[{"s": "q:dh_seonhwa", "t": "정원이 닫힌 날부터 잠을 못 자요. 안에 두고 온 게 있어서요."}, {"s": "q:dh_seonhwa", "t": "안신탕 한 사발이면 오늘은 잘 수 있을 것 같아요."}, {"s": "q:dh_seonhwa", "t": "약제 바탕도 이 근처에서 나요. 조금만 더 캐 주세요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_sealed_garden_2$q$, 2, $q$약 짓기$q$, $q$연화원에서 약제 바탕을 2번 캐고 안신탕을 1번 만든다$q$, $q${"tasks": [{"t": "gather", "items": ["medicine_base"], "r": ["sealed_garden"], "n": 2}, {"t": "craft", "items": ["calm_brew"], "n": 1}], "at": ["sealed_garden"], "give": {"calm_brew": 1}}$q$::jsonb, $q$[{"s": "q:dh_seonhwa", "t": "향이 맞아요. 제 스승님 약 향이에요."}, {"s": "q:dh_seonhwa", "t": "그런데 하나만 더요. 밭에 물을 준 게 누군지 알고 싶어요."}, {"s": "q:dh_seonhwa", "t": "밭가 흙이 늘 젖어 있었어요. 비가 오지 않은 날에도요."}]$q$::jsonb, $q${"xp": 82}$q$::jsonb),
  ($q$sq_sealed_garden_2$q$, 3, $q$밭을 지킨 것$q$, $q$연화원을 2번 탐색하고 덩굴 손 2마리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "search", "r": ["sealed_garden"], "n": 2}, {"t": "win", "m": ["g_sealed_garden"], "n": 2}], "at": ["sealed_garden"]}$q$::jsonb, $q$[{"s": null, "t": "밭가의 덩굴 손들이 쓰러지며 물동이 하나를 놓친다. 덩굴 끝에 낡은 은가락지가 감겨 있다."}, {"s": "q:dh_seonhwa", "t": "스승님 가락지예요. 정원이 닫힐 때 안에 남으셨어요."}, {"s": "q:dh_seonhwa", "t": "덩굴이 되어서도 물을 주셨던 거네요. 저 대신요."}, {"s": "q:dh_seonhwa", "t": "오늘은 잘 수 있겠어요. 내일은 담 너머로 물을 부어 볼게요."}]$q$::jsonb, $q${"xp": 82, "gil": 17, "items": {"calm_brew": 1, "herbal_extract": 1}}$q$::jsonb),
  ($q$sq_west_gate_1$q$, 1, $q$교대 없는 성벽$q$, $q$성문 노병 탁대근을 만난다$q$, $q${"at": ["west_gate"]}$q$::jsonb, $q$[{"s": "q:dh_daegeun", "t": "저기, 성루 위에 창 든 놈들 보이나? 내 전우들이야."}, {"s": "q:dh_daegeun", "t": "성이 버려진 날 교대 명령이 안 내려왔지. 그래서 아직도 서 있어."}, {"s": "q:dh_daegeun", "t": "녹슨 창이 되어서도 지나가는 사람을 찌르네. 그만 쉬게 해 주게."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_west_gate_1$q$, 2, $q$녹슨 창$q$, $q$녹슨 창귀 2마리와 성문 파수망령 2마리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_west_gate_2"], "n": 2}, {"t": "win", "m": ["m_west"], "n": 2}], "at": ["west_gate"]}$q$::jsonb, $q$[{"s": "q:dh_daegeun", "t": "고맙네. 하나씩 눕는 소리가 여기까지 들렸어."}, {"s": "q:dh_daegeun", "t": "그런데 대장이 남았네. 성루에 숨어 지나는 이를 노리는 놈. 그게 우리 대장이야."}, {"s": "q:dh_daegeun", "t": "대장이 교대를 외쳐야 다들 진짜로 쉴 수 있어."}]$q$::jsonb, $q${"xp": 82}$q$::jsonb),
  ($q$sq_west_gate_1$q$, 3, $q$교대 명령$q$, $q$성루 매복병을 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["west_gate"], "rank": "guardian", "n": 1}], "at": ["west_gate"]}$q$::jsonb, $q$[{"s": null, "t": "성루 매복병이 무너지기 직전, 쉰 목소리가 성벽을 울린다. 교대."}, {"s": "q:dh_daegeun", "t": "…들었나? 대장 목소리야. 삼십 년 만이야."}, {"s": "q:dh_daegeun", "t": "나도 이제 내려가도 되겠지. 다리가 많이 아팠거든."}]$q$::jsonb, $q${"xp": 82, "gil": 17, "items": {"clear_spirit_pill": 2}}$q$::jsonb),
  ($q$sq_west_gate_2$q$, 1, $q$마지막 창$q$, $q$성문 노병 탁대근의 부탁을 듣는다$q$, $q${"at": ["west_gate"]}$q$::jsonb, $q$[{"s": "q:dh_daegeun", "t": "전우들 창은 다 묻었네. 이건 내 창이야. 이것만은 못 묻겠더군."}, {"s": "q:dh_daegeun", "t": "날이 다 상했어. 성벽 돌틈에 쇠가 나니 좀 캐 주겠나?"}, {"s": "q:dh_daegeun", "t": "벼리는 건 젊은 손이 해야지. 내 손은 이제 떨려."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_west_gate_2$q$, 2, $q$돌틈의 쇠$q$, $q$서문 폐성벽에서 월철 광석과 생 월철을 캔다$q$, $q${"tasks": [{"t": "gather", "items": ["ore"], "r": ["west_gate"], "n": 2}, {"t": "gather", "items": ["raw_iron"], "r": ["west_gate"], "n": 2}], "at": ["west_gate"]}$q$::jsonb, $q$[{"s": "q:dh_daegeun", "t": "성벽 쇠는 피를 먹고 단단해졌다는 말이 있지. 헛소리야. 그냥 오래돼서 그래."}, {"s": "q:dh_daegeun", "t": "주괴로 녹이고, 수리 도구 하나 만들어 주게."}, {"s": null, "t": "노병이 쇳덩이를 손바닥에 올려 무게를 가늠한다. 손이 조금 떨린다."}]$q$::jsonb, $q${"xp": 82}$q$::jsonb),
  ($q$sq_west_gate_2$q$, 3, $q$다시 벼린 날$q$, $q$월철 주괴와 장비 수리 도구를 하나씩 만들어 넘긴다$q$, $q${"tasks": [{"t": "craft", "items": ["iron_ingot"], "n": 1}, {"t": "craft", "items": ["repair_kit"], "n": 1}], "at": ["west_gate"], "give": {"repair_kit": 1}}$q$::jsonb, $q$[{"s": null, "t": "노병이 수리 도구로 창날을 한참 손본다. 녹 아래에서 새 쇳빛이 드러난다."}, {"s": "q:dh_daegeun", "t": "됐네. 이걸 들고 성문 앞에 서 있겠네. 이번엔 교대가 올 때까지가 아니라."}, {"s": "q:dh_daegeun", "t": "자네 같은 젊은이가 지나갈 때 길을 비켜 주려고 말이야."}]$q$::jsonb, $q${"xp": 82, "gil": 17, "items": {"repair_kit": 1, "iron_ingot": 1}}$q$::jsonb),
  ($q$sq_ghost_bamboo_1$q$, 1, $q$숲의 노랫소리$q$, $q$나무꾼 하청운을 만난다$q$, $q${"at": ["ghost_bamboo"]}$q$::jsonb, $q$[{"s": "q:dh_cheongun", "t": "밤이면 대숲 안쪽에서 노래가 들려요. 누이 목소리예요."}, {"s": "q:dh_cheongun", "t": "작년에 대나무 순 따러 갔다가 안 돌아왔어요. 노래를 따라가면 만날 것 같은데…"}, {"s": "q:dh_cheongun", "t": "따라간 사람들이 다 독에 물려 돌아왔어요. 저도 무서워요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_ghost_bamboo_1$q$, 2, $q$노래를 따라$q$, $q$귀죽림을 2번 탐색하고 대나무 원숭이 3마리를 쫓는다$q$, $q${"tasks": [{"t": "search", "r": ["ghost_bamboo"], "n": 2}, {"t": "win", "m": ["g_ghost_bamboo"], "n": 3}], "at": ["ghost_bamboo"]}$q$::jsonb, $q$[{"s": null, "t": "원숭이들이 흩어진 자리에 짚신 한 짝이 놓여 있다. 작은 발 크기다."}, {"s": "q:dh_cheongun", "t": "누이 신이에요. 제가 엮어 준 거예요."}, {"s": "me", "t": "노래는 저 안쪽, 뱀 비늘 자국이 이어진 쪽에서 납니다."}]$q$::jsonb, $q${"xp": 118}$q$::jsonb),
  ($q$sq_ghost_bamboo_1$q$, 3, $q$노래의 주인$q$, $q$대숲 독사녀를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["ghost_bamboo"], "rank": "guardian", "n": 1}], "at": ["ghost_bamboo"]}$q$::jsonb, $q$[{"s": null, "t": "독사녀가 쓰러지자 노래가 뚝 끊긴다. 그 목에는 누이의 목소리가 아니라 누이가 부르던 노래만 걸려 있었다."}, {"s": "q:dh_cheongun", "t": "누이 목소리를 흉내 냈던 거군요. 사람을 부르려고."}, {"s": "q:dh_cheongun", "t": "그래도… 그 노래가 남아 있었다는 건, 누이가 마지막까지 불렀다는 거겠죠."}, {"s": "q:dh_cheongun", "t": "이제 제가 부를게요. 숲에서 길 잃은 사람이 듣고 나오게요."}]$q$::jsonb, $q${"xp": 118, "gil": 21, "items": {"clear_spirit_pill": 2, "venom_gland": 1}}$q$::jsonb),
  ($q$sq_ghost_bamboo_2$q$, 1, $q$물린 자리$q$, $q$떠돌이 약사 육윤팔을 만난다$q$, $q${"at": ["ghost_bamboo"]}$q$::jsonb, $q$[{"s": "q:dh_yunpal", "t": "허, 또 물린 놈이 왔나 했네. 멀쩡하구먼."}, {"s": "q:dh_yunpal", "t": "대숲 독은 독으로 다스리는 법이지. 독낭 하나에 약제 바탕, 영맥 수피면 된다네."}, {"s": "q:dh_yunpal", "t": "숲 안쪽에서 구해 오게. 나는 물린 놈들 지키느라 못 가."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_ghost_bamboo_2$q$, 2, $q$독과 약$q$, $q$귀죽림에서 독낭·약제 바탕·영맥 수피를 모은다$q$, $q${"tasks": [{"t": "gather", "items": ["venom_gland"], "r": ["ghost_bamboo"], "n": 2}, {"t": "gather", "items": ["medicine_base"], "r": ["ghost_bamboo"], "n": 2}, {"t": "gather", "items": ["spirit_bark"], "r": ["ghost_bamboo"], "n": 2}], "at": ["ghost_bamboo"], "give": {"venom_gland": 2, "medicine_base": 2, "spirit_bark": 2}}$q$::jsonb, $q$[{"s": "q:dh_yunpal", "t": "옳거니. 독낭은 터뜨리지 않고 잘 땄구먼."}, {"s": "q:dh_yunpal", "t": "이제 청령단 두어 알만 지어 주게. 독을 빼고 나면 기운이 빠지거든."}, {"s": null, "t": "약사가 독낭을 갈아 약제 바탕에 섞는다. 쓴 냄새가 대숲에 번진다."}]$q$::jsonb, $q${"xp": 118}$q$::jsonb),
  ($q$sq_ghost_bamboo_2$q$, 3, $q$기운 돋우기$q$, $q$청령단을 2번 만들어 육윤팔에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["clear_spirit_pill"], "n": 2}], "at": ["ghost_bamboo"], "give": {"clear_spirit_pill": 2}}$q$::jsonb, $q$[{"s": null, "t": "누워 있던 나무꾼들이 하나둘 몸을 일으킨다."}, {"s": "q:dh_yunpal", "t": "봤나? 내 처방이 틀린 적이 없다니까."}, {"s": "q:dh_yunpal", "t": "…사실 한 번 틀렸지. 그때 못 살린 놈이 내 동생이었어. 그래서 숲을 못 떠나."}, {"s": "q:dh_yunpal", "t": "자네 덕에 오늘은 하나도 안 잃었네. 고맙네."}]$q$::jsonb, $q${"xp": 118, "gil": 21, "items": {"clear_spirit_pill": 1, "medicine_base": 2}}$q$::jsonb),
  ($q$sq_sunken_district_1$q$, 1, $q$잠긴 관아$q$, $q$옛 관아 아전 홍월순을 만난다$q$, $q${"at": ["sunken_district"]}$q$::jsonb, $q$[{"s": "q:dh_wolsun", "t": "젖은 장부를 쫓는 분이죠? 이 동네 관아에도 장부함이 하나 있어요."}, {"s": "q:dh_wolsun", "t": "물이 들어오던 날, 누가 그 함에 무언가를 넣고 갔어요. 붉은 달이 그려진 끈으로 묶었죠."}, {"s": "q:dh_wolsun", "t": "그런데 침수 장군이 함을 끌어안고 놓지를 않아요. 관아를 지키다 죽은 분이라서요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_sunken_district_1$q$, 2, $q$물 먹은 길$q$, $q$구시가지에서 이끼 쥐떼 2마리와 물 먹은 상여귀 2마리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_sunken_district_1"], "n": 2}, {"t": "win", "m": ["x_sunken_district_2"], "n": 2}], "at": ["sunken_district"]}$q$::jsonb, $q$[{"s": null, "t": "물 위로 상여 하나가 떠내려간다. 그 뒤로 관아 지붕 끝이 보인다."}, {"s": "q:dh_wolsun", "t": "저기예요. 장군님은 함을 열려는 사람만 공격해요."}, {"s": "q:dh_wolsun", "t": "살아 계실 때도 그러셨어요. 장부는 목숨보다 무겁다고요."}]$q$::jsonb, $q${"xp": 160}$q$::jsonb),
  ($q$sq_sunken_district_1$q$, 3, $q$장군의 품$q$, $q$침수 장군 2마리를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_08"], "n": 2}], "at": ["sunken_district"]}$q$::jsonb, $q$[{"s": null, "t": "장군의 팔이 풀리고 장부함이 열린다. 안에는 장부 대신 빈 표지와 붉은 끈만 남아 있다."}, {"s": "q:dh_wolsun", "t": "속은 벌써 누가 가져갔네요. 장군님은 빈 함을 지키셨던 거예요."}, {"s": "q:dh_wolsun", "t": "끈에 붙은 소금 결정 보이세요? 바다 쪽 사람이에요. 염등촌 소금이에요."}, {"s": "q:dh_wolsun", "t": "장군님께 이제 됐다고 말씀드려야겠어요. 지킬 것이 없다고요."}]$q$::jsonb, $q${"xp": 160, "gil": 25, "items": {"clear_spirit_pill": 2, "spirit_dust": 2}}$q$::jsonb),
  ($q$sq_sunken_district_2$q$, 1, $q$깜깜한 물길$q$, $q$물길잡이 개똥이를 만난다$q$, $q${"at": ["sunken_district"]}$q$::jsonb, $q$[{"s": "q:dh_gaetong", "t": "형, 아니 누나? 아무튼 조사원님! 밤에 여기 오면 큰일 나요."}, {"s": "q:dh_gaetong", "t": "물 밑에 사람들이 길을 잃고 돌아다녀요. 불이 없어서 집을 못 찾는 거래요."}, {"s": "q:dh_gaetong", "t": "어유 등잔이면 물 밑까지 비춘대요. 기름은 물고기에서 나와요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_sunken_district_2$q$, 2, $q$기름 낼 고기$q$, $q$침수된 구시가지에서 물고기를 3번 낚는다$q$, $q${"tasks": [{"t": "fish", "r": ["sunken_district"], "n": 3}], "at": ["sunken_district"]}$q$::jsonb, $q$[{"s": "q:dh_gaetong", "t": "와, 많이 잡았다! 이거 다 기름 짜면 되겠다."}, {"s": "q:dh_gaetong", "t": "등잔 만드는 건 제가 못 해요. 조사원님이 해 주세요."}, {"s": null, "t": "소년이 대야 가장자리를 두드리며 물 밑을 내려다본다. 대답처럼 거품 몇 개가 올라온다."}]$q$::jsonb, $q${"xp": 160}$q$::jsonb),
  ($q$sq_sunken_district_2$q$, 3, $q$물 위의 등잔$q$, $q$어유 등잔을 1번 만들어 개똥이에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["fish_oil_lamp"], "n": 1}], "at": ["sunken_district"], "give": {"fish_oil_lamp": 1}}$q$::jsonb, $q$[{"s": null, "t": "개똥이가 대야 위에 등잔을 올려 물에 띄운다. 불빛이 물 밑 골목을 따라 길게 번진다."}, {"s": null, "t": "물 밑에서 희미한 그림자들이 불빛을 따라 하나둘 제 집 문 쪽으로 걸어간다."}, {"s": "q:dh_gaetong", "t": "봐요, 우리 할매도 저기 있어요. 할매가 집 찾았어요."}, {"s": "q:dh_gaetong", "t": "매일 밤 띄울게요. 다 찾을 때까지요."}]$q$::jsonb, $q${"xp": 160, "gil": 25, "items": {"lantern_oil": 1, "grilled_fish": 1}}$q$::jsonb),
  ($q$sq_river_ferry_1$q$, 1, $q$식은 솥$q$, $q$구름나루 주막의 주모와 이야기하기$q$, $q${"at": ["river_ferry"]}$q$::jsonb, $q$[{"s": null, "t": "주막 부뚜막의 솥이 차갑다. 장사하는 집에서 보기 드문 일이다."}, {"s": "q:sn_dalrae", "t": "어서 오시오. 앉기는 하시되 먹을 건 없소. 은어 철인데 고기가 한 마리도 안 올라와요."}, {"s": "q:sn_dalrae", "t": "사공들은 밤마다 강에서 노래가 들린다며 그물을 안 던지고요. 겁쟁이들 같으니."}, {"s": "me", "t": "노래라면 어떤 노래입니까."}, {"s": "q:sn_dalrae", "t": "나야 모르지요. 손님이 직접 낚싯대 한번 담가 보시겠소? 고기가 올라오면 노래 탓은 아니란 뜻이니."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_river_ferry_1$q$, 2, $q$강물 속 노래$q$, $q$구름나루에서 물고기 네 마리 낚기$q$, $q${"tasks": [{"t": "fish", "r": ["river_ferry"], "n": 4}], "at": ["river_ferry"]}$q$::jsonb, $q$[{"s": null, "t": "찌가 가라앉을 때마다 물 밑에서 낮은 흥얼거림이 끊겼다 이어진다."}, {"s": "river_alliance:nodeul", "t": "허, 고기가 올라오는 걸 보니 노래가 잠깐 쉬는 모양이로군."}, {"s": "river_alliance:nodeul", "t": "저건 물에 빠진 사공들 노래요. 고기를 몰아내려는 게 아니라 제 몫을 기다리는 거지."}, {"s": "q:sn_dalrae", "t": "영감님, 또 그 소리. 손님, 그 고기 이리 주시오. 구워서 상을 차릴 테니 손 좀 보태고."}]$q$::jsonb, $q${"xp": 82, "items": {"spirit_tea": 1}}$q$::jsonb),
  ($q$sq_river_ferry_1$q$, 3, $q$강에 띄우는 상$q$, $q$생선구이 두 접시를 구워 주모에게 건네기$q$, $q${"tasks": [{"t": "craft", "items": ["grilled_fish"], "n": 2}], "at": ["river_ferry"], "give": {"grilled_fish": 2}}$q$::jsonb, $q$[{"s": null, "t": "주모는 한 접시를 손님상에 놓고, 다른 한 접시는 나무 쟁반에 받쳐 물가로 들고 간다."}, {"s": "q:sn_dalrae", "t": "우리 집 양반 몫이오. 삼 년 전 저 물에 노를 놓쳤지."}, {"s": "q:sn_dalrae", "t": "고기가 안 잡히니 이 상도 못 띄웠소. 노래가 그 사람 재촉이었나 보오."}, {"s": null, "t": "쟁반이 물살을 타고 멀어지자, 강 위의 흥얼거림이 한 소절 길게 이어지다 그친다."}, {"s": "q:sn_dalrae", "t": "자, 식기 전에 드시오. 오늘은 내가 내는 거요."}]$q$::jsonb, $q${"xp": 82, "gil": 17, "items": {"travel_ration": 2}}$q$::jsonb),
  ($q$sq_river_ferry_2$q$, 1, $q$비어 있는 날짜$q$, $q$구름나루에서 장부 행수 매향 만나기$q$, $q${"at": ["river_ferry"]}$q$::jsonb, $q$[{"s": "river_alliance:maehyang", "t": "그 젖은 장부를 쫓은 조사원이시지요. 연맹 장부에도 이상한 곳이 있습니다."}, {"s": "river_alliance:maehyang", "t": "장부가 물길을 탄 바로 그 밤, 구름나루 출항 기록 한 줄이 칼로 긁혀 있어요."}, {"s": "river_alliance:maehyang", "t": "연맹 배였다면 연맹의 수치입니다. 아니라면 누군가 우리 이름을 빌린 거고요."}, {"s": "river_alliance:maehyang", "t": "그 배가 들렀을 곳은 구룡 폐수로뿐입니다. 거기서 흔적을 찾아 주세요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_river_ferry_2$q$, 2, $q$폐수로의 뱃자국$q$, $q$구룡 폐수로에 가서 세 번 탐색하기$q$, $q${"tasks": [{"t": "travel", "r": ["old_canal"], "n": 1}, {"t": "search", "r": ["old_canal"], "n": 3}], "at": ["old_canal"]}$q$::jsonb, $q$[{"s": null, "t": "수문 아래 진흙에 부러진 노 하나가 박혀 있다."}, {"s": null, "t": "노 손잡이에 수향연맹의 물결 표식, 그 아래 「방울호」라는 배 이름이 새겨져 있다."}, {"s": "me", "t": "연맹 배가 맞군. 사공은 어디로 갔을까."}, {"s": null, "t": "대답처럼, 탁한 물 위로 노 젓는 그림자가 미끄러져 지나간다."}]$q$::jsonb, $q${"xp": 160}$q$::jsonb),
  ($q$sq_river_ferry_2$q$, 3, $q$그림자 뱃사공의 운임표$q$, $q$그림자 뱃사공을 쓰러뜨리고 단서 하나 찾기$q$, $q${"tasks": [{"t": "win", "m": ["x_old_canal_2"], "n": 2}, {"t": "clue", "n": 1}], "at": ["river_ferry"]}$q$::jsonb, $q$[{"s": null, "t": "그림자 뱃사공의 품에서 젖은 운임표가 나왔다. 붉은 달 도장 옆에 연맹 인장이 나란히 찍혀 있다."}, {"s": "river_alliance:maehyang", "t": "이 인장은 진짜입니다. 연맹 안에서 누군가 값을 받고 배를 내줬어요."}, {"s": "river_alliance:jin", "t": "그 값, 얼마였는지 알아낼 수 있겠소, 매향?"}, {"s": "river_alliance:maehyang", "t": "운임표에 적힌 대로라면 쌀 닷 섬. 사람 하나 목숨값으로는 헐하지요."}, {"s": "river_alliance:jin", "t": "방울호 사공 집에 내가 쌀 열 섬을 보내겠소. 팔아먹은 놈은 내가 찾고."}]$q$::jsonb, $q${"xp": 160, "gil": 25, "items": {"clear_spirit_pill": 2}}$q$::jsonb),
  ($q$sq_salt_village_1$q$, 1, $q$하얀 혼례복$q$, $q$염등촌에서 염전 일꾼 옥분의 이야기 듣기$q$, $q${"at": ["salt_village"]}$q$::jsonb, $q$[{"s": "q:sn_okbun", "t": "보름마다 하얀 혼례복 입은 각시가 염전에 서요. 그날 밤엔 꼭 사내 하나가 없어지고요."}, {"s": "q:sn_okbun", "t": "다들 제 언니라고 해요. 시집가던 날 배가 뒤집혀 바다에 빠진 언니요."}, {"s": "me", "t": "언니라고 생각합니까."}, {"s": "q:sn_okbun", "t": "모르겠어요. 그래서 부탁드려요. 쓰러뜨려 주세요. 그리고 언니인지 알려 주세요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_salt_village_1$q$, 2, $q$은가락지$q$, $q$소금각시와 염전 갈매기 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["m_salt"], "n": 1}, {"t": "win", "m": ["x_salt_village_1"], "n": 2}], "at": ["salt_village"]}$q$::jsonb, $q$[{"s": null, "t": "소금각시가 무너진 자리에 소금 더미와 은가락지 하나가 남았다."}, {"s": "q:sn_okbun", "t": "이건 제 가락지예요. 혼례 날 제가 끼었어야 할."}, {"s": "q:sn_okbun", "t": "사실 그 혼처는 제 자리였어요. 제가 무섭다고 울어서 언니가 대신 갔어요."}, {"s": "q:sn_okbun", "t": "그런데 이상해요. 언니라면 이렇게 쉽게 쓰러질 리 없는데. 각시를 염전 끝으로 끌고 가는 그림자를 봤어요."}]$q$::jsonb, $q${"xp": 160}$q$::jsonb),
  ($q$sq_salt_village_1$q$, 3, $q$염전 끝의 매복$q$, $q$염전 매복귀 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["regional_salt_village_guardian"], "n": 1}], "at": ["salt_village"]}$q$::jsonb, $q$[{"s": null, "t": "염전 매복귀의 등에서 끊어진 붉은 혼례 끈이 풀려 나온다. 각시를 묶어 미끼로 쓰고 있었던 것이다."}, {"s": null, "t": "그것이 쓰러지자 바다 바람이 잦아들고, 염전 위에 하얀 소금꽃이 한꺼번에 핀다."}, {"s": "q:sn_okbun", "t": "언니는 사내를 끌고 간 적이 없었네요. 붙잡혀 있었던 거지."}, {"s": "q:sn_okbun", "t": "가락지는 언니한테 돌려줄게요. 이제야 제대로 시집보내는 거예요."}, {"s": null, "t": "옥분은 가락지를 소금 더미 깊이 묻고 오래 그 앞에 앉아 있었다."}]$q$::jsonb, $q${"xp": 160, "gil": 25, "items": {"ward_talisman": 1}}$q$::jsonb),
  ($q$sq_salt_village_2$q$, 1, $q$터진 손바닥$q$, $q$염등촌 약방 영감 만석 만나기$q$, $q${"at": ["salt_village"]}$q$::jsonb, $q$[{"s": "q:sn_manseok", "t": "염전 일꾼들 손을 보셨소? 소금이 살을 파먹어 피가 마를 날이 없지."}, {"s": "q:sn_manseok", "t": "청정수로 씻어 내면 나을 텐데 약초액이 바닥났소. 늙은 다리로는 갯가를 못 다니고."}, {"s": "q:sn_manseok", "t": "염등촌 갯풀에서 짜낸 약초액이면 되오. 좀 모아다 주시겠소?"}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_salt_village_2$q$, 2, $q$소금 낀 약초액$q$, $q$염등촌에서 농축 약초액 세 번 채집하기$q$, $q${"tasks": [{"t": "gather", "items": ["herbal_extract"], "r": ["salt_village"], "n": 3}], "at": ["salt_village"]}$q$::jsonb, $q$[{"s": "q:sn_manseok", "t": "어디 보세. 음, 바다 약초라 소금결이 섞였군. 이대로 바르면 더 쓰라리오."}, {"s": "q:sn_manseok", "t": "한 번 걸러 달여야 하오. 청정수 달이는 법은 아시겠지?"}, {"s": "me", "t": "해 보겠습니다."}, {"s": "q:sn_manseok", "t": "솥은 내 것을 쓰시오. 약은 손 탄 만큼 맑아지는 법이오."}]$q$::jsonb, $q${"xp": 206}$q$::jsonb),
  ($q$sq_salt_village_2$q$, 3, $q$맑은 물 두 병$q$, $q$청정수 두 병을 만들어 만석에게 건네기$q$, $q${"tasks": [{"t": "craft", "items": ["purify_water"], "n": 2}], "at": ["salt_village"], "give": {"purify_water": 2}}$q$::jsonb, $q$[{"s": null, "t": "청정수 병을 건네받는 영감의 손이 소매 밖으로 드러났다. 일꾼들보다 더 깊게 갈라져 있다."}, {"s": "me", "t": "영감님 손이 가장 상하셨군요."}, {"s": "q:sn_manseok", "t": "약방 주인이 제 손부터 씻으면 일꾼들이 약을 믿겠소?"}, {"s": "q:sn_manseok", "t": "남는 게 있으면 그때 쓰겠소. 이번엔 남을 것 같구려. 고맙소."}]$q$::jsonb, $q${"xp": 206, "gil": 29, "items": {"spirit_tea": 2}}$q$::jsonb),
  ($q$sq_lotus_marsh_1$q$, 1, $q$늪가의 빈 바구니$q$, $q$천엽 연화늪에서 연수 만나기$q$, $q${"at": ["lotus_marsh"]}$q$::jsonb, $q$[{"s": "q:sn_yeonsu", "t": "아버지가 늪 독에 쏘여 누우셨어요. 열이 사흘째 안 내려요."}, {"s": "q:sn_yeonsu", "t": "월광 이끼랑 야령초를 달이면 된다는데, 이끼는 밤에만 빛나서 밤 늪에 들어가야 해요."}, {"s": "q:sn_yeonsu", "t": "저 혼자는 무서워서요. 조사원님이 좀 도와주시면 안 될까요?"}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_lotus_marsh_1$q$, 2, $q$빛나는 이끼$q$, $q$천엽 연화늪에서 월광 이끼 세 번 채집하기$q$, $q${"tasks": [{"t": "gather", "items": ["moon_moss"], "r": ["lotus_marsh"], "n": 3}], "at": ["lotus_marsh"]}$q$::jsonb, $q$[{"s": null, "t": "이끼를 걷어 낸 바위 아래, 연근이 반쯤 갉아 먹힌 채 떠올라 있다."}, {"s": null, "t": "이빨 자국이 사람 것보다 크고 고르지 않다."}, {"s": "q:sn_yeonsu", "t": "연근식귀예요. 요즘 연밭이 왜 이렇게 시드나 했더니."}, {"s": "q:sn_yeonsu", "t": "우선 약부터요. 야령초만 더 있으면 돼요."}]$q$::jsonb, $q${"xp": 258}$q$::jsonb),
  ($q$sq_lotus_marsh_1$q$, 3, $q$달인 약 한 사발$q$, $q$야령초를 더 캐고 이끼와 함께 연수에게 건네기$q$, $q${"tasks": [{"t": "gather", "items": ["herb"], "r": ["lotus_marsh"], "n": 3}], "at": ["lotus_marsh"], "give": {"moon_moss": 2, "herb": 2}}$q$::jsonb, $q$[{"s": null, "t": "연수가 약을 달여 아버지 머리맡에 둔다. 새벽녘 열이 내린다."}, {"s": "q:sn_yeonsu", "t": "고맙습니다. 아버지가 눈을 뜨자마자 연밭부터 물으셨어요."}, {"s": "q:sn_yeonsu", "t": "그런데 이상해요. 연근식귀 얘기를 하니까 아무 말씀도 안 하시고 돌아누우셨어요."}]$q$::jsonb, $q${"xp": 258, "gil": 33, "items": {"herbal_extract": 1}}$q$::jsonb),
  ($q$sq_lotus_marsh_2$q$, 1, $q$시든 연잎$q$, $q$천엽 연화늪에서 봉구의 부탁 듣기$q$, $q${"at": ["lotus_marsh"]}$q$::jsonb, $q$[{"s": "q:sn_bonggu", "t": "딸아이를 살려 준 분이구려. 염치없지만 하나만 더 부탁하겠소."}, {"s": "q:sn_bonggu", "t": "연근식귀를 없애 주시오. 저것들이 연밭을 다 갉으면 올겨울은 굶소."}, {"s": "q:sn_bonggu", "t": "다만 늪 한가운데 독두꺼비 쪽으론 가지 마시오. 그건 건드릴 게 아니오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_lotus_marsh_2$q$, 2, $q$뱃속의 부적$q$, $q$연근식귀 두 마리 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["m_17"], "n": 2}], "at": ["lotus_marsh"]}$q$::jsonb, $q$[{"s": null, "t": "쓰러진 연근식귀의 뱃속에서 젖은 부적 뭉치가 쏟아진다. 해마다 같은 글씨다."}, {"s": null, "t": "「올해도 흉년을 거두어 주소서. 연밭지기 봉구.」"}, {"s": "q:sn_yeonsu", "t": "아버지 글씨예요. 아버지가 늪에 이런 걸 던지셨어요?"}, {"s": "me", "t": "부적을 받아먹던 것이 따로 있을 겁니다. 늪 한가운데로 가 보지요."}]$q$::jsonb, $q${"xp": 314}$q$::jsonb),
  ($q$sq_lotus_marsh_2$q$, 3, $q$늪 한가운데의 제사$q$, $q$연못 독두꺼비 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["regional_lotus_marsh_guardian"], "n": 1}], "at": ["lotus_marsh"]}$q$::jsonb, $q$[{"s": null, "t": "독두꺼비가 가라앉자 늪 밑바닥에서 삼십 년 치 부적이 떠오른다. 연근식귀들은 그 찌꺼기를 먹고 자란 것이다."}, {"s": "q:sn_bonggu", "t": "흉년 한 번 없이 삼십 년이었소. 대신 늪은 해마다 독해졌지. 딸아이가 쏘인 것도 내 탓이오."}, {"s": "q:sn_yeonsu", "t": "이제 그만 던지세요, 아버지. 흉년이 오면 같이 굶으면 돼요."}, {"s": "q:sn_yeonsu", "t": "올해 연밥은 제가 따겠습니다. 제 손으로요."}]$q$::jsonb, $q${"xp": 314, "gil": 37, "items": {"venom_gland": 1, "spirit_qi_pill": 1}}$q$::jsonb),
  ($q$sq_mirror_pavilion_1$q$, 1, $q$얼굴 없는 초상$q$, $q$수경루에서 화공 은결 만나기$q$, $q${"at": ["mirror_pavilion"]}$q$::jsonb, $q$[{"s": null, "t": "누각 난간에 걸린 초상화. 춤추는 무희의 옷자락은 살아 있는데 얼굴 자리가 비어 있다."}, {"s": "q:sn_eungyeol", "t": "이 누각에서 춤추던 무희요. 얼굴이 도무지 떠오르지 않소."}, {"s": "q:sn_eungyeol", "t": "호수 물거울에는 비친다더이다. 깨진 거울 조각에 그 빛을 담아 오면 보고 그릴 수 있을 텐데."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_mirror_pavilion_1$q$, 2, $q$조각마다 다른 얼굴$q$, $q$수경루에서 거울 조각 세 번 채집하기$q$, $q${"tasks": [{"t": "gather", "items": ["mirror_shard"], "r": ["mirror_pavilion"], "n": 3}], "at": ["mirror_pavilion"]}$q$::jsonb, $q$[{"s": null, "t": "조각을 들어 올릴 때마다 다른 얼굴이 스친다. 웃는 얼굴, 우는 얼굴, 돌아선 뒷모습."}, {"s": "q:sn_eungyeol", "t": "흩어져 있군. 맞추려면 요기가 더 있어야겠소. 물거울 요정들이 그걸 쥐고 놓질 않지."}, {"s": "me", "t": "요정들을 물리치고 결정을 모아 오겠습니다."}]$q$::jsonb, $q${"xp": 374}$q$::jsonb),
  ($q$sq_mirror_pavilion_1$q$, 3, $q$맞춰진 얼굴$q$, $q$물거울 요정을 물리치고 요기 결정을 모아 조각 건네기$q$, $q${"tasks": [{"t": "win", "m": ["g_mirror_pavilion"], "n": 2}, {"t": "gather", "items": ["spirit_dust"], "r": ["mirror_pavilion"], "n": 2}], "at": ["mirror_pavilion"], "give": {"mirror_shard": 3}}$q$::jsonb, $q$[{"s": null, "t": "요기로 이어 붙인 거울 속에서 무희가 고개를 든다. 그 눈이 화공을 정확히 바라본다."}, {"s": "q:sn_eungyeol", "t": "아, 이 얼굴이었지. 내가 젊어서 그리지 못한 얼굴."}, {"s": "q:sn_eungyeol", "t": "그때 나는 그 사람 앞에서 붓을 들 용기가 없었소. 그래서 평생 옷자락만 그렸지."}, {"s": null, "t": "화공의 붓이 빈 얼굴 자리를 천천히 채운다. 거울 속 무희가 웃는다."}]$q$::jsonb, $q${"xp": 374, "gil": 41, "items": {"spirit_dust": 2}}$q$::jsonb),
  ($q$sq_mirror_pavilion_2$q$, 1, $q$밤의 발소리$q$, $q$수경루에서 은결의 걱정 듣기$q$, $q${"at": ["mirror_pavilion"]}$q$::jsonb, $q$[{"s": "q:sn_eungyeol", "t": "초상을 다 그린 뒤로 밤마다 그림 속에서 발소리가 나오."}, {"s": "q:sn_eungyeol", "t": "춤을 추는 게 아니오. 누가 쫓아오는 것처럼 뛰는 소리요."}, {"s": "q:sn_eungyeol", "t": "정화 부적을 붙이면 잠잠해지려나. 내 손으로는 접을 수가 없소."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_mirror_pavilion_2$q$, 2, $q$접은 부적$q$, $q$정화 부적 세 장 만들기$q$, $q${"tasks": [{"t": "craft", "items": ["ward_talisman"], "n": 3}], "at": ["mirror_pavilion"]}$q$::jsonb, $q$[{"s": null, "t": "부적을 그림에 대려는 순간, 화폭 안의 무희가 손을 내밀어 막는다."}, {"s": null, "t": "그 뒤로 거울 속 누각 깊은 곳에서 화려한 옷의 그림자가 걸어 나온다."}, {"s": "q:sn_eungyeol", "t": "무희장이로군. 저 아이를 거울에 가둔 것이 저것이었어."}, {"s": "me", "t": "부적은 무희가 아니라 저것에게 써야겠습니다."}]$q$::jsonb, $q${"xp": 440}$q$::jsonb),
  ($q$sq_mirror_pavilion_2$q$, 3, $q$빈 화폭$q$, $q$거울 속 무희장을 쓰러뜨리고 부적을 은결에게 건네기$q$, $q${"tasks": [{"t": "win", "m": ["regional_mirror_pavilion_guardian"], "n": 1}], "at": ["mirror_pavilion"], "give": {"ward_talisman": 2}}$q$::jsonb, $q$[{"s": null, "t": "무희장이 깨지자 그림 속 무희가 한 바퀴 돌아 화폭 밖으로 사라진다."}, {"s": null, "t": "남은 것은 물결만 그려진 빈 화폭이다."}, {"s": "q:sn_eungyeol", "t": "얼굴을 겨우 그렸더니 이제 사람이 없구려."}, {"s": "q:sn_eungyeol", "t": "그래도 좋소. 갇힌 얼굴보다 떠난 빈자리가 낫지."}, {"s": "q:sn_eungyeol", "t": "부적 두 장은 이 화폭에 붙여 두겠소. 다시는 아무것도 들어오지 못하게."}]$q$::jsonb, $q${"xp": 440, "gil": 45, "items": {"fine_paper": 2}}$q$::jsonb),
  ($q$sq_sunken_palace_1$q$, 1, $q$떠오르지 않은 방울$q$, $q$용잠 수궁 물가에서 청파 만나기$q$, $q${"at": ["sunken_palace"]}$q$::jsonb, $q$[{"s": "river_alliance:nodeul", "t": "이 친구 동생이 수궁 문 안으로 들어갔소. 열흘째 숨 방울이 안 올라오오."}, {"s": "q:sn_cheongpa", "t": "흑파는 저보다 숨이 짧습니다. 살아 있을 리 없다는 거 압니다."}, {"s": "q:sn_cheongpa", "t": "그래도 시신이라도. 시녀귀들이 문 앞을 막고 있어 저 혼자는 못 들어갑니다."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_sunken_palace_1$q$, 2, $q$시녀귀의 잠수 방울$q$, $q$용궁 시녀귀 두 마리 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["x_sunken_palace_2"], "n": 2}], "at": ["sunken_palace"]}$q$::jsonb, $q$[{"s": null, "t": "시녀귀의 머리 장식 사이에 연맹 잠수꾼의 놋쇠 방울이 꿰여 있다."}, {"s": "q:sn_cheongpa", "t": "흑파 것입니다. 제가 묶어 준 매듭 그대로예요."}, {"s": "q:sn_cheongpa", "t": "더 안쪽으로 끌려갔습니다. 수위가 지키는 문 너머로."}]$q$::jsonb, $q${"xp": 750}$q$::jsonb),
  ($q$sq_sunken_palace_1$q$, 3, $q$투구 안의 이름$q$, $q$용잠 수위 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["m_19"], "n": 1}], "at": ["sunken_palace"]}$q$::jsonb, $q$[{"s": null, "t": "용잠 수위의 투구가 굴러떨어진다. 안쪽에 손톱으로 긁은 글씨, 「흑파」."}, {"s": "river_alliance:nodeul", "t": "수궁은 들어온 사람을 문지기로 바꾼다더니. 옛말이 틀린 적이 없구먼."}, {"s": null, "t": "흩어지는 물살 속에서 한순간, 낯익은 얼굴이 떠오른다."}, {"s": "q:sn_cheongpa", "t": "흑파야."}, {"s": null, "t": "「형, 교대할 사람 데려오지 마.」 그 말만 남기고 물이 다시 검어진다."}, {"s": "q:sn_cheongpa", "t": "다시는 이 문 앞에 연맹 잠수꾼을 보내지 않겠습니다. 그게 동생 부탁이니."}]$q$::jsonb, $q${"xp": 750, "gil": 61, "items": {"rejuv_pill": 1, "drowned_scale": 3}}$q$::jsonb),
  ($q$sq_sunken_palace_2$q$, 1, $q$도방의 주문$q$, $q$구름나루에서 도방 진소랑 만나기$q$, $q${"at": ["river_ferry"]}$q$::jsonb, $q$[{"s": "river_alliance:jin", "t": "물 밑의 노래가 문을 연다는 얘기, 조사원께서 직접 들으셨다지요."}, {"s": "river_alliance:jin", "t": "수궁 등롱어는 그 노래를 들으면 몸에서 빛을 낸다오. 그 기름으로 등을 켜면 노랫말이 보인다는 소문이 있소."}, {"s": "river_alliance:jin", "t": "값은 넉넉히 치르리다. 깎지 않겠소. 이번만은."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_sunken_palace_2$q$, 2, $q$물 밑 한 소절$q$, $q$용잠 수궁에서 물고기 네 마리 낚기$q$, $q${"tasks": [{"t": "fish", "r": ["sunken_palace"], "n": 4}], "at": ["sunken_palace"]}$q$::jsonb, $q$[{"s": null, "t": "고기가 물 위로 끌려 올라올 때마다 깊은 데서 노래 한 소절이 따라 올라온다."}, {"s": null, "t": "가사는 알아듣기 어렵다. 다만 사람 이름을 부르는 듯한 가락이다."}, {"s": "me", "t": "이 노래가 등대에서 왔다면, 여기까지 닿아 있었군."}]$q$::jsonb, $q${"xp": 934}$q$::jsonb),
  ($q$sq_sunken_palace_2$q$, 3, $q$등잔 아래 받아 적은 이름$q$, $q$등롱 어유 두 병을 만들어 진소랑에게 건네기$q$, $q${"tasks": [{"t": "craft", "items": ["lantern_oil"], "n": 2}], "at": ["river_ferry"], "give": {"lantern_oil": 2}}$q$::jsonb, $q$[{"s": null, "t": "진소랑이 어유를 등잔에 붓고 불을 붙인다. 불빛이 흔들리며 벽에 희미한 글자들이 맺힌다."}, {"s": "river_alliance:maehyang", "t": "이름들입니다. 하나, 둘. 지워진 사람들이에요."}, {"s": null, "t": "진소랑이 한 이름에서 손가락을 멈춘다. 웃음기가 사라진 얼굴이다."}, {"s": "river_alliance:jin", "t": "우리 어머니 이름이오. 내가 어릴 때 뱃길에서 사라졌지. 다들 처음부터 없던 사람처럼 굴었소."}, {"s": "river_alliance:jin", "t": "이제 장부에 다시 적을 수 있겠구려. 값은 약속대로, 아니 그보다 더 치르겠소."}]$q$::jsonb, $q${"xp": 934, "gil": 69, "items": {"moonlight_essence": 1, "spirit_glass": 2}}$q$::jsonb),
  ($q$sq_ember_village_1$q$, 1, $q$모자란 손$q$, $q$잔불촌에서 정찰대장 갈매 만나기$q$, $q${"at": ["ember_village"]}$q$::jsonb, $q$[{"s": "southern_remnant:galmae", "t": "내일 새벽 해안 정찰이오. 건량이 바닥났는데 어멈 혼자 다 못 짓소."}, {"s": "q:sn_bokrye", "t": "손은 모자라고 땔감은 더 모자라요. 나무부터 좀 해다 주시구려."}, {"s": "q:sn_bokrye", "t": "잔불촌 아궁이엔 아무 불이나 들이지 않아요. 땔감은 손님이 해 와도 불은 내 불이오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_ember_village_1$q$, 2, $q$땔감 한 짐$q$, $q$부적목 세 번 채집해 잔불촌으로 돌아오기$q$, $q${"tasks": [{"t": "gather", "items": ["wood"], "n": 3}], "at": ["ember_village"]}$q$::jsonb, $q$[{"s": null, "t": "복례가 아궁이 깊숙한 곳의 불씨를 부지깽이로 살살 일으킨다. 작지만 꺼지지 않는 붉은빛이다."}, {"s": "q:sn_bokrye", "t": "나라가 망하던 밤에 성에서 들고 나온 불씨요. 그 뒤로 한 번도 안 꺼졌지."}, {"s": "q:sn_bokrye", "t": "자, 이 불로 지어 보시오. 건량 짓는 법은 어렵지 않아요."}]$q$::jsonb, $q${"xp": 160}$q$::jsonb),
  ($q$sq_ember_village_1$q$, 3, $q$남겨 둔 한 봉지$q$, $q$노정 건량 세 개를 지어 갈매에게 건네기$q$, $q${"tasks": [{"t": "craft", "items": ["travel_ration"], "n": 3}], "at": ["ember_village"], "give": {"travel_ration": 3}}$q$::jsonb, $q$[{"s": "southern_remnant:galmae", "t": "됐소, 이만하면 대원들 사흘은 버티오."}, {"s": null, "t": "갈매가 건량 하나를 슬쩍 따로 품에 넣는다."}, {"s": "me", "t": "그건 누구 몫입니까."}, {"s": "southern_remnant:galmae", "t": "지난달 해안에서 못 돌아온 녀석이오. 무덤 앞에 놓아 줄 거요. 그놈이 어멈 건량을 제일 좋아했지."}, {"s": "q:sn_bokrye", "t": "그럼 하나 더 지어야겠네. 산 사람 몫이 모자라면 안 되니."}]$q$::jsonb, $q${"xp": 160, "gil": 25, "items": {"spicy_stew": 1}}$q$::jsonb),
  ($q$sq_ember_village_2$q$, 1, $q$부러진 칼날$q$, $q$잔불촌 대장간에서 쇠불 만나기$q$, $q${"at": ["ember_village"]}$q$::jsonb, $q$[{"s": null, "t": "모루 위에 칼 한 자루가 두 동강 나 있다. 칼자루에 망국 군부의 문장이 닳아 있다."}, {"s": "q:sn_soebul", "t": "장군님 칼입니다. 어제 연무하다 부러졌어요. 장군님은 괜찮다 하시지만 얼굴이 아니에요."}, {"s": "q:sn_soebul", "t": "다시 벼리려면 쇠가 있어야 합니다. 월철 광석이랑 생 월철을 좀 구해 주십시오. 어느 산에서 캐셔도 됩니다."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_ember_village_2$q$, 2, $q$광석 자루$q$, $q$월철 광석 세 번, 생 월철 두 번 채집하기$q$, $q${"tasks": [{"t": "gather", "items": ["ore"], "n": 3}, {"t": "gather", "items": ["raw_iron"], "n": 2}], "at": ["ember_village"]}$q$::jsonb, $q$[{"s": "q:sn_soebul", "t": "좋은 쇠입니다. 이제 주괴로 녹이기만 하면 돼요."}, {"s": "q:sn_soebul", "t": "제 풀무는 장군님 칼 녹이는 데 써야 하니, 주괴는 조사원님이 좀 만들어 주시겠어요?"}, {"s": "me", "t": "그러지요."}]$q$::jsonb, $q${"xp": 206}$q$::jsonb),
  ($q$sq_ember_village_2$q$, 3, $q$칼 대신 쟁기$q$, $q$월철 주괴 두 개를 만들어 쇠불에게 건네기$q$, $q${"tasks": [{"t": "craft", "items": ["iron_ingot"], "n": 2}], "at": ["ember_village"], "give": {"iron_ingot": 2}}$q$::jsonb, $q$[{"s": "southern_remnant:jang", "t": "쇠불아, 그 쇠로 내 칼을 벼리지 마라."}, {"s": "q:sn_soebul", "t": "장군님, 하지만."}, {"s": "southern_remnant:jang", "t": "한 팔로 휘두를 칼은 이 부러진 걸로도 넉넉하다. 그 쇠는 아이들 쟁기 날로 써라."}, {"s": "southern_remnant:jang", "t": "나라는 칼로 지켜지지 않았다. 남은 건 밭을 가는 손이다."}, {"s": null, "t": "쇠불은 한참 모루를 내려다보다가 부러진 칼을 벽에 조심스레 걸었다."}]$q$::jsonb, $q${"xp": 206, "gil": 29, "items": {"repair_kit": 1}}$q$::jsonb),
  ($q$sq_ash_coast_1$q$, 1, $q$삭은 그물$q$, $q$재의 해안에서 어부 덕만 만나기$q$, $q${"at": ["ash_coast"]}$q$::jsonb, $q$[{"s": null, "t": "모래 위에 펼쳐 둔 그물이 손만 대도 잿가루처럼 부서진다."}, {"s": "q:sn_deokman", "t": "바다에 재가 섞이고부터 그물이 한 철을 못 가오."}, {"s": "q:sn_deokman", "t": "수향 갈대로 엮고 수귀 비늘로 추를 달면 버틴다더군. 이 해안에도 그게 나오오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_ash_coast_1$q$, 2, $q$갯가의 갈대$q$, $q$재의 해안에서 수향 갈대 세 번 채집하기$q$, $q${"tasks": [{"t": "gather", "items": ["river_reed"], "r": ["ash_coast"], "n": 3}], "at": ["ash_coast"]}$q$::jsonb, $q$[{"s": null, "t": "덕만이 갈대 한 줄기를 손에 감아 힘껏 당겨 본다. 끊어지지 않는다."}, {"s": "q:sn_deokman", "t": "질기구먼. 이거면 되겠소."}, {"s": "q:sn_deokman", "t": "비늘은 재갈매기 떼가 물어 가기 전에 주워야 하오. 저놈들이 반짝이는 건 다 채 가거든."}]$q$::jsonb, $q${"xp": 440}$q$::jsonb),
  ($q$sq_ash_coast_1$q$, 3, $q$그물코마다$q$, $q$재갈매기 떼를 쫓고 수귀 비늘을 모아 갈대와 함께 건네기$q$, $q${"tasks": [{"t": "win", "m": ["g_ash_coast"], "n": 2}, {"t": "gather", "items": ["drowned_scale"], "r": ["ash_coast"], "n": 2}], "at": ["ash_coast"], "give": {"river_reed": 3, "drowned_scale": 2}}$q$::jsonb, $q$[{"s": null, "t": "덕만이 그물을 엮는 동안, 언제 왔는지 무녀 소이가 곁에 앉아 낮게 노래를 부른다."}, {"s": "southern_remnant:soi", "t": "한 코에 한 이름, 두 코에 두 이름. 바다에 진 이들 이름을 엮어 넣는 노래예요."}, {"s": "q:sn_deokman", "t": "옛날엔 그물 엮을 때 꼭 이 노래를 불렀소. 그래야 바다가 그물을 안 찢는다고."}, {"s": "southern_remnant:soi", "t": "바다도 이름 불리는 걸 좋아하거든요. 잊히는 게 제일 무섭대요."}, {"s": null, "t": "새 그물이 바다로 던져진다. 이번에는 잿물이 그물코를 그냥 지나간다."}]$q$::jsonb, $q${"xp": 440, "gil": 45, "items": {"fish_porridge": 1}}$q$::jsonb),
  ($q$sq_ash_coast_2$q$, 1, $q$떠오른 관선$q$, $q$재의 해안에서 정찰대장 갈매 만나기$q$, $q${"at": ["ash_coast"]}$q$::jsonb, $q$[{"s": "southern_remnant:galmae", "t": "등대를 끄라는 명령서 얘기는 들었소. 그런데 오늘 아침 해안에 배 하나가 떠올랐소."}, {"s": "southern_remnant:galmae", "t": "흑련회 배가 아니오. 뱃머리에 야행국 본부 관선 표식이 있소."}, {"s": "southern_remnant:galmae", "t": "본부 사람인 당신이 뒤져 보는 게 낫겠지. 우리가 하면 또 남명회가 꾸몄다 할 테니."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_ash_coast_2$q$, 2, $q$물 먹은 선실$q$, $q$재의 해안을 세 번 탐색하고 단서 하나 찾기$q$, $q${"tasks": [{"t": "search", "r": ["ash_coast"], "n": 3}, {"t": "clue", "n": 1}], "at": ["ash_coast"]}$q$::jsonb, $q$[{"s": null, "t": "선실 바닥 궤짝 안에서 기름종이로 싼 항해일지가 나온다. 마지막 장만 먹이 번지지 않았다."}, {"s": null, "t": "「명령서를 받았다. 등대를 끄라 한다. 인장은 진짜다. 그러나 나는 따르지 않겠다.」"}, {"s": "me", "t": "명령을 거부한 배였군. 그런데 왜 가라앉았을까."}, {"s": null, "t": "갑판 위로 젖은 갑옷 소리가 다가온다. 배를 떠나지 못한 선원들이다."}]$q$::jsonb, $q${"xp": 586}$q$::jsonb),
  ($q$sq_ash_coast_2$q$, 3, $q$따르지 않은 자들$q$, $q$난파선 망령을 잠재우고 잔불촌에 일지 알리기$q$, $q${"tasks": [{"t": "win", "m": ["x_ash_coast_2"], "n": 2}], "at": ["ember_village"]}$q$::jsonb, $q$[{"s": "southern_remnant:jang", "t": "선장이 명령을 거부하자 같은 날 밤 배에 불이 났다고 적혀 있군."}, {"s": "southern_remnant:jang", "t": "본부 안에 등대를 끄려는 자가 있었고, 그걸 막으려다 죽은 자도 있었다는 얘기다."}, {"s": "southern_remnant:galmae", "t": "본부 놈들이 다 같은 놈들은 아니었다는 거요?"}, {"s": "southern_remnant:jang", "t": "이름을 지운 자들만 있었던 건 아니라는 거다. 이 선장 이름은 우리가 기억하자."}, {"s": "southern_remnant:soi", "t": "노래 끝에 한 줄 더 붙일게요. 불을 지키다 간 사람."}]$q$::jsonb, $q${"xp": 586, "gil": 53, "items": {"revival_charm": 1}}$q$::jsonb),
  ($q$sq_crimson_mine_1$q$, 1, $q$멈추지 않는 소리$q$, $q$주혈 광산 입구에서 광부 반장 맹구 만나기$q$, $q${"at": ["crimson_mine"]}$q$::jsonb, $q$[{"s": "q:sn_maenggu", "t": "막장이 무너진 지 여섯 해요. 그런데 밤마다 그 안에서 곡괭이 소리가 나오."}, {"s": "q:sn_maenggu", "t": "그날 갇힌 광부가 열하나. 하나도 못 꺼냈지."}, {"s": "q:sn_maenggu", "t": "가는 길엔 광석 지네가 들끓소. 길부터 터 주시오. 나는 뒤따라가겠소."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_crimson_mine_1$q$, 2, $q$지네 굴$q$, $q$광석 지네 세 마리 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["x_crimson_mine_1"], "n": 3}], "at": ["crimson_mine"]}$q$::jsonb, $q$[{"s": null, "t": "지네 굴을 따라 내려갈수록 곡괭이 소리가 또렷해진다. 하나가 아니라 여럿이다."}, {"s": "q:sn_maenggu", "t": "저 박자. 우리 조가 쓰던 박자요. 셋 치고 한 번 쉬고."}, {"s": "me", "t": "아직 일을 하고 있는 겁니다."}]$q$::jsonb, $q${"xp": 390}$q$::jsonb),
  ($q$sq_crimson_mine_1$q$, 3, $q$캐는 손$q$, $q$갱도 원령 두 마리 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["x_crimson_mine_2"], "n": 2}], "at": ["crimson_mine"]}$q$::jsonb, $q$[{"s": null, "t": "갱도 원령들은 쓰러지면서도 곡괭이를 놓지 않는다. 그 발목마다 붉은 광맥 줄기가 감겨 있다."}, {"s": "q:sn_maenggu", "t": "광맥이 붙잡고 있는 거요. 쉬지도 못하게 캐게 하고."}, {"s": "q:sn_maenggu", "t": "맨 안쪽에 광맥왕이 있을 거요. 그놈이 무너뜨린 거요, 그날 막장을."}]$q$::jsonb, $q${"xp": 390}$q$::jsonb),
  ($q$sq_crimson_mine_1$q$, 4, $q$셋 치고 한 번 쉬고$q$, $q$주혈 광맥왕 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["regional_crimson_mine_guardian"], "n": 1}], "at": ["crimson_mine"]}$q$::jsonb, $q$[{"s": null, "t": "광맥왕이 무너지자 갱도 전체에서 곡괭이 소리가 한꺼번에 멎는다."}, {"s": "q:sn_maenggu", "t": "조사원, 하나 털어놓겠소. 그날 막장이 흔들릴 때 내가 제일 먼저 뛰었소. 반장이란 놈이."}, {"s": "q:sn_maenggu", "t": "뒤에서 누가 내 이름을 불렀는데 돌아보지 않았지."}, {"s": null, "t": "어둠 속에서 마지막으로 한 번, 곡괭이가 바위를 친다. 셋을 치고 한 번 쉬는 박자처럼, 느리고 고르게."}, {"s": "q:sn_maenggu", "t": "다 끝났다는 소리요. 우리 조는 일 끝나면 꼭 저렇게 한 번 쳤소."}]$q$::jsonb, $q${"xp": 390, "gil": 53, "items": {"clear_spirit_pill": 2}}$q$::jsonb),
  ($q$sq_crimson_mine_2$q$, 1, $q$캐다 만 광맥$q$, $q$주혈 광산에서 맹구의 부탁 듣기$q$, $q${"at": ["crimson_mine"]}$q$::jsonb, $q$[{"s": "q:sn_maenggu", "t": "막장 벽에 그날 캐다 만 광맥이 그대로 있소. 다들 그 몫을 받지 못하고 갔지."}, {"s": "q:sn_maenggu", "t": "그 광석을 캐서 가족들한테 보내고 싶소. 대부분 잔불촌에 산다오."}, {"s": "q:sn_maenggu", "t": "내 손으로 캐야 하는데, 팔이 떨려 곡괭이를 못 들겠소."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_crimson_mine_2$q$, 2, $q$열한 자루$q$, $q$주혈 광산에서 월철 광석 세 번, 강철 주괴 두 번 채집하기$q$, $q${"tasks": [{"t": "gather", "items": ["ore"], "r": ["crimson_mine"], "n": 3}, {"t": "gather", "items": ["steel_ingot"], "r": ["crimson_mine"], "n": 2}], "at": ["crimson_mine"]}$q$::jsonb, $q$[{"s": null, "t": "맹구가 광석을 열한 몫으로 나누고 자루마다 이름을 적는다. 글씨가 삐뚤다."}, {"s": "me", "t": "강철 덩이까지 있으니 값이 꽤 나가겠습니다."}, {"s": "q:sn_maenggu", "t": "잔불촌까지 같이 가 주시오. 혼자 가면 문 앞에서 돌아설 것 같소."}]$q$::jsonb, $q${"xp": 666}$q$::jsonb),
  ($q$sq_crimson_mine_2$q$, 3, $q$잔불촌 마당에서$q$, $q$잔불촌에서 광석과 주괴를 건네기$q$, $q${"tasks": [{"t": "travel", "r": ["ember_village"], "n": 1}], "at": ["ember_village"], "give": {"ore": 3, "steel_ingot": 2}}$q$::jsonb, $q$[{"s": null, "t": "광부 가족들이 마당에 모인다. 맹구는 고개를 들지 못하고 자루만 내민다."}, {"s": "southern_remnant:soi", "t": "이 이름들, 노래에 넣어도 될까요? 광산 노래는 아직 없었거든요."}, {"s": null, "t": "한 노파가 자루를 받아 들고 맹구의 떨리는 손을 오래 쥐어 준다."}, {"s": "q:sn_maenggu", "t": "원망하시오. 그래야 내가 편하오."}, {"s": null, "t": "노파는 대답 없이 고개만 젓는다. 소이의 노래가 첫 이름을 부르기 시작한다."}]$q$::jsonb, $q${"xp": 666, "gil": 57, "items": {"iron_ingot": 2}}$q$::jsonb),
  ($q$sq_red_forest_1$q$, 1, $q$물린 동료$q$, $q$혈엽림에서 약초꾼 화옥 만나기$q$, $q${"at": ["red_forest"]}$q$::jsonb, $q$[{"s": "q:sn_hwaok", "t": "같이 다니던 동료가 단풍 독거미에 물렸소. 독이 다리에서 가슴으로 올라오는 중이오."}, {"s": "q:sn_hwaok", "t": "회춘단이면 잡을 수 있소. 영맥 수피와 약제 바탕이 있어야 하는데 이 숲에 다 있지."}, {"s": "q:sn_hwaok", "t": "나는 동료 곁을 지켜야 하니 재료를 좀 모아 주시오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_red_forest_1$q$, 2, $q$붉은 수피$q$, $q$혈엽림에서 영맥 수피와 약제 바탕 두 번씩 채집하기$q$, $q${"tasks": [{"t": "gather", "items": ["spirit_bark"], "r": ["red_forest"], "n": 2}, {"t": "gather", "items": ["medicine_base"], "r": ["red_forest"], "n": 2}], "at": ["red_forest"]}$q$::jsonb, $q$[{"s": "q:sn_hwaok", "t": "좋은 수피요. 껍질 안쪽이 아직 붉군."}, {"s": null, "t": "화옥이 재료를 받으려 손을 뻗다 멈칫한다. 소매 끝이 젖어 있고, 다리를 끈다."}, {"s": "q:sn_hwaok", "t": "단은 조사원께서 빚어 주시오. 내 손이 지금 좀 떨려서."}]$q$::jsonb, $q${"xp": 586}$q$::jsonb),
  ($q$sq_red_forest_1$q$, 3, $q$남의 이야기$q$, $q$회춘단 두 개를 빚어 하나를 화옥에게 건네기$q$, $q${"tasks": [{"t": "craft", "items": ["rejuv_pill"], "n": 2}], "at": ["red_forest"], "give": {"rejuv_pill": 1}}$q$::jsonb, $q$[{"s": null, "t": "화옥은 단을 받자마자 제 입에 털어 넣는다. 걷어 올린 바짓단 아래 검게 부은 상처가 보인다."}, {"s": "me", "t": "물린 건 당신이었군요."}, {"s": "q:sn_hwaok", "t": "약초꾼이 제가 물렸다 하면 누가 숲 안까지 따라와 주겠소. 다들 동료 얘기엔 마음이 약하지."}, {"s": "q:sn_hwaok", "t": "속인 건 미안하오. 남은 하나는 조사원께서 가지시오. 이 숲에선 누구든 언젠가 물리니."}]$q$::jsonb, $q${"xp": 586, "gil": 53, "items": {"herb": 3}}$q$::jsonb),
  ($q$sq_red_forest_2$q$, 1, $q$가지에 붙은 잎$q$, $q$혈엽림에서 무녀 소이 만나기$q$, $q${"at": ["red_forest"]}$q$::jsonb, $q$[{"s": "southern_remnant:soi", "t": "이 숲 잎은 나라 망하던 해 군사들 피로 붉어졌대요. 그래도 해마다 지긴 했어요."}, {"s": "southern_remnant:soi", "t": "올해는 하나도 안 져요. 겨울이 왔는데도 가지에 매달려 있어요."}, {"s": "southern_remnant:galmae", "t": "낙엽 원령이 숲길을 막아 정찰대도 못 지나가오. 먼저 그것들부터 치워 주시오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_red_forest_2$q$, 2, $q$흩어지지 못한 낙엽$q$, $q$낙엽 원령 세 마리 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["x_red_forest_2"], "n": 3}], "at": ["red_forest"]}$q$::jsonb, $q$[{"s": null, "t": "원령이 흩어진 자리의 낙엽마다 녹슨 갑옷 비늘이 하나씩 붙어 있다."}, {"s": "southern_remnant:soi", "t": "남명 군사 갑옷이에요. 노래에서 들은 그대로."}, {"s": "southern_remnant:soi", "t": "숲 한가운데 혈엽수인이 잎을 붙잡고 있을 거예요. 그 곁엔 늘 독거미가 지키고요."}]$q$::jsonb, $q${"xp": 666}$q$::jsonb),
  ($q$sq_red_forest_2$q$, 3, $q$이름을 불러 주는 노래$q$, $q$혈엽수인과 단풍 독거미 쓰러뜨리기$q$, $q${"tasks": [{"t": "win", "m": ["m_21"], "n": 1}, {"t": "win", "m": ["regional_red_forest_guardian"], "n": 1}], "at": ["red_forest"]}$q$::jsonb, $q$[{"s": null, "t": "쓰러진 혈엽수인의 몸이 나무껍질처럼 갈라지고, 그 안에서 갑옷 입은 병사의 손이 가지를 꽉 쥐고 있다."}, {"s": "southern_remnant:soi", "t": "잎이 지면 잊힐까 봐 붙잡고 있었던 거예요."}, {"s": null, "t": "소이가 옛말 섞인 노래로 이름 하나하나를 부른다. 이름이 불릴 때마다 잎이 하나씩 떨어진다."}, {"s": "southern_remnant:galmae", "t": "다 지는구먼. 이제야 겨울이네."}, {"s": "southern_remnant:soi", "t": "내년에도 붉어질 거예요. 그래도 이제는 질 줄 알 거예요."}]$q$::jsonb, $q${"xp": 666, "gil": 57, "items": {"spirit_bark": 2, "spirit_qi_pill": 1}}$q$::jsonb),
  ($q$sq_nine_lighthouse_1$q$, 1, $q$어두운 끝섬$q$, $q$구등대 군도에서 별순 만나기$q$, $q${"at": ["nine_lighthouse"]}$q$::jsonb, $q$[{"s": "q:sn_byeolsun", "t": "아버지가 사라지고 등대 불이 꺼졌어요. 지난달에만 배가 두 척 부딪혔어요."}, {"s": "q:sn_byeolsun", "t": "등잔은 제가 걸 수 있어요. 기름이 없어요. 아버지는 바닷고기 기름을 썼어요."}, {"s": "q:sn_byeolsun", "t": "고기를 잡아 기름을 내 주실 수 있어요? 등잔 만드는 것도 좀 가르쳐 주시고요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_nine_lighthouse_1$q$, 2, $q$고기 기름$q$, $q$구등대 군도에서 세 마리 낚고 등롱 어유 두 병 만들기$q$, $q${"tasks": [{"t": "fish", "r": ["nine_lighthouse"], "n": 3}, {"t": "craft", "items": ["lantern_oil"], "n": 2}], "at": ["nine_lighthouse"]}$q$::jsonb, $q$[{"s": null, "t": "끓인 어유가 병 속에서 노랗게 맑아진다. 비린내 사이로 묘하게 따뜻한 냄새가 난다."}, {"s": "q:sn_byeolsun", "t": "냄새가 아버지 옷에서 나던 냄새예요."}, {"s": "q:sn_byeolsun", "t": "이제 등잔이에요. 아버지 등잔은 바다에 떨어졌어요."}]$q$::jsonb, $q${"xp": 500}$q$::jsonb),
  ($q$sq_nine_lighthouse_1$q$, 3, $q$새 등잔$q$, $q$어유 등잔 하나 만들기$q$, $q${"tasks": [{"t": "craft", "items": ["fish_oil_lamp"], "n": 1}], "at": ["nine_lighthouse"]}$q$::jsonb, $q$[{"s": null, "t": "등잔에 불이 붙자 등대 꼭대기 어둠 속에서 무거운 발소리가 내려온다."}, {"s": null, "t": "녹슨 등대지기 옷을 입은 그림자가 불빛을 향해 손을 뻗는다. 불을 끄려는 손이다."}, {"s": "q:sn_byeolsun", "t": "아버지 옷이에요. 아버지가 왜 불을."}, {"s": "me", "t": "물러서 있어요. 등잔은 제가 지키겠습니다."}]$q$::jsonb, $q${"xp": 500}$q$::jsonb),
  ($q$sq_nine_lighthouse_1$q$, 4, $q$불을 미워한 등대지기$q$, $q$꺼진 등대지기를 쓰러뜨리고 등잔을 별순에게 건네기$q$, $q${"tasks": [{"t": "win", "m": ["regional_nine_lighthouse_guardian"], "n": 1}], "at": ["nine_lighthouse"], "give": {"fish_oil_lamp": 1}}$q$::jsonb, $q$[{"s": null, "t": "꺼진 등대지기가 무너지며 짧게 중얼거린다. 「불을 켜면, 저것들이 온다.」"}, {"s": "q:sn_byeolsun", "t": "아버지는 불을 지키다가, 불에 몰려드는 것들 때문에 불을 미워하게 됐나 봐요."}, {"s": null, "t": "별순이 계단을 올라 등잔을 건다. 바다 위로 길게 빛이 뻗는다."}, {"s": "q:sn_byeolsun", "t": "그래도 저는 켤래요. 배가 부딪히는 것보다는 낫잖아요."}, {"s": null, "t": "멀리 어둠 속에서 다른 등대 하나가 대답하듯 잠깐 깜빡인다. 아홉 중 하나다."}]$q$::jsonb, $q${"xp": 500, "gil": 61, "items": {"fish_oil_lamp": 1, "lantern_oil": 1}}$q$::jsonb),
  ($q$sq_nine_lighthouse_2$q$, 1, $q$한 쌍의 종$q$, $q$구등대 군도에서 무녀 소이 만나기$q$, $q${"at": ["nine_lighthouse"]}$q$::jsonb, $q$[{"s": "southern_remnant:soi", "t": "북쪽 얼음 아래 종이 있었다면서요. 우리 노래에도 종이 나와요."}, {"s": "southern_remnant:soi", "t": "「아홉 불 아래 종이 잔다, 울리면 이름이 진다.」 할머니가 부르던 대목이에요."}, {"s": "southern_remnant:soi", "t": "북쪽과 남쪽 종이 한 쌍이라면, 남쪽 종은 여기 어딘가에 있어야 해요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_nine_lighthouse_2$q$, 2, $q$바위틈 쇠고리$q$, $q$구등대 군도를 세 번 탐색하기$q$, $q${"tasks": [{"t": "search", "r": ["nine_lighthouse"], "n": 3}], "at": ["nine_lighthouse"]}$q$::jsonb, $q$[{"s": null, "t": "가장 오래된 등대 아래 갯바위에 어른 팔뚝만 한 쇠고리가 박혀 있다. 종을 걸던 고리다."}, {"s": null, "t": "고리는 비어 있다. 끊긴 자리가 날카롭고, 녹이 아직 덜 슬었다."}, {"s": "me", "t": "누군가 떼어 간 지 오래되지 않았군."}]$q$::jsonb, $q${"xp": 840}$q$::jsonb),
  ($q$sq_nine_lighthouse_2$q$, 3, $q$종 없이 종소리를 듣는 이들$q$, $q$등불 원령 두 마리를 잠재우고 단서 하나 찾기$q$, $q${"tasks": [{"t": "win", "m": ["x_nine_lighthouse_2"], "n": 2}, {"t": "clue", "n": 1}], "at": ["nine_lighthouse"]}$q$::jsonb, $q$[{"s": null, "t": "쇠고리에 검은 연꽃 매듭이 감겨 있다. 흑련회의 매듭이다."}, {"s": null, "t": "등불 원령들은 종이 없는 고리를 향해 고개를 숙이고 있다. 아무 소리도 없는데 무언가를 듣는 얼굴이다."}, {"s": "southern_remnant:soi", "t": "저분들이 종을 울린 사람들이에요. 그래서 이름을 잃고 등불이 된 거고요."}, {"s": "southern_remnant:soi", "t": "종은 떠났는데 소리는 아직 여기 있어요. 아홉 불이 꺼지면 이 소리도 어디론가 가겠지요."}, {"s": "me", "t": "흑련회가 종을 가져갔다면, 등대를 끄는 것도 그들일 겁니다."}]$q$::jsonb, $q${"xp": 840, "gil": 65, "items": {"mirror_shard": 2, "ward_talisman": 1}}$q$::jsonb),
  ($q$sq_bone_market_1$q$, 1, $q$손끝으로 읽는 어음$q$, $q$백골 장터의 뼈 감정사를 만난다$q$, $q${"at": ["bone_market"]}$q$::jsonb, $q$[{"s": null, "t": "좌판 위에 하얀 뼈 조각이 줄지어 놓였다. 노파가 하나를 집어 손끝으로 쓸어 본다."}, {"s": "q:rn_gobun", "t": "야행국 사람이로구먼. 마침 잘 왔소. 이걸 좀 보시오."}, {"s": "q:rn_gobun", "t": "장터에선 뼈에 빚을 새겨 주고받소. 그런데 이 어음엔 붉은 달 인장이 찍혀 있소. 교령에서 쓰지 않은 지 오래된 인장이오."}, {"s": "me", "t": "얼음 아래로 이름을 바치던 그 서약의 인장입니까."}, {"s": "q:rn_gobun", "t": "그건 내 알 바 아니고. 이 뼈는 적사 황무지 모래 냄새가 나오. 누가 거기서 빚을 받으러 다니는지 알아봐 주시오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_bone_market_1$q$, 2, $q$모래 속 빚쟁이$q$, $q$적사 황무지를 탐색해 단서를 찾는다$q$, $q${"tasks": [{"t": "search", "r": ["red_plain"], "n": 3}, {"t": "clue", "n": 1}], "at": ["red_plain"]}$q$::jsonb, $q$[{"s": null, "t": "모래언덕 그늘에 반쯤 묻힌 천막이 있다. 안에는 빈 장부와 새로 깎은 뼈 어음 몇 장."}, {"s": "me", "t": "어음마다 이름 칸이 비어 있습니다. 갚을 사람을 적지 않은 빚이라니."}, {"s": null, "t": "천막 기둥에 모래가 쓸고 간 글씨가 남아 있다. 「이름을 잃은 자의 빚은 교령이 거둔다」."}, {"s": "me", "t": "빚을 핑계로 이름을 거두어 가는 겁니다. 장터로 돌아가 알려야겠습니다."}]$q$::jsonb, $q${"xp": 413}$q$::jsonb),
  ($q$sq_bone_market_1$q$, 3, $q$지워진 칸$q$, $q$백골 장터의 고분에게 돌아가 알린다$q$, $q${"at": ["bone_market"]}$q$::jsonb, $q$[{"s": "q:rn_gobun", "t": "이름 칸이 비었다고? 허허, 그럼 그건 어음이 아니라 명부요."}, {"s": "q:rn_gobun", "t": "요 몇 달 장터에서 빚진 사람들이 하나둘 보이지 않았지. 다들 도망친 줄만 알았소."}, {"s": "red_moon_cult:danbi", "t": "어머, 감정사 할멈. 손님이 귀한 걸 들고 오셨네요. 그건 제가 거둬 갈게요."}, {"s": null, "t": "주홍 무녀가 웃으며 어음을 집어 소매에 넣는다. 아무도 막지 않는다."}, {"s": "q:rn_gobun", "t": "……보았소? 장터에선 저것이 법이오. 그래도 고맙소. 내 장부엔 그 사람들 이름을 다시 적어 두리다."}]$q$::jsonb, $q${"gil": 29, "items": {"ward_talisman": 1, "spirit_tea": 2}}$q$::jsonb),
  ($q$sq_bone_market_2$q$, 1, $q$빈 화살통$q$, $q$백골 장터의 상단 호위를 만난다$q$, $q${"at": ["bone_market"]}$q$::jsonb, $q$[{"s": "q:rn_dalgu", "t": "이보시오, 야행국 양반. 화살 좀 깎을 줄 아시오?"}, {"s": "q:rn_dalgu", "t": "상단이 내일 새벽 황무지를 건너는데, 화살 값을 깜빡하고 술값으로 다 썼지 뭐요."}, {"s": "q:rn_dalgu", "t": "장터 화살장은 뼈 어음만 받는다는데, 난 뼈 빚까진 지고 싶지 않소."}, {"s": "me", "t": "직접 깎아 드리지요. 몇 대면 됩니까."}, {"s": "q:rn_dalgu", "t": "많을수록 좋지! 아, 독수리가 덤벼드는 길이니 끝은 단단하게."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_bone_market_2$q$, 2, $q$깎고 다듬고$q$, $q$화살을 만들어 호위에게 넘긴다$q$, $q${"tasks": [{"t": "craft", "items": ["ammo_arrow"], "n": 3}], "at": ["bone_market"], "give": {"ammo_arrow": 3}}$q$::jsonb, $q$[{"s": "q:rn_dalgu", "t": "오, 촉이 반듯하구먼. 내가 깎은 것보다 낫소."}, {"s": "q:rn_dalgu", "t": "그런데 하나 부탁이 더 있소. 길목 독수리들이 요즘 유난히 사납다오."}, {"s": "q:rn_dalgu", "t": "상단이 지나기 전에 몇 마리만 쫓아 주시겠소? 화살 맛을 먼저 보여 주는 셈 치고."}, {"s": "me", "t": "화살이 제대로 나는지 확인도 할 겸 다녀오겠습니다."}]$q$::jsonb, $q${"xp": 160}$q$::jsonb),
  ($q$sq_bone_market_2$q$, 3, $q$새벽 길목$q$, $q$적사 황무지에서 요괴를 쫓아낸다$q$, $q${"tasks": [{"t": "win", "r": ["red_plain"], "n": 3}], "at": ["red_plain"]}$q$::jsonb, $q$[{"s": null, "t": "붉은 모래 위로 해가 오른다. 멀리 상단의 방울 소리가 들린다."}, {"s": "q:rn_dalgu", "t": "하하, 길이 깨끗하구먼! 독수리 한 마리 안 보이오."}, {"s": "q:rn_dalgu", "t": "이번 일은 술값으로 갚겠다고 하면 화내시겠지. 대신 이건 받으시오. 상단에서 남은 거요."}, {"s": "me", "t": "다음엔 화살 값부터 챙기세요."}, {"s": "q:rn_dalgu", "t": "그럴 리가. 그래야 또 야행국 양반을 부르지 않겠소."}]$q$::jsonb, $q${"xp": 160, "gil": 25, "items": {"travel_ration": 2, "clear_spirit_pill": 1}}$q$::jsonb),
  ($q$sq_red_plain_1$q$, 1, $q$끊긴 길$q$, $q$적사 황무지의 길잡이를 만난다$q$, $q${"at": ["red_plain"]}$q$::jsonb, $q$[{"s": "q:rn_sapyeong", "t": "내 발자국을 따라오면 길을 잃지 않는다. 삼십 년 동안 그랬소."}, {"s": "q:rn_sapyeong", "t": "그런데 지난밤 순례자 셋이 내 발자국 위에서 사라졌소. 발자국은 거기서 뚝 끊겼고."}, {"s": "me", "t": "모래 밑에 무언가 있다는 말씀이군요."}, {"s": "q:rn_sapyeong", "t": "전갈이 늘었소. 전갈이 늘면 그 밑에 큰 놈이 있지. 먼저 작은 것들부터 걷어 주시오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_red_plain_1$q$, 2, $q$붉은 집게$q$, $q$붉은 전갈과 사구귀를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["g_red_plain"], "n": 3}, {"t": "win", "m": ["m_09"], "n": 1}], "at": ["red_plain"]}$q$::jsonb, $q$[{"s": null, "t": "전갈을 걷어 내자 모래가 숨을 쉬듯 오르내린다."}, {"s": "q:rn_sapyeong", "t": "보이시오? 모래가 숨을 쉬고 있소. 놈이 밑에서 기다리는 거요."}, {"s": "q:rn_sapyeong", "t": "길잡이는 모래와 싸우지 않소. 하지만 오늘은 당신이 있으니."}, {"s": "me", "t": "끌어내겠습니다. 물러서 계세요."}]$q$::jsonb, $q${"xp": 206}$q$::jsonb),
  ($q$sq_red_plain_1$q$, 3, $q$모래 밑의 왕$q$, $q$모래 매복귀를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["regional_red_plain_guardian"], "n": 1}], "at": ["red_plain"]}$q$::jsonb, $q$[{"s": null, "t": "거대한 몸이 모래로 흩어지자 그 밑에서 순례자의 지팡이 세 자루가 나온다."}, {"s": "q:rn_sapyeong", "t": "……늦었구려. 그래도 지팡이는 돌려보낼 수 있겠소."}, {"s": "q:rn_sapyeong", "t": "순례자들은 지팡이에 이름을 새기오. 이름이 남았으니 길을 잃은 건 아니오."}, {"s": "me", "t": "그렇게 믿겠습니다."}, {"s": "q:rn_sapyeong", "t": "내일부터 발자국을 조금 더 깊이 찍겠소. 고맙소."}]$q$::jsonb, $q${"xp": 206, "gil": 29, "items": {"spirit_qi_pill": 1, "travel_ration": 2}}$q$::jsonb),
  ($q$sq_red_plain_2$q$, 1, $q$붉은 손$q$, $q$적사 황무지의 주사 광부를 만난다$q$, $q${"at": ["red_plain"]}$q$::jsonb, $q$[{"s": "q:rn_chadol", "t": "야행국이 서약 문서를 뒤진다고 들었소. 그 붉은 글씨, 내가 캔 주사로 쓴 거요."}, {"s": "q:rn_chadol", "t": "교령은 주사를 갈아 서약 먹을 만들었소. 이름을 적으면 지워지지 않는 먹이라 했지."}, {"s": "me", "t": "그 먹으로 지워진 이름들을 얼음 아래 바쳤습니다."}, {"s": "q:rn_chadol", "t": "알아. 그래서 말하는 거요. 주사를 다시 캐 주시오. 그 먹을 거꾸로 풀 방법이 있소."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_red_plain_2$q$, 2, $q$주사와 옥$q$, $q$주사 광물과 옥 파편을 캔다$q$, $q${"tasks": [{"t": "gather", "items": ["cinnabar"], "r": ["red_plain"], "n": 4}, {"t": "gather", "items": ["jade_shard"], "r": ["red_plain"], "n": 2}], "at": ["red_plain"]}$q$::jsonb, $q$[{"s": "q:rn_chadol", "t": "좋은 광맥이오. 붉은 줄이 굵구먼."}, {"s": "q:rn_chadol", "t": "옥은 먹을 가라앉히고, 주사는 글씨를 세우오. 둘을 함께 갈면 서약 먹과 반대가 되지."}, {"s": "q:rn_chadol", "t": "이름을 묶는 대신 풀어 주는 먹이오. 내 할아버지가 몰래 쓰던 방법이오."}, {"s": "me", "t": "그럼 그 먹으로 무엇을 합니까?"}, {"s": "q:rn_chadol", "t": "넘겨 주시오. 나머지는 내 손으로 갈겠소."}]$q$::jsonb, $q${"xp": 258}$q$::jsonb),
  ($q$sq_red_plain_2$q$, 3, $q$푸는 먹$q$, $q$주사와 옥을 넘긴다$q$, $q${"at": ["red_plain"], "give": {"cinnabar": 4, "jade_shard": 2}}$q$::jsonb, $q$[{"s": null, "t": "차돌이 돌절구에 주사와 옥을 넣고 천천히 간다. 붉은 가루가 점점 옅어진다."}, {"s": "q:rn_chadol", "t": "보시오. 이 먹으로 서약 문서를 덧쓰면 이름이 종이에서 떠오르오."}, {"s": "q:rn_chadol", "t": "다 돌아오진 않겠지. 하지만 누가 바쳐졌는지는 알게 될 거요."}, {"s": "me", "t": "야행국 기록관에게 전하겠습니다."}, {"s": "q:rn_chadol", "t": "내 이름은 빼 주시오. 난 아직 교령에서 살아야 하니."}]$q$::jsonb, $q${"xp": 258, "gil": 33, "items": {"sealing_ink": 1, "ward_talisman": 1}}$q$::jsonb),
  ($q$sq_glass_canyon_1$q$, 1, $q$바람 굽는 가마$q$, $q$유리협곡의 유리장이를 만난다$q$, $q${"at": ["glass_canyon"]}$q$::jsonb, $q$[{"s": null, "t": "협곡 바람이 가마 불을 휘젓는다. 여인이 맨손으로 뜨거운 유리를 굴린다."}, {"s": "q:rn_haerang", "t": "협곡 유리는 바람이 굽는 거예요. 저는 거들 뿐이지요."}, {"s": "q:rn_haerang", "t": "영유리를 모아 주세요. 큰 거울을 하나 만들어야 해요."}, {"s": "me", "t": "무엇을 비추려고요?"}, {"s": "q:rn_haerang", "t": "……협곡엔 같은 얼굴 둘이 걸어 다닌대요. 그중 하나가 제 동생인지 보고 싶어요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_glass_canyon_1$q$, 2, $q$바람이 남긴 것$q$, $q$영유리와 요기 결정을 모은다$q$, $q${"tasks": [{"t": "gather", "items": ["spirit_glass"], "r": ["glass_canyon"], "n": 4}, {"t": "gather", "items": ["spirit_dust"], "r": ["glass_canyon"], "n": 2}], "at": ["glass_canyon"], "give": {"spirit_glass": 4}}$q$::jsonb, $q$[{"s": "q:rn_haerang", "t": "맑네요. 이 정도면 사람 얼굴이 아니라 혼까지 비치겠어요."}, {"s": "q:rn_haerang", "t": "요기 결정은 유리에 녹여 넣을 거예요. 요괴도 거울에 비치게."}, {"s": null, "t": "해랑이 유리를 녹여 둥근 거울을 뜬다. 식어 가는 거울에 두 사람의 얼굴이 비친다. 그런데 하나가 더 있다."}, {"s": "q:rn_haerang", "t": "……봤어요? 지금 제 뒤에."}, {"s": "me", "t": "보았습니다. 같은 얼굴이 하나 더."}]$q$::jsonb, $q${"xp": 627, "gil": 37, "items": {"spirit_qi_pill": 1, "spirit_tea": 2}}$q$::jsonb),
  ($q$sq_glass_canyon_2$q$, 1, $q$거울이 가리킨 곳$q$, $q$해랑의 이야기를 듣는다$q$, $q${"at": ["glass_canyon"]}$q$::jsonb, $q$[{"s": "q:rn_haerang", "t": "그건 제 동생이 아니었어요. 동생 얼굴을 쓴 무언가였지요."}, {"s": "q:rn_haerang", "t": "경면쌍생이라고, 사람 얼굴을 베껴 쓰는 요괴래요. 베낀 얼굴의 주인은 거울 속에 갇힌다고요."}, {"s": "q:rn_haerang", "t": "그 요괴를 깨면 동생이 거울에서 나올까요?"}, {"s": "me", "t": "모르겠습니다. 하지만 갇혀 있게 둘 순 없지요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_glass_canyon_2$q$, 2, $q$바람 속의 그림자$q$, $q$협곡 바람귀를 걷어 내고 경면쌍생을 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_glass_canyon_2"], "n": 2}, {"t": "win", "m": ["m_10"], "n": 2}], "at": ["glass_canyon"]}$q$::jsonb, $q$[{"s": null, "t": "경면쌍생이 깨지며 유리 조각이 바람에 흩어진다. 조각마다 다른 얼굴이 비친다."}, {"s": null, "t": "해랑의 거울이 한 번 크게 울린다. 거울 안에서 누군가 손을 흔든다."}, {"s": "q:rn_haerang", "t": "……웃고 있어요. 저 애, 저렇게 웃었어요."}, {"s": "q:rn_haerang", "t": "나오진 못하나 봐요. 그래도 이제 다른 것에게 얼굴을 빌려주진 않겠지요."}, {"s": "me", "t": "거울은 어떻게 하실 겁니까."}, {"s": "q:rn_haerang", "t": "가마 옆에 걸어 둘래요. 바람이 굽는 동안 같이 보라고요."}]$q$::jsonb, $q${"xp": 749, "gil": 41, "items": {"spirit_glass": 2, "rejuv_pill": 1}}$q$::jsonb),
  ($q$sq_black_sand_temple_1$q$, 1, $q$벽 너머의 독경$q$, $q$흑사단 폐단의 순찰 교도를 만난다$q$, $q${"at": ["black_sand_temple"]}$q$::jsonb, $q$[{"s": "q:rn_mukhyang", "t": "쉿. 들리십니까? 벽 안에서 아직도 독경을 합니다."}, {"s": "q:rn_mukhyang", "t": "흑사단이 쫓겨난 지 오래인데 기도는 멈추지 않았습니다. 들은 교도들이 하나둘 잠을 못 잡니다."}, {"s": "q:rn_mukhyang", "t": "교령에 말하면 겁쟁이라 하겠지요. 야행국 부적이라면 틈을 막을 수 있지 않겠습니까."}, {"s": "me", "t": "황지부터 모아야겠군요. 이 근처에서 구할 수 있습니까."}, {"s": "q:rn_mukhyang", "t": "폐단 안쪽 제단에 마른 황지가 쌓여 있습니다. 기도문을 적다 만 종이지요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_black_sand_temple_1$q$, 2, $q$적다 만 기도문$q$, $q$폐단에서 황지를 모은다$q$, $q${"tasks": [{"t": "gather", "items": ["seal_paper"], "r": ["black_sand_temple"], "n": 3}], "at": ["black_sand_temple"]}$q$::jsonb, $q$[{"s": null, "t": "주워 온 황지마다 기도문이 반쯤 적혀 있다. 끝 문장이 모두 같은 데서 끊겼다."}, {"s": "me", "t": "「이름을 바쳐」. 거기서 다 끊겼습니다."}, {"s": "q:rn_mukhyang", "t": "그 뒤를 적으면 기도가 끝나는 걸까요, 시작되는 걸까요."}, {"s": "me", "t": "둘 다 아닙니다. 뒷면에 정화 부적을 그리지요. 기도를 덮어 버리면 됩니다."}]$q$::jsonb, $q${"xp": 440}$q$::jsonb),
  ($q$sq_black_sand_temple_1$q$, 3, $q$틈을 막는 종이$q$, $q$정화 부적을 만들어 순찰 교도에게 넘긴다$q$, $q${"tasks": [{"t": "craft", "items": ["ward_talisman"], "n": 2}], "at": ["black_sand_temple"], "give": {"ward_talisman": 2}}$q$::jsonb, $q$[{"s": null, "t": "부적을 벽 틈에 붙이자 독경 소리가 한 겹씩 멀어진다. 마지막 한 줄이 꼬리처럼 남았다가 사라진다."}, {"s": "q:rn_mukhyang", "t": "……조용합니다. 이 벽이 조용한 건 처음 들어 봅니다."}, {"s": "q:rn_mukhyang", "t": "이건 교령엔 비밀로 해 주십시오. 야행국 부적에 기댄 걸 알면 저도 벽 안으로 들어가야 합니다."}, {"s": "me", "t": "부적은 오래 가지 않습니다. 기도가 다시 들리면 부르세요."}, {"s": "q:rn_mukhyang", "t": "그 전에 제가 그리는 법을 배우겠습니다. 오늘 밤엔 잘 수 있겠군요."}]$q$::jsonb, $q${"xp": 440, "gil": 45, "items": {"talisman_thread": 3, "calm_brew": 1}}$q$::jsonb),
  ($q$sq_black_sand_temple_2$q$, 1, $q$부르지 못하는 아이$q$, $q$폐단 앞에서 이름 없는 사환을 만난다$q$, $q${"at": ["black_sand_temple"]}$q$::jsonb, $q$[{"s": null, "t": "폐단 계단에 아이 하나가 앉아 있다. 누가 불러도 돌아보지 않는다."}, {"s": "q:rn_sahwan", "t": "……부르셨어요? 미안해요. 이름을 불러 줘야 알아듣는데, 다들 제 이름을 잊었어요."}, {"s": "q:rn_sahwan", "t": "단주님이 단원 모두의 이름을 문에 바쳤대요. 저는 심부름 가 있어서 그날 없었어요."}, {"s": "me", "t": "그런데 왜 다들 이름을 잊었지?"}, {"s": "q:rn_sahwan", "t": "명부에 제 줄만 비었대요. 이름은 남았는데 적힌 데가 없어서, 아무도 못 읽나 봐요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_black_sand_temple_2$q$, 2, $q$젖지 않은 명부$q$, $q$폐단을 뒤져 명부의 흔적을 찾는다$q$, $q${"tasks": [{"t": "search", "r": ["black_sand_temple"], "n": 3}, {"t": "clue", "n": 1}], "at": ["black_sand_temple"]}$q$::jsonb, $q$[{"s": null, "t": "무너진 서고 밑에서 명부 한 권이 나온다. 마지막 줄만 먹이 번지지 않은 채 비어 있다."}, {"s": "me", "t": "모두의 이름이 지워진 자리엔 먹 자국이 남았는데, 이 줄은 처음부터 비었군요."}, {"s": null, "t": "빈 줄 옆에 작은 손글씨. 「심부름 아이. 돌아오면 이름을 묻고 적을 것」."}, {"s": "me", "t": "단주는 적으려고 했던 겁니다. 문에 바치기 전에."}, {"s": "q:rn_sahwan", "t": "……그럼 저도 바쳐질 뻔했어요?"}]$q$::jsonb, $q${"xp": 1171}$q$::jsonb),
  ($q$sq_black_sand_temple_2$q$, 3, $q$다시 적는 이름$q$, $q$기록관에게 명부를 가져간다$q$, $q${"at": ["hq_archive", "hq_yard"]}$q$::jsonb, $q$[{"s": "night_office:mo", "t": "이건…… 흑사단 명부로군요. 원본이 남아 있을 줄은 몰랐어요."}, {"s": "night_office:mo", "t": "바친 이름은 되돌릴 수 없어요. 하지만 빈 줄에 새로 적는 건 누구도 막지 못하지요."}, {"s": "night_office:mo", "t": "야행국 장부에 그 아이 이름을 적어 두겠습니다. 문에 바쳐진 명부가 아니라 우리 장부에요."}, {"s": "me", "t": "아이에게 이름을 물어보고 오겠습니다."}, {"s": null, "t": "폐단 계단의 아이가 돌아본다. 처음으로, 부르기도 전에."}, {"s": "q:rn_sahwan", "t": "제 이름은요……"}]$q$::jsonb, $q${"gil": 53, "items": {"spirit_qi_pill": 2, "ward_talisman": 1}}$q$::jsonb),
  ($q$sq_red_moon_fort_1$q$, 1, $q$열리지 않는 문$q$, $q$월식성 바깥 문지기를 만난다$q$, $q${"at": ["red_moon_fort"]}$q$::jsonb, $q$[{"s": "q:rn_takmu", "t": "멈춰라. 야행국 개가 여긴 왜 왔나."}, {"s": "q:rn_takmu", "t": "……대호법께서 기다리신다. 들어가기 전에 시험이 있다."}, {"s": "red_moon_cult:sama", "t": "하하, 그만 짖어라, 탁무. 손님이다."}, {"s": "red_moon_cult:sama", "t": "요즘 성벽에 박쥐와 미친 교도가 들끓는다. 내 교도들로는 성이 차지 않아."}, {"s": "red_moon_cult:sama", "t": "네가 쓸 만한지 보자. 성벽을 한 바퀴 돌고 오너라."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_red_moon_fort_1$q$, 2, $q$성벽 한 바퀴$q$, $q$월식 박쥐 떼와 월식 교도를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_red_moon_fort_1"], "n": 3}, {"t": "win", "m": ["g_red_moon_fort"], "n": 2}], "at": ["red_moon_fort"]}$q$::jsonb, $q$[{"s": "q:rn_takmu", "t": "……살아 돌아왔군."}, {"s": "red_moon_cult:sama", "t": "살아 돌아오는 게 시험이었지. 그런데 넌 숨도 안 찼구나."}, {"s": "red_moon_cult:sama", "t": "좋다. 하나 더. 혈월 무사들이 내 말을 안 듣는다. 월식 이후로 눈빛이 이상해."}, {"s": "red_moon_cult:sama", "t": "죽이지 말고 눕혀만 놔라. 깨어나면 내가 물어보겠다."}]$q$::jsonb, $q${"xp": 840}$q$::jsonb),
  ($q$sq_red_moon_fort_1$q$, 3, $q$눈빛 붉은 무사$q$, $q$혈월 무사를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_red_moon_fort_2"], "n": 2}], "at": ["red_moon_fort"]}$q$::jsonb, $q$[{"s": null, "t": "쓰러진 혈월 무사의 눈동자가 천천히 원래 빛으로 돌아온다."}, {"s": "red_moon_cult:sama", "t": "돌아왔군. 월식 날 하늘을 너무 오래 봤나 보다."}, {"s": "red_moon_cult:sama", "t": "야행국. 네 이름은 기억해 두마. 적이 되면 내가 직접 상대하지."}, {"s": "me", "t": "그 날이 오지 않기를 바랍니다."}, {"s": "q:rn_takmu", "t": "……대호법께서 사람 이름을 외우시는 건 드문 일이다. 조심해라."}]$q$::jsonb, $q${"xp": 840, "gil": 65, "items": {"rejuv_pill": 1, "spirit_qi_pill": 2}}$q$::jsonb),
  ($q$sq_red_moon_fort_2$q$, 1, $q$뒤뜰 약방$q$, $q$월식성 약방 노파를 만난다$q$, $q${"at": ["red_moon_fort"]}$q$::jsonb, $q$[{"s": "q:rn_eunsil", "t": "대호법이 보낸 사람이구먼. 무사들 눈을 고칠 약을 찾지?"}, {"s": "q:rn_eunsil", "t": "월식 날 붉은 달을 오래 본 놈들은 꿈속에서도 달을 봐. 잠을 못 자니 눈이 돌아가는 게지."}, {"s": "q:rn_eunsil", "t": "마음을 가라앉히는 탕과 달빛 정수가 있어야 해. 내 손은 떨려서 정수를 못 뽑는다오."}, {"s": "me", "t": "제가 달여 보겠습니다."}, {"s": "q:rn_eunsil", "t": "달빛은 붉은 달 말고 흰 달에서 받아야 해. 그것만 잊지 마."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_red_moon_fort_2$q$, 2, $q$흰 달의 정수$q$, $q$안신탕과 월광 정수를 만들어 넘긴다$q$, $q${"tasks": [{"t": "craft", "items": ["calm_brew"], "n": 2}, {"t": "craft", "items": ["moonlight_essence"], "n": 1}], "at": ["red_moon_fort"], "give": {"calm_brew": 2, "moonlight_essence": 1}}$q$::jsonb, $q$[{"s": "q:rn_eunsil", "t": "냄새가 좋구먼. 쓸 만해."}, {"s": null, "t": "노파가 안신탕을 무사들 입에 한 숟갈씩 흘려 넣는다. 거친 숨이 하나둘 고르게 바뀐다."}, {"s": "q:rn_eunsil", "t": "교주님은 붉은 달을 믿으라 하시고, 나는 흰 달로 약을 달이지. 우습지?"}, {"s": "q:rn_eunsil", "t": "그래도 여기 사람들은 아프면 날 찾아와. 교리 대신."}, {"s": "me", "t": "약방이 오래 열려 있기를 바랍니다."}, {"s": "q:rn_eunsil", "t": "그러려면 야행국도 가끔 약초 좀 갖다 주시게."}]$q$::jsonb, $q${"xp": 1869, "gil": 69, "items": {"herbal_extract": 2, "moon_moss": 2}}$q$::jsonb),
  ($q$sq_ash_mountain_1$q$, 1, $q$꺼져 가는 풀무$q$, $q$회산 관문 대장장이를 만난다$q$, $q${"at": ["ash_mountain"]}$q$::jsonb, $q$[{"s": null, "t": "관문 옆 대장간. 풀무 불이 허옇게 식어 간다."}, {"s": "q:rn_cheolbu", "t": "쇠가 없소. 맹주께선 겨울 전에 창 백 자루를 원하시는데."}, {"s": "q:rn_cheolbu", "t": "화구 근처에 생 월철이 흐르오. 거기 강철 덩이도 굳어 있고. 쥐떼만 아니면 내가 직접 가겠는데."}, {"s": "me", "t": "제가 캐 오겠습니다."}, {"s": "q:rn_cheolbu", "t": "불 옆에서 캐야 하오. 뜨거우니 손 조심하고."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_ash_mountain_1$q$, 2, $q$잿더미 사이$q$, $q$생 월철과 강철 주괴를 캔다$q$, $q${"tasks": [{"t": "gather", "items": ["raw_iron"], "r": ["ash_mountain"], "n": 4}, {"t": "gather", "items": ["steel_ingot"], "r": ["ash_mountain"], "n": 2}], "at": ["ash_mountain"]}$q$::jsonb, $q$[{"s": null, "t": "잿더미 쥐떼가 광맥 주변을 갉아 놓았다. 그 틈에서 붉게 달아오른 쇳줄이 보인다."}, {"s": "me", "t": "화구의 열기로 쇠가 저절로 녹았다 굳었습니다. 질이 좋군요."}, {"s": "q:rn_cheolbu", "t": "넘겨 주시오. 오늘 밤 풀무를 다시 살리겠소."}]$q$::jsonb, $q${"xp": 258}$q$::jsonb),
  ($q$sq_ash_mountain_1$q$, 3, $q$다시 붉은 불$q$, $q$대장장이에게 쇠를 넘긴다$q$, $q${"at": ["ash_mountain"], "give": {"raw_iron": 4, "steel_ingot": 2}}$q$::jsonb, $q$[{"s": null, "t": "풀무가 숨을 들이켜고 불이 다시 붉어진다. 망치 소리가 관문을 울린다."}, {"s": "q:rn_cheolbu", "t": "이 소리요. 이게 들려야 관문 사람들이 잠을 자오."}, {"s": "q:rn_cheolbu", "t": "고맙소. 하나 더 부탁할 게 있는데…… 아니, 내일 말하리다. 오늘은 두드려야겠소."}]$q$::jsonb, $q${"xp": 258, "gil": 33, "items": {"charcoal": 2, "repair_kit": 1}}$q$::jsonb),
  ($q$sq_ash_mountain_2$q$, 1, $q$내일의 부탁$q$, $q$대장장이의 부탁을 듣는다$q$, $q${"at": ["ash_mountain"]}$q$::jsonb, $q$[{"s": "q:rn_cheolbu", "t": "어제 하려던 말이오. 호송대 장비가 엉망이오."}, {"s": "north_league:yeo", "t": "잔도에서 바람에 긁히고 얼음에 깨졌지. 고칠 손이 모자라."}, {"s": "q:rn_cheolbu", "t": "월철 주괴를 녹여 수리 도구를 만들어 주시오. 내 망치는 창에 묶여 있소."}, {"s": "north_league:yeo", "t": "잘 만들어 주면 다음 호송 때 앞자리를 내주지. 거기가 제일 경치가 좋아."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_ash_mountain_2$q$, 2, $q$두드린 만큼$q$, $q$월철 주괴와 수리 도구를 만들어 넘긴다$q$, $q${"tasks": [{"t": "craft", "items": ["iron_ingot"], "n": 3}, {"t": "craft", "items": ["repair_kit"], "n": 1}], "at": ["ash_mountain"], "give": {"repair_kit": 1}}$q$::jsonb, $q$[{"s": "q:rn_cheolbu", "t": "……이음매가 곱소. 대장장이 손이로구먼."}, {"s": "north_league:yeo", "t": "좋아. 이걸로 방패 서른 개는 살리겠어."}, {"s": "q:rn_cheolbu", "t": "관문 쇠는 원래 화구에서 왔소. 그 불이 꺼지지 않는 한 북령은 무너지지 않소."}, {"s": "north_league:yeo", "t": "앞자리 약속은 지킨다. 눈보라 칠 때 오면 더 재미있을 거야."}, {"s": "me", "t": "맑은 날로 부탁드립니다."}]$q$::jsonb, $q${"xp": 627, "gil": 37, "items": {"iron_ingot": 2, "travel_ration": 2}}$q$::jsonb),
  ($q$sq_iron_monastery_1$q$, 1, $q$돌아오지 않은 심부름$q$, $q$철벽 고찰의 수좌를 만난다$q$, $q${"at": ["iron_monastery"]}$q$::jsonb, $q$[{"s": "north_league:hyegak", "t": "허허, 오셨습니까. 앉으시지요. 차 한 잔 하실 틈은 없겠지만."}, {"s": "north_league:hyegak", "t": "막내 행자를 옥문 협로로 심부름 보냈는데, 사흘째 돌아오지 않습니다."}, {"s": "north_league:hyegak", "t": "밤마다 잔도에서 목탁 소리가 들린다 합니다. 살아 있다는 뜻이지요."}, {"s": "north_league:hyegak", "t": "잔도엔 매복귀가 붙어 삽니다. 혹 만나시거든, 제 대신 한 대씩 눕혀 주십시오. 세게."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_iron_monastery_1$q$, 2, $q$바람 속의 목탁$q$, $q$옥문 협로의 잔도 매복귀를 쓰러뜨리고 행자를 찾는다$q$, $q${"tasks": [{"t": "win", "m": ["x_jade_pass_2"], "n": 2}, {"t": "win", "m": ["g_jade_pass"], "n": 2}], "at": ["jade_pass"]}$q$::jsonb, $q$[{"s": null, "t": "매복귀를 걷어 내자 잔도 바위 틈에서 목탁 소리가 또렷해진다."}, {"s": "q:rn_doyun", "t": "……사람이에요? 요괴 아니죠? 목탁을 멈추면 그것들이 다가와서, 계속 쳤어요."}, {"s": "q:rn_doyun", "t": "팔이 떨어질 것 같아요. 수좌님이 염불은 멈추지 말라고 하셔서."}, {"s": "me", "t": "잘 버텼다. 이제 내려가자."}]$q$::jsonb, $q${"xp": 880}$q$::jsonb),
  ($q$sq_iron_monastery_1$q$, 3, $q$돌아온 목탁$q$, $q$행자를 데리고 고찰로 돌아간다$q$, $q${"at": ["iron_monastery"]}$q$::jsonb, $q$[{"s": "north_league:hyegak", "t": "도윤아. 사흘이나 목탁을 쳤느냐."}, {"s": "q:rn_doyun", "t": "네. 한 번도 안 멈췄어요."}, {"s": "north_league:hyegak", "t": "장하다. 그럼 오늘은 저녁 공양 전까지 마당을 쓸어라. 사흘 치."}, {"s": "q:rn_doyun", "t": "수좌님……"}, {"s": "north_league:hyegak", "t": "하하. 조사원님, 고맙습니다. 저 아이가 웃으면 고찰이 따뜻해지지요."}]$q$::jsonb, $q${"gil": 45, "items": {"calm_brew": 1, "spirit_qi_pill": 1, "ward_talisman": 1}}$q$::jsonb),
  ($q$sq_iron_monastery_2$q$, 1, $q$바람이 찢은 기도$q$, $q$철벽 고찰의 깃발지기를 만난다$q$, $q${"at": ["iron_monastery"]}$q$::jsonb, $q$[{"s": "q:rn_jeongsim", "t": "산문의 깃발은 바람에 기도를 실어 보내는 것입니다."}, {"s": "q:rn_jeongsim", "t": "지난 눈보라에 깃발 셋이 찢어졌지요. 그 뒤로 산문 밖에서 길 잃는 사람이 늘었습니다."}, {"s": "q:rn_jeongsim", "t": "영사 실타래로 다시 짜야 합니다. 부적실을 꼬아 영기를 먹이면 되지요."}, {"s": "me", "t": "부적실은 어디서 구합니까."}, {"s": "q:rn_jeongsim", "t": "흑사단 폐단이나 무덤가에 많습니다. 기도가 깊었던 곳에서 실도 질기지요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_iron_monastery_2$q$, 2, $q$질긴 실$q$, $q$부적실을 모으고 영사 실타래를 만든다$q$, $q${"tasks": [{"t": "gather", "items": ["talisman_thread"], "n": 3}, {"t": "craft", "items": ["spirit_thread"], "n": 2}], "at": ["iron_monastery"], "give": {"spirit_thread": 2}}$q$::jsonb, $q$[{"s": null, "t": "정심이 실타래를 깃대에 감는다. 바람이 불자 깃발이 소리 없이 펼쳐진다."}, {"s": "q:rn_jeongsim", "t": "……북쪽에서 바람이 옵니다. 얼음 냄새가 섞였군요."}, {"s": "q:rn_jeongsim", "t": "이 깃발이 펄럭이는 동안은 산문 밖에서도 고찰이 보일 겁니다."}, {"s": "me", "t": "길 잃은 사람이 줄면 좋겠습니다."}, {"s": "q:rn_jeongsim", "t": "깃발은 길을 알려 주지 않습니다. 돌아갈 곳이 있다는 것만 알려 주지요."}]$q$::jsonb, $q${"xp": 749, "gil": 41, "items": {"silk": 2, "ward_talisman": 1}}$q$::jsonb),
  ($q$sq_jade_pass_1$q$, 1, $q$빈 보따리$q$, $q$옥문 협로의 호송대 막내를 만난다$q$, $q${"at": ["jade_pass"]}$q$::jsonb, $q$[{"s": "q:rn_chorong", "t": "대장님이 약 보따리를 채워 오라 하셨어요. 그런데 저 혼자서는 잔도 끝까지 못 가요."}, {"s": "q:rn_chorong", "t": "밤에 잔도에 푸른 등불이 떠다녀요. 옛날 호송대 등불지기 귀신이래요."}, {"s": "north_league:yeo", "t": "초롱아, 또 귀신 얘기냐. 조사원, 미안하지만 약초 좀 같이 캐 줘."}, {"s": "north_league:yeo", "t": "야령초랑 부적목 수지야. 수지는 상처에 바르고 얼음 깨진 짐도 붙이지."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_jade_pass_1$q$, 2, $q$잔도 끝$q$, $q$야령초와 부적목 수지를 모은다$q$, $q${"tasks": [{"t": "gather", "items": ["herb"], "r": ["jade_pass"], "n": 4}, {"t": "gather", "items": ["resin"], "r": ["jade_pass"], "n": 2}], "at": ["jade_pass"]}$q$::jsonb, $q$[{"s": null, "t": "잔도 끝 바위틈에서 야령초를 뜯는데, 등 뒤로 푸른빛이 스친다."}, {"s": "q:rn_chorong", "t": "봤죠? 봤죠! 등불이에요!"}, {"s": null, "t": "푸른 등불은 다가오지 않는다. 멀리서 길 쪽을 비출 뿐이다."}, {"s": "me", "t": "우리를 해치려는 것 같진 않다. 길을 비추고 있어."}, {"s": "q:rn_chorong", "t": "……등불지기였으니까요. 아직도 일하는 걸까요."}]$q$::jsonb, $q${"xp": 440}$q$::jsonb),
  ($q$sq_jade_pass_1$q$, 3, $q$채운 보따리$q$, $q$호송대장에게 약초를 넘긴다$q$, $q${"at": ["jade_pass"], "give": {"herb": 4, "resin": 2}}$q$::jsonb, $q$[{"s": "north_league:yeo", "t": "이 정도면 겨울 호송 두 번은 버티겠다. 수고했어."}, {"s": "q:rn_chorong", "t": "대장님, 등불을 봤어요. 길을 비춰 줬어요."}, {"s": "north_league:yeo", "t": "……청등 호송대 말이냐. 이십 년 전 눈사태에 묻힌 호송대지."}, {"s": "north_league:yeo", "t": "요즘 그 등불이 사람을 홀려 낭떠러지로 끈다는 말도 있어. 어느 쪽이 맞는지 모르겠군."}]$q$::jsonb, $q${"xp": 440, "gil": 45, "items": {"herbal_extract": 1, "spirit_tea": 2}}$q$::jsonb),
  ($q$sq_jade_pass_2$q$, 1, $q$두 갈래 소문$q$, $q$호송대장의 이야기를 듣는다$q$, $q${"at": ["jade_pass"]}$q$::jsonb, $q$[{"s": "north_league:yeo", "t": "청등 호송대는 내 스승이 이끌던 대였어. 눈사태 날 짐을 끝까지 안 놓았지."}, {"s": "north_league:yeo", "t": "그런데 지난달 상인 둘이 푸른 등불을 따라가다 떨어졌어. 같은 등불이 아니야."}, {"s": "q:rn_chorong", "t": "그럼 착한 등불이랑 나쁜 등불이 같이 있는 거예요?"}, {"s": "north_league:yeo", "t": "가 보면 알겠지. 조사원, 나쁜 쪽이 있으면 꺼 줘."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_jade_pass_2$q$, 2, $q$두 개의 등불$q$, $q$청등 호송귀와 비취 수문장을 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_jade"], "n": 2}, {"t": "win", "m": ["regional_jade_pass_guardian"], "n": 1}], "at": ["jade_pass"]}$q$::jsonb, $q$[{"s": null, "t": "청등 호송귀가 쓰러지자 들고 있던 등불이 꺼진다. 그 뒤에서 또 하나의 푸른 등불이 흔들린다."}, {"s": null, "t": "비취 수문장이 무너진 자리, 눈 속에서 녹슨 등롱 하나가 나온다. 등롱엔 「청등」 두 글자."}, {"s": "north_league:yeo", "t": "……스승의 등롱이야. 나쁜 놈들이 이 등불을 흉내 냈던 거군."}, {"s": null, "t": "남은 등불 하나가 잔도 아래를 한 번 비추고는 천천히 사그라든다."}, {"s": "q:rn_chorong", "t": "갔어요. 길을 다 비추고 간 것 같아요."}, {"s": "north_league:yeo", "t": "이 등롱은 초롱이 네가 들어라. 이제 무서워하지 말고."}]$q$::jsonb, $q${"xp": 1021, "gil": 49, "items": {"fish_oil_lamp": 1, "spirit_qi_pill": 2}}$q$::jsonb),
  ($q$sq_frost_valley_1$q$, 1, $q$숨 쉬는 얼음$q$, $q$빙혼곡의 인장 파수를 만난다$q$, $q${"at": ["frost_valley"]}$q$::jsonb, $q$[{"s": "north_league:seok", "t": "왔나. 종은 끌려갔지만 얼음은 아직 숨을 쉰다."}, {"s": "north_league:seok", "t": "인장 둘레 얼음이 묽어졌다. 종이 빠져나간 구멍으로 바람이 든다."}, {"s": "q:rn_seolbaek", "t": "빙정염을 뿌려 얼음을 다지면 됩니다. 녹지 않는 소금이지요."}, {"s": "q:rn_seolbaek", "t": "다만 골짜기 깊은 곳에서만 납니다. 늑대들이 그 근처에 굴을 팠고요."}, {"s": "north_league:seok", "t": "말은 됐다. 캐 와라."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_frost_valley_1$q$, 2, $q$골짜기 소금$q$, $q$빙정염을 캔다$q$, $q${"tasks": [{"t": "gather", "items": ["frost_salt"], "r": ["frost_valley"], "n": 5}], "at": ["frost_valley"]}$q$::jsonb, $q$[{"s": null, "t": "빙정염 결정이 손바닥에서 차갑게 빛난다. 손끝이 얼얼하다."}, {"s": "q:rn_seolbaek", "t": "좋은 결정입니다. 이거면 인장 둘레를 한 겹 다질 수 있겠어요."}, {"s": "q:rn_seolbaek", "t": "……그런데 혹시 캐면서 들으셨습니까. 얼음 밑에서 무언가 두드리는 소리."}, {"s": "me", "t": "들었습니다. 종이 떠난 자리에 아직 무언가 남아 있습니까?"}, {"s": "q:rn_seolbaek", "t": "모르겠습니다. 다지고 나면 조용해지겠지요."}]$q$::jsonb, $q${"xp": 586}$q$::jsonb),
  ($q$sq_frost_valley_1$q$, 3, $q$다진 얼음$q$, $q$빙정염을 넘기고 인장 둘레를 다진다$q$, $q${"at": ["frost_valley"], "give": {"frost_salt": 5}}$q$::jsonb, $q$[{"s": null, "t": "설백이 소금을 뿌리자 묽던 얼음이 하얗게 굳는다. 두드리던 소리가 멎는다."}, {"s": "north_league:seok", "t": "됐다."}, {"s": "q:rn_seolbaek", "t": "맹주님, 소리가 멎기 직전에 마지막으로 세 번 울렸습니다. 사람이 문 두드리듯."}, {"s": "north_league:seok", "t": "……얼음 밑에 사람은 없다. 잊어라."}, {"s": null, "t": "맹주의 손이 얼음 위 인장을 오래 짚고 있다."}]$q$::jsonb, $q${"xp": 586, "gil": 53, "items": {"spirit_core": 1, "ward_talisman": 1}}$q$::jsonb),
  ($q$sq_frost_valley_2$q$, 1, $q$세 번의 소리$q$, $q$인장 파수의 고백을 듣는다$q$, $q${"at": ["frost_valley"]}$q$::jsonb, $q$[{"s": "q:rn_seolbaek", "t": "맹주님이 잊으라 하셨지만, 저는 잊을 수가 없습니다."}, {"s": "q:rn_seolbaek", "t": "얼음 인장을 처음 세운 날, 북령맹 장수 하나가 안에 남았다고 합니다. 종을 지키겠다고요."}, {"s": "q:rn_seolbaek", "t": "빙혼 장수가 골짜기를 도는 것도 그날부터랍니다. 혹시 그 장수가……"}, {"s": "me", "t": "확인하겠습니다. 장수를 쓰러뜨려 보면 알겠지요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_frost_valley_2$q$, 2, $q$빙혼 장수$q$, $q$빙벽 갑귀와 빙혼 장수를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_frost_valley_2"], "n": 2}, {"t": "win", "m": ["m_14"], "n": 1}], "at": ["frost_valley"]}$q$::jsonb, $q$[{"s": null, "t": "빙혼 장수가 무릎을 꿇는다. 투구 틈으로 사람의 눈이 보이다가 서리처럼 흩어진다."}, {"s": null, "t": "녹아내린 갑옷 안에서 북령맹 패 하나가 떨어진다. 패에 새긴 이름은 반쯤 닳았다."}, {"s": "north_league:seok", "t": "……석진후. 내 형이다."}, {"s": "north_league:seok", "t": "종이 떠났으니 지킬 것도 없었겠지. 그래서 문을 두드렸나 보다. 나가겠다고."}, {"s": "q:rn_seolbaek", "t": "맹주님."}, {"s": "north_league:seok", "t": "패는 고찰에 올려라. 조사원, 고맙다. 이건 갚지 않겠다. 잊지 않겠다는 뜻이다."}]$q$::jsonb, $q${"xp": 1331, "gil": 57, "items": {"rejuv_pill": 1, "spirit_qi_pill": 2}}$q$::jsonb),
  ($q$sq_sky_lake_1$q$, 1, $q$물에 비친 하늘$q$, $q$천경호 낚시꾼을 만난다$q$, $q${"at": ["sky_lake"]}$q$::jsonb, $q$[{"s": null, "t": "얼음 학이 호수 위를 난다. 물에 비친 학과 하늘의 학이 똑같이 움직인다."}, {"s": "q:rn_yunga", "t": "쉿. 지금 물이 하늘을 비추고 있네. 이럴 때만 천경 백어가 올라오지."}, {"s": "q:rn_yunga", "t": "딸아이가 병이 깊어. 천경 백어로 끓인 죽을 먹으면 낫는다는 옛말이 있네."}, {"s": "q:rn_yunga", "t": "내 손이 떨려서 챔질을 못 해. 자네가 대신 낚아 주겠나."}, {"s": "me", "t": "해 보겠습니다. 백어가 아니어도 괜찮습니까."}, {"s": "q:rn_yunga", "t": "고기가 올라와야 백어도 올라오는 법이지."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_sky_lake_1$q$, 2, $q$떨리는 줄$q$, $q$천경호에서 물고기를 낚는다$q$, $q${"tasks": [{"t": "fish", "r": ["sky_lake"], "n": 4}], "at": ["sky_lake"]}$q$::jsonb, $q$[{"s": null, "t": "줄이 팽팽해진다. 은빛 비늘이 물 위로 튀어 오르며 하늘빛을 뿌린다."}, {"s": "q:rn_yunga", "t": "그래, 그거야! 놓치지 말게!"}, {"s": "q:rn_yunga", "t": "……허허, 사십 년 만에 남이 낚는 걸 보니 내가 낚은 것보다 좋구먼."}, {"s": "me", "t": "따님께 가져가시지요."}, {"s": "q:rn_yunga", "t": "아니, 아직이네. 죽을 쑬 줄 아는 사람이 하나 더 필요해."}]$q$::jsonb, $q${"xp": 1331, "gil": 57, "items": {"lantern_oil": 1, "spirit_tea": 2}}$q$::jsonb),
  ($q$sq_sky_lake_2$q$, 1, $q$죽 쑤는 법$q$, $q$낚시꾼 윤가의 부탁을 듣는다$q$, $q${"at": ["sky_lake"]}$q$::jsonb, $q$[{"s": "q:rn_yunga", "t": "죽은 원래 아내가 쑤었네. 나는 낚기만 했지."}, {"s": "q:rn_yunga", "t": "아내가 떠난 뒤로 딸아이는 생선 냄새만 맡아도 운다네. 어미 생각이 난다고."}, {"s": "q:rn_yunga", "t": "그래도 먹여야지. 자네가 쑤어 주게. 내 손맛이 아니니 울지 않을지도 몰라."}, {"s": "me", "t": "약초를 넣은 찜도 함께 만들겠습니다. 기운을 돋우게요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_sky_lake_2$q$, 2, $q$두 그릇$q$, $q$어죽과 약초 생선찜을 만들어 넘긴다$q$, $q${"tasks": [{"t": "craft", "items": ["fish_porridge"], "n": 2}, {"t": "craft", "items": ["herb_fish_steam"], "n": 1}], "at": ["sky_lake"], "give": {"fish_porridge": 2, "herb_fish_steam": 1}}$q$::jsonb, $q$[{"s": null, "t": "호숫가 오두막. 아이가 이불 밖으로 얼굴을 내민다."}, {"s": "q:rn_yunga", "t": "아가, 이건 조사원 양반이 쑤었다. 아버지 것 아니다."}, {"s": null, "t": "아이가 한 숟갈 뜨더니 멈춘다. 그리고 다시 한 숟갈."}, {"s": "q:rn_yunga", "t": "……안 우는구나."}, {"s": "q:rn_yunga", "t": "고맙네. 다음엔 내가 쑤어 보겠네. 아내 맛은 아니어도, 내 맛으로."}, {"s": null, "t": "창밖으로 물에 비친 하늘이 잔잔하다."}]$q$::jsonb, $q${"xp": 1501, "gil": 61, "items": {"spirit_gukbap": 1, "mirror_shard": 2}}$q$::jsonb),
  ($q$sq_thunder_peak_1$q$, 1, $q$벼락 쫓는 사내$q$, $q$뇌명봉의 벼락 수집꾼을 만난다$q$, $q${"at": ["thunder_peak"]}$q$::jsonb, $q$[{"s": "q:rn_beongae", "t": "오, 사람이다! 여긴 사람이 잘 안 와. 벼락이 무서워서."}, {"s": "q:rn_beongae", "t": "나는 세 번 맞았지. 그래서 이름도 번개야. 원래 이름은 까먹었어."}, {"s": "q:rn_beongae", "t": "벼락 맞은 바위엔 영핵이 굳어. 그걸 모으고 있는데, 요즘 뇌조가 내 몫을 먹어 치워."}, {"s": "me", "t": "영핵을 함께 모아 드리지요."}, {"s": "q:rn_beongae", "t": "좋아! 한 가지만. 번쩍하면 엎드려. 생각은 그다음에."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_thunder_peak_1$q$, 2, $q$번쩍한 다음$q$, $q$응축 영핵과 요기 결정을 모은다$q$, $q${"tasks": [{"t": "gather", "items": ["spirit_core"], "r": ["thunder_peak"], "n": 3}, {"t": "gather", "items": ["spirit_dust"], "r": ["thunder_peak"], "n": 3}], "at": ["thunder_peak"], "give": {"spirit_core": 2}}$q$::jsonb, $q$[{"s": null, "t": "바위가 아직 뜨겁다. 갈라진 틈에서 푸른 빛 도는 영핵이 맺혀 있다."}, {"s": "q:rn_beongae", "t": "그거야, 그거! 하하, 잘 엎드리던데."}, {"s": "q:rn_beongae", "t": "근데 이상하지. 요즘 벼락이 떨어지는 자리가 늘 같아. 산 꼭대기 한 군데로만."}, {"s": "q:rn_beongae", "t": "누가 벼락을 부르는 것 같아. 붉은 옷 입은 사람들이 거기서 뭘 한다는 소리도 있고."}, {"s": "me", "t": "적월교가 뇌명봉에 왔습니까?"}, {"s": "q:rn_beongae", "t": "나는 벼락만 보지. 사람은 잘 안 봐."}]$q$::jsonb, $q${"xp": 1869, "gil": 69, "items": {"thunder_ore": 2, "moonlight_essence": 1}}$q$::jsonb),
  ($q$sq_thunder_peak_2$q$, 1, $q$꼭대기의 붉은 천$q$, $q$북령 척후를 만난다$q$, $q${"at": ["thunder_peak"]}$q$::jsonb, $q$[{"s": "q:rn_gangpa", "t": "……봉우리 꼭대기에 붉은 천이 걸렸소."}, {"s": "north_league:yeo", "t": "월식의 문이 열린 뒤로 적월교 잔당이 여기까지 올라왔어. 벼락으로 무언가를 달구는 중이야."}, {"s": "north_league:yeo", "t": "문을 연 것만으론 모자란가 봐. 다음 문을 열 쇠를 벼락에 담금질하는 거겠지."}, {"s": "q:rn_gangpa", "t": "산군이 그놈들 곁을 지키오. 벼락 맞고 미쳤소."}, {"s": "north_league:yeo", "t": "조사원, 길은 강파가 낸다. 넌 앞만 쳐."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_thunder_peak_2$q$, 2, $q$벼락길$q$, $q$벼락 지네와 뇌석 갑귀를 걷어 내며 오른다$q$, $q${"tasks": [{"t": "win", "m": ["x_thunder_peak_1"], "n": 3}, {"t": "win", "m": ["x_thunder_peak_2"], "n": 2}], "at": ["thunder_peak"]}$q$::jsonb, $q$[{"s": null, "t": "바위마다 벼락 자국이 같은 쪽을 가리킨다. 꼭대기의 붉은 천이 바람에 찢어질 듯 펄럭인다."}, {"s": "q:rn_gangpa", "t": "……다 왔소. 저 위요."}, {"s": null, "t": "천 아래에 쇠사슬로 묶인 붉은 열쇠 하나. 벼락이 떨어질 때마다 붉게 달아오른다."}, {"s": "me", "t": "사슬을 끊기 전에 지키는 것부터 치워야겠군요."}]$q$::jsonb, $q${"xp": 1138}$q$::jsonb),
  ($q$sq_thunder_peak_2$q$, 3, $q$식은 열쇠$q$, $q$뇌각 산군을 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_thunder"], "n": 1}], "at": ["thunder_peak"]}$q$::jsonb, $q$[{"s": null, "t": "뇌각 산군이 쓰러지자 벼락이 멎는다. 달아올랐던 열쇠가 천천히 검게 식는다."}, {"s": "q:rn_gangpa", "t": "……식었소."}, {"s": "north_league:yeo", "t": "담금질이 덜 끝났어. 이 열쇠로는 아무 문도 못 열 거야."}, {"s": "north_league:yeo", "t": "하지만 이게 하나뿐일까. 다음 문은 물 밑이라 했지. 물 밑엔 벼락이 안 닿으니, 다른 걸로 달구겠지."}, {"s": "me", "t": "그 전에 찾겠습니다."}, {"s": "q:rn_gangpa", "t": "……산 아래까지는 내가 데려다 주겠소."}]$q$::jsonb, $q${"xp": 1138, "gil": 77, "items": {"spirit_core": 1, "rejuv_pill": 1, "revival_charm": 1}}$q$::jsonb),
  ($q$sq_hidden_bazaar_1$q$, 1, $q$장부의 빈칸$q$, $q$십삼문 암시장에서 여섯째의 말을 듣는다$q$, $q${"at": ["hidden_bazaar"]}$q$::jsonb, $q$[{"s": null, "t": "등불 아래, 여섯째가 장부 한 장을 손가락으로 짚는다. 이름이 있어야 할 자리가 비어 있다."}, {"s": "black_lotus:six", "t": "사백십이 번. 석수장이. 이름을 맡기고 빚을 갚았다."}, {"s": "black_lotus:six", "t": "그런데 맡긴 이름보다 빚이 컸다. 남은 몫을 두고 달아났다."}, {"s": "me", "t": "어디로 갔는지 짐작은 있습니까?"}, {"s": "black_lotus:six", "t": "만인장. 돌 깎는 자는 돌 곁으로 간다. 찾아라. 데려오든 말든, 셈만 맞추면 된다."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_hidden_bazaar_1$q$, 2, $q$끌 자국$q$, $q$만인장에 가서 세 번 살핀다$q$, $q${"tasks": [{"t": "travel", "r": ["burial_steps"], "n": 1}, {"t": "search", "r": ["burial_steps"], "n": 3}], "at": ["burial_steps"]}$q$::jsonb, $q$[{"s": null, "t": "비석 사이로 새 끌 자국이 이어진다. 오래된 비석의 깨진 귀퉁이마다 누군가 정성껏 다듬어 둔 흔적이 있다."}, {"s": "me", "t": "달아난 사람이 남의 비석을 고쳐 주고 다녔다."}, {"s": null, "t": "자국은 묘역 안쪽, 까마귀가 모여 앉은 낮은 언덕으로 향한다."}, {"s": "me", "t": "저 언덕 너머에 무언가 있다. 새들이 길을 막고 있다."}]$q$::jsonb, $q${"xp": 440}$q$::jsonb),
  ($q$sq_hidden_bazaar_1$q$, 3, $q$까마귀가 지키던 비석$q$, $q$만인장 요괴를 물리치고 단서를 찾는다$q$, $q${"tasks": [{"t": "win", "r": ["burial_steps"], "n": 2}, {"t": "clue", "n": 1}], "at": ["burial_steps"]}$q$::jsonb, $q$[{"s": null, "t": "언덕 위에 갓 깎은 비석 하나가 서 있다. 그 아래, 돌가루를 뒤집어쓴 채 굳은 사내가 끌을 쥐고 엎드려 있다."}, {"s": null, "t": "비석에 새긴 이름은 사내의 것이 아니다. 어린 여자아이의 이름 석 자다."}, {"s": "me", "t": "제 이름은 팔았으니 새길 수가 없었겠지. 그래서 딸의 이름을 남겼나."}, {"s": null, "t": "비석 뒷면에 작은 글씨가 있다. 「이 아이의 빚은 아비가 다 졌다.」"}, {"s": "me", "t": "흑련회 장부를 다시 봐야겠다."}]$q$::jsonb, $q${"xp": 440, "items": {"seal_paper": 2}}$q$::jsonb),
  ($q$sq_hidden_bazaar_1$q$, 4, $q$셈이 맞는 날$q$, $q$십삼문 암시장의 여섯째에게 알린다$q$, $q${"at": ["hidden_bazaar"]}$q$::jsonb, $q$[{"s": "black_lotus:six", "t": "죽었나."}, {"s": "me", "t": "예. 딸의 비석을 깎다가. 그 아이의 빚도 자기가 졌다고 적어 두었습니다."}, {"s": null, "t": "여섯째가 장부를 넘긴다. 사백십삼 번. 같은 성을 쓴 아이의 이름 옆에 붉은 줄이 길게 그어져 있다."}, {"s": "black_lotus:six", "t": "아비 몫으로 넘긴다. 둘 다 지운다."}, {"s": "black_lotus:six", "t": "숫자 둘이 줄었다. 오늘은 그걸로 됐다."}]$q$::jsonb, $q${"gil": 45, "items": {"spirit_qi_pill": 1}}$q$::jsonb),
  ($q$sq_hidden_bazaar_2$q$, 1, $q$밤새 울리는 알$q$, $q$십삼문 암시장에서 구슬의 부탁을 듣는다$q$, $q${"at": ["hidden_bazaar"]}$q$::jsonb, $q$[{"s": null, "t": "새벽인데도 장부 방에서 주판알 소리가 끊이지 않는다. 구슬의 눈 밑이 검다."}, {"s": "black_lotus:guseul", "t": "앉으셔요. 나는 들어온 빚을 하나도 잊지 못해요. 그게 내 재주고, 그게 내 병이지요."}, {"s": "black_lotus:guseul", "t": "눈을 감으면 숫자가 줄을 서요. 열흘째 잠을 못 잤어요."}, {"s": "black_lotus:guseul", "t": "월광 정수를 지어 주셔요. 기억을 흐리게 한다는 약. 재료는 만인장의 요기 결정이 좋다더군요."}, {"s": "me", "t": "잊고 싶은 빚이 있습니까?"}, {"s": "black_lotus:guseul", "t": "하나 있지요. 값은 나중에 말해 줄게요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_hidden_bazaar_2$q$, 2, $q$묘역의 결정$q$, $q$만인장에서 요기 결정을 세 번 채집한다$q$, $q${"tasks": [{"t": "gather", "items": ["spirit_dust"], "r": ["burial_steps"], "n": 3}], "at": ["burial_steps"]}$q$::jsonb, $q$[{"s": null, "t": "무덤 틈에서 캐낸 요기 결정이 손바닥에서 희미하게 식는다. 죽은 이들이 남긴 마지막 기억이 굳은 것이라 한다."}, {"s": "me", "t": "남의 기억을 녹여 한 사람의 기억을 덮는 약이라."}, {"s": null, "t": "결정 하나가 깨지며 낯선 목소리가 귓가를 스친다. 누군가 누군가에게 돈을 돌려 달라고 빈다."}, {"s": "me", "t": "서두르자. 오래 쥐고 있을 물건은 아니다."}]$q$::jsonb, $q${"xp": 510}$q$::jsonb),
  ($q$sq_hidden_bazaar_2$q$, 3, $q$달빛 한 병$q$, $q$월광 정수를 두 번 지어 하나를 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["moonlight_essence"], "n": 2}], "at": ["hidden_bazaar"], "give": {"moonlight_essence": 1}}$q$::jsonb, $q$[{"s": "black_lotus:guseul", "t": "고와라. 달을 병에 담았네."}, {"s": null, "t": "구슬은 병을 마시지 않고 주판 옆에 세워 둔다."}, {"s": "black_lotus:guseul", "t": "잊고 싶은 빚이 뭐냐고 물었지요. 회주가 나한테 진 빚이에요. 이름 하나."}, {"s": "black_lotus:guseul", "t": "처음 왔을 때 그이는 나한테 자기 이름을 맡겼어요. 그러고는 그 이름을 판 데가 어딘지 끝내 말해 주지 않았지요."}, {"s": "black_lotus:guseul", "t": "안 마실래요. 잊을 수 있다는 걸 아는 것만으로 오늘은 잠이 올 것 같아요."}, {"s": null, "t": "그날 밤, 장부 방의 주판 소리가 처음으로 멎었다."}]$q$::jsonb, $q${"xp": 510, "gil": 49, "items": {"calm_brew": 1, "spirit_tea": 2}}$q$::jsonb),
  ($q$sq_burial_steps_1$q$, 1, $q$상엿소리$q$, $q$만인장에서 상여꾼 화강을 만난다$q$, $q${"at": ["burial_steps"]}$q$::jsonb, $q$[{"s": null, "t": "묘역 어귀에서 늙은 사내가 상엿소리를 흥얼거린다. 멀리서 그 가락을 따라 부르는 목소리가 수십이다."}, {"s": "q:bl_hwagang", "t": "저 소리가 들리오? 밤마다 백골들이 관을 메고 돈다오. 관은 비었소."}, {"s": "q:bl_hwagang", "t": "누구를 묻으려는지도 모르고 돌기만 하오. 서른 해를 봤지만 저리 오래 도는 행렬은 처음이오."}, {"s": "me", "t": "멈추게 하면 됩니까?"}, {"s": "q:bl_hwagang", "t": "앞줄부터 끊으시오. 행렬은 머리를 잃으면 흩어지는 법이오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_burial_steps_1$q$, 2, $q$행렬의 머리$q$, $q$만인행군을 두 번 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_22"], "n": 2}], "at": ["burial_steps"]}$q$::jsonb, $q$[{"s": null, "t": "앞줄이 무너지자 빈 관이 땅에 떨어진다. 관 뚜껑 안쪽에 손톱으로 긁은 글씨가 빼곡하다."}, {"s": "q:bl_hwagang", "t": "묘지기 영감 글씨요. 눈에 익소. 「나를 묻어 다오」."}, {"s": "me", "t": "묘지기가 산 채로 이걸 썼다는 말입니까?"}, {"s": "q:bl_hwagang", "t": "그 영감은 남을 다 묻고 정작 자기는 묻어 줄 사람이 없었소. 갑사들이 관 곁을 지키고 있을 거요."}]$q$::jsonb, $q${"xp": 340}$q$::jsonb),
  ($q$sq_burial_steps_1$q$, 3, $q$관 지키는 갑사$q$, $q$백골 갑사를 세 번 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_burial_steps_2"], "n": 3}], "at": ["burial_steps"]}$q$::jsonb, $q$[{"s": null, "t": "갑사들이 쓰러진 자리마다 낡은 삽이 하나씩 놓여 있다. 묘지기가 부리던 일꾼들의 것이다."}, {"s": "q:bl_hwagang", "t": "다 그 영감 밑에서 무덤을 판 사람들이오. 죽어서도 주인 곁에 있었구려."}, {"s": "me", "t": "그럼 행렬을 부른 것은 묘지기 자신이겠군요."}, {"s": "q:bl_hwagang", "t": "만장 사이 가장 깊은 곳에 있을 거요. 영감한테 이제 쉬라고 전해 주시오."}]$q$::jsonb, $q${"xp": 340}$q$::jsonb),
  ($q$sq_burial_steps_1$q$, 4, $q$묻어 줄 사람$q$, $q$만장 묘지기를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["burial_steps"], "rank": "guardian", "n": 1}], "at": ["burial_steps"]}$q$::jsonb, $q$[{"s": null, "t": "묘지기가 무너지자 그 몸이 가볍게 빈 관 안으로 눕는다. 처음부터 거기 들어갈 자리였던 것처럼."}, {"s": "q:bl_hwagang", "t": "내가 메겠소. 한 사람이면 충분하오."}, {"s": null, "t": "화강이 관을 지고 천천히 언덕을 오른다. 상엿소리를 따라 부르던 목소리들이 하나씩 끊긴다."}, {"s": "q:bl_hwagang", "t": "어허 넘자, 어허 넘자. 이번엔 진짜로 가는 길이오."}, {"s": null, "t": "그 밤, 만인장에는 처음으로 아무 소리도 나지 않았다."}]$q$::jsonb, $q${"xp": 340, "gil": 49, "items": {"revival_charm": 1}}$q$::jsonb),
  ($q$sq_burial_steps_2$q$, 1, $q$지워지는 이름$q$, $q$만인장에서 비석 닦는 아이를 만난다$q$, $q${"at": ["burial_steps"]}$q$::jsonb, $q$[{"s": null, "t": "작은 아이가 걸레로 비석을 문지르고 있다. 닦을수록 잿빛 가루가 다시 내려앉는다."}, {"s": "q:bl_yeonok", "t": "재가 앉으면 이름이 지워져요. 이름이 지워지면 여기 누운 사람도 잊혀요."}, {"s": "q:bl_yeonok", "t": "혼자서는 다 못 닦아요. 재를 좀 걷어 주실래요?"}, {"s": "me", "t": "부모님은 어디 계시니?"}, {"s": "q:bl_yeonok", "t": "몰라요. 그냥 여기서 늘 닦았어요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_burial_steps_2$q$, 2, $q$잿빛 걸레$q$, $q$만인장에서 원령재를 네 번 채집해 세 줌 건넨다$q$, $q${"tasks": [{"t": "gather", "items": ["ghost_ash"], "r": ["burial_steps"], "n": 4}], "at": ["burial_steps"], "give": {"ghost_ash": 3}}$q$::jsonb, $q$[{"s": "q:bl_yeonok", "t": "고마워요. 이 재는 모아서 멀리 버릴 거예요."}, {"s": null, "t": "걷어 낸 비석마다 이름이 드러난다. 그런데 아이는 그 이름들을 읽지 못한다. 글자를 배운 적이 없다고 한다."}, {"s": "q:bl_yeonok", "t": "까마귀들이 자꾸 와서 글자를 쪼아요. 그것도 좀 쫓아 주세요."}, {"s": "me", "t": "황지도 좀 구해 오마. 탁본을 떠 두면 지워져도 남는다."}]$q$::jsonb, $q${"xp": 440}$q$::jsonb),
  ($q$sq_burial_steps_2$q$, 3, $q$탁본 한 장$q$, $q$비석 까마귀를 쫓고 황지를 두 번 채집한다$q$, $q${"tasks": [{"t": "win", "m": ["g_burial_steps"], "n": 2}, {"t": "gather", "items": ["seal_paper"], "r": ["burial_steps"], "n": 2}], "at": ["burial_steps"]}$q$::jsonb, $q$[{"s": null, "t": "마지막 비석은 가장 작다. 탁본을 뜨자 종이 위에 두 글자가 떠오른다. 연옥."}, {"s": "q:bl_yeonok", "t": "뭐라고 써 있어요?"}, {"s": "me", "t": "네 이름이다."}, {"s": null, "t": "아이는 한참 탁본을 들여다보다가 걸레를 비석 위에 곱게 개어 둔다."}, {"s": "q:bl_yeonok", "t": "그럼 나는 이제 안 닦아도 되겠네요. 누가 기억해 주니까."}, {"s": null, "t": "돌아보았을 때 아이는 없었다. 비석은 깨끗했고, 재는 더 내려앉지 않았다."}]$q$::jsonb, $q${"xp": 440, "gil": 45, "items": {"ward_talisman": 2}}$q$::jsonb),
  ($q$sq_forgotten_city_1$q$, 1, $q$울리지 않은 종소리$q$, $q$무명 고도에서 사관 여휘를 만난다$q$, $q${"at": ["forgotten_city"]}$q$::jsonb, $q$[{"s": null, "t": "무너진 처마 아래, 사관 하나가 빈 책장을 넘기고 있다. 어느 장에도 글자가 없다."}, {"s": "q:bl_yeohwi", "t": "그대가 종을 따라 내려간 조사원이구려. 그 종이 이 성을 지나갔소."}, {"s": "q:bl_yeohwi", "t": "울리지는 않았소. 끌려가며 땅에 닿았을 뿐인데 그날 밤 성 사람들의 이름이 내 책에서 지워졌소."}, {"s": "me", "t": "지나간 자리를 보여 주시겠습니까?"}, {"s": "q:bl_yeohwi", "t": "보시오. 나는 더는 그 길을 걷지 못하겠소."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_forgotten_city_1$q$, 2, $q$깊게 패인 바닥$q$, $q$무명 고도를 세 번 살핀다$q$, $q${"tasks": [{"t": "search", "r": ["forgotten_city"], "n": 3}], "at": ["forgotten_city"]}$q$::jsonb, $q$[{"s": null, "t": "옛 큰길 한가운데로 깊은 홈이 나 있다. 무거운 쇠가 끌려간 자국이다. 홈 양쪽 돌에 작은 글씨가 박혀 있다."}, {"s": "me", "t": "이름들이다. 종이 지나가며 빨아들인 이름이 돌에 눌어붙었다."}, {"s": null, "t": "홈은 성의 결계관이 지키는 옛 관아로 이어진다."}, {"s": "me", "t": "결계관이 길을 막고 있다. 저 너머까지 읽어야 한다."}]$q$::jsonb, $q${"xp": 934}$q$::jsonb),
  ($q$sq_forgotten_city_1$q$, 3, $q$결계 너머의 명부$q$, $q$고도 결계관을 물리치고 단서 둘을 찾는다$q$, $q${"tasks": [{"t": "win", "m": ["x_forgotten_city_2"], "n": 2}, {"t": "clue", "n": 2}], "at": ["forgotten_city"]}$q$::jsonb, $q$[{"s": null, "t": "관아 마당의 홈은 갑자기 끊긴다. 그 끝 돌에는 가장 새 글씨가 깊게 새겨져 있다."}, {"s": null, "t": "이름은 없고 직함만 있다. 「야행국 본부 연화원 제조」."}, {"s": "me", "t": "본부 관리가 종이 지나간 뒤에 여기 왔다. 그리고 스스로 이름을 놓고 갔다."}, {"s": "me", "t": "누가 왜 그랬는지는 아직 모르겠다. 하지만 지워진 게 아니라 내려놓은 이름이다."}]$q$::jsonb, $q${"xp": 934, "items": {"talisman_thread": 2}}$q$::jsonb),
  ($q$sq_forgotten_city_1$q$, 4, $q$적지 못한 한 줄$q$, $q$무명 고도의 여휘에게 돌아간다$q$, $q${"at": ["forgotten_city"]}$q$::jsonb, $q$[{"s": "q:bl_yeohwi", "t": "연화원 제조라. 내 젊을 적에도 그런 직함은 장부에서 함부로 적지 않았소."}, {"s": "q:bl_yeohwi", "t": "이름을 빼앗긴 자는 울며 오고, 이름을 버린 자는 말없이 오지. 그자는 말없이 왔을 게요."}, {"s": null, "t": "여휘가 빈 책장 맨 끝에 직함만 적는다. 붓끝이 처음으로 떨리지 않는다."}, {"s": "q:bl_yeohwi", "t": "이 줄의 이름은 언젠가 그대가 채워 오시오. 등잔 밑을 잘 살피시고."}]$q$::jsonb, $q${"gil": 69, "items": {"spirit_qi_pill": 2}}$q$::jsonb),
  ($q$sq_forgotten_city_2$q$, 1, $q$조회를 알리는 북$q$, $q$무명 고도에서 늙은 내관을 만난다$q$, $q${"at": ["forgotten_city"]}$q$::jsonb, $q$[{"s": null, "t": "깊은 밤, 무너진 정전에서 조회를 알리는 북이 울린다. 굽은 내관이 계단 밑에서 고개를 조아린다."}, {"s": "q:bl_damu", "t": "폐하께서 오늘도 조회를 여시옵니다. 신하는 아무도 오지 않는데."}, {"s": "q:bl_damu", "t": "폐하는 당신 이름을 잊으셨사옵니다. 신하들에게 당신 이름을 묻고 또 물으시지요. 답할 자가 없사옵니다."}, {"s": "me", "t": "그대는 알지 않습니까?"}, {"s": "q:bl_damu", "t": "아뢰면 안 되옵니다. 내관은 어명 없이 옥명을 입에 올리지 못하옵니다. 그것이 법이었사옵니다."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_forgotten_city_2$q$, 2, $q$돌로 선 수문병$q$, $q$석상 수문병을 세 번 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["g_forgotten_city"], "n": 3}], "at": ["forgotten_city"]}$q$::jsonb, $q$[{"s": null, "t": "부서진 수문병 석상마다 받침돌에 직책이 새겨져 있다. 이름은 하나도 없다."}, {"s": "q:bl_damu", "t": "모두 폐하를 따라 이름을 바친 자들이옵니다. 망국의 마지막 날, 이름을 바치면 성이 지켜진다 믿었지요."}, {"s": "me", "t": "성은 지켜졌습니까?"}, {"s": "q:bl_damu", "t": "이렇게 남았사옵니다. 아무도 모르는 채로. 근위장이 정전 문을 지키고 있사옵니다."}]$q$::jsonb, $q${"xp": 623}$q$::jsonb),
  ($q$sq_forgotten_city_2$q$, 3, $q$정전의 문$q$, $q$망국 근위장을 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["forgotten_city"], "rank": "guardian", "n": 1}], "at": ["forgotten_city"]}$q$::jsonb, $q$[{"s": null, "t": "근위장이 무릎을 꿇자 정전 문이 저절로 열린다. 텅 빈 자리들 끝에 면류관을 쓴 그림자가 앉아 있다."}, {"s": "q:bl_damu", "t": "폐하께서 그대를 보시옵니다. 신하로 여기시는 듯하옵니다."}, {"s": "me", "t": "그럼 신하로서 끝을 아뢰겠습니다."}, {"s": "q:bl_damu", "t": "부디 아프시지 않게."}]$q$::jsonb, $q${"xp": 623}$q$::jsonb),
  ($q$sq_forgotten_city_2$q$, 4, $q$옥명$q$, $q$무명 황제를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_20"], "n": 1}], "at": ["forgotten_city"]}$q$::jsonb, $q$[{"s": null, "t": "황제의 그림자가 흐려지며 마지막으로 묻는다. 짐의 이름이 무엇이냐."}, {"s": null, "t": "담무가 엎드린 채 떨리는 목소리로 두 글자를 아뢴다. 어명 없이, 처음이자 마지막으로."}, {"s": null, "t": "그림자는 그 이름을 듣고 고개를 끄덕인 뒤 사라진다. 면류관만 바닥에 남는다."}, {"s": "q:bl_damu", "t": "법을 어겼사옵니다. 이제 신도 쉬어도 되겠지요."}, {"s": "me", "t": "그 이름, 저도 기억하겠습니다."}, {"s": "q:bl_damu", "t": "아니옵니다. 잊어 주시옵소서. 폐하는 들으셨으니 그로 족하옵니다."}]$q$::jsonb, $q${"xp": 623, "gil": 69, "items": {"spirit_core": 1}}$q$::jsonb),
  ($q$sq_under_root_1$q$, 1, $q$마른 갱$q$, $q$지맥의 뿌리에서 채굴 감독을 만난다$q$, $q${"at": ["under_root"]}$q$::jsonb, $q$[{"s": null, "t": "갱 벽을 뒤덮은 뿌리가 맥박처럼 꿈틀거린다. 감독 반석이 흙을 한 줌 쥐어 냄새를 맡는다."}, {"s": "q:bl_banseok", "t": "말랐소. 지난달만 해도 영핵이 포도송이처럼 달렸는데."}, {"s": "q:bl_banseok", "t": "뿌리가 마시고 있소. 지맥의 기운을 아래로, 더 아래로 끌어 내리고 있어."}, {"s": "me", "t": "아래라면 어디 말입니까?"}, {"s": "q:bl_banseok", "t": "그걸 알려면 남은 영핵부터 캐 봐야지. 영핵은 뿌리의 심장 소리를 기억하오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_under_root_1$q$, 2, $q$심장 소리$q$, $q$지맥의 뿌리에서 응축 영핵을 세 번 채집한다$q$, $q${"tasks": [{"t": "gather", "items": ["spirit_core"], "r": ["under_root"], "n": 3}], "at": ["under_root"]}$q$::jsonb, $q$[{"s": null, "t": "캐낸 영핵을 귀에 대면 낮은 울림이 들린다. 울림은 고르지 않고, 한참 멎었다가 크게 한 번 친다."}, {"s": "q:bl_banseok", "t": "숨이오. 무언가 아주 느리게 숨을 쉬고 있소. 뿌리는 그 숨을 따라 마시는 거고."}, {"s": "me", "t": "결정 쪽도 같은지 보겠습니다."}, {"s": "q:bl_banseok", "t": "지네들이 결정 맥을 갉아먹고 있소. 조심하시오."}]$q$::jsonb, $q${"xp": 1034}$q$::jsonb),
  ($q$sq_under_root_1$q$, 3, $q$아래로 향하는 맥$q$, $q$뿌리 지네를 물리치고 요기 결정을 세 번 채집해 영핵 둘을 건넨다$q$, $q${"tasks": [{"t": "win", "m": ["g_under_root"], "n": 2}, {"t": "gather", "items": ["spirit_dust"], "r": ["under_root"], "n": 3}], "at": ["under_root"], "give": {"spirit_core": 2}}$q$::jsonb, $q$[{"s": "q:bl_banseok", "t": "결정의 결이 모두 한쪽으로 누웠소. 남쪽 아래. 흑조 균열보다 더 깊은 쪽이오."}, {"s": "me", "t": "구중 봉연입니다."}, {"s": null, "t": "반석이 한동안 말이 없다가 영핵 둘을 등잔 옆에 내려놓는다."}, {"s": "q:bl_banseok", "t": "회주께서 이 갱을 왜 그리 아끼셨는지 이제 알겠소. 여기서 그곳의 숨을 들을 수 있으니까."}, {"s": "q:bl_banseok", "t": "캐는 건 계속하겠소. 뿌리가 마시는 걸 조금이라도 덜어 내야지. 그게 우리 몫이오."}]$q$::jsonb, $q${"xp": 1034, "gil": 73, "items": {"spirit_qi_pill": 2}}$q$::jsonb),
  ($q$sq_under_root_2$q$, 1, $q$물이 운다$q$, $q$지맥의 뿌리에서 수맥 지기 은결을 만난다$q$, $q${"at": ["under_root"]}$q$::jsonb, $q$[{"s": null, "t": "뿌리 사이로 흐르는 물이 이상하게 낮은 소리를 낸다. 쇠를 친 뒤 남는 여운 같은 소리다."}, {"s": "q:bl_eungyeol", "t": "종이 여기서 하룻밤 쉬어 갔어요. 끌고 가던 자들이 이 물가에 내려놓았지요."}, {"s": "q:bl_eungyeol", "t": "울리지도 않았는데 물이 그 소리를 배웠어요. 그 뒤로 수맥귀가 생겼고요."}, {"s": "me", "t": "물이 기억한 종소리라. 어떻게 하면 잊게 합니까?"}, {"s": "q:bl_eungyeol", "t": "정화 부적을 띄워 주세요. 물은 덮어 주면 조용해져요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_under_root_2$q$, 2, $q$물에 띄울 부적$q$, $q$정화 부적을 세 번 만든다$q$, $q${"tasks": [{"t": "craft", "items": ["ward_talisman"], "n": 3}], "at": ["under_root"]}$q$::jsonb, $q$[{"s": null, "t": "부적을 물에 띄우자 낮은 울림이 조금씩 가라앉는다. 그런데 물길 안쪽에서 무언가 거꾸로 거슬러 오른다."}, {"s": "q:bl_eungyeol", "t": "수맥귀예요. 종소리를 가장 많이 먹은 것들이요. 부적을 싫어해요."}, {"s": "me", "t": "먼저 그것들을 정리하겠습니다."}]$q$::jsonb, $q${"xp": 758}$q$::jsonb),
  ($q$sq_under_root_2$q$, 3, $q$거슬러 오르는 것$q$, $q$지하 수맥귀를 두 번 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_under_root_2"], "n": 2}], "at": ["under_root"]}$q$::jsonb, $q$[{"s": null, "t": "수맥귀가 흩어질 때마다 종소리가 한 번씩 울리고 사라진다. 소리마다 누군가의 이름이 섞여 있는 것만 같다."}, {"s": "q:bl_eungyeol", "t": "들었어요? 다들 이름을 부르며 가요. 종이 삼킨 이름들이요."}, {"s": "me", "t": "종이 머문 바로 그 자리를 덮어야겠군요."}, {"s": "q:bl_eungyeol", "t": "회생 부적 하나면 돼요. 그 자리에서 다시 숨 쉬지 못하게 묻어 주는 거예요."}]$q$::jsonb, $q${"xp": 758}$q$::jsonb),
  ($q$sq_under_root_2$q$, 4, $q$묻어 둔 숨$q$, $q$회생 부적을 만들어 은결에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["revival_charm"], "n": 1}], "at": ["under_root"], "give": {"revival_charm": 1}}$q$::jsonb, $q$[{"s": null, "t": "은결이 종이 놓였던 자리, 둥글게 패인 바위에 부적을 묻는다. 물소리가 그제야 물소리로 돌아온다."}, {"s": "q:bl_eungyeol", "t": "고마워요. 이제 물은 그냥 흘러요."}, {"s": "q:bl_eungyeol", "t": "하지만 종은 아직 저 아래에 있지요. 물이 배운 소리가 이 정도였다면, 종 곁에 있는 것들은 무엇을 배웠을까요."}, {"s": "me", "t": "그건 내려가 보면 알겠지요."}]$q$::jsonb, $q${"xp": 758, "gil": 77, "items": {"purify_water": 2}}$q$::jsonb),
  ($q$sq_black_tide_rift_1$q$, 1, $q$놓아주는 낚시$q$, $q$흑조 균열에서 늙은 낚시꾼을 만난다$q$, $q${"at": ["black_tide_rift"]}$q$::jsonb, $q$[{"s": null, "t": "검은 물이 거꾸로 흐르는 균열 끝에 늙은이가 앉아 있다. 낚아 올린 먹장어를 한참 들여다보다가 다시 놓아준다."}, {"s": "q:bl_eodu", "t": "내 아들 녀석이 남쪽 등대지기였소. 등대가 꺼지던 해에 바다로 쓸려 들어갔지."}, {"s": "q:bl_eodu", "t": "남쪽 바다에 빠진 건 결국 다 이리로 흘러온다오. 그래서 여기서 기다리는 거요."}, {"s": "me", "t": "무엇을 찾고 계십니까?"}, {"s": "q:bl_eodu", "t": "낚싯대. 녀석이 늘 허리에 차던 은가락지가 달린 놈이오. 손이 떨려서 이제 혼자 줄을 못 당기겠소."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_black_tide_rift_1$q$, 2, $q$첫 입질$q$, $q$흑조 균열에서 세 번 낚아 올린다$q$, $q${"tasks": [{"t": "fish", "r": ["black_tide_rift"], "n": 3}], "at": ["black_tide_rift"]}$q$::jsonb, $q$[{"s": null, "t": "올라온 것은 눈 없는 물고기와 녹슨 등잔 조각, 그리고 끊어진 낚싯줄 한 토막이다."}, {"s": "q:bl_eodu", "t": "이 매듭. 우리 집안 매듭이오. 녀석이 맨 거요."}, {"s": "me", "t": "가까이 있다는 뜻이군요."}, {"s": "q:bl_eodu", "t": "그런데 촉수 놈들이 자꾸 줄을 감아 가오. 녀석 것을 뺏으려는 것처럼."}]$q$::jsonb, $q${"xp": 1478}$q$::jsonb),
  ($q$sq_black_tide_rift_1$q$, 3, $q$줄을 감는 물결$q$, $q$검은 물결 촉수를 물리치고 두 번 더 낚는다$q$, $q${"tasks": [{"t": "win", "m": ["g_black_tide_rift"], "n": 2}, {"t": "fish", "r": ["black_tide_rift"], "n": 2}], "at": ["black_tide_rift"]}$q$::jsonb, $q$[{"s": null, "t": "마지막으로 당긴 줄이 유난히 무겁다. 끝에 걸려 나온 것은 부러진 낚싯대, 손잡이에 은가락지 하나가 감겨 있다."}, {"s": "q:bl_eodu", "t": "이놈이오."}, {"s": null, "t": "늙은이는 낚싯대를 품에 안고 오래 아무 말도 하지 않는다."}, {"s": "q:bl_eodu", "t": "녀석이 끝까지 쥐고 있었구려. 등불을 지키다 간 놈이니 낚싯대쯤이야 놓을 리가 없지."}]$q$::jsonb, $q${"xp": 1478}$q$::jsonb),
  ($q$sq_black_tide_rift_1$q$, 4, $q$다시 드리운 줄$q$, $q$흑조 균열의 어두에게 인사한다$q$, $q${"at": ["black_tide_rift"]}$q$::jsonb, $q$[{"s": "me", "t": "이제 돌아가시겠습니까?"}, {"s": "q:bl_eodu", "t": "아니오. 이걸로 낚을 거요. 녀석 대 대신에."}, {"s": null, "t": "늙은이가 부러진 대에 새 줄을 매어 검은 물에 드리운다. 물살이 그 줄 근처에서만 잠잠해진다."}, {"s": "q:bl_eodu", "t": "이 물엔 아직 못 돌아간 놈들이 많소. 내가 하나씩 건져서 놓아주리다. 녀석이 했을 일이니."}]$q$::jsonb, $q${"gil": 89, "items": {"fish_oil_lamp": 1, "fish_porridge": 2}}$q$::jsonb),
  ($q$sq_black_tide_rift_2$q$, 1, $q$혼자 돌아온 선장$q$, $q$흑조 균열에서 밀수선 선장을 만난다$q$, $q${"at": ["black_tide_rift"]}$q$::jsonb, $q$[{"s": null, "t": "부서진 뱃머리 조각에 걸터앉은 여인이 검은 물을 노려본다. 젖은 옷소매에서 흑련 문양이 비친다."}, {"s": "q:bl_chaeun", "t": "배가 거꾸로 뒤집혔어. 물이 위로 흐르더니 우리를 통째로 삼켰지."}, {"s": "q:bl_chaeun", "t": "나만 뱉어 냈어. 선원 열둘은 아직 저 안에서 떠돌아. 거꾸로, 머리를 밑으로 한 채로."}, {"s": "me", "t": "건져 낼 방법이 있습니까?"}, {"s": "q:bl_chaeun", "t": "없어. 그러니까 끝내 줘. 선장이 할 일을 대신해 줘."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_black_tide_rift_2$q$, 2, $q$갑판을 기는 것$q$, $q$검은 게 떼를 세 번 물리친다$q$, $q${"tasks": [{"t": "win", "m": ["x_black_tide_rift_1"], "n": 3}], "at": ["black_tide_rift"]}$q$::jsonb, $q$[{"s": null, "t": "게 떼가 흩어진 자리에 배의 짐짝들이 떠 있다. 흑련회 인장이 찍힌 상자 속은 텅 비어 있다."}, {"s": "q:bl_chaeun", "t": "물건은 상관없어. 장부지기한테는 내가 빚을 지면 그만이야."}, {"s": "q:bl_chaeun", "t": "저기, 물 위로 발이 보이지. 우리 애들이야."}]$q$::jsonb, $q${"xp": 1068}$q$::jsonb),
  ($q$sq_black_tide_rift_2$q$, 3, $q$선원 명부$q$, $q$역천 표류체를 두 번 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_rift"], "n": 2}], "at": ["black_tide_rift"]}$q$::jsonb, $q$[{"s": null, "t": "표류체가 무너질 때마다 채운이 낮게 이름을 부른다. 돌쇠, 막동, 끝순이."}, {"s": "q:bl_chaeun", "t": "선원 명부는 배와 함께 잠겼어. 그래도 이름은 내 머릿속에 다 있어. 흑련회 사람이 이름을 외우는 건 웃기지?"}, {"s": "me", "t": "전혀요."}, {"s": "q:bl_chaeun", "t": "아직 셋 남았는데, 그 셋을 쥐고 있는 놈이 있어. 균열 한가운데. 배를 삼킨 그놈."}]$q$::jsonb, $q${"xp": 1068}$q$::jsonb),
  ($q$sq_black_tide_rift_2$q$, 4, $q$균열을 삼킨 자$q$, $q$균열을 삼킨 자를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["black_tide_rift"], "rank": "guardian", "n": 1}], "at": ["black_tide_rift"]}$q$::jsonb, $q$[{"s": null, "t": "거대한 것이 가라앉자 검은 물이 잠시 바로 흐른다. 마지막 세 그림자가 똑바로 서서 선장을 향해 고개를 숙이고 흩어진다."}, {"s": "q:bl_chaeun", "t": "열둘. 다 셌다."}, {"s": "q:bl_chaeun", "t": "흑련회는 빚을 받으러 오겠지. 배 한 척, 짐 한 배. 갚을게. 이번엔 아깝지 않아."}, {"s": null, "t": "선장은 뱃머리 조각을 물에 띄워 보낸다. 조각은 거꾸로 흐르는 물을 거슬러 천천히 멀어진다."}]$q$::jsonb, $q${"xp": 1068, "gil": 93, "items": {"spirit_core": 1, "revival_charm": 1}}$q$::jsonb),
  ($q$sq_white_tower_1$q$, 1, $q$졸린 관측관$q$, $q$백옥 천문탑에서 서이연을 만난다$q$, $q${"at": ["white_tower"]}$q$::jsonb, $q$[{"s": null, "t": "탑 계단참에서 서이연이 하품을 삼키며 별자리 판을 넘긴다."}, {"s": "mandate_court:seo", "t": "아, 왔네요. 부탁이 있어요. 별모래 좀 모아 줘요. 탑 난간에 쌓이는 성진사요."}, {"s": "mandate_court:seo", "t": "하늘의 별이 하나 떨어지면 그만큼 모래가 쌓여요. 그걸로 별 수를 세는 거죠."}, {"s": "mandate_court:seo", "t": "요즘 셈이 안 맞아요. 하나가 모자라. 내가 졸아서 잘못 센 거면 좋겠는데."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_white_tower_1$q$, 2, $q$난간의 모래$q$, $q$백옥 천문탑에서 성진사를 세 번 채집한다$q$, $q${"tasks": [{"t": "gather", "items": ["star_sand"], "r": ["white_tower"], "n": 3}], "at": ["white_tower"]}$q$::jsonb, $q$[{"s": null, "t": "손끝에 닿은 성진사가 차갑게 빛난다. 모래 알갱이마다 아주 작은 별자리가 비친다."}, {"s": "mandate_court:seo", "t": "역시 하나가 비어요. 북쪽 하늘, 원래는 빛이 약한 별 자리."}, {"s": "mandate_court:seo", "t": "떨어진 별은 거울에 비쳐 보면 어디로 갔는지 알 수 있어요. 거울 조각도 부탁해요. 나비들이 좀 성가실 거예요."}]$q$::jsonb, $q${"xp": 1360}$q$::jsonb),
  ($q$sq_white_tower_1$q$, 3, $q$거울에 비친 낙하$q$, $q$별빛 나비 떼를 쫓고 거울 조각을 두 번 채집해 성진사 둘을 건넨다$q$, $q${"tasks": [{"t": "win", "m": ["g_white_tower"], "n": 2}, {"t": "gather", "items": ["mirror_shard"], "r": ["white_tower"], "n": 2}], "at": ["white_tower"], "give": {"star_sand": 2}}$q$::jsonb, $q$[{"s": null, "t": "서이연이 거울 조각 위에 성진사를 뿌린다. 모래가 미끄러져 한쪽으로 모인다. 아래쪽으로."}, {"s": "mandate_court:seo", "t": "하늘로 안 갔네요. 땅속으로 떨어졌어. 아주 깊이."}, {"s": "me", "t": "별이 땅속으로 떨어지기도 합니까?"}, {"s": "mandate_court:seo", "t": "끌려가면요. 아래에서 무언가 별을 하나씩 세고 있다면, 그렇겠죠."}, {"s": "mandate_court:seo", "t": "태사령께는 아직 말하지 마요. 내가 졸아서 잘못 본 걸로 해 둘래요. 조금만 더."}]$q$::jsonb, $q${"xp": 1360, "gil": 85, "items": {"heavenly_dew": 1}}$q$::jsonb),
  ($q$sq_white_tower_2$q$, 1, $q$끝나지 않은 당번$q$, $q$백옥 천문탑에서 늙은 관측생을 만난다$q$, $q${"at": ["white_tower"]}$q$::jsonb, $q$[{"s": null, "t": "탑 맨 아래층, 먼지 쌓인 책상에 노인이 앉아 있다. 눈꺼풀이 없는 것처럼 눈을 감지 않는다."}, {"s": "q:bl_galhyeon", "t": "마흔 해 전에 당번을 섰소. 교대할 사람이 오지 않았지. 그래서 아직도 서 있소."}, {"s": "q:bl_galhyeon", "t": "눈을 감으면 그 사이에 무슨 별이 떨어질지 몰라서 감을 수가 없소."}, {"s": "q:bl_galhyeon", "t": "천령 감로를 한 잔 얻을 수 있겠소? 한 번만 깊이 자고 싶소."}, {"s": "me", "t": "지어 오겠습니다."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_white_tower_2$q$, 2, $q$영기를 졸이다$q$, $q$응축 영핵을 한 번 만든다$q$, $q${"tasks": [{"t": "craft", "items": ["spirit_core"], "n": 1}], "at": ["white_tower"]}$q$::jsonb, $q$[{"s": null, "t": "노인이 영핵을 받아 들고 불빛에 비춰 본다. 손가락이 오래된 붓 자국으로 검다."}, {"s": "q:bl_galhyeon", "t": "좋은 결이오. 감로의 바탕으로 충분하오."}, {"s": "q:bl_galhyeon", "t": "그대가 오기 전까지 나는 내가 깨어 있는 줄도 몰랐소. 눈 뜬 꿈이었는지도."}, {"s": "me", "t": "이제 한 번만 더 지으면 됩니다."}]$q$::jsonb, $q${"xp": 1478}$q$::jsonb),
  ($q$sq_white_tower_2$q$, 3, $q$감로 한 잔$q$, $q$천령 감로를 지어 갈현에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["heavenly_dew"], "n": 1}], "at": ["white_tower"], "give": {"heavenly_dew": 1}}$q$::jsonb, $q$[{"s": null, "t": "노인이 감로를 천천히 마신다. 그리고 마흔 해 쓴 관측 일지를 덮어 이쪽으로 민다."}, {"s": "q:bl_galhyeon", "t": "교대요. 그대가 받아 주시오. 마지막 장은 아직 비어 있소."}, {"s": null, "t": "노인의 눈이 마침내 감긴다. 숨소리가 길고 고르다. 다시 뜨이지 않는다."}, {"s": null, "t": "일지 맨 끝 장에는 떨리는 글씨로 한 줄이 적혀 있다. 「별 하나가 아래로 내려갔다. 누가 셈을 시작했다.」"}, {"s": "me", "t": "당번은 제가 서겠습니다. 편히 주무십시오."}]$q$::jsonb, $q${"xp": 1478, "gil": 89, "items": {"spirit_qi_pill": 2, "star_sand": 2}}$q$::jsonb),
  ($q$sq_star_observatory_1$q$, 1, $q$웃지 않는 사관$q$, $q$무극 관성대에서 문서진을 만난다$q$, $q${"at": ["star_observatory"]}$q$::jsonb, $q$[{"s": null, "t": "관성대 서고 앞에서 문서진이 문을 반쯤 막고 서 있다."}, {"s": "mandate_court:mun", "t": "연화원 일을 캐고 있다지요. 천명원에도 그 일의 기록이 있습니다."}, {"s": "mandate_court:mun", "t": "백옥 천문탑 지하에 옛 성도가 있습니다. 별빛으로는 읽히지 않고, 짐승 기름 불로만 글자가 떠오르게 써 두었지요."}, {"s": "mandate_court:mun", "t": "어유 등잔 두 개를 만들어 오십시오. 그 뒤의 일은 보고 판단하겠습니다."}, {"s": "me", "t": "왜 감춰 두었습니까?"}, {"s": "mandate_court:mun", "t": "그것도 보고 판단하십시오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_star_observatory_1$q$, 2, $q$어유 등잔$q$, $q$어유 등잔을 두 번 만들어 문서진에게 건넨다$q$, $q${"tasks": [{"t": "craft", "items": ["fish_oil_lamp"], "n": 2}], "at": ["star_observatory"], "give": {"fish_oil_lamp": 2}}$q$::jsonb, $q$[{"s": "mandate_court:mun", "t": "하나는 제가 가지고, 하나는 탑 지하에 두십시오. 두 불이 같은 글을 비추면 거짓이 아닙니다."}, {"s": "mandate_court:mun", "t": "성도 앞에서는 오래 살피십시오. 글자는 불빛이 흔들릴 때만 보입니다."}, {"s": "me", "t": "흔들리는 불빛으로만 읽히는 기록이라. 쓴 사람도 확신이 없었던 모양이군요."}]$q$::jsonb, $q${"xp": 2290}$q$::jsonb),
  ($q$sq_star_observatory_1$q$, 3, $q$흔들리는 성도$q$, $q$백옥 천문탑을 세 번 살피고 단서를 찾는다$q$, $q${"tasks": [{"t": "search", "r": ["white_tower"], "n": 3}, {"t": "clue", "n": 1}], "at": ["white_tower"]}$q$::jsonb, $q$[{"s": null, "t": "등잔불이 흔들리자 성도 귀퉁이에 작은 글씨가 떠오른다. 마흔 해도 더 된 날짜와 태사령의 수결."}, {"s": null, "t": "「연화원 제조가 별을 물어 왔다. 이름을 버리면 문을 닫을 수 있느냐고. 답하지 않았다.」"}, {"s": "me", "t": "천명원은 그 사람이 무엇을 하려는지 알고 있었다."}, {"s": null, "t": "그 아래 한 줄이 더 있다. 「답하지 않은 것이 답이 되었다.」"}]$q$::jsonb, $q${"xp": 2290}$q$::jsonb),
  ($q$sq_star_observatory_1$q$, 4, $q$입 밖에 내지 않은 예언$q$, $q$무극 관성대로 돌아가 보고한다$q$, $q${"at": ["star_observatory"]}$q$::jsonb, $q$[{"s": "mandate_court:mun", "t": "보셨군요. 그럼 판단하셨겠지요."}, {"s": null, "t": "서고 안쪽에서 하후정이 지팡이를 짚고 나온다. 한참을 말없이 서 있다."}, {"s": "mandate_court:hahu", "t": "막았으면 문은 열렸을 것이오. 말했으면 그는 멈췄을 것이오. 둘 다 별에 적혀 있었소."}, {"s": "mandate_court:hahu", "t": "나는 고르지 않았소. 그게 천명원의 죄요. 기록에 그리 적으시오."}, {"s": "mandate_court:mun", "t": "적겠습니다. 처음으로 감추지 않는 기록입니다."}]$q$::jsonb, $q${"gil": 113, "items": {"heavenly_dew": 1, "spirit_core": 1}}$q$::jsonb),
  ($q$sq_star_observatory_2$q$, 1, $q$꼭대기의 불빛$q$, $q$무극 관성대에서 수직 운해를 만난다$q$, $q${"at": ["star_observatory"]}$q$::jsonb, $q$[{"s": null, "t": "관성대에서 보면 백옥 천문탑 꼭대기에 희미한 불빛 하나가 밤마다 켜졌다 꺼진다."}, {"s": "q:bl_unhae", "t": "선대 태사령이십니다. 종말을 보시고 탑에서 내려오지 않으셨다지요. 그게 백 년 전입니다."}, {"s": "q:bl_unhae", "t": "그분 곁의 거울귀와 식자들이 탑을 오르는 사람을 막습니다. 저희는 감히 오르지 못했습니다."}, {"s": "q:bl_unhae", "t": "그분이 보신 것을 듣고 와 주십시오. 지금 태사령께서는 아무 말씀도 하지 않으시니까요."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_star_observatory_2$q$, 2, $q$거울 계단$q$, $q$천문 거울귀를 세 번 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_white_tower_2"], "n": 3}], "at": ["white_tower"]}$q$::jsonb, $q$[{"s": null, "t": "깨진 거울마다 같은 밤하늘이 비친다. 별의 자리가 지금과 조금씩 다르다. 백 년 뒤의 하늘이다."}, {"s": "me", "t": "미래를 비추는 거울이었나. 아니면 미래만 비추게 된 거울인가."}, {"s": null, "t": "위층에서 붓으로 종이를 긁는 소리가 들린다. 수없이, 끊임없이."}]$q$::jsonb, $q${"xp": 1333}$q$::jsonb),
  ($q$sq_star_observatory_2$q$, 3, $q$셈하는 식자들$q$, $q$천문식자를 두 번 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["m_27"], "n": 2}], "at": ["white_tower"]}$q$::jsonb, $q$[{"s": null, "t": "식자들이 흩어진 자리에 셈판이 쌓여 있다. 모두 같은 셈이다. 별 하나를 빼고, 또 하나를 빼고."}, {"s": "me", "t": "줄어드는 별을 세고 있었다. 무엇이 다 셀 때까지."}, {"s": null, "t": "꼭대기 문 너머에서 늙은 목소리가 들린다. 올라오너라. 거기까지 왔으면 들을 자격이 있다."}]$q$::jsonb, $q${"xp": 1333}$q$::jsonb),
  ($q$sq_star_observatory_2$q$, 4, $q$별이 다 차면$q$, $q$탑 꼭대기 원령을 쓰러뜨리고 관성대에 알린다$q$, $q${"tasks": [{"t": "win", "r": ["white_tower"], "rank": "guardian", "n": 1}], "at": ["star_observatory"]}$q$::jsonb, $q$[{"s": null, "t": "원령이 무너지기 전 마지막으로 입을 연다. 「아홉째 문 뒤에서 잠든 것은 별을 센다. 별이 한 바퀴 돌 때마다 눈을 뜨려 한다.」"}, {"s": null, "t": "「문을 닫아도 셈은 멈추지 않는다. 늦출 뿐이다.」 그리고 불빛이 꺼진다."}, {"s": "q:bl_unhae", "t": "그 말씀을 하시려고 백 년을 계셨군요."}, {"s": "q:bl_unhae", "t": "태사령께서 이걸 아시면서도 입 밖에 내지 않으셨다면, 저는 적어 두겠습니다. 누군가는 날짜를 세어야 하니까요."}]$q$::jsonb, $q${"xp": 1333, "gil": 105, "items": {"heavenly_dew": 1, "revival_charm": 1}}$q$::jsonb),
  ($q$sq_sealed_abyss_1$q$, 1, $q$닫힌 문 앞의 파수$q$, $q$구중 봉연에서 파수꾼 윤재음을 만난다$q$, $q${"at": ["sealed_abyss"]}$q$::jsonb, $q$[{"s": null, "t": "마지막 문은 닫혔다. 그런데 문 너머에서 쇠사슬이 끊기는 소리가 들린다. 한 번, 그리고 오래 쉬었다가 또 한 번."}, {"s": "q:bl_jaeum", "t": "문은 잘 닫혔습니다. 붉은 인장도 제자리에 있습니다. 그건 분명합니다."}, {"s": "q:bl_jaeum", "t": "다만 사슬이 끊깁니다. 안에서 누가 끊는 게 아니라, 밖으로 새어 나온 것들이 끊습니다."}, {"s": "night_office:han", "t": "규정상 봉연은 닫힌 곳입니다. 닫힌 곳에서 소리가 나면 보고해야 하지요. 그래서 그대를 불렀습니다."}, {"s": "q:bl_jaeum", "t": "먼저 사슬을 갉는 것들부터 걷어 주십시오."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_sealed_abyss_1$q$, 2, $q$사슬을 갉는 것들$q$, $q$심연 사슬귀를 네 번 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["g_sealed_abyss"], "n": 4}], "at": ["sealed_abyss"]}$q$::jsonb, $q$[{"s": null, "t": "사슬귀가 흩어진 자리에서 끊긴 사슬 고리가 천천히 다시 이어진다. 봉인이 스스로 아무는 것이다."}, {"s": "q:bl_jaeum", "t": "보십시오. 봉인은 살아 있습니다. 끊으면 다시 감깁니다."}, {"s": "me", "t": "그럼 무엇이 문제입니까?"}, {"s": "q:bl_jaeum", "t": "다시 감기는 데 걸리는 시간이 매번 조금씩 깁니다. 거울귀들이 그 틈을 비추고 있습니다."}]$q$::jsonb, $q${"xp": 1840}$q$::jsonb),
  ($q$sq_sealed_abyss_1$q$, 3, $q$틈을 비추는 거울$q$, $q$봉연 거울귀를 두 번 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "m": ["x_sealed_abyss_2"], "n": 2}], "at": ["sealed_abyss"]}$q$::jsonb, $q$[{"s": null, "t": "깨진 거울 조각 하나에 문 너머가 언뜻 비친다. 아홉 겹 사슬에 감긴 거대한 형체가 숨을 들이쉬고 있다."}, {"s": null, "t": "형체의 가슴께에 새겨진 글자가 거울 속에서 거꾸로 읽힌다. 구중 봉주."}, {"s": "q:bl_jaeum", "t": "봤습니까. 저것은 잠들어 있습니다. 아주 깊이. 그런데 꿈을 꿉니다."}, {"s": "night_office:han", "t": "꿈을 꾸는 봉인물. 보고서에 쓸 말이 아니군요. 그래도 쓰겠습니다."}]$q$::jsonb, $q${"xp": 1840}$q$::jsonb),
  ($q$sq_sealed_abyss_1$q$, 4, $q$끊는 자의 수$q$, $q$사슬 끊는 자를 쓰러뜨린다$q$, $q${"tasks": [{"t": "win", "r": ["sealed_abyss"], "rank": "guardian", "n": 1}], "at": ["sealed_abyss"]}$q$::jsonb, $q$[{"s": null, "t": "사슬 끊는 자가 무너지며 웃는다. 그 웃음이 문 너머 숨소리와 꼭 맞는 박자다."}, {"s": "q:bl_jaeum", "t": "저것도 저 안의 숨이 밖으로 새어 나온 한 조각이었습니다. 쓰러뜨려도 다음 숨에 또 생겨납니다."}, {"s": "night_office:han", "t": "간격을 세십시오. 언제 숨을 쉬는지 알아야 언제 막을지 압니다."}, {"s": "q:bl_jaeum", "t": "세고 있습니다. 문이 닫힌 날부터 하루도 빼지 않고. 숨과 숨 사이가 점점 짧아집니다."}, {"s": null, "t": "문 너머에서 사슬이 다시 감기는 소리가 들린다. 이번에는 조금 더 늦게."}]$q$::jsonb, $q${"xp": 1840, "gil": 125, "items": {"heavenly_dew": 1, "revival_charm": 2}}$q$::jsonb),
  ($q$sq_sealed_abyss_2$q$, 1, $q$졸음이 달아난 관측관$q$, $q$무극 관성대에서 서이연을 만난다$q$, $q${"at": ["star_observatory"]}$q$::jsonb, $q$[{"s": null, "t": "서이연이 드물게 눈을 크게 뜨고 있다. 책상 위에 별자리 판과 봉연 지도가 겹쳐 펼쳐져 있다."}, {"s": "mandate_court:seo", "t": "문은 닫혔죠. 다들 끝났다고 해요. 그런데 별이 계속 빠져요. 아래로."}, {"s": "mandate_court:seo", "t": "봉연에서 캔 응축 영핵은 그 아래 것의 숨을 품고 있을 거예요. 몇 개만 가져와 줘요."}, {"s": "mandate_court:seo", "t": "숨 간격을 재면 별 빠지는 날짜를 맞출 수 있어요. 맞추고 싶지 않지만."}]$q$::jsonb, $q${}$q$::jsonb),
  ($q$sq_sealed_abyss_2$q$, 2, $q$따뜻한 영핵$q$, $q$구중 봉연에서 응축 영핵을 세 번 채집한다$q$, $q${"tasks": [{"t": "gather", "items": ["spirit_core"], "r": ["sealed_abyss"], "n": 3}], "at": ["sealed_abyss"]}$q$::jsonb, $q$[{"s": null, "t": "봉연의 영핵은 다른 곳의 것과 달리 따뜻하다. 손에 쥐고 있으면 아주 느린 맥박이 전해진다."}, {"s": "me", "t": "살아 있는 것의 체온 같다."}, {"s": null, "t": "맥박은 길게 멎었다가 한 번 크게 뛴다. 그 순간 발밑의 사슬들이 일제히 울린다."}, {"s": "me", "t": "주변도 살펴 두자. 숨이 닿는 범위를 알아야 한다."}]$q$::jsonb, $q${"xp": 1840}$q$::jsonb),
  ($q$sq_sealed_abyss_2$q$, 3, $q$숨이 닿는 곳$q$, $q$구중 봉연을 두 번 살피고 요기 결정을 세 번 채집한다$q$, $q${"tasks": [{"t": "search", "r": ["sealed_abyss"], "n": 2}, {"t": "gather", "items": ["spirit_dust"], "r": ["sealed_abyss"], "n": 3}], "at": ["sealed_abyss"]}$q$::jsonb, $q$[{"s": null, "t": "요기 결정이 모두 문 쪽을 향해 자라 있다. 바깥 길목의 결정까지 그렇다. 숨이 닿는 범위가 생각보다 넓다."}, {"s": null, "t": "닫힌 문 아래 틈으로 한 줄기 바람이 불어 나온다. 바람에 섞인 낮은 목소리가 무언가를 센다. 아홉, 여덟, 일곱."}, {"s": "me", "t": "세고 있다. 거꾸로."}]$q$::jsonb, $q${"xp": 1840}$q$::jsonb),
  ($q$sq_sealed_abyss_2$q$, 4, $q$맞추고 싶지 않은 날짜$q$, $q$응축 영핵 둘을 무극 관성대의 서이연에게 건넨다$q$, $q${"at": ["star_observatory"], "give": {"spirit_core": 2}}$q$::jsonb, $q$[{"s": null, "t": "서이연이 영핵 둘을 별자리 판 위에 올려 둔다. 맥박이 뛸 때마다 판 위의 별 하나가 깜빡인다."}, {"s": "mandate_court:seo", "t": "숨 한 번에 별 하나. 별이 한 바퀴 돌면 깨어나려 하고, 문이 그걸 눌러요. 그리고 다시 셈을 시작하고."}, {"s": "mandate_court:seo", "t": "끝난 게 아니었어요. 되풀이되는 거예요. 밀물처럼."}, {"s": "me", "t": "다음 숨은 언제입니까?"}, {"s": "mandate_court:seo", "t": "곧이요. 오늘부터는 안 졸 거예요. 태사령께도 말씀드릴게요. 이번엔 입 밖에 내셔야 하니까."}]$q$::jsonb, $q${"xp": 1840, "gil": 125, "items": {"heavenly_dew": 1, "star_sand": 2}}$q$::jsonb);

-- 이미 진행한 조사원: 마친 장은 주 이야기 퀘스트도 마침, 지금 장에서 단서를 하나라도 찾았으면 장면을 건너뛴 것으로 한다(단서 찾기가 막히지 않게)
insert into public.world_quest_progress(owner_id, quest_id, step, done_at)
select c.owner_id, q.quest_id, (select count(*) from public.world_quest_steps s where s.quest_id = q.quest_id),
       case when public.world_quest_chapter_done(c.owner_id, q.chapter_id) then now() end
  from public.world_characters c cross join public.world_quests q
 where q.kind = 'main'
   and (public.world_quest_chapter_done(c.owner_id, q.chapter_id)
        or exists (select 1 from public.world_case_progress p where p.owner_id = c.owner_id and p.case_id = q.chapter_id and jsonb_array_length(coalesce(p.clues, '[]'::jsonb)) > 0))
on conflict (owner_id, quest_id) do nothing;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261030000000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

-- 패치노트 6.0.0
insert into public.world_patch_notes(note_id, title, body, created_at) values
  ('6.0.0', '퀘스트 · 주 이야기 장면 · 밸런스 개편', $PN$## 6.0.0 · 퀘스트 · 주 이야기 장면 · 밸런스 개편 (통산 6번째 패치)

### 퀘스트
- **퀘스트 94개**가 생겼습니다. 주 이야기 10장과 지역마다 보조 퀘스트 84개(「전투」「채집·약초」「제작·단조」「낚시」처럼 분류가 앞에 붙음).
- 현장 화면에 **퀘스트 칸**이 생겼습니다(접기 가능). 진행 중인 퀘스트의 할 일·넘길 물품·보고할 곳, 지금 있는 곳에서 받을 수 있는 퀘스트, 세력 퀘스트가 함께 보입니다. 할 일을 다 하면 알려 주고, 보고하면 대화창으로 이야기가 이어집니다.
- 퀘스트 지역에 들어서면 「퀘스트 지역」 안내가 뜹니다.
- **주 이야기**는 장마다 인물과 대화하는 장면부터 시작합니다. 장면을 다 보고해야 그 장의 단서가 탐색에 나옵니다. 장을 마치면 결말 장면이 나옵니다. 이미 마친 장과 단서를 찾기 시작한 장은 장면을 건너뛴 것으로 처리했습니다.

### 세력 화면
- 캐릭터 › 세력을 **칸 단추**로 바꿨습니다. 소속 임무·일일 보급·거점·등급과 퀘스트·의뢰판·비고·기부·수련장·세력 인물을 누르면 상점처럼 팝업으로 열립니다. 할 일이 있는 칸에는 빨간 점이 찍힙니다. **세력 판도**만 화면에 그대로 둡니다. 「세력 떠나기」는 거점 팝업 안에 있습니다.
- 수련장 시련과 비무의 합이 **한 줄씩 차례로** 올라옵니다(기기의 움직임 줄이기를 켜도 마찬가지). 「건너뛰기」로 한꺼번에 볼 수 있습니다.
- 안전지대 현장에 **「세력」 칸**이 생겼습니다.

### 밸런스
- 탐색력 1이 **15분**마다 찹니다(전에는 6분). 노정 건량은 탐색력 **+2**(전에는 +5).
- 퀘스트·이야기·상시 의뢰로 받는 전을 **×0.4**로 줄였습니다.
- 주 능력치가 주는 피해를 낮췄습니다. 피해 % 합계는 **+35%**까지, 칭호의 피해 %는 절반, 치명타는 **150%**(전에는 160%).
- 능력치 하나에 넣을 수 있는 포인트에 **상한(5 + 레벨×1.5)**이 생겼습니다. 넘게 넣은 몫은 포인트로 돌려드렸습니다.
- 장비 드롭: 일반 **1%**·정예 **5%**·우두머리 **15%**, 3단계 이상 장비는 우두머리만 떨어뜨립니다. 원정 완주 장비는 2시간 50%·4시간 보장.
- 사냥 경험치를 절반으로 줄이고 **레벨 차 배율**을 붙였습니다. 나보다 높은 요괴는 더 주고(최대 ×1.5), 많이 낮은 요괴는 거의 주지 않습니다(×0.2).
- 내 레벨보다 3 높은 바깥 지역에서는 침식이 1.5배, 5 높으면 2배로 오릅니다.
- 원정 경험치는 **끝까지 다녀왔을 때만** 한 번에 받습니다(지역 레벨·시간·깊이·레벨 차로 정함). 조기 귀환·쓰러짐은 경험치가 없습니다. 숙련 경험은 전과 같습니다.

### 고친 것
- 길과 채집터를 모두 찾아 답사도가 100%가 되어도 **지역 완전 답사**(가방 +1칸·창고 넓히기·다섯 곳 안개 사슴)를 받지 못하던 문제를 고쳤습니다. 이미 다 찾은 지역은 이번에 받습니다.
- 지역 들머리에 채집터가 없어 세력·퀘스트의 「○○에서 채집」이 0에서 멈추던 문제: 바깥 지역마다 들머리에 **「어귀의 …」 채집터**를 하나씩 두고 처음부터 찾은 것으로 했습니다.
- 원정 짐 보따리의 물품 이름을 누르면 물품 정보가 뜹니다. 가방 칸 표시 옆에 「창고 열기」 단추가 생겼습니다.
- 도움말의 귀령초 확률을 5.0.0 값으로 고쳤습니다.
$PN$, now())
on conflict (note_id) do update set title = excluded.title, body = excluded.body;

-- ⑦ 직업 역할 나누기(2026-10-29 결정): 근접 · 원거리 물리 · 술법 · 생활 특화 · 치유 · 보조
--   퇴마관 술법 딜 / 현장 조사원 원거리 물리 / 호위 무사(옛 법구 제작사) 근접 / 의무관 치유 / 봉인술사 보조(버프·디버프) / 백공 기술관(옛 기록 분석관) 생활 특화
--   내부 키(artificer·analyst)는 그대로 두고 이름·기본 능력치·시작 장비·직업 효과를 바꾼다.
--   기본 능력치 합은 전과 같은 30(전에는 모두 5). 기존 캐릭터는 새 기본값 + 지금까지 직접 찍은 몫(능력치 − 5)으로 다시 셈하고,
--   한 능력치 상한(직업 기본값 + 레벨×1.5)을 넘는 몫은 포인트로 돌려준다.

create or replace function public.world_job_base(p_job text)
returns jsonb language sql immutable set search_path to 'pg_catalog' as $$
  select case p_job
    when 'artificer'  then '{"strength":9,"agility":5,"vitality":7,"perception":3,"willpower":3,"spirit_affinity":3}'
    when 'scout'      then '{"strength":4,"agility":8,"vitality":4,"perception":8,"willpower":3,"spirit_affinity":3}'
    when 'exorcist'   then '{"strength":3,"agility":3,"vitality":4,"perception":4,"willpower":7,"spirit_affinity":9}'
    when 'medic'      then '{"strength":3,"agility":3,"vitality":6,"perception":3,"willpower":8,"spirit_affinity":7}'
    when 'sealmaster' then '{"strength":3,"agility":3,"vitality":5,"perception":4,"willpower":8,"spirit_affinity":7}'
    when 'analyst'    then '{"strength":5,"agility":6,"vitality":6,"perception":7,"willpower":3,"spirit_affinity":3}'
    else '{"strength":5,"agility":5,"vitality":5,"perception":5,"willpower":5,"spirit_affinity":5}' end::jsonb
$$;
alter function public.world_job_base(text) owner to fn_owner_field;
grant execute on function public.world_job_base(text) to public;

-- 능력치 하나의 상한 = 그 직업의 기본값 + 레벨×1.5(내림)
create or replace function public.world_stat_cap_of(p_job text, p_stat text, p_level int)
returns int language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select coalesce((public.world_job_base(p_job) ->> p_stat)::int, 5) + floor(greatest(1, coalesce(p_level, 1)) * 1.5)::int
$$;
alter function public.world_stat_cap_of(text, text, int) owner to fn_owner_field;
grant execute on function public.world_stat_cap_of(text, text, int) to public;

create or replace function public.world_job_label(p_job text)
returns text language sql immutable set search_path to 'pg_catalog' as $$
  select case p_job when 'exorcist' then '퇴마관' when 'scout' then '현장 조사원' when 'medic' then '의무관'
    when 'sealmaster' then '봉인술사' when 'analyst' then '백공 기술관' when 'artificer' then '호위 무사' end
$$;
alter function public.world_job_label(text) owner to fn_owner_field;
grant execute on function public.world_job_label(text) to public;

-- 직업 효과(상태 효과 합계에 더함). 피해 %는 그 공격 방식 무기를 들었을 때만 붙는다(world_combat_stats의 style_pct)
create or replace function public.world_job_effect(p_key text)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select case c.job_key
      when 'exorcist'   then case p_key when 'magic_pct' then 8 else 0 end
      when 'scout'      then case p_key when 'ranged_pct' then 8 else 0 end
      when 'artificer'  then case p_key when 'melee_pct' then 8 when 'incoming_damage_pct' then -6 else 0 end
      when 'medic'      then case p_key when 'healing_pct' then 10 else 0 end
      when 'sealmaster' then case p_key when 'mental_loss_pct' then -10 when 'erosion_pct' then -5 else 0 end
      when 'analyst'    then case p_key when 'gather_qty_pct' then 15 when 'rare_loot_pct' then 3 else 0 end
      else 0 end
    from public.world_characters c where c.owner_id = public.fn_owner_auth_uid()), 0)::numeric
$$;
alter function public.world_job_effect(text) owner to fn_owner_field;
revoke all on function public.world_job_effect(text) from public, anon, authenticated;
grant execute on function public.world_job_effect(text) to public;

-- 바꿀 자리를 정확히 한 번씩 찾아 고치는 도우미(이 파일 안에서만 쓰고 지운다)
create or replace function pg_temp.yh_patch(p_sig text, p_done text, p_pairs text[])
returns void language plpgsql as $$
declare d text := pg_get_functiondef(p_sig::regprocedure); i int;
begin
  if p_done is not null and position(p_done in d) > 0 then return; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> 1 then
      raise exception '직업 역할 고칠 자리 없음: % (%)', p_sig, left(p_pairs[2 * i - 1], 60); end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $$;

select pg_temp.yh_patch('public.world_status_effect_total(text)', 'world_job_effect', array[
  '+ public.world_level_gap_effect(p_effect_key)', '+ public.world_level_gap_effect(p_effect_key) + public.world_job_effect(p_effect_key)']);

-- 이름
select pg_temp.yh_patch('public.world_job_name(text)', '백공 기술관', array[
  'when ''analyst'' then ''기록 분석관'' when ''artificer'' then ''법구 제작사''', 'when ''analyst'' then ''백공 기술관'' when ''artificer'' then ''호위 무사''']);
select pg_temp.yh_patch('public.world_gimmick_tip(text)', '백공 기술관', array[
  'when ''analyst'' then ''기록 분석관''', 'when ''analyst'' then ''백공 기술관''',
  'when ''artificer'' then ''법구 제작사''', 'when ''artificer'' then ''호위 무사''',
  '폭렬 부적은 결계를 무시합니다.', '파갑참은 결계를 무시합니다.']);
update public.world_characters set occupation = public.world_job_label(job_key) where occupation is distinct from public.world_job_label(job_key) and public.world_job_label(job_key) is not null;

-- 제작 품질 +15·강화 확률 +10%p는 백공 기술관으로 옮긴다
select pg_temp.yh_patch('public.world_craft_item(text)', 'when ''analyst'' then ''백공 기술관''', array[
  '+case when c.job_key=''artificer'' then 15 else 0 end+', '+case when c.job_key=''analyst'' then 15 else 0 end+',
  'when ''analyst'' then ''기록 분석관'' when ''artificer'' then ''법구 제작사''', 'when ''analyst'' then ''백공 기술관'' when ''artificer'' then ''호위 무사''']);
select pg_temp.yh_patch('public.world_weapon_enhance()', 'c.job_key = ''analyst'' then 10', array[
  'case when c.job_key = ''artificer'' then 10 else 0 end', 'case when c.job_key = ''analyst'' then 10 else 0 end']);
select pg_temp.yh_patch('public.world_enhance_quote()', 'c.job_key = ''analyst'' then 10', array[
  'case when c.job_key = ''artificer'' then 10 else 0 end', 'case when c.job_key = ''analyst'' then 10 else 0 end']);

-- 탐색: 채집터 찾기 보정은 현장 조사원·백공 기술관
select pg_temp.yh_patch('public.world_field_search()', 'c.job_key IN (''analyst'', ''scout'') THEN 4', array[
  'CASE WHEN c.job_key IN (''artificer'', ''scout'') THEN 4 ELSE 0 END', 'CASE WHEN c.job_key IN (''analyst'', ''scout'') THEN 4 ELSE 0 END']);

-- 전투 능력치: 치명타 +8(기록 분석관) → 없앰, 호위 무사 이목 +30(앞에 서서 공격을 끈다)
select pg_temp.yh_patch('public.world_combat_stats(uuid,jsonb)', 'c.job_key = ''artificer'' THEN 30', array[
  ' + CASE WHEN c.job_key = ''analyst'' THEN 8 ELSE 0 END', '',
  'pres := greatest(5, least(300, 30 + s_vit * 0.8', 'pres := greatest(5, least(300, 30 + CASE WHEN c.job_key = ''artificer'' THEN 30 ELSE 0 END + s_vit * 0.8']);

-- 현장 토벌 직업 기술: 호위 무사 「파갑참」(근접, 방어·껍질·결계 무시, ×1.7)
do $$ declare d text := pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure);
  a text := 'ELSIF act = ''skill'' AND c.job_key = ''artificer'' THEN skill_name := ''폭렬 부적'';';
  b text := 'ELSIF act = ''skill'' AND c.job_key = ''artificer'' THEN style := ''melee''; skill_name := ''파갑참'';';
begin
  if position('파갑참' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '직업 역할 고칠 자리 없음: 파갑참'; end if;
  execute replace(replace(d, a, b), '''폭렬 부적''', '''파갑참''');
end $$;

-- 원정 직업 기술: 호위 무사 「반격 태세」(밀린 다음 싸움 승률 +15%), 백공 기술관 「현장 가공」(채집 25% 하나 더)
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)', '[반격 태세]', array[
  'if c.job_key = ''analyst'' then weak_bonus := 0.15; end if;', 'if c.job_key = ''artificer'' then weak_bonus := 0.15; end if;',
  '''[약점 간파] 앞서 밀렸던 싸움에서 읽어 낸 약점을 노립니다.''', '''[반격 태세] 앞서 밀렸던 싸움을 되새겨 빈틈없이 맞받아칩니다.''',
  'case when c.job_key in (''artificer'', ''scout'') then 0.15 else 0 end', 'case when c.job_key in (''analyst'', ''scout'') then 0.15 else 0 end',
  'if c.job_key = ''artificer'' and qty > 0 and random() < 0.25 then', 'if c.job_key = ''analyst'' and qty > 0 and random() < 0.25 then']);
select pg_temp.yh_patch('public.world_expedition_finish(boolean)', 'c.job_key IN (''analyst'', ''scout'') THEN 0.15', array[
  'CASE WHEN c.job_key IN (''artificer'', ''scout'') THEN 0.15 ELSE 0 END', 'CASE WHEN c.job_key IN (''analyst'', ''scout'') THEN 0.15 ELSE 0 END']);
select pg_temp.yh_patch('public.world_expedition_complete(boolean)', 'when ''artificer'' then ''반격 태세''', array[
  'when ''analyst'' then ''약점 간파'' when ''artificer'' then ''현장 가공''', 'when ''analyst'' then ''현장 가공'' when ''artificer'' then ''반격 태세''']);
select pg_temp.yh_patch('public.world_expedition_progress()', 'when ''artificer'' then ''반격 태세''', array[
  'when ''analyst'' then ''약점 간파'' when ''artificer'' then ''현장 가공''', 'when ''analyst'' then ''현장 가공'' when ''artificer'' then ''반격 태세''']);
select pg_temp.yh_patch('public.world_exp_fight_story(uuid,text,text,jsonb,integer,boolean,integer,integer,jsonb,double precision,double precision,timestamp with time zone,integer,text,text,integer,jsonb)', '[호위 일격]', array[
  'when ''analyst'' then ''[약점 간파] {f}의 움직임에서 빈틈을 읽었습니다''', 'when ''analyst'' then ''[현장 기지] 주변 지형을 이용해 {f}의 발을 묶었습니다''',
  'when ''artificer'' then ''[법구 발동] 허리춤의 법구가 빛을 뿜어 {f}을(를) 밀어냈습니다''', 'when ''artificer'' then ''[호위 일격] 앞을 막아서며 {f}을(를) 베어 넘겼습니다''']);
select pg_temp.yh_patch('public.world_expedition_walk_lines(uuid)', '동료가 지나갈 길목', array[
  'when ''analyst'' then array[''지금까지 본 요괴의 습성을 수첩에 정리합니다.'', ''흔적의 순서를 맞춰 보며 동선을 추론합니다.'', ''모순되는 단서 하나에 밑줄을 그어 둡니다.'']',
  'when ''analyst'' then array[''쓸 만한 부품을 주워 주머니에 넣습니다.'', ''바위틈의 약초 뿌리를 다치지 않게 캐 둡니다.'', ''이상한 광택의 금속 조각을 수첩에 그려 둡니다.'']',
  'when ''artificer'' then array[''쓸 만한 부품을 주워 주머니에 넣습니다.'', ''헐거워진 장비의 매듭을 고쳐 조입니다.'', ''이상한 광택의 금속 조각을 살펴봅니다.'']',
  'when ''artificer'' then array[''칼자루를 고쳐 쥐고 앞장섭니다.'', ''동료가 지나갈 길목을 먼저 살핍니다.'', ''갑옷 끈을 다시 단단히 조입니다.'']']);

-- 능력치 올리기: 직업별 상한
select pg_temp.yh_patch('public.world_allocate_stat(text)', 'world_stat_cap_of', array[
  '>= public.world_stat_cap(c.level) then raise exception', '>= public.world_stat_cap_of(c.job_key, p_stat, c.level) then raise exception',
  '(레벨이 오르면 늘어납니다).'', public.world_stat_cap(c.level);', '(레벨이 오르면 늘어납니다).'', public.world_stat_cap_of(c.job_key, p_stat, c.level);']);

-- 되돌릴 포인트 = 직업 기본값을 넘는 몫
create or replace function public.world_reset_points(p_uid uuid)
returns integer language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select greatest(0, c.strength - (b ->> 'strength')::int) + greatest(0, c.agility - (b ->> 'agility')::int) + greatest(0, c.vitality - (b ->> 'vitality')::int)
       + greatest(0, c.perception - (b ->> 'perception')::int) + greatest(0, c.willpower - (b ->> 'willpower')::int) + greatest(0, c.spirit_affinity - (b ->> 'spirit_affinity')::int)
    from public.world_characters c cross join lateral (select public.world_job_base(c.job_key) b) j where c.owner_id = p_uid
$$;
-- 세심단: 지금 직업의 기본값으로 / 환골탈태: 새 직업의 기본값으로
select pg_temp.yh_patch('public.world_reset_stats()', 'world_job_base', array[
  'set strength = least(strength, 5), agility = least(agility, 5), vitality = least(vitality, 5), perception = least(perception, 5),',
  'set strength = (public.world_job_base(job_key) ->> ''strength'')::int, agility = (public.world_job_base(job_key) ->> ''agility'')::int, vitality = (public.world_job_base(job_key) ->> ''vitality'')::int, perception = (public.world_job_base(job_key) ->> ''perception'')::int,',
  'willpower = least(willpower, 5), spirit_affinity = least(spirit_affinity, 5), stat_points = stat_points + back,',
  'willpower = (public.world_job_base(job_key) ->> ''willpower'')::int, spirit_affinity = (public.world_job_base(job_key) ->> ''spirit_affinity'')::int, stat_points = stat_points + back,']);
select pg_temp.yh_patch('public.world_reset_identity(text,text)', 'world_job_base', array[
  'job_label := case p_job when ''exorcist'' then ''퇴마관'' when ''scout'' then ''현장 조사원'' when ''medic'' then ''의무관''', 'job_label := public.world_job_label(p_job); /*',
  'when ''sealmaster'' then ''봉인술사'' when ''analyst'' then ''기록 분석관'' when ''artificer'' then ''법구 제작사'' end;', '*/',
  'strength = least(strength, 5), agility = least(agility, 5), vitality = least(vitality, 5), perception = least(perception, 5),',
  'strength = (public.world_job_base(p_job) ->> ''strength'')::int, agility = (public.world_job_base(p_job) ->> ''agility'')::int, vitality = (public.world_job_base(p_job) ->> ''vitality'')::int, perception = (public.world_job_base(p_job) ->> ''perception'')::int,',
  'willpower = least(willpower, 5), spirit_affinity = least(spirit_affinity, 5), stat_points = stat_points + back,',
  'willpower = (public.world_job_base(p_job) ->> ''willpower'')::int, spirit_affinity = (public.world_job_base(p_job) ->> ''spirit_affinity'')::int, stat_points = stat_points + back,']);

-- 새 캐릭터: 직업 기본 능력치와 역할에 맞는 시작 장비
create or replace function public.world_create_character_v2(p_name text, p_job text, p_faction text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare
  uid uuid := public.fn_owner_auth_uid();
  nm text := btrim(coalesce(p_name, ''));
  r public.world_characters%rowtype;
  job_label text; b jsonb; kit jsonb; inv jsonb; it record;
begin
  if uid is null then raise exception '로그인이 필요합니다.' using errcode = '28000'; end if;
  if exists (select 1 from public.world_characters where owner_id = uid) then
    raise exception '이미 캐릭터가 있습니다. 이름·직업·소속은 생성 후 변경할 수 없습니다.';
  end if;
  if char_length(nm) < 2 or char_length(nm) > 12 then raise exception '이름은 2~12자로 입력하세요.'; end if;
  if nm !~ '^[가-힣A-Za-z0-9 ]+$' then raise exception '이름에는 한글·영문·숫자·공백만 사용할 수 있습니다.'; end if;
  job_label := public.world_job_label(p_job);
  if job_label is null then raise exception '직업을 선택하세요.'; end if;
  if p_faction is null or p_faction not in ('headquarters','fieldbureau','archivebureau','sealbureau','medicalbureau','independent') then
    raise exception '소속을 선택하세요.';
  end if;
  if exists (select 1 from public.world_characters where lower(btrim(character_name)) = lower(nm)) then
    raise exception '이미 사용 중인 이름입니다.';
  end if;
  b := public.world_job_base(p_job);
  -- 역할별 시작 장비(장착 칸 → 물품)와 덤 물품
  kit := case p_job
    when 'artificer'  then '{"weapon":"iron_sword","armor":"a1_iron","hat":"h1_guard","amulet":"m1_ward","tool":"field_knife"}'
    when 'scout'      then '{"weapon":"w_ranged1_keen","armor":"a1_light","shoes":"s1_swift","tool":"field_knife"}'
    when 'exorcist'   then '{"weapon":"spirit_bell","armor":"a1_robe","amulet":"m1_spell","tool":"field_knife"}'
    when 'medic'      then '{"weapon":"w_magic1_silent","armor":"a1_robe","amulet":"m1_purify","tool":"field_knife"}'
    when 'sealmaster' then '{"weapon":"w_magic1_heavy","armor":"padded_coat","hat":"h1_calm","tool":"field_knife"}'
    else                   '{"weapon":"w_melee1_keen","armor":"padded_coat","norigae":"n1_plenty","shoes":"s1_road","tool":"field_knife"}' end::jsonb;
  inv := '{"herb":2,"ward_talisman":1,"ore_pick":1,"seal_paper":1,"wood":0,"ore":0}'::jsonb;
  for it in select value v from jsonb_each_text(kit) loop inv := inv || jsonb_build_object(it.v, coalesce((inv ->> it.v)::int, 0) + 1); end loop;
  inv := inv || case p_job
    when 'scout'      then '{"ammo_arrow":100}'
    when 'medic'      then '{"herb":5,"tonic":3}'
    when 'sealmaster' then '{"seal_paper":4,"ward_talisman":2}'
    when 'analyst'    then '{"fishing_rod":1}'
    else '{}' end::jsonb;
  begin
    insert into public.world_characters(owner_id, character_name, occupation, inventory, job_key, faction_key,
                                        strength, agility, vitality, perception, willpower, spirit_affinity)
    values (uid, nm, job_label, inv, p_job, p_faction,
            (b ->> 'strength')::int, (b ->> 'agility')::int, (b ->> 'vitality')::int, (b ->> 'perception')::int, (b ->> 'willpower')::int, (b ->> 'spirit_affinity')::int)
    returning * into r;
  exception when unique_violation then
    raise exception '이미 사용 중인 이름이거나 캐릭터가 이미 있습니다.';
  end;
  insert into public.world_character_equipment(owner_id, slot, item_id)
  select uid, k.key, k.value from jsonb_each_text(kit) k
  on conflict (owner_id, slot) do nothing;
  return jsonb_build_object('ok', true, 'character_name', r.character_name, 'job_key', r.job_key, 'faction_key', r.faction_key);
end
$function$;

-- 기존 캐릭터: 새 기본값 + 직접 찍은 몫, 상한을 넘는 몫은 포인트로(한 번만)
with x as (
  select c.owner_id, b,
         (b ->> 'strength')::int + greatest(0, c.strength - 5) s1, (b ->> 'agility')::int + greatest(0, c.agility - 5) s2,
         (b ->> 'vitality')::int + greatest(0, c.vitality - 5) s3, (b ->> 'perception')::int + greatest(0, c.perception - 5) s4,
         (b ->> 'willpower')::int + greatest(0, c.willpower - 5) s5, (b ->> 'spirit_affinity')::int + greatest(0, c.spirit_affinity - 5) s6,
         floor(greatest(1, c.level) * 1.5)::int lv
    from public.world_characters c cross join lateral (select public.world_job_base(c.job_key) b) j
   where not exists (select 1 from public.world_app_meta m where m.key = 'v6_job_base'))
update public.world_characters c
   set strength = least(x.s1, (x.b ->> 'strength')::int + x.lv), agility = least(x.s2, (x.b ->> 'agility')::int + x.lv),
       vitality = least(x.s3, (x.b ->> 'vitality')::int + x.lv), perception = least(x.s4, (x.b ->> 'perception')::int + x.lv),
       willpower = least(x.s5, (x.b ->> 'willpower')::int + x.lv), spirit_affinity = least(x.s6, (x.b ->> 'spirit_affinity')::int + x.lv),
       stat_points = c.stat_points + greatest(0, x.s1 - (x.b ->> 'strength')::int - x.lv) + greatest(0, x.s2 - (x.b ->> 'agility')::int - x.lv)
                   + greatest(0, x.s3 - (x.b ->> 'vitality')::int - x.lv) + greatest(0, x.s4 - (x.b ->> 'perception')::int - x.lv)
                   + greatest(0, x.s5 - (x.b ->> 'willpower')::int - x.lv) + greatest(0, x.s6 - (x.b ->> 'spirit_affinity')::int - x.lv),
       updated_at = now()
  from x where x.owner_id = c.owner_id;
insert into public.world_app_meta(key, value) values ('v6_job_base', '1') on conflict (key) do nothing;

drop function pg_temp.yh_patch(text, text, text[]);

-- 패치노트 6.0.0에 직업 역할을 더한다
update public.world_patch_notes set body = replace(body, E'### 밸런스\n', E'### 직업 역할\n- 직업을 **여섯 역할**로 나눴습니다. 호위 무사(옛 법구 제작사) **근접** · 현장 조사원 **원거리 물리** · 퇴마관 **술법** · 의무관 **치유** · 봉인술사 **보조(버프·디버프)** · 백공 기술관(옛 기록 분석관) **생활 특화**.\n- 직업마다 **기본 능력치**가 다릅니다(합은 모두 30). 지금 캐릭터는 새 기본값에 지금까지 직접 올린 몫을 그대로 더했고, 한 능력치 상한(**직업 기본값 + 레벨×1.5**)을 넘은 몫은 포인트로 돌려드렸습니다. 세심단·환골탈태도 직업 기본값으로 되돌립니다.\n- 직업 효과: 호위 무사 근접 피해 +8%·받는 피해 −6%·이목 +30, 현장 조사원 원거리 피해 +8%, 퇴마관 술법 피해 +8%, 의무관 회복 +10%, 봉인술사 정신 손실 −10%·침식 −5%, 백공 기술관 채집량 +15%·희귀품 +3%. 피해 보정은 그 역할의 무기를 들었을 때만 붙습니다.\n- 옛 법구 제작사의 제작 품질 +15·강화 확률 +10%p·원정 「현장 가공」은 **백공 기술관**으로, 옛 기록 분석관의 원정 「약점 간파」는 호위 무사의 「반격 태세」로 옮겼습니다. 기록 분석관의 치명타 +8은 없앴습니다. 호위 무사의 현장 기술은 「파갑참」(근접, 방어·결계 무시)입니다.\n- 새 캐릭터는 역할에 맞는 **시작 장비**를 갖추고 시작합니다(현장 조사원은 화살 100발 포함).\n- 새 역할로 갈아타실 수 있도록 모두에게 **「환골탈태 서첩」을 하나씩** 드렸습니다(가방에 자리가 없으면 창고).\n\n### 밸런스\n')
 where note_id = '6.0.0' and position('### 직업 역할' in body) = 0;

-- 직업 역할이 바뀌었으니 모두에게 「환골탈태 서첩」 하나씩(이미 있어도 하나 더). 가방에 자리가 없으면 창고(한 번만)
update public.world_item_catalog set description = '능력치를 직업 기본값으로 되돌리고 쓴 포인트를 모두 돌려받습니다. 귀속 물품이라 거래·판매할 수 없습니다(창고에는 맡길 수 있습니다).'
 where item_id = 'reset_stats';
do $$
declare r record;
begin
  if exists (select 1 from public.world_app_meta where key = 'v6_job_reset_gift') then return; end if;
  for r in select owner_id, inventory from public.world_characters where not coalesce(is_dead, false) loop
    if public.world_bag_room(r.inventory, 'reset_identity', public.world_bag_limit(r.owner_id)) >= 1 then
      update public.world_characters set inventory = public.world_inv_add(inventory, 'reset_identity', 1) where owner_id = r.owner_id;
    else
      insert into public.world_storage(owner_id, items) values (r.owner_id, jsonb_build_object('reset_identity', 1))
      on conflict (owner_id) do update set items = public.world_inv_add(public.world_storage.items, 'reset_identity', 1), updated_at = now();
    end if;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.owner_id, 'reward', '직업 역할 개편 · 환골탈태 서첩', '직업이 여섯 역할(근접·원거리 물리·술법·생활 특화·치유·보조)로 나뉘었습니다. 새 역할로 갈아타실 수 있도록 「환골탈태 서첩」을 하나 드렸습니다(가방에 자리가 없으면 창고). 능력치는 새 직업 기본값으로 다시 셌습니다.', '{}'::jsonb);
  end loop;
  insert into public.world_app_meta(key, value) values ('v6_job_reset_gift', '1');
end $$;
