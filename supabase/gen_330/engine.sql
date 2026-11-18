create table if not exists public.world_regular_progress (
  owner_id uuid not null,
  npc text not null,
  aff int not null default 0,
  total int not null default 0,
  day date,
  done int[] not null default '{}',
  updated_at timestamptz not null default now(),
  primary key (owner_id, npc)
);
create table if not exists public.world_regular_day (
  owner_id uuid primary key,
  day date not null,
  n int not null default 0
);
alter table public.world_regular_progress enable row level security;
alter table public.world_regular_day enable row level security;
revoke all on public.world_regular_progress from public, anon, authenticated;
revoke all on public.world_regular_day from public, anon, authenticated;
grant select, insert, update, delete on public.world_regular_progress, public.world_regular_day to fn_owner_field;

create or replace function public.world_regular_rule(p_npc text)
 returns jsonb language sql immutable set search_path = pg_catalog, public
as $f$ select public.world_regular_rules() -> 'npcs' -> p_npc $f$;

create or replace function public.world_regular_stage(p_aff int)
 returns int language sql immutable set search_path = pg_catalog, public
as $f$
  select greatest(1, (select count(*) from jsonb_array_elements_text(public.world_regular_rules() -> 'aff' -> 'stages') s where s::int <= coalesce(p_aff, 0))::int)
$f$;

create or replace function public.world_regular_next(p_aff int)
 returns int language sql immutable set search_path = pg_catalog, public
as $f$
  select min(s::int) from jsonb_array_elements_text(public.world_regular_rules() -> 'aff' -> 'stages') s where s::int > coalesce(p_aff, 0)
$f$;

create or replace function public.world_regular_open(p_uid uuid, p_npc text)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
begin
  return p_uid is not null and public.world_regular_rule(p_npc) is not null and public.world_quest_done(p_uid, public.world_regular_rule(p_npc) ->> 'open');
end $f$;

create or replace function public.world_regular_aff(p_uid uuid, p_npc text)
 returns int language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
begin
  return coalesce((select g.aff from public.world_regular_progress g where g.owner_id = p_uid and g.npc = p_npc), 0);
end $f$;

create or replace function public.world_regular_stage_of(p_uid uuid, p_npc text)
 returns int language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
begin
  if not public.world_regular_open(p_uid, p_npc) then return 0; end if;
  return public.world_regular_stage(public.world_regular_aff(p_uid, p_npc));
end $f$;

create or replace function public.world_regular_rank(p_uid uuid, p_line text)
 returns int language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
begin
  return greatest(1, coalesce((select (c.skill_progress -> p_line ->> 'rank')::int from public.world_characters c where c.owner_id = p_uid), 1));
end $f$;

create or replace function public.world_regular_pool(p_line text, p_rank int)
 returns text[] language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_regular_rules(); span int := (r ->> 'span')::int; hi int := greatest(p_rank, 5); lo int := greatest(1, p_rank - span); out text[];
begin
  for pass in 1 .. 2 loop
    if p_line = 'fishing' then
      select array_agg(distinct f.fish_id order by f.fish_id) into out from public.world_fish_species f join public.world_item_catalog i on i.item_id = f.fish_id
       where f.active and not coalesce(f.named, false) and f.min_level <= hi and f.min_level >= case when pass = 1 then lo - 3 else 0 end
         and i.tradeable and not coalesce(i.market_only, false);
    elsif r -> 'lines' ? p_line then
      select array_agg(distinct x order by x) into out from public.world_gathering_spots s, unnest(s.loot_items) x join public.world_item_catalog i on i.item_id = x
       where s.active and s.category = any (array(select jsonb_array_elements_text(r -> 'lines' -> p_line)))
         and s.min_level <= hi and s.min_level >= case when pass = 1 then lo - 3 else 0 end
         and i.tradeable and not coalesce(i.market_only, false) and i.category = 'material';
    else
      select array_agg(distinct w.output_item order by w.output_item) into out from public.world_crafting_recipes w join public.world_item_catalog i on i.item_id = w.output_item
       where public.world_craft_line_of(w.craft_field) = p_line and coalesce(w.minimum_level, 1) <= hi and coalesce(w.minimum_level, 1) >= case when pass = 1 then lo else 0 end
         and i.tradeable and not coalesce(i.market_only, false) and i.base_item_id is null and i.category not in ('furniture', 'outfit', 'pet', 'quest');
    end if;
    exit when coalesce(array_length(out, 1), 0) >= (r ->> 'orders')::int;
  end loop;
  return coalesce(out, '{}');
