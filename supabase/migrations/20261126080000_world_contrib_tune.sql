do $m$
declare v jsonb := public.world_contrib_rules();
begin
  v := jsonb_set(jsonb_set(jsonb_set(v, '{heal}', '0.1'), '{guard_mul,formation}', '2.0'), '{job_mul,formation}', '1.3');
  execute format('create or replace function public.world_contrib_rules() returns jsonb language sql immutable set search_path = pg_catalog as %L', ' select ' || quote_literal(v::text) || '::jsonb ');
  v := jsonb_set(public.world_shadow_rules(), '{mk2,brand,hold}', '0.5');
  execute format('create or replace function public.world_shadow_rules() returns jsonb language sql immutable set search_path = pg_catalog as %L', ' select ' || quote_literal(v::text) || '::jsonb ');
end $m$;

do $m$
declare src text; def text; fn regprocedure; o text;
begin
  fn := 'public.world_raid_hit'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := '    perform public.world_raid_credit(p_raid, (c ->> 0)::uuid, (c ->> 1)::numeric, c ->> 2);';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_hit 기여 고리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '    perform public.world_raid_credit(p_raid, (c ->> 0)::uuid, (c ->> 1)::numeric * case when p_kind = ''buster'' and c ->> 2 = ''guard'' and (c ->> 0)::uuid = who then (public.world_shadow_rules() -> ''mk2'' -> ''brand'' ->> ''hold'')::numeric else 1 end, c ->> 2);');
  o := '    if self_guard > 0 then perform public.world_raid_credit(p_raid, who, self_guard, ''guard''); end if;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_hit 스스로 막은 몫 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '    if p_kind = ''buster'' then self_guard := self_guard * (public.world_shadow_rules() -> ''mk2'' -> ''brand'' ->> ''hold'')::numeric; end if;' || chr(10) || o);
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

update public.world_patch_notes set body = body || E'\n- 싸움 기여도에서 동료를 돌본 몫(회복)을 전보다 무겁게 셉니다.\n- 진법가가 막아 준 피해를 기여도에 더 크게 셉니다.\n- 사슬 벗은 그림자의 검은 낙인을 받아 낸 몫은 기여도의 버팀에 절반만 셉니다.'
 where note_id = '3.7.0' and body not like '%동료를 돌본 몫(회복)을 전보다 무겁게%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126080000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
