create or replace function pg_temp.yh_rb_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname in ('service_role', 'postgres') loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function public.world_realm_bond_day()
 returns date language sql stable set search_path to 'pg_catalog' as $f$
  select (now() at time zone 'Asia/Seoul')::date
$f$;

create or replace function public.world_realm_bond_day0()
 returns timestamptz language sql stable set search_path to 'pg_catalog' as $f$
  select ((now() at time zone 'Asia/Seoul')::date)::timestamp at time zone 'Asia/Seoul'
$f$;

create or replace function public.world_realm_bond_realm(p_region text)
 returns text language sql immutable set search_path to 'pg_catalog', 'public' as $f$
  select public.world_realm_bond_rules() -> 'regions' ->> p_region
$f$;

create or replace function public.world_realm_bond_stage_name(p_stage int)
 returns text language sql immutable set search_path to 'pg_catalog', 'public' as $f$
  select s ->> 'name' from jsonb_array_elements(public.world_realm_bond_rules() -> 'stages') s where (s ->> 'n')::int = p_stage
$f$;

create or replace function public.world_realm_bond_need(p_stage int)
 returns numeric language sql immutable set search_path to 'pg_catalog', 'public' as $f$
  select (s ->> 'need')::numeric from jsonb_array_elements(public.world_realm_bond_rules() -> 'stages') s where (s ->> 'n')::int = p_stage
$f$;

create or replace function public.world_realm_bond_here(p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare rg text; rl text; r jsonb := public.world_realm_bond_rules();
begin
  select (public.world_region_at(c.location)).region_id into rg from public.world_characters c where c.owner_id = p_uid;
  rl := r -> 'regions' ->> rg;
  if rl is null then return jsonb_build_object('region', rg); end if;
  return jsonb_build_object('region', rg, 'realm', rl, 'hub', r -> 'realms' -> rl -> 'hubs' ? rg);
end $f$;

create or replace function public.world_realm_bond_row(p_uid uuid, p_realm text)
 returns public.world_realm_bonds language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select * from public.world_realm_bonds where owner_id = p_uid and realm = p_realm
$f$;

create or replace function public.world_realm_bond_stage_of(p_uid uuid, p_realm text)
 returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select coalesce((select stage from public.world_realm_bonds where owner_id = p_uid and realm = p_realm), 0)
$f$;

create or replace function public.world_realm_bond_pts_of(p_uid uuid, p_realm text)
 returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select coalesce((select pts from public.world_realm_bonds where owner_id = p_uid and realm = p_realm), -1)
$f$;

create or replace function public.world_realm_bond_room(p_uid uuid, p_realm text)
 returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare d jsonb := public.world_realm_bond_rules() -> 'day'; dy date := public.world_realm_bond_day(); mine numeric; tot numeric;
begin
  select coalesce(sum(day_pts) filter (where realm = p_realm), 0), coalesce(sum(day_pts), 0) into mine, tot
    from public.world_realm_bonds where owner_id = p_uid and day = dy;
  return greatest(0, least((d ->> 'realm')::numeric - mine, (d ->> 'all')::numeric - tot));
end $f$;

create or replace function public.world_realm_bond_open(p_uid uuid, p_realm text)
 returns boolean language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare nm text := public.world_realm_bond_rules() -> 'realms' -> p_realm ->> 'name';
begin
  if p_uid is null or nm is null then return false; end if;
  insert into public.world_realm_bonds(owner_id, realm) values (p_uid, p_realm) on conflict do nothing;
  if not found then return false; end if;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_uid, 'realm_bond', '권역 인연 · ' || nm, public.world_josa(nm, '과', '와') || ' 인연을 맺기 시작했습니다. 그 권역에서 활동하면 인연도가 쌓이고, 캐릭터 › 권역 인연에서 볼 수 있습니다.',
    jsonb_build_object('realm', p_realm, 'open', true));
  return true;
end $f$;

create or replace function public.world_realm_bond_sync(p_uid uuid, p_realm text)
 returns int language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare b public.world_realm_bonds%rowtype; s jsonb; tgt int; nm text;
begin
  select * into b from public.world_realm_bonds where owner_id = p_uid and realm = p_realm for update;
  if not found then return 0; end if;
  tgt := b.stage;
  for s in select x from jsonb_array_elements(public.world_realm_bond_rules() -> 'stages') x order by (x ->> 'n')::int loop
    if (s ->> 'n')::int > tgt and b.pts >= (s ->> 'need')::numeric and b.story >= (s ->> 'n')::int then tgt := (s ->> 'n')::int; end if;
  end loop;
  if tgt <= b.stage then return b.stage; end if;
  update public.world_realm_bonds set stage = tgt where owner_id = p_uid and realm = p_realm;
  nm := public.world_realm_bond_rules() -> 'realms' -> p_realm ->> 'name';
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_uid, 'realm_bond', '권역 인연 · ' || nm, nm || ' 권역 인연이 ' || tgt || '단계 「' || public.world_realm_bond_stage_name(tgt) || '」에 올랐습니다. '
      || coalesce(public.world_realm_bond_rules() -> 'perk_text' ->> tgt::text, '') || case when public.world_realm_bond_rules() -> 'perk_text' ? tgt::text then '.' else '' end,
    jsonb_build_object('realm', p_realm, 'stage', tgt));
  perform public.world_title_award_check(p_uid, 'realm_bond');
  return tgt;