end $f$;

create or replace function public.world_regular_orders(p_uid uuid, p_npc text, p_day date)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_regular_rules(); n jsonb := public.world_regular_rule(p_npc); line text := n ->> 'line'; rk int; out jsonb;
begin
  if n is null then return '[]'::jsonb; end if;
  rk := public.world_regular_rank(p_uid, line);
  select coalesce(jsonb_agg(jsonb_build_object('i', z.o - 1, 'id', z.x, 'qty',
           case when line = 'fishing' then (r -> 'qty' ->> 'fish')::int when r -> 'lines' ? line then (r -> 'qty' ->> 'gather')::int
                when i.category = any (array(select jsonb_array_elements_text(r -> 'gear'))) then (r -> 'qty' ->> 'gear')::int else (r -> 'qty' ->> 'item')::int end)
         order by z.o), '[]'::jsonb)
    into out
    from (select x, row_number() over (order by md5(p_uid::text || ':' || p_npc || ':' || p_day::text || ':' || x)) o
            from unnest(public.world_regular_pool(line, rk)) x) z
    join public.world_item_catalog i on i.item_id = z.x
   where z.o <= (r ->> 'orders')::int;
  return out;
end $f$;

create or replace function public.world_regular_day_n(p_uid uuid, p_day date)
 returns int language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
begin
  return coalesce((select d.n from public.world_regular_day d where d.owner_id = p_uid and d.day = p_day), 0);
end $f$;

create or replace function public.world_regular_here(p_uid uuid)
 returns text language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rid text;
begin
  select (public.world_region_at(c.location)).region_id into rid from public.world_characters c where c.owner_id = p_uid;
  return (select e.key from jsonb_each(public.world_regular_rules() -> 'npcs') e where e.value ->> 'region' = rid order by (e.value ->> 'sort')::int limit 1);
end $f$;

create or replace function public.world_regular_xp(p_rank int, p_hq boolean)
 returns int language sql immutable set search_path = pg_catalog, public
as $f$
  select case when p_rank >= 50 then 0 else
    floor(greatest((public.world_regular_rules() -> 'xp' ->> 'min')::numeric,
      ceil((public.world_skill_line_xp(p_rank + 1) - public.world_skill_line_xp(p_rank)) * (public.world_regular_rules() -> 'xp' ->> 'pct')::numeric / 100))
      * case when p_hq then (public.world_regular_rules() -> 'xp' ->> 'hq_mul')::numeric else 1 end)::int end
$f$;

