create or replace function pg_temp.yh_ps_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if position(p_pairs[2 * i] in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.yh_ps_share(p_fn text, p_auth boolean default false) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname in ('service_role', 'postgres') loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
  if p_auth then execute format('grant execute on function %s to authenticated', p_fn); end if;
end $f$;

create table if not exists public.world_pet_skin_earned (
  owner_id uuid not null references auth.users(id) on delete cascade,
  skin text not null,
  at timestamptz not null default now(),
  primary key (owner_id, skin)
);
create table if not exists public.world_pet_skin_tally (
  owner_id uuid not null references auth.users(id) on delete cascade,
  k text not null,
  n bigint not null default 0,
  primary key (owner_id, k)
);
alter table public.world_pet_skin_earned enable row level security;
alter table public.world_pet_skin_tally enable row level security;
revoke all on public.world_pet_skin_earned, public.world_pet_skin_tally from public, anon, authenticated;
do $g$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant select, insert, update, delete on public.world_pet_skin_earned, public.world_pet_skin_tally to %I', x);
  end loop;
end $g$;

create or replace function public.world_pet_skin_need(p_rule jsonb)
 returns int language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  return case p_rule ->> 'by'
    when 'quest' then jsonb_array_length(p_rule -> 'q')
    when 'side' then jsonb_array_length(p_rule -> 'q')
    when 'survey' then jsonb_array_length(p_rule -> 'regs')
    when 'fishdex' then jsonb_array_length(p_rule -> 'fish')
    when 'codex' then (select count(distinct m.monster_id)::int from public.world_region_monsters m
                        where m.region_id in (select jsonb_array_elements_text(p_rule -> 'regs')) and m.role <> 'raider')
    else coalesce((p_rule ->> 'n')::int, 1) end;
end $f$;

create or replace function public.world_pet_skin_prog(p_uid uuid, p_rule jsonb, p_full jsonb default null)
 returns int language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare by_ text := p_rule ->> 'by'; regs text[] := array(select jsonb_array_elements_text(coalesce(p_rule -> 'regs', '[]'::jsonb))); v int;
begin
  if p_uid is null then return 0; end if;
  if by_ = 'boss' then
    select coalesce(max(g.kills), 0) into v from public.world_gw_records g where g.owner_id = p_uid and g.boss_id = p_rule ->> 'boss';
  elsif by_ in ('quest', 'side') then
    select count(*) into v from jsonb_array_elements_text(p_rule -> 'q') q where q = any (public.world_quest_done_ids(p_uid));
  elsif by_ = 'survey' then
    select count(*) into v from jsonb_array_elements_text(coalesce(p_full, public.world_survey_full_list(p_uid))) f where f = any (regs);
  elsif by_ in ('trade', 'raid', 'feast_full', 'feast_eat', 'guard') then
    select coalesce(max(t.n), 0) into v from public.world_pet_skin_tally t where t.owner_id = p_uid and t.k = p_rule ->> 'k';
  elsif by_ = 'catch' then
    select count(*) into v from public.world_lanterns l where l.catcher_id = p_uid and l.caught_port = p_rule ->> 'port';
  elsif by_ = 'float' then
    select count(*) into v from public.world_lanterns l where l.author_id = p_uid;
  elsif by_ = 'ship' then
    select coalesce(max(s.tier), 0) into v from public.world_ships s where s.owner_id = p_uid;
  elsif by_ = 'codex' then
    select count(distinct x.monster_id) into v from public.world_monster_codex x
     where x.owner_id = p_uid and x.defeated > 0
       and x.monster_id in (select m.monster_id from public.world_region_monsters m where m.region_id = any (regs) and m.role <> 'raider');
  elsif by_ = 'exp' then
    select count(*) into v from public.world_expeditions e
     where e.owner_id = p_uid and e.status = 'done' and e.region_id = any (regs) and e.result ->> 'ended' = 'complete'
       and coalesce((e.result ->> 'rounds')::int, 0) >= coalesce((e.result ->> 'total_rounds')::int, 1);
  elsif by_ = 'exp_full' then
    select count(*) into v from public.world_region_progress p where p.owner_id = p_uid and p.region_id = p_rule ->> 'region' and 'complete' = any (p.milestones);
  elsif by_ = 'fishdex' then
    select count(*) into v from public.world_fish_log f where f.owner_id = p_uid and f.fish_id in (select jsonb_array_elements_text(p_rule -> 'fish'));
  elsif by_ = 'craft' then
    select count(*) into v from (select 1 from public.world_events e join public.world_item_catalog i on i.item_id = e.payload ->> 'output'
     where e.actor_id = p_uid and e.event_type = 'craft' and i.tier >= (p_rule ->> 'tier')::int
       and i.category in (select jsonb_array_elements_text(p_rule -> 'cats')) limit 1) z;
  end if;
  return coalesce(v, 0);
end $f$;

create or replace function public.world_pet_skin_check(p_uid uuid, p_by text default null)
 returns int language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare s record; got int := 0; fl jsonb; pn text; owned boolean;
begin
  if p_uid is null or not exists (select 1 from public.world_characters c where c.owner_id = p_uid) then return 0; end if;
  for s in select k.key, k.value from jsonb_each(public.world_pet_skin_rules() -> 'skins') k
            where k.value ->> 'how' = 'earn' and (p_by is null or k.value ->> 'by' = p_by)
              and not exists (select 1 from public.world_pet_skin_earned e where e.owner_id = p_uid and e.skin = k.key) order by k.key loop
    if s.value ->> 'by' = 'survey' and fl is null then fl := public.world_survey_full_list(p_uid); end if;
    if public.world_pet_skin_prog(p_uid, s.value, fl) < public.world_pet_skin_need(s.value) then continue; end if;
    insert into public.world_pet_skin_earned(owner_id, skin) values (p_uid, s.key) on conflict do nothing;
    if not found then continue; end if;
    got := got + 1;
    select sp.pet_name into pn from public.world_pet_species sp where sp.pet_id = s.value ->> 'pet';
    owned := exists (select 1 from public.world_pets p where p.owner_id = p_uid and p.pet_id = s.value ->> 'pet');
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_uid, 'pet_skin', '동무 무늬를 얻었습니다',
            '「' || (s.value ->> 'name') || '」 무늬 · ' || case when owned then coalesce(pn, '바탕 동무') || '의 「무늬」에서 고를 수 있습니다.'
                                                         else '바탕 동무 「' || coalesce(pn, '') || '」을(를) 얻으면 바로 고를 수 있습니다.' end,
            jsonb_build_object('skin', s.key, 'pet', s.value ->> 'pet'));
  end loop;
  return got;
