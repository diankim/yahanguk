create or replace function pg_temp.pj_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int; want int; old text;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    old := p_pairs[2 * i - 1]; want := 1;
    if old like '%#%' and old ~ '^#[0-9]+#' then want := substring(old from '^#([0-9]+)#')::int; old := regexp_replace(old, '^#[0-9]+#', ''); end if;
    n := (length(d) - length(replace(d, old, ''))) / length(old);
    if n <> want then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳, 바란 것 %)', p_name, i, n, want; end if;
    d := replace(d, old, p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.pj_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function pg_temp.pj_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

create or replace function pg_temp.yh_pj_setjson(p_fn regprocedure, p_j jsonb) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); body text := (select prosrc from pg_proc where oid = p_fn);
begin
  if position(body in src) = 0 then raise exception 'yh_pj_setjson %: 본문을 못 찾음', p_fn; end if;
  execute replace(src, body, ' select ' || quote_literal(p_j::text) || '::jsonb ');
end $f$;

create table if not exists public.world_projects (
  project_key text primary key,
  stage int not null default 0 check (stage between 0 and 5),
  points bigint not null default 0,
  goal bigint not null default 0,
  total bigint not null default 0,
  stage_at timestamptz[] not null default '{}',
  updated_at timestamptz not null default now()
);
create table if not exists public.world_project_contrib (
  project_key text not null references public.world_projects(project_key),
  owner_id uuid not null,
  total bigint not null default 0,
  cur bigint not null default 0,
  day date,
  day_pts int not null default 0,
  marks int[] not null default '{}',
  updated_at timestamptz not null default now(),
  primary key (project_key, owner_id)
);
create index if not exists idx_world_project_contrib_owner on public.world_project_contrib(owner_id);
do $g$
declare t text;
begin
  foreach t in array array['world_projects', 'world_project_contrib'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to fn_owner_field', t);
  end loop;
end $g$;

alter table public.world_faction_vault add column if not exists stage_need int not null default 0;

create or replace function public.world_active_actors(p_at timestamptz, p_window_h int, p_min int)
 returns table(actor_id uuid) language sql stable set search_path = pg_catalog, public
as $f$
  select e.actor_id from public.world_events e where e.created_at > p_at - make_interval(hours => p_window_h) and e.created_at <= p_at
   group by e.actor_id having count(distinct floor(extract(epoch from e.created_at) / 600)) >= p_min / 10
$f$;
select pg_temp.pj_share('public.world_active_actors(timestamptz, int, int)');

select pg_temp.pj_fix('world_influence_score', array[
$q$      from (select e.actor_id from public.world_events e where e.created_at > p_at - w and e.created_at <= p_at
             group by e.actor_id having count(distinct floor(extract(epoch from e.created_at) / 600)) >= (rr ->> 'active_min')::int / 10) a$q$,
$q$      from public.world_active_actors(p_at, (rr ->> 'window_h')::int, (rr ->> 'active_min')::int) a$q$]);

create or replace function public.world_give_check(p_uid uuid, p_item text, p_inv jsonb)
 returns int language sql stable security definer set search_path = pg_catalog, public
as $f$
  select case
    when i.item_id is null or i.category = 'quest' or coalesce(i.reference_price, 0) <= 0 then 0
    when exists (select 1 from public.world_item_locks l where l.owner_id = p_uid and l.item_id = p_item) then 0
    else greatest(0, coalesce((p_inv ->> p_item)::int, 0)
      - (select count(*)::int from public.world_character_equipment x where x.owner_id = p_uid and x.item_id = p_item)
      - case when exists (select 1 from public.world_gear_enhance g where g.owner_id = p_uid and g.item_id = p_item and g.level > 0) then 1 else 0 end) end
  from (select 1) z left join public.world_item_catalog i on i.item_id = p_item
$f$;
select pg_temp.pj_share('public.world_give_check(uuid, text, jsonb)');
select pg_temp.pj_own('public.world_give_check(uuid, text, jsonb)', 'fn_owner_field');

select pg_temp.pj_fix('world_faction_donate_info', array[
$q$    'items', (select coalesce(jsonb_agg(jsonb_build_object('item_id', i.item_id, 'name', i.item_name, 'qty', q.qty - q.eq, 'price', i.reference_price, 'rarity', i.rarity,
                'category', i.category, 'tier', i.tier, 'tradeable', i.tradeable) order by i.item_name), '[]'::jsonb)
              from (select e.key item_id, (e.value)::text::int qty,
                      (select count(*)::int from public.world_character_equipment x where x.owner_id = p_uid and x.item_id = e.key)
                      + case when exists (select 1 from public.world_gear_enhance g where g.owner_id = p_uid and g.item_id = e.key and g.level > 0) then 1 else 0 end eq
                    from public.world_characters c, jsonb_each(coalesce(c.inventory, '{}'::jsonb)) e
                    where c.owner_id = p_uid and jsonb_typeof(e.value) = 'number') q
              join public.world_item_catalog i on i.item_id = q.item_id
              where q.qty - q.eq > 0 and coalesce(i.reference_price, 0) > 0 and i.category <> 'quest'
                and not exists (select 1 from public.world_item_locks l where l.owner_id = p_uid and l.item_id = q.item_id)))$q$,
$q$    'items', (select coalesce(jsonb_agg(jsonb_build_object('item_id', i.item_id, 'name', i.item_name, 'qty', q.qty, 'price', i.reference_price, 'rarity', i.rarity,
                'category', i.category, 'tier', i.tier, 'tradeable', i.tradeable) order by i.item_name), '[]'::jsonb)
              from (select e.key item_id, public.world_give_check(p_uid, e.key, c.inventory) qty
                    from public.world_characters c, jsonb_each(coalesce(c.inventory, '{}'::jsonb)) e
                    where c.owner_id = p_uid and jsonb_typeof(e.value) = 'number') q
              join public.world_item_catalog i on i.item_id = q.item_id
              where q.qty > 0))$q$]);
