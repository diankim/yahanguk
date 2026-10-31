-- 7.5.9d — 봉연의 그림자 출현 시각을 한국 시각 16:00~21:30으로 넓힌다(사용자 요청: 오후 4시부터, 자정 전에 끝나게).
-- 출현 시각 = 모임 시작, 30분 모임 + 2시간 토벌이므로 21:30이 마지막(24:00 끝). 이미 정해진 회차는 그대로 둔다.
create or replace function public.world_raid_evening(p_base timestamp with time zone)
 returns timestamp with time zone
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare d date := (p_base at time zone 'Asia/Seoul')::date; s timestamptz; e timestamptz; f timestamptz;
begin
  loop
    s := (d + time '16:00') at time zone 'Asia/Seoul'; e := (d + time '21:30') at time zone 'Asia/Seoul';
    if p_base <= e then f := greatest(s, p_base); return f + random() * (e - f); end if;
    d := d + 1;
  end loop;
end $function$;

-- 패치노트 줄은 다음 묶음을 배포할 때 supabase/pending/next_patch_note.md에서 모아 넣는다.
update public.world_app_meta set value = '20261104110000' where key = 'db_version';
