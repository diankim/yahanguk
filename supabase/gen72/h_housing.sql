-- ─────────────────────────────────────────────────────────────
-- 7.2 ① 별채(別棟): 방 하나(6×6~9×9)·가구·곳간·방명록·발걸음·대문
--   가구는 물품(category furniture, equipment_traits: hk 그림 키·kind floor|rug|surface|wall|paper|ground·w·d·top·ww·wh·cat·pet).
--   놓으면 가방(또는 곳간)에서 빠지고, 거두면 곳간으로 간다. 수정은 안전지대에서만, 구경은 어디서나.
--   방을 열 때 한 번 읽고 저장할 때 한 번 쓴다(실시간 없음).
-- ─────────────────────────────────────────────────────────────
alter table public.world_item_catalog drop constraint if exists world_item_catalog_category_check;
alter table public.world_item_catalog add constraint world_item_catalog_category_check check (category = any (array['material', 'consumable', 'equipment', 'tool', 'weapon', 'armor', 'quest',
  'hat', 'shoes', 'norigae', 'amulet', 'mask', 'furniture', 'pet']));

create table if not exists public.world_housing (
  owner_id uuid primary key,
  size int not null default 6 check (size between 6 and 9),
  items jsonb not null default '[]'::jsonb,
  wall jsonb not null default '[]'::jsonb,
  paper text, ground text,
  gate text not null default 'open' check (gate in ('open', 'friends', 'closed')),
  visits_total int not null default 0, visits_today int not null default 0, visits_day date,
  pet_id text, pet_out boolean not null default false,
  opened_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.world_housing_store (
  owner_id uuid primary key,
  items jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.world_housing_guestbook (
  id bigserial primary key,
  owner_id uuid not null, writer_id uuid not null, writer_name text not null,
  body text not null check (char_length(body) between 1 and 80),
  created_at timestamptz not null default now()
);
create index if not exists world_housing_guestbook_owner on public.world_housing_guestbook(owner_id, created_at desc);
create index if not exists world_housing_guestbook_writer on public.world_housing_guestbook(writer_id, owner_id, created_at desc);
create table if not exists public.world_housing_visits (
  owner_id uuid not null, visitor_id uuid not null, day date not null,
  primary key (owner_id, visitor_id, day)
);
-- 한 번만 주는 가구(칭호·이야기·결전·외전·비무회): 같은 출처는 한 번
create table if not exists public.world_housing_rewards (
  owner_id uuid not null, source text not null, item_id text not null, got_at timestamptz not null default now(),
  primary key (owner_id, source)
);
-- 가구가 나오는 곳: source = drop_normal·drop_guardian·expedition·raid_world(확률) / title:<칭호>·chapter:<장>·raid_final·gw_first(한 번)
create table if not exists public.world_furniture_sources (
  source text not null, item_id text not null, chance numeric not null default 1,
  primary key (source, item_id)
);
alter table public.world_housing enable row level security;
alter table public.world_housing_store enable row level security;
alter table public.world_housing_guestbook enable row level security;
alter table public.world_housing_visits enable row level security;
alter table public.world_housing_rewards enable row level security;
alter table public.world_furniture_sources enable row level security;
revoke all on public.world_housing, public.world_housing_store, public.world_housing_guestbook, public.world_housing_visits, public.world_housing_rewards, public.world_furniture_sources from anon, authenticated;
revoke all on sequence public.world_housing_guestbook_id_seq from anon, authenticated;
grant select, insert, update, delete on public.world_housing, public.world_housing_store, public.world_housing_guestbook, public.world_housing_visits, public.world_housing_rewards to fn_owner_field;
grant select on public.world_furniture_sources to fn_owner_field;
grant usage on sequence public.world_housing_guestbook_id_seq to fn_owner_field;

-- 방 크기마다 설치 상한(바닥+벽)·곳간 상한
create or replace function public.world_housing_cap(p_size int) returns int
language sql immutable set search_path = '' as $$ select case p_size when 6 then 15 when 7 then 20 when 8 then 26 else 32 end $$;
create or replace function public.world_housing_store_cap(p_size int) returns int
language sql immutable set search_path = '' as $$ select 30 + 5 * greatest(0, coalesce(p_size, 6) - 6) $$;
-- 같은 가구 설치 상한: 범품 4·양품 3·진품 2·명품·신품 1
create or replace function public.world_housing_kind_cap(p_tier int) returns int
language sql immutable set search_path = '' as $$ select case coalesce(p_tier, 1) when 1 then 4 when 2 then 3 when 3 then 2 else 1 end $$;
-- 그림 키 → 물품 id
create or replace function public.world_housing_item(p_kind text, p_key text) returns text
language sql immutable set search_path = '' as $$ select case p_kind when 'paper' then 'hp_' when 'ground' then 'hg_' else 'hf_' end || p_key $$;
create or replace function public.world_housing_today() returns date
language sql stable set search_path = '' as $$ select (now() at time zone 'Asia/Seoul')::date $$;

-- 혼례를 올린 정인(「한 지붕」: 서로의 별채를 고칠 수 있다)
create or replace function public.world_housing_married(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_a is not null and p_b is not null and p_a <> p_b and exists (select 1 from public.world_bonds b
    where b.ended_at is null and coalesce((b.marks ->> 'married')::boolean, false) and ((b.a_id = p_a and b.b_id = p_b) or (b.a_id = p_b and b.b_id = p_a)))
$$;
create or replace function public.world_housing_blocked(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.world_blocks k where (k.owner_id = p_a and k.blocked_id = p_b) or (k.owner_id = p_b and k.blocked_id = p_a))
$$;
create or replace function public.world_housing_friends(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.world_friends f where f.status = 'accepted' and ((f.owner_id = p_a and f.friend_id = p_b) or (f.owner_id = p_b and f.friend_id = p_a)))
$$;
-- 구경할 수 있는가(주인·정인은 늘, 차단은 늘 못 함, 대문에 따라)
create or replace function public.world_housing_can_view(p_viewer uuid, p_owner uuid, p_gate text) returns text
language sql stable security definer set search_path = '' as $$
  select case when p_viewer = p_owner or public.world_housing_married(p_viewer, p_owner) then null
              when public.world_housing_blocked(p_viewer, p_owner) then '들어갈 수 없는 별채입니다.'
              when p_gate = 'closed' then '대문이 닫혀 있습니다.'
              when p_gate = 'friends' and not public.world_housing_friends(p_viewer, p_owner) then '벗에게만 열린 별채입니다.'
              else null end
$$;
-- 고칠 수 있는 곳인가(창고와 같은 조건, 반요촌은 안 됨). 막는 까닭을 돌려준다(null이면 됨).
create or replace function public.world_housing_edit_block(p_uid uuid) returns text
language plpgsql stable security definer set search_path = '' as $$
declare c public.world_characters%rowtype;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if not found then return '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null then return '전투불능 상태에서는 별채를 고칠 수 없습니다.'; end if;
  if c.travel_arrives_at is not null then return '이동 중에는 별채를 고칠 수 없습니다.'; end if;
  if not exists (select 1 from public.world_current_shop(p_uid)) then return '별채는 안전지대에서만 고칠 수 있습니다. 바깥에서는 구경만 됩니다.'; end if;
  if public.world_banyo_here(p_uid) then return '반요촌에서는 별채를 고칠 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then return '원정 중에는 별채를 고칠 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities a where a.owner_id = p_uid and a.status = 'active') then return '자율 활동 중에는 별채를 고칠 수 없습니다.'; end if;
  if exists (select 1 from public.world_character_statuses s where s.owner_id = p_uid and s.status_key = 'yohwa_seal' and s.expires_at > now()) then return '봉인 해독 중에는 별채를 고칠 수 없습니다.'; end if;
  return null;
end $$;

-- 놓인 가구 목록 → 물품별 수
create or replace function public.world_housing_counts(p_items jsonb, p_wall jsonb, p_paper text, p_ground text) returns jsonb
language sql immutable set search_path = '' as $$
  select coalesce(jsonb_object_agg(k, n), '{}'::jsonb) from (
    select k, count(*) n from (
      select 'hf_' || (x ->> 'k') k from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) x
      union all select 'hf_' || (x ->> 'k') from jsonb_array_elements(coalesce(p_wall, '[]'::jsonb)) x
      union all select 'hp_' || p_paper where p_paper is not null
      union all select 'hg_' || p_ground where p_ground is not null) t group by k) u
$$;
create or replace function public.world_housing_store_count(p_items jsonb) returns int
language sql immutable set search_path = '' as $$ select coalesce(sum(value::int), 0)::int from jsonb_each_text(coalesce(p_items, '{}'::jsonb)) $$;

-- 곳간에 넣는다(보상·전리품). p_force면 상한을 넘어도 넣는다. 들어간 수를 돌려준다.
create or replace function public.world_housing_grant(p_owner uuid, p_item text, p_qty int, p_note text, p_force boolean default true) returns int
language plpgsql security definer set search_path = '' as $$
declare s public.world_housing_store%rowtype; cap int; n int := greatest(0, coalesce(p_qty, 0)); nm text;
begin
  select item_name into nm from public.world_item_catalog where item_id = p_item and category = 'furniture';
  if nm is null or n <= 0 then return 0; end if;
  insert into public.world_housing_store(owner_id) values (p_owner) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = p_owner for update;
  if not p_force then
    cap := public.world_housing_store_cap((select size from public.world_housing where owner_id = p_owner));
    n := least(n, greatest(0, cap - public.world_housing_store_count(s.items)));
    if n <= 0 then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (p_owner, 'housing_item', '곳간이 가득 참', public.world_josa(nm, '을', '를') || ' 얻었지만 곳간이 가득 차 두고 왔습니다.', jsonb_build_object('item', p_item));
      return 0;
    end if;
  end if;
  update public.world_housing_store set items = public.world_inv_add(items, p_item, n), updated_at = now() where owner_id = p_owner;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_owner, 'housing_item', '별채 가구 · ' || nm, coalesce(p_note || ' · ', '') || public.world_josa(nm, '이', '가') || ' 곳간에 들어왔습니다.', jsonb_build_object('item', p_item, 'qty', n));
  return n;
