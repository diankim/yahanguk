create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

create or replace function public.world_bijang_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object(
    'maps', jsonb_build_array(
      jsonb_build_object('tier', 1, 'id', 'bj_map_1', 'name', '낡은 비장도', 'lv', 30, 'lo', 30, 'hi', 37),
      jsonb_build_object('tier', 2, 'id', 'bj_map_2', 'name', '귀한 비장도', 'lv', 38, 'lo', 38, 'hi', 43),
      jsonb_build_object('tier', 3, 'id', 'bj_map_3', 'name', '봉인된 비장도', 'lv', 44, 'lo', 44, 'hi', 46)),
    'hold', 1, 'party_max', 4, 'gather_s', 60, 'stamina', 1, 'entry_day', 3, 'rooms', 5,
    'door_pct', jsonb_build_array(50, 60, 70),
    'reveal_pct', jsonb_build_array(25, 30, 35, 40),
    'room_guard_pct', 100,
    'guard', jsonb_build_object('lv_up', 3, 'hp_mul', 1.2, 'atk_mul', 1.0, 'room_rank', 'guardian'),
    'chest', jsonb_build_object(
      '1', jsonb_build_object('gil', jsonb_build_array(120, 280), 'n', jsonb_build_array(1, 2), 'items', jsonb_build_array(
        jsonb_build_object('id', 'steel_ingot', 'w', 3), jsonb_build_object('id', 'spirit_bark', 'w', 3), jsonb_build_object('id', 'reinforced_lumber', 'w', 3),
        jsonb_build_object('id', 'reed_silk', 'w', 2), jsonb_build_object('id', 'inverted_incense', 'w', 2), jsonb_build_object('id', 'moonless_silk', 'w', 2),
        jsonb_build_object('id', 'oblivion_crystal', 'w', 2), jsonb_build_object('id', 'mz_herb', 'w', 1), jsonb_build_object('id', 'mz_wood', 'w', 1), jsonb_build_object('id', 'mz_stone', 'w', 1))),
      '2', jsonb_build_object('gil', jsonb_build_array(220, 450), 'n', jsonb_build_array(1, 2), 'items', jsonb_build_array(
        jsonb_build_object('id', 'gwiheo_iron', 'w', 3), jsonb_build_object('id', 'yoin_blood', 'w', 2), jsonb_build_object('id', 'jade_shard', 'w', 2),
        jsonb_build_object('id', 'blank_hanji', 'w', 2), jsonb_build_object('id', 'meokbi_ebony', 'w', 2), jsonb_build_object('id', 'spirit_core', 'w', 1),
        jsonb_build_object('id', 'mz_herb', 'w', 1), jsonb_build_object('id', 'mz_wood', 'w', 1), jsonb_build_object('id', 'mz_stone', 'w', 1))),
      '3', jsonb_build_object('gil', jsonb_build_array(350, 700), 'n', jsonb_build_array(1, 2), 'items', jsonb_build_array(
        jsonb_build_object('id', 'register_slip', 'w', 2), jsonb_build_object('id', 'drifting_name_thread', 'w', 2), jsonb_build_object('id', 'erased_plate', 'w', 2),
        jsonb_build_object('id', 'yoin_blood', 'w', 2), jsonb_build_object('id', 'gwiheo_pearl', 'w', 1), jsonb_build_object('id', 'spirit_core', 'w', 1),
        jsonb_build_object('id', 'mz_herb', 'w', 1), jsonb_build_object('id', 'mz_wood', 'w', 1), jsonb_build_object('id', 'mz_stone', 'w', 1)))),
    'egg', jsonb_build_object('id', 'pet_egg_3', 'pct', jsonb_build_array(0.5, 1, 2)),
    'final', jsonb_build_object('gil', jsonb_build_array(1000, 1800, 2800), 'picks', jsonb_build_array(1, 1, 2), 'items', jsonb_build_array(
      jsonb_build_object('id', 'mz_herb_n', 'w', 3, 'n', 1), jsonb_build_object('id', 'mz_wood_n', 'w', 3, 'n', 1), jsonb_build_object('id', 'mz_stone_n', 'w', 3, 'n', 1),
      jsonb_build_object('id', 'pet_egg_3', 'w', 2, 'n', 1),
      jsonb_build_object('pet', 'bj_mandarin_duck', 'w', 1),
      jsonb_build_object('pet', 'bj_horseshoe_crab', 'w', 1),
      jsonb_build_object('pet', 'bj_moon_halo', 'w', 1),
      jsonb_build_object('pet', 'bj_rainbow_lizard', 'w', 1),
      jsonb_build_object('pet', 'bj_pink_marten', 'w', 1),
      jsonb_build_object('pet', 'bj_rose_wolf', 'w', 1),
      jsonb_build_object('pet', 'bj_seahorse', 'w', 1),
      jsonb_build_object('pet', 'bj_silkmoth', 'w', 1),
      jsonb_build_object('pet', 'bj_bukcheong_lion', 'w', 1),
      jsonb_build_object('pet', 'bj_mirage_cat', 'w', 1),
      jsonb_build_object('pet', 'bj_black_goat', 'w', 1),
      jsonb_build_object('pet', 'bj_phoenix', 'w', 1),
      jsonb_build_object('pet', 'bj_mountain_turtle', 'w', 1),
      jsonb_build_object('id', 'hf_bj_name_chest', 'w', 2, 'n', 1),
      jsonb_build_object('id', 'hf_bj_vault_gate', 'w', 2, 'n', 1),
      jsonb_build_object('id', 'hf_bj_map_frame', 'w', 2, 'n', 1))),
    'titles', jsonb_build_array(1, 5, 20), 'seal', 'sl_bj')
$function$;
grant execute on function public.world_bijang_rules() to public;

create or replace function public.world_bijang_map_rule(p_tier int)
 returns jsonb
 language sql
 immutable
as $function$
  select m from jsonb_array_elements(public.world_bijang_rules() -> 'maps') m where (m ->> 'tier')::int = p_tier
$function$;
grant execute on function public.world_bijang_map_rule(int) to public;

create or replace function public.world_bijang_tier_of(p_item text)
 returns int
 language sql
 immutable
as $function$
  select (m ->> 'tier')::int from jsonb_array_elements(public.world_bijang_rules() -> 'maps') m where m ->> 'id' = p_item
$function$;
grant execute on function public.world_bijang_tier_of(text) to public;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, minimum_level, tradeable, reference_price, stack_size, equipment_traits)
select m ->> 'id', m ->> 'name', 'consumable', 3 + (m ->> 'tier')::int,
  case (m ->> 'tier')::int
    when 1 then '명부 정리 전에 누군가 이름과 재물을 함께 묻은 자리를 그린 옛 그림. 가방에서 펼치면 Lv30~37 바깥 지역 하나가 드러난다. 한 사람이 하나만 지닐 수 있다.'
    when 2 then '먹빛이 아직 바래지 않은 옛 그림. 이름을 지키려 깊이 묻은 곳간을 가리킨다. 가방에서 펼치면 Lv38~43 바깥 지역 하나가 드러난다. 한 사람이 하나만 지닐 수 있다.'
    else '봉인 먹줄로 묶여 있던 옛 그림. 가장 깊은 곳간을 가리킨다. 가방에서 펼치면 Lv44 이상 바깥 지역 하나가 드러난다. 한 사람이 하나만 지닐 수 있다.' end,
  true, (m ->> 'lv')::int, true, (array[1200, 2400, 4000])[(m ->> 'tier')::int], 1, jsonb_build_object('bijang', (m ->> 'tier')::int)
  from jsonb_array_elements(public.world_bijang_rules() -> 'maps') m
on conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, minimum_level = excluded.minimum_level,
  reference_price = excluded.reference_price, stack_size = 1, tradeable = true, equipment_traits = excluded.equipment_traits;

create table if not exists public.world_bijang_maps (
  map_id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  tier integer not null check (tier between 1 and 3),
  region_id text not null,
  status text not null default 'open' check (status in ('open', 'digging', 'done')),
  run_id uuid,
  opened_at timestamptz not null default now(),
  done_at timestamptz);
create unique index if not exists world_bijang_maps_live on public.world_bijang_maps(owner_id, tier) where status in ('open', 'digging');
create index if not exists world_bijang_maps_owner on public.world_bijang_maps(owner_id, opened_at desc);

create table if not exists public.world_bijang_runs (
  run_id uuid primary key default gen_random_uuid(),
  map_id uuid not null references public.world_bijang_maps(map_id) on delete cascade,
  leader_id uuid not null,
  picker_id uuid,
  party_id uuid not null,
  tier integer not null,
  region_id text not null,
  status text not null default 'fight' check (status in ('fight', 'room', 'end')),
  room integer not null default 0,
  door integer,
  shown integer,
  picks jsonb not null default '[]'::jsonb,
  result text,
  fight_id uuid,
  log jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  ended_at timestamptz);
create index if not exists world_bijang_runs_map on public.world_bijang_runs(map_id);
create index if not exists world_bijang_runs_leader on public.world_bijang_runs(leader_id, created_at desc);
create index if not exists world_bijang_runs_live on public.world_bijang_runs(party_id) where status <> 'end';

create table if not exists public.world_bijang_members (
  run_id uuid not null references public.world_bijang_runs(run_id) on delete cascade,
  owner_id uuid not null,
  name text,
  is_owner boolean not null default false,
  entered boolean not null default false,
  day date,
  got jsonb not null default '{}'::jsonb,
  gains jsonb not null default '[]'::jsonb,
  joined_at timestamptz not null default now(),
  primary key (run_id, owner_id));
create index if not exists world_bijang_members_owner on public.world_bijang_members(owner_id, day);

create table if not exists public.world_bijang_fights (
  fight_id uuid primary key,
  run_id uuid not null references public.world_bijang_runs(run_id) on delete cascade,
  room integer not null default 0);
create index if not exists world_bijang_fights_run on public.world_bijang_fights(run_id);

alter table public.world_bijang_maps enable row level security;
alter table public.world_bijang_runs enable row level security;
alter table public.world_bijang_members enable row level security;
alter table public.world_bijang_fights enable row level security;
revoke all on public.world_bijang_maps, public.world_bijang_runs, public.world_bijang_members, public.world_bijang_fights from anon, authenticated;
do $g$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' loop
    execute format('grant select, insert, update, delete on public.world_bijang_maps, public.world_bijang_runs, public.world_bijang_members, public.world_bijang_fights to %I', x);
  end loop;
end $g$;

create or replace function public.world_bijang_held(p_uid uuid, p_tier integer)
 returns integer
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
declare i text := public.world_bijang_map_rule(p_tier) ->> 'id';
begin
  return (select * from (select coalesce(sum(q), 0)::int from (
    select (c.inventory ->> i)::int q from public.world_characters c where c.owner_id = p_uid and c.inventory ? i
    union all select (s.items ->> i)::int from public.world_storage s where s.owner_id = p_uid and s.items ? i
    union all select v.qty from public.world_overflow_items v where v.owner_id = p_uid and v.item_id = i
    union all select t.quantity from public.world_trade_offers t where t.seller_id = p_uid and t.item_id = i and t.status = 'open'
    union all select (l.items ->> i)::int from public.world_letters l where l.recipient_id = p_uid and l.claimed_at is null and l.items ? i
    union all select (u.delivered ->> i)::int from public.world_user_commissions u where u.owner_id = p_uid and u.settled_at is null and u.delivered ? i
    union all select 1 from public.world_bijang_maps m where m.owner_id = p_uid and m.tier = p_tier and m.status in ('open', 'digging')) x where q > 0) yhq limit 1);
end $function$;
select pg_temp.yh_share('public.world_bijang_held(uuid, integer)');

create or replace function public.world_bijang_hold_check()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare who uuid; t int; hold int := (public.world_bijang_rules() ->> 'hold')::int;
begin
  who := (to_jsonb(new) ->> case tg_table_name when 'world_trade_offers' then 'seller_id' when 'world_letters' then 'recipient_id' else 'owner_id' end)::uuid;
  if who is null then return null; end if;
  for t in 1 .. 3 loop
    if public.world_bijang_held(who, t) > hold then
      raise exception '%은(는) 한 사람이 하나만 지닐 수 있습니다(가방·창고·보따리·거래소 등록·받지 않은 서신·펼친 지도를 합쳐). 이미 지닌 사람은 더 받을 수 없습니다.',
        public.world_bijang_map_rule(t) ->> 'name' using hint = 'bj_hold';
    end if;
  end loop;
  return null;
end $function$;
select pg_temp.yh_share('public.world_bijang_hold_check()');

drop trigger if exists trg_world_bj_hold_char on public.world_characters;
create constraint trigger trg_world_bj_hold_char after update of inventory on public.world_characters deferrable initially deferred for each row
  when (new.inventory ?| array['bj_map_1', 'bj_map_2', 'bj_map_3'] and (old.inventory -> 'bj_map_1' is distinct from new.inventory -> 'bj_map_1'
    or old.inventory -> 'bj_map_2' is distinct from new.inventory -> 'bj_map_2' or old.inventory -> 'bj_map_3' is distinct from new.inventory -> 'bj_map_3'))
  execute function public.world_bijang_hold_check();
drop trigger if exists trg_world_bj_hold_store on public.world_storage;
create constraint trigger trg_world_bj_hold_store after insert or update on public.world_storage deferrable initially deferred for each row
  when (new.items ?| array['bj_map_1', 'bj_map_2', 'bj_map_3']) execute function public.world_bijang_hold_check();
drop trigger if exists trg_world_bj_hold_ov on public.world_overflow_items;
create constraint trigger trg_world_bj_hold_ov after insert or update on public.world_overflow_items deferrable initially deferred for each row
  when (new.item_id in ('bj_map_1', 'bj_map_2', 'bj_map_3')) execute function public.world_bijang_hold_check();
