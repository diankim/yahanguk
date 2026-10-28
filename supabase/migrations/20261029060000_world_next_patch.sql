-- 다음 대규모 패치(5.0.0) 묶음: 그 패치 때 한 번에 실행하는 파일이다(작은 SQL을 따로따로 돌리지 않는다).
--   ① 이동 중에는 탈것을 바꿀 수 없다(출발한 뒤 다른 탈것으로 갈아타던 것을 막는다)
--   ② 노정 건량 준비(make_travel_ration)의 의무관 전용 조건을 뺀다(원정·이동 보급품으로 쓰이는 곳이 많아 누구나 만들게)
--   ④ 파티 원정 함께 출발: 파티장 제안 → 동료 수락 → 한 트랜잭션에서 모두 출발(출발·귀환 시각이 같다). 2명은 수락해야 출발, 3명 이상은 거절·무응답 빼고 출발
--   ⑤ 지역마다 요괴 2종 더(안전지대 제외 33곳 66종, 이름·갈래·설명만 새로, 능력치·전리품은 그 지역 같은 역할을 따름)
--   ③ 전체 채팅에 쓰러짐을 알린 조사원이 다시 일어나면(구조·본부 구조대·회복품·요화 봉인) 그 소식도 한 줄 남긴다(헛걸음 방지)
--   ⑥ 기술 단계 보상 개편: 4.0.0의 이름 있는 기술 105개(13·30 추가, 24·43 택일, 50 숙달, 조합 7)를 수치 보정 대신 행동이 바뀌는 고유 효과로(현장 토벌·채집·제작·탐색·이동·휴식·강화·수리·구조), 근접 택일 24b는 「도발」(이목)
--   ⑦ 원거리 소모품: 화살·쇠뇌살·취관 침(묶음 100). 한 발에 하나(없으면 피해 절반), 원정은 회차마다 둘. 지금 원거리 무기를 든 조사원에게 100개
--   ⑧ 기력: 근접 무기를 들면 영력을 「기력」으로 쓴다(공격마다 2). 전투·원정 중 장비 바꿔 끼기를 막는다
--   ⑨ 같은 장비가 여럿일 때 상점 팔기·버리기·분해는 닳은 쪽이 먼저 나간다(남은 것은 새것)
--   ⑩ 봉인술 계열 13·24·30·43단계를 모두 택일로(A 폭딜 · B 버프/디버프)
--   ⑪ 근접 계열 13·24·30·43단계를 모두 택일로(A 딜러 · B 탱커·이목)
--   (화면) 채팅의 구조 알림 줄: 시각이 「21:/00」처럼 세로로 쪼개지던 것을 한 줄로
--   (화면) 환골탈태 서첩 창: 모바일에서 직업·소속 12칸이 한 줄씩 쌓여 「이대로 다시 시작」 단추가 한참 아래로 밀려 안 보이던 것을 두 줄 격자·아래 고정 단추로
--   (화면) 동료 화면 친구·모임: 단추가 이름에서 멀리 떨어져 늘어나던 것을 사람·모임마다 카드로 나누고 단추를 이름 곁에
--   (화면) 조사원 카드의 비무 단추를 귓속말 옆으로 올리고, 못 할 때는 숨기지 않고 까닭을 적는다(안전지대에서 아래로 밀려 안 보이던 것)
--   (화면) 채팅 안내 문구 「하루 50회」 (가방 검색 한글 깨짐은 4.0.0 32번으로 먼저 배포함)

grant fn_owner_18885 to postgres with inherit true, set true;
grant fn_owner_18987 to postgres with inherit true, set true;
grant fn_owner_field to postgres with inherit true, set true;
grant fn_owner_18452 to postgres with inherit true, set true;
grant fn_owner_18453 to postgres with inherit true, set true;
grant fn_owner_18956 to postgres with inherit true, set true;
grant fn_owner_18878 to postgres with inherit true, set true;

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

-- ⑥ ─────────────────────────────────────────
-- 기술 단계 보상 개편: 4.0.0에서 넣은 이름 있는 기술(13·30 추가, 24·43 택일, 50 숙달, 조합 7개)을 수치 보정 대신 행동이 바뀌는 고유 효과로.
-- 9단계 기본 기술(base)은 그대로 수치 효과다. 고유 효과는 각 행동 함수가 world_skill_procs(이 캐릭터가 가진 고유 효과 기술 목록)를 보고 처리한다.

-- 이 캐릭터가 가진 고유 효과 기술(추가·택일·숙달·조합)의 skill_id 목록
create or replace function public.world_skill_procs(p_uid uuid)
returns text[] language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce(array_agg(sk.skill_id), '{}')
  from public.world_characters c
  left join public.world_skill_picks pk on pk.owner_id = c.owner_id
  join public.world_skill_catalog sk on sk.slot in ('extra', 'a', 'b', 'master', 'combo')
  where c.owner_id = p_uid
    and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires)
$$;
revoke all on function public.world_skill_procs(uuid) from public, anon, authenticated;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn_owner_%' loop
    execute format('grant execute on function public.world_skill_procs(uuid) to %I', r);
  end loop;
end $$;

-- 수치 보정은 없애고(빈 효과), 설명을 고유 효과로 바꾼다
update public.world_skill_catalog s set passive_effect = '{}'::jsonb, description = v.d
from (values
  -- 근접
  ('melee_x13', '추가 기술 · 전투의 첫 공격(근접)은 반드시 치명타'),
  ('melee_c24a', '택일 기술 · 적 체력이 30% 아래면 근접 피해 +40%(마무리)'),
  ('melee_c24b', '택일 기술 · 이목 +60(원정 합동 전투에서 요괴가 나를 먼저 노린다) · 현장 토벌에서 방어하면 적이 예고한 기믹을 버리고 나에게 달려든다'),
  ('melee_x30', '추가 기술 · 근접 공격할 때마다 보호막 +3(최대 15, 받는 피해를 먼저 막음)'),
  ('melee_c43a', '택일 기술 · 근접 치명타가 적의 방어를 2턴 무너뜨린다(받는 피해 +20%)'),
  ('melee_c43b', '택일 기술 · 막기·회피에 성공하면 다음 공격이 반드시 치명타'),
  ('melee_m50', '숙달 기술 · 근접 공격 때 20% 확률로 세 번 연속 베기(2·3타 피해 50%)'),
  -- 원거리
  ('ranged_x13', '추가 기술 · 전투의 첫 공격은 허상·회피에 막히지 않는다'),
  ('ranged_c24a', '택일 기술 · 적 체력이 70% 위면 원거리 피해 +30%(선제 저격)'),
  ('ranged_c24b', '택일 기술 · 원거리 공격 때 20% 확률로 연사(두 번째 화살 피해 60%)'),
  ('ranged_x30', '추가 기술 · 비금·천상 요괴에게 원거리 피해 +25%'),
  ('ranged_c43a', '택일 기술 · 원거리 공격이 결계·껍질을 무시하고 꿰뚫는다'),
  ('ranged_c43b', '택일 기술 · 연사가 나가면 50% 확률로 세 번째 화살(피해 60%)'),
  ('ranged_m50', '숙달 기술 · 원거리 치명타가 「꿰뚫림」을 남긴다(3턴 동안 매턴 적 최대 체력 4% 피해)'),
  -- 봉인술(술법)
  ('sealing_x13', '추가 기술 · 우두머리가 봉인술을 떨쳐 낼 확률 50% → 35%'),
  ('sealing_c24a', '택일 기술 · 술법이 적중하면 20% 확률로 터져 피해 25% 추가'),
  ('sealing_c24b', '택일 기술 · 술법 공격마다 정신 +2(한 전투에 5번까지)'),
  ('sealing_x30', '추가 기술 · 봉인에 묶였던 적에게 주는 다음 공격 피해 +30%'),
  ('sealing_c43a', '택일 기술 · 술법 공격 때 15% 확률로 벼락(적 최대 체력 8% 피해)'),
  ('sealing_c43b', '택일 기술 · 술법 공격마다 30% 확률로 침식 −1'),
  ('sealing_m50', '숙달 기술 · 우두머리가 봉인술을 떨쳐 낼 확률을 절반으로'),
  -- 분석
  ('analysis_x13', '추가 기술 · 요괴가 기믹을 쓰는 턴에 받는 피해 −20%'),
  ('analysis_c24a', '택일 기술 · 약점 간파 뒤 첫 공격은 반드시 치명타, 치명타 피해 ×2'),
  ('analysis_c24b', '택일 기술 · 기믹을 예고한 턴에 공격하면 30% 확률로 그 기믹을 끊는다'),
  ('analysis_x30', '추가 기술 · 이미 쓰러뜨린 적 있는 요괴에게 주는 피해 +15%'),
  ('analysis_c43a', '택일 기술 · 치명타가 나면 적의 방어를 2턴 무너뜨린다(받는 피해 +20%)'),
  ('analysis_c43b', '택일 기술 · 기를 모으는 요괴를 끊는 기준이 체력 15% → 8%'),
  ('analysis_m50', '숙달 기술 · 약점 간파가 3번 → 5번 공격까지, 걸린 동안 회피 +15'),
  -- 막기
  ('guarding_x13', '추가 기술 · 방어한 턴에 받는 피해 추가 −20%'),
  ('guarding_c24a', '택일 기술 · 방어한 턴의 공격 한 번을 완전히 막는다(3턴에 한 번)'),
  ('guarding_c24b', '택일 기술 · 방어한 턴에 받은 피해의 50%를 적에게 되돌린다'),
  ('guarding_x30', '추가 기술 · 붙잡히지 않는다(붙잡기 기믹 무효)'),
  ('guarding_c43a', '택일 기술 · 한 전투에 한 번, 쓰러질 피해를 체력 1로 버틴다'),
  ('guarding_c43b', '택일 기술 · 방어로 막아 낸 피해만큼 다음 공격 피해가 커진다'),
  ('guarding_m50', '숙달 기술 · 방어한 턴에는 어떤 상태이상도 걸리지 않는다'),
  -- 응급 처치
  ('first_aid_x13', '추가 기술 · 전투 중 매턴 30% 확률로 출혈·중독이 저절로 풀린다'),
  ('first_aid_c24a', '택일 기술 · 회복품을 쓰면 다음 2턴 동안 체력 +4씩'),
  ('first_aid_c24b', '택일 기술 · 회복품을 쓰면 정신도 +6'),
  ('first_aid_x30', '추가 기술 · 한 전투에 한 번, 회복품을 쓰는 턴에 적이 공격하지 못한다'),
  ('first_aid_c43a', '택일 기술 · 내가 구조한 동료가 체력 80으로 깨어난다'),
  ('first_aid_c43b', '택일 기술 · 회복품이 나쁜 상태 하나를 함께 푼다'),
  ('first_aid_m50', '숙달 기술 · 체력이 25 아래로 떨어지면 한 전투에 한 번 저절로 체력 +30'),
  -- 일반 채집
  ('foraging_x13', '추가 기술 · 채집 때 10% 확률로 그 채집터의 다른 재료 하나 덤'),
  ('foraging_c24a', '택일 기술 · 채집 때 15% 확률로 두 번 거둔다'),
  ('foraging_c24b', '택일 기술 · 채집 때 10% 확률로 그 지역 희귀품 하나'),
  ('foraging_x30', '추가 기술 · 채집터를 다시 쓰는 대기 5분 → 4분'),
  ('foraging_c43a', '택일 기술 · 채집 때 10% 확률로 세 배 거둔다'),
  ('foraging_c43b', '택일 기술 · 채집 때 10% 확률로 묻혀 있던 옛 엽전(10 + 위험도×10전)'),
  ('foraging_m50', '숙달 기술 · 채집 때 25% 확률로 탐색력을 쓰지 않는다'),
  -- 약초 채집
  ('herbalism_x13', '추가 기술 · 약초를 거둘 때 10% 확률로 약초액 하나 덤'),
  ('herbalism_c24a', '택일 기술 · 약초를 거둘 때 15% 확률로 두 번 거둔다'),
  ('herbalism_c24b', '택일 기술 · 약초를 거둘 때 그 자리에서 씹어 체력 +3'),
  ('herbalism_x30', '추가 기술 · 약초를 거둘 때 도구가 닳지 않는다'),
  ('herbalism_c43a', '택일 기술 · 약초를 거둘 때 10% 확률로 세 배'),
  ('herbalism_c43b', '택일 기술 · 위험도 7 이상 지역에서 약초를 거둘 때 3% 확률로 귀령초'),
  ('herbalism_m50', '숙달 기술 · 약초를 거둘 때 체력·정신 +2, 침식 −1'),
  -- 광맥 채집
  ('mining_x13', '추가 기술 · 광석을 캘 때 10% 확률로 정련 숯 하나 덤'),
  ('mining_c24a', '택일 기술 · 광석을 캘 때 15% 확률로 두 번 캔다'),
  ('mining_c24b', '택일 기술 · 광석을 캘 때 10% 확률로 월철 주괴 하나'),
  ('mining_x30', '추가 기술 · 광석을 캘 때 도구가 닳지 않는다'),
  ('mining_c43a', '택일 기술 · 광석을 캘 때 5% 확률로 다섯 배'),
  ('mining_c43b', '택일 기술 · 광석을 캘 때 8% 확률로 강철 주괴 하나'),
  ('mining_m50', '숙달 기술 · 광석을 캔 채집터는 다시 쓰는 대기가 절반'),
  -- 영기 채집
  ('spirit_gathering_x13', '추가 기술 · 영기를 거둘 때 침식 −1'),
  ('spirit_gathering_c24a', '택일 기술 · 영기를 거둘 때 영력 +5'),
  ('spirit_gathering_c24b', '택일 기술 · 영기를 거둘 때 나쁜 상태 하나를 푼다'),
  ('spirit_gathering_x30', '추가 기술 · 영기를 거둘 때 10% 확률로 응축 영핵 하나'),
  ('spirit_gathering_c43a', '택일 기술 · 영기를 거둘 때 15% 확률로 두 번 거둔다'),
  ('spirit_gathering_c43b', '택일 기술 · 영기를 거둘 때 정신 +6'),
  ('spirit_gathering_m50', '숙달 기술 · 영기를 거둘 때 그 지역 희귀품이 20% 확률로'),
  -- 단조
  ('smithing_x13', '추가 기술 · 제작 때 10% 확률로 재료 한 종류를 하나 돌려받는다'),
  ('smithing_c24a', '택일 기술 · 단조 제작 품질을 두 번 굴려 높은 쪽을 쓴다'),
  ('smithing_c24b', '택일 기술 · 수리 도구가 내구도를 절반이 아니라 전부 되살린다'),
  ('smithing_x30', '추가 기술 · 품질 85 이상이면 장비가 아닌 완성품 하나 더'),
  ('smithing_c43a', '택일 기술 · 무기 강화 성공 확률 +10%p'),
  ('smithing_c43b', '택일 기술 · 대장간 수리비 절반'),
  ('smithing_m50', '숙달 기술 · 제작 때 10% 확률로 재료를 하나도 쓰지 않는다'),
  -- 연금
  ('alchemy_x13', '추가 기술 · 연금 제작 때 10% 확률로 재료 한 종류를 하나 돌려받는다'),
  ('alchemy_c24a', '택일 기술 · 연금 제작 때 15% 확률로 하나 더'),
  ('alchemy_c24b', '택일 기술 · 연금 제작을 마치면 약 기운을 맛보아 체력·정신 +5'),
  ('alchemy_x30', '추가 기술 · 연금 제작 품질을 두 번 굴려 높은 쪽을 쓴다'),
  ('alchemy_c43a', '택일 기술 · 연금 제작 때 30% 확률로 가장 비싼 재료 하나를 돌려받는다'),
  ('alchemy_c43b', '택일 기술 · 연금 제작을 마치면 나쁜 상태 하나를 푼다'),
  ('alchemy_m50', '숙달 기술 · 연금 제작 때 20% 확률로 두 배'),
  -- 결계 각인
  ('wardcraft_x13', '추가 기술 · 각인 제작 때 10% 확률로 재료 한 종류를 하나 돌려받는다'),
  ('wardcraft_c24a', '택일 기술 · 각인 제작 때 15% 확률로 하나 더'),
  ('wardcraft_c24b', '택일 기술 · 각인 제작을 마치면 침식 −2'),
  ('wardcraft_x30', '추가 기술 · 각인 제작 품질을 두 번 굴려 높은 쪽을 쓴다'),
  ('wardcraft_c43a', '택일 기술 · 각인 제작 품질 85 이상이면 완성품 하나 더'),
  ('wardcraft_c43b', '택일 기술 · 각인 제작을 마치면 정신 +6'),
  ('wardcraft_m50', '숙달 기술 · 각인 제작 때 20% 확률로 두 배'),
  -- 추적
  ('tracking_x13', '추가 기술 · 탐색에서 단서를 찾으면 10% 확률로 경험치 두 배'),
  ('tracking_c24a', '택일 기술 · 탐색에서 새 갈림길을 찾을 확률 두 배'),
  ('tracking_c24b', '택일 기술 · 이동 구간마다 10% 확률로 운임 면제'),
  ('tracking_x30', '추가 기술 · 탐색 때 요괴를 만나면 25% 확률로 들키지 않고 지나간다'),
  ('tracking_c43a', '택일 기술 · 탐색에서 사건 단서를 찾을 확률 두 배'),
  ('tracking_c43b', '택일 기술 · 걸어서 갈 때(노정패 없을 때) 이동 시간 −25%'),
  ('tracking_m50', '숙달 기술 · 탐색 때 15% 확률로 탐색력을 쓰지 않는다'),
  -- 조합
  ('combo_melee_smithing', '조합 기술(근접·단조 둘 다 18단계) · 공격할 때 무기가 닳지 않을 확률 50%'),
  ('combo_ranged_tracking', '조합 기술(원거리·추적 둘 다 18단계) · 전투의 첫 원거리 공격 피해 +50%'),
  ('combo_sealing_wardcraft', '조합 기술(봉인술·결계 각인 둘 다 18단계) · 봉인술로 묶으면 2턴 동안 움직이지 못한다'),
  ('combo_analysis_spirit_gathering', '조합 기술(분석·영기 채집 둘 다 18단계) · 영기를 거둔 채집터는 다시 쓰는 대기가 절반'),
  ('combo_guarding_mining', '조합 기술(막기·광맥 채집 둘 다 18단계) · 방어한 턴에 받은 피해의 30%만큼 체력 회복'),
  ('combo_first_aid_herbalism', '조합 기술(응급 처치·약초 채집 둘 다 18단계) · 약초를 쓰면 약초액만큼(체력 22) 회복'),
  ('combo_foraging_alchemy', '조합 기술(일반 채집·연금 둘 다 18단계) · 쉬기·야영 때 야령초 2개로 농축 약초액 하나를 저절로 만든다')
) v(id, d)
where s.skill_id = v.id;
update public.world_skill_catalog set skill_name = '도발' where skill_id = 'melee_c24b';

