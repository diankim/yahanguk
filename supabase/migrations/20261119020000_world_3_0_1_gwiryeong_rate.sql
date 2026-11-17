create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  if position(p_new in d) > 0 then return; end if;
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

select pg_temp.yh_patch('public.world_gwiryeong_rules()',
  $q$'cap_div', 1,$q$,
  $q$'cap_div', 1, 'rate_mul', 0.25,$q$);

select pg_temp.yh_patch('public.world_gwiryeong_chance(text,jsonb)',
  $q$select case when p_type in ('gw_win', 'raid_win', 'mk_win', 'gg_win', 'by_win') then 0.01 else$q$,
  $q$select (public.world_gwiryeong_rules() ->> 'rate_mul')::numeric * case when p_type in ('gw_win', 'raid_win', 'mk_win', 'gg_win', 'by_win') then 0.01 else$q$);

select pg_temp.yh_patch('public.world_field_search()',
  $q$random() < 0.002 AND public.world_gwiryeong_reserve(uid, 'skill_tracking')$q$,
  $q$random() < 0.002 * (public.world_gwiryeong_rules() ->> 'rate_mul')::numeric AND public.world_gwiryeong_reserve(uid, 'skill_tracking')$q$);

update public.world_skill_catalog set description = '추가 기술 · 위험도 7 이상 지역에서 탐색할 때 0.05% 확률로 귀령초 하나(한 번 얻으면 72시간 다시 나오지 않음)'
 where skill_id = 'tracking_x36' and description <> '추가 기술 · 위험도 7 이상 지역에서 탐색할 때 0.05% 확률로 귀령초 하나(한 번 얻으면 72시간 다시 나오지 않음)';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119020000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
