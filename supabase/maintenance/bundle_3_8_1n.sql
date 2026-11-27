-- 배포 앞(운영 전용): 운영의 postgres는 슈퍼유저가 아니라 inherit 없는 함수 주인 역할(fn_owner_*)의 함수를 create or replace 할 수 없다.
-- 이 트랜잭션 동안만 inherit을 켜고, owner_inherit_end.sql이 같은 목록을 원래대로(inherit false) 되돌린다.
create temp table yh_inh on commit drop as
select distinct r.rolname::text as r from pg_proc p join pg_roles r on r.oid = p.proowner
 where p.pronamespace = 'public'::regnamespace and r.rolname like 'fn\_owner%' and not pg_has_role('postgres', r.oid, 'USAGE');
do $i$ declare x text; begin for x in select r from yh_inh loop execute format('grant %I to postgres with inherit true', x); end loop; end $i$;
lock table public.world_app_meta, public.world_patch_notes, public.world_item_locks in access exclusive mode;
grant create on schema public to fn_owner_field;
create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_combat_stats', array[
  $a$WHEN c.job_key = 'bloodknight' THEN 0.9 WHEN$a$,
  $a$WHEN c.job_key = 'bloodknight' THEN 0.9 WHEN c.job_key IN ('medic', 'formation') THEN 0.85 WHEN$a$]);

select pg_temp.yh_fix('world_contrib_rules', array[
  $a$"heal": 0.1,$a$, $a$"heal": 0.05,$a$,
  $a$"result": 0.2,$a$, $a$"result": 0.3,$a$,
  $a$"scout": 0.88,$a$, $a$"scout": 1.0,$a$,
  $a$"formation": 1.3,$a$, $a$"formation": 1.0,$a$,
  $a$"sealmaster": 1.35,$a$, $a$"sealmaster": 1.2,$a$,
  $a$"bloodknight": 1.2}$a$, $a$"bloodknight": 1.1}$a$,
  $a$"guard_mul": {"formation": 2.0}$a$, $a$"guard_mul": {"formation": 1.0}$a$]);

select pg_temp.yh_fix('world_field_search', array[
  $a$w_path := w_path * (1 + public.world_explore_find_pct(uid) / 100.0); w_spot := w_spot * (1 + public.world_explore_find_pct(uid) / 100.0);$a$,
  $a$w_path := w_path * (1 + public.world_explore_find_pct(uid) / 100.0); w_spot := w_spot * (1 + public.world_explore_find_pct(uid) / 100.0);
  IF w_clue = 0 THEN
    w_path := w_path * greatest(1, 1 + (public.world_status_effect_total('clue_bonus_pct') + public.world_title_bonus('clue_bonus_pct')) / 100.0);
    w_spot := w_spot * greatest(1, 1 + (public.world_status_effect_total('clue_bonus_pct') + public.world_title_bonus('clue_bonus_pct')) / 100.0);
  END IF;$a$]);

