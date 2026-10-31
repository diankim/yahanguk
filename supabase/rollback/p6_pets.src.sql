-- 대기 파일: 꼬마 동무 1.0.0(롤백 패치) — 새 동무 8종(조사원 제보) · 동무 두 자리(프로필 동무 / 별채 동무)
-- 1.0.0 묶음에 합칠 것(db_version 줄은 넣지 않았다 — 묶음 마지막에 한 번). migrations 폴더 밖에 두어 실수로 돌지 않게 했다.
-- 화면: assets/js/housing/pets.js(38종, tools/pet_art/art4.py → gen.py) · views/housing.js(동무 창·별채 없을 때 동무 칸) · views/guide.js.
-- 그림(pets.js)이 먼저 배포돼 있어도 world_pet_species에 없으면 도감에 나오지 않는다.
--
-- ① 새 동무 8종(제보한 조사원 → 동무)
--   네눈박이 강아지(박시현) 범품 · 바구니 / 흰둥이 강아지(조의신) 범품 · 바구니
--   잿빛 장모 고양이(여보) · 점박이 하늘다람쥐(윤아람) · 꼬마 족제비(강산하) 양품 · 얼룩무늬 알
--   금빛 날개늑대(나락) 진품 · 퀘스트 「벼락을 부르는 문」 + 빛나는 알
--   외뿔 팔족염소(아도니스) 명품 · 외전 「거꾸로 선 기도」(gq_3) / 꼬마 홍룡(조의신) 명품 · 8장 「재의 바다」(mq_ash_sea)
-- ② 제보한 조사원에게 주기(결정 필요): world_pet_gifts(계정 id = world_characters.owner_id, 롤백해도 그대로) + 스위치 world_app_meta 'pet_gift'
--   'on'이면 그 계정이 새 캐릭터를 만들 때 저절로 도감에 넣고, 켤 때 이미 캐릭터가 있으면 world_pet_gift_apply_all()로 한 번에 준다.
--   이 파일은 'off'로 넣는다. 켜기: update public.world_app_meta set value = 'on' where key = 'pet_gift'; select public.world_pet_gift_apply_all();
--   아예 주지 않기: 'off' 그대로 두거나 delete from public.world_pet_gifts;
-- ③ 동무 두 자리: 프로필 동무(world_pet_profile, 조사원 카드에 보이고 데리고 다님, 별채 없어도 됨) · 별채 동무(world_housing.pet_id, 지금처럼).
--   같은 동무는 한 자리에만(다른 자리로 고르면 앞 자리에서 빠짐). world_housing.pet_out은 더 쓰지 않는다(열은 남기고 늘 false).
--   한 지붕에 들어온 정인도 프로필 동무는 따로 정한다(별채 동무는 지금처럼 집주인 것).
--
-- 미리 돌려 보기: begin; + 이 파일 + rollback;
-- ─────────────────────────────────────────────────────────────

-- 함수 본문 고치기 도우미(gen71/_patch_fn.sql과 같다)
create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

grant fn_owner_field to postgres with inherit true, set true;

-- ── ① 새 동무 8종 ─────────────────────────────
insert into public.world_pet_species(pet_id, pet_name, grade, kind, likes, how, sort, egg)
select x.pet_id, x.pet_name, x.grade, x.kind, x.likes, x.how, x.sort, x.egg
  from (values
    ('neun_puppy',       '네눈박이 강아지',   1, 'ward',    'treat_meat',  '안전지대 상점의 바구니', 30, false),
    ('white_puppy',      '흰둥이 강아지',     1, 'ward',    'treat_rice',  '안전지대 상점의 바구니', 31, false),
    ('ash_longhair',     '잿빛 장모 고양이',  2, 'shadow',  'treat_fish',  '탐색 중 「얼룩무늬 알」', 32, true),
    ('spotted_glider',   '점박이 하늘다람쥐', 2, 'sky',     'treat_rice',  '탐색 중 「얼룩무늬 알」', 33, true),
    ('golden_wingwolf',  '금빛 날개늑대',     3, 'sky',     'treat_meat',  '퀘스트 「벼락을 부르는 문」을(를) 마친다 · 빛나는 알', 34, true),
    ('little_ferret',    '꼬마 족제비',       2, 'shadow',  'treat_meat',  '탐색 중 「얼룩무늬 알」', 35, true),
    ('onehorn_goat',     '외뿔 팔족염소',     4, 'giant',   'treat_herb',  '외전 「거꾸로 선 기도」를 마친다', 36, false),
    ('little_hongryong', '꼬마 홍룡',         4, 'breaker', 'treat_meat',  '이야기 8장 「재의 바다」를 마친다', 37, false)
  ) as x(pet_id, pet_name, grade, kind, likes, how, sort, egg)