end $f$;

create or replace function public.world_pet_skin_tally_add(p_uid uuid, p_k text, p_n bigint)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  if p_uid is null or coalesce(p_n, 0) <= 0 then return; end if;
  insert into public.world_pet_skin_tally(owner_id, k, n) values (p_uid, p_k, p_n)
  on conflict (owner_id, k) do update set n = public.world_pet_skin_tally.n + excluded.n;
end $f$;

create or replace function public.world_pet_skin_uses(p_by text[], p_key text, p_val text)
 returns boolean language sql immutable set search_path to 'pg_catalog', 'public' as $f$
  select exists (select 1 from jsonb_each(public.world_pet_skin_rules() -> 'skins') k
                  where k.value ->> 'by' = any (p_by) and p_val is not null and (k.value -> p_key ? p_val or k.value ->> p_key = p_val))
$f$;

create or replace function public.world_pet_skins_for(p_uid uuid, p_pet text) returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  if not exists (select 1 from public.world_pets p where p.owner_id = p_uid and p.pet_id = p_pet) then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(k.key order by k.key) from jsonb_each(public.world_pet_skin_rules() -> 'skins') k
    where k.value ->> 'pet' = p_pet
      and (k.value ->> 'how' = 'pet'
           or (k.value ->> 'how' = 'earn' and exists (select 1 from public.world_pet_skin_earned e where e.owner_id = p_uid and e.skin = k.key)))), '[]'::jsonb);
