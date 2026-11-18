create or replace function public.world_title_ev_hit(r jsonb, ev text, pl jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select case
    when r ? 'all' then exists (select 1 from jsonb_array_elements(r -> 'all') s where public.world_title_ev_hit(s, ev, pl))
    when not (r ? 'ev') then true
    when r ->> 'ev' <> ev then false
    else (not r ? 'p' or pl @> (r -> 'p'))
     and (not r ? 'has' or pl ? (r ->> 'has'))
     and (not r ? 'phase' or coalesce(pl ->> 'env_phase', r ->> 'phase') = r ->> 'phase')
  end
$$;
revoke all on function public.world_title_ev_hit(jsonb, text, jsonb) from public, anon, authenticated;
alter function public.world_title_ev_hit(jsonb, text, jsonb) owner to fn_owner_field;

select pg_temp.yh_fix('world_title_award_check(uuid,text)', array[
  E'DECLARE t record; got int := 0; last_outcome text; r jsonb;',
  E'DECLARE t record; got int := 0; last_outcome text; r jsonb; ev_pl jsonb := nullif(current_setting(''yh.title_ev'', true), '''')::jsonb;',
  E'    IF r ? ''codex'' AND',
  E'    IF ev_pl IS NOT NULL AND NOT public.world_title_ev_hit(r, p_event_type, ev_pl) THEN CONTINUE; END IF;\n    IF r ? ''codex'' AND'
]);

select pg_temp.yh_fix('world_apply_activity_status()', array[
  E' perform public.world_title_award_check(new.actor_id,new.event_type);',
  E' perform set_config(''yh.title_ev'', coalesce(new.payload, ''{}''::jsonb)::text, true);\n perform public.world_title_award_check(new.actor_id,new.event_type);\n perform set_config(''yh.title_ev'', '''', true);'
]);

select pg_temp.yh_fix('world_fish()', array[
  E'  perform public.world_title_award_check(uid, ''fish'');\n  return jsonb_build_object(''ok'', true, ''caught'', true,',
  E'  return jsonb_build_object(''ok'', true, ''caught'', true,'
]);

select pg_temp.yh_fix('world_cosmetic_award_check(uuid,text)', array[
  E'declare t record; got int := 0; r jsonb; kname text;',
  E'declare t record; got int := 0; r jsonb; kname text; ev_pl jsonb := nullif(current_setting(''yh.title_ev'', true), '''')::jsonb;',
  E'      if r ? ''mounts'' and p_event_type not in',
  E'      if r ? ''tourney'' and p_event_type <> ''tourney'' then continue; end if;\n      if r ? ''home'' and p_event_type <> ''home'' then continue; end if;\n      if ev_pl is not null and not public.world_title_ev_hit(r, p_event_type, ev_pl) then continue; end if;\n      if r ? ''mounts'' and p_event_type not in'
]);
