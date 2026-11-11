create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

create or replace function public.world_feast_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object(
    'start', '12:30', 'min', 30, 'buff_h', 8, 'gap_s', 15, 'pet_max', 3, 'notify_min', 30, 'chat_min', 10,
    'feasts', jsonb_build_array(
      jsonb_build_object('dow', 1, 'faction', 'night_office', 'region', 'hq_yard', 'key', 'feast_lamp', 'name', '봉등례', 'hanja', '奉燈禮', 'desc', '명부 앞에 등을 올리는 정청의 의식', 'buff', '봉등의 가호', 'icon', 'flame', 'effects', jsonb_build_object('mental_loss_pct', -10, 'erosion_pct', -5)),
      jsonb_build_object('dow', 2, 'faction', 'red_moon_cult', 'region', 'bone_market', 'key', 'feast_redmoon', 'name', '적월제', 'hanja', '赤月祭', 'desc', '붉은 달 아래 맹세를 새로 하는 적월교의 제사', 'buff', '적월의 맹세', 'icon', 'spark', 'effects', jsonb_build_object('combat_damage_pct', 5)),
      jsonb_build_object('dow', 3, 'faction', 'black_lotus', 'region', 'hidden_bazaar', 'key', 'feast_ledger', 'name', '야장회', 'hanja', '夜帳會', 'desc', '흑련회가 장부를 맞추어 덮는 모임', 'buff', '장부의 셈', 'icon', 'mask', 'effects', jsonb_build_object('rare_loot_pct', 5)),
      jsonb_build_object('dow', 4, 'faction', 'north_league', 'region', 'iron_monastery', 'key', 'feast_snowlamp', 'name', '설등 공양', 'hanja', '雪燈供養', 'desc', '눈으로 빚은 등에 불을 넣어 올리는 북령맹의 공양', 'buff', '설등의 온기', 'icon', 'shield', 'effects', jsonb_build_object('incoming_damage_pct', -5)),
      jsonb_build_object('dow', 5, 'faction', 'river_alliance', 'region', 'river_ferry', 'key', 'feast_flowlamp', 'name', '유등회', 'hanja', '流燈會', 'desc', '물 위에 등을 띄워 보내는 수향연맹의 모임', 'buff', '유등의 물길', 'icon', 'leaf', 'effects', jsonb_build_object('travel_time_pct', -10)),
      jsonb_build_object('dow', 6, 'faction', 'southern_remnant', 'region', 'ember_village', 'key', 'feast_ember', 'name', '잔불제', 'hanja', '殘火祭', 'desc', '불씨를 손에서 손으로 나눠 잇는 남명회의 잔치', 'buff', '이어 받은 불씨', 'icon', 'flame', 'effects', jsonb_build_object('healing_pct', 10)),
      jsonb_build_object('dow', 7, 'faction', 'mandate_court', 'region', 'star_observatory', 'key', 'feast_star', 'name', '관성제', 'hanja', '觀星祭', 'desc', '별자리를 짚어 길을 묻는 천명원의 의식', 'buff', '관성의 점괘', 'icon', 'spark', 'effects', jsonb_build_object('clue_bonus_pct', 8, 'encounter_pct', -5))))
$function$;
grant execute on function public.world_feast_rules() to public;

insert into public.world_status_catalog(status_key, status_name, polarity, description, duration_minutes, effects, max_stacks, active, icon, cure)
select f ->> 'key', f ->> 'buff', 'positive', (f ->> 'name') || '에 함께한 기운이 남아 있습니다.', 480, f -> 'effects', 1, true, f ->> 'icon', '시간이 지나면 사라집니다.'
  from jsonb_array_elements(public.world_feast_rules() -> 'feasts') f
on conflict (status_key) do update set status_name = excluded.status_name, description = excluded.description, duration_minutes = excluded.duration_minutes, effects = excluded.effects, icon = excluded.icon;

create table if not exists public.world_feasts (
  feast_id uuid primary key default gen_random_uuid(),
  faction_key text not null,
  region_id text not null,
  day date not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'soon' check (status in ('soon', 'live', 'done')),
  told integer not null default 0,
  unique (faction_key, day));
