-- 7.2.8 꼬마 동무 도감: 범품 바구니를 어느 안전지대 상점에서 파는지 「얻는 곳」에 적는다(상점 목록 world_shop_catalog에서 계산).
-- 바구니는 회차마다 다른 물품처럼 나왔다 빠졌다 한다(상점 규칙은 그대로). 파는 상점이 없는 종은 그렇게 적는다.
update public.world_pet_species p set how = coalesce(
    (select '안전지대 상점의 바구니 · ' || string_agg(distinct r.region_name, '·' order by r.region_name) || ' (회차마다 진열이 바뀝니다)'
       from public.world_shop_catalog sc join public.world_map_regions r on r.shop_id = sc.shop_id and r.is_safe_zone
      where sc.item_id = 'pt_' || p.pet_id),
    '안전지대 상점의 바구니 · 지금은 파는 상점이 없습니다')
 where p.grade = 1;

update public.world_patch_notes set body = body || $n$

## 7.2.8
- 꼬마 동무 도감의 「얻는 곳」에 범품 바구니를 파는 안전지대 상점을 적었습니다. 바구니는 다른 물품처럼 회차(07·15·23시)마다 진열이 바뀝니다.
- 7.2.7 배포 직후 이동이 끝나지 않고 길에 멈추던 문제를 고쳤습니다(멈춰 있던 분들은 목적지에 도착 처리했습니다).
$n$ where note_id = '7.2.0' and position('## 7.2.8' in body) = 0;

update public.world_app_meta set value = '20261103070000' where key = 'db_version';