drop trigger if exists trg_world_bj_hold_offer on public.world_trade_offers;
create constraint trigger trg_world_bj_hold_offer after insert or update on public.world_trade_offers deferrable initially deferred for each row
  when (new.item_id in ('bj_map_1', 'bj_map_2', 'bj_map_3') and new.status = 'open') execute function public.world_bijang_hold_check();
drop trigger if exists trg_world_bj_hold_letter on public.world_letters;
create constraint trigger trg_world_bj_hold_letter after insert on public.world_letters deferrable initially deferred for each row
  when (new.items ?| array['bj_map_1', 'bj_map_2', 'bj_map_3']) execute function public.world_bijang_hold_check();
drop trigger if exists trg_world_bj_hold_ucomm on public.world_user_commissions;
create constraint trigger trg_world_bj_hold_ucomm after update on public.world_user_commissions deferrable initially deferred for each row
  when (new.delivered ?| array['bj_map_1', 'bj_map_2', 'bj_map_3'] and new.settled_at is null) execute function public.world_bijang_hold_check();
drop trigger if exists trg_world_bj_hold_map on public.world_bijang_maps;
create constraint trigger trg_world_bj_hold_map after insert on public.world_bijang_maps deferrable initially deferred for each row
  execute function public.world_bijang_hold_check();

create or replace function public.world_bijang_grant(p_uid uuid, p_tier integer)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare c public.world_characters%rowtype; m jsonb := public.world_bijang_map_rule(p_tier); i text;
begin
  if p_uid is null or m is null then return false; end if;
  i := m ->> 'id';
  if not exists (select 1 from public.world_item_catalog where item_id = i) then return false; end if;
  select * into c from public.world_characters where owner_id = p_uid for update;
  if not found or coalesce(c.is_dead, false) then return false; end if;
  if public.world_bijang_held(p_uid, p_tier) >= (public.world_bijang_rules() ->> 'hold')::int then return false; end if;
  if public.world_bag_room(c.inventory, i, public.world_bag_limit(p_uid)) >= 1 then
    update public.world_characters set inventory = public.world_inv_add(inventory, i, 1), updated_at = now() where owner_id = p_uid;
  else
    perform public.world_letter_spill(p_uid, jsonb_build_object(i, 1));
  end if;
  return true;
end $function$;
select pg_temp.yh_share('public.world_bijang_grant(uuid, integer)');

create or replace function public.world_bijang_entries_left(p_uid uuid)
 returns integer
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
begin
  return (select * from (select greatest(0, (public.world_bijang_rules() ->> 'entry_day')::int - count(*)::int) from public.world_bijang_members m
    where m.owner_id = p_uid and m.entered and m.day = (now() at time zone 'Asia/Seoul')::date) yhq limit 1);
end $function$;
select pg_temp.yh_share('public.world_bijang_entries_left(uuid)');

create or replace function public.world_bijang_brief(p_uid uuid)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
begin
  return (select * from (select case when exists (select 1 from public.world_bijang_maps x where x.owner_id = p_uid and x.status in ('open', 'digging'))
      or exists (select 1 from public.world_bijang_members y join public.world_bijang_runs r on r.run_id = y.run_id where y.owner_id = p_uid and r.status <> 'end')
    then jsonb_build_object(
    'maps', (select coalesce(jsonb_agg(jsonb_build_object('map_id', m.map_id, 'tier', m.tier, 'name', public.world_bijang_map_rule(m.tier) ->> 'name', 'region_id', m.region_id,
        'region_name', g.region_name, 'status', m.status, 'run_id', m.run_id) order by m.tier), '[]'::jsonb)
      from public.world_bijang_maps m join public.world_map_regions g on g.region_id = m.region_id where m.owner_id = p_uid and m.status in ('open', 'digging')),
    'entries_left', public.world_bijang_entries_left(p_uid)) end) yhq limit 1);
end $function$;
select pg_temp.yh_share('public.world_bijang_brief(uuid)');

create or replace function public.world_bijang_say(p_run uuid, p_lines jsonb)
 returns void
 language sql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  update public.world_bijang_runs set updated_at = now(),
    log = (select coalesce(jsonb_agg(x order by o), '[]'::jsonb) from (select x, o from jsonb_array_elements(log || p_lines) with ordinality t(x, o) order by o desc limit 80) s)
   where run_id = p_run
$function$;
select pg_temp.yh_share('public.world_bijang_say(uuid, jsonb)');

create or replace function public.world_bijang_give(p_run uuid, p_uid uuid, p_gil integer, p_items jsonb)
 returns text
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare c public.world_characters%rowtype; inv jsonb; lim int; k text; v int; names text[] := '{}'; st jsonb := '{}'::jsonb; gain jsonb := '{}'::jsonb; nm text;
begin
  select * into c from public.world_characters where owner_id = p_uid for update;
  if not found then return ''; end if;
  inv := coalesce(c.inventory, '{}'::jsonb); lim := public.world_bag_limit(p_uid);
  for k, v in select key, value::int from jsonb_each_text(coalesce(p_items, '{}'::jsonb)) loop
    select item_name into nm from public.world_item_catalog where item_id = k;
    if nm is null or v < 1 then continue; end if;
    if public.world_bag_room(inv, k, lim) >= v then inv := public.world_inv_add(inv, k, v);
    else st := public.world_inv_add(st, k, v); end if;
    gain := public.world_inv_add(gain, k, v);
    names := names || (nm || ' ×' || v);
  end loop;
  update public.world_characters set inventory = inv, gil = gil + greatest(0, coalesce(p_gil, 0)), updated_at = now() where owner_id = p_uid;
  perform public.world_letter_spill(p_uid, st);
  update public.world_bijang_members m set gains = m.gains || jsonb_build_array(jsonb_build_object('n', jsonb_array_length(m.gains) + 1,
      'room', (select x.room from public.world_bijang_runs x where x.run_id = p_run), 'gil', greatest(0, coalesce(p_gil, 0)), 'items', gain, 'stored', st <> '{}'::jsonb)),
    got = jsonb_build_object('gil', coalesce((m.got ->> 'gil')::int, 0) + greatest(0, coalesce(p_gil, 0)),
      'items', (select coalesce(jsonb_object_agg(x.key, x.v), '{}'::jsonb) from (select key, sum(value::int) v from (select * from jsonb_each_text(coalesce(m.got -> 'items', '{}'::jsonb)) union all select * from jsonb_each_text(gain)) u group by key) x))
   where m.run_id = p_run and m.owner_id = p_uid;
  if coalesce(p_gil, 0) > 0 then names := (p_gil || '전') || names; end if;
  return array_to_string(names, ' · ') || case when st <> '{}'::jsonb then '(가방이 차서 일부는 개인 창고로)' else '' end;
end $function$;
select pg_temp.yh_share('public.world_bijang_give(uuid, uuid, integer, jsonb)');