end $$;

create or replace function public.world_pet_skin_book(p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare out jsonb[] := '{}'; s record; fl jsonb; got timestamptz; have boolean; need int; done text[];
begin
  if p_uid is null then return '[]'::jsonb; end if;
  done := public.world_quest_done_ids(p_uid);
  for s in select k.key, k.value from jsonb_each(public.world_pet_skin_rules() -> 'skins') k order by k.key loop
    have := exists (select 1 from public.world_pets p where p.owner_id = p_uid and p.pet_id = s.value ->> 'pet');
    if s.value ->> 'how' = 'pet' then
      out := out || jsonb_build_object('k', s.key, 'pet', s.value ->> 'pet', 'how', 'pet', 'got', have, 'have', have);
      continue;
    end if;
    select e.at into got from public.world_pet_skin_earned e where e.owner_id = p_uid and e.skin = s.key;
    if got is null and s.value ? 'reveal' and not (s.value ->> 'reveal' = any (done)) then
      out := out || jsonb_build_object('k', s.key, 'pet', s.value ->> 'pet', 'how', 'earn', 'hidden', true, 'got', false, 'have', have);
      continue;
    end if;
    need := public.world_pet_skin_need(s.value);
    if got is null and s.value ->> 'by' = 'survey' and fl is null then fl := public.world_survey_full_list(p_uid); end if;
    out := out || jsonb_build_object('k', s.key, 'pet', s.value ->> 'pet', 'how', 'earn', 'got', got is not null, 'at', got, 'have', have,
      'src', s.value ->> 'src', 'need', need, 'n', case when got is not null then need else least(need, public.world_pet_skin_prog(p_uid, s.value, fl)) end);
  end loop;
  return to_jsonb(out);
end $f$;

create or replace function public.world_pet_skin_trg()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare rg text; u uuid; s numeric := 0; x jsonb;
begin
  if tg_table_name = 'world_gw_records' then
    if new.kills > 0 and public.world_pet_skin_uses(array['boss'], 'boss', new.boss_id) then perform public.world_pet_skin_check(new.owner_id, 'boss'); end if;
  elsif tg_table_name = 'world_quest_progress' then
    if new.done_at is not null and (tg_op = 'INSERT' or old.done_at is null) and public.world_pet_skin_uses(array['quest', 'side'], 'q', new.quest_id) then
      perform public.world_pet_skin_check(new.owner_id, 'quest');
      perform public.world_pet_skin_check(new.owner_id, 'side');
    end if;
  elsif tg_table_name in ('world_exploration_discoveries', 'world_gathering_discoveries') then
    if tg_table_name = 'world_gathering_discoveries' then
      select n.region_id into rg from public.world_gathering_spots g join public.world_exploration_nodes n on n.node_id = g.node_id where g.spot_id = new.spot_id;
    else
      select n.region_id into rg from public.world_exploration_nodes n where n.node_id = new.node_id;
    end if;
    if public.world_pet_skin_uses(array['survey'], 'regs', rg) then perform public.world_pet_skin_check(new.owner_id, 'survey'); end if;
  elsif tg_table_name = 'world_monster_codex' then
    if new.defeated > 0 and (tg_op = 'INSERT' or old.defeated = 0)
       and exists (select 1 from public.world_region_monsters m where m.monster_id = new.monster_id and public.world_pet_skin_uses(array['codex'], 'regs', m.region_id)) then
      perform public.world_pet_skin_check(new.owner_id, 'codex');
    end if;
  elsif tg_table_name = 'world_fish_log' then
    if public.world_pet_skin_uses(array['fishdex'], 'fish', new.fish_id) then perform public.world_pet_skin_check(new.owner_id, 'fishdex'); end if;
  elsif tg_table_name = 'world_events' then
    if new.event_type = 'combat' then
      for x in select k.value from jsonb_each(public.world_pet_skin_rules() -> 'skins') k
                where k.value ->> 'by' = 'guard' and k.value -> 'regs' ? (new.payload ->> 'region_id') loop
        perform public.world_pet_skin_tally_add(new.actor_id, x ->> 'k', 1);
      end loop;
      if found then perform public.world_pet_skin_check(new.actor_id, 'guard'); end if;
    elsif new.event_type = 'craft' then
      if exists (select 1 from jsonb_each(public.world_pet_skin_rules() -> 'skins') k join public.world_item_catalog i on i.item_id = new.payload ->> 'output'
                  where k.value ->> 'by' = 'craft' and i.tier >= (k.value ->> 'tier')::int and i.category in (select jsonb_array_elements_text(k.value -> 'cats'))) then
        perform public.world_pet_skin_check(new.actor_id, 'craft');
      end if;
    elsif new.event_type = 'expedition_end' then
      if public.world_pet_skin_uses(array['exp'], 'regs', new.payload ->> 'region_id') then perform public.world_pet_skin_check(new.actor_id, 'exp'); end if;
      if public.world_pet_skin_uses(array['exp_full'], 'region', new.payload ->> 'region_id') then perform public.world_pet_skin_check(new.actor_id, 'exp_full'); end if;
    end if;
  elsif tg_table_name = 'world_lanterns' then
    if tg_op = 'INSERT' then
      perform public.world_pet_skin_check(new.author_id, 'float');
    elsif new.catcher_id is not null and old.catcher_id is null and public.world_pet_skin_uses(array['catch'], 'port', new.caught_port) then
      perform public.world_pet_skin_check(new.catcher_id, 'catch');
    end if;
  elsif tg_table_name = 'world_hfeast_eats' then
    if not new.giver then
      perform public.world_pet_skin_tally_add(new.owner_id, 'feast_eat', 1);
      perform public.world_pet_skin_check(new.owner_id, 'feast_eat');
    end if;
  elsif tg_table_name = 'world_hfeast_tables' then
    if new.status = 'open' and old.status is distinct from 'open' then
      for u in select distinct b.owner_id from public.world_hfeast_bowls b where b.table_id = new.table_id order by 1 loop
        perform public.world_pet_skin_tally_add(u, 'feast_full', 1);
        perform public.world_pet_skin_check(u, 'feast_full');
      end loop;
    end if;
  elsif tg_table_name = 'world_economy_ledger' then
    if new.action = 'trade_goods_sale' and public.world_pet_skin_uses(array['trade'], 'k', 'trade:' || (new.details ->> 'port')) then
      for x in select value from jsonb_array_elements(coalesce(new.details -> 'sold', '[]'::jsonb)) loop
        s := s + coalesce((public.world_trade_good(x ->> 'good') ->> 'base')::numeric, 0) * coalesce((x ->> 'qty')::numeric, 0);
      end loop;
      perform public.world_pet_skin_tally_add(new.owner_id, 'trade:' || (new.details ->> 'port'), round(s)::bigint);
      perform public.world_pet_skin_check(new.owner_id, 'trade');
    end if;
  elsif tg_table_name = 'world_ships' then
    if tg_op = 'INSERT' or new.tier is distinct from old.tier then perform public.world_pet_skin_check(new.owner_id, 'ship'); end if;
  elsif tg_table_name = 'world_trade_voyages' then
    if new.raid_done and not old.raid_done and coalesce((new.result #>> '{raid,won}')::boolean, false) then
      for u in select a.owner_id from public.world_trade_aboard a where a.voyage_id = new.voyage_id order by 1 loop
        perform public.world_pet_skin_tally_add(u, 'raid', 1);
        perform public.world_pet_skin_check(u, 'raid');
      end loop;
    end if;
  end if;
  return null;
end $f$;

drop trigger if exists trg_world_pet_skin on public.world_gw_records;
create trigger trg_world_pet_skin after insert or update of kills on public.world_gw_records for each row execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_quest_progress;
create trigger trg_world_pet_skin after insert or update of done_at on public.world_quest_progress for each row when (new.done_at is not null) execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_exploration_discoveries;
create trigger trg_world_pet_skin after insert on public.world_exploration_discoveries for each row execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_gathering_discoveries;
create trigger trg_world_pet_skin after insert on public.world_gathering_discoveries for each row execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_monster_codex;
create trigger trg_world_pet_skin after insert or update of defeated on public.world_monster_codex for each row when (new.defeated > 0) execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_fish_log;
create trigger trg_world_pet_skin after insert on public.world_fish_log for each row execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_events;
create trigger trg_world_pet_skin after insert on public.world_events for each row
  when ((new.event_type = 'combat' and new.payload ->> 'rank' = 'guardian') or new.event_type in ('craft', 'expedition_end')) execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_lanterns;
create trigger trg_world_pet_skin after insert or update of catcher_id on public.world_lanterns for each row execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_hfeast_eats;
create trigger trg_world_pet_skin after insert on public.world_hfeast_eats for each row execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_hfeast_tables;
create trigger trg_world_pet_skin after update of status on public.world_hfeast_tables for each row when (new.status = 'open') execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_economy_ledger;
create trigger trg_world_pet_skin after insert on public.world_economy_ledger for each row when (new.action = 'trade_goods_sale') execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_ships;
create trigger trg_world_pet_skin after insert or update of tier on public.world_ships for each row execute function public.world_pet_skin_trg();
drop trigger if exists trg_world_pet_skin on public.world_trade_voyages;
create trigger trg_world_pet_skin after update of raid_done on public.world_trade_voyages for each row when (new.raid_done) execute function public.world_pet_skin_trg();

select pg_temp.yh_ps_share('public.world_pet_skin_need(jsonb)');
select pg_temp.yh_ps_share('public.world_pet_skin_prog(uuid,jsonb,jsonb)');
select pg_temp.yh_ps_share('public.world_pet_skin_check(uuid,text)');
select pg_temp.yh_ps_share('public.world_pet_skin_tally_add(uuid,text,bigint)');
select pg_temp.yh_ps_share('public.world_pet_skin_uses(text[],text,text)');
select pg_temp.yh_ps_share('public.world_pet_skin_book(uuid)');
select pg_temp.yh_ps_share('public.world_pet_skin_trg()');

select pg_temp.yh_ps_fix('world_pet_snapshot()', array[
$q$'slots', public.world_pet_slot_info(uid),$q$,
$q$'slots', public.world_pet_slot_info(uid),
    'skin_book', public.world_pet_skin_book(uid),$q$]);

select pg_temp.yh_ps_fix('world_notify_group(text)', array[
$q$when p_kind in ('reward', 'skill_rerank', 'outfit_got') then 'reward'$q$,
$q$when p_kind in ('reward', 'skill_rerank', 'outfit_got', 'pet_skin') then 'reward'$q$]);

select pg_temp.yh_ps_fix('world_character_purge(uuid)', array[
$q$  if p_uid is null then return; end if;$q$,
$q$  if p_uid is null then return; end if;
  delete from public.world_pet_skin_earned where owner_id = p_uid;
  delete from public.world_pet_skin_tally where owner_id = p_uid;$q$]);

insert into public.world_pet_skin_tally(owner_id, k, n)
select e.actor_id, k.value ->> 'k', count(*) from jsonb_each(public.world_pet_skin_rules() -> 'skins') k
  join public.world_events e on e.event_type = 'combat' and e.payload ->> 'rank' = 'guardian' and k.value -> 'regs' ? (e.payload ->> 'region_id')
 where k.value ->> 'by' = 'guard' and exists (select 1 from auth.users u where u.id = e.actor_id)
 group by 1, 2
on conflict (owner_id, k) do update set n = greatest(public.world_pet_skin_tally.n, excluded.n);
select public.world_pet_skin_check(c.owner_id) from public.world_characters c order by c.owner_id;
