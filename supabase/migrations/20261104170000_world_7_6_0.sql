-- 7.6.0 — 7.5.9d·e·g·i·k를 하나로 묶은 배포(사용자 결정 2026-10-31). 패치노트는 7.5.0 본문 맨 아래에 「## 7.6.0」으로 덧붙인다.
lock table public.world_characters in access exclusive mode;

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

-- 7.5.9e — 퀘스트 채집 할 일 문구에서 「(캔 개수)」「(채집 횟수)」를 뺀다(사용자 요청). 단위는 화면(quests.js unitOf)이 수 뒤에 「개」「회」로 붙인다.
do $p$
declare d text; n int; own text; inh boolean;
begin
  d := replace(pg_get_functiondef('public.world_quest_task_label(jsonb)'::regprocedure), E'\r\n', E'\n');
  if position('(캔 개수)' in d) = 0 then return; end if;
  n := (length(d) - length(replace(d, $o$' 모으기(캔 개수)', '채집하기(채집 횟수)'$o$, ''))) / length($o$' 모으기(캔 개수)', '채집하기(채집 횟수)'$o$);
  if n <> 1 then raise exception '7.5.9e label anchor %', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_quest_task_label(jsonb)'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, $o$' 모으기(캔 개수)', '채집하기(채집 횟수)'$o$, $o$' 모으기', '채집하기'$o$);
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;

