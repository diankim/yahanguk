create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

create or replace function public.world_tourney_rules()
 returns jsonb language sql immutable
as $f$ select '{"exchange_s": 3, "between_s": 8, "rest_s": 20}'::jsonb $f$;
revoke all on function public.world_tourney_rules() from public, anon, authenticated;
grant execute on function public.world_tourney_rules() to fn_owner_field;

select pg_temp.yh_fix2('public.world_tourney_play_round(uuid)'::regprocedure,
  $o$latest timestamptz := now(); loser uuid; w uuid;$o$,
  $n$latest timestamptz := now(); loser uuid; w uuid; tr jsonb := public.world_tourney_rules(); at timestamptz := now(); dur interval;$n$);
select pg_temp.yh_fix2('public.world_tourney_play_round(uuid)'::regprocedure,
  $o$    update public.world_tourney_matches set winner = w, log = r -> 'log', exchanges = (r ->> 'exchanges')::int, starts_at = now(),
      ends_at = now() + make_interval(secs => 2 * (r ->> 'exchanges')::int) where match_id = m.match_id;
    latest := greatest(latest, now() + make_interval(secs => 2 * (r ->> 'exchanges')::int));$o$,
  $n$    dur := make_interval(secs => (tr ->> 'exchange_s')::int * (r ->> 'exchanges')::int);
    update public.world_tourney_matches set winner = w, log = r -> 'log', exchanges = (r ->> 'exchanges')::int, starts_at = at,
      ends_at = at + dur where match_id = m.match_id;
    latest := greatest(latest, at + dur);
    at := at + dur + make_interval(secs => (tr ->> 'between_s')::int);$n$);
select pg_temp.yh_fix2('public.world_tourney_play_round(uuid)'::regprocedure,
  $o$round_at = latest + interval '20 seconds'$o$,
  $n$round_at = latest + make_interval(secs => (tr ->> 'rest_s')::int)$n$);

select pg_temp.yh_fix2('public.world_tourney_view(uuid)'::regprocedure,
  $o$'log', case when can_watch then m.log end)$o$,
  $n$'log', case when can_watch and (m.starts_at <= now() or t.status = 'done') then m.log end)$n$);
select pg_temp.yh_fix2('public.world_tourney_view(uuid)'::regprocedure,
  $o$where m.t_id = p_t and m.starts_at <= now() and m.ends_at > now() order by m.starts_at desc limit 1) lm$o$,
  $n$where m.t_id = p_t and m.a is not null and m.b is not null and m.starts_at is not null
                                 order by (m.ends_at > now()) desc, case when m.ends_at > now() then m.starts_at end, m.ends_at desc limit 1) lm$n$);

update public.world_patch_notes set body = body || '
- 비무회 겨루기가 한 라운드 안에서 동시에 열리지 않고 차례로 펼쳐집니다. 한 합은 3초, 겨루기 사이에는 8초 쉽니다. 장면에는 지금 겨루는 두 편이 서고, 다음 겨루기를 기다리는 동안에는 곧 나설 두 편이 섭니다. 아직 시작하지 않은 겨루기의 기록은 시작할 때 열립니다.
' where note_id = '2.3.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118100000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