end $$;
-- 한 번만 주는 보상
create or replace function public.world_housing_grant_once(p_owner uuid, p_source text, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select item_id from public.world_furniture_sources where source = p_source loop
    insert into public.world_housing_rewards(owner_id, source, item_id) values (p_owner, p_source, r.item_id) on conflict do nothing;
    if found then perform public.world_housing_grant(p_owner, r.item_id, 1, p_note, true); end if;
  end loop;
end $$;
-- 확률 보상: 그 출처의 가구 가운데 하나를 chance 무게로 고른다(별채가 있는 사람만)
create or replace function public.world_housing_roll(p_owner uuid, p_source text, p_p numeric, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare got text;
begin
  if p_p <= 0 or random() >= p_p then return; end if;
  if not exists (select 1 from public.world_housing where owner_id = p_owner) then return; end if;
  select item_id into got from public.world_furniture_sources where source = p_source and chance > 0 order by -ln(greatest(random(), 1e-9)) / chance limit 1;
  if got is not null then perform public.world_housing_grant(p_owner, got, 1, p_note, false); end if;
end $$;

-- 기록 트리거: 토벌 승리·원정 완주·이야기 장 마침·귀허의 주인 처치. 캐릭터 행은 고치지 않는다(곳간·알림만).
create or replace function public.world_housing_event_trg() returns trigger
language plpgsql security definer set search_path = '' as $$
declare p jsonb := coalesce(new.payload, '{}'::jsonb);
begin
  if new.actor_id is null then return new; end if;
  if new.event_type = 'combat' then
    if coalesce((p ->> 'defeated')::boolean, false) then
      if p ->> 'rank' = 'guardian' then perform public.world_housing_roll(new.actor_id, 'drop_guardian', 0.03, '우두머리 전리품');
      else perform public.world_housing_roll(new.actor_id, 'drop_normal', case when p ->> 'rank' = 'elite' then 0.012 else 0.004 end, '토벌 전리품'); end if;
    end if;
  elsif new.event_type = 'expedition_end' then
    if p ->> 'ended' = 'complete' then perform public.world_housing_roll(new.actor_id, 'expedition', 0.04, '원정 완주'); end if;
  elsif new.event_type = 'story' then
    if p ? 'chapter_id' then perform public.world_housing_grant_once(new.actor_id, 'chapter:' || (p ->> 'chapter_id'), '이야기 장 보상'); end if;
  elsif new.event_type = 'gw_win' then
    perform public.world_housing_grant_once(new.actor_id, 'gw_first', '귀허의 주인 첫 처치');
  end if;
  return new;
end $$;
drop trigger if exists trg_world_housing_event on public.world_events;
create trigger trg_world_housing_event after insert on public.world_events
  for each row when (new.event_type in ('combat', 'expedition_end', 'story', 'gw_win')) execute function public.world_housing_event_trg();
-- 칭호를 얻으면(칭호 보상 가구)
create or replace function public.world_housing_title_trg() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.world_furniture_sources where source = 'title:' || new.title_key) then
    perform public.world_housing_grant_once(new.owner_id, 'title:' || new.title_key, '칭호 보상');
  end if;
  return new;
end $$;
drop trigger if exists trg_world_housing_title on public.world_character_titles;
create trigger trg_world_housing_title after insert on public.world_character_titles for each row execute function public.world_housing_title_trg();
-- 합동 토벌: 봉연의 그림자 이기면 기여 1% 넘은 사람마다 명품 가구 확률, 10장 결전 첫 승리는 신품
create or replace function public.world_housing_raid_trg() returns trigger
language plpgsql security definer set search_path = '' as $$
declare m record; tot numeric;
begin
  select greatest(1, sum(contrib)) into tot from public.world_raid_members where raid_id = new.raid_id;
  for m in select owner_id, contrib from public.world_raid_members where raid_id = new.raid_id and acts > 0 loop
    if new.kind = 'final' then perform public.world_housing_grant_once(m.owner_id, 'raid_final', '10장 결전 첫 승리');
    elsif coalesce(m.contrib, 0) / tot >= 0.01 then perform public.world_housing_roll(m.owner_id, 'raid_world', 0.06 + 0.2 * least(1, coalesce(m.contrib, 0) / tot), '봉연의 그림자 토벌'); end if;
  end loop;
  return new;
end $$;
drop trigger if exists trg_world_housing_raid on public.world_raids;
create trigger trg_world_housing_raid after update of status on public.world_raids
  for each row when (new.status = 'won' and old.status is distinct from 'won') execute function public.world_housing_raid_trg();

-- 별채 열기(개방 퀘스트 「객사 별채」를 마치면): 6×6 방과 기본 세트 「단청 별채」를 놓아 준다
create or replace function public.world_housing_open(p_owner uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare d jsonb := public.world_housing_default_set();
begin
  insert into public.world_housing(owner_id, size, items, wall, paper, ground)
  values (p_owner, 6, d -> 'items', d -> 'wall', d ->> 'paper', d ->> 'ground') on conflict (owner_id) do nothing;
  if found then
    insert into public.world_housing_store(owner_id) values (p_owner) on conflict (owner_id) do nothing;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_owner, 'reward', '별채를 얻었습니다', '본부 객사 뒤편의 별채가 이제 당신의 것입니다. 캐릭터 › 별채에서 꾸밀 수 있습니다.', jsonb_build_object('housing', true));
  end if;
end $$;
create or replace function public.world_housing_quest_trg() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.quest_id = 'hs_byeolchae' and new.done_at is not null and (tg_op = 'INSERT' or old.done_at is null) then perform public.world_housing_open(new.owner_id); end if;
  return new;
end $$;
drop trigger if exists trg_world_housing_quest on public.world_quest_progress;
create trigger trg_world_housing_quest after insert or update of done_at on public.world_quest_progress for each row execute function public.world_housing_quest_trg();

-- 퀘스트 장면이 전을 받는다(need.gil, 「객사 별채」 수리비)
select pg_temp.yh_patch('public.world_quest_report(text)', 'rw_gil := coalesce((s.reward ->> ''gil'')::int, 0); rw_xp := coalesce((s.reward ->> ''xp'')::int, 0);',
'rw_gil := coalesce((s.reward ->> ''gil'')::int, 0); rw_xp := coalesce((s.reward ->> ''xp'')::int, 0);
  if coalesce((s.need ->> ''gil'')::int, 0) > 0 then
    if c.gil < (s.need ->> ''gil'')::int then raise exception ''%전이 필요합니다. (가진 전 %)'', (s.need ->> ''gil'')::int, c.gil; end if;
    rw_gil := rw_gil - (s.need ->> ''gil'')::int; msg := msg || ''치른 값: '' || (s.need ->> ''gil'') || ''전 · '';
    insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, ''quest_fee'', -(s.need ->> ''gil'')::int, true, jsonb_build_object(''quest'', p_quest));
  end if;');

-- 별채 보기(내 것·남의 것). 남의 별채는 하루 한 번 발걸음을 센다.
create or replace function public.world_housing_snapshot(p_owner uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); own uuid := coalesce(p_owner, uid); h public.world_housing%rowtype; nm text; why text; today date := public.world_housing_today();
  role text; edit text; c public.world_characters%rowtype; bag jsonb := '{}'::jsonb; store jsonb := '{}'::jsonb; nxt jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select character_name into nm from public.world_characters where owner_id = own;
  if nm is null then raise exception '알 수 없는 조사원입니다.'; end if;
  select * into h from public.world_housing where owner_id = own;
  if not found then
    if own <> uid then raise exception '%님은 아직 별채가 없습니다.', nm; end if;
    return jsonb_build_object('open', false, 'quest', (select jsonb_build_object('step', coalesce(g.step, 0), 'done', g.done_at is not null) from (select 1) z
      left join public.world_quest_progress g on g.owner_id = uid and g.quest_id = 'hs_byeolchae'),
      'store', (select items from public.world_housing_store where owner_id = uid));
  end if;
  why := public.world_housing_can_view(uid, own, h.gate);
  if why is not null then raise exception '%', why; end if;
  role := case when uid = own then 'owner' when public.world_housing_married(uid, own) then 'partner' end;
  if role is null then
    insert into public.world_housing_visits(owner_id, visitor_id, day) values (own, uid, today) on conflict do nothing;
    if found then
      update public.world_housing set visits_total = visits_total + 1, visits_today = case when visits_day = today then visits_today + 1 else 1 end, visits_day = today
       where owner_id = own returning * into h;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      select own, 'housing_visit', '별채 발걸음', character_name || '님이 별채에 다녀갔습니다.', jsonb_build_object('visitor', uid) from public.world_characters where owner_id = uid;
    end if;
  else
    edit := public.world_housing_edit_block(uid);
    select * into c from public.world_characters where owner_id = uid;
    select coalesce(jsonb_object_agg(i.item_id, (c.inventory ->> i.item_id)::int), '{}'::jsonb) into bag
      from public.world_item_catalog i where i.category = 'furniture' and coalesce((c.inventory ->> i.item_id)::int, 0) > 0;
    store := coalesce((select items from public.world_housing_store where owner_id = own), '{}'::jsonb);
    nxt := case h.size when 6 then jsonb_build_object('size', 7, 'gil', 2500, 'level', 15, 'items', jsonb_build_object('lumber', 10))
                       when 7 then jsonb_build_object('size', 8, 'gil', 6000, 'level', 20, 'items', jsonb_build_object('reinforced_lumber', 4, 'lacquer', 6))
                       when 8 then jsonb_build_object('size', 9, 'gil', 15000, 'level', 25, 'items', jsonb_build_object('reinforced_lumber', 6, 'spirit_bark', 4, 'jade_shard', 2)) end;
  end if;
  return jsonb_build_object('open', true, 'owner_id', own, 'owner_name', nm, 'role', role, 'edit_block', case when role is null then null else edit end,
    'size', h.size, 'cap', public.world_housing_cap(h.size), 'store_cap', public.world_housing_store_cap(h.size), 'kind_caps', jsonb_build_array(4, 3, 2, 1, 1),
    'items', h.items, 'wall', h.wall, 'paper', h.paper, 'ground', h.ground, 'gate', h.gate,
    'visits_today', case when h.visits_day = today then h.visits_today else 0 end, 'visits_total', h.visits_total,
    'pet_id', h.pet_id, 'pet_out', h.pet_out,
    'bag', case when role is not null then bag end, 'store', case when role is not null then store end, 'next', nxt,
    'guestbook', (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'writer_id', g.writer_id, 'writer', g.writer_name, 'body', g.body, 'at', g.created_at,
        'mine', g.writer_id = uid, 'can_delete', g.writer_id = uid or uid = own) order by g.created_at desc), '[]'::jsonb)
      from (select * from public.world_housing_guestbook where owner_id = own order by created_at desc limit 20) g),
    'wrote_today', (select count(*) from public.world_housing_guestbook where owner_id = own and writer_id = uid and created_at >= (today::timestamp at time zone 'Asia/Seoul')));
