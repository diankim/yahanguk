create table if not exists public.world_ui_prefs (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  prefs jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.world_ui_prefs enable row level security;
revoke all on table public.world_ui_prefs from public, anon, authenticated;
grant select, insert, update on table public.world_ui_prefs to fn_owner_field;

create or replace function public.world_ui_prefs_set(p_prefs jsonb) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); p jsonb; t timestamptz := now();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_prefs is null or jsonb_typeof(p_prefs) <> 'object' then raise exception '설정 형식이 맞지 않습니다.'; end if;
  select coalesce(jsonb_object_agg(k, v), '{}'::jsonb) into p from jsonb_each(p_prefs) e(k, v) where k in ('theme', 'custom', 'fz', 'sound');
  if octet_length(p::text) > 4000 then raise exception '설정이 너무 큽니다.'; end if;
  insert into public.world_ui_prefs (owner_id, prefs, updated_at) values (uid, p, t)
  on conflict (owner_id) do update set prefs = excluded.prefs, updated_at = t;
  return jsonb_build_object('ok', true, 'at', t);
end $f$;
revoke all on function public.world_ui_prefs_set(jsonb) from public, anon, authenticated;
alter function public.world_ui_prefs_set(jsonb) owner to fn_owner_field;
grant execute on function public.world_ui_prefs_set(jsonb) to authenticated, service_role;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_tutorial_snapshot()'::regprocedure), E'\r\n', E'\n');
  if position('world_ui_prefs' in d) > 0 then return; end if;
  a := $a$    'saved', f is not null,$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.4b world_tutorial_snapshot 기준 문구가 없습니다'; end if;
  execute replace(d, a, $x$    'saved', f is not null,
    'ui', (select jsonb_build_object('prefs', u.prefs, 'at', u.updated_at) from public.world_ui_prefs u where u.owner_id = uid),$x$);
end $w$;

update public.world_app_meta set value = '20261105230000' where key = 'db_version';
