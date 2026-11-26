create or replace function public.world_lantern_ports()
 returns jsonb language plpgsql stable security definer set search_path to '' as $f$
begin
  return coalesce((select jsonb_agg(jsonb_build_object('r', p.key, 'name', coalesce(p.value ->> 'name', m.region_name, p.key)) order by p.key)
    from jsonb_each(coalesce(public.world_trade_rules() -> 'ports', '{}'::jsonb)) p left join public.world_map_regions m on m.region_id = p.key), '[]'::jsonb);
end $f$;

create or replace function public.world_lantern_day0()
 returns timestamptz language sql stable set search_path to '' as $f$
  select (pg_catalog.date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul')
$f$;

create or replace function public.world_lantern_port_of(p_uid uuid)
 returns jsonb language plpgsql stable security definer set search_path to '' as $f$
declare rg text := public.world_trade_here(p_uid);
begin
  if rg is null then return null; end if;
  return (select x from jsonb_array_elements(public.world_lantern_ports()) x where x ->> 'r' = rg limit 1);
end $f$;

create or replace function public.world_lantern_port_name(p_region text)
 returns text language sql stable security definer set search_path to '' as $f$
  select coalesce((select x ->> 'name' from jsonb_array_elements(public.world_lantern_ports()) x where x ->> 'r' = p_region limit 1),
    (select m.region_name from public.world_map_regions m where m.region_id = p_region), p_region)
$f$;

create or replace function public.world_lantern_clean(p_body text)
 returns text language sql immutable set search_path to '' as $f$
  select pg_catalog.btrim(pg_catalog.regexp_replace(pg_catalog.regexp_replace(pg_catalog.regexp_replace(coalesce(p_body, ''),
    '[\x01-\x09\x0b-\x1f\x7f]+', ' ', 'g'), '\n{2,}', E'\n', 'g'), ' {2,}', ' ', 'g'), E' \n')
$f$;

create or replace function public.world_lantern_snip(p_body text)
 returns text language sql immutable set search_path to '' as $f$
  select pg_catalog.left(pg_catalog.replace(coalesce(p_body, ''), E'\n', ' '), 16) || case when char_length(coalesce(p_body, '')) > 16 then '…' else '' end
$f$;

create or replace function public.world_lantern_look_ok(p_shape text, p_color text)
 returns boolean language sql immutable set search_path to '' as $f$
  select exists (select 1 from jsonb_array_elements(public.world_lantern_rules() -> 'shapes') s where s ->> 'key' = p_shape)
     and exists (select 1 from jsonb_array_elements(public.world_lantern_rules() -> 'colors') c where c ->> 'key' = p_color)
$f$;

create or replace function public.world_lantern_book_of(p_uid uuid)
 returns text[] language sql stable security definer set search_path to '' as $f$
  select coalesce((select b.open from public.world_lantern_book b where b.owner_id = p_uid),
    array[(public.world_lantern_rules() -> 'start' ->> 'shape') || ':' || (public.world_lantern_rules() -> 'start' ->> 'color')])
$f$;

create or replace function public.world_lantern_book_lock(p_uid uuid)
 returns text[] language plpgsql security definer set search_path to '' as $f$
declare o text[];
begin
  insert into public.world_lantern_book(owner_id, open) values (p_uid, public.world_lantern_book_of(p_uid)) on conflict (owner_id) do nothing;
  select b.open into o from public.world_lantern_book b where b.owner_id = p_uid for update;
  return o;
end $f$;

create or replace function public.world_lantern_rule_count(p_owner uuid, p_rule jsonb)
 returns numeric language sql stable security definer set search_path to '' as $f$
  select case p_rule ->> 'lantern'
    when 'caught' then (select count(*) from public.world_lanterns l where l.catcher_id = p_owner and l.reply_to is null)
    when 'book' then coalesce(pg_catalog.cardinality(public.world_lantern_book_of(p_owner)), 0)
    else 0 end::numeric
$f$;

create or replace function public.world_lantern_blocked(p_a uuid, p_b uuid)
 returns boolean language sql stable security definer set search_path to '' as $f$
  select exists (select 1 from public.world_blocks b where (b.owner_id = p_a and b.blocked_id = p_b) or (b.owner_id = p_b and b.blocked_id = p_a))
$f$;

create or replace function public.world_lantern_here_check(p_uid uuid, p_what text)
 returns jsonb language plpgsql security definer set search_path to '' as $f$
declare p jsonb;
begin
  if p_uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  perform public.world_travel_guard(p_what);
  perform public.world_rate_check('lantern', p_uid);
  if exists (select 1 from public.world_characters c where c.owner_id = p_uid and (c.downed_at is not null or c.is_dead)) then
    raise exception '쓰러진 채로는 등불을 다룰 수 없습니다.' using hint = 'down';
  end if;
  p := public.world_lantern_port_of(p_uid);
  if p is null then raise exception '등불은 항구 물가에서 띄우고 건질 수 있습니다.' using hint = 'not_port'; end if;
  return p;
end $f$;

create or replace function public.world_lantern_day(p_uid uuid)
 returns jsonb language sql stable security definer set search_path to '' as $f$
  select jsonb_build_object(
    'sent', (select count(*) from public.world_lanterns l where l.author_id = p_uid and l.created_at >= public.world_lantern_day0()),
    'send_cap', (public.world_lantern_rules() -> 'day' ->> 'send')::int,
    'caught', (select count(*) from public.world_lanterns l where l.catcher_id = p_uid and l.reply_to is null and l.caught_at >= public.world_lantern_day0()),
    'catch_cap', (public.world_lantern_rules() -> 'day' ->> 'catch')::int)
$f$;

create or replace function public.world_lantern_pool(p_uid uuid, p_port text)
 returns setof bigint language sql stable security definer set search_path to '' as $f$
  select l.id from public.world_lanterns l
   where l.reply_to is null and l.caught_at is null and l.removed_at is null
     and l.created_at > now() - make_interval(days => (public.world_lantern_rules() ->> 'days')::int)
     and l.port <> p_port and l.author_id is not null and l.author_id <> p_uid
     and not exists (select 1 from public.world_blocks b where (b.owner_id = p_uid and b.blocked_id = l.author_id) or (b.owner_id = l.author_id and b.blocked_id = p_uid))
     and not exists (select 1 from public.world_lantern_hides h join public.world_lanterns x on x.id = h.lantern_id where h.viewer_id = p_uid and x.author_id = l.author_id)
$f$;

create or replace function public.world_lantern_card(p_id bigint)
 returns jsonb language sql stable security definer set search_path to '' as $f$
  select jsonb_build_object('id', l.id, 'body', case when l.removed_at is null then l.body end, 'removed', l.removed_at is not null,
    'shape', l.shape, 'color', l.color, 'from', public.world_lantern_port_name(l.port), 'at', l.created_at)
    from public.world_lanterns l where l.id = p_id
$f$;

create or replace function public.world_lantern_view()
 returns jsonb language plpgsql stable security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); p jsonb; ru jsonb := public.world_lantern_rules(); bk text[]; n int; dd int := (ru ->> 'days')::int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  p := public.world_lantern_port_of(uid);
  bk := public.world_lantern_book_of(uid);
  n := public.world_lantern_rule_count(uid, '{"lantern": "caught"}'::jsonb)::int;
  return jsonb_build_object(
    'here', p,
    'day', public.world_lantern_day(uid),
    'pool', case when p is not null then (select count(*) from public.world_lantern_pool(uid, p ->> 'r')) end,
    'book', jsonb_build_object('open', to_jsonb(bk), 'n', coalesce(cardinality(bk), 0),
      'total', jsonb_array_length(ru -> 'shapes') * jsonb_array_length(ru -> 'colors')),
    'caught_n', n,
    'hanger', jsonb_build_object('n', (ru -> 'hanger' ->> 'n')::int,
      'got', exists (select 1 from public.world_housing_rewards w where w.owner_id = uid and w.source = 'lantern')),
    'sent', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'body', case when l.removed_at is null then l.body end, 'removed', l.removed_at is not null,
        'shape', l.shape, 'color', l.color, 'from', public.world_lantern_port_name(l.port), 'at', l.created_at,
        'status', case when l.removed_at is not null then 'removed' when l.caught_at is not null then 'caught'
                       when l.created_at <= now() - make_interval(days => dd) then 'out' else 'float' end,
        'out_at', l.created_at + make_interval(days => dd),
        'reply', (select r.id from public.world_lanterns r where r.reply_to = l.id
                   and not exists (select 1 from public.world_lantern_hides h where h.viewer_id = uid and h.lantern_id = r.id)))
        order by l.created_at desc)
      from (select * from public.world_lanterns x where x.author_id = uid and x.reply_to is null order by x.created_at desc limit (ru -> 'list' ->> 'sent')::int) l), '[]'::jsonb),
    'caught', coalesce((select jsonb_agg(public.world_lantern_card(l.id) || jsonb_build_object('caught_at', l.caught_at, 'where', public.world_lantern_port_name(l.caught_port),
        'my_reply', (select public.world_lantern_card(r.id) from public.world_lanterns r where r.reply_to = l.id),
        'can_reply', l.removed_at is null and l.author_id is not null and not public.world_lantern_blocked(uid, l.author_id)
          and not exists (select 1 from public.world_lanterns r where r.reply_to = l.id))
        order by l.caught_at desc)
      from (select * from public.world_lanterns x where x.catcher_id = uid and x.reply_to is null
              and not exists (select 1 from public.world_lantern_hides h where h.viewer_id = uid and h.lantern_id = x.id)
             order by x.caught_at desc limit (ru -> 'list' ->> 'caught')::int) l), '[]'::jsonb),
    'replies', coalesce((select jsonb_agg(public.world_lantern_card(l.id) || jsonb_build_object('to', (select public.world_lantern_snip(o.body) from public.world_lanterns o where o.id = l.reply_to),
        'to_id', l.reply_to) order by l.created_at desc)
      from (select * from public.world_lanterns x where x.to_id = uid
              and not exists (select 1 from public.world_lantern_hides h where h.viewer_id = uid and h.lantern_id = x.id)
             order by x.created_at desc limit (ru -> 'list' ->> 'replies')::int) l), '[]'::jsonb));
