create or replace function public.world_gwiryeong_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object('hold', 1, 'cooldown_h', 72, 'window_days', 3, 'cap_div', 1, 'yohwa_mul', 3, 'party_mul', 2, 'wither_h', 72, 'warn_h', 24)
$function$;