end $$;

-- 저장: 화면이 보낸 배치 전체(p_state = {items:[{k,x,y,r}], wall:[{k,side,t,z}], paper, ground})를 서버가 다시 검사하고 한 번에 반영한다.
--   늘어난 가구는 곳간 → 고치는 사람 가방 순서로 꺼내 쓰고, 줄어든 가구는 주인의 곳간으로 간다.
create or replace function public.world_housing_save(p_owner uuid, p_state jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); own uuid := coalesce(p_owner, uid); c public.world_characters%rowtype; h public.world_housing%rowtype; s public.world_housing_store%rowtype;
  why text; v_items jsonb := coalesce(p_state -> 'items', '[]'::jsonb); v_wall jsonb := coalesce(p_state -> 'wall', '[]'::jsonb); v_paper text := nullif(p_state ->> 'paper', ''); v_ground text := nullif(p_state ->> 'ground', '');
  x jsonb; t jsonb; k text; n int; oldc jsonb; newc jsonb; d int; inv jsonb; st jsonb; take int; occ text[] := '{}'; tops text[] := '{}'; surf text[] := '{}';
  gx int; gy int; r int; w int; dd int; i int; j int; cell text; wl jsonb := '[]'::jsonb; a jsonb; b jsonb; bag_changed boolean := false; placed int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if own <> uid and not public.world_housing_married(uid, own) then raise exception '내 별채나 혼례를 올린 정인의 별채만 고칠 수 있습니다.'; end if;
  why := public.world_housing_edit_block(uid);
  if why is not null then raise exception '%', why; end if;
  if jsonb_typeof(v_items) <> 'array' or jsonb_typeof(v_wall) <> 'array' then raise exception '배치 형식이 올바르지 않습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  select * into h from public.world_housing where owner_id = own for update;
  if not found then raise exception '아직 별채가 없습니다.'; end if;
  placed := jsonb_array_length(v_items) + jsonb_array_length(v_wall);
  if placed > public.world_housing_cap(h.size) then raise exception '이 별채에는 가구를 %개까지 놓을 수 있습니다. (지금 %개)', public.world_housing_cap(h.size), placed; end if;

  -- 바닥 가구: 칸 안·겹침·소품은 윗면 있는 가구 위
  for x in select value from jsonb_array_elements(v_items) loop
    k := x ->> 'k';
    select equipment_traits into t from public.world_item_catalog where item_id = 'hf_' || k and category = 'furniture';
    if t is null or t ->> 'kind' not in ('floor', 'rug', 'surface') then raise exception '바닥에 놓을 수 없는 물건입니다: %', coalesce(k, '?'); end if;
    if jsonb_typeof(x -> 'x') <> 'number' or jsonb_typeof(x -> 'y') <> 'number' then raise exception '자리가 올바르지 않습니다.'; end if;
    gx := (x ->> 'x')::numeric::int; gy := (x ->> 'y')::numeric::int; r := coalesce((x ->> 'r')::numeric::int, 0);
    if (x ->> 'x')::numeric <> gx or (x ->> 'y')::numeric <> gy or r not between 0 and 3 then raise exception '자리가 올바르지 않습니다.'; end if;
    w := (t ->> 'w')::int; dd := (t ->> 'd')::int;
    if r % 2 = 1 then i := w; w := dd; dd := i; end if;
    if gx < 0 or gy < 0 or gx + w > h.size or gy + dd > h.size then raise exception '방 밖으로 나간 가구가 있습니다.'; end if;
    for i in gx .. gx + w - 1 loop for j in gy .. gy + dd - 1 loop
      cell := (t ->> 'kind') || ':' || i || ':' || j;
      if t ->> 'kind' = 'surface' then
        if cell = any (surf) then raise exception '한 자리에 소품을 둘 올릴 수 없습니다.'; end if;
        surf := surf || cell;
      else
        if cell = any (occ) then raise exception '겹쳐 놓인 가구가 있습니다.'; end if;
        occ := occ || cell;
        if t ->> 'kind' = 'floor' and coalesce((t ->> 'top')::numeric, 0) > 0 then tops := tops || (i || ':' || j); end if;
      end if;
    end loop; end loop;
  end loop;
  for x in select value from jsonb_array_elements(v_items) loop
    if (select equipment_traits ->> 'kind' from public.world_item_catalog where item_id = 'hf_' || (x ->> 'k')) = 'surface'
       and not ((x ->> 'x')::numeric::int || ':' || (x ->> 'y')::numeric::int) = any (tops) then
      raise exception '소품은 탁자·서안·서가처럼 윗면이 있는 가구 위에만 올릴 수 있습니다.';
    end if;
  end loop;
  -- 벽 장식: 왼쪽(L)·오른쪽(R) 벽 안, 같은 벽에서 겹치지 않게(t는 칸, z는 높이 픽셀)
  for x in select value from jsonb_array_elements(v_wall) loop
    k := x ->> 'k';
    select equipment_traits into t from public.world_item_catalog where item_id = 'hf_' || k and category = 'furniture';
    if t is null or t ->> 'kind' <> 'wall' then raise exception '벽에 걸 수 없는 물건입니다: %', coalesce(k, '?'); end if;
    if x ->> 'side' not in ('L', 'R') or jsonb_typeof(x -> 't') <> 'number' or jsonb_typeof(x -> 'z') <> 'number' then raise exception '벽 자리가 올바르지 않습니다.'; end if;
    if ((x ->> 't')::numeric * 10) % 1 <> 0 or (x ->> 'z')::numeric % 1 <> 0 then raise exception '벽 자리가 올바르지 않습니다.'; end if;
    if (x ->> 't')::numeric < 0 or (x ->> 't')::numeric + (t ->> 'ww')::numeric > h.size or (x ->> 'z')::numeric < 4 or (x ->> 'z')::numeric + (t ->> 'wh')::numeric > 75 then
      raise exception '벽 밖으로 나간 장식이 있습니다.';
    end if;
    wl := wl || jsonb_build_object('side', x ->> 'side', 't0', (x ->> 't')::numeric, 't1', (x ->> 't')::numeric + (t ->> 'ww')::numeric, 'z0', (x ->> 'z')::numeric, 'z1', (x ->> 'z')::numeric + (t ->> 'wh')::numeric);
  end loop;
  for i in 0 .. jsonb_array_length(wl) - 1 loop for j in i + 1 .. jsonb_array_length(wl) - 1 loop
    a := wl -> i; b := wl -> j;
    if a ->> 'side' = b ->> 'side' and (a ->> 't0')::numeric < (b ->> 't1')::numeric and (b ->> 't0')::numeric < (a ->> 't1')::numeric
       and (a ->> 'z0')::numeric < (b ->> 'z1')::numeric and (b ->> 'z0')::numeric < (a ->> 'z1')::numeric then raise exception '벽 장식이 서로 겹칩니다.'; end if;
  end loop; end loop;
  if v_paper is not null and not exists (select 1 from public.world_item_catalog where item_id = 'hp_' || v_paper and category = 'furniture') then raise exception '알 수 없는 벽지입니다.'; end if;
  if v_ground is not null and not exists (select 1 from public.world_item_catalog where item_id = 'hg_' || v_ground and category = 'furniture') then raise exception '알 수 없는 바닥재입니다.'; end if;

  -- 같은 가구 설치 상한
  newc := public.world_housing_counts(v_items, v_wall, v_paper, v_ground);
  for k, n in select key, value::int from jsonb_each_text(newc) loop
    if k like 'hf\_%' and n > public.world_housing_kind_cap((select tier from public.world_item_catalog where item_id = k)) then
      raise exception '%은(는) 한 별채에 %개까지 놓을 수 있습니다.', (select item_name from public.world_item_catalog where item_id = k), public.world_housing_kind_cap((select tier from public.world_item_catalog where item_id = k));
    end if;
  end loop;

  -- 늘고 준 만큼 곳간·가방에서 오간다
  oldc := public.world_housing_counts(h.items, h.wall, h.paper, h.ground);
  insert into public.world_housing_store(owner_id) values (own) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = own for update;
  inv := coalesce(c.inventory, '{}'::jsonb); st := coalesce(s.items, '{}'::jsonb);
  for k in select key from jsonb_each(newc) union select key from jsonb_each(oldc) loop
    d := coalesce((newc ->> k)::int, 0) - coalesce((oldc ->> k)::int, 0);
    if d > 0 then
      take := least(d, coalesce((st ->> k)::int, 0));
      if take > 0 then st := public.world_inv_add(st, k, -take); if coalesce((st ->> k)::int, 0) <= 0 then st := st - k; end if; d := d - take; end if;
      if d > 0 then
        if coalesce((inv ->> k)::int, 0) < d then raise exception '%이(가) 모자랍니다. 가방이나 곳간에 있어야 놓을 수 있습니다.', (select item_name from public.world_item_catalog where item_id = k); end if;
        inv := public.world_inv_add(inv, k, -d); if coalesce((inv ->> k)::int, 0) <= 0 then inv := inv - k; end if; bag_changed := true;
      end if;
    elsif d < 0 then
      st := public.world_inv_add(st, k, -d);
    end if;
  end loop;
  if public.world_housing_store_count(st) > public.world_housing_store_cap(h.size) and public.world_housing_store_count(st) > public.world_housing_store_count(s.items) then
    raise exception '곳간이 가득 차 거둘 수 없습니다. (곳간 %칸) 곳간을 비운 뒤 다시 저장하세요.', public.world_housing_store_cap(h.size);
  end if;
  update public.world_housing set items = v_items, wall = v_wall, paper = v_paper, ground = v_ground, updated_at = now() where owner_id = own;
  update public.world_housing_store set items = st, updated_at = now() where owner_id = own;
  if bag_changed then update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid; end if;
  return public.world_housing_snapshot(own);
