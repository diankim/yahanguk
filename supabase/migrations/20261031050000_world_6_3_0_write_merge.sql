-- 6.3.0 서버 부담 정리 ②: 행동 한 번의 캐릭터 행 쓰기 줄이기.
-- world_events가 한 줄 들어갈 때마다 후속 트리거 다섯·여섯 개가 저마다 world_characters를 고쳐(노정패·숙련 경험·침식·희귀 전리품·
-- 기술 경험·경험치/레벨·평판·행동마다 상태 피해) 탐색 한 번에 캐릭터 행이 9~10번 새로 쓰였다. 행이 고쳐질 때마다
-- 캐릭터 BEFORE 트리거(world_skill_sync 등)가 다시 돌고, 변경 기록(WAL)이 쌓이고, 실시간(realtime.list_changes)이 그 기록을 모두 읽는다.
-- ① 그 트리거들을 world_event_char_apply 하나로 합쳐 캐릭터 행을 한 번만 고친다(주는 값·순서는 그대로).
-- ② 탐색(world_field_search)이 따로 하던 갱신(전리품·경험치, 단서 숙련, 함정 피해, 길조 정신·영력, 침식, 침식 단계)을 한 번으로 합친다.
--    옛 탐사 트리거가 탐사마다 침식 +2를 하고 탐색이 −2로 되돌리던 것을 둘 다 뺀다(탐사 기록은 탐색만 남긴다).
-- ③ 이미 다 찬 의뢰·소속 임무 진행을 다시 쓰지 않는다.
-- ④ 탐색력: 6.0.0에서 1 회복을 15분으로 정했는데 탐색력을 쓰는 world_stamina_change만 6분(360초)으로 남아 있었다 → 900초.
-- 트리거 함수(world_award_mount_tokens·world_apply_event_progress·world_track_specialized_skill·world_award_progression_from_event·
-- world_track_major_faction_reputation)는 되돌릴 때 쓰도록 남기고 트리거만 지운다.
lock table public.world_characters in access exclusive mode;

-- 고칠 함수의 주인 역할(world_apply_activity_status·world_track_faction_missions는 옛 fn_owner_* 역할 것)
do $$ declare r text; begin
  foreach r in array array['fn_owner_field', 'fn_owner_20175', 'fn_owner_18540'] loop
    if not pg_has_role('postgres', r, 'usage') then execute format('grant %I to postgres with inherit true, set true', r); end if;
  end loop;
end $$;

create or replace function public.world_event_char_apply()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $f$
declare
  uid uuid := new.actor_id; k text := coalesce(new.event_type, ''); p jsonb := coalesce(new.payload, '{}'::jsonb);
  won boolean := coalesce((new.payload ->> 'defeated')::boolean, false); trav boolean;
  c public.world_characters%rowtype; act text; hp_tick int := 0; mn_tick int := 0;
  tok int := 0; xp_e int := 0; award int := 0; er int := 0; er_x int := 0; rep int := 0;
  sk text; sk_xp int := 0; rcp text; rare text;
  cx int; gx int; crx int; ix int; nx int; nl int; gained int := 0; sp jsonb; ero int; hp int; mn int; dn timestamptz;
