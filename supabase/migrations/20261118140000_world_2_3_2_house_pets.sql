create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

create table if not exists public.world_housing_pets (
  keeper_id uuid not null,
  pet_id text not null,
  room smallint not null default 0,
  set_at timestamptz not null default now(),
  primary key (keeper_id, pet_id),
  foreign key (keeper_id, pet_id) references public.world_pets(owner_id, pet_id) on delete cascade
);
alter table public.world_housing_pets enable row level security;
revoke all on public.world_housing_pets from public, anon, authenticated;

create table if not exists public.world_pet_slots (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  n smallint not null default 0,
  bought_at timestamptz not null default now()
);
alter table public.world_pet_slots enable row level security;
revoke all on public.world_pet_slots from public, anon, authenticated;

alter table public.world_pet_guest add column if not exists pet_id text not null default '';
alter table public.world_pet_guest drop constraint world_pet_guest_pkey;
alter table public.world_pet_guest add primary key (owner_id, visitor_id, day, pet_id);

create or replace function public.world_pet_slot_rules()
 returns jsonb language sql immutable
as $f$ select '{"base": 1, "buy": [{"gil": 3000, "items": {"pet_token": 1}}, {"gil": 10000, "items": {"pet_token": 3}}]}'::jsonb $f$;

create or replace function public.world_pet_slot_info(p uuid)
 returns jsonb language plpgsql stable security definer set search_path to ''
as $f$
declare r jsonb := public.world_pet_slot_rules(); b int; u int;
begin
  b := coalesce((select s.n from public.world_pet_slots s where s.owner_id = p), 0);
  u := (select count(*) from public.world_housing_pets hp where hp.keeper_id = p);
  return jsonb_build_object('cap', (r ->> 'base')::int + b, 'used', u, 'bought', b,
    'max', (r ->> 'base')::int + jsonb_array_length(r -> 'buy'), 'next', r -> 'buy' -> b);
end $f$;

create or replace function public.world_housing_pets_view(p_home uuid, p_viewer uuid)
 returns jsonb language plpgsql stable security definer set search_path to ''
as $f$
declare mate uuid := public.world_housing_mate(p_home); guest boolean := p_viewer is not null and p_viewer is distinct from p_home and p_viewer is distinct from mate; today date := public.world_housing_today();
begin
  return (select coalesce(jsonb_agg(jsonb_build_object('id', hp.pet_id, 'keeper', hp.keeper_id, 'nick', p.nickname, 'name', s.pet_name,
      'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'grown', p.affinity >= 100, 'affinity', p.affinity, 'out', false,
      'mess', public.world_pet_mess_of(hp.keeper_id, hp.pet_id), 'room', public.world_housing_room_eff(p_home, hp.room),
      'today', case when guest then coalesce((select jsonb_build_object('pat', g.pat, 'play', g.play) from public.world_pet_guest g
        where g.owner_id = hp.keeper_id and g.visitor_id = p_viewer and g.day = today and g.pet_id = hp.pet_id), '{}'::jsonb) end)
      order by hp.keeper_id = p_home desc, hp.set_at), '[]'::jsonb)
    from public.world_housing_pets hp join public.world_pets p on p.owner_id = hp.keeper_id and p.pet_id = hp.pet_id
    join public.world_pet_species s on s.pet_id = hp.pet_id
   where (hp.keeper_id = p_home or hp.keeper_id = mate) and public.world_housing_home(hp.keeper_id) = p_home);
end $f$;

create or replace function public.world_housing_pet_pick(p_keeper uuid, p_pet text)
 returns text language plpgsql stable security definer set search_path to ''
as $f$
declare home uuid := public.world_housing_home(p_keeper);
begin
  return (select hp.pet_id from public.world_housing_pets hp
   where (hp.keeper_id = p_keeper or (p_pet is null and p_keeper = home and hp.keeper_id = public.world_housing_mate(home)))
     and public.world_housing_home(hp.keeper_id) = home and (p_pet is null or hp.pet_id = p_pet)
   order by hp.keeper_id = p_keeper desc, hp.set_at limit 1);
end $f$;

