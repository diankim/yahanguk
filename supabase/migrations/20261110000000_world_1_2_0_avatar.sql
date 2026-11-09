lock table public.world_characters in access exclusive mode;

create table if not exists public.world_avatars (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  look jsonb not null default '{}'::jsonb,
  home_on boolean not null default true,
  updated_at timestamptz not null default now()
);
create table if not exists public.world_wardrobe (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  look_key text not null,
  got_at timestamptz not null default now(),
  primary key (owner_id, look_key)
);
alter table public.world_avatars enable row level security;
alter table public.world_wardrobe enable row level security;
revoke all on public.world_avatars from public, anon, authenticated;
revoke all on public.world_wardrobe from public, anon, authenticated;

create table if not exists public.world_outfit_designs (
  id bigint generated always as identity primary key,
  origin bigint,
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  author_id uuid not null,
  author_name text not null,
  slot text not null check (slot in ('top', 'bottom')),
  base text not null,
  title text not null default '',
  pal text not null check (pal ~ '^([0-9a-f]{6}){1,8}$'),
  px text not null check (px ~ '^[0-7.]+$'),
  deco text not null default '' check (deco ~ '^([0-9a-f]{6}|[.]{6})*$'),
  giver_id uuid,
  gift_from text,
  created_at timestamptz not null default now(),
  woven_at timestamptz,
  deleted_at timestamptz,
  removed_at timestamptz,
  removed_by uuid
);
create unique index if not exists world_outfit_designs_owner_grp on public.world_outfit_designs (owner_id, (coalesce(origin, id)));
create index if not exists world_outfit_designs_grp on public.world_outfit_designs ((coalesce(origin, id)));
create index if not exists world_outfit_designs_author_day on public.world_outfit_designs (author_id, created_at);
create index if not exists world_outfit_designs_giver_day on public.world_outfit_designs (giver_id, created_at) where giver_id is not null;
create table if not exists public.world_outfit_design_hides (
  viewer_id uuid not null references public.world_characters(owner_id) on delete cascade,
  grp bigint not null,
  hidden boolean not null default true,
  at timestamptz not null default now(),
  primary key (viewer_id, grp)
);
alter table public.world_outfit_designs enable row level security;
alter table public.world_outfit_design_hides enable row level security;
revoke all on public.world_outfit_designs from public, anon, authenticated;
revoke all on public.world_outfit_design_hides from public, anon, authenticated;
grant select, insert, update on public.world_outfit_designs to fn_owner_field;
grant select, insert, update on public.world_outfit_design_hides to fn_owner_field;

create or replace function public.world_avatar_parts()
 returns jsonb language sql immutable
as $f$ select '{"free":{"skins":["deep","fair","tan","warm"],"hair":["buns","calm","cloud","curly","curtain","fluffy","halfup","layered","long","pony","princess","sports","twintail"],"hairColors":["black","brown","chestnut","gold","indigo","peach","red","silver"],"eyes":["cat","dot","droopy","round","sharp","sleepy","smile","sparkle","teary","wink"],"eyeColors":["amber","blue","brown","crimson","dark","jade"],"mouth":["cat","grin","open","pout","small","smile"]},"outfits":{"top:guard":{"slot":"top","name":"쇠미늘 갑옷","grade":1},"top:scout":{"slot":"top","name":"무명 철릭","grade":1},"top:exorcist":{"slot":"top","name":"삼베 도포","grade":1},"top:medic":{"slot":"top","name":"쑥빛 앞치마 도포","grade":1},"top:seal":{"slot":"top","name":"누비 전포","grade":1},"top:shadow":{"slot":"top","name":"먹빛 누비 전포","grade":1},"top:jeogori":{"slot":"top","name":"연분홍 저고리","grade":1},"top:vest":{"slot":"top","name":"무명 조끼","grade":1},"top:magoja":{"slot":"top","name":"짧은 마고자","grade":1},"top:jeoksam":{"slot":"top","name":"짧은 적삼","grade":1},"bottom:guard":{"slot":"bottom","name":"검은 바지와 가죽 장화","grade":1},"bottom:scout":{"slot":"bottom","name":"고동 바지와 미투리","grade":1},"bottom:exorcist":{"slot":"bottom","name":"쪽빛 대님 바지","grade":1},"bottom:medic":{"slot":"bottom","name":"무명 대님 바지","grade":1},"bottom:seal":{"slot":"bottom","name":"검은 바지","grade":1},"bottom:shadow":{"slot":"bottom","name":"먹빛 바지와 짚신","grade":1},"bottom:chima":{"slot":"bottom","name":"남빛 치마","grade":1},"acc:flowerpin":{"slot":"acc","name":"꽃 머리핀","grade":1},"acc:glasses":{"slot":"acc","name":"둥근 안경","grade":1},"acc:earring":{"slot":"acc","name":"구슬 귀걸이","grade":1},"acc:scarf":{"slot":"acc","name":"목도리","grade":1},"acc:norigae":{"slot":"acc","name":"노리개","grade":1},"acc:foxmask":{"slot":"acc","name":"여우 탈","grade":1}},"job":{"artificer":{"top":"guard","bottom":"guard"},"scout":{"top":"scout","bottom":"scout"},"exorcist":{"top":"exorcist","bottom":"exorcist"},"medic":{"top":"medic","bottom":"medic"},"sealmaster":{"top":"seal","bottom":"seal"},"analyst":{"top":"shadow","bottom":"shadow"}},"masks":{"top:guard":{"n":40,"deco":3},"top:scout":{"n":70,"deco":3},"top:exorcist":{"n":79,"deco":3},"top:medic":{"n":46,"deco":3},"top:seal":{"n":42,"deco":3},"top:shadow":{"n":58,"deco":3},"top:jeogori":{"n":35,"deco":3},"top:vest":{"n":28,"deco":3},"top:magoja":{"n":44,"deco":2},"top:jeoksam":{"n":47,"deco":2},"bottom:guard":{"n":20,"deco":1},"bottom:scout":{"n":32,"deco":1},"bottom:exorcist":{"n":30,"deco":2},"bottom:medic":{"n":30,"deco":2},"bottom:seal":{"n":32,"deco":1},"bottom:shadow":{"n":32,"deco":1},"bottom:chima":{"n":64,"deco":1}}}'::jsonb $f$;

create or replace function public.world_avatar_look_clean(p_owner uuid, p_look jsonb)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare l jsonb := p_look; k text; dv text; did bigint;
begin
  if l is null then return null; end if;
  foreach k in array array['top', 'bottom'] loop
    dv := l ->> (k || '_d');
    if dv is null then continue; end if;
    did := null;
    if dv ~ '^[0-9]{1,18}$' then
      select x.id into did from public.world_outfit_designs x
       where x.id = dv::bigint and x.owner_id = p_owner and x.slot = k and x.base = l ->> k and x.woven_at is not null and x.removed_at is null
         and exists (select 1 from public.world_wardrobe w where w.owner_id = p_owner and w.look_key = k || ':@' || x.id);
    end if;
    l := case when did is null then l - (k || '_d') else l || jsonb_build_object(k || '_d', did) end;
  end loop;
  return l;
