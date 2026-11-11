create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

create or replace function public.world_wedding_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object(
    'delays', jsonb_build_array(10, 60, 720, 1440),
    'run_min', 10,
    'remind_min', 10,
    'gap_s', 15,
    'wish_max', 40,
    'guest', jsonb_build_object('clap', 5, 'petal', 5, 'cup', 5),
    'couple', jsonb_build_object('bow', 5, 'cake', 5))
$function$;
grant execute on function public.world_wedding_rules() to public;

alter table public.world_weddings add column if not exists delay_min integer not null default 5;
alter table public.world_weddings add column if not exists reminded boolean not null default false;
alter table public.world_wedding_guests add column if not exists cups integer not null default 0;
alter table public.world_wedding_guests add column if not exists bows integer not null default 0;
alter table public.world_wedding_guests add column if not exists cakes integer not null default 0;

create or replace function public.world_wedding_when(p_at timestamptz, p_delay integer)
 returns text
 language sql
 stable
 set search_path to ''
as $function$
  select case when p_delay < 60 then p_delay::text || '분 뒤'
    else extract(month from p_at at time zone 'Asia/Seoul')::int::text || '월 ' || extract(day from p_at at time zone 'Asia/Seoul')::int::text || '일 '
      || to_char(p_at at time zone 'Asia/Seoul', 'HH24:MI') end
$function$;
revoke all on function public.world_wedding_when(timestamptz, integer) from public, anon, authenticated;
grant execute on function public.world_wedding_when(timestamptz, integer) to fn_owner_field, service_role;

create or replace function public.world_wedding_invitees(p_a uuid, p_b uuid)
 returns setof uuid
 language sql
 stable
 set search_path to ''
as $function$
  select distinct x from (
    select f.friend_id x from public.world_friends f where f.owner_id in (p_a, p_b) and f.status = 'accepted'
    union select cm2.owner_id from public.world_circle_members cm join public.world_circle_members cm2 on cm2.circle_id = cm.circle_id where cm.owner_id in (p_a, p_b)) s
  where x not in (p_a, p_b)
$function$;
revoke all on function public.world_wedding_invitees(uuid, uuid) from public, anon, authenticated;
grant execute on function public.world_wedding_invitees(uuid, uuid) to fn_owner_field, service_role;

drop function if exists public.world_wedding_ask();
create or replace function public.world_wedding_ask(p_delay integer default 10)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); b public.world_bonds%rowtype; me public.world_characters%rowtype; pt public.world_characters%rowtype; pid uuid; r public.world_map_regions%rowtype; wid uuid;
  ru jsonb := public.world_wedding_rules(); dl integer := coalesce(p_delay, 10);
begin perform public.world_travel_guard('혼례 청하기');
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not (ru -> 'delays') @> to_jsonb(dl) then raise exception '혼례를 시작할 때를 다시 골라 주세요.'; end if;
  select * into b from public.world_bonds where ended_at is null and (a_id = uid or b_id = uid) for update;
  if not found then raise exception '정인이 있어야 혼례를 올릴 수 있습니다.'; end if;
  if coalesce((b.marks ->> 'married')::boolean, false) then raise exception '이미 혼례를 올렸습니다.'; end if;
  if b.affinity < 300 then raise exception '인연도가 300이 되어야 혼례를 올릴 수 있습니다(지금 %).', b.affinity; end if;
  pid := case when b.a_id = uid then b.b_id else b.a_id end;
  select * into me from public.world_characters where owner_id = uid;
  select * into pt from public.world_characters where owner_id = pid;
  if coalesce(me.level, 1) < 20 or coalesce(pt.level, 1) < 20 then raise exception '두 사람 모두 레벨 20이어야 합니다.'; end if;
  if not public.world_quest_chapter_done(uid, 'eclipse_gate') or not public.world_quest_chapter_done(pid, 'eclipse_gate') then raise exception '두 사람 모두 주 이야기 6장 「월식의 문」을 마쳐야 합니다.'; end if;
  if me.location is distinct from pt.location then raise exception '정인과 같은 곳에 있어야 합니다.'; end if;
  r := public.world_field_region(me.location);
  if not (r.region_id = any (public.world_wedding_places(uid, pid))) then raise exception '본부 정청이나 두 사람 가운데 한 사람의 세력 거점에서 혼례를 올릴 수 있습니다.'; end if;
  if coalesce(me.gil, 0) < 1500 then raise exception '혼례 비용 1,500전이 모자랍니다(둘이 1,500전씩).'; end if;
  if exists (select 1 from public.world_weddings where bond_id = b.bond_id and status in ('asked', 'ready', 'ceremony')) then raise exception '이미 청한 혼례가 있습니다.'; end if;
  insert into public.world_weddings(bond_id, a_id, b_id, a_name, b_name, region_id, asked_by, delay_min)
  values (b.bond_id, uid, pid, me.character_name, pt.character_name, r.region_id, uid, dl) returning wed_id into wid;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (pid, 'bond_wedding_ask', '혼례를 청합니다', me.character_name || '이(가) ' || r.region_name || '에서 혼례를 올리자고 합니다. 받으면 '
    || case when dl < 60 then dl::text || '분' else (dl / 60)::text || '시간' end || ' 뒤 시작합니다(1,500전씩).', jsonb_build_object('wed_id', wid));
  return jsonb_build_object('ok', true, 'wed_id', wid, 'content', '정인에게 혼례를 청했습니다.');
