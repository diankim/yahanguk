-- 11차 버그 수정(서버)
-- 1) 장비 제한 문구에 영문 코드(artificer·소속·능력치)가 그대로 나오던 문제 → 한글 이름
-- 2) 파티 나가기·해체(world_party_leave): 혼자 남은 파티장은 해체, 다른 파티원이 있으면 가장 먼저 들어온 파티원에게 파티장을 넘긴다.
--    분배하지 않은 공동 전리품이 있으면 해체를 막는다(전리품이 함께 사라지지 않도록).
-- 3) 파티 초대를 보내면 받는 사람에게 알림(kind=party_invite)을 남겨 화면에 바로 뜨게 하고, 응답하면 그 알림을 읽음 처리한다.

-- 기존 함수는 각자 다른 최소 권한 역할(fn_owner_*)이 소유한다. postgres는 그 역할의 구성원이지만 소유자 권한을
-- 물려받지 않으므로(must be owner 오류), 바꾸는 동안만 inherit를 켜고 끝나면 원래대로(inherit false) 되돌린다.
-- 함수 소유자·search_path·권한은 바뀌지 않는다.

create or replace function public.world_job_name(p_job text) returns text
language sql immutable set search_path = '' as $$
  select case p_job when 'exorcist' then '퇴마관' when 'scout' then '현장 조사원' when 'medic' then '의무관'
    when 'sealmaster' then '봉인술사' when 'analyst' then '기록 분석관' when 'artificer' then '법구 제작사' else '특정 직업' end
$$;
create or replace function public.world_faction_name(p_faction text) returns text
language sql immutable set search_path = '' as $$
  select case p_faction when 'headquarters' then '본부 직속' when 'fieldbureau' then '현장대응국' when 'archivebureau' then '기록감찰국'
    when 'sealbureau' then '봉인관리국' when 'medicalbureau' then '의무지원국' when 'independent' then '외부 협력자' else '특정 소속' end
$$;
create or replace function public.world_stat_name(p_stat text) returns text
language sql immutable set search_path = '' as $$
  select case p_stat when 'strength' then '근력' when 'agility' then '민첩' when 'vitality' then '체질' when 'perception' then '감각'
    when 'willpower' then '의지' when 'spirit_affinity' then '영성' else '능력치' end
$$;
revoke all on function public.world_job_name(text), public.world_faction_name(text), public.world_stat_name(text) from public, anon, authenticated;
grant execute on function public.world_job_name(text), public.world_faction_name(text), public.world_stat_name(text) to fn_owner_18453;

grant fn_owner_18453, fn_owner_19386, fn_owner_19387 to postgres with inherit true;

-- 1) 장착 제한 문구 한글화
do $$ declare def text; nd text; begin
  def := pg_get_functiondef('public.world_equip_item(text)'::regprocedure);
  nd := replace(def, '''직업 제한: % 전용 장비입니다.'',it.required_job', '''직업 제한: % 전용 장비입니다.'',public.world_job_name(it.required_job)');
  nd := replace(nd, '''소속 제한: % 전용 장비입니다.'',it.required_faction', '''소속 제한: % 전용 장비입니다.'',public.world_faction_name(it.required_faction)');
  nd := replace(nd, '''능력치 조건 미달: % % 필요'',stat_key,required', '''능력치 조건 미달: % % 필요'',public.world_stat_name(stat_key),required');
  if nd = def or position('world_job_name' in nd) = 0 or position('world_faction_name' in nd) = 0 or position('world_stat_name' in nd) = 0 then
    raise exception 'world_equip_item 문구를 찾지 못했습니다.'; end if;
  execute nd;
end $$;

-- 2) 초대 알림
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

-- 소유자 권한 물려받기를 원래대로 끈다.
grant fn_owner_18453, fn_owner_19386, fn_owner_19387 to postgres with inherit false;

-- 파티 나가기·해체
-- 소유자는 fn_owner_field(이미 파티 테이블 조회·삭제와 알림 작성 권한이 있다). 모자란 수정 권한만 더한다.
grant update on public.world_parties, public.world_party_members, public.world_party_invites to fn_owner_field;
grant select on public.world_party_loot_pool to fn_owner_field;

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
alter function public.world_party_leave() owner to fn_owner_field;
revoke all on function public.world_party_leave() from public, anon, authenticated;
grant execute on function public.world_party_leave() to authenticated;
