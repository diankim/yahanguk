
-- ─────────────────────────────────────────────────────────────
-- F. 연리 인연도 개편 · 혼례(2026-10-29 확정안)
--   인연도: 하루 상한 30 → 100. 함께 토벌 +2(같은 곳·같은 파티) · 함께 탐색·채집 +1 · 안부 귓속말 +5(하루 1번) · 선물 +10(하루 1번)
--           함께 원정 완주 +20(같은 지역에 같이 다녀옴) · 구조 +20. 단계 100·300·700 그대로
--   혼례: 인연도 300 + 둘 다 Lv20 + 주 이야기 6장 마침. 본부 정청이나 두 사람 가운데 한 사람의 세력 거점(안전지대)에 둘이 함께 있을 때
--         한 사람이 청하고 정인이 받으면 5분 뒤 시작해 10분 동안 혼례가 이어진다(비용 3,000전, 둘이 1,500전씩)
--         그 시각 그곳에 있는 이는 하객: 박수 3번·꽃잎 3번·축사 1번(40자), 단추 사이 15초. 끝나면 하객에게 혼례 떡
--         두 사람에게 칭호 「백년가약」·한 쌍 테두리 「연리 매듭 테」·낙관 「合」·별채 「한 지붕」(서로의 별채에 가구를 놓는 권한, 7.2 별채에서 씀)
--   파혼: 혼례를 올린 연리가 끝나면 다시 맺기까지 7일(그 밖은 3일 그대로)
-- ─────────────────────────────────────────────────────────────
select pg_temp.yh_patch('public.world_bond_gain(uuid,integer,text)', 'room := greatest(0, 30 - b.gain_today);', 'room := greatest(0, 100 - b.gain_today);');
select pg_temp.yh_patch('public.world_bond_on_whisper()', 'perform public.world_bond_gain(b.bond_id, 3, ''greet'');', 'perform public.world_bond_gain(b.bond_id, 5, ''greet'');', 2);
select pg_temp.yh_patch('public.world_bond_gift(text,integer,integer)', 'perform public.world_bond_gain(b.bond_id, 5, ''gift'');', 'perform public.world_bond_gain(b.bond_id, 10, ''gift'');');
select pg_temp.yh_patch('public.world_bond_on_event()', '    perform public.world_bond_gain(bid, 10, ''rescue'');', '    perform public.world_bond_gain(bid, 20, ''rescue'');');
select pg_temp.yh_patch('public.world_bond_on_event()', '    perform public.world_bond_gain(bid, 1, ''fight'');', '    perform public.world_bond_gain(bid, 2, ''fight'');
  elsif new.event_type in (''explore'', ''gather'') and public.world_bond_together(new.actor_id) then
    perform public.world_bond_gain(bid, 1, new.event_type);
  elsif new.event_type = ''expedition_end'' and new.payload ->> ''ended'' = ''complete''
    and exists (select 1 from public.world_expeditions mine join public.world_expeditions x on x.owner_id = pid and x.region_id = mine.region_id and x.status = ''done''
                 and x.started_at < mine.finished_at and x.finished_at > mine.started_at and x.finished_at > now() - interval ''30 minutes''
                 where mine.owner_id = new.actor_id and mine.status = ''done'' and mine.finished_at > now() - interval ''1 minute'')
    and not exists (select 1 from public.world_bonds bb where bb.bond_id = bid and coalesce((bb.marks ->> ''exp_day'')::date, ''2000-01-01'') = public.world_bond_day()) then
    update public.world_bonds set marks = coalesce(marks, ''{}''::jsonb) || jsonb_build_object(''exp_day'', public.world_bond_day()) where bond_id = bid;
    perform public.world_bond_gain(bid, 20, ''expedition'');');
drop trigger if exists world_bond_on_event on public.world_events;
create trigger world_bond_on_event after insert on public.world_events for each row
  when (new.event_type = any (array['rescue', 'combat', 'explore', 'gather', 'expedition_end'])) execute function public.world_bond_on_event();
-- 혼례를 올린 연리가 끝나면 7일
select pg_temp.yh_patch('public.world_bond_block_reason(uuid,text)', '  select max(ended_at) into last_end from public.world_bonds where (a_id = p_owner or b_id = p_owner) and ended_at is not null;',
  '  select max(ended_at + case when coalesce((marks ->> ''married'')::boolean, false) then interval ''4 days'' else interval ''0'' end) into last_end
    from public.world_bonds where (a_id = p_owner or b_id = p_owner) and ended_at is not null;');

-- 혼례
create table if not exists public.world_weddings (
  wed_id uuid primary key default gen_random_uuid(),
  bond_id uuid not null,
  a_id uuid not null, b_id uuid not null, a_name text, b_name text,
  region_id text not null,
  status text not null default 'asked' check (status in ('asked', 'ready', 'ceremony', 'done', 'cancelled')),
  asked_by uuid not null,
  starts_at timestamptz, ends_at timestamptz,
  script jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
create unique index if not exists world_weddings_live on public.world_weddings(bond_id) where status in ('asked', 'ready', 'ceremony');
create table if not exists public.world_wedding_guests (
  wed_id uuid not null references public.world_weddings(wed_id) on delete cascade,
  owner_id uuid not null,
  name text,
  claps int not null default 0, petals int not null default 0, wished boolean not null default false,
  last_at timestamptz,
  primary key (wed_id, owner_id)
);
create table if not exists public.world_wedding_lines (
  id bigserial primary key,
  wed_id uuid not null references public.world_weddings(wed_id) on delete cascade,
  at timestamptz not null default now(),
  kind text not null,
  text text not null
);
create index if not exists world_wedding_lines_wed on public.world_wedding_lines(wed_id, at);
alter table public.world_weddings enable row level security;
alter table public.world_wedding_guests enable row level security;
alter table public.world_wedding_lines enable row level security;
revoke all on public.world_weddings, public.world_wedding_guests, public.world_wedding_lines from anon, authenticated;
grant select, insert, update, delete on public.world_weddings, public.world_wedding_guests, public.world_wedding_lines to fn_owner_field;
grant usage on sequence public.world_wedding_lines_id_seq to fn_owner_field;

-- 혼례를 올릴 수 있는 곳: 본부 정청 · 두 사람의 세력 거점
create or replace function public.world_wedding_places(p_a uuid, p_b uuid) returns text[]
language sql stable security definer set search_path = '' as $$
  select array(select distinct x from unnest(array['hq_yard']
      || public.world_faction_home((select major_faction_id from public.world_characters where owner_id = p_a))
      || public.world_faction_home((select major_faction_id from public.world_characters where owner_id = p_b))) x)
$$;

-- 혼례 절차: 시작 시각부터 10분 동안 차례로 올라가는 줄(주례 · 전안례 · 교배례 · 합근례)
create or replace function public.world_wedding_script(p_a text, p_b text, p_place text) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_agg(jsonb_build_object('s', s, 'k', k, 't', t) order by s) from (values
    (0, 'rite', p_place || ' 마당에 청사초롱이 걸린다. 대례상 위에 밤·대추·청실홍실이 놓였다.'),
    (20, 'host', '주례: 오늘 ' || p_a || '과(와) ' || p_b || '이(가) 하객 앞에서 백년을 약속하려 합니다. 모두 자리해 주십시오.'),
    (45, 'rite', '나무 기러기를 품에 안은 ' || p_a || '이(가) 들어선다. 기러기는 한 번 맺은 짝을 평생 잊지 않는다고 한다.'),
    (75, 'host', '주례: 전안례(奠雁禮)를 올립니다. 기러기를 상 위에 올려 변치 않을 마음을 보이십시오.'),
    (105, 'rite', p_a || '이(가) 기러기를 상에 내려놓고 두 번 절한다. 하객들 사이로 낮은 웃음과 박수가 번진다.'),
    (150, 'rite', p_b || '이(가) 활옷 소매를 여미고 마주 선다. 머리 위 청사초롱 불빛이 조용히 흔들린다.'),
    (190, 'host', '주례: 교배례(交拜禮)를 올립니다. 서로에게 절을 올려 예를 갖추십시오.'),
    (220, 'rite', p_b || '이(가) 두 번 절하고, ' || p_a || '이(가) 한 번 절한다. 다시 두 번, 다시 한 번. 절이 오가는 동안 마당이 고요해진다.'),
    (270, 'rite', '어디선가 밤바람이 불어 초롱이 일제히 기울었다가 바로 선다. 누군가 「좋은 바람이다」 하고 속삭인다.'),
    (320, 'host', '주례: 합근례(合巹禮)를 올립니다. 한 박을 둘로 나눈 잔에 술을 따라 나누어 마시십시오.'),
    (355, 'rite', '반쪽 표주박 두 개에 술이 채워진다. 두 사람이 잔을 바꾸어 들고, 천천히 마신다.'),
    (400, 'rite', '빈 표주박을 다시 맞붙이자 한 몸이 된다. 하객들이 숨을 죽였다가 한꺼번에 환호한다.'),
    (450, 'host', '주례: 이제 두 사람은 한 지붕 아래 같은 등불을 켭니다. 서로의 길이 어두울 때 먼저 등을 드십시오.'),
    (500, 'rite', '청실과 홍실이 두 사람의 손목에 한 번씩 감긴다. 연리의 정표가 희미하게 빛난다.'),
    (540, 'host', '주례: 혼례를 마칩니다. 하객 여러분, 큰 박수로 배웅해 주십시오.'),
    (580, 'rite', '꽃잎이 마당 가득 흩날린다. ' || p_a || '과(와) ' || p_b || '이(가) 나란히 하객 사이를 걸어 나간다.')) v(s, k, t)
$$;

create or replace function public.world_wedding_ask() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); b public.world_bonds%rowtype; me public.world_characters%rowtype; pt public.world_characters%rowtype; pid uuid; r public.world_map_regions%rowtype; wid uuid;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into b from public.world_bonds where ended_at is null and (a_id = uid or b_id = uid) for update;
  if not found then raise exception '정인이 있어야 혼례를 올릴 수 있습니다.'; end if;
  if coalesce((b.marks ->> 'married')::boolean, false) then raise exception '이미 혼례를 올렸습니다.'; end if;
  if b.affinity < 300 then raise exception '인연도가 300이 되어야 혼례를 올릴 수 있습니다(지금 %).', b.affinity; end if;
  pid := case when b.a_id = uid then b.b_id else b.a_id end;
  select * into me from public.world_characters where owner_id = uid;
  select * into pt from public.world_characters where owner_id = pid;
  if coalesce(me.level, 1) < 20 or coalesce(pt.level, 1) < 20 then raise exception '두 사람 모두 레벨 20이어야 합니다.'; end if;
  if not public.world_quest_chapter_done(uid, 'eclipse_gate') or not public.world_quest_chapter_done(pid, 'eclipse_gate') then raise exception '두 사람 모두 주 이야기 6장 「월식의 문」을 마쳐야 합니다.'; end if;
  if me.location is distinct from pt.location then raise exception '정인과 같은 곳에 있어야 합니다.'; end if;
  r := public.world_field_region(me.location);
  if not (r.region_id = any (public.world_wedding_places(uid, pid))) then raise exception '본부 정청이나 두 사람 가운데 한 사람의 세력 거점에서 혼례를 올릴 수 있습니다.'; end if;
  if coalesce(me.gil, 0) < 1500 then raise exception '혼례 비용 1,500전이 모자랍니다(둘이 1,500전씩).'; end if;
  if exists (select 1 from public.world_weddings where bond_id = b.bond_id and status in ('asked', 'ready', 'ceremony')) then raise exception '이미 청한 혼례가 있습니다.'; end if;
  insert into public.world_weddings(bond_id, a_id, b_id, a_name, b_name, region_id, asked_by)
  values (b.bond_id, uid, pid, me.character_name, pt.character_name, r.region_id, uid) returning wed_id into wid;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (pid, 'bond_wedding_ask', '혼례를 청합니다', me.character_name || '이(가) ' || r.region_name || '에서 혼례를 올리자고 합니다. 받으면 5분 뒤 시작합니다(1,500전씩).', jsonb_build_object('wed_id', wid));
  return jsonb_build_object('ok', true, 'wed_id', wid, 'content', '정인에게 혼례를 청했습니다.');
end $$;

create or replace function public.world_wedding_respond(p_wed uuid, p_accept boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); w public.world_weddings%rowtype; a public.world_characters%rowtype; bb public.world_characters%rowtype; place text; who uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into w from public.world_weddings where wed_id = p_wed for update;
  if not found or w.status <> 'asked' or w.b_id <> uid then raise exception '받을 수 있는 혼례 청이 아닙니다.'; end if;
  if not coalesce(p_accept, false) then
    update public.world_weddings set status = 'cancelled' where wed_id = p_wed;
    insert into public.world_notifications(user_id, kind, title, content, payload) values (w.a_id, 'bond_wedding', '혼례를 미루었습니다', w.b_name || '이(가) 혼례를 다음으로 미루었습니다.', jsonb_build_object('wed_id', p_wed));
    return jsonb_build_object('ok', true, 'content', '혼례를 미루었습니다.');
  end if;
  perform 1 from public.world_characters where owner_id in (w.a_id, w.b_id) order by owner_id for update;
  select * into a from public.world_characters where owner_id = w.a_id;
  select * into bb from public.world_characters where owner_id = w.b_id;
  select region_name into place from public.world_map_regions where region_id = w.region_id;
  if a.location is distinct from place or bb.location is distinct from place then raise exception '두 사람이 모두 %에 있어야 합니다.', place; end if;
  if coalesce(a.gil, 0) < 1500 or coalesce(bb.gil, 0) < 1500 then raise exception '두 사람 모두 1,500전이 있어야 합니다.'; end if;
  update public.world_characters set gil = gil - 1500, updated_at = now() where owner_id in (w.a_id, w.b_id);
  update public.world_weddings set status = 'ready', starts_at = now() + interval '5 minutes', ends_at = now() + interval '15 minutes',
    script = public.world_wedding_script(w.a_name, w.b_name, place) where wed_id = p_wed;
  -- 하객 초대: 두 사람의 친구·모임원
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select distinct x, 'wedding_invite', '혼례에 초대합니다', w.a_name || '과(와) ' || w.b_name || '이(가) 5분 뒤 ' || place || '에서 혼례를 올립니다. 그 시각 그곳에 있으면 하객이 됩니다.', jsonb_build_object('wed_id', p_wed)
    from (select f.friend_id x from public.world_friends f where f.owner_id in (w.a_id, w.b_id) and f.status = 'accepted'
          union select cm2.owner_id from public.world_circle_members cm join public.world_circle_members cm2 on cm2.circle_id = cm.circle_id where cm.owner_id in (w.a_id, w.b_id)) s
   where x not in (w.a_id, w.b_id);
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (w.a_id, 'bond_wedding', '혼례가 정해졌습니다', '5분 뒤 ' || place || '에서 혼례가 시작됩니다.', jsonb_build_object('wed_id', p_wed)),
         (w.b_id, 'bond_wedding', '혼례가 정해졌습니다', '5분 뒤 ' || place || '에서 혼례가 시작됩니다.', jsonb_build_object('wed_id', p_wed));
  select owner_id into who from public.world_staff order by owner_id limit 1;
  if who is not null then
    insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
    values ('global', who, '연리 소식', w.a_name || '과(와) ' || w.b_name || '의 혼례가 5분 뒤 ' || place || '에서 열립니다. 그곳에 계신 분은 누구나 하객이 됩니다.');
  end if;
  return jsonb_build_object('ok', true, 'wed_id', p_wed, 'content', '혼례가 5분 뒤 시작합니다.');
end $$;

-- 혼례를 마친다(끝 시각이 지난 뒤 누군가 볼 때 또는 비무회 예약 작업이 돌 때)
create or replace function public.world_wedding_finish(p_wed uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare w public.world_weddings%rowtype; place text; g record; n int := 0;
begin
  select * into w from public.world_weddings where wed_id = p_wed for update;
  if not found or w.status not in ('ready', 'ceremony') or now() < w.ends_at then return; end if;
  update public.world_weddings set status = 'done' where wed_id = p_wed;
  update public.world_bonds set marks = coalesce(marks, '{}'::jsonb) || jsonb_build_object('married', true, 'married_at', now(), 'wed_id', p_wed) where bond_id = w.bond_id;
  insert into public.world_character_titles(owner_id, title_key) values (w.a_id, 'wed_vow'), (w.b_id, 'wed_vow') on conflict do nothing;
  insert into public.world_character_cosmetics(owner_id, cosmetic_key) values (w.a_id, 'fr_wed'), (w.b_id, 'fr_wed'), (w.a_id, 'sl_hap'), (w.b_id, 'sl_hap') on conflict do nothing;
  select region_name into place from public.world_map_regions where region_id = w.region_id;
  -- 하객: 끝날 때 그곳에 있는 이(두 사람 빼고) + 단추를 한 번이라도 누른 이에게 혼례 떡
  for g in select c.owner_id, c.character_name from public.world_characters c
            where (c.location = place or exists (select 1 from public.world_wedding_guests x where x.wed_id = p_wed and x.owner_id = c.owner_id))
              and c.owner_id not in (w.a_id, w.b_id) and not coalesce(c.is_dead, false) loop
    update public.world_characters set inventory = public.world_inv_add(coalesce(inventory, '{}'::jsonb), 'wedding_rice_cake', 1), updated_at = now() where owner_id = g.owner_id;
    insert into public.world_wedding_guests(wed_id, owner_id, name) values (p_wed, g.owner_id, g.character_name) on conflict do nothing;
    n := n + 1;
  end loop;
  insert into public.world_wedding_lines(wed_id, kind, text) values (p_wed, 'end', '혼례가 끝났습니다. 하객 ' || n || '명에게 혼례 떡을 나누었습니다.');
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (w.a_id, 'bond_wedding', '백년가약', w.b_name || '과(와) 혼례를 올렸습니다. 칭호 「백년가약」·테두리 「연리 매듭 테」·낙관 「合」을 받았습니다. 별채가 열리면 서로의 별채에 가구를 놓을 수 있습니다.', jsonb_build_object('wed_id', p_wed)),
         (w.b_id, 'bond_wedding', '백년가약', w.a_name || '과(와) 혼례를 올렸습니다. 칭호 「백년가약」·테두리 「연리 매듭 테」·낙관 「合」을 받았습니다. 별채가 열리면 서로의 별채에 가구를 놓을 수 있습니다.', jsonb_build_object('wed_id', p_wed));
end $$;
create or replace function public.world_wedding_tick() returns void
language plpgsql security definer set search_path = '' as $$
declare w record;
begin
  for w in select wed_id from public.world_weddings where status in ('ready', 'ceremony') and ends_at <= now() loop perform public.world_wedding_finish(w.wed_id); end loop;
  update public.world_weddings set status = 'ceremony' where status = 'ready' and starts_at <= now();
  update public.world_weddings set status = 'cancelled' where status = 'asked' and created_at < now() - interval '1 hour';
end $$;

-- 혼례 창: 절차 줄(시작부터 지난 만큼) + 하객 줄
create or replace function public.world_wedding_view(p_wed uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); w public.world_weddings%rowtype; c public.world_characters%rowtype; place text; el numeric; me public.world_wedding_guests%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_wedding_finish(p_wed);
  select * into w from public.world_weddings where wed_id = p_wed;
  if not found then raise exception '없는 혼례입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  select region_name into place from public.world_map_regions where region_id = w.region_id;
  select * into me from public.world_wedding_guests where wed_id = p_wed and owner_id = uid;
  el := extract(epoch from now() - w.starts_at);
  return jsonb_build_object('now', now(), 'wed_id', w.wed_id, 'status', w.status, 'a', w.a_name, 'b', w.b_name, 'place', place, 'starts_at', w.starts_at, 'ends_at', w.ends_at,
    'here', c.location = place, 'couple', uid in (w.a_id, w.b_id),
    'me', jsonb_build_object('claps', coalesce(me.claps, 0), 'petals', coalesce(me.petals, 0), 'wished', coalesce(me.wished, false), 'last_at', me.last_at),
    'script', case when w.status in ('ceremony', 'done') or (w.status = 'ready' and el >= 0) then
        (select coalesce(jsonb_agg(jsonb_build_object('at', w.starts_at + make_interval(secs => (x ->> 's')::int), 'k', x ->> 'k', 't', x ->> 't')), '[]'::jsonb)
           from jsonb_array_elements(w.script) x where w.status = 'done' or (x ->> 's')::int <= el) else '[]'::jsonb end,
    'lines', (select coalesce(jsonb_agg(jsonb_build_object('at', l.at, 'k', l.kind, 't', l.text) order by l.at), '[]'::jsonb) from public.world_wedding_lines l where l.wed_id = p_wed),
    'guests', (select count(*) from public.world_wedding_guests where wed_id = p_wed));
end $$;

-- 하객 단추: 박수 3번 · 꽃잎 3번 · 축사 1번(40자), 단추 사이 15초. 혼례 시각에 그곳에 있어야 한다
create or replace function public.world_wedding_cheer(p_wed uuid, p_kind text, p_text text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); w public.world_weddings%rowtype; c public.world_characters%rowtype; g public.world_wedding_guests%rowtype; place text; msg text; wish text;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_kind not in ('clap', 'petal', 'wish') then raise exception '알 수 없는 축하입니다.'; end if;
  select * into w from public.world_weddings where wed_id = p_wed;
  if not found or w.status not in ('ready', 'ceremony') or now() < w.starts_at or now() > w.ends_at then raise exception '혼례가 열리는 동안에만 축하할 수 있습니다.'; end if;
  if uid in (w.a_id, w.b_id) then raise exception '혼례의 주인공은 하객 단추를 쓰지 않습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  select region_name into place from public.world_map_regions where region_id = w.region_id;
  if c.location is distinct from place then raise exception '%에 있어야 하객이 됩니다.', place; end if;
  insert into public.world_wedding_guests(wed_id, owner_id, name) values (p_wed, uid, c.character_name) on conflict do nothing;
  select * into g from public.world_wedding_guests where wed_id = p_wed and owner_id = uid for update;
  if g.last_at is not null and g.last_at > now() - interval '15 seconds' then raise exception '조금 뒤에 다시 축하할 수 있습니다(단추 사이 15초).'; end if;
  if p_kind = 'clap' then
    if g.claps >= 3 then raise exception '박수는 세 번까지 칠 수 있습니다.'; end if;
    update public.world_wedding_guests set claps = claps + 1, last_at = now() where wed_id = p_wed and owner_id = uid;
    msg := c.character_name || '이(가) 힘껏 박수를 친다.';
  elsif p_kind = 'petal' then
    if g.petals >= 3 then raise exception '꽃잎은 세 번까지 뿌릴 수 있습니다.'; end if;
    update public.world_wedding_guests set petals = petals + 1, last_at = now() where wed_id = p_wed and owner_id = uid;
    msg := c.character_name || '이(가) 두 사람 앞에 꽃잎을 한 줌 뿌린다.';
  else
    if g.wished then raise exception '축사는 한 번만 할 수 있습니다.'; end if;
    wish := btrim(regexp_replace(coalesce(p_text, ''), '\s+', ' ', 'g'));
    if wish = '' then raise exception '축사를 적어 주세요.'; end if;
    if char_length(wish) > 40 then raise exception '축사는 40자까지 적을 수 있습니다.'; end if;
    update public.world_wedding_guests set wished = true, last_at = now() where wed_id = p_wed and owner_id = uid;
    msg := c.character_name || '의 축사: 「' || wish || '」';
  end if;
  insert into public.world_wedding_lines(wed_id, kind, text) values (p_wed, p_kind, msg);
  return public.world_wedding_view(p_wed);
end $$;

-- 내 혼례(진행 중이거나 청을 받은 것)와 지금 있는 곳에서 열리는 혼례
create or replace function public.world_wedding_here() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype;
begin
  select * into c from public.world_characters where owner_id = uid;
  return (select coalesce(jsonb_agg(jsonb_build_object('wed_id', w.wed_id, 'a', w.a_name, 'b', w.b_name, 'status', w.status, 'starts_at', w.starts_at, 'mine', uid in (w.a_id, w.b_id),
      'place', (select region_name from public.world_map_regions where region_id = w.region_id)) order by w.created_at desc), '[]'::jsonb)
    from public.world_weddings w where (w.status in ('ready', 'ceremony') and (uid in (w.a_id, w.b_id) or (select region_name from public.world_map_regions where region_id = w.region_id) = c.location))
                                     or (w.status = 'asked' and uid in (w.a_id, w.b_id)));
end $$;

do $$ declare fn text; begin
  foreach fn in array array['world_wedding_places(uuid,uuid)', 'world_wedding_script(text,text,text)', 'world_wedding_ask()', 'world_wedding_respond(uuid,boolean)', 'world_wedding_finish(uuid)',
    'world_wedding_tick()', 'world_wedding_view(uuid)', 'world_wedding_cheer(uuid,text,text)', 'world_wedding_here()'] loop
    execute format('alter function public.%s owner to fn_owner_field', fn);
  end loop;
  set role fn_owner_field;
  revoke all on function public.world_wedding_places(uuid, uuid), public.world_wedding_script(text, text, text), public.world_wedding_finish(uuid), public.world_wedding_tick() from public, anon, authenticated;
  revoke all on function public.world_wedding_ask(), public.world_wedding_respond(uuid, boolean), public.world_wedding_view(uuid), public.world_wedding_cheer(uuid, text, text), public.world_wedding_here() from public, anon;
  grant execute on function public.world_wedding_ask(), public.world_wedding_respond(uuid, boolean), public.world_wedding_view(uuid), public.world_wedding_cheer(uuid, text, text), public.world_wedding_here() to authenticated;
  reset role;
end $$;
grant select on public.world_friends, public.world_circle_members to fn_owner_field;
grant select, insert on public.world_character_titles, public.world_character_cosmetics to fn_owner_field;
-- 혼례 마침은 1분 예약 작업(비무회)에 함께 돈다
select pg_temp.yh_patch('public.world_tourney_tick()', '  perform public.world_tourney_ensure();', '  perform public.world_tourney_ensure();
  perform public.world_wedding_tick();');

-- 보상: 칭호·꾸미기·혼례 떡
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
 ('wed_vow', '백년가약', 'knot', '하객 앞에서 정인과 백년을 약속했다.', '정인과 혼례를 올린다', '{}', true, false, '{"manual": true}', 1300, '교류', 4)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
 ('fr_wed', 'frame', 'legend', '연리 매듭 테', '정인과 혼례를 올린다', '교류', '{"manual": true}', false, true, 1300),
 ('sl_hap', 'seal', 'legend', '낙관 「合」', '정인과 혼례를 올린다', '교류', '{"manual": true}', false, true, 1301)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, category = excluded.category;
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
values ('wedding_rice_cake', '혼례 떡', 'consumable', 1, '혼례에서 하객에게 나누는 떡. 먹으면 체력 +20·정신 +15.', true, '{}', 1, '{}', true, 30, 10)
on conflict (item_id) do update set description = excluded.description;
select pg_temp.yh_patch('public.world_use_item(text)', '''banyo_salve'', ''oblivion_incense'') THEN RAISE EXCEPTION', '''banyo_salve'', ''oblivion_incense'', ''wedding_rice_cake'') THEN RAISE EXCEPTION');
select pg_temp.yh_patch('public.world_use_item(text)', 'WHEN ''banyo_salve'' THEN hp := 70;', 'WHEN ''wedding_rice_cake'' THEN hp := 20; mn := 15; WHEN ''banyo_salve'' THEN hp := 70;');
select pg_temp.yh_patch('public.world_notify_group(text)', 'when p_kind like ''bond%'' then ''bond''', 'when p_kind like ''bond%'' or p_kind = ''wedding_invite'' then ''bond''');
-- 연리 칸: 혼례를 올렸는지
select pg_temp.yh_patch('public.world_bond_snapshot()', '      ''gifted_today'', (case when side = ''a'' then b.a_gift_day else b.b_gift_day end) = today,',
  '      ''gifted_today'', (case when side = ''a'' then b.a_gift_day else b.b_gift_day end) = today, ''married'', coalesce((b.marks ->> ''married'')::boolean, false),');
