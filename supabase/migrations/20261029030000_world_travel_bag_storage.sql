-- 패치 묶음 2(2026-10-29): ① 이동 보상은 도착할 때만 · 취소 대가는 3분 대기  ② 장착한 장비는 가방 칸을 차지하지 않음  ③ 개인 창고.
--   한 번에 실행하는 파일이다(실행 횟수를 줄이려고 세 패치를 합침).
grant fn_owner_field to postgres with inherit true, set true;
grant fn_owner_expedition to postgres with inherit true, set true;
grant fn_owner_18473 to postgres with inherit true, set true;
grant fn_owner_18941 to postgres with inherit true, set true;
grant fn_owner_18962 to postgres with inherit true, set true;
grant fn_owner_20175 to postgres with inherit true, set true;
grant fn_owner_18540 to postgres with inherit true, set true;
grant fn_owner_19257 to postgres with inherit true, set true;

-- ① ─────────────────────────────────────────
-- ① 이동 보상은 도착할 때만, 취소 대가는 돈 대신 시간.
--   출발·도착 모두 행동 기록 'travel'을 남기는데, 도착 기록에만 travel_history_id가 있다(world_travel_status).
--   지금까지 출발에도 경험치(+5·+4)·추적 기술 +3·상태 굴림·세력 임무·이동 칭호가 붙어, 출발→취소를 되풀이해 쌓을 수 있었다.
--   · 보상을 주는 곳에서 출발 기록은 건너뛴다(도착 기록만 센다).
--   · 이동 칭호·꾸미기 규칙도 도착만 센다(규칙에 "has":"travel_history_id", 서로 다른 지역 수 규칙도 has를 따르게 한다).
--   · 이동 취소는 위약금 없이, 취소한 뒤 3분 동안 다시 출발할 수 없다(world_guard_action_context가 출발 기록에서 막는다).

-- 행동 막기 함수 주인이 취소 기록을 읽을 수 있게(읽기만)
grant select on public.world_travel_history to fn_owner_expedition;