select pg_temp.yh_fix('world_tourney_rules', array[
  $a$"medic": {"dealt": 1.10,$a$, $a$"medic": {"dealt": 1.29,$a$,
  $a$"formation": {"dealt": 1.12,$a$, $a$"formation": {"dealt": 1.32,$a$]);

select pg_temp.yh_fix('world_shadow_rules', array[$a$"hp_mul": 350,$a$, $a$"hp_mul": 450,$a$]);

update public.world_patch_notes set body = body || E'\n- [그림자] 사슬 벗은 그림자의 체력이 늘어, 다 함께 쳐도 10~15분쯤 걸리게 했습니다.'
where note_id = '3.8.0' and position('[그림자] 사슬 벗은 그림자의 체력이 늘어' in body) = 0;

update public.world_patch_notes set body = body || E'\n- [직업] 의무관·진법가의 공격력이 ×0.85가 됩니다(모든 싸움, 호위 무사와 같음). 치유를 맡는 직업이 공격수만큼 때리지 않게 했고, 비무에서는 직업 보정으로 그만큼 되돌려 지금 균형을 지킵니다.'
where note_id = '3.8.0' and position('[직업] 의무관·진법가의 공격력이' in body) = 0;

update public.world_patch_notes set body = body || E'\n- [기여도] 실제로 깎은 피해를 기여도에 더 크게 셉니다. 진법가가 막아 준 피해를 다른 직업과 같게 세고, 진법가·혈기사·봉인술사의 직업 보정을 낮추고 월궁 사수 보정을 올렸습니다.'
where note_id = '3.8.0' and position('[기여도] 실제로 깎은 피해를 기여도에 더 크게' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127170000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int; a text; b text;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    a := p_pairs[2 * i - 1]; b := p_pairs[2 * i];
    if position(a in d) = 0 and position(E'\r\n' in d) > 0 then a := replace(a, E'\n', E'\r\n'); b := replace(b, E'\n', E'\r\n'); end if;
    n := (length(d) - length(replace(d, a, ''))) / length(a);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, a, b);
  end loop;
  execute d;
end $f$;

alter table public.world_item_locks add column if not exists qty integer;
update public.world_item_locks l set qty = greatest(1,
    coalesce((select (c.inventory ->> l.item_id)::int from public.world_characters c where c.owner_id = l.owner_id), 0)
  + coalesce((select (s.items ->> l.item_id)::int from public.world_storage s where s.owner_id = l.owner_id), 0))
 where l.qty is null;
alter table public.world_item_locks alter column qty set default 1, alter column qty set not null;
alter table public.world_item_locks drop constraint if exists world_item_locks_qty_check;
alter table public.world_item_locks add constraint world_item_locks_qty_check check (qty >= 1);
grant select (qty) on public.world_item_locks to authenticated;
grant update (qty, locked_at) on public.world_item_locks to fn_owner_field;

create or replace function public.world_item_lock_keep(p_uid uuid, p_item text) returns integer language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce((select l.qty from public.world_item_locks l where l.owner_id = p_uid and l.item_id = p_item), 0)
$$;
alter function public.world_item_lock_keep(uuid, text) owner to fn_owner_field;
revoke all on function public.world_item_lock_keep(uuid, text) from public, anon, authenticated;

create or replace function public.world_item_lock_left(p_uid uuid, p_item text, p_bag integer) returns integer language sql stable security definer set search_path = pg_catalog, public as $$
  select case when k.qty is null then 1000000000
    else greatest(0, coalesce(p_bag, (select (c.inventory ->> p_item)::int from public.world_characters c where c.owner_id = p_uid), 0)
      + coalesce((select (s.items ->> p_item)::int from public.world_storage s where s.owner_id = p_uid), 0) - k.qty) end
  from (select (select l.qty from public.world_item_locks l where l.owner_id = p_uid and l.item_id = p_item) as qty) k
$$;
alter function public.world_item_lock_left(uuid, text, integer) owner to fn_owner_field;
revoke all on function public.world_item_lock_left(uuid, text, integer) from public, anon, authenticated;

create or replace function public.world_item_lock_guard(p_uid uuid, p_item text, p_bag integer, p_qty integer) returns void language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare lf int := public.world_item_lock_left(p_uid, p_item, p_bag); nm text;
begin
  if coalesce(p_qty, 0) <= lf then return; end if;
  nm := coalesce((select item_name from public.world_item_catalog where item_id = p_item), '물품');
  if lf <= 0 then
    raise exception '잠근 물품입니다: %. %개를 지키도록 잠가 두어 지금은 내줄 수 없습니다. 가방에서 지킬 수를 줄이거나 잠금을 푸세요.', nm, public.world_item_lock_keep(p_uid, p_item) using hint = 'locked';
  end if;
  raise exception '잠근 물품입니다: %. %개를 지키도록 잠가 두어 %개까지만 내줄 수 있습니다.', nm, public.world_item_lock_keep(p_uid, p_item), lf using hint = 'locked';
end $$;
alter function public.world_item_lock_guard(uuid, text, integer, integer) owner to fn_owner_field;
revoke all on function public.world_item_lock_guard(uuid, text, integer, integer) from public, anon, authenticated;

create or replace function public.world_item_lock(p_item_id text, p_locked boolean, p_qty integer) returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); inv jsonb; nm text; tot int; q int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select inventory into inv from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select item_name into nm from public.world_item_catalog where item_id = p_item_id;
  if nm is null then raise exception '알 수 없는 물품입니다.'; end if;
  if p_locked then
    tot := coalesce((inv ->> p_item_id)::int, 0) + coalesce((select (s.items ->> p_item_id)::int from public.world_storage s where s.owner_id = uid), 0);
    if tot < 1 then raise exception '가지고 있지 않은 물품입니다.'; end if;
    q := coalesce(p_qty, tot);
    if q < 1 or q > tot then raise exception '지킬 수는 1개부터 가진 수(가방·창고 %개)까지 정할 수 있습니다.', tot; end if;
    insert into public.world_item_locks(owner_id, item_id, qty) values (uid, p_item_id, q)
      on conflict (owner_id, item_id) do update set qty = excluded.qty, locked_at = now();
    return jsonb_build_object('ok', true, 'locked', true, 'qty', q, 'content', nm || ' ' || q || '개를 지키도록 잠갔습니다. 그만큼은 팔거나 버리거나 넘길 수 없습니다.');
  end if;
  delete from public.world_item_locks where owner_id = uid and item_id = p_item_id;
  return jsonb_build_object('ok', true, 'locked', false, 'qty', 0, 'content', nm || '의 잠금을 풀었습니다.');
end $$;
alter function public.world_item_lock(text, boolean, integer) owner to fn_owner_field;
revoke all on function public.world_item_lock(text, boolean, integer) from public, anon, authenticated;
grant execute on function public.world_item_lock(text, boolean, integer) to authenticated, service_role;

create or replace function public.world_item_lock(p_item_id text, p_locked boolean) returns jsonb language sql security definer set search_path = '' as $$
  select public.world_item_lock(p_item_id, p_locked, null::integer)
$$;

select pg_temp.yh_fix('world_item_give_guard', array[
  $a$  if exists (select 1 from public.world_item_locks where owner_id = p_owner and item_id = p_item_id) then
    raise exception '잠근 물품입니다: %. 가방에서 잠금을 풀어야 내줄 수 있습니다.', coalesce(nm, '물품');
  end if;$a$,
  $a$  perform public.world_item_lock_guard(p_owner, p_item_id, p_have, p_qty);$a$]);

select pg_temp.yh_fix('world_give_check', array[
  $a$    when exists (select 1 from public.world_item_locks l where l.owner_id = p_uid and l.item_id = p_item) then 0
    else greatest(0, coalesce((p_inv ->> p_item)::int, 0)$a$,
  $a$    else greatest(0, least(public.world_item_lock_left(p_uid, p_item, coalesce((p_inv ->> p_item)::int, 0)), coalesce((p_inv ->> p_item)::int, 0)$a$,
  $a$then 1 else 0 end) end$a$,
  $a$then 1 else 0 end)) end$a$]);

select pg_temp.yh_fix('world_project_have', array[
  $a$'have_st', case when p_st is null or exists (select 1 from public.world_item_locks l where l.owner_id = p_uid and l.item_id = p_item) then 0 else greatest(0, coalesce((p_st ->> p_item)::int, 0)) end,$a$,
  $a$'have_st', case when p_st is null then 0 else greatest(0, least(coalesce((p_st ->> p_item)::int, 0), public.world_item_lock_left(p_uid, p_item, coalesce((p_inv ->> p_item)::int, 0)) - public.world_give_check(p_uid, p_item, p_inv))) end,$a$,
  $a$'hq_st', case when p_st is null or exists (select 1 from public.world_item_locks l where l.owner_id = p_uid and l.item_id = p_item || '_hq') then 0 else greatest(0, coalesce((p_st ->> (p_item || '_hq'))::int, 0)) end)$a$,
  $a$'hq_st', case when p_st is null then 0 else greatest(0, least(coalesce((p_st ->> (p_item || '_hq'))::int, 0), public.world_item_lock_left(p_uid, p_item || '_hq', coalesce((p_inv ->> (p_item || '_hq'))::int, 0)) - public.world_give_check(p_uid, p_item || '_hq', p_inv))) end)$a$]);

select pg_temp.yh_fix('world_project_give', array[
  $a$    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = e.key) then raise exception '「%」은(는) 잠가 둔 물품입니다.', nm; end if;
$a$,
  $a$    perform public.world_item_lock_guard(uid, e.key, coalesce((inv ->> e.key)::int, 0), q);
$a$]);

