create or replace function public.world_xp_lead_rules() returns jsonb language sql immutable as $f$
  select jsonb_build_object('lead', 3, 'active_days', 2,
    'steps', jsonb_build_array(jsonb_build_array(3, 80), jsonb_build_array(5, 60), jsonb_build_array(7, 45),
                               jsonb_build_array(9, 30), jsonb_build_array(11, 20), jsonb_build_array(13, 12), jsonb_build_array(15, 6)))
$f$;
revoke all on function public.world_xp_lead_rules() from public, anon, authenticated;