do $$
declare pat record; d text;
begin
  for pat in select * from (values
    -- 레벨 경험치: 출발 0, 도착 5
    ('public.world_award_progression_from_event()',
     'when new.event_type=''travel'' then case when coalesce(new.payload->>''arrived'',''false'')=''true'' then 0 else 5 end',
     'when new.event_type=''travel'' then case when coalesce(new.payload,''{}''::jsonb) ? ''travel_history_id'' then 5 else 0 end'),
    -- 사건 진행 경험치
    ('public.world_apply_event_progress()', '  elsif k=''travel'' then xp := 4;', '  elsif k=''travel'' and payload ? ''travel_history_id'' then xp := 4;'),
    -- 추적 기술 경험
    ('public.world_track_specialized_skill()',
     ' if new.event_type not in (''combat'',''gather'',''craft'',''explore'',''story'',''travel'',''rescue'') then return new; end if;',
     ' if new.event_type not in (''combat'',''gather'',''craft'',''explore'',''story'',''travel'',''rescue'') then return new; end if;
 if new.event_type=''travel'' and not (v_payload ? ''travel_history_id'') then return new; end if;'),
    -- 이동 중 상태이상 굴림
    ('public.world_apply_activity_status()', 'when new.event_type in (''travel'',''move'') then ''travel''',
     'when new.event_type in (''travel'',''move'') and coalesce(new.payload,''{}''::jsonb) ? ''travel_history_id'' then ''travel'''),
    -- 세력 임무(아무 행동)
    ('public.world_track_faction_missions()', '  IF new.event_type=''encounter'' THEN RETURN new; END IF;',
     '  IF new.event_type=''encounter'' THEN RETURN new; END IF;
  IF new.event_type=''travel'' AND NOT (coalesce(new.payload,''{}''::jsonb) ? ''travel_history_id'') THEN RETURN new; END IF;'),
    -- 서로 다른 지역 수 규칙도 has를 따른다
    ('public.world_title_rule_ok(uuid,jsonb)',
     'WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> ''distinct'' AND e.payload ? (p_rule ->> ''key'');',
     'WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> ''distinct'' AND e.payload ? (p_rule ->> ''key'') AND (NOT p_rule ? ''has'' OR e.payload ? (p_rule ->> ''has''));'),
    ('public.world_title_rule_progress(uuid,jsonb)',
     'where e.actor_id = p_owner and e.event_type = p_rule ->> ''distinct'' and e.payload ? (p_rule ->> ''key'');',
     'where e.actor_id = p_owner and e.event_type = p_rule ->> ''distinct'' and e.payload ? (p_rule ->> ''key'') and (not p_rule ? ''has'' or e.payload ? (p_rule ->> ''has''));'),
    -- 취소 뒤 3분 동안 출발 막기(출발 기록 = travel_history_id가 없는 travel)
    ('public.world_guard_action_context()', '  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN (''encounter'', ''combat'') THEN',
     '  IF k = ''travel'' AND NOT (p ? ''travel_history_id'') THEN
    PERFORM 1 FROM public.world_travel_history h WHERE h.owner_id = new.actor_id AND h.cancelled_at > now() - interval ''3 minutes'';
    IF FOUND THEN
      RAISE EXCEPTION ''%'', format(''이동을 취소한 뒤 3분 동안은 다시 출발할 수 없습니다(%s초 남음).'',
        ceil(extract(epoch FROM (SELECT max(h.cancelled_at) FROM public.world_travel_history h WHERE h.owner_id = new.actor_id) + interval ''3 minutes'' - now())));
    END IF;
  END IF;
  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN (''encounter'', ''combat'') THEN')
  ) as t(fn, a, b) loop
    d := pg_get_functiondef(pat.fn::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '이동 보상 고칠 자리가 하나가 아닙니다: % / %', pat.fn, left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

-- 이동 칭호·꾸미기는 도착만 센다
update public.world_title_catalog set rule = rule || '{"has": "travel_history_id"}'::jsonb
 where (rule ->> 'ev' = 'travel' or rule ->> 'distinct' = 'travel') and not rule ? 'has';
update public.world_cosmetic_catalog set rule = rule || '{"has": "travel_history_id"}'::jsonb
 where (rule ->> 'ev' = 'travel' or rule ->> 'distinct' = 'travel') and not rule ? 'has';

-- 이동 취소: 위약금 없음(대신 3분 동안 다시 출발할 수 없음). 출발 60초 안에만 취소할 수 있는 것은 그대로.
create or replace function public.world_travel_cancel()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; h public.world_travel_history%rowtype;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.travel_arrives_at is null then raise exception '취소할 이동이 없습니다.'; end if;
  select * into h from public.world_travel_history where owner_id = uid and completed_at is null and cancelled_at is null order by started_at desc limit 1 for update;
  if h.id is null then raise exception '취소 가능한 이동 기록이 없습니다.'; end if;
  if now() > h.started_at + interval '60 seconds' then raise exception '출발 후 60초가 지나 이동을 취소할 수 없습니다.'; end if;
  update public.world_characters set travel_destination = null, travel_arrives_at = null, updated_at = now() where owner_id = uid;
  update public.world_travel_history set cancelled_at = now(), cancellation_penalty = 0 where id = h.id;
  -- 취소는 부른 사람의 이동만 멈춘다. 동승 상대의 따로 가는 이동은 그대로 둔다.
  update public.world_travel_party_requests set status = 'cancelled', cancelled_at = now() where (leader_id = uid or passenger_id = uid) and status = 'pending';
  return jsonb_build_object('ok', true, 'content', '이동을 취소했습니다. 3분 동안은 다시 출발할 수 없습니다.', 'penalty', 0, 'cooldown_seconds', 180);
end $$;
grant execute on function public.world_seal_guard() to fn_owner_19257;

-- ② ─────────────────────────────────────────
-- ② 장착한 장비는 가방 칸을 차지하지 않는다.
--   장착해도 물품은 inventory에 남아 world_bag_count가 센다. 장비는 묶음 크기 1이라 장착한 수만큼 가방 용량을 더하면
--   「장착한 것은 세지 않음」과 같다. 가방 용량을 계산하는 곳(world_bag_limit·용량 트리거·원정 귀환·보따리·직접 거래)에 더한다.
--   화면(core.js bagUsed)은 쓴 칸에서 장착한 것을 뺀다.

create or replace function public.world_bag_limit(p_owner uuid)
returns integer language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select c.bag_capacity + case when c.major_faction_id = 'river_alliance' then 6 else 0 end
       + (select count(*)::int from public.world_character_equipment e
           where e.owner_id = c.owner_id and coalesce((c.inventory ->> e.item_id)::numeric, 0) > 0)
  from public.world_characters c where c.owner_id = p_owner
$$;
grant execute on function public.world_bag_limit(uuid) to fn_owner_field;

do $$
declare pat record; d text;
begin
  for pat in select * from (values
    ('public.world_enforce_bag_capacity()',
     'cap int := new.bag_capacity + CASE WHEN new.major_faction_id = ''river_alliance'' THEN 6 ELSE 0 END;',
     'cap int := new.bag_capacity + CASE WHEN new.major_faction_id = ''river_alliance'' THEN 6 ELSE 0 END
    + (SELECT count(*)::int FROM public.world_character_equipment e WHERE e.owner_id = new.owner_id AND coalesce((new.inventory ->> e.item_id)::numeric, 0) > 0);'),
    -- 원정 귀환은 원정 장비가 닳아 이름이 바뀐 뒤의 가방(inv)으로 센다
    ('public.world_expedition_complete(boolean)',
     'cap := c.bag_capacity + case when c.major_faction_id = ''river_alliance'' then 6 else 0 end;',
     'cap := c.bag_capacity + case when c.major_faction_id = ''river_alliance'' then 6 else 0 end
    + (select count(*)::int from public.world_character_equipment e where e.owner_id = c.owner_id and coalesce((inv ->> e.item_id)::numeric, 0) > 0);'),
    ('public.world_overflow_snapshot()',
     'cap := c.bag_capacity + case when c.major_faction_id = ''river_alliance'' then 6 else 0 end;', 'cap := public.world_bag_limit(c.owner_id);'),
    ('public.world_overflow_take(text,integer)',
     'cap := c.bag_capacity + case when c.major_faction_id = ''river_alliance'' then 6 else 0 end;', 'cap := public.world_bag_limit(c.owner_id);'),
    ('public.world_trade_direct_respond(uuid,boolean)',
     'a.bag_capacity + case when a.major_faction_id = ''river_alliance'' then 6 else 0 end', 'public.world_bag_limit(a.owner_id)'),
    ('public.world_trade_direct_respond(uuid,boolean)',
     'b.bag_capacity + case when b.major_faction_id = ''river_alliance'' then 6 else 0 end', 'public.world_bag_limit(b.owner_id)')
  ) as t(fn, a, b) loop
    d := pg_get_functiondef(pat.fn::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '가방 용량 고칠 자리가 하나가 아닙니다: % / %', pat.fn, left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

-- ③ ─────────────────────────────────────────
-- ③ 개인 창고(2026-10-29): 기본 30칸, 어느 안전지대에서 열어도 같은 창고.
--   넓히기(최대 +38 → 68칸): 전으로 4번(+4씩, 1,000·2,500·5,000·10,000전) · 이야기 6~10장 해결 +2씩 ·
--   대세력 평판 300·600·1000 +2씩(세력을 떠나 평판이 내려가면 줄어듦) · 지역 완전 답사 10·20·30곳 +2씩.
--   용량은 그때그때 계산한다(world_storage_capacity). 줄어 넘쳐도 물품은 남고 맡기기만 막힌다.
--   칸은 가방과 같은 묶음 기준(world_bag_count). 맡기기·찾기는 행동 기록(world_events)을 남기지 않고(세력 임무·칭호로 세지 않음),
--   함수 첫머리의 world_seal_guard()와 안전지대·전투불능·이동·원정·자율 활동 검사로 막는다.
--   장착 중인 마지막 하나, 강화한 장비의 마지막 하나(강화가 지워짐), 임무 물품은 맡길 수 없다.
create table if not exists public.world_storage (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  items jsonb not null default '{}'::jsonb,
  bought integer not null default 0 check (bought between 0 and 4),
  updated_at timestamptz not null default now()
);
alter table public.world_storage enable row level security;
revoke all on public.world_storage from public, anon, authenticated;
grant select, insert, update on public.world_storage to fn_owner_field;

-- 창고 용량(기본 30 + 넓히기 · 이야기 · 평판 · 답사)
create or replace function public.world_storage_capacity(p_uid uuid)
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select jsonb_build_object('base', 30, 'bought', b.v, 'story', st.v, 'faction', fa.v, 'survey', sv.v,
           'total', 30 + b.v + st.v + fa.v + sv.v, 'bought_steps', b.n, 'surveyed', sv.n,
           'next_price', (array[1000, 2500, 5000, 10000])[b.n + 1])
    from (select coalesce((select s.bought from public.world_storage s where s.owner_id = p_uid), 0) n) b0,
         lateral (select b0.n n, b0.n * 4 v) b,
         lateral (select 2 * count(*)::int v from public.world_story_chapters ch join public.world_case_progress p
                    on p.owner_id = p_uid and p.case_id = ch.chapter_id
                   where ch.seq between 6 and 10 and coalesce(p.combined, '[]'::jsonb) ? (ch.chapter_id || '_completed')) st,
         lateral (select case when c.major_faction_id is null then 0
                    else 2 * ((coalesce(c.faction_reputation, 0) >= 300)::int + (coalesce(c.faction_reputation, 0) >= 600)::int
                            + (coalesce(c.faction_reputation, 0) >= 1000)::int) end v
                    from public.world_characters c where c.owner_id = p_uid) fa,
         lateral (select x.n, 2 * least(3, x.n / 10) v
                    from (select count(*)::int n from public.world_region_progress r where r.owner_id = p_uid and 'complete' = any (r.milestones)) x) sv
$$;

-- 창고를 열 수 있는지(안전지대·행동 가능) 검사하고 캐릭터 행을 돌려준다
create or replace function public.world_storage_check(p_uid uuid, p_lock boolean)
returns public.world_characters language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype;
begin
  if p_uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_lock then select * into c from public.world_characters where owner_id = p_uid for update;
  else select * into c from public.world_characters where owner_id = p_uid; end if;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) then raise exception '사망한 캐릭터는 창고를 쓸 수 없습니다.'; end if;
  if c.downed_at is not null then raise exception '전투불능 상태에서는 창고를 쓸 수 없습니다.'; end if;
  if c.travel_arrives_at is not null then raise exception '이동 중에는 창고를 쓸 수 없습니다.'; end if;
  if not exists (select 1 from public.world_current_shop(p_uid)) then raise exception '창고는 안전지대에서만 열 수 있습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then raise exception '원정 중에는 창고를 쓸 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities a where a.owner_id = p_uid and a.status = 'active') then raise exception '자율 활동 중에는 창고를 쓸 수 없습니다.'; end if;
  return c;
end $$;

create or replace function public.world_storage_snapshot()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_storage%rowtype; cap int; sc jsonb;
begin
  perform public.world_seal_guard();
  c := public.world_storage_check(uid, false);
  insert into public.world_storage(owner_id) values (uid) on conflict (owner_id) do nothing;
  select * into s from public.world_storage where owner_id = uid;
  cap := public.world_bag_limit(uid);
  sc := public.world_storage_capacity(uid);
  return jsonb_build_object('available', true,
    'items', coalesce((select jsonb_agg(jsonb_build_object('item_id', x.key, 'name', coalesce(i.item_name, x.key), 'qty', x.value::int,
        'rarity', i.rarity, 'category', i.category, 'tier', i.tier, 'stack', public.world_item_stack(x.key),
        'room', public.world_bag_room(c.inventory, x.key, cap)) order by i.category, i.tier, i.item_name)
      from jsonb_each_text(s.items) x left join public.world_item_catalog i on i.item_id = x.key
      where x.value ~ '^[0-9]+$' and x.value::int > 0), '[]'::jsonb),
    'used', public.world_bag_count(s.items), 'capacity', (sc ->> 'total')::int, 'sources', sc, 'gil', c.gil,
    'bag', jsonb_build_object('used', public.world_bag_count(c.inventory), 'limit', cap));
end $$;

-- 맡기기: 창고에 들어가는 만큼만
create or replace function public.world_storage_put(p_item text, p_qty integer default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_storage%rowtype;
  have int; keep int := 0; avail int; room int; n int; nm text;
begin
  perform public.world_seal_guard();
  c := public.world_storage_check(uid, true);
  if p_qty is not null and p_qty < 0 then raise exception '수량이 올바르지 않습니다.'; end if;
  select item_name into nm from public.world_item_catalog where item_id = p_item;
  if nm is null then raise exception '알 수 없는 물품입니다.'; end if;
  if (select category from public.world_item_catalog where item_id = p_item) = 'quest' then raise exception '임무 물품은 창고에 맡길 수 없습니다.'; end if;
  have := coalesce((c.inventory ->> p_item)::int, 0);
  if exists (select 1 from public.world_character_equipment e where e.owner_id = uid and e.item_id = p_item) then keep := 1; end if;
  if exists (select 1 from public.world_gear_enhance g where g.owner_id = uid and g.item_id = p_item) then keep := greatest(keep, 1); end if;
  avail := have - keep;
  if avail <= 0 then
    if have > 0 and keep > 0 then raise exception '장착 중이거나 강화한 장비의 마지막 하나는 맡길 수 없습니다.'; end if;
    raise exception '가방에 그 물품이 없습니다.';
  end if;
  insert into public.world_storage(owner_id) values (uid) on conflict (owner_id) do nothing;
  select * into s from public.world_storage where owner_id = uid for update;
  room := public.world_bag_room(s.items, p_item, (public.world_storage_capacity(uid) ->> 'total')::int);
  n := least(avail, coalesce(nullif(p_qty, 0), avail), room);
  if n <= 0 then raise exception '창고에 자리가 없습니다.'; end if;
  update public.world_characters
     set inventory = case when have - n <= 0 then inventory - p_item else jsonb_set(inventory, array[p_item], to_jsonb(have - n)) end,
         updated_at = now()
   where owner_id = uid;
  update public.world_storage set items = public.world_inv_add(items, p_item, n), updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'moved', n, 'content', nm || ' ×' || n || '을(를) 창고에 맡겼습니다.');
end $$;

-- 찾기: 가방에 들어가는 만큼만
create or replace function public.world_storage_take(p_item text, p_qty integer default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_storage%rowtype;
  have int; room int; n int; nm text;
begin
  perform public.world_seal_guard();
  c := public.world_storage_check(uid, true);
  if p_qty is not null and p_qty < 0 then raise exception '수량이 올바르지 않습니다.'; end if;
  select * into s from public.world_storage where owner_id = uid for update;
  have := coalesce((s.items ->> p_item)::int, 0);
  if have <= 0 then raise exception '창고에 그 물품이 없습니다.'; end if;
  nm := coalesce((select item_name from public.world_item_catalog where item_id = p_item), p_item);
  room := public.world_bag_room(c.inventory, p_item, public.world_bag_limit(uid));
  n := least(have, coalesce(nullif(p_qty, 0), have), room);
  if n <= 0 then raise exception '가방에 자리가 없습니다.'; end if;
  update public.world_storage
     set items = case when have - n <= 0 then items - p_item else jsonb_set(items, array[p_item], to_jsonb(have - n)) end, updated_at = now()
   where owner_id = uid;
  update public.world_characters set inventory = public.world_inv_add(coalesce(inventory, '{}'::jsonb), p_item, n), updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'moved', n, 'content', nm || ' ×' || n || '을(를) 창고에서 꺼냈습니다.');
end $$;

-- 넓히기(전): 4번까지 +4칸씩
create or replace function public.world_storage_expand()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_storage%rowtype; price int;
begin
  perform public.world_seal_guard();
  c := public.world_storage_check(uid, true);
  insert into public.world_storage(owner_id) values (uid) on conflict (owner_id) do nothing;
  select * into s from public.world_storage where owner_id = uid for update;
  if s.bought >= 4 then raise exception '창고는 전으로 더 넓힐 수 없습니다. 이야기·세력 평판·지역 답사로 넓어집니다.'; end if;
  price := (array[1000, 2500, 5000, 10000])[s.bought + 1];
  if c.gil < price then raise exception '전이 모자랍니다(%전 필요).', price; end if;
  update public.world_characters set gil = gil - price, updated_at = now() where owner_id = uid;
  update public.world_storage set bought = bought + 1, updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'price', price,
    'content', format('창고를 %s전에 넓혔습니다(+4칸, 이제 %s칸).', price, (public.world_storage_capacity(uid) ->> 'total')));
end $$;

alter function public.world_storage_capacity(uuid) owner to fn_owner_field;
alter function public.world_storage_expand() owner to fn_owner_field;
revoke all on function public.world_storage_capacity(uuid) from public, anon, authenticated;
revoke all on function public.world_storage_expand() from public, anon, authenticated;
grant execute on function public.world_storage_expand() to authenticated;
alter function public.world_storage_check(uuid, boolean) owner to fn_owner_field;
alter function public.world_storage_snapshot() owner to fn_owner_field;
alter function public.world_storage_put(text, integer) owner to fn_owner_field;
alter function public.world_storage_take(text, integer) owner to fn_owner_field;
revoke all on function public.world_storage_check(uuid, boolean) from public, anon, authenticated;
revoke all on function public.world_storage_snapshot() from public, anon, authenticated;
revoke all on function public.world_storage_put(text, integer) from public, anon, authenticated;
revoke all on function public.world_storage_take(text, integer) from public, anon, authenticated;
grant execute on function public.world_storage_snapshot() to authenticated;
grant execute on function public.world_storage_put(text, integer) to authenticated;
grant execute on function public.world_storage_take(text, integer) to authenticated;

grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_expedition to postgres with inherit false, set false;
grant fn_owner_18473 to postgres with inherit false, set false;
grant fn_owner_18941 to postgres with inherit false, set false;
grant fn_owner_18962 to postgres with inherit false, set false;
grant fn_owner_20175 to postgres with inherit false, set false;
grant fn_owner_18540 to postgres with inherit false, set false;
grant fn_owner_19257 to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029030000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
