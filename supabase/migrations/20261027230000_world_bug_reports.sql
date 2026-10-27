-- 버그·문의 제보: 조사원이 GM(world_staff)에게 직접 보내는 창
-- - world_bug_reports: 분류(오류·화면·밸런스·제안·기타)·제목·내용과, 보낸 때의 화면 위치·기기·최근 오류 기록(context)을 남긴다.
-- - 보내면 모든 GM에게 알림(kind = bug_report)이 가고, GM이 답하면 보낸 사람에게 알림(kind = bug_reply)이 간다.
-- - 조사원은 자기 제보만, GM은 모든 제보를 본다(함수로만 읽고 쓴다). 한 사람이 1시간에 5건까지 보낸다.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

create table if not exists public.world_bug_reports (
  report_id bigint generated always as identity primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  character_name text,
  category text not null default 'bug' check (category in ('bug', 'screen', 'balance', 'idea', 'other')),
  title text not null,
  body text not null,
  context jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (status in ('open', 'checking', 'fixed', 'closed')),
  reply text,
  replied_by uuid,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists world_bug_reports_owner on public.world_bug_reports(owner_id, created_at desc);
create index if not exists world_bug_reports_status on public.world_bug_reports(status, created_at desc);
alter table public.world_bug_reports enable row level security;
revoke all on public.world_bug_reports from anon, authenticated;
grant select, insert, update on public.world_bug_reports to fn_owner_field;
grant select on public.world_staff to fn_owner_field;
grant select, insert on public.world_notifications to fn_owner_field;
do $$ declare q text := pg_get_serial_sequence('public.world_notifications', 'id'); begin if q is not null then execute format('grant usage on sequence %s to fn_owner_field', q); end if; end $$;

create or replace function public.world_bug_report_submit(p_category text, p_title text, p_body text, p_context jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); nm text; t text := btrim(coalesce(p_title, '')); b text := btrim(coalesce(p_body, '')); rid bigint;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if coalesce(p_category, '') not in ('bug', 'screen', 'balance', 'idea', 'other') then raise exception '분류를 골라 주세요.'; end if;
  if char_length(t) < 2 or char_length(t) > 60 then raise exception '제목은 2~60자로 적어 주세요.'; end if;
  if char_length(b) < 5 or char_length(b) > 2000 then raise exception '내용은 5~2000자로 적어 주세요.'; end if;
  if (select count(*) from public.world_bug_reports where owner_id = uid and created_at > now() - interval '1 hour') >= 5 then
    raise exception '제보는 1시간에 5건까지 보낼 수 있습니다. 잠시 뒤에 보내 주세요.'; end if;
  select character_name into nm from public.world_characters where owner_id = uid;
  -- 기기 정보는 크기만 제한해 그대로 남긴다(전·가방 같은 게임 값은 받지 않는다)
  insert into public.world_bug_reports(owner_id, character_name, category, title, body, context)
  values (uid, nm, p_category, t, b, case when pg_column_size(coalesce(p_context, '{}'::jsonb)) <= 8000 then coalesce(p_context, '{}'::jsonb) else '{}'::jsonb end)
  returning report_id into rid;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select s.owner_id, 'bug_report', '새 제보', coalesce(nm, '조사원') || ': ' || t, jsonb_build_object('report_id', rid)
    from public.world_staff s where s.owner_id <> uid;
  return jsonb_build_object('ok', true, 'report_id', rid, 'content', '제보를 보냈습니다. 운영진이 확인하면 알림으로 답을 드립니다.');
end $$;

create or replace function public.world_bug_report_list(p_status text default null)
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  with me as (select public.fn_owner_auth_uid() as uid),
  gm as (select exists (select 1 from public.world_staff s, me where s.owner_id = me.uid) as is_gm)
  select jsonb_build_object('is_gm', (select is_gm from gm),
    'reports', coalesce((select jsonb_agg(jsonb_build_object(
        'report_id', r.report_id, 'owner_id', r.owner_id, 'character_name', r.character_name, 'category', r.category, 'title', r.title, 'body', r.body,
        'context', case when (select is_gm from gm) then r.context else null end,
        'status', r.status, 'reply', r.reply, 'replied_at', r.replied_at, 'created_at', r.created_at) order by r.created_at desc)
      from (select * from public.world_bug_reports r, me
             where me.uid is not null and ((select is_gm from gm) or r.owner_id = me.uid)
               and (p_status is null or r.status = p_status)
             order by r.created_at desc limit 100) r), '[]'::jsonb),
    'open_count', case when (select is_gm from gm) then (select count(*) from public.world_bug_reports where status in ('open', 'checking')) end)
$$;

create or replace function public.world_bug_report_reply(p_report bigint, p_reply text, p_status text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); r public.world_bug_reports%rowtype; msg text := btrim(coalesce(p_reply, ''));
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_staff where owner_id = uid) then raise exception '운영진만 답할 수 있습니다.'; end if;
  if coalesce(p_status, '') not in ('open', 'checking', 'fixed', 'closed') then raise exception '처리 상태를 골라 주세요.'; end if;
  if char_length(msg) > 2000 then raise exception '답은 2000자까지 적을 수 있습니다.'; end if;
  select * into r from public.world_bug_reports where report_id = p_report for update;
  if not found then raise exception '없는 제보입니다.'; end if;
  update public.world_bug_reports set status = p_status,
    reply = case when msg <> '' then msg else reply end,
    replied_by = case when msg <> '' then uid else replied_by end,
    replied_at = case when msg <> '' then now() else replied_at end
  where report_id = p_report;
  if msg <> '' or p_status <> r.status then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.owner_id, 'bug_reply', '제보 답변', '「' || r.title || '」 · ' || case p_status when 'open' then '접수' when 'checking' then '확인 중' when 'fixed' then '고침' else '닫음' end
      || case when msg <> '' then ' — ' || left(msg, 80) else '' end, jsonb_build_object('report_id', p_report));
  end if;
  return jsonb_build_object('ok', true, 'content', '제보를 처리했습니다.');
end $$;

do $$
declare f text;
begin
  foreach f in array array['world_bug_report_submit(text, text, text, jsonb)', 'world_bug_report_list(text)', 'world_bug_report_reply(bigint, text, text)'] loop
    execute format('alter function public.%s owner to fn_owner_field', f);
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261027230000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select (select count(*) from pg_proc where proname like 'world_bug_report_%') as functions,
       to_regclass('public.world_bug_reports') is not null as reports_table,
       (select value from public.world_app_meta where key = 'db_version') as db_version;
