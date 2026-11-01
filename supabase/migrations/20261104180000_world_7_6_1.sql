-- 7.6.1 — 봉연 토벌: 물러난 뒤 「원할 때 돌아오기」(제보 67, 사용자 묶음)
-- 전에는 쓰러져 물러나면 60초 뒤 저절로 싸움에 돌아가, 회복하는 사이에도 광역·표적 공격을 맞아 다시 쓰러지곤 했다.
-- 이제 60초가 지나도 out_until을 남겨 두고(쉬는 중), 그 사람이 직접 행동(공격·방어·물품·협동 기술)하면 world_raid_action이
-- out_until을 비워 돌아간다. 쉬는 동안은 요괴의 표적·광역·사슬·함께 거는 효과·대신 막기·「모두 물러남」 판정에서 빠지고,
-- 가방·퀵슬롯 물품도 쓸 수 있다(world_use_item). 화면에는 snapshot의 resting으로 알린다.
lock table public.world_characters in access exclusive mode;

do $p$
declare r record; d text; own text; inh boolean; n int;
begin
  for r in select * from (values
      -- 표적 등: 「물러남이 끝났으면 다시 셈」 → 「직접 돌아왔을 때만 셈」
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure,
       $a$(x.out_until is null or x.out_until <= now()) and public.world_raid_here$a$,
       $b$x.out_until is null and public.world_raid_here$b$, 'x.out_until is null and public.world_raid_here', 10),
      -- 되살리기(소생)는 쉬는 동료에게도 쓸 수 있다
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure,
       $a$if tm.out_until is null or tm.out_until <= now() then raise exception '물러난 동료에게만 쓸 수 있습니다.'; end if;$a$,
       $b$if tm.out_until is null then raise exception '물러난 동료에게만 쓸 수 있습니다.'; end if;$b$, 'if tm.out_until is null then raise', 1),
      -- 대신 막기: 쉬는 사람은 막아 주지 않는다
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure,
       $a$if found and (pm.out_until is null or pm.out_until <= now()) then$a$,
       $b$if found and pm.out_until is null then$b$, 'if found and pm.out_until is null then', 1),
      ('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure,
       $a$'의 피해를 입고 물러났습니다(1분 뒤 돌아옴).'$a$,
       $b$'의 피해를 입고 물러났습니다(1분 쉰 뒤 행동하면 돌아옴).'$b$, '1분 쉰 뒤 행동하면', 1),
      -- 가방·퀵슬롯: 쉬는 동안에도 쓸 수 있다
      ('public.world_use_item(text)'::regprocedure,
       $a$AND coalesce(m.out_until, '-infinity'::timestamptz) <= now()$a$,
       $b$AND m.out_until IS NULL$b$, 'AND m.out_until IS NULL', 1),
      -- 화면: 쉬는 중(물러남 시간은 끝났고 아직 돌아오지 않음)
      ('public.world_raid_snapshot_core(uuid)'::regprocedure,
       $a$'out', case when x.out_until > now() then ceil(extract(epoch from x.out_until - now())) end,$a$,
       $b$'out', case when x.out_until > now() then ceil(extract(epoch from x.out_until - now())) end, 'resting', x.out_until is not null and x.out_until <= now(),$b$, '''resting'', x.out_until', 1),
      ('public.world_raid_snapshot_core(uuid)'::regprocedure,
       $a$'out', case when me.out_until > now() then ceil(extract(epoch from me.out_until - now())) end,$a$,
       $b$'out', case when me.out_until > now() then ceil(extract(epoch from me.out_until - now())) end, 'resting', me.out_until is not null and me.out_until <= now(),$b$, '''resting'', me.out_until', 1)
    ) x(fn, a, b, mark, cnt)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.mark in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> r.cnt then raise exception '7.6.1 anchor in % (% of %)', r.fn, n, r.cnt; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

