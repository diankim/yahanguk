-- 침식 밸런스(2026-10-28 결정: 보통 속도 · 모든 직업에 불이익 · 고위험 보상)
-- 오르는 곳
--   탐색: 위험도 1~2는 반쯤 +1, 3~4는 +1, 5 이상은 +2. 삼경 +0.5, 사당·폐단·묘역·지하·심연 같은 어두운 곳 +0.5. 침식 보정(장비·칭호·음식·상태·날씨, 혈무는 날씨 보정으로 이미 더 오른다) 반영, 소수는 확률로 올림.
--   토벌: 위험도 3 이상에서 이기면 +1, 지면 +3. 영체·독성·반사·매복 요괴나 정예·우두머리는 +2 더. 침식 보정 반영.
--   (원정은 지금 그대로 위험도·깊이에 따라 오른다.)
-- 단계별 효과(world_status_effect_total에 world_erosion_effect를 더한다)
--   주의 30+: 회복량 −15%, 희귀품·단서 +5%
--   위험 55+: 회복량 −25%, 받는 피해 +10%, 행동마다 정신 −1, 희귀품·단서 +10%
--   붕괴 직전 80+: 회복량 −35%, 받는 피해 +20%, 주는 피해 −10%, 요괴 조우 +20%, 희귀품·단서 +15%
--   (술법 공격력 −10/−20/−30%는 world_combat_stats에 이미 있다.)
--   100에 닿으면 정신이 0이 된다.

/* ── 단계별 효과 ─────────────────────────────────────────── */
create or replace function public.world_erosion_effect(p_effect_key text)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select case p_effect_key
      when 'healing_pct' then case when e >= 80 then -35 when e >= 55 then -25 when e >= 30 then -15 else 0 end
      when 'incoming_damage_pct' then case when e >= 80 then 20 when e >= 55 then 10 else 0 end
      when 'combat_damage_pct' then case when e >= 80 then -10 else 0 end
      when 'encounter_pct' then case when e >= 80 then 20 else 0 end
      when 'rare_loot_pct' then case when e >= 80 then 15 when e >= 55 then 10 when e >= 30 then 5 else 0 end
      when 'clue_bonus_pct' then case when e >= 80 then 15 when e >= 55 then 10 when e >= 30 then 5 else 0 end
      else 0 end
    from (select coalesce(erosion, 0) as e from public.world_characters where owner_id = public.fn_owner_auth_uid()) x), 0)::numeric
$$;
alter function public.world_erosion_effect(text) owner to fn_owner_field;
revoke all on function public.world_erosion_effect(text) from public;
-- 칭호 효과(world_title_extra)를 부를 수 있는 역할이 이것도 부를 수 있게(상태 효과 합계를 거쳐 불린다)
do $$
declare ro text;
begin
  for ro in select r.rolname from pg_roles r where has_function_privilege(r.oid, 'public.world_title_extra(text)', 'execute') and r.rolname <> 'postgres' loop
    execute format('grant execute on function public.world_erosion_effect(text) to %I', ro);
  end loop;
end $$;