select pg_temp.yh_fix('world_regular_give', array[
  $a$      if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = cid) then continue; end if;
$a$, '',
  $a$        take_st := least(need, greatest(0, coalesce((st ->> cid)::int, 0)));$a$,
  $a$        take_st := least(need, greatest(0, coalesce((st ->> cid)::int, 0)), greatest(0, public.world_item_lock_left(uid, cid, coalesce((c.inventory ->> cid)::int, 0)) - take_inv));$a$]);

select pg_temp.yh_fix('world_kin_gift', array[
  $a$  if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = p_item) then raise exception '잠근 물품은 줄 수 없습니다. 잠금을 풀고 주세요.'; end if;
$a$, '',
  $a$(장착 중·강화한 것·임무 물품은 빠집니다)$a$, $a$(장착 중·강화한 것·잠가 지키는 몫·임무 물품은 빠집니다)$a$]);

select pg_temp.yh_fix('world_bond_gift', array[
  $a$    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = p_item) then raise exception '잠근 물품은 보낼 수 없습니다. 잠금을 풀고 보내 주세요.'; end if;
    have := coalesce((me.inventory ->> p_item)::int, 0);$a$,
  $a$    have := coalesce((me.inventory ->> p_item)::int, 0);
    perform public.world_item_lock_guard(uid, p_item, have, q);$a$]);

