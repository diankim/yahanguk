-- 상점 구매가 "permission denied for table world_item_catalog"로 실패하던 문제.
-- world_shop_buy는 구매 뒤 아이템 이름을 읽는데, 소유 역할에 카탈로그 조회 권한이 없었다.
-- 필요한 열만 내부 함수 역할에 준다(클라이언트 권한은 그대로).
grant select (item_id, item_name) on public.world_item_catalog to fn_owner_18877;
