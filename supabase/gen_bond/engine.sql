create table if not exists public.world_kin (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  npc text,
  made_at timestamptz,
  ended_at timestamptz,
  wear boolean not null default true,
  fx_until timestamptz,
  room int not null default 0,
  past jsonb not null default '[]'::jsonb,
  day date,
  gift_day date,
  mem jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.world_kin enable row level security;
revoke all on public.world_kin from public, anon, authenticated;

create table if not exists public.world_kin_lines (
  npc text not null,
  key text not null,
  n int not null,
  lines jsonb not null,
  primary key (npc, key, n)
);
alter table public.world_kin_lines enable row level security;
revoke all on public.world_kin_lines from public, anon, authenticated;

create or replace function public.world_kin_rules()
 returns jsonb
 language sql
 immutable
 set search_path to 'pg_catalog', 'public'
as $function$
  select '{
    "cost": 300, "talk_day": 10, "gift_day": 1, "fx_h": 24,
    "reward": {"pct": 50, "n": 2},
    "pick": {"idle": 70, "weather": 20, "home": 10},
    "cap": {"weather": 2, "state": 2, "first": 3},
    "state_pct": 15, "idle_recent": 10, "away_days": 3, "days": [7, 30, 100], "far_hops": 3,
    "faded": "빛바랜 정표",
    "npcs": {
      "hanseol": {"token": "금동곳", "reward": "ward_talisman"},
      "yeoul": {"token": "갈대 영사 매듭", "reward": "banyo_salve"},
      "wolha": {"token": "엽전 노리개", "reward": "moonlight_essence"},
      "daon": {"token": "들꽃 매듭 노리개", "reward": "rejuv_pill"},
      "hisu": {"token": "먹물 붓 노리개", "reward": "meokgwi_incense"},
      "danbi": {"token": "주홍 방울", "reward": "bark_stew"},
      "unbi": {"token": "붉은 술 매듭", "reward": "eel_tonic"},
      "cheongpa": {"token": "뱃사공 매듭 팔찌", "reward": "bream_sashimi"},
      "galmae": {"token": "불씨 쇠고리", "reward": "repair_kit"},
      "haram": {"token": "별자리 점자 패", "reward": "shad_lamp"},
      "munsu": {"token": "나무 등잔 조각", "reward": "meokbi_umbrella"}
    }
  }'::jsonb
$function$;

create or replace function public.world_kin_npc(p_npc text)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare k jsonb := public.world_kin_rules() -> 'npcs' -> p_npc; r jsonb := public.world_regular_rule(p_npc);
begin
  if k is null or r is null then return null; end if;
  return r || k || jsonb_build_object('npc', p_npc,
    'reward_name', (select i.item_name from public.world_item_catalog i where i.item_id = k ->> 'reward'),
    'line_name', public.world_line_name(r ->> 'line'),
    'region_name', (select m.region_name from public.world_map_regions m where m.region_id = r ->> 'region'));
end $function$;

create or replace function public.world_kin_on(p_owner uuid)
 returns boolean
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
begin
  return (select * from (
    select exists (select 1 from public.world_kin k where k.owner_id = p_owner and k.npc is not null and k.ended_at is null
                      and k.wear and k.fx_until > now())
  ) yhq limit 1);
end $function$;

create or replace function public.world_kin_in_field(p_line text, p_item text)
 returns boolean
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_regular_rules();
begin
  if p_line = 'fishing' then
    return exists (select 1 from public.world_fish_species f where f.fish_id = p_item);
  elsif r -> 'lines' ? p_line then
    return exists (select 1 from public.world_gathering_spots s where p_item = any (s.loot_items)
                     and s.category = any (array(select jsonb_array_elements_text(r -> 'lines' -> p_line))));
  end if;
  return exists (select 1 from public.world_crafting_recipes w where w.output_item = p_item and public.world_craft_line_of(w.craft_field) = p_line);
end $function$;

