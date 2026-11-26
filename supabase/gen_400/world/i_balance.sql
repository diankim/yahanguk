select pg_temp.yh_fix('world_combat_stats', array[
  $a$WHEN c.job_key = 'bloodknight' THEN 0.9 WHEN$a$,
  $a$WHEN c.job_key = 'bloodknight' THEN 0.9 WHEN c.job_key IN ('medic', 'formation') THEN 0.9 WHEN$a$]);

select pg_temp.yh_fix('world_contrib_rules', array[
  $a$"heal": 0.1,$a$, $a$"heal": 0.05,$a$,
  $a$"medic": 0.98,$a$, $a$"medic": 0.8,$a$,
  $a$"formation": 1.3,$a$, $a$"formation": 1.0,$a$,
  $a$"guard_mul": {"formation": 2.0}$a$, $a$"guard_mul": {"formation": 1.0}$a$]);

select pg_temp.yh_fix('world_shadow_rules', array[$a$"hp_mul": 350,$a$, $a$"hp_mul": 450,$a$]);
