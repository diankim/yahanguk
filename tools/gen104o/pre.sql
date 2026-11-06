create or replace function public.world_contrib_rules()
 returns jsonb
 language sql
 immutable
 set search_path to 'pg_catalog'
as $function$
  select '{"deal": 0.5, "hold": 0.3, "heal": 0.1, "boost": 0.1, "result": 0.2, "eff_cap": 2, "press": 1, "heal_need": 0.25, "boost_need": 0.1}'::jsonb
$function$;

create or replace function public.world_shadow_rules()
 returns jsonb
 language sql
 immutable
 set search_path to 'pg_catalog'
as $function$
  select '{"hp_mul": 350, "hp_min": 9000, "dmg_mul": 1.4, "pow_lo": 0.75, "pow_hi": 1.5, "charge_mul": 5, "stay_full": 0.5, "gil_lv": 20}'::jsonb
$function$;

create or replace function public.world_contrib_shares(p_rows jsonb)
 returns jsonb
 language plpgsql
 immutable
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_contrib_rules(); res jsonb;
begin
  with m as (
    select x ->> 'id' id,
           coalesce((x -> 'cr' ->> 'dmg')::numeric, 0) dmg,
           coalesce((x -> 'cr' ->> 'boost')::numeric, 0) boost,
           coalesce((x -> 'cr' ->> 'heal')::numeric, 0) heal,
           coalesce((x -> 'cr' ->> 'taken')::numeric, 0) taken,
           coalesce((x -> 'cr' ->> 'guard')::numeric, 0) guard,
           coalesce((x -> 'cr' ->> 'guard')::numeric, 0) + coalesce((x -> 'cr' ->> 'hit1')::numeric, 0) hold,
           nullif((x ->> 'atk')::numeric, 0) atk,
           coalesce(x -> 'cr', '{}'::jsonb) <> '{}'::jsonb active
      from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) x),
  a as (select coalesce(avg(atk), 1) aa, greatest(1, count(*) filter (where active)) n from m),
  e as (select m.*, m.dmg / greatest(coalesce(m.atk, a.aa), a.aa / (r ->> 'eff_cap')::numeric, 1) eff from m, a),
  t as (select sum(dmg) d, sum(eff) ef, sum(hold) h, sum(heal) hl, sum(boost) b, sum(taken) tk, sum(taken + guard) pr from e),
  w as (select (r ->> 'deal')::numeric * (t.d > 0)::int wd,
               (r ->> 'hold')::numeric * (t.h > 0)::int * least(1, t.pr / (a.n * 100 * (r ->> 'press')::numeric)) wh,
               (r ->> 'heal')::numeric * (t.hl > 0)::int * least(1, t.pr / (a.n * 100 * (r ->> 'press')::numeric))
                 * least(1, t.hl / greatest(1, (r ->> 'heal_need')::numeric * t.tk)) whl,
               (r ->> 'boost')::numeric * (t.b > 0)::int * least(1, t.b / greatest(1, (r ->> 'boost_need')::numeric * t.d)) wb
          from t, a),
  s as (select e.id,
               w.wd * case when t.d > 0 then (r ->> 'result')::numeric * e.dmg / t.d + (1 - (r ->> 'result')::numeric) * e.eff / t.ef else 0 end
             + w.wh * case when t.h > 0 then e.hold / t.h else 0 end
             + w.whl * case when t.hl > 0 then e.heal / t.hl else 0 end
             + w.wb * case when t.b > 0 then e.boost / t.b else 0 end v
          from e, t, w)
  select coalesce(jsonb_object_agg(s.id, case when z.tot > 0 then round(s.v / z.tot * 100, 1) else 0 end), '{}'::jsonb) into res
    from s, (select sum(v) tot from s) z;
  return res;
end $function$;
revoke all on function public.world_contrib_rules() from public, anon, authenticated;
revoke all on function public.world_shadow_rules() from public, anon, authenticated;
revoke all on function public.world_contrib_shares(jsonb) from public, anon, authenticated;
grant execute on function public.world_contrib_rules() to fn_owner_field, service_role;
grant execute on function public.world_shadow_rules() to fn_owner_field, service_role;
grant execute on function public.world_contrib_shares(jsonb) to fn_owner_field, service_role;

create or replace function public.world_raid_shares(p_raid uuid)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select public.world_contrib_shares(coalesce(jsonb_agg(jsonb_build_object('id', owner_id, 'cr', credits, 'atk', (stats ->> 'attack')::numeric)), '[]'::jsonb))
    from public.world_raid_members where raid_id = p_raid
$function$;
revoke all on function public.world_raid_shares(uuid) from public, anon, authenticated;
grant execute on function public.world_raid_shares(uuid) to fn_owner_field, service_role;

create or replace function public.world_raid_recontrib(p_raid uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare s jsonb := public.world_raid_shares(p_raid);
begin
  update public.world_raid_members x set contrib = coalesce((s ->> x.owner_id::text)::numeric, 0)
   where x.raid_id = p_raid and x.credits <> '{}'::jsonb;
end $function$;

create or replace function public.world_gw_shares(p_fight uuid)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select public.world_contrib_shares(coalesce(jsonb_agg(jsonb_build_object('id', owner_id, 'cr', credits, 'atk', (stats ->> 'attack')::numeric)), '[]'::jsonb))
    from public.world_gw_members where fight_id = p_fight
$function$;

create or replace function public.world_pfight_shares(p_fight uuid)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select public.world_contrib_shares(coalesce(jsonb_agg(jsonb_build_object('id', pm.owner_id,
           'cr', case when pm.dmg > 0 or pm.taken > 0 then jsonb_build_object('dmg', pm.dmg, 'taken', pm.taken, 'hit1', pm.taken) else '{}'::jsonb end,
           'atk', (select (o ->> 'atk')::numeric from jsonb_array_elements(coalesce(f.turn_order, '[]'::jsonb)) o where (o ->> 'id')::uuid = pm.owner_id limit 1))), '[]'::jsonb))
    from public.world_pfight_members pm join public.world_pfights f on f.fight_id = pm.fight_id where pm.fight_id = p_fight
$function$;
