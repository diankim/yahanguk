create or replace function public.world_xp_lead_rules() returns jsonb language sql immutable as $f$
  select jsonb_build_object('lead', 3, 'active_days', 2,
    'steps', jsonb_build_array(jsonb_build_array(3, 85), jsonb_build_array(5, 70), jsonb_build_array(7, 55),
                               jsonb_build_array(9, 40), jsonb_build_array(11, 30), jsonb_build_array(13, 20)))
$f$;
revoke all on function public.world_xp_lead_rules() from public, anon, authenticated;
select public.world_xp_avg_refresh();
