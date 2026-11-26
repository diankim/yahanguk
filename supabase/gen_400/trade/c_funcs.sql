create or replace function public.world_trade_hash(p_text text)
 returns numeric language sql immutable set search_path to 'pg_catalog' as $f$
  select (('x' || lpad(substr(md5(p_text), 1, 8), 16, '0'))::bit(64)::bigint)::numeric / 4294967296
$f$;

create or replace function public.world_trade_port(p_port text)
 returns jsonb language sql stable set search_path to 'pg_catalog', 'public' as $f$
  select case when p_port is null then null else public.world_trade_rules() -> 'ports' -> p_port end
$f$;

create or replace function public.world_trade_ship_rule(p_tier int)
 returns jsonb language sql stable set search_path to 'pg_catalog', 'public' as $f$
  select public.world_trade_rules() -> 'ships' -> (greatest(1, least(5, coalesce(p_tier, 1))) - 1)
$f$;

create or replace function public.world_trade_route_min(p_a text, p_b text)
 returns int language sql stable set search_path to 'pg_catalog', 'public' as $f$
  select (x ->> 2)::int from jsonb_array_elements(public.world_trade_rules() -> 'routes') x
   where (x ->> 0 = p_a and x ->> 1 = p_b) or (x ->> 0 = p_b and x ->> 1 = p_a) limit 1
$f$;

create or replace function public.world_trade_here(p_uid uuid)
 returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare rg text;
begin
  select (public.world_field_region(c.location)).region_id into rg from public.world_characters c where c.owner_id = p_uid;
  if rg is not null and public.world_trade_rules() -> 'ports' ? rg then return rg; end if;
  return null;
end $f$;

create or replace function public.world_trade_good(p_good text)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare r jsonb := public.world_trade_rules(); f jsonb; k text; hub text; nm text; pr bigint;
begin
  if p_good is null then return null; end if;
  if r -> 'goods' ? p_good then return (r -> 'goods' -> p_good) || jsonb_build_object('id', p_good, 'food', false); end if;
  if not (p_good = any (public.world_food_fixed())) then return null; end if;
  f := public.world_food_rules();
  select e.key into k from jsonb_each(f -> 'specials') e where e.value ? p_good limit 1;
  hub := f -> 'hubs' ->> k;
  select item_name, reference_price into nm, pr from public.world_item_catalog where item_id = p_good;
  return jsonb_build_object('id', p_good, 'name', nm, 'base', greatest(1, coalesce(pr, 1)), 'want', '[]'::jsonb, 'food', true,
    'port', (select p.key from jsonb_each(r -> 'ports') p where p.value ->> 'name' = hub limit 1));
end $f$;

create or replace function public.world_trade_seek(p_port text, p_day date)
 returns text[] language sql stable set search_path to 'pg_catalog', 'public' as $f$
  with r as (select public.world_trade_rules() j)
  select coalesce(array(select g.key from r, jsonb_each(r.j -> 'goods') g where g.value ->> 'port' <> p_port
     order by md5(p_port || '|' || g.key || '|' || ((p_day - date '2026-01-01') / (r.j -> 'price' -> 'seek' ->> 'days')::int)::text)
     limit (select (j -> 'price' -> 'seek' ->> 'n')::int from r)), '{}')
$f$;

create or replace function public.world_trade_demand_of(p_day date)
 returns jsonb language sql stable set search_path to 'pg_catalog', 'public' as $f$
  with r as (select public.world_trade_rules() j)
  select jsonb_build_object('port', (select p.key from r, jsonb_each(r.j -> 'ports') p order by md5('demand|' || p_day::text || '|' || p.key) limit 1),
    'name', (select r.j -> 'price' -> 'event' -> 'names' ->> floor(public.world_trade_hash('demand-name|' || p_day::text) * jsonb_array_length(r.j -> 'price' -> 'event' -> 'names'))::int from r))
$f$;

create or replace function public.world_trade_quote(p_port text, p_good text, p_day date, p_mode int)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare r jsonb := public.world_trade_rules(); pr jsonb := r -> 'price'; g jsonb := public.world_trade_good(p_good); pp jsonb := r -> 'ports' -> p_port; op jsonb;
  mul numeric; x numeric; tags text[] := '{}'; fl public.world_trade_flow%rowtype; eff numeric := 0; fm numeric := 1;
begin
  if g is null or pp is null then return null; end if;
  op := r -> 'ports' -> (g ->> 'port');
  mul := (pr ->> 'normal')::numeric;
  if g ->> 'port' = p_port then mul := (pr ->> 'origin')::numeric; tags := tags || 'origin'::text;
  elsif coalesce(g -> 'want', '[]') ? p_port then mul := (pr ->> 'want')::numeric; tags := tags || 'want'::text; end if;
  if op is not null and op ->> 'realm' <> 'main' and pp ->> 'realm' = 'main' and mul < (pr ->> 'far')::numeric then mul := (pr ->> 'far')::numeric; tags := tags || 'far'::text; end if;
  x := (g ->> 'base')::numeric * mul * (1 + (public.world_trade_hash(p_port || '|' || p_good || '|' || p_day::text) * 2 - 1) * (pr ->> 'wobble')::numeric);
  if p_mode >= 1 then
    if not (g ->> 'food')::boolean and p_good = any (public.world_trade_seek(p_port, p_day)) then x := x * (pr -> 'seek' ->> 'mul')::numeric; tags := tags || 'seek'::text; end if;
    if p_mode <> 3 and public.world_trade_demand_of(p_day) ->> 'port' = p_port then x := x * (pr -> 'event' ->> 'mul')::numeric; tags := tags || 'event'::text; end if;
  end if;
  if p_mode >= 2 then
    select * into fl from public.world_trade_flow where port_id = p_port and good_id = p_good;
    if found then
      eff := fl.sold * greatest(0, 1 - extract(epoch from now() - fl.at) / ((pr -> 'flow' ->> 'hours')::numeric * 3600));
      fm := greatest((pr -> 'flow' ->> 'min')::numeric, 1 - eff * (pr -> 'flow' ->> 'per')::numeric);
      x := x * fm;
      if fm < (pr ->> 'hot')::numeric then tags := tags || 'hot'::text; end if;
    end if;
  end if;
  return jsonb_build_object('good', p_good, 'name', g ->> 'name', 'base', (g ->> 'base')::int, 'price', greatest(1, round(x))::int, 'tags', to_jsonb(tags), 'flow', round(fm, 3), 'food', (g ->> 'food')::boolean);
end $f$;

create or replace function public.world_trade_board_vals(p_port text)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare d date := public.world_housing_today(); k text; q jsonb; t numeric; y numeric; out jsonb[] := '{}';
begin
  for k in select g.key from jsonb_each(public.world_trade_rules() -> 'goods') g order by (g.value ->> 'base')::int, g.key loop
    q := public.world_trade_quote(p_port, k, d, 2);
    t := (public.world_trade_quote(p_port, k, d, 1) ->> 'price')::numeric;
    y := (public.world_trade_quote(p_port, k, d - 1, 1) ->> 'price')::numeric;
    out := out || (q || jsonb_build_object('pct', case when y > 0 then round((t - y) * 100 / y)::int else 0 end,
      'buy', case when q -> 'tags' ? 'origin' then (public.world_trade_quote(p_port, k, d, 0) ->> 'price')::int end));
  end loop;
  return to_jsonb(out);
end $f$;

create or replace function public.world_trade_hold(p_uid uuid)
 returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select coalesce(jsonb_agg(jsonb_build_object('good', h.good_id, 'name', i.item_name, 'qty', h.qty, 'cost', h.cost, 'base', (public.world_trade_good(h.good_id) ->> 'base')::int,
    'food', (public.world_trade_good(h.good_id) ->> 'food')::boolean) order by h.good_id), '[]'::jsonb)
    from public.world_ship_hold h join public.world_item_catalog i on i.item_id = h.good_id where h.owner_id = p_uid
$f$;

create or replace function public.world_trade_slots_used(p_uid uuid)
 returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select coalesce(sum(ceil(h.qty::numeric / (public.world_trade_rules() ->> 'slot_n')::int)), 0)::int from public.world_ship_hold h where h.owner_id = p_uid
$f$;

create or replace function public.world_trade_room(p_uid uuid, p_good text)
 returns int language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare n int := (public.world_trade_rules() ->> 'slot_n')::int; s public.world_ships%rowtype; q0 int; other int;
begin
  select * into s from public.world_ships where owner_id = p_uid;
  if not found then return 0; end if;
  select coalesce(qty, 0) into q0 from public.world_ship_hold where owner_id = p_uid and good_id = p_good;
  q0 := coalesce(q0, 0);
  other := public.world_trade_slots_used(p_uid) - ceil(q0::numeric / n)::int;
  return greatest(0, ((public.world_trade_ship_rule(s.tier) ->> 'slots')::int - other) * n - q0);
end $f$;

create or replace function public.world_trade_fight_live(p_fight uuid)
 returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select p_fight is not null and exists (select 1 from public.world_pfights f where f.fight_id = p_fight and f.status in ('gather', 'fight'))
$f$;

