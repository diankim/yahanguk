-- 1.0.0b — 다시 열기 전 정리(2026-11-03 10:00 KST 전)
--  ① 버팀 기세 설명 +35% → +20%(실제 ×1.20)  ② 귀허·봉연 「보호막」 기록 줄 지움(보호막 주는 기술 없음)
--  ③ 한설 소개의 옛 직업 이름처럼 읽히는 말  ④ 직업 전용 제작법·도구 모두 없앰(전투만 직업 역할, 사용자 결정)
--  ⑤ 안 쓰는 옛 함수 지움  ⑥ 겹치는 함수 합침  ⑦ 칭호 규칙 셈을 n에서 멈춤·시간대는 기록에 남은 값
--  ⑧ world_skill_has·world_skill_line_ok를 인라인되는 SQL로  ⑨ 채팅 created_at 색인
--  Ⓐ 운영진 캐릭터에 「야행국 운영진」 칭호 저절로  Ⓑ 채집·제작·낚시 결과 말투 합쇼체로  Ⓒ 쉬기 결과 근접 무기면 「기력」
lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.rep(d text, a text, b text, n int default 1) returns text language plpgsql as $r$
declare k int := (length(d) - length(replace(d, a, ''))) / length(a);
begin
  if k <> n then raise exception '1.0.0b anchor (% / %): %', k, n, left(a, 90); end if;
  return replace(d, a, b);
end $r$;
create or replace function pg_temp.fdef(p_name text) returns text language plpgsql as $r$
declare d text; k int;
begin
  select count(*), max(replace(pg_get_functiondef(oid), E'\r\n', E'\n')) into k, d from pg_proc where proname = p_name and pronamespace = 'public'::regnamespace;
  if k <> 1 then raise exception '1.0.0b function % (%)', p_name, k; end if;
  return d;
end $r$;
-- 함수 실행 권한을 다른 함수와 똑같이(새 도우미용)
create or replace function pg_temp.copy_acl(p_from regprocedure, p_to regprocedure) returns void language plpgsql as $r$
declare g text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_to);
  for g in select distinct a.grantee::regrole::text from pg_proc p, aclexplode(p.proacl) a where p.oid = p_from and a.privilege_type = 'EXECUTE' and a.grantee <> 0 loop
    execute format('grant execute on function %s to %s', p_to, g);
  end loop;
end $r$;

-- ── ① 버팀 기세 ─────────────────────────────────────────────────────
update public.world_skill_catalog set description = replace(description, '다음 공격 피해 +35%', '다음 공격 피해 +20%')
 where skill_id = 'melee_g24' and description like '%다음 공격 피해 +35%%';

-- ── ② 보호막 기록 줄(보호막을 거는 협동 기술이 없어 나오지 않음) ─────────────
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_gw_hit');
  if position('방호 법구가' in d) > 0 then
    execute pg_temp.rep(d, $a$  if (r ->> 'absorb')::int > 0 then perform public.world_gw_say(p_fight, p_round, 'good', m.name || ' — 방호 법구가 ' || (r ->> 'absorb') || '을(를) 먼저 받아 냈습니다.'); end if;
$a$, '');
  end if;
  d := pg_temp.fdef('world_raid_hit');
  if position('보호막이 ' in d) > 0 then
    execute pg_temp.rep(d, $a$ || case when absorb > 0 then '(보호막이 ' || absorb || ' 받아 냄)' else '' end$a$, '');
  end if;
end $p$;

-- ── ③ 한설 소개 ──────────────────────────────────────────────────────
update public.world_faction_npcs set detail = replace(detail, '원래 현장 조사원이었으나', '원래 현장을 뛰던 조사원이었으나')
 where npc_key = 'night_office:han' and detail like '%원래 현장 조사원이었으나%';

-- ── ④ 직업 전용 제작·채집 없앰 ─────────────────────────────────────────
-- 제작법 13(호위 무사 6·의무관 3·봉인술사 4)과 영맥 낫(월궁 사수, 보통·우수). 무기의 직업 태그(equipment_traits.jobs)는 그대로.
update public.world_crafting_recipes set required_job = null where required_job is not null;
update public.world_item_catalog set required_job = null where required_job is not null and category <> 'weapon';
-- 봉인술사만 받던 봉인 공예 품질 +5(부적 정련 3단계) 없앰 — 봉인술 계열은 봉인술사만 오르므로 직업 전용과 같았다
update public.world_skill_catalog set description = '봉인 피해 +8%.', passive_effect = passive_effect - 'craft_quality'
 where skill_id = 'sealing_script' and passive_effect ? 'craft_quality';
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_craft_item');
  if position($a$c.job_key = 'sealmaster'$a$ in d) > 0 then
    execute pg_temp.rep(d, $a$    + case when line = 'wardcraft' and c.job_key = 'sealmaster' and coalesce((c.skill_progress -> 'sealing' ->> 'rank')::int, 0) >= 3 then 5 else 0 end
$a$, '');
  end if;
