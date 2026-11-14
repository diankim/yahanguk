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

create or replace function public.world_safe_near(p_location text, p_level int)
returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare r public.world_map_regions%rowtype := public.world_field_region(p_location); s text;
begin
  select x.region_id into s from public.world_map_regions x where x.is_safe_zone and x.active and x.min_level <= p_level
   order by (x.territory_id is distinct from r.territory_id), (x.world_x - coalesce(r.world_x, 480)) ^ 2 + (x.world_y - coalesce(r.world_y, 360)) ^ 2 limit 1;
  return s;
end $$;
select pg_temp.yh_share('public.world_safe_near(text, int)');
select pg_temp.yh_own('public.world_safe_near(text, int)', 'fn_owner_field');

select pg_temp.yh_fix('world_call_rescue', array[
$q$SELECT * INTO s FROM public.world_map_regions x WHERE x.is_safe_zone AND x.active AND x.min_level <= c.level$q$,
$q$SELECT * INTO s FROM public.world_map_regions x WHERE x.region_id = public.world_safe_near(c.location, c.level)$q$,
$q$ORDER BY (x.world_x - coalesce(r.world_x, 480)) ^ 2 + (x.world_y - coalesce(r.world_y, 360)) ^ 2 LIMIT 1;$q$,
$q$LIMIT 1;$q$]);

select pg_temp.yh_fix('world_yohwa_seal', array[
$q$select * into z from public.world_map_regions x where x.is_safe_zone and x.active and x.min_level <= c.level$q$,
$q$select * into z from public.world_map_regions x where x.region_id = public.world_safe_near(c.location, c.level)$q$,
$q$order by (x.world_x - coalesce(r.world_x, 480)) ^ 2 + (x.world_y - coalesce(r.world_y, 360)) ^ 2 limit 1;$q$,
$q$limit 1;$q$]);

select pg_temp.yh_fix('world_battle_action', array[
$q$'xp', xp + 24,$q$, $q$'xp', xp + 12,$q$,
$q$v_pfx := v_pfx || jsonb_build_object('u_gd', coalesce((v_pfx ->> 'u_gd')::int, 0) + 1, 'gd_last', true);$q$,
$q$v_pfx := v_pfx || jsonb_build_object('u_gd', coalesce((v_pfx ->> 'u_gd')::int, 0) + case when a.current_hp > 0 then 1 else 0 end, 'gd_last', true);$q$]);

select pg_temp.yh_fix('world_pfight_resolve', array[
$q$      perform set_config('yh.pf_n', alive::text, true);$q$,
$q$      perform set_config('yh.pf_n', (select count(*) from public.world_pfight_members where fight_id = p_fight and coalesce(out_reason, '') not in ('fled', 'gone'))::text, true);$q$,
$q$        perform set_config('yh.pf_skip', '1', true);$q$,
$q$        perform set_config('yh.pf_skip', '1', true);
        perform set_config('yh.pf_n', (select count(*) from public.world_pfight_members where fight_id = p_fight and coalesce(out_reason, '') not in ('fled', 'gone'))::text, true);$q$]);

create or replace function public.world_grant_xp_got(p_uid uuid, p_xp int)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare l0 int; e0 bigint; l1 int; e1 bigint; got bigint; lv int; ups int;
begin
  select level, experience into l0, e0 from public.world_characters where owner_id = p_uid for update;
  if l0 is null then return jsonb_build_object('levels', 0, 'xp', 0); end if;
  ups := public.world_grant_xp(p_uid, p_xp);
  select level, experience into l1, e1 from public.world_characters where owner_id = p_uid;
  if l1 = l0 then got := e1 - e0;
  else
    got := public.world_xp_need(l0) - e0 + e1;
    for lv in l0 + 1 .. l1 - 1 loop got := got + public.world_xp_need(lv); end loop;
  end if;
  return jsonb_build_object('levels', coalesce(ups, 0), 'xp', greatest(0, got));
end $$;
select pg_temp.yh_share('public.world_grant_xp_got(uuid, int)');
select pg_temp.yh_own('public.world_grant_xp_got(uuid, int)', 'fn_owner_field');

select pg_temp.yh_fix('world_quest_report', array[
$q$gained int := 0;$q$, $q$gained int := 0; gx jsonb;$q$,
$q$if rw_xp > 0 then gained := public.world_grant_xp(uid, rw_xp); msg := msg || '경험치 ' || rw_xp || ' · '; end if;$q$,
$q$if rw_xp > 0 then gx := public.world_grant_xp_got(uid, rw_xp); gained := (gx ->> 'levels')::int; msg := msg || '경험치 ' || (gx ->> 'xp') || ' · '; end if;$q$]);

select pg_temp.yh_fix('world_commission_claim', array[
$q$today date := (now() AT TIME ZONE 'Asia/Seoul')::date;$q$, $q$today date := (now() AT TIME ZONE 'Asia/Seoul')::date; xg text;$q$,
$q$  PERFORM public.world_grant_xp(uid, m.reward_xp);$q$, $q$  xg := public.world_grant_xp_got(uid, m.reward_xp) ->> 'xp';$q$,
$q$'전, 경험치 ' || m.reward_xp);$q$, $q$'전, 경험치 ' || xg);$q$]);

select pg_temp.yh_fix('world_ucomm_fulfill', array[
$q$ nm text;$q$, $q$ nm text; xg text;$q$,
$q$    perform public.world_grant_xp(uid, xp);$q$, $q$    xg := public.world_grant_xp_got(uid, xp) ->> 'xp';$q$,
$q$then ' · 경험치 ' || xp else$q$, $q$then ' · 경험치 ' || xg else$q$]);

