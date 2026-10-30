
-- ─────────────────────────────────────────────────────────────
-- D-2. 세력 배치·가입 Lv5·세력 겨루기 A·B·C(2026-10-29 확정안)
--   배치: 직할령 Lv1~3 여덟 곳은 중립(겨루기에서 빠짐) · 옥문 협로는 북령맹 → 정통파(관청 검문소, 직할령) · 새 지역 11곳은 위 생성기가 넣음
--   가입: 레벨 5부터. 그 세력 거점·본부 정청·그 세력의 낮은 지역(새로 둔 들머리 지역)에서 신청할 수 있고, 가입 퀘스트 보고도 그 지역에서 받는다
--   A 방치 점령지: 본래 주인이 아닌 세력이 차지한 곳에서 그 세력 활동이 6시간 없으면 줄어드는 속도 3% → 8%/시간, 24시간이 지나면 본래 주인에게 돌아감
--   B 독식 보정: 본래 땅 밖에서 차지한 지역 수로 새로 쌓는 영향력 ×1(2곳까지)·×0.8(3)·×0.65(4)·×0.5(5+)
--   C 주간 정산: 매주 월요일 04:00(KST) 지킨 지역을 세력 소식으로 남기고, 지킨 지역 하나마다 그 세력 조사원(가입 퀘스트 마침·그 주 활동)에게 공훈 5, 그 뒤 모든 영향력 절반
-- ─────────────────────────────────────────────────────────────

-- 배치
update public.world_map_regions set home_faction_id = null, control_faction_id = null, faction_control = '중립 직할령', contested = false
 where region_id in ('field_outskirts', 'hq_training', 'shrine_ruins', 'hq_archive', 'paper_bridge', 'old_canal', 'west_gate', 'sealed_garden');
update public.world_map_regions set home_faction_id = 'night_office', control_faction_id = 'night_office', faction_control = '야행국 정통파', contested = false,
       territory_id = 'capital', territory_name = '야행국 직할령'
 where region_id = 'jade_pass';
update public.world_map_regions m set home_faction_id = x.f, control_faction_id = x.f, faction_control = (select faction_name from public.world_major_factions where faction_id = x.f), contested = false
  from (values ('old_prison', 'night_office'), ('seal_vault', 'night_office'), ('tide_gate', 'river_alliance'), ('crimson_altar', 'red_moon_cult'),
               ('snow_hollow', 'north_league'), ('ember_pass', 'southern_remnant'), ('lamp_alley', 'black_lotus'),
               ('star_hill', 'mandate_court'), ('water_clock', 'mandate_court'), ('comet_crater', 'mandate_court'), ('cloud_corridor', 'mandate_court'),
               ('black_tide_rift', 'southern_remnant')) as x(r, f) -- 흑조 균열은 7.2.3에서 남명회로(지도가 끊기지 않게)
 where m.region_id = x.r;
-- 옮겨지거나 중립이 된 곳의 영향력은 0에서 다시(기록은 남김)
update public.world_region_influence set points = 0
 where region_id in ('field_outskirts', 'hq_training', 'shrine_ruins', 'hq_archive', 'paper_bridge', 'old_canal', 'west_gate', 'sealed_garden', 'jade_pass');
insert into public.world_faction_log(kind, region_id, faction_id, other_id, content)
values ('control', 'jade_pass', 'night_office', 'north_league', '세력 배치가 바뀌었습니다. 옥문 협로는 야행국 정통파의 검문소가 되었고, 직할령 들머리 여덟 곳은 어느 세력에도 속하지 않습니다. 새 지역 열한 곳이 열렸습니다.');

-- 세력마다 가입을 받는 곳: 거점 · 본부 정청 · 들머리 지역
create or replace function public.world_faction_join_regions(p_faction text) returns text[]
language sql immutable set search_path = '' as $$
  select case p_faction
    when 'night_office' then array['hq_yard', 'hq_dorm', 'ghost_bamboo']
    when 'red_moon_cult' then array['red_moon_fort', 'hq_yard', 'bone_market', 'red_plain']
    when 'black_lotus' then array['hidden_bazaar', 'hq_yard', 'lamp_alley']
    when 'north_league' then array['iron_monastery', 'hq_yard', 'snow_hollow']
    when 'river_alliance' then array['river_ferry', 'hq_yard', 'salt_village']
    when 'southern_remnant' then array['ember_village', 'hq_yard', 'ember_pass']
    when 'mandate_court' then array['star_observatory', 'hq_yard', 'hq_dorm', 'star_hill']
    else array['hq_yard'] end