end $f$;

create or replace function public.world_realm_bond_add(p_uid uuid, p_realm text, p_amt numeric, p_src text)
 returns numeric language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare d jsonb := public.world_realm_bond_rules() -> 'day'; dy date := public.world_realm_bond_day(); b public.world_realm_bonds%rowtype; other numeric; g numeric; cur numeric;
begin
  if p_uid is null or p_realm is null or coalesce(p_amt, 0) <= 0 then return 0; end if;
  perform pg_advisory_xact_lock(hashtextextended('realm_bond:' || p_uid::text, 0));
  select * into b from public.world_realm_bonds where owner_id = p_uid and realm = p_realm for update;
  if not found then return 0; end if;
  cur := case when b.day = dy then b.day_pts else 0 end;
  select coalesce(sum(day_pts), 0) into other from public.world_realm_bonds where owner_id = p_uid and realm <> p_realm and day = dy;
  g := round(greatest(0, least(p_amt, (d ->> 'realm')::numeric - cur, (d ->> 'all')::numeric - other - cur)), 2);
  if g <= 0 then return 0; end if;
  update public.world_realm_bonds set pts = pts + g, tokens = tokens + g, day = dy, day_pts = cur + g where owner_id = p_uid and realm = p_realm;
  if b.story > b.stage then perform public.world_realm_bond_sync(p_uid, p_realm); end if;
  return g;
end $f$;

