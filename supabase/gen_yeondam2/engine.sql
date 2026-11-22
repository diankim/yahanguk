create or replace function public.world_regular_line(p_uid uuid, p_npc text)
 returns text language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare l text := public.world_regular_rule(p_npc) ->> 'line';
begin
  if l = 'job' then return (select public.world_job_line(c.job_key) from public.world_characters c where c.owner_id = p_uid); end if;
  return l;
end $f$;

create or replace function public.world_regular_line_name(p_uid uuid, p_npc text)
 returns text language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
begin
  return public.world_line_name(public.world_regular_line(p_uid, p_npc));
end $f$;

create or replace function public.world_regular_here_list(p_uid uuid)
 returns text[] language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare rid text;
begin
  select (public.world_region_at(c.location)).region_id into rid from public.world_characters c where c.owner_id = p_uid;
  return coalesce((select array_agg(e.key order by (e.value ->> 'sort')::int) from jsonb_each(public.world_regular_rules() -> 'npcs') e where e.value ->> 'region' = rid), '{}');
end $f$;

create or replace function public.world_regular_here(p_uid uuid)
 returns text language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare l text[] := public.world_regular_here_list(p_uid); k text;
begin
  foreach k in array l loop
    if public.world_regular_open(p_uid, k) then return k; end if;
  end loop;
  return l[1];
end $f$;

create or replace function public.world_regular_kinds(p_uid uuid)
 returns text[] language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare lv int := coalesce((select c.level from public.world_characters c where c.owner_id = p_uid), 1);
begin
  return coalesce((select array_agg(distinct m.region_id || '|' || m.kind order by m.region_id || '|' || m.kind)
    from public.world_region_monsters m join public.world_monster_kinds k on k.kind_key = m.kind
   where m.role <> 'guardian' and coalesce(m.spawn_weight, 1) > 0 and m.region_id in (select g.region_id from public.world_map_regions g
                          where g.active and not g.is_safe_zone and g.min_level <= lv and public.world_region_open(p_uid, g.region_id))), '{}');
end $f$;

create or replace function public.world_regular_cpool(p_uid uuid, p_npc text, p_rank int, p_ammo boolean default true)
 returns text[] language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_regular_rules(); c jsonb := r -> 'combat'; base text := public.world_regular_rule(p_npc) ->> 'line';
  kind text := c -> 'item' -> base ->> 0; span int := (r ->> 'span')::int; hi int := greatest(p_rank, 5); lo int := greatest(1, p_rank - span);
  out text[]; rare text[]; a text;
begin
  if kind is null then return '{}'; end if;
  if kind = 'weapon' and p_ammo then
    a := public.world_ammo_of(p_uid);
    if a is not null then return array[a]; end if;
  end if;
  rare := public.world_regular_rare();
  for pass in 1 .. 2 loop
    if kind = 'loot' then
      select array_agg(distinct x order by x) into out from public.world_region_monsters m, jsonb_object_keys(m.drops) x join public.world_item_catalog i on i.item_id = x
       where m.min_level <= hi and m.min_level >= case when pass = 1 then lo - 3 else 0 end
         and i.tradeable and not coalesce(i.market_only, false) and i.category = 'material' and i.base_item_id is null and not (x = any (rare));
    else
      select array_agg(distinct w.output_item order by w.output_item) into out from public.world_crafting_recipes w join public.world_item_catalog i on i.item_id = w.output_item
       where coalesce(w.minimum_level, 1) <= hi and coalesce(w.minimum_level, 1) >= case when pass = 1 then lo else 0 end
         and i.tradeable and not coalesce(i.market_only, false) and i.base_item_id is null and i.category not in ('furniture', 'outfit', 'pet', 'quest')
         and not (w.output_item = any (rare))
         and case kind when 'armor' then i.category = any (array(select jsonb_array_elements_text(c -> 'armor')))
                       when 'heal' then public.world_craft_line_of(w.craft_field) = 'alchemy' and coalesce((i.use_fx ->> 'hp')::int, 0) > 0
                       else public.world_craft_line_of(w.craft_field) = 'alchemy' and coalesce((i.use_fx ->> 'sp')::int, 0) > 0 end;
    end if;
    exit when coalesce(array_length(out, 1), 0) >= (r ->> 'orders')::int;
  end loop;
  return coalesce(out, '{}');
end $f$;

