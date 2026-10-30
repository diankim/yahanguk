-- 7.3.0 별채: 혼례를 올린 정인과 「한 지붕」(제보 26)
--   한 사람이 둘 중 한 별채를 고르고 제안 → 정인이 24시간 안에 받으면 그 별채(집)를 둘이 함께 쓴다.
--   넓이는 그대로(넓히기는 둘 중 누구든 집을 넓힘), 설치 상한·곳간은 두 사람 몫(집 + 들어온 정인 별채 넓이의 몫), 같은 가구 상한은 두 배.
--   들어온 정인(mate)의 별채는 지우지 않고 그대로 두며, 곳간 가구는 함께 쓰는 곳간으로 옮긴다. 들어온 정인이 들여온 가구 수는 contrib에 적어 두고
--   갈라서면(둘 중 누구든 「각자 별채로」 또는 연리·혼례가 끝나면) 그만큼(남아 있는 만큼)을 곳간 → 놓인 것 순서로 빼서 그 사람 곳간에 돌려준다.
--   구경·방명록·발걸음·대문·동무는 집 하나로 모인다(정인의 별채 주소로 와도 집을 보인다). 동무는 집주인의 동무가 머문다.

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;

create table if not exists public.world_housing_shared (
  home_id uuid primary key,
  mate_id uuid not null unique,
  merged_at timestamptz not null default now(),
  contrib jsonb not null default '{}'::jsonb,
  check (home_id <> mate_id)
);
create table if not exists public.world_housing_merge_asks (
  from_id uuid primary key, to_id uuid not null, home_id uuid not null,
  created_at timestamptz not null default now()
);
alter table public.world_housing_shared enable row level security;
alter table public.world_housing_merge_asks enable row level security;
revoke all on public.world_housing_shared, public.world_housing_merge_asks from anon, authenticated;
grant select, insert, update, delete on public.world_housing_shared, public.world_housing_merge_asks to fn_owner_field;