create or replace function public.world_kin_line(p_npc text, p_key text, p_avoid int default null)
 returns jsonb
 language plpgsql
 volatile security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare out jsonb;
begin
  select jsonb_build_object('key', l.key, 'n', l.n, 'lines', l.lines) into out
    from public.world_kin_lines l where l.npc = p_npc and l.key = p_key
   order by (l.n = p_avoid and (select count(*) from public.world_kin_lines x where x.npc = p_npc and x.key = p_key) > 1), random() limit 1;
  return out;
end $function$;

create or replace function public.world_kin_view(p_npc text default null)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_kin_rules(); n text := coalesce(p_npc, public.world_regular_here(uid));
  nr jsonb := public.world_kin_npc(n); k public.world_kin%rowtype; c public.world_characters%rowtype; why text; rb timestamptz; here boolean;
  done boolean; bond_wear boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if nr is null then return null; end if;
  select * into c from public.world_characters where owner_id = uid;
  select * into k from public.world_kin where owner_id = uid;
  here := (public.world_region_at(c.location)).region_id is not distinct from nr ->> 'region';
  done := (nr ->> 'key') || '_5' = any (public.world_quest_done_ids(uid));
  rb := k.ended_at + make_interval(hours => (public.world_wedding_rules() ->> 'rebond_h')::int);
  why := case when not done then public.world_josa(nr ->> 'short', '과', '와') || '의 연담 마지막 이야기를 마치면 맺을 수 있습니다.'
              when k.npc is not null and k.ended_at is null and k.npc <> n then '이미 ' || coalesce((public.world_kin_npc(k.npc)) ->> 'short', '') || '와(과) 백년지기입니다. 백년지기는 한 사람만 맺습니다.'
              when k.npc = n and k.ended_at is null then null
              when rb > now() then '백년지기를 끊은 지 얼마 되지 않았습니다.'
              when not here then (nr ->> 'region_name') || '에서 맺습니다.'
              when c.gil < (r ->> 'cost')::int then '정표 짓는 값 ' || (r ->> 'cost') || '전이 모자랍니다.'
              else null end;
  return jsonb_build_object('npc', n, 'name', nr ->> 'short', 'token', nr ->> 'token', 'cost', (r ->> 'cost')::int,
    'reward', nr ->> 'reward', 'reward_name', nr ->> 'reward_name', 'line', nr ->> 'line', 'line_name', nr ->> 'line_name',
    'region_name', nr ->> 'region_name', 'here', here, 'done', done,
    'mine', k.npc is not null and k.ended_at is null and k.npc = n,
    'other', case when k.npc is not null and k.ended_at is null and k.npc <> n then (public.world_kin_npc(k.npc)) ->> 'short' end,
    'again', coalesce(k.past, '[]'::jsonb) @> jsonb_build_array(jsonb_build_object('npc', n)),
    'can_make', why is null and not (k.npc is not null and k.ended_at is null), 'why', why,
    'rebond_until', case when rb > now() then rb end,
    'made_at', case when k.npc = n and k.ended_at is null then k.made_at end,
    'wear', case when k.npc = n and k.ended_at is null then k.wear end,
    'faded', (select jsonb_agg(jsonb_build_object('npc', p ->> 'npc', 'token', public.world_kin_npc(p ->> 'npc') ->> 'token')) from jsonb_array_elements(coalesce(k.past, '[]'::jsonb)) p),
    'faded_name', r ->> 'faded');
end $function$;