create table if not exists public.world_feast_members (
  feast_id uuid not null references public.world_feasts(feast_id) on delete cascade,
  owner_id uuid not null,
  name text,
  joined_at timestamptz not null default now(),
  pets integer not null default 0,
  last_at timestamptz,
  primary key (feast_id, owner_id));
create index if not exists idx_world_feast_members_owner on public.world_feast_members(owner_id);
create table if not exists public.world_feast_lines (
  id bigserial primary key,
  feast_id uuid not null references public.world_feasts(feast_id) on delete cascade,
  at timestamptz not null default now(),
  kind text not null,
  text text not null);
create index if not exists idx_world_feast_lines_feast on public.world_feast_lines(feast_id, at);
alter table public.world_feasts enable row level security;
alter table public.world_feast_members enable row level security;
alter table public.world_feast_lines enable row level security;
revoke all on public.world_feasts, public.world_feast_members, public.world_feast_lines from anon, authenticated;
do $g$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' loop
    execute format('grant select, insert, update, delete on public.world_feasts, public.world_feast_members, public.world_feast_lines to %I', x);
    execute format('grant usage on sequence public.world_feast_lines_id_seq to %I', x);
  end loop;
end $g$;

create or replace function public.world_feast_script(p_key text)
 returns jsonb
 language sql
 immutable