-- 현장 토벌: 4.0.0 동작(갈래 상성·기믹·거울막·레벨 차·행동 기술 경험)은 그대로 두고 전투 계열 고유 효과를 더한 새 판.
-- 원거리 공격은 장착 무기의 화살·쇠뇌살·취관 침을 쓴다(world_ammo_of). 근접 택일 24b는 「도발」(이목·기믹 끊기).
-- 새 상태값: 적 fx broken(방어 무너짐 턴)·pierce(꿰뚫림 턴)·dazed(봉인 뒤 무방비), 내 pfx opened(첫 공격 함)·flow(다음 공격 치명타)·
-- pshield(보호막)·surge(역류 피해)·regen(붕대 회복 턴)·wall_cd(철벽 다음 가능 턴)·endured·rallied·swift·calm(정심주 횟수)·focus_fresh.
create or replace function public.world_battle_action(p_action text, p_item text default null::text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
DECLARE
  uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; a public.world_active_encounters%rowtype;
  m public.world_region_monsters%rowtype; r public.world_map_regions%rowtype; st jsonb;
  act text := lower(coalesce(p_action, '')); style text := 'melee'; adr numeric := 0; eva numeric; flee_p numeric; crit_p numeric; defv numeric; inc numeric;
  turn int; v_fx jsonb; v_pfx jsonb; lines jsonb := '[]'::jsonb; dmg int := 0; mdmg int := 0; heal int := 0; crit boolean := false;
  base numeric; mul numeric := 1; cc numeric; mdef numeric; hit numeric; v_intent text; next_intent text; skip_monster boolean := false;
  guarding boolean := false; fled boolean := false; ended text; hp int; mn int; sp int; er int; inv jsonb; it text; k text; v int;
  loot jsonb := '{}'::jsonb; xp int := 0; gil_gain int := 0; rk_mul numeric; drop_p numeric; reflect int := 0; shield int;
  skill_name text; qty int; job_cd int; v_result jsonb; statuses text[] := '{}'; sig text; attacked boolean := false; wear jsonb; rare numeric; g public.world_monster_gimmicks%rowtype; gburst boolean := false; keen boolean := false; mheal int := 0; thorn int := 0;
  sk text[]; first_atk boolean; force_crit boolean := false; crit_x numeric := 1.6; extra int; ex_total int := 0; resist numeric; nfix int; gname text;
  raw_m int; absorb int; brk numeric := 0.15; eva_now numeric; n_hit int := 0; ammo_k text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF act NOT IN ('attack', 'skill', 'guard', 'item', 'flee') THEN RAISE EXCEPTION '알 수 없는 행동입니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태입니다.'; END IF;
  SELECT * INTO a FROM public.world_active_encounters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND OR a.defeated OR coalesce(a.fled, false) OR a.mlevel IS NULL THEN RAISE EXCEPTION '진행 중인 전투가 없습니다.'; END IF;
  IF a.last_action_at IS NOT NULL AND a.last_action_at > now() - interval '1 second' THEN
    RAISE EXCEPTION '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.'; END IF;
  SELECT * INTO m FROM public.world_region_monsters WHERE monster_id = a.monster_id;
  r := public.world_field_region(c.location);
  IF r.region_id IS DISTINCT FROM a.region_id THEN RAISE EXCEPTION '전투가 벌어진 지역에 있어야 합니다.'; END IF;

  st := public.world_combat_stats(uid);
  style := st ->> 'style';
  eva := (st ->> 'evasion_pct')::numeric; flee_p := (st ->> 'flee_pct')::numeric; crit_p := (st ->> 'crit_pct')::numeric;
  defv := (st ->> 'defense')::numeric; inc := (st ->> 'incoming_pct')::numeric;
  IF st -> 'armor' IS NOT NULL AND st -> 'armor' <> 'null'::jsonb AND st -> 'armor' ->> 'state' <> 'broken' THEN adr := coalesce((st -> 'armor' ->> 'reduction')::numeric, 0); END IF;
  sk := public.world_skill_procs(uid);

  turn := a.turn_count + 1; v_fx := coalesce(a.fx, '{}'::jsonb); v_pfx := coalesce(a.pfx, '{}'::jsonb);
  hp := c.health; mn := c.mental; sp := c.spiritual_power; er := c.erosion; inv := coalesce(c.inventory, '{}'::jsonb);
  v_intent := coalesce(a.intent, 'strike');
  job_cd := coalesce((v_pfx ->> 'skill_ready')::int, 0);
  first_atk := NOT coalesce((v_pfx ->> 'opened')::boolean, false);
  IF 'analysis_c43b' = ANY (sk) THEN brk := 0.08; END IF;

  -- 턴 시작: 지혈(출혈·중독 30%), 붕대술(남은 턴 동안 체력 +4)
  IF 'first_aid_x13' = ANY (sk) AND random() < 0.3 THEN
    UPDATE public.world_character_statuses SET expires_at = now() WHERE status_id = (SELECT status_id FROM public.world_character_statuses
      WHERE owner_id = uid AND expires_at > now() AND status_key IN ('bleeding', 'poisoned') ORDER BY expires_at LIMIT 1);
    IF FOUND THEN lines := lines || jsonb_build_array('「지혈」 출혈·독 하나를 다스렸다.'); END IF;
  END IF;
  IF coalesce((v_pfx ->> 'regen')::int, 0) > 0 THEN
    hp := least(100, hp + 4); v_pfx := v_pfx || jsonb_build_object('regen', (v_pfx ->> 'regen')::int - 1);
    lines := lines || jsonb_build_array('「붕대술」 체력 +4');
  END IF;

  IF act = 'skill' THEN
    IF turn < job_cd THEN RAISE EXCEPTION '%', format('기술은 %s턴 뒤에 다시 쓸 수 있습니다.', job_cd - turn); END IF;
    IF sp < 12 THEN RAISE EXCEPTION '%', CASE WHEN style = 'melee' THEN '기력' ELSE '영력' END || '이 모자랍니다. (필요 12)'; END IF;
    sp := sp - 12; v_pfx := v_pfx || jsonb_build_object('skill_ready', turn + 3);
  END IF;

  IF act = 'flee' THEN
    IF coalesce((v_pfx ->> 'bound')::int, 0) > 0 THEN
      lines := lines || jsonb_build_array('붙잡혀 있어 달아날 수 없다.');
    ELSIF random() * 100 < least(90, flee_p - greatest(0, a.mlevel - c.level) * 3 - (CASE WHEN a.rank = 'guardian' THEN 20 ELSE 0 END)) THEN
      fled := true; lines := lines || jsonb_build_array('몸을 돌려 달아났다.');
    ELSE
      lines := lines || jsonb_build_array('달아나려 했지만 길이 막혔다.');
    END IF;
  ELSIF act = 'guard' THEN
    guarding := true; sp := least(100, sp + 4); v_pfx := v_pfx || jsonb_build_object('u_gd', coalesce((v_pfx ->> 'u_gd')::int, 0) + 1);
    lines := lines || jsonb_build_array('자세를 낮추고 막을 준비를 했다.');
  ELSIF act = 'item' THEN
    it := coalesce(p_item, '');
    IF it NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman', 'spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew', 'rejuv_pill', 'grand_pill') THEN RAISE EXCEPTION '전투 중에 쓸 수 없는 물품입니다.'; END IF;
    IF coalesce((inv ->> it)::int, 0) < 1 THEN RAISE EXCEPTION '가방에 그 물품이 없습니다.'; END IF;
    inv := public.world_inv_add(inv, it, -1); v_pfx := v_pfx || jsonb_build_object('u_fa', coalesce((v_pfx ->> 'u_fa')::int, 0) + 1);
    IF it IN ('spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew') THEN
      heal := CASE it WHEN 'spirit_tea' THEN 10 WHEN 'clear_spirit_pill' THEN 20 WHEN 'spirit_qi_pill' THEN 35 WHEN 'moonlight_essence' THEN 55 ELSE 80 END;
      IF c.job_key = 'medic' THEN heal := round(heal * 1.4); END IF;
      heal := round(heal * (1 + public.world_status_effect_total('healing_pct') / 100.0));
      sp := least(100, sp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 ' || CASE WHEN style = 'melee' THEN '기력 ' ELSE '영력 ' END || heal || ' 회복');
    ELSIF it = 'ward_talisman' THEN
      mn := least(100, mn + 8);
      UPDATE public.world_character_statuses SET expires_at = now() WHERE owner_id = uid AND expires_at > now() AND status_key IN ('erosion_whisper', 'shaken', 'poisoned');
      IF (v_fx ->> 'barrier') IS NOT NULL THEN v_fx := v_fx - 'barrier'; END IF;
      lines := lines || jsonb_build_array('정화 부적을 태워 사기를 걷어냈다. 정신 +8');
    ELSE
      heal := CASE it WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 WHEN 'rejuv_pill' THEN 60 WHEN 'grand_pill' THEN 100
        ELSE CASE WHEN 'combo_first_aid_herbalism' = ANY (sk) THEN 22 ELSE 12 END END;
      IF c.job_key = 'medic' THEN heal := round(heal * 1.4); END IF;
      heal := round(heal * (1 + public.world_status_effect_total('healing_pct') / 100.0));
      hp := least(100, hp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 체력 ' || heal || ' 회복');
      IF 'first_aid_c24a' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('regen', 2); END IF;
      IF 'first_aid_c24b' = ANY (sk) THEN mn := least(100, mn + 6); lines := lines || jsonb_build_array('「안정 호흡」 정신 +6'); END IF;
      IF 'first_aid_c43b' = ANY (sk) THEN
        UPDATE public.world_character_statuses SET expires_at = now() WHERE status_id = (SELECT cs.status_id FROM public.world_character_statuses cs JOIN public.world_status_catalog sc USING (status_key)
          WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' ORDER BY cs.expires_at LIMIT 1);
        IF FOUND THEN lines := lines || jsonb_build_array('「해독술」 나쁜 상태 하나를 풀었다.'); END IF;
      END IF;
    END IF;
    IF 'first_aid_x30' = ANY (sk) AND NOT coalesce((v_pfx ->> 'swift')::boolean, false) THEN
      skip_monster := true; v_pfx := v_pfx || jsonb_build_object('swift', true);
      lines := lines || jsonb_build_array('「약침」 빈틈없이 처치해 적이 덤벼들지 못했다.');
    END IF;
  ELSIF act = 'skill' AND c.job_key = 'medic' THEN
    heal := least(60, 25 + c.vitality + c.willpower / 2); hp := least(100, hp + heal); v_pfx := v_pfx || jsonb_build_object('u_fa', coalesce((v_pfx ->> 'u_fa')::int, 0) + 1);
    UPDATE public.world_character_statuses SET expires_at = now() WHERE status_id = (SELECT cs.status_id FROM public.world_character_statuses cs JOIN public.world_status_catalog sc USING (status_key)
      WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' ORDER BY cs.expires_at LIMIT 1);
    lines := lines || jsonb_build_array('응급 처방: 체력 ' || heal || ' 회복, 나쁜 상태 하나를 걷어냈다.');
  ELSIF act = 'skill' AND c.job_key = 'analyst' THEN
    v_pfx := v_pfx || jsonb_build_object('focus', CASE WHEN 'analysis_m50' = ANY (sk) THEN 5 ELSE 3 END, 'focus_fresh', true, 'u_an', coalesce((v_pfx ->> 'u_an')::int, 0) + 1);
    lines := lines || jsonb_build_array('약점 간파: ' || m.monster_name || '의 빈틈을 읽었다. 다음 ' || CASE WHEN 'analysis_m50' = ANY (sk) THEN '다섯' ELSE '세' END || ' 번의 공격이 강해진다.');
  ELSE
    attacked := true;
    IF act = 'skill' AND c.job_key = 'exorcist' THEN style := 'magic'; skill_name := '퇴마진';
    ELSIF act = 'skill' AND c.job_key = 'scout' THEN style := 'ranged'; skill_name := '급소 사격';
    ELSIF act = 'skill' AND c.job_key = 'sealmaster' THEN skill_name := '봉인술';
    ELSIF act = 'skill' AND c.job_key = 'artificer' THEN skill_name := '폭렬 부적';
    END IF;
    base := (st ->> 'attack_raw')::numeric;
    -- 원거리 무기는 화살·쇠뇌살·취관 침을 한 발에 하나 쓴다(없으면 피해 절반)
    IF style = 'ranged' THEN
      ammo_k := public.world_ammo_of(uid);
      IF ammo_k IS NOT NULL THEN
        IF coalesce((inv ->> ammo_k)::int, 0) > 0 THEN inv := public.world_inv_add(inv, ammo_k, -1);
        ELSE base := base * 0.5; lines := lines || jsonb_build_array('쏠 것이 떨어져 활대로 내리쳤다. (피해 절반)'); END IF;
      END IF;
    END IF;
    IF style = 'magic' AND act = 'attack' THEN
      IF sp >= 3 THEN sp := sp - 3; ELSE base := base * 0.5; lines := lines || jsonb_build_array('영력이 바닥나 술법이 약해졌다.'); END IF;
    END IF;
    -- 근접 무기는 영력 대신 기력(같은 수치, 화면에서 노란 게이지)을 공격마다 2 쓴다(없으면 피해 절반)
    IF style = 'melee' AND act = 'attack' THEN
      IF sp >= 2 THEN sp := sp - 2; ELSE base := base * 0.5; lines := lines || jsonb_build_array('기력이 바닥나 칼끝에 힘이 실리지 않았다. (피해 절반)'); END IF;
    END IF;
    keen := coalesce((v_pfx ->> 'focus')::int, 0) > 0 OR coalesce((v_fx ->> 'marked')::int, 0) > 0 OR (first_atk AND 'ranged_x13' = ANY (sk));
    mul := 0.85 + random() * 0.3;
    mul := mul * public.world_kind_mult(m.kind, style, c.job_key);
    -- 약점 간파 뒤 첫 공격(급소 간파): 반드시 치명타, 치명타 피해 ×2
    IF coalesce((v_pfx ->> 'focus_fresh')::boolean, false) THEN
      IF 'analysis_c24a' = ANY (sk) THEN force_crit := true; crit_x := 2.0; END IF;
      v_pfx := v_pfx - 'focus_fresh';
    END IF;
    IF coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN mul := mul * 1.4; v_pfx := v_pfx || jsonb_build_object('focus', (v_pfx ->> 'focus')::int - 1); END IF;
    IF coalesce((v_fx ->> 'marked')::int, 0) > 0 THEN mul := mul * 1.25; v_fx := v_fx || jsonb_build_object('marked', (v_fx ->> 'marked')::int - 1); END IF;
    IF coalesce((v_fx ->> 'airborne')::boolean, false) THEN
      mul := mul * CASE style WHEN 'melee' THEN 0.4 WHEN 'ranged' THEN 1.2 ELSE 0.9 END;
    END IF;
    -- 고유 효과: 피해 배율
    IF style = 'melee' AND 'melee_c24a' = ANY (sk) AND a.current_hp < a.max_hp * 0.3 THEN mul := mul * 1.4; lines := lines || jsonb_build_array('「일격」 마무리를 노렸다.'); END IF;
    IF style = 'ranged' AND 'ranged_c24a' = ANY (sk) AND a.current_hp > a.max_hp * 0.7 THEN mul := mul * 1.3; END IF;
    IF style = 'ranged' AND 'ranged_x30' = ANY (sk) AND m.kind IN ('bird', 'sky') THEN mul := mul * 1.25; END IF;
    IF style = 'ranged' AND first_atk AND 'combo_ranged_tracking' = ANY (sk) THEN mul := mul * 1.5; lines := lines || jsonb_build_array('「사냥꾼의 눈」 먼저 겨눴다.'); END IF;
    IF 'analysis_x30' = ANY (sk) AND EXISTS (SELECT 1 FROM public.world_monster_codex x WHERE x.owner_id = uid AND x.monster_id = m.monster_id AND x.defeated > 0) THEN mul := mul * 1.15; END IF;
    IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN mul := mul * 1.2; END IF;
    IF coalesce((v_fx ->> 'dazed')::int, 0) > 0 THEN
      IF 'sealing_x30' = ANY (sk) THEN mul := mul * 1.3; lines := lines || jsonb_build_array('「겹술식」 무방비한 틈을 찔렀다.'); END IF;
      v_fx := v_fx - 'dazed';
    END IF;
    IF skill_name = '퇴마진' THEN mul := mul * 2.0; v_fx := v_fx - 'barrier';
    ELSIF skill_name = '급소 사격' THEN mul := mul * 1.8; v_fx := v_fx || jsonb_build_object('marked', 2);
    ELSIF skill_name = '폭렬 부적' THEN mul := mul * 1.7;
    ELSIF skill_name = '봉인술' THEN mul := mul * 1.1;
    END IF;
    -- 치명타: 발도(첫 근접 공격), 유수검(막기·회피 뒤)
    IF first_atk AND style = 'melee' AND 'melee_x13' = ANY (sk) THEN force_crit := true; END IF;
    IF coalesce((v_pfx ->> 'flow')::boolean, false) THEN force_crit := true; v_pfx := v_pfx - 'flow'; END IF;
    cc := least(0.65, crit_p / 100.0 + (CASE WHEN (v_pfx ? 'focus') THEN 0.1 ELSE 0 END));
    crit := skill_name = '급소 사격' OR force_crit OR random() < cc;
    IF crit AND skill_name IS DISTINCT FROM '급소 사격' THEN mul := mul * crit_x; END IF;
    mdef := a.def;
    IF coalesce((v_fx ->> 'harden')::int, 0) > 0 AND style IN ('melee', 'ranged') AND skill_name IS DISTINCT FROM '폭렬 부적'
       AND NOT (style = 'ranged' AND 'ranged_c43a' = ANY (sk)) THEN mdef := mdef * 3; END IF;
    v_fx := v_fx - 'harden';
    IF skill_name = '폭렬 부적' OR (style = 'ranged' AND 'ranged_c43a' = ANY (sk)) THEN mdef := 0; END IF;
    dmg := greatest(1, round(base * mul - mdef * 0.8));
    IF coalesce((v_pfx ->> 'surge')::int, 0) > 0 THEN dmg := dmg + (v_pfx ->> 'surge')::int; lines := lines || jsonb_build_array('「역류」 막아 낸 힘을 실었다. +' || (v_pfx ->> 'surge')); v_pfx := v_pfx - 'surge'; END IF;
    IF coalesce((v_fx ->> 'evade')::int, 0) > 0 AND NOT keen AND random() < 0.5 THEN dmg := 0; lines := lines || jsonb_build_array('허상을 쳤다. 공격이 빗나갔다.'); END IF;
    shield := coalesce((v_fx ->> 'barrier')::int, 0);
    IF shield > 0 AND skill_name IS DISTINCT FROM '폭렬 부적' AND NOT (style = 'ranged' AND 'ranged_c43a' = ANY (sk)) THEN
      IF style = 'magic' THEN shield := shield - dmg * 2; ELSE shield := shield - dmg; END IF;
      IF shield > 0 THEN v_fx := v_fx || jsonb_build_object('barrier', shield); lines := lines || jsonb_build_array('결계가 공격을 삼켰다.'); dmg := 0;
      ELSE v_fx := v_fx - 'barrier'; dmg := greatest(1, -shield / (CASE WHEN style = 'magic' THEN 2 ELSE 1 END)); lines := lines || jsonb_build_array('결계가 깨졌다.'); END IF;
    END IF;
    IF coalesce((v_fx ->> 'mirror')::int, 0) > 0 AND style = 'magic' AND dmg > 0 THEN
      reflect := least(15, round(dmg * 0.3)); v_fx := v_fx - 'mirror';
    END IF;
    a.current_hp := greatest(0, a.current_hp - dmg);
    lines := lines || jsonb_build_array(coalesce(skill_name, CASE style WHEN 'ranged' THEN '사격' WHEN 'magic' THEN '술법' ELSE '베기' END) || ': ' || dmg || ' 피해'
      || CASE WHEN crit THEN ' (치명타)' ELSE '' END);
    -- 고유 효과: 추가 타격(연타·검신·속사·연환시)
    IF dmg > 0 AND a.current_hp > 0 THEN
      IF style = 'melee' AND 'melee_m50' = ANY (sk) AND random() < 0.2 THEN
        extra := greatest(1, round(dmg * 0.5)); a.current_hp := greatest(0, a.current_hp - extra * 2); ex_total := extra * 2;
        lines := lines || jsonb_build_array('「검신」 세 번 연속 베었다: +' || extra || ' · +' || extra);
      ELSIF style = 'ranged' AND 'ranged_c24b' = ANY (sk) AND random() < 0.2 AND (ammo_k IS NULL OR coalesce((inv ->> ammo_k)::int, 0) > 0) THEN
        IF ammo_k IS NOT NULL THEN inv := public.world_inv_add(inv, ammo_k, -1); END IF;
        extra := greatest(1, round(dmg * 0.6)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := extra;
        lines := lines || jsonb_build_array('「속사」 연사: ' || extra || ' 피해');
        IF 'ranged_c43b' = ANY (sk) AND random() < 0.5 AND a.current_hp > 0 AND (ammo_k IS NULL OR coalesce((inv ->> ammo_k)::int, 0) > 0) THEN
          IF ammo_k IS NOT NULL THEN inv := public.world_inv_add(inv, ammo_k, -1); END IF;
          a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra;
          lines := lines || jsonb_build_array('「연환시」 세 번째 화살: ' || extra || ' 피해');
        END IF;
      END IF;
    END IF;
    -- 고유 효과: 치명타가 남기는 것(파천·필살 계산·천궁)
    IF crit AND dmg > 0 THEN
      IF (style = 'melee' AND 'melee_c43a' = ANY (sk)) OR 'analysis_c43a' = ANY (sk) THEN
        v_fx := v_fx || jsonb_build_object('broken', 2); lines := lines || jsonb_build_array(m.monster_name || '의 방어가 무너졌다(2턴 동안 받는 피해 +20%).');
      END IF;
      IF style = 'ranged' AND 'ranged_m50' = ANY (sk) THEN
        v_fx := v_fx || jsonb_build_object('pierce', 3); lines := lines || jsonb_build_array('「천궁」 화살이 꿰뚫고 박혔다.');
      END IF;
    END IF;
    -- 고유 효과: 술법(폭렬부·천뢰부·정심주·청정결)
    IF style = 'magic' AND dmg > 0 AND a.current_hp > 0 THEN
      IF 'sealing_c13a' = ANY (sk) AND random() < 0.25 THEN extra := greatest(1, round(dmg * 0.4)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「연쇄부」 부적이 튀어 ' || extra || ' 피해'); END IF;
      IF 'sealing_c30a' = ANY (sk) AND random() < 0.25 AND a.current_hp > 0 THEN extra := greatest(1, round(dmg * 0.7)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「연환부」 한 번 더 시전: ' || extra || ' 피해'); END IF;
      IF 'sealing_c24a' = ANY (sk) AND random() < 0.2 AND a.current_hp > 0 THEN extra := greatest(1, round(dmg * 0.25)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「폭렬부」 술식이 터졌다: ' || extra || ' 피해'); END IF;
      IF 'sealing_c43a' = ANY (sk) AND random() < 0.15 AND a.current_hp > 0 THEN extra := greatest(1, round(a.max_hp * 0.08)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「천뢰부」 벼락: ' || extra || ' 피해'); END IF;
    END IF;
    IF style = 'magic' AND 'sealing_c24b' = ANY (sk) THEN
      v_pfx := v_pfx || jsonb_build_object('pshield', least(16, coalesce((v_pfx ->> 'pshield')::int, 0) + 4));
      IF coalesce((v_pfx ->> 'calm')::int, 0) < 5 THEN mn := least(100, mn + 2); v_pfx := v_pfx || jsonb_build_object('calm', coalesce((v_pfx ->> 'calm')::int, 0) + 1); END IF;
    END IF;
    -- 청정결계: 술법을 쓰면 3턴 동안 받는 피해 −20%
    IF style = 'magic' AND 'sealing_c43b' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('ward', 3); END IF;
    IF style = 'magic' AND 'sealing_c43b' = ANY (sk) AND random() < 0.3 AND er > 0 THEN er := er - 1; END IF;
    -- 강기 두르기: 근접 공격마다 보호막 +3(최대 15)
    IF style = 'melee' AND 'melee_x30' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('pshield', least(15, coalesce((v_pfx ->> 'pshield')::int, 0) + 3)); END IF;
    v_pfx := v_pfx || jsonb_build_object('opened', true);
    IF reflect > 0 AND hp > 1 THEN reflect := least(reflect, hp - 1); hp := hp - reflect; lines := lines || jsonb_build_array('거울막이 술법을 되돌려 ' || reflect || ' 피해를 입었다.'); END IF;
    IF coalesce((v_fx ->> 'thorns')::int, 0) > 0 AND style = 'melee' AND dmg > 0 THEN thorn := greatest(1, round(dmg * 0.3)); hp := greatest(0, hp - thorn); lines := lines || jsonb_build_array('가시에 찔려 ' || thorn || ' 피해를 입었다.'); END IF;
    IF skill_name = '봉인술' THEN
      resist := CASE WHEN 'sealing_x13' = ANY (sk) THEN 0.35 ELSE 0.5 END;
      IF 'sealing_m50' = ANY (sk) THEN resist := resist / 2; END IF;
      IF a.rank = 'guardian' AND random() < resist THEN lines := lines || jsonb_build_array('우두머리가 봉인을 떨쳐냈다.');
      ELSE v_fx := v_fx || jsonb_build_object('stunned', CASE WHEN 'combo_sealing_wardcraft' = ANY (sk) THEN 2 ELSE 1 END);
        IF 'sealing_x13' = ANY (sk) THEN v_fx := v_fx || jsonb_build_object('broken', 2); lines := lines || jsonb_build_array('「부적 접기」 묶인 틈에 방어가 풀렸다.'); END IF;
        IF 'sealing_x30' = ANY (sk) THEN v_fx := v_fx || jsonb_build_object('weak', 4); lines := lines || jsonb_build_array('「겹술식」 기운이 꺾여 2턴 동안 공격이 약해진다.'); END IF;
        lines := lines || jsonb_build_array(m.monster_name || '의 움직임을 봉했다' || CASE WHEN 'combo_sealing_wardcraft' = ANY (sk) THEN '(겹봉인: 2턴)' ELSE '' END || '.'); END IF;
    END IF;
    IF NOT ('combo_melee_smithing' = ANY (sk) AND random() < 0.5) THEN
      wear := public.world_durability_wear(uid, 'weapon', 1);
      IF coalesce((wear ->> 'broke')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 부서졌다! 수리할 때까지 맨손만 못한 위력으로 싸운다.');
      ELSIF coalesce((wear ->> 'worn')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '의 날이 무뎌졌다. 수리가 필요하다.'); END IF;
    END IF;
  END IF;

  -- 꿰뚫림(천궁): 매턴 적 최대 체력 4%
  IF coalesce((v_fx ->> 'pierce')::int, 0) > 0 AND a.current_hp > 0 THEN
    extra := greatest(1, round(a.max_hp * 0.04)); a.current_hp := greatest(0, a.current_hp - extra);
    v_fx := v_fx || jsonb_build_object('pierce', (v_fx ->> 'pierce')::int - 1);
    IF (v_fx ->> 'pierce')::int <= 0 THEN v_fx := v_fx - 'pierce'; END IF;
    lines := lines || jsonb_build_array('박힌 화살이 파고든다: ' || extra || ' 피해');
  END IF;
  IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN
    v_fx := v_fx || jsonb_build_object('broken', (v_fx ->> 'broken')::int - 1);
    IF (v_fx ->> 'broken')::int <= 0 THEN v_fx := v_fx - 'broken'; END IF;
  END IF;
  IF coalesce((v_fx ->> 'weak')::int, 0) > 0 THEN
    v_fx := v_fx || jsonb_build_object('weak', (v_fx ->> 'weak')::int - 1);
    IF (v_fx ->> 'weak')::int <= 0 THEN v_fx := v_fx - 'weak'; END IF;
  END IF;
  IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 AND NOT (style = 'magic' AND attacked AND 'sealing_c43b' = ANY (sk)) THEN
    v_pfx := v_pfx || jsonb_build_object('ward', (v_pfx ->> 'ward')::int - 1);
    IF (v_pfx ->> 'ward')::int <= 0 THEN v_pfx := v_pfx - 'ward'; END IF;
  END IF;

  v_pfx := v_pfx - 'bound'; v_fx := v_fx - 'evade' - 'thorns' - 'mirror';
  IF a.current_hp <= 0 THEN
    ended := 'victory';
  ELSIF fled THEN
    ended := 'fled';
  ELSE
    IF coalesce((v_fx ->> 'stunned')::int, 0) > 0 THEN
      skip_monster := true;
      IF (v_fx ->> 'stunned')::int > 1 THEN v_fx := v_fx || jsonb_build_object('stunned', (v_fx ->> 'stunned')::int - 1);
      ELSE v_fx := v_fx - 'stunned'; END IF;
      v_fx := v_fx || jsonb_build_object('dazed', 1);
      lines := lines || jsonb_build_array(m.monster_name || '이(가) 봉인에 묶여 움직이지 못했다.');
      next_intent := public.world_battle_intent_k(m.kind, a.mlevel, m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank);
    END IF;
    -- 흐름 읽기: 기믹을 예고한 턴에 공격하면 30% 확률로 끊는다
    IF NOT skip_monster AND attacked AND 'analysis_c24b' = ANY (sk) AND v_intent LIKE 'g:%' AND random() < 0.3 THEN
      SELECT name INTO gname FROM public.world_monster_gimmicks WHERE gimmick_key = split_part(v_intent, ':', 2);
      lines := lines || jsonb_build_array('「흐름 읽기」 ' || coalesce('「' || gname || '」', '기믹') || '을(를) 미리 끊었다.');
      v_intent := 'strike';
    END IF;
    IF NOT skip_monster THEN
      hit := a.atk * (0.9 + random() * 0.2);
      IF coalesce((v_fx ->> 'weak')::int, 0) > 0 THEN hit := hit * 0.8; END IF;
      IF coalesce((v_fx ->> 'swarm')::int, 0) > 0 AND v_intent IN ('strike', 'heavy') THEN hit := hit * 1.3; v_fx := v_fx - 'swarm'; END IF;
      hit := hit * CASE v_intent WHEN 'strike' THEN 1 WHEN 'heavy' THEN 1.9 WHEN 'dive' THEN 1.7 WHEN 'pounce' THEN 2.0 WHEN 'unleash' THEN 2.6
        WHEN 'harden' THEN 0.5 WHEN 'wail' THEN 0.6 WHEN 'venom' THEN 0.6 WHEN 'mirror' THEN 0.4 WHEN 'tide' THEN 0.8 WHEN 'barrier' THEN 0.3
        WHEN 'breach' THEN 0.7 ELSE 0 END;
      IF v_intent LIKE 'g%:%' THEN
        SELECT * INTO g FROM public.world_monster_gimmicks WHERE gimmick_key = split_part(v_intent, ':', 2);
        gburst := v_intent LIKE 'g!:%';
        IF g.gimmick_key IS NULL THEN hit := a.atk * (0.9 + random() * 0.2);
        ELSIF g.gtype = 'charge' AND NOT gburst THEN
          hit := 0;
          IF dmg + ex_total >= a.max_hp * brk THEN lines := lines || jsonb_build_array(m.monster_name || '의 기세가 흐트러져 「' || g.name || '」이(가) 끊겼다.');
          ELSE next_intent := 'g!:' || g.gimmick_key; lines := lines || jsonb_build_array(m.monster_name || ': ' || g.tell); END IF;
        ELSE
          hit := a.atk * (0.9 + random() * 0.2) * g.power;
          IF g.gtype = 'heal' THEN
            mheal := round(a.max_hp * g.power2 * CASE WHEN act = 'skill' THEN 0.5 ELSE 1 END); a.current_hp := least(a.max_hp, a.current_hp + mheal);
            lines := lines || jsonb_build_array(m.monster_name || '의 「' || g.name || '」: 체력 ' || mheal || ' 회복' || CASE WHEN act = 'skill' THEN ' (기술로 절반을 끊음)' ELSE '' END);
          ELSIF g.gtype = 'summon' THEN
            a.current_hp := least(a.max_hp, a.current_hp + round(a.max_hp * g.power2)); v_fx := v_fx || jsonb_build_object('swarm', 1);
            lines := lines || jsonb_build_array(m.monster_name || '의 「' || g.name || '」: 무리가 몰려든다.');
          ELSIF g.gtype = 'shield' THEN
            v_fx := v_fx || jsonb_build_object('barrier', coalesce((v_fx ->> 'barrier')::int, 0) + round(a.max_hp * g.power2));
            lines := lines || jsonb_build_array(m.monster_name || '의 「' || g.name || '」: 결계가 둘러졌다.');
          ELSIF g.gtype = 'evade' THEN v_fx := v_fx || jsonb_build_object('evade', 1);
          ELSIF g.gtype = 'thorns' THEN v_fx := v_fx || jsonb_build_object('thorns', 1);
          ELSIF g.gtype = 'mirror' THEN v_fx := v_fx || jsonb_build_object('mirror', 1);
          END IF;
        END IF;
      END IF;
      v_fx := v_fx - 'airborne';
      IF v_intent = 'soar' THEN v_fx := v_fx || jsonb_build_object('airborne', true); next_intent := 'dive'; lines := lines || jsonb_build_array(m.monster_name || '이(가) 하늘로 솟구쳤다.');
      ELSIF v_intent = 'lurk' THEN next_intent := 'pounce'; lines := lines || jsonb_build_array(m.monster_name || '이(가) 그림자 속으로 숨었다.');
      ELSIF v_intent = 'charge' THEN next_intent := 'unleash'; lines := lines || jsonb_build_array(m.monster_name || '이(가) 기를 모은다.');
      ELSIF v_intent = 'harden' THEN v_fx := v_fx || jsonb_build_object('harden', 1); lines := lines || jsonb_build_array(m.monster_name || '이(가) 껍질을 굳혔다.');
      ELSIF v_intent = 'swarm' THEN
        a.current_hp := least(a.max_hp, a.current_hp + round(a.max_hp * 0.1)); v_fx := v_fx || jsonb_build_object('swarm', 1);
        lines := lines || jsonb_build_array(m.monster_name || '이(가) 무리를 불러 모았다.');
      ELSIF v_intent = 'mirror' THEN v_fx := v_fx || jsonb_build_object('mirror', 1); lines := lines || jsonb_build_array(m.monster_name || '이(가) 거울막을 둘렀다.');
      ELSIF v_intent = 'barrier' THEN v_fx := v_fx || jsonb_build_object('barrier', round(a.max_hp * 0.12)); lines := lines || jsonb_build_array(m.monster_name || '이(가) 결계를 펼쳤다.');
      ELSIF v_intent = 'rest' THEN a.current_hp := least(a.max_hp, a.current_hp + round(a.max_hp * 0.06)); lines := lines || jsonb_build_array(m.monster_name || '이(가) 숨을 골랐다.');
      END IF;
      IF hit > 0 THEN
        mdmg := round(hit * 100.0 / (100 + defv * 3));
        raw_m := mdmg;
        IF guarding THEN mdmg := round(mdmg * (CASE WHEN v_intent IN ('heavy', 'dive', 'pounce', 'unleash') OR gburst OR g.gtype IS NOT DISTINCT FROM 'big' THEN 0.25 ELSE 0.35 END)); END IF;
        IF guarding AND 'guarding_x13' = ANY (sk) THEN mdmg := round(mdmg * 0.8); END IF;
        IF g.gimmick_key IS NOT NULL AND 'analysis_x13' = ANY (sk) THEN mdmg := round(mdmg * 0.8); END IF;
        IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 THEN mdmg := round(mdmg * 0.8); END IF;
        IF 'melee_c13b' = ANY (sk) AND NOT coalesce((v_pfx ->> 'cowed')::boolean, false) THEN mdmg := round(mdmg * 0.7); v_pfx := v_pfx || jsonb_build_object('cowed', true); lines := lines || jsonb_build_array('「호령」 기세에 눌린 첫 공격이 무뎌졌다.'); END IF;
        IF coalesce((v_pfx ->> 'roar')::int, 0) > 0 THEN mdmg := round(mdmg * 0.85); END IF;
        mdmg := round(mdmg * (1 + inc / 100.0) * (1 - adr / 100.0) * greatest(0.7, least(1.3, 1 - 0.03 * (c.level - a.mlevel))));
        IF c.health < 30 THEN mdmg := ceil(mdmg * 1.15); END IF;
        eva_now := eva + CASE WHEN 'analysis_m50' = ANY (sk) AND coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN 15 ELSE 0 END;
        IF guarding AND 'guarding_c24a' = ANY (sk) AND coalesce((v_pfx ->> 'wall_cd')::int, 0) <= turn THEN
          mdmg := 0; v_pfx := v_pfx || jsonb_build_object('wall_cd', turn + 3); lines := lines || jsonb_build_array('「철벽」 공격을 완전히 막아 냈다.');
        ELSIF NOT guarding AND random() * 100 < eva_now * (CASE WHEN v_intent IN ('heavy', 'pounce', 'unleash') OR gburst THEN 0.6 ELSE 1 END) THEN
          mdmg := 0; lines := lines || jsonb_build_array('몸을 틀어 공격을 피했다.');
          IF 'melee_c30a' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('flow', true); END IF;
        END IF;
        mdmg := greatest(0, mdmg);
        IF guarding AND 'melee_c30a' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('flow', true); END IF;
        IF guarding AND 'guarding_c43b' = ANY (sk) AND raw_m > mdmg THEN v_pfx := v_pfx || jsonb_build_object('surge', least(40, raw_m - mdmg)); END IF;
        -- 강기 보호막이 먼저 받는다
        IF mdmg > 0 AND coalesce((v_pfx ->> 'pshield')::int, 0) > 0 THEN
          absorb := least(mdmg, (v_pfx ->> 'pshield')::int); mdmg := mdmg - absorb;
          v_pfx := v_pfx || jsonb_build_object('pshield', (v_pfx ->> 'pshield')::int - absorb);
          lines := lines || jsonb_build_array('「강기」가 ' || absorb || ' 피해를 막았다.');
        END IF;
        hp := greatest(0, hp - mdmg);
        IF mdmg > 0 THEN
          lines := lines || jsonb_build_array(m.monster_name || CASE v_intent WHEN 'heavy' THEN '의 강타' WHEN 'dive' THEN '의 급강하' WHEN 'pounce' THEN '의 기습'
            WHEN 'unleash' THEN '의 폭발' WHEN 'venom' THEN '의 독 분사' WHEN 'wail' THEN '의 곡성' WHEN 'tide' THEN '의 물살' WHEN 'breach' THEN '의 봉인 깨기' ELSE CASE WHEN g.gimmick_key IS NOT NULL THEN '의 「' || g.name || '」' ELSE '의 공격' END END
            || ': ' || mdmg || ' 피해' || CASE WHEN guarding THEN ' (막음)' ELSE '' END);
          wear := public.world_durability_wear(uid, 'hat', 1); IF coalesce((wear ->> 'broke')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 부서졌다!'); END IF; wear := public.world_durability_wear(uid, 'armor', 1);
          IF coalesce((wear ->> 'broke')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 찢어졌다! 수리할 때까지 막아 주지 못한다.');
          ELSIF coalesce((wear ->> 'worn')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> 'name') || '이(가) 해어졌다. 수리가 필요하다.'); END IF;
          IF guarding AND (v_intent IN ('heavy', 'dive', 'pounce', 'unleash') OR gburst OR g.gtype IS NOT DISTINCT FROM 'big') AND style = 'melee' THEN
            dmg := round(mdmg * 1.2 + c.strength * 0.5); a.current_hp := greatest(0, a.current_hp - dmg);
            lines := lines || jsonb_build_array('받아치기: ' || dmg || ' 피해');
          END IF;
          IF guarding AND 'guarding_c24b' = ANY (sk) THEN
            extra := greatest(1, round(mdmg * 0.5)); a.current_hp := greatest(0, a.current_hp - extra); lines := lines || jsonb_build_array('「반격 태세」 ' || extra || ' 피해를 되돌렸다.');
          END IF;
          IF guarding AND 'combo_guarding_mining' = ANY (sk) THEN
            extra := greatest(1, round(mdmg * 0.3)); hp := least(100, hp + extra); lines := lines || jsonb_build_array('「바위 몸」 체력 +' || extra);
          END IF;
          IF v_intent = 'wail' THEN mn := greatest(0, mn - greatest(0, round(6 * (1 + public.world_status_effect_total('mental_loss_pct') / 100.0))::int)); IF random() < 0.35 THEN statuses := array_append(statuses, 'shaken'); END IF; END IF;
          IF v_intent = 'venom' AND random() < 0.45 THEN statuses := array_append(statuses, 'poisoned'); END IF;
          IF v_intent = 'tide' AND random() < 0.3 THEN statuses := array_append(statuses, 'cold'); END IF;
          IF v_intent = 'breach' THEN er := least(100, er + greatest(1, round(4 * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int)); END IF;
          IF v_intent IN ('heavy', 'pounce') AND NOT guarding AND random() < 0.2 THEN statuses := array_append(statuses, 'bleeding'); END IF;
          IF g.gimmick_key IS NOT NULL THEN
            IF g.status IS NOT NULL AND random() < g.chance * (CASE WHEN guarding THEN 0.5 ELSE 1 END) THEN statuses := array_append(statuses, g.status); END IF;
            IF g.mental > 0 THEN mn := greatest(0, mn - greatest(0, round(g.mental * (CASE WHEN guarding THEN 0.5 ELSE 1 END) * (1 + public.world_status_effect_total('mental_loss_pct') / 100.0))::int)); END IF;
            IF g.erosion > 0 THEN er := least(100, er + greatest(1, round(g.erosion * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int)); END IF;
            IF g.gtype = 'drain' THEN mheal := round(mdmg * g.power2); a.current_hp := least(a.max_hp, a.current_hp + mheal); lines := lines || jsonb_build_array(m.monster_name || '이(가) 기운을 빨아 체력 ' || mheal || ' 회복'); END IF;
            IF g.gtype = 'grapple' THEN
              IF 'guarding_x30' = ANY (sk) THEN lines := lines || jsonb_build_array('「부동」 붙잡히지 않았다.');
              ELSE v_pfx := v_pfx || jsonb_build_object('bound', 1); lines := lines || jsonb_build_array('붙잡혔다. 다음 턴에는 달아날 수 없다.'); END IF;
            END IF;
          END IF;
        END IF;
      END IF;
      -- 만장성벽: 방어한 턴에는 상태이상이 붙지 않는다
      IF guarding AND 'guarding_m50' = ANY (sk) AND cardinality(statuses) > 0 THEN statuses := '{}'; lines := lines || jsonb_build_array('「만장성벽」 나쁜 기운을 모두 튕겨 냈다.'); END IF;
    END IF;
    IF a.current_hp <= 0 THEN ended := 'victory'; END IF;
    -- 기사회생: 체력이 25 아래로 떨어지면 한 번 +30
    IF ended IS NULL AND hp > 0 AND hp < 25 AND 'first_aid_m50' = ANY (sk) AND NOT coalesce((v_pfx ->> 'rallied')::boolean, false) THEN
      hp := least(100, hp + 30); v_pfx := v_pfx || jsonb_build_object('rallied', true); lines := lines || jsonb_build_array('「기사회생」 숨을 몰아쉬며 다시 섰다. 체력 +30');
    END IF;
    -- 금강불괴: 한 번 체력 1로 버틴다
    IF ended IS NULL AND hp <= 0 AND 'guarding_c43a' = ANY (sk) AND NOT coalesce((v_pfx ->> 'endured')::boolean, false) THEN
      hp := 1; v_pfx := v_pfx || jsonb_build_object('endured', true); lines := lines || jsonb_build_array('「금강불괴」 쓰러질 일격을 버텨 냈다. 체력 1');
    END IF;
    IF ended IS NULL AND hp <= 0 THEN
      IF coalesce((inv ->> 'revival_charm')::int, 0) > 0 AND NOT coalesce((v_pfx ->> 'revived')::boolean, false) THEN
        inv := public.world_inv_add(inv, 'revival_charm', -1); hp := 30; v_pfx := v_pfx || jsonb_build_object('revived', true);
        lines := lines || jsonb_build_array('쓰러지는 순간 회생 부적이 타올라 다시 일어섰다.');
      ELSE
        ended := 'defeat';
      END IF;
    END IF;
    IF ended IS NULL THEN
      next_intent := coalesce(next_intent, public.world_battle_intent_k(m.kind, a.mlevel, m.mechanic_key, a.current_hp::numeric / a.max_hp, a.rank));
    END IF;
    -- 도발: 방어한 턴에 적이 다음에 쓰려던 기믹을 버리고 나에게 달려든다
    IF ended IS NULL AND guarding AND 'melee_c43b' = ANY (sk) THEN
      v_pfx := v_pfx || jsonb_build_object('roar', 2); lines := lines || jsonb_build_array('「사자후」 포효가 울려 ' || m.monster_name || '의 시선이 내게 묶였다.');
    END IF;
    IF ended IS NULL AND coalesce((v_pfx ->> 'roar')::int, 0) > 0 AND next_intent LIKE 'g%:%' THEN next_intent := 'strike'; END IF;
    IF ended IS NULL AND NOT guarding AND coalesce((v_pfx ->> 'roar')::int, 0) > 0 THEN
      v_pfx := v_pfx || jsonb_build_object('roar', (v_pfx ->> 'roar')::int - 1); IF (v_pfx ->> 'roar')::int <= 0 THEN v_pfx := v_pfx - 'roar'; END IF;
    END IF;
    IF ended IS NULL AND guarding AND 'melee_c24b' = ANY (sk) AND next_intent LIKE 'g%:%' THEN
      next_intent := 'strike'; lines := lines || jsonb_build_array('「도발」 ' || m.monster_name || '이(가) 준비하던 수를 버리고 달려든다.');
    END IF;
  END IF;

  FOREACH k IN ARRAY statuses LOOP PERFORM public.world_field_status(uid, k, 'combat'); END LOOP;

  IF ended = 'victory' THEN
    rk_mul := CASE a.rank WHEN 'elite' THEN 1.8 WHEN 'guardian' THEN 3 ELSE 1 END;
    rare := public.world_status_effect_total('rare_loot_pct') + public.world_title_bonus('rare_loot_pct');
    xp := round((12 + a.mlevel * 6) * rk_mul * (CASE WHEN a.mlevel < c.level - 5 THEN 0.3 ELSE 1 END));
    gil_gain := round((2 + a.mlevel) * rk_mul);
    drop_p := least(1, (CASE a.rank WHEN 'elite' THEN 0.8 WHEN 'guardian' THEN 1 ELSE 0.6 END) * (1 + rare / 100.0));
    FOR k, v IN SELECT d.key, CASE WHEN jsonb_typeof(d.value) = 'number' THEN d.value::text::int ELSE 1 END FROM jsonb_each(coalesce(m.drops, '{}'::jsonb)) d LOOP
      IF EXISTS (SELECT 1 FROM public.world_item_catalog ic WHERE ic.item_id = k) AND random() < drop_p THEN
        qty := greatest(1, 1 + floor(random() * greatest(1, v))::int) * (CASE WHEN a.rank = 'guardian' THEN 2 ELSE 1 END);
        loot := public.world_inv_add(loot, k, qty);
      END IF;
    END LOOP;
    IF random() < 0.25 + rare / 100.0 THEN
      SELECT x INTO sig FROM public.world_region_profiles p, unnest(p.signature_items) x JOIN public.world_item_catalog ic ON ic.item_id = x
        WHERE p.region_id = a.region_id AND ic.tier <= 2 AND x NOT IN ('courier_token', 'spirit_compass') ORDER BY random() LIMIT 1;
      IF sig IS NOT NULL THEN loot := public.world_inv_add(loot, sig, 1); END IF;
    END IF;
    IF a.rank <> 'normal' AND random() < (CASE a.rank WHEN 'guardian' THEN 1 ELSE 0.3 END) THEN loot := public.world_inv_add(loot, 'monster_core', 1); END IF; sig := public.world_gear_roll(m.mechanic_key, a.mlevel, a.rank, rare); IF sig IS NOT NULL THEN loot := public.world_inv_add(loot, sig, 1); lines := lines || jsonb_build_array('장비를 얻었다: ' || (SELECT item_name FROM public.world_item_catalog WHERE item_id = sig)); END IF;
    IF loot = '{}'::jsonb THEN loot := public.world_inv_add(loot, CASE WHEN random() < 0.5 THEN 'spirit_dust' ELSE 'beast_bone' END, 1); END IF;
    FOR k, v IN SELECT key, value::text::int FROM jsonb_each(loot) LOOP inv := public.world_inv_add(inv, k, v); END LOOP;
    lines := lines || jsonb_build_array(m.monster_name || '을(를) 쓰러뜨렸다.');
    v_result := jsonb_build_object('outcome', 'victory', 'monster', m.monster_name, 'rank', a.rank, 'level', a.mlevel, 'xp', xp + 24, 'gil', gil_gain, 'loot', loot);
  ELSIF ended = 'defeat' THEN
    hp := 0;
    lines := lines || jsonb_build_array('정신이 아득해진다… 쓰러졌다.');
    v_result := jsonb_build_object('outcome', 'defeat', 'monster', m.monster_name);
  ELSIF ended = 'fled' THEN
    v_result := jsonb_build_object('outcome', 'fled', 'monster', m.monster_name);
  END IF;

  UPDATE public.world_characters SET health = hp, mental = mn, spiritual_power = sp, erosion = er,
    erosion_stage = CASE WHEN er >= 80 THEN 4 WHEN er >= 55 THEN 3 WHEN er >= 30 THEN 2 WHEN er >= 10 THEN 1 ELSE 0 END,
    inventory = inv, gil = gil + gil_gain, experience = experience + greatest(0, xp), updated_at = now()
  WHERE owner_id = uid;

  UPDATE public.world_active_encounters SET current_hp = a.current_hp, turn_count = turn, fx = v_fx, pfx = v_pfx,
    intent = CASE WHEN ended IS NULL THEN next_intent ELSE v_intent END,
    defeated = coalesce(ended = 'victory', false), fled = coalesce(ended IN ('fled', 'defeat'), false), result = v_result,
    log = (SELECT coalesce(jsonb_agg(x ORDER BY o), '[]'::jsonb) FROM (SELECT x, o FROM jsonb_array_elements(a.log || lines) WITH ORDINALITY t(x, o) ORDER BY o DESC LIMIT 14) s),
    last_action_at = now(), updated_at = now()
  WHERE owner_id = uid;

  IF ended = 'victory' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'combat', m.monster_name || ' 토벌' || CASE a.rank WHEN 'elite' THEN '(정예)' WHEN 'guardian' THEN '(우두머리)' ELSE '' END,
      jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id, 'monster_name', m.monster_name, 'defeated', true,
        'mechanic', m.mechanic_key, 'action', CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'seal' ELSE 'attack' END,
        'rank', a.rank, 'level', a.mlevel, 'loot', loot, 'turns', turn,
        'acts', jsonb_build_object('analysis', coalesce((v_pfx ->> 'u_an')::int, 0), 'guarding', coalesce((v_pfx ->> 'u_gd')::int, 0), 'first_aid', coalesce((v_pfx ->> 'u_fa')::int, 0))));
  ELSIF ended = 'defeat' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'battle_lost', m.monster_name || '에게 쓰러졌습니다.', jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id));
  ELSIF ended = 'fled' THEN
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, 'battle_fled', m.monster_name || '에게서 달아났습니다.', jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id));
  END IF;

  RETURN jsonb_build_object('ok', true, 'lines', lines, 'ended', ended, 'result', v_result, 'damage', dmg + ex_total, 'taken', mdmg, 'heal', heal,
    'crit', crit, 'health', hp, 'battle', public.world_field_battle_view(uid), 'next_action_at', now() + interval '1 second');
END $function$;
grant select on public.world_monster_codex to fn_owner_field;

-- 채집: 4.0.0 동작은 그대로 두고 채집 계열 고유 효과를 더한 새 판.
-- 일반 채집 효과는 모든 채집터에, 약초·광맥·영기 채집 효과는 그 갈래 채집터(herbs·ore·spirit)에만 붙는다.
-- 채집터 대기(5분)를 줄이는 효과는 last_gathered_at을 앞당겨 적는다(새 열 없음).
create or replace function public.world_field_gather(p_spot_id uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
DECLARE uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_gathering_spots%rowtype;
  d public.world_gathering_discoveries%rowtype; it text; qty int; tool_bonus int := 0; inv jsonb; left_st int; prof_match boolean; nm text;
  sk text[]; line text; rg public.world_map_regions%rowtype; mult int := 1; mnote text; notes text[] := '{}'; extra jsonb := '{}'::jsonb;
  wait_s int := 300; dhp int := 0; dmn int := 0; dsp int := 0; der int := 0; gil_gain int := 0; no_wear boolean := false; free_st boolean := false;
  x text; k text; v int;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(c.is_dead, false) OR c.downed_at IS NOT NULL OR c.health <= 0 THEN RAISE EXCEPTION '전투불능 상태에서는 채집할 수 없습니다.'; END IF;
  IF c.travel_arrives_at IS NOT NULL AND c.travel_arrives_at > now() THEN RAISE EXCEPTION '이동 중에는 채집할 수 없습니다.'; END IF;
  IF EXISTS (SELECT 1 FROM public.world_active_encounters a WHERE a.owner_id = uid AND NOT a.defeated AND NOT coalesce(a.fled, false)) THEN
    RAISE EXCEPTION '전투 중에는 채집할 수 없습니다.'; END IF;
  SELECT * INTO s FROM public.world_gathering_spots WHERE spot_id = p_spot_id AND active AND node_id = c.current_exploration_node_id;
  IF NOT FOUND THEN RAISE EXCEPTION '지금 있는 곳의 채집터가 아닙니다.'; END IF;
  SELECT * INTO d FROM public.world_gathering_discoveries WHERE owner_id = uid AND spot_id = s.spot_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '먼저 탐색으로 채집터를 찾으세요.'; END IF;
  IF d.last_gathered_at IS NOT NULL AND d.last_gathered_at > now() - interval '5 minutes' THEN
    RAISE EXCEPTION '%', format('이 채집터는 %s초 뒤에 다시 쓸 수 있습니다.', ceil(extract(epoch FROM d.last_gathered_at + interval '5 minutes' - now()))::int); END IF;
  IF c.level < s.min_level THEN RAISE EXCEPTION '%', format('레벨 %s부터 채집할 수 있습니다.', s.min_level); END IF;
  sk := public.world_skill_procs(uid);
  line := CASE s.category WHEN 'herbs' THEN 'herbalism' WHEN 'ore' THEN 'mining' WHEN 'spirit' THEN 'spirit_gathering' ELSE 'foraging' END;
  rg := public.world_field_region(c.location);
  IF 'foraging_m50' = ANY (sk) AND random() < 0.25 THEN free_st := true; notes := notes || '「산천의 은혜」 탐색력을 쓰지 않았다'::text; END IF;
  left_st := public.world_stamina_change(uid, CASE WHEN free_st THEN 0 ELSE -1 END);
  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid;
  SELECT round(coalesce((i.equipment_traits ->> 'gathering_bonus_pct')::numeric, 0))::int INTO tool_bonus FROM public.world_character_equipment e
    JOIN public.world_item_catalog i ON i.item_id = e.item_id WHERE e.owner_id = uid AND e.slot = 'tool';
  it := s.loot_items[1 + floor(random() * cardinality(s.loot_items))::int];
  qty := s.yield_min + floor(random() * (s.yield_max - s.yield_min + 1))::int + coalesce(c.gathering_rank, 1) / 12;
  prof_match := (c.gathering_profession = 'mining' AND s.category = 'ore') OR (c.gathering_profession = 'botany' AND s.category = 'herbs')
    OR (c.gathering_profession = 'spirit_harvest' AND s.category = 'spirit') OR (c.gathering_profession = 'fishing' AND s.category = 'water')
    OR (c.gathering_profession = 'fieldwork' AND s.category IN ('wood', 'supplies', 'relics'));
  IF prof_match THEN qty := qty + 1; END IF;
  IF EXISTS (SELECT 1 FROM public.world_character_equipment e JOIN public.world_item_durability dd ON dd.owner_id = e.owner_id AND dd.item_id = e.item_id
             WHERE e.owner_id = uid AND e.slot = 'tool' AND dd.durability <= 0) THEN tool_bonus := 0; END IF;
  no_wear := (line = 'herbalism' AND 'herbalism_x30' = ANY (sk)) OR (line = 'mining' AND 'mining_x30' = ANY (sk));
  IF NOT no_wear THEN PERFORM public.world_durability_wear(uid, 'tool', 1); END IF;
  qty := greatest(1, round(qty * (1 + (coalesce(tool_bonus, 0) + public.world_status_effect_total('gather_qty_pct') + public.world_title_bonus('gather_qty_pct')) / 100.0)));

  -- 몇 배 거두기: 굴림마다 따로, 가장 큰 배수 하나만
  IF 'foraging_c24a' = ANY (sk) AND random() < 0.15 AND mult < 2 THEN mult := 2; mnote := '「넓게 줍기」 두 번 거뒀다'; END IF;
  IF 'foraging_c43a' = ANY (sk) AND random() < 0.10 AND mult < 3 THEN mult := 3; mnote := '「대풍」 세 배로 거뒀다'; END IF;
  IF line = 'herbalism' THEN
    IF 'herbalism_c24a' = ANY (sk) AND random() < 0.15 AND mult < 2 THEN mult := 2; mnote := '「깊이 캐기」 두 번 거뒀다'; END IF;
    IF 'herbalism_c43a' = ANY (sk) AND random() < 0.10 AND mult < 3 THEN mult := 3; mnote := '「약초 군락」 세 배로 거뒀다'; END IF;
  ELSIF line = 'mining' THEN
    IF 'mining_c24a' = ANY (sk) AND random() < 0.15 AND mult < 2 THEN mult := 2; mnote := '「힘껏 캐기」 두 번 캤다'; END IF;
    IF 'mining_c43a' = ANY (sk) AND random() < 0.05 AND mult < 5 THEN mult := 5; mnote := '「노다지」 다섯 배로 캤다'; END IF;
  ELSIF line = 'spirit_gathering' THEN
    IF 'spirit_gathering_c43a' = ANY (sk) AND random() < 0.15 AND mult < 2 THEN mult := 2; mnote := '「영기 폭주」 두 번 거뒀다'; END IF;
  END IF;
  qty := qty * mult;
  IF mnote IS NOT NULL THEN notes := notes || mnote; END IF;

  -- 덤과 몸에 오는 것
  IF 'foraging_x13' = ANY (sk) AND cardinality(s.loot_items) > 1 AND random() < 0.10 THEN
    SELECT y INTO x FROM unnest(s.loot_items) y WHERE y <> it ORDER BY random() LIMIT 1;
    IF x IS NOT NULL THEN extra := public.world_inv_add(extra, x, 1); notes := notes || ('「눈썰미」 덤: ' || (SELECT item_name FROM public.world_item_catalog WHERE item_id = x)); END IF;
  END IF;
  IF ('foraging_c24b' = ANY (sk) AND random() < 0.10) OR (line = 'spirit_gathering' AND 'spirit_gathering_m50' = ANY (sk) AND random() < 0.20) THEN
    x := NULL;
    SELECT y INTO x FROM public.world_region_profiles p, unnest(p.signature_items) y JOIN public.world_item_catalog ic ON ic.item_id = y
     WHERE p.region_id = rg.region_id AND y NOT IN ('courier_token', 'spirit_compass') ORDER BY random() LIMIT 1;
    IF x IS NOT NULL THEN extra := public.world_inv_add(extra, x, 1); notes := notes || ('희귀품: ' || (SELECT item_name FROM public.world_item_catalog WHERE item_id = x)); END IF;
  END IF;
  IF 'foraging_c43b' = ANY (sk) AND random() < 0.10 THEN
    gil_gain := 10 + coalesce(rg.danger_level, 1) * 10; notes := notes || ('「보물 감별」 묻혀 있던 옛 엽전 ' || gil_gain || '전');
  END IF;
  IF line = 'herbalism' THEN
    IF 'herbalism_x13' = ANY (sk) AND random() < 0.10 THEN extra := public.world_inv_add(extra, 'herbal_extract', 1); notes := notes || '「잎맥 살피기」 농축 약초액 덤'::text; END IF;
    IF 'herbalism_c24b' = ANY (sk) THEN dhp := dhp + 3; END IF;
    IF 'herbalism_c43b' = ANY (sk) AND coalesce(rg.danger_level, 0) >= 7 AND random() < 0.03 THEN extra := public.world_inv_add(extra, 'gwiryeong_cho', 1); notes := notes || '「영초 감별」 귀령초를 찾았다'::text; END IF;
    IF 'herbalism_m50' = ANY (sk) THEN dhp := dhp + 2; dmn := dmn + 2; der := der + 1; END IF;
  ELSIF line = 'mining' THEN
    IF 'mining_x13' = ANY (sk) AND random() < 0.10 THEN extra := public.world_inv_add(extra, 'charcoal', 1); notes := notes || '「광맥 읽기」 정련 숯 덤'::text; END IF;
    IF 'mining_c24b' = ANY (sk) AND random() < 0.10 THEN extra := public.world_inv_add(extra, 'iron_ingot', 1); notes := notes || '「옥석 가리기」 월철 주괴'::text; END IF;
    IF 'mining_c43b' = ANY (sk) AND random() < 0.08 THEN extra := public.world_inv_add(extra, 'steel_ingot', 1); notes := notes || '「보석 눈」 강철 주괴'::text; END IF;
  ELSIF line = 'spirit_gathering' THEN
    IF 'spirit_gathering_x13' = ANY (sk) THEN der := der + 1; END IF;
    IF 'spirit_gathering_c24a' = ANY (sk) THEN dsp := dsp + 5; END IF;
    IF 'spirit_gathering_c24b' = ANY (sk) THEN
      UPDATE public.world_character_statuses SET expires_at = now() WHERE status_id = (SELECT cs.status_id FROM public.world_character_statuses cs JOIN public.world_status_catalog sc USING (status_key)
        WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' ORDER BY cs.expires_at LIMIT 1);
      IF FOUND THEN notes := notes || '「정화 채집」 나쁜 상태 하나가 풀렸다'::text; END IF;
    END IF;
    IF 'spirit_gathering_x30' = ANY (sk) AND random() < 0.10 THEN extra := public.world_inv_add(extra, 'spirit_core', 1); notes := notes || '「영맥 조율」 응축 영핵'::text; END IF;
    IF 'spirit_gathering_c43b' = ANY (sk) THEN dmn := dmn + 6; END IF;
  END IF;
  IF dhp + dmn + dsp + der > 0 THEN
    notes := notes || concat_ws(' · ', CASE WHEN dhp > 0 THEN '체력 +' || dhp END, CASE WHEN dmn > 0 THEN '정신 +' || dmn END,
      CASE WHEN dsp > 0 THEN '영력 +' || dsp END, CASE WHEN der > 0 THEN '침식 -' || der END);
  END IF;

  -- 채집터 대기
  IF 'foraging_x30' = ANY (sk) THEN wait_s := 240; END IF;
  IF (line = 'mining' AND 'mining_m50' = ANY (sk)) OR (line = 'spirit_gathering' AND 'combo_analysis_spirit_gathering' = ANY (sk)) THEN wait_s := wait_s / 2; END IF;

  inv := public.world_inv_add(c.inventory, it, qty);
  FOR k, v IN SELECT key, value::text::int FROM jsonb_each(extra) LOOP inv := public.world_inv_add(inv, k, v); END LOOP;
  UPDATE public.world_characters SET inventory = inv, gil = gil + gil_gain, health = least(100, health + dhp), mental = least(100, mental + dmn),
    spiritual_power = least(100, spiritual_power + dsp), erosion = greatest(0, erosion - der), updated_at = now() WHERE owner_id = uid;
  UPDATE public.world_gathering_discoveries SET last_gathered_at = now() - make_interval(secs => 300 - wait_s), gather_count = gather_count + 1 WHERE owner_id = uid AND spot_id = s.spot_id;
  SELECT item_name INTO nm FROM public.world_item_catalog WHERE item_id = it;
  INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
  VALUES (uid, c.character_name, 'gather', s.spot_name || '에서 ' || nm || ' ×' || qty || ' 채집',
    jsonb_build_object('spot_id', s.spot_id, 'category', s.category, 'item_id', it, 'qty', qty, 'node_id', s.node_id,
      'node', CASE s.category WHEN 'ore' THEN 'ore' WHEN 'herbs' THEN 'herb' WHEN 'spirit' THEN 'shrine' ELSE 'field' END, 'profession_match', prof_match, 'extra', extra));
  RETURN jsonb_build_object('ok', true, 'content', s.spot_name || '에서 ' || nm || ' ×' || qty || '을(를) 얻었습니다.' || CASE WHEN prof_match THEN ' (전문 분야 +1)' ELSE '' END
      || CASE WHEN cardinality(notes) > 0 THEN ' ' || array_to_string(notes, ' · ') || '.' ELSE '' END,
    'item_id', it, 'qty', qty, 'extra', extra, 'stamina', left_st, 'ready_at', now() + make_interval(secs => wait_s));
END $function$;

-- 제작: 4.0.0 동작(창고 재료·가방 자리·도구 계열)은 그대로 두고 단조·연금·결계 각인 고유 효과를 더한 새 판.
-- 계열은 제작으로 오르는 기술과 같다: 제작법의 required_skill(단조·연금·결계 각인), 없으면 분야(연금→연금, 봉인 공예→결계 각인, 요리→없음, 그 밖→단조).
create or replace function public.world_craft_item(p_recipe_id text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_crafting_recipes%rowtype; inv jsonb; tool_tier int:=0; k text; need int; have int; out_qty int; quality int; result_text text; loc_bonus int:=0; st jsonb; take int; from_st jsonb := '{}'::jsonb; room int;
 sk text[]; line text; rq int; free_mat boolean := false; is_gear boolean; notes text[] := '{}'; rf text; dhp int := 0; dmn int := 0; der int := 0;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select * into c from public.world_characters where owner_id=uid for update; if found and (c.downed_at is not null or c.health<=0) then raise exception '전투불능 상태입니다. 다른 조사원의 구조를 받아야 행동할 수 있습니다.'; end if;
 if not found then raise exception '캐릭터를 먼저 생성하세요.'; end if;
 select * into r from public.world_crafting_recipes where recipe_id=p_recipe_id;
 if not found then raise exception '존재하지 않는 제작법입니다.'; end if;
 if c.level<r.minimum_level then raise exception '이 제작법은 레벨 %부터 해금됩니다.',r.minimum_level; end if; if r.required_skill is not null and coalesce((c.skill_progress->r.required_skill->>'rank')::int,1)<r.required_skill_rank then raise exception '% 기술 %단계가 필요합니다(지금 %단계). 캐릭터 › 기술에서 확인하세요.',case r.required_skill when 'alchemy' then '연금' when 'smithing' then '단조' when 'spirit_gathering' then '영기 채집' when 'wardcraft' then '결계 각인' else r.required_skill end,r.required_skill_rank,coalesce((c.skill_progress->r.required_skill->>'rank')::int,1); end if; if r.required_job is not null and c.job_key<>r.required_job then raise exception '필요 직업: %',case r.required_job when 'exorcist' then '퇴마관' when 'scout' then '현장 조사원' when 'medic' then '의무관' when 'sealmaster' then '봉인술사' when 'analyst' then '기록 분석관' when 'artificer' then '법구 제작사' else r.required_job end; end if;
 if r.required_location is not null and (coalesce(c.location,'')=r.required_location or (r.required_location='야행국 본부 정청' and c.location in ('본부 로비','야행국 본부 · 정청')) or (r.required_location='연무장·팔괘진' and c.location in ('훈련실','야행국 본부 · 연무장')) or (r.required_location='장서각 지하서고' and c.location in ('기록 보관실','야행국 본부 · 장서각'))) then loc_bonus:=12; end if;
 sk := public.world_skill_procs(uid);
 line := case when r.required_skill in ('smithing','alchemy','wardcraft') then r.required_skill when r.required_skill is not null then null
   when r.craft_field = 'alchemy' then 'alchemy' when r.craft_field = 'sealing' then 'wardcraft' when r.craft_field = 'cooking' then null else 'smithing' end;
 select i.category in ('weapon','armor','hat','shoes','norigae','amulet','mask','tool') into is_gear from public.world_item_catalog i where i.item_id = r.output_item;
 inv:=coalesce(c.inventory,'{}'::jsonb);
 if exists (select 1 from public.world_current_shop(uid)) then select items into st from public.world_storage where owner_id=uid for update; end if;
 st:=coalesce(st,'{}'::jsonb);
 if r.required_tool is not null then
  select max(coalesce(i.tier,0)) into tool_tier from public.world_item_catalog i where public.world_tool_covers(i.item_id, r.required_tool) and (coalesce((c.inventory->>i.item_id)::numeric,0)>0 or exists (select 1 from public.world_character_equipment e where e.owner_id=uid and e.item_id=i.item_id));
  if tool_tier is null then raise exception '필요 도구가 가방에 있어야 합니다: %',coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id=r.required_tool),r.required_tool); end if;
  if coalesce(tool_tier,0)<r.required_tool_tier then raise exception '도구 단계가 부족합니다. 필요 단계: %',r.required_tool_tier; end if;
 end if;
 for k,need in select key,value::text::int from jsonb_each(r.ingredients) loop
  have:=coalesce((inv->>k)::int,0)+coalesce((st->>k)::int,0); if have<need then raise exception '재료 부족: % (필요 %, 보유 %)',coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id=k),k),need,have; end if;
 end loop;
 -- 천하명장: 단조 제작 10%는 재료를 하나도 쓰지 않는다
 free_mat := line = 'smithing' and 'smithing_m50' = any (sk) and random() < 0.10;
 if free_mat then notes := notes || '「천하명장」 재료를 하나도 쓰지 않았다'::text;
 else
  for k,need in select key,value::text::int from jsonb_each(r.ingredients) loop
   take:=least(need,greatest(0,coalesce((inv->>k)::int,0)));
   inv:=jsonb_set(inv,array[k],to_jsonb(coalesce((inv->>k)::int,0)-take),true);
   if need-take>0 then st:=jsonb_set(st,array[k],to_jsonb(coalesce((st->>k)::int,0)-(need-take))); from_st:=from_st||jsonb_build_object(k,need-take); end if;
  end loop;
 end if;
 if from_st<>'{}'::jsonb then
  update public.world_storage set items=(select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) from jsonb_each(st) where jsonb_typeof(value)='number' and value::text::int>0),updated_at=now() where owner_id=uid;
 end if;
 room:=public.world_bag_room(inv,r.output_item,public.world_bag_limit(uid));
 if room<r.output_qty then raise exception '가방에 완성품을 넣을 자리가 없습니다. 가방을 한 칸 비운 뒤 다시 제작하세요.'; end if;
 -- 섬세한 단조·화후 조절·겹결계: 품질 굴림을 두 번 해 높은 쪽
 rq := floor(random()*20)::int;
 if (line = 'smithing' and 'smithing_c24a' = any (sk)) or (line = 'alchemy' and 'alchemy_x30' = any (sk)) or (line = 'wardcraft' and 'wardcraft_x30' = any (sk)) then
  rq := greatest(rq, floor(random()*20)::int);
 end if;
 quality:=least(100,greatest(0,10+coalesce(c.crafting_xp,0)/20+(case when r.craft_field = 'cooking' then coalesce(c.cooking_rank, 1) * 3 else round(coalesce(c.crafting_rank, 1) * 1.2) end)+case when c.job_key='artificer' then 15 else 0 end+coalesce((c.skill_progress->r.required_skill->>'rank')::int,1)*2+case when c.crafting_profession = r.craft_field then 12 when c.crafting_profession = 'general' then 4 else 0 end+case when exists(select 1 from public.world_character_equipment e join public.world_item_catalog i on i.item_id=e.item_id where e.owner_id=uid and i.crafting_specialization=r.required_skill) then 10 else 0 end-r.recipe_difficulty*8+rq+(public.world_status_effect_total('craft_quality')+public.world_title_bonus('craft_quality'))+public.world_status_effect_total('action_quality_pct')+loc_bonus));
 out_qty:=r.output_qty;
 if quality>=85 then out_qty:=out_qty+greatest(1,ceil(r.output_qty*0.5)::int); end if;
 if quality>=85 and ((line = 'smithing' and 'smithing_x30' = any (sk) and not coalesce(is_gear, false)) or (line = 'wardcraft' and 'wardcraft_c43a' = any (sk))) then
  out_qty := out_qty + 1; notes := notes || (case when line = 'smithing' then '「명장의 눈」' else '「천하 각인」' end || ' 하나 더');
 end if;
 if (line = 'alchemy' and 'alchemy_c24a' = any (sk) and random() < 0.15) or (line = 'wardcraft' and 'wardcraft_c24a' = any (sk) and random() < 0.15) then
  out_qty := out_qty + 1; notes := notes || (case when line = 'alchemy' then '「농축」' else '「정교한 각인」' end || ' 하나 더');
 end if;
 if (line = 'alchemy' and 'alchemy_m50' = any (sk) and random() < 0.20) or (line = 'wardcraft' and 'wardcraft_m50' = any (sk) and random() < 0.20) then
  out_qty := out_qty * 2; notes := notes || (case when line = 'alchemy' then '「구전금단」' else '「만법귀일」' end || ' 두 배로 만들었다');
 end if;
 out_qty := greatest(r.output_qty, least(room, out_qty));
 inv:=jsonb_set(inv,array[r.output_item],to_jsonb(coalesce((inv->>r.output_item)::int,0)+out_qty),true);
 -- 재료 돌려받기(불꽃 담금·달이기·먹 고르기 10%, 금단 30%는 가장 비싼 재료)
 if not free_mat then
  if (line = 'smithing' and 'smithing_x13' = any (sk)) or (line = 'alchemy' and 'alchemy_x13' = any (sk)) or (line = 'wardcraft' and 'wardcraft_x13' = any (sk)) then
   if random() < 0.10 then
    select key into rf from jsonb_each(r.ingredients) order by random() limit 1;
    if rf is not null then inv := jsonb_set(inv, array[rf], to_jsonb(coalesce((inv->>rf)::int,0)+1), true);
      notes := notes || ('재료를 아껴 ' || coalesce((select item_name from public.world_item_catalog where item_id = rf), '재료') || ' 하나를 돌려받았다'); end if;
   end if;
  end if;
  if line = 'alchemy' and 'alchemy_c43a' = any (sk) and random() < 0.30 then
   rf := null;
   select j.key into rf from jsonb_each(r.ingredients) j left join public.world_item_catalog ic on ic.item_id = j.key order by coalesce(ic.reference_price, 0) desc limit 1;
   if rf is not null then inv := jsonb_set(inv, array[rf], to_jsonb(coalesce((inv->>rf)::int,0)+1), true);
     notes := notes || ('「금단」 ' || coalesce((select item_name from public.world_item_catalog where item_id = rf), '재료') || ' 하나를 돌려받았다'); end if;
  end if;
 end if;
 -- 마친 뒤 몸에 오는 것
 if line = 'alchemy' and 'alchemy_c24b' = any (sk) then dhp := dhp + 5; dmn := dmn + 5; end if;
 if line = 'wardcraft' and 'wardcraft_c24b' = any (sk) then der := der + 2; end if;
 if line = 'wardcraft' and 'wardcraft_c43b' = any (sk) then dmn := dmn + 6; end if;
 if line = 'alchemy' and 'alchemy_c43b' = any (sk) then
  update public.world_character_statuses set expires_at = now() where status_id = (select cs.status_id from public.world_character_statuses cs join public.world_status_catalog sc using (status_key)
    where cs.owner_id = uid and cs.expires_at > now() and sc.polarity = 'negative' order by cs.expires_at limit 1);
  if found then notes := notes || '「영약 조제」 나쁜 상태 하나가 풀렸다'::text; end if;
 end if;
 if dhp + dmn + der > 0 then
  notes := notes || concat_ws(' · ', case when dhp > 0 then '체력 +' || dhp end, case when dmn > 0 then '정신 +' || dmn end, case when der > 0 then '침식 -' || der end);
 end if;
 update public.world_characters set inventory=inv,crafting_successes=crafting_successes+1,crafting_quality=crafting_quality+quality,
   health=least(100,health+dhp),mental=least(100,mental+dmn),erosion=greatest(0,erosion-der),updated_at=now() where owner_id=uid;
 if r.craft_field = 'cooking' then update public.world_characters set cooking_xp = cooking_xp + 10 + r.recipe_difficulty * 5, cooking_rank = least(20, 1 + (cooking_xp + 10 + r.recipe_difficulty * 5) / 120) where owner_id = uid; end if;
 result_text:='제작 성공: '||r.recipe_name||' → '||coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id=r.output_item),r.output_item)||' ×'||out_qty||' · 품질 '||quality||case when loc_bonus>0 then ' · 제작 장소 가산 +'||loc_bonus else '' end||case when quality>=85 then ' · 고품질 추가 생산!' else '' end||case when from_st<>'{}'::jsonb then ' · 창고 재료 사용' else '' end
   ||case when cardinality(notes) > 0 then ' · '||array_to_string(notes, ' · ') else '' end;
 insert into public.world_events(actor_id,actor_name,event_type,content,payload) values(uid,c.character_name,'craft',result_text,jsonb_build_object('recipe',r.recipe_id,'output',r.output_item,'qty',out_qty,'quality',quality,'difficulty',r.recipe_difficulty));
 return jsonb_build_object('content',result_text,'inventory',inv,'recipe',r.recipe_id,'output',r.output_item,'qty',out_qty,'quality',quality,'location_bonus',loc_bonus,'from_storage',from_st);
end $function$;


-- 제작 함수 주인(fn_owner_18452)이 연금 「영약 조제」로 나쁜 상태를 풀 수 있게(그 역할에만, 이용자 권한은 그대로)
grant select, update on public.world_character_statuses to fn_owner_18452;
grant select on public.world_status_catalog to fn_owner_18452;

-- 이동·탐색·휴식·강화·수리·구조: 함수 전체를 다시 쓰지 않고 한 줄씩 정확히 바꾼다(찾는 자리가 정해진 수가 아니면 멈춘다).
do $$
declare p record; d text; n int;
begin
  for p in select * from (values
    -- 이동: 샛길(구간마다 10% 운임 면제), 바람처럼(걸어갈 때 이동 시간 −25%)
    (1, 'public.world_travel_route(text)', $a$vis int; fare_per int; fare int := 0; walked boolean := false; arrives timestamptz; fee int; names text[] := '{}'; nb text;$a$,
        $a$vis int; fare_per int; fare int := 0; walked boolean := false; arrives timestamptz; fee int; names text[] := '{}'; nb text; sk text[]; n_free int := 0;$a$, 1),
    (2, 'public.world_travel_route(text)', $a$  fare := coalesce(fare_per, 0) * (cardinality(path) - 1);$a$,
        $a$  sk := public.world_skill_procs(uid);
  IF 'tracking_c24b' = ANY (sk) AND coalesce(fare_per, 0) > 0 THEN SELECT count(*) INTO n_free FROM generate_series(1, cardinality(path) - 1) WHERE random() < 0.1; END IF;
  fare := coalesce(fare_per, 0) * (cardinality(path) - 1 - n_free);$a$, 1),
    (3, 'public.world_travel_route(text)', $a$IF fare > 0 AND c.mount_tokens < fare THEN speed := 1; walked := true; fare := 0; END IF;$a$,
        $a$IF fare > 0 AND c.mount_tokens < fare THEN speed := 1; walked := true; fare := 0; n_free := 0; END IF;
  IF (walked OR c.mount_id IS NULL) AND 'tracking_c43b' = ANY (sk) THEN speed := speed / 0.75; END IF;$a$, 1),
    (4, 'public.world_travel_route(text)', $a$'(으)로 출발했습니다. ' || CASE WHEN walked$a$,
        $a$'(으)로 출발했습니다. ' || CASE WHEN n_free > 0 THEN '「샛길」 ' || n_free || '구간은 운임 없이 지납니다. ' ELSE '' END || CASE WHEN walked$a$, 1),
    -- 탐색: 흙자국 살피기·끈질긴 추적·기척 숨기기·명탐·만리추적
    (5, 'public.world_field_search()', $a$hurt int; stkey text; site text; omen int;$a$,
        $a$hurt int; stkey text; site text; omen int; sk text[]; free_st boolean := false; sneak boolean := false;$a$, 1),
    (6, 'public.world_field_search()', $a$  left_st := public.world_stamina_change(uid, -1);$a$,
        $a$  sk := public.world_skill_procs(uid);
  free_st := 'tracking_m50' = ANY (sk) AND random() < 0.15;
  left_st := public.world_stamina_change(uid, CASE WHEN free_st THEN 0 ELSE -1 END);$a$, 1),
    (7, 'public.world_field_search()', $a$w_path := 22 + CASE WHEN c.job_key = 'scout' THEN 8 ELSE 0 END + CASE WHEN depth = 0 THEN 20 ELSE 0 END;$a$,
        $a$w_path := (22 + CASE WHEN c.job_key = 'scout' THEN 8 ELSE 0 END + CASE WHEN depth = 0 THEN 20 ELSE 0 END) * CASE WHEN 'tracking_c24a' = ANY (sk) THEN 2 ELSE 1 END;$a$, 1),
    (8, 'public.world_field_search()', $a$  tot := w_path + w_spot + w_enc + w_cache + w_clue + w_reg + w_haz + w_omen + w_quiet;$a$,
        $a$  IF 'tracking_c43a' = ANY (sk) THEN w_clue := w_clue * 2; END IF;
  tot := w_path + w_spot + w_enc + w_cache + w_clue + w_reg + w_haz + w_omen + w_quiet;$a$, 1),
    (9, 'public.world_field_search()', $a$    battle := public.world_battle_open(uid, r.region_id, n.node_id, depth, c.level);$a$,
        $a$    IF 'tracking_x30' = ANY (sk) AND random() < 0.25 THEN battle := NULL; sneak := true;
    ELSE battle := public.world_battle_open(uid, r.region_id, n.node_id, depth, c.level); END IF;$a$, 1),
    (10, 'public.world_field_search()', $a$IF battle IS NULL THEN outcome := 'quiet'; txt := '수상한 기척이 있었지만 이내 사라졌다.';$a$,
        $a$IF battle IS NULL THEN outcome := 'quiet'; txt := CASE WHEN sneak THEN '「기척 숨기기」 요괴의 기척을 먼저 알아채고 들키지 않고 지나쳤다.' ELSE '수상한 기척이 있었지만 이내 사라졌다.' END;$a$, 1),
    (11, 'public.world_field_search()', $a$    xp := 20; payload := jsonb_build_object('chapter_id'$a$,
        $a$    xp := CASE WHEN 'tracking_x13' = ANY (sk) AND random() < 0.1 THEN 40 ELSE 20 END; payload := jsonb_build_object('chapter_id'$a$, 1),
    (12, 'public.world_field_search()', $a$  UPDATE public.world_characters SET inventory = inv, gil = gil + gil_gain, experience = experience + xp, updated_at = now() WHERE owner_id = uid;$a$,
        $a$  IF free_st THEN txt := txt || ' (「만리추적」 탐색력을 쓰지 않았다)'; END IF;
  UPDATE public.world_characters SET inventory = inv, gil = gil + gil_gain, experience = experience + xp, updated_at = now() WHERE owner_id = uid;$a$, 1),
    -- 휴식: 현장 조제(약초 2개 → 농축 약초액 하나)
    (13, 'public.world_field_rest(text)', $a$rest_wait interval; stg int := 0; gain text;$a$, $a$rest_wait interval; stg int := 0; gain text; brew boolean := false;$a$, 1),
    (14, 'public.world_field_rest(text)', $a$  GET DIAGNOSTICS cleared = ROW_COUNT;$a$,
        $a$  GET DIAGNOSTICS cleared = ROW_COUNT;
  brew := 'combo_foraging_alchemy' = ANY (public.world_skill_procs(uid)) AND coalesce((c.inventory ->> 'herb')::int, 0) >= 2;$a$, 1),
    (15, 'public.world_field_rest(text)', $a$  UPDATE public.world_characters SET health = least(100, health + hp),$a$,
        $a$  UPDATE public.world_characters SET inventory = CASE WHEN brew THEN public.world_inv_add(public.world_inv_add(inventory, 'herb', -2), 'herbal_extract', 1) ELSE inventory END, health = least(100, health + hp),$a$, 1),
    (16, 'public.world_field_rest(text)', $a$hp, mn, sp, er, stg);$a$,
        $a$hp, mn, sp, er, stg) || CASE WHEN brew THEN ' · 「현장 조제」 농축 약초액 +1' ELSE '' END;$a$, 1),
    -- 강화: 일품 단조(+10%p) — 강화 견적과 실제 강화 둘 다
    (17, 'public.world_weapon_enhance()', $a$case when c.job_key = 'artificer' then 10 else 0 end);$a$,
        $a$case when c.job_key = 'artificer' then 10 else 0 end + case when 'smithing_c43a' = any (public.world_skill_procs(uid)) then 10 else 0 end);$a$, 1),
    (18, 'public.world_enhance_quote()', $a$case when c.job_key = 'artificer' then 10 else 0 end);$a$,
        $a$case when c.job_key = 'artificer' then 10 else 0 end + case when 'smithing_c43a' = any (public.world_skill_procs(uid)) then 10 else 0 end);$a$, 1),
    -- 수리: 현장 수리(수리 도구가 전부 되살림), 강철 피부(대장간 수리비 절반) — 수리 견적·하나 수리·모두 수리
    (19, 'public.world_equipment_repair(text,text)', $a$    nxt := least(mx, cur + ceil(mx * 0.5)::int);$a$,
        $a$    nxt := CASE WHEN 'smithing_c24b' = ANY (public.world_skill_procs(uid)) THEN mx ELSE least(mx, cur + ceil(mx * 0.5)::int) END;$a$, 1),
    (20, 'public.world_equipment_repair(text,text)', $a$    cost := greatest(5, ceil((mx - cur) * (coalesce(it.tier, 1) + 1) / 2.0)::int);$a$,
        $a$    cost := greatest(5, ceil((mx - cur) * (coalesce(it.tier, 1) + 1) / 2.0)::int);
    IF 'smithing_c43b' = ANY (public.world_skill_procs(uid)) THEN cost := greatest(2, cost / 2); END IF;$a$, 1),
    (21, 'public.world_repair_quote()', $a$with me as (select public.fn_owner_auth_uid() as uid),$a$,
        $a$with me as (select public.fn_owner_auth_uid() as uid, 'smithing_c43b' = any (public.world_skill_procs(public.fn_owner_auth_uid())) as half),$a$, 1),
    (22, 'public.world_repair_quote()', $a$and e.item_id = i.item_id) equipped$a$, $a$and e.item_id = i.item_id) equipped, me.half$a$, 1),
    (23, 'public.world_repair_quote()', $a$greatest(5, ceil((mx - cur) * (coalesce(tier, 1) + 1) / 2.0)::int)$a$,
        $a$(case when half then greatest(2, greatest(5, ceil((mx - cur) * (coalesce(tier, 1) + 1) / 2.0)::int) / 2) else greatest(5, ceil((mx - cur) * (coalesce(tier, 1) + 1) / 2.0)::int) end)$a$, 2),
    -- 구조: 소생술(내가 구조한 동료가 체력 80으로)
    (24, 'public.world_rescue_character(uuid)', $a$health=case when public.world_bond_partner(uid)=p_target then 50 else 30 end$a$,
        $a$health=case when 'first_aid_c43a' = any (public.world_skill_procs(uid)) then 80 when public.world_bond_partner(uid)=p_target then 50 else 30 end$a$, 1)
  ) v(ord, fn, old, new, cnt) order by ord loop
    d := pg_get_functiondef(p.fn::regprocedure);
    n := (length(d) - length(replace(d, p.old, ''))) / length(p.old);
    if n <> p.cnt then raise exception '기술 개편: % 고칠 자리(%)가 %곳입니다(예상 %곳).', p.fn, p.ord, n, p.cnt; end if;
    execute replace(d, p.old, p.new);
  end loop;
