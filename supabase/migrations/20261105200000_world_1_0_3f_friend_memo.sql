create table if not exists public.world_friend_notes (
  owner_id uuid not null,
  target_id uuid not null,
  nick text not null default '',
  memo text not null default '',
  updated_at timestamptz not null default now(),
  primary key (owner_id, target_id)
);
alter table public.world_friend_notes enable row level security;
revoke all on table public.world_friend_notes from public, anon, authenticated;
grant select, insert, update, delete on table public.world_friend_notes to fn_owner_field;

create or replace function public.world_friend_note_set(p_target uuid, p_nick text, p_memo text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); n text; m text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_target is null or p_target = uid then raise exception '별명을 붙일 수 없는 상대입니다.'; end if;
  if not exists (select 1 from public.world_friends f where f.status = 'accepted'
                   and ((f.owner_id = uid and f.friend_id = p_target) or (f.owner_id = p_target and f.friend_id = uid))) then
    raise exception '친구에게만 별명과 메모를 남길 수 있습니다.';
  end if;
  n := btrim(regexp_replace(coalesce(p_nick, ''), '[[:cntrl:]]+', ' ', 'g'));
  m := btrim(regexp_replace(coalesce(p_memo, ''), '[\x01-\x09\x0b-\x1f\x7f]+', ' ', 'g'));
  if char_length(n) > 12 then raise exception '별명은 12자까지 쓸 수 있습니다.'; end if;
  if char_length(m) > 200 then raise exception '메모는 200자까지 쓸 수 있습니다.'; end if;
  if n = '' and m = '' then
    delete from public.world_friend_notes where owner_id = uid and target_id = p_target;
  else
    insert into public.world_friend_notes (owner_id, target_id, nick, memo, updated_at) values (uid, p_target, n, m, now())
    on conflict (owner_id, target_id) do update set nick = excluded.nick, memo = excluded.memo, updated_at = now();
  end if;
  return jsonb_build_object('ok', true, 'nick', n, 'memo', m);
end $f$;
revoke all on function public.world_friend_note_set(uuid, text, text) from public, anon, authenticated;
alter function public.world_friend_note_set(uuid, text, text) owner to fn_owner_field;
grant execute on function public.world_friend_note_set(uuid, text, text) to authenticated, service_role;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_friend_overview()'::regprocedure), E'\r\n', E'\n');
  a := $a$'traveling', c.travel_arrives_at is not null and c.travel_arrives_at > now()) order by c.updated_at desc)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.3f world_friend_overview 기준 문구가 없습니다'; end if;
  execute replace(d, a, $x$'traveling', c.travel_arrives_at is not null and c.travel_arrives_at > now())
    || coalesce((select jsonb_build_object('nick', n.nick, 'memo', n.memo) from public.world_friend_notes n where n.owner_id = uid and n.target_id = c.owner_id), '{}'::jsonb) order by c.updated_at desc)$x$);
end $w$;

update public.world_app_meta set value = '20261105200000' where key = 'db_version';
