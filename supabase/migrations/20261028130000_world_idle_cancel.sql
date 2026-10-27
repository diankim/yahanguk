-- 자율 활동 중도 그만두기: 끝나기 전에 수령하면 활동을 멈추고 지난 시간만큼만 보상한다(원정 조기 귀환과 같은 방식).
-- 끝나기 전에는 보상의 최소 1 보정을 주지 않는다(바로 그만두기를 되풀이해 보상을 얻지 못하게).
-- 새 함수나 권한 없이 기존 world_claim_idle_activity(소유 fn_owner_19181)를 고친다.
grant fn_owner_19181 to postgres with inherit true;
do $$
declare d text;
  a0 text := $q$v_new_level integer; v_levels integer:=0;$q$;
  a1 text := $q$if now()<v.started_at+make_interval(mins=>v.duration_minutes) then raise exception '아직 활동 시간이 끝나지 않았습니다.'; end if;$q$;
  a2 text := $q$v_hours:=v.duration_minutes::numeric/60.0;$q$;
  a3 text := $q$v_gain:=greatest(1,floor(v_hours*12*0.35)::integer);$q$;
  a4 text := $q$else greatest(1,floor(v_hours*(case v.activity_type$q$;
  a5 text := $q$update public.world_idle_activities set status='claimed'$q$;
begin
  d := pg_get_functiondef('public.world_claim_idle_activity()'::regprocedure);
  if position('v_early' in d) > 0 then return; end if;
  if position(a0 in d) = 0 or position(a1 in d) = 0 or position(a2 in d) = 0 or position(a3 in d) = 0 or position(a4 in d) = 0 or position(a5 in d) = 0 then
    raise exception '자율 활동 수령 함수에서 고칠 줄을 찾지 못했습니다';
  end if;
  d := replace(d, a0, $q$v_new_level integer; v_early boolean; v_levels integer:=0;$q$);
  d := replace(d, a1, $q$v_early := now()<v.started_at+make_interval(mins=>v.duration_minutes);$q$);
  d := replace(d, a2, $q$v_hours:=case when v_early then greatest(0,extract(epoch from (now()-v.started_at)))/3600.0 else v.duration_minutes::numeric/60.0 end;$q$);
  d := replace(d, a3, $q$v_gain:=case when v_early then floor(v_hours*12*0.35)::integer else greatest(1,floor(v_hours*12*0.35)::integer) end;$q$);
  d := replace(d, a4, $q$else greatest(case when v_early then 0 else 1 end,floor(v_hours*(case v.activity_type$q$);
  d := replace(d, a5, $q$if v_early then
   v_result:=v_result||jsonb_build_object('cancelled',true,'elapsed_minutes',floor(v_hours*60)::integer,
     'message',replace(replace(coalesce(v_result->>'message',''),'자율수련','자율 수련'),'완료','중단')||' · 지난 시간만큼만 받았습니다');
 end if;
 $q$ || a5);
  execute d;
end $$;
grant fn_owner_19181 to postgres with inherit false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028130000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
