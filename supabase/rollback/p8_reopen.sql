-- ── 8. 다시 열 준비 ───────────────────────────────────────────────────────────────
-- 동무 선물은 하지 않는다(사용자 결정 2026-10-31): 스위치 off, 선물 명단도 비움
update public.world_app_meta set value = 'off' where key = 'pet_gift';
do $g$ begin if to_regclass('public.world_pet_gifts') is not null then delete from public.world_pet_gifts; end if; end $g$;

-- 초대권: 이 순간부터 7일(world_invite_* 함수가 invite_open_at을 본다)
insert into public.world_app_meta(key, value, changed_at) values ('invite_open_at', now()::text, now())
on conflict (key) do update set value = excluded.value, changed_at = now();

-- 확인: 남은 캐릭터 0, 운영진 명단·초대권·레거시 명단은 그대로
do $v$
declare n int;
begin
  select count(*) into n from public.world_characters;
  if n <> 0 then raise exception 'ROLLBACK: 캐릭터가 % 남았다', n; end if;
  if not exists (select 1 from public.world_staff) then raise exception 'ROLLBACK: 운영진 명단이 비었다'; end if;
  if not exists (select 1 from public.world_legacy_marks) then raise exception 'ROLLBACK: 레거시 명단이 비었다'; end if;
  if public.world_long_night_stage(timestamptz '2026-11-05 12:00+09') <> 0 then raise exception 'ROLLBACK: 장야가 끝나지 않았다'; end if;
end $v$;

update public.world_app_meta set value = '20261105000000' where key = 'db_version';