end $f$;

create or replace function public.world_lantern_send(p_body text, p_shape text, p_color text)
 returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); p jsonb; ru jsonb := public.world_lantern_rules(); b text := public.world_lantern_clean(p_body); bk text[]; d jsonb; nid bigint;
begin
  p := public.world_lantern_here_check(uid, '등불 띄우기');
  if b = '' then raise exception '등불에 적을 글을 써 주세요.' using hint = 'body'; end if;
  if char_length(b) > (ru ->> 'body_max')::int then raise exception '등불에는 %자까지 적을 수 있습니다.', ru ->> 'body_max' using hint = 'body'; end if;
  if not public.world_lantern_look_ok(p_shape, p_color) then raise exception '고를 수 없는 등 모양입니다.' using hint = 'look'; end if;
  bk := public.world_lantern_book_lock(uid);
  if not (p_shape || ':' || p_color) = any(bk) then raise exception '아직 등불첩에 열리지 않은 등입니다. 남의 등불을 건지면 그 등이 열립니다.' using hint = 'look'; end if;
  d := public.world_lantern_day(uid);
  if (d ->> 'sent')::int >= (d ->> 'send_cap')::int then
    raise exception '오늘은 등불을 %번 모두 띄웠습니다. 내일 다시 띄울 수 있습니다.', d ->> 'send_cap' using hint = 'day_send';
  end if;
  insert into public.world_lanterns(author_id, port, shape, color, body) values (uid, p ->> 'r', p_shape, p_color, b) returning id into nid;
  update public.world_lantern_book set last_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'id', nid, 'day', public.world_lantern_day(uid),
    'content', '등불이 물살을 타고 떠났습니다. 다른 항구에서 누군가 건져 읽을 것입니다.');
