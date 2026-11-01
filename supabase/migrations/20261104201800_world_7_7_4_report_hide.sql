-- 7.7.4 — 보낸 제보 지우기(사용자 전달 제보, 이상혁 2026-11-01).
-- 행을 지우지 않고 보낸 사람 목록에서만 감춘다(owner_hidden). 운영진 받은 제보 칸에는 「보낸 이가 지움」으로 남아 처리 기록이 사라지지 않는다.
alter table public.world_bug_reports add column if not exists owner_hidden boolean not null default false;

create or replace function public.world_bug_report_hide(p_report bigint)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  update public.world_bug_reports set owner_hidden = true where report_id = p_report and owner_id = uid and not owner_hidden;
  if not found then raise exception '내가 보낸 제보만 지울 수 있습니다.'; end if;
  return jsonb_build_object('ok', true, 'content', '제보를 목록에서 지웠습니다.');
end $function$;
revoke all on function public.world_bug_report_hide(bigint) from public, anon;
grant execute on function public.world_bug_report_hide(bigint) to authenticated;

do $p$
declare r record; d text; n int; own text;
begin
  for r in
    select * from (values
      ('public.world_bug_report_list(text)'::regprocedure, $A$'status', r.status, 'reply'$A$, $B$'status', r.status, 'hidden', r.owner_hidden, 'reply'$B$),
      ('public.world_bug_report_list(text)'::regprocedure, $A$((select is_gm from gm) or r.owner_id = me.uid)$A$, $B$((select is_gm from gm) or (r.owner_id = me.uid and not r.owner_hidden))$B$)
    ) x(fn, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.4 report hide anchor (% of 1): %', n, r.a; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
  end loop;
end $p$;

update public.world_app_meta set value = '20261104201800' where key = 'db_version';
