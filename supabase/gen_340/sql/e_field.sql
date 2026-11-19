create or replace function public.world_job_skill_cost(p_job text) returns integer language sql immutable as $$
  select case when p_job in ('medic', 'formation') then 25 when p_job in ('bloodknight', 'spearman') then 20 else 12 end
$$;
select pg_temp.yh_share('public.world_job_skill_cost(text)');

create or replace function public.world_spear_rules() returns jsonb language sql immutable as $$
  select jsonb_build_object('name', '창끝 기세', 'per', 5, 'per24', 1, 'rank24', 24, 'max', 5, 'finish_name', '마무리 찌르기', 'finish_pct', 15, 'finish_at', 30)
$$;
create or replace function public.world_spear_mul(p_uid uuid, p_n integer, p_hp numeric, p_max numeric) returns numeric
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare r jsonb := public.world_spear_rules(); rk int; m numeric;
begin
  select coalesce((c.skill_progress -> 'spear' ->> 'rank')::int, 0) into rk from public.world_characters c where c.owner_id = p_uid;
  m := 1 + ((r ->> 'per')::numeric + case when coalesce(rk, 0) >= (r ->> 'rank24')::int then (r ->> 'per24')::numeric else 0 end) / 100.0 * least((r ->> 'max')::int, greatest(0, coalesce(p_n, 0)));
  if coalesce(p_max, 0) > 0 and p_hp * 100 < p_max * (r ->> 'finish_at')::numeric and 'spear_m50' = any (public.world_skill_procs(p_uid)) then
    m := m * (1 + (r ->> 'finish_pct')::numeric / 100.0);
  end if;
  return m;
end $$;
select pg_temp.yh_own('public.world_spear_mul(uuid, integer, numeric, numeric)', 'fn_owner_field');
select pg_temp.yh_share('public.world_spear_mul(uuid, integer, numeric, numeric)');
select pg_temp.yh_share('public.world_spear_rules()');
grant execute on function public.world_spear_rules() to authenticated;

