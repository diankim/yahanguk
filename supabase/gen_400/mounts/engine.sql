create or replace function public.world_mount_realm_rules()
 returns jsonb language sql immutable set search_path to 'pg_catalog' as $f$ select %%RULES%% $f$;
create or replace function public.world_terr_realm(p_terr text)
 returns text language sql immutable set search_path to 'pg_catalog', 'public' as $f$
  select coalesce(public.world_domain_rules() -> p_terr ->> 'realm', public.world_mount_realm_rules() ->> 'default')
$f$;
create or replace function public.world_terr_realms()
 returns jsonb language sql immutable set search_path to 'pg_catalog', 'public' as $f$
  select coalesce(jsonb_object_agg(key, value ->> 'realm'), '{}'::jsonb) from jsonb_each(public.world_domain_rules()) where jsonb_typeof(value) = 'object' and value ? 'realm'
$f$;
create or replace function public.world_region_realm(p_region text)
 returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select public.world_terr_realm(r.territory_id) from public.world_map_regions r where r.region_id = p_region
$f$;
create or replace function public.world_mount_realm(p_mount text)
 returns text language sql immutable set search_path to 'pg_catalog', 'public' as $f$
  select coalesce(public.world_mount_realm_rules() -> 'mounts' ->> p_mount, public.world_mount_realm_rules() ->> 'default')
$f$;
create or replace function public.world_mount_realm_ok(p_mount text, p_region text)
 returns boolean language sql stable set search_path to 'pg_catalog', 'public' as $f$
  select p_mount is null or p_region is null or public.world_mount_realm(p_mount) = coalesce(public.world_region_realm(p_region), public.world_mount_realm(p_mount))
$f$;
create or replace function public.world_mount_realm_ok_at(p_mount text, p_location text)
 returns boolean language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select public.world_mount_realm_ok(p_mount, (public.world_field_region(p_location)).region_id)
$f$;
create or replace function public.world_mount_realm_msg(p_mount text)
 returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select format('%s은(는) %s에서만 탈 수 있습니다. 지금 선 땅의 탈것을 고르세요.', coalesce((select m.mount_name from public.world_mount_catalog m where m.mount_id = p_mount), '그 탈것'),
    public.world_mount_realm_rules() -> 'names' ->> public.world_mount_realm(p_mount))
$f$;

create table if not exists public.world_mount_last (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  realm text not null,
  mount_id text not null references public.world_mount_catalog(mount_id) on delete cascade,
  at timestamptz not null default now(),
  primary key (owner_id, realm)
);
create index if not exists idx_world_mount_last_mount on public.world_mount_last(mount_id);
alter table public.world_mount_last enable row level security;
revoke all on public.world_mount_last from public, anon, authenticated;

create or replace function public.world_mount_last_pick(p_uid uuid, p_realm text)
 returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $f$
  select l.mount_id from public.world_mount_last l join public.world_owned_mounts o on o.owner_id = l.owner_id and o.mount_id = l.mount_id
   where l.owner_id = p_uid and l.realm = p_realm and public.world_mount_realm(l.mount_id) = p_realm
$f$;

create or replace function public.world_mount_realm_note(p_uid uuid, p_realm text, p_from text, p_to text)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare rn text := public.world_mount_realm_rules() -> 'names' ->> p_realm; fn text; tn text;
begin
  select mount_name into fn from public.world_mount_catalog where mount_id = p_from;
  select mount_name into tn from public.world_mount_catalog where mount_id = p_to;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_uid, 'guide', '땅을 건넜습니다',
    case when tn is not null and fn is not null then format('%s에 들어서며 %s에서 내려, 이 땅에서 타던 %s(으)로 갈아탔습니다.', rn, fn, tn)
         when tn is not null then format('%s에 들어서며 이 땅에서 타던 %s에 다시 올랐습니다.', rn, tn)
         when fn is not null then format('%s에 들어서며 %s에서 내렸습니다. 이 땅에서 탄 탈것이 없어 걸어갑니다. %s 안전지대 마구간에서 이 땅의 탈것을 들일 수 있습니다.', rn, fn, rn)
         else format('%s에 들어섰습니다. 이 땅에서 탄 탈것이 없어 걸어갑니다. %s 안전지대 마구간에서 이 땅의 탈것을 들일 수 있습니다.', rn, rn) end,
    jsonb_build_object('tip', 'mount_realm', 'realm', p_realm, 'from', p_from, 'to', p_to));