on conflict (pet_id) do update set pet_name = excluded.pet_name, grade = excluded.grade, kind = excluded.kind, likes = excluded.likes, how = excluded.how, sort = excluded.sort, egg = excluded.egg;

insert into public.world_pet_sources(source, pet_id) values
  ('quest:sq_thunder_peak_2', 'golden_wingwolf'),
  ('quest:gq_3', 'onehorn_goat'),
  ('quest:mq_ash_sea', 'little_hongryong')
on conflict do nothing;

-- 범품 바구니 둘(기존 바구니와 같은 값·같은 꼴). 상점 목록에는 모든 안전지대 상점(대장간·반요촌 제외)에 넣고, 회차마다 절반쯤 나온다(world_shop_refresh).
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size)
values
  ('pt_neun_puppy', '네눈박이 강아지 바구니', 'pet', 1, '눈 위의 갈색 점이 눈이 넷인 것처럼 보이는 검둥이 강아지입니다. 공을 던져 주면 지칠 때까지 물어 옵니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).',
   false, '{}'::jsonb, 1, '{"pet": "neun_puppy"}'::jsonb, true, 300, 1),
  ('pt_white_puppy', '흰둥이 강아지 바구니', 'pet', 1, '눈처럼 하얀 털이 보송보송한 강아지입니다. 반가우면 말린 꼬리를 쉬지 않고 흔듭니다. 쓰면 꼬마 동무가 된다(한 종은 한 번만).',
   false, '{}'::jsonb, 1, '{"pet": "white_puppy"}'::jsonb, true, 300, 1)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max, daily_cap)
select s.shop_id, x.item_id, 300, 0, 10, null
  from (select distinct shop_id from public.world_shop_catalog where shop_id not in ('smithy', 'banyo_shop')) s
  cross join (values ('pt_neun_puppy'), ('pt_white_puppy')) as x(item_id)
on conflict (shop_id, item_id) do update set base_price = excluded.base_price;

-- 「모든 동무의 벗」 칭호 글: 서른 → 지금 종 수(판정 n은 30 그대로 — 이미 받은 사람을 지키고, 새 종은 덤)
update public.world_title_catalog set description = '야행국의 꼬마 동무 서른을 만났다.', condition_text = '꼬마 동무 30마리를 모은다'
 where title_key = 'pet_30';

