create or replace function public.world_invite_rules()
 returns jsonb language sql immutable
as $function$
  select '{"cap":100,"days":7}'::jsonb
$function$;

do $p$
declare d text := pg_get_functiondef('public.world_invite_distribute()'::regprocedure);
begin
  if position('greatest(0, 60 - accts)' in d) = 0 then raise exception '정원 자리를 못 찾음'; end if;
  execute replace(d, 'greatest(0, 60 - accts)', 'greatest(0, (public.world_invite_rules() ->> ''cap'')::int - accts)');
end $p$;
