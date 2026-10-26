-- world_claim_idle_activity: 선언되지 않은 v_activity_type 참조를 v.activity_type 으로 수정.
-- 휴식(rest)을 제외한 training/research/maintenance 수령이 모두
-- 'column "v_activity_type" does not exist' 로 실패하던 문제.
-- 소유자(fn_owner_19181)·ACL·search_path 는 그대로 유지하고, 기존 패턴대로
-- 임시 SET/CREATE 권한을 부여했다가 같은 마이그레이션 안에서 회수한다.

GRANT fn_owner_19181 TO postgres WITH SET TRUE;
GRANT CREATE ON SCHEMA public TO fn_owner_19181;

SET ROLE fn_owner_19181;
CREATE OR REPLACE FUNCTION public.world_claim_idle_activity()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare v public.world_idle_activities%rowtype; c public.world_characters%rowtype;
 v_hours numeric; v_gain integer; v_exp integer; v_xp integer; v_level integer; v_points integer;
 v_new_level integer; v_levels integer:=0; v_skill text; v_skill_xp integer; v_old_skill_xp integer; v_result jsonb:='{}'::jsonb;
begin
 if public.fn_owner_auth_uid() is null then raise exception '로그인 후 이용할 수 있습니다.'; end if;
 select * into v from public.world_idle_activities where owner_id=public.fn_owner_auth_uid() and status='active' for update;
 if not found then raise exception '수령할 자율 활동이 없습니다.'; end if;
 if now()<v.started_at+make_interval(mins=>v.duration_minutes) then raise exception '아직 활동 시간이 끝나지 않았습니다.'; end if;
 select * into c from public.world_characters where owner_id=public.fn_owner_auth_uid() for update;
 if not found then raise exception '캐릭터 정보를 찾을 수 없습니다.'; end if;
 v_hours:=v.duration_minutes::numeric/60.0;
 v_gain:=greatest(1,floor(v_hours*12*0.35)::integer);
 v_exp:=case when c.level>=100 then 0 else greatest(1,floor(v_hours*(case v.activity_type when 'training' then 12 when 'research' then 10 when 'maintenance' then 8 else 3 end)*0.35)::integer) end;
 v_skill:=case v.activity_type when 'training' then 'melee' when 'research' then 'tracking' when 'maintenance' then 'wardcraft' else null end;
 if v.activity_type='rest' then
   update public.world_characters set health=least(100,health+v_gain),mental=least(100,mental+v_gain),spiritual_power=least(100,spiritual_power+v_gain),experience=experience+v_exp where owner_id=public.fn_owner_auth_uid();
   v_result:=jsonb_build_object('message','휴식 완료','health',v_gain,'mental',v_gain,'spiritual_power',v_gain,'experience',v_exp);
 else
   v_skill_xp:=v_gain;
   select coalesce((skill_progress->v_skill->>'xp')::integer,0) into v_old_skill_xp from public.world_characters where owner_id=public.fn_owner_auth_uid();
   if v.activity_type='training' then
     update public.world_characters set experience=experience+v_exp,combat_xp=least(500000,combat_xp+v_skill_xp),
       skill_progress=coalesce(skill_progress,'{}'::jsonb)||jsonb_build_object(v_skill,jsonb_build_object('xp',least(500000,v_old_skill_xp+v_skill_xp),'rank',least(50,1+floor(least(500000,v_old_skill_xp+v_skill_xp)/100.0)::integer))) where owner_id=public.fn_owner_auth_uid();
     v_result:=jsonb_build_object('message','자율수련 완료','combat_xp',v_skill_xp,'experience',v_exp);
   elsif v.activity_type='research' then
     update public.world_characters set experience=experience+v_exp,investigation_xp=least(500000,investigation_xp+v_skill_xp),
       skill_progress=coalesce(skill_progress,'{}'::jsonb)||jsonb_build_object(v_skill,jsonb_build_object('xp',least(500000,v_old_skill_xp+v_skill_xp),'rank',least(50,1+floor(least(500000,v_old_skill_xp+v_skill_xp)/100.0)::integer))) where owner_id=public.fn_owner_auth_uid();
     v_result:=jsonb_build_object('message','자료 조사 완료','investigation_xp',v_skill_xp,'experience',v_exp,'rare_clues',0);
   else
     update public.world_characters set experience=experience+v_exp,crafting_xp=least(600000,crafting_xp+v_skill_xp),
       skill_progress=coalesce(skill_progress,'{}'::jsonb)||jsonb_build_object(v_skill,jsonb_build_object('xp',least(600000,v_old_skill_xp+v_skill_xp),'rank',least(50,1+floor(least(600000,v_old_skill_xp+v_skill_xp)/120.0)::integer))) where owner_id=public.fn_owner_auth_uid();
     v_result:=jsonb_build_object('message','장비 정비 완료','crafting_xp',v_skill_xp,'experience',v_exp,'items_created',0);
   end if;
 end if;
 select experience,level,stat_points into v_xp,v_level,v_points from public.world_characters where owner_id=public.fn_owner_auth_uid();
 v_new_level:=v_level;
 if v_new_level<100 then
   while v_new_level<100 and v_xp>=v_new_level*100 loop v_xp:=v_xp-v_new_level*100;v_new_level:=v_new_level+1;v_levels:=v_levels+1;end loop;
 else v_xp:=0; end if;
 update public.world_characters set experience=case when v_new_level>=100 then 0 else v_xp end,level=v_new_level,
   stat_points=least(297,v_points+v_levels*3),health=least(100,health+v_levels*10),
   mental=least(100,mental+v_levels*5),spiritual_power=least(100,spiritual_power+v_levels*5),updated_at=now()
 where owner_id=public.fn_owner_auth_uid();
 update public.world_idle_activities set status='claimed',claimed_at=now(),reward=v_result where id=v.id;
 return v_result||jsonb_build_object('success',true,'activity_type',v.activity_type,'duration_minutes',v.duration_minutes,'efficiency',0.35,'level_cap',100);
end $function$;
RESET ROLE;

REVOKE CREATE ON SCHEMA public FROM fn_owner_19181;
GRANT fn_owner_19181 TO postgres WITH SET FALSE, INHERIT FALSE;
