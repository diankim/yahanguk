-- 오픈 전 운영진만 먼저 들어가기(2026-11-02 사용자 요청): 문(end.sql)을 열어도 open_at 전에는 운영진(world_staff)만 캐릭터를 만든다.
-- 캐릭터가 없으면 게임 행동을 할 수 없으므로, 다른 조사원은 로그인해도 생성 화면에서 막힌다. open_at이 지나면 저절로 풀린다(예약 작업 없음).
-- 1.0.0 오픈 뒤 지워도 되고(아래 맨 끝 주석), 남겨 둬도 open_at이 지난 뒤에는 아무 일도 하지 않는다.
insert into public.world_app_meta(key, value, changed_at) values ('open_at', '2026-11-03 10:00:00+09', now())
on conflict (key) do update set value = excluded.value, changed_at = now();

create or replace function public.world_open_gate(p_uid uuid)
returns void language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare t timestamptz;
begin
  select value::timestamptz into t from public.world_app_meta where key = 'open_at';
  if t is not null and now() < t and not exists (select 1 from public.world_staff s where s.owner_id = p_uid) then
    raise exception '야행국은 %에 문을 엽니다. 그때 조사원을 만들 수 있습니다.', to_char(t at time zone 'Asia/Seoul', 'FMMM"월" FMDD"일" HH24:MI');
  end if;
end $f$;
revoke all on function public.world_open_gate(uuid) from public, anon, authenticated;
grant execute on function public.world_open_gate(uuid) to fn_owner_19111;

do $p$
declare d text := replace(pg_get_functiondef('public.world_create_character_v2(text,text,text)'::regprocedure), E'\r\n', E'\n');
  a text := $a$  if uid is null then raise exception '로그인이 필요합니다.' using errcode = '28000'; end if;$a$;
begin
  if position('world_open_gate' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception 'gm_preopen anchor'; end if;
  execute replace(d, a, a || E'\n  perform public.world_open_gate(uid);');
end $p$;

-- 지울 때: create_character_v2에서 「perform public.world_open_gate(uid);」 줄을 빼고 drop function public.world_open_gate(uuid); delete from world_app_meta where key = 'open_at';
