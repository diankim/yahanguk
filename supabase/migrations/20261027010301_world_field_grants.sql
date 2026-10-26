-- fn_owner_field 테이블 권한과 원정 세부 지역 열
GRANT EXECUTE ON FUNCTION public.fn_owner_auth_uid(), public.world_skill_rank(integer, text), public.world_status_effect_total(text),
  public.world_title_bonus(text) TO fn_owner_field;
GRANT SELECT ON public.world_map_regions, public.world_exploration_nodes, public.world_gathering_spots, public.world_region_monsters,
  public.world_item_catalog, public.world_character_equipment, public.world_region_profiles, public.world_status_catalog,
  public.world_major_factions, public.world_idle_activities, public.world_region_sites, public.world_region_theme,
  public.world_mount_catalog, public.world_title_catalog TO fn_owner_field;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.world_active_encounters, public.world_exploration_discoveries, public.world_gathering_discoveries,
  public.world_character_statuses, public.world_case_progress, public.world_region_progress, public.world_region_intel TO fn_owner_field;
GRANT SELECT, INSERT, UPDATE ON public.world_expeditions TO fn_owner_field;
GRANT SELECT, INSERT ON public.world_owned_mounts TO fn_owner_field;
GRANT SELECT ON public.world_characters TO fn_owner_field;
GRANT UPDATE (location, travel_destination, travel_arrives_at, current_exploration_node_id, stamina, stamina_at, health, mental,
  spiritual_power, erosion, erosion_stage, experience, level, stat_points, combat_xp, combat_rank, gathering_xp, gathering_rank,
  investigation_xp, investigation_rank, gil, inventory, bag_capacity, downed_at, mount_tokens, updated_at) ON public.world_characters TO fn_owner_field;
GRANT INSERT ON public.world_events, public.world_notifications, public.world_economy_ledger, public.world_travel_history TO fn_owner_field;
GRANT SELECT ON public.world_travel_history, public.world_events, public.world_character_titles TO fn_owner_field;
GRANT USAGE ON SEQUENCE public.world_events_id_seq, public.world_notifications_id_seq TO fn_owner_field;
GRANT EXECUTE ON FUNCTION public.world_status_roll(text, jsonb) TO fn_owner_field;

ALTER TABLE public.world_expeditions ADD COLUMN IF NOT EXISTS node_id uuid REFERENCES public.world_exploration_nodes(node_id);
