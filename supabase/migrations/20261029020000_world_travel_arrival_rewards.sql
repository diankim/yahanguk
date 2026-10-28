-- 이동 보상은 도착할 때만(2026-10-29), 취소 대가는 돈 대신 시간.
--   출발·도착 모두 행동 기록 'travel'을 남기는데, 도착 기록에만 travel_history_id가 있다(world_travel_status).
--   지금까지 출발에도 경험치(+5·+4)·추적 기술 +3·상태 굴림·세력 임무·이동 칭호가 붙어, 출발→취소를 되풀이해 쌓을 수 있었다.
--   · 보상을 주는 곳에서 출발 기록은 건너뛴다(도착 기록만 센다).
--   · 이동 칭호·꾸미기 규칙도 도착만 센다(규칙에 "has":"travel_history_id", 서로 다른 지역 수 규칙도 has를 따르게 한다).
--   · 이동 취소는 위약금 없이, 취소한 뒤 3분 동안 다시 출발할 수 없다(world_guard_action_context가 출발 기록에서 막는다).
grant fn_owner_field to postgres with inherit true, set true;
grant fn_owner_expedition to postgres with inherit true, set true;
grant fn_owner_18473 to postgres with inherit true, set true;
grant fn_owner_18941 to postgres with inherit true, set true;
grant fn_owner_18962 to postgres with inherit true, set true;
grant fn_owner_20175 to postgres with inherit true, set true;
grant fn_owner_18540 to postgres with inherit true, set true;
grant fn_owner_19257 to postgres with inherit true, set true;

-- 행동 막기 함수 주인이 취소 기록을 읽을 수 있게(읽기만)
grant select on public.world_travel_history to fn_owner_expedition;