-- 7.5.9g — 퀘스트 장면 목표(goal) 문구: 물품을 정한 채집은 캔 개수로 세므로 「세 번 채집」을 「세 개 모으기」처럼 고친다(사용자 요청).
-- 토벌·탐색·제작·낚시 횟수(「2번 쓰러뜨린다」 등)는 그대로. 고친 목표는 38줄.
update public.world_quest_steps s set goal = v.g
  from (values
  ('aq_archivebureau', 2, '장서각 지하서고에서 먹정을 2개 거두고 책벌레 요괴를 2번 쓰러뜨린다'),
  ('aq_fieldbureau', 3, '귀죽림에서 약제 바탕과 부적목 수지를 2개씩 거둬 수지를 건넨다'),
  ('aq_medicalbureau', 3, '연화원에서 약제 바탕과 월광 이끼를 2개씩 거둬 약제 바탕을 건넨다'),
  ('jq_analyst', 2, '백지교에서 정제 황지를 3개, 연무장·팔괘진에서 부적목을 3개 거둬 둘씩 건넨다'),
  ('jq_exorcist', 3, '방울먹는 무녀귀를 쓰러뜨리고, 사당에서 부적실을 2개 거둬 방울을 다시 맨다'),
  ('jq_medic', 2, '잿빛 들녘에서 야령초를 4개, 약제 바탕을 2개 거둬 온다'),
  ('jq_sealmaster', 2, '폐쇄 사당에서 황지를 3개 거두고 금줄식귀를 2번 쓰러뜨린다'),
  ('mq_drowned_ledger', 4, '염등촌에서 수귀 비늘을 세 개 모아 노들에게 건넨다'),
  ('mq_frost_seal', 4, '빙혼곡에서 빙정염을 세 개 모아 백무에게 건넨다'),
  ('mq_red_seal', 4, '잿빛 들녘에서 야령초를 세 개 모아 모가람에게 건넨다'),
  ('rq_comet_crater', 2, '혜성 낙하지에서 성진사를 2개 거둔다'),
  ('rq_ember_pass', 2, '불씨 고개에서 숯을 4개 거둔다'),
  ('rq_snow_hollow', 3, '설피골에서 월광 이끼를 3개 거둔다'),
  ('rq_star_hill', 3, '별바라기 언덕에서 운면을 2개 거둔다'),
  ('rq_water_clock', 2, '물시계 터에서 영유리를 2개 거두고 누리에게 생 월철 3개를 건넨다'),
  ('sq_ash_coast_1', 2, '재의 해안에서 수향 갈대 세 개 모으기'),
  ('sq_ash_mountain_1', 2, '생 월철을 네 개, 월철 광석을 두 개 캔다'),
  ('sq_burial_steps_2', 2, '만인장에서 원령재를 네 개 모아 세 줌 건넨다'),
  ('sq_burial_steps_2', 3, '비석 까마귀를 쫓고 황지를 두 개 모은다'),
  ('sq_crimson_mine_2', 2, '주혈 광산에서 월철 광석 세 개, 생 월철 두 개 모으기'),
  ('sq_ember_village_1', 2, '부적목 세 개를 모아 잔불촌으로 돌아오기'),
  ('sq_ember_village_2', 2, '월철 광석 세 개, 생 월철 두 개 모으기'),
  ('sq_hidden_bazaar_2', 2, '만인장에서 요기 결정을 세 개 모은다'),
  ('sq_hq_dorm_1', 2, '잿빛 들녘에서 야령초를 3개 캐 온다'),
  ('sq_hq_training_2', 2, '연무장에서 부적목을 3개 베어 온다'),
  ('sq_lantern_market_1', 2, '잿빛 들녘에서 야령초를 4개 캐 온다'),
  ('sq_lotus_marsh_1', 2, '천엽 연화늪에서 월광 이끼 세 개 모으기'),
  ('sq_mirror_pavilion_1', 2, '수경루에서 귀경 파편 세 개 모으기'),
  ('sq_red_forest_1', 2, '혈엽림에서 영맥 수피와 약제 바탕 두 개씩 모으기'),
  ('sq_salt_village_2', 2, '염등촌에서 농축 약초액 세 개 모으기'),
  ('sq_sealed_abyss_2', 2, '구중 봉연에서 응축 영핵을 세 개 모은다'),
  ('sq_sealed_abyss_2', 3, '구중 봉연을 두 번 살피고 요기 결정을 세 개 모은다'),
  ('sq_sealed_garden_2', 2, '연화원에서 약제 바탕을 2개 캐고 안신탕을 1번 만든다'),
  ('sq_thunder_peak_1', 2, '뇌명봉에서 응축 영핵과 요기 결정을 세 개씩 캐고 영핵 둘을 넘긴다'),
  ('sq_under_root_1', 2, '지맥의 뿌리에서 응축 영핵을 세 개 모은다'),
  ('sq_under_root_1', 3, '뿌리 지네를 물리치고 요기 결정을 세 개 모아 영핵 둘을 건넨다'),
  ('sq_white_tower_1', 2, '백옥 천문탑에서 성진사를 세 개 모은다'),
  ('sq_white_tower_1', 3, '별빛 나비 떼를 쫓고 귀경 파편을 두 개 모아 성진사 둘을 건넨다')
  ) v(q, n, g)
 where s.quest_id = v.q and s.step = v.n and s.goal is distinct from v.g;

-- 7.5.9i — 날씨 「세우(細雨)」(drizzle, 사용자 요청): 장우보다 가늘고 고운 비. 채집 +6%·회복 +5%·침식 −5%·단서 +4%·원거리 −5%,
-- 낚시 입질 +5%p(비·안개·흐림과 같음). 영역마다 날씨 무게를 장우·청명에서 덜어 넣는다(땅 밑·심연에는 없음).
-- 날씨는 영역·12시간 칸마다 무게 누계로 정하므로, 배포한 그 칸의 날씨가 바뀔 수 있다.
insert into public.world_environment_catalog(kind, sort, effects, env_key, env_name, description)
select 'weather', 18, '{"healing_pct":5,"gather_qty_pct":6,"erosion_pct":-5,"clue_bonus_pct":4,"ranged_pct":-5}'::jsonb, 'drizzle', '세우',
       '가랑비가 보슬보슬 내린다. 풀잎이 촉촉해 채집이 잘되고 마음이 가라앉아 침식이 덜하지만, 활시위가 조금 눅눅하다.'
 where not exists (select 1 from public.world_environment_catalog where env_key = 'drizzle');