create or replace function public.world_housing_pet_keeper(p_keeper uuid, p_pet text)
 returns uuid language plpgsql stable security definer set search_path to ''
as $f$
declare home uuid := public.world_housing_home(p_keeper);
begin
  return (select hp.keeper_id from public.world_housing_pets hp
   where (hp.keeper_id = p_keeper or (p_pet is null and p_keeper = home and hp.keeper_id = public.world_housing_mate(home)))
     and public.world_housing_home(hp.keeper_id) = home and (p_pet is null or hp.pet_id = p_pet)
   order by hp.keeper_id = p_keeper desc, hp.set_at limit 1);
end $f$;

create or replace function public.world_housing_pets_on_place()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  insert into public.world_pet_mess(owner_id, pet_id, clean_at) values (new.keeper_id, new.pet_id, now())
  on conflict (owner_id, pet_id) do update set clean_at = now();
  return new;
end $f$;

drop trigger if exists trg_world_pet_mess_place on public.world_housing;

insert into public.world_housing_pets(keeper_id, pet_id, room, set_at)
select h.owner_id, h.pet_id, h.pet_room, h.updated_at from public.world_housing h
  join public.world_pets p on p.owner_id = h.owner_id and p.pet_id = h.pet_id
 where h.pet_id is not null
on conflict do nothing;
update public.world_housing set pet_id = null, pet_out = false where pet_id is not null or pet_out;

drop trigger if exists trg_world_housing_pets_place on public.world_housing_pets;
create trigger trg_world_housing_pets_place after insert on public.world_housing_pets for each row execute function public.world_housing_pets_on_place();

create or replace function public.world_pet_room(p_owner uuid)
 returns jsonb language sql stable security definer set search_path to ''
as $f$ select public.world_housing_pets_view(p_owner, null) -> 0 $f$;

create or replace function public.world_pet_place(p_pet text)
 returns jsonb language plpgsql security definer set search_path to ''
as $f$
declare uid uuid := public.fn_owner_auth_uid(); moved boolean := false; home uuid; cap int; n int; rm smallint := 0; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh_pet_slot:' || uid::text));
  home := public.world_housing_home(uid);
  if not exists (select 1 from public.world_housing where owner_id = home) then raise exception '별채를 얻은 뒤에 동무를 들일 수 있습니다.'; end if;
  if p_pet is null then
    delete from public.world_housing_pets where keeper_id = uid;
    return jsonb_build_object('ok', true, 'pet_id', null, 'content', '별채의 동무를 쉬게 했습니다.');
  end if;
  select coalesce(p.nickname, s.pet_name) into nm from public.world_pets p join public.world_pet_species s using (pet_id) where p.owner_id = uid and p.pet_id = p_pet;
  if nm is null then raise exception '함께하는 동무가 아닙니다.'; end if;
  if exists (select 1 from public.world_housing_pets where keeper_id = uid and pet_id = p_pet) then raise exception '%은(는) 이미 별채에 있습니다.', nm; end if;
  cap := (public.world_pet_slot_info(uid) ->> 'cap')::int;
  n := (select count(*) from public.world_housing_pets where keeper_id = uid);
  if n >= cap then
    if cap > 1 then raise exception '동무 자리가 다 찼습니다(%/%). 별채의 동무 하나를 내보내거나 동무 자리를 늘리세요.', n, cap; end if;
    select room into rm from public.world_housing_pets where keeper_id = uid order by set_at limit 1;
    delete from public.world_housing_pets where keeper_id = uid;
  end if;
  delete from public.world_pet_profile where owner_id = uid and pet_id = p_pet;
  moved := found;
  insert into public.world_housing_pets(keeper_id, pet_id, room) values (uid, p_pet, coalesce(rm, 0));
  return jsonb_build_object('ok', true, 'pet_id', p_pet, 'from_profile', moved,
    'content', case when moved then '데리고 다니던 ' || public.world_josa(nm, '을', '를') || ' 별채에 두었습니다.' else public.world_josa(nm, '을', '를') || ' 별채에 두었습니다.' end);
end $f$;