as $function$
  select case p_key
    when 'feast_lamp' then jsonb_build_array(
      jsonb_build_object('s', 0, 'k', 'rite', 't', '정청 마당에 명부를 모신 단이 놓이고, 서리들이 등을 하나씩 들고 줄을 선다.'),
      jsonb_build_object('s', 420, 'k', 'host', 't', '주관 서리가 단 앞에 서서 말한다. 「적힌 이름은 잊히지 않습니다. 오늘도 이 등불이 그 이름들을 지킵니다.」'),
      jsonb_build_object('s', 1080, 'k', 'rite', 't', '모인 이들이 차례로 단 앞에 등을 올리자 마당이 환하게 밝아진다.'),
      jsonb_build_object('s', 1740, 'k', 'rite', 't', '마지막 등이 오르자 서리가 명부를 덮고 깊이 고개를 숙인다.'))
    when 'feast_redmoon' then jsonb_build_array(
      jsonb_build_object('s', 0, 'k', 'rite', 't', '백골 장터 한가운데 붉은 천을 두른 제단이 세워지고, 교도들이 횃불을 밝힌다.'),
      jsonb_build_object('s', 420, 'k', 'host', 't', '제사장이 붉은 잔을 높이 들고 외친다. 「붉은 달 아래 맺은 맹세는 피보다 진하다!」'),
      jsonb_build_object('s', 1080, 'k', 'rite', 't', '북소리가 빨라지자 모인 이들이 제단 둘레를 돌며 맹세의 말을 따라 외친다.'),
      jsonb_build_object('s', 1740, 'k', 'rite', 't', '제사장이 잔을 땅에 붓자 횃불이 한꺼번에 높이 치솟는다.'))
    when 'feast_ledger' then jsonb_build_array(
      jsonb_build_object('s', 0, 'k', 'rite', 't', '십삼문 암시장 안쪽 방에 검은 장부들이 펼쳐지고, 호칭으로만 불리는 이들이 자리를 잡는다.'),
      jsonb_build_object('s', 420, 'k', 'host', 't', '장부지기가 붓을 들며 말한다. 「오늘 맞춘 셈은 오늘 안에 덮습니다. 빠진 줄이 있으면 지금 말하시오.」'),
      jsonb_build_object('s', 1080, 'k', 'rite', 't', '주판알 튕기는 소리가 방 안을 메우고, 맞춘 장부가 한 권씩 쌓여 간다.'),
      jsonb_build_object('s', 1740, 'k', 'rite', 't', '마지막 장부가 덮이자 장부지기가 먹물 묻은 손을 털며 웃는다.'))
    when 'feast_snowlamp' then jsonb_build_array(
      jsonb_build_object('s', 0, 'k', 'rite', 't', '철벽 고찰 마당에 눈을 다져 만든 등이 줄지어 놓이고, 맹원들이 그 안에 촛불을 넣는다.'),
      jsonb_build_object('s', 420, 'k', 'host', 't', '노승이 합장하고 말한다. 「추위를 견딘 불은 쉽게 꺼지지 않습니다. 서로의 등을 지켜 주십시오.」'),
      jsonb_build_object('s', 1080, 'k', 'rite', 't', '바람이 불어도 눈등 안의 불은 흔들리기만 할 뿐 꺼지지 않는다.'),
      jsonb_build_object('s', 1740, 'k', 'rite', 't', '노승이 마지막 눈등에 불을 옮기자 고찰 마당 전체가 은은하게 빛난다.'))
    when 'feast_flowlamp' then jsonb_build_array(
      jsonb_build_object('s', 0, 'k', 'rite', 't', '구름나루 물가에 연꽃 모양 등이 쌓이고, 뱃사람들이 그 등을 하나씩 나누어 준다.'),
      jsonb_build_object('s', 420, 'k', 'host', 't', '나루지기가 첫 등을 물에 띄우며 말한다. 「물길이 이어지듯 우리 인연도 끊기지 않기를.」'),
      jsonb_build_object('s', 1080, 'k', 'rite', 't', '모인 이들이 띄운 등이 강물을 따라 길게 흘러가 물 위에 불빛의 길을 낸다.'),
      jsonb_build_object('s', 1740, 'k', 'rite', 't', '마지막 등이 굽이를 돌아 사라지자 나루지기가 뱃노래를 한 소절 부른다.'))
    when 'feast_ember' then jsonb_build_array(
      jsonb_build_object('s', 0, 'k', 'rite', 't', '잔불촌 한가운데 큰 화로에 불씨가 옮겨지고, 마을 사람들이 작은 화로를 들고 모여든다.'),
      jsonb_build_object('s', 420, 'k', 'host', 't', '촌장이 불씨를 집어 들며 말한다. 「꺼진 땅에서도 불은 이어집니다. 받은 불씨는 다음 사람에게 건네 주시오.」'),
      jsonb_build_object('s', 1080, 'k', 'rite', 't', '불씨가 손에서 손으로 건너가 마을 곳곳의 화로에 하나씩 불이 붙는다.'),
      jsonb_build_object('s', 1740, 'k', 'rite', 't', '마지막 화로에 불이 오르자 잿빛 하늘이 잠시 따뜻한 빛으로 물든다.'))
    when 'feast_star' then jsonb_build_array(
      jsonb_build_object('s', 0, 'k', 'rite', 't', '무극 관성대 꼭대기에서 혼천의가 돌아가고, 관원들이 별자리 그림을 펼친다.'),
      jsonb_build_object('s', 420, 'k', 'host', 't', '천문관이 하늘을 가리키며 말한다. 「낮에도 별은 제자리에 있습니다. 보이지 않는다고 길이 사라지지는 않습니다.」'),
      jsonb_build_object('s', 1080, 'k', 'rite', 't', '모인 이들이 차례로 혼천의 앞에 서서 제 별자리를 짚어 본다.'),
      jsonb_build_object('s', 1740, 'k', 'rite', 't', '천문관이 별자리 그림을 말아 들고 오늘의 점괘를 크게 읽는다.'))
    else '[]'::jsonb end
$function$;
grant execute on function public.world_feast_script(text) to public;

