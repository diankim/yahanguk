create or replace function public.world_project_rule(p_key text)
 returns jsonb language sql immutable set search_path = pg_catalog, public
as $f$ select public.world_project_rules() -> 'projects' -> p_key $f$;

create or replace function public.world_project_stage(p_key text)
 returns int language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
begin
  return coalesce((select p.stage from public.world_projects p where p.project_key = p_key), 0);
end $f$;

create or replace function public.world_project_items(p_key text, p_stage int)
 returns text[] language sql immutable set search_path = pg_catalog, public
as $f$
  select array(select jsonb_array_elements_text(s -> 'craft')) || array(select jsonb_array_elements_text(s -> 'gather'))
    from (select public.world_project_rule(p_key) -> 'stages' -> least(greatest(p_stage, 0), 4) s) z
$f$;

create or replace function public.world_project_urgent(p_key text, p_stage int, p_day date)
 returns text[] language sql immutable set search_path = pg_catalog, public
as $f$
  select array(select x from unnest(public.world_project_items(p_key, p_stage)) x
                order by md5(p_key || ':' || p_stage || ':' || p_day::text || ':' || x)
                limit (public.world_project_rules() -> 'urgent' ->> 'n')::int)
$f$;

create or replace function public.world_project_n(p_key text, p_at timestamptz)
 returns int language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare p jsonb := public.world_project_rule(p_key); g jsonb := public.world_project_rules() -> 'goal'; n int;
begin
  if p ->> 'kind' = 'faction' then
    select count(*) into n from public.world_active_actors(p_at, (g ->> 'window_h')::int, (g ->> 'active_min')::int) a
      join public.world_characters c on c.owner_id = a.actor_id where c.major_faction_id = p ->> 'faction';
  else
    select count(*) into n from public.world_active_actors(p_at, (g ->> 'window_h')::int, (g ->> 'active_min')::int) a
      join public.world_characters c on c.owner_id = a.actor_id where public.world_domain_open(c.owner_id, p ->> 'domain');
  end if;
  return greatest(1, coalesce(n, 1));
end $f$;

create or replace function public.world_project_goal(p_key text, p_stage int, p_n int)
 returns bigint language sql immutable set search_path = pg_catalog, public
as $f$
  select case when p_stage >= 5 then 0 else
    round(((public.world_project_rule(p_key) -> 'stages' -> p_stage ->> 'base')::numeric) * greatest(1, sqrt(greatest(p_n, 1)::numeric)))::bigint end
$f$;

create or replace function public.world_project_member(p_uid uuid, p_key text)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare p jsonb := public.world_project_rule(p_key);
begin
  if p is null or p_uid is null then return false; end if;
  if p ->> 'kind' = 'faction' then
    return exists (select 1 from public.world_characters c join public.world_faction_progress fp on fp.owner_id = c.owner_id and fp.faction_id = c.major_faction_id
                    where c.owner_id = p_uid and c.major_faction_id = p ->> 'faction' and fp.join_done_at is not null);
  end if;
  return public.world_domain_open(p_uid, p ->> 'domain');
end $f$;

create or replace function public.world_project_story(p_uid uuid, p_key text)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare p jsonb := public.world_project_rule(p_key);
begin
  if p is null or p_uid is null then return false; end if;
  if p ->> 'kind' = 'faction' then return public.world_project_member(p_uid, p_key); end if;
  return public.world_quest_done(p_uid, p ->> 'story');
end $f$;

create or replace function public.world_project_at(p_uid uuid)
 returns text language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rid text; fac text; k text; p jsonb;
begin
  select (public.world_region_at(c.location)).region_id, c.major_faction_id into rid, fac from public.world_characters c where c.owner_id = p_uid;
  if rid is null then return null; end if;
  for k, p in select key, value from jsonb_each(public.world_project_rules() -> 'projects') loop
    if p -> 'hubs' ? rid and (p ->> 'kind' = 'common' or p ->> 'faction' = fac) then return k; end if;
  end loop;
  return null;
end $f$;

create or replace function public.world_project_text(p_key text, p_stage int)
 returns text language sql immutable set search_path = pg_catalog, public
as $f$
  select public.world_project_rules() -> 'perk_text' -> (public.world_project_rule(p_key) ->> 'kind') ->> (p_stage - 1)
