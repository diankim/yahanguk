create or replace function public.world_gwiryeong_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object('hold', 1, 'cooldown_h', 72, 'window_days', 3, 'cap_div', 2, 'yohwa_mul', 3, 'party_mul', 2, 'wither_h', 72, 'warn_h', 24)
$function$;

create table if not exists public.world_gwiryeong_plants (
  id bigserial primary key,
  holder uuid references auth.users(id) on delete cascade,
  found_at timestamptz not null default now(),
  expires_at timestamptz not null,
  warned boolean not null default false,
  ended text,
  ended_at timestamptz
);
create index if not exists world_gwiryeong_plants_alive on public.world_gwiryeong_plants(holder) where ended is null;
alter table public.world_gwiryeong_plants enable row level security;
revoke all on public.world_gwiryeong_plants from public, anon, authenticated;
revoke all on sequence public.world_gwiryeong_plants_id_seq from public, anon, authenticated;

create or replace function public.world_gwiryeong_held()
 returns table(owner_id uuid, n integer)
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select o, sum(q)::int from (
    select c.owner_id o, (c.inventory ->> 'gwiryeong_cho')::int q from public.world_characters c where c.inventory ? 'gwiryeong_cho'
    union all select s.owner_id, (s.items ->> 'gwiryeong_cho')::int from public.world_storage s where s.items ? 'gwiryeong_cho'
    union all select v.owner_id, v.qty from public.world_overflow_items v where v.item_id = 'gwiryeong_cho'
    union all select t.seller_id, t.quantity from public.world_trade_offers t where t.item_id = 'gwiryeong_cho' and t.status = 'open'
    union all select l.recipient_id, (l.items ->> 'gwiryeong_cho')::int from public.world_letters l where l.claimed_at is null and l.items ? 'gwiryeong_cho'
  ) x where q > 0 group by o
$function$;
revoke all on function public.world_gwiryeong_held() from public, anon, authenticated;
grant execute on function public.world_gwiryeong_held() to service_role, fn_owner_field;

create or replace function public.world_gwiryeong_plant_on_log()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
begin
  insert into public.world_gwiryeong_plants(holder, found_at, expires_at)
  values (new.owner_id, new.got_at, new.got_at + make_interval(hours => (public.world_gwiryeong_rules() ->> 'wither_h')::int));
  return new;
end $function$;
revoke all on function public.world_gwiryeong_plant_on_log() from public, anon, authenticated;
drop trigger if exists trg_world_gwiryeong_plant on public.world_gwiryeong_log;
create trigger trg_world_gwiryeong_plant after insert on public.world_gwiryeong_log for each row execute function public.world_gwiryeong_plant_on_log();

create or replace function public.world_gwiryeong_take_one(p_uid uuid)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare k text := 'gwiryeong_cho'; oid uuid; lid bigint;
begin
  update public.world_characters set inventory = case when (inventory ->> k)::int <= 1 then inventory - k else jsonb_set(inventory, array[k], to_jsonb((inventory ->> k)::int - 1)) end, updated_at = now()
   where owner_id = p_uid and coalesce((inventory ->> k)::int, 0) >= 1;
  if found then return true; end if;
  update public.world_storage set items = case when (items ->> k)::int <= 1 then items - k else jsonb_set(items, array[k], to_jsonb((items ->> k)::int - 1)) end, updated_at = now()
   where owner_id = p_uid and coalesce((items ->> k)::int, 0) >= 1;
  if found then return true; end if;
  update public.world_overflow_items set qty = qty - 1 where owner_id = p_uid and item_id = k and qty > 1;
  if found then return true; end if;
  delete from public.world_overflow_items where owner_id = p_uid and item_id = k;
  if found then return true; end if;
  select offer_id into oid from public.world_trade_offers where seller_id = p_uid and item_id = k and status = 'open' order by created_at limit 1;
  if oid is not null then
    update public.world_trade_offers set quantity = quantity - 1 where offer_id = oid and quantity > 1;
    if not found then update public.world_trade_offers set status = 'cancelled' where offer_id = oid; end if;
    return true;
  end if;
  select id into lid from public.world_letters where recipient_id = p_uid and claimed_at is null and coalesce((items ->> k)::int, 0) >= 1 order by created_at limit 1;
  if lid is not null then
    update public.world_letters set items = case when (items ->> k)::int <= 1 then items - k else jsonb_set(items, array[k], to_jsonb((items ->> k)::int - 1)) end where id = lid;
    return true;
  end if;
  return false;