create or replace function public.world_trade_sailing(p_uid uuid)
 returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select exists (select 1 from public.world_trade_aboard a join public.world_trade_voyages v on v.voyage_id = a.voyage_id
    where a.owner_id = p_uid and v.status in ('sail', 'raid') and not (v.status = 'raid' and public.world_trade_fight_live(v.fight_id)))
$f$;

create or replace function public.world_trade_raid_on(p_uid uuid)
 returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select exists (select 1 from public.world_trade_aboard a join public.world_trade_voyages v on v.voyage_id = a.voyage_id
    where a.owner_id = p_uid and v.status = 'raid' and public.world_trade_fight_live(v.fight_id))
$f$;

create or replace function public.world_trade_is_raid_fight(p_fight uuid)
 returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select exists (select 1 from public.world_trade_voyages v where v.fight_id = p_fight)
$f$;

create or replace function public.world_trade_ready(p_uid uuid, p_port text, p_other boolean default false)
 returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare c public.world_characters%rowtype; who text;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if not found then return '캐릭터를 찾을 수 없습니다.'; end if;
  who := case when p_other then c.character_name || '은(는) ' else '' end;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then return who || '전투불능 상태에서는 배를 탈 수 없습니다.'; end if;
  if public.world_busy_kind(p_uid) is not null then return public.world_busy_msg(p_uid, '배 타기', p_other); end if;
  if exists (select 1 from public.world_character_statuses s where s.owner_id = p_uid and s.status_key = 'yohwa_seal' and s.expires_at > now()) then
    return who || '봉인 해독 중에는 배를 탈 수 없습니다.'; end if;
  if public.world_trade_here(p_uid) is distinct from p_port then return who || '그 항구에 있어야 배를 탈 수 있습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = p_uid and not a.defeated and not coalesce(a.fled, false)) then
    return who || '전투 중에는 배를 탈 수 없습니다.'; end if;
  if exists (select 1 from public.world_pfight_members pm join public.world_pfights pf on pf.fight_id = pm.fight_id
              where pm.owner_id = p_uid and pm.out_reason is null and pf.status in ('gather', 'fight')) then return who || '토벌 중에는 배를 탈 수 없습니다.'; end if;
  if exists (select 1 from public.world_trade_aboard a where a.owner_id = p_uid) then return who || '이미 다른 배에 타고 있습니다.'; end if;
  return null;
end $f$;

create or replace function public.world_trade_dest_ok(p_uid uuid, p_port text)
 returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare r public.world_map_regions%rowtype; lv int; nm text;
begin
  select * into r from public.world_map_regions where region_id = p_port;
  select level, character_name into lv, nm from public.world_characters where owner_id = p_uid;
  if r.region_id is null then return '갈 수 없는 항구입니다.'; end if;
  if not (public.world_domain_open(p_uid, r.territory_id) and public.world_region_open(p_uid, r.region_id)) then
    return coalesce(nm, '') || '에게는 아직 ' || r.region_name || '(으)로 가는 뱃길이 열리지 않았습니다.'; end if;
  if lv < r.min_level then return r.region_name || '은(는) Lv.' || r.min_level || '부터 갈 수 있습니다(' || coalesce(nm, '') || ' Lv.' || lv || ').'; end if;
  return null;
end $f$;

create or replace function public.world_trade_note(p_uid uuid, p_kind text, p_title text, p_text text, p_payload jsonb)
 returns void language sql security definer set search_path to 'pg_catalog', 'public' as $f$
  insert into public.world_notifications(user_id, kind, title, content, payload) values (p_uid, p_kind, p_title, p_text, coalesce(p_payload, '{}'))
$f$;

create or replace function public.world_trade_demand_today()
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare d date := public.world_housing_today(); e jsonb := public.world_trade_demand_of(d); got date; who uuid; pn text;
begin
  if exists (select 1 from public.world_trade_demand where day = d) then return e; end if;
  insert into public.world_trade_demand(day, port_id, name) values (d, e ->> 'port', e ->> 'name') on conflict (day) do nothing returning day into got;
  if got is not null then
    who := coalesce((select owner_id from public.world_staff order by owner_id limit 1), (select owner_id from public.world_characters order by owner_id limit 1));
    pn := public.world_trade_port(e ->> 'port') ->> 'name';
    if who is not null then
      insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
      values ('global', who, '교역 소식', '오늘 ' || pn || '에 ' || (e ->> 'name') || '이(가) 들어 모든 교역품을 평소보다 비싸게 삽니다.');
    end if;
  end if;
  return e;
end $f$;

create or replace function public.world_trade_cargo_loss(p_uid uuid, p_pct numeric)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare h public.world_ship_hold%rowtype; n int; lost jsonb := '{}';
begin
  if coalesce(p_pct, 0) <= 0 then return lost; end if;
  for h in select * from public.world_ship_hold where owner_id = p_uid order by good_id for update loop
    n := least(h.qty, round(h.qty * p_pct / 100)::int);
    if n <= 0 then continue; end if;
    lost := lost || jsonb_build_object(h.good_id, n);
    if n >= h.qty then delete from public.world_ship_hold where owner_id = p_uid and good_id = h.good_id;
    else update public.world_ship_hold set qty = qty - n, cost = cost - cost * n / qty where owner_id = p_uid and good_id = h.good_id; end if;
  end loop;
  return lost;
end $f$;

create or replace function public.world_trade_sell_core(p_uid uuid, p_port text, p_items jsonb, p_prices jsonb, p_mul numeric, p_day date)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare r jsonb := public.world_trade_rules(); pr jsonb := r -> 'price'; cap int := (r ->> 'day_cap')::int; used int; k text; want int; h public.world_ship_hold%rowtype;
  g jsonb; base int; n int; unit int; gain int; gil_all bigint := 0; sold jsonb[] := '{}'; left_j jsonb := '{}'; base_add int := 0; nm text;
begin
  select coalesce(base_sum, 0) into used from public.world_trade_sales where owner_id = p_uid and day = p_day;
  used := coalesce(used, 0);
  for k, want in select e.key, (e.value)::text::int from jsonb_each(coalesce(p_items, '{}')) e where jsonb_typeof(e.value) = 'number' order by e.key loop
    if want <= 0 then continue; end if;
    select * into h from public.world_ship_hold where owner_id = p_uid and good_id = k for update;
    if not found then continue; end if;
    n := least(want, h.qty);
    g := public.world_trade_good(k);
    base := (g ->> 'base')::int;
    n := least(n, greatest(0, (cap - used) / base));
    if n < least(want, h.qty) then left_j := left_j || jsonb_build_object(k, least(want, h.qty) - n); end if;
    if n <= 0 then continue; end if;
    unit := coalesce((p_prices ->> k)::int, (public.world_trade_quote(p_port, k, public.world_housing_today(), 2) ->> 'price')::int);
    gain := round(unit * n * coalesce(p_mul, 1))::int;
    if n >= h.qty then delete from public.world_ship_hold where owner_id = p_uid and good_id = k;
    else update public.world_ship_hold set qty = qty - n, cost = cost - cost * n / qty where owner_id = p_uid and good_id = k; end if;
    insert into public.world_trade_flow(port_id, good_id, sold, at) values (p_port, k, n, now())
    on conflict (port_id, good_id) do update set
      sold = public.world_trade_flow.sold * greatest(0, 1 - extract(epoch from now() - public.world_trade_flow.at) / ((pr -> 'flow' ->> 'hours')::numeric * 3600)) + excluded.sold, at = now();
    used := used + base * n; base_add := base_add + base * n; gil_all := gil_all + gain;
    select item_name into nm from public.world_item_catalog where item_id = k;
    sold := sold || jsonb_build_object('good', k, 'name', nm, 'qty', n, 'unit', round(unit * coalesce(p_mul, 1))::int, 'gil', gain);
  end loop;
  if base_add > 0 then
    update public.world_characters set gil = gil + gil_all, updated_at = now() where owner_id = p_uid;
    insert into public.world_trade_sales(owner_id, day, base_sum, gil_sum) values (p_uid, p_day, base_add, gil_all)
    on conflict (owner_id, day) do update set base_sum = public.world_trade_sales.base_sum + excluded.base_sum, gil_sum = public.world_trade_sales.gil_sum + excluded.gil_sum;
    insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
    values (p_uid, 'trade_goods_sale', gil_all, false, jsonb_build_object('port', p_port, 'sold', to_jsonb(sold)));
  end if;
  return jsonb_build_object('sold', to_jsonb(sold), 'gil', gil_all, 'left', left_j, 'used', used, 'cap', cap);
end $f$;