end $f$;

create or replace function public.world_lantern_catch()
 returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); p jsonb; ru jsonb := public.world_lantern_rules(); bk text[]; d jsonb; lid bigint; l public.world_lanterns%rowtype;
  k text; opened boolean := false; n int;
begin
  p := public.world_lantern_here_check(uid, '등불 건지기');
  bk := public.world_lantern_book_lock(uid);
  d := public.world_lantern_day(uid);
  if (d ->> 'caught')::int >= (d ->> 'catch_cap')::int then
    raise exception '오늘은 등불을 %번 건졌습니다. 내일 다시 건질 수 있습니다.', d ->> 'catch_cap' using hint = 'day_catch';
  end if;
  select x.id into lid from public.world_lanterns x where x.id in (select public.world_lantern_pool(uid, p ->> 'r'))
   order by random() limit 1 for update skip locked;
  if lid is null then raise exception '지금 이 물가에는 건질 등불이 없습니다. 다른 항구에 흘러온 등불을 찾아보세요.' using hint = 'none_here'; end if;
  update public.world_lanterns set catcher_id = uid, caught_at = now(), caught_port = p ->> 'r' where id = lid and caught_at is null returning * into l;
  if not found then raise exception '등불이 물살에 밀려 멀어졌습니다. 다시 건져 보세요.' using hint = 'none_here'; end if;
  k := l.shape || ':' || l.color;
  if not k = any(bk) then bk := bk || k; opened := true; end if;
  update public.world_lantern_book set open = bk, last_at = now() where owner_id = uid;
  n := public.world_lantern_rule_count(uid, '{"lantern": "caught"}'::jsonb)::int;
  if n >= (ru -> 'hanger' ->> 'n')::int then perform public.world_housing_grant_once(uid, 'lantern', '등불 편지'); end if;
  perform public.world_title_award_check(uid, 'lantern');
  return jsonb_build_object('ok', true, 'lantern', public.world_lantern_card(l.id), 'opened', opened, 'look', k,
    'book_n', cardinality(bk), 'caught_n', n, 'day', public.world_lantern_day(uid),
    'content', case when opened then '흘러온 등불을 건졌습니다. 등불첩에 새 등이 열렸습니다.' else '흘러온 등불을 건졌습니다.' end);
