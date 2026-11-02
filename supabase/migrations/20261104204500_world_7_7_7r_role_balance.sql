-- 7.7.7r — 직업 역할 균형(사용자 결정 2026-11-02, 7.7.7q 시뮬 검토 뒤)
--  ② 기여도: 한 사람을 노린 공격을 맞으면 자기 방어(피해 감소·받는 피해)로 줄인 몫의 절반을 「막아 준 피해」로(봉연·결전·귀허).
--  ③ 이목: 호위 무사 직업 이목 +50 → +80. 단도(백공) 기본 기술 넷에 이목 감소(합 −45%).
--  ④ 공격 역할: Lv30이면 누구나 피해 % 상한 35%에 닿아 백공의 덤이 잘렸다(호위 233 · 백공 226).
--      → 상한 밖에서 곱한다: 호위 무사 공격력 ×0.85, 백공 근접 공격력 ×1.10(직업 효과 근접 피해 +8%는 이것으로 바꿈).
--      백공 기본 능력치 힘 5·민첩 6·체질 6·감각 7 → 힘 8·민첩 6·체질 5·감각 5.
--      퇴마관 ② 정화 갈래 강화: 파사안 +20% → +26%(그 밖의 요괴에게도 +8%), 퇴마 진언 30 → 40%·걷어 내면 요괴 다음 공격 약화,
--      정화의 불 40 → 50%·25% 확률로 요기를 사르는 불(2턴 매턴 요괴 최대 체력 4%), 금강 결계 받는 피해 −20 → −26%.
--  ⑤ 결전(구중 봉주)에서는 피해 감소를 65%까지로 묶는다(갑옷 76%·도포 57% → 받는 피해 1.8배 차이가 1.2배로).
lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.rep(d text, a text, b text, n int default 1) returns text language plpgsql as $r$
declare k int := (length(d) - length(replace(d, a, ''))) / length(a);
begin
  if k <> n then raise exception '7.7.7r anchor (% / %): %', k, n, left(a, 90); end if;
  return replace(d, a, b);
end $r$;
create or replace function pg_temp.fdef(p_name text) returns text language plpgsql as $r$
declare d text; k int;
begin
  select count(*), max(replace(pg_get_functiondef(oid), E'\r\n', E'\n')) into k, d from pg_proc where proname = p_name and pronamespace = 'public'::regnamespace;
  if k <> 1 then raise exception '7.7.7r function % (%)', p_name, k; end if;
  return d;
end $r$;