create or replace function public.world_regular_view(p_npc text default null)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); k text := p_npc; n jsonb; r jsonb := public.world_regular_rules(); c public.world_characters%rowtype; g public.world_regular_progress%rowtype;
  today date := (now() at time zone 'Asia/Seoul')::date; st jsonb; orders jsonb; rk int; why text; dn int; day_n int; aff int; done int[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if k is null then k := public.world_regular_here(uid); end if;
  n := public.world_regular_rule(k);
  if n is null or not public.world_regular_open(uid, k) then raise exception '아직 단골로 지내는 사람이 아닙니다.'; end if;
  select * into g from public.world_regular_progress where owner_id = uid and npc = k;
  aff := coalesce(g.aff, 0);
  done := case when g.day = today then g.done else '{}' end;
  if public.world_project_st_ok(uid) then select s.items into st from public.world_storage s where s.owner_id = uid; st := coalesce(st, '{}'::jsonb); end if;
  rk := public.world_regular_rank(uid, n ->> 'line');
  select coalesce(jsonb_agg(o || jsonb_build_object('name', i.item_name, 'tier', i.tier, 'category', i.category, 'done', (o ->> 'i')::int = any (done),
           'hq_ok', exists (select 1 from public.world_item_catalog h where h.item_id = (o ->> 'id') || '_hq'),
           'gil', floor(coalesce(i.reference_price, 0) * (o ->> 'qty')::int * (r -> 'gil' ->> 'rate')::numeric + (r -> 'gil' ->> 'base')::numeric)::int)
           || public.world_project_have(uid, c.inventory, st, o ->> 'id') order by (o ->> 'i')::int), '[]'::jsonb)
    into orders from jsonb_array_elements(public.world_regular_orders(uid, k, today)) o join public.world_item_catalog i on i.item_id = o ->> 'id';
  day_n := (r ->> 'day_n')::int;
  dn := public.world_regular_day_n(uid, today);
  why := case when (public.world_region_at(c.location)).region_id is distinct from n ->> 'region'
      then (select m.region_name from public.world_map_regions m where m.region_id = n ->> 'region') || '에서 넘깁니다.'
    when c.downed_at is not null or c.health <= 0 then '전투불능 상태에서는 넘길 수 없습니다.'
    when dn >= day_n then '오늘 납품은 다 했습니다(모든 단골을 합쳐 하루 ' || day_n || '번).'
    else null end;
  return jsonb_build_object('npc', k, 'name', n ->> 'name', 'short', n ->> 'short', 'line', n ->> 'line', 'line_name', public.world_line_name(n ->> 'line'), 'rank', rk,
    'xp', public.world_regular_xp(rk, false), 'xp_hq', public.world_regular_xp(rk, true),
    'region', n ->> 'region', 'place', (select m.region_name from public.world_map_regions m where m.region_id = n ->> 'region'),
    'aff', aff, 'stage', public.world_regular_stage(aff), 'next', public.world_regular_next(aff), 'cap', (r -> 'aff' ->> 'cap')::int, 'total', coalesce(g.total, 0),
    'title', n ->> 'title_name',
    'orders', orders, 'storage', st is not null, 'today', jsonb_build_object('n', dn, 'cap', day_n),
    'quests', (select jsonb_agg(jsonb_build_object('n', s, 'id', (n ->> 'key') || '_' || s, 'done', public.world_quest_done(uid, (n ->> 'key') || '_' || s),
                 'open', public.world_regular_stage(aff) >= s) order by s) from generate_series(1, 5) s),
    'can', jsonb_build_object('give', why is null, 'why', why));
end $f$;

create or replace function public.world_regular_give(p_npc text, p_order int, p_hq boolean default false)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); nr jsonb := public.world_regular_rule(p_npc); r jsonb := public.world_regular_rules(); c public.world_characters%rowtype;
  g public.world_regular_progress%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; o jsonb; id text; q int; nm text; inv jsonb; st jsonb; st_ok boolean;
  free_inv int; take_inv int; take_st int; rk int; xp int; v_gil int; add int; aff0 int; aff1 int; s0 int; s1 int; dn int; v_done int[]; used_st jsonb := '{}'::jsonb; line text;
