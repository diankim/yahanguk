insert into public.world_pet_species (pet_id, pet_name, grade, kind, likes, how, sort, egg) values
('bj_mandarin_duck', '아기 원앙', 4, 'bird', 'treat_rice', '비장고 마지막 방에서 만난다', 79, false),
('bj_horseshoe_crab', '아기 투구게', 4, 'shell', 'treat_fish', '비장고 마지막 방에서 만난다', 80, false),
('bj_moon_halo', '꼬마 달무리 혼령', 4, 'ghost', 'treat_rice', '비장고 마지막 방에서 만난다', 81, false),
('bj_rainbow_lizard', '무지개 꼬마 도마뱀', 4, 'venom', 'treat_meat', '비장고 마지막 방에서 만난다', 82, false),
('bj_pink_marten', '분홍 담비', 4, 'wood', 'treat_honey', '비장고 마지막 방에서 만난다', 83, false),
('bj_rose_wolf', '연홍빛 늑대', 4, 'shadow', 'treat_meat', '비장고 마지막 방에서 만난다', 84, false),
('bj_seahorse', '아기 해마', 4, 'water', 'treat_fish', '비장고 마지막 방에서 만난다', 85, false),
('bj_silkmoth', '아기 누에나방', 4, 'swarm', 'treat_herb', '비장고 마지막 방에서 만난다', 86, false),
('bj_bukcheong_lion', '아기 북청사자', 4, 'ward', 'treat_rice', '비장고 마지막 방에서 만난다', 87, false),
('bj_mirage_cat', '신기루 고양이', 4, 'mirror', 'treat_fish', '비장고 마지막 방에서 만난다', 88, false),
('bj_black_goat', '검은 산양', 4, 'breaker', 'treat_herb', '비장고 마지막 방에서 만난다', 89, false),
('bj_phoenix', '아기 봉황', 4, 'sky', 'treat_honey', '비장고 마지막 방에서 만난다', 90, false),
('bj_mountain_turtle', '꼬마 산거북', 4, 'giant', 'treat_herb', '비장고 마지막 방에서 만난다', 91, false)
on conflict (pet_id) do update set pet_name = excluded.pet_name, grade = excluded.grade, kind = excluded.kind, likes = excluded.likes, how = excluded.how, sort = excluded.sort, egg = excluded.egg;

update public.world_app_meta set value = '20261117040000' where key = 'db_version';
