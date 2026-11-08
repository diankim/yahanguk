create table if not exists public.world_pet_mess (
  owner_id uuid not null references auth.users(id) on delete cascade,
  pet_id text not null,
  clean_at timestamptz not null default now(),
  sick_at timestamptz,
  primary key (owner_id, pet_id)
);
alter table public.world_pet_mess enable row level security;
revoke all on public.world_pet_mess from public, anon, authenticated;

create table if not exists public.world_pet_clean_log (
  owner_id uuid not null references auth.users(id) on delete cascade,
  visitor_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  primary key (owner_id, visitor_id, day)
);
create index if not exists world_pet_clean_log_visitor on public.world_pet_clean_log(visitor_id);
alter table public.world_pet_clean_log enable row level security;
revoke all on public.world_pet_clean_log from public, anon, authenticated;

create or replace function public.world_pet_mess_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object('every_h', 8, 'max', 3, 'sick_h', 24, 'cure', 'pet_medicine', 'guest_gain', 1)
$function$;

create or replace function public.world_pet_mess_of(p_owner uuid, p_pet text)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare m public.world_pet_mess%rowtype; r jsonb := public.world_pet_mess_rules(); every interval; mx int; thr interval;
begin
  if p_pet is null then return null; end if;
  select * into m from public.world_pet_mess where owner_id = p_owner and pet_id = p_pet;
  if not found then return jsonb_build_object('n', 0, 'sick', false, 'max', (r->>'max')::int, 'every_h', (r->>'every_h')::int); end if;
  every := make_interval(hours => (r->>'every_h')::int); mx := (r->>'max')::int;
  thr := every * mx + make_interval(hours => (r->>'sick_h')::int);
  return jsonb_build_object('n', least(mx, floor(extract(epoch from now() - m.clean_at) / extract(epoch from every))::int),
    'sick', m.sick_at is not null or now() >= m.clean_at + thr, 'max', mx, 'every_h', (r->>'every_h')::int);
end $function$;

create or replace function public.world_pet_care(p_owner uuid, p_act text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); h public.world_housing%rowtype; m public.world_pet_mess%rowtype; r jsonb := public.world_pet_mess_rules();
  st jsonb; why text; own boolean; nm text; vn text; c public.world_characters%rowtype; have int; cure text := r->>'cure'; thr interval; aff int; gain int := 0;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_act not in ('clean', 'cure') then raise exception '알 수 없는 돌보기입니다.'; end if;
  select * into h from public.world_housing where owner_id = p_owner;
  if not found or h.pet_id is null then raise exception '이 별채에는 동무가 없습니다.'; end if;
  if h.pet_out then raise exception '동무가 주인과 함께 나가 있습니다.'; end if;
  why := public.world_housing_can_view(uid, p_owner, h.gate);
  if why is not null then raise exception '%', why; end if;
  own := coalesce(uid = p_owner or uid = public.world_housing_mate(p_owner) or public.world_housing_married(uid, p_owner), false);
  select coalesce(p.nickname, s.pet_name) into nm from public.world_pet_species s left join public.world_pets p on p.owner_id = p_owner and p.pet_id = s.pet_id where s.pet_id = h.pet_id;
  insert into public.world_pet_mess(owner_id, pet_id, clean_at) values (p_owner, h.pet_id, now()) on conflict do nothing;
  select * into m from public.world_pet_mess where owner_id = p_owner and pet_id = h.pet_id for update;
  st := public.world_pet_mess_of(p_owner, h.pet_id);
  thr := make_interval(hours => (r->>'every_h')::int) * (r->>'max')::int + make_interval(hours => (r->>'sick_h')::int);
  if p_act = 'clean' then
    if (st->>'n')::int < 1 then raise exception '%의 자리는 깨끗합니다. 치울 것이 없습니다.', nm; end if;
    if not own then
      insert into public.world_pet_clean_log(owner_id, visitor_id, day) values (p_owner, uid, public.world_housing_today()) on conflict do nothing;
      if not found then raise exception '오늘은 이미 이 별채의 동무 자리를 치워 주었습니다. 내일 또 와 주세요.'; end if;
      gain := (r->>'guest_gain')::int;
      update public.world_pets set affinity = least(300, affinity + gain) where owner_id = p_owner and pet_id = h.pet_id returning affinity into aff;
      select character_name into vn from public.world_characters where owner_id = uid;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (p_owner, 'pet_clean', '별채의 동무', vn || '님이 ' || public.world_josa(nm, '이', '가') || ' 어질러 둔 자리를 치워 주었습니다.', jsonb_build_object('visitor', uid));
    end if;
    update public.world_pet_mess set clean_at = now(), sick_at = case when sick_at is null and now() >= clean_at + thr then clean_at + thr else sick_at end
     where owner_id = p_owner and pet_id = h.pet_id;
  else
    if not own then raise exception '약은 주인만 먹일 수 있습니다.'; end if;
    if not (st->>'sick')::boolean then raise exception '%은(는) 아프지 않습니다.', nm; end if;
    if (st->>'n')::int > 0 then raise exception '먼저 어질러진 자리를 치워 주세요.'; end if;
    select * into c from public.world_characters where owner_id = uid for update;
    have := coalesce((c.inventory ->> cure)::int, 0);
    if have < 1 then raise exception '가방에 %이(가) 없습니다. 안전지대 상점에서 살 수 있습니다.', (select item_name from public.world_item_catalog where item_id = cure); end if;
    update public.world_characters set inventory = case when have - 1 <= 0 then inventory - cure else jsonb_set(inventory, array[cure], to_jsonb(have - 1)) end, updated_at = now() where owner_id = uid;
    update public.world_pet_mess set sick_at = null, clean_at = now() where owner_id = p_owner and pet_id = h.pet_id;
  end if;
  return jsonb_build_object('ok', true, 'mess', public.world_pet_mess_of(p_owner, h.pet_id), 'gain', gain, 'affinity', aff,
    'content', case when p_act = 'cure' then public.world_josa(nm, '이', '가') || ' 약을 먹고 기운을 차렸습니다.'
      when own then public.world_josa(nm, '이', '가') || ' 어질러 둔 자리를 깨끗이 치웠습니다.'
      else public.world_josa(nm, '이', '가') || ' 어질러 둔 자리를 치워 주었습니다. 동무가 고마워합니다.' end);
