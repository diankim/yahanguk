lock table public.world_characters in access exclusive mode;

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
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname in ('service_role', 'postgres') loop
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

create or replace function public.world_gw_ready_check(p_uid uuid, p_boss text default 'gwiheo', p_mode text default 'hard')
 returns void language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare c public.world_characters%rowtype; rec public.world_gw_records%rowtype; br jsonb := public.world_boss_rules() -> p_boss;
begin
  if br is null then raise exception '알 수 없는 우두머리입니다.'; end if;
  select * into c from public.world_characters where owner_id = p_uid;
  if p_boss = 'mukjeok' then
    if (public.world_region_at(c.location)).region_id is distinct from br ->> 'region' then raise exception '%에서만 %의 앞에 설 수 있습니다.', br ->> 'place', br ->> 'name'; end if;
    if c.level < (br ->> 'lv')::int then raise exception 'Lv%부터 도전할 수 있습니다.', br ->> 'lv'; end if;
    if br ->> 'quest' is not null and not public.world_quest_done(p_uid, br ->> 'quest') then raise exception '%을(를) 마쳐야 %의 앞에 설 수 있습니다.', br ->> 'quest_name', br ->> 'name'; end if;
    if p_mode = 'story' then return; end if;
    if not public.world_quest_done(p_uid, br ->> 'hard_quest') then raise exception '%을(를) 마친 뒤에 더 깊은 명부가 열립니다.', br ->> 'hard_quest_name'; end if;
  else
    if (public.world_region_at(c.location)).region_id is distinct from br ->> 'region' then raise exception '귀허에서만 귀허의 주인 앞에 설 수 있습니다.'; end if;
    if not public.world_gwiheo_open(p_uid) then raise exception '귀허도에 아직 건너오지 못했습니다.'; end if;
    if c.level < (br ->> 'lv')::int then raise exception 'Lv%부터 도전할 수 있습니다.', br ->> 'lv'; end if;
    if not public.world_quest_done(p_uid, br ->> 'quest') then raise exception '외전 4장 「달 없는 장」을 마쳐야 귀허의 주인 앞에 설 수 있습니다.'; end if;
    if p_mode = 'story' then return; end if;
  end if;
  select * into rec from public.world_gw_records where owner_id = p_uid and boss_id = p_boss;
  if rec.last_kill_day = (now() at time zone 'Asia/Seoul')::date then
    raise exception '오늘은 이미 %. 내일(한국 시각 0시 뒤) 다시 도전할 수 있습니다.', case when p_boss = 'mukjeok' then '먹그림자를 보냈습니다' else '귀허의 주인을 쓰러뜨렸습니다' end;
  end if;
  if rec.last_fail_at > now() - make_interval(mins => (br -> 'fail' ->> 'cd')::int) then
    raise exception '%. %분 뒤 다시 도전할 수 있습니다.', case when p_boss = 'mukjeok' then '명부의 먹이 아직 마르지 않았습니다' else '귀허의 소용돌이가 아직 가라앉지 않았습니다' end,
      ceil(extract(epoch from rec.last_fail_at + make_interval(mins => (br -> 'fail' ->> 'cd')::int) - now()) / 60);
  end if;
  if coalesce((c.inventory ->> (br ->> 'item'))::int, 0) < 1 then raise exception '%이(가) 필요합니다. %에서 팝니다.', br ->> 'item_name', br ->> 'shop_name'; end if;
end $f$;

create or replace function public.world_gw_ready(p_uid uuid, p_boss text default 'gwiheo', p_mode text default 'hard')
 returns public.world_characters language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare c public.world_characters%rowtype;
begin
  if public.world_boss_rules() -> p_boss is null then raise exception '알 수 없는 우두머리입니다.'; end if;
  select * into c from public.world_characters where owner_id = p_uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 도전할 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 도전할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = p_uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '요괴와 싸우는 중입니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then raise exception '원정 중에는 도전할 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = 'active') then raise exception '자율 활동 중에는 도전할 수 없습니다.'; end if;
  perform public.world_gw_ready_check(p_uid, p_boss, p_mode);
  if exists (select 1 from public.world_gw_members m join public.world_gw_fights f using (fight_id) where m.owner_id = p_uid and f.status in ('wait', 'fight')) then
    raise exception '이미 %와(과) 싸우는 중입니다.', (select public.world_boss_rules() -> x.boss_id ->> 'name' from public.world_gw_members m join public.world_gw_fights x using (fight_id)
      where m.owner_id = p_uid and x.status in ('wait', 'fight') limit 1); end if;
  return c;
end $f$;

drop function if exists public.world_gw_invitable(uuid);
create or replace function public.world_gw_invitable(p_uid uuid, p_boss text, p_mode text)
returns boolean language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
begin
  if public.world_busy_kind(p_uid) is not null then return false; end if;
  if exists (select 1 from public.world_gw_members m join public.world_gw_fights f using (fight_id) where m.owner_id = p_uid and f.status in ('wait', 'fight')) then return false; end if;
  perform public.world_gw_ready_check(p_uid, p_boss, p_mode);
  return true;
exception when others then return false;
end $f$;
grant execute on function public.world_busy_kind(uuid) to fn_owner_field;
select pg_temp.yh_share('public.world_gw_invitable(uuid, text, text)');
select pg_temp.yh_own('public.world_gw_invitable(uuid, text, text)', 'fn_owner_field');

select pg_temp.yh_fix('world_gw_open', array[
$q$join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null;$q$,
$q$join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null and public.world_gw_invitable(b.owner_id, boss, md);$q$,
$q$join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null limit 3 loop$q$,
$q$join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null and public.world_gw_invitable(b.owner_id, boss, md) limit 3 loop$q$]);

select pg_temp.yh_fix('world_mk_settle', array[
$q$if xp > 0 then perform public.world_grant_xp(m.owner_id, xp); end if;$q$,
$q$if xp > 0 then xp := (public.world_grant_xp_got(m.owner_id, xp) ->> 'xp')::int; end if;$q$]);

select pg_temp.yh_fix('world_battle_open', array[
$q$  lv := greatest(1, lv);$q$,
$q$  lv := least(greatest(lv, m.min_level), public.world_level_cap() + CASE rk WHEN 'normal' THEN 0 ELSE 1 END);
  lv := greatest(1, lv);$q$]);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116170000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