end $$;

-- ⑦ ─────────────────────────────────────────
-- 원거리 무기 소모품: 술법이 영력을 쓰듯 원거리 무기는 한 발에 하나씩 쓴다(묶음 100).
-- 활 → 화살, 쇠뇌·대노 → 쇠뇌살, 취관 → 취관 침. 무기 특성 equipment_traits.ammo로 잇는다(새 원거리 무기를 넣을 때도 ammo를 단다).
-- 현장 토벌은 공격·연사마다 하나(없으면 피해 절반), 원정은 정산한 회차마다 둘(시작할 때 없으면 원정 전투력 −40%).
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, rarity, acquisition_difficulty,
  drop_rate_modifier, equipment_traits, tradeable, reference_price, stack_size)
values
  ('ammo_arrow', '화살', 'consumable', 1, '활에 메겨 쏘는 화살. 활로 공격할 때마다 하나씩 쓴다. 떨어지면 활대로 내리쳐 피해가 절반이 된다.', true, '{}'::jsonb, 1, 'common', 1, 1.0, '{}'::jsonb, true, 2, 100),
  ('ammo_bolt', '쇠뇌살', 'consumable', 1, '쇠뇌와 대노에 재는 짧고 굵은 살. 쇠뇌로 공격할 때마다 하나씩 쓴다.', true, '{}'::jsonb, 1, 'common', 1, 1.0, '{}'::jsonb, true, 3, 100),
  ('ammo_dart', '취관 침', 'consumable', 1, '독낭 즙을 바른 가는 침. 취관으로 공격할 때마다 하나씩 쓴다.', true, '{}'::jsonb, 1, 'common', 1, 1.0, '{}'::jsonb, true, 3, 100)
