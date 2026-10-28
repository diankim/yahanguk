-- 긴급 수정(2026-10-29 21:10 KST, 운영 DB에 바로 적용함): 제작할 때 「permission denied for function world_bag_count」로 막히던 문제.
-- world_bag_room은 부른 쪽 권한으로 도는 함수(security invoker)라, 그 안의 world_bag_count·world_item_stack·world_inv_count를
-- 부르는 함수 주인 역할(fn_owner_*)마다 실행 권한이 있어야 한다. 4.0.0에서 제작(fn_owner_18452)이 world_bag_room을 쓰기 시작하며 드러났다.
-- 함수 주인 역할에만 주므로 anon·authenticated(조사원)의 권한은 그대로다.
do $T$ declare r text; begin
  grant fn_owner_expedition to postgres with inherit true, set true;
  for r in select rolname from pg_roles where rolname like 'fn_owner_%' loop
    execute format('grant execute on function public.world_bag_count(jsonb), public.world_item_stack(text), public.world_inv_count(jsonb) to %I', r);
  end loop;
  grant fn_owner_expedition to postgres with inherit false, set false;
end $T$;

-- 접속 중인 화면에 「새로고침」 안내를 띄운다
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029055000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
