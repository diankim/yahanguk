
-- ⑤ 읽기 함수: 물품 내력·요괴 목격담(한 번에, 접속 동안 화면이 기억) · 지역 첫 방문 · 다녀간 지역 글 · 숨김 칭호 유래
create or replace function public.world_lore_bundle()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object(
    'items', (select coalesce(jsonb_object_agg(item_id, lore), '{}'::jsonb) from public.world_item_lore),
    -- 목격담은 그 갈래를 need마리 쓰러뜨린 것만 글을 내준다(못 연 것은 조건만)
    'witness', (select coalesce(jsonb_object_agg(kind_key, arr), '{}'::jsonb) from (
       select w.kind_key, jsonb_agg(case when coalesce(kk.n, 0) >= w.need
           then jsonb_build_object('need', w.need, 'open', true, 'name', coalesce(public.world_quest_cast(array[w.speaker], '') -> w.speaker ->> 'name', ''), 't', w.line)
           else jsonb_build_object('need', w.need, 'open', false) end order by w.need) arr
         from public.world_kind_witness w
         left join (select m.kind, sum(x.defeated) n from public.world_monster_codex x join public.world_region_monsters m using (monster_id) where x.owner_id = uid group by m.kind) kk on kk.kind = w.kind_key
        group by w.kind_key) z));
end $function$;

create or replace function public.world_region_intro(p_region text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; l jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  select * into r from public.world_map_regions where region_id = p_region and region_name = c.location;
  if not found or c.travel_destination is not null then return null; end if;
  select lines into l from public.world_region_lore where region_id = p_region;
  if l is null then return null; end if;
  insert into public.world_region_visits(owner_id, region_id) values (uid, p_region) on conflict do nothing;
  if not found then return null; end if;
  return jsonb_build_object('region_id', p_region, 'title', r.region_name, 'lines', l);
end $function$;

create or replace function public.world_region_lore_seen()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('region_id', v.region_id, 'region_name', m.region_name, 'territory', m.territory_name, 'visited_at', v.visited_at, 'lines', l.lines) order by v.visited_at), '[]'::jsonb)
            from public.world_region_visits v join public.world_region_lore l on l.region_id = v.region_id join public.world_map_regions m on m.region_id = v.region_id
           where v.owner_id = uid);
end $function$;

create or replace function public.world_title_story(p_title text)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); l jsonb; spk text[]; nm text; me text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if not exists (select 1 from public.world_character_titles where owner_id = uid and title_key = p_title) then raise exception '얻은 칭호만 유래를 볼 수 있습니다.'; end if;
  select lines into l from public.world_title_lore where title_key = p_title;
  if l is null then return null; end if;
  select title_name into nm from public.world_title_catalog where title_key = p_title;
  select character_name into me from public.world_characters where owner_id = uid;
  select array_agg(distinct x ->> 's') into spk from jsonb_array_elements(l) x where x ->> 's' is not null;
  return jsonb_build_object('title', '「' || nm || '」의 유래', 'lines', l, 'cast', public.world_quest_cast(spk, me));
end $function$;

-- 소속 보급 편지: 마친 장 수까지 열린 편지 가운데 날마다 하나
create or replace function public.world_affil_letter(p_uid uuid, p_faction text)
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $function$
  select jsonb_build_object('title', l.sender || '에서 온 편지', 'lines', l.lines)
    from public.world_affil_letters l
   where l.faction_key = p_faction
     and l.min_chapters <= (select count(*) from public.world_quests q where q.kind = 'main' and q.active and public.world_quest_done(p_uid, q.quest_id))
   order by md5(l.seq::text || p_uid::text || current_date::text) limit 1
$function$;

do $$ declare d text := pg_get_functiondef('public.world_claim_faction_supply()'::regprocedure);
  a text := 'return jsonb_build_object(''content'',''소속 보급을 수령했습니다: ''';
  b text := 'return jsonb_build_object(''letter'',public.world_affil_letter(uid,c.faction_key),''content'',''소속 보급을 수령했습니다: ''';
