-- 검증용(아무것도 남기지 않는다): 낚시·도감·요리·직업 원정 기술·원정 진행 기록·원정 중 직접 거래 금지.
-- SQL Editor에서 실행하면 마지막에 "시험결과(되돌림): ..." 오류로 결과를 보여 주고, 그 오류 때문에 모든 변경이 되돌려진다.
-- 두 계정(a72edf97…, 32f43cbe…)에 캐릭터가 없을 때 쓴다(시험 안에서 만들고 되돌린다).
do $$
declare a uuid := 'a72edf97-dd21-46b4-97da-b22cf80fc947'; b uuid := '32f43cbe-6894-4bfe-b654-76a404a6c3e2';
  node uuid := '104fd4ed-c1ab-45e9-8c17-15be16e27e20'; r jsonb; out text := ''; i int;
begin
  -- 캐릭터 만들기: 갑(법구 제작사)·을(의무관)
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', a::text, true); set local role authenticated;
  r := public.world_create_character_v2('검증갑', 'artificer', 'headquarters'); reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', b::text, true); set local role authenticated;
  r := public.world_create_character_v2('검증을', 'medic', 'medicalbureau'); reset role;

  -- 갑: 본부에서는 낚시터가 없어야 한다
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', a::text, true); set local role authenticated;
  out := out || '본부 낚시터: ' || coalesce(public.world_fish_spot()::text, '없음') || E'\n';
  begin r := public.world_fish(); out := out || '본부 낚시: 됨(문제)' || E'\n'; exception when others then out := out || '본부 낚시: ' || sqlerrm || E'\n'; end;
  reset role;

  -- 갑을 구름나루로 옮기고 낚싯대 없이 → 있이
  update public.world_characters set location = '구름나루' where owner_id = a;
  set local role authenticated;
  out := out || '구름나루 낚시터: ' || (public.world_fish_spot() ->> 'ground_name') || ', 낚싯대 ' || (public.world_fish_spot() ->> 'rod') || E'\n';
  begin r := public.world_fish(); out := out || '낚싯대 없이: 됨(문제)' || E'\n'; exception when others then out := out || '낚싯대 없이: ' || sqlerrm || E'\n'; end;
  reset role;
  update public.world_characters set inventory = inventory || '{"fishing_rod":1,"minnow":4,"charcoal":2}'::jsonb where owner_id = a;
  set local role authenticated;
  r := public.world_fish(); out := out || '낚시 1: ' || (r ->> 'content') || E'\n';
  begin r := public.world_fish(); out := out || '20초 안에 다시: 됨(문제)' || E'\n'; exception when others then out := out || '20초 안에 다시: ' || sqlerrm || E'\n'; end;
  reset role;
  out := out || '낚시 기록 건수: ' || (select count(*) from public.world_events where actor_id = a and event_type = 'fish') || ', 도감 칸: '
    || coalesce((select string_agg(fish_id || '×' || caught, ',') from public.world_fish_log where owner_id = a), '없음') || E'\n';
  -- 여러 번 던진 것처럼(쿨타임 기록을 지우고) 10번 더 → 어종·칭호 확인
  for i in 1..10 loop
    delete from public.world_events where actor_id = a and event_type = 'fish' and created_at > now() - interval '1 minute' and payload ->> 'caught' = 'false';
    update public.world_events set created_at = created_at - interval '30 seconds' where actor_id = a and event_type = 'fish';
    update public.world_characters set stamina = 30, stamina_at = now() where owner_id = a;
    set local role authenticated;
    begin r := public.world_fish(); exception when others then out := out || '반복 오류: ' || sqlerrm || E'\n'; end;
    reset role;
  end loop;
  out := out || '도감: ' || coalesce((select string_agg(s.fish_name || '×' || l.caught || '(' || l.best_size || 'cm)', ', ') from public.world_fish_log l join public.world_fish_species s using (fish_id) where l.owner_id = a), '없음') || E'\n';
  out := out || '칭호: ' || coalesce((select string_agg(title_key, ',') from public.world_character_titles where owner_id = a), '없음') || E'\n';
  set local role authenticated;
  r := public.world_fish_codex();
  out := out || '도감 RPC: 종 ' || jsonb_array_length(r -> 'species') || ', 가려진 이름 ' || (select count(*) from jsonb_array_elements(r -> 'species') x where x ->> 'name' = '???')
    || ', 낚시 칭호 ' || jsonb_array_length(r -> 'titles') || E'\n';
  -- 요리: 버들치 손질 → 생선구이 → 먹기
  r := public.world_craft_item('fillet_minnow'); out := out || '손질: ' || coalesce(r ->> 'content', r::text) || E'\n';
  r := public.world_craft_item('cook_grilled_fish'); out := out || '요리: ' || coalesce(r ->> 'content', r::text) || E'\n';
  r := public.world_use_item('grilled_fish'); out := out || '먹기: ' || (r ->> 'content') || E'\n';
  begin r := public.world_use_item('grilled_fish'); out := out || '없는 요리 먹기: 됨(문제)' || E'\n'; exception when others then out := out || '없는 요리 먹기: ' || sqlerrm || E'\n'; end;
  reset role;
  out := out || '상태: ' || coalesce((select string_agg(status_key || '~' || to_char(expires_at - now(), 'MI') || '분', ',') from public.world_character_statuses where owner_id = a and expires_at > now()), '없음') || E'\n';

  -- 을: 원정을 끝난 상태로 만들어 진행 기록과 직업 기술 확인
  update public.world_characters set location = '백지교' where owner_id = b;
  insert into public.world_expeditions(owner_id, region_id, node_id, minutes, stance, supplies, started_at, ends_at, status)
  values (b, 'paper_bridge', node, 60, 'bold', '{}'::jsonb, now() - interval '61 minutes', now() - interval '1 minute', 'active');
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', b::text, true); set local role authenticated;
  r := public.world_expedition_progress();
  out := out || '진행 기록: 수색 ' || (r ->> 'rounds_done') || '/' || (r ->> 'total_rounds') || ', 줄 ' || jsonb_array_length(r -> 'lines') || ', 기술 ' || (r ->> 'job_skill')
    || E'\n  마지막 줄: ' || (r -> 'lines' -> -1 ->> 'text') || E'\n';
  reset role;
  -- 원정 중 직접 거래 금지(같은 곳에 있게 한 뒤 시험)
  update public.world_characters set location = '구름나루' where owner_id = b;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', a::text, true); set local role authenticated;
  begin r := public.world_trade_direct_offer(b, '{}', 10, '{}', 0); out := out || '원정 중인 상대와 거래: 됨(문제)' || E'\n'; exception when others then out := out || '원정 중인 상대와 거래: ' || sqlerrm || E'\n'; end;
  reset role;
  update public.world_characters set location = '백지교', health = 40 where owner_id = b;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', b::text, true); set local role authenticated;
  r := public.world_expedition_complete(false);
  out := out || '원정 결과: ' || (r -> 'result' ->> 'ended') || ', 전투 ' || (r -> 'result' ->> 'wins') || '승 ' || (r -> 'result' ->> 'losses') || '패, 직업 기술 '
    || coalesce(r -> 'result' -> 'job_skill' ->> 'name', '?') || ' ' || coalesce(r -> 'result' -> 'job_skill' ->> 'count', '?') || '회'
    || E'\n  기록: ' || coalesce((select string_agg(x, ' / ') from jsonb_array_elements_text(r -> 'result' -> 'log') x), '') || E'\n';
  reset role;
  raise exception '시험결과(되돌림): %', out;
end $$;