on conflict (item_id) do nothing;

update public.world_item_catalog set equipment_traits = equipment_traits || jsonb_build_object('ammo',
    case when item_id = 'w_ranged2_silent' then 'ammo_dart'
         when item_id = 'reed_crossbow' or item_id ~ '^w_ranged[2-5]_heavy$' then 'ammo_bolt'
         else 'ammo_arrow' end)
 where category = 'weapon' and equipment_traits ->> 'weapon_type' = 'ranged';

-- 장착한 무기가 쓰는 소모품(없으면 null)
create or replace function public.world_ammo_of(p_uid uuid)
returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select i.equipment_traits ->> 'ammo' from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
   where e.owner_id = p_uid and e.slot = 'weapon' limit 1
$$;
revoke all on function public.world_ammo_of(uuid) from public, anon, authenticated;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn_owner_%' loop
    execute format('grant execute on function public.world_ammo_of(uuid) to %I', r);
  end loop;
end $$;

-- 제작(목공)과 상점(늘 파는 품목)
insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location,
  description, minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field)
values
  ('make_ammo_arrow', '화살 깎기', 'ammo_arrow', 50, '{"wood": 1, "river_reed": 2, "raw_iron": 1}'::jsonb, 'field_knife', 1, null, '갈대 살대에 생 월철 촉을 달아 화살 50개를 만든다.', 1, null, 1, 0, null, 1, 'carpentry'),
  ('make_ammo_bolt', '쇠뇌살 깎기', 'ammo_bolt', 40, '{"wood": 1, "iron_ingot": 1}'::jsonb, 'field_knife', 1, null, '단단한 나무에 월철 촉을 박아 쇠뇌살 40개를 만든다.', 1, null, 1, 0, null, 1, 'carpentry'),
  ('make_ammo_dart', '취관 침 다듬기', 'ammo_dart', 50, '{"river_reed": 2, "venom_gland": 1}'::jsonb, 'field_knife', 1, null, '갈대 침에 독낭 즙을 발라 취관 침 50개를 만든다.', 1, null, 1, 0, null, 1, 'carpentry')