end $$;

-- 곳간: 가방에서 넣기·가방으로 꺼내기·버리기(주인만, 안전지대에서)
create or replace function public.world_housing_store_move(p_item text, p_qty int, p_dir text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_housing_store%rowtype; why text; nm text; have int; n int; room int; sz int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  why := public.world_housing_edit_block(uid);
  if why is not null then raise exception '%', replace(why, '별채를 고칠', '곳간을 쓸'); end if;
  if p_dir not in ('put', 'take', 'discard') then raise exception '알 수 없는 일입니다.'; end if;
  if p_qty is null or p_qty < 1 or p_qty > 99 then raise exception '수량이 올바르지 않습니다.'; end if;
  select item_name into nm from public.world_item_catalog where item_id = p_item and category = 'furniture';
  if nm is null then raise exception '곳간에는 별채 가구만 둘 수 있습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  select size into sz from public.world_housing where owner_id = uid;
  insert into public.world_housing_store(owner_id) values (uid) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = uid for update;
  if p_dir = 'put' then
    if sz is null then raise exception '별채를 얻은 뒤에 곳간을 쓸 수 있습니다.'; end if;
    have := coalesce((c.inventory ->> p_item)::int, 0);
    if have < p_qty then raise exception '가방에 %이(가) 모자랍니다.', nm; end if;
    if public.world_housing_store_count(s.items) + p_qty > public.world_housing_store_cap(sz) then raise exception '곳간이 가득 찼습니다. (곳간 %칸)', public.world_housing_store_cap(sz); end if;
    update public.world_characters set inventory = case when have - p_qty <= 0 then inventory - p_item else jsonb_set(inventory, array[p_item], to_jsonb(have - p_qty)) end, updated_at = now() where owner_id = uid;
    update public.world_housing_store set items = public.world_inv_add(items, p_item, p_qty), updated_at = now() where owner_id = uid;
    return jsonb_build_object('ok', true, 'content', nm || ' ×' || p_qty || '을(를) 곳간에 넣었습니다.');
  end if;
  have := coalesce((s.items ->> p_item)::int, 0);
  if have < p_qty then raise exception '곳간에 %이(가) 모자랍니다.', nm; end if;
  if p_dir = 'take' then
    room := public.world_bag_room(c.inventory, p_item, public.world_bag_limit(uid));
    n := least(p_qty, room);
    if n <= 0 then raise exception '가방에 자리가 없습니다.'; end if;
    update public.world_characters set inventory = public.world_inv_add(inventory, p_item, n), updated_at = now() where owner_id = uid;
  else
    n := p_qty;
  end if;
  update public.world_housing_store set items = case when have - n <= 0 then items - p_item else jsonb_set(items, array[p_item], to_jsonb(have - n)) end, updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'moved', n, 'content', nm || ' ×' || n || case when p_dir = 'take' then '을(를) 가방으로 꺼냈습니다.' else '을(를) 버렸습니다.' end);
