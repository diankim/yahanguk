do $d$
declare j jsonb := public.world_domain_rules() || $J${
  "deungdo": {"name": "등도 옛터", "open_quest": "mdq_3", "no_shadow": true, "rare": "lamp_wick_core",
    "regions": {"deungdo_landing": "mdq_3", "dark_yamen": "mdq_3", "martial_row": "mdq_4", "red_shrine_lane": "mdq_6", "old_ferry_market": "mdq_8",
                "lamp_rest": "mdq_8", "first_observatory": "mdq_10", "ash_palace": "mdq_12", "pact_court": "mdq_14"},
    "night": {"deungdo_landing": "mdq_4", "dark_yamen": "mdq_4", "martial_row": "mdq_6", "red_shrine_lane": "mdq_8", "old_ferry_market": "mdq_10",
              "lamp_rest": "mdq_10", "first_observatory": "mdq_11", "ash_palace": "mdq_13", "pact_court": "mdq_16"},
    "fx": {"name": "백야", "white_night": true, "no_rescue": true, "guard": ["under_lamp"],
           "effects": {"mental_loss_pct": 15, "incoming_damage_pct": 5, "encounter_pct": 5, "wn_sneak": 15, "wn_quiet": 10, "wn_eva": 3},
           "recall": {"per_day": 1, "hp": 1, "status": "faded_name"}}},
  "jeongni": {"name": "정리소", "open_quest": "mdq_11", "no_shadow": true, "rare": "lamp_wick_core"}
}$J$::jsonb;
begin
  execute format('create or replace function public.world_domain_rules() returns jsonb language sql immutable as %L', format('select %L::jsonb', j::text));
end $d$;
grant execute on function public.world_domain_rules() to anon, authenticated;

create or replace function public.world_weak_safe_rules() returns jsonb
language sql immutable as $$ select '["banyo_village", "mukchang_ferry", "deungdo_landing", "lamp_rest"]'::jsonb $$;

create or replace function public.world_region_open(p_uid uuid, p_region text) returns boolean
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
#variable_conflict use_column
declare t text; q text;
begin
  select r.territory_id into t from public.world_map_regions r where r.region_id = p_region;
  if t is null then return true; end if;
  if not public.world_domain_open(p_uid, t) then return false; end if;
  q := public.world_domain_rules() -> t -> 'regions' ->> p_region;
  if q is null or exists (select 1 from public.world_staff s where s.owner_id = p_uid) then return true; end if;
  return q = any (public.world_quest_done_ids(p_uid));
end $$;
revoke all on function public.world_region_open(uuid, text) from public, anon, authenticated;

create or replace function public.world_region_shut(p_uid uuid) returns text[]
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
begin
  return coalesce((select array_agg(k) from jsonb_each(public.world_domain_rules()) d, jsonb_object_keys(coalesce(d.value -> 'regions', '{}'::jsonb)) k
                    where not public.world_region_open(p_uid, k)), '{}');
end $$;
revoke all on function public.world_region_shut(uuid) from public, anon, authenticated;

create or replace function public.world_deungdo_night(p_uid uuid, p_region text) returns boolean
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare q text;
begin
  q := (select public.world_domain_rules() -> r.territory_id -> 'night' ->> p_region from public.world_map_regions r where r.region_id = p_region);
  if q is null then return false; end if;
  return q = any (public.world_quest_done_ids(p_uid));
end $$;
revoke all on function public.world_deungdo_night(uuid, text) from public, anon, authenticated;

select pg_temp.yh_patch('public.world_domain_fx(uuid)',
  'declare t text; d jsonb; g timestamptz; e int; b jsonb; k int; st jsonb;',
  'declare t text; d jsonb; g timestamptz; e int; b jsonb; k int; st jsonb; rg text;');
select pg_temp.yh_patch('public.world_domain_fx(uuid)',
  'select (public.world_region_at(c.location)).territory_id, coalesce(c.erosion, 0) into t, e from public.world_characters c where c.owner_id = p_uid;',
  'select (public.world_region_at(c.location)).territory_id, (public.world_region_at(c.location)).region_id, coalesce(c.erosion, 0) into t, rg, e from public.world_characters c where c.owner_id = p_uid;');
