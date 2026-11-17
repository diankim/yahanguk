insert into public.world_pet_species (pet_id, pet_name, grade, kind, likes, how, sort, egg) values
('ug_vortex_jelly', '아기 소용돌이 해파리', 4, 'water', 'treat_fish', '극 판 교환', 92, false),
('ug_ink_tadpole', '먹방울 올챙이', 4, 'shadow', 'treat_fish', '극 판 교환', 93, false),
('ug_abacus_ladybug', '주판알 무당벌레', 4, 'shell', 'treat_honey', '극 판 교환', 94, false)
on conflict (pet_id) do update set pet_name = excluded.pet_name, grade = excluded.grade, kind = excluded.kind, likes = excluded.likes, how = excluded.how, sort = excluded.sort, egg = excluded.egg;

insert into public.world_cosmetic_catalog (cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
('fr_ug_gwiheo', 'frame', 'legend', '극 귀허', '극 판 교환', '극', '{"shop": "ultimate"}', false, true, 1700),
('fr_ug_gapgwi', 'frame', 'legend', '극 장부', '극 판 교환', '극', '{"shop": "ultimate"}', false, true, 1701),
('pt_ug_inkline', 'pattern', 'legend', '먹줄', '극 판 교환', '극', '{"shop": "ultimate"}', false, true, 1702),
('sl_ug_heo', 'seal', 'legend', '낙관 「虛」', '극 판 교환', '극', '{"shop": "ultimate"}', false, true, 1703),
('sl_ug_jong', 'seal', 'legend', '낙관 「終」', '극 판 교환', '극', '{"shop": "ultimate"}', false, true, 1704)
on conflict (cosmetic_key) do update set kind = excluded.kind, tier = excluded.tier, cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text,
  category = excluded.category, rule = excluded.rule, hidden = excluded.hidden, active = excluded.active, sort = excluded.sort;