create or replace function public.world_pet_unplace(p_pet text)
 returns jsonb language plpgsql security definer set search_path to ''
as $f$
declare uid uuid := public.fn_owner_auth_uid(); nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh_pet_slot:' || uid::text));
  delete from public.world_housing_pets where keeper_id = uid and pet_id = p_pet;
  if not found then raise exception '별채에 있는 내 동무가 아닙니다.'; end if;
  select coalesce(p.nickname, s.pet_name) into nm from public.world_pet_species s left join public.world_pets p on p.owner_id = uid and p.pet_id = s.pet_id where s.pet_id = p_pet;
  return jsonb_build_object('ok', true, 'pet_id', p_pet, 'content', public.world_josa(nm, '을', '를') || ' 별채에서 내보냈습니다.');
end $f$;

create or replace function public.world_pet_room_set(p_pet text, p_room integer, p_keeper uuid default null)
 returns jsonb language plpgsql security definer set search_path to ''
as $f$
declare uid uuid := public.fn_owner_auth_uid(); kp uuid := coalesce(p_keeper, uid); home uuid; why text; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  home := public.world_housing_home(uid);
  if public.world_housing_home(kp) <> home then raise exception '이 별채의 동무가 아닙니다.'; end if;
  perform 1 from public.world_housing where owner_id = home for update;
  if not found then raise exception '아직 별채가 없습니다.'; end if;
  why := public.world_housing_room_ok(home, p_room);
  if why is not null then raise exception '%', why; end if;
  update public.world_housing_pets set room = p_room where keeper_id = kp and pet_id = p_pet;
  if not found then raise exception '이 별채의 동무가 아닙니다.'; end if;
  nm := public.world_housing_room_rules() -> 'names' ->> p_room;
  return jsonb_build_object('ok', true, 'pet_id', p_pet, 'keeper', kp, 'room', p_room,
    'content', public.world_josa((select coalesce(p.nickname, s.pet_name) from public.world_pet_species s left join public.world_pets p on p.owner_id = kp and p.pet_id = s.pet_id where s.pet_id = p_pet), '이', '가') || ' ' || nm || '에 머뭅니다.');
end $f$;

create or replace function public.world_pet_slot_buy()
 returns jsonb language plpgsql security definer set search_path to ''
as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; why text; info jsonb; nx jsonb; v_gil int; need jsonb; st jsonb; mt jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  why := public.world_housing_edit_block(uid);
  if why is not null then raise exception '%', why; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not exists (select 1 from public.world_housing where owner_id = public.world_housing_home(uid)) then raise exception '별채를 얻은 뒤에 동무 자리를 늘릴 수 있습니다.'; end if;
  info := public.world_pet_slot_info(uid);
  nx := info -> 'next';
  if nx is null or jsonb_typeof(nx) <> 'object' then raise exception '동무 자리는 %자리가 가장 많습니다.', info ->> 'max'; end if;
  v_gil := coalesce((nx ->> 'gil')::int, 0); need := coalesce(nx -> 'items', '{}'::jsonb);
  if c.gil < v_gil then raise exception '%전이 필요합니다. (가진 전 %)', v_gil, c.gil; end if;
  select items into st from public.world_storage where owner_id = uid for update;
  mt := public.world_materials_take(coalesce(c.inventory, '{}'::jsonb), coalesce(st, '{}'::jsonb), need);
  update public.world_characters set inventory = mt -> 'inv', gil = gil - v_gil, updated_at = now() where owner_id = uid;
  if mt -> 'from_st' <> '{}'::jsonb then
    update public.world_storage set items = (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(mt -> 'st') where jsonb_typeof(value) = 'number' and value::text::int > 0), updated_at = now() where owner_id = uid;
  end if;
  insert into public.world_pet_slots(owner_id, n) values (uid, 1)
  on conflict (owner_id) do update set n = public.world_pet_slots.n + 1, bought_at = now();
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details) values (uid, 'pet_slot', -v_gil, true, jsonb_build_object('items', need));
  info := public.world_pet_slot_info(uid);
  return jsonb_build_object('ok', true, 'slots', info, 'from_storage', mt -> 'from_st',
    'content', '동무 자리를 늘렸습니다. 이제 별채에 내 동무를 ' || (info ->> 'cap') || '마리까지 둘 수 있습니다.');
