create or replace function public.world_xp_lead_rules() returns jsonb language sql immutable as $f$
  select jsonb_build_object('lead', 3, 'active_days', 3,
    'steps', jsonb_build_array(jsonb_build_array(3, 85), jsonb_build_array(5, 70), jsonb_build_array(7, 55),
                               jsonb_build_array(9, 40), jsonb_build_array(11, 30), jsonb_build_array(13, 20)))
$f$;
revoke all on function public.world_xp_lead_rules() from public, anon, authenticated;

create or replace function public.world_xp_avg_refresh() returns numeric
language plpgsql security definer set search_path = '' as $f$
declare v numeric;
begin
  select round(avg(c.level), 2) into v from public.world_characters c
   where not exists (select 1 from public.world_staff s where s.owner_id = c.owner_id)
     and exists (select 1 from public.world_events e where e.actor_id = c.owner_id
                  and e.created_at > now() - make_interval(days => (public.world_xp_lead_rules() ->> 'active_days')::int));
  insert into public.world_app_meta(key, value) values ('xp_avg_level', coalesce(v, 1)::text)
  on conflict (key) do update set value = excluded.value;
  return v;
end $f$;
revoke all on function public.world_xp_avg_refresh() from public, anon, authenticated;
select public.world_xp_avg_refresh();
select cron.unschedule(jobid) from cron.job where jobname = 'yh-xp-avg';
select cron.schedule('yh-xp-avg', '*/30 * * * *', 'select public.world_xp_avg_refresh()');

create or replace function public.world_xp_damp_apply() returns trigger
language plpgsql security definer set search_path = '' as $f$
declare d public.world_xp_damp%rowtype; r jsonb := public.world_xp_lead_rules(); top int; avg_lv numeric; gain bigint; tot bigint; nl int := 1;
        gap numeric; pct numeric := 100; p numeric;
begin
  if new.experience is not distinct from old.experience and new.level is not distinct from old.level then return new; end if;
  if old.level >= 40 or exists (select 1 from public.world_staff s where s.owner_id = new.owner_id) then return new; end if;
  gain := public.world_xp_total(new.level, new.experience) - public.world_xp_total(old.level, old.experience);
  if gain <= 0 then return new; end if;
  select nullif(value, '')::numeric into avg_lv from public.world_app_meta where key = 'xp_avg_level';
  if avg_lv is not null and old.level - avg_lv >= (r ->> 'lead')::numeric then
    gap := old.level - avg_lv;
    p := (select (s ->> 1)::numeric from jsonb_array_elements(r -> 'steps') s where (s ->> 0)::numeric <= gap order by (s ->> 0)::numeric desc limit 1);
    if p is not null then pct := least(pct, p); end if;
  end if;
  select * into d from public.world_xp_damp where owner_id = new.owner_id and until > now();
  if found then
    select max(c.level) into top from public.world_characters c
     where c.owner_id <> new.owner_id and not exists (select 1 from public.world_staff s where s.owner_id = c.owner_id);
    if old.level - coalesce(top, 0) >= d.lead then
      pct := least(pct, coalesce((select (s ->> 1)::numeric from jsonb_array_elements(d.steps) s where (s ->> 0)::int <= old.level - coalesce(top, 0) order by (s ->> 0)::int desc limit 1), d.pct));
    end if;
  end if;
  if pct >= 100 then return new; end if;
  tot := public.world_xp_total(old.level, old.experience) + round(gain * pct / 100.0);
  while nl < 40 and tot >= public.world_xp_need(nl) loop tot := tot - public.world_xp_need(nl); nl := nl + 1; end loop;
  new.stat_points := least(117, greatest(0, new.stat_points + 3 * (nl - new.level)));
  new.level := nl;
  new.experience := case when nl >= 40 then 0 else tot end;
  return new;
end $f$;
revoke all on function public.world_xp_damp_apply() from public, anon, authenticated;