begin
  perform public.world_travel_guard('단골 납품');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if nr is null then raise exception '없는 단골입니다.'; end if;
  if not public.world_regular_open(uid, p_npc) then raise exception '아직 단골로 지내는 사람이 아닙니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 넘길 수 없습니다.'; end if;
  if (public.world_region_at(c.location)).region_id is distinct from nr ->> 'region' then
    raise exception '%에서 넘깁니다.', (select m.region_name from public.world_map_regions m where m.region_id = nr ->> 'region');
  end if;
  insert into public.world_regular_day(owner_id, day, n) values (uid, today, 0) on conflict (owner_id) do update set day = excluded.day, n = 0 where world_regular_day.day <> excluded.day;
  select d.n into dn from public.world_regular_day d where d.owner_id = uid for update;
  if dn >= (r ->> 'day_n')::int then raise exception '오늘 납품은 다 했습니다(모든 단골을 합쳐 하루 %번). 내일 다시 오세요.', r ->> 'day_n'; end if;
  insert into public.world_regular_progress(owner_id, npc, day) values (uid, p_npc, today) on conflict do nothing;
  select * into g from public.world_regular_progress where owner_id = uid and npc = p_npc for update;
  v_done := case when g.day = today then g.done else '{}' end;
  if p_order = any (v_done) then raise exception '이 주문은 오늘 이미 넘겼습니다.'; end if;
  select x into o from jsonb_array_elements(public.world_regular_orders(uid, p_npc, today)) x where (x ->> 'i')::int = p_order;
  if o is null then raise exception '없는 주문입니다.'; end if;
  id := o ->> 'id'; q := (o ->> 'qty')::int;
  if coalesce(p_hq, false) then
    if not exists (select 1 from public.world_item_catalog h where h.item_id = id || '_hq') then raise exception '우수품이 없는 물품입니다.'; end if;
    id := id || '_hq';
  end if;
  nm := coalesce((select item_name from public.world_item_catalog where item_id = id), id);
  if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = id) then raise exception '「%」은(는) 잠가 둔 물품입니다.', nm; end if;
  st_ok := public.world_project_st_ok(uid);
  if st_ok then
    insert into public.world_storage(owner_id) values (uid) on conflict do nothing;
    select s.items into st from public.world_storage s where s.owner_id = uid for update;
  end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  free_inv := public.world_give_check(uid, id, inv);
  take_inv := least(q, free_inv);
  take_st := q - take_inv;
  if take_st > 0 and (not st_ok or coalesce((st ->> id)::int, 0) < take_st) then
    raise exception '「%」이(가) 모자랍니다(% 개 필요, 넘길 수 있는 것 %개 — 장착 중·강화한 것은 빠집니다).', nm, q, take_inv + case when st_ok then greatest(0, coalesce((st ->> id)::int, 0)) else 0 end;
  end if;
  if take_inv > 0 then inv := public.world_inv_add(inv, id, -take_inv); end if;
  if take_st > 0 then
    st := case when coalesce((st ->> id)::int, 0) - take_st <= 0 then st - id else jsonb_set(st, array[id], to_jsonb(coalesce((st ->> id)::int, 0) - take_st)) end;
    used_st := jsonb_build_object(id, take_st);
  end if;
  line := nr ->> 'line';
  rk := public.world_regular_rank(uid, line);
  xp := public.world_regular_xp(rk, coalesce(p_hq, false));
  v_gil := floor(coalesce((select reference_price from public.world_item_catalog where item_id = o ->> 'id'), 0) * q * (r -> 'gil' ->> 'rate')::numeric + (r -> 'gil' ->> 'base')::numeric)::int;
  add := case when coalesce(p_hq, false) then (r -> 'aff' ->> 'hq')::int else (r -> 'aff' ->> 'give')::int end;
  aff0 := g.aff; aff1 := least((r -> 'aff' ->> 'cap')::int, aff0 + add);
  s0 := public.world_regular_stage(aff0); s1 := public.world_regular_stage(aff1);
  perform set_config('yh.wear_leaves', 'on', true);
  update public.world_characters set inventory = inv, gil = gil + v_gil,
    skill_progress = public.world_skill_add(skill_progress, line, xp), updated_at = now() where owner_id = uid;
  if used_st <> '{}'::jsonb then update public.world_storage set items = st, updated_at = now() where owner_id = uid; end if;
  update public.world_regular_progress set aff = aff1, total = total + 1, day = today, done = v_done || p_order, updated_at = now() where owner_id = uid and npc = p_npc;
  update public.world_regular_day set n = n + 1 where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  values (uid, 'regular_give', v_gil, false, jsonb_build_object('npc', p_npc, 'item', id, 'qty', q));
  if s1 > s0 then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (uid, 'regular_stage', (nr ->> 'short') || ' · 친밀도 ' || s1 || '단계',
      case when s1 >= 5 and aff1 >= (r -> 'aff' ->> 'cap')::int then public.world_josa(nr ->> 'short', '과', '와') || '의 친밀도가 가장 높은 단계에 닿았습니다. 마지막 이야기가 열렸습니다.'
           else public.world_josa(nr ->> 'short', '과', '와') || '의 친밀도가 ' || s1 || '단계가 되었습니다. 새 이야기가 열렸습니다.' end,
      jsonb_build_object('npc', p_npc, 'stage', s1, 'quest', (nr ->> 'key') || '_' || s1));
  end if;
  if aff1 >= (r -> 'aff' ->> 'cap')::int and aff0 < (r -> 'aff' ->> 'cap')::int then perform public.world_title_award_check(uid, 'regular'); end if;
  return jsonb_build_object('npc', p_npc, 'item', id, 'qty', q, 'xp', xp, 'gil', v_gil, 'aff', aff1, 'add', aff1 - aff0, 'stage', s1, 'stage_up', s1 > s0,
    'from_storage', used_st, 'today', dn + 1, 'cap', (r ->> 'day_n')::int,
    'content', public.world_josa(nr ->> 'short', '에게', '에게') || ' 「' || nm || '」 ' || q || '개를 넘겼습니다 · ' || public.world_line_name(line) || ' 경험 +' || xp || ' · ' || v_gil || '전 · 친밀도 +' || (aff1 - aff0) ||
      case when s1 > s0 then ' · 친밀도 ' || s1 || '단계 — 새 이야기가 열렸습니다!' else '' end || ' · 오늘 ' || (dn + 1) || '/' || (r ->> 'day_n'),
    'view', public.world_regular_view(p_npc));