-- 이 사람이 사는 집(함께 쓰면 집주인, 아니면 자기)
create or replace function public.world_housing_home(p uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  return coalesce((select s.home_id from public.world_housing_shared s where s.home_id = p or s.mate_id = p limit 1), p);
end $$;
create or replace function public.world_housing_mate(p_home uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  return (select s.mate_id from public.world_housing_shared s where s.home_id = p_home);
end $$;
-- 혼례를 올린 정인
create or replace function public.world_housing_partner(p uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  return (select case when b.a_id = p then b.b_id else b.a_id end from public.world_bonds b
    where b.ended_at is null and coalesce((b.marks ->> 'married')::boolean, false) and (b.a_id = p or b.b_id = p) limit 1);
end $$;
-- 두 사람 몫: 집 넓이의 몫 + 들어온 정인 별채 넓이의 몫(별채가 없으면 6×6 몫)
create or replace function public.world_housing_cap_of(p_home uuid) returns int
language plpgsql stable security definer set search_path = '' as $$
declare m uuid := public.world_housing_mate(p_home);
begin
  return public.world_housing_cap((select h.size from public.world_housing h where h.owner_id = p_home))
    + case when m is null then 0 else public.world_housing_cap(coalesce((select h.size from public.world_housing h where h.owner_id = m), 6)) end;
end $$;
create or replace function public.world_housing_store_cap_of(p_home uuid) returns int
language plpgsql stable security definer set search_path = '' as $$
declare m uuid := public.world_housing_mate(p_home);
begin
  return public.world_housing_store_cap((select h.size from public.world_housing h where h.owner_id = p_home))
    + case when m is null then 0 else public.world_housing_store_cap((select h.size from public.world_housing h where h.owner_id = m)) end;
end $$;
create or replace function public.world_housing_kind_mul(p_home uuid) returns int
language plpgsql stable security definer set search_path = '' as $$
begin
  return case when exists (select 1 from public.world_housing_shared s where s.home_id = p_home) then 2 else 1 end;
end $$;
-- 들어온 정인이 들여온 가구 수를 더하고 뺀다(0 아래로 내려가지 않음)
create or replace function public.world_housing_contrib(p_home uuid, p_item text, p_delta int) returns void
language plpgsql security definer set search_path = '' as $$
declare cur int;
begin
  select coalesce((s.contrib ->> p_item)::int, 0) into cur from public.world_housing_shared s where s.home_id = p_home for update;
  if not found then return; end if;
  cur := greatest(0, cur + coalesce(p_delta, 0));
  update public.world_housing_shared set contrib = case when cur = 0 then contrib - p_item else jsonb_set(contrib, array[p_item], to_jsonb(cur)) end where home_id = p_home;
end $$;

-- 화면용: 정인·한 지붕·제안 상태
create or replace function public.world_housing_merge_info(p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare pt uuid := public.world_housing_partner(p_uid); sh public.world_housing_shared%rowtype;
begin
  select * into sh from public.world_housing_shared s where s.home_id = p_uid or s.mate_id = p_uid;
  if pt is null and sh.home_id is null then return null; end if;
  return jsonb_build_object(
    'partner_id', pt, 'partner_name', (select c.character_name from public.world_characters c where c.owner_id = pt),
    'partner_house', exists (select 1 from public.world_housing h where h.owner_id = pt),
    'my_house', exists (select 1 from public.world_housing h where h.owner_id = p_uid),
    'shared', case when sh.home_id is null then null else jsonb_build_object('home_id', sh.home_id, 'mate_id', sh.mate_id, 'i_am_home', sh.home_id = p_uid, 'since', sh.merged_at,
      'home_name', (select c.character_name from public.world_characters c where c.owner_id = sh.home_id),
      'mate_name', (select c.character_name from public.world_characters c where c.owner_id = sh.mate_id),
      'mate_items', public.world_housing_store_count(sh.contrib)) end,
    'ask_out', (select jsonb_build_object('home_id', a.home_id, 'at', a.created_at) from public.world_housing_merge_asks a where a.from_id = p_uid and a.created_at > now() - interval '24 hours'),
    'ask_in', (select jsonb_build_object('home_id', a.home_id, 'at', a.created_at, 'from_name', (select c.character_name from public.world_characters c where c.owner_id = a.from_id))
      from public.world_housing_merge_asks a where a.to_id = p_uid and a.created_at > now() - interval '24 hours'));
end $$;

-- 합치자고 제안(p_home: 'mine' 내 별채로 · 'theirs' 정인의 별채로)
create or replace function public.world_housing_merge_ask(p_home text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); pt uuid; hm uuid; nm text; pn text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  pt := public.world_housing_partner(uid);
  if pt is null then raise exception '혼례를 올린 정인이 있어야 별채를 합칠 수 있습니다.'; end if;
  hm := case p_home when 'mine' then uid when 'theirs' then pt end;
  if hm is null then raise exception '어느 별채를 함께 쓸지 고르세요.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh-house-merge:' || least(uid, pt)::text || greatest(uid, pt)::text));
  if not exists (select 1 from public.world_housing h where h.owner_id = hm) then raise exception '%의 별채가 아직 없습니다.', case when hm = uid then '내' else '정인' end; end if;
  if exists (select 1 from public.world_housing_shared s where s.home_id in (uid, pt) or s.mate_id in (uid, pt)) then raise exception '이미 한 지붕 아래 있습니다.'; end if;
  delete from public.world_housing_merge_asks where from_id in (uid, pt);
  insert into public.world_housing_merge_asks(from_id, to_id, home_id) values (uid, pt, hm);
  select character_name into nm from public.world_characters where owner_id = uid;
  select character_name into pn from public.world_characters where owner_id = pt;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (pt, 'housing_merge', '한 지붕 제안', nm || '님이 ' || case when hm = uid then nm || '님의 별채' else '당신의 별채' end || '를 함께 쓰자고 합니다. 24시간 안에 캐릭터 › 별채에서 받을 수 있습니다.', jsonb_build_object('from', uid));
  return jsonb_build_object('ok', true, 'content', pn || '님에게 별채를 합치자고 전했습니다. 정인이 받으면 한 지붕이 됩니다.');
end $$;
create or replace function public.world_housing_merge_cancel() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  delete from public.world_housing_merge_asks where from_id = uid;
  return jsonb_build_object('ok', true, 'content', '제안을 거두었습니다.');
end $$;
-- 받기·미루기
create or replace function public.world_housing_merge_answer(p_accept boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); a public.world_housing_merge_asks%rowtype; pt uuid; mate uuid; nm text; st jsonb; k text; v int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into a from public.world_housing_merge_asks where to_id = uid and created_at > now() - interval '24 hours' order by created_at desc limit 1;
  if not found then raise exception '받은 제안이 없거나 기한(24시간)이 지났습니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh-house-merge:' || least(uid, a.from_id)::text || greatest(uid, a.from_id)::text));
  delete from public.world_housing_merge_asks where from_id = a.from_id;
  select character_name into nm from public.world_characters where owner_id = uid;
  if not coalesce(p_accept, false) then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (a.from_id, 'housing_merge', '한 지붕 제안', nm || '님이 별채 합치기를 다음으로 미뤘습니다.', jsonb_build_object('from', uid));
    return jsonb_build_object('ok', true, 'content', '제안을 미뤘습니다.');
  end if;
  pt := public.world_housing_partner(uid);
  if pt is null or pt <> a.from_id then raise exception '정인과의 혼례가 이어져 있지 않습니다.'; end if;
  if exists (select 1 from public.world_housing_shared s where s.home_id in (uid, pt) or s.mate_id in (uid, pt)) then raise exception '이미 한 지붕 아래 있습니다.'; end if;
  if not exists (select 1 from public.world_housing h where h.owner_id = a.home_id) then raise exception '함께 쓸 별채가 없습니다.'; end if;
  mate := case when a.home_id = uid then pt else uid end;
  insert into public.world_housing_shared(home_id, mate_id) values (a.home_id, mate);
  -- 들어오는 정인의 곳간 가구는 함께 쓰는 곳간으로(들여온 몫으로 적어 둔다, 곳간 칸을 넘어도 옮김)
  select items into st from public.world_housing_store where owner_id = mate for update;
  if st is not null and st <> '{}'::jsonb then
    insert into public.world_housing_store(owner_id) values (a.home_id) on conflict (owner_id) do nothing;
    for k, v in select key, value::int from jsonb_each_text(st) loop
      if v > 0 then
        update public.world_housing_store set items = public.world_inv_add(items, k, v), updated_at = now() where owner_id = a.home_id;
        perform public.world_housing_contrib(a.home_id, k, v);
      end if;
    end loop;
    update public.world_housing_store set items = '{}'::jsonb, updated_at = now() where owner_id = mate;
  end if;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (a.from_id, 'housing_merge', '한 지붕이 되었습니다', nm || '님이 제안을 받았습니다. 이제 한 별채를 함께 씁니다.', jsonb_build_object('home', a.home_id));
  return jsonb_build_object('ok', true, 'content', '한 지붕이 되었습니다. 설치할 수 있는 가구와 곳간이 두 사람 몫으로 늘었습니다.');