create or replace function public.world_trade_ship_view(p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare s public.world_ships%rowtype; sr jsonb;
begin
  select * into s from public.world_ships where owner_id = p_uid;
  if not found then return null; end if;
  sr := public.world_trade_ship_rule(s.tier);
  return jsonb_build_object('tier', s.tier, 'kind', sr ->> 'name', 'name', coalesce(s.name, sr ->> 'name'), 'durability', s.durability, 'max', (sr ->> 'dur')::int,
    'broken', s.durability <= 0, 'slots', (sr ->> 'slots')::int, 'used', public.world_trade_slots_used(p_uid), 'crew', (sr ->> 'crew')::int, 'cabin', (sr ->> 'cabin')::int,
    'speed', (sr ->> 'speed')::numeric, 'port', s.port_id, 'port_name', public.world_trade_port(s.port_id) ->> 'name', 'status', s.status, 'voyage_id', s.voyage_id,
    'sell_port', s.sell_port, 'sell_pct', s.sell_pct, 'repair_gil', (public.world_trade_rules() -> 'dur' ->> 'repair_gil')::int * greatest(0, (sr ->> 'dur')::int - s.durability));
end $f$;

create or replace function public.world_trade_parts_view(p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare s public.world_ships%rowtype; nt int; need jsonb; have jsonb; sr jsonb; cats jsonb := '{}'; cat text; items jsonb; k text; n int; done boolean := true; ci jsonb;
begin
  select * into s from public.world_ships where owner_id = p_uid;
  if not found or s.tier >= 5 then return null; end if;
  nt := s.tier + 1;
  need := public.world_trade_rules() -> 'parts' -> nt::text;
  select parts into have from public.world_ship_parts where owner_id = p_uid and next_tier = nt;
  have := coalesce(have, '{}');
  sr := public.world_trade_ship_rule(nt);
  for cat, items in select key, value from jsonb_each(need) loop
    ci := '{}';
    for k, n in select key, value::text::int from jsonb_each(items) loop
      ci := ci || jsonb_build_object(k, jsonb_build_object('name', (select item_name from public.world_item_catalog where item_id = k), 'need', n,
        'have', least(n, coalesce((have -> cat ->> k)::int, 0))));
      if coalesce((have -> cat ->> k)::int, 0) < n then done := false; end if;
    end loop;
    cats := cats || jsonb_build_object(cat, jsonb_build_object('name', public.world_trade_rules() -> 'part_names' ->> cat, 'items', ci));
  end loop;
  return jsonb_build_object('tier', nt, 'name', sr ->> 'name', 'lv', (sr ->> 'lv')::int, 'gil', (sr ->> 'gil')::int, 'cats', cats, 'done', done);
end $f$;

create or replace function public.world_trade_voyage_view(p_voyage uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare v public.world_trade_voyages%rowtype;
begin
  select * into v from public.world_trade_voyages where voyage_id = p_voyage;
  if not found then return null; end if;
  return jsonb_build_object('id', v.voyage_id, 'mode', v.mode, 'status', v.status, 'from', v.from_port, 'to', v.to_port,
    'from_name', public.world_trade_port(v.from_port) ->> 'name', 'to_name', public.world_trade_port(v.to_port) ->> 'name',
    'captain', v.captain_id, 'captain_name', (select character_name from public.world_characters where owner_id = v.captain_id),
    'bonus', v.bonus, 'mates', v.mates, 'board_ends', v.board_ends, 'started_at', v.started_at, 'arrives_at', v.arrives_at,
    'check_at', case when v.status = 'board' then v.board_ends when v.mode = 'direct' and v.status = 'sail' and not v.raid_done then v.raid_at else v.arrives_at end,
    'fight_id', case when v.status = 'raid' then v.fight_id end,
    'crew', (select coalesce(jsonb_agg(jsonb_build_object('id', a.owner_id, 'name', c.character_name) order by a.joined_at), '[]'::jsonb)
               from public.world_trade_aboard a join public.world_characters c on c.owner_id = a.owner_id where a.voyage_id = v.voyage_id),
    'board', case when v.status = 'board' then (select coalesce(jsonb_agg(jsonb_build_object('id', b.owner_id, 'name', c.character_name, 'status', b.status)), '[]'::jsonb)
               from public.world_trade_board b join public.world_characters c on c.owner_id = b.owner_id where b.voyage_id = v.voyage_id) end,
    'result', case when v.status in ('done', 'cancelled') then v.result end);
end $f$;

create or replace function public.world_trade_finish(p_voyage uuid)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare v public.world_trade_voyages%rowtype; r jsonb := public.world_trade_rules(); s public.world_ships%rowtype; u uuid; lost jsonb; pct numeric; res jsonb := '{}';
  sold jsonb; rgn text; owners uuid[]; hagg int := 0; dd int := (r -> 'dur' ->> 'voyage')::int; vals jsonb;
begin
  select * into v from public.world_trade_voyages where voyage_id = p_voyage;
  select region_name into rgn from public.world_map_regions where region_id = v.to_port;
  owners := array(select x from (select a.owner_id x from public.world_trade_aboard a where a.voyage_id = v.voyage_id
                                 union select s2.owner_id from public.world_ships s2 where s2.ship_id = any (v.ships)) z order by x);
  perform 1 from public.world_characters where owner_id = any (owners) order by owner_id for update;
  if v.mode = 'direct' and v.bonus = 'haggle' and v.mates > 0 then hagg := (r -> 'bonus' -> 'haggle' ->> 'per')::int * least(v.mates, (r -> 'bonus' ->> 'max_mates')::int); end if;
  for s in select * from public.world_ships where ship_id = any (v.ships) order by owner_id for update loop
    if v.mode = 'send' and v.raid_roll then
      pct := (r -> 'raid' -> 'send_lose' ->> 0)::numeric + random() * ((r -> 'raid' -> 'send_lose' ->> 1)::numeric - (r -> 'raid' -> 'send_lose' ->> 0)::numeric);
      lost := public.world_trade_cargo_loss(s.owner_id, pct);
      res := res || jsonb_build_object('raid', jsonb_build_object('auto', true, 'pct', round(pct), 'lost', lost));
      dd := dd + (r -> 'dur' ->> 'raid')::int;
    end if;
    update public.world_ships set port_id = v.to_port, status = 'docked', voyage_id = null, durability = greatest(0, durability - dd),
      sell_port = case when hagg > 0 then v.to_port end, sell_pct = hagg, updated_at = now() where owner_id = s.owner_id;
  end loop;
  if v.mode = 'direct' then
    vals := public.world_trade_board_vals(v.to_port);
    update public.world_characters c set location = rgn, updated_at = now()
      where c.owner_id in (select a.owner_id from public.world_trade_aboard a where a.voyage_id = v.voyage_id);
    for u in select a.owner_id from public.world_trade_aboard a where a.voyage_id = v.voyage_id order by a.owner_id loop
      insert into public.world_trade_seen(owner_id, port_id, vals, at) values (u, v.to_port, vals, now())
      on conflict (owner_id, port_id) do update set vals = excluded.vals, at = excluded.at;
      perform public.world_trade_note(u, 'trade_arrive', '배가 닿음', (public.world_trade_port(v.to_port) ->> 'name') || '에 닿았습니다.', jsonb_build_object('voyage_id', v.voyage_id, 'port', v.to_port));
    end loop;
    delete from public.world_trade_aboard where voyage_id = v.voyage_id;
  else
    sold := public.world_trade_sell_core(v.captain_id,  v.to_port,
      (select coalesce(jsonb_object_agg(h.good_id, h.qty), '{}'::jsonb) from public.world_ship_hold h where h.owner_id = v.captain_id),
      v.prices, (r -> 'sail' ->> 'send_mul')::numeric, (v.arrives_at at time zone 'Asia/Seoul')::date);
    res := res || jsonb_build_object('sale', sold);
    perform public.world_trade_note(v.captain_id, 'trade_arrive', '보낸 배가 닿음',
      (public.world_trade_port(v.to_port) ->> 'name') || '에 배가 닿았습니다.'
        || case when coalesce((sold ->> 'gil')::int, 0) > 0 then ' 짐을 팔아 ' || (sold ->> 'gil') || '전을 받았습니다.' else '' end
        || case when res ? 'raid' then ' 뱃길에서 습격을 받아 짐 일부를 잃었습니다.' else '' end
        || case when sold -> 'left' <> '{}'::jsonb then ' 오늘 팔 수 있는 몫이 차서 남은 짐은 배에 실려 있습니다.' else '' end,
      jsonb_build_object('voyage_id', v.voyage_id, 'port', v.to_port));
  end if;
  update public.world_trade_voyages set status = 'done', finished_at = now(), result = result || res where voyage_id = v.voyage_id;
end $f$;

create or replace function public.world_trade_raid_spawn(p_voyage uuid)
 returns uuid language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare v public.world_trade_voyages%rowtype; r jsonb := public.world_trade_rules(); crew uuid[]; lv int; sea text[]; m public.world_region_monsters%rowtype; ld uuid; u uuid;
  rg text; hp int; atk int; df int; it text; fid uuid; nm text; pid uuid; n int := 0;
  oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true);
begin
  select * into v from public.world_trade_voyages where voyage_id = p_voyage;
  crew := array(select a.owner_id from public.world_trade_aboard a where a.voyage_id = v.voyage_id order by (a.owner_id = v.captain_id) desc, a.joined_at);
  select max(level) into lv from public.world_characters where owner_id = any (crew);
  lv := least(public.world_level_cap() + 1, coalesce(lv, 1) + (r -> 'raid' ->> 'lv_up')::int);
  sea := array(select jsonb_array_elements_text(coalesce(r -> 'ports' -> v.from_port -> 'sea', '[]')) union select jsonb_array_elements_text(coalesce(r -> 'ports' -> v.to_port -> 'sea', '[]')));
  if random() >= (r -> 'raid' ->> 'robber')::numeric then
    select * into m from public.world_region_monsters where region_id = any (sea) and role in ('common', 'main') order by random() limit 1;
  end if;
  if m.monster_id is null then select * into m from public.world_region_monsters where monster_id = r -> 'raid' ->> 'robber_id'; end if;
  if m.monster_id is null then return null; end if;
  foreach u in array crew loop
    if exists (select 1 from public.world_characters c where c.owner_id = u and not coalesce(c.is_dead, false) and c.downed_at is null and c.health > 0)
       and not exists (select 1 from public.world_active_encounters a where a.owner_id = u and not a.defeated and not coalesce(a.fled, false))
       and not exists (select 1 from public.world_pfight_members pm join public.world_pfights pf on pf.fight_id = pm.fight_id
                        where pm.owner_id = u and pm.out_reason is null and pf.status in ('gather', 'fight')) then ld := u; exit; end if;
  end loop;
  if ld is null then return null; end if;
  select (public.world_field_region(c.location)).region_id, c.character_name into rg, nm from public.world_characters c where c.owner_id = ld;
  hp := round(70 + lv * 14); atk := round(8 + lv * 1.1); df := round(lv * 0.6 * case when m.mechanic_key = 'armored' then 2 else 1 end);
  it := case when m.mechanic_key = 'ambush' then 'strike' else public.world_battle_intent_k(m.kind, lv, m.mechanic_key, 1, 'normal') end;
  insert into public.world_active_encounters(owner_id, region_id, monster_id, current_hp, max_hp, defeated, fled, started_at, updated_at,
    turn_count, analysis_turns, guard_until_turn, node_id, mlevel, atk, def, rank, intent, fx, pfx, log, last_action_at, result)
  values (ld, rg, m.monster_id, hp, hp, false, false, now(), now(), 0, 0, 0, null, lv, atk, df, 'normal', it, '{}', '{}',
    jsonb_build_array('뱃길 한가운데서 ' || m.monster_name || '이(가) 뱃전으로 기어올랐다.'), now() - interval '1 second', null)
  on conflict (owner_id) do update set region_id = excluded.region_id, monster_id = excluded.monster_id, current_hp = excluded.current_hp,
    max_hp = excluded.max_hp, defeated = false, fled = false, started_at = now(), updated_at = now(), turn_count = 0, analysis_turns = 0,
    guard_until_turn = 0, node_id = null, mlevel = excluded.mlevel, atk = excluded.atk, def = excluded.def, rank = excluded.rank,
    intent = excluded.intent, fx = '{}', pfx = '{}', log = excluded.log, last_action_at = excluded.last_action_at, result = null;
  select party_id into pid from public.world_party_members where owner_id = ld;
  insert into public.world_pfights(party_id, region_id, leader_id, monster_id, monster_name, rank, mlevel, base_hp, max_hp, hp, intent, fx, gather_ends, log)
  values (coalesce(pid, ld), rg, ld, m.monster_id, m.monster_name, 'normal', lv, hp, hp, hp, it, '{}', now() + interval '60 seconds',
    jsonb_build_array('뱃길 한가운데서 ' || m.monster_name || '이(가) 배를 덮쳤다.'))
  returning fight_id into fid;
  insert into public.world_pfight_members(fight_id, owner_id, name) values (fid, ld, nm);
  update public.world_trade_voyages set status = 'raid', fight_id = fid where voyage_id = v.voyage_id;
  foreach u in array crew loop
    if u = ld then continue; end if;
    perform set_config('request.jwt.claim.sub', u::text, true);
    perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    begin perform public.world_pfight_join(fid); n := n + 1; exception when others then null; end;
  end loop;
  perform set_config('request.jwt.claims', coalesce(oc, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  perform public.world_pfight_start(fid, true);
  foreach u in array crew loop
    perform public.world_trade_note(u, 'trade_raid', '뱃길 습격', m.monster_name || '이(가) 배를 덮쳤습니다. 물리치면 짐을 지킬 수 있습니다.',
      jsonb_build_object('voyage_id', v.voyage_id, 'fight_id', fid));
  end loop;
  return fid;
end $f$;

create or replace function public.world_trade_raid_end(p_voyage uuid)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare v public.world_trade_voyages%rowtype; r jsonb := public.world_trade_rules(); st text; mn text; pct numeric; lost jsonb := '{}'; s public.world_ships%rowtype; u uuid; won boolean;
begin
  select * into v from public.world_trade_voyages where voyage_id = p_voyage;
  select status, monster_name into st, mn from public.world_pfights where fight_id = v.fight_id;
  won := st = 'won';
  if not won then
    pct := (r -> 'raid' ->> 'lose_pct')::numeric;
    if v.bonus = 'guard' and v.mates > 0 then pct := pct * (1 - (r -> 'bonus' -> 'guard' ->> 'per')::numeric * least(v.mates, (r -> 'bonus' ->> 'max_mates')::int) / 100); end if;
    perform 1 from public.world_ships where ship_id = any (v.ships) order by owner_id for update;
    for s in select * from public.world_ships where ship_id = any (v.ships) order by owner_id loop
      lost := lost || jsonb_build_object(s.owner_id::text, public.world_trade_cargo_loss(s.owner_id, pct));
      update public.world_ships set durability = greatest(0, durability - (r -> 'dur' ->> 'raid')::int), updated_at = now() where owner_id = s.owner_id;
    end loop;
  end if;
  update public.world_trade_voyages set status = 'sail', raid_done = true, arrives_at = now() + greatest(interval '0', arrives_at - raid_at),
    result = result || jsonb_build_object('raid', jsonb_build_object('monster', mn, 'fight', st, 'won', won, 'pct', round(coalesce(pct, 0)), 'lost', lost))
   where voyage_id = v.voyage_id;
  for u in select a.owner_id from public.world_trade_aboard a where a.voyage_id = v.voyage_id loop
    perform public.world_trade_note(u, 'trade_raid', case when won then '습격을 물리침' else '습격에 짐을 잃음' end,
      case when won then mn || '을(를) 물리쳐 짐을 지켰습니다. 배는 다시 물길을 갑니다.'
           else mn || '에게 밀려 짐 일부를 잃고 배가 상했습니다. 배는 다시 물길을 갑니다.' end,
      jsonb_build_object('voyage_id', v.voyage_id, 'won', won, 'lost', coalesce(lost -> u::text, '{}')));
  end loop;
end $f$;

create or replace function public.world_trade_launch(p_voyage uuid)
 returns text language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare v public.world_trade_voyages%rowtype; r jsonb := public.world_trade_rules(); c public.world_characters%rowtype; s public.world_ships%rowtype; sr jsonb;
  why text; crew uuid[]; u uuid; v_mates int; mins numeric; p numeric; route int; v_ships uuid[]; tk int := (r -> 'sail' ->> 'tokens')::int; v_prices jsonb := '{}'; k text;
  fail text; seats int;
begin
  select * into v from public.world_trade_voyages where voyage_id = p_voyage;
  if v.status <> 'board' then return null; end if;
  crew := array(select v.captain_id union select b.owner_id from public.world_trade_board b where b.voyage_id = v.voyage_id and b.status = 'accepted');
  perform 1 from public.world_characters where owner_id = any (crew) order by owner_id for update;
  select * into c from public.world_characters where owner_id = v.captain_id;
  select * into s from public.world_ships where owner_id = v.captain_id for update;
  fail := public.world_trade_ready(v.captain_id, v.from_port, false);
  if fail is null and (s.owner_id is null or s.status <> 'docked' or s.port_id <> v.from_port) then fail := '배가 이 항구에 대 있지 않습니다.'; end if;
  if fail is null and s.durability <= 0 then fail := '배가 부서져 고치기 전에는 띄울 수 없습니다.'; end if;
  if fail is null then fail := public.world_trade_dest_ok(v.captain_id, v.to_port); end if;
  if fail is null and c.mount_tokens < tk then fail := '노정패가 모자랍니다. 필요 ' || tk || '개 / 보유 ' || c.mount_tokens || '개.'; end if;
  route := public.world_trade_route_min(v.from_port, v.to_port);
  if fail is null and route is null then fail := '두 항구 사이에 뱃길이 없습니다.'; end if;
  if fail is not null then
    update public.world_trade_voyages set status = 'cancelled', finished_at = now(), result = jsonb_build_object('why', fail) where voyage_id = v.voyage_id;
    for u in select b.owner_id from public.world_trade_board b where b.voyage_id = v.voyage_id and b.status in ('pending', 'accepted') loop
      perform public.world_trade_note(u, 'trade_cancel', '배가 뜨지 못함', fail, jsonb_build_object('voyage_id', v.voyage_id));
    end loop;
    update public.world_trade_board set status = 'cancelled' where voyage_id = v.voyage_id and status in ('pending', 'accepted');
    return fail;
  end if;
  sr := public.world_trade_ship_rule(s.tier);
  seats := (sr ->> 'crew')::int;
  crew := array[v.captain_id];
  if v.mode = 'direct' then
    for u in select b.owner_id from public.world_trade_board b where b.voyage_id = v.voyage_id and b.status = 'accepted' order by b.created_at, b.owner_id loop
      why := public.world_trade_ready(u, v.from_port, true);
      if why is null then why := public.world_trade_dest_ok(u, v.to_port); end if;
      if why is null and cardinality(crew) >= seats then why := '배에 자리가 모자랍니다.'; end if;
      if why is null then crew := crew || u;
      else
        update public.world_trade_board set status = 'cancelled' where voyage_id = v.voyage_id and owner_id = u;
        perform public.world_trade_note(u, 'trade_cancel', '배에 오르지 못함', why, jsonb_build_object('voyage_id', v.voyage_id));
      end if;
    end loop;
  end if;
  update public.world_trade_board set status = 'cancelled' where voyage_id = v.voyage_id and status = 'pending';
  v_mates := cardinality(crew) - 1;
  mins := route * (sr ->> 'speed')::numeric;
  if v.mode = 'direct' then
    mins := mins / (r -> 'sail' ->> 'direct_div')::numeric;
    if v.bonus = 'time' and v_mates > 0 then mins := mins * (1 - (r -> 'bonus' -> 'time' ->> 'per')::numeric * least(v_mates, (r -> 'bonus' ->> 'max_mates')::int) / 100); end if;
  end if;
  p := case when route >= (r -> 'raid' ->> 'far_min')::int or exists (select 1 from jsonb_array_elements(r -> 'cross') x
             where (x ->> 0 = v.from_port and x ->> 1 = v.to_port) or (x ->> 1 = v.from_port and x ->> 0 = v.to_port))
            then (r -> 'raid' ->> 'p_far')::numeric else (r -> 'raid' ->> 'p')::numeric end;
  v_ships := array[s.ship_id];
  if v.mode = 'direct' then
    v_ships := v_ships || array(select x.ship_id from public.world_ships x where x.owner_id = any (crew) and x.owner_id <> v.captain_id
                             and x.status = 'docked' and x.port_id = v.from_port and x.durability > 0 order by x.owner_id);
  else
    for k in select h.good_id from public.world_ship_hold h where h.owner_id = v.captain_id loop
      v_prices := v_prices || jsonb_build_object(k, (public.world_trade_quote(v.to_port, k, public.world_housing_today(), 3) ->> 'price')::int);
    end loop;
  end if;
  perform 1 from public.world_ships where ship_id = any (v_ships) order by owner_id for update;
  update public.world_ships set status = 'sailing', voyage_id = v.voyage_id, sell_port = null, sell_pct = 0, updated_at = now() where ship_id = any (v_ships);
  update public.world_characters set mount_tokens = mount_tokens - tk, updated_at = now() where owner_id = v.captain_id;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  values (v.captain_id, 'trade_sail_fare', -tk, true, jsonb_build_object('from', v.from_port, 'to', v.to_port, 'mode', v.mode));
  if v.mode = 'direct' then
    insert into public.world_trade_aboard(owner_id, voyage_id) select x, v.voyage_id from unnest(crew) x;
  end if;
  update public.world_trade_voyages set status = 'sail', mates = v_mates, ships = v_ships, started_at = now(),
    arrives_at = now() + make_interval(secs => mins * 60), raid_at = now() + make_interval(secs => mins * 30),
    raid_roll = random() * 100 < p, raid_done = (v.mode = 'send'), prices = v_prices,
    bonus = case when v_mates > 0 then v.bonus end
   where voyage_id = v.voyage_id;
  foreach u in array crew loop
    if u <> v.captain_id then
      perform public.world_trade_note(u, 'trade_sail', '배가 떠남', c.character_name || '의 배를 타고 ' || (public.world_trade_port(v.to_port) ->> 'name') || '(으)로 떠났습니다.',
        jsonb_build_object('voyage_id', v.voyage_id));
    end if;
  end loop;
  return null;
end $f$;

create or replace function public.world_trade_settle(p_voyage uuid)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare v public.world_trade_voyages%rowtype; i int;
begin
  for i in 1 .. 4 loop
    select * into v from public.world_trade_voyages where voyage_id = p_voyage;
    if not found or v.status in ('done', 'cancelled') then return; end if;
    if not ((v.status = 'board' and now() >= v.board_ends)
         or (v.status = 'sail' and v.mode = 'direct' and not v.raid_done and now() >= v.raid_at)
         or (v.status = 'raid' and not public.world_trade_fight_live(v.fight_id))
         or (v.status = 'sail' and v.raid_done and now() >= v.arrives_at)) then return; end if;
    select * into v from public.world_trade_voyages where voyage_id = p_voyage for update;
    if v.status = 'board' then
      if now() >= v.board_ends then perform public.world_trade_launch(v.voyage_id); end if;
    elsif v.status = 'sail' and v.mode = 'direct' and not v.raid_done then
      if now() >= v.raid_at then
        if not v.raid_roll or public.world_trade_raid_spawn(v.voyage_id) is null then
          update public.world_trade_voyages set raid_done = true where voyage_id = v.voyage_id;
        end if;
      end if;
    elsif v.status = 'raid' then
      if not public.world_trade_fight_live(v.fight_id) then perform public.world_trade_raid_end(v.voyage_id); end if;
    elsif v.status = 'sail' and v.raid_done and now() >= v.arrives_at then
      perform public.world_trade_finish(v.voyage_id);
    end if;
  end loop;
end $f$;

create or replace function public.world_trade_tick(p_uid uuid)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare x uuid;
begin
  if p_uid is null then return; end if;
  for x in select a.voyage_id from public.world_trade_aboard a where a.owner_id = p_uid
           union select v.voyage_id from public.world_trade_voyages v where v.captain_id = p_uid and v.status in ('board', 'sail', 'raid')
           union select b.voyage_id from public.world_trade_board b where b.owner_id = p_uid and b.status in ('pending', 'accepted') loop
    perform public.world_trade_settle(x);
  end loop;
end $f$;

create or replace function public.world_trade_brief(p_uid uuid)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare me uuid; sends jsonb; inv jsonb;
begin
  if p_uid is null then return null; end if;
  if not exists (select 1 from public.world_ships s where s.owner_id = p_uid) and not exists (select 1 from public.world_trade_board b where b.owner_id = p_uid and b.status = 'pending')
     and not exists (select 1 from public.world_trade_aboard a where a.owner_id = p_uid) then return null; end if;
  perform public.world_trade_tick(p_uid);
  select a.voyage_id into me from public.world_trade_aboard a where a.owner_id = p_uid;
  select coalesce(jsonb_agg(public.world_trade_voyage_view(v.voyage_id)), '[]'::jsonb) into sends from public.world_trade_voyages v
   where v.captain_id = p_uid and v.mode = 'send' and v.status = 'sail';
  select coalesce(jsonb_agg(public.world_trade_voyage_view(b.voyage_id)), '[]'::jsonb) into inv from public.world_trade_board b join public.world_trade_voyages v on v.voyage_id = b.voyage_id
   where b.owner_id = p_uid and b.status = 'pending' and v.status = 'board';
  if me is null and sends = '[]'::jsonb and inv = '[]'::jsonb
     and not exists (select 1 from public.world_trade_voyages v where v.captain_id = p_uid and v.status = 'board') then return null; end if;
  return jsonb_build_object('voyage', public.world_trade_voyage_view(coalesce(me, (select v.voyage_id from public.world_trade_voyages v where v.captain_id = p_uid and v.status = 'board' limit 1))),
    'sends', sends, 'invites', inv);
end $f$;

create or replace function public.world_trade_status()
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return coalesce(public.world_trade_brief(uid), '{}'::jsonb);
end $f$;

create or replace function public.world_trade_view(p_port text default null)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_trade_rules(); here text; port text; live boolean; board jsonb; seen public.world_trade_seen%rowtype;
  d date := public.world_housing_today(); dem jsonb; used int; ports jsonb; c public.world_characters%rowtype; ship_port text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_trade_tick(uid);
  dem := public.world_trade_demand_today();
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  here := case when public.world_trade_sailing(uid) then null else public.world_trade_here(uid) end;
  port := case when p_port is not null and r -> 'ports' ? p_port then p_port else here end;
  live := port is not null and port = here;
  select port_id into ship_port from public.world_ships where owner_id = uid;
  if live then board := public.world_trade_board_vals(port);
  elsif port is not null then
    select * into seen from public.world_trade_seen where owner_id = uid and port_id = port;
    board := seen.vals;
  end if;
  select coalesce(base_sum, 0) into used from public.world_trade_sales where owner_id = uid and day = d;
  select coalesce(jsonb_agg(jsonb_build_object('id', p.key, 'name', p.value ->> 'name', 'dock', p.value ->> 'dock', 'shipyard', (p.value ->> 'shipyard')::boolean,
      'realm', p.value ->> 'realm', 'good', p.value ->> 'good', 'lv', g.min_level, 'open', public.world_trade_dest_ok(uid, p.key) is null,
      'seen_at', (select s.at from public.world_trade_seen s where s.owner_id = uid and s.port_id = p.key),
      'minutes', public.world_trade_route_min(coalesce(ship_port, here), p.key)) order by g.min_level, p.key), '[]'::jsonb)
    into ports from jsonb_each(r -> 'ports') p left join public.world_map_regions g on g.region_id = p.key;
  return jsonb_build_object('here', here, 'port', port, 'port_name', public.world_trade_port(port) ->> 'name', 'live', live, 'shipyard', coalesce((public.world_trade_port(port) ->> 'shipyard')::boolean, false),
    'board', board, 'seen_at', case when not live then seen.at end, 'seek', case when live then to_jsonb(public.world_trade_seek(port, d)) end,
    'demand', dem || jsonb_build_object('port_name', public.world_trade_port(dem ->> 'port') ->> 'name'),
    'ports', ports, 'ship', public.world_trade_ship_view(uid), 'hold', public.world_trade_hold(uid), 'parts', public.world_trade_parts_view(uid),
    'brief', public.world_trade_brief(uid), 'day', jsonb_build_object('used', coalesce(used, 0), 'cap', (r ->> 'day_cap')::int),
    'tokens', c.mount_tokens, 'gil', c.gil, 'level', c.level);
end $f$;

create or replace function public.world_trade_guard_here(p_what text)
 returns text language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; here text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_travel_guard(p_what);
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null then raise exception '전투불능 상태에서는 %을(를) 할 수 없습니다.', p_what; end if;
  here := public.world_trade_here(uid);
  if here is null then raise exception '항구에서만 %을(를) 할 수 있습니다.', p_what using hint = 'no_port'; end if;
  return here;
end $f$;

create or replace function public.world_trade_my_ship(p_uid uuid, p_here text, p_what text)
 returns public.world_ships language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare s public.world_ships%rowtype;
begin
  select * into s from public.world_ships where owner_id = p_uid for update;
  if not found then raise exception '아직 배가 없습니다. 조선소가 있는 항구에서 나룻배를 받으세요.' using hint = 'no_ship'; end if;
  if s.status <> 'docked' then raise exception '배가 물길에 나가 있어 %을(를) 할 수 없습니다.', p_what using hint = 'ship_away'; end if;
  if s.port_id <> p_here then raise exception '배는 %에 대 있습니다. 그 항구에서 %을(를) 하세요.', public.world_trade_port(s.port_id) ->> 'name', p_what using hint = 'ship_elsewhere'; end if;
  return s;
end $f$;

create or replace function public.world_trade_ship_get()
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); here text := public.world_trade_guard_here('배 받기'); sr jsonb := public.world_trade_ship_rule(1);
begin
  perform 1 from public.world_characters where owner_id = uid for update;
  if not coalesce((public.world_trade_port(here) ->> 'shipyard')::boolean, false) then raise exception '나룻배는 조선소가 있는 항구에서 받을 수 있습니다.' using hint = 'no_shipyard'; end if;
  if exists (select 1 from public.world_ships where owner_id = uid) then raise exception '이미 배가 있습니다.' using hint = 'have_ship'; end if;
  insert into public.world_ships(owner_id, tier, durability, port_id) values (uid, 1, (sr ->> 'dur')::int, here);
  return jsonb_build_object('ok', true, 'content', (sr ->> 'name') || '을(를) 받았습니다.', 'ship', public.world_trade_ship_view(uid));
end $f$;

create or replace function public.world_trade_ship_name(p_name text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); nm text := nullif(btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')), '');
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if nm is not null and char_length(nm) > (public.world_trade_rules() ->> 'name_max')::int then
    raise exception '배 이름은 %자까지 지을 수 있습니다.', public.world_trade_rules() ->> 'name_max'; end if;
  update public.world_ships set name = nm, updated_at = now() where owner_id = uid;
  if not found then raise exception '아직 배가 없습니다.' using hint = 'no_ship'; end if;
  return jsonb_build_object('ok', true, 'ship', public.world_trade_ship_view(uid));
end $f$;

create or replace function public.world_trade_ship_part(p_items jsonb)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); here text := public.world_trade_guard_here('조선 재료 넣기'); r jsonb := public.world_trade_rules(); c public.world_characters%rowtype;
  s public.world_ships%rowtype; nt int; need jsonb; have jsonb; k text; n int; cat text; room int; take jsonb := '{}'; tot int := 0; st jsonb; ok boolean; mt jsonb; xp int;
begin
  select * into c from public.world_characters where owner_id = uid for update;
  s := public.world_trade_my_ship(uid, here, '조선');
  if not coalesce((public.world_trade_port(here) ->> 'shipyard')::boolean, false) then raise exception '조선은 조선소가 있는 항구에서 할 수 있습니다.' using hint = 'no_shipyard'; end if;
  if s.tier >= 5 then raise exception '이미 가장 큰 배입니다.' using hint = 'max_tier'; end if;
  nt := s.tier + 1; need := r -> 'parts' -> nt::text;
  insert into public.world_ship_parts(owner_id, next_tier, parts) values (uid, nt, '{}')
  on conflict (owner_id) do update set next_tier = excluded.next_tier, parts = case when public.world_ship_parts.next_tier = excluded.next_tier then public.world_ship_parts.parts else '{}' end;
  select parts into have from public.world_ship_parts where owner_id = uid for update;
  for k, n in select e.key, (e.value)::text::int from jsonb_each(coalesce(p_items, '{}')) e where jsonb_typeof(e.value) = 'number' loop
    if n <= 0 then continue; end if;
    select x.key into cat from jsonb_each(need) x where x.value ? k limit 1;
    if cat is null then raise exception '%은(는) 이번 배에 드는 재료가 아닙니다.', coalesce((select item_name from public.world_item_catalog where item_id = k), k) using hint = 'not_part'; end if;
    room := (need -> cat ->> k)::int - coalesce((have -> cat ->> k)::int, 0) - coalesce((take ->> k)::int, 0);
    n := least(n, room);
    if n <= 0 then continue; end if;
    take := take || jsonb_build_object(k, coalesce((take ->> k)::int, 0) + n);
    cat := null;
  end loop;
  if take = '{}'::jsonb then raise exception '더 넣을 재료가 없습니다.' using hint = 'parts_full'; end if;
  ok := exists (select 1 from public.world_current_shop(uid)) and not public.world_weak_here(uid, 'storage');
  if ok then select items into st from public.world_storage where owner_id = uid for update; end if;
  mt := public.world_materials_take(coalesce(c.inventory, '{}'::jsonb), case when ok then coalesce(st, '{}'::jsonb) else '{}'::jsonb end, take);
  for k, n in select e.key, (e.value)::text::int from jsonb_each(take) e loop
    select x.key into cat from jsonb_each(need) x where x.value ? k limit 1;
    have := jsonb_set(have, array[cat], coalesce(have -> cat, '{}') || jsonb_build_object(k, coalesce((have -> cat ->> k)::int, 0) + n), true);
    tot := tot + n;
  end loop;
  xp := least((r -> 'part_xp' ->> 'cap')::int, tot * (r -> 'part_xp' ->> 'per')::int);
  update public.world_characters set inventory = mt -> 'inv', skill_progress = public.world_skill_add(skill_progress, r -> 'part_xp' ->> 'line', xp), updated_at = now() where owner_id = uid;
  if ok and mt -> 'from_st' <> '{}'::jsonb then
    update public.world_storage set items = (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(mt -> 'st') where jsonb_typeof(value) = 'number' and value::text::int > 0), updated_at = now() where owner_id = uid;
  end if;
  update public.world_ship_parts set parts = have, updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'put', take, 'from_storage', mt -> 'from_st', 'parts', public.world_trade_parts_view(uid));
end $f$;

create or replace function public.world_trade_ship_upgrade()
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); here text := public.world_trade_guard_here('배 짓기'); c public.world_characters%rowtype; s public.world_ships%rowtype; pv jsonb; sr jsonb;
begin
  select * into c from public.world_characters where owner_id = uid for update;
  s := public.world_trade_my_ship(uid, here, '배 짓기');
  if not coalesce((public.world_trade_port(here) ->> 'shipyard')::boolean, false) then raise exception '배는 조선소가 있는 항구에서 지을 수 있습니다.' using hint = 'no_shipyard'; end if;
  perform 1 from public.world_ship_parts where owner_id = uid for update;
  pv := public.world_trade_parts_view(uid);
  if pv is null then raise exception '이미 가장 큰 배입니다.' using hint = 'max_tier'; end if;
  if c.level < (pv ->> 'lv')::int then raise exception '%은(는) Lv.%부터 지을 수 있습니다.', pv ->> 'name', pv ->> 'lv' using hint = 'level'; end if;
  if not (pv ->> 'done')::boolean then raise exception '아직 넣지 않은 재료가 있습니다.' using hint = 'parts'; end if;
  if c.gil < (pv ->> 'gil')::int then raise exception '전이 모자랍니다(필요 %전).', pv ->> 'gil' using hint = 'gil'; end if;
  sr := public.world_trade_ship_rule((pv ->> 'tier')::int);
  update public.world_characters set gil = gil - (pv ->> 'gil')::int, updated_at = now() where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'trade_ship_build', -(pv ->> 'gil')::int, true, jsonb_build_object('tier', pv ->> 'tier'));
  update public.world_ships set tier = (pv ->> 'tier')::int, durability = (sr ->> 'dur')::int, updated_at = now() where owner_id = uid;
  delete from public.world_ship_parts where owner_id = uid;
  return jsonb_build_object('ok', true, 'content', (sr ->> 'name') || '을(를) 지었습니다.', 'ship', public.world_trade_ship_view(uid), 'parts', public.world_trade_parts_view(uid));
