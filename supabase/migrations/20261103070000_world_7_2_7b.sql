-- 7.2.7 덧붙임(패치노트는 7.2.7 항목 아래에 이어 적는다)
-- ① 까치 바구니가 어느 상점에도 없던 것: 백골 장터(frontier_market)·철벽 고찰(north_market) 상점에 넣는다(다른 바구니와 같은 300전, 회차마다 진열이 바뀜)
insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max)
select s, 'pt_magpie', 300, 0, 10 from unnest(array['frontier_market', 'north_market']) s
where not exists (select 1 from public.world_shop_catalog c where c.shop_id = s and c.item_id = 'pt_magpie');

-- ② 꼬마 동무 도감: 범품 바구니를 어느 안전지대 상점에서 파는지 「얻는 곳」에 적는다(상점 목록에서 계산)
update public.world_pet_species p set how = coalesce(
    (select '안전지대 상점의 바구니 · ' || string_agg(distinct r.region_name, '·' order by r.region_name) || ' (회차마다 진열이 바뀝니다)'
       from public.world_shop_catalog sc join public.world_map_regions r on r.shop_id = sc.shop_id and r.is_safe_zone
      where sc.item_id = 'pt_' || p.pet_id),
    '안전지대 상점의 바구니 · 지금은 파는 상점이 없습니다')
 where p.grade = 1;

-- ③ 패치노트: 7.2.7 항목(본문 맨 끝)에 이어 적는다
update public.world_patch_notes set body = rtrim(body, E'\n') || $n$
- 까치 바구니를 백골 장터·철벽 고찰 상점에서도 팝니다(그동안 파는 곳이 없었습니다). 꼬마 동무 도감의 「얻는 곳」에 바구니를 파는 상점을 적었습니다. 바구니는 다른 물품처럼 회차(07·15·23시)마다 진열이 바뀝니다.
- 7.2.7 배포 직후 이동이 끝나지 않고 길에 멈추던 문제를 고쳤습니다(멈춰 있던 분들은 목적지에 도착 처리했습니다).
$n$ where note_id = '7.2.0' and position('까치 바구니를 백골 장터' in body) = 0;

update public.world_app_meta set value = '20261103070000' where key = 'db_version';