select pg_temp.yh_fix('world_quest_report', array[
  $a$    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = k) then raise exception '잠근 물품은 넘길 수 없습니다. 잠금을 푼 뒤 다시 보고하세요.'; end if;$a$,
  $a$    perform public.world_item_lock_guard(uid, k, coalesce((inv ->> k)::int, 0), lim);$a$]);

select pg_temp.yh_fix('world_storage_discard', array[
  $a$  if exists (select 1 from public.world_item_locks where owner_id = uid and item_id = p_item) then
    raise exception '잠근 물품입니다: %. 가방에서 잠금을 풀어야 버릴 수 있습니다.', nm;
  end if;
  n := least(have, coalesce(nullif(p_qty, 0), have));$a$,
  $a$  n := least(have, coalesce(nullif(p_qty, 0), have));
  perform public.world_item_lock_guard(uid, p_item, null, n);$a$]);

select pg_temp.yh_fix('world_enhance_move', array[
  $a$if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id in (p_from, p_to)) then$a$,
  $a$if public.world_item_lock_keep(uid, p_from) > 0 or public.world_item_lock_keep(uid, p_to) > 0 then$a$]);

select pg_temp.yh_fix('world_enhance_move_info', array[
  $a$'locked', exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = i.item_id))$a$,
  $a$'locked', public.world_item_lock_keep(uid, i.item_id) > 0)$a$]);

update public.world_patch_notes set body = body || E'\n- [가방] 잠금을 그 종류 전체가 아니라 지킬 수만큼 걸게 바꿨습니다. 잠글 때 지킬 수를 고르고(처음엔 가진 수 전부), 그보다 많이 가진 몫은 팔거나 버리거나 넘길 수 있습니다. 지킬 몫에는 강화한 것·장착 중인 것·덜 닳은 것이 먼저 듭니다. 이미 잠가 둔 물품은 지금 가진 수(가방·창고)만큼 지키도록 바뀝니다.'
where note_id = '3.8.0' and position('[가방] 잠금을 그 종류 전체가 아니라 지킬 수만큼' in body) = 0;

