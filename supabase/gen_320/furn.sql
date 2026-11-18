create or replace function pg_temp.yh_setjson(p_fn regprocedure, p_j jsonb) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); body text := (select prosrc from pg_proc where oid = p_fn);
begin
  if position(body in src) = 0 then raise exception 'yh_setjson %: 본문을 못 찾음', p_fn; end if;
  execute replace(src, body, ' select ' || quote_literal(p_j::text) || '::jsonb ');
end $f$;

create or replace function public.world_furn_rules() returns jsonb language sql immutable set search_path = '' as $$
  select '{"item": "furn_pattern", "keep": 20, "colors": 16, "title_max": 12, "name": "직접 그린 가구", "tier": 2,
    "sizes": {"1x1": {"w": 1, "d": 1, "pw": 32, "ph": 56}, "2x1": {"w": 2, "d": 1, "pw": 48, "ph": 64}, "2x2": {"w": 2, "d": 2, "pw": 64, "ph": 72}},
    "layers": ["floor", "rug"], "tops": [0, 0.42, 0.92, 1.6], "pets": ["bed", "bowl", "toy", "perch"],
    "mats": {"lumber": 2, "lacquer": 1}}'::jsonb
$$;
grant execute on function public.world_furn_rules() to authenticated;

insert into public.world_item_catalog (item_id, item_name, category, tier, description, stackable, stack_size, tradeable, reference_price, equipment_traits, acquisition_difficulty, drop_rate_modifier)
values ('furn_pattern', '가구 그리기 도안', 'consumable', 4, '비장고 깊은 곳에서 나온, 빈 칸에 먹선으로 바닥 마름모만 그려진 도안. 가구를 직접 그려 도안첩에 담을 때 바닥 칸 하나에 한 장씩 쓴다(1×1 한 장·2×1 두 장·2×2 네 장). 담은 도안은 목공 재료로 지어 별채 곳간에 넣는다.',
  true, 20, true, 1500, '{"furn_pattern": true}'::jsonb, 4, 0.2)
on conflict (item_id) do nothing;

alter table public.world_outfit_designs add column if not exists furn jsonb;
alter table public.world_outfit_designs drop constraint world_outfit_designs_slot_check;
alter table public.world_outfit_designs add constraint world_outfit_designs_slot_check check (slot = any (array['top', 'bottom', 'face', 'hair', 'furn']));