begin
  if uid is null then return new; end if;
  trav := k in ('travel', 'move') and p ? 'travel_history_id';
  perform set_config('request.jwt.claim.sub', uid::text, true);
  -- 행동마다 상태 피해를 받는 활동(옛 world_apply_activity_status)
  act := case when k = 'combat' then 'combat' when k in ('explore', 'regional_explore') then 'explore' when k in ('gather', 'gathering') then 'gather'
    when k in ('craft', 'crafting') then 'craft' when k in ('investigation', 'investigate', 'case') then 'investigation' when k in ('training', 'train') then 'training'
    when trav then 'travel' when k = 'rest' then 'rest' when k = 'rescue' then 'rescue' when k = 'story' then 'story' end;
  -- 노정패(옛 world_award_mount_tokens)
  if k = 'combat' and won then tok := 1;
  elsif k in ('explore', 'gather') and random() < 1.0 / 6 then tok := 1;
  elsif k = 'story' then tok := 3;
  elsif k in ('commission', 'mission') then tok := 2; end if;
  -- 숙련 경험(옛 world_apply_event_progress)
  xp_e := case when k = 'combat' then case when won then 45 else 0 end when k = 'gather' then 18 when k = 'craft' then 22
    when k in ('explore', 'story', 'faction') then 16 else 0 end;
  -- 경험치(옛 world_award_progression_from_event)
  award := case k when 'combat' then case when won then 12 else 0 end when 'craft' then 18 when 'gather' then 14 when 'explore' then 12
    when 'story' then 20 when 'equip' then 4 when 'travel' then case when p ? 'travel_history_id' then 5 else 0 end
    when 'travel_arrive' then 5 when 'trade' then 5 when 'shop_buy' then 3 when 'shop_sell' then 3 when 'mount' then 5
    when 'supply' then 3 when 'craft_refine' then 18 when 'rest' then 2 else 0 end;
  -- 기술 경험(옛 world_track_specialized_skill)
  if k in ('combat', 'gather', 'craft', 'explore', 'story', 'rescue') or (k = 'travel' and p ? 'travel_history_id') then
    sk := case
      when k = 'combat' and coalesce(p ->> 'action', '') = 'ranged' then 'ranged'
      when k = 'combat' and coalesce(p ->> 'action', '') = 'seal' then 'sealing'
      when k = 'combat' and coalesce(p ->> 'action', '') = 'analyze' then 'analysis'
      when k = 'combat' and coalesce(p ->> 'action', '') = 'support' then 'first_aid'
      when k = 'combat' and coalesce(p ->> 'action', '') = 'guard' then 'guarding'
      when k = 'combat' then 'melee'
      when k = 'gather' and coalesce(p ->> 'node', '') = 'ore' then 'mining'
      when k = 'gather' and coalesce(p ->> 'node', '') = 'herb' then 'herbalism'
      when k = 'gather' and coalesce(p ->> 'node', '') = 'shrine' then 'spirit_gathering'
      when k = 'gather' then 'foraging'
      when k in ('explore', 'story', 'travel') then 'tracking' end;
    if k = 'craft' then
      select coalesce(required_skill, case craft_field when 'sealing' then 'wardcraft' when 'alchemy' then 'alchemy' when 'cooking' then '-' else 'smithing' end)
        into rcp from public.world_crafting_recipes where recipe_id = coalesce(p ->> 'recipe', '');
      sk := nullif(coalesce(rcp, case when coalesce(p ->> 'recipe', '') ilike '%seal%' then 'wardcraft' when coalesce(p ->> 'recipe', '') ilike '%alchemy%' then 'alchemy' else 'smithing' end), '-');
    end if;
    sk_xp := case k when 'combat' then 10 when 'gather' then 8 when 'craft' then 12 when 'explore' then 8 when 'story' then 10 when 'travel' then 3 else 0 end;
    if sk_xp <= 0 then sk := null; end if;
  end if;
  -- 대세력 평판(옛 world_track_major_faction_reputation): 토벌은 이긴 기록에만
  if not (k = 'combat' and not won) then
    rep := case k when 'combat' then 3 when 'story' then 3 when 'explore' then 2 when 'gather' then 1 when 'craft' then 1 when 'mission' then 4 else 0 end;
  end if;
  -- 토벌 침식(옛 world_apply_event_progress, 보정은 아래에서)
  if k in ('combat', 'battle_lost') then
    er := case when won then case when public.world_region_danger(p ->> 'region_id') >= 3 then 1 else 0 end else 3 end
      + case when p ->> 'mechanic' in ('독성', 'toxic', '영체', 'spectral', '반사', 'reflect', '매복', 'ambush', 'boss') or p ->> 'rank' in ('elite', 'boss', 'guardian') then 2 else 0 end;
  elsif k = 'explore' and coalesce(p ->> 'kind', '') <> 'field_search' and coalesce(p ->> 'location', '') not in ('야행국 본부 · 로비', '본부 로비', 'hq_yard') then
    er_x := 2;
  end if;
  if act is null and tok = 0 and xp_e = 0 and award = 0 and sk is null and rep = 0 and er = 0 and er_x = 0 then return new; end if;

  select * into c from public.world_characters where owner_id = uid for update;
  if not found or coalesce(c.is_dead, false) then return new; end if;
  if act is not null then
    select greatest(0, coalesce(sum(case when (cat.effects ->> 'health_per_action') ~ '^-?[0-9]+$' then (cat.effects ->> 'health_per_action')::int * cs.potency else 0 end), 0)),
           greatest(0, coalesce(sum(case when (cat.effects ->> 'mental_per_action') ~ '^-?[0-9]+$' then (cat.effects ->> 'mental_per_action')::int * cs.potency else 0 end), 0))
      into hp_tick, mn_tick
      from public.world_character_statuses cs join public.world_status_catalog cat using (status_key)
     where cs.owner_id = uid and cs.expires_at > now() and act = any (cat.triggers);
    -- 침식 위험(55) 이상이면 행동마다 정신 1을 더 잃는다
    mn_tick := mn_tick + case when c.erosion >= 55 then 1 else 0 end;
  end if;
  if er > 0 then er := floor(er * greatest(0, 1 + public.world_erosion_pct_self() / 100.0) + random())::int; end if;
  if k in ('combat', 'battle_lost') and won and random() < 0.22 then
    rare := case when p ->> 'region_id' = 'sealed_abyss' then 'spirit_core' else case coalesce(p ->> 'mechanic', '')
      when '독성' then 'venom_gland' when 'toxic' then 'venom_gland' when '영체' then 'ghost_ash' when 'spectral' then 'ghost_ash'
      when '수계' then 'drowned_scale' when 'tide' then 'drowned_scale' when '장갑' then 'monster_core' when 'armored' then 'monster_core'
      when '비행' then 'sky_feather' when 'aerial' then 'sky_feather' when '반사' then 'mirror_shard' when 'reflect' then 'mirror_shard'
      when '결계' then 'ward_fragment' when 'warded' then 'ward_fragment' when '매복' then 'shadow_fang' when 'ambush' then 'shadow_fang'
      else 'monster_core' end end;
  end if;
  if hp_tick = 0 and mn_tick = 0 and tok = 0 and xp_e = 0 and award = 0 and sk is null and (rep = 0 or c.major_faction_id is null)
     and er <= 0 and er_x = 0 and rare is null then return new; end if;

  cx := c.combat_xp + case when k = 'combat' then xp_e else 0 end;
  gx := c.gathering_xp + case when k = 'gather' then xp_e else 0 end;
  crx := c.crafting_xp + case when k = 'craft' then xp_e else 0 end;
  ix := c.investigation_xp + case when k in ('explore', 'story', 'faction') then xp_e else 0 end;
  nl := c.level; nx := c.experience;
  if award > 0 then
    gx := least(500000, gx + case when k = 'gather' then award else 0 end);
    crx := least(600000, crx + case when k in ('craft', 'craft_refine') then award else 0 end);
    ix := least(500000, ix + case when k = 'explore' then award else 0 end);
    nx := case when nl >= 30 then 0 else nx + award end;
    if nl < 30 then
      while nl < 30 and nx >= public.world_xp_need(nl) loop nx := nx - public.world_xp_need(nl); nl := nl + 1; gained := gained + 1; end loop;
    else nx := 0; end if;
    if nl >= 30 then nx := 0; end if;
  end if;
  sp := case when sk is not null then public.world_skill_add(c.skill_progress, sk, sk_xp, case when k = 'combat' then p -> 'acts' end) else c.skill_progress end;
  hp := c.health; mn := c.mental; dn := c.downed_at;
  if hp_tick > 0 or mn_tick > 0 then
    hp := greatest(0, c.health - hp_tick); mn := greatest(0, c.mental - mn_tick);
    dn := case when c.health - hp_tick <= 0 then coalesce(c.downed_at, now()) else c.downed_at end;
  end if;
  if er > 0 then mn := greatest(0, mn - case when won then 0 else 1 end); end if;
  ero := case when er > 0 or er_x > 0 then least(100, c.erosion + greatest(er, 0) + er_x) else c.erosion end;
  if award > 0 then hp := least(100, hp + gained * 10); mn := least(100, mn + gained * 5); end if;

  update public.world_characters set
    health = hp, mental = mn, downed_at = dn,
    mount_tokens = least(9999, mount_tokens + tok),
    combat_xp = cx, gathering_xp = gx, crafting_xp = crx, investigation_xp = ix,
    level = least(30, nl), experience = nx,
    stat_points = case when gained > 0 then least(87, stat_points + gained * 3) else stat_points end,
    spiritual_power = case when gained > 0 then least(100, spiritual_power + gained * 5) else spiritual_power end,
    skill_progress = sp,
    faction_reputation = case when rep > 0 and major_faction_id is not null then least(5000, greatest(-1000, coalesce(faction_reputation, 0) + rep)) else faction_reputation end,
    erosion = ero,
    erosion_stage = case when er > 0 or er_x > 0 then case when ero >= 80 then 4 when ero >= 55 then 3 when ero >= 30 then 2 when ero >= 10 then 1 else 0 end else erosion_stage end,
    inventory = case when rare is not null then jsonb_set(coalesce(inventory, '{}'::jsonb), array[rare], to_jsonb(coalesce((inventory ->> rare)::int, 0) + 1), true) else inventory end,
    updated_at = now()
  where owner_id = uid;
  if rare is not null then
    insert into public.world_events(actor_id, actor_name, event_type, content, payload)
    values (uid, coalesce(c.character_name, '조사원'), 'loot', '희귀 전리품 획득: ' || rare || ' ×1', jsonb_build_object('item', rare, 'qty', 1, 'source', 'monster_rare_drop'));
  end if;
  return new;