end $f$;

select pg_temp.yh_fix2('public.world_pet_profile_set(text)'::regprocedure,
  $o$update public.world_housing set pet_id = null, pet_out = false, updated_at = now() where owner_id = uid and pet_id = p_pet;$o$,
  $n$delete from public.world_housing_pets where keeper_id = uid and pet_id = p_pet;$n$);
select pg_temp.yh_fix2('public.world_pet_profile_set(text)'::regprocedure,
  $o$' 별채는 비었습니다.'$o$, $n$' 별채에서 데리고 나왔습니다.'$n$);
select pg_temp.yh_fix2('public.world_reset_identity(text,text,text)'::regprocedure,
  $o$update public.world_housing set pet_id = null, pet_out = false, updated_at = now() where owner_id = uid and pet_id = p_pet;$o$,
  $n$delete from public.world_housing_pets where keeper_id = uid and pet_id = p_pet;$n$);
select pg_temp.yh_fix2('public.world_pet_start(uuid,text)'::regprocedure,
  $o$update public.world_housing set pet_id = null, pet_out = false, updated_at = now() where owner_id = p_owner and pet_id = p_pet;$o$,
  $n$delete from public.world_housing_pets where keeper_id = p_owner and pet_id = p_pet;$n$);

create or replace function public.world_pet_walk(p_out boolean)
 returns jsonb language plpgsql security definer set search_path to ''
as $f$
declare uid uuid := public.fn_owner_auth_uid(); pid text; f text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if coalesce(p_out, false) then
    pid := (select pet_id from public.world_housing_pets where keeper_id = uid order by set_at limit 1);
    if pid is null then raise exception '먼저 별채에 동무를 들이세요. 동무 창에서 바로 데리고 다닐 수도 있습니다.'; end if;
    return public.world_pet_profile_set(pid) || jsonb_build_object('pet_out', true);
  end if;
  select pet_id into f from public.world_pet_profile where owner_id = uid;
  if f is null then raise exception '데리고 다니는 동무가 없습니다.'; end if;
  return public.world_pet_place(f) || jsonb_build_object('pet_out', false);
end $f$;

create or replace function public.world_pet_snapshot()
 returns jsonb language plpgsql stable security definer set search_path to ''
as $f$
declare uid uuid := public.fn_owner_auth_uid(); today date := public.world_housing_today(); home uuid; has_h boolean; placed jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  home := public.world_housing_home(uid);
  has_h := exists (select 1 from public.world_housing h where h.owner_id = home);
  placed := (select coalesce(jsonb_agg(hp.pet_id order by hp.set_at), '[]'::jsonb) from public.world_housing_pets hp where hp.keeper_id = uid);
  return jsonb_build_object(
    'species', (select coalesce(jsonb_agg(jsonb_build_object('id', s.pet_id, 'name', s.pet_name, 'grade', s.grade, 'kind', s.kind, 'likes', s.likes, 'how', s.how) order by s.sort), '[]'::jsonb) from public.world_pet_species s),
    'mine', (select coalesce(jsonb_agg(jsonb_build_object('id', p.pet_id, 'nick', p.nickname, 'affinity', p.affinity, 'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'grown', p.affinity >= 100, 'baby', p.baby_look, 'got_at', p.got_at,
        'pat', case when p.pat_day = today then p.pat_n else 0 end, 'play', case when p.play_day = today then p.play_n else 0 end, 'feed', case when p.feed_day = today then p.feed_n else 0 end) order by p.got_at), '[]'::jsonb)
      from public.world_pets p where p.owner_id = uid),
    'profile', (select f.pet_id from public.world_pet_profile f where f.owner_id = uid),
    'house', has_h,
    'shared', home <> uid or public.world_housing_mate(home) is not null,
    'placed', placed,
    'slots', public.world_pet_slot_info(uid),
    'room', case when has_h then jsonb_build_object('pet_id', placed ->> 0, 'pet_out', false) end);
end $f$;

