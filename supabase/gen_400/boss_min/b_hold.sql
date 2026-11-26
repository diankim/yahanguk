create or replace function public.world_hold_rules()
 returns jsonb language sql immutable set search_path = ''
as $f$ select '{"name": "버팀 태세", "guard": 25, "dmg": -15, "shields": ["artificer", "bloodknight"], "healers": ["medic", "formation"], "bosses": ["dohaesu", "ttangul"], "modes": ["hard"]}'::jsonb $f$;

create or replace function public.world_hold_can(p_fight uuid)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_hold_rules(); f public.world_gw_fights%rowtype;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if not found or not (r -> 'bosses' ? f.boss_id) or not (r -> 'modes' ? f.mode) then return false; end if;
  return not exists (select 1 from public.world_gw_members m where m.fight_id = p_fight and (r -> 'shields' ? m.job_key or r -> 'healers' ? m.job_key));
end $f$;

create or replace function public.world_hold_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_hold_rules(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if not found or not (r -> 'bosses' ? f.boss_id) or not (r -> 'modes' ? f.mode) then return null; end if;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  return jsonb_build_object('name', r ->> 'name', 'guard', (r ->> 'guard')::int, 'dmg', (r ->> 'dmg')::int,
    'can', f.status = 'wait' and public.world_hold_can(p_fight) and me.owner_id is not null,
    'on', coalesce(me.fx ? 'hold', false) or coalesce((me.stats ->> 'hold')::boolean, false),
    'shield', not public.world_hold_can(p_fight),
    'who', (select coalesce(jsonb_agg(m.owner_id), '[]'::jsonb) from public.world_gw_members m where m.fight_id = p_fight and (m.fx ? 'hold' or coalesce((m.stats ->> 'hold')::boolean, false))));
end $f$;

create or replace function public.world_gw_hold(p_fight uuid, p_on boolean)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if not found or f.status <> 'wait' then raise exception '모이는 중에만 고를 수 있습니다.'; end if;
  if not exists (select 1 from public.world_gw_members where fight_id = p_fight and owner_id = uid) then raise exception '이 도전에 든 조사원만 고를 수 있습니다.'; end if;
  if p_on and not public.world_hold_can(p_fight) then raise exception '방패(호위 무사·혈기사)나 치유(의무관·진법가)가 함께하면 %를 쓰지 않습니다.', public.world_hold_rules() ->> 'name'; end if;
  update public.world_gw_members set fx = case when p_on then coalesce(fx, '{}'::jsonb) || '{"hold": true}'::jsonb else coalesce(fx, '{}'::jsonb) - 'hold' end
   where fight_id = p_fight and owner_id = uid;
  return public.world_gw_snapshot(p_fight);
end $f$;

create or replace function public.world_hold_apply(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_hold_rules();
begin
  if public.world_hold_can(p_fight) then
    update public.world_gw_members set stats = stats || jsonb_build_object('solo_guard', (r ->> 'guard')::int, 'solo_dmg', (r ->> 'dmg')::int, 'hold', true)
     where fight_id = p_fight and fx ? 'hold';
  end if;
  update public.world_gw_members set fx = fx - 'hold' where fight_id = p_fight and fx ? 'hold';
end $f$;

revoke all on function public.world_hold_can(uuid), public.world_hold_view(uuid, uuid), public.world_hold_apply(uuid), public.world_gw_hold(uuid, boolean) from public, anon, authenticated;
grant execute on function public.world_hold_can(uuid), public.world_hold_view(uuid, uuid), public.world_hold_apply(uuid) to service_role, fn_owner_field;
grant execute on function public.world_gw_hold(uuid, boolean) to authenticated, service_role;
grant execute on function public.world_hold_rules() to authenticated, service_role, fn_owner_field;

select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$    perform public.world_dh_begin(p_fight, n);$o$,
  $n$    perform public.world_hold_apply(p_fight);
    perform public.world_dh_begin(p_fight, n);$n$);
select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$    perform public.world_du_begin(p_fight, n);$o$,
  $n$    perform public.world_hold_apply(p_fight);
    perform public.world_du_begin(p_fight, n);$n$);
select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$    'solo', case when$o$,
  $n$    'hold', public.world_hold_view(fid, uid),
    'solo', case when$n$);
