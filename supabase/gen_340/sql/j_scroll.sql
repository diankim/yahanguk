create table if not exists public.world_job_changes (
  owner_id uuid primary key,
  changed_at timestamptz not null default now()
);
alter table public.world_job_changes enable row level security;
revoke all on public.world_job_changes from anon, authenticated;
grant select, insert, update, delete on public.world_job_changes to fn_owner_field;
do $$ declare r text; begin
  for r in select rolname from pg_roles where rolname like 'fn\_owner%' loop execute format('grant select, insert, update, delete on public.world_job_changes to %I', r); end loop;
end $$;

create or replace function public.world_job_change_rules() returns jsonb language sql immutable as $$
  select jsonb_build_object('cd_min', 60, 'price_base', 100, 'price_lv', 20,
    'alloc', jsonb_build_object(
      'artificer', jsonb_build_array('strength', 'vitality', 'agility'),
      'bloodknight', jsonb_build_array('strength', 'vitality', 'willpower'),
      'analyst', jsonb_build_array('strength', 'agility', 'perception'),
      'spearman', jsonb_build_array('strength', 'agility', 'perception'),
      'scout', jsonb_build_array('agility', 'perception', 'vitality'),
      'tamer', jsonb_build_array('agility', 'perception', 'vitality'),
      'exorcist', jsonb_build_array('spirit_affinity', 'willpower', 'perception'),
      'sealmaster', jsonb_build_array('spirit_affinity', 'willpower', 'vitality'),
      'medic', jsonb_build_array('spirit_affinity', 'willpower', 'vitality'),
      'formation', jsonb_build_array('spirit_affinity', 'willpower', 'perception')),
    'weapon', jsonb_build_object('artificer', 'iron_sword', 'bloodknight', 'w_melee1_heavy', 'analyst', 'w_melee1_keen', 'spearman', 'w_spear1_b',
      'scout', 'w_ranged1_keen', 'tamer', 'short_bow', 'exorcist', 'spirit_bell', 'sealmaster', 'w_magic1_heavy', 'medic', 'w_magic1_silent', 'formation', 'w_magic1_keen'))
$$;
grant execute on function public.world_job_change_rules() to authenticated;

create or replace function public.world_job_change_until(p_uid uuid) returns timestamptz language sql stable security definer set search_path = pg_catalog, public as $$
  select j.changed_at + make_interval(mins => (public.world_job_change_rules() ->> 'cd_min')::int) from public.world_job_changes j
   where j.owner_id = p_uid and j.changed_at + make_interval(mins => (public.world_job_change_rules() ->> 'cd_min')::int) > now()
$$;

create or replace function public.world_job_change_status() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); lv int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select level into lv from public.world_characters where owner_id = uid;
  return jsonb_build_object('until', public.world_job_change_until(uid),
    'price', (public.world_job_change_rules() ->> 'price_base')::int + (public.world_job_change_rules() ->> 'price_lv')::int * coalesce(lv, 1));
end $$;