update public.world_weather_climate c set weights = c.weights || v.w
  from (values
    ('capital',    '{"rain":10,"drizzle":10,"clear":25}'::jsonb),
    ('north',      '{"drizzle":4,"clear":16}'::jsonb),
    ('east',       '{"rain":20,"drizzle":12,"clear":16}'::jsonb),
    ('south',      '{"rain":16,"drizzle":12,"clear":19}'::jsonb),
    ('frontier',   '{"rain":8,"drizzle":6,"clear":18}'::jsonb),
    ('heavenward', '{"rain":6,"drizzle":8,"clear":34}'::jsonb)
  ) v(t, w)
 where c.territory_id = v.t and not (c.weights ? 'drizzle');

do $p$
declare r record; d text; own text; inh boolean;
begin
  for r in select * from (values
      ('public.world_expedition_walk_lines', $a$when 'rain' then '장우'$a$, $b$when 'rain' then '장우' when 'drizzle' then '세우'$b$),
      ('public.world_expedition_walk_lines', $a$p_env := case wk when 'rain' then$a$, $b$p_env := case wk when 'drizzle' then array['가는 빗방울이 잎을 또도독 두드려 발소리가 잘 묻힙니다.', '세우에 흙내가 올라와 숨이 한결 편합니다.'] when 'rain' then$b$),
      ('public.world_fish', $a$wk in ('rain', 'fog', 'cloudy')$a$, $b$wk in ('rain', 'drizzle', 'fog', 'cloudy')$b$)
    ) x(fn, a, b)
  loop
    select p.oid::regprocedure::text into d from pg_proc p where p.oid = (select min(oid) from pg_proc where oid::regprocedure::text like substr(r.fn, 8) || '(%' and pronamespace = 'public'::regnamespace);
    d := replace(pg_get_functiondef(d::regprocedure), E'\r\n', E'\n');
    if position('drizzle' in d) > 0 and position(r.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, replace(r.a, E'\r\n', E'\n'), ''))) / length(r.a) <> 1 then raise exception '7.5.9i anchor % in %', r.a, r.fn; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = (select min(oid) from pg_proc where oid::regprocedure::text like substr(r.fn, 8) || '(%' and pronamespace = 'public'::regnamespace);
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

-- 7.5.9k — 봉연 토벌의 물품·자리 비움(사용자 요청)
-- ① 토벌에서 싸우는 동안(물러남이 아니고 토벌 자리에 있을 때) 가방·퀵슬롯으로 물품을 바로 쓰지 못하게 한다(토벌 행동 간격과 상관없이 체력을 채우던 것).
--    토벌 화면의 「물품」(world_raid_action item)은 yh.raid_item을 켜고 같은 길(world_use_item)을 지나므로 그대로 된다.
-- ② 토벌 자리를 비우면(다른 곳에 있거나 이동·원정 중·전투불능) 물러난 것으로 본다: 요괴가 노리지 않고, 함께 거는 회복·북돋기도 받지 않으며,
--    가방·퀵슬롯도 쓸 수 있다(거점에 가서 쉬고 돌아오기). 참가 기록은 그대로라 돌아오면 다시 합류하지 않고 바로 싸우며(요괴 체력도 다시 늘지 않음),
--    쌓은 기여도대로 정산한다.
create or replace function public.world_raid_here(p_uid uuid, p_region text)
 returns boolean
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
begin
  return exists (select 1 from public.world_characters ch join public.world_map_regions r on r.region_name = ch.location
                  where ch.owner_id = p_uid and r.region_id = p_region and ch.travel_destination is null and ch.downed_at is null and ch.health > 0)
     and not exists (select 1 from public.world_expeditions where owner_id = p_uid and status = 'active');
end $function$;
revoke all on function public.world_raid_here(uuid, text) from public, anon, authenticated;
grant execute on function public.world_raid_here(uuid, text) to fn_owner_field;