on conflict (recipe_id) do nothing;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
select distinct s.shop_id, a.item_id, a.price, 1, 1 from public.world_shop_catalog s
  cross join (values ('ammo_arrow', 2), ('ammo_bolt', 3), ('ammo_dart', 3)) a(item_id, price)
 where s.item_id = 'field_knife'
on conflict do nothing;
insert into public.world_shop_stock(shop_id, item_id, stock, unit_price, refreshed_at)
select c.shop_id, c.item_id, 1, c.base_price, public.world_shop_slot() from public.world_shop_catalog c where c.item_id in ('ammo_arrow', 'ammo_bolt', 'ammo_dart')
on conflict do nothing;

-- 원정 정산·이목(도발)·상점 늘 파는 품목: 한 줄씩 정확히 바꾼다
do $$
declare p record; d text; n int;
begin
  for p in select * from (values
    (1, 'public.world_expedition_settle(uuid,integer)', $a$fx jsonb; wtype text; brank int;$a$, $a$fx jsonb; wtype text; brank int; ammo_k text; ammo_have int := 0; ammo_used int := 0;$a$, 1),
    (2, 'public.world_expedition_settle(uuid,integer)', $a$q.slot = 'weapon' limit 1), 'melee');$a$,
        $a$q.slot = 'weapon' limit 1), 'melee');
  ammo_k := public.world_ammo_of(e.owner_id);
  ammo_have := CASE WHEN ammo_k IS NULL THEN 0 ELSE coalesce((c.inventory ->> ammo_k)::int, 0) END;
  IF ammo_k IS NOT NULL AND ammo_have < 1 THEN power := power * 0.6; END IF;$a$, 1),
    (3, 'public.world_expedition_settle(uuid,integer)', $a$  update public.world_characters set health = hp, mental = mn, erosion = er,$a$,
        $a$  ammo_used := CASE WHEN ammo_k IS NULL THEN 0 ELSE least(ammo_have, greatest(0, last_i - e.settled_rounds) * 2) END;
  update public.world_characters set inventory = CASE WHEN ammo_used > 0 THEN public.world_inv_add(inventory, ammo_k, -ammo_used) ELSE inventory END, health = hp, mental = mn, erosion = er,$a$, 1),
    (4, 'public.world_combat_stats(uuid,jsonb)', $a$pres := greatest(5, least(300, 30 + s_vit * 0.8 - s_agi * 0.4 + adef * 0.6 + g_pres));$a$,
        $a$pres := greatest(5, least(300, 30 + s_vit * 0.8 - s_agi * 0.4 + adef * 0.6 + g_pres
    + CASE WHEN style = 'melee' THEN (SELECT coalesce(sum(CASE x WHEN 'melee_c13b' THEN 40 WHEN 'melee_c24b' THEN 60 WHEN 'melee_x30' THEN 30 WHEN 'melee_c43b' THEN 150 ELSE 0 END), 0) FROM unnest(public.world_skill_procs(p_owner)) x) ELSE 0 END));$a$, 1),
    (5, 'public.world_shop_refresh(text)', $a$'field_knife', 'ore_pick'];$a$, $a$'field_knife', 'ore_pick', 'ammo_arrow', 'ammo_bolt', 'ammo_dart'];$a$, 1)
  ) v(ord, fn, old, new, cnt) order by ord loop
    d := pg_get_functiondef(p.fn::regprocedure);
    n := (length(d) - length(replace(d, p.old, ''))) / length(p.old);
    if n <> p.cnt then raise exception '소모품: % 고칠 자리(%)가 %곳입니다(예상 %곳).', p.fn, p.ord, n, p.cnt; end if;
    execute replace(d, p.old, p.new);
  end loop;