-- ── ④ 백공 기본 능력치 ───────────────────────────────────────────────
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_job_base');
  if position($a$when 'analyst'    then '{"strength":5,$a$ in d) > 0 then
    execute pg_temp.rep(d, $a$when 'analyst'    then '{"strength":5,"agility":6,"vitality":6,"perception":7,"willpower":3,"spirit_affinity":3}'$a$,
      $a$when 'analyst'    then '{"strength":8,"agility":6,"vitality":5,"perception":5,"willpower":3,"spirit_affinity":3}'$a$);
  end if;
  -- 직업 효과의 근접 피해 +8%는 상한 밖 ×1.10으로 바꾼다
  d := pg_temp.fdef('world_job_effect');
  if position($a$when 'analyst'    then case p_key when 'melee_pct' then 8 else 0 end$a$ in d) > 0 then
    execute pg_temp.rep(d, $a$when 'analyst'    then case p_key when 'melee_pct' then 8 else 0 end$a$, $a$when 'analyst'    then 0$a$);
  end if;
end $p$;

-- ── ③④ 전투 능력치: 이목·공격 역할 ────────────────────────────────────
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_combat_stats');
  if position('presence_pct' in d) = 0 then
    d := pg_temp.rep(d, $a$WHEN c.job_key = 'artificer' THEN 50 ELSE 0 END$a$, $a$WHEN c.job_key = 'artificer' THEN 80 ELSE 0 END$a$);
    d := pg_temp.rep(d, $a$  pres := greatest(5, least(300, 30 +$a$,
      $a$  pres := greatest(5, least(300, (1 + coalesce((SELECT sum((sk.passive_effect ->> 'presence_pct')::numeric) FROM public.world_skill_catalog sk
      WHERE sk.category = skill_cat AND sk.passive_effect ? 'presence_pct' AND public.world_skill_line_ok(sk.category, sk.requires, c.job_key)
        AND public.world_skill_has(c.skill_progress, '{}'::jsonb, sk.category, sk.unlock_rank, sk.slot, sk.requires)), 0) / 100.0) * (30 +$a$);
    d := pg_temp.rep(d, $a$ FROM unnest(public.world_skill_procs(p_owner)) x) ELSE 0 END));$a$, $a$ FROM unnest(public.world_skill_procs(p_owner)) x) ELSE 0 END)));$a$);
    -- 공격 역할: 피해 % 상한(35)과 따로 곱한다
    d := pg_temp.rep(d, $a$  attack := base * (1 + (least(coalesce(c.combat_rank, 1), 50) - 1) * 0.006) * mind * (1 + pct / 100.0);$a$,
      $a$  attack := base * (1 + (least(coalesce(c.combat_rank, 1), 50) - 1) * 0.006) * mind * (1 + pct / 100.0)
    * CASE WHEN c.job_key = 'artificer' THEN 0.85 WHEN c.job_key = 'analyst' AND style = 'melee' THEN 1.10 ELSE 1 END;$a$);
    execute d;
  end if;
end $p$;

-- 봉인술사 = 버티는 술사(호위 무사보다 낮고 다른 직업보다 높은 이목·방어, 조사원보다 낮고 다른 직업보다 높은 회피)
-- 퇴마관 = 술법 공격수(방어는 낮게, 대신 이목도 낮게) — 사용자 결정 2026-11-02
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_combat_stats');
  if position($a$WHEN c.job_key = 'sealmaster' THEN 60$a$ in d) = 0 then
    d := pg_temp.rep(d, $a$WHEN c.job_key = 'artificer' THEN 80 ELSE 0 END$a$,
      $a$WHEN c.job_key = 'artificer' THEN 80 WHEN c.job_key = 'sealmaster' THEN 60 WHEN c.job_key = 'exorcist' THEN -15 ELSE 0 END$a$);
    d := pg_temp.rep(d, $a$  defense := greatest(0, s_vit * 0.8 + adef + g_def + c.level * 0.5);$a$,
      $a$  defense := greatest(0, s_vit * 0.8 + adef + g_def + c.level * 0.5 + CASE WHEN c.job_key = 'sealmaster' THEN 30 ELSE 0 END);$a$);
    d := pg_temp.rep(d, $a$CASE WHEN c.job_key = 'scout' THEN 6 ELSE 0 END + g_eva$a$,
      $a$CASE WHEN c.job_key = 'scout' THEN 6 WHEN c.job_key = 'sealmaster' THEN 12 ELSE 0 END + g_eva$a$);
    execute d;
  end if;
end $p$;

update public.world_skill_catalog s set description = v.d, passive_effect = v.e::jsonb
  from (values
    ('dagger_t3',  '근접 피해 +5% · 이목 -10%.', '{"damage_pct": 5, "presence_pct": -10}'),
    ('dagger_t13', '근접 피해 +3% · 이목 -10%.', '{"damage_pct": 3, "presence_pct": -10}'),
    ('dagger_t30', '치명타 +3% · 이목 -10%.', '{"crit_pct": 3, "presence_pct": -10}'),
    ('dagger_t43', '근접 피해 +3% · 치명타 +2% · 이목 -15%.', '{"damage_pct": 3, "crit_pct": 2, "presence_pct": -15}')) v(id, d, e)
 where s.skill_id = v.id;

