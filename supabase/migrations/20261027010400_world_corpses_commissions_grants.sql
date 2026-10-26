-- 시신·상시 의뢰 테이블과 fn_owner_field 추가 권한(사망·캐릭터 정리·이야기·의뢰·이동 경로용).
CREATE TABLE IF NOT EXISTS public.world_corpses (
  corpse_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL, character_name text NOT NULL, location text NOT NULL, region_id text,
  died_at timestamptz NOT NULL DEFAULT now(), death_reason text,
  items jsonb NOT NULL DEFAULT '{}'::jsonb, gil bigint NOT NULL DEFAULT 0,
  respects uuid[] NOT NULL DEFAULT '{}', looted_by uuid, looted_at timestamptz);
CREATE INDEX IF NOT EXISTS world_corpses_location_idx ON public.world_corpses(location, died_at DESC);
ALTER TABLE public.world_corpses ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.world_commissions (
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, day date NOT NULL, slot smallint NOT NULL,
  kind text NOT NULL CHECK (kind IN ('hunt', 'gather', 'search', 'deliver')), title text NOT NULL, description text NOT NULL,
  target_region text, target_item text, need integer NOT NULL, progress integer NOT NULL DEFAULT 0,
  reward_gil integer NOT NULL, reward_xp integer NOT NULL, reward_item text, claimed_at timestamptz,
  PRIMARY KEY (owner_id, day, slot));
ALTER TABLE public.world_commissions ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON public.world_corpses, public.world_commissions TO fn_owner_field;
GRANT DELETE ON public.world_commissions TO fn_owner_field;
GRANT UPDATE (is_dead, died_at, death_reason, profile, gathering_profession, crafting_profession, life_changed_at)
  ON public.world_characters TO fn_owner_field;
GRANT SELECT ON public.world_faction_supply_claims, public.world_regional_case_claims, public.world_trade_offers,
  public.world_parties, public.world_party_members, public.world_region_progress TO fn_owner_field;
-- 캐릭터 정리(본인 요청)에서만 쓰는 삭제 권한
GRANT DELETE ON public.world_characters, public.world_character_equipment, public.world_character_titles,
  public.world_expedition_state, public.world_expeditions, public.world_idle_activities, public.world_owned_mounts,
  public.world_region_event_progress, public.world_region_site_discoveries, public.world_regional_case_claims,
  public.world_story_progress, public.world_faction_mission_progress, public.world_ride_requests,
  public.world_travel_party_requests, public.world_party_invites, public.world_party_members, public.world_parties,
  public.world_trade_offers, public.world_trade_requests TO fn_owner_field;
GRANT SELECT ON public.world_expedition_state, public.world_region_event_progress, public.world_region_site_discoveries,
  public.world_story_progress, public.world_faction_mission_progress, public.world_ride_requests,
  public.world_travel_party_requests, public.world_party_invites, public.world_trade_requests TO fn_owner_field;
