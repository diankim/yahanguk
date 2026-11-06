create table if not exists public.world_drawings (
  id bigint generated always as identity primary key,
  owner_id uuid not null,
  origin bigint,
  author_id uuid not null,
  author_name text not null,
  title text not null default '',
  size text not null check (size in ('S', 'L')),
  px text not null check (px ~ '^[0-9a-f.]+$'),
  giver_id uuid,
  gift_from text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  removed_at timestamptz,
  removed_by uuid
);
create index if not exists world_drawings_owner_idx on public.world_drawings (owner_id);
create index if not exists world_drawings_origin_idx on public.world_drawings (origin);
create index if not exists world_drawings_author_day_idx on public.world_drawings (author_id, created_at);
create index if not exists world_drawings_giver_day_idx on public.world_drawings (giver_id, created_at) where giver_id is not null;
alter table public.world_drawings enable row level security;
revoke all on table public.world_drawings from public, anon, authenticated;
grant select, insert, update, delete on table public.world_drawings to fn_owner_field;

create table if not exists public.world_drawing_hides (
  viewer_id uuid not null,
  origin bigint not null,
  created_at timestamptz not null default now(),
  primary key (viewer_id, origin)
);
alter table public.world_drawing_hides enable row level security;
revoke all on table public.world_drawing_hides from public, anon, authenticated;
grant select, insert, update, delete on table public.world_drawing_hides to fn_owner_field;

alter table public.world_bug_reports drop constraint if exists world_bug_reports_category_check;
alter table public.world_bug_reports add constraint world_bug_reports_category_check check (category = any (array['bug', 'screen', 'balance', 'idea', 'review', 'other', 'drawing']));

create or replace function public.world_drawing_rules()
returns jsonb language sql immutable set search_path to '' as $f$
  select jsonb_build_object('per_day', 5, 'keep', 40, 'give_day', 10, 'title_max', 12,
    'sizes', jsonb_build_object('S', jsonb_build_array(16, 16), 'L', jsonb_build_array(32, 24)))
$f$;
revoke all on function public.world_drawing_rules() from public, anon, authenticated;
grant execute on function public.world_drawing_rules() to fn_owner_field, service_role;

create or replace function public.world_drawing_day_start()
returns timestamptz language sql stable set search_path to '' as $f$
  select (date_trunc('day', now() at time zone 'Asia/Seoul')) at time zone 'Asia/Seoul'
$f$;
revoke all on function public.world_drawing_day_start() from public, anon, authenticated;
grant execute on function public.world_drawing_day_start() to fn_owner_field, service_role;

create or replace function public.world_drawing_json(d public.world_drawings, p_uid uuid)
returns jsonb language sql stable set search_path to '' as $f$
  select jsonb_build_object('id', d.id, 'o', coalesce(d.origin, d.id), 's', d.size, 'px', d.px, 't', d.title, 'a', d.author_name, 'ai', d.author_id,
    'gift', d.gift_from, 'mine', d.owner_id = p_uid, 'authored', d.author_id = p_uid and coalesce(d.origin, d.id) = d.id, 'at', d.created_at)
$f$;
revoke all on function public.world_drawing_json(public.world_drawings, uuid) from public, anon, authenticated;
grant execute on function public.world_drawing_json(public.world_drawings, uuid) to fn_owner_field, service_role;

create or replace function public.world_drawing_list()
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); ds timestamptz := public.world_drawing_day_start();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object('rules', public.world_drawing_rules(),
    'made_today', (select count(*) from public.world_drawings where author_id = uid and giver_id is null and created_at >= ds),
    'given_today', (select count(*) from public.world_drawings where giver_id = uid and created_at >= ds),
    'mine', coalesce((select jsonb_agg(public.world_drawing_json(d, uid) order by d.created_at desc) from public.world_drawings d where d.owner_id = uid and d.removed_at is null), '[]'::jsonb));
end $f$;
revoke all on function public.world_drawing_list() from public, anon, authenticated;
grant execute on function public.world_drawing_list() to authenticated, service_role;

