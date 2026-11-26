select pg_temp.yh_fix('world_busy_kind(uuid)', array[
  '  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = ''active'') then return ''expedition''; end if;',
  '  if public.world_trade_sailing(p_uid) then return ''sailing''; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = p_uid and e.status = ''active'') then return ''expedition''; end if;']);
select pg_temp.yh_fix('world_busy_rules()', array[
  '''idle'', jsonb_build_object(''name'', ''자율 활동''',
  '''sailing'', jsonb_build_object(''name'', ''항해'', ''after'', ''항구에 닿은 뒤에 하세요.''),
    ''idle'', jsonb_build_object(''name'', ''자율 활동''']);
select pg_temp.yh_fix('world_guard_action_context()', array[
  '  IF (k IN (''explore'', ''gather'', ''fish'', ''combat'', ''encounter'', ''expedition_start'') OR (k = ''travel'' AND NOT (p ? ''travel_history_id'')))',
  '  IF NOT (k IN (''progression'', ''mission'', ''supply'', ''case_combine'', ''case_resolved'', ''story'', ''loot'', ''use_item'', ''equip'', ''unequip'', ''downed''))
     AND public.world_trade_sailing(new.actor_id) THEN
    RAISE EXCEPTION ''항해 중에는 할 수 없습니다. 항구에 닿은 뒤 다시 시도하세요.'' USING HINT = ''sailing'';
  END IF;
  IF (k IN (''explore'', ''gather'', ''fish'', ''combat'', ''encounter'', ''expedition_start'') OR (k = ''travel'' AND NOT (p ? ''travel_history_id'')))',
  'IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN (''encounter'', ''combat'') THEN',
  'IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN (''encounter'', ''combat'') AND NOT public.world_trade_raid_on(new.actor_id) THEN']);
select pg_temp.yh_fix('world_pfight_start(uuid,boolean)', array[
  'if n < 2 and not exists (select 1 from public.world_bijang_fights b where b.fight_id = p_fight) then',
  'if n < 2 and not exists (select 1 from public.world_bijang_fights b where b.fight_id = p_fight) and not public.world_trade_is_raid_fight(p_fight) then']);
select pg_temp.yh_fix('world_pfight_ready(uuid,text)', array[
  'and not exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = ''active'')',
  'and not exists (select 1 from public.world_idle_activities i where i.owner_id = p_uid and i.status = ''active'')
    and not public.world_trade_sailing(p_uid)']);
select pg_temp.yh_fix('world_character_purge(uuid)', array[
  '  if p_uid is null then return; end if;',
  '  if p_uid is null then return; end if;
  delete from public.world_trade_aboard where owner_id = p_uid;
  delete from public.world_trade_board where owner_id = p_uid;
  update public.world_ships set status = ''docked'', voyage_id = null where voyage_id in (select v.voyage_id from public.world_trade_voyages v where v.captain_id = p_uid);
  delete from public.world_ships where owner_id = p_uid;
  delete from public.world_trade_voyages where captain_id = p_uid;
  delete from public.world_ship_parts where owner_id = p_uid;
  delete from public.world_ship_hold where owner_id = p_uid;
  delete from public.world_trade_seen where owner_id = p_uid;
  delete from public.world_trade_sales where owner_id = p_uid;']);
select pg_temp.yh_fix('world_hud_snapshot()', array[
  '''battle'', public.world_field_battle_view(uid),',
  '''voyage'', public.world_trade_brief(uid), ''battle'', public.world_field_battle_view(uid),']);
select pg_temp.yh_fix('world_notify_group(text)', array[
  'when p_kind in (''trade_offer'', ''trade_result'', ''ucomm_done'') then ''trade''',
  'when p_kind in (''trade_offer'', ''trade_result'', ''ucomm_done'', ''trade_raid'', ''trade_arrive'') then ''trade''',
  '''party_exp_result'', ''bijang'') then ''party''',
  '''party_exp_result'', ''bijang'', ''trade_board'', ''trade_board_reply'', ''trade_sail'', ''trade_cancel'') then ''party''']);
do $d$
declare a text[] := public.world_sys_chat_names();
begin
  if not ('교역 소식' = any (a)) then
    a := a || '교역 소식'::text;
    execute format('create or replace function public.world_sys_chat_names() returns text[] language sql immutable as %L', format('select %L::text[]', a::text));
  end if;
end $d$;
select pg_temp.yh_fix('world_expedition_settle', array[
  'and (role <> ''guardian'' or depth >= 3)', 'and role <> ''raider'' and (role <> ''guardian'' or depth >= 3)']);
select pg_temp.yh_fix('world_field_snapshot', array[
  'WHERE m.region_id = r.region_id),', 'WHERE m.region_id = r.region_id AND m.role <> ''raider''),',
  'WHERE dm.region_id = r.region_id)', 'WHERE dm.region_id = r.region_id AND dm.role <> ''raider'')']);