end $$;

-- 갈라서기(안쪽): 들어온 정인이 들여온 가구를 곳간 → 놓인 것 순서로 빼서 그 사람 곳간에 돌려준다
create or replace function public.world_housing_unshare(p_home uuid, p_why text) returns void
language plpgsql security definer set search_path = '' as $$
declare sh public.world_housing_shared%rowtype; h public.world_housing%rowtype; st jsonb; placed jsonb; give jsonb := '{}'::jsonb;
  k text; want int; n int; t1 int; rest int; arr jsonb; out jsonb; x jsonb; i int; j int; total int := 0; v_paper text; v_ground text;
begin
  select * into sh from public.world_housing_shared where home_id = p_home for update;
  if not found then return; end if;
  select * into h from public.world_housing where owner_id = p_home for update;
  insert into public.world_housing_store(owner_id) values (p_home) on conflict (owner_id) do nothing;
  select coalesce(items, '{}'::jsonb) into st from public.world_housing_store where owner_id = p_home for update;
  placed := public.world_housing_counts(h.items, h.wall, h.paper, h.ground);
  v_paper := h.paper; v_ground := h.ground;
  for k, want in select key, value::int from jsonb_each_text(sh.contrib) loop
    n := least(want, coalesce((st ->> k)::int, 0) + coalesce((placed ->> k)::int, 0));
    if n <= 0 then continue; end if;
    t1 := least(n, coalesce((st ->> k)::int, 0));
    if t1 > 0 then st := public.world_inv_add(st, k, -t1); if coalesce((st ->> k)::int, 0) <= 0 then st := st - k; end if; end if;
    rest := n - t1;
    -- 놓인 것에서 뺀다(뒤에 놓인 것부터): 바닥 → 벽 → 벽지·바닥재
    for j in 1 .. 2 loop
      exit when rest <= 0;
      arr := case j when 1 then coalesce(h.items, '[]'::jsonb) else coalesce(h.wall, '[]'::jsonb) end;
      out := '[]'::jsonb;
      for i in reverse jsonb_array_length(arr) - 1 .. 0 loop
        x := arr -> i;
        if rest > 0 and 'hf_' || (x ->> 'k') = k then rest := rest - 1; else out := jsonb_build_array(x) || out; end if;
      end loop;
      if j = 1 then h.items := out; else h.wall := out; end if;
    end loop;
    if rest > 0 and v_paper is not null and 'hp_' || v_paper = k then v_paper := null; rest := rest - 1; end if;
    if rest > 0 and v_ground is not null and 'hg_' || v_ground = k then v_ground := null; rest := rest - 1; end if;
    give := jsonb_set(give, array[k], to_jsonb(n - rest)); total := total + n - rest;
  end loop;
  update public.world_housing set items = h.items, wall = h.wall, paper = v_paper, ground = v_ground, updated_at = now() where owner_id = p_home;
  update public.world_housing_store set items = st, updated_at = now() where owner_id = p_home;
  insert into public.world_housing_store(owner_id) values (sh.mate_id) on conflict (owner_id) do nothing;
  for k, n in select key, value::int from jsonb_each_text(give) loop
    if n > 0 then update public.world_housing_store set items = public.world_inv_add(items, k, n), updated_at = now() where owner_id = sh.mate_id; end if;
  end loop;
  delete from public.world_housing_shared where home_id = p_home;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select u, 'housing_merge', '각자 별채로 돌아갔습니다', coalesce(p_why || ' ', '') ||
    case when u = sh.mate_id then case when total > 0 then '들여온 가구 ' || total || '점이 내 별채 곳간으로 돌아왔습니다.' else '내 별채로 돌아왔습니다.' end
         else case when total > 0 then '정인이 들여온 가구 ' || total || '점은 정인에게 돌아갔습니다.' else '별채는 그대로입니다.' end end,
    jsonb_build_object('home', p_home)
  from unnest(array[sh.home_id, sh.mate_id]) u;
