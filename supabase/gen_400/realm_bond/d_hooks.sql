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

select pg_temp.yh_fix('world_trade_sell_core', array[
  $a$values (p_uid, 'trade_goods_sale', gil_all, false, jsonb_build_object('port', p_port, 'sold', to_jsonb(sold)));$a$,
  $a$values (p_uid, 'trade_goods_sale', gil_all, false, jsonb_build_object('port', p_port, 'sold', to_jsonb(sold)));
    perform public.world_realm_bond_trade(p_uid, p_port, base_add);$a$]);

select pg_temp.yh_fix('world_social_effect', array[
  $a$return v + public.world_project_area_fx(uid, p_key);$a$,
  $a$return v + public.world_project_area_fx(uid, p_key) + public.world_realm_bond_fx(uid, p_key, me.location);$a$]);

select pg_temp.yh_fix('world_shop_buy', array[
  $a$total := s.unit_price * p_qty;$a$,
  $a$total := public.world_realm_bond_price(uid, s.unit_price) * p_qty;$a$]);

select pg_temp.yh_fix('world_shop_snapshot', array[
  $a$'unit_price', case when ss.item_id = 'reset_identity'$a$,
  $a$'unit_price', public.world_realm_bond_price(uid, case when ss.item_id = 'reset_identity'$a$,
  $a$else ss.unit_price end,$a$,
  $a$else ss.unit_price end),$a$]);

select pg_temp.yh_fix('world_smithy_snapshot', array[
  $a$'unit_price', ss.unit_price,$a$,
  $a$'unit_price', public.world_realm_bond_price(uid, ss.unit_price),$a$]);

select pg_temp.yh_fix('world_travel_plan(uuid,text,integer)', array[
  $a$secs := secs * (1 - coalesce((pr ->> 'cut')::numeric, 0));$a$,
  $a$secs := secs * (1 - coalesce((pr ->> 'cut')::numeric, 0));
  secs := secs * (1 + public.world_realm_bond_route(p_uid, here.region_id, dest.region_id) / 100.0);$a$]);

select pg_temp.yh_fix('world_call_rescue', array[
  $a$if own then fee := fee / 2; end if;$a$,
  $a$if own then fee := fee / 2; end if;
  if public.world_realm_bond_fx(uid, 'rescue_half', c.location) > 0 then fee := fee / 2; end if;$a$]);

select pg_temp.yh_fix('world_quest_gate_ok', array[
  $a$case when p_req ? 'regular' then$a$,
  $a$case when p_req ? 'realm_bond' then public.world_realm_bond_pts_of(public.fn_owner_auth_uid(), p_req ->> 'realm_bond') >= coalesce((p_req ->> 'pts')::numeric, 0)
    when p_req ? 'regular' then$a$]);

select pg_temp.yh_fix('world_quest_gate_text', array[
  $a$when p_req ? 'regular' then$a$,
  $a$when p_req ? 'realm_bond' then coalesce(public.world_realm_bond_rules() -> 'realms' -> (p_req ->> 'realm_bond') ->> 'name', '권역') || ' 권역 인연도가 ' || (p_req ->> 'pts') || '에 닿으면 열립니다.'
    when p_req ? 'regular' then$a$]);

select pg_temp.yh_fix('world_title_rule_ok', array[$a$ELSIF p_rule ? 'project' THEN$a$,
  $a$ELSIF p_rule ? 'realm_bond' THEN RETURN public.world_realm_bond_rule_count(p_owner, p_rule) >= n; ELSIF p_rule ? 'project' THEN$a$]);
select pg_temp.yh_fix('world_title_rule_progress', array[$a$elsif p_rule ? 'project' then v :=$a$,
  $a$elsif p_rule ? 'realm_bond' then v := public.world_realm_bond_rule_count(p_owner, p_rule); elsif p_rule ? 'project' then v :=$a$]);
select pg_temp.yh_fix('world_title_award_check', array[$a$IF r ? 'project' AND p_event_type IS NOT NULL AND p_event_type <> 'project' THEN CONTINUE; END IF;$a$,
  $a$IF r ? 'realm_bond' AND p_event_type IS NOT NULL AND p_event_type <> 'realm_bond' THEN CONTINUE; END IF;
    IF p_event_type = 'realm_bond' AND NOT (r ? 'realm_bond') THEN CONTINUE; END IF;
    IF r ? 'project' AND p_event_type IS NOT NULL AND p_event_type <> 'project' THEN CONTINUE; END IF;$a$]);

select pg_temp.yh_fix('world_notify_group', array[$a$'faction_week', 'feast') then 'faction'$a$, $a$'faction_week', 'feast', 'realm_bond') then 'faction'$a$]);

select pg_temp.yh_fix('world_character_purge', array[$a$delete from public.world_faction_progress where owner_id = p_uid;$a$,
  $a$delete from public.world_faction_progress where owner_id = p_uid;
  delete from public.world_realm_bonds where owner_id = p_uid;
  delete from public.world_realm_bond_claims where owner_id = p_uid;$a$]);
