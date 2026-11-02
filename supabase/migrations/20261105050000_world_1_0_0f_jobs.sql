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

update public.world_skill_catalog set description = '택일 기술 · 내가 구조한 동료가 체력 80으로 깨어난다(응급 처치 8단계 덤 +10은 따로)'
 where skill_id = 'first_aid_c43a';

update public.world_app_meta set value = '20261105050000' where key = 'db_version';
