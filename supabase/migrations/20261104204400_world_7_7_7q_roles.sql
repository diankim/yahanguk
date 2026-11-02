-- 7.7.7q — 직업 역할 다시 세우기(사용자 결정 2026-11-02)
--  · 호위 무사 = 방패·수호(요괴의 시선을 끌고 동료를 지킨다). 근접 공격수 자리는 백공 기술관(단도)에게.
--      직업 효과: 근접 피해 +8 → 없음, 받는 피해 −6 → −12, 이목 +30 → +50.
--      근접 계열 기본 기술은 받는 피해 감소 중심으로, 택일은 ① 방패(호령·도발·철갑 강기·사자후) / ② 수호(새: 반격 자세·버팀 기세·불굴·수호신), 숙달 「금강 수호」.
--      옛 공격 갈래(발도·일격·유수검·파천·검신)는 단도 계열이 빌려 쓰는 동작으로만 남긴다(category 'proc_src', 누구도 직접 익히지 않음).
--  · 백공 기술관: 직업 효과에 근접 피해 +8(근접 무기를 들었을 때). 생활 효과는 그대로.
--  · 협동 기술 맞바꾸기: 지키기 기술 「대신 막기」·「호법 신장」(→ 「철벽 수호」)은 호위 무사에게, 공격 기술 「급소 지시」(→ 「약점 진언」)·「파진 돌격」(→ 「멸마 진격」)은 퇴마관에게.
lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.rep(d text, a text, b text, n int default 1) returns text language plpgsql as $r$
declare k int := (length(d) - length(replace(d, a, ''))) / length(a);
begin
  if k <> n then raise exception '7.7.7q anchor (% / %): %', k, n, left(a, 90); end if;
  return replace(d, a, b);
end $r$;
create or replace function pg_temp.fdef(p_name text) returns text language plpgsql as $r$
declare d text; k int;
begin
  select count(*), max(replace(pg_get_functiondef(oid), E'\r\n', E'\n')) into k, d from pg_proc where proname = p_name and pronamespace = 'public'::regnamespace;
  if k <> 1 then raise exception '7.7.7q function % (%)', p_name, k; end if;
  return d;
end $r$;

-- ── 1. 직업 효과·이목 ───────────────────────────────────────────────
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_job_effect');
  if position($a$when 'artificer'  then case p_key when 'incoming_damage_pct' then -12$a$ in d) = 0 then
    d := pg_temp.rep(d, $a$when 'artificer'  then case p_key when 'melee_pct' then 8 when 'incoming_damage_pct' then -6 else 0 end$a$,
      $a$when 'artificer'  then case p_key when 'incoming_damage_pct' then -12 else 0 end$a$);
    d := pg_temp.rep(d, $a$when 'analyst'    then case p_key when 'gather_qty_pct' then 15$a$,
      $a$when 'analyst'    then case p_key when 'melee_pct' then 8 when 'gather_qty_pct' then 15$a$);
    execute d;
  end if;
  d := pg_temp.fdef('world_combat_stats');
  if position($a$WHEN c.job_key = 'artificer' THEN 50 ELSE 0 END$a$ in d) = 0 then
    execute pg_temp.rep(d, $a$WHEN c.job_key = 'artificer' THEN 30 ELSE 0 END$a$, $a$WHEN c.job_key = 'artificer' THEN 50 ELSE 0 END$a$);
  end if;
end $p$;

-- ── 2. 근접 계열(호위 무사) ─────────────────────────────────────────
-- 옛 공격 갈래·검신은 단도가 빌려 쓰는 동작으로만
update public.world_skill_catalog set category = 'proc_src'
 where skill_id in ('melee_x13', 'melee_c24a', 'melee_c30a', 'melee_c43a', 'melee_m50') and category = 'melee';
