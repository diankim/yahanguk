-- 물가 풍경인데 낚시터가 없던 곳에 낚시터를 둔다: 염등촌(바다)·수경루(호수), 그리고 연못이 있는 폐쇄된 연화원(늪).
insert into public.world_fish_grounds(region_id, habitat, ground_name, description) values
  ('salt_village', 'sea', '염등촌 소금밭 갯가', '소금밭 끝에 바닷물이 드나드는 갯가. 해가 지면 이름을 부르지 말고 조용히 낚으세요.'),
  ('mirror_pavilion', 'lake', '수경루 난간 아래', '누각 난간 아래 거울 같은 호수. 물에 비친 얼굴이 먼저 찌를 봅니다.'),
  ('sealed_garden', 'marsh', '연화원 연못', '연꽃이 한밤중 사람 얼굴을 비추는 연못. 진흙 바닥에 물고기가 숨어 있습니다.')
on conflict (region_id) do nothing;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028110000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
