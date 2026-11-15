create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

create or replace function public.world_rescue_rules()
 returns jsonb language sql immutable
as $f$
  select jsonb_build_object('pct', 15, 'min', 30, 'per_lv', 80, 'per_lv_low', 40, 'low_lv', 15, 'xp_pct', 5, 'death_h', 4)
$f$;

select pg_temp.yh_fix2('public.world_death_sweep()'::regprocedure,
  $o$downed_at < now() - interval '4 hours'$o$,
  $n$downed_at < now() - make_interval(hours => (public.world_rescue_rules() ->> 'death_h')::int)$n$);
select pg_temp.yh_fix2('public.world_hud_snapshot()'::regprocedure,
  $o$c.downed_at + interval '4 hours' END$o$,
  $n$c.downed_at + make_interval(hours => (public.world_rescue_rules() ->> 'death_h')::int) END$n$);

create or replace function public.world_tourney_rules()
 returns jsonb language sql immutable
as $f$ select '{"exchange_s": 3, "between_s": 8, "rest_s": 20,
  "stance": {"attack": {"dealt": 1.15, "taken": 1.1, "evade": 0}, "balanced": {"dealt": 1, "taken": 1, "evade": 0}, "defense": {"dealt": 0.85, "taken": 0.8, "evade": 5}},
  "skill_at": {"mid": 0.6, "finish": 0.35}, "heal_at": 0.4,
  "signup_end_day": 5, "solo_day": 5, "team_day": 6, "start_h": 21, "absent_min": 10, "min_entries": 4}'::jsonb $f$;
revoke all on function public.world_tourney_rules() from public, anon, authenticated;
grant execute on function public.world_tourney_rules() to fn_owner_field;

select pg_temp.yh_fix2('public.world_tourney_duel(uuid,uuid,uuid)'::regprocedure,
  $o$is_crit boolean; heal numeric;$o$,
  $n$is_crit boolean; tr jsonb := public.world_tourney_rules(); heal numeric;$n$);
select pg_temp.yh_fix2('public.world_tourney_duel(uuid,uuid,uuid)'::regprocedure,
  $o$hp[i] < mx[i] * 0.4 and$o$,
  $n$hp[i] < mx[i] * (tr ->> 'heal_at')::numeric and$n$);
