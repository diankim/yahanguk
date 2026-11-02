-- 1.0.0c — 두 사람 가상 플레이에서 나온 것
--  ① 파티 원정 합동 전투: world_cb_aggro(double precision)가 없어 원정 진행·정산·귀환이 모두 실패하던 것(7.7.7n에서 한 곳만 ::numeric이 빠짐)
--  ② 파티 채팅에서 다른 파티원 이름이 비던 것: world_party_chat_snapshot을 security definer로(제 파티 글만 읽는다)
--  ③ 동승 요청을 받는 사람에게 알림(ride_request, 화면 위에 바로 뜨고 그 자리에서 받거나 사양)
lock table public.world_characters in access exclusive mode;

do $p$
declare d text;
begin
  d := replace(pg_get_functiondef('public.world_exp_fight_story(uuid,text,text,jsonb,integer,boolean,integer,integer,jsonb,double precision,double precision,timestamp with time zone,integer,text,text,integer,jsonb)'::regprocedure), E'\r\n', E'\n');
  if position('public.world_cb_aggro(p_pres)' in d) > 0 then
    if (length(d) - length(replace(d, 'public.world_cb_aggro(p_pres)', ''))) / length('public.world_cb_aggro(p_pres)') <> 2 then raise exception '1.0.0c anchor aggro'; end if;
    execute replace(d, 'public.world_cb_aggro(p_pres)', 'public.world_cb_aggro(p_pres::numeric)');
  end if;
end $p$;

alter function public.world_party_chat_snapshot() security definer;
revoke all on function public.world_party_chat_snapshot() from public, anon;
grant execute on function public.world_party_chat_snapshot() to authenticated;

grant insert on public.world_notifications to fn_owner_party_invite_v2;
do $p$
declare d text; a text := $a$  RETURNING request_id INTO rid;
$a$;
begin
  d := replace(pg_get_functiondef('public.world_travel_party_invite_v2(uuid,text)'::regprocedure), E'\r\n', E'\n');
  if position('ride_request' in d) = 0 then
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0c anchor ride'; end if;
    execute replace(d, a, a || $b$
  INSERT INTO public.world_notifications(user_id, kind, title, content, payload)
  VALUES (p_passenger_id, 'ride_request', '동승 요청',
    coalesce((SELECT x.character_name FROM public.world_characters x WHERE x.owner_id = uid), '동료') || '이(가) '
      || coalesce((SELECT r.region_name FROM public.world_map_regions r WHERE r.region_id = p_region_id), '다른 곳') || '(으)로 함께 가자고 합니다.',
    jsonb_build_object('request_id', rid, 'from_id', uid, 'to_region', p_region_id));
$b$);
  end if;
end $p$;
do $p$
declare d text;
begin
  d := replace(pg_get_functiondef('public.world_notify_group(text)'::regprocedure), E'\r\n', E'\n');
  if position('ride_request' in d) = 0 then
    execute replace(d, $a$when p_kind in ('party_invite',$a$, $a$when p_kind in ('ride_request', 'party_invite',$a$);
  end if;
end $p$;

update public.world_app_meta set value = '20261105020000' where key = 'db_version';
