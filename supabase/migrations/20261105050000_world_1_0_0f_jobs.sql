-- 1.0.0f — 퇴마관·월궁 사수 역할 맞바꿈(사용자 결정 2026-11-02): 술법은 한 방, 활은 꾸준히
--  · 퇴마진: ×1.7 → ×1.4 + 반드시 치명타(×1.5, 숙달 「멸마」면 ×2.0) — 한 방 2.1배(멸마 2.8배). 부적 퇴마진 ×2.1 → ×1.7(2.55배).
--  · 급소 사격: ×1.8 → ×1.4, 반드시 치명타 표시 없앰(원래 배율도 안 붙었음), 표식 2 → 3번(맞을 때마다 +25%) — 표식이 늘 걸려 꾸준히.
--  · 치명타: 퇴마관 술법 +6 없앰, 월궁 사수 원거리 +4.
--  · 퇴마관 기본 회피 4+레벨×0.3(영기·의지에는 회피가 안 붙어, 봉인술사 기본 방어처럼 — Lv5 약 10·Lv15 13·Lv35 19, 민첩을 찍는 월궁 사수 14·19·29의 2/3쯤)·달아나기 +8.
--  세 턴 한 바퀴(기술+평타 둘) 기대 피해: 퇴마관 약 +3%, 월궁 사수 약 ±0(표식이 다음 기술까지 이어짐).
lock table public.world_characters in access exclusive mode;