do $p$
declare r record; d text; own text; inh boolean; n int;
begin
  for r in select * from (values
      ('public.world_use_item(text)'::regprocedure,
       $a$IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;$a$,
       $b$IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(current_setting('yh.raid_item', true), '') <> '1' AND EXISTS (
       SELECT 1 FROM public.world_raid_members m JOIN public.world_raids rd ON rd.raid_id = m.raid_id
        WHERE m.owner_id = uid AND rd.status = 'fight' AND coalesce(m.out_until, '-infinity'::timestamptz) <= now()
          AND public.world_raid_here(uid, rd.region_id)) THEN
    RAISE EXCEPTION '토벌에서 싸우는 동안에는 가방의 물품을 바로 쓸 수 없습니다. 토벌 화면의 「물품」으로 쓰세요(물러나 있거나 토벌 자리를 비운 동안에는 가방에서도 쓸 수 있습니다).';
  END IF;$b$, 'yh.raid_item', 1),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure,
       $a$    perform public.world_use_item(p_item);$a$,
       $b$    perform set_config('yh.raid_item', '1', true);
    perform public.world_use_item(p_item);
    perform set_config('yh.raid_item', '', true);$b$, 'yh.raid_item', 1),
      -- 요괴의 표적·광역·사슬·함께 거는 효과·「모두 물러남」 판정에서 자리를 비운 사람을 뺀다
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure,
       $a$(x.out_until is null or x.out_until <= now())$a$,
       $b$(x.out_until is null or x.out_until <= now()) and public.world_raid_here(x.owner_id, rd.region_id)$b$, 'world_raid_here(x.owner_id', 10),
      -- 화면: 참가자마다 자리 비움, 나도 자리 비움
      ('public.world_raid_snapshot_core(uuid)'::regprocedure,
       $a$'me', x.owner_id = uid,$a$,
       $b$'me', x.owner_id = uid, 'away', rd.status = 'fight' and not public.world_raid_here(x.owner_id, rd.region_id),$b$, '''away'', rd.status', 1),
      ('public.world_raid_snapshot_core(uuid)'::regprocedure,
       $a$'here', here = rd.region_id,$a$,
       $b$'here', here = rd.region_id, 'away', me.owner_id is not null and rd.status = 'fight' and not public.world_raid_here(uid, rd.region_id),$b$, '''away'', me.owner_id', 1)
    ) x(fn, a, b, mark, cnt)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.mark in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> r.cnt then raise exception '7.5.9k anchor in % (% of %)', r.fn, n, r.cnt; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.6.0