do $$
declare d text; a text := 'public.world_title_extra(p_effect_key)';
begin
  d := pg_get_functiondef('public.world_status_effect_total(text)'::regprocedure);
  if position('world_erosion_effect' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '상태 효과 합계에서 더할 자리를 찾지 못했습니다'; end if;
  execute replace(d, a, a || ' + public.world_erosion_effect(p_effect_key)');
end $$;

/* ── 위험 단계: 행동마다 정신 −1 ───────────────────────────── */
grant fn_owner_20175 to postgres with inherit true;
do $$
declare d text;
  a text := $q$into hp_tick,mental_tick from public.world_character_statuses cs join public.world_status_catalog cat using(status_key) where cs.owner_id=new.actor_id and cs.expires_at>now() and activity_key=any(cat.triggers);$q$;
begin
  d := pg_get_functiondef('public.world_apply_activity_status()'::regprocedure);
  if position('erosion >= 55' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '행동 상태 함수에서 고칠 줄을 찾지 못했습니다'; end if;
  execute replace(d, a, a || $q$
  -- 침식 위험(55) 이상이면 행동마다 정신 1을 더 잃는다
  mental_tick := mental_tick + coalesce((select case when ch.erosion >= 55 then 1 else 0 end from public.world_characters ch where ch.owner_id = new.actor_id), 0);$q$);
end $$;
grant fn_owner_20175 to postgres with inherit false;

/* ── 토벌로 오르는 침식 ──────────────────────────────────── */
-- 토벌 기록 트리거(소유 fn_owner_18941)가 침식 보정(장비·칭호·음식·상태)을 읽을 수 있게: 탐색 함수와 같은 소유자(fn_owner_field)가 계산하는 작은 함수만 연다
create or replace function public.world_erosion_pct_self()
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select public.world_status_effect_total('erosion_pct')
$$;
alter function public.world_erosion_pct_self() owner to fn_owner_field;
revoke all on function public.world_erosion_pct_self() from public;
grant execute on function public.world_erosion_pct_self() to fn_owner_18941;
grant fn_owner_18941 to postgres with inherit true;
do $$
declare d text; i int; j int; pre text; kp int;
  head text := $q$er := case when payload->>'mechanic' in ($q$;
  tail text := $q$else 0 end;$q$;
  kc text := $q$if k='combat' then$q$;
begin
  d := pg_get_functiondef('public.world_apply_event_progress()'::regprocedure);
  if position('world_erosion_pct_self' in d) > 0 then return; end if;
  i := position(head in d);
  if i = 0 then raise exception '토벌 침식 줄(시작)을 찾지 못했습니다'; end if;
  j := position(tail in substr(d, i));
  if j = 0 then raise exception '토벌 침식 줄(끝)을 찾지 못했습니다'; end if;
  -- 바로 앞의 「if k='combat' then」을 진 싸움(battle_lost)까지 받도록 넓힌다
  pre := substr(d, 1, i - 1);
  kp := length(pre) - position(reverse(kc) in reverse(pre)) - length(kc) + 2;
  if position(kc in pre) = 0 or i - kp > 40 then raise exception '토벌 침식 줄 앞의 조건을 찾지 못했습니다'; end if;
  pre := substr(pre, 1, kp - 1) || $q$if k in ('combat', 'battle_lost') then$q$ || substr(pre, kp + length(kc));
  d := pre || $q$er := floor((
        case when coalesce((payload->>'defeated')::boolean, false)
          then case when coalesce((select m.danger_level from public.world_map_regions m where m.region_id = payload->>'region_id'), 1) >= 3 then 1 else 0 end
          else 3 end
        + case when payload->>'mechanic' in ('독성','toxic','영체','spectral','반사','reflect','매복','ambush','boss') or payload->>'rank' in ('elite','boss','guardian') then 2 else 0 end
      ) * greatest(0, 1 + public.world_erosion_pct_self() / 100.0) + random())::int;$q$
    || substr(d, i + j - 1 + length(tail));
  execute d;
end $$;
grant fn_owner_18941 to postgres with inherit false;

/* ── 탐색으로 오르는 침식 ────────────────────────────────── */
do $$
declare d text; i int; j int;
  head text := $q$erosion = greatest(0, least(100, erosion - 2 + CASE WHEN (r.danger_level >= 5 AND random() < 0.4)$q$;
  stop text := $q$WHERE owner_id = uid;$q$;
begin
  d := pg_get_functiondef('public.world_field_search()'::regprocedure);
  if position('dark_place' in d) > 0 then return; end if;
  i := position(head in d);
  if i = 0 then raise exception '탐색 침식 줄을 찾지 못했습니다'; end if;
  j := position(stop in substr(d, i));
  if j = 0 then raise exception '탐색 침식 줄의 끝을 찾지 못했습니다'; end if;
  -- 탐사 트리거가 더하는 2를 되돌리고, 그 자리에 위험도·시간·날씨·장소에 따른 값을 더한다(dark_place: 어두운 곳)
  d := substr(d, 1, i - 1) || $q$erosion = greatest(0, least(100, erosion - 2 + floor((
      CASE WHEN r.danger_level >= 5 THEN 2 WHEN r.danger_level >= 3 THEN 1 ELSE 0.5 END
      + CASE WHEN public.world_time_phase(now()) = 'night' THEN 0.5 ELSE 0 END
      + CASE WHEN r.region_type IN ('sealed_shrine', 'ruined_temple', 'burial_ground', 'underground', 'abyss', 'rift', 'lost_city', 'underwater_ruins', 'haunted_garden', 'blood_forest') THEN 0.5 ELSE 0 END -- dark_place
    ) * greatest(0, 1 + public.world_status_effect_total('erosion_pct') / 100.0) + random())::int))
  WHERE owner_id = uid;
  UPDATE public.world_characters SET
    erosion_stage = CASE WHEN erosion >= 80 THEN 4 WHEN erosion >= 55 THEN 3 WHEN erosion >= 30 THEN 2 WHEN erosion >= 10 THEN 1 ELSE 0 END
  $q$ || substr(d, i + j - 1);
  execute d;
end $$;

/* ── 100에 닿으면 정신이 바닥난다 ───────────────────────────── */
create or replace function public.world_erosion_overflow()
returns trigger language plpgsql set search_path to 'pg_catalog', 'public' as $$
begin
  if coalesce(new.erosion, 0) >= 100 and coalesce(old.erosion, 0) < 100 then
    new.mental := 0;
  end if;
  return new;
end $$;
drop trigger if exists trg_world_erosion_overflow on public.world_characters;
create trigger trg_world_erosion_overflow before update of erosion on public.world_characters
  for each row execute function public.world_erosion_overflow();

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028140000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