end $$;

-- 넓히기: 6→7(2,500전·가공 부적목 10) → 8(Lv20·6,000전·강화 부적목 4·칠액 6) → 9(Lv25·15,000전·강화 부적목 6·영맥 수피 4·비취 파편 2)
create or replace function public.world_housing_expand() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; h public.world_housing%rowtype; why text; need jsonb; v_gil int; lv int; inv jsonb; k text; v int; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  why := public.world_housing_edit_block(uid);
  if why is not null then raise exception '%', why; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  select * into h from public.world_housing where owner_id = uid for update;
  if not found then raise exception '아직 별채가 없습니다.'; end if;
  if h.size >= 9 then raise exception '별채를 더 넓힐 수 없습니다(9×9가 가장 넓습니다).'; end if;
  v_gil := case h.size when 6 then 2500 when 7 then 6000 else 15000 end; lv := case h.size when 6 then 15 when 7 then 20 else 25 end;
  need := case h.size when 6 then '{"lumber":10}'::jsonb when 7 then '{"reinforced_lumber":4,"lacquer":6}'::jsonb else '{"reinforced_lumber":6,"spirit_bark":4,"jade_shard":2}'::jsonb end;
  if c.level < lv then raise exception 'Lv%부터 넓힐 수 있습니다.', lv; end if;
  if c.gil < v_gil then raise exception '%전이 필요합니다. (가진 전 %)', v_gil, c.gil; end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  for k, v in select key, value::int from jsonb_each_text(need) loop
    select item_name into nm from public.world_item_catalog where item_id = k;
    if coalesce((inv ->> k)::int, 0) < v then raise exception '%이(가) %개 필요합니다. (가진 수 %)', nm, v, coalesce((inv ->> k)::int, 0); end if;
    perform public.world_item_give_guard(uid, k, coalesce((inv ->> k)::int, 0), v);
    inv := public.world_inv_add(inv, k, -v); if coalesce((inv ->> k)::int, 0) <= 0 then inv := inv - k; end if;
  end loop;
  update public.world_characters set inventory = inv, gil = gil - v_gil, updated_at = now() where owner_id = uid;
  update public.world_housing set size = size + 1, updated_at = now() where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'housing_expand', -v_gil, true, jsonb_build_object('size', h.size + 1));
  return jsonb_build_object('ok', true, 'size', h.size + 1, 'content', '별채를 ' || (h.size + 1) || '×' || (h.size + 1) || '로 넓혔습니다.');