begin
  if position('world_affil_letter' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 소속 보급 편지'; end if;
  execute replace(d, a, b);
end $$;

-- ⑥ 탈것 내리기: 탈것 없이 걸어 다닌다(속도 ×1, 운임 없음 — world_travel_route가 탈것이 없으면 그렇게 계산). 언제든 다시 탈 수 있다
create or replace function public.world_mount_unequip()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 등록하세요.'; end if;
  if c.is_dead or c.health <= 0 or c.downed_at is not null then raise exception '현재 상태에서는 탈것을 바꿀 수 없습니다.'; end if;
  if c.travel_destination is not null then raise exception '이동 중에는 탈것에서 내릴 수 없습니다. 도착한 뒤에 내리세요.'; end if;
  if c.mount_id is null then raise exception '이미 걸어 다니고 있습니다.'; end if;
  update public.world_characters set mount_id = null, updated_at = now() where owner_id = uid;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload) values (uid, c.character_name, 'mount', '탈것에서 내림', jsonb_build_object('mount_id', null, 'from', c.mount_id));
  return jsonb_build_object('content', '탈것에서 내렸습니다. 이제 걸어서 다닙니다(운임 없음).', 'mount_id', null);
end $function$;

-- 탈것 내리기(주인 fn_owner_field)가 캐릭터의 탈것 열만 고칠 수 있게(열 하나만, 화면 권한은 그대로)
grant update (mount_id) on public.world_characters to fn_owner_field;

do $$ declare f text; begin
  foreach f in array array['public.world_lore_bundle()', 'public.world_region_intro(text)', 'public.world_region_lore_seen()', 'public.world_title_story(text)', 'public.world_affil_letter(uuid,text)', 'public.world_mount_unequip()'] loop
    execute format('alter function %s owner to fn_owner_field', f);
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['public.world_lore_bundle()', 'public.world_region_intro(text)', 'public.world_region_lore_seen()', 'public.world_title_story(text)', 'public.world_mount_unequip()'] loop
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  -- 보급 함수 주인이 편지 함수를 부른다
  execute format('grant execute on function public.world_affil_letter(uuid,text) to %I', (select pg_get_userbyid(proowner) from pg_proc where oid = 'public.world_claim_faction_supply()'::regprocedure));
end $$;

-- ⑥-2 6.1.0 합동 토벌 보강(배포 전 검토)
-- 봉연 예고(출현지·후보·시각)는 world_raid_brief가 때맞춰 공개하므로, 표 직접 읽기는 예고가 아닌 회차만
drop policy if exists world_raids_read on public.world_raids;
create policy world_raids_read on public.world_raids for select to authenticated using (status <> 'announced');

