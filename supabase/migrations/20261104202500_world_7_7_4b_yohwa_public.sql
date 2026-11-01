-- 7.7.4b — 요화 3단계·요괴화를 남에게도 보인다(사용자 요청 2026-11-01).
-- 요화 1·2단계는 지금처럼 본인만 안다. 3단계(반요)는 조사원 카드의 「지금」 칸에, 요괴화(마지막 1시간)는
-- 조사원 카드 이름 옆과 채팅 이름 옆(전체·지역·세력·귓속말·모임)에 붉게 보인다 — 「동네방네 소문이 나게」.
-- world_yohwa_public(uid): 'frenzy'(요괴화 중) · '3'(요화 3단계) · null.
-- 채팅은 보낼 때 찍는다(world_chat_stamp_title·world_circle_send → sender_mark) — 읽을 때 따로 묻지 않는다.
alter table public.world_chat_messages add column if not exists sender_mark text;
alter table public.world_circle_messages add column if not exists sender_mark text;

create or replace function public.world_yohwa_public(p_owner uuid)
returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
begin
  if exists (select 1 from public.world_character_statuses s where s.owner_id = p_owner and s.status_key = 'yohwa_frenzy'
              and (s.expires_at is null or s.expires_at > now())) then return 'frenzy'; end if;
  if exists (select 1 from public.world_character_statuses s where s.owner_id = p_owner and s.status_key = 'yohwa'
              and greatest(coalesce(s.potency, 0), coalesce((s.metadata ->> 'stage')::int, 0)) >= 3) then return '3'; end if;
  return null;
end $function$;
revoke all on function public.world_yohwa_public(uuid) from public, anon, authenticated;

do $p$
declare r record; d text; n int; own text;
begin
  for r in
    select * from (values
      ('public.world_chat_stamp_title()'::regprocedure,
$A$RETURN new;$A$,
$B$new.sender_mark := case when new.sender_id is not null and public.world_yohwa_public(new.sender_id) = 'frenzy' then 'frenzy' end;
  RETURN new;$B$),
      ('public.world_circle_send(uuid,text)'::regprocedure,
$A$insert into public.world_circle_messages(circle_id, sender_id, sender_name, sender_title, sender_color, content)$A$,
$B$insert into public.world_circle_messages(circle_id, sender_id, sender_name, sender_title, sender_color, content, sender_mark)$B$),
      ('public.world_circle_send(uuid,text)'::regprocedure,
$A$(c.profile ->> 'chat_hue')::numeric::smallint end, clean) returning id into mid;$A$,
$B$(c.profile ->> 'chat_hue')::numeric::smallint end, clean, case when public.world_yohwa_public(uid) = 'frenzy' then 'frenzy' end) returning id into mid;$B$),
      ('public.world_character_card(uuid)'::regprocedure,
$A$'owner_id', c.owner_id, 'character_name', c.character_name, 'level', c.level,$A$,
$B$'owner_id', c.owner_id, 'character_name', c.character_name, 'level', c.level, 'yohwa', public.world_yohwa_public(c.owner_id),$B$)
    ) x(fn, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.4b yohwa public anchor in % (% of 1): %', r.fn, n, left(r.a, 70); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    if own <> 'postgres' then
      if not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
      execute format('grant execute on function public.world_yohwa_public(uuid) to %I', own);
    end if;
    execute replace(d, r.a, r.b);
  end loop;
end $p$;

update public.world_app_meta set value = '20261104202500' where key = 'db_version';