end $f$;
revoke all on function public.world_avatar_look_clean(uuid, jsonb) from public, anon, authenticated;

create or replace function public.world_avatar_design_ids(p_look jsonb)
 returns bigint[] language sql immutable
as $f$ select array_remove(array[case when p_look ->> 'top_d' ~ '^[0-9]{1,18}$' then (p_look ->> 'top_d')::bigint end, case when p_look ->> 'bottom_d' ~ '^[0-9]{1,18}$' then (p_look ->> 'bottom_d')::bigint end], null) $f$;
revoke all on function public.world_avatar_design_ids(jsonb) from public, anon, authenticated;
grant execute on function public.world_avatar_design_ids(jsonb) to fn_owner_field;

create or replace function public.world_outfit_design_map(p_viewer uuid, p_ids bigint[])
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  if p_viewer is null or p_ids is null or cardinality(p_ids) = 0 then return '{}'::jsonb; end if;
  return (select coalesce(jsonb_object_agg(d.id::text, jsonb_build_object('slot', d.slot, 'base', d.base, 'pal', d.pal, 'px', d.px, 'deco', d.deco)), '{}'::jsonb)
    from public.world_outfit_designs d
   where d.id = any (p_ids) and d.woven_at is not null and d.removed_at is null
     and not exists (select 1 from public.world_outfit_design_hides h where h.viewer_id = p_viewer and h.grp = coalesce(d.origin, d.id) and h.hidden)
     and not public.world_housing_blocked(p_viewer, d.author_id));
end $f$;
revoke all on function public.world_outfit_design_map(uuid, bigint[]) from public, anon, authenticated;
grant execute on function public.world_outfit_design_map(uuid, bigint[]) to fn_owner_field;

create or replace function public.world_avatar_get(p_owner uuid default null)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); who uuid; jk text; a public.world_avatars%rowtype; lk jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  who := coalesce(p_owner, uid);
  select c.job_key into jk from public.world_characters c where c.owner_id = who;
  if not found then raise exception '조사원을 찾을 수 없습니다.'; end if;
  select * into a from public.world_avatars where owner_id = who;
  lk := public.world_avatar_look_clean(who, a.look);
  if who <> uid then
    return jsonb_build_object('look', lk, 'job', jk, 'home_on', coalesce(a.home_on, true), 'designs', public.world_outfit_design_map(uid, public.world_avatar_design_ids(lk)));
  end if;
  return jsonb_build_object('look', lk, 'job', jk, 'home_on', coalesce(a.home_on, true),
    'owned', coalesce((select jsonb_agg(w.look_key order by w.look_key) from public.world_wardrobe w where w.owner_id = uid), '[]'::jsonb),
    'designs', public.world_outfit_design_map(uid, public.world_avatar_design_ids(lk) || coalesce((select array_agg(substr(w.look_key, strpos(w.look_key, '@') + 1)::bigint)
      from public.world_wardrobe w where w.owner_id = uid and w.look_key ~ '^(top|bottom):@[0-9]{1,18}$'), '{}'::bigint[])));
end $f$;

create or replace function public.world_avatar_set(p_look jsonb, p_home_on boolean default null)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); jk text; r jsonb := public.world_avatar_parts(); k text; t text; v text; look jsonb := '{}'::jsonb; dv text; dd public.world_outfit_designs%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select c.job_key into jk from public.world_characters c where c.owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if jsonb_typeof(p_look) is distinct from 'object' then raise exception '모습을 고르세요.'; end if;
  for k, t in select * from (values ('skin', 'skins'), ('hair', 'hair'), ('hair_color', 'hairColors'), ('eyes', 'eyes'), ('eye_color', 'eyeColors'), ('mouth', 'mouth')) x(k, t) loop
    v := p_look ->> k;
    if v is null or not (r -> 'free' -> t ? v) then raise exception '고를 수 없는 모습이 있습니다.'; end if;
    look := look || jsonb_build_object(k, v);
  end loop;
  foreach k in array array['top', 'bottom'] loop
    dv := p_look ->> (k || '_d');
    if dv is not null and dv <> '' then
      if dv !~ '^[0-9]{1,18}$' then raise exception '도안 번호가 올바르지 않습니다.'; end if;
      select * into dd from public.world_outfit_designs x where x.id = dv::bigint and x.owner_id = uid and x.slot = k and x.woven_at is not null and x.removed_at is null;
      if dd.id is null or not exists (select 1 from public.world_wardrobe w where w.owner_id = uid and w.look_key = k || ':@' || dd.id) then
        raise exception '지어서 옷장에 넣은 도안만 입을 수 있습니다.'; end if;
      look := look || jsonb_build_object(k, dd.base, k || '_d', dd.id);
      dd := null;
      continue;
    end if;
    v := p_look ->> k;
    if v is null or not (r -> 'outfits' ? (k || ':' || v)) then raise exception '고를 수 없는 옷이 있습니다.'; end if;
    if v is distinct from (r -> 'job' -> jk ->> k) and not exists (select 1 from public.world_wardrobe w where w.owner_id = uid and w.look_key = k || ':' || v) then
      raise exception '아직 가지지 않은 옷입니다.'; end if;
    look := look || jsonb_build_object(k, v);
  end loop;
  v := coalesce(p_look ->> 'acc', '');
  if v <> '' and not exists (select 1 from public.world_wardrobe w where w.owner_id = uid and w.look_key = 'acc:' || v) then
    raise exception '아직 가지지 않은 장식입니다.'; end if;
  look := look || jsonb_build_object('acc', v);
  insert into public.world_avatars(owner_id, look, home_on) values (uid, look, coalesce(p_home_on, true))
  on conflict (owner_id) do update set look = excluded.look, home_on = coalesce(p_home_on, public.world_avatars.home_on), updated_at = now();
  return jsonb_build_object('ok', true, 'look', look, 'home_on', (select home_on from public.world_avatars where owner_id = uid));
end $f$;

revoke all on function public.world_avatar_parts() from public, anon, authenticated;
revoke all on function public.world_avatar_get(uuid) from public, anon;
revoke all on function public.world_avatar_set(jsonb, boolean) from public, anon;
grant execute on function public.world_avatar_get(uuid) to authenticated;
grant execute on function public.world_avatar_set(jsonb, boolean) to authenticated;

do $p$
declare d text := pg_get_functiondef('public.world_character_purge(uuid)'::regprocedure);
  a text := 'delete from public.world_quickslots where owner_id = p_uid;';