create or replace function public.world_realm_bond_on_event()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare r jsonb := public.world_realm_bond_rules(); g jsonb := r -> 'gain'; rg text; rl text; amt numeric := 0; mins numeric;
begin
  if new.actor_id is null then return null; end if;
  if new.event_type in ('travel', 'rescue') then
    rg := coalesce(new.payload ->> 'region_id', new.payload ->> 'to');
    rl := r -> 'regions' ->> rg;
    if rl is not null and r -> 'realms' -> rl -> 'hubs' ? rg then perform public.world_realm_bond_open(new.actor_id, rl); end if;
    return null;
  end if;
  if not exists (select 1 from public.world_realm_bonds b where b.owner_id = new.actor_id) then return null; end if;
  if new.event_type = 'combat' then
    if not coalesce((new.payload ->> 'defeated')::boolean, false) then return null; end if;
    rg := new.payload ->> 'region_id'; amt := (g ->> 'win')::numeric;
  elsif new.event_type = 'explore' then
    if new.payload ->> 'kind' is distinct from 'field_search' then return null; end if;
    rg := new.payload ->> 'region_id'; amt := (g ->> 'explore')::numeric;
  elsif new.event_type = 'gather' then
    rg := coalesce(new.payload ->> 'region_id', (select n.region_id from public.world_exploration_nodes n
      where n.node_id = case when new.payload ->> 'node_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then (new.payload ->> 'node_id')::uuid end));
    amt := (g ->> 'gather')::numeric;
  elsif new.event_type = 'expedition_end' then
    rg := new.payload ->> 'region_id';
    if r -> 'regions' ->> rg is null then return null; end if;
    select least(x.minutes, extract(epoch from coalesce(x.finished_at, now()) - x.started_at) / 60) into mins
      from public.world_expeditions x where x.owner_id = new.actor_id order by x.started_at desc limit 1;
    amt := least((g ->> 'exp_max')::numeric, coalesce(mins, 0) / (g ->> 'exp_min')::numeric);
  else
    return null;
  end if;
  rl := r -> 'regions' ->> rg;
  if rl is null then return null; end if;
  perform public.world_realm_bond_add(new.actor_id, rl, amt, new.event_type);
  return null;
end $f$;

create or replace function public.world_realm_bond_quest_trg()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare q jsonb := public.world_realm_bond_rules() -> 'quests' -> new.quest_id;
begin
  if q is null or new.done_at is null or (tg_op = 'UPDATE' and old.done_at is not null) then return null; end if;
  update public.world_realm_bonds set story = greatest(story, (q ->> 1)::int) where owner_id = new.owner_id and realm = q ->> 0;
  if found then perform public.world_realm_bond_sync(new.owner_id, q ->> 0); end if;
  return null;
end $f$;

create or replace function public.world_realm_bond_trade(p_uid uuid, p_port text, p_base numeric)
 returns numeric language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  if coalesce(p_base, 0) <= 0 then return 0; end if;
  return public.world_realm_bond_add(p_uid, public.world_realm_bond_realm(p_port), p_base / (public.world_realm_bond_rules() -> 'gain' ->> 'trade_gil')::numeric, 'trade');
end $f$;

create or replace function public.world_realm_bond_fx(p_uid uuid, p_key text, p_loc text default null)
 returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare r jsonb := public.world_realm_bond_rules(); loc text := p_loc; rg text; rl text; st int; v numeric := 0; k text;
begin
  if p_uid is null or p_key not in ('shop_pct', 'gather_qty_pct', 'healing_pct', 'rescue_half') then return 0; end if;
  if loc is null then select c.location into loc from public.world_characters c where c.owner_id = p_uid; end if;
  rg := (public.world_region_at(loc)).region_id;
  rl := r -> 'regions' ->> rg;
  if rl is null then return 0; end if;
  if r -> 'safe_only' ? p_key and not (r -> 'realms' -> rl -> 'hubs' ? rg) then return 0; end if;
  select b.stage into st from public.world_realm_bonds b where b.owner_id = p_uid and b.realm = rl;
  if st is null then return 0; end if;
  for k in select jsonb_object_keys(r -> 'perks') loop
    if k::int <= st and r -> 'perks' -> k ? p_key then v := v + (r -> 'perks' -> k ->> p_key)::numeric; end if;
  end loop;
  return v;
end $f$;

create or replace function public.world_realm_bond_price(p_uid uuid, p_price bigint)
 returns bigint language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select case when p_price is null then null else greatest(1, round(p_price * (100 + public.world_realm_bond_fx(p_uid, 'shop_pct')) / 100.0))::bigint end
$f$;

create or replace function public.world_realm_bond_route(p_uid uuid, p_from text, p_to text)
 returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare r jsonb := public.world_realm_bond_rules(); a text := r -> 'regions' ->> p_from; st int; v numeric := 0; k text;
begin
  if a is null or a is distinct from r -> 'regions' ->> p_to then return 0; end if;
  st := public.world_realm_bond_stage_of(p_uid, a);
  for k in select jsonb_object_keys(r -> 'perks') loop
    if k::int <= st and r -> 'perks' -> k ? 'travel_pct' then v := v + (r -> 'perks' -> k ->> 'travel_pct')::numeric; end if;
  end loop;
  return v;
end $f$;

create or replace function public.world_realm_bond_requests(p_realm text, p_day date)
 returns jsonb language sql stable set search_path to 'pg_catalog', 'public' as $f$
  select coalesce(jsonb_agg(case when q ? 'pick' then (q || jsonb_build_object('give', jsonb_build_object(
      q -> 'pick' ->> (('x' || substr(md5(p_realm || p_day::text || 'give'), 1, 7))::bit(28)::int % jsonb_array_length(q -> 'pick')), (q ->> 'give_n')::int))) - 'pick' - 'give_n'
    else q end order by md5(q ->> 'key' || p_realm || p_day::text)), '[]'::jsonb)
  from (select q from jsonb_array_elements(public.world_realm_bond_rules() -> 'requests' -> 'list' -> p_realm) q
        order by md5(q ->> 'key' || p_realm || p_day::text)
        limit (public.world_realm_bond_rules() -> 'requests' ->> 'n')::int) z
$f$;

create or replace function public.world_realm_bond_task_count(p_uid uuid, p_task jsonb, p_since timestamptz)
 returns int language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  if p_task ->> 't' = 'tradesale' then
    return coalesce((select sum((s ->> 'qty')::int * (public.world_trade_good(s ->> 'good') ->> 'base')::int)
      from public.world_economy_ledger l, jsonb_array_elements(l.details -> 'sold') s
     where l.owner_id = p_uid and l.action = 'trade_goods_sale' and l.created_at >= p_since
       and l.details ->> 'port' in (select jsonb_array_elements_text(p_task -> 'r'))), 0)::int;
  end if;
  return public.world_faction_task_count(p_uid, p_task, p_since);
end $f$;

create or replace function public.world_realm_bond_task_label(p_task jsonb)
 returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select case when p_task ->> 't' = 'tradesale' then
      coalesce((select string_agg(m.region_name, '·') || '에서 ' from public.world_map_regions m where m.region_id in (select jsonb_array_elements_text(p_task -> 'r'))), '')
      || '교역품 팔기(정가 합)'
    else public.world_faction_task_label(p_task) end
$f$;

create or replace function public.world_realm_bond_board_of(p_uid uuid, p_realm text)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare dy date := public.world_realm_bond_day(); d0 timestamptz := public.world_realm_bond_day0(); q jsonb; t jsonb; tasks jsonb[]; give jsonb[]; out jsonb[] := '{}';
  inv jsonb; e record; done boolean; n int;
begin
  select coalesce(c.inventory, '{}'::jsonb) into inv from public.world_characters c where c.owner_id = p_uid;
  for q in select x from jsonb_array_elements(public.world_realm_bond_requests(p_realm, dy)) x loop
    tasks := '{}'; give := '{}'; done := true;
    for t in select x from jsonb_array_elements(coalesce(q -> 'tasks', '[]'::jsonb)) x loop
      n := public.world_realm_bond_task_count(p_uid, t, d0);
      tasks := tasks || jsonb_build_object('label', public.world_realm_bond_task_label(t), 'have', least(n, (t ->> 'n')::int), 'n', (t ->> 'n')::int,
        'unit', case when t ->> 't' = 'tradesale' then '전' when t ->> 't' in ('win', 'gather') then '번' else '회' end);
      if n < (t ->> 'n')::int then done := false; end if;
    end loop;
    for e in select key, value from jsonb_each(coalesce(q -> 'give', '{}'::jsonb)) loop
      n := public.world_give_check(p_uid, e.key, inv);
      give := give || jsonb_build_object('item_id', e.key, 'name', (select item_name from public.world_item_catalog where item_id = e.key), 'n', (e.value)::text::int, 'have', n);
      if n < (e.value)::text::int then done := false; end if;
    end loop;
    out := out || jsonb_build_object('key', q ->> 'key', 'title', q ->> 'title', 'tasks', to_jsonb(tasks), 'give', to_jsonb(give), 'ready', done,
      'claimed', exists (select 1 from public.world_realm_bond_claims c where c.owner_id = p_uid and c.day = dy and c.realm = p_realm and c.req_key = q ->> 'key'),
      'reward', (public.world_realm_bond_rules() -> 'gain' ->> 'request')::numeric);
  end loop;
  return to_jsonb(out);
end $f$;

create or replace function public.world_realm_bond_vault_ready(p_v jsonb)
 returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select coalesce((p_v ->> 'ready')::boolean, true) and case p_v ->> 'kind'
    when 'item' then exists (select 1 from public.world_item_catalog i where i.item_id = p_v ->> 'id')
    when 'title' then exists (select 1 from public.world_title_catalog t where t.title_key = p_v ->> 'id')
    when 'cosmetic' then exists (select 1 from public.world_cosmetic_catalog c where c.cosmetic_key = p_v ->> 'id')
    when 'mount' then exists (select 1 from public.world_mount_catalog m where m.mount_id = p_v ->> 'id')
    when 'name_style' then true
    else false end
$f$;

create or replace function public.world_realm_bond_vault_owned(p_uid uuid, p_v jsonb)
 returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select case p_v ->> 'kind'
    when 'title' then exists (select 1 from public.world_character_titles where owner_id = p_uid and title_key = p_v ->> 'id')
    when 'cosmetic' then exists (select 1 from public.world_character_cosmetics where owner_id = p_uid and cosmetic_key = p_v ->> 'id')
    when 'name_style' then exists (select 1 from public.world_faction_unlocks where owner_id = p_uid and unlock_key = p_v ->> 'id')
    when 'mount' then exists (select 1 from public.world_owned_mounts where owner_id = p_uid and mount_id = p_v ->> 'id')
    else false end
$f$;

create or replace function public.world_realm_bond_vault_of(p_uid uuid, p_realm text)
 returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select coalesce(jsonb_agg(jsonb_build_object('id', v ->> 'id', 'kind', v ->> 'kind', 'stage', (v ->> 'stage')::int, 'price', (v ->> 'price')::int,
      'name', coalesce(case v ->> 'kind' when 'item' then (select item_name from public.world_item_catalog where item_id = v ->> 'id')
                                         when 'title' then (select title_name from public.world_title_catalog where title_key = v ->> 'id')
                                         when 'cosmetic' then (select cosmetic_name from public.world_cosmetic_catalog where cosmetic_key = v ->> 'id')
                                         when 'mount' then (select mount_name from public.world_mount_catalog where mount_id = v ->> 'id') end, v ->> 'name'),
      'owned', public.world_realm_bond_vault_owned(p_uid, v),
      'open', public.world_realm_bond_stage_of(p_uid, p_realm) >= (v ->> 'stage')::int) order by (v ->> 'sort')::int), '[]'::jsonb)
  from jsonb_array_elements(public.world_realm_bond_rules() -> 'vault') v
  where v ->> 'realm' = p_realm and public.world_realm_bond_vault_ready(v)
$f$;

create or replace function public.world_realm_bond_card(p_uid uuid, p_realm text)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare r jsonb := public.world_realm_bond_rules(); b public.world_realm_bonds%rowtype; dy date := public.world_realm_bond_day(); nx int; tot numeric; qid text; k text; perks jsonb[] := '{}';
begin
  select * into b from public.world_realm_bonds where owner_id = p_uid and realm = p_realm;
  if not found then
    return jsonb_build_object('realm', p_realm, 'name', r -> 'realms' -> p_realm ->> 'name', 'opened', false);
  end if;
  select coalesce(sum(day_pts), 0) into tot from public.world_realm_bonds where owner_id = p_uid and day = dy;
  nx := case when b.stage < 5 then b.stage + 1 end;
  qid := case when nx is not null then 'rb_' || p_realm || '_' || nx end;
  for k in select jsonb_object_keys(r -> 'perk_text') loop
    perks := perks || jsonb_build_object('stage', k::int, 'text', r -> 'perk_text' ->> k, 'on', b.stage >= k::int);
  end loop;
  return jsonb_build_object('realm', p_realm, 'name', r -> 'realms' -> p_realm ->> 'name', 'opened', true, 'opened_at', b.opened_at,
    'stage', b.stage, 'stage_name', public.world_realm_bond_stage_name(b.stage), 'pts', b.pts, 'tokens', floor(b.tokens)::int,
    'today', case when b.day = dy then b.day_pts else 0 end, 'today_cap', (r -> 'day' ->> 'realm')::numeric, 'all_today', tot, 'all_cap', (r -> 'day' ->> 'all')::numeric,
    'next', case when nx is null then null else jsonb_build_object('stage', nx, 'name', public.world_realm_bond_stage_name(nx), 'need', public.world_realm_bond_need(nx),
      'quest', qid, 'quest_title', (select q.title from public.world_quests q where q.quest_id = qid and q.active),
      'quest_done', b.story >= nx) end,
    'perks', (select to_jsonb(array_agg(p order by (p ->> 'stage')::int)) from unnest(perks) p));
end $f$;

create or replace function public.world_realm_bond_rule_count(p_owner uuid, p_rule jsonb)
 returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select case p_rule ->> 'realm_bond'
    when 'stage' then coalesce((select stage from public.world_realm_bonds where owner_id = p_owner and realm = p_rule ->> 'realm'), 0)
    when 'realms' then (select count(*) from public.world_realm_bonds where owner_id = p_owner and stage >= coalesce((p_rule ->> 'stage')::int, 1))
    else 0 end::numeric
$f$;

create or replace function public.world_realm_bond_pick(p_uid uuid, p_realm text, p_need_hub boolean, p_what text)
 returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare h jsonb := public.world_realm_bond_here(p_uid); rl text := coalesce(nullif(p_realm, ''), h ->> 'realm');
begin
  if rl is null or not (public.world_realm_bond_rules() -> 'realms' ? rl) then raise exception '권역을 고르세요(건넛누리 권역 안에 있으면 그곳이 골라집니다).' using hint = 'no_realm'; end if;
  if p_need_hub and (h ->> 'realm' is distinct from rl or not coalesce((h ->> 'hub')::boolean, false)) then
    raise exception '%은(는) % 안전지대에서만 할 수 있습니다.', p_what, public.world_realm_bond_rules() -> 'realms' -> rl ->> 'name' using hint = 'not_here';
  end if;
  if not exists (select 1 from public.world_realm_bonds where owner_id = p_uid and realm = rl) then
    raise exception '아직 % 권역과 인연을 맺지 않았습니다. 그 권역 안전지대에 먼저 닿으세요.', public.world_realm_bond_rules() -> 'realms' -> rl ->> 'name' using hint = 'not_open';
  end if;
  return rl;
end $f$;

create or replace function public.world_realm_bond_list()
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_realm_bond_rules(); k text; out jsonb[] := '{}';
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  for k in select jsonb_array_elements_text(r -> 'order') loop
    out := out || public.world_realm_bond_card(uid, k);
  end loop;
  return jsonb_build_object('realms', to_jsonb(out), 'here', public.world_realm_bond_here(uid));
end $f$;

create or replace function public.world_realm_bond_view(p_realm text default null)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_realm_bond_rules(); h jsonb; rl text; card jsonb; sp jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  h := public.world_realm_bond_here(uid);
  rl := coalesce(nullif(p_realm, ''), h ->> 'realm');
  if rl is null or not (r -> 'realms' ? rl) then return jsonb_build_object('realm', null, 'here', h); end if;
  card := public.world_realm_bond_card(uid, rl);
  if not (card ->> 'opened')::boolean then return card || jsonb_build_object('here', h); end if;
  select coalesce(jsonb_agg(jsonb_build_object('item_id', i.item_id, 'name', i.item_name, 'price', i.reference_price,
      'have', public.world_give_check(uid, i.item_id, (select coalesce(c.inventory, '{}'::jsonb) from public.world_characters c where c.owner_id = uid))) order by o), '[]'::jsonb)
    into sp from jsonb_array_elements_text(r -> 'realms' -> rl -> 'specials') with ordinality z(it, o) join public.world_item_catalog i on i.item_id = z.it;
  return card || jsonb_build_object('here', h, 'at_hub', h ->> 'realm' = rl and coalesce((h ->> 'hub')::boolean, false),
    'board', public.world_realm_bond_board_of(uid, rl), 'vault', public.world_realm_bond_vault_of(uid, rl), 'specials', sp,
    'room', public.world_realm_bond_room(uid, rl), 'donate_gil', (r -> 'gain' ->> 'donate_gil')::int,
    'story', (select coalesce(jsonb_agg(jsonb_build_object('quest', q.quest_id, 'title', q.title, 'stage', (r -> 'quests' -> q.quest_id ->> 1)::int,
        'done', exists (select 1 from public.world_quest_progress p where p.owner_id = uid and p.quest_id = q.quest_id and p.done_at is not null)) order by q.quest_id), '[]'::jsonb)
      from public.world_quests q where q.active and r -> 'quests' -> q.quest_id ->> 0 = rl));
end $f$;

create or replace function public.world_realm_bond_board(p_realm text default null)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); rl text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  rl := public.world_realm_bond_pick(uid, p_realm, false, '의뢰판 보기');
  return jsonb_build_object('realm', rl, 'board', public.world_realm_bond_board_of(uid, rl), 'room', public.world_realm_bond_room(uid, rl));
end $f$;

create or replace function public.world_realm_bond_claim(p_req text, p_realm text default null)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rl text; q jsonb; t jsonb; e record; inv jsonb; g numeric;
  dy date := public.world_realm_bond_day(); d0 timestamptz := public.world_realm_bond_day0(); nm text;
begin
  perform public.world_travel_guard('권역 의뢰 보고');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 의뢰를 보고할 수 없습니다.'; end if;
  rl := public.world_realm_bond_pick(uid, p_realm, true, '권역 의뢰 보고');
  q := (select x from jsonb_array_elements(public.world_realm_bond_requests(rl, dy)) x where x ->> 'key' = p_req);
  if q is null then raise exception '오늘의 의뢰가 아닙니다.' using hint = 'not_today'; end if;
  if public.world_realm_bond_room(uid, rl) <= 0 then raise exception '오늘 이 권역에서 쌓을 수 있는 인연도가 찼습니다. 한국 시각 0시에 다시 찹니다.' using hint = 'day_cap'; end if;
  for t in select x from jsonb_array_elements(coalesce(q -> 'tasks', '[]'::jsonb)) x loop
    if public.world_realm_bond_task_count(uid, t, d0) < (t ->> 'n')::int then raise exception '아직 의뢰를 마치지 않았습니다.' using hint = 'not_done'; end if;
  end loop;
  insert into public.world_realm_bond_claims(owner_id, day, realm, req_key) values (uid, dy, rl, p_req) on conflict do nothing;
  if not found then raise exception '이미 받은 의뢰입니다.' using hint = 'claimed'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  for e in select key, value from jsonb_each(coalesce(q -> 'give', '{}'::jsonb)) loop
    if public.world_give_check(uid, e.key, inv) < (e.value)::text::int then
      select item_name into nm from public.world_item_catalog where item_id = e.key;
      raise exception '「%」이(가) % 개 있어야 합니다(잠금·장착 중인 것은 빼고 셈).', coalesce(nm, e.key), (e.value)::text::int using hint = 'give';
    end if;
    inv := case when (inv ->> e.key)::int - (e.value)::text::int <= 0 then inv - e.key else jsonb_set(inv, array[e.key], to_jsonb((inv ->> e.key)::int - (e.value)::text::int)) end;
  end loop;
  if q -> 'give' is not null and q -> 'give' <> '{}'::jsonb then
    perform set_config('yh.wear_leaves', 'on', true);
    update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  end if;
  g := public.world_realm_bond_add(uid, rl, (public.world_realm_bond_rules() -> 'gain' ->> 'request')::numeric, 'request');
  return jsonb_build_object('ok', true, 'gain', g, 'card', public.world_realm_bond_card(uid, rl),
    'content', '의뢰 「' || (q ->> 'title') || '」을(를) 마쳤습니다. 인연도 +' || trim(to_char(g, 'FM999990.##')) || ' · 인연 표 +' || trim(to_char(g, 'FM999990.##')));
end $f$;

create or replace function public.world_realm_bond_donate(p_items jsonb)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rl text; r jsonb := public.world_realm_bond_rules(); e record; inv jsonb; have int;
  price int; val int := 0; top int := 0; n int := 0; kinds int := 0; amt numeric; room numeric; g numeric; rate numeric; nm text;
begin
  perform public.world_travel_guard('권역 기부');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_items is null or jsonb_typeof(p_items) <> 'object' or p_items = '{}'::jsonb then raise exception '넘길 물품을 고르세요.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 기부할 수 없습니다.'; end if;
  rl := public.world_realm_bond_pick(uid, null, true, '권역 기부');
  rate := (r -> 'gain' ->> 'donate_gil')::numeric;
  room := public.world_realm_bond_room(uid, rl);
  if room <= 0 then raise exception '오늘 이 권역에서 쌓을 수 있는 인연도가 찼습니다. 한국 시각 0시에 다시 찹니다.' using hint = 'day_cap'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  for e in select key, value from jsonb_each(p_items) order by key loop
    if jsonb_typeof(e.value) <> 'number' or (e.value)::text::numeric <> floor((e.value)::text::numeric) or (e.value)::text::int < 1 then raise exception '수량이 올바르지 않습니다.'; end if;
    select item_name, reference_price into nm, price from public.world_item_catalog where item_id = e.key;
    if not (r -> 'realms' -> rl -> 'specials' ? e.key) then
      raise exception '「%」은(는) 이 권역 특산 재료가 아닙니다.', coalesce(nm, e.key) using hint = 'not_special';
    end if;
    have := public.world_give_check(uid, e.key, inv);
    if (e.value)::text::int > have then raise exception '「%」을(를) % 개까지 넘길 수 있습니다.', nm, have using hint = 'give'; end if;
    val := val + price * (e.value)::text::int;
    top := greatest(top, price);
    n := n + (e.value)::text::int; kinds := kinds + 1;
    inv := case when (inv ->> e.key)::int - (e.value)::text::int <= 0 then inv - e.key else jsonb_set(inv, array[e.key], to_jsonb((inv ->> e.key)::int - (e.value)::text::int)) end;
  end loop;
  amt := val / rate;
  if amt - top / rate >= room then
    raise exception '오늘 이 권역에 더 쌓을 수 있는 인연도는 %(시세 약 %전어치)입니다. 수량을 줄이세요.', trim(to_char(room, 'FM999990.##')), ceil(room * rate)::int using hint = 'too_much';
  end if;
  perform set_config('yh.wear_leaves', 'on', true);
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  g := public.world_realm_bond_add(uid, rl, amt, 'donate');
  return jsonb_build_object('ok', true, 'gain', g, 'value', val, 'card', public.world_realm_bond_card(uid, rl),
    'content', kinds || '가지 ' || n || '개를 기부했습니다(시세 ' || val || '전). 인연도 +' || trim(to_char(g, 'FM999990.##'))
      || case when g < amt then ' · 오늘 쌓을 수 있는 몫에 닿았습니다.' else '' end);
end $f$;

create or replace function public.world_realm_bond_vault(p_realm text default null)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); rl text; h jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  rl := public.world_realm_bond_pick(uid, p_realm, false, '비고 보기');
  h := public.world_realm_bond_here(uid);
  return jsonb_build_object('realm', rl, 'tokens', floor((public.world_realm_bond_row(uid, rl)).tokens)::int, 'stage', public.world_realm_bond_stage_of(uid, rl),
    'at_hub', h ->> 'realm' = rl and coalesce((h ->> 'hub')::boolean, false), 'items', public.world_realm_bond_vault_of(uid, rl));
