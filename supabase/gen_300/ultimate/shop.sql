create table if not exists public.world_ultimate_buys (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  item_key text not null,
  board text not null,
  bought_at timestamptz not null default now(),
  primary key (owner_id, item_key)
);
alter table public.world_ultimate_buys enable row level security;
revoke all on table public.world_ultimate_buys from public, anon, authenticated;

create or replace function public.world_ultimate_tokens(p_uid uuid)
 returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
  select coalesce(jsonb_object_agg(b.key, coalesce((c.inventory ->> (b.value ->> 'token'))::int, 0) + coalesce((s.items ->> (b.value ->> 'token'))::int, 0)), '{}'::jsonb)
  from jsonb_each(public.world_ultimate_rules() -> 'boards') b
  left join public.world_characters c on c.owner_id = p_uid
  left join public.world_storage s on s.owner_id = p_uid
$f$;
revoke all on function public.world_ultimate_tokens(uuid) from public, anon, authenticated;

drop function if exists public.world_ultimate_shop();
create or replace function public.world_ultimate_shop(p_board text default null)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_ultimate_rules(); done text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  done := public.world_quest_done_ids(uid);
  return jsonb_build_object(
    'boards', (select coalesce(jsonb_object_agg(b.key, b.value || jsonb_build_object('open', done @> array[b.value ->> 'open_quest'])), '{}'::jsonb)
      from jsonb_each(r -> 'boards') b where p_board is null or b.key = p_board),
    'tokens', public.world_ultimate_tokens(uid),
    'items', (select coalesce(jsonb_agg(x.value || jsonb_build_object('owned', exists (select 1 from public.world_ultimate_buys u where u.owner_id = uid and u.item_key = x.value ->> 'key')) order by x.ordinality), '[]'::jsonb)
      from jsonb_array_elements(r -> 'shop') with ordinality x where p_board is null or x.value ->> 'board' = p_board));
end $f$;
revoke all on function public.world_ultimate_shop(text) from public, anon;
grant execute on function public.world_ultimate_shop(text) to authenticated;

create or replace function public.world_ultimate_buy(p_key text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb := public.world_ultimate_rules(); s jsonb; b jsonb; c public.world_characters%rowtype; st jsonb; tk text; cost int; t jsonb; msg text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_travel_guard('토큰 교환');
  perform public.world_seal_guard();
  select x into s from jsonb_array_elements(r -> 'shop') x where x ->> 'key' = p_key;
  if s is null then raise exception '바꿀 수 없는 것입니다.'; end if;
  b := r -> 'boards' -> (s ->> 'board');
  tk := b ->> 'token'; cost := (s ->> 'price')::int;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 바꿀 수 없습니다.'; end if;
  if (public.world_region_at(c.location)).region_id is distinct from b ->> 'region' then
    raise exception '%의 교환은 %에서만 할 수 있습니다.', b ->> 'name', (select rg.region_name from public.world_map_regions rg where rg.region_id = b ->> 'region'); end if;
  if exists (select 1 from public.world_ultimate_buys where owner_id = uid and item_key = p_key) then raise exception '이미 바꾼 것입니다. 같은 것은 한 번만 바꿀 수 있습니다.'; end if;
  select items into st from public.world_storage where owner_id = uid for update;
  if coalesce((public.world_ultimate_tokens(uid) ->> (s ->> 'board'))::int, 0) < cost then
    raise exception '%이(가) 모자랍니다(% 필요, 지금 %).', b ->> 'token_name', cost, coalesce((public.world_ultimate_tokens(uid) ->> (s ->> 'board'))::int, 0);
  end if;
  t := public.world_materials_take(coalesce(c.inventory, '{}'::jsonb), coalesce(st, '{}'::jsonb), jsonb_build_object(tk, cost));
  if s ->> 'kind' = 'item' and public.world_bag_room(t -> 'inv', s ->> 'id', public.world_bag_limit(uid)) < 1 then raise exception '가방 자리가 모자랍니다.'; end if;
  update public.world_characters set inventory = case when s ->> 'kind' = 'item' then public.world_inv_add(t -> 'inv', s ->> 'id', 1) else t -> 'inv' end, updated_at = now() where owner_id = uid;
  if st is not null then update public.world_storage set items = t -> 'st', updated_at = now() where owner_id = uid; end if;
  insert into public.world_ultimate_buys(owner_id, item_key, board) values (uid, p_key, s ->> 'board');
  if s ->> 'kind' = 'outfit' then perform public.world_outfit_give(uid, s ->> 'id', '무용담 토큰으로');
  elsif s ->> 'kind' in ('frame', 'pattern', 'seal') then insert into public.world_character_cosmetics(owner_id, cosmetic_key) values (uid, s ->> 'id') on conflict do nothing;
  elsif s ->> 'kind' = 'name_style' then insert into public.world_faction_unlocks(owner_id, unlock_key) values (uid, s ->> 'id') on conflict do nothing;
  elsif s ->> 'kind' = 'pet' then perform public.world_pet_grant(uid, s ->> 'id', 'ultimate', false);
  end if;
  msg := public.world_josa(s ->> 'name', '을', '를') || ' 받았습니다(' || (b ->> 'token_name') || ' ' || cost || ').'
    || case s ->> 'kind' when 'item' then ' 가방에 넣었습니다.' when 'outfit' then ' 「내 모습」 옷장에 넣었습니다.' when 'pet' then ' 꼬마 동무 도감에 들어왔습니다.'
      when 'name_style' then ' 설정 › 프로필 › 채팅 이름 색에서 고릅니다.' else ' 설정 › 프로필 꾸미기에서 답니다.' end;
  return jsonb_build_object('content', msg, 'tokens', public.world_ultimate_tokens(uid), 'key', p_key, 'from_storage', t -> 'from_st');
end $f$;
revoke all on function public.world_ultimate_buy(text) from public, anon;
grant execute on function public.world_ultimate_buy(text) to authenticated;

select pg_temp.yh_patch('public.world_character_purge(uuid)',
  $q$  delete from public.world_mentor_merit where owner_id = p_uid;$q$,
  $q$  delete from public.world_mentor_merit where owner_id = p_uid;
  delete from public.world_ultimate_buys where owner_id = p_uid;$q$);
