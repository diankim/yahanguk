do $d$
declare r record; n int := 0; pins int;
begin
  for r in select c.owner_id from public.world_characters c
            where not exists (select 1 from public.world_staff s where s.owner_id = c.owner_id)
              and not exists (select 1 from public.world_letters l where l.recipient_id = c.owner_id and l.items ? 'hair_pattern' and l.title = '고마운 마음을 담아')
  loop
    select count(*) into pins from public.world_letters where recipient_id = r.owner_id and pinned;
    insert into public.world_letters(recipient_id, sender_id, sender_name, title, body, items, pinned)
    values (r.owner_id, null, '야행국 운영진', '고마운 마음을 담아',
      '야행국의 밤을 함께 걸어 주셔서 고맙습니다. 즐겁게 플레이해 주신 데 대한 작은 감사의 뜻으로 「머리 그리기 도안」 한 장을 보내 드립니다.' || E'\n\n' ||
      '· 안전지대에서 이 서신의 물품 받기를 누르면 가방에 들어옵니다.' || E'\n' ||
      '· 「내 모습」에서 머리를 직접 그려 저장할 때 한 장을 씁니다.' || E'\n\n' ||
      '앞으로도 야행국에서 즐거운 밤 보내시길 바랍니다.',
      '{"hair_pattern": 1}'::jsonb, pins < 5);
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (r.owner_id, 'letter', '운영진이 감사의 선물을 보냈습니다', '서신함에 「머리 그리기 도안」 한 장이 든 서신이 왔습니다.', '{}'::jsonb);
    n := n + 1;
  end loop;
  raise notice 'sent %', n;
end $d$;