end $f$;
alter function public.world_event_char_apply() owner to fn_owner_field;
set role fn_owner_field;
revoke all on function public.world_event_char_apply() from public, anon, authenticated;
reset role;

-- 이름 순으로 가장 먼저 돈다(칭호 판정·상태 굴림 trg_world_activity_status_roll보다 앞): 상태 피해는 이번 행동의 새 상태가 붙기 전 기준 그대로
drop trigger if exists trg_world_award_mount_tokens on public.world_events;
drop trigger if exists trg_world_event_progress on public.world_events;
drop trigger if exists trg_world_specialized_skill_xp on public.world_events;
drop trigger if exists world_event_progression_award on public.world_events;
drop trigger if exists world_major_faction_reputation_trigger on public.world_events;
drop trigger if exists trg_world_aa_event_char on public.world_events;
create trigger trg_world_aa_event_char after insert on public.world_events for each row execute function public.world_event_char_apply();

-- 칭호 판정·상태 굴림만 남긴다(행동마다 상태 피해는 world_event_char_apply로)
create or replace function public.world_apply_activity_status()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare activity_key text;
begin
 activity_key:=case when new.event_type='combat' then 'combat' when new.event_type in ('explore','regional_explore') then 'explore' when new.event_type in ('gather','gathering') then 'gather' when new.event_type in ('craft','crafting') then 'craft' when new.event_type in ('investigation','investigate','case') then 'investigation' when new.event_type in ('training','train') then 'training' when new.event_type in ('travel','move') and coalesce(new.payload,'{}'::jsonb) ? 'travel_history_id' then 'travel' when new.event_type='rest' then 'rest' when new.event_type='rescue' then 'rescue' when new.event_type='story' then 'story' else null end;
 if new.actor_id is null then return new; end if;
 perform set_config('request.jwt.claim.sub',new.actor_id::text,true);
 perform public.world_title_award_check(new.actor_id,new.event_type);
 if activity_key is null then return new; end if;
 delete from public.world_character_statuses where owner_id=new.actor_id and expires_at<=now() and status_key<>'yohwa';
 perform public.world_status_roll(activity_key,coalesce(new.payload,'{}'::jsonb)||jsonb_build_object('event_type',new.event_type,'event_id',new.id));
 return new;
