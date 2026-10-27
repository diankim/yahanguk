SET ROLE fn_owner_field;
REVOKE EXECUTE ON FUNCTION public.world_inv_add(jsonb, text, integer) FROM anon, authenticated;
RESET ROLE;
