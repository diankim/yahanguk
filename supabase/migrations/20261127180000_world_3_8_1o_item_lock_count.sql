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

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127180000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
