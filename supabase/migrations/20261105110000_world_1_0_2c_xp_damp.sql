create table if not exists public.world_xp_damp (owner_id uuid primary key, pct int not null, lead int not null, until timestamptz not null, note text);
alter table public.world_xp_damp enable row level security;
revoke all on table public.world_xp_damp from public, anon, authenticated;

create or replace function public.world_xp_total(p_level int, p_exp int) returns bigint language sql immutable as $f$
  select coalesce((select sum(public.world_xp_need(l)) from generate_series(1, greatest(1, p_level) - 1) l), 0) + greatest(0, coalesce(p_exp, 0))
$f$;
revoke all on function public.world_xp_total(int, int) from public, anon, authenticated;

create or replace function public.world_xp_damp_apply() returns trigger
language plpgsql security definer set search_path = '' as $f$
declare d public.world_xp_damp%rowtype; top int; gain bigint; tot bigint; nl int := 1;
begin
  if new.experience is not distinct from old.experience and new.level is not distinct from old.level then return new; end if;
  select * into d from public.world_xp_damp where owner_id = new.owner_id and until > now();
  if not found then return new; end if;
  gain := public.world_xp_total(new.level, new.experience) - public.world_xp_total(old.level, old.experience);
  if gain <= 0 or old.level >= 40 then return new; end if;
  select max(c.level) into top from public.world_characters c
   where c.owner_id <> new.owner_id and not exists (select 1 from public.world_staff s where s.owner_id = c.owner_id);
  if old.level < coalesce(top, 0) + d.lead then return new; end if;
  tot := public.world_xp_total(old.level, old.experience) + round(gain * d.pct / 100.0);
  while nl < 40 and tot >= public.world_xp_need(nl) loop tot := tot - public.world_xp_need(nl); nl := nl + 1; end loop;
  new.stat_points := least(117, greatest(0, new.stat_points + 3 * (nl - new.level)));
  new.level := nl;
  new.experience := case when nl >= 40 then 0 else tot end;
  return new;
end $f$;
revoke all on function public.world_xp_damp_apply() from public, anon, authenticated;

drop trigger if exists trg_world_zz_xp_damp on public.world_characters;
create trigger trg_world_zz_xp_damp before update of experience, level on public.world_characters
  for each row execute function public.world_xp_damp_apply();

insert into public.world_xp_damp (owner_id, pct, lead, until, note)
select owner_id, 30, 2, now() + interval '7 days', '선두 단독 질주 보정(1.0.2c)' from public.world_characters where character_name = '연주'
on conflict (owner_id) do update set pct = excluded.pct, lead = excluded.lead, until = excluded.until, note = excluded.note;
