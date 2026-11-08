create or replace function public.world_task_row(p_uid uuid, p_task jsonb, p_since timestamptz, p_loc text, p_live boolean)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare n int; it jsonb := case when jsonb_typeof(p_task -> 'items') = 'array' then p_task -> 'items' else '[]'::jsonb end;
begin
  n := case when not p_live then 0
            when p_task ->> 't' = 'travel' and p_task ? 'r' and exists (select 1 from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(p_task -> 'r')) and m.region_name = p_loc) then (p_task ->> 'n')::int
            else least((p_task ->> 'n')::int, public.world_quest_task_count(p_uid, p_task, p_since)) end;
  return jsonb_build_object('label', public.world_quest_task_label(p_task), 'cur', n, 'n', (p_task ->> 'n')::int, 't', p_task ->> 't',
    'regions', coalesce(p_task -> 'r', case when p_task ->> 't' = 'win' and p_task ? 'm' then (select jsonb_agg(distinct rm.region_id) from public.world_region_monsters rm where rm.monster_id in (select jsonb_array_elements_text(p_task -> 'm'))) end, '[]'::jsonb),
    'items', p_task -> 'items',
    'mn', case when p_task ->> 't' = 'win' and p_task ? 'm' then (select jsonb_agg(rm.monster_name order by rm.monster_name) from public.world_region_monsters rm where rm.monster_id in (select jsonb_array_elements_text(p_task -> 'm'))) end,
    'unit', case when p_task ->> 't' = 'gather' then case when jsonb_array_length(it) > 0 then '개' else '회' end when p_task ->> 't' = 'craft' and jsonb_array_length(it) > 0 then '개' else '' end);
end
$function$;

create or replace function public.world_quest_board()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; q record; st jsonb; act jsonb := '[]'::jsonb; avail jsonb;
  here_id text; clues jsonb; ndone int; ntotal int; fac jsonb; dn text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select region_id into here_id from public.world_map_regions where region_name = c.location limit 1;
  dn := public.world_quest_done_ids(uid);
  select count(*), count(*) filter (where x.quest_id = any(dn)) into ntotal, ndone
  from public.world_quests x
  where x.active and (x.job_key is null or x.job_key = c.job_key) and (x.faction_key is null or x.faction_key = c.faction_key);
  for q in select * from (select x.quest_id, x.kind, x.cat, x.title, x.summary, x.region_id, m.region_name, x.min_level, x.after, x.chapter_id, g.step gstep, g.owner_id has_prog,
             coalesce((select count(*) from public.world_quest_steps s where s.quest_id = x.quest_id), 0)::int nst,
             (x.kind = 'main') ismain, x.sort, x.quest_id = any(dn) done
      from public.world_quests x
      left join public.world_quest_progress g on g.quest_id = x.quest_id and g.owner_id = uid
      left join public.world_map_regions m on m.region_id = x.region_id
      where x.active
        and (x.job_key is null or x.job_key = c.job_key)
        and (x.faction_key is null or x.faction_key = c.faction_key)) b where not b.done and b.has_prog is not null and coalesce(b.gstep, 0) >= 1
    order by b.ismain desc, b.min_level, b.sort, b.quest_id loop
    if q.kind = 'main' and coalesce(q.gstep, 0) >= q.nst then
      select jsonb_build_object(
        'found', count(*) filter (where exists (
          select 1 from public.world_case_progress p
          where p.owner_id = uid and p.case_id = k.chapter_id
            and p.clues @> jsonb_build_array(jsonb_build_object('id', k.clue_id))
        )),
        'total', count(*),
        'regions', jsonb_agg(distinct k.region_id),
        'region_names', jsonb_agg(distinct (select region_name from public.world_map_regions where region_id = k.region_id))
      )
      into clues
      from public.world_story_clues k
      where k.chapter_id = q.chapter_id;
      act := act || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'clues', 'clues', clues,
        'step', q.nst, 'steps', q.nst);
    else
      st := public.world_quest_step_state(uid, q.quest_id);
      act := act || (jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'step') || coalesce(st, '{}'::jsonb) || jsonb_build_object('title', q.title, 'step_title', st ->> 'title'));
    end if;
  end loop;
  select coalesce(jsonb_agg(
    case when jsonb_typeof(a.a1) = 'array' and jsonb_array_length(a.a1) > 0 then
      jsonb_build_object('quest_id', a.quest_id, 'kind', a.kind, 'cat', a.cat, 'title', a.title, 'summary', a.summary,
        'region_id', a.a1 ->> 0,
        'region_name', (select string_agg(m.region_name, '·' order by m.region_name) from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(a.a1))),
        'min_level', a.min_level, 'locked', not a.ok, 'here', coalesce(a.a1 ? here_id, false), 'steps', a.nst)
    else
      jsonb_build_object('quest_id', a.quest_id, 'kind', a.kind, 'cat', a.cat, 'title', a.title, 'summary', a.summary,
        'region_id', a.region_id, 'region_name', a.region_name, 'min_level', a.min_level, 'locked', not a.ok, 'here', a.region_id = here_id, 'steps', a.nst)
    end order by a.ismain desc, a.min_level, a.sort, a.quest_id), '[]'::jsonb)
  into avail
  from (
    select b.*, (c.level >= b.min_level and b.after <@ dn) ok,
      (select s.need -> 'at' from public.world_quest_steps s where s.quest_id = b.quest_id and s.step = 1) a1
    from (select x.quest_id, x.kind, x.cat, x.title, x.summary, x.region_id, m.region_name, x.min_level, x.after, x.chapter_id, g.step gstep, g.owner_id has_prog,
             coalesce((select count(*) from public.world_quest_steps s where s.quest_id = x.quest_id), 0)::int nst,
             (x.kind = 'main') ismain, x.sort, x.quest_id = any(dn) done
      from public.world_quests x
      left join public.world_quest_progress g on g.quest_id = x.quest_id and g.owner_id = uid
      left join public.world_map_regions m on m.region_id = x.region_id
      where x.active
        and (x.job_key is null or x.job_key = c.job_key)
        and (x.faction_key is null or x.faction_key = c.faction_key)) b
    where not b.done and not (b.has_prog is not null and coalesce(b.gstep, 0) >= 1)
  ) a
  where a.ok or (a.kind = 'main' and a.after <@ dn);
  if c.major_faction_id is not null and exists (
    select 1 from public.world_faction_progress p
    where p.owner_id = uid and p.faction_id = c.major_faction_id and not p.rejoin_pending
  ) then
    fac := public.world_faction_current(uid, false);
    if fac is not null then
      fac := fac || jsonb_build_object('faction_id', c.major_faction_id,
        'regions', (select coalesce(jsonb_agg(distinct x), '[]'::jsonb)
          from public.world_faction_scenes s,
          lateral (
            select jsonb_array_elements_text(t -> 'r') x
            from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t
            union
            select jsonb_array_elements_text(coalesce(s.need -> 'at', '[]'::jsonb))
          ) z
          where s.scene_key = fac ->> 'scene_key'));
    end if;
  end if;
  return jsonb_build_object('active', act, 'available', avail, 'faction', fac, 'done', ndone, 'total', ntotal, 'here_id', here_id, 'level', c.level);