end $f$;

create or replace function public.world_trade_repair(p_points int default null)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); here text := public.world_trade_guard_here('배 고치기'); c public.world_characters%rowtype; s public.world_ships%rowtype; mx int; n int; cost int;
begin
  select * into c from public.world_characters where owner_id = uid for update;
  s := public.world_trade_my_ship(uid, here, '배 고치기');
  mx := (public.world_trade_ship_rule(s.tier) ->> 'dur')::int;
  n := least(mx - s.durability, coalesce(p_points, mx - s.durability));
  if n <= 0 then raise exception '고칠 곳이 없습니다.' using hint = 'full'; end if;
  cost := n * (public.world_trade_rules() -> 'dur' ->> 'repair_gil')::int;
  if c.gil < cost then raise exception '전이 모자랍니다(필요 %전).', cost using hint = 'gil'; end if;
  update public.world_characters set gil = gil - cost, updated_at = now() where owner_id = uid;
  update public.world_ships set durability = durability + n, updated_at = now() where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'trade_ship_repair', -cost, true, jsonb_build_object('points', n));
  return jsonb_build_object('ok', true, 'points', n, 'gil', cost, 'ship', public.world_trade_ship_view(uid));
end $f$;

create or replace function public.world_trade_buy(p_good text, p_qty int)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); here text := public.world_trade_guard_here('교역품 싣기'); c public.world_characters%rowtype; s public.world_ships%rowtype; g jsonb; unit int; n int; cost int;
begin
  select * into c from public.world_characters where owner_id = uid for update;
  s := public.world_trade_my_ship(uid, here, '교역품 싣기');
  g := public.world_trade_good(p_good);
  if g is null or (g ->> 'food')::boolean or g ->> 'port' <> here then raise exception '이 항구에서 파는 교역품이 아닙니다.' using hint = 'not_here'; end if;
  n := least(coalesce(p_qty, 0), public.world_trade_room(uid, p_good));
  if coalesce(p_qty, 0) <= 0 then raise exception '살 수량을 정하세요.'; end if;
  if n <= 0 then raise exception '짐칸에 자리가 없습니다.' using hint = 'hold_full'; end if;
  unit := (public.world_trade_quote(here, p_good, public.world_housing_today(), 0) ->> 'price')::int;
  cost := unit * n;
  if c.gil < cost then raise exception '전이 모자랍니다(필요 %전).', cost using hint = 'gil'; end if;
  update public.world_characters set gil = gil - cost, updated_at = now() where owner_id = uid;
  insert into public.world_ship_hold(owner_id, good_id, qty, cost) values (uid, p_good, n, cost)
  on conflict (owner_id, good_id) do update set qty = public.world_ship_hold.qty + excluded.qty, cost = public.world_ship_hold.cost + excluded.cost;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'trade_goods_buy', -cost, true, jsonb_build_object('port', here, 'good', p_good, 'qty', n));
  return jsonb_build_object('ok', true, 'good', p_good, 'qty', n, 'unit', unit, 'gil', cost, 'short', p_qty - n, 'hold', public.world_trade_hold(uid), 'ship', public.world_trade_ship_view(uid));