end $function$;
revoke all on function public.world_gwiryeong_take_one(uuid) from public, anon, authenticated;
grant execute on function public.world_gwiryeong_take_one(uuid) to service_role;

create or replace function public.world_gwiryeong_reconcile()
 returns void
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare wither interval := make_interval(hours => (public.world_gwiryeong_rules() ->> 'wither_h')::int); hold int := (public.world_gwiryeong_rules() ->> 'hold')::int; h record; pool bigint[] := '{}'; i int;
begin
  perform pg_advisory_xact_lock(hashtext('yh-gwiryeong-plants'));
  for h in select a.holder, a.cnt - coalesce(x.n, 0) less
             from (select holder, count(*)::int cnt from public.world_gwiryeong_plants where ended is null group by holder) a
             left join public.world_gwiryeong_held() x on x.owner_id = a.holder where a.cnt > coalesce(x.n, 0) loop
    pool := pool || array(select id from public.world_gwiryeong_plants where ended is null and holder = h.holder order by expires_at, id limit h.less);
  end loop;
  for h in select x.owner_id, x.n, x.n - coalesce(a.cnt, 0) more
             from public.world_gwiryeong_held() x
             left join (select holder, count(*)::int cnt from public.world_gwiryeong_plants where ended is null group by holder) a on a.holder = x.owner_id
            where x.n > coalesce(a.cnt, 0) loop
    if h.n > hold then
      raise exception '귀령초는 한 사람이 %포기까지만 지닐 수 있습니다(가방·창고·거래소 등록·받지 않은 서신을 합쳐). 이미 귀령초를 가진 사람은 더 받을 수 없습니다.', hold using hint = 'gw_hold';
    end if;
    for i in 1..h.more loop
      if cardinality(pool) > 0 then
        update public.world_gwiryeong_plants set holder = h.owner_id where id = pool[1];
        pool := pool[2:];
      else
        insert into public.world_gwiryeong_plants(holder, found_at, expires_at) values (h.owner_id, now(), now() + wither);
      end if;
    end loop;
  end loop;
  update public.world_gwiryeong_plants set ended = 'used', ended_at = now() where id = any(pool);
end $function$;
revoke all on function public.world_gwiryeong_reconcile() from public, anon, authenticated;
grant execute on function public.world_gwiryeong_reconcile() to service_role;

create or replace function public.world_gwiryeong_wither_tick()
 returns integer
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare ru jsonb := public.world_gwiryeong_rules(); warn interval; p record; n int := 0;
begin
  warn := make_interval(hours => (ru ->> 'warn_h')::int);
  perform public.world_gwiryeong_reconcile();
  for p in select * from public.world_gwiryeong_plants where ended is null and not warned and expires_at > now() and expires_at - warn <= now() loop
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p.holder, 'guide', '귀령초가 곧 시듭니다',
      '가진 귀령초 한 포기가 ' || to_char(p.expires_at at time zone 'Asia/Seoul', 'MM"월" DD"일" HH24"시" MI"분"') || '에 시들어 사라집니다. 귀령초는 처음 찾은 때부터 ' || ((ru ->> 'wither_h')::int / 24) || '일이 지나면 시듭니다. 요화로 곤란한 동료가 있으면 그 전에 넘겨 주세요.',
      jsonb_build_object('tip', 'gwiryeong', 'expires_at', p.expires_at));
    update public.world_gwiryeong_plants set warned = true where id = p.id;
  end loop;
  for p in select * from public.world_gwiryeong_plants where ended is null and expires_at <= now() order by id loop
    if public.world_gwiryeong_take_one(p.holder) then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (p.holder, 'guide', '귀령초가 시들었습니다',
        '처음 찾은 지 ' || ((ru ->> 'wither_h')::int / 24) || '일이 지난 귀령초 한 포기가 시들어 사라졌습니다. 귀령초는 서버 전체에 몇 포기뿐이라 오래 쥐고 있으면 시듭니다.',
        jsonb_build_object('tip', 'gwiryeong'));
      update public.world_gwiryeong_plants set ended = 'withered', ended_at = now() where id = p.id;
      n := n + 1;
    else
      update public.world_gwiryeong_plants set ended = 'used', ended_at = now() where id = p.id;
    end if;
  end loop;
  return n;