create or replace function public.world_drawing_save(p_id bigint, p_size text, p_title text, p_px text)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_drawing_rules(); sz jsonb := r -> 'sizes' -> p_size; t text; nm text; d public.world_drawings%rowtype; nid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select character_name into nm from public.world_characters where owner_id = uid;
  if nm is null then raise exception '캐릭터가 없습니다.'; end if;
  if sz is null then raise exception '그림 크기가 올바르지 않습니다.'; end if;
  if p_px is null or char_length(p_px) <> (sz ->> 0)::int * (sz ->> 1)::int or p_px !~ '^[0-9a-f.]+$' then raise exception '그림 내용이 올바르지 않습니다.'; end if;
  if p_px !~ '[0-9a-f]' then raise exception '빈 그림은 걸 수 없습니다. 한 칸이라도 칠해 주세요.'; end if;
  t := btrim(regexp_replace(coalesce(p_title, ''), '[[:cntrl:]]+', ' ', 'g'));
  if char_length(t) > (r ->> 'title_max')::int then raise exception '그림 이름은 %자까지 쓸 수 있습니다.', r ->> 'title_max'; end if;
  if p_id is null then
    if (select count(*) from public.world_drawings where author_id = uid and giver_id is null and created_at >= public.world_drawing_day_start()) >= (r ->> 'per_day')::int then
      raise exception '새 그림은 하루에 %장까지 그릴 수 있습니다. 이미 그린 그림은 언제든 고칠 수 있습니다.', r ->> 'per_day'; end if;
    if (select count(*) from public.world_drawings where owner_id = uid and removed_at is null) >= (r ->> 'keep')::int then
      raise exception '그림첩이 가득 찼습니다(%장). 안 쓰는 그림을 지운 뒤 그려 주세요.', r ->> 'keep'; end if;
    insert into public.world_drawings (owner_id, author_id, author_name, title, size, px) values (uid, uid, nm, t, p_size, p_px) returning id into nid;
    update public.world_drawings set origin = nid where id = nid;
  else
    select * into d from public.world_drawings where id = p_id for update;
    if not found or d.owner_id <> uid or d.removed_at is not null then raise exception '그림을 찾을 수 없습니다.'; end if;
    if d.author_id <> uid or coalesce(d.origin, d.id) <> d.id then raise exception '선물로 받은 그림은 고칠 수 없습니다.'; end if;
    if d.size <> p_size then raise exception '그림 크기는 바꿀 수 없습니다.'; end if;
    update public.world_drawings set px = p_px, title = t, author_name = nm, updated_at = now() where id = p_id;
    nid := p_id;
  end if;
  return public.world_drawing_list() || jsonb_build_object('saved', nid, 'content', '그림첩에 담았습니다.');
end $f$;
revoke all on function public.world_drawing_save(bigint, text, text, text) from public, anon, authenticated;
grant execute on function public.world_drawing_save(bigint, text, text, text) to authenticated, service_role;

create or replace function public.world_drawing_delete(p_id bigint)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  delete from public.world_drawings where id = p_id and owner_id = uid;
  if not found then raise exception '그림을 찾을 수 없습니다.'; end if;
  return public.world_drawing_list() || jsonb_build_object('content', '그림을 지웠습니다. 걸어 둔 액자는 빈 액자가 됩니다.');
end $f$;
revoke all on function public.world_drawing_delete(bigint) from public, anon, authenticated;
grant execute on function public.world_drawing_delete(bigint) to authenticated, service_role;

