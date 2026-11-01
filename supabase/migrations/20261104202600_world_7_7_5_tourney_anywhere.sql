-- 7.7.5 — 야행 비무회는 개최지에 없어도 나선다(사용자 요청 2026-11-01).
-- 시작 10분 전 출석 확인에서 「개최지에 있는가」를 빼고, 쓰러졌거나 숨진 사람만 불참으로 둔다.
-- 신청은 그대로 안전지대 비무 방에서, 경기 기록은 신청한 사람이면 어디서나 본다(world_tourney_view, 원래 그렇다).
do $p$
declare r record; d text; n int; own text;
begin
  for r in
    select * from (values
      ('public.world_tourney_tick()'::regprocedure,
$A$        -- 출석: 모든 구성원이 개최지에 있고 쓰러지지 않았어야 한다
        update public.world_tourney_entries e set status = 'absent'
         where e.t_id = t.t_id and exists (select 1 from unnest(e.members) u join public.world_characters c on c.owner_id = u
                                            where c.location is distinct from venue or c.downed_at is not null or coalesce(c.is_dead, false));$A$,
$B$        -- 출석(7.7.5): 어디에 있든 나선다. 쓰러졌거나 숨진 구성원이 있으면 불참
        update public.world_tourney_entries e set status = 'absent'
         where e.t_id = t.t_id and exists (select 1 from unnest(e.members) u join public.world_characters c on c.owner_id = u
                                            where c.downed_at is not null or coalesce(c.is_dead, false));$B$),
      ('public.world_tourney_tick()'::regprocedure,
$A$'시작 10분 전에 ' || venue || '에 없어(또는 쓰러져 있어) 이번 비무회에 나서지 못했습니다.'$A$,
$B$'시작 10분 전에 쓰러져 있어 이번 비무회에 나서지 못했습니다.'$B$),
      ('public.world_tourney_tick()'::regprocedure,
$A$'30분 뒤 ' || venue || '에서 비무회가 열립니다. 10분 전까지 개최지에 있어야 합니다.'$A$,
$B$'30분 뒤 ' || venue || '에서 비무회가 열립니다. 어디에 있든 나서지만, 10분 전에 쓰러져 있으면 불참입니다.'$B$),
      ('public.world_tourney_tick()'::regprocedure,
$A$'한 시간 뒤 ' || venue || '에서 비무회가 열립니다. 미리 도착해 작전을 정하세요(정하지 않으면 균형).'$A$,
$B$'한 시간 뒤 ' || venue || '에서 비무회가 열립니다. 작전을 정해 두세요(정하지 않으면 균형).'$B$)
    ) x(fn, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.5 tourney anchor (% of 1): %', n, left(r.a, 60); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
  end loop;
end $p$;

-- 패치노트: 7.7.0 본문 끝에 덧붙임
update public.world_patch_notes set body = body || $N$
## 7.7.5
- **야행 비무회는 개최지에 없어도 나섭니다.** 신청만 해 두면 어디에 있든 대회에 나서고, 시작 10분 전에 쓰러져 있을 때만 불참입니다(신청은 그대로 안전지대 비무 방에서).
- 토벌 화면에서 「약점」·「피할 길」 같은 칩이 붙고 빠질 때 공격·방어 단추가 위아래로 움직이던 것을 고쳤습니다.
- 토벌의 「물품」 창에 물품 설명 대신 안쪽 이름(영문)이 보이던 것을 고쳤습니다.
$N$ where note_id = '7.7.0' and position('## 7.7.5' in body) = 0;

update public.world_app_meta set value = '20261104202600' where key = 'db_version';