create or replace function public.world_bijang_chest(p_run uuid, p_uid uuid)
 returns text
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r public.world_bijang_runs%rowtype; ru jsonb := public.world_bijang_rules(); ch jsonb; e jsonb; items jsonb := '{}'::jsonb; g int; lo int; hi int;
begin
  select * into r from public.world_bijang_runs where run_id = p_run;
  ch := ru -> 'chest' -> r.tier::text;
  lo := (ch -> 'gil' ->> 0)::int; hi := (ch -> 'gil' ->> 1)::int;
  g := lo + floor(random() * (hi - lo + 1))::int;
  select x into e from jsonb_array_elements(ch -> 'items') x
   where exists (select 1 from public.world_item_catalog i where i.item_id = x ->> 'id')
   order by -ln(greatest(random(), 1e-9)) / greatest((x ->> 'w')::numeric, 0.01) limit 1;
  if e is not null then
    items := jsonb_build_object(e ->> 'id', (ch -> 'n' ->> 0)::int + floor(random() * ((ch -> 'n' ->> 1)::int - (ch -> 'n' ->> 0)::int + 1))::int);
  end if;
  if random() * 100 < (ru -> 'egg' -> 'pct' ->> (r.tier - 1))::numeric and exists (select 1 from public.world_item_catalog where item_id = ru -> 'egg' ->> 'id') then
    items := public.world_inv_add(items, ru -> 'egg' ->> 'id', 1);
  end if;
  return public.world_bijang_give(p_run, p_uid, g, items);
end $function$;
select pg_temp.yh_share('public.world_bijang_chest(uuid, uuid)');

create or replace function public.world_bijang_final_give(p_run uuid, p_uid uuid)
 returns text
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r public.world_bijang_runs%rowtype; f jsonb := public.world_bijang_rules() -> 'final'; e jsonb; items jsonb := '{}'::jsonb; pets text[] := '{}'; pet_ids text[] := '{}'; out text; nm text;
begin
  select * into r from public.world_bijang_runs where run_id = p_run;
  for e in select x from jsonb_array_elements(coalesce(f -> 'items', '[]'::jsonb)) x
            where (x ? 'id' and exists (select 1 from public.world_item_catalog i where i.item_id = x ->> 'id'))
               or (x ? 'pet' and exists (select 1 from public.world_pet_species s where s.pet_id = x ->> 'pet'))
            order by -ln(greatest(random(), 1e-9)) / greatest(coalesce((x ->> 'w')::numeric, 1), 0.01)
            limit greatest(0, coalesce((f -> 'picks' ->> (r.tier - 1))::int, 1)) loop
    if e ? 'pet' then
      perform public.world_pet_grant(p_uid, e ->> 'pet', 'bijang');
      select pet_name into nm from public.world_pet_species where pet_id = e ->> 'pet';
      pets := pets || ('꼬마 동무 ' || nm); pet_ids := pet_ids || (e ->> 'pet');
    else items := public.world_inv_add(items, e ->> 'id', greatest(1, coalesce((e ->> 'n')::int, 1))); end if;
  end loop;
  out := public.world_bijang_give(p_run, p_uid, coalesce((f -> 'gil' ->> (r.tier - 1))::int, 0), items);
  update public.world_bijang_members m set gains = jsonb_set(m.gains, array[(jsonb_array_length(m.gains) - 1)::text],
      (m.gains -> (jsonb_array_length(m.gains) - 1)) || jsonb_build_object('final', true, 'pets', to_jsonb(coalesce(pet_ids, '{}'::text[]))))
   where m.run_id = p_run and m.owner_id = p_uid and jsonb_array_length(m.gains) > 0;
  return array_to_string(array_remove(array[nullif(out, '')] || pets, null), ' · ');
end $function$;
select pg_temp.yh_share('public.world_bijang_final_give(uuid, uuid)');

create or replace function public.world_bijang_encounter(p_uid uuid, p_region text, p_tier integer, p_rank text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare c public.world_characters%rowtype; m public.world_region_monsters%rowtype; g jsonb := public.world_bijang_rules() -> 'guard'; lv int; hp int; v_atk int; df int;
  hpm numeric; atm numeric; v_intent text; rg int;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  select min_level into rg from public.world_map_regions where region_id = p_region;
  select * into m from public.world_region_monsters where region_id = p_region and role = case when p_rank = 'guardian' then 'guardian' else role end
   order by (role = 'guardian') desc, random() limit 1;
  if p_rank <> 'guardian' then select * into m from public.world_region_monsters where region_id = p_region and role in ('common', 'main') order by random() limit 1; end if;
  if m.monster_id is null then select * into m from public.world_region_monsters where region_id = p_region order by random() limit 1; end if;
  if m.monster_id is null then return null; end if;
  lv := least(46, greatest(coalesce(rg, 1), (public.world_bijang_map_rule(p_tier) ->> 'lv')::int) + (g ->> 'lv_up')::int);
  lv := greatest(1, least(lv, c.level + 6));
  if p_rank = 'guardian' then hpm := 2.6; atm := 1.4; else hpm := 1.6; atm := 1.25; end if;
  hp := round((70 + lv * 14) * hpm * (g ->> 'hp_mul')::numeric);
  v_atk := round((8 + lv * 1.1) * atm * (g ->> 'atk_mul')::numeric);
  df := round(lv * 0.6 * case when m.mechanic_key = 'armored' then 2 else 1 end);
  v_intent := case when m.mechanic_key = 'ambush' then 'strike' else public.world_battle_intent_k(m.kind, lv, m.mechanic_key, 1, p_rank) end;
  insert into public.world_active_encounters(owner_id, region_id, monster_id, current_hp, max_hp, defeated, fled, started_at, updated_at,
    turn_count, analysis_turns, guard_until_turn, node_id, mlevel, atk, def, rank, intent, fx, pfx, log, last_action_at, result)
  values (p_uid, p_region, m.monster_id, hp, hp, false, false, now(), now(), 0, 0, 0, null, lv, v_atk, df, p_rank, v_intent, '{}', '{}',
    jsonb_build_array('비장고를 지키던 ' || m.monster_name || '이(가) 흙 속에서 일어났다.'), now() - interval '1 second', null)
  on conflict (owner_id) do update set region_id = excluded.region_id, monster_id = excluded.monster_id, current_hp = excluded.current_hp,
    max_hp = excluded.max_hp, defeated = false, fled = false, started_at = now(), updated_at = now(), turn_count = 0, analysis_turns = 0,
    guard_until_turn = 0, node_id = null, mlevel = excluded.mlevel, atk = excluded.atk, def = excluded.def, rank = excluded.rank,
    intent = excluded.intent, fx = '{}', pfx = '{}', log = excluded.log, last_action_at = excluded.last_action_at, result = null;
  return jsonb_build_object('monster_id', m.monster_id, 'name', m.monster_name, 'level', lv, 'hp', hp, 'rank', p_rank);
end $function$;
select pg_temp.yh_share('public.world_bijang_encounter(uuid, text, integer, text)');

create or replace function public.world_bijang_spawn(p_run uuid, p_room integer, p_leader uuid, p_mates uuid[], p_gather boolean)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r public.world_bijang_runs%rowtype; e jsonb; fid uuid; nm text; u uuid; ok int := 0;
  oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true);