update public.world_patch_notes set body = body || E'\n- [사업] 넘길 물품을 고르면 그만큼의 몫과, 이번 단계 목표에서 차지하는 몫이 함께 보입니다.'
where note_id = '3.8.0' and position('[사업] 넘길 물품을 고르면 그만큼의 몫과' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127180000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

create or replace function public.world_item_downgrade(p_item_id text, p_qty integer) returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; bnm text; have int; bhave int; st int; inv jsonb; d public.world_item_durability%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_qty is null or p_qty < 1 or p_qty > 9999 then raise exception '바꿀 수량이 올바르지 않습니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  perform public.world_travel_guard('보통 물품으로 바꾸기');
  if coalesce(c.is_dead, false) then raise exception '현재 상태에서는 바꿀 수 없습니다.'; end if;
  select * into it from public.world_item_catalog where item_id = p_item_id;
  if it.item_id is null then raise exception '알 수 없는 물품입니다.'; end if;
  if it.base_item_id is null or coalesce(it.quality_grade, 0) < 1 then raise exception '우수품만 보통 물품으로 바꿀 수 있습니다.'; end if;
  select item_name into bnm from public.world_item_catalog where item_id = it.base_item_id;
  if bnm is null then raise exception '바꿀 보통 물품이 없습니다.'; end if;
  if it.category = 'quest' then raise exception '임무 물품은 바꿀 수 없습니다.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb); have := coalesce((inv ->> p_item_id)::int, 0); bhave := coalesce((inv ->> it.base_item_id)::int, 0);
  if have < 1 then raise exception '가방에 없는 물품입니다. 창고에 있으면 꺼낸 뒤 바꾸세요.'; end if;
  if have < p_qty then raise exception '가진 수량보다 많이 바꿀 수 없습니다.'; end if;
  if exists (select 1 from public.world_gear_enhance g where g.owner_id = uid and g.item_id = p_item_id and g.level > 0) then
    raise exception '강화한 장비는 보통 물품으로 바꿀 수 없습니다: %.', it.item_name;
  end if;
  perform public.world_item_give_guard(uid, p_item_id, have, p_qty);
  st := coalesce((select (s.items ->> p_item_id)::int from public.world_storage s where s.owner_id = uid), 0);
  if have - p_qty < 1 and st < 1 then
    select * into d from public.world_item_durability where owner_id = uid and item_id = p_item_id;
    if d.item_id is not null and d.durability < d.max_durability then
      raise exception '닳은 장비는 보통 물품으로 바꿀 수 없습니다: %. 수리한 뒤 바꾸세요.', it.item_name;
    end if;
  end if;
  inv := case when have = p_qty then inv - p_item_id else jsonb_set(inv, array[p_item_id], to_jsonb(have - p_qty)) end;
  inv := jsonb_set(inv, array[it.base_item_id], to_jsonb(bhave + p_qty));
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'item', p_item_id, 'base', it.base_item_id, 'qty', p_qty,
    'content', it.item_name || ' ×' || p_qty || '을(를) ' || bnm || '(으)로 바꿨습니다.', 'inventory', inv);
end $$;
revoke all on function public.world_item_downgrade(text, integer) from public, anon, authenticated;
grant execute on function public.world_item_downgrade(text, integer) to authenticated, service_role;
alter function public.world_item_downgrade(text, integer) owner to fn_owner_field;

update public.world_patch_notes set body = body || E'\n- [가방] 우수품을 보통 물품으로 바꿀 수 있습니다. 물품 정보 창에서 수량을 골라 「품질 하향」을 누르면 됩니다(값 없음, 되돌릴 수 없음). 가방에 있는 것만 바뀌고, 잠가 지키는 몫·장착 중인 마지막 하나·강화한 장비·닳은 마지막 장비는 바꿀 수 없습니다.'
where note_id = '3.8.0' and position('[가방] 우수품을 보통 물품으로 바꿀 수 있습니다' in body) = 0;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;
select pg_temp.yh_fix('world_project_rules', array[$a$"day_cap": 8000,$a$, $a$"day_cap": 16000,$a$]);

update public.world_patch_notes set body = body || E'\n- [사업] 한 사람이 하루에 넘길 수 있는 몫을 늘렸습니다(모든 사업 합쳐 8,000 → 16,000).'
where note_id = '3.8.0' and position('[사업] 한 사람이 하루에 넘길 수 있는 몫을 늘렸습니다' in body) = 0;

select pg_temp.yh_fix('world_regular_rules', array[$a$"day_n": 6,$a$, $a$"day_n": 9,$a$]);

update public.world_patch_notes set body = body || E'\n- [연담] 하루에 넘길 수 있는 주문 수를 늘렸습니다(모든 인물 합쳐 6 → 9).'
where note_id = '3.8.0' and position('[연담] 하루에 넘길 수 있는 주문 수를 늘렸습니다' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127190000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;


revoke create on schema public from fn_owner_field;
-- 배포 끝: 앞에서 켠 inherit을 원래대로
do $i$ declare x text; begin for x in select r from yh_inh loop execute format('grant %I to postgres with inherit false', x); end loop; end $i$;
drop table yh_inh;
