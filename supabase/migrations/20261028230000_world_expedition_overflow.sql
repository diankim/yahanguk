-- 원정 짐 보따리(2026-10-28): 원정에서 돌아올 때 가방이 넘치면 넘친 전리품을 버리지 않고 따로 담아 둔다.
--   조사원은 보따리에서 골라 챙기거나 버린다. 보따리가 비기 전에는 이동·지역 안 이동·탐색·채집·낚시·전투·원정 출발을 서버가 막는다.
--   가방이 넘치지 않으면 보따리는 생기지 않는다. 원정 밖의 얻기(전리품·채집 등)는 지금처럼 넘친 만큼 버리고 알린다.
grant fn_owner_field to postgres with inherit true, set true;
grant fn_owner_expedition to postgres with inherit true, set true;

create table if not exists public.world_overflow_items (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  item_id text not null,
  qty integer not null check (qty > 0),
  source text not null default 'expedition',
  created_at timestamptz not null default now(),
  primary key (owner_id, item_id)
);
alter table public.world_overflow_items enable row level security;
revoke all on public.world_overflow_items from public, anon, authenticated;
grant select, insert, update, delete on public.world_overflow_items to fn_owner_field, fn_owner_expedition;

-- 가방 넘침: 원정 귀환(yh.overflow_to = expedition) 중이면 넘친 만큼 보따리에 담는다
create or replace function public.world_enforce_bag_capacity()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
DECLARE
  cap int := new.bag_capacity + CASE WHEN new.major_faction_id = 'river_alliance' THEN 6 ELSE 0 END;
  old_total int := public.world_bag_count(old.inventory);
  new_total int := public.world_bag_count(new.inventory);
  allowed int; need int; k text; cur int; was int; s int; sc int; sm int; r int; nq int;
  dropped jsonb := '{}'::jsonb; exchange boolean;
  stash boolean := coalesce(current_setting('yh.overflow_to', true), '') = 'expedition';
BEGIN
  IF new_total <= cap OR new_total <= old_total THEN RETURN new; END IF;
  allowed := greatest(cap, old_total);
  IF new_total <= allowed THEN RETURN new; END IF;
  exchange := new.gil < old.gil OR EXISTS (
    SELECT 1 FROM jsonb_each(coalesce(old.inventory, '{}'::jsonb)) o(k, v)
    WHERE jsonb_typeof(o.v) = 'number' AND coalesce((new.inventory ->> o.k)::numeric, 0) < o.v::text::numeric);
  IF exchange AND NOT stash THEN
    RAISE EXCEPTION '가방이 가득 찼습니다 (%/%칸). 물품을 정리한 뒤 다시 시도하세요.', new_total, cap USING errcode = 'P0001';
  END IF;
  need := new_total - allowed;
  FOR k, cur, was IN
    SELECT n.k, n.v::text::numeric::int, coalesce((old.inventory ->> n.k)::numeric, 0)::int
    FROM jsonb_each(new.inventory) n(k, v)
    WHERE jsonb_typeof(n.v) = 'number' AND n.v::text::numeric > coalesce((old.inventory ->> n.k)::numeric, 0)
    ORDER BY n.k DESC
  LOOP
    EXIT WHEN need <= 0;
    s := public.world_item_stack(k);
    sc := ceil(cur::numeric / s); sm := ceil(greatest(0, was)::numeric / s);
    r := least(sc - sm, need);
    CONTINUE WHEN r <= 0;
    nq := (sc - r) * s;
    new.inventory := jsonb_set(new.inventory, ARRAY[k], to_jsonb(nq));
    dropped := jsonb_set(dropped, ARRAY[k], to_jsonb(cur - nq));
    need := need - r;
  END LOOP;
  IF dropped <> '{}'::jsonb THEN
    IF stash THEN
      INSERT INTO public.world_overflow_items(owner_id, item_id, qty)
      SELECT new.owner_id, d.k, d.v::int FROM jsonb_each_text(dropped) d(k, v) WHERE d.v::int > 0
      ON CONFLICT (owner_id, item_id) DO UPDATE SET qty = public.world_overflow_items.qty + excluded.qty;
      INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
      VALUES (new.owner_id, 'bag_overflow', '원정 짐 보따리',
        (SELECT string_agg(coalesce(i.item_name, d.k) || ' ×' || d.v, ', ') FROM jsonb_each_text(dropped) d(k, v) LEFT JOIN public.world_item_catalog i ON i.item_id = d.k)
          || '은(는) 가방에 자리가 없어 보따리에 담았습니다. 챙기거나 버려야 다시 길을 나설 수 있습니다.',
        jsonb_build_object('stashed', dropped, 'capacity', cap));
    ELSE
      INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
      VALUES (new.owner_id, 'bag_full', '가방이 가득 찼습니다',
        (SELECT string_agg(coalesce(i.item_name, d.k) || ' ×' || d.v, ', ') FROM jsonb_each_text(dropped) d(k, v) LEFT JOIN public.world_item_catalog i ON i.item_id = d.k)
          || '을(를) 챙기지 못했습니다. 가방을 정리하거나 용량을 늘리세요.',
        jsonb_build_object('dropped', dropped, 'capacity', cap));
    END IF;
  END IF;
  RETURN new;