end $f$;

create or replace function public.world_trade_load(p_item text, p_qty int)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); here text := public.world_trade_guard_here('짐 싣기'); c public.world_characters%rowtype; s public.world_ships%rowtype; b text; g jsonb; have int; n int;
begin
  select * into c from public.world_characters where owner_id = uid for update;
  s := public.world_trade_my_ship(uid, here, '짐 싣기');
  b := public.world_item_base(p_item);
  g := public.world_trade_good(b);
  if g is null or not (g ->> 'food')::boolean then raise exception '배에 실을 수 있는 물품이 아닙니다(교역품과 세력 특선 음식만).' using hint = 'not_good'; end if;
  have := coalesce((c.inventory ->> p_item)::int, 0);
  if coalesce(p_qty, 0) <= 0 then raise exception '실을 수량을 정하세요.'; end if;
  n := least(p_qty, have, public.world_trade_room(uid, b));
  if have <= 0 then raise exception '가방에 없습니다.' using hint = 'none'; end if;
  if n <= 0 then raise exception '짐칸에 자리가 없습니다.' using hint = 'hold_full'; end if;
  update public.world_characters set inventory = case when have - n <= 0 then inventory - p_item else jsonb_set(inventory, array[p_item], to_jsonb(have - n)) end, updated_at = now() where owner_id = uid;
  insert into public.world_ship_hold(owner_id, good_id, qty, cost) values (uid, b, n, (g ->> 'base')::int * n)
  on conflict (owner_id, good_id) do update set qty = public.world_ship_hold.qty + excluded.qty, cost = public.world_ship_hold.cost + excluded.cost;
  return jsonb_build_object('ok', true, 'good', b, 'qty', n, 'hold', public.world_trade_hold(uid), 'ship', public.world_trade_ship_view(uid));
