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
--   ⑫ 세력 가입 퀘스트(대화)·등급 5단계·등급 퀘스트·의뢰판·비고(공훈 상점)·수련장, 평판 상한 5000, 조사원 카드 세력 등급, 세력 인물 프로필
--   ⑭ 기존 대세력 가입자는 세력에서 나와 가입 퀘스트부터(재가입 제한 없음) · 천명원 효과(날씨 불이익 감소·예언) · 수련장 시련 전투 기록
--   ⑬ 1:1 직접 거래는 같은 곳이면 안전지대 밖에서도 · 수향연맹 세금 감면(등급마다 −20%, 5등급 −80%) · 흑련회 그림자 장부(상점 판매 한도 +300전씩)
--   (원정) 체력이 넉넉하면 밀린 싸움을 버틴다([버팀]) — ⑦의 원정 정산 고칠 자리 6~8
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
    (5, 'public.world_shop_refresh(text)', $a$'field_knife', 'ore_pick'];$a$, $a$'field_knife', 'ore_pick', 'ammo_arrow', 'ammo_bolt', 'ammo_dart'];$a$, 1),
    -- 원정 전투 승패가 체력과 상관없이 굴려져, 체력이 가득한데도 「밀려 물러났습니다」가 나왔다(문의).
    -- 체력이 70 이상이면 밀린 싸움도 버텨 다시 맞선다(체력 70에서 20%, 100에서 50%). 대신 이긴 싸움보다 두 배로 맞는다.
    (6, 'public.world_expedition_settle(uuid,integer)', $a$p_fight float8; dmg_mul float8;$a$, $a$grit boolean := false; p_fight float8; dmg_mul float8;$a$, 1),
    (7, 'public.world_expedition_settle(uuid,integer)', $a$won := random() < win_p;$a$,
        $a$won := random() < win_p; grit := false;
        IF NOT won AND hp >= 70 AND random() < least(0.5, (hp - 50) / 100.0) THEN
          won := true; grit := true;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[버팀] ' || foe || '에게 밀렸지만 체력이 넉넉해 물러서지 않고 다시 맞섭니다.');
        END IF;$a$, 1),
    (8, 'public.world_expedition_settle(uuid,integer)', $a$if m.drops is not null and random() < 0.7 * loot_mul then$a$,
        $a$IF grit THEN dmg := dmg * 2; END IF;
          if m.drops is not null and random() < 0.7 * loot_mul then$a$, 1)
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
-- 이 세 행동에서는 닳은 쪽이 먼저 나가고 남은 것은 새것(기록을 지움)으로 본다. 모두 내놓아 0개가 되어도 기록을 지운다(새로 만든 것이 옛 내구도를 물려받지 않게).
-- 창고·거래는 그대로(닳은 것을 넘겨 공짜로 고치는 길을 막는다).
create or replace function public.world_wear_leaves_first()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  -- 하나도 남지 않으면 기록을 지운다(제보 #7: 모두 분해한 뒤 새로 만든 장비가 옛 내구도를 물려받음).
  delete from public.world_item_durability d
   where d.owner_id = new.owner_id
     and coalesce((old.inventory ->> d.item_id)::numeric, 0) > coalesce((new.inventory ->> d.item_id)::numeric, 0)
     and (coalesce((new.inventory ->> d.item_id)::numeric, 0) < 1 or d.durability < d.max_durability);
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

grant fn_owner_18669 to postgres with inherit true, set true;
grant fn_owner_18881 to postgres with inherit true, set true;
-- ⑫ 세력 가입 퀘스트·등급(5단계)·등급 퀘스트·의뢰판·비고(秘庫)·수련장
--   · 대본(인물·장면)은 표에 두고, 진행은 world_faction_progress(캐릭터×세력)에 둔다. world_characters에는 열을 더하지 않는다.
--   · 할 일은 world_events를 장면이 열린 뒤부터 센다(world_faction_task_count). 행동 한 번의 쓰기를 늘리지 않는다.
--   · 가입 퀘스트는 그 세력에 처음 들 때만, 다시 들면 재가입 대사만. 등급은 평판(누적)과 레벨로 열리는 등급 퀘스트를 마쳐야 오른다.
--   · 공훈(merit)은 의뢰판·퀘스트로 모으는 쓰는 몫이고, 비고에서만 쓴다(비고는 사기만, 팔기 없음). 쓴다고 평판(등급 기준)은 줄지 않는다.
create table if not exists public.world_faction_npcs (
  npc_key text primary key, faction_id text not null, npc_name text not null, bio text not null default '', sort int not null default 0);
create table if not exists public.world_faction_scenes (
  scene_key text primary key, faction_id text not null, kind text not null check (kind in ('join', 'rejoin', 'rank', 'vault', 'hall')),
  step int not null, title text not null, goal text not null default '', need jsonb not null default '{}'::jsonb, lines jsonb not null,
  reward jsonb not null default '{}'::jsonb, min_level int not null default 1, rep_need int not null default 0);
create table if not exists public.world_faction_ranks (
  faction_id text not null, rank int not null check (rank between 1 and 5), rank_name text not null, primary key (faction_id, rank));
create table if not exists public.world_faction_progress (
  owner_id uuid not null, faction_id text not null,
  join_step int not null default 0, join_done_at timestamptz, joined_at timestamptz,
  rank int not null default 1 check (rank between 1 and 5), open_step text, step_started_at timestamptz not null default now(),
  merit int not null default 0 check (merit >= 0), npcs_met text[] not null default '{}', rejoin_pending boolean not null default false,
  show_rank boolean not null default true, hall_day date, hall_best int not null default 0, updated_at timestamptz not null default now(),
  primary key (owner_id, faction_id));
create table if not exists public.world_faction_requests (
  req_key text primary key, title text not null, need jsonb not null, merit int not null, rep int not null, sort int not null default 0);
create table if not exists public.world_faction_request_claims (
  owner_id uuid not null, day date not null, req_key text not null, claimed_at timestamptz not null default now(), primary key (owner_id, day, req_key));
create table if not exists public.world_faction_vault (
  faction_id text not null, item_id text not null, rank_need int not null default 1, price int not null check (price > 0), sort int not null default 0,
  primary key (faction_id, item_id));
do $$ declare t text; begin
  foreach t in array array['world_faction_npcs', 'world_faction_scenes', 'world_faction_ranks', 'world_faction_progress', 'world_faction_requests', 'world_faction_request_claims', 'world_faction_vault'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select on public.%I to fn_owner_field', t);
  end loop;
end $$;
grant insert, update on public.world_faction_progress to fn_owner_field;
grant insert on public.world_faction_request_claims to fn_owner_field;
grant update (faction_reputation) on public.world_characters to fn_owner_field;

insert into public.world_faction_ranks(faction_id, rank, rank_name) values
  ('night_office', 1, '수습 야행관'), ('night_office', 2, '야행관'), ('night_office', 3, '감찰 야행관'), ('night_office', 4, '당상 야행관'), ('night_office', 5, '야행 판관'),
  ('red_moon_cult', 1, '입문 교도'), ('red_moon_cult', 2, '혈인 교도'), ('red_moon_cult', 3, '월식 집사'), ('red_moon_cult', 4, '적월 호법'), ('red_moon_cult', 5, '홍월 장로'),
  ('black_lotus', 1, '빚진 손님'), ('black_lotus', 2, '연잎'), ('black_lotus', 3, '흑련 손'), ('black_lotus', 4, '열세 번째 문지기'), ('black_lotus', 5, '연주 대리'),
  ('north_league', 1, '산문 제자'), ('north_league', 2, '맹약 무사'), ('north_league', 3, '호위 무사'), ('north_league', 4, '철벽 호법'), ('north_league', 5, '북령 장로'),
  ('river_alliance', 1, '보증 손님'), ('river_alliance', 2, '나루 객주'), ('river_alliance', 3, '상단 행수'), ('river_alliance', 4, '대행수'), ('river_alliance', 5, '연맹 도방'),
  ('southern_remnant', 1, '불씨 지기'), ('southern_remnant', 2, '잔불'), ('southern_remnant', 3, '횃불'), ('southern_remnant', 4, '봉화'), ('southern_remnant', 5, '남명 수호장'),
  ('mandate_court', 1, '관측생'), ('mandate_court', 2, '일관(日官)'), ('mandate_court', 3, '관상관'), ('mandate_court', 4, '천문 교수'), ('mandate_court', 5, '영대 감정')
on conflict (faction_id, rank) do update set rank_name = excluded.rank_name;

-- 의뢰판: 매일(한국 시각) 세력마다 셋. 그날 한 일을 센다
insert into public.world_faction_requests(req_key, title, need, merit, rep, sort) values
  ('r_hunt', '요괴 토벌', '{"tasks":[{"t":"win","n":4}]}', 20, 15, 1),
  ('r_gather', '재료 납품', '{"tasks":[{"t":"gather","n":4}]}', 20, 15, 2),
  ('r_search', '현장 탐색', '{"tasks":[{"t":"search","n":5}]}', 20, 15, 3),
  ('r_clue', '단서 수집', '{"tasks":[{"t":"clue","n":1}]}', 25, 18, 4),
  ('r_exped', '원정 보고', '{"tasks":[{"t":"expedition","n":1}]}', 30, 20, 5),
  ('r_craft', '물자 제작', '{"tasks":[{"t":"craft","n":2}]}', 20, 15, 6),
  ('r_travel', '연락 심부름', '{"tasks":[{"t":"travel","n":2}]}', 15, 12, 7),
  ('r_sell', '시장 동향', '{"tasks":[{"t":"sell","n":2}]}', 15, 12, 8),
  ('r_patrol', '경계 순찰', '{"tasks":[{"t":"search","n":3,"distinct":true}]}', 25, 18, 9)
on conflict (req_key) do update set title = excluded.title, need = excluded.need, merit = excluded.merit, rep = excluded.rep, sort = excluded.sort;

-- 비고: 공훈으로만 산다(팔기 없음). 등급마다 품목이 늘어난다
insert into public.world_faction_vault(faction_id, item_id, rank_need, price, sort)
select f.faction_id, v.item_id, v.rank_need, v.price, v.sort
  from public.world_major_factions f
  cross join (values ('tonic', 1, 10, 1), ('clear_spirit_pill', 1, 15, 2), ('ward_talisman', 1, 10, 3), ('travel_ration', 1, 8, 4),
                     ('spirit_qi_pill', 2, 30, 5), ('repair_kit', 2, 25, 6), ('revival_charm', 2, 60, 7),
                     ('rejuv_pill', 3, 50, 8), ('moonlight_essence', 3, 60, 9),
                     ('grand_pill', 4, 100, 11), ('spirit_core', 4, 120, 12),
                     ('heavenly_dew', 5, 150, 14)) v(item_id, rank_need, price, sort)
on conflict (faction_id, item_id) do nothing;
insert into public.world_faction_vault(faction_id, item_id, rank_need, price, sort) values
  ('night_office', 'mirror_shard', 3, 80, 10), ('night_office', 'star_sand', 5, 150, 15),
  ('red_moon_cult', 'monster_core', 3, 80, 10), ('red_moon_cult', 'ember_crystal', 5, 150, 15),
  ('black_lotus', 'jade_shard', 3, 80, 10), ('black_lotus', 'mirror_shard', 5, 150, 15),
  ('north_league', 'thunder_ore', 3, 80, 10), ('north_league', 'sky_feather', 5, 150, 15),
  ('river_alliance', 'spirit_bark', 3, 60, 10), ('river_alliance', 'jade_shard', 5, 150, 15),
  ('southern_remnant', 'ember_crystal', 3, 80, 10), ('southern_remnant', 'monster_core', 5, 150, 15),
  ('mandate_court', 'star_sand', 3, 80, 10), ('mandate_court', 'sky_feather', 5, 150, 15)
on conflict (faction_id, item_id) do nothing;
delete from public.world_faction_vault v where not exists (select 1 from public.world_item_catalog i where i.item_id = v.item_id);

-- 수련장 칭호(3·5등급 시련을 처음 넘으면) · 5등급 칭호를 가지면 세력 낙관
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('fac_night_office_t3', '팔괘진을 깬 야행관', 'shield', '연무청의 팔괘진을 깨고 나온 정통파 조사원.', '정통파 수련장 3등급 시련 통과', '{"clue_bonus_pct": 3, "crit_pct": 1}', true, false, null, 950, '세력', 3),
  ('fac_night_office_t5', '연무청의 판관', 'shield', '등잔을 지키는 자의 이름을 연무청에 새겼다.', '정통파 수련장 5등급 시련 통과', '{"clue_bonus_pct": 5, "crit_pct": 2, "defense": 4}', true, false, null, 951, '세력', 4),
  ('fac_red_moon_cult_t3', '수련굴의 생존자', 'flame', '월식 수련굴에서 걸어 나온 몇 안 되는 교도.', '적월교 수련장 3등급 시련 통과', '{"combat_damage_pct": 3, "crit_pct": 1}', true, false, null, 952, '세력', 3),
  ('fac_red_moon_cult_t5', '달을 삼킨 자', 'flame', '요기를 삼키고도 스스로를 잃지 않았다.', '적월교 수련장 5등급 시련 통과', '{"combat_damage_pct": 5, "crit_pct": 2, "erosion_pct": -3}', true, false, null, 953, '세력', 4),
  ('fac_black_lotus_t3', '장부에서 지워진 빚', 'scroll', '그림자 장부실에서 빚 한 줄을 지워 냈다.', '흑련회 수련장 3등급 시련 통과', '{"rare_loot_pct": 3, "evasion_pct": 1}', true, false, null, 954, '세력', 3),
  ('fac_black_lotus_t5', '열세 번째 문의 주인', 'scroll', '열세 번째 문은 이제 이 사람을 위해 열린다.', '흑련회 수련장 5등급 시련 통과', '{"rare_loot_pct": 5, "evasion_pct": 2, "clue_bonus_pct": 3}', true, false, null, 955, '세력', 4),
  ('fac_north_league_t3', '철벽을 넘은 무사', 'shield', '철벽 연무장의 수좌를 땅에 눕혔다.', '북령맹 수련장 3등급 시련 통과', '{"incoming_damage_pct": -3, "presence": 6}', true, false, null, 956, '세력', 3),
  ('fac_north_league_t5', '눈 속의 맹주감', 'shield', '산문의 노승들이 다음 맹주감이라 부르는 이.', '북령맹 수련장 5등급 시련 통과', '{"incoming_damage_pct": -5, "presence": 10, "defense": 4}', true, false, null, 957, '세력', 4),
  ('fac_river_alliance_t3', '물길을 건넌 자', 'route', '쉬지 않는 물길 시험장을 끝까지 건넜다.', '수향연맹 수련장 3등급 시련 통과', '{"travel_time_pct": -3, "gather_qty_pct": 2}', true, false, null, 958, '세력', 3),
  ('fac_river_alliance_t5', '강의 신용', 'route', '이 사람의 말 한마디면 강 위의 배가 움직인다.', '수향연맹 수련장 5등급 시련 통과', '{"travel_time_pct": -5, "gather_qty_pct": 3, "rare_loot_pct": 2}', true, false, null, 959, '세력', 4),
  ('fac_southern_remnant_t3', '꺼지지 않는 횃불', 'flame', '봉화대가 꺼지기 전까지 버텨 낸 불씨.', '남명회 수련장 3등급 시련 통과', '{"gather_qty_pct": 3, "healing_pct": 2}', true, false, null, 960, '세력', 3),
  ('fac_southern_remnant_t5', '마지막 봉화', 'flame', '망국의 마지막 봉화를 이어받았다.', '남명회 수련장 5등급 시련 통과', '{"gather_qty_pct": 5, "healing_pct": 4, "incoming_damage_pct": -2}', true, false, null, 961, '세력', 4),
  ('fac_mandate_court_t3', '혼천의를 읽은 자', 'spark', '혼천의가 도는 동안 별의 흐름을 놓치지 않았다.', '천명원 수련장 3등급 시련 통과', '{"erosion_pct": -3, "clue_bonus_pct": 2}', true, false, null, 962, '세력', 3),
  ('fac_mandate_court_t5', '별을 말하지 않는 자', 'spark', '본 것을 모두 말하지 않는 것이 별을 보는 자의 계율이다.', '천명원 수련장 5등급 시련 통과', '{"erosion_pct": -5, "clue_bonus_pct": 3, "mental_loss_pct": -3}', true, false, null, 963, '세력', 4)
on conflict (title_key) do nothing;
insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
  ('sl_f_night', 'seal', 'legend', '낙관 「錄」', '정통파 수련장 5등급 시련 통과', '세력', '{"title": "fac_night_office_t5"}', false, true, 950),
  ('sl_f_redmoon', 'seal', 'legend', '낙관 「血」', '적월교 수련장 5등급 시련 통과', '세력', '{"title": "fac_red_moon_cult_t5"}', false, true, 951),
  ('sl_f_lotus', 'seal', 'legend', '낙관 「蓮」', '흑련회 수련장 5등급 시련 통과', '세력', '{"title": "fac_black_lotus_t5"}', false, true, 952),
  ('sl_f_north', 'seal', 'legend', '낙관 「盟」', '북령맹 수련장 5등급 시련 통과', '세력', '{"title": "fac_north_league_t5"}', false, true, 953),
  ('sl_f_river', 'seal', 'legend', '낙관 「舟」', '수향연맹 수련장 5등급 시련 통과', '세력', '{"title": "fac_river_alliance_t5"}', false, true, 954),
  ('sl_f_south', 'seal', 'legend', '낙관 「燼」', '남명회 수련장 5등급 시련 통과', '세력', '{"title": "fac_southern_remnant_t5"}', false, true, 955),
  ('sl_f_mandate', 'seal', 'legend', '낙관 「星」', '천명원 수련장 5등급 시련 통과', '세력', '{"title": "fac_mandate_court_t5"}', false, true, 956)
on conflict (cosmetic_key) do nothing;

-- 평판 상한 1000 → 5000(등급 기준 1,600·3,000에 닿도록)
do $$ declare d text := pg_get_functiondef('public.world_track_major_faction_reputation()'::regprocedure);
  a text := 'least(1000, greatest(-1000,'; b text := 'least(5000, greatest(-1000,';
begin
  if position(b in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '평판 상한 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- 장면이 열린 뒤 한 일을 센다
create or replace function public.world_faction_task_count(p_uid uuid, p_task jsonb, p_since timestamptz)
returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  with ev as (
    select e.payload, coalesce(e.payload ->> 'region_id', (select n.region_id from public.world_exploration_nodes n where n.node_id::text = e.payload ->> 'node_id')) region
      from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since
       and e.event_type = case p_task ->> 't' when 'search' then 'explore' when 'clue' then 'explore' when 'win' then 'combat' when 'gather' then 'gather'
                            when 'travel' then 'travel' when 'expedition' then 'expedition_end' when 'sell' then 'shop_sell' when 'trade' then 'trade' when 'craft' then 'craft' end
  ), ok as (
    select ev.region from ev
     where case p_task ->> 't'
             when 'search' then ev.payload ->> 'kind' = 'field_search'
             when 'clue' then ev.payload ->> 'kind' = 'field_search' and ev.payload ->> 'outcome' = 'clue'
             when 'win' then coalesce((ev.payload ->> 'defeated')::boolean, false)
             when 'travel' then ev.payload ? 'travel_history_id'
             when 'expedition' then ev.payload ->> 'ended' = 'complete'
             else true end
       and (not p_task ? 'r' or ev.region in (select jsonb_array_elements_text(p_task -> 'r')))
       and (not p_task ? 'rank' or ev.payload ->> 'rank' = p_task ->> 'rank')
       and (not p_task ? 'phase' or ev.payload ->> 'env_phase' in (select jsonb_array_elements_text(p_task -> 'phase')))
       and (not p_task ? 'weather' or ev.payload ->> 'env_weather' in (select jsonb_array_elements_text(p_task -> 'weather')))
       and (not coalesce((p_task ->> 'safe')::boolean, false) or exists (select 1 from public.world_map_regions m where m.region_id = ev.region and m.is_safe_zone))
  )
  select case when coalesce((p_task ->> 'distinct')::boolean, false) then (select count(distinct region) from ok)::int else (select count(*) from ok)::int end
$$;

-- 할 일 한 줄의 화면 문구
create or replace function public.world_faction_task_label(p_task jsonb)
returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select string_agg(m.region_name, '·') || '에서 ' from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(p_task -> 'r'))), '')
    || case when p_task ->> 'phase' is not null then '삼경에 ' else '' end
    || case when p_task ->> 'weather' is not null then '농무·삭풍·혈무 날씨에 ' else '' end
    || case p_task ->> 't'
         when 'search' then case when coalesce((p_task ->> 'distinct')::boolean, false) then '서로 다른 곳에서 탐색' else '탐색' end
         when 'clue' then '탐색에서 단서 발견' when 'win' then case when p_task ->> 'rank' = 'guardian' then '우두머리 쓰러뜨리기' else '토벌 승리' end
         when 'gather' then '채집' when 'travel' then case when coalesce((p_task ->> 'safe')::boolean, false) then '서로 다른 안전지대 들르기' when p_task ? 'r' then '도착' else '다른 지역으로 이동' end
         when 'expedition' then '원정 완주' when 'sell' then '상점에서 팔기' when 'trade' then '거래소에서 사거나 팔기' when 'craft' then '제작' else '' end