create or replace function public.world_regular_cgil(p_uid uuid, p_npc text, p_rank int)
 returns int language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_regular_rules();
begin
  return floor(coalesce((select avg(coalesce(i.reference_price, 0)) from public.world_item_catalog i where i.item_id = any (public.world_regular_cpool(p_uid, p_npc, p_rank, false))), 0)
    * (r -> 'combat' ->> 'gil_n')::numeric * (r -> 'gil' ->> 'rate')::numeric + (r -> 'gil' ->> 'base')::numeric)::int;
end $f$;

create or replace function public.world_regular_orders(p_uid uuid, p_npc text, p_day date)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_regular_rules(); n jsonb := public.world_regular_rule(p_npc); line text; rk int; out jsonb; c jsonb := r -> 'combat'; act jsonb; it jsonb; kk text; pick text;
begin
  if n is null then return '[]'::jsonb; end if;
  line := public.world_regular_line(p_uid, p_npc);
  rk := public.world_regular_rank(p_uid, line);
  if n ->> 'kind' = 'combat' then
    act := c -> 'act' -> (n ->> 'line');
    it := c -> 'item' -> (n ->> 'line');
    out := jsonb_build_array(jsonb_build_object('i', 0, 'type', 'act', 'act', act ->> 0, 'qty', (act ->> 1)::int));
    select k into kk from unnest(public.world_regular_kinds(p_uid)) k order by md5(p_uid::text || ':' || p_npc || ':' || p_day::text || ':kill:' || k) limit 1;
    if kk is not null then out := out || jsonb_build_object('i', 1, 'type', 'kill', 'region', split_part(kk, '|', 1), 'kind', split_part(kk, '|', 2), 'qty', (c ->> 'kill')::int); end if;
    select z into pick from unnest(public.world_regular_cpool(p_uid, p_npc, rk)) z order by md5(p_uid::text || ':' || p_npc || ':' || p_day::text || ':' || z) limit 1;
    if pick is not null then out := out || jsonb_build_object('i', 2, 'type', 'item', 'id', pick, 'qty', case when pick = public.world_ammo_of(p_uid) then (c ->> 'ammo_n')::int else (it ->> 1)::int end); end if;
    return out;
  end if;
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

create or replace function public.world_regular_tally(p_uid uuid, p_day date)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare t0 timestamptz := p_day::timestamp at time zone 'Asia/Seoul'; out jsonb;
begin
  with ev as (
    select e.payload from public.world_events e
     where e.actor_id = p_uid and e.event_type = 'combat' and e.created_at >= t0 and e.created_at < t0 + interval '1 day'
       and coalesce((e.payload ->> 'defeated')::boolean, true))
  select jsonb_build_object('win', count(*),
      'analysis', coalesce(sum((payload -> 'acts' ->> 'analysis')::int), 0),
      'guarding', coalesce(sum((payload -> 'acts' ->> 'guarding')::int), 0),
      'first_aid', coalesce(sum((payload -> 'acts' ->> 'first_aid')::int), 0),
      'kinds', coalesce((select jsonb_object_agg(z.rk, z.n) from (select (ev.payload ->> 'region_id') || '|' || m.kind rk, count(*) n
                          from ev join lateral (select x.kind from public.world_region_monsters x where x.monster_id = ev.payload ->> 'monster_id' and x.kind is not null limit 1) m on true
                          group by 1) z), '{}'::jsonb))
    into out from ev;
  return out;
end $f$;

create or replace function public.world_regular_prog(p_order jsonb, p_tally jsonb)
 returns int language sql immutable set search_path = pg_catalog, public
as $f$
  select case p_order ->> 'type' when 'act' then coalesce((p_tally ->> (p_order ->> 'act'))::int, 0)
    when 'kill' then coalesce((p_tally -> 'kinds' ->> ((p_order ->> 'region') || '|' || (p_order ->> 'kind')))::int, 0) else 0 end
$f$;