end $function$;
revoke all on function public.world_wedding_ask(integer) from public, anon;
grant execute on function public.world_wedding_ask(integer) to authenticated, service_role;
select pg_temp.yh_own('public.world_wedding_ask(integer)', 'fn_owner_field');

create or replace function public.world_wedding_respond(p_wed uuid, p_accept boolean)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); w public.world_weddings%rowtype; a public.world_characters%rowtype; bb public.world_characters%rowtype; place text; who uuid;
  ru jsonb := public.world_wedding_rules(); st timestamptz; at_txt text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into w from public.world_weddings where wed_id = p_wed for update;
  if not found or w.status <> 'asked' or w.b_id <> uid then raise exception '받을 수 있는 혼례 청이 아닙니다.'; end if;
  if not coalesce(p_accept, false) then
    update public.world_weddings set status = 'cancelled' where wed_id = p_wed;
    insert into public.world_notifications(user_id, kind, title, content, payload) values (w.a_id, 'bond_wedding', '혼례를 미루었습니다', w.b_name || '이(가) 혼례를 다음으로 미루었습니다.', jsonb_build_object('wed_id', p_wed));
    return jsonb_build_object('ok', true, 'content', '혼례를 미루었습니다.');
  end if;
  perform 1 from public.world_characters where owner_id in (w.a_id, w.b_id) order by owner_id for update;
  select * into a from public.world_characters where owner_id = w.a_id;
  select * into bb from public.world_characters where owner_id = w.b_id;
  select region_name into place from public.world_map_regions where region_id = w.region_id;
  if a.location is distinct from place or bb.location is distinct from place then raise exception '두 사람이 모두 %에 있어야 합니다.', place; end if;
  if coalesce(a.gil, 0) < 1500 or coalesce(bb.gil, 0) < 1500 then raise exception '두 사람 모두 1,500전이 있어야 합니다.'; end if;
  update public.world_characters set gil = gil - 1500, updated_at = now() where owner_id in (w.a_id, w.b_id);
  st := now() + make_interval(mins => w.delay_min);
  at_txt := public.world_wedding_when(st, w.delay_min);
  update public.world_weddings set status = 'ready', starts_at = st, ends_at = st + make_interval(mins => (ru ->> 'run_min')::int),
    reminded = w.delay_min < 60, script = public.world_wedding_script(w.a_name, w.b_name, place) where wed_id = p_wed;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select x, 'wedding_invite', '혼례에 초대합니다', w.a_name || '과(와) ' || w.b_name || '이(가) ' || at_txt || ' ' || place || '에서 혼례를 올립니다. 그 시각 그곳에 있으면 하객이 됩니다.', jsonb_build_object('wed_id', p_wed)
    from public.world_wedding_invitees(w.a_id, w.b_id) x;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (w.a_id, 'bond_wedding', '혼례가 정해졌습니다', at_txt || ' ' || place || '에서 혼례가 시작됩니다.', jsonb_build_object('wed_id', p_wed)),
         (w.b_id, 'bond_wedding', '혼례가 정해졌습니다', at_txt || ' ' || place || '에서 혼례가 시작됩니다.', jsonb_build_object('wed_id', p_wed));
  select owner_id into who from public.world_staff order by owner_id limit 1;
  if who is not null then
    insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
    values ('global', who, '연리 소식', w.a_name || '과(와) ' || w.b_name || '의 혼례가 ' || at_txt || ' ' || place || '에서 열립니다. 그곳에 계신 분은 누구나 하객이 됩니다.');
  end if;
  return jsonb_build_object('ok', true, 'wed_id', p_wed, 'content', '혼례가 ' || at_txt || ' 시작합니다.');
end $function$;