$$;

-- 등급 효과(가입 퀘스트를 마친 지금 세력, 2~5등급)
create or replace function public.world_faction_rank_effect(p_key text)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select (p.rank - 1) * case c.major_faction_id
      when 'night_office' then case p_key when 'clue_bonus_pct' then 2 else 0 end
      when 'red_moon_cult' then case p_key when 'combat_damage_pct' then 1 else 0 end
      when 'black_lotus' then case p_key when 'rare_loot_pct' then 1 else 0 end
      when 'north_league' then case p_key when 'incoming_damage_pct' then -1 else 0 end
      when 'river_alliance' then case p_key when 'travel_time_pct' then -2 else 0 end
      when 'southern_remnant' then case p_key when 'gather_qty_pct' then 2 else 0 end
      -- 천명원: 예언(요괴 조우 −2%) + 지금 날씨·시간대가 주는 불이익을 10%씩 되돌린다
      when 'mandate_court' then case p_key when 'encounter_pct' then -2 else 0 end
        - 0.1 * case when p_key in ('erosion_pct', 'incoming_damage_pct', 'encounter_pct', 'mental_loss_pct', 'travel_time_pct')
                     then greatest(0, public.world_env_total(c.owner_id, p_key)) else least(0, public.world_env_total(c.owner_id, p_key)) end
      else 0 end
    from public.world_characters c join public.world_faction_progress p on p.owner_id = c.owner_id and p.faction_id = c.major_faction_id
   where c.owner_id = public.fn_owner_auth_uid() and p.join_done_at is not null), 0)::numeric
$$;
do $$ declare d text := pg_get_functiondef('public.world_status_effect_total(text)'::regprocedure);
  a text := '+ public.world_social_effect(p_effect_key)'; b text := '+ public.world_social_effect(p_effect_key) + public.world_faction_rank_effect(p_effect_key)';
begin
  if position('world_faction_rank_effect' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '상태 효과 합계 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- 조사원 카드·프로필에 보일 세력 등급(가입 퀘스트를 마쳤고 보이기로 한 경우)
create or replace function public.world_faction_rank_label(p_owner uuid)
returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select r.rank_name from public.world_characters c
    join public.world_faction_progress p on p.owner_id = c.owner_id and p.faction_id = c.major_faction_id
    join public.world_faction_ranks r on r.faction_id = p.faction_id and r.rank = p.rank
   where c.owner_id = p_owner and p.join_done_at is not null and p.show_rank
$$;
do $$ declare d text := pg_get_functiondef('public.world_character_card'::regproc);
  a text := '''major_faction_id'', c.major_faction_id,'; b text := '''major_faction_id'', c.major_faction_id, ''faction_rank'', public.world_faction_rank_label(c.owner_id),';
begin
  if position('world_faction_rank_label' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '조사원 카드 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- 진행 행을 지금 세력에 맞춘다(처음이면 만들고, 다시 들었으면 재가입 대사·등급 1로)
create or replace function public.world_faction_sync(p_uid uuid)
returns public.world_faction_progress language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype; p public.world_faction_progress%rowtype; jt timestamptz;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if c.major_faction_id is null then return null; end if;
  jt := coalesce((select max(e.created_at) from public.world_events e where e.actor_id = p_uid and e.event_type = 'faction'
                   and e.payload ->> 'faction_id' = c.major_faction_id and coalesce(e.payload ->> 'left', 'false') <> 'true'), now());
  insert into public.world_faction_progress(owner_id, faction_id, joined_at, step_started_at) values (p_uid, c.major_faction_id, jt, now())
  on conflict (owner_id, faction_id) do nothing;
  select * into p from public.world_faction_progress where owner_id = p_uid and faction_id = c.major_faction_id for update;
  if p.joined_at is null or p.joined_at < jt then
    update public.world_faction_progress
       set joined_at = jt, rejoin_pending = (p.join_done_at is not null), rank = case when p.join_done_at is not null then 1 else p.rank end,
           open_step = null, step_started_at = now(), updated_at = now()
     where owner_id = p_uid and faction_id = c.major_faction_id returning * into p;
  end if;
  return p;
end $$;

-- 지금 진행할 장면(가입 → 등급). 등급 퀘스트는 평판·레벨이 차면 열리고, 열린 때부터 센다
create or replace function public.world_faction_current(p_uid uuid, p_open boolean default true)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype; p public.world_faction_progress%rowtype; s public.world_faction_scenes%rowtype; k text; t jsonb;
  tasks jsonb := '[]'::jsonb; ready boolean := true; locked text; here_ok boolean := true; n int;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  select * into p from public.world_faction_progress where owner_id = p_uid and faction_id = c.major_faction_id;
  if p.owner_id is null then return null; end if;
  if p.join_step < 3 then k := c.major_faction_id || ':join:' || (p.join_step + 1);
  elsif p.rank < 5 then k := c.major_faction_id || ':rank:' || (p.rank + 1);
  else return null; end if;
  select * into s from public.world_faction_scenes where scene_key = k;
  if s.scene_key is null then return null; end if;
  if s.kind = 'rank' then
    if c.level < s.min_level then locked := 'Lv' || s.min_level || '부터 열립니다(지금 Lv' || c.level || ').'; end if;
    if coalesce(c.faction_reputation, 0) < s.rep_need then locked := coalesce(locked || ' ', '') || '평판 ' || s.rep_need || '에 닿으면 열립니다(지금 ' || coalesce(c.faction_reputation, 0) || ').'; end if;
    if locked is null and p_open and p.open_step is distinct from k then
      update public.world_faction_progress set open_step = k, step_started_at = now(), updated_at = now() where owner_id = p_uid and faction_id = p.faction_id;
      p.step_started_at := now();
    end if;
  end if;
  for t in select * from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) loop
    n := case when locked is null then least((t ->> 'n')::int, public.world_faction_task_count(p_uid, t, p.step_started_at)) else 0 end;
    if n < (t ->> 'n')::int then ready := false; end if;
    tasks := tasks || jsonb_build_object('label', public.world_faction_task_label(t), 'cur', n, 'n', (t ->> 'n')::int);
  end loop;
  if s.need ? 'erosion' then
    tasks := tasks || jsonb_build_object('label', '침식 ' || (s.need ->> 'erosion') || ' 이상인 채로 보고', 'cur', least(c.erosion, (s.need ->> 'erosion')::int), 'n', (s.need ->> 'erosion')::int);
    if c.erosion < (s.need ->> 'erosion')::int then ready := false; end if;
  end if;
  if s.need ? 'at' then
    here_ok := exists (select 1 from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(s.need -> 'at')) and m.region_name = c.location);
  end if;
  return jsonb_build_object('scene_key', s.scene_key, 'kind', s.kind, 'step', s.step, 'title', s.title, 'goal', s.goal, 'tasks', tasks,
    'at_names', (select jsonb_agg(m.region_name order by m.region_name) from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(coalesce(s.need -> 'at', '[]'::jsonb)))),
    'here_ok', here_ok, 'cost', coalesce((s.need ->> 'cost')::int, 0), 'locked', locked, 'ready', ready and locked is null and here_ok,
    'reward', s.reward, 'since', p.step_started_at);
end $$;

-- 세력 화면 한 번에: 등급·공훈·지금 퀘스트·만난 인물·오늘 의뢰·비고·수련장
create or replace function public.world_faction_snapshot()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; p public.world_faction_progress%rowtype;
  v_day date := (now() at time zone 'Asia/Seoul')::date; d0 timestamptz := ((now() at time zone 'Asia/Seoul')::date)::timestamp at time zone 'Asia/Seoul';
  home boolean; reqs jsonb := '[]'::jsonb; r record; t jsonb; tl jsonb; ok boolean; n int; lv int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if c.major_faction_id is null then return jsonb_build_object('faction_id', null); end if;
  p := public.world_faction_sync(uid);
  home := c.location in (select m.region_name from public.world_map_regions m where m.region_id = any (public.world_faction_home(c.major_faction_id)));
  for r in select q.* from public.world_faction_requests q order by md5(q.req_key || c.major_faction_id || v_day::text) limit 3 loop
    tl := '[]'::jsonb; ok := true;
    for t in select * from jsonb_array_elements(r.need -> 'tasks') loop
      n := least((t ->> 'n')::int, public.world_faction_task_count(uid, t, d0));
      if n < (t ->> 'n')::int then ok := false; end if;
      tl := tl || jsonb_build_object('label', public.world_faction_task_label(t), 'cur', n, 'n', (t ->> 'n')::int);
    end loop;
    reqs := reqs || jsonb_build_object('key', r.req_key, 'title', r.title, 'tasks', tl, 'merit', r.merit, 'rep', r.rep, 'ready', ok,
      'claimed', exists (select 1 from public.world_faction_request_claims x where x.owner_id = uid and x.day = v_day and x.req_key = r.req_key));
  end loop;
  lv := greatest(1, p.rank);
  return jsonb_build_object(
    'faction_id', c.major_faction_id, 'rep', coalesce(c.faction_reputation, 0), 'rank', p.rank, 'merit', p.merit, 'show_rank', p.show_rank,
    'ranks', (select jsonb_agg(x.rank_name order by x.rank) from public.world_faction_ranks x where x.faction_id = c.major_faction_id),
    'next', (select jsonb_build_object('rep', s.rep_need, 'level', s.min_level) from public.world_faction_scenes s where s.scene_key = c.major_faction_id || ':rank:' || (p.rank + 1)),
    'join_done', p.join_done_at is not null, 'join_step', p.join_step, 'rejoin_pending', p.rejoin_pending, 'at_home', home,
    'home_names', (select jsonb_agg(m.region_name) from public.world_map_regions m where m.region_id = any (public.world_faction_home(c.major_faction_id))),
    'quest', case when p.rejoin_pending then null else public.world_faction_current(uid) end,
    'npcs', (select coalesce(jsonb_agg(jsonb_build_object('key', z.npc_key, 'name', z.npc_name, 'bio', z.bio, 'quote', z.quote, 'detail', z.detail) order by z.sort), '[]'::jsonb)
               from public.world_faction_npcs z where z.npc_key = any (p.npcs_met) and z.faction_id = c.major_faction_id),
    'npc_total', (select count(*) from public.world_faction_npcs z where z.faction_id = c.major_faction_id),
    'requests', reqs,
    'vault', (select coalesce(jsonb_agg(jsonb_build_object('item_id', v.item_id, 'name', i.item_name, 'price', v.price, 'rank_need', v.rank_need, 'locked', v.rank_need > p.rank) order by v.rank_need, v.sort), '[]'::jsonb)
                from public.world_faction_vault v join public.world_item_catalog i on i.item_id = v.item_id where v.faction_id = c.major_faction_id),
    'hall', jsonb_build_object('tier', p.rank, 'done_today', p.hall_day = v_day, 'best', p.hall_best, 'foe_level', (array[3, 7, 12, 18, 24])[p.rank]),
    'keepers', (select jsonb_object_agg(s.kind, jsonb_build_object('title', s.title, 'line', s.lines -> 0 ->> 't', 'who', (select z.npc_name from public.world_faction_npcs z where z.npc_key = s.lines -> 0 ->> 's')))
                  from public.world_faction_scenes s where s.faction_id = c.major_faction_id and s.kind in ('vault', 'hall')));
end $$;

-- 세력 안전지대(비고·수련장·보고 장소). 정청은 모든 세력 연락관이 있어 가입 퀘스트 보고를 받는다(장면 need.at)
create or replace function public.world_faction_home(p_faction text)
returns text[] language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select case p_faction when 'night_office' then array['hq_yard', 'hq_dorm'] when 'red_moon_cult' then array['bone_market'] when 'black_lotus' then array['hidden_bazaar']
    when 'north_league' then array['iron_monastery'] when 'river_alliance' then array['river_ferry'] when 'southern_remnant' then array['ember_village']
    when 'mandate_court' then array['star_observatory', 'hq_dorm'] else array[]::text[] end
$$;