do $$ declare d text; a text; b text; n int;
begin
  d := pg_get_functiondef('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure);
  if position('토벌 보강 6.1.1' in d) = 0 then
    -- ① 신청 뒤에도 자율 활동·이동 중이면 싸울 수 없다
    a := 'raise exception ''원정 중에는 싸울 수 없습니다.''; end if;';
    b := a || E'\n  -- 토벌 보강 6.1.1\n  if c.travel_destination is not null then raise exception ''이동 중에는 싸울 수 없습니다.''; end if;\n  if exists (select 1 from public.world_idle_activities where owner_id = uid and status = ''active'') then raise exception ''자율 활동 중에는 싸울 수 없습니다.''; end if;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 토벌 상태 확인(%)', n; end if;
    d := replace(d, a, b);
    -- ② 협동 기술 기본 기여도는 공격 한 번보다 적게(효과가 없어도 공격보다 많이 쌓이던 것)
    a := 'credit := (st ->> ''attack'')::numeric * 1.2;';
    b := 'credit := (st ->> ''attack'')::numeric * 0.6;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 협동 기여도(%)', n; end if;
    d := replace(d, a, b);
    -- ③ 회복·소생은 실제로 오른 체력만 센다
    a := 'update public.world_characters set health = greatest(health, amt), updated_at = now() where owner_id = tgt;';
    b := 'select health into h1 from public.world_characters where owner_id = tgt;' || E'\n        ' || a || E'\n        amt := greatest(0, amt - coalesce(h1, 0));';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 소생(%)', n; end if;
    d := replace(d, a, b);
    a := 'update public.world_characters set health = least(100, health + amt), updated_at = now() where owner_id = tgt and health > 0;';
    b := 'select health into h1 from public.world_characters where owner_id = tgt;' || E'\n        ' || a || E'\n        amt := case when coalesce(h1, 0) > 0 then greatest(0, least(100, h1 + amt) - h1) else 0 end;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 회복(%)', n; end if;
    d := replace(d, a, b);
    a := E'      get diagnostics n_act = row_count;\n      mb.heal := mb.heal + amt * n_act; credit := credit + amt * n_act * 2;';
    b := E'      get diagnostics n_act = row_count;\n      mb.heal := mb.heal + coalesce(acc, 0)::int; credit := credit + coalesce(acc, 0) * 2;';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 모두 회복(%)', n; end if;
    d := replace(d, a, b);
    a := E'      update public.world_characters ch set health = least(100, ch.health + amt), updated_at = now()\n        from public.world_raid_members x';
    b := E'      select sum(greatest(0, least(100, ch.health + amt) - ch.health)) into acc from public.world_characters ch join public.world_raid_members x on x.owner_id = ch.owner_id\n       where x.raid_id = p_raid and (x.out_until is null or x.out_until <= now()) and ch.health > 0;\n' || a;
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 모두 회복 합(%)', n; end if;
    execute replace(d, a, b);
  end if;
end $$;

-- ⑥-3 초반~중반 전 수입 보강(2026-10-29 경제 점검): Lv15 미만 구조대 상한 절반, 의뢰 보상 전 약 +25%(다음 날 게시판부터)
do $$ declare d text; a text; b text; n int;
begin
  d := pg_get_functiondef('public.world_call_rescue()'::regprocedure);
  if position('c.level < 15' in d) = 0 then
    a := 'fee := least(c.gil, least(c.level * 80, greatest(30, c.gil * 15 / 100)));';
    b := 'fee := least(c.gil, least(c.level * case when c.level < 15 then 40 else 80 end, greatest(30, c.gil * 15 / 100)));';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 구조대 비용(%)', n; end if;
    execute replace(d, a, b);
  end if;
  d := pg_get_functiondef('public.world_commission_board()'::regprocedure);
  if position('50 + c.level * 8' in d) = 0 then
    a := 'reg.region_id, 3, 40 + c.level * 6, 30 + c.level * 5);';
    b := 'reg.region_id, 3, 50 + c.level * 8, 30 + c.level * 5);';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 토벌 의뢰(%)', n; end if;
    d := replace(d, a, b);
    a := 'SELECT uid, today, 2, k, t, d, NULL, n, 30 + c.level * 4, 25 + c.level * 4';
    b := 'SELECT uid, today, 2, k, t, d, NULL, n, 38 + c.level * 5, 25 + c.level * 4';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 채집·정찰 의뢰(%)', n; end if;
    d := replace(d, a, b);
    a := 'it, q, round(price * q * 1.4)::int, 20 + c.level * 3);';
    b := 'it, q, round(price * q * 1.75)::int, 20 + c.level * 3);';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 납품 의뢰(%)', n; end if;
    execute replace(d, a, b);
  end if;
end $$;

-- ⑥-4 옛 경로 닫기(2026-10-29 점검): 화면·다른 함수·예약 작업 어디서도 부르지 않는 옛 행동 함수의 실행 권한만 거둔다(함수는 남겨 되돌릴 수 있음).
-- 탐색력·쿨타임·안전지대 규칙이 생기기 전 경로라 직접 부르면 재료를 공짜로 얻을 수 있었다.
do $$ declare f regprocedure; o text; begin
  for f, o in select p.oid::regprocedure, pg_get_userbyid(p.proowner) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in (
      'world_case_investigate','world_combat_action','world_combat_snapshot','world_expedition_board','world_expedition_finish','world_expedition_launch',
      'world_expedition_prepare','world_expedition_retreat','world_exploration_back','world_exploration_enter','world_exploration_gather','world_exploration_overview',
      'world_exploration_search_spot','world_gather_action','world_mark_character_dead','world_party_candidates','world_party_expedition_call','world_party_loot_deposit',
      'world_party_snapshot','world_public_activity_feed','world_public_roster','world_region_combat_action','world_region_encounter_snapshot','world_region_site_explore',
      'world_region_tactic_action','world_rest_at_spot','world_rpg_action','world_status_snapshot','world_status_treat','world_story_choice','world_trade_market_snapshot',
      'world_use_recovery_item') loop
    -- 권한은 주인 역할이 준 것이라 그 역할 이름으로 거둔다(postgres가 그 역할을 쓸 수 있게 먼저 맞춘다)
    if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
    execute format('set role %I', o);
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    reset role;
  end loop;
end $$;
-- 강화 기록 읽기 정책: 줄마다 auth.uid()를 다시 부르지 않게(뜻은 같음)
drop policy if exists world_gear_enhance_read_own on public.world_gear_enhance;
create policy world_gear_enhance_read_own on public.world_gear_enhance for select to authenticated using (owner_id = (select auth.uid()));

-- ⑥-5 옛 방 기반 시절 표·함수 지우기(2026-10-29 사용자 승인): 화면·지금 함수·예약 작업 어디서도 쓰지 않는다. 행이 있는 것은 옛 견본(items 10·locations 5·location_connections 8)뿐.
-- profiles는 회원가입 트리거(handle_new_user)가 쓰므로 남긴다. cascade 없이 지워, 다른 것이 기대고 있으면 실패해 전체가 되돌려진다.
drop table if exists public.action_results, public.activity_logs, public.character_inventory, public.character_secrets, public.character_states,
  public.event_choices, public.event_participants, public.event_steps, public.scheduled_events, public.game_actions, public.message_reads, public.messages,
  public.relationship_history, public.relationships, public.room_invites, public.room_members, public.notifications, public.world_clock,
  public.characters, public.events, public.game_rooms, public.location_connections, public.locations, public.items;
do $$ declare f regprocedure; begin
  for f in select p.oid::regprocedure from pg_proc p where p.pronamespace = 'public'::regnamespace
      and p.proname in ('chat_create_invite', 'chat_create_room', 'chat_join_invite', 'create_game_room', 'create_room_invite', 'join_room_with_invite', 'initialize_character_records') loop
    execute format('drop function %s', f);
  end loop;
end $$;

-- ⑥-6 퀘스트 채집 할 일은 얻은 개수로 센다(전에는 채집 횟수, 덤 물품 제외 — 「약제 바탕 0/2」가 가방에 있어도 오래 안 차던 것)
do $$ declare d text; a text; b text; n int;
begin
  d := pg_get_functiondef('public.world_quest_task_count(uuid,jsonb,timestamptz)'::regprocedure);
  if position('얻은 개수' in d) = 0 then
    a := E'    when p_task ->> ''t'' in (''win'', ''gather'', ''craft'', ''fish'') then (';
    b := E'    -- 채집(물품 지정): 얻은 개수(주 물품 수량 + 덤 물품)\n'
      || E'    when p_task ->> ''t'' = ''gather'' and p_task ? ''items'' then (\n'
      || E'    select coalesce(sum(\n'
      || E'        (case when e.payload ->> ''item_id'' in (select jsonb_array_elements_text(p_task -> ''items'')) then greatest(1, coalesce((e.payload ->> ''qty'')::int, 1)) else 0 end)\n'
      || E'      + coalesce((select sum((x.value)::text::int) from jsonb_each(case when jsonb_typeof(e.payload -> ''extra'') = ''object'' then e.payload -> ''extra'' else ''{}''::jsonb end) x\n'
      || E'                   where jsonb_typeof(x.value) = ''number'' and x.key in (select jsonb_array_elements_text(p_task -> ''items''))), 0)), 0)::int\n'
      || E'      from public.world_events e\n'
      || E'     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = ''gather''\n'
      || E'       and (not p_task ? ''r'' or (select n.region_id from public.world_exploration_nodes n\n'
      || E'                                   where n.node_id = case when e.payload ->> ''node_id'' ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'' then (e.payload ->> ''node_id'')::uuid end)\n'
      || E'                                 in (select jsonb_array_elements_text(p_task -> ''r''))))\n'
      || a;
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 퀘스트 채집 개수(%)', n; end if;
    execute replace(d, a, b);
  end if;
end $$;

-- ⑦ 6.1.0 숨김 풀기: 보관해 둔 6.1.0 패치노트를 되살리고, 서버 보스 예약을 다시 켠다(아무도 모이지 않은 예고 회차는 지우고 새로 잡는다)
do $$ begin
  if to_regclass('yh_deploy.hold_patch_note') is not null then
    execute 'insert into public.world_patch_notes select * from yh_deploy.hold_patch_note on conflict (note_id) do nothing';
  end if;
end $$;
delete from public.world_raids r where r.kind = 'world' and r.status = 'announced' and not exists (select 1 from public.world_raid_members m where m.raid_id = r.raid_id);
select public.world_raid_schedule_next() where not exists (select 1 from public.world_raids where kind = 'world' and status in ('announced', 'signup', 'fight'));
select cron.alter_job(jobid, active := true) from cron.job where jobname = 'yh-raid';

update public.world_patch_notes set body = body || E'\n### 6.1.1\n- **직업·소속 퀘스트 12개**: 직업마다 하나(호위 무사 「마지막 파수의 칼」·현장 조사원 「빈 과녁의 주인」·퇴마관 「방울을 돌려주는 밤」·의무관 「외상 장부의 약값」·봉인술사 「봉인 부적 출납부」·백공 기술관 「이름 붙은 등」), 소속마다 하나(본부 직속 「서리의 하루」·현장대응국 「귀죽림 순찰로」·기록감찰국 「젖은 쪽의 먹」·봉인관리국 「닫힌 줄 모르는 수문」·의무지원국 「담 밖의 약초밭」·외부 협력자 「명부 밖의 손님」). 이야기 속 인물들이 맡기고, 내 직업·소속에게만 보입니다(Lv3·4).\n- **1장 첫 장면**에서 연서희가 직업과 소속에 따라 다르게 맞아 줍니다(일지에서 다시 보기로도 보입니다).\n- **소속 보급 편지**: 하루 소속 보급을 받으면 부서에서 짧은 편지가 함께 옵니다. 이야기를 진행할수록 내용이 달라집니다.\n- **지역 첫 방문 글**: 지역에 처음 들어가면 그곳의 내력을 짧게 보여 주고, 일지 › 기록 › 지역에 남깁니다.\n- **물품 내력**: 시작 장비와 주요 물품 정보 창에 한 줄 내력이 붙습니다.\n- **요괴 목격담**: 요괴 도감에서 갈래를 고르면, 그 갈래를 1·10마리 쓰러뜨릴 때마다 이야기 속 인물의 한마디가 열립니다.\n- **숨김 칭호 유래**: 얻은 숨김 칭호 카드의 「유래」를 누르면 그 칭호를 두고 인물들이 하는 말을 보여 줍니다.\n- **환골탈태 장면**: 서첩을 쓰면 정청 서기관이 배속 변경을 처리하는 짧은 장면이 나옵니다.\n- **탈것에서 내리기**: 지도 › 탈것에서 탈것을 내려 걸어 다닐 수 있습니다(속도 ×1, 노정패 운임 없음). 언제든 다시 탈 수 있습니다.\n- **물품 버리기 편의(제보)**: 물품 정보 창의 버리기 칸에 가진 수량을 함께 적고, 「최대」(버릴 수 있는 만큼 채우기)와 「모두 버리기」 단추를 더했습니다. 장착 중인 장비는 하나를 남깁니다. 창 안의 글자를 끌어 고르다 바깥에서 손을 떼도 창이 닫히지 않습니다.\n- **초반~중반 전 수입 보강**: 레벨 15 미만은 본부 구조대 비용 상한이 절반(레벨×40전)입니다. 상시 의뢰의 보상 전을 약 25~30% 올렸습니다(예: Lv10 토벌 의뢰 40전 → 52전, 다음 날 게시판부터).\n- **물품 갈래 표시**: 상점(사기·팔기)·대장간·수리·분해·거래소·직접 거래·창고 목록의 물품 이름 앞에 무기·방어구·관모·신·노리개·호신부·탈·도구·소모품·재료 같은 갈래를 작게 붙였습니다.\n- **칭호 등급순 보기**: 칭호 화면에서 「보기」를 분류별·등급 높은순·등급 낮은순으로 고를 수 있습니다(등급순이면 신품~범품으로 묶고 카드에 분류를 적습니다. 얻지 못한 숨김 칭호는 맨 끝에 둡니다).\n- **퀘스트 채집 할 일**: 채집 횟수가 아니라 **얻은 개수**로 셉니다(한 번에 3개를 캐면 3, 덤으로 따라 나온 물품도 셈). 그 장면이 열린 뒤에 채집한 것만 세는 것은 같습니다.\n- **서버 정리**: 지금은 쓰지 않는 옛 행동 경로 32개를 닫았습니다(화면에서 쓰는 기능은 그대로입니다).\n'
 where note_id = '6.1.0' and position('### 6.1.1' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261031010000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
