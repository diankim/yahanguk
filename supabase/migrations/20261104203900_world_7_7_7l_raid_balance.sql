-- 7.7.7l — 파티 전투 균형(사용자 결정 2026-11-01, 복제 DB 시뮬레이션 결과):
--  ① 구중 봉주 결전도 귀허처럼 체력 회복품을 한 싸움에 다섯 개까지(아래 단계 토벌이라 귀허 둘보다 많이), 쉬다 돌아오면 체력 30, 혼자면 회복 기술 절반. 결전 중에는 가방·퀵슬롯에서 바로 못 쓰고 결전 화면 「물품」으로만.
--     영력·기력 회복품(체력이 오르지 않는 것)은 세지 않는다.
--  ② 혼자 싸울 때만 직업 보정(world_solo_aid): 혼자 귀허 승률이 백공 67%·호위 무사 42%·조사원 17%·퇴마관·봉인술사·의무관 0%로 갈려서
--     주는 피해 +%와(귀허) 쓰러짐 상한 +n번. 둘 이상은 그대로.
alter table public.world_raid_members add column if not exists items_used integer not null default 0;

create or replace function public.world_solo_aid(p_job text)
returns jsonb language sql immutable as $f$
  -- dmg: 주는 피해 %, falls: 귀허 쓰러짐 상한 +, guard: 받는 피해 −%(world_cb_mitigate가 stats.solo_guard로) — 혼자 도전 10판씩 복제 DB 시뮬레이션으로 맞춤
  -- final_dmg: 구중 봉주 결전 혼자일 때만 solo_dmg 대신(회복품이 다섯이라 회복 기술·회피가 있는 직업이 크게 유리해서 따로 맞춤)
  select case p_job
    when 'exorcist'   then '{"solo_dmg": 17, "solo_falls": 2, "solo_guard": 8, "final_dmg": 20}'
    when 'sealmaster' then '{"solo_dmg": 15, "solo_falls": 2, "solo_guard": 12, "final_dmg": 20}'
    when 'medic'      then '{"solo_dmg": 5, "solo_falls": 2}'
    when 'artificer'  then '{"solo_dmg": 5, "solo_falls": 1, "final_dmg": 15}'
    when 'scout'      then '{"solo_dmg": 7, "solo_falls": 2, "final_dmg": -15}'
    when 'analyst'    then '{"final_dmg": -25}'
    else '{}' end::jsonb
$f$;
revoke all on function public.world_solo_aid(text) from public, anon, authenticated;
grant execute on function public.world_solo_aid(text) to fn_owner_field;

create or replace function pg_temp.yh_sub(d text, o text, n text, tag text) returns text language plpgsql as $f$
begin
  if (length(d) - length(replace(d, o, ''))) / greatest(1, length(o)) <> 1 then raise exception '7.7.7l anchor %', tag; end if;
  return replace(d, o, n);
end $f$;

