create or replace function public.world_bond_emote_rules() returns jsonb language sql immutable as $f$ select '{
  "emotes": [{"k": "hug", "name": "포옹하기", "icon": "heart"}, {"k": "hand", "name": "손 잡기", "icon": "heart"}, {"k": "pat", "name": "머리 쓰다듬기", "icon": "spark"},
    {"k": "tease", "name": "장난치기", "icon": "sweat"}, {"k": "praise", "name": "칭찬하기", "icon": "spark"}, {"k": "comfort", "name": "위로하기", "icon": "heart"},
    {"k": "five", "name": "하이파이브", "icon": "spark"}, {"k": "dance", "name": "함께 춤추기", "icon": "note"}],
  "tiers": [{"min": 0, "key": "t1", "name": "설렘"}, {"min": 300, "key": "t2", "name": "편안함"}, {"min": 1000, "key": "t3", "name": "애틋함"}, {"min": 2500, "key": "t4", "name": "오랜 사이"}],
  "day": 10, "gap_s": 3, "gain": 2, "state_p": 0.5, "weather_p": 0.25, "erosion": 55, "hp": 35, "exp_h": 1,
  "weather": {"rain": "rain", "drizzle": "rain", "snow": "snow", "fog": "fog", "wind": "wind", "bloodmist": "bloodmist"}
}'::jsonb $f$;

create table if not exists public.world_bond_emote_lines (
  id serial primary key, emote text not null, ctx text not null, tier text not null, line text not null
);
create index if not exists idx_world_bond_emote_lines_k on public.world_bond_emote_lines(ctx, emote, tier);
create table if not exists public.world_bond_emotes (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  day date, n int not null default 0, last_at timestamptz, gain_day date, phase_seen text, last_line int
);
alter table public.world_bond_emote_lines enable row level security;
alter table public.world_bond_emotes enable row level security;
revoke all on public.world_bond_emote_lines, public.world_bond_emotes from anon, authenticated;
grant select on public.world_bond_emote_lines to fn_owner_field;
grant select, insert, update, delete on public.world_bond_emotes to fn_owner_field;

create or replace function public.world_bond_emote_left(p_uid uuid) returns int language sql stable security definer set search_path = pg_catalog, public as $f$
  select greatest(0, (public.world_bond_emote_rules() ->> 'day')::int - coalesce((select e.n from public.world_bond_emotes e where e.owner_id = p_uid and e.day = public.world_bond_day()), 0))
$f$;

