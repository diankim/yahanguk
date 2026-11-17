create or replace function public.world_rt_out()
 returns trigger language plpgsql security definer set search_path = pg_catalog, public
as $function$
declare j jsonb;
begin
  if tg_table_name = 'world_notifications' then
    perform realtime.send(jsonb_build_object('new', to_jsonb(new)), 'note', 'note:' || new.user_id::text, true);
  elsif tg_table_name = 'world_chat_messages' then
    j := jsonb_build_object('new', to_jsonb(new));
    if new.channel_type = 'global' then perform realtime.send(j, 'msg', 'chat:global', true);
    elsif new.channel_type = 'region' and new.region is not null then perform realtime.send(j, 'msg', 'chat:region:' || new.region, true);
    elsif new.channel_type = 'faction' and new.faction_id is not null then perform realtime.send(j, 'msg', 'chat:faction:' || new.faction_id, true);
    elsif new.channel_type = 'whisper' then
      if new.recipient_id is not null then perform realtime.send(j, 'msg', 'whisper:' || new.recipient_id::text, true); end if;
      if new.sender_id is not null and new.sender_id is distinct from new.recipient_id then perform realtime.send(j, 'msg', 'whisper:' || new.sender_id::text, true); end if;
    end if;
  elsif tg_table_name = 'world_party_messages' then
    perform realtime.send(jsonb_build_object('new', to_jsonb(new)), 'msg', 'party:' || new.party_id::text, true);
  elsif tg_table_name = 'world_circle_messages' then
    perform realtime.send(jsonb_build_object('new', to_jsonb(new)), 'msg', 'circle:' || new.circle_id::text, true);
  elsif tg_table_name = 'world_raids' then
    if new.status <> 'announced' then
      j := jsonb_build_object('new', jsonb_build_object('raid_id', new.raid_id, 'status', new.status, 'hp', new.hp, 'phase', new.phase, 'intent', new.intent));
      perform realtime.send(j, 'change', 'raid:' || new.raid_id::text, true);
      perform realtime.send(j, 'change', 'raid:any', true);
    end if;
  elsif tg_table_name = 'world_gw_fights' then
    perform realtime.send(jsonb_build_object('id', new.fight_id, 'round', new.round, 'phase', new.phase, 'status', new.status), 'change', 'gw:' || new.fight_id::text, true);
  elsif tg_table_name = 'world_active_sessions' then
    perform realtime.send(jsonb_build_object('at', now()), 'claim', 'session:' || new.owner_id::text, true);
  end if;
  return null;
end $function$;

create or replace function public.world_rt_can(p_topic text)
 returns boolean language plpgsql stable security definer set search_path = pg_catalog, public
as $function$
declare uid uuid := auth.uid(); k text; v text; f public.world_gw_fights%rowtype; rg text;
begin
  if uid is null or p_topic is null then return false; end if;
  if p_topic in ('session:' || uid::text, 'note:' || uid::text, 'whisper:' || uid::text, 'chat:global', 'raid:any') then return true; end if;
  if p_topic like 'raid:%' then return true; end if;
  if p_topic like 'chat:region:%' then
    return substr(p_topic, 13) = (select c.location from public.world_characters c where c.owner_id = uid);
  end if;
  if p_topic like 'chat:faction:%' then
    return substr(p_topic, 14) = (select c.major_faction_id from public.world_characters c where c.owner_id = uid);
  end if;
  k := split_part(p_topic, ':', 1); v := substr(p_topic, length(k) + 2);
  if k = 'party' then return exists (select 1 from public.world_party_members m where m.party_id::text = v and m.owner_id = uid); end if;
  if k = 'circle' then return exists (select 1 from public.world_circle_members m where m.circle_id::text = v and m.owner_id = uid); end if;
  if k = 'gw' then
    if v !~ '^[0-9a-f-]{36}$' then return false; end if;
    select * into f from public.world_gw_fights x where x.fight_id = v::uuid;
    if f.fight_id is null then return false; end if;
    if exists (select 1 from public.world_gw_members m where m.fight_id = f.fight_id and m.owner_id = uid) then return true; end if;
    if exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id where a.owner_id = f.leader_id and b.owner_id = uid) then return true; end if;
    rg := coalesce(public.world_ultimate_rules() -> 'boards' -> (f.board -> 'ug' ->> 'board') ->> 'region', public.world_boss_rules() -> coalesce(f.board -> 'ug' ->> 'board', f.boss_id) ->> 'region');
    return rg is not null and (select (public.world_region_at(c.location)).region_id from public.world_characters c where c.owner_id = uid) = rg;
  end if;
  return false;
end $function$;

drop trigger if exists trg_world_rt_out on public.world_gw_fights;
create trigger trg_world_rt_out after update of round, status on public.world_gw_fights for each row
  when (old.round is distinct from new.round or old.status is distinct from new.status) execute function public.world_rt_out();