end $p$;

-- ── ⑤ 안 쓰는 옛 함수(화면·다른 함수·트리거·예약 작업·정책 어디서도 안 부름) ─────────
drop function if exists public.world_allocate_stat(text);        -- → world_allocate_stats
drop function if exists public.world_craft_line(text);           -- → world_craft_line_of
drop function if exists public.world_housing_item(text, text);
drop function if exists public.world_letter_unread();
drop function if exists public.world_status_snapshot();          -- → world_hud_snapshot·world_field_status
drop function if exists public.world_wedding_here();
drop function if exists public.world_stat_cap(integer);          -- → world_stat_cap_of

-- ── ⑥ 겹치는 함수 합침 ────────────────────────────────────────────────
-- 가방 칸: world_inv_count = world_bag_count(같은 본문). 부르던 곳을 바꾸고 지운다.
do $p$
declare d text;
begin
  if exists (select 1 from pg_proc where proname = 'world_inv_count' and pronamespace = 'public'::regnamespace) then
    d := pg_temp.fdef('world_trade_direct_respond');
    if position('public.world_inv_count(' in d) > 0 then
      execute pg_temp.rep(d, 'public.world_inv_count(', 'public.world_bag_count(', 4);
    end if;
    if exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace and prosrc ~ '\mworld_inv_count\M' and proname <> 'world_inv_count') then
      raise exception '1.0.0b world_inv_count 아직 부르는 곳이 있음';
    end if;
    drop function public.world_inv_count(jsonb);
  end if;
end $p$;

-- 얻는 곳: world_item_sources는 world_item_sources_all을 갈래마다 6곳까지 자른 것
create or replace function public.world_item_sources(p_item text)
 returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
  select s || jsonb_build_object(
    'gather',   (select coalesce(jsonb_agg(v order by o), '[]') from jsonb_array_elements(s -> 'gather') with ordinality a(v, o) where o <= 6),
    'sites',    (select coalesce(jsonb_agg(v order by o), '[]') from jsonb_array_elements(s -> 'sites') with ordinality a(v, o) where o <= 6),
    'monsters', (select coalesce(jsonb_agg(v order by o), '[]') from jsonb_array_elements(s -> 'monsters') with ordinality a(v, o) where o <= 6),
    'fish',     (select coalesce(jsonb_agg(v order by o), '[]') from jsonb_array_elements(s -> 'fish') with ordinality a(v, o) where o <= 6))
  from (select public.world_item_sources_all(p_item) s) x
$f$;
grant execute on function public.world_item_sources_all(text) to fn_owner_field;

-- 칭호 효과: world_title_bonus(키) = world_title_bonus_of(지금 조사원, 키), 인라인되는 SQL
create or replace function public.world_title_bonus(p_effect_key text)
 returns numeric language sql stable
as $f$
  select public.world_title_bonus_of(public.fn_owner_auth_uid(), p_effect_key)
$f$;

-- 완전 답사: 지역 목록 하나(world_survey_full_list)를 목록·수가 함께 쓴다
create or replace function public.world_survey_full_list(p_owner uuid)
 returns jsonb language plpgsql stable set search_path to 'pg_catalog', 'public'
as $f$
begin
  if p_owner is null then return '[]'::jsonb; end if;
  return coalesce((with dr as materialized (
           select x.region_id from public.world_exploration_discoveries d join public.world_exploration_nodes x on x.node_id = d.node_id where d.owner_id = p_owner
           union select y.region_id from public.world_gathering_discoveries d join public.world_gathering_spots g on g.spot_id = d.spot_id join public.world_exploration_nodes y on y.node_id = g.node_id where d.owner_id = p_owner),
       n as (select x.region_id, count(*) t, count(d.node_id) f from public.world_exploration_nodes x
               left join public.world_exploration_discoveries d on d.node_id = x.node_id and d.owner_id = p_owner
              where x.hierarchy_level >= 2 and x.region_id in (select region_id from dr) group by 1),
       s as (select y.region_id, count(*) t, count(d.spot_id) f from public.world_gathering_spots x
               join public.world_exploration_nodes y on y.node_id = x.node_id
               left join public.world_gathering_discoveries d on d.spot_id = x.spot_id and d.owner_id = p_owner
              where x.active and y.region_id in (select region_id from dr) group by 1)
  select jsonb_agg(r.region_id order by r.region_id) from public.world_map_regions r
    left join n on n.region_id = r.region_id left join s on s.region_id = r.region_id
   where r.active and not coalesce(r.is_safe_zone, false) and r.region_id in (select region_id from dr)
     and coalesce(n.t, 0) + coalesce(s.t, 0) > 0
     and coalesce(n.f, 0) + coalesce(s.f, 0) >= coalesce(n.t, 0) + coalesce(s.t, 0)), '[]'::jsonb);