-- 묶음 크기(사용자 결정 2026-10-31, 제보 67·68): 장비·가구(1)와 탄(100)은 그대로,
-- 고급 소모품(진품 이상 — 전에 한 칸 3·5개였던 대환단·회춘단·천령 감로·영기환·바다 요리 등)은 20개, 나머지 2~39개짜리는 모두 40개.
-- 우수품(_hq)도 같은 줄에 걸려 함께 바뀐다(trg_world_item_hq_sync는 기본 물품을 따라 맞추므로 결과가 같다).
update public.world_item_catalog
   set stack_size = case when category = 'consumable' and stack_size <= 5 then 20 else 40 end
 where stack_size between 2 and 39;

update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.6.1
- 봉연 토벌: 쓰러져 물러난 뒤 1분이 지나도 **저절로 싸움에 돌아가지 않습니다**(제보 67). 회복하는 사이 광역·표적 공격을 맞아 다시 쓰러지던 것을 막았습니다. 쉬는 동안은 요괴가 노리지 않고 가방·퀵슬롯도 쓸 수 있으며, 준비가 되면 공격·방어·기술을 눌러 돌아갑니다(돌아가면 먼저 방어가 안전합니다).
- 토벌 화면: 내 체력·영력(기력)을 막대와 큰 숫자로 단추 바로 위에 보이고, 내가 준 피해 합과 기여도도 함께 적습니다. 「물품」 창은 체력·정신 회복과 영력(기력) 회복을 나눠 보입니다.
- 휴대폰 채팅·귓속말에서 보내기를 누르면 키패드가 내려가던 것을 다시 고쳤습니다. 이제 손가락을 떼는 순간 입력칸에서 초점이 빠지지 않습니다.
- 가방·창고 **묶음 크기**를 늘렸습니다: 재료·소모품·임무 물품은 한 칸에 40개, 대환단·회춘단·천령 감로·바다 요리 같은 고급 소모품은 20개까지 쌓입니다(장비·가구 1개, 화살 등은 100개 그대로).
- 색 고르기(설정 › 테마 직접 설정·모임 채팅 색): 휴대폰의 기본 색 선택 창 대신 게임 안 창이 뜹니다. 사각형 판에서 채도·밝기를, 막대에서 색조를 고르고, Hex 코드(#2f6f8f처럼)를 바로 적을 수도 있습니다. 어울리는 추천색 24가지를 새로 골랐고, 다시 열면 지금 쓰는 색에서 시작합니다.
- 퀘스트 카드: 할 일이 다른 곳에 남아 있는데도 「보고: 잔불촌 (지금 여기)」만 보여 그곳에서 끝내는 것처럼 읽히던 것을 고쳤습니다. 이제 남은 할 일의 장소를 「할 곳: 주혈 광산」으로 먼저 적고, 보고 장소는 「다 하면 보고: 잔불촌」으로 적습니다.
- 화면 점검으로 찾은 자잘한 것들: 휴대폰 상태 띠를 펼친 채 아래 탭을 누르면 띠가 새 화면을 덮던 것, 글 줄 안의 아이콘이 따로 한 줄을 차지하던 것(제작 창고 안내·도감 파훼법), 상점·대장간 아래 「구매하기」 칸 밑으로 목록이 비치던 것, 원정 기록의 「자세히」가 두 줄로 쪼개지던 것, 제작법 재료 수가 가운데로 밀리던 것, 물품 창고 맡기기 칸 글이 쪼개지던 것, 현장 「의뢰 게시판」이 주 이야기를 열던 것(이제 의뢰 칸), 퀘스트 「넘기기」에 「개」가 빠졌던 것, 토벌 예고 화면의 빈 지역 이름·참가자 없음 줄, 기운 모으기 줄이 잘리던 것(「끊기까지 N」으로 줄임), 휴대폰 토벌 기록이 채팅 단추에 가리던 것을 고쳤습니다.
- 가방 › 제작에서 분야·만드는 것 체크박스나 정렬을 바꾸면 목록이 줄면서 화면이 아래로 끌려 내려가던 것을 고쳤습니다. 이제 누른 칸이 화면의 같은 자리에 남고, 목록이 짧아져도 그 아래로 빈 화면이 길게 이어지지 않습니다.
$N$
 where note_id = '7.5.0' and position('## 7.6.1' in body) = 0;

update public.world_app_meta set value = '20261104180000' where key = 'db_version';
