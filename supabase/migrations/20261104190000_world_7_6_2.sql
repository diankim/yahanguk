-- 7.6.2 — 원정 일지: 다른 지역으로 따로 원정 간 파티원의 일지가 섞여 함께 간 것처럼 보이던 것(사용자 제보 2026-10-31)
-- 합동 전투(world_expedition_settle)·함께 간 보너스(world_expedition_complete)는 같은 지역만 세므로, 일지도 같은 지역 파티원만 섞는다.
-- 「원정 중인 동료」 목록(party)은 그대로 모두 보인다(같은 지역 표시).
lock table public.world_characters in access exclusive mode;

do $p$
declare d text; a text; b text; n int; own text; inh boolean;
begin
  d := replace(pg_get_functiondef('public.world_expedition_progress()'::regprocedure), E'\r\n', E'\n');
  if position('if x.region_id = e.region_id then lines := lines' in d) > 0 then return; end if;
  a := $a$      lines := lines || public.world_expedition_walk_lines(x.expedition_id);$a$;
  b := $b$      if x.region_id = e.region_id then lines := lines || public.world_expedition_walk_lines(x.expedition_id); end if;$b$;
  n := (length(d) - length(replace(d, a, ''))) / length(a);
  if n <> 1 then raise exception '7.6.2 anchor (% of 1)', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_expedition_progress()'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, a, b);
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;

-- 요화: 침식 100에서 넘친 몫(사용자 결정 2026-10-31). 80·90·100 경계 판정은 그대로 두고,
-- 침식이 오르는 행동(탐색·토벌 기록·원정 회차 정산·귀허의 주인 실패) 안에서만, 100을 넘친 1점마다 0.25%를 더 굴린다.
-- 캐릭터 행 갱신은 늘리지 않는다(각 함수가 이미 하는 계산 자리에서 부르고, 걸렸을 때만 상태·알림 한 줄씩).
create or replace function public.world_yohwa_overflow(p_uid uuid, p_over numeric)
returns boolean language plpgsql security definer set search_path to '' as $f$
begin
  if p_uid is null or coalesce(p_over, 0) <= 0 then return false; end if;
  if exists (select 1 from public.world_character_statuses where owner_id = p_uid and status_key in ('yohwa', 'yohwa_seal')) then return false; end if;
  if random() >= 1 - power(1 - 0.0025, least(p_over, 100)) then return false; end if;
  insert into public.world_character_statuses(owner_id, status_key, stacks, potency, source_activity, expires_at, metadata)
    values (p_uid, 'yohwa', 1, 1, 'erosion', now() + interval '3 days', jsonb_build_object('stage', 1, 'started_at', now(), 'from', 'overflow'));
  insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_uid, 'yohwa', '요화: 1단계 요기 스밈', '가득 찬 침식을 넘어 요기가 몸에 스며들었습니다. 3일 뒤 2단계로 나빠집니다. 귀령초로만 풀 수 있습니다.', jsonb_build_object('stage', 1));
  perform public.world_yohwa_mark(p_uid, 'onset');
  return true;
end $f$;
revoke all on function public.world_yohwa_overflow(uuid, numeric) from public, anon, authenticated;
alter function public.world_yohwa_overflow(uuid, numeric) owner to fn_owner_field;

