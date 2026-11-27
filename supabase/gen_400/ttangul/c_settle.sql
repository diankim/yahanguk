create or replace function public.world_du_settle(p_fight uuid, p_won boolean)
 returns void language plpgsql security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_boss_fight_rules(p_fight); f public.world_gw_fights%rowtype; m record; today date := (now() at time zone 'Asia/Seoul')::date;
  rec public.world_gw_records%rowtype; n int; solo boolean; flawless boolean; is_first boolean; xp int; msg text; lv int; v_gil int; v_got text; v_n int;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status not in ('fight', 'wait') then return; end if;
  update public.world_gw_fights set status = case when p_won then 'won' else 'failed' end, ended_at = now(), updated_at = now(), hp = case when p_won then 0 else hp end where fight_id = p_fight;
  select count(*), coalesce(sum(falls), 0) = 0 into n, flawless from public.world_gw_members where fight_id = p_fight;
  solo := n = 1;
  if f.mode = 'story' then
    for m in select * from public.world_gw_members where fight_id = p_fight loop
      update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
      if p_won then
        insert into public.world_gw_records(owner_id, boss_id) values (m.owner_id, 'ttangul_story') on conflict do nothing;
        select * into rec from public.world_gw_records where owner_id = m.owner_id and boss_id = 'ttangul_story' for update;
        is_first := coalesce(rec.kills, 0) = 0;
        update public.world_gw_records set kills = kills + 1, last_kill_day = today, first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id and boss_id = 'ttangul_story';
        v_gil := 0;
        if is_first then
          v_gil := (r -> 'first' ->> 'gil')::int;
          update public.world_characters set gil = gil + v_gil, updated_at = now() where owner_id = m.owner_id;
        end if;
        insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '땅울이를 잠재웠습니다',
          case when is_first then '고임터에서 땅울이를 잠재웠습니다. ' || to_char(v_gil, 'FM999,999') || '전을 받았습니다. 이야기를 이어 가세요.'
            else '고임터에서 다시 한 번 땅울이를 잠재웠습니다.' end,
          jsonb_build_object('fight_id', p_fight, 'boss', 'ttangul', 'mode', 'story', 'first', is_first));
      else
        insert into public.world_notifications(user_id, kind, title, content, payload)
        values (m.owner_id, 'gw', '땅울이 앞에서 밀려났습니다', '이야기판은 밀려나도 잃는 것이 없습니다. 숨을 고르고 다시 서세요.', jsonb_build_object('fight_id', p_fight, 'boss', 'ttangul', 'mode', 'story'));
      end if;
    end loop;
  else
    for m in select * from public.world_gw_members where fight_id = p_fight loop
      if p_won then
        update public.world_characters set health = greatest(1, m.hp), updated_at = now() where owner_id = m.owner_id;
        insert into public.world_gw_records(owner_id, boss_id) values (m.owner_id, 'ttangul') on conflict do nothing;
        select * into rec from public.world_gw_records where owner_id = m.owner_id and boss_id = 'ttangul' for update;
        if rec.last_kill_day is distinct from today then
          is_first := coalesce(rec.kills, 0) = 0;
          update public.world_gw_records set kills = kills + 1, last_kill_day = today, first_kill_at = coalesce(first_kill_at, now()) where owner_id = m.owner_id and boss_id = 'ttangul';
          select level into lv from public.world_characters where owner_id = m.owner_id;
          xp := case when lv >= (r ->> 'xp_cap_lv')::int then 0
            else round(public.world_xp_need(lv) * case when is_first then (r -> 'first' ->> 'xp')::numeric else (r -> 'again' ->> 'xp')::numeric end) end;
          v_gil := case when is_first then (r -> 'first' ->> 'gil')::int else (r -> 'again' ->> 'gil')::int end;
          update public.world_characters set gil = gil + v_gil, updated_at = now() where owner_id = m.owner_id;
          if xp > 0 then xp := coalesce((public.world_grant_xp_got(m.owner_id, xp) ->> 'xp')::int, 0); end if;
          v_got := '';
          if is_first and r -> 'first' ->> 'mount' is not null then
            insert into public.world_owned_mounts(owner_id, mount_id) values (m.owner_id, r -> 'first' ->> 'mount') on conflict do nothing;
            v_got := v_got || ' · 탈것 「' || (r -> 'first' ->> 'mount_name') || '」';
          end if;
          if is_first and r -> 'first' ->> 'furniture_name' is not null then v_got := v_got || ' · 별채 가구 「' || (r -> 'first' ->> 'furniture_name') || '」'; end if;
          if r -> 'both' ->> 'name_style' is not null and exists (select 1 from public.world_gw_records g where g.owner_id = m.owner_id and g.boss_id = r -> 'both' ->> 'with' and g.kills > 0) then
            insert into public.world_faction_unlocks(owner_id, unlock_key) values (m.owner_id, r -> 'both' ->> 'name_style') on conflict do nothing;
            get diagnostics v_n = row_count;
            if v_n > 0 then v_got := v_got || ' · 이름 색 「' || (r -> 'both' ->> 'name_style_name') || '」'; end if;
          end if;
          msg := case when is_first then '땅울이를 처음으로 잠재웠습니다. ' || to_char(v_gil, 'FM999,999') || '전' || case when xp > 0 then ' · 경험치 ' || xp else '' end || v_got || '을(를) 받았습니다.'
            else '땅울이를 잠재웠습니다(' || (coalesce(rec.kills, 0) + 1) || '번째). ' || v_gil || '전' || case when xp > 0 then ' · 경험치 ' || xp else '' end || v_got || '.' end;
          insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '땅울이 진정', msg, jsonb_build_object('fight_id', p_fight, 'first', is_first, 'boss', 'ttangul'));
          insert into public.world_events(actor_id, actor_name, event_type, content, payload)
          values (m.owner_id, m.name, 'du_win', m.name || '이(가) 고임터에서 땅울이를 잠재웠습니다.',
                  jsonb_build_object('fight_id', p_fight, 'boss', 'ttangul', 'first', is_first, 'solo', solo, 'flawless', flawless and n >= 2, 'members', n, 'kills', coalesce(rec.kills, 0) + 1));
        else
          insert into public.world_notifications(user_id, kind, title, content, payload) values (m.owner_id, 'reward', '땅울이 진정', '오늘은 이미 처치를 인정받아 보상은 없습니다. 연습 삼아 몇 번이든 다시 설 수 있습니다.', jsonb_build_object('fight_id', p_fight, 'boss', 'ttangul'));
        end if;
      else
        update public.world_item_durability d set durability = greatest(0, d.durability - ceil(public.world_item_max_durability(d.item_id) * (r -> 'fail' ->> 'dur')::numeric / 100.0)::int), updated_at = now()
          from public.world_character_equipment e where e.owner_id = m.owner_id and d.owner_id = m.owner_id and d.item_id = e.item_id;
        perform public.world_yohwa_overflow(m.owner_id, (select erosion from public.world_characters where owner_id = m.owner_id) + (r -> 'fail' ->> 'er')::int - 100);
        update public.world_characters set health = greatest(1, m.hp), erosion = least(100, erosion + (r -> 'fail' ->> 'er')::int),
               erosion_stage = case when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 80 then 4 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 55 then 3
                 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 30 then 2 when least(100, erosion + (r -> 'fail' ->> 'er')::int) >= 10 then 1 else 0 end,
               updated_at = now() where owner_id = m.owner_id;
        insert into public.world_gw_records(owner_id, boss_id, last_fail_at) values (m.owner_id, 'ttangul', now()) on conflict (owner_id, boss_id) do update set last_fail_at = now();
        insert into public.world_notifications(user_id, kind, title, content, payload)
        values (m.owner_id, 'gw', '땅울이 도전 실패', '무너지는 돌판에서 물러났습니다. 장착한 장비 내구도가 ' || (r -> 'fail' ->> 'dur') || '% 닳고 침식이 ' || (r -> 'fail' ->> 'er') || ' 올랐습니다. '
          || '바로 다시 도전할 수 있습니다.', jsonb_build_object('fight_id', p_fight, 'boss', 'ttangul'));
      end if;
    end loop;
  end if;
  perform public.world_gw_say(p_fight, f.round, case when p_won then 'win' else 'bad' end, case when p_won
    then '땅울이의 울음이 낮게 잦아든다. 돌판 밑에 고였던 빛이 갈라진 틈으로 천천히 흘러 나가고, 고임터 바닥이 제자리로 가라앉는다.'
    else '도전이 끝났습니다.' end);
end $f$;

