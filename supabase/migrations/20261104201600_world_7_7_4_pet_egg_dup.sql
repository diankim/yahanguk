-- 7.7.4 — 알에서 이미 함께하는 동무도 나온다(사용자 요청 2026-11-01).
-- 전에는 아직 없는 동무만 뽑고, 그 등급을 다 모으면 알을 열 수 없었다.
-- 이제 그 등급 알 동무 가운데 고르게 뽑아(모은 만큼 겹칠 확률이 오름) 겹치면 친밀도 +30(최대 300),
-- 친밀도를 이미 가득 채운 동무가 나오면 「동무 정표」 하나. 정표 5개는 「빛나는 알」 하나로 바꾼다(world_pet_token_trade, 어디서나).

-- 동무 정표(거래 불가 재료, 묶음 40). 단계 3 → 희귀도는 world_normalize_item_rarity가 정한다.
insert into public.world_item_catalog(item_id, item_name, category, tier, rarity, stackable, stack_size, tradeable, description, reference_price, equipment_traits, minimum_level, required_stats, quality_grade)
values ('pet_token', '동무 정표', 'material', 3, 'rare', true, 40, false,
  '친밀도를 가득 채운 꼬마 동무가 알에서 다시 나왔을 때 남기는 작은 매듭. 다섯 개를 모으면 「빛나는 알」 하나로 바꿀 수 있다(가방·별채 동무 도감).',
  300, '{"pet_token":true}'::jsonb, 1, '{}'::jsonb, 0)
on conflict (item_id) do nothing;
update public.world_item_catalog set description = '탐색하다 주운 따뜻한 알. 쓰면 양품 꼬마 동무가 태어난다. 이미 함께하는 동무가 나오면 친밀도가 오르고, 친밀도를 다 채운 동무면 동무 정표가 된다.' where item_id = 'pet_egg_2';
update public.world_item_catalog set description = '안쪽에서 은은한 빛이 새는 알. 쓰면 진품 꼬마 동무가 태어난다. 이미 함께하는 동무가 나오면 친밀도가 오르고, 친밀도를 다 채운 동무면 동무 정표가 된다.' where item_id = 'pet_egg_3';

do $p$
declare r record; d text; n int; own text; inh boolean;
begin
  for r in
    select * from (values
      ('public.world_pet_adopt(text)'::regprocedure,
$A$declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; pid text; g int; have int; sp public.world_pet_species%rowtype;$A$,
$B$declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; pid text; g int; have int; sp public.world_pet_species%rowtype; dup boolean := false; aff0 int; aff1 int;$B$),
      ('public.world_pet_adopt(text)'::regprocedure,
$A$    select s.pet_id into pid from public.world_pet_species s
     where s.grade = g and s.egg and not exists (select 1 from public.world_pets p where p.owner_id = uid and p.pet_id = s.pet_id)
     order by random() limit 1;
    if pid is null then raise exception '이 알에서 나올 동무를 모두 만났습니다. 알은 팔거나 다른 조사원에게 넘길 수 있습니다.'; end if;$A$,
$B$    -- 7.7.4: 그 등급 알 동무 가운데 고르게 뽑는다(이미 함께하는 동무도 나옴 — 모은 만큼 겹칠 확률이 오른다)
    select s.pet_id into pid from public.world_pet_species s where s.grade = g and s.egg order by random() limit 1;
    if pid is null then raise exception '이 알에서 나올 동무가 없습니다.'; end if;
    select affinity into aff0 from public.world_pets where owner_id = uid and pet_id = pid;
    dup := aff0 is not null;$B$),
      ('public.world_pet_adopt(text)'::regprocedure,
$A$  perform public.world_pet_grant(uid, pid, 'item:' || p_item, false);
  select * into sp from public.world_pet_species where pet_id = pid;$A$,
$B$  select * into sp from public.world_pet_species where pet_id = pid;
  if dup and aff0 >= 300 then
    -- 친밀도를 이미 가득 채운 동무: 동무 정표 하나(가방이 차면 개인 창고로)
    if public.world_bag_room((select inventory from public.world_characters where owner_id = uid), 'pet_token', public.world_bag_limit(uid)) >= 1 then
      update public.world_characters set inventory = public.world_inv_add(inventory, 'pet_token', 1), updated_at = now() where owner_id = uid;
    else
      insert into public.world_storage(owner_id) values (uid) on conflict (owner_id) do nothing;
      update public.world_storage set items = public.world_inv_add(items, 'pet_token', 1), updated_at = now() where owner_id = uid;
    end if;
    return jsonb_build_object('ok', true, 'pet_id', pid, 'name', sp.pet_name, 'grade', sp.grade, 'dup', true, 'token', true, 'affinity', aff0,
      'content', '알이 갈라지고 ' || public.world_josa(sp.pet_name, '이', '가') || ' 나왔습니다. 이미 마음을 다 연 동무라 「동무 정표」 하나를 남기고 돌아갑니다. 정표 다섯 개는 빛나는 알 하나로 바꿀 수 있습니다.');
  elsif dup then
    -- 겹치면 친밀도 +30(최대 300), 100을 넘기면 다 자람
    aff1 := least(300, aff0 + 30);
    update public.world_pets set affinity = aff1 where owner_id = uid and pet_id = pid;
    if aff0 < 100 and aff1 >= 100 then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (uid, 'pet_new', '꼬마 동무가 자랐습니다', public.world_josa(sp.pet_name, '이', '가') || ' 훌쩍 자랐습니다.', jsonb_build_object('pet_id', pid));
      perform public.world_title_award_check(uid, 'home');
    end if;
    return jsonb_build_object('ok', true, 'pet_id', pid, 'name', sp.pet_name, 'grade', sp.grade, 'dup', true, 'affinity', aff1,
      'content', '알이 갈라지고 ' || public.world_josa(sp.pet_name, '이', '가') || ' 나왔습니다. 이미 함께하는 동무라 친밀도가 ' || (aff1 - aff0) || ' 올랐습니다(' || aff1 || '/300).');
  end if;
  perform public.world_pet_grant(uid, pid, 'item:' || p_item, false);$B$)
    ) x(fn, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.4 pet egg anchor in % (% of 1): %', r.fn, n, left(r.a, 60); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole and am.inherit_option limit 1;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is null and own <> 'postgres' then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

-- 동무 정표 5개 → 빛나는 알 1개(어디서나, 봉인 중 아님, 가방 자리 확인)
create or replace function public.world_pet_token_trade()
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare uid uuid := public.fn_owner_auth_uid(); have int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select coalesce((inventory ->> 'pet_token')::int, 0) into have from public.world_characters where owner_id = uid for update;
  if have < 5 then raise exception '동무 정표가 %개 있습니다. 다섯 개가 있어야 빛나는 알로 바꿀 수 있습니다.', have; end if;
  update public.world_characters set inventory = public.world_inv_add(public.world_inv_add(inventory, 'pet_token', -5), 'pet_egg_3', 1), updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'content', '동무 정표 다섯 개를 엮어 「빛나는 알」 하나로 바꿨습니다.', 'left', have - 5);
end $function$;
revoke all on function public.world_pet_token_trade() from public, anon;
grant execute on function public.world_pet_token_trade() to authenticated;

update public.world_app_meta set value = '20261104201600' where key = 'db_version';