end $function$;
revoke all on function public.world_gwiryeong_wither_tick() from public, anon, authenticated;
grant execute on function public.world_gwiryeong_wither_tick() to service_role, fn_owner_field;

create or replace function public.world_gwiryeong_on_move()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
begin
  perform public.world_gwiryeong_reconcile();
  return null;
end $function$;
revoke all on function public.world_gwiryeong_on_move() from public, anon, authenticated;

drop trigger if exists trg_world_gw_move_char on public.world_characters;
create constraint trigger trg_world_gw_move_char after update of inventory on public.world_characters deferrable initially deferred for each row
 when ((old.inventory -> 'gwiryeong_cho') is distinct from (new.inventory -> 'gwiryeong_cho')) execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_char_del on public.world_characters;
create constraint trigger trg_world_gw_move_char_del after delete on public.world_characters deferrable initially deferred for each row
 when (old.inventory ? 'gwiryeong_cho') execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_store_ins on public.world_storage;
create constraint trigger trg_world_gw_move_store_ins after insert on public.world_storage deferrable initially deferred for each row
 when (new.items ? 'gwiryeong_cho') execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_store_upd on public.world_storage;
create constraint trigger trg_world_gw_move_store_upd after update on public.world_storage deferrable initially deferred for each row
 when ((old.items -> 'gwiryeong_cho') is distinct from (new.items -> 'gwiryeong_cho')) execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_store_del on public.world_storage;
create constraint trigger trg_world_gw_move_store_del after delete on public.world_storage deferrable initially deferred for each row
 when (old.items ? 'gwiryeong_cho') execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_ov_ins on public.world_overflow_items;
create constraint trigger trg_world_gw_move_ov_ins after insert on public.world_overflow_items deferrable initially deferred for each row
 when (new.item_id = 'gwiryeong_cho') execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_ov_upd on public.world_overflow_items;
create constraint trigger trg_world_gw_move_ov_upd after update on public.world_overflow_items deferrable initially deferred for each row
 when (new.item_id = 'gwiryeong_cho' or old.item_id = 'gwiryeong_cho') execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_ov_del on public.world_overflow_items;
create constraint trigger trg_world_gw_move_ov_del after delete on public.world_overflow_items deferrable initially deferred for each row
 when (old.item_id = 'gwiryeong_cho') execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_offer_ins on public.world_trade_offers;
create constraint trigger trg_world_gw_move_offer_ins after insert on public.world_trade_offers deferrable initially deferred for each row
 when (new.item_id = 'gwiryeong_cho') execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_offer_upd on public.world_trade_offers;
create constraint trigger trg_world_gw_move_offer_upd after update on public.world_trade_offers deferrable initially deferred for each row
 when (new.item_id = 'gwiryeong_cho' or old.item_id = 'gwiryeong_cho') execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_offer_del on public.world_trade_offers;
create constraint trigger trg_world_gw_move_offer_del after delete on public.world_trade_offers deferrable initially deferred for each row
 when (old.item_id = 'gwiryeong_cho') execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_letter_ins on public.world_letters;
create constraint trigger trg_world_gw_move_letter_ins after insert on public.world_letters deferrable initially deferred for each row
 when (new.items ? 'gwiryeong_cho') execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_letter_upd on public.world_letters;
create constraint trigger trg_world_gw_move_letter_upd after update on public.world_letters deferrable initially deferred for each row
 when ((old.items -> 'gwiryeong_cho') is distinct from (new.items -> 'gwiryeong_cho') or (old.claimed_at is null) is distinct from (new.claimed_at is null) and (old.items ? 'gwiryeong_cho')) execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_letter_del on public.world_letters;