select pg_temp.yh_fix('world_battle_action', array[
  $q$sp := sp - CASE WHEN c.job_key = 'medic' THEN 25 ELSE 12 END;$q$,
  $q$sp := sp - public.world_job_skill_cost(c.job_key);$q$,

  $q$  first_atk := NOT coalesce((v_pfx ->> 'opened')::boolean, false);$q$,
  $q$  first_atk := NOT coalesce((v_pfx ->> 'opened')::boolean, false);
  IF act NOT IN ('attack', 'skill') THEN v_pfx := v_pfx - 'chain'; END IF;$q$,

  $q$  ELSIF act = 'skill' AND c.job_key = 'analyst' THEN$q$,
  $q$  ELSIF act = 'skill' AND c.job_key = 'analyst' THEN$q$,

  $q$    ELSIF act = 'skill' AND c.job_key = 'tamer' THEN style := 'ranged'; skill_name := public.world_job_skill_rules() -> 'tamer' ->> 'name';$q$,
  $q$    ELSIF act = 'skill' AND c.job_key = 'tamer' THEN style := 'ranged'; skill_name := public.world_job_skill_rules() -> 'tamer' ->> 'name';
    ELSIF act = 'skill' AND c.job_key = 'spearman' THEN style := 'melee'; skill_name := public.world_job_skill_rules() -> 'spearman' ->> 'name';$q$,

  $q$    ELSIF skill_name = '파갑참' THEN mul := mul * 1.7;$q$,
  $q$    ELSIF skill_name = '파갑참' THEN mul := mul * 1.7;
    ELSIF skill_name = '관통 찌르기' THEN mul := mul * 1.4;$q$,

  $q$    IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN mul := mul * 1.2; END IF;$q$,
  $q$    IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN mul := mul * 1.2; END IF;
    IF c.job_key = 'bloodknight' AND 'bloodcraft_c24a' = ANY (sk) AND hp < 50 THEN mul := mul * 1.15; END IF;
    IF c.job_key = 'formation' AND 'formation_c30b' = ANY (sk) AND coalesce((v_pfx ->> 'zin')::int, 0) > 0 THEN mul := mul * 1.15; END IF;
    IF c.job_key = 'formation' AND coalesce((v_pfx ->> 'turned')::boolean, false) THEN mul := mul * 1.2; v_pfx := v_pfx - 'turned'; END IF;
    IF c.job_key = 'spearman' AND 'spear_c30b' = ANY (sk) AND v_intent LIKE 'g%:%' THEN mul := mul * 1.25; END IF;
    IF c.job_key = 'spearman' AND 'spear_c24a' = ANY (sk) AND style = 'melee' THEN crit_x := crit_x + 0.2; END IF;
    IF c.job_key = 'spearman' AND 'spear_m50' = ANY (sk) AND first_atk THEN force_crit := true; END IF;
    IF c.job_key = 'spearman' AND style = 'melee' THEN
      mul := mul * public.world_spear_mul(uid, coalesce((v_pfx ->> 'chain')::int, 0), a.current_hp, a.max_hp);
      v_pfx := v_pfx || jsonb_build_object('chain', least((public.world_spear_rules() ->> 'max')::int, coalesce((v_pfx ->> 'chain')::int, 0) + 1));
    END IF;$q$,

  $q$    dmg := greatest(1, round(base * mul - mdef * 0.8));$q$,
  $q$    dmg := greatest(1, round(base * mul - mdef * 0.8 * CASE WHEN skill_name = '관통 찌르기' AND 'spear_c43a' = ANY (sk) THEN 0 WHEN skill_name = '관통 찌르기' THEN 0.5 ELSE 1 END));
    IF coalesce((v_pfx ->> 'bsurge')::int, 0) > 0 THEN dmg := dmg + (v_pfx ->> 'bsurge')::int; lines := lines || jsonb_build_array('「갑주 되갚기」 막아 낸 피해를 되갚았다. +' || (v_pfx ->> 'bsurge')); v_pfx := v_pfx - 'bsurge'; END IF;$q$,

  $q$    a.current_hp := greatest(0, a.current_hp - dmg);
    lines := lines || jsonb_build_array(coalesce(skill_name,$q$,
  $q$    a.current_hp := greatest(0, a.current_hp - dmg);
    IF c.job_key = 'bloodknight' AND style = 'melee' AND dmg > 0 THEN
      extra := public.world_leech_of(uid, dmg);
      IF 'bloodcraft_c13a' = ANY (sk) AND random() < 0.25 THEN extra := extra * 2; END IF;
      IF coalesce((v_pfx ->> 'bk_last')::boolean, false) THEN extra := extra * 3; v_pfx := v_pfx - 'bk_last'; END IF;
      IF hp >= 100 AND 'bloodcraft_c30a' = ANY (sk) THEN
        v_pfx := v_pfx || jsonb_build_object('pshield_t', 3, 'pshield', least(coalesce((v_pfx ->> 'pshield')::int, 0) + extra, greatest(coalesce((v_pfx ->> 'pshield')::int, 0), 20)));
        lines := lines || jsonb_build_array('「끊기지 않는 숨」 넘친 피가 보호막이 됐다. +' || extra);
      ELSIF hp < 100 THEN
        hp := least(100, hp + extra); lines := lines || jsonb_build_array('흘린 피를 갈무리했다. 체력 +' || extra);
      END IF;
    END IF;
    IF c.job_key = 'spearman' AND style = 'melee' AND dmg > 0 AND a.current_hp > 0 THEN
      IF 'spear_c13a' = ANY (sk) AND coalesce((v_pfx ->> 'chain')::int, 0) >= 3 AND random() < 0.25 THEN
        extra := greatest(1, round(dmg * 0.6)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「세 번 찌르기」 +' || extra);
      END IF;
      IF 'spear_c13b' = ANY (sk) AND random() < 0.2 AND a.current_hp > 0 THEN
        extra := greatest(1, round(dmg * 0.4)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「반달 베기」 +' || extra);
      END IF;
      IF 'spear_c24b' = ANY (sk) AND random() < 0.15 THEN v_fx := v_fx || jsonb_build_object('weak', greatest(2, coalesce((v_fx ->> 'weak')::int, 0))); lines := lines || jsonb_build_array('「자루 쳐내기」 요괴가 휘청였다.'); END IF;
      IF 'spear_c30a' = ANY (sk) AND coalesce((v_pfx ->> 'chain')::int, 0) >= 3 THEN v_fx := v_fx || jsonb_build_object('marked', greatest(1, coalesce((v_fx ->> 'marked')::int, 0))); END IF;
      IF 'spear_c43b' = ANY (sk) THEN
        v_pfx := v_pfx || jsonb_build_object('spin', coalesce((v_pfx ->> 'spin')::int, 0) + 1);
        IF (v_pfx ->> 'spin')::int % 4 = 0 AND a.current_hp > 0 THEN
          extra := greatest(1, round(dmg * 0.5)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra; lines := lines || jsonb_build_array('「언월 회전」 +' || extra);
        END IF;
      END IF;
    END IF;
    IF c.job_key = 'formation' AND style = 'magic' AND dmg > 0 AND 'formation_c24b' = ANY (sk) AND random() < 0.2 THEN
      v_fx := v_fx || jsonb_build_object('weak', greatest(2, coalesce((v_fx ->> 'weak')::int, 0))); lines := lines || jsonb_build_array('「허를 셈」 요괴의 다음 수가 무뎌졌다.');
    END IF;
    IF first_atk AND skill_name IS NULL AND c.job_key = 'spearman' AND style = 'melee' AND dmg > 0 AND a.current_hp > 0 THEN
      extra := greatest(1, round(dmg * 0.3)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra;
      lines := lines || jsonb_build_array('「선제」 요괴보다 먼저 한 번 더 찔렀다. +' || extra);
    END IF;
    lines := lines || jsonb_build_array(coalesce(skill_name,$q$,

  $q$        IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 THEN mdmg := round(mdmg * CASE WHEN 'exorcism_c43b' = ANY (sk) THEN 0.74 ELSE 0.8 END); END IF;$q$,
  $q$        IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 THEN mdmg := round(mdmg * CASE WHEN 'exorcism_c43b' = ANY (sk) THEN 0.74 ELSE 0.8 END); END IF;
        IF coalesce((v_pfx ->> 'zin')::int, 0) > 0 THEN mdmg := round(mdmg * CASE WHEN 'formation_c24a' = ANY (sk) THEN 0.65 ELSE 0.75 END); END IF;
        IF c.job_key = 'formation' AND 'formation_c13b' = ANY (sk) AND v_intent LIKE 'g%:%' THEN mdmg := round(mdmg * 0.7); END IF;
        IF c.job_key = 'formation' AND 'formation_c43b' = ANY (sk) AND v_intent LIKE 'g%:%' THEN v_pfx := v_pfx || jsonb_build_object('turned', true); END IF;$q$,

  $q$        lines := lines || jsonb_build_array('「강기」가 ' || absorb || ' 피해를 막았다.');$q$,
  $q$        lines := lines || jsonb_build_array('보호막이 ' || absorb || ' 피해를 막았다.');
        IF 'bloodcraft_c30b' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('babs', coalesce((v_pfx ->> 'babs')::int, 0) + absorb); END IF;
        IF (v_pfx ->> 'pshield')::int <= 0 AND v_pfx ? 'bk_paid' THEN
          IF (v_pfx ->> 'bk_paid')::int > 0 THEN hp := least(100, hp + ((v_pfx ->> 'bk_paid')::int / 2)); lines := lines || jsonb_build_array('피 갑주가 깨지며 깎았던 체력 일부가 돌아왔다.'); END IF;
          IF 'bloodcraft_c30b' = ANY (sk) THEN v_pfx := (v_pfx - 'babs') || jsonb_build_object('bsurge', least(40, coalesce((v_pfx ->> 'bsurge')::int, 0) + round(coalesce((v_pfx ->> 'babs')::int, 0) * 0.3))); lines := lines || jsonb_build_array('「갑주 되갚기」 막아 낸 힘을 다음 공격에 싣는다.'); END IF;
          v_pfx := v_pfx - 'bk_paid';
        END IF;$q$,

  $q$  v_pfx := v_pfx - 'bound'; v_fx := v_fx - 'evade' - 'thorns' - 'mirror';$q$,
  $q$  IF v_pfx ? 'pshield_t' THEN
    IF (v_pfx ->> 'pshield_t')::int <= 1 OR coalesce((v_pfx ->> 'pshield')::int, 0) <= 0 THEN
      IF coalesce((v_pfx ->> 'pshield')::int, 0) > 0 THEN lines := lines || jsonb_build_array('보호막이 걷혔다.'); END IF;
      v_pfx := v_pfx - 'pshield' - 'pshield_t' - 'bk_paid' - 'babs';
    ELSE v_pfx := v_pfx || jsonb_build_object('pshield_t', (v_pfx ->> 'pshield_t')::int - 1); END IF;
  END IF;
  IF coalesce((v_pfx ->> 'zin')::int, 0) > 0 THEN
    IF 'formation_c30a' = ANY (sk) AND hp < 100 THEN hp := least(100, hp + 3); END IF;
    v_pfx := v_pfx || jsonb_build_object('zin', (v_pfx ->> 'zin')::int - 1);
    IF (v_pfx ->> 'zin')::int <= 0 THEN
      v_pfx := v_pfx - 'zin'; extra := round(10 * CASE WHEN 'formation_m50' = ANY (sk) THEN 2 ELSE 1 END * (1 + public.world_status_effect_total('healing_pct') / 100.0)); hp := least(100, hp + extra);
      IF 'formation_m50' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('pshield_t', 3, 'pshield', greatest(coalesce((v_pfx ->> 'pshield')::int, 0), round(15 * (1 + public.world_status_effect_total('shield_pct') / 100.0)))); END IF;
      lines := lines || jsonb_build_array('산가지 진이 걷히며 체력 +' || extra);
    END IF;
  END IF;
  v_pfx := v_pfx - 'bound'; v_fx := v_fx - 'evade' - 'thorns' - 'mirror';$q$,

  $q$    IF ended IS NULL AND hp <= 0 AND 'medicine_c43b' = ANY (sk) AND NOT coalesce((v_pfx ->> 'reborn')::boolean, false) THEN$q$,
  $q$    IF ended IS NULL AND hp <= 0 AND 'bloodcraft_c43a' = ANY (sk) AND NOT coalesce((v_pfx ->> 'endured')::boolean, false) THEN
      hp := 1; v_pfx := v_pfx || jsonb_build_object('endured', true, 'bk_last', true); lines := lines || jsonb_build_array('「마지막 한 모금」 쓰러질 일격을 버텨 냈다. 체력 1');
    END IF;
    IF ended IS NULL AND hp <= 0 AND 'formation_c43a' = ANY (sk) AND NOT coalesce((v_pfx ->> 'endured')::boolean, false) THEN
      hp := 25; v_pfx := v_pfx || jsonb_build_object('endured', true); lines := lines || jsonb_build_array('「무너지지 않는 진」 진이 쓰러질 일격을 대신 받았다. 체력 25');
    END IF;
    IF ended IS NULL AND hp <= 0 AND 'medicine_c43b' = ANY (sk) AND NOT coalesce((v_pfx ->> 'reborn')::boolean, false) THEN$q$
]);

select pg_temp.yh_fix('world_battle_action', array[
  $q$    IF sp < (CASE WHEN c.job_key = 'medic' THEN 25 ELSE 12 END) THEN RAISE EXCEPTION '%', CASE WHEN style = 'melee' THEN '기력' ELSE '영력' END || '이 모자랍니다. (필요 ' || CASE WHEN c.job_key = 'medic' THEN 25 ELSE 12 END || ')'; END IF;$q$,
  $q$    IF sp < public.world_job_skill_cost(c.job_key) THEN RAISE EXCEPTION '%', CASE WHEN style = 'melee' THEN '기력' ELSE '영력' END || '이 모자랍니다. (필요 ' || public.world_job_skill_cost(c.job_key) || ')'; END IF;$q$]);

select pg_temp.yh_fix('world_battle_action', array[
  $q$    sp := sp - public.world_job_skill_cost(c.job_key); v_pfx := v_pfx || jsonb_build_object('skill_ready', turn + 3);
  END IF;$q$,
  $q$    sp := sp - public.world_job_skill_cost(c.job_key); v_pfx := v_pfx || jsonb_build_object('skill_ready', turn + 3);
  END IF;
  IF act = 'skill' AND c.job_key = 'bloodknight' THEN
    IF NOT ('bloodcraft_m50' = ANY (sk)) THEN
      IF hp <= 15 THEN RAISE EXCEPTION '체력이 모자라 피 갑주를 두를 수 없습니다.'; END IF;
      hp := hp - 15;
    END IF;
    extra := round(CASE WHEN 'bloodcraft_c24b' = ANY (sk) THEN 30 ELSE 20 END * (1 + public.world_status_effect_total('shield_pct') / 100.0));
    v_pfx := v_pfx || jsonb_build_object('pshield_t', 3, 'pshield', least(90, coalesce((v_pfx ->> 'pshield')::int, 0) + extra), 'bk_paid', CASE WHEN 'bloodcraft_m50' = ANY (sk) THEN 0 ELSE 15 END);
    lines := lines || jsonb_build_array((public.world_job_skill_rules() -> 'bloodknight' ->> 'name') || ': ' || CASE WHEN 'bloodcraft_m50' = ANY (sk) THEN '' ELSE '체력 15를 깎아 ' END || '보호막 ' || extra || '을(를) 두르고 베어 들었다.');
    act := 'attack';
  ELSIF act = 'skill' AND c.job_key = 'formation' THEN
    v_pfx := v_pfx || jsonb_build_object('zin', CASE WHEN 'formation_c13a' = ANY (sk) THEN 4 ELSE 3 END, 'fm_hit', true);
    lines := lines || jsonb_build_array((public.world_job_skill_rules() -> 'formation' ->> 'name') || ': 다칠 자리를 셈해 진을 치며 산가지를 날렸다. 세 턴 동안 받는 피해가 줄어든다.');
    act := 'attack';
  END IF;$q$,
  $q$    IF coalesce((v_pfx ->> 'brace')::boolean, false) THEN mul := mul * 1.20;$q$,
  $q$    IF coalesce((v_pfx ->> 'fm_hit')::boolean, false) THEN mul := mul * 0.7; v_pfx := v_pfx - 'fm_hit'; END IF;
    IF style = 'melee' AND c.job_key = 'bloodknight' AND m.kind IN ('giant', 'shell') AND coalesce((c.skill_progress -> 'bloodcraft' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;
    IF style = 'melee' AND c.job_key = 'spearman' AND m.kind IN ('bird', 'sky') AND coalesce((c.skill_progress -> 'spear' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;
    IF style = 'magic' AND c.job_key = 'formation' AND m.kind IN ('ward', 'water') AND coalesce((c.skill_progress -> 'formation' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;
    IF coalesce((v_pfx ->> 'brace')::boolean, false) THEN mul := mul * 1.20;$q$]);