end $$;
create or replace function public.world_housing_split() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); hm uuid; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  hm := public.world_housing_home(uid);
  if public.world_housing_mate(hm) is null then raise exception '함께 쓰는 별채가 아닙니다.'; end if;
  select character_name into nm from public.world_characters where owner_id = uid;
  perform public.world_housing_unshare(hm, nm || '님이 각자 별채로 돌아가기로 했습니다.');
  return jsonb_build_object('ok', true, 'content', '각자 별채로 돌아갔습니다. 정인이 들여온 가구는 정인의 곳간으로 돌아갑니다.');
end $$;

-- 연리가 끝나거나 혼례 표시가 사라지면 저절로 갈라선다(제안도 지운다)
create or replace function public.world_housing_bond_trg() returns trigger
language plpgsql security definer set search_path = '' as $$
declare hm uuid;
begin
  if (new.ended_at is not null and old.ended_at is null)
     or (coalesce((old.marks ->> 'married')::boolean, false) and not coalesce((new.marks ->> 'married')::boolean, false)) then
    delete from public.world_housing_merge_asks where from_id in (new.a_id, new.b_id);
    select s.home_id into hm from public.world_housing_shared s where (s.home_id = new.a_id and s.mate_id = new.b_id) or (s.home_id = new.b_id and s.mate_id = new.a_id);
    if hm is not null then perform public.world_housing_unshare(hm, '연리가 끝나'); end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_world_housing_bond on public.world_bonds;
