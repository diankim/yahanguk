alter table public.world_xp_damp add column if not exists steps jsonb;

create or replace function public.world_xp_damp_apply() returns trigger
language plpgsql security definer set search_path = '' as $f$
declare d public.world_xp_damp%rowtype; top int; gain bigint; tot bigint; nl int := 1; gap int; pct numeric;
begin
  if new.experience is not distinct from old.experience and new.level is not distinct from old.level then return new; end if;
  select * into d from public.world_xp_damp where owner_id = new.owner_id and until > now();
  if not found then return new; end if;
  gain := public.world_xp_total(new.level, new.experience) - public.world_xp_total(old.level, old.experience);
  if gain <= 0 or old.level >= 40 then return new; end if;
  select max(c.level) into top from public.world_characters c
   where c.owner_id <> new.owner_id and not exists (select 1 from public.world_staff s where s.owner_id = c.owner_id);
  gap := old.level - coalesce(top, 0);
  if gap < d.lead then return new; end if;
  pct := coalesce((select (s ->> 1)::numeric from jsonb_array_elements(d.steps) s where (s ->> 0)::int <= gap order by (s ->> 0)::int desc limit 1), d.pct);
  tot := public.world_xp_total(old.level, old.experience) + round(gain * pct / 100.0);
  while nl < 40 and tot >= public.world_xp_need(nl) loop tot := tot - public.world_xp_need(nl); nl := nl + 1; end loop;
  new.stat_points := least(117, greatest(0, new.stat_points + 3 * (nl - new.level)));
  new.level := nl;
  new.experience := case when nl >= 40 then 0 else tot end;
  return new;
end $f$;
revoke all on function public.world_xp_damp_apply() from public, anon, authenticated;

update public.world_xp_damp set steps = '[[2,50],[3,40],[4,30],[5,20],[6,10]]'::jsonb, note = '선두 단독 질주 보정(1.0.2c, 1.0.3에 차이별 단계)'
 where owner_id = (select owner_id from public.world_characters where character_name = '연주');
