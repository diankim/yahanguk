-- 가방 묶음 + 탈것 설명의 「운임 없음」 문구 바로잡기 + 휴식·야영 회복량 표시. 같은 물품은 한 묶음까지 한 칸에 쌓인다(지금까지는 수량 하나가 한 칸이었다).
-- 묶음 크기(world_item_catalog.stack_size)
-- - 장비(무기·방어구·관모·신·노리개·호신부·탈·도구·기타 장비): 1
-- - 재료: 흔함·보통 20 · 귀함 10 · 진귀·전설 5 (낚은 물고기도 재료라 같은 기준)
-- - 소모품: 흔함·보통 10 · 귀함 5 · 진귀·전설 3 · 노정 건량은 원정에 여럿 챙기므로 20
-- - 임무 물품: 20
-- 칸 수 = 물품마다 올림(수량 ÷ 묶음 크기)의 합. 쓰는 곳: world_bag_count·world_inv_count(직접 거래)·가방 넘침 트리거·
--   원정 전리품(world_expedition_finish·world_expedition_complete)·연리 선물(world_bond_gift).
-- 넘침 처리: 얻기만 하는 행동은 넘친 칸만큼 묶음 단위로 덜어 내고 알린다(이미 있는 묶음의 빈 자리는 채운다).
-- 이 변경으로 칸 수는 줄기만 하므로 지금 가방이 넘치게 되는 캐릭터는 없다.
-- 새 물품을 넣을 때는 stack_size를 위 기준으로 정한다(정하지 않으면 1).
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 결과가 같다.

alter table public.world_item_catalog add column if not exists stack_size int not null default 1;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'world_item_catalog_stack_size_chk') then
    alter table public.world_item_catalog add constraint world_item_catalog_stack_size_chk check (stack_size between 1 and 999);
  end if;
end $$;

update public.world_item_catalog set stack_size = case
    when category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool', 'equipment') then 1
    when item_id = 'travel_ration' then 20
    when category = 'consumable' then case rarity when 'rare' then 5 when 'epic' then 3 when 'legendary' then 3 else 10 end
    when category like '%material%' then case rarity when 'rare' then 10 when 'epic' then 5 when 'legendary' then 5 else 20 end
    when category = 'quest' then 20
    else 10 end
 where stack_size is distinct from (case
    when category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool', 'equipment') then 1
    when item_id = 'travel_ration' then 20
    when category = 'consumable' then case rarity when 'rare' then 5 when 'epic' then 3 when 'legendary' then 3 else 10 end
    when category like '%material%' then case rarity when 'rare' then 10 when 'epic' then 5 when 'legendary' then 5 else 20 end
    when category = 'quest' then 20
    else 10 end);

-- 물품 하나의 묶음 크기(목록에 없으면 1)
create or replace function public.world_item_stack(p_item text)
 returns int language sql stable set search_path to ''
as $$ select coalesce((select greatest(1, i.stack_size) from public.world_item_catalog i where i.item_id = p_item), 1) $$;
grant execute on function public.world_item_stack(text) to public;
revoke execute on function public.world_item_stack(text) from anon;

-- 쓰는 칸 수
grant fn_owner_expedition to postgres with inherit true;
create or replace function public.world_bag_count(p_inv jsonb)
 returns integer language sql stable set search_path to 'pg_catalog', 'public'
as $function$
  select coalesce(sum(ceil(greatest(0, t.v::text::numeric) / coalesce(greatest(1, i.stack_size), 1))), 0)::int
  from jsonb_each(coalesce(p_inv, '{}'::jsonb)) as t(k, v)
  left join public.world_item_catalog i on i.item_id = t.k
  where jsonb_typeof(t.v) = 'number'
$function$;
alter function public.world_bag_count(jsonb) owner to fn_owner_expedition;
-- world_bag_room(누구나 실행)은 이 함수를 부르므로 원정 귀환·연리 선물(fn_owner_field 소유)이 실행할 수 있어야 한다(2026-10-27 운영 DB에 바로 넣음)
grant execute on function public.world_bag_count(jsonb) to fn_owner_field;

create or replace function public.world_inv_count(p_inv jsonb)
 returns integer language sql stable set search_path to ''
as $function$
  select coalesce(sum(ceil(greatest(0, t.v::text::numeric) / coalesce(greatest(1, i.stack_size), 1))), 0)::int
  from jsonb_each(coalesce(p_inv, '{}'::jsonb)) as t(k, v)
  left join public.world_item_catalog i on i.item_id = t.k
  where jsonb_typeof(t.v) = 'number'
$function$;

-- 이 물품을 몇 개 더 넣을 수 있는가(지금 묶음의 빈 자리 + 빈 칸 × 묶음 크기)
create or replace function public.world_bag_room(p_inv jsonb, p_item text, p_cap int)
 returns int language plpgsql stable set search_path to 'pg_catalog', 'public'