create or replace function public.world_kin_make(p_npc text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_kin_rules(); nr jsonb := public.world_kin_npc(p_npc);
  c public.world_characters%rowtype; k public.world_kin%rowtype; v jsonb; again boolean; bw boolean; ln jsonb;
begin
  perform public.world_travel_guard('백년지기 맺기');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if nr is null then raise exception '백년지기를 맺을 수 없는 사람입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 맺을 수 없습니다.'; end if;
  insert into public.world_kin(owner_id) values (uid) on conflict do nothing;
  select * into k from public.world_kin where owner_id = uid for update;
  v := public.world_kin_view(p_npc);
  if not coalesce((v ->> 'can_make')::boolean, false) then raise exception '%', coalesce(v ->> 'why', '지금은 맺을 수 없습니다.'); end if;
  again := (v ->> 'again')::boolean;
  bw := exists (select 1 from public.world_bonds b where b.ended_at is null and ((b.a_id = uid and b.a_wear) or (b.b_id = uid and b.b_wear)));
  update public.world_characters set gil = gil - (r ->> 'cost')::int, updated_at = now() where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  values (uid, 'kin_make', -(r ->> 'cost')::int, true, jsonb_build_object('npc', p_npc));
  update public.world_kin set npc = p_npc, made_at = now(), ended_at = null, wear = not bw, fx_until = null, room = 0,
    day = null, mem = jsonb_build_object('lv', c.level), updated_at = now() where owner_id = uid;
  ln := public.world_kin_line(p_npc, case when again then 'bond_again' else 'bond_make' end);
  return jsonb_build_object('ok', true, 'npc', p_npc, 'talk', ln, 'wear', not bw,
    'content', public.world_josa(nr ->> 'short', '과', '와') || ' 백년지기를 맺었습니다 · 「' || (nr ->> 'token') || '」' ||
      case when bw then ' — 연리 정표를 차고 있어 백년지기 정표는 벗어 두었습니다.' else '' end,
    'view', public.world_kin_view(p_npc));
end $function$;

create or replace function public.world_kin_break()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); k public.world_kin%rowtype; c public.world_characters%rowtype; nr jsonb; ln jsonb;
begin
  perform public.world_travel_guard('백년지기 끊기');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  select * into k from public.world_kin where owner_id = uid for update;
  if not found or k.npc is null or k.ended_at is not null then raise exception '맺은 백년지기가 없습니다.'; end if;
  nr := public.world_kin_npc(k.npc);
  if (public.world_region_at(c.location)).region_id is distinct from nr ->> 'region' then
    raise exception '%에서 끊을 수 있습니다.', nr ->> 'region_name';
  end if;
  ln := public.world_kin_line(k.npc, 'bond_break');
  update public.world_kin set ended_at = now(), npc = null, wear = false, fx_until = null,
    past = (select coalesce(jsonb_agg(p), '[]'::jsonb) from jsonb_array_elements(past) p where p ->> 'npc' <> k.npc)
           || jsonb_build_array(jsonb_build_object('npc', k.npc, 'made_at', k.made_at, 'ended_at', now())),
    updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'npc', k.npc, 'talk', ln,
    'content', public.world_josa(nr ->> 'short', '과', '와') || '의 백년지기를 끊었습니다. 정표는 「' || (public.world_kin_rules() ->> 'faded') || '」로 남습니다.',
    'view', public.world_kin_view(k.npc));
end $function$;

create or replace function public.world_kin_wear(p_wear boolean)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); k public.world_kin%rowtype; bw boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into k from public.world_kin where owner_id = uid for update;
  if not found or k.npc is null or k.ended_at is not null then raise exception '맺은 백년지기가 없습니다.'; end if;
  bw := exists (select 1 from public.world_bonds b where b.ended_at is null and ((b.a_id = uid and b.a_wear) or (b.b_id = uid and b.b_wear)));
  if p_wear and bw then
    update public.world_bonds set a_wear = case when a_id = uid then false else a_wear end, b_wear = case when b_id = uid then false else b_wear end
     where ended_at is null and (a_id = uid or b_id = uid);
  end if;
  update public.world_kin set wear = p_wear, updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'wear', p_wear,
    'content', case when p_wear then '「' || (public.world_kin_npc(k.npc) ->> 'token') || '」을(를) 찼습니다.' || case when bw then ' 정표 칸은 하나라 연리 정표는 벗었습니다.' else '' end
                    else '「' || (public.world_kin_npc(k.npc) ->> 'token') || '」을(를) 벗었습니다.' end);
