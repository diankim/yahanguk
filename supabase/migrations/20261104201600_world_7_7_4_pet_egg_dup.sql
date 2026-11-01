-- 7.7.4 — 알에서 이미 함께하는 동무도 나온다(사용자 요청 2026-11-01).
-- 전에는 아직 없는 동무만 뽑고, 그 등급을 다 모으면 알을 열 수 없었다.
-- 이제 그 등급 알 동무 가운데 고르게 뽑아(모은 만큼 겹칠 확률이 오름) 겹치면 친밀도 +30(최대 300). 친밀도를 가득 채운 동무는 뽑지 않고,
-- 그 등급 동무가 모두 가득 차면 지금처럼 열 수 없다고 알린다.
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
$B$    -- 7.7.4: 그 등급 알 동무 가운데 고르게 뽑는다(이미 함께하는 동무도 나옴 — 모은 만큼 겹칠 확률이 오른다). 친밀도를 가득(300) 채운 동무는 빼고 뽑는다.
    select s.pet_id into pid from public.world_pet_species s
     where s.grade = g and s.egg and not exists (select 1 from public.world_pets p where p.owner_id = uid and p.pet_id = s.pet_id and p.affinity >= 300)
     order by random() limit 1;
    if pid is null then raise exception '이 알에서 나올 동무가 모두 친밀도를 가득 채웠습니다. 알은 팔거나 다른 조사원에게 넘길 수 있습니다.'; end if;
    select affinity into aff0 from public.world_pets where owner_id = uid and pet_id = pid;
    dup := aff0 is not null;$B$),
      ('public.world_pet_adopt(text)'::regprocedure,
$A$  perform public.world_pet_grant(uid, pid, 'item:' || p_item, false);
  select * into sp from public.world_pet_species where pet_id = pid;$A$,
$B$  select * into sp from public.world_pet_species where pet_id = pid;
  if dup then
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

update public.world_app_meta set value = '20261104201600' where key = 'db_version';
