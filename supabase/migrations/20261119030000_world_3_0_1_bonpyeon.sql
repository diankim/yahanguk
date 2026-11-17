create or replace function pg_temp.yh_repl(p_fn text, p_old text, p_new text) returns void
language plpgsql as $$
declare d text; o text;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  if position(p_old in d) = 0 then return; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

select pg_temp.yh_repl('public.world_boss_rules()', '"arc": "외전 · ', '"arc": "');
select pg_temp.yh_repl('public.world_boss_rules()', '"외전 4장 「', '"「요인록」 4장 「');
select pg_temp.yh_repl('public.world_boss_rules()', '"외전 「', '"「');
select pg_temp.yh_repl('public.world_gw_ready_check(uuid,text,text)', '''외전 4장 「달 없는 장」을', '''「요인록」 4장 「달 없는 장」을');
select pg_temp.yh_repl('public.world_project_view(text)', '''혜택은 외전 「''', '''혜택은 「''');

do $$ begin
  if exists (select 1 from pg_proc where proname in ('world_boss_rules', 'world_gw_ready_check', 'world_project_view') and prosrc ~ '외전 [「·0-9]') then
    raise exception '외전 문구가 남았습니다';
  end if;
end $$;

update public.world_patch_notes set body = body || $N$
- 도움말·싸움 화면에서 「요인록」·「묵적록」·「명등기」를 「외전」이 아니라 「홍인사」와 이어지는 본편으로 적습니다. 도움말 「사건과 일지」에 본편 네 이야기와 「홍인사」 소개를 넣고, 귀령초 확률표가 숫자로 나오게 고쳤습니다.$N$ where note_id = '3.0.0' and position($N$- 도움말·싸움 화면에서 「요인록」·「묵적록」·「명등기」를 「외전」이 아니라 「홍인사」와 이어지는 본편으로 적습니다. 도움말 「사건과 일지」에 본편 네 이야기와 「홍인사」 소개를 넣고, 귀령초 확률표가 숫자로 나오게 고쳤습니다.$N$ in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119030000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