end $f$;
select pg_temp.copy_acl('public.world_survey_full_count(uuid)', 'public.world_survey_full_list(uuid)');
grant execute on function public.world_survey_full_list(uuid) to postgres;
create or replace function public.world_survey_full_regions()
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return public.world_survey_full_list(auth.uid());
end $f$;
create or replace function public.world_survey_full_count(p_owner uuid)
 returns integer language plpgsql stable set search_path to 'pg_catalog', 'public'
as $f$
begin
  return jsonb_array_length(public.world_survey_full_list(p_owner));
end $f$;

-- ── ⑦ 칭호 규칙: n개에서 멈춤, 시간대는 기록 때 남긴 env_phase(없으면 계산) ─────────
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_title_rule_ok');
  if position('env_phase' in d) = 0 then
    d := pg_temp.rep(d, $a$    SELECT count(*) INTO v FROM public.world_events e
    WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> 'ev'$a$, $a$    SELECT count(*) INTO v FROM (SELECT 1 FROM public.world_events e
    WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> 'ev'$a$);
    d := pg_temp.rep(d, $a$      AND (NOT p_rule ? 'phase' OR public.world_time_phase(e.created_at) = p_rule ->> 'phase')$a$,
      $a$      AND (NOT p_rule ? 'phase' OR coalesce(e.payload ->> 'env_phase', public.world_time_phase(e.created_at)) = p_rule ->> 'phase')$a$);
    d := pg_temp.rep(d, $a$(e.payload ->> g.key)::numeric >= g.value::numeric)));
    RETURN v >= n;$a$, $a$(e.payload ->> g.key)::numeric >= g.value::numeric)))
      LIMIT greatest(1, ceil(n))::bigint) x;
    RETURN v >= n;$a$);
    d := pg_temp.rep(d, $a$    SELECT count(DISTINCT e.payload ->> (p_rule ->> 'key')) INTO v FROM public.world_events e
    WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> 'distinct' AND e.payload ? (p_rule ->> 'key') AND (NOT p_rule ? 'has' OR e.payload ? (p_rule ->> 'has'));$a$,
      $a$    SELECT count(*) INTO v FROM (SELECT DISTINCT e.payload ->> (p_rule ->> 'key') FROM public.world_events e
    WHERE e.actor_id = p_owner AND e.event_type = p_rule ->> 'distinct' AND e.payload ? (p_rule ->> 'key') AND e.payload ->> (p_rule ->> 'key') IS NOT NULL
      AND (NOT p_rule ? 'has' OR e.payload ? (p_rule ->> 'has')) LIMIT greatest(1, ceil(n))::bigint) x;$a$);
    execute d;
  end if;
  -- 진행 게이지도 같은 식(못 얻은 칭호만 보이므로 n에서 멈춰도 같다)
  d := pg_temp.fdef('world_title_rule_progress');
  if position('env_phase' in d) = 0 then
    d := pg_temp.rep(d, $a$    select count(*) into v from public.world_events e
     where e.actor_id = p_owner and e.event_type = p_rule ->> 'ev'$a$, $a$    select count(*) into v from (select 1 from public.world_events e
     where e.actor_id = p_owner and e.event_type = p_rule ->> 'ev'$a$);
    d := pg_temp.rep(d, $a$       and (not p_rule ? 'phase' or public.world_time_phase(e.created_at) = p_rule ->> 'phase')$a$,
      $a$       and (not p_rule ? 'phase' or coalesce(e.payload ->> 'env_phase', public.world_time_phase(e.created_at)) = p_rule ->> 'phase')$a$);
    d := pg_temp.rep(d, $a$(e.payload ->> g.key)::numeric >= g.value::numeric)));
  elsif p_rule ? 'distinct' then$a$, $a$(e.payload ->> g.key)::numeric >= g.value::numeric)))
       limit greatest(1, ceil(n))::bigint) x;
  elsif p_rule ? 'distinct' then$a$);
    d := pg_temp.rep(d, $a$    select count(distinct e.payload ->> (p_rule ->> 'key')) into v from public.world_events e
     where e.actor_id = p_owner and e.event_type = p_rule ->> 'distinct' and e.payload ? (p_rule ->> 'key') and (not p_rule ? 'has' or e.payload ? (p_rule ->> 'has'));$a$,
      $a$    select count(*) into v from (select distinct e.payload ->> (p_rule ->> 'key') from public.world_events e
     where e.actor_id = p_owner and e.event_type = p_rule ->> 'distinct' and e.payload ? (p_rule ->> 'key') and e.payload ->> (p_rule ->> 'key') is not null
       and (not p_rule ? 'has' or e.payload ? (p_rule ->> 'has')) limit greatest(1, ceil(n))::bigint) x;$a$);
    execute d;
  end if;