begin
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '캐릭터 정리 함수 모양이 예상과 다릅니다'; end if;
  if position('world_avatars' in d) = 0 then
    execute replace(d, a, a || E'\n  delete from public.world_avatars where owner_id = p_uid;\n  delete from public.world_wardrobe where owner_id = p_uid;\n  delete from public.world_outfit_designs where owner_id = p_uid;\n  delete from public.world_outfit_design_hides where viewer_id = p_uid;');
  end if;
end $p$;

create or replace function public.world_avatar_room(p_owner uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return (select coalesce(jsonb_agg(jsonb_build_object('id', c.owner_id, 'name', c.character_name, 'job', c.job_key, 'look', public.world_avatar_look_clean(c.owner_id, a.look)) order by c.owner_id = p_owner desc), '[]'::jsonb)
    from public.world_characters c left join public.world_avatars a on a.owner_id = c.owner_id
   where c.owner_id in (p_owner, public.world_housing_mate(p_owner)) and coalesce(a.home_on, true));
end $f$;
revoke all on function public.world_avatar_room(uuid) from public, anon, authenticated;
grant execute on function public.world_avatar_room(uuid) to fn_owner_field;

create or replace function public.world_avatar_room_ids(p_owner uuid)
 returns bigint[] language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return (select coalesce(array_agg(x), '{}'::bigint[]) from jsonb_array_elements(public.world_avatar_room(p_owner)) r, unnest(public.world_avatar_design_ids(r -> 'look')) x);
end $f$;
revoke all on function public.world_avatar_room_ids(uuid) from public, anon, authenticated;
grant execute on function public.world_avatar_room_ids(uuid) to fn_owner_field;

do $p$
declare d text := pg_get_functiondef((select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'world_housing_snapshot'));
  a text := $q$'drawings', public.world_drawing_room(uid, h.wall),$q$;
begin
  if position('world_avatar_room' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '별채 정보 함수 모양이 예상과 다릅니다'; end if;
  execute replace(d, a, a || $q$ 'avatars', public.world_avatar_room(own), 'avatar_designs', public.world_outfit_design_map(public.fn_owner_auth_uid(), public.world_avatar_room_ids(own)),$q$);
end $p$;

create or replace function public.world_avatar_look_of(p_owner uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return (select public.world_avatar_look_clean(p_owner, a.look) from public.world_avatars a where a.owner_id = p_owner);
end $f$;
revoke all on function public.world_avatar_look_of(uuid) from public, anon, authenticated;
grant execute on function public.world_avatar_look_of(uuid) to fn_owner_field;

do $p$
declare d text := pg_get_functiondef((select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'world_character_card'));
  a text := $q$'pet', public.world_pet_profile_of(c.owner_id),$q$;
begin
  if position('world_avatar_look_of' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '조사원 카드 함수 모양이 예상과 다릅니다'; end if;
  execute replace(d, a, a || $q$ 'look', public.world_avatar_look_of(c.owner_id), 'look_designs', public.world_outfit_design_map(public.fn_owner_auth_uid(), public.world_avatar_design_ids(public.world_avatar_look_of(c.owner_id))),$q$);
end $p$;

create or replace function public.world_set_avatar_px(p_image text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_image is null or length(p_image) > 40000 or p_image !~ '^data:image/png;base64,[A-Za-z0-9+/]+={0,2}$' then raise exception '얼굴 그림 형식이 올바르지 않습니다.'; end if;
  update public.world_characters set profile = coalesce(profile, '{}'::jsonb) || jsonb_build_object('avatar', p_image, 'avatar_px', true), updated_at = now() where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  return jsonb_build_object('ok', true, 'content', '내 모습을 얼굴로 씁니다.');
end $f$;
revoke all on function public.world_set_avatar_px(text) from public, anon;
grant execute on function public.world_set_avatar_px(text) to authenticated;

do $p$
declare d text := pg_get_functiondef((select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'world_set_avatar'));
  a text := $q$coalesce(profile, '{}'::jsonb) - 'avatar'$q$;
  b text := $q$ELSE coalesce(profile, '{}'::jsonb) || jsonb_build_object('avatar', p_image)$q$;
begin
  if position('avatar_px' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 or (length(d) - length(replace(d, b, ''))) / length(b) <> 1 then raise exception '프로필 사진 함수 모양이 예상과 다릅니다'; end if;
  execute replace(replace(d, a, a || $q$ - 'avatar_px'$q$), b, $q$ELSE (coalesce(profile, '{}'::jsonb) - 'avatar_px') || jsonb_build_object('avatar', p_image)$q$);
end $p$;

alter table public.world_item_catalog drop constraint if exists world_item_catalog_category_check;
alter table public.world_item_catalog add constraint world_item_catalog_category_check check (category = any (array['material', 'consumable', 'equipment', 'tool', 'weapon', 'armor', 'quest', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'furniture', 'pet', 'outfit']));

create or replace function public.world_outfit_rules()
 returns jsonb language sql immutable
as $f$ select '{"box_exp_pct": 2, "box_boss_pct": 1, "box": "of_bundle", "pool": ["of_top_vest", "of_top_jeoksam", "of_acc_scarf", "of_top_jeogori", "of_bottom_chima", "of_acc_norigae", "of_top_magoja", "of_acc_earring", "of_acc_glasses", "of_top_guard", "of_bottom_guard", "of_top_scout", "of_bottom_scout", "of_top_exorcist", "of_bottom_exorcist", "of_top_medic", "of_bottom_medic", "of_top_seal", "of_bottom_seal", "of_top_shadow", "of_bottom_shadow"], "tourney": "acc:foxmask", "design": {"per_day": 2, "keep": 20, "colors": 8, "title_max": 12, "weave": {"top": "r_of_jeogori", "bottom": "r_of_chima"}}}'::jsonb $f$;
revoke all on function public.world_outfit_rules() from public, anon, authenticated;
grant execute on function public.world_outfit_rules() to fn_owner_field;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values
('of_top_vest', '무명 조끼', 'outfit', 1, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 300, 1, '{"look": "top:vest"}'::jsonb),
('of_top_jeoksam', '짧은 적삼', 'outfit', 1, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 350, 1, '{"look": "top:jeoksam"}'::jsonb),
('of_acc_scarf', '목도리', 'outfit', 1, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 400, 1, '{"look": "acc:scarf"}'::jsonb),
('of_top_jeogori', '연분홍 저고리', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 260, 1, '{"look": "top:jeogori"}'::jsonb),
('of_bottom_chima', '남빛 치마', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 320, 1, '{"look": "bottom:chima"}'::jsonb),
('of_acc_norigae', '노리개', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 300, 1, '{"look": "acc:norigae"}'::jsonb),
('of_top_magoja', '짧은 마고자', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 350, 1, '{"look": "top:magoja"}'::jsonb),
('of_acc_earring', '구슬 귀걸이', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 300, 1, '{"look": "acc:earring"}'::jsonb),
('of_acc_glasses', '둥근 안경', 'outfit', 2, '「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 500, 1, '{"look": "acc:glasses"}'::jsonb),
('of_acc_flowerpin', '꽃 머리핀', 'outfit', 2, '객사 별채를 고쳐 준 답례로 받은 머리핀입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, false, 100, 1, '{"look": "acc:flowerpin"}'::jsonb),
('of_top_guard', '쇠미늘 갑옷', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:guard"}'::jsonb),
('of_bottom_guard', '검은 바지와 가죽 장화', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:guard"}'::jsonb),
('of_top_scout', '무명 철릭', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:scout"}'::jsonb),
('of_bottom_scout', '고동 바지와 미투리', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:scout"}'::jsonb),
('of_top_exorcist', '삼베 도포', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:exorcist"}'::jsonb),
('of_bottom_exorcist', '쪽빛 대님 바지', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:exorcist"}'::jsonb),
('of_top_medic', '쑥빛 앞치마 도포', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:medic"}'::jsonb),
('of_bottom_medic', '무명 대님 바지', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:medic"}'::jsonb),
('of_top_seal', '누비 전포', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:seal"}'::jsonb),
('of_bottom_seal', '검은 바지', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:seal"}'::jsonb),
('of_top_shadow', '먹빛 누비 전포', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:shadow"}'::jsonb),
('of_bottom_shadow', '먹빛 바지와 짚신', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:shadow"}'::jsonb),
('of_bundle', '옷 꾸러미', 'outfit', 2, '풀어 보면 옷이나 장신구 하나가 들어 있습니다. 다른 직업의 차림이 나오기도 합니다.', false, true, 400, 1, '{"box": true}'::jsonb)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = 1, equipment_traits = excluded.equipment_traits;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max) values
('capital_market', 'of_top_vest', 300, 0, 5), ('capital_market', 'of_acc_scarf', 400, 0, 5),
('river_market', 'of_top_jeoksam', 350, 0, 5), ('river_market', 'of_top_vest', 300, 0, 5),
('north_market', 'of_acc_scarf', 400, 0, 5), ('north_market', 'of_top_jeoksam', 350, 0, 5),
('south_market', 'of_top_vest', 300, 0, 5), ('south_market', 'of_top_jeoksam', 350, 0, 5)
on conflict do nothing;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, description, minimum_level, recipe_difficulty, craft_field) values
('r_of_jeogori', '연분홍 저고리 짓기', 'of_top_jeogori', 1, '{"silk": 2, "cloud_cotton": 1}', '영사와 운면으로 연분홍 저고리를 짓습니다.', 5, 1, 'weaving'),
('r_of_chima', '남빛 치마 짓기', 'of_bottom_chima', 1, '{"silk": 2, "cloud_cotton": 2}', '영사와 운면으로 남빛 치마를 짓습니다.', 5, 1, 'weaving'),
('r_of_norigae', '노리개 엮기', 'of_acc_norigae', 1, '{"talisman_thread": 2, "silk": 1}', '부적실을 꼬아 노리개를 엮습니다.', 8, 1, 'weaving'),
('r_of_magoja', '짧은 마고자 짓기', 'of_top_magoja', 1, '{"spirit_thread": 1, "silk": 2}', '영사 실타래로 짧은 마고자를 짓습니다.', 10, 2, 'weaving'),
('r_of_earring', '구슬 귀걸이 깎기', 'of_acc_earring', 1, '{"spirit_glass": 1, "ore": 2}', '영유리를 구슬로 깎아 귀걸이를 만듭니다.', 8, 1, 'artifice'),
('r_of_glasses', '둥근 안경 짜기', 'of_acc_glasses', 1, '{"spirit_glass": 2, "ore": 1}', '영유리 알 두 개를 월철 테에 끼웁니다.', 8, 1, 'artifice')
on conflict (recipe_id) do update set ingredients = excluded.ingredients, minimum_level = excluded.minimum_level, output_item = excluded.output_item, craft_field = excluded.craft_field;

update public.world_quest_steps set reward = reward || jsonb_build_object('items', coalesce(reward -> 'items', '{}'::jsonb) || '{"of_acc_flowerpin": 1}'::jsonb)
 where quest_id = 'hs_byeolchae' and step = (select max(step) from public.world_quest_steps where quest_id = 'hs_byeolchae') and not coalesce(reward -> 'items', '{}'::jsonb) ? 'of_acc_flowerpin';
insert into public.world_wardrobe(owner_id, look_key)
select g.owner_id, 'acc:flowerpin' from public.world_quest_progress g join public.world_characters c on c.owner_id = g.owner_id
 where g.quest_id = 'hs_byeolchae' and g.done_at is not null on conflict do nothing;

create or replace function public.world_wardrobe_add(p_item text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; k text; pick text; inv jsonb; r jsonb := public.world_outfit_rules();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select * into it from public.world_item_catalog where item_id = p_item and category = 'outfit';
  if not found then raise exception '옷이 아닙니다.'; end if;
  if coalesce((c.inventory ->> p_item)::int, 0) < 1 then raise exception '가방에 없습니다.'; end if;
  inv := c.inventory;
  inv := case when (inv ->> p_item)::int <= 1 then inv - p_item else jsonb_set(inv, array[p_item], to_jsonb((inv ->> p_item)::int - 1)) end;
  if coalesce((it.equipment_traits ->> 'box')::boolean, false) then
    select x into pick from jsonb_array_elements_text(r -> 'pool') x order by random() limit 1;
    inv := jsonb_set(inv, array[pick], to_jsonb(coalesce((inv ->> pick)::int, 0) + 1));
    update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
    return jsonb_build_object('ok', true, 'item', pick, 'content', '옷 꾸러미를 풀자 ' || public.world_josa((select item_name from public.world_item_catalog where item_id = pick), '이', '가') || ' 나왔습니다.');
  end if;
  k := it.equipment_traits ->> 'look';
  if k is null then raise exception '옷장에 넣을 수 없습니다.'; end if;
  if exists (select 1 from public.world_wardrobe w where w.owner_id = uid and w.look_key = k)
     or (public.world_avatar_parts() -> 'job' -> c.job_key ->> split_part(k, ':', 1)) = split_part(k, ':', 2) then
    raise exception '이미 옷장에 있는 옷입니다. 팔거나 다른 조사원에게 넘길 수 있습니다.';
  end if;
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  insert into public.world_wardrobe(owner_id, look_key) values (uid, k);
  return jsonb_build_object('ok', true, 'look', k, 'content', public.world_josa(it.item_name, '을', '를') || ' 옷장에 넣었습니다. 「내 모습」에서 고를 수 있습니다.');
end $f$;
revoke all on function public.world_wardrobe_add(text) from public, anon;
grant execute on function public.world_wardrobe_add(text) to authenticated;
grant insert on public.world_wardrobe to fn_owner_field;

alter table public.world_bug_reports drop constraint if exists world_bug_reports_category_check;
alter table public.world_bug_reports add constraint world_bug_reports_category_check check (category = any (array['bug', 'screen', 'balance', 'idea', 'review', 'other', 'drawing', 'outfit']));

create or replace function public.world_materials_take(p_inv jsonb, p_st jsonb, p_need jsonb, p_check_only boolean default false)
 returns jsonb language plpgsql stable set search_path to 'pg_catalog', 'public'
as $f$
declare inv jsonb := p_inv; st jsonb := p_st; from_st jsonb := '{}'::jsonb; k text; need int; have int; left_n int; part text; take int;
begin
  for k, need in select key, value::text::int from jsonb_each(p_need) loop
    have := coalesce((inv ->> k)::int, 0) + coalesce((st ->> k)::int, 0) + coalesce((inv ->> (k || '_hq'))::int, 0) + coalesce((st ->> (k || '_hq'))::int, 0);
    if have < need then raise exception '재료 부족: % (필요 %, 보유 %)', coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id = k), k), need, have; end if;
  end loop;
  if p_check_only then return null; end if;
  for k, need in select key, value::text::int from jsonb_each(p_need) loop
    left_n := need;
    foreach part in array array[k, k || '_hq'] loop
      exit when left_n <= 0;
      take := least(left_n, greatest(0, coalesce((inv ->> part)::int, 0)));
      if take > 0 then inv := jsonb_set(inv, array[part], to_jsonb(coalesce((inv ->> part)::int, 0) - take), true); left_n := left_n - take; end if;
      take := least(left_n, greatest(0, coalesce((st ->> part)::int, 0)));
      if take > 0 then st := jsonb_set(st, array[part], to_jsonb(coalesce((st ->> part)::int, 0) - take)); from_st := from_st || jsonb_build_object(part, coalesce((from_st ->> part)::int, 0) + take); left_n := left_n - take; end if;
    end loop;
  end loop;
  inv := (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(inv) where not (jsonb_typeof(value) = 'number' and value::text::numeric <= 0));
  return jsonb_build_object('inv', inv, 'st', st, 'from_st', from_st);
end $f$;
revoke all on function public.world_materials_take(jsonb, jsonb, jsonb, boolean) from public, anon, authenticated;
grant execute on function public.world_materials_take(jsonb, jsonb, jsonb, boolean) to fn_owner_18452, fn_owner_field;
grant execute on function public.world_avatar_parts() to fn_owner_field;

create or replace function public.world_wardrobe_has(p_uid uuid, p_key text)
 returns boolean language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return exists (select 1 from public.world_wardrobe w where w.owner_id = p_uid and w.look_key = p_key);
end $f$;
revoke all on function public.world_wardrobe_has(uuid, text) from public, anon, authenticated;
grant execute on function public.world_wardrobe_has(uuid, text) to fn_owner_field;

create or replace function public.world_outfit_design_list()
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_outfit_rules() -> 'design'; day timestamptz := public.world_drawing_day_start();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return (with mine as (
      select d.*, jsonb_build_object('id', d.id, 'grp', coalesce(d.origin, d.id), 'slot', d.slot, 'base', d.base, 't', d.title, 'pal', d.pal, 'px', d.px, 'deco', d.deco,
        'a', d.author_name, 'mine', d.origin is null, 'gift', d.gift_from, 'woven', d.woven_at is not null, 'at', d.created_at) j
        from public.world_outfit_designs d where d.owner_id = uid and d.removed_at is null)
    select jsonb_build_object(
      'rules', r || jsonb_build_object('give_day', (public.world_drawing_rules() ->> 'give_day')::int),
      'made_today', (select count(*) from public.world_outfit_designs x where x.author_id = uid and x.origin is null and x.created_at >= day),
      'given_today', (select count(*) from public.world_outfit_designs x where x.giver_id = uid and x.created_at >= day),
      'kept', (select count(*) from mine where deleted_at is null),
      'items', coalesce((select jsonb_agg(j order by id desc) from mine where deleted_at is null), '[]'::jsonb),
      'trash', coalesce((select jsonb_agg(j order by deleted_at desc) from mine where deleted_at is not null), '[]'::jsonb)));
end $f$;

create or replace function public.world_outfit_design_save(p_slot text, p_base text, p_title text, p_pal text, p_px text, p_deco text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_outfit_rules() -> 'design'; parts jsonb := public.world_avatar_parts(); m jsonb; o jsonb;
  jk text; nm text; pal text; px text; deco text; t text; nid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  perform pg_advisory_xact_lock(hashtextextended('outfit:' || uid::text, 0));
  select c.job_key, c.character_name into jk, nm from public.world_characters c where c.owner_id = uid;
  if nm is null then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if p_slot is null or p_slot not in ('top', 'bottom') then raise exception '도안을 그릴 옷을 고르세요.'; end if;
  o := parts -> 'outfits' -> (p_slot || ':' || coalesce(p_base, ''));
  m := parts -> 'masks' -> (p_slot || ':' || coalesce(p_base, ''));
  if o is null or m is null or o ->> 'slot' is distinct from p_slot then raise exception '도안 바탕으로 고를 수 없는 옷입니다.'; end if;
  if (parts -> 'job' -> jk ->> p_slot) is distinct from p_base and not public.world_wardrobe_has(uid, p_slot || ':' || p_base) then
    raise exception '옷장에 있는 옷만 도안 바탕으로 고를 수 있습니다.'; end if;
  pal := lower(replace(coalesce(p_pal, ''), '#', ''));
  if pal !~ '^([0-9a-f]{6}){1,8}$' or length(pal) / 6 > (r ->> 'colors')::int then raise exception '색이 올바르지 않습니다.'; end if;
  px := coalesce(p_px, '');
  if char_length(px) <> (m ->> 'n')::int or px !~ '^[0-7.]+$' then raise exception '도안 칸이 올바르지 않습니다.'; end if;
  if px !~ '[0-7]' then raise exception '한 칸 이상 칠해 주세요.'; end if;
  if exists (select 1 from regexp_matches(px, '[0-7]', 'g') x where x[1]::int >= length(pal) / 6) then raise exception '고르지 않은 색으로 칠한 칸이 있습니다.'; end if;
  deco := lower(replace(coalesce(p_deco, ''), '#', ''));
  if char_length(deco) <> 6 * (m ->> 'deco')::int or deco !~ '^([0-9a-f]{6}|[.]{6})*$' then raise exception '장식 색이 올바르지 않습니다.'; end if;
  t := btrim(regexp_replace(coalesce(p_title, ''), '[[:cntrl:]]+', ' ', 'g'));
  if char_length(t) > (r ->> 'title_max')::int then raise exception '도안 이름은 %자까지 쓸 수 있습니다.', r ->> 'title_max'; end if;
  if (select count(*) from public.world_outfit_designs x where x.author_id = uid and x.origin is null and x.created_at >= public.world_drawing_day_start()) >= (r ->> 'per_day')::int then
    raise exception '새 도안은 하루에 %장까지 그릴 수 있습니다.', r ->> 'per_day'; end if;
  if (select count(*) from public.world_outfit_designs x where x.owner_id = uid and x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int then
    raise exception '도안첩이 가득 찼습니다(%장). 안 쓰는 도안을 지운 뒤 그려 주세요.', r ->> 'keep'; end if;
  insert into public.world_outfit_designs (owner_id, author_id, author_name, slot, base, title, pal, px, deco)
  values (uid, uid, nm, p_slot, p_base, t, pal, px, deco) returning id into nid;
  return public.world_outfit_design_list() || jsonb_build_object('saved', nid, 'content', '도안첩에 담았습니다. 옷을 지으면 입을 수 있습니다.');
end $f$;

create or replace function public.world_outfit_design_delete(p_id bigint)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  update public.world_outfit_designs set deleted_at = now() where id = p_id and owner_id = uid and deleted_at is null and removed_at is null;
  if not found then raise exception '도안을 찾을 수 없습니다.'; end if;
  return public.world_outfit_design_list() || jsonb_build_object('content', '도안을 지웠습니다. 이미 지은 옷은 그대로 입을 수 있고, 지운 도안에서 되살릴 수 있습니다.');
end $f$;

create or replace function public.world_outfit_design_restore(p_id bigint)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_outfit_rules() -> 'design'; d public.world_outfit_designs%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('outfit:' || uid::text, 0));
  select * into d from public.world_outfit_designs where id = p_id and owner_id = uid for update;
  if not found or d.deleted_at is null then raise exception '되살릴 도안을 찾을 수 없습니다.'; end if;
  if d.removed_at is not null then raise exception '운영진이 내린 도안은 되살릴 수 없습니다.'; end if;
  if (select count(*) from public.world_outfit_designs x where x.owner_id = uid and x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int then
    raise exception '도안첩이 가득 찼습니다(%장). 다른 도안을 지운 뒤 되살려 주세요.', r ->> 'keep'; end if;
  update public.world_outfit_designs set deleted_at = null where id = d.id;
  return public.world_outfit_design_list() || jsonb_build_object('content', '도안을 되살렸습니다.');
end $f$;

create or replace function public.world_outfit_design_give(p_id bigint, p_target uuid)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_outfit_rules() -> 'design'; d public.world_outfit_designs%rowtype; nm text; tn text; nid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_target is null or p_target = uid then raise exception '받을 사람을 골라 주세요.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('outfit:' || least(uid, p_target)::text, 0));
  perform pg_advisory_xact_lock(hashtextextended('outfit:' || greatest(uid, p_target)::text, 0));
  select * into d from public.world_outfit_designs where id = p_id and owner_id = uid and origin is null and author_id = uid and deleted_at is null and removed_at is null;
  if not found then raise exception '내가 그린 도안만 보낼 수 있습니다.'; end if;
  select character_name into tn from public.world_characters where owner_id = p_target;
  if tn is null then raise exception '알 수 없는 조사원입니다.'; end if;
  if not public.world_housing_friends(uid, p_target) or public.world_housing_blocked(uid, p_target) then raise exception '도안은 친구에게만 보낼 수 있습니다.'; end if;
  if (select count(*) from public.world_outfit_designs x where x.giver_id = uid and x.created_at >= public.world_drawing_day_start()) >= (public.world_drawing_rules() ->> 'give_day')::int then
    raise exception '도안은 하루에 %장까지 보낼 수 있습니다.', public.world_drawing_rules() ->> 'give_day'; end if;
  if exists (select 1 from public.world_outfit_designs x where x.owner_id = p_target and coalesce(x.origin, x.id) = coalesce(d.origin, d.id)) then
    raise exception '%님은 이미 이 도안을 가지고 있습니다(지운 도안 포함).', tn; end if;
  if (select count(*) from public.world_outfit_designs x where x.owner_id = p_target and x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int then
    raise exception '%님의 도안첩이 가득 찼습니다.', tn; end if;
  select character_name into nm from public.world_characters where owner_id = uid;
  insert into public.world_outfit_designs (origin, owner_id, author_id, author_name, slot, base, title, pal, px, deco, giver_id, gift_from)
  values (coalesce(d.origin, d.id), p_target, d.author_id, d.author_name, d.slot, d.base, d.title, d.pal, d.px, d.deco, uid, nm) returning id into nid;
  insert into public.world_notifications (user_id, kind, title, content, payload)
  values (p_target, 'outfit_gift', '도안 선물', nm || '님이 옷 도안' || case when d.title <> '' then ' 「' || d.title || '」' else '' end || '을(를) 보냈습니다. 내 모습 › 내 도안에서 지어 입을 수 있습니다.', jsonb_build_object('from', uid, 'design', nid));
  return jsonb_build_object('ok', true, 'content', tn || '님에게 도안을 보냈습니다.');
end $f$;

create or replace function public.world_outfit_design_weave(p_id bigint)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; d public.world_outfit_designs%rowtype; rc public.world_crafting_recipes%rowtype;
  inv jsonb; st jsonb; mt jsonb; fs jsonb; n int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  perform public.world_travel_guard('옷 짓기');
  perform public.world_seal_guard();
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태입니다. 다른 조사원의 구조를 받아야 행동할 수 있습니다.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  if exists (select 1 from public.world_current_shop(uid)) and not public.world_banyo_here(uid) then select items into st from public.world_storage where owner_id = uid for update; end if;
  st := coalesce(st, '{}'::jsonb);
  select * into d from public.world_outfit_designs where id = p_id and owner_id = uid for update;
  if not found then raise exception '도안을 찾을 수 없습니다.'; end if;
  if d.removed_at is not null then raise exception '운영진이 내린 도안이라 지을 수 없습니다.'; end if;
  if d.deleted_at is not null then raise exception '지운 도안은 지을 수 없습니다. 먼저 되살려 주세요.'; end if;
  if d.woven_at is not null then raise exception '이미 지어 옷장에 넣은 도안입니다.'; end if;
  select * into rc from public.world_crafting_recipes where recipe_id = public.world_outfit_rules() -> 'design' -> 'weave' ->> d.slot;
  if not found then raise exception '옷 짓는 법을 찾을 수 없습니다.'; end if;
  if c.level < rc.minimum_level then raise exception '옷을 지으려면 레벨 %부터 됩니다.', rc.minimum_level; end if;
  mt := public.world_materials_take(inv, st, rc.ingredients);
  inv := mt -> 'inv'; st := mt -> 'st'; fs := mt -> 'from_st';
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  if fs <> '{}'::jsonb then
    update public.world_storage set items = (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(st) where jsonb_typeof(value) = 'number' and value::text::int > 0), updated_at = now() where owner_id = uid;
  end if;
  insert into public.world_wardrobe(owner_id, look_key) values (uid, d.slot || ':@' || d.id) on conflict do nothing;
  get diagnostics n = row_count;
  if n = 0 then raise exception '이미 옷장에 있는 옷입니다.'; end if;
  update public.world_outfit_designs set woven_at = now() where id = d.id;
  return jsonb_build_object('ok', true, 'id', d.id, 'look', d.slot || ':@' || d.id, 'inventory', inv, 'from_storage', fs,
    'content', case when d.title <> '' then '「' || d.title || '」 ' else '' end || '도안으로 옷을 지어 옷장에 넣었습니다.' || case when fs <> '{}'::jsonb then ' · 창고 재료 사용' else '' end);
end $f$;

create or replace function public.world_outfit_design_hide(p_grp bigint)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_outfit_designs x where coalesce(x.origin, x.id) = p_grp) then raise exception '도안을 찾을 수 없습니다.'; end if;
  insert into public.world_outfit_design_hides (viewer_id, grp) values (uid, p_grp)
  on conflict (viewer_id, grp) do update set hidden = true, at = now();
  return jsonb_build_object('ok', true, 'content', '이 도안을 내 화면에서 숨겼습니다.');
end $f$;

create or replace function public.world_outfit_design_report(p_id bigint, p_reason text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); d public.world_outfit_designs%rowtype; v_grp bigint; nm text; why text := btrim(regexp_replace(coalesce(p_reason, ''), '[\x01-\x09\x0b-\x1f\x7f]+', ' ', 'g')); rid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into d from public.world_outfit_designs x where x.id = p_id and x.removed_at is null
     and (x.owner_id = uid or x.id::text in (public.world_avatar_look_of(x.owner_id) ->> 'top_d', public.world_avatar_look_of(x.owner_id) ->> 'bottom_d'));
  if not found then raise exception '도안을 찾을 수 없습니다.'; end if;
  v_grp := coalesce(d.origin, d.id);
  if d.author_id = uid then raise exception '내가 그린 도안은 제보할 수 없습니다.'; end if;
  if char_length(why) > 200 then raise exception '까닭은 200자까지 적을 수 있습니다.'; end if;
  if exists (select 1 from public.world_bug_reports where owner_id = uid and category = 'outfit' and context ->> 'outfit' = v_grp::text) then
    raise exception '이미 제보한 도안입니다. 운영진이 살펴보고 있습니다.'; end if;
  if (select count(*) from public.world_bug_reports where owner_id = uid and created_at > now() - interval '1 hour') >= 5 then
    raise exception '제보는 1시간에 5건까지 보낼 수 있습니다. 잠시 뒤에 보내 주세요.'; end if;
  select character_name into nm from public.world_characters where owner_id = uid;
  insert into public.world_bug_reports (owner_id, character_name, category, title, body, context)
  values (uid, nm, 'outfit', '도안 제보 · ' || d.author_name || case when d.title <> '' then ' 「' || d.title || '」' else '' end,
    case when why = '' then '(까닭을 적지 않음)' else why end, jsonb_build_object('outfit', v_grp, 'author_id', d.author_id, 'author', d.author_name))
  returning report_id into rid;
  insert into public.world_notifications (user_id, kind, title, content, payload)
  select s.owner_id, 'bug_report', '새 제보', coalesce(nm, '조사원') || ': 도안 제보', jsonb_build_object('report_id', rid) from public.world_staff s where s.owner_id <> uid;
  insert into public.world_outfit_design_hides (viewer_id, grp) values (uid, v_grp)
  on conflict (viewer_id, grp) do update set hidden = true, at = now();
  return jsonb_build_object('ok', true, 'content', '운영진에게 알렸습니다. 이 도안은 내 화면에서 숨깁니다.');
end $f$;

create or replace function public.world_outfit_design_remove(p_grp bigint, p_reason text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); d public.world_outfit_designs%rowtype; n int; why text := btrim(coalesce(p_reason, ''));
begin
  if uid is null or not exists (select 1 from public.world_staff where owner_id = uid) then raise exception '운영진만 할 수 있습니다.'; end if;
  select * into d from public.world_outfit_designs x where coalesce(x.origin, x.id) = p_grp order by x.id limit 1;
  if not found then raise exception '도안을 찾을 수 없습니다.'; end if;
  update public.world_outfit_designs set removed_at = now(), removed_by = uid where coalesce(origin, id) = p_grp and removed_at is null;
  get diagnostics n = row_count;
  if n > 0 then
    insert into public.world_notifications (user_id, kind, title, content, payload)
    select d.author_id, 'outfit_removed', '도안이 내려졌습니다', '운영진이 옷 도안' || case when d.title <> '' then ' 「' || d.title || '」' else '' end || '을(를) 내렸습니다. 그 도안으로 지은 옷은 입을 수 없습니다.'
      || case when why <> '' then ' 까닭: ' || left(why, 200) else '' end, jsonb_build_object('outfit', p_grp)
     where exists (select 1 from public.world_characters c where c.owner_id = d.author_id);
  end if;
  return jsonb_build_object('ok', true, 'removed', n, 'content', case when n > 0 then '도안과 사본 ' || n || '장을 내렸습니다.' else '이미 내린 도안입니다.' end);
end $f$;

create or replace function public.world_outfit_design_brief(p_grp bigint)
 returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
  select jsonb_build_object('o', p_grp, 'slot', d.slot, 'base', d.base, 'pal', d.pal, 'px', d.px, 'deco', d.deco, 't', d.title, 'a', d.author_name, 'removed', d.removed_at is not null,
    'copies', (select count(*) from public.world_outfit_designs c where coalesce(c.origin, c.id) = p_grp and c.removed_at is null))
    from (select * from public.world_outfit_designs x where coalesce(x.origin, x.id) = p_grp order by x.removed_at is null desc, x.id limit 1) d
$f$;

revoke all on function public.world_outfit_design_list() from public, anon, authenticated;
revoke all on function public.world_outfit_design_save(text, text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.world_outfit_design_delete(bigint) from public, anon, authenticated;
revoke all on function public.world_outfit_design_restore(bigint) from public, anon, authenticated;
revoke all on function public.world_outfit_design_give(bigint, uuid) from public, anon, authenticated;
revoke all on function public.world_outfit_design_weave(bigint) from public, anon, authenticated;
revoke all on function public.world_outfit_design_hide(bigint) from public, anon, authenticated;
revoke all on function public.world_outfit_design_report(bigint, text) from public, anon, authenticated;
revoke all on function public.world_outfit_design_remove(bigint, text) from public, anon, authenticated;
revoke all on function public.world_outfit_design_brief(bigint) from public, anon, authenticated;
grant execute on function public.world_outfit_design_list() to authenticated;
grant execute on function public.world_outfit_design_save(text, text, text, text, text, text) to authenticated;
grant execute on function public.world_outfit_design_delete(bigint) to authenticated;
grant execute on function public.world_outfit_design_restore(bigint) to authenticated;
grant execute on function public.world_outfit_design_give(bigint, uuid) to authenticated;
grant execute on function public.world_outfit_design_weave(bigint) to authenticated;
grant execute on function public.world_outfit_design_hide(bigint) to authenticated;
grant execute on function public.world_outfit_design_report(bigint, text) to authenticated;
grant execute on function public.world_outfit_design_remove(bigint, text) to authenticated;

grant create on schema public to fn_owner_field;
alter function public.world_outfit_design_list() owner to fn_owner_field;
alter function public.world_outfit_design_save(text, text, text, text, text, text) owner to fn_owner_field;
alter function public.world_outfit_design_delete(bigint) owner to fn_owner_field;
alter function public.world_outfit_design_restore(bigint) owner to fn_owner_field;
alter function public.world_outfit_design_give(bigint, uuid) owner to fn_owner_field;
alter function public.world_outfit_design_weave(bigint) owner to fn_owner_field;
alter function public.world_outfit_design_hide(bigint) owner to fn_owner_field;
alter function public.world_outfit_design_report(bigint, text) owner to fn_owner_field;
alter function public.world_outfit_design_remove(bigint, text) owner to fn_owner_field;
alter function public.world_outfit_design_brief(bigint) owner to fn_owner_field;
revoke create on schema public from fn_owner_field;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[], p_n int) returns void language plpgsql as $x$
declare d text; i int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if position(p_pairs[2 * i] in d) > 0 then return; end if;
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> p_n then raise exception '함수 % 모양이 예상과 다릅니다', p_name; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $x$;

select pg_temp.yh_fix('world_expedition_complete', array[
$q$if e.settled_rounds >= total_rounds and ended = 'complete' and e.node_id is not null$q$,
$q$if e.settled_rounds >= total_rounds and ended = 'complete' and random() * 100 < (public.world_outfit_rules() ->> 'box_exp_pct')::numeric then
      loot := public.world_inv_add(loot, public.world_outfit_rules() ->> 'box', 1);
      lg := lg || jsonb_build_array('길가에 떨어진 옷 꾸러미 하나를 주웠습니다.');
    end if;
    if e.settled_rounds >= total_rounds and ended = 'complete' and e.node_id is not null$q$], 1);

select pg_temp.yh_fix('world_event_char_apply', array[
$q$  if hp_tick = 0 and mn_tick = 0 and tok = 0 and xp_e = 0$q$,
$q$  if k = 'combat' and won and rare is null and p ->> 'rank' = 'guardian' and random() * 100 < (public.world_outfit_rules() ->> 'box_boss_pct')::numeric then rare := public.world_outfit_rules() ->> 'box'; end if;
  if hp_tick = 0 and mn_tick = 0 and tok = 0 and xp_e = 0$q$], 1);

select pg_temp.yh_fix('world_tourney_finish', array[
$q$on conflict do nothing;
    select count(*) into nchamp$q$,
$q$on conflict do nothing;
    insert into public.world_wardrobe(owner_id, look_key) values (u, public.world_outfit_rules() ->> 'tourney') on conflict do nothing;
    select count(*) into nchamp$q$], 1);

select pg_temp.yh_fix('world_craft_item', array[
$q$  cs_pct numeric; cx_pct numeric;
begin$q$,
$q$  cs_pct numeric; cx_pct numeric; use_n jsonb; mt jsonb;
begin$q$,
$q$  -- 재료: 기본 물품 + 우수품(가방·창고)을 함께 센다
  for k, need in select key, value::text::int from jsonb_each(r.ingredients) loop
    have := coalesce((inv ->> k)::int, 0) + coalesce((st ->> k)::int, 0) + coalesce((inv ->> (k || '_hq'))::int, 0) + coalesce((st ->> (k || '_hq'))::int, 0);
    if have < need then raise exception '재료 부족: % (필요 %, 보유 %)', coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id = k), k), need, have; end if;
  end loop;
$q$,
$q$  perform public.world_materials_take(inv, st, r.ingredients, true);
$q$,
$q$    for k, need in select key, value::text::int from jsonb_each(r.ingredients) loop
      -- 약재 바탕 아끼기(연금 24b): 약제 바탕·농축 약초액은 30% 쓰지 않는다
      if line = 'alchemy' and 'alchemy_c24b' = any (sk) and k in ('medicine_base', 'herbal_extract') and random() < 0.30 then
        notes := notes || ('「약재 바탕 아끼기」 ' || coalesce((select item_name from public.world_item_catalog where item_id = k), '재료') || '을(를) 아꼈습니다'); continue;
      end if;
      left_n := need;
      -- 기본 먼저(가방 → 창고), 모자라면 우수품(가방 → 창고)
      foreach part in array array[k, k || '_hq'] loop
        exit when left_n <= 0;
        take := least(left_n, greatest(0, coalesce((inv ->> part)::int, 0)));
        if take > 0 then inv := jsonb_set(inv, array[part], to_jsonb(coalesce((inv ->> part)::int, 0) - take), true); left_n := left_n - take; end if;
        take := least(left_n, greatest(0, coalesce((st ->> part)::int, 0)));
        if take > 0 then st := jsonb_set(st, array[part], to_jsonb(coalesce((st ->> part)::int, 0) - take)); from_st := from_st || jsonb_build_object(part, coalesce((from_st ->> part)::int, 0) + take); left_n := left_n - take; end if;
      end loop;
    end loop;
    inv := (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(inv) where not (jsonb_typeof(value) = 'number' and value::text::numeric <= 0));
$q$,
$q$    use_n := '{}'::jsonb;
    for k, need in select key, value::text::int from jsonb_each(r.ingredients) loop
      if line = 'alchemy' and 'alchemy_c24b' = any (sk) and k in ('medicine_base', 'herbal_extract') and random() < 0.30 then
        notes := notes || ('「약재 바탕 아끼기」 ' || coalesce((select item_name from public.world_item_catalog where item_id = k), '재료') || '을(를) 아꼈습니다'); continue;
      end if;
      use_n := use_n || jsonb_build_object(k, need);
    end loop;
    mt := public.world_materials_take(inv, st, use_n);
    inv := mt -> 'inv'; st := mt -> 'st'; from_st := mt -> 'from_st';
$q$], 1);

select pg_temp.yh_fix('world_notify_group', array[
$q$'pet_new', 'drawing_gift') then 'housing'$q$,
$q$'pet_new', 'drawing_gift', 'outfit_gift') then 'housing'$q$], 1);

select pg_temp.yh_fix('world_bug_report_list', array[
$q$'drawing', case when (select is_gm from gm) and r.category = 'drawing' then public.world_drawing_brief((r.context ->> 'drawing')::bigint) end,$q$,
$q$'drawing', case when (select is_gm from gm) and r.category = 'drawing' then public.world_drawing_brief((r.context ->> 'drawing')::bigint) end, 'outfit', case when (select is_gm from gm) and r.category = 'outfit' then public.world_outfit_design_brief((r.context ->> 'outfit')::bigint) end,$q$], 1);

update public.world_app_meta set value = '20261110000000' where key = 'db_version';