$$;
grant execute on function public.world_faction_join_regions(text) to public;

select pg_temp.yh_patch('public.world_join_major_faction(text)', ' if r.region_name is not null and c.location not in (r.region_name,''야행국 본부 · 정청'') then raise exception ''입단 조건: %에서 의식·심사를 완료해야 합니다.'',r.region_name; end if;',
  ' if coalesce(c.level, 1) < 5 then raise exception ''세력 가입은 레벨 5부터 할 수 있습니다.''; end if;
 if c.location not in (select mr.region_name from public.world_map_regions mr where mr.region_id = any (public.world_faction_join_regions(p_faction_id))) then
   raise exception ''입단 조건: % 가운데 한 곳에서 신청해야 합니다.'', (select string_agg(mr.region_name, ''·'' order by array_position(public.world_faction_join_regions(p_faction_id), mr.region_id))
     from public.world_map_regions mr where mr.region_id = any (public.world_faction_join_regions(p_faction_id)));
 end if;');
-- 가입 퀘스트 장면 보고도 들머리 지역에서 받는다
update public.world_faction_scenes s set need = jsonb_set(s.need, '{at}', coalesce(s.need -> 'at', '[]'::jsonb) || to_jsonb(x.r))
  from (values ('night_office', 'ghost_bamboo'), ('red_moon_cult', 'red_plain'), ('black_lotus', 'lamp_alley'), ('north_league', 'snow_hollow'),
               ('river_alliance', 'salt_village'), ('southern_remnant', 'ember_pass'), ('mandate_court', 'star_hill')) as x(f, r)
 where s.faction_id = x.f and s.scene_key like x.f || ':join:%' and not coalesce(s.need -> 'at', '[]'::jsonb) ? x.r;

-- 레벨 5에 닿으면 한 번 알림(대세력이 없을 때)
create or replace function public.world_faction_open_note() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.major_faction_id is null then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (new.owner_id, 'faction_open', '세력 가입이 열렸습니다', '레벨 5가 되어 대세력에 들 수 있습니다. 캐릭터 › 세력에서 세력마다 하는 일과 가입하는 곳을 보세요.', '{}'::jsonb);
  end if;
  return new;
end $$;
revoke all on function public.world_faction_open_note() from public, anon, authenticated;
drop trigger if exists trg_world_faction_open on public.world_characters;
create trigger trg_world_faction_open after update of level on public.world_characters
  for each row when (old.level < 5 and new.level >= 5) execute function public.world_faction_open_note();
select pg_temp.yh_patch('public.world_notify_group(text)', 'when p_kind in (''faction'') then ''faction''', 'when p_kind in (''faction'', ''faction_open'', ''faction_week'') then ''faction''');

-- B. 독식 보정
create or replace function public.world_faction_spread_mult(p_faction text, p_region text) returns numeric
language sql stable set search_path = '' as $$
  select case when (select home_faction_id from public.world_map_regions where region_id = p_region) = p_faction then 1::numeric
    else (select case when n <= 2 then 1 when n = 3 then 0.8 when n = 4 then 0.65 else 0.5 end
            from (select count(*) n from public.world_map_regions mr where mr.active and not mr.is_safe_zone and mr.control_faction_id = p_faction
                   and mr.home_faction_id is not null and mr.home_faction_id <> p_faction) x) end
$$;
select pg_temp.yh_patch('public.world_influence_tick()', 'round(pts * public.world_faction_boost(f), 2)', 'round(pts * public.world_faction_boost(f) * public.world_faction_spread_mult(f, region_id), 2)');

-- A. 방치 점령지: 줄어드는 속도와 되돌림
select pg_temp.yh_patch('public.world_influence_tick()', '  update public.world_region_influence set points = round(points * 0.97, 2) where points > 0;',
  '  update public.world_region_influence i set points = round(i.points * case when i.updated_at < t1 - interval ''6 hours'' and exists (select 1 from public.world_map_regions mr
           where mr.region_id = i.region_id and mr.control_faction_id = i.faction_id and mr.home_faction_id is distinct from i.faction_id) then 0.92 else 0.97 end, 2) where i.points > 0;');
