do $$
declare r jsonb := public.world_boss_rules();
begin
  r := jsonb_set(r, '{dohaesu,first}', (r -> 'dohaesu' -> 'first') || '{"mount": "dh_wave_skiff", "mount_name": "물너울 쪽배", "furniture": "dh_first", "furniture_name": "도해수 비늘 물때표"}'::jsonb);
  r := jsonb_set(r, '{ttangul,first}', (r -> 'ttangul' -> 'first') || '{"furniture": "du_first", "furniture_name": "돌홈 지맥 등잔"}'::jsonb);
  r := jsonb_set(r, '{dohaesu,both}', '{"with": "ttangul", "name_style": "ns:1044", "name_style_name": "물때"}'::jsonb);
  r := jsonb_set(r, '{ttangul,both}', '{"with": "dohaesu", "name_style": "ns:1044", "name_style_name": "물때"}'::jsonb);
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
end $$;

insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, unlock_faction, unlock_region, unlock_item, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method)
select v.id, v.nm, v.spd, v.lv, m.unlock_reputation, m.unlock_faction, m.unlock_region, m.unlock_item, m.price, v.descr, m.tier, m.passenger_capacity, m.fare_tokens, m.fare_free, m.acquire_method
  from public.world_mount_catalog m, (values
    ('dh_wave_skiff', '물너울 쪽배', 2.50, 51, '도해수를 제 바다로 돌려보낸 조사원을 태우는 쪽배. 노를 젓지 않아도 뱃전에 붙은 물너울이 가야 할 쪽으로 밀어 준다. 운임은 구간당 노정패 1.')) v(id, nm, spd, lv, descr)
 where m.mount_id = 'moonless_boat'
on conflict (mount_id) do update set mount_name = excluded.mount_name, speed_multiplier = excluded.speed_multiplier, unlock_level = excluded.unlock_level, description = excluded.description;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size, quality_grade, market_only) values
  ('hf_dh_tide_chart', '도해수 비늘 물때표', 'furniture', 5, '별채 가구 · 장식. 깊은 물목에서 도해수를 처음 돌려보낸 이에게 남는 물때표입니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1,
   '{"hk": "dh_tide_chart", "ww": 1.4, "wh": 34, "cat": "장식", "kind": "wall", "wall": "deco", "grade": 5}'::jsonb, false, 2000, 1, 0, false),
  ('hf_du_vein_lamp', '돌홈 지맥 등잔', 'furniture', 5, '별채 가구 · 조명. 깊은 고임터에서 땅울이를 처음 잠재운 이에게 남는 등잔입니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1,
   '{"d": 1, "w": 1, "hk": "du_vein_lamp", "cat": "조명", "top": 0, "kind": "floor", "grade": 5}'::jsonb, false, 2000, 1, 0, false)
on conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price;
insert into public.world_furniture_sources(source, item_id, chance) values ('dh_first', 'hf_dh_tide_chart', 1), ('du_first', 'hf_du_vein_lamp', 1) on conflict do nothing;

select pg_temp.yh_patch('public.world_housing_event_trg()',
  $q$  elsif new.event_type = 'by_win' then
    perform public.world_housing_grant_once(new.actor_id, 'by_first', '백야 첫 승리');
$q$,
  $q$  elsif new.event_type = 'by_win' then
    perform public.world_housing_grant_once(new.actor_id, 'by_first', '백야 첫 승리');
  elsif new.event_type = 'dh_win' then
    perform public.world_housing_grant_once(new.actor_id, 'dh_first', '도해수 첫 진정');
  elsif new.event_type = 'du_win' then
    perform public.world_housing_grant_once(new.actor_id, 'du_first', '땅울이 첫 진정');
$q$);
drop trigger if exists trg_world_housing_event on public.world_events;
create trigger trg_world_housing_event after insert on public.world_events for each row
  when (new.event_type = any (array['combat', 'expedition_end', 'story', 'gw_win', 'mk_win', 'gg_win', 'by_win', 'dh_win', 'du_win'])) execute function public.world_housing_event_trg();