create or replace function public.world_drawing_give(p_id bigint, p_target uuid)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_drawing_rules(); d public.world_drawings%rowtype; nm text; tn text; nid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into d from public.world_drawings where id = p_id and owner_id = uid and removed_at is null;
  if not found then raise exception '그림을 찾을 수 없습니다.'; end if;
  if p_target is null or p_target = uid then raise exception '받을 사람을 골라 주세요.'; end if;
  select character_name into tn from public.world_characters where owner_id = p_target;
  if tn is null then raise exception '알 수 없는 조사원입니다.'; end if;
  if not public.world_housing_friends(uid, p_target) or public.world_housing_blocked(uid, p_target) then raise exception '그림은 친구에게만 보낼 수 있습니다.'; end if;
  if (select count(*) from public.world_drawings where giver_id = uid and created_at >= public.world_drawing_day_start()) >= (r ->> 'give_day')::int then
    raise exception '그림은 하루에 %장까지 보낼 수 있습니다.', r ->> 'give_day'; end if;
  if exists (select 1 from public.world_drawings where owner_id = p_target and coalesce(origin, id) = coalesce(d.origin, d.id)) then
    raise exception '%님은 이미 이 그림을 가지고 있습니다.', tn; end if;
  if (select count(*) from public.world_drawings where owner_id = p_target and removed_at is null) >= (r ->> 'keep')::int then
    raise exception '%님의 그림첩이 가득 찼습니다.', tn; end if;
  select character_name into nm from public.world_characters where owner_id = uid;
  insert into public.world_drawings (owner_id, origin, author_id, author_name, title, size, px, giver_id, gift_from)
  values (p_target, coalesce(d.origin, d.id), d.author_id, d.author_name, d.title, d.size, d.px, uid, nm) returning id into nid;
  insert into public.world_notifications (user_id, kind, title, content, payload)
  values (p_target, 'drawing_gift', '그림 선물', nm || '님이 그림' || case when d.title <> '' then ' 「' || d.title || '」' else '' end || '을(를) 보냈습니다. 별채 › 그림첩에서 볼 수 있습니다.', jsonb_build_object('from', uid, 'drawing', nid));
  return jsonb_build_object('ok', true, 'content', tn || '님에게 그림을 보냈습니다.');
end $f$;
revoke all on function public.world_drawing_give(bigint, uuid) from public, anon, authenticated;
grant execute on function public.world_drawing_give(bigint, uuid) to authenticated, service_role;

create or replace function public.world_drawing_hide(p_origin bigint)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_drawings where coalesce(origin, id) = p_origin) then raise exception '그림을 찾을 수 없습니다.'; end if;
  insert into public.world_drawing_hides (viewer_id, origin) values (uid, p_origin) on conflict do nothing;
  return jsonb_build_object('ok', true, 'content', '이 그림을 내 화면에서 숨겼습니다.');
end $f$;
revoke all on function public.world_drawing_hide(bigint) from public, anon, authenticated;
grant execute on function public.world_drawing_hide(bigint) to authenticated, service_role;

create or replace function public.world_drawing_report(p_origin bigint, p_house uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); d public.world_drawings%rowtype; nm text; why text := btrim(regexp_replace(coalesce(p_reason, ''), '[\x01-\x09\x0b-\x1f\x7f]+', ' ', 'g')); rid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into d from public.world_drawings where coalesce(origin, id) = p_origin and removed_at is null order by id limit 1;
  if not found then raise exception '그림을 찾을 수 없습니다.'; end if;
  if d.author_id = uid then raise exception '내가 그린 그림은 제보할 수 없습니다.'; end if;
  if char_length(why) > 200 then raise exception '까닭은 200자까지 적을 수 있습니다.'; end if;
  if exists (select 1 from public.world_bug_reports where owner_id = uid and category = 'drawing' and context ->> 'drawing' = p_origin::text) then
    raise exception '이미 제보한 그림입니다. 운영진이 살펴보고 있습니다.'; end if;
  if (select count(*) from public.world_bug_reports where owner_id = uid and created_at > now() - interval '1 hour') >= 5 then
    raise exception '제보는 1시간에 5건까지 보낼 수 있습니다. 잠시 뒤에 보내 주세요.'; end if;
  select character_name into nm from public.world_characters where owner_id = uid;
  insert into public.world_bug_reports (owner_id, character_name, category, title, body, context)
  values (uid, nm, 'drawing', '그림 제보 · ' || d.author_name || case when d.title <> '' then ' 「' || d.title || '」' else '' end,
    case when why = '' then '(까닭을 적지 않음)' else why end,
    jsonb_build_object('drawing', p_origin, 'author_id', d.author_id, 'author', d.author_name, 'house', p_house, 'hash', case when p_house is not null then '#/house/' || p_house end))
  returning report_id into rid;
  insert into public.world_notifications (user_id, kind, title, content, payload)
  select s.owner_id, 'bug_report', '새 제보', coalesce(nm, '조사원') || ': 그림 제보', jsonb_build_object('report_id', rid) from public.world_staff s where s.owner_id <> uid;
  insert into public.world_drawing_hides (viewer_id, origin) values (uid, p_origin) on conflict do nothing;
  return jsonb_build_object('ok', true, 'content', '운영진에게 알렸습니다. 이 그림은 내 화면에서 숨깁니다.');