end $p$;

-- ── ⑧ 기술 보유 판정을 인라인되는 SQL로(행동 한 번에 수백 번 불림) ───────────────
-- 조합 기술만 두 계열을 훑는 도우미로(하위 질의가 있으면 인라인이 안 됨)
create or replace function public.world_skill_combo_ok(p_prog jsonb, p_req jsonb)
 returns boolean language sql immutable
as $f$
  select coalesce((select bool_and(coalesce((p_prog -> r.k ->> 'rank')::int, 1) >= r.v::int) from jsonb_each_text(coalesce(p_req, '{}'::jsonb)) r(k, v)), false)
$f$;
-- world_skill_snapshot(invoker)이 authenticated로 부르므로 world_skill_has와 같은 권한
select pg_temp.copy_acl('public.world_skill_has(jsonb,jsonb,text,integer,text,jsonb)', 'public.world_skill_combo_ok(jsonb,jsonb)');
create or replace function public.world_skill_has(p_prog jsonb, p_picks jsonb, p_cat text, p_unlock integer, p_slot text, p_req jsonb)
 returns boolean language sql immutable
as $f$
  select case
    when p_cat = 'combo' then public.world_skill_combo_ok(p_prog, p_req)
    when p_slot in ('a', 'b') then coalesce((p_prog -> p_cat ->> 'rank')::int, 1) >= p_unlock and coalesce(p_picks ->> (p_cat || ':' || p_unlock::text), '') = p_slot  -- ::text(text || int는 stable이라 인라인이 막힘)
    else coalesce((p_prog -> p_cat ->> 'rank')::int, 1) >= p_unlock end
$f$;
create or replace function public.world_skill_line_ok(p_cat text, p_req jsonb, p_job text)
 returns boolean language sql immutable
as $f$
  -- 지금 직업의 계열이 아닌 전투 계열 기술(환골탈태 서첩으로 직업을 바꾼 뒤 남은 것)과 그 계열이 드는 조합 기술은 효과가 없다
  select case when p_job is null then true
    when p_cat in ('melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine') then p_cat = coalesce(public.world_job_line(p_job), p_cat)
    when p_cat = 'combo' then not ((coalesce(p_req, '{}'::jsonb) - coalesce(public.world_job_line(p_job), ''))
      ?| array['melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine'])
    else true end
$f$;

-- ── ⑨ 채팅 created_at 색인(정리·여러 갈래 최근 읽기) ─────────────────────────
create index if not exists world_chat_messages_created_idx on public.world_chat_messages (created_at desc);

-- ── Ⓐ 운영진 칭호: 캐릭터를 만들거나 명단에 오르면 저절로 ──────────────────────
create or replace function public.trg_world_staff_title()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  insert into public.world_character_titles (owner_id, title_key)
  select new.owner_id, 'gm_staff'
   where exists (select 1 from public.world_staff s where s.owner_id = new.owner_id)
     and exists (select 1 from public.world_characters c where c.owner_id = new.owner_id)
     and exists (select 1 from public.world_title_catalog t where t.title_key = 'gm_staff')
  on conflict do nothing;
  return null;
end $f$;
revoke all on function public.trg_world_staff_title() from public, anon, authenticated;
drop trigger if exists trg_world_staff_title on public.world_characters;
create trigger trg_world_staff_title after insert on public.world_characters for each row execute function public.trg_world_staff_title();
drop trigger if exists trg_world_staff_title on public.world_staff;
create trigger trg_world_staff_title after insert on public.world_staff for each row execute function public.trg_world_staff_title();
insert into public.world_character_titles (owner_id, title_key)
select s.owner_id, 'gm_staff' from public.world_staff s join public.world_characters c on c.owner_id = s.owner_id
 where exists (select 1 from public.world_title_catalog t where t.title_key = 'gm_staff')