select pg_temp.yh_fix('world_design_clean', array[
  E'  else\n    raise exception ''도안을 그릴 곳을 고르세요.'';',
  E'  elsif p_slot = ''furn'' then
    m := public.world_furn_rules() -> ''sizes'' -> coalesce(p_base, '''');
    if m is null then raise exception ''가구 크기를 고르세요.''; end if;
    pal := lower(replace(coalesce(p_pal, ''''), ''#'', ''''));
    if pal !~ ''^([0-9a-f]{6}){1,16}$'' or length(pal) / 6 > (public.world_furn_rules() ->> ''colors'')::int then raise exception ''색이 올바르지 않습니다.''; end if;
    px := coalesce(p_px, '''');
    if char_length(px) not in ((m ->> ''pw'')::int * (m ->> ''ph'')::int, 2 * (m ->> ''pw'')::int * (m ->> ''ph'')::int) or px !~ ''^[0-9a-f.]+$'' then raise exception ''도안 칸이 올바르지 않습니다.''; end if;
    if px !~ ''[0-9a-f]'' then raise exception ''한 칸 이상 칠해 주세요.''; end if;
    if exists (select 1 from regexp_matches(px, ''[0-9a-f]'', ''g'') x where (''x'' || lpad(x[1], 8, ''0''))::bit(32)::int >= length(pal) / 6) then raise exception ''고르지 않은 색으로 칠한 칸이 있습니다.''; end if;
    t := btrim(regexp_replace(coalesce(p_title, ''''), ''[[:cntrl:]]+'', '' '', ''g''));
    if char_length(t) > (public.world_furn_rules() ->> ''title_max'')::int then raise exception ''도안 이름은 %자까지 쓸 수 있습니다.'', public.world_furn_rules() ->> ''title_max''; end if;
  else
    raise exception ''도안을 그릴 곳을 고르세요.'';'
]);

create or replace function public.world_furn_attr(p_size text, p_attr jsonb) returns jsonb
language plpgsql stable set search_path = '' as $f$
declare r jsonb := public.world_furn_rules(); ly text := coalesce(p_attr ->> 'layer', 'floor'); tp numeric := 0; pt text := nullif(p_attr ->> 'pet', ''); pk text := nullif(p_attr ->> 'pk', '');
begin
  if r -> 'sizes' -> coalesce(p_size, '') is null then raise exception '가구 크기를 고르세요.'; end if;
  if not (r -> 'layers') ? ly then raise exception '가구 종류가 올바르지 않습니다.'; end if;
  if jsonb_typeof(p_attr -> 'top') = 'number' then tp := (p_attr ->> 'top')::numeric; end if;
  if not exists (select 1 from jsonb_array_elements_text(r -> 'tops') x where x::numeric = tp) then raise exception '윗면 높이가 올바르지 않습니다.'; end if;
  if ly = 'rug' and tp > 0 then raise exception '깔개에는 윗면을 둘 수 없습니다.'; end if;
  if pt is not null and not (r -> 'pets') ? pt then raise exception '동무 쓰임이 올바르지 않습니다.'; end if;
  if pt = 'perch' and tp = 0 then raise exception '횃대는 윗면 높이를 골라야 동무가 올라앉습니다.'; end if;
  if pk is not null and (pt is null or not exists (select 1 from public.world_monster_kinds k where k.kind_key = pk)) then raise exception '좋아하는 갈래가 올바르지 않습니다.'; end if;
  return jsonb_strip_nulls(jsonb_build_object('layer', ly, 'top', tp, 'pet', pt, 'pk', pk));
end $f$;
revoke all on function public.world_furn_attr(text, jsonb) from public, anon, authenticated;
select pg_temp.yh_own('public.world_furn_attr(text, jsonb)', 'fn_owner_field');

create or replace function public.world_furn_item(p_grp bigint) returns text
language plpgsql security definer set search_path = '' as $f$
declare d public.world_outfit_designs%rowtype; r jsonb := public.world_furn_rules(); m jsonb; k text := 'fd' || p_grp; a jsonb;
begin
  select * into d from public.world_outfit_designs where id = p_grp and origin is null and slot = 'furn';
  if not found then raise exception '도안을 찾을 수 없습니다.'; end if;
  m := r -> 'sizes' -> d.base; a := coalesce(d.furn, '{}'::jsonb);
  insert into public.world_item_catalog (item_id, item_name, category, tier, description, stackable, stack_size, tradeable, reference_price, equipment_traits)
  values ('hf_' || k, coalesce(nullif(d.title, ''), r ->> 'name'), 'furniture', (r ->> 'tier')::int, d.author_name || '이(가) 직접 그린 가구.', false, 1, false, 0,
    jsonb_strip_nulls(jsonb_build_object('hk', k, 'kind', a ->> 'layer', 'w', (m ->> 'w')::int, 'd', (m ->> 'd')::int, 'top', nullif((a ->> 'top')::numeric, 0),
      'pet', a ->> 'pet', 'petKind', a ->> 'pk', 'cat', '직접 그림', 'fd', p_grp)))
  on conflict (item_id) do update set item_name = excluded.item_name;
  return 'hf_' || k;
end $f$;
revoke all on function public.world_furn_item(bigint) from public, anon, authenticated;
grant execute on function public.world_furn_item(bigint) to fn_owner_field;

create or replace function public.world_furn_title_sync() returns trigger
language plpgsql security definer set search_path = '' as $f$
begin
  if new.slot = 'furn' and new.origin is null and new.title is distinct from old.title then
    update public.world_item_catalog set item_name = coalesce(nullif(new.title, ''), public.world_furn_rules() ->> 'name') where item_id = 'hf_fd' || new.id;
  end if;
  return new;
end $f$;
revoke all on function public.world_furn_title_sync() from public, anon, authenticated;
drop trigger if exists trg_world_furn_title_sync on public.world_outfit_designs;
create trigger trg_world_furn_title_sync after update of title on public.world_outfit_designs for each row execute function public.world_furn_title_sync();

create or replace function public.world_furn_design_save(p_size text, p_attr jsonb, p_title text, p_pal text, p_px text) returns jsonb
language plpgsql security definer set search_path = 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_furn_rules(); o jsonb; a jsonb; nm text; inv jsonb; need int; have int; nid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  perform pg_advisory_xact_lock(hashtextextended('outfit:' || uid::text, 0));
  select c.character_name, c.inventory into nm, inv from public.world_characters c where c.owner_id = uid for update;
  if nm is null then raise exception '캐릭터를 먼저 만드세요.'; end if;
  o := public.world_design_clean('furn', p_size, p_title, p_pal, p_px, '');
  a := public.world_furn_attr(p_size, coalesce(p_attr, '{}'::jsonb));
  if (select count(*) from public.world_outfit_designs x where x.owner_id = uid and x.slot = 'furn' and x.deleted_at is null and x.removed_at is null) >= (r ->> 'keep')::int then
    raise exception '가구 도안은 %장까지 둘 수 있습니다. 안 쓰는 도안을 지운 뒤 그려 주세요.', r ->> 'keep'; end if;
  need := (r -> 'sizes' -> p_size ->> 'w')::int * (r -> 'sizes' -> p_size ->> 'd')::int;
  have := coalesce((inv ->> (r ->> 'item'))::int, 0);
  if have < need then raise exception '가구 그리기 도안이 %장 있어야 이 크기를 그릴 수 있습니다. (가방에 %장)', need, have; end if;
  update public.world_characters c set inventory = case when have - need <= 0 then c.inventory - (r ->> 'item') else jsonb_set(c.inventory, array[r ->> 'item'], to_jsonb(have - need)) end, updated_at = now() where c.owner_id = uid;
  insert into public.world_outfit_designs (owner_id, author_id, author_name, slot, base, title, pal, px, deco, furn)
  values (uid, uid, nm, 'furn', p_size, o ->> 't', o ->> 'pal', o ->> 'px', '', a) returning id into nid;
  return public.world_outfit_design_list() || jsonb_build_object('saved', nid, 'content', '가구 도안을 담았습니다. 가구 그리기 도안 ' || need || '장을 썼고, 도안첩에서 지으면 별채 곳간에 들어갑니다.');
end $f$;
revoke all on function public.world_furn_design_save(text, jsonb, text, text, text) from public, anon;
grant execute on function public.world_furn_design_save(text, jsonb, text, text, text) to authenticated;
select pg_temp.yh_own('public.world_furn_design_save(text, jsonb, text, text, text)', 'fn_owner_field');

create or replace function public.world_furn_weave(p_id bigint, p_n integer default 1) returns jsonb
language plpgsql security definer set search_path = 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_furn_rules(); c public.world_characters%rowtype; d public.world_outfit_designs%rowtype; s public.world_housing_store%rowtype;
  hm uuid; why text; inv jsonb; st jsonb; mt jsonb; fs jsonb; need jsonb; tiles int; it text; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_n is null or p_n < 1 or p_n > 10 then raise exception '한 번에 1~10개까지 지을 수 있습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  perform public.world_travel_guard('가구 짓기');
  perform public.world_seal_guard();
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태입니다. 다른 조사원의 구조를 받아야 행동할 수 있습니다.'; end if;
  hm := public.world_housing_home(uid);
  if not exists (select 1 from public.world_housing where owner_id = hm) then raise exception '별채를 얻은 뒤에 가구를 지을 수 있습니다.'; end if;
  why := public.world_housing_edit_block(uid);
  if why is not null then raise exception '%', replace(why, '별채를 고칠', '가구를 지을'); end if;
  select * into d from public.world_outfit_designs where id = p_id and owner_id = uid for update;
  if not found or d.slot <> 'furn' then raise exception '가구 도안을 찾을 수 없습니다.'; end if;
  if d.removed_at is not null then raise exception '운영진이 내린 도안이라 지을 수 없습니다.'; end if;
  if d.deleted_at is not null then raise exception '지운 도안은 지을 수 없습니다. 먼저 되살려 주세요.'; end if;
  if exists (select 1 from public.world_outfit_designs x where x.id = coalesce(d.origin, d.id) and x.removed_at is not null) then raise exception '운영진이 내린 도안이라 지을 수 없습니다.'; end if;
  tiles := (r -> 'sizes' -> d.base ->> 'w')::int * (r -> 'sizes' -> d.base ->> 'd')::int;
  need := (select jsonb_object_agg(key, value::int * tiles * p_n) from jsonb_each_text(r -> 'mats'));
  inv := coalesce(c.inventory, '{}'::jsonb);
  if exists (select 1 from public.world_current_shop(uid)) and not public.world_weak_here(uid, 'storage') then select items into st from public.world_storage where owner_id = uid for update; end if;
  st := coalesce(st, '{}'::jsonb);
  insert into public.world_housing_store(owner_id) values (hm) on conflict (owner_id) do nothing;
  select * into s from public.world_housing_store where owner_id = hm for update;
  if public.world_housing_store_count(s.items) + p_n > public.world_housing_store_cap_of(hm) then raise exception '곳간이 가득 찼습니다. (곳간 %칸)', public.world_housing_store_cap_of(hm); end if;
  mt := public.world_materials_take(inv, st, need);
  inv := mt -> 'inv'; st := mt -> 'st'; fs := mt -> 'from_st';
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  if fs <> '{}'::jsonb then
    update public.world_storage set items = (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(st) where jsonb_typeof(value) = 'number' and value::text::int > 0), updated_at = now() where owner_id = uid;
  end if;
  it := public.world_furn_item(coalesce(d.origin, d.id));
  update public.world_housing_store set items = public.world_inv_add(items, it, p_n), updated_at = now() where owner_id = hm;
  if hm <> uid then perform public.world_housing_contrib(hm, it, p_n); end if;
  update public.world_outfit_designs set woven_at = coalesce(woven_at, now()) where id = d.id;
  select item_name into nm from public.world_item_catalog where item_id = it;
  return jsonb_build_object('ok', true, 'id', d.id, 'item', it, 'n', p_n, 'inventory', inv, 'from_storage', fs,
    'content', '「' || nm || '」 ' || p_n || '개를 지어 별채 곳간에 넣었습니다.' || case when fs <> '{}'::jsonb then ' · 창고 재료 사용' else '' end);
end $f$;
revoke all on function public.world_furn_weave(bigint, integer) from public, anon;
grant execute on function public.world_furn_weave(bigint, integer) to authenticated;
select pg_temp.yh_own('public.world_furn_weave(bigint, integer)', 'fn_owner_field');

create or replace function public.world_furn_room(p_home uuid, p_viewer uuid, p_keys text[]) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(k.k, jsonb_strip_nulls(jsonb_build_object('name', i.item_name, 'W', (i.equipment_traits ->> 'w')::int, 'D', (i.equipment_traits ->> 'd')::int,
      'layer', i.equipment_traits ->> 'kind', 'top', (i.equipment_traits ->> 'top')::numeric, 'pet', i.equipment_traits ->> 'pet', 'pk', i.equipment_traits ->> 'petKind')
    || case when d.id is null or d.removed_at is not null or coalesce(h.hidden, false) then jsonb_build_object('gone', true)
       else jsonb_build_object('a', d.author_name, 'grp', d.id, 'size', d.base, 'pal', d.pal, 'px', d.px) end)), '{}'::jsonb)
  from unnest(p_keys) k(k)
  join public.world_item_catalog i on i.item_id = 'hf_' || k.k
  left join public.world_outfit_designs d on d.id = substr(k.k, 3)::bigint and d.slot = 'furn' and d.origin is null
  left join public.world_outfit_design_hides h on h.viewer_id = p_viewer and h.grp = d.id
  where k.k ~ '^fd[0-9]+$'
$$;
revoke all on function public.world_furn_room(uuid, uuid, text[]) from public, anon, authenticated;
select pg_temp.yh_own('public.world_furn_room(uuid, uuid, text[])', 'fn_owner_field');

create or replace function public.world_furn_keys(p_items jsonb, p_store jsonb) returns text[]
language sql immutable set search_path = '' as $$
  select coalesce(array_agg(distinct k), '{}') from (
    select x ->> 'k' k from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) x where x ->> 'k' ~ '^fd[0-9]+$'
    union select substr(key, 4) from jsonb_object_keys(coalesce(p_store, '{}'::jsonb)) key where key ~ '^hf_fd[0-9]+$') z
$$;
revoke all on function public.world_furn_keys(jsonb, jsonb) from public, anon, authenticated;
select pg_temp.yh_own('public.world_furn_keys(jsonb, jsonb)', 'fn_owner_field');

select pg_temp.yh_fix('world_housing_snapshot', array[
  E'''drawings'', public.world_drawing_room(uid, h.wall),',
  E'''drawings'', public.world_drawing_room(uid, h.wall), ''furns'', public.world_furn_room(own, uid, public.world_furn_keys(h.items, case when role is not null then store end)),'
]);

select pg_temp.yh_fix('world_housing_store_move', array[
  E'  if p_dir = ''take'' then\n    room :=',
  E'  if p_dir = ''take'' and p_item ~ ''^hf_fd[0-9]+$'' then raise exception ''직접 그린 가구는 곳간에만 둡니다. 별채 꾸미기에서 바로 놓을 수 있습니다.''; end if;\n  if p_dir = ''take'' then\n    room :='
]);

select pg_temp.yh_fix('world_outfit_design_report', array[
  E'''hair_d''));',
  E'''hair_d'')\n          or (x.slot = ''furn'' and x.origin is null and exists (select 1 from public.world_item_catalog i where i.item_id = ''hf_fd'' || x.id)));'
]);

select pg_temp.yh_fix('world_outfit_design_weave', array[
  E'if d.slot in (''face'', ''hair'') then raise exception',
  E'if d.slot = ''furn'' then raise exception ''가구 도안은 가구 짓기로 짓습니다.''; end if;\n  if d.slot in (''face'', ''hair'') then raise exception'
]);

select pg_temp.yh_fix('world_outfit_design_give', array[
  E'(case when d.slot = ''hair'' then x.slot = ''hair'' else x.slot in (''top'', ''bottom'') end)',
  E'(case when d.slot in (''hair'', ''furn'') then x.slot = d.slot else x.slot in (''top'', ''bottom'') end)',
  E'>= (case when d.slot = ''hair'' then (r -> ''hair'' ->> ''keep'')::int else (r ->> ''keep'')::int end) then',
  E'>= (case when d.slot = ''hair'' then (r -> ''hair'' ->> ''keep'')::int when d.slot = ''furn'' then (public.world_furn_rules() ->> ''keep'')::int else (r ->> ''keep'')::int end) then',
  E'insert into public.world_outfit_designs (origin, owner_id, author_id, author_name, slot, base, title, pal, px, deco, giver_id, gift_from, woven_at)\n  values (coalesce(d.origin, d.id), p_target, d.author_id, d.author_name, d.slot, d.base, d.title, d.pal, d.px, d.deco, uid, nm, case when d.slot = ''hair'' then now() end)',
  E'insert into public.world_outfit_designs (origin, owner_id, author_id, author_name, slot, base, title, pal, px, deco, giver_id, gift_from, woven_at, furn)\n  values (coalesce(d.origin, d.id), p_target, d.author_id, d.author_name, d.slot, d.base, d.title, d.pal, d.px, d.deco, uid, nm, case when d.slot = ''hair'' then now() end, d.furn)',
  E'case when d.slot = ''hair'' then ''머리'' else ''옷'' end || '' 도안''',
  E'case d.slot when ''hair'' then ''머리'' when ''furn'' then ''가구'' else ''옷'' end || '' 도안''',
  E'|| case when d.slot = ''hair'' then ''내 모습 › 머리에서 바로 쓸 수 있습니다.'' else',
  E'|| case when d.slot = ''hair'' then ''내 모습 › 머리에서 바로 쓸 수 있습니다.'' when d.slot = ''furn'' then ''별채 › 가구 도안에서 지어 놓을 수 있습니다.'' else'
]);

select pg_temp.yh_fix('world_outfit_design_restore', array[
  E'  if d.slot in (''face'', ''hair'') then',
  E'  if d.slot = ''furn'' then
    if (select count(*) from public.world_outfit_designs x where x.owner_id = uid and x.slot = ''furn'' and x.deleted_at is null and x.removed_at is null) >= (public.world_furn_rules() ->> ''keep'')::int then
      raise exception ''가구 도안은 %장까지 둘 수 있습니다. 다른 도안을 지운 뒤 되살려 주세요.'', public.world_furn_rules() ->> ''keep''; end if;
  elsif d.slot in (''face'', ''hair'') then'
]);

select pg_temp.yh_fix('world_outfit_design_delete', array[
  E'    else ''도안을 지웠습니다. 이미 지은 옷은',
  E'    when sl = ''furn'' then ''도안을 지웠습니다. 이미 지은 가구는 그대로 두고, 지운 도안에서 되살릴 수 있습니다.''\n    else ''도안을 지웠습니다. 이미 지은 옷은'
]);

select pg_temp.yh_fix('world_outfit_design_edit', array[
  E'case d.slot when ''face'' then ''눈·입 도안을 고쳤습니다.''',
  E'case d.slot when ''face'' then ''눈·입 도안을 고쳤습니다.'' when ''furn'' then ''가구 도안을 고쳤습니다. 이미 지은 가구도 고친 모습으로 바뀝니다.'''
]);

select pg_temp.yh_fix('world_outfit_design_list', array[
  E'''deco'', d.deco,\n',
  E'''deco'', d.deco, ''furn'', d.furn,\n',
  E'''hair_items'',',
  E'''furns'', (select count(*) from mine where slot = ''furn'' and deleted_at is null),
      ''furn_items'', coalesce((select (c.inventory ->> (public.world_furn_rules() ->> ''item''))::int from public.world_characters c where c.owner_id = uid), 0),
      ''furn_rules'', public.world_furn_rules(),
      ''hair_items'','
]);

select pg_temp.yh_setjson('public.world_bijang_rules()'::regprocedure, jsonb_set(jsonb_set(jsonb_set(public.world_bijang_rules(),
  '{final,tiers,1}', (public.world_bijang_rules() #> '{final,tiers,1}') || '[{"id": "furn_pattern", "n": 1, "w": 4}]'::jsonb),
  '{final,tiers,2}', (public.world_bijang_rules() #> '{final,tiers,2}') || '[{"id": "furn_pattern", "n": 2, "w": 4}]'::jsonb),
  '{final,tiers,3}', (public.world_bijang_rules() #> '{final,tiers,3}') || '[{"id": "furn_pattern", "n": 4, "w": 4}]'::jsonb));
