insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, unlock_faction, unlock_region, unlock_item, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method)
select v.id, v.nm, v.spd, v.lv, m.unlock_reputation, m.unlock_faction, m.unlock_region, m.unlock_item, m.price, v.descr, m.tier, m.passenger_capacity, m.fare_tokens, m.fare_free, m.acquire_method
  from public.world_mount_catalog m, (values
    ('leaf_ox', '낱장 황소', 2.40, 47, '값귀가 무너지며 흩날린 빈 낱장이 모여 일어선 황소. 이름도 값도 지워진 흰 종이 몸이라 등에 무엇을 얹어도 셈하지 않는다. 운임은 구간당 노정패 1.'),
    ('first_night_horse', '첫 밤 흑마', 2.50, 50, '백야를 걷어 낸 조사원을 태우는 검은 말. 갈기에 처음 돌아온 밤의 별이 박혀 있고, 발굽이 닿는 자리마다 그림자가 다시 진다. 운임은 구간당 노정패 1.')) v(id, nm, spd, lv, descr)
 where m.mount_id = 'moonless_boat'
on conflict (mount_id) do update set mount_name = excluded.mount_name, speed_multiplier = excluded.speed_multiplier, unlock_level = excluded.unlock_level, description = excluded.description;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, equipment_traits, tradeable, reference_price, stack_size, quality_grade, market_only) values
  ('hf_gg_scale', '값을 덮은 대저울', 'furniture', 5, '별채 가구 · 장식. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d": 1, "w": 2, "hk": "gg_scale", "cat": "장식", "top": 0, "kind": "floor", "grade": 5}'::jsonb, false, 2000, 1, 0, false),
  ('hf_by_lamp_pillar', '맹약 마당 등 기둥', 'furniture', 5, '별채 가구 · 조명. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 갑니다.', false, '{}'::jsonb, 1, '{"d": 1, "w": 1, "hk": "by_lamp_pillar", "cat": "조명", "top": 0, "kind": "floor", "grade": 5}'::jsonb, false, 2000, 1, 0, false)
on conflict (item_id) do nothing;
insert into public.world_furniture_sources(source, item_id, chance) values ('gg_first', 'hf_gg_scale', 1), ('by_first', 'hf_by_lamp_pillar', 1) on conflict do nothing;

select pg_temp.yh_patch('public.world_housing_event_trg()',
  $q$    perform public.world_housing_grant_once(new.actor_id, 'mk_first', '먹그림자 첫 처치');
$q$,
  $q$    perform public.world_housing_grant_once(new.actor_id, 'mk_first', '먹그림자 첫 처치');
  elsif new.event_type = 'gg_win' then
    perform public.world_housing_grant_once(new.actor_id, 'gg_first', '값귀 첫 처치');
  elsif new.event_type = 'by_win' then
    perform public.world_housing_grant_once(new.actor_id, 'by_first', '백야 첫 승리');
$q$);
drop trigger if exists trg_world_housing_event on public.world_events;
create trigger trg_world_housing_event after insert on public.world_events for each row
  when (new.event_type = any (array['combat', 'expedition_end', 'story', 'gw_win', 'mk_win', 'gg_win', 'by_win'])) execute function public.world_housing_event_trg();

insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
  ('fr_gapgwi', 'frame', 'legend', '장터 저울 테', '깊은 장부에서 값귀를 쓰러뜨린다', '외전', '{"ev": "gg_win"}', false, true, 1120),
  ('pt_gapgwi', 'pattern', 'legend', '엄지 도장 낱장 무늬', '깊은 장부에서 값귀를 3번 쓰러뜨린다', '외전', '{"n": 3, "ev": "gg_win"}', false, true, 1121),
  ('sl_gga', 'seal', 'legend', '낙관 「價」', '깊은 장부에서 값귀를 10번 쓰러뜨린다', '외전', '{"n": 10, "ev": "gg_win"}', false, true, 1122),
  ('fr_baekya', 'frame', 'legend', '일곱 등 테', '깊은 판에서 백야를 이긴다', '외전', '{"ev": "by_win"}', false, true, 1130),
  ('pt_baekya', 'pattern', 'legend', '멈춘 화살 등불 무늬', '깊은 판에서 백야를 3번 이긴다', '외전', '{"n": 3, "ev": "by_win"}', false, true, 1131),
  ('sl_so', 'seal', 'legend', '낙관 「宵」', '깊은 판에서 백야를 10번 이긴다', '외전', '{"n": 10, "ev": "by_win"}', false, true, 1132)
on conflict (cosmetic_key) do nothing;

do $c$
begin
  if exists (select 1 from public.world_title_catalog where title_name in ('붉은 골목의 단골', '장터를 되찾은 이', '흰 마당의 손님', '밤을 돌려준 이')
      and title_key not in ('gg_kill3', 'gg_kill25', 'by_kill3', 'by_kill25')) then
    raise exception '칭호 이름 겹침: 값귀·백야 처치 칭호';
  end if;
end $c$;
insert into public.world_title_catalog(title_key, title_name, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('gg_kill3', '붉은 골목의 단골', '깊은 장부에서 값귀를 3번 쓰러뜨린다.', '깊은 장부에서 값귀를 3번 쓰러뜨린다', '{"healing_pct": 4, "incoming_damage_pct": -3}', true, false, '{"n": 3, "ev": "gg_win"}', 3109, '명등기', 4),
  ('gg_kill25', '장터를 되찾은 이', '깊은 장부에서 값귀를 25번 쓰러뜨린다.', '깊은 장부에서 값귀를 25번 쓰러뜨린다', '{"crit_pct": 2, "erosion_pct": -8, "rare_loot_pct": 3}', true, false, '{"n": 25, "ev": "gg_win"}', 3111, '명등기', 5),
  ('by_kill3', '흰 마당의 손님', '깊은 판에서 백야를 3번 이긴다.', '깊은 판에서 백야를 3번 이긴다', '{"healing_pct": 4, "incoming_damage_pct": -3}', true, false, '{"n": 3, "ev": "by_win"}', 3115, '명등기', 4),
  ('by_kill25', '밤을 돌려준 이', '깊은 판에서 백야를 25번 이긴다.', '깊은 판에서 백야를 25번 이긴다', '{"crit_pct": 2, "erosion_pct": -8, "rare_loot_pct": 3}', true, false, '{"n": 25, "ev": "by_win"}', 3117, '명등기', 5)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus,
  rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;
update public.world_title_catalog t set sort = v.s from (values ('gg_kill10', 3110), ('gg_solo', 3112), ('gg_flawless', 3113), ('by_kill1', 3114), ('by_kill10', 3116), ('by_solo', 3118), ('by_flawless', 3119)) v(k, s)
 where t.title_key = v.k and t.sort <> v.s;
