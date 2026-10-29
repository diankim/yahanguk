-- 7.2.0: 별채(하우징) · 꼬마 동무 · …
-- 생성기: supabase/gen72/gen.py (손으로 고치지 말고 생성기를 고친 뒤 다시 만든다). 7.1.0(20261102000000) 뒤에 돈다.
lock table public.world_characters in access exclusive mode;

-- ─────────────────────────────────────────────────────────────
-- A. 만렙 40 · 쌓아 둘 능력치 포인트 117 · 기술 30단계부터 가파르게 · 깊이별 레벨 되살림
-- ─────────────────────────────────────────────────────────────

-- 함수 본문 고치기 도우미: 고칠 자리(old)가 정확히 n번 있어야 바꾼다. 이미 바뀌어 있으면 건너뛴다.
create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

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
      values (p_owner, 'housing_item', '곳간이 가득 참', nm || public.world_josa(nm, '을', '를') || ' 얻었지만 곳간이 가득 차 두고 왔습니다.', jsonb_build_object('item', p_item));
      return 0;
    end if;
  end if;
  update public.world_housing_store set items = public.world_inv_add(items, p_item, n), updated_at = now() where owner_id = p_owner;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_owner, 'housing_item', '별채 가구 · ' || nm, coalesce(p_note || ' · ', '') || nm || public.world_josa(nm, '이', '가') || ' 곳간에 들어왔습니다.', jsonb_build_object('item', p_item, 'qty', n));
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


-- ─── 가구 69가지(바닥·벽·벽지·바닥재) · 제작법 48 · 상점 · 출처 ───
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
select x.item_id, x.item_name, 'furniture', x.tier, x.description, false, '{}'::jsonb, 1, x.equipment_traits, x.tradeable, x.reference_price, 1
  from jsonb_to_recordset($J$[{"item_id":"hf_cushion_obang","item_name":"오방색 방석","tier":1,"description":"별채 가구 · 좌석·탁자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"cushion_obang","kind":"floor","w":1,"d":1,"top":0,"cat":"좌석·탁자","grade":1,"pet":"bed"},"tradeable":true,"reference_price":110},{"item_id":"hf_soban","item_name":"개다리소반","tier":1,"description":"별채 가구 · 좌석·탁자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"soban","kind":"floor","w":1,"d":1,"top":0.42,"cat":"좌석·탁자","grade":1},"tradeable":true,"reference_price":110},{"item_id":"hf_lantern_cheongsa","item_name":"청사초롱","tier":1,"description":"별채 가구 · 조명. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"lantern_cheongsa","kind":"floor","w":1,"d":1,"top":0,"cat":"조명","grade":1},"tradeable":false,"reference_price":120},{"item_id":"hf_onggi","item_name":"옹기 항아리","tier":1,"description":"별채 가구 · 도자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"onggi","kind":"floor","w":1,"d":1,"top":0,"cat":"도자","grade":1},"tradeable":true,"reference_price":80},{"item_id":"hf_pot_orchid","item_name":"난초 화분","tier":1,"description":"별채 가구 · 화분. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"pot_orchid","kind":"floor","w":1,"d":1,"top":0,"cat":"화분","grade":1},"tradeable":true,"reference_price":70},{"item_id":"hf_rug_straw","item_name":"왕골 돗자리","tier":1,"description":"별채 가구 · 깔개. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"rug_straw","kind":"rug","w":2,"d":2,"top":0,"cat":"깔개","grade":1,"pet":"bed"},"tradeable":true,"reference_price":120},{"item_id":"hf_pet_bell","item_name":"방울 놀잇감","tier":1,"description":"별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"pet_bell","kind":"floor","w":1,"d":1,"top":0,"cat":"소품","grade":1,"pet":"toy"},"tradeable":true,"reference_price":130},{"item_id":"hf_pet_bowl","item_name":"놋 먹이 그릇","tier":1,"description":"별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"pet_bowl","kind":"floor","w":1,"d":1,"top":0,"cat":"소품","grade":1,"pet":"bowl"},"tradeable":true,"reference_price":50},{"item_id":"hf_surf_books","item_name":"책갑","tier":1,"description":"별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"surf_books","kind":"surface","w":1,"d":1,"top":0,"cat":"소품","grade":1},"tradeable":true,"reference_price":110},{"item_id":"hf_surf_candle","item_name":"놋 촛대","tier":1,"description":"별채 가구 · 조명. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"surf_candle","kind":"surface","w":1,"d":1,"top":0,"cat":"조명","grade":1},"tradeable":true,"reference_price":120},{"item_id":"hf_pungno","item_name":"풍로","tier":1,"description":"별채 가구 · 화로. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"pungno","kind":"floor","w":1,"d":1,"top":0,"cat":"화로","grade":1},"tradeable":true,"reference_price":80},{"item_id":"hf_table_lacquer","item_name":"주칠 좌식 탁자","tier":2,"description":"별채 가구 · 좌석·탁자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"table_lacquer","kind":"floor","w":2,"d":1,"top":0.55,"cat":"좌석·탁자","grade":2},"tradeable":false,"reference_price":120},{"item_id":"hf_seoan","item_name":"서안","tier":2,"description":"별채 가구 · 좌석·탁자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"seoan","kind":"floor","w":2,"d":1,"top":0.72,"cat":"좌석·탁자","grade":2},"tradeable":true,"reference_price":200},{"item_id":"hf_bandaji","item_name":"반닫이","tier":2,"description":"별채 가구 · 수납. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"bandaji","kind":"floor","w":2,"d":1,"top":0.92,"cat":"수납","grade":2},"tradeable":true,"reference_price":290},{"item_id":"hf_bedding_cotton","item_name":"무명 이부자리","tier":2,"description":"별채 가구 · 침구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"bedding_cotton","kind":"floor","w":2,"d":1,"top":0,"cat":"침구","grade":2,"pet":"bed"},"tradeable":true,"reference_price":320},{"item_id":"hf_pot_bamboo","item_name":"대나무 화분","tier":2,"description":"별채 가구 · 화분. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"pot_bamboo","kind":"floor","w":1,"d":1,"top":0,"cat":"화분","grade":2},"tradeable":true,"reference_price":180},{"item_id":"hf_brazier_brass","item_name":"놋쇠 화로","tier":2,"description":"별채 가구 · 화로. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"brazier_brass","kind":"floor","w":1,"d":1,"top":0,"cat":"화로","grade":2},"tradeable":true,"reference_price":170},{"item_id":"hf_surf_teaset","item_name":"다기 세트","tier":2,"description":"별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"surf_teaset","kind":"surface","w":1,"d":1,"top":0,"cat":"소품","grade":2},"tradeable":true,"reference_price":150},{"item_id":"hf_surf_munbang","item_name":"문방사우","tier":2,"description":"별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"surf_munbang","kind":"surface","w":1,"d":1,"top":0,"cat":"소품","grade":2},"tradeable":true,"reference_price":170},{"item_id":"hf_lamp_jwadeung","item_name":"좌등","tier":2,"description":"별채 가구 · 조명. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"lamp_jwadeung","kind":"floor","w":1,"d":1,"top":0,"cat":"조명","grade":2},"tradeable":true,"reference_price":320},{"item_id":"hf_rug_hwamun","item_name":"화문석","tier":2,"description":"별채 가구 · 깔개. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"rug_hwamun","kind":"rug","w":3,"d":2,"top":0,"cat":"깔개","grade":2,"pet":"bed"},"tradeable":true,"reference_price":300},{"item_id":"hf_pet_perch","item_name":"횃대","tier":2,"description":"별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"pet_perch","kind":"floor","w":1,"d":1,"top":0,"cat":"소품","grade":2,"pet":"perch"},"tradeable":true,"reference_price":160},{"item_id":"hf_wardrobe_najeon","item_name":"자개 장롱","tier":3,"description":"별채 가구 · 수납. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"wardrobe_najeon","kind":"floor","w":2,"d":1,"top":2.36,"cat":"수납","grade":3,"pet":"perch"},"tradeable":true,"reference_price":1200},{"item_id":"hf_bookshelf","item_name":"서가","tier":3,"description":"별채 가구 · 수납. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"bookshelf","kind":"floor","w":2,"d":1,"top":2.04,"cat":"수납","grade":3,"pet":"perch"},"tradeable":true,"reference_price":890},{"item_id":"hf_screen_sansu","item_name":"산수 병풍","tier":3,"description":"별채 가구 · 병풍. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"screen_sansu","kind":"floor","w":2,"d":1,"top":0,"cat":"병풍","grade":3},"tradeable":true,"reference_price":900},{"item_id":"hf_bedding_silk","item_name":"비단 이부자리","tier":3,"description":"별채 가구 · 침구. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"bedding_silk","kind":"floor","w":2,"d":1,"top":0,"cat":"침구","grade":3,"pet":"bed"},"tradeable":true,"reference_price":750},{"item_id":"hf_jar_moon","item_name":"백자 달항아리","tier":3,"description":"별채 가구 · 도자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"jar_moon","kind":"floor","w":1,"d":1,"top":0,"cat":"도자","grade":3},"tradeable":true,"reference_price":590},{"item_id":"hf_celadon_maebyeong","item_name":"청자 매병","tier":3,"description":"별채 가구 · 도자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"celadon_maebyeong","kind":"floor","w":1,"d":1,"top":0,"cat":"도자","grade":3},"tradeable":true,"reference_price":590},{"item_id":"hf_bonsai_pine","item_name":"소나무 분재","tier":3,"description":"별채 가구 · 화분. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"bonsai_pine","kind":"floor","w":1,"d":1,"top":0,"cat":"화분","grade":3},"tradeable":true,"reference_price":530},{"item_id":"hf_aquarium","item_name":"돌확 어항","tier":3,"description":"별채 가구 · 어항. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"aquarium","kind":"floor","w":2,"d":1,"top":0,"cat":"어항","grade":3},"tradeable":true,"reference_price":720},{"item_id":"hf_stone_lamp","item_name":"실내 석등","tier":3,"description":"별채 가구 · 정원. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"stone_lamp","kind":"floor","w":1,"d":1,"top":0,"cat":"정원","grade":3},"tradeable":true,"reference_price":290},{"item_id":"hf_surf_incense","item_name":"청동 향로","tier":3,"description":"별채 가구 · 소품. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"surf_incense","kind":"surface","w":1,"d":1,"top":0,"cat":"소품","grade":3},"tradeable":true,"reference_price":230},{"item_id":"hf_screen_hwajo","item_name":"화조 병풍","tier":4,"description":"별채 가구 · 병풍. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"screen_hwajo","kind":"floor","w":3,"d":1,"top":0,"cat":"병풍","grade":4},"tradeable":false,"reference_price":800},{"item_id":"hf_rug_unhak","item_name":"운학 양탄자","tier":4,"description":"별채 가구 · 깔개. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"rug_unhak","kind":"rug","w":3,"d":3,"top":0,"cat":"깔개","grade":4,"pet":"bed"},"tradeable":false,"reference_price":800},{"item_id":"hf_garden_suban","item_name":"수반 괴석","tier":4,"description":"별채 가구 · 정원. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"garden_suban","kind":"floor","w":2,"d":2,"top":0,"cat":"정원","grade":4},"tradeable":false,"reference_price":800},{"item_id":"hf_screen_ilwol","item_name":"일월오봉도 병풍","tier":5,"description":"별채 가구 · 병풍. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"screen_ilwol","kind":"floor","w":3,"d":1,"top":0,"cat":"병풍","grade":5},"tradeable":false,"reference_price":2000},{"item_id":"hf_throne_dragon","item_name":"금박 용상","tier":5,"description":"별채 가구 · 좌석·탁자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"throne_dragon","kind":"floor","w":2,"d":2,"top":0,"cat":"좌석·탁자","grade":5},"tradeable":false,"reference_price":2000},{"item_id":"hf_lantern_pearl","item_name":"귀허 진주 등롱","tier":5,"description":"별채 가구 · 조명. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"lantern_pearl","kind":"floor","w":1,"d":1,"top":0,"cat":"조명","grade":5},"tradeable":false,"reference_price":2000},{"item_id":"hf_bonsai_yeonri","item_name":"연리목 분재","tier":5,"description":"별채 가구 · 화분. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"bonsai_yeonri","kind":"floor","w":2,"d":1,"top":0,"cat":"화분","grade":5},"tradeable":false,"reference_price":2000},{"item_id":"hf_window_sal","item_name":"살창","tier":1,"description":"별채 가구 · 창문. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"window_sal","kind":"wall","wall":"window","ww":1.6,"wh":30,"cat":"창문","grade":1},"tradeable":true,"reference_price":100},{"item_id":"hf_window_shutter","item_name":"널 덧창","tier":1,"description":"별채 가구 · 창문. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"window_shutter","kind":"wall","wall":"window","ww":1.4,"wh":30,"cat":"창문","grade":1},"tradeable":true,"reference_price":100},{"item_id":"hf_scroll_orchid","item_name":"묵란 족자","tier":1,"description":"별채 가구 · 족자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"scroll_orchid","kind":"wall","wall":"deco","ww":1,"wh":36,"cat":"족자","grade":1},"tradeable":true,"reference_price":100},{"item_id":"hf_fan_taegeuk","item_name":"태극 부채","tier":1,"description":"별채 가구 · 부채. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"fan_taegeuk","kind":"wall","wall":"deco","ww":1,"wh":20,"cat":"부채","grade":1},"tradeable":true,"reference_price":70},{"item_id":"hf_beam_dancheong","item_name":"단청 들보","tier":2,"description":"별채 가구 · 들보. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"beam_dancheong","kind":"wall","wall":"deco","ww":3,"wh":14,"cat":"들보","grade":2},"tradeable":false,"reference_price":120},{"item_id":"hf_window_flower","item_name":"오방 꽃살창","tier":2,"description":"별채 가구 · 창문. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"window_flower","kind":"wall","wall":"window","ww":1.6,"wh":32,"cat":"창문","grade":2},"tradeable":false,"reference_price":120},{"item_id":"hf_door_jangji","item_name":"장지문","tier":2,"description":"별채 가구 · 문. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"door_jangji","kind":"wall","wall":"door","ww":1.6,"wh":40,"cat":"문","grade":2},"tradeable":true,"reference_price":200},{"item_id":"hf_scroll_sansu","item_name":"산수 족자","tier":2,"description":"별채 가구 · 족자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"scroll_sansu","kind":"wall","wall":"deco","ww":1,"wh":38,"cat":"족자","grade":2},"tradeable":true,"reference_price":270},{"item_id":"hf_mask_hahoe","item_name":"하회탈","tier":3,"description":"별채 가구 · 탈. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"mask_hahoe","kind":"wall","wall":"deco","ww":1.2,"wh":26,"cat":"탈","grade":3},"tradeable":false,"reference_price":300},{"item_id":"hf_map_old","item_name":"야행국 옛 지도","tier":3,"description":"별채 가구 · 지도. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"map_old","kind":"wall","wall":"deco","ww":2.4,"wh":30,"cat":"지도","grade":3},"tradeable":false,"reference_price":300},{"item_id":"hf_board_yahaeng","item_name":"현판 「夜行」","tier":4,"description":"별채 가구 · 현판. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"board_yahaeng","kind":"wall","wall":"deco","ww":2,"wh":16,"cat":"현판","grade":4},"tradeable":false,"reference_price":800},{"item_id":"hf_gayageum","item_name":"가야금 걸이","tier":4,"description":"별채 가구 · 악기. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"gayageum","kind":"wall","wall":"deco","ww":3,"wh":16,"cat":"악기","grade":4},"tradeable":false,"reference_price":800},{"item_id":"hf_window_round","item_name":"둥근 달창","tier":4,"description":"별채 가구 · 창문. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"window_round","kind":"wall","wall":"window","ww":1.6,"wh":32,"cat":"창문","grade":4},"tradeable":false,"reference_price":800},{"item_id":"hf_door_yeodat","item_name":"띠살 여닫이문","tier":4,"description":"별채 가구 · 문. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"door_yeodat","kind":"wall","wall":"door","ww":1.8,"wh":40,"cat":"문","grade":4},"tradeable":false,"reference_price":800},{"item_id":"hf_scroll_magpie","item_name":"까치호랑이 족자","tier":4,"description":"별채 가구 · 족자. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"scroll_magpie","kind":"wall","wall":"deco","ww":1.3,"wh":38,"cat":"족자","grade":4},"tradeable":false,"reference_price":800},{"item_id":"hf_board_cheonha","item_name":"비무 장원 현판 「天下第一」","tier":5,"description":"별채 가구 · 현판. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"board_cheonha","kind":"wall","wall":"deco","ww":3.2,"wh":18,"cat":"현판","grade":5},"tradeable":false,"reference_price":2000},{"item_id":"hp_hanji","item_name":"한지","tier":1,"description":"별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"hanji","kind":"paper","cat":"벽지","grade":1},"tradeable":true,"reference_price":100},{"item_id":"hp_bamboo","item_name":"대나무","tier":1,"description":"별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"bamboo","kind":"paper","cat":"벽지","grade":1},"tradeable":true,"reference_price":100},{"item_id":"hp_dancheong","item_name":"단청 벽지","tier":1,"description":"별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"dancheong","kind":"paper","cat":"벽지","grade":1},"tradeable":false,"reference_price":120},{"item_id":"hp_ink_dan","item_name":"먹빛 단청","tier":3,"description":"별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"ink_dan","kind":"paper","cat":"벽지","grade":3},"tradeable":true,"reference_price":470},{"item_id":"hp_yeonji","item_name":"연지빛","tier":2,"description":"별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"yeonji","kind":"paper","cat":"벽지","grade":2},"tradeable":true,"reference_price":270},{"item_id":"hp_cloud","item_name":"구름무늬","tier":2,"description":"별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"cloud","kind":"paper","cat":"벽지","grade":2},"tradeable":true,"reference_price":270},{"item_id":"hp_brick","item_name":"전벽돌","tier":2,"description":"별채 가구 · 벽지. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"brick","kind":"paper","cat":"벽지","grade":2},"tradeable":true,"reference_price":270},{"item_id":"hg_jangpan","item_name":"장판","tier":1,"description":"별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"jangpan","kind":"ground","cat":"바닥재","grade":1},"tradeable":true,"reference_price":90},{"item_id":"hg_maru","item_name":"대청마루","tier":1,"description":"별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"maru","kind":"ground","cat":"바닥재","grade":1},"tradeable":false,"reference_price":120},{"item_id":"hg_wanggol","item_name":"왕골 자리","tier":1,"description":"별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"wanggol","kind":"ground","cat":"바닥재","grade":1},"tradeable":true,"reference_price":90},{"item_id":"hg_jeondol","item_name":"전돌","tier":2,"description":"별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"jeondol","kind":"ground","cat":"바닥재","grade":2},"tradeable":true,"reference_price":200},{"item_id":"hg_baduk","item_name":"바둑판 마루","tier":2,"description":"별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"baduk","kind":"ground","cat":"바닥재","grade":2},"tradeable":true,"reference_price":200},{"item_id":"hg_eotgyeol","item_name":"엇결 마루","tier":3,"description":"별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"eotgyeol","kind":"ground","cat":"바닥재","grade":3},"tradeable":true,"reference_price":840},{"item_id":"hg_ochre","item_name":"황토 장판","tier":2,"description":"별채 가구 · 바닥재. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.","equipment_traits":{"hk":"ochre","kind":"ground","cat":"바닥재","grade":2},"tradeable":true,"reference_price":200}]$J$::jsonb) as x(item_id text, item_name text, tier int, description text, equipment_traits jsonb, tradeable boolean, reference_price int)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = 1;
insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, required_skill, required_skill_rank, craft_field)
select x.recipe_id, x.recipe_name, x.output_item, 1, x.ingredients, null, 1, null, x.description, x.minimum_level, null, x.recipe_difficulty, null, 1, x.craft_field
  from jsonb_to_recordset($J$[{"recipe_id":"r_hf_cushion_obang","recipe_name":"오방색 방석 만들기","output_item":"hf_cushion_obang","ingredients":{"wood":4,"resin":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"목공","description":"별채에 놓을 오방색 방석을(를) 만든다."},{"recipe_id":"r_hf_soban","recipe_name":"개다리소반 만들기","output_item":"hf_soban","ingredients":{"wood":4,"resin":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"목공","description":"별채에 놓을 개다리소반을(를) 만든다."},{"recipe_id":"r_hf_onggi","recipe_name":"옹기 항아리 만들기","output_item":"hf_onggi","ingredients":{"ore":2,"charcoal":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"법구 공예","description":"별채에 놓을 옹기 항아리을(를) 만든다."},{"recipe_id":"r_hf_pot_orchid","recipe_name":"난초 화분 만들기","output_item":"hf_pot_orchid","ingredients":{"herb":3,"ore":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"법구 공예","description":"별채에 놓을 난초 화분을(를) 만든다."},{"recipe_id":"r_hf_rug_straw","recipe_name":"왕골 돗자리 만들기","output_item":"hf_rug_straw","ingredients":{"river_reed":5},"minimum_level":1,"recipe_difficulty":1,"craft_field":"직조","description":"별채에 놓을 왕골 돗자리을(를) 만든다."},{"recipe_id":"r_hf_pet_bell","recipe_name":"방울 놀잇감 만들기","output_item":"hf_pet_bell","ingredients":{"raw_iron":1,"talisman_thread":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"단조","description":"별채에 놓을 방울 놀잇감을(를) 만든다."},{"recipe_id":"r_hf_pet_bowl","recipe_name":"놋 먹이 그릇 만들기","output_item":"hf_pet_bowl","ingredients":{"raw_iron":1,"charcoal":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"단조","description":"별채에 놓을 놋 먹이 그릇을(를) 만든다."},{"recipe_id":"r_hf_surf_books","recipe_name":"책갑 만들기","output_item":"hf_surf_books","ingredients":{"seal_paper":3,"resin":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"봉인 공예","description":"별채에 놓을 책갑을(를) 만든다."},{"recipe_id":"r_hf_surf_candle","recipe_name":"놋 촛대 만들기","output_item":"hf_surf_candle","ingredients":{"seal_paper":2,"wood":2,"resin":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"법구 공예","description":"별채에 놓을 놋 촛대을(를) 만든다."},{"recipe_id":"r_hf_pungno","recipe_name":"풍로 만들기","output_item":"hf_pungno","ingredients":{"raw_iron":2,"charcoal":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"단조","description":"별채에 놓을 풍로을(를) 만든다."},{"recipe_id":"r_hf_seoan","recipe_name":"서안 만들기","output_item":"hf_seoan","ingredients":{"lumber":3,"lacquer":1},"minimum_level":8,"recipe_difficulty":2,"craft_field":"목공","description":"별채에 놓을 서안을(를) 만든다."},{"recipe_id":"r_hf_bandaji","recipe_name":"반닫이 만들기","output_item":"hf_bandaji","ingredients":{"lumber":4,"lacquer":2},"minimum_level":8,"recipe_difficulty":2,"craft_field":"목공","description":"별채에 놓을 반닫이을(를) 만든다."},{"recipe_id":"r_hf_bedding_cotton","recipe_name":"무명 이부자리 만들기","output_item":"hf_bedding_cotton","ingredients":{"cloud_cotton":3,"silk":1},"minimum_level":8,"recipe_difficulty":2,"craft_field":"직조","description":"별채에 놓을 무명 이부자리을(를) 만든다."},{"recipe_id":"r_hf_pot_bamboo","recipe_name":"대나무 화분 만들기","output_item":"hf_pot_bamboo","ingredients":{"herb":3,"moon_moss":1,"ore":2},"minimum_level":8,"recipe_difficulty":2,"craft_field":"법구 공예","description":"별채에 놓을 대나무 화분을(를) 만든다."},{"recipe_id":"r_hf_brazier_brass","recipe_name":"놋쇠 화로 만들기","output_item":"hf_brazier_brass","ingredients":{"iron_ingot":2,"charcoal":2},"minimum_level":8,"recipe_difficulty":2,"craft_field":"단조","description":"별채에 놓을 놋쇠 화로을(를) 만든다."},{"recipe_id":"r_hf_surf_teaset","recipe_name":"다기 세트 만들기","output_item":"hf_surf_teaset","ingredients":{"ore":3,"charcoal":2,"herb":1},"minimum_level":8,"recipe_difficulty":2,"craft_field":"법구 공예","description":"별채에 놓을 다기 세트을(를) 만든다."},{"recipe_id":"r_hf_surf_munbang","recipe_name":"문방사우 만들기","output_item":"hf_surf_munbang","ingredients":{"fine_paper":1,"inkstone":2,"wood":1},"minimum_level":8,"recipe_difficulty":2,"craft_field":"봉인 공예","description":"별채에 놓을 문방사우을(를) 만든다."},{"recipe_id":"r_hf_lamp_jwadeung","recipe_name":"좌등 만들기","output_item":"hf_lamp_jwadeung","ingredients":{"lumber":1,"fine_paper":2,"spirit_dust":1},"minimum_level":8,"recipe_difficulty":2,"craft_field":"법구 공예","description":"별채에 놓을 좌등을(를) 만든다."},{"recipe_id":"r_hf_rug_hwamun","recipe_name":"화문석 만들기","output_item":"hf_rug_hwamun","ingredients":{"river_reed":6,"silk":2},"minimum_level":8,"recipe_difficulty":2,"craft_field":"직조","description":"별채에 놓을 화문석을(를) 만든다."},{"recipe_id":"r_hf_pet_perch","recipe_name":"횃대 만들기","output_item":"hf_pet_perch","ingredients":{"lumber":2,"resin":2},"minimum_level":8,"recipe_difficulty":2,"craft_field":"목공","description":"별채에 놓을 횃대을(를) 만든다."},{"recipe_id":"r_hf_wardrobe_najeon","recipe_name":"자개 장롱 만들기","output_item":"hf_wardrobe_najeon","ingredients":{"reinforced_lumber":2,"lacquer":3,"mirror_shard":1},"minimum_level":15,"recipe_difficulty":3,"craft_field":"목공","description":"별채에 놓을 자개 장롱을(를) 만든다."},{"recipe_id":"r_hf_bookshelf","recipe_name":"서가 만들기","output_item":"hf_bookshelf","ingredients":{"reinforced_lumber":2,"lumber":3},"minimum_level":15,"recipe_difficulty":3,"craft_field":"목공","description":"별채에 놓을 서가을(를) 만든다."},{"recipe_id":"r_hf_screen_sansu","recipe_name":"산수 병풍 만들기","output_item":"hf_screen_sansu","ingredients":{"reinforced_lumber":1,"fine_paper":3,"sealing_ink":2,"cinnabar":1},"minimum_level":15,"recipe_difficulty":3,"craft_field":"목공","description":"별채에 놓을 산수 병풍을(를) 만든다."},{"recipe_id":"r_hf_bedding_silk","recipe_name":"비단 이부자리 만들기","output_item":"hf_bedding_silk","ingredients":{"silk":3,"spirit_thread":2,"cloud_cotton":2},"minimum_level":15,"recipe_difficulty":3,"craft_field":"직조","description":"별채에 놓을 비단 이부자리을(를) 만든다."},{"recipe_id":"r_hf_jar_moon","recipe_name":"백자 달항아리 만들기","output_item":"hf_jar_moon","ingredients":{"spirit_glass":1,"jade_shard":1,"charcoal":2},"minimum_level":15,"recipe_difficulty":3,"craft_field":"법구 공예","description":"별채에 놓을 백자 달항아리을(를) 만든다."},{"recipe_id":"r_hf_celadon_maebyeong","recipe_name":"청자 매병 만들기","output_item":"hf_celadon_maebyeong","ingredients":{"spirit_glass":1,"jade_shard":1,"charcoal":2},"minimum_level":15,"recipe_difficulty":3,"craft_field":"법구 공예","description":"별채에 놓을 청자 매병을(를) 만든다."},{"recipe_id":"r_hf_bonsai_pine","recipe_name":"소나무 분재 만들기","output_item":"hf_bonsai_pine","ingredients":{"spirit_bark":1,"moon_moss":2,"ore":2},"minimum_level":15,"recipe_difficulty":3,"craft_field":"법구 공예","description":"별채에 놓을 소나무 분재을(를) 만든다."},{"recipe_id":"r_hf_aquarium","recipe_name":"돌확 어항 만들기","output_item":"hf_aquarium","ingredients":{"reinforced_lumber":1,"spirit_glass":1,"golden_carp":1,"ore":2},"minimum_level":15,"recipe_difficulty":3,"craft_field":"목공","description":"별채에 놓을 돌확 어항을(를) 만든다."},{"recipe_id":"r_hf_stone_lamp","recipe_name":"실내 석등 만들기","output_item":"hf_stone_lamp","ingredients":{"ore":4,"spirit_dust":1,"charcoal":1,"moon_moss":1},"minimum_level":15,"recipe_difficulty":3,"craft_field":"법구 공예","description":"별채에 놓을 실내 석등을(를) 만든다."},{"recipe_id":"r_hf_surf_incense","recipe_name":"청동 향로 만들기","output_item":"hf_surf_incense","ingredients":{"iron_ingot":2,"charcoal":1,"spirit_dust":1},"minimum_level":15,"recipe_difficulty":3,"craft_field":"단조","description":"별채에 놓을 청동 향로을(를) 만든다."},{"recipe_id":"r_hf_window_sal","recipe_name":"살창 만들기","output_item":"hf_window_sal","ingredients":{"wood":4,"seal_paper":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"목공","description":"별채에 놓을 살창을(를) 만든다."},{"recipe_id":"r_hf_window_shutter","recipe_name":"널 덧창 만들기","output_item":"hf_window_shutter","ingredients":{"wood":4,"seal_paper":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"목공","description":"별채에 놓을 널 덧창을(를) 만든다."},{"recipe_id":"r_hf_scroll_orchid","recipe_name":"묵란 족자 만들기","output_item":"hf_scroll_orchid","ingredients":{"seal_paper":3,"inkstone":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"봉인 공예","description":"별채에 놓을 묵란 족자을(를) 만든다."},{"recipe_id":"r_hf_fan_taegeuk","recipe_name":"태극 부채 만들기","output_item":"hf_fan_taegeuk","ingredients":{"seal_paper":2,"wood":1},"minimum_level":1,"recipe_difficulty":1,"craft_field":"봉인 공예","description":"별채에 놓을 태극 부채을(를) 만든다."},{"recipe_id":"r_hf_door_jangji","recipe_name":"장지문 만들기","output_item":"hf_door_jangji","ingredients":{"lumber":3,"seal_paper":2},"minimum_level":8,"recipe_difficulty":2,"craft_field":"목공","description":"별채에 놓을 장지문을(를) 만든다."},{"recipe_id":"r_hf_scroll_sansu","recipe_name":"산수 족자 만들기","output_item":"hf_scroll_sansu","ingredients":{"fine_paper":2,"sealing_ink":1},"minimum_level":8,"recipe_difficulty":2,"craft_field":"봉인 공예","description":"별채에 놓을 산수 족자을(를) 만든다."},{"recipe_id":"r_hp_hanji","recipe_name":"한지 만들기","output_item":"hp_hanji","ingredients":{"seal_paper":4},"minimum_level":1,"recipe_difficulty":1,"craft_field":"봉인 공예","description":"별채에 놓을 한지을(를) 만든다."},{"recipe_id":"r_hp_bamboo","recipe_name":"대나무 만들기","output_item":"hp_bamboo","ingredients":{"seal_paper":4},"minimum_level":1,"recipe_difficulty":1,"craft_field":"봉인 공예","description":"별채에 놓을 대나무을(를) 만든다."},{"recipe_id":"r_hp_ink_dan","recipe_name":"먹빛 단청 만들기","output_item":"hp_ink_dan","ingredients":{"fine_paper":3,"sealing_ink":2,"inkstone":1},"minimum_level":15,"recipe_difficulty":3,"craft_field":"봉인 공예","description":"별채에 놓을 먹빛 단청을(를) 만든다."},{"recipe_id":"r_hp_yeonji","recipe_name":"연지빛 만들기","output_item":"hp_yeonji","ingredients":{"fine_paper":2,"cinnabar":1},"minimum_level":8,"recipe_difficulty":2,"craft_field":"봉인 공예","description":"별채에 놓을 연지빛을(를) 만든다."},{"recipe_id":"r_hp_cloud","recipe_name":"구름무늬 만들기","output_item":"hp_cloud","ingredients":{"fine_paper":2,"cinnabar":1},"minimum_level":8,"recipe_difficulty":2,"craft_field":"봉인 공예","description":"별채에 놓을 구름무늬을(를) 만든다."},{"recipe_id":"r_hp_brick","recipe_name":"전벽돌 만들기","output_item":"hp_brick","ingredients":{"fine_paper":2,"cinnabar":1},"minimum_level":8,"recipe_difficulty":2,"craft_field":"봉인 공예","description":"별채에 놓을 전벽돌을(를) 만든다."},{"recipe_id":"r_hg_jangpan","recipe_name":"장판 만들기","output_item":"hg_jangpan","ingredients":{"wood":5},"minimum_level":1,"recipe_difficulty":1,"craft_field":"목공","description":"별채에 놓을 장판을(를) 만든다."},{"recipe_id":"r_hg_wanggol","recipe_name":"왕골 자리 만들기","output_item":"hg_wanggol","ingredients":{"wood":5},"minimum_level":1,"recipe_difficulty":1,"craft_field":"목공","description":"별채에 놓을 왕골 자리을(를) 만든다."},{"recipe_id":"r_hg_jeondol","recipe_name":"전돌 만들기","output_item":"hg_jeondol","ingredients":{"lumber":3,"ore":2},"minimum_level":8,"recipe_difficulty":2,"craft_field":"목공","description":"별채에 놓을 전돌을(를) 만든다."},{"recipe_id":"r_hg_baduk","recipe_name":"바둑판 마루 만들기","output_item":"hg_baduk","ingredients":{"lumber":3,"ore":2},"minimum_level":8,"recipe_difficulty":2,"craft_field":"목공","description":"별채에 놓을 바둑판 마루을(를) 만든다."},{"recipe_id":"r_hg_eotgyeol","recipe_name":"엇결 마루 만들기","output_item":"hg_eotgyeol","ingredients":{"reinforced_lumber":2,"lumber":2},"minimum_level":15,"recipe_difficulty":3,"craft_field":"목공","description":"별채에 놓을 엇결 마루을(를) 만든다."},{"recipe_id":"r_hg_ochre","recipe_name":"황토 장판 만들기","output_item":"hg_ochre","ingredients":{"lumber":3,"ore":2},"minimum_level":8,"recipe_difficulty":2,"craft_field":"목공","description":"별채에 놓을 황토 장판을(를) 만든다."}]$J$::jsonb) as x(recipe_id text, recipe_name text, output_item text, ingredients jsonb, description text, minimum_level int, recipe_difficulty int, craft_field text)
on conflict (recipe_id) do update set ingredients = excluded.ingredients, minimum_level = excluded.minimum_level, recipe_difficulty = excluded.recipe_difficulty,
  craft_field = excluded.craft_field, description = excluded.description, recipe_name = excluded.recipe_name;
-- 범품 가구는 안전지대 상점(대장간·반요촌 빼고)마다 다섯 가지씩 돌아가며 판다
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, x.item_id, x.price, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join lateral (select y.item_id, y.price from jsonb_to_recordset($J$[{"item_id":"hf_cushion_obang","price":110},{"item_id":"hf_soban","price":110},{"item_id":"hf_onggi","price":80},{"item_id":"hf_pot_orchid","price":70},{"item_id":"hf_rug_straw","price":120},{"item_id":"hf_pet_bell","price":130},{"item_id":"hf_pet_bowl","price":50},{"item_id":"hf_surf_books","price":110},{"item_id":"hf_surf_candle","price":120},{"item_id":"hf_pungno","price":80},{"item_id":"hf_window_sal","price":100},{"item_id":"hf_window_shutter","price":100},{"item_id":"hf_scroll_orchid","price":100},{"item_id":"hf_fan_taegeuk","price":70},{"item_id":"hp_hanji","price":100},{"item_id":"hp_bamboo","price":100},{"item_id":"hg_jangpan","price":90},{"item_id":"hg_wanggol","price":90}]$J$::jsonb) as y(item_id text, price int) order by md5(s.shop_id || y.item_id) limit 5) x
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;
delete from public.world_furniture_sources;
insert into public.world_furniture_sources(source, item_id, chance) select x.source, x.item_id, x.chance from jsonb_to_recordset($J$[{"source":"drop_normal","item_id":"hf_seoan","chance":1},{"source":"drop_normal","item_id":"hf_bandaji","chance":1},{"source":"drop_normal","item_id":"hf_bedding_cotton","chance":1},{"source":"drop_normal","item_id":"hf_pot_bamboo","chance":1},{"source":"drop_normal","item_id":"hf_brazier_brass","chance":1},{"source":"drop_normal","item_id":"hf_surf_teaset","chance":1},{"source":"drop_normal","item_id":"hf_surf_munbang","chance":1},{"source":"drop_normal","item_id":"hf_lamp_jwadeung","chance":1},{"source":"drop_normal","item_id":"hf_rug_hwamun","chance":1},{"source":"drop_normal","item_id":"hf_pet_perch","chance":1},{"source":"drop_guardian","item_id":"hf_wardrobe_najeon","chance":1},{"source":"expedition","item_id":"hf_wardrobe_najeon","chance":1},{"source":"drop_guardian","item_id":"hf_bookshelf","chance":1},{"source":"expedition","item_id":"hf_bookshelf","chance":1},{"source":"drop_guardian","item_id":"hf_screen_sansu","chance":1},{"source":"expedition","item_id":"hf_screen_sansu","chance":1},{"source":"drop_guardian","item_id":"hf_bedding_silk","chance":1},{"source":"expedition","item_id":"hf_bedding_silk","chance":1},{"source":"drop_guardian","item_id":"hf_jar_moon","chance":1},{"source":"expedition","item_id":"hf_jar_moon","chance":1},{"source":"drop_guardian","item_id":"hf_celadon_maebyeong","chance":1},{"source":"expedition","item_id":"hf_celadon_maebyeong","chance":1},{"source":"drop_guardian","item_id":"hf_bonsai_pine","chance":1},{"source":"expedition","item_id":"hf_bonsai_pine","chance":1},{"source":"drop_guardian","item_id":"hf_aquarium","chance":1},{"source":"expedition","item_id":"hf_aquarium","chance":1},{"source":"drop_guardian","item_id":"hf_stone_lamp","chance":1},{"source":"expedition","item_id":"hf_stone_lamp","chance":1},{"source":"drop_guardian","item_id":"hf_surf_incense","chance":1},{"source":"expedition","item_id":"hf_surf_incense","chance":1},{"source":"chapter:eclipse_gate","item_id":"hf_screen_hwajo","chance":1},{"source":"raid_world","item_id":"hf_rug_unhak","chance":1},{"source":"chapter:sunken_lantern","item_id":"hf_garden_suban","chance":1},{"source":"raid_final","item_id":"hf_screen_ilwol","chance":1},{"source":"title:gw_kill10","item_id":"hf_throne_dragon","chance":1},{"source":"gw_first","item_id":"hf_lantern_pearl","chance":1},{"source":"title:wed_vow","item_id":"hf_bonsai_yeonri","chance":1},{"source":"drop_normal","item_id":"hf_door_jangji","chance":1},{"source":"drop_normal","item_id":"hf_scroll_sansu","chance":1},{"source":"chapter:lamp_shadow","item_id":"hf_board_yahaeng","chance":1},{"source":"raid_world","item_id":"hf_gayageum","chance":1},{"source":"chapter:ash_sea","item_id":"hf_window_round","chance":1},{"source":"chapter:nine_gates","item_id":"hf_door_yeodat","chance":1},{"source":"title:tn_team","item_id":"hf_scroll_magpie","chance":1},{"source":"title:tn_champ","item_id":"hf_board_cheonha","chance":1},{"source":"drop_guardian","item_id":"hp_ink_dan","chance":1},{"source":"expedition","item_id":"hp_ink_dan","chance":1},{"source":"drop_normal","item_id":"hp_yeonji","chance":1},{"source":"drop_normal","item_id":"hp_cloud","chance":1},{"source":"drop_normal","item_id":"hp_brick","chance":1},{"source":"drop_normal","item_id":"hg_jeondol","chance":1},{"source":"drop_normal","item_id":"hg_baduk","chance":1},{"source":"drop_guardian","item_id":"hg_eotgyeol","chance":1},{"source":"expedition","item_id":"hg_eotgyeol","chance":1},{"source":"drop_normal","item_id":"hg_ochre","chance":1}]$J$::jsonb) as x(source text, item_id text, chance numeric);
insert into public.world_faction_vault(faction_id, item_id, rank_need, price, sort, kind)
select f.faction_id, x.item_id, x.rank_need, x.price, 900 + x.rank_need, 'item' from public.world_major_factions f cross join jsonb_to_recordset($J$[{"item_id":"hf_mask_hahoe","rank_need":3,"price":200},{"item_id":"hf_map_old","rank_need":3,"price":220},{"item_id":"hf_gayageum","rank_need":5,"price":400}]$J$::jsonb) as x(item_id text, rank_need int, price int)
on conflict do nothing;
-- 기본 세트 「단청 별채」
create or replace function public.world_housing_default_set() returns jsonb language sql immutable set search_path = '' as $D$ select $J${"paper":"dancheong","ground":"maru","items":[{"k":"table_lacquer","x":2,"y":2,"r":0},{"k":"cushion_obang","x":2,"y":3,"r":0},{"k":"cushion_obang","x":3,"y":1,"r":0},{"k":"lantern_cheongsa","x":5,"y":0,"r":0}],"wall":[{"k":"beam_dancheong","side":"R","t":1.5,"z":44},{"k":"window_flower","side":"L","t":2.2,"z":24}]}$J$::jsonb $D$;

insert into public.world_quest_npcs(npc_key, npc_name, bio) select x.k, x.n, x.b from jsonb_to_recordset($J$[{"k":"hs_bomi","n":"객사 살림꾼 보미","b":"본부 객사의 살림을 맡은 사람. 손님 방부터 뒤뜰 장독까지 모르는 것이 없다. 오래 비어 있던 별채를 아까워한다."}]$J$::jsonb) as x(k text, n text, b text)
on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active)
values ('hs_byeolchae', 'side', '생활·별채', '객사 별채', '본부 객사 뒤뜰의 빈 별채를 손봐 내 방으로 삼는다. (주 이야기 4장을 마친 뒤 Lv15부터)', 'hq_dorm', 15, array['mq_frost_seal'], null, 950, '[]'::jsonb, true)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward)
select 'hs_byeolchae', x.step, x.title, x.goal, x.need, x.lines, x.reward from jsonb_to_recordset($J$[{"step":1,"title":"빈 별채","goal":"본부 객사의 살림꾼 보미에게 말을 겁니다.","need":{"at":["hq_dorm"]},"lines":[{"s":null,"t":"객사 뒤뜰, 마른 감나무 너머로 지붕 낮은 별채가 보인다. 문살에 먼지가 하얗게 앉았다."},{"s":"q:hs_bomi","t":"저 별채 말이우? 예전엔 오래 머무는 조사원들이 쓰던 방이었지."},{"s":"q:hs_bomi","t":"주인이 안 돌아온 지 몇 해째라, 이제 들일 사람을 찾고 있었수."},{"s":"q:hs_bomi","t":"손 좀 보면 쓸 만해. 마음 있으면 채비부터 같이 해 봅시다."}],"reward":{}},{"step":2,"title":"채비","goal":"부적목 6개·황지 4개를 채집해 오고, 오방색 방석 하나를 직접 만듭니다.","need":{"at":["hq_dorm"],"give":{"wood":6,"seal_paper":4},"tasks":[{"t":"gather","n":6,"items":["wood"]},{"t":"gather","n":4,"items":["seal_paper"]},{"t":"craft","n":1,"items":["hf_cushion_obang"]}]},"lines":[{"s":null,"t":"보미가 부적목을 하나씩 두드려 보고 고개를 끄덕인다."},{"s":"q:hs_bomi","t":"나무는 좋수. 황지는 문창에 바를 거라 넉넉해야 해."},{"s":"q:hs_bomi","t":"방석은 손수 만든 거네. 바느질이 삐뚤어도 처음 깔 자리는 제 손으로 만든 게 제일이우."},{"s":"q:hs_bomi","t":"이제 수리비만 치르면 열쇠를 넘겨 드리지."}],"reward":{"xp":840}},{"step":3,"title":"입주","goal":"수리비 1,000전을 치르고 별채 열쇠를 받습니다.","need":{"at":["hq_dorm"],"gil":1000},"lines":[{"s":null,"t":"보미가 허리춤에서 녹슨 열쇠 꾸러미를 풀어 하나를 골라낸다."},{"s":"q:hs_bomi","t":"자, 이제 당신 방이우. 단청 들보랑 꽃살창은 옛 주인이 남기고 간 걸 닦아 둔 거고."},{"s":"q:hs_bomi","t":"가구는 안전지대에 있을 때 들이고 옮길 수 있수. 바깥에선 구경만 하고."},{"s":"q:hs_bomi","t":"손님이 오면 방명록도 받아 보구려. 빈방에 사람 냄새가 나야 집이 살아."},{"s":null,"t":"문을 밀자 마루 냄새가 훅 끼친다. 오래 잠들어 있던 방이 숨을 쉬기 시작한다."}],"reward":{"xp":840,"gil":65}}]$J$::jsonb)
  as x(step int, title text, goal text, need jsonb, lines jsonb, reward jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;

-- ─────────────────────────────────────────────────────────────
-- 7.2 ② 꼬마 동무(펫) 30종: 능력치·보상 효과 없음. 도감처럼 모으고, 별채에 한 마리를 두거나 데리고 다닌다(조사원 카드에 보임).
--   얻기: 범품 바구니(상점) · 양품 「얼룩무늬 알」(탐색 희귀) · 진품 퀘스트·「빛나는 알」(탐색 아주 드묾) · 명품 어려운 퀘스트·칭호 · 신품 아주 어려운 칭호·외전
--   거래는 바구니·알(물품)로만, 조건을 채워 얻은 동무는 바로 도감에 들어온다(한 번만).
--   쓰다듬기·놀아 주기·먹이는 별채 안에서만(손님도 하루 한 번씩 쓰다듬기·놀아 주기). 먹이는 고르는 것이고 안 먹여도 불이익 없다.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.world_pet_species (
  pet_id text primary key, pet_name text not null, grade int not null, kind text, likes text, how text, sort int not null default 0, egg boolean not null default false
);
create table if not exists public.world_pets (
  owner_id uuid not null, pet_id text not null, nickname text, affinity int not null default 0, source text, got_at timestamptz not null default now(),
  pat_day date, pat_n int not null default 0, play_day date, play_n int not null default 0, feed_day date, feed_n int not null default 0,
  primary key (owner_id, pet_id)
);
create table if not exists public.world_pet_guest (
  owner_id uuid not null, visitor_id uuid not null, day date not null, pat boolean not null default false, play boolean not null default false,
  primary key (owner_id, visitor_id, day)
);
create table if not exists public.world_pet_sources (source text not null, pet_id text not null, primary key (source, pet_id));
alter table public.world_pet_species enable row level security;
alter table public.world_pets enable row level security;
alter table public.world_pet_guest enable row level security;
alter table public.world_pet_sources enable row level security;
revoke all on public.world_pet_species, public.world_pets, public.world_pet_guest, public.world_pet_sources from anon, authenticated;
grant select on public.world_pet_species, public.world_pet_sources to fn_owner_field;
grant select, insert, update, delete on public.world_pets, public.world_pet_guest to fn_owner_field;

-- 동무를 도감에 넣는다. 이미 있으면 먹이 셋을 개인 창고에 넣어 준다(조건 보상이 겹칠 때).
create or replace function public.world_pet_grant(p_owner uuid, p_pet text, p_source text, p_notify boolean default true) returns boolean
language plpgsql security definer set search_path = '' as $$
declare nm text;
begin
  select pet_name into nm from public.world_pet_species where pet_id = p_pet;
  if nm is null then return false; end if;
  insert into public.world_pets(owner_id, pet_id, source) values (p_owner, p_pet, p_source) on conflict do nothing;
  if found then
    if p_notify then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (p_owner, 'pet_new', '꼬마 동무 · ' || nm, nm || public.world_josa(nm, '이', '가') || ' 동무가 되었습니다. 캐릭터 › 별채에서 만날 수 있습니다.', jsonb_build_object('pet_id', p_pet));
    end if;
    perform public.world_title_award_check(p_owner, 'home');
    return true;
  end if;
  if p_notify then
    insert into public.world_storage(owner_id) values (p_owner) on conflict (owner_id) do nothing;
    update public.world_storage set items = public.world_inv_add(items, 'pet_food', 3), updated_at = now() where owner_id = p_owner;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_owner, 'pet_new', '꼬마 동무 · ' || nm, '이미 함께하는 ' || nm || '라 대신 동무 주먹밥 3개를 개인 창고에 넣었습니다.', jsonb_build_object('pet_id', p_pet));
  end if;
  return false;
end $$;
create or replace function public.world_pet_grant_source(p_owner uuid, p_source text) returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select pet_id from public.world_pet_sources where source = p_source loop perform public.world_pet_grant(p_owner, r.pet_id, p_source, true); end loop;
end $$;

-- 바구니·알을 열어 동무를 맞는다
create or replace function public.world_pet_adopt(p_item text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; pid text; g int; have int; sp public.world_pet_species%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into it from public.world_item_catalog where item_id = p_item and category = 'pet';
  if not found then raise exception '동무를 맞을 수 있는 물품이 아닙니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  have := coalesce((c.inventory ->> p_item)::int, 0);
  if have < 1 then raise exception '가방에 %이(가) 없습니다.', it.item_name; end if;
  if c.downed_at is not null then raise exception '전투불능 상태에서는 열 수 없습니다.'; end if;
  pid := it.equipment_traits ->> 'pet';
  if pid is not null then
    if exists (select 1 from public.world_pets where owner_id = uid and pet_id = pid) then raise exception '이미 함께하는 동무입니다. 바구니는 팔거나 다른 조사원에게 넘길 수 있습니다.'; end if;
  else
    g := (it.equipment_traits ->> 'egg')::int;
    select s.pet_id into pid from public.world_pet_species s
     where s.grade = g and s.egg and not exists (select 1 from public.world_pets p where p.owner_id = uid and p.pet_id = s.pet_id)
     order by random() limit 1;
    if pid is null then raise exception '이 알에서 나올 동무를 모두 만났습니다. 알은 팔거나 다른 조사원에게 넘길 수 있습니다.'; end if;
  end if;
  update public.world_characters set inventory = case when have - 1 <= 0 then inventory - p_item else jsonb_set(inventory, array[p_item], to_jsonb(have - 1)) end, updated_at = now() where owner_id = uid;
  perform public.world_pet_grant(uid, pid, 'item:' || p_item, false);
  select * into sp from public.world_pet_species where pet_id = pid;
  return jsonb_build_object('ok', true, 'pet_id', pid, 'name', sp.pet_name, 'grade', sp.grade,
    'content', case when pid = it.equipment_traits ->> 'pet' then sp.pet_name || public.world_josa(sp.pet_name, '이', '가') || ' 바구니에서 고개를 내밀었습니다.'
                    else '알이 갈라지고 ' || sp.pet_name || public.world_josa(sp.pet_name, '이', '가') || ' 태어났습니다!' end);
end $$;

-- 별명: 8자까지, 비우면 원래 이름
create or replace function public.world_pet_nickname(p_pet text, p_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); nm text := nullif(btrim(coalesce(p_name, '')), '');
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if nm is not null then
    if char_length(nm) > 8 then raise exception '별명은 8자까지 지을 수 있습니다.'; end if;
    if nm !~ '^[가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9 ]+$' then raise exception '별명에는 한글·영문·숫자만 쓸 수 있습니다.'; end if;
    if lower(replace(nm, ' ', '')) ~ '(gm|운영|관리자|씨발|시발|개새|병신|좆|존나|섹스|fuck|shit)' then raise exception '쓸 수 없는 낱말이 들어 있습니다.'; end if;
  end if;
  update public.world_pets set nickname = nm where owner_id = uid and pet_id = p_pet;
  if not found then raise exception '함께하는 동무가 아닙니다.'; end if;
  return jsonb_build_object('ok', true, 'nickname', nm);
end $$;

-- 별채에 둘 동무(한 마리) · 데리고 다니기
create or replace function public.world_pet_place(p_pet text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_pet is not null and not exists (select 1 from public.world_pets where owner_id = uid and pet_id = p_pet) then raise exception '함께하는 동무가 아닙니다.'; end if;
  update public.world_housing set pet_id = p_pet, pet_out = false, updated_at = now() where owner_id = uid;
  if not found then raise exception '별채를 얻은 뒤에 동무를 들일 수 있습니다.'; end if;
  return jsonb_build_object('ok', true, 'pet_id', p_pet);
end $$;
create or replace function public.world_pet_walk(p_out boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); h public.world_housing%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into h from public.world_housing where owner_id = uid for update;
  if not found then raise exception '별채를 얻은 뒤에 동무와 다닐 수 있습니다.'; end if;
  if h.pet_id is null then raise exception '먼저 별채에 동무를 들이세요.'; end if;
  update public.world_housing set pet_out = coalesce(p_out, false), updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'pet_out', coalesce(p_out, false));
end $$;

-- 별채 안에서 동무와 놀기(p_act pat·play·feed). 주인은 하루 쓰다듬기 5·놀기 3·먹이 3번까지 친밀도가 오르고, 손님은 쓰다듬기·놀기를 하루 한 번씩.
create or replace function public.world_pet_act(p_owner uuid, p_act text, p_item text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); h public.world_housing%rowtype; pt public.world_pets%rowtype; sp public.world_pet_species%rowtype; why text;
  today date := public.world_housing_today(); gain int := 0; react text := 'heart'; c public.world_characters%rowtype; have int; was_adult boolean; g public.world_pet_guest%rowtype; nm text; vn text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_act not in ('pat', 'play', 'feed') then raise exception '알 수 없는 놀이입니다.'; end if;
  select * into h from public.world_housing where owner_id = p_owner;
  if not found or h.pet_id is null then raise exception '이 별채에는 동무가 없습니다.'; end if;
  if h.pet_out then raise exception '동무가 주인과 함께 나가 있습니다.'; end if;
  why := public.world_housing_can_view(uid, p_owner, h.gate);
  if why is not null then raise exception '%', why; end if;
  select * into pt from public.world_pets where owner_id = p_owner and pet_id = h.pet_id for update;
  select * into sp from public.world_pet_species where pet_id = h.pet_id;
  nm := coalesce(pt.nickname, sp.pet_name); was_adult := pt.affinity >= 100;
  if uid = p_owner then
    if p_act = 'pat' then
      if pt.pat_day is distinct from today then pt.pat_n := 0; end if;
      pt.pat_n := pt.pat_n + 1; pt.pat_day := today; gain := case when pt.pat_n <= 5 then 2 else 0 end;
    elsif p_act = 'play' then
      if pt.play_day is distinct from today then pt.play_n := 0; end if;
      pt.play_n := pt.play_n + 1; pt.play_day := today; gain := case when pt.play_n <= 3 then 3 else 0 end; react := 'note';
    else
      if p_item is null or (p_item <> 'pet_food' and p_item not like 'treat\_%') then raise exception '동무 먹이를 골라 주세요.'; end if;
      if pt.feed_day is distinct from today then pt.feed_n := 0; end if;
      if pt.feed_n >= 3 then raise exception '%은(는) 오늘 배가 불러 더 먹지 않습니다.', nm; end if;
      select * into c from public.world_characters where owner_id = uid for update;
      have := coalesce((c.inventory ->> p_item)::int, 0);
      if have < 1 then raise exception '가방에 그 먹이가 없습니다.'; end if;
      update public.world_characters set inventory = case when have - 1 <= 0 then inventory - p_item else jsonb_set(inventory, array[p_item], to_jsonb(have - 1)) end, updated_at = now() where owner_id = uid;
      pt.feed_n := pt.feed_n + 1; pt.feed_day := today;
      gain := case when p_item = sp.likes then 12 when p_item = 'pet_food' then 4 else 6 end; react := case when p_item = sp.likes then 'star' else 'bowl' end;
    end if;
  else
    if p_act = 'feed' then raise exception '먹이는 주인만 줄 수 있습니다.'; end if;
    insert into public.world_pet_guest(owner_id, visitor_id, day) values (p_owner, uid, today) on conflict do nothing;
    select * into g from public.world_pet_guest where owner_id = p_owner and visitor_id = uid and day = today for update;
    if (p_act = 'pat' and g.pat) or (p_act = 'play' and g.play) then raise exception '오늘은 이미 %했습니다. 내일 또 와 주세요.', case when p_act = 'pat' then '쓰다듬어 주었' else '놀아 주었' end; end if;
    update public.world_pet_guest set pat = pat or p_act = 'pat', play = play or p_act = 'play' where owner_id = p_owner and visitor_id = uid and day = today;
    gain := 1; react := case when p_act = 'play' then 'note' else 'heart' end;
    if not g.pat and not g.play then
      select character_name into vn from public.world_characters where owner_id = uid;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (p_owner, 'pet_play', '별채의 동무', vn || '님이 ' || nm || public.world_josa(nm, '과', '와') || ' ' || case when p_act = 'pat' then '쓰다듬어 주었습니다.' else '놀아 주었습니다.' end, jsonb_build_object('visitor', uid));
    end if;
  end if;
  pt.affinity := least(300, pt.affinity + gain);
  update public.world_pets set affinity = pt.affinity, pat_day = pt.pat_day, pat_n = pt.pat_n, play_day = pt.play_day, play_n = pt.play_n, feed_day = pt.feed_day, feed_n = pt.feed_n
   where owner_id = p_owner and pet_id = h.pet_id;
  if not was_adult and pt.affinity >= 100 then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_owner, 'pet_new', '꼬마 동무가 자랐습니다', nm || public.world_josa(nm, '이', '가') || ' 훌쩍 자랐습니다.', jsonb_build_object('pet_id', h.pet_id));
    perform public.world_title_award_check(p_owner, 'home');
  end if;
  return jsonb_build_object('ok', true, 'affinity', pt.affinity, 'gain', gain, 'adult', pt.affinity >= 100, 'grew', not was_adult and pt.affinity >= 100, 'react', react,
    'counts', case when uid = p_owner then jsonb_build_object('pat', pt.pat_n, 'play', pt.play_n, 'feed', pt.feed_n) end);
end $$;

-- 내 동무 도감(모든 종 + 함께하는 동무)
create or replace function public.world_pet_snapshot() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); today date := public.world_housing_today();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object(
    'species', (select coalesce(jsonb_agg(jsonb_build_object('id', s.pet_id, 'name', s.pet_name, 'grade', s.grade, 'kind', s.kind, 'likes', s.likes, 'how', s.how) order by s.sort), '[]'::jsonb) from public.world_pet_species s),
    'mine', (select coalesce(jsonb_agg(jsonb_build_object('id', p.pet_id, 'nick', p.nickname, 'affinity', p.affinity, 'adult', p.affinity >= 100, 'got_at', p.got_at,
        'pat', case when p.pat_day = today then p.pat_n else 0 end, 'play', case when p.play_day = today then p.play_n else 0 end, 'feed', case when p.feed_day = today then p.feed_n else 0 end) order by p.got_at), '[]'::jsonb)
      from public.world_pets p where p.owner_id = uid),
    'room', (select jsonb_build_object('pet_id', h.pet_id, 'pet_out', h.pet_out) from public.world_housing h where h.owner_id = uid));
end $$;
-- 남의 별채에서 보는 동무 한 마리(이름·자람)
create or replace function public.world_pet_room(p_owner uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when h.pet_id is null then null else jsonb_build_object('id', h.pet_id, 'out', h.pet_out, 'nick', p.nickname, 'name', s.pet_name, 'adult', coalesce(p.affinity, 0) >= 100, 'affinity', p.affinity) end
    from public.world_housing h left join public.world_pets p on p.owner_id = h.owner_id and p.pet_id = h.pet_id left join public.world_pet_species s on s.pet_id = h.pet_id
   where h.owner_id = p_owner
$$;

-- 별채 보기에 동무를 함께 싣는다
select pg_temp.yh_patch('public.world_housing_snapshot(uuid)', '''pet_id'', h.pet_id, ''pet_out'', h.pet_out,', '''pet_id'', h.pet_id, ''pet_out'', h.pet_out, ''pet'', public.world_pet_room(own),
    ''pet_today'', case when h.pet_id is not null and role is null then (select jsonb_build_object(''pat'', g.pat, ''play'', g.play) from public.world_pet_guest g where g.owner_id = own and g.visitor_id = uid and g.day = today) end,');

-- 기록 보상: 퀘스트·칭호·외전으로 오는 동무
create or replace function public.world_pet_quest_trg() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.done_at is not null and (tg_op = 'INSERT' or old.done_at is null) and exists (select 1 from public.world_pet_sources where source = 'quest:' || new.quest_id) then
    perform public.world_pet_grant_source(new.owner_id, 'quest:' || new.quest_id);
  end if;
  return new;
end $$;
drop trigger if exists trg_world_pet_quest on public.world_quest_progress;
create trigger trg_world_pet_quest after insert or update of done_at on public.world_quest_progress for each row execute function public.world_pet_quest_trg();
select pg_temp.yh_patch('public.world_housing_title_trg()', '  return new;', '  if exists (select 1 from public.world_pet_sources where source = ''title:'' || new.title_key) then
    perform public.world_pet_grant_source(new.owner_id, ''title:'' || new.title_key);
  end if;
  return new;');
select pg_temp.yh_patch('public.world_housing_event_trg()', '    perform public.world_housing_grant_once(new.actor_id, ''gw_first'', ''귀허의 주인 첫 처치'');',
  '    perform public.world_housing_grant_once(new.actor_id, ''gw_first'', ''귀허의 주인 첫 처치'');
    perform public.world_pet_grant_source(new.actor_id, ''gw_first'');');

-- 탐색 희귀 결과 「알 줍기」: 탐색 한 번에 얼룩무늬 알 0.5%·빛나는 알 0.06%(희귀 전리품과 같은 길로 가방에 넣는다)
select pg_temp.yh_patch('public.world_event_char_apply()', '  if hp_tick = 0 and mn_tick = 0 and tok = 0',
'  if k = ''explore'' and p ->> ''kind'' = ''field_search'' and rare is null then
    rare := case when random() < 0.0006 then ''pet_egg_3'' when random() < 0.005 then ''pet_egg_2'' end;
  end if;
  if hp_tick = 0 and mn_tick = 0 and tok = 0');
-- 동무 주먹밥은 상점에 늘 나온다
select pg_temp.yh_patch('public.world_shop_refresh(text)', '''ammo_dart''];', '''ammo_dart'', ''pet_food''];');

-- 조사원 카드: 별채가 있는지·데리고 다니는 동무
select pg_temp.yh_patch('public.world_character_card(uuid)', '''faction_rank'', public.world_faction_rank_label(c.owner_id),',
  '''faction_rank'', public.world_faction_rank_label(c.owner_id),
    ''housing'', exists (select 1 from public.world_housing hh where hh.owner_id = c.owner_id),
    ''pet'', (select public.world_pet_room(c.owner_id) from public.world_housing hh where hh.owner_id = c.owner_id and hh.pet_out),');

-- 칭호·꾸미기 규칙 'home'(별채·꼬마 동무)
create or replace function public.world_home_rule_count(p_owner uuid, p_rule jsonb) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(case p_rule ->> 'home'
    when 'open' then (select count(*) from public.world_housing where owner_id = p_owner)
    when 'size' then (select max(size) from public.world_housing where owner_id = p_owner)
    when 'visits' then (select max(visits_total) from public.world_housing where owner_id = p_owner)
    when 'guest' then (select count(distinct writer_id) from public.world_housing_guestbook where owner_id = p_owner and writer_id <> p_owner)
    when 'furn' then public.world_housing_owned_kinds(p_owner)
    when 'pets' then (select count(*) from public.world_pets where owner_id = p_owner)
    when 'adult' then (select count(*) from public.world_pets where owner_id = p_owner and affinity >= 100)
    when 'pet_grade' then (select count(*) from public.world_pets p join public.world_pet_species s using (pet_id) where p.owner_id = p_owner and s.grade >= coalesce((p_rule ->> 'g')::int, 5))
  end, 0)
$$;
revoke all on function public.world_home_rule_count(uuid, jsonb) from public, anon, authenticated;
do $$ declare o text; begin
  foreach o in array array[(select pg_get_userbyid(proowner) from pg_proc where oid = 'public.world_title_rule_ok(uuid,jsonb)'::regprocedure),
                           (select pg_get_userbyid(proowner) from pg_proc where oid = 'public.world_title_rule_progress(uuid,jsonb)'::regprocedure),
                           (select pg_get_userbyid(proowner) from pg_proc where oid = 'public.world_cosmetic_award_check(uuid,text)'::regprocedure)] loop
    execute format('grant execute on function public.world_home_rule_count(uuid, jsonb), public.world_housing_owned_kinds(uuid) to %I', o);
    execute format('grant select on public.world_housing, public.world_housing_guestbook, public.world_housing_store, public.world_pets, public.world_pet_species to %I', o);
  end loop;
end $$;
select pg_temp.yh_patch('public.world_title_rule_ok(uuid,jsonb)', 'ELSIF p_rule ? ''tourney'' THEN RETURN',
  'ELSIF p_rule ? ''home'' THEN RETURN public.world_home_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? ''tourney'' THEN RETURN');
select pg_temp.yh_patch('public.world_title_rule_progress(uuid,jsonb)', 'elsif p_rule ? ''tourney'' then', 'elsif p_rule ? ''home'' then v := public.world_home_rule_count(p_owner, p_rule);
  elsif p_rule ? ''tourney'' then');
select pg_temp.yh_patch('public.world_title_award_check(uuid,text)', 'IF r ? ''tourney'' AND p_event_type IS NOT NULL AND p_event_type <> ''tourney'' THEN CONTINUE; END IF;',
  'IF r ? ''tourney'' AND p_event_type IS NOT NULL AND p_event_type <> ''tourney'' THEN CONTINUE; END IF; IF r ? ''home'' AND p_event_type IS NOT NULL AND p_event_type <> ''home'' THEN CONTINUE; END IF;');
-- 별채 쪽 행동 뒤에도 판정한다(열기·넓히기·저장·발걸음·방명록)
select pg_temp.yh_patch('public.world_housing_open(uuid)', '    insert into public.world_housing_store(owner_id) values (p_owner) on conflict (owner_id) do nothing;',
  '    insert into public.world_housing_store(owner_id) values (p_owner) on conflict (owner_id) do nothing;
    perform public.world_title_award_check(p_owner, ''home'');');
select pg_temp.yh_patch('public.world_housing_expand()', '  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, ''housing_expand''',
  '  perform public.world_title_award_check(uid, ''home'');
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, ''housing_expand''');
select pg_temp.yh_patch('public.world_housing_save(uuid,jsonb)', '  return public.world_housing_snapshot(own);',
  '  perform public.world_title_award_check(own, ''home'');
  return public.world_housing_snapshot(own);');
select pg_temp.yh_patch('public.world_housing_snapshot(uuid)', '       where owner_id = own returning * into h;',
  '       where owner_id = own returning * into h;
      if h.visits_total in (10, 50, 100, 300) then perform public.world_title_award_check(own, ''home''); end if;');
select pg_temp.yh_patch('public.world_housing_guest_write(uuid,text)', '  if uid <> p_owner then', '  if uid <> p_owner then
    perform public.world_title_award_check(p_owner, ''home'');');
select pg_temp.yh_patch('public.world_housing_grant(uuid,text,integer,text,boolean)', '  update public.world_housing_store set items = public.world_inv_add(items, p_item, n), updated_at = now() where owner_id = p_owner;',
  '  update public.world_housing_store set items = public.world_inv_add(items, p_item, n), updated_at = now() where owner_id = p_owner;
  perform public.world_title_award_check(p_owner, ''home'');');


-- ─── 꼬마 동무 30종 · 바구니·알·먹이 ───
insert into public.world_pet_species(pet_id, pet_name, grade, kind, likes, how, sort, egg)
select x.pet_id, x.pet_name, x.grade, x.kind, x.likes, x.how, x.sort, x.egg from jsonb_to_recordset($J$[{"pet_id":"nureong_puppy","pet_name":"누렁 강아지","grade":1,"kind":"ward","likes":"treat_meat","how":"안전지대 상점의 바구니","sort":0,"egg":false},{"pet_id":"spotted_cat","pet_name":"얼룩 고양이","grade":1,"kind":"shadow","likes":"treat_fish","how":"안전지대 상점의 바구니","sort":1,"egg":false},{"pet_id":"magpie","pet_name":"까치","grade":1,"kind":"bird","likes":"treat_meat","how":"안전지대 상점의 바구니","sort":2,"egg":false},{"pet_id":"sparrow","pet_name":"참새","grade":1,"kind":"bird","likes":"treat_rice","how":"안전지대 상점의 바구니","sort":3,"egg":false},{"pet_id":"squirrel","pet_name":"다람쥐","grade":1,"kind":"wood","likes":"treat_honey","how":"안전지대 상점의 바구니","sort":4,"egg":false},{"pet_id":"white_rabbit","pet_name":"흰 토끼","grade":1,"kind":"wood","likes":"treat_herb","how":"안전지대 상점의 바구니","sort":5,"egg":false},{"pet_id":"baby_turtle","pet_name":"새끼 거북","grade":1,"kind":"shell","likes":"treat_herb","how":"안전지대 상점의 바구니","sort":6,"egg":false},{"pet_id":"goldfish","pet_name":"금붕어","grade":1,"kind":"water","likes":"treat_rice","how":"안전지대 상점의 바구니","sort":7,"egg":false},{"pet_id":"ink_cat","pet_name":"먹물 고양이","grade":3,"kind":"shadow","likes":"treat_fish","how":"퀘스트 「빈 명부의 마지막 줄」을(를) 마친다 · 빛나는 알","sort":8,"egg":true},{"pet_id":"baby_crow","pet_name":"아기 까마귀","grade":2,"kind":"bird","likes":"treat_rice","how":"탐색 중 「얼룩무늬 알」","sort":9,"egg":true},{"pet_id":"dokkaebi_fire","pet_name":"도깨비불","grade":2,"kind":"ghost","likes":"treat_rice","how":"탐색 중 「얼룩무늬 알」","sort":10,"egg":true},{"pet_id":"little_raccoon","pet_name":"꼬마 너구리","grade":2,"kind":"shadow","likes":"treat_fish","how":"탐색 중 「얼룩무늬 알」","sort":11,"egg":true},{"pet_id":"baby_crane","pet_name":"아기 학","grade":2,"kind":"sky","likes":"treat_fish","how":"탐색 중 「얼룩무늬 알」","sort":12,"egg":true},{"pet_id":"baby_otter","pet_name":"새끼 수달","grade":2,"kind":"water","likes":"treat_fish","how":"탐색 중 「얼룩무늬 알」","sort":13,"egg":true},{"pet_id":"baby_owl","pet_name":"아기 부엉이","grade":2,"kind":"bird","likes":"treat_meat","how":"탐색 중 「얼룩무늬 알」","sort":14,"egg":true},{"pet_id":"little_toad","pet_name":"꼬마 두꺼비","grade":2,"kind":"venom","likes":"treat_meat","how":"탐색 중 「얼룩무늬 알」","sort":15,"egg":true},{"pet_id":"firefly_spirit","pet_name":"반딧불 정령","grade":2,"kind":"swarm","likes":"treat_honey","how":"탐색 중 「얼룩무늬 알」","sort":16,"egg":true},{"pet_id":"baby_gumiho","pet_name":"새끼 구미호","grade":3,"kind":"mirror","likes":"treat_meat","how":"퀘스트 「지지 않는 단풍」을(를) 마친다 · 빛나는 알","sort":17,"egg":true},{"pet_id":"baby_haetae","pet_name":"아기 해태","grade":3,"kind":"ward","likes":"treat_rice","how":"퀘스트 「잔도 위의 목탁」을(를) 마친다 · 빛나는 알","sort":18,"egg":true},{"pet_id":"bead_imugi","pet_name":"구슬 이무기","grade":3,"kind":"water","likes":"treat_honey","how":"퀘스트 「수궁 문지기 교대」을(를) 마친다 · 빛나는 알","sort":19,"egg":true},{"pet_id":"baby_sangun","pet_name":"아기 산군","grade":3,"kind":"breaker","likes":"treat_meat","how":"퀘스트 「벼락이 굳힌 핵」을(를) 마친다 · 빛나는 알","sort":20,"egg":true},{"pet_id":"moon_rabbit","pet_name":"달토끼","grade":3,"kind":"sky","likes":"treat_rice","how":"퀘스트 「달빛 끓이는 밤」을(를) 마친다 · 빛나는 알","sort":21,"egg":true},{"pet_id":"wooden_doll","pet_name":"목각 인형 정령","grade":3,"kind":"wood","likes":"treat_honey","how":"퀘스트 「꺼진 등대에 다시 불을」을(를) 마친다 · 빛나는 알","sort":22,"egg":true},{"pet_id":"baby_bulgasari","pet_name":"아기 불가사리","grade":4,"kind":"giant","likes":"treat_rice","how":"칭호 「공방의 주인」을(를) 얻는다","sort":23,"egg":false},{"pet_id":"samjogo_chick","pet_name":"삼족오 새끼","grade":4,"kind":"sky","likes":"treat_honey","how":"퀘스트 「내려오지 않은 별지기」을(를) 마친다","sort":24,"egg":false},{"pet_id":"baby_girin","pet_name":"아기 기린","grade":4,"kind":"sky","likes":"treat_herb","how":"퀘스트 「마흔 해 깨어 있던 눈」을(를) 마친다","sort":25,"egg":false},{"pet_id":"little_cheongryong","pet_name":"꼬마 청룡","grade":4,"kind":"water","likes":"treat_fish","how":"퀘스트 「거꾸로 떠도는 선원들」을(를) 마친다","sort":26,"egg":false},{"pet_id":"little_jangseung","pet_name":"꼬마 장승","grade":4,"kind":"ward","likes":"treat_herb","how":"퀘스트 「다시 감기는 사슬」을(를) 마친다","sort":27,"egg":false},{"pet_id":"baby_baektaek","pet_name":"아기 백택","grade":5,"kind":"ward","likes":"treat_herb","how":"칭호 「만귀보」을(를) 얻는다","sort":28,"egg":false},{"pet_id":"gwiheo_butterfly","pet_name":"귀허 나비","grade":5,"kind":"ghost","likes":"treat_honey","how":"귀허의 주인을 처음 쓰러뜨린다","sort":29,"egg":false}]$J$::jsonb) as x(pet_id text, pet_name text, grade int, kind text, likes text, how text, sort int, egg boolean)
on conflict (pet_id) do update set pet_name = excluded.pet_name, grade = excluded.grade, kind = excluded.kind, likes = excluded.likes, how = excluded.how, sort = excluded.sort, egg = excluded.egg;
delete from public.world_pet_sources;
insert into public.world_pet_sources(source, pet_id) select x.source, x.pet_id from jsonb_to_recordset($J$[{"source":"quest:sq_black_sand_temple_2","pet_id":"ink_cat"},{"source":"quest:sq_red_forest_2","pet_id":"baby_gumiho"},{"source":"quest:sq_iron_monastery_1","pet_id":"baby_haetae"},{"source":"quest:sq_sunken_palace_1","pet_id":"bead_imugi"},{"source":"quest:sq_thunder_peak_1","pet_id":"baby_sangun"},{"source":"quest:sq_red_moon_fort_2","pet_id":"moon_rabbit"},{"source":"quest:sq_nine_lighthouse_1","pet_id":"wooden_doll"},{"source":"title:craft_200","pet_id":"baby_bulgasari"},{"source":"quest:sq_star_observatory_2","pet_id":"samjogo_chick"},{"source":"quest:sq_white_tower_2","pet_id":"baby_girin"},{"source":"quest:sq_black_tide_rift_2","pet_id":"little_cheongryong"},{"source":"quest:sq_sealed_abyss_1","pet_id":"little_jangseung"},{"source":"title:codex_100","pet_id":"baby_baektaek"},{"source":"gw_first","pet_id":"gwiheo_butterfly"}]$J$::jsonb) as x(source text, pet_id text);
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
select x.item_id, x.item_name, x.category, x.tier, x.description, x.stack_size > 1, '{}'::jsonb, 1, x.equipment_traits, x.tradeable, x.reference_price, x.stack_size
  from jsonb_to_recordset($J$[{"item_id":"pt_nureong_puppy","item_name":"누렁 강아지 바구니","tier":1,"description":"마을 어귀마다 한 마리씩은 있는 누런 강아지입니다. 낯선 기척이 나면 제일 먼저 짖어 알려 줍니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).","equipment_traits":{"pet":"nureong_puppy"},"tradeable":true,"reference_price":300,"stack_size":1,"category":"pet"},{"item_id":"pt_spotted_cat","item_name":"얼룩 고양이 바구니","tier":1,"description":"세 빛깔 얼룩이 박힌 고양이입니다. 볕 드는 자리를 귀신같이 찾아내 낮잠을 잡니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).","equipment_traits":{"pet":"spotted_cat"},"tradeable":true,"reference_price":300,"stack_size":1,"category":"pet"},{"item_id":"pt_magpie","item_name":"까치 바구니","tier":1,"description":"반가운 손님이 온다고 먼저 울어 주는 새입니다. 반짝이는 것을 보면 꼭 한 번 쪼아 봅니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).","equipment_traits":{"pet":"magpie"},"tradeable":true,"reference_price":300,"stack_size":1,"category":"pet"},{"item_id":"pt_sparrow","item_name":"참새 바구니","tier":1,"description":"처마 밑에서 짹짹거리며 낟알을 줍는 작은 새입니다. 겁이 많아 쓰다듬으면 몸을 동그랗게 부풀립니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).","equipment_traits":{"pet":"sparrow"},"tradeable":true,"reference_price":300,"stack_size":1,"category":"pet"},{"item_id":"pt_squirrel","item_name":"다람쥐 바구니","tier":1,"description":"볼주머니가 터지도록 먹이를 모아 두는 다람쥐입니다. 숨겨 둔 곳은 금세 잊어버립니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).","equipment_traits":{"pet":"squirrel"},"tradeable":true,"reference_price":300,"stack_size":1,"category":"pet"},{"item_id":"pt_white_rabbit","item_name":"흰 토끼 바구니","tier":1,"description":"눈처럼 하얀 털에 빨간 눈을 가진 토끼입니다. 기분이 좋으면 제자리에서 폴짝 뜁니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).","equipment_traits":{"pet":"white_rabbit"},"tradeable":true,"reference_price":300,"stack_size":1,"category":"pet"},{"item_id":"pt_baby_turtle","item_name":"새끼 거북 바구니","tier":1,"description":"등딱지가 손바닥만 한 거북입니다. 느릿느릿 걷다가도 먹이 소리에는 고개를 번쩍 듭니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).","equipment_traits":{"pet":"baby_turtle"},"tradeable":true,"reference_price":300,"stack_size":1,"category":"pet"},{"item_id":"pt_goldfish","item_name":"금붕어 바구니","tier":1,"description":"동그란 어항 속에서 사는 금붕어입니다. 손가락을 대면 졸졸 따라 헤엄칩니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).","equipment_traits":{"pet":"goldfish"},"tradeable":true,"reference_price":300,"stack_size":1,"category":"pet"},{"item_id":"pet_egg_2","item_name":"얼룩무늬 알","tier":2,"description":"탐색하다 주운 따뜻한 알. 쓰면 아직 만나지 못한 양품 꼬마 동무가 태어난다.","equipment_traits":{"egg":2},"tradeable":true,"reference_price":400,"stack_size":5,"category":"pet"},{"item_id":"pet_egg_3","item_name":"빛나는 알","tier":3,"description":"안쪽에서 은은한 빛이 새는 알. 쓰면 아직 만나지 못한 진품 꼬마 동무가 태어난다.","equipment_traits":{"egg":3},"tradeable":true,"reference_price":1500,"stack_size":5,"category":"pet"},{"item_id":"pet_food","item_name":"동무 주먹밥","tier":1,"description":"꼬마 동무가 먹는 작은 주먹밥. 별채에서 먹이면 친밀도가 오른다.","equipment_traits":{"pet_food":true},"tradeable":true,"reference_price":10,"stack_size":20,"category":"consumable"},{"item_id":"treat_fish","item_name":"말린 생선포","tier":1,"description":"꼬마 동무 별미. 생선을 좋아하는 동무가 반긴다.","equipment_traits":{"pet_food":true},"tradeable":true,"reference_price":30,"stack_size":20,"category":"consumable"},{"item_id":"treat_rice","item_name":"쌀 강정","tier":1,"description":"꼬마 동무 별미. 곡식을 좋아하는 동무가 반긴다.","equipment_traits":{"pet_food":true},"tradeable":true,"reference_price":30,"stack_size":20,"category":"consumable"},{"item_id":"treat_honey","item_name":"꿀 약과","tier":1,"description":"꼬마 동무 별미. 단것을 좋아하는 동무가 반긴다.","equipment_traits":{"pet_food":true},"tradeable":true,"reference_price":50,"stack_size":20,"category":"consumable"},{"item_id":"treat_herb","item_name":"향긋한 풀단","tier":1,"description":"꼬마 동무 별미. 풀과 잎을 좋아하는 동무가 반긴다.","equipment_traits":{"pet_food":true},"tradeable":true,"reference_price":30,"stack_size":20,"category":"consumable"},{"item_id":"treat_meat","item_name":"육포 조각","tier":1,"description":"꼬마 동무 별미. 고기를 좋아하는 동무가 반긴다.","equipment_traits":{"pet_food":true},"tradeable":true,"reference_price":40,"stack_size":20,"category":"consumable"}]$J$::jsonb) as x(item_id text, item_name text, category text, tier int, description text, equipment_traits jsonb, tradeable boolean, reference_price int, stack_size int)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;
-- 상점: 주먹밥·별미 다섯은 모든 상점, 범품 바구니는 상점마다 두 가지씩
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, f.item_id, f.price, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join jsonb_to_recordset($J$[{"item_id":"pet_food","price":10},{"item_id":"treat_fish","price":30},{"item_id":"treat_rice","price":30},{"item_id":"treat_honey","price":50},{"item_id":"treat_herb","price":30},{"item_id":"treat_meat","price":40}]$J$::jsonb) as f(item_id text, price int)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, x.item_id, 300, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join lateral (select y.item_id from jsonb_array_elements_text($J$["pt_nureong_puppy","pt_spotted_cat","pt_magpie","pt_sparrow","pt_squirrel","pt_white_rabbit","pt_baby_turtle","pt_goldfish"]$J$::jsonb) as y(item_id) order by md5(s.shop_id || y.item_id) limit 2) x
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;
-- 요리: 말린 생선포(손질한 생선 2 → 3개)
insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, required_job, recipe_difficulty, required_skill, required_skill_rank, craft_field)
values ('r_treat_fish', '말린 생선포 만들기', 'treat_fish', 3, '{"fish_fillet": 2}'::jsonb, null, 1, null, '손질한 생선을 말려 꼬마 동무 별미를 만든다.', 1, null, 1, null, 1, '요리')
on conflict (recipe_id) do update set ingredients = excluded.ingredients, output_qty = excluded.output_qty;
-- 칭호(효과 없음)·꾸미기: 별채·꼬마 동무
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade)
select x.k, x.n, x.i, x.d, x.c, '{}'::jsonb, true, x.h, x.r, 1400 + x.o, '별채', x.g
  from jsonb_to_recordset($J$[{"k":"hs_open","n":"별채 주인","i":"home","d":"본부 객사 뒤뜰의 별채를 얻었다.","c":"「객사 별채」를 마쳐 별채를 얻는다","r":{"home":"open","n":1},"g":1,"h":false,"o":0},{"k":"hs_visit50","n":"발걸음이 잦은 집","i":"home","d":"별채 문턱을 넘은 발걸음이 쉰을 넘었다.","c":"별채 발걸음 50","r":{"home":"visits","n":50},"g":2,"h":false,"o":1},{"k":"hs_guest20","n":"스무 손님의 방명록","i":"home","d":"스무 사람이 별채 방명록에 이름을 남겼다.","c":"서로 다른 손님 20명이 방명록을 남긴다","r":{"home":"guest","n":20},"g":3,"h":false,"o":2},{"k":"hs_size9","n":"아홉 칸 별채","i":"home","d":"별채를 가장 넓게 넓혔다.","c":"별채를 9×9로 넓힌다","r":{"home":"size","n":9},"g":3,"h":false,"o":3},{"k":"hs_furn30","n":"가구 수집가","i":"home","d":"서른 가지 가구를 모았다.","c":"가구 30가지를 모은다","r":{"home":"furn","n":30},"g":3,"h":false,"o":4},{"k":"hs_visit300","n":"문턱이 닳은 집","i":"home","d":"별채 문턱이 반들반들 닳았다.","c":"별채 발걸음 300","r":{"home":"visits","n":300},"g":4,"h":false,"o":5},{"k":"hs_furn60","n":"별채의 장인","i":"home","d":"야행국의 가구를 거의 다 모았다.","c":"가구 60가지를 모은다","r":{"home":"furn","n":60},"g":5,"h":true,"o":6},{"k":"pet_5","n":"동무 다섯","i":"heart","d":"꼬마 동무 다섯과 함께한다.","c":"꼬마 동무 5마리를 모은다","r":{"home":"pets","n":5},"g":2,"h":false,"o":7},{"k":"pet_adult5","n":"잘 키운 동무들","i":"heart","d":"꼬마 동무 다섯을 다 자라게 했다.","c":"꼬마 동무 5마리를 다 자라게 한다","r":{"home":"adult","n":5},"g":3,"h":false,"o":8},{"k":"pet_15","n":"동무 열다섯","i":"heart","d":"꼬마 동무 열다섯과 함께한다.","c":"꼬마 동무 15마리를 모은다","r":{"home":"pets","n":15},"g":3,"h":false,"o":9},{"k":"pet_legend","n":"상서로운 짐승의 벗","i":"heart","d":"신품 꼬마 동무와 벗이 되었다.","c":"신품 꼬마 동무를 얻는다","r":{"home":"pet_grade","g":5,"n":1},"g":5,"h":false,"o":10},{"k":"pet_30","n":"모든 동무의 벗","i":"heart","d":"야행국의 꼬마 동무 서른을 모두 만났다.","c":"꼬마 동무 30마리를 모두 모은다","r":{"home":"pets","n":30},"g":5,"h":true,"o":11}]$J$::jsonb) as x(k text, n text, i text, d text, c text, r jsonb, g int, h boolean, o int)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, rule = excluded.rule,
  category = excluded.category, grade = excluded.grade, hidden = excluded.hidden, bonus = excluded.bonus;
insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort)
select x.k, x.kind, x.t, x.n, x.c, '별채', x.r, false, true, 1400 + x.o
  from jsonb_to_recordset($J$[{"k":"fr_home","kind":"frame","t":"legend","n":"처마 끝 테","c":"가구 20가지를 모은다","r":{"home":"furn","n":20},"o":0},{"k":"pt_home","kind":"pattern","t":"rare","n":"단청 무늬","c":"별채를 8×8로 넓힌다","r":{"home":"size","n":8},"o":1},{"k":"sl_dong","kind":"seal","t":"rare","n":"낙관 「同」","c":"꼬마 동무 10마리를 모은다","r":{"home":"pets","n":10},"o":2}]$J$::jsonb) as x(k text, kind text, t text, n text, c text, r jsonb, o int)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, category = excluded.category;


-- 알림 설정에 「별채」 갈래(발걸음·방명록·가구·손님이 동무와 놀아 줌)
select pg_temp.yh_patch('public.world_notify_prefs_set(text[])', '''faction'', ''raid'')', '''faction'', ''raid'', ''housing'')');

-- ─────────────────────────────────────────────────────────────
-- 함수 주인·권한: 행동 함수는 fn_owner_field가 갖고, 화면이 부르는 것만 authenticated에 연다
-- ─────────────────────────────────────────────────────────────
do $$ declare fn text; begin
  foreach fn in array array['world_housing_married(uuid,uuid)', 'world_housing_blocked(uuid,uuid)', 'world_housing_friends(uuid,uuid)', 'world_housing_can_view(uuid,uuid,text)',
    'world_housing_edit_block(uuid)', 'world_housing_grant(uuid,text,integer,text,boolean)', 'world_housing_grant_once(uuid,text,text)', 'world_housing_roll(uuid,text,numeric,text)',
    'world_housing_event_trg()', 'world_housing_title_trg()', 'world_housing_raid_trg()', 'world_housing_open(uuid)', 'world_housing_quest_trg()', 'world_housing_snapshot(uuid)',
    'world_housing_save(uuid,jsonb)', 'world_housing_store_move(text,integer,text)', 'world_housing_expand()', 'world_housing_gate(text)', 'world_housing_guest_write(uuid,text)',
    'world_housing_guest_delete(bigint)', 'world_housing_owned_kinds(uuid)',
    'world_pet_grant(uuid,text,text,boolean)', 'world_pet_grant_source(uuid,text)', 'world_pet_adopt(text)', 'world_pet_nickname(text,text)', 'world_pet_place(text)',
    'world_pet_walk(boolean)', 'world_pet_act(uuid,text,text)', 'world_pet_snapshot()', 'world_pet_room(uuid)', 'world_pet_quest_trg()', 'world_home_rule_count(uuid,jsonb)'] loop
    execute format('alter function public.%s owner to fn_owner_field', fn);
  end loop;
end $$;
revoke all on function public.world_housing_cap(int), public.world_housing_store_cap(int), public.world_housing_kind_cap(int), public.world_housing_item(text, text),
  public.world_housing_today(), public.world_housing_counts(jsonb, jsonb, text, text), public.world_housing_store_count(jsonb), public.world_housing_default_set() from public, anon, authenticated;
grant execute on function public.world_housing_cap(int), public.world_housing_store_cap(int), public.world_housing_kind_cap(int), public.world_housing_item(text, text),
  public.world_housing_today(), public.world_housing_counts(jsonb, jsonb, text, text), public.world_housing_store_count(jsonb), public.world_housing_default_set() to fn_owner_field;
do $$ begin
  set role fn_owner_field;
  revoke all on function public.world_housing_married(uuid, uuid), public.world_housing_blocked(uuid, uuid), public.world_housing_friends(uuid, uuid), public.world_housing_can_view(uuid, uuid, text),
    public.world_housing_edit_block(uuid), public.world_housing_grant(uuid, text, integer, text, boolean), public.world_housing_grant_once(uuid, text, text), public.world_housing_roll(uuid, text, numeric, text),
    public.world_housing_event_trg(), public.world_housing_title_trg(), public.world_housing_raid_trg(), public.world_housing_open(uuid), public.world_housing_quest_trg(), public.world_housing_owned_kinds(uuid),
    public.world_pet_grant(uuid, text, text, boolean), public.world_pet_grant_source(uuid, text), public.world_pet_room(uuid), public.world_pet_quest_trg(), public.world_home_rule_count(uuid, jsonb)
    from public, anon, authenticated;
  revoke all on function public.world_housing_snapshot(uuid), public.world_housing_save(uuid, jsonb), public.world_housing_store_move(text, integer, text), public.world_housing_expand(),
    public.world_housing_gate(text), public.world_housing_guest_write(uuid, text), public.world_housing_guest_delete(bigint),
    public.world_pet_adopt(text), public.world_pet_nickname(text, text), public.world_pet_place(text), public.world_pet_walk(boolean), public.world_pet_act(uuid, text, text), public.world_pet_snapshot()
    from public, anon;
  grant execute on function public.world_housing_snapshot(uuid), public.world_housing_save(uuid, jsonb), public.world_housing_store_move(text, integer, text), public.world_housing_expand(),
    public.world_housing_gate(text), public.world_housing_guest_write(uuid, text), public.world_housing_guest_delete(bigint),
    public.world_pet_adopt(text), public.world_pet_nickname(text, text), public.world_pet_place(text), public.world_pet_walk(boolean), public.world_pet_act(uuid, text, text), public.world_pet_snapshot()
    to authenticated;
  reset role;
end $$;

-- ─────────────────────────────────────────────────────────────
-- 소급: 7.2 전에 이미 마친 이야기 장·칭호·결전·외전·퀘스트 → 가구는 곳간, 동무는 도감(알림이 간다)
-- ─────────────────────────────────────────────────────────────
do $$ declare r record; begin
  for r in select distinct e.actor_id uid, 'chapter:' || (e.payload ->> 'chapter_id') src from public.world_events e
            where e.event_type = 'story' and e.payload ? 'chapter_id' and e.actor_id is not null
              and exists (select 1 from public.world_furniture_sources f where f.source = 'chapter:' || (e.payload ->> 'chapter_id'))
              and exists (select 1 from public.world_characters c where c.owner_id = e.actor_id) loop
    perform public.world_housing_grant_once(r.uid, r.src, '이야기 장 보상');
  end loop;
  for r in select distinct t.owner_id uid, f.source src from public.world_character_titles t
             join public.world_furniture_sources f on f.source = 'title:' || t.title_key
                  or (f.source = 'raid_final' and t.title_key = 'final_clear') or (f.source = 'gw_first' and t.title_key = 'gw_kill1') loop
    perform public.world_housing_grant_once(r.uid, r.src, '지난 기록 보상');
  end loop;
  for r in select distinct g.owner_id uid, s.source src from public.world_quest_progress g join public.world_pet_sources s on s.source = 'quest:' || g.quest_id where g.done_at is not null
           union select distinct t.owner_id, s.source from public.world_character_titles t join public.world_pet_sources s on s.source = 'title:' || t.title_key or (s.source = 'gw_first' and t.title_key = 'gw_kill1') loop
    perform public.world_pet_grant_source(r.uid, r.src);
  end loop;
end $$;


insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261103000000', now())
  on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