end $f$;

create or replace function public.world_regular_brief(p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare k text := public.world_regular_here(p_uid); n jsonb; g public.world_regular_progress%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; dn int;
begin
  if k is null or not public.world_regular_open(p_uid, k) then return null; end if;
  n := public.world_regular_rule(k);
  select * into g from public.world_regular_progress where owner_id = p_uid and npc = k;
  dn := public.world_regular_day_n(p_uid, today);
  return jsonb_build_object('npc', k, 'name', n ->> 'name', 'short', n ->> 'short', 'line_name', public.world_line_name(n ->> 'line'),
    'aff', coalesce(g.aff, 0), 'stage', public.world_regular_stage(coalesce(g.aff, 0)), 'next', public.world_regular_next(coalesce(g.aff, 0)),
    'left', (public.world_regular_rules() ->> 'orders')::int - coalesce(array_length(case when g.day = today then g.done end, 1), 0),
    'today', dn, 'cap', (public.world_regular_rules() ->> 'day_n')::int);
end $f$;

create or replace function public.world_regular_list()
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); today date := (now() at time zone 'Asia/Seoul')::date;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object('today', public.world_regular_day_n(uid, today), 'cap', (public.world_regular_rules() ->> 'day_n')::int,
    'list', coalesce((select jsonb_agg(jsonb_build_object('npc', e.key, 'name', e.value ->> 'name', 'short', e.value ->> 'short', 'line_name', public.world_line_name(e.value ->> 'line'),
        'place', (select m.region_name from public.world_map_regions m where m.region_id = e.value ->> 'region'), 'region', e.value ->> 'region',
        'aff', public.world_regular_aff(uid, e.key), 'stage', public.world_regular_stage(public.world_regular_aff(uid, e.key)), 'next', public.world_regular_next(public.world_regular_aff(uid, e.key)),
        'left', (public.world_regular_rules() ->> 'orders')::int - coalesce((select array_length(g.done, 1) from public.world_regular_progress g where g.owner_id = uid and g.npc = e.key and g.day = today), 0),
        'title', e.value ->> 'title_name') order by (e.value ->> 'sort')::int)
      from jsonb_each(public.world_regular_rules() -> 'npcs') e where public.world_regular_open(uid, e.key)), '[]'::jsonb));
end $f$;

create or replace function public.world_regular_rule_count(p_owner uuid, p_rule jsonb)
 returns numeric language sql stable security definer set search_path = pg_catalog, public
as $f$
  select count(*)::numeric from public.world_regular_progress g
   where g.owner_id = p_owner and g.aff >= (public.world_regular_rules() -> 'aff' ->> 'cap')::int
$f$;

create or replace function public.world_quest_gate_ok(p_req jsonb) returns boolean
language sql stable as $f$
  select p_req is null or case when p_req ? 'regular' then public.world_regular_stage_of(public.fn_owner_auth_uid(), p_req ->> 'regular') >= coalesce((p_req ->> 'stage')::int, 0)
    else coalesce((select p.stage from public.world_projects p where p.project_key = p_req ->> 'project'), 0) >= coalesce((p_req ->> 'stage')::int, 0) end