-- 방패 갈래는 택일 ①
update public.world_skill_catalog set slot = 'a' where skill_id in ('melee_c13b', 'melee_c24b', 'melee_x30', 'melee_c43b') and category = 'melee';
-- 기본 기술: 받는 피해 감소 중심
update public.world_skill_catalog s set skill_name = v.n, description = v.d, passive_effect = v.e::jsonb
  from (values
    ('melee_edge',  '방패 다루기', '받는 피해 -2% · 근접 피해 +2%.', '{"incoming_damage_pct": -2, "damage_pct": 2}'),
    ('melee_break', '파쇄 타격',   '근접 피해 +5%, 장갑 요괴에게 +8% 더.', '{"damage_pct": 5, "armored_bonus": 8}'),
    ('melee_t13',   '굳센 자세',   '받는 피해 -2%.', '{"incoming_damage_pct": -2}'),
    ('melee_t18',   '중심 잡기',   '받는 피해 -2% · 치명타 +2%.', '{"incoming_damage_pct": -2, "crit_pct": 2}'),
    ('melee_t24',   '검기 응축',   '근접 피해 +4%.', '{"damage_pct": 4}'),
    ('melee_t30',   '철벽 걸음',   '받는 피해 -3%.', '{"incoming_damage_pct": -3}'),
    ('melee_t36',   '기혈 순환',   '회복량 +5%.', '{"healing_pct": 5}'),
    ('melee_t43',   '부동심',      '받는 피해 -3% · 정신 손실 -5%.', '{"incoming_damage_pct": -3, "mental_loss_pct": -5}'),
    ('melee_t50',   '수호지경',    '받는 피해 -3% · 근접 피해 +5%.', '{"incoming_damage_pct": -3, "damage_pct": 5}')) v(id, n, d, e)
 where s.skill_id = v.id;
-- 수호 갈래(택일 ②)와 숙달
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, proc_as, requires) values
 ('melee_g13', '반격 자세', 'melee', '택일 기술(수호) · 방어하며 공격을 받으면 받은 피해의 40%+근력의 절반을 되받아친다', '{}', 13, 'b', null, null),
 ('melee_g24', '버팀 기세', 'melee', '택일 기술(수호) · 방어하며 공격을 받아 내면 다음 공격 피해 +35%', '{}', 24, 'b', null, null),
 ('melee_g30', '불굴', 'melee', '택일 기술(수호) · 체력이 30 아래면 받는 피해 −25%', '{}', 30, 'b', null, null),
 ('melee_g43', '수호신', 'melee', '택일 기술(수호) · 방어할 때 받는 피해 −30% 더, 방어마다 보호막 +4(최대 20)', '{}', 43, 'b', null, null),
 ('melee_g50', '금강 수호', 'melee', '숙달 기술 · 방어한 턴에 30% 확률로 공격을 완전히 받아 낸다', '{}', 50, 'master', null, null)
on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description,
  passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_exp_skill_def(skill_id, atk, guard, win, loot, find, heal, ward, kind, txt) values
 ('melee_g13', 2, 3, 0, 0, 0, 0, 0, 'fight', '방패를 세우고 들어오는 일격을 되받아칩니다.'),
 ('melee_g24', 3, 3, 0, 0, 0, 0, 0, 'fight', '받아 낸 힘을 실어 되밀어 냅니다.'),
 ('melee_g30', 0, 5, 0.01, 0, 0, 0, 0, 'fight', '쓰러질 듯 버티며 물러서지 않습니다.'),
 ('melee_g43', 0, 6, 0.01, 0, 0, 0, 0, 'fight', '수호신처럼 동료 앞을 막아섭니다.'),
 ('melee_g50', 0, 8, 0.02, 0, 0, 0, 0, 'fight', '금강처럼 버텨 어떤 일격도 넘기지 않습니다.')
on conflict (skill_id) do update set atk = excluded.atk, guard = excluded.guard, win = excluded.win, kind = excluded.kind, txt = excluded.txt;