end $f$;

create or replace function public.world_lantern_reply(p_id bigint, p_body text, p_shape text, p_color text)
 returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); p jsonb; ru jsonb := public.world_lantern_rules(); b text := public.world_lantern_clean(p_body); bk text[]; d jsonb;
  o public.world_lanterns%rowtype; nid bigint;
begin
  p := public.world_lantern_here_check(uid, '답등 띄우기');
  select * into o from public.world_lanterns x where x.id = p_id and x.catcher_id = uid and x.reply_to is null for update;
  if not found then raise exception '내가 건진 등불에만 답등을 띄울 수 있습니다.' using hint = 'not_yours'; end if;
  if o.removed_at is not null or o.author_id is null or public.world_lantern_blocked(uid, o.author_id) then
    raise exception '이 등불을 띄운 이에게는 이제 답등이 닿지 않습니다.' using hint = 'gone';
  end if;
  if exists (select 1 from public.world_lanterns r where r.reply_to = o.id) then raise exception '이 등불에는 이미 답등을 띄웠습니다.' using hint = 'replied'; end if;
  if b = '' then raise exception '답등에 적을 글을 써 주세요.' using hint = 'body'; end if;
  if char_length(b) > (ru ->> 'body_max')::int then raise exception '등불에는 %자까지 적을 수 있습니다.', ru ->> 'body_max' using hint = 'body'; end if;
  if not public.world_lantern_look_ok(p_shape, p_color) then raise exception '고를 수 없는 등 모양입니다.' using hint = 'look'; end if;
  bk := public.world_lantern_book_lock(uid);
  if not (p_shape || ':' || p_color) = any(bk) then raise exception '아직 등불첩에 열리지 않은 등입니다. 남의 등불을 건지면 그 등이 열립니다.' using hint = 'look'; end if;
  if coalesce((ru -> 'reply' ->> 'counts_send')::boolean, true) then
    d := public.world_lantern_day(uid);
    if (d ->> 'sent')::int >= (d ->> 'send_cap')::int then
      raise exception '오늘은 등불을 %번 모두 띄웠습니다. 내일 다시 띄울 수 있습니다.', d ->> 'send_cap' using hint = 'day_send';
    end if;
  end if;
  insert into public.world_lanterns(author_id, port, shape, color, body, reply_to, to_id) values (uid, p ->> 'r', p_shape, p_color, b, o.id, o.author_id) returning id into nid;
  update public.world_lantern_book set last_at = now() where owner_id = uid;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (o.author_id, 'lantern_reply', '답등이 닿았습니다',
    '띄워 보낸 등불 「' || public.world_lantern_snip(o.body) || '」에 누군가 답등을 띄웠습니다. 항구 물가의 등불 편지에서 읽을 수 있습니다.',
    jsonb_build_object('lantern', o.id, 'reply', nid));
  return jsonb_build_object('ok', true, 'id', nid, 'day', public.world_lantern_day(uid), 'content', '답등이 물살을 타고 그 등불을 띄운 이에게 흘러갔습니다.');
