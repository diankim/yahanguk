alter table public.world_gw_members add column if not exists weak jsonb not null default '[]'::jsonb;

create or replace function public.world_ug_weak(p_fight uuid, p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare w jsonb := public.world_ultimate_rules() -> 'weak'; r int; ex int[]; k int; strong boolean;
begin
  select g.round into r from public.world_gw_fights g where g.fight_id = p_fight and g.mode = 'ultimate';
  if r is null then return jsonb_build_object('n', 0, 'deal', 1, 'take', 1); end if;
  select array(select e::int from jsonb_array_elements_text(m.weak) e where e::int > r order by 1) into ex
    from public.world_gw_members m where m.fight_id = p_fight and m.owner_id = p_uid;
  k := coalesce(cardinality(ex), 0);
  if k = 0 then return jsonb_build_object('n', 0, 'deal', 1, 'take', 1); end if;
  strong := k >= (w ->> 'strong_at')::int;
  return jsonb_build_object('n', k, 'strong', strong, 'left', ex[1] - r,
    'name', case when strong then w ->> 'strong_name' else w ->> 'name' end,
    'deal', case when strong then 1 - (w ->> 'strong_deal')::numeric else greatest(0.1, 1 - (w ->> 'deal')::numeric * k) end,
    'take', case when strong then 1 + (w ->> 'strong_take')::numeric + (w ->> 'more_take')::numeric * (k - (w ->> 'strong_at')::int) else 1 + (w ->> 'take')::numeric * k end);
end $f$;

create or replace function public.world_ug_weak_add(p_fight uuid, p_uid uuid, p_round integer) returns void
language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare w jsonb := public.world_ultimate_rules() -> 'weak'; nm text; wk jsonb;
begin
  update public.world_gw_members y set weak = (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(y.weak) e where (e #>> '{}')::int > p_round)
      || to_jsonb(p_round + (w ->> 'rounds')::int)
   where y.fight_id = p_fight and y.owner_id = p_uid returning y.name into nm;
  if nm is null then return; end if;
  wk := public.world_ug_weak(p_fight, p_uid);
  perform public.world_gw_say(p_fight, p_round, 'bad', nm || ' — 수법을 놓쳐 「' || (wk ->> 'name') || '」 ' || (wk ->> 'n') || '겹(주는 피해 ×' || round((wk ->> 'deal')::numeric, 2)
    || ' · 받는 피해 ×' || round((wk ->> 'take')::numeric, 2) || ', ' || (w ->> 'rounds') || '라운드 뒤 한 겹씩 풀림).');
end $f$;

select pg_temp.yh_patch('public.world_gw_hurt(uuid,uuid,integer,integer,text)',
  $o$d int := greatest(0, p_dmg); v_n int; v_out int;
begin$o$,
  $n$d int := greatest(0, p_dmg); v_n int; v_out int;
begin
  if d > 0 and exists (select 1 from public.world_gw_members wm where wm.fight_id = p_fight and wm.owner_id = p_uid and wm.weak <> '[]'::jsonb) then
    d := round(d * (public.world_ug_weak(p_fight, p_uid) ->> 'take')::numeric)::int;
  end if;$n$);

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$      if f.boss_id = 'baekya' then d := d * public.world_by_on_attack(p_fight, m.owner_id, r); end if;$o$,
  $n$      if f.boss_id = 'baekya' then d := d * public.world_by_on_attack(p_fight, m.owner_id, r); end if;
      if f.mode = 'ultimate' and m.weak <> '[]'::jsonb then d := d * (public.world_ug_weak(p_fight, m.owner_id) ->> 'deal')::numeric; end if;$n$);

select pg_temp.yh_patch('public.world_ug_view(uuid,uuid)',
  $o$'act', (ug ->> 'act')::int, 'acts', (ug ->> 'acts')::int,$o$,
  $n$'act', (ug ->> 'act')::int, 'acts', (ug ->> 'acts')::int,
    'weak', (select coalesce(jsonb_object_agg(wm.owner_id::text, public.world_ug_weak(p_fight, wm.owner_id)), '{}'::jsonb) from public.world_gw_members wm where wm.fight_id = p_fight and wm.weak <> '[]'::jsonb),$n$);

revoke all on function public.world_ug_weak(uuid, uuid), public.world_ug_weak_add(uuid, uuid, integer) from public, anon, authenticated;
do $d$
declare o text;
begin
  for o in select rolname from pg_roles where rolname like 'fn_owner%' loop
    execute format('grant execute on function public.world_ug_weak(uuid, uuid), public.world_ug_weak_add(uuid, uuid, integer) to %I', o);
  end loop;
  execute 'grant execute on function public.world_ug_weak(uuid, uuid), public.world_ug_weak_add(uuid, uuid, integer) to service_role';
end $d$;