-- ── ② 제보한 조사원에게 주기(스위치 'pet_gift', 처음은 off) ─────────────
create table if not exists public.world_pet_gifts (
  owner_id uuid not null,          -- 계정(auth) id = world_characters.owner_id. 롤백 뒤에도 같다.
  pet_id text not null,
  reporter text,                   -- 제보할 때의 캐릭터 이름(기록용)
  granted_at timestamptz,
  primary key (owner_id, pet_id)
);
alter table public.world_pet_gifts enable row level security;
revoke all on public.world_pet_gifts from anon, authenticated;
grant select, update on public.world_pet_gifts to fn_owner_field;
insert into public.world_pet_gifts(owner_id, pet_id, reporter) values
  ('a6608aa3-c889-4abb-9dab-2be00a9e85b3', 'onehorn_goat', '아도니스'),
  ('fdde20a1-0b69-465b-8113-c5c3e29fba74', 'ash_longhair', '여보'),
  ('f8edc79d-423e-499f-9232-2e67f7e0b6a6', 'spotted_glider', '윤아람'),
  ('71f09a4e-be3f-402b-a241-f3e678f9fc22', 'neun_puppy', '박시현'),
  ('01375cc5-0c6d-493e-b59b-43d0740eb08a', 'golden_wingwolf', '나락'),
  ('eb400e69-ecd9-463e-8c3a-9c072968d778', 'little_ferret', '강산하'),
  ('ea4e4e6b-3a21-4709-95d5-ac33afde971d', 'white_puppy', '조의신'),
  ('ea4e4e6b-3a21-4709-95d5-ac33afde971d', 'little_hongryong', '조의신')
on conflict do nothing;
insert into public.world_app_meta(key, value) values ('pet_gift', 'off') on conflict (key) do nothing;

-- 한 계정에 제보 동무를 준다(스위치가 켜져 있고 캐릭터가 있을 때만, 이미 있으면 world_pet_grant가 건너뜀 — 주먹밥도 주지 않음)
create or replace function public.world_pet_gift_give(p_owner uuid) returns int
language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  if coalesce((select value from public.world_app_meta where key = 'pet_gift'), 'off') <> 'on' then return 0; end if;
  if not exists (select 1 from public.world_characters where owner_id = p_owner) then return 0; end if;
  for r in select g.pet_id, s.pet_name from public.world_pet_gifts g join public.world_pet_species s using (pet_id) where g.owner_id = p_owner loop
    if public.world_pet_grant(p_owner, r.pet_id, 'gift', false) then
      n := n + 1;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (p_owner, 'pet_new', '꼬마 동무 · ' || r.pet_name,
        '제보해 주신 동무 ' || public.world_josa(r.pet_name, '이', '가') || ' 야행국에 왔습니다. 고맙습니다. 별채 화면의 「동무」에서 데리고 다니거나 별채에 둘 수 있습니다.',
        jsonb_build_object('pet_id', r.pet_id, 'gift', true));
    end if;
    update public.world_pet_gifts set granted_at = coalesce(granted_at, now()) where owner_id = p_owner and pet_id = r.pet_id;
  end loop;
  return n;
end $$;
revoke all on function public.world_pet_gift_give(uuid) from public, anon, authenticated;
alter function public.world_pet_gift_give(uuid) owner to fn_owner_field;

-- 켤 때 이미 캐릭터가 있는 계정에 한 번에(운영진이 SQL 편집기에서만 부름)
create or replace function public.world_pet_gift_apply_all() returns int
language plpgsql security definer set search_path = '' as $$
declare n int := 0; o uuid;
begin
  for o in select distinct owner_id from public.world_pet_gifts loop n := n + public.world_pet_gift_give(o); end loop;
  return n;
end $$;
revoke all on function public.world_pet_gift_apply_all() from public, anon, authenticated;
alter function public.world_pet_gift_apply_all() owner to fn_owner_field;

-- 새 캐릭터를 만들면 저절로(스위치 off면 아무것도 안 함, 캐릭터 행은 고치지 않는다)
create or replace function public.trg_world_pet_gift_on_create() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.world_pet_gifts where owner_id = new.owner_id) then
    perform public.world_pet_gift_give(new.owner_id);
  end if;
  return new;
end $$;
revoke all on function public.trg_world_pet_gift_on_create() from public, anon, authenticated;
alter function public.trg_world_pet_gift_on_create() owner to fn_owner_field;
drop trigger if exists trg_world_pet_gift_on_create on public.world_characters;
create trigger trg_world_pet_gift_on_create after insert on public.world_characters
  for each row execute function public.trg_world_pet_gift_on_create();

