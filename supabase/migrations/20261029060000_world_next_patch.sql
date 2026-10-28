-- 다음 대규모 패치(5.0.0) 묶음: 그 패치 때 한 번에 실행하는 파일이다(작은 SQL을 따로따로 돌리지 않는다).
--   ① 이동 중에는 탈것을 바꿀 수 없다(출발한 뒤 다른 탈것으로 갈아타던 것을 막는다)
--   ② 노정 건량 준비(make_travel_ration)의 의무관 전용 조건을 뺀다(원정·이동 보급품으로 쓰이는 곳이 많아 누구나 만들게)
--   ④ 파티 원정 함께 출발: 파티장 제안 → 동료 수락 → 한 트랜잭션에서 모두 출발(출발·귀환 시각이 같다). 2명은 수락해야 출발, 3명 이상은 거절·무응답 빼고 출발
--   ⑤ 지역마다 요괴 2종 더(안전지대 제외 33곳 66종, 이름·갈래·설명만 새로, 능력치·전리품은 그 지역 같은 역할을 따름)
--   ③ 전체 채팅에 쓰러짐을 알린 조사원이 다시 일어나면(구조·본부 구조대·회복품·요화 봉인) 그 소식도 한 줄 남긴다(헛걸음 방지)
--   (화면) 채팅의 구조 알림 줄: 시각이 「21:/00」처럼 세로로 쪼개지던 것을 한 줄로
--   (화면) 환골탈태 서첩 창: 모바일에서 직업·소속 12칸이 한 줄씩 쌓여 「이대로 다시 시작」 단추가 한참 아래로 밀려 안 보이던 것을 두 줄 격자·아래 고정 단추로
--   (화면) 동료 화면 친구·모임: 단추가 이름에서 멀리 떨어져 늘어나던 것을 사람·모임마다 카드로 나누고 단추를 이름 곁에
--   (화면) 조사원 카드의 비무 단추를 귓속말 옆으로 올리고, 못 할 때는 숨기지 않고 까닭을 적는다(안전지대에서 아래로 밀려 안 보이던 것)
--   (화면) 채팅 안내 문구 「하루 50회」 (가방 검색 한글 깨짐은 4.0.0 32번으로 먼저 배포함)

grant fn_owner_18885 to postgres with inherit true, set true;
grant fn_owner_18987 to postgres with inherit true, set true;
grant fn_owner_field to postgres with inherit true, set true;

-- ① ─────────────────────────────────────────
-- world_mount_equip: 이동 중(travel_destination이 남아 있는 동안 — 도착·취소 때 비워진다)에는 거절한다
do $$ declare d text := pg_get_functiondef('public.world_mount_equip(text)'::regprocedure);
  a text := 'IF NOT EXISTS(SELECT 1 FROM public.world_owned_mounts WHERE owner_id=uid AND mount_id=p_mount_id) THEN';
  b text := 'IF c.travel_destination IS NOT NULL THEN RAISE EXCEPTION ''이동 중에는 탈것을 바꿀 수 없습니다. 도착한 뒤에 바꾸세요.''; END IF; ';
