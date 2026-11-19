select pg_temp.yh_fix('world_battle_action', array[
  $q$sp := sp - CASE WHEN c.job_key = 'medic' THEN 25 ELSE 12 END;$q$,
  $q$sp := sp - CASE WHEN c.job_key IN ('medic', 'formation') THEN 25 WHEN c.job_key IN ('bloodknight', 'spearman') THEN 20 ELSE 12 END;$q$,

  $q$  first_atk := NOT coalesce((v_pfx ->> 'opened')::boolean, false);$q$,
  $q$  first_atk := NOT coalesce((v_pfx ->> 'opened')::boolean, false);
  IF act NOT IN ('attack', 'skill') THEN v_pfx := v_pfx - 'chain'; END IF;$q$,

  $q$  ELSIF act = 'skill' AND c.job_key = 'analyst' THEN$q$,
  $q$  ELSIF act = 'skill' AND c.job_key = 'bloodknight' THEN
    IF hp <= 15 THEN RAISE EXCEPTION '체력이 모자라 피 갑주를 두를 수 없습니다.'; END IF;
    hp := hp - 15;
    extra := round(30 * (1 + public.world_status_effect_total('shield_pct') / 100.0));
    v_pfx := v_pfx || jsonb_build_object('pshield', least(90, coalesce((v_pfx ->> 'pshield')::int, 0) + extra), 'bk_paid', 15);
    lines := lines || jsonb_build_array((public.world_job_skill_rules() -> 'bloodknight' ->> 'name') || ': 체력 15를 깎아 보호막 ' || extra || '을(를) 둘렀다.');
  ELSIF act = 'skill' AND c.job_key = 'formation' THEN
    v_pfx := v_pfx || jsonb_build_object('zin', 3);
    lines := lines || jsonb_build_array((public.world_job_skill_rules() -> 'formation' ->> 'name') || ': 다칠 자리를 셈해 진을 쳤다. 세 턴 동안 받는 피해가 줄어든다.');
  ELSIF act = 'skill' AND c.job_key = 'analyst' THEN$q$,

  $q$    ELSIF act = 'skill' AND c.job_key = 'tamer' THEN style := 'ranged'; skill_name := public.world_job_skill_rules() -> 'tamer' ->> 'name';$q$,
  $q$    ELSIF act = 'skill' AND c.job_key = 'tamer' THEN style := 'ranged'; skill_name := public.world_job_skill_rules() -> 'tamer' ->> 'name';
    ELSIF act = 'skill' AND c.job_key = 'spearman' THEN style := 'melee'; skill_name := public.world_job_skill_rules() -> 'spearman' ->> 'name';$q$,

  $q$    ELSIF skill_name = '파갑참' THEN mul := mul * 1.7;$q$,
  $q$    ELSIF skill_name = '파갑참' THEN mul := mul * 1.7;
    ELSIF skill_name = '관통 찌르기' THEN mul := mul * 1.6;$q$,

  $q$    IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN mul := mul * 1.2; END IF;$q$,
  $q$    IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN mul := mul * 1.2; END IF;
    IF c.job_key = 'spearman' AND style = 'melee' THEN
      mul := mul * (1 + 0.06 * least(3, coalesce((v_pfx ->> 'chain')::int, 0)));
      v_pfx := v_pfx || jsonb_build_object('chain', least(3, coalesce((v_pfx ->> 'chain')::int, 0) + 1));
    END IF;$q$,

  $q$    dmg := greatest(1, round(base * mul - mdef * 0.8));$q$,
  $q$    dmg := greatest(1, round(base * mul - mdef * 0.8 * CASE WHEN skill_name = '관통 찌르기' THEN 0.5 ELSE 1 END));$q$,

  $q$    a.current_hp := greatest(0, a.current_hp - dmg);
    lines := lines || jsonb_build_array(coalesce(skill_name,$q$,
  $q$    a.current_hp := greatest(0, a.current_hp - dmg);
    IF c.job_key = 'bloodknight' AND style = 'melee' AND dmg > 0 AND hp < 100 THEN
      extra := least(6, greatest(1, round(dmg * 0.08))); hp := least(100, hp + extra);
      lines := lines || jsonb_build_array('흘린 피를 갈무리했다. 체력 +' || extra);
    END IF;
    IF first_atk AND c.job_key = 'spearman' AND style = 'melee' AND dmg > 0 AND a.current_hp > 0 THEN
      extra := greatest(1, round(dmg * 0.5)); a.current_hp := greatest(0, a.current_hp - extra); ex_total := ex_total + extra;
      lines := lines || jsonb_build_array('「선제」 요괴보다 먼저 한 번 더 찔렀다. +' || extra);
    END IF;
    lines := lines || jsonb_build_array(coalesce(skill_name,$q$,

  $q$        IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 THEN mdmg := round(mdmg * CASE WHEN 'exorcism_c43b' = ANY (sk) THEN 0.74 ELSE 0.8 END); END IF;$q$,
  $q$        IF coalesce((v_pfx ->> 'ward')::int, 0) > 0 THEN mdmg := round(mdmg * CASE WHEN 'exorcism_c43b' = ANY (sk) THEN 0.74 ELSE 0.8 END); END IF;
        IF coalesce((v_pfx ->> 'zin')::int, 0) > 0 THEN mdmg := round(mdmg * 0.65); END IF;$q$,

  $q$        lines := lines || jsonb_build_array('「강기」가 ' || absorb || ' 피해를 막았다.');$q$,
  $q$        lines := lines || jsonb_build_array('보호막이 ' || absorb || ' 피해를 막았다.');
        IF (v_pfx ->> 'pshield')::int <= 0 AND v_pfx ? 'bk_paid' THEN
          hp := least(100, hp + ((v_pfx ->> 'bk_paid')::int / 2)); v_pfx := v_pfx - 'bk_paid';
          lines := lines || jsonb_build_array('피 갑주가 깨지며 깎았던 체력 일부가 돌아왔다.');
        END IF;$q$,

  $q$  v_pfx := v_pfx - 'bound'; v_fx := v_fx - 'evade' - 'thorns' - 'mirror';$q$,
  $q$  IF coalesce((v_pfx ->> 'zin')::int, 0) > 0 THEN
    v_pfx := v_pfx || jsonb_build_object('zin', (v_pfx ->> 'zin')::int - 1);
    IF (v_pfx ->> 'zin')::int <= 0 THEN
      v_pfx := v_pfx - 'zin'; extra := round(10 * (1 + public.world_status_effect_total('healing_pct') / 100.0)); hp := least(100, hp + extra);
      lines := lines || jsonb_build_array('산가지 진이 걷히며 체력 +' || extra);
    END IF;
  END IF;
  v_pfx := v_pfx - 'bound'; v_fx := v_fx - 'evade' - 'thorns' - 'mirror';$q$
]);
