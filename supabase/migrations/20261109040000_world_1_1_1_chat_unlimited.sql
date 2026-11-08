CREATE OR REPLACE FUNCTION public.world_chat_send(p_channel text, p_content text, p_recipient_name text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; target public.world_characters%rowtype; msg public.world_chat_messages%rowtype; clean text:=btrim(coalesce(p_content,'')); day_count integer;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 if char_length(clean)<1 or char_length(clean)>500 then raise exception '메시지는 1~500자로 입력해 주세요.'; end if;
 if p_channel not in ('global','region','whisper','faction') then raise exception '올바르지 않은 채팅 종류입니다.'; end if;
 select * into c from public.world_characters where owner_id=uid;
 if c.owner_id is null then raise exception '먼저 캐릭터를 생성해 주세요.'; end if;
 if exists(select 1 from public.world_chat_messages where sender_id=uid and created_at>now()-interval '2 seconds') then raise exception '메시지를 너무 빠르게 보내고 있어요. 잠시 기다려 주세요.'; end if;
 if p_channel='global' then
  null;
 elsif p_channel='region' then
  if coalesce(c.location,'')='' then raise exception '현재 지역을 확인할 수 없습니다.'; end if;
 elsif p_channel='faction' then
  if c.major_faction_id is null then raise exception '세력에 가입한 캐릭터만 세력 채팅을 이용할 수 있어요.'; end if;
 elsif p_channel='whisper' then
  if coalesce(btrim(p_recipient_name),'')='' then raise exception '귓속말 상대 캐릭터명을 입력해 주세요.'; end if;
  select * into target from public.world_characters where lower(character_name)=lower(btrim(p_recipient_name)) and owner_id<>uid limit 1;
  if target.owner_id is null then raise exception '해당 캐릭터를 찾을 수 없습니다.'; end if;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             if exists(select 1 from public.world_blocks b where b.owner_id=target.owner_id and b.blocked_id=uid) then raise exception '상대가 귓속말을 받지 않습니다.'; end if;
 end if;
 insert into public.world_chat_messages(channel_type,sender_id,sender_name,region,faction_id,recipient_id,content)
 values(p_channel,uid,c.character_name,case when p_channel='region' then c.location else null end,case when p_channel='faction' then c.major_faction_id else null end,case when p_channel='whisper' then target.owner_id else null end,clean)
 returning * into msg;
 return jsonb_build_object('id',msg.id,'channel_type',msg.channel_type,'sender_name',msg.sender_name,'content',msg.content,'created_at',msg.created_at,'recipient_name',case when p_channel='whisper' then target.character_name else null end);
end $function$;

update public.world_patch_notes set body = body || E'\n- 전체 채팅 하루 50회 제한을 없앴습니다(도배 방지 2초 간격은 그대로).'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109040000' where key = 'db_version';
