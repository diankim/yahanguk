-- 긴급 수정: 20261028140000에서 토벌 침식 계산이 지역 위험도를 world_map_regions에서 직접 읽어,
-- 토벌 기록 트리거 소유자(fn_owner_18941)에게 그 표 권한이 없어 요괴를 쓰러뜨리는 마지막 공격이 「권한이 없습니다」로 막혔다.
-- 표 권한을 넓히지 않고, 지역 표를 읽는 소유자(fn_owner_field)가 위험도만 돌려주는 함수로 바꾼다.
create or replace function public.world_region_danger(p_region text)
returns int language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce((select danger_level from public.world_map_regions where region_id = p_region), 1)
$$;
alter function public.world_region_danger(text) owner to fn_owner_field;
revoke all on function public.world_region_danger(text) from public;
grant execute on function public.world_region_danger(text) to fn_owner_18941;

grant fn_owner_18941 to postgres with inherit true;
do $$
declare d text;
  a text := $q$coalesce((select m.danger_level from public.world_map_regions m where m.region_id = payload->>'region_id'), 1)$q$;
begin
  d := pg_get_functiondef('public.world_apply_event_progress()'::regprocedure);
  if position('world_region_danger' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '토벌 침식의 위험도 줄을 찾지 못했습니다'; end if;
  execute replace(d, a, $q$public.world_region_danger(payload->>'region_id')$q$);
end $$;
grant fn_owner_18941 to postgres with inherit false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028160000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
