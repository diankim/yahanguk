create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

create table if not exists public.world_meisho_alerts (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  meisho_id text not null,
  open_at timestamptz not null,
  primary key (owner_id, meisho_id, open_at)
);
alter table public.world_meisho_alerts enable row level security;
revoke all on public.world_meisho_alerts from public, anon, authenticated;

select pg_temp.yh_fix2('public.world_notify_prefs_set(text[])'::regprocedure,
  $o$'raid', 'housing')$o$, $n$'raid', 'housing', 'meisho')$n$);

create or replace function public.world_meisho_alert_rules()
 returns jsonb language sql immutable
as $f$ select '{"active_days": 2, "near_min": 20, "keep_days": 3}'::jsonb $f$;
revoke all on function public.world_meisho_alert_rules() from public, anon, authenticated;

create or replace function public.world_meisho_alert_tick()
 returns integer language plpgsql security definer set search_path to ''
as $f$
declare ru jsonb := public.world_meisho_rules(); ar jsonb := public.world_meisho_alert_rules(); m public.world_meisho%rowtype; w jsonb; oa timestamptz; ln text; n int := 0; k int; rg text; terr text;
begin
  delete from public.world_meisho_alerts where open_at < now() - make_interval(days => (ar ->> 'keep_days')::int);
  for m in select * from public.world_meisho where active order by sort loop
    w := public.world_meisho_when(m.meisho_id, now());
    if not coalesce((w ->> 'open')::boolean, false) then continue; end if;
    oa := (w ->> 'open_at')::timestamptz;
    if oa < now() - make_interval(mins => (ar ->> 'near_min')::int) then continue; end if;
    ln := ru -> 'kinds' -> m.kind ->> 'line';
    select r.region_name, r.territory_id into rg, terr from public.world_map_regions r where r.region_id = m.region_id;
    with ins as (
      insert into public.world_meisho_alerts (owner_id, meisho_id, open_at)
      select c.owner_id, m.meisho_id, oa from public.world_characters c
       where c.level >= m.min_level and coalesce((c.skill_progress -> ln ->> 'rank')::int, 1) >= (ru #>> '{rank,base}')::int
         and c.updated_at > now() - make_interval(days => (ar ->> 'active_days')::int)
         and public.world_domain_open(c.owner_id, terr)
      on conflict do nothing returning owner_id)
    insert into public.world_notifications (user_id, kind, title, content, payload)
    select ins.owner_id, 'meisho_open', '명소가 열렸습니다',
      coalesce(rg, '') || '의 ' || (ru -> 'kinds' -> m.kind ->> 'name') || ' 명소 「' || m.meisho_name || '」 · 한국 시각 '
        || to_char((w ->> 'close_at')::timestamptz at time zone 'Asia/Seoul', 'HH24:MI') || '까지 캘 수 있습니다.',
      jsonb_build_object('location', m.region_id, 'meisho', m.meisho_id, 'close_at', w ->> 'close_at')
      from ins;
    get diagnostics k = row_count;
    n := n + k;
  end loop;
  return n;
end $f$;
revoke all on function public.world_meisho_alert_tick() from public, anon, authenticated;

select pg_temp.yh_fix2('public.world_notify_group(text)'::regprocedure,
  $o$when p_kind in ('letter') then 'letter'$o$,
  $n$when p_kind in ('letter') then 'letter'
    when p_kind in ('meisho_open') then 'meisho'$n$);

select pg_temp.yh_fix2('public.world_character_purge(uuid)'::regprocedure,
  $o$  delete from public.world_meisho_finds where owner_id = p_uid;$o$,
  $n$  delete from public.world_meisho_finds where owner_id = p_uid;
  delete from public.world_meisho_alerts where owner_id = p_uid;$n$);

select cron.schedule('yh-meisho', '*/10 * * * *', 'select public.world_meisho_alert_tick()');

update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n- 채집·채광 숙련이 명소를 캘 만큼 오른 조사원에게는, 갈 수 있는 명소가 열릴 때 알림이 갑니다. 설정 › 알림의 「명소」로 끌 수 있습니다.\n'
 where note_id = '2.2.0' and body like '%## 2.2.2%' and body not like '%명소가 열릴 때 알림%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118070000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
