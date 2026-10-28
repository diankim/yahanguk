-- 긴급 수정 기록 4.0.1(2026-10-28, 운영 DB에 바로 적용함 — 다시 돌려도 이미 고친 것을 보고 그냥 지나간다)
-- world_equip_item에 전투·원정 검사가 없어 전투 도중·원정 도중 무기를 바꿔 낄 수 있었다(해제는 막혀 있었다). 해제와 같이 막는다.
-- 함수 주인 fn_owner_18453에 두 표 읽기 권한이 없어 함께 준다(그 역할에만, 이용자 권한은 그대로).
grant fn_owner_18453 to postgres with inherit true, set true;
grant select on public.world_active_encounters, public.world_expeditions to fn_owner_18453;
do $$ declare d text := pg_get_functiondef('public.world_equip_item(text)'::regprocedure);
  a text := 'if not found then raise exception ''캐릭터를 먼저 생성하세요.''; end if;';
  b text := ' if exists (select 1 from public.world_active_encounters x where x.owner_id = uid and not x.defeated and not coalesce(x.fled, false)) then raise exception ''전투 중에는 장비를 바꿀 수 없습니다.''; end if;'
    || ' if exists (select 1 from public.world_expeditions x where x.owner_id = uid and x.status = ''active'') then raise exception ''원정 중에는 장비를 바꿀 수 없습니다.''; end if;';
begin
  if position('전투 중에는 장비를 바꿀 수 없습니다' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '장비 장착 고칠 자리'; end if;
  execute replace(d, a, a || b);
end $$;
grant fn_owner_18453 to postgres with inherit false, set false;