-- 대화 보고: 할 일을 마쳤으면 장면 대사를 돌려주고 다음으로 넘긴다(재가입 대사도 여기서 한 번)
create or replace function public.world_faction_report()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; p public.world_faction_progress%rowtype; s public.world_faction_scenes%rowtype;
  cur jsonb; inv jsonb; it record; lim int; spk text[]; msg text := '';
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if c.major_faction_id is null then raise exception '대세력에 들어야 합니다.'; end if;
  p := public.world_faction_sync(uid);
  if p.rejoin_pending then
    select * into s from public.world_faction_scenes where scene_key = c.major_faction_id || ':rejoin:1';
    update public.world_faction_progress set rejoin_pending = false, updated_at = now() where owner_id = uid and faction_id = p.faction_id;
  else
    cur := public.world_faction_current(uid);
    if cur is null then raise exception '지금 이어 갈 세력 퀘스트가 없습니다.'; end if;
    if cur ->> 'locked' is not null then raise exception '%', cur ->> 'locked'; end if;
    if not (cur ->> 'here_ok')::boolean then raise exception '%에서 보고할 수 있습니다.', array_to_string(array(select jsonb_array_elements_text(cur -> 'at_names')), '·'); end if;
    if not (cur ->> 'ready')::boolean then raise exception '아직 할 일이 남았습니다.'; end if;
    if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 보고할 수 없습니다.'; end if;
    select * into s from public.world_faction_scenes where scene_key = cur ->> 'scene_key';
    if (cur ->> 'cost')::int > 0 then
      if coalesce(c.gil, 0) < (cur ->> 'cost')::int then raise exception '전이 모자랍니다(%전 필요).', cur ->> 'cost'; end if;
      update public.world_characters set gil = gil - (cur ->> 'cost')::int, updated_at = now() where owner_id = uid;
      msg := msg || (cur ->> 'cost') || '전을 냈습니다. ';
    end if;
    -- 보상 물품: 가방에 들어가지 않으면 보고를 받지 않는다
    inv := coalesce(c.inventory, '{}'::jsonb); lim := public.world_bag_limit(uid);
    for it in select key, value::int q from jsonb_each_text(coalesce(s.reward -> 'items', '{}'::jsonb)) loop
      if public.world_bag_room(inv, it.key, lim) < it.q then raise exception '가방 자리가 모자랍니다. 보상을 받을 자리를 비운 뒤 다시 보고하세요.'; end if;
      inv := public.world_inv_add(inv, it.key, it.q);
      msg := msg || (select item_name from public.world_item_catalog where item_id = it.key) || ' ×' || it.q || ' ';
    end loop;
    if inv is distinct from coalesce(c.inventory, '{}'::jsonb) then update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid; end if;
    if coalesce((s.reward ->> 'merit')::int, 0) > 0 then msg := msg || '공훈 +' || (s.reward ->> 'merit') || ' '; end if;
    update public.world_faction_progress
       set join_step = case when s.kind = 'join' then s.step else join_step end,
           join_done_at = case when s.kind = 'join' and s.step = 3 then now() else join_done_at end,
           rank = case when s.kind = 'rank' then s.step else rank end,
           merit = merit + coalesce((s.reward ->> 'merit')::int, 0), open_step = null, step_started_at = now(), updated_at = now()
     where owner_id = uid and faction_id = p.faction_id;
  end if;
  select array_agg(distinct x ->> 's') into spk from jsonb_array_elements(s.lines) x where x ->> 's' is not null;
  update public.world_faction_progress set npcs_met = array(select distinct unnest(npcs_met || coalesce(spk, '{}'))) where owner_id = uid and faction_id = p.faction_id;
  return jsonb_build_object('title', s.title, 'kind', s.kind, 'step', s.step, 'lines', s.lines, 'reward', nullif(trim(msg), ''),
    'cast', (select coalesce(jsonb_object_agg(z.npc_key, jsonb_build_object('name', z.npc_name, 'bio', z.bio)), '{}'::jsonb) from public.world_faction_npcs z where z.npc_key = any (spk)),
    'rank_name', (select r.rank_name from public.world_faction_ranks r join public.world_faction_progress q on q.faction_id = r.faction_id and q.rank = r.rank where q.owner_id = uid and q.faction_id = p.faction_id));
end $$;

-- 의뢰판: 오늘 의뢰 하나를 마치고 받는다(평판·공훈)
create or replace function public.world_faction_request_claim(p_req text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_faction_requests%rowtype; t jsonb;
  v_day date := (now() at time zone 'Asia/Seoul')::date; d0 timestamptz := ((now() at time zone 'Asia/Seoul')::date)::timestamp at time zone 'Asia/Seoul';
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if c.major_faction_id is null then raise exception '대세력에 들어야 합니다.'; end if;
  perform public.world_faction_sync(uid);
  if p_req not in (select q.req_key from public.world_faction_requests q order by md5(q.req_key || c.major_faction_id || v_day::text) limit 3) then raise exception '오늘의 의뢰가 아닙니다.'; end if;
  select * into r from public.world_faction_requests where req_key = p_req;
  for t in select * from jsonb_array_elements(r.need -> 'tasks') loop
    if public.world_faction_task_count(uid, t, d0) < (t ->> 'n')::int then raise exception '아직 의뢰를 마치지 않았습니다.'; end if;
  end loop;
  insert into public.world_faction_request_claims(owner_id, day, req_key) values (uid, v_day, p_req) on conflict do nothing;
  if not found then raise exception '이미 받은 의뢰입니다.'; end if;
  update public.world_characters set faction_reputation = least(5000, coalesce(faction_reputation, 0) + r.rep), updated_at = now() where owner_id = uid;
  update public.world_faction_progress set merit = merit + r.merit, updated_at = now() where owner_id = uid and faction_id = c.major_faction_id;
  return jsonb_build_object('content', '의뢰 「' || r.title || '」를 마쳤습니다. 평판 +' || r.rep || ' · 공훈 +' || r.merit, 'merit', r.merit, 'rep', r.rep);
end $$;

-- 비고: 세력 안전지대에서 공훈으로 산다(팔기 없음)
create or replace function public.world_faction_vault_buy(p_item text, p_qty int default 1)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; p public.world_faction_progress%rowtype; v public.world_faction_vault%rowtype; cost int; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_qty is null or p_qty < 1 or p_qty > 99 then raise exception '수량은 1~99개입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.major_faction_id is null then raise exception '대세력에 들어야 합니다.'; end if;
  p := public.world_faction_sync(uid);
  if p.join_done_at is null then raise exception '가입 퀘스트를 마치면 비고가 열립니다.'; end if;
  if c.location not in (select m.region_name from public.world_map_regions m where m.region_id = any (public.world_faction_home(c.major_faction_id))) then raise exception '세력 안전지대에서만 비고를 열 수 있습니다.'; end if;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 살 수 없습니다.'; end if;
  select * into v from public.world_faction_vault where faction_id = c.major_faction_id and item_id = p_item;
  if v.item_id is null then raise exception '비고에 없는 물품입니다.'; end if;
  if v.rank_need > p.rank then raise exception '% 등급부터 살 수 있습니다.', (select rank_name from public.world_faction_ranks where faction_id = c.major_faction_id and rank = v.rank_need); end if;
  cost := v.price * p_qty;
  if p.merit < cost then raise exception '공훈이 모자랍니다(% 필요, 지금 %).', cost, p.merit; end if;
  if public.world_bag_room(coalesce(c.inventory, '{}'::jsonb), p_item, public.world_bag_limit(uid)) < p_qty then raise exception '가방 자리가 모자랍니다.'; end if;
  update public.world_faction_progress set merit = merit - cost, updated_at = now() where owner_id = uid and faction_id = c.major_faction_id and merit >= cost;
  if not found then raise exception '공훈이 모자랍니다.'; end if;
  update public.world_characters set inventory = public.world_inv_add(coalesce(inventory, '{}'::jsonb), p_item, p_qty), updated_at = now() where owner_id = uid;
  select item_name into nm from public.world_item_catalog where item_id = p_item;
  return jsonb_build_object('content', nm || ' ×' || p_qty || '을(를) 공훈 ' || cost || '으로 받았습니다.', 'merit', p.merit - cost);
end $$;

-- 수련장: 하루 한 번 지금 등급의 시련. 내 전투 능력치(world_combat_stats)와 등급별 시련 상대가 최대 12합을 주고받고, 그 기록을 화면이 한 줄씩 보인다.
-- 3·5등급 시련을 처음 넘으면 칭호(5등급은 낙관도)
create or replace function public.world_faction_trial()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; p public.world_faction_progress%rowtype;
  v_day date := (now() at time zone 'Asia/Seoul')::date; tier int; won boolean; keeper text; lines jsonb := '[]'::jsonb; gain int := 0; tk text; got text;
  cs jsonb; atk numeric; red numeric; crit numeric; eva numeric; mhp int; fhp int; fmax int; flv int; fatk numeric; dmg int; rnd int := 0; foe text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if c.major_faction_id is null then raise exception '대세력에 들어야 합니다.'; end if;
  p := public.world_faction_sync(uid);
  if p.join_done_at is null then raise exception '가입 퀘스트를 마치면 수련장이 열립니다.'; end if;
  if c.location not in (select m.region_name from public.world_map_regions m where m.region_id = any (public.world_faction_home(c.major_faction_id))) then raise exception '세력 안전지대에서만 수련장에 들어갈 수 있습니다.'; end if;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 시련을 치를 수 없습니다.'; end if;
  if p.hall_day = v_day then raise exception '오늘의 시련은 이미 치렀습니다. 내일 다시 오세요.'; end if;
  tier := p.rank;
  select z.npc_name into keeper from public.world_faction_scenes s join public.world_faction_npcs z on z.npc_key = s.lines -> 0 ->> 's' where s.scene_key = c.major_faction_id || ':hall:1';
  cs := public.world_combat_stats(uid, null);
  atk := coalesce((cs ->> 'attack')::numeric, 20); red := least(60, coalesce((cs ->> 'reduction_pct')::numeric, 0));
  crit := least(60, coalesce((cs ->> 'crit_pct')::numeric, 5)); eva := least(40, coalesce((cs ->> 'evasion_pct')::numeric, 3));
  flv := (array[3, 7, 12, 18, 24])[tier]; fmax := 100 + 8 * flv; fhp := fmax; fatk := 10 + flv * 2.6; mhp := 100 + 8 * c.level;
  foe := tier || '등급 시련 상대';
  lines := lines || jsonb_build_object('kind', 'start', 'who', 0, 'text', coalesce(keeper, '관리인') || '이(가) ' || foe || '(Lv' || flv || ')를 내보낸다. 기세 ' || mhp || ' 대 ' || fmax || '.');
  while rnd < 12 and mhp > 0 and fhp > 0 loop
    rnd := rnd + 1;
    if random() * 100 < 6 then
      lines := lines || jsonb_build_object('kind', 'miss', 'who', 1, 'text', rnd || '합 · 내 공격이 빗나갔다.');
    else
      dmg := round(atk * 0.3 * (0.85 + random() * 0.3));
      if random() * 100 < crit then dmg := round(dmg * 1.6); fhp := greatest(0, fhp - dmg);
        lines := lines || jsonb_build_object('kind', 'crit', 'who', 1, 'text', rnd || '합 · 급소를 꿰뚫었다! ' || dmg || ' (상대 기세 ' || fhp || ')');
      else fhp := greatest(0, fhp - dmg);
        lines := lines || jsonb_build_object('kind', 'hit', 'who', 1, 'text', rnd || '합 · ' || dmg || '을(를) 먹였다. (상대 기세 ' || fhp || ')');
      end if;
    end if;
    exit when fhp <= 0;
    if random() * 100 < eva then
      lines := lines || jsonb_build_object('kind', 'miss', 'who', 2, 'text', '상대의 반격을 몸을 틀어 피했다.');
    else
      dmg := round(fatk * (1 - red / 100.0) * (0.85 + random() * 0.3));
      if random() * 100 < 8 then dmg := round(dmg * 1.5); mhp := greatest(0, mhp - dmg);
        lines := lines || jsonb_build_object('kind', 'crit', 'who', 2, 'text', '상대의 일격이 깊게 들어왔다! ' || dmg || ' (내 기세 ' || mhp || ')');
      else mhp := greatest(0, mhp - dmg);
        lines := lines || jsonb_build_object('kind', 'hit', 'who', 2, 'text', '상대가 ' || dmg || '을(를) 되갚았다. (내 기세 ' || mhp || ')');
      end if;
    end if;
  end loop;
  won := fhp <= 0 or (mhp > 0 and mhp::numeric / (100 + 8 * c.level) > fhp::numeric / fmax);
  lines := lines || jsonb_build_object('kind', 'end', 'who', case when won then 1 else 2 end,
    'text', case when fhp <= 0 then '상대가 무릎을 꿇었다. 시련을 넘었다.' when mhp <= 0 then '끝내 버티지 못하고 쓰러졌다.' when won then '12합이 끝났다. 기세가 더 남아 판정승.' else '12합이 끝났다. 기세가 모자라 판정패.' end);
  if won then
    gain := 10 * tier;
    tk := case when tier >= 5 and p.hall_best < 5 then 'fac_' || c.major_faction_id || '_t5' when tier >= 3 and p.hall_best < 3 then 'fac_' || c.major_faction_id || '_t3' end;
    if tk is not null then
      insert into public.world_character_titles(owner_id, title_key) values (uid, tk) on conflict do nothing;
      if tier >= 5 and p.hall_best < 3 then insert into public.world_character_titles(owner_id, title_key) values (uid, 'fac_' || c.major_faction_id || '_t3') on conflict do nothing; end if;
      insert into public.world_character_cosmetics(owner_id, cosmetic_key)
        select uid, cc.cosmetic_key from public.world_cosmetic_catalog cc where cc.rule ->> 'title' = tk on conflict do nothing;
      select title_name into got from public.world_title_catalog where title_key = tk;
    end if;
  end if;
  update public.world_faction_progress set hall_day = v_day, hall_best = case when won then greatest(hall_best, tier) else hall_best end, merit = merit + gain, updated_at = now()
   where owner_id = uid and faction_id = c.major_faction_id;
  return jsonb_build_object('won', won, 'tier', tier, 'log', lines, 'merit', gain, 'title', got, 'foe_level', flv,
    'content', case when won then '시련을 넘었습니다. 공훈 +' || gain || coalesce(' · 칭호 「' || got || '」', '') else '시련에 졌습니다. 내일 다시 도전할 수 있습니다.' end);
end $$;

-- 프로필에 세력 등급 보이기·숨기기
create or replace function public.world_faction_show_rank(p_show boolean)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); fid text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select major_faction_id into fid from public.world_characters where owner_id = uid;
  if fid is null then raise exception '대세력에 들어야 합니다.'; end if;
  perform public.world_faction_sync(uid);
  update public.world_faction_progress set show_rank = coalesce(p_show, true), updated_at = now() where owner_id = uid and faction_id = fid;
  return jsonb_build_object('content', case when p_show then '프로필에 세력 등급을 보입니다.' else '프로필에서 세력 등급을 숨깁니다.' end);
end $$;

