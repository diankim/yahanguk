-- 7.4.0 배포 때 함께: 하드 콘텐츠 난이도 시험을 맡은 조사원 넷(조의신·강산하·여보·황지호(조의신의 정인))을 Lv30으로 올리고 주 이야기 1~10장을 마친 것으로 한다(사용자 요청).
-- · 레벨: world_grant_xp로 Lv30까지 필요한 경험치를 준다(레벨마다 능력치 포인트 3·체력/정신/영력 회복은 평소와 같음).
-- · 아직 못 마친 장만: 단서 넷·가설 둘·마침 표시(world_case_progress), 장 퀘스트 mq_<장> 마침(world_quest_progress),
--   장 보상(전·가방 칸·능력치 포인트·탈것, 물품은 가방이 넘치지 않게 개인 창고로). 장 보상 경험치는 주지 않는다(레벨을 직접 맞추므로).
-- · 「n장 해결」 기록(world_events story)은 원정 중인 사람도 남도록 이 기록만 트리거 없이 넣고, 칭호·꾸미기 판정은 따로 부른다.
-- · 다시 돌려도 이미 마친 장은 건너뛴다.
do $do$
declare
  names text[] := array['조의신', '강산하', '여보', '황지호'];
  c record; ch record; uid uuid; need bigint; lv int; rw jsonb; k text; q int; st jsonb; done text[] := '{}'; n_ch int;
begin
  for c in select owner_id, character_name, level, experience from public.world_characters where character_name = any(names) order by character_name loop
    uid := c.owner_id; n_ch := 0;
    -- ① Lv30
    if c.level < 30 then
      need := -c.experience;
      for lv in c.level..29 loop need := need + public.world_xp_need(lv); end loop;
      perform public.world_grant_xp(uid, need::int);
    end if;
    -- ② 주 이야기 1~10장
    for ch in select * from public.world_story_chapters order by seq loop
      if exists (select 1 from public.world_case_progress p where p.owner_id = uid and p.case_id = ch.chapter_id
                  and p.combined ? (case when ch.chapter_id = 'red_seal' then 'redseal_case_completed' else ch.chapter_id || '_completed' end)) then
        continue;
      end if;
      insert into public.world_case_progress(owner_id, case_id, clues, combined, updated_at)
      values (uid, ch.chapter_id,
        (select coalesce(jsonb_agg(jsonb_build_object('id', s.clue_id, 'title', s.name, 'region', s.region_id, 'found_at', now()) order by s.sort), '[]') from public.world_story_clues s where s.chapter_id = ch.chapter_id),
        (select coalesce(jsonb_agg(x.combo_id order by x.sort), '[]') from public.world_story_combos x where x.chapter_id = ch.chapter_id)
          || jsonb_build_array(case when ch.chapter_id = 'red_seal' then 'redseal_case_completed' else ch.chapter_id || '_completed' end),
        now())
      on conflict (owner_id, case_id) do update set clues = excluded.clues, combined = excluded.combined, updated_at = now();
      insert into public.world_quest_progress(owner_id, quest_id, step, started_at, step_started_at, done_at)
      values (uid, 'mq_' || ch.chapter_id, (select max(step) from public.world_quest_steps where quest_id = 'mq_' || ch.chapter_id), now(), now(), now())
      on conflict (owner_id, quest_id) do update set step = excluded.step, done_at = coalesce(public.world_quest_progress.done_at, now());
      -- 장 보상(경험치 제외)
      rw := coalesce(ch.rewards, '{}');
      update public.world_characters set gil = gil + coalesce((rw ->> 'gil')::int, 0),
        bag_capacity = least(400, bag_capacity + coalesce((rw ->> 'bag')::int, 0)),
        stat_points = least(117, stat_points + coalesce((rw ->> 'stat')::int, 0)), updated_at = now()
      where owner_id = uid;
      if rw ? 'mount' then insert into public.world_owned_mounts(owner_id, mount_id, acquired_at) values (uid, rw ->> 'mount', now()) on conflict do nothing; end if;
      if rw ? 'items' then
        select items into st from public.world_storage where owner_id = uid;
        st := coalesce(st, '{}');
        for k, q in select key, value::text::int from jsonb_each(rw -> 'items') loop st := public.world_inv_add(st, k, q); end loop;
        insert into public.world_storage(owner_id, items, updated_at) values (uid, st, now())
        on conflict (owner_id) do update set items = excluded.items, updated_at = now();
      end if;
      -- 「n장 해결」 기록: 원정 중이면 행동 막기 트리거가 거절하므로 이 한 줄만 트리거 없이 넣는다
      set local session_replication_role = replica;
      insert into public.world_events(actor_id, actor_name, event_type, content, payload)
      values (uid, c.character_name, 'story', ch.seq || '장 「' || ch.title || '」 해결', jsonb_build_object('v2', true, 'chapter_id', ch.chapter_id, 'granted', '7.4.0 시험'));
      set local session_replication_role = origin;
      n_ch := n_ch + 1;
    end loop;
    perform public.world_title_award_check(uid, 'story');
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (uid, 'reward', '하드 콘텐츠 시험 준비', 'Lv30·주 이야기 10장 마침으로 맞췄습니다. 새로 마친 장의 보상(전·가방 칸·능력치 포인트·탈것)을 드렸고, 물품은 개인 창고에 넣었습니다. 쌓인 능력치 포인트는 캐릭터 › 성장에서 나눠 주세요.', '{}');
    done := done || (c.character_name || ' 새로 마친 장 ' || n_ch);
  end loop;
  raise notice '%', array_to_string(done, ' / ');
end $do$;