end $$;

-- 대문(활짝 엶·벗에게만·닫음)
create or replace function public.world_housing_gate(p_gate text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_gate not in ('open', 'friends', 'closed') then raise exception '알 수 없는 대문 설정입니다.'; end if;
  update public.world_housing set gate = p_gate, updated_at = now() where owner_id = uid;
  if not found then raise exception '아직 별채가 없습니다.'; end if;
  return jsonb_build_object('ok', true, 'gate', p_gate);
end $$;

-- 방명록: 한 줄 80자, 한 별채에 하루 3개, 별채마다 최근 20개만 남김
create or replace function public.world_housing_guest_write(p_owner uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); h public.world_housing%rowtype; why text; v_body text := btrim(coalesce(p_body, '')); nm text; today date := public.world_housing_today();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if char_length(v_body) < 1 then raise exception '남길 말을 적어 주세요.'; end if;
  if char_length(v_body) > 80 then raise exception '방명록은 80자까지 쓸 수 있습니다.'; end if;
  select * into h from public.world_housing where owner_id = p_owner;
  if not found then raise exception '별채를 찾을 수 없습니다.'; end if;
  why := public.world_housing_can_view(uid, p_owner, h.gate);
  if why is not null then raise exception '%', why; end if;
  perform pg_advisory_xact_lock(hashtext('yh-guest:' || uid::text || p_owner::text));
  if (select count(*) from public.world_housing_guestbook where owner_id = p_owner and writer_id = uid and created_at >= (today::timestamp at time zone 'Asia/Seoul')) >= 3 then
    raise exception '한 별채에는 하루 3개까지 남길 수 있습니다.';
  end if;
  select character_name into nm from public.world_characters where owner_id = uid;
  insert into public.world_housing_guestbook(owner_id, writer_id, writer_name, body) values (p_owner, uid, nm, v_body);
  delete from public.world_housing_guestbook where owner_id = p_owner and id not in (select id from public.world_housing_guestbook where owner_id = p_owner order by created_at desc limit 20);
  if uid <> p_owner then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_owner, 'housing_guest', '별채 방명록', nm || ': ' || v_body, jsonb_build_object('writer', uid));
  end if;
  return public.world_housing_snapshot(p_owner);