end $function$;

create or replace function public.world_kin_ctx(p_uid uuid, p_k public.world_kin)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_kin_rules(); c public.world_characters%rowtype; m jsonb := coalesce(p_k.mem, '{}'::jsonb);
  last_at timestamptz := (m ->> 'last_at')::timestamptz; today date := (now() at time zone 'Asia/Seoul')::date; home uuid;
  terr text; heavy text; light text; mate uuid; mate_npc text; homes text[] := '{}'; er int; erst int;
begin
  select * into c from public.world_characters where owner_id = p_uid;
  er := coalesce(c.erosion, 0);
  heavy := case when exists (select 1 from public.world_character_statuses s where s.owner_id = p_uid and s.status_key = 'yohwa') then 'me_yohwa'
                when er >= 80 then 'me_erosion_80'
                when c.downed_at is null and exists (select 1 from public.world_events e where e.actor_id = p_uid and e.event_type = 'downed'
                       and (e.created_at at time zone 'Asia/Seoul')::date = today) then 'me_rescued'
                when coalesce(c.health, 100) < 35 then 'me_hp_low' end;
  erst := case when er >= 55 then 55 when er >= 30 then 30 else 0 end;
  light := case when erst > coalesce((m ->> 'er')::int, 0) and erst < 80 then 'me_erosion_' || erst
                when last_at is not null and exists (select 1 from public.world_events e where e.actor_id = p_uid and e.event_type = 'expedition_end' and e.created_at > last_at) then 'me_exp_back'
                when last_at is not null and exists (select 1 from public.world_events e where e.actor_id = p_uid and e.event_type = 'travel' and e.created_at > last_at
                       and jsonb_array_length(coalesce(e.payload -> 'route', '[]'::jsonb)) > (r ->> 'far_hops')::int) then 'me_far_travel'
                when c.level > coalesce((m ->> 'lv')::int, c.level) then 'me_levelup' end;
  home := public.world_housing_home(p_uid);
  if exists (select 1 from public.world_housing h where h.owner_id = home and coalesce(h.wall, '[]'::jsonb) @> jsonb_build_array(jsonb_build_object('k', 'portrait_' || p_k.npc))) then homes := array_append(homes, 'home_portrait'); end if;
  if exists (select 1 from public.world_housing_pets p where public.world_housing_home(p.keeper_id) = home) then homes := array_append(homes, 'home_pet'); end if;
  if last_at is not null and exists (select 1 from public.world_housing h where h.owner_id = home and h.updated_at > last_at) then homes := array_append(homes, 'home_new_furn'); end if;
  select case when s.home_id = p_uid then s.mate_id else s.home_id end into mate from public.world_housing_shared s where s.home_id = p_uid or s.mate_id = p_uid limit 1;
  if mate is not null then
    homes := array_append(homes, 'home_mate');
    select k.npc into mate_npc from public.world_kin k where k.owner_id = mate and k.npc is not null and k.ended_at is null;
    if mate_npc is not null and mate_npc <> p_k.npc then homes := array_append(homes, ('mate_' || mate_npc)); end if;
  end if;
  select m2.territory_id into terr from public.world_map_regions m2 where m2.region_id = (public.world_region_at(c.location)).region_id;
  return jsonb_build_object('phase', public.world_time_phase(now()), 'weather', public.world_weather_key(terr, now()),
    'heavy', heavy, 'light', light, 'er', erst, 'lv', c.level, 'homes', to_jsonb(homes),
    'days', case when p_k.made_at is not null then floor(extract(epoch from now() - p_k.made_at) / 86400)::int end,
    'away', case when last_at is not null then extract(epoch from now() - last_at) / 86400 > (r ->> 'away_days')::numeric else false end);
end $function$;