$f$;

create or replace function public.world_quest_gate_text(p_req jsonb) returns text
language sql stable as $f$
  select case when p_req is null then null
    when p_req ? 'regular' then public.world_josa(public.world_regular_rule(p_req ->> 'regular') ->> 'short', '과', '와') || '의 친밀도가 ' || (p_req ->> 'stage') || '단계에 닿으면 열립니다.'
    else coalesce(public.world_project_rules() -> 'projects' -> (p_req ->> 'project') ->> 'name', '거점 사업') || ' ' || (p_req ->> 'stage') || '단계를 마치면 열립니다.' end
$f$;

select pg_temp.pj_fix('world_title_rule_ok', array[
$q$ELSIF p_rule ? 'project' THEN RETURN public.world_project_rule_count(p_owner, p_rule) >= n;$q$,
$q$ELSIF p_rule ? 'regular' THEN RETURN public.world_regular_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'project' THEN RETURN public.world_project_rule_count(p_owner, p_rule) >= n;$q$]);
select pg_temp.pj_fix('world_title_rule_progress', array[
$q$elsif p_rule ? 'project' then v := public.world_project_rule_count(p_owner, p_rule);$q$,
$q$elsif p_rule ? 'regular' then v := public.world_regular_rule_count(p_owner, p_rule); elsif p_rule ? 'project' then v := public.world_project_rule_count(p_owner, p_rule);$q$]);
select pg_temp.pj_fix('world_title_award_check', array[
$q$    IF p_event_type = 'project' AND NOT (r ? 'project') THEN CONTINUE; END IF;$q$,
$q$    IF p_event_type = 'project' AND NOT (r ? 'project') THEN CONTINUE; END IF;
    IF r ? 'regular' AND p_event_type IS NOT NULL AND p_event_type <> 'regular' THEN CONTINUE; END IF;
    IF p_event_type = 'regular' AND NOT (r ? 'regular') THEN CONTINUE; END IF;$q$]);
select pg_temp.pj_fix('world_notify_group', array[
$q$when p_kind in ('project_stage') then 'project'$q$, $q$when p_kind in ('project_stage') then 'project'
    when p_kind in ('regular_stage') then 'reward'$q$]);
select pg_temp.pj_fix('world_character_purge(uuid)', array[
$q$  delete from public.world_project_contrib where owner_id = p_uid;$q$,
$q$  delete from public.world_project_contrib where owner_id = p_uid;
  delete from public.world_regular_progress where owner_id = p_uid;
  delete from public.world_regular_day where owner_id = p_uid;$q$]);
select pg_temp.pj_fix('world_field_snapshot', array[
$q$'project', public.world_project_brief(uid),$q$,
$q$'project', public.world_project_brief(uid), 'regular', public.world_regular_brief(uid),$q$]);

do $g$
declare f text;
begin
  foreach f in array array['world_regular_rules()', 'world_regular_rule(text)', 'world_regular_stage(int)', 'world_regular_next(int)', 'world_regular_xp(int, boolean)'] loop
    perform pg_temp.pj_share('public.' || f);
  end loop;
  foreach f in array array['world_regular_open(uuid, text)', 'world_regular_aff(uuid, text)', 'world_regular_stage_of(uuid, text)', 'world_regular_rank(uuid, text)',
    'world_regular_pool(text, int)', 'world_regular_orders(uuid, text, date)', 'world_regular_day_n(uuid, date)', 'world_regular_here(uuid)',
    'world_regular_view(text)', 'world_regular_give(text, int, boolean)', 'world_regular_brief(uuid)', 'world_regular_list()', 'world_regular_rule_count(uuid, jsonb)'] loop
    perform pg_temp.pj_share('public.' || f);
    perform pg_temp.pj_own('public.' || f, 'fn_owner_field');
  end loop;
end $g$;
grant execute on function public.world_regular_view(text) to authenticated;
grant execute on function public.world_regular_give(text, int, boolean) to authenticated;
grant execute on function public.world_regular_list() to authenticated;
grant execute on function public.world_regular_rules() to anon, authenticated;
