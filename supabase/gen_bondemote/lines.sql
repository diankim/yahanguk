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

delete from public.world_bond_emote_lines;
insert into public.world_bond_emote_lines(emote, ctx, tier, line) values
  ('hug', 'base', 'all', '{정인}이(가) 잠깐 놀란 듯하더니 곧 팔을 둘러 마주 안아 줍니다.'),
  ('hug', 'base', 'all', '{정인}이(가) 안긴 채로 {이름}의 등을 두어 번 가볍게 두드립니다.'),
  ('hug', 'base', 'all', '{정인}이(가) 숨을 한 번 크게 들이쉬고 천천히 몸에 힘을 뺍니다.'),
  ('hug', 'base', 'all', '{정인}이(가) 품 안에서 고개를 들어 {이름}을(를) 올려다봅니다. 표정이 한결 부드러워진 것 같습니다.'),
  ('hug', 'base', 'all', '{정인}이(가) 빨래를 개던 손을 멈추고 그대로 안아 줍니다. 개다 만 옷가지가 무릎에서 흘러내립니다.'),
  ('hug', 'base', 'all', '{정인}이(가) 부엌에서 나오다 말고 앞치마 차림으로 안깁니다. 밀가루가 묻은 손은 허공에 든 채입니다.'),
  ('hug', 'base', 't1', '{정인}이(가) 굳은 채로 안겼다가 이내 마주 안아 줍니다. 귀 끝이 조금 빨개진 것 같습니다.'),
  ('hug', 'base', 't1', '{정인}이(가) 두 팔을 어디 둘지 몰라 잠깐 머뭇거리다가 등을 가만히 토닥여 줍니다.'),
  ('hug', 'base', 't1', '{정인}이(가) 안기자마자 숨을 멈춘 것처럼 가만히 있습니다. 심장 소리가 크게 들리는 것 같습니다.'),
  ('hug', 'base', 't2', '{정인}이(가) 기다렸다는 듯 꼭 끌어안아 줍니다. 한동안 놓아줄 생각이 없어 보입니다.'),
  ('hug', 'base', 't2', '{정인}이(가) 품에 얼굴을 묻고 가만히 있다가 천천히 숨을 내쉽니다.'),
  ('hug', 'base', 't2', '{정인}이(가) 안긴 채로 몸을 좌우로 살랑살랑 흔듭니다.'),
  ('hug', 'base', 't2', '{정인}이(가) 품을 빠져나가려다 말고 다시 파고듭니다.'),
  ('hug', 'base', 't3', '{정인}이(가) 등을 천천히 쓸어내리며 오래 안아 줍니다. 무사히 돌아온 것을 확인하는 듯합니다.'),
  ('hug', 'base', 't3', '{정인}이(가) 한참을 놓지 않습니다. 팔에 힘이 조금 더 들어간 것 같습니다.'),
  ('hug', 'base', 't3', '{정인}이(가) {이름}의 어깨에 얼굴을 묻고 한동안 움직이지 않습니다.'),
  ('hug', 'base', 't3', '{정인}이(가) 놓아줄 듯하다가 다시 한 번 꼭 끌어안습니다.'),
  ('hug', 'base', 't4', '{정인}이(가) 익숙하게 어깨에 턱을 얹습니다. 그 자리가 제 자리인 듯 편안해 보입니다.'),
  ('hug', 'base', 't4', '{정인}이(가) 안긴 채로 작게 하품을 합니다. {이름}의 품이 꽤 졸린 모양입니다.'),
  ('hug', 'base', 't4', '{정인}이(가) 안긴 채로 {이름}의 옷깃에 묻은 먼지를 무심하게 털어 줍니다.'),
  ('hug', 'base', 't4', '{정인}이(가) 등을 두어 번 두드리고는 하던 일로 자연스럽게 돌아갑니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 내민 손을 마주 잡고 살며시 힘을 줍니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 맞잡은 손을 잠시 들여다보다가 손가락을 하나씩 엮어 깍지를 낍니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 손을 잡은 채 {이름} 쪽으로 반 걸음 다가섭니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 맞잡은 손을 제 쪽으로 가볍게 당깁니다. 어디든 같이 가자는 뜻인 것 같습니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 장 보러 가는 길인 듯 장바구니를 다른 손으로 옮겨 들고 손을 잡아 줍니다.'),
  ('hand', 'base', 'all', '{정인}이(가) 마당을 쓸던 빗자루를 벽에 기대 세워 두고 손을 내밉니다.'),
  ('hand', 'base', 't1', '{정인}이(가) 손끝이 닿자 움찔했다가 슬그머니 다시 손을 내밉니다.'),
  ('hand', 'base', 't1', '{정인}이(가) 맞잡은 손을 한참 내려다봅니다. 손에 살짝 땀이 밴 것 같습니다.'),
  ('hand', 'base', 't1', '{정인}이(가) 손을 잡히자 시선을 어디 둘지 몰라 하늘만 올려다봅니다.'),
  ('hand', 'base', 't2', '{정인}이(가) 깍지를 끼고 맞잡은 손을 앞뒤로 크게 흔듭니다.'),
  ('hand', 'base', 't2', '{정인}이(가) 엄지로 손바닥의 굳은살을 문질러 봅니다. 요즘 무슨 일을 했는지 알아챈 듯합니다.'),
  ('hand', 'base', 't2', '{정인}이(가) 잡은 손을 크게 휘저으며 앞장서 걷습니다.'),
  ('hand', 'base', 't2', '{정인}이(가) 손가락으로 {이름}의 손등을 톡톡 두드립니다. 장난을 치고 싶은 모양입니다.'),
  ('hand', 'base', 't3', '{정인}이(가) 손을 꼭 쥐고 쉽게 놓지 않습니다.'),
  ('hand', 'base', 't3', '{정인}이(가) 맞잡은 손등에 이마를 살며시 기댑니다.'),
  ('hand', 'base', 't3', '{정인}이(가) 손의 온기를 오래 확인하듯 천천히 쓸어 봅니다.'),
  ('hand', 'base', 't3', '{정인}이(가) 맞잡은 손을 제 가슴께로 가져가 잠시 머뭅니다.'),
  ('hand', 'base', 't4', '{정인}이(가) 쳐다보지도 않고 손을 찾아 잡습니다. 손이 먼저 길을 아는 것 같습니다.'),
  ('hand', 'base', 't4', '{정인}이(가) 잡은 손을 그대로 제 소매 속에 같이 넣어 둡니다.'),
  ('hand', 'base', 't4', '{정인}이(가) 손을 잡은 채로 다른 손으로는 하던 일을 계속합니다.'),
  ('hand', 'base', 't4', '{정인}이(가) 손을 잡자마자 익숙하게 걸음을 맞춥니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 쓰다듬는 손길에 눈을 가늘게 뜹니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 고개를 살짝 기울여 손이 닿기 좋게 해 줍니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 손이 떠나자 아쉬운 듯 {이름}을(를) 흘끔 봅니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 쓰다듬어지는 동안 얌전히 서 있습니다. 기분이 좋아 보입니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 마루 끝에 앉아 콩을 고르다가 고개만 내밀어 줍니다.'),
  ('pat', 'base', 'all', '{정인}이(가) 막 감은 머리를 수건으로 말리던 참이라 손에 물기가 조금 묻어납니다.'),
  ('pat', 'base', 't1', '{정인}이(가) 눈을 질끈 감고 가만히 있습니다. 싫지는 않은 것 같습니다.'),
  ('pat', 'base', 't1', '{정인}이(가) 손길을 피하지 못하고 고개를 살짝 숙입니다. 머리 모양이 신경 쓰이는 듯합니다.'),
  ('pat', 'base', 't1', '{정인}이(가) 손이 닿는 순간 어깨를 움찔 떨었다가 천천히 긴장을 풉니다.'),
  ('pat', 'base', 't2', '{정인}이(가) 머리를 손바닥 쪽으로 꾹 밀어붙입니다. 한 번 더 해 달라는 뜻인 것 같습니다.'),
  ('pat', 'base', 't2', '{정인}이(가) 헝클어진 머리를 손가락으로 대충 넘기고 피식 웃습니다.'),
  ('pat', 'base', 't2', '{정인}이(가) 손을 붙잡아 제 머리를 대신 마구 헝클어뜨립니다.'),
  ('pat', 'base', 't2', '{정인}이(가) 이번에는 {이름}의 머리를 쓰다듬어 되갚아 줍니다.'),
  ('pat', 'base', 't3', '{정인}이(가) 손길에 기대어 천천히 숨을 내쉽니다. 어깨에서 힘이 빠진 것 같습니다.'),
  ('pat', 'base', 't3', '{정인}이(가) 쓰다듬던 손을 붙잡아 제 뺨에 가져다 댑니다.'),
  ('pat', 'base', 't3', '{정인}이(가) 손길이 멈추지 않도록 그대로 가만히 기대 있습니다.'),
  ('pat', 'base', 't3', '{정인}이(가) 쓰다듬는 손 아래에서 아주 작게 웃습니다.'),
  ('pat', 'base', 't4', '{정인}이(가) 하던 일을 멈추지 않은 채 머리만 손 쪽으로 기울여 줍니다.'),
  ('pat', 'base', 't4', '{정인}이(가) 눈도 뜨지 않고 고개를 조금씩 움직여 쓰다듬을 자리를 알려 줍니다.'),
  ('pat', 'base', 't4', '{정인}이(가) 쓰다듬는 손을 한 손으로 붙잡아 머리 위에 얹어 둔 채 책장을 넘깁니다.'),
  ('pat', 'base', 't4', '{정인}이(가) 쓰다듬어지는 데 익숙한 듯 꾸벅 졸기 시작합니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 장난을 알아채고 눈을 가늘게 뜹니다. 반격을 궁리하는 것 같습니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 화들짝 놀랐다가 웃음을 터뜨립니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 어깨로 {이름}을(를) 가볍게 밀어냅니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 모르는 척 고개를 돌렸다가 갑자기 돌아서서 똑같이 장난을 칩니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 찻잔을 든 채로 장난을 피하느라 차를 흘리지 않으려 애씁니다.'),
  ('tease', 'base', 'all', '{정인}이(가) 신발을 짝짝이로 신고 나가려던 참에 장난을 당하고 그제야 발밑을 내려다봅니다.'),
  ('tease', 'base', 't1', '{정인}이(가) 옆구리를 찔리자 펄쩍 뛰어오릅니다. 얼굴이 금세 붉어진 것 같습니다.'),
  ('tease', 'base', 't1', '{정인}이(가) 머리에 꽂힌 풀잎을 뒤늦게 발견하고 {이름}을(를) 빤히 쳐다봅니다.'),
  ('tease', 'base', 't1', '{정인}이(가) 어쩔 줄 몰라 하며 두 손으로 얼굴을 가립니다. 손가락 틈으로 웃고 있는 것 같습니다.'),
  ('tease', 'base', 't2', '{정인}이(가) 지지 않고 똑같이 볼을 쭉 늘려 돌려줍니다.'),
  ('tease', 'base', 't2', '{정인}이(가) 차가운 손을 {이름}의 목덜미에 슬쩍 갖다 댑니다. 반격할 때를 기다린 듯합니다.'),
  ('tease', 'base', 't2', '{정인}이(가) 소매를 걷어붙이고 본격적으로 반격할 자세를 잡습니다.'),
  ('tease', 'base', 't2', '{정인}이(가) 잡히지 않으려고 마당을 한 바퀴 돌아 달아납니다.'),
  ('tease', 'base', 't3', '{정인}이(가) 장난을 받아 주다가 결국 웃음을 터뜨립니다.'),
  ('tease', 'base', 't3', '{정인}이(가) 입을 삐죽 내밀었다가 금세 풀고 어깨를 툭 부딪쳐 옵니다.'),
  ('tease', 'base', 't3', '{정인}이(가) 장난에 넘어가 주고는 {이름}이(가) 웃는 얼굴을 한참 바라봅니다.'),
  ('tease', 'base', 't3', '{정인}이(가) 토라진 척 등을 돌렸다가 금세 돌아봅니다.'),
  ('tease', 'base', 't4', '{정인}이(가) 피하지도 않고 담담한 얼굴로 서 있습니다. 이미 다 읽힌 수법인 것 같습니다.'),
  ('tease', 'base', 't4', '{정인}이(가) 모르는 척하다가 다리를 슬쩍 걸어 함께 넘어집니다.'),
  ('tease', 'base', 't4', '{정인}이(가) 하품을 하며 장난을 흘려보냅니다. 오늘은 넘어가 주는 모양입니다.'),
  ('tease', 'base', 't4', '{정인}이(가) 미리 준비해 둔 듯 품에서 장난감 거미를 꺼내 보입니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 쑥스러운 듯 뒷머리를 긁적입니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 칭찬을 듣고 어깨를 으쓱합니다. 기분이 좋아진 것 같습니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 고개를 끄덕이며 {이름}에게 엄지를 세워 보입니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 입꼬리를 감추지 못하고 시선을 피합니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 방금 개어 둔 이부자리를 가리키며 그것도 칭찬해 달라는 얼굴을 합니다.'),
  ('praise', 'base', 'all', '{정인}이(가) 밥상을 차리다 말고 수저를 든 채 웃습니다.'),
  ('praise', 'base', 't1', '{정인}이(가) 손사래를 치다가 소매로 입가를 가립니다. 입꼬리가 올라간 것 같습니다.'),
  ('praise', 'base', 't1', '{정인}이(가) 눈을 동그랗게 뜨고 {이름}을(를) 쳐다봅니다. 방금 들은 말을 곱씹는 듯합니다.'),
  ('praise', 'base', 't1', '{정인}이(가) 손부채질을 하며 얼굴의 열기를 식힙니다.'),
  ('praise', 'base', 't2', '{정인}이(가) 허리에 손을 얹고 턱을 살짝 치켜듭니다. 꽤 뿌듯해 보입니다.'),
  ('praise', 'base', 't2', '{정인}이(가) 칭찬을 그대로 돌려주려는 듯 {이름}을(를) 손가락으로 가리킵니다.'),
  ('praise', 'base', 't2', '{정인}이(가) 한 바퀴 빙그르르 돌며 자랑하듯 몸짓을 해 보입니다.'),
  ('praise', 'base', 't2', '{정인}이(가) 칭찬받은 김에 {이름}의 어깨를 툭툭 두드려 줍니다.'),
  ('praise', 'base', 't3', '{정인}이(가) 잠깐 말을 잃고 {이름}을(를) 바라봅니다. 눈가가 조금 붉어진 것 같습니다.'),
  ('praise', 'base', 't3', '{정인}이(가) 고개를 숙이고 한참 웃습니다. 오늘 들은 말 중에 제일 좋았던 모양입니다.'),
  ('praise', 'base', 't3', '{정인}이(가) {이름}의 손을 꼭 쥐고 고맙다는 듯 고개를 숙입니다.'),
  ('praise', 'base', 't3', '{정인}이(가) 웃음 끝에 조용히 {이름}의 곁에 기대섭니다.'),
  ('praise', 'base', 't4', '{정인}이(가) 귀에 손을 대고 한 번 더 말해 보라는 시늉을 합니다.'),
  ('praise', 'base', 't4', '{정인}이(가) 헛기침을 하며 딴청을 피웁니다. 귀가 빨개진 것은 감추지 못한 것 같습니다.'),
  ('praise', 'base', 't4', '{정인}이(가) 들은 척 만 척하다가 슬그머니 콧노래를 흥얼거립니다.'),
  ('praise', 'base', 't4', '{정인}이(가) 칭찬을 받아 적는 시늉을 합니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 가만히 고개를 끄덕이며 곁에 앉습니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 어깨를 토닥이는 손에 천천히 숨을 고릅니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 한숨을 길게 내쉬고 {이름} 쪽으로 몸을 기울입니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 말없이 {이름}의 손을 찾아 쥡니다. 조금 나아진 것 같습니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 끓던 찻물을 불에서 내려놓고 곁으로 와 앉습니다.'),
  ('comfort', 'base', 'all', '{정인}이(가) 바느질하던 옷을 무릎에 내려놓고 {이름}의 손을 잡습니다.'),
  ('comfort', 'base', 't1', '{정인}이(가) 조심스럽게 고개를 끄덕입니다. 티를 내지 않으려 했던 것 같습니다.'),
  ('comfort', 'base', 't1', '{정인}이(가) 어깨에 얹힌 손을 가만히 내려다보다가 그 위에 자기 손을 포갭니다.'),
  ('comfort', 'base', 't1', '{정인}이(가) 괜찮다는 듯 웃어 보이지만 눈가가 촉촉해 보입니다.'),
  ('comfort', 'base', 't2', '{정인}이(가) 털썩 기대 앉아 한동안 말없이 있습니다. 조금 나아진 듯합니다.'),
  ('comfort', 'base', 't2', '{정인}이(가) 코를 훌쩍이다가 고개를 돌립니다. 우는 얼굴은 보이고 싶지 않은 것 같습니다.'),
  ('comfort', 'base', 't2', '{정인}이(가) 무릎을 끌어안고 앉아 {이름} 쪽으로 머리를 기울입니다.'),
  ('comfort', 'base', 't2', '{정인}이(가) 따뜻한 차를 두 잔 따라 하나를 {이름}에게 내밉니다.'),
  ('comfort', 'base', 't3', '{정인}이(가) 등을 맡긴 채 천천히 숨을 고릅니다.'),
  ('comfort', 'base', 't3', '{정인}이(가) {이름}의 소매 끝을 꼭 붙잡고 놓지 않습니다.'),
  ('comfort', 'base', 't3', '{정인}이(가) {이름}의 품에 기대어 눈을 감습니다. 마음이 놓인 것 같습니다.'),
  ('comfort', 'base', 't3', '{정인}이(가) 떨리는 손을 감추지 않고 {이름}에게 맡깁니다.'),
  ('comfort', 'base', 't4', '{정인}이(가) 말없이 머리를 어깨에 기댑니다. 이 정도면 충분하다는 듯합니다.'),
  ('comfort', 'base', 't4', '{정인}이(가) 눈을 감은 채 옅게 웃습니다. 무엇을 해 줄지 이미 알고 있었던 것 같습니다.'),
  ('comfort', 'base', 't4', '{정인}이(가) 담요를 둘러쓰고 {이름}의 옆자리를 툭툭 칩니다.'),
  ('comfort', 'base', 't4', '{정인}이(가) {이름}의 어깨에 기댄 채 금세 잠이 듭니다.'),
  ('five', 'base', 'all', '{정인}이(가) 손바닥을 마주 맞추고 활짝 웃습니다.'),
  ('five', 'base', 'all', '{정인}이(가) 손을 높이 들어 힘차게 맞받아 줍니다.'),
  ('five', 'base', 'all', '{정인}이(가) 맞춘 손바닥을 털며 신난 듯 발을 구릅니다.'),
  ('five', 'base', 'all', '{정인}이(가) 손을 맞춘 뒤 주먹을 쥐어 보입니다. 다음 일도 해낼 기세입니다.'),
  ('five', 'base', 'all', '{정인}이(가) 장작을 다 패고 난 참이라 손바닥이 조금 거칩니다.'),
  ('five', 'base', 'all', '{정인}이(가) 밭에서 막 돌아와 흙 묻은 손을 털고는 힘차게 손뼉을 맞춥니다.'),
  ('five', 'base', 't1', '{정인}이(가) 손바닥을 맞추고는 그 손을 한참 내려다봅니다.'),
  ('five', 'base', 't1', '{정인}이(가) 한 박자 늦게 손을 들어 허공을 치고는 얼굴을 감쌉니다.'),
  ('five', 'base', 't1', '{정인}이(가) 손바닥이 닿자 깜짝 놀라 손을 털다가 쑥스럽게 웃습니다.'),
  ('five', 'base', 't2', '{정인}이(가) 손바닥이 얼얼할 만큼 힘차게 맞받아 줍니다.'),
  ('five', 'base', 't2', '{정인}이(가) 맞춘 손을 그대로 깍지 껴 버립니다.'),
  ('five', 'base', 't2', '{정인}이(가) 하이파이브 끝에 팔꿈치까지 부딪쳐 옵니다.'),
  ('five', 'base', 't2', '{정인}이(가) 손바닥을 맞추고 한쪽 발로 깡충 뜁니다.'),
  ('five', 'base', 't3', '{정인}이(가) 손을 맞댄 채 {이름}과(와) 눈을 맞추고 고개를 끄덕입니다.'),
  ('five', 'base', 't3', '{정인}이(가) 맞댄 손을 쉽게 떼지 못합니다.'),
  ('five', 'base', 't3', '{정인}이(가) 맞댄 손을 그대로 내려 {이름}의 손을 잡습니다.'),
  ('five', 'base', 't3', '{정인}이(가) 손을 맞춘 뒤 조용히 웃으며 이마를 톡 맞댑니다.'),
  ('five', 'base', 't4', '{정인}이(가) 위로, 아래로, 옆으로 둘만 아는 순서대로 손을 맞춥니다. 한 번도 틀리지 않습니다.'),
  ('five', 'base', 't4', '{정인}이(가) 손바닥을 내밀었다가 맞추기 직전에 쓱 뺍니다. 장난기가 가득한 얼굴입니다.'),
  ('five', 'base', 't4', '{정인}이(가) 보지도 않고 손을 뻗어 정확히 맞춥니다.'),
  ('five', 'base', 't4', '{정인}이(가) 하이파이브를 받아 주는 척하다가 손바닥에 콩알 하나를 쥐여 줍니다.'),
  ('dance', 'base', 'all', '{정인}이(가) 손을 맞잡고 박자에 맞춰 천천히 몸을 흔듭니다.'),
  ('dance', 'base', 'all', '{정인}이(가) {이름}의 이끄는 대로 한 바퀴 빙그르르 돕니다.'),
  ('dance', 'base', 'all', '{정인}이(가) 발끝을 맞춰 보려 애쓰다가 함께 웃음을 터뜨립니다.'),
  ('dance', 'base', 'all', '{정인}이(가) 춤을 마치고 가볍게 고개 숙여 인사를 합니다.'),
  ('dance', 'base', 'all', '{정인}이(가) 설거지를 하다 말고 젖은 손을 앞치마에 닦으며 따라 돕니다.'),
  ('dance', 'base', 'all', '{정인}이(가) 마당에 널어 둔 빨래 사이를 빙글빙글 돌며 춤을 춥니다.'),
  ('dance', 'base', 't1', '{정인}이(가) 발을 밟고 깜짝 놀라 펄쩍 물러섭니다. 춤이 영 서툰 것 같습니다.'),
  ('dance', 'base', 't1', '{정인}이(가) 서툴게 한 바퀴 돌다가 웃음을 참지 못합니다. 누가 볼까 봐 문 쪽을 흘끔거립니다.'),
  ('dance', 'base', 't1', '{정인}이(가) 손을 어디 둘지 몰라 허둥대다가 결국 {이름}의 소매를 잡습니다.'),
  ('dance', 'base', 't2', '{정인}이(가) 엉터리 박자로 몸을 흔듭니다. 박자는 상관없는 듯합니다.'),
  ('dance', 'base', 't2', '{정인}이(가) 손을 잡고 빙글 돌며 신나게 따라옵니다.'),
  ('dance', 'base', 't2', '{정인}이(가) 마당을 무대 삼아 과장된 몸짓으로 빙글빙글 돕니다.'),
  ('dance', 'base', 't2', '{정인}이(가) 손뼉으로 장단을 치며 {이름}의 춤을 거듭니다.'),
  ('dance', 'base', 't3', '{정인}이(가) 느리게 몸을 흔들다가 이마를 맞댑니다.'),
  ('dance', 'base', 't3', '{정인}이(가) 춤을 멈추고 가만히 끌어안습니다. 음악이 없어도 괜찮은 것 같습니다.'),
  ('dance', 'base', 't3', '{정인}이(가) 춤추는 동안 한순간도 {이름}에게서 눈을 떼지 않습니다.'),
  ('dance', 'base', 't3', '{정인}이(가) 천천히 돌다가 {이름}의 어깨에 살며시 머리를 기댑니다.'),
  ('dance', 'base', 't4', '{정인}이(가) 일부러 엉망으로 추며 {이름}을(를) 웃깁니다.'),
  ('dance', 'base', 't4', '{정인}이(가) 발을 밟히고도 태연하게 다음 동작을 이어 갑니다.'),
  ('dance', 'base', 't4', '{정인}이(가) 둘만 아는 엉터리 춤을 정확한 순서대로 춥니다.'),
  ('dance', 'base', 't4', '{정인}이(가) 춤추다 말고 부엌으로 가서 국을 한 번 젓고 돌아옵니다.'),
  ('any', 'time:dawn', 'all', '{정인}이(가) 기지개를 켜다가 {이름}을(를) 보고 팔을 내리지도 않은 채 웃습니다.'),
  ('any', 'time:dawn', 'all', '{정인}이(가) 세숫물을 떠 오다가 걸음을 멈추고 돌아봅니다.'),
  ('any', 'time:dawn', 'all', '{정인}이(가) 아궁이에 불을 지피다 말고 재 묻은 얼굴로 돌아봅니다.'),
  ('any', 'time:dawn', 'all', '{정인}이(가) 이불을 개다 말고 그 위에 털썩 주저앉습니다.'),
  ('any', 'time:dawn', 't1', '{정인}이(가) 덜 뜬 눈을 비비다가 {이름}을(를) 보고 허둥지둥 머리를 매만집니다.'),
  ('any', 'time:dawn', 't2', '{정인}이(가) 까치집 머리 그대로 느릿느릿 다가옵니다. 아직 잠이 덜 깬 것 같습니다.'),
  ('any', 'time:dawn', 't3', '{정인}이(가) 창으로 드는 햇살 속에서 {이름}을(를) 한참 바라봅니다.'),
  ('any', 'time:dawn', 't4', '{정인}이(가) 길게 하품을 하며 아침상 쪽을 턱으로 가리킵니다.'),
  ('any', 'time:noon', 'all', '{정인}이(가) 볕을 피해 처마 그늘로 {이름}을(를) 끌어당깁니다.'),
  ('any', 'time:noon', 'all', '{정인}이(가) 점심을 먹다 말고 숟가락을 든 채 돌아봅니다.'),
  ('any', 'time:noon', 'all', '{정인}이(가) 마당에 고추를 널다가 손을 털고 다가옵니다.'),
  ('any', 'time:noon', 'all', '{정인}이(가) 툇마루에서 꾸벅꾸벅 졸다가 화들짝 깹니다.'),
  ('any', 'time:noon', 't1', '{정인}이(가) 볕에 달아오른 뺨을 손등으로 식힙니다. 더위 때문만은 아닌 것 같습니다.'),
  ('any', 'time:noon', 't2', '{정인}이(가) 마루에 대자로 누운 채 옆자리를 손바닥으로 툭툭 칩니다.'),
  ('any', 'time:noon', 't3', '{정인}이(가) 바쁜 한낮에 일부러 들른 듯 숨이 조금 차 있습니다.'),
  ('any', 'time:noon', 't4', '{정인}이(가) 부채를 부치다가 바람을 {이름} 쪽으로 돌려 줍니다.'),
  ('any', 'time:dusk', 'all', '{정인}이(가) 마당의 빨래를 걷다 말고 돌아섭니다.'),
  ('any', 'time:dusk', 'all', '{정인}이(가) 노을을 등지고 서서 {이름}이(가) 오기를 기다립니다.'),
  ('any', 'time:dusk', 'all', '{정인}이(가) 저녁 쌀을 씻다가 젖은 손을 털며 돌아봅니다.'),
  ('any', 'time:dusk', 'all', '{정인}이(가) 하루 장부를 정리하던 붓을 내려놓습니다.'),
  ('any', 'time:dusk', 't1', '{정인}이(가) 노을빛에 물든 얼굴로 창밖과 {이름}을(를) 번갈아 봅니다.'),
  ('any', 'time:dusk', 't2', '{정인}이(가) 등롱에 불을 붙이다 말고 돌아봅니다. 저녁거리를 고민하는 듯합니다.'),
  ('any', 'time:dusk', 't3', '{정인}이(가) 하루를 마친 얼굴로 조용히 어깨에 기댑니다.'),
  ('any', 'time:dusk', 't4', '{정인}이(가) 벌써 이부자리를 펴 두고 그 옆에 앉아 있습니다.'),
  ('any', 'time:night', 'all', '{정인}이(가) 등잔 심지를 낮추고 소리 죽여 다가옵니다.'),
  ('any', 'time:night', 'all', '{정인}이(가) 잠든 척하다가 한쪽 눈을 살며시 뜹니다.'),
  ('any', 'time:night', 'all', '{정인}이(가) 등잔 아래 읽던 책을 덮고 하품을 삼킵니다.'),
  ('any', 'time:night', 'all', '{정인}이(가) 물 한 모금 마시러 나왔다가 마주칩니다.'),
  ('any', 'time:night', 't1', '{정인}이(가) 깜짝 놀라 소리를 삼킵니다. 이 밤에 잠이 다 달아난 것 같습니다.'),
  ('any', 'time:night', 't2', '{정인}이(가) 이불을 들어 올려 들어오라는 시늉을 합니다.'),
  ('any', 'time:night', 't3', '{정인}이(가) 잠결에 손을 더듬어 {이름}의 손을 찾아 쥡니다.'),
  ('any', 'time:night', 't4', '{정인}이(가) 눈을 감은 채 돌아누우며 이불 한쪽을 내어 줍니다.'),
  ('any', 'w:rain', 'all', '{정인}이(가) 빗방울이 맺힌 {이름}의 머리를 손바닥으로 훔쳐 줍니다.'),
  ('any', 'w:rain', 'all', '{정인}이(가) 우산 하나를 펴 들고 {이름} 쪽으로 기울입니다.'),
  ('any', 'w:rain', 'all', '{정인}이(가) 처마 밑에 장독 뚜껑을 덮고 들어옵니다.'),
  ('any', 'w:rain', 'all', '{정인}이(가) 젖은 신발을 문간에 나란히 세워 둡니다.'),
  ('any', 'w:rain', 't1', '{정인}이(가) 처마 끝 빗줄기와 {이름}을(를) 번갈아 봅니다. 비 오는 날이 싫지 않은 것 같습니다.'),
  ('any', 'w:rain', 't2', '{정인}이(가) 젖은 머리를 털며 마른 수건부터 내밉니다.'),
  ('any', 'w:rain', 't3', '{정인}이(가) 빗소리에 귀를 기울이다가 {이름} 곁으로 바짝 다가앉습니다.'),
  ('any', 'w:rain', 't4', '{정인}이(가) 마당의 빗물받이 통을 보고 흡족한 듯 고개를 끄덕입니다.'),
  ('any', 'w:snow', 'all', '{정인}이(가) 하얀 입김을 불며 손을 비빕니다.'),
  ('any', 'w:snow', 'all', '{정인}이(가) 눈송이를 손바닥에 받아 {이름}에게 보여 줍니다.'),
  ('any', 'w:snow', 'all', '{정인}이(가) 마당에 쌓인 눈을 쓸다 말고 빗자루에 기대섭니다.'),
  ('any', 'w:snow', 'all', '{정인}이(가) 화롯불에 군밤을 굽다가 하나를 건넵니다.'),
  ('any', 'w:snow', 't1', '{정인}이(가) {이름}의 어깨에 쌓인 눈을 털어 주다가 손이 닿자 움찔합니다.'),
  ('any', 'w:snow', 't2', '{정인}이(가) 등 뒤에 무언가를 숨긴 채 다가옵니다. 손이 차갑게 젖어 있는 것 같습니다.'),
  ('any', 'w:snow', 't3', '{정인}이(가) 언 손을 제 두 손으로 감싸 녹여 줍니다.'),
  ('any', 'w:snow', 't4', '{정인}이(가) 화로 옆자리를 말없이 내어 줍니다.'),
  ('any', 'w:fog', 'all', '{정인}이(가) 안개 속에서 손을 휘저어 {이름}을(를) 찾습니다.'),
  ('any', 'w:fog', 'all', '{정인}이(가) 등롱을 들어 둘 사이의 안개를 비춥니다.'),
  ('any', 'w:fog', 'all', '{정인}이(가) 눅눅해진 이불을 걷어 들이며 고개를 갸웃합니다.'),
  ('any', 'w:fog', 'all', '{정인}이(가) 등잔 심지를 돋우어 방 안을 조금 더 밝힙니다.'),
  ('any', 'w:fog', 't1', '{정인}이(가) 안개 너머에서 {이름}을(를) 찾아내고 안도하는 얼굴이 됩니다.'),
  ('any', 'w:fog', 't2', '{정인}이(가) 안개 속에서 길을 잃지 않으려는 듯 소매를 꼭 붙잡습니다.'),
  ('any', 'w:fog', 't3', '{정인}이(가) 뿌연 마당을 내다보다가 {이름} 쪽으로 몸을 돌립니다.'),
  ('any', 'w:fog', 't4', '{정인}이(가) 코끝을 찡그리며 부엌 쪽을 흘끔거립니다. 따뜻한 국물이 당기는 듯합니다.'),
  ('any', 'w:wind', 'all', '{정인}이(가) 바람에 펄럭이는 옷자락을 붙잡느라 정신이 없습니다.'),
  ('any', 'w:wind', 'all', '{정인}이(가) 바람을 등지고 {이름}의 앞을 막아 섭니다.'),
  ('any', 'w:wind', 'all', '{정인}이(가) 날아간 빨래를 주워 들고 돌아옵니다.'),
  ('any', 'w:wind', 'all', '{정인}이(가) 덜컹이는 문고리를 끈으로 묶어 둡니다.'),
  ('any', 'w:wind', 't1', '{정인}이(가) 바람에 날린 머리카락을 급히 정리합니다. 신경이 쓰이는 것 같습니다.'),
  ('any', 'w:wind', 't2', '{정인}이(가) 문풍지 떠는 소리에 어깨를 움츠리며 바짝 붙어 앉습니다.'),
  ('any', 'w:wind', 't3', '{정인}이(가) 겉옷을 벗어 {이름}의 어깨에 둘러 줍니다.'),
  ('any', 'w:wind', 't4', '{정인}이(가) 덜컹이는 창을 쳐다보다가 {이름}과(와) 눈이 마주치자 어깨를 으쓱합니다.'),
  ('any', 'w:bloodmist', 'all', '{정인}이(가) 붉은 안개를 헤치고 와서 {이름}의 얼굴부터 살핍니다.'),
  ('any', 'w:bloodmist', 'all', '{정인}이(가) 등잔을 하나 더 켜 둡니다. 어둠이 싫은 것 같습니다.'),
  ('any', 'w:bloodmist', 'all', '{정인}이(가) 마당의 화분을 하나씩 안으로 들여놓습니다.'),
  ('any', 'w:bloodmist', 'all', '{정인}이(가) 문단속을 마치고 빗장을 한 번 더 확인합니다.'),
  ('any', 'w:bloodmist', 't1', '{정인}이(가) 붉은 안개를 불안하게 내다보다가 곁으로 다가섭니다.'),
  ('any', 'w:bloodmist', 't2', '{정인}이(가) 창호지를 한 겹 더 덧대고 문단속을 합니다.'),
  ('any', 'w:bloodmist', 't3', '{정인}이(가) {이름}의 손을 꼭 잡고 놓지 않습니다.'),
  ('any', 'w:bloodmist', 't4', '{정인}이(가) 익숙한 손놀림으로 정화 부적을 문설주에 붙입니다.'),
  ('any', 'st:erosion', 'all', '{정인}이(가) {이름}의 이마에 손을 얹어 열이 있는지 살핍니다.'),
  ('any', 'st:erosion', 'all', '{정인}이(가) 마음 다잡기 하러 가자는 듯 {이름}의 손을 끕니다.'),
  ('any', 'st:erosion', 'all', '{정인}이(가) 따뜻한 국을 한 그릇 떠서 말없이 내밉니다.'),
  ('any', 'st:erosion', 'all', '{정인}이(가) 이부자리를 펴 두고 좀 누우라는 듯 손짓합니다.'),
  ('any', 'st:erosion', 't1', '{정인}이(가) {이름}의 눈가에 번진 검은 기운을 보고 놀란 얼굴이 됩니다.'),
  ('any', 'st:erosion', 't2', '{정인}이(가) 정화 부적을 {이름}의 손에 꼭 쥐여 줍니다.'),
  ('any', 'st:erosion', 't3', '{정인}이(가) 서늘해진 손끝을 두 손으로 감싸 쥡니다. 걱정이 가득한 눈빛입니다.'),
  ('any', 'st:erosion', 't4', '{정인}이(가) 뭔가 말하려다 꾹 참는 얼굴로 {이름}을(를) 바라봅니다.'),
  ('any', 'st:hp', 'all', '{정인}이(가) {이름}의 팔을 조심스럽게 붙잡고 다친 곳을 살핍니다.'),
  ('any', 'st:hp', 'all', '{정인}이(가) 상처를 보고 미간을 찌푸리며 약상자를 꺼내 옵니다.'),
  ('any', 'st:hp', 'all', '{정인}이(가) 미지근한 물수건을 짜서 {이름}의 이마에 얹어 줍니다.'),
  ('any', 'st:hp', 'all', '{정인}이(가) 죽을 쑤려는 듯 쌀자루를 꺼내 옵니다.'),
  ('any', 'st:hp', 't1', '{정인}이(가) 상처를 보고 얼굴이 하얘집니다. 서둘러 약을 찾는 것 같습니다.'),
  ('any', 'st:hp', 't2', '{정인}이(가) {이름}의 팔을 붙잡아 자리에 앉힙니다.'),
  ('any', 'st:hp', 't3', '{정인}이(가) 붕대를 감다가 손을 멈추고 한동안 말이 없습니다.'),
  ('any', 'st:hp', 't4', '{정인}이(가) 익숙한 손놀림으로 상처에 약을 발라 줍니다.'),
  ('any', 'st:yohwa', 'all', '{정인}이(가) 요문이 떠오른 손을 피하지 않고 꼭 잡아 줍니다.'),
  ('any', 'st:yohwa', 'all', '{정인}이(가) {이름}의 곁을 한 발짝도 떠나지 않으려는 듯 바짝 붙어 섭니다.'),
  ('any', 'st:yohwa', 'all', '{정인}이(가) 평소처럼 밥상을 차려 {이름}의 자리에 수저를 놓습니다.'),
  ('any', 'st:yohwa', 'all', '{정인}이(가) 아무렇지 않은 척 {이름}의 옷을 개어 머리맡에 둡니다.'),
  ('any', 'st:yohwa', 't1', '{정인}이(가) {이름}의 살갗에 떠오른 요문을 보고 숨을 삼킵니다.'),
  ('any', 'st:yohwa', 't2', '{정인}이(가) 요문 위에 가만히 손을 얹습니다. 혼자 두지 않겠다는 뜻인 것 같습니다.'),
  ('any', 'st:yohwa', 't3', '{정인}이(가) {이름}의 눈을 똑바로 바라보며 이름을 또박또박 불러 줍니다.'),
  ('any', 'st:yohwa', 't4', '{정인}이(가) 아무렇지 않은 얼굴로 늘 앉던 자리를 {이름}에게 내어 줍니다.'),
  ('any', 'st:exp', 'all', '{정인}이(가) 원정에서 돌아온 {이름}을(를) 위아래로 훑어보며 다친 데를 찾습니다.'),
  ('any', 'st:exp', 'all', '{정인}이(가) 무거운 짐을 받아 들고 마루에 내려놓습니다.'),
  ('any', 'st:exp', 'all', '{정인}이(가) 물을 데워 두었는지 김이 오르는 대야를 가리킵니다.'),
  ('any', 'st:exp', 'all', '{정인}이(가) 흙 묻은 신발을 받아 들고 털어 줍니다.'),
  ('any', 'st:exp', 't1', '{정인}이(가) 먼지 묻은 옷을 털어 주며 다친 데가 없는지 살핍니다.'),
  ('any', 'st:exp', 't2', '{정인}이(가) 반가운 얼굴로 다가오다가 짐 보따리부터 흘끔 봅니다.'),
  ('any', 'st:exp', 't3', '{정인}이(가) 달려와 와락 끌어안습니다. 기다림이 길었던 것 같습니다.'),
  ('any', 'st:exp', 't4', '{정인}이(가) 문간에 기대 서서 고개를 끄덕여 맞아 줍니다. 언제 올지 알고 있었던 듯합니다.');
