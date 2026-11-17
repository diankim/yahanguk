insert into public.world_pet_species (pet_id, pet_name, grade, kind, likes, how, sort, egg) values
('ug_vortex_jelly', '아기 소용돌이 해파리', 4, 'water', 'treat_fish', '무용담 교환', 92, false),
('ug_crown_wisp', '왕관 쓴 꼬마 넋', 4, 'ghost', 'treat_rice', '무용담 교환', 93, false),
('ug_chain_rhino', '사슬 아기 코뿔소', 4, 'breaker', 'treat_herb', '무용담 교환', 94, false),
('ug_seal_mammoth', '봉연 아기 매머드', 4, 'giant', 'treat_herb', '무용담 교환', 95, false),
('ug_ink_tadpole', '먹방울 올챙이', 4, 'shadow', 'treat_fish', '무용담 교환', 96, false),
('ug_hanji_chameleon', '한지 카멜레온', 4, 'mirror', 'treat_meat', '무용담 교환', 97, false),
('ug_brush_panda', '붓꼬리 아기 판다', 4, 'wood', 'treat_herb', '무용담 교환', 98, false),
('ug_go_penguin', '바둑판 아기 펭귄', 4, 'bird', 'treat_fish', '무용담 교환', 99, false),
('ug_tally_hedgehog', '셈가지 고슴도치', 4, 'shell', 'treat_honey', '무용담 교환', 100, false),
('ug_bead_snake', '주판알 꼬마 뱀', 4, 'venom', 'treat_meat', '무용담 교환', 101, false),
('ug_ledger_ant', '장부 지기 개미', 4, 'swarm', 'treat_honey', '무용담 교환', 102, false),
('ug_lantern_bear', '등롱 반달곰', 4, 'ward', 'treat_honey', '무용담 교환', 103, false),
('ug_whitenight_bat', '흰 밤 아기 박쥐', 4, 'sky', 'treat_honey', '무용담 교환', 104, false)
on conflict (pet_id) do update set pet_name = excluded.pet_name, grade = excluded.grade, kind = excluded.kind, likes = excluded.likes, how = excluded.how, sort = excluded.sort, egg = excluded.egg;

insert into public.world_cosmetic_catalog (cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
('fr_ug_gwiheo', 'frame', 'legend', '무용담 · 귀허', '무용담 교환', '무용담', '{"shop": "ultimate"}', false, true, 1700),
('fr_ug_gapgwi', 'frame', 'legend', '무용담 · 장부', '무용담 교환', '무용담', '{"shop": "ultimate"}', false, true, 1701),
('pt_ug_inkline', 'pattern', 'legend', '먹줄', '무용담 교환', '무용담', '{"shop": "ultimate"}', false, true, 1702),
('sl_ug_heo', 'seal', 'legend', '낙관 「虛」', '무용담 교환', '무용담', '{"shop": "ultimate"}', false, true, 1703),
('sl_ug_jong', 'seal', 'legend', '낙관 「終」', '무용담 교환', '무용담', '{"shop": "ultimate"}', false, true, 1704)
on conflict (cosmetic_key) do update set kind = excluded.kind, tier = excluded.tier, cosmetic_name = excluded.cosmetic_name, condition_text = excluded.condition_text,
  category = excluded.category, rule = excluded.rule, hidden = excluded.hidden, active = excluded.active, sort = excluded.sort;