create constraint trigger trg_world_gw_move_letter_del after delete on public.world_letters deferrable initially deferred for each row
 when (old.items ? 'gwiryeong_cho' and old.claimed_at is null) execute function public.world_gwiryeong_on_move();
drop trigger if exists trg_world_gw_move_log on public.world_gwiryeong_log;
create constraint trigger trg_world_gw_move_log after insert on public.world_gwiryeong_log deferrable initially deferred for each row execute function public.world_gwiryeong_on_move();

do $r$
declare src text := pg_get_functiondef('public.world_yohwa_tick()'::regprocedure);
  o text := $o$return n;$o$;
begin
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_yohwa_tick: 바꿀 곳이 하나가 아님'; end if;
  execute replace(src, o, $n$perform public.world_gwiryeong_wither_tick(); return n;$n$);
end $r$;

insert into public.world_gwiryeong_plants(holder, found_at, expires_at)
select h.owner_id, g.got, g.got + make_interval(hours => (public.world_gwiryeong_rules() ->> 'wither_h')::int)
  from public.world_gwiryeong_held() h
  cross join lateral generate_series(1, h.n) k
  cross join lateral (select coalesce((select max(l.got_at) from public.world_gwiryeong_log l where l.owner_id = h.owner_id), now()) got) g
 where not exists (select 1 from public.world_gwiryeong_plants p where p.holder = h.owner_id and p.ended is null);

do $r$
declare src text := pg_get_functiondef('public.world_gwiryeong_reserve(uuid,text)'::regprocedure);
  o text := $o$  if coalesce((select (c.inventory ->> 'gwiryeong_cho')::int from public.world_characters c where c.owner_id = p_uid), 0)
     + coalesce((select (s.items ->> 'gwiryeong_cho')::int from public.world_storage s where s.owner_id = p_uid), 0) >= (ru ->> 'hold')::int then return false; end if;$o$;
begin
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_gwiryeong_reserve: 바꿀 곳이 하나가 아님'; end if;
  execute replace(src, o, $n$  if coalesce((select h.n from public.world_gwiryeong_held() h where h.owner_id = p_uid), 0) >= (ru ->> 'hold')::int then return false; end if;$n$);
end $r$;

do $r$
declare src text := pg_get_functiondef('public.world_trade_direct_offer(uuid,jsonb,bigint,jsonb,bigint)'::regprocedure);
  o text := $o$p_want := coalesce(p_want, '{}'::jsonb);$o$;
begin
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_trade_direct_offer: 바꿀 곳이 하나가 아님'; end if;
  execute replace(src, o, $n$p_want := coalesce(p_want, '{}'::jsonb);
  if p_give ? 'gwiryeong_cho' and p_want ? 'gwiryeong_cho' then raise exception '귀령초는 서로 맞바꿀 수 없습니다.' using hint = 'gw_swap'; end if;$n$);
end $r$;

do $r$
declare src text := pg_get_functiondef('public.world_trade_direct_respond(uuid,boolean)'::regprocedure);
  o text := $o$if t.status <> 'pending' or t.expires_at <= now() then raise exception '이미 끝났거나 시간이 지난 거래 제안입니다.'; end if;$o$;
begin
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_trade_direct_respond: 바꿀 곳이 하나가 아님'; end if;
  execute replace(src, o, o || $n$
  if p_accept and coalesce(t.give_items, '{}'::jsonb) ? 'gwiryeong_cho' and coalesce(t.want_items, '{}'::jsonb) ? 'gwiryeong_cho' then raise exception '귀령초는 서로 맞바꿀 수 없습니다.' using hint = 'gw_swap'; end if;$n$);
end $r$;

select public.world_gwiryeong_wither_tick();

update public.world_patch_notes set body = body || E'\n- 귀령초는 처음 찾은 때부터 3일이 지나면 시들어 사라집니다(남에게 넘겨도 처음 찾은 때부터 셉니다). 시들기 하루 전에 알려 드립니다. 귀령초는 한 사람이 한 포기까지만 지닐 수 있어, 이미 가진 사람은 거래·서신으로도 더 받을 수 없습니다. 귀령초끼리 서로 맞바꿀 수도 없습니다. 요화로 곤란한 동료가 있으면 넘겨 주세요.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261108230000' where key = 'db_version';