-- ── ③ 동무 두 자리 ─────────────────────────────
create table if not exists public.world_pet_profile (
  owner_id uuid primary key,
  pet_id text not null,
  set_at timestamptz not null default now()
);
alter table public.world_pet_profile enable row level security;
revoke all on public.world_pet_profile from anon, authenticated;
grant select, insert, update, delete on public.world_pet_profile to fn_owner_field;

-- 옮기기: 데리고 다니던(pet_out) 동무는 프로필 동무로, 그 별채는 빈다(같은 동무는 한 자리에만)
insert into public.world_pet_profile(owner_id, pet_id)
select h.owner_id, h.pet_id from public.world_housing h
 where h.pet_out and h.pet_id is not null and exists (select 1 from public.world_pets p where p.owner_id = h.owner_id and p.pet_id = h.pet_id)
on conflict (owner_id) do nothing;
update public.world_housing set pet_id = null, pet_out = false where pet_out;

-- 조사원 카드·남에게 보이는 프로필 동무(이름·자람)
create or replace function public.world_pet_profile_of(p_owner uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return (select jsonb_build_object('id', f.pet_id, 'nick', p.nickname, 'name', s.pet_name, 'adult', p.affinity >= 100, 'affinity', p.affinity)
            from public.world_pet_profile f
            join public.world_pets p on p.owner_id = f.owner_id and p.pet_id = f.pet_id
            join public.world_pet_species s on s.pet_id = f.pet_id
           where f.owner_id = p_owner);
end $$;
revoke all on function public.world_pet_profile_of(uuid) from public, anon, authenticated;
alter function public.world_pet_profile_of(uuid) owner to fn_owner_field;

-- 프로필 동무 정하기(null이면 비움). 그 동무가 내 별채에 있으면 별채에서 빠진다.
create or replace function public.world_pet_profile_set(p_pet text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); moved boolean := false; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh_pet_slot:' || uid::text));
  if p_pet is null then
    delete from public.world_pet_profile where owner_id = uid;
    return jsonb_build_object('ok', true, 'profile', null, 'content', '데리고 다니던 동무를 쉬게 했습니다.');
  end if;
  select coalesce(p.nickname, s.pet_name) into nm from public.world_pets p join public.world_pet_species s using (pet_id) where p.owner_id = uid and p.pet_id = p_pet;
  if nm is null then raise exception '함께하는 동무가 아닙니다.'; end if;
  update public.world_housing set pet_id = null, pet_out = false, updated_at = now() where owner_id = uid and pet_id = p_pet;
  moved := found;
  insert into public.world_pet_profile(owner_id, pet_id) values (uid, p_pet)
  on conflict (owner_id) do update set pet_id = excluded.pet_id, set_at = now();
  return jsonb_build_object('ok', true, 'profile', p_pet, 'from_house', moved,
    'content', public.world_josa(nm, '과', '와') || ' 함께 다닙니다.' || case when moved then ' 별채는 비었습니다.' else '' end);
end $$;
revoke all on function public.world_pet_profile_set(text) from public, anon;
grant execute on function public.world_pet_profile_set(text) to authenticated;
alter function public.world_pet_profile_set(text) owner to fn_owner_field;

-- 별채 동무 정하기: 프로필 동무였으면 프로필에서 빠진다
create or replace function public.world_pet_place(p_pet text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); moved boolean := false;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh_pet_slot:' || uid::text));
  if p_pet is not null and not exists (select 1 from public.world_pets where owner_id = uid and pet_id = p_pet) then raise exception '함께하는 동무가 아닙니다.'; end if;
  if public.world_housing_home(uid) <> uid then raise exception '함께 쓰는 별채에는 집주인의 동무가 머뭅니다. 내 동무는 데리고 다닐 수 있습니다.'; end if;
  update public.world_housing set pet_id = p_pet, pet_out = false, updated_at = now() where owner_id = uid;
  if not found then raise exception '별채를 얻은 뒤에 동무를 들일 수 있습니다.'; end if;
  if p_pet is not null then
    delete from public.world_pet_profile where owner_id = uid and pet_id = p_pet;
    moved := found;
  end if;
  return jsonb_build_object('ok', true, 'pet_id', p_pet, 'from_profile', moved,
    'content', case when p_pet is null then '별채의 동무를 쉬게 했습니다.' when moved then '데리고 다니던 동무를 별채에 두었습니다.' else '별채에 동무를 두었습니다.' end);
end $$;

-- 옛 「데리고 다니기」(화면이 새로 받기 전 호환): true = 별채 동무를 프로필로, false = 프로필 동무를 빈 별채로 돌려놓기
create or replace function public.world_pet_walk(p_out boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); h public.world_housing%rowtype; f text; has_h boolean;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtext('yh_pet_slot:' || uid::text));
  select * into h from public.world_housing where owner_id = uid for update;
  has_h := found;
  if coalesce(p_out, false) then
    if not has_h or h.pet_id is null then raise exception '먼저 별채에 동무를 들이세요. 동무 창에서 바로 데리고 다닐 수도 있습니다.'; end if;
    insert into public.world_pet_profile(owner_id, pet_id) values (uid, h.pet_id) on conflict (owner_id) do update set pet_id = excluded.pet_id, set_at = now();
    update public.world_housing set pet_id = null, pet_out = false, updated_at = now() where owner_id = uid;
  else
    select pet_id into f from public.world_pet_profile where owner_id = uid;
    if f is null then raise exception '데리고 다니는 동무가 없습니다.'; end if;
    if has_h and h.pet_id is null and public.world_housing_home(uid) = uid then
      update public.world_housing set pet_id = f, pet_out = false, updated_at = now() where owner_id = uid;
    end if;
    delete from public.world_pet_profile where owner_id = uid;
  end if;
  return jsonb_build_object('ok', true, 'pet_out', coalesce(p_out, false));