do $p$
declare r record; d text; own text; inh boolean; n int;
begin
  for r in select * from (values
      ('public.world_field_search()'::regprocedure,
       $a$  UPDATE public.world_characters SET inventory = inv, gil = gil + gil_gain, experience = experience + xp,$a$,
       $b$  IF e_add > 0 THEN PERFORM public.world_yohwa_overflow(uid, (SELECT erosion FROM public.world_characters WHERE owner_id = uid) + e_add - 100); END IF;
  UPDATE public.world_characters SET inventory = inv, gil = gil + gil_gain, experience = experience + xp,$b$),
      ('public.world_event_char_apply()'::regprocedure,
       $a$  ero := case when er > 0 or er_x > 0 then least(100, c.erosion + greatest(er, 0) + er_x) else c.erosion end;$a$,
       $b$  ero := case when er > 0 or er_x > 0 then least(100, c.erosion + greatest(er, 0) + er_x) else c.erosion end;
  if er > 0 or er_x > 0 then perform public.world_yohwa_overflow(c.owner_id, c.erosion + greatest(er, 0) + er_x - 100); end if;$b$),
      ('public.world_expedition_settle(uuid,integer)'::regprocedure,
       $a$  er := greatest(0, least(100, er)); mn := greatest(0, least(100, mn)); hp := greatest(0, least(100, hp));$a$,
       $b$  if er > 100 then perform public.world_yohwa_overflow(e.owner_id, er - 100); end if;
  er := greatest(0, least(100, er)); mn := greatest(0, least(100, mn)); hp := greatest(0, least(100, hp));$b$),
      ('public.world_gw_settle(uuid,boolean)'::regprocedure,
       $a$      update public.world_characters set health = greatest(1, m.hp), erosion = least(100, erosion + 10),$a$,
       $b$      perform public.world_yohwa_overflow(m.owner_id, (select erosion from public.world_characters where owner_id = m.owner_id) + 10 - 100);
      update public.world_characters set health = greatest(1, m.hp), erosion = least(100, erosion + 10),$b$),
      -- 침식이 처음 100에 닿으면(요화에 걸리지 않았을 때) 앞으로 넘친 몫이 판정된다고 한 번 알린다
      ('public.world_yohwa_onset()'::regprocedure,
       $a$if not hit then return null; end if;$a$,
       $b$if not hit then
    if old.erosion < 100 and new.erosion >= 100 then
      insert into public.world_notifications(user_id, kind, title, content, payload)
        values (new.owner_id, 'yohwa', '침식이 가득 찼습니다', '침식이 100에 닿았습니다. 이제부터 침식이 더 오르는 행동(탐색·토벌·원정)을 할 때마다 넘친 몫이 요기로 스며 요화에 걸릴 수 있습니다. 정화 부적이나 마음 다잡기로 침식을 낮추세요.', jsonb_build_object('stage', 0, 'warn', true));
    end if;
    return null;
  end if;$b$)
    ) x(fn, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position('world_yohwa_overflow' in d) > 0 or position('침식이 가득 찼습니다' in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.6.2 yohwa anchor in % (% of 1)', r.fn, n; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

-- 요괴화(7.6.2, 사용자 요청): 요화 3단계가 끝나면 바로 쓰러지지 않고, 「거의 요괴가 된 것처럼」 1시간 동안 강해진 뒤 쓰러진다.
-- 요화 상태(3단계 불이익)는 그대로 두고 'yohwa_frenzy'(이로운 상태, 상태 칸 10칸에 세지 않음)를 1시간 붙인다.
-- 원정 중이면 지금처럼 1시간씩 미룬다. 귀령초로 요화가 풀리면(요화 줄이 지워지면) 요괴화도 함께 사라진다.
insert into public.world_status_catalog(status_key, status_name, polarity, description, duration_minutes, triggers, effects, max_stacks, active, icon, cure, cure_items)
values ('yohwa_frenzy', '요괴화', 'positive', '요화 마지막 단계가 끝나 요괴의 힘이 몸을 차지했습니다. 한 시간 동안 요화와 합쳐 주는 피해 +42%·받는 피해 −12%·정신 손실 −20%·민첩 +15%·침식 +24%가 되지만, 끝나면 쓰러집니다.', 60, '{}'::text[],
        '{"combat_damage_pct":30,"incoming_damage_pct":-30,"healing_pct":30,"mental_loss_pct":-50,"agility_pct":15}'::jsonb, 1, true, 'mask',
        '귀령초로 요화가 풀리면 함께 사라집니다.', '{}'::text[])
on conflict (status_key) do update set status_name = excluded.status_name, polarity = excluded.polarity, description = excluded.description,
  duration_minutes = excluded.duration_minutes, effects = excluded.effects, max_stacks = excluded.max_stacks, active = excluded.active, icon = excluded.icon, cure = excluded.cure;

create or replace function public.world_yohwa_frenzy_clear() returns trigger
language plpgsql security definer set search_path to '' as $f$
begin
  delete from public.world_character_statuses where owner_id = old.owner_id and status_key = 'yohwa_frenzy';
  return null;
end $f$;
revoke all on function public.world_yohwa_frenzy_clear() from public, anon, authenticated;
alter function public.world_yohwa_frenzy_clear() owner to fn_owner_field;
drop trigger if exists trg_world_yohwa_frenzy_clear on public.world_character_statuses;
create trigger trg_world_yohwa_frenzy_clear after delete on public.world_character_statuses
  for each row when (old.status_key = 'yohwa') execute function public.world_yohwa_frenzy_clear();

do $p$
declare r record; d text; own text; inh boolean; n int;
begin
  for r in select * from (values
      ('public.world_yohwa_tick()'::regprocedure,
       $a$select cs.status_id, cs.owner_id, cs.potency from public.world_character_statuses cs$a$,
       $b$select cs.status_id, cs.owner_id, cs.potency, cs.metadata from public.world_character_statuses cs$b$, 'cs.potency, cs.metadata from'),
      ('public.world_yohwa_tick()'::regprocedure,
       $a$update public.world_character_statuses set expires_at = now() + interval '1 hour' where status_id = s.status_id;$a$,
       $b$update public.world_character_statuses set expires_at = now() + interval '1 hour' where status_id = s.status_id;
    elsif not coalesce(s.metadata ? 'frenzy_at', false) then
      -- 3단계 끝: 1시간 요괴화 뒤에 쓰러진다(7.6.2)
      update public.world_character_statuses set expires_at = now() + interval '1 hour', applied_at = now(),
             metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('frenzy_at', now())
       where status_id = s.status_id;
      delete from public.world_character_statuses where owner_id = s.owner_id and status_key = 'yohwa_frenzy';
      insert into public.world_character_statuses(owner_id, status_key, stacks, potency, source_activity, expires_at, metadata)
        values (s.owner_id, 'yohwa_frenzy', 1, 1, 'yohwa', now() + interval '1 hour', jsonb_build_object('stage', 4));
      insert into public.world_notifications(user_id, kind, title, content, payload)
        values (s.owner_id, 'yohwa', '요괴화: 요괴의 힘이 깨어났습니다',
                '반요의 시간이 끝나 요괴의 힘이 몸을 차지했습니다. 한 시간 동안 요화와 합쳐 주는 피해 +42%·받는 피해 −12%·정신 손실 −20%·민첩 +15%·침식 +24%가 되지만, 한 시간이 지나면 쓰러집니다. 지금이라도 귀령초를 쓰면 요화가 풀립니다.',
                jsonb_build_object('stage', 4, 'frenzy', true));$b$, '''frenzy_at'', false'),
      ('public.world_status_roll(text,jsonb)'::regprocedure,
       $a$status_key not in ('yohwa','yohwa_seal')$a$,
       $b$status_key not in ('yohwa','yohwa_seal','yohwa_frenzy')$b$, '''yohwa_frenzy'')')
    ) x(fn, a, b, mark)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.mark in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.6.2 frenzy anchor in % (% of 1)', r.fn, n; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.6.2
- 원정 일지: 파티원이 다른 지역으로 따로 원정을 떠났는데도 그 사람의 일지가 내 일지에 섞여 함께 간 것처럼 보이던 것을 고쳤습니다. 이제 같은 지역으로 원정 중인 파티원(함께 싸우는 동료)의 일지만 함께 보이고, 다른 곳에 간 파티원은 아래 「원정 중인 동료」 목록에서 진행만 볼 수 있습니다.
- 요화: 침식이 100에 머문 채로 계속 행동하면 더는 요화 판정이 없던 것을 바꿨습니다. 이제 침식이 가득 찬 상태에서 탐색·토벌·원정으로 침식이 더 오르면, 넘친 1점마다 0.25% 확률로 요기가 스며 요화에 걸릴 수 있습니다(80·90·100에 처음 닿을 때의 판정은 그대로). 접속하지 않거나 안전지대에서 쉬는 동안에는 판정하지 않습니다. 침식이 처음 100에 닿으면 알림으로 알려 드립니다.
- 요화 마지막 단계(반요)가 끝나면 곧바로 쓰러지지 않고, 요괴의 힘이 몸을 차지한 **요괴화** 상태로 1시간을 보냅니다. 그동안은 요화와 합쳐 주는 피해 +42%·받는 피해 −12%·정신 손실 −20%·민첩 +15%·침식 +24%가 되고(주는 피해는 피해 합 상한 +35%까지), 1시간이 지나면 쓰러집니다. 그 사이에 귀령초를 쓰면 요화와 함께 풀립니다.
- 가방 › 소지품 검색은 물품 이름에서만, 가방 › 제작 검색은 제작법·완성품 이름에서만 찾습니다. 「응축 영핵」을 찾으면 응축 영핵을 만드는 제작법만 나오고, 그것이 재료로 들어가는 제작법은 섞이지 않습니다(재료로 쓰는 곳은 물품 정보 창의 제작법 목록에서 볼 수 있습니다).
$N$
 where note_id = '7.5.0' and position('## 7.6.2' in body) = 0;

update public.world_app_meta set value = '20261104190000' where key = 'db_version';