end $f$;
revoke all on function public.world_drawing_report(bigint, uuid, text) from public, anon, authenticated;
grant execute on function public.world_drawing_report(bigint, uuid, text) to authenticated, service_role;

create or replace function public.world_drawing_remove(p_origin bigint, p_reason text)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); d public.world_drawings%rowtype; n int; why text := btrim(coalesce(p_reason, ''));
begin
  if uid is null or not exists (select 1 from public.world_staff where owner_id = uid) then raise exception '운영진만 할 수 있습니다.'; end if;
  select * into d from public.world_drawings where coalesce(origin, id) = p_origin order by id limit 1;
  if not found then raise exception '그림을 찾을 수 없습니다.'; end if;
  update public.world_drawings set removed_at = now(), removed_by = uid where coalesce(origin, id) = p_origin and removed_at is null;
  get diagnostics n = row_count;
  if n > 0 then
    insert into public.world_notifications (user_id, kind, title, content, payload)
    values (d.author_id, 'drawing_removed', '그림이 내려졌습니다', '운영진이 그림' || case when d.title <> '' then ' 「' || d.title || '」' else '' end || '을(를) 내렸습니다.' || case when why <> '' then ' 까닭: ' || left(why, 200) else '' end, jsonb_build_object('drawing', p_origin));
  end if;
  return jsonb_build_object('ok', true, 'removed', n, 'content', case when n > 0 then '그림과 사본 ' || n || '장을 내렸습니다.' else '이미 내린 그림입니다.' end);
end $f$;
revoke all on function public.world_drawing_remove(bigint, text) from public, anon, authenticated;
grant execute on function public.world_drawing_remove(bigint, text) to authenticated, service_role;

create or replace function public.world_drawing_brief(p_origin bigint)
returns jsonb language sql stable security definer set search_path to '' as $f$
  select jsonb_build_object('o', p_origin, 's', d.size, 'px', d.px, 't', d.title, 'a', d.author_name, 'removed', d.removed_at is not null,
    'copies', (select count(*) from public.world_drawings c where coalesce(c.origin, c.id) = p_origin and c.removed_at is null))
    from (select * from public.world_drawings x where coalesce(x.origin, x.id) = p_origin order by x.removed_at is null desc, x.id limit 1) d
$f$;
revoke all on function public.world_drawing_brief(bigint) from public, anon, authenticated;
grant execute on function public.world_drawing_brief(bigint) to fn_owner_field, service_role;

create or replace function public.world_drawing_room(p_uid uuid, p_wall jsonb)
returns jsonb language sql stable security definer set search_path to '' as $f$
  select coalesce(jsonb_object_agg(d.id::text, public.world_drawing_json(d, p_uid)), '{}'::jsonb)
    from public.world_drawings d
   where d.id in (select (w ->> 'd')::bigint from jsonb_array_elements(coalesce(p_wall, '[]'::jsonb)) w where jsonb_typeof(w -> 'd') = 'number')
     and d.removed_at is null
     and not exists (select 1 from public.world_drawing_hides h where h.viewer_id = p_uid and h.origin = coalesce(d.origin, d.id))
     and not public.world_housing_blocked(p_uid, d.author_id)