end
$function$;

update public.world_mount_catalog set speed_multiplier = case when mount_id = 'fm_river_alliance' then 2.5 else 2.4 end, passenger_capacity = 4, fare_tokens = 2
 where acquire_method = 'faction' and mount_id like 'fm\_%';
update public.world_mount_catalog set unlock_faction = null, unlock_reputation = 0, speed_multiplier = 2.3 where mount_id = 'moon_elk';

update public.world_map_regions set has_stable = true where region_id in ('bone_market', 'hidden_bazaar', 'iron_monastery');
insert into public.world_mount_catalog (mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, unlock_faction, unlock_region, unlock_item, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method)
values
('lantern_coach', '청사 쌍두마차', 2.3, 20, 0, null, 'hq_yard', 'spirit_core', 12000, '청사초롱을 앞뒤로 매단 정청의 쌍두마차. 넷이 마주 앉아 밤길을 간다.', '영물', 4, 2, false, 'stable'),
('redmoon_camel', '적월 쌍봉낙타', 2.3, 20, 0, null, 'bone_market', 'spirit_core', 12000, '붉은 달이 뜨면 장터를 떠나는 큰 낙타. 두 혹 사이 안장에 넷이 앉는다.', '영물', 4, 2, false, 'stable'),
('ink_cart', '먹빛 쌍마 수레', 2.3, 20, 0, null, 'hidden_bazaar', 'spirit_core', 12000, '십삼문 뒷길을 아는 검은 말 두 마리가 끄는 덮개 수레. 넷이 숨어 탄다.', '영물', 4, 2, false, 'stable'),
('snow_sled', '설원 개썰매', 2.3, 20, 0, null, 'iron_monastery', 'spirit_core', 12000, '철벽 고찰의 썰매개 여섯이 끄는 큰 썰매. 눈길에서도 넷을 싣고 달린다.', '영물', 4, 2, false, 'stable'),
('buffalo_cart', '물소 달구지', 2.3, 20, 0, null, 'river_ferry', 'spirit_core', 12000, '수향 논두렁을 오가는 물소가 끄는 달구지. 물길이 끊긴 곳에서도 넷을 태운다.', '영물', 4, 2, false, 'stable'),
('ember_bison', '잔불 들소 수레', 2.3, 20, 0, null, 'ember_village', 'spirit_core', 12000, '뿔 끝에 불티가 이는 들소가 끄는 수레. 재 언덕을 넷이 함께 넘는다.', '영물', 4, 2, false, 'stable')
on conflict (mount_id) do nothing;