-- ── ④ 퇴마관 ② 정화 갈래 ─────────────────────────────────────────────
update public.world_skill_catalog s set description = v.d
  from (values
    ('exorcism_c13b', '택일 기술(정화) · 영귀·은형·파봉 요괴에게 술법 피해 +26%, 그 밖의 요괴에게 +8%'),
    ('exorcism_c24b', '택일 기술(정화) · 술법이 적중하면 40% 확률로 요괴의 결계와 허상을 걷어 내고, 걷어 내면 요괴의 다음 공격이 약해진다(−20%)'),
    ('exorcism_c30b', '택일 기술(정화) · 술법 공격 때 50% 확률로 침식 −1, 25% 확률로 요기를 사르는 불(2턴 동안 매턴 요괴 최대 체력 4% 피해)'),
    ('exorcism_c43b', '택일 기술(정화) · 술법을 쓰면 3턴 동안 받는 피해 −26%, 술법 공격마다 30% 확률로 침식 −1')) v(id, d)
 where s.skill_id = v.id;

do $p$
declare d text;
begin
  d := pg_temp.fdef('world_battle_action');
  if position('정화의 불」 요기를 사르는' in d) = 0 then
    d := pg_temp.rep(d, $a$    IF style = 'magic' AND 'exorcism_c13b' = ANY (sk) AND m.kind IN ('ghost', 'shadow', 'breaker') THEN mul := mul * 1.2; END IF;$a$,
      $a$    IF style = 'magic' AND 'exorcism_c13b' = ANY (sk) THEN mul := mul * CASE WHEN m.kind IN ('ghost', 'shadow', 'breaker') THEN 1.26 ELSE 1.08 END; END IF;$a$);
    d := pg_temp.rep(d, $a$      IF 'exorcism_c24b' = ANY (sk) AND (v_fx ? 'barrier' OR v_fx ? 'evade') AND random() < 0.3 THEN
        v_fx := v_fx - 'barrier' - 'evade'; lines := lines || jsonb_build_array('「퇴마 진언」 요괴의 결계와 허상을 걷어 냈다.');$a$,
      $a$      IF 'exorcism_c24b' = ANY (sk) AND (v_fx ? 'barrier' OR v_fx ? 'evade') AND random() < 0.4 THEN
        v_fx := (v_fx - 'barrier' - 'evade') || jsonb_build_object('weak', greatest(2, coalesce((v_fx ->> 'weak')::int, 0))); lines := lines || jsonb_build_array('「퇴마 진언」 요괴의 결계와 허상을 걷어 냈다. 다음 공격이 약해진다.');$a$);
    d := pg_temp.rep(d, $a$      IF 'exorcism_c30b' = ANY (sk) AND er > 0 AND random() < 0.4 THEN er := er - 1; END IF;$a$,
      $a$      IF 'exorcism_c30b' = ANY (sk) AND er > 0 AND random() < 0.5 THEN er := er - 1; END IF;
      IF 'exorcism_c30b' = ANY (sk) AND a.current_hp > 0 AND random() < 0.25 THEN
        v_fx := v_fx || jsonb_build_object('pierce', greatest(2, coalesce((v_fx ->> 'pierce')::int, 0))); lines := lines || jsonb_build_array('「정화의 불」 요기를 사르는 불이 붙었다.');
      END IF;$a$);
    -- 금강 결계(청정결계 동작)는 퇴마관만 −26%
    d := pg_temp.rep(d, $a$        IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 THEN mdmg := round(mdmg * 0.8); END IF;$a$,
      $a$        IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 THEN mdmg := round(mdmg * CASE WHEN 'exorcism_c43b' = ANY (sk) THEN 0.74 ELSE 0.8 END); END IF;$a$);
    execute d;
  end if;
end $p$;

