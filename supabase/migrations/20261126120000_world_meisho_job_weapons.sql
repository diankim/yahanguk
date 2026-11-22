create temp table yh_mzw(id text, src text, job text, name text, descr text) on commit drop;
insert into yh_mzw values
  ('w_melee_mz', 'w_melee_mz', 'artificer', null, null),
  ('w_melee_mzl', 'w_melee_mzl', 'artificer', null, null),
  ('w_ranged_mz', 'w_ranged_mz', 'scout', null, null),
  ('w_ranged_mzl', 'w_ranged_mzl', 'scout', null, null),
  ('w_magic_mz', 'w_magic_mz', 'exorcist', null, null),
  ('w_magic_mzl', 'w_magic_mzl', 'exorcist', null, null),
  ('w_blood_mz', 'w_melee_mz', 'bloodknight', '명석 대검', '이름 서린 명석을 두드려 두껍게 벼린 대검. 명소에서 「명석의 정」이 더 잘 보인다.'),
  ('w_blood_mzl', 'w_melee_mzl', 'bloodknight', '등불 서린 명석 대검', '등불 서린 명석을 두드려 두껍게 벼린 대검이다. 명소에서 「명석의 정」이 더 잘 보인다.'),
  ('w_spear_mz', 'w_melee_mz', 'spearman', '명석 장창', '이름 서린 명석으로 창날을 세운 장창. 명소에서 「명석의 정」이 더 잘 보인다.'),
  ('w_spear_mzl', 'w_melee_mzl', 'spearman', '등불 서린 명석 장창', '등불 서린 명석으로 창날을 세운 장창이다. 명소에서 「명석의 정」이 더 잘 보인다.'),
  ('w_dagger_mz', 'w_melee_mz', 'analyst', '명석 단도', '이름 서린 명석을 얇게 갈아 낸 단도. 명소에서 「명석의 정」이 더 잘 보인다.'),
  ('w_dagger_mzl', 'w_melee_mzl', 'analyst', '등불 서린 명석 단도', '등불 서린 명석을 얇게 갈아 낸 단도다. 명소에서 「명석의 정」이 더 잘 보인다.'),
  ('w_tamer_mz', 'w_ranged_mz', 'tamer', '명목 단궁', '이름 서린 명목을 휘어 만든 단궁. 명소에서 「명목의 정」이 더 잘 보인다.'),
  ('w_tamer_mzl', 'w_ranged_mzl', 'tamer', '등불 서린 명목 단궁', '등불 서린 명목을 휘어 만든 단궁이다. 명소에서 「명목의 정」이 더 잘 보인다.'),
  ('w_medic_mz', 'w_magic_mz', 'medic', '명초 부채', '이름 서린 명초를 살에 먹인 부채. 명소에서 「명초의 정」이 더 잘 보인다.'),
  ('w_medic_mzl', 'w_magic_mzl', 'medic', '등불 서린 명초 부채', '등불 서린 명초를 살에 먹인 부채다. 명소에서 「명초의 정」이 더 잘 보인다.'),
  ('w_seal_mz', 'w_magic_mz', 'sealmaster', '명초 금강령', '이름 서린 명초 기름으로 닦은 금강령. 명소에서 「명초의 정」이 더 잘 보인다.'),
  ('w_seal_mzl', 'w_magic_mzl', 'sealmaster', '등불 서린 명초 금강령', '등불 서린 명초 향을 품은 금강령이다. 명소에서 「명초의 정」이 더 잘 보인다.'),
  ('w_form_mz', 'w_magic_mz', 'formation', '명초 나경', '이름 서린 명초 잎을 판에 눌러 박은 나경. 명소에서 「명초의 정」이 더 잘 보인다.'),
  ('w_form_mzl', 'w_magic_mzl', 'formation', '등불 서린 명초 나경', '등불 서린 명초 잎을 판에 눌러 박은 나경이다. 명소에서 「명초의 정」이 더 잘 보인다.');

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
       rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, use_fx, market_only)
select m.id, m.name, s.category, s.tier, m.descr, s.stackable, s.required_stats, s.required_job, s.required_faction, s.minimum_level,
       s.rarity, s.acquisition_difficulty, s.drop_rate_modifier, jsonb_set(s.equipment_traits, '{jobs}', jsonb_build_array(m.job)), s.crafting_specialization,
       s.tradeable, s.reference_price, s.stack_size, s.use_fx, s.market_only
  from yh_mzw m join public.world_item_catalog s on s.item_id = m.src
 where m.id <> m.src;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
       rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade, use_fx, market_only)
select m.id || '_hq', m.name || ' (우수)', h.category, h.tier, h.description, h.stackable, h.required_stats, h.required_job, h.required_faction, h.minimum_level,
       h.rarity, h.acquisition_difficulty, h.drop_rate_modifier, jsonb_set(h.equipment_traits, '{jobs}', jsonb_build_array(m.job)), h.crafting_specialization,
       h.tradeable, h.reference_price, h.stack_size, m.id, h.quality_grade, h.use_fx, h.market_only
  from yh_mzw m join public.world_item_catalog h on h.item_id = m.src || '_hq'
 where m.id <> m.src;