$f$;

create or replace function public.world_project_stage_up(p_key text, p_giver uuid)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare p jsonb := public.world_project_rule(p_key); r jsonb := public.world_project_rules(); m jsonb := r -> 'memento'; pr public.world_projects%rowtype;
  done int; need bigint; carry bigint; who uuid; got uuid[] := '{}'; v_gil bigint := 0; fac boolean := p ->> 'kind' = 'faction'; place text; msg text; x record;
begin
  select * into pr from public.world_projects where project_key = p_key;
  if pr.stage >= 5 or pr.points < pr.goal or pr.goal <= 0 then return null; end if;
  done := pr.stage + 1;
  need := ceil(pr.goal * (m ->> 'pct')::numeric / 100);
  carry := pr.points - pr.goal;
  if not fac then v_gil := floor(pr.goal * (m ->> 'common_gil_pct')::numeric / 100); end if;
  for x in select c.owner_id from public.world_project_contrib c where c.project_key = p_key and c.cur >= need order by c.owner_id loop
    got := got || x.owner_id;
    update public.world_project_contrib set marks = marks || done where project_key = p_key and owner_id = x.owner_id;
    insert into public.world_storage(owner_id, items) values (x.owner_id, jsonb_build_object(m ->> 'cake', (m ->> 'cake_n')::int))
    on conflict (owner_id) do update set items = public.world_inv_add(world_storage.items, m ->> 'cake', (m ->> 'cake_n')::int), updated_at = now();
    if fac then
      update public.world_faction_progress set merit = merit + (m ->> 'faction_merit')::int, updated_at = now() where owner_id = x.owner_id and faction_id = p ->> 'faction';
      if done = 5 then
        update public.world_storage set items = public.world_inv_add(items, m ->> 'plaque', 1), updated_at = now() where owner_id = x.owner_id;
      end if;
    else
      update public.world_characters set gil = gil + v_gil, updated_at = now() where owner_id = x.owner_id;
      insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (x.owner_id, 'project_memento', v_gil, false, jsonb_build_object('project', p_key, 'stage', done));
      if done = 5 then
        insert into public.world_character_cosmetics(owner_id, cosmetic_key) values (x.owner_id, m ->> 'seal') on conflict do nothing;
      end if;
    end if;
  end loop;
  update public.world_project_contrib set cur = 0, updated_at = now() where project_key = p_key and cur <> 0;
  if carry > 0 and p_giver is not null then
    update public.world_project_contrib set cur = carry where project_key = p_key and owner_id = p_giver;
  end if;
  update public.world_projects set stage = done, stage_at = stage_at || now(),
    points = case when done >= 5 then 0 else carry end,
    goal = public.world_project_goal(p_key, done, goal_n), updated_at = now() where project_key = p_key;
  place := case when fac then public.world_mf_name(p ->> 'faction') || ' 거점 사업' else (public.world_domain_rules() -> (p ->> 'domain') ->> 'name') || ' 공동 사업' end;
  msg := place || ' 「' || (p ->> 'name') || '」 ' || done || '단계를 마쳤습니다. ' || coalesce(public.world_project_text(p_key, done), '');
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select c.owner_id, 'project_stage', '사업 ' || done || '단계 마침', msg ||
      case when c.owner_id = any (got) then ' 힘을 보탠 몫으로 낙성 떡을 창고에 넣었습니다' ||
        case when fac then ' · 공훈 +' || (m ->> 'faction_merit') else ' · ' || v_gil || '전' end ||
        case when done = 5 then case when fac then ' · 낙성 기념패' else ' · 낙관 「拓」' end else '' end || '.' else '' end,
    jsonb_build_object('project', p_key, 'stage', done)
    from public.world_characters c
   where not coalesce(c.is_dead, false) and (case when fac then c.major_faction_id = p ->> 'faction' else public.world_domain_open(c.owner_id, p ->> 'domain') end or c.owner_id = any (got));
  if fac and done = 5 then
    insert into public.world_character_cosmetics(owner_id, cosmetic_key)
    select c.owner_id, p -> 'pattern' ->> 0 from public.world_characters c where c.major_faction_id = p ->> 'faction' on conflict do nothing;
  end if;
  who := coalesce(p_giver, got[1]);
  if who is not null then
    insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
    values ('global', who, case when fac then '세력 소식' else '사업 소식' end, place || ' 「' || (p ->> 'name') || '」이(가) ' || done || '단계를 마쳤습니다.');
  end if;
  foreach who in array got loop perform public.world_title_award_check(who, 'project'); end loop;
  return jsonb_build_object('stage', done, 'got', to_jsonb(got));