select pg_temp.yh_patch('public.world_influence_tick()', '    select coalesce((select points from public.world_region_influence where region_id = r.region_id and faction_id = r.control_faction_id), 0)',
  '    if r.control_faction_id is distinct from r.home_faction_id
       and coalesce((select updated_at from public.world_region_influence where region_id = r.region_id and faction_id = r.control_faction_id), ''-infinity''::timestamptz) < t1 - interval ''24 hours'' then
      update public.world_map_regions set control_faction_id = r.home_faction_id, faction_control = public.world_mf_name(r.home_faction_id), control_changed_at = t1, contested = false where region_id = r.region_id;
      flips := flips + 1;
      insert into public.world_faction_log(kind, region_id, faction_id, other_id, content)
      values (''control'', r.region_id, r.home_faction_id, r.control_faction_id, public.world_josa(r.region_name, ''이'', ''가'') || '' 하루 넘게 돌보는 이가 없어 본래 주인 '' || public.world_mf_name(r.home_faction_id) || ''에게 돌아갔습니다.'');
      insert into public.world_notifications(user_id, kind, title, content, payload)
      select c.owner_id, ''faction'', ''세력 판도 변화'', public.world_josa(r.region_name, ''이'', ''가'') || '' 본래 주인 '' || public.world_mf_name(r.home_faction_id) || ''에게 돌아갔습니다.'', jsonb_build_object(''region_id'', r.region_id, ''faction_id'', r.home_faction_id)
        from public.world_characters c where c.major_faction_id in (r.home_faction_id, r.control_faction_id) and not coalesce(c.is_dead, false);
      continue;
    end if;
    select coalesce((select points from public.world_region_influence where region_id = r.region_id and faction_id = r.control_faction_id), 0)');

-- C. 주간 정산(pg_cron yh-faction-week, 월요일 04:00 KST = 일요일 19:00 UTC)
create or replace function public.world_faction_weekly() returns jsonb
language plpgsql set search_path = '' as $$
declare f record; names text; n int; who uuid; paid int := 0; lines text := '';
begin
  select owner_id into who from public.world_staff order by owner_id limit 1;
  for f in select mf.faction_id, mf.faction_name from public.world_major_factions mf where mf.active order by mf.faction_id loop
    select string_agg(mr.region_name, '·' order by mr.min_level), count(*) into names, n
      from public.world_map_regions mr where mr.active and not mr.is_safe_zone and mr.home_faction_id is not null and mr.control_faction_id = f.faction_id;
    if coalesce(n, 0) = 0 then continue; end if;
    insert into public.world_faction_log(kind, faction_id, content)
    values ('week', f.faction_id, public.world_josa(f.faction_name, '이', '가') || ' 이번 주 ' || n || '곳을 지켰습니다: ' || names || '.');
    lines := lines || case when lines = '' then '' else ' · ' end || f.faction_name || ' ' || n || '곳';
    with got as (
      update public.world_faction_progress p set merit = coalesce(p.merit, 0) + 5 * n, updated_at = now()
        from public.world_characters c
       where c.owner_id = p.owner_id and c.major_faction_id = f.faction_id and p.faction_id = f.faction_id and p.join_done_at is not null
         and exists (select 1 from public.world_events e where e.actor_id = c.owner_id and e.created_at > now() - interval '7 days')
      returning p.owner_id)
    insert into public.world_notifications(user_id, kind, title, content, payload)
    select g.owner_id, 'faction_week', '주간 세력 정산', f.faction_name || '이(가) 이번 주 ' || n || '곳을 지켜 공훈 ' || (5 * n) || '을(를) 받았습니다.', jsonb_build_object('faction_id', f.faction_id, 'regions', n)
      from got g;
    get diagnostics n = row_count; paid := paid + n;
  end loop;
  if lines <> '' and who is not null then
    insert into public.world_chat_messages(channel_type, sender_id, sender_name, content)
    values ('global', who, '세력 소식', '주간 세력 정산 — ' || lines || '. 모든 지역의 영향력이 절반으로 줄었습니다.');
  end if;
  update public.world_region_influence set points = round(points * 0.5, 2) where points > 0;
  return jsonb_build_object('paid', paid, 'summary', lines);
end $$;
revoke all on function public.world_faction_weekly() from public, anon, authenticated;
select cron.schedule('yh-faction-week', '0 19 * * 0', 'select public.world_faction_weekly()');
