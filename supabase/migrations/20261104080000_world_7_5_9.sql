-- 7.5.9 — 화면 묶음의 패치노트(7.5.0 본문 맨 아래에 덧붙임). 10개가 모이면 배포한다(2026-10-31 결정).
-- 채집 도감에 세부 채집터(7.5.9, 사용자 요청): 거둔 재료마다 지역별로 그 재료가 나오는 채집터 이름·출입 레벨과 내가 찾았는지(f)를 spots로 더한다.
do $p$
declare d text; a text; n int; own text; inh boolean;
begin
  d := replace(pg_get_functiondef('public.world_gather_codex_snapshot()'::regprocedure), E'\r\n', E'\n');
  if position('''spots''' in d) > 0 then return; end if;
  a := $o$'regions', it.regions,$o$;
  n := (length(d) - length(replace(d, a, ''))) / length(a);
  if n <> 1 then raise exception '7.5.9 gather codex anchor %', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_gather_codex_snapshot()'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, a, a || $n$
            'spots', (select jsonb_agg(jsonb_build_object('r', rr.n, 'l', rr.l, 'c', rr.c, 'fc', rr.fc, 's', rr.s) order by rr.l, rr.n) from (
              -- 지역마다 채집터 수(c)·찾은 수(fc)와 이름 넷(찾은 곳 먼저, 그다음 출입 레벨이 낮은 곳)만 — 흔한 재료는 한 지역에 20곳이 넘어 다 내보내면 무겁다
              select q.n, min(q.l) as l, count(*) as c, count(*) filter (where q.f) as fc,
                jsonb_path_query_array(jsonb_agg(jsonb_build_object('n', q.sn, 'lv', q.lv, 'f', q.f) order by q.f desc, q.lv, q.sn), '$[0 to 3]') as s
                from (select r2.region_name as n, coalesce(r2.min_level, 1) as l, s2.spot_name as sn, s2.min_level as lv,
                        exists (select 1 from public.world_gathering_discoveries d2 where d2.owner_id = uid and d2.spot_id = s2.spot_id) as f
                        from public.world_gathering_spots s2 join public.world_exploration_nodes n2 on n2.node_id = s2.node_id
                        join public.world_map_regions r2 on r2.region_id = n2.region_id
                       where s2.active and it.item_id = any (s2.loot_items)) q
               group by q.n order by 2, 1 limit 8) rr),$n$);
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;

update public.world_patch_notes set body = body || $N$

## 7.5.9
- 가방에서 같은 물품을 **묶음 크기만큼 한 칸씩 나눠** 보입니다. 청심환 45개라면 20·20·5 세 줄로 보여, 몇 칸을 차지하는지 따로 셈하지 않아도 됩니다(강산하 님 제보). 장착 중인 하나는 칸을 쓰지 않으므로 따로 한 줄로 보입니다. 정렬 옆 「칸대로 나눠 보기」를 끄면 예전처럼 한 줄에 모아 보입니다.
- 휴대폰 칭호 화면: 두 칸 카드에 설명·조건·효과를 누르지 않아도 모두 적고, 단추를 작게 줄였습니다. **대표 칭호** 단추는 카드 오른쪽 위로 옮겼습니다(PC도 같음). 아직 얻지 못한 칭호의 진행 게이지는 흐려지지 않고 또렷하게 보입니다.
- 퀘스트의 **채집 할 일·넘길 물품**에 그 물품이 나오는 지역을 5곳까지 바로 가기로 붙였습니다(지역이 정해진 할 일은 그 지역 그대로). 누르면 지도에서 그 지역을 크게 보여 줍니다.
- 토벌 중 **화살(탄)·기력·영력이 떨어져** 공격 피해가 절반이 되면 화면 아래에 「화살(탄)이 없습니다 · 피해가 절반으로 줄었습니다」처럼 알림을 띄웁니다(같은 알림은 5초에 한 번, 파티 토벌에서도 내 공격이면 같은 알림). 전에는 전투 기록 한 줄로만 지나가 알아채기 어려웠습니다.
- 장비 수리에서 **우수 수리 도구**만 가지고 있으면 「수리 도구」 단추가 잠겨 있던 것을 고쳤습니다(강산하 님 제보). 서버는 처음부터 받고 있었고 화면이 보통 수리 도구만 셌습니다.
- **채집 도감**: 거둔 재료마다 지역별로 그 재료가 나오는 **세부 채집터**(지역마다 채집터 수·찾은 수와 이름 넷 — 찾은 곳 먼저)를 적습니다. 찾은 채집터는 표시합니다.
$N$
 where note_id = '7.5.0' and position('## 7.5.9' in body) = 0;

update public.world_app_meta set value = '20261104080000' where key = 'db_version';