end $f$;

create or replace function public.world_mount_realm_on_move()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare nr text; orr text; pk text;
begin
  nr := public.world_region_realm((public.world_field_region(new.location)).region_id);
  if nr is null then return new; end if;
  orr := public.world_region_realm((public.world_field_region(old.location)).region_id);
  if orr is not distinct from nr and (new.mount_id is null or public.world_mount_realm(new.mount_id) = nr) then return new; end if;
  if old.mount_id is not null and orr is not null and public.world_mount_realm(old.mount_id) = orr then
    insert into public.world_mount_last(owner_id, realm, mount_id) values (new.owner_id, orr, old.mount_id)
    on conflict (owner_id, realm) do update set mount_id = excluded.mount_id, at = now() where public.world_mount_last.mount_id is distinct from excluded.mount_id;
  end if;
  pk := case when new.mount_id is not null and public.world_mount_realm(new.mount_id) = nr then new.mount_id else public.world_mount_last_pick(new.owner_id, nr) end;
  if pk is distinct from new.mount_id or orr is distinct from nr then
    perform public.world_mount_realm_note(new.owner_id, nr, case when pk is distinct from new.mount_id then new.mount_id end, case when pk is distinct from new.mount_id or orr is distinct from nr then pk end);
    new.mount_id := pk;
  end if;
  return new;
end $f$;
drop trigger if exists trg_world_mount_realm on public.world_characters;
create trigger trg_world_mount_realm before update of location on public.world_characters for each row
  when (new.location is distinct from old.location) execute function public.world_mount_realm_on_move();

create or replace function public.world_mount_last_note()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare rl text := public.world_region_realm((public.world_field_region(new.location)).region_id);
begin
  if rl is not null and public.world_mount_realm(new.mount_id) = rl then
    insert into public.world_mount_last(owner_id, realm, mount_id) values (new.owner_id, rl, new.mount_id)
    on conflict (owner_id, realm) do update set mount_id = excluded.mount_id, at = now() where public.world_mount_last.mount_id is distinct from excluded.mount_id;
  end if;
  return null;
end $f$;
drop trigger if exists trg_world_mount_last on public.world_characters;
create trigger trg_world_mount_last after update of mount_id on public.world_characters for each row
  when (new.mount_id is not null and new.mount_id is distinct from old.mount_id) execute function public.world_mount_last_note();

create or replace function public.world_mount_realm_sync(p_uid uuid)
 returns text language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare c public.world_characters%rowtype; rl text; pk text;
begin
  select * into c from public.world_characters where owner_id = p_uid for update;
  if not found then return null; end if;
  rl := public.world_region_realm((public.world_field_region(c.location)).region_id);
  if rl is null or c.mount_id is null or public.world_mount_realm(c.mount_id) = rl then return c.mount_id; end if;
  insert into public.world_mount_last(owner_id, realm, mount_id) values (p_uid, public.world_mount_realm(c.mount_id), c.mount_id)
  on conflict (owner_id, realm) do update set mount_id = excluded.mount_id, at = now();
  pk := public.world_mount_last_pick(p_uid, rl);
  update public.world_characters set mount_id = pk where owner_id = p_uid;
  perform public.world_mount_realm_note(p_uid, rl, c.mount_id, pk);
  return pk;
end $f$;

do $$ declare f text; begin
  foreach f in array array['public.world_mount_realm_rules()', 'public.world_terr_realm(text)', 'public.world_terr_realms()', 'public.world_region_realm(text)', 'public.world_mount_realm(text)',
    'public.world_mount_realm_ok(text,text)', 'public.world_mount_realm_msg(text)'] loop
    perform pg_temp.yh_share(f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array['public.world_mount_realm_ok_at(text,text)', 'public.world_mount_last_pick(uuid,text)', 'public.world_mount_realm_note(uuid,text,text,text)', 'public.world_mount_realm_on_move()', 'public.world_mount_last_note()',
    'public.world_mount_realm_sync(uuid)'] loop
    perform pg_temp.yh_share(f);
  end loop;
end $$;

insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, unlock_faction, unlock_region, unlock_item, price, description, tier,
  passenger_capacity, fare_tokens, fare_free, acquire_method)