begin
  select * into r from public.world_bijang_runs where run_id = p_run;
  select character_name into nm from public.world_characters where owner_id = p_leader;
  e := public.world_bijang_encounter(p_leader, r.region_id, r.tier, case when p_room = 0 then 'guardian' else public.world_bijang_rules() -> 'guard' ->> 'room_rank' end);
  if e is null then return null; end if;
  insert into public.world_pfights(party_id, region_id, leader_id, monster_id, monster_name, rank, mlevel, base_hp, max_hp, hp, intent, fx, gather_ends, log)
  select r.party_id, r.region_id, p_leader, a.monster_id, e ->> 'name', a.rank, a.mlevel, a.max_hp, a.max_hp, a.current_hp, a.intent, '{}'::jsonb,
         now() + make_interval(secs => (public.world_bijang_rules() ->> 'gather_s')::int),
         jsonb_build_array(case when p_room = 0 then nm || '이(가) 비장도를 따라 흙을 파자 ' || (e ->> 'name') || '이(가) 일어났다.'
                                else (e ->> 'name') || '이(가) ' || p_room || '번 방을 지키고 있다.' end)
    from public.world_active_encounters a where a.owner_id = p_leader
  returning fight_id into fid;
  insert into public.world_pfight_members(fight_id, owner_id, name) values (fid, p_leader, nm);
  insert into public.world_bijang_fights(fight_id, run_id, room) values (fid, p_run, p_room);
  update public.world_bijang_runs set status = 'fight', fight_id = fid, updated_at = now() where run_id = p_run;
  if p_gather then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    select m.owner_id, 'pfight_invite', '비장고 파수꾼', nm || '이(가) 비장도를 따라 판 자리에서 ' || (e ->> 'name') || '이(가) 일어났습니다. 60초 안에 합류하면 비장고 보상을 함께 받습니다(탐색력 1).',
           jsonb_build_object('fight_id', fid, 'region_id', r.region_id, 'bijang', p_run)
      from public.world_party_members m where m.party_id = r.party_id and m.owner_id <> p_leader and public.world_pfight_ready(m.owner_id, r.region_id);
    get diagnostics ok = row_count;
    if ok = 0 then perform public.world_pfight_start(fid, true); end if;
  else
    foreach u in array coalesce(p_mates, '{}') loop
      if u = p_leader or not public.world_pfight_ready(u, r.region_id) then continue; end if;
      perform set_config('request.jwt.claim.sub', u::text, true);
      perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
      begin perform public.world_pfight_join(fid); exception when others then null; end;
    end loop;
    perform set_config('request.jwt.claims', coalesce(oc, ''), true);
    perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
    perform public.world_pfight_start(fid, true);
  end if;
  return fid;
end $function$;
select pg_temp.yh_share('public.world_bijang_spawn(uuid, integer, uuid, uuid[], boolean)');

create or replace function public.world_bijang_here(p_uid uuid, p_region text)
 returns boolean
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select exists (select 1 from public.world_characters c where c.owner_id = p_uid and not coalesce(c.is_dead, false)
    and c.travel_destination is null and (public.world_field_region(c.location)).region_id = p_region)
    and not exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active')
    and not exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = 'active')
$function$;
select pg_temp.yh_share('public.world_bijang_here(uuid, text)');

create or replace function public.world_bijang_room_open(p_run uuid, p_room integer)
 returns void
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare d int := 1 + floor(random() * 3)::int; rv numeric := coalesce((public.world_bijang_rules() -> 'reveal_pct' ->> (p_room - 1))::numeric, 0);
  sh int := case when random() * 100 < rv then d end;
begin
  update public.world_bijang_runs set status = 'room', room = p_room, door = d, shown = sh, fight_id = null, updated_at = now() where run_id = p_run;
  perform public.world_bijang_say(p_run, jsonb_build_array(p_room || '번 방 · 문 셋이 나란히 서 있다.'
    || case when sh is not null then ' 그중 ' || sh || '번 문틈으로 먹빛 이름 한 줄이 비친다.' else '' end));
end $function$;
select pg_temp.yh_share('public.world_bijang_room_open(uuid, integer)');

create or replace function public.world_bijang_finish(p_run uuid, p_result text, p_line text)
 returns void
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r public.world_bijang_runs%rowtype; m record;
begin
  select * into r from public.world_bijang_runs where run_id = p_run;
  update public.world_bijang_runs set status = 'end', result = p_result, fight_id = null, ended_at = now(), updated_at = now() where run_id = p_run;
  if p_result = 'lost' and r.room = 0 then
    update public.world_bijang_maps set status = 'open', run_id = null where map_id = r.map_id;
  else
    update public.world_bijang_maps set status = 'done', done_at = now() where map_id = r.map_id;
  end if;
  perform public.world_bijang_say(p_run, jsonb_build_array(p_line));
  for m in select * from public.world_bijang_members where run_id = p_run loop
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (m.owner_id, 'bijang', '비장고 · ' || (public.world_bijang_map_rule(r.tier) ->> 'name'), p_line
      || case when coalesce((m.got ->> 'gil')::int, 0) > 0 or coalesce(m.got -> 'items', '{}'::jsonb) <> '{}'::jsonb then ' 얻은 것은 비장고 화면에서 볼 수 있습니다.' else '' end,
      jsonb_build_object('run_id', p_run, 'result', p_result));
  end loop;
end $function$;
select pg_temp.yh_share('public.world_bijang_finish(uuid, text, text)');