end $f$;

create or replace function public.world_trade_sell(p_items jsonb)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); here text := public.world_trade_guard_here('교역품 팔기'); s public.world_ships%rowtype; res jsonb;
begin
  perform 1 from public.world_characters where owner_id = uid for update;
  s := public.world_trade_my_ship(uid, here, '교역품 팔기');
  res := public.world_trade_sell_core(uid, here, p_items, null, 1 + case when s.sell_port = here then s.sell_pct else 0 end / 100.0, public.world_housing_today());
  if jsonb_array_length(res -> 'sold') = 0 then
    if res -> 'left' <> '{}'::jsonb then raise exception '오늘 팔 수 있는 몫(정가 합 %전)이 찼습니다. 한국 시각 0시에 다시 찹니다.', res ->> 'cap' using hint = 'day_cap'; end if;
    raise exception '팔 짐이 없습니다.' using hint = 'none';
  end if;
  return res || jsonb_build_object('ok', true, 'hold', public.world_trade_hold(uid), 'ship', public.world_trade_ship_view(uid));
end $f$;

create or replace function public.world_trade_sail(p_to text, p_mode text default 'direct', p_bonus text default null, p_party boolean default false)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); here text := public.world_trade_guard_here('배 띄우기'); r jsonb := public.world_trade_rules(); c public.world_characters%rowtype;
  s public.world_ships%rowtype; vid uuid; why text; pid uuid; n int := 0; u uuid; ends timestamptz;
