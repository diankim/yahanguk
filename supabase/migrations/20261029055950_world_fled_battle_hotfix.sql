-- 긴급 수정(2026-10-28): 달아나거나 쓰러져 끝난 전투(fled = true, defeated = false)를 몇몇 함수가
-- 「진행 중인 전투」로 보아, 마을에서도 자율 활동(수련 등)을 시작할 수 없었다(문의).
-- 다른 함수들처럼 「not defeated and not fled」로 맞춘다. 동승 요청·동승 후보·파티 화면의 전투 중 표시도 같은 문제라 함께 고친다.
grant fn_owner_19301 to postgres with inherit true, set true;
grant fn_owner_19258 to postgres with inherit true, set true;
grant fn_owner_19259 to postgres with inherit true, set true;
grant fn_owner_19180 to postgres with inherit true, set true;
do $$
declare p record; d text; n int;
begin
  for p in select * from (values
    ('public.world_start_idle_activity(text,integer)', 'where owner_id=public.fn_owner_auth_uid() and not defeated)', 'where owner_id=public.fn_owner_auth_uid() and not defeated and not coalesce(fled,false))'),
    ('public.world_region_explore', 'where owner_id=uid and not defeated)', 'where owner_id=uid and not defeated and not coalesce(fled,false))'),
    ('public.world_ride_candidates', 'e.owner_id=w.owner_id and not e.defeated)', 'e.owner_id=w.owner_id and not e.defeated and not coalesce(e.fled,false))'),
    ('public.world_ride_request', 'e.owner_id in (uid,p_passenger_id) and not e.defeated)', 'e.owner_id in (uid,p_passenger_id) and not e.defeated and not coalesce(e.fled,false))'),
    ('public.world_ride_respond', 'e.owner_id in (q.driver_id,uid) and not e.defeated)', 'e.owner_id in (q.driver_id,uid) and not e.defeated and not coalesce(e.fled,false))'),
    ('public.world_travel_party_snapshot', 'e.owner_id=x.owner_id and not e.defeated)', 'e.owner_id=x.owner_id and not e.defeated and not coalesce(e.fled,false))'),
    ('public.world_party_snapshot', 'e.owner_id=m.owner_id and not e.defeated)', 'e.owner_id=m.owner_id and not e.defeated and not coalesce(e.fled,false))')
  ) v(fn, old, new) loop
    d := pg_get_functiondef(case when p.fn like '%(%' then p.fn::regprocedure::oid else p.fn::regproc::oid end);
    n := (length(d) - length(replace(d, p.old, ''))) / length(p.old);
    if n <> 1 then raise exception '% 고칠 자리가 %곳입니다.', p.fn, n; end if;
    execute replace(d, p.old, p.new);
  end loop;
end $$;
grant fn_owner_19301 to postgres with inherit false, set false;
grant fn_owner_19258 to postgres with inherit false, set false;
grant fn_owner_19259 to postgres with inherit false, set false;
grant fn_owner_19180 to postgres with inherit false, set false;
