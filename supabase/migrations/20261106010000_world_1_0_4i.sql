create or replace function public.world_xp_damp_pct(p_uid uuid, p_level int) returns numeric
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare r jsonb := public.world_xp_lead_rules(); d public.world_xp_damp%rowtype; avg_lv numeric; gap numeric; top int; pct numeric := 100; p numeric;
begin
  if p_uid is null or p_level >= 40 or exists (select 1 from public.world_staff s where s.owner_id = p_uid) then return 100; end if;
  select nullif(value, '')::numeric into avg_lv from public.world_app_meta where key = 'xp_avg_level';
  if avg_lv is not null and p_level - avg_lv >= (r ->> 'lead')::numeric then
    gap := p_level - avg_lv;
    p := (select (s ->> 1)::numeric from jsonb_array_elements(r -> 'steps') s where (s ->> 0)::numeric <= gap order by (s ->> 0)::numeric desc limit 1);
    if p is not null then pct := least(pct, p); end if;
  end if;
  select * into d from public.world_xp_damp where owner_id = p_uid and until > now();
  if found then
    select max(c.level) into top from public.world_characters c
     where c.owner_id <> p_uid and not exists (select 1 from public.world_staff s where s.owner_id = c.owner_id);
    if p_level - coalesce(top, 0) >= d.lead then
      pct := least(pct, coalesce((select (s ->> 1)::numeric from jsonb_array_elements(d.steps) s where (s ->> 0)::int <= p_level - coalesce(top, 0) order by (s ->> 0)::int desc limit 1), d.pct));
    end if;
  end if;
  return pct;
end $f$;
revoke all on function public.world_xp_damp_pct(uuid, int) from public, anon, authenticated;
grant execute on function public.world_xp_damp_pct(uuid, int) to fn_owner_field;

create or replace function public.world_xp_damp_apply() returns trigger
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare gain bigint; tot bigint; nl int := 1; pct numeric;
begin
  if new.experience is not distinct from old.experience and new.level is not distinct from old.level then return new; end if;
  gain := public.world_xp_total(new.level, new.experience) - public.world_xp_total(old.level, old.experience);
  if gain <= 0 then return new; end if;
  pct := public.world_xp_damp_pct(new.owner_id, old.level);
  if pct >= 100 then return new; end if;
  tot := public.world_xp_total(old.level, old.experience) + round(gain * pct / 100.0);
  while nl < 40 and tot >= public.world_xp_need(nl) loop tot := tot - public.world_xp_need(nl); nl := nl + 1; end loop;
  new.stat_points := least(117, greatest(0, new.stat_points + 3 * (nl - new.level)));
  new.level := nl;
  new.experience := case when nl >= 40 then 0 else tot end;
  return new;
end $f$;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_hud_snapshot()'::regprocedure), E'\r\n', E'\n');
  if position('xp_pct' in d) > 0 then return; end if;
  a := $a$'death_at', CASE WHEN c.downed_at$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.4i world_hud_snapshot 기준 문구가 없습니다'; end if;
  execute replace(d, a, $b$'xp_pct', public.world_xp_damp_pct(uid, c.level), $b$ || a);
end $w$;

update public.world_app_meta set value = '20261106010000' where key = 'db_version';