create or replace function public.world_rate_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object('gather_s', 12, 'fish_s', 15, 'search_ms', 900, 'battle_ms', 1000, 'raid_ms', 1000)
$function$;
revoke all on function public.world_rate_rules() from public, anon, authenticated;
grant execute on function public.world_rate_rules() to service_role, fn_owner_19149;
do $g$ declare r text; begin
  for r in select distinct a.grantee::regrole::text from pg_proc p, aclexplode(p.proacl) a
    where p.oid = 'public.world_rate_check(text,uuid,uuid)'::regprocedure and a.privilege_type = 'EXECUTE' and a.grantee <> 0
      and a.grantee::regrole::text not in ('anon', 'authenticated') loop
    execute format('grant execute on function public.world_rate_rules() to %I', r);
  end loop;
end $g$;

create or replace function public.world_rate_check(p_kind text, p_uid uuid, p_ref uuid default null::uuid)
 returns void
 language plpgsql
 stable
 set search_path to 'pg_catalog', 'public'
as $function$
begin
  if p_uid is null then return; end if;
  if p_kind = 'gather' and exists (select 1 from public.world_events where actor_id = p_uid and event_type = 'gather' and created_at > now() - make_interval(secs => (public.world_rate_rules()->>'gather_s')::int)) then
    raise exception '채집은 12초마다 가능합니다. 잠시 후 다시 시도하세요.' using hint = 'rate';
  elsif p_kind = 'fish' and exists (select 1 from public.world_events where actor_id = p_uid and event_type = 'fish' and created_at > now() - make_interval(secs => (public.world_rate_rules()->>'fish_s')::int)) then
    raise exception '찌를 다시 던지려면 조금 더 기다리세요.' using hint = 'rate';
  elsif p_kind = 'search' and exists (select 1 from public.world_events where actor_id = p_uid and event_type = 'explore' and created_at > now() - (public.world_rate_rules()->>'search_ms')::int * interval '1 millisecond') then
    raise exception '숨을 고르는 중입니다. 잠시 후 다시 탐색하세요.' using hint = 'rate';
  elsif p_kind = 'battle' and exists (select 1 from public.world_active_encounters where owner_id = p_uid and last_action_at > now() - (public.world_rate_rules()->>'battle_ms')::int * interval '1 millisecond') then
    raise exception '전투 행동 간격이 너무 짧습니다. 잠시 후 다시 시도하세요.' using hint = 'rate';
  elsif p_kind = 'raid' and exists (select 1 from public.world_raid_members where raid_id = p_ref and owner_id = p_uid and last_action_at > now() - (public.world_rate_rules()->>'raid_ms')::int * interval '1 millisecond') then
    raise exception '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.' using hint = 'rate';
  end if;
end $function$;

create or replace function public.world_guard_repeat_farming()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
DECLARE
  cooldown_seconds integer;
  last_action timestamptz;
BEGIN
  IF new.actor_id IS NULL THEN RETURN new; END IF;
  cooldown_seconds := CASE
    WHEN new.event_type='gather' THEN (public.world_rate_rules()->>'gather_s')::int
    WHEN new.event_type IN ('combat','encounter') THEN 1
    ELSE 0
  END;
  IF cooldown_seconds=0 THEN RETURN new; END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(new.actor_id::text || ':' || new.event_type,0));
  SELECT max(created_at) INTO last_action
  FROM public.world_events
  WHERE actor_id=new.actor_id AND event_type=new.event_type;

  IF last_action IS NOT NULL AND last_action > now() - make_interval(secs=>cooldown_seconds) THEN
    RAISE EXCEPTION USING errcode='P0001', hint='rate',
      message=CASE WHEN new.event_type='gather'
        THEN '채집은 12초마다 가능합니다. 잠시 후 다시 시도하세요.'
        ELSE '전투 행동 간격이 너무 짧습니다. 잠시 후 다시 시도하세요.' END;
  END IF;
  RETURN new;
END;
$function$;

do $r$
declare src text := pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure);
  old text := $o$RAISE EXCEPTION '진행 중인 전투가 없습니다.';$o$;
begin
  if (length(src) - length(replace(src, old, ''))) / length(old) <> 1 then raise exception 'world_battle_action: 바꿀 곳이 하나가 아님'; end if;
  execute replace(src, old, $n$RAISE EXCEPTION '진행 중인 전투가 없습니다.' USING HINT = 'no_battle';$n$);
end $r$;