drop function if exists public.world_pet_act(uuid, text, text);
create function public.world_pet_act(p_owner uuid, p_act text, p_item text default null, p_pet text default null)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); h public.world_housing%rowtype; pt public.world_pets%rowtype; sp public.world_pet_species%rowtype; why text;
  today date := public.world_housing_today(); gain int := 0; react text := 'heart'; c public.world_characters%rowtype; have int; was_adult boolean; carry boolean := false; g public.world_pet_guest%rowtype; nm text; vn text; pid text; kp uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_act not in ('pat', 'play', 'feed') then raise exception '알 수 없는 놀이입니다.'; end if;
  if p_owner is null then
    select f.pet_id into pid from public.world_pet_profile f where f.owner_id = uid;
    if pid is null then raise exception '데리고 다니는 동무가 없습니다.'; end if;
    p_owner := uid; carry := true;
  else
    select * into h from public.world_housing where owner_id = public.world_housing_home(p_owner);
    if not found then raise exception '이 별채에는 동무가 없습니다.'; end if;
    why := public.world_housing_can_view(uid, h.owner_id, h.gate);
    if why is not null then raise exception '%', why; end if;
    pid := public.world_housing_pet_pick(p_owner, p_pet);
    kp := public.world_housing_pet_keeper(p_owner, p_pet);
    if pid is null then raise exception '%', case when p_pet is null then '이 별채에는 동무가 없습니다.' else '그 동무는 이 별채에 없습니다.' end; end if;
    p_owner := kp;
  end if;
  select * into pt from public.world_pets where owner_id = p_owner and pet_id = pid for update;
  select * into sp from public.world_pet_species where pet_id = pid;
  nm := coalesce(pt.nickname, sp.pet_name); was_adult := pt.affinity >= 100;
  if uid = p_owner or public.world_housing_married(uid, p_owner) then
    if p_act = 'pat' then
      if pt.pat_day is distinct from today then pt.pat_n := 0; end if;
      pt.pat_n := pt.pat_n + 1; pt.pat_day := today; gain := public.world_pet_care_gain(uid, 'pat', pt.pat_n, null, null);
    elsif p_act = 'play' then
      if pt.play_day is distinct from today then pt.play_n := 0; end if;
      pt.play_n := pt.play_n + 1; pt.play_day := today; gain := public.world_pet_care_gain(uid, 'play', pt.play_n, null, null); react := 'note';
    else
      if p_item is null or (p_item <> 'pet_food' and p_item not like 'treat\_%') then raise exception '동무 먹이를 골라 주세요.'; end if;
      if pt.feed_day is distinct from today then pt.feed_n := 0; end if;
      if pt.feed_n >= 3 then raise exception '%은(는) 오늘 배가 불러 더 먹지 않습니다.', nm; end if;
      select * into c from public.world_characters where owner_id = uid for update;
      have := coalesce((c.inventory ->> p_item)::int, 0);
      if have < 1 then raise exception '가방에 그 먹이가 없습니다.'; end if;
      update public.world_characters set inventory = case when have - 1 <= 0 then inventory - p_item else jsonb_set(inventory, array[p_item], to_jsonb(have - 1)) end, updated_at = now() where owner_id = uid;
      pt.feed_n := pt.feed_n + 1; pt.feed_day := today;
      gain := public.world_pet_care_gain(uid, 'feed', pt.feed_n, p_item, sp.likes); react := case when p_item = sp.likes then 'star' else 'bowl' end;
    end if;
  else
    if p_act = 'feed' then raise exception '먹이는 주인만 줄 수 있습니다.'; end if;
    insert into public.world_pet_guest(owner_id, visitor_id, day, pet_id) values (p_owner, uid, today, pid) on conflict do nothing;
    select * into g from public.world_pet_guest where owner_id = p_owner and visitor_id = uid and day = today and pet_id = pid for update;
    if (p_act = 'pat' and g.pat) or (p_act = 'play' and g.play) then raise exception '오늘은 이미 %. 내일 또 와 주세요.', case when p_act = 'pat' then '쓰다듬어 주었습니다' else '놀아 주었습니다' end; end if;
    update public.world_pet_guest set pat = pat or p_act = 'pat', play = play or p_act = 'play' where owner_id = p_owner and visitor_id = uid and day = today and pet_id = pid;
    gain := public.world_pet_care_gain(uid, 'guest', 1, null, null); react := case when p_act = 'play' then 'note' else 'heart' end;
    if not g.pat and not g.play then
      select character_name into vn from public.world_characters where owner_id = uid;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (p_owner, 'pet_play', '별채의 동무', vn || '님이 ' || case when p_act = 'pat' then public.world_josa(nm, '을', '를') || ' 쓰다듬어 주었습니다.' else public.world_josa(nm, '과', '와') || ' 놀아 주었습니다.' end, jsonb_build_object('visitor', uid));
    end if;
  end if;
  if p_act <> 'feed' and not carry and coalesce((public.world_pet_mess_of(p_owner, pid) ->> 'sick')::boolean, false) then gain := 0; react := 'sick'; end if;
  pt.affinity := least(300, pt.affinity + gain);
  update public.world_pets set affinity = pt.affinity, pat_day = pt.pat_day, pat_n = pt.pat_n, play_day = pt.play_day, play_n = pt.play_n, feed_day = pt.feed_day, feed_n = pt.feed_n
   where owner_id = p_owner and pet_id = pid;
  if not was_adult and pt.affinity >= 100 then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_owner, 'pet_new', '꼬마 동무가 자랐습니다', public.world_josa(nm, '이', '가') || ' 훌쩍 자랐습니다.', jsonb_build_object('pet_id', pid));
    perform public.world_title_award_check(p_owner, 'home');
  end if;
  return jsonb_build_object('ok', true, 'pet_id', pid, 'keeper', p_owner, 'affinity', pt.affinity, 'gain', gain, 'adult', public.world_pet_look_adult(pt.affinity, pt.baby_look), 'grown', pt.affinity >= 100, 'grew', not was_adult and pt.affinity >= 100, 'react', react,
    'counts', case when uid = p_owner or public.world_housing_married(uid, p_owner) then jsonb_build_object('pat', pt.pat_n, 'play', pt.play_n, 'feed', pt.feed_n) end);