-- 수호 갈래의 현장 토벌 동작
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_battle_action');
  if position('melee_g13' in d) = 0 then
    -- 버팀 기세: 다음 공격 +35%
    d := pg_temp.rep(d, $a$    IF coalesce((v_pfx ->> 'gd_last')::boolean, false) AND$a$,
      $a$    IF coalesce((v_pfx ->> 'brace')::boolean, false) THEN mul := mul * 1.35; v_pfx := v_pfx - 'brace'; lines := lines || jsonb_build_array('「버팀 기세」 받아 낸 힘을 실었다.'); END IF;
    IF coalesce((v_pfx ->> 'gd_last')::boolean, false) AND$a$);
    -- 수호신·금강 수호: 방어할 때 더 줄이고 보호막
    d := pg_temp.rep(d, $a$        IF guarding AND 'guarding_x13' = ANY (sk) THEN mdmg := round(mdmg * 0.8); END IF;$a$,
      $a$        IF guarding AND 'guarding_x13' = ANY (sk) THEN mdmg := round(mdmg * 0.8); END IF;
        IF guarding AND 'melee_g43' = ANY (sk) THEN mdmg := round(mdmg * 0.7); v_pfx := v_pfx || jsonb_build_object('pshield', least(20, coalesce((v_pfx ->> 'pshield')::int, 0) + 4)); END IF;
        IF guarding AND 'melee_g50' = ANY (sk) AND mdmg > 0 AND random() < 0.3 THEN mdmg := 0; lines := lines || jsonb_build_array('「금강 수호」 공격을 완전히 받아 냈다.'); END IF;$a$);
    -- 불굴: 체력 30 아래 받는 피해 −25%
    d := pg_temp.rep(d, $a$        IF c.health < 30 THEN mdmg := ceil(mdmg * 1.15); END IF;$a$,
      $a$        IF c.health < 30 THEN mdmg := ceil(mdmg * 1.15); END IF;
        IF hp < 30 AND 'melee_g30' = ANY (sk) THEN mdmg := round(mdmg * 0.75); END IF;$a$);
    -- 반격 자세·버팀 기세(공격을 받아 냈을 때)
    d := pg_temp.rep(d, $a$          IF guarding AND 'combo_guarding_mining' = ANY (sk) THEN$a$,
      $a$          IF guarding AND 'melee_g13' = ANY (sk) AND a.current_hp > 0 THEN
            extra := greatest(1, round(raw_m * 0.4 + c.strength * 0.5)); a.current_hp := greatest(0, a.current_hp - extra); lines := lines || jsonb_build_array('「반격 자세」 ' || extra || ' 피해를 되받아쳤다.');
          END IF;
          IF guarding AND 'melee_g24' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('brace', true); END IF;
          IF guarding AND 'combo_guarding_mining' = ANY (sk) THEN$a$);
    execute d;
  end if;
end $p$;

-- ── 3. 협동 기술 맞바꾸기 ───────────────────────────────────────────
update public.world_coop_skills set job_key = 'artificer', unlock_rank = 8, sort = 2 where skill_id = 'exo_cover';
update public.world_coop_skills set job_key = 'artificer', unlock_rank = 36, sort = 4, skill_name = '철벽 수호',
  exp_text = '철벽처럼 버티며 요괴의 공격을 끌어왔습니다' where skill_id = 'exo_guardian';
update public.world_coop_skills set job_key = 'exorcist', unlock_rank = 3, sort = 1, skill_name = '약점 진언',
  exp_text = '진언으로 요괴의 약점을 짚어 주었습니다' where skill_id = 'an_point';
update public.world_coop_skills set job_key = 'exorcist', unlock_rank = 36, sort = 4, skill_name = '멸마 진격',
  exp_text = '진언을 몰아 앞장서 몰아쳤습니다' where skill_id = 'an_command';
update public.world_coop_skills set sort = 1 where skill_id = 'an_share';
update public.world_coop_skills set sort = 3 where skill_id = 'an_break';
update public.world_coop_skills set sort = 2 where skill_id = 'exo_mantra';
update public.world_coop_skills set sort = 3 where skill_id = 'exo_barrier';