end $f$;

create or replace function public.world_project_have(p_uid uuid, p_inv jsonb, p_st jsonb, p_item text)
 returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $f$
  select jsonb_build_object('have', public.world_give_check(p_uid, p_item, p_inv), 'have_hq', public.world_give_check(p_uid, p_item || '_hq', p_inv),
    'have_st', case when p_st is null or exists (select 1 from public.world_item_locks l where l.owner_id = p_uid and l.item_id = p_item) then 0 else greatest(0, coalesce((p_st ->> p_item)::int, 0)) end,
    'have_st_hq', case when p_st is null or exists (select 1 from public.world_item_locks l where l.owner_id = p_uid and l.item_id = p_item || '_hq') then 0 else greatest(0, coalesce((p_st ->> (p_item || '_hq'))::int, 0)) end)
$f$;

create or replace function public.world_project_st_ok(p_uid uuid)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
begin
  return exists (select 1 from public.world_current_shop(p_uid)) and not public.world_weak_here(p_uid, 'storage');
end $f$;

create or replace function public.world_project_view(p_key text default null)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); k text := p_key; p jsonb; r jsonb := public.world_project_rules(); pr public.world_projects%rowtype; ct public.world_project_contrib%rowtype;
  c public.world_characters%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; st jsonb; items jsonb; urg text[]; rid text; why text; cap int; fac boolean; sg int; story boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if k is null then k := public.world_project_at(uid); end if;
  if k is null and c.major_faction_id is not null then k := 'f:' || c.major_faction_id; end if;
  p := public.world_project_rule(k);
  if p is null then raise exception '여기에는 사업이 없습니다.'; end if;
  fac := p ->> 'kind' = 'faction';
  select * into pr from public.world_projects where project_key = k;
  select * into ct from public.world_project_contrib where project_key = k and owner_id = uid;
  rid := (public.world_region_at(c.location)).region_id;
  if public.world_project_st_ok(uid) then select s.items into st from public.world_storage s where s.owner_id = uid; st := coalesce(st, '{}'::jsonb); end if;
  sg := least(pr.stage, 4);
  urg := public.world_project_urgent(k, sg, today);
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'name', i.item_name, 'tier', i.tier, 'category', i.category, 'v', (r -> 'v' ->> x.id)::int,
           'kind', case when x.o <= 4 then 'craft' else 'gather' end, 'urgent', x.id = any (urg))
           || public.world_project_have(uid, c.inventory, st, x.id) order by x.o), '[]'::jsonb)
    into items from unnest(public.world_project_items(k, sg)) with ordinality x(id, o) join public.world_item_catalog i on i.item_id = x.id;
  cap := ((r -> 'pay' -> (p ->> 'kind')) ->> 'day_cap')::int;
  story := public.world_project_story(uid, k);
  why := case when not public.world_project_member(uid, k) then case when fac then '그 세력에 들어 가입 퀘스트를 마친 조사원만 넘길 수 있습니다.' else '그 땅이 열린 조사원만 넘길 수 있습니다.' end
    when not (p -> 'hubs' ? coalesce(rid, '')) then (select string_agg(m.region_name, '·') from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(p -> 'hubs'))) || '에서 넘깁니다.'
    when c.downed_at is not null or c.health <= 0 then '전투불능 상태에서는 넘길 수 없습니다.'
    when coalesce(ct.day, today - 1) = today and ct.day_pts >= cap then '오늘은 더 받지 않습니다(하루 ' || cap || '몫까지).'
    else null end;
  if fac and pr.stage >= 5 and story and not exists (select 1 from public.world_character_cosmetics cc where cc.owner_id = uid and cc.cosmetic_key = p -> 'pattern' ->> 0) then
    insert into public.world_character_cosmetics(owner_id, cosmetic_key) values (uid, p -> 'pattern' ->> 0) on conflict do nothing;
  end if;
  return jsonb_build_object('key', k, 'kind', p ->> 'kind', 'name', p ->> 'name', 'stage', pr.stage, 'points', pr.points, 'goal', pr.goal, 'goal_n', pr.goal_n, 'total', pr.total,
    'stage_at', to_jsonb(pr.stage_at), 'place', case when fac then public.world_mf_name(p ->> 'faction') else public.world_domain_rules() -> (p ->> 'domain') ->> 'name' end,
    'hubs', (select jsonb_agg(m.region_name) from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(p -> 'hubs'))),
    'items', items, 'storage', st is not null,
    'today', jsonb_build_object('pts', case when ct.day = today then ct.day_pts else 0 end, 'cap', cap),
    'mine', jsonb_build_object('total', coalesce(ct.total, 0), 'cur', coalesce(ct.cur, 0), 'marks', to_jsonb(coalesce(ct.marks, '{}'::int[])),
      'need', ceil(pr.goal * (r -> 'memento' ->> 'pct')::numeric / 100)),
    'givers', (select count(*) from public.world_project_contrib x where x.project_key = k and x.cur > 0),
    'perks', (select jsonb_agg(jsonb_build_object('stage', g, 'done', pr.stage >= g, 'text', public.world_project_text(k, g))) from generate_series(1, 5) g),
    'can', jsonb_build_object('give', why is null, 'why', why),
    'benefit', jsonb_build_object('ok', story, 'why', case when story then null when fac then '그 세력 조사원만 혜택을 받습니다.'
      else '혜택은 「' || coalesce((select q.title from public.world_quests q where q.quest_id = p ->> 'story'), p ->> 'story') || '」을(를) 마친 조사원만 받습니다.' end),
    'after', pr.stage >= 5);