end $function$;

drop function if exists public.world_pet_care(uuid, text);
create function public.world_pet_care(p_owner uuid, p_act text, p_pet text default null)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); h public.world_housing%rowtype; m public.world_pet_mess%rowtype; r jsonb := public.world_pet_mess_rules();
  st jsonb; why text; own boolean; nm text; vn text; c public.world_characters%rowtype; have int; cure text := r->>'cure'; thr interval; aff int; gain int := 0; pid text; kp uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_act not in ('clean', 'cure') then raise exception '알 수 없는 돌보기입니다.'; end if;
  select * into h from public.world_housing where owner_id = public.world_housing_home(p_owner);
  if not found then raise exception '이 별채에는 동무가 없습니다.'; end if;
  pid := public.world_housing_pet_pick(p_owner, p_pet);
  kp := public.world_housing_pet_keeper(p_owner, p_pet);
  if pid is null then raise exception '%', case when p_pet is null then '이 별채에는 동무가 없습니다.' else '그 동무는 이 별채에 없습니다.' end; end if;
  why := public.world_housing_can_view(uid, h.owner_id, h.gate);
  if why is not null then raise exception '%', why; end if;
  own := coalesce(uid = h.owner_id or uid = public.world_housing_mate(h.owner_id) or uid = kp or public.world_housing_married(uid, kp), false);
  select coalesce(p.nickname, s.pet_name) into nm from public.world_pet_species s left join public.world_pets p on p.owner_id = kp and p.pet_id = s.pet_id where s.pet_id = pid;
  insert into public.world_pet_mess(owner_id, pet_id, clean_at) values (kp, pid, now()) on conflict do nothing;
  select * into m from public.world_pet_mess where owner_id = kp and pet_id = pid for update;
  st := public.world_pet_mess_of(kp, pid);
  thr := make_interval(hours => (r->>'every_h')::int) * (r->>'max')::int + make_interval(hours => (r->>'sick_h')::int);
  if p_act = 'clean' then
    if (st->>'n')::int < 1 then raise exception '%의 자리는 깨끗합니다. 치울 것이 없습니다.', nm; end if;
    if not own then
      insert into public.world_pet_clean_log(owner_id, visitor_id, day) values (h.owner_id, uid, public.world_housing_today()) on conflict do nothing;
      if not found then raise exception '오늘은 이미 이 별채의 동무 자리를 치워 주었습니다. 내일 또 와 주세요.'; end if;
      gain := (r->>'guest_gain')::int;
      update public.world_pets set affinity = least(300, affinity + gain) where owner_id = kp and pet_id = pid returning affinity into aff;
      select character_name into vn from public.world_characters where owner_id = uid;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (kp, 'pet_clean', '별채의 동무', vn || '님이 ' || public.world_josa(nm, '이', '가') || ' 어질러 둔 자리를 치워 주었습니다.', jsonb_build_object('visitor', uid));
    end if;
    update public.world_pet_mess set clean_at = now(), sick_at = case when sick_at is null and now() >= clean_at + thr then clean_at + thr else sick_at end
     where owner_id = kp and pet_id = pid;
  else
    if not own then raise exception '약은 주인만 먹일 수 있습니다.'; end if;
    if not (st->>'sick')::boolean then raise exception '%은(는) 아프지 않습니다.', nm; end if;
    if (st->>'n')::int > 0 then raise exception '먼저 어질러진 자리를 치워 주세요.'; end if;
    select * into c from public.world_characters where owner_id = uid for update;
    have := coalesce((c.inventory ->> cure)::int, 0);
    if have < 1 then raise exception '가방에 %이(가) 없습니다. 안전지대 상점에서 살 수 있습니다.', (select item_name from public.world_item_catalog where item_id = cure); end if;
    update public.world_characters set inventory = case when have - 1 <= 0 then inventory - cure else jsonb_set(inventory, array[cure], to_jsonb(have - 1)) end, updated_at = now() where owner_id = uid;
    update public.world_pet_mess set sick_at = null, clean_at = now() where owner_id = kp and pet_id = pid;
  end if;
  return jsonb_build_object('ok', true, 'pet_id', pid, 'keeper', kp, 'mess', public.world_pet_mess_of(kp, pid), 'gain', gain, 'affinity', aff,
    'content', case when p_act = 'cure' then public.world_josa(nm, '이', '가') || ' 약을 먹고 기운을 차렸습니다.'
      when own then public.world_josa(nm, '이', '가') || ' 어질러 둔 자리를 깨끗이 치웠습니다.'
      else public.world_josa(nm, '이', '가') || ' 어질러 둔 자리를 치워 주었습니다. 동무가 고마워합니다.' end);