do $$
declare pat record; d text;
begin
  for pat in select * from (values
    -- 레벨 경험치: 출발 0, 도착 5
    ('public.world_award_progression_from_event()',
     'when new.event_type=''travel'' then case when coalesce(new.payload->>''arrived'',''false'')=''true'' then 0 else 5 end',
     'when new.event_type=''travel'' then case when coalesce(new.payload,''{}''::jsonb) ? ''travel_history_id'' then 5 else 0 end'),
    -- 사건 진행 경험치
    ('public.world_apply_event_progress()', '  elsif k=''travel'' then xp := 4;', '  elsif k=''travel'' and payload ? ''travel_history_id'' then xp := 4;'),
    -- 추적 기술 경험
    ('public.world_track_specialized_skill()',
     ' if new.event_type not in (''combat'',''gather'',''craft'',''explore'',''story'',''travel'',''rescue'') then return new; end if;',
     ' if new.event_type not in (''combat'',''gather'',''craft'',''explore'',''story'',''travel'',''rescue'') then return new; end if;
 if new.event_type=''travel'' and not (v_payload ? ''travel_history_id'') then return new; end if;'),
    -- 이동 중 상태이상 굴림
    ('public.world_apply_activity_status()', 'when new.event_type in (''travel'',''move'') then ''travel''',
     'when new.event_type in (''travel'',''move'') and coalesce(new.payload,''{}''::jsonb) ? ''travel_history_id'' then ''travel'''),
    -- 세력 임무(아무 행동)
    ('public.world_track_faction_missions()', '  IF new.event_type=''encounter'' THEN RETURN new; END IF;',
     '  IF new.event_type=''encounter'' THEN RETURN new; END IF;
  IF new.event_type=''travel'' AND NOT (coalesce(new.payload,''{}''::jsonb) ? ''travel_history_id'') THEN RETURN new; END IF;'),
    -- 서로 다른 지역 수 규칙도 has를 따른다
    ('public.world_title_rule_ok(uuid,jsonb)',
     'WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> ''distinct'' AND e.payload ? (p_rule ->> ''key'');',
     'WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> ''distinct'' AND e.payload ? (p_rule ->> ''key'') AND (NOT p_rule ? ''has'' OR e.payload ? (p_rule ->> ''has''));'),
    ('public.world_title_rule_progress(uuid,jsonb)',
     'where e.actor_id = p_owner and e.event_type = p_rule ->> ''distinct'' and e.payload ? (p_rule ->> ''key'');',
     'where e.actor_id = p_owner and e.event_type = p_rule ->> ''distinct'' and e.payload ? (p_rule ->> ''key'') and (not p_rule ? ''has'' or e.payload ? (p_rule ->> ''has''));'),
    -- 취소 뒤 3분 동안 출발 막기(출발 기록 = travel_history_id가 없는 travel)
    ('public.world_guard_action_context()', '  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN (''encounter'', ''combat'') THEN',
     '  IF k = ''travel'' AND NOT (p ? ''travel_history_id'') THEN
    PERFORM 1 FROM public.world_travel_history h WHERE h.owner_id = new.actor_id AND h.cancelled_at > now() - interval ''3 minutes'';
    IF FOUND THEN
      RAISE EXCEPTION ''%'', format(''이동을 취소한 뒤 3분 동안은 다시 출발할 수 없습니다(%s초 남음).'',
        ceil(extract(epoch FROM (SELECT max(h.cancelled_at) FROM public.world_travel_history h WHERE h.owner_id = new.actor_id) + interval ''3 minutes'' - now())));
    END IF;
  END IF;
  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN (''encounter'', ''combat'') THEN')
  ) as t(fn, a, b) loop
    d := pg_get_functiondef(pat.fn::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '이동 보상 고칠 자리가 하나가 아닙니다: % / %', pat.fn, left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

-- 이동 칭호·꾸미기는 도착만 센다
update public.world_title_catalog set rule = rule || '{"has": "travel_history_id"}'::jsonb
 where (rule ->> 'ev' = 'travel' or rule ->> 'distinct' = 'travel') and not rule ? 'has';
update public.world_cosmetic_catalog set rule = rule || '{"has": "travel_history_id"}'::jsonb
 where (rule ->> 'ev' = 'travel' or rule ->> 'distinct' = 'travel') and not rule ? 'has';

-- 이동 취소: 위약금 없음(대신 3분 동안 다시 출발할 수 없음). 출발 60초 안에만 취소할 수 있는 것은 그대로.
create or replace function public.world_travel_cancel()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; h public.world_travel_history%rowtype;
begin
  perform public.world_seal_guard();
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.travel_arrives_at is null then raise exception '취소할 이동이 없습니다.'; end if;
  select * into h from public.world_travel_history where owner_id = uid and completed_at is null and cancelled_at is null order by started_at desc limit 1 for update;
  if h.id is null then raise exception '취소 가능한 이동 기록이 없습니다.'; end if;
  if now() > h.started_at + interval '60 seconds' then raise exception '출발 후 60초가 지나 이동을 취소할 수 없습니다.'; end if;
  update public.world_characters set travel_destination = null, travel_arrives_at = null, updated_at = now() where owner_id = uid;
  update public.world_travel_history set cancelled_at = now(), cancellation_penalty = 0 where id = h.id;
  -- 취소는 부른 사람의 이동만 멈춘다. 동승 상대의 따로 가는 이동은 그대로 둔다.
  update public.world_travel_party_requests set status = 'cancelled', cancelled_at = now() where (leader_id = uid or passenger_id = uid) and status = 'pending';
  return jsonb_build_object('ok', true, 'content', '이동을 취소했습니다. 3분 동안은 다시 출발할 수 없습니다.', 'penalty', 0, 'cooldown_seconds', 180);
end $$;
grant execute on function public.world_seal_guard() to fn_owner_19257;

grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_expedition to postgres with inherit false, set false;
grant fn_owner_18473 to postgres with inherit false, set false;
grant fn_owner_18941 to postgres with inherit false, set false;
grant fn_owner_18962 to postgres with inherit false, set false;
grant fn_owner_20175 to postgres with inherit false, set false;
grant fn_owner_18540 to postgres with inherit false, set false;
grant fn_owner_19257 to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029020000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
