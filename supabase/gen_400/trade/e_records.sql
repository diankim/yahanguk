create table if not exists public.world_trade_record (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  sold_base bigint not null default 0,
  sold_gil bigint not null default 0,
  sold_n int not null default 0,
  ports jsonb not null default '{}',
  best_gil int not null default 0,
  best_port text,
  best_at timestamptz,
  demand_n int not null default 0,
  demand_day date,
  full_n int not null default 0,
  voy_n int not null default 0,
  cross_n int not null default 0,
  send_n int not null default 0,
  ocean_cross boolean not null default false,
  raid_win int not null default 0,
  raid_lose int not null default 0,
  send_raid int not null default 0,
  bonus jsonb not null default '{}',
  tiers jsonb not null default '{}',
  broke_wait boolean not null default false,
  broke_fix boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.world_trade_record enable row level security;
revoke all on table public.world_trade_record from anon, authenticated;

create or replace function public.world_trade_rec_val(p_rec jsonb, p_by text, p_seen int)
 returns numeric language sql immutable set search_path to 'pg_catalog' as $f$
  select coalesce(case p_by
    when 'sold' then (p_rec ->> 'sold_base')::numeric
    when 'cross' then (p_rec ->> 'cross_n')::numeric
    when 'ports' then p_seen
    when 'demand' then (p_rec ->> 'demand_n')::numeric
    when 'full' then (p_rec ->> 'full_n')::numeric
    when 'send' then (p_rec ->> 'send_n')::numeric
    when 'raid' then (p_rec ->> 'raid_win')::numeric
    when 'ocean' then case when (p_rec ->> 'ocean_cross')::boolean then 1 else 0 end
    when 'crew' then (select count(*) from jsonb_each(coalesce(p_rec -> 'bonus', '{}')) b where jsonb_typeof(b.value) = 'number' and b.value::text::numeric > 0)
    when 'best' then (p_rec ->> 'best_gil')::numeric
    when 'broke' then case when (p_rec ->> 'broke_fix')::boolean then 1 else 0 end
  end, 0)
$f$;

create or replace function public.world_trade_seen_n(p_uid uuid)
 returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select count(*)::int from public.world_trade_seen where owner_id = p_uid
$f$;

create or replace function public.world_trade_rule_count(p_owner uuid, p_rule jsonb)
 returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select public.world_trade_rec_val(coalesce((select to_jsonb(t) from public.world_trade_record t where t.owner_id = p_owner), '{}'::jsonb), p_rule ->> 'trade',
    case when p_rule ->> 'trade' = 'ports' then public.world_trade_seen_n(p_owner) else 0 end)
$f$;

create or replace function public.world_trade_rec(p_uid uuid, p_add jsonb)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare o public.world_trade_record%rowtype; n public.world_trade_record%rowtype; s jsonb := p_add -> 'sale'; pt text; pj jsonb; t jsonb;
  seen1 int := 0; seen0 int := 0; oj jsonb; nj jsonb;
begin
  if p_uid is null or p_add is null or p_add = '{}'::jsonb then return; end if;
  select * into o from public.world_trade_record where owner_id = p_uid for update;
  if not found then
    o.owner_id := p_uid; o.sold_base := 0; o.sold_gil := 0; o.sold_n := 0; o.ports := '{}'; o.best_gil := 0; o.demand_n := 0; o.full_n := 0;
    o.voy_n := 0; o.cross_n := 0; o.send_n := 0; o.ocean_cross := false; o.raid_win := 0; o.raid_lose := 0; o.send_raid := 0;
    o.bonus := '{}'; o.tiers := '{}'; o.broke_wait := false; o.broke_fix := false;
  end if;
  n := o;
  if s is not null then
    pt := s ->> 'port';
    n.sold_base := n.sold_base + coalesce((s ->> 'b')::bigint, 0);
    n.sold_gil := n.sold_gil + coalesce((s ->> 'g')::bigint, 0);
    n.sold_n := n.sold_n + coalesce((s ->> 'n')::int, 0);
    pj := coalesce(n.ports -> pt, '{}');
    n.ports := n.ports || jsonb_build_object(pt, jsonb_build_object('b', coalesce((pj ->> 'b')::bigint, 0) + coalesce((s ->> 'b')::bigint, 0),
      'g', coalesce((pj ->> 'g')::bigint, 0) + coalesce((s ->> 'g')::bigint, 0), 'n', coalesce((pj ->> 'n')::int, 0) + coalesce((s ->> 'n')::int, 0)));
    if coalesce((s ->> 'g')::int, 0) > n.best_gil then n.best_gil := (s ->> 'g')::int; n.best_port := pt; n.best_at := now(); end if;
    if coalesce((s ->> 'demand')::boolean, false) and n.demand_day is distinct from (s ->> 'day')::date then
      n.demand_n := n.demand_n + 1; n.demand_day := (s ->> 'day')::date; end if;
    if coalesce((s ->> 'full')::boolean, false) then n.full_n := n.full_n + 1; end if;
  end if;
  n.voy_n := n.voy_n + coalesce((p_add ->> 'voy')::int, 0);
  n.cross_n := n.cross_n + coalesce((p_add ->> 'cross')::int, 0);
  n.send_n := n.send_n + coalesce((p_add ->> 'send')::int, 0);
  n.send_raid := n.send_raid + coalesce((p_add ->> 'send_raid')::int, 0);
  if coalesce((p_add ->> 'ocean')::boolean, false) then n.ocean_cross := true; end if;
  if p_add ->> 'raid' = 'win' then n.raid_win := n.raid_win + 1; elsif p_add ->> 'raid' = 'lose' then n.raid_lose := n.raid_lose + 1; end if;
  if p_add ? 'bonus' then n.bonus := n.bonus || jsonb_build_object(p_add ->> 'bonus', coalesce((n.bonus ->> (p_add ->> 'bonus'))::int, 0) + 1); end if;
  if p_add ? 'tier' and not (n.tiers ? (p_add ->> 'tier')) then n.tiers := n.tiers || jsonb_build_object(p_add ->> 'tier', now()); end if;
  if p_add ? 'broke_wait' then n.broke_wait := (p_add ->> 'broke_wait')::boolean; end if;
  if coalesce((p_add ->> 'broke_fix')::boolean, false) then n.broke_fix := true; n.broke_wait := false; end if;
  n.updated_at := now();
  insert into public.world_trade_record select n.*
  on conflict (owner_id) do update set sold_base = excluded.sold_base, sold_gil = excluded.sold_gil, sold_n = excluded.sold_n, ports = excluded.ports,
    best_gil = excluded.best_gil, best_port = excluded.best_port, best_at = excluded.best_at, demand_n = excluded.demand_n, demand_day = excluded.demand_day,
    full_n = excluded.full_n, voy_n = excluded.voy_n, cross_n = excluded.cross_n, send_n = excluded.send_n, ocean_cross = excluded.ocean_cross,
    raid_win = excluded.raid_win, raid_lose = excluded.raid_lose, send_raid = excluded.send_raid, bonus = excluded.bonus, tiers = excluded.tiers,
    broke_wait = excluded.broke_wait, broke_fix = excluded.broke_fix, updated_at = excluded.updated_at;
  oj := to_jsonb(o); nj := to_jsonb(n);
  if coalesce((p_add ->> 'seen_new')::int, 0) > 0 then seen1 := public.world_trade_seen_n(p_uid); seen0 := seen1 - (p_add ->> 'seen_new')::int; end if;
  for t in select x from jsonb_array_elements(public.world_trade_rules() -> 'titles') x loop
    if public.world_trade_rec_val(oj, t ->> 'by', seen0) < (t ->> 'n')::numeric and public.world_trade_rec_val(nj, t ->> 'by', seen1) >= (t ->> 'n')::numeric then
      perform public.world_title_award_check(p_uid, 'trade');
      exit;
    end if;
  end loop;
end $f$;

create or replace function public.world_trade_record_view()
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_trade_rules(); t public.world_trade_record%rowtype; rj jsonb; seen int; d int; ports jsonb[] := '{}';
  k text; p jsonb; tl jsonb[] := '{}'; x jsonb; got boolean; v numeric;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into t from public.world_trade_record where owner_id = uid;
  rj := coalesce(to_jsonb(t), '{}'::jsonb);
  if not found then rj := '{}'::jsonb; end if;
  seen := public.world_trade_seen_n(uid);
  select base_sum into d from public.world_trade_sales where owner_id = uid and day = public.world_housing_today();
  for k, p in select e.key, e.value from jsonb_each(r -> 'ports') e loop
    ports := ports || jsonb_build_object('id', k, 'name', p ->> 'name', 'realm', p ->> 'realm', 'b', coalesce((rj -> 'ports' -> k ->> 'b')::bigint, 0),
      'g', coalesce((rj -> 'ports' -> k ->> 'g')::bigint, 0), 'n', coalesce((rj -> 'ports' -> k ->> 'n')::int, 0),
      'seen_at', (select s.at from public.world_trade_seen s where s.owner_id = uid and s.port_id = k));
  end loop;
  for x in select e from jsonb_array_elements(r -> 'titles') e loop
    got := exists (select 1 from public.world_character_titles ct where ct.owner_id = uid and ct.title_key = x ->> 'key');
    v := public.world_trade_rec_val(rj, x ->> 'by', seen);
    tl := tl || case when (x ->> 'hidden')::boolean and not got then jsonb_build_object('key', x ->> 'key', 'hidden', true, 'earned', false)
      else jsonb_build_object('key', x ->> 'key', 'name', x ->> 'name', 'cond', x ->> 'cond', 'grade', (x ->> 'grade')::int, 'hidden', (x ->> 'hidden')::boolean,
        'need', (x ->> 'n')::numeric, 'progress', least(v, (x ->> 'n')::numeric), 'earned', got) end;
  end loop;
  return jsonb_build_object('ship', public.world_trade_ship_view(uid), 'tiers', coalesce(rj -> 'tiers', '{}'),
    'sold_n', coalesce((rj ->> 'sold_n')::int, 0), 'sold_base', coalesce((rj ->> 'sold_base')::bigint, 0), 'sold_gil', coalesce((rj ->> 'sold_gil')::bigint, 0),
    'day', jsonb_build_object('used', coalesce(d, 0), 'cap', (r ->> 'day_cap')::int),
    'ports', to_jsonb(ports), 'seen', seen, 'port_n', (select count(*) from jsonb_object_keys(r -> 'ports')),
    'best', case when coalesce((rj ->> 'best_gil')::int, 0) > 0 then jsonb_build_object('gil', (rj ->> 'best_gil')::int, 'port', rj ->> 'best_port',
      'port_name', r -> 'ports' -> (rj ->> 'best_port') ->> 'name', 'at', rj -> 'best_at') end,
    'full_n', coalesce((rj ->> 'full_n')::int, 0), 'demand_n', coalesce((rj ->> 'demand_n')::int, 0),
    'voy_n', coalesce((rj ->> 'voy_n')::int, 0), 'cross_n', coalesce((rj ->> 'cross_n')::int, 0), 'send_n', coalesce((rj ->> 'send_n')::int, 0),
    'raid_win', coalesce((rj ->> 'raid_win')::int, 0), 'raid_lose', coalesce((rj ->> 'raid_lose')::int, 0), 'send_raid', coalesce((rj ->> 'send_raid')::int, 0),
    'bonus', coalesce(rj -> 'bonus', '{}'), 'titles', to_jsonb(tl));
end $f$;

create or replace function public.world_trade_arrive_log(p_uid uuid, p_from text, p_to text, p_started timestamptz)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare hid bigint; nm text; rgn text;
begin
  select character_name into nm from public.world_characters where owner_id = p_uid;
  select region_name into rgn from public.world_map_regions where region_id = p_to;
  begin
    insert into public.world_travel_history(owner_id, from_region, to_region, started_at, arrives_at, completed_at, passenger_count, fare_exempt)
    values (p_uid, (select region_name from public.world_map_regions where region_id = p_from), rgn, coalesce(p_started, now()), now(), now(), 1, true)
    returning id into hid;
    insert into public.world_events(actor_id, actor_name, event_type, content, payload)
    values (p_uid, nm, 'travel', '도착: ' || rgn, jsonb_build_object('region_id', p_to, 'region_name', rgn, 'travel_history_id', hid, 'ship', true));
  exception when others then null;
  end;
end $f$;

select pg_temp.yh_fix('world_trade_sell_core', array[
  $a$g jsonb; base int; n int; unit int; gain int; gil_all bigint := 0; sold jsonb[] := '{}'; left_j jsonb := '{}'; base_add int := 0; nm text;$a$,
  $a$g jsonb; base int; n int; unit int; gain int; gil_all bigint := 0; sold jsonb[] := '{}'; left_j jsonb := '{}'; base_add int := 0; nm text;
  used0 int; n_all int := 0; low int;$a$,
  $a$  used := coalesce(used, 0);$a$,
  $a$  used := coalesce(used, 0); used0 := used;$a$,
  $a$    used := used + base * n; base_add := base_add + base * n; gil_all := gil_all + gain;$a$,
  $a$    used := used + base * n; base_add := base_add + base * n; gil_all := gil_all + gain; n_all := n_all + n; low := least(coalesce(low, base), base);$a$,
  $a$values (p_uid, 'trade_goods_sale', gil_all, false, jsonb_build_object('port', p_port, 'sold', to_jsonb(sold)));$a$,
  $a$values (p_uid, 'trade_goods_sale', gil_all, false, jsonb_build_object('port', p_port, 'sold', to_jsonb(sold)));
    perform public.world_trade_rec(p_uid, jsonb_build_object('sale', jsonb_build_object('port', p_port, 'b', base_add, 'g', gil_all, 'n', n_all, 'day', p_day,
      'demand', p_prices is null and public.world_trade_demand_of(p_day) ->> 'port' = p_port, 'full', used0 = 0 and used >= cap - low)));$a$]);

select pg_temp.yh_fix('world_trade_finish', array[
  $a$  sold jsonb; rgn text; owners uuid[]; hagg int := 0; dd int := (r -> 'dur' ->> 'voyage')::int; vals jsonb;$a$,
  $a$  sold jsonb; rgn text; owners uuid[]; hagg int := 0; dd int := (r -> 'dur' ->> 'voyage')::int; vals jsonb; crew uuid[]; xs boolean; ctier int; sn int;$a$,
  $a$    for u in select a.owner_id from public.world_trade_aboard a where a.voyage_id = v.voyage_id order by a.owner_id loop
      insert into public.world_trade_seen$a$,
  $a$    xs := exists (select 1 from jsonb_array_elements(r -> 'cross') x where (x ->> 0 = v.from_port and x ->> 1 = v.to_port) or (x ->> 1 = v.from_port and x ->> 0 = v.to_port));
    select tier into ctier from public.world_ships where owner_id = v.captain_id;
    crew := array(select a.owner_id from public.world_trade_aboard a where a.voyage_id = v.voyage_id order by a.owner_id);
    for u in select a.owner_id from public.world_trade_aboard a where a.voyage_id = v.voyage_id order by a.owner_id loop
      sn := case when exists (select 1 from public.world_trade_seen ws where ws.owner_id = u and ws.port_id = v.to_port) then 0 else 1 end;
      insert into public.world_trade_seen$a$,
  $a$      perform public.world_trade_note(u, 'trade_arrive', '배가 닿음',$a$,
  $a$      perform public.world_trade_rec(u, jsonb_build_object('voy', 1, 'cross', case when xs then 1 else 0 end, 'seen_new', sn,
        'ocean', xs and u = v.captain_id and ctier >= 5) || case when v.bonus is not null and v.mates > 0 then jsonb_build_object('bonus', v.bonus) else '{}'::jsonb end);
      perform public.world_trade_note(u, 'trade_arrive', '배가 닿음',$a$,
  $a$    delete from public.world_trade_aboard where voyage_id = v.voyage_id;$a$,
  $a$    delete from public.world_trade_aboard where voyage_id = v.voyage_id;
    foreach u in array crew loop
      perform public.world_trade_arrive_log(u, v.from_port, v.to_port, v.started_at);
    end loop;$a$,
  $a$      jsonb_build_object('voyage_id', v.voyage_id, 'port', v.to_port));
  end if;$a$,
  $a$      jsonb_build_object('voyage_id', v.voyage_id, 'port', v.to_port));
    perform public.world_trade_rec(v.captain_id, jsonb_build_object('send', 1, 'send_raid', case when res ? 'raid' then 1 else 0 end));
  end if;$a$]);

select pg_temp.yh_fix('world_trade_raid_end', array[
  $a$  for u in select a.owner_id from public.world_trade_aboard a where a.voyage_id = v.voyage_id loop
    perform public.world_trade_note(u, 'trade_raid',$a$,
  $a$  for u in select a.owner_id from public.world_trade_aboard a where a.voyage_id = v.voyage_id order by a.owner_id loop
    perform public.world_trade_rec(u, jsonb_build_object('raid', case when won then 'win' else 'lose' end));
    perform public.world_trade_note(u, 'trade_raid',$a$]);

select pg_temp.yh_fix('world_trade_ship_get', array[
  $a$  insert into public.world_ships(owner_id, tier, durability, port_id) values (uid, 1, (sr ->> 'dur')::int, here);$a$,
  $a$  insert into public.world_ships(owner_id, tier, durability, port_id) values (uid, 1, (sr ->> 'dur')::int, here);
  perform public.world_trade_rec(uid, jsonb_build_object('tier', 1));$a$]);

select pg_temp.yh_fix('world_trade_ship_upgrade', array[
  $a$  delete from public.world_ship_parts where owner_id = uid;$a$,
  $a$  delete from public.world_ship_parts where owner_id = uid;
  perform public.world_trade_rec(uid, jsonb_build_object('tier', (pv ->> 'tier')::int));$a$]);

select pg_temp.yh_fix('world_trade_repair', array[
  $a$  update public.world_ships set durability = durability + n, updated_at = now() where owner_id = uid;$a$,
  $a$  update public.world_ships set durability = durability + n, updated_at = now() where owner_id = uid;
  if s.durability <= 0 then perform public.world_trade_rec(uid, jsonb_build_object('broke_wait', true)); end if;$a$]);

select pg_temp.yh_fix('world_trade_launch', array[
  $a$  update public.world_characters set mount_tokens = mount_tokens - tk, updated_at = now() where owner_id = v.captain_id;$a$,
  $a$  update public.world_characters set mount_tokens = mount_tokens - tk, updated_at = now() where owner_id = v.captain_id;
  if exists (select 1 from public.world_trade_record tr where tr.owner_id = v.captain_id and tr.broke_wait) then
    perform public.world_trade_rec(v.captain_id, jsonb_build_object('broke_fix', true)); end if;$a$]);

select pg_temp.yh_fix('world_housekeeping', array[
  $a$  delete from public.world_drawing_made where made_at < now() - interval '2 days';$a$,
  $a$  delete from public.world_drawing_made where made_at < now() - interval '2 days';
  delete from public.world_trade_voyages where status in ('done', 'cancelled') and coalesce(finished_at, created_at) < now() - interval '2 days';$a$]);

select pg_temp.yh_fix('world_title_rule_ok', array[$a$ELSIF p_rule ? 'regular' THEN$a$,
  $a$ELSIF p_rule ? 'trade' THEN RETURN public.world_trade_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'regular' THEN$a$]);
select pg_temp.yh_fix('world_title_rule_progress', array[$a$elsif p_rule ? 'regular' then v :=$a$,
  $a$elsif p_rule ? 'trade' then v := public.world_trade_rule_count(p_owner, p_rule); elsif p_rule ? 'regular' then v :=$a$]);
select pg_temp.yh_fix('world_title_award_check', array[$a$IF r ? 'regular' AND p_event_type IS NOT NULL$a$,
  $a$IF r ? 'trade' AND p_event_type IS NOT NULL AND p_event_type <> 'trade' THEN CONTINUE; END IF;
    IF p_event_type = 'trade' AND NOT (r ? 'trade') THEN CONTINUE; END IF;
    IF r ? 'regular' AND p_event_type IS NOT NULL$a$]);

select pg_temp.yh_fix('world_character_purge(uuid)', array[
  '  delete from public.world_trade_sales where owner_id = p_uid;',
  '  delete from public.world_trade_sales where owner_id = p_uid;
  delete from public.world_trade_record where owner_id = p_uid;']);

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade)
select t ->> 'key', t ->> 'name', 'ship', t ->> 'desc', t ->> 'cond', t -> 'bonus', true, (t ->> 'hidden')::boolean,
  jsonb_build_object('trade', t ->> 'by', 'n', (t ->> 'n')::int), 3700 + o::int, public.world_trade_rules() ->> 'title_cat', (t ->> 'grade')::int
from jsonb_array_elements(public.world_trade_rules() -> 'titles') with ordinality z(t, o)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus,
  hidden = excluded.hidden, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;

insert into public.world_trade_record(owner_id, sold_base, sold_gil)
select s.owner_id, sum(s.base_sum), sum(s.gil_sum) from public.world_trade_sales s group by s.owner_id
on conflict (owner_id) do nothing;
insert into public.world_trade_record(owner_id, tiers)
select w.owner_id, (select jsonb_object_agg(g::text, case when g = 1 then to_jsonb(w.got_at) else 'null'::jsonb end) from generate_series(1, w.tier) g) from public.world_ships w
on conflict (owner_id) do update set tiers = excluded.tiers || public.world_trade_record.tiers;

do $$
declare f text;
begin
  foreach f in array array['world_trade_rec_val(jsonb,text,integer)', 'world_trade_seen_n(uuid)', 'world_trade_rule_count(uuid,jsonb)', 'world_trade_rec(uuid,jsonb)',
    'world_trade_arrive_log(uuid,text,text,timestamptz)'] loop
    perform pg_temp.yh_share('public.' || f);
  end loop;
  revoke all on function public.world_trade_record_view() from public, anon;
  grant execute on function public.world_trade_record_view() to authenticated, service_role;
end $$;