end $function$;

select pg_temp.yh_fix2('public.world_housing_snapshot(uuid)'::regprocedure,
  $o$'pet_room', public.world_housing_room_eff(own, h.pet_room),$o$,
  $n$'pet_room', coalesce((public.world_pet_room(own) ->> 'room')::int, 0),$n$);
select pg_temp.yh_fix2('public.world_housing_snapshot(uuid)'::regprocedure,
  $o$'pet_id', h.pet_id, 'pet_out', h.pet_out, 'pet', public.world_pet_room(own),$o$,
  $n$'pet_id', public.world_pet_room(own) ->> 'id', 'pet_out', false, 'pet', public.world_pet_room(own), 'pets', public.world_housing_pets_view(own, uid),$n$);
select pg_temp.yh_fix2('public.world_housing_snapshot(uuid)'::regprocedure,
  $o$'pet_today', case when h.pet_id is not null and role is null then (select jsonb_build_object('pat', g.pat, 'play', g.play) from public.world_pet_guest g where g.owner_id = own and g.visitor_id = uid and g.day = today) end,$o$,
  $n$'pet_today', case when role is null then (public.world_housing_pets_view(own, uid) -> 0 -> 'today') end,$n$);

select pg_temp.yh_fix2('public.world_housing_room_set(text,integer)'::regprocedure,
  $o$if p_what = 'pet' then update public.world_housing set pet_room = p_room, updated_at = now() where owner_id = own;$o$,
  $n$if p_what = 'pet' then update public.world_housing_pets set room = p_room where keeper_id = uid;$n$);
