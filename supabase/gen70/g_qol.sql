
-- ─────────────────────────────────────────────────────────────
-- G. 편의·밸런스
-- ─────────────────────────────────────────────────────────────

-- ① 귀령초: 확률을 크게 낮추고(일반 0.02%·정예 0.08%·우두머리 0.3%·구중 봉연 우두머리·합동 토벌/결전·귀허의 주인 1%·채집 0.02%·원정 완주 0.15%, 위험도 10 ×1.5),
--    한 번 얻으면 72시간 다시 안 나오며, 서버 전체 7일 몫 = 지난 7일 요화가 걸린 수의 절반(최소 1)
create table if not exists public.world_gwiryeong_log (id bigserial primary key, owner_id uuid not null, got_at timestamptz not null default now(), source text);
create index if not exists world_gwiryeong_log_at on public.world_gwiryeong_log(got_at);
alter table public.world_gwiryeong_log enable row level security;
revoke all on public.world_gwiryeong_log from anon, authenticated;
grant select, insert on public.world_gwiryeong_log to fn_owner_field;
grant usage on sequence public.world_gwiryeong_log_id_seq to fn_owner_field;

create or replace function public.world_gwiryeong_chance(p_type text, p_payload jsonb) returns numeric
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  with reg as (
    select r.danger_level from public.world_map_regions r
     where r.region_id = coalesce(p_payload ->> 'region_id',
       (select n.region_id from public.world_exploration_nodes n
         where n.node_id = case when p_payload ->> 'node_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (p_payload ->> 'node_id')::uuid end))
  )
  select case when p_type in ('gw_win', 'raid_win') then 0.01 else coalesce((select least(0.01, case when reg.danger_level < 7 then 0 else
      case p_type
        when 'gather' then 0.0002
        when 'expedition_end' then case when p_payload ->> 'ended' = 'complete' then 0.0015 else 0 end
        when 'combat' then case when not coalesce((p_payload ->> 'defeated')::boolean, false) then 0
          when p_payload ->> 'region_id' = 'sealed_abyss' and p_payload ->> 'rank' = 'guardian' then 0.01
          else case p_payload ->> 'rank' when 'guardian' then 0.003 when 'elite' then 0.0008 else 0.0002 end end
        else 0 end * case when reg.danger_level >= 10 then 1.5 else 1 end end) from reg), 0) end
$$;

-- 72시간·서버 7일 몫을 확인하고 한 몫을 적어 둔다(얻는 모든 길이 이것을 거친다: 기록 트리거·토벌 트리거·기술 「영초 감별」)
create or replace function public.world_gwiryeong_reserve(p_uid uuid, p_source text) returns boolean
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare cap int;
begin
  if p_uid is null then return false; end if;
  if exists (select 1 from public.world_gwiryeong_log l where l.owner_id = p_uid and l.got_at > now() - interval '72 hours') then return false; end if;
  perform pg_advisory_xact_lock(hashtext('yh-gwiryeong-week'));
  cap := greatest(1, (select count(*) from public.world_yohwa_log y where y.kind = 'onset' and y.at > now() - interval '7 days')::int / 2);
  if (select count(*) from public.world_gwiryeong_log l where l.got_at > now() - interval '7 days') >= cap then return false; end if;
  insert into public.world_gwiryeong_log(owner_id, source) values (p_uid, p_source);
  return true;
end $$;
create or replace function public.world_gwiryeong_give(p_uid uuid, p_chance numeric, p_source text) returns boolean
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if p_uid is null or coalesce(p_chance, 0) <= 0 or random() >= p_chance then return false; end if;
  if not exists (select 1 from public.world_characters where owner_id = p_uid) then return false; end if;
  if not public.world_gwiryeong_reserve(p_uid, p_source) then return false; end if;
  update public.world_characters set inventory = public.world_inv_add(coalesce(inventory, '{}'::jsonb), 'gwiryeong_cho', 1), updated_at = now() where owner_id = p_uid;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_uid, 'reward', '귀령초를 찾았습니다',
    '음습한 기운 사이에서 귀령초 한 포기를 찾았습니다. 요화를 다스리는 귀한 풀입니다(가방이 가득 찼다면 넘친 만큼은 버려집니다).',
    jsonb_build_object('item_id', 'gwiryeong_cho', 'qty', 1, 'source', p_source));
  return true;
end $$;
create or replace function public.world_gwiryeong_roll() returns trigger
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if new.actor_id is null then return new; end if;
  perform public.world_gwiryeong_give(new.actor_id, public.world_gwiryeong_chance(new.event_type, coalesce(new.payload, '{}'::jsonb)), new.event_type);
  return new;
end $$;
drop trigger if exists trg_world_gwiryeong_roll on public.world_events;
create trigger trg_world_gwiryeong_roll after insert on public.world_events for each row
  when (new.event_type = any (array['gather', 'combat', 'expedition_end', 'gw_win'])) execute function public.world_gwiryeong_roll();
-- 합동 토벌·10장 결전 승리: 싸운 사람마다 1%
create or replace function public.world_gwiryeong_raid_trg() returns trigger
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare m record;
begin
  for m in select owner_id from public.world_raid_members where raid_id = new.raid_id and acts > 0 loop
    perform public.world_gwiryeong_give(m.owner_id, public.world_gwiryeong_chance('raid_win', '{}'::jsonb), 'raid_' || new.kind);
  end loop;
  return new;
end $$;
drop trigger if exists trg_world_gwiryeong_raid on public.world_raids;
create trigger trg_world_gwiryeong_raid after update of status on public.world_raids for each row
  when (new.status = 'won' and old.status is distinct from 'won') execute function public.world_gwiryeong_raid_trg();
do $$ declare f text; begin
  foreach f in array array['world_gwiryeong_chance(text,jsonb)', 'world_gwiryeong_reserve(uuid,text)', 'world_gwiryeong_give(uuid,numeric,text)', 'world_gwiryeong_roll()', 'world_gwiryeong_raid_trg()'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn_owner%' loop execute format('grant execute on function public.world_gwiryeong_reserve(uuid,text) to %I', r); end loop;
end $$;
-- 기술 「영초 감별」도 같은 몫을 거친다(0.6% → 0.2%), 봉연의 그림자 정산의 따로 굴리던 1%는 빼고 위 토벌 트리거 하나로
select pg_temp.yh_patch('public.world_field_gather(uuid)', 'AND random() < 0.006 THEN extra := public.world_inv_add(extra, ''gwiryeong_cho'', 1);',
  'AND random() < 0.002 AND public.world_gwiryeong_reserve(uid, ''skill_herbalism'') THEN extra := public.world_inv_add(extra, ''gwiryeong_cho'', 1);');
select pg_temp.yh_patch('public.world_raid_settle(uuid,boolean)', '          if random() < 0.01 then items := items || jsonb_build_object(''gwiryeong_cho'', 1); end if;
', '');
update public.world_skill_catalog set description = '택일 기술 · 위험도 7 이상 지역에서 약초를 거둘 때 0.2% 확률로 귀령초(한 번 얻으면 72시간 다시 나오지 않음)' where skill_id = 'herbalism_c43b';
-- 조사 지점의 희귀 보너스에 섞여 있던 귀령초를 뺀다(위 판정 밖에서 나오던 길)
update public.world_region_sites set rare_bonus = jsonb_set(rare_bonus, '{items}', (select coalesce(jsonb_agg(x), '[]'::jsonb) from jsonb_array_elements(rare_bonus -> 'items') x where x #>> '{}' <> 'gwiryeong_cho'))
 where rare_bonus -> 'items' @> '["gwiryeong_cho"]'::jsonb;
-- 화면이 쓰지 않는 옛 조사 지점 함수(world_region_explore)는 실행 권한을 거둔다(함수는 남김)
do $$ declare o text; begin
  o := pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_region_explore(text,text)'::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute format('set role %I', o);
  revoke execute on function public.world_region_explore(text,text) from public, anon, authenticated;
  reset role;
end $$;
update public.world_item_catalog set description = '위험도 7 이상 지역에서 아주 드물게 찾는 음습한 풀. 요화를 풀고 침식을 20 낮춘다.' where item_id = 'gwiryeong_cho';

-- ② 수향연맹 뱃길: 동승해서 갈 때도 배 속도(등급 보정)를 쓴다
select pg_temp.yh_patch('public.world_travel_party_respond_v2(uuid,boolean)', '   /coalesce(speed,1))::int));', '   /(coalesce(speed,1)*public.world_river_boat_speed(q.leader_id, c.mount_id)))::int));');
select pg_temp.yh_patch('public.world_travel_party_respond_v2(uuid,boolean)', ' select case when coalesce(m.fare_free,false) then 0',
  ' select case when coalesce(m.fare_free,false) or public.world_river_boat_member(q.leader_id, m.mount_id) then 0');

-- ③ 외래어: 퀘스트 제목 · 서버 안내문의 「아이템」
update public.world_quests set title = '얼음 밑의 두드림' where title = '얼음 밑의 노크';
do $$ declare f record; n int; begin
  for f in select p.oid::regprocedure::text sig, (length(pg_get_functiondef(p.oid)) - length(replace(pg_get_functiondef(p.oid), '아이템', ''))) / length('아이템') k
             from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and pg_get_functiondef(p.oid) like '%아이템%' loop
    perform pg_temp.yh_patch(f.sig, '아이템', '물품', f.k);
  end loop;
end $$;

-- ④ 모임 순서: 내 화면의 모임 순서를 서버에 저장한다(채팅의 모임 단추 줄·동료 화면 모임 목록)
alter table public.world_circle_members add column if not exists sort int;
select pg_temp.yh_patch('public.world_circle_snapshot()', ') order by m.joined_at)', ') order by m.sort nulls last, m.joined_at)');
create or replace function public.world_circle_reorder(p_ids uuid[]) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if coalesce(cardinality(p_ids), 0) > 10 then raise exception '모임이 너무 많습니다.'; end if;
  update public.world_circle_members m set sort = x.o from unnest(p_ids) with ordinality x(id, o) where m.owner_id = uid and m.circle_id = x.id;
  return jsonb_build_object('ok', true);
end $$;
alter function public.world_circle_reorder(uuid[]) owner to fn_owner_field;
revoke all on function public.world_circle_reorder(uuid[]) from public, anon, authenticated;
grant execute on function public.world_circle_reorder(uuid[]) to authenticated;
grant update (sort) on public.world_circle_members to fn_owner_field;

-- ⑤ 알림 종류별 켜고 끄기: 꺼 둔 갈래의 알림은 들어올 때 읽음으로 두어 화면에 띄우지 않는다(지난 알림에는 남음)
create table if not exists public.world_notify_prefs (owner_id uuid primary key, off text[] not null default '{}', updated_at timestamptz not null default now());
alter table public.world_notify_prefs enable row level security;
revoke all on public.world_notify_prefs from anon, authenticated;
grant select, insert, update on public.world_notify_prefs to fn_owner_field;
create or replace function public.world_notify_group(p_kind text) returns text
language sql immutable set search_path to 'pg_catalog' as $$
  select case
    when p_kind in ('title', 'cosmetic') then 'title'
    when p_kind in ('reward', 'skill_rerank') then 'reward'
    when p_kind in ('bag_full', 'bag_overflow') then 'bag'
    when p_kind in ('rescue_request') then 'rescue'
    when p_kind in ('friend_down') then 'friend_rescue'
    when p_kind in ('trade_offer', 'trade_result') then 'trade'
    when p_kind in ('friend_request', 'friend_accepted') then 'friend'
    when p_kind in ('party_invite', 'party_expedition', 'party_exp_offer', 'party_leave', 'party_aid') then 'party'
    when p_kind in ('circle_invite') then 'circle'
    when p_kind in ('spar_request', 'spar_result') then 'spar'
    when p_kind like 'bond%' then 'bond'
    when p_kind in ('faction') then 'faction'
    when p_kind in ('raid_invite', 'raid', 'gw', 'gw_invite') then 'raid'
    else null end   -- 운영 공지·제보 답장·요화·원정 같은 것은 끌 수 없다
$$;
create or replace function public.world_notify_prefs_trg() returns trigger
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare g text := public.world_notify_group(new.kind);
begin
  if g is not null and new.read_at is null and exists (select 1 from public.world_notify_prefs p where p.owner_id = new.user_id and g = any (p.off)) then
    new.read_at := now();
  end if;
  return new;
end $$;
drop trigger if exists trg_world_notify_prefs on public.world_notifications;
create trigger trg_world_notify_prefs before insert on public.world_notifications for each row execute function public.world_notify_prefs_trg();
create or replace function public.world_notify_prefs_get() returns jsonb
language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select jsonb_build_object('off', coalesce((select to_jsonb(off) from public.world_notify_prefs where owner_id = public.fn_owner_auth_uid()), '[]'::jsonb))
$$;
create or replace function public.world_notify_prefs_set(p_off text[]) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); v text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select coalesce(array_agg(distinct x), '{}') into v from unnest(coalesce(p_off, '{}')) x
   where x in ('title', 'reward', 'bag', 'rescue', 'friend_rescue', 'trade', 'friend', 'party', 'circle', 'spar', 'bond', 'faction', 'raid');
  insert into public.world_notify_prefs(owner_id, off, updated_at) values (uid, v, now())
  on conflict (owner_id) do update set off = excluded.off, updated_at = now();
  return jsonb_build_object('ok', true, 'off', to_jsonb(v));
end $$;
do $$ declare f text; begin
  foreach f in array array['world_notify_group(text)', 'world_notify_prefs_trg()', 'world_notify_prefs_get()', 'world_notify_prefs_set(text[])'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
grant execute on function public.world_notify_prefs_get(), public.world_notify_prefs_set(text[]) to authenticated;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn_owner%' loop execute format('grant execute on function public.world_notify_group(text) to %I', r); end loop;
end $$;

-- ⑥ 친구가 쓰러지면 다른 곳에 있는 친구에게도 알림(friend_down, 알림 설정 「친구 구조」로 끔). 같은 곳의 조사원은 지금처럼 긴급 구조 요청을 받는다
grant select on public.world_friends to fn_owner_18987;
select pg_temp.yh_patch('public.world_notify_downed()', '  insert into public.world_chat_messages(channel_type,sender_id,sender_name,content) values(''global'',new.owner_id,''구조 알림'',
    new.character_name||'' 조사원이 ''||coalesce(new.location,''어딘가'')||''에서 쓰러졌습니다.',
  '  for rec in select distinct c.owner_id from public.world_friends f
                 join public.world_characters c on c.owner_id = case when f.owner_id = new.owner_id then f.friend_id else f.owner_id end
                where f.status = ''accepted'' and new.owner_id in (f.owner_id, f.friend_id)
                  and not (c.location = new.location and c.health > 0 and c.downed_at is null) loop
   insert into public.world_notifications(user_id,kind,title,content,payload) values(rec.owner_id,''friend_down'',''친구 구조 요청'',new.character_name||'' 조사원이 ''||coalesce(new.location,''어딘가'')||''에서 쓰러졌습니다. 가서 구조할 수 있습니다.'',jsonb_build_object(''target_id'',new.owner_id,''target_name'',new.character_name,''location'',new.location,''created_at'',now()));
  end loop;
  insert into public.world_chat_messages(channel_type,sender_id,sender_name,content) values(''global'',new.owner_id,''구조 알림'',
    new.character_name||'' 조사원이 ''||coalesce(new.location,''어딘가'')||''에서 쓰러졌습니다.');