end $$;
create or replace function public.world_housing_guest_delete(p_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); g public.world_housing_guestbook%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into g from public.world_housing_guestbook where id = p_id;
  if not found then raise exception '이미 지워진 글입니다.'; end if;
  if uid not in (g.owner_id, g.writer_id) then raise exception '내 별채의 글이나 내가 쓴 글만 지울 수 있습니다.'; end if;
  delete from public.world_housing_guestbook where id = p_id;
  return jsonb_build_object('ok', true);
end $$;

-- 가구 도감용: 지금까지 얻은 가구 종류(곳간·가방·놓인 것)
create or replace function public.world_housing_owned_kinds(p_uid uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(distinct k)::int from (
    select key k from public.world_housing_store s, jsonb_each(s.items) where s.owner_id = p_uid
    union select key from public.world_housing h, jsonb_each(public.world_housing_counts(h.items, h.wall, h.paper, h.ground)) where h.owner_id = p_uid
    union select i.item_id from public.world_characters c join public.world_item_catalog i on i.category = 'furniture' and coalesce((c.inventory ->> i.item_id)::int, 0) > 0 where c.owner_id = p_uid) t
$$;

-- 조건을 채워 얻은 가구는 상점에 팔 수 없다(거래 불가 가구)
select pg_temp.yh_patch('public.world_shop_sell(text,integer)', 'if not found or item.category = ''quest'' then raise exception',
  'if not found or item.category = ''quest'' or (item.category = ''furniture'' and not coalesce(item.tradeable, false)) then raise exception');
-- 별채 알림은 설정에서 끈다
select pg_temp.yh_patch('public.world_notify_group(text)', '    else null end', '    when p_kind in (''housing_visit'', ''housing_guest'', ''housing_item'', ''pet_play'') then ''housing''
    else null end');

-- 퀘스트 완료 알림의 조사(「제목」제목을 → 「제목」을)
select pg_temp.yh_patch('public.world_quest_report(text)', '''」'' || public.world_josa(q.title, ''을'', ''를'') || '' 마쳤습니다.''',
  '''」'' || substr(public.world_josa(q.title, ''을'', ''를''), char_length(q.title) + 1) || '' 마쳤습니다.''');