create or replace function public.world_kin_talk()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_kin_rules(); k public.world_kin%rowtype; x jsonb;
  today date := (now() at time zone 'Asia/Seoul')::date; m jsonb; d jsonb; n int; key text; ln jsonb; cap int := (r ->> 'talk_day')::int;
  dd int; seen jsonb; w int; tot int; roll int; pool text[]; h text; idle_avoid int[]; first_fx boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into k from public.world_kin where owner_id = uid for update;
  if not found or k.npc is null or k.ended_at is not null then raise exception '맺은 백년지기가 없습니다.'; end if;
  m := coalesce(k.mem, '{}'::jsonb);
  d := case when k.day = today then coalesce(m -> 'd', '{}'::jsonb) else '{}'::jsonb end;
  n := coalesce((d ->> 'n')::int, 0);
  if n >= cap then raise exception '오늘은 더 말을 걸 수 없습니다(하루 %번). 내일 다시 와 주세요.', cap; end if;
  x := public.world_kin_ctx(uid, k);
  seen := coalesce(m -> 'seen', '[]'::jsonb);
  if n = 0 then
    dd := (x ->> 'days')::int;
    key := (select 't_days_' || v from jsonb_array_elements_text(r -> 'days') v
             where dd >= v::int and not seen ? ('t_days_' || v) order by v::int desc limit 1);
    if key is not null then seen := seen || to_jsonb(key); end if;
    if key is null and coalesce((x ->> 'away')::boolean, false) then key := 't_long_away'; end if;
  end if;
  if key is null and n = cap - 1 then key := 't_last_today'; end if;
  if key is null and x ->> 'heavy' is not null and coalesce((d ->> 'st')::int, 0) < (r -> 'cap' ->> 'state')::int
     and (coalesce((d ->> 'st')::int, 0) = 0 or random() * 100 < (r ->> 'state_pct')::numeric) then
    key := x ->> 'heavy'; d := d || jsonb_build_object('st', coalesce((d ->> 'st')::int, 0) + 1);
  end if;
  if key is null and x ->> 'light' is not null then key := x ->> 'light'; end if;
  if key is null and (d ->> 'ph') is distinct from (x ->> 'phase') and coalesce((d ->> 'first')::int, 0) < (r -> 'cap' ->> 'first')::int then
    key := 'first_' || (x ->> 'phase'); d := d || jsonb_build_object('ph', x ->> 'phase', 'first', coalesce((d ->> 'first')::int, 0) + 1);
  end if;
  if key is null then
    pool := array(select h2 from jsonb_array_elements_text(x -> 'homes') h2 where not coalesce(d -> 'home', '[]'::jsonb) ? h2);
    tot := (r -> 'pick' ->> 'idle')::int
         + case when coalesce((d ->> 'w')::int, 0) < (r -> 'cap' ->> 'weather')::int and x ->> 'weather' is not null then (r -> 'pick' ->> 'weather')::int else 0 end
         + case when coalesce(array_length(pool, 1), 0) > 0 then (r -> 'pick' ->> 'home')::int else 0 end;
    roll := floor(random() * tot)::int;
    if roll >= (r -> 'pick' ->> 'idle')::int and coalesce((d ->> 'w')::int, 0) < (r -> 'cap' ->> 'weather')::int and x ->> 'weather' is not null
       and roll < (r -> 'pick' ->> 'idle')::int + (r -> 'pick' ->> 'weather')::int then
      key := 'w_' || (x ->> 'weather'); d := d || jsonb_build_object('w', coalesce((d ->> 'w')::int, 0) + 1);
    elsif roll >= (r -> 'pick' ->> 'idle')::int and coalesce(array_length(pool, 1), 0) > 0
       and (roll >= (r -> 'pick' ->> 'idle')::int + (r -> 'pick' ->> 'weather')::int or coalesce((d ->> 'w')::int, 0) >= (r -> 'cap' ->> 'weather')::int or x ->> 'weather' is null) then
      h := pool[1 + floor(random() * array_length(pool, 1))::int];
      key := h; d := d || jsonb_build_object('home', coalesce(d -> 'home', '[]'::jsonb) || to_jsonb(h));
    else
      key := 'idle';
    end if;
  end if;
  if key = 'idle' then
    idle_avoid := array(select (v)::int from jsonb_array_elements_text(coalesce(m -> 'idle', '[]'::jsonb)) v);
    select jsonb_build_object('key', l.key, 'n', l.n, 'lines', l.lines) into ln from public.world_kin_lines l
     where l.npc = k.npc and l.key = 'idle' order by (l.n = any (idle_avoid)), random() limit 1;
    m := m || jsonb_build_object('idle', (select coalesce(jsonb_agg(v), '[]'::jsonb) from (
           select v from jsonb_array_elements(coalesce(m -> 'idle', '[]'::jsonb) || to_jsonb((ln ->> 'n')::int)) v) z
           offset greatest(0, jsonb_array_length(coalesce(m -> 'idle', '[]'::jsonb)) + 1 - (r ->> 'idle_recent')::int)));
  else
    ln := public.world_kin_line(k.npc, key, (m -> 'last' ->> key)::int);
    if ln is null then
      select jsonb_build_object('key', l.key, 'n', l.n, 'lines', l.lines) into ln from public.world_kin_lines l where l.npc = k.npc and l.key = 'idle' order by random() limit 1;
    end if;
    m := jsonb_set(m, '{last}', coalesce(m -> 'last', '{}'::jsonb) || jsonb_build_object(key, (ln ->> 'n')::int));
  end if;
  first_fx := n = 0;
  d := d || jsonb_build_object('n', n + 1);
  m := m || jsonb_build_object('d', d, 'seen', seen, 'last_at', now(), 'lv', (x ->> 'lv')::int, 'er', (x ->> 'er')::int);
  update public.world_kin set day = today, mem = m,
    fx_until = case when first_fx then now() + make_interval(hours => (r ->> 'fx_h')::int) else fx_until end,
    updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'npc', k.npc, 'talk', ln, 'left', cap - n - 1, 'cap', cap,
    'fx_until', case when first_fx then now() + make_interval(hours => (r ->> 'fx_h')::int) else k.fx_until end, 'wear', k.wear);
