create or replace function pg_temp.yh_fix(p_name text, p_pairs text[], p_n int) returns void language plpgsql as $f$
declare d text; i int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> p_n then raise exception '함수 % 모양이 예상과 다릅니다', p_name; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_housekeeping', array[
$q$  delete from public.world_letter_sends where day < (now() at time zone 'Asia/Seoul')::date - 2;$q$,
$q$  delete from public.world_letter_sends where day < (now() at time zone 'Asia/Seoul')::date - 2;
  delete from public.world_drawing_made where made_at < now() - interval '2 days';$q$], 1);

select pg_temp.yh_fix('world_notify_group', array[
$q$'pfight_invite', 'pfight_join') then 'party'$q$,
$q$'pfight_invite', 'pfight_join', 'party_exp_departed', 'party_exp_result') then 'party'$q$,
$q$'raid_result', 'gw', 'gw_invite') then 'raid'$q$,
$q$'raid_result', 'raid_notice', 'gw', 'gw_invite') then 'raid'$q$], 1);

select pg_temp.yh_fix('world_pet_act', array[
$q$  if p_act not in ('pat', 'play', 'feed') then raise exception '알 수 없는 놀이입니다.'; end if;$q$,
$q$  perform public.world_seal_guard();
  if p_act not in ('pat', 'play', 'feed') then raise exception '알 수 없는 놀이입니다.'; end if;$q$], 1);

select pg_temp.yh_fix('world_pet_care', array[
$q$  if p_act not in ('clean', 'cure') then raise exception '알 수 없는 돌보기입니다.'; end if;$q$,
$q$  perform public.world_seal_guard();
  if p_act not in ('clean', 'cure') then raise exception '알 수 없는 돌보기입니다.'; end if;$q$], 1);

create or replace function public.world_shop_sell_cap()
 returns bigint language sql stable
as $f$ select 2000 + public.world_affil_cap()::bigint $f$;
revoke all on function public.world_shop_sell_cap() from public, anon, authenticated;
grant execute on function public.world_shop_sell_cap() to fn_owner_field, fn_owner_18878;

select pg_temp.yh_fix('world_shop_sell', array[$q$cap := 2000 + public.world_affil_cap();$q$, $q$cap := public.world_shop_sell_cap();$q$], 1);
select pg_temp.yh_fix('world_shop_sell_status', array[$q$cap := 2000 + public.world_affil_cap();$q$, $q$cap := public.world_shop_sell_cap();$q$], 1);

do $p$
declare d text := pg_get_functiondef('public.world_character_purge(uuid)'::regprocedure);
  a text := 'delete from public.world_drawing_made where owner_id = p_uid;';
begin
  if position('world_bond_requests' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '캐릭터 정리 함수 모양이 예상과 다릅니다'; end if;
  execute replace(d, a, a || $q$
  update public.world_bond_requests set status = 'canceled' where status = 'pending' and from_id = p_uid;
  with x as (update public.world_bond_requests set status = 'canceled' where status = 'pending' and to_id = p_uid returning from_id, cost)
  update public.world_characters c set gil = c.gil + x.cost, updated_at = now() from x where c.owner_id = x.from_id;
  perform public.world_bond_note(case when b.a_id = p_uid then b.b_id else b.a_id end, 'bond_broken', '정표가 파기되었습니다',
    coalesce((select character_name from public.world_characters where owner_id = p_uid), '정인') || '님이 연리를 끝냈습니다.', jsonb_build_object('bond_id', b.bond_id))
    from public.world_bonds b where b.ended_at is null and (b.a_id = p_uid or b.b_id = p_uid);
  update public.world_bonds set ended_at = coalesce(ended_at, now()), ended_by = coalesce(ended_by, p_uid),
    a_cleared = a_cleared or a_id = p_uid, b_cleared = b_cleared or b_id = p_uid
   where (a_id = p_uid or b_id = p_uid) and (ended_at is null or (a_id = p_uid and not a_cleared) or (b_id = p_uid and not b_cleared));$q$);
end $p$;

update public.world_patch_notes set body = body || E'\n- 파티 원정 출발·결과 알림과 봉연 예고 알림도 설정 › 알림에서 끌 수 있습니다. 봉인 중에는 별채 동무를 돌볼 수 없습니다. 캐릭터를 정리하면 맺은 연리와 오가던 연리 신청도 함께 끝납니다(신청한 쪽에는 정표 값을 돌려줍니다).'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109130000' where key = 'db_version';