create or replace function public.world_pet_show(p_uid uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare r record; grp text; lines text[];
begin
  select coalesce(p.nickname, s.pet_name) nm, s.kind into r
    from public.world_pet_profile f join public.world_pets p on p.owner_id = f.owner_id and p.pet_id = f.pet_id
    join public.world_pet_species s on s.pet_id = f.pet_id where f.owner_id = p_uid;
  if not found then return null; end if;
  grp := case when r.kind in ('ward', 'shell', 'giant') then 'guard' when r.kind in ('shadow', 'breaker', 'wood') then 'bite' when r.kind in ('bird', 'sky') then 'peck' else 'charm' end;
  lines := case grp
    when 'guard' then array['이(가) 자리를 지키겠다는 듯 꼿꼿이 버티고 선다.', '이(가) 앞발을 모으고 사람들에게 꾸벅 인사한다.', '이(가) 의젓하게 앉아 모인 이들을 하나하나 둘러본다.']
    when 'bite' then array['이(가) 꼬리를 흔들며 사람들 발치를 빙글빙글 돈다.', '이(가) 신이 나서 폴짝폴짝 뛰어다닌다.', '이(가) 떨어진 떡 부스러기를 냉큼 주워 먹고 시치미를 뗀다.']
    when 'peck' then array['이(가) 날개를 파닥이며 사람들 머리 위를 한 바퀴 돈다.', '이(가) 누군가의 어깨에 내려앉아 고개를 갸웃거린다.', '이(가) 맑은 소리로 짧게 노래한다.']
    else array['이(가) 반짝이는 눈으로 사람들 사이를 오가며 재롱을 부린다.', '이(가) 빙그르르 돌며 춤추는 시늉을 한다.', '이(가) 가까이 있는 사람의 손바닥에 살며시 머리를 비빈다.'] end;
  return jsonb_build_object('name', r.nm, 'line', r.nm || lines[1 + floor(random() * array_length(lines, 1))::int]);
end $function$;
select pg_temp.yh_share('public.world_pet_show(uuid)');
select pg_temp.yh_own('public.world_pet_show(uuid)', 'fn_owner_field');

create or replace function public.world_feast_today(p_now timestamptz default now())
 returns jsonb
 language sql
 stable
 set search_path to ''
as $function$
  select f || jsonb_build_object(
      'day', (p_now at time zone 'Asia/Seoul')::date,
      'starts_at', ((p_now at time zone 'Asia/Seoul')::date + (r ->> 'start')::time) at time zone 'Asia/Seoul',
      'ends_at', ((p_now at time zone 'Asia/Seoul')::date + (r ->> 'start')::time + make_interval(mins => (r ->> 'min')::int)) at time zone 'Asia/Seoul',
      'place', (select g.region_name from public.world_map_regions g where g.region_id = f ->> 'region'))
    from (select public.world_feast_rules() r) x, jsonb_array_elements(x.r -> 'feasts') f
   where (f ->> 'dow')::int = extract(isodow from p_now at time zone 'Asia/Seoul')::int
$function$;
select pg_temp.yh_share('public.world_feast_today(timestamptz)');

create or replace function public.world_feast_tick()
 returns void
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare t jsonb := public.world_feast_today(); ru jsonb := public.world_feast_rules(); f public.world_feasts%rowtype; who uuid; m record; n int := 0; nm text;
begin
  if t is null then return; end if;
  if now() >= (t ->> 'starts_at')::timestamptz - make_interval(mins => (ru ->> 'notify_min')::int) and now() < (t ->> 'ends_at')::timestamptz then
    insert into public.world_feasts(faction_key, region_id, day, starts_at, ends_at)
    values (t ->> 'faction', t ->> 'region', (t ->> 'day')::date, (t ->> 'starts_at')::timestamptz, (t ->> 'ends_at')::timestamptz)
    on conflict (faction_key, day) do nothing;
  end if;
  select owner_id into who from public.world_staff order by owner_id limit 1;
  nm := (t ->> 'name') || '(' || (t ->> 'hanja') || ')';
  for f in select * from public.world_feasts where status <> 'done' order by starts_at for update skip locked loop
    if f.told < 1 and now() < f.starts_at then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      select c.owner_id, 'feast', nm, (ru ->> 'notify_min') || '분 뒤 ' || (t ->> 'place') || '에서 ' || nm || '이(가) 열립니다. 함께하고 끝날 때 그곳에 있으면 「' || (t ->> 'buff') || '」을(를) ' || (ru ->> 'buff_h') || '시간 동안 받습니다.', jsonb_build_object('feast', f.feast_id)
        from public.world_characters c where c.major_faction_id = f.faction_key and f.faction_key = t ->> 'faction';
      update public.world_feasts set told = 1 where feast_id = f.feast_id;
    end if;
    if f.told < 2 and now() >= f.starts_at - make_interval(mins => (ru ->> 'chat_min')::int) and now() < f.starts_at and who is not null then
      insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
      values ('global', who, '세력 소식', (ru ->> 'chat_min') || '분 뒤 ' || (t ->> 'place') || '에서 ' || nm || '이(가) 열립니다. 세력과 상관없이 누구나 함께할 수 있습니다.');
      update public.world_feasts set told = 2 where feast_id = f.feast_id;
    end if;
    if f.status = 'soon' and now() >= f.starts_at then
      update public.world_feasts set status = 'live', told = 3 where feast_id = f.feast_id;
      if who is not null then
        insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
        values ('global', who, '세력 소식', (t ->> 'place') || '에서 ' || nm || '이(가) 시작되었습니다. ' || (ru ->> 'min') || '분 동안 이어집니다.');
      end if;
    end if;
    if now() >= f.ends_at then
      for m in select x.owner_id, c.character_name from public.world_feast_members x join public.world_characters c on c.owner_id = x.owner_id
                join public.world_map_regions g on g.region_id = f.region_id
               where x.feast_id = f.feast_id and c.location = g.region_name and c.downed_at is null and not coalesce(c.is_dead, false) loop
        delete from public.world_character_statuses where owner_id = m.owner_id and status_key = (select e ->> 'key' from jsonb_array_elements(ru -> 'feasts') e where e ->> 'faction' = f.faction_key);
        insert into public.world_character_statuses(owner_id, status_key, potency, source_activity, expires_at)
        select m.owner_id, e ->> 'key', 1, 'feast', now() + make_interval(hours => (ru ->> 'buff_h')::int) from jsonb_array_elements(ru -> 'feasts') e where e ->> 'faction' = f.faction_key;
        insert into public.world_notifications(user_id, kind, title, content, payload)
        select m.owner_id, 'feast', e ->> 'name' || '이(가) 끝났습니다', '「' || (e ->> 'buff') || '」을(를) ' || (ru ->> 'buff_h') || '시간 동안 받았습니다.', jsonb_build_object('feast', f.feast_id)
          from jsonb_array_elements(ru -> 'feasts') e where e ->> 'faction' = f.faction_key;
        n := n + 1;
      end loop;
      insert into public.world_feast_lines(feast_id, kind, text)
      select f.feast_id, 'end', (e ->> 'name') || '이(가) 끝났습니다. 끝까지 함께한 ' || n || '명이 「' || (e ->> 'buff') || '」을(를) 받았습니다.' from jsonb_array_elements(ru -> 'feasts') e where e ->> 'faction' = f.faction_key;
      update public.world_feasts set status = 'done' where feast_id = f.feast_id;
      n := 0;
    end if;
  end loop;
end $function$;
select pg_temp.yh_share('public.world_feast_tick()');
select pg_temp.yh_own('public.world_feast_tick()', 'fn_owner_field');

create or replace function public.world_feast_view()
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); t jsonb := public.world_feast_today(); f public.world_feasts%rowtype; c public.world_characters%rowtype; me public.world_feast_members%rowtype; el numeric; st text; pet jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if t is null then return null; end if;
  select * into f from public.world_feasts where faction_key = t ->> 'faction' and day = (t ->> 'day')::date;
  select * into c from public.world_characters where owner_id = uid;
  if f.feast_id is not null then select * into me from public.world_feast_members where feast_id = f.feast_id and owner_id = uid; end if;
  el := extract(epoch from now() - (t ->> 'starts_at')::timestamptz);
  st := case when now() >= (t ->> 'ends_at')::timestamptz then 'done' when el >= 0 then 'live' else 'soon' end;
  if f.status = 'done' then st := 'done'; end if;
  select jsonb_build_object('name', coalesce(p.nickname, s.pet_name)) into pet
    from public.world_pet_profile x join public.world_pets p on p.owner_id = x.owner_id and p.pet_id = x.pet_id join public.world_pet_species s on s.pet_id = x.pet_id where x.owner_id = uid;
  return t || jsonb_build_object('now', now(), 'status', st, 'here', c.location = t ->> 'place', 'rules', public.world_feast_rules() - 'feasts', 'pet', pet,
    'me', jsonb_build_object('joined', me.owner_id is not null, 'pets', coalesce(me.pets, 0), 'last_at', me.last_at),
    'count', (select count(*) from public.world_feast_members where feast_id = f.feast_id),
    'script', (select coalesce(jsonb_agg(jsonb_build_object('at', (t ->> 'starts_at')::timestamptz + make_interval(secs => (x ->> 's')::int), 'k', x ->> 'k', 't', x ->> 't')), '[]'::jsonb)
                 from jsonb_array_elements(public.world_feast_script(t ->> 'key')) x where st = 'done' or (x ->> 's')::int <= el),
    'lines', (select coalesce(jsonb_agg(jsonb_build_object('at', l.at, 'k', l.kind, 't', l.text) order by l.at), '[]'::jsonb) from public.world_feast_lines l where l.feast_id = f.feast_id));