select x.mount_id, x.mount_name, x.speed_multiplier, x.unlock_level, 0, null, x.unlock_region, null, x.price, x.description, x.tier, x.passenger_capacity, x.fare_tokens, false, 'stable'
  from jsonb_to_recordset(%%ROWS%%) as x(mount_id text, mount_name text, speed_multiplier numeric, unlock_level int, unlock_region text, description text, tier text,
    passenger_capacity int, fare_tokens int, price bigint)
on conflict (mount_id) do update set mount_name = excluded.mount_name, speed_multiplier = excluded.speed_multiplier, unlock_level = excluded.unlock_level, unlock_region = excluded.unlock_region,
  description = excluded.description, tier = excluded.tier, passenger_capacity = excluded.passenger_capacity, fare_tokens = excluded.fare_tokens, price = excluded.price, acquire_method = 'stable';
update public.world_map_regions set has_stable = true where region_id in (%%HUBS%%) and not has_stable;
do $$ begin
  if exists (select mount_name from public.world_mount_catalog group by mount_name having count(*) > 1) then raise exception '탈것 이름 겹침'; end if;
  if exists (select 1 from jsonb_object_keys(public.world_mount_realm_rules() -> 'mounts') k where not exists (select 1 from public.world_mount_catalog m where m.mount_id = k)) then
    raise exception '땅 탈것 규칙에 없는 탈것이 있습니다'; end if;
  if exists (select 1 from public.world_mount_catalog m where public.world_mount_realm(m.mount_id) <> 'main' and m.unlock_region is not null
             and public.world_region_realm(m.unlock_region) <> public.world_mount_realm(m.mount_id)) then raise exception '탈것을 들이는 곳과 땅이 맞지 않습니다'; end if;
end $$;