$f$;
revoke all on function public.world_drawing_room(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.world_drawing_room(uuid, jsonb) to fn_owner_field, service_role;

create or replace function public.world_drawing_wall_clean(p_uid uuid, p_home uuid, p_wall jsonb)
returns jsonb language plpgsql stable security definer set search_path to '' as $f$
declare x jsonb; out jsonb := '[]'::jsonb; e jsonb; fr text; d public.world_drawings%rowtype; mate uuid := public.world_housing_mate(p_home);
begin
  if jsonb_typeof(p_wall) <> 'array' then return p_wall; end if;
  for x in select value from jsonb_array_elements(p_wall) loop
    if jsonb_typeof(x) <> 'object' then raise exception '벽 자리가 올바르지 않습니다.'; end if;
    e := jsonb_build_object('k', x -> 'k', 'side', x -> 'side', 't', x -> 't', 'z', x -> 'z');
    if jsonb_typeof(x -> 'd') = 'number' then
      fr := (select equipment_traits ->> 'frame' from public.world_item_catalog where item_id = 'hf_' || (x ->> 'k') and category = 'furniture');
      if fr is null then raise exception '그림은 그림 액자에만 걸 수 있습니다.'; end if;
      select * into d from public.world_drawings where id = (x ->> 'd')::numeric::bigint;
      if found and d.removed_at is null then
        if d.owner_id not in (p_uid, p_home) and d.owner_id is distinct from mate then raise exception '내 그림첩의 그림만 걸 수 있습니다.'; end if;
        if d.size <> fr then raise exception '그림 크기가 액자와 맞지 않습니다.'; end if;
        e := e || jsonb_build_object('d', d.id);
      end if;
    end if;
    out := out || e;
  end loop;
  return out;
end $f$;
revoke all on function public.world_drawing_wall_clean(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.world_drawing_wall_clean(uuid, uuid, jsonb) to fn_owner_field, service_role;

grant create on schema public to fn_owner_field;
alter function public.world_drawing_list() owner to fn_owner_field;
alter function public.world_drawing_save(bigint, text, text, text) owner to fn_owner_field;
alter function public.world_drawing_delete(bigint) owner to fn_owner_field;
alter function public.world_drawing_give(bigint, uuid) owner to fn_owner_field;
alter function public.world_drawing_hide(bigint) owner to fn_owner_field;
alter function public.world_drawing_report(bigint, uuid, text) owner to fn_owner_field;
alter function public.world_drawing_remove(bigint, text) owner to fn_owner_field;
alter function public.world_drawing_brief(bigint) owner to fn_owner_field;
alter function public.world_drawing_room(uuid, jsonb) owner to fn_owner_field;
alter function public.world_drawing_wall_clean(uuid, uuid, jsonb) owner to fn_owner_field;
revoke create on schema public from fn_owner_field;

do $w$
declare d text; a text; b text;
begin
  d := replace(pg_get_functiondef('public.world_housing_save(uuid, jsonb)'::regprocedure), E'\r\n', E'\n');
  if position('world_drawing_wall_clean' in d) = 0 then
    a := $a$then raise exception '배치 형식이 올바르지 않습니다.'; end if;$a$;
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.1.0 world_housing_save 기준 문구가 없습니다'; end if;
    execute replace(d, a, a || E'\n  v_wall := public.world_drawing_wall_clean(uid, own, v_wall);');
  end if;

  d := replace(pg_get_functiondef('public.world_housing_snapshot(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('world_drawing_room' in d) = 0 then
    a := $a$'pet', public.world_pet_room(own),$a$;
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.1.0 world_housing_snapshot 기준 문구가 없습니다'; end if;
    execute replace(d, a, a || $x$ 'drawings', public.world_drawing_room(uid, h.wall),$x$);
  end if;

  d := replace(pg_get_functiondef('public.world_character_purge(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('world_drawings' in d) = 0 then
    a := $a$  delete from public.world_user_commissions where owner_id = p_uid and status = 'open';$a$;
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.1.0 world_character_purge 기준 문구가 없습니다'; end if;
    execute replace(d, a, a || E'\n  delete from public.world_drawings where owner_id = p_uid;\n  delete from public.world_drawing_hides where viewer_id = p_uid;');
  end if;

  d := replace(pg_get_functiondef('public.world_notify_group(text)'::regprocedure), E'\r\n', E'\n');
  if position('drawing_gift' in d) = 0 then
    a := $a$'pet_play', 'pet_new') then 'housing'$a$;
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.1.0 world_notify_group 기준 문구가 없습니다'; end if;
    execute replace(d, a, $x$'pet_play', 'pet_new', 'drawing_gift') then 'housing'$x$);
  end if;

  d := replace(pg_get_functiondef('public.world_bug_report_list(text)'::regprocedure), E'\r\n', E'\n');
  if position('world_drawing_brief' in d) = 0 then
    a := $a$'context', case when (select is_gm from gm) then r.context else null end,$a$;
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.1.0 world_bug_report_list 기준 문구가 없습니다'; end if;
    execute replace(d, a, a || $x$ 'drawing', case when (select is_gm from gm) and r.category = 'drawing' then public.world_drawing_brief((r.context ->> 'drawing')::bigint) end,$x$);
  end if;
end $w$;

update public.world_app_meta set value = '20261108010000' where key = 'db_version';
