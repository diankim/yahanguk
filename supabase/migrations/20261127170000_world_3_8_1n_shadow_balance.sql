create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_combat_stats', array[
  $a$WHEN c.job_key = 'bloodknight' THEN 0.9 WHEN$a$,
  $a$WHEN c.job_key = 'bloodknight' THEN 0.9 WHEN c.job_key IN ('medic', 'formation') THEN 0.9 WHEN$a$]);

select pg_temp.yh_fix('world_contrib_rules', array[
  $a$"deal": 0.6,$a$, $a$"deal": 0.65,$a$,
  $a$"heal": 0.1,$a$, $a$"heal": 0.05,$a$,
  $a$"hold": 0.2,$a$, $a$"hold": 0.15,$a$,
  $a$"result": 0.2,$a$, $a$"result": 0.4,$a$,
  $a$"scout": 0.88,$a$, $a$"scout": 1.0,$a$,
  $a$"formation": 1.3,$a$, $a$"formation": 1.0,$a$,
  $a$"sealmaster": 1.35,$a$, $a$"sealmaster": 1.2,$a$,
  $a$"bloodknight": 1.2}$a$, $a$"bloodknight": 1.1}$a$,
  $a$"guard_mul": {"formation": 2.0}$a$, $a$"guard_mul": {"formation": 1.0}$a$]);

select pg_temp.yh_fix('world_shadow_rules', array[$a$"hp_mul": 350,$a$, $a$"hp_mul": 450,$a$]);

update public.world_patch_notes set body = body || E'\n- [그림자] 사슬 벗은 그림자의 체력이 늘어, 다 함께 쳐도 10~15분쯤 걸리게 했습니다.'
where note_id = '3.8.0' and position('[그림자] 사슬 벗은 그림자의 체력이 늘어' in body) = 0;

update public.world_patch_notes set body = body || E'\n- [직업] 의무관·진법가의 공격력이 ×0.9가 됩니다(모든 싸움). 치유를 맡는 직업이 공격수만큼 때리지 않게 했습니다.'
where note_id = '3.8.0' and position('[직업] 의무관·진법가의 공격력이 ×0.9' in body) = 0;

update public.world_patch_notes set body = body || E'\n- [기여도] 실제로 깎은 피해를 기여도에 더 크게 셉니다. 진법가가 막아 준 피해를 다른 직업과 같게 세고, 진법가·혈기사·봉인술사의 직업 보정을 낮추고 월궁 사수 보정을 올렸습니다.'
where note_id = '3.8.0' and position('[기여도] 실제로 깎은 피해를 기여도에 더 크게' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127170000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