select pg_temp.yh_fix('world_travel_plan(uuid,text,integer)', array[
  'swap boolean; pr jsonb;', 'swap boolean; pr jsonb; mr text; rl text[]; rides int := 0; ws float8 := 1;',
  'path := si || path;', 'path := si || path;
  mr := public.world_mount_realm(c.mount_id);
  SELECT array_agg(public.world_terr_realm(t) ORDER BY o) INTO rl FROM unnest(terr) WITH ORDINALITY u(t, o);
  IF c.mount_id IS NOT NULL THEN
    FOR i IN 2..cardinality(path) LOOP IF rl[path[i - 1]] = mr AND rl[path[i]] = mr THEN rides := rides + 1; END IF; END LOOP;
  END IF;',
  'generate_series(1, cardinality(path) - 1) WHERE random() < 0.1', 'generate_series(1, rides) WHERE random() < 0.1',
  'fare := coalesce(fare_per, 0) * (cardinality(path) - 1 - n_free);', 'fare := coalesce(fare_per, 0) * greatest(0, rides - n_free);',
  'THEN speed := speed / 0.75; END IF;', 'THEN speed := speed / 0.75; END IF;
  IF ''tracking_c43b'' = ANY (sk) THEN ws := 1 / 0.75; END IF;',
  'THEN 1.2 ELSE 1 END / speed;', 'THEN 1.2 ELSE 1 END / CASE WHEN rl[path[i - 1]] = mr AND rl[path[i]] = mr THEN speed ELSE ws END;',
  '''mount_id'', c.mount_id,', '''mount_id'', c.mount_id, ''rides'', rides,']);

select pg_temp.yh_fix('world_mount_equip(text)', array[
  'THEN RAISE EXCEPTION ''보유하지 않은 탈것입니다.''; END IF;', 'THEN RAISE EXCEPTION ''보유하지 않은 탈것입니다.''; END IF; IF NOT public.world_mount_realm_ok_at(p_mount_id, c.location) THEN RAISE EXCEPTION USING message = public.world_mount_realm_msg(p_mount_id), hint = ''mount_realm''; END IF;']);

select pg_temp.yh_fix('world_mount_acquire(text)', array[
  'stable_name text;', 'stable_name text; mst jsonb; mt jsonb;',
  'IF c.gil<m.price THEN RAISE EXCEPTION ''재화가 부족합니다. (필요 %전)'', m.price; END IF;', 'IF NOT public.world_mount_realm_ok(p_mount_id, r.region_id) THEN RAISE EXCEPTION USING message = public.world_mount_realm_msg(p_mount_id), hint = ''mount_realm''; END IF;
  IF c.gil<m.price THEN RAISE EXCEPTION ''재화가 부족합니다. (필요 %전)'', m.price; END IF;
  IF public.world_mount_realm_rules() -> ''mats'' ? p_mount_id THEN
    IF NOT public.world_weak_here(uid, ''storage'') THEN SELECT items INTO mst FROM public.world_storage WHERE owner_id = uid FOR UPDATE; END IF;
    mt := public.world_materials_take(inv, coalesce(mst, ''{}''::jsonb), public.world_mount_realm_rules() -> ''mats'' -> p_mount_id);
    inv := mt -> ''inv'';
    IF mt -> ''from_st'' <> ''{}''::jsonb THEN
      UPDATE public.world_storage SET items = (SELECT coalesce(jsonb_object_agg(key, value), ''{}''::jsonb) FROM jsonb_each(mt -> ''st'') WHERE jsonb_typeof(value) = ''number'' AND value::text::int > 0), updated_at = now() WHERE owner_id = uid;
    END IF;
  END IF;',
  '''mount_id'',p_mount_id,''gil'',c.gil-m.price);', '''mount_id'',p_mount_id,''gil'',c.gil-m.price,''from_storage'',coalesce(mt -> ''from_st'', ''{}''::jsonb));']);

grant execute on function public.world_materials_take(jsonb, jsonb, jsonb, boolean) to fn_owner_18883;

select pg_temp.yh_fix('world_mount_snapshot', array[
  'm.mount_id),0)) order by case', 'm.mount_id),0),''realm'',public.world_mount_realm(m.mount_id),''mats'',public.world_mount_realm_rules()->''mats''->m.mount_id) order by case',
  '''travel_arrives_at'',c.travel_arrives_at); end', '''travel_arrives_at'',c.travel_arrives_at,''realm'',coalesce(public.world_region_realm(here),public.world_mount_realm_rules()->>''default''),''realm_names'',public.world_mount_realm_rules()->''names'',''terr_realm'',public.world_terr_realms()); end']);

select pg_temp.yh_fix('world_travel_party_invite_v2(uuid,text)', array[
  'pl := public.world_travel_plan(uid, r.region_id, least(c.level, p.level));', 'IF NOT public.world_mount_realm_ok_at(c.mount_id, c.location) THEN
    RAISE EXCEPTION USING message = public.world_mount_realm_msg(c.mount_id), hint = ''mount_realm'';
  END IF;
  pl := public.world_travel_plan(uid, r.region_id, least(c.level, p.level));']);

select pg_temp.yh_fix('world_ride_go(uuid,uuid[],uuid,boolean)', array[
  'when coalesce(cap, 0) < 2 then', 'when not public.world_mount_realm_ok(c.mount_id, oldr.region_id) then public.world_mount_realm_msg(c.mount_id)
    when coalesce(cap, 0) < 2 then']);

select pg_temp.yh_fix('world_character_purge(uuid)', array[
  '  if p_uid is null then return; end if;', '  if p_uid is null then return; end if;
  delete from public.world_mount_last where owner_id = p_uid;']);

select public.world_mount_realm_sync(c.owner_id) from public.world_characters c
 where c.mount_id is not null and public.world_mount_realm(c.mount_id) is distinct from coalesce(public.world_region_realm((public.world_field_region(c.location)).region_id), public.world_mount_realm(c.mount_id));