begin
  if position('이동 중에는 탈것을 바꿀 수 없습니다' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '탈것 바꾸기 고칠 자리'; end if;
  execute replace(d, a, b || a);
end $$;

-- ② ─────────────────────────────────────────
-- 노정 건량 준비: 직업 조건 없음(재료·도구·지정 장소 품질 보너스는 그대로)
update public.world_crafting_recipes set required_job = null where recipe_id = 'make_travel_ration' and required_job = 'medic';

-- ③ ─────────────────────────────────────────
-- world_notify_downed(world_characters 갱신 트리거): 쓰러짐(health 0)을 알리던 같은 트리거에, downed_at이 비워지며 다시 일어난 경우를 더한다.
-- 다시 일어나는 길(world_rescue_character·world_call_rescue·world_use_item·world_use_recovery_item·world_yohwa_seal)은 모두 downed_at을 비우므로 여기 한 곳에서 잡힌다.
-- 사망(is_dead)은 알리지 않는다. 행동마다 쓰기를 늘리지 않는다(다시 일어날 때 채팅 한 줄뿐).
do $$ declare d text := pg_get_functiondef('public.world_notify_downed()'::regprocedure);
  a text := E' end if;\n return new;\nend';
  b text := E' elsif old.downed_at is not null and new.downed_at is null and new.health > 0 and not coalesce(new.is_dead, false) then\n'
    || E'  insert into public.world_chat_messages(channel_type,sender_id,sender_name,content) values(''global'',new.owner_id,''구조 알림'',\n'
    || E'    new.character_name||'' 조사원이 다시 일어났습니다''||case when new.location is distinct from old.location then ''(''||coalesce(new.location,''안전지대'')||''(으)로 옮겨짐)'' else '''' end||''. 구조하러 가지 않아도 됩니다.'');\n'
    || E' end if;\n return new;\nend';
begin
  if position('다시 일어났습니다' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '쓰러짐 알림 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- ④ ─────────────────────────────────────────
-- 파티 원정 함께 출발: 파티장이 원정지·기간·태세를 제안하고, 같은 곳의 동료가 답하면 서버가 한 번(한 트랜잭션)에 모두 출발시킨다.
-- 같은 트랜잭션 안의 now()는 같으므로 출발·귀환 시각이 정확히 같다(전에는 「함께 가기」 알림을 받은 동료가 따로 출발해 시각이 어긋났다).
-- 2명(파티장 + 1)은 동료가 수락해야만 출발, 3명 이상은 거절·무응답을 빼고 출발, 아무도 수락하지 않으면 출발하지 않는다. 제안은 3분 유효.
create table if not exists public.world_party_exp_offers (
  offer_id uuid primary key default gen_random_uuid(),
  party_id uuid not null, leader_id uuid not null,
  node_id uuid not null, region_id text, location text not null,
  minutes int not null, stance text not null,
  invitees uuid[] not null, responses jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'departed', 'cancelled')),
  created_at timestamptz not null default now(), expires_at timestamptz not null, resolved_at timestamptz, result jsonb);
create index if not exists world_party_exp_offers_party on public.world_party_exp_offers(party_id, status);
alter table public.world_party_exp_offers enable row level security;
revoke all on public.world_party_exp_offers from public, anon, authenticated;
grant select, insert, update on public.world_party_exp_offers to fn_owner_field;
grant select on public.world_parties to fn_owner_field;

-- 이 조사원이 지금 이 원정지로 떠날 수 있는지(아니면 까닭). 실제 출발은 world_expedition_start가 다시 검사한다.
create or replace function public.world_pexp_ready(p_uid uuid, p_node uuid, p_location text)
returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype; n public.world_exploration_nodes%rowtype; fare int;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if not found then return '캐릭터가 없습니다'; end if;
  if coalesce(c.is_dead, false) or c.health <= 0 or c.downed_at is not null then return '전투불능'; end if;
  if c.location is distinct from p_location then return '다른 곳에 있음'; end if;
  if c.travel_destination is not null then return '이동 중'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then return '이미 원정 중'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = p_uid and not a.defeated and not coalesce(a.fled, false)) then return '전투 중'; end if;
  if exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = 'active') then return '자율 활동 중'; end if;
  select * into n from public.world_exploration_nodes where node_id = p_node;
  if not found then return '원정지를 찾을 수 없음'; end if;
  if not exists (select 1 from public.world_exploration_discoveries d where d.owner_id = p_uid and d.node_id = p_node) then return '아직 찾지 못한 원정지'; end if;
  if c.level < n.min_level then return format('레벨 %s 필요', n.min_level); end if;
  fare := greatest(1, least(3, n.hierarchy_level - 1));
  if c.mount_tokens < fare then return format('노정패 %s개 필요', fare); end if;
  return null;
end $$;

-- 수락한 동료와 파티장을 한 번에 출발시킨다(내부용). 파티장이 못 떠나거나 함께 떠날 동료가 없으면 아무도 떠나지 않는다.
create or replace function public.world_pexp_resolve(p_offer uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare o public.world_party_exp_offers%rowtype; acc uuid[]; pid uuid; started uuid[] := '{}'; failed jsonb := '{}'::jsonb;
  oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true);
  nm text; names text; why text; ln text;
begin
  select * into o from public.world_party_exp_offers where offer_id = p_offer for update;
  if not found or o.status <> 'pending' then return jsonb_build_object('ok', false, 'content', '이미 끝난 제안입니다.'); end if;
  select array_agg(x) into acc from unnest(o.invitees) x where o.responses ->> x::text = 'accepted';
  acc := coalesce(acc, '{}');
  select node_name into nm from public.world_exploration_nodes where node_id = o.node_id;
  select character_name into ln from public.world_characters where owner_id = o.leader_id;
  if cardinality(acc) = 0 then
    why := '함께 가겠다고 한 동료가 없어 출발하지 않았습니다.';
  else
    begin
      foreach pid in array array[o.leader_id] || acc loop
        perform set_config('request.jwt.claim.sub', pid::text, true);
        perform set_config('request.jwt.claims', json_build_object('sub', pid, 'role', 'authenticated')::text, true);
        begin
          perform public.world_expedition_start(o.node_id, o.minutes, o.stance);
          started := started || pid;
        exception when others then
          if pid = o.leader_id then raise; end if;
          failed := failed || jsonb_build_object(pid::text, sqlerrm);
        end;
      end loop;
      if cardinality(started) < 2 then raise exception '함께 떠날 수 있는 동료가 없어 출발하지 않았습니다.'; end if;
    exception when others then
      why := sqlerrm; started := '{}';
    end;
    perform set_config('request.jwt.claims', coalesce(oc, ''), true);
    perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  end if;
  if cardinality(started) = 0 then
    update public.world_party_exp_offers set status = 'cancelled', resolved_at = now(), result = jsonb_build_object('reason', why, 'failed', failed) where offer_id = o.offer_id;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    select u, 'party_exp_result', '파티 원정 취소', ln || '의 파티 원정 제안: ' || why, jsonb_build_object('offer_id', o.offer_id)
    from unnest(array[o.leader_id] || acc) u;
    return jsonb_build_object('ok', false, 'departed', false, 'content', why);
  end if;
  select string_agg(c.character_name, '·' order by array_position(started, c.owner_id)) into names from public.world_characters c where c.owner_id = any (started);
  update public.world_party_exp_offers set status = 'departed', resolved_at = now(), result = jsonb_build_object('started', to_jsonb(started), 'failed', failed) where offer_id = o.offer_id;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select u, 'party_exp_departed', '파티 원정 출발', names || ' 조사원이 함께 ' || coalesce(nm, '원정지') || '(으)로 떠났습니다. ' || o.minutes || '분 뒤 함께 돌아옵니다.', jsonb_build_object('offer_id', o.offer_id, 'node_id', o.node_id)
  from unnest(started) u;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select k::uuid, 'party_exp_result', '파티 원정에 빠짐', '함께 출발하지 못했습니다: ' || v, jsonb_build_object('offer_id', o.offer_id)
  from jsonb_each_text(failed) t(k, v);
  return jsonb_build_object('ok', true, 'departed', true, 'content', names || ' 조사원이 함께 원정을 떠났습니다. ' || o.minutes || '분 뒤 함께 돌아옵니다.');
end $$;

create or replace function public.world_party_expedition_propose(p_node_id uuid, p_minutes int, p_stance text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); pid uuid; c public.world_characters%rowtype; r public.world_map_regions%rowtype; n public.world_exploration_nodes%rowtype;
  why text; inv uuid[] := '{}'; skipped text[] := '{}'; m record; oid uuid; sn text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_minutes is null or p_minutes not in (30, 60, 120, 240, 480) then raise exception '원정 기간을 고르세요.'; end if;
  if p_stance is null or p_stance not in ('cautious', 'balanced', 'bold') then raise exception '원정 태세를 고르세요.'; end if;
  select party_id into pid from public.world_parties where leader_id = uid;
  if pid is null then raise exception '파티장만 함께 원정을 제안할 수 있습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  r := public.world_field_region(c.location);
  if r.region_id is null or r.is_safe_zone then raise exception '안전지대에서는 원정을 떠날 수 없습니다.'; end if;
  select * into n from public.world_exploration_nodes where node_id = p_node_id and region_id = r.region_id and hierarchy_level >= 2;
  if not found then raise exception '지금 있는 지역의 원정지를 고르세요.'; end if;
  why := public.world_pexp_ready(uid, n.node_id, c.location);
  if why is not null then raise exception '%', '지금은 원정을 떠날 수 없습니다: ' || why; end if;
  for m in select pm.owner_id, o.character_name from public.world_party_members pm join public.world_characters o on o.owner_id = pm.owner_id
           where pm.party_id = pid and pm.owner_id <> uid and o.location = c.location loop
    why := public.world_pexp_ready(m.owner_id, n.node_id, c.location);
    if why is null then inv := inv || m.owner_id; else skipped := skipped || (m.character_name || '(' || why || ')'); end if;
  end loop;
  if cardinality(inv) = 0 then
    raise exception '%', '같은 곳에 함께 떠날 수 있는 동료가 없습니다' || case when cardinality(skipped) > 0 then ': ' || array_to_string(skipped, ', ') else '.' end;
  end if;
  update public.world_party_exp_offers set status = 'cancelled', resolved_at = now(), result = jsonb_build_object('reason', '새 제안으로 바뀜')
   where party_id = pid and status = 'pending';
  insert into public.world_party_exp_offers(party_id, leader_id, node_id, region_id, location, minutes, stance, invitees, expires_at)
  values (pid, uid, n.node_id, r.region_id, c.location, p_minutes, p_stance, inv, now() + interval '3 minutes') returning offer_id into oid;
  sn := case p_stance when 'cautious' then '신중' when 'bold' then '강행' else '균형' end;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select u, 'party_exp_offer', '파티 원정 제안',
         c.character_name || ' 파티장이 ' || n.node_name || '(으)로 ' || p_minutes || '분 · ' || sn || ' 원정을 제안했습니다. 수락하면 모두 답한 순간 함께 출발합니다(3분 안).',
         jsonb_build_object('offer_id', oid, 'leader', c.character_name, 'node_id', n.node_id, 'node_name', n.node_name, 'minutes', p_minutes, 'stance', p_stance, 'location', c.location)
  from unnest(inv) u;
  return jsonb_build_object('ok', true, 'offer_id', oid,
    'content', '동료 ' || cardinality(inv) || '명에게 함께 원정을 제안했습니다. 모두 답하면 바로 함께 출발합니다.' || case when cardinality(skipped) > 0 then ' 함께 못 가는 동료: ' || array_to_string(skipped, ', ') else '' end);
end $$;

create or replace function public.world_party_expedition_respond(p_offer uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); o public.world_party_exp_offers%rowtype; why text; done_n int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into o from public.world_party_exp_offers where offer_id = p_offer for update;
  if not found or not (uid = any (o.invitees)) then raise exception '받은 원정 제안이 아닙니다.'; end if;
  update public.world_notifications set read_at = now() where user_id = uid and kind = 'party_exp_offer' and read_at is null and (payload ->> 'offer_id') = p_offer::text;
  if o.status <> 'pending' then raise exception '%', case o.status when 'departed' then '이미 출발한 원정입니다.' else '취소된 제안입니다.' end; end if;
  if o.expires_at < now() then
    update public.world_party_exp_offers set status = 'cancelled', resolved_at = now(), result = jsonb_build_object('reason', '제안 시간이 지남') where offer_id = o.offer_id;
    return jsonb_build_object('ok', false, 'content', '제안 시간(3분)이 지났습니다. 파티장에게 다시 제안해 달라고 하세요.');
  end if;
  if o.responses ? uid::text then raise exception '이미 답했습니다.'; end if;
  if p_accept then
    why := public.world_pexp_ready(uid, o.node_id, o.location);
    if why is not null then raise exception '%', '지금은 함께 떠날 수 없습니다: ' || why; end if;
  end if;
  update public.world_party_exp_offers set responses = responses || jsonb_build_object(uid::text, case when p_accept then 'accepted' else 'declined' end)
   where offer_id = o.offer_id returning * into o;
  select count(*) into done_n from unnest(o.invitees) x where o.responses ? x::text;
  if done_n >= cardinality(o.invitees) then return public.world_pexp_resolve(o.offer_id); end if;
  return jsonb_build_object('ok', true, 'content', case when p_accept then '함께 가겠다고 답했습니다. 다른 동료의 답을 기다립니다.' else '이번 원정에서 빠졌습니다.' end);
end $$;

-- 파티장: 아직 답하지 않은 동료를 빼고 지금 출발하거나(수락한 동료가 있어야 함), 제안을 거둔다
create or replace function public.world_party_expedition_depart(p_offer uuid, p_cancel boolean default false)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); o public.world_party_exp_offers%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into o from public.world_party_exp_offers where offer_id = p_offer for update;
  if not found or o.leader_id <> uid then raise exception '내가 낸 원정 제안이 아닙니다.'; end if;
  if o.status <> 'pending' then raise exception '이미 끝난 제안입니다.'; end if;
  if p_cancel then
    update public.world_party_exp_offers set status = 'cancelled', resolved_at = now(), result = jsonb_build_object('reason', '파티장이 거둠') where offer_id = o.offer_id;
    update public.world_notifications set read_at = now() where kind = 'party_exp_offer' and read_at is null and (payload ->> 'offer_id') = p_offer::text;
    return jsonb_build_object('ok', true, 'content', '원정 제안을 거뒀습니다.');
  end if;
  update public.world_notifications set read_at = now() where kind = 'party_exp_offer' and read_at is null and (payload ->> 'offer_id') = p_offer::text;
  return public.world_pexp_resolve(o.offer_id);
end $$;

-- 화면용: 내 파티에 걸린 제안(파티장·초대받은 사람 모두)
create or replace function public.world_party_expedition_offer_status()
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((
    select jsonb_build_object('offer_id', o.offer_id, 'is_leader', o.leader_id = public.fn_owner_auth_uid(),
      'leader', (select character_name from public.world_characters where owner_id = o.leader_id),
      'node_id', o.node_id, 'node_name', (select node_name from public.world_exploration_nodes where node_id = o.node_id),
      'minutes', o.minutes, 'stance', o.stance, 'expires_at', o.expires_at,
      'my_answer', o.responses ->> public.fn_owner_auth_uid()::text,
      'members', (select jsonb_agg(jsonb_build_object('name', c.character_name, 'answer', o.responses ->> x::text) order by c.character_name)
                    from unnest(o.invitees) x join public.world_characters c on c.owner_id = x))
    from public.world_party_exp_offers o
    where o.status = 'pending' and o.expires_at > now()
      and (o.leader_id = public.fn_owner_auth_uid() or public.fn_owner_auth_uid() = any (o.invitees))
    order by o.created_at desc limit 1), 'null'::jsonb)
$$;

do $$ declare f text; begin
  foreach f in array array['public.world_pexp_ready(uuid, uuid, text)', 'public.world_pexp_resolve(uuid)',
    'public.world_party_expedition_propose(uuid, integer, text)', 'public.world_party_expedition_respond(uuid, boolean)',
    'public.world_party_expedition_depart(uuid, boolean)', 'public.world_party_expedition_offer_status()'] loop
    execute format('alter function %s owner to fn_owner_field', f);
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['public.world_party_expedition_propose(uuid, integer, text)', 'public.world_party_expedition_respond(uuid, boolean)',
    'public.world_party_expedition_depart(uuid, boolean)', 'public.world_party_expedition_offer_status()'] loop
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

-- ⑤ ─────────────────────────────────────────
-- 지역마다 요괴 2종 더(일반 1·주력 1, 안전지대 제외 33곳 = 66종): 한 지역을 답사도 100%까지 도는 동안 같은 3종만 만나 지루하던 것을 덜어 준다.
-- 이름·갈래·설명만 새로 짓고, 레벨대·체력·공격·나오는 비율·전리품·위험 등급은 그 지역의 같은 역할 요괴를 그대로 따른다(밸런스·경제 그대로).
-- 갈래는 그 지역 풍경에 맞추되 되도록 그 지역에 없던 갈래로 골라 상성이 다양해지게 했다. 기믹·도감·「얻는 곳」은 갈래와 전리품을 따라 저절로 붙는다.
insert into public.world_region_monsters(monster_id, region_id, monster_name, monster_type, min_level, max_level, hp, attack_power, spawn_weight,
  description, drops, difficulty_rank, mechanic_key, mechanic_description, role, kind)
select 'x_' || v.region || '_' || v.n, v.region, v.name,
  case v.kind when 'bird' then '비행 요괴' when 'shell' then '갑각 요괴' when 'ghost' then '원령' when 'venom' then '독충' when 'wood' then '수목 요괴'
    when 'shadow' then '매복 요괴' when 'water' then '수귀' when 'swarm' then '무리 요괴' when 'mirror' then '거울 요괴' when 'ward' then '결계 요괴'
    when 'sky' then '천상 요괴' else '요괴' end,
  t.min_level, t.max_level, t.hp, t.attack_power, t.spawn_weight, v.descr, t.drops, t.difficulty_rank,
  case v.kind when 'bird' then 'aerial' when 'sky' then 'aerial' when 'shell' then 'armored' when 'ghost' then 'spectral' when 'venom' then 'toxic' when 'wood' then 'toxic'
    when 'shadow' then 'ambush' when 'water' then 'tide' when 'swarm' then 'swarm' when 'mirror' then 'reflect' when 'ward' then 'warded' else 'standard' end,
  case v.kind when 'bird' then '공중에 머물러 근접 타격이 약해진다. 원거리 사격에 취약하다.' when 'sky' then '공중에 머물러 근접 타격이 약해진다. 원거리 사격에 취약하다.'
    when 'shell' then '물리 방어가 높다. 봉인 제압은 방어를 무시하는 추가 피해를 준다.'
    when 'ghost' then '영체 장막이 정신을 흔든다. 봉인 제압이 효과적이며 정신 피해를 경계하라.'
    when 'venom' then '독성 기운이 짝수 행동마다 정신 안정도를 깎는다.' when 'wood' then '독성 기운이 짝수 행동마다 정신 안정도를 깎는다.'
    when 'shadow' then '빈틈을 노려 기습한다. 방어 태세로 첫 강공격을 대비하라.'
    when 'water' then '물의 기운으로 전투가 길어질수록 압박이 커진다. 빠르게 제압하라.'
    when 'swarm' then '군체의 압박으로 세 번째 행동마다 강한 반격을 가한다.'
    when 'mirror' then '공격의 일부를 되돌린다. 원거리 사격이나 봉인 제압을 활용하라.'
    when 'ward' then '결계막으로 공격을 완화한다. 봉인 제압으로 결계를 무너뜨려라.' else '일반 반격. 세 번째 행동마다 강한 공격을 한다.' end,
  v.role, v.kind
from (values
  ('field_outskirts', 1, 'common', '허수 까마귀', 'bird', '잿빛 허수아비 어깨에 앉아 이삭과 사람 눈을 노린다.'),
  ('field_outskirts', 2, 'main', '이삭 도깨비', 'wood', '잿빛 이삭 더미가 뭉쳐 일어선 도깨비. 낫 가는 소리를 흉내 낸다.'),
  ('hq_training', 1, 'common', '과녁 쥐떼', 'swarm', '과녁 짚단 속에 둥지를 튼 쥐 요괴 떼.'),
  ('hq_training', 2, 'main', '팔괘 거울귀', 'mirror', '팔괘진 거울에 맺힌 수련생의 잔상이 칼을 휘두른다.'),
  ('hq_archive', 1, 'common', '먹물 거미', 'venom', '서가 틈에 숨어 먹물 같은 독을 품은 거미.'),
  ('hq_archive', 2, 'main', '봉서 결계귀', 'ward', '봉인된 서책의 결계가 스스로 걸어 나왔다.'),
  ('shrine_ruins', 1, 'common', '촛농 도깨비불', 'ghost', '꺼진 제단 촛농에서 피어오르는 도깨비불.'),
  ('shrine_ruins', 2, 'main', '신목 덩굴귀', 'wood', '사당 신목에 감긴 덩굴이 금줄을 끊고 일어섰다.'),
  ('west_gate', 1, 'common', '성벽 박쥐 떼', 'swarm', '무너진 성벽 틈에서 쏟아져 나오는 박쥐 떼.'),
  ('west_gate', 2, 'main', '녹슨 창귀', 'shell', '녹슨 갑주를 걸친 채 아직도 성문을 지키는 수비병의 혼.'),
  ('paper_bridge', 1, 'common', '먹물 잉어', 'water', '다리 아래 먹물 든 물에서 뛰어오르는 잉어 요괴.'),
  ('paper_bridge', 2, 'main', '부적 허수', 'ward', '다리 난간에 붙은 부적들이 모여 사람 꼴을 했다.'),
  ('old_canal', 1, 'common', '수로 독개구리', 'venom', '고인 수로에서 독을 뿜는 개구리.'),
  ('old_canal', 2, 'main', '그림자 뱃사공', 'shadow', '어둠 속 수문 사이로 소리 없이 노를 젓는 그림자.'),
  ('sealed_garden', 1, 'common', '연잎 두꺼비', 'venom', '연잎 아래 숨어 있다 독을 뿜는 두꺼비.'),
  ('sealed_garden', 2, 'main', '봉인 석등귀', 'ward', '연화원 석등에 깃든 결계의 잔재.'),
  ('ghost_bamboo', 1, 'common', '댓잎 참새 떼', 'bird', '대숲을 가르며 날카로운 깃을 날리는 참새 떼.'),
  ('ghost_bamboo', 2, 'main', '죽엽 은자', 'shadow', '댓잎 그림자 사이로 사라졌다 나타나는 은자.'),
  ('salt_village', 1, 'common', '염전 갈매기', 'bird', '소금 자루를 쪼아 대는 갈매기 요괴.'),
  ('salt_village', 2, 'main', '소금 기둥귀', 'shell', '굳은 소금 껍질을 겹겹이 두른 요괴.'),
  ('sunken_district', 1, 'common', '이끼 쥐떼', 'swarm', '잠긴 골목 지붕 위로 몰려다니는 쥐 떼.'),
  ('sunken_district', 2, 'main', '물 먹은 상여귀', 'ghost', '떠내려온 상여에 붙어 다니는 원령.'),
  ('red_plain', 1, 'common', '적사 독수리', 'bird', '적사 위를 맴돌며 쓰러진 이를 노리는 독수리.'),
  ('red_plain', 2, 'main', '사암 갑귀', 'shell', '사암 껍질을 두른 채 모래 속을 헤엄친다.'),
  ('ash_mountain', 1, 'common', '잿더미 쥐떼', 'swarm', '뜨거운 재 속을 굴러다니는 쥐 떼.'),
  ('ash_mountain', 2, 'main', '용암 원령', 'ghost', '식은 용암 틈으로 떠도는 원령.'),
  ('lotus_marsh', 1, 'common', '연밥 물새', 'bird', '늪 위를 스치며 연밥과 사람 손을 노리는 물새 요괴.'),
  ('lotus_marsh', 2, 'main', '연화 수귀', 'water', '연꽃 아래 잠긴 수귀가 발목을 끌어당긴다.'),
  ('glass_canyon', 1, 'common', '유리 전갈', 'venom', '투명한 껍질 속 독이 비쳐 보이는 전갈.'),
  ('glass_canyon', 2, 'main', '협곡 바람귀', 'sky', '유리 벽에 부딪혀 울리는 바람이 날을 세운다.'),
  ('mirror_pavilion', 1, 'common', '달그림자 학', 'bird', '수면에 비친 달을 쪼는 학 요괴.'),
  ('mirror_pavilion', 2, 'main', '누각 밑 수귀', 'water', '누각 아래 거울 같은 물속에서 손을 뻗는 수귀.'),
  ('ash_coast', 1, 'common', '잿빛 게 떼', 'swarm', '잿빛 모래를 뒤덮은 게 떼.'),
  ('ash_coast', 2, 'main', '난파선 망령', 'ghost', '잿바다에 가라앉은 배의 선원 혼백.'),
  ('black_sand_temple', 1, 'common', '흑사 박쥐', 'bird', '폐단 천장에 매달려 있다 날아드는 검은 박쥐.'),
  ('black_sand_temple', 2, 'main', '금주 사제', 'ward', '끊어진 금주를 다시 감는 사교 사제의 망령.'),
  ('burial_steps', 1, 'common', '무덤 쥐떼', 'swarm', '무덤 사이를 파고드는 쥐 떼.'),
  ('burial_steps', 2, 'main', '백골 갑사', 'shell', '백골 위에 녹슨 갑옷을 두른 무덤 수호병.'),
  ('jade_pass', 1, 'common', '옥빛 뱀', 'venom', '비취 바위 틈에 숨은 독뱀.'),
  ('jade_pass', 2, 'main', '잔도 매복귀', 'shadow', '벼랑 잔도 그늘에 숨었다가 길손을 떠민다.'),
  ('frost_valley', 1, 'common', '서리 까마귀', 'bird', '얼음 깃을 흩뿌리는 까마귀.'),
  ('frost_valley', 2, 'main', '빙벽 갑귀', 'shell', '얼음 껍질을 겹겹이 두른 요괴.'),
  ('crimson_mine', 1, 'common', '광석 지네', 'venom', '붉은 광석 사이를 기는 독지네.'),
  ('crimson_mine', 2, 'main', '갱도 원령', 'ghost', '무너진 갱도에 갇힌 광부의 혼.'),
  ('red_forest', 1, 'common', '핏잎 나비 떼', 'swarm', '붉은 잎과 함께 흩날리는 나비 떼.'),
  ('red_forest', 2, 'main', '낙엽 원령', 'ghost', '붉은 낙엽 더미 아래 묻힌 나그네의 혼.'),
  ('sky_lake', 1, 'common', '서리 나비 떼', 'swarm', '얼어붙은 호수 위를 춤추는 나비 떼.'),
  ('sky_lake', 2, 'main', '하늘 거울귀', 'mirror', '호수에 비친 하늘에서 걸어 나온 요괴.'),
  ('nine_lighthouse', 1, 'common', '갯바위 집게', 'shell', '갯바위에 붙어 지나는 이를 집는 큰 게.'),
  ('nine_lighthouse', 2, 'main', '등불 원령', 'ghost', '꺼진 등불을 들고 섬 사이를 떠도는 원령.'),
  ('sunken_palace', 1, 'common', '수궁 해파리 떼', 'swarm', '빛을 내며 몰려드는 해파리 떼.'),
  ('sunken_palace', 2, 'main', '용궁 시녀귀', 'ghost', '용궁을 섬기던 시녀의 혼백.'),
  ('forgotten_city', 1, 'common', '처마 박쥐', 'bird', '무너진 궁궐 처마에서 날아드는 박쥐.'),
  ('forgotten_city', 2, 'main', '고도 결계관', 'ward', '망국의 결계를 지키던 관리의 혼.'),
  ('red_moon_fort', 1, 'common', '월식 박쥐 떼', 'swarm', '붉은 달빛 아래 몰려드는 박쥐 떼.'),
  ('red_moon_fort', 2, 'main', '혈월 무사', 'shadow', '월식 그늘에서 칼을 뽑는 교단 무사.'),
  ('thunder_peak', 1, 'common', '벼락 지네', 'venom', '벼락 맞은 바위 틈에서 기어 나온 지네.'),
  ('thunder_peak', 2, 'main', '뇌석 갑귀', 'shell', '벼락을 머금은 바위 껍질의 요괴.'),
  ('under_root', 1, 'common', '뿌리 덩굴손', 'wood', '지맥의 뿌리가 뻗어 나와 발을 휘감는다.'),
  ('under_root', 2, 'main', '지하 수맥귀', 'water', '뿌리 사이를 흐르는 수맥에 깃든 요괴.'),
  ('white_tower', 1, 'common', '별빛 박쥐', 'bird', '탑 꼭대기에서 별빛을 쪼는 박쥐.'),
  ('white_tower', 2, 'main', '천문 거울귀', 'mirror', '관측용 거울에 맺힌 별의 그림자.'),
  ('black_tide_rift', 1, 'common', '검은 게 떼', 'swarm', '균열 틈에서 쏟아지는 검은 게 떼.'),
  ('black_tide_rift', 2, 'main', '심해 원령', 'ghost', '검은 물결 아래 잠긴 혼백.'),
  ('sealed_abyss', 1, 'common', '봉연 박쥐 떼', 'swarm', '봉인 틈으로 새어 나온 박쥐 떼.'),
  ('sealed_abyss', 2, 'main', '봉연 거울귀', 'mirror', '아홉 겹 봉인에 비친 요기가 형체를 얻었다.')
) v(region, n, role, name, kind, descr)
join lateral (select * from public.world_region_monsters t where t.region_id = v.region and t.role = v.role and t.monster_id not like 'x\_%' order by t.min_level, t.monster_id limit 1) t on true
on conflict (monster_id) do nothing;

grant fn_owner_18885 to postgres with inherit false, set false;
grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_18987 to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029060000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
