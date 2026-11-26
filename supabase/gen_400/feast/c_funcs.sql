create or replace function pg_temp.yh_hf_patch(p_fn text, p_old text, p_new text) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  if position(p_new in d) > 0 then return; end if;
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k <> 1 then raise exception '고칠 자리 수가 다름: % (1번 기대, %번)', p_fn, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

create or replace function public.world_hfeast_slot(p_t timestamptz)
 returns timestamptz
 language sql
 stable
 set search_path to 'pg_catalog', 'public'
as $function$
  select (date_trunc('hour', p_t at time zone (r ->> 'tz'))
          - make_interval(hours => extract(hour from p_t at time zone (r ->> 'tz'))::int % (r ->> 'slot_h')::int)) at time zone (r ->> 'tz')
    from (select public.world_harbor_feast_rules() r) x
$function$;

create or replace function public.world_hfeast_ports()
 returns table(port_id text, region_id text, port_name text, region_name text)
 language plpgsql
 stable
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare j jsonb;
begin
  if to_regprocedure('public.world_trade_rules()') is null then return; end if;
  execute 'select public.world_trade_rules() -> ''ports''' into j;
  return query
    select p.key, coalesce(p.value ->> 'region', p.key), coalesce(p.value ->> 'name', g.region_name), coalesce(g.region_name, p.value ->> 'name')
      from jsonb_each(coalesce(j, '{}'::jsonb)) p
      left join public.world_map_regions g on g.region_id = coalesce(p.value ->> 'region', p.key);
end $function$;

create or replace function public.world_hfeast_port_at(p_uid uuid)
 returns text
 language sql
 stable
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select p.port_id from public.world_hfeast_ports() p join public.world_characters c on c.owner_id = p_uid and c.location = p.region_name limit 1
$function$;

create or replace function public.world_hfeast_dish_kind(p_item text)
 returns text
 language sql
 stable
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  with b as (select public.world_item_base(p_item) id, public.world_harbor_feast_rules() r),
  rec as (select k from b, public.world_crafting_recipes x, jsonb_object_keys(x.ingredients) k
           where x.output_item = b.id and x.craft_field = 'cooking')
  select case
    when not exists (select 1 from b join public.world_item_catalog i on i.item_id = b.id and i.category = 'consumable') then null
    when exists (select 1 from b where (b.r -> 'skip') ? b.id) then null
    when not exists (select 1 from b, public.world_crafting_recipes x where x.output_item = b.id and x.craft_field = 'cooking') then null
    when exists (select 1 from rec where rec.k like 'mt\_%') then 'meat'
    when exists (select 1 from rec, b where (b.r -> 'sea_items') ? rec.k or exists (select 1 from public.world_fish_species f where f.fish_id = rec.k)) then 'sea'
    else 'soban' end
$function$;

create or replace function public.world_hfeast_table_kind(p_table uuid)
 returns text
 language sql
 stable
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  with c as (select b.kind, count(*) n from public.world_hfeast_bowls b where b.table_id = p_table group by b.kind),
  m as (select max(n) mx from c)
  select case when (select count(*) from c, m where c.n = m.mx) = 1 then (select c.kind from c, m where c.n = m.mx)
              else public.world_harbor_feast_rules() ->> 'tie' end
$function$;

create or replace function public.world_hfeast_buff(p_uid uuid, p_kind text)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_harbor_feast_rules(); k text := r -> 'kinds' -> p_kind ->> 'key';
begin
  if k is null or not public.world_feast_room(p_uid, k) then return false; end if;
  delete from public.world_character_statuses where owner_id = p_uid and status_key = k;
  insert into public.world_character_statuses(owner_id, status_key, potency, source_activity, expires_at)
  values (p_uid, k, 1, 'hfeast', now() + make_interval(hours => (r ->> 'buff_h')::int));
  return true;
end $function$;

