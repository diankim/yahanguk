create or replace function public.world_portrait_have(p_uid uuid, p_item text) returns int
language plpgsql stable security definer set search_path = pg_catalog, public as $f$
declare hm uuid := public.world_housing_home(p_uid); n int := 0;
begin
  n := n + coalesce((select (c.inventory ->> p_item)::int from public.world_characters c where c.owner_id = p_uid), 0);
  n := n + coalesce((select (s.items ->> p_item)::int from public.world_storage s where s.owner_id = p_uid), 0);
  n := n + coalesce((select (s.items ->> p_item)::int from public.world_housing_store s where s.owner_id = hm), 0);
  n := n + coalesce((select (public.world_housing_counts_all(h.items, h.wall, h.paper, h.ground, h.rooms) ->> p_item)::int from public.world_housing h where h.owner_id = hm), 0);
  return n;
end $f$;

create or replace function public.world_portrait_book()
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid(); done text[]; pre text := public.world_portrait_rules() ->> 'item';
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  done := public.world_quest_done_ids(uid);
  return jsonb_build_object(
    'house', exists (select 1 from public.world_housing h where h.owner_id = public.world_housing_home(uid)),
    'list', coalesce((select jsonb_agg(jsonb_build_object('k', c.value ->> 'k', 'quest', q.title, 'lv', q.min_level, 'cat', q.cat,
        'open', (c.value ->> 'q') = any(done),
        'have', (c.value ->> 'q') = any(done) and public.world_portrait_have(uid, pre || (c.value ->> 'k')) > 0) order by c.ord)
      from jsonb_array_elements(public.world_portrait_rules() -> 'cast') with ordinality c(value, ord)
      left join public.world_quests q on q.quest_id = c.value ->> 'q'), '[]'::jsonb));
end $f$;

create or replace function public.world_portrait_take(p_key text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb; it text; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select c into r from jsonb_array_elements(public.world_portrait_rules() -> 'cast') c where c ->> 'k' = p_key;
  if r is null then raise exception '없는 초상입니다.'; end if;
  perform 1 from public.world_characters where owner_id = uid for update;
  if not exists (select 1 from public.world_housing h where h.owner_id = public.world_housing_home(uid)) then
    raise exception '별채가 있어야 초상 액자를 꺼낼 수 있습니다.' using hint = 'no_house';
  end if;
  if not ((r ->> 'q') = any(public.world_quest_done_ids(uid))) then
    raise exception '아직 화첩에 열리지 않은 초상입니다.' using hint = 'locked';
  end if;
  it := (public.world_portrait_rules() ->> 'item') || p_key;
  select item_name into nm from public.world_item_catalog where item_id = it;
  if public.world_portrait_have(uid, it) > 0 then
    raise exception '%', public.world_josa(nm, '은', '는') || ' 이미 가방·창고·별채 어딘가에 있습니다.' using hint = 'have';
  end if;
  perform public.world_housing_grant(uid, it, 1, '초상 화첩', true);
  return jsonb_build_object('item', it, 'name', nm);
end $f$;

do $g$
declare f text;
begin
  perform pg_temp.pj_share('public.world_portrait_rules()');
  foreach f in array array['world_portrait_have(uuid, text)', 'world_portrait_book()', 'world_portrait_take(text)'] loop
    perform pg_temp.pj_share('public.' || f);
    perform pg_temp.pj_own('public.' || f, 'fn_owner_field');
  end loop;
end $g$;
grant execute on function public.world_portrait_book() to authenticated;
grant execute on function public.world_portrait_take(text) to authenticated;
grant execute on function public.world_portrait_rules() to anon, authenticated;