update public.world_item_catalog c set equipment_traits = jsonb_set(c.equipment_traits, '{jobs}', jsonb_build_array(m.job))
  from yh_mzw m where c.item_id = m.id and m.id = m.src;

update public.world_item_catalog h set description = b.description || ' ' || public.world_item_hq_note(b.item_id, b.category),
       equipment_traits = public.world_item_hq_traits(b.equipment_traits)
  from yh_mzw m join public.world_item_catalog b on b.item_id = m.id
 where h.item_id = m.id || '_hq';

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description,
       minimum_level, required_job, recipe_difficulty, quality_bonus, required_skill, required_skill_rank, craft_field)
select 'r_' || m.id, m.name || ' 만들기', m.id, r.output_qty, r.ingredients, r.required_tool, r.required_tool_tier, r.required_location,
       '명장의 솜씨로 ' || m.name || '을(를) 만든다.',
       r.minimum_level, r.required_job, r.recipe_difficulty, r.quality_bonus, r.required_skill, r.required_skill_rank, r.craft_field
  from yh_mzw m join public.world_crafting_recipes r on r.output_item = m.src
 where m.id <> m.src;

do $m$
declare r record; tgt text; inv jsonb;
begin
  for r in
    select c.owner_id, c.job_key, e.item_id, i.base_item_id is not null as hq, coalesce(i.base_item_id, i.item_id) base_id, i.tier
      from public.world_characters c
      join public.world_character_equipment e on e.owner_id = c.owner_id and e.slot = 'weapon'
      join public.world_item_catalog i on i.item_id = e.item_id
     where coalesce(i.base_item_id, i.item_id) in (select id from yh_mzw)
       and not (i.equipment_traits -> 'jobs' ? c.job_key)
  loop
    select m.id into tgt from yh_mzw m join public.world_item_catalog x on x.item_id = m.id
     where m.job = r.job_key and x.tier = r.tier limit 1;
    if tgt is null then continue; end if;
    if r.hq then tgt := tgt || '_hq'; end if;
    if not exists (select 1 from public.world_item_durability where owner_id = r.owner_id and item_id = tgt) then
      update public.world_item_durability set item_id = tgt where owner_id = r.owner_id and item_id = r.item_id;
    end if;
    if not exists (select 1 from public.world_gear_enhance where owner_id = r.owner_id and item_id = tgt) then
      update public.world_gear_enhance set item_id = tgt where owner_id = r.owner_id and item_id = r.item_id;
    end if;
    select inventory into inv from public.world_characters where owner_id = r.owner_id for update;
    inv := case when coalesce((inv ->> r.item_id)::int, 0) > 1 then jsonb_set(inv, array[r.item_id], to_jsonb((inv ->> r.item_id)::int - 1)) else inv - r.item_id end;
    inv := jsonb_set(inv, array[tgt], to_jsonb(coalesce((inv ->> tgt)::int, 0) + 1));
    update public.world_characters set inventory = inv where owner_id = r.owner_id;
    update public.world_character_equipment set item_id = tgt where owner_id = r.owner_id and slot = 'weapon';
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.owner_id, 'guide', '무기를 바꿔 드렸습니다',
            '명장 무기가 직업마다 나뉘어, 끼고 있던 ' || (select item_name from public.world_item_catalog where item_id = r.item_id) || '을(를) 같은 단계의 '
              || (select item_name from public.world_item_catalog where item_id = tgt) || '(으)로 바꿔 끼워 드렸습니다. 우수품·강화·내구도는 그대로입니다.',
            jsonb_build_object('tip', 'weapon_swap', 'from', r.item_id, 'to', tgt));
  end loop;
end $m$;

update public.world_patch_notes set body = body || E'\n\n## 3.7.1b\n- 명장 무기(명석·명목·명초, 등불 서린 것 포함)가 직업마다 하나씩으로 나뉘었습니다. 7단계와 8단계에 열 직업 모두 제 무기가 있고, 위력·효과·제작 재료는 그대로입니다. 새로 생긴 것: 명석 대검(혈기사)·명석 장창(여명 창객)·명석 단도(암영 검객)·명목 단궁(조련사)·명초 부채(의무관)·명초 금강령(봉인술사)·명초 나경(진법가), 그리고 각각의 등불 서린 것.\n- 명석 참명도·등불 서린 명석 환도는 호위 무사, 명목 흑단궁·등불 서린 명목 각궁은 월궁 사수, 명초 법등·등불 서린 명초 법등은 퇴마관 무기가 됩니다. 다른 직업이 끼고 있던 명장 무기는 같은 단계의 제 직업 명장 무기로 바꿔 끼워 드렸습니다.'
 where note_id = '3.7.0' and body not like '%## 3.7.1b%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126120000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
