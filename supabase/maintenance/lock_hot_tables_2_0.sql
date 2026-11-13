-- 2.0 배포 앞(owner_inherit_begin 바로 뒤): 이 묶음이 고치는(alter table·트리거·행 갱신) 기존 표를 처음에 한 번에 잠근다.
-- 중간에 world_events 등을 새로 잠그면, 기록을 먼저 넣고 캐릭터를 기다리는 플레이어 행동과 교착한다(2026-11-13 되돌리는 시험 40P01).
lock table public.world_characters, public.world_events, public.world_item_catalog, public.world_quest_progress, public.world_pets,
  public.world_fish_grounds, public.world_fish_species, public.world_monster_kinds, public.world_gw_fights, public.world_gw_members,
  public.world_gw_records, public.world_wedding_guests, public.world_bug_reports in access exclusive mode;