create or replace function public.world_regular_view(p_npc text default null)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); k text := p_npc; n jsonb; r jsonb := public.world_regular_rules(); c public.world_characters%rowtype; g public.world_regular_progress%rowtype;
  today date := (now() at time zone 'Asia/Seoul')::date; st jsonb; orders jsonb; rk int; why text; dn int; day_n int; aff int; done int[]; line text; tl jsonb; cg int; here_l text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if k is null then k := public.world_regular_here(uid); end if;
  n := public.world_regular_rule(k);
  if n is null or not public.world_regular_open(uid, k) then raise exception '아직 연담을 맺은 사람이 아닙니다.'; end if;
  select * into g from public.world_regular_progress where owner_id = uid and npc = k;
  aff := coalesce(g.aff, 0);
  done := case when g.day = today then g.done else '{}' end;
  if public.world_project_st_ok(uid) then select s.items into st from public.world_storage s where s.owner_id = uid; st := coalesce(st, '{}'::jsonb); end if;
  line := public.world_regular_line(uid, k);
  rk := public.world_regular_rank(uid, line);
  if n ->> 'kind' = 'combat' then
    tl := public.world_regular_tally(uid, today);
    cg := public.world_regular_cgil(uid, k, rk);
  end if;
  select coalesce(jsonb_agg(case when o ->> 'type' in ('act', 'kill') then
             o || jsonb_build_object('name', case when o ->> 'type' = 'act' then r -> 'combat' -> 'act_name' ->> (o ->> 'act')
                                                  else coalesce((select mrg.region_name from public.world_map_regions mrg where mrg.region_id = o ->> 'region') || '의 ', '') || coalesce((select mk.kind_name from public.world_monster_kinds mk where mk.kind_key = o ->> 'kind'), o ->> 'kind') || ' 요괴' end,
               'done', (o ->> 'i')::int = any (done), 'prog', public.world_regular_prog(o, tl), 'hq_ok', false, 'gil', cg,
               'region_name', (select mrg.region_name from public.world_map_regions mrg where mrg.region_id = o ->> 'region'),
               'kind_name', (select mk.kind_name from public.world_monster_kinds mk where mk.kind_key = o ->> 'kind'))
           else o || jsonb_build_object('name', i.item_name, 'tier', i.tier, 'category', i.category, 'done', (o ->> 'i')::int = any (done),
             'hq_ok', exists (select 1 from public.world_item_catalog h where h.item_id = (o ->> 'id') || '_hq'),
             'gil', floor(coalesce(i.reference_price, 0) * (o ->> 'qty')::int * (r -> 'gil' ->> 'rate')::numeric + (r -> 'gil' ->> 'base')::numeric)::int)
             || public.world_project_have(uid, c.inventory, st, o ->> 'id') end order by (o ->> 'i')::int), '[]'::jsonb)
    into orders from jsonb_array_elements(public.world_regular_orders(uid, k, today)) o left join public.world_item_catalog i on i.item_id = o ->> 'id'
   where o ->> 'type' in ('act', 'kill') or i.item_id is not null;
  day_n := (r ->> 'day_n')::int;
  dn := public.world_regular_day_n(uid, today);
  why := case when (public.world_region_at(c.location)).region_id is distinct from n ->> 'region'
      then (select m.region_name from public.world_map_regions m where m.region_id = n ->> 'region') || '에서 넘깁니다.'
    when c.downed_at is not null or c.health <= 0 then '전투불능 상태에서는 넘길 수 없습니다.'
    when dn >= day_n then '오늘 납품은 다 했습니다(모든 연담을 합쳐 하루 ' || day_n || '번).'
    else null end;
  here_l := array(select x from unnest(public.world_regular_here_list(uid)) x where public.world_regular_open(uid, x));
  return jsonb_build_object('npc', k, 'name', n ->> 'name', 'short', n ->> 'short', 'line', line, 'line_name', public.world_line_name(line), 'line_label', n ->> 'line_label', 'kind', n ->> 'kind', 'rank', rk,
    'xp', public.world_regular_xp(rk, false), 'xp_fine', public.world_regular_xp(rk, true),
    'region', n ->> 'region', 'place', (select m.region_name from public.world_map_regions m where m.region_id = n ->> 'region'),
    'aff', aff, 'stage', public.world_regular_stage(aff), 'next', public.world_regular_next(aff), 'cap', (r -> 'aff' ->> 'cap')::int, 'total', coalesce(g.total, 0),
    'title', n ->> 'title_name',
    'orders', orders, 'storage', st is not null, 'today', jsonb_build_object('n', dn, 'cap', day_n),
    'others', coalesce((select jsonb_agg(jsonb_build_object('npc', x, 'short', public.world_regular_rule(x) ->> 'short')) from unnest(here_l) x where x <> k), '[]'::jsonb),
    'quests', (select jsonb_agg(jsonb_build_object('n', s, 'id', (n ->> 'key') || '_' || s, 'done', public.world_quest_done(uid, (n ->> 'key') || '_' || s),
                 'open', public.world_regular_stage(aff) >= s) order by s) from generate_series(1, 5) s),
    'can', jsonb_build_object('give', why is null, 'why', why));