on conflict do nothing;

-- ── Ⓑ 채집 결과 말투(「…얻었습니다. … 쓰지 않았다.」 섞임) ──────────────────────
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_field_gather');
  if position('쓰지 않았다' in d) > 0 then
    d := pg_temp.rep(d, '탐색력을 쓰지 않았다', '탐색력을 쓰지 않았습니다', 2);
    d := pg_temp.rep(d, '두 번 거뒀다', '두 번 거뒀습니다');
    d := pg_temp.rep(d, '세 배로 거뒀다', '세 배로 거뒀습니다');
    d := pg_temp.rep(d, '두 번 캤다', '두 번 캤습니다');
    d := pg_temp.rep(d, '다섯 배로 캤다', '다섯 배로 캤습니다');
    execute d;
  end if;
  -- 제작·낚시 결과의 덧붙는 말도 같은 까닭으로
  d := pg_temp.fdef('world_craft_item');
  if position('하나도 쓰지 않았다' in d) > 0 then
    d := pg_temp.rep(d, '재료를 하나도 쓰지 않았다', '재료를 하나도 쓰지 않았습니다');
    d := pg_temp.rep(d, '을(를) 아꼈다', '을(를) 아꼈습니다');
    d := pg_temp.rep(d, '25% 더 만들었다', '25% 더 만들었습니다', 2);
    d := pg_temp.rep(d, ' 하나를 돌려받았다', ' 하나를 돌려받았습니다', 2);
    execute d;
  end if;
  d := pg_temp.fdef('world_fish');
  if position('탐색력을 쓰지 않았다' in d) > 0 then
    d := pg_temp.rep(d, '탐색력을 쓰지 않았다', '탐색력을 쓰지 않았습니다');
    d := pg_temp.rep(d, '탐색력을 돌려받았다', '탐색력을 돌려받았습니다');
    d := pg_temp.rep(d, '하나 더 낚았다', '하나 더 낚았습니다');
    execute d;
  end if;
end $p$;

-- ── Ⓒ 쉬기 결과: 근접 무기(또는 무기 없음)면 「기력」(화면 core.js spOf와 같게) ──────────
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_field_rest');
  if position('· 영력 +%s ·' in d) > 0 then
    d := pg_temp.rep(d, $a$  gain := format('체력 +%s · 정신 +%s · 영력 +%s · 침식 -%s · 탐색력 +%s', hp, mn, sp, er, stg)$a$,
      $a$  gain := format('체력 +%s · 정신 +%s · %s +%s · 침식 -%s · 탐색력 +%s', hp, mn,
    case when coalesce((select i.equipment_traits ->> 'weapon_type' from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
                         where e.owner_id = uid and e.slot = 'weapon' limit 1), 'melee') = 'melee' then '기력' else '영력' end, sp, er, stg)$a$);
    execute d;
  end if;
end $p$;

-- ── 1.0.0 패치노트 본문 ─────────────────────────────────────────────
update public.world_patch_notes set body = replace(body,
  '암영 검객의 생활 효과(채집량·희귀품·제작 품질·강화 확률·다른 직업 전용 제작법·원정 현장 가공)는 없어졌고, 채집·제작은 직업과 상관없이 누구나 같은 조건입니다.',
  '암영 검객의 생활 효과(채집량·희귀품·제작 품질·강화 확률·다른 직업 전용 제작법·원정 현장 가공)는 없어졌고, 채집·제작은 직업과 상관없이 누구나 같은 조건입니다.'
  || E'\n' || '- **직업 전용 제작법이 없어졌습니다.** 청심환·약제 바탕·봉인 먹·정제 황지·강철 정련·청동 호신패·영맥 나침반 등 직업만 만들던 13가지를 누구나 만들고, 영맥 낫도 누구나 듭니다. 봉인술사만 받던 봉인 공예 품질 +5(「부적 정련」)도 없앴습니다.')
 where note_id = '1.0.0' and body not like '%직업 전용 제작법이 없어졌습니다%';

-- 남은 것 확인
do $p$
begin
  if exists (select 1 from public.world_crafting_recipes where required_job is not null) then raise exception '1.0.0b 직업 전용 제작법이 남음'; end if;
  if exists (select 1 from public.world_item_catalog where required_job is not null and category <> 'weapon') then raise exception '1.0.0b 직업 전용 도구가 남음'; end if;
end $p$;

update public.world_app_meta set value = '20261105010000' where key = 'db_version';
