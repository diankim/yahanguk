create or replace function public.world_party_near_of(p_uid uuid) returns boolean
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
begin
  return exists (select 1 from public.world_party_members a
    join public.world_party_members b on b.party_id = a.party_id and b.owner_id <> a.owner_id
    join public.world_characters me on me.owner_id = a.owner_id
    join public.world_characters o on o.owner_id = b.owner_id
   where a.owner_id = p_uid and o.location = me.location and o.downed_at is null and coalesce(o.health, 0) > 0
     and (o.travel_arrives_at is null or o.travel_arrives_at <= now()));
end $$;
revoke all on function public.world_party_near_of(uuid) from public, anon, authenticated;
grant execute on function public.world_party_near_of(uuid) to fn_owner_field;

create or replace function public.world_party_near() returns boolean
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
begin
  return public.world_party_near_of(public.fn_owner_auth_uid());
end $$;
revoke all on function public.world_party_near() from public, anon;
grant execute on function public.world_party_near() to authenticated;
do $d$
declare o text;
begin
  for o in select rolname from pg_roles where rolname like 'fn_owner%' loop
    execute format('grant execute on function public.world_party_near() to %I', o);
  end loop;
end $d$;

select pg_temp.yh_patch('public.world_status_self(uuid,text)',
  $q$where cs.owner_id = p_owner and cs.expires_at > now() and (cat.effects ->> p_key) ~ '^-?[0-9]+(\.[0-9]+)?$'$q$,
  $q$where cs.owner_id = p_owner and cs.expires_at > now() and (cat.effects ->> p_key) ~ '^-?[0-9]+(\.[0-9]+)?$'
     and (not (cat.effects ? 'party_only') or public.world_party_near_of(p_owner))$q$);
select pg_temp.yh_patch('public.world_status_effect_total(text)',
  $q$ where cs.owner_id=public.fn_owner_auth_uid() and cs.expires_at>now()$q$,
  $q$ where cs.owner_id=public.fn_owner_auth_uid() and cs.expires_at>now() and (not (cat.effects ? 'party_only') or public.world_party_near())$q$);
