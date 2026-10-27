-- 생존 행동 바로잡기
-- - 부적 정화(cleanse): 황지가 아니라 정화 부적(ward_talisman)을 1개 쓴다. 정화할 침식이 없으면 쓰지 않는다(부적도 그대로).
-- - 마음 다잡기(ground): 15분 쿨타임(서버 world_events 기록으로 판단). 정신이 가득하고 침식도 없으면 쓰지 않는다.
--   지금 지명(본부 객사·연무장·팔괘진)에서도 할 수 있게 한다(옛 지명만 적혀 있어 사실상 정청에서만 됐다).
-- - 본부 휴식(rest) 경로: 잠깐 쉬기와 같은 10분 쿨타임을 함께 쓴다(화면에는 없는 경로지만 직접 불러도 무한히 회복하지 못하게).
-- - world_rest_status에 마음 다잡기 쿨타임(ground_ready_at)을 더한다.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

grant fn_owner_18944 to postgres with inherit true;
create or replace function public.world_survival_action(p_action text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; inv jsonb; result_text text; last_at timestamptz; er int;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select * into c from public.world_characters where owner_id=uid for update;
 if not found then raise exception '캐릭터를 먼저 등록하세요.'; end if;
 if c.downed_at is not null or c.health<=0 then raise exception '전투불능 상태입니다. 다른 조사원의 구조를 받아야 행동할 수 있습니다.'; end if;
 inv:=coalesce(c.inventory,'{}'::jsonb);
 if p_action='rest' then
   if c.location not in ('본부 로비','야행국 본부 · 로비','야행국 본부 정청','hq_yard','hq_dorm','본부 객사') then
     raise exception '안전한 휴식은 본부 로비나 기숙사에서만 가능합니다.';
   end if;
   select max(created_at) into last_at from public.world_events where actor_id=uid and event_type='rest' and payload->>'style'='short' and created_at>now()-interval '10 minutes';
   if last_at is not null then raise exception '%', format('잠깐 쉬기는 %s분 뒤에 다시 할 수 있습니다.', ceil(extract(epoch from last_at+interval '10 minutes'-now())/60)); end if;
   update public.world_characters set health=least(100,health+25),mental=least(100,mental+20),spiritual_power=least(100,spiritual_power+15),updated_at=now() where owner_id=uid returning * into c;
   result_text:='안전 구역에서 휴식했다. 체력 +25, 정신 안정도 +20, 영력 +15.';
   insert into public.world_events(actor_id,actor_name,event_type,content,payload) values(uid,c.character_name,'rest',result_text,jsonb_build_object('style','short','via','survival'));
 elsif p_action='cleanse' then
   if coalesce((inv->>'ward_talisman')::integer,0)<1 then raise exception '정화 부적이 없습니다. 안전지대 상점에서 사거나 만들 수 있습니다.'; end if;
   if coalesce(c.erosion,0)<=0 then raise exception '정화할 침식이 없습니다. 정화 부적은 그대로 남겨 두었습니다.'; end if;
   inv:=case when (inv->>'ward_talisman')::integer<=1 then inv-'ward_talisman' else jsonb_set(inv,'{ward_talisman}',to_jsonb((inv->>'ward_talisman')::integer-1)) end;
   er:=greatest(0,c.erosion-25);
   update public.world_characters set inventory=inv,erosion=er,erosion_stage=case when er>=80 then 4 when er>=55 then 3 when er>=30 then 2 when er>=10 then 1 else 0 end,mental=least(100,mental+8),updated_at=now() where owner_id=uid returning * into c;
   result_text:='정화 부적을 태워 정화 의식을 마쳤다. 침식 -25, 정신 안정도 +8.';
 elsif p_action='ground' then
   if c.location not in ('본부 로비','야행국 본부 · 로비','야행국 본부 정청','hq_yard','hq_dorm','야행국 본부 · 연무장','hq_training','본부 객사','연무장·팔괘진') then raise exception '정신 안정 의식은 본부의 안전 구역에서만 가능합니다.'; end if;
   if coalesce(c.mental,0)>=100 and coalesce(c.erosion,0)<=0 then raise exception '정신이 이미 맑습니다. 다잡을 것이 없습니다.'; end if;
   select max(created_at) into last_at from public.world_events where actor_id=uid and event_type='survival' and payload->>'action'='ground' and created_at>now()-interval '15 minutes';
   if last_at is not null then raise exception '%', format('마음 다잡기는 %s분 뒤에 다시 할 수 있습니다.', ceil(extract(epoch from last_at+interval '15 minutes'-now())/60)); end if;
   er:=greatest(0,c.erosion-10);
   update public.world_characters set mental=least(100,mental+18),erosion=er,erosion_stage=case when er>=80 then 4 when er>=55 then 3 when er>=30 then 2 when er>=10 then 1 else 0 end,updated_at=now() where owner_id=uid returning * into c;
   result_text:='호흡과 주문으로 정신을 가다듬었다. 정신 안정도 +18, 침식 -10.';
 else raise exception '알 수 없는 생존 행동입니다.'; end if;
 if p_action<>'rest' then
   insert into public.world_events(actor_id,actor_name,event_type,content,payload) values(uid,c.character_name,'survival',result_text,jsonb_build_object('action',p_action,'erosion',c.erosion,'mental',c.mental));
 end if;
 return jsonb_build_object('content',result_text,'health',c.health,'mental',c.mental,'spiritual_power',c.spiritual_power,'erosion',c.erosion,'erosion_stage',c.erosion_stage,'inventory',c.inventory,
   'ground_ready_at',case when p_action='ground' then now()+interval '15 minutes' end);
end; $function$;
grant fn_owner_18944 to postgres with inherit false;

create or replace function public.world_rest_status()
returns jsonb language plpgsql stable security definer set search_path to '' as $function$
declare uid uuid := public.fn_owner_auth_uid(); s timestamptz; f timestamptz; g timestamptz;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select max(created_at) into s from public.world_events where actor_id = uid and event_type = 'rest' and payload ->> 'style' = 'short' and created_at > now() - interval '10 minutes';
  select max(created_at) into f from public.world_events where actor_id = uid and event_type = 'rest' and payload ->> 'style' = 'full' and created_at > now() - interval '30 minutes';
  select max(created_at) into g from public.world_events where actor_id = uid and event_type = 'survival' and payload ->> 'action' = 'ground' and created_at > now() - interval '15 minutes';
  return jsonb_build_object('short_ready_at', s + interval '10 minutes', 'full_ready_at', f + interval '30 minutes', 'ground_ready_at', g + interval '15 minutes', 'now', now());
end $function$;

select position('ward_talisman' in pg_get_functiondef('public.world_survival_action(text)'::regprocedure)) > 0 as cleanse_uses_ward,
       position('ground_ready_at' in pg_get_functiondef('public.world_rest_status()'::regprocedure)) > 0 as rest_status_has_ground;