do $$ declare f text; begin
  foreach f in array array['world_faction_task_count(uuid,jsonb,timestamptz)', 'world_faction_task_label(jsonb)', 'world_faction_rank_effect(text)', 'world_faction_rank_label(uuid)',
    'world_faction_sync(uuid)', 'world_faction_current(uuid,boolean)', 'world_faction_snapshot()', 'world_faction_home(text)', 'world_faction_report()',
    'world_faction_request_claim(text)', 'world_faction_vault_buy(text,integer)', 'world_faction_trial()', 'world_faction_show_rank(boolean)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
  -- 화면이 부르는 것과 상태 효과 합계(여러 함수 주인이 부름)·이름표만 연다
  foreach f in array array['world_faction_snapshot()', 'world_faction_report()', 'world_faction_request_claim(text)', 'world_faction_vault_buy(text,integer)', 'world_faction_trial()', 'world_faction_show_rank(boolean)'] loop
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'grant execute on function public.world_faction_rank_effect(text) to public';
  execute 'grant execute on function public.world_faction_home(text) to public';
end $$;

insert into public.world_faction_npcs(npc_key, faction_id, npc_name, bio, sort) values
  ('night_office:baek', 'night_office', '도제조 백운서', '정통파의 수장. 백발의 노관리. 말이 느리고 짧다.', 0),
  ('night_office:han', 'night_office', '감찰관 한설', '규정과 보고를 무엇보다 앞세우는 감찰관. 차갑지만 공정하다.', 1),
  ('night_office:mo', 'night_office', '기록관 모가람', '장서각을 지키는 기록관. 말이 많고 다정하다. 비고 관리인.', 2),
  ('night_office:kang', 'night_office', '교관 강두철', '연무청 교관. 목소리가 크고 웃음이 많다. 수련장 관리인.', 3),
  ('red_moon_cult:wolhwa', 'red_moon_cult', '교주 월화(月華)', '적월교의 교주. 붉은 면사포 너머로 얼굴을 보인 적이 없다.', 0),
  ('red_moon_cult:sama', 'red_moon_cult', '대호법 사마겸', '교의 무력을 맡은 거한. 약한 자를 경멸하고 강한 자를 아낀다. 수련굴 관리인.', 1),
  ('red_moon_cult:danbi', 'red_moon_cult', '주홍 무녀 단비', '의식을 집전하는 젊은 무녀. 웃는 얼굴로 무서운 말을 한다. 비고 관리인.', 2),
  ('black_lotus:mumyeong', 'black_lotus', '회주 무명(無名)', '흑련회의 회주. 자기 이름을 팔았다고 한다. 누구도 진짜 이름을 모른다.', 0),
  ('black_lotus:guseul', 'black_lotus', '장부지기 구슬', '암시장의 모든 빚을 외우는 여인. 주판 소리가 말버릇이다. 비고 관리인.', 1),
  ('black_lotus:six', 'black_lotus', '채무 추적자 여섯째', '빚을 받아 내는 사람. 말이 적고 숫자로 부른다. 수련장 관리인.', 2),
  ('north_league:seok', 'north_league', '맹주 석진악', '북령맹의 맹주. 얼음 인장을 지키는 노무인. 말보다 손이 먼저 나간다.', 0),
  ('north_league:hyegak', 'north_league', '수좌 혜각', '철벽 고찰의 수좌승. 웃으면서 사람을 땅에 눕힌다. 수련장 관리인.', 1),
  ('north_league:yeo', 'north_league', '호송대장 여운비', '맹의 호송대를 이끄는 여장수. 길과 날씨를 누구보다 잘 안다. 비고 관리인.', 2),
  ('river_alliance:jin', 'river_alliance', '도방 진소랑', '수향연맹의 도방. 웃는 얼굴로 값을 깎는 장사꾼. 약속은 반드시 지킨다.', 0),
  ('river_alliance:nodeul', 'river_alliance', '뱃사공 노들 영감', '구름나루에서 오십 년 노를 저은 노인. 물길의 모든 소문을 안다. 수련장 관리인.', 1),
  ('river_alliance:maehyang', 'river_alliance', '장부 행수 매향', '상단의 장부를 맡은 행수. 계산이 빠르고 말이 똑 부러진다. 비고 관리인.', 2),
  ('southern_remnant:jang', 'southern_remnant', '노장 장무현', '남명회의 수장. 망국의 마지막 장군. 한쪽 팔이 없다.', 0),
  ('southern_remnant:soi', 'southern_remnant', '무녀 소이', '망국의 기억을 노래로 전하는 무녀. 말끝마다 옛말이 섞인다. 비고 관리인.', 1),
  ('southern_remnant:galmae', 'southern_remnant', '정찰대장 갈매', '잔불촌의 젊은 정찰대장. 날래고 거칠다. 수련장 관리인.', 2),
  ('mandate_court:hahu', 'mandate_court', '태사령 하후정', '천명원의 수장. 황실의 별을 읽는 노학자. 예언을 입 밖에 내지 않는다.', 0),
  ('mandate_court:seo', 'mandate_court', '수석 관측관 서이연', '관성대의 수석 관측관. 밤을 새우는 게 일상이라 늘 졸린 얼굴이다. 수련장 관리인.', 1),
  ('mandate_court:mun', 'mandate_court', '기밀 사관 문서진', '황실 기록을 맡은 사관. 웃지 않는다. 비고 관리인.', 2)
on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio, sort = excluded.sort;

insert into public.world_faction_scenes(scene_key, faction_id, kind, step, title, goal, need, lines, reward, min_level, rep_need) values
  ('night_office:join:1', 'night_office', 'join', 1, '신원 심사', '본부 정청에서 감찰관 한설과 이야기한다', '{"at": ["hq_dorm", "hq_yard"]}'::jsonb, '[{"s": null, "t": "정청 마루의 등잔이 하나씩 밝혀진다. 문서 더미 너머에서 붓 끝을 닦던 사내가 고개를 든다."}, {"s": "night_office:han", "t": "입국 신청서. 이름, 직업, 소속. …전부 적혀 있군. 드문 일이다."}, {"s": "night_office:han", "t": "야행국 정통파는 퇴마를 하는 곳이 아니다. 퇴마를 「기록하는」 곳이지. 무엇을 베었는지보다 무엇을 보았는지가 먼저다."}, {"s": "night_office:mo", "t": "감찰관님, 또 겁부터 주시네. 어서 와요. 나는 장서각의 모가람. 여기서 쓰는 장부는 전부 내 손을 거쳐요."}, {"s": "night_office:han", "t": "기초 교육부터 받는다. 잿빛 들녘에 나가 보고, 본 것을 적어 와라. 하나도 빼놓지 말고."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('night_office:join:2', 'night_office', 'join', 2, '첫 현장 기록', '잿빛 들녘에서 탐색 3회·토벌 승리 2회 뒤 본부에 보고', '{"tasks": [{"t": "search", "n": 3, "r": ["field_outskirts"]}, {"t": "win", "n": 2, "r": ["field_outskirts"]}], "at": ["hq_dorm", "hq_yard"]}'::jsonb, '[{"s": null, "t": "잿빛 들녘의 풀은 밤에도 회색이다. 발밑에서 부러진 부적 조각이 바스락거린다."}, {"s": "night_office:kang", "t": "하하! 신입이 벌써 돌아왔나! 어디 보자… 요괴 둘에 흔적 셋. 숫자는 맞는데."}, {"s": "night_office:han", "t": "이 줄. 「검은 털이 많았음」. 몇 가닥이었나. 어느 방향으로 누워 있었나."}, {"s": null, "t": "한설이 붓으로 한 줄을 긋는다. 그러나 장부를 돌려주는 손길은 조심스럽다."}, {"s": "night_office:han", "t": "처음치고는 나쁘지 않다. 기록은 거짓말을 하지 않는다. 기록하는 자가 거짓말을 할 뿐이지."}, {"s": "night_office:mo", "t": "이 말 들었으면 합격이에요. 감찰관님이 칭찬을 저렇게 하시거든요."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('night_office:join:3', 'night_office', 'join', 3, '등잔 아래의 서약', '본부 정청에서 도제조 백운서를 만난다', '{"at": ["hq_dorm", "hq_yard"]}'::jsonb, '[{"s": null, "t": "정청 가장 안쪽 방. 꺼지지 않는 등잔 하나 아래, 백발의 노인이 기다리고 있다."}, {"s": "night_office:baek", "t": "…앉게."}, {"s": "night_office:baek", "t": "야행국이 생긴 지 삼백 년일세. 그동안 우리는 요괴를 다 없애지 못했어. 다만 잊지 않았지."}, {"s": "night_office:baek", "t": "이름을 적는 것은 그것을 붙잡아 두는 일이네. 사람이든 요괴든. 자네 이름도 이제 이 장부에 남네."}, {"s": null, "t": "노인이 장부를 펼친다. 붉은 인장이 찍힐 자리가 비어 있다."}, {"s": "night_office:baek", "t": "야행국의 밤은 길다네. 등잔이 꺼지지 않게만 해 주게."}, {"s": null, "t": "「수습 야행관」의 직위를 받았다. 정통파의 비고와 수련장이 열린다."}]'::jsonb, '{"items": {"tonic": 5, "clear_spirit_pill": 3, "spirit_qi_pill": 2}, "merit": 30}'::jsonb, 1, 0),
  ('night_office:rejoin:1', 'night_office', 'rejoin', 1, '돌아온 이에게', '', '{}'::jsonb, '[{"s": "night_office:han", "t": "돌아왔군. 장부에서 지웠던 이름을 다시 적는다. 이번엔 지우지 않게 해라."}, {"s": "night_office:mo", "t": "감찰관님 말은 반만 들어요. 다시 와서 다들 반가워해요. 정말로요."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('night_office:rank:2', 'night_office', 'rank', 2, '두 번째 장부', '장서각 지하서고에서 탐색 2회', '{"tasks": [{"t": "search", "n": 2, "r": ["hq_archive"]}]}'::jsonb, '[{"s": "night_office:mo", "t": "지하서고에 오래된 장부가 하나 더 있대요. 첫 번째 장부랑 먹 색이 달라서 누가 따로 적은 거래요."}, {"s": null, "t": "서고 깊은 곳, 습기를 먹은 책장 사이에서 낡은 장부를 찾아냈다. 마지막 장이 뜯겨 있다."}, {"s": "night_office:han", "t": "뜯긴 자리는 기록해 둬라. 없는 것도 기록이다."}, {"s": null, "t": "「야행관」으로 올랐다."}]'::jsonb, '{"items": {"spirit_qi_pill": 3, "ward_talisman": 3}, "merit": 60}'::jsonb, 5, 300),
  ('night_office:rank:3', 'night_office', 'rank', 3, '감찰의 눈', '토벌 승리 5회 · 탐색에서 단서 1개', '{"tasks": [{"t": "win", "n": 5}, {"t": "clue", "n": 1}]}'::jsonb, '[{"s": "night_office:han", "t": "야시장에 이름 없는 장부가 돈다. 산 사람도 판 사람도 입을 닫는다. 그 길을 따라가 봐라."}, {"s": null, "t": "장부를 판 자는 이미 사라졌다. 남은 것은 젖은 먹 냄새와 연꽃을 그린 종이 한 장이다."}, {"s": "night_office:han", "t": "…연꽃이라. 이 일은 내가 직접 올린다. 너는 오늘부터 감찰을 맡는다."}, {"s": null, "t": "「감찰 야행관」으로 올랐다."}]'::jsonb, '{"items": {"rejuv_pill": 2, "revival_charm": 1}, "merit": 90}'::jsonb, 10, 800),
  ('night_office:rank:4', 'night_office', 'rank', 4, '얼음 인장 호송', '철벽 고찰까지 이동 · 빙혼곡 원정 1회 완주', '{"tasks": [{"t": "travel", "n": 1, "r": ["iron_monastery"]}, {"t": "expedition", "n": 1, "r": ["frost_valley"]}]}'::jsonb, '[{"s": "night_office:baek", "t": "북령맹이 도움을 청해 왔네. 얼음 인장에 금이 갔다지. 우리 봉인 문서를 직접 건네주게."}, {"s": null, "t": "철벽 고찰의 승려들이 문서를 받아 들고 고개를 숙인다. 정통파와 북령맹의 인장이 나란히 찍힌다."}, {"s": "night_office:kang", "t": "산문 놈들이 고맙다는 말을 다 하네! 이런 날은 연무청에서 한잔해야지."}, {"s": null, "t": "「당상 야행관」으로 올랐다."}]'::jsonb, '{"items": {"grand_pill": 1, "moonlight_essence": 2}, "merit": 120}'::jsonb, 16, 1600),
  ('night_office:rank:5', 'night_office', 'rank', 5, '꺼지지 않는 등잔', '본부 정청에서 도제조 백운서를 만난다', '{"at": ["hq_dorm", "hq_yard"]}'::jsonb, '[{"s": "night_office:baek", "t": "판관의 자리는 쉽게 내주지 않네. 판관은 남이 쓴 기록을 다시 읽는 사람이거든."}, {"s": "night_office:baek", "t": "…그리고 언젠가는 우리 스스로 쓴 기록도 의심해야 하네. 등잔 밑이 가장 어두운 법이니."}, {"s": null, "t": "노인이 자신의 등잔에서 불을 덜어 새 등잔에 옮겨 붙인다."}, {"s": null, "t": "「야행 판관」이 되었다. 정통파 최고 등급이다."}]'::jsonb, '{"items": {"heavenly_dew": 1, "grand_pill": 1}, "merit": 150}'::jsonb, 22, 3000),
  ('night_office:vault:1', 'night_office', 'vault', 1, '본부 비고(秘庫)', '', '{}'::jsonb, '[{"s": "night_office:mo", "t": "어서 와요. 공훈은 여기서만 써요. 대신 파는 건 안 받아요. 비고는 받는 곳이 아니라 내주는 곳이라서요."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('night_office:hall:1', 'night_office', 'hall', 1, '팔괘 연무청', '', '{}'::jsonb, '[{"s": "night_office:kang", "t": "연무청이다! 오늘 등급에 맞는 상대를 붙여 주지. 이기면 정통파 이름으로 칭호를 새겨 주마!"}]'::jsonb, '{}'::jsonb, 1, 0),
  ('red_moon_cult:join:1', 'red_moon_cult', 'join', 1, '장터의 붉은 등', '백골 장터(또는 본부 정청 연락관)에서 주홍 무녀 단비를 찾는다', '{"at": ["bone_market", "hq_yard"]}'::jsonb, '[{"s": null, "t": "백골 장터의 끝, 뼈로 엮은 차양 아래 붉은 등 하나가 걸려 있다. 등 아래 앉은 소녀가 손짓한다."}, {"s": "red_moon_cult:danbi", "t": "왔네요. 정청 사람들은 우리를 마교라고 부르죠? 맞아요. 우린 그 이름이 싫지 않아요."}, {"s": "red_moon_cult:danbi", "t": "요기는 독이 아니에요. 다룰 줄 모르는 사람한테만 독이죠. 당신은 어느 쪽일까요?"}, {"s": "red_moon_cult:danbi", "t": "황무지로 나가 보세요. 붉은 모래가 당신을 먹으려 들 거예요. 먹히지 않고 돌아오면 그다음 이야기를 해요."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('red_moon_cult:join:2', 'red_moon_cult', 'join', 2, '붉은 모래의 시험', '적월 변경(적사 황무지 등)에서 토벌 승리 3회 · 침식 20 이상인 채로 돌아와 보고', '{"tasks": [{"t": "win", "n": 3, "r": ["red_plain", "glass_canyon", "black_sand_temple", "red_moon_fort"]}], "erosion": 20, "at": ["bone_market", "hq_yard"]}'::jsonb, '[{"s": null, "t": "돌아온 손끝이 붉게 저리다. 몸 어딘가에서 낯선 힘이 꿈틀거린다."}, {"s": "red_moon_cult:sama", "t": "흥. 살아 돌아왔군. 대부분은 첫 달을 못 넘긴다."}, {"s": "red_moon_cult:sama", "t": "그 저린 손. 그게 요기다. 정청 놈들은 그걸 씻어 내라고 하지. 우리는 삼키라고 한다."}, {"s": "red_moon_cult:danbi", "t": "호법님이 말을 거셨으니 합격이에요. 호법님은 시체한테는 말을 안 거시거든요."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('red_moon_cult:join:3', 'red_moon_cult', 'join', 3, '월식의 입교', '백골 장터의 붉은 등 아래에서 입교 의식을 치른다', '{"at": ["bone_market", "hq_yard"]}'::jsonb, '[{"s": null, "t": "등불이 모두 꺼진다. 어둠 속에서 붉은 면사포가 흔들린다. 목소리는 가까운데 발소리는 들리지 않는다."}, {"s": "red_moon_cult:wolhwa", "t": "달은 차오르고, 먹히고, 다시 차오른다. 우리도 그렇다."}, {"s": "red_moon_cult:wolhwa", "t": "세상은 우리를 금기라 불렀다. 그러니 우리는 금기로 세상을 지킨다. 저들이 감당하지 못한 것을, 우리가 삼켜서."}, {"s": "red_moon_cult:wolhwa", "t": "네 피 한 방울을 달에 바쳐라. 그 대신 달이 너를 기억할 것이다."}, {"s": null, "t": "손바닥에 붉은 달 모양의 자국이 떠올랐다가 스며든다."}, {"s": null, "t": "「입문 교도」가 되었다. 적월교의 비고와 수련장이 열린다."}]'::jsonb, '{"items": {"tonic": 5, "clear_spirit_pill": 3, "spirit_qi_pill": 2}, "merit": 30}'::jsonb, 1, 0),
  ('red_moon_cult:rejoin:1', 'red_moon_cult', 'rejoin', 1, '돌아온 이에게', '', '{}'::jsonb, '[{"s": "red_moon_cult:danbi", "t": "어머, 돌아왔네요. 달은 떠난 사람을 원망하지 않아요. 기억할 뿐이죠."}, {"s": "red_moon_cult:sama", "t": "한 번 등 돌린 자는 두 배로 증명해야 한다. 잊지 마라."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('red_moon_cult:rank:2', 'red_moon_cult', 'rank', 2, '혈서', '유리협곡에서 채집 3회', '{"tasks": [{"t": "gather", "n": 3, "r": ["glass_canyon"]}]}'::jsonb, '[{"s": "red_moon_cult:danbi", "t": "혈서를 쓸 먹이 모자라요. 유리협곡 절벽의 붉은 결정을 갈아서 써요."}, {"s": null, "t": "결정을 갈아 만든 먹으로 이름을 쓰자, 글자가 잠깐 맥박처럼 뛴다."}, {"s": null, "t": "「혈인 교도」로 올랐다."}]'::jsonb, '{"items": {"spirit_qi_pill": 3, "ward_talisman": 3}, "merit": 60}'::jsonb, 8, 300),
  ('red_moon_cult:rank:3', 'red_moon_cult', 'rank', 3, '흑사단의 그림자', '흑사단 폐단에서 토벌 승리 5회', '{"tasks": [{"t": "win", "n": 5, "r": ["black_sand_temple"]}]}'::jsonb, '[{"s": "red_moon_cult:sama", "t": "흑사단. 한때 우리 형제였다. 지금은 이름 없는 시체들이 그 자리를 지킨다."}, {"s": "red_moon_cult:sama", "t": "그들이 무엇을 바쳤는지 묻지 마라. 너는 그 자리를 지나 돌아오기만 하면 된다."}, {"s": null, "t": "폐단의 벽에는 수백 개의 이름이 긁혀 지워져 있었다."}, {"s": null, "t": "「월식 집사」로 올랐다."}]'::jsonb, '{"items": {"rejuv_pill": 2, "revival_charm": 1}, "merit": 90}'::jsonb, 10, 800),
  ('red_moon_cult:rank:4', 'red_moon_cult', 'rank', 4, '먹히는 달', '적월교 월식성에서 탐색 3회', '{"tasks": [{"t": "search", "n": 3, "r": ["red_moon_fort"]}]}'::jsonb, '[{"s": null, "t": "월식성의 하늘에는 달이 반만 떠 있다. 나머지 반은 무언가에 먹힌 채로 멈춰 있다."}, {"s": "red_moon_cult:wolhwa", "t": "보았느냐. 저것이 우리가 지키는 것이다. 정청은 저 달을 원망하지만, 저 달이 다 먹히는 날 세상도 함께 먹힌다."}, {"s": null, "t": "「적월 호법」으로 올랐다."}]'::jsonb, '{"items": {"grand_pill": 1, "moonlight_essence": 2}, "merit": 120}'::jsonb, 16, 1600),
  ('red_moon_cult:rank:5', 'red_moon_cult', 'rank', 5, '면사포 너머', '백골 장터에서 교주 월화를 만난다', '{"at": ["bone_market", "hq_yard"]}'::jsonb, '[{"s": "red_moon_cult:wolhwa", "t": "장로가 되는 자에게만 하는 말이 있다."}, {"s": "red_moon_cult:wolhwa", "t": "나는 교를 이끄는 자가 아니다. 교에 붙들린 자다. 언젠가 내가 달에 먹히면, 그때는 네가 이 면사포를 들어라."}, {"s": null, "t": "면사포 아래로 붉은 눈 하나가 잠깐 보였다가 사라진다."}, {"s": null, "t": "「홍월 장로」가 되었다. 적월교 최고 등급이다."}]'::jsonb, '{"items": {"heavenly_dew": 1, "grand_pill": 1}, "merit": 150}'::jsonb, 22, 3000),
  ('red_moon_cult:vault:1', 'red_moon_cult', 'vault', 1, '혈월 비고', '', '{}'::jsonb, '[{"s": "red_moon_cult:danbi", "t": "위계로만 사요. 전으로는 못 사요. 팔러 오셨다면… 그건 장터에서 하세요. 여긴 바치는 곳이지 파는 곳이 아니에요."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('red_moon_cult:hall:1', 'red_moon_cult', 'hall', 1, '월식 수련굴', '', '{}'::jsonb, '[{"s": "red_moon_cult:sama", "t": "수련굴이다. 약한 자는 들어가지 마라. 강한 자도 마찬가지다. 들어간 자만 강해진다."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('black_lotus:join:1', 'black_lotus', 'join', 1, '첫 번째 빚', '십삼문 암시장(또는 본부 정청 연락관)에서 장부지기 구슬과 계약한다 · 300전', '{"at": ["hidden_bazaar", "hq_yard"], "cost": 300}'::jsonb, '[{"s": null, "t": "열두 개의 문을 지나면 문이 하나 더 있다. 아무도 그 문을 세지 않는다."}, {"s": "black_lotus:guseul", "t": "어서 오세요, 손님. 여기선 무엇이든 팔아요. 물건, 소문, 기억, 이름까지요."}, {"s": "black_lotus:guseul", "t": "들어오려면 빚을 하나 지셔야 해요. 돈으로 갚을 수 있는 작은 빚. 그래야 우리가 손님을 믿죠."}, {"s": null, "t": "주판알이 세 번 튕긴다. 계약서 한 귀퉁이에 검은 연꽃이 피어난다."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('black_lotus:join:2', 'black_lotus', 'join', 2, '팔리지 않은 소문', '탐색 2회 · 탐색에서 단서 1개 뒤 보고', '{"tasks": [{"t": "search", "n": 2}, {"t": "clue", "n": 1}], "at": ["hidden_bazaar", "hq_yard"]}'::jsonb, '[{"s": "black_lotus:six", "t": "빚은 갚아야 한다. 돈 말고, 정보로."}, {"s": "black_lotus:six", "t": "정청이 숨기는 것. 아무거나 하나. 기록에 없는 것일수록 비싸다."}, {"s": null, "t": "가져온 단서를 받아 든 여섯째가 손가락으로 무언가를 센다. 그리고 한 번 고개를 끄덕인다."}, {"s": "black_lotus:guseul", "t": "빚은 갚으셨어요. 이자는 받지 않을게요. 첫 손님이니까."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('black_lotus:join:3', 'black_lotus', 'join', 3, '이름을 맡기는 밤', '열세 번째 문 앞에서 회주 무명을 만난다', '{"at": ["hidden_bazaar", "hq_yard"]}'::jsonb, '[{"s": null, "t": "문 너머 방에는 등도 의자도 없다. 목소리만 있다."}, {"s": "black_lotus:mumyeong", "t": "진실은 기록되지 않은 곳에 있다. 기록된 것은 이미 누군가가 고른 진실이지."}, {"s": "black_lotus:mumyeong", "t": "나는 내 이름을 팔았다. 그 값으로 이 문을 샀지. 너에게 그만큼을 바라진 않는다."}, {"s": "black_lotus:mumyeong", "t": "이름의 한 글자만 이 장부에 맡겨라. 네가 우리를 배신하지 않는 한 아무도 그 글자를 꺼내지 않는다."}, {"s": null, "t": "「빚진 손님」이 되었다. 흑련회의 비고와 수련장이 열린다."}]'::jsonb, '{"items": {"tonic": 5, "clear_spirit_pill": 3, "spirit_qi_pill": 2}, "merit": 30}'::jsonb, 1, 0),
  ('black_lotus:rejoin:1', 'black_lotus', 'rejoin', 1, '돌아온 이에게', '', '{}'::jsonb, '[{"s": "black_lotus:guseul", "t": "돌아오셨네요. 맡기신 글자는 그대로 있어요. 우리는 손님을 잊지 않아요."}, {"s": "black_lotus:six", "t": "빚은 없다. 이번에는."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('black_lotus:rank:2', 'black_lotus', 'rank', 2, '만인장의 비석', '만인장에서 탐색 3회', '{"tasks": [{"t": "search", "n": 3, "r": ["burial_steps"]}]}'::jsonb, '[{"s": "black_lotus:guseul", "t": "만인장 비석 중에 이름이 지워진 게 있어요. 누가 그 이름을 샀는지 알아 오세요."}, {"s": null, "t": "비석 뒤편에 작은 글씨로 적힌 숫자. 장부의 쪽수다."}, {"s": null, "t": "「연잎」으로 올랐다."}]'::jsonb, '{"items": {"spirit_qi_pill": 3, "ward_talisman": 3}, "merit": 60}'::jsonb, 10, 300),
  ('black_lotus:rank:3', 'black_lotus', 'rank', 3, '두 장부', '거래소에서 사거나 팔기 1회 · 탐색 3회', '{"tasks": [{"t": "trade", "n": 1}, {"t": "search", "n": 3}]}'::jsonb, '[{"s": "black_lotus:six", "t": "정청 장부와 우리 장부. 같은 일을 적었는데 숫자가 다르다. 어느 쪽이 틀렸는지 찾아라."}, {"s": null, "t": "틀린 쪽은 정청 장부였다. 그런데 고친 사람의 필체가 흑련회 것이다."}, {"s": "black_lotus:six", "t": "…거기까지만 봐라."}, {"s": null, "t": "「흑련 손」으로 올랐다."}]'::jsonb, '{"items": {"rejuv_pill": 2, "revival_charm": 1}, "merit": 90}'::jsonb, 12, 800),
  ('black_lotus:rank:4', 'black_lotus', 'rank', 4, '무명 고도의 문', '무명 고도 원정 1회 완주', '{"tasks": [{"t": "expedition", "n": 1, "r": ["forgotten_city"]}]}'::jsonb, '[{"s": "black_lotus:mumyeong", "t": "고도의 폐궁에는 문이 하나 있다. 아직 열 때가 아니다. 다만 문지기는 문을 알아야 한다."}, {"s": null, "t": "폐궁의 문에는 열세 개의 자물쇠가 있었고, 그중 몇 개는 이미 열려 있었다."}, {"s": null, "t": "「열세 번째 문지기」로 올랐다."}]'::jsonb, '{"items": {"grand_pill": 1, "moonlight_essence": 2}, "merit": 120}'::jsonb, 16, 1600),
  ('black_lotus:rank:5', 'black_lotus', 'rank', 5, '이름 없는 자의 대리', '열세 번째 문 앞에서 회주 무명을 만난다', '{"at": ["hidden_bazaar", "hq_yard"]}'::jsonb, '[{"s": "black_lotus:mumyeong", "t": "흑련의 뿌리가 어디 있는지 궁금하겠지. 너희가 가장 잘 아는 곳이다. 그래서 아무도 보지 못하는 곳."}, {"s": "black_lotus:mumyeong", "t": "언젠가 그 뿌리가 썩으면, 베는 것은 너다. 그것이 대리의 일이다."}, {"s": null, "t": "맡겨 두었던 이름의 한 글자를 돌려받았다. 이제 빚은 없다."}, {"s": null, "t": "「연주 대리」가 되었다. 흑련회 최고 등급이다."}]'::jsonb, '{"items": {"heavenly_dew": 1, "grand_pill": 1}, "merit": 150}'::jsonb, 22, 3000),
  ('black_lotus:vault:1', 'black_lotus', 'vault', 1, '열세 번째 문', '', '{}'::jsonb, '[{"s": "black_lotus:guseul", "t": "인연채무로만 받아요. 되파는 건 안 돼요. 여기서 나간 물건은 이미 누군가의 빚이거든요."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('black_lotus:hall:1', 'black_lotus', 'hall', 1, '그림자 장부실', '', '{}'::jsonb, '[{"s": "black_lotus:six", "t": "장부실이다. 너보다 빚이 많은 자를 붙여 주마. 이기면 장부에서 한 줄 지워 주지."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('north_league:join:1', 'north_league', 'join', 1, '산문을 두드리다', '철벽 고찰(또는 본부 정청 연락관)에서 호송대장 여운비를 만난다', '{"at": ["hq_yard", "iron_monastery"]}'::jsonb, '[{"s": null, "t": "눈 덮인 산문 앞. 철갑을 두른 여인이 창을 땅에 꽂고 길을 막는다."}, {"s": "north_league:yeo", "t": "맹에 들고 싶다고? 북령맹은 세력이 아니다. 맹약이다. 약한 자를 지키겠다고 맹세하는 자들의 모임이지."}, {"s": "north_league:yeo", "t": "말로는 아무나 맹세한다. 길 위에서 보여 줘라. 회산 관문까지 짐 하나를 날라 와."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('north_league:join:2', 'north_league', 'join', 2, '호송의 길', '다른 지역으로 이동 2회 · 토벌 승리 3회 뒤 보고', '{"tasks": [{"t": "travel", "n": 2}, {"t": "win", "n": 3}], "at": ["hq_yard", "iron_monastery"]}'::jsonb, '[{"s": null, "t": "짐은 무겁지 않았다. 그런데 길 위의 요괴들은 꼭 짐 쪽을 노렸다."}, {"s": "north_league:yeo", "t": "짐을 지켰군. 사람이었으면 살았겠다. 그거면 됐다."}, {"s": "north_league:hyegak", "t": "허허, 대장께서 칭찬을 하시다니. 눈이 그치겠습니다."}, {"s": "north_league:hyegak", "t": "맹주께서 기다리십니다. 손이 먼저 나가는 분이니, 놀라지 마시고."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('north_league:join:3', 'north_league', 'join', 3, '얼음 인장 아래의 맹약', '맹주 석진악 앞에서 맹약을 맺는다', '{"at": ["hq_yard", "iron_monastery"]}'::jsonb, '[{"s": null, "t": "고찰의 종각 아래, 얼음처럼 투명한 인장이 매달려 있다. 노인이 맨손으로 그 인장을 짚고 서 있다."}, {"s": "north_league:seok", "t": "…"}, {"s": null, "t": "노인의 주먹이 바람을 가르며 코앞에서 멈춘다. 눈을 감지 않았다."}, {"s": "north_league:seok", "t": "좋다. 눈을 감는 자는 뒤에 선 사람을 못 지킨다."}, {"s": "north_league:seok", "t": "무력은 약한 자를 위해 있다. 그 반대가 되는 날, 맹은 너를 벤다. 맹세하겠느냐."}, {"s": null, "t": "「산문 제자」가 되었다. 북령맹의 비고와 수련장이 열린다."}]'::jsonb, '{"items": {"tonic": 5, "clear_spirit_pill": 3, "spirit_qi_pill": 2}, "merit": 30}'::jsonb, 1, 0),
  ('north_league:rejoin:1', 'north_league', 'rejoin', 1, '돌아온 이에게', '', '{}'::jsonb, '[{"s": "north_league:yeo", "t": "돌아왔나. 맹약은 한 번 깨져도 다시 맺을 수 있다. 두 번째는 더 단단하게."}, {"s": "north_league:seok", "t": "…오너라."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('north_league:rank:2', 'north_league', 'rank', 2, '회산 관문의 밤', '회산 관문에서 토벌 승리 5회', '{"tasks": [{"t": "win", "n": 5, "r": ["ash_mountain"]}]}'::jsonb, '[{"s": "north_league:yeo", "t": "관문에 붉은 달 문양이 그려진 깃발이 꽂혔다. 뽑아 와라. 그리고 꽂은 놈들도."}, {"s": null, "t": "깃발을 뽑자 바람이 바뀌었다. 북쪽 바람이다."}, {"s": null, "t": "「맹약 무사」로 올랐다."}]'::jsonb, '{"items": {"spirit_qi_pill": 3, "ward_talisman": 3}, "merit": 60}'::jsonb, 7, 300),
  ('north_league:rank:3', 'north_league', 'rank', 3, '옥문 협로 호송', '옥문 협로 원정 1회 완주', '{"tasks": [{"t": "expedition", "n": 1, "r": ["jade_pass"]}]}'::jsonb, '[{"s": "north_league:yeo", "t": "피난민 행렬이 협로를 지난다. 우리가 앞에 서고, 뒤에 서고, 옆에 선다."}, {"s": null, "t": "행렬 끝의 아이가 무사가 된 당신의 뒷모습을 오래 바라본다."}, {"s": null, "t": "「호위 무사」로 올랐다."}]'::jsonb, '{"items": {"rejuv_pill": 2, "revival_charm": 1}, "merit": 90}'::jsonb, 10, 800),
  ('north_league:rank:4', 'north_league', 'rank', 4, '금 간 인장', '빙혼곡에서 채집 3회 · 천경호에서 탐색 2회', '{"tasks": [{"t": "gather", "n": 3, "r": ["frost_valley"]}, {"t": "search", "n": 2, "r": ["sky_lake"]}]}'::jsonb, '[{"s": "north_league:hyegak", "t": "인장에 금이 갔습니다. 녹은 얼음을 다시 얼릴 수는 없지만, 더 녹지 않게는 할 수 있지요."}, {"s": "north_league:seok", "t": "인장이 깨지는 날이 와도 맹은 깨지지 않는다. 그걸 위해 너를 호법으로 세운다."}, {"s": null, "t": "「철벽 호법」으로 올랐다."}]'::jsonb, '{"items": {"grand_pill": 1, "moonlight_essence": 2}, "merit": 120}'::jsonb, 13, 1600),
  ('north_league:rank:5', 'north_league', 'rank', 5, '뇌명봉의 맹세', '뇌명봉 우두머리 쓰러뜨리기', '{"tasks": [{"t": "win", "n": 1, "r": ["thunder_peak"], "rank": "guardian"}]}'::jsonb, '[{"s": null, "t": "벼락이 그치지 않는 봉우리 꼭대기. 노인이 먼저 올라 기다리고 있다."}, {"s": "north_league:seok", "t": "나도 언젠가 늙어 쓰러진다. 그때 인장 앞에 설 자가 필요하다."}, {"s": "north_league:seok", "t": "…맹을 부탁한다."}, {"s": null, "t": "「북령 장로」가 되었다. 북령맹 최고 등급이다."}]'::jsonb, '{"items": {"heavenly_dew": 1, "grand_pill": 1}, "merit": 150}'::jsonb, 22, 3000),
  ('north_league:vault:1', 'north_league', 'vault', 1, '산문 무기고', '', '{}'::jsonb, '[{"s": "north_league:yeo", "t": "맹공으로 내준다. 되팔 생각이면 가져가지 마라. 맹의 무기는 지키는 데 쓰는 거다."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('north_league:hall:1', 'north_league', 'hall', 1, '철벽 연무장', '', '{}'::jsonb, '[{"s": "north_league:hyegak", "t": "허허, 연무장입니다. 오늘은 누구를 눕혀 드릴까요. 아, 반대였던가요."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('river_alliance:join:1', 'river_alliance', 'join', 1, '보증인을 찾아서', '구름나루(또는 본부 정청 연락관)에서 뱃사공 노들 영감과 이야기한다', '{"at": ["hq_yard", "river_ferry"]}'::jsonb, '[{"s": null, "t": "안개 낀 나루. 배 한 척이 물결에 흔들리고, 노인이 곰방대를 문 채 손님을 훑어본다."}, {"s": "river_alliance:nodeul", "t": "연맹에 들겠다고? 그럼 보증인이 있어야지. 여긴 사람을 믿지 않아. 사람의 약속을 믿지."}, {"s": "river_alliance:nodeul", "t": "내가 서 주마. 대신 내 부탁 하나 들어줘. 염등촌에 물건 좀 대 줘야 하거든."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('river_alliance:join:2', 'river_alliance', 'join', 2, '첫 거래', '채집 3회 · 상점에서 물건 팔기 1회 뒤 보고', '{"tasks": [{"t": "gather", "n": 3}, {"t": "sell", "n": 1}], "at": ["hq_yard", "river_ferry"]}'::jsonb, '[{"s": "river_alliance:maehyang", "t": "노들 영감이 보증을 섰다고요? 흠. 영감이 보증 선 사람은 열 명 중 아홉이 돈을 벌었어요."}, {"s": "river_alliance:maehyang", "t": "물건은 잘 받았어요. 값도 제대로 매겼고요. 장사는 거짓말을 안 하는 게 제일 남는 장사예요."}, {"s": "river_alliance:nodeul", "t": "거 봐라. 내 눈은 아직 멀쩡하다니까."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('river_alliance:join:3', 'river_alliance', 'join', 3, '물 위의 서명', '도방 진소랑의 배 위에서 서명한다', '{"at": ["hq_yard", "river_ferry"]}'::jsonb, '[{"s": null, "t": "연맹의 큰 배 위, 비단 차양 아래에서 여인이 주판을 내려놓는다."}, {"s": "river_alliance:jin", "t": "강과 길은 누구의 것도 아니에요. 그 위를 오가는 약속만이 우리 것이죠."}, {"s": "river_alliance:jin", "t": "정청도 적월교도, 다 우리 배를 타요. 우리는 누구 편도 아니에요. 그래서 모두가 우리를 필요로 하죠."}, {"s": "river_alliance:jin", "t": "여기 서명하세요. 지키면 이 강이 당신을 실어 나를 거예요. 어기면… 강은 깊으니까요."}, {"s": null, "t": "「보증 손님」이 되었다. 수향연맹의 비고와 수련장이 열린다."}]'::jsonb, '{"items": {"tonic": 5, "clear_spirit_pill": 3, "spirit_qi_pill": 2}, "merit": 30}'::jsonb, 1, 0),
  ('river_alliance:rejoin:1', 'river_alliance', 'rejoin', 1, '돌아온 이에게', '', '{}'::jsonb, '[{"s": "river_alliance:maehyang", "t": "다시 오셨네요. 지난 장부는 깨끗하게 닫혀 있어요. 새로 열죠."}, {"s": "river_alliance:nodeul", "t": "떠났다 돌아오는 배가 제일 반가운 법이지."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('river_alliance:rank:2', 'river_alliance', 'rank', 2, '염등촌의 등', '염등촌까지 이동 · 염등촌에서 채집 3회', '{"tasks": [{"t": "travel", "n": 1, "r": ["salt_village"]}, {"t": "gather", "n": 3, "r": ["salt_village"]}]}'::jsonb, '[{"s": "river_alliance:maehyang", "t": "염등촌 사람들이 소금 등잔에 쓸 기름이 떨어졌대요. 연맹 이름으로 대 주세요."}, {"s": null, "t": "등잔에 불이 다시 켜지자 마을 사람들이 연맹 깃발을 향해 고개를 숙인다."}, {"s": null, "t": "「나루 객주」로 올랐다."}]'::jsonb, '{"items": {"spirit_qi_pill": 3, "ward_talisman": 3}, "merit": 60}'::jsonb, 5, 300),
  ('river_alliance:rank:3', 'river_alliance', 'rank', 3, '거꾸로 흐르는 물시계', '수경루에서 탐색 2회', '{"tasks": [{"t": "search", "n": 2, "r": ["mirror_pavilion"]}]}'::jsonb, '[{"s": "river_alliance:nodeul", "t": "수경루 물시계가 거꾸로 흐른다는 소문이 돌아. 물길이 뒤집히면 배도 뒤집혀."}, {"s": null, "t": "물시계 밑바닥에 작은 거울 조각이 박혀 있었다. 비친 것은 물 밑의 무언가였다."}, {"s": null, "t": "「상단 행수」로 올랐다."}]'::jsonb, '{"items": {"rejuv_pill": 2, "revival_charm": 1}, "merit": 90}'::jsonb, 9, 800),
  ('river_alliance:rank:4', 'river_alliance', 'rank', 4, '연맹의 뱃길', '거래소에서 사거나 팔기 1회 · 서로 다른 안전지대 3곳 들르기', '{"tasks": [{"t": "trade", "n": 1}, {"t": "travel", "n": 3, "safe": true, "distinct": true}]}'::jsonb, '[{"s": "river_alliance:jin", "t": "전쟁이 나면 제일 먼저 끊기는 게 뱃길이에요. 그 뱃길을 붙잡아 둘 사람이 필요해요."}, {"s": null, "t": "세 곳의 안전지대에 연맹 깃발이 새로 걸렸다."}, {"s": null, "t": "「대행수」로 올랐다."}]'::jsonb, '{"items": {"grand_pill": 1, "moonlight_essence": 2}, "merit": 120}'::jsonb, 14, 1600),
  ('river_alliance:rank:5', 'river_alliance', 'rank', 5, '용잠 수궁의 노래', '용잠 수궁 원정 1회 완주', '{"tasks": [{"t": "expedition", "n": 1, "r": ["sunken_palace"]}]}'::jsonb, '[{"s": "river_alliance:jin", "t": "수궁 깊은 곳에서 노래가 들린대요. 그 노래가 무엇을 부르는지, 연맹은 알아야 해요."}, {"s": "river_alliance:jin", "t": "그리고 이건 장사가 아니라 부탁이에요. 도방이 하는 첫 부탁."}, {"s": null, "t": "진소랑이 자신의 주판을 건넨다. 알 하나가 붉다."}, {"s": null, "t": "「연맹 도방」이 되었다. 수향연맹 최고 등급이다."}]'::jsonb, '{"items": {"heavenly_dew": 1, "grand_pill": 1}, "merit": 150}'::jsonb, 21, 3000),
  ('river_alliance:vault:1', 'river_alliance', 'vault', 1, '상단 별고(別庫)', '', '{}'::jsonb, '[{"s": "river_alliance:maehyang", "t": "신용으로 사 가세요. 별고 물건은 되팔 수 없어요. 연맹이 신용을 걸고 내준 물건이니까요."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('river_alliance:hall:1', 'river_alliance', 'hall', 1, '물길 시험장', '', '{}'::jsonb, '[{"s": "river_alliance:nodeul", "t": "물길 시험장이다. 물은 쉬지 않아. 버티는 놈만 건너가지."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('southern_remnant:join:1', 'southern_remnant', 'join', 1, '꺼져 가는 마을', '잔불촌(또는 본부 정청 연락관)에서 정찰대장 갈매를 만난다', '{"at": ["ember_village", "hq_yard"]}'::jsonb, '[{"s": null, "t": "잔불촌의 화로들은 모두 반쯤 꺼져 있다. 사람들은 재를 긁어모아 불씨를 살린다."}, {"s": "southern_remnant:galmae", "t": "또 구경꾼인가? 여긴 볼 거 없어. 망한 나라 사람들이 아직 안 죽고 사는 것 말고는."}, {"s": "southern_remnant:galmae", "t": "…진심이야? 그럼 마을을 지켜 봐. 밤마다 재 속에서 뭔가가 기어 나와."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('southern_remnant:join:2', 'southern_remnant', 'join', 2, '잔불촌 수호', '토벌 승리 3회 · 채집 2회 뒤 보고', '{"tasks": [{"t": "win", "n": 3}, {"t": "gather", "n": 2}], "at": ["ember_village", "hq_yard"]}'::jsonb, '[{"s": null, "t": "새벽이 되자 화로 몇 개에 다시 불이 붙었다. 지킨 만큼 불이 살아난다."}, {"s": "southern_remnant:galmae", "t": "…고마워. 이런 말 잘 안 해."}, {"s": "southern_remnant:soi", "t": "그대가 지킨 화로에서 옛 노래가 들리더이다. 망자들도 그대를 보았나 보오."}, {"s": "southern_remnant:soi", "t": "장군께서 뵙자 하시오. 남은 한 팔로 그대를 맞으실 게요."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('southern_remnant:join:3', 'southern_remnant', 'join', 3, '불씨 나눔', '꺼지지 않는 화로 앞에서 노장 장무현을 만난다', '{"at": ["ember_village", "hq_yard"]}'::jsonb, '[{"s": null, "t": "마을 한가운데, 절대 꺼뜨리지 않는다는 화로. 외팔의 노장이 그 앞에 앉아 있다."}, {"s": "southern_remnant:jang", "t": "우리 나라는 망했다. 왕도, 성도, 깃발도 없다. 남은 건 이 불씨뿐이다."}, {"s": "southern_remnant:jang", "t": "빼앗긴 땅을 되찾자고 하면 다들 웃더군. 그래도 우리는 불을 끄지 않는다. 불이 있는 한 나라는 끝나지 않으니."}, {"s": null, "t": "노장이 화로에서 불씨 하나를 집어 작은 등에 옮겨 담아 건넨다."}, {"s": "southern_remnant:jang", "t": "꺼뜨리지 마라. 그게 맹세의 전부다."}, {"s": null, "t": "「불씨 지기」가 되었다. 남명회의 비고와 수련장이 열린다."}]'::jsonb, '{"items": {"tonic": 5, "clear_spirit_pill": 3, "spirit_qi_pill": 2}, "merit": 30}'::jsonb, 1, 0),
  ('southern_remnant:rejoin:1', 'southern_remnant', 'rejoin', 1, '돌아온 이에게', '', '{}'::jsonb, '[{"s": "southern_remnant:soi", "t": "돌아오셨구려. 그대가 맡긴 불씨, 우리가 대신 지키고 있었소."}, {"s": "southern_remnant:galmae", "t": "흥. 다시 왔으면 이번엔 끝까지 있어."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('southern_remnant:rank:2', 'southern_remnant', 'rank', 2, '재의 해안', '재의 해안에서 탐색 3회', '{"tasks": [{"t": "search", "n": 3, "r": ["ash_coast"]}]}'::jsonb, '[{"s": "southern_remnant:soi", "t": "해안의 재 속에 옛 왕궁의 기와 조각이 묻혀 있소. 하나라도 건져 오시오."}, {"s": null, "t": "재를 털어 낸 기와에 희미하게 남명의 문장이 남아 있다."}, {"s": null, "t": "「잔불」로 올랐다."}]'::jsonb, '{"items": {"spirit_qi_pill": 3, "ward_talisman": 3}, "merit": 60}'::jsonb, 10, 300),
  ('southern_remnant:rank:3', 'southern_remnant', 'rank', 3, '혈엽림의 쇠사슬', '혈엽림에서 토벌 승리 5회 · 채집 2회', '{"tasks": [{"t": "win", "n": 5, "r": ["red_forest"]}, {"t": "gather", "n": 2, "r": ["red_forest"]}]}'::jsonb, '[{"s": "southern_remnant:galmae", "t": "혈엽림에 묻힌 쇠사슬. 옛날에 뭔가를 매달았던 사슬이래. 누가 파 가기 전에 우리가 먼저."}, {"s": null, "t": "사슬 끝에는 아무것도 없었다. 매달려 있던 것은 이미 누군가 가져갔다."}, {"s": null, "t": "「횃불」로 올랐다."}]'::jsonb, '{"items": {"rejuv_pill": 2, "revival_charm": 1}, "merit": 90}'::jsonb, 12, 800),
  ('southern_remnant:rank:4', 'southern_remnant', 'rank', 4, '주혈 광산의 망자', '주혈 광산 원정 1회 완주', '{"tasks": [{"t": "expedition", "n": 1, "r": ["crimson_mine"]}]}'::jsonb, '[{"s": "southern_remnant:jang", "t": "광산에서 망자들이 일어났다. 우리 병사들이다. 저들을 다시 눕혀 다오."}, {"s": "southern_remnant:jang", "t": "…이번엔 편히 누우라고 전해 다오."}, {"s": null, "t": "「봉화」로 올랐다."}]'::jsonb, '{"items": {"grand_pill": 1, "moonlight_essence": 2}, "merit": 120}'::jsonb, 14, 1600),
  ('southern_remnant:rank:5', 'southern_remnant', 'rank', 5, '마지막 등대', '구등대 군도에서 탐색 3회', '{"tasks": [{"t": "search", "n": 3, "r": ["nine_lighthouse"]}]}'::jsonb, '[{"s": "southern_remnant:soi", "t": "아홉 등대 중 하나가 아직 켜져 있소. 망국의 마지막 날부터 한 번도 꺼진 적 없는 불이오."}, {"s": "southern_remnant:jang", "t": "수호장은 그 불을 지키는 자다. 나 다음은 너다."}, {"s": null, "t": "노장이 남은 한 팔로 처음으로 당신의 어깨를 짚는다."}, {"s": null, "t": "「남명 수호장」이 되었다. 남명회 최고 등급이다."}]'::jsonb, '{"items": {"heavenly_dew": 1, "grand_pill": 1}, "merit": 150}'::jsonb, 22, 3000),
  ('southern_remnant:vault:1', 'southern_remnant', 'vault', 1, '불씨 창고', '', '{}'::jsonb, '[{"s": "southern_remnant:soi", "t": "잔불로 바꿔 가시오. 다시 팔 생각은 마시오. 여기 물건은 다 누군가의 유품이니."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('southern_remnant:hall:1', 'southern_remnant', 'hall', 1, '봉화대 수련장', '', '{}'::jsonb, '[{"s": "southern_remnant:galmae", "t": "봉화대 수련장이야. 불이 꺼지기 전에 버텨. 그게 다야."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('mandate_court:join:1', 'mandate_court', 'join', 1, '관측 시험 응시', '본부 정청(또는 무극 관성대)에서 수석 관측관 서이연을 만난다', '{"at": ["hq_dorm", "hq_yard", "star_observatory"]}'::jsonb, '[{"s": null, "t": "정청 한구석, 별자리 도판을 펼쳐 놓은 관리가 하품을 한다."}, {"s": "mandate_court:seo", "t": "천명원 응시자? 아… 오늘 밤 관측 시험이에요. 별을 보는 시험은 아니고요, 땅을 보는 시험."}, {"s": "mandate_court:seo", "t": "하늘의 변화는 땅에 먼저 내려와요. 서로 다른 곳 세 군데를 살피고 와요. 날씨, 시간, 요기의 흐름까지."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('mandate_court:join:2', 'mandate_court', 'join', 2, '세 곳의 관측점', '서로 다른 지역 세 곳에서 탐색 뒤 보고', '{"tasks": [{"t": "search", "n": 3, "distinct": true}], "at": ["hq_dorm", "hq_yard", "star_observatory"]}'::jsonb, '[{"s": null, "t": "세 곳의 기록을 나란히 놓자, 요기의 흐름이 한 방향을 가리킨다. 남쪽이다."}, {"s": "mandate_court:seo", "t": "…오. 이걸 혼자 찾았어요? 보통 다섯 번은 다시 보내는데."}, {"s": "mandate_court:mun", "t": "기록은 정확하다. 결론은 쓰지 마라. 결론은 태사령께서 내리신다."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('mandate_court:join:3', 'mandate_court', 'join', 3, '별 아래의 서약', '혼천의 앞에서 태사령 하후정을 만난다', '{"at": ["hq_dorm", "hq_yard", "star_observatory"]}'::jsonb, '[{"s": null, "t": "혼천의가 천천히 돈다. 노학자가 그 앞에서 눈을 감고 있다."}, {"s": "mandate_court:hahu", "t": "천명은 정해져 있다. 다만 아는 자와 모르는 자가 있을 뿐이다."}, {"s": "mandate_court:hahu", "t": "우리를 두고 예언을 권력으로 쓴다고들 하지. 맞는 말이다. 그래서 우리는 예언을 함부로 입에 올리지 않는다."}, {"s": "mandate_court:hahu", "t": "본 것을 다 말하지 않겠다고 맹세하라. 그것이 별을 보는 자의 첫 번째 계율이다."}, {"s": null, "t": "「관측생」이 되었다. 천명원의 비고와 수련장이 열린다."}]'::jsonb, '{"items": {"tonic": 5, "clear_spirit_pill": 3, "spirit_qi_pill": 2}, "merit": 30}'::jsonb, 1, 0),
  ('mandate_court:rejoin:1', 'mandate_court', 'rejoin', 1, '돌아온 이에게', '', '{}'::jsonb, '[{"s": "mandate_court:seo", "t": "아, 다시 왔네요. 별자리는 그새 조금 움직였어요. 다시 맞춰 봐요."}, {"s": "mandate_court:mun", "t": "떠난 동안 본 것은 묻지 않겠다. 기록에도 남기지 않는다."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('mandate_court:rank:2', 'mandate_court', 'rank', 2, '삼경의 별', '삼경(0~6시)에 탐색 2회', '{"tasks": [{"t": "search", "n": 2, "phase": ["night"]}]}'::jsonb, '[{"s": "mandate_court:seo", "t": "삼경의 별은 낮에 안 보이는 걸 보여 줘요. 졸려도 참고 봐요. 나도 참으니까."}, {"s": null, "t": "삼경의 하늘에 낯선 별 하나가 떠 있다. 도판에 없는 별이다."}, {"s": null, "t": "「일관」으로 올랐다."}]'::jsonb, '{"items": {"spirit_qi_pill": 3, "ward_talisman": 3}, "merit": 60}'::jsonb, 5, 300),
  ('mandate_court:rank:3', 'mandate_court', 'rank', 3, '혈무의 기록', '농무·삭풍·혈무 가운데 한 날씨에 원정 1회 완주', '{"tasks": [{"t": "expedition", "n": 1, "weather": ["fog", "wind", "bloodmist"]}]}'::jsonb, '[{"s": "mandate_court:mun", "t": "날씨가 사나운 날에만 남는 흔적이 있다. 그 기록이 필요하다."}, {"s": null, "t": "사나운 날씨 속에서 쓴 기록에는 맑은 날에는 없던 숫자가 섞여 있다."}, {"s": null, "t": "「관상관」으로 올랐다."}]'::jsonb, '{"items": {"rejuv_pill": 2, "revival_charm": 1}, "merit": 90}'::jsonb, 10, 800),
  ('mandate_court:rank:4', 'mandate_court', 'rank', 4, '백옥 천문탑', '백옥 천문탑에서 탐색 3회', '{"tasks": [{"t": "search", "n": 3, "r": ["white_tower"]}]}'::jsonb, '[{"s": "mandate_court:hahu", "t": "천문탑의 거울이 흐려졌다. 하늘이 흐려진 것인지 거울이 흐려진 것인지 알아 오너라."}, {"s": null, "t": "거울은 멀쩡했다. 흐려진 것은 하늘 쪽이었다."}, {"s": null, "t": "「천문 교수」로 올랐다."}]'::jsonb, '{"items": {"grand_pill": 1, "moonlight_essence": 2}, "merit": 120}'::jsonb, 20, 1600),
  ('mandate_court:rank:5', 'mandate_court', 'rank', 5, '말하지 않은 예언', '무극 관성대(또는 본부 객사 분소)에서 태사령 하후정을 만난다', '{"at": ["hq_dorm", "hq_yard", "star_observatory"]}'::jsonb, '[{"s": "mandate_court:hahu", "t": "영대 감정은 내가 본 예언을 하나 물려받는다. 그리고 평생 그것을 말하지 않는다."}, {"s": null, "t": "노학자가 귓가에 무언가를 속삭인다. 그 말은 이 기록에 적지 않는다."}, {"s": null, "t": "「영대 감정」이 되었다. 천명원 최고 등급이다."}]'::jsonb, '{"items": {"heavenly_dew": 1, "grand_pill": 1}, "merit": 150}'::jsonb, 25, 3000),
  ('mandate_court:vault:1', 'mandate_court', 'vault', 1, '영대 서고', '', '{}'::jsonb, '[{"s": "mandate_court:mun", "t": "천문 허가로만 열람… 아니, 구입이다. 서고의 물건은 되팔 수 없다. 기록은 거래하지 않는다."}]'::jsonb, '{}'::jsonb, 1, 0),
  ('mandate_court:hall:1', 'mandate_court', 'hall', 1, '혼천의 시련실', '', '{}'::jsonb, '[{"s": "mandate_court:seo", "t": "시련실이에요. 혼천의가 도는 동안 버티면 돼요. 저는… 잠깐 눈 좀 붙일게요."}]'::jsonb, '{}'::jsonb, 1, 0)
on conflict (scene_key) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward, min_level = excluded.min_level, rep_need = excluded.rep_need;

-- 세력 인물 자세한 프로필: 한 줄 소개 대사(quote)와 인물 서술(detail). 세력 인물 칸에서 누르면 펼친다
alter table public.world_faction_npcs add column if not exists quote text not null default '';
alter table public.world_faction_npcs add column if not exists detail text not null default '';
update public.world_faction_npcs n set quote = v.quote, detail = v.detail from (values
  ('night_office:baek', '등잔은 누가 지켜보지 않아도 타야 하네.', '야행국이 세워질 무렵부터 정청을 지켜 온 도제조. 나이를 아는 사람은 없고, 본인도 묻는 말에 웃기만 한다. 젊은 시절 「백야(白夜)의 붓」이라 불리며 요괴 백 마리의 이름을 하룻밤에 적어 봉인했다는 이야기가 전하지만, 지금은 정청 안쪽 방에서 꺼지지 않는 등잔 하나를 지키며 결재 서류에 붉은 인장을 찍을 뿐이다. 말이 느리고 짧아 답답하다는 소리를 듣는데, 그가 「…앉게」라고 말한 뒤에 한 이야기는 누구도 잊지 못한다고 한다. 왼손 약지에 먹이 배어 지워지지 않는 자국이 있다.'),
  ('night_office:han', '기록에 없는 일은 일어나지 않은 일이다. 그러니 적어라.', '정통파 감찰관. 보고서의 쉼표 하나까지 되돌려 보내는 것으로 유명해 신입들 사이에서는 「한 줄 더」라는 별명으로 불린다. 원래 현장 조사원이었으나 동료 셋을 잃은 사건의 보고서가 위에서 고쳐 쓰인 것을 본 뒤로 감찰관을 자청했다고 한다. 차갑게 굴지만 신입이 처음 올린 장부는 몰래 따로 묶어 서랍에 보관한다. 붓을 닦는 버릇이 있는데, 화가 날수록 더 천천히 닦는다.'),
  ('night_office:mo', '장부 냄새 맡아 봤어요? 오래된 먹은 단내가 나요.', '장서각 지하서고를 맡은 기록관이자 정청 비고의 관리인. 서고의 책장 순서를 모두 외우고, 찾는 책이 어디 있는지 묻기도 전에 꺼내 온다. 말이 많고 다정해서 신입들의 고민 상담을 도맡지만, 장서각 깊은 곳의 봉인된 서가에 대해서는 웃으며 말을 돌린다. 손님이 오면 늘 식은 보리차를 내오는데, 뜨거운 차는 종이에 해롭다는 이유다.'),
  ('night_office:kang', '땀으로 적은 기록은 번지지 않는다! 하하!', '팔괘 연무청의 교관. 목소리가 커서 연무장 끝에서 불러도 정청 마루까지 들린다. 북령맹에서 수련하다 정통파로 옮겨 온 드문 내력이 있어 산문의 무예와 야행국의 봉인술을 섞어 가르친다. 신입이 쓰러지면 제일 먼저 달려와 업고 가는 사람이 그다. 연무청 기둥마다 그가 부순 목인(木人)의 수가 칼자국으로 새겨져 있다.'),
  ('red_moon_cult:wolhwa', '달은 원망하지 않는다. 기억할 뿐이다.', '적월교의 교주. 붉은 면사포 너머로 얼굴을 보인 적이 없고, 걸어도 발소리가 나지 않는다. 교도들은 그가 이미 반쯤 달에 먹혔다고 수군댄다. 월식성의 거울 앞에서 밤을 새우는 날이 많으며, 그 거울에 무엇이 비치는지는 장로들에게만 이야기한다고 한다. 목소리는 가까이서 들리는데 모습은 늘 몇 걸음 떨어져 있다. 교를 「이끈다」가 아니라 「붙들려 있다」고 말하는 유일한 사람.'),
  ('red_moon_cult:sama', '약한 자는 들어오지 마라. 강한 자도 마찬가지다.', '적월교의 대호법. 문 두 짝을 합친 것만큼 어깨가 넓고, 팔뚝에는 삼킨 요기만큼 붉은 문신이 늘어 간다. 약한 자를 경멸하지만 한번 살아 돌아온 자는 끝까지 챙기는 사람이라, 교도들은 그를 두려워하면서도 그의 등 뒤에 서려 한다. 흑사단에 있었던 옛 동료들의 이름을 혼자 외우고 다닌다는 소문이 있다. 수련굴 입구에 앉아 무를 깎아 먹는 모습이 자주 보인다.'),
  ('red_moon_cult:danbi', '어머, 무서워요? 괜찮아요. 처음엔 다 그래요.', '백골 장터 끝 붉은 등 아래 앉아 있는 주홍 무녀. 앳된 얼굴로 웃으며 오싹한 말을 아무렇지 않게 한다. 의식을 집전할 때만 목소리가 낮고 단단해지는데, 그때의 그를 본 교도들은 그 뒤로 그를 「아씨」라고 부르지 못한다. 혈월 비고의 열쇠를 머리 장식에 꽂고 다니며, 요기에 물든 붉은 손톱을 굳이 감추지 않는다. 장터 아이들에게는 사탕을 나눠 주는 다정한 누나다.'),
  ('black_lotus:mumyeong', '나는 이름을 팔았다. 그 값으로 이 문을 샀지.', '흑련회의 회주. 진짜 이름을 아는 사람이 없고, 그 자신도 잊었다고 말한다. 열세 번째 문 너머 등도 의자도 없는 방에 목소리로만 존재하며, 회원 중 그의 얼굴을 본 이는 손에 꼽는다. 정청의 장부와 흑련회의 장부를 둘 다 외운다는 소문이 있고, 두 장부가 어긋나는 곳을 짚을 때만 목소리에 웃음기가 섞인다. 흑련의 뿌리가 어디에 있는지 묻는 이에게는 언제나 같은 대답을 한다. 「너희가 가장 잘 아는 곳.」'),
  ('black_lotus:guseul', '딱, 딱, 딱. 빚은 세 번 튕기면 정해져요.', '십삼문 암시장의 장부지기. 주판알 튕기는 소리가 말버릇이라 대화 중에도 손가락이 쉬지 않는다. 암시장에서 오간 빚을 하나도 빠짐없이 외우고, 십 년 전 한 푼 덜 갚은 사람의 이름까지 기억한다. 손님에게는 깍듯하지만 계약을 어긴 자에게는 같은 미소로 여섯째를 부른다. 첫 손님에게만 이자를 받지 않는다는 원칙을 한 번도 어긴 적이 없다.'),
  ('black_lotus:six', '…셋. 넷. 다섯. 여섯.', '흑련회의 채무 추적자. 사람을 이름이 아니라 숫자로 부르고, 자기 자신도 「여섯째」라고만 소개한다. 말이 적어 문장을 끝까지 말하는 일이 드물지만, 그가 무언가를 세기 시작하면 빚진 자들은 자리를 뜬다. 그림자 장부실에서 수련생들을 상대해 주는데, 이기면 장부에서 한 줄을 지워 주는 것이 그 나름의 칭찬이다. 왼쪽 손등에 여섯 개의 점이 새겨져 있고, 하나는 지워져 있다.'),
  ('north_league:seok', '눈을 감는 자는 뒤에 선 사람을 못 지킨다.', '북령맹의 맹주. 얼음 인장을 맨손으로 짚고 서 있어도 손이 얼지 않는 노무인이다. 말보다 주먹이 먼저 나가지만, 그 주먹은 언제나 상대의 코앞에서 멈춘다. 젊은 시절 적월교와의 싸움에서 산문 아홉 곳을 홀로 지켰다는 전설이 있으며, 그때 생긴 흉터를 「맹약의 값」이라 부른다. 제자들이 잠든 새벽에 종각 아래에서 혼자 인장의 금을 세어 보는 모습을 혜각만이 알고 있다.'),
  ('north_league:hyegak', '허허, 오늘은 누구를 눕혀 드릴까요. 아, 반대였던가요.', '철벽 고찰의 수좌승이자 연무장의 관리인. 늘 웃는 얼굴로 상대를 땅에 눕히는 재주가 있어 산문 제자들에게 「웃는 바위」라 불린다. 맹주의 오랜 벗으로, 맹주가 말하지 못한 것을 대신 말해 주는 역할을 자처한다. 차를 끓이는 솜씨가 좋아 연무장 한쪽에는 늘 김이 오르는 주전자가 있다. 얼음 인장의 금이 늘어날 때마다 염주 알을 하나씩 더한다.'),
  ('north_league:yeo', '짐을 지켰군. 사람이었으면 살았겠다. 그거면 됐다.', '북령맹 호송대를 이끄는 여장수. 길과 날씨를 누구보다 잘 알아, 그가 「내일은 눈」이라고 하면 산문의 장작이 미리 쌓인다. 피난민 행렬을 지킨 횟수가 백을 넘었고, 지키지 못한 행렬의 수도 정확히 기억한다. 칭찬이 서툴러 「살았겠다」, 「됐다」 정도가 최고의 찬사다. 산문 무기고의 열쇠를 갑옷 안쪽에 두며, 창날에는 지난 행렬의 수만큼 가는 홈이 파여 있다.'),
  ('river_alliance:jin', '강은 깊어요. 약속을 어기면 그만큼 깊이 가라앉죠.', '수향연맹의 도방. 연맹의 큰 배 위 비단 차양 아래에서 주판 하나로 강 전체의 물길을 다스린다. 웃는 얼굴로 값을 깎지만 한번 한 약속은 반드시 지키는 것으로 유명해, 정청과 적월교가 동시에 그의 배를 탄다. 어느 편에도 서지 않는 것이 연맹의 힘이라 믿으며, 그 믿음을 지키기 위해 잃은 것이 많다는 이야기를 가끔 술자리에서 흘린다. 주판에는 붉은 알이 하나 섞여 있는데, 그 알의 내력은 아무도 모른다.'),
  ('river_alliance:nodeul', '떠났다 돌아오는 배가 제일 반가운 법이지.', '구름나루에서 오십 년 노를 저은 뱃사공. 곰방대를 문 채 손님을 훑어보는 눈이 매서워, 그가 보증을 선 사람은 열에 아홉이 돈을 번다고 한다. 물길에 떠도는 소문을 모두 알고, 안개 낀 날 강의 소리만 듣고도 상류에 무슨 일이 났는지 맞힌다. 물길 시험장의 관리인으로, 버티는 놈만 건너간다는 것이 그의 유일한 가르침이다. 젊은 시절 용잠 수궁 근처까지 노를 저어 갔다 돌아온 단 한 사람이라는 소문이 있다.'),
  ('river_alliance:maehyang', '장사는 거짓말을 안 하는 게 제일 남는 장사예요.', '상단의 장부를 맡은 행수. 계산이 빠르고 말이 똑 부러져 상인들이 그 앞에서는 값을 부풀리지 못한다. 상단 별고의 관리인으로, 연맹이 신용을 걸고 내준 물건은 되팔지 못하게 하는 원칙을 칼같이 지킨다. 바쁜 와중에도 염등촌 사람들에게 보낼 기름은 직접 챙긴다. 장부 맨 뒷장에는 연맹 일을 하다 강에 잠긴 사람들의 이름이 따로 적혀 있다.'),
  ('southern_remnant:jang', '불이 있는 한 나라는 끝나지 않는다.', '남명회의 수장이자 망국의 마지막 장군. 한쪽 팔을 잃은 채 잔불촌 한가운데의 꺼지지 않는 화로 앞을 지킨다. 빼앗긴 땅을 되찾자는 그의 말에 사람들은 웃지만, 그를 따르는 유민들은 웃지 않는다. 남은 한 팔로 검을 쥐는 대신 불씨를 나누는 쪽을 택했고, 그 불씨를 받은 이들이 지금의 남명회다. 밤이면 잃어버린 팔이 시리다며 화로 가까이 붙어 앉는다.'),
  ('southern_remnant:soi', '그대가 지킨 화로에서 옛 노래가 들리더이다.', '망국의 기억을 노래로 전하는 무녀. 말끝마다 옛말이 섞여 처음 듣는 이는 고개를 갸웃한다. 재의 바다에서 건진 기와 조각과 유품을 모아 불씨 창고를 지키며, 물건 하나하나에 얽힌 사연을 모두 노래로 외운다. 망자들의 목소리를 들을 수 있다고 하는데, 본인은 「들리는 게 아니라 기억나는 것」이라고 고쳐 말한다. 그의 노래를 끝까지 들은 사람은 이상하게 고향 꿈을 꾼다.'),
  ('southern_remnant:galmae', '흥. 다시 왔으면 이번엔 끝까지 있어.', '잔불촌의 젊은 정찰대장. 날래고 거칠어 말보다 발이 먼저 나간다. 망국이 무너진 날 태어났다고 해서 마을 어른들은 그를 「마지막 아이」라 부르는데, 본인은 그 이름을 몹시 싫어한다. 밤마다 재 속에서 기어 나오는 것들과 싸우며 마을의 경계를 지키고, 봉화대 수련장에서는 불이 꺼지기 전까지 버티라는 말만 한다. 고맙다는 말을 할 때 늘 고개를 돌린다.'),
  ('mandate_court:hahu', '본 것을 다 말하지 않는 것, 그것이 첫 번째 계율이다.', '천명원의 수장인 태사령. 황실의 별을 읽어 온 노학자로, 혼천의 앞에서 눈을 감고 있는 시간이 눈을 뜨고 있는 시간보다 길다. 예언을 권력으로 쓴다는 비난에 「맞는 말이다」라고 답하는 사람이다. 평생 본 예언 가운데 입 밖에 낸 것은 셋뿐이며, 그 셋이 모두 맞았다는 이야기가 천명원의 무게가 되었다. 영대 감정이 될 사람에게만 말하지 않은 예언 하나를 물려준다.'),
  ('mandate_court:seo', '아… 졸려요. 그래도 별은 봐야죠.', '무극 관성대의 수석 관측관. 밤을 새우는 게 일상이라 늘 반쯤 감긴 눈으로 하품을 한다. 그러나 별자리 도판을 펼치면 눈빛이 바뀌어, 하늘의 작은 흔들림 하나도 놓치지 않는다. 하늘의 변화는 땅에 먼저 내려온다는 것이 그의 지론이라 관측생들을 자꾸 땅으로 내보낸다. 혼천의 시련실에서 시련자가 버티는 동안 꾸벅꾸벅 조는데, 시련이 끝나는 순간에는 정확히 깨어난다.'),
  ('mandate_court:mun', '기록은 정확하다. 결론은 쓰지 마라.', '황실 기록을 맡은 기밀 사관. 웃지 않는다는 것으로 유명해, 관측생들 사이에서는 그가 웃는 것을 보면 좋은 일이 생긴다는 미신까지 돈다. 영대 서고를 관리하며, 기록은 거래하지 않는다는 원칙에 따라 서고의 문서는 한 장도 밖으로 내보내지 않는다. 떠났다 돌아온 이에게 무엇을 보았는지 묻지 않는 것이 그 나름의 배려다. 붓 대신 쇠못으로 목판에 기록을 새기는 오래된 버릇이 있다.')
) v(k, quote, detail) where n.npc_key = v.k;

-- 1:1 직접 거래는 같은 곳에만 있으면 된다(안전지대 조건만 뺀다). 원정 중·전투불능·차단은 그대로 막는다
do $$ declare p record; d text; n int;
begin
  for p in select * from (values
    ('public.world_trade_direct_offer(uuid,jsonb,bigint,jsonb,bigint)', $a$if not coalesce(r.is_safe_zone, false) then raise exception '거래는 안전지대에서만 할 수 있습니다.'; end if;$a$),
    ('public.world_trade_direct_respond(uuid,boolean)', $a$if not coalesce(r.is_safe_zone, false) then raise exception '거래는 안전지대에서만 할 수 있습니다.'; end if;$a$)
  ) v(fn, old) loop
    d := pg_get_functiondef(p.fn::regprocedure);
    n := (length(d) - length(replace(d, p.old, ''))) / length(p.old);
    if n <> 1 then raise exception '직접 거래 고칠 자리(%): %곳', p.fn, n; end if;
    execute replace(d, p.old, '');
  end loop;
end $$;

-- 수향연맹 등급 세금 감면: 등급마다 20%(5등급 −80%). 상점 팔기·거래소 판매·직접 거래에
create or replace function public.world_trade_tax_mult(p_owner uuid)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select greatest(0, 1 - (p.rank - 1) * case c.major_faction_id when 'river_alliance' then 0.2 else 0 end)
    from public.world_characters c join public.world_faction_progress p on p.owner_id = c.owner_id and p.faction_id = c.major_faction_id
   where c.owner_id = p_owner and p.join_done_at is not null), 1)::numeric
$$;
alter function public.world_trade_tax_mult(uuid) owner to fn_owner_field;
revoke all on function public.world_trade_tax_mult(uuid) from public, anon, authenticated;
grant execute on function public.world_trade_tax_mult(uuid) to fn_owner_18878, fn_owner_18881;
do $$ declare p record; d text; n int;
begin
  for p in select * from (values
    ('public.world_shop_sell(text,integer)', $a$tax := greatest(1, round(price * p_qty * public.world_affil_tax())::bigint);$a$,
      $a$tax := case when public.world_trade_tax_mult(uid) <= 0 then 0 else greatest(1, round(price * p_qty * public.world_affil_tax() * public.world_trade_tax_mult(uid))::bigint) end;$a$),
    ('public.world_trade_offer_buy(uuid)', $a$tax:=greatest(1,round(total*0.05)::bigint);$a$,
      $a$tax:=case when public.world_trade_tax_mult(s.seller_id)<=0 then 0 else greatest(1,round(total*0.05*public.world_trade_tax_mult(s.seller_id))::bigint) end;$a$),
    ('public.world_trade_direct_respond(uuid,boolean)', $a$tax_a := case when t.want_gil > 0 then greatest(1, round(t.want_gil * 0.05)::bigint) else 0 end;$a$,
      $a$tax_a := case when t.want_gil > 0 and public.world_trade_tax_mult(a.owner_id) > 0 then greatest(1, round(t.want_gil * 0.05 * public.world_trade_tax_mult(a.owner_id))::bigint) else 0 end;$a$),
    ('public.world_trade_direct_respond(uuid,boolean)', $a$tax_b := case when t.give_gil > 0 then greatest(1, round(t.give_gil * 0.05)::bigint) else 0 end;$a$,
      $a$tax_b := case when t.give_gil > 0 and public.world_trade_tax_mult(b.owner_id) > 0 then greatest(1, round(t.give_gil * 0.05 * public.world_trade_tax_mult(b.owner_id))::bigint) else 0 end;$a$)
  ) v(fn, old, new) loop
    d := pg_get_functiondef(p.fn::regprocedure);
    n := (length(d) - length(replace(d, p.old, ''))) / length(p.old);
    if n <> 1 then raise exception '세금 고칠 자리(%): %곳', p.fn, n; end if;
    execute replace(d, p.old, p.new);
  end loop;
end $$;
-- 흑련회 등급 효과 「그림자 장부」: 장부 밖으로 물건을 넘길 연줄 — 상점 하루 판매 한도 +300전씩(5등급 +1,200전)
create or replace function public.world_affil_cap()
returns integer language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select (case when c.faction_key = 'headquarters' then 500 else 0 end
        + coalesce((select (p.rank - 1) * 300 from public.world_faction_progress p
                     where p.owner_id = c.owner_id and p.faction_id = 'black_lotus' and c.major_faction_id = 'black_lotus' and p.join_done_at is not null), 0))::int
    from public.world_characters c where c.owner_id = public.fn_owner_auth_uid()
$$;
grant fn_owner_18669 to postgres with inherit false, set false;
grant fn_owner_18881 to postgres with inherit false, set false;

-- 물품 정보 「얻는 곳」: 상점·대장간·세력 비고를 나눠 알린다(정련 숯이 「상점에서 삽니다」로만 보이던 문의)
do $$ declare d text := pg_get_functiondef('public.world_item_sources(text)'::regprocedure);
  a text := $a$'shop', exists (select 1 from public.world_shop_catalog where item_id = p_item))$a$;
  b text := $a$'shop', exists (select 1 from public.world_shop_catalog where item_id = p_item and shop_id <> 'smithy'),
    'smithy', exists (select 1 from public.world_shop_catalog where item_id = p_item and shop_id = 'smithy'),
    'vault', exists (select 1 from public.world_faction_vault where item_id = p_item))$a$;
begin
  if position('''smithy''' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '얻는 곳 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

grant fn_owner_18885 to postgres with inherit false, set false;
grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_18987 to postgres with inherit false, set false;
grant fn_owner_18452 to postgres with inherit false, set false;
grant fn_owner_18453 to postgres with inherit false, set false;
grant fn_owner_18956 to postgres with inherit false, set false;
grant fn_owner_18878 to postgres with inherit false, set false;

-- 세력 가입 퀘스트 도입: 지금 대세력에 든 조사원은 세력에서 나와 처음부터 가입 퀘스트를 밟는다(2026-10-29 결정).
-- 「떠남」 기록(payload.left)을 남기지 않아 12시간 재가입 제한에 걸리지 않고 바로 다시 들 수 있다. 쌓은 영향력은 세력에 남는다.
do $$ declare r record; begin
  for r in select owner_id, major_faction_id from public.world_characters where major_faction_id is not null loop
    update public.world_characters set major_faction_id = null, faction_reputation = 0, updated_at = now() where owner_id = r.owner_id;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.owner_id, 'faction', '세력 가입 퀘스트가 열렸습니다',
      '5.0.0에서 세력 가입 퀘스트와 등급이 생겨, 세력에 든 모든 조사원이 세력에서 나와 처음부터 시작합니다. 캐릭터 › 세력에서 바로 다시 가입할 수 있고(12시간 제한 없음), 가입하면 세력 인물들과의 가입 퀘스트가 시작됩니다.',
      jsonb_build_object('faction_id', r.major_faction_id, 'reset', true));
  end loop;
end $$;

-- 장착 안 되던 옛 장비 정리(2026-10-29 제보): 청동 호신패·행상인 짐틀은 분류가 'equipment'라 장착 칸이 없고
-- 특성·조건도 비어 화면에는 「장착 조건 누구나」로 보였지만 world_equip_item이 거절했다. 호신부·노리개로 옮기고,
-- 청동 호신패 제작법 둘은 서로 다른 호신부를 만든다(요핵 → 청동 호신패, 주사·비취 → 비취 청동패).
-- 값은 재료 시세 합 × 1.2 안팎, 같은 칸 3단계(≤ 4단계 최저 ÷ 1.15)·4단계(≥ 3단계 최고 × 1.15) 순서를 지킨다.
update public.world_item_catalog set category = 'amulet', rarity = 'rare', tier = 3, minimum_level = 10,
  required_stats = '{"vitality": 12}'::jsonb, reference_price = 460, drop_rate_modifier = 0.42, acquisition_difficulty = 3,
  equipment_traits = '{"trait": "호신부", "defense": 4, "presence": 6, "incoming_damage_pct": -4}'::jsonb,
  description = '요핵을 녹여 부은 청동 패. 몸을 단단히 하고 받는 피해를 줄인다.'
where item_id = 'bronze_charm';
insert into public.world_item_catalog(item_id, item_name, category, rarity, tier, stackable, tradeable, stack_size, description,
  required_job, minimum_level, required_stats, reference_price, equipment_traits, required_faction, drop_rate_modifier, acquisition_difficulty)
values ('jade_bronze_charm', '비취 청동패', 'amulet', 'rare', 3, false, true, 1,
  '주사로 술식을 그리고 비취를 박은 청동 패. 술법을 돋우고 침식과 정신 손실을 막는다.',
  null, 10, '{"spirit_affinity": 12}'::jsonb, 530,
  '{"trait": "호신부", "magic_pct": 5, "erosion_pct": -5, "mental_loss_pct": -4}'::jsonb, null, 0.42, 3)
on conflict (item_id) do nothing;
update public.world_crafting_recipes set recipe_name = '청동 호신패 만들기', minimum_level = 10,
  description = '요핵과 월철 주괴로 청동 호신패(방어·받는 피해 감소)를 만든다.'
where recipe_id = 'recipe_monster_ward';
update public.world_crafting_recipes set output_item = 'jade_bronze_charm', recipe_name = '비취 청동패 만들기', minimum_level = 10,
  description = '주사와 비취를 결합해 비취 청동패(술법·침식·정신 손실)를 만든다.'
where recipe_id = 'make_bronze_charm_advanced';
update public.world_item_catalog set category = 'norigae', rarity = 'epic', tier = 4, minimum_level = 15,
  required_stats = '{"vitality": 16}'::jsonb, reference_price = 1300, drop_rate_modifier = 0.2, acquisition_difficulty = 4,
  equipment_traits = '{"trait": "노리개", "travel_time_pct": -6, "supply_save_pct": 10}'::jsonb,
  description = '운반 준비를 갖춘 작은 등짐틀을 허리에 매단다. 길을 줄이고 보급품을 아낀다.'
where item_id = 'wayfarer_pack';
update public.world_crafting_recipes set minimum_level = 15 where recipe_id = 'make_wayfarer_pack';

-- 패치노트 5.0.0
insert into public.world_patch_notes(note_id, title, body, created_at) values
  ('5.0.0', '세력 퀘스트·등급 · 고유 기술 · 원거리 소모품 · 기력', $PN$## 5.0.0 · 세력 퀘스트·등급 · 고유 기술 · 원거리 소모품 · 기력 (통산 5번째 패치)

### 세력
1. 세력에 처음 들면 **가입 퀘스트**(3장면)가 열립니다. 세력 인물들과 대화창으로 이야기하고, 맡은 일을 마친 뒤 정해진 곳에서 「보고하기」를 누르면 다음 장면이 이어집니다. 마치면 회복약 묶음과 공훈을 받습니다. 떠났다 다시 들면 짧은 재가입 대사만 나옵니다. **지금 세력에 든 분들은 모두 세력에서 나와 처음부터 시작합니다**(12시간 제한 없이 바로 다시 가입할 수 있습니다).
2. **세력 등급 5단계**(세력마다 이름이 다름). 평판 300·800·1,600·3,000과 레벨 조건을 채우면 등급 퀘스트가 열리고, 마치면 오릅니다. 등급마다 세력 효과가 커집니다(정통파 단서 · 적월교 주는 피해 · 흑련회 희귀품 · 북령맹 받는 피해 감소 · 수향연맹 이동 · 남명회 채집량 · 천명원 날씨 불이익 감소와 예언(요괴 조우 감소)). 평판 상한은 5,000으로 올렸습니다.
3. 조사원 카드의 세력 표식에 「세력 · 등급」이 보입니다(캐릭터 › 세력에서 숨길 수 있음).
4. **의뢰판**: 매일 세 가지 세력 의뢰. 그날 한 일로 평판과 공훈을 받습니다.
5. **비고(秘庫)**: 세력 안전지대에서 공훈으로 회복약·부적·강화 재료를 삽니다(사들이지는 않음). 등급이 오를수록 품목이 늘어납니다.
6. **수련장**: 세력 안전지대에서 하루 한 번 등급 시련. 내 전투 능력치로 시련 상대와 합을 주고받고, 한 줄씩 펼쳐지는 전투를 지켜봅니다(건너뛰기 가능). 3·5등급 시련을 처음 넘으면 세력 칭호(14개), 5등급은 세력 낙관(錄·血·蓮·盟·舟·燼·星)도 받습니다.
7. **세력 인물**: 퀘스트에서 만난 인물의 기록(소개 대사·인물 서술)을 캐릭터 › 세력에서 펼쳐 봅니다.
8. 경제 세력: **수향연맹**(거상)은 뱃길 이동 단축과 함께 등급마다 세금이 20%씩 줄어듭니다(5등급 −80%, 상점 판매세·거래소·직접 거래). **흑련회**(암시장)는 희귀품과 함께 「그림자 장부」로 등급마다 상점 하루 판매 한도가 300전씩 늘어납니다(5등급 +1,200전).

### 기술
9. 4.0.0의 이름 있는 기술 105개(추가·택일·숙달·조합)가 수치 보정 대신 **행동이 바뀌는 고유 효과**를 냅니다(토벌·채집·제작·탐색·이동·휴식·강화·수리·구조). 캐릭터 › 기술의 설명을 확인하세요.
10. **근접** 13·24·30·43단계를 모두 택일로: A 딜러(발도·일격·유수검·파천) / B 탱커(호령·도발·철갑 강기·사자후, 이목을 끈다).
11. **봉인술** 13·24·30·43단계를 모두 택일로: A 폭딜(연쇄부·폭렬부·연환부·천뢰부) / B 버프·디버프(부적 접기·호체부·겹술식·청정결계). 바꾸기 13단계 1,000 · 24단계 2,000 · 30단계 3,000 · 43단계 5,000전(처음 고르기는 무료). 13·30단계 기술을 갖고 있던 분은 한 번 골라야 다시 생깁니다.

### 무기와 장비
12. **원거리 소모품**: 화살·쇠뇌살·취관 침(묶음 100). 한 발에 하나를 쓰고, 없으면 피해가 절반입니다. 원정은 회차마다 둘. 지금 원거리 무기를 든 분께 100개를 드렸습니다(가방이 차면 창고로). 상점과 목공 제작법에서 구합니다.
13. **기력**: 근접 무기를 들면 영력 게이지가 노란 「기력」이 되고, 근접 공격마다 2를 씁니다(모자라면 피해 절반). 영력 회복약은 기력도 채웁니다.
14. 같은 장비가 여럿일 때 상점 팔기·버리기·분해는 닳은 쪽이 먼저 나갑니다. 모두 팔거나 분해한 뒤 새로 만든 장비는 새 내구도로 시작합니다(전에는 옛 장비의 닳은 내구도가 남았습니다).

### 원정·파티
15. **파티 원정**: 파티장이 제안하고 동료가 수락하면 한꺼번에 출발합니다(출발·귀환 시각이 같음).
16. 원정 전투에서 체력이 넉넉하면(70 이상) 밀린 싸움도 버텨 이깁니다(대신 피해 두 배, 일지에 [버팀]).
17. 원정 일지에서 전투 중에 다른 줄(보급품 먹기 등)이 끼어도 전투 칸이 끊기지 않습니다.
18. 지역마다 요괴 2종이 더 나옵니다(66종).

### 거래·편의
19. **1:1 직접 거래**는 상대와 같은 곳에만 있으면 안전지대 밖에서도 할 수 있습니다.
20. 거래소 등록·직접 거래의 물품 고르기에 분류·이름 검색·가나다순을 넣었습니다.
21. 현장의 **답사 지도**: 길·채집터 수를 말로 적고, 다 찾은 곳 표시, 찾지 못한 곳은 빈칸으로, 위에 답사도 단계 막대.
22. 물품 정보의 「얻는 곳」에 대장간·상점·세력 비고를 나눠 적습니다.
23. 쓰러졌다 다시 일어나면 전체 채팅에 그 소식도 남습니다. 이동 중에는 탈것을 바꿀 수 없습니다. 노정 건량은 누구나 만듭니다.
24. 화면: 환골탈태 서첩 창(모바일)·동료 화면 카드·조사원 카드 비무 단추·채팅 구조 알림 줄 정리.
25. **비무**도 겨루는 모습이 한 줄씩 펼쳐집니다(건너뛰기 가능).
26. 거래소·직접 거래 목록에 없는 물품은 거래할 수 없는 물품(응축 영핵·천공 깃털 같은 희귀 성장 재료 등)입니다. 이제 목록 아래에 어떤 물품이 빠졌는지 적어 둡니다.
27. **청동 호신패**·**행상인 짐틀**이 「장착 조건 누구나」로 보이는데 장착되지 않던 문제를 고쳤습니다. 청동 호신패는 호신부(3단계, Lv10·체질 12: 방어 +4·받는 피해 −4%), 행상인 짐틀은 노리개(4단계, Lv15·체질 16: 이동 시간 −6%·보급품 절약 10%)가 됩니다. 청동 호신패 제작법 둘은 이제 서로 다른 호신부를 만듭니다: 요핵 → 청동 호신패, 주사·비취 → **비취 청동패**(술법 +5%·침식 −5%·정신 손실 −4%).
$PN$, now())
on conflict (note_id) do update set title = excluded.title, body = excluded.body;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029060000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
