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

create or replace function public.world_gwiryeong_full() returns boolean
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare ru jsonb := public.world_gwiryeong_rules();
begin
  return (select count(*) from public.world_gwiryeong_log l where l.got_at > now() - make_interval(days => (ru ->> 'window_days')::int))
    >= greatest(1, (select count(distinct s.owner_id) from public.world_character_statuses s where s.status_key = 'yohwa')::int / (ru ->> 'cap_div')::int);
end $$;
revoke all on function public.world_gwiryeong_full() from public, anon, authenticated;
grant execute on function public.world_gwiryeong_full() to fn_owner_field;

select pg_temp.yh_patch('public.world_gwiryeong_reserve(uuid,text)',
  $q$  cap := greatest(1, (select count(distinct s.owner_id) from public.world_character_statuses s where s.status_key = 'yohwa')::int / (ru ->> 'cap_div')::int);
  if (select count(*) from public.world_gwiryeong_log l where l.got_at > now() - win) >= cap then return false; end if;$q$,
  $q$  if public.world_gwiryeong_full() then return false; end if;$q$);

create or replace function public.world_gwiryeong_mine() returns jsonb
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); ru jsonb := public.world_gwiryeong_rules(); cd timestamptz; why text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  cd := (select max(l.got_at) from public.world_gwiryeong_log l where l.owner_id = uid) + make_interval(hours => (ru ->> 'cooldown_h')::int);
  why := case when coalesce((select h.n from public.world_gwiryeong_held() h where h.owner_id = uid), 0) >= (ru ->> 'hold')::int then 'hold'
              when cd > now() then 'cooldown' end;
  return jsonb_build_object('plants', coalesce((select jsonb_agg(jsonb_build_object('until', p.expires_at) order by p.expires_at)
      from public.world_gwiryeong_plants p where p.holder = uid and p.ended is null and p.expires_at > now()), '[]'::jsonb),
    'warn_h', (ru ->> 'warn_h')::int,
    'can', jsonb_build_object('open', not public.world_gwiryeong_full(), 'why', why, 'until', case when why = 'cooldown' then cd end));
end $$;

update public.world_patch_notes set body = body || $N$

## 3.0.2
- 귀령초 물품 정보와 도움말 귀령초 칸에 「지금 서버에서 귀령초가 나올 수 있는 때인지」가 한 줄로 보입니다. 내가 최근에 얻었거나 이미 지니고 있어 나에게만 안 나오는 때도 함께 적힙니다.$N$
 where note_id = '3.0.0' and position('## 3.0.2' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119050000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