create or replace function public.world_idle_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object('rate', jsonb_build_object('training', 12, 'research', 10, 'maintenance', 8, 'rest', 3), 'gain', 12, 'eff', 0.35)
$function$;
create or replace function public.world_rescue_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object('pct', 15, 'min', 30, 'per_lv', 80, 'per_lv_low', 40, 'low_lv', 15, 'xp_pct', 5)
$function$;
revoke all on function public.world_idle_rules() from public, anon, authenticated;
revoke all on function public.world_rescue_rules() from public, anon, authenticated;
grant execute on function public.world_idle_rules() to service_role, fn_owner_19181;
grant execute on function public.world_rescue_rules() to service_role, fn_owner_field;

do $r$
declare src text := pg_get_functiondef('public.world_claim_idle_activity'::regproc);
  o1 text := $o$floor(v_hours*12*0.35)::integer$o$;
  n1 text := $n$floor(v_hours*(public.world_idle_rules()->>'gain')::numeric*(public.world_idle_rules()->>'eff')::numeric)::integer$n$;
  o2 text := $o$(case v.activity_type when 'training' then 12 when 'research' then 10 when 'maintenance' then 8 else 3 end)*0.35$o$;
  n2 text := $n$coalesce((public.world_idle_rules()->'rate'->>v.activity_type)::numeric, (public.world_idle_rules()->'rate'->>'rest')::numeric)*(public.world_idle_rules()->>'eff')::numeric$n$;
begin
  if (length(src) - length(replace(src, o1, ''))) / length(o1) <> 2 then raise exception 'world_claim_idle_activity: o1이 두 곳이 아님'; end if;
  if (length(src) - length(replace(src, o2, ''))) / length(o2) <> 1 then raise exception 'world_claim_idle_activity: o2가 한 곳이 아님'; end if;
  execute replace(replace(src, o1, n1), o2, n2);
end $r$;

do $r$
declare src text := pg_get_functiondef('public.world_call_rescue'::regproc);
  o1 text := $o$least(c.level * case when c.level < 15 then 40 else 80 end, greatest(30, c.gil * 15 / 100))$o$;
  n1 text := $n$least(c.level * case when c.level < (public.world_rescue_rules()->>'low_lv')::int then (public.world_rescue_rules()->>'per_lv_low')::int else (public.world_rescue_rules()->>'per_lv')::int end, greatest((public.world_rescue_rules()->>'min')::int, c.gil * (public.world_rescue_rules()->>'pct')::int / 100))$n$;
  o2 text := $o$round(public.world_xp_need(c.level) * 0.05)$o$;
  n2 text := $n$round(public.world_xp_need(c.level) * (public.world_rescue_rules()->>'xp_pct')::numeric / 100)$n$;
begin
  if (length(src) - length(replace(src, o1, ''))) / length(o1) <> 1 then raise exception 'world_call_rescue: o1이 한 곳이 아님'; end if;
  if (length(src) - length(replace(src, o2, ''))) / length(o2) <> 1 then raise exception 'world_call_rescue: o2가 한 곳이 아님'; end if;
  execute replace(replace(src, o1, n1), o2, n2);
end $r$;

update public.world_patch_notes set body = body || E'\n\n## 1.1.0d\n- 현장 퀘스트 칸이 할 일과 상관없는 행동 뒤에도 매번 다시 읽히던 것을 줄였습니다. 보이는 내용은 같습니다.\n- 세력 비고 탈것 일곱 가지를 모두 같게 맞췄습니다. 속도 ×2.4(수향연맹 화방선 ×2.5), 넷이 함께 타고, 노정패 운임은 구간마다 2개입니다.\n- 월광록은 천명원 소속이 아니어도 무극 관성대 마구간에서 들일 수 있게 바꾸고, 속도를 ×2.3으로 낮췄습니다. 이미 가진 월광록도 같이 바뀝니다.\n- 다른 여섯 세력 거점 마구간에도 월광록과 같은 탈것을 하나씩 들였습니다(×2.3, 넷이 함께 탐, 레벨 20·응축 영핵·12,000전, 소속 조건 없음): 야행국 본부 정청 청사 쌍두마차 · 백골 장터 적월 쌍봉낙타 · 십삼문 암시장 먹빛 쌍마 수레 · 철벽 고찰 설원 개썰매 · 구름나루 물소 달구지 · 잔불촌 잔불 들소 수레. 백골 장터·십삼문 암시장·철벽 고찰에는 마구간을 새로 열었습니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261108180000' where key = 'db_version';
update public.world_patch_notes set body = body || E'\n- 넓은 화면에서 현장 머리 그림 사이에 납작한 긴 선이 생기던 것을 고쳐, 그림이 끊김 없이 이어집니다.\n- 현장 머리 그림의 색을 지형이 아니라 그곳을 다스리는 세력 색으로 맞췄습니다(흑조 균열·주혈 광산이 흑련회 보라로 보이던 것 등).'
 where note_id = '1.1.0';