end $function$;

create or replace function public.world_kin_gift(p_item text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_kin_rules(); k public.world_kin%rowtype; c public.world_characters%rowtype;
  nr jsonb; today date := (now() at time zone 'Asia/Seoul')::date; inv jsonb; base text; hq boolean; infield boolean; key text;
  ln jsonb; rw jsonb; rid text; rn int := (r -> 'reward' ->> 'n')::int; got boolean := false; nm text; stored boolean := false;
begin
  perform public.world_travel_guard('백년지기 선물');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select * into k from public.world_kin where owner_id = uid for update;
  if not found or k.npc is null or k.ended_at is not null then raise exception '맺은 백년지기가 없습니다.'; end if;
  if k.gift_day = today then raise exception '선물은 하루에 한 번 줄 수 있습니다. 내일 다시 주세요.'; end if;
  if p_item is null or not exists (select 1 from public.world_item_catalog i where i.item_id = p_item) then raise exception '줄 물품을 골라 주세요.'; end if;
  if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = p_item) then raise exception '잠근 물품은 줄 수 없습니다. 잠금을 풀고 주세요.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  if public.world_give_check(uid, p_item, inv) < 1 then raise exception '줄 수 있는 물품이 아닙니다(장착 중·강화한 것·임무 물품은 빠집니다).'; end if;
  nr := public.world_kin_npc(k.npc);
  base := public.world_item_base(p_item); hq := base <> p_item;
  infield := public.world_kin_in_field(nr ->> 'line', base);
  key := case when infield and hq then 'gift_hq' when infield then 'gift_field' else 'gift_other' end;
  inv := public.world_inv_add(inv, p_item, -1);
  if infield and random() * 100 < (r -> 'reward' ->> 'pct')::numeric then
    rid := nr ->> 'reward';
    if exists (select 1 from public.world_item_catalog h where h.item_id = rid || '_hq') then rid := rid || '_hq'; end if;
    got := true;
    if public.world_bag_room(inv, rid, public.world_bag_limit(uid)) >= rn then
      inv := public.world_inv_add(inv, rid, rn);
    else
      stored := true;
    end if;
  end if;
  perform set_config('yh.wear_leaves', 'on', true);
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  if stored then perform public.world_letter_spill(uid, jsonb_build_object(rid, rn)); end if;
  update public.world_kin set gift_day = today, updated_at = now() where owner_id = uid;
  ln := public.world_kin_line(k.npc, key);
  if got then rw := public.world_kin_line(k.npc, 'gift_reward'); end if;
  nm := (select item_name from public.world_item_catalog where item_id = p_item);
  return jsonb_build_object('ok', true, 'npc', k.npc, 'talk', ln, 'reward_talk', rw, 'infield', infield,
    'reward', case when got then jsonb_build_object('id', rid, 'n', rn, 'name', (select item_name from public.world_item_catalog where item_id = rid), 'stored', stored) end,
    'content', public.world_josa(nr ->> 'short', '에게', '에게') || ' 「' || nm || '」을(를) 건넸습니다.' ||
      case when got then ' 답례로 「' || (select item_name from public.world_item_catalog where item_id = rid) || '」 ' || rn || '개를 받았습니다' || case when stored then '(가방이 차서 창고로).' else '.' end else '' end);