end $function$;

-- 탐색: 캐릭터 갱신을 한 번으로
do $$ declare d text; a text; n int; i0 int; i1 int;
begin
  d := pg_get_functiondef('public.world_field_search()'::regprocedure);
  if position('e_add' in d) = 0 then
    a := 'free_st boolean := false; sneak boolean := false;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 탐색 선언(%)', n; end if;
    d := replace(d, a, a || E'\n  d_ixp int := 0; d_mn int := 0; d_sp int := 0; e_add int := 0;');
    a := E'UPDATE public.world_characters SET investigation_xp = investigation_xp + 8, investigation_rank = public.world_skill_rank(investigation_xp + 8, ''investigation'') WHERE owner_id = uid;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 실마리(%)', n; end if;
    d := replace(d, a, 'd_ixp := 8;');
    a := E'UPDATE public.world_characters SET investigation_xp = investigation_xp + 15, investigation_rank = public.world_skill_rank(investigation_xp + 15, ''investigation'') WHERE owner_id = uid;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 단서(%)', n; end if;
    d := replace(d, a, 'd_ixp := 15;');
    a := E'      UPDATE public.world_characters SET health = greatest(1, health - hurt), updated_at = now() WHERE owner_id = uid;\n';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 함정(%)', n; end if;
    d := replace(d, a, '');
    a := 'UPDATE public.world_characters SET mental = least(100, mental + 6) WHERE owner_id = uid;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 길조 정신(%)', n; end if;
    d := replace(d, a, 'd_mn := 6;');
    a := 'UPDATE public.world_characters SET spiritual_power = least(100, spiritual_power + 6) WHERE owner_id = uid;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 길조 영력(%)', n; end if;
    d := replace(d, a, 'd_sp := 6;');
    a := 'UPDATE public.world_characters SET inventory = inv, gil = gil + gil_gain, experience = experience + xp, updated_at = now() WHERE owner_id = uid;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 마무리 갱신(%)', n; end if;
    d := replace(d, a, E'-- 침식: 위험한 곳·삼경·어두운 곳에서 쌓이고 보정(world_status_effect_total erosion_pct)을 곱한다. 소수는 확률로 올림\n'
      || E'  e_add := floor((CASE WHEN r.danger_level >= 5 THEN 2 WHEN r.danger_level >= 3 THEN 1 ELSE 0.5 END\n'
      || E'      + CASE WHEN public.world_time_phase(now()) = ''night'' THEN 0.5 ELSE 0 END\n'
      || E'      + CASE WHEN r.region_type IN (''sealed_shrine'', ''ruined_temple'', ''burial_ground'', ''underground'', ''abyss'', ''rift'', ''lost_city'', ''underwater_ruins'', ''haunted_garden'', ''blood_forest'') THEN 0.5 ELSE 0 END)\n'
      || E'    * greatest(0, 1 + public.world_status_effect_total(''erosion_pct'') / 100.0) + random())::int;\n'
      || E'  UPDATE public.world_characters SET inventory = inv, gil = gil + gil_gain, experience = experience + xp,\n'
      || E'    investigation_xp = investigation_xp + d_ixp,\n'
      || E'    health = CASE WHEN coalesce(hurt, 0) > 0 THEN greatest(1, health - hurt) ELSE health END,\n'
      || E'    mental = CASE WHEN d_mn > 0 THEN least(100, mental + d_mn) ELSE mental END,\n'
      || E'    spiritual_power = CASE WHEN d_sp > 0 THEN least(100, spiritual_power + d_sp) ELSE spiritual_power END,\n'
      || E'    erosion = greatest(0, least(100, erosion + e_add)),\n'
      || E'    erosion_stage = CASE WHEN greatest(0, least(100, erosion + e_add)) >= 80 THEN 4 WHEN greatest(0, least(100, erosion + e_add)) >= 55 THEN 3\n'
      || E'      WHEN greatest(0, least(100, erosion + e_add)) >= 30 THEN 2 WHEN greatest(0, least(100, erosion + e_add)) >= 10 THEN 1 ELSE 0 END,\n'
      || E'    updated_at = now() WHERE owner_id = uid;');
    -- 탐색 기록 뒤의 침식 두 번 갱신(옛 +2 되돌리기 포함)을 지운다
    i0 := position(E'  -- 기존 탐사 트리거는 탐사마다 침식 2를 더한다.' in d);
    i1 := position(E'  RETURN jsonb_build_object(''ok'', true, ''outcome'', outcome' in d);
    if i0 = 0 or i1 = 0 or i1 < i0 then raise exception '고칠 자리 없음: 탐색 침식(% %)', i0, i1; end if;
    d := left(d, i0 - 1) || E'\n' || substr(d, i1);
    if (length(d) - length(replace(d, 'UPDATE public.world_characters', ''))) / length('UPDATE public.world_characters') <> 1 then
      raise exception '탐색 캐릭터 갱신이 하나가 아닙니다'; end if;
    execute d;
  end if;