end $f$;

create or replace function public.world_regular_give(p_npc text, p_order int, p_fine boolean default false)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); nr jsonb := public.world_regular_rule(p_npc); r jsonb := public.world_regular_rules(); c public.world_characters%rowtype;
  g public.world_regular_progress%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; o jsonb; id text; q int; nm text; inv jsonb; st jsonb; st_ok boolean;
  free_inv int; take_inv int; take_st int; rk int; xp int; v_gil int; add int; aff0 int; aff1 int; s0 int; s1 int; dn int; v_done int[]; used_st jsonb := '{}'::jsonb; line text; ids text[]; cid text; need int; got int;
  task boolean := false; pg int; msg text;
begin
  perform public.world_travel_guard('연담 납품');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if nr is null then raise exception '없는 연담 상대입니다.'; end if;
  if not public.world_regular_open(uid, p_npc) then raise exception '아직 연담을 맺은 사람이 아닙니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 넘길 수 없습니다.'; end if;
  if (public.world_region_at(c.location)).region_id is distinct from nr ->> 'region' then
    raise exception '%에서 넘깁니다.', (select m.region_name from public.world_map_regions m where m.region_id = nr ->> 'region');
  end if;
  insert into public.world_regular_day(owner_id, day, n) values (uid, today, 0) on conflict (owner_id) do update set day = excluded.day, n = 0 where world_regular_day.day <> excluded.day;
  select d.n into dn from public.world_regular_day d where d.owner_id = uid for update;
  if dn >= (r ->> 'day_n')::int then raise exception '오늘 납품은 다 했습니다(모든 연담을 합쳐 하루 %번). 내일 다시 오세요.', r ->> 'day_n'; end if;
  insert into public.world_regular_progress(owner_id, npc, day) values (uid, p_npc, today) on conflict do nothing;
  select * into g from public.world_regular_progress where owner_id = uid and npc = p_npc for update;
  v_done := case when g.day = today then g.done else '{}' end;
  if p_order = any (v_done) then raise exception '이 주문은 오늘 이미 넘겼습니다.'; end if;
  select x into o from jsonb_array_elements(public.world_regular_orders(uid, p_npc, today)) x where (x ->> 'i')::int = p_order;
  if o is null then raise exception '없는 주문입니다.'; end if;
  line := public.world_regular_line(uid, p_npc);
  rk := public.world_regular_rank(uid, line);
  q := (o ->> 'qty')::int;
  if o ->> 'type' in ('act', 'kill') then
    task := true;
    if coalesce(p_fine, false) then raise exception '이 주문은 물품을 넘기는 주문이 아닙니다.'; end if;
    pg := public.world_regular_prog(o, public.world_regular_tally(uid, today));
    nm := case when o ->> 'type' = 'act' then r -> 'combat' -> 'act_name' ->> (o ->> 'act')
               else coalesce((select mrg.region_name from public.world_map_regions mrg where mrg.region_id = o ->> 'region') || '의 ', '') || coalesce((select mk.kind_name from public.world_monster_kinds mk where mk.kind_key = o ->> 'kind'), o ->> 'kind') || ' 요괴' end;
    if pg < q then raise exception '아직 다 채우지 못했습니다(오늘 「%」 %/%).', nm, pg, q; end if;
    id := coalesce(o ->> 'act', o ->> 'kind');
    v_gil := public.world_regular_cgil(uid, p_npc, rk);
  else
    id := o ->> 'id';
    if coalesce(p_fine, false) then
      if not exists (select 1 from public.world_item_catalog h where h.item_id = id || '_hq') then raise exception '우수품이 없는 물품입니다.'; end if;
      id := id || '_hq';
    end if;
    ids := case when coalesce(p_fine, false) then array[id]
                when exists (select 1 from public.world_item_catalog h where h.item_id = id || '_hq') then array[id, id || '_hq'] else array[id] end;
    nm := coalesce((select item_name from public.world_item_catalog where item_id = id), id);
    st_ok := public.world_project_st_ok(uid);
    if st_ok then
      insert into public.world_storage(owner_id) values (uid) on conflict do nothing;
      select s.items into st from public.world_storage s where s.owner_id = uid for update;
    end if;
    inv := coalesce(c.inventory, '{}'::jsonb);
    need := q; got := 0;
    foreach cid in array ids loop
      if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = cid) then continue; end if;
      free_inv := public.world_give_check(uid, cid, inv);
      take_inv := least(need, free_inv);
      if take_inv > 0 then inv := public.world_inv_add(inv, cid, -take_inv); need := need - take_inv; end if;
      if need > 0 and st_ok then
        take_st := least(need, greatest(0, coalesce((st ->> cid)::int, 0)));
        if take_st > 0 then
          st := case when coalesce((st ->> cid)::int, 0) - take_st <= 0 then st - cid else jsonb_set(st, array[cid], to_jsonb(coalesce((st ->> cid)::int, 0) - take_st)) end;
          used_st := used_st || jsonb_build_object(cid, take_st); need := need - take_st;
        end if;
      end if;
      exit when need <= 0;
    end loop;
    if need > 0 then
      raise exception '「%」이(가) 모자랍니다(%개 필요, 넘길 수 있는 것 %개 — 잠근 것·장착 중·강화한 것은 빠집니다).', nm, q, q - need;
    end if;
    v_gil := floor(coalesce((select reference_price from public.world_item_catalog where item_id = o ->> 'id'), 0) * q * (r -> 'gil' ->> 'rate')::numeric + (r -> 'gil' ->> 'base')::numeric)::int;
  end if;
  xp := public.world_regular_xp(rk, coalesce(p_fine, false));
  add := case when coalesce(p_fine, false) then (r -> 'aff' ->> 'hq')::int else (r -> 'aff' ->> 'give')::int end;
  aff0 := g.aff; aff1 := least((r -> 'aff' ->> 'cap')::int, aff0 + add);
  s0 := public.world_regular_stage(aff0); s1 := public.world_regular_stage(aff1);
  if task then
    update public.world_characters set gil = gil + v_gil,
      skill_progress = public.world_skill_add(skill_progress, line, xp), updated_at = now() where owner_id = uid;
  else
    perform set_config('yh.wear_leaves', 'on', true);
    update public.world_characters set inventory = inv, gil = gil + v_gil,
      skill_progress = public.world_skill_add(skill_progress, line, xp), updated_at = now() where owner_id = uid;
    if used_st <> '{}'::jsonb then update public.world_storage set items = st, updated_at = now() where owner_id = uid; end if;
  end if;
  update public.world_regular_progress set aff = aff1, total = total + 1, day = today, done = v_done || p_order, updated_at = now() where owner_id = uid and npc = p_npc;
  update public.world_regular_day set n = n + 1 where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  values (uid, 'regular_give', v_gil, false, jsonb_build_object('npc', p_npc, 'item', id, 'qty', q) || case when task then jsonb_build_object('type', o ->> 'type') else '{}'::jsonb end);
  if s1 > s0 then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (uid, 'regular_stage', (nr ->> 'short') || ' · 친밀도 ' || s1 || '단계',
      case when s1 >= 5 and aff1 >= (r -> 'aff' ->> 'cap')::int then public.world_josa(nr ->> 'short', '과', '와') || '의 친밀도가 가장 높은 단계에 닿았습니다. 마지막 이야기가 열렸습니다.'
           else public.world_josa(nr ->> 'short', '과', '와') || '의 친밀도가 ' || s1 || '단계가 되었습니다. 새 이야기가 열렸습니다.' end,
      jsonb_build_object('npc', p_npc, 'stage', s1, 'quest', (nr ->> 'key') || '_' || s1));
  end if;
  if aff1 >= (r -> 'aff' ->> 'cap')::int and aff0 < (r -> 'aff' ->> 'cap')::int then perform public.world_title_award_check(uid, 'regular'); end if;
  msg := case when task then public.world_josa(nr ->> 'short', '에게', '에게') || ' 오늘 「' || nm || '」 ' || q || (case when o ->> 'type' = 'kill' then '마리를' else '번을' end) || ' 보고했습니다'
              else public.world_josa(nr ->> 'short', '에게', '에게') || ' 「' || nm || '」 ' || q || '개를 넘겼습니다' end;
  return jsonb_build_object('npc', p_npc, 'item', id, 'type', coalesce(o ->> 'type', 'item'), 'qty', q, 'xp', xp, 'gil', v_gil, 'aff', aff1, 'add', aff1 - aff0, 'stage', s1, 'stage_up', s1 > s0,
    'from_storage', used_st, 'today', dn + 1, 'cap', (r ->> 'day_n')::int,
    'content', msg || ' · ' || public.world_line_name(line) || ' 경험 +' || xp || ' · ' || to_char(v_gil, 'FM999,999,990') || '전 · 친밀도 +' || (aff1 - aff0) ||
      case when s1 > s0 then ' · 친밀도 ' || s1 || '단계 — 새 이야기가 열렸습니다!' else '' end || ' · 오늘 ' || (dn + 1) || '/' || (r ->> 'day_n'),
    'view', public.world_regular_view(p_npc));