END
$function$;

-- 원정 귀환: 이 처리 안에서 넘치는 것은 보따리로
do $$
declare d text := pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure);
  a text := $q$if not found then raise exception '진행 중인 원정이 없습니다.'; end if;$q$;
begin
  if position('yh.overflow_to' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '원정 귀환 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  execute replace(d, a, a || $q$
  perform set_config('yh.overflow_to', 'expedition', true);$q$);
end $$;

-- 지역 안 이동(이 함수는 행동 기록을 남기지 않아 따로 막는다)
do $$
declare d text := pg_get_functiondef('public.world_field_move(uuid)'::regprocedure);
  a text := $q$IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;$q$;
begin
  if position('world_overflow_items' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '지역 안 이동 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  execute regexp_replace(d, regexp_replace(a, '([().\[\]])', '\\\1', 'g'), a || $q$
  IF EXISTS (SELECT 1 FROM public.world_overflow_items o WHERE o.owner_id = uid) THEN RAISE EXCEPTION '원정 짐 보따리를 먼저 정리하세요. 챙기거나 버린 뒤 움직일 수 있습니다.'; END IF;$q$);
end $$;

-- 행동 기록 검사: 보따리가 남아 있으면 길 떠나기·탐색·채집·낚시·전투·원정 출발을 막는다
do $$
declare d text := pg_get_functiondef('public.world_guard_action_context()'::regprocedure);
  a text := $q$  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN ('encounter', 'combat') THEN$q$;
begin
  if position('world_overflow_items' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '행동 검사 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  execute replace(d, a, $q$  IF (k IN ('explore', 'gather', 'fish', 'combat', 'encounter', 'expedition_start') OR (k = 'travel' AND NOT (p ? 'travel_history_id')))
     AND EXISTS (SELECT 1 FROM public.world_overflow_items o WHERE o.owner_id = new.actor_id) THEN
    RAISE EXCEPTION '원정 짐 보따리를 먼저 정리하세요. 챙기거나 버린 뒤 다시 할 수 있습니다.';
  END IF;
$q$ || a);
end $$;