end $f$;

create or replace function public.world_lantern_seen(p_uid uuid, p_id bigint)
 returns boolean language sql stable security definer set search_path to '' as $f$
  select exists (select 1 from public.world_lanterns l where l.id = p_id and ((l.catcher_id = p_uid and l.reply_to is null) or l.to_id = p_uid))
$f$;

create or replace function public.world_lantern_hide(p_id bigint)
 returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not public.world_lantern_seen(uid, p_id) then raise exception '등불을 찾을 수 없습니다.'; end if;
  insert into public.world_lantern_hides(viewer_id, lantern_id) values (uid, p_id) on conflict do nothing;
  return jsonb_build_object('ok', true, 'content', '이 등불을 내 화면에서 숨겼습니다. 같은 이가 띄운 등불은 앞으로 건지지 않습니다.');
end $f$;

create or replace function public.world_lantern_report(p_id bigint, p_reason text)
 returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); l public.world_lanterns%rowtype; nm text; rid bigint;
  why text := btrim(regexp_replace(coalesce(p_reason, ''), '[\x01-\x09\x0b-\x1f\x7f]+', ' ', 'g'));
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not public.world_lantern_seen(uid, p_id) then raise exception '등불을 찾을 수 없습니다.'; end if;
  select * into l from public.world_lanterns where id = p_id;
  if l.removed_at is not null then raise exception '이미 운영진이 내린 등불입니다.'; end if;
  if char_length(why) > 200 then raise exception '까닭은 200자까지 적을 수 있습니다.'; end if;
  if exists (select 1 from public.world_bug_reports where owner_id = uid and category = 'lantern' and context ->> 'lantern' = p_id::text) then
    raise exception '이미 제보한 등불입니다. 운영진이 살펴보고 있습니다.'; end if;
  if (select count(*) from public.world_bug_reports where owner_id = uid and created_at > now() - interval '1 hour') >= 5 then
    raise exception '제보는 1시간에 5건까지 보낼 수 있습니다. 잠시 뒤에 보내 주세요.'; end if;
  select character_name into nm from public.world_characters where owner_id = uid;
  insert into public.world_bug_reports (owner_id, character_name, category, title, body, context)
  values (uid, nm, 'lantern', case when l.reply_to is null then '등불 제보 · 「' else '답등 제보 · 「' end || public.world_lantern_snip(l.body) || '」',
    case when why = '' then '(까닭을 적지 않음)' else why end,
    jsonb_build_object('lantern', p_id, 'author_id', l.author_id, 'reply', l.reply_to is not null))
  returning report_id into rid;
  insert into public.world_notifications (user_id, kind, title, content, payload)
  select s.owner_id, 'bug_report', '새 제보', coalesce(nm, '조사원') || ': 등불 제보', jsonb_build_object('report_id', rid) from public.world_staff s where s.owner_id <> uid;
  insert into public.world_lantern_hides(viewer_id, lantern_id) values (uid, p_id) on conflict do nothing;
  return jsonb_build_object('ok', true, 'content', '운영진에게 알렸습니다. 이 등불은 내 화면에서 숨깁니다.');