-- ── 4. 백공 기술관: 생활 특화를 빼고 전투만(사용자 결정 2026-11-02 「직업 효과는 전부 전투 관련으로」) ─────
--  빼는 것: 채집량 +15%·희귀품 +3%(직업 효과), 제작 품질 +15, 다른 직업 전용 제작법, 강화 확률 +10%p, 원정 「현장 가공」·원정 희귀품 +5%p, 탐색 채집터·덤 발견 보너스
--  더하는 것: 근접 피해 +8%(위 1), 근접 무기를 들면 치명타 +5, 원정 기술 「급소 찌르기」(싸움마다 25% 확률로 승률 +10%p)
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_job_effect');
  if position($a$'gather_qty_pct' then 15$a$ in d) > 0 then
    execute pg_temp.rep(d, $a$when 'analyst'    then case p_key when 'melee_pct' then 8 when 'gather_qty_pct' then 15 when 'rare_loot_pct' then 3 else 0 end$a$,
      $a$when 'analyst'    then case p_key when 'melee_pct' then 8 else 0 end$a$);
  end if;
  d := pg_temp.fdef('world_combat_stats');
  if position($a$c.job_key = 'analyst' AND style = 'melee' THEN 5$a$ in d) = 0 then
    execute pg_temp.rep(d, $a$CASE WHEN style = 'ranged' THEN 8 ELSE 0 END + skill_crit$a$,
      $a$CASE WHEN style = 'ranged' THEN 8 ELSE 0 END + CASE WHEN c.job_key = 'analyst' AND style = 'melee' THEN 5 ELSE 0 END + skill_crit$a$);
  end if;
  d := pg_temp.fdef('world_craft_item');
  if position($a$c.job_key <> 'analyst'$a$ in d) > 0 then
    d := pg_temp.rep(d, $a$ and c.job_key <> r.required_job and c.job_key <> 'analyst' then$a$, $a$ and c.job_key <> r.required_job then$a$);
    d := pg_temp.rep(d, E'    + case when c.job_key = ''analyst'' then 15 else 0 end\n', '');
    execute d;
  end if;
  d := pg_temp.fdef('world_enhance_quote');
  if position($a$c.job_key = 'analyst' then 10$a$ in d) > 0 then execute pg_temp.rep(d, $a$ + case when c.job_key = 'analyst' then 10 else 0 end$a$, ''); end if;
  d := pg_temp.fdef('world_weapon_enhance');
  if position($a$c.job_key = 'analyst' then 10$a$ in d) > 0 then execute pg_temp.rep(d, $a$ + case when c.job_key = 'analyst' then 10 else 0 end$a$, ''); end if;
  d := pg_temp.fdef('world_field_search');
  if position($a$c.job_key IN ('analyst', 'scout')$a$ in d) > 0 then
    d := pg_temp.rep(d, $a$CASE WHEN c.job_key IN ('analyst', 'scout') THEN 4$a$, $a$CASE WHEN c.job_key = 'scout' THEN 4$a$);
    d := pg_temp.rep(d, $a$ + CASE WHEN c.job_key = 'analyst' THEN 8 ELSE 0 END + depth * 3$a$, $a$ + depth * 3$a$);
    execute d;
  end if;
  d := pg_temp.fdef('world_expedition_settle');
  if position('[현장 가공]' in d) > 0 then
    d := pg_temp.rep(d, $a$        if c.job_key = 'analyst' and qty > 0 and random() < 0.25 then
          loot := public.world_inv_add(loot, item, 1); jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[현장 가공] 캔 재료를 손질해 쓸 만한 것을 하나 더 건졌습니다.');
        end if;
$a$, '');
    d := pg_temp.rep(d, $a$ + (case when c.job_key = 'analyst' then 0.05 else 0 end)$a$, '');
    d := pg_temp.rep(d, $a$        if weak_bonus > 0 then
          win_p := win_p + weak_bonus; weak_bonus := 0; jobn := jobn + 1;$a$,
      $a$        if c.job_key = 'analyst' and random() < 0.25 then
          win_p := win_p + 0.1; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[급소 찌르기] 요괴의 급소를 짚어 단번에 파고듭니다.');
        end if;
        if weak_bonus > 0 then
          win_p := win_p + weak_bonus; weak_bonus := 0; jobn := jobn + 1;$a$);
    execute d;
  end if;
  d := pg_temp.fdef('world_expedition_complete');
  if position($a$'analyst' then '현장 가공'$a$ in d) > 0 then execute pg_temp.rep(d, $a$'analyst' then '현장 가공'$a$, $a$'analyst' then '급소 찌르기'$a$); end if;
  d := pg_temp.fdef('world_expedition_progress');
  if position($a$'analyst' then '현장 가공'$a$ in d) > 0 then execute pg_temp.rep(d, $a$'analyst' then '현장 가공'$a$, $a$'analyst' then '급소 찌르기'$a$); end if;
  d := pg_temp.fdef('world_exp_fight_story');
  if position('[현장 기지]' in d) > 0 then execute pg_temp.rep(d, $a$'[현장 기지] 주변 지형을 이용해 {f}의 발을 묶었습니다'$a$, $a$'[급소 찌르기] {f}의 급소를 정확히 찔렀습니다'$a$); end if;
end $p$;

do $c$
begin
  if (select count(*) from public.world_coop_skills where job_key = 'artificer') <> 4 or (select count(*) from public.world_coop_skills where job_key = 'exorcist') <> 4 then raise exception '7.7.7q: 협동 기술 수'; end if;
  if (select count(*) from public.world_skill_catalog where category = 'melee') <> 18 then raise exception '7.7.7q: 근접 계열 기술 수 %', (select count(*) from public.world_skill_catalog where category = 'melee'); end if;
end $c$;

update public.world_app_meta set value = '20261104204400' where key = 'db_version';
