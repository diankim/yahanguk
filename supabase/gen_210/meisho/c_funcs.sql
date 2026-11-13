create or replace function public.world_meisho_start(p_id text, p_phase text, p_day date)
 returns timestamptz
 language sql
 stable
 set search_path to 'pg_catalog'
as $function$
  select (p_day::timestamp + make_interval(mins => (r -> 'phase_start' ->> p_phase)::int * 60
    + (abs(hashtext(p_id || ':' || p_day::text)::bigint) % ((r ->> 'phase_h')::int * 60 / (r ->> 'open_min')::int))::int * (r ->> 'open_min')::int)) at time zone 'Asia/Seoul'
    from (select public.world_meisho_rules() r) x
$function$;
select pg_temp.yh_share('public.world_meisho_start(text, text, date)');

create or replace function public.world_meisho_when(p_id text, p_at timestamptz default now())
 returns jsonb
 language plpgsql
 stable
 set search_path to 'pg_catalog', 'public'
as $function$
declare m public.world_meisho%rowtype; ru jsonb := public.world_meisho_rules(); terr text; d date := (p_at at time zone 'Asia/Seoul')::date;
  s timestamptz; mins int := (ru ->> 'open_min')::int; o timestamptz; nx timestamptz;
begin
  select * into m from public.world_meisho where meisho_id = p_id;
  if not found then return null; end if;
  select territory_id into terr from public.world_map_regions where region_id = m.region_id;
  for i in 0 .. (ru ->> 'look_days')::int loop
    s := public.world_meisho_start(m.meisho_id, m.phase, d + i);
    if s + make_interval(mins => mins) <= p_at then continue; end if;
    if public.world_time_phase(s) <> m.phase or public.world_weather_key(terr, s) <> m.weather then continue; end if;
    if s <= p_at then o := s; else nx := s; exit; end if;
  end loop;
  return jsonb_build_object('open', o is not null, 'open_at', o, 'close_at', o + make_interval(mins => mins),
    'next_at', nx, 'next_end', nx + make_interval(mins => mins));
end $function$;
select pg_temp.yh_share('public.world_meisho_when(text, timestamptz)');

create or replace function public.world_meisho_grade(p_level integer)
 returns integer
 language sql
 immutable
 set search_path to 'pg_catalog'