end $f$;

create or replace function public.world_project_give(p_key text, p_items jsonb)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); p jsonb := public.world_project_rule(p_key); r jsonb := public.world_project_rules(); c public.world_characters%rowtype;
  pr public.world_projects%rowtype; ct public.world_project_contrib%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; fac boolean;
  inv jsonb; st jsonb; st_ok boolean; e record; base text; hq boolean; q int; free_inv int; take_inv int; take_st int; allowed text[]; urg text[]; mul numeric;
  pts bigint := 0; cap int; m numeric := 1; gain bigint := 0; before_pts int; rid text; ups jsonb := '[]'::jsonb; up jsonb; used_st boolean := false; n_items int := 0;
  before_total bigint; th bigint; nm text;
begin perform public.world_travel_guard('사업 납품');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p is null then raise exception '없는 사업입니다.'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'object' or p_items = '{}'::jsonb then raise exception '넘길 물품을 고르세요.'; end if;
  fac := p ->> 'kind' = 'faction';
  perform 1 from public.world_projects where project_key = p_key for update;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 넘길 수 없습니다.'; end if;
  if not public.world_project_member(uid, p_key) then
    raise exception '%', case when fac then '그 세력에 들어 가입 퀘스트를 마친 조사원만 넘길 수 있습니다.' else '그 땅이 열린 조사원만 넘길 수 있습니다.' end;
  end if;
  rid := (public.world_region_at(c.location)).region_id;
  if not (p -> 'hubs' ? coalesce(rid, '')) then
    raise exception '%에서 넘깁니다.', (select string_agg(mr.region_name, '·') from public.world_map_regions mr where mr.region_id in (select jsonb_array_elements_text(p -> 'hubs')));
  end if;
  st_ok := public.world_project_st_ok(uid);
  if st_ok then
    insert into public.world_storage(owner_id) values (uid) on conflict do nothing;
    select s.items into st from public.world_storage s where s.owner_id = uid for update;
  end if;
  select * into pr from public.world_projects where project_key = p_key;
  if pr.goal_day is distinct from today and pr.stage < 5 then
    pr.goal_n := public.world_project_n(p_key, now());
    update public.world_projects set goal_n = pr.goal_n, goal = public.world_project_goal(p_key, stage, pr.goal_n), goal_day = today where project_key = p_key
      returning * into pr;
  end if;
  insert into public.world_project_contrib(project_key, owner_id, day) values (p_key, uid, today) on conflict do nothing;
  select * into ct from public.world_project_contrib where project_key = p_key and owner_id = uid for update;
  before_pts := case when ct.day = today then ct.day_pts else 0 end;
  before_total := ct.total;
  cap := ((r -> 'pay' -> (p ->> 'kind')) ->> 'day_cap')::int;
  if before_pts >= cap then raise exception '오늘은 더 받지 않습니다(하루 %몫까지). 내일 다시 오세요.', cap; end if;
  allowed := public.world_project_items(p_key, least(pr.stage, 4));
  urg := public.world_project_urgent(p_key, least(pr.stage, 4), today);
  inv := coalesce(c.inventory, '{}'::jsonb);
  for e in select key, value from jsonb_each(p_items) loop
    if jsonb_typeof(e.value) <> 'number' or (e.value)::text::numeric <> floor((e.value)::text::numeric) or (e.value)::text::int < 1 or (e.value)::text::int > 999 then
      raise exception '수량이 올바르지 않습니다.'; end if;
    q := (e.value)::text::int;
    base := public.world_item_base(e.key); hq := base <> e.key;
    nm := coalesce((select item_name from public.world_item_catalog where item_id = e.key), e.key);
    if not (base = any (allowed)) then raise exception '「%」은(는) 지금 단계에서 받는 물품이 아닙니다.', nm; end if;
    free_inv := public.world_give_check(uid, e.key, inv);
    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = e.key) then raise exception '「%」은(는) 잠가 둔 물품입니다.', nm; end if;
    take_inv := least(q, free_inv);
    take_st := q - take_inv;
    if take_st > 0 and (not st_ok or coalesce((st ->> e.key)::int, 0) < take_st) then
      raise exception '「%」이(가) 모자랍니다(넘길 수 있는 것 %개 — 장착 중·강화한 것은 빠집니다).', nm, take_inv + case when st_ok then greatest(0, coalesce((st ->> e.key)::int, 0)) else 0 end;
    end if;
    if take_inv > 0 then inv := public.world_inv_add(inv, e.key, -take_inv); end if;
    if take_st > 0 then
      st := case when coalesce((st ->> e.key)::int, 0) - take_st <= 0 then st - e.key else jsonb_set(st, array[e.key], to_jsonb(coalesce((st ->> e.key)::int, 0) - take_st)) end;
      used_st := true;
    end if;
    mul := least((r ->> 'mul_cap')::numeric, case when base = any (urg) then (r -> 'urgent' ->> 'mul')::numeric else 1 end * case when hq then (r ->> 'hq_mul')::numeric else 1 end);
    pts := pts + floor((r -> 'v' ->> base)::numeric * mul * q)::bigint;
    n_items := n_items + q;
  end loop;
  if pts <= 0 then raise exception '넘길 물품을 고르세요.'; end if;
  if pr.stage >= 5 then m := (r -> 'pay' ->> 'after_mul')::numeric; end if;
  if fac then
    gain := floor((before_pts + pts) * m / ((r -> 'pay' -> 'faction' ->> 'per_merit')::numeric)) - floor(before_pts * m / ((r -> 'pay' -> 'faction' ->> 'per_merit')::numeric));
  else
    gain := floor((before_pts + pts) * m * (r -> 'pay' -> 'common' ->> 'gil_rate')::numeric) - floor(before_pts * m * (r -> 'pay' -> 'common' ->> 'gil_rate')::numeric);
  end if;
  perform set_config('yh.wear_leaves', 'on', true);
  update public.world_characters set inventory = inv, gil = gil + case when fac then 0 else gain end, updated_at = now() where owner_id = uid;
  if used_st then update public.world_storage set items = st, updated_at = now() where owner_id = uid; end if;
  if fac and gain > 0 then
    update public.world_faction_progress set merit = merit + gain::int, updated_at = now() where owner_id = uid and faction_id = p ->> 'faction';
  end if;
  if not fac and gain > 0 then
    insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'project_give', gain, false, jsonb_build_object('project', p_key, 'pts', pts));
  end if;
  update public.world_project_contrib set total = total + pts, cur = cur + case when pr.stage >= 5 then 0 else pts end, day = today, day_pts = before_pts + pts::int, updated_at = now()
   where project_key = p_key and owner_id = uid;
  update public.world_projects set total = total + pts, points = points + case when stage >= 5 then 0 else pts end, updated_at = now() where project_key = p_key;
  loop
    up := public.world_project_stage_up(p_key, uid);
    exit when up is null;
    ups := ups || up;
  end loop;
  for th in select distinct ((t.rule ->> 'n')::bigint) from public.world_title_catalog t where t.rule ? 'project' and (t.rule ->> 'project' like '%:%' or t.rule ->> 'project' in ('faction', 'common')) loop
    if before_total < th and before_total + pts >= th then perform public.world_title_award_check(uid, 'project'); exit; end if;
  end loop;
  return jsonb_build_object('pts', pts, 'n', n_items, 'merit', case when fac then gain else 0 end, 'gil', case when fac then 0 else gain end, 'from_storage', used_st,
    'today', before_pts + pts, 'cap', cap, 'stage_up', ups,
    'content', n_items || '개를 넘겼습니다 · ' || pts || '몫 · ' || case when fac then '공훈 +' || gain else gain || '전' end ||
      case when before_pts + pts >= cap then ' · 오늘 상한에 닿았습니다.' else ' · 오늘 ' || (before_pts + pts) || '/' || cap end ||
      case when jsonb_array_length(ups) > 0 then ' · 사업이 ' || (ups -> -1 ->> 'stage') || '단계를 마쳤습니다!' else '' end,
    'view', public.world_project_view(p_key));
