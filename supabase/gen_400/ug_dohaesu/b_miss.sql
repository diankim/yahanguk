do $$
declare r jsonb := public.world_boss_rules();
begin
  r := jsonb_set(r, '{dohaesu,ultimate,board,fail_party}', '{"raw": 15}'::jsonb);
  r := jsonb_set(r, '{ttangul,ultimate,board,fail_party}', '{"raw": 15}'::jsonb);
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
end $$;

create or replace function public.world_ug_sea_miss(p_fight uuid, p_uid uuid, p_round integer, p_why text)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare b jsonb;
begin
  select board into b from public.world_gw_fights where fight_id = p_fight and mode = 'ultimate' and boss_id in ('dohaesu', 'ttangul') for update;
  if b is null then return; end if;
  perform public.world_ug_weak_add(p_fight, p_uid, p_round);
  b := coalesce(b -> 'ugm', '{}'::jsonb);
  if coalesce((b ->> 'r')::int, -1) <> p_round then b := jsonb_build_object('r', p_round, 'w', '[]'::jsonb); end if;
  if not b -> 'w' ? coalesce(p_why, '') then b := jsonb_set(b, '{w}', (b -> 'w') || to_jsonb(coalesce(p_why, ''))); end if;
  update public.world_gw_fights set board = board || jsonb_build_object('ugm', b) where fight_id = p_fight;
end $f$;

create or replace function public.world_ug_sea_flush(p_fight uuid, p_round integer)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare f public.world_gw_fights%rowtype; n int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.mode <> 'ultimate' or f.boss_id not in ('dohaesu', 'ttangul') or coalesce((f.board -> 'ugm' ->> 'r')::int, -1) <> p_round then return; end if;
  n := jsonb_array_length(coalesce(f.board -> 'ugm' -> 'w', '[]'::jsonb));
  update public.world_gw_fights set board = board - 'ugm' where fight_id = p_fight;
  perform public.world_ug_fail(p_fight, p_round, n, coalesce((public.world_boss_fight_rules(p_fight) -> 'board' -> 'fail_party' ->> 'raw')::numeric, 0), false);
end $f$;

revoke all on function public.world_ug_sea_miss(uuid, uuid, integer, text), public.world_ug_sea_flush(uuid, integer) from public, anon, authenticated;
grant execute on function public.world_ug_sea_miss(uuid, uuid, integer, text), public.world_ug_sea_flush(uuid, integer) to service_role, fn_owner_field;

select pg_temp.yh_patch('public.world_dh_dmg(uuid,uuid,numeric,integer,text,boolean)',
  $q$  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight;$q$,
  $q$  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  perform public.world_ug_sea_miss(p_fight, p_uid, p_round, p_why);
  select * into f from public.world_gw_fights where fight_id = p_fight;$q$);
select pg_temp.yh_patch('public.world_du_dmg(uuid,uuid,numeric,integer,text,numeric)',
  $q$  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight;$q$,
  $q$  if not found or m.out_rounds > 0 or m.rest then return 0; end if;
  perform public.world_ug_sea_miss(p_fight, p_uid, p_round, p_why);
  select * into f from public.world_gw_fights where fight_id = p_fight;$q$);
select pg_temp.yh_patch('public.world_dh_fall(uuid,uuid,integer,text)',
  $q$  if not found or m.out_rounds > 0 then return; end if;
  if fh is not null then$q$,
  $q$  if not found or m.out_rounds > 0 then return; end if;
  perform public.world_ug_sea_miss(p_fight, p_uid, p_round, p_why);
  if fh is not null then$q$);
select pg_temp.yh_patch('public.world_du_fall(uuid,uuid,integer,text)',
  $q$  if not found or m.out_rounds > 0 then return; end if;
  if fh is not null then$q$,
  $q$  if not found or m.out_rounds > 0 then return; end if;
  perform public.world_ug_sea_miss(p_fight, p_uid, p_round, p_why);
  if fh is not null then$q$);
select pg_temp.yh_patch('public.world_ug_after(uuid,integer)',
  $q$  if coalesce((ug ->> 'rest')::int, 0) > 0 then return false; end if;$q$,
  $q$  if coalesce((ug ->> 'rest')::int, 0) > 0 then return false; end if;
  perform public.world_ug_sea_flush(p_fight, p_round);
  select * into f from public.world_gw_fights where fight_id = p_fight;
  if f.status <> 'fight' then return true; end if;$q$);

select pg_temp.yh_fix('world_ug_round', array[
  $q$|| case when x.gval is not null then ' ' || x.gval || '섬' else '' end$q$,
  $q$|| case when x.gval is not null and f.boss_id = 'gapgwi' then ' ' || x.gval || '섬' else '' end$q$]);