create trigger trg_world_housing_bond after update of ended_at, marks on public.world_bonds for each row execute function public.world_housing_bond_trg();

-- ── 기존 함수: 집 하나로 모으기 ──
-- 보기: 정인의 별채 주소로 와도 집을 보이고, 들어온 정인도 집주인처럼(owner) 고친다. 상한은 두 사람 몫, 한 지붕·제안 상태를 함께 돌려준다
select pg_temp.yh_patch('public.world_housing_snapshot(uuid)', 'own uuid := coalesce(p_owner, uid);', 'own uuid := public.world_housing_home(coalesce(p_owner, uid));');
select pg_temp.yh_patch('public.world_housing_snapshot(uuid)', 'role := case when uid = own then ''owner''', 'role := case when uid = own or uid = public.world_housing_mate(own) then ''owner''');
select pg_temp.yh_patch('public.world_housing_snapshot(uuid)',
  '''cap'', public.world_housing_cap(h.size), ''store_cap'', public.world_housing_store_cap(h.size), ''kind_caps'', jsonb_build_array(4, 3, 2, 1, 1),',
  '''cap'', public.world_housing_cap_of(own), ''store_cap'', public.world_housing_store_cap_of(own),
    ''kind_caps'', (select jsonb_agg(x * public.world_housing_kind_mul(own) order by o) from unnest(array[4, 3, 2, 1, 1]) with ordinality u(x, o)),
    ''merge'', case when role = ''owner'' then public.world_housing_merge_info(uid) end,
    ''mate_name'', (select c2.character_name from public.world_characters c2 where c2.owner_id = public.world_housing_mate(own)),');
select pg_temp.yh_patch('public.world_housing_snapshot(uuid)', '''store'', (select items from public.world_housing_store where owner_id = uid));',
  '''store'', (select items from public.world_housing_store where owner_id = uid), ''merge'', public.world_housing_merge_info(uid));');
-- 저장: 집에 저장하고, 상한은 두 사람 몫, 들어온 정인이 가방에서 놓은 가구는 들여온 몫으로 적는다
select pg_temp.yh_patch('public.world_housing_save(uuid,jsonb)', 'own uuid := coalesce(p_owner, uid);', 'own uuid := public.world_housing_home(coalesce(p_owner, uid));');
select pg_temp.yh_patch('public.world_housing_save(uuid,jsonb)',
  'if placed > public.world_housing_cap(h.size) then raise exception ''이 별채에는 가구를 %개까지 놓을 수 있습니다. (지금 %개)'', public.world_housing_cap(h.size), placed; end if;',
  'if placed > public.world_housing_cap_of(own) then raise exception ''이 별채에는 가구를 %개까지 놓을 수 있습니다. (지금 %개)'', public.world_housing_cap_of(own), placed; end if;');
select pg_temp.yh_patch('public.world_housing_save(uuid,jsonb)',
  'public.world_housing_kind_cap((select tier from public.world_item_catalog where item_id = k))',
  'public.world_housing_kind_cap((select tier from public.world_item_catalog where item_id = k)) * public.world_housing_kind_mul(own)', 2);
select pg_temp.yh_patch('public.world_housing_save(uuid,jsonb)',
  'inv := public.world_inv_add(inv, k, -d); if coalesce((inv ->> k)::int, 0) <= 0 then inv := inv - k; end if; bag_changed := true;',
  'inv := public.world_inv_add(inv, k, -d); if coalesce((inv ->> k)::int, 0) <= 0 then inv := inv - k; end if; bag_changed := true;
        if own <> uid and uid = public.world_housing_mate(own) then perform public.world_housing_contrib(own, k, d); end if;');
select pg_temp.yh_patch('public.world_housing_save(uuid,jsonb)', 'public.world_housing_store_cap(h.size)', 'public.world_housing_store_cap_of(own)', 2);
-- 곳간: 집의 곳간을 쓴다. 들어온 정인이 넣으면 들여온 몫에 더하고, 꺼내거나 버리면 뺀다
select pg_temp.yh_patch('public.world_housing_store_move(text,integer,text)', 'room int; sz int;', 'room int; sz int; hm uuid;');
select pg_temp.yh_patch('public.world_housing_store_move(text,integer,text)', 'select size into sz from public.world_housing where owner_id = uid;',
  'hm := public.world_housing_home(uid); select size into sz from public.world_housing where owner_id = hm;');
select pg_temp.yh_patch('public.world_housing_store_move(text,integer,text)',
  'insert into public.world_housing_store(owner_id) values (uid) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = uid for update;',
  'insert into public.world_housing_store(owner_id) values (hm) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = hm for update;');
select pg_temp.yh_patch('public.world_housing_store_move(text,integer,text)', 'public.world_housing_store_cap(sz)', 'public.world_housing_store_cap_of(hm)', 2);
select pg_temp.yh_patch('public.world_housing_store_move(text,integer,text)',
  'update public.world_housing_store set items = public.world_inv_add(items, p_item, p_qty), updated_at = now() where owner_id = uid;',
  'update public.world_housing_store set items = public.world_inv_add(items, p_item, p_qty), updated_at = now() where owner_id = hm;
    if hm <> uid then perform public.world_housing_contrib(hm, p_item, p_qty); end if;');
select pg_temp.yh_patch('public.world_housing_store_move(text,integer,text)',
  'update public.world_housing_store set items = case when have - n <= 0 then items - p_item else jsonb_set(items, array[p_item], to_jsonb(have - n)) end, updated_at = now() where owner_id = uid;',
  'update public.world_housing_store set items = case when have - n <= 0 then items - p_item else jsonb_set(items, array[p_item], to_jsonb(have - n)) end, updated_at = now() where owner_id = hm;
  if hm <> uid then perform public.world_housing_contrib(hm, p_item, -n); end if;');
-- 넓히기·대문: 집에
select pg_temp.yh_patch('public.world_housing_expand()', 'select * into h from public.world_housing where owner_id = uid for update;',
  'select * into h from public.world_housing where owner_id = public.world_housing_home(uid) for update;');
select pg_temp.yh_patch('public.world_housing_expand()', 'update public.world_housing set size = size + 1, updated_at = now() where owner_id = uid;',
  'update public.world_housing set size = size + 1, updated_at = now() where owner_id = h.owner_id;');
select pg_temp.yh_patch('public.world_housing_gate(text)', 'update public.world_housing set gate = p_gate, updated_at = now() where owner_id = uid;',
  'update public.world_housing set gate = p_gate, updated_at = now() where owner_id = public.world_housing_home(uid);');
-- 방명록: 함께 사는 정인도 집의 글을 지운다
select pg_temp.yh_patch('public.world_housing_guest_delete(bigint)', 'if uid not in (g.owner_id, g.writer_id) then',
  'if uid not in (g.owner_id, g.writer_id) and public.world_housing_home(uid) <> g.owner_id then');
-- 보상 가구: 함께 살면 집의 곳간으로(들어온 정인 몫은 들여온 몫에 더함)
select pg_temp.yh_patch('public.world_housing_grant(uuid,text,integer,text,boolean)', 'declare s public.world_housing_store%rowtype;',
  'declare hm uuid := public.world_housing_home(p_owner); s public.world_housing_store%rowtype;');
select pg_temp.yh_patch('public.world_housing_grant(uuid,text,integer,text,boolean)',
  'insert into public.world_housing_store(owner_id) values (p_owner) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = p_owner for update;',
  'insert into public.world_housing_store(owner_id) values (hm) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = hm for update;');
select pg_temp.yh_patch('public.world_housing_grant(uuid,text,integer,text,boolean)',
  'cap := public.world_housing_store_cap((select size from public.world_housing where owner_id = p_owner));', 'cap := public.world_housing_store_cap_of(hm);');
select pg_temp.yh_patch('public.world_housing_grant(uuid,text,integer,text,boolean)',
  'update public.world_housing_store set items = public.world_inv_add(items, p_item, n), updated_at = now() where owner_id = p_owner;',
  'update public.world_housing_store set items = public.world_inv_add(items, p_item, n), updated_at = now() where owner_id = hm;
  if hm <> p_owner then perform public.world_housing_contrib(hm, p_item, n); end if;');
-- 동무: 함께 쓰는 집에는 집주인의 동무가 머문다
select pg_temp.yh_patch('public.world_pet_place(text)', '  update public.world_housing set pet_id = p_pet, pet_out = false, updated_at = now() where owner_id = uid;',
  '  if public.world_housing_home(uid) <> uid then raise exception ''함께 쓰는 별채에는 집주인의 동무가 머뭅니다. 내 동무는 데리고 다닐 수 있습니다.''; end if;
  update public.world_housing set pet_id = p_pet, pet_out = false, updated_at = now() where owner_id = uid;');

-- 함수 주인·권한
do $$ declare fn text; begin
  foreach fn in array array['world_housing_home(uuid)', 'world_housing_mate(uuid)', 'world_housing_partner(uuid)', 'world_housing_cap_of(uuid)', 'world_housing_store_cap_of(uuid)',
    'world_housing_kind_mul(uuid)', 'world_housing_contrib(uuid,text,integer)', 'world_housing_merge_info(uuid)', 'world_housing_merge_ask(text)', 'world_housing_merge_cancel()',
    'world_housing_merge_answer(boolean)', 'world_housing_unshare(uuid,text)', 'world_housing_split()', 'world_housing_bond_trg()'] loop
    execute format('alter function public.%s owner to fn_owner_field', fn);
  end loop;
end $$;
do $$ begin
  set role fn_owner_field;
  revoke all on function public.world_housing_home(uuid), public.world_housing_mate(uuid), public.world_housing_partner(uuid), public.world_housing_cap_of(uuid), public.world_housing_store_cap_of(uuid),
    public.world_housing_kind_mul(uuid), public.world_housing_contrib(uuid, text, integer), public.world_housing_merge_info(uuid), public.world_housing_unshare(uuid, text), public.world_housing_bond_trg()
    from public, anon, authenticated;
  revoke all on function public.world_housing_merge_ask(text), public.world_housing_merge_cancel(), public.world_housing_merge_answer(boolean), public.world_housing_split() from public, anon;
  grant execute on function public.world_housing_merge_ask(text), public.world_housing_merge_cancel(), public.world_housing_merge_answer(boolean), public.world_housing_split() to authenticated;
  reset role;
end $$;

update public.world_app_meta set value = '20261103150000' where key = 'db_version';