as $function$
declare s int := public.world_item_stack(p_item); have int := greatest(0, coalesce((p_inv ->> p_item)::numeric, 0))::int;
begin
  return (case when have % s = 0 then 0 else s - have % s end) + greatest(0, p_cap - public.world_bag_count(p_inv)) * s;
end $function$;
grant execute on function public.world_bag_room(jsonb, text, int) to public;
revoke execute on function public.world_bag_room(jsonb, text, int) from anon;

-- 가방 넘침 트리거: 칸 단위로 판정하고, 넘친 칸만큼 묶음 단위로 덜어 낸다
create or replace function public.world_enforce_bag_capacity()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
DECLARE
  cap int := new.bag_capacity + CASE WHEN new.major_faction_id = 'river_alliance' THEN 6 ELSE 0 END;
  old_total int := public.world_bag_count(old.inventory);
  new_total int := public.world_bag_count(new.inventory);
  allowed int; need int; k text; cur int; was int; s int; sc int; sm int; r int; nq int;
  dropped jsonb := '{}'::jsonb; exchange boolean;
BEGIN
  IF new_total <= cap OR new_total <= old_total THEN RETURN new; END IF;
  allowed := greatest(cap, old_total);
  IF new_total <= allowed THEN RETURN new; END IF;
  exchange := new.gil < old.gil OR EXISTS (
    SELECT 1 FROM jsonb_each(coalesce(old.inventory, '{}'::jsonb)) o(k, v)
    WHERE jsonb_typeof(o.v) = 'number' AND coalesce((new.inventory ->> o.k)::numeric, 0) < o.v::text::numeric);
  IF exchange THEN
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
    INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
    VALUES (new.owner_id, 'bag_full', '가방이 가득 찼습니다',
      (SELECT string_agg(coalesce(i.item_name, d.k) || ' ×' || d.v, ', ') FROM jsonb_each_text(dropped) d(k, v) LEFT JOIN public.world_item_catalog i ON i.item_id = d.k)
        || '을(를) 챙기지 못했습니다. 가방을 정리하거나 용량을 늘리세요.',
      jsonb_build_object('dropped', dropped, 'capacity', cap));
  END IF;
  RETURN new;
END
$function$;
alter function public.world_enforce_bag_capacity() owner to fn_owner_expedition;

-- 원정 전리품: 남은 칸 수 대신 이 물품이 들어갈 수 있는 개수로 판정
do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_expedition_finish'::regproc);
  if position('space := greatest(0, cap - used);' in d) > 0 then
    execute replace(d, 'space := greatest(0, cap - used);', 'space := public.world_bag_room(inv, k, cap);');
  end if;
end $$;
grant fn_owner_expedition to postgres with inherit false;

do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_expedition_complete'::regproc);
  if position('space := greatest(0, cap - used);' in d) > 0 then
    execute replace(d, 'space := greatest(0, cap - used);', 'space := public.world_bag_room(inv, k, cap);');
  end if;
end $$;