begin
  if p_mode not in ('direct', 'send') then raise exception '알 수 없는 항해 방식입니다.'; end if;
  if p_bonus is not null and not (r -> 'bonus' ? p_bonus and p_bonus <> 'max_mates') then raise exception '알 수 없는 덤입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  s := public.world_trade_my_ship(uid, here, '배 띄우기');
  if s.durability <= 0 then raise exception '배가 부서져 고치기 전에는 띄울 수 없습니다.' using hint = 'broken'; end if;
  if not (r -> 'ports' ? p_to) or p_to = here then raise exception '갈 항구를 고르세요.'; end if;
  if public.world_trade_route_min(here, p_to) is null then raise exception '두 항구 사이에 뱃길이 없습니다.' using hint = 'no_route'; end if;
  why := public.world_trade_dest_ok(uid, p_to);
  if why is not null then raise exception '%', why using hint = 'dest'; end if;
  if c.mount_tokens < (r -> 'sail' ->> 'tokens')::int then
    raise exception '노정패가 모자랍니다. 필요 %개 / 보유 %개.', r -> 'sail' ->> 'tokens', c.mount_tokens using hint = 'tokens'; end if;
  if exists (select 1 from public.world_trade_voyages v where v.captain_id = uid and v.status in ('board', 'sail', 'raid') and (v.mode = 'direct' or v.status = 'board')) then
    raise exception '이미 띄우려는 배가 있습니다.' using hint = 'busy'; end if;
  if p_mode = 'direct' then
    why := public.world_trade_ready(uid, here, false);
    if why is not null then raise exception '%', why; end if;
  end if;
  if exists (select 1 from public.world_trade_board b join public.world_trade_voyages v on v.voyage_id = b.voyage_id
              where b.owner_id = uid and b.status = 'accepted' and v.status = 'board') then raise exception '다른 배에 오르기로 했습니다. 먼저 그 배에서 내리세요.' using hint = 'boarding'; end if;
  ends := now() + make_interval(secs => (r -> 'sail' ->> 'board_s')::int);
  insert into public.world_trade_voyages(captain_id, mode, from_port, to_port, status, bonus, board_ends)
  values (uid, p_mode, here, p_to, 'board', p_bonus, ends) returning voyage_id into vid;
  if p_mode = 'direct' and p_party then
    select party_id into pid from public.world_party_members where owner_id = uid;
    if pid is not null then
      for u in select m.owner_id from public.world_party_members m where m.party_id = pid and m.owner_id <> uid order by m.owner_id loop
        if public.world_trade_ready(u, here, true) is null then
          insert into public.world_trade_board(voyage_id, owner_id) values (vid, u);
          perform public.world_trade_note(u, 'trade_board', '배에 오르기',
            c.character_name || '이(가) ' || (public.world_trade_port(p_to) ->> 'name') || '(으)로 가는 배에 함께 타자고 합니다. '
              || (r -> 'sail' ->> 'board_s') || '초 안에 답하세요.'
              || coalesce(' 덤: ' || (r -> 'bonus' -> p_bonus ->> 'name') || '.', ''),
            jsonb_build_object('voyage_id', vid, 'to', p_to, 'bonus', p_bonus, 'ends', ends));
          n := n + 1;
        end if;
      end loop;
    end if;
    if n = 0 then raise exception '같은 항구에 함께 탈 수 있는 파티원이 없습니다.' using hint = 'no_mates'; end if;
    return jsonb_build_object('ok', true, 'voyage_id', vid, 'board', true, 'invited', n, 'board_ends', ends,
      'content', n || '명에게 함께 타자고 했습니다. ' || (r -> 'sail' ->> 'board_s') || '초 뒤에 떠납니다.');
  end if;
  why := public.world_trade_launch(vid);
  if why is not null then raise exception '%', why; end if;
  return jsonb_build_object('ok', true, 'voyage_id', vid, 'board', false, 'voyage', public.world_trade_voyage_view(vid),
    'content', case when p_mode = 'send' then '배를 ' || (public.world_trade_port(p_to) ->> 'name') || '(으)로 보냈습니다.'
                    else (public.world_trade_port(p_to) ->> 'name') || '(으)로 배를 띄웠습니다.' end);
