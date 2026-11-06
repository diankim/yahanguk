alter table public.world_pfight_members add column if not exists weak text;
alter table public.world_raid_log add column if not exists who text;
alter table public.world_raid_log add column if not exists n integer;

create or replace function public.world_raid_say_n(p_raid uuid, p_kind text, p_text text, p_who text, p_n integer)
 returns void
 language sql
 security definer
 set search_path to ''
as $function$
  insert into public.world_raid_log(raid_id, kind, text, who, n) values (p_raid, p_kind, p_text, p_who, p_n)
$function$;
alter function public.world_raid_say_n(uuid, text, text, text, integer) owner to fn_owner_field;
revoke all on function public.world_raid_say_n(uuid, text, text, text, integer) from public, anon, authenticated;
grant execute on function public.world_raid_say_n(uuid, text, text, text, integer) to service_role;

create or replace function public.world_notify_group(p_kind text)
 returns text
 language sql
 immutable
 set search_path to 'pg_catalog'
as $function$
  select case
    when p_kind in ('title', 'cosmetic') then 'title'
    when p_kind in ('reward', 'skill_rerank') then 'reward'
    when p_kind in ('bag_full', 'bag_overflow') then 'bag'
    when p_kind in ('rescue_request') then 'rescue'
    when p_kind in ('friend_down') then 'friend_rescue'
    when p_kind in ('trade_offer', 'trade_result', 'ucomm_done') then 'trade'
    when p_kind in ('friend_request', 'friend_accepted') then 'friend'
    when p_kind in ('ride_request', 'party_invite', 'party_expedition', 'party_exp_offer', 'party_leave', 'party_aid', 'pfight_invite', 'pfight_join') then 'party'
    when p_kind in ('circle_invite') then 'circle'
    when p_kind in ('letter') then 'letter'
    when p_kind in ('spar_request', 'spar_result', 'tourney_alert', 'tourney_result', 'tourney_partner') then 'spar'
    when p_kind like 'bond%' or p_kind = 'wedding_invite' then 'bond'
    when p_kind in ('faction', 'faction_open', 'faction_week') then 'faction'
    when p_kind in ('raid_invite', 'raid_vote', 'raid', 'raid_result', 'gw', 'gw_invite') then 'raid'
    when p_kind in ('housing_visit', 'housing_guest', 'housing_item', 'housing_merge', 'pet_play', 'pet_new') then 'housing'
    else null end
$function$;