-- 현장 화면: 보따리에 남은 수량
do $$
declare d text := pg_get_functiondef('public.world_field_snapshot()'::regprocedure);
  a text := $q$'trail', (SELECT jsonb_build_object('expires_at'$q$;
begin
  if position('world_overflow_items' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '현장 함수에서 고칠 자리를 찾지 못했습니다'; end if;
  execute replace(d, a, $q$'overflow', (SELECT coalesce(sum(o.qty), 0) FROM public.world_overflow_items o WHERE o.owner_id = uid),
    $q$ || a);
end $$;

create or replace function public.world_overflow_snapshot()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; cap int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  cap := c.bag_capacity + case when c.major_faction_id = 'river_alliance' then 6 else 0 end;
  return jsonb_build_object(
    'items', coalesce((select jsonb_agg(jsonb_build_object('item_id', o.item_id, 'name', coalesce(i.item_name, o.item_id), 'qty', o.qty,
        'rarity', i.rarity, 'category', i.category, 'stack', public.world_item_stack(o.item_id),
        'room', public.world_bag_room(c.inventory, o.item_id, cap)) order by o.created_at, o.item_id)
      from public.world_overflow_items o left join public.world_item_catalog i on i.item_id = o.item_id where o.owner_id = uid), '[]'::jsonb),
    'bag', jsonb_build_object('used', public.world_bag_count(c.inventory), 'limit', cap));
end $$;

-- 챙기기: 가방에 들어가는 만큼만 옮긴다
create or replace function public.world_overflow_take(p_item text, p_qty integer default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; o public.world_overflow_items%rowtype; cap int; room int; n int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select * into o from public.world_overflow_items where owner_id = uid and item_id = p_item for update;
  if not found then raise exception '보따리에 그 물품이 없습니다.'; end if;
  cap := c.bag_capacity + case when c.major_faction_id = 'river_alliance' then 6 else 0 end;
  room := public.world_bag_room(c.inventory, p_item, cap);
  n := least(o.qty, coalesce(nullif(p_qty, 0), o.qty), room);
  if n <= 0 then raise exception '가방에 자리가 없습니다. 가방에서 쓰거나 버린 뒤 다시 챙기세요.'; end if;
  update public.world_characters set inventory = public.world_inv_add(coalesce(inventory, '{}'::jsonb), p_item, n), updated_at = now() where owner_id = uid;
  if n >= o.qty then delete from public.world_overflow_items where owner_id = uid and item_id = p_item;
  else update public.world_overflow_items set qty = qty - n where owner_id = uid and item_id = p_item; end if;
  return jsonb_build_object('ok', true, 'taken', n, 'left', o.qty - n,
    'content', coalesce((select item_name from public.world_item_catalog where item_id = p_item), p_item) || ' ×' || n || '을(를) 챙겼습니다.');
end $$;

-- 버리기
create or replace function public.world_overflow_discard(p_item text, p_qty integer default null)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); o public.world_overflow_items%rowtype; n int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into o from public.world_overflow_items where owner_id = uid and item_id = p_item for update;
  if not found then raise exception '보따리에 그 물품이 없습니다.'; end if;
  n := least(o.qty, coalesce(nullif(p_qty, 0), o.qty));
  if n >= o.qty then delete from public.world_overflow_items where owner_id = uid and item_id = p_item;
  else update public.world_overflow_items set qty = qty - n where owner_id = uid and item_id = p_item; end if;
  return jsonb_build_object('ok', true, 'discarded', n, 'left', o.qty - n,
    'content', coalesce((select item_name from public.world_item_catalog where item_id = p_item), p_item) || ' ×' || n || '을(를) 버렸습니다.');
end $$;

alter function public.world_overflow_snapshot() owner to fn_owner_field;
alter function public.world_overflow_take(text, integer) owner to fn_owner_field;
alter function public.world_overflow_discard(text, integer) owner to fn_owner_field;
revoke all on function public.world_overflow_snapshot() from public, anon, authenticated;
revoke all on function public.world_overflow_take(text, integer) from public, anon, authenticated;
revoke all on function public.world_overflow_discard(text, integer) from public, anon, authenticated;
grant execute on function public.world_overflow_snapshot() to authenticated;
grant execute on function public.world_overflow_take(text, integer) to authenticated;
grant execute on function public.world_overflow_discard(text, integer) to authenticated;

grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_expedition to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028230000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