end $$;

-- 지금 원거리 무기를 든 조사원에게 그 무기의 소모품 100개(가방에 자리가 없으면 개인 창고로)
do $$
declare r record; room int;
begin
  for r in select c.owner_id, c.inventory, i.equipment_traits ->> 'ammo' ammo
             from public.world_characters c
             join public.world_character_equipment e on e.owner_id = c.owner_id and e.slot = 'weapon'
             join public.world_item_catalog i on i.item_id = e.item_id
            where i.equipment_traits ? 'ammo' and coalesce(c.is_dead, false) = false loop
    room := public.world_bag_room(coalesce(r.inventory, '{}'::jsonb), r.ammo, public.world_bag_limit(r.owner_id));
    if room >= 100 then
      update public.world_characters set inventory = public.world_inv_add(coalesce(inventory, '{}'::jsonb), r.ammo, 100) where owner_id = r.owner_id;
    else
      insert into public.world_storage(owner_id, items, updated_at) values (r.owner_id, jsonb_build_object(r.ammo, 100), now())
      on conflict (owner_id) do update set items = public.world_inv_add(coalesce(public.world_storage.items, '{}'::jsonb), r.ammo, 100), updated_at = now();
    end if;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.owner_id, 'reward', '원거리 소모품 지급',
      '이제 원거리 무기는 한 발에 ' || (select item_name from public.world_item_catalog where item_id = r.ammo) || ' 하나를 씁니다. 지금 든 무기에 맞는 '
      || (select item_name from public.world_item_catalog where item_id = r.ammo) || ' 100개를 ' || case when room >= 100 then '가방에' else '개인 창고에(가방이 가득 차서)' end || ' 넣어 드렸습니다. 안전지대 상점과 목공 제작으로도 구할 수 있습니다.',
      jsonb_build_object('item_id', r.ammo, 'qty', 100));
  end loop;