end $f$;

create or replace function public.world_realm_bond_buy(p_key text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; v jsonb; rl text; b public.world_realm_bonds%rowtype; cost int; nm text;
begin
  perform public.world_travel_guard('권역 비고 교환');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 받을 수 없습니다.'; end if;
  v := (select x from jsonb_array_elements(public.world_realm_bond_rules() -> 'vault') x where x ->> 'id' = p_key limit 1);
  if v is null or not public.world_realm_bond_vault_ready(v) then raise exception '비고에 없는 물품입니다.' using hint = 'none'; end if;
  rl := public.world_realm_bond_pick(uid, v ->> 'realm', true, '권역 비고 교환');
  perform pg_advisory_xact_lock(hashtextextended('realm_bond:' || uid::text, 0));
  select * into b from public.world_realm_bonds where owner_id = uid and realm = rl for update;
  if b.stage < (v ->> 'stage')::int then raise exception '권역 인연 %단계(「%」)부터 받을 수 있습니다.', v ->> 'stage', public.world_realm_bond_stage_name((v ->> 'stage')::int) using hint = 'stage'; end if;
  if public.world_realm_bond_vault_owned(uid, v) then raise exception '이미 가지고 있습니다.' using hint = 'owned'; end if;
  cost := (v ->> 'price')::int;
  if b.tokens < cost then raise exception '인연 표가 모자랍니다(% 필요, 지금 %).', cost, floor(b.tokens)::int using hint = 'tokens'; end if;
  if v ->> 'kind' = 'item' and public.world_bag_room(coalesce(c.inventory, '{}'::jsonb), p_key, public.world_bag_limit(uid)) < 1 then raise exception '가방 자리가 모자랍니다.' using hint = 'bag'; end if;
  update public.world_realm_bonds set tokens = tokens - cost where owner_id = uid and realm = rl;
  nm := (select x ->> 'name' from jsonb_array_elements(public.world_realm_bond_vault_of(uid, rl)) x where x ->> 'id' = p_key);
  case v ->> 'kind'
    when 'item' then update public.world_characters set inventory = public.world_inv_add(coalesce(inventory, '{}'::jsonb), p_key, 1), updated_at = now() where owner_id = uid;
    when 'title' then insert into public.world_character_titles(owner_id, title_key) values (uid, p_key) on conflict do nothing;
    when 'cosmetic' then insert into public.world_character_cosmetics(owner_id, cosmetic_key) values (uid, p_key) on conflict do nothing;
    when 'name_style' then insert into public.world_faction_unlocks(owner_id, unlock_key) values (uid, p_key) on conflict do nothing;
    when 'mount' then insert into public.world_owned_mounts(owner_id, mount_id) values (uid, p_key) on conflict do nothing;
  end case;
  return jsonb_build_object('ok', true, 'kind', v ->> 'kind', 'tokens', floor(b.tokens - cost)::int,
    'content', coalesce(nm, p_key) || '을(를) 받았습니다(인연 표 ' || cost || ').' ||
      case v ->> 'kind' when 'title' then ' 캐릭터 › 칭호에서 장착하세요.' when 'cosmetic' then ' 설정 › 프로필 꾸미기에서 답니다.' when 'name_style' then ' 설정 › 프로필 › 채팅 이름 색에서 고릅니다.'
        when 'mount' then ' 지도 › 이동의 내 탈것에서 탑니다.' else '' end);
end $f$;

grant create on schema public to fn_owner_field;
do $$ declare f text; begin
  foreach f in array array[
    'world_realm_bond_here(uuid)', 'world_realm_bond_row(uuid, text)', 'world_realm_bond_stage_of(uuid, text)', 'world_realm_bond_pts_of(uuid, text)', 'world_realm_bond_room(uuid, text)',
    'world_realm_bond_open(uuid, text)', 'world_realm_bond_sync(uuid, text)', 'world_realm_bond_add(uuid, text, numeric, text)', 'world_realm_bond_on_event()', 'world_realm_bond_quest_trg()',
    'world_realm_bond_trade(uuid, text, numeric)', 'world_realm_bond_fx(uuid, text, text)', 'world_realm_bond_price(uuid, bigint)', 'world_realm_bond_route(uuid, text, text)',
    'world_realm_bond_task_count(uuid, jsonb, timestamptz)', 'world_realm_bond_task_label(jsonb)', 'world_realm_bond_board_of(uuid, text)', 'world_realm_bond_vault_ready(jsonb)',
    'world_realm_bond_vault_owned(uuid, jsonb)', 'world_realm_bond_vault_of(uuid, text)', 'world_realm_bond_card(uuid, text)', 'world_realm_bond_rule_count(uuid, jsonb)',
    'world_realm_bond_pick(uuid, text, boolean, text)', 'world_realm_bond_list()', 'world_realm_bond_view(text)', 'world_realm_bond_board(text)', 'world_realm_bond_claim(text, text)',
    'world_realm_bond_donate(jsonb)', 'world_realm_bond_vault(text)', 'world_realm_bond_buy(text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
  end loop;
end $$;
revoke create on schema public from fn_owner_field;

do $$ declare f text; begin
  foreach f in array array['world_realm_bond_day()', 'world_realm_bond_day0()', 'world_realm_bond_realm(text)', 'world_realm_bond_stage_name(integer)', 'world_realm_bond_need(integer)',
    'world_realm_bond_requests(text, date)',
    'world_realm_bond_here(uuid)', 'world_realm_bond_row(uuid, text)', 'world_realm_bond_stage_of(uuid, text)', 'world_realm_bond_pts_of(uuid, text)', 'world_realm_bond_room(uuid, text)',
    'world_realm_bond_open(uuid, text)', 'world_realm_bond_sync(uuid, text)', 'world_realm_bond_add(uuid, text, numeric, text)', 'world_realm_bond_on_event()', 'world_realm_bond_quest_trg()',
    'world_realm_bond_trade(uuid, text, numeric)', 'world_realm_bond_fx(uuid, text, text)', 'world_realm_bond_price(uuid, bigint)', 'world_realm_bond_route(uuid, text, text)',
    'world_realm_bond_task_count(uuid, jsonb, timestamptz)', 'world_realm_bond_task_label(jsonb)', 'world_realm_bond_board_of(uuid, text)', 'world_realm_bond_vault_ready(jsonb)',
    'world_realm_bond_vault_owned(uuid, jsonb)', 'world_realm_bond_vault_of(uuid, text)', 'world_realm_bond_card(uuid, text)', 'world_realm_bond_rule_count(uuid, jsonb)',
    'world_realm_bond_pick(uuid, text, boolean, text)'] loop
    perform pg_temp.yh_rb_share('public.' || f);
  end loop;
  foreach f in array array['world_realm_bond_list()', 'world_realm_bond_view(text)', 'world_realm_bond_board(text)', 'world_realm_bond_claim(text, text)',
    'world_realm_bond_donate(jsonb)', 'world_realm_bond_vault(text)', 'world_realm_bond_buy(text)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $$;

drop trigger if exists trg_world_realm_bond_event on public.world_events;
create trigger trg_world_realm_bond_event after insert on public.world_events for each row
  when (new.event_type = any (array['combat', 'explore', 'gather', 'expedition_end', 'travel', 'rescue'])) execute function public.world_realm_bond_on_event();
drop trigger if exists trg_world_realm_bond_quest on public.world_quest_progress;
create trigger trg_world_realm_bond_quest after insert or update of done_at on public.world_quest_progress for each row
  when (new.done_at is not null and new.quest_id like 'rb\_%') execute function public.world_realm_bond_quest_trg();