do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 2.1 ELSE 1.7 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor exo'; end if;
  d := replace(d, a, $b$CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 1.7 ELSE 1.4 END$b$);
  a := $a$ELSIF skill_name = '급소 사격' THEN mul := mul * 1.8; v_fx := v_fx || jsonb_build_object('marked', 2);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor aim'; end if;
  d := replace(d, a, $b$ELSIF skill_name = '급소 사격' THEN mul := mul * 1.4; v_fx := v_fx || jsonb_build_object('marked', 3);$b$);
  a := $a$crit := skill_name = '급소 사격' OR force_crit OR random() < cc;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor crit'; end if;
  d := replace(d, a, $b$crit := skill_name = '퇴마진' OR force_crit OR random() < cc;$b$);
  a := $a$IF crit AND skill_name IS DISTINCT FROM '급소 사격' THEN mul := mul * crit_x; END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor critx'; end if;
  d := replace(d, a, $b$IF crit THEN mul := mul * crit_x; END IF;$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_combat_stats(uuid,jsonb)'::regprocedure), E'\r\n', E'\n');
  a := $a$WHEN c.job_key = 'exorcist' AND style = 'magic' THEN 6 ELSE 0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cs crit'; end if;
  d := replace(d, a, $b$WHEN c.job_key = 'scout' AND style = 'ranged' THEN 4 ELSE 0 END$b$);
  a := $a$CASE WHEN c.job_key = 'scout' THEN 6 WHEN c.job_key = 'sealmaster' THEN 12 ELSE 0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cs eva'; end if;
  d := replace(d, a, $b$CASE WHEN c.job_key = 'scout' THEN 6 WHEN c.job_key = 'sealmaster' THEN 12 WHEN c.job_key = 'exorcist' THEN 4 + c.level * 0.3 ELSE 0 END$b$);
  a := $a$CASE WHEN c.job_key = 'scout' THEN 15 ELSE 0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cs flee'; end if;
  d := replace(d, a, $b$CASE WHEN c.job_key = 'scout' THEN 15 WHEN c.job_key = 'exorcist' THEN 8 ELSE 0 END$b$);
  execute d;
end $p$;

update public.world_skill_catalog set description = replace(description, '퇴마진의 피해가 ×1.7에서 ×2.1로', '퇴마진의 피해가 ×1.4에서 ×1.7로(반드시 치명타)')
 where skill_id = 'combo_exorcism_wardcraft';

-- 효과 점검(설명과 실제가 다른 것)
--  ① 응급 처방·「해독술」이 요화(나쁜 상태)를 「가장 먼저 끝나는 나쁜 상태」로 골라 끝내 버려 요화 단계를 앞당기던 것 — 요화·봉인은 빼고(해독 처방과 같게),
--     걷어 낸 것이 없으면 「걷어냈다」를 안 적음. 응급 처방 회복에 회복 보정(healing_pct)을 곱함(회복품·야전 처치와 같게).
--  ② 「약점 간파」 치명타 +10%가 세 번이 지나도 전투 끝까지 남던 것(focus > 0일 때만).
--  ③ 귀허: 「급소 드러내기」(암영 검객)가 「봉인 사슬」의 반격 막기·두 얼굴 묶기까지 걸던 것 — stagger 있는 기술(봉인 사슬)만.
--  ④ 귀허: 협동 회복 기술(응급 처치·맥 짚기·해독 침)에 응급 처치 단계 덤(봉연과 같게), 「파사 진언」 정신 +6(봉연과 같게).
--  ⑤ 귀허: 회복품을 동료에게 쓰면 의무관 ×1.4(현장 돌보기와 같게), 쓴 사람의 회복 보정(world_raid_stats.heal)도 곱함.
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$          WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' ORDER BY cs.expires_at LIMIT 1);
        IF FOUND THEN lines := lines || jsonb_build_array('「해독술」 나쁜 상태 하나를 풀었다.'); END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor detox'; end if;
  d := replace(d, a, $b$          WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' AND cs.status_key NOT IN ('yohwa', 'yohwa_seal') ORDER BY cs.expires_at LIMIT 1);
        IF FOUND THEN lines := lines || jsonb_build_array('「해독술」 나쁜 상태 하나를 풀었다.'); END IF;$b$);
  a := $a$    heal := least(40, 15 + c.vitality / 2 + c.willpower / 2); IF 'medicine_m50' = ANY (sk) THEN heal := round(heal * 1.5); END IF; IF 'combo_medicine_alchemy' = ANY (sk) THEN heal := heal + 10; END IF; hp := least(100, hp + heal);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor medheal'; end if;
  d := replace(d, a, $b$    heal := least(40, 15 + c.vitality / 2 + c.willpower / 2); IF 'medicine_m50' = ANY (sk) THEN heal := round(heal * 1.5); END IF; IF 'combo_medicine_alchemy' = ANY (sk) THEN heal := heal + 10; END IF;
    heal := round(heal * (1 + public.world_status_effect_total('healing_pct') / 100.0)); hp := least(100, hp + heal);$b$);
  a := $a$      WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' ORDER BY cs.expires_at LIMIT 1);
    lines := lines || jsonb_build_array('응급 처방: 체력 ' || heal || ' 회복, 나쁜 상태 하나를 걷어냈다.');$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor medcure'; end if;
  d := replace(d, a, $b$      WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' AND cs.status_key NOT IN ('yohwa', 'yohwa_seal') ORDER BY cs.expires_at LIMIT 1);
    lines := lines || jsonb_build_array('응급 처방: 체력 ' || heal || ' 회복' || CASE WHEN FOUND THEN ', 나쁜 상태 하나를 걷어냈다.' ELSE '.' END);$b$);
  a := $a$(CASE WHEN (v_pfx ? 'focus') THEN 0.1 ELSE 0 END)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor focus'; end if;
  d := replace(d, a, $b$(CASE WHEN coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN 0.1 ELSE 0 END)$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_raid_stats(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$  s := public.world_combat_stats(p_owner);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor rs'; end if;
  d := replace(d, a, $b$  s := public.world_combat_stats(p_owner) || jsonb_build_object('heal_pct', public.world_status_effect_total('healing_pct'));$b$);
  a := $a$'style', coalesce(s ->> 'style', 'melee'));$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor rs2'; end if;
  d := replace(d, a, $b$'style', coalesce(s ->> 'style', 'melee'), 'heal', coalesce((s ->> 'heal_pct')::numeric, 0));$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_gw_resolve(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$, 'block', coalesce((vbfx ->> 'block')::int, 0) + 1, 'block_by', m.owner_id); sealed := true;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gw expose'; end if;
  d := replace(d, a, $b$);
        if e ? 'stagger' then vbfx := vbfx || jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + 1, 'block_by', m.owner_id); sealed := true; end if;$b$);
  -- 협동 회복: 0.65 × (1 + 응급 처치 단계/100)
  a := $a$    e := sk.effect;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gw e'; end if;
  d := replace(d, a, $b$    e := sk.effect;
    if e ? 'amt' then
      e := e || jsonb_build_object('amt', round((e ->> 'amt')::int * (1 + coalesce((select (x.skill_progress -> 'first_aid' ->> 'rank')::int from public.world_characters x where x.owner_id = m.owner_id), 0) / 100.0)));
    end if;$b$);
  a := $a$      when 'gward' then update public.world_gw_members set fx = fx || public.world_cb_buff('gward', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gw gward'; end if;
  d := replace(d, a, a || $b$
        if coalesce((e ->> 'mind')::int, 0) > 0 then
          update public.world_characters set mental = least(100, mental + (e ->> 'mind')::int), updated_at = now() where owner_id = tgt;
        end if;$b$);
  a := $a$* case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end * case when m.job_key = 'medic' then 1.15 else 1 end;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gw item'; end if;
  d := replace(d, a, $b$* case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end * case when m.job_key = 'medic' then case when tgt = m.owner_id then 1.15 else 1.4 end else 1 end
             * (1 + coalesce((m.stats ->> 'heal')::numeric, 0) / 100.0);$b$);
  execute d;
end $p$;

-- 효과 점검 2차(기술 362개 · 칭호·소속·세력·환경)
--  ⑥ 방어 무너짐(해체의 일격·필살 계산·부적 접기)이 「2턴」이라 적혀 있는데 같은 턴에 1을 빼 다음 공격 한 번만 들던 것 → 3으로 넣어 두 번
--  ⑦ 수호신 보호막이 먼저 막으면 반격 자세·버팀 기세·반격 태세·바위 몸·받아치기가 안 나던 것 → 보호막에 막히기 전 피해로 판정
--  ⑧ 분석 계열이 암영 검객만 오르던 것 → 요괴가 수법 낌새를 보인 턴에 행동하면 누구나 분석 경험(acts.analysis)
--  ⑨ 제작 재료 돌려받기 덤 때문에 가방이 가득 차 있으면 제작 전체가 실패하던 것 → 자리가 없으면 그 덤만 건너뜀
--  ⑩ 요괴화(+30)·요화(단계×4) 주는 피해와 침식 80 「주는 피해 −10%」가 피해 % 상한 35 안에 묻히던 것 → 상한 밖에서 더함
--  ⑪ 북령맹 「원정 받는 피해 −20%」가 방어×1.2(실제 −6~−12%)이던 것 → 받는 피해 ×0.8
--  ⑫ 회복 보정(침식·날씨·소속·연리·세력·요화)이 쉬기·야영에 안 들던 것 → 체력·정신·영력에 곱함
--  ⑬ 야영 습격 확률에 요괴 조우 보정이 안 들던 것 → ×(1+조우%/100)
--  ⑭ 낚시 희귀 어종에 칭호 희귀품이 빠졌던 것
--  ⑮ 현장 토벌에서 침식이 100을 넘친 몫이 요화 판정(world_yohwa_overflow)에 안 들어가던 것
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  -- ⑥
  a := $a$v_fx := v_fx || jsonb_build_object('broken', 2); lines := lines || jsonb_build_array(m.monster_name || '의 방어가 무너졌다(2턴 동안 받는 피해 +20%).');$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor broken1'; end if;
  d := replace(d, a, $b$v_fx := v_fx || jsonb_build_object('broken', 3); lines := lines || jsonb_build_array(m.monster_name || '의 방어가 무너졌다(다음 두 번 받는 피해 +20%).');$b$);
  a := $a$IF 'sealing_x13' = ANY (sk) THEN v_fx := v_fx || jsonb_build_object('broken', 2);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor broken2'; end if;
  d := replace(d, a, $b$IF 'sealing_x13' = ANY (sk) THEN v_fx := v_fx || jsonb_build_object('broken', 3);$b$);
  -- ⑦
  a := $a$raw_m int; absorb int;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor decl'; end if;
  d := replace(d, a, $b$raw_m int; absorb int; m_pre int;$b$);
  a := $a$        -- 강기 보호막이 먼저 받는다
        IF mdmg > 0 AND$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor pre'; end if;
  d := replace(d, a, $b$        m_pre := mdmg;
        -- 강기 보호막이 먼저 받는다
        IF mdmg > 0 AND$b$);
  a := $a$        hp := greatest(0, hp - mdmg);
        IF mdmg > 0 THEN$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor hit'; end if;
  d := replace(d, a, $b$        hp := greatest(0, hp - mdmg);
        IF m_pre > 0 THEN$b$);
  a := $a$dmg := round(mdmg * 1.2 + c.strength * 0.5);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor riposte'; end if;
  d := replace(d, a, $b$dmg := round(m_pre * 1.2 + c.strength * 0.5);$b$);
  a := $a$extra := greatest(1, round(mdmg * 0.5)); a.current_hp := greatest(0, a.current_hp - extra); lines := lines || jsonb_build_array('「반격 태세」$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor c24b'; end if;
  d := replace(d, a, $b$extra := greatest(1, round(m_pre * 0.5)); a.current_hp := greatest(0, a.current_hp - extra); lines := lines || jsonb_build_array('「반격 태세」$b$);
  a := $a$extra := greatest(1, round(mdmg * 0.3)); hp := least(100, hp + extra); lines := lines || jsonb_build_array('「바위 몸」$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor rock'; end if;
  d := replace(d, a, $b$extra := greatest(1, round(m_pre * 0.3)); hp := least(100, hp + extra); lines := lines || jsonb_build_array('「바위 몸」$b$);
  -- ⑧ 낌새를 본 턴에 행동하면 분석 경험
  a := $a$  v_intent := coalesce(a.intent, 'strike');$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor intent'; end if;
  d := replace(d, a, a || $b$
  IF v_intent LIKE 'g%:%' AND act IN ('attack', 'guard', 'skill', 'item') THEN v_pfx := v_pfx || jsonb_build_object('u_an', coalesce((v_pfx ->> 'u_an')::int, 0) + 1); END IF;$b$);
  -- ⑮ 넘친 침식
  a := $a$IF v_intent = 'breach' THEN er := least(100, er + greatest(1, round(4 * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int)); END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor breach'; end if;
  d := replace(d, a, $b$IF v_intent = 'breach' THEN PERFORM public.world_yohwa_overflow(uid, er + greatest(1, round(4 * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int) - 100); er := least(100, er + greatest(1, round(4 * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int)); END IF;$b$);
  a := $a$IF g.erosion > 0 THEN er := least(100, er + greatest(1, round(g.erosion * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int)); END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gero'; end if;
  d := replace(d, a, $b$IF g.erosion > 0 THEN PERFORM public.world_yohwa_overflow(uid, er + greatest(1, round(g.erosion * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int) - 100); er := least(100, er + greatest(1, round(g.erosion * (1 + public.world_status_effect_total('erosion_pct') / 100.0))::int)); END IF;$b$);
  execute d;

  -- ⑨
  d := replace(pg_get_functiondef('public.world_craft_item(text)'::regprocedure), E'\r\n', E'\n');
  a := $a$if rf is not null then inv := jsonb_set(inv, array[rf], to_jsonb(coalesce((inv ->> rf)::int, 0) + 1), true);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 2 then raise exception '1.0.0f anchor refund'; end if;
  d := replace(d, a, $b$if rf is not null and public.world_bag_room(inv, rf, public.world_bag_limit(uid)) >= 1 then inv := jsonb_set(inv, array[rf], to_jsonb(coalesce((inv ->> rf)::int, 0) + 1), true);$b$);
  execute d;

  -- ⑩
  d := replace(pg_get_functiondef('public.world_combat_stats(uuid,jsonb)'::regprocedure), E'\r\n', E'\n');
  a := $a$pct := least(35, pct);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cap'; end if;
  d := replace(d, a, $b$-- 요화·요괴화의 피해와 침식 불이익은 상한 밖(상한에 묻혀 효과가 사라지지 않게)
  pct := least(35, pct - public.world_status_self(p_owner, 'combat_damage_pct') - public.world_erosion_effect('combat_damage_pct'))
         + (SELECT coalesce(sum((cat.effects ->> 'combat_damage_pct')::numeric * coalesce(cs.potency, 1)), 0) FROM public.world_character_statuses cs JOIN public.world_status_catalog cat USING (status_key)
             WHERE cs.owner_id = p_owner AND cs.expires_at > now() AND cs.status_key IN ('yohwa', 'yohwa_frenzy'))
         + least(0, public.world_erosion_effect('combat_damage_pct'))
         + public.world_status_self(p_owner, 'combat_damage_pct')
         - (SELECT coalesce(sum((cat.effects ->> 'combat_damage_pct')::numeric * coalesce(cs.potency, 1)), 0) FROM public.world_character_statuses cs JOIN public.world_status_catalog cat USING (status_key)
             WHERE cs.owner_id = p_owner AND cs.expires_at > now() AND cs.status_key IN ('yohwa', 'yohwa_frenzy'));$b$);
  execute d;

  -- ⑪
  d := replace(pg_get_functiondef('public.world_expedition_settle(uuid,integer)'::regprocedure), E'\r\n', E'\n');
  a := $a$  if c.major_faction_id = 'north_league' then defense := defense * 1.2; end if;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor north'; end if;
  d := replace(d, a, '');
  a := $a$* 100.0 / (100 + defense));$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 2 then raise exception '1.0.0f anchor north dmg'; end if;
  d := replace(d, a, $b$* 100.0 / (100 + defense) * case when c.major_faction_id = 'north_league' then 0.8 else 1 end);$b$);
  execute d;

  -- ⑫ ⑬
  d := replace(pg_get_functiondef('public.world_field_rest(text)'::regprocedure), E'\r\n', E'\n');
  a := $a$  IF NOT r.is_safe_zone THEN hp := hp * 2 / 3; mn := mn * 2 / 3; sp := sp * 2 / 3; er := er * 2 / 3; END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor rest'; end if;
  d := replace(d, a, a || $b$
  -- 회복 보정(침식·날씨·소속·연리·세력 등)을 체력·정신·영력에
  hp := greatest(0, round(hp * (1 + public.world_status_effect_total('healing_pct') / 100.0)))::int;
  mn := greatest(0, round(mn * (1 + public.world_status_effect_total('healing_pct') / 100.0)))::int;
  sp := greatest(0, round(sp * (1 + public.world_status_effect_total('healing_pct') / 100.0)))::int;$b$);
  a := $a$random() < least(0.45, 0.05 + r.danger_level * 0.03)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor ambush'; end if;
  d := replace(d, a, $b$random() < least(0.45, (0.05 + r.danger_level * 0.03) * greatest(0, 1 + public.world_status_effect_total('encounter_pct') / 100.0))$b$);
  execute d;

  -- ⑭
  d := replace(pg_get_functiondef('public.world_fish()'::regprocedure), E'\r\n', E'\n');
  a := $a$+ public.world_status_effect_total('rare_loot_pct')$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor fish'; end if;
  d := replace(d, a, a || $b$ + public.world_title_bonus('rare_loot_pct')$b$);
  execute d;
end $p$;

-- 기술 설명을 실제에 맞춤
update public.world_skill_catalog set description = replace(description, '받은 피해의 40%', '막기 전 피해의 40%') where skill_id = 'melee_g13';
update public.world_skill_catalog set description = description || ' (최대 +40)' where skill_id = 'guarding_c43b' and description not like '%최대 +40%';
update public.world_skill_catalog set description = replace(description, '탐색하거나 조사 지점을 살필 때', '탐색할 때') where skill_id = 'tracking_x36';
update public.world_skill_catalog set description = replace(replace(description, '확률 +5%', '확률 5% 더(비율)'), '확률이 +5%', '확률이 5% 더(비율)') where skill_id = 'analysis_hunter';
update public.world_skill_catalog set description = replace(description, '치명타 확률 +3%', '원거리 피해 +3% · 치명타 확률 +3%') where skill_id = 'ranged_steady' and description not like '%피해 +3%%';
update public.world_skill_catalog set description = replace(replace(description, '술법 공격마다', '술법이 적중할 때마다'), '술법 공격 때', '술법이 적중하면') where skill_id in ('medicine_c24b', 'exorcism_c30b');
update public.world_skill_catalog set description = replace(description, '봉인 피해', '술법 피해') where skill_id in ('sealing_script', 'sealing_domain');
update public.world_skill_catalog set skill_name = '숨죽인 걸음' where skill_id = 'tracking_x30' and skill_name = '기척 숨기기';

-- 효과 점검 3차(물품·장비·상태)
--  ⑯ 현장·파티 토벌에서 쓰는 물품이 물품 효과(use_fx)의 정신·침식·치료를 빠뜨리던 것(대환단 정신 20·심신 동요 치료 등) → world_item_fx로
--     정화 부적은 가방·정화·토벌 모두 침식 −18·정신 +6(우수품 ×1.15)으로 하나로(원정은 따로 −15·+5)
--  ⑰ 채집 도구의 희귀품이 상태 합에도 들어가 두 번 붙고 토벌·탐색·낚시까지 퍼지던 것, 부서진 도구도 덤이 붙던 것
--  ⑱ 동료 돌보기(world_party_use_item)로 싸우는 중인 동료를 턴 없이 치료하던 것 → 대상도 싸우는 중이면 거절
--  ⑲ 비경 호신부 마지막 원정에서 「비경 찾기」가 0이던 것(닳은 뒤에 굴림) → 닳기 전 값으로
--  ⑳ 귀허에서 회복품의 정신 회복이 빠졌던 것(반요 고약·대환단)
update public.world_item_catalog set use_fx = use_fx || '{"er": 18, "mn": 6}'::jsonb where item_id = 'ward_talisman';
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$raw_m int; absorb int; m_pre int;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor decl2'; end if;
  d := replace(d, a, $b$raw_m int; absorb int; m_pre int; fxi jsonb; fxq numeric;$b$);
  a := $a$      mn := least(100, mn + ceil(8 * (CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END))::int);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor ward'; end if;
  d := replace(d, a, '');
  a := $a$      lines := lines || jsonb_build_array('정화 부적을 태워 사기를 걷어냈다. 정신 +8');$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor wardline'; end if;
  d := replace(d, a, $b$      lines := lines || jsonb_build_array('정화 부적을 태워 사기를 걷어냈다.');$b$);
  a := $a$    IF 'first_aid_x30' = ANY (sk) AND NOT coalesce((v_pfx ->> 'swift')::boolean, false) THEN$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor itemfx'; end if;
  d := replace(d, a, $b$    -- 물품 효과의 정신·침식·치료(use_fx 한 원본, 체력·영력은 위에서 기술 보정과 함께)
    fxi := public.world_item_fx(public.world_item_base(it)); fxq := CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END;
    IF coalesce((fxi ->> 'mn')::numeric, 0) > 0 THEN mn := least(100, mn + ceil((fxi ->> 'mn')::numeric * fxq)::int); lines := lines || jsonb_build_array('정신 +' || ceil((fxi ->> 'mn')::numeric * fxq)::int); END IF;
    IF coalesce((fxi ->> 'er')::numeric, 0) > 0 THEN er := greatest(0, er - ceil((fxi ->> 'er')::numeric * fxq)::int); lines := lines || jsonb_build_array('침식 −' || ceil((fxi ->> 'er')::numeric * fxq)::int); END IF;
    IF jsonb_array_length(coalesce(fxi -> 'cures', '[]'::jsonb)) > 0 THEN
      UPDATE public.world_character_statuses SET expires_at = now() WHERE owner_id = uid AND expires_at > now()
        AND status_key IN (SELECT jsonb_array_elements_text(fxi -> 'cures')) AND status_key NOT IN ('yohwa', 'yohwa_seal');
    END IF;
$b$ || a);
  execute d;

  -- ⑰
  d := replace(pg_get_functiondef('public.world_gear_total(uuid,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$    AND NOT (e.slot = 'tool' AND p_key = 'gathering_bonus_pct')$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gtot'; end if;
  d := replace(d, a, $b$    AND NOT (e.slot = 'tool' AND p_key IN ('gathering_bonus_pct', 'rare_loot_pct'))$b$);
  execute d;
  d := replace(pg_get_functiondef('public.world_field_gather(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$coalesce((select (i.equipment_traits ->> 'rare_loot_pct')::numeric from public.world_item_catalog i where i.item_id = tool_id), 0)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor grare'; end if;
  d := replace(d, a, $b$coalesce((select (i.equipment_traits ->> 'rare_loot_pct')::numeric
        * CASE WHEN x.mx IS NULL THEN 1 WHEN coalesce(dr.durability, x.mx) <= 0 THEN 0 WHEN coalesce(dr.durability, x.mx) * 4 < x.mx THEN 0.8 ELSE 1 END
      from public.world_item_catalog i cross join lateral (select public.world_item_max_durability(i.item_id) as mx) x
      left join public.world_item_durability dr on dr.owner_id = uid and dr.item_id = i.item_id where i.item_id = tool_id), 0)$b$);
  execute d;

  -- ⑱
  d := replace(pg_get_functiondef('public.world_party_use_item(uuid,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$  if p_target is null or p_target = uid then raise exception '자기에게 쓸 때는 가방에서 쓰세요.'; end if;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor ptarget'; end if;
  d := replace(d, a, a || $b$
  IF EXISTS (SELECT 1 FROM public.world_active_encounters ae WHERE ae.owner_id = p_target AND ae.result IS NULL AND NOT ae.defeated AND NOT coalesce(ae.fled, false) AND ae.mlevel IS NOT NULL)
     OR EXISTS (SELECT 1 FROM public.world_pfight_members pm JOIN public.world_pfights pf ON pf.fight_id = pm.fight_id WHERE pm.owner_id = p_target AND pm.out_reason IS NULL AND pf.status = 'fight')
     OR EXISTS (SELECT 1 FROM public.world_gw_members gm JOIN public.world_gw_fights gf ON gf.fight_id = gm.fight_id WHERE gm.owner_id = p_target AND gf.status = 'fight')
     OR EXISTS (SELECT 1 FROM public.world_raid_members rm JOIN public.world_raids rr ON rr.raid_id = rm.raid_id WHERE rm.owner_id = p_target AND rr.status = 'fight' AND rm.left_at IS NULL AND (rm.out_until IS NULL OR rm.out_until > now())) THEN
    RAISE EXCEPTION '그 동료는 지금 싸우는 중입니다. 싸움이 끝난 뒤에 돌봐 주세요.';
  END IF;$b$);
  execute d;

  -- ⑲
  d := replace(pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure), E'\r\n', E'\n');
  a := $a$for eqr in select q2.slot, q2.item_id from public.world_character_equipment q2 where q2.owner_id = uid and q2.item_id ~ '^exg_[a-z]+_[12]$' loop$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor exgwear'; end if;
  d := replace(d, a, $b$perform set_config('yh.exg_trail', public.world_gear_total(uid, 'trail_find_pct')::text, true);
    $b$ || a);
  a := $a$(1 + public.world_gear_total(uid, 'trail_find_pct') / 100.0)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor exgtrail'; end if;
  d := replace(d, a, $b$(1 + coalesce(nullif(current_setting('yh.exg_trail', true), '')::numeric, public.world_gear_total(uid, 'trail_find_pct')) / 100.0)$b$);
  execute d;

  -- ⑳
  d := replace(pg_get_functiondef('public.world_gw_resolve(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$        update public.world_gw_members set hp = least(100, hp + round(d)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gwmn'; end if;
  d := replace(d, a, a || $b$
        update public.world_characters set mental = least(100, mental + ceil(coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'mn')::numeric, 0) * case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end)::int)
         where owner_id = tgt and coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'mn')::numeric, 0) > 0;$b$);
  execute d;
end $p$;

-- 효과 점검 4차(도움말·규칙)
--  ㉑ 원정 일찍 돌아오기가 「지난 회차만큼」인데 반올림이라 아직 안 지난 회차까지 셈 → 내림
--  ㉒ 반요촌 판매 칸이 한도 전체를 남은 한도로 보이던 것 → 반요촌에선 절반
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure), E'\r\n', E'\n');
  a := $a$else round(total_rounds * extract(epoch from now() - e.started_at) / (e.minutes * 60.0))::int end;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor early'; end if;
  d := replace(d, a, $b$else floor(total_rounds * extract(epoch from now() - e.started_at) / (e.minutes * 60.0))::int end;$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_shop_sell_status()'::regprocedure), E'\r\n', E'\n');
  a := $a$  cap := 2000 + public.world_affil_cap();$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor sellcap'; end if;
  d := replace(d, a, a || $b$
  if public.world_banyo_here(uid) then cap := cap / 2; end if;$b$);
  execute d;
end $p$;

-- 효과 점검 5차(남은 것)
--  ㉓ 요괴화 「민첩 +15%」·근맥 손상(agility_pct)이 기척 숨기기·조용히 살피기에 안 들던 것 → 능력치 계산과 같게 민첩에 곱함
--  ㉔ 닳은 채집 도구의 채집량·탐사 나침반·낚싯대가 1/4 아래 −20%·0이면 효과 없음을 안 따르던 것
--  ㉕ 원정 보급품 아낌 줄이 짐틀·은호패로 아껴도 「야행 탈 덕에」라 적던 것 → 실제 든 장비 이름
--  ㉖ 비경이 열려 있는 지역에서 비경 지도를 펼치면 늘지도 않고 지도만 사라지던 것 → 거절
--  ㉗ 동료 돌보기 회복 보정이 쓰는 사람(침식 불이익 포함) 기준이던 것 → 받는 사람 기준, 의무관 ×1.4는 쓰는 사람
--  ㉘ 세심단 뒤 능력치 조건이 안 맞는 장비가 그대로 장착돼 있던 것 → 벗김(가방에 남음), 원정 중엔 못 씀(환골탈태와 같게)
--  ㉙ 가방 물품 사용이 손으로 적은 목록만 받던 것 → 물품 효과(use_fx)가 있으면 씀(지금 목록과 같음)
--  ㉚ 자율 활동 수령이 기술 기록을 통째로 덮어쓰고 기술 경험 보정(training_xp_pct)을 안 받던 것 → 더해 넣고 보정
--  ㉛ 가방에서 쓰는 약에 맥 짚기 ×1.2·응급 처치 3단계 +10·야전 약방(야령초 22)이 빠졌던 것 → 토벌과 같게
--  ㉜ 잔향 추적 +10%가 올림이라 5→6·3→4가 되던 것 → 내림 + 나머지는 확률
--  ㉝ 호령이 피하거나 철벽으로 막은 공격에도 쓰여 버리던 것 → 실제로 맞을 때만
--  ㉞ 충분한 휴식·기력 저하·화상·탈진 설명의 「행동 효율」 → 실제(기술 경험·제작 품질)대로
do $p$
declare d text; a text;
begin
  -- ㉓
  d := replace(pg_get_functiondef('public.world_sneak_pct(uuid,integer,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$round(25 + c.agility * 0.8$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor sneakagi'; end if;
  d := replace(d, a, $b$round(25 + greatest(1, round(c.agility * (1 + public.world_status_self(c.owner_id, 'agility_pct') / 100.0))) * 0.8$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_field_search()'::regprocedure), E'\r\n', E'\n');
  a := $a$q_mode := least(0.5, (coalesce(c.agility, 0) + coalesce(c.perception, 0)) * 0.008);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor quietagi'; end if;
  d := replace(d, a, $b$q_mode := least(0.5, (greatest(1, round(coalesce(c.agility, 0) * (1 + public.world_status_self(uid, 'agility_pct') / 100.0))) + coalesce(c.perception, 0)) * 0.008);$b$);
  execute d;

  -- ㉔ 채집 도구
  d := replace(pg_get_functiondef('public.world_field_gather(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$tool_ln text;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gathdecl'; end if;
  d := replace(d, a, $b$tool_ln text; tool_m numeric := 1;$b$);
  a := $a$  select round(coalesce((i.equipment_traits ->> 'gathering_bonus_pct')::numeric, 0))::int, i.item_id into tool_bonus, tool_id from public.world_character_equipment e
    join public.world_item_catalog i on i.item_id = e.item_id where e.owner_id = uid and e.slot = 'tool';$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gathtool'; end if;
  d := replace(d, a, $b$  select CASE WHEN x.mx IS NULL THEN 1 WHEN coalesce(dd.durability, x.mx) <= 0 THEN 0 WHEN coalesce(dd.durability, x.mx) * 4 < x.mx THEN 0.8 ELSE 1 END,
         i.item_id into tool_m, tool_id from public.world_character_equipment e
    join public.world_item_catalog i on i.item_id = e.item_id cross join lateral (select public.world_item_max_durability(e.item_id) as mx) x
    left join public.world_item_durability dd on dd.owner_id = e.owner_id and dd.item_id = e.item_id
   where e.owner_id = uid and e.slot = 'tool';
  tool_m := coalesce(tool_m, 1);
  tool_bonus := round(coalesce((select (i.equipment_traits ->> 'gathering_bonus_pct')::numeric from public.world_item_catalog i where i.item_id = tool_id), 0) * tool_m)::int;$b$);
  a := $a$    tool_bonus := tool_bonus + 10;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gathten'; end if;
  d := replace(d, a, $b$    tool_bonus := tool_bonus + round(10 * tool_m)::int;$b$);
  execute d;

  -- ㉔ 탐사 나침반
  d := replace(pg_get_functiondef('public.world_explore_find_pct(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$select coalesce(max((i.equipment_traits ->> 'search_find_pct')::numeric), 0)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor explfind'; end if;
  d := replace(d, a, $b$select coalesce(max((i.equipment_traits ->> 'search_find_pct')::numeric
      * case when public.world_item_max_durability(e.item_id) is null then 1
             when coalesce(dd.durability, public.world_item_max_durability(e.item_id)) * 4 < public.world_item_max_durability(e.item_id) then 0.8 else 1 end), 0)$b$);
  execute d;

  -- ㉔ 낚싯대(단계 덤·입질·희귀·크기)
  d := replace(pg_get_functiondef('public.world_fish()'::regprocedure), E'\r\n', E'\n');
  a := $a$first boolean;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor fishdecl'; end if;
  d := replace(d, a, $b$first boolean; rod_m numeric := 1;$b$);
  a := $a$  sk := public.world_skill_procs(uid);
  if 'fishing_c24a' = any (sk)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor fishrodm'; end if;
  d := replace(d, a, $b$  rod_m := coalesce((select CASE WHEN x.mx IS NULL THEN 1 WHEN coalesce(dd.durability, x.mx) <= 0 THEN 0 WHEN coalesce(dd.durability, x.mx) * 4 < x.mx THEN 0.8 ELSE 1 END
      from (select public.world_fish_rod(uid) as it) ri cross join lateral (select public.world_item_max_durability(ri.it) as mx) x
      left join public.world_item_durability dd on dd.owner_id = uid and dd.item_id = ri.it), 1);
$b$ || a);
  a := $a$least(rod, case when 'combo_fishing_carpentry' = any (sk) then 3 else 2 end) * 0.06$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor fishbite'; end if;
  d := replace(d, a, a || $b$ * rod_m$b$);
  a := $a$least(rod, case when 'combo_fishing_carpentry' = any (sk) then 3 else 2 end) * 3$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor fishrare'; end if;
  d := replace(d, a, a || $b$ * rod_m$b$);
  a := $a$::numeric from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid))$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 3 then raise exception '1.0.0f anchor fishtraits'; end if;
  d := replace(d, a, $b$::numeric * rod_m from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid))$b$);
  execute d;

  -- ㉕
  d := replace(pg_get_functiondef('public.world_expedition_complete(boolean)'::regprocedure), E'\r\n', E'\n');
  a := $a$'야행 탈 덕에 보급품 ' || saved || '개를 아꼈습니다.'$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor supsave'; end if;
  d := replace(d, a, $b$coalesce((select string_agg(i.item_name, '·' order by i.item_name) from public.world_character_equipment eq join public.world_item_catalog i on i.item_id = eq.item_id
      where eq.owner_id = uid and (i.equipment_traits ->> 'supply_save_pct') ~ '^[0-9]+(\.[0-9]+)?$' and (i.equipment_traits ->> 'supply_save_pct')::numeric > 0), '장비')
    || ' 덕에 보급품 ' || saved || '개를 아꼈습니다.'$b$);
  execute d;

  -- ㉖ ㉙ ㉛
  d := replace(pg_get_functiondef('public.world_use_item(text)'::regprocedure), E'\r\n', E'\n');
  a := $a$IF rr.region_id IS NULL OR coalesce(rr.is_safe_zone, false) THEN RAISE EXCEPTION '비경 지도는 안전지대 밖의 지역에서 펼칠 수 있습니다.'; END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor trailmap'; end if;
  d := replace(d, a, a || $b$
    IF EXISTS (SELECT 1 FROM public.world_hidden_trails ht WHERE ht.owner_id = uid AND ht.region_id = rr.region_id AND ht.expires_at > now()) THEN
      RAISE EXCEPTION '%', format('%s의 비경이 아직 열려 있습니다(%s까지). 비경이 닫힌 뒤에 펼치세요.', rr.region_name,
        (SELECT to_char(max(ht.expires_at) AT TIME ZONE 'Asia/Seoul', 'HH24:MI') FROM public.world_hidden_trails ht WHERE ht.owner_id = uid AND ht.region_id = rr.region_id AND ht.expires_at > now()));
    END IF;$b$);
  a := $a$'haeryong_feast') THEN RAISE EXCEPTION '쓸 수 없는 물품입니다.'; END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor uselist'; end if;
  d := replace(d, a, $b$'haeryong_feast')
      AND NOT EXISTS (SELECT 1 FROM public.world_item_catalog ui WHERE ui.item_id = v_base AND ui.use_fx IS NOT NULL) THEN RAISE EXCEPTION '쓸 수 없는 물품입니다.'; END IF;$b$);
  a := $a$bname text; cbfx jsonb;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor usedecl'; end if;
  d := replace(d, a, $b$bname text; cbfx jsonb; v_sk text[];$b$);
  a := $a$  hp := round(ceil(hp * v_hq) * mul); mn := round(ceil(mn * v_hq) * mul); spg := round(ceil(spg * v_hq) * mul); er := ceil(er * v_hq)::int;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor useheal'; end if;
  d := replace(d, a, $b$  v_sk := public.world_skill_procs(uid);
  IF v_base = 'herb' AND 'combo_first_aid_herbalism' = ANY (v_sk) THEN hp := 22; END IF; -- 야전 약방
$b$ || a || $b$
  -- 토벌의 약과 같게: 맥 짚기 ×1.2(체력·영력 약), 응급 처치 3단계 +10(체력 약)
  IF v_base IN ('tonic', 'herbal_extract', 'herb', 'rejuv_pill', 'grand_pill') AND hp > 0 THEN
    IF 'medicine_c13b' = ANY (v_sk) THEN hp := round(hp * 1.2); END IF;
    IF coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) >= 3 THEN hp := hp + 10; END IF;
  END IF;
  IF v_base IN ('spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew') AND spg > 0 AND 'medicine_c13b' = ANY (v_sk) THEN spg := round(spg * 1.2); END IF;$b$);
  execute d;

  -- ㉗
  d := replace(pg_get_functiondef('public.world_party_use_item(uuid,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$  mul := (case when c.job_key = 'medic' then 1.4 else 1 end) * (1 + public.world_status_effect_total('healing_pct') / 100.0);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor pheal'; end if;
  d := replace(d, a, $b$  mul := (case when c.job_key = 'medic' then 1.4 else 1 end) * (1 + coalesce((public.world_raid_stats(p_target) ->> 'heal')::numeric, 0) / 100.0);$b$);
  execute d;

  -- ㉘
  d := replace(pg_get_functiondef('public.world_reset_stats()'::regprocedure), E'\r\n', E'\n');
  a := $a$c public.world_characters%rowtype; back int;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor rsdecl'; end if;
  d := replace(d, a, $b$c public.world_characters%rowtype; back int; off_items text[];$b$);
  a := $a$  if coalesce((c.inventory ->> 'reset_stats')::int, 0) < 1 then raise exception '세심단이 없습니다.'; end if;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor rsguard'; end if;
  d := replace(d, a, a || $b$
  if exists (select 1 from public.world_expeditions x where x.owner_id = uid and x.status = 'active') then raise exception '원정 중에는 세심단을 쓸 수 없습니다.'; end if;$b$);
  a := $a$  return jsonb_build_object('ok', true, 'refunded', back, 'content', format('능력치를 처음으로 되돌렸습니다. 포인트 %s점을 돌려받았습니다(지금 %s점).', back, c.stat_points + back));$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor rsret'; end if;
  d := replace(d, a, $b$  -- 되돌린 능력치로 조건이 안 맞는 장비는 벗는다(가방에 남음, world_equip_item과 같은 조건: 장신구는 가장 높은 능력치, 방어구는 짝 능력치)
  select array_agg(e.item_id) into off_items from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
    cross join (select to_jsonb(ch) as j, greatest(ch.strength, ch.agility, ch.vitality, ch.perception, ch.willpower, ch.spirit_affinity) as top
                  from public.world_characters ch where ch.owner_id = uid) s
   where e.owner_id = uid and exists (select 1 from jsonb_each(coalesce(i.required_stats, '{}'::jsonb)) rq
     where (case when i.category in ('hat', 'shoes', 'norigae', 'amulet', 'mask') then s.top
                 when i.category = 'armor' then greatest(coalesce((s.j ->> rq.key)::int, 0), coalesce((s.j ->> public.world_stat_pair(rq.key))::int, 0))
                 else coalesce((s.j ->> rq.key)::int, 0) end) < (rq.value #>> '{}')::numeric);
  if off_items is not null then
    delete from public.world_character_equipment e where e.owner_id = uid and e.item_id = any (off_items);
  end if;
  return jsonb_build_object('ok', true, 'refunded', back, 'unequipped', coalesce(to_jsonb(off_items), '[]'::jsonb),
    'content', format('능력치를 처음으로 되돌렸습니다. 포인트 %s점을 돌려받았습니다(지금 %s점).', back, c.stat_points + back)
      || case when off_items is not null then ' 능력치 조건이 안 맞는 장비는 벗었습니다: '
           || (select string_agg(i.item_name, '·') from public.world_item_catalog i where i.item_id = any (off_items)) || '.' else '' end);$b$);
  execute d;

  -- ㉚
  d := replace(pg_get_functiondef('public.world_claim_idle_activity()'::regprocedure), E'\r\n', E'\n');
  a := $a$   v_skill_xp:=v_gain;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor idlexp'; end if;
  d := replace(d, a, $b$   v_skill_xp:=round(v_gain*greatest(0.5,1+public.world_status_self(c.owner_id,'training_xp_pct')/100.0))::integer;$b$);
  a := $a$skill_progress=coalesce(skill_progress,'{}'::jsonb)||jsonb_build_object(v_skill,jsonb_build_object('xp',least(500000,v_old_skill_xp+v_skill_xp),'rank',least(50,1+floor(least(500000,v_old_skill_xp+v_skill_xp)/100.0)::integer)))$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 2 then raise exception '1.0.0f anchor idlesp5'; end if;
  d := replace(d, a, $b$skill_progress=public.world_skill_add(skill_progress,v_skill,v_skill_xp)$b$);
  a := $a$skill_progress=coalesce(skill_progress,'{}'::jsonb)||jsonb_build_object(v_skill,jsonb_build_object('xp',least(600000,v_old_skill_xp+v_skill_xp),'rank',least(50,1+floor(least(600000,v_old_skill_xp+v_skill_xp)/100.0)::integer)))$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor idlesp6'; end if;
  d := replace(d, a, $b$skill_progress=public.world_skill_add(skill_progress,v_skill,v_skill_xp)$b$);
  execute d;

  -- ㉜
  d := replace(pg_get_functiondef('public.world_event_char_apply()'::regprocedure), E'\r\n', E'\n');
  a := $a$sk_xp := ceil(sk_xp * 1.1)::int;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor scent'; end if;
  d := replace(d, a, $b$sk_xp := floor(sk_xp * 1.1)::int + case when random() < sk_xp * 1.1 - floor(sk_xp * 1.1) then 1 else 0 end;$b$);
  execute d;

  -- ㉝
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$        IF 'melee_c13b' = ANY (sk) AND NOT coalesce((v_pfx ->> 'cowed')::boolean, false) THEN mdmg := round(mdmg * 0.7); v_pfx := v_pfx || jsonb_build_object('cowed', true); lines := lines || jsonb_build_array('「호령」 기세에 눌린 첫 공격이 무뎌졌다.'); END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cowed'; end if;
  d := replace(d, a, $b$        IF 'melee_c13b' = ANY (sk) AND mdmg > 0 AND NOT coalesce((v_pfx ->> 'cowed')::boolean, false) THEN mdmg := round(mdmg * 0.7); v_pfx := v_pfx || jsonb_build_object('cowed', true, 'cowed_now', true); END IF;$b$);
  a := $a$        mdmg := greatest(0, mdmg);
$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cowed2'; end if;
  d := replace(d, a, a || $b$        -- 호령은 실제로 맞은 첫 공격에만(피하거나 철벽으로 막으면 다음 공격으로 넘어감)
        IF coalesce((v_pfx ->> 'cowed_now')::boolean, false) THEN
          IF mdmg > 0 THEN lines := lines || jsonb_build_array('「호령」 기세에 눌린 첫 공격이 무뎌졌다.'); ELSE v_pfx := v_pfx - 'cowed'; END IF;
          v_pfx := v_pfx - 'cowed_now';
        END IF;
$b$);
  execute d;
end $p$;

-- ㉚ 자율 수령 함수 주인이 새로 부르는 도우미
grant execute on function public.world_skill_add(jsonb, text, integer) to fn_owner_19181;
grant execute on function public.world_status_self(uuid, text) to fn_owner_19181;

-- ㉛ 설명: 맥 짚기는 가방에서 쓰는 약에도
update public.world_skill_catalog set description = '택일 기술(처방) · 회복품(약)의 회복량 +20%(토벌·가방)'
 where skill_id = 'medicine_c13b';
-- ㉞
update public.world_status_catalog set description = case status_key
    when 'well_rested' then '휴식을 마쳐 기술 경험이 더 붙고 제작 품질이 오른다.'
    when 'fatigue' then '기력이 부족해 기술 경험이 덜 붙고 제작 품질이 떨어진다.'
    when 'burned' then '화상이 아물지 않아 행동할 때 기혈이 줄고 제작 품질이 떨어진다.'
    when 'exhausted' then '기력이 다해 행동할 때 기혈이 줄고 제작 품질이 크게 떨어진다.' end
 where status_key in ('well_rested', 'fatigue', 'burned', 'exhausted');

-- 화면 점검(실제 화면 띄워 보기)
--  ㉟ 지금 서 있는 곳이 지도에서 「미답사 지역」으로 나오던 것(새 캐릭터는 출발지 방문 기록이 없음) → 지금 있는 지역은 방문한 것으로
--  ㊱ 싸울 수 없는 안전지대 9곳에 걸린 요괴 27마리가 도감 칸으로 잡혀 영영 못 채우던 것 → 도감 목록·전체 수에서 뺌(자료는 그대로)
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_map_snapshot()'::regprocedure), E'\r\n', E'\n');
  a := $a$v.n>0$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 4 then raise exception '1.0.0f anchor mapvisit'; end if;
  d := replace(d, a, $b$(v.n>0 OR r.region_id=current_region)$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_monster_codex_snapshot()'::regprocedure), E'\r\n', E'\n');
  a := $a$'total', (select count(*) from public.world_region_monsters m where m.kind = k.kind_key),$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor codextotal'; end if;
  d := replace(d, a, $b$'total', (select count(*) from public.world_region_monsters m join public.world_map_regions sr on sr.region_id = m.region_id where m.kind = k.kind_key and not coalesce(sr.is_safe_zone, false)),$b$);
  a := $a$from public.world_region_monsters m join public.world_map_regions r on r.region_id = m.region_id join$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor codexlist'; end if;
  d := replace(d, a, $b$from public.world_region_monsters m join public.world_map_regions r on r.region_id = m.region_id and not coalesce(r.is_safe_zone, false) join$b$);
  execute d;
end $p$;

-- 서버 문구 점검
--  ㊲ 요화로 쓰러지면 「구조·회생 부적으로 일어나」라고 안내했지만 실제로는 막혀 있음 → 봉인만 안내
--  ㊳ 요화 「귀령초로만 풀 수 있습니다」 → 귀령초나 안전지대 봉인(24시간)
--  ㊴ 동무 이름 뒤 조사 「라」 박음(「새끼 거북라」) → world_josa
--  ㊵ 요괴 도감 파훼법이 없는 행동 「봉인 제압」·「기믹」을 권하던 것 → 봉인술·술법·수법
--  ㊶ 적월교 거점 행동이 월식성을 요구하던 것(거점은 백골 장터, world_faction_home과 같게)
--  ㊷ 회생 부적 설명에 요화 예외, 꾸미기 「붉은 인장」 조건을 장 제목대로
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_yohwa_tick()'::regprocedure), E'\r\n', E'\n');
  a := $a$「안전지대 봉인」으로 24시간 해독을 받거나, 구조·회생 부적으로 일어나 귀령초로 풀 수 있습니다.$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor yohwa down'; end if;
  d := replace(d, a, $b$구조나 회생 부적으로는 일어날 수 없고, 「안전지대 봉인」(24시간)을 골라야 요화가 풀립니다.$b$);
  execute d;
  foreach a in array array['public.world_yohwa_onset()', 'public.world_yohwa_overflow(uuid,numeric)'] loop
    d := replace(pg_get_functiondef(a::regprocedure), E'\r\n', E'\n');
    if position('귀령초로만 풀 수 있습니다.' in d) = 0 then raise exception '1.0.0f anchor yohwa cure %', a; end if;
    execute replace(d, '귀령초로만 풀 수 있습니다.', '귀령초로 풀 수 있고, 요화로 쓰러지면 「안전지대 봉인」(24시간)으로 풀립니다.');
  end loop;

  d := replace(pg_get_functiondef('public.world_pet_grant(uuid,text,text,boolean)'::regprocedure), E'\r\n', E'\n');
  a := $a$' || nm || '라 대신$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor petjosa'; end if;
  d := replace(d, a, $b$' || public.world_josa(nm, '이라', '라') || ' 대신$b$);
  execute d;
end $p$;
update public.world_status_catalog set cure = '귀령초로 풀 수 있습니다. 요화로 쓰러지면 「안전지대 봉인」(24시간)으로 풀립니다.' where status_key = 'yohwa';
update public.world_item_catalog set description = description || ' (요화로 쓰러졌을 때는 쓸 수 없음)'
 where item_id in ('revival_charm', 'revival_charm_hq') and description not like '%요화%';
update public.world_region_monsters set mechanic_description =
  replace(replace(replace(replace(replace(replace(mechanic_description,
    '기믹 분석 후 제압·봉인을 사용하라', '수법을 살핀 뒤 봉인술이나 술법으로 맞서라'),
    '봉인 제압은 방어를 무시하는 추가 피해를 준다', '술법과 봉인술은 방어에 덜 막힌다'),
    '봉인 제압으로 결계를 무너뜨려라', '술법이나 봉인술로 결계를 무너뜨려라'),
    '봉인 제압이 효과적이며', '술법·봉인술이 잘 들며'),
    '봉인 제압', '봉인술·술법'),
    '기믹', '수법')
 where mechanic_description like '%봉인 제압%' or mechanic_description like '%기믹%';
update public.world_cosmetic_catalog set condition_text = '이야기 「붉은 인장의 실종」을 끝낸다' where cosmetic_key = 'fr_red_seal' and condition_text = '이야기 「붉은 인장」을 끝낸다';
update public.world_major_factions set base_region_id = 'bone_market' where faction_id = 'red_moon_cult' and base_region_id = 'red_moon_fort';

-- ㊸ 일지 › 답사 목록이 영역 id 알파벳순이라 새 캐릭터에게 Lv30 구중 금역이 맨 위에 나오던 것 → 영역 안 가장 낮은 레벨순
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef((select oid from pg_proc where proname = 'world_survey_overview' and pronamespace = 'public'::regnamespace limit 1)), E'\r\n', E'\n');
  a := $a$ORDER BY r.territory_id, r.min_level, r.region_name$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor survey order'; end if;
  d := replace(d, a, $b$ORDER BY (SELECT min(t.min_level) FROM public.world_map_regions t WHERE t.territory_id = r.territory_id), r.territory_id, r.min_level, r.region_name$b$);
  execute d;
end $p$;

update public.world_skill_catalog set description = '택일 기술 · 내가 구조한 동료가 체력 80으로 깨어난다(응급 처치 8단계 덤 +10은 따로)'
 where skill_id = 'first_aid_c43a';


-- ===== 혼자 도전 보정(supabase/pending/solo_aid_1_0_0f.sql) =====
-- solo_aid_1_0_0f.sql — 혼자 도전 보정(world_solo_aid) 다시 맞춤 + 결전 받는 피해를 귀허와 떼어 냄 (제안, 배포 안 함)
-- 기준 DB: 복제본 yh_fx6(운영 + 1.0.0e + 1.0.0f 후보). world_raid_action 본문은 그 1.0.0f 후보 본문에 한 줄만 바꾼 것 —
-- 운영에 1.0.0f 후보가 먼저 들어가지 않으면 이 본문을 그대로 쓰지 말고 같은 한 줄만 옮길 것.
-- 배포는 §17 11-1(버퍼 + owner_inherit_begin/end; world_raid_action 주인 fn_owner_field).
--
-- 시뮬 조건(로컬 복제 PostgreSQL 16, 정석 플레이):
--   빌드: 귀허 Lv38 · 결전 Lv36(협동 기술 넷이 모두 열리는 첫 레벨 — Lv35면 36단계 기술이 잠김), 소속 본부 직속,
--         능력치 3×(L−1)을 주 능력치 상한(직업 기본+1.5L) → 체질 → 나머지, 직업 계열·전투 숙련 = 레벨, 분석·막기·응급 처치 L/3,
--         6단계 장비 한 벌(무기 *_keen · 갑옷 갈래 · 관모·신·노리개·호신부·탈), 회복품 반요 고약(체력 70).
--   행동: 수법 정석(제 사슬·이름 부르기(혼자 30%)·의무관 해독 침·얼굴에 맞는 공격·물살 예고에 버티기·결전 휘두르기 예고에 방어·
--         끊지 못할 기운 모으기는 마지막 차례에 방어·사슬에 묶이면 공격 대신 기술), 협동 기술은 다시 쓰기·영력이 되면 우선순위대로,
--         체력 50↓ 회복 기술·40↓ 회복품(귀허 2·결전 5). 일부러 하는 실수 0%, 엔진 난수는 그대로.
--   시간: 귀허 고른 라운드 3초(수법 5초)·물러난 라운드 마감까지, 결전 행동 2초·쓰러지면 30초 — 시각 칸을 그만큼 당겨 엔진이 직접 15·20분 판정.
--
-- 결과(승/판, 진 판의 보스 남은 체력 평균)
--   직업      | 지금 값(7.7.7r) 귀허 · 결전             | 제안 값 귀허 · 결전 (조정 마지막 20판 + 확인 20판 = 40판)
--   호위 무사 | 10/10(쓰러짐 6.6)·0/10(남은 29%)        | 9/40(2.3/10, 남은 4~6%) · 10/40(2.5/10, 남은 4~6%)
--   월궁 사수 | 10/10(4.5)·10/10(10분)                 | 5/20(2.5/10, solo −25/−46 확인판) · 8/40(2.0/10, 남은 7%)
--   퇴마관    | 10/10(4.0)·10/10(12.5분)               | 9/40(2.3/10, 남은 8~10%) · 14/40(3.5/10, 남은 6%)
--   의무관    | 10/10(2.6)·0/10(남은 39%)              | 10/40(2.5/10, 남은 11%) · 8/40(2.0/10, 남은 9~10%)
--   봉인술사  | 10/10(7.1)·8/10                        | 13/40(3.3/10, 남은 9~11%) · 12/40(3.0/10, 남은 5%)
--   암영 검객 | 10/10(5.2)·0/10(남은 31%)              | 13/40(3.3/10, 남은 6~11%) · 8/20(4.0/10, final 34 확인판; 36에서 16/40)
--   (n=20이면 95% 구간 대략 ±20%p, n=40이면 ±15%p)
-- 2·4인 귀허(같은 값, 보정은 혼자만 붙음 — world_gw_start n=1 · world_raid_action count=1): 호위+퇴마 10/10·암영+의무 10/10·넷 10/10, 쓰러짐 0
--   → 넷 10/10은 맞지만 둘 5/10 목표보다 훨씬 쉬움(혼자 보정과 무관한 별도 과제).

-- ① 결전은 solo_guard 대신 final_guard(없으면 0)를 쓴다: 귀허에서 맞춘 받는 피해 보정이 결전으로 새지 않게
CREATE OR REPLACE FUNCTION public.world_raid_action(p_raid uuid, p_action text, p_skill text DEFAULT NULL::text, p_target uuid DEFAULT NULL::uuid, p_item text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rd public.world_raids%rowtype; mb public.world_raid_members%rowtype;
  tm public.world_raid_members%rowtype; sk public.world_coop_skills%rowtype; st jsonb; f jsonb; rfx jsonb; act text := lower(coalesce(p_action, ''));
  here text; sp int; inv jsonb; ammo text; mul numeric := 1; dmg int := 0; crit boolean := false; credit numeric := 0; h0 int; h1 int; amt int;
  n_act int; pick uuid; lv int; raw numeric; ph_mul numeric; k text; v jsonb; tgt uuid; nm text; newp int; tot numeric; acc numeric; rnd numeric; m record;
  bm text; bp numeric := 0; be text; bep numeric := 0; bc text; bcp numeric := 0; bcn text; ex numeric;
  bt int; tick boolean := true; bnow numeric; cbr jsonb; cbc jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if act not in ('attack', 'guard', 'item', 'coop') then raise exception '알 수 없는 행동입니다.'; end if;
  -- 7.7.7m: 내 1초 간격을 토벌 행(모두가 함께 씀)을 잠그기 전에 — 연타가 다른 참가자의 행동을 줄 세우지 않게
  perform public.world_rate_check('raid', uid, p_raid);
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if not found then raise exception '알 수 없는 토벌입니다.'; end if;
  if rd.status <> 'fight' then raise exception '지금은 싸울 수 없습니다.'; end if;
  if rd.ends_at <= now() then perform public.world_raid_settle(p_raid, false); return public.world_raid_snapshot(p_raid); end if;
  select * into mb from public.world_raid_members where raid_id = p_raid and owner_id = uid for update;
  if not found then raise exception '참가 신청한 조사원만 싸울 수 있습니다. 진행은 관전으로 볼 수 있습니다.'; end if;
  if mb.last_action_at is not null and mb.last_action_at > now() - interval '1 second' then raise exception '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.'; end if;
  if mb.left_at is not null then raise exception '토벌에서 나왔습니다. 「다시 참가」하면 이어서 싸울 수 있습니다.'; end if;
  if mb.out_until is not null and mb.out_until > now() then
    raise exception '물러나 숨을 고르는 중입니다(%초 뒤 돌아옴).', ceil(extract(epoch from mb.out_until - now())); end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태입니다.'; end if;
  select region_id into here from public.world_map_regions where region_name = c.location;
  if here is distinct from rd.region_id then raise exception '토벌이 벌어진 곳에 있어야 합니다.'; end if;
  if exists (select 1 from public.world_expeditions where owner_id = uid and status = 'active') then raise exception '원정 중에는 싸울 수 없습니다.'; end if;
  -- 토벌 보강 6.1.1
  if c.travel_destination is not null then raise exception '이동 중에는 싸울 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities where owner_id = uid and status = 'active') then raise exception '자율 활동 중에는 싸울 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false) and a.mlevel is not null) then
    raise exception '진행 중인 요괴 전투를 먼저 끝내세요.'; end if;

  st := public.world_raid_stats(uid);
  f := mb.fx; rfx := rd.fx; sp := c.spiritual_power; inv := coalesce(c.inventory, '{}'::jsonb);
  if mb.out_until is not null then mb.out_until := null;
    -- 결전: 쉬다가 돌아오면 체력 30(귀허와 같게 — 회복품이 셋뿐이라 체력 1로 돌아오면 곧바로 다시 쓰러진다)
    if rd.kind = 'final' and c.health < 30 then c.health := 30; update public.world_characters set health = 30, updated_at = now() where owner_id = uid; end if;
  end if;

  if act = 'attack' then
    -- 무기 소모: 근접 기력 2·술법 영력 3·원거리 한 발, 없으면 피해 절반
    if st ->> 'style' = 'magic' then if sp >= 2 then sp := sp - 2; else mul := mul * 0.5; end if;
    elsif st ->> 'style' = 'ranged' then
      ammo := public.world_ammo_of(uid);
      if ammo is not null and coalesce((inv ->> ammo)::int, 0) >= 1 then inv := public.world_inv_add(inv, ammo, -1); if (inv ->> ammo)::int <= 0 then inv := inv - ammo; end if;
      else mul := mul * 0.5; end if;
    else if sp >= 2 then sp := sp - 2; else mul := mul * 0.5; end if; end if;
    cbr := public.world_cb_attack(st, f, rfx, 0.85, 0.3);
    f := cbr -> 'fx'; rfx := cbr -> 'bfx'; crit := (cbr ->> 'crit')::boolean;
    if rd.kind = 'final' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then
      mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_dmg')::numeric, (public.world_solo_aid(c.job_key) ->> 'solo_dmg')::numeric, 0) / 100.0);
    elsif rd.kind = 'final' then mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_all')::numeric, 0) / 100.0); end if;
    dmg := greatest(1, round((cbr ->> 'd')::numeric * mul))::int;
    rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - dmg); mb.dmg := mb.dmg + dmg; credit := 0;
    -- 늘려 준 몫은 건 사람에게(공용 world_cb_boost_credits), 남은 몫이 내 기여
    for cbc in select * from jsonb_array_elements(public.world_cb_boost_credits(dmg, crit, cbr -> 'src', uid, (st ->> 'crit')::numeric)) loop
      if cbc ->> 2 = 'dmg' then credit := (cbc ->> 1)::numeric; else perform public.world_raid_credit(p_raid, (cbc ->> 0)::uuid, (cbc ->> 1)::numeric, 'boost'); end if;
    end loop;
    if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,got}', to_jsonb((rfx -> 'charge' ->> 'got')::int + dmg)); end if;
    perform public.world_raid_say(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.');
  elsif act = 'guard' then
    f := f || jsonb_build_object('guard', 1); mb.guarded := mb.guarded + 1;
    perform public.world_raid_say(p_raid, 'guard', mb.name || ' — 방어 태세를 갖췄습니다.');
  elsif act = 'item' then
    -- 물품은 평소 쓰는 길(world_use_item)을 그대로 거친다
    update public.world_characters set spiritual_power = sp where owner_id = uid;
    h0 := c.health;
    perform set_config('yh.raid_item', '1', true);
    perform public.world_use_item(p_item);
    perform set_config('yh.raid_item', '', true);
    select * into c from public.world_characters where owner_id = uid;
    sp := c.spiritual_power; inv := coalesce(c.inventory, '{}'::jsonb); h1 := c.health;
    if rd.kind = 'final' and h1 > h0 then
      if mb.items_used >= 5 then raise exception '결전에서는 체력 회복품을 한 싸움에 다섯 개까지만 쓸 수 있습니다.'; end if;
      mb.items_used := mb.items_used + 1;
    end if;
    mb.heal := mb.heal + greatest(0, h1 - h0); credit := greatest(0, h1 - h0);
    perform public.world_raid_say(p_raid, 'item', mb.name || ' — ' || coalesce((select item_name from public.world_item_catalog where item_id = p_item), '물품') || '을(를) 썼습니다' || case when h1 > h0 then '(체력 +' || (h1 - h0) || ')' else '' end || '.');
  else
    select * into sk from public.world_coop_skills where skill_id = p_skill;
    if not found or sk.job_key <> c.job_key then raise exception '쓸 수 없는 협동 기술입니다.'; end if;
    if coalesce(c.combat_rank, 1) < sk.unlock_rank then raise exception '전투 숙련 %단계에 열리는 기술입니다.', sk.unlock_rank; end if;
    if mb.cd ? sk.skill_id and (mb.cd ->> sk.skill_id)::timestamptz > now() then
      raise exception '%은(는) %초 뒤에 다시 쓸 수 있습니다.', sk.skill_name, ceil(extract(epoch from (mb.cd ->> sk.skill_id)::timestamptz - now())); end if;
    if sp < sk.cost then raise exception '영력이 모자랍니다(필요 %).', sk.cost; end if;
    tgt := case when sk.target = 'self' then uid else coalesce(p_target, uid) end;
    if sk.target = 'ally' then
      select * into tm from public.world_raid_members where raid_id = p_raid and owner_id = tgt for update;
      if not found then raise exception '이 토벌에 참가한 동료에게만 쓸 수 있습니다.'; end if;
      if sk.effect ->> 'type' = 'revive' then
        if tm.out_until is null then raise exception '물러난 동료에게만 쓸 수 있습니다.'; end if;
        if tm.left_at is not null then raise exception '토벌에서 나간 동료입니다.'; end if;
      elsif tm.out_until is not null and tm.out_until > now() then raise exception '물러난 동료에게는 쓸 수 없습니다.'; end if;
    end if;
    sp := sp - sk.cost;
    mb.cd := mb.cd || jsonb_build_object(sk.skill_id, now() + make_interval(secs => sk.cooldown_s));
    mb.coop := mb.coop + 1; credit := 0;
    k := sk.effect ->> 'type'; v := sk.effect;
    -- 자신에게 거는 효과는 아래에서 mb.fx(f)에 바로 쓴다
    if sk.target in ('ally', 'self') and tgt = uid then
      if k in ('ward', 'might', 'evade', 'gward', 'crit_next') then f := f || public.world_cb_buff(k, v, uid);
      elsif k = 'shield' then f := f || jsonb_build_object('shield', coalesce((f ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid);
      elsif k = 'cleanse_heal' then f := f - 'bound';
      elsif k = 'cover' then raise exception '자기 자신은 대신 막을 수 없습니다.';
      end if;
    elsif sk.target = 'ally' then
      update public.world_raid_members set fx = case
          when k in ('ward', 'might', 'evade', 'gward', 'crit_next') then fx || public.world_cb_buff(k, v, uid)
          when k = 'shield' then fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid)
          when k = 'cleanse_heal' then fx - 'bound'
          when k = 'cover' then fx || jsonb_build_object('cover', jsonb_build_object('by', uid, 'until', now() + make_interval(secs => (v ->> 'secs')::int)))
          else fx end,
        out_until = case when k = 'revive' then least(out_until, now()) else out_until end
       where raid_id = p_raid and owner_id = tgt;
    end if;
    if k in ('heal', 'cleanse_heal', 'revive', 'sp', 'gward') then
      amt := case k when 'revive' then (v ->> 'hp')::int when 'sp' then 0 when 'gward' then 0
             else round((v ->> 'amt')::int * (1 + coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) / 100.0)) end;
      -- 결전: 회복 기술은 절반(회복품을 다섯으로 묶어 회복 기술이 승패를 혼자 정하던 것 — 회복 직업 없는 조가 해볼 만하게)
      if rd.kind = 'final' and k in ('heal', 'cleanse_heal') then amt := ceil(amt * 0.5); end if;
      if k = 'revive' then
        select health into h1 from public.world_characters where owner_id = tgt;
        update public.world_characters set health = greatest(health, amt), updated_at = now() where owner_id = tgt;
        amt := greatest(0, amt - coalesce(h1, 0));
      elsif k = 'sp' then
        if tgt <> uid then perform public.world_raid_credit(p_raid, uid, (select greatest(0, least((v ->> 'amt')::int, 100 - x.spiritual_power)) from public.world_characters x where x.owner_id = tgt) * coalesce((st ->> 'attack')::numeric, 0) * 0.05, 'boost'); end if;
        update public.world_characters set spiritual_power = least(100, spiritual_power + (v ->> 'amt')::int), updated_at = now() where owner_id = tgt and owner_id <> uid;
        if tgt = uid then sp := least(100, sp + (v ->> 'amt')::int); end if;
      elsif k = 'gward' then
        update public.world_characters set mental = least(100, mental + coalesce((v ->> 'mind')::int, 0)), updated_at = now() where owner_id = tgt;
      else
        if tgt = uid then
          select health into h0 from public.world_characters where owner_id = uid;
        end if;
        select health into h1 from public.world_characters where owner_id = tgt;
        update public.world_characters set health = least(100, health + amt), updated_at = now() where owner_id = tgt and health > 0;
        amt := case when coalesce(h1, 0) > 0 then greatest(0, least(100, h1 + amt) - h1) else 0 end;
      end if;
      if amt > 0 then mb.heal := mb.heal + amt; perform public.world_raid_credit(p_raid, uid, amt, case when tgt = uid then 'heal_self' else 'heal' end); end if;
    end if;
    if k = 'heal_all' then
      amt := round((v ->> 'amt')::int * (1 + coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) / 100.0));
      if rd.kind = 'final' then amt := ceil(amt * 0.5); end if; -- heal_all final half
      select sum(greatest(0, least(100, ch.health + amt) - ch.health)) into acc from public.world_characters ch join public.world_raid_members x on x.owner_id = ch.owner_id
       where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and ch.health > 0;
      update public.world_characters ch set health = least(100, ch.health + amt), updated_at = now()
        from public.world_raid_members x where x.raid_id = p_raid and x.owner_id = ch.owner_id and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and ch.health > 0;
      get diagnostics n_act = row_count;
      mb.heal := mb.heal + coalesce(acc, 0)::int; perform public.world_raid_credit(p_raid, uid, coalesce(acc, 0), 'heal');
    elsif k in ('ward_all', 'might_all', 'crit_all', 'rally', 'resonance') then
      update public.world_raid_members x set fx = x.fx || public.world_cb_buff(k, v, uid)
       where x.raid_id = p_raid and x.owner_id <> uid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id);
      f := f || public.world_cb_buff(k, v, uid);
    elsif k = 'taunt' then
      f := f || public.world_cb_buff('taunt', v, uid);
    elsif k = 'expose' then
      rfx := rfx || jsonb_build_object('expose', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n', 'by', uid), 'stagger', coalesce((rfx ->> 'stagger')::int, 0) + coalesce((v ->> 'stagger')::int, 0), 'stagger_by', uid);
    elsif k = 'delay' then
      rfx := rfx || jsonb_build_object('stagger', coalesce((rfx ->> 'stagger')::int, 0) + (v ->> 'n')::int, 'stagger_by', uid);
      if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int + 3));
        if (rfx -> 'charge' ->> 'until') is not null then rfx := jsonb_set(rfx, '{charge,until}', to_jsonb((rfx -> 'charge' ->> 'until')::numeric + 6)); end if; end if;
    elsif k = 'smoke' then
      rfx := rfx || jsonb_build_object('smoke', jsonb_build_object('miss', v -> 'miss', 'n', v -> 'n', 'by', uid));
    elsif k = 'break' then
      rfx := rfx || jsonb_build_object('break', v -> 'pct', 'break_by', uid);
    end if;
    select name into nm from public.world_raid_members where raid_id = p_raid and owner_id = tgt;
    perform public.world_raid_say(p_raid, 'coop', mb.name || ' — [' || sk.skill_name || '] ' ||
      case when sk.target = 'ally' and tgt <> uid then nm || '에게 · ' else '' end || sk.exp_text || '.');
  end if;

  -- 내 행동을 먼저 적고(체력·영력·가방), 보스의 반격은 그 뒤에 실제 캐릭터에 쓴다
  update public.world_characters set spiritual_power = sp, inventory = inv, updated_at = now() where owner_id = uid;
  mb.acts := mb.acts + 1; mb.last_action_at := now();
  mb.contrib := mb.contrib + credit * case when rd.kind = 'world' then least(1, mb.level / 30.0) else 1 end;
  update public.world_raid_members set fx = f, cd = mb.cd, dmg = mb.dmg, heal = mb.heal, coop = mb.coop, guarded = mb.guarded, acts = mb.acts,
    contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = case when rd.kind = 'final' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then st || (public.world_solo_aid(c.job_key) - 'solo_guard' - 'final_guard') || jsonb_build_object('solo_guard', coalesce(public.world_solo_aid(c.job_key) -> 'final_guard', '0'::jsonb)) else st end, items_used = mb.items_used where raid_id = p_raid and owner_id = uid;
  perform public.world_raid_credit(p_raid, uid, credit, case act when 'attack' then 'dmg' when 'item' then 'heal_self' end);
  if act = 'coop' then perform public.world_raid_credit(p_raid, uid, 1, 'skill'); end if;

  rd.turn := rd.turn + 1;
  if rd.hp <= 0 then
    update public.world_raids set hp = 0, turn = rd.turn, fx = rfx, updated_at = now() where raid_id = p_raid;
    perform public.world_raid_say(p_raid, 'win', mb.name || '의 일격에 ' || rd.boss_name || '이(가) 무너졌습니다.');
    perform public.world_raid_settle(p_raid, true);
    return public.world_raid_snapshot(p_raid);
  end if;
  newp := case when rd.hp * 100 <= rd.max_hp * 40 then 3 when rd.hp * 100 <= rd.max_hp * 70 then 2 else 1 end;
  if newp > rd.phase then
    rd.phase := newp;
    perform public.world_raid_say(p_raid, 'phase', case newp when 2 then rd.boss_name || '의 사슬이 풀리며 움직임이 사나워집니다(2단계).'
                                                    else rd.boss_name || '이(가) 봉연의 기운을 끌어모으기 시작합니다(3단계).' end);
  end if;
  ph_mul := case rd.phase when 1 then 1 when 2 then 1.15 else 1.3 end * case when rd.kind = 'final' then 1.1 else 1 end;
  select count(*) into n_act from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id
   where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' and ch.health > 1;

  -- 7.7.6: 서버 보스는 큰 수법을 2초 박자로 센다(결전은 차례 그대로)
  if rd.kind = 'world' then
    bnow := extract(epoch from now()); tick := false;
    if not (rfx ? 'beat_at') then rfx := rfx || jsonb_build_object('beat', 0, 'beat_at', bnow);
    elsif bnow >= (rfx ->> 'beat_at')::numeric + 2 then
      rfx := rfx || jsonb_build_object('beat', (rfx ->> 'beat')::int + 1, 'beat_at', bnow); tick := true;
    end if;
    bt := (rfx ->> 'beat')::int;
  else bt := rd.turn; end if;

  if coalesce((rfx ->> 'stagger')::int, 0) > 0 then
    rfx := case when (rfx ->> 'stagger')::int <= 1 then rfx - 'stagger' else jsonb_set(rfx, '{stagger}', to_jsonb((rfx ->> 'stagger')::int - 1)) end;
    if rfx ? 'stagger_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'stagger_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 0.7 * (least(0.4, 0.8 / greatest(1, n_act)) + 0.8 * greatest(1, n_act) / 7.0), 'guard'); end if;
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 휘청여 반격하지 못합니다.');
  elsif rfx ? 'charge' then
    rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int - case when tick then 1 else 0 end));
    if (rfx -> 'charge' ->> 'got')::int >= (rfx -> 'charge' ->> 'need')::int then
      rfx := rfx - 'charge';
      perform public.world_raid_say(p_raid, 'boss', '몰아친 공격에 ' || rd.boss_name || '의 기운 모으기가 끊겼습니다.');
    elsif (case when (rfx -> 'charge' ->> 'until') is not null then extract(epoch from now()) >= (rfx -> 'charge' ->> 'until')::numeric else (rfx -> 'charge' ->> 'left')::int <= 0 end) then
      rfx := rfx - 'charge';
      perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 모은 봉연의 기운을 터뜨립니다!');
      for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' loop
        raw := public.world_raid_boss_base(p_raid, rd.kind, m.level) * ph_mul * 2.2 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
        perform public.world_raid_hit(p_raid, m.owner_id, raw, 'burst');
      end loop;
      if rfx ? 'break_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'break_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 2.2 * (rfx ->> 'break')::numeric / 100.0 * 0.7 * greatest(1, n_act), 'guard'); end if;
      rfx := rfx - 'break' - 'break_by';
    end if;
  elsif tick and rd.phase = 3 and bt % 11 = 0 then
    rfx := rfx || jsonb_build_object('charge', jsonb_build_object('left', case when rd.kind = 'world' then 4 else 5 + greatest(1, n_act) end, 'until', case when rd.kind = 'world' then round(extract(epoch from now())::numeric + 8, 2) end, 'need', public.world_raid_charge_need(p_raid, rd.kind, rd.max_hp), 'got', 0));
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 기운을 모읍니다. ' || public.world_raid_charge_need(p_raid, rd.kind, rd.max_hp) || ' 넘게 몰아쳐 끊거나, 방어하세요!');
  elsif tick and bt % 7 = 0 then
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 크게 휘둘러 모두를 덮칩니다.');
    for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' loop
      raw := public.world_raid_boss_base(p_raid, rd.kind, m.level) * ph_mul * 0.8 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
      perform public.world_raid_hit(p_raid, m.owner_id, raw, 'slam');
    end loop;
    if rfx ? 'break_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'break_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 0.8 * (rfx ->> 'break')::numeric / 100.0 * 0.7 * greatest(1, n_act), 'guard'); end if;
    rfx := rfx - 'break' - 'break_by';
  elsif tick and rd.phase >= 2 and bt % 5 = 0 then
    select x.owner_id, x.name into pick, nm from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) order by random() limit 1;
    if pick is not null then
      update public.world_raid_members set fx = fx || '{"bound":1}'::jsonb where raid_id = p_raid and owner_id = pick;
      perform public.world_raid_say(p_raid, 'boss', '봉연의 사슬이 ' || nm || '을(를) 휘감습니다(다음 공격 절반).');
    end if;
  elsif random() < least(0.4, 0.8 / greatest(1, n_act)) then
    -- 표적: 이목^1.3에 비례(호법 신장은 이목을 더한다)
    select x.owner_id, x.level into pick, lv from public.world_raid_members x
     where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds'
     order by public.world_cb_pick_key((x.stats ->> 'pres')::numeric + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)) limit 1;
    if pick is not null then
      if rfx ? 'smoke' and random() * 100 < (rfx -> 'smoke' ->> 'miss')::numeric then
        perform public.world_raid_credit(p_raid, nullif(rfx -> 'smoke' ->> 'by', '')::uuid, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul * 0.7, 'guard');
        perform public.world_raid_say(p_raid, 'miss', '연막 속에서 ' || rd.boss_name || '의 공격이 빗나갔습니다.');
      else
        perform public.world_raid_hit(p_raid, pick, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul, 'single');
      end if;
      if rfx ? 'smoke' then rfx := case when (rfx -> 'smoke' ->> 'n')::int <= 1 then rfx - 'smoke' else jsonb_set(rfx, '{smoke,n}', to_jsonb((rfx -> 'smoke' ->> 'n')::int - 1)) end; end if;
    end if;
  end if;

  -- 결전에서 모두 물러나면 보스가 기운을 되찾는다
  if rd.kind = 'final' and not exists (select 1 from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id)) then
    rd.hp := least(rd.max_hp, rd.hp + round(rd.max_hp * 0.015));
    perform public.world_raid_say(p_raid, 'boss', '모두 물러난 사이 ' || rd.boss_name || '이(가) 기운을 되찾습니다(체력 +1.5%).');
  end if;
  rd.intent := case when rfx ? 'charge' then '기운을 모으는 중 — ' || case when rd.kind = 'world' then greatest(0, ceil(coalesce((rfx -> 'charge' ->> 'until')::numeric, extract(epoch from now()) + (rfx -> 'charge' ->> 'left')::int * 2) - extract(epoch from now())))::int || '초' else '남은 ' || (rfx -> 'charge' ->> 'left') || '번' end || ' 안에 ' || greatest(0, (rfx -> 'charge' ->> 'need')::int - (rfx -> 'charge' ->> 'got')::int) || ' 더 몰아치면 끊긴다'
                    when (bt + 1) % 7 = 0 then '크게 휘두를 낌새가 보인다 — 방어하라'
                    when rd.phase >= 2 and (bt + 1) % 5 = 0 then '사슬이 꿈틀거린다'
                    else null end;
  update public.world_raids set hp = rd.hp, turn = rd.turn, phase = rd.phase, fx = rfx, intent = rd.intent, updated_at = now() where raid_id = p_raid;
  return public.world_raid_snapshot(p_raid);
end $function$

;

-- ② 혼자 도전 보정 값
create or replace function public.world_solo_aid(p_job text)
 returns jsonb language sql immutable as $function$
  -- 혼자 도전 보정(1.0.0f): 협동 기술·6단계 장비 한 벌로 정석 플레이 시뮬(직업마다 귀허·결전 20~40판) → 혼자 2~3/10
  -- solo_dmg·solo_guard는 귀허, final_dmg·final_guard는 결전(final_guard 없으면 0 — world_raid_action)
  select case p_job
    when 'artificer'  then '{"solo_dmg": -38, "solo_guard": -22, "final_dmg": -2}'
    when 'scout'      then '{"solo_dmg": -25, "solo_guard": -46, "final_dmg": -47}'
    when 'exorcist'   then '{"solo_dmg": -42, "solo_guard": -17, "final_dmg": 13}'
    when 'medic'      then '{"solo_dmg": -21, "solo_guard": -46, "final_dmg": 18}'
    when 'sealmaster' then '{"solo_dmg": -42, "solo_guard": -32, "final_dmg": 5}'
    when 'analyst'    then '{"solo_dmg": -17, "solo_guard": -28, "final_dmg": 34}'
    else '{}' end::jsonb
$function$;

-- ===== 둘이 하는 귀허 배율(supabase/pending/duo_1_0_0f.sql) =====
-- duo_1_0_0f.sql — 귀허의 주인 「둘」 난이도 다시 맞춤 (제안, 배포 안 함)
-- 기준 DB: 복제본 yh_fx9(운영 + 1.0.0e + 1.0.0f 후보) + supabase/pending/solo_aid_1_0_0f.sql. 세 함수 본문은 yh_fx9 본문에서
-- 「when 2 then 0.95」만 바꾼 것 — 운영 본문이 다르면 같은 자리만 옮길 것. 혼자(n=1)·셋·넷 값은 그대로.
-- 바꾸는 곳
--   world_gw_start   주인 체력 인원 배율 둘 0.95 → 1.7 (max_hp·hp 두 곳)
--   world_gw_resolve 주인 손길·물살 피해(raw) 인원 배율 둘 0.95 → 1.4
--   world_gw_k       기여 K의 요괴 한 대(같은 배율) 둘 0.95 → 1.4 (피해 배율과 맞춤, 승패와 무관)
--   10장 결전(world_raid_begin_fight {2.4,3.3,2.9,3.3})은 바꾸지 않음 — 아래 결과.
-- 함께 고칠 것(이 파일 밖): assets/js/views/guide.js 1500줄 「둘 0.95배」 → 체력 1.7배·공격 1.4배, CLAUDE.md §3.5 인원 배율 문장,
--   마이그레이션에 넣을 때 끝에 world_app_meta db_version 줄. 배포는 §17 11-1(버퍼 + owner_inherit_begin/end;
--   world_gw_start·world_gw_resolve 주인 fn_owner_field, world_gw_k 주인 postgres).
--
-- 시뮬(로컬 복제 PostgreSQL 16, 이전 혼자 시뮬과 같은 빌드·정석 플레이: 귀허 Lv38 · 결전 Lv36, 6단계 장비, 반요 고약)
--   둘 정석 행동 보강: 이름을 잃었는데 불러 줄 동료가 없으면(동료 물러남) 스스로 부르기(30%)·의무관은 해독 침,
--   소용돌이에 퇴마관은 퇴마 결계. 결전 둘: 2초마다 둘 다 행동, 의무관 야전 소생·낮은 쪽 회복, 호위 무사 대신 막기,
--   휘두르기 예고에 방어·끊지 못할 기운 모으기는 마지막 차례에 방어·사슬에 묶이면 기술.
--
-- 귀허 둘 걸음(15조 전부, 승/판 · 진 판 주인 남은 체력 평균)
--   체력·피해 0.95·0.95(지금)  45/45  (평균 3분, 쓰러짐 0)                       → 너무 쉬움
--   3.5·0.95                     4/45   (진 판 23~46%)                           → 너무 어려움
--   2.0·0.95                    44/60 (7.3/10)  의무·봉인 조 4/4, 물리 둘(호위+사수 등)·암영 조 1~2/4
--   2.4·0.95                    47/90 (5.2/10)  사수+암영 0/6·호위+사수 1/6 ~ 봉인 조 5/6 — 체력만 올리면 같은 얼굴 조가 오래 끌려 크게 벌어짐
--   3.0·0.8                     43/90 (4.8/10)  퇴마+암영 0/6 ~ 사수+의무 6/6
--   1.6·1.4                     59/90 (6.6/10)  봉인 조 6/6, 물리 둘 3~4/6 — 싸움이 짧아져 조 차이가 줄어듦
--   1.8·1.5                     32/90 (3.6/10)
--   1.7·1.4 (제안)             181/368 (4.9/10)  아래 표
--
-- 귀허 둘 조별(지금 0.95·0.95 → 제안 1.7·1.4; 제안은 8판 + 확인 12~20판)
--   조              | 지금      | 제안 승/판  (/10) | 진 판 남은 체력 평균
--   호위+사수       | 3/3       | 10/20  5.0         | 14%
--   호위+퇴마       | 3/3       | 14/28  5.0         | 25%
--   호위+의무       | 3/3       | 10/20  5.0         | 15~21%
--   호위+봉인       | 3/3       | 15/20  7.5         | 2~23%
--   호위+암영       | 3/3       |  7/28  2.5         | 26~31%
--   사수+퇴마       | 3/3       | 12/28  4.3         | 19~31%
--   사수+의무       | 3/3       | 15/20  7.5         | 17~22%
--   사수+봉인       | 3/3       | 16/28  5.7         | 14~24%
--   사수+암영       | 3/3       |  8/28  2.9         | 25~36%
--   퇴마+의무       | 3/3       | 17/28  6.1         | 8~26%
--   퇴마+봉인       | 3/3       | 12/20  6.0         | 7~8%
--   퇴마+암영       | 3/3       |  5/20  2.5         | 21~26%
--   의무+봉인       | 3/3       | 23/28  8.2         | 15~21%
--   의무+암영       | 3/3       | 10/28  3.6         | 16%
--   봉인+암영       | 3/3       |  7/20  3.5         | 11~17%
--   (n=20이면 95% 구간 대략 ±20%p, n=28이면 ±18%p) 암영 검객이 든 조가 2.5~3.6으로 낮고 의무+봉인이 8.2로 높음 —
--   인원 배율 하나로는 못 좁힘(암영은 혼자 보정도 +11/+20이 필요했던 직업: 둘에서도 약한 직업 쪽 문제).
-- 넷(제안 값, 넷 배율은 그대로): 호위+퇴마+의무+암영 10/10 · 사수+봉인+의무+호위 10/10 · 사수+퇴마+봉인+암영 10/10, 쓰러짐 0
-- 혼자: n=1 갈래(체력 1.2·피해 1·world_solo_aid)는 손대지 않음 — solo_aid_1_0_0f.sql 결과 그대로.
--
-- 10장 결전 둘(바꾸지 않음, 체력 배율 3.3; 승/판)
--   조              | 3.3          | 3.5   | 3.7
--   호위+사수       | 4/4          | 6/6   | 4/4
--   호위+퇴마       | 12/12        | 6/6   | 4/4
--   호위+의무       | 4/4          | 6/6   | 3/4
--   호위+봉인       | 4/4          | 6/6   | 4/4
--   호위+암영       | 12/12        | 5/6   | 2/4
--   사수+퇴마       | 12/12        | 6/6   | 4/4
--   사수+의무       | 4/4          | 6/6   | 4/4
--   사수+봉인       | 12/12        | 6/6   | 4/4
--   사수+암영       | 4/4          | 6/6   | 4/4
--   퇴마+의무       | 10/12        | 2/6   | 0/4
--   퇴마+봉인       | 4/4          | 5/6   | 2/4
--   퇴마+암영       | 1/4 (진 판 2~9%) | 1/6 | 0/4
--   의무+봉인       | 12/12        | 2/6   | 1/4
--   의무+암영       | 2/12 (진 판 3~16%, 20분 시간 끝) | 0/6 | 0/4
--   봉인+암영       | 5/12 (진 판 1~6%) | 1/6 | 0/4
--   합계            | 약 8.5/10    | 7.1   | 6.3
--   사수 조는 8~10분에 쓰러짐 1~8로 늘 이기고(사수는 혼자 결전 final_dmg −46이 필요했던 직업), 암영·의무가 든 조는 20분이 모자라 짐.
--   체력 배율을 올리면 이미 아슬아슬한 암영·의무 조만 0으로 떨어지고 사수 조는 그대로 10/10 → 인원 배율로는 5~8에 못 넣음.
--   3.3을 그대로 둠(조별 차이는 직업 쪽 — 사수 결전 화력·암영 결전 화력 — 으로 따로 다룰 일).

CREATE OR REPLACE FUNCTION public.world_gw_start(p_fight uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare f public.world_gw_fights%rowtype; x record; s jsonb; sa numeric := 0; n int := 0;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'wait' then return; end if;
  for x in select m.owner_id, c.inventory, c.health from public.world_gw_members m join public.world_characters c using (owner_id) where m.fight_id = p_fight for update of c loop
    if coalesce((x.inventory ->> 'gwiheo_charm')::int, 0) < 1 or x.health <= 0 then
      delete from public.world_gw_members where fight_id = p_fight and owner_id = x.owner_id;
      continue;
    end if;
    update public.world_characters set inventory = public.world_inv_add(inventory, 'gwiheo_charm', -1), updated_at = now() where owner_id = x.owner_id;
    s := public.world_raid_stats(x.owner_id);
    update public.world_gw_members set stats = s, hp = greatest(30, least(100, x.health)) where fight_id = p_fight and owner_id = x.owner_id;
    insert into public.world_gw_records(owner_id, tries) values (x.owner_id, 1) on conflict (owner_id) do update set tries = world_gw_records.tries + 1;
    sa := sa + coalesce((s ->> 'attack')::numeric, 50); n := n + 1;
  end loop;
  if n = 0 then
    update public.world_gw_fights set status = 'failed', ended_at = now(), updated_at = now() where fight_id = p_fight;
    return;
  end if;
  update public.world_gw_fights set status = 'fight', max_hp = round(greatest(6000, sa * 40) * case n when 1 then 1.2 when 2 then 1.7 when 3 then 0.8 else 0.85 end),
         hp = round(greatest(6000, sa * 40) * case n when 1 then 1.2 when 2 then 1.7 when 3 then 0.8 else 0.85 end), phase = 1, round = 0, cycle = 0,
         ends_at = now() + interval '15 minutes', updated_at = now() where fight_id = p_fight;
  if n = 1 then update public.world_gw_members m set stats = m.stats || public.world_solo_aid(m.job_key) where fight_id = p_fight; end if;
  perform public.world_gw_say(p_fight, 0, 'phase', '빈 왕좌 위로 물이 솟아 사람 꼴이 된다. 귀허의 주인이 두 얼굴을 번갈아 든다. 「사람의 얼굴에는 사람의 칼을, 요괴의 얼굴에는…」 말끝이 물에 녹는다.');
  perform public.world_gw_next_round(p_fight);
end $function$;

CREATE OR REPLACE FUNCTION public.world_gw_resolve(p_fight uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare cbr jsonb; f public.world_gw_fights%rowtype; m record; a jsonb; av text; d numeric; boss_dmg numeric := 0; boss_heal numeric := 0; physical boolean;
  k text; vsum numeric := 0; tank_ok boolean := false; freed uuid[] := '{}'; tgt uuid; raw numeric; r int; alive int; cr boolean;
  sk public.world_coop_skills%rowtype; csp int; vbfx jsonb; vfx jsonb; tn text; e jsonb; aoe boolean; mul numeric; n int; need numeric;
  delayed boolean := false; sealed boolean := false; broke boolean := false; cover_by uuid; hit_who uuid; v_n int; v_hands int; v_h int; v_hit uuid[] := '{}'; v_miss numeric;
  v_mb text; v_mp numeric; v_eb text; v_ep numeric; v_cb text; v_cp numeric; v_cn text; v_brk uuid;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return; end if;
  if now() < f.round_ends_at and exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act is null) then return; end if;
  r := f.round; k := f.mech ->> 'k'; aoe := coalesce((f.mech ->> 'aoe')::boolean, false); vbfx := coalesce(f.bfx, '{}'::jsonb);
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'coop' order by joined_at loop
    select * into sk from public.world_coop_skills where skill_id = m.act ->> 's';
    if sk.skill_id is null then continue; end if;
    select spiritual_power into csp from public.world_characters where owner_id = m.owner_id for update;
    if coalesce(csp, 0) < sk.cost then perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 영력이 모자라 「' || sk.skill_name || '」이(가) 흩어졌습니다.'); continue; end if;
    update public.world_characters set spiritual_power = spiritual_power - sk.cost, updated_at = now() where owner_id = m.owner_id;
    update public.world_gw_members set acts = acts + 1, cds = jsonb_set(cds, array[sk.skill_id], to_jsonb(r + greatest(1, ceil(sk.cooldown_s / 5.0)::int)))
     where fight_id = p_fight and owner_id = m.owner_id;
    perform public.world_gw_credit(p_fight, m.owner_id, 1, 'skill');
    tgt := case when sk.target = 'self' then m.owner_id else coalesce(nullif(m.act ->> 't', '')::uuid, m.owner_id) end;
    select name into tn from public.world_gw_members where fight_id = p_fight and owner_id = tgt;
    e := sk.effect;
    if e ? 'amt' then
      e := e || jsonb_build_object('amt', round((e ->> 'amt')::int * (1 + coalesce((select (x.skill_progress -> 'first_aid' ->> 'rank')::int from public.world_characters x where x.owner_id = m.owner_id), 0) / 100.0)));
    end if;
    case e ->> 'type'
      when 'ward' then update public.world_gw_members set fx = fx || public.world_cb_buff('ward', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'ward_all' then update public.world_gw_members set fx = fx || public.world_cb_buff('ward_all', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'might' then update public.world_gw_members set fx = fx || public.world_cb_buff('might', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'might_all' then update public.world_gw_members set fx = fx || public.world_cb_buff('might_all', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'rally' then update public.world_gw_members set fx = fx || public.world_cb_buff('rally', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'resonance' then update public.world_gw_members set fx = fx || public.world_cb_buff('resonance', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'expose' then vbfx := vbfx || jsonb_build_object('expose', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int, 'by', m.owner_id));
        if e ? 'stagger' then vbfx := vbfx || jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + 1, 'block_by', m.owner_id); sealed := true; end if;
      when 'heal' then
        select least(round((e ->> 'amt')::int * 0.65), 100 - x.hp) into d from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0;
        perform public.world_gw_credit(p_fight, m.owner_id, d, case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.65)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
      when 'heal_all' then
        select sum(least(round((e ->> 'amt')::int * 0.65), 100 - x.hp)) into d from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest;
        perform public.world_gw_credit(p_fight, m.owner_id, d, 'heal');
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.65)::int) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'cleanse_heal' then
        select least(round((e ->> 'amt')::int * 0.65), 100 - x.hp) into d from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0;
        perform public.world_gw_credit(p_fight, m.owner_id, d, case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.65)::int), nameless = false where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
        freed := freed || tgt;
      when 'revive' then
        if exists (select 1 from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds > 0) then
          perform public.world_gw_credit(p_fight, m.owner_id, (e ->> 'hp')::int, 'heal'); end if;
        update public.world_gw_members set out_rounds = 0, rest = true, hp = (e ->> 'hp')::int where fight_id = p_fight and owner_id = tgt and out_rounds > 0;
      when 'cover' then update public.world_gw_members set fx = fx || jsonb_build_object('cover', tgt) where fight_id = p_fight and owner_id = m.owner_id;
      when 'gward' then update public.world_gw_members set fx = fx || public.world_cb_buff('gward', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
        if coalesce((e ->> 'mind')::int, 0) > 0 then
          update public.world_characters set mental = least(100, mental + (e ->> 'mind')::int), updated_at = now() where owner_id = tgt;
        end if;
      when 'break' then broke := true; v_brk := m.owner_id;
      when 'taunt' then update public.world_gw_members set fx = fx || public.world_cb_buff('taunt', e, m.owner_id) where fight_id = p_fight and owner_id = m.owner_id;
      when 'crit_all' then update public.world_gw_members set fx = fx || public.world_cb_buff('crit_all', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'evade' then update public.world_gw_members set fx = fx || public.world_cb_buff('evade', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'smoke' then vbfx := vbfx || jsonb_build_object('smoke', jsonb_build_object('n', (e ->> 'n')::int, 'miss', (e ->> 'miss')::int, 'by', m.owner_id));
      when 'crit_next' then update public.world_gw_members set fx = fx || public.world_cb_buff('crit_next', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'delay' then vbfx := vbfx || jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + (e ->> 'n')::int, 'block_by', m.owner_id); delayed := true;
      when 'shield' then update public.world_gw_members set fx = fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (e ->> 'amt')::int, 'shield_by', m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'sp' then
        if tgt <> m.owner_id then perform public.world_gw_credit(p_fight, m.owner_id, (select greatest(0, least((e ->> 'amt')::int, 100 - x.spiritual_power)) from public.world_characters x where x.owner_id = tgt)
          * coalesce((m.stats ->> 'attack')::numeric, 0) * 0.05, 'boost'); end if;
        update public.world_characters set spiritual_power = least(100, spiritual_power + (e ->> 'amt')::int), updated_at = now() where owner_id = tgt;
      else null;
    end case;
    perform public.world_gw_say(p_fight, r, 'skill', m.name || ' — 「' || sk.skill_name || '」' || case when sk.target = 'ally' and tgt <> m.owner_id then ' → ' || coalesce(tn, '') else '' end || ' · ' || sk.exp_text
      || case e ->> 'type' when 'cleanse_heal' then case when k = 'chain' then ' (사슬이 느슨해집니다)' when k = 'name' then ' (흐려진 이름이 또렷해집니다)' else '' end
                           when 'delay' then case when k = 'vortex' then ' (물살이 잠시 멎습니다)' else '' end
                           when 'expose' then case when k = 'face' then ' (주인의 입이 사슬에 묶입니다)' else '' end
                           when 'break' then ' (물의 기세가 꺾입니다)' else '' end || '.');
  end loop;
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest order by joined_at loop
    a := coalesce(m.act, '{"a":"guard"}'::jsonb); av := a ->> 'a';
    if av = 'coop' then continue; end if;
    if m.act is not null then update public.world_gw_members set acts = acts + 1 where fight_id = p_fight and owner_id = m.owner_id; end if;
    select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
    if av = 'attack' then
      cbr := public.world_cb_attack(m.stats, vfx, vbfx, 0.9, 0.2);
      vfx := cbr -> 'fx'; vbfx := cbr -> 'bfx'; cr := (cbr ->> 'crit')::boolean;
      v_mb := cbr -> 'src' ->> 'mb'; v_mp := (cbr -> 'src' ->> 'mp')::numeric; v_eb := cbr -> 'src' ->> 'eb'; v_ep := (cbr -> 'src' ->> 'ep')::numeric;
      v_cb := cbr -> 'src' ->> 'cb'; v_cp := (cbr -> 'src' ->> 'cp')::numeric; v_cn := cbr -> 'src' ->> 'cn';
      update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;
      d := (cbr ->> 'd')::numeric * (1 + coalesce((m.stats ->> 'solo_dmg')::numeric, 0) / 100.0);
      physical := coalesce(m.stats ->> 'style', 'melee') in ('melee', 'ranged');
      if m.nameless then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 이름을 잃어 칼끝이 주인에게 닿지 않습니다.');
      elsif k = 'face' and ((f.mech ->> 'face' = 'human') <> physical) then
        if sealed then
          d := d * 0.5; boss_dmg := boss_dmg + d;
          update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
          perform public.world_gw_credit_hit(p_fight, m.owner_id, d, cr, v_mb, v_mp, v_eb, v_ep, v_cb, v_cp, v_cn, coalesce((m.stats ->> 'crit')::numeric, 5));
          perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — 사슬에 묶인 주인이 힘을 삼키지 못합니다. ' || round(d) || '의 피해.');
        else
          boss_heal := boss_heal + round(d * 0.5);
          perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — ' || case when physical then '요괴의 얼굴에 칼을 대자' else '사람의 얼굴에 술법을 쓰자' end || ' 주인이 그 힘을 삼켜 ' || round(d * 0.5) || ' 회복합니다.');
        end if;
      else
        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;
        update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
          perform public.world_gw_credit_hit(p_fight, m.owner_id, d, cr, v_mb, v_mp, v_eb, v_ep, v_cb, v_cp, v_cn, coalesce((m.stats ->> 'crit')::numeric, 5));
        perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — ' || round(d) || case when cr then '의 치명타.' else '의 피해.' end);
      end if;
    elsif av in ('guard', 'brace') then
      if k = 'vortex' and (m.owner_id::text = f.mech ->> 'tank' or (av = 'brace' and vfx ? 'taunt')) then tank_ok := true;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — ' || case when av = 'brace' then '몸을 낮춰 소용돌이를 정면으로 받아 냅니다.' else '방패를 세우고 물살을 버팁니다.' end);
      elsif av = 'brace' and m.act is not null then
        perform public.world_gw_say(p_fight, r, 'guard', m.name || ' — 몸을 낮추고 버팁니다.');
      end if;
    elsif av = 'item' then
      tgt := coalesce(nullif(a ->> 't', '')::uuid, m.owner_id);
      if coalesce(m.items_used, 0) >= 2 then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 이 싸움에서는 회복품을 더 꺼낼 수 없습니다.');
      elsif coalesce(((select x.inventory from public.world_characters x where x.owner_id = m.owner_id) ->> (a ->> 'i'))::int, 0) < 1 then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 꺼낼 회복품이 없습니다.');
      else
        d := coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'hp')::numeric, 0)
             * case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end * case when m.job_key = 'medic' then case when tgt = m.owner_id then 1.15 else 1.4 end else 1 end
             * (1 + coalesce((m.stats ->> 'heal')::numeric, 0) / 100.0);
        update public.world_characters set inventory = public.world_inv_add(inventory, a ->> 'i', -1), updated_at = now() where owner_id = m.owner_id;
        perform public.world_gw_credit(p_fight, m.owner_id, (select least(round(d), 100 - x.hp) from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0),
          case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set hp = least(100, hp + round(d)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
        update public.world_characters set mental = least(100, mental + ceil(coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'mn')::numeric, 0) * case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end)::int)
         where owner_id = tgt and coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'mn')::numeric, 0) > 0;
        update public.world_gw_members set heal = heal + round(d)::int, items_used = items_used + 1 where fight_id = p_fight and owner_id = m.owner_id;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — ' || coalesce((select x.name from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt), '') || '의 체력 +' || round(d)
          || ' (회복품 ' || (coalesce(m.items_used, 0) + 1) || '/2).');
      end if;
    elsif av = 'call' then
      tgt := nullif(a ->> 't', '')::uuid;
      select name into tn from public.world_gw_members where fight_id = p_fight and owner_id = tgt;
      if k <> 'name' or not exists (select 1 from public.world_gw_members where fight_id = p_fight and owner_id = tgt and nameless) then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — ' || coalesce(tn, '') || '을(를) 불렀지만 메아리만 돌아옵니다.');
      elsif tgt <> m.owner_id or random() < 0.3 then
        update public.world_gw_members set nameless = false where fight_id = p_fight and owner_id = tgt;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — 「' || tn || '!」 부르는 소리에 물에 녹던 이름이 되돌아옵니다.');
      else
        perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — 제 이름을 스스로 부르려 했지만 목소리가 물에 녹았습니다.');
      end if;
    elsif av = 'chain' then
      if k <> 'chain' then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 끊을 사슬이 없습니다.');
      elsif a ->> 'c' = f.mech -> 'colors' ->> m.owner_id::text then
        freed := freed || m.owner_id;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — 자기 사슬(' || (a ->> 'c') || ')을 끊었습니다.');
      else
        perform public.world_gw_hurt(p_fight, m.owner_id, 20, r, '남의 사슬(' || coalesce(a ->> 'c', '?') || ')을 쳐 되튕긴 사슬에');
      end if;
    end if;
  end loop;
  if k = 'chain' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '끊지 못한 사슬에 끌려가');
    end loop;
    if exists (select 1 from public.world_gw_members where fight_id = p_fight and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text) then
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest loop
        if broke then perform public.world_gw_credit(p_fight, v_brk, 30 * 0.7, 'guard'); end if;
        perform public.world_gw_hit(p_fight, m.owner_id, 60 * case when broke then 0.5 else 1 end, r, '사슬이 끌어당긴 물살에', true);
      end loop;
    end if;
  elsif k = 'name' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and nameless loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '이름을 끝내 찾지 못해');
    end loop;
  elsif k = 'vortex' then
    need := coalesce((f.mech ->> 'need')::numeric, 0) * case when delayed then 0.5 else 1 end;
    if tank_ok and vsum >= need then
      boss_dmg := boss_dmg + round(vsum * 0.5);
      perform public.world_gw_say(p_fight, r, 'good', '소용돌이를 끊었습니다! 흩어진 물살이 주인에게 되돌아가 ' || round(vsum * 0.5) || '의 피해를 더 줍니다.');
    else
      perform public.world_gw_say(p_fight, r, 'bad', case when not tank_ok then '쏠린 물살을 받아 낸 사람이 없었습니다. ' else '왕좌를 몰아친 힘이 모자랐습니다. ' end
        || '소용돌이가 모두를 삼키고 주인이 더 사나워집니다.' || case when broke then ' (퇴마 결계가 물살을 절반으로 꺾었습니다)' else '' end);
      if broke then perform public.world_gw_credit(p_fight, v_brk, (select sum(x.hp * 0.25) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest), 'guard'); end if;
      update public.world_gw_members x set hp = greatest(1, (x.hp * case when broke or x.fx ? 'gward' then 0.75 else 0.5 end)::int), fx = x.fx - 'gward'
       where x.fight_id = p_fight and x.out_rounds = 0 and not rest;
      update public.world_gw_fights set enrage = enrage + 1 where fight_id = p_fight;
      f.enrage := f.enrage + 1;
    end if;
  end if;
  update public.world_gw_fights set hp = least(max_hp, greatest(0, hp - round(boss_dmg)::int + round(boss_heal)::int)), updated_at = now() where fight_id = p_fight returning * into f;
  if f.hp <= 0 then update public.world_gw_fights set bfx = vbfx where fight_id = p_fight; perform public.world_gw_settle(p_fight, true); return; end if;
  if k in ('face', 'normal') then
    -- 인원 배율(7.7.4, 1.0.0f 둘 다시 맞춤 — 정석 플레이 시뮬: 넷 거의 다 이김 · 둘 절반 · 혼자 드물게): 1명 1 · 2명 1.4 · 3명 0.8 · 4명 0.85(주인 체력 1.2 · 1.7 · 0.8 · 0.85, world_gw_start)
    raw := (35 + 4 * f.phase) * (1 + 0.15 * f.enrage)
           * (select case count(*) when 1 then 1 when 2 then 1.4 when 3 then 0.8 else 0.85 end from public.world_gw_members where fight_id = p_fight);
    if aoe then
      perform public.world_gw_say(p_fight, r, 'boss', '모아 둔 기운이 터집니다. 왕좌 아래의 물이 한꺼번에 쏟아집니다!' || case when broke then ' (퇴마 결계가 물살을 절반으로 꺾었습니다)' else '' end);
      if broke then perform public.world_gw_credit(p_fight, v_brk, raw * 0.9 * 0.5 * 0.7 * (select count(*) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest), 'guard'); end if;
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest loop
        perform public.world_gw_hit(p_fight, m.owner_id, raw * 0.9 * case when broke then 0.5 else 1 end, r, '쏟아지는 물살에', true);
      end loop;
    elsif coalesce((vbfx ->> 'block')::int, 0) > 0 then
      vbfx := case when (vbfx ->> 'block')::int > 1 then jsonb_set(vbfx, '{block}', to_jsonb((vbfx ->> 'block')::int - 1)) else vbfx - 'block' end;
      perform public.world_gw_credit(p_fight, nullif(vbfx ->> 'block_by', '')::uuid, raw * 0.7 * (select case when count(*) >= 4 then 2 when count(*) = 3 then 1.5 else 1 end from public.world_gw_members x where x.fight_id = p_fight), 'guard');
      perform public.world_gw_say(p_fight, r, 'good', '주인의 손길이 묶여 허공을 가릅니다.');
    else
      -- 손아귀 수는 인원에 맞춘다(7.7.4): 1·2명 하나, 3명 하나·둘 번갈아, 4명 둘 — 같은 사람을 두 번 노리지 않음
      select count(*) into v_n from public.world_gw_members where fight_id = p_fight;
      v_hands := case when v_n >= 4 then 2 when v_n = 3 then 1 + (r % 2) else 1 end;
      n := coalesce((vbfx -> 'smoke' ->> 'n')::int, 0);
      v_miss := coalesce((vbfx -> 'smoke' ->> 'miss')::numeric, 45);
      for v_h in 1 .. v_hands loop
        select * into m from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest and not (x.owner_id = any (v_hit))
         order by public.world_cb_pick_key(coalesce((x.stats ->> 'pres')::numeric, 30) + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)) limit 1;
        exit when m.owner_id is null;
        v_hit := v_hit || m.owner_id;
        hit_who := m.owner_id; cover_by := null;
        select owner_id into cover_by from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and fx ->> 'cover' = m.owner_id::text and owner_id <> m.owner_id limit 1;
        select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
        if n > 0 and random() * 100 < v_miss then
          perform public.world_gw_credit(p_fight, nullif(vbfx -> 'smoke' ->> 'by', '')::uuid, raw * 0.7, 'guard');
          perform public.world_gw_say(p_fight, r, 'miss', '연막 속에서 주인의 손길이 ' || m.name || '을(를) 비껴갑니다.');
        elsif random() * 100 < coalesce((m.stats ->> 'eva')::numeric, 0) + coalesce((vfx -> 'evade' ->> 'pct')::numeric, 0) + (case when m.stats ->> 'style' = 'magic' then 15 else 0 end) then
          if vfx -> 'evade' ->> 'by' is not null and vfx -> 'evade' ->> 'by' <> m.owner_id::text then
            perform public.world_gw_credit(p_fight, (vfx -> 'evade' ->> 'by')::uuid, raw * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0)
              * (vfx -> 'evade' ->> 'pct')::numeric / greatest(1, coalesce((m.stats ->> 'eva')::numeric, 0) + (vfx -> 'evade' ->> 'pct')::numeric), 'guard'); end if;
          if vfx ? 'evade' then update public.world_gw_members x set fx = case when (x.fx -> 'evade' ->> 'n')::int > 1 then jsonb_set(x.fx, '{evade,n}', to_jsonb((x.fx -> 'evade' ->> 'n')::int - 1)) else x.fx - 'evade' end where x.fight_id = p_fight and x.owner_id = m.owner_id; end if;
          perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 주인의 손길을 피했습니다.');
        elsif cover_by is not null then
          perform public.world_gw_credit(p_fight, cover_by, raw * 0.5 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0), 'guard');
          perform public.world_gw_hit(p_fight, cover_by, raw * 0.5, r, (select name from public.world_gw_members where fight_id = p_fight and owner_id = cover_by) || '이(가) ' || m.name || ' 앞을 막아서 주인의 ' || case when v_h > 1 then '다른 ' else '' end || '손아귀를', false);
        else
          perform public.world_gw_hit(p_fight, hit_who, raw, r, case when v_h > 1 then '주인의 다른 손아귀에' else '주인의 손아귀에' end, false);
        end if;
      end loop;
      if n > 0 and coalesce(array_length(v_hit, 1), 0) > 0 then vbfx := case when n > 1 then jsonb_set(vbfx, '{smoke,n}', to_jsonb(n - 1)) else vbfx - 'smoke' end; end if;
    end if;
  end if;
  update public.world_gw_members set out_rounds = out_rounds - 1, rest = rest or out_rounds = 1, hp = case when out_rounds = 1 then 30 else hp end where fight_id = p_fight and out_rounds > 0;
  update public.world_gw_members set fx = fx - 'cover' where fight_id = p_fight and fx ? 'cover';
  update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
  select count(*) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
  -- 혼자면 쓰러져도 한 라운드 쉬고 돌아오므로 「모두 물러남」으로 끝내지 않는다(7.7.4). 대신 열한 번째로 쓰러지면 끝(쓰러짐 10번까지)
  if (select count(*) from public.world_gw_members where fight_id = p_fight) = 1 and (select max(falls) - coalesce(max((stats ->> 'solo_falls')::int), 0) from public.world_gw_members where fight_id = p_fight) > 10 then
    perform public.world_gw_say(p_fight, r, 'bad', '쓰러질 수 있는 횟수를 넘겼습니다. 홀로 선 이의 넋이 더는 버티지 못합니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  if alive = 0 and (select count(*) from public.world_gw_members where fight_id = p_fight) > 1 then
    perform public.world_gw_say(p_fight, r, 'bad', '모두가 물러났습니다. 소용돌이가 왕좌를 덮습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  if now() >= f.ends_at then
    perform public.world_gw_say(p_fight, r, 'bad', '시간이 다 되었습니다. 귀허의 주인이 바다 밑으로 가라앉습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  perform public.world_gw_next_round(p_fight);
end $function$;

CREATE OR REPLACE FUNCTION public.world_gw_k(p_fight uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare aa numeric; n int; ph int;
begin
  select avg((stats ->> 'attack')::numeric), count(*) into aa, n from public.world_gw_members where fight_id = p_fight;
  select phase into ph from public.world_gw_fights where fight_id = p_fight;
  if aa is null then return 1; end if;
  return 1.5 * aa / ((35 + 4 * coalesce(ph, 1)) * case n when 1 then 1 when 2 then 1.4 when 3 then 0.8 else 0.85 end);
end $function$;

update public.world_app_meta set value = '20261105050000' where key = 'db_version';
