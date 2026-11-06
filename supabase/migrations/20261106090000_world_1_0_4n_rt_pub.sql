do $$
declare t text;
begin
  foreach t in array array['world_active_sessions','world_chat_messages','world_circle_messages','world_notifications','world_raids','world_party_messages'] loop
    if exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime drop table public.%I', t);
    end if;
  end loop;
end $$;

update public.world_patch_notes set body = replace(body,
  E'- 상태이상 창의 치료 단추에 우수품도 함께 뜹니다.\n',
  E'- 상태이상 창의 치료 단추에 우수품도 함께 뜹니다.\n- 동료 돌보기의 물품 목록에도 우수품이 뜹니다(효과도 우수품 그대로).\n- 채팅·알림·토벌 소식을 받는 길을 하나로 모아 서버 부담을 크게 줄였습니다. 처음 접속하거나 다시 이어질 때 잠깐 늦을 수 있습니다.\n- 도움말 「합동 토벌 · 결전 · 협동 기술」에 기여도 갈래 무게, 봉연의 그림자 세기, 협동 기술이 인원에 따라 달라지는 방식을 적었습니다.\n')
where note_id = '1.0.0' and position('동료 돌보기의 물품 목록에도 우수품' in body) = 0;

update public.world_app_meta set value = '20261106090000' where key = 'db_version';