create or replace function public.world_hfeast_open(p_table uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_harbor_feast_rules(); t public.world_hfeast_tables%rowtype; kd text; ki jsonb; m record; pn text; rn text; who uuid; cap text := public.world_status_rules() ->> 'cap'; hm text;
begin
  select * into t from public.world_hfeast_tables where table_id = p_table;
  kd := public.world_hfeast_table_kind(p_table);
  ki := r -> 'kinds' -> kd;
  update public.world_hfeast_tables set status = 'open', kind = kd, opened_at = now(), eat_until = now() + make_interval(hours => (r ->> 'eat_h')::int)
   where table_id = p_table returning * into t;
  select p.port_name, p.region_name into pn, rn from public.world_hfeast_ports() p where p.port_id = t.port_id;
  hm := to_char(t.eat_until at time zone (r ->> 'tz'), 'HH24:MI');
  for m in select distinct b.owner_id, c.downed_at is not null down from public.world_hfeast_bowls b join public.world_characters c on c.owner_id = b.owner_id
            where b.table_id = p_table and not coalesce(c.is_dead, false) loop
    if m.down then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (m.owner_id, r ->> 'note', coalesce(pn, '') || ' 잔칫상이 열렸습니다',
              (ki ->> 'name') || '이(가) 차려졌지만 쓰러진 채로는 「' || (ki ->> 'buff') || '」 기운을 받을 수 없습니다. 일어난 뒤 ' || hm || '까지 ' || coalesce(pn, '항구') || '에서 「상에서 먹기」를 하세요.',
              jsonb_build_object('table', p_table, 'port', t.port_id, 'kind', kd, 'eat_until', t.eat_until, 'got', false, 'down', true));
    elsif public.world_hfeast_buff(m.owner_id, kd) then
      insert into public.world_hfeast_eats(table_id, owner_id, giver) values (p_table, m.owner_id, true) on conflict do nothing;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (m.owner_id, r ->> 'note', coalesce(pn, '') || ' 잔칫상이 열렸습니다',
              '열두 그릇이 다 차 ' || (ki ->> 'name') || '이(가) 차려졌습니다. 「' || (ki ->> 'buff') || '」 기운을 ' || (r ->> 'buff_h') || '시간 동안 받았습니다.',
              jsonb_build_object('table', p_table, 'port', t.port_id, 'kind', kd, 'eat_until', t.eat_until, 'got', true));
    else
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (m.owner_id, r ->> 'note', coalesce(pn, '') || ' 잔칫상이 열렸습니다',
              (ki ->> 'name') || '이(가) 차려졌지만 상태 칸 ' || cap || '칸이 모두 차 있어 「' || (ki ->> 'buff') || '」 기운을 받지 못했습니다. ' || hm || '까지 칸을 비우고 ' || coalesce(pn, '항구') || '에서 「상에서 먹기」를 하면 받을 수 있습니다.',
              jsonb_build_object('table', p_table, 'port', t.port_id, 'kind', kd, 'eat_until', t.eat_until, 'got', false));
    end if;
  end loop;
  who := coalesce((select owner_id from public.world_staff order by owner_id limit 1), (select owner_id from public.world_characters order by owner_id limit 1));
  if who is not null then
    insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
    values ('global', who, r ->> 'chat',
            coalesce(pn, rn, '항구') || '의 나눔 잔칫상에 ' || (ki ->> 'name') || '이(가) 차려졌습니다. ' || hm || '까지 와서 「상에서 먹기」를 하면 「' || (ki ->> 'buff') || '」 기운을 ' || (r ->> 'buff_h') || '시간 동안 받습니다.');
  end if;
end $function$;

create or replace function public.world_hfeast_view(p_port text default null)
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_harbor_feast_rules(); here text; port text; pn text; rn text; slot timestamptz := public.world_hfeast_slot(now());
  t public.world_hfeast_tables%rowtype; e public.world_hfeast_tables%rowtype; c public.world_characters%rowtype; bowls jsonb; dishes jsonb; mine int := 0; ate boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  here := public.world_hfeast_port_at(uid);
  port := coalesce(p_port, here);
  select p.port_name, p.region_name into pn, rn from public.world_hfeast_ports() p where p.port_id = port;
  if port is null or pn is null then
    return jsonb_build_object('port', null, 'now', now(), 'rules', r, 'slot_at', slot, 'slot_end', slot + make_interval(hours => (r ->> 'slot_h')::int));
  end if;
  select * into t from public.world_hfeast_tables where port_id = port and slot_at = slot;
  if t.table_id is not null then
    select coalesce(jsonb_agg(jsonb_build_object('n', b.n, 'name', b.name, 'item', b.item_id, 'item_name', coalesce(i.item_name, b.item_id), 'hq', b.hq, 'kind', b.kind, 'me', b.owner_id = uid) order by b.n), '[]'::jsonb),
           count(*) filter (where b.owner_id = uid)
      into bowls, mine
      from public.world_hfeast_bowls b left join public.world_item_catalog i on i.item_id = b.item_id where b.table_id = t.table_id;
  end if;
  select * into e from public.world_hfeast_tables where port_id = port and status = 'open' and eat_until > now() order by opened_at desc limit 1;
  if e.table_id is not null then ate := exists (select 1 from public.world_hfeast_eats where table_id = e.table_id and owner_id = uid); end if;
  if here = port then
    select coalesce(jsonb_agg(jsonb_build_object('id', x.key, 'name', coalesce(i.item_name, x.key), 'n', x.value::text::int, 'hq', x.key like '%\_hq', 'kind', public.world_hfeast_dish_kind(x.key)) order by i.item_name), '[]'::jsonb)
      into dishes
      from jsonb_each(c.inventory) x left join public.world_item_catalog i on i.item_id = x.key
     where jsonb_typeof(x.value) = 'number' and x.value::text::numeric > 0 and public.world_hfeast_dish_kind(x.key) is not null;
  end if;
  return jsonb_build_object(
    'now', now(), 'rules', r, 'port', port, 'port_name', pn, 'region', rn, 'here', coalesce(here = port, false),
    'slot_at', slot, 'slot_end', slot + make_interval(hours => (r ->> 'slot_h')::int),
    'table', case when t.table_id is null then jsonb_build_object('status', 'fill', 'n', 0, 'need', (r ->> 'need')::int, 'bowls', '[]'::jsonb)
                  else jsonb_build_object('id', t.table_id, 'status', t.status, 'n', t.n, 'need', (r ->> 'need')::int, 'kind', t.kind, 'kind_name', r -> 'kinds' -> t.kind ->> 'name',
                                          'opened_at', t.opened_at, 'eat_until', t.eat_until, 'bowls', bowls) end,
    'mine', mine, 'mine_left', greatest(0, (r ->> 'per_person')::int - mine),
    'eat', case when e.table_id is null then null
                else jsonb_build_object('table', e.table_id, 'kind', e.kind, 'kind_name', r -> 'kinds' -> e.kind ->> 'name', 'buff', r -> 'kinds' -> e.kind ->> 'buff',
                                        'until', e.eat_until, 'ate', ate, 'full', not ate and not public.world_feast_room(uid, r -> 'kinds' -> e.kind ->> 'key')) end,
    'full', not public.world_status_room(uid, r -> 'kinds' -> 'soban' ->> 'key'),
    'cap', (public.world_status_rules() ->> 'cap')::int,
    'dishes', dishes);
end $function$;

create or replace function public.world_hfeast_list()
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_harbor_feast_rules(); slot timestamptz := public.world_hfeast_slot(now());
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object('now', now(), 'slot_at', slot, 'slot_end', slot + make_interval(hours => (r ->> 'slot_h')::int), 'need', (r ->> 'need')::int,
    'ports', (select coalesce(jsonb_agg(jsonb_build_object('port', p.port_id, 'name', p.port_name, 'region', p.region_id,
                'status', coalesce(t.status, 'fill'), 'n', coalesce(t.n, 0), 'kind', t.kind,
                'eat_until', e.eat_until, 'eat_kind', e.kind) order by p.port_name), '[]'::jsonb)
                from public.world_hfeast_ports() p
                left join public.world_hfeast_tables t on t.port_id = p.port_id and t.slot_at = slot
                left join lateral (select x.eat_until, x.kind from public.world_hfeast_tables x where x.port_id = p.port_id and x.status = 'open' and x.eat_until > now() order by x.opened_at desc limit 1) e on true));
end $function$;

create or replace function public.world_hfeast_give(p_item text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_harbor_feast_rules(); c public.world_characters%rowtype; port text; pn text; slot timestamptz := public.world_hfeast_slot(now());
  t public.world_hfeast_tables%rowtype; kd text; taken text; mine int; nx int; opened boolean := false; msg text;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_travel_guard('잔칫상에 요리 올리기');
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터가 없습니다.'; end if;
  if c.downed_at is not null or coalesce(c.is_dead, false) then raise exception '쓰러진 채로는 요리를 올릴 수 없습니다.'; end if;
  port := public.world_hfeast_port_at(uid);
  if port is null then raise exception '항구에 있어야 잔칫상에 요리를 올릴 수 있습니다.' using hint = 'hfeast_port'; end if;
  select p.port_name into pn from public.world_hfeast_ports() p where p.port_id = port;
  kd := public.world_hfeast_dish_kind(p_item);
  if kd is null then raise exception '잔칫상에는 요리만 올릴 수 있습니다.' using hint = 'hfeast_dish'; end if;
  taken := case when coalesce((c.inventory ->> p_item)::int, 0) > 0 then p_item
                when p_item not like '%\_hq' and coalesce((c.inventory ->> (p_item || '_hq'))::int, 0) > 0 then p_item || '_hq' end;
  if taken is null then raise exception '가방에 그 요리가 없습니다.' using hint = 'hfeast_none'; end if;
  delete from public.world_hfeast_tables where port_id = port and slot_at < now() - make_interval(days => (r ->> 'keep_days')::int);
  insert into public.world_hfeast_tables(port_id, slot_at) values (port, slot) on conflict (port_id, slot_at) do nothing;
  select * into t from public.world_hfeast_tables where port_id = port and slot_at = slot for update;
  if t.status <> 'fill' then raise exception '이번 잔칫상은 이미 차려졌습니다. 다음 상은 %부터 올릴 수 있습니다.', to_char((slot + make_interval(hours => (r ->> 'slot_h')::int)) at time zone (r ->> 'tz'), 'HH24:MI') using hint = 'hfeast_open'; end if;
  select count(*) into mine from public.world_hfeast_bowls where table_id = t.table_id and owner_id = uid;
  if mine >= (r ->> 'per_person')::int then raise exception '한 상에는 한 사람이 %그릇까지 올릴 수 있습니다.', r ->> 'per_person' using hint = 'hfeast_mine'; end if;
  update public.world_characters set inventory = public.world_materials_take(c.inventory, '{}'::jsonb, jsonb_build_object(taken, 1)) -> 'inv' where owner_id = uid;
  nx := coalesce((select max(n) from public.world_hfeast_bowls where table_id = t.table_id), 0) + 1;
  insert into public.world_hfeast_bowls(table_id, n, owner_id, name, item_id, hq, kind) values (t.table_id, nx, uid, c.character_name, public.world_item_base(taken), taken like '%\_hq', kd);
  update public.world_hfeast_tables set n = n + 1 where table_id = t.table_id returning * into t;
  if t.n >= (r ->> 'need')::int then
    perform public.world_hfeast_open(t.table_id);
    opened := true;
    select * into t from public.world_hfeast_tables where table_id = t.table_id;
    msg := '마지막 그릇을 올려 ' || (r -> 'kinds' -> t.kind ->> 'name') || '이(가) 차려졌습니다.';
  else
    msg := coalesce(pn, '') || ' 잔칫상에 요리를 올렸습니다(' || t.n || '/' || (r ->> 'need') || ').';
  end if;
  return public.world_hfeast_view(port) || jsonb_build_object('ok', true, 'content', msg, 'opened', opened, 'kind', kd);
end $function$;

create or replace function public.world_hfeast_eat()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_harbor_feast_rules(); c public.world_characters%rowtype; port text; e public.world_hfeast_tables%rowtype; ki jsonb; n int;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_travel_guard('잔칫상에서 먹기');
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터가 없습니다.'; end if;
  if c.downed_at is not null or coalesce(c.is_dead, false) then raise exception '쓰러진 채로는 먹을 수 없습니다.'; end if;
  port := public.world_hfeast_port_at(uid);
  if port is null then raise exception '항구에 있어야 잔칫상에서 먹을 수 있습니다.' using hint = 'hfeast_port'; end if;
  select * into e from public.world_hfeast_tables where port_id = port and status = 'open' and eat_until > now() order by opened_at desc limit 1;
  if not found then raise exception '지금 이 항구에 차려진 잔칫상이 없습니다.' using hint = 'hfeast_closed'; end if;
  ki := r -> 'kinds' -> e.kind;
  if exists (select 1 from public.world_hfeast_eats where table_id = e.table_id and owner_id = uid) then raise exception '이 상에서는 이미 먹었습니다.' using hint = 'hfeast_ate'; end if;
  if not public.world_feast_room(uid, ki ->> 'key') then
    raise exception '상태 칸 %칸이 모두 차 있어 기운을 받을 수 없습니다. 이로운 상태를 상태 창에서 꺼 칸을 비운 뒤 다시 하세요.', public.world_status_rules() ->> 'cap' using hint = 'hfeast_full';
  end if;
  insert into public.world_hfeast_eats(table_id, owner_id) values (e.table_id, uid) on conflict do nothing;
  get diagnostics n = row_count;
  if n = 0 then raise exception '이 상에서는 이미 먹었습니다.' using hint = 'hfeast_ate'; end if;
  perform public.world_hfeast_buff(uid, e.kind);
  return public.world_hfeast_view(port) || jsonb_build_object('ok', true, 'content', (ki ->> 'name') || '에서 나눠 먹고 「' || (ki ->> 'buff') || '」 기운을 ' || (r ->> 'buff_h') || '시간 동안 받았습니다.');
end $function$;

do $o$ declare f text; x text; g boolean := not has_schema_privilege('fn_owner_field', 'public', 'CREATE'); begin
  foreach f in array array['world_hfeast_slot(timestamptz)', 'world_hfeast_ports()', 'world_hfeast_port_at(uuid)', 'world_hfeast_dish_kind(text)', 'world_hfeast_table_kind(uuid)',
                           'world_hfeast_buff(uuid, text)', 'world_hfeast_open(uuid)', 'world_hfeast_view(text)', 'world_hfeast_list()', 'world_hfeast_give(text)', 'world_hfeast_eat()'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
      execute format('grant execute on function public.%s to %I', f, x);
    end loop;
  end loop;
  grant execute on function public.world_hfeast_view(text), public.world_hfeast_list(), public.world_hfeast_give(text), public.world_hfeast_eat() to authenticated;
  if to_regprocedure('public.world_trade_rules()') is not null then
    for x in select rolname from pg_roles where rolname like 'fn\_owner%' loop
      execute format('grant execute on function public.world_trade_rules() to %I', x);
    end loop;
  end if;
  if g then grant create on schema public to fn_owner_field; end if;
  foreach f in array array['world_hfeast_ports()', 'world_hfeast_port_at(uuid)', 'world_hfeast_dish_kind(text)', 'world_hfeast_table_kind(uuid)',
                           'world_hfeast_buff(uuid, text)', 'world_hfeast_open(uuid)', 'world_hfeast_view(text)', 'world_hfeast_list()', 'world_hfeast_give(text)', 'world_hfeast_eat()'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
  end loop;
  if g then revoke create on schema public from fn_owner_field; end if;
end $o$;

select pg_temp.yh_hf_patch('public.world_character_purge(uuid)', '  if p_uid is null then return; end if;', '  if p_uid is null then return; end if;
  delete from public.world_hfeast_eats where owner_id = p_uid;
  update public.world_hfeast_tables t set n = t.n - x.k from (select b.table_id, count(*)::int k from public.world_hfeast_bowls b join public.world_hfeast_tables y on y.table_id = b.table_id and y.status = ''fill'' where b.owner_id = p_uid group by b.table_id) x where t.table_id = x.table_id;
  delete from public.world_hfeast_bowls where owner_id = p_uid;');

select pg_temp.yh_hf_patch('public.world_notify_group(text)', $$when p_kind in ('regular_stage') then 'reward'$$, $$when p_kind in ('regular_stage', 'hfeast') then 'reward'$$);

do $s$
declare a text[] := public.world_sys_chat_names(); nm text := public.world_harbor_feast_rules() ->> 'chat';
begin
  if not nm = any (a) then
    execute format('create or replace function public.world_sys_chat_names() returns text[] language sql immutable as %L', format('select %L::text[]', (a || nm)::text));
  end if;
end $s$;