- **봉연의 그림자**가 나타나는 때를 한국 시각 오후 4시~9시 30분 사이로 넓혔습니다(전에는 오후 6시부터). 모임 30분과 토벌 2시간이 자정 전에 끝납니다.
- 퀘스트 채집 할 일 문구를 「야령초 모으기 0/3개」·「채집하기 0/3회」처럼 수 뒤에 단위를 붙여 깔끔하게 바꿨습니다(물품을 정한 제작도 「…개」).
- 지도의 세력 경계선을 바깥 해안선과 같은 굵기로 얇게 줄였습니다.
- PC 현장 퀘스트 칸의 카드를 한 줄에 세 개까지 나란히 놓아 한눈에 더 많이 보입니다.
- 퀘스트 장면 목표 문구 38줄을 「부적목 세 번 채집」 대신 「부적목 세 개 모으기」처럼 고쳤습니다. 물품을 정한 채집은 캔 개수로 셉니다.
- 현장 토벌·세력 창·칭호 유래처럼 팝업을 띄웠다 닫거나 행동 뒤 화면이 다시 그려질 때 보던 자리가 맨 위로 올라가던 것을 고쳤습니다.
- 새 날씨 **세우(細雨)**: 가랑비가 보슬보슬 내립니다. 채집 +6%·회복 +5%·침식 −5%·단서 +4%, 물고기도 잘 뭅니다(활은 −5%). 땅 밑·심연에는 내리지 않고, 잎과 처마에 빗방울이 또도도독 떨어지는 소리가 납니다.
- 누름 소리: 정해진 소리가 없던 단추·칩·링크·접는 칸도 모두 짧고 둥근 「톡」 소리를 내고, 효과음 전체를 배경음악·빗소리에 묻히지 않게 키웠습니다.
- 환경음 다듬기: 물가·안개는 일렁이는 물소리로, 새는 음이 휘는 맑은 노래로, 밤 풀벌레는 「찌르르」 우는 귀뚜라미로 바꿨습니다.
- 봉연 토벌에서 싸우는 동안에는 가방·퀵슬롯으로 회복품을 바로 쓸 수 없습니다(토벌 행동 간격과 상관없이 체력을 채울 수 있던 것). 토벌 화면의 「물품」은 그대로 되고, 체력 1로 물러나 있거나 토벌 자리를 비운 동안에는 가방·퀵슬롯으로도 쓸 수 있습니다.
- 토벌 자리를 비우면(다른 지역·이동 중·원정 중) 물러난 것으로 셉니다. 요괴가 노리지 않고 쌓은 기여도는 그대로라, 물러난 동안 거점에 가서 쉬고 돌아와도 됩니다. 토벌 지역에 돌아오면 「토벌로 돌아가기」 창이 뜨고, 다시 합류하지 않고 바로 싸웁니다(요괴 체력도 다시 늘지 않음). 보상은 끝날 때 쌓은 기여도대로 받습니다.
- 휴대폰 토벌 화면의 전투 기록을 화면 아래까지 늘리고 최근 기록이 맨 위에 오게 했습니다.
- 봉연 토벌 화면 다시 짜기(제보 65·66): 요괴의 말·기운 모으기 줄을 높이가 정해진 칸에 넣어 공격 단추가 위아래로 움직이지 않습니다. 참가자는 세 칸 격자로 보이고(이름을 누르면 협동 기술 대상), PC는 왼쪽에 요괴·행동·전투 기록, 오른쪽에 참가자를 둡니다. 휴대폰은 요괴 띠·내 상태와 단추 넷(공격·방어·물품·기술)·참가자·짧은 기록을 한 화면에 담고, 협동 기술은 「기술」을 눌러 펼칩니다.
- 전투 기록에서 준 피해(금빛 「이름 → 요괴 N 피해」)와 받은 피해(빨강 「요괴 → 이름 −N 맞음」)를 색과 문장으로 가르고, 내 줄은 밑줄로 짚습니다. 기록은 새 줄만 덧붙여 읽던 자리가 튀지 않습니다.
- 토벌 「물품」은 고르는 창으로 뜹니다. 화면이 새로 읽혀도 닫히지 않고, 닫기는 직접 합니다. 체력 1로 물러나면 남은 시간과 할 일(물품·가방·퀵슬롯으로 회복 → 돌아오면 먼저 방어)을 안내합니다.
- PC 상태판의 상태이상을 날씨 칩처럼 작고 둥근 칩(상태판에서 가장 작은 글씨)으로 나란히 보여 자리를 덜 차지합니다.
- 물품 정보의 「얻는 곳」 지역 이름을 누르면 지도에서 그 지역을 짚어 엽니다(제보 66).
- 환경음: 삭풍의 바람을 몇 초마다 일었다 잦아드는 「휘이잉」 소리로 바꾸고, 다른 날씨에 늘 깔리던 바람결은 뺐습니다. 세우는 처마·잎에서 간헐적으로 떨어지는 「똑 · 또독」 소리로 바꾸고 빗소리는 아주 작게 뒤에 깔았으며, 장우는 「촤아」 하는 쇳소리 대신 고르게 적시는 빽빽한 빗소리로 바꾸고 조금 작게 했습니다.
- 설정 › 소리: 알림음 칸 이름을 「알림음」으로 줄이고, 들어 보기는 효과음 견본 단추 줄 끝의 「알림」 단추로 옮겼습니다.
$N$
 where note_id = '7.5.0' and position('## 7.6.0' in body) = 0;

update public.world_app_meta set value = '20261104170000' where key = 'db_version';
