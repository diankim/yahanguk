lock table public.world_characters in share row exclusive mode;

create table if not exists public.world_storage_marks (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  faction_steps int not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.world_storage_marks enable row level security;
revoke all on public.world_storage_marks from public, anon, authenticated;
grant select on public.world_storage_marks to fn_owner_field;

create or replace function public.world_faction_steps_of(p_rep int)
 RETURNS int
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  select count(*)::int from jsonb_array_elements_text(public.world_storage_rules() -> 'faction' -> 'steps') t
   where coalesce(p_rep, 0) >= t::int
$function$;
revoke all on function public.world_faction_steps_of(int) from public, anon, authenticated;
grant execute on function public.world_faction_steps_of(int) to fn_owner_field;

create or replace function public.world_storage_faction_mark()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare n int := public.world_faction_steps_of(new.faction_reputation);
begin
  if n > 0 and n > public.world_faction_steps_of(old.faction_reputation) then
    insert into public.world_storage_marks(owner_id, faction_steps) values (new.owner_id, n)
    on conflict (owner_id) do update set faction_steps = excluded.faction_steps, updated_at = now()
     where public.world_storage_marks.faction_steps < excluded.faction_steps;
  end if;
  return null;
end
$function$;
revoke all on function public.world_storage_faction_mark() from public, anon, authenticated;

drop trigger if exists trg_world_storage_faction_mark on public.world_characters;
create trigger trg_world_storage_faction_mark
  after update of faction_reputation on public.world_characters
  for each row when (new.faction_reputation >= 300 and new.faction_reputation > old.faction_reputation)
  execute function public.world_storage_faction_mark();

insert into public.world_storage_marks(owner_id, faction_steps)
select c.owner_id, public.world_faction_steps_of(c.faction_reputation)
  from public.world_characters c
 where c.major_faction_id is not null and public.world_faction_steps_of(c.faction_reputation) > 0
on conflict (owner_id) do update set faction_steps = greatest(public.world_storage_marks.faction_steps, excluded.faction_steps);

create or replace function public.world_storage_capacity(p_uid uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  with r as (select public.world_storage_rules() j)
  select jsonb_build_object('base', (r.j ->> 'base')::int, 'bought', b.v, 'story', st.v, 'arc', ar.v, 'faction', fa.v, 'survey', sv.v, 'jobs', jb.v, 'regular', rg.v,
           'total', (r.j ->> 'base')::int + b.v + st.v + ar.v + fa.v + sv.v + jb.v + rg.v, 'bought_steps', b.n, 'surveyed', sv.n,
           'job_lines', jb.n, 'regular_done', rg.n,
           'next_price', (r.j -> 'prices' ->> b.n)::int)
    from r,
         lateral (select coalesce((select s.bought from public.world_storage s where s.owner_id = p_uid), 0) n) b0,
         lateral (select b0.n n, b0.n * (r.j ->> 'step')::int v) b,
         lateral (select (r.j ->> 'story')::int * count(*)::int v from public.world_story_chapters ch join public.world_case_progress p
                    on p.owner_id = p_uid and p.case_id = ch.chapter_id
                   where ch.seq between 6 and 10 and coalesce(p.combined, '[]'::jsonb) ? (ch.chapter_id || '_completed')) st,
         lateral (select coalesce(sum((r.j -> 'arcs' ->> g.quest_id)::int), 0)::int v from public.world_quest_progress g
                   where g.owner_id = p_uid and g.done_at is not null and (r.j -> 'arcs') ? g.quest_id) ar,
         lateral (select (r.j -> 'faction' ->> 'cells')::int
                         * greatest(coalesce((select m.faction_steps from public.world_storage_marks m where m.owner_id = p_uid), 0),
                                    coalesce((select case when c.major_faction_id is null then 0
                                                     else (select count(*)::int from jsonb_array_elements_text(r.j -> 'faction' -> 'steps') t
                                                            where coalesce(c.faction_reputation, 0) >= t::int) end
                                                from public.world_characters c where c.owner_id = p_uid), 0)) v) fa,
         lateral (select x.n, (r.j -> 'survey' ->> 'cells')::int * least((r.j -> 'survey' ->> 'max')::int, x.n / (r.j -> 'survey' ->> 'per')::int) v
                    from (select count(*)::int n from public.world_region_progress rp where rp.owner_id = p_uid and 'complete' = any (rp.milestones)) x) sv,
         lateral (select x.n, (r.j -> 'jobs' ->> 'cells')::int * least((r.j -> 'jobs' ->> 'max')::int, greatest(0, x.n - 1)) v
                    from (select count(*)::int n from public.world_characters c, unnest(public.world_combat_lines()) l
                           where c.owner_id = p_uid and coalesce((c.skill_progress -> l ->> 'rank')::int, 1) >= (r.j -> 'jobs' ->> 'rank')::int) x) jb,
         lateral (select x.n, (r.j -> 'regular' ->> 'cells')::int * x.n v
                    from (select count(*)::int n from public.world_quest_progress g
                           where g.owner_id = p_uid and g.done_at is not null and g.quest_id like 'rg\_%\_5') x) rg
$function$;

do $p$
declare d text := pg_get_functiondef('public.world_character_purge(uuid)'::regprocedure);
begin
  if position('world_storage_marks' in d) = 0 then
    if position('delete from public.world_enhance_moves where owner_id = p_uid;' in d) = 0 then raise exception 'purge 자리 못 찾음'; end if;
    execute replace(d, 'delete from public.world_enhance_moves where owner_id = p_uid;', 'delete from public.world_enhance_moves where owner_id = p_uid;
  delete from public.world_storage_marks where owner_id = p_uid;');
  end if;
end $p$;

update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n- 대세력 평판으로 늘어난 창고 칸(300·600·1,000마다 +2)이 세력을 떠나거나 옮기면 사라지던 것을, 한 번 닿은 칸은 그대로 남게 바꿨습니다. 지금 세력에서 이미 닿은 칸도 남는 것으로 적었습니다.\n- 가방 › 장비에서 낀 장비와 바꿔 낄 장비의 이름을 누르면 물품 정보가 열립니다.\n'
 where note_id = '3.5.0' and position('한 번 닿은 칸은 그대로 남게' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124160000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