end $function$;
revoke all on function public.world_feast_view() from public, anon;
grant execute on function public.world_feast_view() to authenticated, service_role;
select pg_temp.yh_own('public.world_feast_view()', 'fn_owner_field');

create or replace function public.world_feast_act(p_kind text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); t jsonb := public.world_feast_today(); ru jsonb := public.world_feast_rules(); f public.world_feasts%rowtype; c public.world_characters%rowtype; me public.world_feast_members%rowtype; pet jsonb;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_kind not in ('join', 'pet') then raise exception '알 수 없는 행동입니다.'; end if;
  perform public.world_travel_guard('행사에 함께하기');
  if t is null or now() < (t ->> 'starts_at')::timestamptz or now() >= (t ->> 'ends_at')::timestamptz then raise exception '세력 행사가 열려 있는 동안에만 함께할 수 있습니다.'; end if;
  perform public.world_feast_tick();
  select * into f from public.world_feasts where faction_key = t ->> 'faction' and day = (t ->> 'day')::date and status = 'live';
  if not found then raise exception '세력 행사가 열려 있는 동안에만 함께할 수 있습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if c.location is distinct from t ->> 'place' then raise exception '%에 있어야 함께할 수 있습니다.', t ->> 'place'; end if;
  if c.downed_at is not null then raise exception '쓰러진 채로는 함께할 수 없습니다.'; end if;
  select * into me from public.world_feast_members where feast_id = f.feast_id and owner_id = uid for update;
  if p_kind = 'join' then
    if found then raise exception '이미 함께하고 있습니다.'; end if;
    insert into public.world_feast_members(feast_id, owner_id, name, last_at) values (f.feast_id, uid, c.character_name, now());
    insert into public.world_feast_lines(feast_id, kind, text) values (f.feast_id, 'join', c.character_name || '이(가) ' || (t ->> 'name') || '에 함께한다.');
  else
    if not found then raise exception '먼저 행사에 함께해야 합니다.'; end if;
    if me.pets >= (ru ->> 'pet_max')::int then raise exception '동무는 %번까지 나설 수 있습니다.', ru ->> 'pet_max'; end if;
    if me.last_at is not null and me.last_at > now() - make_interval(secs => (ru ->> 'gap_s')::int) then raise exception '조금 뒤에 다시 할 수 있습니다(단추 사이 %초).', ru ->> 'gap_s'; end if;
    pet := public.world_pet_show(uid);
    if pet is null then raise exception '데리고 다니는 동무가 없습니다.'; end if;
    update public.world_feast_members set pets = pets + 1, last_at = now() where feast_id = f.feast_id and owner_id = uid;
    insert into public.world_feast_lines(feast_id, kind, text) values (f.feast_id, 'pet', c.character_name || '의 ' || (pet ->> 'line'));
  end if;
  return public.world_feast_view();
