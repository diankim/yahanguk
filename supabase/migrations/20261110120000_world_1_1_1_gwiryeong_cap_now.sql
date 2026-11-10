create or replace function public.world_gwiryeong_reserve(p_uid uuid, p_source text)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare cap int; ru jsonb := public.world_gwiryeong_rules(); win interval;
begin
  if p_uid is null then return false; end if;
  win := make_interval(days => (ru ->> 'window_days')::int);
  if exists (select 1 from public.world_gwiryeong_log l where l.owner_id = p_uid and l.got_at > now() - make_interval(hours => (ru ->> 'cooldown_h')::int)) then return false; end if;
  if coalesce((select h.n from public.world_gwiryeong_held() h where h.owner_id = p_uid), 0) >= (ru ->> 'hold')::int then return false; end if;
  perform pg_advisory_xact_lock(hashtext('yh-gwiryeong-week'));
  cap := greatest(1, (select count(distinct s.owner_id) from public.world_character_statuses s where s.status_key = 'yohwa')::int / (ru ->> 'cap_div')::int);
  if (select count(*) from public.world_gwiryeong_log l where l.got_at > now() - win) >= cap then return false; end if;
  insert into public.world_gwiryeong_log(owner_id, source) values (p_uid, p_source);
  return true;
end $function$;
alter function public.world_gwiryeong_reserve(uuid, text) owner to fn_owner_field;
