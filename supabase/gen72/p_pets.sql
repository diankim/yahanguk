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
      values (p_owner, 'pet_new', '꼬마 동무 · ' || nm, public.world_josa(nm, '이', '가') || ' 동무가 되었습니다. 캐릭터 › 별채에서 만날 수 있습니다.', jsonb_build_object('pet_id', p_pet));
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
    'content', case when pid = it.equipment_traits ->> 'pet' then public.world_josa(sp.pet_name, '이', '가') || ' 바구니에서 고개를 내밀었습니다.'
                    else '알이 갈라지고 ' || public.world_josa(sp.pet_name, '이', '가') || ' 태어났습니다!' end);
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
    if (p_act = 'pat' and g.pat) or (p_act = 'play' and g.play) then raise exception '오늘은 이미 %. 내일 또 와 주세요.', case when p_act = 'pat' then '쓰다듬어 주었습니다' else '놀아 주었습니다' end; end if;
    update public.world_pet_guest set pat = pat or p_act = 'pat', play = play or p_act = 'play' where owner_id = p_owner and visitor_id = uid and day = today;
    gain := 1; react := case when p_act = 'play' then 'note' else 'heart' end;
    if not g.pat and not g.play then
      select character_name into vn from public.world_characters where owner_id = uid;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (p_owner, 'pet_play', '별채의 동무', vn || '님이 ' || case when p_act = 'pat' then public.world_josa(nm, '을', '를') || ' 쓰다듬어 주었습니다.' else public.world_josa(nm, '과', '와') || ' 놀아 주었습니다.' end, jsonb_build_object('visitor', uid));
    end if;
  end if;
  pt.affinity := least(300, pt.affinity + gain);
  update public.world_pets set affinity = pt.affinity, pat_day = pt.pat_day, pat_n = pt.pat_n, play_day = pt.play_day, play_n = pt.play_n, feed_day = pt.feed_day, feed_n = pt.feed_n
   where owner_id = p_owner and pet_id = h.pet_id;
  if not was_adult and pt.affinity >= 100 then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_owner, 'pet_new', '꼬마 동무가 자랐습니다', public.world_josa(nm, '이', '가') || ' 훌쩍 자랐습니다.', jsonb_build_object('pet_id', h.pet_id));
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