end $$;


-- ⑧ ─────────────────────────────────────────
-- 기력: 근접 무기를 들면 영력 수치를 「기력」으로 쓴다(새 수치·게이지 없이 같은 spiritual_power, 화면은 노란 게이지·이름만 바꿈).
-- 근접 공격마다 기력 2(없으면 피해 절반), 술법은 영력 3, 원거리는 화살 등. 직업 기술(12)·방어(+4)·영력 회복약은 둘 다 같다.
update public.world_item_catalog set description = replace(description, '영력', '영력·기력')
 where item_id in ('spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew') and description not like '%영력·기력%';

grant select on public.world_active_encounters, public.world_expeditions to fn_owner_18453;
-- 전투·원정 중에는 장비를 바꿔 낄 수 없다(해제는 이미 막혀 있었고 장착은 열려 있어, 전투 도중·원정 도중 무기를 갈아 끼울 수 있었다)
do $$ declare d text := pg_get_functiondef('public.world_equip_item(text)'::regprocedure);
  a text := 'if not found then raise exception ''캐릭터를 먼저 생성하세요.''; end if;';
  b text := ' if exists (select 1 from public.world_active_encounters x where x.owner_id = uid and not x.defeated and not coalesce(x.fled, false)) then raise exception ''전투 중에는 장비를 바꿀 수 없습니다.''; end if;'
    || ' if exists (select 1 from public.world_expeditions x where x.owner_id = uid and x.status = ''active'') then raise exception ''원정 중에는 장비를 바꿀 수 없습니다.''; end if;';
