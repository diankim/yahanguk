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

create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

select pg_temp.yh_fix2('public.world_tourney_tick()'::regprocedure,
$o$      update public.world_tourneys set status = 'running', updated_at = now() where t_id = t.t_id;
      perform public.world_tourney_play_round(t.t_id);$o$,
$n$      update public.world_tourneys set status = 'running', updated_at = now() where t_id = t.t_id;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      select c.owner_id, 'tourney_start', '비무회 시작', venue || '에서 ' || case when t.mode = 'solo' then '1:1' else '팀전' end || ' 비무회가 시작되었습니다. 대진표에서 겨루기를 지켜보세요.', jsonb_build_object('t_id', t.t_id)
        from public.world_characters c;
      perform public.world_tourney_play_round(t.t_id);$n$);

select pg_temp.yh_fix2('public.world_notify_group(text)'::regprocedure,
$o$'tourney_alert', 'tourney_result'$o$, $n$'tourney_alert', 'tourney_start', 'tourney_result'$n$);

select pg_temp.yh_fix2('public.world_wedding_rules()'::regprocedure,
$o$'run_min', 10,$o$, $n$'run_min', 10,
    'rebond_h', 24,$n$);

select pg_temp.yh_fix2('public.world_bond_block_reason(uuid, text)'::regprocedure,
$o$select max(ended_at + case when coalesce((marks ->> 'married')::boolean, false) then interval '4 days' else interval '0' end) into last_end$o$,
$n$select max(ended_at) + make_interval(hours => (public.world_wedding_rules() ->> 'rebond_h')::int) into last_end$n$);

select pg_temp.yh_fix2('public.world_bond_block_reason(uuid, text)'::regprocedure,
$o$if last_end is not null and last_end > now() - interval '3 days' then$o$, $n$if last_end is not null and last_end > now() then$n$);

select pg_temp.yh_fix2('public.world_bond_block_reason(uuid, text)'::regprocedure,
$o$'은(는) 연리가 끝난 지 3일이 지나지 않았습니다(' || to_char((last_end + interval '3 days') at time zone$o$,
$n$'은(는) 연리가 끝난 지 얼마 되지 않았습니다(' || to_char(last_end at time zone$n$);

select pg_temp.yh_fix2('public.world_bond_snapshot()'::regprocedure,
$o$'cooldown_until', case when last_end > now() - interval '3 days' then last_end + interval '3 days' end,$o$,
$n$'cooldown_until', case when last_end + make_interval(hours => (public.world_wedding_rules() ->> 'rebond_h')::int) > now() then last_end + make_interval(hours => (public.world_wedding_rules() ->> 'rebond_h')::int) end,$n$);

update public.world_patch_notes set body = body || '

- 서신함이 가득 차거나 받은 지 3일이 지나 서신이 지워지면 알림이 옵니다. 알림의 「지워진 서신 보기」로 지워진 서신의 글을 다시 읽을 수 있습니다.
- 서신함이 넘칠 때는 읽은 서신부터, 그다음 오래된 서신부터 지웁니다. 아직 읽지 않은 서신이 먼저 지워지지 않습니다.
- 서신함에 지금 몇 통이 있는지, 몇 통을 고정했는지, 가득 차면 어떤 서신이 지워지는지 서신 칸에 적었습니다.
- 비무회가 시작하는 순간 모든 조사원에게 알림이 뜹니다. 알림의 「대진표」로 바로 겨루기를 볼 수 있습니다.
- 연리가 끝난 뒤 새 연리를 맺기까지 기다리는 시간을 하루로 줄였습니다(혼례를 올린 연리도 같습니다).
- 조사원 카드의 내 모습과 꼬마 동무를 위아래가 아니라 나란히 보이게 했습니다.
- 아이폰에서 「내 모습」 머리·옷 고르기 칸이 화면 밖으로 넘치고 「직접 그린 머리」 글이 그림 위에 겹치던 것을 고쳤습니다.
- 비무회 팀전 장면에서 한 팀이 무대 양쪽을 다 차지하고 상대 팀이 구경꾼 줄에 서던 것을 고쳤습니다. 두 팀이 무대 양쪽에 마주 섭니다.
' where note_id = '2.3.0' and body not like '%지워진 서신 보기%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118150000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