create or replace function public.world_bijang_final(p_run uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r public.world_bijang_runs%rowtype; m record; lines jsonb := '[]'::jsonb; t text;
begin
  select * into r from public.world_bijang_runs where run_id = p_run;
  for m in select * from public.world_bijang_members where run_id = p_run and entered order by joined_at loop
    if not public.world_bijang_here(m.owner_id, r.region_id) then continue; end if;
    t := public.world_bijang_final_give(p_run, m.owner_id);
    lines := lines || jsonb_build_array(m.name || ' · 마지막 방 · ' || t);
    if not exists (select 1 from public.world_character_statuses s where s.owner_id = m.owner_id and s.status_key = 'yohwa_seal' and s.expires_at > now()) then
      insert into public.world_events(actor_id, actor_name, event_type, content, payload)
      values (m.owner_id, m.name, 'bj_final', m.name || '이(가) 비장고 마지막 방에 닿았습니다.', jsonb_build_object('tier', r.tier, 'run_id', p_run, 'region_id', r.region_id));
    end if;
  end loop;
  perform public.world_bijang_say(p_run, jsonb_build_array('마지막 방 · 이름을 적은 함과 재물이 고스란히 남아 있었다.') || lines);
  perform public.world_bijang_finish(p_run, 'final', '비장고 마지막 방에 닿았다.');
end $function$;
select pg_temp.yh_share('public.world_bijang_final(uuid)');

create or replace function public.world_bijang_advance(p_run uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r public.world_bijang_runs%rowtype; f public.world_pfights%rowtype; ru jsonb := public.world_bijang_rules(); m record; lines jsonb := '[]'::jsonb; t text;
  today date := (now() at time zone 'Asia/Seoul')::date; n_in int := 0;
begin
  select * into r from public.world_bijang_runs where run_id = p_run for update;
  if not found or r.status <> 'fight' or r.fight_id is null then return; end if;
  select * into f from public.world_pfights where fight_id = r.fight_id;
  if not found then perform public.world_bijang_finish(p_run, 'lost', '파수꾼과의 싸움이 사라져 비장고가 다시 흙에 묻혔다.'); return; end if;
  if f.status in ('gather', 'fight') then return; end if;
  if f.status <> 'won' then
    perform public.world_bijang_finish(p_run, 'lost', case when r.room = 0 then '파수꾼에게 밀려 물러났다. 비장도는 그대로 남아 다시 파 볼 수 있다.' else '방을 지키던 파수꾼에게 밀려 비장고를 빠져나왔다. 얻은 것은 그대로 가졌다.' end);
    return;
  end if;
  if r.room = 0 then
    insert into public.world_bijang_members(run_id, owner_id, name, is_owner)
    select p_run, pm.owner_id, pm.name, pm.owner_id = r.leader_id from public.world_pfight_members pm
     where pm.fight_id = f.fight_id and pm.out_reason in ('won', 'down') on conflict do nothing;
    for m in select * from public.world_bijang_members where run_id = p_run order by joined_at loop
      if not public.world_bijang_here(m.owner_id, r.region_id) then continue; end if;
      t := public.world_bijang_chest(p_run, m.owner_id);
      lines := lines || jsonb_build_array(m.name || ' · 묻힌 상자 · ' || t);
    end loop;
    perform public.world_bijang_say(p_run, lines);
    if random() * 100 >= (ru -> 'door_pct' ->> (r.tier - 1))::numeric then
      perform public.world_bijang_finish(p_run, 'nodoor', '상자 밑을 더 파 보았지만 숨은 문은 없었다.');
      return;
    end if;
    lines := '[]'::jsonb;
    for m in select * from public.world_bijang_members where run_id = p_run order by is_owner desc, joined_at loop
      perform pg_advisory_xact_lock(hashtext('yh-bijang-entry'), hashtext(m.owner_id::text));
      if public.world_bijang_here(m.owner_id, r.region_id) and public.world_bijang_entries_left(m.owner_id) > 0 then
        update public.world_bijang_members set entered = true, day = today where run_id = p_run and owner_id = m.owner_id;
        n_in := n_in + 1;
      else
        lines := lines || jsonb_build_array(m.name || ' · 오늘은 비장고에 더 들어갈 수 없다(하루 ' || (ru ->> 'entry_day') || '번).');
      end if;
    end loop;
    perform public.world_bijang_say(p_run, jsonb_build_array('상자 밑에서 숨은 문이 드러났다.') || lines);
    if n_in = 0 then
      perform public.world_bijang_finish(p_run, 'full', '숨은 문을 찾았지만 오늘은 아무도 들어갈 수 없어 문을 다시 덮었다.');
      return;
    end if;
    update public.world_bijang_runs set picker_id = coalesce((select owner_id from public.world_bijang_members where run_id = p_run and entered order by is_owner desc, joined_at limit 1), leader_id)
     where run_id = p_run;
    perform public.world_bijang_room_open(p_run, 1);
  else
    if r.room >= (ru ->> 'rooms')::int then perform public.world_bijang_final(p_run); return; end if;
    for m in select * from public.world_bijang_members where run_id = p_run and entered order by joined_at loop
      if not public.world_bijang_here(m.owner_id, r.region_id) then continue; end if;
      lines := lines || jsonb_build_array(m.name || ' · 방의 상자 · ' || public.world_bijang_chest(p_run, m.owner_id));
    end loop;
    perform public.world_bijang_say(p_run, jsonb_build_array('파수꾼이 쓰러지고 방 안쪽 상자가 드러났다.') || lines);
    perform public.world_bijang_room_open(p_run, r.room);
  end if;
end $function$;
select pg_temp.yh_share('public.world_bijang_advance(uuid)');

create or replace function public.world_bijang_open(p_item text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; t int := public.world_bijang_tier_of(p_item); mr jsonb; rg public.world_map_regions%rowtype; mid uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_travel_guard('비장도 펼치기');
  perform public.world_seal_guard();
  if t is null then raise exception '비장도가 아닙니다.'; end if;
  mr := public.world_bijang_map_rule(t);
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null then raise exception '전투불능 상태에서는 비장도를 펼칠 수 없습니다.'; end if;
  if coalesce((c.inventory ->> p_item)::int, 0) < 1 then raise exception '가방에 %이(가) 없습니다.', mr ->> 'name'; end if;
  if c.level < (mr ->> 'lv')::int then raise exception '%은(는) Lv.%부터 알아볼 수 있습니다.', mr ->> 'name', mr ->> 'lv'; end if;
  if exists (select 1 from public.world_bijang_maps where owner_id = uid and tier = t and status in ('open', 'digging')) then
    raise exception '이미 펼친 %이(가) 있습니다. 그 자리를 먼저 파 보세요.', mr ->> 'name'; end if;
  select * into rg from public.world_map_regions r where r.active and not r.is_safe_zone and r.min_level between (mr ->> 'lo')::int and (mr ->> 'hi')::int
     and public.world_domain_open(uid, r.territory_id) and exists (select 1 from public.world_region_monsters x where x.region_id = r.region_id)
   order by random() limit 1;
  if rg.region_id is null then raise exception '이 그림이 가리키는 땅을 아직 알아볼 수 없습니다. 더 깊은 곳이 열린 뒤 펼치세요.'; end if;
  update public.world_characters set inventory = case when (inventory ->> p_item)::int <= 1 then inventory - p_item else public.world_inv_add(inventory, p_item, -1) end, updated_at = now()
   where owner_id = uid;
  insert into public.world_bijang_maps(owner_id, tier, region_id) values (uid, t, rg.region_id) returning map_id into mid;
  return jsonb_build_object('ok', true, 'map_id', mid, 'tier', t, 'region_id', rg.region_id, 'region_name', rg.region_name,
    'content', (mr ->> 'name') || '을(를) 펼쳤습니다. 옛 그림이 「' || rg.region_name || '」의 어느 자리를 가리킵니다. 그 지역에서 「비장도 따라 파기」를 하세요(지도에 표시).');
end $function$;
revoke all on function public.world_bijang_open(text) from public, anon;
grant execute on function public.world_bijang_open(text) to authenticated, service_role;
select pg_temp.yh_own('public.world_bijang_open(text)', 'fn_owner_field');

create or replace function public.world_bijang_dig()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rg public.world_map_regions%rowtype; mp public.world_bijang_maps%rowtype; mr jsonb;
  pid uuid; rid uuid; fid uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_travel_guard('비장도 따라 파기');
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  rg := public.world_field_region(c.location);
  select * into mp from public.world_bijang_maps where owner_id = uid and status = 'open' and region_id = rg.region_id order by tier desc limit 1 for update;
  if not found then raise exception '이 지역을 가리키는 펼친 비장도가 없습니다.'; end if;
  mr := public.world_bijang_map_rule(mp.tier);
  if rg.is_safe_zone then raise exception '안전지대에서는 팔 수 없습니다.'; end if;
  if c.level < (mr ->> 'lv')::int then raise exception '%은(는) Lv.%부터 따라 팔 수 있습니다.', mr ->> 'name', mr ->> 'lv'; end if;
  if exists (select 1 from public.world_bijang_members m join public.world_bijang_runs r on r.run_id = m.run_id where m.owner_id = uid and r.status <> 'end')
     or exists (select 1 from public.world_bijang_runs r where r.leader_id = uid and r.status <> 'end') then
    raise exception '이미 비장고를 도는 중입니다.'; end if;
  if not public.world_pfight_ready(uid, rg.region_id) then
    raise exception '지금은 팔 수 없습니다(전투·원정·이동·자율 중이거나 쓰러져 있으면 안 됩니다).'; end if;
  perform public.world_stamina_change(uid, -(public.world_bijang_rules() ->> 'stamina')::int);
  select party_id into pid from public.world_party_members where owner_id = uid;
  insert into public.world_bijang_runs(map_id, leader_id, party_id, tier, region_id)
  values (mp.map_id, uid, coalesce(pid, uid), mp.tier, rg.region_id) returning run_id into rid;
  update public.world_bijang_maps set status = 'digging', run_id = rid where map_id = mp.map_id;
  fid := public.world_bijang_spawn(rid, 0, uid, null, true);
  if fid is null then raise exception '이 지역에서는 파수꾼이 일어나지 않습니다.'; end if;
  perform public.world_bijang_say(rid, jsonb_build_array(c.character_name || '이(가) ' || (mr ->> 'name') || '을(를) 따라 ' || rg.region_name || '의 흙을 팠다.'));
  return jsonb_build_object('ok', true, 'run_id', rid, 'fight_id', fid,
    'content', case when pid is null then '흙 속에서 파수꾼이 일어났습니다.' else '흙 속에서 파수꾼이 일어났습니다. 같은 곳의 파티원은 60초 안에 합류할 수 있습니다.' end);
end $function$;
revoke all on function public.world_bijang_dig() from public, anon;
grant execute on function public.world_bijang_dig() to authenticated, service_role;
select pg_temp.yh_own('public.world_bijang_dig()', 'fn_owner_field');

create or replace function public.world_bijang_snapshot(p_run uuid default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r public.world_bijang_runs%rowtype; f public.world_pfights%rowtype; me public.world_bijang_members%rowtype; ru jsonb := public.world_bijang_rules();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_run is null then
    select x.run_id into p_run from public.world_bijang_runs x
     where (x.leader_id = uid or exists (select 1 from public.world_bijang_members y where y.run_id = x.run_id and y.owner_id = uid))
       and (x.status <> 'end' or x.ended_at > now() - interval '30 minutes')
     order by (x.status <> 'end') desc, x.created_at desc limit 1;
    if p_run is null then return null; end if;
  end if;
  select * into r from public.world_bijang_runs where run_id = p_run;
  if not found then raise exception '없는 비장고입니다.'; end if;
  if r.leader_id <> uid and not exists (select 1 from public.world_bijang_members where run_id = p_run and owner_id = uid)
     and not exists (select 1 from public.world_party_members where party_id = r.party_id and owner_id = uid) then
    raise exception '함께 간 사람만 볼 수 있습니다.'; end if;
  if r.status = 'fight' then
    if r.fight_id is not null then
      select * into f from public.world_pfights where fight_id = r.fight_id;
      if f.status = 'gather' and now() >= f.gather_ends then perform public.world_pfight_start(r.fight_id); end if;
      perform public.world_pfight_resolve(r.fight_id);
    end if;
    perform public.world_bijang_advance(p_run);
    select * into r from public.world_bijang_runs where run_id = p_run;
  end if;
  select * into f from public.world_pfights where fight_id = r.fight_id;
  select * into me from public.world_bijang_members where run_id = p_run and owner_id = uid;
  return jsonb_build_object('run_id', r.run_id, 'tier', r.tier, 'name', public.world_bijang_map_rule(r.tier) ->> 'name', 'region_id', r.region_id,
    'region_name', (select region_name from public.world_map_regions where region_id = r.region_id), 'status', r.status, 'result', r.result,
    'room', r.room, 'rooms', (ru ->> 'rooms')::int, 'shown', r.shown, 'picks', r.picks, 'leader_id', r.leader_id, 'picker_id', r.picker_id,
    'fight', case when f.fight_id is not null then jsonb_build_object('id', f.fight_id, 'status', f.status, 'monster', f.monster_name, 'hp', f.hp, 'max_hp', f.max_hp,
      'mine', exists (select 1 from public.world_pfight_members pm where pm.fight_id = f.fight_id and pm.owner_id = uid and pm.out_reason is null),
      'can_join', f.status in ('gather', 'fight') and now() <= f.gather_ends and not exists (select 1 from public.world_pfight_members pm where pm.fight_id = f.fight_id and pm.owner_id = uid)
        and public.world_pfight_ready(uid, f.region_id)) end,
    'me', jsonb_build_object('id', uid, 'member', me.owner_id is not null, 'entered', coalesce(me.entered, false), 'can_pick', r.status = 'room' and r.picker_id = uid,
      'entries_left', public.world_bijang_entries_left(uid), 'entry_day', (ru ->> 'entry_day')::int, 'gains', coalesce(me.gains, '[]'::jsonb)),
    'members', (select coalesce(jsonb_agg(jsonb_build_object('id', m.owner_id, 'name', m.name, 'job', c.job_key, 'hp', c.health, 'owner', m.is_owner, 'entered', m.entered,
        'here', public.world_bijang_here(m.owner_id, r.region_id), 'got', m.got) order by m.is_owner desc, m.joined_at), '[]'::jsonb)
      from public.world_bijang_members m join public.world_characters c on c.owner_id = m.owner_id where m.run_id = p_run),
    'names', (select coalesce(jsonb_object_agg(i.item_id, i.item_name), '{}'::jsonb) from public.world_item_catalog i
      where exists (select 1 from public.world_bijang_members m, jsonb_object_keys(coalesce(m.got -> 'items', '{}'::jsonb)) k where m.run_id = p_run and k = i.item_id)),
    'log', r.log, 'now', now());
end $function$;
revoke all on function public.world_bijang_snapshot(uuid) from public, anon;
grant execute on function public.world_bijang_snapshot(uuid) to authenticated, service_role;
select pg_temp.yh_own('public.world_bijang_snapshot(uuid)', 'fn_owner_field');

create or replace function public.world_bijang_pick(p_run uuid, p_door integer)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r public.world_bijang_runs%rowtype; ru jsonb := public.world_bijang_rules(); k int; m record; lines jsonb := '[]'::jsonb; t text;
  mates uuid[]; lead uuid; fid uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_travel_guard('비장고 문 고르기');
  perform public.world_seal_guard();
  if p_door is null or p_door not between 1 and 3 then raise exception '문은 셋 가운데 하나를 고르세요.'; end if;
  select * into r from public.world_bijang_runs where run_id = p_run for update;
  if not found then raise exception '없는 비장고입니다.'; end if;
  if r.status <> 'room' then raise exception '지금은 문을 고를 때가 아닙니다.'; end if;
  if r.picker_id is distinct from uid then raise exception '문은 비장도를 펼친 사람(길잡이)이 고릅니다.'; end if;
  if not public.world_bijang_here(uid, r.region_id) then raise exception '비장고가 있는 지역에 있어야 문을 고를 수 있습니다.'; end if;
  update public.world_bijang_runs set picks = picks || jsonb_build_array(jsonb_build_object('room', r.room, 'door', p_door, 'ok', p_door = r.door)), updated_at = now() where run_id = p_run;
  if p_door <> r.door then
    perform public.world_bijang_say(p_run, jsonb_build_array(r.room || '번 방 · ' || p_door || '번 문을 열자 흙이 무너져 내렸다. 맞는 문은 ' || r.door || '번이었다.'));
    perform public.world_bijang_finish(p_run, 'wrong', '문을 잘못 골라 비장고가 무너졌다. 얻은 것은 그대로 가지고 나왔다.');
    return public.world_bijang_snapshot(p_run);
  end if;
  k := r.room + 1;
  perform public.world_bijang_say(p_run, jsonb_build_array(r.room || '번 방 · ' || p_door || '번 문이 열렸다.'));
  if random() * 100 < (ru ->> 'room_guard_pct')::numeric then
    select array_agg(owner_id order by joined_at) into mates from public.world_bijang_members where run_id = p_run and entered;
    lead := case when public.world_pfight_ready(uid, r.region_id) then uid
      else (select x from unnest(mates) x where public.world_pfight_ready(x, r.region_id) limit 1) end;
    if lead is not null then
      update public.world_bijang_runs set room = k, door = null, shown = null where run_id = p_run;
      fid := public.world_bijang_spawn(p_run, k, lead, mates, false);
      if fid is not null then
        perform public.world_bijang_say(p_run, jsonb_build_array(case when k >= (ru ->> 'rooms')::int then '마지막 방 · 이름 함을 지키던 파수꾼이 일어섰다.' else k || '번 방 · 파수꾼이 길을 막았다.' end));
        return public.world_bijang_snapshot(p_run);
      end if;
    end if;
  end if;
  if k >= (ru ->> 'rooms')::int then perform public.world_bijang_final(p_run); return public.world_bijang_snapshot(p_run); end if;
  for m in select * from public.world_bijang_members where run_id = p_run and entered order by joined_at loop
    if not public.world_bijang_here(m.owner_id, r.region_id) then continue; end if;
    lines := lines || jsonb_build_array(m.name || ' · 방의 상자 · ' || public.world_bijang_chest(p_run, m.owner_id));
  end loop;
  perform public.world_bijang_say(p_run, lines);
  perform public.world_bijang_room_open(p_run, k);
  return public.world_bijang_snapshot(p_run);
end $function$;
revoke all on function public.world_bijang_pick(uuid, integer) from public, anon;
grant execute on function public.world_bijang_pick(uuid, integer) to authenticated, service_role;
select pg_temp.yh_own('public.world_bijang_pick(uuid, integer)', 'fn_owner_field');

select pg_temp.yh_fix('world_pfight_start(uuid,boolean)', array[
  $$  if n < 2 then$$,
  $$  if n < 2 and not exists (select 1 from public.world_bijang_fights b where b.fight_id = p_fight) then$$]);

select pg_temp.yh_fix('world_pfight_snapshot(uuid)', array[
  $$'log', f.log, 'result', f.result, 'region_id', f.region_id,$$,
  $$'log', f.log, 'result', f.result, 'region_id', f.region_id, 'bijang', (select b.run_id from public.world_bijang_fights b where b.fight_id = f.fight_id),$$]);

select pg_temp.yh_fix('world_my_fight(uuid)', array[
  $$      where m.owner_id = p_uid and m.out_reason is null and f.status in ('gather', 'fight') limit 1))$$,
  $$      where m.owner_id = p_uid and m.out_reason is null and f.status in ('gather', 'fight') limit 1),
    (select jsonb_build_object('kind', 'bijang', 'id', x.run_id, 'name', public.world_bijang_map_rule(x.tier) ->> 'name', 'status', x.status)
       from public.world_bijang_runs x
      where x.status <> 'end' and (x.leader_id = p_uid or exists (select 1 from public.world_bijang_members m where m.run_id = x.run_id and m.owner_id = p_uid))
      order by x.created_at desc limit 1))$$]);