select pg_temp.yh_fix('world_raid_settle', array[
$q$ room int;$q$, $q$ room int; xg text;$q$,
$q$if xp > 0 then perform public.world_grant_xp(m.owner_id, xp); end if;$q$,
$q$xg := '0'; if xp > 0 then xg := public.world_grant_xp_got(m.owner_id, xp) ->> 'xp'; end if;$q$,
$q$' · 경험치 ' || round(xp * public.world_xp_damp_pct(m.owner_id, m.clv) / 100.0)$q$, $q$' · 경험치 ' || xg$q$]);

select pg_temp.yh_fix('world_gw_settle', array[
$q$        perform public.world_grant_xp(m.owner_id, xp);$q$,
$q$        xp := (public.world_grant_xp_got(m.owner_id, xp) ->> 'xp')::int;$q$]);

create or replace function public.world_gw_ready_check(p_uid uuid)
returns void language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype; rec public.world_gw_records%rowtype;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  if (public.world_region_at(c.location)).region_id is distinct from 'gwiheo_core' then raise exception '귀허에서만 귀허의 주인 앞에 설 수 있습니다.'; end if;
  if not public.world_gwiheo_open(p_uid) then raise exception '귀허도에 아직 건너오지 못했습니다.'; end if;
  if c.level < 38 then raise exception 'Lv38부터 도전할 수 있습니다.'; end if;
  if not public.world_quest_done(p_uid, 'gq_4') then raise exception '외전 4장 「달 없는 장」을 마쳐야 귀허의 주인 앞에 설 수 있습니다.'; end if;
  select * into rec from public.world_gw_records where owner_id = p_uid;
  if rec.last_kill_day = (now() at time zone 'Asia/Seoul')::date then raise exception '오늘은 이미 귀허의 주인을 쓰러뜨렸습니다. 내일(한국 시각 0시 뒤) 다시 도전할 수 있습니다.'; end if;
  if rec.last_fail_at > now() - interval '30 minutes' then
    raise exception '귀허의 소용돌이가 아직 가라앉지 않았습니다. %분 뒤 다시 도전할 수 있습니다.', ceil(extract(epoch from rec.last_fail_at + interval '30 minutes' - now()) / 60);
  end if;
  if coalesce((c.inventory ->> 'gwiheo_charm')::int, 0) < 1 then raise exception '귀허 부적이 필요합니다. 반요촌 잡화에서 팝니다.'; end if;
end $$;

create or replace function public.world_gw_ready(p_uid uuid)
returns public.world_characters language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare c public.world_characters%rowtype;
begin
  select * into c from public.world_characters where owner_id = p_uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 도전할 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 도전할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = p_uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '요괴와 싸우는 중입니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = 'active') then raise exception '원정 중에는 도전할 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = 'active') then raise exception '자율 활동 중에는 도전할 수 없습니다.'; end if;
  perform public.world_gw_ready_check(p_uid);
  if exists (select 1 from public.world_gw_members m join public.world_gw_fights f using (fight_id) where m.owner_id = p_uid and f.status in ('wait', 'fight')) then
    raise exception '이미 귀허의 주인과 싸우는 중입니다.'; end if;
  return c;
end $$;

create or replace function public.world_gw_invitable(p_uid uuid)
returns boolean language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if public.world_busy_kind(p_uid) is not null then return false; end if;
  if exists (select 1 from public.world_gw_members m join public.world_gw_fights f using (fight_id) where m.owner_id = p_uid and f.status in ('wait', 'fight')) then return false; end if;
  perform public.world_gw_ready_check(p_uid);
  return true;
exception when others then return false;
end $$;
grant execute on function public.world_busy_kind(uuid) to fn_owner_field;
select pg_temp.yh_share('public.world_gw_invitable(uuid)');
select pg_temp.yh_own('public.world_gw_invitable(uuid)', 'fn_owner_field');

select pg_temp.yh_fix('world_gw_open', array[
$q$join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null;$q$,
$q$join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null and public.world_gw_invitable(b.owner_id);$q$,
$q$join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null limit 3 loop$q$,
$q$join public.world_characters o on o.owner_id = b.owner_id where a.owner_id = uid and o.location = c.location and o.downed_at is null and public.world_gw_invitable(b.owner_id) limit 3 loop$q$]);

update public.world_patch_notes set body = body || E'\n\n## 1.1.2b\n- 쓰러져 본부 구조대를 부르거나 요화로 봉인될 때, 지금 있는 영역의 안전지대로 옮겨집니다(그 영역에 안전지대가 없을 때만 가장 가까운 곳). 길이 이어지지 않은 다른 영역으로 옮겨지던 것을 고쳤습니다.\n- 현장 토벌 결과 창의 경험치가 실제로 받는 양보다 12 많게 보이던 것을 고쳤습니다.\n- 퀘스트 보고·상시 의뢰·조사원 의뢰·봉연의 그림자·귀허의 주인 보상 문구의 경험치를 실제로 들어간 양으로 적습니다. 최고 레벨이면 「경험치 0」으로 나옵니다.\n- 파티 토벌에서 마지막 한 방을 치지 않은 사람에게 막기 횟수가 붙던 것을 고쳤습니다.\n- 파티 토벌 경험치 동료 덤(한 명마다 +10%)에 도중에 쓰러진 동료도 셉니다. 달아나거나 자리를 떠난 사람만 빠집니다.\n- 귀허의 주인: 대기실 안내와 도전할 때의 거절 문구를 하나로 맞췄습니다. 오늘 이미 쓰러뜨렸거나 귀허 부적이 없는 등 지금 합류할 수 없는 파티원에게는 초대가 가지 않고, 초대받을 사람이 없으면 기다리지 않고 바로 시작합니다.'
 where note_id = '1.1.0' and position('## 1.1.2b' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261113060000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