end $f$;

create or replace function public.world_lantern_remove(p_id bigint, p_reason text)
 returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); l public.world_lanterns%rowtype; why text := btrim(coalesce(p_reason, ''));
begin
  if uid is null or not exists (select 1 from public.world_staff where owner_id = uid) then raise exception '운영진만 할 수 있습니다.'; end if;
  update public.world_lanterns set removed_at = now(), removed_by = uid where id = p_id and removed_at is null returning * into l;
  if not found then
    if not exists (select 1 from public.world_lanterns where id = p_id) then raise exception '등불을 찾을 수 없습니다.'; end if;
    return jsonb_build_object('ok', true, 'removed', 0, 'content', '이미 내린 등불입니다.');
  end if;
  if l.author_id is not null then
    insert into public.world_notifications (user_id, kind, title, content, payload)
    values (l.author_id, 'lantern_removed', '등불이 내려졌습니다',
      '운영진이 띄워 보낸 등불 「' || public.world_lantern_snip(l.body) || '」을(를) 내렸습니다.'
        || case when why <> '' then ' 까닭: ' || left(why, 200) else '' end, jsonb_build_object('lantern', p_id));
  end if;
  return jsonb_build_object('ok', true, 'removed', 1, 'content', '등불을 내렸습니다.');
end $f$;

create or replace function public.world_lantern_brief(p_id bigint)
 returns jsonb language sql stable security definer set search_path to '' as $f$
  select jsonb_build_object('id', l.id, 'body', l.body, 'shape', l.shape, 'color', l.color, 'port', public.world_lantern_port_name(l.port), 'at', l.created_at,
    'author_id', l.author_id, 'author', (select c.character_name from public.world_characters c where c.owner_id = l.author_id),
    'reply', l.reply_to is not null, 'caught', l.caught_at is not null, 'removed', l.removed_at is not null)
    from public.world_lanterns l where l.id = p_id
$f$;

select pg_temp.yh_fix('world_rate_check', array[
  $a$raise exception '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.' using hint = 'rate';$a$,
  $a$raise exception '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.' using hint = 'rate';
  elsif p_kind = 'lantern' and exists (select 1 from public.world_lantern_book where owner_id = p_uid and last_at > now() - (public.world_rate_rules()->>'lantern_ms')::int * interval '1 millisecond') then
    raise exception '물살이 잔잔해질 때까지 잠시 기다리세요.' using hint = 'rate';$a$]);

select pg_temp.yh_fix('world_notify_group', array[$a$when p_kind in ('letter') then 'letter'$a$, $a$when p_kind in ('letter', 'lantern_reply') then 'letter'$a$]);

select pg_temp.yh_fix('world_bug_report_list', array[
  $a$'outfit', case when (select is_gm from gm) and r.category = 'outfit' then public.world_outfit_design_brief((r.context ->> 'outfit')::bigint) end,$a$,
  $a$'outfit', case when (select is_gm from gm) and r.category = 'outfit' then public.world_outfit_design_brief((r.context ->> 'outfit')::bigint) end, 'lantern', case when (select is_gm from gm) and r.category = 'lantern' then public.world_lantern_brief((r.context ->> 'lantern')::bigint) end,$a$]);

select pg_temp.yh_fix('world_title_rule_ok', array[$a$ELSIF p_rule ? 'regular' THEN$a$,
  $a$ELSIF p_rule ? 'lantern' THEN RETURN public.world_lantern_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'regular' THEN$a$]);
select pg_temp.yh_fix('world_title_rule_progress', array[$a$elsif p_rule ? 'regular' then v :=$a$,
  $a$elsif p_rule ? 'lantern' then v := public.world_lantern_rule_count(p_owner, p_rule); elsif p_rule ? 'regular' then v :=$a$]);
