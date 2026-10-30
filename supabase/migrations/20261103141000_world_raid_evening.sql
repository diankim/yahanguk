-- 봉연의 그림자는 실시간으로 함께 싸우는 토벌이라 저녁에만 드러나게 한다(사용자 요청 2026-10-30).
--   72시간(배포 직후 첫 회는 30시간) 뒤를 기준으로, 그날(또는 다음 날) 한국 시각 18:00~21:30 사이 어느 때에 드러난다.
--   드러난 뒤 30분 모이고 2시간 토벌하므로 늦어도 자정 전에 끝난다.
--   이미 잡혀 있던 회차(10/31 03:13 서문 폐성벽)는 같은 날 저녁 20:00으로 옮기고, 출현지 확정 알림을 그 시각으로 다시 보낸다.

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;

-- 기준 시각 뒤의 첫 저녁 창(18:00~21:30 KST) 안의 아무 때
create or replace function public.world_raid_evening(p_base timestamptz) returns timestamptz
language plpgsql volatile security definer set search_path = '' as $$
declare d date := (p_base at time zone 'Asia/Seoul')::date; s timestamptz; e timestamptz; f timestamptz;
begin
  loop
    s := (d + time '18:00') at time zone 'Asia/Seoul'; e := (d + time '21:30') at time zone 'Asia/Seoul';
    if p_base <= e then f := greatest(s, p_base); return f + random() * (e - f); end if;
    d := d + 1;
  end loop;
end $$;
revoke all on function public.world_raid_evening(timestamptz) from public, anon, authenticated;
grant execute on function public.world_raid_evening(timestamptz) to fn_owner_field; -- 예약 함수(world_raid_schedule_next) 주인이 부른다

select pg_temp.yh_patch('public.world_raid_schedule_next()',
  'at := now() + case when cnt = 0 then interval ''30 hours'' + random() * interval ''12 hours'' else interval ''72 hours'' + random() * interval ''24 hours'' end;',
  'at := public.world_raid_evening(now() + case when cnt = 0 then interval ''30 hours'' else interval ''72 hours'' end); -- 저녁 18:00~21:30(KST)에만');

-- 잡혀 있던 회차 옮기기(저녁 창 밖이면 그날 20:00, 이미 지난 날이면 건드리지 않음)
do $$ declare r public.world_raids%rowtype; t timestamptz; reg text; begin
  for r in select * from public.world_raids where kind = 'world' and status = 'announced' and not (fx ? 'last_night') loop
    if (r.spawn_at at time zone 'Asia/Seoul')::time between time '18:00' and time '21:30' then continue; end if;
    t := ((r.spawn_at at time zone 'Asia/Seoul')::date + time '20:00') at time zone 'Asia/Seoul';
    if t <= now() + interval '1 hour' then t := t + interval '1 day'; end if;
    update public.world_raids set spawn_at = t, notices = array['24h'], updated_at = now() where raid_id = r.raid_id;
    select region_name into reg from public.world_map_regions where region_id = r.region_id;
    perform public.world_raid_broadcast(r.raid_id, '봉연 · 출현 시각 변경', '봉연의 그림자가 늦은 밤이 아닌 저녁에 드러납니다. ' ||
      to_char(t at time zone 'Asia/Seoul', 'MM"월" DD"일" HH24"시" MI"분"') || '쯤 ' || reg || '에 봉연의 그림자가 드러납니다.');
  end loop;
end $$;