end $f$;

create or replace function public.world_trade_board_respond(p_voyage uuid, p_accept boolean)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); v public.world_trade_voyages%rowtype; b public.world_trade_board%rowtype; why text; seats int; nm text; left_n int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into v from public.world_trade_voyages where voyage_id = p_voyage for update;
  if not found or v.status <> 'board' or now() >= v.board_ends then raise exception '이미 떠났거나 끝난 배입니다.' using hint = 'gone'; end if;
  select * into b from public.world_trade_board where voyage_id = p_voyage and owner_id = uid for update;
  if not found or b.status <> 'pending' then raise exception '이미 답했습니다.' using hint = 'answered'; end if;
  if p_accept then
    why := public.world_trade_ready(uid, v.from_port, false);
    if why is null then why := public.world_trade_dest_ok(uid, v.to_port); end if;
    if why is not null then raise exception '%', why; end if;
    if exists (select 1 from public.world_trade_board x join public.world_trade_voyages y on y.voyage_id = x.voyage_id
                where x.owner_id = uid and x.status = 'accepted' and y.status = 'board') then raise exception '다른 배에 오르기로 했습니다.' using hint = 'boarding'; end if;
    seats := (public.world_trade_ship_rule((select tier from public.world_ships where owner_id = v.captain_id)) ->> 'crew')::int;
    if (select count(*) from public.world_trade_board where voyage_id = p_voyage and status = 'accepted') + 1 >= seats then
      raise exception '배에 자리가 다 찼습니다.' using hint = 'full'; end if;
  end if;
  update public.world_trade_board set status = case when p_accept then 'accepted' else 'declined' end where voyage_id = p_voyage and owner_id = uid;
  update public.world_notifications set read_at = now() where user_id = uid and kind = 'trade_board' and read_at is null and payload ->> 'voyage_id' = p_voyage::text;
  select character_name into nm from public.world_characters where owner_id = uid;
  perform public.world_trade_note(v.captain_id, 'trade_board_reply', case when p_accept then '함께 탐' else '사양함' end,
    nm || case when p_accept then '이(가) 배에 오르기로 했습니다.' else '이(가) 배에 오르지 않겠다고 했습니다.' end, jsonb_build_object('voyage_id', p_voyage, 'accept', p_accept));
  select count(*) into left_n from public.world_trade_board where voyage_id = p_voyage and status = 'pending';
  if left_n = 0 then perform public.world_trade_launch(p_voyage); end if;
  return jsonb_build_object('ok', true, 'accepted', p_accept, 'voyage', public.world_trade_voyage_view(p_voyage));
end $f$;

create or replace function public.world_trade_depart(p_voyage uuid, p_bonus text default null)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); v public.world_trade_voyages%rowtype; why text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into v from public.world_trade_voyages where voyage_id = p_voyage for update;
  if not found or v.status <> 'board' then return jsonb_build_object('ok', true, 'done', true, 'voyage', public.world_trade_voyage_view(p_voyage)); end if;
  if v.captain_id <> uid and not (now() >= v.board_ends and exists (select 1 from public.world_trade_board b where b.voyage_id = p_voyage and b.owner_id = uid)) then
    raise exception '선장만 지금 떠날 수 있습니다.' using hint = 'not_captain'; end if;
  if p_bonus is not null and v.captain_id = uid then
    if not (public.world_trade_rules() -> 'bonus' ? p_bonus and p_bonus <> 'max_mates') then raise exception '알 수 없는 덤입니다.'; end if;
    update public.world_trade_voyages set bonus = p_bonus where voyage_id = p_voyage;
  end if;
  why := public.world_trade_launch(p_voyage);
  return jsonb_build_object('ok', why is null, 'why', why, 'voyage', public.world_trade_voyage_view(p_voyage));
end $f$;

create or replace function public.world_trade_board_cancel(p_voyage uuid)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); v public.world_trade_voyages%rowtype; u uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into v from public.world_trade_voyages where voyage_id = p_voyage for update;
  if not found or v.status <> 'board' then raise exception '이미 떠났거나 끝난 배입니다.' using hint = 'gone'; end if;
  if v.captain_id = uid then
    update public.world_trade_voyages set status = 'cancelled', finished_at = now(), result = jsonb_build_object('why', 'captain') where voyage_id = p_voyage;
    for u in select b.owner_id from public.world_trade_board b where b.voyage_id = p_voyage and b.status in ('pending', 'accepted') loop
      update public.world_notifications set read_at = now() where user_id = u and kind = 'trade_board' and read_at is null and payload ->> 'voyage_id' = p_voyage::text;
      perform public.world_trade_note(u, 'trade_cancel', '배가 뜨지 않음', '선장이 배 띄우기를 그만두었습니다.', jsonb_build_object('voyage_id', p_voyage));
    end loop;
    update public.world_trade_board set status = 'cancelled' where voyage_id = p_voyage and status in ('pending', 'accepted');
  else
    update public.world_trade_board set status = 'cancelled' where voyage_id = p_voyage and owner_id = uid and status in ('pending', 'accepted');
    if not found then raise exception '이 배에 오르기로 하지 않았습니다.'; end if;
  end if;
  return jsonb_build_object('ok', true, 'voyage', public.world_trade_voyage_view(p_voyage));
end $f$;

do $$
declare f text;
begin
  foreach f in array array[
    'world_trade_hash(text)', 'world_trade_port(text)', 'world_trade_ship_rule(int)', 'world_trade_route_min(text,text)', 'world_trade_here(uuid)', 'world_trade_good(text)',
    'world_trade_seek(text,date)', 'world_trade_demand_of(date)', 'world_trade_quote(text,text,date,int)', 'world_trade_board_vals(text)', 'world_trade_hold(uuid)',
    'world_trade_slots_used(uuid)', 'world_trade_room(uuid,text)', 'world_trade_fight_live(uuid)', 'world_trade_sailing(uuid)', 'world_trade_raid_on(uuid)',
    'world_trade_is_raid_fight(uuid)', 'world_trade_ready(uuid,text,boolean)', 'world_trade_dest_ok(uuid,text)', 'world_trade_note(uuid,text,text,text,jsonb)',
    'world_trade_demand_today()', 'world_trade_cargo_loss(uuid,numeric)', 'world_trade_sell_core(uuid,text,jsonb,jsonb,numeric,date)', 'world_trade_ship_view(uuid)',
    'world_trade_parts_view(uuid)', 'world_trade_voyage_view(uuid)', 'world_trade_finish(uuid)', 'world_trade_raid_spawn(uuid)', 'world_trade_raid_end(uuid)',
    'world_trade_launch(uuid)', 'world_trade_settle(uuid)', 'world_trade_tick(uuid)', 'world_trade_brief(uuid)', 'world_trade_guard_here(text)',
    'world_trade_my_ship(uuid,text,text)'] loop
    perform pg_temp.yh_share('public.' || f);
  end loop;
  foreach f in array array[
    'world_trade_status()', 'world_trade_view(text)', 'world_trade_ship_get()', 'world_trade_ship_name(text)', 'world_trade_ship_part(jsonb)', 'world_trade_ship_upgrade()',
    'world_trade_repair(int)', 'world_trade_buy(text,int)', 'world_trade_load(text,int)', 'world_trade_sell(jsonb)', 'world_trade_sail(text,text,text,boolean)',
    'world_trade_board_respond(uuid,boolean)', 'world_trade_depart(uuid,text)', 'world_trade_board_cancel(uuid)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $$;