end $f$;

create or replace function public.world_project_brief(p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare k text := public.world_project_at(p_uid); pr public.world_projects%rowtype; fac text; urg text[] := '{}'; x text; today date := (now() at time zone 'Asia/Seoul')::date; here jsonb;
begin
  select c.major_faction_id into fac from public.world_characters c where c.owner_id = p_uid;
  if k is not null then
    select * into pr from public.world_projects where project_key = k;
    here := jsonb_build_object('key', k, 'name', public.world_project_rule(k) ->> 'name', 'kind', public.world_project_rule(k) ->> 'kind', 'stage', pr.stage,
      'pct', case when pr.stage >= 5 or pr.goal <= 0 then 100 else least(99, floor(pr.points * 100.0 / pr.goal))::int end);
  end if;
  for x in select key from jsonb_each(public.world_project_rules() -> 'projects') loop
    if (x = 'f:' || coalesce(fac, '')) or (x like 'c:%' and public.world_project_member(p_uid, x)) then
      select array(select u from unnest(public.world_project_urgent(x, least(public.world_project_stage(x), 4), today)) u
                    where u = any (array(select jsonb_array_elements_text(public.world_project_rule(x) -> 'stages' -> least(public.world_project_stage(x), 4) -> 'gather')))) || urg into urg;
    end if;
  end loop;
  return jsonb_build_object('here', here, 'urgent', to_jsonb(array(select distinct u from unnest(urg) u)));
end $f$;

create or replace function public.world_project_rule_count(p_owner uuid, p_rule jsonb)
 returns numeric language sql stable security definer set search_path = pg_catalog, public
as $f$
  select case
    when p_rule ->> 'project' = 'faction' then coalesce((select sum(total) from public.world_project_contrib where owner_id = p_owner and project_key like 'f:%'), 0)
    when p_rule ->> 'project' = 'common' then coalesce((select sum(total) from public.world_project_contrib where owner_id = p_owner and project_key like 'c:%'), 0)
    when p_rule ->> 'project' = 'f_stages' then coalesce((select max((select count(distinct m) from unnest(marks) m)) from public.world_project_contrib where owner_id = p_owner and project_key like 'f:%'), 0)
    when p_rule ->> 'project' = 'c_last' then (select count(*) from public.world_project_contrib where owner_id = p_owner and project_key like 'c:%' and 5 = any (marks))
    else coalesce((select total from public.world_project_contrib where owner_id = p_owner and project_key = p_rule ->> 'project'), 0) end::numeric
$f$;

insert into public.world_projects(project_key, goal, goal_n)
select k, public.world_project_goal(k, 0, 1), 1 from jsonb_object_keys(public.world_project_rules() -> 'projects') k
on conflict (project_key) do nothing;
