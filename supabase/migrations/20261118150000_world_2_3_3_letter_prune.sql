create or replace function public.world_letter_prune(p_uid uuid)
 returns integer language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare r record; n int := 0; spilled jsonb := '{}'::jsonb; lim jsonb := public.world_letter_limits();
  box int := (lim ->> 'box')::int; days int := (lim ->> 'days')::int; gone jsonb := '[]'::jsonb; full_n int := 0;
begin
  for r in
    select l.id, l.items, l.claimed_at, l.title, l.body, l.sender_name, l.created_at,
           l.created_at < now() - make_interval(days => days) as old
      from public.world_letters l
     where l.recipient_id = p_uid and not l.pinned
       and (l.created_at < now() - make_interval(days => days)
            or l.id in (select x.id from public.world_letters x where x.recipient_id = p_uid and not x.pinned
                         order by (x.read_at is null) desc, x.created_at desc, x.id desc
                         offset greatest(0, box - (select count(*) from public.world_letters y where y.recipient_id = p_uid and y.pinned))))
     order by l.created_at
  loop
    if r.claimed_at is null and r.items <> '{}'::jsonb then
      perform public.world_letter_spill(p_uid, r.items);
      spilled := spilled || r.items;
    end if;
    gone := gone || jsonb_build_array(jsonb_build_object('title', r.title, 'body', r.body, 'from_name', r.sender_name, 'at', r.created_at, 'items', r.items, 'why', case when r.old then 'old' else 'full' end));
    if not r.old then full_n := full_n + 1; end if;
    delete from public.world_letters where id = r.id;
    n := n + 1;
  end loop;
  if n > 0 then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_uid, 'letter',
      case when full_n > 0 then '서신함이 가득 찼습니다' else '오래된 서신을 정리했습니다' end,
      case when full_n > 0 then '서신함이 ' || box || '통을 넘어 고정하지 않은 서신 ' || n || '통이 지워졌습니다. 읽은 서신부터, 오래된 것부터 지웁니다.'
        else '받은 지 ' || days || '일이 지난 서신 ' || n || '통이 지워졌습니다.' end
      || case when spilled <> '{}'::jsonb then ' 받지 않은 물품은 개인 창고에 넣었습니다.' else '' end
      || ' 알림의 「지워진 서신 보기」로 글을 다시 읽을 수 있습니다.',
      jsonb_build_object('removed', gone, 'storage', case when spilled <> '{}'::jsonb then spilled end));
  end if;
  return n;
end $function$;

update public.world_patch_notes set body = body || '

- 서신함이 가득 차거나 받은 지 3일이 지나 서신이 지워지면 알림이 옵니다. 알림의 「지워진 서신 보기」로 지워진 서신의 글을 다시 읽을 수 있습니다.
- 서신함이 넘칠 때는 읽은 서신부터, 그다음 오래된 서신부터 지웁니다. 아직 읽지 않은 서신이 먼저 지워지지 않습니다.
- 서신함에 지금 몇 통이 있는지, 몇 통을 고정했는지, 가득 차면 어떤 서신이 지워지는지 서신 칸에 적었습니다.
' where note_id = '2.3.0' and body not like '%지워진 서신 보기%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118150000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