select pg_temp.yh_fix2('public.world_housing_room_set(text,integer)'::regprocedure,
  $o$when (select pet_id from public.world_housing where owner_id = own) is null then$o$,
  $n$when not exists (select 1 from public.world_housing_pets where keeper_id = uid) then$n$);

select pg_temp.yh_fix2('public.world_character_purge(uuid)'::regprocedure,
  $o$delete from public.world_pet_mess where owner_id = p_uid;$o$,
  $n$delete from public.world_pet_mess where owner_id = p_uid;
  delete from public.world_housing_pets where keeper_id = p_uid;
  delete from public.world_pet_slots where owner_id = p_uid;$n$);

do $o$ declare f text; begin
  foreach f in array array['public.world_pet_slot_rules()', 'public.world_pet_slot_info(uuid)', 'public.world_housing_pets_view(uuid,uuid)', 'public.world_housing_pet_pick(uuid,text)', 'public.world_housing_pet_keeper(uuid,text)', 'public.world_housing_pets_on_place()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to fn_owner_field', f);
  end loop;
  foreach f in array array['public.world_pet_unplace(text)', 'public.world_pet_room_set(text,integer,uuid)', 'public.world_pet_slot_buy()'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $o$;
grant select, insert, update, delete on public.world_housing_pets, public.world_pet_slots to fn_owner_field;

revoke all on function public.world_pet_care(uuid, text, text) from public, anon;
grant execute on function public.world_pet_care(uuid, text, text) to authenticated, service_role;
grant create on schema public to fn_owner_field;
alter function public.world_pet_act(uuid, text, text, text) owner to fn_owner_field;
revoke create on schema public from fn_owner_field;
revoke all on function public.world_pet_act(uuid, text, text, text) from public, anon;
grant execute on function public.world_pet_act(uuid, text, text, text) to authenticated, service_role, fn_owner_field;

select pg_temp.yh_fix2('public.world_storage_snapshot()'::regprocedure,
  $o$'in_safe', exists (select 1 from public.world_current_shop(uid)),$o$,
  $n$'in_safe', exists (select 1 from public.world_current_shop(uid)), 'use_here', exists (select 1 from public.world_current_shop(uid)) and not public.world_banyo_here(uid),$n$);

update public.world_patch_notes set body = body || '

- 별채에 꼬마 동무를 여러 마리 둘 수 있습니다. 처음에는 한 사람에 한 자리이고, 동무 창에서 「동무 자리 늘리기」로 두 자리를 더 늘릴 수 있습니다(둘째 자리 3,000전과 동무 정표 1개, 셋째 자리 10,000전과 동무 정표 3개 — 별채를 고칠 수 있는 곳에서, 재료는 가방 먼저, 모자라면 창고에서).
- 한 지붕에 사는 정인끼리는 서로 자기 동무를 둡니다. 두 사람의 자리를 더한 만큼 한 별채에 머물고, 갈라서면 각자의 동무는 각자의 별채로 돌아갑니다.
- 동무마다 머무는 방을 따로 고르고, 어질러진 자리·배탈도 동무마다 따로 셉니다. 손님은 동무마다 하루 한 번씩 쓰다듬고 놀아 줄 수 있습니다.
- 동무 창에서 별채에 있는 동무마다 「내보내기」를 누를 수 있습니다. 자리가 하나뿐이면 다른 동무를 「별채에 두기」로 바로 바꿔 둡니다.
- 묵창 나루에서 가방 › 제작이 창고 재료까지 더해 「만들 수 있음」으로 보이던 것을 고쳤습니다. 묵창 나루도 반요촌처럼 창고 재료를 쓰지 않으며(서버는 원래 그랬습니다), 제작 화면·도움말·서신·조사원 의뢰·강화 안내가 빈약한 안전지대 두 곳을 함께 적습니다.
' where note_id = '2.3.0' and body not like '%여러 마리 둘 수 있습니다%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118140000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