select pg_temp.yh_fix('world_hud_snapshot()', array[
  $$    'fight', public.world_my_fight(uid),$$,
  $$    'fight', public.world_my_fight(uid), 'bijang', public.world_bijang_brief(uid),$$]);

select pg_temp.yh_fix('world_notify_group', array[
  $$'party_exp_departed', 'party_exp_result') then 'party'$$,
  $$'party_exp_departed', 'party_exp_result', 'bijang') then 'party'$$]);

select pg_temp.yh_fix('world_character_purge(uuid)', array[
  $$  delete from public.world_drawing_made where owner_id = p_uid;$$,
  $$  delete from public.world_drawing_made where owner_id = p_uid;
  delete from public.world_bijang_members where owner_id = p_uid;
  delete from public.world_bijang_maps where owner_id = p_uid;$$]);

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('bj_final1', '비장고를 연 자', 'chest', '명부 정리 전에 묻힌 이름 하나를 흙 속에서 다시 꺼냈다.', '비장고 마지막 방에 닿는다', '{"rare_loot_pct": 3, "clue_bonus_pct": 2}', true, false, '{"n": 1, "ev": "bj_final"}', 3100, '비장고', 3),
  ('bj_final5', '옛 그림을 읽는 눈', 'chest', '바랜 비장도의 먹선만 보고도 문을 고른다.', '비장고 마지막 방에 5번 닿는다', '{"rare_loot_pct": 4, "gather_qty_pct": 3}', true, false, '{"n": 5, "ev": "bj_final"}', 3101, '비장고', 4),
  ('bj_final20', '이름 곳간지기', 'chest', '스무 곳의 곳간에서 잊힌 이름을 건져 올렸다.', '비장고 마지막 방에 20번 닿는다', '{"rare_loot_pct": 5, "clue_bonus_pct": 4, "mental_loss_pct": -3}', true, false, '{"n": 20, "ev": "bj_final"}', 3102, '비장고', 5)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text,
  bonus = excluded.bonus, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade, icon = excluded.icon;

insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
  ('sl_bj', 'seal', 'legend', '낙관 「藏」', '비장고 마지막 방에 5번 닿는다', '비장고', '{"n": 5, "ev": "bj_final"}', false, true, 1510)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, category = excluded.category;

update public.world_app_meta set value = '20261117010000' where key = 'db_version';