end $$;

-- 다 찬 의뢰·소속 임무는 다시 쓰지 않는다
do $$ declare d text; a text; n int;
begin
  d := pg_get_functiondef('public.world_track_commissions()'::regprocedure);
  if position('progress < need' in d) = 0 then
    a := 'claimed_at IS NULL';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 3 then raise exception '고칠 자리 없음: 의뢰(%)', n; end if;
    execute replace(d, a, 'claimed_at IS NULL AND progress < need');
  end if;
  d := pg_get_functiondef('public.world_track_faction_missions()'::regprocedure);
  if position('progress < m.target_count' in d) = 0 then
    a := 'WHERE public.world_faction_mission_progress.claimed=false;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 소속 임무(%)', n; end if;
    execute replace(d, a, 'WHERE public.world_faction_mission_progress.claimed=false AND public.world_faction_mission_progress.progress < m.target_count;');
  end if;
end $$;

-- 탐색력 1 회복 15분(900초): 화면·상태판(world_stamina_now)과 같은 기준
do $$ declare d text; n int;
begin
  d := pg_get_functiondef('public.world_stamina_change(uuid,integer)'::regprocedure);
  if position('360' in d) > 0 then
    n := (length(d) - length(replace(d, '360', ''))) / 3; if n <> 4 then raise exception '고칠 자리 없음: 탐색력(%)', n; end if;
    execute replace(d, '360', '900');
  end if;
