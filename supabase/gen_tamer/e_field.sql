select pg_temp.yh_fix('world_battle_action', array[
$q$pf_on boolean := coalesce(current_setting('yh.pf_resolve', true), '') = '1';$q$,
$q$pf_on boolean := coalesce(current_setting('yh.pf_resolve', true), '') = '1';
  pt jsonb; pgr jsonb; pr jsonb := public.world_pet_partner_rules(); pet_d int := 0; pet_brk int := 0; pet_x numeric; pet_eff boolean;$q$,

$q$  sk := public.world_skill_procs(uid);
$q$,
$q$  sk := public.world_skill_procs(uid);
  pt := st -> 'pet'; IF jsonb_typeof(pt) IS DISTINCT FROM 'object' THEN pt := NULL; END IF;
$q$,

$q$    ELSIF act = 'skill' AND c.job_key = 'artificer' THEN style := 'melee'; skill_name := public.world_job_skill_rules() -> 'artificer' ->> 'name';$q$,
$q$    ELSIF act = 'skill' AND c.job_key = 'artificer' THEN style := 'melee'; skill_name := public.world_job_skill_rules() -> 'artificer' ->> 'name';
    ELSIF act = 'skill' AND c.job_key = 'tamer' THEN style := 'ranged'; skill_name := public.world_job_skill_rules() -> 'tamer' ->> 'name';$q$,

$q$    ELSIF skill_name = '봉인술' THEN mul := mul * 1.1;$q$,
$q$    ELSIF skill_name = '봉인술' THEN mul := mul * 1.1;
    ELSIF act = 'skill' AND c.job_key = 'tamer' THEN mul := mul * (pr -> 'whistle' ->> 'mul')::numeric;$q$,

$q$    v_pfx := v_pfx || jsonb_build_object('opened', true);$q$,
$q$    IF pt IS NOT NULL AND a.current_hp > 0 AND NOT coalesce((v_pfx ->> 'pet_off')::boolean, false) THEN
      pgr := pr -> 'groups' -> (pt ->> 'grp');
      pet_x := ((pr -> 'jitter' ->> 0)::numeric + random() * (pr -> 'jitter' ->> 1)::numeric) * public.world_kind_mult(m.kind, CASE WHEN pr -> 'melee_vs' ? m.kind THEN 'melee' ELSE pt ->> 'style' END, 'tamer');
      IF act = 'skill' THEN pet_x := pet_x * (pr -> 'whistle' ->> 'pet')::numeric; END IF;
      IF pr -> 'fav_kinds' ? m.kind THEN
        IF coalesce((pt ->> 'rank8')::boolean, false) THEN pet_x := pet_x * (1 + (pr ->> 'rank8_pct')::numeric / 100); END IF;
        IF 'taming_x30' = ANY (sk) THEN pet_x := pet_x * (1 + (pr ->> 'x30_pct')::numeric / 100); END IF;
      END IF;
      IF 'taming_c43a' = ANY (sk) AND a.current_hp < a.max_hp * (pr ->> 'c43a_hp')::numeric THEN pet_x := pet_x * (pr ->> 'c43a_mul')::numeric; END IF;
      IF coalesce((v_fx ->> 'airborne')::boolean, false) AND pt ->> 'grp' <> 'peck' THEN pet_x := pet_x * CASE pt ->> 'style' WHEN 'melee' THEN 0.4 ELSE 0.9 END; END IF;
      IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN pet_x := pet_x * 1.2; END IF;
      pet_d := greatest(1, round((st ->> 'attack_raw')::numeric * (pt ->> 'mul')::numeric * pet_x - a.def * (pr ->> 'def_k')::numeric))::int;
      IF coalesce((v_fx ->> 'evade')::int, 0) > 0 AND pt ->> 'grp' <> 'peck' AND random() < 0.5 THEN pet_d := 0; END IF;
      IF pet_d > 0 AND coalesce((v_fx ->> 'barrier')::int, 0) > 0 THEN
        shield := (v_fx ->> 'barrier')::int - pet_d;
        IF shield > 0 THEN v_fx := v_fx || jsonb_build_object('barrier', shield); pet_d := 0; ELSE v_fx := v_fx - 'barrier'; pet_d := -shield; END IF;
      END IF;
      pet_eff := act = 'skill' OR (first_atk AND 'taming_x13' = ANY (sk)) OR pt ->> 'grp' = 'guard' OR random() < coalesce((pt ->> 'p')::numeric, 0);
      a.current_hp := greatest(0, a.current_hp - pet_d); ex_total := ex_total + pet_d;
      IF pt ->> 'grp' = 'charm' AND v_intent LIKE 'g:%' THEN pet_brk := pet_d; END IF;
      lines := lines || jsonb_build_array((pt ->> 'name') || '이(가) ' || (pgr ->> 'line') || CASE WHEN pet_d > 0 THEN ': ' || pet_d || ' 피해' ELSE '. 피해를 주지 못했다.' END);
      IF pet_eff AND a.current_hp > 0 THEN
        IF pt ->> 'grp' = 'guard' THEN v_pfx := v_pfx || jsonb_build_object('pet_ward', round((pgr ->> 'ward_base')::numeric + (pgr ->> 'ward_k')::numeric * (pt ->> 'pow')::numeric));
        ELSE v_fx := v_fx || jsonb_build_object(pgr ->> 'fx', greatest((pgr ->> 'n')::int, coalesce((v_fx ->> (pgr ->> 'fx'))::int, 0)));
          lines := lines || jsonb_build_array('「' || (pt ->> 'grp_name') || '」 ' || (pgr ->> 'fx_line') || '.'); END IF;
      END IF;
    END IF;
    v_pfx := v_pfx || jsonb_build_object('opened', true);$q$,

$q$IF dmg + ex_total + coalesce(nullif(current_setting('yh.pf_dmg', true), '')::int, 0) >= a.max_hp * brk THEN$q$,
$q$IF dmg + ex_total + pet_brk + coalesce(nullif(current_setting('yh.pf_dmg', true), '')::int, 0) >= a.max_hp * brk THEN$q$,

$q$        IF coalesce((v_pfx ->> 'roar')::int, 0) > 0 THEN mdmg := round(mdmg * 0.85); END IF;$q$,
$q$        IF coalesce((v_pfx ->> 'roar')::int, 0) > 0 THEN mdmg := round(mdmg * 0.85); END IF;
        IF coalesce((v_pfx ->> 'pet_ward')::int, 0) > 0 THEN mdmg := round(mdmg * (1 - (v_pfx ->> 'pet_ward')::numeric / 100)); v_pfx := v_pfx - 'pet_ward'; END IF;
        IF pt IS NOT NULL AND 'taming_c24b' = ANY (sk) AND hp < (pr ->> 'c24b_hp')::int AND NOT coalesce((v_pfx ->> 'pet_off')::boolean, false) THEN mdmg := round(mdmg * (1 - (pr ->> 'c24b_pct')::numeric / 100)); END IF;$q$,

$q$    IF ended IS NULL AND hp <= 0 THEN
      IF coalesce((inv ->> 'revival_charm')::int, 0) > 0$q$,
$q$    IF ended IS NULL AND hp <= 0 AND pt IS NOT NULL AND 'taming_c43b' = ANY (sk) AND NOT coalesce((v_pfx ->> 'pet_off')::boolean, false) THEN
      hp := 1; v_pfx := v_pfx || jsonb_build_object('pet_off', true); lines := lines || jsonb_build_array('「끝까지 곁에」 ' || (pt ->> 'name') || '이(가) 몸을 던져 쓰러질 일격을 막았다. 체력 1');
    END IF;
    IF ended IS NULL AND hp <= 0 THEN
      IF coalesce((inv ->> 'revival_charm')::int, 0) > 0$q$,

$q$    lines := lines || jsonb_build_array(m.monster_name || '을(를) 쓰러뜨렸다.');$q$,
$q$    lines := lines || jsonb_build_array(m.monster_name || '을(를) 쓰러뜨렸다.');
    IF pt IS NOT NULL THEN
      UPDATE public.world_pets SET win_n = CASE WHEN win_day = public.world_housing_today() THEN win_n + 1 ELSE 1 END, win_day = public.world_housing_today(),
        affinity = least((pr ->> 'aff_cap')::int, affinity + CASE WHEN win_day = public.world_housing_today() AND win_n >= (pr ->> 'win_day')::int THEN 0 ELSE (pr ->> 'win_aff')::int END)
       WHERE owner_id = uid AND pet_id = pt ->> 'id';
    END IF;$q$
]);