end $$;

-- 동무 창: profile(프로필 동무) · room(내가 사는 별채가 내 것일 때만 별채 동무) · house(별채 있음) · shared(정인의 별채에 들어가 삶)
create or replace function public.world_pet_snapshot() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); today date := public.world_housing_today(); home uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  home := public.world_housing_home(uid);
  return jsonb_build_object(
    'species', (select coalesce(jsonb_agg(jsonb_build_object('id', s.pet_id, 'name', s.pet_name, 'grade', s.grade, 'kind', s.kind, 'likes', s.likes, 'how', s.how) order by s.sort), '[]'::jsonb) from public.world_pet_species s),
    'mine', (select coalesce(jsonb_agg(jsonb_build_object('id', p.pet_id, 'nick', p.nickname, 'affinity', p.affinity, 'adult', p.affinity >= 100, 'got_at', p.got_at,
        'pat', case when p.pat_day = today then p.pat_n else 0 end, 'play', case when p.play_day = today then p.play_n else 0 end, 'feed', case when p.feed_day = today then p.feed_n else 0 end) order by p.got_at), '[]'::jsonb)
      from public.world_pets p where p.owner_id = uid),
    'profile', (select f.pet_id from public.world_pet_profile f where f.owner_id = uid),
    'house', exists (select 1 from public.world_housing h where h.owner_id = home),
    'shared', home <> uid,
    'room', case when home = uid then (select jsonb_build_object('pet_id', h.pet_id, 'pet_out', false) from public.world_housing h where h.owner_id = uid) end);
end $$;

-- 조사원 카드: 별채가 없어도 프로필 동무를 보인다
select pg_temp.yh_patch('public.world_character_card(uuid)',
  $o$'pet', (select public.world_pet_room(c.owner_id) from public.world_housing hh where hh.owner_id = c.owner_id and hh.pet_out),$o$,
  $n$'pet', public.world_pet_profile_of(c.owner_id),$n$);

grant fn_owner_field to postgres with inherit false, set false;
