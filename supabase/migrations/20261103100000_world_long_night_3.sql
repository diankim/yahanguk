-- 장야 2·3단계 덧붙임: 요괴 넘침(정예·우두머리) + 마지막 합동 토벌(일 11/1 20:00, 반드시 실패)
-- 넘침: 현장 토벌의 정예·우두머리가 깊이와 상관없이 더 나온다(2단계 정예 8% / 3단계 이후 정예 25%·우두머리 6%).
-- 마지막 토벌: 봉연의 그림자(fx.last_night)가 본부 앞 연무장·팔괘진에 드러난다. 체력은 최대의 3% 아래로 내려가지 않고,
--   바닥에 닿을 때마다 꺼진 등불의 빛을 삼켜 40%로 일어선다(횟수 제한 없음). 토벌은 서버를 닫는 월 0시까지 이어지고,
--   23:50에 토벌대 전원을 체력 1까지 몰아붙이는 전멸 연출, 0시에 실패로 끝나며(보통 실패와 같은 위로 보상)
--   봉연 소식이 등불이 꺼졌다고 알린다. 그 뒤로 새 회차를 잡지 않는다(롤백).

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

-- ① 요괴 넘침
select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  $o$  IF p_depth >= 3 AND random() < (CASE WHEN p_depth >= 4 THEN 0.16 ELSE 0.09 END) THEN$o$,
  $o$  IF (p_depth >= 3 AND random() < (CASE WHEN p_depth >= 4 THEN 0.16 ELSE 0.09 END)) OR (public.world_long_night_stage(now()) BETWEEN 3 AND 4 AND random() < 0.06) THEN$o$);
select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  $o$  IF rk = 'normal' AND p_depth >= 2 AND random() < 0.05 + p_depth * 0.03 THEN rk := 'elite'; END IF;$o$,
  $o$  IF rk = 'normal' AND ((p_depth >= 2 AND random() < 0.05 + p_depth * 0.03)
     OR random() < CASE public.world_long_night_stage(now()) WHEN 2 THEN 0.08 WHEN 3 THEN 0.25 WHEN 4 THEN 0.25 ELSE 0 END) THEN rk := 'elite'; END IF;$o$);

-- ② 마지막 합동 토벌 예약: 장야 동안에는 일요일 20시 회차 하나만 잡고, 그것이 끝나면 더 잡지 않는다
select pg_temp.yh_patch('public.world_raid_schedule_next()',
  $o$  select count(*) into cnt from public.world_raids where kind = 'world';$o$,
  $o$  if public.world_long_night_stage(now()) between 1 and 4 then
    if exists (select 1 from public.world_raids where kind = 'world' and fx ? 'last_night') or now() >= timestamptz '2026-11-01 20:00+09' then return null; end if;
    insert into public.world_raids(kind, boss_name, region_id, status, candidates, spawn_at, fx)
    values ('world', '봉연의 그림자', 'hq_training', 'announced', array['hq_training', 'field_outskirts', 'shrine_ruins'],
            timestamptz '2026-11-01 20:00+09', '{"last_night": true}');
    return timestamptz '2026-11-01 20:00+09';
  end if;
  select count(*) into cnt from public.world_raids where kind = 'world';$o$);

-- ③ 반드시 실패: 보스 체력은 최대의 3% 아래로 내려가지 않는다(이기는 판정 자체가 나지 않음)
select pg_temp.yh_patch('public.world_raid_action(uuid,text,text,uuid,text)',
  $o$    rd.hp := greatest(0, rd.hp - dmg);$o$,
  $o$    rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - dmg);$o$);