create or replace function public.world_wedding_tick()
 returns void
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare w record; place text; who uuid; mins int := (public.world_wedding_rules() ->> 'remind_min')::int;
begin
  for w in select wed_id from public.world_weddings where status in ('ready', 'ceremony') and ends_at <= now() loop perform public.world_wedding_finish(w.wed_id); end loop;
  update public.world_weddings set status = 'ceremony' where status = 'ready' and starts_at <= now();
  update public.world_weddings set status = 'cancelled' where status = 'asked' and created_at < now() - interval '1 hour';
  for w in update public.world_weddings set reminded = true
            where status = 'ready' and not reminded and starts_at <= now() + make_interval(mins => mins)
            returning wed_id, a_id, b_id, a_name, b_name, region_id loop
    select region_name into place from public.world_map_regions where region_id = w.region_id;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    select x, 'wedding_invite', '혼례가 곧 열립니다', w.a_name || '과(와) ' || w.b_name || '의 혼례가 ' || mins || '분 뒤 ' || place || '에서 열립니다. 그 시각 그곳에 있으면 하객이 됩니다.', jsonb_build_object('wed_id', w.wed_id)
      from public.world_wedding_invitees(w.a_id, w.b_id) x;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (w.a_id, 'bond_wedding', '혼례가 곧 열립니다', mins || '분 뒤 ' || place || '에서 혼례가 시작됩니다.', jsonb_build_object('wed_id', w.wed_id)),
           (w.b_id, 'bond_wedding', '혼례가 곧 열립니다', mins || '분 뒤 ' || place || '에서 혼례가 시작됩니다.', jsonb_build_object('wed_id', w.wed_id));
    select owner_id into who from public.world_staff order by owner_id limit 1;
    if who is not null then
      insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
      values ('global', who, '연리 소식', w.a_name || '과(와) ' || w.b_name || '의 혼례가 ' || mins || '분 뒤 ' || place || '에서 열립니다.');
    end if;
  end loop;
end $function$;

create or replace function public.world_wedding_cheer(p_wed uuid, p_kind text, p_text text default null::text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); w public.world_weddings%rowtype; c public.world_characters%rowtype; g public.world_wedding_guests%rowtype; place text; msg text; wish text;
  ru jsonb := public.world_wedding_rules(); couple boolean; cap int; used int;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into w from public.world_weddings where wed_id = p_wed;
  if not found or w.status not in ('ready', 'ceremony') or now() < w.starts_at or now() > w.ends_at then raise exception '혼례가 열리는 동안에만 축하할 수 있습니다.'; end if;
  couple := uid in (w.a_id, w.b_id);
  if couple and not (ru -> 'couple') ? p_kind then raise exception '혼례의 주인공은 절하기와 떡 돌리기를 할 수 있습니다.'; end if;
  if not couple and not ((ru -> 'guest') ? p_kind or p_kind = 'wish') then raise exception '알 수 없는 축하입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  select region_name into place from public.world_map_regions where region_id = w.region_id;
  if c.location is distinct from place then raise exception '%에 있어야 %.', place, case when couple then '혼례를 올릴 수 있습니다' else '하객이 됩니다' end; end if;
  insert into public.world_wedding_guests(wed_id, owner_id, name) values (p_wed, uid, c.character_name) on conflict do nothing;
  select * into g from public.world_wedding_guests where wed_id = p_wed and owner_id = uid for update;
  if g.last_at is not null and g.last_at > now() - make_interval(secs => (ru ->> 'gap_s')::int) then raise exception '조금 뒤에 다시 할 수 있습니다(단추 사이 %초).', ru ->> 'gap_s'; end if;
  if p_kind = 'wish' then
    if g.wished then raise exception '축사는 한 번만 할 수 있습니다.'; end if;
    wish := btrim(regexp_replace(coalesce(p_text, ''), '\s+', ' ', 'g'));
    if wish = '' then raise exception '축사를 적어 주세요.'; end if;
    if char_length(wish) > (ru ->> 'wish_max')::int then raise exception '축사는 %자까지 적을 수 있습니다.', ru ->> 'wish_max'; end if;
    update public.world_wedding_guests set wished = true, last_at = now() where wed_id = p_wed and owner_id = uid;
    msg := c.character_name || '의 축사: 「' || wish || '」';
  else
    cap := coalesce((ru -> case when couple then 'couple' else 'guest' end ->> p_kind)::int, 0);
    used := case p_kind when 'clap' then g.claps when 'petal' then g.petals when 'cup' then g.cups when 'bow' then g.bows else g.cakes end;
    if used >= cap then raise exception '이 축하는 %번까지 할 수 있습니다.', cap; end if;
    update public.world_wedding_guests set claps = claps + (p_kind = 'clap')::int, petals = petals + (p_kind = 'petal')::int, cups = cups + (p_kind = 'cup')::int,
      bows = bows + (p_kind = 'bow')::int, cakes = cakes + (p_kind = 'cake')::int, last_at = now() where wed_id = p_wed and owner_id = uid;
    msg := c.character_name || case p_kind
      when 'clap' then '이(가) 힘껏 박수를 친다.'
      when 'petal' then '이(가) 두 사람 앞에 꽃잎을 한 줌 뿌린다.'
      when 'cup' then '이(가) 두 사람을 향해 술잔을 높이 올린다.'
      when 'bow' then '이(가) 하객들에게 깊이 절을 올린다.'
      else '이(가) 하객들에게 혼례 떡을 한 접시씩 돌린다.' end;
  end if;
  insert into public.world_wedding_lines(wed_id, kind, text) values (p_wed, p_kind, msg);
  return public.world_wedding_view(p_wed);
