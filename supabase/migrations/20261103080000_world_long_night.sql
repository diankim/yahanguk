-- 장야(長夜): 롤백 전 끝나지 않는 밤으로 가는 연출. 단계는 날짜(한국 시각 자정)에 따라 저절로 넘어간다(운영진 조작 없음).
--   1단계 10/30(금) 밤이 일찍 찾아온다 · 2단계 10/31(토) 해가 거의 뜨지 않는다 · 3단계 11/1(일) 끝나지 않는 밤 · 4 = 11/2(월) 0시 롤백 시작(밤 그대로)
-- 시간대(world_time_phase)만 바꾸면 하늘 그림·날씨/시간대 효과·기록이 함께 따른다.

create or replace function public.world_long_night_stage(p_ts timestamptz default now())
returns int language sql immutable set search_path = pg_catalog as $f$
  select case when p_ts >= timestamptz '2026-11-02 00:00+09' then 4
              when p_ts >= timestamptz '2026-11-01 00:00+09' then 3
              when p_ts >= timestamptz '2026-10-31 00:00+09' then 2
              when p_ts >= timestamptz '2026-10-30 00:00+09' then 1 else 0 end
$f$;

-- 시간대: 0단계 해돋이 6~12·한낮 12~18·땅거미 18~24·삼경 0~6 / 1단계 6~11·11~15·15~20·20~6 / 2단계 9~10·10~11·11~15·15~9 / 3단계 이후 늘 삼경
create or replace function public.world_time_phase(p_ts timestamp with time zone)
returns text language plpgsql stable set search_path to 'pg_catalog' as $f$
declare h int := extract(hour from p_ts at time zone 'Asia/Seoul')::int; s int := public.world_long_night_stage(p_ts);
begin
  if s >= 3 then return 'night'; end if;
  if s = 2 then return case when h >= 9 and h < 10 then 'dawn' when h >= 10 and h < 11 then 'noon' when h >= 11 and h < 15 then 'dusk' else 'night' end; end if;
  if s = 1 then return case when h >= 6 and h < 11 then 'dawn' when h >= 11 and h < 15 then 'noon' when h >= 15 and h < 20 then 'dusk' else 'night' end; end if;
  return case when h >= 6 and h < 12 then 'dawn' when h >= 12 and h < 18 then 'noon' when h >= 18 then 'dusk' else 'night' end;
end $f$;

-- 지금 시간대가 바뀌는 때(화면의 「n시간 뒤 바뀜」). 정각마다 다음 시간대를 보고, 48시간 안에 안 바뀌면 48시간 뒤로 둔다.
create or replace function public.world_time_phase_end(p_ts timestamptz)
returns timestamptz language plpgsql stable set search_path to 'pg_catalog' as $f$
declare cur text := public.world_time_phase(p_ts); t timestamptz := date_trunc('hour', p_ts);
begin
  for i in 1..48 loop
    t := t + interval '1 hour';
    if public.world_time_phase(t) <> cur then return t; end if;
  end loop;
  return t;
end $f$;

-- 단계 효과(날씨·시간대 효과와 함께 world_env_total에 더한다): 2단계 조우 +15·침식 +20·희귀품/단서 +5 / 3단계 이후 조우 +50·침식 +30·희귀품/단서 +10·정신 손실 +10
create or replace function public.world_long_night_fx(p_key text)
returns numeric language sql stable set search_path = pg_catalog as $f$
  select case public.world_long_night_stage(now())
    when 2 then case p_key when 'encounter_pct' then 15 when 'erosion_pct' then 20 when 'rare_loot_pct' then 5 when 'clue_bonus_pct' then 5 else 0 end
    when 3 then case p_key when 'encounter_pct' then 50 when 'erosion_pct' then 30 when 'rare_loot_pct' then 10 when 'clue_bonus_pct' then 10 when 'mental_loss_pct' then 10 else 0 end
    when 4 then case p_key when 'encounter_pct' then 50 when 'erosion_pct' then 30 when 'rare_loot_pct' then 10 when 'clue_bonus_pct' then 10 when 'mental_loss_pct' then 10 else 0 end
    else 0 end::numeric
$f$;

create or replace function public.world_env_total(p_owner uuid, p_key text)
returns numeric language plpgsql stable security definer set search_path = pg_catalog, public as $f$
#variable_conflict use_column
begin
  return (with k as materialized (select public.world_time_phase(now()) tp, public.world_weather_key(public.world_owner_territory(p_owner), now()) wk where p_owner is not null)
    select coalesce(sum(case when (e.effects ->> p_key) ~ '^-?[0-9]+(\.[0-9]+)?$' then (e.effects ->> p_key)::numeric else 0 end), 0)
      from k join public.world_environment_catalog e on e.env_key in (k.tp, k.wk))
    + case when p_owner is not null then public.world_long_night_fx(p_key) else 0 end;
end $f$;

