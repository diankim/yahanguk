do $d$
declare o text := pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_field_search()'::regprocedure));
begin
  if o like 'fn_owner%' then execute format('grant execute on function public.world_party_near_of(uuid) to %I', o); end if;
end $d$;

select pg_temp.yh_patch('public.world_field_search()',
  $q$'node_id', n.node_id, 'danger', r.danger_level, 'location', c.location) || CASE WHEN q_mode > 0 THEN jsonb_build_object('quiet_mode', round((q_mode * 100)::numeric)) ELSE '{}'::jsonb END);$q$,
  $q$'node_id', n.node_id, 'danger', r.danger_level, 'location', c.location) || CASE WHEN q_mode > 0 THEN jsonb_build_object('quiet_mode', round((q_mode * 100)::numeric)) ELSE '{}'::jsonb END
    || CASE WHEN coalesce((public.world_domain_fx(uid) ->> 'white_night')::boolean, false) AND NOT public.world_party_near_of(uid) THEN jsonb_build_object('wn_alone', true) ELSE '{}'::jsonb END);$q$);

select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $q$'rank', a.rank, 'level', a.mlevel, 'loot', loot, 'turns', turn,$q$,
  $q$'rank', a.rank, 'level', a.mlevel, 'loot', loot, 'turns', turn, 'wick', coalesce(loot ? 'lamp_wick_core', false),$q$);