as $function$
  select coalesce((select (g ->> 1)::int from jsonb_array_elements(public.world_meisho_rules() #> '{soil,grade_lv}') g
                    where p_level >= (g ->> 0)::int order by (g ->> 0)::int desc limit 1), 1)
$function$;
select pg_temp.yh_share('public.world_meisho_grade(integer)');

create or replace function public.world_meisho_gear(p_uid uuid, p_key text)
 returns numeric
 language sql
 stable
 set search_path to 'pg_catalog'
as $function$
  select coalesce(public.world_gear_total(p_uid, p_key), 0) + coalesce(public.world_status_self(p_uid, p_key), 0)
$function$;
select pg_temp.yh_share('public.world_meisho_gear(uuid, text)');

create or replace function public.world_meisho_card(p_uid uuid, p_id text, p_skill jsonb)
 returns jsonb
 language plpgsql
 stable
 set search_path to 'pg_catalog', 'public'
as $function$
declare m public.world_meisho%rowtype; f public.world_meisho_finds%rowtype; ru jsonb := public.world_meisho_rules(); k jsonb; w jsonb;
  today date := (now() at time zone 'Asia/Seoul')::date;
begin
  select * into m from public.world_meisho where meisho_id = p_id;
  if not found then return null; end if;
  select * into f from public.world_meisho_finds where owner_id = p_uid and meisho_id = p_id;
  k := ru -> 'kinds' -> m.kind; w := public.world_meisho_when(m.meisho_id);
  return jsonb_build_object('id', m.meisho_id, 'name', m.meisho_name, 'kind', m.kind, 'kind_name', k ->> 'name', 'line', k ->> 'line',
    'items', k -> 'items', 'phase', m.phase, 'weather', m.weather, 'level', m.min_level, 'desc', m.description, 'node_id', m.node_id,
    'node_name', (select n.node_name from public.world_exploration_nodes n where n.node_id = m.node_id), 'found', f.owner_id is not null,
    'rank', coalesce((p_skill -> (k ->> 'line') ->> 'rank')::int, 1), 'rank_need', (ru #>> '{rank,base}')::int,
    'grade', public.world_meisho_grade(m.min_level),
    'dug', f.dug_at is not null and f.dug_at = (w ->> 'open_at')::timestamptz, 'soil_done', f.soil_day is not distinct from today)
    || w;
end $function$;
select pg_temp.yh_share('public.world_meisho_card(uuid, text, jsonb)');

create or replace function public.world_meisho_field(p_uid uuid, p_region text, p_node uuid)
 returns jsonb
 language plpgsql
 stable
 set search_path to 'pg_catalog', 'public'
as $function$
declare ru jsonb := public.world_meisho_rules(); sp jsonb; lv int; here jsonb := '[]'::jsonb; near boolean := false; sense jsonb; nxt jsonb; m record; w jsonb; arr jsonb := '[]'::jsonb;
begin
  if p_uid is null then return null; end if;
  select skill_progress, level into sp, lv from public.world_characters where owner_id = p_uid;
  if exists (select 1 from public.world_meisho x where x.region_id = p_region and x.active) then
    for m in select x.meisho_id from public.world_meisho x join public.world_meisho_finds f on f.meisho_id = x.meisho_id and f.owner_id = p_uid
              where x.node_id = p_node and x.active order by x.sort loop
      here := here || jsonb_build_array(public.world_meisho_card(p_uid, m.meisho_id, sp));
    end loop;
    near := exists (select 1 from public.world_meisho x where x.node_id = p_node and x.active and lv >= x.min_level
      and not exists (select 1 from public.world_meisho_finds f where f.owner_id = p_uid and f.meisho_id = x.meisho_id)
      and coalesce((public.world_meisho_when(x.meisho_id) ->> 'open')::boolean, false));
    if public.world_meisho_gear(p_uid, 'mz_sense') > 0 then
      select coalesce(jsonb_agg(jsonb_build_object('name', case when f.owner_id is not null then x.meisho_name end, 'kind_name', ru -> 'kinds' -> x.kind ->> 'name',
          'node_name', n.node_name, 'node_id', x.node_id, 'close_at', (w2.w ->> 'close_at')::timestamptz) order by x.sort), '[]'::jsonb) into sense
        from public.world_meisho x join public.world_exploration_nodes n on n.node_id = x.node_id
        left join public.world_meisho_finds f on f.owner_id = p_uid and f.meisho_id = x.meisho_id
        cross join lateral (select public.world_meisho_when(x.meisho_id) as w) w2
       where x.region_id = p_region and x.active and coalesce((w2.w ->> 'open')::boolean, false);
    end if;
  end if;
  if public.world_meisho_gear(p_uid, 'mz_next') > 0 then
    for m in select x.meisho_id, x.meisho_name, x.kind, r.region_name, r.territory_id, f.owner_id is not null as found
               from public.world_meisho x join public.world_map_regions r on r.region_id = x.region_id
               left join public.world_meisho_finds f on f.owner_id = p_uid and f.meisho_id = x.meisho_id
              where x.active loop
      if not public.world_domain_open(p_uid, m.territory_id) then continue; end if;
      w := public.world_meisho_when(m.meisho_id);
      if w is null or (not (w ->> 'open')::boolean and w ->> 'next_at' is null) then continue; end if;
      arr := arr || jsonb_build_array(jsonb_build_object('name', case when m.found then m.meisho_name end, 'kind_name', ru -> 'kinds' -> m.kind ->> 'name',
        'region_name', m.region_name, 'open', (w ->> 'open')::boolean,
        'at', case when (w ->> 'open')::boolean then w ->> 'open_at' else w ->> 'next_at' end,
        'end', case when (w ->> 'open')::boolean then w ->> 'close_at' else w ->> 'next_end' end));
    end loop;
    select coalesce(jsonb_agg(v order by (v ->> 'at')::timestamptz), '[]'::jsonb) into nxt
      from (select v from jsonb_array_elements(arr) v order by (v ->> 'at')::timestamptz limit (ru ->> 'next_n')::int) z;
  end if;
  if jsonb_array_length(here) = 0 and not near and sense is null and nxt is null then return null; end if;
  return jsonb_build_object('here', here, 'near', near, 'sense', sense, 'next', nxt);
end $function$;
select pg_temp.yh_share('public.world_meisho_field(uuid, text, uuid)');

create or replace function public.world_meisho_dig(p_meisho text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); ru jsonb := public.world_meisho_rules(); c public.world_characters%rowtype; m public.world_meisho%rowtype;
  f public.world_meisho_finds%rowtype; w jsonb; k jsonb; line text; rank int; base text; qty int; jp numeric; np numeric; ex int;
  extra jsonb := '{}'::jsonb; inv jsonb; lim int; left_st int; notes text[] := '{}'; sk text[]; it text; v int; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_rate_check('gather', uid);
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 캘 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 캘 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then
    raise exception '전투 중에는 캘 수 없습니다.'; end if;
  select * into m from public.world_meisho where meisho_id = p_meisho and active;
  if not found then raise exception '없는 명소입니다.'; end if;
  if c.current_exploration_node_id is distinct from m.node_id then
    raise exception '%에 가야 캘 수 있습니다.', (select n.node_name from public.world_exploration_nodes n where n.node_id = m.node_id); end if;
  select * into f from public.world_meisho_finds where owner_id = uid and meisho_id = m.meisho_id for update;
  if not found then raise exception '먼저 탐색으로 명소를 찾으세요.'; end if;
  if c.level < m.min_level then raise exception '레벨 %부터 캘 수 있습니다.', m.min_level; end if;
  w := public.world_meisho_when(m.meisho_id);
  if not coalesce((w ->> 'open')::boolean, false) then
    raise exception '%은(는) 지금 닫혀 있습니다. %·% 때 한 시간만 열립니다.', m.meisho_name,
      (select env_name from public.world_environment_catalog where env_key = m.phase), (select env_name from public.world_environment_catalog where env_key = m.weather)
      using hint = 'mz_closed';
  end if;
  if f.dug_at is not null and f.dug_at = (w ->> 'open_at')::timestamptz then
    raise exception '이번에 열린 동안은 이미 캤습니다. 다음에 열릴 때 다시 오세요.' using hint = 'mz_done'; end if;
  k := ru -> 'kinds' -> m.kind; line := k ->> 'line';
  rank := coalesce((c.skill_progress -> line ->> 'rank')::int, 1);
  if rank < (ru #>> '{rank,base}')::int then
    raise exception '% 기술 %단계부터 명소를 캘 수 있습니다(지금 %단계). 흙 살피기는 단계와 무관합니다.', public.world_line_name(line), ru #>> '{rank,base}', rank;
  end if;
  base := k -> 'items' ->> 0;
  qty := (ru #>> '{qty,base}')::int + case when rank >= (ru #>> '{rank,j}')::int then (ru #>> '{qty,r40}')::int else 0 end
    + case when rank >= (ru #>> '{rank,n}')::int then (ru #>> '{qty,r50}')::int else 0 end;
  ex := least((ru ->> 'extra_cap')::int, floor(public.world_meisho_gear(uid, 'mz_extra'))::int);
  if ex > 0 then qty := qty + ex; notes := notes || format('장비 덤 +%s', ex); end if;
  if rank >= (ru #>> '{rank,j}')::int then
    jp := least((ru #>> '{j_pct,cap}')::numeric, (ru #>> '{j_pct,base}')::numeric + (rank - (ru #>> '{rank,j}')::int) * (ru #>> '{j_pct,per_rank}')::numeric
      + public.world_meisho_gear(uid, 'mz_j_' || m.kind) + public.world_meisho_gear(uid, 'mz_j_all'));
    if random() * 100 < jp then extra := extra || jsonb_build_object(k -> 'items' ->> 1, 1); end if;
  end if;
  if rank >= (ru #>> '{rank,n}')::int then
    np := least((ru #>> '{n_pct,cap}')::numeric, (ru #>> '{n_pct,base}')::numeric + public.world_meisho_gear(uid, 'mz_n_pct'));
    if random() * 100 < np then extra := extra || jsonb_build_object(k -> 'items' ->> 2, 1); end if;
  end if;
  lim := public.world_bag_limit(uid);
  inv := public.world_inv_add(coalesce(c.inventory, '{}'::jsonb), base, qty);
  for it, v in select key, value::text::int from jsonb_each(extra) loop inv := public.world_inv_add(inv, it, v); end loop;
  if public.world_bag_count(inv) > lim then
    raise exception '가방에 자리가 없습니다. 칸을 비운 뒤 다시 캐세요. 명소가 닫히기 전이면 다시 캘 수 있습니다.' using hint = 'bag'; end if;
  left_st := public.world_stamina_change(uid, -(ru ->> 'stamina')::int);
  select * into c from public.world_characters where owner_id = uid;
  inv := public.world_inv_add(coalesce(c.inventory, '{}'::jsonb), base, qty);
  for it, v in select key, value::text::int from jsonb_each(extra) loop inv := public.world_inv_add(inv, it, v); end loop;
  sk := public.world_skill_procs(uid);
  if not ((line = 'foraging' and 'foraging_x30' = any (sk)) or (line = 'mining' and 'mining_x30' = any (sk))) then perform public.world_durability_wear(uid, 'tool', 1); end if;
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  update public.world_meisho_finds set dug_at = (w ->> 'open_at')::timestamptz, dig_count = dig_count + 1 where owner_id = uid and meisho_id = m.meisho_id;
  select item_name into nm from public.world_item_catalog where item_id = base;
  for it in select key from jsonb_each(extra) loop notes := notes || (select item_name from public.world_item_catalog where item_id = it); end loop;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'gather', m.meisho_name || '에서 ' || nm || ' ×' || qty || ' 캠',
    jsonb_build_object('meisho_id', m.meisho_id, 'meisho', m.meisho_name, 'category', k ->> 'cat', 'item_id', base, 'qty', qty, 'node_id', m.node_id,
      'region_id', m.region_id, 'line', line, 'node', case when line = 'mining' then 'ore' else 'herb' end, 'extra', extra, 'free_day', false, 'profession_match', false));
  return jsonb_build_object('ok', true, 'content', m.meisho_name || '에서 ' || nm || ' ×' || qty || '을(를) 캤습니다.'
      || case when cardinality(notes) > 0 then ' ' || array_to_string(notes, ' · ') || '.' else '' end,
    'item_id', base, 'qty', qty, 'extra', extra, 'line', line, 'stamina', left_st, 'meisho_id', m.meisho_id, 'close_at', w ->> 'close_at');
end $function$;
revoke all on function public.world_meisho_dig(text) from public, anon;
grant execute on function public.world_meisho_dig(text) to authenticated, service_role;
select pg_temp.yh_own('public.world_meisho_dig(text)', 'fn_owner_field');

create or replace function public.world_meisho_soil(p_meisho text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); ru jsonb := public.world_meisho_rules(); c public.world_characters%rowtype; m public.world_meisho%rowtype;
  f public.world_meisho_finds%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; g int; pct numeric; rolled boolean := false; got boolean := false; txt text;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_travel_guard('흙 살피기');
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 흙을 살필 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then
    raise exception '전투 중에는 흙을 살필 수 없습니다.'; end if;
  select * into m from public.world_meisho where meisho_id = p_meisho and active;
  if not found then raise exception '없는 명소입니다.'; end if;
  if c.current_exploration_node_id is distinct from m.node_id then
    raise exception '%에 가야 흙을 살필 수 있습니다.', (select n.node_name from public.world_exploration_nodes n where n.node_id = m.node_id); end if;
  select * into f from public.world_meisho_finds where owner_id = uid and meisho_id = m.meisho_id for update;
  if not found then raise exception '먼저 탐색으로 명소를 찾으세요.'; end if;
  if c.level < m.min_level then raise exception '레벨 %부터 흙을 살필 수 있습니다.', m.min_level; end if;
  if f.soil_day is not distinct from today then
    raise exception '이 명소의 흙은 오늘 이미 살폈습니다. 한국 시각 자정이 지나면 다시 살필 수 있습니다.' using hint = 'mz_soil_done'; end if;
  g := public.world_meisho_grade(m.min_level);
  pct := least((ru #>> '{soil,cap}')::numeric, (ru -> 'soil' -> 'pct' ->> g::text)::numeric * greatest(0, 1 + public.world_meisho_gear(uid, 'mz_soil_pct') / 100.0));
  rolled := random() * 100 < pct;
  if rolled then got := coalesce(public.world_bijang_grant(uid, g), false); end if;
  update public.world_meisho_finds set soil_day = today, soil_count = soil_count + 1 where owner_id = uid and meisho_id = m.meisho_id;
  txt := case when got then m.meisho_name || '의 흙을 살피다 묻혀 있던 비장도를 찾았습니다.'
    when rolled then m.meisho_name || '의 흙 속에 비장도의 흔적이 있었지만, 같은 등급의 비장도를 이미 지니고 있어 덮어 두었습니다.'
    else m.meisho_name || '의 흙을 살폈지만 묻힌 것은 없었습니다.' end;
  return jsonb_build_object('ok', true, 'content', txt, 'got', got, 'had', rolled and not got, 'grade', g, 'meisho_id', m.meisho_id);
end $function$;
revoke all on function public.world_meisho_soil(text) from public, anon;
grant execute on function public.world_meisho_soil(text) to authenticated, service_role;
select pg_temp.yh_own('public.world_meisho_soil(text)', 'fn_owner_field');
