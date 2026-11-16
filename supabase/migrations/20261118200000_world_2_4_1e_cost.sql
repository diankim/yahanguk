create or replace function public.world_xp_avg_refresh()
 returns numeric
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v numeric; r jsonb := public.world_xp_lead_rules();
begin
  with b as (
    select distinct e.actor_id, floor(extract(epoch from e.created_at) / 600) k from public.world_events e
     where e.created_at > now() - make_interval(days => (r ->> 'active_days')::int)),
  act as (
    select b.actor_id from b group by b.actor_id
    having count(*) >= ceil(coalesce((r ->> 'active_min')::numeric, 10) / 10))
  select round(avg(c.level), 2) into v from public.world_characters c
    join act on act.actor_id = c.owner_id
   where not exists (select 1 from public.world_staff s where s.owner_id = c.owner_id);
  insert into public.world_app_meta(key, value) values ('xp_avg_level', coalesce(v, 1)::text)
  on conflict (key) do update set value = excluded.value;
  return v;
end $function$;

update public.world_app_meta set value = '20261118200000' where key = 'db_version';