-- 연리 선물: 정인의 가방 칸도 묶음으로 센다
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.world_bond_gift'::regproc);
  if position('world_bag_room' in d) > 0 then return; end if;
  n := regexp_replace(d,
    $r$if \(select coalesce\(sum\(greatest\(0, case when jsonb_typeof\(v\) = 'number'.*?then raise exception '정인의 가방에 자리가 없습니다\.'$r$,
    $b$if q > 0 and public.world_bag_room(pc.inventory, p_item, pc.bag_capacity + (case when pc.major_faction_id = 'river_alliance' then 20 else 0 end)) < q then raise exception '정인의 가방에 자리가 없습니다.'$b$);
  if n = d then raise exception '연리 선물 가방 검사 줄을 찾지 못했습니다'; end if;
  execute n;
end $$;

-- 탈것 설명·운임 부족 문구 바로잡기(20261028003000에서 모든 탈것에 운임을 붙였다)
update public.world_mount_catalog set description = '초보자용 낡은 손수레. 느리고 한 명만 탈 수 있지만 운임이 싸다(구간당 노정패 1).'
 where mount_id = 'starter_cart' and description like '%필요 없다%';
update public.world_mount_catalog set description = '붉은 인장 사건을 끝까지 해결한 조사원을 따르는 작은 해태. 적은 운임(구간당 노정패 1)으로 둘을 태운다.'
 where mount_id = 'seal_haetae' and description like '%운임 없이%';
grant fn_owner_19203 to postgres with inherit true;
grant fn_owner_19259 to postgres with inherit true;
do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_charge_mount_fare'::regproc);
  if position('운행 재화가 부족합니다. 필요 %개 / 보유 %개. 탐험·전투·채집·제작으로 획득할 수 있습니다.' in d) > 0 then
    execute replace(d, '운행 재화가 부족합니다. 필요 %개 / 보유 %개. 탐험·전투·채집·제작으로 획득할 수 있습니다.',
      '노정패가 부족합니다. 필요 %개 / 보유 %개. 토벌 승리·이야기·의뢰·원정 귀환으로 얻을 수 있습니다.');
  end if;
  d := pg_get_functiondef('public.world_ride_respond'::regproc);
  if position('운행 재화가 부족합니다. 탈것 운임을 확인한 뒤 다시 시도하세요.' in d) > 0 then
    execute replace(d, '운행 재화가 부족합니다. 탈것 운임을 확인한 뒤 다시 시도하세요.', '노정패가 부족합니다. 탈것 운임을 확인한 뒤 다시 시도하세요.');
  end if;
end $$;
grant fn_owner_19203 to postgres with inherit false;
grant fn_owner_19259 to postgres with inherit false;

-- 휴식·야영 회복량 알리기: 실제로 오른 체력·정신·영력·침식·탐색력을 결과 문구와 'recovered'로 돌려준다.
-- 현장 정보(world_field_snapshot.region)에 rest_quality를 더해 화면이 쉬기 전에 예상 회복량을 보여 준다.
do $$
declare d text;
begin
  d := pg_get_functiondef('public.world_field_rest'::regproc);
  if position('stg int' in d) = 0 then
    d := replace(d, 'last_rest timestamptz; rest_wait interval;', 'last_rest timestamptz; rest_wait interval; stg int := 0; gain text;');
    d := replace(d, 'GET DIAGNOSTICS cleared = ROW_COUNT;',
      'GET DIAGNOSTICS cleared = ROW_COUNT;' || chr(10) ||
      '  hp := least(hp, greatest(0, 100 - c.health)); mn := least(mn, greatest(0, 100 - c.mental)); sp := least(sp, greatest(0, 100 - c.spiritual_power)); er := least(er, greatest(0, c.erosion));');
    d := replace(d, 'PERFORM public.world_stamina_change(uid, least(mx - st, CASE WHEN is_full AND r.is_safe_zone THEN mx WHEN is_full THEN 6 ELSE 3 END));',
      'stg := greatest(0, least(mx - st, CASE WHEN is_full AND r.is_safe_zone THEN mx WHEN is_full THEN 6 ELSE 3 END));' || chr(10) ||
      '  PERFORM public.world_stamina_change(uid, stg);' || chr(10) ||
      $q$  gain := format('체력 +%s · 정신 +%s · 영력 +%s · 침식 -%s · 탐색력 +%s', hp, mn, sp, er, stg);$q$);
    d := replace(d, $q$'content', '쉬던 중 ' || (ambush ->> 'name') || '이(가) 습격했습니다!');$q$,
      $q$'recovered', jsonb_build_object('health', hp, 'mental', mn, 'spirit', sp, 'erosion', er, 'stamina', stg), 'content', gain || '. 쉬던 중 ' || (ambush ->> 'name') || '이(가) 습격했습니다!');$q$);
    d := replace(d, $q$RETURN jsonb_build_object('ok', true, 'content', CASE WHEN is_full THEN '푹 쉬었습니다.' ELSE '잠시 숨을 골랐습니다.' END$q$,
      $q$RETURN jsonb_build_object('ok', true, 'recovered', jsonb_build_object('health', hp, 'mental', mn, 'spirit', sp, 'erosion', er, 'stamina', stg), 'content', CASE WHEN is_full THEN '푹 쉬었습니다.' ELSE '잠시 숨을 골랐습니다.' END$q$);
    d := replace(d, $q$|| ' 체력·정신·영력이 회복되고 탐색력이 찼습니다.' ||$q$, $q$|| ' ' || gain || '.' ||$q$);
    if (length(d) - length(replace(d, 'gain', ''))) / 4 < 4 or position('''recovered''' in d) = 0 or position('stg := greatest' in d) = 0 or position('hp := least(hp' in d) = 0 then
      raise exception '휴식 함수 바꿀 줄을 다 찾지 못했습니다';
    end if;
    execute d;
  end if;
  d := pg_get_functiondef('public.world_field_snapshot'::regproc);
  if position('''rest_quality''' in d) = 0 then
    if position($q$'rest_fee', r.rest_fee),$q$ in d) = 0 then raise exception '현장 정보에서 rest_fee 줄을 찾지 못했습니다'; end if;
    execute replace(d, $q$'rest_fee', r.rest_fee),$q$, $q$'rest_fee', r.rest_fee, 'rest_quality', coalesce(r.rest_quality, 1)),$q$);
  end if;
end $$;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028020000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select stack_size, category, count(*) from public.world_item_catalog group by 1, 2 order by 2, 1;