begin
  if position('전투 중에는 장비를 바꿀 수 없습니다' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '장비 장착 고칠 자리'; end if;
  execute replace(d, a, a || b);
end $$;

-- ⑨ ─────────────────────────────────────────
-- 같은 장비를 여럿 가졌을 때 내구도 기록(world_item_durability, 사람×물품 하나)은 장착해 닳은 한 벌을 뜻한다.
-- 상점에 팔거나·버리거나·분해해 하나를 내놓으면 수량만 줄고 닳은 기록이 남아, 멀쩡한 쪽이 팔린 것처럼 됐다(문의: 닳은 장비를 팔고 새로 만든 것을 끼려 했는데 새것이 팔림).
-- 이 세 행동에서는 닳은 쪽이 먼저 나가고 남은 것은 새것(기록을 지움)으로 본다. 창고·거래는 그대로(닳은 것을 넘겨 공짜로 고치는 길을 막는다).
create or replace function public.world_wear_leaves_first()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  delete from public.world_item_durability d
   where d.owner_id = new.owner_id and d.durability < d.max_durability
     and coalesce((old.inventory ->> d.item_id)::numeric, 0) > coalesce((new.inventory ->> d.item_id)::numeric, 0)
     and coalesce((new.inventory ->> d.item_id)::numeric, 0) >= 1;
  return new;
end $$;
revoke all on function public.world_wear_leaves_first() from public, anon, authenticated;
drop trigger if exists trg_world_wear_leaves_first on public.world_characters;
create trigger trg_world_wear_leaves_first after update of inventory on public.world_characters
  for each row when (current_setting('yh.wear_leaves', true) = 'on' and old.inventory is distinct from new.inventory)
  execute function public.world_wear_leaves_first();

do $$
declare f text; d text; a text := 'if uid is null then raise exception ''로그인이 필요합니다.''; end if;';
begin
  foreach f in array array['public.world_shop_sell(text,integer)', 'public.world_item_discard(text,integer)', 'public.world_dismantle_item(text)'] loop
    d := pg_get_functiondef(f::regprocedure);
    if position('yh.wear_leaves' in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '닳은 장비 먼저: % 고칠 자리', f; end if;
    execute replace(d, a, a || ' perform set_config(''yh.wear_leaves'', ''on'', true);');
  end loop;
end $$;

-- ⑩ ─────────────────────────────────────────
-- 봉인술 계열: 13·24·30·43단계를 모두 택일로(A 폭딜 · B 버프/디버프). 13·30단계의 추가 기술(부적 접기·겹술식)은 B가 되고 A를 새로 둔다.
-- 13·30단계도 고를 수 있게(바꾸는 값 13단계 1,000전 · 24단계 2,000전 · 30단계 3,000전 · 43단계 5,000전). 이미 13·30단계에 닿은 조사원은 처음 고르기가 무료다.
update public.world_skill_catalog set slot = 'b' where skill_id in ('sealing_x13', 'sealing_x30');
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, active_skill, recipe_id, slot, requires) values
  ('sealing_c13a', '연쇄부', 'sealing', '', '{}'::jsonb, 13, null, null, 'a', null),
  ('sealing_c30a', '연환부', 'sealing', '', '{}'::jsonb, 30, null, null, 'a', null)
on conflict (skill_id) do nothing;
update public.world_skill_catalog s set skill_name = v.n, description = v.d from (values
  ('sealing_c13a', '연쇄부', '택일 기술(폭딜) · 술법이 적중하면 25% 확률로 부적이 튀어 피해 40% 추가'),
  ('sealing_x13', '부적 접기', '택일 기술(버프·디버프) · 우두머리가 봉인술을 떨쳐 낼 확률 50% → 35%, 봉인하면 적의 방어가 2턴 무너진다(받는 피해 +20%)'),
  ('sealing_c24a', '폭렬부', '택일 기술(폭딜) · 술법이 적중하면 20% 확률로 터져 피해 25% 추가'),
  ('sealing_c24b', '호체부', '택일 기술(버프·디버프) · 술법 공격마다 내 보호막 +4(최대 16, 받는 피해를 먼저 막음) · 정신 +2(한 전투에 5번까지)'),
  ('sealing_c30a', '연환부', '택일 기술(폭딜) · 술법 공격 때 25% 확률로 한 번 더 시전(피해 70%)'),
  ('sealing_x30', '겹술식', '택일 기술(버프·디버프) · 봉인에 묶였던 적에게 주는 다음 공격 피해 +30%, 봉인한 뒤 2번의 공격 동안 적 공격력 −20%'),
  ('sealing_c43a', '천뢰부', '택일 기술(폭딜) · 술법 공격 때 15% 확률로 벼락(적 최대 체력 8% 피해)'),
  ('sealing_c43b', '청정결계', '택일 기술(버프·디버프) · 술법을 쓰면 3턴 동안 받는 피해 −20%, 술법 공격마다 30% 확률로 침식 −1')
) v(id, n, d) where s.skill_id = v.id;

do $$ declare d text := pg_get_functiondef('public.world_skill_choose(text,integer,text)'::regprocedure);
  a1 text := 'if p_tier not in (24, 43)'; b1 text := 'if p_tier not in (13, 24, 30, 43)';
  a2 text := 'fee := case p_tier when 24 then 2000 else 5000 end;'; b2 text := 'fee := case p_tier when 13 then 1000 when 24 then 2000 when 30 then 3000 else 5000 end;';
begin
  if position(b1 in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1 or (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 then raise exception '기술 고르기 고칠 자리'; end if;
  execute replace(replace(d, a1, b1), a2, b2);
end $$;

-- ⑪ ─────────────────────────────────────────
-- 근접 계열: 13·24·30·43단계를 모두 택일로(A 딜러 · B 탱커 — 이목). 같은 효과를 키우지 않고 단계마다 다른 동작.
--   A: 13 발도(첫 공격 치명타) · 24 일격(마무리) · 30 유수검(막기·회피 뒤 치명타) · 43 파천(치명타가 방어를 무너뜨림)
--   B: 13 호령(이목 +40·첫 공격 피해 −30%) · 24 도발(이목 +60·방어하면 기믹 끊기) · 30 철갑 강기(공격마다 보호막·이목 +30) · 43 사자후(이목 +150·방어하면 2턴 기믹 봉쇄·받는 피해 −15%)
-- 유수검은 43단계 B에서 30단계 A(melee_c30a)로 옮기고, 43단계 B(melee_c43b)는 사자후가 된다.
update public.world_skill_catalog set slot = 'a' where skill_id = 'melee_x13';
update public.world_skill_catalog set slot = 'b' where skill_id = 'melee_x30';
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, active_skill, recipe_id, slot, requires) values
  ('melee_c13b', '호령', 'melee', '', '{}'::jsonb, 13, null, null, 'b', null),
  ('melee_c30a', '유수검', 'melee', '', '{}'::jsonb, 30, null, null, 'a', null)
on conflict (skill_id) do nothing;
update public.world_skill_catalog s set skill_name = v.n, description = v.d from (values
  ('melee_x13', '발도', '택일 기술(딜러) · 전투의 첫 근접 공격은 반드시 치명타'),
  ('melee_c13b', '호령', '택일 기술(탱커) · 이목 +40 · 전투에서 처음 받는 공격의 피해 −30%'),
  ('melee_c24a', '일격', '택일 기술(딜러) · 적 체력이 30% 아래면 근접 피해 +40%(마무리)'),
  ('melee_c24b', '도발', '택일 기술(탱커) · 이목 +60(한 적의 시선을 끈다) · 방어하면 적이 준비하던 기믹을 버리고 나에게 달려든다'),
  ('melee_c30a', '유수검', '택일 기술(딜러) · 막기·회피에 성공하면 다음 공격이 반드시 치명타'),
  ('melee_x30', '철갑 강기', '택일 기술(탱커) · 근접 공격할 때마다 보호막 +3(최대 15, 받는 피해를 먼저 막음) · 이목 +30'),
  ('melee_c43a', '파천', '택일 기술(딜러) · 근접 치명타가 적의 방어를 2턴 무너뜨린다(받는 피해 +20%)'),
  ('melee_c43b', '사자후', '택일 기술(탱커) · 이목 +150(원정 합동 전투에서 요괴가 거의 반드시 나를 노린다) · 방어하면 포효해 2턴 동안 적이 기믹을 쓰지 못하고 받는 피해 −15%')
) v(id, n, d) where s.skill_id = v.id;

grant fn_owner_18885 to postgres with inherit false, set false;
grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_18987 to postgres with inherit false, set false;
grant fn_owner_18452 to postgres with inherit false, set false;
grant fn_owner_18453 to postgres with inherit false, set false;
grant fn_owner_18956 to postgres with inherit false, set false;
grant fn_owner_18878 to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029060000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