select pg_temp.yh_patch('public.world_gwiryeong_chance(text,jsonb)',
  $q$p_type in ('gw_win', 'raid_win', 'mk_win', 'gg_win', 'by_win')$q$,
  $q$p_type in ('gw_win', 'raid_win', 'mk_win', 'gg_win', 'by_win', 'dh_win', 'du_win')$q$);
drop trigger if exists trg_world_gwiryeong_roll on public.world_events;
create trigger trg_world_gwiryeong_roll after insert on public.world_events for each row
  when (new.event_type = any (array['gather', 'combat', 'expedition_end', 'gw_win', 'mk_win', 'gg_win', 'by_win', 'dh_win', 'du_win'])) execute function public.world_gwiryeong_roll();

do $c$
begin
  if exists (select 1 from public.world_title_catalog where title_name in ('물목을 연 이', '땅울음을 잠재운 이', '도해록의 끝') and title_key not in ('dh_kill1', 'du_kill1', 'hw_boss_both')) then
    raise exception '칭호 이름 겹침: 도해수·땅울이 처치 칭호';
  end if;
  if exists (select 1 from public.world_cosmetic_catalog where cosmetic_name in ('낙관 「渡」', '땅울림') and cosmetic_key not in ('sl_do', 'fr_ttangul')) then
    raise exception '꾸미기 이름 겹침: 도해수·땅울이';
  end if;
  if exists (select 1 from public.world_mount_catalog where mount_name = '물너울 쪽배' and mount_id <> 'dh_wave_skiff') then
    raise exception '탈것 이름 겹침: 물너울 쪽배';
  end if;
end $c$;
insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('dh_kill1', '물목을 연 이', '깊은 물목에서 도해수를 제 바다로 돌려보냈다.', '깊은 물목에서 도해수를 돌려보낸다', '{"presence": 6, "erosion_pct": -6, "combat_damage_pct": 3}', true, false, '{"n": 1, "ev": "dh_win"}', 3201, '도해록', 5),
  ('du_kill1', '땅울음을 잠재운 이', '깊은 고임터에서 땅울이를 잠재웠다.', '깊은 고임터에서 땅울이를 잠재운다', '{"presence": 6, "erosion_pct": -6, "combat_damage_pct": 3}', true, false, '{"n": 1, "ev": "du_win"}', 3202, '도해록', 5),
  ('hw_boss_both', '도해록의 끝', '물목과 고임터, 두 곳의 막힌 흐름을 모두 제 길로 돌려보냈다.', '깊은 물목의 도해수와 깊은 고임터의 땅울이를 모두 진정시킨다', '{}', true, false,
   '{"all": [{"ev": "dh_win"}, {"ev": "du_win"}]}', 3203, '도해록', 5)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus,
  rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;
insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
  ('sl_do', 'seal', 'legend', '낙관 「渡」', '깊은 물목에서 도해수를 10번 돌려보낸다', '외전', '{"n": 10, "ev": "dh_win"}', false, true, 1140),
  ('fr_ttangul', 'frame', 'legend', '땅울림', '깊은 고임터에서 땅울이를 잠재운다', '외전', '{"ev": "du_win"}', false, true, 1141)
on conflict (cosmetic_key) do update set cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text, rule = excluded.rule, tier = excluded.tier, category = excluded.category;

select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $q$    if c.level < (br ->> 'lv')::int then raise exception 'Lv%부터 도전할 수 있습니다.', br ->> 'lv'; end if;$q$,
  $q$    if c.level < coalesce(case when p_mode = 'story' then (br -> 'story' ->> 'lv')::int end, (br ->> 'lv')::int) then
      raise exception 'Lv%부터 도전할 수 있습니다.', coalesce(case when p_mode = 'story' then br -> 'story' ->> 'lv' end, br ->> 'lv'); end if;$q$, 2);