-- 날씨·시간대 창: 시간대가 끝나는 때를 장야에 맞추고, 장야 단계 안내를 더한다
create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;
select pg_temp.yh_patch('public.world_environment_snapshot()',
  $o$  phase_end := (date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') + make_interval(hours => (h / 6 + 1) * 6)) AT TIME ZONE 'Asia/Seoul';$o$,
  $o$  phase_end := public.world_time_phase_end(now());$o$);
select pg_temp.yh_patch('public.world_environment_snapshot()',
  $o$    'territory_id', terr,$o$,
  $o$    'territory_id', terr,
    'long_night', CASE public.world_long_night_stage(now())
      WHEN 1 THEN jsonb_build_object('stage', 1, 'name', '밤이 일찍 찾아온다', 'text', '해가 평소보다 일찍 기운다. 땅거미는 오후 세 시에, 삼경은 저녁 여덟 시에 찾아온다.')
      WHEN 2 THEN jsonb_build_object('stage', 2, 'name', '해가 거의 뜨지 않는다', 'text', '해는 아침 아홉 시에 잠깐 비쳤다 사라진다. 어둠을 틈타 요괴가 늘고(조우 +15%) 침식이 빨라진다(+20%). 대신 어둠 속에서 귀한 것이 눈에 띈다(희귀품·단서 +5%).')
      WHEN 3 THEN jsonb_build_object('stage', 3, 'name', '끝나지 않는 밤', 'text', '해가 뜨지 않는다. 요괴가 넘쳐나고(조우 +50%) 침식이 거세다(+30%, 정신 손실 +10%). 희귀품·단서 +10%. 안전지대만이 마지막 등불이다.')
      WHEN 4 THEN jsonb_build_object('stage', 4, 'name', '끝나지 않는 밤', 'text', '등불이 하나씩 꺼지고 있다.')
    END,$o$);

-- 소식: 매시 정각 단계가 바뀌었으면 전체 채팅 「봉연 소식」으로 알리고, 단계마다 정해진 시각에 한 줄씩 낌새를 남긴다
create or replace function public.world_long_night_tick()
returns void language plpgsql security definer set search_path = pg_catalog, public as $f$
declare s int := public.world_long_night_stage(now()); h int := extract(hour from now() at time zone 'Asia/Seoul')::int;
  last int := coalesce((select value::int from public.world_app_meta where key = 'long_night_announced'), 0); who uuid; msg text;
begin
  if s = 0 then return; end if;
  who := (select owner_id from public.world_staff limit 1);
  if who is null then return; end if;
  if s > last then
    msg := case s
      when 1 then '관상감 보고: 오늘은 해가 평소보다 일찍 기울었습니다. 땅거미가 오후 세 시에 찾아옵니다. 봉연 쪽 하늘이 붉습니다.'
      when 2 then '관상감 보고: 해가 아침 아홉 시에 잠깐 비쳤다가 사라졌습니다. 어둠을 틈타 요괴가 늘고 있습니다. 바깥 길은 조심하십시오.'
      when 3 then '관상감 보고: 해가 뜨지 않았습니다. 끝나지 않는 밤이 시작되었습니다. 요괴가 넘쳐납니다. 안전지대의 등불을 지키십시오.'
      else '등불이 하나씩 꺼지고 있습니다.' end;
    insert into public.world_chat_messages(channel_type, sender_id, sender_name, content) values ('global', who, '봉연 소식', msg);
    insert into public.world_app_meta(key, value, changed_at) values ('long_night_announced', s::text, now())
      on conflict (key) do update set value = excluded.value, changed_at = now();
    return;
  end if;
  msg := case
    when s = 1 and h = 15 then '땅거미가 벌써 내려앉았습니다. 아직 오후인데도 등불을 켜는 집이 늘었습니다.'
    when s = 1 and h = 20 then '삼경입니다. 봉연 쪽에서 낮게 우는 소리가 들립니다.'
    when s = 2 and h = 11 then '잠깐 비친 해가 다시 사라졌습니다. 장터 사람들이 서둘러 문을 닫습니다.'
    when s = 2 and h = 18 then '세력 수장들이 정청에 모였습니다. 밤이 이대로 끝나지 않을 수도 있다는 말이 돕니다.'
    when s = 3 and h = 6 then '해 뜰 시각이 지났지만 하늘은 여전히 검습니다.'
    when s = 3 and h = 12 then '한낮이어야 할 시각입니다. 요괴가 안전지대 바로 앞까지 내려왔습니다.'
    when s = 3 and h = 18 then '연서희가 붉은 인장을 꺼냈다는 소문이 정청에 돕니다.'
    when s = 3 and h = 22 then '등불이 흔들립니다. 오늘 밤이 마지막일지도 모릅니다.'
    else null end;
  if msg is not null then insert into public.world_chat_messages(channel_type, sender_id, sender_name, content) values ('global', who, '봉연 소식', msg); end if;
end $f$;
revoke all on function public.world_long_night_tick() from public, anon, authenticated;
select cron.schedule('yh-long-night', '0 * * * *', 'select public.world_long_night_tick()');
select public.world_long_night_tick();

update public.world_app_meta set value = '20261103080000' where key = 'db_version';