end $function$;
revoke all on function public.world_pet_care(uuid, text) from public, anon;
grant execute on function public.world_pet_care(uuid, text) to authenticated, service_role;
revoke all on function public.world_pet_mess_of(uuid, text) from public, anon, authenticated;
grant execute on function public.world_pet_mess_of(uuid, text) to service_role, fn_owner_field;
revoke all on function public.world_pet_mess_rules() from public, anon, authenticated;
grant execute on function public.world_pet_mess_rules() to service_role, fn_owner_field;

create or replace function public.world_pet_mess_on_place()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
begin
  if new.pet_id is not null and new.pet_id is distinct from old.pet_id then
    insert into public.world_pet_mess(owner_id, pet_id, clean_at) values (new.owner_id, new.pet_id, now())
    on conflict (owner_id, pet_id) do update set clean_at = now();
  end if;
  return new;
end $function$;
revoke all on function public.world_pet_mess_on_place() from public, anon, authenticated;
drop trigger if exists trg_world_pet_mess_place on public.world_housing;
create trigger trg_world_pet_mess_place after update of pet_id on public.world_housing for each row execute function public.world_pet_mess_on_place();

insert into public.world_pet_mess(owner_id, pet_id, clean_at)
select owner_id, pet_id, now() from public.world_housing where pet_id is not null
on conflict do nothing;

insert into public.world_item_catalog (item_id, item_name, category, tier, rarity, stackable, stack_size, tradeable, description, reference_price, equipment_traits, minimum_level)
values ('pet_medicine', '동무 약', 'consumable', 1, 'common', true, 40, true, '배탈 난 꼬마 동무에게 먹이는 쓴 약. 어질러진 자리를 먼저 치운 뒤 별채에서 먹이면 기운을 차린다.', 50, '{"pet_care": true}'::jsonb, 1)
on conflict (item_id) do nothing;
insert into public.world_shop_catalog (item_id, shop_id, daily_cap, stock_max, stock_min, base_price)
select 'pet_medicine', shop_id, daily_cap, stock_max, stock_min, 50 from public.world_shop_catalog where item_id = 'pet_food'
on conflict do nothing;

do $r$
declare src text := pg_get_functiondef('public.world_pet_room(uuid)'::regprocedure);
  o text := $o$'affinity', p.affinity) end$o$;
begin
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_pet_room: 바꿀 곳이 하나가 아님'; end if;
  execute replace(src, o, $n$'affinity', p.affinity, 'mess', public.world_pet_mess_of(h.owner_id, h.pet_id)) end$n$);
end $r$;

do $r$
declare src text := pg_get_functiondef('public.world_pet_act(uuid,text,text)'::regprocedure);
  o text := $o$  pt.affinity := least(300, pt.affinity + gain);$o$;
begin
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_pet_act: 바꿀 곳이 하나가 아님'; end if;
  execute replace(src, o, $n$  if p_act <> 'feed' and coalesce((public.world_pet_mess_of(p_owner, h.pet_id) ->> 'sick')::boolean, false) then gain := 0; react := 'sick'; end if;
  pt.affinity := least(300, pt.affinity + gain);$n$);
end $r$;

do $r$
declare src text := pg_get_functiondef('public.world_notify_group(text)'::regprocedure);
  o text := $o$'pet_play', 'pet_new',$o$;
begin
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_notify_group: 바꿀 곳이 하나가 아님'; end if;
  execute replace(src, o, $n$'pet_play', 'pet_clean', 'pet_new',$n$);
end $r$;

do $r$
declare src text := pg_get_functiondef('public.world_character_purge(uuid)'::regprocedure);
  o text := $o$  delete from public.world_pets where owner_id = p_uid;$o$;
begin
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_character_purge: 바꿀 곳이 하나가 아님'; end if;
  execute replace(src, o, $n$  delete from public.world_pet_mess where owner_id = p_uid;
  delete from public.world_pet_clean_log where owner_id = p_uid or visitor_id = p_uid;
  delete from public.world_pets where owner_id = p_uid;$n$);
end $r$;

update public.world_patch_notes set body = body || E'\n\n## 1.1.1\n- 거래소에서 여러 개를 묶어 올린 물품도 필요한 개수만 골라 살 수 있습니다. 남은 물품은 그대로 판매 중으로 남습니다.\n- 별채의 꼬마 동무가 8시간마다 한 번씩 자리를 어지릅니다(최대 3번). 「치우기」로 치워 주세요. 다녀간 손님도 하루 한 번 치워 줄 수 있고, 그러면 그 동무의 친밀도가 1 오릅니다.\n- 세 번 어질러진 채 하루가 지나면 동무가 배탈이 납니다. 배탈 동안에는 쓰다듬거나 놀아 주어도 친밀도가 오르지 않습니다. 자리를 치운 뒤 「동무 약」(안전지대 상점, 50전)을 먹이면 낫습니다. 친밀도가 깎이지는 않습니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261108210000' where key = 'db_version';