select pg_temp.yh_fix('world_title_award_check', array[$a$IF r ? 'regular' AND p_event_type IS NOT NULL$a$,
  $a$IF r ? 'lantern' AND p_event_type IS NOT NULL AND p_event_type <> 'lantern' THEN CONTINUE; END IF;
    IF p_event_type = 'lantern' AND NOT (r ? 'lantern') THEN CONTINUE; END IF;
    IF r ? 'regular' AND p_event_type IS NOT NULL$a$]);

select pg_temp.yh_fix('world_character_purge', array[$a$delete from public.world_quest_progress where owner_id = p_uid;$a$,
  $a$delete from public.world_quest_progress where owner_id = p_uid;
  delete from public.world_lantern_hides where viewer_id = p_uid;
  delete from public.world_lantern_book where owner_id = p_uid;
  delete from public.world_lanterns where to_id = p_uid;
  delete from public.world_lanterns where author_id = p_uid and reply_to is null and caught_at is null;
  update public.world_lanterns set author_id = null where author_id = p_uid;
  update public.world_lanterns set catcher_id = null where catcher_id = p_uid;$a$]);

grant create on schema public to fn_owner_field;
do $$ declare f text; begin
  foreach f in array array[
    'world_lantern_ports()', 'world_lantern_port_of(uuid)', 'world_lantern_port_name(text)', 'world_lantern_book_of(uuid)', 'world_lantern_book_lock(uuid)', 'world_lantern_rule_count(uuid, jsonb)',
    'world_lantern_blocked(uuid, uuid)', 'world_lantern_here_check(uuid, text)', 'world_lantern_day(uuid)', 'world_lantern_pool(uuid, text)', 'world_lantern_card(bigint)',
    'world_lantern_view()', 'world_lantern_send(text, text, text)', 'world_lantern_catch()', 'world_lantern_reply(bigint, text, text, text)', 'world_lantern_seen(uuid, bigint)',
    'world_lantern_hide(bigint)', 'world_lantern_report(bigint, text)', 'world_lantern_remove(bigint, text)', 'world_lantern_brief(bigint)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
  end loop;
end $$;
revoke create on schema public from fn_owner_field;

select pg_temp.yh_lt_share('public.world_lantern_ports()');
select pg_temp.yh_lt_share('public.world_lantern_day0()');
select pg_temp.yh_lt_share('public.world_lantern_clean(text)');
select pg_temp.yh_lt_share('public.world_lantern_snip(text)');
select pg_temp.yh_lt_share('public.world_lantern_look_ok(text, text)');
select pg_temp.yh_lt_share('public.world_lantern_port_of(uuid)');
select pg_temp.yh_lt_share('public.world_lantern_port_name(text)');
select pg_temp.yh_lt_share('public.world_lantern_book_of(uuid)');
select pg_temp.yh_lt_share('public.world_lantern_book_lock(uuid)');
select pg_temp.yh_lt_share('public.world_lantern_rule_count(uuid, jsonb)');
select pg_temp.yh_lt_share('public.world_lantern_blocked(uuid, uuid)');
select pg_temp.yh_lt_share('public.world_lantern_here_check(uuid, text)');
select pg_temp.yh_lt_share('public.world_lantern_day(uuid)');
select pg_temp.yh_lt_share('public.world_lantern_pool(uuid, text)');
select pg_temp.yh_lt_share('public.world_lantern_card(bigint)');
select pg_temp.yh_lt_share('public.world_lantern_seen(uuid, bigint)');
select pg_temp.yh_lt_share('public.world_lantern_brief(bigint)');
do $$ declare f text; begin
  foreach f in array array['world_lantern_view()', 'world_lantern_send(text, text, text)', 'world_lantern_catch()', 'world_lantern_reply(bigint, text, text, text)',
    'world_lantern_hide(bigint)', 'world_lantern_report(bigint, text)', 'world_lantern_remove(bigint, text)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $$;