end $$;

insert into public.world_patch_notes(note_id, title, body)
select '6.3.0', '서버 부담 정리 · 탐색력 회복 15분 바로잡기', $N$## 6.3.0 · 서버 부담 정리 · 탐색력 회복 15분 바로잡기

### 서버 부담 정리
행동 하나를 할 때마다 서버가 캐릭터 기록을 여러 번 나눠 고치던 것을 **한 번에 고치도록** 합쳤습니다. 받는 경험치·숙련·기술 경험·노정패·평판·침식·전리품은 그대로입니다. 서버가 덜 바빠져 행동이 조금 빨라지고, 채팅·알림 실시간도 덜 밀립니다.

운영 서버에서 같은 캐릭터 10명·같은 조건으로 바꾸기 전과 뒤를 재 본 값입니다(되돌리는 시험이라 실제 기록은 남지 않음). 앞은 캐릭터 기록을 고치는 횟수, 뒤는 쌓이는 변경 기록 크기입니다.
- **탐색 1번**: 9.7번 → **3번** · 21.3KB → **7.7KB** (−64%)
- **토벌 승리 1번**: 6.3번 → **1번** · 13.4KB → **3.5KB** (−74%)
- **채집 1번**: 4.6번 → **1번** · 9.7KB → **2.7KB** (−72%)
- **제작 1번**: 3.4번 → **1번** · 7.4KB → **2.7KB** (−64%)
- 이미 다 채운 상시 의뢰·소속 임무는 진행 기록을 다시 쓰지 않습니다.
- 같은 행동을 옛 방식과 새 방식으로 각각 돌려 결과를 맞춰 봤습니다(144가지). 레벨·경험치·체력·숙련·기술 경험·평판·전·탐색 결과가 모두 같았고, 확률로 정해지는 몫(침식 소수 올림·노정패·희귀 전리품)만 굴림 순서가 바뀌었습니다.
- 탐색으로 쌓인 침식이 이제 그 탐색의 「침식 위험(55) 이상이면 행동마다 정신 −1」 판정에 바로 들어갑니다(전에는 다음 행동부터).

### 탐색력 회복 15분 바로잡기
- 6.0.0에서 탐색력 1 회복을 **15분**으로 바꿨는데, 탐색력을 쓰는 순간의 계산만 옛 **6분**으로 남아 있었습니다. 그래서 탐색을 하면 회복이 화면에 보이는 것보다 빨리 차오르곤 했습니다. 이제 화면과 같이 15분입니다.
$N$
where not exists (select 1 from public.world_patch_notes where note_id = '6.3.0');

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261031050000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