-- 바닥에 닿으면 세 번까지 40%로 일어서고, 끝나면(실패) 등불이 꺼졌다고 알린다
create or replace function public.world_last_night_raid_fx()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $f$
declare n int;
begin
  if not (new.fx ? 'last_night') then return new; end if;
  -- 토벌은 서버를 닫는 월요일 0시까지 이어진다(보통 회차는 2시간)
  if tg_op = 'UPDATE' and old.status = 'signup' and new.status = 'fight' then
    new.ends_at := timestamptz '2026-11-02 00:00+09';
  end if;
  -- 바닥에 닿을 때마다 몇 번이든 40%로 일어선다
  if tg_op = 'UPDATE' and new.status = 'fight' and new.max_hp > 0 and new.hp <= ceil(new.max_hp * 0.03) then
    n := coalesce((new.fx ->> 'revive')::int, 0);
    new.hp := round(new.max_hp * 0.4);
    new.fx := jsonb_set(new.fx, '{revive}', to_jsonb(n + 1));
    perform public.world_raid_say(new.raid_id, 'phase', case n % 4
      when 0 then '그림자가 꺼져 가는 등불의 빛을 삼키고 다시 일어섭니다. 바깥 안전지대의 등불 하나가 꺼졌습니다.'
      when 1 then '그림자가 또 일어섭니다. 밤이 깊어질수록 그림자는 짙어집니다. 등불이 또 하나 꺼졌습니다.'
      when 2 then '베어 낸 자리에서 어둠이 다시 차오릅니다. 봉연이 그림자를 끝없이 밀어 올립니다.'
      else '그림자가 마지막 등불의 빛까지 끌어당깁니다. 이 밤은 끝나지 않습니다.' end);
  end if;
  if tg_op = 'UPDATE' and old.status = 'fight' and new.status in ('failed', 'won') then
    insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
    select 'global', s.owner_id, '봉연 소식', '봉연의 그림자를 끝내 몰아내지 못했습니다. 정청의 등불만 남았습니다. 연서희가 붉은 인장을 장부 위에 올렸다는 말이 돕니다.'
      from public.world_staff s limit 1;
  end if;
  return new;
end $f$;
revoke all on function public.world_last_night_raid_fx() from public, anon, authenticated;
drop trigger if exists trg_world_last_night_raid on public.world_raids;
create trigger trg_world_last_night_raid before update on public.world_raids for each row execute function public.world_last_night_raid_fx();


-- 전멸 연출(일 23:50): 그림자가 마지막 등불을 삼키며 토벌에 든 모두를 쓰러지기 직전(체력 1)까지 몰아붙인다. 쓰러뜨리지는 않는다.
create or replace function public.world_last_night_wipe()
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare rid uuid; n int := 0;
begin
  select raid_id into rid from public.world_raids where fx ? 'last_night' and status = 'fight' limit 1;
  if rid is null then return jsonb_build_object('ok', false); end if;
  perform public.world_raid_say(rid, 'phase', '그림자가 정청을 뺀 모든 등불을 한꺼번에 삼킵니다. 칠흑 같은 어둠이 토벌대 전체를 덮칩니다.');
  update public.world_characters c set health = 1, updated_at = now()
    from public.world_raid_members m where m.raid_id = rid and m.owner_id = c.owner_id and c.health > 1;
  get diagnostics n = row_count;
  update public.world_raid_members set out_until = now() + interval '60 seconds', falls = falls + 1 where raid_id = rid;
  perform public.world_raid_say(rid, 'fall', '토벌대 전원 — 쓰러지기 직전까지 몰렸습니다(체력 1). 1분 뒤 다시 일어설 수 있습니다.');
  insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
  select 'global', s.owner_id, '봉연 소식', '연무장의 토벌대가 한꺼번에 무너졌습니다. 그림자가 등불을 모두 삼켰습니다. 남은 것은 정청의 등불 하나뿐입니다.'
    from public.world_staff s limit 1;
  begin perform cron.unschedule('yh-last-night-wipe'); exception when others then null; end;
  return jsonb_build_object('ok', true, 'hit', n);
end $f$;
revoke all on function public.world_last_night_wipe() from public, anon, authenticated;
select cron.schedule('yh-last-night-wipe', '50 14 1 11 *', 'select public.world_last_night_wipe()');

update public.world_app_meta set value = '20261103100000' where key = 'db_version';