do $p$
declare d text;
begin
  -- 귀허: 혼자 시작하면 보정을 참가자 능력치에 적어 둔다(주인 체력 계산 뒤라 체력은 그대로)
  d := replace(pg_get_functiondef('public.world_gw_start(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('world_solo_aid' in d) = 0 then
    d := pg_temp.yh_sub(d, '  perform public.world_gw_say(p_fight, 0, ''phase'',',
      '  if n = 1 then update public.world_gw_members m set stats = m.stats || public.world_solo_aid(m.job_key) where fight_id = p_fight; end if;
  perform public.world_gw_say(p_fight, 0, ''phase'',', 'gw_start');
    execute d;
  end if;

  d := replace(pg_get_functiondef('public.world_gw_resolve(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('solo_dmg' in d) = 0 then
    d := pg_temp.yh_sub(d, '* case when cr then 1.5 else 1 end * mul;
      physical',
      '* case when cr then 1.5 else 1 end * mul * (1 + coalesce((m.stats ->> ''solo_dmg'')::numeric, 0) / 100.0);
      physical', 'gw_resolve dmg');
    d := pg_temp.yh_sub(d, '(select max(falls) from public.world_gw_members where fight_id = p_fight) > 10 then',
      '(select max(falls) - coalesce(max((stats ->> ''solo_falls'')::int), 0) from public.world_gw_members where fight_id = p_fight) > 10 then', 'gw_resolve cap');
    d := pg_temp.yh_sub(d, '''열한 번째로 쓰러졌습니다. 홀로 선 이의 넋이 더는 버티지 못합니다.''',
      '''쓰러질 수 있는 횟수를 넘겼습니다. 홀로 선 이의 넋이 더는 버티지 못합니다.''', 'gw_resolve msg');
    execute d;
  end if;

  d := replace(pg_get_functiondef('public.world_gw_hurt(uuid,uuid,integer,integer,text)'::regprocedure), E'\r\n', E'\n');
  if position('solo_falls' in d) = 0 then
    d := pg_temp.yh_sub(d, 'greatest(0, 10 - (m.falls + 1))', 'greatest(0, 10 + coalesce((m.stats ->> ''solo_falls'')::int, 0) - (m.falls + 1))', 'gw_hurt');
    execute d;
  end if;

  d := replace(pg_get_functiondef('public.world_gw_snapshot(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('falls_cap' in d) = 0 then
    d := pg_temp.yh_sub(d, '''items_left'', greatest(0, 2 - coalesce(me.items_used, 0)),',
      '''items_left'', greatest(0, 2 - coalesce(me.items_used, 0)),
    ''falls_cap'', 10 + coalesce((select max((x.stats ->> ''solo_falls'')::int) from public.world_gw_members x where x.fight_id = fid), 0),
    ''solo'', case when (select count(*) from public.world_gw_members x where x.fight_id = fid) = 1 then jsonb_build_object(''dmg'', me.stats -> ''solo_dmg'', ''falls'', me.stats -> ''solo_falls'', ''guard'', me.stats -> ''solo_guard'') end,', 'gw_snapshot');
    execute d;
  end if;

  -- 결전: 회복품 셋·혼자 주는 피해
  d := replace(pg_get_functiondef('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure), E'\r\n', E'\n');
  if position('items_used' in d) = 0 then
    d := pg_temp.yh_sub(d, '  if mb.out_until is not null then mb.out_until := null; end if;',
      '  if mb.out_until is not null then mb.out_until := null;
    -- 결전: 쉬다가 돌아오면 체력 30(귀허와 같게 — 회복품이 셋뿐이라 체력 1로 돌아오면 곧바로 다시 쓰러진다)
    if rd.kind = ''final'' and c.health < 30 then c.health := 30; update public.world_characters set health = 30, updated_at = now() where owner_id = uid; end if;
  end if;', 'raid_action return');
    d := pg_temp.yh_sub(d, '      if k = ''revive'' then
        select health into h1',
      '      -- 결전: 회복 기술은 절반(회복품을 다섯으로 묶어 회복 기술이 승패를 혼자 정하던 것 — 회복 직업 없는 조가 해볼 만하게)
      if rd.kind = ''final'' and k in (''heal'', ''cleanse_heal'') then amt := ceil(amt * 0.5); end if;
      if k = ''revive'' then
        select health into h1', 'raid_action solo heal');
    d := pg_temp.yh_sub(d, '    if crit then mul := mul * 1.5; end if;',
      '    if crit then mul := mul * 1.5; end if;
    if rd.kind = ''final'' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then
      mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> ''final_dmg'')::numeric, (public.world_solo_aid(c.job_key) ->> ''solo_dmg'')::numeric, 0) / 100.0); end if;', 'raid_action dmg');
    d := pg_temp.yh_sub(d, '    sp := c.spiritual_power; inv := coalesce(c.inventory, ''{}''::jsonb); h1 := c.health;',
      '    sp := c.spiritual_power; inv := coalesce(c.inventory, ''{}''::jsonb); h1 := c.health;
    if rd.kind = ''final'' and h1 > h0 then
      if mb.items_used >= 5 then raise exception ''결전에서는 체력 회복품을 한 싸움에 다섯 개까지만 쓸 수 있습니다.''; end if;
      mb.items_used := mb.items_used + 1;
    end if;', 'raid_action item');
    d := pg_temp.yh_sub(d, 'contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = st where raid_id = p_raid and owner_id = uid;',
      'contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = case when rd.kind = ''final'' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then st || public.world_solo_aid(c.job_key) else st end, items_used = mb.items_used where raid_id = p_raid and owner_id = uid;', 'raid_action save');
    execute d;
  end if;

  d := replace(pg_get_functiondef('public.world_raid_snapshot_core(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('items_left' in d) = 0 then
    d := pg_temp.yh_sub(d, '''resting'', me.out_until is not null and me.out_until <= now(),',
      '''resting'', me.out_until is not null and me.out_until <= now(),
      ''items_left'', case when rd.kind = ''final'' and me.owner_id is not null then greatest(0, 5 - me.items_used) end,
      ''solo'', case when rd.kind = ''final'' and me.owner_id is not null and (select count(*) from public.world_raid_members x where x.raid_id = rd.raid_id) = 1 then public.world_solo_aid(me.job_key) end,', 'raid_snapshot');
    execute d;
  end if;

  -- 결전 중에는 가방·퀵슬롯에서 바로 쓰지 않는다(물러나 있거나 자리를 비워도) — 결전 화면 「물품」(world_raid_action)만
  d := replace(pg_get_functiondef('public.world_use_item(text)'::regprocedure), E'\r\n', E'\n');
  if position('결전 중에는' in d) = 0 then
    d := pg_temp.yh_sub(d, '  IF coalesce(c.is_dead, false) THEN RAISE EXCEPTION',
      '  IF coalesce(current_setting(''yh.raid_item'', true), '''') <> ''1'' AND EXISTS (
       SELECT 1 FROM public.world_raid_members m JOIN public.world_raids rd ON rd.raid_id = m.raid_id
        WHERE m.owner_id = uid AND rd.status = ''fight'' AND rd.kind = ''final'') THEN
    RAISE EXCEPTION ''결전 중에는 가방의 물품을 바로 쓸 수 없습니다. 결전 화면의 「물품」으로 쓰세요(체력 회복품은 한 싸움에 다섯 개까지).'';
  END IF;
  IF coalesce(c.is_dead, false) THEN RAISE EXCEPTION', 'use_item');
    execute d;
  end if;
  -- 혼자 도전 보정의 받는 피해 감소(stats.solo_guard — 귀허 시작 때·결전 행동 때 적음)
  d := replace(pg_get_functiondef('public.world_cb_mitigate(numeric,jsonb,jsonb,uuid,boolean,boolean,text,boolean)'::regprocedure), E'\r\n', E'\n');
  if position('solo_guard' in d) = 0 then
    d := pg_temp.yh_sub(d, '  d := d * (1 - red / 100.0) * (1 + coalesce((p_stats ->> ''inc'')::numeric, 0) / 100.0);',
      '  d := d * (1 - red / 100.0) * (1 + coalesce((p_stats ->> ''inc'')::numeric, 0) / 100.0) * (1 - coalesce((p_stats ->> ''solo_guard'')::numeric, 0) / 100.0);', 'cb_mitigate solo');
    execute d;
  end if;
  -- 결전: 모두 물러났을 때 보스가 되찾는 체력 8% → 3%(회복 직업 없는 조합이 회복품을 다 쓴 뒤 되풀이해 차올라 0%이던 것)
  d := replace(pg_get_functiondef('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure), E'\r\n', E'\n');
  if position('round(rd.max_hp * 0.08)' in d) > 0 then
    d := pg_temp.yh_sub(d, 'rd.hp := least(rd.max_hp, rd.hp + round(rd.max_hp * 0.08));', 'rd.hp := least(rd.max_hp, rd.hp + round(rd.max_hp * 0.03));', 'final wipe heal');
    d := pg_temp.yh_sub(d, '기운을 되찾습니다(체력 +8%).', '기운을 되찾습니다(체력 +3%).', 'final wipe msg');
    execute d;
  end if;
  -- 귀허: 혼자면 주인 체력 ×1.12(혼자 보정 뒤 평균을 3/10 근처로)
  d := replace(pg_get_functiondef('public.world_gw_start(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('when 1 then 1.12 when 2' in d) = 0 then
    if (length(d) - length(replace(d, 'case n when 1 then 1 when 2', ''))) / length('case n when 1 then 1 when 2') <> 2 then raise exception '7.7.7l anchor gw solo hp'; end if;
    d := replace(d, 'case n when 1 then 1 when 2', 'case n when 1 then 1.12 when 2');
    execute d;
  end if;
  -- 결전: 혼자면 보스 체력 ×1.6·둘이면 ×2.0(전 1·1.7) (회복품 다섯·물러남 회복 3%로 둘이 해볼 만해진 대신 혼자는 쉬워져서)
  d := replace(pg_get_functiondef('public.world_raid_begin_fight(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('when 1 then 1.6 when 2 then 2.0' in d) = 0 then
    d := pg_temp.yh_sub(d, 'case least(n, 4) when 1 then 1 when 2 then 1.7', 'case least(n, 4) when 1 then 1.6 when 2 then 2.0', 'final solo hp');
    execute d;
  end if;
  -- 협동 기술(사용자 결정 2026-11-01, 파티 효율 점검): 퇴마관 파사 진언은 광역뿐 아니라 다음에 받는 공격 한 번에
  d := replace(pg_get_functiondef('public.world_cb_mitigate(numeric,jsonb,jsonb,uuid,boolean,boolean,text,boolean)'::regprocedure), E'\r\n', E'\n');
  if position('if p_aoe and f ? ''gward'' then' in d) > 0 then
    d := pg_temp.yh_sub(d, 'if p_aoe and f ? ''gward'' then', 'if f ? ''gward'' then', 'mantra any hit');
    execute d;
  end if;
  -- 귀허: 의무관 회복 기술 절반 → 0.65배
  d := replace(pg_get_functiondef('public.world_gw_resolve(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('(e ->> ''amt'')::int * 0.5)' in d) > 0 then
    if (length(d) - length(replace(d, '(e ->> ''amt'')::int * 0.5)', ''))) / length('(e ->> ''amt'')::int * 0.5)') <> 6 then raise exception '7.7.7l anchor gw heal'; end if;
    d := replace(d, '(e ->> ''amt'')::int * 0.5)', '(e ->> ''amt'')::int * 0.65)');
    execute d;
  end if;
  -- 결전: 쓰러졌을 때 쉬는 시간 60초 → 30초(회복 직업 없는 조가 쉬는 동안 시간이 다 가 버리던 것)
  d := replace(pg_get_functiondef('public.world_raid_hit(uuid,uuid,numeric,text)'::regprocedure), E'\r\n', E'\n');
  if position('30 seconds' in d) = 0 then
    d := pg_temp.yh_sub(d, 'out_until = now() + interval ''60 seconds'', falls = falls + 1',
      'out_until = now() + case when (select x.kind from public.world_raids x where x.raid_id = p_raid) = ''final'' then interval ''30 seconds'' else interval ''60 seconds'' end, falls = falls + 1', 'hit out30');
    d := pg_temp.yh_sub(d, '의 피해를 입고 물러났습니다(1분 쉰 뒤 행동하면 돌아옴).''',
      '의 피해를 입고 물러났습니다('' || case when (select x.kind from public.world_raids x where x.raid_id = p_raid) = ''final'' then ''30초'' else ''1분'' end || '' 쉰 뒤 행동하면 돌아옴).''', 'hit out30 msg');
    execute d;
  end if;
  -- 결전: 모두 회복도 절반
  d := replace(pg_get_functiondef('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure), E'\r\n', E'\n');
  if position('heal_all final half' in d) = 0 then
    d := pg_temp.yh_sub(d, E'      amt := round((v ->> ''amt'')::int * (1 + coalesce((c.skill_progress -> ''first_aid'' ->> ''rank'')::int, 0) / 100.0));\n      select sum',
      E'      amt := round((v ->> ''amt'')::int * (1 + coalesce((c.skill_progress -> ''first_aid'' ->> ''rank'')::int, 0) / 100.0));\n      if rd.kind = ''final'' then amt := ceil(amt * 0.5); end if; -- heal_all final half\n      select sum', 'heal_all final');
    execute d;
  end if;
end $p$;

-- 협동 기술 수치: 의무관 응급 처치 16→20·맥 짚기 12→15, 퇴마관 대신 막기 다시 쓰기 12→8초·퇴마 결계 25→20초, 백공 영력 보급 20→25
update public.world_coop_skills set effect = jsonb_set(effect, '{amt}', '20'), description = '동료 한 명의 체력을 20 회복한다(응급 처치 기술 단계만큼 더).' where skill_id = 'med_aid';
update public.world_coop_skills set effect = jsonb_set(effect, '{amt}', '15'), description = '참가자 모두의 체력을 15 회복한다.' where skill_id = 'med_pulse';
update public.world_coop_skills set cooldown_s = 8 where skill_id = 'exo_cover';
update public.world_coop_skills set cooldown_s = 20 where skill_id = 'exo_barrier';
update public.world_coop_skills set description = '동료 한 명이 다음에 받는 공격 한 번의 피해 −50%, 정신 +6.' where skill_id = 'exo_mantra';
update public.world_coop_skills set effect = jsonb_set(effect, '{amt}', '25'), description = '동료 한 명의 영력(기력)을 25 채운다. 영력이 들지 않는다.' where skill_id = 'art_supply';

update public.world_patch_notes set body = body || $N$
## 7.7.7l
- 구중 봉주 결전에서도 체력 회복품을 한 싸움에 다섯 개까지만 쓸 수 있습니다(귀허의 주인은 두 개). 모두 물러났을 때 결전 보스가 되찾는 체력은 8%에서 3%로 줄였습니다. 결전에서 회복 기술의 회복량은 절반입니다. 결전 중에는 가방·퀵슬롯에서 바로 쓰지 않고 결전 화면의 「물품」으로 씁니다. 영력·기력 회복품은 세지 않습니다. 결전에서 물러났다가 쉬는 중에 행동해 돌아오면 귀허처럼 체력 30으로 돌아옵니다.
- 혼자 도전하면 귀허의 주인 체력이 1.12배, 구중 봉주 체력이 1.8배입니다(전 1배). 둘이 도전하는 구중 봉주 체력은 1.7배에서 2배로 올렸습니다. 결전에서 쓰러졌을 때 쉬는 시간은 1분에서 30초로 줄였습니다.
- 혼자 도전할 때만 직업 보정이 붙습니다(둘 이상이면 그대로): 의무관 주는 피해 +15%·받는 피해 −8% · 퇴마관 +12%·−8% · 봉인술사 +12%·−12% · 현장 조사원 +8% · 호위 무사 +5%. 귀허의 주인에서는 쓰러질 수 있는 횟수도 의무관 +3번·퇴마관·봉인술사·조사원 +2번·호위 무사 +1번.
- 협동 기술: 의무관 응급 처치 체력 16→20·맥 짚기 12→15, 퇴마관 대신 막기 다시 쓰기 12초→8초·퇴마 결계 25초→20초·파사 진언은 광역뿐 아니라 다음에 받는 공격 한 번에, 백공 영력 보급 20→25. 귀허의 주인에서 의무관 회복 기술은 절반이 아니라 0.65배입니다.
$N$ where note_id = '7.7.0' and position('## 7.7.7l' in body) = 0;

update public.world_app_meta set value = '20261104203900' where key = 'db_version';