create or replace function public.world_reset_identity(p_job text, p_faction text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; back int; job_label text; off_items text[];
  r jsonb := public.world_job_change_rules(); pts int; st text; cur int; cap int; add int; vals jsonb; until timestamptz; wpn text; got_wpn boolean := false;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce((c.inventory ->> 'reset_identity')::int, 0) < 1 then raise exception '환골탈태 서첩이 없습니다.'; end if;
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 쓸 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then raise exception '원정 중에는 쓸 수 없습니다.'; end if;
  until := public.world_job_change_until(uid);
  if until is not null then
    raise exception '직업을 바꾼 지 얼마 되지 않았습니다. %분 뒤에 다시 쓸 수 있습니다.', ceil(extract(epoch from until - now()) / 60)
      using hint = 'cd:' || ceil(extract(epoch from until - now()))::int;
  end if;
  job_label := public.world_job_label(p_job);
  if job_label is null then raise exception '직업을 고르세요.'; end if;
  if p_job = c.job_key then raise exception '지금과 같은 직업입니다.'; end if;
  back := public.world_reset_points(uid);
  select array_agg(e.item_id) into off_items from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
   where e.owner_id = uid and ((i.required_job is not null and i.required_job <> p_job) or not public.world_weapon_job_ok(i.category, i.equipment_traits, p_job));
  delete from public.world_character_equipment e using public.world_item_catalog i
   where e.owner_id = uid and i.item_id = e.item_id and ((i.required_job is not null and i.required_job <> p_job) or not public.world_weapon_job_ok(i.category, i.equipment_traits, p_job));
  vals := public.world_job_base(p_job);
  select stat_points + back into pts from public.world_characters where owner_id = uid;
  for st in select jsonb_array_elements_text(r -> 'alloc' -> p_job) loop
    exit when pts <= 0;
    cur := (vals ->> st)::int;
    cap := public.world_stat_cap_of(p_job, st, c.level);
    add := greatest(0, least(pts, cap - cur));
    vals := jsonb_set(vals, array[st], to_jsonb(cur + add));
    pts := pts - add;
  end loop;
  wpn := r -> 'weapon' ->> p_job;
  update public.world_characters
     set job_key = p_job, occupation = job_label,
         strength = (vals ->> 'strength')::int, agility = (vals ->> 'agility')::int, vitality = (vals ->> 'vitality')::int, perception = (vals ->> 'perception')::int,
         willpower = (vals ->> 'willpower')::int, spirit_affinity = (vals ->> 'spirit_affinity')::int, stat_points = pts,
         inventory = case when (inventory ->> 'reset_identity')::int <= 1 then inventory - 'reset_identity' else jsonb_set(inventory, '{reset_identity}', to_jsonb((inventory ->> 'reset_identity')::int - 1)) end,
         updated_at = now()
   where owner_id = uid;
  if wpn is not null and not exists (select 1 from public.world_characters x, jsonb_each(x.inventory) iv join public.world_item_catalog ic on ic.item_id = iv.key
                                      where x.owner_id = uid and ic.category = 'weapon' and public.world_weapon_job_ok(ic.category, ic.equipment_traits, p_job)) then
    update public.world_characters set inventory = inventory || jsonb_build_object(wpn, coalesce((inventory ->> wpn)::int, 0) + 1) where owner_id = uid;
    got_wpn := true;
  end if;
  insert into public.world_job_changes(owner_id, changed_at) values (uid, now()) on conflict (owner_id) do update set changed_at = now();
  return jsonb_build_object('ok', true, 'refunded', back, 'left_points', pts, 'stats', vals, 'weapon', case when got_wpn then wpn end,
    'unequipped', coalesce(to_jsonb(off_items), '[]'::jsonb),
    'content', format('%s(으)로 새 길을 걷습니다. 레벨로 받은 능력치를 새 직업에 맞게 다시 놓았습니다.%s%s', job_label,
      case when got_wpn then ' ' || (select item_name from public.world_item_catalog where item_id = wpn) || '을(를) 받았습니다.' else '' end,
      case when off_items is not null then ' 새 직업이 쓸 수 없는 장비는 벗었습니다.' else '' end));
end
$function$;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, 'reset_identity', 100, 99, 99, null from (select distinct shop_id from public.world_shop_catalog where shop_id <> 'smithy') s
on conflict do nothing;
delete from public.world_shop_catalog where item_id = 'ammo_bolt';

select pg_temp.yh_fix('world_shop_refresh', array[$q$'ammo_bolt', $q$, $q$'reset_identity', $q$]);

select pg_temp.yh_fix('world_shop_buy', array[$q$  total := s.unit_price * p_qty;$q$,
  $q$  if p_item_id = 'reset_identity' then s.unit_price := (public.world_job_change_rules() ->> 'price_base')::int + (public.world_job_change_rules() ->> 'price_lv')::int * c.level; end if;
  total := s.unit_price * p_qty;$q$]);

select pg_temp.yh_fix('world_shop_snapshot', array[$q$'unit_price', ss.unit_price,$q$,
  $q$'unit_price', case when ss.item_id = 'reset_identity' then (public.world_job_change_rules() ->> 'price_base')::int + (public.world_job_change_rules() ->> 'price_lv')::int * coalesce((select x.level from public.world_characters x where x.owner_id = public.fn_owner_auth_uid()), 1) else ss.unit_price end,$q$]);

update public.world_faction_vault set item_id = 'reset_stats' where item_id = 'reset_identity';
update public.world_item_catalog set description = '레벨로 받은 능력치 포인트를 모두 돌려받아 다시 나눈다. 직업은 그대로다.' where item_id = 'reset_stats';
update public.world_item_catalog set description = '직업을 새로 고른다. 레벨로 받은 능력치는 새 직업의 주 능력치에 맞게 저절로 놓이고, 소속·레벨·기술 단계는 그대로다. 쓴 뒤 1시간은 다시 쓸 수 없다.', reference_price = 100 where item_id = 'reset_identity';

do $$
declare f text;
begin
  foreach f in array array['public.world_job_change_until(uuid)', 'public.world_job_change_status()'] loop
    perform pg_temp.yh_own(f, 'fn_owner_field');
    perform pg_temp.yh_share(f);
  end loop;
end $$;
grant execute on function public.world_job_change_status() to authenticated;

select pg_temp.yh_fix('world_character_purge', array[$q$  delete from public.world_gear_sets where owner_id = p_uid;$q$,
  $q$  delete from public.world_gear_sets where owner_id = p_uid;
  delete from public.world_job_changes where owner_id = p_uid;$q$]);

select pg_temp.yh_fix('world_hud_snapshot', array[$q$'bijang', public.world_bijang_brief(uid),$q$, $q$'bijang', public.world_bijang_brief(uid), 'job_cd', public.world_job_change_until(uid),$q$]);