create or replace function public.world_bond_emote(p_emote text) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_bond_emote_rules(); b public.world_bonds%rowtype; pid uuid; e public.world_bond_emotes%rowtype;
  c public.world_characters%rowtype; today date := public.world_bond_day(); v_tier text; tname text; em jsonb; v_ctx text := null; ph text; wk text; reg public.world_map_regions%rowtype;
  ln public.world_bond_emote_lines%rowtype; gained int := 0; pname text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  em := (select x from jsonb_array_elements(r -> 'emotes') x where x ->> 'k' = p_emote);
  if em is null then raise exception '알 수 없는 상호작용입니다.'; end if;
  b := public.world_bond_active(uid);
  if b.bond_id is null then raise exception '연리를 맺은 정인이 없습니다.'; end if;
  pid := case when b.a_id = uid then b.b_id else b.a_id end;
  insert into public.world_bond_emotes(owner_id) values (uid) on conflict do nothing;
  select * into e from public.world_bond_emotes where owner_id = uid for update;
  if e.last_at is not null and e.last_at + make_interval(secs => (r ->> 'gap_s')::int) > now() then
    raise exception '조금 천천히 해 주세요.' using hint = 'rate';
  end if;
  if e.day is distinct from today then e.n := 0; end if;
  if e.n >= (r ->> 'day')::int then raise exception '오늘은 상호작용을 다 했습니다. 하루 %번까지입니다.', r ->> 'day'; end if;
  select x ->> 'key', x ->> 'name' into v_tier, tname from jsonb_array_elements(r -> 'tiers') x where (x ->> 'min')::int <= b.affinity order by (x ->> 'min')::int desc limit 1;
  select * into c from public.world_characters where owner_id = uid;
  select character_name into pname from public.world_characters where owner_id = pid;
  if random() < (r ->> 'state_p')::numeric then
    v_ctx := case
      when exists (select 1 from public.world_character_statuses s where s.owner_id = uid and s.status_key = 'yohwa') then 'st:yohwa'
      when coalesce(c.erosion, 0) >= (r ->> 'erosion')::int then 'st:erosion'
      when coalesce(c.health, 100) <= (r ->> 'hp')::int then 'st:hp'
      when exists (select 1 from public.world_events v where v.actor_id = uid and v.event_type = 'expedition_end' and v.created_at > now() - make_interval(hours => (r ->> 'exp_h')::int)) then 'st:exp'
    end;
  end if;
  ph := public.world_time_phase(now());
  if v_ctx is null and e.phase_seen is distinct from (today::text || ph) then v_ctx := 'time:' || ph; end if;
  if v_ctx is null and random() < (r ->> 'weather_p')::numeric then
    reg := public.world_field_region(c.location);
    wk := r -> 'weather' ->> public.world_weather_key(reg.territory_id, now());
    if wk is not null then v_ctx := 'w:' || wk; end if;
  end if;
  if v_ctx is not null then
    select * into ln from public.world_bond_emote_lines l where l.ctx = v_ctx and l.tier in (v_tier, 'all') and l.id is distinct from e.last_line order by random() limit 1;
  end if;
  if ln.id is null then
    select * into ln from public.world_bond_emote_lines l where l.ctx = 'base' and l.emote = p_emote and l.tier in (v_tier, 'all') and l.id is distinct from e.last_line order by random() limit 1;
  end if;
  if e.gain_day is distinct from today then
    gained := public.world_bond_gain(b.bond_id, (r ->> 'gain')::int, 'emote');
  end if;
  update public.world_bond_emotes set day = today, n = e.n + 1, last_at = now(), last_line = ln.id, phase_seen = today::text || ph,
    gain_day = case when e.gain_day is distinct from today then today else e.gain_day end where owner_id = uid;
  perform public.world_bond_note(pid, 'bond_emote', '연리', c.character_name || '님이 별채에서 「' || (em ->> 'name') || '」 상호작용을 보냈습니다. (설정 › 알림 「연리」에서 끌 수 있습니다)',
    jsonb_build_object('from', uid, 'emote', p_emote));
  return jsonb_build_object('ok', true, 'emote', p_emote, 'name', em ->> 'name', 'icon', em ->> 'icon', 'tier', tname,
    'line', replace(replace(ln.line, '{정인}', coalesce(pname, '정인')), '{이름}', c.character_name),
    'partner', pid, 'left', (r ->> 'day')::int - e.n - 1, 'gained', gained);
end $f$;

do $o$ declare f text; x text; g boolean := not has_schema_privilege('fn_owner_field', 'public', 'CREATE'); begin
  foreach f in array array['world_bond_emote_rules()', 'world_bond_emote_left(uuid)', 'world_bond_emote(text)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
      execute format('grant execute on function public.%s to %I', f, x);
    end loop;
  end loop;
  grant execute on function public.world_bond_emote(text) to authenticated;
  if g then grant create on schema public to fn_owner_field; end if;
  execute 'alter function public.world_bond_emote(text) owner to fn_owner_field';
  execute 'alter function public.world_bond_emote_left(uuid) owner to fn_owner_field';
  if g then revoke create on schema public from fn_owner_field; end if;
end $o$;
grant usage, select on sequence public.world_bond_emote_lines_id_seq to fn_owner_field;

select pg_temp.yh_patch('public.world_bond_snapshot()'::regprocedure, '''married'', coalesce((b.marks ->> ''married'')::boolean, false),', '''married'', coalesce((b.marks ->> ''married'')::boolean, false), ''emote_left'', public.world_bond_emote_left(uid),');
select pg_temp.yh_patch('public.world_character_purge(uuid)'::regprocedure, '    delete from public.world_garden_plots where owner_id = p_uid;', '    delete from public.world_garden_plots where owner_id = p_uid;
    delete from public.world_bond_emotes where owner_id = p_uid;');