-- ── ②⑤ 받는 피해: 스스로 막아 낸 몫 · 결전 피해 감소 상한 ─────────────────
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_raid_hit');
  if position('self_guard' in d) = 0 then
    d := pg_temp.rep(d, $a$declare m public.world_raid_members%rowtype; pm public.world_raid_members%rowtype; f jsonb; r jsonb; c jsonb; d int; hp int; who uuid := p_target; nm text; absorb int;$a$,
      $a$declare m public.world_raid_members%rowtype; pm public.world_raid_members%rowtype; f jsonb; r jsonb; c jsonb; d int; hp int; who uuid := p_target; nm text; absorb int;
  rk text := (select x.kind from public.world_raids x where x.raid_id = p_raid); st jsonb; self_guard numeric;$a$);
    d := pg_temp.rep(d, $a$  nm := m.name;
  r := public.world_cb_mitigate(p_raw, m.stats, m.fx, who, p_kind in ('slam', 'burst'), p_kind = 'burst', null, p_kind = 'single');$a$,
      $a$  nm := m.name;
  -- 결전은 피해 감소를 65%까지(갑옷과 도포의 차이를 줄인다, 7.7.7r)
  st := case when rk = 'final' then m.stats || jsonb_build_object('red', least(65, coalesce((m.stats ->> 'red')::numeric, 0))) else m.stats end;
  r := public.world_cb_mitigate(p_raw, st, m.fx, who, p_kind in ('slam', 'burst'), p_kind = 'burst', null, p_kind = 'single');$a$);
    d := pg_temp.rep(d, $a$  perform public.world_raid_credit(p_raid, who, d, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);$a$,
      $a$  perform public.world_raid_credit(p_raid, who, d, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);
  -- 한 사람을 노린 공격: 자기 방어로 줄인 몫의 절반은 막아 준 피해(7.7.7r)
  if p_kind = 'single' then
    self_guard := p_raw * (1 - (1 - least(80, coalesce((st ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((st ->> 'inc')::numeric, 0) / 100.0)) * 0.5;
    if self_guard > 0 then perform public.world_raid_credit(p_raid, who, self_guard, 'guard'); end if;
  end if;$a$);
    execute d;
  end if;

  d := pg_temp.fdef('world_gw_hit');
  if position('self_guard' in d) = 0 then
    d := pg_temp.rep(d, $a$declare m public.world_gw_members%rowtype; r jsonb; c jsonb; av text;$a$, $a$declare m public.world_gw_members%rowtype; r jsonb; c jsonb; av text; self_guard numeric;$a$);
    d := pg_temp.rep(d, $a$  perform public.world_gw_credit(p_fight, p_uid, (r ->> 'd')::numeric, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);$a$,
      $a$  perform public.world_gw_credit(p_fight, p_uid, (r ->> 'd')::numeric, case when (r ->> 'taunt')::boolean then 'guard' else 'taken' end);
  -- 한 사람을 노린 공격: 자기 방어로 줄인 몫의 절반은 막아 준 피해(7.7.7r)
  if not p_aoe then
    self_guard := p_raw * (1 - (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0) * (1 + coalesce((m.stats ->> 'inc')::numeric, 0) / 100.0)
      * (1 - coalesce((m.stats ->> 'solo_guard')::numeric, 0) / 100.0)) * 0.5;
    if self_guard > 0 then perform public.world_gw_credit(p_fight, p_uid, self_guard, 'guard'); end if;
  end if;$a$);
    execute d;
  end if;
end $p$;

do $c$
begin
  if (select passive_effect ->> 'presence_pct' from public.world_skill_catalog where skill_id = 'dagger_t43') <> '-15' then raise exception '7.7.7r: 단도 이목'; end if;
  if (public.world_job_base('analyst') ->> 'strength') <> '8' then raise exception '7.7.7r: 백공 능력치'; end if;
  if (select sum(v::int) from jsonb_each_text(public.world_job_base('analyst')) t(k, v)) <> 30 then raise exception '7.7.7r: 백공 능력치 합'; end if;
end $c$;

update public.world_app_meta set value = '20261104204500' where key = 'db_version';
