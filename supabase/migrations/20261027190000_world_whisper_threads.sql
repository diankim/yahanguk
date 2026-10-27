-- 귓속말 창: 상대별 대화 목록과 읽음 표시(어느 기기에서든 같게)
-- - world_whisper_reads: 캐릭터가 상대별로 귓속말을 마지막으로 읽은 시각. 클라이언트는 직접 읽거나 쓰지 않고 RPC로만 다룬다.
-- - world_whisper_threads(): 나와 귓속말을 주고받은 상대 목록(상대 이름·마지막 말·안 읽은 수). 차단한 상대는 뺀다.
-- - world_whisper_mark_read(p_partner): 그 상대와의 귓속말을 지금까지 읽은 것으로 표시한다.
-- 메시지 자체는 그대로 world_chat_messages(channel_type = 'whisper')에 있고, 읽기 권한(보낸 이·받는 이만)도 그대로다.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

create table if not exists public.world_whisper_reads (
  owner_id uuid not null references auth.users(id) on delete cascade,
  partner_id uuid not null,
  read_at timestamptz not null default now(),
  primary key (owner_id, partner_id)
);
alter table public.world_whisper_reads enable row level security;
revoke all on public.world_whisper_reads from anon, authenticated;
grant select, insert, update on public.world_whisper_reads to fn_owner_field;

create or replace function public.world_whisper_threads()
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  with me as (select public.fn_owner_auth_uid() as uid),
  m as (
    select case when w.sender_id = me.uid then w.recipient_id else w.sender_id end as partner, w.*
      from public.world_chat_messages w, me
     where me.uid is not null and w.channel_type = 'whisper' and (w.sender_id = me.uid or w.recipient_id = me.uid)
       and w.created_at > now() - interval '30 days'
  ),
  t as (
    select m.partner,
           max(m.created_at) as last_at,
           (array_agg(m.content order by m.created_at desc))[1] as last_text,
           (array_agg(m.sender_id = (select uid from me) order by m.created_at desc))[1] as last_mine,
           (array_agg(m.sender_name order by m.created_at desc) filter (where m.sender_id = m.partner))[1] as partner_said_name,
           count(*) filter (where m.sender_id = m.partner and m.created_at > coalesce(r.read_at, '-infinity'::timestamptz)) as unread
      from m left join public.world_whisper_reads r on r.owner_id = (select uid from me) and r.partner_id = m.partner
     where m.partner is not null
       and not exists (select 1 from public.world_blocks b where b.owner_id = (select uid from me) and b.blocked_id = m.partner)
     group by m.partner
  )
  select jsonb_build_object(
    'unread_total', coalesce(sum(t.unread), 0),
    'threads', coalesce(jsonb_agg(jsonb_build_object(
      'partner_id', t.partner, 'name', coalesce(c.character_name, t.partner_said_name, '떠난 조사원'),
      'last_at', t.last_at, 'last_text', left(t.last_text, 80), 'last_mine', t.last_mine, 'unread', t.unread
    ) order by t.last_at desc), '[]'::jsonb))
  from (select * from t order by last_at desc limit 50) t
  left join public.world_characters c on c.owner_id = t.partner
$$;
alter function public.world_whisper_threads() owner to fn_owner_field;
revoke all on function public.world_whisper_threads() from public, anon;
grant execute on function public.world_whisper_threads() to authenticated;

create or replace function public.world_whisper_mark_read(p_partner uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_partner is null or p_partner = uid then return jsonb_build_object('ok', false); end if;
  insert into public.world_whisper_reads(owner_id, partner_id, read_at) values (uid, p_partner, now())
  on conflict (owner_id, partner_id) do update set read_at = excluded.read_at;
  return jsonb_build_object('ok', true);
end $$;
alter function public.world_whisper_mark_read(uuid) owner to fn_owner_field;
revoke all on function public.world_whisper_mark_read(uuid) from public, anon;
grant execute on function public.world_whisper_mark_read(uuid) to authenticated;

select (select count(*) from pg_proc where proname in ('world_whisper_threads', 'world_whisper_mark_read')) as functions,
       to_regclass('public.world_whisper_reads') is not null as reads_table;