end $function$;
revoke all on function public.world_feast_act(text) from public, anon;
grant execute on function public.world_feast_act(text) to authenticated, service_role;
select pg_temp.yh_own('public.world_feast_act(text)', 'fn_owner_field');

select pg_temp.yh_fix('world_notify_group', array[
  $$when p_kind in ('faction', 'faction_open', 'faction_week') then 'faction'$$,
  $$when p_kind in ('faction', 'faction_open', 'faction_week', 'feast') then 'faction'$$]);

create or replace function public.world_wedding_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object(
    'delays', jsonb_build_array(10, 60, 720, 1440),
    'run_min', 10,
    'remind_min', 10,
    'gap_s', 15,
    'wish_max', 40,
    'guest', jsonb_build_object('clap', 5, 'petal', 5, 'cup', 5, 'pet', 3),
    'couple', jsonb_build_object('bow', 5, 'cake', 5, 'pet', 3))
$function$;

alter table public.world_wedding_guests add column if not exists pets integer not null default 0;

select pg_temp.yh_fix('world_wedding_cheer(uuid,text,text)', array[
  $$ru jsonb := public.world_wedding_rules(); couple boolean; cap int; used int;$$,
  $$ru jsonb := public.world_wedding_rules(); couple boolean; cap int; used int; pet jsonb;$$,
  $$    used := case p_kind when 'clap' then g.claps when 'petal' then g.petals when 'cup' then g.cups when 'bow' then g.bows else g.cakes end;$$,
  $$    used := case p_kind when 'clap' then g.claps when 'petal' then g.petals when 'cup' then g.cups when 'bow' then g.bows when 'pet' then g.pets else g.cakes end;
    if p_kind = 'pet' then pet := public.world_pet_show(uid); if pet is null then raise exception '데리고 다니는 동무가 없습니다.'; end if; end if;$$,
  $$      bows = bows + (p_kind = 'bow')::int, cakes = cakes + (p_kind = 'cake')::int, last_at = now()$$,
  $$      bows = bows + (p_kind = 'bow')::int, cakes = cakes + (p_kind = 'cake')::int, pets = pets + (p_kind = 'pet')::int, last_at = now()$$,
  $$    msg := c.character_name || case p_kind$$,
  $$    msg := case when p_kind = 'pet' then c.character_name || '의 ' || (pet ->> 'line') else c.character_name || case p_kind$$,
  $$      else '이(가) 하객들에게 혼례 떡을 한 접시씩 돌린다.' end;$$,
  $$      else '이(가) 하객들에게 혼례 떡을 한 접시씩 돌린다.' end end;$$]);

