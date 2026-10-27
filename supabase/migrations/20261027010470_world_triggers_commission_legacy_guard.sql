-- 의뢰 진행·옛 방식 차단 트리거
CREATE TRIGGER trg_world_guard_legacy_actions BEFORE INSERT ON public.world_events FOR EACH ROW EXECUTE FUNCTION public.world_guard_legacy_actions();
CREATE TRIGGER trg_world_track_commissions AFTER INSERT ON public.world_events FOR EACH ROW EXECUTE FUNCTION public.world_track_commissions();
REVOKE ALL ON FUNCTION public.world_guard_legacy_actions(), public.world_track_commissions() FROM PUBLIC, anon, authenticated;
ALTER FUNCTION public.world_guard_legacy_actions() OWNER TO fn_owner_field;
ALTER FUNCTION public.world_track_commissions() OWNER TO fn_owner_field;