select pg_temp.yh_patch('public.world_domain_fx(uuid)',
  '  if d is null then return null; end if;
  select max(s.expires_at)',
  '  if d is null then return null; end if;
  if coalesce((d ->> ''white_night'')::boolean, false) and (public.world_weak_safe(rg) or public.world_deungdo_night(p_uid, rg)) then return null; end if;
  select max(s.expires_at)');
select pg_temp.yh_patch('public.world_domain_fx(uuid)',
  '  b := d -> ''blur'';',
  '  if coalesce((d ->> ''white_night'')::boolean, false) and g is not null then d := d || jsonb_build_object(''effects'', ''{}''::jsonb); end if;
  b := d -> ''blur'';');

do $d$
declare f text; o text;
begin
  foreach f in array array['public.world_domain_fx(uuid)', 'public.world_map_snapshot()', 'public.world_travel_route(text)', 'public.world_travel_party_invite_v2(uuid,text)',
    'public.world_travel_party_respond_v2(uuid,boolean)', 'public.world_call_rescue()', 'public.world_sneak_pct(uuid,integer,text)', 'public.world_field_search()',
    'public.world_combat_stats(uuid,jsonb)', 'public.world_bijang_open(text)'] loop
    if to_regprocedure(f) is null then continue; end if;
    o := pg_get_userbyid((select proowner from pg_proc where oid = to_regprocedure(f)));
    if o like 'fn_owner%' then
      execute format('grant execute on function public.world_region_open(uuid, text) to %I', o);
      execute format('grant execute on function public.world_region_shut(uuid) to %I', o);
      execute format('grant execute on function public.world_deungdo_night(uuid, text) to %I', o);
      execute format('grant execute on function public.world_domain_fx(uuid) to %I', o);
    end if;
  end loop;
end $d$;

select pg_temp.yh_patch('public.world_map_snapshot()',
  ' hide := coalesce((select array_agg(x.region_id) from public.world_map_regions x where x.territory_id = any(shut)), ''{}'');',
  ' hide := coalesce((select array_agg(x.region_id) from public.world_map_regions x where x.territory_id = any(shut)), ''{}'') || public.world_region_shut(uid);');
select pg_temp.yh_patch('public.world_map_snapshot()',
  '  where r.active and not (coalesce(r.territory_id, '''') = any(shut));',
  '  where r.active and not (coalesce(r.territory_id, '''') = any(shut)) and not (r.region_id = any(hide));');
select pg_temp.yh_patch('public.world_travel_route(text)',
  'IF dest.region_id IS NULL OR NOT public.world_domain_open(uid, dest.territory_id) THEN',
  'IF dest.region_id IS NULL OR NOT public.world_domain_open(uid, dest.territory_id) OR NOT public.world_region_open(uid, dest.region_id) THEN');
select pg_temp.yh_patch('public.world_travel_party_invite_v2(uuid,text)',
  'IF NOT (public.world_domain_open(uid, r.territory_id) AND public.world_domain_open(p_passenger_id, r.territory_id)) THEN',
  'IF NOT (public.world_domain_open(uid, r.territory_id) AND public.world_domain_open(p_passenger_id, r.territory_id) AND public.world_region_open(uid, r.region_id) AND public.world_region_open(p_passenger_id, r.region_id)) THEN');
select pg_temp.yh_patch('public.world_travel_party_respond_v2(uuid,boolean)',
  'if not (public.world_domain_open(q.leader_id, r.territory_id) and public.world_domain_open(uid, r.territory_id))',
  'if not (public.world_domain_open(q.leader_id, r.territory_id) and public.world_domain_open(uid, r.territory_id) and public.world_region_open(q.leader_id, r.region_id) and public.world_region_open(uid, r.region_id))');
select pg_temp.yh_patch('public.world_bijang_open(text)',
  'and public.world_domain_open(uid, r.territory_id) and exists',
  'and public.world_domain_open(uid, r.territory_id) and public.world_region_open(uid, r.region_id) and exists');

select pg_temp.yh_patch('public.world_sneak_pct(uuid,integer,text)',
  '+ case when c.job_key = ''scout'' then (public.world_agile_rules() ->> ''scout_sneak'')::numeric else 0 end',
  '+ case when c.job_key = ''scout'' then (public.world_agile_rules() ->> ''scout_sneak'')::numeric else 0 end
    + coalesce((public.world_domain_fx(c.owner_id) -> ''effects'' ->> ''wn_sneak'')::numeric, 0)');
select pg_temp.yh_patch('public.world_field_search()',
  'q_mode := least((public.world_agile_rules() ->> ''quiet_cap'')::numeric, v_ag',
  'q_mode := least((public.world_agile_rules() ->> ''quiet_cap'')::numeric + coalesce((public.world_domain_fx(uid) -> ''effects'' ->> ''wn_quiet'')::numeric, 0), v_ag');
select pg_temp.yh_patch('public.world_combat_stats(uuid,jsonb)',
  '+ CASE WHEN c.job_key = ''scout'' THEN (public.world_agile_rules() ->> ''scout_eva'')::numeric ELSE 0 END + g_eva));',
  '+ CASE WHEN c.job_key = ''scout'' THEN (public.world_agile_rules() ->> ''scout_eva'')::numeric ELSE 0 END + g_eva
    + coalesce((public.world_domain_fx(p_owner) -> ''effects'' ->> ''wn_eva'')::numeric, 0)));');

select pg_temp.yh_patch('public.world_call_rescue()',
  '  r := public.world_field_region(c.location);',
  '  r := public.world_field_region(c.location);
  IF coalesce((public.world_domain_fx(uid) ->> ''no_rescue'')::boolean, false) THEN
    RAISE EXCEPTION ''본부 구조대가 오지 못하는 곳입니다. 동료의 구조·회생 부적·「제 이름 외기」로 일어나세요.'' USING HINT = ''no_rescue'';
  END IF;');

insert into public.world_status_catalog(status_key, status_name, polarity, duration_minutes, effects, icon, description)
values ('faded_name', '바랜 이름', 'negative', 60, '{"combat_damage_pct": -10}'::jsonb, 'spark', '스스로 제 이름을 외어 일어났습니다. 이름이 아직 바래 있어 주는 피해가 줄어듭니다.'),
       ('under_lamp', '등불 아래', 'positive', 60, '{}'::jsonb, 'flame', '명등 등롱 불빛이 흰 밤을 밀어냅니다. 등도의 백야 효과를 받지 않습니다.')
on conflict (status_key) do update set status_name = excluded.status_name, polarity = excluded.polarity, duration_minutes = excluded.duration_minutes,
  effects = excluded.effects, icon = excluded.icon, description = excluded.description;

create or replace function public.world_self_recall() returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_map_regions%rowtype; fx jsonb; rc jsonb; used int; st jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found or coalesce(c.is_dead, false) then raise exception '제 이름을 욀 수 없습니다.'; end if;
  if c.downed_at is null and c.health > 0 then raise exception '쓰러진 상태가 아닙니다.'; end if;
  fx := public.world_domain_fx(uid);
  rc := fx -> 'recall';
  if rc is null or not coalesce((fx ->> 'no_rescue')::boolean, false) then raise exception '이곳에서는 본부 구조대를 부를 수 있습니다.'; end if;
  used := (select count(*) from public.world_events e where e.actor_id = uid and e.event_type = 'rescue' and e.payload ->> 'recall' = 'true'
            and e.created_at >= (date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul'));
  if used >= (rc ->> 'per_day')::int then raise exception '제 이름 외기는 하루 %번입니다. 동료의 구조나 회생 부적으로 일어나세요.', (rc ->> 'per_day')::int; end if;
  select * into s from public.world_map_regions x where x.region_id = public.world_safe_near(c.location, c.level) limit 1;
  delete from public.world_active_encounters where owner_id = uid;
  update public.world_characters set health = greatest(1, (rc ->> 'hp')::int), downed_at = null, location = s.region_name, current_exploration_node_id = null,
    travel_destination = null, travel_arrives_at = null, updated_at = now() where owner_id = uid;
  select to_jsonb(sc) into st from public.world_status_catalog sc where sc.status_key = rc ->> 'status';
  if st is not null then
    delete from public.world_character_statuses where owner_id = uid and status_key = rc ->> 'status';
    insert into public.world_character_statuses(owner_id, status_key, intensity, expires_at, metadata)
    values (uid, rc ->> 'status', 1, now() + make_interval(mins => (st ->> 'duration_minutes')::int), '{}'::jsonb);
  end if;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'rescue', c.character_name || '이(가) 제 이름을 외어 ' || s.region_name || '에서 일어났습니다.', jsonb_build_object('self', true, 'recall', true, 'to', s.region_id));
  return jsonb_build_object('ok', true, 'location', s.region_name, 'content', '제 이름을 끝까지 외자 몸이 ' || s.region_name || '에서 다시 일어났습니다. 1시간 동안 「바랜 이름」: 주는 피해 −10%.');
end $$;
revoke all on function public.world_self_recall() from public, anon;
grant execute on function public.world_self_recall() to authenticated;