select pg_temp.yh_fix('world_wedding_view(uuid)', array[
  $$'cake', coalesce(me.cakes, 0),$$,
  $$'cake', coalesce(me.cakes, 0), 'pet', coalesce(me.pets, 0),$$,
  $$'rules', public.world_wedding_rules(),$$,
  $$'rules', public.world_wedding_rules(), 'my_pet', (select coalesce(p.nickname, s.pet_name) from public.world_pet_profile x join public.world_pets p on p.owner_id = x.owner_id and p.pet_id = x.pet_id join public.world_pet_species s on s.pet_id = x.pet_id where x.owner_id = uid),$$]);

do $c$ begin
  if exists (select 1 from cron.job where jobname = 'yh-feast') then perform cron.unschedule('yh-feast'); end if;
  perform cron.schedule('yh-feast', '* * * * *', 'select public.world_feast_tick()');
end $c$;

update public.world_patch_notes set body = replace(body, E'\n## 그 밖\n', $N$

## 세력 행사
- 일곱 대세력이 요일마다 거점에서 행사를 엽니다. 월 정통파 봉등례(본부 정청) · 화 적월교 적월제(백골 장터) · 수 흑련회 야장회(십삼문 암시장) · 목 북령맹 설등 공양(철벽 고찰) · 금 수향연맹 유등회(구름나루) · 토 남명회 잔불제(잔불촌) · 일 천명원 관성제(무극 관성대).
- 행사는 매일 낮 12시 30분부터 30분 동안 열립니다. 세력과 상관없이 누구나 그곳에서 「함께하기」를 누를 수 있고, 도중에 와도 됩니다.
- 끝나는 순간 그곳에 있는 참여자는 그 행사의 기운을 8시간 동안 받습니다(봉등의 가호: 정신 손실 −10%·침식 −5% · 적월의 맹세: 주는 피해 +5% · 장부의 셈: 희귀품 +5% · 설등의 온기: 받는 피해 −5% · 유등의 물길: 이동 시간 −10% · 이어 받은 불씨: 회복량 +10% · 관성의 점괘: 단서 +8%·조우 −5%).
- 30분 전에 그 세력 조사원에게 알림이 가고, 10분 전과 시작할 때 전체 채팅 「세력 소식」에 올라갑니다. 현장 위 띠에서 오늘의 행사를 볼 수 있습니다.
- 데리고 다니는 꼬마 동무가 있으면 행사와 혼례에서 「동무 나서기」로 재롱을 보일 수 있습니다(세 번까지).

## 그 밖
$N$) where note_id = '2.0.0' and position('## 세력 행사' in body) = 0;

update public.world_app_meta set value = '20261116060000' where key = 'db_version';
