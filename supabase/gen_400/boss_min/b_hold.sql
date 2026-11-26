drop function if exists public.world_gw_hold(uuid, boolean);

create or replace function public.world_hold_rules()
 returns jsonb language sql immutable set search_path = ''
as $f$ select '{"stances": {"hold": {"name": "버팀 태세", "guard": 35, "dmg": -15, "presence": 40, "no": ["shields", "healers"]},
  "rush": {"name": "몰아치기 태세", "guard": -10, "dmg": 20, "presence": 0, "no": ["shields"]}},
  "shields": ["artificer", "bloodknight"], "healers": ["medic", "formation"], "bosses": ["dohaesu", "ttangul"], "modes": ["hard"]}'::jsonb $f$;

create or replace function public.world_hold_can(p_fight uuid, p_kind text)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_hold_rules(); f public.world_gw_fights%rowtype; st jsonb := public.world_hold_rules() -> 'stances' -> p_kind;
begin
  if st is null then return false; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if not found or not (r -> 'bosses' ? f.boss_id) or not (r -> 'modes' ? f.mode) then return false; end if;
  return not exists (select 1 from public.world_gw_members m, jsonb_array_elements_text(st -> 'no') g where m.fight_id = p_fight and r -> g ? m.job_key);
end $f$;

create or replace function public.world_hold_view(p_fight uuid, p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_hold_rules(); f public.world_gw_fights%rowtype; me public.world_gw_members%rowtype; k text; out jsonb := '{}'::jsonb;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if not found or not (r -> 'bosses' ? f.boss_id) or not (r -> 'modes' ? f.mode) then return null; end if;
  select * into me from public.world_gw_members where fight_id = p_fight and owner_id = p_uid;
  for k in select jsonb_object_keys(r -> 'stances') loop
    out := out || jsonb_build_object(k, (r -> 'stances' -> k) - 'no' || jsonb_build_object('can', f.status = 'wait' and me.owner_id is not null and public.world_hold_can(p_fight, k),
      'who', (select coalesce(jsonb_agg(m.owner_id), '[]'::jsonb) from public.world_gw_members m where m.fight_id = p_fight and coalesce(m.fx ->> 'hold', m.stats ->> 'hold') = k)));
  end loop;
  return jsonb_build_object('stances', out, 'mine', coalesce(me.fx ->> 'hold', me.stats ->> 'hold'));
end $f$;

create or replace function public.world_gw_hold(p_fight uuid, p_kind text)
 returns jsonb language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; st jsonb := public.world_hold_rules() -> 'stances' -> p_kind;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if not found or f.status <> 'wait' then raise exception '모이는 중에만 고를 수 있습니다.'; end if;
  if not exists (select 1 from public.world_gw_members where fight_id = p_fight and owner_id = uid) then raise exception '이 도전에 든 조사원만 고를 수 있습니다.'; end if;
  if p_kind is not null and st is null then raise exception '알 수 없는 태세입니다.'; end if;
  if p_kind is not null and not public.world_hold_can(p_fight, p_kind) then
    raise exception '% 직업이 함께하면 %을(를) 쓸 수 없습니다.', case when st -> 'no' ? 'healers' then '방패(호위 무사·혈기사)나 치유(의무관·진법가)' else '방패(호위 무사·혈기사)' end, st ->> 'name'; end if;
  update public.world_gw_members set fx = case when p_kind is not null then coalesce(fx, '{}'::jsonb) || jsonb_build_object('hold', p_kind) else coalesce(fx, '{}'::jsonb) - 'hold' end
   where fight_id = p_fight and owner_id = uid;
  return public.world_gw_snapshot(p_fight);
end $f$;

create or replace function public.world_hold_apply(p_fight uuid)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_hold_rules(); x record; st jsonb;
begin
  for x in select owner_id, fx ->> 'hold' k from public.world_gw_members where fight_id = p_fight and fx ? 'hold' loop
    st := r -> 'stances' -> x.k;
    if st is not null and public.world_hold_can(p_fight, x.k) then
      update public.world_gw_members set stats = stats || jsonb_build_object('solo_guard', (st ->> 'guard')::int, 'solo_dmg', (st ->> 'dmg')::int, 'hold', x.k,
        'presence', coalesce((stats ->> 'presence')::numeric, 30) + coalesce((st ->> 'presence')::numeric, 0))
       where fight_id = p_fight and owner_id = x.owner_id;
    end if;
  end loop;
  update public.world_gw_members set fx = fx - 'hold' where fight_id = p_fight and fx ? 'hold';
end $f$;

revoke all on function public.world_hold_can(uuid, text), public.world_hold_view(uuid, uuid), public.world_hold_apply(uuid), public.world_gw_hold(uuid, text) from public, anon, authenticated;
grant execute on function public.world_hold_can(uuid, text), public.world_hold_view(uuid, uuid), public.world_hold_apply(uuid) to service_role, fn_owner_field;
grant execute on function public.world_gw_hold(uuid, text) to authenticated, service_role;
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