end $function$;

create or replace function public.world_kin_room_set(p_room int)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); k public.world_kin%rowtype; why text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into k from public.world_kin where owner_id = uid for update;
  if not found or k.npc is null or k.ended_at is not null then raise exception '맺은 백년지기가 없습니다.'; end if;
  why := public.world_housing_room_ok(public.world_housing_home(uid), p_room);
  if why is not null then raise exception '%', why; end if;
  update public.world_kin set room = p_room, updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'room', p_room, 'content', '백년지기가 지낼 방을 옮겼습니다.');
end $function$;

create or replace function public.world_kin_home(p_home uuid, p_viewer uuid)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_kin_rules(); today date := (now() at time zone 'Asia/Seoul')::date;
begin
  return (select coalesce(jsonb_agg(jsonb_build_object(
      'owner', k.owner_id, 'npc', k.npc, 'name', public.world_kin_npc(k.npc) ->> 'short', 'token', public.world_kin_npc(k.npc) ->> 'token',
      'room', public.world_housing_room_eff(p_home, k.room), 'mine', k.owner_id = p_viewer,
      'wear', case when k.owner_id = p_viewer then k.wear end,
      'fx_until', case when k.owner_id = p_viewer then k.fx_until end,
      'left', case when k.owner_id = p_viewer then (r ->> 'talk_day')::int - case when k.day = today then coalesce((k.mem -> 'd' ->> 'n')::int, 0) else 0 end end,
      'gift', case when k.owner_id = p_viewer then k.gift_day is distinct from today end,
      'line_name', case when k.owner_id = p_viewer then public.world_kin_npc(k.npc) ->> 'line_name' end,
      'made_at', k.made_at) order by k.owner_id = p_viewer desc), '[]'::jsonb)
    from public.world_kin k
   where k.npc is not null and k.ended_at is null
     and (k.owner_id = p_home or k.owner_id in (select s.mate_id from public.world_housing_shared s where s.home_id = p_home)));
end $function$;

create or replace function public.world_kin_greet(p_owner uuid)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); k public.world_kin%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into k from public.world_kin where owner_id = p_owner and npc is not null and ended_at is null;
  if not found then raise exception '그 백년지기는 지금 별채에 없습니다.'; end if;
  if public.world_housing_home(p_owner) <> public.world_housing_home(uid) then raise exception '한 지붕 아래에서만 인사할 수 있습니다.'; end if;
  return jsonb_build_object('npc', k.npc, 'talk', public.world_kin_line(k.npc, 'first_' || public.world_time_phase(now())));
end $function$;