end $function$;

create or replace function public.world_wedding_view(p_wed uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); w public.world_weddings%rowtype; c public.world_characters%rowtype; place text; el numeric; me public.world_wedding_guests%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_wedding_finish(p_wed);
  select * into w from public.world_weddings where wed_id = p_wed;
  if not found then raise exception '없는 혼례입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  select region_name into place from public.world_map_regions where region_id = w.region_id;
  select * into me from public.world_wedding_guests where wed_id = p_wed and owner_id = uid;
  el := extract(epoch from now() - w.starts_at);
  return jsonb_build_object('now', now(), 'wed_id', w.wed_id, 'status', w.status, 'a', w.a_name, 'b', w.b_name, 'place', place, 'starts_at', w.starts_at, 'ends_at', w.ends_at,
    'here', c.location = place, 'couple', uid in (w.a_id, w.b_id), 'rules', public.world_wedding_rules(),
    'me', jsonb_build_object('clap', coalesce(me.claps, 0), 'petal', coalesce(me.petals, 0), 'cup', coalesce(me.cups, 0), 'bow', coalesce(me.bows, 0), 'cake', coalesce(me.cakes, 0),
      'claps', coalesce(me.claps, 0), 'petals', coalesce(me.petals, 0), 'wished', coalesce(me.wished, false), 'last_at', me.last_at),
    'script', case when w.status in ('ceremony', 'done') or (w.status = 'ready' and el >= 0) then
        (select coalesce(jsonb_agg(jsonb_build_object('at', w.starts_at + make_interval(secs => (x ->> 's')::int), 'k', x ->> 'k', 't', x ->> 't')), '[]'::jsonb)
           from jsonb_array_elements(w.script) x where w.status = 'done' or (x ->> 's')::int <= el) else '[]'::jsonb end,
    'lines', (select coalesce(jsonb_agg(jsonb_build_object('at', l.at, 'k', l.kind, 't', l.text) order by l.at), '[]'::jsonb) from public.world_wedding_lines l where l.wed_id = p_wed),
    'guests', (select count(*) from public.world_wedding_guests where wed_id = p_wed and owner_id not in (w.a_id, w.b_id)));
end $function$;

update public.world_patch_notes set body = replace(body, E'- 휴대폰 싸움 화면(봉연·파티 토벌·귀허·먹그림자)에서 채팅 동그라미를 기록 손잡이 아래 손잡이로 옮겨, 협동 기술 칸을 가리지 않게 했습니다.\n', $N$- 휴대폰 싸움 화면(봉연·파티 토벌·귀허·먹그림자)에서 채팅 동그라미를 기록 손잡이 아래 손잡이로 옮겨, 협동 기술 칸을 가리지 않게 했습니다.
- 혼례: 청할 때 시작 시각을 10분·1시간·12시간·24시간 뒤 가운데 고릅니다. 1시간 이상 뒤로 정하면 시작 10분 전에 친구·모임원과 전체 채팅에 한 번 더 알립니다.
- 혼례 하객은 박수·꽃잎을 다섯 번씩, 새 「술잔 올리기」도 다섯 번 할 수 있고, 축사 칸이 넓어지고 글자 수가 보입니다. 단추 사이 남은 초도 보입니다.
- 혼례의 두 사람도 하객에게 절하기·떡 돌리기를 다섯 번씩 할 수 있습니다.
$N$) where note_id = '2.0.0' and position('혼례: 청할 때 시작 시각' in body) = 0;
