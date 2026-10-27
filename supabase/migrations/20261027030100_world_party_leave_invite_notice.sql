-- 11차 버그 수정(서버)
-- 1) 장비 직업 제한 문구에 영문 직업 코드(artificer)가 그대로 나오던 문제 → 한글 직업명
-- 2) 파티 나가기·해체(world_party_leave): 혼자 남은 파티장은 해체, 다른 파티원이 있으면 가장 먼저 들어온 파티원에게 파티장을 넘긴다.
--    분배하지 않은 공동 전리품이 있으면 해체를 막는다(전리품이 함께 사라지지 않도록).
-- 3) 파티 초대를 보내면 받는 사람에게 알림(kind=party_invite)을 남겨 화면에 바로 뜨게 하고, 응답하면 그 알림을 읽음 처리한다.

create or replace function public.world_job_name(p_job text) returns text
language sql immutable set search_path = '' as $$
  select case p_job when 'exorcist' then '퇴마관' when 'scout' then '현장 조사원' when 'medic' then '의무관'
    when 'sealmaster' then '봉인술사' when 'analyst' then '기록 분석관' when 'artificer' then '법구 제작사' else '특정 직업' end
$$;
revoke all on function public.world_job_name(text) from public, anon, authenticated;
grant execute on function public.world_job_name(text) to fn_owner_18453;

do $$ declare def text; nd text; begin
  def := pg_get_functiondef('public.world_equip_item(text)'::regprocedure);
  nd := replace(def, '''직업 제한: % 전용 장비입니다.'',it.required_job', '''직업 제한: % 전용 장비입니다.'',public.world_job_name(it.required_job)');
  if nd = def then raise exception 'world_equip_item 문구를 찾지 못했습니다.'; end if;
  execute nd;
end $$;

-- 초대 알림
grant insert on public.world_notifications to fn_owner_19386;
grant select (id, payload, kind, user_id), update (read_at) on public.world_notifications to fn_owner_19387;
do $$ declare def text; nd text; begin
  def := pg_get_functiondef('public.world_party_invite(uuid)'::regprocedure);
  nd := replace(def, ' return jsonb_build_object(''ok'',true,''invite_id'',inv,''content'',''파티 초대를 보냈습니다.'');',
    ' insert into public.world_notifications(user_id,kind,title,content,payload)
   select p_invitee_id,''party_invite'',''동료 초대'',coalesce(c.character_name,''조사원'')||''님이 동료로 함께하자고 합니다.'',jsonb_build_object(''invite_id'',inv,''party_id'',pid,''inviter_id'',uid,''inviter_name'',c.character_name)
     from public.world_characters c where c.owner_id=uid;
 return jsonb_build_object(''ok'',true,''invite_id'',inv,''content'',''파티 초대를 보냈습니다.'');');
  if nd = def then raise exception 'world_party_invite 반환문을 찾지 못했습니다.'; end if;
  execute nd;
  def := pg_get_functiondef('public.world_party_respond(uuid,boolean)'::regprocedure);
  nd := replace(def, ' if not p_accept then update public.world_party_invites',
    ' update public.world_notifications set read_at=coalesce(read_at,now()) where user_id=uid and kind=''party_invite'' and payload->>''invite_id''=i.invite_id::text;
 if not p_accept then update public.world_party_invites');
  if nd = def then raise exception 'world_party_respond 거절문을 찾지 못했습니다.'; end if;
  execute nd;
end $$;

-- 파티 나가기·해체
grant select, update, delete on public.world_parties to fn_owner_social;
grant select, update, delete on public.world_party_members to fn_owner_social;
grant select, update on public.world_party_invites to fn_owner_social;
grant insert on public.world_notifications to fn_owner_social;
grant select (owner_id, character_name) on public.world_characters to fn_owner_social;

create or replace function public.world_party_leave() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); m public.world_party_members%rowtype; nxt uuid; nm text; others int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into m from public.world_party_members where owner_id = uid for update;
  if not found then raise exception '소속된 파티가 없습니다.'; end if;
  perform 1 from public.world_parties where party_id = m.party_id for update;
  select character_name into nm from public.world_characters where owner_id = uid;
  select count(*) into others from public.world_party_members where party_id = m.party_id and owner_id <> uid;
  if others = 0 then
    if exists (select 1 from public.world_party_loot_pool where party_id = m.party_id and status = 'available') then
      raise exception '분배하지 않은 공동 전리품이 있습니다. 먼저 분배한 뒤 해체하세요.';
    end if;
    update public.world_party_invites set status = 'cancelled', responded_at = now() where party_id = m.party_id and status = 'pending';
    delete from public.world_parties where party_id = m.party_id;
    return jsonb_build_object('ok', true, 'disbanded', true, 'content', '파티를 해체했습니다.');
  end if;
  delete from public.world_party_members where party_id = m.party_id and owner_id = uid;
  if m.role = 'leader' then
    select owner_id into nxt from public.world_party_members where party_id = m.party_id order by joined_at limit 1;
    update public.world_party_members set role = 'leader' where party_id = m.party_id and owner_id = nxt;
    update public.world_parties set leader_id = nxt where party_id = m.party_id;
    update public.world_party_invites set status = 'cancelled', responded_at = now() where party_id = m.party_id and inviter_id = uid and status = 'pending';
  end if;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select pm.owner_id, 'party_leave', '동료 떠남', coalesce(nm, '조사원') || '님이 파티를 떠났습니다.' || case when pm.owner_id = nxt then ' 이제 당신이 파티장입니다.' else '' end,
         jsonb_build_object('party_id', m.party_id)
    from public.world_party_members pm where pm.party_id = m.party_id;
  return jsonb_build_object('ok', true, 'disbanded', false, 'content', '파티에서 나왔습니다.');
end $$;
alter function public.world_party_leave() owner to fn_owner_social;
revoke all on function public.world_party_leave() from public, anon, authenticated;
grant execute on function public.world_party_leave() to authenticated;