end $f$;

create or replace function public.world_regular_brief_one(p_uid uuid, p_npc text)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare n jsonb := public.world_regular_rule(p_npc); g public.world_regular_progress%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; dn int;
begin
  select * into g from public.world_regular_progress where owner_id = p_uid and npc = p_npc;
  dn := public.world_regular_day_n(p_uid, today);
  return jsonb_build_object('npc', p_npc, 'name', n ->> 'name', 'short', n ->> 'short', 'line_name', public.world_regular_line_name(p_uid, p_npc),
    'aff', coalesce(g.aff, 0), 'stage', public.world_regular_stage(coalesce(g.aff, 0)), 'next', public.world_regular_next(coalesce(g.aff, 0)),
    'left', (public.world_regular_rules() ->> 'orders')::int - coalesce(array_length(case when g.day = today then g.done end, 1), 0),
    'today', dn, 'cap', (public.world_regular_rules() ->> 'day_n')::int);
end $f$;

create or replace function public.world_regular_brief(p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare l jsonb;
begin
  select jsonb_agg(public.world_regular_brief_one(p_uid, x) order by o) into l
    from unnest(public.world_regular_here_list(p_uid)) with ordinality t(x, o) where public.world_regular_open(p_uid, x);
  if l is null then return null; end if;
  return (l -> 0) || jsonb_build_object('all', l);
end $f$;

create or replace function public.world_regular_list()
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); today date := (now() at time zone 'Asia/Seoul')::date;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object('today', public.world_regular_day_n(uid, today), 'cap', (public.world_regular_rules() ->> 'day_n')::int,
    'list', coalesce((select jsonb_agg(jsonb_build_object('npc', e.key, 'name', e.value ->> 'name', 'short', e.value ->> 'short', 'line_name', public.world_regular_line_name(uid, e.key),
        'place', (select m.region_name from public.world_map_regions m where m.region_id = e.value ->> 'region'), 'region', e.value ->> 'region',
        'aff', public.world_regular_aff(uid, e.key), 'stage', public.world_regular_stage(public.world_regular_aff(uid, e.key)), 'next', public.world_regular_next(public.world_regular_aff(uid, e.key)),
        'left', (public.world_regular_rules() ->> 'orders')::int - coalesce((select array_length(g.done, 1) from public.world_regular_progress g where g.owner_id = uid and g.npc = e.key and g.day = today), 0),
        'title', e.value ->> 'title_name') order by (e.value ->> 'sort')::int)
      from jsonb_each(public.world_regular_rules() -> 'npcs') e where public.world_regular_open(uid, e.key)), '[]'::jsonb));
end $f$;

do $g$
declare f text;
begin
  perform pg_temp.pj_share('public.world_regular_prog(jsonb, jsonb)');
  foreach f in array array['world_regular_line(uuid, text)', 'world_regular_line_name(uuid, text)', 'world_regular_here_list(uuid)', 'world_regular_kinds(uuid)',
    'world_regular_cpool(uuid, text, int, boolean)', 'world_regular_cgil(uuid, text, int)', 'world_regular_tally(uuid, date)', 'world_regular_brief_one(uuid, text)'] loop
    perform pg_temp.pj_share('public.' || f);
    perform pg_temp.pj_own('public.' || f, 'fn_owner_field');
  end loop;
end $g$;
grant execute on function public.world_regular_view(text) to authenticated;
grant execute on function public.world_regular_give(text, int, boolean) to authenticated;
grant execute on function public.world_regular_list() to authenticated;
