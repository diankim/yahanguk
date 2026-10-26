-- 의뢰 진행·옛 방식 차단 트리거, 상태이상 굴림(동시 10개, 탐색은 함정 결과로만 상태를 건다)
CREATE TRIGGER trg_world_guard_legacy_actions BEFORE INSERT ON public.world_events FOR EACH ROW EXECUTE FUNCTION public.world_guard_legacy_actions();
CREATE TRIGGER trg_world_track_commissions AFTER INSERT ON public.world_events FOR EACH ROW EXECUTE FUNCTION public.world_track_commissions();
REVOKE ALL ON FUNCTION public.world_guard_legacy_actions(), public.world_track_commissions() FROM PUBLIC;
ALTER FUNCTION public.world_guard_legacy_actions() OWNER TO fn_owner_field;
ALTER FUNCTION public.world_track_commissions() OWNER TO fn_owner_field;

CREATE OR REPLACE FUNCTION public.world_status_roll(p_activity text, p_context jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid:=public.fn_owner_auth_uid(); pick text; st public.world_status_catalog%rowtype; existing public.world_character_statuses%rowtype; roll numeric; applied jsonb:='[]'::jsonb; status_cap integer:=10; current_count integer;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 if p_activity not in ('combat','explore','gather','craft','investigation','training','travel','rest','rescue','story') then raise exception '알 수 없는 활동 유형입니다.'; end if;
 -- 현장 탐색은 함정·징조 결과로 직접 상태를 건다(탐색마다 무작위로 걸지 않는다)
 if p_activity='explore' and coalesce(p_context->>'kind','')='field_search' then return jsonb_build_object('ok',true,'activity',p_activity,'applied',applied,'max_active',status_cap); end if;
 if not exists(select 1 from public.world_characters where owner_id=uid) then raise exception '캐릭터를 먼저 생성하세요.'; end if;
 delete from public.world_character_statuses where owner_id=uid and expires_at<=now();
 select count(*) into current_count from public.world_character_statuses where owner_id=uid;
 roll:=random();
 if p_activity in ('explore','combat','travel') and roll<0.08 then
   pick:=case when random()<0.35 then 'bleeding' when random()<0.55 then 'sprain' when random()<0.75 then 'shaken' when random()<0.90 then 'burned' else 'adrenaline' end;
 elsif p_activity in ('explore','gather') and roll<0.18 then
   pick:=case when random()<0.30 then 'keen_senses' when random()<0.55 then 'fieldcraft' when random()<0.75 then 'lucky_find' else 'poisoned' end;
 elsif p_activity='combat' and roll<0.16 then
   pick:=case when random()<0.6 then 'combat_rhythm' else 'adrenaline' end;
 elsif p_activity in ('craft','investigation','training') and roll<0.22 then
   pick:=case when random()<0.25 then 'focused' when random()<0.50 then 'steady_hands' when random()<0.72 then 'inspired' when random()<0.88 then 'fatigue' else 'overtrained' end;
 elsif p_activity='rest' and roll<0.65 then
   pick:=case when random()<0.45 then 'well_rested' when random()<0.75 then 'clear_mind' else 'steady_hands' end;
 elsif p_activity in ('combat','gather','craft','investigation','training','travel') and roll<0.24 then
   pick:=case when random()<0.25 then 'fatigue' when random()<0.45 then 'disoriented' when random()<0.65 then 'cold' when random()<0.82 then 'stomach_upset' else 'focused' end;
 end if;
 if pick is null then return jsonb_build_object('ok',true,'activity',p_activity,'applied',applied,'active_count',current_count,'max_active',status_cap); end if;
 select * into st from public.world_status_catalog where status_key=pick and active and p_activity=any(triggers);
 if not found then return jsonb_build_object('ok',true,'activity',p_activity,'applied',applied,'active_count',current_count,'max_active',status_cap); end if;
 select * into existing from public.world_character_statuses where owner_id=uid and status_key=pick and expires_at>now() order by expires_at desc limit 1 for update;
 if found then
   update public.world_character_statuses set stacks=least(st.max_stacks,stacks+1),potency=least(3,potency+1),expires_at=greatest(expires_at,now())+make_interval(mins=>least(st.duration_minutes,15)) where status_id=existing.status_id;
   applied:=jsonb_build_array(jsonb_build_object('key',pick,'name',st.status_name,'refreshed',true));
 elsif current_count<status_cap then
   insert into public.world_character_statuses(owner_id,status_key,source_activity,expires_at,metadata) values(uid,pick,p_activity,now()+make_interval(mins=>st.duration_minutes),'{}'::jsonb);
   applied:=jsonb_build_array(jsonb_build_object('key',pick,'name',st.status_name,'polarity',st.polarity));
 end if;
 return jsonb_build_object('ok',true,'activity',p_activity,'applied',applied,'active_count',current_count,'max_active',status_cap);
end $function$;