select pg_temp.yh_fix2('public.world_tourney_duel(uuid,uuid,uuid)'::regprocedure,
  $o$hp[i] < mx[i] * 0.6)$o$,
  $n$hp[i] < mx[i] * (tr #>> '{skill_at,mid}')::numeric)$n$);
select pg_temp.yh_fix2('public.world_tourney_duel(uuid,uuid,uuid)'::regprocedure,
  $o$hp[tgt] < mx[tgt] * 0.35)$o$,
  $n$hp[tgt] < mx[tgt] * (tr #>> '{skill_at,finish}')::numeric)$n$);
select pg_temp.yh_fix2('public.world_tourney_duel(uuid,uuid,uuid)'::regprocedure,
  $o$(case when stance[tgt] = 'defense' then 5 else 0 end)$o$,
  $n$coalesce((tr -> 'stance' -> stance[tgt] ->> 'evade')::numeric, 0)$n$);
select pg_temp.yh_fix2('public.world_tourney_duel(uuid,uuid,uuid)'::regprocedure,
  $o$* case stance[i] when 'attack' then 1.15 when 'defense' then 0.85 else 1 end$o$,
  $n$* coalesce((tr -> 'stance' -> stance[i] ->> 'dealt')::numeric, 1)$n$);
select pg_temp.yh_fix2('public.world_tourney_duel(uuid,uuid,uuid)'::regprocedure,
  $o$* case stance[tgt] when 'attack' then 1.1 when 'defense' then 0.8 else 1 end$o$,
  $n$* coalesce((tr -> 'stance' -> stance[tgt] ->> 'taken')::numeric, 1)$n$);

select pg_temp.yh_fix2('public.world_tourney_ensure()'::regprocedure,
  $o$declare mon date := date_trunc('week', now() at time zone 'Asia/Seoul')::date; v text;$o$,
  $n$declare mon date := date_trunc('week', now() at time zone 'Asia/Seoul')::date; v text; tr jsonb := public.world_tourney_rules();$n$);
select pg_temp.yh_fix2('public.world_tourney_ensure()'::regprocedure,
  $o$values (mon, 'solo', v, ((mon + 5)::timestamp) at time zone 'Asia/Seoul', ((mon + 5)::timestamp + interval '21 hours') at time zone 'Asia/Seoul'),
         (mon, 'team', v, ((mon + 5)::timestamp) at time zone 'Asia/Seoul', ((mon + 6)::timestamp + interval '21 hours') at time zone 'Asia/Seoul')$o$,
  $n$values (mon, 'solo', v, ((mon + (tr ->> 'signup_end_day')::int)::timestamp) at time zone 'Asia/Seoul', ((mon + (tr ->> 'solo_day')::int)::timestamp + make_interval(hours => (tr ->> 'start_h')::int)) at time zone 'Asia/Seoul'),
         (mon, 'team', v, ((mon + (tr ->> 'signup_end_day')::int)::timestamp) at time zone 'Asia/Seoul', ((mon + (tr ->> 'team_day')::int)::timestamp + make_interval(hours => (tr ->> 'start_h')::int)) at time zone 'Asia/Seoul')$n$);

select pg_temp.yh_fix2('public.world_tourney_tick()'::regprocedure,
  $o$if now() >= t.starts_at - interval '10 minutes' then$o$,
  $n$if now() >= t.starts_at - make_interval(mins => (public.world_tourney_rules() ->> 'absent_min')::int) then$n$);
select pg_temp.yh_fix2('public.world_tourney_tick()'::regprocedure,
  $o$if n < 4 then$o$,
  $n$if n < (public.world_tourney_rules() ->> 'min_entries')::int then$n$);



create or replace function public.world_survival_rules()
 returns jsonb language sql immutable
as $f$ select '{"cleanse": {"er": 18, "mn": 6, "hq_er": 21, "hq_mn": 7}, "ground": {"mn": 18, "er": 10, "min": 15}}'::jsonb $f$;
revoke all on function public.world_survival_rules() from public, anon, authenticated;
grant execute on function public.world_survival_rules() to fn_owner_18944;

select pg_temp.yh_fix2('public.world_survival_action(text)'::regprocedure,
  $o$cl int := 0; wm int := 6;$o$,
  $n$cl int := 0; sr jsonb := public.world_survival_rules(); wm int := (sr #>> '{cleanse,mn}')::int; ce int := (sr #>> '{cleanse,er}')::int;$n$);
select pg_temp.yh_fix2('public.world_survival_action(text)'::regprocedure,
  $o$er:=greatest(0,c.erosion-18);$o$, $n$er:=greatest(0,c.erosion-ce);$n$);
select pg_temp.yh_fix2('public.world_survival_action(text)'::regprocedure,
  $o$er:=greatest(0,c.erosion-21); wm:=7;$o$,
  $n$ce:=(sr #>> '{cleanse,hq_er}')::int; er:=greatest(0,c.erosion-ce); wm:=(sr #>> '{cleanse,hq_mn}')::int;$n$);
select pg_temp.yh_fix2('public.world_survival_action(text)'::regprocedure,
  $o$case when wm=7 then 21 else 18 end$o$, $n$ce$n$);
select pg_temp.yh_fix2('public.world_survival_action(text)'::regprocedure,
  $o$created_at>now()-interval '15 minutes'$o$, $n$created_at>now()-make_interval(mins => (sr #>> '{ground,min}')::int)$n$);
select pg_temp.yh_fix2('public.world_survival_action(text)'::regprocedure,
  $o$last_at+interval '15 minutes'-now()$o$, $n$last_at+make_interval(mins => (sr #>> '{ground,min}')::int)-now()$n$);
select pg_temp.yh_fix2('public.world_survival_action(text)'::regprocedure,
  $o$now()+interval '15 minutes' end$o$, $n$now()+make_interval(mins => (sr #>> '{ground,min}')::int) end$n$);
select pg_temp.yh_fix2('public.world_survival_action(text)'::regprocedure,
  $o$er:=greatest(0,c.erosion-10);$o$, $n$er:=greatest(0,c.erosion-(sr #>> '{ground,er}')::int);$n$);
select pg_temp.yh_fix2('public.world_survival_action(text)'::regprocedure,
  $o$mental=least(100,mental+18),erosion=er$o$, $n$mental=least(100,mental+(sr #>> '{ground,mn}')::int),erosion=er$n$);
select pg_temp.yh_fix2('public.world_survival_action(text)'::regprocedure,
  $o$'호흡과 주문으로 정신을 가다듬었다. 정신 안정도 +18, 침식 -10.'$o$,
  $n$'호흡과 주문으로 정신을 가다듬었다. 정신 안정도 +'||(sr #>> '{ground,mn}')||', 침식 -'||(sr #>> '{ground,er}')||'.'$n$);

update public.world_patch_notes set body = body || '
- 물품 가짓수가 늘어 화면이 묶음 크기를 일부만 읽던 탓에 가방 칸 수가 실제보다 많게 보이던 것을 고쳤습니다. 서버가 세는 칸 수는 그대로였습니다.
- 동료 화면 친구 카드에 「별채」 단추를 두어 조사원 카드를 열지 않고 바로 구경 갈 수 있습니다.
- 쉬기·마음 다잡기 뒤 남은 시간이 바로 바뀝니다.
- 행사·혼례·비무회 창을 다른 탭에 둔 동안에는 새로 읽지 않고, 돌아오면 한 번 읽습니다.
- 조사원 카드의 도안 제보 단추를 카드 오른쪽 아래 구석의 작은 깃발로 옮겼습니다. 입은 도안이 여럿이면 누른 뒤 고릅니다.
' where note_id = '2.3.0' and body not like '%묶음 크기를 일부만 읽던%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118130000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
