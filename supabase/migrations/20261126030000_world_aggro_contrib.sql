create or replace function public.world_presence_rules() returns jsonb
language sql immutable
as $$
  select jsonb_build_object('cap', jsonb_build_object('artificer', 300, 'bloodknight', 300, 'sealmaster', 220), 'cap_other', 160, 'aggro_pow', 1.5)
$$;

create or replace function public.world_cb_aggro(p_pres numeric) returns numeric
language sql immutable
as $$ select power(greatest(5, coalesce(p_pres, 30)), (public.world_presence_rules() ->> 'aggro_pow')::numeric) $$;

create or replace function public.world_cb_pick_key(p_pres numeric) returns double precision
language sql volatile
as $$ select -ln(greatest(random(), 1e-9)) / power(greatest(5, coalesce(p_pres, 30)), (public.world_presence_rules() ->> 'aggro_pow')::numeric)::float8 $$;

do $m$
declare v jsonb := public.world_contrib_rules();
begin
  v := jsonb_set(jsonb_set(v, '{job_mul,bloodknight}', '1.2'), '{job_mul,spearman}', '1.0');
  execute format('create or replace function public.world_contrib_rules() returns jsonb language sql immutable set search_path = pg_catalog as %L', ' select ' || quote_literal(v::text) || '::jsonb ');
end $m$;

update public.world_patch_notes set body = body || E'\n- 합동 토벌·귀허류 싸움·파티 토벌·파티 원정에서 요괴가 이목이 높은 사람을 전보다 더 자주 노립니다.\n- 싸움 기여도의 직업 보정을 고쳤습니다. 혈기사는 올리고 여명 창객은 조금 내렸습니다.'
 where note_id = '3.7.0' and body not like '%이목이 높은 사람을 전보다 더 자주%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126030000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
